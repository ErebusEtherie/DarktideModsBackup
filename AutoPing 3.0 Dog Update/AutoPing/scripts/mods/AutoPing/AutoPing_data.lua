local mod = get_mod("AutoPing")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = "cd",
				type = "numeric",
				default_value = 10,
				range = {1, 30},
				decimals_number = 1,  
			},
			{
				setting_id = "manualoverride",
				type = "checkbox",
				default_value = false
			},
			{
				setting_id = "refresh",
				type = "checkbox",
				default_value = true
			},
			{
				setting_id = "filter_mode",
				type = "dropdown",
				default_value = "high_priority_only",
				options = {
					{text = "filter_mode_all_pingable", value = "all_pingable"},
					{text = "filter_mode_high_priority", value = "high_priority_only"},
					{text = "filter_mode_specials_elites", value = "specials_and_elites"},
					{text = "filter_mode_custom", value = "custom"}
				}
			},
			{
				setting_id = "priority_targeting",
				type = "checkbox",
				default_value = false
			},
			{
				setting_id = "companion_attack_mode",
				type = "checkbox",
				default_value = false
			},
			{
				setting_id = "debug_mode",
				type = "checkbox",
				default_value = false
			},
			-- Priority Level Settings
			{
				setting_id = "priority_settings_header",
				type = "group",
				sub_widgets = {
					-- Boss Enemies (Priority 1 - Fixed to include all bosses)
					{
						setting_id = "priority_chaos_beast_of_nurgle",
						type = "dropdown",
						default_value = "high",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_chaos_plague_ogryn",
						type = "dropdown",
						default_value = "high",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_chaos_daemonhost",
						type = "dropdown",
						default_value = "high",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_chaos_spawn",
						type = "dropdown",
						default_value = "high",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					-- High Priority Enemies (Specials/Disablers)
					{
						setting_id = "priority_cultist_flamer",
						type = "dropdown",
						default_value = "high",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_renegade_flamer",
						type = "dropdown",
						default_value = "high",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_renegade_netgunner",
						type = "dropdown",
						default_value = "high",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_renegade_sniper",
						type = "dropdown",
						default_value = "high",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_cultist_grenadier",
						type = "dropdown",
						default_value = "high",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_renegade_grenadier",
						type = "dropdown",
						default_value = "high",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_chaos_hound",
						type = "dropdown",
						default_value = "high",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_chaos_poxwalker_bomber",
						type = "dropdown",
						default_value = "high",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					-- Medium Priority Enemies (Elites)
					{
						setting_id = "priority_renegade_gunner",
						type = "dropdown",
						default_value = "medium",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_cultist_gunner",
						type = "dropdown",
						default_value = "medium",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_renegade_shocktrooper",
						type = "dropdown",
						default_value = "medium",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_cultist_shocktrooper",
						type = "dropdown",
						default_value = "medium",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_chaos_ogryn_executor",
						type = "dropdown",
						default_value = "medium",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_chaos_ogryn_gunner",
						type = "dropdown",
						default_value = "medium",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_chaos_ogryn_bulwark",
						type = "dropdown",
						default_value = "medium",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_renegade_executor",
						type = "dropdown",
						default_value = "medium",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_renegade_berzerker",
						type = "dropdown",
						default_value = "medium",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_cultist_berzerker",
						type = "dropdown",
						default_value = "medium",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					},
					{
						setting_id = "priority_cultist_mutant",
						type = "dropdown",
						default_value = "medium",
						options = {
							{text = "priority_high", value = "high"},
							{text = "priority_medium", value = "medium"},
							{text = "priority_disabled", value = "disabled"}
						}
					}
				}
			},
			-- Legacy Custom Mode Settings (kept for backward compatibility)
			{
				setting_id = "tag_cultist_flamer",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_renegade_flamer",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_renegade_netgunner",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_renegade_sniper",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_cultist_grenadier",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_renegade_grenadier",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_chaos_hound",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_cultist_berzerker",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_renegade_berzerker",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_chaos_poxwalker_bomber",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_renegade_gunner",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_cultist_gunner",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_renegade_shocktrooper",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_cultist_shocktrooper",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_chaos_ogryn_executor",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_chaos_ogryn_gunner",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_chaos_ogryn_bulwark",
				type = "checkbox",
				default_value = false,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_renegade_executor",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_chaos_spawn",
				type = "checkbox",
				default_value = false,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_cultist_mutant",
				type = "checkbox",
				default_value = false,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			-- Boss enemies for custom mode
			{
				setting_id = "tag_chaos_beast_of_nurgle",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_chaos_plague_ogryn",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			},
			{
				setting_id = "tag_chaos_daemonhost",
				type = "checkbox",
				default_value = true,
				show_widget = function() return mod:get("filter_mode") == "custom" end
			}
		}
	}
}