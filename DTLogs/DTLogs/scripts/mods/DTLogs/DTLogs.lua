local mod = get_mod("DTLogs")
local DMF = get_mod("DMF")
local CLASS = CLASS
local MOD_VERSION = "0.13.40"

-- MissionTemplates is used only to identify Expedition missions. Keep the
-- dependency optional so a future game-side path change cannot prevent DTLogs
-- from loading; the fallback recognises the current expedition mission prefix.
local MissionTemplates = nil
do
	local ok, value = pcall(mod.original_require, mod, "scripts/settings/mission/mission_templates")
	if ok and type(value) == "table" then
		MissionTemplates = value
	end
end

-- DangerSettings is used only as a safe fallback when the live
-- DifficultyManager does not expose get_danger_settings(). The live manager is
-- authoritative because circumstances can alter effective difficulty after
-- StateGameplay receives the raw mechanism data.
local DangerSettings = nil
do
	local ok, value = pcall(mod.original_require, mod, "scripts/settings/difficulty/danger_settings")
	if ok and type(value) == "table" then
		DangerSettings = value
	end
end

-- Optional metadata tables used only by the mission-modifier diagnostic probe.
-- The runtime mission/mechanism managers remain authoritative; these tables
-- merely help expose stable template ids/localization/icon metadata when the
-- current game build makes them available. Missing paths must never stop DTLogs.
local CircumstanceTemplates = nil
do
	local ok, value = pcall(mod.original_require, mod, "scripts/settings/circumstance/circumstance_templates")
	if ok and type(value) == "table" then
		CircumstanceTemplates = value
	end
end

local MutatorTemplates = nil
do
	local ok, value = pcall(mod.original_require, mod, "scripts/settings/mutator/mutator_templates")
	if ok and type(value) == "table" then
		MutatorTemplates = value
	end
end

-- Breed is used to distinguish actual enemy minions from companions and other
-- non-player units. Keep it optional so a future game-side path change cannot
-- prevent DTLogs from loading.
local Breed = nil
do
	local ok, value = pcall(mod.original_require, mod, "scripts/utilities/breed")
	if ok and type(value) == "table" then
		Breed = value
	end
end

-- Remote-player buff diagnostics remain disabled. v0.13.5 adds bounded performance diagnostics.
local _io = DMF:persistent_table("_io")
_io.initialized = _io.initialized or false
if not _io.initialized then
	_io = DMF.deepcopy(Mods.lua.io)
end

local _os = DMF:persistent_table("_os")
_os.initialized = _os.initialized or false
if not _os.initialized then
	_os = DMF.deepcopy(Mods.lua.os)
end

-- Automatic upload uses the same anonymous multipart endpoint as the website's
-- manual uploader. The worker itself still uses Windows Script Host + curl.exe,
-- but v0.13.25 launches wscript.exe natively through ShellExecuteW instead of
-- os.execute(). This bypasses cmd.exe entirely, so no console window should be
-- created over Darktide.
local AUTO_UPLOAD_URL = "https://dtlogs.com/api/v1/logs"
-- Account-linked uploads must use the dedicated production endpoint. Keep this
-- as a standalone constant so it cannot accidentally drift back to the old
-- pre-rollout /api/v1/addon/logs path.
local AUTO_UPLOAD_LINKED_URL = "https://dtlogs.com/api/v1/logs/addon"
local AUTO_UPLOAD_AUTH = {
	key_file_name = "dtlogs_upload_key.txt",
}
local AUTO_UPLOAD_CONNECT_TIMEOUT_SECONDS = 10
local AUTO_UPLOAD_MAX_TIME_SECONDS = 300
local AUTO_UPLOAD_RETRY_DELAY_SECONDS = 30
local AUTO_UPLOAD_QUEUE_FILE_NAME = "dtlogs_upload_queue.txt"
local AUTO_UPLOAD_RECEIPT_FILE_NAME = "dtlogs_upload_receipts.txt"

mod.auto_upload_jobs = {}
mod.auto_upload_active_paths = {}
mod.auto_upload_queue = {}
mod.auto_upload_queue_set = {}
mod.auto_upload_retry_after = {}
mod.auto_upload_failure_notified = {}
mod.auto_upload_queue_loaded = false
mod.auto_upload_sequence = 0
mod.auto_upload_poll_accumulator = 0
mod.auto_upload_scheduler_accumulator = 0
mod.last_completed_log_path = nil
mod.auto_upload_key = nil
mod.auto_upload_key_loaded = false
mod.auto_upload_auth_blocked = false
mod.auto_upload_auth_block_reason = nil

mod.current_file = nil
mod.current_file_path = nil
mod.current_session_id = nil
mod.current_mission_name = nil
mod.current_circumstance = nil
mod.current_havoc_data_raw = nil
mod.current_modifier_mechanism_context = nil
mod.current_mission_modifiers = {}
mod.current_mission_modifiers_source = nil
mod.modifier_startup_snapshot_written = false
mod.modifier_final_snapshot_written = false
mod.current_challenge = nil
mod.current_resistance = nil
mod.current_difficulty_mode = nil
mod.current_havoc_rank = nil
mod.current_effective_challenge = nil
mod.current_effective_resistance = nil
mod.current_initial_challenge = nil
mod.current_initial_resistance = nil
mod.current_danger_name = nil
mod.current_danger_index = nil
mod.current_danger_difficulty = nil
mod.current_danger_is_auric = nil
mod.current_danger_localization_key = nil
mod.difficulty_resolution_written = false
mod.current_game_version = nil
mod.current_game_version_source = nil
mod.current_game_build_identifier = nil
mod.current_game_build_mode = nil
mod.current_game_teamcity_build_id = nil
mod.mission_start_time_ms = nil
mod.event_count = 0
mod.capture_queue = {}
mod.capture_queue_head = 1
mod.capture_queue_tail = 0
mod.capture_queue_count = 0
mod.capture_queue_peak = 0
mod.max_events_serialized_per_frame = 48
mod.serialize_time_budget_seconds = 0.0005
mod.pending_lines = {}
mod.pending_line_head = 1
mod.pending_line_tail = 0
mod.pending_line_count = 0
mod.pending_line_peak = 0
mod.pending_line_bytes = 0
mod.pending_line_byte_peak = 0
mod.max_bytes_per_write = 65536
mod.write_interval_seconds = 0.5
mod.write_accumulator = 0
mod.flush_interval_seconds = 30.0
mod.flush_accumulator = 0
mod.buff_definitions_written = {}
mod.buff_definition_count = 0
mod.buff_position_cache_time_ms = nil
mod.buff_position_cache = {}
mod.serialized_event_count = 0
mod.physical_line_count = 0
mod.write_chunk_count = 0
mod.max_write_chunk_bytes = 0
mod.active_buff_batch = nil
mod.buff_batch_max_entries = 64
mod.buff_batch_line_count = 0
mod.buff_batch_logical_event_count = 0
mod.buff_batch_peak_entries = 0
mod.player_unit_lookup_time_ms = nil
mod.player_unit_lookup = {}
mod.stable_player_identity_cache = {}
mod.actor_snapshot_cache_time_ms = nil
mod.actor_snapshot_cache = {}
mod.event_position_cache_time_ms = nil
mod.event_position_cache = {}
mod.buff_game_object_unit_cache = {}
mod.buff_template_name_cache = {}
mod.active_interactions = {}
mod.player_ability_num_charges = {}
mod.active_player_states = {}
mod.last_slot_events = {}
mod.last_suppression_events = {}
mod.event_type_counts = {}
mod.total_actual_damage = 0
mod.total_effective_enemy_damage = 0
mod.total_overkill_damage = 0
mod.enemy_damage_event_count = 0
mod.enemy_damage_fallback_count = 0
mod.enemy_health_cache = {}
mod.enemy_health_cache_hit_count = 0
mod.enemy_health_cache_miss_count = 0
mod.enemy_health_cache_seed_count = 0
mod.enemy_health_read_fallback_count = 0
mod.enemy_damage_accounting_anomaly_count = 0 -- deprecated alias; see scoreboard_damage_outlier_count
mod.scoreboard_damage_outlier_count = 0
mod.zero_damage_event_count = 0
mod.total_player_damage_taken = 0
mod.player_resources = {}
mod.resource_poll_accumulator = 0
mod.total_health_lost = 0
mod.total_health_restored = 0
mod.total_toughness_lost = 0
mod.total_toughness_restored = 0
mod.active_player_buffs = {}
mod.buff_generations = {}
mod.last_coherency_events = {}
mod.profile_probe_accumulator = 0
mod.profile_probe_interval = 1.0
mod.profile_late_join_probe_interval = 2.0
mod.profile_snapshot_players = {}
mod.profile_pending_logged = {}
mod.profile_probe_started_ms = nil
mod.profile_probe_finished = false
mod.profile_probe_deadline_ms = 20000
mod.profile_snapshot_count = 0
mod.profile_late_join_snapshot_count = 0

-- v0.13.18 mission-clock / participant-presence semantics.
-- Live validation showed that a fresh mission opens the DTLogs file before the
-- synchronized server gameplay clock reaches zero, while a hot-join recording
-- starts after that server clock is already running. Compare those two monotonic
-- origins and keep a narrow ambiguity band instead of guessing near zero.
mod.presence_diagnostic_version = 1
mod.gameplay_clock_diagnostic_version = 1
mod.gameplay_clock_sync_count = 0
mod.gameplay_clock_first_server_sync_ms = nil
mod.gameplay_clock_first_sync_offset = nil
mod.gameplay_clock_first_sync_recording_elapsed_ms = nil
mod.gameplay_clock_first_observed_ms = nil
mod.gameplay_clock_last_observed_ms = nil
mod.gameplay_state_enter_observed = false
mod.gameplay_state_exit_observed = false
mod.session_join_event_count = 0
mod.session_leave_event_count = 0
mod.presence_peer_identity = {}
mod.presence_initial_snapshot_written = false
mod.presence_final_snapshot_written = false
mod.mission_end_observed = false

-- v0.13.5 bounded performance diagnostics. These probes do not remove or
-- aggregate gameplay events. They only add rare performance_spike records.
mod.performance_spike_limit = 500
mod.performance_spike_count = 0
mod.performance_spike_written_count = 0
mod.performance_spike_dropped = 0
mod.performance_spike_counts = {}
mod.pending_performance_spikes = {}
mod.pending_performance_spike_head = 1
mod.pending_performance_spike_tail = 0
mod.pending_performance_spike_count = 0
mod.performance_threshold_seconds = {
	hook = 0.0025,
	serialize = 0.0020,
	write = 0.0020,
	flush = 0.0020,
	addon_update = 0.0030,
	frame = 0.0500,
}
mod.max_performance_duration_ms = {}
mod.max_performance_label = {}
mod.last_update_metrics = {}
mod.last_lua_memory_kb = nil

local function json_escape(value)
	value = tostring(value or "")
	value = string.gsub(value, "\\", "\\\\")
	value = string.gsub(value, '"', '\\"')
	value = string.gsub(value, "\n", "\\n")
	value = string.gsub(value, "\r", "\\r")
	value = string.gsub(value, "\t", "\\t")
	return value
end

local function json_string(value)
	if value == nil then
		return "null"
	end
	return '"' .. json_escape(value) .. '"'
end

local function json_number(value)
	value = tonumber(value)
	if not value then
		return "null"
	end

	-- JSON does not support NaN or +/-Infinity. Preserve the diagnostic
	-- meaning as strings instead of producing an invalid JSONL line.
	if value ~= value then
		return '"nan"'
	elseif value == math.huge then
		return '"infinity"'
	elseif value == -math.huge then
		return '"-infinity"'
	end

	return tostring(value)
end

local function json_boolean(value)
	if value == true then
		return "true"
	elseif value == false then
		return "false"
	end

	return "null"
end

