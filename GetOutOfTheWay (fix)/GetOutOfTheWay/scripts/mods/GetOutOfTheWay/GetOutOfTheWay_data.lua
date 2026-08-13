local mod = get_mod("GetOutOfTheWay")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "min_distance",
				type = "numeric",
				default_value = 1,
				range = { 0, 20 },
				decimals_number = 1,
			},
			{
				setting_id = "max_distance",
				type = "numeric",
				default_value = 5,
				range = { 0, 20 },
				decimals_number = 1,
			},
			{
				setting_id = "max_height_difference",
				type = "numeric",
				default_value = 5,
				range = { 0, 20 },
				decimals_number = 1,
			},
			{
				setting_id = "apply_to_my_cyber_mastiff",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "apply_to_my_servo_skull",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "only_ogryn",
				type = "checkbox",
				default_value = false,
			},
			{
				setting_id = "apply_to_cyber_mastiff",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "apply_to_servo_skull",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "keep_rescue_targets_visible",
				type = "checkbox",
				default_value = true,
			},
			{
				setting_id = "keep_allies_visible_while_holding_support_items",
				type = "checkbox",
				default_value = true,
			},
		}
	}
}
