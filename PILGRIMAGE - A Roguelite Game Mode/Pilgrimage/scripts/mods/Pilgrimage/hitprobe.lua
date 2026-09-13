-- hitprobe.lua
--
-- A measurement tool for one specific bug: in a Pilgrimage-launched mission, the
-- bots' hits produce YOUR hit markers and their weapons play with your first-person
-- audio.
--
-- ===========================================================================
-- WHY THIS EXISTS RATHER THAN A FIX
-- ===========================================================================
--
-- I found the exact filter that decides who sees a hit marker.
-- scripts/managers/attack_report/attack_report_manager.lua:190-196:
--
--     local first_person_extension = ScriptUnit.has_extension(attacking_unit, "first_person_system")
--     local local_human = not attacking_player.remote and attacking_player:is_human_controlled()
--     local is_in_first_person_mode = first_person_extension and first_person_extension:is_in_first_person_mode()
--     _trigger_hit_events(local_human, is_in_first_person_mode, ...)
--
-- and _trigger_hit_events fires the crosshair report when
-- `local_human or is_in_first_person_mode`.
--
-- Reading the source, BOTH should be false for a bot:
--   * BotPlayer.is_human_controlled returns false (bot_player.lua:25)
--   * a bot's first-person mode resolves through
--     _server_evaluate_other_players_first_person_mode, which returns
--     `is_first_person_spectated and wants_1p_camera`, and
--     _is_first_person_spectated is only set true for a unit the camera is
--     following in spectator mode (player_unit_first_person_extension.lua:532-537)
--
-- So the code says this should not happen, and the game says it does. Guessing at
-- that point produces a plausible fix that quietly does nothing, which is exactly
-- the failure mode the weapon patcher already taught us.
--
-- Two candidates this measures directly:
--   1. Something genuinely makes one of those two values true for bots when we host.
--   2. Another mod is involved. There are 130+ installed here, several of which touch
--      hit feedback (dopamine, DynamicCrosshair, crosshair_hud, NumericUI,
--      KillfeedImprovements, SuperImpact, BetterBots).
--
-- Either way this reports the real values per attack, and then the fix writes itself.

local M = {}

local _mod
local _shared
local _hooks
local _fileio
local _debug_log

local SENTINEL = "__pilgrimage_hitprobe_installed"

M.ATTACK_REPORT_PATH = "scripts/managers/attack_report/attack_report_manager"

local _enabled = false
local _rows = {}
local _max_rows = 60
local _installed = false

-- ---------------------------------------------------------------------------

-- Returns nil when the attacker is not a player. Enemies attack constantly and an
-- enemy hit tells us nothing about who sees a hit marker, so those rows would be
-- pure noise and would fill the cap before a single bot attack landed.
local function describe_attacker(attacking_unit)
	if not attacking_unit then return nil end

	local spawn_manager = Managers and Managers.state and Managers.state.player_unit_spawn
	if not spawn_manager or not spawn_manager.owner then return nil end

	local ok, player = pcall(spawn_manager.owner, spawn_manager, attacking_unit)
	if not ok or not player then return nil end

	local out = {
		owner = "unnamed",
		remote = "?",
		human = "?",
		first_person = "?",
		is_bot = "?",
		local_human = "?",
	}

	out.owner = tostring(player.name and player:name() or "unnamed")
	out.remote = tostring(player.remote)

	local ok_human, human = pcall(player.is_human_controlled, player)
	out.human = ok_human and tostring(human) or "err"

	-- A bot is a player that is not human controlled.
	out.is_bot = (ok_human and not human) and "true" or "false"

	-- Recompute the game's own expression exactly.
	if ok_human then
		out.local_human = tostring(not player.remote and human)
	end

	local extension = _shared.extension(attacking_unit, "first_person_system")
	if extension and extension.is_in_first_person_mode then
		local ok_fp, fp = pcall(extension.is_in_first_person_mode, extension)
		out.first_person = ok_fp and tostring(fp) or "err"

		-- The two inputs that decide it for a non-human player.
		out.spectated = tostring(rawget(extension, "_is_first_person_spectated"))
		out.wants_1p = tostring(rawget(extension, "_wants_1p_camera"))
		out.local_unit = tostring(rawget(extension, "_is_local_unit"))
		out.force_3p = tostring(rawget(extension, "_force_third_person_mode"))
	end

	return out
end

function M.record(buffer_data)
	if not _enabled then return end
	if #_rows >= _max_rows then return end

	local attacking_unit = buffer_data and buffer_data.attacking_unit
	if not attacking_unit then return end

	local info = describe_attacker(attacking_unit)
	if not info then return end

	-- Only the interesting case: an attack by something that is not the local human.
	-- A row here that also shows a hit marker is the bug.
	_rows[#_rows + 1] = string.format(
		"%-18s bot=%-5s remote=%-5s human=%-5s local_human=%-5s fp_mode=%-5s " ..
		"spectated=%-5s wants_1p=%-5s local_unit=%-5s force_3p=%-5s  WOULD_SHOW_MARKER=%s",
		info.owner, info.is_bot, info.remote, info.human, info.local_human,
		info.first_person, tostring(info.spectated), tostring(info.wants_1p),
		tostring(info.local_unit), tostring(info.force_3p),
		tostring(info.local_human == "true" or info.first_person == "true"))
end

-- ---------------------------------------------------------------------------

function M.install(AttackReportManager)
	if not AttackReportManager then return end
	if _hooks.claim(AttackReportManager, SENTINEL) then return end

	-- hook_safe: pure observation. This runs per attack, so it early-outs on the
	-- disabled flag before doing anything at all.
	_mod:hook_safe(AttackReportManager, "_process_attack_result", function(self, buffer_data)
		M.record(buffer_data)
	end)

	_installed = true
end

function M.set_enabled(enabled)
	_enabled = enabled == true
	if _enabled then _rows = {} end
end

function M.is_enabled() return _enabled end
function M.is_installed() return _installed end
function M.row_count() return #_rows end

function M.report_lines()
	local lines = {
		"Pilgrimage hit-report probe",
		"",
		"One row per attack processed by AttackReportManager while recording.",
		"",
		"The game shows YOUR crosshair hit marker when local_human OR fp_mode is true",
		"(attack_report_manager.lua:190-196 and _trigger_hit_events).",
		"",
		"So: any row with bot=true and WOULD_SHOW_MARKER=true is the bug, and whichever",
		"of local_human or fp_mode is true on that row is the cause.",
		"",
		"installed: " .. tostring(_installed),
		"recording: " .. tostring(_enabled),
		"rows: " .. #_rows .. " (cap " .. _max_rows .. ")",
		"",
	}

	if #_rows == 0 then
		lines[#lines + 1] = "No attacks recorded. Turn recording on with /pil_hits, then"
		lines[#lines + 1] = "let a bot shoot something, then run /pil_hits again to write this file."
	end

	for i = 1, #_rows do
		lines[#lines + 1] = string.format("%3d  %s", i, _rows[i])
	end

	return lines
end

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_hooks = deps.hooks
	_fileio = deps.fileio
	_debug_log = deps.debug_log or function() end
end

return M
