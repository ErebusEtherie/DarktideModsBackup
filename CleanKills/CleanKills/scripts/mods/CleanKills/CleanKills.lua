local mod = get_mod("CleanKills")
local Breed = require("scripts/utilities/breed")

mod.version = "1.1.4"

local RAGDOLL_REMOVE_RETRY_DELAY = 0.15
local MAX_RAGDOLL_REMOVALS_PER_FRAME = 8
local MAX_RETRY_FAILURES = 3
local HUSK_DEATH_SCAN_INTERVAL = 0.06
local RAGDOLL_SWEEP_INTERVAL = 0.2
local MAX_RAGDOLL_SWEEP_PER_TICK = 16
local MAX_TRACKED_ENTRY_AGE = 12
local METRICS_SUMMARY_INTERVAL = 10
local POST_REMOVE_CONFIRM_DELAY = 0.15
-- Matches the game's own telemetry ping sampling cadence
-- (PingReporter.SAMPLE_INTERVAL in ping_reporter.lua) - Network.ping()'s
-- underlying RTT estimate doesn't change every render frame, so sampling
-- faster than this just re-reads the same cached value.
local PING_SAMPLE_INTERVAL = 1
local EXCLUDED_BREED_NAMES_ALWAYS = {
    -- nurgle excluded due to needing to see death explosion
    chaos_beast_of_nurgle = true,
    -- twins excluded due to corner case: temporary death > invisible
    renegade_twin_captain = true,
    renegade_twin_captain_two = true,
}

-- Persistent per-session removal queue.
-- Each entry: { unit, unit_key, manager, time_left, age, failures, queue_index }
mod._ck_removal_queue = mod._ck_removal_queue or {}
-- Weak-keyed by unit for fast direct lookup. Note: this does not make entries
-- GC-able on its own -- each entry also holds a strong entry.unit reference
-- and is reachable from the queue array and the non-weak by_key/by_tostring
-- indexes below, so the unit stays alive until the entry is explicitly
-- removed via clear_entry_indexes regardless of this table's mode.
mod._ck_removal_index = mod._ck_removal_index or setmetatable({}, { __mode = "k" })
-- Some callbacks can hand us different unit wrappers for the same corpse; keep
-- a stable key index to prevent duplicate queue entries/removals for one death.
mod._ck_removal_index_by_key = mod._ck_removal_index_by_key or {}
-- Secondary identity for wrapper churn cases where engine id lookup flips
-- availability across callbacks in the same death lifecycle.
mod._ck_removal_index_by_tostring = mod._ck_removal_index_by_tostring or {}
mod._ck_processed_husk_deaths = mod._ck_processed_husk_deaths or setmetatable({}, { __mode = "k" })
mod._ck_next_husk_dead_scan_t = mod._ck_next_husk_dead_scan_t or 0
mod._ck_ragdoll_sweep_elapsed = mod._ck_ragdoll_sweep_elapsed or 0
mod._ck_metrics_summary_elapsed = mod._ck_metrics_summary_elapsed or 0
-- nil = not yet determined this mission (e.g. still in hub/menus).
mod._ck_is_authoritative_host = nil
mod._ck_ping_sum_ms = mod._ck_ping_sum_ms or 0
mod._ck_ping_sample_count = mod._ck_ping_sample_count or 0
mod._ck_ping_sample_elapsed = mod._ck_ping_sample_elapsed or 0
mod._ck_metrics = mod._ck_metrics or {
    queued_total = 0,
    removed_total = 0,
    retry_total = 0,
    abandoned_total = 0,
    dropped_by_age_total = 0,
    frame_deferred_total = 0,
    peak_queue_size = 0,
    -- Attribution of which detection path first queued a given corpse, kept
    -- separate from queued_total (which also counts the ragdoll/kill hooks).
    -- Lets triage logs show whether the unit_died event listener is actually
    -- beating the husk poll fallback in the field.
    event_queued_total = 0,
    husk_scan_queued_total = 0,
}

local function is_triage_logging_enabled()
    return mod:get("enable_triage_logs") == true
end

local function triage_log(message)
    if not is_triage_logging_enabled() then
        return
    end

    mod:info(string.format("[triage] %s", message))
end

local function is_unit_deleted_handle(unit)
    if not unit then
        return false
    end

    local unit_string = tostring(unit)
    return type(unit_string) == "string" and string.find(unit_string, "(deleted)", 1, true) ~= nil
end

local function get_metrics_snapshot()
    local queue = mod._ck_removal_queue
    local snapshot = {
        queue_size_current = #queue,
        hidden_current = 0,
        no_manager_current = 0,
        retrying_current = 0,
        avg_queue_age = 0,
        oldest_queue_age = 0,
    }

    local age_total = 0
    for i = 1, #queue do
        local entry = queue[i]
        if entry then
            local age = entry.age or 0
            age_total = age_total + age
            if age > snapshot.oldest_queue_age then
                snapshot.oldest_queue_age = age
            end

            if entry.hidden == true then
                snapshot.hidden_current = snapshot.hidden_current + 1
            end

            if entry.manager == nil then
                snapshot.no_manager_current = snapshot.no_manager_current + 1
            end

            if (entry.failures or 0) > 0 then
                snapshot.retrying_current = snapshot.retrying_current + 1
            end
        end
    end

    if snapshot.queue_size_current > 0 then
        snapshot.avg_queue_age = age_total / snapshot.queue_size_current
    end

    return snapshot
end

