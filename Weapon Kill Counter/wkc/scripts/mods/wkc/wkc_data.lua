local mod = get_mod("wkc")

return {
	name         = "Weapon Kill Counter",
	description  = mod:localize("wkc_mod_description"),
	is_togglable = true,
	options = {
		widgets  = {
			{
				setting_id  = "wkc_honorific_group",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "wkc_per_instance",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "wkc_merge_factions",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "wkc_card_kills",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id    = "wkc_detail_kills",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id    = "wkc_hide_havoc",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "wkc_honorific_notify",
						type          = "checkbox",
						default_value = false,
					},
					{
						setting_id    = "wkc_honorific_title",
						type          = "checkbox",
						default_value = true,
					},
					{
						setting_id    = "wkc_inventory_prefix",
						type          = "checkbox",
						default_value = false,
					},
				},
			},

			{
				setting_id  = "wkc_admin_group",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "wkc_reset_trigger",
						type          = "dropdown",
						default_value = 0,
						options       = {
							{ text = "wkc_reset_inactive", value = 0 },
							{ text = "wkc_reset_active",   value = 1 },
						},
					},
				},
			},
		},
	},
}
