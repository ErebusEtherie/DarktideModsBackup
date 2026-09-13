local mod = get_mod("AutoLoot")

local Pickups = require("scripts/settings/pickup/pickups")

-- ───────────────────── ❀ ─────────────────────
--  Press State
-- ───────────────────── ❀ ─────────────────────

local pickup = false
local pickup_unit = nil
local cooldown = 0.0

local pending = {}
local arm_kind = nil
local arm_value = nil

local CONFIRM_TIMEOUT = 2.0

local pressed_unit = nil

local MIN_PRESS_COOLDOWN = 0.1

-- ───────────────────── ❀ ─────────────────────
--  Aim Gate
-- ───────────────────── ❀ ─────────────────────

local AIM_TURN_COS = math.cos(0.07)

local press_locked = false
local locked_fx, locked_fy, locked_fz = 0, 0, 0
local aim_fx, aim_fy, aim_fz = 0, 0, 0
local settled_unit = nil
local settled_for = 0.0

local function read_aim(unit_data_extension)
    local ok, eye, forward = pcall(function()
        local first_person = unit_data_extension:read_component("first_person")

        return first_person.position, Vector3.normalize(Quaternion.forward(first_person.rotation))
    end)

    if ok and eye and forward then
        return eye, forward
    end

    return nil, nil
end

local function aim_offset(eye, forward, target_unit)
    if not eye or not forward or not target_unit or not ALIVE[target_unit] then
        return nil
    end

    local ok, offset = pcall(function()
        local boxed, pose, extents = pcall(Unit.box, target_unit)
        local centre, reach

        if boxed and pose and extents then
            centre = Matrix4x4.translation(pose)
            reach = math.min(extents.x, extents.y, extents.z)
        else
            centre = Unit.world_position(target_unit, 1)
            reach = 0.0
        end

        local to_target = centre - eye
        local along = Vector3.dot(forward, to_target)

        if along <= 0 then
            return math.huge
        end

        return math.max(0, Vector3.length(to_target - forward * along) - reach)
    end)

    if ok and type(offset) == "number" and offset == offset then
        return offset
    end

    return nil
end

-- ───────────────────── ❀ ─────────────────────
--  Stimm Names
-- ───────────────────── ❀ ─────────────────────

local STIMM_PICKUP_BY_HUD = {
    ["loc_pickup_pocketable_01"] = "syringe_corruption_pocketable",
    ["loc_pickup_syringe_pocketable_02"] = "syringe_ability_boost_pocketable",
    ["loc_pickup_syringe_pocketable_03"] = "syringe_power_boost_pocketable",
    ["loc_pickup_syringe_pocketable_04"] = "syringe_speed_boost_pocketable",
}

local STIMM_SETTING_BY_PICKUP = {
    syringe_corruption_pocketable = "med",
    syringe_power_boost_pocketable = "combat",
    syringe_ability_boost_pocketable = "concentration",
    syringe_speed_boost_pocketable = "celerity",
}

-- ───────────────────── ❀ ─────────────────────
--  Settings & Ammo
-- ───────────────────── ❀ ─────────────────────

local function get_number(setting_id, fallback, optional_floor)
    local value = mod:get(setting_id)

    if type(value) ~= "number" or value ~= value then
        value = fallback
    end

    if optional_floor and value < optional_floor then
        return optional_floor
    end

    return value
end

local FALLBACK_CLIP_FRACTION = 0.15
local FALLBACK_BAG_FRACTION = 0.50

local function read_ammo_pickup_modifier()
    local ok, modifier = pcall(function()
        local game_mode_manager = Managers.state and Managers.state.game_mode
        local game_mode = game_mode_manager and game_mode_manager:game_mode()
        local havoc_extension = game_mode and game_mode:extension("havoc")

        return havoc_extension and havoc_extension:get_modifier_value("ammo_pickup_modifier")
    end)

    if ok and type(modifier) == "number" and modifier == modifier and modifier > 0 then
        return modifier
    end

    return 1
end

