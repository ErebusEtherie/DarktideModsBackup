local mod = get_mod("AutoLoot")

local Pickups = require("scripts/settings/pickup/pickups")

local pickup = false
local pickup_unit = nil
local cooldown = 0.0

-- Every conditional pickup is armed here and stays pending until the value it
-- affects changes, which is the server confirming the pickup landed. Keyed by
-- category, so a watch on one category never displaces a watch on another.
-- Each entry is { value = <recorded value>, expiry = <seconds remaining> }.
local pending = {}
local arm_kind = nil
local arm_value = nil

-- Backstop for a pickup that never lands, such as a teammate taking the bag
-- first. Without it a pending watch would block that category permanently.
local CONFIRM_TIMEOUT = 2.0

-- Unit the mod has already forced a press for. One press per unit.
local pressed_unit = nil

-- Floor for the post-press cooldown. fixed_update can run twice against one
-- input sample, so a shorter delay lets the same press fire twice.
local MIN_PRESS_COOLDOWN = 0.1

-- hud_description mapped to pickup name. A held stimm reports the same name
-- through swap_pickup_name, so both sides of a swap share one namespace.
local STIMM_PICKUP_BY_HUD = {
    ["loc_pickup_pocketable_01"] = "syringe_corruption_pocketable",
    ["loc_pickup_syringe_pocketable_02"] = "syringe_ability_boost_pocketable",
    ["loc_pickup_syringe_pocketable_03"] = "syringe_power_boost_pocketable",
    ["loc_pickup_syringe_pocketable_04"] = "syringe_speed_boost_pocketable",
}

-- Pickup name mapped to the key used to build option ids. Internal names do
-- not match in-game ones: power_boost is Combat, ability_boost Concentration.
local STIMM_SETTING_BY_PICKUP = {
    syringe_corruption_pocketable = "med",
    syringe_power_boost_pocketable = "combat",
    syringe_ability_boost_pocketable = "concentration",
    syringe_speed_boost_pocketable = "celerity",
}

-- Numeric settings feed straight into arithmetic, so a malformed stored
-- value would throw every frame. optional_floor clamps low values.
local function get_number(setting_id, fallback, optional_floor)
    local value = mod:get(setting_id)

    -- NaN check.
    if type(value) ~= "number" or value ~= value then
        value = fallback
    end

    if optional_floor and value < optional_floor then
        return optional_floor
    end

    return value
end

-- Fractions of the maximum ammo reserve restored by each pickup, matching the
-- values in the game files. Used only when the pickup definition cannot be
-- read, so a future rename degrades to correct unmodified behaviour.
local FALLBACK_CLIP_FRACTION = 0.15
local FALLBACK_BAG_FRACTION = 0.50

-- Havoc scales ammo pickups through a modifier held on the game mode extension,
-- which is absent outside Havoc and on Havoc missions without the modifier. The
-- server copies the value into the difficulty manager, but that copy never
-- happens on a client, so the extension is the only route that works for
-- everyone. Several links in the chain are missing outside a mission.
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

-- Fraction of the maximum reserve a pickup restores, from the game's pickup
-- definition, with the recorded fallback covering a future field rename.
local function pickup_reserve_fraction(pickup_name, fallback_fraction)
    local pickup_settings = Pickups.by_name[pickup_name]
    local fraction = pickup_settings and pickup_settings.ammunition_percentage

    if type(fraction) ~= "number" or fraction ~= fraction or fraction <= 0 then
        return fallback_fraction
    end

    return fraction
end

-- Whether the full pickup fits into the reserve with nothing lost. Mirrors the
-- game's own grant: the amount is the pickup's fraction of the maximum reserve,
-- scaled by the Havoc modifier and rounded up, and it lands in the reserve
-- alone, so the clip plays no part in whether anything overflows.
local function ammo_pickup_fits(pickup_name, fallback_fraction, modifier, curr_reserve, max_reserve)
    local fraction = pickup_reserve_fraction(pickup_name, fallback_fraction)
    local amount = math.ceil(fraction * modifier * max_reserve)

    return max_reserve - curr_reserve >= amount
end

-- Reserve fill level the fit check corresponds to, for the mission start
-- report. Rounding the granted amount up to whole rounds moves the real
-- boundary by at most one round per weapon, so this is the idealized figure.
local function automatic_threshold(pickup_name, fallback_fraction, modifier)
    local fraction = pickup_reserve_fraction(pickup_name, fallback_fraction)

    return math.max(0, math.min(1, 1 - fraction * modifier))
end

-- Menu order and default preset. 1 is the highest priority.
local STIMM_KEYS = { "med", "combat", "celerity", "concentration" }
local STIMM_DEFAULT_RANK = { med = 1, combat = 2, celerity = 3, concentration = 4 }

