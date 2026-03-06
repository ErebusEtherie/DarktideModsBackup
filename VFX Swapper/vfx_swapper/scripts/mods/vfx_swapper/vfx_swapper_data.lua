local mod = get_mod("vfx_swapper")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,

	options = {
		widgets = {
			{
				setting_id = "vfx_replacement_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "replace_gas_vfx",
						type = "dropdown",
						default_value = "content/fx/particles/weapons/grenades/gas_grenade_ground",
						options = {
							{ text = "gas_vfx_default", value = "content/fx/particles/enemies/cultist_blight_grenadier/cultist_gas_grenade" },
							{ text = "gas_vfx_ground_cloud", value = "content/fx/particles/weapons/grenades/gas_grenade_ground" },
							{ text = "gas_vfx_beast_goo", value = "content/fx/particles/liquid_area/nurgle_corruption_goo" },
							{ text = "green_fire_short", value = "content/fx/particles/liquid_area/fire_lingering_cultist" },
							{ text = "fire_short", value = "content/fx/particles/liquid_area/fire_lingering" },
							{ text = "summoning_circle", value = "content/fx/particles/enemies/renegade_psyker/renegade_psyker_summoning_circle" },
							{ text = "fire_vfx_beast_slime", value = "content/fx/particles/liquid_area/beast_of_nurgle_slime" }
						},
					},
					{
						setting_id = "replace_renegade_grenade_vfx",
						type = "dropdown",
						default_value = "content/fx/particles/liquid_area/fire_lingering",
						options = {
							{ text = "grenade_vfx_default", value = "content/fx/particles/weapons/grenades/flame_grenade_hostile_fire_lingering" },
							{ text = "gas_vfx_ground_cloud", value = "content/fx/particles/weapons/grenades/gas_grenade_ground" },
							{ text = "summoning_circle", value = "content/fx/particles/enemies/renegade_psyker/renegade_psyker_summoning_circle" },
							{ text = "green_fire_short", value = "content/fx/particles/liquid_area/fire_lingering_cultist" },
							{ text = "fire_short", value = "content/fx/particles/liquid_area/fire_lingering" },
							{ text = "curroptor_goo", value = "content/fx/particles/liquid_area/corruptor_nurgle_goo"}
						},
					},
					{
						setting_id = "replace_renegade_flamer_vfx",
						type = "dropdown",
						default_value = "content/fx/particles/liquid_area/fire_lingering",
						options = {
							{ text = "flamer_vfx_default", value = "content/fx/particles/enemies/renegade_flamer/renegade_flamer_fire_lingering" },
							{ text = "gas_vfx_ground_cloud", value = "content/fx/particles/weapons/grenades/gas_grenade_ground" },
							{ text = "summoning_circle", value = "content/fx/particles/enemies/renegade_psyker/renegade_psyker_summoning_circle" },
							{ text = "green_fire_short", value = "content/fx/particles/liquid_area/fire_lingering_cultist" },
							{ text = "fire_short", value = "content/fx/particles/liquid_area/fire_lingering" },
							{ text = "curroptor_goo", value = "content/fx/particles/liquid_area/corruptor_nurgle_goo"}
						},
					},
					{
						setting_id = "replace_cultist_flamer_vfx",
						type = "dropdown",
						default_value = "content/fx/particles/liquid_area/fire_lingering_cultist",
						options = {
							{ text = "flamer_vfx_default", value = "content/fx/particles/weapons/grenades/flame_grenade_hostile_fire_lingering_green" },
							{ text = "gas_vfx_ground_cloud", value = "content/fx/particles/weapons/grenades/gas_grenade_ground" },
							{ text = "summoning_circle", value = "content/fx/particles/enemies/renegade_psyker/renegade_psyker_summoning_circle" },
							{ text = "green_fire_short", value = "content/fx/particles/liquid_area/fire_lingering_cultist" },
							{ text = "fire_short", value = "content/fx/particles/liquid_area/fire_lingering" },
							{ text = "curroptor_goo", value = "content/fx/particles/liquid_area/corruptor_nurgle_goo"}
						},
					},
					{
						setting_id = "replace_immolation_vfx",
						type = "dropdown",
						default_value = "content/fx/particles/liquid_area/beast_of_nurgle_slime",
						options = {
							{ text = "fire_vfx_default", value = "content/fx/particles/weapons/grenades/fire_grenade/fire_grenade_player_lingering_fire" },
							{ text = "fire_vfx_beast_slime", value = "content/fx/particles/liquid_area/beast_of_nurgle_slime" },
							{ text = "fire_vfx_beast_goo", value = "content/fx/particles/liquid_area/nurgle_corruption_goo" },
							{ text = "gas_vfx_ground_cloud", value = "content/fx/particles/weapons/grenades/gas_grenade_ground" },
							{ text = "curroptor_goo", value = "content/fx/particles/liquid_area/corruptor_nurgle_goo"}
						},
					},
					{
						setting_id = "replace_rotten_armor",
						type = "dropdown",
						default_value = "content/fx/particles/weapons/grenades/gas_grenade_ground",
						options = {
							{ text = "rotten_vfx_default", value = "content/fx/particles/weapons/grenades/gas_grenade_gas" },
							{ text = "gas_vfx_ground_cloud", value = "content/fx/particles/weapons/grenades/gas_grenade_ground" },
							{ text = "green_fire_short", value = "content/fx/particles/liquid_area/fire_lingering_cultist" },
							{ text = "fire_short", value = "content/fx/particles/liquid_area/fire_lingering" },
							{ text = "summoning_circle", value = "content/fx/particles/enemies/renegade_psyker/renegade_psyker_summoning_circle" },
							{ text = "vfx_circle_only", value = "CIRCLE_ONLY" },
						},
					},
					{
						setting_id = "replace_havoc_enemy_corruption_liquid",
						type = "dropdown",
						default_value = "content/fx/particles/enemies/renegade_psyker/renegade_psyker_summoning_circle",
						options = {
							{ text = "blight_vfx_default", value = "content/fx/particles/liquid_area/nurgle_corruption_goo" },
							{ text = "gas_vfx_ground_cloud", value = "content/fx/particles/weapons/grenades/gas_grenade_ground" },
							{ text = "green_fire_short", value = "content/fx/particles/liquid_area/fire_lingering_cultist" },
							{ text = "fire_short", value = "content/fx/particles/liquid_area/fire_lingering" },
							{ text = "summoning_circle", value = "content/fx/particles/enemies/renegade_psyker/renegade_psyker_summoning_circle" },
							{ text = "vfx_circle_only", value = "CIRCLE_ONLY" },

						},
					},
					{
						setting_id = "replace_broker_tox_grenade",
						type = "dropdown",
						default_value = "content/fx/particles/liquid_area/chem_grenade_player_lingering",
						options = {
							{ text = "vfx_circle_only", value = "CIRCLE_ONLY" },
							{ text = "chemnade_vfx_default", value = "content/fx/particles/liquid_area/chem_grenade_player_lingering" },
							{ text = "gas_vfx_ground_cloud", value = "content/fx/particles/weapons/grenades/gas_grenade_ground" },							
							{ text = "fire_vfx_beast_slime", value = "content/fx/particles/liquid_area/beast_of_nurgle_slime" },
							{ text = "fire_vfx_beast_goo", value = "content/fx/particles/liquid_area/nurgle_corruption_goo" },
							
						},
					},
					{
						setting_id = "replace_fire_barrel_vfx",
						type = "dropdown",
						default_value = "content/fx/particles/liquid_area/fire_lingering",
						options = {
							{ text = "fire_barrel_vfx_default", value = "content/fx/particles/liquid_area/fire_lingering" },
							{ text = "zealot_grenade", value = "content/fx/particles/weapons/grenades/fire_grenade/fire_grenade_player_lingering_fire" },
							-- { text = "fire_barrel_vfx_beast_slime", value = "content/fx/particles/liquid_area/beast_of_nurgle_slime" },
							-- { text = "fire_barrel_vfx_beast_goo", value = "content/fx/particles/liquid_area/nurgle_corruption_goo" },
							-- { text = "gas_vfx_ground_cloud", value = "content/fx/particles/weapons/grenades/gas_grenade_ground" },
							{ text = "curroptor_goo", value = "content/fx/particles/liquid_area/corruptor_nurgle_goo"},
						},
					},
				},
			},
			{
				setting_id = "havoc_toggle_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "disable_rotten_armor_stages",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "disable_rotten_armor_impact",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "disable_corrupted_enemies_color",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "disable_corrupted_enemies_vfx",
						type = "checkbox",
						tooltip =  "corrupted_vfx_tip",
						require_restart = true,
						default_value = false,
					},
					{
						setting_id = "disable_rampaging_vfx",
						type = "checkbox",
						tooltip =  "rampaging_tip",
						require_restart = true,
						default_value = false,
					},
					{
						setting_id = "disable_toxin_death_vfx",
						type = "checkbox",
						tooltip =  "toxin_death_tip",
						default_value = false,
					},
					{
						setting_id = "disable_death_vfx",
						type = "checkbox",
						default_value = false,
					},
				},
			},
			{
				setting_id = "tox_gas_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "disable_toxic_gas",
						type = "checkbox",
						tooltip = "disable_toxic_gas_tip",
						default_value = false,
					},
					{
						setting_id = "disable_coral_vfx",
						type = "checkbox",
						tooltip = "disable_coral_vfx_tip",
						default_value = false,
					},
					{
						setting_id = "disable_toxic_fog",
						type = "checkbox",
						tooltip = "disable_toxic_fog_tip",
						default_value = false,
					},
				},
			},
			{
				setting_id = "circle_indicators_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "rotten_circle_enabled",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "rotten_circle_red",
						type = "numeric",
						default_value = 50,
						range = { 0, 100 },
					},
					{
						setting_id = "rotten_circle_green",
						type = "numeric",
						default_value = 17,
						range = { 0, 100 },
					},
					{
						setting_id = "rotten_circle_blue",
						type = "numeric",
						default_value = 0,
						range = { 0, 100 },
					},
					{
						setting_id = "rotten_circle_alpha",
						type = "numeric",
						default_value = 60,
						range = { 0, 100 },
					},
					{
						setting_id = "blight_circle_enabled",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "blight_circle_red",
						type = "numeric",
						default_value = 10,
						range = { 0, 100 },
					},
					{
						setting_id = "blight_circle_green",
						type = "numeric",
						default_value = 50,
						range = { 0, 100 },
					},
					{
						setting_id = "blight_circle_blue",
						type = "numeric",
						default_value = 10,
						range = { 0, 100 },
					},
					{
						setting_id = "blight_circle_alpha",
						type = "numeric",
						default_value = 60,
						range = { 0, 100 },
					},
					{
						setting_id = "chemnade_circle_enabled",
						type = "checkbox",
						default_value = false,
					},
					{
						setting_id = "chemnade_circle_red",
						type = "numeric",
						default_value = 35,
						range = { 0, 100 },
					},
					{
						setting_id = "chemnade_circle_green",
						type = "numeric",
						default_value = 26,
						range = { 0, 100 },
					},
					{
						setting_id = "chemnade_circle_blue",
						type = "numeric",
						default_value = 10,
						range = { 0, 100 },
					},
					{
						setting_id = "chemnade_circle_alpha",
						type = "numeric",
						default_value = 40,
						range = { 0, 100 },
					},
					{
						setting_id = "circle_count",
						type = "numeric",
						default_value = 1,
						range = { 1, 30 },
					},
				},
			},
		},
	},
}
-- I  wouldn't use these if I were you. 
-- { text = "testvfx", value = "content/fx/particles/enemies/daemonhost/daemonhost_hand_glow" },
-- { text = "test2vfx", value = "content/fx/particles/enemies/buff_gardens_embrace_head" },
-- { text = "test3vfx", value = "content/fx/particles/enemies/buff_gardens_embrace_head_02" },
-- { text = "test4vfx", value = "content/fx/particles/enemies/daemonhost/daemonhost_hand_execution" },
-- { text = "test5vfx", value = "content/fx/particles/enemies/chaos_mutator_daemonhost_shield" },
-- { text = "test6vfx", value = "content/fx/particles/weapons/grenades/twin_grenade_passive" },
-- { text = "test7vfx", value = "content/fx/particles/player_buffs/player_netted_idle" },
-- { text = "test8vfx", value = "content/fx/particles/abilities/ability_radius_aoe" },
-- { text = "gas_grenade_gas", value = "content/fx/particles/weapons/grenades/gas_grenade_gas" },
-- { text = "test6vfx", value = "content/fx/particles/weapons/grenades/twin_grenade_passive" },
