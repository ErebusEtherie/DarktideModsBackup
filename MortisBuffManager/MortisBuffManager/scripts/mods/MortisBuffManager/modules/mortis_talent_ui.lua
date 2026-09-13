local mod = get_mod("MortisBuffManager")

local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local ScrollbarPassTemplates = require("scripts/ui/pass_templates/scrollbar_pass_templates")
if mod._mortis_workspace_class then return mod._mortis_workspace_class end
local BaseView = require("scripts/ui/views/base_view")
local MortisView = class("MBMWorkspaceMortisView", "BaseView")
mod._mortis_workspace_class = MortisView
local Definitions = { scenegraph_definition = {
    screen = { size = { 1920, 1080 }, scale = "fit" },
    canvas = { parent = "screen", size = { 1920, 800 }, position = { 0, 220, 0 } },
}, widget_definitions = {} }
local UIWidget = require("scripts/managers/ui/ui_widget")

local function button_definition(scenegraph_id, text)
	-- TalentBuilderView already uses terminal_button. default_button_small also
	-- references buttons/secondary from the inventory package, which can unload
	-- while this view is drawing (including the always-visible picker entry).
	return UIWidget.create_definition(ButtonPassTemplates.terminal_button, scenegraph_id, {
		original_text = text,
		text = text,
	}, nil, {
		text = { font_size = 20, character_spacing = 0.1 },
	})
end

local VISIBLE_ROWS = 10
local PANEL_WIDTH = 1728
local PANEL_HEIGHT = 760
local ROW_WIDTH = 1040
local ROW_HEIGHT = 46
local ROW_GAP = 4
local DETAIL_WIDTH = 640
local DETAIL_HEIGHT = 540
local LIST_HEIGHT = VISIBLE_ROWS * ROW_HEIGHT + (VISIBLE_ROWS - 1) * ROW_GAP
local MORTIS_UI_PACKAGES = {
	"packages/ui/constant_elements/mission_buffs/mission_buffs",
	"content/levels/horde/missions/mission_psykhanium",
}
local PACKAGE_REFERENCE = "MortisBuffManager_mortis_talent_ui"
local FAMILY_NAMES = mod.mortis_family_names or {
	"fire",
	"unkillable",
	"cowboy",
	"electric",
	"elementalist",
	"critical",
	"unstoppable",
}

local package_load_ids = {}
local package_load_generation = 0
local package_load_requested = false
local package_ready = false
local package_failed = false
local active_views = setmetatable({}, { __mode = "k" })

local function request_mortis_ui_package()
	if package_ready or package_load_requested or package_failed or not Managers.package then
		return
	end

	package_load_requested = true
	package_load_generation = package_load_generation + 1
	local generation = package_load_generation
	local pending = #MORTIS_UI_PACKAGES

	for i = 1, #MORTIS_UI_PACKAGES do
		local package_name = MORTIS_UI_PACKAGES[i]
		local resource_exists = true

		if rawget(_G, "Application") and Application.can_get_resource then
			local checked, exists = pcall(Application.can_get_resource, "package", package_name)

			resource_exists = not checked or exists
		end

		if not resource_exists then
			package_load_requested = false
			package_failed = true
			mod:error("Mortis UI resource package does not exist: %s", package_name)

			return
		end

		local success, load_id = pcall(function()
			return Managers.package:load(package_name, PACKAGE_REFERENCE, function(callback_load_id)
				if generation ~= package_load_generation then return end
				if callback_load_id then
					package_load_ids[package_name] = callback_load_id
				end

				if generation == package_load_generation then
					pending = pending - 1

					if pending == 0 then
						package_ready = true
						package_load_requested = false
						mod:info("Native Mortis mission assets loaded for the talent picker")
					end
				end
			end)
		end)

		if success then
			package_load_ids[package_name] = load_id
		else
			package_load_requested = false
			package_failed = true
			mod:error("Failed to load Mortis UI package %s: %s", package_name, tostring(load_id))

			return
		end
	end
end

mod.mortis_request_assets=request_mortis_ui_package
mod.release_mortis_talent_ui_package = function()
	package_load_generation = package_load_generation + 1
	package_ready = false
	package_load_requested = false
	package_failed = false

	if Managers.package then
		for package_name, load_id in pairs(package_load_ids) do
			if load_id then
				local success, release_error = pcall(function()
					Managers.package:release(load_id)
				end)

				if not success then
					mod:error("Failed to release Mortis UI package %s: %s", package_name, tostring(release_error))
				end
			end
		end
	end

	package_load_ids = {}
end

local function visible(content)
	return content.visible == true
end