-- Authoritative-host status is only known once Managers.connection exists
-- with a settled host/client role; nil means "not yet determined this
-- mission" (e.g. still in hub/menus, or connection not established yet).
local function refresh_authoritative_host_status()
    local connection_manager = Managers and Managers.connection
    if not connection_manager or type(connection_manager.is_host) ~= "function" then
        return
    end

    local ok, is_host = pcall(connection_manager.is_host, connection_manager)
    if ok and type(is_host) == "boolean" then
        mod._ck_is_authoritative_host = is_host
    end
end

local function log_authoritative_host_status()
    refresh_authoritative_host_status()

    local status = mod._ck_is_authoritative_host
    triage_log(string.format(
        "mission start: authoritative_host=%s",
        status == nil and "unknown" or tostring(status)
    ))
end

-- Ping is only meaningful for non-host clients (a host has no RTT to
-- itself); samples accumulate at PING_SAMPLE_INTERVAL while triage logging
-- is on and get averaged/reset each time a [triage metrics] summary line is
-- emitted, so the value reflects "since the last triage log event" as
-- requested.
local function sample_ping(dt)
    mod._ck_ping_sample_elapsed = (mod._ck_ping_sample_elapsed or 0) + dt
    if mod._ck_ping_sample_elapsed < PING_SAMPLE_INTERVAL then
        return
    end
    mod._ck_ping_sample_elapsed = 0

    local connection_manager = Managers and Managers.connection
    if not connection_manager or type(connection_manager.is_client) ~= "function" then
        return
    end

    local is_client_ok, is_client = pcall(connection_manager.is_client, connection_manager)
    if not is_client_ok or not is_client then
        return
    end

    local host_ok, host_peer_id = pcall(connection_manager.host, connection_manager)
    if not host_ok or not host_peer_id then
        return
    end

    local ping_ok, ping_seconds = pcall(Network.ping, host_peer_id)
    if not ping_ok or type(ping_seconds) ~= "number" then
        return
    end

    mod._ck_ping_sum_ms = (mod._ck_ping_sum_ms or 0) + ping_seconds * 1000
    mod._ck_ping_sample_count = (mod._ck_ping_sample_count or 0) + 1
end

local function log_metrics_snapshot(prefix)
    local snapshot = get_metrics_snapshot()
    local metrics = mod._ck_metrics or {}

    local avg_ping_ms = 0
    local ping_sample_count = mod._ck_ping_sample_count or 0
    if ping_sample_count > 0 then
        avg_ping_ms = (mod._ck_ping_sum_ms or 0) / ping_sample_count
    end
    mod._ck_ping_sum_ms = 0
    mod._ck_ping_sample_count = 0

    local host_status = mod._ck_is_authoritative_host
    local host_field = host_status == nil and "?" or (host_status and "1" or "0")

    mod:info(string.format(
        "%s host=%s avg_ping_ms=%.1f(%d) queue=%d hidden=%d no_manager=%d retrying=%d avg_age=%.2f oldest_age=%.2f queued=%d removed=%d retry=%d abandoned=%d age_dropped=%d deferred=%d peak=%d event_queued=%d husk_scan_queued=%d",
        prefix or "[metrics]",
        host_field,
        avg_ping_ms,
        ping_sample_count,
        snapshot.queue_size_current,
        snapshot.hidden_current,
        snapshot.no_manager_current,
        snapshot.retrying_current,
        snapshot.avg_queue_age,
        snapshot.oldest_queue_age,
        metrics.queued_total or 0,
        metrics.removed_total or 0,
        metrics.retry_total or 0,
        metrics.abandoned_total or 0,
        metrics.dropped_by_age_total or 0,
        metrics.frame_deferred_total or 0,
        metrics.peak_queue_size or 0,
        metrics.event_queued_total or 0,
        metrics.husk_scan_queued_total or 0
    ))

    return snapshot
end

local function maybe_log_metrics_summary(dt)
    if not is_triage_logging_enabled() then
        return
    end

    sample_ping(dt)

    mod._ck_metrics_summary_elapsed = (mod._ck_metrics_summary_elapsed or 0) + dt
    if mod._ck_metrics_summary_elapsed < METRICS_SUMMARY_INTERVAL then
        return
    end

    mod._ck_metrics_summary_elapsed = 0
    log_metrics_snapshot("[triage metrics]")
end

local function get_unit_key(unit)
    if not unit then
        return nil
    end

    -- Prefer engine identity (network id / level index) over tostring(unit)
    -- because tostring can differ across wrappers for the same underlying unit.
    -- NOTE: when unit_spawner is unavailable (e.g. around state transitions),
    -- this falls back to tostring(unit) -- the same value handle_dead_unit/
    -- queue_upsert already use as their own last-resort identity key. In that
    -- failure mode all identity layers collapse to plain tostring(unit), so
    -- the "three layers of dedup" are not independent protection against
    -- rapid address/wrapper reuse; they only add coverage when the engine
    -- lookup below actually succeeds.
    local unit_spawner = Managers and Managers.state and Managers.state.unit_spawner
    if unit_spawner and unit_spawner.game_object_id_or_level_index then
        local ok, is_level_unit, id = pcall(unit_spawner.game_object_id_or_level_index, unit_spawner, unit)
        if ok and id ~= nil then
            if is_level_unit then
                return "lvl:" .. tostring(id)
            end

            return "net:" .. tostring(id)
        end
    end

    return tostring(unit)
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function is_unit_alive(unit)
    if not unit then
        return false
    end
    local ALIVE = rawget(_G, "ALIVE")
    if ALIVE ~= nil then
        return ALIVE[unit] == true
    end
    if Unit and Unit.alive then
        local ok, alive = pcall(Unit.alive, unit)
        return ok and alive == true
    end
    return false
