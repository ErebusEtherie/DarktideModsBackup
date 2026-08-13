

---@param Module DLH_ModMenu
---@param mod DL_Mod
return function(Module, mod)
	if Module.overlay_definitions then
		return Module.overlay_definitions
	end

	local UIWidget = require("scripts/managers/ui/ui_widget")
	local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

	local C = Module.constants

	---@param c argb_table
	local function argb(c)
		return { c[1], c[2], c[3], c[4] }
	end

	local OVERLAY = {

		BG = { 255, 25, 37, 37 },
		TINT = { 200, 190, 210, 180 },
		SHADOW = { 100, 0, 0, 0 },
		TITLE = { 255, 216, 229, 207 },
		TITLE_FONT_SIZE = 48,
		BOOTUP_FONT_SIZE = 14,

		LABEL = "- ACCESS GRANTED -",
	}

	local scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		overlay_panel = {
			parent = "screen",
			horizontal_alignment = "center",
			vertical_alignment = "center",
			size = { C.PANEL_WIDTH, C.PANEL_HEIGHT },
			position = { C.PANEL_OFFSET_X, C.PANEL_OFFSET_Y, 0 },
		},
	}

	local function node_texture(style_id, material, color, z, scale)
		return {
			pass_type = "texture",
			style_id = style_id,
			value = material,
			style = {
				offset = { 0, 0, z or 0 },
				color = argb(color or { 255, 255, 255, 255 }),
				scale_to_material = scale or false,
			},
		}
	end

	local function overlay_passes()
		local passes = {

			{
				pass_type = "texture",
				style_id = "overlay_shadow",
				value = C.MATERIAL.shadow,
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "center",
					scale_to_material = true,
					color = argb(OVERLAY.SHADOW),
					size_addition = { 38, 70 },
					offset = { 14, 0, 0 },
				},
			},

			{
				pass_type = "rect",
				style_id = "overlay_bg",
				style = {
					size = { C.PANEL_WIDTH - 20, C.PANEL_HEIGHT - 20 },
					offset = { 10, 10, 1 },
					color = C.COLOR.CONTENT_PANEL_BG,
				},
			},

			node_texture("overlay_terminal", C.MATERIAL.terminal_basic, C.COLOR.CONTENT_PANEL, 2, true),
			node_texture("overlay_terminal_fluff", C.MATERIAL.vox_fluff, C.COLOR.CONTENT_PANEL, 2, true),

			{
				pass_type = "texture_uv",
				style_id = "overlay_terminal2",
				value = "content/ui/materials/hud/backgrounds/interaction_background",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "center",
					scale_to_material = true,
					color = { 150, 25, 37, 37 },
					size = { C.PANEL_WIDTH - 20, C.PANEL_HEIGHT - 20 },
					size_addition = { -8, -8 },
					offset = { 0, 0, 3 },
					uvs = mod.dl.uv.clip_bottom(0.95),
				},
			},

			{
				pass_type = "text",
				style_id = "bootup_sequence_text",
				value_id = "bootup_sequence_text",
				value = "",
				style = {
					font_type = C.FONTS.bootup_sequence,
					font_size = OVERLAY.BOOTUP_FONT_SIZE,
					text_horizontal_alignment = "left",
					text_vertical_alignment = "top",
					size = { C.PANEL_WIDTH, C.PANEL_HEIGHT },
					offset = { 24, 24, 4 },
					text_color = Color.terminal_text_body(100, true),
				},
			},

			{
				pass_type = "text",
				style_id = "overlay_title",
				value_id = "overlay_title",
				value = OVERLAY.LABEL,
				style = {
					font_type = C.FONTS.overlay_title,
					font_size = OVERLAY.TITLE_FONT_SIZE,
					text_horizontal_alignment = "center",
					text_vertical_alignment = "center",
					size = { C.PANEL_WIDTH, C.PANEL_HEIGHT },
					offset = { 0, 0, 5 },
					text_color = argb(OVERLAY.TITLE),
				},
			},

		}

		return passes
	end

	local widget_definitions = {
		overlay_panel = UIWidget.create_definition(overlay_passes(), "overlay_panel"),
	}

	local OverlayDefinitions = {
		scenegraph_definition = scenegraph_definition,
		widget_definitions = widget_definitions,
	}

	Module.overlay_definitions = OverlayDefinitions

	return OverlayDefinitions
end
