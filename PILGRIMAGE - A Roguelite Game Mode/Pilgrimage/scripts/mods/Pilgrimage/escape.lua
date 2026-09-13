-- escape.lua
--
-- Makes it possible to leave a Pilgrimage-launched mission.
--
-- ===========================================================================
-- THE BUG THIS FIXES
-- ===========================================================================
--
-- Launching a mission via boot_singleplayer_session leaves you with NO WAY OUT
-- through the escape menu. Both exits are hidden, for two different reasons, found in
-- scripts/ui/views/system_view/system_view_content_list.lua on 1.12.3:
--
--   "Leave Mission"       validation_function = validation_is_in_standard_mission
--
--       local function validation_is_in_mission()
--           local host_type = Managers.multiplayer_session:host_type()
--           if host_type == HOST_TYPES.mission_server then return true end
--           return false
--       end
--
--     We are `singleplay`, not `mission_server`, so this returns false.
--
--   "Exit to Main Menu"   only shown when game_mode_name is prologue, prologue_hub,
--     hub, training_grounds or shooting_range. We are in coop_complete_objective.
--
-- So the player is genuinely trapped. That is a serious enough defect that this
-- module exists purely to fix it, and it does so two ways: a command that always
-- works, and a patch that puts the real button back where it belongs.
--
-- The underlying call is the same one the vanilla button uses:
--
--     Managers.multiplayer_session:leave("leave_mission")
--
-- which just sets a reason and a delay; the manager's post-update does the work
-- (multiplayer_session_manager.lua:98).

local M = {}

local _mod
local _shared
local _hooks
local _event_log
local _debug_log
local _terminal

local CONTENT_LIST_PATH = "scripts/ui/views/system_view/system_view_content_list"
local SENTINEL = "__pilgrimage_escape_patched"

-- Menu entries are identified by their localisation key, which is stable across
-- patches in a way that array indices are not.
local LEAVE_MISSION_TEXT = "loc_leave_mission_display_name"

local _patched_entries = 0

-- ---------------------------------------------------------------------------
-- The always-works escape hatch
-- ---------------------------------------------------------------------------

function M.leave(reason)
	local session = Managers and Managers.multiplayer_session
	if not session or not session.leave then
		return false, "no multiplayer_session manager"
	end

	if _terminal and type(_terminal.arm_return_spawn) == "function" then
		pcall(_terminal.arm_return_spawn)
	end

	local ok, err = pcall(session.leave, session, reason or "leave_mission")
	if not ok then return false, tostring(err) end

	_event_log.emit({
		t = _shared.fixed_time(),
		event = "leave_session",
		id = _event_log.next_id(),
		reason = tostring(reason or "leave_mission"),
		game_mode = _shared.game_mode_name(),
	})

	_debug_log("leave", _shared.fixed_time(),
		"leaving session, reason " .. tostring(reason or "leave_mission"), 0, "info")

	return true
end

-- ---------------------------------------------------------------------------
-- Put the real button back
--
-- We do not replace the vanilla validation. We WRAP it, so the button still appears
-- everywhere it normally would, and additionally appears when we are hosting a solo
-- session. If Fatshark changes the vanilla rules, ours still layers on top.
-- ---------------------------------------------------------------------------

-- IMPORTANT: there are TWO entries with this text in the vanilla list.
--   system_view_content_list.lua:425  validation_is_in_standard_mission
--   system_view_content_list.lua:456  validation_is_in_havoc_mission
-- They are identical apart from their validation and their confirmation wording (the
-- havoc one warns about a leave penalty). v0.6.1 matched on text and patched BOTH,
-- which put two "Leave Mission" buttons in the menu.
--
-- Only the first is augmented now. They perform the same action, so which one wins
-- only affects the confirmation text, and the standard one comes first.
local function patch_entry_list(list)
	if type(list) ~= "table" then return 0 end

	local patched = 0
	local seen_leave_entry = false

	for i = 1, #list do
		local entry = list[i]
		if type(entry) == "table" and entry.text == LEAVE_MISSION_TEXT and not seen_leave_entry then
			seen_leave_entry = true
			local original = entry.validation_function
			local original_trigger = entry.trigger_function

			-- The button's confirmation callback calls multiplayer_session:leave
			-- directly, bypassing M.leave. Arm HumanPlayer's native wanted spawn
			-- before the popup appears, while the mission player still exists.
			-- If the player cancels, keeping it armed is harmless: every eventual
			-- exit from this Pilgrimage leg should return to the terminal anyway.
			if type(original_trigger) == "function" then
				entry.trigger_function = function(...)
					if _terminal and type(_terminal.arm_return_spawn) == "function" then
						pcall(_terminal.arm_return_spawn)
					end
					return original_trigger(...)
				end
			end

			entry.validation_function = function(...)
				-- Vanilla first. If it already says yes, change nothing, including
				-- whatever `disabled` state it wanted.
				if original then
					local ok, can_show, is_disabled = pcall(original, ...)
					if ok and can_show then return can_show, is_disabled end
				end

				-- Our addition: hosting a solo session inside an actual mission.
				local ok_solo, solo = pcall(_shared.is_solo_host)
				if not ok_solo or not solo then return false end

				local mode = _shared.game_mode_name()
				if not mode then return false end
				if _shared.is_in_hub() then return false end
				if _shared.is_in_psykhanium() then return false end

				return true, false
			end

			patched = patched + 1
		end
	end

	return patched
end

function M.install(content_list)
	if not content_list then return end
	if _hooks.claim(content_list, SENTINEL) then return end

	-- The module returns { StateMainMenu = <list>, default = <list> }. Patch every
	-- list rather than assuming which one is live.
	for _, list in pairs(content_list) do
		_patched_entries = _patched_entries + patch_entry_list(list)
	end

	_debug_log("escape_patch", 0,
		"patched " .. _patched_entries .. " leave-mission menu entries", 0, "info")
end

function M.patched_count()
	return _patched_entries
end

M.CONTENT_LIST_PATH = CONTENT_LIST_PATH

-- ---------------------------------------------------------------------------

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_hooks = deps.hooks
	_event_log = deps.event_log
	_terminal = deps.terminal
	_debug_log = deps.debug_log or function() end
end

return M