local function json_number_array(values)
	if type(values) ~= "table" then
		return "[]"
	end

	local result = {}
	for i = 1, #values do
		result[#result + 1] = json_number(values[i])
	end
	return "[" .. table.concat(result, ",") .. "]"
end

-- Darktide passes Havoc context into StateGameplay through
-- params.mechanism_data.havoc_data. On the current game protocol this value is
-- a semicolon-delimited string whose second field is the authoritative Havoc
-- rank (for example: "km_station;25;..."). Support a table shape as well so
-- DTLogs remains tolerant if the game later exposes the already-parsed data.
local function havoc_rank_from_data(havoc_data)
	local rank = nil

	if type(havoc_data) == "table" then
		rank = tonumber(havoc_data.havoc_rank or havoc_data.rank)
	elseif type(havoc_data) == "string" and havoc_data ~= "" then
		local rank_text = string.match(havoc_data, "^[^;]*;([^;]+)")
		rank = tonumber(rank_text)
	end

	if not rank or rank < 1 or rank ~= math.floor(rank) then
		return nil
	end

	return rank
end

local function has_havoc_data(havoc_data)
	if type(havoc_data) == "table" then
		return true
	end

	return type(havoc_data) == "string" and havoc_data ~= ""
end

-- v0.13.20 canonical mission-modifier identifiers -------------------------
-- Live validation showed that the fifth semicolon-delimited field of
-- StateGameplay mechanism_data.havoc_data is the ordered list of the
-- user-facing Havoc modifier cards. The same ids are also exposed by the
-- game's party advertisement as havoc_circ_1, havoc_circ_2, ... . Preserve
-- those high-level ids and their order; do not expand them into the many
-- low-level gameplay mutators they may activate internally.
local function havoc_high_level_modifier_ids(havoc_data)
	local ids = {}

	if type(havoc_data) == "string" and havoc_data ~= "" then
		local modifier_field = string.match(havoc_data, "^[^;]*;[^;]*;[^;]*;[^;]*;([^;]*)")
		if modifier_field and modifier_field ~= "" then
			for id in string.gmatch(modifier_field, "[^:]+") do
				if id ~= "" then
					ids[#ids + 1] = id
				end
			end
		end
	elseif type(havoc_data) == "table" then
		-- Future-tolerant fallback if Darktide starts passing parsed Havoc data.
		-- Only inspect explicitly high-level list fields; never recursively scrape
		-- arbitrary mutator tables because that would mix hidden implementation
		-- mutators into the public mission-modifier list.
		local candidates = havoc_data.havoc_circumstances
			or havoc_data.circumstances
			or havoc_data.mutators
			or havoc_data.modifiers
		if type(candidates) == "string" then
			for id in string.gmatch(candidates, "[^:]+") do
				if id ~= "" then
					ids[#ids + 1] = id
				end
			end
		elseif type(candidates) == "table" then
			for i = 1, #candidates do
				local candidate = candidates[i]
				local id = type(candidate) == "table"
					and (candidate.id or candidate.name or candidate.mutator_name or candidate.circumstance_name)
					or candidate
				if type(id) == "string" and id ~= "" then
					ids[#ids + 1] = id
				end
			end
		end
	end

	return ids
end

local function resolve_mission_modifiers(circumstance_name, havoc_data)
	local result = {}
	local seen = {}
	local havoc_ids = havoc_high_level_modifier_ids(havoc_data)

	for i = 1, #havoc_ids do
		local id = tostring(havoc_ids[i])
		if id ~= "" and not seen[id] then
			seen[id] = true
			result[#result + 1] = {
				id = id,
				kind = "havoc_mutator",
				display_order = #result + 1,
			}
		end
	end

	if #result > 0 then
		return result, "state_gameplay_havoc_data_high_level_list"
	end

	-- Normal mission Conditions are represented by mechanism_data.circumstance_name.
	-- `default` means no user-facing Condition. This fallback also prevents a
	-- future/legacy Havoc shape with no explicit high-level list from silently
	-- discarding a non-default circumstance.
	if circumstance_name ~= nil then
		local id = tostring(circumstance_name)
		if id ~= "" and id ~= "default" then
			result[1] = {
				id = id,
				kind = "condition",
				display_order = 1,
			}
		end
	end

	return result, "state_gameplay_circumstance_name"
end

local function mission_game_mode_name(mission_name)
	if type(MissionTemplates) == "table" then
		local mission_template = MissionTemplates[mission_name]
		if type(mission_template) == "table" then
			return mission_template.game_mode_name
		end
	end

	-- Current Expedition mission ids use the exp_ prefix. This fallback is used
	-- only if MissionTemplates could not be loaded.
	if type(mission_name) == "string" and string.match(mission_name, "^exp_") then
		return "expedition"
	end

	return nil
end

local function resolve_difficulty_context(mission_name, mechanism_data)
	mechanism_data = mechanism_data or {}
	local havoc_data = mechanism_data.havoc_data

	-- Havoc takes precedence over the underlying mission template because Havoc
	-- runs reuse normal adventure mission ids such as km_station.
	if has_havoc_data(havoc_data) then
		return "havoc", havoc_rank_from_data(havoc_data)
	end

	if mission_game_mode_name(mission_name) == "expedition" then
		return "expedition", nil
	end

	return "standard", nil
end

-- Read one of several possible fields without allowing diagnostic code to
-- interrupt the game. v0.12.2 referenced this helper but did not define it.
local function safe_field(object, names)
	if object == nil or type(names) ~= "table" then
		return nil
	end
	for i = 1, #names do
		local name = names[i]
		local ok, value = pcall(function()
			return object[name]
		end)
		if ok and value ~= nil then
			return value
		end
	end
	return nil
end

local function scalar_string(value)
	local value_type = type(value)
	if value_type == "string" or value_type == "number" or value_type == "boolean" then
		return tostring(value)
	end
	return nil
end

local function semantic_version_from_string(value)
	local text = scalar_string(value)
	if not text then
		return nil
	end

	-- Prefer a conventional x.y.z version when the build identifier embeds one.
	return string.match(text, "%d+%.%d+%.%d+[%w%._%-%+]*")
		or string.match(text, "%d+%.%d+")
end

local function get_game_build_metadata()
	local application_settings = rawget(_G, "APPLICATION_SETTINGS")
	local build_identifier = scalar_string(rawget(_G, "BUILD_IDENTIFIER"))
	local game_version = scalar_string(safe_field(application_settings, {
		"game_version",
		"product_version",
		"release_version",
		"application_version",
		"version",
	}))
	local game_version_source = game_version and "application_settings" or nil

	if not game_version then
		game_version = semantic_version_from_string(build_identifier)
		if game_version then
			game_version_source = "build_identifier"
		end
	end

	return {
		game_version = game_version,
		game_version_source = game_version_source,
		game_build_identifier = build_identifier,
		game_build_mode = scalar_string(rawget(_G, "BUILD")),
		game_teamcity_build_id = scalar_string(safe_field(application_settings, {"teamcity_build_id"})),
	}
end

local function timestamp()
	return _os.time()
end

local function monotonic_time_ms()
	if Application and Application.time_since_launch then
		local ok, value = pcall(Application.time_since_launch)
		if ok and type(value) == "number" then
			return math.floor(value * 1000)
		end
	end

	if _os.clock then
		return math.floor(_os.clock() * 1000)
	end

	return timestamp() * 1000
end

local function mission_elapsed_ms()
	if not mod.mission_start_time_ms then
		return 0
	end
	return math.max(0, monotonic_time_ms() - mod.mission_start_time_ms)
end

local function directory_exists(path)
	local ok, _, code = _os.rename(path, path)
	if not ok and code == 13 then
		return true
	end
	return ok
end

local function output_directory()
	local appdata = _os.getenv("APPDATA")
	return appdata .. "/Fatshark/Darktide/DTLogs/"
end

local function create_output_directory()
	local path = output_directory()
	if not directory_exists(path .. "/") then
		_os.execute('mkdir "' .. path .. '"')
	end
	return path
end


local function auto_upload_enabled()
	local ok, value = pcall(function()
		return mod:get("auto_upload_completed_missions")
	end)
	return ok and value == true
end

-- Keep these helpers on the mod table instead of declaring more top-level
-- locals. DTLogs.lua is a large LuaJIT chunk and is close to Lua's 200-local
-- compiler limit; adding menu/upload-policy helpers as locals can make the
-- whole mod fail to compile before it starts.
function mod.auto_upload_scope()
	local ok, value = pcall(function()
		return mod:get("auto_upload_scope")
	end)
	if ok and value == "all_missions" then
		return "all_missions"
	end
	return "successful_only"
end

function mod.mission_outcome_is_success(outcome)
	local normalized_outcome = tostring(outcome or ""):lower()
	-- Darktide's authoritative GameModeManager end-condition hook reports a
	-- victory as "won" (and a defeat as "lost"). Keep "success" accepted as
	-- a compatibility alias for older/synthetic logs and tests.
	return normalized_outcome == "won" or normalized_outcome == "success"
end

function mod.should_auto_upload_mission(outcome)
	if not auto_upload_enabled() then
		return false, "disabled"
	end
	if mod.auto_upload_scope() == "all_missions" then
		return true, nil
	end
	if mod.mission_outcome_is_success(outcome) then
		return true, nil
	end
	return false, "not_successful"
end

local function windows_path(path)
	return tostring(path or ""):gsub("/", "\\")
end

-- Darktide Mod Loader preserves LuaJIT's FFI library in Mods.lua.ffi. Use it
-- only for a tiny, isolated Windows process-launch call. All FFI setup is
-- defensive: if it is unavailable, DTLogs keeps the log queued rather than
-- falling back to os.execute(), because that fallback is what causes the
-- visible CMD flash we are trying to eliminate.
local _ffi = Mods and Mods.lua and Mods.lua.ffi or nil
local _kernel32 = nil
local _shell32 = nil
local native_upload_launcher_available = false
local native_upload_launcher_error = nil

do
	if not _ffi then
		native_upload_launcher_error = "LuaJIT FFI is unavailable"
	else
		-- Declare each function separately. pcall also tolerates the declaration
		-- already having been installed by another mod.
		pcall(function()
			_ffi.cdef([[
				int MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char *lpMultiByteStr, int cbMultiByte, unsigned short *lpWideCharStr, int cchWideChar);
			]])
		end)
		pcall(function()
			_ffi.cdef([[
				void *ShellExecuteW(void *hwnd, const unsigned short *lpOperation, const unsigned short *lpFile, const unsigned short *lpParameters, const unsigned short *lpDirectory, int nShowCmd);
			]])
		end)

		local ok, err = pcall(function()
			_kernel32 = _ffi.load("kernel32")
			_shell32 = _ffi.load("shell32")
			-- Resolve the symbols now so an unavailable declaration/library is
			-- detected before the first mission upload.
			local _ = _kernel32.MultiByteToWideChar
			local __ = _shell32.ShellExecuteW
		end)
		if ok then
			native_upload_launcher_available = true
		else
			native_upload_launcher_error = tostring(err)
		end
	end
end

local function utf8_to_wide(value)
	if not native_upload_launcher_available then
		return nil, native_upload_launcher_error or "native launcher is unavailable"
	end

	local text = tostring(value or "")
	local required = _kernel32.MultiByteToWideChar(65001, 0, text, -1, nil, 0)
	if required == nil or required <= 0 then
		return nil, "MultiByteToWideChar failed"
	end

	local buffer = _ffi.new("unsigned short[?]", required)
	local converted = _kernel32.MultiByteToWideChar(65001, 0, text, -1, buffer, required)
	if converted == nil or converted <= 0 then
		return nil, "MultiByteToWideChar conversion failed"
	end
	return buffer, nil
end

local function launch_wscript_hidden_native(script_path)
	if not native_upload_launcher_available then
		return false, native_upload_launcher_error or "native launcher is unavailable"
	end

	local operation, operation_error = utf8_to_wide("open")
	if not operation then
		return false, operation_error
	end
	local executable, executable_error = utf8_to_wide("wscript.exe")
	if not executable then
		return false, executable_error
	end
	local parameters, parameters_error = utf8_to_wide('//B //NoLogo "' .. windows_path(script_path) .. '"')
	if not parameters then
		return false, parameters_error
	end

	local ok, result_or_error = pcall(function()
		return _shell32.ShellExecuteW(nil, operation, executable, parameters, nil, 0)
	end)
	if not ok then
		return false, "ShellExecuteW failed: " .. tostring(result_or_error)
	end

	local result_code = tonumber(_ffi.cast("intptr_t", result_or_error))
	if not result_code or result_code <= 32 then
		return false, "ShellExecuteW returned " .. tostring(result_code)
	end

	return true, nil
end

local function vbs_escape(value)
	return tostring(value or ""):gsub('"', '""')
end

local function remove_file_safely(path)
	if not path or path == "" then
		return
	end
	pcall(function()
		_os.remove(path)
	end)
end

local function read_small_file(path, max_bytes)
	local file = _io.open(path, "rb")
	if not file then
		return nil
	end

	local ok, data = pcall(function()
		return file:read(max_bytes or 4096)
	end)
	pcall(function()
		file:close()
	end)

	if not ok then
		return nil
	end
	return data
end

local function upload_queue_path()
	return create_output_directory() .. AUTO_UPLOAD_QUEUE_FILE_NAME
end

local function upload_receipt_path()
	return create_output_directory() .. AUTO_UPLOAD_RECEIPT_FILE_NAME
end

function AUTO_UPLOAD_AUTH.key_path()
	return create_output_directory() .. AUTO_UPLOAD_AUTH.key_file_name
end

function AUTO_UPLOAD_AUTH.normalize(value)
	return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function AUTO_UPLOAD_AUTH.valid(value)
	local key = AUTO_UPLOAD_AUTH.normalize(value)
	if #key < 39 or #key > 103 then
		return false
	end
	return key:match("^dtl_up_[%w_-]+$") ~= nil
end

-- Accept either the raw upload key or a copied DTLogs link/text containing the
-- key. Upload keys use URL-safe characters, so no URL decoding is required.
function AUTO_UPLOAD_AUTH.extract(value)
	local input = AUTO_UPLOAD_AUTH.normalize(value)
	if AUTO_UPLOAD_AUTH.valid(input) then
		return input
	end
	local embedded = input:match("(dtl_up_[%w_-]+)")
	if embedded and AUTO_UPLOAD_AUTH.valid(embedded) then
		return embedded
	end
	return nil
end

function AUTO_UPLOAD_AUTH.hint(value)
	local key = AUTO_UPLOAD_AUTH.normalize(value)
	if key == "" then
		return nil
	end
	local suffix = #key >= 4 and key:sub(-4) or key
	return "dtl_up_..." .. suffix
end

function AUTO_UPLOAD_AUTH.mask(value)
	local hint = AUTO_UPLOAD_AUTH.hint(value)
	if not hint then
		return "not linked"
	end
	return "linked (" .. hint .. ")"
end

function AUTO_UPLOAD_AUTH.load()
	if mod.auto_upload_key_loaded then
		return mod.auto_upload_key
	end
	mod.auto_upload_key_loaded = true
	mod.auto_upload_key = nil

	local file = _io.open(AUTO_UPLOAD_AUTH.key_path(), "rb")
	if not file then
		return nil
	end
	local ok, data = pcall(function()
		return file:read(256)
	end)
	pcall(function() file:close() end)
	if not ok then
		return nil
	end
	local key = AUTO_UPLOAD_AUTH.normalize(data)
	if AUTO_UPLOAD_AUTH.valid(key) then
		mod.auto_upload_key = key
	end
	return mod.auto_upload_key
end

function AUTO_UPLOAD_AUTH.persist(key)
	key = AUTO_UPLOAD_AUTH.normalize(key)
	if not AUTO_UPLOAD_AUTH.valid(key) then
		return false, "invalid upload key format"
	end

	local path = AUTO_UPLOAD_AUTH.key_path()
	local temp_path = path .. ".tmp"
	local file, open_error = _io.open(temp_path, "wb")
	if not file then
		return false, open_error
	end
	local ok, write_error = pcall(function()
		file:write(key, "\r\n")
		file:flush()
		file:close()
	end)
	if not ok then
		pcall(function() file:close() end)
		remove_file_safely(temp_path)
		return false, write_error
	end

	remove_file_safely(path)
	local renamed, rename_error = _os.rename(temp_path, path)
	if not renamed then
		remove_file_safely(temp_path)
		return false, rename_error or "could not replace upload key file"
	end

	mod.auto_upload_key = key
	mod.auto_upload_key_loaded = true
	mod.auto_upload_auth_blocked = false
	mod.auto_upload_auth_block_reason = nil
	return true, nil
end

function AUTO_UPLOAD_AUTH.clear()
	remove_file_safely(AUTO_UPLOAD_AUTH.key_path())
	remove_file_safely(AUTO_UPLOAD_AUTH.key_path() .. ".tmp")
	mod.auto_upload_key = nil
	mod.auto_upload_key_loaded = true
	mod.auto_upload_auth_blocked = false
	mod.auto_upload_auth_block_reason = nil
end

function AUTO_UPLOAD_AUTH.current()
	local key = AUTO_UPLOAD_AUTH.load()
	if key then
		return "linked", key
	end
	return "anonymous", nil
end

function AUTO_UPLOAD_AUTH.http_status(path)
	local headers = read_small_file(path, 8192)
	if not headers or headers == "" then
		return nil
	end
	local status = nil
	for code in headers:gmatch("HTTP/%S+%s+(%d%d%d)") do
		status = tonumber(code)
	end
	return status
end

local function persist_auto_upload_queue()
	local path = upload_queue_path()
	local file, open_error = _io.open(path, "wb")
	if not file then
		return false, open_error
	end

	local ok, write_error = pcall(function()
		for _, log_path in ipairs(mod.auto_upload_queue or {}) do
			if log_path and log_path ~= "" then
				file:write(tostring(log_path):gsub("[\r\n]", ""), "\r\n")
			end
		end
		file:flush()
		file:close()
	end)
	if not ok then
		pcall(function() file:close() end)
		return false, write_error
	end
	return true, nil
end

local function rebuild_auto_upload_queue_set()
	mod.auto_upload_queue_set = {}
	for _, log_path in ipairs(mod.auto_upload_queue or {}) do
		mod.auto_upload_queue_set[log_path] = true
	end
end

local function load_auto_upload_queue()
	if mod.auto_upload_queue_loaded then
		return
	end
	mod.auto_upload_queue_loaded = true
	mod.auto_upload_queue = {}
	mod.auto_upload_queue_set = {}

	local file = _io.open(upload_queue_path(), "rb")
	if not file then
		return
	end

	for line in file:lines() do
		local log_path = tostring(line or ""):gsub("\r", ""):gsub("\n", "")
		if log_path ~= "" and not mod.auto_upload_queue_set[log_path] then
			local probe = _io.open(log_path, "rb")
			if probe then
				probe:close()
				table.insert(mod.auto_upload_queue, log_path)
				mod.auto_upload_queue_set[log_path] = true
			end
		end
	end
	file:close()

	-- A hidden worker may finish after Darktide has already closed. It appends a
	-- success receipt so the next game launch can remove that item without
	-- sending the same completed log a second time.
	local receipt_file = _io.open(upload_receipt_path(), "rb")
	if receipt_file then
		local receipts = {}
		for line in receipt_file:lines() do
			local receipt_path = tostring(line or ""):gsub("\r", ""):gsub("\n", "")
			if receipt_path ~= "" then
				receipts[receipt_path] = true
			end
		end
		receipt_file:close()
		if next(receipts) then
			for index = #mod.auto_upload_queue, 1, -1 do
				if receipts[mod.auto_upload_queue[index]] then
					table.remove(mod.auto_upload_queue, index)
				end
			end
			rebuild_auto_upload_queue_set()
		end
		remove_file_safely(upload_receipt_path())
	end

	persist_auto_upload_queue()
end

local function queue_auto_upload(log_path)
	load_auto_upload_queue()
	if not log_path or log_path == "" then
		return false, "completed log path is unavailable"
	end
	if mod.auto_upload_queue_set[log_path] then
		return true, nil
	end

	local probe = _io.open(log_path, "rb")
	if not probe then
		return false, "completed log file cannot be opened"
	end
	probe:close()

	table.insert(mod.auto_upload_queue, log_path)
	mod.auto_upload_queue_set[log_path] = true
	local persisted, persist_error = persist_auto_upload_queue()
	if not persisted then
		table.remove(mod.auto_upload_queue, #mod.auto_upload_queue)
		mod.auto_upload_queue_set[log_path] = nil
		return false, "cannot persist upload queue: " .. tostring(persist_error)
	end
	return true, nil
end

local function remove_from_auto_upload_queue(log_path)
	if not log_path then
		return
	end
	for index = #(mod.auto_upload_queue or {}), 1, -1 do
		if mod.auto_upload_queue[index] == log_path then
			table.remove(mod.auto_upload_queue, index)
		end
	end
	mod.auto_upload_queue_set[log_path] = nil
	mod.auto_upload_retry_after[log_path] = nil
	mod.auto_upload_failure_notified[log_path] = nil
	persist_auto_upload_queue()
end

local function cleanup_auto_upload_job_files(job)
	remove_file_safely(job.status_path)
	remove_file_safely(job.response_path)
	remove_file_safely(job.error_path)
	remove_file_safely(job.header_path)
	remove_file_safely(job.launcher_path)
	remove_file_safely(job.worker_path)
end

local function start_auto_upload(log_path)
	if not log_path or log_path == "" then
		return false, "completed log path is unavailable"
	end
	if mod.auto_upload_active_paths[log_path] then
		return false, "this log is already being uploaded"
	end

	-- Verify the finalized file is readable before spawning curl.
	local probe = _io.open(log_path, "rb")
	if not probe then
		return false, "completed log file cannot be opened"
	end
	probe:close()

	mod.auto_upload_sequence = (mod.auto_upload_sequence or 0) + 1
	local job_id = tostring(timestamp()) .. "_" .. tostring(mod.auto_upload_sequence)
	local base_path = create_output_directory() .. "dtlogs_upload_" .. job_id
	local worker_path = base_path .. "_worker.vbs"
	local status_path = base_path .. ".status"
	local response_path = base_path .. ".response"
	local error_path = base_path .. ".error"
	local header_path = base_path .. ".headers"

	local worker_file, worker_error = _io.open(worker_path, "wb")
	if not worker_file then
		return false, "cannot create hidden upload worker: " .. tostring(worker_error)
	end

	local vbs_log_path = vbs_escape(windows_path(log_path))
	local vbs_status_path = vbs_escape(windows_path(status_path))
	local vbs_response_path = vbs_escape(windows_path(response_path))
	local vbs_error_path = vbs_escape(windows_path(error_path))
	local vbs_header_path = vbs_escape(windows_path(header_path))
	local vbs_receipt_path = vbs_escape(windows_path(upload_receipt_path()))
	local upload_identity, upload_key = AUTO_UPLOAD_AUTH.current()
	local upload_url = upload_identity == "linked" and AUTO_UPLOAD_LINKED_URL or AUTO_UPLOAD_URL
	local vbs_url = vbs_escape(upload_url)
	local vbs_user_agent = vbs_escape("DTLogs/" .. MOD_VERSION)
	local vbs_authorization = upload_key and vbs_escape("Authorization: Bearer " .. upload_key) or nil
	local authorization_segment = vbs_authorization
		and (' & " --header " & q & "' .. vbs_authorization .. '" & q')
		or ""

	local worker_contents = table.concat({
		'Option Explicit',
		'Dim shell, fso, q, cmd, exitCode, statusFile, receiptFile',
		'Set shell = CreateObject("WScript.Shell")',
		'Set fso = CreateObject("Scripting.FileSystemObject")',
		'q = Chr(34)',
		'cmd = "curl.exe --silent --show-error --fail --connect-timeout ' .. tostring(AUTO_UPLOAD_CONNECT_TIMEOUT_SECONDS)
			.. ' --max-time ' .. tostring(AUTO_UPLOAD_MAX_TIME_SECONDS)
			.. ' --retry 2 --retry-delay 2 --header " & q & "User-Agent: ' .. vbs_user_agent .. '" & q'
			.. authorization_segment
			.. ' & " --dump-header " & q & "' .. vbs_header_path .. '" & q'
			.. ' & " --output " & q & "' .. vbs_response_path .. '" & q'
			.. ' & " --stderr " & q & "' .. vbs_error_path .. '" & q'
			.. ' & " --form " & q & "file=@' .. vbs_log_path .. '" & q'
			.. ' & " " & q & "' .. vbs_url .. '" & q',
		'exitCode = shell.Run(cmd, 0, True)',
		'If exitCode = 0 Then',
		'  On Error Resume Next',
		'  Set receiptFile = fso.OpenTextFile("' .. vbs_receipt_path .. '", 8, True)',
		'  receiptFile.WriteLine "' .. vbs_log_path .. '"',
		'  receiptFile.Close',
		'  On Error GoTo 0',
		'End If',
		'Set statusFile = fso.CreateTextFile("' .. vbs_status_path .. '", True)',
		'statusFile.Write CStr(exitCode)',
		'statusFile.Close',
		'On Error Resume Next',
		'fso.DeleteFile WScript.ScriptFullName, True',
	}, "\r\n") .. "\r\n"

	local worker_wrote, worker_write_error = pcall(function()
		worker_file:write(worker_contents)
		worker_file:flush()
		worker_file:close()
	end)
	if not worker_wrote then
		pcall(function() worker_file:close() end)
		remove_file_safely(worker_path)
		return false, "cannot write hidden upload worker: " .. tostring(worker_write_error)
	end

	-- Launch the worker directly with the Windows Shell API. Unlike os.execute(),
	-- this does not create an intermediate cmd.exe process, so there is no black
	-- console window to flash over Darktide. wscript.exe is itself windowless here
	-- (SW_HIDE / nShowCmd=0) and it launches curl with windowStyle=0.
	local launch_ok, launch_error = launch_wscript_hidden_native(worker_path)
	if not launch_ok then
		cleanup_auto_upload_job_files({
			worker_path = worker_path,
			status_path = status_path,
			response_path = response_path,
			error_path = error_path,
			header_path = header_path,
		})
		return false, "failed to launch native hidden uploader: " .. tostring(launch_error)
	end

	mod.auto_upload_active_paths[log_path] = true
	table.insert(mod.auto_upload_jobs, {
		id = job_id,
		log_path = log_path,
		worker_path = worker_path,
		status_path = status_path,
		response_path = response_path,
		error_path = error_path,
		header_path = header_path,
		upload_identity = upload_identity,
		started_at = timestamp(),
	})
	return true, nil
end

local function notify_auto_upload_failure_once(log_path, message)
	if not log_path or log_path == "" then
		return
	end
	if mod.auto_upload_failure_notified[log_path] then
		return
	end
	mod.auto_upload_failure_notified[log_path] = true
	mod:echo(message)
end

local function pump_auto_upload_queue()
	load_auto_upload_queue()
	if not auto_upload_enabled() then
		return
	end
	if mod.auto_upload_auth_blocked then
		return
	end

	-- Keep upload traffic deliberately serial. Mission recording itself never
	-- waits for the network, while a single worker avoids duplicate attempts.
	if #(mod.auto_upload_jobs or {}) > 0 then
		return
	end

	local now = timestamp()
	for _, log_path in ipairs(mod.auto_upload_queue or {}) do
		if not mod.auto_upload_active_paths[log_path]
			and now >= (mod.auto_upload_retry_after[log_path] or 0) then
			local started, start_error = start_auto_upload(log_path)
			if not started then
				mod.auto_upload_retry_after[log_path] = now + AUTO_UPLOAD_RETRY_DELAY_SECONDS
				notify_auto_upload_failure_once(
					log_path,
					"DTLogs: Automatic upload could not start: " .. tostring(start_error or "unknown upload error") .. ". The log is saved locally; retries will continue silently."
				)
			end
			return
		end
	end
end

local function poll_auto_upload_jobs()
	local jobs = mod.auto_upload_jobs or {}
	for index = #jobs, 1, -1 do
		local job = jobs[index]
		local status_text = read_small_file(job.status_path, 64)
		if status_text then
			local exit_code = tonumber(status_text:match("%-?%d+"))
			if exit_code ~= nil then
				mod.auto_upload_active_paths[job.log_path] = nil
				if exit_code == 0 then
					local response = read_small_file(job.response_path, 4096) or ""
					local log_id = response:match('"logId"%s*:%s*"([^\"]+)"')
					remove_from_auto_upload_queue(job.log_path)
					if log_id then
						mod:echo("DTLogs: Upload complete. Report queued on DTLogs.com (log ID: " .. tostring(log_id) .. ").")
					else
						mod:echo("DTLogs: Upload complete. Report queued for processing on DTLogs.com.")
					end
				else
					local http_status = AUTO_UPLOAD_AUTH.http_status(job.header_path)
					local auth_failure = job.upload_identity == "linked" and (http_status == 401 or http_status == 403)
					if auth_failure then
						mod.auto_upload_auth_blocked = true
						mod.auto_upload_auth_block_reason = "HTTP " .. tostring(http_status)
						mod.auto_upload_retry_after[job.log_path] = nil
						mod:echo("DTLogs: Linked upload authorization was rejected (HTTP " .. tostring(http_status) .. "). Automatic retries are paused.")
						mod:echo("DTLogs: The log remains saved locally and queued. Use /dtlogs_link with a new key or /dtlogs_unlink.")
					else
						mod.auto_upload_retry_after[job.log_path] = timestamp() + AUTO_UPLOAD_RETRY_DELAY_SECONDS
						local status_suffix = http_status and (" (HTTP " .. tostring(http_status) .. ")") or ""
						notify_auto_upload_failure_once(
							job.log_path,
							"DTLogs: Automatic upload failed" .. status_suffix .. ". The log is saved locally; retries will continue silently."
						)
					end
				end

				cleanup_auto_upload_job_files(job)
				table.remove(jobs, index)
			end
		elseif timestamp() - (job.started_at or timestamp()) > (AUTO_UPLOAD_MAX_TIME_SECONDS + 30) then
			mod.auto_upload_active_paths[job.log_path] = nil
			mod.auto_upload_retry_after[job.log_path] = timestamp() + AUTO_UPLOAD_RETRY_DELAY_SECONDS
			notify_auto_upload_failure_once(
				job.log_path,
				"DTLogs: Automatic upload timed out. The log is saved locally; retries will continue silently."
			)
			cleanup_auto_upload_job_files(job)
			table.remove(jobs, index)
		end
	end
end

local function vector_to_json(vector)
	if not vector then
		return "null"
	end

	local ok, x, y, z = pcall(function()
		return Vector3.to_elements(vector)
	end)

	if not ok then
		return "null"
	end

	return '{"x":' .. json_number(x)
		.. ',"y":' .. json_number(y)
		.. ',"z":' .. json_number(z)
		.. '}'
end

local function unit_position_json(unit)
	if not unit then
		return "null"
	end

	local ok, position = pcall(Unit.local_position, unit, 1)
	if not ok then
		return "null"
	end

	return vector_to_json(position)
end

local function player_from_unit(unit)
	if not unit or not Managers.player then
		return nil
	end

	local ok, players = pcall(function()
		return Managers.player:players()
	end)
	if not ok or not players then
		return nil
	end

	for _, player in pairs(players) do
		if player.player_unit == unit then
			return player
		end
	end

	return nil
end

local function network_unit(game_object_id)
	if game_object_id == nil or not Managers.state or not Managers.state.unit_spawner then
		return nil
	end

	local ok, unit = pcall(function()
		return Managers.state.unit_spawner:unit(game_object_id)
	end)
	return ok and unit or nil
end

local function buff_template_name(buff_template_id)
	if buff_template_id == nil or not NetworkLookup or not NetworkLookup.buff_templates then
		return nil
	end
	return NetworkLookup.buff_templates[buff_template_id]
end

local buff_registry_candidates = {
	"scripts/settings/buff/buff_templates",
	"scripts/settings/buff/player_archetype_buff_templates",
	"scripts/settings/buff/horde_buff_templates",
}

local loaded_buff_registries = nil

local function register_buff_registry(registries, registry, source)
	if type(registry) ~= "table" then
		return
	end
	registries[#registries + 1] = {table = registry, source = source}
end

local function get_buff_registries()
	if loaded_buff_registries then
		return loaded_buff_registries
	end

	local registries = {}
	register_buff_registry(registries, rawget(_G, "BuffTemplates"), "_G.BuffTemplates")

	for _, module_name in ipairs(buff_registry_candidates) do
		local ok, registry = pcall(require, module_name)
		if ok then
			register_buff_registry(registries, registry, module_name)
		end
	end

	if package and package.loaded then
		for module_name, registry in pairs(package.loaded) do
			if type(module_name) == "string" and string.find(string.lower(module_name), "buff") and type(registry) == "table" then
				register_buff_registry(registries, registry, "package.loaded:" .. module_name)
			end
		end
	end

	loaded_buff_registries = registries
	return registries
end

local function find_named_template(registry, name)
	if type(registry) ~= "table" then
		return nil
	end
	if type(registry[name]) == "table" then
		return registry[name]
	end
	for _, child in pairs(registry) do
		if type(child) == "table" and type(child[name]) == "table" then
			return child[name]
		end
	end
	return nil
end

local function buff_template(buff_template_id)
	local name = buff_template_name(buff_template_id)
	if not name then
		return nil, "network_lookup_missing"
	end

	for _, entry in ipairs(get_buff_registries()) do
		local template = find_named_template(entry.table, name)
		if template then
			return template, entry.source
		end
	end

	return nil, "registry_not_found"
end

local function template_from_buff_instance(self, server_index)
	if type(self) ~= "table" or server_index == nil then
		return nil, nil
	end

	-- Client RPCs use a server index that is translated to a local buff index.
	-- Looking directly in _buffs_by_index with the server index is only correct
	-- by accident, so resolve through _buff_index_map first.
	local local_index = self._buff_index_map and self._buff_index_map[server_index] or server_index
	local containers = {
		self._buffs_by_index,
		self._buffs,
		self._buff_instances,
		self._buffs_by_server_index,
	}

	for _, container in ipairs(containers) do
		if type(container) == "table" then
			local instance = container[local_index] or container[server_index]
			if type(instance) == "table" then
				local template = instance.template or instance.buff_template or instance._template or instance.config
				if type(template) == "function" then
					local ok, value = pcall(template, instance)
					template = ok and value or nil
				end
				if type(template) == "table" then
					return template, "extension_instance"
				end
			end
		end
	end

	return nil, nil
end

local function json_value(value, depth, seen)
	depth = depth or 0
	seen = seen or {}
	local value_type = type(value)

	if value == nil then
		return "null"
	elseif value_type == "boolean" then
		return value and "true" or "false"
	elseif value_type == "number" then
		return json_number(value)
	elseif value_type == "string" then
		return json_string(value)
	elseif value_type ~= "table" then
		return json_string("<" .. value_type .. ">")
	end

	if depth >= 3 or seen[value] then
		return json_string("<table>")
	end
	seen[value] = true

	local is_array = true
	local max_index = 0
	local count = 0
	for key, _ in pairs(value) do
		count = count + 1
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			is_array = false
		else
			max_index = math.max(max_index, key)
		end
		if count > 120 then
			break
		end
	end

	local result = {}
	if is_array and max_index <= 120 then
		for i = 1, max_index do
			result[#result + 1] = json_value(value[i], depth + 1, seen)
		end
		seen[value] = nil
		return "[" .. table.concat(result, ",") .. "]"
	end

	local keys = {}
	for key, _ in pairs(value) do
		keys[#keys + 1] = tostring(key)
		if #keys >= 120 then
			break
		end
	end
	table.sort(keys)
	for _, key_string in ipairs(keys) do
		local original_value = value[key_string]
		if original_value == nil then
			for original_key, candidate in pairs(value) do
				if tostring(original_key) == key_string then
					original_value = candidate
					break
				end
			end
		end
		result[#result + 1] = json_string(key_string) .. ":" .. json_value(original_value, depth + 1, seen)
	end
	seen[value] = nil
	return "{" .. table.concat(result, ",") .. "}"
end

local function buff_visibility(template)
	if type(template) ~= "table" then
		return nil, "template_missing", nil, false, nil
	end

	-- Only HUD-specific fields count. Generic template.icon is commonly a
	-- default editor/ability icon and does not mean the buff is drawn.
	local hud_priority = tonumber(template.hud_priority)
	local show_in_hud = template.show_in_hud
	if show_in_hud == nil then show_in_hud = template.show_in_buff_bar end
	if show_in_hud == nil then show_in_hud = template.show_in_hud_buff_bar end

	local hide_from_hud = template.hide_from_hud
	if hide_from_hud == nil then hide_from_hud = template.hide_in_hud end
	if hide_from_hud == nil then hide_from_hud = template.hide_in_buff_bar end

	local hud_icon = template.hud_icon
	local has_hud_icon = hud_icon ~= nil and hud_icon ~= false and tostring(hud_icon) ~= ""

	if hide_from_hud == true then
		return false, "hide_from_hud", hud_priority, has_hud_icon, show_in_hud
	elseif show_in_hud == false then
		return false, "show_in_hud_false", hud_priority, has_hud_icon, show_in_hud
	elseif show_in_hud == true then
		return true, "show_in_hud", hud_priority, has_hud_icon, show_in_hud
	elseif has_hud_icon then
		return true, "hud_icon", hud_priority, has_hud_icon, show_in_hud
	elseif hud_priority ~= nil then
		-- Presence is evidence even when the value is 0 or +/-infinity; the UI
		-- can use priority as ordering rather than a positive/negative flag.
		return true, "hud_priority", hud_priority, has_hud_icon, show_in_hud
	end

	-- We successfully resolved the template and found no HUD metadata.
	return false, "no_hud_metadata", hud_priority, has_hud_icon, show_in_hud
end

local function safe_player_name(player)
	if not player then
		return nil
	end

	local ok, value = pcall(function()
		return player:name()
	end)
	return ok and value or nil
end

local function safe_account_id(player)
	if not player then
		return nil
	end

	local ok, value = pcall(function()
		return player:account_id()
	end)
	return ok and value or nil
end

-- v0.13.21 player identity diagnostics. Darktide exposes account and operative
-- identities separately. Keep legacy `player_uuid` semantics unchanged for
-- backward compatibility; emit the real character id alongside it instead.
local function safe_character_id(player)
	if not player then
		return nil
	end

	local ok, value = pcall(function()
		return player:character_id()
	end)
	return ok and value or nil
end

local function unit_uuid(unit)
	if not unit then
		return nil
	end

	local player = player_from_unit(unit)
	if player then
		return safe_account_id(player) or safe_player_name(player)
	end

	local extension = ScriptUnit.has_extension(unit, "unit_data_system")
	if extension then
		local ok, component = pcall(function()
			return extension:read_component("uuid")
		end)

		if ok and component then
			return component.uuid or component.value
		end
	end

	return tostring(unit)
end

local function safe_breed_name(unit)
	if not unit then
		return nil, false
	end

	local extension = ScriptUnit.has_extension(unit, "unit_data_system")
	if not extension then
		return nil, false
	end

	local ok, breed = pcall(function()
		return extension:breed()
	end)

	if not ok or not breed then
		return nil, false
	end

	local is_minion = false
	if Breed and Breed.is_minion then
		local minion_ok, minion_result = pcall(Breed.is_minion, breed)
		is_minion = minion_ok and minion_result or false
	end

	return breed.name, is_minion
end

local function actor_type(unit)
	if not unit then
		return "environment"
	end

	if player_from_unit(unit) then
		return "player"
	end

	local breed_name, is_minion = safe_breed_name(unit)
	if is_minion or breed_name ~= nil then
		return "minion"
	end

	return "other"
end

local function safe_damage_profile_name(profile)
	if type(profile) == "string" then
		return profile
	end

	if type(profile) == "table" then
		return profile.name
			or profile.name_id
			or profile.template_name
			or profile.damage_profile_name
	end

	return nil
end

local function unit_from_network_id(unit_id, is_level_unit)
	if not Managers.state or not Managers.state.unit_spawner then
		return nil
	end

	local ok, unit = pcall(function()
		return Managers.state.unit_spawner:unit(unit_id, is_level_unit)
	end)

	return ok and unit or nil
end


local write_event
local guarded_event

local function safe_extension(unit, system_name)
	if not unit or not ScriptUnit or not ScriptUnit.has_extension then
		return nil
	end

	local ok, extension = pcall(ScriptUnit.has_extension, unit, system_name)
	return ok and extension or nil
end

local function safe_numeric_method(object, method_names)
	if not object then
		return nil
	end

	for _, method_name in ipairs(method_names) do
		local method = object[method_name]
		if type(method) == "function" then
			local ok, value = pcall(method, object)
			if ok and type(value) == "number" then
				return value
			end
		end
	end

	return nil
end

-- Ovenproof Scoreboard-compatible enemy damage accounting.
--
-- `scoreboard_damage` is the canonical combat-report metric from v0.13.15 onward.
-- It intentionally mirrors Ovenproof's `total_damage` behavior exactly:
--   * non-lethal minion hit: raw `damage`
--   * lethal minion hit: max_health - damage_taken
--   * Psykanium shooting range: Ovenproof's special correction
--
-- IMPORTANT: do not derive "overkill" as raw_damage - scoreboard_damage. Darktide's
-- health extension can legitimately make the Ovenproof value exceed the raw hit on
-- a small number of lethal events. The metric is still correct (and was validated
-- 4/4 players against Ovenproof), but that subtraction is not a valid overkill stat.
local function capture_enemy_damage_accounting(attacked_unit, target, numeric_damage, attack_result)
	local target_is_minion = target and target.is_minion == true

	if not target_is_minion then
		return nil, nil, false, "not_minion_target", nil, nil, nil, false
	end

	if numeric_damage <= 0 then
		return 0, nil, true, "zero_damage", nil, nil, nil, false
	end

	local scoreboard_damage = numeric_damage
	local accounting_source = "ovenproof_raw_nonlethal"
	local scoreboard_damage_outlier = false

	if attack_result == "died" then
		local health_extension = safe_extension(attacked_unit, "health_system")
		local damage_taken = safe_numeric_method(health_extension, {
			"damage_taken",
		})
		local max_health = safe_numeric_method(health_extension, {
			"max_health",
			"current_max_health",
		})

		if damage_taken ~= nil and max_health ~= nil then
			if mod.current_mission_name == "tg_shooting_range" then
				scoreboard_damage = max_health - damage_taken + numeric_damage
				accounting_source = "ovenproof_lethal_shooting_range"
			else
				scoreboard_damage = max_health - damage_taken
				accounting_source = "ovenproof_lethal_remaining_health"
			end
		else
			-- Do not drop damage if a future game build hides the health extension.
			-- This fallback is intentionally visible in mission diagnostics.
			scoreboard_damage = numeric_damage
			accounting_source = "ovenproof_lethal_health_unavailable"
			mod.enemy_damage_fallback_count = (mod.enemy_damage_fallback_count or 0) + 1
		end
	end

	-- Neutral diagnostic only. This is NOT treated as a damage-accounting error:
	-- Ovenproof can produce a lethal scoreboard value outside [0, raw_damage].
	scoreboard_damage_outlier = scoreboard_damage ~= nil and (
		scoreboard_damage < 0
		or (attack_result == "died" and scoreboard_damage > numeric_damage)
	)
	if scoreboard_damage_outlier then
		mod.scoreboard_damage_outlier_count = (mod.scoreboard_damage_outlier_count or 0) + 1
		-- Keep the old counter populated for consumers that already ingest it.
		mod.enemy_damage_accounting_anomaly_count = (mod.enemy_damage_accounting_anomaly_count or 0) + 1
	end

	-- overkill_damage is deliberately nil in semantics v6. `effective_damage` remains
	-- an alias of scoreboard_damage for backward compatibility.
	return scoreboard_damage, nil, true, accounting_source, nil, nil, nil, scoreboard_damage_outlier
end

local function read_player_resources(unit)
	local health_extension = safe_extension(unit, "health_system")
	local toughness_extension = safe_extension(unit, "toughness_system")

	local health = safe_numeric_method(health_extension, {
		"current_health",
		"health",
	})
	local max_health = safe_numeric_method(health_extension, {
		"current_max_health",
		"max_health",
	})
	local permanent_damage = safe_numeric_method(health_extension, {
		"permanent_damage_taken",
		"permanent_damage",
	})

	local toughness = safe_numeric_method(toughness_extension, {
		"current_toughness",
		"toughness",
	})
	local max_toughness = safe_numeric_method(toughness_extension, {
		"max_toughness",
		"current_max_toughness",
	})

	return {
		health = health,
		max_health = max_health,
		permanent_damage = permanent_damage,
		toughness = toughness,
		max_toughness = max_toughness,
	}
end

local function number_changed(previous, current, epsilon)
	if previous == nil or current == nil then
		return false
	end
	return math.abs(current - previous) >= (epsilon or 0.01)
end

local function write_health_change(unit, player, previous, current)
	local health_delta = current.health - previous.health
	local max_delta = nil
	if previous.max_health ~= nil and current.max_health ~= nil then
		max_delta = current.max_health - previous.max_health
	end

	if health_delta < 0 then
		mod.total_health_lost = mod.total_health_lost + math.abs(health_delta)
	elseif health_delta > 0 then
		mod.total_health_restored = mod.total_health_restored + health_delta
	end

	local change_type = health_delta < 0 and "damage" or "healing"
	if math.abs(health_delta) < 0.01 and max_delta ~= nil and math.abs(max_delta) >= 0.01 then
		change_type = "max_health_changed"
	end

	write_event("player_health_changed", {
		'"player_uuid":' .. json_string(unit_uuid(unit)),
		'"player_name":' .. json_string(safe_player_name(player)),
		'"previous_health":' .. json_number(previous.health),
		'"current_health":' .. json_number(current.health),
		'"delta":' .. json_number(health_delta),
		'"previous_max_health":' .. json_number(previous.max_health),
		'"current_max_health":' .. json_number(current.max_health),
		'"max_delta":' .. json_number(max_delta),
		'"previous_permanent_damage":' .. json_number(previous.permanent_damage),
		'"current_permanent_damage":' .. json_number(current.permanent_damage),
		'"change_type":' .. json_string(change_type),
		'"position":' .. unit_position_json(unit),
	}, false)
end

local function flush_toughness_recovery(unit, player, state, current, force)
	local pending = state.pending_toughness_recovery or 0
	if pending <= 0 then
		return
	end

	local now = mission_elapsed_ms()
	local started_at = state.pending_toughness_started_at or now
	if not force and pending < 5 and now - started_at < 500 then
		return
	end

	mod.total_toughness_restored = mod.total_toughness_restored + pending

	write_event("player_toughness_changed", {
		'"player_uuid":' .. json_string(unit_uuid(unit)),
		'"player_name":' .. json_string(safe_player_name(player)),
		'"previous_toughness":' .. json_number(current.toughness - pending),
		'"current_toughness":' .. json_number(current.toughness),
		'"delta":' .. json_number(pending),
		'"previous_max_toughness":' .. json_number(state.last_emitted_max_toughness),
		'"current_max_toughness":' .. json_number(current.max_toughness),
		'"change_type":"recovery"',
		'"aggregated":true',
		'"aggregation_ms":' .. json_number(now - started_at),
		'"position":' .. unit_position_json(unit),
	}, false)

	state.pending_toughness_recovery = 0
	state.pending_toughness_started_at = nil
	state.last_emitted_max_toughness = current.max_toughness
end

local function track_player_resources(unit, player)
	if not unit then
		return
	end

	local key = tostring(unit_uuid(unit))
	local current = read_player_resources(unit)
	local state = mod.player_resources[key]

	if not state then
		mod.player_resources[key] = {
			last = current,
			pending_toughness_recovery = 0,
			pending_toughness_started_at = nil,
			last_emitted_max_toughness = current.max_toughness,
		}
		return
	end

	local previous = state.last

	if current.health ~= nil and previous.health ~= nil then
		if previous.health <= 0.01 and current.health > 0.01 then
			write_event("player_resources_initialized", {
				'"player_uuid":' .. json_string(unit_uuid(unit)),
				'"player_name":' .. json_string(safe_player_name(player)),
				'"health":' .. json_number(current.health),
				'"max_health":' .. json_number(current.max_health),
				'"toughness":' .. json_number(current.toughness),
				'"max_toughness":' .. json_number(current.max_toughness),
				'"position":' .. unit_position_json(unit),
			}, false)
			state.last = current
			return
		end

		local health_changed = number_changed(previous.health, current.health, 0.01)
		local max_changed = number_changed(previous.max_health, current.max_health, 0.01)
		local corruption_changed = number_changed(previous.permanent_damage, current.permanent_damage, 0.01)
		if health_changed or max_changed or corruption_changed then
			write_health_change(unit, player, previous, current)
		end
	end

	if current.toughness ~= nil and previous.toughness ~= nil then
		local delta = current.toughness - previous.toughness
		local max_changed = number_changed(previous.max_toughness, current.max_toughness, 0.01)

		if delta < -0.01 then
			flush_toughness_recovery(unit, player, state, previous, true)
			mod.total_toughness_lost = mod.total_toughness_lost + math.abs(delta)

			write_event("player_toughness_changed", {
				'"player_uuid":' .. json_string(unit_uuid(unit)),
				'"player_name":' .. json_string(safe_player_name(player)),
				'"previous_toughness":' .. json_number(previous.toughness),
				'"current_toughness":' .. json_number(current.toughness),
				'"delta":' .. json_number(delta),
				'"previous_max_toughness":' .. json_number(previous.max_toughness),
				'"current_max_toughness":' .. json_number(current.max_toughness),
				'"change_type":"damage"',
				'"aggregated":false',
				'"position":' .. unit_position_json(unit),
			}, false)
			state.last_emitted_max_toughness = current.max_toughness
		elseif delta > 0.01 then
			if (state.pending_toughness_recovery or 0) <= 0 then
				state.pending_toughness_started_at = mission_elapsed_ms()
			end
			state.pending_toughness_recovery = (state.pending_toughness_recovery or 0) + delta
			flush_toughness_recovery(unit, player, state, current, false)
		elseif max_changed then
			flush_toughness_recovery(unit, player, state, current, true)
			write_event("player_toughness_changed", {
				'"player_uuid":' .. json_string(unit_uuid(unit)),
				'"player_name":' .. json_string(safe_player_name(player)),
				'"previous_toughness":' .. json_number(previous.toughness),
				'"current_toughness":' .. json_number(current.toughness),
				'"delta":0',
				'"previous_max_toughness":' .. json_number(previous.max_toughness),
				'"current_max_toughness":' .. json_number(current.max_toughness),
				'"change_type":"max_toughness_changed"',
				'"aggregated":false',
				'"position":' .. unit_position_json(unit),
			}, false)
			state.last_emitted_max_toughness = current.max_toughness
		end
	end

	state.last = current
end

local function poll_player_resources(dt)
	if not mod.current_file then
		return
	end

	mod.resource_poll_accumulator = (mod.resource_poll_accumulator or 0) + (dt or 0)
	if mod.resource_poll_accumulator < 0.1 then
		return
	end
	mod.resource_poll_accumulator = 0

	if not Managers.player then
		return
	end

	local ok, players = pcall(function()
		return Managers.player:players()
	end)
	if not ok or not players then
		return
	end

	for _, player in pairs(players) do
		local unit = player.player_unit
		if unit then
			guarded_event("PLAYER_RESOURCES", function()
				track_player_resources(unit, player)
			end)
		end
	end
end

local IMPORTANT_PLAYER_STATES = {
	dodging = true,
	dead = true,
	knocked_down = true,
	pounced = true,
	hogtied = true,
	mutant_charged = true,
	ledge_hanging = true,
	stunned = true,
	catapulted = true,
	interacting = true,
	disabled = true,
}

local function should_log_player_state(previous_state, current_state)
	if current_state == nil or current_state == previous_state then
		return false
	end

	return IMPORTANT_PLAYER_STATES[current_state] == true
		or IMPORTANT_PLAYER_STATES[previous_state] == true
end

local function event_dedup_key(...)
	local values = {...}
	for i = 1, #values do
		values[i] = tostring(values[i] or "")
	end
	return table.concat(values, "|")
end

local function should_log_slot_event(player_id, slot_name, event_name)
	local key = event_dedup_key(player_id, slot_name, event_name)
	local now = mission_elapsed_ms()
	local previous = mod.last_slot_events[key]

	mod.last_slot_events[key] = now

	return previous == nil or now - previous > 150
end

local function should_log_suppression(player_id, suppression_hits)
	local key = tostring(player_id or "")
	local now = mission_elapsed_ms()
	local previous = mod.last_suppression_events[key]

	if not previous then
		mod.last_suppression_events[key] = {
			time_ms = now,
			hits = suppression_hits,
		}
		return true
	end

	if previous.hits ~= suppression_hits or now - previous.time_ms >= 500 then
		previous.time_ms = now
		previous.hits = suppression_hits
		return true
	end

	return false
end

local function capture_clock_seconds()
	if Application and Application.time_since_launch then
		local ok, value = pcall(Application.time_since_launch)
		if ok and type(value) == "number" then
			return value
		end
	end
	if _os.clock then
		return _os.clock()
	end
	return timestamp()
end

local function json_string_array(values)
	if type(values) ~= "table" then
		return "[]"
	end
	local result = {}
	for i = 1, #values do
		result[#result + 1] = json_string(values[i])
	end
	return "[" .. table.concat(result, ",") .. "]"
end

local function position_snapshot(unit)
	if not unit then
		return nil
	end
	local ok_position, position = pcall(Unit.local_position, unit, 1)
	if not ok_position or not position then
		return nil
	end
	local ok_values, x, y, z = pcall(function()
		return Vector3.to_elements(position)
	end)
	if not ok_values then
		return nil
	end
	return {x = x, y = y, z = z}
end

local function position_snapshot_json(position)
	if type(position) ~= "table" then
		return "null"
	end
	return '{"x":' .. json_number(position.x)
		.. ',"y":' .. json_number(position.y)
		.. ',"z":' .. json_number(position.z)
		.. '}'
end


local function vector_snapshot(vector)
	if not vector then
		return nil
	end
	local ok, x, y, z = pcall(function()
		return Vector3.to_elements(vector)
	end)
	if not ok then
		return nil
	end
	return {x = x, y = y, z = z}
end

local function cached_event_position_snapshot(unit, now_ms)
	if not unit then
		return nil
	end
	now_ms = now_ms or mission_elapsed_ms()
	if mod.event_position_cache_time_ms ~= now_ms then
		mod.event_position_cache_time_ms = now_ms
		mod.event_position_cache = {}
	end
	local cached = mod.event_position_cache[unit]
	if cached ~= nil then
		return cached == false and nil or cached
	end
	local snapshot = position_snapshot(unit)
	mod.event_position_cache[unit] = snapshot or false
	return snapshot
end

local function refresh_player_unit_lookup(now_ms)
	now_ms = now_ms or mission_elapsed_ms()
	if mod.player_unit_lookup_time_ms == now_ms then
		return
	end
	mod.player_unit_lookup_time_ms = now_ms
	mod.player_unit_lookup = {}
	if not Managers.player then
		return
	end
	local ok, players = pcall(function()
		return Managers.player:players()
	end)
	if not ok or not players then
		return
	end
	for _, player in pairs(players) do
		local unit = player and player.player_unit
		if unit then
			mod.player_unit_lookup[unit] = player
		end
	end
end

local function cached_player_identity(unit, now_ms)
	if not unit then
		return nil
	end
	local stable = mod.stable_player_identity_cache[unit]
	if stable then
		return stable
	end
	refresh_player_unit_lookup(now_ms)
	local player = mod.player_unit_lookup[unit]
	if not player then
		return nil
	end
	local breed_name = safe_breed_name(unit)
	local account_id = safe_account_id(player)
	local character_id = safe_character_id(player)
	stable = {
		player = player,
		-- Legacy identity used by existing protocol=2 consumers. Do not change
		-- until the website parser has migrated to explicit account/character ids.
		uuid = account_id or safe_player_name(player),
		account_id = account_id,
		character_id = character_id,
		name = safe_player_name(player),
		breed = breed_name,
	}
	mod.stable_player_identity_cache[unit] = stable
	return stable
end

local function nonplayer_uuid(unit)
	if not unit then
		return nil
	end
	local extension = ScriptUnit.has_extension(unit, "unit_data_system")
	if extension then
		local ok, component = pcall(function()
			return extension:read_component("uuid")
		end)
		if ok and component then
			return component.uuid or component.value or tostring(unit)
		end
	end
	return tostring(unit)
end

local function capture_actor_snapshot(unit, now_ms)
	if not unit then
		return {
			actor_type = "environment",
			uuid = nil,
			name = nil,
			breed = nil,
			position = nil,
			is_player = false,
			is_minion = false,
		}
	end
	now_ms = now_ms or mission_elapsed_ms()
	if mod.actor_snapshot_cache_time_ms ~= now_ms then
		mod.actor_snapshot_cache_time_ms = now_ms
		mod.actor_snapshot_cache = {}
	end
	local cached = mod.actor_snapshot_cache[unit]
	if cached then
		return cached
	end
	local player_identity = cached_player_identity(unit, now_ms)
	local snapshot
	if player_identity then
		snapshot = {
			actor_type = "player",
			uuid = player_identity.uuid,
			account_id = player_identity.account_id,
			character_id = player_identity.character_id,
			name = player_identity.name,
			breed = player_identity.breed,
			position = cached_event_position_snapshot(unit, now_ms),
			is_player = true,
			is_minion = false,
		}
	else
		local breed_name, is_minion = safe_breed_name(unit)
		snapshot = {
			-- Keep actor_type backward-compatible: older DTLogs versions treated any
			-- non-player unit with a breed as "minion". `is_minion` below is the
			-- authoritative enemy-minion flag for damage accounting.
			actor_type = (is_minion or breed_name ~= nil) and "minion" or "other",
			uuid = nonplayer_uuid(unit),
			name = nil,
			breed = breed_name,
			position = cached_event_position_snapshot(unit, now_ms),
			is_player = false,
			is_minion = is_minion == true,
		}
	end
	mod.actor_snapshot_cache[unit] = snapshot
	return snapshot
end

local function clear_capture_queue()
	mod.capture_queue = {}
	mod.capture_queue_head = 1
	mod.capture_queue_tail = 0
	mod.capture_queue_count = 0
	mod.active_buff_batch = nil
end

local function clear_pending_lines()
	mod.pending_lines = {}
	mod.pending_line_head = 1
	mod.pending_line_tail = 0
	mod.pending_line_count = 0
	mod.pending_line_bytes = 0
end

local function reserve_event_metadata(event_name, time_ms_override, timestamp_override)
	mod.event_count = mod.event_count + 1
	mod.event_type_counts[event_name] = (mod.event_type_counts[event_name] or 0) + 1
	return {
		event_index = mod.event_count,
		timestamp = timestamp_override or timestamp(),
		time_ms = time_ms_override or mission_elapsed_ms(),
	}
end

local function queue_capture_item(item)
	mod.capture_queue_tail = mod.capture_queue_tail + 1
	mod.capture_queue[mod.capture_queue_tail] = item
	mod.capture_queue_count = mod.capture_queue_count + 1
	if mod.capture_queue_count > (mod.capture_queue_peak or 0) then
		mod.capture_queue_peak = mod.capture_queue_count
	end
end

local function enqueue_event_item(event_name, payload_kind, payload, time_ms_override, timestamp_override)
	if not mod.current_file then
		return false
	end

	-- Any non-batched logical event closes the current contiguous buff run.
	mod.active_buff_batch = nil
	local metadata = reserve_event_metadata(event_name, time_ms_override, timestamp_override)
	queue_capture_item({
		event_name = event_name,
		event_index = metadata.event_index,
		timestamp = metadata.timestamp,
		time_ms = metadata.time_ms,
		payload_kind = payload_kind or "prepared",
		payload = payload,
	})
	return true
end

local function enqueue_buff_batch_event(logical_event_name, batch_event_name, payload_kind, batch_key, common_payload, entry_payload, time_ms_override, timestamp_override)
	if not mod.current_file then
		return false
	end

	local metadata = reserve_event_metadata(logical_event_name, time_ms_override, timestamp_override)
	local active = mod.active_buff_batch
	local max_entries = mod.buff_batch_max_entries or 64
	local can_append = active
		and active.batch_key == batch_key
		and active.payload_kind == payload_kind
		and active.time_ms == metadata.time_ms
		and active.event_index_end + 1 == metadata.event_index
		and #active.payload.entries < max_entries

	if not can_append then
		common_payload.entries = {}
		common_payload.event_index_end = metadata.event_index
		active = {
			batch_key = batch_key,
			payload_kind = payload_kind,
			time_ms = metadata.time_ms,
			event_index_end = metadata.event_index,
			payload = common_payload,
		}
		mod.active_buff_batch = active
		queue_capture_item({
			event_name = batch_event_name,
			event_index = metadata.event_index,
			timestamp = metadata.timestamp,
			time_ms = metadata.time_ms,
			payload_kind = payload_kind,
			payload = common_payload,
		})
		mod.buff_batch_line_count = (mod.buff_batch_line_count or 0) + 1
	else
		active.event_index_end = metadata.event_index
		active.payload.event_index_end = metadata.event_index
	end

	entry_payload.event_index = metadata.event_index
	active.payload.entries[#active.payload.entries + 1] = entry_payload
	active.payload.event_index_end = metadata.event_index
	mod.buff_batch_logical_event_count = (mod.buff_batch_logical_event_count or 0) + 1
	if #active.payload.entries > (mod.buff_batch_peak_entries or 0) then
		mod.buff_batch_peak_entries = #active.payload.entries
	end
	return true
end

local function safe_lua_memory_kb()
	if not collectgarbage then
		return nil
	end
	local ok, value = pcall(collectgarbage, "count")
	if ok and type(value) == "number" then
		return value
	end
	return nil
end

local function round_milliseconds(seconds)
	local value = math.max(0, tonumber(seconds) or 0) * 1000
	return math.floor(value * 1000 + 0.5) / 1000
end

local function reset_performance_diagnostics()
	mod.performance_spike_count = 0
	mod.performance_spike_written_count = 0
	mod.performance_spike_dropped = 0
	mod.performance_spike_counts = {}
	mod.pending_performance_spikes = {}
	mod.pending_performance_spike_head = 1
	mod.pending_performance_spike_tail = 0
	mod.pending_performance_spike_count = 0
	mod.max_performance_duration_ms = {}
	mod.max_performance_label = {}
	mod.last_update_metrics = {}
	mod.last_lua_memory_kb = safe_lua_memory_kb()
end

local function note_performance_duration(kind, duration_seconds, label)
	local duration_ms = round_milliseconds(duration_seconds)
	local previous = mod.max_performance_duration_ms[kind] or 0
	if duration_ms > previous then
		mod.max_performance_duration_ms[kind] = duration_ms
		mod.max_performance_label[kind] = label
	end
	return duration_ms
end

local function record_performance_spike(kind, duration_seconds, label, details, observed_time_ms)
	if not mod.current_file then
		return false
	end

	local duration_ms = note_performance_duration(kind, duration_seconds, label)
	local threshold = (mod.performance_threshold_seconds and mod.performance_threshold_seconds[kind]) or 0.002
	if (tonumber(duration_seconds) or 0) < threshold then
		return false
	end

	if (mod.performance_spike_count or 0) >= (mod.performance_spike_limit or 500) then
		mod.performance_spike_dropped = (mod.performance_spike_dropped or 0) + 1
		return false
	end

	local spike = {
		kind = kind,
		label = label,
		duration_ms = duration_ms,
		observed_time_ms = observed_time_ms or mission_elapsed_ms(),
		observed_timestamp = timestamp(),
		details = details or {},
	}
	mod.pending_performance_spike_tail = mod.pending_performance_spike_tail + 1
	mod.pending_performance_spikes[mod.pending_performance_spike_tail] = spike
	mod.pending_performance_spike_count = mod.pending_performance_spike_count + 1
	mod.performance_spike_count = mod.performance_spike_count + 1
	mod.performance_spike_counts[kind] = (mod.performance_spike_counts[kind] or 0) + 1
	return true
end

local function performance_spike_fields(spike)
	local fields = {
		'"diagnostic_version":1',
		'"spike_kind":' .. json_string(spike.kind),
		'"label":' .. json_string(spike.label),
		'"duration_ms":' .. json_number(spike.duration_ms),
		'"observed_time_ms":' .. json_number(spike.observed_time_ms),
		'"observed_timestamp":' .. json_number(spike.observed_timestamp),
	}

	local keys = {}
	for key, _ in pairs(spike.details or {}) do
		if type(key) == "string" and string.match(key, "^[A-Za-z0-9_]+$") then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	for i = 1, #keys do
		local key = keys[i]
		fields[#fields + 1] = json_string(key) .. ":" .. json_value(spike.details[key])
	end
	return fields
end

local function drain_pending_performance_spikes(max_count)
	if not mod.current_file or (mod.pending_performance_spike_count or 0) <= 0 then
		return 0
	end
	local drained = 0
	local limit = max_count or 16
	while mod.pending_performance_spike_count > 0 and drained < limit do
		local index = mod.pending_performance_spike_head
		local spike = mod.pending_performance_spikes[index]
		mod.pending_performance_spikes[index] = nil
		mod.pending_performance_spike_head = index + 1
		mod.pending_performance_spike_count = mod.pending_performance_spike_count - 1
		if spike then
			enqueue_event_item("performance_spike", "prepared", performance_spike_fields(spike))
			mod.performance_spike_written_count = (mod.performance_spike_written_count or 0) + 1
		end
		drained = drained + 1
	end
	if mod.pending_performance_spike_count <= 0 then
		mod.pending_performance_spikes = {}
		mod.pending_performance_spike_head = 1
		mod.pending_performance_spike_tail = 0
		mod.pending_performance_spike_count = 0
	end
	return drained
end

local function append_actor_fields(fields, prefix, actor, include_breed)
	actor = actor or {}
	fields[#fields + 1] = '"' .. prefix .. '_type":' .. json_string(actor.actor_type)
	fields[#fields + 1] = '"' .. prefix .. '_uuid":' .. json_string(actor.uuid)
	fields[#fields + 1] = '"' .. prefix .. '_account_id":' .. json_string(actor.account_id)
	fields[#fields + 1] = '"' .. prefix .. '_character_id":' .. json_string(actor.character_id)
	fields[#fields + 1] = '"' .. prefix .. '_name":' .. json_string(actor.name)
	if include_breed then
		fields[#fields + 1] = '"' .. prefix .. '_breed":' .. json_string(actor.breed)
	end
	fields[#fields + 1] = '"' .. prefix .. '_position":' .. position_snapshot_json(actor.position)
end

local function serialize_buff_added_batch_entries(entries)
	local result = {}
	for i = 1, #(entries or {}) do
		local entry = entries[i]
		result[#result + 1] = '{"event_index":' .. tostring(entry.event_index)
			.. ',"server_indices":' .. json_number_array(entry.server_indices)
			.. ',"buff_instance_ids":' .. json_string_array(entry.buff_instance_ids)
			.. ',"buff_instance_id":' .. json_string(entry.buff_instance_ids and entry.buff_instance_ids[1] or nil)
			.. ',"added_stacks":' .. json_number(entry.added_stacks)
			.. ',"stack_count_before":' .. json_number(entry.stack_count_before)
			.. ',"stack_count_after":' .. json_number(entry.stack_count_after)
			.. ',"effective_stack_count_before":' .. json_number(entry.effective_stack_count_before)
			.. ',"effective_stack_count_after":' .. json_number(entry.effective_stack_count_after)
			.. ',"max_stacks":' .. json_number(entry.max_stacks)
			.. ',"max_stacks_cap":' .. json_number(entry.max_stacks_cap)
			.. ',"duration":' .. json_number(entry.duration)
			.. ',"extra_duration":' .. json_number(entry.extra_duration)
			.. ',"game_start_time":' .. json_number(entry.game_start_time)
			.. ',"predicted":' .. (entry.predicted == nil and 'null' or tostring(entry.predicted == true))
			.. '}'
	end
	return '[' .. table.concat(result, ',') .. ']'
end

local function serialize_buff_removed_batch_entries(entries)
	local result = {}
	for i = 1, #(entries or {}) do
		local entry = entries[i]
		result[#result + 1] = '{"event_index":' .. tostring(entry.event_index)
			.. ',"server_index":' .. json_number(entry.server_index)
			.. ',"buff_instance_id":' .. json_string(entry.buff_instance_id)
			.. ',"buff_generation":' .. json_number(entry.buff_generation)
			.. ',"cache_miss":' .. tostring(entry.cache_miss == true)
			.. ',"removed_stacks":' .. json_number(entry.removed_stacks)
			.. ',"stack_count_before":' .. json_number(entry.stack_count_before)
			.. ',"stack_count_after":' .. json_number(entry.stack_count_after)
			.. ',"effective_stack_count_before":' .. json_number(entry.effective_stack_count_before)
			.. ',"effective_stack_count_after":' .. json_number(entry.effective_stack_count_after)
			.. ',"max_stacks":' .. json_number(entry.max_stacks)
			.. ',"max_stacks_cap":' .. json_number(entry.max_stacks_cap)
			.. '}'
	end
	return '[' .. table.concat(result, ',') .. ']'
end

local function serialize_raw_payload(item, fields)
	local data = item.payload or {}
	local kind = item.payload_kind

	if kind == "buff_definition" then
		fields[#fields + 1] = '"definition_version":1'
		fields[#fields + 1] = '"buff_template_id":' .. json_number(data.buff_template_id)
		fields[#fields + 1] = '"buff_template_name":' .. json_string(data.buff_template_name)
		fields[#fields + 1] = '"is_visible_to_player":' .. (data.is_visible_to_player == nil and "null" or tostring(data.is_visible_to_player == true))
		fields[#fields + 1] = '"visibility_source":' .. json_string(data.visibility_source)
		fields[#fields + 1] = '"hud_priority":' .. json_number(data.hud_priority)
		fields[#fields + 1] = '"has_hud_icon":' .. tostring(data.has_hud_icon == true)
		fields[#fields + 1] = '"hud_icon":' .. json_string(data.hud_icon)
		fields[#fields + 1] = '"show_in_hud":' .. (data.show_in_hud == nil and "null" or tostring(data.show_in_hud == true))
		fields[#fields + 1] = '"buff_template_source":' .. json_string(data.buff_template_source)
		fields[#fields + 1] = '"buff_template_parameters":' .. json_value(data.buff_template)
	elseif kind == "buff_added_batch" then
		fields[#fields + 1] = '"batch_version":3'
		fields[#fields + 1] = '"logical_event":"player_buff_added"'
		fields[#fields + 1] = '"event_index_end":' .. tostring(data.event_index_end or item.event_index)
		fields[#fields + 1] = '"logical_event_count":' .. tostring(#(data.entries or {}))
		fields[#fields + 1] = '"player_uuid":' .. json_string(data.player_uuid)
		fields[#fields + 1] = '"account_id":' .. json_string(data.account_id)
		fields[#fields + 1] = '"character_id":' .. json_string(data.character_id)
		fields[#fields + 1] = '"player_name":' .. json_string(data.player_name)
		fields[#fields + 1] = '"buff_template_id":' .. json_number(data.buff_template_id)
		fields[#fields + 1] = '"buff_template_name":' .. json_string(data.buff_template_name)
		fields[#fields + 1] = '"parent_buff_template_id":' .. json_number(data.parent_buff_template_id)
		fields[#fields + 1] = '"parent_buff_template_name":' .. json_string(data.parent_buff_template_name)
		fields[#fields + 1] = '"optional_lerp_value":' .. json_number(data.optional_lerp_value)
		fields[#fields + 1] = '"optional_item_slot_id":' .. json_number(data.optional_item_slot_id)
		local talent_name = data.from_talent_name
		local from_talent = talent_name ~= nil and talent_name ~= "n/a"
		-- Keep `from_specialization` as a legacy boolean alias for older parsers.
		fields[#fields + 1] = '"from_specialization":' .. tostring(from_talent)
		fields[#fields + 1] = '"talent_id":' .. json_number(from_talent and data.from_talent_id or nil)
		fields[#fields + 1] = '"talent_name":' .. json_string(from_talent and talent_name or nil)
		fields[#fields + 1] = '"owner_unit_id":' .. json_number(data.owner_unit_id)
		fields[#fields + 1] = '"owner_player_uuid":' .. json_string(data.owner_player_uuid)
		fields[#fields + 1] = '"owner_player_name":' .. json_string(data.owner_player_name)
		fields[#fields + 1] = '"capture_source":' .. json_string(data.capture_source)
		fields[#fields + 1] = '"extension_class":' .. json_string(data.extension_class)
		fields[#fields + 1] = '"position":' .. position_snapshot_json(data.position)
		fields[#fields + 1] = '"instances":' .. serialize_buff_added_batch_entries(data.entries)
	elseif kind == "buff_removed_batch" then
		fields[#fields + 1] = '"batch_version":3'
		fields[#fields + 1] = '"logical_event":"player_buff_removed"'
		fields[#fields + 1] = '"event_index_end":' .. tostring(data.event_index_end or item.event_index)
		fields[#fields + 1] = '"logical_event_count":' .. tostring(#(data.entries or {}))
		fields[#fields + 1] = '"player_uuid":' .. json_string(data.player_uuid)
		fields[#fields + 1] = '"account_id":' .. json_string(data.account_id)
		fields[#fields + 1] = '"character_id":' .. json_string(data.character_id)
		fields[#fields + 1] = '"player_name":' .. json_string(data.player_name)
		fields[#fields + 1] = '"buff_template_id":' .. json_number(data.buff_template_id)
		fields[#fields + 1] = '"buff_template_name":' .. json_string(data.buff_template_name)
		fields[#fields + 1] = '"capture_source":' .. json_string(data.capture_source)
		fields[#fields + 1] = '"extension_class":' .. json_string(data.extension_class)
		fields[#fields + 1] = '"position":' .. position_snapshot_json(data.position)
		fields[#fields + 1] = '"instances":' .. serialize_buff_removed_batch_entries(data.entries)
	elseif kind == "attack_result_raw" then
		append_actor_fields(fields, "attacker", data.attacker, false)
		append_actor_fields(fields, "target", data.target, true)
		fields[#fields + 1] = '"target_is_minion":' .. tostring(data.target_is_minion == true)
		fields[#fields + 1] = '"damage_profile":' .. json_string(data.damage_profile)
		-- `damage` remains raw hit damage for backward compatibility and highest-hit analytics.
		fields[#fields + 1] = '"damage":' .. json_number(data.damage)
		-- Canonical report metric. `effective_damage` is retained as a compatibility alias.
		fields[#fields + 1] = '"effective_damage":' .. json_number(data.effective_damage)
		fields[#fields + 1] = '"scoreboard_damage":' .. json_number(data.scoreboard_damage or data.effective_damage)
		-- Deprecated from damage_semantics_version=6: Ovenproof total_damage is not an overkill metric.
		fields[#fields + 1] = '"overkill_damage":null'
		fields[#fields + 1] = '"overkill_semantics_available":false'
		fields[#fields + 1] = '"damage_accounting_source":' .. json_string(data.damage_accounting_source)
		-- Legacy diagnostic fields are kept nullable for schema compatibility.
		fields[#fields + 1] = '"target_health_before":null'
		fields[#fields + 1] = '"target_health_after":null'
		fields[#fields + 1] = '"health_cache_hit":null'
		fields[#fields + 1] = '"scoreboard_damage_outlier":' .. tostring(data.damage_accounting_anomaly == true)
		fields[#fields + 1] = '"damage_accounting_anomaly":' .. tostring(data.damage_accounting_anomaly == true)
		fields[#fields + 1] = '"weakspot":' .. tostring(data.weakspot == true)
		fields[#fields + 1] = '"critical":' .. tostring(data.critical == true)
		fields[#fields + 1] = '"result":' .. json_string(data.result)
		fields[#fields + 1] = '"attack_type":' .. json_string(data.attack_type)
		fields[#fields + 1] = '"damage_efficiency":' .. json_number(data.damage_efficiency)
		fields[#fields + 1] = '"attack_direction":' .. position_snapshot_json(data.attack_direction)
		fields[#fields + 1] = '"hit_position":' .. position_snapshot_json(data.hit_position)
	elseif kind == "player_damage_taken_raw" then
		local target = data.target or {}
		fields[#fields + 1] = '"player_uuid":' .. json_string(target.uuid)
		fields[#fields + 1] = '"account_id":' .. json_string(target.account_id)
		fields[#fields + 1] = '"character_id":' .. json_string(target.character_id)
		fields[#fields + 1] = '"player_name":' .. json_string(target.name)
		fields[#fields + 1] = '"player_position":' .. position_snapshot_json(target.position)
		append_actor_fields(fields, "attacker", data.attacker, true)
		fields[#fields + 1] = '"damage_profile":' .. json_string(data.damage_profile)
		fields[#fields + 1] = '"damage":' .. json_number(data.damage)
		fields[#fields + 1] = '"result":' .. json_string(data.result)
		fields[#fields + 1] = '"attack_type":' .. json_string(data.attack_type)
		fields[#fields + 1] = '"damage_efficiency":' .. json_number(data.damage_efficiency)
		fields[#fields + 1] = '"attack_direction":' .. position_snapshot_json(data.attack_direction)
		fields[#fields + 1] = '"hit_position":' .. position_snapshot_json(data.hit_position)
	end
end

local function serialize_event_item(item)
	local fields = {
		'"protocol":2',
		'"event":' .. json_string(item.event_name),
		'"event_index":' .. tostring(item.event_index),
		'"timestamp":' .. tostring(item.timestamp),
		'"time_ms":' .. tostring(item.time_ms),
		'"session_id":' .. json_string(mod.current_session_id),
	}

	if item.payload_kind == "prepared" then
		if item.payload then
			for _, field in ipairs(item.payload) do
				fields[#fields + 1] = field
			end
		end
	else
		serialize_raw_payload(item, fields)
	end

	return "{" .. table.concat(fields, ",") .. "}\n"
end

local function append_pending_line(line)
	mod.pending_line_tail = mod.pending_line_tail + 1
	mod.pending_lines[mod.pending_line_tail] = line
	mod.pending_line_count = mod.pending_line_count + 1
	mod.pending_line_bytes = (mod.pending_line_bytes or 0) + #line
	if mod.pending_line_count > (mod.pending_line_peak or 0) then
		mod.pending_line_peak = mod.pending_line_count
	end
	if mod.pending_line_bytes > (mod.pending_line_byte_peak or 0) then
		mod.pending_line_byte_peak = mod.pending_line_bytes
	end
end

local function process_capture_queue(force_all)
	if mod.capture_queue_count <= 0 then
		return 0, 0
	end

	-- No hook may append to a batch once serialization for this frame starts.
	mod.active_buff_batch = nil
	local processed = 0
	local queue_before = mod.capture_queue_count or 0
	local pending_before = mod.pending_line_count or 0
	local pending_bytes_before = mod.pending_line_bytes or 0
	local started_at = capture_clock_seconds()
	local max_events = force_all and math.huge or (mod.max_events_serialized_per_frame or 48)
	local budget = mod.serialize_time_budget_seconds or 0.0005

	while mod.capture_queue_count > 0 and processed < max_events do
		local item = mod.capture_queue[mod.capture_queue_head]
		mod.capture_queue[mod.capture_queue_head] = nil
		mod.capture_queue_head = mod.capture_queue_head + 1
		mod.capture_queue_count = mod.capture_queue_count - 1

		if item then
			append_pending_line(serialize_event_item(item))
			mod.serialized_event_count = (mod.serialized_event_count or 0) + 1
			mod.physical_line_count = (mod.physical_line_count or 0) + 1
		end
		processed = processed + 1

		-- Batch records are heavier than ordinary records, so check after every item.
		if not force_all and capture_clock_seconds() - started_at >= budget then
			break
		end
	end

	local duration_seconds = capture_clock_seconds() - started_at
	local queue_after = mod.capture_queue_count or 0
	local pending_after = mod.pending_line_count or 0
	local pending_bytes_after = mod.pending_line_bytes or 0
	if not force_all then
		local threshold = (mod.performance_threshold_seconds and mod.performance_threshold_seconds.serialize) or 0.002
		if duration_seconds >= threshold then
			record_performance_spike("serialize", duration_seconds, "capture_queue", {
				events_processed = processed,
				queue_before = queue_before,
				queue_after = queue_after,
				pending_lines_before = pending_before,
				pending_lines_after = pending_after,
				pending_bytes_before = pending_bytes_before,
				pending_bytes_after = pending_bytes_after,
				current_event_count = mod.event_count or 0,
				lua_memory_kb = safe_lua_memory_kb(),
			})
		else
			note_performance_duration("serialize", duration_seconds, "capture_queue")
		end
	end

	if mod.capture_queue_count <= 0 then
		clear_capture_queue()
	end
	return processed, duration_seconds
end

local function write_pending_byte_chunk(suppress_performance_event)
	local file = mod.current_file
	if not file or mod.pending_line_count <= 0 then
		return 0, 0, 0
	end

	local pending_before = mod.pending_line_count or 0
	local pending_bytes_before = mod.pending_line_bytes or 0
	local byte_limit = mod.max_bytes_per_write or 65536
	local chunk = {}
	local line_count = 0
	local byte_count = 0
	while mod.pending_line_count > 0 do
		local index = mod.pending_line_head
		local line = mod.pending_lines[index]
		local line_bytes = line and #line or 0
		if line_count > 0 and byte_count + line_bytes > byte_limit then
			break
		end
		line_count = line_count + 1
		chunk[line_count] = line
		byte_count = byte_count + line_bytes
		mod.pending_lines[index] = nil
		mod.pending_line_head = index + 1
		mod.pending_line_count = mod.pending_line_count - 1
		mod.pending_line_bytes = math.max(0, (mod.pending_line_bytes or 0) - line_bytes)
		if byte_count >= byte_limit then
			break
		end
	end

	local duration_seconds = 0
	if line_count > 0 then
		local started_at = capture_clock_seconds()
		file:write(table.concat(chunk))
		duration_seconds = capture_clock_seconds() - started_at
		mod.write_chunk_count = (mod.write_chunk_count or 0) + 1
		if byte_count > (mod.max_write_chunk_bytes or 0) then
			mod.max_write_chunk_bytes = byte_count
		end
		if not suppress_performance_event then
			local threshold = (mod.performance_threshold_seconds and mod.performance_threshold_seconds.write) or 0.002
			if duration_seconds >= threshold then
				record_performance_spike("write", duration_seconds, "file_write", {
					lines_written = line_count,
					bytes_written = byte_count,
					pending_lines_before = pending_before,
					pending_lines_after = mod.pending_line_count or 0,
					pending_bytes_before = pending_bytes_before,
					pending_bytes_after = mod.pending_line_bytes or 0,
					queue_after = mod.capture_queue_count or 0,
					current_event_count = mod.event_count or 0,
					lua_memory_kb = safe_lua_memory_kb(),
				})
			else
				note_performance_duration("write", duration_seconds, "file_write")
			end
		end
	end

	if mod.pending_line_count <= 0 then
		clear_pending_lines()
	end
	return line_count, byte_count, duration_seconds
end

local function measured_file_flush(label, suppress_performance_event)
	if not mod.current_file then
		return 0
	end
	local started_at = capture_clock_seconds()
	mod.current_file:flush()
	local duration_seconds = capture_clock_seconds() - started_at
	if not suppress_performance_event then
		local threshold = (mod.performance_threshold_seconds and mod.performance_threshold_seconds.flush) or 0.002
		if duration_seconds >= threshold then
			record_performance_spike("flush", duration_seconds, label or "periodic_flush", {
				queue_after = mod.capture_queue_count or 0,
				pending_lines_after = mod.pending_line_count or 0,
				pending_bytes_after = mod.pending_line_bytes or 0,
				current_event_count = mod.event_count or 0,
				lua_memory_kb = safe_lua_memory_kb(),
			})
		else
			note_performance_duration("flush", duration_seconds, label or "periodic_flush")
		end
	end
	return duration_seconds
end

local function drain_event_buffer(force_flush, force_all)
	local file = mod.current_file
	if not file then
		clear_capture_queue()
		clear_pending_lines()
		mod.write_accumulator = 0
		mod.flush_accumulator = 0
		return false
	end

	if force_all then
		process_capture_queue(true)
	end

	if force_all then
		while mod.pending_line_count > 0 do
			write_pending_byte_chunk(true)
		end
	else
		write_pending_byte_chunk(force_flush == true)
	end

	if force_flush then
		measured_file_flush("forced_flush", true)
		mod.flush_accumulator = 0
	end
	mod.write_accumulator = 0
	return true
end

write_event = function(event_name, extra_fields, force_flush)
	local queued = enqueue_event_item(event_name, "prepared", extra_fields)
	if queued and force_flush then
		drain_event_buffer(true, true)
	end
	return queued
end

local function write_raw_event(event_name, payload_kind, payload, time_ms_override, timestamp_override)
	return enqueue_event_item(event_name, payload_kind, payload, time_ms_override, timestamp_override)
end

local function write_buff_batch_event(logical_event_name, batch_event_name, payload_kind, batch_key, common_payload, entry_payload, time_ms_override, timestamp_override)
	return enqueue_buff_batch_event(
		logical_event_name,
		batch_event_name,
		payload_kind,
		batch_key,
		common_payload,
		entry_payload,
		time_ms_override,
		timestamp_override
	)
end

local function close_current_file()
	local close_success = true
	local close_error = nil
	local file = mod.current_file

	if file then
		local ok, result, error_message = pcall(function()
			drain_pending_performance_spikes(math.huge)
			drain_event_buffer(true, true)

			local close_result, file_error = file:close()
			if close_result == nil or close_result == false then
				return false, file_error
			end

			return true, nil
		end)

		if not ok then
			close_success = false
			close_error = result
		elseif result == false then
			close_success = false
			close_error = error_message
		end

		if not close_success then
			-- Best-effort cleanup if writing/flushing/closing failed.
			pcall(function()
				file:close()
			end)
		end
	end

	mod.current_file = nil
	mod.current_file_path = nil
	mod.current_session_id = nil
	mod.modifier_startup_snapshot_written = false
	mod.modifier_final_snapshot_written = false
	mod.current_game_version = nil
	mod.current_game_version_source = nil
	mod.current_game_build_identifier = nil
	mod.current_game_build_mode = nil
	mod.current_game_teamcity_build_id = nil
	mod.mission_start_time_ms = nil
	mod.event_count = 0
	clear_capture_queue()
	mod.capture_queue_peak = 0
	clear_pending_lines()
	mod.pending_line_peak = 0
	mod.pending_line_byte_peak = 0
	mod.write_accumulator = 0
	mod.flush_accumulator = 0
	mod.buff_definitions_written = {}
	mod.buff_definition_count = 0
	mod.buff_position_cache_time_ms = nil
	mod.buff_position_cache = {}
	mod.serialized_event_count = 0
	mod.physical_line_count = 0
	mod.write_chunk_count = 0
	mod.max_write_chunk_bytes = 0
	mod.active_buff_batch = nil
	mod.buff_batch_line_count = 0
	mod.buff_batch_logical_event_count = 0
	mod.buff_batch_peak_entries = 0
	mod.player_unit_lookup_time_ms = nil
	mod.player_unit_lookup = {}
	mod.stable_player_identity_cache = {}
	mod.actor_snapshot_cache_time_ms = nil
	mod.actor_snapshot_cache = {}
	mod.event_position_cache_time_ms = nil
	mod.event_position_cache = {}
	mod.buff_game_object_unit_cache = {}
	mod.buff_template_name_cache = {}
	mod.active_interactions = {}
	mod.player_ability_num_charges = {}
	mod.active_player_states = {}
	mod.last_slot_events = {}
	mod.last_suppression_events = {}
	mod.event_type_counts = {}
	mod.total_actual_damage = 0
	mod.total_effective_enemy_damage = 0
	mod.total_overkill_damage = 0
	mod.enemy_damage_event_count = 0
	mod.enemy_damage_fallback_count = 0
	mod.enemy_health_cache = {}
	mod.enemy_health_cache_hit_count = 0
	mod.enemy_health_cache_miss_count = 0
	mod.enemy_health_cache_seed_count = 0
	mod.enemy_health_read_fallback_count = 0
	mod.enemy_damage_accounting_anomaly_count = 0 -- deprecated alias; see scoreboard_damage_outlier_count
	mod.scoreboard_damage_outlier_count = 0
	mod.zero_damage_event_count = 0
	mod.total_player_damage_taken = 0
	mod.player_resources = {}
	mod.active_player_buffs = {}
	mod.buff_generations = {}
	mod.resource_poll_accumulator = 0
	mod.total_health_lost = 0
	mod.total_health_restored = 0
	mod.total_toughness_lost = 0
	mod.total_toughness_restored = 0
	mod.profile_probe_accumulator = 0
	mod.profile_snapshot_players = {}
	mod.profile_pending_logged = {}
	mod.profile_probe_started_ms = nil
	mod.profile_probe_finished = false
	mod.profile_snapshot_count = 0
	mod.profile_late_join_snapshot_count = 0
	mod.gameplay_clock_sync_count = 0
	mod.gameplay_clock_first_server_sync_ms = nil
	mod.gameplay_clock_first_sync_offset = nil
	mod.gameplay_clock_first_sync_recording_elapsed_ms = nil
	mod.gameplay_clock_first_observed_ms = nil
	mod.gameplay_clock_last_observed_ms = nil
	mod.gameplay_state_enter_observed = false
	mod.gameplay_state_exit_observed = false
	mod.session_join_event_count = 0
	mod.session_leave_event_count = 0
	mod.presence_peer_identity = {}
	mod.presence_initial_snapshot_written = false
	mod.presence_final_snapshot_written = false
	mod.mission_end_observed = false
	reset_performance_diagnostics()

	return close_success, close_error
end

local function is_recordable_mission(mission_name)
	return mission_name ~= nil
		and mission_name ~= "hub"
		and mission_name ~= "hub_ship"
		and mission_name ~= "tg_shooting_range" -- Psykanium / Meat Grinder
end

local function call_difficulty_manager(manager, method_name)
	if type(manager) ~= "table" then
		return nil
	end

	local method = manager[method_name]
	if type(method) ~= "function" then
		return nil
	end

	local ok, value = pcall(method, manager)
	if ok then
		return value
	end

	return nil
end

local function danger_settings_for_pair(challenge, resistance)
	if type(DangerSettings) ~= "table" then
		return nil
	end

	challenge = tonumber(challenge)
	resistance = tonumber(resistance)
	if not challenge or not resistance then
		return nil
	end

	for i, danger in ipairs(DangerSettings) do
		if type(danger) == "table"
			and tonumber(danger.challenge) == challenge
			and tonumber(danger.resistance) == resistance
		then
			return danger
		end
	end

	return nil
end

local function live_havoc_rank(manager)
	local parsed = call_difficulty_manager(manager, "get_parsed_havoc_data")
	local rank = havoc_rank_from_data(parsed)

	if rank then
		return rank
	end

	-- Keep the StateGameplay mechanism value as the fallback. v0.13.8 already
	-- validated this source against the live Havoc manager.
	return mod.current_havoc_rank
end

local function poll_difficulty_resolution(force)
	if not mod.current_file or mod.difficulty_resolution_written then
		return false
	end

	-- DifficultyManager is created shortly after StateGameplay:on_enter. Waiting
	-- one second prevents a stale manager from the previous state being sampled
	-- while still resolving long before normal mission activity matters.
	if not force and mission_elapsed_ms() < 1000 then
		return false
	end

	local manager = Managers
		and Managers.state
		and Managers.state.difficulty
		or nil

	if type(manager) ~= "table" then
		return false
	end

	local effective_challenge = call_difficulty_manager(manager, "get_challenge")
	local effective_resistance = call_difficulty_manager(manager, "get_resistance")
	if effective_challenge == nil or effective_resistance == nil then
		return false
	end

	local initial_challenge = call_difficulty_manager(manager, "get_initial_challenge")
	local initial_resistance = call_difficulty_manager(manager, "get_initial_resistance")
	local danger = call_difficulty_manager(manager, "get_danger_settings")

	if type(danger) ~= "table" then
		danger = danger_settings_for_pair(effective_challenge, effective_resistance)
	end

	local danger_name = type(danger) == "table" and danger.name or nil
	local danger_index = type(danger) == "table" and danger.index or nil
	local danger_difficulty = type(danger) == "table" and danger.difficulty or nil
	local danger_is_auric = nil
	if type(danger) == "table" then
		danger_is_auric = danger.is_auric == true
	end
	local danger_localization_key = type(danger) == "table" and danger.display_name or nil

	local havoc_rank = mod.current_difficulty_mode == "havoc"
		and live_havoc_rank(manager)
		or nil

	-- If this is Havoc and the live rank is not visible yet, wait unless this
	-- is the final forced attempt at mission end. The base mechanism rank stays
	-- available as a fallback there.
	if mod.current_difficulty_mode == "havoc" and havoc_rank == nil and not force then
		return false
	end

	mod.current_effective_challenge = tonumber(effective_challenge) or effective_challenge
	mod.current_effective_resistance = tonumber(effective_resistance) or effective_resistance
	mod.current_initial_challenge = tonumber(initial_challenge) or initial_challenge
	mod.current_initial_resistance = tonumber(initial_resistance) or initial_resistance
	mod.current_danger_name = danger_name
	mod.current_danger_index = tonumber(danger_index) or danger_index
	mod.current_danger_difficulty = tonumber(danger_difficulty) or danger_difficulty
	mod.current_danger_is_auric = danger_is_auric
	mod.current_danger_localization_key = danger_localization_key
	if havoc_rank ~= nil then
		mod.current_havoc_rank = havoc_rank
	end

	write_event("mission_difficulty_resolved", {
		'"difficulty_mode":' .. json_string(mod.current_difficulty_mode),
		'"havoc_rank":' .. json_number(mod.current_havoc_rank),
		'"difficulty_context_version":2',
		'"mission_modifier_semantics_version":1',
		'"mission_modifier_semantics_status":"stable_ids"',
		'"mission_modifiers":' .. json_value(mod.current_mission_modifiers),
		'"mission_modifiers_source":' .. json_string(mod.current_mission_modifiers_source),
		'"mission_modifier_diagnostic_version":1',
		'"modifier_mechanism_context":' .. json_value(mod.current_modifier_mechanism_context),
		'"havoc_data_raw":' .. json_value(mod.current_havoc_data_raw),
		'"base_challenge":' .. json_number(tonumber(mod.current_challenge)),
		'"base_resistance":' .. json_number(tonumber(mod.current_resistance)),
		'"initial_challenge":' .. json_number(tonumber(mod.current_initial_challenge)),
		'"initial_resistance":' .. json_number(tonumber(mod.current_initial_resistance)),
		'"effective_challenge":' .. json_number(tonumber(mod.current_effective_challenge)),
		'"effective_resistance":' .. json_number(tonumber(mod.current_effective_resistance)),
		'"danger_name":' .. json_string(mod.current_danger_name),
		'"danger_index":' .. json_number(tonumber(mod.current_danger_index)),
		'"danger_difficulty":' .. json_number(tonumber(mod.current_danger_difficulty)),
		'"danger_is_auric":' .. json_boolean(mod.current_danger_is_auric),
		'"danger_localization_key":' .. json_string(mod.current_danger_localization_key),
		'"resolution_source":"difficulty_manager"',
	}, true)

	mod.difficulty_resolution_written = true
	return true
end

-- Forward declaration: modifier diagnostics run before the mission-clock helper
-- body appears later in this file. v0.13.19 called the name before its local
-- declaration, which made Lua resolve a nil global and aborted mod.update every
-- frame. Keep one local binding and assign its implementation below.
local safe_gameplay_clock_ms

-- Modifier metadata probing remains diagnostic in v0.13.20. Canonical high-level
-- modifier ids are now captured separately as mission_modifier_semantics_version=1.
-- A single circumstance_name represents normal mission Conditions, while Havoc
-- can carry multiple user-facing modifier cards and a larger set of low-level
-- gameplay mutators.
-- user-facing modifier cards and a larger set of low-level gameplay mutators.
-- Until live logs prove which runtime structure is the stable high-level source,
-- record a bounded, modifier-specific snapshot instead of guessing or emitting
-- every low-level mutator as a website-visible modifier.
local function modifier_key_is_relevant(key, include_generic_name_fields)
	local text = string.lower(tostring(key or ""))
	if string.find(text, "circumstance", 1, true)
		or string.find(text, "mutator", 1, true)
		or string.find(text, "modifier", 1, true)
		or string.find(text, "havoc", 1, true)
	then
		return true
	end

	if include_generic_name_fields then
		return text == "name"
			or text == "display_name"
			or text == "display_name_key"
			or text == "display_title"
			or text == "title"
			or text == "description"
			or text == "description_key"
			or text == "display_description"
			or text == "icon"
			or text == "hud_icon"
			or text == "tier"
			or text == "level"
			or text == "localization_key"
	end

	return false
end

local function modifier_relevant_fields(source, include_generic_name_fields)
	if type(source) ~= "table" then
		return nil
	end

	local result = {}
	local count = 0
	for key, value in pairs(source) do
		if modifier_key_is_relevant(key, include_generic_name_fields) then
			result[tostring(key)] = value
			count = count + 1
			if count >= 80 then
				break
			end
		end
	end

	return next(result) ~= nil and result or nil
end

local function modifier_relevant_keys(source)
	if type(source) ~= "table" then
		return {}
	end

	local result = {}
	for key, _ in pairs(source) do
		if modifier_key_is_relevant(key, false) then
			result[#result + 1] = tostring(key)
			if #result >= 80 then
				break
			end
		end
	end
	table.sort(result)
	return result
end

local function probe_read_only_accessors(manager, accessor_names)
	if type(manager) ~= "table" or type(accessor_names) ~= "table" then
		return nil
	end

	local result = {}
	for i = 1, #accessor_names do
		local name = accessor_names[i]
		local ok_field, member = pcall(function()
			return manager[name]
		end)
		if ok_field and member ~= nil then
			if type(member) == "function" then
				local ok_call, value = pcall(member, manager)
				if ok_call then
					result[name] = value
				else
					result[name] = "<call_failed>"
				end
			else
				result[name] = member
			end
		end
	end

	return next(result) ~= nil and result or nil
end

local function modifier_manager_probe(manager, kind)
	if type(manager) ~= "table" then
		return { available = false }
	end

	local accessor_names
	if kind == "circumstance" then
		accessor_names = {
			"get_current_circumstance",
			"get_circumstance_name",
			"get_active_circumstance",
		}
	else
		accessor_names = {
			"get_active_mutators",
			"get_mutators",
			"get_mutator_names",
		}
	end

	local relevant_fields = modifier_relevant_fields(manager, false)
	local relevant_keys = modifier_relevant_keys(manager)
	local meta = getmetatable(manager)
	local class_table = type(meta) == "table" and meta.__index or nil
	local class_relevant_keys = modifier_relevant_keys(class_table)

	return {
		available = true,
		relevant_fields = relevant_fields,
		relevant_keys = relevant_keys,
		class_relevant_keys = class_relevant_keys,
		read_only_accessors = probe_read_only_accessors(manager, accessor_names),
	}
end

local function collect_modifier_identifiers(value, output, seen, depth)
	output = output or {}
	seen = seen or {}
	depth = depth or 0

	if depth > 4 or #output >= 80 then
		return output
	end

	local value_type = type(value)
	if value_type == "string" then
		local lower = string.lower(value)
		if string.find(lower, "mutator", 1, true) or string.find(lower, "circumstance", 1, true) then
			output[#output + 1] = value
		end
		return output
	elseif value_type ~= "table" or seen[value] then
		return output
	end

	seen[value] = true
	local visited = 0
	for key, child in pairs(value) do
		visited = visited + 1
		if visited > 160 or #output >= 80 then
			break
		end

		if type(key) == "string" then
			local lower_key = string.lower(key)
			if string.find(lower_key, "mutator", 1, true) or string.find(lower_key, "circumstance", 1, true) then
				output[#output + 1] = key
			end
		end
		collect_modifier_identifiers(child, output, seen, depth + 1)
	end
	seen[value] = nil

	return output
end

local function unique_sorted_strings(values)
	local seen = {}
	local result = {}
	for i = 1, #(values or {}) do
		local value = tostring(values[i])
		if value ~= "" and not seen[value] then
			seen[value] = true
			result[#result + 1] = value
		end
	end
	table.sort(result)
	return result
end

local function modifier_template_diagnostics(candidate_ids)
	local result = {}
	for i = 1, #(candidate_ids or {}) do
		local id = candidate_ids[i]
		local template = type(MutatorTemplates) == "table" and MutatorTemplates[id] or nil
		if type(template) == "table" then
			result[id] = modifier_relevant_fields(template, true) or { name = template.name }
		end
	end
	return next(result) ~= nil and result or nil
end

local function current_circumstance_template_diagnostic()
	if type(CircumstanceTemplates) ~= "table" or mod.current_circumstance == nil then
		return nil
	end

	local template = CircumstanceTemplates[mod.current_circumstance]
	if type(template) ~= "table" then
		return nil
	end

	return modifier_relevant_fields(template, true) or { name = template.name }
end

local function write_modifier_context_snapshot(reason, force)
	if not mod.current_file then
		return false
	end

	if reason == "startup_probe" and mod.modifier_startup_snapshot_written then
		return false
	end
	if reason == "mission_end" and mod.modifier_final_snapshot_written then
		return false
	end

	-- Wait until the normal mission managers have had time to initialize. A
	-- forced mission-end snapshot is always allowed.
	if not force and mission_elapsed_ms() < 1000 then
		return false
	end

	local state = Managers and Managers.state or nil
	local difficulty_manager = type(state) == "table" and state.difficulty or nil
	local parsed_havoc_data = call_difficulty_manager(difficulty_manager, "get_parsed_havoc_data")
	local circumstance_manager = type(state) == "table" and state.circumstance or nil
	local mutator_manager = type(state) == "table" and state.mutator or nil

	-- Some builds expose these managers outside Managers.state. Capture those
	-- read-only references only as fallback; never invoke mutation methods.
	if circumstance_manager == nil and type(Managers) == "table" then
		circumstance_manager = Managers.circumstance
	end
	if mutator_manager == nil and type(Managers) == "table" then
		mutator_manager = Managers.mutator
	end

	local circumstance_probe = modifier_manager_probe(circumstance_manager, "circumstance")
	local mutator_probe = modifier_manager_probe(mutator_manager, "mutator")
	local candidate_ids = {}
	if mod.current_circumstance ~= nil and tostring(mod.current_circumstance) ~= "" and tostring(mod.current_circumstance) ~= "default" then
		candidate_ids[#candidate_ids + 1] = tostring(mod.current_circumstance)
	end
	collect_modifier_identifiers(mod.current_modifier_mechanism_context, candidate_ids)
	collect_modifier_identifiers(parsed_havoc_data, candidate_ids)
	collect_modifier_identifiers(circumstance_probe, candidate_ids)
	collect_modifier_identifiers(mutator_probe, candidate_ids)
	candidate_ids = unique_sorted_strings(candidate_ids)

	write_event("mission_modifier_context_snapshot", {
		'"mission_modifier_diagnostic_version":1',
		'"mission_modifier_semantics_version":1',
		'"mission_modifier_semantics_status":"stable_ids"',
		'"diagnostic_metadata_status":"diagnostic_only"',
		'"canonical_modifiers":' .. json_value(mod.current_mission_modifiers),
		'"snapshot_reason":' .. json_string(reason),
		'"recording_elapsed_ms":' .. json_number(mission_elapsed_ms()),
		'"gameplay_clock_ms":' .. json_number(safe_gameplay_clock_ms()),
		'"difficulty_mode":' .. json_string(mod.current_difficulty_mode),
		'"havoc_rank":' .. json_number(mod.current_havoc_rank),
		'"circumstance_name":' .. json_string(mod.current_circumstance),
		'"mechanism_modifier_context":' .. json_value(mod.current_modifier_mechanism_context),
		'"havoc_data_raw":' .. json_value(mod.current_havoc_data_raw),
		'"difficulty_parsed_havoc_data":' .. json_value(parsed_havoc_data),
		'"circumstance_template":' .. json_value(current_circumstance_template_diagnostic()),
		'"circumstance_manager_probe":' .. json_value(circumstance_probe),
		'"mutator_manager_probe":' .. json_value(mutator_probe),
		'"candidate_modifier_ids":' .. json_value(candidate_ids),
		'"candidate_mutator_templates":' .. json_value(modifier_template_diagnostics(candidate_ids)),
	}, true)

	if reason == "startup_probe" then
		mod.modifier_startup_snapshot_written = true
	elseif reason == "mission_end" then
		mod.modifier_final_snapshot_written = true
	end

	return true
end

local function start_mission_file()
	-- Always close the previous mission file when StateGameplay changes.
	-- Previously, a transition into hub/hub_ship could return before closing the
	-- previous file. Because the StateGameplay hook also resets
	-- difficulty_resolution_written, the hub DifficultyManager could then append
	-- a second mission_difficulty_resolved event to the old mission log.
	--
	-- Closing first makes mission ownership unambiguous: a mission file belongs
	-- only to the StateGameplay instance that created it.
	close_current_file()

	if not is_recordable_mission(mod.current_mission_name) then
		return false
	end

	create_output_directory()

	local started_at = timestamp()
	mod.mission_start_time_ms = monotonic_time_ms()
	mod.current_session_id = tostring(started_at) .. "-" .. tostring(math.random(100000, 999999))

	local safe_mission = tostring(mod.current_mission_name or "unknown")
	safe_mission = string.gsub(safe_mission, '[<>:"/\\\\|?*]', "_")

	local file_name =
		"mission_"
		.. tostring(started_at)
		.. "_"
		.. safe_mission
		.. "_"
		.. mod.current_session_id
		.. ".jsonl"

	mod.current_file_path = output_directory() .. file_name

	local file, error_message = _io.open(mod.current_file_path, "w+")
	if not file then
		mod:echo("DTLogs: failed to create the mission log file: " .. tostring(error_message))
		mod.current_file_path = nil
		mod.current_session_id = nil
		return false
	end

	mod.current_file = file
	clear_capture_queue()
	mod.capture_queue_peak = 0
	clear_pending_lines()
	mod.pending_line_peak = 0
	mod.pending_line_byte_peak = 0
	mod.write_accumulator = 0
	mod.flush_accumulator = 0
	mod.buff_definitions_written = {}
	mod.buff_definition_count = 0
	mod.buff_position_cache_time_ms = nil
	mod.buff_position_cache = {}
	mod.serialized_event_count = 0
	mod.physical_line_count = 0
	mod.write_chunk_count = 0
	mod.max_write_chunk_bytes = 0
	mod.active_buff_batch = nil
	mod.buff_batch_line_count = 0
	mod.buff_batch_logical_event_count = 0
	mod.buff_batch_peak_entries = 0
	mod.player_unit_lookup_time_ms = nil
	mod.player_unit_lookup = {}
	mod.stable_player_identity_cache = {}
	mod.actor_snapshot_cache_time_ms = nil
	mod.actor_snapshot_cache = {}
	mod.event_position_cache_time_ms = nil
	mod.event_position_cache = {}
	mod.buff_game_object_unit_cache = {}
	mod.buff_template_name_cache = {}
	mod.active_player_buffs = {}
	mod.buff_generations = {}
	mod.profile_probe_accumulator = 0
	mod.profile_snapshot_players = {}
	mod.profile_pending_logged = {}
	mod.profile_probe_started_ms = mission_elapsed_ms()
	mod.profile_probe_finished = false
	mod.profile_snapshot_count = 0
	mod.profile_late_join_snapshot_count = 0
	mod.gameplay_clock_sync_count = 0
	mod.gameplay_clock_first_server_sync_ms = nil
	mod.gameplay_clock_first_sync_offset = nil
	mod.gameplay_clock_first_sync_recording_elapsed_ms = nil
	mod.gameplay_clock_first_observed_ms = nil
	mod.gameplay_clock_last_observed_ms = nil
	mod.gameplay_state_enter_observed = false
	mod.gameplay_state_exit_observed = false
	mod.session_join_event_count = 0
	mod.session_leave_event_count = 0
	mod.presence_peer_identity = {}
	mod.presence_initial_snapshot_written = false
	mod.presence_final_snapshot_written = false
	mod.mission_end_observed = false
	mod.modifier_startup_snapshot_written = false
	mod.modifier_final_snapshot_written = false
	reset_performance_diagnostics()

	local game_build_metadata = get_game_build_metadata()
	mod.current_game_version = game_build_metadata.game_version
	mod.current_game_version_source = game_build_metadata.game_version_source
	mod.current_game_build_identifier = game_build_metadata.game_build_identifier
	mod.current_game_build_mode = game_build_metadata.game_build_mode
	mod.current_game_teamcity_build_id = game_build_metadata.game_teamcity_build_id

	write_event("mission_started", {
		'"mission_name":' .. json_string(mod.current_mission_name),
		'"circumstance":' .. json_string(mod.current_circumstance),
		'"challenge":' .. json_string(mod.current_challenge),
		'"resistance":' .. json_string(mod.current_resistance),
		'"difficulty_mode":' .. json_string(mod.current_difficulty_mode),
		'"havoc_rank":' .. json_number(mod.current_havoc_rank),
		'"difficulty_context_version":2',
		'"mission_modifier_semantics_version":1',
		'"mission_modifier_semantics_status":"stable_ids"',
		'"mission_modifiers":' .. json_value(mod.current_mission_modifiers),
		'"mission_modifiers_source":' .. json_string(mod.current_mission_modifiers_source),
		'"mission_modifier_diagnostic_version":1',
		'"modifier_mechanism_context":' .. json_value(mod.current_modifier_mechanism_context),
		'"havoc_data_raw":' .. json_value(mod.current_havoc_data_raw),
		'"damage_semantics_version":6',
		'"damage_metric":"ovenproof_total_damage"',
		'"overkill_semantics_available":false',
		'"presence_diagnostic_version":1',
		'"gameplay_clock_diagnostic_version":1',
		'"presence_semantics_version":1',
		'"player_identity_diagnostic_version":1',
		'"player_identity_semantics_version":1',
		'"player_identity_semantics_status":"stable_character_id"',
		'"mission_recording_status":"pending"',
		'"buff_capture_semantics_version":7',
		'"buff_hook_capabilities":' .. json_value(mod.buff_hook_capabilities),
		'"mod_version":' .. json_string(MOD_VERSION),
		'"game_version":' .. json_string(mod.current_game_version),
		'"game_version_source":' .. json_string(mod.current_game_version_source),
		'"game_build_identifier":' .. json_string(mod.current_game_build_identifier),
		'"game_build_mode":' .. json_string(mod.current_game_build_mode),
		'"game_teamcity_build_id":' .. json_string(mod.current_game_teamcity_build_id),
		'"capture_focus":"startup_and_late_join_build_loadout_exact_timeline_batched_buffs_exact_stack_semantics_proc_state_setters_proc_rpc_predicted_lifecycle_callbacks_hook_require_resolution_buff_hook_capabilities_perf_diagnostics_difficulty_context_v2_scoreboard_damage_v6_ovenproof_total_damage_presence_clock_semantics_v1_player_identity_semantics_v1_mission_modifier_ids_v1_modifier_context_diagnostics_v1"',
		'"performance_diagnostic_version":1',
		'"frame_spike_threshold_ms":50',
		'"hook_spike_threshold_ms":2.5',
		'"serialize_spike_threshold_ms":2',
		'"write_spike_threshold_ms":2',
		'"flush_spike_threshold_ms":2',
		'"addon_update_spike_threshold_ms":3',
	}, true)

	write_event("mission_modifiers_resolved", {
		'"mission_modifier_semantics_version":1',
		'"mission_modifier_semantics_status":"stable_ids"',
		'"difficulty_mode":' .. json_string(mod.current_difficulty_mode),
		'"havoc_rank":' .. json_number(mod.current_havoc_rank),
		'"circumstance_name":' .. json_string(mod.current_circumstance),
		'"mission_modifiers":' .. json_value(mod.current_mission_modifiers),
		'"mission_modifiers_source":' .. json_string(mod.current_mission_modifiers_source),
	}, true)

	return true
end

guarded_event = function(label, callback)
	local started_at = capture_clock_seconds()
	local observed_time_ms = mission_elapsed_ms()
	local ok, error_message = pcall(callback)
	local duration_seconds = capture_clock_seconds() - started_at
	local threshold = (mod.performance_threshold_seconds and mod.performance_threshold_seconds.hook) or 0.0025
	if duration_seconds >= threshold then
		record_performance_spike("hook", duration_seconds, label, {
			queue_after = mod.capture_queue_count or 0,
			pending_lines_after = mod.pending_line_count or 0,
			pending_bytes_after = mod.pending_line_bytes or 0,
			current_event_count = mod.event_count or 0,
			lua_memory_kb = safe_lua_memory_kb(),
		}, observed_time_ms)
	else
		note_performance_duration("hook", duration_seconds, label)
	end
	if not ok then
		mod:echo("DTLogs " .. label .. " ERROR: " .. tostring(error_message))
	end
end


local function safe_hook(class_name, method_name, callback)
	local class = CLASS and CLASS[class_name]

	if not class then
		mod:echo("DTLogs: hook skipped for " .. class_name .. "." .. method_name .. " — class not found")
		return false
	end

	local ok, error_message = pcall(function()
		mod:hook(class, method_name, callback)
	end)

	if not ok then
		mod:echo(
			"DTLogs: hook skipped for "
			.. class_name
			.. "."
			.. method_name
			.. " — "
			.. tostring(error_message)
		)
		return false
	end

	return true
end

-- v0.13.18 mission clock / participant presence semantics -------------------
safe_gameplay_clock_ms = function()
	if not Managers or not Managers.time then
		return nil
	end

	local ok, value = pcall(function()
		return Managers.time:time("gameplay")
	end)
	value = ok and tonumber(value) or nil
	if value == nil then
		return nil
	end

	return math.floor(value * 1000 + 0.5)
end

local RECORDING_START_AMBIGUITY_MS = 250

local function recording_start_gameplay_clock_estimate_ms()
	local server_sync_ms = tonumber(mod.gameplay_clock_first_server_sync_ms)
	local local_elapsed_ms = tonumber(mod.gameplay_clock_first_sync_recording_elapsed_ms)
	if server_sync_ms == nil or local_elapsed_ms == nil then
		return nil
	end
	return server_sync_ms - local_elapsed_ms
end

local function mission_recording_status()
	local estimate_ms = recording_start_gameplay_clock_estimate_ms()
	if estimate_ms == nil then
		return "unknown"
	end
	if estimate_ms < -RECORDING_START_AMBIGUITY_MS then
		return "full"
	elseif estimate_ms > RECORDING_START_AMBIGUITY_MS then
		return "partial"
	end
	return "unknown"
end

local function safe_network_peer_id()
	if not Network or type(Network.peer_id) ~= "function" then
		return nil
	end
	local ok, value = pcall(function()
		return Network.peer_id()
	end)
	return ok and value or nil
end

local function joined_peer_snapshot(session_manager)
	local raw_peer_ids = {}
	local peer_id_strings = {}
	if not session_manager then
		return raw_peer_ids, peer_id_strings
	end

	local ok, peers = pcall(function()
		return session_manager:joined_peers()
	end)
	if not ok or type(peers) ~= "table" then
		return raw_peer_ids, peer_id_strings
	end

	for peer_id, joined in pairs(peers) do
		if joined == true then
			raw_peer_ids[#raw_peer_ids + 1] = peer_id
		end
	end
	table.sort(raw_peer_ids, function(left, right)
		return tostring(left) < tostring(right)
	end)
	for i = 1, #raw_peer_ids do
		peer_id_strings[i] = tostring(raw_peer_ids[i])
	end
	return raw_peer_ids, peer_id_strings
end

local function resolve_peer_players(peer_id)
	local resolved = {}
	if not Managers or not Managers.player or peer_id == nil then
		return resolved
	end

	local ok, players = pcall(function()
		return Managers.player:players_at_peer(peer_id)
	end)
	if not ok or type(players) ~= "table" then
		return resolved
	end

	for local_player_id, player in pairs(players) do
		local unit = nil
		pcall(function()
			unit = player.player_unit
		end)
		local account_id = safe_account_id(player)
		local character_id = safe_character_id(player)
		local player_uuid = account_id or unit_uuid(unit)
		local player_name = safe_player_name(player)
		resolved[#resolved + 1] = {
			local_player_id = local_player_id,
			player_uuid = player_uuid,
			account_id = account_id,
			character_id = character_id,
			player_name = player_name,
		}
		if player_uuid ~= nil or player_name ~= nil then
			mod.presence_peer_identity[tostring(peer_id)] = {
				player_uuid = player_uuid,
				account_id = account_id,
				character_id = character_id,
				player_name = player_name,
			}
		end
	end

	table.sort(resolved, function(left, right)
		return tostring(left.local_player_id) < tostring(right.local_player_id)
	end)
	return resolved
end

local function resolved_players_json(raw_peer_ids)
	local entries = {}
	local count = 0
	for i = 1, #(raw_peer_ids or {}) do
		local peer_id = raw_peer_ids[i]
		local players = resolve_peer_players(peer_id)
		for j = 1, #players do
			local player = players[j]
			entries[#entries + 1] = '{"peer_id":' .. json_string(tostring(peer_id))
				.. ',"local_player_id":' .. json_value(player.local_player_id)
				.. ',"player_uuid":' .. json_string(player.player_uuid)
				.. ',"account_id":' .. json_string(player.account_id)
				.. ',"character_id":' .. json_string(player.character_id)
				.. ',"player_name":' .. json_string(player.player_name)
				.. '}'
			count = count + 1
		end
	end
	return '[' .. table.concat(entries, ',') .. ']', count
end

local function write_presence_roster_snapshot(reason, force_flush)
	if not mod.current_file then
		return false
	end

	local session_manager = Managers and Managers.state and Managers.state.game_session or nil
	local raw_peer_ids, peer_id_strings = joined_peer_snapshot(session_manager)
	local players_json, resolved_count = resolved_players_json(raw_peer_ids)
	local gameplay_clock_ms = safe_gameplay_clock_ms()
	if gameplay_clock_ms ~= nil then
		mod.gameplay_clock_last_observed_ms = gameplay_clock_ms
		if mod.gameplay_clock_first_observed_ms == nil then
			mod.gameplay_clock_first_observed_ms = gameplay_clock_ms
		end
	end

	write_event("presence_roster_snapshot", {
		'"presence_diagnostic_version":1',
		'"player_identity_diagnostic_version":1',
		'"player_identity_semantics_version":1',
		'"snapshot_reason":' .. json_string(reason),
		'"recording_elapsed_ms":' .. json_number(mission_elapsed_ms()),
		'"gameplay_clock_ms":' .. json_number(gameplay_clock_ms),
		'"recorder_peer_id":' .. json_string(safe_network_peer_id()),
		'"peer_count":' .. tostring(#peer_id_strings),
		'"peer_ids":' .. json_string_array(peer_id_strings),
		'"resolved_player_count":' .. tostring(resolved_count),
		'"resolved_players":' .. players_json,
	}, force_flush == true)

	return true
end

local function peer_identity_fields(peer_id)
	local identity = nil
	local players = resolve_peer_players(peer_id)
	if #players > 0 then
		identity = players[1]
	elseif peer_id ~= nil then
		identity = mod.presence_peer_identity[tostring(peer_id)]
	end
	return identity and identity.player_uuid or nil,
		identity and identity.account_id or nil,
		identity and identity.character_id or nil,
		identity and identity.player_name or nil
end

local function write_session_presence_event(event_name, peer_id, channel_id, game_reason, engine_reason, source)
	if not mod.current_file then
		return
	end
	local gameplay_clock_ms = safe_gameplay_clock_ms()
	if gameplay_clock_ms ~= nil then
		mod.gameplay_clock_last_observed_ms = gameplay_clock_ms
	end
	local player_uuid, account_id, character_id, player_name = peer_identity_fields(peer_id)
	write_event(event_name, {
		'"presence_diagnostic_version":1',
		'"player_identity_diagnostic_version":1',
		'"player_identity_semantics_version":1',
		'"source":' .. json_string(source),
		'"peer_id":' .. json_string(peer_id and tostring(peer_id) or nil),
		'"channel_id":' .. json_number(channel_id),
		'"player_uuid":' .. json_string(player_uuid),
		'"account_id":' .. json_string(account_id),
		'"character_id":' .. json_string(character_id),
		'"player_name":' .. json_string(player_name),
		'"game_reason":' .. json_string(game_reason),
		'"engine_reason":' .. json_string(engine_reason),
		'"recording_elapsed_ms":' .. json_number(mission_elapsed_ms()),
		'"gameplay_clock_ms":' .. json_number(gameplay_clock_ms),
	}, false)
end


-- v0.13.7 profile / talent / loadout snapshots ------------------------------
-- Existing participants are captured during the startup window. After that
-- window completes, DTLogs keeps a very light roster probe active so a player
-- who joins mid-mission receives the same full build/loadout snapshot exactly
-- once. Profiles/equipment for already captured players are never re-read.
local SNAPSHOT_MAX_DEPTH = 5
local SNAPSHOT_MAX_ENTRIES = 160
local SNAPSHOT_MAX_NODES = 700

local function compact_json_value(value, depth, seen, state)
	depth = depth or 0
	seen = seen or {}
	state = state or {nodes = 0}

	local value_type = type(value)
	if value == nil then
		return "null"
	elseif value_type == "boolean" then
		return value and "true" or "false"
	elseif value_type == "number" then
		return json_number(value)
	elseif value_type == "string" then
		return json_string(value)
	elseif value_type ~= "table" then
		return json_string("<" .. value_type .. ">")
	end

	if seen[value] then
		return json_string("<cycle>")
	end
	if depth >= SNAPSHOT_MAX_DEPTH then
		return json_string("<max_depth>")
	end
	if state.nodes >= SNAPSHOT_MAX_NODES then
		return json_string("<node_budget_exhausted>")
	end

	state.nodes = state.nodes + 1
	seen[value] = true

	local count = 0
	local max_index = 0
	local is_array = true
	for key, _ in pairs(value) do
		count = count + 1
		if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
			is_array = false
		else
			max_index = math.max(max_index, key)
		end
		if count > SNAPSHOT_MAX_ENTRIES then
			break
		end
	end

	local result = {}
	if is_array and max_index <= SNAPSHOT_MAX_ENTRIES then
		for index = 1, max_index do
			result[#result + 1] = compact_json_value(value[index], depth + 1, seen, state)
		end
		seen[value] = nil
		return "[" .. table.concat(result, ",") .. "]"
	end

	local entries = {}
	for key, child in pairs(value) do
		entries[#entries + 1] = {key = tostring(key), value = child}
		if #entries >= SNAPSHOT_MAX_ENTRIES then
			break
		end
	end
	table.sort(entries, function(left, right)
		return left.key < right.key
	end)

	for index = 1, #entries do
		local entry = entries[index]
		result[#result + 1] = json_string(entry.key)
			.. ":"
			.. compact_json_value(entry.value, depth + 1, seen, state)
	end
	if count > SNAPSHOT_MAX_ENTRIES then
		result[#result + 1] = '"__truncated__":true'
	end

	seen[value] = nil
	return "{" .. table.concat(result, ",") .. "}"
end

local function safe_object_method(object, method_name, ...)
	if object == nil then
		return nil
	end
	local ok_method, method = pcall(function()
		return object[method_name]
	end)
	if not ok_method or type(method) ~= "function" then
		return nil
	end
	local ok_result, result = pcall(method, object, ...)
	return ok_result and result or nil
end

local function player_profile(player)
	if not player then
		return nil
	end

	local profile = safe_object_method(player, "profile")
	if type(profile) == "table" then
		return profile
	end

	local ok, fallback = pcall(function()
		return player._profile
	end)
	if ok and type(fallback) == "table" then
		return fallback
	end

	return nil
end

local function profile_player_identity(player)
	local unit = nil
	pcall(function()
		unit = player.player_unit
	end)
	local account_id = safe_account_id(player)
	local character_id = safe_character_id(player)
	local player_name = safe_player_name(player)
	local key = tostring(account_id or player_name or player)
	return key, account_id, character_id, player_name, unit
end

local function simple_scalar(value)
	local value_type = type(value)
	if value_type == "string" or value_type == "number" or value_type == "boolean" then
		return value
	end
	return nil
end

local function selected_talent_rank(value)
	local value_type = type(value)
	if value_type == "number" then
		return value > 0 and value or nil
	elseif value_type == "boolean" then
		return value and 1 or nil
	elseif value_type == "string" then
		return 1
	elseif value_type == "table" then
		local selected = value.selected
		if selected == false then
			return nil
		end
		local rank = value.rank or value.points or value.point_count or value.value
		if type(rank) == "number" then
			return rank > 0 and rank or nil
		end
		if selected == true then
			return 1
		end
	end
	return nil
end

local function summarize_selected_talents(profile)
	local selected = type(profile) == "table" and profile.talents or nil
	local archetype = type(profile) == "table" and profile.archetype or nil
	local definitions = type(archetype) == "table" and archetype.talents or nil
	local result = {}

	if type(selected) ~= "table" then
		return result
	end

	for key, value in pairs(selected) do
		local talent_id = tostring(key)
		if type(value) == "string" then
			talent_id = value
		elseif type(value) == "table" then
			talent_id = value.id or value.name or value.talent_id or talent_id
		end

		local rank = selected_talent_rank(value)
		if rank ~= nil then
			local definition = type(definitions) == "table" and definitions[talent_id] or nil
			result[#result + 1] = {
				id = tostring(talent_id),
				rank = rank,
				display_name = type(definition) == "table" and simple_scalar(definition.display_name) or nil,
				description = type(definition) == "table" and simple_scalar(definition.description) or nil,
				icon = type(definition) == "table" and simple_scalar(definition.icon) or nil,
			}
		end
	end

	table.sort(result, function(left, right)
		return tostring(left.id) < tostring(right.id)
	end)
	return result
end

local function summarize_modifier_list(values)
	local result = {}
	if type(values) ~= "table" then
		return result
	end

	for _, value in pairs(values) do
		if type(value) == "table" then
			result[#result + 1] = {
				id = value.id or value.name,
				rarity = value.rarity,
				value = value.value,
				modified = value.modified,
			}
		end
		if #result >= 12 then
			break
		end
	end
	return result
end

local function summarize_base_stats(values)
	local result = {}
	if type(values) ~= "table" then
		return result
	end
	for _, value in pairs(values) do
		if type(value) == "table" then
			result[#result + 1] = {
				name = value.name,
				value = value.value,
			}
		end
		if #result >= 10 then
			break
		end
	end
	return result
end

local function item_summary(item, slot_name)
	if type(item) ~= "table" then
		return {
			slot_name = slot_name,
			value_type = type(item),
		}
	end

	local gear = type(item.__gear) == "table" and item.__gear or {}
	local instance = type(gear.masterDataInstance) == "table" and gear.masterDataInstance or {}
	local overrides = type(instance.overrides) == "table" and instance.overrides or {}
	local master = type(item.__master_item) == "table" and item.__master_item or {}

	return {
		slot_name = slot_name,
		item_id = item.__gear_id or item.gear_id or item.item_id,
		master_data_id = instance.id or master.name,
		display_name = master.display_name or master.name,
		description = master.description,
		weapon_template = master.weapon_template,
		item_type = master.item_type,
		rarity = overrides.rarity or master.rarity,
		base_item_level = overrides.baseItemLevel or master.baseItemLevel,
		item_level = overrides.itemLevel or master.itemLevel,
		weapon_skin = overrides.slot_weapon_skin or master.slot_weapon_skin,
		base_stats = summarize_base_stats(overrides.base_stats or master.base_stats),
		perks = summarize_modifier_list(overrides.perks or master.perks),
		traits = summarize_modifier_list(overrides.traits or master.traits),
	}
end

local INCLUDED_LOADOUT_SLOTS = {
	slot_primary = true,
	slot_secondary = true,
	slot_attachment_1 = true,
	slot_attachment_2 = true,
	slot_attachment_3 = true,
	slot_gear_head = true,
	slot_gear_upperbody = true,
	slot_gear_lowerbody = true,
	slot_gear_extra_cosmetic = true,
	slot_character_title = true,
	slot_insignia = true,
	slot_portrait_frame = true,
}

local function summarize_equipment(profile)
	local loadout = type(profile) == "table" and profile.loadout or nil
	local result = {}
	if type(loadout) ~= "table" then
		return result
	end

	for slot_name, item in pairs(loadout) do
		if INCLUDED_LOADOUT_SLOTS[slot_name] then
			result[#result + 1] = item_summary(item, slot_name)
		end
	end
	table.sort(result, function(left, right)
		return tostring(left.slot_name) < tostring(right.slot_name)
	end)
	return result
end

local function emit_profile_snapshot(player, profile, snapshot_reason)
	local player_key, account_id, character_id, player_name, unit = profile_player_identity(player)
	local archetype = type(profile.archetype) == "table" and profile.archetype or {}
	local selected_talents = summarize_selected_talents(profile)
	local equipment = summarize_equipment(profile)

	write_event("player_build_loadout_snapshot", {
		'"player_identity_diagnostic_version":1',
		'"player_identity_semantics_version":1',
		'"player_uuid":' .. json_string(account_id or unit_uuid(unit)),
		'"account_id":' .. json_string(account_id),
		'"character_id":' .. json_string(character_id),
		'"player_name":' .. json_string(player_name),
		'"profile_key":' .. json_string(player_key),
		'"profile_name":' .. json_string(profile.name),
		'"archetype":' .. json_string(archetype.archetype_name or archetype.name),
		'"level":' .. json_number(profile.current_level or profile.level),
		'"talent_points":' .. json_number(profile.talent_points),
		'"base_talents":' .. compact_json_value(archetype.base_talents),
		'"selected_talents":' .. compact_json_value(selected_talents),
		'"selected_nodes":' .. compact_json_value(profile.selected_nodes),
		'"talents_raw":' .. compact_json_value(profile.talents),
		'"equipment":' .. compact_json_value(equipment),
		'"snapshot_reason":' .. json_string(snapshot_reason or "mission_start"),
		'"snapshot_elapsed_ms":' .. json_number(mission_elapsed_ms()),
	}, false)
end

local function captured_profile_count()
	local count = 0
	for _, captured in pairs(mod.profile_snapshot_players) do
		if captured then
			count = count + 1
		end
	end
	return count
end

local function poll_player_profiles(dt, force)
	if not mod.current_file or not Managers.player then
		return
	end

	local startup_probe_finished = mod.profile_probe_finished == true
	local probe_interval = startup_probe_finished
		and (mod.profile_late_join_probe_interval or 2.0)
		or (mod.profile_probe_interval or 1.0)

	if not force then
		mod.profile_probe_accumulator = mod.profile_probe_accumulator + (dt or 0)
		if mod.profile_probe_accumulator < probe_interval then
			return
		end
		mod.profile_probe_accumulator = 0
	end

	local ok_players, players = pcall(function()
		return Managers.player:players()
	end)
	if not ok_players or type(players) ~= "table" then
		return
	end

	local visible_player_count = 0
	for _, player in pairs(players) do
		visible_player_count = visible_player_count + 1
		local player_key = profile_player_identity(player)
		if not mod.profile_snapshot_players[player_key] then
			local profile = player_profile(player)
			if type(profile) == "table" then
				local snapshot_reason = startup_probe_finished and "mid_mission_join" or "mission_start"
				local snapshot_ok, snapshot_error = pcall(emit_profile_snapshot, player, profile, snapshot_reason)
				if snapshot_ok then
					mod.profile_snapshot_players[player_key] = true
					mod.profile_snapshot_count = mod.profile_snapshot_count + 1
					if snapshot_reason == "mid_mission_join" then
						mod.profile_late_join_snapshot_count = (mod.profile_late_join_snapshot_count or 0) + 1
					end
				else
					mod:echo("DTLogs PROFILE_SNAPSHOT ERROR: " .. tostring(snapshot_error))
				end
			end
		end
	end

	-- team_build_snapshot_complete describes only the initial team snapshot.
	-- The lightweight roster probe intentionally remains active after this event
	-- so late joiners can still receive a full player_build_loadout_snapshot.
	if not startup_probe_finished then
		local captured = captured_profile_count()
		local deadline_reached = mission_elapsed_ms() >= (mod.profile_probe_deadline_ms or 20000)
		local full_team_captured = visible_player_count >= 4 and captured >= visible_player_count

		if not force and (full_team_captured or deadline_reached) then
			mod.profile_probe_finished = true
			mod.profile_probe_accumulator = 0
			write_event("team_build_snapshot_complete", {
				'"players_visible":' .. json_number(visible_player_count),
				'"players_captured":' .. json_number(captured),
				'"reason":' .. json_string(full_team_captured and "full_team_captured" or "startup_window_elapsed"),
				'"late_join_monitor_active":true',
			}, true)
		end
	end
end

-- Ability events no longer inspect the profile/loadout during combat. The
-- complete build and equipment are stored by the player snapshot, including late joiners.
local function ability_loadout_item(unit, ability_type)
	local slot_name = ability_type == "combat_ability"
		and "slot_combat_ability"
		or "slot_grenade_ability"
	return nil, slot_name
end

function mod.echo_startup_upload_status()
	if auto_upload_enabled() then
		if mod.auto_upload_scope() == "all_missions" then
			mod:echo(mod:localize("startup_upload_all_missions"))
		else
			mod:echo(mod:localize("startup_upload_successful_only"))
		end
	else
		mod:echo(mod:localize("startup_upload_disabled"))
	end

	local upload_identity, upload_key = AUTO_UPLOAD_AUTH.current()
	if upload_identity == "linked" then
		local hint = AUTO_UPLOAD_AUTH.hint(upload_key)
		local hint_suffix = hint and (" (" .. tostring(hint) .. ")") or ""
		mod:echo(mod:localize("startup_account_linked") .. hint_suffix .. ". " .. mod:localize("startup_account_linked_note"))
	else
		mod:echo(mod:localize("startup_account_not_linked"))
	end
end

function mod.on_all_mods_loaded()
	load_auto_upload_queue()
	AUTO_UPLOAD_AUTH.load()
	if mod.sync_account_menu_status then
		mod.sync_account_menu_status(true)
	end
	mod:echo("DTLogs v" .. MOD_VERSION .. ": mod loaded")
	mod.echo_startup_upload_status()
	if auto_upload_enabled() and #(mod.auto_upload_queue or {}) > 0 then
		mod:echo("DTLogs: " .. tostring(#mod.auto_upload_queue) .. " queued report(s) waiting for automatic upload.")
		pump_auto_upload_queue()
	end
end

safe_hook("StateGameplay", "on_enter", function(func, self, parent, params, creation_context, ...)
	func(self, parent, params, creation_context, ...)

	params = params or {}
	local mechanism_data = params.mechanism_data or {}

	mod.current_mission_name = params.mission_name
	mod.current_circumstance = mechanism_data.circumstance_name
	mod.current_havoc_data_raw = mechanism_data.havoc_data
	mod.current_modifier_mechanism_context = modifier_relevant_fields(mechanism_data, false)
	mod.current_challenge = mechanism_data.challenge
	mod.current_resistance = mechanism_data.resistance
	mod.current_difficulty_mode, mod.current_havoc_rank = resolve_difficulty_context(
		mod.current_mission_name,
		mechanism_data
	)
	mod.current_mission_modifiers, mod.current_mission_modifiers_source = resolve_mission_modifiers(
		mod.current_circumstance,
		mod.current_havoc_data_raw
	)
	mod.current_effective_challenge = nil
	mod.current_effective_resistance = nil
	mod.current_initial_challenge = nil
	mod.current_initial_resistance = nil
	mod.current_danger_name = nil
	mod.current_danger_index = nil
	mod.current_danger_difficulty = nil
	mod.current_danger_is_auric = nil
	mod.current_danger_localization_key = nil
	mod.difficulty_resolution_written = false

	start_mission_file()
end)

safe_hook("StateGameplay", "on_exit", function(func, self, ...)
	if mod.current_file then
		write_event("recording_incomplete", {
			'"presence_semantics_version":1',
			'"reason":"state_gameplay_exited_without_mission_end"',
			'"mission_recording_status":"incomplete"',
			'"recording_duration_ms":' .. json_number(mission_elapsed_ms()),
			'"gameplay_clock_ms":' .. json_number(safe_gameplay_clock_ms()),
		}, true)
		close_current_file()
	end
	return func(self, ...)
end)

-- Diagnostic-only lifecycle evidence. `rpc_sync_clock` is especially useful:
-- Darktide supplies the client with the already-running gameplay clock during
-- hot join, so its first server time can distinguish a fresh start from a
-- recorder that attached to an in-progress mission after live validation.
safe_hook("GameplayStateRun", "on_enter", function(func, self, parent, params, ...)
	func(self, parent, params, ...)
	if mod.current_file then
		mod.gameplay_state_enter_observed = true
		write_event("gameplay_state_entered", {
			'"gameplay_clock_diagnostic_version":1',
			'"recording_elapsed_ms":' .. json_number(mission_elapsed_ms()),
			'"gameplay_clock_ms":' .. json_number(safe_gameplay_clock_ms()),
		}, false)
	end
end)

safe_hook("GameplayStateRun", "rpc_sync_clock", function(func, self, channel_id, time, offset, ...)
	local first_sync = self and self._gameplay_timer_registered ~= true
	local sync_recording_elapsed_ms = mission_elapsed_ms()
	if mod.current_file then
		mod.gameplay_clock_sync_count = (mod.gameplay_clock_sync_count or 0) + 1
		if first_sync and mod.gameplay_clock_first_server_sync_ms == nil then
			mod.gameplay_clock_first_server_sync_ms = round_milliseconds(time)
			mod.gameplay_clock_first_sync_offset = tonumber(offset)
			mod.gameplay_clock_first_sync_recording_elapsed_ms = sync_recording_elapsed_ms
		end
		write_event("gameplay_clock_sync_received", {
			'"gameplay_clock_diagnostic_version":1',
			'"first_sync":' .. tostring(first_sync == true),
			'"channel_id":' .. json_number(channel_id),
			'"server_sync_time_seconds":' .. json_number(time),
			'"server_sync_time_ms":' .. json_number(round_milliseconds(time)),
			'"server_sync_offset":' .. json_number(offset),
			'"recording_elapsed_ms":' .. json_number(sync_recording_elapsed_ms),
			'"recording_start_gameplay_clock_estimate_ms":' .. json_number(recording_start_gameplay_clock_estimate_ms()),
		}, false)
	end

	func(self, channel_id, time, offset, ...)

	if mod.current_file and first_sync then
		local gameplay_clock_ms = safe_gameplay_clock_ms()
		if gameplay_clock_ms ~= nil then
			mod.gameplay_clock_first_observed_ms = mod.gameplay_clock_first_observed_ms or gameplay_clock_ms
			mod.gameplay_clock_last_observed_ms = gameplay_clock_ms
		end
		write_event("gameplay_clock_registered", {
			'"gameplay_clock_diagnostic_version":1',
			'"recording_elapsed_ms":' .. json_number(mission_elapsed_ms()),
			'"gameplay_clock_ms":' .. json_number(gameplay_clock_ms),
			'"server_sync_time_ms":' .. json_number(mod.gameplay_clock_first_server_sync_ms),
		}, false)
		if not mod.presence_initial_snapshot_written then
			mod.presence_initial_snapshot_written = true
			write_presence_roster_snapshot("first_gameplay_clock_sync", true)
		end
	end
end)

safe_hook("GameplayStateRun", "on_exit", function(func, self, exit_params, ...)
	if mod.current_file then
		mod.gameplay_state_exit_observed = true
		local gameplay_clock_ms = safe_gameplay_clock_ms()
		if gameplay_clock_ms ~= nil then
			mod.gameplay_clock_last_observed_ms = gameplay_clock_ms
		end
		write_event("gameplay_state_exited", {
			'"gameplay_clock_diagnostic_version":1',
			'"recording_elapsed_ms":' .. json_number(mission_elapsed_ms()),
			'"gameplay_clock_ms":' .. json_number(gameplay_clock_ms),
			'"mission_end_observed":' .. tostring(mod.mission_end_observed == true),
			'"on_shutdown":' .. tostring(type(exit_params) == "table" and exit_params.on_shutdown == true),
		}, true)
		if mod.mission_end_observed ~= true then
			write_event("recording_incomplete", {
				'"presence_semantics_version":1',
				'"reason":"gameplay_state_exited_without_mission_end"',
				'"mission_recording_status":"incomplete"',
				'"recording_duration_ms":' .. json_number(mission_elapsed_ms()),
				'"gameplay_clock_ms":' .. json_number(gameplay_clock_ms),
			}, true)
			close_current_file()
		end
	end
	return func(self, exit_params, ...)
end)

-- Session membership gives exact join/leave evidence from the point this
-- recorder is connected. Both client-view and host-view paths are hooked; a
-- normal dedicated-server Darktide client uses the member_* path.
safe_hook("GameSessionManager", "_member_joined", function(func, self, channel_id, peer_id, ...)
	func(self, channel_id, peer_id, ...)
	if mod.current_file then
		mod.session_join_event_count = (mod.session_join_event_count or 0) + 1
		write_session_presence_event("session_member_joined", peer_id, channel_id, nil, nil, "member_joined")
		write_presence_roster_snapshot("session_member_joined", false)
	end
end)

safe_hook("GameSessionManager", "_member_left", function(func, self, channel_id, peer_id, game_reason, engine_reason, ...)
	if mod.current_file then
		mod.session_leave_event_count = (mod.session_leave_event_count or 0) + 1
		write_session_presence_event("session_member_left", peer_id, channel_id, game_reason, engine_reason, "member_left")
	end
	return func(self, channel_id, peer_id, game_reason, engine_reason, ...)
end)

safe_hook("GameSessionManager", "_client_joined", function(func, self, channel_id, peer_id, ...)
	func(self, channel_id, peer_id, ...)
	if mod.current_file then
		mod.session_join_event_count = (mod.session_join_event_count or 0) + 1
		write_session_presence_event("session_member_joined", peer_id, channel_id, nil, nil, "client_joined")
		write_presence_roster_snapshot("session_client_joined", false)
	end
end)

safe_hook("GameSessionManager", "_client_left", function(func, self, channel_id, peer_id, game_reason, engine_reason, ...)
	if mod.current_file then
		mod.session_leave_event_count = (mod.session_leave_event_count or 0) + 1
		write_session_presence_event("session_member_left", peer_id, channel_id, game_reason, engine_reason, "client_left")
	end
	return func(self, channel_id, peer_id, game_reason, engine_reason, ...)
end)

-- Full AttackReportManager implementation based on Power DI.
-- v0.13.14 intentionally uses a regular wrapper hook to match Ovenproof Scoreboard timing.
-- Compact immutable snapshots are captured before the original function; JSON construction is deferred.
safe_hook("AttackReportManager", "add_attack_result", function(
	func,
	self,
	damage_profile,
	attacked_unit,
	attacking_unit,
	attack_direction,
	hit_world_position,
	hit_weakspot,
	damage,
	attack_result,
	attack_type,
	damage_efficiency,
	is_critical_strike,
	...
)
	if mod.current_file then
		guarded_event("ATTACK", function()
			local event_time_ms = mission_elapsed_ms()
			local event_timestamp = timestamp()
			local attacker = capture_actor_snapshot(attacking_unit, event_time_ms)
			local target = capture_actor_snapshot(attacked_unit, event_time_ms)
			local numeric_damage = tonumber(damage) or 0
			local effective_damage, overkill_damage, target_is_minion, damage_accounting_source,
				target_health_before, target_health_after, health_cache_hit, damage_accounting_anomaly =
				capture_enemy_damage_accounting(attacked_unit, target, numeric_damage, attack_result)
			local common_payload = {
				attacker = attacker,
				target = target,
				target_is_minion = target_is_minion,
				damage_profile = safe_damage_profile_name(damage_profile),
				damage = numeric_damage,
				effective_damage = effective_damage,
				scoreboard_damage = effective_damage,
				overkill_damage = overkill_damage,
				damage_accounting_source = damage_accounting_source,
				target_health_before = target_health_before,
				target_health_after = target_health_after,
				health_cache_hit = health_cache_hit,
				damage_accounting_anomaly = damage_accounting_anomaly,
				weakspot = hit_weakspot == true,
				critical = is_critical_strike == true,
				result = attack_result,
				attack_type = attack_type,
				damage_efficiency = tonumber(damage_efficiency),
				attack_direction = vector_snapshot(attack_direction),
				hit_position = vector_snapshot(hit_world_position),
			}

			-- Keep the old raw total as a diagnostic/backward-compatible field. Canonical
			-- combat-report Damage/DPS uses scoreboard_damage on enemy minions.
			if numeric_damage > 0 then
				mod.total_actual_damage = mod.total_actual_damage + numeric_damage
			else
				mod.zero_damage_event_count = mod.zero_damage_event_count + 1
			end

			if attacker.is_player and target_is_minion and numeric_damage > 0 then
				mod.enemy_damage_event_count = mod.enemy_damage_event_count + 1
				if effective_damage ~= nil then
					mod.total_effective_enemy_damage = mod.total_effective_enemy_damage + effective_damage
				end
			end

			if target.is_player and numeric_damage > 0 then
				mod.total_player_damage_taken = mod.total_player_damage_taken + numeric_damage
				write_raw_event(
					"player_damage_taken",
					"player_damage_taken_raw",
					common_payload,
					event_time_ms,
					event_timestamp
				)
			end

			write_raw_event(
				"attack_result",
				"attack_result_raw",
				common_payload,
				event_time_ms,
				event_timestamp
			)
		end)
	end

	return func(
		self,
		damage_profile,
		attacked_unit,
		attacking_unit,
		attack_direction,
		hit_world_position,
		hit_weakspot,
		damage,
		attack_result,
		attack_type,
		damage_efficiency,
		is_critical_strike,
		...
	)
end)

safe_hook("WeaponSystem", "rpc_player_blocked_attack", function(
	func,
	self,
	channel_id,
	unit_id,
	attacking_unit_id,
	hit_world_position,
	block_broken,
	weapon_template_id,
	attack_type_id,
	...
)
	if mod.current_file then
		guarded_event("BLOCK", function()
			local player_unit = unit_from_network_id(unit_id, false)
			local attacking_unit = unit_from_network_id(attacking_unit_id, false)
			local weapon_template = NetworkLookup.weapon_templates[weapon_template_id]
			local attack_type = NetworkLookup.attack_types[attack_type_id]

			write_event("blocked_attack", {
				'"player_uuid":' .. json_string(unit_uuid(player_unit)),
				'"player_name":' .. json_string(safe_player_name(player_from_unit(player_unit))),
				'"player_position":' .. unit_position_json(player_unit),
				'"attacker_uuid":' .. json_string(unit_uuid(attacking_unit)),
				'"attacker_breed":' .. json_string(safe_breed_name(attacking_unit)),
				'"attacker_position":' .. unit_position_json(attacking_unit),
				'"block_broken":' .. tostring(block_broken == true),
				'"weapon_template":' .. json_string(weapon_template),
				'"attack_type":' .. json_string(attack_type),
				'"hit_position":' .. vector_to_json(hit_world_position),
			}, false)
		end)
	end

	return func(
		self,
		channel_id,
		unit_id,
		attacking_unit_id,
		hit_world_position,
		block_broken,
		weapon_template_id,
		attack_type_id,
		...
	)
end)

safe_hook("PlayerSuppressionExtension", "rpc_player_suppressed", function(
	func,
	self,
	channel_id,
	unit_id,
	num_suppression_hits,
	...
)
	if mod.current_file then
		guarded_event("SUPPRESSION", function()
			local player_unit = unit_from_network_id(unit_id, false)
			local player_id = unit_uuid(player_unit)

			if not should_log_suppression(player_id, num_suppression_hits) then
				return
			end

			write_event("player_suppressed", {
				'"player_uuid":' .. json_string(unit_uuid(player_unit)),
				'"player_name":' .. json_string(safe_player_name(player_from_unit(player_unit))),
				'"player_position":' .. unit_position_json(player_unit),
				'"suppression_hits":' .. json_number(num_suppression_hits),
			}, false)
		end)
	end

	return func(self, channel_id, unit_id, num_suppression_hits, ...)
end)

safe_hook("InteracteeSystem", "rpc_interaction_started", function(
	func,
	self,
	channel_id,
	unit_id,
	is_level_unit,
	interactor_game_object_id,
	...
)
	if mod.current_file then
		guarded_event("INTERACTION_START", function()
			local interactor_unit = unit_from_network_id(interactor_game_object_id, false)
			local interactee_unit = unit_from_network_id(unit_id, is_level_unit)
			local interaction_type = nil
			local extension = self._unit_to_extension_map and self._unit_to_extension_map[interactee_unit]

			if extension and extension.interaction_type then
				local ok, value = pcall(function()
					return extension:interaction_type()
				end)
				interaction_type = ok and value or nil
			end

			mod.active_interactions[unit_id] = interactor_unit

			write_event("interaction_started", {
				'"interaction_type":' .. json_string(interaction_type),
				'"interactor_uuid":' .. json_string(unit_uuid(interactor_unit)),
				'"interactor_name":' .. json_string(safe_player_name(player_from_unit(interactor_unit))),
				'"interactor_position":' .. unit_position_json(interactor_unit),
				'"interactee_uuid":' .. json_string(unit_uuid(interactee_unit)),
				'"interactee_position":' .. unit_position_json(interactee_unit),
				'"is_level_unit":' .. tostring(is_level_unit == true),
			}, false)
		end)
	end

	return func(self, channel_id, unit_id, is_level_unit, interactor_game_object_id, ...)
end)

safe_hook("InteracteeSystem", "rpc_interaction_stopped", function(
	func,
	self,
	channel_id,
	unit_id,
	is_level_unit,
	interactor_game_object_id,
	result,
	...
)
	if mod.current_file then
		guarded_event("INTERACTION_STOP", function()
			local interactee_unit = unit_from_network_id(unit_id, is_level_unit)
			local interactor_unit = mod.active_interactions[unit_id]
				or unit_from_network_id(interactor_game_object_id, false)
			local interaction_type = nil
			local extension = self._unit_to_extension_map and self._unit_to_extension_map[interactee_unit]

			if extension and extension.interaction_type then
				local ok, value = pcall(function()
					return extension:interaction_type()
				end)
				interaction_type = ok and value or nil
			end

			mod.active_interactions[unit_id] = nil

			write_event("interaction_stopped", {
				'"interaction_type":' .. json_string(interaction_type),
				'"interactor_uuid":' .. json_string(unit_uuid(interactor_unit)),
				'"interactor_name":' .. json_string(safe_player_name(player_from_unit(interactor_unit))),
				'"interactee_uuid":' .. json_string(unit_uuid(interactee_unit)),
				'"is_level_unit":' .. tostring(is_level_unit == true),
				'"result":' .. json_string(NetworkLookup.interaction_result[result]),
			}, false)
		end)
	end

	return func(
		self,
		channel_id,
		unit_id,
		is_level_unit,
		interactor_game_object_id,
		result,
		...
	)
end)

safe_hook("VisualLoadoutSystem", "rpc_player_wield_slot", function(
	func,
	self,
	channel_id,
	go_id,
	slot_id,
	...
)
	if mod.current_file then
		guarded_event("WIELD", function()
			local player_unit = unit_from_network_id(go_id, false)

			local player_id = unit_uuid(player_unit)
			if not should_log_slot_event(player_id, NetworkLookup.player_inventory_slot_names[slot_id], "slot_wielded") then
				return
			end

			write_event("slot_wielded", {
				'"source":"network"',
				'"player_uuid":' .. json_string(unit_uuid(player_unit)),
				'"player_name":' .. json_string(safe_player_name(player_from_unit(player_unit))),
				'"slot_name":' .. json_string(NetworkLookup.player_inventory_slot_names[slot_id]),
			}, false)
		end)
	end

	return func(self, channel_id, go_id, slot_id, ...)
end)

safe_hook("VisualLoadoutSystem", "rpc_player_unwield_slot", function(
	func,
	self,
	channel_id,
	go_id,
	slot_id,
	...
)
	if mod.current_file then
		guarded_event("UNWIELD", function()
			local player_unit = unit_from_network_id(go_id, false)

			local player_id = unit_uuid(player_unit)
			if not should_log_slot_event(player_id, NetworkLookup.player_inventory_slot_names[slot_id], "slot_unwielded") then
				return
			end

			write_event("slot_unwielded", {
				'"source":"network"',
				'"player_uuid":' .. json_string(unit_uuid(player_unit)),
				'"player_name":' .. json_string(safe_player_name(player_from_unit(player_unit))),
				'"slot_name":' .. json_string(NetworkLookup.player_inventory_slot_names[slot_id]),
			}, false)
		end)
	end

	return func(self, channel_id, go_id, slot_id, ...)
end)

safe_hook("PlayerUnitWeaponExtension", "on_slot_wielded", function(
	func,
	self,
	slot_name,
	t,
	skip_wield_action,
	...
)
	local result = func(self, slot_name, t, skip_wield_action, ...)

	if mod.current_file then
		guarded_event("LOCAL_WIELD", function()
			local player_unit = self._unit
			local player_id = unit_uuid(player_unit)
			if not should_log_slot_event(player_id, slot_name, "slot_wielded") then
				return
			end

			write_event("slot_wielded", {
				'"source":"local"',
				'"player_uuid":' .. json_string(unit_uuid(player_unit)),
				'"player_name":' .. json_string(safe_player_name(player_from_unit(player_unit))),
				'"slot_name":' .. json_string(slot_name),
			}, false)
		end)
	end

	return result
end)

safe_hook("PlayerUnitWeaponExtension", "on_slot_unwielded", function(
	func,
	self,
	slot_name,
	t,
	...
)
	local result = func(self, slot_name, t, ...)

	if mod.current_file then
		guarded_event("LOCAL_UNWIELD", function()
			local player_unit = self._unit
			local player_id = unit_uuid(player_unit)
			if not should_log_slot_event(player_id, slot_name, "slot_unwielded") then
				return
			end

			write_event("slot_unwielded", {
				'"source":"local"',
				'"player_uuid":' .. json_string(unit_uuid(player_unit)),
				'"player_name":' .. json_string(safe_player_name(player_from_unit(player_unit))),
				'"slot_name":' .. json_string(slot_name),
			}, false)
		end)
	end

	return result
end)

local function track_ability_charges(self, unit)
	if not mod.current_file or not unit then
		return
	end

	local ability_types = {"combat_ability", "grenade_ability"}
	for _, ability_type in ipairs(ability_types) do
		local enabled_ok, enabled = pcall(function()
			return self:ability_enabled(ability_type)
		end)

		if enabled_ok and enabled then
			local ability_components = self._ability_components or self._components
			local component = ability_components and ability_components[ability_type]
			local current_num_charges = component and component.num_charges

			if current_num_charges ~= nil then
				local key = ability_type .. "_" .. tostring(unit_uuid(unit))
				local previous = mod.player_ability_num_charges[key]

				if previous == nil then
					mod.player_ability_num_charges[key] = current_num_charges
				elseif previous ~= current_num_charges then
					local charge_delta = current_num_charges - previous

					if charge_delta < 0 then
						local ability_item, ability_slot = ability_loadout_item(unit, ability_type)
						local ability_summary = item_summary(ability_item)
						write_event("ability_used", {
							'"player_uuid":' .. json_string(unit_uuid(unit)),
							'"player_name":' .. json_string(safe_player_name(player_from_unit(unit))),
							'"ability_type":' .. json_string(ability_type),
							'"ability_slot":' .. json_string(ability_slot),
							'"ability_item_id":' .. json_string(ability_summary.item_id),
							'"ability_master_id":' .. json_string(ability_summary.master_id),
							'"ability_name":' .. json_string(ability_summary.name),
							'"ability_template":' .. json_string(ability_summary.template),
							'"charges_spent":' .. json_number(math.abs(charge_delta)),
							'"previous_charges":' .. json_number(previous),
							'"current_charges":' .. json_number(current_num_charges),
						}, false)
					end

					write_event("ability_charge_changed", {
						'"player_uuid":' .. json_string(unit_uuid(unit)),
						'"player_name":' .. json_string(safe_player_name(player_from_unit(unit))),
						'"ability_type":' .. json_string(ability_type),
						'"previous_charges":' .. json_number(previous),
						'"current_charges":' .. json_number(current_num_charges),
						'"charge_delta":' .. json_number(charge_delta),
					}, false)

					mod.player_ability_num_charges[key] = current_num_charges
				end
			end
		end
	end
end

local function log_coherency_event(event_name, game_object_id, other_game_object_id)
	local player_unit = network_unit(game_object_id)
	local other_unit = network_unit(other_game_object_id)
	local player = player_from_unit(player_unit)
	local other_player = player_from_unit(other_unit)
	local player_uuid = unit_uuid(player_unit)
	local other_uuid = unit_uuid(other_unit)
	local player_name = safe_player_name(player)
	local other_name = safe_player_name(other_player)

	if not player_uuid or not other_uuid or player_uuid == other_uuid or not player_name or not other_name then
		return
	end

	local first_uuid = tostring(player_uuid)
	local second_uuid = tostring(other_uuid)
	if second_uuid < first_uuid then
		first_uuid, second_uuid = second_uuid, first_uuid
	end
	local key = event_name .. "|" .. first_uuid .. "|" .. second_uuid
	local now = monotonic_time_ms()
	local previous = mod.last_coherency_events[key]
	if previous and now - previous < 250 then
		return
	end
	mod.last_coherency_events[key] = now

	write_event(event_name, {
		'"player_uuid":' .. json_string(player_uuid),
		'"player_name":' .. json_string(player_name),
		'"other_player_uuid":' .. json_string(other_uuid),
		'"other_player_name":' .. json_string(other_name),
		'"player_position":' .. unit_position_json(player_unit),
		'"other_player_position":' .. unit_position_json(other_unit),
	}, false)
end

safe_hook("HuskCoherencyExtension", "rpc_player_unit_enter_coherency", function(func, self, channel_id, game_object_id, enter_game_object_id, ...)
	if mod.current_file then
		guarded_event("COHERENCY_ENTER", function()
			log_coherency_event("player_coherency_entered", game_object_id, enter_game_object_id)
		end)
	end
	return func(self, channel_id, game_object_id, enter_game_object_id, ...)
end)

safe_hook("HuskCoherencyExtension", "rpc_player_unit_exit_coherency", function(func, self, channel_id, game_object_id, exit_game_object_id, ...)
	if mod.current_file then
		guarded_event("COHERENCY_EXIT", function()
			log_coherency_event("player_coherency_exited", game_object_id, exit_game_object_id)
		end)
	end
	return func(self, channel_id, game_object_id, exit_game_object_id, ...)
end)

-- Network RPCs encode the originating archetype talent through
-- NetworkLookup.archetype_talent_names. Preserve both the numeric lookup ID
-- and the stable talent name so the website can attribute buffs to talents.
-- Defined on `mod` rather than as another top-level local to stay below the
-- LuaJIT 200-local compiler limit that DTLogs has hit before.
mod.buff_talent_name = function(talent_id)
	if talent_id == nil or not NetworkLookup or not NetworkLookup.archetype_talent_names then
		return nil
	end
	return NetworkLookup.archetype_talent_names[talent_id]
end

-- Read the real state of a network-synchronised buff after Darktide has applied
-- the RPC. A server index is not the same thing as PlayerUnitBuffExtension's
-- local buff index, so always resolve it through _buff_index_map.
mod.player_buff_instance_state = function(self, server_index)
	if type(self) ~= "table" or server_index == nil then
		return nil
	end
	local local_index = self._buff_index_map and self._buff_index_map[server_index]
	local buff_instance = local_index and self._buffs_by_index and self._buffs_by_index[local_index]
	if type(buff_instance) ~= "table" then
		return nil
	end

	local function safe_method(name)
		local fn = buff_instance[name]
		if type(fn) ~= "function" then
			return nil
		end
		local ok, value = pcall(fn, buff_instance)
		return ok and value or nil
	end

	local template = buff_instance._template

	return {
		local_index = local_index,
		template_name = safe_method("template_name"),
		stack_count = safe_method("stack_count"),
		effective_stack_count = safe_method("stat_buff_stacking_count"),
		max_stacks = safe_method("max_stacks"),
		max_stacks_cap = safe_method("max_stacks_cap"),
		max_stat_stacks = type(template) == "table" and template.max_stat_stacks or nil,
		stack_offset = type(template) == "table" and template.stack_offset or nil,
		duration = safe_method("duration"),
		extra_duration = safe_method("extra_duration"),
		start_time = safe_method("start_time"),
		active_start_time = safe_method("active_start_time"),
		active_duration = type(template) == "table" and template.active_duration or nil,
		proc_count = safe_method("proc_count"),
		is_proc_active = safe_method("is_proc_active"),
		predicted = safe_method("is_predicted"),
	}
end

-- Same state reader for local predicted buffs, which never receive a server index.
mod.predicted_buff_instance_state = function(buff_instance)
	if type(buff_instance) ~= "table" then
		return nil
	end
	local function safe_method(name)
		local fn = buff_instance[name]
		if type(fn) ~= "function" then
			return nil
		end
		local ok, value = pcall(fn, buff_instance)
		return ok and value or nil
	end
	local template = buff_instance._template

	return {
		template_name = safe_method("template_name"),
		instance_id = safe_method("instance_id"),
		component_index = safe_method("component_index"),
		stack_count = safe_method("stack_count"),
		effective_stack_count = safe_method("stat_buff_stacking_count"),
		max_stacks = safe_method("max_stacks"),
		max_stacks_cap = safe_method("max_stacks_cap"),
		max_stat_stacks = type(template) == "table" and template.max_stat_stacks or nil,
		stack_offset = type(template) == "table" and template.stack_offset or nil,
		duration = safe_method("duration"),
		extra_duration = safe_method("extra_duration"),
		start_time = safe_method("start_time"),
		active_start_time = safe_method("active_start_time"),
		active_duration = type(template) == "table" and template.active_duration or nil,
		proc_count = safe_method("proc_count"),
		is_proc_active = safe_method("is_proc_active"),
		predicted = safe_method("is_predicted"),
	}
end

-- Match Darktide Buff:stat_buff_stacking_count() exactly for a hypothetical
-- raw stack count. max_stacks_cap is not part of this calculation; the game
-- uses max_stat_stacks (when present), otherwise Buff:max_stacks(), plus the
-- template stack_offset before clamping.
mod.buff_effective_stack_count = function(state, stack_count)
	if stack_count == nil then
		return nil
	end
	local max_stacks = state and (state.max_stat_stacks or state.max_stacks) or nil
	max_stacks = max_stacks or 1
	local stack_offset = state and state.stack_offset or 0
	return math.max(0, math.min(stack_count + stack_offset, max_stacks))
end

local function cache_player_buff(unit, server_index, buff_template_id, optional_lerp_value, optional_item_slot_id, optional_parent_buff_template_id, from_talent_id, metadata, unit_id_override)
	if not unit or server_index == nil then
		return nil
	end
	local unit_id = tostring(unit_id_override or unit_uuid(unit))
	local key = unit_id .. "_" .. tostring(server_index)
	local generation_key = key
	local generation = (mod.buff_generations[generation_key] or 0) + 1
	mod.buff_generations[generation_key] = generation
	local instance_id = unit_id .. ":" .. tostring(server_index) .. ":" .. tostring(generation)
	mod.active_player_buffs[key] = {
		buff_template_id = buff_template_id,
		optional_lerp_value = optional_lerp_value,
		optional_item_slot_id = optional_item_slot_id,
		optional_parent_buff_template_id = optional_parent_buff_template_id,
		from_talent_id = from_talent_id,
		from_talent_name = mod.buff_talent_name and mod.buff_talent_name(from_talent_id) or nil,
		metadata = metadata,
		buff_instance_id = instance_id,
		generation = generation,
	}
	return instance_id
end

local function cached_buff_template_name(buff_template_id)
	if buff_template_id == nil then
		return nil
	end
	local cached = mod.buff_template_name_cache[buff_template_id]
	if cached ~= nil then
		return cached == false and nil or cached
	end
	local name = buff_template_name(buff_template_id)
	mod.buff_template_name_cache[buff_template_id] = name or false
	return name
end

local function player_buff_definition_key(buff_template_id)
	return tostring(buff_template_id or "nil") .. "|" .. tostring(cached_buff_template_name(buff_template_id) or "unknown")
end

local function cached_buff_unit(game_object_id)
	if game_object_id == nil then
		return nil
	end
	local cached = mod.buff_game_object_unit_cache[game_object_id]
	if cached then
		return cached
	end
	local unit = network_unit(game_object_id)
	if unit then
		mod.buff_game_object_unit_cache[game_object_id] = unit
	end
	return unit
end

local function cached_buff_position_snapshot(unit, now_ms)
	return cached_event_position_snapshot(unit, now_ms)
end

local function ensure_player_buff_definition(buff_template_id, template, template_source, visible, visibility_source, hud_priority, has_hud_icon, show_in_hud)
	local definition_key = player_buff_definition_key(buff_template_id)
	if mod.buff_definitions_written[definition_key] then
		return
	end

	mod.buff_definitions_written[definition_key] = true
	mod.buff_definition_count = (mod.buff_definition_count or 0) + 1
	write_raw_event("player_buff_definition", "buff_definition", {
		buff_template_id = buff_template_id,
		buff_template_name = cached_buff_template_name(buff_template_id),
		is_visible_to_player = visible,
		visibility_source = visibility_source,
		hud_priority = hud_priority,
		has_hud_icon = has_hud_icon,
		hud_icon = type(template) == "table" and template.hud_icon or nil,
		show_in_hud = show_in_hud,
		buff_template_source = template_source,
		buff_template = template,
	})
end

local function copy_array(values)
	local result = {}
	for i = 1, #(values or {}) do
		result[i] = values[i]
	end
	return result
end

local function log_player_buff_added(self, game_object_id, buff_template_id, server_indices, owner_unit_id, optional_lerp_value, optional_item_slot_id, optional_parent_buff_template_id, from_talent_id, capture_source, state_before)
	local event_time_ms = mission_elapsed_ms()
	local event_timestamp = timestamp()
	local unit = cached_buff_unit(game_object_id)
	local identity = cached_player_identity(unit, event_time_ms)
	if not unit or not identity then
		return
	end

	local owner_unit = cached_buff_unit(owner_unit_id)
	local owner_identity = cached_player_identity(owner_unit, event_time_ms)
	server_indices = copy_array(server_indices)

	-- Template discovery and visibility analysis are static work. Do them only
	-- for the first occurrence of this buff template in the mission.
	local definition_key = player_buff_definition_key(buff_template_id)
	if not mod.buff_definitions_written[definition_key] then
		local template, template_source = nil, nil
		if server_indices[1] ~= nil then
			template, template_source = template_from_buff_instance(self, server_indices[1])
		end
		if not template then
			template, template_source = buff_template(buff_template_id)
		end
		local visible, visibility_source, hud_priority, has_hud_icon, show_in_hud = buff_visibility(template)
		ensure_player_buff_definition(
			buff_template_id,
			template,
			template_source,
			visible,
			visibility_source,
			hud_priority,
			has_hud_icon,
			show_in_hud
		)
	end

	local instance_ids = {}
	for i = 1, #server_indices do
		instance_ids[i] = cache_player_buff(
			unit,
			server_indices[i],
			buff_template_id,
			optional_lerp_value,
			optional_item_slot_id,
			optional_parent_buff_template_id,
			from_talent_id,
			nil,
			identity.uuid
		)
	end

	local extension_class = self and self.__class_name
	local source = capture_source or "rpc"
	local batch_key = table.concat({
		"add",
		tostring(identity.uuid),
		tostring(buff_template_id),
		tostring(optional_parent_buff_template_id),
		tostring(optional_lerp_value),
		tostring(optional_item_slot_id),
		tostring(from_talent_id),
		tostring(owner_identity and owner_identity.uuid),
		tostring(source),
		tostring(extension_class),
	}, "|")

	local state = server_indices[1] ~= nil and mod.player_buff_instance_state(self, server_indices[1]) or nil
	local added_stacks = #server_indices > 0 and #server_indices or 1
	local stack_after = state and state.stack_count or nil
	local stack_count_before = state_before and state_before.stack_count or nil
	local effective_stack_count_before = state_before and state_before.effective_stack_count or nil
	if stack_count_before == nil and stack_after ~= nil then
		stack_count_before = math.max(stack_after - added_stacks, 0)
		effective_stack_count_before = mod.buff_effective_stack_count(state, stack_count_before)
	end

	write_buff_batch_event(
		"player_buff_added",
		"player_buff_added_batch",
		"buff_added_batch",
		batch_key,
		{
			player_uuid = identity.uuid,
			account_id = identity.account_id,
			character_id = identity.character_id,
			player_name = identity.name,
			buff_template_id = buff_template_id,
			buff_template_name = cached_buff_template_name(buff_template_id),
			parent_buff_template_id = optional_parent_buff_template_id,
			parent_buff_template_name = cached_buff_template_name(optional_parent_buff_template_id),
			optional_lerp_value = optional_lerp_value,
			optional_item_slot_id = optional_item_slot_id,
			from_talent_id = from_talent_id,
			from_talent_name = mod.buff_talent_name(from_talent_id),
			owner_unit_id = owner_unit_id,
			owner_player_uuid = owner_identity and owner_identity.uuid or nil,
			owner_player_name = owner_identity and owner_identity.name or nil,
			capture_source = source,
			extension_class = extension_class,
			position = cached_buff_position_snapshot(unit, event_time_ms),
		},
		{
			server_indices = server_indices,
			buff_instance_ids = instance_ids,
			added_stacks = added_stacks,
			stack_count_before = stack_count_before,
			stack_count_after = stack_after,
			effective_stack_count_before = effective_stack_count_before,
			effective_stack_count_after = state and state.effective_stack_count or nil,
			max_stacks = state and state.max_stacks or nil,
			max_stacks_cap = state and state.max_stacks_cap or nil,
			duration = state and state.duration or nil,
			extra_duration = state and state.extra_duration or nil,
			game_start_time = state and state.start_time or nil,
			predicted = state and state.predicted or false,
		},
		event_time_ms,
		event_timestamp
	)
end

local function log_player_buff_removed(self, game_object_id, server_index, capture_source, removed_stacks, state_before, stack_count_after)
	local event_time_ms = mission_elapsed_ms()
	local event_timestamp = timestamp()
	local unit = cached_buff_unit(game_object_id)
	local identity = cached_player_identity(unit, event_time_ms)
	if not unit or not identity then
		return
	end

	local key = tostring(identity.uuid) .. "_" .. tostring(server_index)
	local cached = mod.active_player_buffs[key]
	mod.active_player_buffs[key] = nil
	local template_id = cached and cached.buff_template_id or nil
	local extension_class = self and self.__class_name
	local source = capture_source or "rpc"
	local batch_key = table.concat({
		"remove",
		tostring(identity.uuid),
		tostring(template_id),
		tostring(source),
		tostring(extension_class),
	}, "|")

	write_buff_batch_event(
		"player_buff_removed",
		"player_buff_removed_batch",
		"buff_removed_batch",
		batch_key,
		{
			player_uuid = identity.uuid,
			account_id = identity.account_id,
			character_id = identity.character_id,
			player_name = identity.name,
			buff_template_id = template_id,
			buff_template_name = cached_buff_template_name(template_id),
			capture_source = source,
			extension_class = extension_class,
			position = cached_buff_position_snapshot(unit, event_time_ms),
		},
		{
			server_index = server_index,
			buff_instance_id = cached and cached.buff_instance_id or nil,
			buff_generation = cached and cached.generation or nil,
			cache_miss = cached == nil,
			removed_stacks = removed_stacks,
			stack_count_before = state_before and state_before.stack_count or nil,
			stack_count_after = stack_count_after,
			effective_stack_count_before = state_before and state_before.effective_stack_count or nil,
			effective_stack_count_after = mod.buff_effective_stack_count(state_before, stack_count_after),
			max_stacks = state_before and state_before.max_stacks or nil,
			max_stacks_cap = state_before and state_before.max_stacks_cap or nil,
		},
		event_time_ms,
		event_timestamp
	)
end


-- Record timing/state transitions without polling the buff extension every frame.
-- These are deliberately ordinary events (rather than snapshots): the website can
-- reconstruct uptime, refreshes, proc activations and extra-duration changes from
-- the event timeline.
mod.log_player_buff_state_event = function(self, event_name, game_object_id, server_index, capture_source, state_fields)
	if not mod.current_file then
		return
	end

	local event_time_ms = mission_elapsed_ms()
	local unit = cached_buff_unit(game_object_id)
	local identity = cached_player_identity(unit, event_time_ms)
	if not unit or not identity then
		return
	end

	local key = tostring(identity.uuid) .. "_" .. tostring(server_index)
	local cached = mod.active_player_buffs[key]
	local template_id = cached and cached.buff_template_id or nil
	local fields = {
		'"player_uuid":' .. json_string(identity.uuid),
		'"account_id":' .. json_string(identity.account_id),
		'"character_id":' .. json_string(identity.character_id),
		'"player_name":' .. json_string(identity.name),
		'"buff_template_id":' .. json_number(template_id),
		'"buff_template_name":' .. json_string(cached_buff_template_name(template_id)),
		'"server_index":' .. json_number(server_index),
		'"buff_instance_id":' .. json_string(cached and cached.buff_instance_id or nil),
		'"buff_generation":' .. json_number(cached and cached.generation or nil),
		'"cache_miss":' .. tostring(cached == nil),
		'"capture_source":' .. json_string(capture_source),
		'"extension_class":' .. json_string(self and self.__class_name or nil),
	}

	for i = 1, #(state_fields or {}) do
		fields[#fields + 1] = state_fields[i]
	end

	write_event(event_name, fields, false)
end

mod._dtlogs_pending_module_hooks = mod._dtlogs_pending_module_hooks or {}
mod._dtlogs_module_hook_registered = mod._dtlogs_module_hook_registered or {}
mod._dtlogs_required_module_classes = mod._dtlogs_required_module_classes or {}
mod._dtlogs_direct_module_hooks = mod._dtlogs_direct_module_hooks or {}

mod.buff_hook_capability_key = function(class_name, method_name)
	if class_name == "BuffExtensionBase" then
		if method_name == "rpc_add_buff_with_stacks"
			or method_name == "rpc_remove_buff_stacks"
			or method_name == "rpc_buff_set_start_time"
			or method_name == "rpc_buff_set_extra_duration"
			or method_name == "rpc_buff_batched_proc_set_active_time"
		then
			return method_name
		elseif method_name == "_on_remove_buff_stack" then
			return "predicted_on_remove_buff_stack"
		end
	elseif class_name == "PlayerUnitBuffExtension" then
		if method_name == "_on_add_buff" then
			return "predicted_on_add_buff"
		elseif method_name == "_on_add_buff_stack" then
			return "predicted_on_add_buff_stack"
		elseif method_name == "_on_remove_buff" then
			return "predicted_on_remove_buff"
		elseif method_name == "_set_proc_active_start_time" then
			return "proc_state_setter"
		elseif method_name == "_set_start_time_from_rpc" then
			return "start_time_state_setter"
		elseif method_name == "_set_extra_duration_from_rpc" then
			return "extra_duration_state_setter"
		end
	end
	return nil
end

mod.refresh_predicted_buff_hook_capability = function()
	local caps = mod.buff_hook_capabilities
	if not caps then
		return
	end
	caps.predicted_lifecycle_callbacks =
		caps.predicted_on_add_buff == true
		and caps.predicted_on_add_buff_stack == true
		and caps.predicted_on_remove_buff_stack == true
		and caps.predicted_on_remove_buff == true
end

mod.install_direct_module_hook = function(class_name, method_name, callback, required_class)
	if type(required_class) ~= "table" or type(required_class[method_name]) ~= "function" then
		return false
	end
	local hook_key = tostring(class_name) .. "." .. tostring(method_name)
	if mod._dtlogs_direct_module_hooks[hook_key] then
		return true
	end
	local ok_hook, error_message = pcall(function()
		mod:hook(required_class, method_name, callback)
	end)
	if not ok_hook then
		mod:echo(
			"DTLogs: hook skipped for "
			.. class_name
			.. "."
			.. method_name
			.. " — "
			.. tostring(error_message)
		)
		return false
	end
	mod._dtlogs_direct_module_hooks[hook_key] = true
	local capability_key = mod.buff_hook_capability_key(class_name, method_name)
	if capability_key and mod.buff_hook_capabilities then
		mod.buff_hook_capabilities[capability_key] = true
		mod.refresh_predicted_buff_hook_capability()
	end
	return true
end

local function hook_if_present(class_name, method_name, callback)
	local class = CLASS and CLASS[class_name]
	if class and type(class[method_name]) == "function" then
		return safe_hook(class_name, method_name, callback)
	end

	-- Do NOT original_require buff extension modules here. Darktide may currently
	-- be in the middle of requiring the same dependency chain, which poisons the
	-- require cache and can prevent the hub/gameplay extension system from loading.
	-- DMF hook_require is designed for this case: it observes the module after the
	-- game's own require completes and hands us the returned module-local class.
	local module_path = nil
	if class_name == "BuffExtensionBase" then
		module_path = "scripts/extension_systems/buff/buff_extension_base"
	elseif class_name == "PlayerUnitBuffExtension" then
		module_path = "scripts/extension_systems/buff/player_unit_buff_extension"
	end
	if not module_path or type(mod.hook_require) ~= "function" then
		return false
	end

	local hook_key = tostring(class_name) .. "." .. tostring(method_name)
	local cached_class = mod._dtlogs_required_module_classes[module_path]
	if cached_class then
		return mod.install_direct_module_hook(class_name, method_name, callback, cached_class)
	end

	local pending = mod._dtlogs_pending_module_hooks[module_path]
	if not pending then
		pending = {}
		mod._dtlogs_pending_module_hooks[module_path] = pending
	end
	if not pending[hook_key] then
		pending[hook_key] = {
			class_name = class_name,
			method_name = method_name,
			callback = callback,
		}
	end

	if not mod._dtlogs_module_hook_registered[module_path] then
		mod._dtlogs_module_hook_registered[module_path] = true
		local ok_register, error_message = pcall(function()
			mod:hook_require(module_path, function(required_class)
				if type(required_class) ~= "table" then
					return
				end
				mod._dtlogs_required_module_classes[module_path] = required_class
				local queued = mod._dtlogs_pending_module_hooks[module_path] or {}
				for _, entry in pairs(queued) do
					mod.install_direct_module_hook(entry.class_name, entry.method_name, entry.callback, required_class)
				end
			end)
		end)
		if not ok_register then
			mod._dtlogs_module_hook_registered[module_path] = nil
			mod:echo("DTLogs: hook_require registration failed for " .. module_path .. " — " .. tostring(error_message))
			return false
		end
	end

	-- hook_require executes immediately when the file is already in DMF's require
	-- store. Otherwise the capability is flipped to true by the callback later.
	if mod._dtlogs_direct_module_hooks[hook_key] then
		return true
	end
	return false
end

mod.buff_hook_capabilities = {}

mod.is_local_player_buff_extension = function(self)
	local context = self and self._buff_context
	return context ~= nil and context.player ~= nil and context.is_local_unit == true
end

mod.log_predicted_buff_lifecycle = function(self, event_name, buff_instance, stack_count_before, stack_count_after, change, capture_source)
	if not mod.current_file or not mod.is_local_player_buff_extension(self) then
		return
	end
	local state = mod.predicted_buff_instance_state(buff_instance)
	if not state or state.predicted ~= true then
		return
	end
	local event_time_ms = mission_elapsed_ms()
	local identity = cached_player_identity(self and self._unit, event_time_ms)
	if not identity then
		return
	end
	local template_name = state.template_name
	local buff_template_id = NetworkLookup and NetworkLookup.buff_templates and template_name and NetworkLookup.buff_templates[template_name] or nil
	local template = nil
	if buff_instance and type(buff_instance.template) == "function" then
		local ok, value = pcall(buff_instance.template, buff_instance)
		if ok and type(value) == "table" then
			template = value
		end
	end
	local definition_key = player_buff_definition_key(buff_template_id)
	if not mod.buff_definitions_written[definition_key] then
		local visible, visibility_source, hud_priority, has_hud_icon, show_in_hud = buff_visibility(template)
		ensure_player_buff_definition(buff_template_id, template, "predicted_lifecycle", visible, visibility_source, hud_priority, has_hud_icon, show_in_hud)
	end
	local effective_before = mod.buff_effective_stack_count(state, stack_count_before)
	local effective_after = mod.buff_effective_stack_count(state, stack_count_after)
	local active_end_time = state.active_start_time and state.active_duration and (state.active_start_time + state.active_duration) or nil
	local fields = {
		'"player_uuid":' .. json_string(identity.uuid),
		'"account_id":' .. json_string(identity.account_id),
		'"character_id":' .. json_string(identity.character_id),
		'"player_name":' .. json_string(identity.name),
		'"buff_template_id":' .. json_number(buff_template_id),
		'"buff_template_name":' .. json_string(template_name),
		'"buff_instance_local_id":' .. json_number(state.instance_id),
		'"component_index":' .. json_number(state.component_index),
		'"stack_count_before":' .. json_number(stack_count_before),
		'"stack_count_after":' .. json_number(stack_count_after),
		'"effective_stack_count_before":' .. json_number(effective_before),
		'"effective_stack_count_after":' .. json_number(effective_after),
		'"max_stacks":' .. json_number(state.max_stacks),
		'"max_stacks_cap":' .. json_number(state.max_stacks_cap),
		'"duration":' .. json_number(state.duration),
		'"extra_duration":' .. json_number(state.extra_duration),
		'"game_start_time":' .. json_number(state.start_time),
		'"active_start_time":' .. json_number(state.active_start_time),
		'"active_duration":' .. json_number(state.active_duration),
		'"active_end_time":' .. json_number(active_end_time),
		'"proc_count":' .. json_number(state.proc_count),
		'"is_proc_active":' .. (state.is_proc_active == nil and 'null' or tostring(state.is_proc_active == true)),
		'"predicted":true',
		'"capture_source":' .. json_string(capture_source),
	}
	if change then
		fields[#fields + 1] = '"change":' .. json_string(change)
	end
	write_event(event_name, fields, false)
end


-- Convert the local buff index used by PlayerUnitBuffExtension's internal state
-- mutators back to the server index used by DTLogs' stable buff-instance cache.
-- The map is server_index -> local_index, so reverse lookup is intentionally
-- done only on state-change events rather than per frame.
mod.player_buff_server_index_from_local_index = function(self, local_index)
	if type(self) ~= "table" or local_index == nil or type(self._buff_index_map) ~= "table" then
		return nil
	end
	for server_index, mapped_local_index in pairs(self._buff_index_map) do
		if mapped_local_index == local_index then
			return server_index
		end
	end
	return nil
end

-- Canonical proc capture. Darktide ultimately mutates proc state through
-- PlayerUnitBuffExtension._set_proc_active_start_time on the receiving client.
-- This is more reliable than observing only the network delegate entry point,
-- while still remaining event-driven and avoiding per-frame polling.
mod.log_player_buff_proc_activation = function(self, local_index, activation_time, capture_source)
	if not mod.current_file or not mod.is_local_player_buff_extension(self) then
		return
	end
	local server_index = mod.player_buff_server_index_from_local_index(self, local_index)
	if server_index == nil then
		return
	end
	local state = mod.player_buff_instance_state(self, server_index)
	local active_duration = state and state.active_duration or nil
	local sampled_active_start_time = state and state.active_start_time or nil
	local effective_activation_time = sampled_active_start_time or activation_time
	local active_end_time = effective_activation_time and active_duration and (effective_activation_time + active_duration) or nil
	mod.log_player_buff_state_event(self, "player_buff_proc_activated", self._game_object_id, server_index, capture_source, {
		'"activation_time":' .. json_number(activation_time),
		'"sampled_active_start_time":' .. json_number(sampled_active_start_time),
		'"active_duration":' .. json_number(active_duration),
		'"active_end_time":' .. json_number(active_end_time),
		'"proc_count":' .. json_number(state and state.proc_count),
		'"is_proc_active_after":' .. (state and state.is_proc_active ~= nil and tostring(state.is_proc_active == true) or 'null'),
	})
end

local function install_local_player_buff_hooks()
	-- Darktide 1.12.x signature. rpc_add_buff/rpc_remove_buff are already proven
	-- on PlayerUnitBuffExtension in live logs; keep those hooks unchanged.
	mod.buff_hook_capabilities.rpc_add_buff = safe_hook("PlayerUnitBuffExtension", "rpc_add_buff", function(func, self, channel_id, game_object_id, buff_template_id, server_index, owner_unit_id, optional_lerp_value, optional_item_slot_id, optional_parent_buff_template_id, from_talent, ...)
		local template_name = NetworkLookup and NetworkLookup.buff_templates and NetworkLookup.buff_templates[buff_template_id]
		local existing = template_name and self and self._stacking_buffs and self._stacking_buffs[template_name]
		local state_before = mod.predicted_buff_instance_state(existing)
		local result = func(self, channel_id, game_object_id, buff_template_id, server_index, owner_unit_id, optional_lerp_value, optional_item_slot_id, optional_parent_buff_template_id, from_talent, ...)
		if mod.current_file then
			guarded_event("BUFF_ADD_PlayerUnitBuffExtension", function()
				log_player_buff_added(self, game_object_id, buff_template_id, {server_index}, owner_unit_id, optional_lerp_value, optional_item_slot_id, optional_parent_buff_template_id, from_talent, "PlayerUnitBuffExtension.rpc_add_buff", state_before)
			end)
		end
		return result
	end)

	-- These RPC handlers are declared directly on BuffExtensionBase, not on the
	-- subclass table. v0.13.36 therefore reported false even though the client
	-- registers and receives them. Gate the base hooks to the local player only.
	mod.buff_hook_capabilities.rpc_add_buff_with_stacks = hook_if_present("BuffExtensionBase", "rpc_add_buff_with_stacks", function(func, self, channel_id, game_object_id, buff_template_id, server_index_array, owner_unit_id, optional_lerp_value, optional_item_slot_id, optional_parent_buff_template_id, ...)
		local should_capture = mod.is_local_player_buff_extension(self)
		local template_name = should_capture and NetworkLookup and NetworkLookup.buff_templates and NetworkLookup.buff_templates[buff_template_id] or nil
		local existing = template_name and self and self._stacking_buffs and self._stacking_buffs[template_name]
		local state_before = mod.predicted_buff_instance_state(existing)
		local result = func(self, channel_id, game_object_id, buff_template_id, server_index_array, owner_unit_id, optional_lerp_value, optional_item_slot_id, optional_parent_buff_template_id, ...)
		if should_capture and mod.current_file then
			guarded_event("BUFF_ADD_STACKS_BuffExtensionBase", function()
				log_player_buff_added(self, game_object_id, buff_template_id, server_index_array, owner_unit_id, optional_lerp_value, optional_item_slot_id, optional_parent_buff_template_id, nil, "BuffExtensionBase.rpc_add_buff_with_stacks", state_before)
			end)
		end
		return result
	end)

	mod.buff_hook_capabilities.rpc_remove_buff = safe_hook("PlayerUnitBuffExtension", "rpc_remove_buff", function(func, self, channel_id, game_object_id, server_index, ...)
		local state_before = mod.player_buff_instance_state(self, server_index)
		local result = func(self, channel_id, game_object_id, server_index, ...)
		if mod.current_file then
			guarded_event("BUFF_REMOVE_PlayerUnitBuffExtension", function()
				local stack_after = state_before and math.max((state_before.stack_count or 1) - 1, 0) or nil
				log_player_buff_removed(self, game_object_id, server_index, "PlayerUnitBuffExtension.rpc_remove_buff", 1, state_before, stack_after)
			end)
		end
		return result
	end)

	mod.buff_hook_capabilities.rpc_remove_buff_stacks = hook_if_present("BuffExtensionBase", "rpc_remove_buff_stacks", function(func, self, channel_id, game_object_id, server_index_array, ...)
		local should_capture = mod.is_local_player_buff_extension(self)
		local state_before = should_capture and server_index_array and server_index_array[1] and mod.player_buff_instance_state(self, server_index_array[1]) or nil
		local result = func(self, channel_id, game_object_id, server_index_array, ...)
		if should_capture and mod.current_file then
			guarded_event("BUFF_REMOVE_STACKS_BuffExtensionBase", function()
				local initial_stack_count = state_before and state_before.stack_count or nil
				for i = 1, #(server_index_array or {}) do
					local per_entry_before = state_before
					if state_before and initial_stack_count then
						per_entry_before = table.clone and table.clone(state_before) or {
							stack_count = state_before.stack_count,
							effective_stack_count = state_before.effective_stack_count,
							max_stacks = state_before.max_stacks,
							max_stacks_cap = state_before.max_stacks_cap,
							max_stat_stacks = state_before.max_stat_stacks,
							stack_offset = state_before.stack_offset,
						}
						per_entry_before.stack_count = math.max(initial_stack_count - (i - 1), 0)
						per_entry_before.effective_stack_count = mod.buff_effective_stack_count(state_before, per_entry_before.stack_count)
					end
					local stack_after = initial_stack_count and math.max(initial_stack_count - i, 0) or nil
					log_player_buff_removed(self, game_object_id, server_index_array[i], "BuffExtensionBase.rpc_remove_buff_stacks", 1, per_entry_before, stack_after)
				end
			end)
		end
		return result
	end)

	mod.buff_hook_capabilities.rpc_buff_set_start_time = hook_if_present("BuffExtensionBase", "rpc_buff_set_start_time", function(func, self, channel_id, game_object_id, server_index, activation_frame, ...)
		return func(self, channel_id, game_object_id, server_index, activation_frame, ...)
	end)

	mod.buff_hook_capabilities.rpc_buff_set_extra_duration = hook_if_present("BuffExtensionBase", "rpc_buff_set_extra_duration", function(func, self, channel_id, game_object_id, server_index, extra_duration, ...)
		return func(self, channel_id, game_object_id, server_index, extra_duration, ...)
	end)

	mod.buff_hook_capabilities.rpc_buff_batched_proc_set_active_time = hook_if_present("BuffExtensionBase", "rpc_buff_batched_proc_set_active_time", function(func, self, channel_id, game_object_id, server_index_array, activation_frame, ...)
		-- Keep this hook as a capability/compatibility probe. Canonical proc events
		-- are emitted from _set_proc_active_start_time below, after the live buff
		-- instance has actually been updated.
		return func(self, channel_id, game_object_id, server_index_array, activation_frame, ...)
	end)

	-- Hook the actual client-side state mutators. The network RPC handlers and
	-- component correction path converge on these methods, so they are the
	-- authoritative event boundary for proc/start-time/extra-duration changes.
	mod.buff_hook_capabilities.proc_state_setter = hook_if_present("PlayerUnitBuffExtension", "_set_proc_active_start_time", function(func, self, local_index, activation_time, skip_send_active_time_rpc, ...)
		local should_capture = mod.is_local_player_buff_extension(self) and self._is_server ~= true
		local result = func(self, local_index, activation_time, skip_send_active_time_rpc, ...)
		if should_capture and mod.current_file then
			guarded_event("BUFF_PROC_STATE_SETTER_PlayerUnitBuffExtension", function()
				mod.log_player_buff_proc_activation(self, local_index, activation_time, "PlayerUnitBuffExtension._set_proc_active_start_time")
			end)
		end
		return result
	end)

	mod.buff_hook_capabilities.start_time_state_setter = hook_if_present("PlayerUnitBuffExtension", "_set_start_time_from_rpc", function(func, self, local_index, start_time, ...)
		local should_capture = mod.is_local_player_buff_extension(self)
		local result = func(self, local_index, start_time, ...)
		if should_capture and mod.current_file then
			guarded_event("BUFF_START_TIME_STATE_SETTER_PlayerUnitBuffExtension", function()
				local server_index = mod.player_buff_server_index_from_local_index(self, local_index)
				if server_index ~= nil then
					local state = mod.player_buff_instance_state(self, server_index)
					mod.log_player_buff_state_event(self, "player_buff_start_time_changed", self._game_object_id, server_index, "PlayerUnitBuffExtension._set_start_time_from_rpc", {
						'"start_time":' .. json_number(start_time),
						'"sampled_start_time":' .. json_number(state and state.start_time),
					})
				end
			end)
		end
		return result
	end)

	mod.buff_hook_capabilities.extra_duration_state_setter = hook_if_present("PlayerUnitBuffExtension", "_set_extra_duration_from_rpc", function(func, self, local_index, extra_duration, ...)
		local should_capture = mod.is_local_player_buff_extension(self)
		local result = func(self, local_index, extra_duration, ...)
		if should_capture and mod.current_file then
			guarded_event("BUFF_EXTRA_DURATION_STATE_SETTER_PlayerUnitBuffExtension", function()
				local server_index = mod.player_buff_server_index_from_local_index(self, local_index)
				if server_index ~= nil then
					local state = mod.player_buff_instance_state(self, server_index)
					mod.log_player_buff_state_event(self, "player_buff_extra_duration_changed", self._game_object_id, server_index, "PlayerUnitBuffExtension._set_extra_duration_from_rpc", {
						'"extra_duration":' .. json_number(extra_duration),
						'"sampled_extra_duration":' .. json_number(state and state.extra_duration),
					})
				end
			end)
		end
		return result
	end)

	-- Predicted buffs do not need private _add_predicted_buff/_remove_predicted_buff
	-- hooks. These lifecycle callbacks are fired by BuffExtensionBase at the exact
	-- point where a buff/stack is added or removed and expose the live instance.
	mod.buff_hook_capabilities.predicted_on_add_buff = hook_if_present("PlayerUnitBuffExtension", "_on_add_buff", function(func, self, buff_instance, ...)
		local result = func(self, buff_instance, ...)
		if mod.current_file then
			guarded_event("BUFF_PREDICTED_ON_ADD", function()
				local state = mod.predicted_buff_instance_state(buff_instance)
				if state and state.predicted == true then
					mod.log_predicted_buff_lifecycle(self, "player_predicted_buff_added", buff_instance, 0, state.stack_count or 1, nil, "PlayerUnitBuffExtension._on_add_buff")
				end
			end)
		end
		return result
	end)

	mod.buff_hook_capabilities.predicted_on_add_buff_stack = hook_if_present("PlayerUnitBuffExtension", "_on_add_buff_stack", function(func, self, buff_instance, previous_stack_count, ...)
		local result = func(self, buff_instance, previous_stack_count, ...)
		if mod.current_file then
			guarded_event("BUFF_PREDICTED_ON_ADD_STACK", function()
				local state = mod.predicted_buff_instance_state(buff_instance)
				if state and state.predicted == true then
					mod.log_predicted_buff_lifecycle(self, "player_predicted_buff_stack_changed", buff_instance, previous_stack_count, state.stack_count, "add", "PlayerUnitBuffExtension._on_add_buff_stack")
				end
			end)
		end
		return result
	end)

	mod.buff_hook_capabilities.predicted_on_remove_buff_stack = hook_if_present("BuffExtensionBase", "_on_remove_buff_stack", function(func, self, buff_instance, previous_stack_count, ...)
		local result = func(self, buff_instance, previous_stack_count, ...)
		if mod.current_file and mod.is_local_player_buff_extension(self) then
			guarded_event("BUFF_PREDICTED_ON_REMOVE_STACK", function()
				local state = mod.predicted_buff_instance_state(buff_instance)
				if state and state.predicted == true then
					mod.log_predicted_buff_lifecycle(self, "player_predicted_buff_stack_changed", buff_instance, previous_stack_count, state.stack_count, "remove", "BuffExtensionBase._on_remove_buff_stack")
				end
			end)
		end
		return result
	end)

	mod.buff_hook_capabilities.predicted_on_remove_buff = hook_if_present("PlayerUnitBuffExtension", "_on_remove_buff", function(func, self, buff_instance, ...)
		local state_before = mod.predicted_buff_instance_state(buff_instance)
		local result = func(self, buff_instance, ...)
		if mod.current_file and state_before and state_before.predicted == true then
			guarded_event("BUFF_PREDICTED_ON_REMOVE", function()
				mod.log_predicted_buff_lifecycle(self, "player_predicted_buff_removed", buff_instance, state_before.stack_count or 1, 0, nil, "PlayerUnitBuffExtension._on_remove_buff")
			end)
		end
		return result
	end)

	mod.buff_hook_capabilities.predicted_lifecycle_callbacks =
		mod.buff_hook_capabilities.predicted_on_add_buff == true
		and mod.buff_hook_capabilities.predicted_on_add_buff_stack == true
		and mod.buff_hook_capabilities.predicted_on_remove_buff_stack == true
		and mod.buff_hook_capabilities.predicted_on_remove_buff == true
end
install_local_player_buff_hooks()


-- Remote buff probing was intentionally removed in v0.13.5.
-- Local PlayerUnitBuffExtension events remain fully recorded.

safe_hook("PlayerUnitAbilityExtension", "update", function(func, self, unit, dt, t, ...)
	local result = func(self, unit, dt, t, ...)
	guarded_event("ABILITY_LOCAL", function()
		track_ability_charges(self, unit)
	end)
	return result
end)

safe_hook("PlayerHuskAbilityExtension", "update", function(func, self, unit, dt, t, ...)
	local result = func(self, unit, dt, t, ...)
	guarded_event("ABILITY_HUSK", function()
		-- Keep teammate ability-use tracking, but do not inspect remote buff/profile
		-- extensions during combat.
		track_ability_charges(self, unit)
	end)
	return result
end)

safe_hook("PlayerUnitMoodExtension", "update", function(func, self, unit, dt, t, ...)
	local result = func(self, unit, dt, t, ...)

	if mod.current_file then
		guarded_event("PLAYER_STATE", function()
			local component = self._character_state_read_component
			local state_name = component and component.state_name
			local key = tostring(unit_uuid(unit))
			local previous = mod.active_player_states[key]

			if should_log_player_state(previous, state_name) then
				if state_name == "dodging" then
					write_event("player_dodge", {
						'"player_uuid":' .. json_string(unit_uuid(unit)),
						'"player_name":' .. json_string(safe_player_name(player_from_unit(unit))),
						'"previous_state":' .. json_string(previous),
						'"position":' .. unit_position_json(unit),
					}, false)
				elseif previous ~= "dodging" then
					local disabling_uuid = nil
					local unit_data_extension = self._unit_data_extension

					if unit_data_extension then
						local ok, disabled = pcall(function()
							return unit_data_extension:read_component("disabled_character_state")
						end)

						if ok and disabled and disabled.disabling_unit then
							disabling_uuid = unit_uuid(disabled.disabling_unit)
						end
					end

					write_event("player_state_changed", {
						'"player_uuid":' .. json_string(unit_uuid(unit)),
						'"player_name":' .. json_string(safe_player_name(player_from_unit(unit))),
						'"previous_state":' .. json_string(previous),
						'"state":' .. json_string(state_name),
						'"disabling_unit_uuid":' .. json_string(disabling_uuid),
					}, false)
				end
			end

			if state_name then
				mod.active_player_states[key] = state_name
			end
		end)
	end

	return result
end)

safe_hook("MinionDeathManager", "rpc_minion_set_dead", function(
	func,
	self,
	channel_id,
	unit_id,
	attack_direction,
	hit_zone_id,
	damage_profile_id,
	do_ragdoll_push,
	herding_template_id_or_nil,
	...
)
	if mod.current_file then
		guarded_event("MINION_DEATH", function()
			local unit = unit_from_network_id(unit_id, false)

			write_event("minion_death", {
				'"unit_uuid":' .. json_string(unit_uuid(unit)),
				'"breed":' .. json_string(safe_breed_name(unit)),
				'"position":' .. unit_position_json(unit),
				'"hit_zone":' .. json_string(hit_zone_id and NetworkLookup.hit_zones[hit_zone_id]),
				'"damage_profile":' .. json_string(NetworkLookup.damage_profile_templates[damage_profile_id]),
				'"herding_template":' .. json_string(
					herding_template_id_or_nil
					and NetworkLookup.herding_templates[herding_template_id_or_nil]
					or nil
				),
				'"attack_direction":' .. vector_to_json(attack_direction),
				'"ragdoll_push":' .. tostring(do_ragdoll_push == true),
			}, false)
		end)
	end

	return func(
		self,
		channel_id,
		unit_id,
		attack_direction,
		hit_zone_id,
		damage_profile_id,
		do_ragdoll_push,
		herding_template_id_or_nil,
		...
	)
end)

safe_hook("GameModeManager", "_set_end_conditions_met", function(func, self, outcome, ...)
	func(self, outcome, ...)

	if mod.current_file then
		-- Ensure the final effective difficulty snapshot is present even for very
		-- short/aborted recordings.
		poll_difficulty_resolution(true)
		write_modifier_context_snapshot("mission_end", true)

		-- Final forced roster check: if someone joined just before the mission ended,
		-- capture their build/loadout without waiting for the 2-second monitor tick.
		poll_player_profiles(0, true)
		local gameplay_clock_end_ms = safe_gameplay_clock_ms()
		if gameplay_clock_end_ms ~= nil then
			mod.gameplay_clock_last_observed_ms = gameplay_clock_end_ms
			mod.gameplay_clock_first_observed_ms = mod.gameplay_clock_first_observed_ms or gameplay_clock_end_ms
		end
		mod.mission_end_observed = true
		if not mod.presence_final_snapshot_written then
			mod.presence_final_snapshot_written = true
			write_presence_roster_snapshot("mission_end", false)
		end
		drain_pending_performance_spikes(math.huge)
		local recording_duration_ms = mission_elapsed_ms()
		local recording_gameplay_span_ms = nil
		local recording_started_at_gameplay_clock_ms = mod.gameplay_clock_first_server_sync_ms or mod.gameplay_clock_first_observed_ms
		if gameplay_clock_end_ms ~= nil and recording_started_at_gameplay_clock_ms ~= nil then
			recording_gameplay_span_ms = math.max(0, gameplay_clock_end_ms - recording_started_at_gameplay_clock_ms)
		end
		local recording_start_estimate_ms = recording_start_gameplay_clock_estimate_ms()
		local recording_status = mission_recording_status()
		local recording_coverage_ratio = nil
		if gameplay_clock_end_ms ~= nil and gameplay_clock_end_ms > 0 and recording_gameplay_span_ms ~= nil then
			recording_coverage_ratio = recording_gameplay_span_ms / gameplay_clock_end_ms
		end
		write_event("mission_ended", {
			'"outcome":' .. json_string(outcome),
			'"mission_name":' .. json_string(mod.current_mission_name),
			'"mod_version":' .. json_string(MOD_VERSION),
			'"game_version":' .. json_string(mod.current_game_version),
			'"game_version_source":' .. json_string(mod.current_game_version_source),
			'"game_build_identifier":' .. json_string(mod.current_game_build_identifier),
			'"game_build_mode":' .. json_string(mod.current_game_build_mode),
			'"game_teamcity_build_id":' .. json_string(mod.current_game_teamcity_build_id),
			'"mission_modifier_semantics_version":1',
			'"mission_modifier_semantics_status":"stable_ids"',
			'"mission_modifiers":' .. json_value(mod.current_mission_modifiers),
			'"mission_modifiers_source":' .. json_string(mod.current_mission_modifiers_source),
			'"mission_modifier_diagnostic_version":1',
			'"modifier_circumstance_name":' .. json_string(mod.current_circumstance),
			'"presence_diagnostic_version":1',
			'"gameplay_clock_diagnostic_version":1',
			'"presence_semantics_version":1',
			'"player_identity_semantics_version":1',
			'"player_identity_semantics_status":"stable_character_id"',
			'"mission_recording_status":' .. json_string(recording_status),
			'"mission_recording_status_source":"server_gameplay_clock_vs_recording_monotonic_origin"',
			'"recording_start_ambiguity_ms":' .. tostring(RECORDING_START_AMBIGUITY_MS),
			'"recording_complete_to_mission_end":true',
			'"recording_duration_ms":' .. json_number(recording_duration_ms),
			'"mission_gameplay_duration_ms":' .. json_number(gameplay_clock_end_ms),
			'"mission_gameplay_duration_source":"server_synced_gameplay_clock"',
			'"gameplay_clock_end_ms":' .. json_number(gameplay_clock_end_ms),
			'"recording_started_at_gameplay_clock_ms":' .. json_number(recording_started_at_gameplay_clock_ms),
			'"recording_start_gameplay_clock_estimate_ms":' .. json_number(recording_start_estimate_ms),
			'"gameplay_clock_first_server_sync_ms":' .. json_number(mod.gameplay_clock_first_server_sync_ms),
			'"gameplay_clock_first_sync_offset":' .. json_number(mod.gameplay_clock_first_sync_offset),
			'"gameplay_clock_first_sync_recording_elapsed_ms":' .. json_number(mod.gameplay_clock_first_sync_recording_elapsed_ms),
			'"gameplay_clock_first_observed_ms":' .. json_number(mod.gameplay_clock_first_observed_ms),
			'"recording_gameplay_span_ms":' .. json_number(recording_gameplay_span_ms),
			'"recorded_gameplay_duration_ms":' .. json_number(recording_gameplay_span_ms),
			'"recording_gameplay_coverage_ratio":' .. json_number(recording_coverage_ratio),
			'"gameplay_clock_sync_count":' .. tostring(mod.gameplay_clock_sync_count or 0),
			'"gameplay_state_enter_observed":' .. tostring(mod.gameplay_state_enter_observed == true),
			'"session_join_event_count":' .. tostring(mod.session_join_event_count or 0),
			'"session_leave_event_count":' .. tostring(mod.session_leave_event_count or 0),
			'"total_event_count":' .. tostring(mod.event_count + 1),
			'"attack_result_count":' .. tostring(mod.event_type_counts.attack_result or 0),
			'"blocked_attack_count":' .. tostring(mod.event_type_counts.blocked_attack or 0),
			'"player_damage_taken_count":' .. tostring(mod.event_type_counts.player_damage_taken or 0),
			'"ability_used_count":' .. tostring(mod.event_type_counts.ability_used or 0),
			'"player_health_changed_count":' .. tostring(mod.event_type_counts.player_health_changed or 0),
			'"player_toughness_changed_count":' .. tostring(mod.event_type_counts.player_toughness_changed or 0),
			'"player_buff_added_count":' .. tostring(mod.event_type_counts.player_buff_added or 0),
			'"player_buff_removed_count":' .. tostring(mod.event_type_counts.player_buff_removed or 0),
			'"coherency_enter_count":' .. tostring(mod.event_type_counts.player_coherency_entered or 0),
			'"coherency_exit_count":' .. tostring(mod.event_type_counts.player_coherency_exited or 0),
			'"interaction_count":' .. tostring(
				(mod.event_type_counts.interaction_started or 0)
				+ (mod.event_type_counts.interaction_stopped or 0)
			),
			'"ability_charge_event_count":' .. tostring(mod.event_type_counts.ability_charge_changed or 0),
			'"important_state_event_count":' .. tostring(mod.event_type_counts.player_state_changed or 0),
			'"suppression_event_count":' .. tostring(mod.event_type_counts.player_suppressed or 0),
			'"minion_death_count":' .. tostring(mod.event_type_counts.minion_death or 0),
			'"total_actual_damage":' .. tostring(mod.total_actual_damage),
			'"total_effective_enemy_damage":' .. tostring(mod.total_effective_enemy_damage or 0),
			'"total_scoreboard_damage":' .. tostring(mod.total_effective_enemy_damage or 0),
			'"total_overkill_damage":null',
			'"overkill_semantics_available":false',
			'"enemy_damage_event_count":' .. tostring(mod.enemy_damage_event_count or 0),
			'"enemy_damage_fallback_count":' .. tostring(mod.enemy_damage_fallback_count or 0),
			'"enemy_health_cache_hit_count":' .. tostring(mod.enemy_health_cache_hit_count or 0),
			'"enemy_health_cache_miss_count":' .. tostring(mod.enemy_health_cache_miss_count or 0),
			'"enemy_health_cache_seed_count":' .. tostring(mod.enemy_health_cache_seed_count or 0),
			'"enemy_health_read_fallback_count":' .. tostring(mod.enemy_health_read_fallback_count or 0),
			'"scoreboard_damage_outlier_count":' .. tostring(mod.scoreboard_damage_outlier_count or 0),
			'"enemy_damage_accounting_anomaly_count":' .. tostring(mod.enemy_damage_accounting_anomaly_count or 0),
			'"total_player_damage_taken":' .. tostring(mod.total_player_damage_taken),
			'"total_health_lost":' .. tostring(mod.total_health_lost),
			'"total_health_restored":' .. tostring(mod.total_health_restored),
			'"total_toughness_lost":' .. tostring(mod.total_toughness_lost),
			'"total_toughness_restored":' .. tostring(mod.total_toughness_restored),
			'"buff_definition_count":' .. tostring(mod.buff_definition_count or 0),
			'"player_build_snapshot_count":' .. tostring(mod.profile_snapshot_count or 0),
			'"late_join_build_snapshot_count":' .. tostring(mod.profile_late_join_snapshot_count or 0),
			'"capture_queue_peak":' .. tostring(mod.capture_queue_peak or 0),
			'"pending_line_peak":' .. tostring(mod.pending_line_peak or 0),
			'"pending_line_byte_peak":' .. tostring(mod.pending_line_byte_peak or 0),
			'"physical_line_count_before_end":' .. tostring(mod.physical_line_count or 0),
			'"buff_batch_line_count":' .. tostring(mod.buff_batch_line_count or 0),
			'"buff_batch_logical_event_count":' .. tostring(mod.buff_batch_logical_event_count or 0),
			'"buff_batch_peak_entries":' .. tostring(mod.buff_batch_peak_entries or 0),
			'"write_chunk_count":' .. tostring(mod.write_chunk_count or 0),
			'"max_write_chunk_bytes":' .. tostring(mod.max_write_chunk_bytes or 0),
			'"capture_queue_backlog_before_end":' .. tostring(mod.capture_queue_count or 0),
			'"serialized_event_count_before_end":' .. tostring(mod.serialized_event_count or 0),
			'"zero_damage_event_count":' .. tostring(mod.zero_damage_event_count),
			'"performance_spike_count":' .. tostring(mod.performance_spike_count or 0),
			'"performance_spike_written_count":' .. tostring(mod.performance_spike_written_count or 0),
			'"performance_spike_dropped":' .. tostring(mod.performance_spike_dropped or 0),
			'"frame_spike_count":' .. tostring((mod.performance_spike_counts and mod.performance_spike_counts.frame) or 0),
			'"hook_spike_count":' .. tostring((mod.performance_spike_counts and mod.performance_spike_counts.hook) or 0),
			'"serialize_spike_count":' .. tostring((mod.performance_spike_counts and mod.performance_spike_counts.serialize) or 0),
			'"write_spike_count":' .. tostring((mod.performance_spike_counts and mod.performance_spike_counts.write) or 0),
			'"flush_spike_count":' .. tostring((mod.performance_spike_counts and mod.performance_spike_counts.flush) or 0),
			'"addon_update_spike_count":' .. tostring((mod.performance_spike_counts and mod.performance_spike_counts.addon_update) or 0),
			'"max_frame_duration_ms":' .. json_number((mod.max_performance_duration_ms and mod.max_performance_duration_ms.frame) or 0),
			'"max_hook_duration_ms":' .. json_number((mod.max_performance_duration_ms and mod.max_performance_duration_ms.hook) or 0),
			'"max_hook_label":' .. json_string(mod.max_performance_label and mod.max_performance_label.hook),
			'"max_serialize_duration_ms":' .. json_number((mod.max_performance_duration_ms and mod.max_performance_duration_ms.serialize) or 0),
			'"max_write_duration_ms":' .. json_number((mod.max_performance_duration_ms and mod.max_performance_duration_ms.write) or 0),
			'"max_flush_duration_ms":' .. json_number((mod.max_performance_duration_ms and mod.max_performance_duration_ms.flush) or 0),
			'"max_addon_update_duration_ms":' .. json_number((mod.max_performance_duration_ms and mod.max_performance_duration_ms.addon_update) or 0),
		}, true)

		local completed_log_path = mod.current_file_path
		local log_closed_successfully, close_error = close_current_file()
		if log_closed_successfully then
			mod.last_completed_log_path = completed_log_path
			local upload_this_mission, upload_skip_reason = mod.should_auto_upload_mission(outcome)
			if upload_this_mission then
				local queued, queue_error = queue_auto_upload(completed_log_path)
				if queued then
					mod:echo("DTLogs: Mission recorded. Report queued for automatic upload to DTLogs.com...")
					pump_auto_upload_queue()
				else
					mod:echo("DTLogs: Mission recorded, but it could not be added to the automatic upload queue: " .. tostring(queue_error or "unknown queue error"))
					mod:echo("DTLogs: The mission log is still saved locally and can be uploaded manually.")
				end
			elseif upload_skip_reason == "not_successful" then
				mod:echo("DTLogs: Mission recorded locally. Automatic upload skipped because the upload policy is successful missions only.")
			else
				mod:echo("DTLogs: Mission recorded. Upload your log to DTLogs.com to explore the full combat report, compare your performance with the Darktide community, and see how you stack up.")
			end
		else
			mod:echo("DTLogs: mission ended, but the log file could not be finalized: " .. tostring(close_error or "unknown file error"))
		end
	end
end)

mod:command("dtlogs_status", "Show DTLogs status", function()
	mod:echo("DTLogs v" .. MOD_VERSION .. " is running")
	mod:echo("DTLogs mission_name: " .. tostring(mod.current_mission_name))
	mod:echo("DTLogs file: " .. tostring(mod.current_file_path))
	mod:echo("DTLogs events: " .. tostring(mod.event_count))
	mod:echo("DTLogs game_version: " .. tostring(mod.current_game_version) .. ", build_identifier: " .. tostring(mod.current_game_build_identifier))
	mod:echo("DTLogs difficulty_mode: " .. tostring(mod.current_difficulty_mode) .. ", challenge: " .. tostring(mod.current_challenge) .. ", resistance: " .. tostring(mod.current_resistance) .. ", havoc_rank: " .. tostring(mod.current_havoc_rank))
	mod:echo("DTLogs circumstance: " .. tostring(mod.current_circumstance) .. ", modifier probe: " .. tostring(mod.modifier_startup_snapshot_written and "captured" or "pending"))
	mod:echo("DTLogs resolved difficulty: " .. tostring(mod.current_danger_name) .. ", effective challenge: " .. tostring(mod.current_effective_challenge) .. ", effective resistance: " .. tostring(mod.current_effective_resistance) .. ", is_auric: " .. tostring(mod.current_danger_is_auric))
	mod:echo("DTLogs queue: " .. tostring(mod.capture_queue_count) .. ", pending lines: " .. tostring(mod.pending_line_count) .. ", pending bytes: " .. tostring(mod.pending_line_bytes or 0))
	mod:echo("DTLogs performance spikes: " .. tostring(mod.performance_spike_count or 0) .. ", pending diagnostics: " .. tostring(mod.pending_performance_spike_count or 0))
	local upload_identity, upload_key = AUTO_UPLOAD_AUTH.current()
	local auth_status = mod.auto_upload_auth_blocked and ("paused (" .. tostring(mod.auto_upload_auth_block_reason or "authorization error") .. ")") or "ready"
	mod:echo("DTLogs auto upload: " .. tostring(auto_upload_enabled() and "enabled" or "disabled") .. ", policy: " .. tostring(mod.auto_upload_scope()) .. ", identity: " .. tostring(upload_identity == "linked" and AUTO_UPLOAD_AUTH.mask(upload_key) or "anonymous") .. ", auth: " .. auth_status .. ", queued: " .. tostring(#(mod.auto_upload_queue or {})) .. ", active: " .. tostring(#(mod.auto_upload_jobs or {})) .. ", launcher: " .. tostring(native_upload_launcher_available and "native ShellExecuteW" or ("unavailable (" .. tostring(native_upload_launcher_error) .. ")")) .. ", last completed log: " .. tostring(mod.last_completed_log_path))
	mod:echo("DTLogs gameplay clock ms: " .. tostring(safe_gameplay_clock_ms()) .. ", first server sync ms: " .. tostring(mod.gameplay_clock_first_server_sync_ms) .. ", first-sync recording elapsed ms: " .. tostring(mod.gameplay_clock_first_sync_recording_elapsed_ms) .. ", recording-start estimate ms: " .. tostring(recording_start_gameplay_clock_estimate_ms()) .. ", status: " .. tostring(mission_recording_status()) .. ", sync count: " .. tostring(mod.gameplay_clock_sync_count or 0))
end)

mod.account_menu_sync_in_progress = false

function mod.account_menu_status_value()
	local upload_identity = AUTO_UPLOAD_AUTH.current()
	if upload_identity == "linked" then
		return "linked"
	end
	return "not_linked"
end

function mod.sync_account_menu_status(_clear_input)
	if mod.account_menu_sync_in_progress then
		return
	end
	mod.account_menu_sync_in_progress = true
	pcall(function()
		mod:set("account_link_status", mod.account_menu_status_value(), true)
		mod:set("account_link_action", "none", true)
		mod:set("account_unlink_action", "keep", true)
	end)
	mod.account_menu_sync_in_progress = false
end

function mod.link_account_from_value(value, source_label)
	local key = AUTO_UPLOAD_AUTH.extract(value)
	if not key then
		mod:echo("DTLogs: invalid account link or upload key. Paste a DTLogs upload key beginning with dtl_up_, or a link that contains that key.")
		mod.sync_account_menu_status(true)
		return false
	end

	local saved, save_error = AUTO_UPLOAD_AUTH.persist(key)
	if not saved then
		mod:echo("DTLogs: could not save the upload key: " .. tostring(save_error or "unknown file error"))
		mod.sync_account_menu_status(true)
		return false
	end

	mod:echo("DTLogs: account upload key saved" .. (source_label and (" from " .. source_label) or "") .. ". Future automatic uploads will use your linked DTLogs.com account.")
	mod:echo("DTLogs: key status: " .. AUTO_UPLOAD_AUTH.mask(key) .. ". The full key will not be shown again by the mod.")
	mod.sync_account_menu_status(true)
	pump_auto_upload_queue()
	return true
end

function mod.unlink_account(source_label)
	local _, existing_key = AUTO_UPLOAD_AUTH.current()
	AUTO_UPLOAD_AUTH.clear()
	if existing_key then
		mod:echo("DTLogs: account disconnected" .. (source_label and (" from " .. source_label) or "") .. ". Future automatic uploads will be anonymous.")
		mod:echo("DTLogs: to reconnect this account later, you will need to enter the DTLogs upload key again.")
	else
		mod:echo("DTLogs: no account upload key was configured. Automatic uploads remain anonymous.")
	end
	mod.sync_account_menu_status(true)
	pump_auto_upload_queue()
end

function mod.on_setting_changed(setting_id)
	if mod.account_menu_sync_in_progress then
		return
	end
	if setting_id == "account_link_action" and mod:get("account_link_action") == "show_command" then
		mod:echo("DTLogs: to link this addon to an account, use /dtlogs_link <upload-key-or-link> in chat. Both a raw dtl_up_... key and text/link containing the key are accepted.")
		mod.sync_account_menu_status(false)
	elseif setting_id == "account_unlink_action" and mod:get("account_unlink_action") == "disconnect" then
		mod.unlink_account("Mod Options")
	elseif setting_id == "account_link_status" then
		-- Status is informational. Restore the actual connection state if the user changes the dropdown.
		mod.sync_account_menu_status(false)
	elseif setting_id == "auto_upload_completed_missions" and auto_upload_enabled() then
		pump_auto_upload_queue()
	end
end

mod:command("dtlogs_link", "Link DTLogs automatic uploads to your DTLogs.com account using an upload key or link", function(key, ...)
	if select("#", ...) > 0 then
		mod:echo("DTLogs: usage: /dtlogs_link <upload-key-or-link>")
		return
	end
	local input = AUTO_UPLOAD_AUTH.normalize(key)
	if input == "" then
		local _, existing_key = AUTO_UPLOAD_AUTH.current()
		if existing_key then
			mod:echo("DTLogs: account uploads are " .. AUTO_UPLOAD_AUTH.mask(existing_key) .. ".")
		else
			mod:echo("DTLogs: no upload key is configured. Usage: /dtlogs_link <upload-key-or-link>")
		end
		return
	end
	mod.link_account_from_value(input, "chat command")
end)

mod:command("dtlogs_unlink", "Remove the DTLogs.com account upload key and return to anonymous uploads", function()
	mod.unlink_account("chat command")
end)

mod:command("dtlogs_link_status", "Show DTLogs.com account-link status without revealing the upload key", function()
	local upload_identity, upload_key = AUTO_UPLOAD_AUTH.current()
	if upload_identity == "linked" then
		mod:echo("DTLogs: " .. AUTO_UPLOAD_AUTH.mask(upload_key) .. ".")
		mod:echo("DTLogs: linked upload endpoint: " .. AUTO_UPLOAD_LINKED_URL)
	else
		mod:echo("DTLogs: automatic uploads are anonymous; no account upload key is configured.")
	end
	if mod.auto_upload_auth_blocked then
		mod:echo("DTLogs: linked uploads are paused because authorization failed: " .. tostring(mod.auto_upload_auth_block_reason or "unknown authorization error") .. ".")
	end
end)

mod:command("dtlogs_upload_last", "Upload the last completed DTLogs mission log", function()
	if not mod.last_completed_log_path then
		mod:echo("DTLogs: no completed mission log is available in this session")
		return
	end

	local queued, queue_error = queue_auto_upload(mod.last_completed_log_path)
	if not queued then
		mod:echo("DTLogs: upload could not be queued: " .. tostring(queue_error or "unknown queue error"))
		return
	end

	local upload_started, upload_error = start_auto_upload(mod.last_completed_log_path)
	if upload_started then
		mod:echo("DTLogs: Uploading the last completed mission log in the background...")
	elseif tostring(upload_error) == "this log is already being uploaded" then
		mod:echo("DTLogs: the last completed mission log is already being uploaded")
	else
		mod.auto_upload_retry_after[mod.last_completed_log_path] = timestamp() + AUTO_UPLOAD_RETRY_DELAY_SECONDS
		mod:echo("DTLogs: upload could not start: " .. tostring(upload_error or "unknown upload error") .. ". The log remains queued.")
	end
end)

mod:command("dtlogs_profile_snapshot", "Capture any missing player build/loadout profiles", function()
	if not mod.current_file then
		mod:echo("DTLogs: this command is available only while a mission is being recorded")
		return
	end
	poll_player_profiles(0, true)
	mod:echo("DTLogs v" .. MOD_VERSION .. ": checked players whose build/loadout snapshot has not yet been recorded")
end)

mod:command("dtlogs_file_test", "Create a test JSONL file", function()
	close_current_file()
	create_output_directory()

	local test_time = timestamp()
	local path = output_directory() .. "test_" .. tostring(test_time) .. ".jsonl"
	local file, error_message = _io.open(path, "w+")

	if not file then
		mod:echo("DTLogs TEST ERROR: " .. tostring(error_message))
		return
	end

	file:write(
		'{"protocol":2,"event":"file_test","timestamp":'
		.. tostring(test_time)
		.. ',"value":12345}\n'
	)
	file:flush()
	file:close()

	mod:echo("DTLogs TEST OK: file created")
end)


-- HUD and teammate-buff diagnostic scanners were removed in v0.13.5.

function mod.update(dt)
	local update_started_at = capture_clock_seconds()
	local frame_dt_seconds = tonumber(dt) or 0
	local previous_metrics = mod.last_update_metrics or {}
	local memory_before = safe_lua_memory_kb()

	-- Upload status polling is intentionally lightweight and independent of an
	-- active mission. curl runs in a separate process; this only checks for the
	-- tiny status file it writes on completion.
	mod.auto_upload_poll_accumulator = (mod.auto_upload_poll_accumulator or 0) + frame_dt_seconds
	if mod.auto_upload_poll_accumulator >= 1.0 then
		mod.auto_upload_poll_accumulator = 0
		poll_auto_upload_jobs()
	end

	mod.auto_upload_scheduler_accumulator = (mod.auto_upload_scheduler_accumulator or 0) + frame_dt_seconds
	if mod.auto_upload_scheduler_accumulator >= 5.0 then
		mod.auto_upload_scheduler_accumulator = 0
		pump_auto_upload_queue()
	end

	if mod.current_file then
		local frame_threshold = (mod.performance_threshold_seconds and mod.performance_threshold_seconds.frame) or 0.050
		if frame_dt_seconds >= frame_threshold then
			record_performance_spike("frame", frame_dt_seconds, "game_frame", {
				frame_dt_ms = round_milliseconds(frame_dt_seconds),
				previous_update_ms = previous_metrics.update_ms,
				previous_resource_poll_ms = previous_metrics.resource_poll_ms,
				previous_profile_poll_ms = previous_metrics.profile_poll_ms,
				previous_serialize_ms = previous_metrics.serialize_ms,
				previous_write_ms = previous_metrics.write_ms,
				previous_flush_ms = previous_metrics.flush_ms,
				queue_before = mod.capture_queue_count or 0,
				pending_lines_before = mod.pending_line_count or 0,
				pending_bytes_before = mod.pending_line_bytes or 0,
				current_event_count = mod.event_count or 0,
				lua_memory_kb = memory_before,
				lua_memory_delta_kb = memory_before and mod.last_lua_memory_kb and (memory_before - mod.last_lua_memory_kb) or nil,
			})
		else
			note_performance_duration("frame", frame_dt_seconds, "game_frame")
		end
	else
		note_performance_duration("frame", frame_dt_seconds, "game_frame")
	end

	if mod.current_file and not mod.difficulty_resolution_written then
		poll_difficulty_resolution(false)
	end

	if mod.current_file and not mod.modifier_startup_snapshot_written then
		write_modifier_context_snapshot("startup_probe", false)
	end

	local resource_started_at = capture_clock_seconds()
	poll_player_resources(dt)
	local resource_poll_seconds = capture_clock_seconds() - resource_started_at

	local profile_started_at = capture_clock_seconds()
	poll_player_profiles(dt, false)
	local profile_poll_seconds = capture_clock_seconds() - profile_started_at
	-- Startup probing becomes a lightweight late-join roster monitor after the initial window.

	local serialize_seconds = 0
	local write_seconds = 0
	local flush_seconds = 0
	if mod.current_file then
		local _, measured_serialize_seconds = process_capture_queue(false)
		serialize_seconds = measured_serialize_seconds or 0

		mod.write_accumulator = (mod.write_accumulator or 0) + frame_dt_seconds
		mod.flush_accumulator = (mod.flush_accumulator or 0) + frame_dt_seconds

		-- At most one byte-bounded write per frame. The bound is independent of
		-- record count, so a few large records cannot create an oversized write.
		if mod.pending_line_bytes >= (mod.max_bytes_per_write or 65536)
			or mod.write_accumulator >= (mod.write_interval_seconds or 0.5)
		then
			local _, _, measured_write_seconds = write_pending_byte_chunk(false)
			write_seconds = measured_write_seconds or 0
			mod.write_accumulator = 0
		end

		-- OS flush is intentionally infrequent; mission end always forces a flush.
		if mod.flush_accumulator >= (mod.flush_interval_seconds or 30.0) then
			flush_seconds = measured_file_flush("periodic_flush", false)
			mod.flush_accumulator = 0
		end
	end

	local update_seconds = capture_clock_seconds() - update_started_at
	if mod.current_file then
		local update_threshold = (mod.performance_threshold_seconds and mod.performance_threshold_seconds.addon_update) or 0.003
		local memory_after = nil
		if update_seconds >= update_threshold then
			memory_after = safe_lua_memory_kb()
			record_performance_spike("addon_update", update_seconds, "mod_update", {
				resource_poll_ms = round_milliseconds(resource_poll_seconds),
				profile_poll_ms = round_milliseconds(profile_poll_seconds),
				serialize_ms = round_milliseconds(serialize_seconds),
				write_ms = round_milliseconds(write_seconds),
				flush_ms = round_milliseconds(flush_seconds),
				queue_after = mod.capture_queue_count or 0,
				pending_lines_after = mod.pending_line_count or 0,
				pending_bytes_after = mod.pending_line_bytes or 0,
				current_event_count = mod.event_count or 0,
				lua_memory_kb = memory_after or memory_before,
				lua_memory_delta_kb = memory_after and memory_before and (memory_after - memory_before) or nil,
			})
		else
			note_performance_duration("addon_update", update_seconds, "mod_update")
		end

		mod.last_update_metrics = {
			update_ms = round_milliseconds(update_seconds),
			resource_poll_ms = round_milliseconds(resource_poll_seconds),
			profile_poll_ms = round_milliseconds(profile_poll_seconds),
			serialize_ms = round_milliseconds(serialize_seconds),
			write_ms = round_milliseconds(write_seconds),
			flush_ms = round_milliseconds(flush_seconds),
		}
		drain_pending_performance_spikes(16)
	end
	mod.last_lua_memory_kb = memory_before or mod.last_lua_memory_kb
end

function mod.on_enabled()
	load_auto_upload_queue()
	mod:echo("DTLogs v" .. MOD_VERSION .. ": logging enabled")
	if auto_upload_enabled() then
		pump_auto_upload_queue()
	end

	-- If the mod is enabled during a mission, start a new log file from this moment.
	if not mod.current_file and is_recordable_mission(mod.current_mission_name) then
		start_mission_file()
	end
end

function mod.on_disabled()
	if mod.current_file then
		write_event("logging_disabled", {
			'"mission_name":' .. json_string(mod.current_mission_name),
			'"recording_duration_ms":' .. json_number(mission_elapsed_ms()),
			'"gameplay_clock_ms":' .. json_number(safe_gameplay_clock_ms()),
			'"presence_diagnostic_version":1',
			'"presence_semantics_version":1',
			'"mission_recording_status":"incomplete"',
			'"total_event_count":' .. tostring(mod.event_count + 1),
		}, true)
	end

	close_current_file()
	mod:echo("DTLogs v" .. MOD_VERSION .. ": logging disabled")
end

function mod.on_unload()
	close_current_file()
end