end

local function hide_single_unit(unit)
    if not unit then
        return
    end

    pcall(Unit.set_unit_visibility, unit, false, true)
end

-- Gear items (weapons/helmets/armor), their attachments and gib stumps are
-- separate units linked to the corpse's skeleton. Hiding the base unit does
-- not cascade to linked units, so without this they keep visibly riding the
-- (hidden) skeleton's death animation until the engine deletes the corpse.
local function hide_attached_units(unit)
    local visual_loadout_extension = ScriptUnit.has_extension(unit, "visual_loadout_system")
    if visual_loadout_extension then
        if type(visual_loadout_extension.slot_items) == "function" then
            local ok, slots = pcall(visual_loadout_extension.slot_items, visual_loadout_extension)
            if ok and type(slots) == "table" then
                for _, slot_data in pairs(slots) do
                    if type(slot_data) == "table" then
                        hide_single_unit(slot_data.unit)

                        local attachments = slot_data.attachments
                        if type(attachments) == "table" then
                            for i = 1, #attachments do
                                hide_single_unit(attachments[i])
                            end
                        end
                    end
                end
            end
        end

        -- Flying gib chunks (severed heads/limbs) are free physics units the
        -- game keeps as gore debris until the corpse unit is deleted.
        local gibbing = visual_loadout_extension._minion_gibbing
        if type(gibbing) == "table" then
            local gibs = gibbing._gibs
            if type(gibs) == "table" then
                for _, gib_units in pairs(gibs) do
                    if type(gib_units) == "table" then
                        for i = 1, #gib_units do
                            hide_single_unit(gib_units[i])
                        end
                    end
                end
            end

            local flesh_gibs = gibbing._flesh_gibs
            if type(flesh_gibs) == "table" then
                for _, gib_flesh_unit in pairs(flesh_gibs) do
                    hide_single_unit(gib_flesh_unit)
                end
            end
        end
    end

    -- Gib stump units are registered on the dissolve extension when spawned
    -- (minion_gibbing.lua -> dissolve_extension:register_stump_unit). Stumps
    -- spawn in the same frame as the kill, after the first hide, so the
    -- periodic re-hide passes are what actually catch them.
    local dissolve_extension = ScriptUnit.has_extension(unit, "dissolve_system")
    if dissolve_extension then
        local stump_units = dissolve_extension._stump_units
        if type(stump_units) == "table" then
            for i = 1, #stump_units do
                hide_single_unit(stump_units[i])
            end
        end
    end
end

local function hide_unit(unit)
    if not unit then
        return
    end

    -- Attempt regardless of ALIVE state; some no-ragdoll/animation deaths can
    -- transition ALIVE while the renderable is still visible for a short window.
    pcall(Unit.set_unit_visibility, unit, false, true)
    hide_attached_units(unit)
end

local function get_configured_remove_delay()
    return 0
end

local function manager_has_ragdoll(manager, unit)
    local ragdolls = manager and manager._ragdolls
    if not ragdolls or not unit then
        return false
    end

    return table.find(ragdolls, unit) ~= nil
end

local function is_minion_unit(unit)
    if not unit then
        return false
    end

    local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
    if not unit_data_extension then
        return false
    end

    local breed = unit_data_extension:breed()
    return Breed.is_minion(breed)
end

local function is_excluded_unit(unit, unit_data_extension)
    if not unit then
        return false
    end

    local extension = unit_data_extension or ScriptUnit.has_extension(unit, "unit_data_system")
    if extension and type(extension.breed) == "function" then
        local ok, breed = pcall(extension.breed, extension)
        if ok and breed and EXCLUDED_BREED_NAMES_ALWAYS[breed.name] then
            return true
        end
    end

    return false
end

local function is_enemy_minion_unit(unit)
    -- Breed.is_minion only tells us the unit architecture/class. It does not
    -- guarantee hostility to players (allied/summoned minions can still be minions).
    -- Keep both checks so CleanKills remains strictly enemy-only.
    if not is_minion_unit(unit) then
        return false
    end

    local extension_manager = Managers and Managers.state and Managers.state.extension
    if not extension_manager then
        return false
    end

    local side_system = extension_manager:system("side_system")
    if not side_system then
        return false
    end

    local unit_side = side_system.side_by_unit and side_system.side_by_unit[unit]
    if not unit_side then
        return false
    end

    local player_side_name = side_system:get_default_player_side_name()
    local player_side = player_side_name and side_system:get_side_from_name(player_side_name)
    if not player_side then
        return false
    end

    -- Side relation is the authoritative hostility check.
    return side_system:is_enemy_by_side(player_side, unit_side)
end