local function selected_visible(content)
	return content.visible == true and content.selected == true
end

local function icon_visible(content)
	return content.visible == true and content.has_icon == true
end

local function row_background_change(content, style)
	local hotspot = content.hotspot
	local color = style.color

	if hotspot.disabled then
		color[1], color[2], color[3], color[4] = 180, 20, 20, 20
	elseif content.selected then
		color[1], color[2], color[3], color[4] = 230, 62, 52, 31
	elseif hotspot.is_hover then
		color[1], color[2], color[3], color[4] = 230, 48, 59, 62
	else
		color[1], color[2], color[3], color[4] = 210, 24, 29, 31
	end
end

local function row_text_change(content, style)
	local color = style.text_color

	if content.hotspot.disabled then
		color[1], color[2], color[3], color[4] = 180, 115, 115, 115
	elseif content.selected then
		color[1], color[2], color[3], color[4] = 255, 238, 196, 84
	elseif content.hotspot.is_hover then
		color[1], color[2], color[3], color[4] = 255, 255, 255, 255
	else
		color[1], color[2], color[3], color[4] = 255, 205, 215, 215
	end
end

local function text_definition(scenegraph_id, font_size, alignment)
	return UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "text",
			value = "",
			value_id = "text",
			style = {
				font_size = font_size,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "center",
				text_horizontal_alignment = alignment or "center",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
				text_color = { 255, 220, 225, 225 },
				offset = { 0, 0, 2 },
			},
		},
	}, scenegraph_id)
end

local function row_definition(scenegraph_id)
	return UIWidget.create_definition({
		{
			content_id = "hotspot",
			pass_type = "hotspot",
			content = {
				on_hover_sound = "wwise/events/ui/play_ui_mouseover",
				on_pressed_sound = "wwise/events/ui/play_ui_click",
			},
		},
		{
			pass_type = "rect",
			style_id = "background",
			visibility_function = visible,
			change_function = row_background_change,
			style = {
				color = { 210, 24, 29, 31 },
				offset = { 0, 0, 0 },
			},
		},
		{
			pass_type = "rect",
			style_id = "check_border",
			visibility_function = visible,
			style = {
				color = { 255, 150, 160, 160 },
				horizontal_alignment = "left",
				vertical_alignment = "center",
				size = { 28, 28 },
				offset = { 14, 0, 2 },
			},
		},
		{
			pass_type = "rect",
			style_id = "check_fill",
			visibility_function = selected_visible,
			style = {
				color = { 255, 196, 157, 55 },
				horizontal_alignment = "left",
				vertical_alignment = "center",
				size = { 20, 20 },
				offset = { 18, 0, 3 },
			},
		},
		{
			pass_type = "text",
			value = "✓",
			visibility_function = selected_visible,
			style = {
				font_size = 22,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "left",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
				text_color = { 255, 18, 22, 20 },
				size = { 28, 28 },
				offset = { 14, 0, 4 },
			},
		},
		{
			pass_type = "texture",
			style_id = "icon",
			value = "content/ui/materials/frames/talents/talent_icon_container",
			visibility_function = icon_visible,
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				size = { 42, 42 },
				material_values = {
					frame = "content/ui/textures/frames/horde/hex_frame_horde",
					icon_mask = "content/ui/textures/frames/horde/hex_frame_horde_mask",
					intensity = 0,
					saturation = 1,
					use_gradient = 0,
				},
				offset = { 54, 0, 3 },
			},
		},
		{
			pass_type = "text",
			style_id = "label",
			value = "",
			value_id = "label",
			visibility_function = visible,
			change_function = row_text_change,
			style = {
				font_size = 20,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "left",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
				text_color = { 255, 205, 215, 215 },
				size = { ROW_WIDTH - 122, ROW_HEIGHT },
				offset = { 106, 0, 4 },
			},
		},
	}, scenegraph_id)
end

local function detail_icon_definition(scenegraph_id)
	return UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "icon",
			value = "content/ui/materials/frames/talents/talent_icon_container",
			visibility_function = icon_visible,
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
			size = { 80, 80 },
				material_values = {
					frame = "content/ui/textures/frames/horde/hex_frame_horde",
					icon_mask = "content/ui/textures/frames/horde/hex_frame_horde_mask",
					intensity = 0,
					saturation = 1,
					use_gradient = 0,
				},
				offset = { 0, 0, 3 },
			},
		},
	}, scenegraph_id)
end

local function detail_text_definition(scenegraph_id, font_size, vertical_alignment, color)
	return UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "text",
			value = "",
			value_id = "text",
			style = {
				font_size = font_size,
				font_type = "proxima_nova_bold",
				horizontal_alignment = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment = vertical_alignment or "top",
				vertical_alignment = "center",
				text_color = color or { 255, 220, 225, 225 },
				offset = { 0, 0, 3 },
			},
		},
	}, scenegraph_id)
