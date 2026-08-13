local mod = get_mod("improve-yourself")

mod.version = "1.0.0"
mod.damage_source_tracker = mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/integrations/damage_source_tracker")
mod.collector_manager = mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/integrations/collector_manager")
mod.visual_constants = mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/views/shared/improve_yourself_visual_constants")

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

    scoreboard:add_global_localize_strings({
        loc_improve_yourself_show_bars = {
            en = "Show bars",
            de = "Balken anzeigen",
        },
        loc_improve_yourself_show_numbers = {
            en = "Show numbers",
            de = "Zahlen anzeigen",
        },
    })
end
