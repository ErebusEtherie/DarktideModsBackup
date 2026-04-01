local mod = get_mod("ZealotThrowingKnife")

local Managers = Managers
local ScriptUnit = ScriptUnit
local string_find = string.find
local pairs = pairs

-- Settings
local settings = {
    mod_enabled = true,
    mod_enable_verbose = false,
    mod_enable_debug = false
}

-- Cached values
local cached_settings = {
    weapon_settings = {}
}

-- Toggle mod function
mod.toggle_mod = function()
    if Managers and Managers.ui and not Managers.ui:using_input() then
        settings.mod_enabled = not settings.mod_enabled
        mod:set("mod_enabled", settings.mod_enabled)
        if settings.mod_enable_verbose then
            mod:echo("ZealotThrowingKnife: %s", settings.mod_enabled and "Enabled" or "Disabled")
        end
        if settings.mod_enable_debug then
            mod:info("ZealotThrowingKnife: %s", settings.mod_enabled and "Enabled" or "Disabled")
        end
    end
end

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
	boltpistol_p1_m2 = "enable_boltpistol_p1_m2",
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

local State = {
	auto_throw_active = false,
	current_player_archetype = nil,
	is_zealot = false,
	skip_next_auto_throw = false,
	simulate_quick_wield = false,
	skip_auto_throw_until = 0,
	last_ranged_slot_log = 0,
	last_switch_attempt = 0,
	last_skip_log = 0,
	log_cooldown = 0.5,
	input_cooldown = 0.3,
}

local function safe_call(func_or_obj, method_or_fn, ...)
	if type(func_or_obj) == "function" then
		local func = func_or_obj
		local ok, result
		if select("#", ...) == 0 and method_or_fn ~= nil then
			ok, result = pcall(func, method_or_fn)
		else
			ok, result = pcall(func, method_or_fn, ...)
		end
		if not ok and settings.mod_enable_debug then
			mod:error("[ZealotThrowingKnife] Error: %s", result)
		end
		return ok, result
	elseif type(func_or_obj) == "table" and type(method_or_fn) == "string" then
		local obj = func_or_obj
		local method_name = method_or_fn
		local method = obj[method_name]
		if not method then
			return false, nil
		end
		local ok, result = pcall(method, obj, ...)
		if not ok and settings.mod_enable_debug then
			mod:error("[ZealotThrowingKnife] Error in %s: %s", method_name, result)
		end
		return ok, result
	end
	return false, nil
end

-- 调试日志函数
local function debug_log(msg, ...)
	if settings.mod_enable_debug then
		local ok, message = pcall(string.format, msg, ...)
		if not ok then return end
		if Managers and Managers.log then
			pcall(function()
				Managers.log:info("[ZealotThrowingKnife] " .. message)
			end)
		else
			mod:debug(message)
		end
	end
end

local function safe_get_player()
	if not Managers or not Managers.player then return nil end
	local ok, result = pcall(function()
		return Managers.player:local_player_safe(1)
	end)
	return ok and result or nil
end

local function safe_get_profile(player)
	if not player then return nil end
	local ok, result = pcall(function()
		return player:profile()
	end)
	return ok and result or nil
end

local function safe_get_player_unit(player)
	if not player or player.bot_player then return nil end
	return player.player_unit
end

local function get_gameplay_time()
	local current_time = 0
	if Managers.time and Managers.time.time then
		local ok, time_result = pcall(function()
			return Managers.time:time("gameplay")
		end)
		if ok then
			current_time = time_result
		end
	end
	return current_time
end

local function has_throwing_knives(player_unit)
	if not player_unit then return false end
	
	local ok, result = pcall(function()
		local weapon_ext = ScriptUnit.has_extension(player_unit, "weapon_system")
		if not weapon_ext then return false end
		
		local weapons = weapon_ext._weapons
		if not weapons then return false end
		
		local grenade_weapon = weapons["slot_grenade_ability"]
		if not grenade_weapon or not grenade_weapon.weapon_template then return false end
		
		return string_find(grenade_weapon.weapon_template.name or "", "zealot_throwing_knives") ~= nil
	end)
	
	return ok and result or false
end

-- 检查武器是否启用
local function is_weapon_enabled(weapon_name)
	if not weapon_name then return false end
	
	-- 检查全局开关
	if not settings.mod_enabled then
		debug_log("Global mod is disabled")
		return false
	end
	
	-- 检查具体武器的开关
	local setting_id = RANGED_WEAPONS[weapon_name]
	if setting_id then
		local enabled = cached_settings.weapon_settings[setting_id]
		if enabled == nil then
			enabled = mod:get(setting_id)
			cached_settings.weapon_settings[setting_id] = enabled
		end
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