local function pickup_reserve_fraction(pickup_name, fallback_fraction)
    local pickup_settings = Pickups.by_name[pickup_name]
    local fraction = pickup_settings and pickup_settings.ammunition_percentage

    if type(fraction) ~= "number" or fraction ~= fraction or fraction <= 0 then
        return fallback_fraction
    end

    return fraction
end

local function ammo_pickup_fits(pickup_name, fallback_fraction, modifier, curr_reserve, max_reserve)
    local fraction = pickup_reserve_fraction(pickup_name, fallback_fraction)
    local amount = math.ceil(fraction * modifier * max_reserve)

    return max_reserve - curr_reserve >= amount
end

local function automatic_threshold(pickup_name, fallback_fraction, modifier)
    local fraction = pickup_reserve_fraction(pickup_name, fallback_fraction)

    return math.max(0, math.min(1, 1 - fraction * modifier))
end

-- ───────────────────── ❀ ─────────────────────
--  Class Stimms
-- ───────────────────── ❀ ─────────────────────

local STIMM_KEYS = { "med", "combat", "celerity", "concentration" }
local STIMM_DEFAULT_RANK = { med = 1, combat = 2, celerity = 3, concentration = 4 }

local function get_class_name()
    local ok, name = pcall(function()
        local player = Managers.player:local_player_safe(1)
        local profile = player and player:profile()
        return profile and profile.archetype and profile.archetype.name
    end)
    if ok and type(name) == "string" and name ~= "" then
        return name
    end
    return nil
end

local syncing_settings = false

local function sync_menu_from_store(class)
    syncing_settings = true
    for _, key in ipairs(STIMM_KEYS) do
        local enabled_id = "stimm_" .. key .. "_enabled"
        local rank_id = "stimm_" .. key .. "_rank"

        if class then
            local stored_enabled = mod:get(enabled_id .. "_" .. class)
            local stored_rank = mod:get(rank_id .. "_" .. class)

            if stored_enabled == nil then
                stored_enabled = true
                mod:set(enabled_id .. "_" .. class, stored_enabled)
            end
            if type(stored_rank) ~= "number" then
                stored_rank = STIMM_DEFAULT_RANK[key]
                mod:set(rank_id .. "_" .. class, stored_rank)
            end

            mod:set(enabled_id, stored_enabled)
            mod:set(rank_id, stored_rank)
        else
            mod:set(enabled_id, true)
            mod:set(rank_id, STIMM_DEFAULT_RANK[key])
        end
    end
    syncing_settings = false
end

local menu_class = nil
local unclassed_edits = {}

local function refresh_menu_class()
    if not mod:get("per_class_stimms") then
        menu_class = nil
        return
    end
    local class = get_class_name()
    if class and class ~= menu_class then
        menu_class = class
        for setting_id, value in pairs(unclassed_edits) do
            mod:set(setting_id .. "_" .. class, value)
            unclassed_edits[setting_id] = nil
        end
        sync_menu_from_store(class)
    end
end

function mod.on_setting_changed(setting_id)
    if syncing_settings then
        return
    end

    if setting_id == "per_class_stimms" then
        if mod:get("per_class_stimms") then
            menu_class = nil
            refresh_menu_class()
        else
            menu_class = nil
            sync_menu_from_store(nil)
        end
        return
    end

    if mod:get("per_class_stimms") then
        if setting_id:find("^stimm_.+_enabled$") or setting_id:find("^stimm_.+_rank$") then
            local class = menu_class or get_class_name()
            if class then
                mod:set(setting_id .. "_" .. class, mod:get(setting_id))
            else
                unclassed_edits[setting_id] = mod:get(setting_id)
            end
        end
    end
end

-- ───────────────────── ❀ ─────────────────────
--  Threshold Report
-- ───────────────────── ❀ ─────────────────────

local NON_MISSION_GAME_MODES = {
    default = true,
    hub = true,
    hub_singleplay = true,
    prologue_hub = true,
    shooting_range = true,
    training_grounds = true,
}

local function format_percent(fraction)
    return (string.format("%.1f", fraction * 100):gsub("%.0$", ""))
