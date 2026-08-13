

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")

local SCREEN_SIZE = UIWorkspaceSettings.screen.size

---@param Module DLH_SettingsMenu
---@param mod DL_Mod
---@param Schema DLH_SettingsMenuSchema
return function(Module, mod, Schema)
	if Module.hud_definitions then
		return Module.hud_definitions
	end

	local C = Module.constants
	local Layout = Module.layout_manager
	local Passes = Module.passes

	local shortest = math.min(C.PANEL_WIDTH, C.PANEL_HEIGHT)

	local scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,

		tooltip = {
			parent = "screen",
			horizontal_alignment = "center",
			vertical_alignment = "center",
			size = { C.TOOLTIP_WIDTH, C.TOOLTIP_MIN_HEIGHT },
			position = { 0, 0, C.Z_TOOLTIP },
		},

		panel = {
			parent = "screen",
			horizontal_alignment = "center",
			vertical_alignment = "center",
			size = { C.PANEL_WIDTH, C.PANEL_HEIGHT },
			position = { C.PANEL_OFFSET_X, C.PANEL_OFFSET_Y, C.Z_PANEL },
		},

		tabs_bg = {
			parent = "panel",
			horizontal_alignment = "left",
			vertical_alignment = "bottom",
			size = { C.TAB_COL_WIDTH + C.TAB_COL_GAP, C.PANEL_HEIGHT - 80 },
			position = { 14, -13, C.Z_TAB_BG },
		},

		dropdown_popup = {
			parent = "panel",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { 200, C.DROPDOWN_OPTION_HEIGHT * C.DROPDOWN_MAX_VISIBLE },
			position = { 0, 0, C.Z_DROPDOWN },
		},
	}

	local function add_node(name, rect)
		scenegraph_definition[name] = {
			parent = "panel",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { rect.w, rect.h },
			position = { rect.x, rect.y, C.Z_WIDGET },
		}
	end

	add_node("scrollbar", Layout.scrollbar_rect())

	local controls = Module.schema_builder.all_controls(Schema)
	for i = 1, #Module.tabs do
		local tab = Module.tabs[i]
		local header_h = Layout.tab_header_height(tab)
		for j = 1, #tab.controls do
			local widget = tab.controls[j]
			add_node(
				"cell_" .. widget.key,
				Layout.cell_rect(widget.col, widget.row, widget.col_span, widget.row_span, header_h)
			)
		end
	end

	if Module.has_tabs then
		for i = 1, #Module.tabs do
			local tab = Module.tabs[i]
			add_node("tab_" .. tab.id, Layout.tab_rect(i))

			if tab.title_text or tab.description_text then
				add_node("tab_header_" .. tab.id, Layout.tab_header_rect(tab))
			end
		end
	end

	local reset_all_rect, tab_reset_rect, fancy_rect
	if Module.has_tabs then
		reset_all_rect = Layout.reset_all_rect()
		add_node("reset_all", reset_all_rect)

		tab_reset_rect = Layout.tab_reset_rect(Module.tabs[1])
		add_node("tab_reset", tab_reset_rect)

		fancy_rect = Layout.fancy_transitions_rect()
		add_node("fancy_transitions", fancy_rect)
	end

	local widget_definitions = {
		tooltip = UIWidget.create_definition(Passes.tooltip(), "tooltip"),
		scrollbar = UIWidget.create_definition(Passes.scrollbar(), "scrollbar"),
		dropdown_popup = UIWidget.create_definition(Passes.dropdown_popup(), "dropdown_popup"),
	}

	if reset_all_rect then
		widget_definitions.reset_all = UIWidget.create_definition(
			Passes.reset_button({ x = 0, y = 0, w = reset_all_rect.w, h = reset_all_rect.h }, C.STRINGS.RESET_ALL),
			"reset_all"
		)
	end

	if tab_reset_rect then
		widget_definitions.tab_reset = UIWidget.create_definition(
			Passes.reset_button({ x = 0, y = 0, w = tab_reset_rect.w, h = tab_reset_rect.h }, C.STRINGS.RESET_TAB),
			"tab_reset"
		)
	end

	if fancy_rect then
		widget_definitions.fancy_transitions = UIWidget.create_definition(
			Passes.fancy_checkbox({ x = 0, y = 0, w = fancy_rect.w, h = fancy_rect.h }, mod:localize("transitions")),
			"fancy_transitions"
		)
	end

	for name, passes in pairs(Passes.chrome) do
		if scenegraph_definition[name] then
			widget_definitions[name] = UIWidget.create_definition(passes, name)
		end
	end

	for i = 1, #controls do
		local widget = controls[i]
		local passes = Passes.for_control(widget)
		if passes then
			widget_definitions["widget_" .. widget.key] = UIWidget.create_definition(passes, "cell_" .. widget.key)
		end
	end

	if Module.has_tabs then
		for i = 1, #Module.tabs do
			local tab = Module.tabs[i]

			local label = tab.label_key and mod:localize(tab.label_key) or Module.title or C.STRINGS.TITLE
			widget_definitions["tab_" .. tab.id] = UIWidget.create_definition(
				ButtonPassTemplates.terminal_button,
				"tab_" .. tab.id,
				{ original_text = string.upper(label) },
				{ C.TAB_COL_WIDTH, C.TAB_HEIGHT },
				{ text = { font_size = C.TAB_FONT_SIZE, font_type = Passes.font.tab } }
			)

			if tab.title_text or tab.description_text then
				widget_definitions["tab_header_" .. tab.id] =
					UIWidget.create_definition(Passes.tab_header(tab), "tab_header_" .. tab.id)
			end
		end
	end

	local SettingsMenuHudDefinitions = {
		scenegraph_definition = scenegraph_definition,
		widget_definitions = widget_definitions,
	}

	Module.hud_definitions = SettingsMenuHudDefinitions

	return SettingsMenuHudDefinitions
end
