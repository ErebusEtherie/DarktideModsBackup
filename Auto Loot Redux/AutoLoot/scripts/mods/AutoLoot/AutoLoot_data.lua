local mod = get_mod("AutoLoot")
return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
		{
			setting_id  = "other_group",
			type        = "group",
			sub_widgets = {
				{
					setting_id = "open_chests",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "pickup_materials",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "pickup_expedition_materials",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "pickup_event_items",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "pickup_crates",
					type = "checkbox",
					default_value = true,
				},
			}
		},
		{
			setting_id  = "grenadesammo_group",
			type        = "group",
			sub_widgets = {
				{
					setting_id = "pickup_grenades",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "grenades_threshold",
					type = "numeric",
					default_value = 1,
					range = {0, 5},
					decimals_number = 0,
				},
				{
					setting_id = "pickup_ammo",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "auto_ammo_thresholds",
					type = "checkbox",
					default_value = false,
				},
				{
					setting_id = "show_auto_ammo_threshold_notifications",
					type = "checkbox",
					default_value = false,
				},
				{
					setting_id = "ammo_clip_threshold",
					type = "numeric",
					default_value = 85,
					range = {1, 100},
					decimals_number = 0,
				},
				{
					setting_id = "ammo_bag_threshold",
					type = "numeric",
					default_value = 50,
					range = {1, 100},
					decimals_number = 0,
				},
			}
		},
		{
			setting_id  = "stimms_group",
			type        = "group",
			sub_widgets = {
				{
					setting_id = "pickup_stimms",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "per_class_stimms",
					type = "checkbox",
					default_value = false,
				},
				{
					setting_id = "stimm_med_enabled",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "stimm_med_rank",
					type = "numeric",
					default_value = 1,
					range = {1, 4},
					decimals_number = 0,
				},
				{
					setting_id = "stimm_combat_enabled",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "stimm_combat_rank",
					type = "numeric",
					default_value = 2,
					range = {1, 4},
					decimals_number = 0,
				},
				{
					setting_id = "stimm_celerity_enabled",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "stimm_celerity_rank",
					type = "numeric",
					default_value = 3,
					range = {1, 4},
					decimals_number = 0,
				},
				{
					setting_id = "stimm_concentration_enabled",
					type = "checkbox",
					default_value = true,
				},
				{
					setting_id = "stimm_concentration_rank",
					type = "numeric",
					default_value = 4,
					range = {1, 4},
					decimals_number = 0,
				},
			}
		},
	}
}
}
