local mod = get_mod("MultiBind")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "combat",
				type = "group",
				sub_widgets = {
					{setting_id = "action_one",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "action_one"},
					{setting_id = "action_two",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "action_two"},
					{setting_id = "weapon_extra",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "weapon_extra"},
					{setting_id = "interact",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "interact"},
					{setting_id = "interact_inspect",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "interact_inspect"},
					{setting_id = "wield_1",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "wield_1"},
					{setting_id = "wield_2",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "wield_2"},
					{setting_id = "wield_3",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "wield_3"},
					{setting_id = "wield_4",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "wield_4"},
					{setting_id = "wield_5",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "wield_5"},
					{setting_id = "quick_wield",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "quick_wield"},
					{setting_id = "wield_scroll_down",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "wield_scroll_down"},
					{setting_id = "wield_scroll_up",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "wield_scroll_up"},
					{setting_id = "weapon_reload",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "weapon_reload"},
					{setting_id = "grenade_ability",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "grenade_ability"},
					{setting_id = "combat_ability",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "combat_ability"},
					{setting_id = "smart_tag",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "smart_tag"},
					{setting_id = "com_wheel",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "com_wheel"},
					{setting_id = "tactical_overlay",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "tactical_overlay"},
					{setting_id = "weapon_inspect",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "weapon_inspect"},
					{setting_id = "spectate_next",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "spectate_next"},
					{setting_id = "voip_push_to_talk",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "voip_push_to_talk"},
				}
			},
			{
				setting_id = "hotkeys",
				type = "group",
				sub_widgets = {
					{setting_id = "hotkey_inventory",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "hotkey_inventory"},
				}
			},
			{
				setting_id = "interface",
				type = "group",
				sub_widgets = {
					{setting_id = "show_chat",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "show_chat"},
				}
			},
			{
				setting_id = "movement",
				type = "group",
				sub_widgets = {
					{setting_id = "keyboard_move_forward",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "keyboard_move_forward"},
					{setting_id = "keyboard_move_backward",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "keyboard_move_backward"},
					{setting_id = "keyboard_move_left",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "keyboard_move_left"},
					{setting_id = "keyboard_move_right",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "keyboard_move_right"},
					{setting_id = "dodge",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "dodge"},
					{setting_id = "jump",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "jump"},
					{setting_id = "crouch",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "crouch"},
					{setting_id = "sprint",type = "keybind",default_value = {},keybind_trigger = "held",keybind_type = "function_call",function_name = "sprint"},
				}
			},
			
			
		}
	}
}
