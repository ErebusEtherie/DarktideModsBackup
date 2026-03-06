--[[
	File: lobby/talent_preview_tree.lua
	Description: Tree mode preview builder for lobby overlay
	Overall Release Version: 1.1.5
	File Version: 1.0.0
	File Introduced in: 1.1.5
	Last Updated: 2026-01-24
	Author: LAUREHTE
]]

local mod = get_mod("TalentPreview")

local function _log_once(key, message)
	if not mod._tp_tree_log_once then
		mod._tp_tree_log_once = {}
	end

	if mod._tp_tree_log_once[key] then
		return
	end

	mod._tp_tree_log_once[key] = true
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
		_log_once("uiwidget_missing", "[TalentPreview] UIWidget unavailable; tree preview disabled.")
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
		_log_once("talent_settings_missing", "[TalentPreview] TalentBuilderViewSettings unavailable; tree preview disabled.")
	end
end
local ContentBlueprints
do
	local ok, module = pcall(require, "scripts/ui/views/lobby_view/lobby_view_content_blueprints")
	if ok then
		ContentBlueprints = module
	else
		_log_once("content_blueprints_missing", "[TalentPreview] Lobby content blueprints unavailable; tree preview disabled.")
	end
end

local TreePreview = {}

local SKIP_NODE_TYPE = {
	start = true,
}

local TREE_LINK_THICKNESS = 6
local TREE_LINK_CORNER_GAP = 2
local UNSELECTED_ALPHA = 0.25
local LINE_MATERIAL = "content/ui/materials/backgrounds/default_square"
local LINE_COLOR_ACTIVE = { 255, 255, 255, 255 }
local LINE_COLOR_INACTIVE = { 77, 0, 0, 0 }

local STAT_NODE_SCALE = 0.5
local STAT_NODE_COLOR = { 255, 120, 200, 255 }

local PLAIN_ICON_NODE_TYPES = {}

local EMPTY_TABLE = {}

local function _line_angle(x1, y1, x2, y2)
	if math.angle then
		return math.angle(x1, y1, x2, y2)
	end

	local dx = x2 - x1
	local dy = y2 - y1

	if math.atan2 then
		return math.atan2(dy, dx)
	end

	if dx == 0 then
		return dy >= 0 and (math.pi * 0.5) or (-math.pi * 0.5)
	end

	local angle = math.atan(dy / dx)
	if dx < 0 then
		angle = angle + math.pi
	end

	return angle
end

local function _safe_number(value, fallback)
	if type(value) ~= "number" or value ~= value then
		return fallback
	end

	return value
end

local function _normalize_icon(icon, fallback_icon)
	if type(icon) == "table" then
		icon = icon.icon or icon.texture or icon.material
	end

	if type(icon) == "string" then
		local lower = string.lower(icon)
		if icon == "" or lower:find("icon here", 1, true) or lower:find("placeholder", 1, true) or not icon:match("^content/") then
			icon = nil
		end
	else
		icon = nil
	end

	if not icon or icon == "" then
		return fallback_icon
	end

	return icon
end

local function _resolve_icon(node, talent, fallback_icon)
	local icon = node and node.icon

	if not icon and talent then
		icon = talent.large_icon or talent.icon or talent.small_icon or talent.hud_icon
	end

	return _normalize_icon(icon, fallback_icon)
end

local function _layout_bounds(layout)
	local nodes = layout and layout.nodes
	if type(nodes) ~= "table" or #nodes == 0 then
		return nil
	end

	local min_x, max_x, min_y, max_y
	for i = 1, #nodes do
		local node = nodes[i]
		if type(node) == "table" and type(node.x) == "number" and type(node.y) == "number" then
			min_x = min_x and math.min(min_x, node.x) or node.x
			max_x = max_x and math.max(max_x, node.x) or node.x
			min_y = min_y and math.min(min_y, node.y) or node.y
			max_y = max_y and math.max(max_y, node.y) or node.y
		end
	end

	if not min_x then
		return nil
	end

	return {
		min_x = min_x,
		max_x = max_x,
		min_y = min_y,
		max_y = max_y,
	}
