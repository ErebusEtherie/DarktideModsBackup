-- @Author: 我是派蒙啊
-- @Date:   2024-10-31 14:36:44
-- @Last Modified by:   我是派蒙啊
-- @Last Modified time: 2024-10-31 18:56:18
local mod = get_mod("MemLeakFix")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "pause_time",
				type = "numeric",
				default_value = 1,
				range = { 1, 10 },
				decimals_number = 1,
			},
			{
				setting_id = "step_mul",
				type = "numeric",
				default_value = 5,
				range = { 2, 5 },
				decimals_number = 1,
			},
			-- {
			-- 	setting_id = "gc_monitor",
			-- 	type = "checkbox",
			-- 	default_value = false,
			-- },
			-- {
			-- 	setting_id = "duration",
			-- 	type = "numeric",
			-- 	default_value = 10,
			-- 	range = { 1, 10 },
			-- 	decimals_number = 2,
			-- },
			-- {
			-- 	setting_id = "call_gc",
			-- 	type = "keybind",
			-- 	default_value = {},
			-- 	keybind_trigger = "pressed",
			-- 	keybind_type = "function_call",
			-- 	function_name = "callgc",
			-- },
		},
	},
}
