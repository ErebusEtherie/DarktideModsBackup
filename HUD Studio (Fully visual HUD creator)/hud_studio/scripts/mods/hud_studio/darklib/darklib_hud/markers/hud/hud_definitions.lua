
---@param module DLH_Marker
return function(module)
	local UIWidget = require("scripts/managers/ui/ui_widget")
	local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

	local Definitions = {}

	Definitions.scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		markersRoot = {
			parent = "screen",
			vertical_alignment = "top",
			horizontal_alignment = "left",
			size = { 250, 250 },
			position = { 0, 0, 1 },
		},
	}

	function Definitions.widget_definitions(draw_function)
		return {
			markers = UIWidget.create_definition({
				{
					pass_type = "logic",
					style_id = "markers",
					value = draw_function,
					style = {
						horizontal_alignment = "left",
						vertical_alignment = "top",
						offset = { 0, 0, 1 },
						size = { 250, 250 },
					},
				},
			}, "markersRoot"),
		}
	end

	return Definitions
end
