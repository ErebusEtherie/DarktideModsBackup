local mod = get_mod("character_cosmetics_view_improved")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = {
			{
				setting_id = "general_settings",
				type = "group",
				sub_widgets = {
					{
						setting_id = "mod_name_pizazz_toggle",
						type = "checkbox",
						default_value = true,
						tooltip = "mod_name_pizazz_tooltip",
					},
					{
						setting_id = "show_commodores",
						type = "dropdown",
						default_value = "loc_VPCC_show_all_commodores",
						tooltip = "show_commodores_tooltip",
						options = {
							{
								text = "All",
								value = "loc_VPCC_show_all_commodores",
							},
							{
								text = "OnlyAvailable",
								value = "loc_VPCC_show_available_commodores",
							},
							{
								text = "OnlyWishlisted",
								value = "loc_VPCC_show_wishlisted_commodores",
							},
							{
								text = "None",
								value = "loc_VPCC_show_no_commodores",
							},
						},
					},
					{
						setting_id = "show_unobtainable",
						type = "checkbox",
						default_value = false,
						tooltip = "show_unobtainable_tooltip",
					},
					{
						setting_id = "display_commodores_price_in_inventory",
						type = "checkbox",
						default_value = true,
						tooltip = "display_commodores_price_in_inventory_tooltip",
					},
				},
			},

			-- {
			--	setting_id = "unhook_cosmetics_from_presets",
			--	type = "checkbox",
			--	default_value = false
			-- },
		},
	},
}
