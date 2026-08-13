local mod = get_mod("Exceeds Payload")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,

	options = {
		widgets = {
			{
				setting_id      = "ep_sag_deg",
				type            = "numeric",
				default_value   = 2,
				range           = { 0, 15 },
				decimals_number = 1,
			},
			{
				setting_id      = "ep_settle_deg",
				type            = "numeric",
				default_value   = 0.6,
				range           = { 0, 10 },
				decimals_number = 1,
			},
			{
				setting_id    = "ep_list_deg",
				type          = "numeric",
				default_value = 6,
				range         = { 0, 45 },
			},
		},
	},
}
