-- Version 2.0.7
-- test version 1.0: 修复记录空玩家的bug [修复成功]

-- Author: Boffee

-- Match history record format (v1.0.5):
-- [timestamp];[result];[account id]:[character id]:[class]:[character name]:[early quit flag];mission_info:[map name]:[difficulty/havoc rank]:[mutator_1],[mutator_2],...:[session id]

-- Example:
-- 2025-07-20 13:54:27;left;
-- xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx:zealot:Boffe:1;
-- xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx:ogryn:player:2;
-- mission_info:loc_mission_name_lm_scavenge:difficulty_5:high_flash_mission_07:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

-- Meaning:
	-- Timestamp: 2025-07-20 13:54:27
	-- Result: left / won / lost
	-- Player Info:
		-- Player account ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
		-- Player character ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
		-- Class: zealot
		-- Name: Boffe
		-- Early Quit Flag:
			-- 0: Player completed the mission normally
			-- 1: Player left the mission early
			-- 2: Player was still in the mission when you quit early (result unknown)
	-- Mission Info:
		-- Map: loc_mission_name_lm_scavenge (ie: Excise Vault Spireside-13)
		-- Difficulty: difficulty_5 (difficulty_X or havoc_rank_X)
		-- Mutators: high_flash_mission_07 (or multiple, comma-separated)
		-- Session id: a unique identifier for each mission


local mod = get_mod("teammate_tracker")
local true_level = get_mod("true_level")
local _io = Mods.lua.io
local _os = Mods.lua.os

local history_path = _os.getenv("APPDATA") .. "/Fatshark/Darktide/teammate_tracker_history/teammate_tracker_history.txt"
local function ensure_dir()
    local dir = _os.getenv("APPDATA") .. "/Fatshark/Darktide/teammate_tracker_history/"
    _os.execute('mkdir "' .. dir .. '"')
end

------------------------------------------------------------
------------------------------------------------------------
--                          TOOLS
------------------------------------------------------------
------------------------------------------------------------

local function get_my_id()
	local player_manager = Managers.player
    local my_player = player_manager:local_player(1)
    return my_player and my_player:account_id()
end

local function havoc_rank_to_difficulty(rank)
	if rank >= 31 then return 5
	elseif rank >= 21 then return 4
	elseif rank >= 11 then return 3
	elseif rank >= 1 then return 2
	else return 1
	end
end

local function timestamp_to_unix_time(datetime_str)
	local Y, M, D, h, m, s = datetime_str:match("^(%d+)%-(%d+)%-(%d+) (%d+):(%d+):(%d+)$")
	if Y then
		return os.time({ year = Y, month = M, day = D, hour = h, min = m, sec = s})
	end
	return nil
end

