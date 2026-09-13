local mod = get_mod("Bubblelicious")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local scale = 200 - mod:get("hud_element_scale")
local inv_scale = 1 / (scale / 100)

-----------------------------------------------------------------------------------------------------------------
-- HUD Element Definitions --------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

-- relevant info regarding ability hud element in DT source code
-- @scripts/ui/hud/elements/player_ability/hud_element_player_ability.lua
-- @scripts/ui/hud/elements/player_ability/hud_element_player_ability_vertical_definitions.lua

mod.hudsettings = {
	icon_size = { 92 * inv_scale, 80 * inv_scale },
	frame = {
		size = 128 * inv_scale, --same for width & height
		glow_color = { 255, 255, 0, 0 },
		frame_border_color = { 255, 0, 255, 0 }
	},
	icon_position = {
		--placed to the right of teammates in the hud
		378, --horizontal position
		-140, --vertical position
		1
	},
	icon_path = "content/ui/textures/icons/talents/psyker_2/psyker_2_tier_1_1" --hourglass look
}

-- Timer/Counter text settings
local counter_text_style = table.clone(UIFontSettings.hud_body)
counter_text_style.horizontal_alignment = "center"
counter_text_style.vertical_alignment = "center"
counter_text_style.text_horizontal_alignment = "center"
counter_text_style.text_vertical_alignment = "center"
counter_text_style.size = mod.hudsettings.icon_size
counter_text_style.text_color = mod.colors.noshift
counter_text_style.font_type = "machine_medium"
counter_text_style.font_size = 42 * inv_scale
counter_text_style.line_spacing = 1
counter_text_style.offset = { 0, 0, 2 * inv_scale }
counter_text_style.drop_shadow = true

local Definitions = {
	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		icon = {
			parent = "screen",
			vertical_alignment = "bottom",
			horizontal_alignment = "left",
			size = mod.hudsettings.icon_size,
			position = mod.hudsettings.icon_position
		}
	},
	widget_definitions = {
		icon = UIWidget.create_definition({
			{
				value_id = "counter_text",
				style_id = "counter_text",
				pass_type = "text",
				value = "",
				style = counter_text_style
			},
			{
				style_id = "ability_frame_container",
				pass_type = "texture",
				value = "content/ui/materials/icons/talents/hud/combat_container",
				style = {
					material_values = {
						progress = 1,
						talent_icon = mod.hudsettings.icon_path
					},
					offset = { 0, 0, 0 },
					color = { 255, 126, 255, 255 }
				}
			},
			{
				value = "content/ui/materials/icons/talents/hud/combat_frame_inner",
				style_id = "ability_frame_inner",
				pass_type = "texture",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					offset = { 0, 0, 3 * inv_scale },
					color = mod.hudsettings.frame.active_color,
					size = { mod.hudsettings.frame.size, mod.hudsettings.frame.size }
				}
			},
			{
				value = "content/ui/materials/effects/hud/combat_talent_glow",
				style_id = "ability_frame_glow",
				pass_type = "texture",
				style = {
					vertical_alignment = "center",
					horizontal_alignment = "center",
					offset = { 0, 0, 4 * inv_scale },
					color = mod.hudsettings.frame.glow_color,
					size = { mod.hudsettings.frame.size, mod.hudsettings.frame.size }
				}
			},
		}, "icon")
	}
}

return Definitions