end

local function _bounds_overlap(a, b)
	if not a or not b then
		return false
	end

	local x_overlap = not (a.max_x < b.min_x or b.max_x < a.min_x)
	local y_overlap = not (a.max_y < b.min_y or b.max_y < a.min_y)
	return x_overlap and y_overlap
end

local function _resolve_primary_layout_path(archetype)
	if not archetype then
		return nil
	end

	local name = archetype.name
	if type(name) == "string" and name ~= "" then
		return "scripts/ui/views/talent_builder_view/layouts/" .. string.lower(name) .. "_tree"
	end

	return nil
end

local function _load_layout(path)
	if not path then
		return nil
	end

	local ok, layout = pcall(require, path)
	if not ok then
		return nil
	end

	return layout
end

local function _is_broker_stimm_layout(path)
	if type(path) ~= "string" then
		return false
	end

	return path:find("broker_stimm_builder_view", 1, true) ~= nil
end

local function _add_links_from_layout(tree, layout, map, node_by_key, node_by_global_id, link_set)
	if not layout then
		return
	end

	local function add_link(from_id, to_id)
		if not from_id or not to_id or not node_by_global_id[from_id] or not node_by_global_id[to_id] then
			return
		end

		local key = tostring(from_id) .. ":" .. tostring(to_id)
		if link_set[key] then
			return
		end

		link_set[key] = true
		tree.links[#tree.links + 1] = { from = from_id, to = to_id }
	end

	local links = layout.links or layout.edges or layout.connections
	if type(links) == "table" then
		for i = 1, #links do
			local link = links[i]
			if type(link) == "table" then
				local from_ref = link.from or link.start or link[1]
				local to_ref = link.to or link["end"] or link.finish or link[2]
				local from_id
				local to_id

				if type(from_ref) == "number" then
					from_id = map[from_ref]
				elseif type(from_ref) == "string" then
					from_id = node_by_key[from_ref]
				end

				if type(to_ref) == "number" then
					to_id = map[to_ref]
				elseif type(to_ref) == "string" then
					to_id = node_by_key[to_ref]
				end

				add_link(from_id, to_id)
			end
		end
	end

	local nodes = layout.nodes
	if type(nodes) ~= "table" then
		return
	end

	for i = 1, #nodes do
		local node = nodes[i]
		if type(node) == "table" then
			local node_id = map[i]
			local parents = node.parents
			local children = node.children

			if type(parents) == "table" then
				for _, parent in ipairs(parents) do
					add_link(node_by_key[parent], node_id)
				end
			end

			if type(children) == "table" then
				for _, child in ipairs(children) do
					add_link(node_id, node_by_key[child])
				end
			end
		end
	end
end

function TreePreview.collect(profile, options)
	if not TalentBuilderViewSettings then
		return nil, ""
	end

	if not profile or not profile.archetype or not profile.archetype.talents then
		return nil, ""
	end

	local archetype = profile.archetype
	local selected_talents = profile.talents or EMPTY_TABLE
	local fallback_icon = NodeLayout and NodeLayout.fallback_icon and NodeLayout.fallback_icon()
		or "content/ui/textures/icons/talents/psyker/psyker_ability_discharge"
	local include_stimm_tree = options and options.include_stimm_tree
	local stimm_gap = _safe_number(options and options.stimm_gap, 80)
	local stimm_offset_x = _safe_number(options and options.stimm_offset_x, 0)
	local stimm_offset_y = _safe_number(options and options.stimm_offset_y, 0)
	local is_broker = archetype and archetype.name == "broker"

	local tree = {
		nodes = {},
		links = {},
		bounds = { min_x = nil, max_x = nil, min_y = nil, max_y = nil },
		layout_bounds = {},
		layout_info = {},
	}

	local node_by_key = {}
	local node_by_global_id = {}
	local signature_parts = {}
	local link_set = {}
	local global_id = 0

	local function register_node(node, global_node_id)
		if not node then
			return
		end
		if node.name then
			node_by_key[node.name] = global_node_id
		end
		if node.id then
			node_by_key[node.id] = global_node_id
		end
		if node.widget_name then
			node_by_key[node.widget_name] = global_node_id
		end
		if node.talent then
			node_by_key[node.talent] = node_by_key[node.talent] or global_node_id
		end
	end

	local function add_node(node, x_offset, y_offset, scale, center_x, center_y, layout_id, is_stimm)
		local node_type = node.type
		if SKIP_NODE_TYPE[node_type] then
			return nil
		end

		global_id = global_id + 1
		local node_id = global_id

		local talent_name = node.talent
		local talent = talent_name and archetype.talents[talent_name] or nil
		local points_spent = talent_name and (selected_talents[talent_name] or 0) or 0

		local icon = _resolve_icon(node, talent, fallback_icon)
		local raw_x = type(node.x) == "number" and node.x or 0
		local raw_y = type(node.y) == "number" and node.y or 0
		local use_scale = scale or 1
		local cx = center_x or 0
		local cy = center_y or 0
		local x = (raw_x - cx) * use_scale + cx + (x_offset or 0)
		local y = (raw_y - cy) * use_scale + cy + (y_offset or 0)

		local entry = {
			id = node_id,
			x = x,
			y = y,
			node_type = node_type or "default",
			talent_name = talent_name,
			talent = talent,
			icon = icon,
			points_spent = points_spent,
			is_selected = points_spent and points_spent > 0 or false,
			layout_id = layout_id,
			is_stimm = is_stimm or false,
		}

		tree.nodes[#tree.nodes + 1] = entry
		node_by_global_id[node_id] = entry
		register_node(node, node_id)

		if entry.is_selected and talent_name then
			signature_parts[#signature_parts + 1] = string.format("%s:%s", talent_name, tostring(points_spent))
		end

		local b = tree.bounds
		b.min_x = b.min_x and math.min(b.min_x, x) or x
		b.max_x = b.max_x and math.max(b.max_x, x) or x
		b.min_y = b.min_y and math.min(b.min_y, y) or y
		b.max_y = b.max_y and math.max(b.max_y, y) or y

		if layout_id then
			local lb = tree.layout_bounds[layout_id]
			if not lb then
				lb = { min_x = nil, max_x = nil, min_y = nil, max_y = nil }
				tree.layout_bounds[layout_id] = lb
			end
			lb.min_x = lb.min_x and math.min(lb.min_x, x) or x
			lb.max_x = lb.max_x and math.max(lb.max_x, x) or x
			lb.min_y = lb.min_y and math.min(lb.min_y, y) or y
			lb.max_y = lb.max_y and math.max(lb.max_y, y) or y
		end

		return node_id
	end

	local layouts = {}
	local stimm_scale = math.max(0.1, (options and options.stimm_scale_percent or 100) / 100)
	local primary_path = _resolve_primary_layout_path(archetype)
	local primary_layout = _load_layout(primary_path)

	if primary_layout and type(primary_layout.nodes) == "table" then
		layouts[#layouts + 1] = { layout = primary_layout, x = 0, y = 0, scale = 1, is_stimm = false }

		if include_stimm_tree and _is_broker_stimm_layout(archetype.specialization_talent_layout_file_path) then
			local stimm_layout = _load_layout(archetype.specialization_talent_layout_file_path)
			local main_bounds = _layout_bounds(primary_layout)
			local stimm_bounds = _layout_bounds(stimm_layout)
			local y_offset = 0
			local x_offset = 0
			local cx = stimm_bounds and (stimm_bounds.min_x + stimm_bounds.max_x) * 0.5 or 0
			local cy = stimm_bounds and (stimm_bounds.min_y + stimm_bounds.max_y) * 0.5 or 0

			if is_broker then
				x_offset = stimm_offset_x
				y_offset = stimm_offset_y
			elseif main_bounds and stimm_bounds then
				local scaled_max_y = cy + (stimm_bounds.max_y - cy) * stimm_scale
				y_offset = (main_bounds.min_y - stimm_gap) - scaled_max_y
			end

			if stimm_layout and type(stimm_layout.nodes) == "table" then
				layouts[#layouts + 1] = {
					layout = stimm_layout,
					x = x_offset,
					y = y_offset,
					scale = stimm_scale,
					center_x = cx,
					center_y = cy,
					is_stimm = true,
				}
			end
		end
	else
		local base_layout = _load_layout(archetype.talent_layout_file_path)
		local spec_layout = _load_layout(archetype.specialization_talent_layout_file_path)
		local spec_is_stimm = include_stimm_tree and _is_broker_stimm_layout(archetype.specialization_talent_layout_file_path)

		if base_layout and type(base_layout.nodes) == "table" then
			layouts[#layouts + 1] = { layout = base_layout, x = 0, y = 0, scale = 1, is_stimm = false }
		end

		if spec_layout and type(spec_layout.nodes) == "table" then
			if spec_is_stimm and #layouts > 0 then
				local main_bounds = _layout_bounds(layouts[1].layout)
				local stimm_bounds = _layout_bounds(spec_layout)
				local y_offset = 0
				local x_offset = 0
				local cx = stimm_bounds and (stimm_bounds.min_x + stimm_bounds.max_x) * 0.5 or 0
				local cy = stimm_bounds and (stimm_bounds.min_y + stimm_bounds.max_y) * 0.5 or 0

				if is_broker then
					x_offset = stimm_offset_x
					y_offset = stimm_offset_y
				elseif main_bounds and stimm_bounds then
					local scaled_max_y = cy + (stimm_bounds.max_y - cy) * stimm_scale
					y_offset = (main_bounds.min_y - stimm_gap) - scaled_max_y
				end

				layouts[#layouts + 1] = {
					layout = spec_layout,
					x = x_offset,
					y = y_offset,
					scale = stimm_scale,
					center_x = cx,
					center_y = cy,
					is_stimm = true,
				}
			elseif #layouts >= 1 then
				local a = _layout_bounds(layouts[1].layout)
				local b = _layout_bounds(spec_layout)

				if _bounds_overlap(a, b) then
					local gap = math.max(30, stimm_gap)
					local y_offset = (a.max_y - b.min_y) + gap
					layouts[#layouts + 1] = { layout = spec_layout, x = 0, y = y_offset, scale = 1, is_stimm = false }
				else
					layouts[#layouts + 1] = { layout = spec_layout, x = 0, y = 0, scale = 1, is_stimm = false }
				end
			else
				layouts[#layouts + 1] = { layout = spec_layout, x = 0, y = 0, scale = 1, is_stimm = false }
			end
		end
	end

	if #layouts == 0 then
		return nil, ""
	end

	local layout_maps = {}
	for li = 1, #layouts do
		local info = layouts[li]
		tree.layout_info[li] = { is_stimm = info.is_stimm or false }
		local nodes = info.layout and info.layout.nodes or EMPTY_TABLE
		local map = {}
		layout_maps[li] = map

		for i = 1, #nodes do
			local node = nodes[i]
			if type(node) == "table" then
				map[i] = add_node(node, info.x, info.y, info.scale, info.center_x, info.center_y, li, info.is_stimm)
			end
		end
	end

	for li = 1, #layouts do
		_add_links_from_layout(tree, layouts[li].layout, layout_maps[li], node_by_key, node_by_global_id, link_set)
	end

	table.sort(signature_parts)
	local signature = table.concat(signature_parts, "|")

	return tree, signature
end

local function _create_line_widget(self, scenegraph_id, name, length, thickness, angle, color, material)
	local pass_template = {
		{
			pass_type = "rotated_texture",
			style_id = "line",
			value = material or LINE_MATERIAL,
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				color = color,
				angle = angle,
				pivot = {
					0,
					thickness * 0.5,
				},
				offset = {
					0,
					0,
					0,
				},
				size = {
					length,
					thickness,
				},
			},
		},
	}
	local widget_definition = UIWidget.create_definition(pass_template, scenegraph_id, nil, { length, thickness }, {})
	return self:_create_widget(name, widget_definition)
end

function TreePreview.build_widgets(self, spawn_slot, tree, settings)
	if not UIWidget or not ContentBlueprints or not TalentBuilderViewSettings then
		return
	end

	if not tree or not tree.nodes or #tree.nodes == 0 then
		return
	end

	local bounds = tree.bounds or {}
	if not bounds.min_x or not bounds.max_x or not bounds.min_y or not bounds.max_y then
		return
	end

	local display_bounds = bounds
	if tree.nodes then
		local main_min_x, main_max_x, main_min_y, main_max_y
		for i = 1, #tree.nodes do
			local entry = tree.nodes[i]
			if entry and not entry.is_stimm then
				local x = entry.x
				local y = entry.y
				if type(x) == "number" and type(y) == "number" then
					main_min_x = main_min_x and math.min(main_min_x, x) or x
					main_max_x = main_max_x and math.max(main_max_x, x) or x
					main_min_y = main_min_y and math.min(main_min_y, y) or y
					main_max_y = main_max_y and math.max(main_max_y, y) or y
				end
			end
		end
		if main_min_x and main_max_x and main_min_y and main_max_y then
			display_bounds = {
				min_x = main_min_x,
				max_x = main_max_x,
				min_y = main_min_y,
				max_y = main_max_y,
			}
		end
	end

	local node_size = _safe_number(settings and settings.node_size, 25)
	local max_preview_width = _safe_number(settings and settings.area_width, 320)
	local max_preview_height = _safe_number(settings and settings.area_height, 260)
	local user_scale = _safe_number(settings and settings.scale_percent, 100) / 100
	local base_offset_x = _safe_number(settings and settings.offset_x, -10)
	local base_offset_y = _safe_number(settings and settings.offset_y, 170)
	local background_style = settings and settings.background_style or "off"

	local scenegraph_id = "loadout"
	local settings_by_node_type = TalentBuilderViewSettings.settings_by_node_type or {}
	local template = ContentBlueprints.talent
	if not template then
		return
	end

	spawn_slot.talent_preview_widgets_tree = spawn_slot.talent_preview_widgets_tree or {}
	spawn_slot.talent_preview_link_widgets_tree = spawn_slot.talent_preview_link_widgets_tree or {}

	local bounds_width = math.max(1, (display_bounds.max_x - display_bounds.min_x) + node_size)
	local bounds_height = math.max(1, (display_bounds.max_y - display_bounds.min_y) + node_size)

	local fit_scale_w = max_preview_width / bounds_width
	local fit_scale_h = max_preview_height / bounds_height
	local fit_scale = fit_scale_h
	local scale = math.max(0.05, math.min(8.0, fit_scale * user_scale))

	local start_margin = 20
	local scaled_width = bounds_width * scale
	local extra_x = (max_preview_width - scaled_width) * 0.5
	local origin_x = start_margin + base_offset_x + extra_x
	local origin_y = -(ContentBlueprints.talent.size[2] + 8) - base_offset_y

	local function world_to_screen_center(x, y)
		local sx = origin_x + (x - display_bounds.min_x) * scale
		local sy = origin_y - ((display_bounds.max_y - y) * scale)
		return sx, sy
	end

	local function world_to_screen_top_left(x, y)
		local cx, cy = world_to_screen_center(x, y)
		return cx - node_size * 0.5, cy - node_size * 0.5
	end

	local node_by_id = {}
	for i = 1, #tree.nodes do
		node_by_id[tree.nodes[i].id] = tree.nodes[i]
	end

	local function _node_layout_size(node)
		local settings = settings_by_node_type[node.node_type] or settings_by_node_type.default
		local size = settings and settings.size and settings.size[1] or node_size
		return size
	end

	local base_link_thickness = math.max(TREE_LINK_THICKNESS, math.floor(node_size * 0.4))
	local link_thickness = math.max(1, math.floor(base_link_thickness * 0.1))
	local link_index = 0
	for i = 1, #tree.links do
		local link = tree.links[i]
		local from_node = node_by_id[link.from]
		local to_node = node_by_id[link.to]

		if from_node and to_node then
			local from_size = _node_layout_size(from_node)
			local to_size = _node_layout_size(to_node)
			local x1, y1 = world_to_screen_center(from_node.x + from_size * 0.5, from_node.y + from_size * 0.5)
			local x2, y2 = world_to_screen_center(to_node.x + to_size * 0.5, to_node.y + to_size * 0.5)

			local dx = x2 - x1
			local dy = y2 - y1
			local distance = math.sqrt(dx * dx + dy * dy)

			if distance > 1 then
				local is_active = from_node.is_selected and to_node.is_selected
				local angle = _line_angle(x2, y2, x1, y1)
				local line_material = LINE_MATERIAL
				local line_color = is_active and LINE_COLOR_ACTIVE or LINE_COLOR_INACTIVE
				local t = link_thickness

				link_index = link_index + 1
				local wname = string.format("talent_preview_link_%s_%s", spawn_slot.index, link_index)
				local widget = _create_line_widget(self, scenegraph_id, wname, distance, t, math.pi - angle, line_color, line_material)
				widget.original_offset = { x1, y1 - t * 0.5, -2 }
				widget.offset = { x1, y1 - t * 0.5, -2 }
				spawn_slot.talent_preview_link_widgets_tree[#spawn_slot.talent_preview_link_widgets_tree + 1] = widget
			end
		end
	end

	local widget_index = 0
	local min_x, max_x, min_y, max_y
	local stimm_min_x, stimm_max_x, stimm_min_y, stimm_max_y

	for i = 1, #tree.nodes do
		local entry = tree.nodes[i]
		local node_type_settings = settings_by_node_type[entry.node_type] or settings_by_node_type.default
		local is_stat = entry.node_type == "stat"
		local is_stimm = entry.is_stimm
		local entry_size = node_size
		if is_stat then
			entry_size = math.max(10, math.floor(node_size * STAT_NODE_SCALE))
		end

		local layout_size = node_type_settings and node_type_settings.size and node_type_settings.size[1] or node_size
		local center_x = entry.x + layout_size * 0.5
		local center_y = entry.y + layout_size * 0.5
		local offset_x, offset_y = world_to_screen_center(center_x, center_y)
		offset_x = offset_x - entry_size * 0.5
		offset_y = offset_y - entry_size * 0.5
		local config = {
			loadout = { icon = entry.icon },
			node_type_settings = node_type_settings,
			loadout_id = entry.node_type,
		}

		local pass_template_function = template.pass_template_function
		local pass_template = pass_template_function and pass_template_function(self, config) or template.pass_template
		local optional_style = template.style or {}
		local widget_definition = pass_template and UIWidget.create_definition(pass_template, scenegraph_id, nil, { entry_size, entry_size }, optional_style)

		if widget_definition then
			widget_index = widget_index + 1
			local name_talent = string.format("talent_preview_%s_%s", spawn_slot.index, widget_index)
			local talent_widget = self:_create_widget(name_talent, widget_definition)

			local init = template.init
			if init then
				init(self, talent_widget, config)
			end

			local talent_style = talent_widget.style and talent_widget.style.talent
			local material_values = talent_style and talent_style.material_values

			if material_values and node_type_settings then
				if PLAIN_ICON_NODE_TYPES[entry.node_type] then
					material_values.frame = nil
					material_values.icon_mask = nil
					material_values.gradient_map = nil
				else
					material_values.frame = node_type_settings.frame or material_values.frame
					material_values.icon_mask = node_type_settings.icon_mask or material_values.icon_mask
					material_values.gradient_map = node_type_settings.gradient_map or material_values.gradient_map
				end
			end

			if is_stat then
				if talent_style then
					talent_style.color = STAT_NODE_COLOR
				end

				if material_values and not material_values.gradient_map then
					material_values.gradient_map = "content/ui/textures/color_ramps/talent_default"
				end
			end

			talent_widget.content.is_selected = entry.is_selected
			talent_widget.content.talent_preview_alpha = entry.is_selected and 1 or UNSELECTED_ALPHA
			talent_widget.alpha_multiplier = talent_widget.content.talent_preview_alpha

			if entry.node_type == "default" or entry.node_type == "stat" or entry.node_type == "iconic" then
				talent_widget.content.frame_selected_talent = "content/ui/materials/frames/talents/circular_frame_selected"

				local highlight_style = talent_widget.style.frame_selected_talent
				if highlight_style then
					highlight_style.size = { entry_size + 6, entry_size + 6 }
					highlight_style.offset[3] = -1
				end
			end

			talent_widget.original_offset = { offset_x, offset_y, 0 }
			talent_widget.offset = { offset_x, offset_y, 0 }

			local tooltip_points = entry.points_spent and entry.points_spent > 0 and entry.points_spent or 1
			talent_widget.content.talent_preview_data = {
				talent = entry.talent,
				node_type = entry.node_type,
				points_spent = tooltip_points,
				icon_size = node_size,
				tooltip_offset_x = 0,
				is_talent_preview = true,
			}

			spawn_slot.talent_preview_widgets_tree[#spawn_slot.talent_preview_widgets_tree + 1] = talent_widget

			local x1 = offset_x
			local y1 = offset_y
			local x2 = offset_x + node_size
			local y2 = offset_y + node_size

			if is_stimm then
				stimm_min_x = stimm_min_x and math.min(stimm_min_x, x1) or x1
				stimm_max_x = stimm_max_x and math.max(stimm_max_x, x2) or x2
				stimm_min_y = stimm_min_y and math.min(stimm_min_y, y1) or y1
				stimm_max_y = stimm_max_y and math.max(stimm_max_y, y2) or y2
			else
				min_x = min_x and math.min(min_x, x1) or x1
				max_x = max_x and math.max(max_x, x2) or x2
				min_y = min_y and math.min(min_y, y1) or y1
				max_y = max_y and math.max(max_y, y2) or y2
			end
		end
	end

	local use_background = background_style ~= "off"
	local function _add_background_widget(name_suffix, bounds_min_x, bounds_max_x, bounds_min_y, bounds_max_y)
		if not bounds_min_x or not bounds_max_x or not bounds_min_y or not bounds_max_y then
			return nil
		end

		local use_themed = background_style == "themed" or background_style == "themed_glow"
		local use_glow = background_style == "themed_glow"
		local padding_base = math.max(14, math.floor(node_size * 0.45))
		local padding_x = math.floor(padding_base * math.max(0.6, user_scale)) + 18
		local padding_y = math.floor(padding_base * math.max(0.6, user_scale)) + 8
		local width = (bounds_max_x - bounds_min_x) + padding_x * 2
		local height = (bounds_max_y - bounds_min_y) + padding_y * 2
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
		local name_bg = string.format("talent_preview_bg_%s_%s", name_suffix, spawn_slot.index)
		local bg_widget = self:_create_widget(name_bg, widget_definition)

		bg_widget.original_offset = { bounds_min_x - padding_x, bounds_min_y - padding_y, -3 }
		bg_widget.offset = { bounds_min_x - padding_x, bounds_min_y - padding_y, -3 }

		return bg_widget
	end

	if use_background then
		if min_x and max_x and min_y and max_y then
			spawn_slot.talent_preview_background_tree = _add_background_widget("tree_main", min_x, max_x, min_y, max_y)
		end

		if stimm_min_x and stimm_max_x and stimm_min_y and stimm_max_y then
			spawn_slot.talent_preview_background_tree_stimm = _add_background_widget(
				"tree_stimm",
				stimm_min_x,
				stimm_max_x,
				stimm_min_y,
				stimm_max_y
			)
		end
	end
end

return TreePreview