-- Internal archetype name, or nil when no profile is readable. Availability
-- differs between hub, mission, and loading, hence the pcall.
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

-- Distinguishes a programmatic load from a user edit in on_setting_changed.
local syncing_settings = false

-- Copies a class store into the visible controls, seeding an untouched one
-- with the defaults. A nil class loads the defaults directly.
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

-- Class whose store the visible controls currently mirror.
local menu_class = nil

-- Re-points the visible controls when the played class has changed.
local function refresh_menu_class()
    if not mod:get("per_class_stimms") then
        menu_class = nil
        return
    end
    local class = get_class_name()
    if class and class ~= menu_class then
        menu_class = class
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
            -- Class stores are kept and restored when re-enabled.
            menu_class = nil
            sync_menu_from_store(nil)
        end
        return
    end

    -- Edits belong to the class the controls mirror, so menu_class is
    -- preferred over a live read that may briefly fail.
    if mod:get("per_class_stimms") then
        local class = menu_class or get_class_name()
        if class and (setting_id:find("^stimm_.+_enabled$") or setting_id:find("^stimm_.+_rank$")) then
            mod:set(setting_id .. "_" .. class, mod:get(setting_id))
        end
    end
end

-- Game modes that never carry an ammo modifier. Anything unlisted is treated as
-- a mission, so a future combat mode reports thresholds without a mod update.
local NON_MISSION_GAME_MODES = {
    default = true,
    hub = true,
    hub_singleplay = true,
    prologue_hub = true,
    shooting_range = true,
    training_grounds = true,
}

-- Whole numbers read as 85 rather than 85.0, while an unusual modifier that
-- lands between whole percentages keeps one decimal.
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

-- Reports the thresholds actually in force for the mission just entered, since
-- the automatic values are never shown in the options menu. Chat output reaches
-- the local player only, and DMF replays it once the chat window exists.
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

-- on_enter runs once per mission and after the Havoc extension is built, so the
-- modifier is readable by the time the thresholds are reported.
mod:hook_require("scripts/game_states/game/gameplay_sub_states/gameplay_state_run", function(instance)
    mod:hook_safe(instance, "on_enter", function()
        announce_thresholds()
    end)
end)

function mod.on_game_state_changed(status, state_name)
    -- Covers character switches, which always pass through a state change.
    if status == "enter" then
        refresh_menu_class()
    end
end

function mod.on_enabled()
    refresh_menu_class()
end

-- The class store is authoritative even if the menu sync has not caught up.
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

-- Reads the gameplay simulation rather than the HUD, so it still works with
-- the HUD hidden.
local function get_interactor_extension()
    -- local_player_safe returns nil before the connection is up. local_player
    -- crashes in the same situation.
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

-- Current target read fresh at input time, not the flag set in mod.update.
local function get_live_target_unit()
    local interactor_extension = get_interactor_extension()
    if not interactor_extension then
        return nil
    end
    return interactor_extension:target_unit()
end

mod:hook("InputService", "_get", function(func, self, action_name)
    if cooldown <= 0 and pickup and action_name == "interact_pressed" then
        -- Units compare by identity, so two identical items in one crate
        -- never match each other.
        local live_unit = get_live_target_unit()

        -- Without the latch the press repeats while the interaction resolves
        -- and can land on whatever the reticle snaps to next.
        if live_unit ~= nil and live_unit == pickup_unit and live_unit ~= pressed_unit then
            pressed_unit = live_unit
            cooldown = MIN_PRESS_COOLDOWN

            -- Arm the confirmation watch for the approved category. The value
            -- was read during the approving frame, before the pickup applied.
            if arm_kind then
                pending[arm_kind] = { value = arm_value, expiry = CONFIRM_TIMEOUT }
            end

            return true
        end

        return func(self, action_name)
    end
    return func(self, action_name)
end)

-- Reserve ammo state for the first ammo-using weapon, or nil when none is
-- equipped. Everything ammo-related works on the reserve alone, because a
-- pickup only ever fills the reserve while firing only drains the clip, so the
-- reserve is the only pool a pickup can overflow and the only value that
-- changes when one lands.
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

-- Snapshot of every value a forced pickup can change, taken once per frame.
-- The value recorded when a press was forced is compared against this on later
-- frames, so a category stays blocked until the server has actually applied the
-- previous pickup. false stands in for nil so an absent value still compares.
local function read_watch_values(unit_data_extension, weapon_slot_configuration, pocketable_template, stimm_template)
    local ammo_reserve = get_current_ammo(unit_data_extension, weapon_slot_configuration)

    return {
        ammo = ammo_reserve or false,
        grenades = unit_data_extension:read_component("grenade_ability").num_charges,
        stimm = stimm_template and stimm_template.swap_pickup_name or false,
        crate = pocketable_template ~= nil,
    }
