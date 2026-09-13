local mod = get_mod("mod_shrine")
local dmf = get_mod("DMF")

local _io = Mods.lua.io
local _os = Mods.lua.os

local VERSION = "0.5.5"
local AUTO_DELAY_SECONDS = 0.85
local STARTUP_SAFE_DELAY_SECONDS = 3.0
local STARTUP_STATE_DELAY_AFTER_SCAN_SECONDS = 0.75
local ARCHIVE_STEP_SECONDS = 0.10
local KNOWN_GOOD_STEP_SECONDS = 0.08
local SNAPSHOT_STEP_SECONDS = 0.06
local RESTORE_STEP_SECONDS = 0.08
mod._retention_reconcile_delay_seconds = 1.25
mod._retention_reconcile_step_seconds = 0.10
mod._hub_safe_fallback_seconds = 20.0
-- v0.5.5 diagnostics: emit an extra breadcrumb for any measured phase
-- that crosses this threshold. Kept on the mod table to avoid consuming another
-- top-level local in Darktide's 200-local Lua chunk.
mod._perf_slow_phase_ms = 50
local LIVE_BASELINE_DELAY_SECONDS = 1.50
local HASH_MODULUS = 4294967296
local MAX_DYNAMIC_ROSTER_ROWS = 20

local pending_auto_backup_at = nil
local startup_scan_at = nil
local startup_check_at = nil
local startup_check_done = false

-- Performance hotfix state.
-- Darktide/DMF Lua executes on the game thread, so expensive shell/process work
-- must never be repeated in a single update.
local ensured_dirs = {}
local cached_installed_mods = nil
local cached_installed_scan_ok = false
local archive_presence_cache = {}
local cached_previous_snapshot_path = nil
local cached_previous_snapshot_analysis = nil
local cached_previous_snapshot_manifest = nil
local archive_queue = {}
local archive_queue_keys = {}
local archive_next_at = 0
local archive_processing_allowed = true
local current_mission_name = nil
mod._hub_processing_pending = false
mod._hub_processing_fallback_at = nil
mod._hub_run_hook_available = false
mod._retention_reconcile_job = nil
mod._retention_reconcile_next_at = 0
local known_good_job = nil
local known_good_next_at = 0
local snapshot_job = nil
local snapshot_queue = {}
local snapshot_next_at = 0
local restore_job = nil
local restore_next_at = 0
local restore_result_checked = false
local cancel_pending_restore_if_state_changed = nil
local maybe_alert_missing = nil

-- DMF live-settings protection.
-- DMF keeps mod settings in memory and exposes save_unsaved_settings_to_file().
-- ModShrine fingerprints the live values of known settings so it can recognize
-- a menu change even before/while the backing file is being flushed.
local live_baseline_at = nil
local last_live_settings_hash = nil
local pending_live_settings_hash = nil
local pending_live_change_since = nil
local dmf_flush_warned = false

-- v0.5.4 guarded no-change fast path.
-- Sentinels are armed only from a state that ModShrine has fully verified
-- against the latest snapshot (or has just written and verified as latest).
-- Keep them on the mod table to preserve the chunk's existing top-level local
-- count; Darktide Lua has a hard 200-local ceiling.
mod._no_change_fastpath_live_hash = nil
mod._no_change_fastpath_disk_hash = nil
mod._no_change_fastpath_roster_hash = nil
mod._no_change_fastpath_snapshot = nil
mod._no_change_fastpath_signature = nil

-- v0.5.5 workflow UI cache. This is intentionally UI-only: backup creation,
-- restore staging, Known Good, and safety checks continue to build fresh state.
-- The cache is reusable only while raw disk config, roster, exact latest
-- snapshot identity, and the v0.5.4 verified sentinel all still match.
mod._workflow_state_cache = nil

-- v0.5.5 UI-only restore-target cache. This may accelerate the
-- guided workflow display, but actual Preview/Stage Restore operations always
-- re-read and re-analyze the backup from disk.
mod._preview_target_cache = nil

-- Restore watcher lifecycle.
local restore_watcher_launched_this_session = false
local pending_restore_recovery_at = nil
local pending_restore_recovery_attempted = false
local pending_cancel_cleanup_at = nil
local pending_restore_cancel_requested = false

-- Guided restore workflow.
-- Step 4 is only unlocked after Step 3 successfully previews the exact same
-- current configuration against the exact same Known Good source.
local restore_preview_signature = nil
local restore_preview_source_snapshot = nil
local restore_preview_source_id = nil
local restore_preview_setting_changes = 0
local restore_preview_completed_at = nil
mod._clear_restore_preview_unlock = nil

local DMF_NOISE_KEYS = {
    options_menu_last_selected = true,
    options_menu_mod_scroll_offsets = true,
    options_menu_toggle_mods_scroll_offset = true,
}

local function q(path)
    return '"' .. tostring(path):gsub('"', '""') .. '"'
end

local function trim(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function env(name)
    if not _os or not _os.getenv then
        return nil
    end
    return _os.getenv(name)
end

local function notify(text)
    if mod:get("show_notifications") ~= false then
        mod:notify(text)
    end
end

local function wall_now()
    return Application.time_since_launch()
end

local function perf_now()
    if _os and _os.clock then
        return _os.clock()
    end

    if os and os.clock then
        return os.clock()
    end

    return Application.time_since_launch()
end

local function perf_ms(started_at)
    return math.max((perf_now() - (started_at or perf_now())) * 1000, 0)
end

local function perf_log(label, started_at, extra)
    local elapsed = perf_ms(started_at)
    local suffix = extra and (" | " .. tostring(extra)) or ""

    mod:info("[ModShrine][PERF] %s=%.2fms%s", tostring(label), elapsed, suffix)

    if elapsed >= (mod._perf_slow_phase_ms or 50) then
        mod:info(
            "[ModShrine][PERF] SLOW_PHASE label=%s elapsed=%.2fms threshold=%.2fms%s",
            tostring(label),
            elapsed,
            tonumber(mod._perf_slow_phase_ms) or 50,
            suffix
        )
    end

    return elapsed
end

local function perf_track(job, label, started_at, extra)
    local elapsed = perf_log(label, started_at, extra)

    if job then
        job.work_sum_ms = (job.work_sum_ms or 0) + elapsed
        job.max_phase_ms = math.max(job.max_phase_ms or 0, elapsed)
    end

    return elapsed
end


local function stable_setting_value(value, seen)
    local value_type = type(value)

    if value_type == "nil" then
        return "nil"
    elseif value_type == "boolean" then
        return value and "true" or "false"
    elseif value_type == "number" then
        return string.format("%.17g", value)
    elseif value_type == "string" then
        return string.format("%q", value)
    elseif value_type ~= "table" then
        return "<" .. value_type .. ":" .. tostring(value) .. ">"
    end

    seen = seen or {}
    if seen[value] then
        return "<cycle>"
    end
    seen[value] = true

    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta == tb then
            return tostring(a) < tostring(b)
        end
        return ta < tb
    end)

    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] =
            "[" .. stable_setting_value(key, seen) .. "]=" ..
            stable_setting_value(value[key], seen)
    end

    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

local function force_dmf_settings_flush(reason)
    if not dmf or type(dmf.save_unsaved_settings_to_file) ~= "function" then
        if not dmf_flush_warned then
            dmf_flush_warned = true
            mod:warning(
                "[ModShrine] DMF save_unsaved_settings_to_file() is unavailable; live-flush protection disabled."
            )
        end
        return false
    end

    local started = perf_now()
    local ok, err = pcall(dmf.save_unsaved_settings_to_file)

    if not ok then
        mod:error(
            "[ModShrine] DMF live settings flush failed (%s): %s",
            tostring(reason or "unknown"),
            tostring(err)
        )
        return false
    end

    perf_log("dmf_settings_flush", started, tostring(reason or "unknown"))
    return true
end

local function hash_string(data)
    if data == nil then
        return nil
    end

    local hash = 5381
    data = tostring(data)

    for i = 1, #data do
        hash = (hash * 33 + string.byte(data, i)) % HASH_MODULUS
    end

    return string.format("%08x", hash)
end

local function file_size(path)
    if not _io or not _io.open or not path then
        return nil
    end

    local file = _io.open(path, "rb")
    if not file then
        return nil
    end

    local size = file:seek("end")
    file:close()
    return size
end

local function file_exists(path)
    return file_size(path) ~= nil
end

local function read_all(path)
    if not _io or not _io.open or not path then
        return nil
    end

    local file = _io.open(path, "rb")
    if not file then
        return nil
    end

    local data = file:read("*a")
    file:close()
    return data
end

local function write_all(path, data)
    if not _io or not _io.open or not path then
        return false
    end

    local file = _io.open(path, "wb")
    if not file then
        return false
    end

    file:write(data or "")
    file:close()
    return true
end

local function content_hash(path)
    local data = read_all(path)
    return data and hash_string(data) or nil
end

local function stamp()
    if _os and _os.date then
        return _os.date("%Y%m%d_%H%M%S")
    end

    return tostring(math.floor(Application.time_since_launch()))
end

local function vault_root()
    local localappdata = env("LOCALAPPDATA") or env("LocalAppData")
    if not localappdata then
        return nil
    end

    return localappdata .. "\\ModShrine\\Darktide"
end

local function snapshots_path()
    local root = vault_root()
    return root and (root .. "\\snapshots") or nil
end

local function known_good_path()
    local root = vault_root()
    return root and (root .. "\\known_good") or nil
end

local function persistent_archive_path()
    local root = vault_root()
    return root and (root .. "\\mod_archive") or nil
end

local function exports_path()
    local root = vault_root()
    return root and (root .. "\\exports") or nil
end

local function restore_staging_path()
    local root = vault_root()
    return root and (root .. "\\restore_staging") or nil
end

local function restore_pending_path()
    local root = vault_root()
    return root and (root .. "\\RESTORE_PENDING.txt") or nil
end

local function restore_result_path()
    local root = vault_root()
    return root and (root .. "\\RESTORE_RESULT.txt") or nil
end

local function restore_cancel_path()
    local root = vault_root()
    return root and (root .. "\\RESTORE_CANCEL.txt") or nil
end

local function restore_watcher_path()
    local root = vault_root()
    return root and (root .. "\\apply_pending_restore.cmd") or nil
end

local function restore_launcher_path()
    local root = vault_root()
    return root and (root .. "\\apply_pending_restore_hidden.vbs") or nil
end

local function pre_restore_metadata_path()
    local root = vault_root()
    return root and (root .. "\\PRE_RESTORE_LATEST.txt") or nil
end

local function latest_metadata_path()
    local root = vault_root()
    return root and (root .. "\\LATEST.txt") or nil
end

local function auto_index_path()
    local root = vault_root()
    return root and (root .. "\\AUTO_SNAPSHOTS.txt") or nil
end

local function known_good_metadata_path()
    local root = vault_root()
    return root and (root .. "\\KNOWN_GOOD.txt") or nil
end

local function retired_mods_path()
    local root = vault_root()
    return root and (root .. "\\RETIRED_MODS.txt") or nil
end

-- Kept on the mod table to avoid adding another top-level local. Forgotten
-- retired IDs are user-suppressed roster identities, not deleted settings.
function mod._forgotten_mods_path()
    local root = vault_root()
    return root and (root .. "\\FORGOTTEN_MODS.txt") or nil
end

local function seen_mods_path()
    local root = vault_root()
    return root and (root .. "\\SEEN_MODS.txt") or nil
end

local function missing_alert_path()
    local root = vault_root()
    return root and (root .. "\\LAST_MISSING_ALERT.txt") or nil
end

local function directory_exists_fast(path)
    if not path or not _os or type(_os.rename) ~= "function" then
        return false
    end

    local ok, result = pcall(_os.rename, path, path)
    return ok and result ~= nil and result ~= false
end

local function ensure_dir(path)
    if not path then
        return false
    end

    if ensured_dirs[path] then
        return true
    end

    -- os.rename(path, path) is a cheap in-process existence test for existing
    -- directories on the supported Windows runtime. This avoids spawning a
    -- command shell for every already-existing vault folder on the first backup.
    if directory_exists_fast(path) then
        ensured_dirs[path] = true
        return true
    end

    if not _os or not _os.execute then
        return false
    end

    _os.execute('if not exist ' .. q(path) .. ' mkdir ' .. q(path) .. ' > nul 2>&1')
    ensured_dirs[path] = true
    return true
end

local function source_path()
    local appdata = env("APPDATA") or env("AppData")
    if not appdata then
        return nil
    end

    local candidates = {
        appdata .. "\\Fatshark\\Darktide\\user_settings.config",
        appdata .. "\\Fatshark\\MicrosoftStore\\Darktide\\user_settings.config",
    }

    for _, candidate in ipairs(candidates) do
        if file_exists(candidate) then
            return candidate
        end
    end

    return nil
end

local function find_load_order_path()
    local candidates = {
        "..\\mods\\mod_load_order.txt",
        ".\\..\\mods\\mod_load_order.txt",
    }

    for _, candidate in ipairs(candidates) do
        if file_exists(candidate) then
            return candidate, candidate:gsub("\\mod_load_order%.txt$", "")
        end
    end

    return nil, nil
end

local function sanitize_file_component(name)
    local clean = tostring(name or "unknown")
    clean = clean:gsub('[<>:"/\\|%?%*]', "_")
    clean = clean:gsub("[%c]", "_")
    clean = clean:gsub("%s+", "_")
    clean = clean:gsub("_+", "_")
    clean = clean:gsub("^_+", ""):gsub("_+$", "")

    if clean == "" then
        clean = "unnamed"
    end

    if #clean > 72 then
        clean = clean:sub(1, 72)
    end

    return clean
end

