local mod = get_mod("CharacterGrid")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id      = "character_count",
				type            = "numeric",
				default_value   = 8,
				range           = { 8, 9 },
				decimals_number = 0,
			},
		}
	}
}
