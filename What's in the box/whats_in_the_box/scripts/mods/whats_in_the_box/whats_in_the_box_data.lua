local mod = get_mod("whats_in_the_box")

local effect_defs = {
    cooldown = { setting = "show_cooldown", default = true },
    cooldown_melee = { setting = "show_cooldown_melee", default = true },
    cooldown_ranged = { setting = "show_cooldown_ranged", default = true },
    attack_speed = { setting = "show_attack_speed", default = true },
    weapon_swap_speed = { setting = "show_weapon_swap_speed", default = false },
    stamina_cost = { setting = "show_stamina_cost", default = false },
    reload_speed = { setting = "show_reload_speed", default = true },
    recoil = { setting = "show_recoil", default = false },
    movement_speed = { setting = "show_movement_speed", default = true },
    dodge_distance = { setting = "show_dodge_distance", default = false },
    dodge_speed = { setting = "show_dodge_speed", default = false },
    dodge_recovery_speed = { setting = "show_dodge_recovery_speed", default = false },
    toughness_regen = { setting = "show_toughness_regen", default = true },
    damage_taken = { setting = "show_damage_taken", default = true },
    replenish_toughness = { setting = "show_replenish_toughness", default = true },
	replenish_toughness_1sec = { setting = "show_replenish_toughness_1sec", default = true },
    strength = { setting = "show_strength", default = true },
    finesse = { setting = "show_finesse", default = true },
    rending = { setting = "show_rending", default = true },
    crit_chance = { setting = "show_crit_chance", default = true },
    stun_immunity = { setting = "show_stun_immunity", default = true },
    slowdown_immunity = { setting = "show_slowdown_immunity", default = true },
	peril_generation = { setting = "show_peril_generation", default = true },
	quell_rate = { setting = "show_quell_rate", default = true },
	charge_time = { setting = "show_charge_time", default = true },
}

local effects_sub_widgets = {}
for _, def in pairs(effect_defs) do
    table.insert(effects_sub_widgets, {
        setting_id = def.setting,
        type = "checkbox",
        default_value = def.default,
    })
end

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,

    options = {
        widgets = {
            {
                setting_id = "display_settings_group",
                type = "group",
                text = "Display Settings",
                sub_widgets = {
                    { setting_id = "use_colors", type = "checkbox", default_value = true },

                    {
                        setting_id = "show_distance",
                        type = "numeric",
                        default_value = 10,
                        range = { 4, 15 },
                    },
					
					 {
						setting_id = "font_type",
						type = "dropdown",
						default_value = "proxima_nova_bold",
						options = {
							{ text = "font_machine_medium", value = "machine_medium" },
							{ text = "font_proxima_nova_medium", value = "proxima_nova_medium" },
							{ text = "font_proxima_nova_bold", value = "proxima_nova_bold" },
							{ text = "font_itc_novarese_medium", value = "itc_novarese_medium" },
							{ text = "font_itc_novarese_bold", value = "itc_novarese_bold" },
						},
					},

                    {
                        setting_id = "font_size",
                        type = "numeric",
                        default_value = 25,
                        range = { 15, 40 },
                    },
                },
            },
            {
                setting_id = "effects_group",
                type = "group",
                text = "Show Effects",
                sub_widgets = effects_sub_widgets,
            },
        },
    },
}
