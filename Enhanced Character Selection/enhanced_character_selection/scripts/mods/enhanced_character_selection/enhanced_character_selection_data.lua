local mod = get_mod("enhanced_character_selection")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,
	options = {
        widgets = {
            {
                setting_id = "anim_type",
                type = "dropdown",
                default_value = "both_poses",
                options = {
                    { text = "both_poses", value = "both_poses" },
                    { text = "end_poses", value = "end_poses" },
                    { text = "wpn_poses", value = "wpn_poses" },
                },
            },
            {
                setting_id = "wpn_anim_type",
                type = "dropdown",
                default_value = "both_wpn_poses",
                options = {
                    { text = "both_wpn_poses", value = "both_wpn_poses" },
                    { text = "wpn_ranged_poses", value = "wpn_ranged_poses" },
                    { text = "wpn_melee_poses", value = "wpn_melee_poses" },
                },
            },
        }
    }
}