end

local function in_mission()
    local ok, result = pcall(function()
        local game_mode_manager = Managers.state and Managers.state.game_mode

        if not game_mode_manager then
            return false
        end

        local game_mode_name = game_mode_manager:game_mode_name()

        if type(game_mode_name) ~= "string" or NON_MISSION_GAME_MODES[game_mode_name] then
            return false
        end

        return not game_mode_manager:is_social_hub() and not game_mode_manager:is_prologue_hub()
    end)

    return ok and result == true
end

local function announce_thresholds()
    if not mod:get("auto_ammo_thresholds") or not mod:get("show_auto_ammo_threshold_notifications") then
        return
    end

    if not in_mission() then
        return
    end

    local modifier = read_ammo_pickup_modifier()

    mod:echo("%s", mod:localize("auto_ammo_thresholds"))
    mod:echo("%s %s%%", mod:localize("ammo_clip_threshold"),
        format_percent(automatic_threshold("small_clip", FALLBACK_CLIP_FRACTION, modifier)))
    mod:echo("%s %s%%", mod:localize("ammo_bag_threshold"),
        format_percent(automatic_threshold("large_clip", FALLBACK_BAG_FRACTION, modifier)))
end

mod:hook_require("scripts/game_states/game/gameplay_sub_states/gameplay_state_run", function(instance)
    mod:hook_safe(instance, "on_enter", function()
        announce_thresholds()
    end)
end)

-- ───────────────────── ❀ ─────────────────────
--  Class Refresh
-- ───────────────────── ❀ ─────────────────────

function mod.on_game_state_changed(status, state_name)
    if status == "enter" then
        refresh_menu_class()
    end
end

function mod.on_enabled()
    refresh_menu_class()
end

local function stimm_enabled(key)
    if mod:get("per_class_stimms") then
        local class = get_class_name()
        if class then
            local stored = mod:get("stimm_" .. key .. "_enabled_" .. class)
            if stored ~= nil then
                return stored
            end
        end
    end
    return mod:get("stimm_" .. key .. "_enabled")
end

local function stimm_rank(key)
    if mod:get("per_class_stimms") then
        local class = get_class_name()
        if class then
            local stored = mod:get("stimm_" .. key .. "_rank_" .. class)
            if type(stored) == "number" then
                return stored
            end
        end
    end
    return get_number("stimm_" .. key .. "_rank", STIMM_DEFAULT_RANK[key])
end

-- ───────────────────── ❀ ─────────────────────
--  Interactor
-- ───────────────────── ❀ ─────────────────────

local function get_interactor_extension()
    local player = Managers.player:local_player_safe(1)
    if not player then
        return nil
    end
    local player_unit = player.player_unit
    if not player_unit or not ALIVE[player_unit] then
        return nil
    end
    return ScriptUnit.has_extension(player_unit, "interactor_system")
end

local function get_live_target_unit()
    local interactor_extension = get_interactor_extension()
    if not interactor_extension then
        return nil
    end
    return interactor_extension:target_unit()
end

-- ───────────────────── ❀ ─────────────────────
--  Forced Press
-- ───────────────────── ❀ ─────────────────────

mod:hook("InputService", "_get", function(func, self, action_name)
    if cooldown <= 0 and pickup and action_name == "interact_pressed" then
        local live_unit = get_live_target_unit()

        if live_unit ~= nil and live_unit == pickup_unit and live_unit ~= pressed_unit then
            pressed_unit = live_unit
            cooldown = MIN_PRESS_COOLDOWN
            press_locked = true
            locked_fx, locked_fy, locked_fz = aim_fx, aim_fy, aim_fz

            if arm_kind then
                pending[arm_kind] = { value = arm_value, expiry = CONFIRM_TIMEOUT }
            end

            return true
        end

        return func(self, action_name)
    end
    return func(self, action_name)
end)

-- ───────────────────── ❀ ─────────────────────
--  Watched Values
-- ───────────────────── ❀ ─────────────────────

