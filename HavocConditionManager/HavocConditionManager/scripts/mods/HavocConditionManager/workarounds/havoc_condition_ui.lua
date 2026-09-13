local mod = get_mod("HavocConditionManager")
local UIWidget = require("scripts/managers/ui/ui_widget")
local HavocConditions = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/havoc_conditions")

-- A HUD layout has finite slots even though the mission condition list does not.
local MAX_DISPLAYED_CONDITIONS = 4

local function indexed_id(prefix, index)
	return prefix .. "0" .. index
end

local function truncated_conditions(source)
	if not source or #source <= MAX_DISPLAYED_CONDITIONS then
		return source
	end

	local result = {}

	for i = 1, MAX_DISPLAYED_CONDITIONS do
		result[i] = source[i]
	end

	return result
end

local function call_with_display_conditions(func, self, havoc_data, original_conditions, display_conditions)
	if havoc_data and display_conditions ~= original_conditions then
		havoc_data.circumstances = display_conditions
	end

	local success, error_message = pcall(func, self)

	if havoc_data and display_conditions ~= original_conditions then
		havoc_data.circumstances = original_conditions
	end

	if not success then
		error(error_message)
	end
end

local function set_style_visibility(style, style_id, visible)
	local style_entry = style and style[style_id]

	if style_entry then
		style_entry.visible = visible
	end
end

local tactical_definitions_path = "scripts/ui/hud/elements/tactical_overlay/hud_element_tactical_overlay_definitions"

mod:hook_require(tactical_definitions_path, function (definitions)
	-- The tactical overlay creates this widget from the left-panel definitions,
	-- not from the root widget definitions used by HudElementBase.
	local left_panel_definitions = definitions and definitions.left_panel_widgets_definitions
	local definition = left_panel_definitions and left_panel_definitions.havoc_circumstance_info

	if not definition then
		return
	end

	local function clone_pass(pass_type, source_id, target_id, offset_y)
		if definition.style[target_id] then
			return
		end

		local source_style = definition.style[source_id]

		if not source_style then
			return
		end

		local style = table.clone(source_style)

		style.offset = table.clone(source_style.offset)
		style.offset[2] = offset_y
		style.visible = false

		UIWidget.add_definition_pass(definition, {
			pass_type = pass_type,
			style_id = target_id,
			value_id = target_id,
			value = definition.content[source_id],
			style = style,
		})
	end

	for i = 5, MAX_DISPLAYED_CONDITIONS do
		local offset_y = (i - 1) * 115
		local icon_id = indexed_id("icon_", i)
		local name_id = indexed_id("circumstance_name_", i)
		local description_id = indexed_id("circumstance_description_", i)

		clone_pass("texture", "icon_04", icon_id, offset_y)
		clone_pass("text", "circumstance_name_04", name_id, offset_y)
		clone_pass("text", "circumstance_description_04", description_id, offset_y + 40)
	end
end)

local HudElementTacticalOverlay = require("scripts/ui/hud/elements/tactical_overlay/hud_element_tactical_overlay")

mod:hook(HudElementTacticalOverlay, "_setup_havoc_mutators", function (func, self)
	local havoc_data = self._havoc_data
	local original_conditions = havoc_data and havoc_data.circumstances
	local display_conditions = truncated_conditions(original_conditions)

	call_with_display_conditions(func, self, havoc_data, original_conditions, display_conditions)

	local widget = self._widgets_by_name.havoc_circumstance_info
	local requested_count = display_conditions and #display_conditions or 0

	if widget then
		local available_count = 0

		for i = 1, MAX_DISPLAYED_CONDITIONS do
			local style = widget.style
			local has_slot = style[indexed_id("icon_", i)]
				and style[indexed_id("circumstance_name_", i)]
				and style[indexed_id("circumstance_description_", i)]

			if not has_slot then
				break
			end

			available_count = i
		end

		local displayed_count = math.min(requested_count, available_count)

		widget.num_displayed_mutators = displayed_count
		for i = 1, MAX_DISPLAYED_CONDITIONS do
			local visible = i <= displayed_count
			set_style_visibility(widget.style, indexed_id("icon_", i), visible)
			set_style_visibility(widget.style, indexed_id("circumstance_name_", i), visible)
			set_style_visibility(widget.style, indexed_id("circumstance_description_", i), visible)
		end

		if requested_count > available_count and not self._havoc_condition_manager_missing_havoc_styles_warning then
			self._havoc_condition_manager_missing_havoc_styles_warning = true
			mod:warning("Tactical overlay has %d complete condition style slots but needs %d; clamping the display to prevent a crash", available_count, requested_count)
		end
	end
end)

local lobby_definitions_path = "scripts/ui/views/lobby_view/lobby_view_definitions"

mod:hook_require(lobby_definitions_path, function (definitions)
	local widget_definitions = definitions and definitions.widget_definitions
	local source = widget_definitions and widget_definitions.havoc_circumstance_04

	if not source or source.__havoc_condition_manager then
		return
	end

	source.__havoc_condition_manager = true

	for i = 5, MAX_DISPLAYED_CONDITIONS do
		widget_definitions[indexed_id("havoc_circumstance_", i)] = table.clone(source)
	end
end)

local LobbyView = require("scripts/ui/views/lobby_view/lobby_view")

mod:hook(LobbyView, "_setup_havoc_info", function (func, self)
	local havoc_data = self._havoc_data
	local original_conditions = havoc_data and havoc_data.circumstances
	local display_conditions = truncated_conditions(original_conditions)

	call_with_display_conditions(func, self, havoc_data, original_conditions, display_conditions)

	local displayed_count = display_conditions and #display_conditions or 0

	for i = 1, MAX_DISPLAYED_CONDITIONS do
		local widget = self._widgets_by_name[indexed_id("havoc_circumstance_", i)]

		if widget then
			widget.visible = i <= displayed_count
		end
	end
end)