-- 更新玩家职业缓存
local function update_player_archetype_cache()
	local player = safe_get_player()
	if not player then
		State.current_player_archetype = nil
		State.is_zealot = false
		return false
	end

	local profile = safe_get_profile(player)
	if not profile then
		State.current_player_archetype = nil
		State.is_zealot = false
		return false
	end

	local ok, archetype_name = pcall(function()
		return profile.archetype and profile.archetype.name
	end)
	
	if not ok or not archetype_name then
		State.current_player_archetype = nil
		State.is_zealot = false
		return false
	end

	if archetype_name ~= State.current_player_archetype then
		State.current_player_archetype = archetype_name
		State.is_zealot = (archetype_name == "zealot")
		debug_log("Player archetype updated to: %s, is_zealot: %s", archetype_name, tostring(State.is_zealot))
		return true
	end

	return false
end

-- 检查武器并触发投掷
local function check_weapon_and_trigger_throw(player_unit, weapon_name)
	if not weapon_name or not is_ranged_weapon(weapon_name) then
		State.auto_throw_active = false
		return false
	end

	if not is_weapon_enabled(weapon_name) then
		State.auto_throw_active = false
		return false
	end

	local current_time = get_gameplay_time()
	
	-- 检查时间窗口是否已过期，如果过期则重置
	if State.skip_auto_throw_until > 0 and current_time > State.skip_auto_throw_until + 0.5 then
		State.skip_auto_throw_until = 0
		State.skip_next_auto_throw = false
	end
	
	local within_time_window = current_time < State.skip_auto_throw_until
	
	if State.skip_next_auto_throw or within_time_window then
		if current_time - State.last_skip_log > State.log_cooldown then
			debug_log("AUTO-THROW SKIPPED (flag=%s, time_window=%s)", 
				tostring(State.skip_next_auto_throw), 
				tostring(within_time_window))
			State.last_skip_log = current_time
		end
		State.skip_next_auto_throw = false
		State.auto_throw_active = false
		return false
	end
	
	debug_log("TRIGGERING AUTO-THROW")
	State.auto_throw_active = true

	return true
end

-- --- 快捷键：切换到远程武器（不自动投掷飞刀）
mod.switch_to_ranged_no_throw = function()
	safe_call(function()
		-- 检查UI是否打开
		if Managers and Managers.ui and Managers.ui:using_input() then
			return
		end

		-- 非狂信徒直接返回，不执行任何操作
		if not State.is_zealot then
			return
		end

		-- 输入防抖：检查冷却时间
		local current_time = get_gameplay_time()
		if current_time - State.last_switch_attempt < State.input_cooldown then
			return
		end
		State.last_switch_attempt = current_time

		local player = safe_get_player()
		local player_unit = safe_get_player_unit(player)

		if not player_unit then
			debug_log("[SWITCH] No player unit available")
			return
		end

		if not has_throwing_knives(player_unit) then
			debug_log("[SWITCH] Player does not have throwing knives")
			return
		end

		-- 获取当前武器信息
		local weapon_ext = ScriptUnit.has_extension(player_unit, "weapon_system")
		if not weapon_ext then
			debug_log("[SWITCH] No weapon extension")
			return
		end

		local inventory = weapon_ext._inventory_component
		if not inventory then
			debug_log("[SWITCH] No inventory component")
			return
		end

		local current_slot = inventory.wielded_slot

		-- 确定要切换到的远程武器槽位
		local ranged_slot = nil
		if current_slot == "slot_primary" then
			ranged_slot = "slot_secondary"
		elseif current_slot == "slot_secondary" then
			-- 已经在远程武器槽，不切换（添加日志冷却机制）
			if current_time - State.last_ranged_slot_log > State.log_cooldown then
				debug_log("[SWITCH] Already in ranged slot (slot_secondary)")
				State.last_ranged_slot_log = current_time
			end
			return
		else
			-- 其他槽位，优先尝试远程武器槽
			ranged_slot = "slot_secondary"
		end

		-- 检查远程武器槽是否有武器
		if not inventory[ranged_slot] or inventory[ranged_slot] == "not_equipped" then
			debug_log("[SWITCH] No weapon in slot: %s", ranged_slot)
			return
		end

		-- 检查远程武器是否启用自动投掷
		local weapon_data = weapon_ext._weapons[ranged_slot]
		local weapon_template = weapon_data and weapon_data.weapon_template
		local weapon_name = weapon_template and weapon_template.name or nil

		if not weapon_name or not is_ranged_weapon(weapon_name) then
			debug_log("[SWITCH] Weapon in slot is not ranged: %s", weapon_name or "nil")
			return
		end

		if not is_weapon_enabled(weapon_name) then
			debug_log("[SWITCH] Auto-throw is disabled for weapon: %s", weapon_name)
			return
		end

		-- 设置跳过自动投掷标志
		State.skip_next_auto_throw = true
		
		-- 设置时间窗口（1秒），用于处理服务器模式下的多次触发
		State.skip_auto_throw_until = current_time + 1.0
		
		debug_log("[SWITCH] Set skip flags for weapon: %s", weapon_name)

		-- 设置模拟 quick_wield 标志，让 InputService._get 钩子处理
		State.simulate_quick_wield = true

		if settings.mod_enable_verbose then
			-- 调试模式打开时输出到聊天栏，否则只输出到日志
			if settings.mod_enable_debug then
				mod:echo("Switching to %s (auto-throw disabled)", weapon_name)
			else
				mod:info("Switching to %s (auto-throw disabled)", weapon_name)
			end
		end
	end)