local function sorted_names_from_map(map)
    local names = {}

    for _, value in pairs(map or {}) do
        names[#names + 1] = value
    end

    table.sort(names, function(a, b)
        return lower(a) < lower(b)
    end)

    return names
end

local function map_count(map)
    local count = 0
    for _ in pairs(map or {}) do
        count = count + 1
    end
    return count
end

local function names_to_map(names)
    local map = {}

    for _, name in ipairs(names or {}) do
        name = trim(name)
        if name ~= "" then
            map[lower(name)] = name
        end
    end

    return map
end

local function map_union_into(target, source)
    for key, name in pairs(source or {}) do
        if not target[key] then
            target[key] = name
        end
    end
end

local function map_difference(left, right)
    local result = {}

    for key, name in pairs(left or {}) do
        if not right or not right[key] then
            result[key] = name
        end
    end

    return result
end

local function map_intersection(left, right)
    local result = {}

    for key, name in pairs(left or {}) do
        if right and right[key] then
            result[key] = name
        end
    end

    return result
end

local function map_excluding(source, exclusions)
    local result = {}

    for key, name in pairs(source or {}) do
        if not exclusions or not exclusions[key] then
            result[key] = name
        end
    end

    return result
end

local function read_name_map(path)
    local data = read_all(path)
    if not data then
        return {}
    end

    local names = {}

    for line in string.gmatch(data, "[^\r\n]+") do
        line = trim(line)
        if line ~= "" and not line:match("^#") then
            names[#names + 1] = line
        end
    end

    return names_to_map(names)
end

local function write_name_map(path, map)
    local names = sorted_names_from_map(map)
    return write_all(path, table.concat(names, "\n") .. (#names > 0 and "\n" or ""))
end

local function read_enabled_mods()
    local load_order_path = find_load_order_path()
    if not load_order_path then
        return {}, false
    end

    local data = read_all(load_order_path)
    if not data then
        return {}, false
    end

    local names = {}

    for line in string.gmatch(data, "[^\r\n]+") do
        line = trim(line)

        if line ~= ""
            and not line:match("^%-%-")
            and not line:match("^#")
        then
            names[#names + 1] = line
        end
    end

    return names_to_map(names), true
end

local function request_installed_mod_scan()
    if cached_installed_mods ~= nil then
        return true
    end

    local started = perf_now()
    local installed = {}
    local registry = dmf and dmf.mods

    if type(registry) == "table" then
        for mod_name, _mod_object in pairs(registry) do
            if type(mod_name) == "string" and trim(mod_name) ~= "" then
                installed[lower(mod_name)] = mod_name
            end
        end
    end

    -- Defensive union: anything explicitly enabled in mod_load_order.txt
    -- counts even if a third-party loader exposes an unusual registry entry.
    local enabled, enabled_ok = read_enabled_mods()
    map_union_into(installed, enabled)

    cached_installed_mods = installed
    cached_installed_scan_ok = type(registry) == "table" or enabled_ok

    perf_log(
        "installed_registry_snapshot",
        started,
        string.format("mods=%d", map_count(cached_installed_mods))
    )

    mod:info(
        "[ModShrine] Installed roster cached from DMF registry/load order: %d mod(s). No Windows directory scan used.",
        map_count(cached_installed_mods)
    )

    return true
end

local function poll_installed_mod_scan(_now)
    -- Compatibility no-op. Registry collection completes immediately in memory.
    return false
end

local function scan_installed_mods()
    if cached_installed_mods == nil then
        request_installed_mod_scan()
    end

    return cached_installed_mods or {}, cached_installed_scan_ok
end

local function parse_key(text, i)
    local n = #text
    local start_i = i
    local in_string = false
    local escaped = false

    while i <= n do
        local c = text:sub(i, i)

        if in_string then
            if escaped then
                escaped = false
            elseif c == "\\" then
                escaped = true
            elseif c == '"' then
                in_string = false
            end
        else
            if c == '"' then
                in_string = true
            elseif c == "=" then
                local raw = trim(text:sub(start_i, i - 1))
                if raw:sub(1, 1) == '"' and raw:sub(-1) == '"' then
                    raw = raw:sub(2, -2)
                end
                return raw, i + 1
            end
        end

        i = i + 1
    end

    return nil, n + 1
end

local function parse_value_end(text, i)
    local n = #text

    while i <= n and text:sub(i, i):match("%s") do
        i = i + 1
    end

    if i > n then
        return n
    end

    local first = text:sub(i, i)

    if first == "{" or first == "[" then
        local brace_depth = 0
        local bracket_depth = 0
        local in_string = false
        local escaped = false
        local j = i

        while j <= n do
            local c = text:sub(j, j)

            if in_string then
                if escaped then
                    escaped = false
                elseif c == "\\" then
                    escaped = true
                elseif c == '"' then
                    in_string = false
                end
            else
                if c == '"' then
                    in_string = true
                elseif c == "{" then
                    brace_depth = brace_depth + 1
                elseif c == "}" then
                    brace_depth = brace_depth - 1
                elseif c == "[" then
                    bracket_depth = bracket_depth + 1
                elseif c == "]" then
                    bracket_depth = bracket_depth - 1
                end

                if brace_depth == 0 and bracket_depth == 0 then
                    return j
                end
            end

            j = j + 1
        end

        return n
    end

    local in_string = false
    local escaped = false
    local j = i

    while j <= n do
        local c = text:sub(j, j)

        if in_string then
            if escaped then
                escaped = false
            elseif c == "\\" then
                escaped = true
            elseif c == '"' then
                in_string = false
            end
        else
            if c == '"' then
                in_string = true
            elseif c == "\n" or c == "\r" then
                return j - 1
            end
        end

        j = j + 1
    end

    return n
end

local function parse_direct_entries(block)
    local entries = {}
    local order = {}

    if not block or block:sub(1, 1) ~= "{" then
        return entries, order
    end

    local i = 2
    local n = #block

    while i <= n do
        while i <= n and block:sub(i, i):match("%s") do
            i = i + 1
        end

        if i > n or block:sub(i, i) == "}" then
            break
        end

        local entry_start = i
        local key, value_start = parse_key(block, i)

        if not key or key == "" then
            break
        end

        local value_end = parse_value_end(block, value_start)
        local raw = trim(block:sub(entry_start, value_end))

        entries[key] = raw
        order[#order + 1] = key

        i = value_end + 1
    end

    return entries, order
end

local function extract_mod_blocks(text)
    local blocks = {}

    if not text then
        return blocks
    end

    local marker_start = string.find(text, "mods_settings%s*=%s*{")
    if not marker_start then
        return blocks
    end

    local open_brace = string.find(text, "{", marker_start, true)
    if not open_brace then
        return blocks
    end

    local i = open_brace + 1
    local n = #text

    while i <= n do
        while i <= n and text:sub(i, i):match("%s") do
            i = i + 1
        end

        if i > n or text:sub(i, i) == "}" then
            break
        end

        local key, value_start = parse_key(text, i)
        if not key then
            break
        end

        while value_start <= n and text:sub(value_start, value_start):match("%s") do
            value_start = value_start + 1
        end

        if text:sub(value_start, value_start) ~= "{" then
            i = value_start + 1
        else
            local value_end = parse_value_end(text, value_start)
            blocks[lower(key)] = {
                name = key,
                raw = text:sub(value_start, value_end),
            }
            i = value_end + 1
        end
    end

    return blocks
end

local function normalized_mod_info(mod_name, raw_block)
    local entries = parse_direct_entries(raw_block)
    local keys = {}

    for key in pairs(entries) do
        if not (lower(mod_name) == "dmf" and DMF_NOISE_KEYS[key]) then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys, function(a, b)
        return lower(a) < lower(b)
    end)

    local parts = {}
    local setting_hashes = {}

    for _, key in ipairs(keys) do
        local value_hash = hash_string(entries[key])
        setting_hashes[key] = value_hash
        parts[#parts + 1] = key .. "=" .. tostring(value_hash)
    end

    return {
        hash = hash_string(table.concat(parts, "\n")),
        setting_count = #keys,
        setting_hashes = setting_hashes,
    }
end

local function analyze_config_text(text)
    local blocks = extract_mod_blocks(text)
    local mod_parts = {}
    local mod_count = 0
    local setting_count = 0

    for key, block in pairs(blocks) do
        local normalized = normalized_mod_info(block.name, block.raw)
        block.hash = normalized.hash
        block.setting_count = normalized.setting_count
        block.setting_hashes = normalized.setting_hashes

        mod_parts[#mod_parts + 1] = key .. "=" .. tostring(block.hash)
        mod_count = mod_count + 1
        setting_count = setting_count + normalized.setting_count
    end

    table.sort(mod_parts)

    return {
        blocks = blocks,
        hash = hash_string(table.concat(mod_parts, "\n")),
        mod_count = mod_count,
        setting_count = setting_count,
    }
end


local function live_dmf_settings_hash(analysis)
    if not dmf or type(dmf._get_setting_value) ~= "function" or not analysis then
        return nil, 0
    end

    local parts = {}
    local count = 0

    for mod_key, block in pairs(analysis.blocks or {}) do
        local setting_ids = {}

        for setting_id in pairs(block.setting_hashes or {}) do
            if not (mod_key == "dmf" and DMF_NOISE_KEYS[setting_id]) then
                setting_ids[#setting_ids + 1] = setting_id
            end
        end

        table.sort(setting_ids, function(a, b)
            return lower(a) < lower(b)
        end)

        for _, setting_id in ipairs(setting_ids) do
            local ok, value = pcall(dmf._get_setting_value, block.name, setting_id)

            if ok then
                parts[#parts + 1] =
                    mod_key .. "." .. setting_id .. "=" ..
                    stable_setting_value(value)
                count = count + 1
            end
        end
    end

    table.sort(parts)
    return hash_string(table.concat(parts, "\n")), count
end

local function probe_live_dmf_settings(reason)
    local started = perf_now()
    local source = source_path()
    local text = source and read_all(source) or nil

    if not text then
        return nil, false
    end

    local analysis = analyze_config_text(text)
    local live_hash, count = live_dmf_settings_hash(analysis)

    if not live_hash then
        return nil, false
    end

    local changed =
        last_live_settings_hash ~= nil
        and tostring(live_hash) ~= tostring(last_live_settings_hash)

    perf_log(
        "live_settings_probe",
        started,
        string.format(
            "reason=%s known=%d changed=%s",
            tostring(reason or "unknown"),
            count,
            tostring(changed)
        )
    )

    if changed then
        pending_live_settings_hash = live_hash
        pending_live_change_since = wall_now()
        mod._clear_no_change_fastpath("live_settings_changed")

        if mod._clear_restore_preview_unlock then
            mod._clear_restore_preview_unlock("live_settings_changed")
        end

        mod:info(
            "[ModShrine] LIVE DMF SETTINGS CHANGE detected before backup check. hash=%s baseline=%s",
            tostring(live_hash),
            tostring(last_live_settings_hash)
        )
    end

    return live_hash, changed, analysis.hash
end

local function refresh_live_settings_baseline(reason)
    local started = perf_now()
    local source = source_path()
    local text = source and read_all(source) or nil

    if not text then
        return false
    end

    local analysis = analyze_config_text(text)
    local live_hash, count = live_dmf_settings_hash(analysis)

    if not live_hash then
        return false
    end

    last_live_settings_hash = live_hash
    pending_live_settings_hash = nil
    pending_live_change_since = nil

    perf_log(
        "live_baseline_refresh",
        started,
        string.format(
            "reason=%s known=%d hash=%s",
            tostring(reason or "unknown"),
            count,
            tostring(live_hash)
        )
    )
    return true
end

local function configured_map_from_analysis(analysis)
    local map = {}

    for key, block in pairs((analysis and analysis.blocks) or {}) do
        map[key] = block.name
    end

    return map
end


local function extract_mods_settings_range(text)
    if not text then
        return nil
    end

    local marker_start = string.find(text, "mods_settings%s*=%s*{")
    if not marker_start then
        return nil
    end

    local open_brace = string.find(text, "{", marker_start, true)
    if not open_brace then
        return nil
    end

    local close_brace = parse_value_end(text, open_brace)
    if not close_brace or close_brace < open_brace then
        return nil
    end

    return {
        marker_start = marker_start,
        open_brace = open_brace,
        close_brace = close_brace,
        raw = text:sub(open_brace, close_brace),
    }
end

local function config_key(name)
    name = tostring(name or "")

    if name:match("^[A-Za-z_][A-Za-z0-9_]*$") then
        return name
    end

    name = name:gsub("\\", "\\\\"):gsub('"', '\\"')
    return '"' .. name .. '"'
end

local function merge_mod_settings_block(current_raw, target_raw, mod_name)
    local current_entries, current_order = parse_direct_entries(current_raw or "{}")
    local target_entries, target_order = parse_direct_entries(target_raw or "{}")
    local merged_entries = {}
    local seen = {}
    local is_dmf = lower(mod_name) == "dmf"

    for _, key in ipairs(current_order) do
        local raw = current_entries[key]

        if not (is_dmf and DMF_NOISE_KEYS[key]) and target_entries[key] then
            raw = target_entries[key]
        end

        merged_entries[#merged_entries + 1] = raw
        seen[key] = true
    end

    for _, key in ipairs(target_order) do
        if not seen[key] and not (is_dmf and DMF_NOISE_KEYS[key]) then
            merged_entries[#merged_entries + 1] = target_entries[key]
            seen[key] = true
        end
    end

    if #merged_entries == 0 then
        return "{}"
    end

    return "{\n\t\t" .. table.concat(merged_entries, "\n\t\t") .. "\n\t}"
end

local function count_safe_restore_setting_changes(current_analysis, target_analysis, matching)
    local changed = 0
    local preserved_current_only = 0

    for key, name in pairs(matching or {}) do
        local current_block = current_analysis and current_analysis.blocks[key] or nil
        local target_block = target_analysis and target_analysis.blocks[key] or nil

        if target_block then
            local current_entries = parse_direct_entries(current_block and current_block.raw or "{}")
            local target_entries = parse_direct_entries(target_block.raw)
            local is_dmf = lower(name) == "dmf"

            for setting_key, target_raw in pairs(target_entries) do
                if not (is_dmf and DMF_NOISE_KEYS[setting_key]) then
                    local current_raw = current_entries[setting_key]
                    if not current_raw or hash_string(current_raw) ~= hash_string(target_raw) then
                        changed = changed + 1
                    end
                end
            end

            for setting_key in pairs(current_entries) do
                if not target_entries[setting_key] or (is_dmf and DMF_NOISE_KEYS[setting_key]) then
                    preserved_current_only = preserved_current_only + 1
                end
            end
        end
    end

    return changed, preserved_current_only
end

local function build_safe_restore_maps(current, target)
    local target_configured = configured_map_from_analysis(target.analysis)
    local current_installed = current.roster.installed
    local retired = current.retired
    local forgotten = current.forgotten or {}

    -- Restore only mods that are BOTH currently installed and represented in
    -- the restore source. Explicitly retired mods are excluded.
    local matching = map_intersection(current_installed, target_configured)
    matching = map_excluding(matching, retired)

    -- Current/new mods that did not exist in the target stay untouched.
    local new_current = map_difference(current_installed, target.installed)

    -- Mods represented in the target but not currently installed remain archived.
    local missing_target = map_difference(target.installed, current_installed)
    missing_target = map_excluding(missing_target, forgotten)

    -- Retired mods remain excluded even if they exist in the target. Forgotten
    -- retired IDs are intentionally absent from the restore workflow entirely.
    local retired_target = map_intersection(target.installed, retired)
    retired_target = map_excluding(retired_target, forgotten)

    local setting_changes, current_only_preserved =
        count_safe_restore_setting_changes(current.analysis, target.analysis, matching)

    return {
        matching = matching,
        new_current = new_current,
        missing_target = missing_target,
        retired_target = retired_target,
        setting_changes = setting_changes,
        current_only_preserved = current_only_preserved,
    }
end


local function validate_safe_restore_plan(current, target, plan)
    local errors = {}

    if type(plan) ~= "table" then
        return false, { "restore plan is not a table" }
    end

    for _, field in ipairs({
        "matching",
        "new_current",
        "missing_target",
        "retired_target",
    }) do
        if type(plan[field]) ~= "table" then
            errors[#errors + 1] = "plan." .. field .. " is not a table"
        end
    end

    if type(plan.setting_changes) ~= "number" or plan.setting_changes < 0 then
        errors[#errors + 1] = "plan.setting_changes is invalid"
    end

    if type(plan.current_only_preserved) ~= "number" or plan.current_only_preserved < 0 then
        errors[#errors + 1] = "plan.current_only_preserved is invalid"
    end

    if current and current.roster and current.roster.installed and plan.matching then
        for key, name in pairs(plan.matching) do
            if not current.roster.installed[key] then
                errors[#errors + 1] =
                    "restore set contains non-installed mod: " .. tostring(name)
            end

            if current.retired and current.retired[key] then
                errors[#errors + 1] =
                    "restore set contains retired mod: " .. tostring(name)
            end

            if not target
                or not target.analysis
                or not target.analysis.blocks
                or not target.analysis.blocks[key]
            then
                errors[#errors + 1] =
                    "restore set has no target settings block: " .. tostring(name)
            end
        end
    end

    return #errors == 0, errors
end

local function build_safe_restore_text(current, target, plan)
    local range = extract_mods_settings_range(current.text)
    if not range then
        return nil, "current_mods_settings_missing"
    end

    local current_entries, current_order = parse_direct_entries(range.raw)
    local target_blocks = target.analysis.blocks or {}
    local output_entries = {}
    local handled = {}

    for _, current_name in ipairs(current_order) do
        local key = lower(current_name)
        local current_entry = current_entries[current_name]

        if plan.matching[key] and target_blocks[key] then
            local current_block = current.analysis.blocks[key]
            local merged_block = merge_mod_settings_block(
                current_block and current_block.raw or "{}",
                target_blocks[key].raw,
                current_name
            )

            local prefix = current_entry and current_entry:match("^(.-=)%s*")
            prefix = prefix or (config_key(current_name) .. " =")
            output_entries[#output_entries + 1] = "\t" .. prefix .. " " .. merged_block
            handled[key] = true
        else
            output_entries[#output_entries + 1] = "\t" .. tostring(current_entry)
        end
    end

    -- If a currently-installed matching mod lost its whole settings block,
    -- re-add only that installed matching mod from the restore source.
    for key, name in pairs(plan.matching) do
        if not handled[key] and target_blocks[key] then
            local merged_block = merge_mod_settings_block("{}", target_blocks[key].raw, name)
            output_entries[#output_entries + 1] =
                "\t" .. config_key(name) .. " = " .. merged_block
            handled[key] = true
        end
    end

    local replacement = "{\n" .. table.concat(output_entries, "\n") .. "\n}"
    local merged =
        current.text:sub(1, range.open_brace - 1) ..
        replacement ..
        current.text:sub(range.close_brace + 1)

    return merged
end

local function verify_safe_restore_text(current, target, plan, merged_text)
    local merged_analysis = analyze_config_text(merged_text)
    local errors = {}

    for key, name in pairs(plan.matching or {}) do
        local target_block = target.analysis.blocks[key]
        local merged_block = merged_analysis.blocks[key]
        local current_block = current.analysis.blocks[key]

        if not target_block or not merged_block then
            errors[#errors + 1] = "missing restored block: " .. tostring(name)
        else
            local target_entries = parse_direct_entries(target_block.raw)
            local merged_entries = parse_direct_entries(merged_block.raw)
            local current_entries = parse_direct_entries(current_block and current_block.raw or "{}")
            local is_dmf = lower(name) == "dmf"

            for setting_key, target_raw in pairs(target_entries) do
                if not (is_dmf and DMF_NOISE_KEYS[setting_key]) then
                    local merged_raw = merged_entries[setting_key]
                    if not merged_raw or hash_string(merged_raw) ~= hash_string(target_raw) then
                        errors[#errors + 1] =
                            tostring(name) .. "." .. tostring(setting_key) .. " != target"
                    end
                end
            end

            -- Current/newer settings absent from the old backup must survive.
            for setting_key, current_raw in pairs(current_entries) do
                if not target_entries[setting_key] or (is_dmf and DMF_NOISE_KEYS[setting_key]) then
                    local merged_raw = merged_entries[setting_key]
                    if not merged_raw or hash_string(merged_raw) ~= hash_string(current_raw) then
                        errors[#errors + 1] =
                            tostring(name) .. "." .. tostring(setting_key) .. " current-only setting lost"
                    end
                end
            end
        end
    end

    -- Mods outside the safe restore set must remain semantically unchanged.
    for key, current_block in pairs(current.analysis.blocks or {}) do
        if not plan.matching[key] then
            local merged_block = merged_analysis.blocks[key]
            if not merged_block or merged_block.hash ~= current_block.hash then
                errors[#errors + 1] =
                    "untouched mod changed or disappeared: " .. tostring(current_block.name)
            end
        end
    end

    if #errors > 0 then
        return false, errors, merged_analysis
    end

    return true, {}, merged_analysis
end

local function compare_config_analyses(previous, current)
    local changed_mods = {}
    local changed_settings = 0
    local all_keys = {}

    for key in pairs((previous and previous.blocks) or {}) do
        all_keys[key] = true
    end

    for key in pairs((current and current.blocks) or {}) do
        all_keys[key] = true
    end

    for key in pairs(all_keys) do
        local old = previous and previous.blocks[key] or nil
        local new = current and current.blocks[key] or nil

        if not old or not new or old.hash ~= new.hash then
            local display = (new and new.name) or (old and old.name) or key
            changed_mods[lower(display)] = display

            local setting_keys = {}

            for setting_key in pairs((old and old.setting_hashes) or {}) do
                setting_keys[setting_key] = true
            end

            for setting_key in pairs((new and new.setting_hashes) or {}) do
                setting_keys[setting_key] = true
            end

            for setting_key in pairs(setting_keys) do
                local old_hash = old and old.setting_hashes[setting_key] or nil
                local new_hash = new and new.setting_hashes[setting_key] or nil

                if old_hash ~= new_hash then
                    changed_settings = changed_settings + 1
                end
            end
        end
    end

    return changed_mods, changed_settings
end

local function read_metadata(path)
    local data = read_all(path)
    if not data then
        return nil
    end

    local result = {}

    for line in string.gmatch(data, "[^\r\n]+") do
        local key, value = string.match(line, "^([^:]+):%s*(.*)$")
        if key and value then
            result[key] = value
        end
    end

    return result
end

local function write_simple_record(path, ordered_fields)
    local lines = {}

    for _, pair in ipairs(ordered_fields or {}) do
        lines[#lines + 1] = tostring(pair[1]) .. ": " .. tostring(pair[2] or "")
    end

    return write_all(path, table.concat(lines, "\n") .. "\n")
end

local function remove_file(path)
    if path and _os and _os.remove and file_exists(path) then
        _os.remove(path)
    end
end

local function write_metadata(path, fields)
    local keys = {
        "Version",
        "Timestamp",
        "Kind",
        "Reason",
        "Source",
        "Snapshot",
        "Bytes",
        "RawHash",
        "SettingsHash",
        "RosterHash",
        "Signature",
        "SettingsCount",
        "ConfiguredMods",
        "InstalledMods",
        "EnabledMods",
        "Manifest",
    }

    local lines = {}

    for _, key in ipairs(keys) do
        if fields[key] ~= nil then
            lines[#lines + 1] = key .. ": " .. tostring(fields[key])
        end
    end

    return write_all(path, table.concat(lines, "\n") .. "\n")
end

local function latest_info()
    local meta = read_metadata(latest_metadata_path())

    if not meta or not meta.Snapshot or not file_exists(meta.Snapshot) then
        return nil
    end

    return meta
end

local function known_good_info()
    local meta = read_metadata(known_good_metadata_path())

    if not meta or not meta.Snapshot or not file_exists(meta.Snapshot) then
        return nil
    end

    return meta
end

local function snapshot_assets_path(snapshot)
    -- Legacy v0.3.0-v0.3.2 manifest directory.
    return snapshot and snapshot:gsub("%.config$", "") .. "_assets" or nil
end

local function snapshot_manifest_tsv_path(snapshot)
    return snapshot and snapshot:gsub("%.config$", ".manifest.tsv") or nil
end

local function snapshot_manifest_txt_path(snapshot)
    return snapshot and snapshot:gsub("%.config$", ".manifest.txt") or nil
end

local function archive_identity(name)
    return sanitize_file_component(name) .. "_" .. tostring(hash_string(lower(name)))
end

local function legacy_persistent_mod_archive_dir(name)
    local root = persistent_archive_path()
    return root and (root .. "\\" .. archive_identity(name)) or nil
end

local function persistent_mod_archive_file(name)
    local root = persistent_archive_path()
    return root and (root .. "\\" .. archive_identity(name) .. ".configpart") or nil
end

local function persistent_mod_archive_info_file(name)
    local root = persistent_archive_path()
    return root and (root .. "\\" .. archive_identity(name) .. ".info.txt") or nil
end

local function archive_exists_for_mod(name)
    local key = lower(name)
    local cached = archive_presence_cache[key]

    if cached ~= nil then
        return cached
    end

    local flat = persistent_mod_archive_file(name)
    if flat and file_exists(flat) then
        archive_presence_cache[key] = true
        return true
    end

    -- Backward compatibility with the folder-per-mod layout created by v0.3.0.
    local legacy = legacy_persistent_mod_archive_dir(name)
    local exists = legacy and file_exists(legacy .. "\\settings.configpart") or false
    archive_presence_cache[key] = exists
    return exists
end

local function update_persistent_mod_archive(name, block, timestamp)
    local root = persistent_archive_path()
    local settings_file = persistent_mod_archive_file(name)
    local info_file = persistent_mod_archive_info_file(name)

    if not root or not settings_file or not info_file or not block then
        return false
    end

    -- One root directory for the whole archive. No per-mod mkdir / cmd.exe spawn.
    ensure_dir(root)

    if not write_all(settings_file, block.raw) then
        return false
    end

    local info = {
        "Mod: " .. tostring(name),
        "LastSeen: " .. tostring(timestamp),
        "Hash: " .. tostring(block.hash),
        "Settings: " .. tostring(block.setting_count),
        "Archive: " .. settings_file,
    }

    write_all(info_file, table.concat(info, "\n") .. "\n")
    archive_presence_cache[lower(name)] = true
    return true
end

local function queue_archive_update(name, block, timestamp)
    if not name or not block then
        return
    end

    local key = lower(name)

    -- Keep only the newest pending copy for a mod.
    if archive_queue_keys[key] then
        archive_queue_keys[key].block = block
        archive_queue_keys[key].timestamp = timestamp
        return
    end

    local item = {
        name = name,
        block = block,
        timestamp = timestamp,
        key = key,
    }

    archive_queue[#archive_queue + 1] = item
    archive_queue_keys[key] = item
end

local function queue_persistent_archive_updates(state, timestamp)
    local queued = 0
    local expected_presence = {}

    for key, block in pairs(state.analysis.blocks or {}) do
        -- A forgotten retired ID is no longer part of active ModShrine roster
        -- maintenance. Its existing archive is preserved, but we stop refreshing it.
        if not (state.forgotten and state.forgotten[key]) then
            local name = block.name
            local prior_present =
                state.previous_manifest
                and state.previous_manifest.archive_present
                and state.previous_manifest.archive_present[key]

            -- Prefer the immutable latest-manifest hint. Only fall back to an actual
            -- filesystem probe when no hint exists (legacy snapshot / first run).
            local has_archive
            if prior_present ~= nil then
                has_archive = prior_present == true or archive_presence_cache[key] == true
                if has_archive then
                    archive_presence_cache[key] = true
                end
            else
                has_archive = archive_exists_for_mod(name)
            end

            local needs_seed = not has_archive
            local changed = state.changed_mods and state.changed_mods[key] ~= nil
            local is_new = state.new_mods and state.new_mods[key] ~= nil
            local returned = state.returned_mods and state.returned_mods[key] ~= nil

            if needs_seed or is_new or (changed and not returned) then
                queue_archive_update(name, block, timestamp)
                queued = queued + 1

                -- The archive write is already queued and normally executes
                -- cooperatively immediately after this manifest phase.
                expected_presence[key] = true
            else
                expected_presence[key] = has_archive
            end
        end
    end

    if queued > 0 then
        mod:info(
            "[ModShrine] Queued %d per-mod archive update(s); processing cooperatively when hub/menu-safe.",
            queued
        )
    end

    return expected_presence
end

local function process_one_archive_item(now)
    if not archive_processing_allowed or #archive_queue == 0 or now < archive_next_at then
        return
    end

    local item = table.remove(archive_queue, 1)
    archive_queue_keys[item.key] = nil

    local started = perf_now()
    local ok = update_persistent_mod_archive(item.name, item.block, item.timestamp)
    perf_log("archive_write", started, string.format("mod=%s remaining=%d", item.name, #archive_queue))

    if ok then
        mod:info(
            "[ModShrine] Background archive updated: %s (%d remaining)",
            item.name,
            #archive_queue
        )
    else
        mod:warning("[ModShrine] Background archive update failed: %s", item.name)
    end

    archive_next_at = now + ARCHIVE_STEP_SECONDS
end

local function read_snapshot_manifest(path)
    local data = read_all(path)
    if not data then
        return nil
    end

    local manifest = {
        enabled = {},
        installed = {},
        configured = {},
        retired = {},
        mod_hashes = {},
        settings_counts = {},
        archive_present = {},
        archive_files = {},
    }

    for line in string.gmatch(data, "[^\r\n]+") do
        local fields = {}
        for field in string.gmatch(line .. "\t", "(.-)\t") do
            fields[#fields + 1] = field
        end

        if fields[1] == "META" and fields[2] then
            manifest[fields[2]] = fields[3]
        elseif fields[1] == "MOD" and fields[2] then
            local name = fields[2]
            local key = lower(name)

            if fields[3] == "1" then
                manifest.enabled[key] = name
            end
            if fields[4] == "1" then
                manifest.installed[key] = name
            end
            if fields[5] == "1" then
                manifest.configured[key] = name
            end
            if fields[6] == "1" then
                manifest.retired[key] = name
            end

            manifest.mod_hashes[key] = fields[7]
            manifest.settings_counts[key] = tonumber(fields[8]) or 0

            local archive_file = fields[9] or ""
            manifest.archive_files[key] = archive_file
            manifest.archive_present[key] = archive_file ~= ""
        end
    end

    return manifest
end

local function manifest_for_snapshot(snapshot)
    if not snapshot then
        return nil
    end

    local flat = snapshot_manifest_tsv_path(snapshot)
    if flat and file_exists(flat) then
        return read_snapshot_manifest(flat)
    end

    local assets = snapshot_assets_path(snapshot)
    return assets and read_snapshot_manifest(assets .. "\\manifest.tsv") or nil
end

local function cached_previous_snapshot_data(snapshot)
    if not snapshot then
        return nil, nil
    end

    if cached_previous_snapshot_path == snapshot then
        return cached_previous_snapshot_analysis, cached_previous_snapshot_manifest
    end

    local previous_text = read_all(snapshot)
    local previous_analysis = previous_text and analyze_config_text(previous_text) or nil
    local previous_manifest = manifest_for_snapshot(snapshot)

    cached_previous_snapshot_path = snapshot
    cached_previous_snapshot_analysis = previous_analysis
    cached_previous_snapshot_manifest = previous_manifest

    return previous_analysis, previous_manifest
end

local function cache_completed_snapshot(snapshot, analysis, manifest_path)
    cached_previous_snapshot_path = snapshot
    cached_previous_snapshot_analysis = analysis
    cached_previous_snapshot_manifest =
        manifest_path and read_snapshot_manifest(manifest_path) or nil
end

local function build_roster()
    local enabled, enabled_ok = read_enabled_mods()
    local installed, installed_ok = scan_installed_mods()

    if not installed_ok then
        -- Do not pretend an installation wipe happened if directory scanning failed.
        installed = {}
        map_union_into(installed, enabled)
    end

    return {
        enabled = enabled,
        installed = installed,
        enabled_scan_ok = enabled_ok,
        installed_scan_ok = installed_ok,
        scan_pending = cached_installed_mods == nil,
    }
end

local function seed_seen_map(current_roster, current_analysis)
    local seen = read_name_map(seen_mods_path())

    if map_count(seen) > 0 then
        return seen
    end

    map_union_into(seen, current_roster.installed)
    map_union_into(seen, current_roster.enabled)
    map_union_into(seen, configured_map_from_analysis(current_analysis))

    local latest = latest_info()
    if latest and latest.Snapshot then
        local old_text = read_all(latest.Snapshot)
        local old_analysis = old_text and analyze_config_text(old_text) or nil
        map_union_into(seen, configured_map_from_analysis(old_analysis))
    end

    local known = known_good_info()
    if known and known.Snapshot then
        local known_text = read_all(known.Snapshot)
        local known_analysis = known_text and analyze_config_text(known_text) or nil
        map_union_into(seen, configured_map_from_analysis(known_analysis))
    end

    write_name_map(seen_mods_path(), seen)
    return seen
end

local function roster_hash(roster, retired)
    local parts = {}

    for _, name in ipairs(sorted_names_from_map(roster.installed)) do
        parts[#parts + 1] = "I:" .. lower(name)
    end

    for _, name in ipairs(sorted_names_from_map(roster.enabled)) do
        parts[#parts + 1] = "E:" .. lower(name)
    end

    for _, name in ipairs(sorted_names_from_map(retired)) do
        parts[#parts + 1] = "R:" .. lower(name)
    end

    return hash_string(table.concat(parts, "\n"))
end

function mod._clear_no_change_fastpath(reason)
    mod._no_change_fastpath_live_hash = nil
    mod._no_change_fastpath_disk_hash = nil
    mod._no_change_fastpath_roster_hash = nil
    mod._no_change_fastpath_snapshot = nil
    mod._no_change_fastpath_signature = nil

    if reason then
        mod:info(
            "[ModShrine][PERF] NO_CHANGE_FASTPATH disarmed reason=%s",
            tostring(reason)
        )
    end

    if mod._clear_workflow_state_cache and mod._workflow_state_cache then
        mod._clear_workflow_state_cache("fastpath_disarmed_" .. tostring(reason or "unknown"))
    end
end

function mod._arm_no_change_fastpath(state, reason)
    local latest = latest_info()

    if not state
        or not state.analysis
        or not state.analysis.hash
        or not state.roster_hash
        or not state.signature
        or not last_live_settings_hash
        or pending_live_settings_hash
        or not latest
        or not latest.Snapshot
        or not latest.Signature
        or not latest.RosterHash
        or tostring(latest.Signature) ~= tostring(state.signature)
        or tostring(latest.RosterHash) ~= tostring(state.roster_hash)
    then
        mod._clear_no_change_fastpath("untrusted_verified_state")
        return false
    end

    mod._no_change_fastpath_live_hash = last_live_settings_hash
    mod._no_change_fastpath_disk_hash = state.analysis.hash
    mod._no_change_fastpath_roster_hash = state.roster_hash
    mod._no_change_fastpath_snapshot = latest.Snapshot
    mod._no_change_fastpath_signature = latest.Signature

    mod:info(
        "[ModShrine][PERF] NO_CHANGE_FASTPATH armed reason=%s live=%s disk=%s roster=%s",
        tostring(reason or "verified_state"),
        tostring(mod._no_change_fastpath_live_hash),
        tostring(mod._no_change_fastpath_disk_hash),
        tostring(mod._no_change_fastpath_roster_hash)
    )
    return true
end

function mod._current_roster_hash_for_fastpath()
    local started = perf_now()
    local roster = build_roster()

    if not roster
        or roster.scan_pending
        or not roster.enabled_scan_ok
        or not roster.installed_scan_ok
    then
        perf_log("fast_roster_probe", started, "trusted=false")
        return nil, "roster_untrusted"
    end

    local retired = read_name_map(retired_mods_path())
    local current_hash = roster_hash(roster, retired)

    perf_log(
        "fast_roster_probe",
        started,
        string.format(
            "trusted=true installed=%d enabled=%d",
            map_count(roster.installed),
            map_count(roster.enabled)
        )
    )

    return current_hash, nil
end

function mod._can_skip_unchanged_menu_snapshot(live_hash, disk_settings_hash)
    if pending_live_settings_hash then
        return false, "pending_live_change"
    end

    if not live_hash
        or not disk_settings_hash
        or not last_live_settings_hash
        or not mod._no_change_fastpath_live_hash
        or not mod._no_change_fastpath_disk_hash
        or not mod._no_change_fastpath_roster_hash
        or not mod._no_change_fastpath_snapshot
        or not mod._no_change_fastpath_signature
    then
        return false, "sentinel_unarmed"
    end

    if tostring(live_hash) ~= tostring(last_live_settings_hash)
        or tostring(live_hash) ~= tostring(mod._no_change_fastpath_live_hash)
    then
        return false, "live_settings_hash_mismatch"
    end

    if tostring(disk_settings_hash) ~= tostring(mod._no_change_fastpath_disk_hash) then
        return false, "disk_settings_hash_mismatch"
    end

    local current_roster_hash, roster_error = mod._current_roster_hash_for_fastpath()
    if not current_roster_hash then
        return false, roster_error or "roster_unknown"
    end

    if tostring(current_roster_hash) ~= tostring(mod._no_change_fastpath_roster_hash) then
        return false, "roster_hash_mismatch"
    end

    -- Keep the fast path tied to the exact latest snapshot that armed it. A
    -- deleted/replaced latest snapshot must fall back to the normal full check.
    local latest = latest_info()
    if not latest then
        return false, "latest_snapshot_unavailable"
    end

    if tostring(latest.Snapshot) ~= tostring(mod._no_change_fastpath_snapshot)
        or tostring(latest.Signature) ~= tostring(mod._no_change_fastpath_signature)
        or tostring(latest.RosterHash) ~= tostring(mod._no_change_fastpath_roster_hash)
    then
        return false, "latest_snapshot_changed"
    end

    return true, "verified_unchanged"
end

local function build_current_state()
    local perf_started = perf_now()
    local phase_started = perf_now()
    local source = source_path()
    if not source then
        return nil, "source_missing"
    end

    local text = read_all(source)
    if not text then
        return nil, "source_read_failed"
    end
    perf_log("state_source_read", phase_started, string.format("bytes=%d", #text))

    phase_started = perf_now()
    local analysis = analyze_config_text(text)
    perf_log(
        "state_config_analysis",
        phase_started,
        string.format("configured=%d settings=%d", analysis.mod_count, analysis.setting_count)
    )

    phase_started = perf_now()
    local roster = build_roster()
    perf_log(
        "state_roster_build",
        phase_started,
        string.format(
            "installed=%d enabled=%d trusted=%s",
            map_count(roster.installed),
            map_count(roster.enabled),
            tostring(roster.installed_scan_ok and roster.enabled_scan_ok)
        )
    )

    phase_started = perf_now()
    local forgotten = read_name_map(mod._forgotten_mods_path())
    local forgotten_changed = false

    -- Forgetting is intended for obsolete/missing IDs. If that exact ID is ever
    -- physically installed again, resume normal tracking automatically.
    for key, name in pairs(roster.installed or {}) do
        if forgotten[key] then
            forgotten[key] = nil
            forgotten_changed = true
            mod:info(
                "[ModShrine] Forgotten mod ID returned; tracking resumed automatically: %s",
                tostring(name)
            )
        end
    end

    if forgotten_changed then
        write_name_map(mod._forgotten_mods_path(), forgotten)
    end

    local retired = map_excluding(read_name_map(retired_mods_path()), forgotten)
    local seen_before = map_excluding(seed_seen_map(roster, analysis), forgotten)
    local latest = latest_info()
    local previous_analysis = nil
    local previous_manifest = nil
    perf_log(
        "state_bookkeeping_seed",
        phase_started,
        string.format(
            "retired=%d forgotten=%d latest=%s",
            map_count(retired),
            map_count(forgotten),
            tostring(latest ~= nil)
        )
    )

    phase_started = perf_now()
    if latest and latest.Snapshot then
        previous_analysis, previous_manifest =
            cached_previous_snapshot_data(latest.Snapshot)
    end
    perf_log(
        "state_previous_snapshot",
        phase_started,
        string.format("cached=%s", tostring(previous_analysis ~= nil))
    )

    local new_mods = {}
    local returned_mods = {}
    local missing_all = {}
    local missing_active = {}
    local retired_missing = {}
    local retired_present = {}
    local installed_disabled = map_difference(roster.installed, roster.enabled)

    -- Never infer added/missing/returned inventory while the physical-folder scan
    -- is pending or unavailable. That avoids false wipe alarms from an incomplete roster.
    if roster.installed_scan_ok then
        for key, name in pairs(roster.installed) do
            if not seen_before[key] then
                new_mods[key] = name
            elseif previous_manifest and not previous_manifest.installed[key] then
                returned_mods[key] = name
            end
        end

        missing_all = map_difference(seen_before, roster.installed)
        missing_active = map_excluding(missing_all, retired)
        retired_missing = map_intersection(missing_all, retired)
        retired_present = map_intersection(roster.installed, retired)
    end

    local changed_mods, changed_settings = compare_config_analyses(previous_analysis, analysis)

    local previous_installed_count = previous_manifest and map_count(previous_manifest.installed) or map_count(roster.installed)
    local current_installed_count = map_count(roster.installed)
    local active_missing_count = map_count(missing_active)
    local drop_count = math.max(previous_installed_count - current_installed_count, 0)

    local inventory_anomaly = false

    if roster.installed_scan_ok
        and previous_installed_count >= 10
        and active_missing_count >= 10
        and drop_count >= 10
        and current_installed_count <= math.floor(previous_installed_count * 0.70)
    then
        inventory_anomaly = true
    end

    local settings_anomaly = false
    local previous_settings_count = previous_analysis and previous_analysis.setting_count or analysis.setting_count

    if not inventory_anomaly
        and previous_analysis
        and previous_analysis.mod_count >= 10
        and math.abs(previous_analysis.mod_count - analysis.mod_count) <= 2
        and changed_settings >= 100
        and changed_settings >= math.floor(math.max(previous_settings_count, 1) * 0.25)
    then
        settings_anomaly = true
    end

    local r_hash = roster_hash(roster, retired)
    local signature = hash_string(
        tostring(analysis.hash) .. "|" ..
        tostring(r_hash)
    )

    phase_started = perf_now()
    local seen_after = {}
    map_union_into(seen_after, seen_before)
    map_union_into(seen_after, roster.installed)
    map_union_into(seen_after, roster.enabled)
    map_union_into(seen_after, configured_map_from_analysis(analysis))
    seen_after = map_excluding(seen_after, forgotten)
    write_name_map(seen_mods_path(), seen_after)
    perf_log(
        "state_compare_finalize",
        phase_started,
        string.format(
            "changed_mods=%d changed_settings=%d",
            map_count(changed_mods),
            changed_settings
        )
    )

    perf_log(
        "build_current_state",
        perf_started,
        string.format(
            "installed=%d configured=%d settings=%d scan_ok=%s",
            map_count(roster.installed),
            analysis.mod_count,
            analysis.setting_count,
            tostring(roster.installed_scan_ok)
        )
    )

    return {
        source = source,
        text = text,
        analysis = analysis,
        roster = roster,
        retired = retired,
        forgotten = forgotten,
        seen_before = seen_before,
        seen_after = seen_after,
        latest = latest,
        previous_manifest = previous_manifest,
        previous_analysis = previous_analysis,
        new_mods = new_mods,
        returned_mods = returned_mods,
        missing_all = missing_all,
        missing_active = missing_active,
        retired_missing = retired_missing,
        retired_present = retired_present,
        installed_disabled = installed_disabled,
        changed_mods = changed_mods,
        changed_settings = changed_settings,
        inventory_anomaly = inventory_anomaly,
        settings_anomaly = settings_anomaly,
        roster_hash = r_hash,
        signature = signature,
    }
end

function mod._clear_workflow_state_cache(reason)
    if mod._workflow_state_cache and reason then
        mod:info(
            "[ModShrine][PERF] WORKFLOW_CACHE cleared reason=%s",
            tostring(reason)
        )
    end

    mod._workflow_state_cache = nil
end

function mod._store_workflow_state_cache(state, reason)
    local latest = latest_info()
    local reject_reason = nil

    if not state then
        reject_reason = "state_missing"
    elseif not state.source or not state.text then
        reject_reason = "state_source_missing"
    elseif not state.roster_hash or not state.signature then
        reject_reason = "state_identity_missing"
    elseif not latest or not latest.Snapshot or not latest.Signature or not latest.RosterHash then
        reject_reason = "latest_unavailable"
    elseif not mod._no_change_fastpath_signature then
        reject_reason = "verified_sentinel_unarmed"
    elseif tostring(mod._no_change_fastpath_signature) ~= tostring(state.signature) then
        reject_reason = "verified_sentinel_mismatch"
    elseif tostring(latest.Signature) ~= tostring(state.signature) then
        reject_reason = "latest_signature_mismatch"
    elseif tostring(latest.RosterHash) ~= tostring(state.roster_hash) then
        reject_reason = "latest_roster_mismatch"
    end

    if reject_reason then
        mod._clear_workflow_state_cache("store_rejected_" .. reject_reason)
        mod:info(
            "[ModShrine][PERF] WORKFLOW_CACHE store_skipped reason=%s source=%s",
            tostring(reject_reason),
            tostring(reason or "full_build")
        )
        return false
    end

    -- Do not mutate the caller's state. Snapshot finalize still uses the
    -- pre-write `latest` value to report whether the roster changed. The UI
    -- cache instead receives a shallow state view pointed at the newly verified
    -- latest metadata.
    local cached_state = {}
    for key, value in pairs(state) do
        cached_state[key] = value
    end
    cached_state.latest = latest

    mod._workflow_state_cache = {
        state = cached_state,
        source = state.source,
        raw_hash = hash_string(state.text),
        roster_hash = state.roster_hash,
        signature = state.signature,
        latest_snapshot = latest.Snapshot,
        latest_signature = latest.Signature,
    }

    mod:info(
        "[ModShrine][PERF] WORKFLOW_CACHE stored reason=%s signature=%s",
        tostring(reason or "full_build"),
        tostring(state.signature)
    )
    return true
end

function mod._refresh_workflow_cache_raw_hash(reason)
    local cache = mod._workflow_state_cache

    if not cache
        or not mod._no_change_fastpath_signature
        or tostring(cache.signature) ~= tostring(mod._no_change_fastpath_signature)
    then
        return false
    end

    local source = source_path()
    if not source or tostring(source) ~= tostring(cache.source) then
        mod._clear_workflow_state_cache("raw_refresh_source_changed")
        return false
    end

    local raw_hash = content_hash(source)
    if not raw_hash then
        return false
    end

    cache.raw_hash = raw_hash
    mod:info(
        "[ModShrine][PERF] WORKFLOW_CACHE raw_refreshed reason=%s raw=%s",
        tostring(reason or "verified_flush"),
        tostring(raw_hash)
    )
    return true
end

function mod._workflow_cached_state_if_fresh()
    local started = perf_now()
    local cache = mod._workflow_state_cache

    if not cache then
        perf_log("workflow_cache_probe", started, "hit=false reason=empty")
        return nil, "empty"
    end

    if snapshot_job
        or #snapshot_queue > 0
        or pending_auto_backup_at
        or pending_live_settings_hash
        or not mod._no_change_fastpath_signature
        or tostring(mod._no_change_fastpath_signature) ~= tostring(cache.signature)
    then
        mod._clear_workflow_state_cache("verification_busy_or_disarmed")
        perf_log("workflow_cache_probe", started, "hit=false reason=busy_or_disarmed")
        return nil, "busy_or_disarmed"
    end

    local source = source_path()
    if not source or tostring(source) ~= tostring(cache.source) then
        mod._clear_workflow_state_cache("source_changed")
        perf_log("workflow_cache_probe", started, "hit=false reason=source_changed")
        return nil, "source_changed"
    end

    local raw_hash = content_hash(source)
    if not raw_hash or tostring(raw_hash) ~= tostring(cache.raw_hash) then
        mod._clear_workflow_state_cache("disk_changed")
        perf_log("workflow_cache_probe", started, "hit=false reason=disk_changed")
        return nil, "disk_changed"
    end

    local current_roster_hash, roster_error = mod._current_roster_hash_for_fastpath()
    if not current_roster_hash
        or tostring(current_roster_hash) ~= tostring(cache.roster_hash)
    then
        mod._clear_workflow_state_cache(roster_error or "roster_changed")
        perf_log(
            "workflow_cache_probe",
            started,
            "hit=false reason=" .. tostring(roster_error or "roster_changed")
        )
        return nil, roster_error or "roster_changed"
    end

    local latest = latest_info()
    if not latest
        or tostring(latest.Snapshot) ~= tostring(cache.latest_snapshot)
        or tostring(latest.Signature) ~= tostring(cache.latest_signature)
    then
        mod._clear_workflow_state_cache("latest_snapshot_changed")
        perf_log("workflow_cache_probe", started, "hit=false reason=latest_snapshot_changed")
        return nil, "latest_snapshot_changed"
    end

    perf_log("workflow_cache_probe", started, "hit=true reason=verified_unchanged")
    return cache.state, "verified_unchanged"
end

local function write_snapshot_assets(snapshot, state, timestamp, kind, reason)
    local manifest_tsv = snapshot_manifest_tsv_path(snapshot)
    local manifest_txt = snapshot_manifest_txt_path(snapshot)

    if not manifest_tsv or not manifest_txt then
        return nil
    end

    -- Flat sidecar manifests avoid spawning cmd.exe just to mkdir a new
    -- per-snapshot assets folder on Darktide's game thread.
    local tsv = {
        "META\tVersion\t" .. VERSION,
        "META\tTimestamp\t" .. tostring(timestamp),
        "META\tKind\t" .. tostring(kind),
        "META\tReason\t" .. tostring(reason),
        "META\tSettingsHash\t" .. tostring(state.analysis.hash),
        "META\tRosterHash\t" .. tostring(state.roster_hash),
        "META\tSignature\t" .. tostring(state.signature),
        "META\tSettingsCount\t" .. tostring(state.analysis.setting_count),
        "META\tConfiguredMods\t" .. tostring(state.analysis.mod_count),
        "META\tInstalledMods\t" .. tostring(map_count(state.roster.installed)),
        "META\tEnabledMods\t" .. tostring(map_count(state.roster.enabled)),
    }

    local human = {
        "MODSHRINE SNAPSHOT MANIFEST",
        "==========================",
        "Version: " .. VERSION,
        "Timestamp: " .. tostring(timestamp),
        "Kind: " .. tostring(kind),
        "Reason: " .. tostring(reason),
        "",
        "SUMMARY",
        "-------",
        "Enabled mods: " .. tostring(map_count(state.roster.enabled)),
        "Installed mods: " .. tostring(map_count(state.roster.installed)),
        "Configured mod blocks: " .. tostring(state.analysis.mod_count),
        "Meaningful stored settings: " .. tostring(state.analysis.setting_count),
        "Changed mods vs previous snapshot: " .. tostring(map_count(state.changed_mods)),
        "Changed settings vs previous snapshot: " .. tostring(state.changed_settings),
        "Missing active mods: " .. tostring(map_count(state.missing_active)),
        "New mods: " .. tostring(map_count(state.new_mods)),
        "Returned mods: " .. tostring(map_count(state.returned_mods)),
        "Retired mods: " .. tostring(map_count(state.retired)),
        "Inventory anomaly: " .. tostring(state.inventory_anomaly),
        "Settings anomaly: " .. tostring(state.settings_anomaly),
        "",
        "NOTE",
        "----",
        "The full raw snapshot contains the exact historical settings for every mod.",
        "Persistent per-mod archives are maintained separately under mod_archive.",
        "",
    }

    local expected_archive_presence =
        queue_persistent_archive_updates(state, timestamp)

    local all_names = {}
    map_union_into(all_names, state.roster.installed)
    map_union_into(all_names, state.roster.enabled)
    map_union_into(all_names, configured_map_from_analysis(state.analysis))
    map_union_into(all_names, state.retired)
    map_union_into(all_names, state.missing_all)
    all_names = map_excluding(all_names, state.forgotten)

    local function archive_present_for_manifest(name, key)
        if expected_archive_presence[key] ~= nil then
            return expected_archive_presence[key]
        end

        local prior =
            state.previous_manifest
            and state.previous_manifest.archive_present
            and state.previous_manifest.archive_present[key]

        if prior ~= nil then
            return prior == true
        end

        return archive_exists_for_mod(name)
    end

    for _, name in ipairs(sorted_names_from_map(all_names)) do
        local key = lower(name)
        local block = state.analysis.blocks[key]
        local archive_file = archive_present_for_manifest(name, key)
            and tostring(persistent_mod_archive_file(name) or "legacy")
            or ""

        tsv[#tsv + 1] = table.concat({
            "MOD",
            name:gsub("\t", " "),
            state.roster.enabled[key] and "1" or "0",
            state.roster.installed[key] and "1" or "0",
            block and "1" or "0",
            state.retired[key] and "1" or "0",
            block and tostring(block.hash) or "",
            block and tostring(block.setting_count) or "0",
            archive_file,
        }, "\t")
    end

    local function add_section(title, map)
        human[#human + 1] = title
        human[#human + 1] = string.rep("-", #title)
        local names = sorted_names_from_map(map)

        if #names == 0 then
            human[#human + 1] = "(none)"
        else
            for _, name in ipairs(names) do
                local key = lower(name)
                local archived =
                    archive_present_for_manifest(name, key)
                    and " [settings archived]"
                    or ""
                human[#human + 1] = "- " .. name .. archived
            end
        end
        human[#human + 1] = ""
    end

    add_section("ENABLED", state.roster.enabled)
    add_section("INSTALLED BUT DISABLED", state.installed_disabled)
    add_section("MISSING", state.missing_active)
    add_section("NEW", state.new_mods)
    add_section("RETURNED", state.returned_mods)
    add_section("RETIRED", state.retired)

    write_all(manifest_tsv, table.concat(tsv, "\n") .. "\n")
    write_all(manifest_txt, table.concat(human, "\n") .. "\n")

    return manifest_tsv
end

local function remove_snapshot_assets(snapshot)
    if _os and _os.remove then
        local flat_tsv = snapshot_manifest_tsv_path(snapshot)
        local flat_txt = snapshot_manifest_txt_path(snapshot)
        if flat_tsv then _os.remove(flat_tsv) end
        if flat_txt then _os.remove(flat_txt) end
    end

    -- v0.3.0-v0.3.2 used a per-snapshot _assets directory. Modern snapshots use
    -- flat sidecars, so do not pay the cost of spawning cmd.exe unless that
    -- legacy directory actually exists. Repeated 20/20 retention logs showed
    -- this unconditional process launch dominating snapshot_finalize.
    local assets = snapshot_assets_path(snapshot)
    if assets and _os and _os.execute and directory_exists_fast(assets) then
        local started = perf_now()
        _os.execute('start "" /b cmd.exe /d /c if exist ' .. q(assets) .. ' rmdir /s /q ' .. q(assets) .. ' > nul 2>&1')
        perf_log("retention_legacy_cleanup_launch", started, "legacy_assets=true")
    end
end

function mod._queue_retention_reconcile(entries, limit, reason)
    local queued_entries = {}

    for i = 1, #entries do
        queued_entries[i] = entries[i]
    end

    mod._retention_reconcile_job = {
        entries = queued_entries,
        valid_entries = {},
        seen = {},
        cursor = 1,
        limit = limit,
        reason = reason or "post_snapshot",
        wall_started_at = wall_now(),
        work_sum_ms = 0,
        max_check_ms = 0,
    }
    mod._retention_reconcile_next_at = wall_now() + mod._retention_reconcile_delay_seconds

    mod:info(
        "[ModShrine] Retention index reconciliation queued cooperatively: %d entry(s).",
        #queued_entries
    )
end

function mod._process_retention_reconcile(now)
    local job = mod._retention_reconcile_job

    if not job
        or not archive_processing_allowed
        or now < mod._retention_reconcile_next_at
        or snapshot_job
        or #snapshot_queue > 0
        or known_good_job
        or restore_job
    then
        return
    end

    if job.cursor <= #job.entries then
        local path = job.entries[job.cursor]
        local started = perf_now()
        local exists = file_exists(path)
        local elapsed = perf_ms(started)

        job.work_sum_ms = (job.work_sum_ms or 0) + elapsed
        job.max_check_ms = math.max(job.max_check_ms or 0, elapsed)

        if exists and not job.seen[path] then
            job.valid_entries[#job.valid_entries + 1] = path
            job.seen[path] = true
        end

        job.cursor = job.cursor + 1
        mod._retention_reconcile_next_at = now + mod._retention_reconcile_step_seconds
        return
    end

    local index_path = auto_index_path()
    if index_path then
        local write_started = perf_now()
        write_all(
            index_path,
            table.concat(job.valid_entries, "\n") .. (#job.valid_entries > 0 and "\n" or "")
        )
        local write_ms = perf_ms(write_started)
        job.work_sum_ms = (job.work_sum_ms or 0) + write_ms
        job.max_check_ms = math.max(job.max_check_ms or 0, write_ms)
    end

    mod:info(
        "[ModShrine][PERF] retention_reconcile_complete=%.2fms | checks=%d valid=%d removed=%d max_step=%.2fms wall_elapsed=%.2fms reason=%s",
        job.work_sum_ms or 0,
        #job.entries,
        #job.valid_entries,
        math.max(#job.entries - #job.valid_entries, 0),
        job.max_check_ms or 0,
        math.max((wall_now() - job.wall_started_at) * 1000, 0),
        tostring(job.reason)
    )

    mod._retention_reconcile_job = nil
    mod._retention_reconcile_next_at = 0
end

local function cleanup_auto_snapshots(new_snapshot)
    local limit = tonumber(mod:get("auto_backup_limit")) or 20
    local index_path = auto_index_path()

    if not index_path or not new_snapshot then
        return
    end

    local cleanup_started = perf_now()
    local parse_started = perf_now()
    local entries = {}
    local seen = {}
    local reconcile_needed = false
    local data = read_all(index_path)

    -- AUTO_SNAPSHOTS.txt is written by ModShrine, so finalization can trust its
    -- paths long enough to enforce the rolling count. Validating all paths with
    -- file_exists() here caused repeatable 94-118 ms cold-I/O stalls on the game
    -- thread. Existence reconciliation now runs later, one entry per safe update.
    if data then
        for line in string.gmatch(data, "[^\r\n]+") do
            line = trim(line)
            if line ~= "" then
                if not seen[line] then
                    entries[#entries + 1] = line
                    seen[line] = true
                else
                    reconcile_needed = true
                end
            end
        end
    end

    perf_log("retention_index_parse", parse_started, string.format("indexed=%d limit=%d", #entries, limit))

    if not seen[new_snapshot] then
        entries[#entries + 1] = new_snapshot
        seen[new_snapshot] = true
    end

    local pruned = 0
    while #entries > limit do
        local prune_started = perf_now()
        local old_path = table.remove(entries, 1)
        remove_snapshot_assets(old_path)

        if _os and _os.remove then
            local delete_started = perf_now()
            local ok = _os.remove(old_path)
            perf_log("retention_snapshot_delete", delete_started, string.format("ok=%s", tostring(ok == true)))
            if ok then
                mod:info("[ModShrine] Pruned indexed automatic snapshot: %s", old_path)
            else
                reconcile_needed = true
                mod:warning(
                    "[ModShrine] Indexed automatic snapshot was already missing or could not be pruned: %s",
                    old_path
                )
            end
        end

        pruned = pruned + 1
        perf_log("retention_prune_one", prune_started, string.format("remaining=%d", #entries))
    end

    local write_started = perf_now()
    write_all(index_path, table.concat(entries, "\n") .. (#entries > 0 and "\n" or ""))
    perf_log("retention_index_write", write_started, string.format("indexed=%d", #entries))

    -- Normal retention does not need to reopen all 20 snapshots. If the index
    -- shows evidence of staleness (duplicate lines or a missing prune target),
    -- reconcile it later and cooperatively. This keeps routine snapshots free of
    -- existence-probe I/O while still self-healing an abnormal index.
    if reconcile_needed then
        mod._queue_retention_reconcile(entries, limit, "index_anomaly")
    end

    perf_log(
        "retention_cleanup_total",
        cleanup_started,
        string.format(
            "pruned=%d indexed=%d/%d reconcile=%s",
            pruned,
            #entries,
            limit,
            reconcile_needed and "queued" or "not_needed"
        )
    )

    mod:info(
        "[ModShrine] Automatic retention updated in Lua: %d/%d indexed snapshot(s).",
        #entries,
        limit
    )
end

local function finish_snapshot_job(success, reason)
    if snapshot_job then
        snapshot_job.result_success = success
        snapshot_job.result_reason = reason
    end
    snapshot_job = nil
end

local function create_snapshot(requested_kind, reason, allow_duplicate, provided_state)
    if requested_kind == "auto" then
        if snapshot_job and snapshot_job.requested_kind == "auto" then
            mod:info("[ModShrine] Automatic snapshot request coalesced into active staged job.")
            return true, "coalesced"
        end

        for _, queued_job in ipairs(snapshot_queue) do
            if queued_job.requested_kind == "auto" then
                mod:info("[ModShrine] Automatic snapshot request coalesced into queued staged job.")
                return true, "coalesced"
            end
        end
    end

    if not archive_processing_allowed then
        mod:info(
            "[ModShrine] Snapshot deferred/blocked in unsafe state: %s",
            tostring(current_mission_name or "transition")
        )
        return false, "unsafe_state"
    end

    snapshot_queue[#snapshot_queue + 1] = {
        requested_kind = requested_kind,
        reason = reason,
        allow_duplicate = allow_duplicate == true,
        provided_state = provided_state,
        phase = "flush",
        flush_reason = reason,
        live_retry_count = 0,
        wall_started_at = wall_now(),
        work_sum_ms = 0,
        max_phase_ms = 0,
    }

    mod:info(
        "[ModShrine] Snapshot queued (%s/%s); queue=%d.",
        tostring(requested_kind),
        tostring(reason),
        #snapshot_queue
    )
    return true, "queued"
end

local function process_snapshot_job(now)
    if not archive_processing_allowed or now < snapshot_next_at then
        return
    end

    if not snapshot_job then
        if #snapshot_queue == 0 then
            return
        end
        snapshot_job = table.remove(snapshot_queue, 1)
    end

    local job = snapshot_job
    local phase_started = perf_now()

    if job.phase == "flush" then
        force_dmf_settings_flush(job.flush_reason or job.reason or job.requested_kind)
        job.phase = "prepare"
        perf_track(job, "snapshot_dmf_flush", phase_started, tostring(job.reason))
        snapshot_next_at = now + SNAPSHOT_STEP_SECONDS
        return

    elseif job.phase == "prepare" then
        local state = job.provided_state
        local state_error = nil

        if not state then
            state, state_error = build_current_state()
        end

        if not state then
            mod:error("[ModShrine] Could not build current state: %s", tostring(state_error))
            notify("ModShrine: current configuration could not be analyzed.")
            perf_track(job, "snapshot_prepare", phase_started, "failed")
            finish_snapshot_job(false, state_error)
            return
        end

        if state.roster.scan_pending then
            job.provided_state = nil
            snapshot_next_at = now + 0.50
            mod:info("[ModShrine] Snapshot staged job waiting for installed-mod scan.")
            return
        end

        if maybe_alert_missing then
            maybe_alert_missing(state)
        end

        if cancel_pending_restore_if_state_changed then
            cancel_pending_restore_if_state_changed(state)
        end

        if not job.allow_duplicate
            and state.latest
            and state.latest.Signature
            and state.latest.Signature == state.signature
        then
            if pending_live_settings_hash and (job.live_retry_count or 0) < 3 then
                job.live_retry_count = (job.live_retry_count or 0) + 1
                job.provided_state = nil
                job.phase = "flush"
                snapshot_next_at = now + 0.35

                mod:warning(
                    "[ModShrine] Live DMF settings changed but disk still matches latest snapshot; forcing save again (%d/3).",
                    job.live_retry_count
                )
                perf_track(job, "snapshot_prepare", phase_started, "live_change_disk_stale")
                return
            end

            if pending_live_settings_hash then
                mod:error(
                    "[ModShrine] LIVE/DISK mismatch survived 3 forced DMF saves. Backup NOT trusted as unchanged."
                )
                notify(
                    "ModShrine: live mod settings changed but the settings file did not update. Do not stage a restore yet; send the console log."
                )
                perf_track(job, "snapshot_prepare", phase_started, "live_disk_mismatch")
                finish_snapshot_job(false, "live_disk_mismatch")
                return
            end

            mod:info("[ModShrine] Snapshot skipped: meaningful settings and roster are unchanged.")
            perf_track(job, "snapshot_prepare", phase_started, "duplicate")
            if job.requested_kind == "manual" then
                notify("ModShrine: no meaningful settings or roster changes since the latest backup.")
            end
            if refresh_live_settings_baseline("duplicate_confirmed") then
                if mod._arm_no_change_fastpath(state, "duplicate_confirmed") then
                    mod._store_workflow_state_cache(state, "duplicate_confirmed")
                end
            else
                mod._clear_no_change_fastpath("duplicate_baseline_refresh_failed")
            end
            finish_snapshot_job(false, "duplicate")
            return
        end

        local dir = snapshots_path()
        if not dir then
            notify("ModShrine: backup vault path is unavailable.")
            finish_snapshot_job(false, "vault_missing")
            return
        end

        ensure_dir(vault_root())
        ensure_dir(dir)
        ensure_dir(persistent_archive_path())
        ensure_dir(exports_path())

        local actual_kind = job.requested_kind
        if job.requested_kind == "auto" and (state.inventory_anomaly or state.settings_anomaly) then
            actual_kind = "incident"
        end

        job.state = state
        job.actual_kind = actual_kind
        job.timestamp = stamp()
        job.destination = dir .. "\\user_settings_" .. job.timestamp .. "_" .. actual_kind .. ".config"
        job.source_bytes = #state.text
        job.source_raw_hash = hash_string(state.text)
        job.provided_state = nil
        job.phase = "write"
        perf_track(job, "snapshot_prepare", phase_started, string.format("changed=%d", state.changed_settings))

    elseif job.phase == "write" then
        if not write_all(job.destination, job.state.text) then
            notify("ModShrine: backup could not be written.")
            perf_track(job, "snapshot_write", phase_started, "failed")
            finish_snapshot_job(false, "copy_unavailable")
            return
        end
        perf_track(job, "snapshot_write", phase_started, string.format("bytes=%d", job.source_bytes))
        job.phase = "verify"

    elseif job.phase == "verify" then
        job.backup_bytes = file_size(job.destination)
        job.backup_raw_hash = content_hash(job.destination)
        perf_track(job, "snapshot_verify", phase_started, "raw_copy")

        if not job.source_bytes
            or not job.backup_bytes
            or job.source_bytes ~= job.backup_bytes
            or not job.source_raw_hash
            or job.source_raw_hash ~= job.backup_raw_hash
        then
            mod:error(
                "[ModShrine] Backup verification failed. Source=%s/%s Backup=%s/%s",
                tostring(job.source_bytes),
                tostring(job.source_raw_hash),
                tostring(job.backup_bytes),
                tostring(job.backup_raw_hash)
            )
            notify("ModShrine: backup failed verification.")
            finish_snapshot_job(false, "verification_failed")
            return
        end

        job.phase = "manifest"

    elseif job.phase == "manifest" then
        job.manifest = write_snapshot_assets(
            job.destination,
            job.state,
            job.timestamp,
            job.actual_kind,
            job.reason
        )
        perf_track(job, "snapshot_manifest", phase_started, string.format("queued_archive=%d", #archive_queue))
        job.phase = "metadata"

    elseif job.phase == "metadata" then
        write_metadata(latest_metadata_path(), {
            Version = VERSION,
            Timestamp = job.timestamp,
            Kind = job.actual_kind,
            Reason = job.reason or "unknown",
            Source = job.state.source,
            Snapshot = job.destination,
            Bytes = job.backup_bytes,
            RawHash = job.backup_raw_hash,
            SettingsHash = job.state.analysis.hash,
            RosterHash = job.state.roster_hash,
            Signature = job.state.signature,
            SettingsCount = job.state.analysis.setting_count,
            ConfiguredMods = job.state.analysis.mod_count,
            InstalledMods = map_count(job.state.roster.installed),
            EnabledMods = map_count(job.state.roster.enabled),
            Manifest = job.manifest or "",
        })

        cache_completed_snapshot(
            job.destination,
            job.state.analysis,
            job.manifest
        )

        perf_track(job, "snapshot_metadata", phase_started, job.actual_kind)
        job.phase = "finalize"

    elseif job.phase == "finalize" then
        local state = job.state
        mod:info(
            "[ModShrine] Verified %s snapshot: %s | mods=%d settings=%d changed=%d/%d missing=%d new=%d returned=%d",
            job.actual_kind,
            job.destination,
            state.analysis.mod_count,
            state.analysis.setting_count,
            map_count(state.changed_mods),
            state.changed_settings,
            map_count(state.missing_active),
            map_count(state.new_mods),
            map_count(state.returned_mods)
        )

        if job.actual_kind == "auto" then
            cleanup_auto_snapshots(job.destination)

            local roster_changed =
                state.latest
                and state.latest.RosterHash
                and tostring(state.latest.RosterHash) ~= tostring(state.roster_hash)

            if state.changed_settings > 0 and roster_changed then
                notify(string.format(
                    "ModShrine: %d setting change(s) + mod roster change, automatic backup secured.",
                    state.changed_settings
                ))
            elseif state.changed_settings > 0 then
                notify(string.format(
                    "ModShrine: %d setting change(s), automatic backup secured.",
                    state.changed_settings
                ))
            elseif roster_changed then
                notify("ModShrine: mod roster changed, automatic backup secured.")
            else
                notify("ModShrine: automatic backup secured.")
            end
        elseif job.actual_kind == "incident" then
            notify("ModShrine: unusual settings/mod inventory change detected. Protected incident snapshot created; auto-pruning skipped.")
        else
            notify("ModShrine: manual backup secured with roster + per-mod archives.")
        end

        if refresh_live_settings_baseline("snapshot_created") then
            if mod._arm_no_change_fastpath(state, "snapshot_created") then
                mod._store_workflow_state_cache(state, "snapshot_created")
            end
        else
            mod._clear_no_change_fastpath("snapshot_baseline_refresh_failed")
        end
        perf_track(job, "snapshot_finalize", phase_started, job.actual_kind)
        mod:info(
            "[ModShrine][PERF] snapshot_work_sum=%.2fms | max_phase=%.2fms | wall_elapsed=%.2fms | staged kind=%s changed=%d",
            job.work_sum_ms or 0,
            job.max_phase_ms or 0,
            math.max((wall_now() - job.wall_started_at) * 1000, 0),
            tostring(job.actual_kind),
            state.changed_settings
        )
        mod:info(
            "[ModShrine][RC] SNAPSHOT_OK kind=%s changed=%d work=%.2fms max_phase=%.2fms",
            tostring(job.actual_kind),
            state.changed_settings,
            job.work_sum_ms or 0,
            job.max_phase_ms or 0
        )
        finish_snapshot_job(true, "created")
        return
    end

    snapshot_next_at = now + SNAPSHOT_STEP_SECONDS
end

local function write_current_roster_export()
    local perf_started = perf_now()
    local state, err = build_current_state()

    if not state then
        notify("ModShrine: roster could not be built.")
        mod:error("[ModShrine] Roster export failed: %s", tostring(err))
        return nil
    end

    local dir = exports_path()
    ensure_dir(vault_root())
    ensure_dir(dir)

    local path = dir .. "\\ModRoster_" .. stamp() .. ".txt"
    local lines = {
        "MODSHRINE MOD ROSTER",
        "====================",
        "Generated: " .. stamp(),
        "Version: " .. VERSION,
        "",
        "CURRENT SUMMARY",
        "---------------",
        "Installed: " .. tostring(map_count(state.roster.installed)),
        "Enabled: " .. tostring(map_count(state.roster.enabled)),
        "Installed but disabled: " .. tostring(map_count(state.installed_disabled)),
        "Configured settings blocks: " .. tostring(state.analysis.mod_count),
        "Stored meaningful settings: " .. tostring(state.analysis.setting_count),
        "",
        "ROSTER MEMORY",
        "-------------",
        "Previously seen mods: " .. tostring(map_count(state.seen_after)),
        "Missing: " .. tostring(map_count(state.missing_active)),
        "New: " .. tostring(map_count(state.new_mods)),
        "Returned: " .. tostring(map_count(state.returned_mods)),
        "Retired: " .. tostring(map_count(state.retired)),
        "",
    }

    local function add(title, map)
        lines[#lines + 1] = title
        lines[#lines + 1] = string.rep("-", #title)

        local names = sorted_names_from_map(map)

        if #names == 0 then
            lines[#lines + 1] = "(none)"
        else
            for _, name in ipairs(names) do
                local archived = archive_exists_for_mod(name) and " | archived settings: YES" or " | archived settings: no"
                lines[#lines + 1] = "- " .. name .. archived
            end
        end

        lines[#lines + 1] = ""
    end

    add("ENABLED MODS", state.roster.enabled)
    add("INSTALLED BUT DISABLED", state.installed_disabled)
    add("MISSING MODS", state.missing_active)
    add("NEW MODS", state.new_mods)
    add("RETURNED MODS", state.returned_mods)
    add("RETIRED MODS", state.retired)

    write_all(path, table.concat(lines, "\n") .. "\n")
    mod:info("[ModShrine] Exported mod roster: %s", path)
    notify("ModShrine: human-readable mod roster exported.")
    perf_log(
        "roster_export_total",
        perf_started,
        string.format("installed=%d", map_count(state.roster.installed))
    )
    return path
end

local function set_retired(name, should_retire)
    local retired = read_name_map(retired_mods_path())
    local key = lower(name)

    if should_retire then
        retired[key] = name
        notify("ModShrine: " .. name .. " marked Retired. Its archived settings were preserved.")
    else
        retired[key] = nil
        notify("ModShrine: " .. name .. " removed from Retired. Archived settings are still available.")
    end

    write_name_map(retired_mods_path(), retired)
    mod:info("[ModShrine] Retired state changed: %s => %s", name, tostring(should_retire))
end

function mod._forget_retired_mod(name)
    local key = lower(name)
    local roster = build_roster()

    if roster.installed and roster.installed[key] then
        notify(
            "ModShrine: " .. tostring(name) ..
            " is installed again. Tracking was not forgotten."
        )
        mod:warning(
            "[ModShrine] Forget Retired rejected for installed mod: %s",
            tostring(name)
        )
        return false
    end

    local forgotten = read_name_map(mod._forgotten_mods_path())
    local retired = read_name_map(retired_mods_path())
    local seen = read_name_map(seen_mods_path())

    forgotten[key] = name
    retired[key] = nil
    seen[key] = nil

    if not write_name_map(mod._forgotten_mods_path(), forgotten) then
        notify("ModShrine: could not save the forgotten-mod list. Nothing was intentionally deleted.")
        mod:error(
            "[ModShrine] Forget Retired failed to write forgotten map: %s",
            tostring(name)
        )
        return false
    end

    local retired_ok = write_name_map(retired_mods_path(), retired)
    local seen_ok = write_name_map(seen_mods_path(), seen)

    if not retired_ok or not seen_ok then
        mod:warning(
            "[ModShrine] Forget Retired saved suppression but cleanup was partial: %s retired_ok=%s seen_ok=%s",
            tostring(name),
            tostring(retired_ok),
            tostring(seen_ok)
        )
    end

    -- Retired roster identity changed. Force the next protection check through
    -- the normal full verifier; the historical snapshot/archive bytes are kept.
    mod._clear_no_change_fastpath("retired_mod_forgotten")

    if mod._clear_restore_preview_unlock then
        mod._clear_restore_preview_unlock("retired_mod_forgotten")
    end

    notify(
        "ModShrine: stopped tracking retired mod " .. tostring(name) ..
        ". Historical snapshots and its existing archive were preserved."
    )
    mod:info(
        "[ModShrine] Retired mod forgotten: %s | archive_preserved=true",
        tostring(name)
    )
    return true
end

function mod._clear_preview_target_cache(reason)
    if mod._preview_target_cache and reason then
        mod:info(
            "[ModShrine][PERF] PREVIEW_TARGET_CACHE cleared reason=%s",
            tostring(reason)
        )
    end

    mod._preview_target_cache = nil
end

function mod._preview_target_cached_if_fresh(target, source_id)
    local started = perf_now()
    local cache = mod._preview_target_cache

    if not cache then
        perf_log("preview_target_cache_probe", started, "hit=false reason=empty")
        return nil, "empty"
    end

    if not target
        or tostring(cache.source_id) ~= tostring(source_id)
        or tostring(cache.snapshot) ~= tostring(target.Snapshot)
        or tostring(cache.signature) ~= tostring(target.Signature)
        or tostring(cache.raw_hash) ~= tostring(target.RawHash)
        or tostring(cache.manifest) ~= tostring(target.Manifest)
    then
        mod._clear_preview_target_cache("identity_changed")
        perf_log("preview_target_cache_probe", started, "hit=false reason=identity_changed")
        return nil, "identity_changed"
    end

    if not file_exists(target.Snapshot) then
        mod._clear_preview_target_cache("snapshot_missing")
        perf_log("preview_target_cache_probe", started, "hit=false reason=snapshot_missing")
        return nil, "snapshot_missing"
    end

    if target.Manifest and tostring(target.Manifest) ~= "" and not file_exists(target.Manifest) then
        mod._clear_preview_target_cache("manifest_missing")
        perf_log("preview_target_cache_probe", started, "hit=false reason=manifest_missing")
        return nil, "manifest_missing"
    end

    perf_log("preview_target_cache_probe", started, "hit=true reason=identity_match")
    return cache.target, "identity_match"
end

function mod._store_preview_target_cache(target, result, source_id)
    if not target or not result or not target.Snapshot then
        mod:info(
            "[ModShrine][PERF] PREVIEW_TARGET_CACHE store_skipped reason=incomplete_target"
        )
        return false
    end

    mod._preview_target_cache = {
        target = result,
        source_id = source_id,
        snapshot = target.Snapshot,
        signature = target.Signature,
        raw_hash = target.RawHash,
        manifest = target.Manifest,
    }

    mod:info(
        "[ModShrine][PERF] PREVIEW_TARGET_CACHE stored source=%s snapshot=%s",
        tostring(source_id),
        tostring(target.Snapshot)
    )
    return true
end

local function target_state_for_preview(allow_ui_cache)
    local perf_started = perf_now()
    local known = known_good_info()
    local target = known or latest_info()

    if not target then
        return nil, "no_snapshot"
    end

    local source_id = known and "known_good" or "latest_verified"

    if allow_ui_cache then
        local cached, cache_reason =
            mod._preview_target_cached_if_fresh(target, source_id)
        if cached then
            perf_log(
                "preview_target_total",
                perf_started,
                string.format("source=%s cached=true", source_id)
            )
            return cached
        end

        mod:info(
            "[ModShrine][PERF] PREVIEW_TARGET_CACHE rebuild reason=%s source=%s",
            tostring(cache_reason or "unknown"),
            tostring(source_id)
        )
    end

    local phase_started = perf_now()
    local text = read_all(target.Snapshot)
    if not text then
        return nil, "snapshot_unreadable"
    end
    perf_log(
        "preview_target_read",
        phase_started,
        string.format("source=%s bytes=%d", known and "known_good" or "latest", #text)
    )

    phase_started = perf_now()
    local analysis = analyze_config_text(text)
    perf_log(
        "preview_target_analysis",
        phase_started,
        string.format("configured=%d settings=%d", analysis.mod_count, analysis.setting_count)
    )

    phase_started = perf_now()
    local manifest = manifest_for_snapshot(target.Snapshot)
    perf_log("preview_target_manifest", phase_started, tostring(manifest ~= nil))

    local target_installed = {}
    local target_enabled = {}

    if manifest then
        map_union_into(target_installed, manifest.installed)
        map_union_into(target_enabled, manifest.enabled)
    else
        -- Legacy v0.1/v0.2 snapshots did not yet contain roster manifests.
        -- Configured mod blocks are the safest non-destructive approximation.
        map_union_into(target_installed, configured_map_from_analysis(analysis))
        map_union_into(target_enabled, configured_map_from_analysis(analysis))
    end

    local result = {
        meta = target,
        analysis = analysis,
        manifest = manifest,
        installed = target_installed,
        enabled = target_enabled,
        source_id = source_id,
        source_kind = known and "Known Good" or "Latest Verified",
        roster_confidence = manifest and "full manifest" or "legacy/configured-mod approximation",
    }

    if allow_ui_cache then
        mod._store_preview_target_cache(target, result, source_id)
    end

    perf_log(
        "preview_target_total",
        perf_started,
        string.format("source=%s cached=false", result.source_id)
    )
    return result
end

mod._clear_restore_preview_unlock = function(reason)
    if restore_preview_signature then
        mod:info(
            "[ModShrine][UX] Restore Preview unlock cleared (%s).",
            tostring(reason or "unknown")
        )
    end

    restore_preview_signature = nil
    restore_preview_source_snapshot = nil
    restore_preview_source_id = nil
    restore_preview_setting_changes = 0
    restore_preview_completed_at = nil
end

local function set_restore_preview_unlock(current, target, plan)
    if not current or not target or not plan or (plan.setting_changes or 0) <= 0 then
        mod._clear_restore_preview_unlock("preview_no_changes")
        return false
    end

    restore_preview_signature = current.signature
    restore_preview_source_snapshot = target.meta and target.meta.Snapshot or nil
    restore_preview_source_id = target.source_id or target.source_kind
    restore_preview_setting_changes = plan.setting_changes
    restore_preview_completed_at = wall_now()

    mod:info(
        "[ModShrine][UX] STEP3_COMPLETE source_id=%s source_label=%s changes=%d signature=%s",
        tostring(restore_preview_source_id),
        tostring(target.source_kind),
        restore_preview_setting_changes,
        tostring(restore_preview_signature)
    )

    return true
end

local function restore_preview_matches(current, target)
    if not current
        or not target
        or not restore_preview_signature
        or restore_preview_setting_changes <= 0
    then
        return false
    end

    local target_snapshot = target.meta and target.meta.Snapshot or nil

    return tostring(current.signature) == tostring(restore_preview_signature)
        and tostring(target_snapshot) == tostring(restore_preview_source_snapshot)
        and tostring(target.source_id or target.source_kind) == tostring(restore_preview_source_id)
end

local function write_safe_restore_preview()
    local perf_started = perf_now()
    local target, target_error = target_state_for_preview()

    if not target then
        notify("ModShrine: no usable backup exists for restore preview.")
        mod:warning("[ModShrine] Restore preview unavailable: %s", tostring(target_error))
        return nil
    end

    local current, current_error = build_current_state()

    if not current then
        notify("ModShrine: current roster could not be analyzed.")
        mod:error("[ModShrine] Restore preview current-state error: %s", tostring(current_error))
        return nil
    end

    -- Preview and Restore share the same planning function.
    local plan = build_safe_restore_maps(current, target)
    local plan_ok, plan_errors = validate_safe_restore_plan(current, target, plan)

    if not plan_ok then
        mod:error(
            "[ModShrine] Safe Restore Preview rejected invalid plan (%d error(s)).",
            #plan_errors
        )
        for i = 1, math.min(#plan_errors, 20) do
            mod:error("[ModShrine] Preview plan validation: %s", tostring(plan_errors[i]))
        end
        notify("ModShrine: Safe Restore Preview rejected an invalid restore plan. Nothing was modified.")
        return nil
    end

    local matching = plan.matching
    local new_current = plan.new_current
    local missing_target = plan.missing_target
    local retired_target = plan.retired_target

    local dir = exports_path()
    ensure_dir(vault_root())
    ensure_dir(dir)

    local path = dir .. "\\SafeRestorePreview_" .. stamp() .. ".txt"
    local lines = {
        "MODSHRINE SAFE RESTORE PREVIEW",
        "==============================",
        "",
        "THIS FILE IS A PREVIEW ONLY.",
        "NO LIVE SETTINGS WERE MODIFIED.",
        "",
        "Restore source: " .. tostring(target.source_kind),
        "Snapshot: " .. tostring(target.meta.Snapshot),
        "Roster data: " .. tostring(target.roster_confidence),
        "",
        "SAFE RESTORE PLAN",
        "-----------------",
        tostring(map_count(matching)) .. " currently installed mod(s) have archived settings that WOULD be restored.",
        tostring(map_count(new_current)) .. " current/new mod(s) WOULD remain unchanged.",
        tostring(map_count(missing_target)) .. " snapshot mod(s) are currently missing and WOULD remain archived.",
        tostring(map_count(retired_target)) .. " retired mod(s) WOULD be excluded from restore.",
        tostring(plan.setting_changes) .. " saved setting value(s) WOULD change.",
        tostring(plan.current_only_preserved) .. " current-only/newer setting(s) WOULD be preserved.",
        "0 settings are modified by this preview.",
        "",
    }

    local function add(title, map)
        lines[#lines + 1] = title
        lines[#lines + 1] = string.rep("-", #title)

        local names = sorted_names_from_map(map)

        if #names == 0 then
            lines[#lines + 1] = "(none)"
        else
            for _, name in ipairs(names) do
                lines[#lines + 1] = "- " .. name
            end
        end

        lines[#lines + 1] = ""
    end

    add("WOULD RESTORE", matching)
    add("WOULD LEAVE UNCHANGED (NEW/CURRENT)", new_current)
    add("MISSING - SETTINGS REMAIN ARCHIVED", missing_target)
    add("RETIRED - EXCLUDED", retired_target)

    if not write_all(path, table.concat(lines, "\n") .. "\n") then
        mod:error("[ModShrine] Safe Restore Preview export write failed: %s", tostring(path))
        notify("ModShrine: preview analysis completed, but the preview file could not be written. Nothing was modified.")
        return nil
    end

    mod:info(
        "[ModShrine] Safe restore preview: restore=%d unchanged=%d missing=%d retired=%d setting_changes=%d preserved_newer=%d -> %s",
        map_count(matching),
        map_count(new_current),
        map_count(missing_target),
        map_count(retired_target),
        plan.setting_changes,
        plan.current_only_preserved,
        path
    )

    notify(
        string.format(
            "ModShrine preview: %d mod(s) restore, %d setting value(s) change, %d current/new mod(s) untouched, %d missing, %d retired. Nothing was modified.",
            map_count(matching),
            plan.setting_changes,
            map_count(new_current),
            map_count(missing_target),
            map_count(retired_target)
        )
    )

    perf_log(
        "restore_preview_total",
        perf_started,
        string.format("restore=%d", map_count(matching))
    )
    mod:info(
        "[ModShrine][RC] RESTORE_PREVIEW source_id=%s source=%s mods=%d changes=%d untouched=%d missing=%d retired=%d",
        tostring(target.source_id or "legacy"),
        tostring(target.source_kind),
        map_count(matching),
        plan.setting_changes,
        map_count(new_current),
        map_count(missing_target),
        map_count(retired_target)
    )

    if set_restore_preview_unlock(current, target, plan) then
        notify(
            "ModShrine: Step 3 complete. Preview validated. Step 4 is now unlocked."
        )
    else
        notify(
            "ModShrine: restore is not needed; current settings already match the trusted restore point."
        )
    end

    return path
end


local function pending_restore_info()
    return read_metadata(restore_pending_path())
end

local function pending_restore_is_armed()
    return file_exists(restore_pending_path()) and not file_exists(restore_result_path())
end

local function batch_escape(value)
    return tostring(value or ""):gsub("%%", "%%%%")
end

local function write_restore_watcher_paths(staged_path, live_path)
    local script_path = restore_watcher_path()
    if not script_path or not staged_path or not live_path then
        return false
    end

    local staged = batch_escape(staged_path)
    local live = batch_escape(live_path)
    local result = batch_escape(restore_result_path())
    local cancel = batch_escape(restore_cancel_path())

    local lines = {
        "@echo off",
        "setlocal",
        'set "STAGED=' .. staged .. '"',
        'set "LIVE=' .. live .. '"',
        'set "RESULT=' .. result .. '"',
        'set "CANCEL=' .. cancel .. '"',
        "",
        ":wait_for_darktide_exit",
        'if exist "%CANCEL%" goto canceled',
        'tasklist /FI "IMAGENAME eq Darktide.exe" /NH | find /I "Darktide.exe" >nul',
        "if not errorlevel 1 (",
        "  timeout /t 2 /nobreak >nul",
        "  goto wait_for_darktide_exit",
        ")",
        "",
        'if exist "%CANCEL%" goto canceled',
        'copy /b /y "%STAGED%" "%LIVE%" >nul',
        "if errorlevel 1 goto failed",
        'fc /b "%STAGED%" "%LIVE%" >nul',
        "if errorlevel 1 goto failed",
        '>"%RESULT%" echo Status: SUCCESS',
        '>>"%RESULT%" echo Applied: %DATE% %TIME%',
        '>>"%RESULT%" echo Staged: %STAGED%',
        '>>"%RESULT%" echo Live: %LIVE%',
        "exit /b 0",
        "",
        ":canceled",
        '>"%RESULT%" echo Status: CANCELED',
        '>>"%RESULT%" echo Applied: %DATE% %TIME%',
        '>>"%RESULT%" echo Staged: %STAGED%',
        '>>"%RESULT%" echo Live: %LIVE%',
        "exit /b 0",
        "",
        ":failed",
        '>"%RESULT%" echo Status: FAILED',
        '>>"%RESULT%" echo Applied: %DATE% %TIME%',
        '>>"%RESULT%" echo Staged: %STAGED%',
        '>>"%RESULT%" echo Live: %LIVE%',
        "exit /b 1",
    }

    return write_all(script_path, table.concat(lines, "\r\n") .. "\r\n")
end

local function write_restore_watcher(job)
    return write_restore_watcher_paths(job.staged_path, job.current.source)
end

local function vbs_escape(value)
    return tostring(value or ""):gsub('"', '""')
end

local function write_restore_hidden_launcher()
    local script_path = restore_watcher_path()
    local launcher_path = restore_launcher_path()

    if not script_path or not launcher_path then
        return false
    end

    -- WScript runs the CMD watcher with window style 0 (hidden).
    local command = 'cmd.exe /d /c call "' .. script_path .. '"'
    local vbs = table.concat({
        'On Error Resume Next',
        'Set shell = CreateObject("WScript.Shell")',
        'shell.Run "' .. vbs_escape(command) .. '", 0, False',
        'Set shell = Nothing',
        '',
    }, "\r\n")

    return write_all(launcher_path, vbs)
end

local function launch_restore_watcher_hidden()
    local launcher_path = restore_launcher_path()

    if not _os or not _os.execute or not launcher_path then
        return false
    end

    if not write_restore_hidden_launcher() then
        return false
    end

    -- wscript.exe is a GUI host. The long-lived cmd.exe it creates is hidden.
    _os.execute('wscript.exe //B //Nologo ' .. q(launcher_path) .. ' > nul 2>&1')
    restore_watcher_launched_this_session = true

    return true
end

local function write_restore_plan_file(job)
    local dir = exports_path()
    ensure_dir(dir)

    local path = dir .. "\\SafeRestorePlan_" .. job.timestamp .. ".txt"
    local lines = {
        "MODSHRINE SAFE RESTORE PLAN",
        "===========================",
        "",
        "Restore source: " .. tostring(job.target.source_kind),
        "Snapshot: " .. tostring(job.target.meta.Snapshot),
        "Pre-restore guard: " .. tostring(job.guard_path),
        "Staged merged config: " .. tostring(job.staged_path),
        "",
        "PLAN",
        "----",
        "Installed matching mods restored: " .. tostring(map_count(job.plan.matching)),
        "New/current mods left unchanged: " .. tostring(map_count(job.plan.new_current)),
        "Missing target mods left archived: " .. tostring(map_count(job.plan.missing_target)),
        "Retired mods excluded: " .. tostring(map_count(job.plan.retired_target)),
        "Saved setting values changed: " .. tostring(job.plan.setting_changes),
        "Current-only/newer settings preserved: " .. tostring(job.plan.current_only_preserved),
        "",
        "APPLICATION METHOD",
        "------------------",
        "The live config is NOT overwritten while Darktide is running.",
        "A detached watcher waits for Darktide.exe to fully exit, then copies the",
        "verified staged config into place and byte-verifies the result.",
        "",
        "If meaningful settings/roster data changes after staging, ModShrine requests",
        "cancellation so newer work is not silently overwritten.",
        "",
    }

    local function add(title, map)
        lines[#lines + 1] = title
        lines[#lines + 1] = string.rep("-", #title)
        local names = sorted_names_from_map(map)
        if #names == 0 then
            lines[#lines + 1] = "(none)"
        else
            for _, name in ipairs(names) do
                lines[#lines + 1] = "- " .. name
            end
        end
        lines[#lines + 1] = ""
    end

    add("RESTORED MODS", job.plan.matching)
    add("LEFT UNCHANGED", job.plan.new_current)
    add("MISSING / ARCHIVED", job.plan.missing_target)
    add("RETIRED / EXCLUDED", job.plan.retired_target)

    write_all(path, table.concat(lines, "\n") .. "\n")
    return path
end

local function cancel_pending_restore(reason)
    if not pending_restore_is_armed() then
        return false, false
    end

    if pending_restore_cancel_requested or file_exists(restore_cancel_path()) then
        pending_restore_cancel_requested = true
        if not pending_cancel_cleanup_at then
            pending_cancel_cleanup_at = wall_now() + 3.0
        end
        return true, false
    end

    ensure_dir(vault_root())
    write_all(
        restore_cancel_path(),
        "Cancel requested: " .. tostring(reason or "user") .. "\n"
    )

    pending_restore_cancel_requested = true

    -- A healthy watcher will consume this immediately. If the watcher was
    -- manually killed/orphaned, clear the stale armed state after a short grace.
    pending_cancel_cleanup_at = wall_now() + 3.0

    mod:warning("[ModShrine] Pending Safe Restore cancellation requested: %s", tostring(reason))
    return true, true
end

cancel_pending_restore_if_state_changed = function(state)
    if not state or not pending_restore_is_armed() then
        return
    end

    local pending = pending_restore_info()
    if not pending or not pending.CurrentSignature then
        return
    end

    if tostring(state.signature) ~= tostring(pending.CurrentSignature) then
        local _ok, newly_requested =
            cancel_pending_restore("meaningful settings/roster changed after restore staging")

        if newly_requested then
            notify("ModShrine: pending Safe Restore canceled because settings changed after it was staged.")
        end
    end
end


local function pending_restore_recovery_valid(pending)
    local errors = {}

    if not pending then
        return false, { "pending metadata missing" }
    end

    for _, field in ipairs({
        "Staged",
        "Live",
        "ExpectedHash",
        "PreRestoreGuard",
        "CurrentSignature",
    }) do
        if not pending[field] or tostring(pending[field]) == "" then
            errors[#errors + 1] = "pending." .. field .. " missing"
        end
    end

    if pending.Staged and not file_exists(pending.Staged) then
        errors[#errors + 1] = "staged restore file missing"
    end

    if pending.PreRestoreGuard and not file_exists(pending.PreRestoreGuard) then
        errors[#errors + 1] = "pre-restore guard missing"
    end

    if pending.Staged and file_exists(pending.Staged) and pending.ExpectedHash then
        local staged_hash = content_hash(pending.Staged)
        if tostring(staged_hash) ~= tostring(pending.ExpectedHash) then
            errors[#errors + 1] = "staged restore hash mismatch"
        end
    end

    return #errors == 0, errors
end

local function rearm_pending_restore_hidden(reason)
    if restore_watcher_launched_this_session then
        return true, "already_launched"
    end

    local pending = pending_restore_info()
    local valid, errors = pending_restore_recovery_valid(pending)

    if not valid then
        mod:error(
            "[ModShrine] Pending Safe Restore recovery rejected (%d error(s)).",
            #errors
        )
        for i = 1, math.min(#errors, 20) do
            mod:error("[ModShrine] Pending recovery: %s", tostring(errors[i]))
        end
        notify(
            "ModShrine: an old pending restore could not be safely recovered. " ..
            "Nothing will be applied; use Cancel Restore to clear it."
        )
        return false, "invalid_pending"
    end

    -- If the expected restore is already live, synthesize a SUCCESS result so
    -- normal verification/cleanup can finish without running another watcher.
    local live_hash = content_hash(pending.Live)
    if tostring(live_hash) == tostring(pending.ExpectedHash) then
        write_simple_record(restore_result_path(), {
            { "Status", "SUCCESS" },
            { "Applied", "already_live_recovery" },
            { "Staged", pending.Staged },
            { "Live", pending.Live },
        })
        mod:info("[ModShrine] Pending restore recovery found expected config already live.")
        return true, "already_live"
    end

    -- Never re-arm an old restore over settings/roster that changed afterward.
    local current, current_error = build_current_state()
    if not current then
        mod:error(
            "[ModShrine] Pending restore recovery could not analyze current state: %s",
            tostring(current_error)
        )
        return false, "current_state_failed"
    end

    if tostring(current.signature) ~= tostring(pending.CurrentSignature) then
        local _ok, newly_requested =
            cancel_pending_restore("recovery detected changed settings/roster")

        if newly_requested then
            notify(
                "ModShrine: old pending restore was canceled because your settings/roster changed after it was staged."
            )
        end
        return false, "state_changed"
    end

    remove_file(restore_cancel_path())
    pending_restore_cancel_requested = false

    if not write_restore_watcher_paths(pending.Staged, pending.Live) then
        mod:error("[ModShrine] Could not rebuild pending restore watcher.")
        return false, "watcher_write_failed"
    end

    if not launch_restore_watcher_hidden() then
        mod:error("[ModShrine] Could not relaunch pending restore watcher hidden.")
        return false, "watcher_launch_failed"
    end

    mod:info(
        "[ModShrine] Pending Safe Restore recovered and re-armed invisibly (%s).",
        tostring(reason or "unknown")
    )
    notify(
        "ModShrine: recovered the pending Safe Restore and re-armed it invisibly. " ..
        "Keep playing; it will apply only after you exit Darktide."
    )

    return true, "rearmed"
end

local function process_pending_restore_recovery(now)
    if pending_restore_recovery_attempted
        or not pending_restore_recovery_at
        or now < pending_restore_recovery_at
        or not archive_processing_allowed
    then
        return
    end

    pending_restore_recovery_at = nil
    pending_restore_recovery_attempted = true

    if file_exists(restore_result_path()) then
        return
    end

    if not pending_restore_is_armed() then
        return
    end

    if file_exists(restore_cancel_path()) then
        pending_cancel_cleanup_at = now + 3.0
        return
    end

    rearm_pending_restore_hidden("startup_or_hub_recovery")
end

local function process_pending_cancel_cleanup(now)
    if not pending_cancel_cleanup_at or now < pending_cancel_cleanup_at then
        return
    end

    pending_cancel_cleanup_at = nil

    -- Healthy watcher wrote a result. Let normal result handling consume it.
    if file_exists(restore_result_path()) then
        return
    end

    -- Dead/orphaned watcher: clear only the ARMED control files.
    -- Preserve staged candidate + pre-restore guard as forensic/safety evidence.
    remove_file(restore_pending_path())
    remove_file(restore_watcher_path())
    remove_file(restore_launcher_path())
    remove_file(restore_cancel_path())

    restore_watcher_launched_this_session = false
    pending_restore_cancel_requested = false

    mod:warning("[ModShrine] Cleared stale pending restore after cancellation grace period.")
    notify(
        "ModShrine: stale pending restore cleared. The staged file and pre-restore backup were preserved."
    )
end

local function check_restore_result_unsafe()
    if restore_result_checked then
        return
    end

    local result = read_metadata(restore_result_path())
    if not result or not result.Status then
        return
    end

    restore_result_checked = true

    local pending = pending_restore_info()
    local status = tostring(result.Status)
    local live = source_path()
    local actual_hash = live and content_hash(live) or nil
    local expected_hash = pending and pending.ExpectedHash or nil
    local verified =
        status == "SUCCESS"
        and expected_hash ~= nil
        and tostring(actual_hash) == tostring(expected_hash)

    ensure_dir(exports_path())
    write_simple_record(exports_path() .. "\\LastRestoreResult.txt", {
        { "Status", status },
        { "ExpectedHash", expected_hash or "" },
        { "ActualHash", actual_hash or "" },
        { "VerifiedOnLaunch", verified and "true" or "false" },
        { "ResultApplied", result.Applied or "" },
        { "Staged", result.Staged or "" },
        { "Live", result.Live or "" },
    })

    if status == "SUCCESS" and verified then
        notify("ModShrine: Safe Restore applied after exit and verified on this launch.")
        mod:info("[ModShrine] Offline Safe Restore verified. hash=%s", tostring(actual_hash))
        mod:info(
            "[ModShrine][RC] RESTORE_RESULT status=SUCCESS verified=true expected=%s actual=%s",
            tostring(expected_hash),
            tostring(actual_hash)
        )
    elseif status == "SUCCESS" then
        mod:info(
            "[ModShrine][RC] RESTORE_RESULT status=SUCCESS verified=false expected=%s actual=%s",
            tostring(expected_hash),
            tostring(actual_hash)
        )
        notify("ModShrine: restore copy completed, but launch verification did not match the staged hash. Check the vault.")
        mod:error(
            "[ModShrine] Restore launch verification mismatch. expected=%s actual=%s",
            tostring(expected_hash),
            tostring(actual_hash)
        )
    elseif status == "CANCELED" then
        mod:info("[ModShrine][RC] RESTORE_RESULT status=CANCELED verified=false")
        notify("ModShrine: pending Safe Restore was canceled. Live settings were not replaced.")
        mod:info("[ModShrine] Pending Safe Restore canceled.")
    else
        mod:info("[ModShrine][RC] RESTORE_RESULT status=%s verified=false", tostring(status))
        notify("ModShrine: Safe Restore failed to apply after exit. Your pre-restore backup remains protected.")
        mod:error("[ModShrine] Offline Safe Restore watcher reported FAILED.")
    end

    remove_file(restore_result_path())
    remove_file(restore_pending_path())
    remove_file(restore_cancel_path())
    remove_file(restore_watcher_path())
    remove_file(restore_launcher_path())
    restore_watcher_launched_this_session = false
    pending_restore_cancel_requested = false
end


local function check_restore_result()
    local ok, err = pcall(check_restore_result_unsafe)

    if ok then
        return
    end

    -- Do not retry every frame and spam/crash if result parsing itself is bad.
    restore_result_checked = true

    mod:error(
        "[ModShrine] Restore-result verification failed safely: %s",
        tostring(err)
    )
    notify(
        "ModShrine: restore-result verification hit an internal error. " ..
        "The vault files were left in place for inspection."
    )
end

local function process_restore_job_unsafe(now)
    if not restore_job or now < restore_next_at then
        return
    end

    if not archive_processing_allowed then
        return
    end

    local job = restore_job
    local phase_started = perf_now()

    if job.phase == "prepare" then
        local current, current_error = build_current_state()
        local target, target_error = target_state_for_preview()

        if not current or not target then
            mod:error(
                "[ModShrine] Safe Restore prepare failed. current=%s target=%s",
                tostring(current_error),
                tostring(target_error)
            )
            notify("ModShrine: Safe Restore could not analyze the current/backup state.")
            restore_job = nil
            return
        end

        local plan = build_safe_restore_maps(current, target)
        local plan_ok, plan_errors = validate_safe_restore_plan(current, target, plan)

        if not plan_ok then
            mod:error(
                "[ModShrine] Safe Restore rejected invalid plan (%d error(s)).",
                #plan_errors
            )
            for i = 1, math.min(#plan_errors, 20) do
                mod:error("[ModShrine] Restore plan validation: %s", tostring(plan_errors[i]))
            end
            notify("ModShrine: Safe Restore plan validation failed. Live settings remain untouched.")
            restore_job = nil
            return
        end

        local merged_text, merge_error = build_safe_restore_text(current, target, plan)

        if not merged_text then
            mod:error("[ModShrine] Safe Restore merge failed: %s", tostring(merge_error))
            notify("ModShrine: Safe Restore merge failed. Nothing was changed.")
            restore_job = nil
            return
        end

        if plan.setting_changes == 0 then
            notify("ModShrine: Safe Restore found no saved setting values that need changing.")
            mod:info("[ModShrine] Safe Restore aborted: no setting changes required.")
            restore_job = nil
            return
        end

        local ok, errors, merged_analysis =
            verify_safe_restore_text(current, target, plan, merged_text)

        if not ok then
            mod:error("[ModShrine] Safe Restore in-memory validation failed (%d errors).", #errors)
            for i = 1, math.min(#errors, 20) do
                mod:error("[ModShrine] Restore validation: %s", tostring(errors[i]))
            end
            notify("ModShrine: Safe Restore validation failed. Live settings remain untouched.")
            restore_job = nil
            return
        end

        job.current = current
        job.target = target
        job.plan = plan
        job.merged_text = merged_text
        job.merged_analysis = merged_analysis
        job.timestamp = stamp()
        job.guard_path =
            snapshots_path() .. "\\user_settings_" .. job.timestamp .. "_pre_restore.config"
        job.staged_path =
            vault_root() .. "\\RESTORE_STAGED_" .. job.timestamp .. ".config"
        job.expected_hash = hash_string(merged_text)
        job.phase = "guard_write"

        perf_track(
            job,
            "restore_prepare",
            phase_started,
            string.format(
                "mods=%d setting_changes=%d preserved_newer=%d",
                map_count(plan.matching),
                plan.setting_changes,
                plan.current_only_preserved
            )
        )

    elseif job.phase == "guard_write" then
        ensure_dir(vault_root())
        ensure_dir(snapshots_path())
        ensure_dir(exports_path())

        if not write_all(job.guard_path, job.current.text) then
            notify("ModShrine: pre-restore emergency backup could not be written. Restore canceled.")
            mod:error("[ModShrine] Could not write pre-restore guard: %s", tostring(job.guard_path))
            restore_job = nil
            return
        end

        job.phase = "guard_verify"
        perf_track(job, "restore_guard_write", phase_started)

    elseif job.phase == "guard_verify" then
        local guard = read_all(job.guard_path)

        if not guard
            or #guard ~= #job.current.text
            or hash_string(guard) ~= hash_string(job.current.text)
        then
            notify("ModShrine: pre-restore emergency backup failed verification. Restore canceled.")
            mod:error("[ModShrine] Pre-restore guard verification failed.")
            restore_job = nil
            return
        end

        write_simple_record(pre_restore_metadata_path(), {
            { "Version", VERSION },
            { "Timestamp", job.timestamp },
            { "Snapshot", job.guard_path },
            { "Bytes", #guard },
            { "RawHash", hash_string(guard) },
            { "ConfiguredMods", job.current.analysis.mod_count },
            { "MeaningfulSettings", job.current.analysis.setting_count },
            { "RestoreSource", job.target.meta.Snapshot },
        })

        job.phase = "stage_write"
        perf_track(job, "restore_guard_verify", phase_started)

    elseif job.phase == "stage_write" then
        if not write_all(job.staged_path, job.merged_text) then
            notify("ModShrine: merged restore file could not be staged. Live settings remain untouched.")
            mod:error("[ModShrine] Could not write staged restore file.")
            restore_job = nil
            return
        end

        job.phase = "stage_verify"
        perf_track(job, "restore_stage_write", phase_started)

    elseif job.phase == "stage_verify" then
        local staged = read_all(job.staged_path)
        local ok =
            staged
            and #staged == #job.merged_text
            and hash_string(staged) == job.expected_hash

        if ok then
            local semantic_ok, errors =
                verify_safe_restore_text(job.current, job.target, job.plan, staged)
            ok = semantic_ok

            if not semantic_ok then
                for i = 1, math.min(#errors, 20) do
                    mod:error("[ModShrine] Staged restore validation: %s", tostring(errors[i]))
                end
            end
        end

        if not ok then
            notify("ModShrine: staged restore failed verification. Live settings remain untouched.")
            mod:error("[ModShrine] Staged restore verification failed.")
            restore_job = nil
            return
        end

        job.phase = "plan"
        perf_track(job, "restore_stage_verify", phase_started)

    elseif job.phase == "plan" then
        job.plan_path = write_restore_plan_file(job)

        write_simple_record(restore_pending_path(), {
            { "Version", VERSION },
            { "Timestamp", job.timestamp },
            { "Status", "ARMED" },
            { "RestoreSource", job.target.meta.Snapshot },
            { "RestoreSourceKind", job.target.source_kind },
            { "PreRestoreGuard", job.guard_path },
            { "Staged", job.staged_path },
            { "Live", job.current.source },
            { "ExpectedHash", job.expected_hash },
            { "CurrentSignature", job.current.signature },
            { "MatchingMods", map_count(job.plan.matching) },
            { "SettingChanges", job.plan.setting_changes },
            { "PreservedCurrentOnlySettings", job.plan.current_only_preserved },
            { "Plan", job.plan_path or "" },
        })

        remove_file(restore_result_path())
        remove_file(restore_cancel_path())
        pending_restore_cancel_requested = false

        if not write_restore_watcher(job) then
            remove_file(restore_pending_path())
            notify("ModShrine: restore watcher could not be created. Live settings remain untouched.")
            mod:error("[ModShrine] Could not write restore watcher.")
            restore_job = nil
            return
        end

        job.phase = "launch"
        perf_track(job, "restore_plan_write", phase_started)

    elseif job.phase == "launch" then
        local script = restore_watcher_path()

        if not _os or not _os.execute or not script then
            remove_file(restore_pending_path())
            notify("ModShrine: restore watcher could not be launched. Live settings remain untouched.")
            mod:error("[ModShrine] OS launch unavailable for restore watcher.")
            restore_job = nil
            return
        end

        if not launch_restore_watcher_hidden() then
            remove_file(restore_pending_path())
            notify("ModShrine: hidden restore watcher could not be launched. Live settings remain untouched.")
            mod:error("[ModShrine] Hidden restore watcher launch failed.")
            restore_job = nil
            return
        end

        perf_track(job, "restore_watcher_launch", phase_started)
        mod:info(
            "[ModShrine][PERF] restore_work_sum=%.2fms | max_phase=%.2fms | wall_elapsed=%.2fms",
            job.work_sum_ms or 0,
            job.max_phase_ms or 0,
            math.max((wall_now() - job.wall_started_at) * 1000, 0)
        )
        mod:info(
            "[ModShrine] Safe Restore ARMED: %d mod(s), %d setting value(s), %d newer/current-only setting(s) preserved.",
            map_count(job.plan.matching),
            job.plan.setting_changes,
            job.plan.current_only_preserved
        )
        mod:info(
            "[ModShrine][RC] RESTORE_ARMED source_id=%s source=%s mods=%d changes=%d preserved_newer=%d hidden_watcher=true",
            tostring(job.target.source_id or "legacy"),
            tostring(job.target.source_kind),
            map_count(job.plan.matching),
            job.plan.setting_changes,
            job.plan.current_only_preserved
        )

        notify(
            string.format(
                "ModShrine: Safe Restore staged for %d setting change(s). EXIT Darktide completely, then relaunch to apply and verify.",
                job.plan.setting_changes
            )
        )

        restore_job = nil
        return
    end

    restore_next_at = now + RESTORE_STEP_SECONDS
end


local function process_restore_job(now)
    if not restore_job then
        return
    end

    local ok, err = pcall(process_restore_job_unsafe, now)

    if ok then
        return
    end

    local failed_phase = restore_job and restore_job.phase or "unknown"

    mod:error(
        "[ModShrine] Safe Restore staging failed safely in phase '%s': %s",
        tostring(failed_phase),
        tostring(err)
    )

    -- Do not arm/apply anything after an unexpected staging exception.
    -- If a pending record was created before the exception, request cancellation
    -- so the detached watcher cannot replace the live config.
    if file_exists(restore_pending_path()) then
        write_all(
            restore_cancel_path(),
            "Cancel requested: restore staging exception in phase " ..
            tostring(failed_phase) .. "\n"
        )
    end

    restore_job = nil
    restore_next_at = wall_now() + RESTORE_STEP_SECONDS

    notify(
        "ModShrine: Safe Restore hit an internal error and was canceled safely. " ..
        "Your live settings were not intentionally replaced; you can keep playing and send the console log later."
    )
end

function mod.ui_safe_restore()
    check_restore_result()

    if not archive_processing_allowed then
        notify("ModShrine: Safe Restore can only be staged from the Mourningstar or main menu.")
        return
    end

    if restore_job then
        notify("ModShrine: Safe Restore staging is already in progress.")
        return
    end

    if pending_restore_is_armed() then
        local ok, reason = rearm_pending_restore_hidden("safe_restore_button")

        if ok then
            if reason == "already_launched" then
                notify("ModShrine: Safe Restore is already armed invisibly. Keep playing and exit normally when finished.")
            elseif reason == "already_live" then
                notify("ModShrine: the pending restore already matches the live config; verification will finish automatically.")
            end
        end

        return
    end

    if snapshot_job or #snapshot_queue > 0 or known_good_job then
        notify("ModShrine: wait for the current backup/Known Good operation to finish first.")
        return
    end

    if not known_good_info() then
        mod._clear_restore_preview_unlock("known_good_missing")
        notify(
            "ModShrine: Step 2 is required first. Mark a trusted Known Good backup before restoring."
        )
        return
    end

    local current, current_error = build_current_state()
    local target, target_error = target_state_for_preview()

    if not current or not target then
        mod._clear_restore_preview_unlock("stage_validation_unavailable")
        mod:error(
            "[ModShrine] Guided restore validation unavailable. current=%s target=%s",
            tostring(current_error),
            tostring(target_error)
        )
        notify("ModShrine: restore validation is unavailable. Nothing was staged.")
        return
    end

    if not restore_preview_matches(current, target) then
        mod._clear_restore_preview_unlock("preview_stale_or_missing")
        notify(
            "ModShrine: Step 3 is required first. Preview the current restore plan before staging. If settings changed after Preview, preview again."
        )
        return
    end

    restore_job = {
        phase = "prepare",
        wall_started_at = wall_now(),
        work_sum_ms = 0,
        max_phase_ms = 0,
    }
    restore_next_at = wall_now()
    mod._clear_restore_preview_unlock("step4_started")

    mod:info("[ModShrine][UX] STEP4_STARTED guided_preview_gate=passed")
    mod:info("[ModShrine] Safe Restore staging queued.")
    notify("ModShrine: Safe Restore staging started. Live settings will NOT be overwritten while Darktide is running.")
end

function mod.ui_cancel_pending_restore()
    if restore_job then
        restore_job = nil
        notify("ModShrine: in-progress Safe Restore staging canceled before arming.")
        mod:info("[ModShrine] In-progress Safe Restore staging canceled.")
        return
    end

    local canceled, newly_requested = cancel_pending_restore("user button")

    if canceled and newly_requested then
        notify("ModShrine: pending Safe Restore cancellation requested.")
    elseif canceled then
        notify("ModShrine: Safe Restore cancellation is already pending.")
    else
        notify("ModShrine: there is no armed Safe Restore to cancel.")
    end
end

function mod.ui_create_backup()
    if not archive_processing_allowed then
        notify("ModShrine: manual backup is paused during missions/loading. Use it in the Mourningstar or main menu.")
        return
    end

    local queued = create_snapshot("manual", "manual_button", false)
    if queued then
        notify("ModShrine: manual backup queued.")
    end
end

local function known_good_fail(message, log_message)
    if log_message then
        mod:error("[ModShrine] Known Good job failed: %s", tostring(log_message))
    end

    notify(message or "ModShrine: Known Good protection failed.")
    known_good_job = nil
end

local function process_known_good_job(now)
    local job = known_good_job
    if not job or not archive_processing_allowed or now < known_good_next_at then
        return
    end

    local phase_started = perf_now()

    if job.phase == "prepare" then
        ensure_dir(vault_root())
        ensure_dir(known_good_path())
        job.phase = "read"
        perf_track(job, "known_good_prepare", phase_started)

    elseif job.phase == "read" then
        job.source_data = read_all(job.latest.Snapshot)
        if not job.source_data then
            known_good_fail("ModShrine: Known Good source could not be read.", "source_read_failed")
            return
        end

        job.source_bytes = #job.source_data
        job.source_hash = hash_string(job.source_data)
        job.phase = "write"
        perf_track(job, "known_good_read", phase_started, string.format("bytes=%d", job.source_bytes))

    elseif job.phase == "write" then
        if not write_all(job.destination, job.source_data) then
            known_good_fail("ModShrine: Known Good copy could not be written.", "copy_write_failed")
            return
        end

        job.phase = "verify"
        perf_track(job, "known_good_write", phase_started)

    elseif job.phase == "verify" then
        local copy_data = read_all(job.destination)
        local copy_bytes = copy_data and #copy_data or nil
        local copy_hash = copy_data and hash_string(copy_data) or nil

        if not copy_bytes
            or job.source_bytes ~= copy_bytes
            or not job.source_hash
            or job.source_hash ~= copy_hash
        then
            known_good_fail("ModShrine: Known Good copy failed verification.", "verification_failed")
            return
        end

        job.copy_bytes = copy_bytes
        job.copy_hash = copy_hash
        job.source_data = nil
        job.phase = "manifest"
        perf_track(job, "known_good_verify", phase_started)

    elseif job.phase == "manifest" then
        job.manifest = ""

        local source_tsv = read_all(snapshot_manifest_tsv_path(job.latest.Snapshot))
        local source_txt = read_all(snapshot_manifest_txt_path(job.latest.Snapshot))

        -- Backward compatibility with v0.3.0-v0.3.2 _assets folders.
        if not source_tsv and not source_txt then
            local source_assets = snapshot_assets_path(job.latest.Snapshot)
            source_tsv = source_assets and read_all(source_assets .. "\\manifest.tsv") or nil
            source_txt = source_assets and read_all(source_assets .. "\\manifest.txt") or nil
        end

        if source_tsv then
            local destination_tsv = snapshot_manifest_tsv_path(job.destination)
            write_all(destination_tsv, source_tsv)
            job.manifest = destination_tsv
        end

        if source_txt then
            write_all(snapshot_manifest_txt_path(job.destination), source_txt)
        end

        job.phase = "metadata"
        perf_track(job, "known_good_manifest", phase_started)

    elseif job.phase == "metadata" then
        write_metadata(known_good_metadata_path(), {
            Version = VERSION,
            Timestamp = job.timestamp,
            Kind = "known_good",
            Reason = "marked_from_latest",
            Source = job.latest.Snapshot,
            Snapshot = job.destination,
            Bytes = job.copy_bytes,
            RawHash = job.copy_hash,
            SettingsHash = job.latest.SettingsHash,
            RosterHash = job.latest.RosterHash,
            Signature = job.latest.Signature,
            SettingsCount = job.latest.SettingsCount,
            ConfiguredMods = job.latest.ConfiguredMods,
            InstalledMods = job.latest.InstalledMods,
            EnabledMods = job.latest.EnabledMods,
            Manifest = job.manifest,
        })

        perf_track(job, "known_good_metadata", phase_started)
        mod:info(
            "[ModShrine][PERF] known_good_work_sum=%.2fms | max_phase=%.2fms | wall_elapsed=%.2fms | staged",
            job.work_sum_ms or 0,
            job.max_phase_ms or 0,
            math.max((wall_now() - job.wall_started_at) * 1000, 0)
        )
        mod:info("[ModShrine] Known Good protected via staged verification: %s", job.destination)
        notify("ModShrine: Step 2 complete. Known Good is protected. Exit Mod Options to the Mourningstar, then reopen ModShrine to continue to Step 3.")
        mod._clear_restore_preview_unlock("known_good_replaced")
        mod._clear_preview_target_cache("known_good_replaced")
        known_good_job = nil
        return
    end

    known_good_next_at = now + KNOWN_GOOD_STEP_SECONDS
end

function mod.ui_mark_known_good()
    if known_good_job then
        notify("ModShrine: Known Good protection is already in progress.")
        return
    end

    local latest = latest_info()

    if not latest then
        notify("ModShrine: create a verified backup first.")
        return
    end

    local dir = known_good_path()
    if not dir then
        notify("ModShrine: Known Good vault path is unavailable.")
        return
    end

    local timestamp = latest.Timestamp or stamp()
    known_good_job = {
        latest = latest,
        timestamp = timestamp,
        destination = dir .. "\\known_good_" .. timestamp .. ".config",
        phase = "prepare",
        wall_started_at = wall_now(),
        work_sum_ms = 0,
        max_phase_ms = 0,
        manifest = "",
    }
    known_good_next_at = wall_now()

    mod:info("[ModShrine] Known Good protection queued as staged job.")
    notify("ModShrine: Known Good protection queued.")
end

function mod.ui_open_backup_folder()
    local root = vault_root()
    if not root then
        notify("ModShrine: vault path is unavailable.")
        return
    end

    ensure_dir(root)
    ensure_dir(snapshots_path())
    ensure_dir(persistent_archive_path())
    ensure_dir(exports_path())

    if _os and _os.execute then
        _os.execute('start "" explorer.exe ' .. q(root) .. ' > nul 2>&1')
        mod:info("[ModShrine] Opened vault: %s", root)
    end
end

function mod.ui_export_roster()
    write_current_roster_export()
end

function mod.ui_preview_safe_restore()
    if not archive_processing_allowed then
        notify("ModShrine: restore preview is only available from the Mourningstar or main menu.")
        return
    end

    local ok, result = pcall(write_safe_restore_preview)

    if not ok then
        mod:error("[ModShrine] Safe Restore Preview failed safely: %s", tostring(result))
        notify("ModShrine: Safe Restore Preview hit an internal error. Nothing was modified; check the console log.")
        return
    end

    return result
end

function mod.ui_check_status()
    local state, err = build_current_state()

    if not state then
        notify("ModShrine: status unavailable.")
        mod:error("[ModShrine] Status state error: %s", tostring(err))
        return
    end

    local known = known_good_info()

    mod:info("[ModShrine] Version: %s", VERSION)
    mod:info("[ModShrine] Source: %s", state.source)
    mod:info("[ModShrine] Meaningful settings hash: %s", tostring(state.analysis.hash))
    mod:info("[ModShrine] Roster hash: %s", tostring(state.roster_hash))
    mod:info("[ModShrine] Signature: %s", tostring(state.signature))
    mod:info("[ModShrine] Configured mods/settings: %d / %d", state.analysis.mod_count, state.analysis.setting_count)
    mod:info("[ModShrine] Installed/enabled: %d / %d", map_count(state.roster.installed), map_count(state.roster.enabled))
    mod:info("[ModShrine] Missing/new/returned/retired: %d / %d / %d / %d",
        map_count(state.missing_active),
        map_count(state.new_mods),
        map_count(state.returned_mods),
        map_count(state.retired)
    )
    mod:info("[ModShrine] Changed mods/settings vs latest: %d / %d",
        map_count(state.changed_mods),
        state.changed_settings
    )
    mod:info("[ModShrine] Inventory anomaly=%s Settings anomaly=%s",
        tostring(state.inventory_anomaly),
        tostring(state.settings_anomaly)
    )
    local restore_source =
        known and "Known Good" or (state.latest and "Latest Verified" or "none")

    mod:info("[ModShrine] Known Good: %s", known and tostring(known.Snapshot) or "none")
    mod:info("[ModShrine] Restore source: %s", restore_source)

    notify(
        string.format(
            "ModShrine: %d installed, %d enabled | %d missing, %d new, %d returned, %d retired.",
            map_count(state.roster.installed),
            map_count(state.roster.enabled),
            map_count(state.missing_active),
            map_count(state.new_mods),
            map_count(state.returned_mods),
            map_count(state.retired)
        ) .. " Restore source: " .. restore_source .. "."
    )
end

maybe_alert_missing = function(state)
    if not state or map_count(state.missing_active) == 0 then
        return
    end

    local names = sorted_names_from_map(state.missing_active)
    local signature = hash_string(table.concat(names, "\n"))
    local prior = trim(read_all(missing_alert_path()) or "")

    if prior == signature then
        return
    end

    write_all(missing_alert_path(), signature .. "\n")

    if state.inventory_anomaly then
        notify(
            string.format(
                "ModShrine: large mod inventory drop detected. %d previously seen mods are missing; archived settings preserved.",
                #names
            )
        )
    else
        notify(
            string.format(
                "ModShrine: %d previously seen mod(s) are missing. Their archived settings are preserved.",
                #names
            )
        )
    end
end

local function queue_auto_backup(reason)
    if mod:get("auto_backup_enabled") ~= true then
        return
    end

    pending_auto_backup_at = wall_now() + AUTO_DELAY_SECONDS
    mod:info("[ModShrine] Queued changed-state check: %s", tostring(reason))
end

local function arm_startup_scan(reason)
    if startup_check_done or cached_installed_mods ~= nil then
        return
    end

    local target = wall_now() + STARTUP_SAFE_DELAY_SECONDS
    if not startup_scan_at or target < startup_scan_at then
        startup_scan_at = target
    end

    mod:info("[ModShrine] Startup protection armed from stable state (%s).", tostring(reason))
end

-- Secondary archive work is allowed in menus and in a fully initialized
-- Mourningstar, but never during missions, loading, or GameplayInitStep*.
-- StateGameplay begins several seconds before hub initialization is complete,
-- so hub work waits for GameplayStateRun instead of racing the loader.
function mod._enable_hub_processing(reason)
    if current_mission_name ~= "hub_ship" then
        return
    end

    archive_processing_allowed = true
    mod._hub_processing_pending = false
    mod._hub_processing_fallback_at = nil
    arm_startup_scan("hub_ship")

    if not last_live_settings_hash then
        live_baseline_at = wall_now() + LIVE_BASELINE_DELAY_SECONDS
    end

    if not pending_restore_recovery_attempted and pending_restore_is_armed() then
        pending_restore_recovery_at = wall_now() + 2.0
    end

    mod:info(
        "[ModShrine] Mourningstar safe state confirmed (%s); secondary archive work allowed.",
        tostring(reason or "GameplayStateRun")
    )
end

if CLASS and CLASS.StateLoading and CLASS.StateLoading.on_enter then
    mod:hook_safe(CLASS.StateLoading, "on_enter", function()
        archive_processing_allowed = false
        mod._hub_processing_pending = false
        mod._hub_processing_fallback_at = nil
        current_mission_name = "loading"
        mod:info("[ModShrine] Level loading entered; secondary archive work paused.")
    end)
end

if CLASS and CLASS.StateMainMenu and CLASS.StateMainMenu.on_enter then
    mod:hook_safe(CLASS.StateMainMenu, "on_enter", function()
        archive_processing_allowed = true
        mod._hub_processing_pending = false
        mod._hub_processing_fallback_at = nil
        current_mission_name = nil
        arm_startup_scan("main_menu")
        if not last_live_settings_hash then
            live_baseline_at = wall_now() + LIVE_BASELINE_DELAY_SECONDS
        end
        if not pending_restore_recovery_attempted and pending_restore_is_armed() then
            pending_restore_recovery_at = wall_now() + 2.0
        end
        mod:info("[ModShrine] Main menu entered; secondary archive work allowed.")
    end)
end

if CLASS and CLASS.StateGameplay and CLASS.StateGameplay.on_enter and CLASS.StateGameplay.on_exit then
    mod:hook_safe(CLASS.StateGameplay, "on_enter", function(_self, _parent, params, _creation_context)
        local mission_name = params and params.mission_name or nil
        current_mission_name = mission_name

        if mission_name == "hub_ship" then
            archive_processing_allowed = false
            mod._hub_processing_pending = true

            if mod._hub_run_hook_available then
                -- Fail closed while Darktide is still inside GameplayInitStep*.
                -- When the hook exists, GameplayStateRun is the authoritative
                -- signal and there is no timer racing normal slow hub loads.
                mod._hub_processing_fallback_at = nil
                mod:info(
                    "[ModShrine] Mourningstar detected (hub_ship); waiting for GameplayStateRun before secondary archive work."
                )
            else
                -- Compatibility path only. If a future game build no longer
                -- exposes GameplayStateRun.on_enter, wait generously before
                -- allowing non-critical hub maintenance.
                mod._hub_processing_fallback_at = wall_now() + mod._hub_safe_fallback_seconds
                mod:info(
                    "[ModShrine] Mourningstar detected (hub_ship); GameplayStateRun hook unavailable, delayed safety fallback armed."
                )
            end
        else
            archive_processing_allowed = false
            mod._hub_processing_pending = false
            mod._hub_processing_fallback_at = nil
            mod:info(
                "[ModShrine] Mission gameplay detected (%s); secondary archive work paused.",
                tostring(mission_name or "unknown")
            )
        end
    end)

    mod:hook_safe(CLASS.StateGameplay, "on_exit", function()
        archive_processing_allowed = false
        mod._hub_processing_pending = false
        mod._hub_processing_fallback_at = nil
        mod:info(
            "[ModShrine] Leaving StateGameplay (%s); secondary archive work paused for transition.",
            tostring(current_mission_name or "unknown")
        )
        current_mission_name = nil
    end)
end

if CLASS and CLASS.GameplayStateRun and CLASS.GameplayStateRun.on_enter then
    mod._hub_run_hook_available = true
    mod:hook_safe(CLASS.GameplayStateRun, "on_enter", function()
        if mod._hub_processing_pending and current_mission_name == "hub_ship" then
            mod._enable_hub_processing("GameplayStateRun")
        end
    end)
else
    mod._hub_run_hook_available = false
    mod:info(
        "[ModShrine] GameplayStateRun hook unavailable; Mourningstar work will use the delayed compatibility fallback."
    )
end

if Managers and Managers.ui and Managers.ui.close_view then
    mod:hook_safe(Managers.ui, "close_view", function(_self, view_name)
        if view_name == "dmf_options_view" then
            local live_hash, live_changed, disk_settings_hash =
                probe_live_dmf_settings("mod_options_closed")
            local flush_ok = force_dmf_settings_flush("mod_options_closed")

            if live_changed then
                queue_auto_backup("mod_options_closed_live_change")
            else
                local can_skip, fastpath_reason =
                    mod._can_skip_unchanged_menu_snapshot(
                        live_hash,
                        disk_settings_hash
                    )

                if can_skip then
                    -- The v0.5.4 guard already proved live settings, semantic
                    -- disk state, roster, and latest snapshot identity unchanged.
                    -- DMF may still rewrite harmless menu/noise bytes during its
                    -- required save, so refresh only the UI cache's raw fingerprint
                    -- after that verified unchanged flush instead of forcing a
                    -- false WORKFLOW_CACHE disk_changed miss on reopen.
                    if flush_ok then
                        mod._refresh_workflow_cache_raw_hash(
                            "verified_unchanged_mod_options_close"
                        )
                    end

                    mod:info(
                        "[ModShrine][PERF] NO_CHANGE_FASTPATH skipped=snapshot_queue reason=%s",
                        tostring(fastpath_reason)
                    )
                else
                    mod:info(
                        "[ModShrine][PERF] NO_CHANGE_FASTPATH fallback=full_check reason=%s",
                        tostring(fastpath_reason)
                    )
                    queue_auto_backup("mod_options_closed")
                end
            end
        end
    end)
else
    mod:warning("[ModShrine] Could not hook Managers.ui.close_view; menu-close automatic checks unavailable.")
end

function mod.update(dt)
    local now = wall_now()

    if mod._hub_processing_pending
        and current_mission_name == "hub_ship"
        and not mod._hub_run_hook_available
        and mod._hub_processing_fallback_at
        and now >= mod._hub_processing_fallback_at
    then
        mod:info(
            "[ModShrine] GameplayStateRun hook unavailable; enabling Mourningstar work via delayed compatibility fallback."
        )
        mod._enable_hub_processing("compatibility fallback")
    end

    check_restore_result()
    process_pending_restore_recovery(now)
    process_pending_cancel_cleanup(now)

    if live_baseline_at and now >= live_baseline_at then
        if archive_processing_allowed then
            live_baseline_at = nil
            refresh_live_settings_baseline("stable_state")
        else
            live_baseline_at = now + 0.50
        end
    end

    if startup_scan_at and now >= startup_scan_at then
        if archive_processing_allowed then
            startup_scan_at = nil
            request_installed_mod_scan()

            if not startup_check_done then
                startup_check_at = now + STARTUP_STATE_DELAY_AFTER_SCAN_SECONDS
            end
        else
            startup_scan_at = now + 1.0
        end
    end

    -- All ModShrine work that can wait is split into small hub/menu-safe stages.
    process_restore_job(now)
    process_known_good_job(now)
    process_snapshot_job(now)
    process_one_archive_item(now)

    if startup_check_at and now >= startup_check_at and not startup_check_done then
        if not archive_processing_allowed then
            startup_check_at = now + 0.50
        else
            startup_check_at = nil
            startup_check_done = true

            if mod:get("auto_backup_enabled") == true then
                local queued, reason = create_snapshot("auto", "startup_state_check", false)
                mod:info(
                    "[ModShrine][RC] STARTUP_CHECK queued=%s reason=%s",
                    tostring(queued),
                    tostring(reason)
                )
                if not queued and reason == "unsafe_state" then
                    startup_check_done = false
                    startup_check_at = now + 0.50
                end
            end
        end
    end

    if pending_auto_backup_at and now >= pending_auto_backup_at then
        if not archive_processing_allowed then
            pending_auto_backup_at = now + 0.50
        else
            pending_auto_backup_at = nil
            -- The Mod Options close hook already flushes DMF immediately, and
            -- every snapshot job performs its own final safety flush before
            -- reading user_settings.config. Avoid a third synchronous save in
            -- between those two safety points.
            local queued, reason = create_snapshot(
                "auto",
                pending_live_settings_hash and "mod_options_closed_live_change" or "mod_options_closed",
                false
            )

            if not queued and reason == "unsafe_state" then
                pending_auto_backup_at = now + 0.50
            end
        end
    end

    -- Retention reconciliation is lowest-priority maintenance. It runs only
    -- after snapshot/restore/Known Good scheduling for this frame is settled.
    mod._process_retention_reconcile(now)
end

local function clear_custom_modshrine_rows(settings)
    for i = #settings, 1, -1 do
        local entry = settings[i]

        if entry
            and entry.custom == true
            and entry.mod_name == "mod_shrine"
        then
            table.remove(settings, i)
        end
    end
end

local function guided_workflow_state()
    local result = {
        state = nil,
        state_error = nil,
        known = known_good_info(),
        pending = pending_restore_is_armed() or restore_job ~= nil,
        target = nil,
        target_error = nil,
        plan = nil,
        plan_valid = false,
        preview_valid = false,
        missing_count = 0,
        new_count = 0,
        returned_count = 0,
        retired_count = 0,
    }

    result.state, result.state_error = mod._workflow_cached_state_if_fresh()

    if result.state then
        mod:info(
            "[ModShrine][PERF] WORKFLOW_STATE current_state_source=cache reason=%s",
            tostring(result.state_error or "verified_unchanged")
        )
        result.state_error = nil
    else
        local cache_miss_reason = result.state_error
        result.state, result.state_error = build_current_state()

        if result.state then
            mod._store_workflow_state_cache(
                result.state,
                "cache_miss_" .. tostring(cache_miss_reason or "unknown")
            )
        end
    end

    if not result.state then
        return result
    end

    result.missing_count = map_count(result.state.missing_active)
    result.new_count = map_count(result.state.new_mods)
    result.returned_count = map_count(result.state.returned_mods)
    result.retired_count = map_count(result.state.retired)

    -- Public guided restore intentionally requires Known Good.
    if result.known then
        result.target, result.target_error = target_state_for_preview(true)

        if result.target and result.target.source_id == "known_good" then
            local plan = build_safe_restore_maps(result.state, result.target)
            local plan_ok, plan_errors =
                validate_safe_restore_plan(result.state, result.target, plan)

            if plan_ok then
                result.plan = plan
                result.plan_valid = true
                result.preview_valid =
                    restore_preview_matches(result.state, result.target)
            else
                result.plan_errors = plan_errors or {}

                mod:error(
                    "[ModShrine][UX] Guided restore plan invalid (%d error(s)).",
                    #result.plan_errors
                )

                for i = 1, math.min(#result.plan_errors, 10) do
                    mod:error(
                        "[ModShrine][UX] Guided plan validation: %s",
                        tostring(result.plan_errors[i])
                    )
                end
            end
        elseif result.target then
            result.target_error =
                "unexpected restore source_id=" ..
                tostring(result.target.source_id) ..
                " label=" ..
                tostring(result.target.source_kind)

            mod:error(
                "[ModShrine][UX] Guided restore source rejected: %s",
                tostring(result.target_error)
            )
        end
    end

    return result
end

local function guided_protection_status_text(workflow)
    if not workflow.state then
        return "ANALYSIS UNAVAILABLE"
    end

    if workflow.pending then
        return "PROTECTED | RESTORE PENDING"
    end

    if not workflow.state.latest then
        return "SETUP NEEDED"
    end

    if workflow.known then
        return "PROTECTED | KNOWN GOOD READY"
    end

    return "PROTECTED | KNOWN GOOD NOT SET"
end

local function guided_current_state_text(workflow)
    if not workflow.state then
        return "CHECK DETAILS"
    end

    local parts = {}

    if workflow.plan_valid then
        local changes = workflow.plan.setting_changes or 0

        if changes > 0 then
            parts[#parts + 1] =
                tostring(changes) .. (changes == 1 and " CHANGE" or " CHANGES")
        else
            parts[#parts + 1] = "MATCHES KNOWN GOOD"
        end
    elseif workflow.known then
        parts[#parts + 1] = "RESTORE CHECK UNAVAILABLE"
    else
        parts[#parts + 1] = "SET KNOWN GOOD"
    end

    if workflow.missing_count > 0 then
        parts[#parts + 1] =
            tostring(workflow.missing_count) ..
            (workflow.missing_count == 1 and " MISSING MOD" or " MISSING MODS")
    end

    return table.concat(parts, " | ")
end

local function guided_locked_notice(step)
    notify(
        "ModShrine: complete " .. tostring(step) ..
        " first. The locked step cannot modify anything."
    )
end

local function guided_completed_notice(message)
    notify("ModShrine: " .. tostring(message))
end

function mod._guided_preview_is_unlocked()
    return restore_preview_signature ~= nil
        and restore_preview_source_snapshot ~= nil
        and restore_preview_setting_changes > 0
end

function mod._guided_preview_is_locked()
    return not mod._guided_preview_is_unlocked()
end

local function has_setting(settings, setting_id)
    for _, entry in ipairs(settings or {}) do
        if entry.setting_id == setting_id then
            return true
        end
    end
    return false
end

local function add_button(
    settings,
    category,
    setting_id,
    title,
    button_text,
    tooltip,
    callback,
    trigger,
    hold_duration,
    validation_function
)
    if has_setting(settings, setting_id) then
        return
    end

    settings[#settings + 1] = {
        after = #settings,
        button_hold_duration = hold_duration or 1,
        button_text = button_text,
        button_trigger = trigger or "pressed",
        category = category,
        custom = true,
        display_name = title,
        indentation_level = 0,
        mod_name = "mod_shrine",
        search_id = setting_id,
        setting_id = setting_id,
        tooltip_text = title .. "\n" .. tooltip,
        widget_type = "button",
        pressed_function = callback,
        validation_function = validation_function,
    }
end

if dmf and dmf.create_mod_options_settings then
    mod:hook(dmf, "create_mod_options_settings", function(func, self, options_templates)
        local result = func(self, options_templates)

        local settings = options_templates and options_templates.settings
        if not settings then
            return result
        end

        -- Runtime rows are rebuilt every time the menu is generated. This lets
        -- the page change from Step 3 -> Step 4, healthy -> missing, or normal
        -- -> pending without restarting Darktide.
        clear_custom_modshrine_rows(settings)

        local category = mod:get_readable_name() or "ModShrine"
        local workflow = guided_workflow_state()
        local state = workflow.state
        local known = workflow.known
        local plan = workflow.plan

        mod:info(
            "[ModShrine][UX] WORKFLOW_STATE latest=%s known_good=%s pending=%s source_id=%s plan_valid=%s changes=%s preview_valid=%s missing=%d retired=%d target_error=%s",
            tostring(state and state.latest ~= nil),
            tostring(known ~= nil),
            tostring(workflow.pending),
            tostring(workflow.target and workflow.target.source_id or "none"),
            tostring(workflow.plan_valid),
            tostring(plan and plan.setting_changes or "n/a"),
            tostring(workflow.preview_valid),
            workflow.missing_count,
            workflow.retired_count,
            tostring(workflow.target_error or "none")
        )

        -- ---------------------------------------------------------------
        -- COMPACT STATUS
        -- Two short rows prevent the DMF button text from becoming a cramped
        -- three-line paragraph at 1080p / common UI scaling.
        -- ---------------------------------------------------------------
        add_button(
            settings,
            category,
            "modshrine_ux_protection_status",
            "Protection Status",
            guided_protection_status_text(workflow),
            "Quick protection summary. Click for detailed status.",
            function()
                mod.ui_check_status()
            end
        )

        add_button(
            settings,
            category,
            "modshrine_ux_current_state",
            "Current State",
            guided_current_state_text(workflow),
            "Quick comparison against Known Good plus any missing-mod attention. Click for detailed status.",
            function()
                mod.ui_check_status()
            end
        )

        -- ---------------------------------------------------------------
        -- ALWAYS-VISIBLE GUIDED CHECKLIST
        -- Completed steps remain visible so a first-time user can understand
        -- the sequence instead of watching earlier steps mysteriously vanish.
        -- ---------------------------------------------------------------

        -- STEP 1
        if state and state.latest then
            add_button(
                settings,
                category,
                "modshrine_ux_step1_complete",
                "1. Protect Your Settings",
                "✓ PROTECTED",
                "Step 1 is complete. A verified backup exists and Automatic Backups will continue protecting meaningful changes.",
                function()
                    guided_completed_notice(
                        "Step 1 complete. Your settings are protected."
                    )
                end
            )
        else
            add_button(
                settings,
                category,
                "modshrine_ux_step1_backup",
                "1. Protect Your Settings",
                "CREATE FIRST BACKUP",
                "Step 1: create the first verified protection point. Automatic Backups maintain protection after this.",
                function()
                    mod.ui_create_backup()
                end
            )
        end

        -- STEP 2
        if not state or not state.latest then
            add_button(
                settings,
                category,
                "modshrine_ux_step2_locked",
                "2. Choose a Trusted Restore Point",
                "LOCKED - COMPLETE STEP 1",
                "Step 2 becomes available after the first verified backup exists.",
                function()
                    guided_locked_notice("Step 1")
                end
            )
        elseif known then
            add_button(
                settings,
                category,
                "modshrine_ux_step2_complete",
                "2. Choose a Trusted Restore Point",
                "✓ KNOWN GOOD READY",
                "Step 2 is complete. Known Good is the trusted restore point used by the guided recovery workflow. If Step 3 has not refreshed yet, exit Mod Options to the Mourningstar and reopen ModShrine.",
                function()
                    guided_completed_notice(
                        "Step 2 complete. Known Good is ready."
                    )
                end
            )
        else
            add_button(
                settings,
                category,
                "modshrine_ux_step2_known_good",
                "2. Choose a Trusted Restore Point",
                "MARK KNOWN GOOD",
                "Step 2: protect the latest verified backup as Known Good. Do this when your mod settings are working exactly the way you want. After Known Good finishes, exit Mod Options to the Mourningstar, then reopen ModShrine to continue to Step 3.",
                function()
                    mod.ui_mark_known_good()
                end,
                "held",
                1.25
            )
        end

        -- STEP 3
        if not known then
            add_button(
                settings,
                category,
                "modshrine_ux_step3_locked",
                "3. Check Before Restoring",
                "LOCKED - COMPLETE STEP 2",
                "Step 3 becomes available after Known Good exists. After completing Step 2, exit Mod Options to the Mourningstar, then reopen ModShrine.",
                function()
                    notify(
                        "ModShrine: complete Step 2, then exit Mod Options to the Mourningstar and reopen ModShrine to continue."
                    )
                end
            )
        elseif not workflow.plan_valid then
            add_button(
                settings,
                category,
                "modshrine_ux_step3_unavailable",
                "3. Check Before Restoring",
                "CHECK UNAVAILABLE - SEE DETAILS",
                "ModShrine could not validate the current restore comparison. Nothing can be restored until this is resolved.",
                function()
                    mod.ui_check_status()
                end
            )
        elseif plan.setting_changes <= 0 then
            add_button(
                settings,
                category,
                "modshrine_ux_step3_not_needed",
                "3. Check Before Restoring",
                "✓ NO RESTORE NEEDED",
                "Current settings already match Known Good. There is nothing to restore.",
                function()
                    guided_completed_notice(
                        "Current settings already match Known Good. No restore is needed."
                    )
                end
            )
        else
            local change_count = plan.setting_changes or 0

            -- Both Step 3 states are registered. DMF's native
            -- validation_function system swaps them live when Preview succeeds.
            add_button(
                settings,
                category,
                "modshrine_ux_step3_preview",
                "3. Preview Restore",
                "PREVIEW " ..
                    tostring(change_count) ..
                    (change_count == 1 and " CHANGE" or " CHANGES"),
                "Step 3: preview exactly what would change. Nothing is modified. Step 4 unlocks automatically after Preview succeeds.",
                function()
                    mod.ui_preview_safe_restore()
                end,
                nil,
                nil,
                mod._guided_preview_is_locked
            )

            add_button(
                settings,
                category,
                "modshrine_ux_step3_complete",
                "3. Preview Restore ",
                "✓ PREVIEW COMPLETE",
                "Step 3 is complete for this exact current configuration and Known Good source. Step 4 is unlocked.",
                function()
                    guided_completed_notice(
                        "Step 3 complete. Restore Preview is validated."
                    )
                end,
                nil,
                nil,
                mod._guided_preview_is_unlocked
            )
        end

        -- STEP 4
        if workflow.pending then
            add_button(
                settings,
                category,
                "modshrine_ux_step4_pending",
                "4. Restore Known Good",
                "PENDING - APPLIES AFTER EXIT",
                "Step 4 is armed. Live settings are not replaced while Darktide is running. The hidden watcher applies the staged restore only after Darktide fully exits.",
                function()
                    guided_completed_notice(
                        "Restore is pending and will apply only after Darktide exits."
                    )
                end
            )
        elseif known
            and workflow.plan_valid
            and plan.setting_changes > 0
        then
            -- Both Step 4 states are registered. DMF swaps them live when the
            -- Preview authorization changes.
            add_button(
                settings,
                category,
                "modshrine_ux_step4_locked",
                "4. Restore Known Good - Locked",
                "LOCKED - COMPLETE STEP 3",
                "Step 4 cannot stage a restore until Step 3 Preview validates the exact current configuration.",
                function()
                    guided_locked_notice("Step 3")
                end,
                nil,
                nil,
                mod._guided_preview_is_locked
            )

            add_button(
                settings,
                category,
                "modshrine_ux_step4_restore",
                "4. Restore Known Good",
                "STAGE KNOWN GOOD RESTORE",
                "Step 4 is unlocked because Step 3 Preview validated this exact configuration. Creates an emergency pre-restore backup, stages a verified merge, and applies it only after Darktide fully exits.",
                function()
                    mod.ui_safe_restore()
                end,
                "held",
                2.0,
                mod._guided_preview_is_unlocked
            )
        end

        -- Restore cancellation belongs directly under Step 4 while armed.
        -- Pending cancellation is contextual and only appears while armed.
        if workflow.pending then
            add_button(
                settings,
                category,
                "modshrine_ux_pending_cancel",
                "Restore Pending",
                "CANCEL PENDING RESTORE",
                "Only use this if you no longer want the staged restore applied after Darktide exits.",
                function()
                    mod.ui_cancel_pending_restore()
                end,
                "held",
                1.0
            )
        end

        -- ---------------------------------------------------------------
        -- CONTEXTUAL ATTENTION
        -- Missing/retired rows exist only when the roster actually needs it.
        -- ---------------------------------------------------------------
        if mod:get("show_missing_mod_rows") ~= false and state then
            local missing = sorted_names_from_map(state.missing_active)
            local retired = sorted_names_from_map(state.retired)

            for i = 1, math.min(#missing, MAX_DYNAMIC_ROSTER_ROWS) do
                local name = missing[i]
                local setting_id =
                    "modshrine_attention_retire_" .. hash_string(lower(name))

                add_button(
                    settings,
                    category,
                    setting_id,
                    "Missing Mod Archived: " .. name,
                    "RETIRE " .. string.upper(name),
                    "This mod is currently missing and its settings archive is already preserved. Do nothing if it may return. Hold RETIRE only if you want ModShrine to stop flagging its absence. Historical backups and archived settings are NOT deleted.",
                    function()
                        set_retired(name, true)
                    end,
                    "held",
                    1.0
                )
            end

            for i = 1, math.min(#retired, MAX_DYNAMIC_ROSTER_ROWS) do
                local name = retired[i]
                local setting_id =
                    "modshrine_attention_unretire_" .. hash_string(lower(name))

                add_button(
                    settings,
                    category,
                    setting_id,
                    "Archived / Retired Mod: " .. name,
                    "RESTORE TRACKING",
                    "Resume treating this mod as part of the remembered roster. Its archived settings remained preserved while retired.",
                    function()
                        set_retired(name, false)
                    end,
                    "held",
                    1.0
                )

                local forget_setting_id =
                    "modshrine_attention_forget_" .. hash_string(lower(name))

                add_button(
                    settings,
                    category,
                    forget_setting_id,
                    "Forget Retired Mod: " .. name,
                    "FORGET TRACKING",
                    "Hold to stop tracking this obsolete retired mod ID. It will disappear from missing/retired workflow rows and restore missing-target counts. Live DMF settings are not deleted, and historical snapshots plus the existing per-mod archive are preserved. If this exact mod ID is installed again later, ModShrine automatically resumes tracking it.",
                    function()
                        mod._forget_retired_mod(name)
                    end,
                    "held",
                    2.0
                )
            end
        end

        -- ---------------------------------------------------------------
        -- ADVANCED / MAINTENANCE TOOLS
        -- Hidden by default. Normal users should not have to sort through
        -- maintenance actions to understand the protection workflow.
        -- ---------------------------------------------------------------
        if mod:get("show_advanced_tools") == true then
            if state and state.latest then
                add_button(
                    settings,
                    category,
                    "modshrine_tool_manual_backup",
                    "Advanced - Manual Backup",
                    "CREATE MANUAL BACKUP",
                    "Optional maintenance action. Automatic Backups normally make this unnecessary.",
                    function()
                        mod.ui_create_backup()
                    end
                )
            end

            if state
                and known
                and workflow.plan_valid
                and plan.setting_changes > 0
                and not workflow.pending
            then
                add_button(
                    settings,
                    category,
                    "modshrine_tool_replace_known_good",
                    "Advanced - Replace Known Good",
                    "REPLACE KNOWN GOOD",
                    "Adopt the latest verified CURRENT settings as the new trusted Known Good instead of restoring the old one. Hold to confirm.",
                    function()
                        mod.ui_mark_known_good()
                    end,
                    "held",
                    1.5
                )
            end

            if state and (
                workflow.missing_count > 0
                or workflow.new_count > 0
                or workflow.returned_count > 0
                or workflow.retired_count > 0
            ) then
                add_button(
                    settings,
                    category,
                    "modshrine_tool_export_roster",
                    "Advanced - Mod Roster",
                    "EXPORT ROSTER",
                    "Write a human-readable roster report.",
                    function()
                        mod.ui_export_roster()
                    end
                )
            end

            add_button(
                settings,
                category,
                "modshrine_tool_open_folder",
                "Advanced - ModShrine Vault",
                "OPEN VAULT",
                "Open the independent ModShrine vault containing snapshots, Known Good, exports, restore evidence, manifests, and per-mod archives.",
                function()
                    mod.ui_open_backup_folder()
                end
            )

            add_button(
                settings,
                category,
                "modshrine_tool_status",
                "Advanced - Detailed Status",
                "CHECK DETAILS",
                "Report detailed configuration, roster, backup, anomaly, and restore-source information.",
                function()
                    mod.ui_check_status()
                end
            )
        end

        return result
    end)

    mod:info(
        "[ModShrine] %s loaded; protection engine armed.",
        VERSION
    )

else
    mod:error("[ModShrine] DMF create_mod_options_settings was unavailable.")
end
