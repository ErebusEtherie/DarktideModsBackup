Inventory2D = Inventory2D or {}
local s = Inventory2D

s.mod = get_mod("Inventory2D")
local data = {}

data = {
	name = s.mod:localize("mod_name"),
	description = s.mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = "group_main_toggles",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_for_primary_weapons",
						type = "checkbox",
						default_value = true
					}, {
						setting_id = "enable_for_secondary_weapons",
						type = "checkbox",
						default_value = true
					}, {
						setting_id = "enable_for_curios",
						type = "checkbox",
						default_value = true
					}
				},
			}, {
				setting_id = "group_grid_layout",
				type = "group",
				sub_widgets = {
					{
						setting_id = "items_per_row",
						type = "numeric",
						default_value = 3,
						range = { 2, 5 }
					}, {
						setting_id = "grid_spacing",
						type = "numeric",
						default_value = 10,
						range = { 0, 50 }
					}
				},
			}, {
				setting_id = "group_item_details",
				type = "group",
				sub_widgets = {
					{
						setting_id = "show_rarity_tag",
						type = "checkbox",
						default_value = false
					}, {
						setting_id = "show_curio_blessing_text",
						type = "checkbox",
						default_value = true
					}, {
						setting_id = "curio_detail_mode",
						type = "checkbox",
						default_value = false
					}, {
						setting_id = "show_item_base_level",
						type = "checkbox",
						default_value = true
					}, {
						setting_id = "show_equipped_glow",
						type = "checkbox",
						default_value = true
					}, {
						setting_id = "show_traits",
						type = "checkbox",
						default_value = true
					}, {
						setting_id = "darken_item_icons",
						type = "numeric",
						default_value = 20,
						range = { 0, 100 }
					}
				}
			}, {
				setting_id = "group_text",
				type = "group",
				sub_widgets = {
					{
						setting_id = "item_name_font_size",
						type = "numeric",
						default_value = 16,
						range = { 8, 32 }
					}, {
						setting_id = "item_level_font_size",
						type = "numeric",
						default_value = 22,
						range = { 8, 32 }
					}, {
						setting_id = "item_base_level_font_size",
						type = "numeric",
						default_value = 16,
						range = { 8, 32 }
					}, {
						setting_id = "curio_blessing_font_size",
						type = "numeric",
						default_value = 16,
						range = { 8, 32 }
					}, {
						setting_id = "curio_detail_mode_blessing_font_size",
						type = "numeric",
						default_value = 16,
						range = { 8, 32 }
					}, {
						setting_id = "curio_detail_mode_perks_font_size",
						type = "numeric",
						default_value = 14,
						range = { 8, 32 }
					}
				}
			}
		}
	}
}

return data
