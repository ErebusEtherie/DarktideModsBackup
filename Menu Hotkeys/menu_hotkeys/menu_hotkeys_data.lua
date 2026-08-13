-- menu_hotkeys_data.lua
local mod = get_mod("menu_hotkeys")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = false,
	options = {
		widgets = {
			{
				setting_id = "settings_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "enable_in_psykhanium",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "enable_in_soloplay",
						type = "checkbox",
						default_value = true,
					},
					{
						setting_id = "close_menu_with_hotkey",
						type = "checkbox",
						default_value = true,
					},
				},
			},
			{
				setting_id = "hotkeys_group",
				type = "group",
				sub_widgets = {
			-- Inventory
					{
						setting_id = "open_inventory_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_inventory_view",
					},
			-- Barber
					{
						setting_id = "open_barber_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_barber_vendor_background_view",
					},
			-- Sire Melk's Requisitorium
					{
						setting_id = "open_requisitorium_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_requisitorium_view",
					},
			-- Contracts
					{
						setting_id = "open_contracts_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_contracts_background_view",
					},
			-- Crafting
					{
						setting_id = "open_crafting_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_crafting_view",
					},
			-- Armoury Exchange
					{
						setting_id = "open_credits_vendor_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_credits_vendor_background_view",
					},
			-- Mission Board
					{
						setting_id = "open_mission_board_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_mission_board_view",
					},
			-- Mortis Trials
					{
						setting_id = "open_training_grounds_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_training_grounds_view",
					},
			-- Meat Grinder
					{
						setting_id = "open_meatgrinder_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_meatgrinder_view",
					},
			-- Commissary (Cosmetics)
					{
						setting_id = "open_commissary_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_commissary_view",
					},
			-- Penance
					{
						setting_id = "open_penance_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_penance_overview_view",
					},
			-- Premium Store
					{
						setting_id = "open_premium_store_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_store_view",
					},
			-- Social Menu
					{
						setting_id = "open_social_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_social_view",
					},
			-- Havoc Mode (new)
					{
						setting_id = "open_havoc_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_havoc_view",
					},
			-- Expedition Mode
					{
						setting_id = "open_expedition_view_key",
						type = "keybind",
						default_value = {},
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "activate_expedition_view",
					},
				},
			},
			{
				setting_id = "debug_group",
				type = "group",
				sub_widgets = {
					{
						setting_id = "requisitorium_close_delay",
						type = "numeric",
						default_value = 900,
						range = { 100, 3000 },
						step_size_value = 100,
					},
				},
			},
		}
	}
}