end

local function panel_background_definition(scenegraph_id, color)
	return UIWidget.create_definition({
		{
			pass_type = "rect",
			style = {
				color = color,
				offset = { 0, 0, 0 },
			},
		},
		{
			pass_type = "texture",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = { 255, 132, 116, 82 },
				offset = { 0, 0, 2 },
				scale_to_material = true,
			},
		},
	}, scenegraph_id)
end

local FILTERS = { "all", "selected", "class", "generic", "family" }
local function inject_definitions()
	local scenegraph = Definitions.scenegraph_definition
	local widgets = Definitions.widget_definitions

	if scenegraph.tamm_mortis_panel then
		return
	end

	-- One page beneath the shared native tabs. The canvas is a layout node,
	-- with no dimmer, floating frame, or second close button.
	scenegraph.tamm_mortis_panel = {
		horizontal_alignment = "center",
		parent = "canvas",
		vertical_alignment = "center",
		size = { PANEL_WIDTH, PANEL_HEIGHT },
		position = { 0, 0, 0 },
	}
	scenegraph.tamm_mortis_title = {
		horizontal_alignment = "left",
		parent = "tamm_mortis_panel",
		vertical_alignment = "top",
		size = { 680, 44 },
		position = { 0, 0, 3 },
	}
	scenegraph.tamm_mortis_status = {
		horizontal_alignment = "right",
		parent = "tamm_mortis_panel",
		vertical_alignment = "top",
		size = { 1000, 42 },
		position = { 0, 0, 3 },
	}
	scenegraph.tamm_mortis_family_label = {
		horizontal_alignment = "left",
		parent = "tamm_mortis_panel",
		vertical_alignment = "top",
		size = { 126, 40 },
		position = { 0, 64, 3 },
	}
	scenegraph.tamm_mortis_context = {
		horizontal_alignment = "left",
		parent = "tamm_mortis_panel",
		vertical_alignment = "top",
		size = { PANEL_WIDTH, 28 },
		position = { 0, 110, 3 },
	}

	for i = 1, #FAMILY_NAMES do
		scenegraph["tamm_mortis_family_" .. i] = {
			horizontal_alignment = "left",
			parent = "tamm_mortis_panel",
			vertical_alignment = "top",
			size = { 154, 40 },
			position = { 132 + (i - 1) * 160, 64, 3 },
		}
	end

    for i, filter in ipairs(FILTERS) do
        local name = "tamm_mortis_filter_" .. filter
        scenegraph[name] = { parent = "tamm_mortis_panel", horizontal_alignment = "left", vertical_alignment = "top",
            size = { 162, 34 }, position = { (i - 1) * 172, 152, 4 } }
        widgets[name] = button_definition(name, "")
    end
	scenegraph.tamm_mortis_list = {
		horizontal_alignment = "left",
		parent = "tamm_mortis_panel",
		vertical_alignment = "top",
		size = { ROW_WIDTH, LIST_HEIGHT },
		position = { 0, 204, 3 },
	}

	for i = 1, VISIBLE_ROWS do
		scenegraph["tamm_mortis_row_" .. i] = {
			horizontal_alignment = "left",
			parent = "tamm_mortis_list",
			vertical_alignment = "top",
			size = { ROW_WIDTH, ROW_HEIGHT },
			position = { 0, (i - 1) * (ROW_HEIGHT + ROW_GAP), 1 },
		}
	end

	scenegraph.tamm_mortis_scrollbar = {
		horizontal_alignment = "right",
		parent = "tamm_mortis_list",
		vertical_alignment = "top",
		size = { ScrollbarPassTemplates.terminal_scrollbar.default_width, LIST_HEIGHT },
		position = { 18, 0, 6 },
	}

	scenegraph.tamm_mortis_detail_panel = {
		horizontal_alignment = "right",
		parent = "tamm_mortis_panel",
		vertical_alignment = "top",
		size = { DETAIL_WIDTH, DETAIL_HEIGHT },
		position = { 0, 160, 3 },
	}
	scenegraph.tamm_mortis_detail_icon = {
		horizontal_alignment = "center",
		parent = "tamm_mortis_detail_panel",
		vertical_alignment = "top",
		size = { 80, 80 },
		position = { 0, 16, 4 },
	}
	scenegraph.tamm_mortis_detail_title = {
		horizontal_alignment = "center",
		parent = "tamm_mortis_detail_panel",
		vertical_alignment = "top",
		size = { DETAIL_WIDTH - 48, 60 },
		position = { 0, 108, 4 },
	}
	scenegraph.tamm_mortis_detail_state = {
		horizontal_alignment = "center",
		parent = "tamm_mortis_detail_panel",
		vertical_alignment = "top",
		size = { DETAIL_WIDTH - 48, 40 },
		position = { 0, 174, 4 },
	}
	scenegraph.tamm_mortis_detail_description = {
		horizontal_alignment = "center",
		parent = "tamm_mortis_detail_panel",
		vertical_alignment = "top",
		size = { DETAIL_WIDTH - 48, DETAIL_HEIGHT - 244 },
		position = { 0, 224, 4 },
	}

	scenegraph.tamm_mortis_clear = {
		horizontal_alignment = "left",
		parent = "tamm_mortis_panel",
		vertical_alignment = "bottom",
		size = { 180, 50 },
		position = { 0, -2, 3 },
	}
	scenegraph.tamm_mortis_scroll_position = {
		horizontal_alignment = "left",
		parent = "tamm_mortis_panel",
		vertical_alignment = "bottom",
		size = { 700, 50 },
		position = { 220, -2, 3 },
	}
	widgets.tamm_mortis_title = text_definition("tamm_mortis_title", 28, "left")
	widgets.tamm_mortis_status = text_definition("tamm_mortis_status", 18, "right")
	widgets.tamm_mortis_family_label = text_definition("tamm_mortis_family_label", 17, "left")
	widgets.tamm_mortis_family_label.content.text = mod:localize("mortis_talent_ui_family_label")
	widgets.tamm_mortis_context = text_definition("tamm_mortis_context", 16, "left")

	for i = 1, #FAMILY_NAMES do
		local family_name = FAMILY_NAMES[i]
		local localization_key = "mortis_talent_ui_family_" .. family_name

		widgets["tamm_mortis_family_" .. i] = button_definition("tamm_mortis_family_" .. i, mod:localize(localization_key))
	end

	for i = 1, VISIBLE_ROWS do
		widgets["tamm_mortis_row_" .. i] = row_definition("tamm_mortis_row_" .. i)
	end

	widgets.tamm_mortis_scrollbar = UIWidget.create_definition(
		ScrollbarPassTemplates.terminal_scrollbar,
		"tamm_mortis_scrollbar",
		{
			axis = 2,
			min_thumb_length = 0.12,
			scroll_speed = 18,
		},
		nil,
		{
			mouse_scroll = {
				scenegraph_id = "tamm_mortis_list",
			},
		}
	)

	widgets.tamm_mortis_detail_panel = panel_background_definition(
		"tamm_mortis_detail_panel",
		{ 235, 15, 20, 22 }
	)
	widgets.tamm_mortis_detail_icon = detail_icon_definition("tamm_mortis_detail_icon")
	widgets.tamm_mortis_detail_title = detail_text_definition(
		"tamm_mortis_detail_title",
		24,
		"center",
		{ 255, 238, 196, 84 }
	)
	widgets.tamm_mortis_detail_state = detail_text_definition(
		"tamm_mortis_detail_state",
		18,
		"center",
		{ 255, 170, 180, 180 }
	)
	widgets.tamm_mortis_detail_description = detail_text_definition(
		"tamm_mortis_detail_description",
		18,
		"top",
		{ 255, 220, 225, 225 }
	)

	widgets.tamm_mortis_clear = button_definition("tamm_mortis_clear", mod:localize("mortis_talent_ui_clear"))
	widgets.tamm_mortis_scroll_position = text_definition("tamm_mortis_scroll_position", 18)
	-- Native UIWidget.init always sets widget.visible=true. Content and pass
	-- gates must remain safe even when DMF disables all lifecycle hooks.
	for name, definition in pairs(widgets) do
		if name:match("^tamm_mortis_") then
			definition.content.visible = false
			for _, pass in ipairs(definition.passes) do
				local original = pass.visibility_function
				pass.visibility_function = function(...)
					return mod:is_enabled() and (not original or original(...))
				end
			end
		end
	end
