local mod = get_mod("improve-yourself")

mod.version = "1.1.2"
mod.damage_source_tracker = mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/integrations/damage_source_tracker")
mod.collector_manager = mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/integrations/collector_manager")
mod.visual_constants = mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/views/shared/improve_yourself_visual_constants")

-- Custom board definitions are also loaded inside Scores-owned views. Never
-- let a temporarily unavailable DMF localization lookup place nil into a text
-- pass: Gui2.slug_text requires an actual string. Reuse the same localization
-- source as a direct language-aware fallback, then fall back to English and
-- finally to the key itself. This affects only Improve Yourself text helpers;
-- it does not replace or hook Darktide's global localization manager.
local iy_localization_entries = mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/improve_yourself_localization") or {}

function mod:safe_localize(key, ...)
    local ok, localized = pcall(self.localize, self, key, ...)
    if ok and type(localized) == "string" then
        return localized
    end

    local language = "en"
    if Application and type(Application.user_setting) == "function" then
        local language_ok, language_id = pcall(Application.user_setting, "language_id")
        if language_ok and type(language_id) == "string" then
            language = language_id
        end
    end

    local entry = iy_localization_entries[key]
    local fallback = type(entry) == "table" and (entry[language] or entry.en) or nil
    if type(fallback) ~= "string" then
        return tostring(key or "")
    end

    local format_ok, formatted = pcall(string.format, fallback, ...)
    return format_ok and formatted or fallback
end

-- Damage-source rows deliberately persist compact English identifiers so
-- History data remains portable when the game language changes. Translate
-- only at display time, including entries saved by earlier releases.
local damage_source_localization = {
    ["Falling"] = "iy_source_falling",
    ["Corruption"] = "iy_source_corruption",
    ["Warp"] = "iy_source_warp",
    ["Overheat"] = "iy_source_overheat",
    ["Netted"] = "iy_source_netted",
    ["Untracked"] = "iy_source_untracked",
    ["Self Damage"] = "iy_source_self_damage",
    ["Armored Hound"] = "iy_source_armored_hound",
    ["Beast of Nurgle"] = "iy_source_beast_of_nurgle",
    ["Hound"] = "iy_source_hound",
    ["Mutated Poxwalker"] = "iy_source_mutated_poxwalker",
    ["Groaner"] = "iy_source_groaner",
    ["Bulwark"] = "iy_source_bulwark",
    ["Crusher"] = "iy_source_crusher",
    ["Reaper"] = "iy_source_reaper",
    ["Houndmaster"] = "iy_source_houndmaster",
    ["Plague Ogryn"] = "iy_source_plague_ogryn",
    ["Poxwalker"] = "iy_source_poxwalker",
    ["Poxburster"] = "iy_source_poxburster",
    ["Chaos Spawn"] = "iy_source_chaos_spawn",
    ["Shotgunner"] = "iy_source_shotgunner",
    ["Rager"] = "iy_source_rager",
    ["Captain"] = "iy_source_captain",
    ["Flamer"] = "iy_source_flamer",
    ["Bomber"] = "iy_source_bomber",
    ["Gunner"] = "iy_source_gunner",
    ["Bruiser"] = "iy_source_bruiser",
    ["Mutant"] = "iy_source_mutant",
    ["Mauler"] = "iy_source_mauler",
    ["Shooter"] = "iy_source_shooter",
    ["Sniper"] = "iy_source_sniper",
    ["Pox Gas"] = "iy_source_pox_gas",
    ["Barrel Fire"] = "iy_source_barrel_fire",
    ["Barrel Explosion"] = "iy_source_barrel_explosion",
    ["Flamer Fire"] = "iy_source_flamer_fire",
    ["Beast Slime"] = "iy_source_beast_slime",
    ["Ground Slam"] = "iy_source_ground_slam",
    ["Explosion"] = "iy_source_explosion",
    ["Area Effect"] = "iy_source_area_effect",
    ["Ranged Attack"] = "iy_source_ranged_attack",
    ["Melee Attack"] = "iy_source_melee_attack",
    ["Other"] = "iy_source_other",
}