end

function mod.update(dt)
    if cooldown > 0 then
        cooldown = cooldown - dt
    end

    -- Arming lasts only for the frame that approved it. The input hook runs
    -- between updates, so a stale arm must never survive into the next frame.
    arm_kind = nil
    arm_value = nil

    -- Clearing a field during a pairs traversal is safe, so expired watches are
    -- dropped in place.
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

    -- Latch clears once the pressed unit stops being the target, which covers
    -- both a completed pickup and the player looking away.
    if pressed_unit ~= nil and target_unit ~= pressed_unit then
        pressed_unit = nil
    end

    if not interactor_extension or not target_unit then
        return
    end

    -- InteractorExtension only reads the interact input while waiting_to_interact.
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

    -- Approves a pickup and records the value whose change will confirm it, so
    -- a second pickup behind the first is not taken on a count, slot, or charge
    -- total that has not updated yet.
    local function approve_watched(kind, value)
        approve()
        arm_kind = kind
        arm_value = value
    end

    local player = Managers.player:local_player_safe(1)
    if not player then
        return
    end
    local player_unit = player.player_unit
    local unit_data_extension = ScriptUnit.extension(player_unit, "unit_data_system")
    local visual_loadout_extension = ScriptUnit.extension(player_unit, "visual_loadout_system")
    local pocketable_template = visual_loadout_extension:weapon_template_from_slot("slot_pocketable")
    local weapon_slot_configuration = visual_loadout_extension:slot_configuration_by_type("weapon")
    local stimm_template = visual_loadout_extension:weapon_template_from_slot("slot_pocketable_small")

    local watch_values = read_watch_values(unit_data_extension, weapon_slot_configuration, pocketable_template, stimm_template)

    -- A pending watch clears as soon as the value it tracks changes, which is
    -- the confirmation that the pickup applied. This unblocks sooner than a
    -- fixed delay on a good connection and waits longer on a poor one.
    for kind, watch in pairs(pending) do
        if watch_values[kind] ~= watch.value then
            pending[kind] = nil
        end
    end

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

    -- Live event collectibles. Matched by pickup group instead of localization
    -- string, so future event items in the rewards group need no mod update.
    -- has_data keeps the lookup off targets that are not pickups.
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

    -- Only reached for a stimm the player can take. An unavailable one, such
    -- as a street stimm against a Cartel-locked Hive Scum, is a focus target
    -- rather than a real target and returns above.
    local ground_pickup = STIMM_PICKUP_BY_HUD[hud_description]
    if ground_pickup then
        -- The previous stimm has not been confirmed into the slot yet, so a
        -- rank comparison here would read the slot as it was before that
        -- pickup and could swap a just-taken stimm straight back out.
        if pending.stimm then
            return
        end

        if mod:get("pickup_stimms") then
            local ground_key = STIMM_SETTING_BY_PICKUP[ground_pickup]

            if stimm_enabled(ground_key) then
                if not stimm_template then
                    -- Empty slot: grab any enabled stimm, priority ignored.
                    approve_watched("stimm", watch_values.stimm)
                    return
                end

                -- Slot occupied: swap only on a strictly better rank, lower
                -- being better. An unrecognised held stimm ranks below all.
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

        -- Recognised stimm, so do not fall through to the checks below.
        return
    end


    -- Below here the categories are threshold gated. Everything above
    -- matches on hud_description alone.
    local is_small_clip = hud_description == "loc_pickup_consumable_small_clip_01"
    local is_large_bag = hud_description == "loc_pickup_consumable_large_clip_01"

    if mod:get("pickup_ammo") and (is_small_clip or is_large_bag) and not pending.ammo then
        -- nil when the equipped weapon uses no ammo, such as a psyker staff.
        local curr_reserve, max_reserve = get_current_ammo(unit_data_extension, weapon_slot_configuration)

        if max_reserve and max_reserve > 0 then
            -- Read once and shared by both sizes. The modifier is fixed for the
            -- mission, and only one of the two branches below can match anyway.
            local automatic = mod:get("auto_ammo_thresholds") == true
            local modifier = automatic and read_ammo_pickup_modifier() or 1

            -- Sliders measure reserve fill, matching the pool a pickup
            -- actually restores. Loaded rounds play no part.
            local reserve_fill = curr_reserve / max_reserve

            -- Both sizes arm the watch. A small clip raises the same reserve a
            -- large bag is judged against, so taking one without waiting for
            -- confirmation leaves the bag behind it measured against the
            -- pre-pickup reserve.
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
        -- grenade_ability exists on every player unit, so num_charges is
        -- always a number here.
        local num_charges = watch_values.grenades
        if num_charges <= get_number("grenades_threshold", 1) then
            approve_watched("grenades", num_charges)
            return
        end
    end
end