local function classify_dead_unit_eligibility(manager, unit)
    if not unit then
        return false, "unit_nil"
    end

    local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
    if is_excluded_unit(unit, unit_data_extension) then
        return false, "excluded_exception"
    end

    -- If this callback is coming from MinionRagdoll and the unit is tracked there,
    -- accept it even when post-death side info has already been stripped.
    if manager and manager_has_ragdoll(manager, unit) then
        return true, "manager_ragdoll"
    end

    if not unit_data_extension then
        return false, "no_unit_data_extension"
    end

    local breed = unit_data_extension:breed()
    if not Breed.is_minion(breed) then
        return false, "not_minion"
    end

    local extension_manager = Managers and Managers.state and Managers.state.extension
    if not extension_manager then
        -- Post-death cleanup can transiently remove side data; keep minion corpses
        -- eligible so we do not miss valid ragdoll removals.
        return true, "side_unavailable_extension_manager"
    end

    local side_system = extension_manager:system("side_system")
    if not side_system then
        -- Same rationale as above: accept when hostility data is unavailable.
        return true, "side_unavailable_side_system"
    end

    local unit_side = side_system.side_by_unit and side_system.side_by_unit[unit]
    local player_side_name = side_system:get_default_player_side_name()
    local player_side = player_side_name and side_system:get_side_from_name(player_side_name)

    if not unit_side or not player_side then
        -- Preserve strict enemy-only behavior when relation data exists; only
        -- fall back when the relation lookup itself is unavailable.
        return true, "side_unavailable_side_data"
    end

    if side_system:is_enemy_by_side(player_side, unit_side) then
        return true, "enemy_side"
    end

    return false, "non_enemy_side"
end

local queue_upsert
local is_unit_marked_for_deletion

local function clear_entry_indexes(entry)
    if not entry then
        return
    end

    if entry.unit then
        mod._ck_removal_index[entry.unit] = nil
    end

    if entry.unit_key then
        mod._ck_removal_index_by_key[entry.unit_key] = nil
    end

    if entry.unit_string_key then
        mod._ck_removal_index_by_tostring[entry.unit_string_key] = nil
    elseif entry.unit then
        mod._ck_removal_index_by_tostring[tostring(entry.unit)] = nil
    end
end

local function is_entry_active_in_queue(entry)
    if not entry then
        return false
    end

    local queue_index = entry.queue_index
    if type(queue_index) ~= "number" then
        return false
    end

    local queue = mod._ck_removal_queue
    return queue[queue_index] == entry
end

local function refresh_entry_identity(entry, unit, unit_key, unit_string_key)
    if not entry or not unit then
        return
    end

    local old_unit = entry.unit
    local old_key = entry.unit_key
    local old_string_key = entry.unit_string_key

    if old_unit and old_unit ~= unit then
        mod._ck_removal_index[old_unit] = nil
    end

    if old_key and old_key ~= unit_key then
        mod._ck_removal_index_by_key[old_key] = nil
    end

    if old_string_key and old_string_key ~= unit_string_key then
        mod._ck_removal_index_by_tostring[old_string_key] = nil
    end

    entry.unit = unit
    entry.unit_key = unit_key
    entry.unit_string_key = unit_string_key

    mod._ck_removal_index[unit] = entry
    if unit_key then
        mod._ck_removal_index_by_key[unit_key] = entry
    end
    mod._ck_removal_index_by_tostring[unit_string_key] = entry
end

local function handle_dead_unit(manager, unit, delay)
    local unit_key = get_unit_key(unit)
    local unit_string_key = tostring(unit)
    local eligible, reason = classify_dead_unit_eligibility(manager, unit)
    if not eligible then
        -- if reason == "excluded_exception" then
        --    triage_log(string.format("skip excluded corpse exception (unit=%s)", tostring(unit)))
        -- end

        return false
    end

    local existing = mod._ck_removal_index[unit]
        or (unit_key and mod._ck_removal_index_by_key[unit_key])
        or mod._ck_removal_index_by_tostring[unit_string_key]

    if existing and not is_entry_active_in_queue(existing) then
        clear_entry_indexes(existing)
        existing = nil
    end

    if existing and is_unit_deleted_handle(existing.unit) then
        -- Avoid reusing a stale deleted-handle entry when the engine recycles
        -- ids/wrappers rapidly (common in Psykhanium loops).
        clear_entry_indexes(existing)
        existing = nil
    end

    if existing then
        -- Allow later callbacks (e.g. create_ragdoll) to enrich an already
        -- queued entry with a manager reference for deterministic removal.
        refresh_entry_identity(existing, unit, unit_key, unit_string_key)
        existing.manager = manager or existing.manager
        existing.time_left = math.min(existing.time_left or delay, delay)
        existing.age = 0
        existing.failures = 0
        existing.pending_remove_confirm = false
        existing.fallback_no_manager = false

        if delay <= 0 then
            hide_unit(unit)
            existing.hidden = true
        end
        return false
    end

    if delay <= 0 then
        hide_unit(unit)
    end

    queue_upsert(manager, unit, delay, unit_key)

    return true
end

-- ---------------------------------------------------------------------------
-- Removal queue
-- ---------------------------------------------------------------------------

