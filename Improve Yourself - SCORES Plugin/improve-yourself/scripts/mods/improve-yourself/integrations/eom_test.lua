local mod = get_mod("improve-yourself")
local scores = get_mod("scores")

if not scores or mod._iy_eom_test_installed then
    return mod
end

mod._iy_eom_test_installed = true

-- Preview state is scoped to one synthetic Scores end-view and must never leak
-- into an actual mission result or the next saved History entry.
local function clear_test_state()
    mod._iy_eom_test_active = false
    mod._iy_eom_test_opening = false
    mod._iy_eom_test_entry = nil
    mod._iy_eom_test_escape_down = false
end

-- Force-close the actual Scores view through Darktide's normal view teardown;
-- that lifecycle restores the previous gameplay, HUD, and input state.
local function close_test_view()
    local ui = scores.ui_manager or mod.ui_manager or (Managers and Managers.ui)

    if ui
        and type(ui.view_active) == "function"
        and ui:view_active("scores_view")
        and type(ui.close_view) == "function" then
        ui:close_view("scores_view", true)
    elseif type(scores.close_scoreboard_view) == "function" then
        scores:close_scoreboard_view()
    end

    clear_test_state()
end

-- End-of-mission views can receive a null UI input service, so Escape must be
-- read from the physical keyboard rather than through input_service:get().
local function escape_pressed()
    local keyboard = Keyboard
    if not keyboard or type(keyboard.button_index) ~= "function" then
        return false
    end

    local ok_index, escape_index = pcall(keyboard.button_index, "esc")
    if not ok_index or escape_index == nil then
        return false
    end

    if type(keyboard.pressed) == "function" then
        local ok_pressed, pressed = pcall(keyboard.pressed, escape_index)
        if ok_pressed then
            return not not pressed
        end
    end

    if type(keyboard.button) ~= "function" then
        return false
    end

    local ok_button, value = pcall(keyboard.button, escape_index)
    local down = ok_button and type(value) == "number" and value > 0.5
    local pressed = down and not mod._iy_eom_test_escape_down
    mod._iy_eom_test_escape_down = down

    return pressed
end

-- Recreate Scores History's lightweight player wrappers so archived matches
-- can be rendered through the same mission-end host as live matches.
local function history_players(entry)
    local players = {}

    for player_index = 1, 4 do
        local player_data = entry.players and entry.players[tostring(player_index)]
        if player_data then
            local player = {
                account_id = function() return player_data.account_id end,
                name = function() return player_data.name end,
                account_name = function() return player_data.account_name end,
                string_symbol = player_data.string_symbol,
            }

            if player_data.profile and player_data.profile.loadout then
                player.scoreboard_history_profile = true
                player.profile = function() return player_data.profile end
            end

            players[#players + 1] = player
        end
    end

    return players
end

-- Reuse Scores' own History APIs instead of inventing match telemetry or
-- maintaining a separate Improve Yourself test-data archive.
local function latest_history_entry()
    if type(scores.get_scoreboard_history_entries) ~= "function"
        or type(scores.appdata_path) ~= "function"
        or type(scores.load_scoreboard_history_entry) ~= "function" then
        return nil, nil
    end

    local ok_entries, entries = pcall(scores.get_scoreboard_history_entries, scores, false)
    if not ok_entries or type(entries) ~= "table" or #entries == 0 then
        ok_entries, entries = pcall(scores.get_scoreboard_history_entries, scores, true)
    end
    if not ok_entries or type(entries) ~= "table" then
        return nil, nil
    end

    local newest
    local newest_stamp
    for _, head in ipairs(entries) do
        local file_name = type(head) == "table" and head.file or nil
        local stamp = type(file_name) == "string" and tonumber(string.match(file_name, "^(%d+)%.lua$")) or nil
        if stamp and (not newest_stamp or stamp > newest_stamp) then
            newest = head
            newest_stamp = stamp
        end
    end

    if not newest or not newest_stamp then
        return nil, nil
    end

    local ok_path, base_path = pcall(scores.appdata_path, scores)
    if not ok_path or type(base_path) ~= "string" then
        return nil, nil
    end

    local ok_load, entry, groups = pcall(
        scores.load_scoreboard_history_entry,
        scores,
        base_path .. newest.file,
        tostring(newest_stamp),
        false
    )
    if not ok_load or type(entry) ~= "table" then
        return nil, nil
    end

    return entry, type(groups) == "table" and groups or {}
end

-- A synthetic end-view must not write another History entry or announce
-- awards. Keep the hooks installed but inert outside the short test lifecycle.
if type(scores.save_scoreboard_history_entry) == "function" then
    mod:hook(scores, "save_scoreboard_history_entry", function(func, self, ...)
        if mod._iy_eom_test_opening or mod._iy_eom_test_active then
            return false
        end
        return func(self, ...)
    end)
end

if type(scores.announce_top_scores) == "function" then
    mod:hook(scores, "announce_top_scores", function(func, self, ...)
        if mod._iy_eom_test_opening or mod._iy_eom_test_active then
            return
        end
        return func(self, ...)
    end)
end

local CLASS = CLASS
if CLASS and CLASS.ScoreboardView and type(CLASS.ScoreboardView.on_exit) == "function" then
    -- Also clear preview state when another game system closes the view.
    mod:hook_safe(CLASS.ScoreboardView, "on_exit", function(view)
        if view and view.end_view and mod._iy_eom_test_active then
            clear_test_state()
        end
    end)
end

-- Poll outside ScoreboardView:update so Escape remains available even when
-- Darktide has intentionally replaced that view's input with a null service.
function mod.poll_eom_test()
    if not mod._iy_eom_test_active or not escape_pressed() then
        return
    end

    local ui = scores.ui_manager or mod.ui_manager or (Managers and Managers.ui)
    local view = ui and type(ui.view_instance) == "function" and ui:view_instance("scores_view")

    if view and view._popup_menu and type(view._close_popup_menu) == "function" then
        view:_close_popup_menu()
        return
    end

    close_test_view()
end

mod:command("iy_eom_test", "Preview the mission-end board using the latest Scores History entry. Press ESC to close.", function()
    if mod._iy_eom_test_active then
        mod:echo("The Improve Yourself EoM preview is already open. Press ESC to close it.")
        return
    end

    if type(scores.end_scoreboard_opened) == "function" and scores:end_scoreboard_opened() then
        mod:echo("Cannot start /iy_eom_test while a real mission-end Scores view is open.")
        return
    end

    local entry, groups = latest_history_entry()
    if not entry then
        mod:echo("/iy_eom_test needs at least one saved Scores History entry.")
        return
    end

    if type(scores.show_scoreboard_view) ~= "function" then
        mod:echo("Scores does not expose the scoreboard preview function required by /iy_eom_test.")
        return
    end

    mod._iy_eom_test_entry = entry
    mod._iy_eom_test_opening = true
    local ok, opened = pcall(scores.show_scoreboard_view, scores, {
        end_view = true,
        groups = groups,
        players = history_players(entry),
        rows = entry.rows or {},
    })
    mod._iy_eom_test_opening = false

    if not ok or opened ~= true then
        clear_test_state()
        mod:echo("Unable to open the Improve Yourself EoM test view.")
        return
    end

    mod._iy_eom_test_active = true
    mod:echo("Improve Yourself EoM test opened from the latest Scores History entry. Press ESC to close it.")
end)

return mod
