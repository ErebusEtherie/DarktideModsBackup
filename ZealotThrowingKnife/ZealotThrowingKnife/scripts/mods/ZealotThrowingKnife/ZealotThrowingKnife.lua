local mod = get_mod("ZealotThrowingKnife")

local Managers = Managers
local ScriptUnit = ScriptUnit
local string_find = string.find
local pairs = pairs
local table_clone = table.clone

-- 远程武器列表 - 用于识别远程武器
local RANGED_WEAPONS = {
	stubrevolver_p1_m1 = "enable_stubrevolver_p1_m1",
	stubrevolver_p1_m2 = "enable_stubrevolver_p1_m2",
	shotgun_p1_m1 = "enable_shotgun_p1_m1",
	shotgun_p1_m2 = "enable_shotgun_p1_m2",
	shotgun_p1_m3 = "enable_shotgun_p1_m3",
	shotgun_p2_m1 = "enable_shotgun_p2_m1",
	laspistol_p1_m1 = "enable_laspistol_p1_m1",
	laspistol_p1_m3 = "enable_laspistol_p1_m3",
	lasgun_p1_m1 = "enable_lasgun_p1_m1",
	lasgun_p1_m2 = "enable_lasgun_p1_m2",
	lasgun_p1_m3 = "enable_lasgun_p1_m3",
	lasgun_p3_m1 = "enable_lasgun_p3_m1",
	lasgun_p3_m2 = "enable_lasgun_p3_m2",
	lasgun_p3_m3 = "enable_lasgun_p3_m3",
	flamer_p1_m1 = "enable_flamer_p1_m1",
	bolter_p1_m1 = "enable_bolter_p1_m1",
	bolter_p1_m2 = "enable_bolter_p1_m2",
	boltpistol_p1_m1 = "enable_boltpistol_p1_m1",
	autopistol_p1_m1 = "enable_autopistol_p1_m1",
	autogun_p1_m1 = "enable_autogun_p1_m1",
	autogun_p1_m2 = "enable_autogun_p1_m2",
	autogun_p1_m3 = "enable_autogun_p1_m3",
	autogun_p2_m1 = "enable_autogun_p2_m1",
	autogun_p2_m2 = "enable_autogun_p2_m2",
	autogun_p2_m3 = "enable_autogun_p2_m3",
	autogun_p3_m1 = "enable_autogun_p3_m1",
	autogun_p3_m2 = "enable_autogun_p3_m2",
	autogun_p3_m3 = "enable_autogun_p3_m3",
}

-- 近战槽位
local MELEE_SLOTS = {
	slot_primary = true,
	slot_secondary = true,
}

local State = {
	last_wielded_weapon = nil,
	auto_throw_active = false,
	auto_throw_end_time = 0,
}

-- 调试日志函数
local function debug_log(msg, ...)
	if mod:get("enable_debug") then
		mod:echo("[DEBUG] " .. (msg or ""), ...)
	end
end

local function safe_get_player()
	if not Managers or not Managers.player then return nil end
	return Managers.player:local_player_safe(1)
end

local function safe_get_profile(player)
	if not player then return nil end
	return player:profile()
end

local function safe_get_player_unit(player)
	if not player or player.bot_player then return nil end
	return player.player_unit
end

local function is_zealot(player)
	local profile = safe_get_profile(player)
	if profile and profile.archetype then
		return profile.archetype.name == "zealot"
	end
	return false
end

local function has_throwing_knives(player_unit)
	if not player_unit then return false end
	
	local weapon_ext = ScriptUnit.has_extension(player_unit, "weapon_system")
	if not weapon_ext then return false end
	
	local weapons = weapon_ext._weapons
	if not weapons then return false end
	
	local grenade_weapon = weapons["slot_grenade_ability"]
	if not grenade_weapon or not grenade_weapon.weapon_template then return false end
	
	return string_find(grenade_weapon.weapon_template.name or "", "zealot_throwing_knives") ~= nil
end

local function get_current_weapon_name(player_unit)
	if not player_unit then return nil end
	
	local weapon_ext = ScriptUnit.has_extension(player_unit, "weapon_system")
	if not weapon_ext then return nil end
	
	local inventory = weapon_ext._inventory_component
	if not inventory then return nil end
	
	local wielded_slot = inventory.wielded_slot
	debug_log("Wielded slot: %s", wielded_slot or "nil")
	
	if not wielded_slot or MELEE_SLOTS[wielded_slot] then 
		debug_log("Slot is melee or nil, returning nil")
		return nil 
	end
	
	local weapons = weapon_ext._weapons
	if not weapons or not weapons[wielded_slot] then 
		debug_log("No weapons table or weapon in slot")
		return nil 
	end
	
	local weapon_template = weapons[wielded_slot].weapon_template
	if not weapon_template then 
		debug_log("No weapon template")
		return nil 
	end
	
	local weapon_name = weapon_template.name or nil
	debug_log("Current weapon name: %s", weapon_name or "nil")
	return weapon_name
end

-- 检查武器是否启用
local function is_weapon_enabled(weapon_name)
	if not weapon_name then return false end
	
	-- 检查全局开关
	local global_enabled = mod:get("global_enabled")
	if global_enabled == false then
		debug_log("Global mod is disabled")
		return false
	end
	
	-- 检查具体武器的开关
	local setting_id = RANGED_WEAPONS[weapon_name]
	if setting_id then
		local enabled = mod:get(setting_id)
		debug_log("Weapon '%s' setting '%s' = %s", weapon_name, setting_id, tostring(enabled))
		return enabled == true
	end
	
	debug_log("Weapon '%s' not found in settings", weapon_name)
	return false