end

local function update_cached_settings()
	for _, setting_id in pairs(RANGED_WEAPONS) do
		cached_settings.weapon_settings[setting_id] = mod:get(setting_id)
	end
	
	if settings.mod_enable_debug then
		mod:info("Settings cache updated")
	end
end

mod.on_all_mods_loaded = function()
    settings.mod_enabled = mod:get("mod_enabled")
    settings.mod_enable_verbose = mod:get("mod_enable_verbose")
    settings.mod_enable_debug = mod:get("mod_enable_debug")
    
    update_cached_settings()
end

mod.on_setting_changed = function(setting_name)
    if setting_name == "mod_enabled" then
        settings.mod_enabled = mod:get("mod_enabled")
        return
    elseif setting_name == "mod_enable_verbose" then
        settings.mod_enable_verbose = mod:get("mod_enable_verbose")
        return
    elseif setting_name == "mod_enable_debug" then
        settings.mod_enable_debug = mod:get("mod_enable_debug")
        return
    else
        update_cached_settings()
    end
end

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "on_slot_wielded", function(self, slot_name, t, skip_wield_action)
	safe_call(function()
		-- 1. 先更新玩家职业缓存
		update_player_archetype_cache()

		-- 2. 检测玩家职业是否为狂信徒，如果不是则立即返回，不输出任何信息
		if not State.is_zealot then
			State.auto_throw_active = false
			return
		end

		-- 只有狂信徒才输出调试信息
		debug_log("=== on_slot_wielded triggered, slot_name=%s, skip_wield_action=%s, skip_next=%s ===", slot_name or "nil", tostring(skip_wield_action), tostring(State.skip_next_auto_throw))

		-- 3. 检测是否有飞刀能力
		local player = safe_get_player()
		local player_unit = safe_get_player_unit(player)
		if not player_unit then
			debug_log("No player unit")
			State.auto_throw_active = false
			return
		end

		if not has_throwing_knives(player_unit) then
			debug_log("No throwing knives, skipping further checks")
			State.auto_throw_active = false
			return
		end

		debug_log("Has throwing knives: YES")

		-- 4. 检测是否切换到远程武器
		local weapon_ext = ScriptUnit.has_extension(player_unit, "weapon_system")
		if not weapon_ext then
			debug_log("No weapon_ext")
			State.auto_throw_active = false
			return
		end

		local weapons = weapon_ext._weapons
		if not weapons then
			debug_log("No weapons table")
			State.auto_throw_active = false
			return
		end

		local weapon_data = weapons[slot_name]
		local weapon_template = weapon_data and weapon_data.weapon_template
		local weapon_name = weapon_template and weapon_template.name or nil
		debug_log("Switched to slot: %s, weapon_name: %s", slot_name, weapon_name or "nil")

		-- 5. 检查武器并触发投掷
		check_weapon_and_trigger_throw(player_unit, weapon_name)
	end)
end)

mod:hook(CLASS.InputService, "_get", function(func, self, action_name)
	local original_result = func(self, action_name)
	
	-- 快速路径：UI打开或非狂信徒时直接返回，避免不必要的闭包创建
	if (Managers and Managers.ui and Managers.ui:using_input()) or not State.is_zealot then
		return original_result
	end
	
	local ok, result = safe_call(function()
		-- Handle quick_wield simulation for weapon switching
		if action_name == "quick_wield" and State.simulate_quick_wield then
			debug_log("[SWITCH] Simulating quick_wield input")
			State.simulate_quick_wield = false
			return true
		end
		
		-- Only intercept grenade_ability_pressed for auto-throw
		if action_name ~= "grenade_ability_pressed" then
			return original_result
		end
		
		-- Check if we should trigger auto-throw
		if State.auto_throw_active then
			debug_log("AUTO-THROW TRIGGERED via input hook")
			State.auto_throw_active = false
			return true
		end
		
		return original_result
	end)
	
	return ok and result or original_result
end)

local function cleanup_state()
	State.auto_throw_active = false
	State.simulate_quick_wield = false
	State.skip_next_auto_throw = false
	State.skip_auto_throw_until = 0
	State.last_switch_attempt = 0
	State.last_skip_log = 0
	State.last_ranged_slot_log = 0
	
	if settings.mod_enable_debug then
		mod:info("State cleaned up")
	end
end

mod.on_load = function()
	for _, setting_id in pairs(RANGED_WEAPONS) do
		if mod:get(setting_id) == nil then
			mod:set(setting_id, true)
		end
	end
	
	update_player_archetype_cache()
	update_cached_settings()
end

mod.on_game_state_changed = function(status, state_name)
	debug_log("Game state changed: status=%s, state_name=%s", status or "nil", state_name or "nil")
	
	if status == "exit" and state_name == "GameplayStateRun" then
		cleanup_state()
		debug_log("Exiting GameplayStateRun, cleaned up state")
	end
end
