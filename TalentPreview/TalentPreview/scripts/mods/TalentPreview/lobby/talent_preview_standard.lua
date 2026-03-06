--[[
	File: lobby/talent_preview_standard.lua
	Description: Standard grid preview builder for lobby overlay
	Overall Release Version: 1.1.5
	File Version: 1.0.0
	File Introduced in: 1.1.5
	Last Updated: 2026-01-24
	Author: LAUREHTE
]]

local mod = get_mod("TalentPreview")

local function _log_once(key, message)
	if not mod._tp_standard_log_once then
		mod._tp_standard_log_once = {}
	end

	if mod._tp_standard_log_once[key] then
		return
	end

	mod._tp_standard_log_once[key] = true
	if mod:get("debug_logging") and mod.echo then
		mod:echo(message)
	end
end

local UIWidget
do
	local ok, module = pcall(require, "scripts/managers/ui/ui_widget")
	if ok then
		UIWidget = module
	else
		_log_once("uiwidget_missing", "[TalentPreview] UIWidget unavailable; standard preview disabled.")
	end
end
local NodeLayout
local success_node_layout, node_layout_module = pcall(require, "scripts/ui/views/node_builder_view_base/utilities/node_layout")
if success_node_layout then
	NodeLayout = node_layout_module
end
local TalentBuilderViewSettings
do
	local ok, module = pcall(require, "scripts/ui/views/talent_builder_view/talent_builder_view_settings")
	if ok then
		TalentBuilderViewSettings = module
	else
		_log_once("talent_settings_missing", "[TalentPreview] TalentBuilderViewSettings unavailable; standard preview disabled.")
	end
end
local ContentBlueprints
do
	local ok, module = pcall(require, "scripts/ui/views/lobby_view/lobby_view_content_blueprints")
	if ok then
		ContentBlueprints = module
	else
		_log_once("content_blueprints_missing", "[TalentPreview] Lobby content blueprints unavailable; standard preview disabled.")
	end
end

local StandardPreview = {}

local CATEGORY_ORDER = {
	"keystone",
	"stat",
	"default",
	"blitz",
	"modifier",
}

local NODE_CATEGORY = {
	keystone = "keystone",
	keystone_modifier = "keystone",
	stat = "stat",
	default = "default",
	iconic = "default",
	ability = "modifier",
	ability_modifier = "modifier",
	tactical = "blitz",
	tactical_modifier = "blitz",
	aura = "modifier",
	aura_modifier = "modifier",
	broker_stimm = "default",
}

local SKIP_NODE_TYPE = {
	start = true,
}

local EMPTY_TABLE = {}

local function _category_enabled(category, settings)
	if category == "keystone" then
		return settings.show_keystone ~= false
	elseif category == "stat" then
		return settings.show_stat ~= false
	elseif category == "default" then
		return settings.show_default ~= false
	elseif category == "blitz" then
		return settings.show_blitz ~= false
	elseif category == "modifier" then
		return settings.show_modifiers ~= false
	end

	return true
end

