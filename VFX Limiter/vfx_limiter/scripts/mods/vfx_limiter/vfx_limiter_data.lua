local mod = get_mod("vfx_limiter")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,

	options = {
		widgets = {
			{
				setting_id = "frag_grenade_vfx",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "krak_grenade_vfx",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "box_grenade_ogryn_vfx",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "frag_bomb_ogryn_vfx",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "stumm_grenade_vfx",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "fire_grenade_vfx",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "rotten_vfx",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "net_elecric_vfx",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "voidstrike_explosion_vfx",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "ritual_vfx",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "scum_stimm_screen",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "scum_rampage_screen",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "scum_сhem_explode",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "vfx_replacement_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "replace_gas_vfx",
						type = "dropdown",
						default_value = "content/fx/particles/enemies/cultist_blight_grenadier/cultist_gas_grenade",
						options = {
							{ text = "gas_vfx_default", value = "content/fx/particles/enemies/cultist_blight_grenadier/cultist_gas_grenade" },
							{ text = "gas_vfx_ground_cloud", value = "content/fx/particles/weapons/grenades/gas_grenade_ground" },
							{ text = "gas_vfx_green_flames", value = "content/fx/particles/weapons/grenades/flame_grenade_hostile_fire_lingering_green" },
							{ text = "gas_vfx_beast_goo", value = "content/fx/particles/liquid_area/nurgle_corruption_goo" },
						},
					},
					{
						setting_id = "replace_immolation_vfx",
						type = "dropdown",
						default_value = "content/fx/particles/weapons/grenades/fire_grenade/fire_grenade_player_lingering_fire",
						options = {
							{ text = "fire_vfx_default", value = "content/fx/particles/weapons/grenades/fire_grenade/fire_grenade_player_lingering_fire" },
							{ text = "fire_vfx_beast_slime", value = "content/fx/particles/liquid_area/beast_of_nurgle_slime" },
							{ text = "fire_vfx_beast_goo", value = "content/fx/particles/liquid_area/nurgle_corruption_goo" },
						},
					},
				},
			},
		},
	},
}