local function get_current_ammo(unit_data_extension, weapon_slot_configuration)
    for slot in pairs(weapon_slot_configuration) do
        local wieldable_component = unit_data_extension:read_component(slot)
        if wieldable_component.max_ammunition_reserve > 0 then
            return wieldable_component.current_ammunition_reserve,
                wieldable_component.max_ammunition_reserve
        end
    end
    return nil, nil
end

local function read_watch_values(unit_data_extension, weapon_slot_configuration, pocketable_template, stimm_template)
    local ammo_reserve = get_current_ammo(unit_data_extension, weapon_slot_configuration)

    return {
        ammo = ammo_reserve or false,
        grenades = unit_data_extension:read_component("grenade_ability").num_charges,
        stimm = stimm_template and stimm_template.swap_pickup_name or false,
        crate = pocketable_template ~= nil,
    }
end

-- ───────────────────── ❀ ─────────────────────
--  Frame Pass
-- ───────────────────── ❀ ─────────────────────

function mod.update(dt)
    if cooldown > 0 then
        cooldown = cooldown - dt
    end

    arm_kind = nil
    arm_value = nil

    for kind, watch in pairs(pending) do
        watch.expiry = watch.expiry - dt
        if watch.expiry <= 0 then
            pending[kind] = nil
        end
    end

    pickup = false
    pickup_unit = nil

    local interactor_extension = get_interactor_extension()
    local target_unit = interactor_extension and interactor_extension:target_unit() or nil

    if pressed_unit ~= nil and target_unit ~= pressed_unit then
        pressed_unit = nil
    end

    if target_unit ~= settled_unit then
        settled_unit = target_unit
        settled_for = 0.0
    else
        settled_for = settled_for + dt
    end

    local player = interactor_extension and Managers.player:local_player_safe(1)
    local player_unit = player and player.player_unit
    local unit_data_extension = player_unit and ScriptUnit.extension(player_unit, "unit_data_system")
    local eye, forward

    if unit_data_extension then
        eye, forward = read_aim(unit_data_extension)
    end

    if forward then
        aim_fx, aim_fy, aim_fz = forward.x, forward.y, forward.z
    end

    if press_locked then
        if target_unit == nil then
            press_locked = false
        elseif forward and aim_fx * locked_fx + aim_fy * locked_fy + aim_fz * locked_fz < AIM_TURN_COS then
            press_locked = false
        end
    end

    if not interactor_extension or not target_unit or not unit_data_extension then
        return
    end

    if interactor_extension:is_interacting() then
        return
    end

    local hud_description = interactor_extension:hud_description()
    if hud_description == nil then
        return
    end

    local function approve()
        pickup = true
        pickup_unit = target_unit
    end

    local function approve_watched(kind, value)
        approve()
        arm_kind = kind
        arm_value = value
    end

    local visual_loadout_extension = ScriptUnit.extension(player_unit, "visual_loadout_system")
    local pocketable_template = visual_loadout_extension:weapon_template_from_slot("slot_pocketable")
    local weapon_slot_configuration = visual_loadout_extension:slot_configuration_by_type("weapon")
    local stimm_template = visual_loadout_extension:weapon_template_from_slot("slot_pocketable_small")

    local watch_values = read_watch_values(unit_data_extension, weapon_slot_configuration, pocketable_template, stimm_template)

    for kind, watch in pairs(pending) do
        if watch_values[kind] ~= watch.value then
            pending[kind] = nil
        end
    end

    if press_locked or settled_for < get_number("press_delay_seconds", 0, 0) then
        return
    end

    local offset = aim_offset(eye, forward, target_unit)

    if offset and offset > get_number("aim_limit", 60, 1) / 100 then
        return
    end

    -- ───────────────────── ❀ ─────────────────────
    --  Category Walk
    -- ───────────────────── ❀ ─────────────────────

    if mod:get("open_chests") and (hud_description == "loc_chest") then
        approve()
        return
    end

    if mod:get("pickup_materials") and (hud_description == "loc_pickup_small_metal" or hud_description == "loc_pickup_large_metal") then
        approve()
        return
    end

    if mod:get("pickup_materials") and (hud_description == "loc_pickup_small_platinum" or hud_description == "loc_pickup_large_platinum") then
        approve()
        return
    end

    if mod:get("pickup_expedition_materials") and (hud_description:find("loc_expeditions_pickup_loot_quality_", 1, true) or hud_description:find("loc_expeditions_pickup_currency_quality_", 1, true) or hud_description == "loc_expeditions_pickup_loot_player_drop") then
        approve()
        return
    end

    if mod:get("pickup_event_items") and Unit.has_data(target_unit, "pickup_type") then
        local pickup_name = Unit.get_data(target_unit, "pickup_type")
        local pickup_settings = pickup_name and Pickups.by_name[pickup_name]
        if pickup_settings and pickup_settings.group == "rewards" then
            approve()
            return
        end
    end

    if mod:get("pickup_crates") and not pending.crate and (hud_description == "loc_pickup_pocketable_medical_crate_01" and not pocketable_template) then
        approve_watched("crate", watch_values.crate)
        return
    end

    if mod:get("pickup_crates") and not pending.crate and (hud_description == "loc_pickup_pocketable_ammo_crate_01" and not pocketable_template) then
        approve_watched("crate", watch_values.crate)
        return
    end

    local ground_pickup = STIMM_PICKUP_BY_HUD[hud_description]
    if ground_pickup then
        if pending.stimm then
            return
        end

        if mod:get("pickup_stimms") then
            local ground_key = STIMM_SETTING_BY_PICKUP[ground_pickup]

            if stimm_enabled(ground_key) then
                if not stimm_template then
                    approve_watched("stimm", watch_values.stimm)
                    return
                end

                local held_pickup = stimm_template.swap_pickup_name
                local held_key = held_pickup and STIMM_SETTING_BY_PICKUP[held_pickup]
                local ground_rank = stimm_rank(ground_key)
                local held_rank = held_key and stimm_rank(held_key) or math.huge

                if ground_rank < held_rank then
                    approve_watched("stimm", watch_values.stimm)
                    return
                end
            end
        end

        return
    end

    -- ───────────────────── ❀ ─────────────────────
    --  Gated Pickups
    -- ───────────────────── ❀ ─────────────────────

    local is_small_clip = hud_description == "loc_pickup_consumable_small_clip_01"
    local is_large_bag = hud_description == "loc_pickup_consumable_large_clip_01"

    if mod:get("pickup_ammo") and (is_small_clip or is_large_bag) and not pending.ammo then
        local curr_reserve, max_reserve = get_current_ammo(unit_data_extension, weapon_slot_configuration)

        if max_reserve and max_reserve > 0 then
            local automatic = mod:get("auto_ammo_thresholds") == true
            local modifier = automatic and read_ammo_pickup_modifier() or 1

            local reserve_fill = curr_reserve / max_reserve

            if is_small_clip then
                local take
                if automatic then
                    take = ammo_pickup_fits("small_clip", FALLBACK_CLIP_FRACTION, modifier, curr_reserve, max_reserve)
                else
                    take = reserve_fill <= get_number("ammo_clip_threshold", 85) / 100
                end

                if take then
                    approve_watched("ammo", watch_values.ammo)
                    return
                end
            end

            if is_large_bag then
                local take
                if automatic then
                    take = ammo_pickup_fits("large_clip", FALLBACK_BAG_FRACTION, modifier, curr_reserve, max_reserve)
                else
                    take = reserve_fill <= get_number("ammo_bag_threshold", 50) / 100
                end

                if take then
                    approve_watched("ammo", watch_values.ammo)
                    return
                end
            end
        end
    end

    if mod:get("pickup_grenades") and not pending.grenades and (hud_description == "loc_pickup_consumable_small_grenade_01" or hud_description == "loc_pickup_consumable_large_grenade_01") then
        local num_charges = watch_values.grenades
        if num_charges <= get_number("grenades_threshold", 1) then
            approve_watched("grenades", num_charges)
            return
        end
    end
end