queue_upsert = function(manager, unit, delay, unit_key)
    if not unit then
        return
    end

    local queue = mod._ck_removal_queue
    local index = mod._ck_removal_index
    local index_by_key = mod._ck_removal_index_by_key
    local index_by_tostring = mod._ck_removal_index_by_tostring
    local unit_string_key = tostring(unit)
    unit_key = unit_key or get_unit_key(unit)

    local existing = index[unit]
        or (unit_key and index_by_key[unit_key])
        or index_by_tostring[unit_string_key]
    if existing and not is_entry_active_in_queue(existing) then
        clear_entry_indexes(existing)
        existing = nil
    end

    if existing then
        refresh_entry_identity(existing, unit, unit_key, unit_string_key)
        existing.manager = manager or existing.manager
        existing.time_left = math.min(existing.time_left or delay, delay)
        existing.age = 0
        existing.failures = 0
        existing.pending_remove_confirm = false
        existing.fallback_no_manager = false
        return
    end

    local metrics = mod._ck_metrics
    local queue_index = #queue + 1
    local entry = {
        unit = unit,
        unit_key = unit_key,
        unit_string_key = unit_string_key,
        manager = manager,
        time_left = delay,
        age = 0,
        hidden = false,
        failures = 0,
        fallback_no_manager = false,
        pending_remove_confirm = false,
        queue_index = queue_index,
    }
    queue[queue_index] = entry
    index[unit] = entry
    if unit_key then
        index_by_key[unit_key] = entry
    end
    index_by_tostring[unit_string_key] = entry

    metrics.queued_total = (metrics.queued_total or 0) + 1
    if #queue > (metrics.peak_queue_size or 0) then
        metrics.peak_queue_size = #queue
    end
end

local function queue_flush()
    local queue = mod._ck_removal_queue
    for i = #queue, 1, -1 do
        queue[i] = nil
    end
    mod._ck_removal_index = setmetatable({}, { __mode = "k" })
    mod._ck_removal_index_by_key = {}
    mod._ck_removal_index_by_tostring = {}
end

local function reset_mod_state()
    queue_flush()
    mod._ck_processed_husk_deaths = setmetatable({}, { __mode = "k" })
    mod._ck_next_husk_dead_scan_t = 0
    mod._ck_ragdoll_sweep_elapsed = 0
    -- Avoid blending ping samples from the connection this mission is
    -- leaving/entering into the next averaging window.
    mod._ck_ping_sum_ms = 0
    mod._ck_ping_sample_count = 0
    mod._ck_ping_sample_elapsed = 0
    triage_log("state reset and queue flushed")
end

local function maybe_sweep_active_ragdolls(dt)
    if not mod:is_enabled() then
        return
    end

    mod._ck_ragdoll_sweep_elapsed = (mod._ck_ragdoll_sweep_elapsed or 0) + dt
    if mod._ck_ragdoll_sweep_elapsed < RAGDOLL_SWEEP_INTERVAL then
        return
    end

    mod._ck_ragdoll_sweep_elapsed = 0

    local minion_death_manager = Managers and Managers.state and Managers.state.minion_death
    if not minion_death_manager or type(minion_death_manager.minion_ragdoll) ~= "function" then
        return
    end

    local ragdoll_manager = minion_death_manager:minion_ragdoll()
    local ragdolls = ragdoll_manager and ragdoll_manager._ragdolls
    if not ragdolls or #ragdolls == 0 then
        return
    end

    local remove_delay = get_configured_remove_delay()
    local scanned = 0

    for i = #ragdolls, 1, -1 do
        local unit = ragdolls[i]
        if unit then
            handle_dead_unit(ragdoll_manager, unit, remove_delay)
            scanned = scanned + 1
            if scanned >= MAX_RAGDOLL_SWEEP_PER_TICK then
                break
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Core corpse-hiding hook
-- Intercept MinionRagdoll.create_ragdoll (called on both server and client paths):
--   server: MinionDeathManager._server_finalize_death -> create_ragdoll
--   client: MinionDeathManager.client_finalize_death  -> create_ragdoll
-- These are observation-only (never gate or alter the original call), so they
-- use hook_safe wherever possible to keep a CleanKills-side bug from being
-- able to crash the game via an unprotected hook.
-- ---------------------------------------------------------------------------

local function install_ragdoll_hook(MinionRagdoll)
    if mod._ck_ragdoll_hook_installed then
        return
    end

    if type(MinionRagdoll) ~= "table" or type(MinionRagdoll.create_ragdoll) ~= "function" then
        return
    end

    mod._ck_ragdoll_hook_installed = true

    mod:hook_safe(MinionRagdoll, "create_ragdoll", function(self, death_data)
        if not mod:is_enabled() then
            return
        end

        local unit = death_data and death_data.unit
        if unit then
            handle_dead_unit(self, unit, get_configured_remove_delay())
        end
    end)
end

mod:hook_require("scripts/managers/minion/minion_ragdoll", function(MinionRagdoll)
    install_ragdoll_hook(MinionRagdoll)
end)

mod:hook_require("scripts/managers/minion/minion_death_manager", function(MinionDeathManager)
    if mod._ck_death_manager_hook_installed then
        return
    end

    if type(MinionDeathManager) ~= "table" or type(MinionDeathManager.set_dead) ~= "function" then
        return
    end

    mod._ck_death_manager_hook_installed = true

    mod:hook_safe(MinionDeathManager, "set_dead", function(self, unit)
        if not mod:is_enabled() or not unit then
            return
        end

        handle_dead_unit(nil, unit, get_configured_remove_delay())
    end)

    if not mod._ck_death_manager_finalize_server_hook_installed then
        mod._ck_death_manager_finalize_server_hook_installed = true

        mod:hook_safe(MinionDeathManager, "_server_finalize_death", function(self, death_data)
            if not mod:is_enabled() then
                return
            end

            local unit = death_data and death_data.unit
            local no_ragdoll = death_data and death_data.no_ragdoll == true

            if no_ragdoll and unit then
                handle_dead_unit(nil, unit, get_configured_remove_delay())
            end
        end)
    end

    if not mod._ck_death_manager_finalize_client_hook_installed then
        mod._ck_death_manager_finalize_client_hook_installed = true

        -- Must stay a regular hook (not hook_safe): client_finalize_death clears
        -- self._minions_awaiting_death[unit] as part of its own body, so death_data
        -- has to be captured before func runs, not after. The CleanKills-side work
        -- is still pcall-wrapped so a bug here can't propagate into the engine call.
        mod:hook(MinionDeathManager, "client_finalize_death", function(func, self, unit, unit_id)
            local death_data = self._minions_awaiting_death and self._minions_awaiting_death[unit]
            local no_ragdoll = death_data and death_data.no_ragdoll == true

            local result = func(self, unit, unit_id)

            if mod:is_enabled() and no_ragdoll and unit then
                mod:pcall(handle_dead_unit, nil, unit, get_configured_remove_delay())
            end

            return result
        end)
    end
end)