end

inject_definitions()

local panel_widget_names = {
	"tamm_mortis_title",
	"tamm_mortis_status",
	"tamm_mortis_family_label",
	"tamm_mortis_context",
	"tamm_mortis_detail_panel",
	"tamm_mortis_detail_icon",
	"tamm_mortis_detail_title",
	"tamm_mortis_detail_state",
	"tamm_mortis_detail_description",
	"tamm_mortis_clear",
	"tamm_mortis_scrollbar",
	"tamm_mortis_scroll_position",
}

for i = 1, #FAMILY_NAMES do
	panel_widget_names[#panel_widget_names + 1] = "tamm_mortis_family_" .. i
end

for i = 1, VISIBLE_ROWS do
	panel_widget_names[#panel_widget_names + 1] = "tamm_mortis_row_" .. i
end

for _, filter in ipairs(FILTERS) do panel_widget_names[#panel_widget_names + 1] = "tamm_mortis_filter_" .. filter end

local function set_panel_visible(view, visible_state)
	local was_open = view._tamm_mortis_panel_open == true
	local is_open = visible_state == true

	view._tamm_mortis_panel_open = is_open

	for i = 1, #panel_widget_names do
		local widget = view._widgets_by_name[panel_widget_names[i]]

		if widget then
			widget.visible = is_open
			widget.content.visible = is_open
		end
	end

	local summary_button = view._widgets_by_name.summary_button

	if summary_button and summary_button.content.hotspot then
		if is_open and not was_open then
			view._tamm_summary_button_was_disabled = summary_button.content.hotspot.disabled == true
		elseif was_open and not is_open then
			summary_button.content.hotspot.disabled = view._tamm_summary_button_was_disabled == true
			view._tamm_summary_button_was_disabled = nil
		end

		if is_open then
			summary_button.content.hotspot.disabled = true
		end
	end
end

local function entry_source_label(entry)
	if not entry then
		return ""
	end

	if entry.source_kind == "class" then
		local requirement = entry.source_requirement or "class"

		return mod:localize("mortis_talent_ui_source_class_" .. requirement)
	elseif entry.source_kind == "generic" then
		return mod:localize("mortis_talent_ui_source_generic")
	elseif entry.source_kind == "family" then
		local family_key = "mortis_talent_ui_family_" .. tostring(entry.source_family or "generic")
		local family_name = mod:localize(family_key)

		if family_name == family_key then
			family_name = tostring(entry.source_family or "")
		end

		return mod:localize("mortis_talent_ui_source_family", family_name)
	end

	return mod:localize("mortis_talent_ui_source_stale")
end

local function localized_archetype_name(archetype_name)
	if type(archetype_name) ~= "string" or archetype_name == "" then
		return mod:localize("mortis_talent_ui_unknown_archetype")
	end

	if rawget(_G, "Localize") then
		local localization_key = "loc_class_" .. archetype_name .. "_name"
		local success, localized = pcall(Localize, localization_key)

		if success
			and type(localized) == "string"
			and localized ~= ""
			and localized ~= localization_key
			and localized ~= "<" .. localization_key .. ">"
		then
			return localized
		end
	end

	return archetype_name
end

local function refresh_panel(view, snapshot)
	local player = view._preview_player
	snapshot = mod:is_enabled() and (snapshot or mod.mortis_talent_ui_snapshot(player)) or nil
	local available = snapshot ~= nil and view._is_own_player and not view._is_readonly


	if not available then
		set_panel_visible(view, false)

		return
	end

	if not view._tamm_mortis_panel_open then
		return
	end

    local filtered = {}
    local filter = view._mbm_filter or "all"
    for _, entry in ipairs(snapshot.entries) do
        if filter == "all" or filter == "selected" and entry.selected or entry.source_kind == filter then filtered[#filtered + 1] = entry end
    end
    snapshot.entries = filtered
    for _, name in ipairs(FILTERS) do
        local widget = view._widgets_by_name["tamm_mortis_filter_" .. name]
        widget.content.original_text = mod:localize("mortis_filter_" .. name)
        widget.content.hotspot.is_selected = filter == name
    end
	local scrollbar = view._widgets_by_name.tamm_mortis_scrollbar
	local max_scroll = math.max(0, #snapshot.entries - VISIBLE_ROWS)
	local scroll_value = math.clamp(scrollbar.content.value or 0, 0, 1)
	local scroll_index = max_scroll > 0 and math.floor(scroll_value * max_scroll + 0.5) or 0

	scroll_index = math.clamp(scroll_index, 0, max_scroll)
	view._tamm_mortis_scroll_index = scroll_index
	view._tamm_mortis_max_scroll = max_scroll
	scrollbar.content.area_length = #snapshot.entries
	scrollbar.content.scroll_length = max_scroll
	scrollbar.content.scroll_amount = 1 / math.max(1, max_scroll)
	scrollbar.content.value = max_scroll > 0 and scroll_value or 0

	local first_index = scroll_index + 1
	local last_index = math.min(#snapshot.entries, first_index + VISIBLE_ROWS - 1)

	view._widgets_by_name.tamm_mortis_title.content.text = mod:localize("mortis_talent_ui_title")

	local status_key

	if package_failed then
		status_key = "mortis_talent_ui_assets_failed"
	elseif not package_ready then
		status_key = "mortis_talent_ui_assets_loading"
	elseif snapshot.is_realms_client and not snapshot.rules_received then
		status_key = "mortis_talent_ui_waiting_host"
	elseif snapshot.is_realms_client and not snapshot.host_enabled then
		status_key = "mortis_talent_ui_host_disabled"
	elseif not snapshot.apply_to_self then
		status_key = "mortis_talent_ui_apply_disabled"
	elseif not snapshot.abilities_ready then
		status_key = "mortis_talent_ui_abilities_waiting"
	else
		status_key = "mortis_talent_ui_direct_apply"
	end

	view._widgets_by_name.tamm_mortis_status.content.text = mod:localize(
		status_key,
		snapshot.selected_count,
		snapshot.limit
	)
	view._widgets_by_name.tamm_mortis_context.content.text = mod:localize(
		"mortis_talent_ui_context",
		localized_archetype_name(snapshot.archetype)
	)
	view._widgets_by_name.tamm_mortis_scroll_position.content.text = #snapshot.entries > 0
		and mod:localize("mortis_talent_ui_scroll_position", first_index, last_index, #snapshot.entries)
		or mod:localize("mortis_talent_ui_no_compatible_buffs")

	for i = 1, #FAMILY_NAMES do
		local family_name = FAMILY_NAMES[i]
		local family_button = view._widgets_by_name["tamm_mortis_family_" .. i]
		local selected = family_name == snapshot.family
		local localization_key = "mortis_talent_ui_family_" .. family_name
		local family_text = mod:localize(localization_key)

		family_button.content.hotspot.is_selected = selected
		family_button.content.original_text = selected
			and mod:localize("mortis_talent_ui_family_selected", family_text)
			or family_text
	end

	local hovered_entry
	local first_visible_entry

	for row_index = 1, VISIBLE_ROWS do
		local widget = view._widgets_by_name["tamm_mortis_row_" .. row_index]
		local entry = snapshot.entries[first_index + row_index - 1]
		local icon_style = widget.style.icon
		local material_values = icon_style.material_values

		widget.visible = entry ~= nil
		widget.content.visible = entry ~= nil
		widget.content.buff_name = entry and entry.buff_name or nil
		widget.content.has_icon = package_ready
			and entry ~= nil
			and type(entry.icon) == "string"
			and entry.icon ~= ""
		widget.content.selected = entry and entry.selected or false
		widget.content.hotspot.disabled = entry == nil or entry.host_banned or not entry.selected and (not entry.valid or snapshot.selected_count >= snapshot.limit)
		widget.content.hotspot.is_selected = entry and entry.selected or false
		widget.content.label = entry and string.format(
			"[%s] %s%s",
			entry_source_label(entry),
			entry.display_name,
			entry.host_banned and mod:localize("diy_host_banned_suffix") or entry.valid and "" or mod:localize("mortis_talent_ui_incompatible_suffix")
		) or ""

		material_values.icon = package_ready and entry and entry.icon or nil
		material_values.gradient_map = package_ready and entry and entry.gradient or nil
		material_values.use_gradient = package_ready and entry and entry.gradient and 1 or 0

		first_visible_entry = first_visible_entry or entry

		if entry and widget.content.hotspot.is_hover then
			hovered_entry = entry
		end
	end

	if hovered_entry then
		view._tamm_mortis_detail_buff_name = hovered_entry.buff_name
	end

	local detail_entry

	if view._tamm_mortis_detail_buff_name then
		for i = 1, #snapshot.entries do
			local entry = snapshot.entries[i]

			if entry.buff_name == view._tamm_mortis_detail_buff_name then
				detail_entry = entry

				break
			end
		end
	end

	detail_entry = detail_entry or first_visible_entry

	if detail_entry then
		view._tamm_mortis_detail_buff_name = detail_entry.buff_name
	end

	local detail_icon = view._widgets_by_name.tamm_mortis_detail_icon
	local detail_title = view._widgets_by_name.tamm_mortis_detail_title
	local detail_state = view._widgets_by_name.tamm_mortis_detail_state
	local detail_description = view._widgets_by_name.tamm_mortis_detail_description
	local detail_material_values = detail_icon.style.icon.material_values

	detail_icon.content.visible = detail_entry ~= nil
	detail_icon.content.has_icon = package_ready
		and detail_entry ~= nil
		and type(detail_entry.icon) == "string"
		and detail_entry.icon ~= ""
	detail_material_values.icon = package_ready and detail_entry and detail_entry.icon or nil
	detail_material_values.gradient_map = package_ready and detail_entry and detail_entry.gradient or nil
	detail_material_values.use_gradient = package_ready and detail_entry and detail_entry.gradient and 1 or 0
	detail_title.content.text = detail_entry
		and detail_entry.display_name
		or mod:localize("mortis_talent_ui_detail_hint")
	detail_description.content.text = detail_entry
		and (detail_entry.description or mod.mortis_talent_ui_description(detail_entry.buff_name)) or ""

	local detail_status = ""

	if detail_entry and detail_entry.host_banned then
        detail_status=mod:localize("diy_host_banned")
	elseif detail_entry and not detail_entry.valid then
		detail_status = mod:localize("mortis_talent_ui_detail_incompatible")
	elseif detail_entry and detail_entry.selected then
		detail_status = mod:localize("mortis_talent_ui_detail_selected")
	elseif detail_entry then
		detail_status = mod:localize("mortis_talent_ui_detail_not_selected")
	end

	detail_state.content.text = detail_entry and string.format(
		"%s · %s",
		entry_source_label(detail_entry),
		detail_status
	) or ""

	local clear = view._widgets_by_name.tamm_mortis_clear

	clear.content.hotspot.disabled = snapshot.editable == false or snapshot.selected_count == 0
    if snapshot.editable == false then
        for i = 1, #FAMILY_NAMES do view._widgets_by_name["tamm_mortis_family_" .. i].content.hotspot.disabled = true end
        for i = 1, VISIBLE_ROWS do view._widgets_by_name["tamm_mortis_row_" .. i].content.hotspot.disabled = true end
        view._widgets_by_name.tamm_mortis_status.content.text = mod:localize("mortis_talent_preselect_locked")
    end
end

local function open_panel(view)
	if not mod:is_enabled() or not view._tamm_mortis_initialized or not mod.mortis_talent_ui_available(view._preview_player) then
		return
	end

	local snapshot = mod.mortis_talent_ui_snapshot(view._preview_player)
    if not snapshot then return end
    request_mortis_ui_package()

	if view._summary_grid and view._close_summary_window then
		view:_close_summary_window()
	end

	view._tamm_mortis_scroll_index = 0
	view._tamm_mortis_max_scroll = 0
	view._widgets_by_name.tamm_mortis_scrollbar.content.value = 0
	view._tamm_mortis_detail_buff_name = nil
	set_panel_visible(view, true)
	refresh_panel(view, snapshot)
end

mod.mortis_talent_ui_on_enter = function(self)
	if not mod:is_enabled() then return end
	active_views[self] = true
	self._tamm_mortis_initialized = true
	self._tamm_mortis_scroll_index = 0
	self._tamm_mortis_max_scroll = 0
	self._tamm_mortis_detail_buff_name = nil
	set_panel_visible(self, false)

	local widgets = self._widgets_by_name

    for _, filter in ipairs(FILTERS) do
        widgets["tamm_mortis_filter_" .. filter].content.hotspot.pressed_callback = function()
            if not mod:is_enabled() or not self._tamm_mortis_panel_open then return end
            self._mbm_filter = filter; self._tamm_mortis_scrollbar_reset_pending = true
            self._widgets_by_name.tamm_mortis_scrollbar.content.value = 0
            self._tamm_mortis_detail_buff_name = nil; refresh_panel(self)
        end
    end
	widgets.tamm_mortis_clear.content.hotspot.pressed_callback = function()
		if not mod:is_enabled() or not self._tamm_mortis_panel_open then return end
		if mod.clear_mortis_buffs_from_talent_ui(self._preview_player) then
			refresh_panel(self)
		end
	end
	for i = 1, #FAMILY_NAMES do
		local family_name = FAMILY_NAMES[i]
		local family_button = widgets["tamm_mortis_family_" .. i]

		family_button.content.hotspot.pressed_callback = function()
			if not mod:is_enabled() or not self._tamm_mortis_panel_open then return end
			local changed, status, removed_count = mod.set_mortis_family_from_talent_ui(
				self._preview_player,
				family_name
			)

			if changed then
				self._tamm_mortis_scrollbar_reset_pending = true
				self._tamm_mortis_detail_buff_name = nil

				if removed_count and removed_count > 0 then
					mod:notify(mod:localize("mortis_talent_ui_family_pruned", removed_count))
				end
			elseif status == "storage" then
				mod:notify(mod:localize("mortis_selection_storage_error"))
			end

			refresh_panel(self)
		end
	end
	for i = 1, VISIBLE_ROWS do
		local row = widgets["tamm_mortis_row_" .. i]

		row.content.hotspot.pressed_callback = function()
			if not mod:is_enabled() or not self._tamm_mortis_panel_open then return end
			local buff_name = row.content.buff_name

			self._tamm_mortis_detail_buff_name = buff_name
			local changed, status, limit = mod.toggle_mortis_buff_from_talent_ui(
				self._preview_player,
				buff_name
			)

			if not changed and status == "full" then
				mod:notify(mod:localize("mortis_selection_full", limit))
			elseif not changed and status == "incompatible" then
				mod:notify(mod:localize("mortis_selection_incompatible", tostring(buff_name)))
			elseif not changed and status == "storage" then
				mod:notify(mod:localize("mortis_selection_storage_error"))
			end

			refresh_panel(self)
		end
	end

	open_panel(self)
end

mod.mortis_talent_ui_on_exit = function(self)
	set_panel_visible(self, false)
	active_views[self] = nil
	self._tamm_mortis_initialized = nil
	mod.release_mortis_talent_ui_package()
end

mod.cleanup_mortis_talent_ui = function()
	for view in pairs(active_views) do
		set_panel_visible(view, false)
		view._tamm_mortis_initialized = nil
		view._tamm_mortis_scrollbar_reset_pending = nil
		view._tamm_mortis_detail_buff_name = nil
		for name, widget in pairs(view._widgets_by_name) do
			if name:match("^tamm_mortis_") then
				widget.visible = false
				widget.content.visible = false
				if view._ui_renderer then UIWidget.set_visible(widget, view._ui_renderer, false) end
				if widget.content.hotspot then
					widget.content.hotspot.pressed_callback = nil
					widget.content.hotspot.on_pressed = nil
				end
			end
		end
	end
	active_views = setmetatable({}, { __mode = "k" })
	mod.release_mortis_talent_ui_package()
end

function MortisView:update(dt, t, input_service)
	-- A native view may have opened while DMF had this mod disabled.
	if not self._tamm_mortis_initialized then mod.mortis_talent_ui_on_enter(self) end
	local pass_input, pass_draw = MortisView.super.update(self, dt, t, input_service)

	if self._tamm_mortis_panel_open then
		local scrollbar = self._widgets_by_name.tamm_mortis_scrollbar

		if self._tamm_mortis_scrollbar_reset_pending then
			self._tamm_mortis_scrollbar_reset_pending = false
			scrollbar.content.value = 0
			self._tamm_mortis_scroll_index = 0
		end

		local max_scroll = self._tamm_mortis_max_scroll or 0
		local value = scrollbar and math.clamp(scrollbar.content.value or 0, 0, 1) or 0
		local scroll_index = max_scroll > 0 and math.floor(value * max_scroll + 0.5) or 0

		if scroll_index ~= (self._tamm_mortis_scroll_index or 0) then
			self._tamm_mortis_detail_buff_name = nil
			refresh_panel(self)
		end
	end

	self._tamm_mortis_refresh_elapsed = (self._tamm_mortis_refresh_elapsed or 0) + dt

	if self._tamm_mortis_refresh_elapsed >= 0.25 then
		self._tamm_mortis_refresh_elapsed = 0
		refresh_panel(self)
	end

	return pass_input, pass_draw
end

function MortisView:init(settings, context)
    self._context = context
    self._preview_player = context.player
    self._is_own_player = context.player == Managers.player:local_player_safe(1)
    self._is_readonly = false
    -- UIWidget and UIScenegraph create their own mutable instances. This
    -- module's template is built once and never edited by an open view.
    MortisView.super.init(self, Definitions, settings, context)
    self._pass_input, self._pass_draw = true, true
end
function MortisView:on_enter()
    MortisView.super.on_enter(self)
    mod.mortis_talent_ui_on_enter(self)
end
function MortisView:on_exit()
    mod.mortis_talent_ui_on_exit(self)
    MortisView.super.on_exit(self)
end
mod.workspace_page = { view_name = "mbm_workspace_mortis_view",
    available = function(player)
        return mod.mortis_talent_ui_available(player)
    end }
mod.workspace_pages = { { id = "mortis", order = 50,
    label = function() return mod:localize("workspace_mortis") end, page = mod.workspace_page,
    applies = mod.mortis_talent_ui_available } }
mod:add_require_path("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_talent_ui")
mod:register_view({ view_name = mod.workspace_page.view_name,
    view_settings = { class = "MBMWorkspaceMortisView", path = "MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_talent_ui",
        package = "packages/ui/views/talent_builder_view/talent_builder_view", state_bound = true,
        init_view_function = function() return true end }, view_transitions = {} })
return MortisView
