local mod = get_mod("ZipIt")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
        widgets = {
            { setting_id = "disableAll", type = "checkbox", default_value = false, },
			{ setting_id = "subtitles", type = "checkbox", default_value = false, },
			{ setting_id = "debug", type = "checkbox", default_value = false, },
            {
                setting_id = "hub_toggles",
                tooltip = "hub_toggles_tooltip",
                type = "group",
                sub_widgets = {
                    { setting_id = "hub_radio", type = "checkbox", default_value = false, },
                    { setting_id = "hub_vox", type = "checkbox", default_value = false, },
                    { setting_id = "hub_soldier", type = "checkbox", default_value = false, },
                    { setting_id = "hub_conversation", type = "checkbox", default_value = false, },
                    { setting_id = "hub_hallowette", type = "checkbox", default_value = false, },
                    { setting_id = "hub_siremelk", type = "checkbox", default_value = false, },
                    { setting_id = "hub_commissary", type = "checkbox", default_value = false, },
                    { setting_id = "hub_krall", type = "checkbox", default_value = false, },
                    { setting_id = "hub_armoury", type = "checkbox", default_value = false, },
                    { setting_id = "hub_hadron", type = "checkbox", default_value = false, },
                    { setting_id = "hub_sefoni", type = "checkbox", default_value = false, },
                    { setting_id = "hub_hestia", type = "checkbox", default_value = false, },
                }
            },
            {
                setting_id = "mission_toggles",
                tooltip = "mission_toggles_tooltip",
                type = "group",
                sub_widgets = {
                    { setting_id = "mission_brief", type = "checkbox", default_value = false, },
                    { setting_id = "mission_info", type = "checkbox", default_value = false, },
                    { setting_id = "mission_conversation", type = "checkbox", default_value = false, },
                    { setting_id = "mission_lore", type = "checkbox", default_value = false, },
                }
            },
            {
                setting_id = "enemy_toggles",
                tooltip = "enemy_toggles_tooltip",
                type = "group",
                sub_widgets = {
                    { setting_id = "enemy_demonhost", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_flamer", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_flamer_spawned", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_fire_grenadier", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_fire_grenadier_spawn", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_gas_grenadier", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_gas_grenadier_spawn", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_gunner", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_berzerker", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_netgunner", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_netgunner_spawn", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_infantry", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_mauler", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_shooter", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_shotgunner", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_bulwark", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_crusher", type = "checkbox", default_value = true, },
                    { setting_id = "enemy_reaper", type = "checkbox", default_value = true, },
                }
            },
            {
                setting_id = "player_toggles",
                tooltip = "player_toggles_tooltip",
                type = "group",
                sub_widgets = {
                    { setting_id = "player_death", type = "checkbox", default_value = false, },
                    { setting_id = "player_ability", type = "checkbox", default_value = false, },
                    { setting_id = "player_kill", type = "checkbox", default_value = false, },
                    { setting_id = "player_headshot", type = "checkbox", default_value = false, },
                    { setting_id = "player_horde", type = "checkbox", default_value = false, },
                    { setting_id = "player_tag_item", type = "checkbox", default_value = false, },
                    { setting_id = "player_tag_enemy", type = "checkbox", default_value = false, },
                    { setting_id = "player_look", type = "checkbox", default_value = false, },
                    { setting_id = "player_throw", type = "checkbox", default_value = false, },
                    { setting_id = "player_wheel", type = "checkbox", default_value = false, },
                    { setting_id = "player_blitz", type = "checkbox", default_value = false, },
                    { setting_id = "player_info", type = "checkbox", default_value = false, },
                }
            },
            {
                setting_id = "team_toggles",
                tooltip = "team_toggles_tooltip",
                type = "group",
                sub_widgets = {
                    { setting_id = "team_advice", type = "checkbox", default_value = false, },
                    { setting_id = "team_help", type = "checkbox", default_value = false, },
                    { setting_id = "team_warning", type = "checkbox", default_value = false, },
                    { setting_id = "team_hacking", type = "checkbox", default_value = false, },
                    { setting_id = "team_revive", type = "checkbox", default_value = false, },
                    { setting_id = "team_downed", type = "checkbox", default_value = false, },
                    { setting_id = "team_monster", type = "checkbox", default_value = false, },
                }
            },
            {
                setting_id = "misc",
                tooltip = "team_toggles_tooltip",
                type = "group",
                sub_widgets = {
                    { setting_id = "misc_medicae", type = "checkbox", default_value = false, },
                }
            },
        }
    }
}