local function install_health_kill_hook(HealthClass, class_name)
    if type(HealthClass) ~= "table" or type(HealthClass.kill) ~= "function" then
        return
    end

    local key = "_ck_health_kill_hook_installed_" .. class_name
    if mod[key] then
        return
    end
    mod[key] = true

    mod:hook_safe(HealthClass, "kill", function(self)
        if not mod:is_enabled() then
            return
        end

        local unit = self and self._unit
        if not is_enemy_minion_unit(unit) then
            return
        end

        handle_dead_unit(nil, unit, get_configured_remove_delay())
    end)
end

mod:hook_require("scripts/extension_systems/health/health_extension", function(HealthExtension)
    install_health_kill_hook(HealthExtension, "HealthExtension")
end)

mod:hook_require("scripts/extension_systems/health/health_system", function(HealthSystem)
    if type(HealthSystem._update_is_dead_status_husk) ~= "function" then
        return
    end

    if mod._ck_health_hook_installed then
        return
    end
    mod._ck_health_hook_installed = true

    mod:hook_safe(HealthSystem, "_update_is_dead_status_husk", function(self, dt, t)
        if not mod:is_enabled() then
            return
        end

        local now = t or 0
        if now < (mod._ck_next_husk_dead_scan_t or 0) then
            return
        end

        mod._ck_next_husk_dead_scan_t = now + HUSK_DEATH_SCAN_INTERVAL
        local remove_delay = get_configured_remove_delay()

        for unit, extension in pairs(self._husk_health_extensions) do
            if extension.is_dead and not mod._ck_processed_husk_deaths[unit] then
                mod._ck_processed_husk_deaths[unit] = true

                -- Under normal conditions the unit_died event listener below
                -- already queued this unit the instant is_dead flipped, so
                -- handle_dead_unit here just refreshes an existing entry and
                -- returns false. A true (newly queued) result means this scan
                -- caught a death the event path missed -- see
                -- DEATH_ANIMATION_INVESTIGATION.md for why both paths are kept.
                if handle_dead_unit(nil, unit, remove_delay) then
                    mod._ck_metrics.husk_scan_queued_total = (mod._ck_metrics.husk_scan_queued_total or 0) + 1
                end
            end
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- unit_died event listener
--
-- HealthSystem._update_is_dead_status_husk (hooked above) fires
-- Managers.event:trigger("unit_died", unit) the instant a husk's is_dead flag
-- flips, every frame -- our own hook only *notices* that on the next
-- HUSK_DEATH_SCAN_INTERVAL tick. Subscribing to the event directly removes
-- that extra polling latency; the husk scan above stays in place as a
-- fallback in case this listener is ever unregistered or fails to fire.
-- HealthExtension.kill also triggers this same event, so authoritative-peer
-- deaths are reported twice (once via the direct kill hook, once via this
-- listener) -- harmless, handle_dead_unit dedups on unit identity.
-- ---------------------------------------------------------------------------

mod._ck_on_unit_died = function(self, unit)
    mod:pcall(function()
        if not mod:is_enabled() or not unit then
            return
        end

        if handle_dead_unit(nil, unit, get_configured_remove_delay()) then
            mod._ck_metrics.event_queued_total = (mod._ck_metrics.event_queued_total or 0) + 1
        end
    end)
end

local function ensure_unit_died_event_registered()
    if mod._ck_unit_died_event_registered then
        return
    end

    local event_manager = Managers and Managers.event
    if not event_manager then
        return
    end

    event_manager:register(mod, "unit_died", "_ck_on_unit_died")
    mod._ck_unit_died_event_registered = true
    triage_log("registered unit_died event listener")
end

local function ensure_unit_died_event_unregistered()
    if not mod._ck_unit_died_event_registered then
        return
    end

    local event_manager = Managers and Managers.event
    if event_manager then
        event_manager:unregister(mod, "unit_died")
    end

    mod._ck_unit_died_event_registered = false
    triage_log("unregistered unit_died event listener")
end

-- ---------------------------------------------------------------------------
-- Per-frame queue processing
-- ---------------------------------------------------------------------------

local function swap_remove_queue_slot(queue, index)
    local last_index = #queue
    if index > last_index then
        return false
    end

    if index ~= last_index then
        local moved_entry = queue[last_index]
        queue[index] = moved_entry
        if moved_entry then
            moved_entry.queue_index = index
        end
    end

    queue[last_index] = nil
    return true
end

local function remove_queue_entry(queue, index, entry)
    if not swap_remove_queue_slot(queue, index) then
        return
    end

    entry.queue_index = nil
    clear_entry_indexes(entry)
end

local function should_remove_stale_entry(entry)
    if entry.time_left > 0 then
        return false
    end

    if is_unit_deleted_handle(entry.unit) then
        return true
    end

    if is_unit_marked_for_deletion(entry.unit) then
        return true
    end

    if entry.manager ~= nil then
        return not is_unit_alive(entry.unit) and not manager_has_ragdoll(entry.manager, entry.unit)
    end

    return false
end

local function is_entry_age_expired(entry)
    return (entry.age or 0) >= MAX_TRACKED_ENTRY_AGE
end

local function should_drop_entry_due_to_age(entry)
    if not is_entry_age_expired(entry) then
        return false, nil
    end

    if is_unit_marked_for_deletion(entry.unit) then
        return true, "marked_for_deletion"
    end

    if not is_unit_alive(entry.unit) then
        return true, "not_alive"
    end

    -- Manager-less entries (e.g. no_ragdoll) can be force-hidden and linger in
    -- animation-driven states; allow age failsafe once they have been hidden.
    if entry.manager == nil and entry.hidden == true then
        return true, "no_manager_hidden"
    end

    return false, nil
end

local function ensure_entry_hidden(entry)
    -- Keep forcing hidden while tracked to counter animation/death-state
    -- systems that can briefly restore visibility before cleanup.
    hide_unit(entry.unit)
    entry.hidden = true
end

local function schedule_entry_retry(entry)
    entry.time_left = RAGDOLL_REMOVE_RETRY_DELAY
end

local REMOVE_RESULT_NO_MANAGER = 1
local REMOVE_RESULT_REMOVED = 2
local REMOVE_RESULT_RETRY = 3

is_unit_marked_for_deletion = function(unit)
    local unit_spawner = Managers and Managers.state and Managers.state.unit_spawner
    if not unit_spawner or type(unit_spawner.is_marked_for_deletion) ~= "function" then
        return false
    end

    local ok, marked = pcall(unit_spawner.is_marked_for_deletion, unit_spawner, unit)
    return ok and marked == true
end

local function is_entry_engine_removed(entry, manager)
    if is_unit_marked_for_deletion(entry.unit) then
        return true
    end

    return manager ~= nil and manager._removed_ragdolls and manager._removed_ragdolls[entry.unit] == true
end

-- Gib stump units (linked to the corpse's skeleton via World.link_unit in
-- minion_gibbing.lua, registered onto the dissolve extension) are never
-- unlinked or marked for deletion by any game code -- MinionGibbing.delete_gibs
-- only clears flying gib/flesh-gib units, and MinionDissolveExtension has no
-- destroy method at all. Forcing early removal of the base unit while these
-- are still linked is what produces the engine's "has still childs attached
-- to it, please unlink them before destroying the unit" error; vanilla rarely
-- hits this because it removes corpses far later (dissolve timer/OOB/ragdoll
-- cap) and less often than CleanKills does. Clean them up ourselves first.
local function cleanup_dissolve_stump_units(unit)
    local dissolve_extension = ScriptUnit.has_extension(unit, "dissolve_system")
    if not dissolve_extension then
        return
    end

    local stump_units = dissolve_extension._stump_units
    if type(stump_units) ~= "table" then
        return
    end

    local unit_spawner = Managers and Managers.state and Managers.state.unit_spawner
    if not unit_spawner then
        return
    end

    for i = 1, #stump_units do
        local stump_unit = stump_units[i]
        if stump_unit and not is_unit_marked_for_deletion(stump_unit) then
            local ok, stump_world = pcall(Unit.world, stump_unit)
            if ok and stump_world then
                pcall(World.unlink_unit, stump_world, stump_unit)
            end
            pcall(unit_spawner.mark_for_deletion, unit_spawner, stump_unit)
        end
    end
end

local function try_remove_entry_ragdoll(entry)
    local manager = entry.manager
    if is_entry_engine_removed(entry, manager) then
        return REMOVE_RESULT_REMOVED
    end

    if manager == nil then
        return REMOVE_RESULT_NO_MANAGER
    end

    if not manager_has_ragdoll(manager, entry.unit) then
        entry.failures = (entry.failures or 0) + 1
        if entry.failures >= MAX_RETRY_FAILURES then
            -- Fall back to manager-less tracking so we keep force-hiding
            -- until engine deletion/cleanup instead of dropping the corpse.
            entry.manager = nil
            entry.fallback_no_manager = true
            return REMOVE_RESULT_NO_MANAGER
        end

        return REMOVE_RESULT_RETRY
    end

    cleanup_dissolve_stump_units(entry.unit)
    pcall(manager.remove_ragdoll_safe, manager, entry.unit)

    if is_entry_engine_removed(entry, manager) then
        return REMOVE_RESULT_REMOVED
    end

    entry.failures = (entry.failures or 0) + 1
    if entry.failures >= MAX_RETRY_FAILURES then
        entry.manager = nil
        entry.fallback_no_manager = true
        return REMOVE_RESULT_NO_MANAGER
    end

    return REMOVE_RESULT_RETRY
end

local function should_drop_entry_after_remove_attempt(remove_result)
    return remove_result == REMOVE_RESULT_REMOVED
end

local function prune_queue_entry(queue, index, entry)
    if not entry then
        swap_remove_queue_slot(queue, index)
        return true
    end

    if should_remove_stale_entry(entry) then
        -- Unit already gone and no longer tracked as a ragdoll.
        mod._ck_metrics.removed_total = (mod._ck_metrics.removed_total or 0) + 1
        remove_queue_entry(queue, index, entry)
        return true
    end

    local drop_for_age, age_reason = should_drop_entry_due_to_age(entry)
    if drop_for_age then
        mod._ck_metrics.dropped_by_age_total = (mod._ck_metrics.dropped_by_age_total or 0) + 1
        triage_log(string.format("drop stale tracked entry after max age (unit=%s age=%.2f reason=%s)", tostring(entry.unit), entry.age or 0, tostring(age_reason)))
        remove_queue_entry(queue, index, entry)
        return true
    end

    return false
end

local function process_due_queue_entry(queue, index, entry, removals_this_frame)
    if is_unit_deleted_handle(entry.unit) then
        mod._ck_metrics.removed_total = (mod._ck_metrics.removed_total or 0) + 1
        remove_queue_entry(queue, index, entry)
        return removals_this_frame
    end

    ensure_entry_hidden(entry)

    if removals_this_frame >= MAX_RAGDOLL_REMOVALS_PER_FRAME then
        -- Too many removals this frame; defer.
        mod._ck_metrics.frame_deferred_total = (mod._ck_metrics.frame_deferred_total or 0) + 1
        triage_log(string.format("defer due to frame cap (unit=%s cap=%d)", tostring(entry.unit), MAX_RAGDOLL_REMOVALS_PER_FRAME))
        schedule_entry_retry(entry)
        return removals_this_frame
    end

    removals_this_frame = removals_this_frame + 1

    -- Re-hide in case the unit became visible again (e.g. LOD swap).
    hide_unit(entry.unit)

    local remove_result = try_remove_entry_ragdoll(entry)
    if should_drop_entry_after_remove_attempt(remove_result) then
        if is_unit_marked_for_deletion(entry.unit) or not is_unit_alive(entry.unit) then
            mod._ck_metrics.removed_total = (mod._ck_metrics.removed_total or 0) + 1
            remove_queue_entry(queue, index, entry)
            return removals_this_frame
        end

        -- Keep force-hiding for a short confirmation window because some
        -- units can still render briefly after ragdoll removal is acknowledged.
        entry.manager = nil
        entry.pending_remove_confirm = true
        entry.time_left = POST_REMOVE_CONFIRM_DELAY
        triage_log(string.format("ragdoll remove acknowledged; waiting for deletion confirm (unit=%s)", tostring(entry.unit)))
        return removals_this_frame
    end

    -- No ragdoll manager path (e.g. breed.no_ragdoll). Keep the unit hidden
    -- and keep checking until the engine removes it.
    mod._ck_metrics.retry_total = (mod._ck_metrics.retry_total or 0) + 1
    schedule_entry_retry(entry)

    if remove_result == REMOVE_RESULT_NO_MANAGER then
        if entry.fallback_no_manager then
            mod._ck_metrics.abandoned_total = (mod._ck_metrics.abandoned_total or 0) + 1
            triage_log(string.format("ragdoll removal fallback to manager-less tracking (unit=%s failures=%d)", tostring(entry.unit), entry.failures or 0))
            entry.fallback_no_manager = false
        end
        return removals_this_frame - 1
    end

    return removals_this_frame
end

mod.update = function(dt)
    if type(dt) ~= "number" then
        return
    end

    if not mod:is_enabled() then
        return
    end

    -- Keep summary cadence independent from queue occupancy so triage metrics
    -- still emit while no corpses are currently tracked.
    maybe_log_metrics_summary(dt)
    maybe_sweep_active_ragdolls(dt)

    local queue = mod._ck_removal_queue
    if #queue == 0 then
        return
    end

    local removals_this_frame = 0

    for i = #queue, 1, -1 do
        local entry = queue[i]
        if not prune_queue_entry(queue, i, entry) then
            entry.age = (entry.age or 0) + dt
            entry.time_left = entry.time_left - dt

            if entry.time_left <= 0 then
                removals_this_frame = process_due_queue_entry(queue, i, entry, removals_this_frame)
            end
        end
    end
end

function mod.on_game_state_changed(status, state_name)
    if state_name ~= "StateGameplay" then
        return
    end

    if status == "exit" or status == "enter" then
        reset_mod_state()
    end

    if status == "enter" then
        log_authoritative_host_status()
    elseif status == "exit" then
        -- Re-determined fresh on next mission enter rather than carried over.
        mod._ck_is_authoritative_host = nil
    end
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

mod.on_all_mods_loaded = function()
    ensure_unit_died_event_registered()
    mod:info(string.format("[%s] loaded (v%s)", mod:get_name(), mod.version))
    triage_log("triage logging enabled")
end

mod.on_enabled = function(initial_call)
    reset_mod_state()
    -- Retry in case Managers.event wasn't up yet at on_all_mods_loaded.
    ensure_unit_died_event_registered()
    mod:info(string.format("[%s] enabled%s", mod:get_name(), initial_call and " (initial)" or ""))
end

mod.on_disabled = function(initial_call)
    reset_mod_state()
    ensure_unit_died_event_unregistered()
    mod:info(string.format("[%s] disabled%s", mod:get_name(), initial_call and " (initial)" or ""))
end

function mod:get_metrics_snapshot()
    return get_metrics_snapshot()
end

function mod:log_metrics_summary(prefix)
    return log_metrics_snapshot(prefix)
end

mod.on_unload = function()
    reset_mod_state()
    ensure_unit_died_event_unregistered()
    mod:info(string.format("[%s] unloaded", mod:get_name()))
end
