local mod = get_mod("DamageTracker")
local Breed = mod:original_require("scripts/utilities/breed")

mod.cached_settings = {
    enable_overkill = false,
    use_k_format = true,
    tracking_mode = "combined",
    floating_mode = "finesse_only",
    floating_weapon_filter = "both",
    floating_style = "fixed",
    fct_los_check = false,
}

local function update_cached_settings()
    mod.cached_settings.enable_overkill = mod:get("enable_overkill_damage")
    mod.cached_settings.use_k_format = mod:get("use_k_format")
    mod.cached_settings.tracking_mode = mod:get("tracking_mode") or "combined"
    mod.cached_settings.floating_mode = mod:get("floating_mode") or "finesse_only"
    mod.cached_settings.floating_weapon_filter = mod:get("floating_weapon_filter") or "both"
    mod.cached_settings.floating_style = mod:get("floating_style") or "fixed"
    mod.cached_settings.fct_los_check = mod:get("fct_los_check")
end

mod.on_all_mods_loaded = function()
    update_cached_settings()
end

mod.on_setting_changed = function()
    update_cached_settings()
    Managers.event:trigger("damage_tracker_settings_changed")
end

mod.format_damage_number = function(value)
    if not mod.cached_settings.use_k_format or value < 1000 then
        return tostring(math.floor(value))
    end
    return string.format("%.1fk", value / 1000):gsub("%.0k", "k")
end

-- 注册HUD元素
mod:register_hud_element({
	filename = "DamageTracker/scripts/mods/DamageTracker/HudElementDamageTrackerStatic",
	class_name = "HudElementDamageTrackerStatic",
	visibility_groups = { "tactical_overlay", "alive" },
	use_hud_scale = true,
	validation_function = function(params) return Managers.state.game_mode:game_mode_name() ~= "hub" end
})

mod:register_hud_element({
	filename = "DamageTracker/scripts/mods/DamageTracker/HudElementDamageTrackerFloating",
	class_name = "HudElementDamageTrackerFloating",
	visibility_groups = { "tactical_overlay", "alive" },
	use_hud_scale = true,
	validation_function = function(params) return Managers.state.game_mode:game_mode_name() ~= "hub" end
})

mod:hook_safe(CLASS.AttackReportManager, "add_attack_result",
function(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage,
	attack_result, attack_type, damage_efficiency, is_critical_strike, ...)

	if not damage or damage <= 0 then return end

	local local_player = Managers.player:local_player(1)
	if not local_player or local_player.player_unit ~= attacking_unit then return end

    local is_dot = (attack_type == "buff" or attack_type == "damage_over_time")
    local s = mod.cached_settings

	local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
	local breed_or_nil = unit_data_extension and unit_data_extension:breed()
	if not (breed_or_nil and Breed.is_minion(breed_or_nil)) then return end

	local unit_health_extension = ScriptUnit.has_extension(attacked_unit, "health_system")
	if not unit_health_extension then return end

    local actual_damage = damage
	local max_hp = unit_health_extension:max_health()
	local damage_taken = unit_health_extension:damage_taken()
	local damage_before_hit = math.max(0, damage_taken - damage)
	local remaining_before_hit = math.max(0, max_hp - damage_before_hit)
	actual_damage = math.min(damage, remaining_before_hit)

    local final_damage = s.enable_overkill and damage or actual_damage
    final_damage = math.ceil(final_damage)
    if final_damage <= 0 then return end

    -- [1] 发送基础累计追踪事件
    local mode = s.tracking_mode
    if is_dot then
        if mode == "combined" or mode == "separated" or mode == "dot_only" then
            Managers.event:trigger("damage_tracker_on_damage", final_damage, "main_dot", final_damage)
        end
    else
        if mode == "combined" or mode == "separated" or mode == "direct_only" then
            Managers.event:trigger("damage_tracker_on_damage", final_damage, "main_direct", final_damage)
        end
    end

    -- [2] 解析浮动文本(FCT)类型
    local is_w = hit_weakspot
    local is_c = is_critical_strike
    local hit_type = "normal"

    if is_dot then hit_type = "dot"
    elseif is_w and is_c then hit_type = "weakspot_crit"
    elseif is_w then hit_type = "pure_weakspot"
    elseif is_c then hit_type = "pure_crit"
    end

    local wf = s.floating_weapon_filter
    local pass_weapon = (wf == "both") or (wf == "melee_only" and attack_type == "melee") or (wf == "ranged_only" and attack_type == "ranged")
    if not pass_weapon then return end

    local world_pos = Unit.world_position(attacked_unit, 1)
    local target_node = hit_weakspot and "j_head" or "j_spine"

    if Unit.has_node(attacked_unit, target_node) then
        world_pos = Unit.world_position(attacked_unit, Unit.node(attacked_unit, target_node))
    elseif not hit_weakspot and Unit.has_node(attacked_unit, "j_hips") then
        world_pos = Unit.world_position(attacked_unit, Unit.node(attacked_unit, "j_hips"))
    end

    -- [4] 通过事件发送数据流
    Managers.event:trigger("damage_tracker_on_floating_damage", final_damage, hit_type, Vector3Box(world_pos), attacked_unit)
end)