----------------------------------------
-- histroy cached function
----------------------------------------
local function build_history_cache()
	mod.history_cache = {
		by_account = {},
		by_character = {}
	}
	mod.char_class_map = {}
	local difficulty_therehold = mod:get("difficulty_therehold") or 1
	local self_day_therehold = mod:get("self_day_therehold") or 0
	local others_day_therehold = mod:get("others_day_therehold") or 0
	local time_now = os.time()

	local file = _io.open(history_path, "r")
	if not file then return end

	for line in file:lines() do
		local sb_checked = false
		-- mod:echo("Reading line: " .. line)
		local parts = string.split(line, ";")
		
		-- v2.0.6 code: add diff filter
		local mission_part = parts[#parts]
		if type(mission_part) ~= "string" or not mission_part:find("^mission_info:") then
			goto continue_skip_line
		else
			-- local diff_str = mission_part:match(":(difficulty_%d+)")
			-- local havoc_str = mission_part:match(":(havoc_rank_%d+)")
			-- local diff = 0
			
			-- if diff_str then
				-- diff = tonumber(diff_str:match("(%d+)")) or 0
			-- elseif havoc_str then
				-- local havoc_rank = tonumber(havoc_str:match("(%d+)")) or 0
				-- diff = havoc_rank_to_difficulty(havoc_rank)
			-- end
			local diff = tonumber(mission_part:match("difficulty_(%d+)"))
				or havoc_rank_to_difficulty(tonumber(mission_part:match("havoc_rank_(%d+)")) or 0)
				or 1
		
			if diff < difficulty_therehold then goto continue_skip_line end
		end

		-- win/loss cached table
		local outcome = parts[2]
		for i = 3, #parts do
			if parts[i]:find("^mission_info:") then break end
			local part = parts[i]
			local acc_id, char_id, class, _, quit_flag = part:match("([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)")
			if not quit_flag then
				acc_id, char_id, class = part:match("([^:]+):([^:]+):([^:]+)")
				quit_flag = "0"
			end
			
			-- v2.0.6 code: add day filter
			local record_time = timestamp_to_unix_time(parts[1])
			if type(record_time) ~= "number" then record_time = 0 end
			local my_id = get_my_id()
			local is_self = (acc_id == my_id)
			local day_therehold = is_self and self_day_therehold or others_day_therehold

			if day_therehold > 0 and (time_now - record_time) > day_therehold * 86400 then
				goto continue_skip_player
			end
			
			-- win/loss cached table (continued)
			local final_char_id = char_id
			if acc_id and class then
				if char_id == "unknown_char_sb" then
					if not mod:get("enable_scoreboard_records") then
						sb_checked = true
					else
						local fake = acc_id .. ":" .. class
						final_char_id = fake
					end
				else
					local key = acc_id .. ":" .. class
					mod.char_class_map[key] = mod.char_class_map[key] or {}
					mod.char_class_map[key][char_id] = true
				end
			end

			local function update(data, key)
				data[key] = data[key] or { win = 0, loss = 0, quit = 0 }
				if quit_flag == "1" then
					data[key].quit = data[key].quit + 1
				elseif quit_flag == "0" then
					if outcome == "won" then data[key].win = data[key].win + 1
					elseif outcome == "lost" then data[key].loss = data[key].loss + 1
					end
				end
			end

			update(mod.history_cache.by_account, acc_id)
			update(mod.history_cache.by_character, final_char_id)
			::continue_skip_player::
		end
		::continue_skip_line::
	end

	file:close()
	
	for fake_id, real_char_ids in pairs(mod.char_class_map) do
		local fake_stats = mod.history_cache.by_character[fake_id]
		if fake_stats then
			for real_char_id, _ in pairs(real_char_ids) do
				local r = mod.history_cache.by_character[real_char_id] or { win = 0, loss = 0, quit = 0 }
				r.win = r.win + fake_stats.win
				r.loss = r.loss + fake_stats.loss
				r.quit = r.quit + fake_stats.quit
				mod.history_cache.by_character[real_char_id] = r
			end
			mod.history_cache.by_character[fake_id] = nil
		end
	end
end

----------------------------------------
-- mission and difficulty cached function
----------------------------------------
local function get_difficulty_and_circ()
	local mgr_diff = Managers.state.difficulty
	local mgr_circ = Managers.state.circumstance
    if (not mgr_diff) or (not mgr_circ) then
		mod:echo("difficulty or circumstance manager not available")
        return nil, nil, nil
    end
	
	-- difficulty
	-- v2.0.6 code: change to _initial, actual value is not present for actual difficulty, initial value is
    local challenge = mgr_diff._initial_challenge or 0
    local resistance = mgr_diff._initial_resistance or 0
	local havoc_data = mgr_diff._parsed_havoc_data
	
	local level
	if challenge == 5 then
		level = (resistance == 4) and 4 or 5
	else
		level = math.max(1, challenge - 1)
	end
	
	-- circumstance
	local is_havoc = type(havoc_data) == "table" and havoc_data.havoc_rank ~= nil
	local circ = mgr_circ._circumstance_name
	local havoc_circ = havoc_data and havoc_data.circumstances
	local havoc_circ_str = havoc_circ and table.concat(havoc_circ, ",") or ""
	
    if is_havoc then
        return true, havoc_data.havoc_rank, havoc_circ_str
    else
        return false, level, circ
    end
end

----------------------------------------
-- players' profile cached function
----------------------------------------
local seen_players = {}
local function collect_teammates()
    local player_manager = Managers.player
    for _, player in pairs(player_manager:human_players()) do
        local acc_id = player and player:account_id() or "unknown_acc"
        if acc_id and not seen_players[acc_id] then
            local char_id = player and player:character_id() or "unknown_char"
            local profile = player:profile()
            local class = profile and profile.archetype and profile.archetype.name or "unknown_class"
            local name = player:name()
            seen_players[acc_id] = {char_id = char_id, class = class, name = name}
        end
    end
	--test
	-- local summary = {}
    -- for acc_id, info in pairs(seen_players) do
        -- table.insert(summary, string.format("%s (%s) [%s]", info.name or "?", acc_id, info.class or "UNKNOWN"))
    -- end

    -- mod:echo(string.format("成功记录，目前共 %d 名参与过：\n%s",
        -- table.size(seen_players),
        -- table.concat(summary, "\n")
    -- ))
end

------------------------------------------------------------
------------------------------------------------------------
--                        VAR CACHED
------------------------------------------------------------
------------------------------------------------------------

----------------------------------------
-- history, mission info cached
----------------------------------------
local _last_mission_name = nil
local _last_difficulty = nil
local _last_circumstance = nil
local _last_session_id = nil
local cached_mission_name = "unknown_map"
local cached_difficulty_str = "unknown_difficulty"
local cached_circumstance = "unknown_circumstance"
local cached_session_id = "unknown_session_id"

mod.history_cache = {
	by_account = {},
	by_character = {}
}
mod.char_class_map = {}

mod.on_all_mods_loaded = function()
	-- v2.0.6 code: serious mistake fixed, tag_1
	-- build_history_cache()
	-- mod:echo("first history cached")
	
	if Managers.event then
        mod:hook_safe(Managers.event, "trigger", function(_, event_name, ...)
			local party = Managers.party_immaterium
			local mission = Managers.state.mission and Managers.state.mission:mission()
			
			-- v2.0.4 code: remove, tag_1
			-- local mode = mission and mission.game_mode_name
			-- if mode ~= "coop_complete_objective" and mode ~= "survival" then
				-- return
			-- end
			
			local current_name = mission and mission.mission_name
			-- allow mission to be nil, but protect current_name since it's used below
			if not current_name then return end
			
			-- difficulty and circumstance components
			local mission_changed = false
			
			if Managers.state.difficulty and Managers.state.circumstance then
				local is_havoc, current_difficulty, current_circumstance = get_difficulty_and_circ()
				-- mission changed
				if current_name ~= _last_mission_name 
					or current_difficulty ~= _last_difficulty 
					or current_circumstance ~= _last_circumstance
				then
					mission_changed = true
					-- map name
					_last_mission_name = current_name
					cached_mission_name = current_name
					-- difficulty
					_last_difficulty = current_difficulty
					cached_difficulty_str = is_havoc
						and string.format("havoc_rank_%s", tostring(current_difficulty))
						or string.format("difficulty_%s", tostring(current_difficulty))
					-- circumstance
					_last_circumstance = current_circumstance
					cached_circumstance = string.format("%s", tostring(current_circumstance))
					-- mod:echo(string.format("检测到mission变更，已缓存: %s,%s,%s", cached_mission_name, cached_difficulty_str, cached_circumstance))
					-- v2.0.4_2 code: 移到下面，不然session id必然导致双重缓存，tag_1
					-- build_history_cache() 
					-- mod:echo("history cached")
				end
			end
			
			-- session id check first
			local current_session_id = party and party:current_game_session_id()
			if current_session_id then
				if current_session_id ~= _last_session_id then
					build_history_cache()
					-- mod:echo("Previous: " .. tostring(_last_session_id))
					-- mod:echo("Current:  " .. tostring(current_session_id))
					_last_session_id = current_session_id
					cached_session_id = current_session_id
					-- mod:echo(string.format("检测到session id变更，已缓存: %s", cached_session_id))
					seen_players = {}
				end
			else
				if mission_changed then
					-- mod:echo(string.format("无法检测session id，使用mission info识别，检测到mission变更"))
					-- v2.0.4_2 code: tag_1
					build_history_cache()
					seen_players = {}
				end
			end
			
			-- v2.0.4 code: move to here, tag_1
			local mode = mission and mission.game_mode_name
			if mode ~= "coop_complete_objective" and mode ~= "survival" then
				return
			end
			
			if event_name == "assign_player_unit_ownership" or event_name == "event_player_set_profile" then
				collect_teammates()
				
				mod.cached_active_players_acc = {}
				for _, player in pairs(Managers.player:human_players()) do
					local acc_id = player and player:account_id()
					if acc_id then
						mod.cached_active_players_acc[acc_id] = true
					end
				end
			end
		end)
    else
        mod:echo("Managers.event is nil, hook skipped.")
    end
end

-- v2.0.6 code: serious mistake fixed, tag_1
mod:hook_safe(CLASS.MainMenuView, "on_enter", function(self)
	-- mod:echo("MainMenuView:on_enter → refreshing teammate history cache")
	build_history_cache()
end)

------------------------------------------------------------
------------------------------------------------------------
--                     HISTORY RECORD
------------------------------------------------------------
------------------------------------------------------------

----------------------------------------
-- record game function
----------------------------------------
local function record_game(outcome)
    local player_manager = Managers.player
	local my_player = player_manager:local_player(1)
	local my_id = get_my_id()
	-- v2.0.6 code: protect from rare case
    local timestamp = os.date("%Y-%m-%d %H:%M:%S") or "unknown_time"
    ensure_dir()
	-- v2.0.4 note: try to fix bug
	-- delete latest record if same mission
	local file_r = _io.open(history_path, "r")
	
	if file_r then
		local all_lines = {}
		for line in file_r:lines() do
			table.insert(all_lines, line)
		end
		file_r:close()
		
		local id_check_count = 0
		local max_id_check = 5
		
		for i = #all_lines, 1, -1 do
			local last_record_session_id = all_lines[i]:match("mission_info:[^:]*:[^:]*:[^:]*:([%w%-]+)")
			if last_record_session_id then
				if last_record_session_id == cached_session_id then
					table.remove(all_lines, i)
					-- delete early record since same mission
					local file_w = _io.open(history_path, "w")
					for _, line in ipairs(all_lines) do
						file_w:write(line .. "\n")
					end
					file_w:close()
					-- mod:echo("last record deleted since same session id:" .. tostring(cached_session_id))
					break
				elseif id_check_count < max_id_check then
					id_check_count = id_check_count + 1
				else 
					break
				end
			end
		end
	end
	
	-- game recording process
    local file_a = _io.open(history_path, "a")
    local entries = {}
    local active = {}
	
	if outcome == "left" and mod.cached_active_players_acc then
		active = mod.cached_active_players_acc
	else
		for _, player in pairs(player_manager:human_players()) do
			local acc_id = player and player:account_id()
			if acc_id then
				active[acc_id] = true
			end
		end
	end

    for acc_id, info in pairs(seen_players or {}) do
        local char_id = info.char_id or "unknown_char"
        local class = info.class or "unknown_class"
        local name = info.name or "unknown_name"
		local quit_flag
		if outcome == "left" then
			if acc_id == my_id then quit_flag = "1"
			else quit_flag = active[acc_id] and "2" or "1"
			end
        else
			quit_flag = active[acc_id] and "0" or "1"
		end

        table.insert(entries, string.format("%s:%s:%s:%s:%s", acc_id, char_id, class, name, quit_flag))
    end
	local mission_info_str = string.format("mission_info:%s:%s:%s:%s", cached_mission_name, cached_difficulty_str, cached_circumstance, cached_session_id)
	
    if file_a then
        file_a:write(string.format(
            "%s;%s;%s;%s \n",
            timestamp,
            outcome,
            table.concat(entries, ";"),
			mission_info_str
        ))
        file_a:close()
        -- mod:echo("Record saved.")
	-- v2.0.4 note: a rare edge case, consider remove them next patch
    else
        mod:echo("Failed to open file.")
    end
	-- v2.0.4 note: search and see "session id check first"
    -- seen_players = {}
end
	
----------------------------------------
-- end game hook
----------------------------------------
latest_outcome = nil

if CLASS.GameModeManager then
	mod:hook(CLASS.GameModeManager, "_set_end_conditions_met", function(func_hook, self, outcome, ...)
		func_hook(self, outcome, ...)
		latest_outcome = outcome
		-- mod:echo("Game ended: " .. outcome)
	end)
else
	mod:echo("CLASS.GameModeManager is nil, hook skipped.")
end

if CLASS.EndView then
	mod:hook_safe(CLASS.EndView, "on_enter", function(self)
		if latest_outcome then
			record_game(latest_outcome)
		end
		build_history_cache()
		cached_session_id = "unknown_session_id"
		cached_mission_name = "unknown_map"
		cached_difficulty_str = "unknown_difficulty"
		cached_circumstance = "unknown_circumstance"
	end)
else
	mod:echo("CLASS.EndView is nil, hook skipped.")
end

if Managers.party_immaterium then
	mod:hook_safe(Managers.party_immaterium, "leave_party", function(...)
		local mission = Managers.state.mission and Managers.state.mission:mission()
		-- v2.0.4 code: disable, should fix some bug
		-- local mode = mission and mission.game_mode_name
		-- if mode ~= "coop_complete_objective" and mode ~= "survival" then
			-- return
		-- end
		
		-- v2.0.6 code: 哀星号离开小队会记录战绩，main menu也会触发left，暂时不知道原因，但不会有玩家。（暂时修不好）
		-- v2.0.7 code: 再次尝试修复，加echo [修复成功]
		if not mod.cached_active_players_acc then
			-- mod:echo("cached_active_players_acc is empty, skipping record.")
			return
		end

		record_game("left")
		build_history_cache()
		-- mod:echo("你点击了提前退出按钮")
	end)
else
	mod:echo("Managers.party_immaterium is nil, hook skipped.")
end

------------------------------------------------------------
------------------------------------------------------------
--                       DISPLAY STYLE
------------------------------------------------------------
------------------------------------------------------------

-- v2.0.6 code: 尝试加颜色选项，效果很差
-- local get_color_tag = function(color_name)
	-- local c = Color[color_name](255, true)
	-- return string.format("{#color(%d,%d,%d)}", c[2], c[3], c[4])
-- end

-- local color_str = get_color_tag("green")

local function results_text_full(wins, losses, quits)
	-- {#size(32)} local player default
	local w = "{#color(0,255,0)}+" .. wins .. "{#reset()}"
    local l = "{#color(255,0,0)}-" .. losses .. "{#reset()}"
    local q = "{#color(255,165,0)}!" .. quits .. "{#reset()}"
	
	if quits > 0 then
		return w .. " " .. l .. " " .. q
	elseif wins ~= 0 or losses ~= 0 then
		return w .. " " .. l
	else
		return nil
	end
end

local function results_text_win_only(wins)
	local w = "{#color(0,255,0)}" .. wins .. "{#reset()}"
	if wins ~= 0 then return w 
	else return nil
	end
end

local function results_ratio_include_left(wins, losses, quits)
	local total = losses + quits
	if total == 0 then total = 1 end
	local ratio = wins / total
	local color
	if ratio < 1 then
		color = "{#color(255,0,0)}"
	elseif ratio < 1.5 then
		color = "{#color(255,165,0)}"
	else
		color = "{#color(0,255,0)}"
	end
	return string.format("%s%.2f%s", color, ratio, "{#reset()}")
end

local function results_ratio_exclude_left(wins, losses, quits)
	if losses == 0 then losses = 1 end
	local ratio = wins / losses
	local color
	if ratio < 1 then
		color = "{#color(255,0,0)}"
	elseif ratio < 1.5 then
		color = "{#color(255,165,0)}"
	else
		color = "{#color(0,255,0)}"
	end
	local q = "{#color(255,165,0)}!" .. quits .. "{#reset()}"
	return string.format("%s%.2f%s %s", color, ratio, "{#reset()}", q)
end

local function results_percentage_include_left(wins, losses, quits)
	local total = wins + losses + quits
	-- if total == 0 then return nil end
	local rate = (wins / total) * 100
	local color
	-- version 2.0.4_2 code: typo, rate < 40 (50 before)
	if rate < 40 then
		color = "{#color(255,0,0)}"
	elseif rate < 60 then
		color = "{#color(255,165,0)}"
	else
		color = "{#color(0,255,0)}"
	end
	return string.format("%s%.1f%%%s", color, rate, "{#reset()}")
end

local function results_percentage_exclude_left(wins, losses, quits)
	local total = wins + losses
	-- if total == 0 then return nil end
	local rate = (wins / total) * 100
	local color
	if rate < 40 then
		color = "{#color(255,0,0)}"
	elseif rate < 60 then
		color = "{#color(255,165,0)}"
	else
		color = "{#color(0,255,0)}"
	end
	local q = "{#color(255,165,0)}!" .. quits .. "{#reset()}"
	return string.format("%s%.1f%%%s %s", color, rate, "{#reset()}", q)
end

------------------------------------------------------------
------------------------------------------------------------
--                   HISTORY to DISPLAY
------------------------------------------------------------
------------------------------------------------------------

-- win loss function
local function get_win_loss(id, split)
	if not mod.history_cache then return 0, 0, 0 end
	if split then
		local data = mod.history_cache.by_character[id]
		if not data and mod.char_class_map[id] then
			-- fallback
			data = mod.history_cache.by_character[mod.char_class_map[id]]
		end
		if not data then return 0, 0, 0 end
		return data.win, data.loss, data.quit
	else
		local data = mod.history_cache.by_account[id]
		if not data then return 0, 0, 0 end
		return data.win, data.loss, data.quit
	end
end

-- replace_level from true level
if true_level then
	mod:hook(true_level, "cache_true_levels", function(func, self_or_others, char_id, base_data, havoc_rank, acc_id)
		func(self_or_others, char_id, base_data, havoc_rank, acc_id)
		local true_levels = self_or_others[char_id]
		if true_levels then
			true_levels.character_id = char_id
			-- mod:echo(string.format("账号: %s 已附加角色ID: %s", acc_id, char_id))
		else
			-- mod:echo("true_levels not found")
		end
	end)


	mod:hook(true_level, "replace_level", function(func, text, true_levels, reference, ...)
		local result = func(text, true_levels, reference, ...)
		
		if reference and not mod:get("tt_display_" .. reference) then
			return result
		end
		
		local account_id = true_levels and true_levels.account_id
		local character_id = true_levels and true_levels.character_id
		
		local my_id = get_my_id()
		local is_self = (account_id == my_id)

		local wins, losses, quits
		
		if is_self then
			if mod:get("show_self") then
				if mod:get("split_self_by_class") and character_id then
					wins, losses, quits = get_win_loss(character_id, true)
				elseif account_id then
					wins, losses, quits = get_win_loss(account_id, false)
				end
			else
				return result
			end
		else
			if mod:get("show_others") then
				if mod:get("split_others_by_class") and character_id then
					wins, losses, quits = get_win_loss(character_id, true)
				elseif account_id then
					wins, losses, quits = get_win_loss(account_id, false)
				end
			else
				return result
			end
		end
		-- final display 
		local stats_text
		-- v2.0.4 note: remove next patch
		-- if is_self and not mod:get("show_self_loss_left") then
			-- stats_text = results_text_win(wins)
		-- elseif not is_self and not mod:get("show_others_loss_left") then 
			-- stats_text = results_text_win(wins)
		-- else
			-- stats_text = results_text(wins, losses, quits)
		-- end
		
		if wins == 0 and losses == 0 and quits == 0 then
			if mod:get("show_no_record") then
				stats_text = is_self and "{#color(255,200,0)}None{#reset()}" or "{#color(255,200,0)}new!{#reset()}"
			else 
				return result
			end
		else
			local display_style = mod:get("display_style")

			if display_style == "text_full" then
				stats_text = results_text_full(wins, losses, quits)
			elseif display_style == "text_win_only" then
				stats_text = results_text_win_only(wins)
			elseif display_style == "ratio_include_left" then
				stats_text = results_ratio_include_left(wins, losses, quits)
			elseif display_style == "ratio_exclude_left" then
				stats_text = results_ratio_exclude_left(wins, losses, quits)
			elseif display_style == "percentage_include_left" then
				stats_text = results_percentage_include_left(wins, losses, quits)	
			elseif display_style == "percentage_exclude_left" then
				stats_text = results_percentage_exclude_left(wins, losses, quits)
			end
		end
		
		if stats_text then
			if result:find("\n") then
				return result:gsub("^(.-)\n", "%1 " .. stats_text .. "\n")
			else
				return result .. " " .. stats_text
			end
		else
			return result
		end
	end)
else
	mod:echo("Warning: 'true_level' not found. Skipping related hooks.")
end

------------------------------------------------------------
------------------------------------------------------------
--                 SCOREBOARD HISTORY RECORD
------------------------------------------------------------
------------------------------------------------------------
local icon_to_archetype = {
	[""] = "ogryn",
	[""] = "psyker",
	[""] = "veteran",
	[""] = "zealot",
	[""] = "adamant", -- 共用
	-- [""] = "ogryn (simple)",
	-- [""] = "psyker (simple)",
	-- [""] = "veteran (simple)",
	-- [""] = "zealot (simple)",
}

mod:command("tt_scoreboard", "Extract scoreboard history", function()
	local dir_scoreboard = _os.getenv("APPDATA") .. "/Fatshark/Darktide/scoreboard_history/"
	local dir_scoreboard_cmd = 'dir "' .. dir_scoreboard .. '" /b'
	local file_list = _io.popen(dir_scoreboard_cmd)
	-- v2.0.2: debug
	if not file_list then
		mod:echo("Failed to list files in scoreboard_history: " .. dir_scoreboard)
		return
	end
	ensure_dir()
	local history_scoreboard = {}
	local file_tt_r = _io.open(history_path, "r")
	
	local earlist_unix_time = nil
	if file_tt_r then
		for tt_lines in file_tt_r:lines() do
			-- v2.0.2: debug
			if type(tt_lines) ~= "string" or tt_lines:match("^%s*$") then
				mod:echo("Invalid tt_lines in tt history file")
				-- return
			else
				local timestamp = string.split(tt_lines, ";")[1]
				local unix_time = timestamp_to_unix_time(timestamp)
				if unix_time and (not earlist_unix_time or unix_time < earlist_unix_time) then
					earlist_unix_time = unix_time
				end
			end
		end
		file_tt_r:close()
	else
		-- mod:echo("file_tt_r not found")
	end
	-- mod:echo(earlist_unix_time)

	for file_name in file_list:lines() do
		if file_name:match("^%d+%.lua$") then
			local history_path_scoreboard = dir_scoreboard .. file_name
			local file_scoreboard = _io.open(history_path_scoreboard, "r")
			-- v2.0.3 code: debug
			-- v2.0.3 note: a rare edge case, consider remove them next patch
			if not file_scoreboard then 
				mod:echo("file_scoreboard not found") 
				-- return
				goto continue_skip_file
			end
			
			local unix_time = tonumber(file_name:match("^(%d+)%."))
			local timestamp
			-- v2.0.3 note: a rare edge case, consider remove them next patch
			if unix_time == nil then 
				timestamp = "unknown_time_sb"
			else 
				timestamp = os.date("%Y-%m-%d %H:%M:%S", unix_time) 
			end
			
			-- v2.0.3 note: a rare edge case, consider remove them next patch
			if not unix_time then 
				mod:echo("unix_time not found for file: " .. tostring(file_name))
				goto continue_skip_file
			elseif not earlist_unix_time or unix_time < earlist_unix_time then
				local file_line = {}
				for i = 1, 6 do
					file_line[i] = file_scoreboard:read("*l")
				end
				file_scoreboard:close()
				-- v2.0.2: debug
				for i = 1, 6 do
					if type(file_line[i]) ~= "string" then
						mod:echo("Invalid file_line[" .. i .. "] in file: " .. tostring(file_name))
						goto continue_skip_file
					end
				end
				local parts = string.split(file_line[1], ";")
				local outcome = (parts[5] == "won" or parts[5] == "lost") and parts[5] or "unknown_outcome_sb"
				local mission_name = parts[2] and ("loc_mission_name_" .. parts[2]) or "unknown_map_sb"
				local difficulty_str = parts[3] and ("difficulty_" .. parts[3]) or "unknown_difficulty_sb"
				local circumstance = parts[4] or "unknown_circ_sb"

				local entries = {}
				local num_players = tonumber(string.split(file_line[2], ";")[2]) or 0
				for i = 3, 2 + num_players do
					local parts_player = string.split(file_line[i], ";")
					local acc_id = parts_player[2] or "unknown_acc_sb"
					local char_id = "unknown_char_sb"
					local class = icon_to_archetype[parts_player[4]] or "unknown_class_sb"
					local name = parts_player[3] or "unknown_name_sb"
					local quit_flag = 0
					table.insert(entries, string.format("%s:%s:%s:%s:%s", acc_id, char_id, class, name, quit_flag))
				end
				
				local mission_info_str = string.format("mission_info:%s:%s:%s", mission_name, difficulty_str, circumstance)
				table.insert(history_scoreboard, string.format("%s;%s;%s;%s \n", timestamp, outcome, table.concat(entries, ";"), mission_info_str))
			else
			end
		else mod:echo("Invalid filename format: " .. tostring(file_name))
		end
		::continue_skip_file::
	end
	
	if #history_scoreboard > 0 then
		local file_tt = _io.open(history_path, "a")
		file_tt:write("-- From here: scoreboard imported records \n")
		for _, line in ipairs(history_scoreboard) do
			file_tt:write(line)
		end
		file_tt:write("-- Until here: scoreboard imported records \n")
		file_tt:close()
		mod:echo(string.format(mod:localize("scoreboard_written"), #history_scoreboard))
	else
		mod:echo(mod:localize("scoreboard_none"))
		mod:echo(mod:localize("scoreboard_possible_reason"))
		mod:echo(mod:localize("scoreboard_reason_imported"))
		mod:echo(mod:localize("scoreboard_reason_early"))
	end
	
	build_history_cache()
end)



---------------------------------------------------------------------------------------------

--[[mod:command("tt_echo_txt", "Echo history txt", function()
    local file = _io.open(history_path, "r")
    if not file then
        mod:echo("History file not found.")
        return
    end
    mod:echo("File content:")
    for line in file:lines() do
        mod:echo("Line: " .. line)
    end
    file:close()
end)]]

mod:command("tt_echo_ids", "Echo teammate IDs, career, and character ID", function()
    local player_manager = Managers.player
    if not player_manager then
        mod:echo("Managers.player not available.")
        return
    end

    local my_player = player_manager:local_player(1)
    local my_id = my_player and my_player:account_id()
    local my_char_id = my_player and my_player:character_id() or "unknown_char"
    local my_profile = my_player and my_player:profile()
    local my_class = my_profile and my_profile.archetype and my_profile.archetype.name or "unknown_class"
    
    mod:echo(string.format("My ID: %s | Character ID: %s | Class: %s", tostring(my_id), tostring(my_char_id), tostring(my_class)))

    local count = 0
    for _, player in pairs(player_manager:human_players()) do
        local id = player:profile() and player:profile().user_id or player:account_id()
        local char_id = player:character_id() or "unknown_char"
        local name = player:name()
        local profile = player:profile()
        local class = profile and profile.archetype and profile.archetype.name or "unknown_class"

        if id and id ~= my_id then
            mod:echo(string.format("Teammate: %s (%s) | Character ID: %s | Class: %s", name, id, char_id, class))
            count = count + 1
        end
    end

    if count == 0 then
        mod:echo("No teammates found.")
    end
end)

--[[local function dump_table(tbl, indent)
    indent = indent or ""
    for k, v in pairs(tbl) do
        local v_type = type(v)
        if v_type == "table" then
            mod:echo(string.format("%s[%s] = {", indent, tostring(k)))
            dump_table(v, indent .. "  ")
            mod:echo(indent .. "}")
        else
            mod:echo(string.format("%s[%s] = %s", indent, tostring(k), tostring(v)))
        end
    end
end
mod:command("tt_echo_difficulty_mgr", "Echo contents of Managers.state.difficulty", function()
    local mgr = Managers.state.difficulty
    for k, v in pairs(mgr) do
        if k == "_parsed_havoc_data" and type(v) == "table" then
            mod:echo("_parsed_havoc_data = {")
            dump_table(v, "  ")
            mod:echo("}")
        else
            local v_str = type(v) == "function" and "function()" or tostring(v)
            mod:echo(string.format(" %s = %s", tostring(k), v_str))
        end
    end
end)]]


mod:command("tt_echo_difficulty_mgr", "Echo contents of Managers.state.difficulty", function()
    local mgr = Managers.state.difficulty
    for k, v in pairs(mgr) do
		if k == "_parsed_havoc_data" then
			local havoc_rank = v.havoc_rank
			mod:echo(string.format("havoc_rank = %s", tostring(havoc_rank)))
        else
			local v_str = type(v) == "function" and "function()" or tostring(v)
			mod:echo(string.format(" - %s = %s", tostring(k), v_str))
		end
    end
end)

mod:command("tt_echo_difficulty", "Echo parsed difficulty string", function()
    local is_havoc, diff = get_difficulty_and_circ()
    if is_havoc then
        mod:echo(string.format("HAVOC RANK: %s", tostring(diff)))
    else
		mod:echo(string.format("DIFFICULTY: %s", tostring(diff)))
    end
end)

--[[mod:command("tt_circumstance", "显示当前 circumstance 管理器的全部字段", function()
    local mgr = Managers.state.circumstance
    if not mgr then
        mod:echo("circumstance 管理器未生成")
        return
    end

    mod:echo("circumstance 字段如下：")
    for k, v in pairs(mgr) do
        mod:echo(tostring(k) .. " = " .. tostring(v))
    end
end)]]

--[[mod:command("tt_circumstance_havoc_include", "判断当前是否为 Havoc 模式并打印 circumstances", function()
    local difficulty_mgr = Managers.state.difficulty
    local circumstance_mgr = Managers.state.circumstance

    local havoc_data = difficulty_mgr and difficulty_mgr._parsed_havoc_data

    if havoc_data and havoc_data.circumstances then
        mod:echo("havoc circumstance: ")
        for i, v in ipairs(havoc_data.circumstances) do
            mod:echo(string.format("  [%d] = %s", i, tostring(v)))
        end
    elseif circumstance_mgr and circumstance_mgr._circumstance_name then
        mod:echo("circumstance = " .. tostring(Localize(circumstance_mgr._circumstance_name)))
    else
        mod:echo("未找到 circumstance 或 havoc 数据。")
    end
end)]]

--[[mod:command("tt_to_unix", "Convert a timestamp string to unix time", function(...)
	local datetime_str = table.concat({...}, " ")
	local unix_time = timestamp_to_unix_time(datetime_str)
	if unix_time then
		mod:echo(string.format("Unix time for [%s] = %d", datetime_str, unix_time))
	else
		mod:echo("Invalid format. Expected format: YYYY-MM-DD HH:MM:SS")
	end
end)]]

mod:command("tt_session_id", "Print current mission session ID", function()
	local party = Managers.party_immaterium
	if not party then
		mod:echo("party_immaterium manager not available.")
		return
	end

	local session_id = party:current_game_session_id()
	if session_id then
		mod:echo("Current session ID: " .. tostring(session_id))
	else
		mod:echo("No active session ID found (likely not in mission).")
	end

	-- mmt id
	--[[local mechanism_data = Managers.mechanism
		and Managers.mechanism._mechanism
		and Managers.mechanism._mechanism._mechanism_data
	if mechanism_data and mechanism_data.backend_mission_id then
		mod:echo("Backend Mission ID: " .. mechanism_data.backend_mission_id)
	else
		mod:echo("Backend Mission ID: not found (may not be in mission state).")
	end]]
	-- list all mechanism_data
	--[[if not mechanism_data then
		mod:echo("mechanism_data not found (likely not in mission).")
		return
	end
	mod:echo("=== mechanism_data fields ===")
	for k, v in pairs(mechanism_data) do
		local value_str
		if type(v) == "table" then
			value_str = "table"
		elseif type(v) == "boolean" then
			value_str = v and "true" or "false"
		else
			value_str = tostring(v)
		end
		mod:echo(k .. " = " .. value_str)
	end]]
end)

mod:command("tt_refresh_histroy_cache", "Rebuild history cache", function()
	build_history_cache()
	
	local n_acc = 0
	local n_char = 0
	local n_fallback = 0
	
	for _ in pairs(mod.history_cache.by_account) do
		n_acc = n_acc + 1
	end
	
	for k in pairs(mod.history_cache.by_character) do
		n_char = n_char + 1
		if k:match("^[%w%-]+:") then
			n_fallback = n_fallback + 1
		end
	end
	
	mod:echo(string.format("Cache rebuilt. Accounts: %d, Characters: %d (Fallback: %d)", n_acc, n_char, n_fallback))
end)

--[[mod:command("tt_show_accounts", "List all account IDs in the cache", function()
	if not mod.history_cache or not mod.history_cache.by_account then
		mod:echo("Cache not built yet.")
		return
	end

	local count = 0
	for acc_id, stat in pairs(mod.history_cache.by_account) do
		mod:echo(string.format("[%s] +%d -%d !%d", acc_id, stat.win, stat.loss, stat.quit))
		count = count + 1
	end

	mod:echo(string.format("Total %d account IDs found.", count))
end)

mod:command("tt_show_characters", "List all character IDs in the cache", function()
	if not mod.history_cache or not mod.history_cache.by_character then
		mod:echo("Cache not built yet.")
		return
	end

	local count = 0
	for char_id, stat in pairs(mod.history_cache.by_character) do
		local tag = ""
		if char_id:match("^[%w%-]+:") then
			tag = " (fallback)"
		end
		mod:echo(string.format("[%s]%s +%d -%d !%d", char_id, tag, stat.win, stat.loss, stat.quit))
		count = count + 1
	end

	mod:echo(string.format("Total %d character IDs found.", count))
end)]]

local map_list = {
	"loc_mission_name_cm_archives",
	"loc_mission_name_cm_habs",
	"loc_mission_name_cm_raid",
	"loc_mission_name_core_research",
	"loc_mission_name_dm_forge",
	"loc_mission_name_dm_propaganda",
	"loc_mission_name_dm_rise",
	"loc_mission_name_dm_stockpile",
	"loc_mission_name_fm_armoury",
	"loc_mission_name_fm_cargo",
	"loc_mission_name_fm_resurgence",
	"loc_mission_name_hm_cartel",
	"loc_mission_name_hm_complex",
	"loc_mission_name_hm_strain",
	"loc_mission_name_hub_ship",
	"loc_mission_name_km_enforcer",
	"loc_mission_name_km_enforcer_twins",
	"loc_mission_name_km_heresy",
	"loc_mission_name_km_station",
	"loc_mission_name_lm_cooling",
	"loc_mission_name_lm_rails",
	"loc_mission_name_lm_scavenge",
	"loc_mission_name_op_train",
	"loc_mission_name_prologue",
	"loc_mission_name_tg_basic_combat_01",
}

mod:command("tt_echo_map_winrate", "Echo win/loss/left for each map", function()
	local my_id = get_my_id()
	if not my_id then
		mod:echo("Cannot find your account ID.")
		return
	end

	local file = _io.open(history_path, "r")
	if not file then
		mod:echo("History file not found.")
		return
	end

	local map_stats = {}
	for _, name in ipairs(map_list) do
		map_stats[name] = { win = 0, loss = 0, left = 0 }
	end

	for line in file:lines() do
		if line:find("^%d") and line:find("mission_info:") then
			local parts = string.split(line, ";")
			local outcome = parts[2]

			for i = 3, #parts do
				local acc = parts[i]:match("^([^:]+):")
				if acc == my_id then
					local map = parts[#parts]:match("mission_info:([^:]+):")
					if map and map_stats[map] then
						if outcome == "won" then
							map_stats[map].win = map_stats[map].win + 1
						elseif outcome == "lost" then
							map_stats[map].loss = map_stats[map].loss + 1
						elseif outcome == "left" then
							map_stats[map].left = map_stats[map].left + 1
						end
					end
					break
				end
			end
		end
	end
	file:close()

	for map, stat in pairs(map_stats) do
		local total = stat.win + stat.loss + stat.left
		if total == 0 then
			mod:echo(string.format("[%s] no records", Localize(map)))
		else
			local rate = (stat.win / total) * 100
			mod:echo(string.format("[%s] Win Rate: %.1f%%%% | Breakdown: %d Wins, %d Losses, %d Leaves",
				Localize(map), rate, stat.win, stat.loss, stat.left))
		end
	end
end)