function mod:localize_damage_source_text(value)
    local translated = {}
    for part in string.gmatch(tostring(value or ""), "[^,]+") do
        local label = part:gsub("^%s+", ""):gsub("%s+$", "")
        local key = damage_source_localization[label]
        translated[#translated + 1] = key and self:safe_localize(key) or label
    end
    return table.concat(translated, ", ")
end

function mod:utf8_character_count(value)
    local text = tostring(value or "")
    local count = 0
    local byte_index = 1
    while byte_index <= #text do
        local lead = string.byte(text, byte_index)
        local width = lead and (lead < 0x80 and 1 or lead < 0xE0 and 2 or lead < 0xF0 and 3 or 4) or 1
        byte_index = byte_index + width
        count = count + 1
    end
    return count
end

function mod:utf8_truncate(value, max_characters, suffix)
    local text = tostring(value or "")
    local maximum = math.max(0, tonumber(max_characters) or 0)
    if self:utf8_character_count(text) <= maximum then
        return text
    end
    local byte_index = 1
    local characters = 0
    while byte_index <= #text and characters < maximum do
        local lead = string.byte(text, byte_index)
        local width = lead and (lead < 0x80 and 1 or lead < 0xE0 and 2 or lead < 0xF0 and 3 or 4) or 1
        byte_index = byte_index + width
        characters = characters + 1
    end
    return string.sub(text, 1, byte_index - 1) .. tostring(suffix or "")
end

-- Scores owns metric visibility. Improve Yourself reads these settings but
-- never changes them. Mandatory rows have no Scores toggle and remain active.
local scores_metric_settings = {
    weakspot_hits = "show_weakspot_hits",
    weakspot_hit_percent = "show_weakspot_hit_percent",
    accuracy = "show_accuracy",
    critical_hits = "show_critical_hits",
    melee_kills = "show_melee_ranged_kills",
    ranged_kills = "show_melee_ranged_kills",
    boss_damage_dealt = "show_boss_damage_dealt",
    times_downed = "show_times_downed",
    times_disabled = "show_times_disabled",
    deaths = "show_deaths",
    attacks_blocked = "show_attacks_blocked",
    heal_station_used = "show_heal_station_used",
    revived_operative = "show_revived_rescued",
    team_saves = "show_team_saves",
    coherency_efficiency = "show_coherency_efficiency",
    ammo_score = "show_ammo_collected",
    resources_collected = "show_resources_collected",
}

function mod:scores_setting_enabled(setting_id)
    local scores = get_mod("scores")
    if not scores or not setting_id then return true end
    local ok, value = pcall(scores.get, scores, setting_id)
    return ok and value == true
end

function mod:is_metric_enabled(source)
    if source == "lesser_enemies" or source == "melee_ranged_threats" or source == "special_threats" then
        return self:scores_setting_enabled("detailed_kill_split")
    end
    local setting_id = scores_metric_settings[source]
    return setting_id == nil or self:scores_setting_enabled(setting_id)
end

function mod:detailed_kill_split_enabled()
    return self:scores_setting_enabled("detailed_kill_split")
end

-- The visual boards need to identify the local operative in both live and
-- saved Scores entries. These are identity utilities only; Improve
-- Yourself does not own or scan a history archive.
function mod:local_identity()
    local player_manager = Managers and Managers.player
    local player = player_manager and player_manager:local_player(1)
    if not player then
        return self._cached_local_account_id, self._cached_local_player_name
    end

    local function safe(method)
        local value = player[method]
        if type(value) == "function" then
            local ok, result = pcall(value, player)
            return ok and result or nil
        end
        return value
    end

    local player_name = safe("name")
    local account_id = safe("account_id") or player_name
    if account_id ~= nil then
        self._cached_local_account_id = account_id
    end
    if player_name ~= nil then
        self._cached_local_player_name = player_name
    end
    return account_id or self._cached_local_account_id, player_name or self._cached_local_player_name
end

function mod:is_local_history_player(player)
    if type(player) ~= "table" then
        return false
    end

    if player.is_local == true then
        return true
    end

    local account_id, player_name = self:local_identity()
    if account_id and player.account_id == account_id then
        return true
    end

    return player_name ~= nil and player.name == player_name
end

function mod.on_game_state_changed(status, state_name)
    if state_name ~= "StateGameplay" or not mod.damage_source_tracker then
        return
    end

    if status == "exit" then
        mod.damage_source_tracker:on_gameplay_exit()
    end
end

local function load_visual_renderer()
    local path = "improve-yourself/scripts/mods/improve-yourself/views/meta/improve_yourself_view"

    -- Improve Yourself is a Scores visualization plugin. Its renderer
    -- is hosted by Scores' Tactical, mission-end, and History views;
    -- no standalone load-always view is registered.
    mod:io_dofile(path)
end

local function install_chat_input_guard()
    local chat_class = CLASS and CLASS.ConstantElementChat
    if mod._chat_guard_installed or not chat_class or type(chat_class.update) ~= "function" then
        return
    end

    mod._chat_guard_installed = true
    mod:hook(chat_class, "update", function(func, self, dt, t, ui_renderer, render_settings, input_service, ...)
        local input_widget = self._input_field_widget
        mod._chat_input_active = not not (input_widget and input_widget.content and input_widget.content.is_writing)
        local result = func(self, dt, t, ui_renderer, render_settings, input_service, ...)
        input_widget = self._input_field_widget
        mod._chat_input_active = not not (input_widget and input_widget.content and input_widget.content.is_writing)
        return result
    end)
end

mod:hook_require("scripts/ui/constant_elements/elements/chat/constant_element_chat", function()
    install_chat_input_guard()
end)

local function live_scoreboard_entry()
    local adapter = mod.collector_manager
        and mod.collector_manager.adapters
        and mod.collector_manager.adapters.scores
    local current = adapter and adapter:get_current_match() or nil

    if not current or type(current.players) ~= "table" or #current.players == 0 then
        return nil
    end

    local entry = {
        name = tostring(os.time()),
        date = os.date("%Y-%m-%d %H:%M:%S"),
        mission_name = current.mission and current.mission.name or "",
        mission_challenge = current.mission and current.mission.difficulty or "",
        victory_defeat = current.mission and current.mission.result or "",
        timer = current.mission and current.mission.duration_seconds or nil,
        players = {},
        rows = {},
    }

    for index, player in ipairs(current.players) do
        entry.players[tostring(index)] = {
            index = tostring(index),
            account_id = player.account_id,
            name = player.name,
            string_symbol = player.string_symbol,
            archetype_name = player.archetype_name,
            account_name = player.account_name,
        }
    end

    for metric, row_name in pairs(adapter.metric_rows or {}) do
        if mod:is_metric_enabled(metric) then
            local row = {name = row_name, text = row_name, data = {}}
            for _, player in ipairs(current.players) do
                local value = player.metrics and player.metrics[metric]
                row.data[player.account_id] = {
                    score = tonumber(value) or 0,
                    value = tonumber(value) or 0,
                }
            end
            entry.rows[#entry.rows + 1] = row
        end
    end

    if mod.damage_source_tracker then
        mod.damage_source_tracker:append_history_rows(entry)
    end

    return entry
end

mod.build_live_scoreboard_entry = live_scoreboard_entry

function mod.update(dt)
    -- The synthetic end-view suppresses normal UI input; poll its Escape
    -- shortcut from the mod lifecycle so its close path always remains live.
    if mod.poll_eom_test then
        mod.poll_eom_test()
    end

    if mod.damage_source_tracker then
        mod.damage_source_tracker:poll_automatic_damage_diagnostic()
    end

    if mod.poll_scores_end_host then
        mod.poll_scores_end_host(dt)
    end

    if mod.poll_scores_history_host then
        mod.poll_scores_history_host()
    end
end

function mod.on_all_mods_loaded()
    local scoreboard = get_mod("scores")
    if not scoreboard then
        mod:error("Improve Yourself requires Scores. Install and enable Scores, then restart Darktide.")
        return
    end

    -- Preserve the user's Tactical choice from Scoreboard II builds. The
    -- option value is internal, so migrate it once to Scores' new identity.
    if mod:get("tactical_overlay_preference") == "scoreboard_ii" then
        mod:set("tactical_overlay_preference", "scores")
    end

    if tonumber(mod:get("goal_frontline_coherency_efficiency")) == 30 then
        mod:set("goal_frontline_coherency_efficiency", 25)
    end
    if tonumber(mod:get("goal_support_control_coherency_efficiency")) == 35 then
        mod:set("goal_support_control_coherency_efficiency", 25)
    end


    if mod.damage_source_tracker then
        mod.damage_source_tracker:install(scoreboard)
    end

    mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/tactical_overlay")
    install_chat_input_guard()
    mod.ui_manager = Managers.ui
    load_visual_renderer()
    mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/integrations/scores_end_host")
    mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/integrations/scores_history_host")
    mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/integrations/eom_test")

    scoreboard:add_global_localize_strings({
        loc_improve_yourself_show_bars = {
            en = "Show bars",
            de = "Balken anzeigen",
            ["zh-cn"] = "显示条形图",
        },
        loc_improve_yourself_show_numbers = {
            en = "Show numbers",
            de = "Zahlen anzeigen",
            ["zh-cn"] = "显示数字",
        },
    })
end
