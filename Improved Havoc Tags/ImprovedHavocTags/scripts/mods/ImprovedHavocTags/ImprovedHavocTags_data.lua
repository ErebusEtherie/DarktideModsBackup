local mod = get_mod("ImprovedHavocTags")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
			{
				setting_id = "revert_to_original_names",
				type = "checkbox",
				default_value = false,  -- false = use custom names, true = use original game names
				title = "revert_to_original_names_title",
				tooltip = "revert_to_original_names_tooltip",
			},
            {
                setting_id = "increased_difficulty",
                type = "color",
                default_value = {255, 255, 255, 255},  -- white
                has_alpha = true,
            },
            {
                setting_id = "highest_difficulty",
                type = "color",
                default_value = {255, 255, 255, 255},  -- white
                has_alpha = true,
            },
            {
                setting_id = "bolstering_enemies",
                type = "color",
                default_value = {255, 208, 136, 48},  -- item_rarity_5
                has_alpha = true,
            },
            {
                setting_id = "encroaching_garden",
                type = "color",
                default_value = {255, 138, 43, 226},  -- blue_violet
                has_alpha = true,
                tooltip = "encroaching_garden_tooltip",
            },
            {
                setting_id = "enraged",
                type = "color",
                default_value = {255, 255, 54, 36},  -- ui_red_light
                has_alpha = true,
                tooltip = "enraged_tooltip",
            },
            {
                setting_id = "chaos_ritual",
                type = "color",
                default_value = {255, 0, 255, 0},  -- lime
                has_alpha = true,
            },
            {
                setting_id = "armored_infected",
                type = "color",
                default_value = {255, 70, 130, 180},  -- steel_blue
                has_alpha = true,
            },
            {
                setting_id = "enemies_corrupted",
                type = "color",
                default_value = {255, 128, 128, 0},  -- olive
                has_alpha = true,
            },
            {
                setting_id = "enemies_parasite_headshot",
                type = "color",
                default_value = {255, 255, 160, 122},  -- light_salmon
                has_alpha = true,
            },
            {
                setting_id = "tougher_skin",
                type = "color",
                default_value = {255, 157, 169, 75},  -- citadel_ogryn_camo
                has_alpha = true,
            },
            {
                setting_id = "rotten_armor",
                type = "color",
                default_value = {255, 132, 156, 99},  -- citadel_nurgling_green
                has_alpha = true,
            },
            {
                setting_id = "stimmed_minions",
                type = "color",
                default_value = {255, 255, 242, 0},  -- citadel_dorn_yellow
                has_alpha = true,
            },
            {
                setting_id = "ember",
                type = "color",
                default_value = {255, 160, 82, 45},  -- sienna
                has_alpha = true,
            },
            {
                setting_id = "toxic_gas",
                type = "color",
                default_value = {255, 154, 205, 50},  -- yellow_green
                has_alpha = true,
            },
            {
                setting_id = "toxic_gas_cultist_grenadier",
                type = "color",
                default_value = {255, 154, 205, 50},  -- yellow_green
                has_alpha = true,
            },
            {
                setting_id = "ventilation_purge",
                type = "color",
                default_value = {255, 128, 128, 128},  -- gray
                has_alpha = true,
            },
            {
                setting_id = "ventilation_purge_with_snipers",
                type = "color",
                default_value = {255, 128, 128, 128},  -- gray
                has_alpha = true,
            },
            {
                setting_id = "darkness",
                type = "color",
                default_value = {255, 20, 16, 14},  -- citadel_nuln_oil
                has_alpha = true,
            },
            {
                setting_id = "darkness_hunting_grounds",
                type = "color",
                default_value = {255, 20, 16, 14},  -- citadel_nuln_oil
                has_alpha = true,
            },
        }
    }
}