function StandardPreview.collect(profile, settings)
	if not TalentBuilderViewSettings then
		return nil, ""
	end

	if not profile or not profile.archetype or not profile.archetype.talents then
		return nil, ""
	end

	settings = settings or EMPTY_TABLE

	local archetype = profile.archetype
	local selected_talents = profile.talents or EMPTY_TABLE
	local fallback_icon = NodeLayout and NodeLayout.fallback_icon and NodeLayout.fallback_icon()
		or "content/ui/textures/icons/talents/psyker/psyker_ability_discharge"
	local entries_by_category = {
		keystone = {},
		stat = {},
		default = {},
		blitz = {},
		modifier = {},
	}
	local signature_parts = {}
	local order = 0

	local function add_node(node)
		local node_type = node.type

		if SKIP_NODE_TYPE[node_type] then
			return
		end

		local talent_name = node.talent
		if not talent_name or talent_name == "not_selected" then
			return
		end

		local tier = selected_talents[talent_name]
		if not tier or tier <= 0 then
			return
		end

		if node_type == "aura" and settings.show_aura == false then
			return
		end

		if node_type == "ability_modifier" and settings.show_ability_modifiers == false then
			return
		end

		if node_type == "broker_stimm" and settings.show_broker_stimm == false then
			return
		end

		local category = NODE_CATEGORY[node_type]
		if not category or not _category_enabled(category, settings) then
			return
		end

		local talent = archetype.talents[talent_name]
		if not talent then
			return
		end

		order = order + 1

		local icon = node.icon or talent.large_icon or talent.icon
		if type(icon) == "string" then
			if icon == "" or icon:find("icon here", 1, true) or not icon:match("^content/") then
				icon = nil
			end
		else
			icon = nil
		end
		if not icon or icon == "" then
			icon = fallback_icon
		end

		entries_by_category[category][#entries_by_category[category] + 1] = {
			talent = talent,
			talent_name = talent_name,
			node_type = node_type,
			icon = icon,
			points_spent = tier,
			order = order,
		}

		signature_parts[#signature_parts + 1] = string.format("%s:%s:%s", talent_name, node_type, tostring(tier))
	end

	local function process_layout(layout_path)
		if not layout_path then
			return
		end

		local ok, layout = pcall(require, layout_path)
		if not ok or not layout then
			return
		end

		local nodes = layout.nodes
		if not nodes then
			return
		end

		for i = 1, #nodes do
			add_node(nodes[i])
		end
	end

	process_layout(archetype.talent_layout_file_path)
	process_layout(archetype.specialization_talent_layout_file_path)

	for _, category in ipairs(CATEGORY_ORDER) do
		table.sort(entries_by_category[category], function(a, b)
			return a.order < b.order
		end)
	end

	table.sort(signature_parts)

	return entries_by_category, table.concat(signature_parts, "|")
end

function StandardPreview.build_widgets(self, spawn_slot, entries_by_category, settings)
	if not UIWidget or not ContentBlueprints or not TalentBuilderViewSettings then
		return
	end

	settings = settings or EMPTY_TABLE
	spawn_slot.talent_preview_widgets_standard = spawn_slot.talent_preview_widgets_standard or {}

	local icon_size = settings.icon_size or 60
	if icon_size < 1 then
		icon_size = 1
	end
	local icons_per_row = settings.icons_per_row or 4
	if icons_per_row < 1 then
		icons_per_row = 1
	end
	local margin = math.max(4, math.floor(icon_size * 0.15))
	local row_gap = math.max(3, math.floor(icon_size * 0.075))
	local start_margin = 20
	local tooltip_offset_x = settings.offset_x or 0
	local base_offset_x = tooltip_offset_x
	local base_offset_y = -(ContentBlueprints.talent.size[2] + 8) - (settings.offset_y or 0)
	local row_height = icon_size + row_gap
	local column_width = icon_size + margin
	local scenegraph_id = "loadout"
	local settings_by_node_type = TalentBuilderViewSettings.settings_by_node_type or {}
	local template = ContentBlueprints.talent
	if not template then
		return
	end
	local pass_template_function = template.pass_template_function
	local optional_style = template.style or {}
	local size = { icon_size, icon_size }

	local current_offset_y = base_offset_y
	local widget_index = 0
	local min_x, max_x, min_y, max_y

	for _, category in ipairs(CATEGORY_ORDER) do
		local entries = entries_by_category[category]

		if #entries > 0 then
			local rows = math.ceil(#entries / icons_per_row)
			local total_rows = math.max(rows, 1)
			local total_columns = math.min(#entries, icons_per_row)
			local total_width = (total_columns * icon_size) + ((total_columns - 1) * margin)
			local offset_x = base_offset_x - total_width * 0.5
			local offset_y = current_offset_y

			for index = 1, #entries do
				local entry = entries[index]
				local row = math.floor((index - 1) / icons_per_row)
				local column = (index - 1) % icons_per_row
				local offset_width = offset_x + column * column_width + start_margin
				local offset_height = offset_y - row * row_height

				local config = {
					size = size,
					loadout = {
						name = entry.talent_name,
						icon = entry.icon,
					},
					node_type_settings = settings_by_node_type.default or {},
					loadout_id = entry.node_type,
					icon = entry.icon,
					unique_id = entry.talent_name,
					is_selected = entry.points_spent and entry.points_spent > 0,
					points_spent = entry.points_spent,
				}

				local node_type_settings = settings_by_node_type[entry.node_type] or settings_by_node_type.default or {}
				if node_type_settings then
					config.node_type_settings = node_type_settings
					config.node_type = entry.node_type
					config.frame = node_type_settings.frame
					config.icon_mask = node_type_settings.icon_mask
					config.gradient_map = node_type_settings.gradient_map
					config.icon_size = node_type_settings.icon_size or icon_size
				end

				widget_index = widget_index + 1

				local name_talent = string.format("talent_preview_%s_%s", spawn_slot.index, widget_index)
				local pass_template = pass_template_function and pass_template_function(self, config) or template.pass_template
				local widget_definition = pass_template and UIWidget.create_definition(pass_template, scenegraph_id, nil, size, optional_style)

				if widget_definition then
					local talent_widget = self:_create_widget(name_talent, widget_definition)
					local init = template.init

					if init then
						init(self, talent_widget, config)
					end

					local talent_style = talent_widget.style and talent_widget.style.talent
					local material_values = talent_style and talent_style.material_values
					if material_values and node_type_settings then
						material_values.frame = node_type_settings.frame or material_values.frame
						material_values.icon_mask = node_type_settings.icon_mask or material_values.icon_mask
						material_values.gradient_map = node_type_settings.gradient_map or material_values.gradient_map
					end

					if entry.node_type == "default" or entry.node_type == "stat" or entry.node_type == "iconic" then
						talent_widget.content.frame_selected_talent = "content/ui/materials/frames/talents/circular_frame_selected"

						local highlight_style = talent_widget.style.frame_selected_talent
						if highlight_style then
							highlight_style.size = { icon_size + 6, icon_size + 6 }
							highlight_style.offset[3] = -1
						end
					end

					talent_widget.original_offset = { offset_width, offset_height, 0 }
					talent_widget.offset = { offset_width, offset_height, 0 }
					talent_widget.content.talent_preview_data = {
						talent = entry.talent,
						node_type = entry.node_type,
						points_spent = entry.points_spent,
						icon_size = icon_size,
						tooltip_offset_x = tooltip_offset_x,
						is_talent_preview = true,
					}
					spawn_slot.talent_preview_widgets_standard[#spawn_slot.talent_preview_widgets_standard + 1] = talent_widget

					local x1 = offset_width
					local y1 = offset_height
					local x2 = offset_width + icon_size
					local y2 = offset_height + icon_size

					min_x = min_x and math.min(min_x, x1) or x1
					max_x = max_x and math.max(max_x, x2) or x2
					min_y = min_y and math.min(min_y, y1) or y1
					max_y = max_y and math.max(max_y, y2) or y2
				end
			end

			current_offset_y = current_offset_y - total_rows * row_height - row_gap
		end
	end

	local background_style = settings.background_style or "themed"
	local use_background = background_style ~= "off"

	if use_background and min_x and max_x and min_y and max_y then
		local use_themed = background_style == "themed" or background_style == "themed_glow"
		local use_glow = background_style == "themed_glow"

		local padding = math.max(6, math.floor(icon_size * 0.2))
		local width = (max_x - min_x) + padding * 2
		local height = (max_y - min_y) + padding * 2
		local pass_template

		if background_style == "black" then
			pass_template = {
				{
					pass_type = "rect",
					style_id = "background",
					style = {
						color = { 160, 0, 0, 0 },
					},
				},
			}
		else
			pass_template = {}

			if use_glow then
				pass_template[#pass_template + 1] = {
					pass_type = "texture",
					style_id = "outer_shadow",
					value = "content/ui/materials/frames/dropshadow_medium",
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						scale_to_material = true,
						color = Color.black(160, true),
						size_addition = { 20, 20 },
						offset = { 0, 0, -4 },
					},
				}
			end

			pass_template[#pass_template + 1] = {
				pass_type = "texture",
				style_id = "background",
				value = "content/ui/materials/backgrounds/terminal_basic",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "center",
					scale_to_material = true,
					color = Color.terminal_grid_background(nil, true),
					offset = { 0, 0, 0 },
				},
			}

			if use_glow then
				pass_template[#pass_template + 1] = {
					pass_type = "texture",
					style_id = "frame",
					value = "content/ui/materials/frames/frame_tile_2px",
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						color = Color.terminal_frame(nil, true),
						offset = { 0, 0, 2 },
					},
				}
				pass_template[#pass_template + 1] = {
					pass_type = "texture",
					style_id = "corner",
					value = "content/ui/materials/frames/frame_corner_2px",
					style = {
						horizontal_alignment = "center",
						vertical_alignment = "center",
						color = Color.terminal_corner(nil, true),
						offset = { 0, 0, 3 },
					},
				}
			end
		end

		local widget_definition = UIWidget.create_definition(pass_template, scenegraph_id, nil, { width, height }, {})
		local name_bg = string.format("talent_preview_bg_%s", spawn_slot.index)
		local bg_widget = self:_create_widget(name_bg, widget_definition)

		bg_widget.original_offset = { min_x - padding, min_y - padding, -3 }
		bg_widget.offset = { min_x - padding, min_y - padding, -3 }

		spawn_slot.talent_preview_background_standard = bg_widget
	end
end

return StandardPreview