end

-- 检查是否是远程武器
local function is_ranged_weapon(weapon_name)
	if not weapon_name then return false end
	return RANGED_WEAPONS[weapon_name] ~= nil
end

-- 处理批量启用/禁用
local function handle_batch_actions()
	local reset_all = mod:get("reset_all_enabled")
	local disable_all = mod:get("disable_all_enabled")
	
	if reset_all then
		mod:set("reset_all_enabled", false)
		for weapon_name, setting_id in pairs(RANGED_WEAPONS) do
			mod:set(setting_id, true)
		end
		mod:set("global_enabled", true)
		mod:echo("[ZealotThrowingKnife] All weapons enabled")
	elseif disable_all then
		mod:set("disable_all_enabled", false)
		for weapon_name, setting_id in pairs(RANGED_WEAPONS) do
			mod:set(setting_id, false)
		end
		mod:set("global_enabled", false)
		mod:echo("[ZealotThrowingKnife] All weapons disabled")
	end
end

-- 切换模组功能（用于快捷键）
mod.mod_enable_toggle = function()
	local current_state = mod:get("global_enabled") or false
	local new_state = not current_state
	mod:set("global_enabled", new_state)
	
	if new_state then
		mod:echo("[ZealotThrowingKnife] Mod ENABLED")
	else
		mod:echo("[ZealotThrowingKnife] Mod DISABLED")
	end
end

-- Hook on weapon wield to detect switching from melee to ranged
mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded", function(self, slot_name, t, skip_wield_action)
	debug_log("=== on_slot_wielded triggered, slot_name=%s ===", slot_name or "nil")
	
	-- 处理批量操作
	handle_batch_actions()

	local player = safe_get_player()
	debug_log("Player: %s", player and "valid" or "nil")

	if not is_zealot(player) then 
		debug_log("Player is not zealot")
		return 
	end

	local player_unit = safe_get_player_unit(player)
	debug_log("Player unit: %s", player_unit and "valid" or "nil")

	if not player_unit or not has_throwing_knives(player_unit) then 
		debug_log("No player unit or no throwing knives")
		return 
	end

	debug_log("Has throwing knives: YES")

	local weapon_ext = ScriptUnit.has_extension(player_unit, "weapon_system")
	if not weapon_ext then debug_log("No weapon_ext"); return end
	local weapons = weapon_ext._weapons
	if not weapons then debug_log("No weapons table"); return end
	for slot, data in pairs(weapons) do
		debug_log("[DEBUG] weapons[%s]=%s", slot, data and (data.weapon_template and data.weapon_template.name or "no template") or "nil")
	end

	-- 只在切换到远程武器时触发
	local weapon_data = weapons[slot_name]
	local weapon_template = weapon_data and weapon_data.weapon_template
	local weapon_name = weapon_template and weapon_template.name or nil
	debug_log("Switched to slot: %s, weapon_name: %s", slot_name, weapon_name or "nil")
	
	if weapon_name and is_ranged_weapon(weapon_name) and is_weapon_enabled(weapon_name) then
		local delay = mod:get("throw_delay") or 0
		debug_log("TRIGGERING AUTO-THROW: delay=%f", delay)
		State.auto_throw_active = true
		State.auto_throw_end_time = (Managers.time:time("gameplay") or 0) + delay
	else
		debug_log("NOT triggering: ranged=%s, enabled=%s", 
			weapon_name and is_ranged_weapon(weapon_name) and "yes" or "no",
			weapon_name and is_weapon_enabled(weapon_name) and "yes" or "no")
		State.auto_throw_active = false
	end
	State.last_wielded_weapon = weapon_name
end)

-- Main InputService hook - override grenade_ability_pressed when in auto-throw window
mod:hook(CLASS.InputService, "_get", function(func, self, action_name)
	local original_result = func(self, action_name)
	
	-- Only intercept grenade_ability_pressed
	if action_name ~= "grenade_ability_pressed" then
		return original_result
	end
	
	-- Check if UI is open
	if Managers and Managers.ui and Managers.ui:using_input() then
		return original_result
	end
	
	-- Check if we should trigger auto-throw
	if State.auto_throw_active then
		local current_time = Managers.time:time("gameplay") or 0
		
		if current_time >= State.auto_throw_end_time then
			-- Time to throw! Return true to simulate input
			debug_log("AUTO-THROW TRIGGERED! current_time=%f, end_time=%f", current_time, State.auto_throw_end_time)
			State.auto_throw_active = false
			return true
		end
		-- Still in delay window, suppress input
		debug_log("In delay window: %.2f seconds remaining", State.auto_throw_end_time - current_time)
		return false
	end
	
	return original_result
end)

-- On mod load, initialize settings
mod.on_load = function()
	-- 确保所有武器设置都有默认值
	for weapon_name, setting_id in pairs(RANGED_WEAPONS) do
		if mod:get(setting_id) == nil then
			mod:set(setting_id, true)
		end
	end
	
	if mod:get("global_enabled") == nil then
		mod:set("global_enabled", true)
	end
end
