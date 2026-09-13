local mod = get_mod("GhostHost")

-- What the ghost host looks at while the squad plays.
-- NOTE: a dropdown default MUST be one of its own options, otherwise DMF
-- rejects the whole options table and the mod loses every setting.
local function camera_mode_options()
	return {
		{ text = "camera_static", value = "static" },
		{ text = "camera_spectate", value = "spectate" },
	}
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,

	options = {
		widgets = {
			{
				setting_id = "camera_mode",
				type = "dropdown",
				default_value = "static",
				options = camera_mode_options(),
				tooltip = "camera_mode_description",
			},
			{
				setting_id = "esc_opens_menu",
				type = "checkbox",
				default_value = true,
				tooltip = "esc_opens_menu_description",
			},
			{
				setting_id = "disable_loading_overlay",
				type = "checkbox",
				default_value = false,
				tooltip = "disable_loading_overlay_description",
			},
			{
				setting_id = "hide_ghost_panel",
				type = "checkbox",
				default_value = true,
				tooltip = "hide_ghost_panel_description",
			},
			{
				setting_id = "bot_target_ignores_ghost",
				type = "checkbox",
				default_value = true,
				tooltip = "bot_target_ignores_ghost_description",
			},
			{
				setting_id = "announce_on_start",
				type = "checkbox",
				default_value = true,
				tooltip = "announce_on_start_description",
			},
			{
				setting_id = "allow_experimental_modes",
				type = "checkbox",
				default_value = false,
				tooltip = "allow_experimental_modes_description",
			},
		},
	},
}
