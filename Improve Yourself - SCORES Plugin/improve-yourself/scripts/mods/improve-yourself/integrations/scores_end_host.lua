local mod = get_mod("improve-yourself")
local scoreboard = get_mod("scores")
if not scoreboard or mod._scores_end_host_installed then
    return mod
end
mod._scores_end_host_installed = true

local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local CLASS = CLASS
local VisualConstants = mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/views/shared/improve_yourself_visual_constants")
local REWARD_PHASE_Y_OFFSET = VisualConstants.victory.reward_phase_y_offset
local SCORES_DEFINITIONS = "scores/scripts/mods/scores/views/scoreboard/scoreboard_view_definitions"
local IY_DEFINITIONS = "improve-yourself/scripts/mods/improve-yourself/views/meta/improve_yourself_view_definitions"

-- Scores builds the view incrementally and protects its widget lookup table
-- with a strict metatable. Missing hosted widgets must be treated as "not
-- ready yet" instead of being accessed through the throwing wrapper.
local function hosted_widget(view, name)
    local widgets = view and view._widgets_by_name
    return type(widgets) == "table" and rawget(widgets, name) or nil
end

-- Mirror the proven History integration: hosted widgets remain hidden from
-- Scores' native draw-all pass and are revealed only inside our own draw pass.
local function set_compact_visibility(view, visible)
    for _, name in ipairs(mod.victory_host_compact_widgets or {}) do
        local widget = hosted_widget(view, name)
        if widget then
            widget.visible = visible == true
        end
    end
end

-- Feature gate for replacing Scores' visible end screen.
local function replacement_enabled()
    return tostring(mod:get("end_board_preference") or "improve_yourself") == "improve_yourself"
end

-- Refresh the shared Victory definitions inside the mission-end host.
-- Prevents old merged geometry from surviving Reload Mods.
local function merge_definitions(definitions)
    if type(definitions) ~= "table" then
        return definitions
    end

    local iy = mod:io_dofile(IY_DEFINITIONS)
    if type(iy) ~= "table" then return definitions end

    definitions.scenegraph_definition = definitions.scenegraph_definition or {}
    definitions.widget_definitions = definitions.widget_definitions or {}

    -- Merge only the compact Victory Board. Earlier builds merged the entire
    -- detailed view, including obsolete test catalogues, into Scores.
    for name, node in pairs(iy.scenegraph_definition or {}) do
        if string.sub(name, 1, 8) == "compact_" then
            definitions.scenegraph_definition[name] = table.clone(node)
        end
    end
    for _, name in ipairs(mod.victory_host_compact_widgets or {}) do
        local widget = iy.widget_definitions and iy.widget_definitions[name]
        if widget then
            definitions.widget_definitions[name] = table.clone(widget)
        end
    end

    definitions._iy_host_merged = true
    return definitions
end

-- Both the end-board and History integrations need to augment definitions
-- loaded through Scores' io_dofile method. DMF identifies hooks by the
-- calling mod, target, and method, so installing two separate hooks here and
-- in scores_history_host.lua lets the later hook displace the earlier
-- one. Keep one dispatcher and register path-specific mergers with it instead.
mod._iy_scoreboard_definition_mergers = mod._iy_scoreboard_definition_mergers or {}

function mod.register_scores_definition_merger(path, key, merger)
    if type(path) ~= "string" or type(key) ~= "string" or type(merger) ~= "function" then
        return false
    end

    local mergers = mod._iy_scoreboard_definition_mergers
    mergers[path] = mergers[path] or {}
    mergers[path][key] = merger

    if not mod._iy_scoreboard_definition_dispatcher_installed then
        mod._iy_scoreboard_definition_dispatcher_installed = true
        mod:hook(scoreboard, "io_dofile", function(func, self, loaded_path, ...)
            local result = func(self, loaded_path, ...)
            local path_mergers = mod._iy_scoreboard_definition_mergers
                and mod._iy_scoreboard_definition_mergers[loaded_path]

            if path_mergers then
                for _, registered_merger in pairs(path_mergers) do
                    result = registered_merger(result)
                end
            end

            return result
        end)
    end

    return true
end

mod.register_scores_definition_merger(SCORES_DEFINITIONS, "end_host", merge_definitions)

local attach_live_view

-- Scores saves the finalized entry synchronously from its end-view
-- on_enter. Prefer that exact entry when history saving is enabled: it avoids
-- rebuilding the finished roster from player-manager state while the mission
-- is being torn down. This is not a second history reader or cache; it calls
-- Scores' own loader for only the entry created for this end view.
local function recently_saved_entry(view)
    if not view then return nil end
    if view._iy_saved_entry then return view._iy_saved_entry end
    if type(scoreboard.get_scoreboard_history_entries_cache) ~= "function"
        or type(scoreboard.appdata_path) ~= "function"
        or type(scoreboard.load_scoreboard_history_entry) ~= "function" then
        return nil
    end

    local ok_cache, files = pcall(scoreboard.get_scoreboard_history_entries_cache, scoreboard)
    if not ok_cache or type(files) ~= "table" then return nil end

    local newest_file
    local newest_stamp
    for _, file_name in pairs(files) do
        local stamp = type(file_name) == "string" and tonumber(string.match(file_name, "^(%d+)%.lua$")) or nil
        if stamp and (not newest_stamp or stamp > newest_stamp) then
            newest_file = file_name
            newest_stamp = stamp
        end
    end

    -- Never borrow an older mission when history auto-save is disabled or a
    -- save failed. The matching file must have been created with this view.
    local attached_at = tonumber(view._iy_host_attached_at) or os.time()
    if not newest_stamp or newest_stamp < attached_at - 2 or newest_stamp > os.time() + 2 then
        return nil
    end

    local ok_base, base_path = pcall(scoreboard.appdata_path, scoreboard)
    if not ok_base or type(base_path) ~= "string" then return nil end

    local ok_load, entry = pcall(
        scoreboard.load_scoreboard_history_entry,
        scoreboard,
        base_path .. newest_file,
        tostring(newest_stamp),
        false
    )
    if ok_load and type(entry) == "table" then
        view._iy_saved_entry = entry
        return entry
    end
    return nil
end

local function compact_widgets_exist(view)
    for _, name in ipairs(mod.victory_host_compact_widgets or {}) do
        if not hosted_widget(view, name) then
            return false, name
        end
    end
    return true
end

-- Prepare the replacement as part of view attachment, before Scores'
-- first draw. The regular update poll repeats the same work and remains the
-- recovery path when either the merged widgets or finalized data are not yet
-- available. This removes the one-frame native-number flash without weakening
-- the native fallback for genuine initialization failures.
local function prepare_initial_host(view)
    if not view or not compact_widgets_exist(view) then return false end

    local entry = mod._iy_eom_test_entry
        or recently_saved_entry(view)
        or (mod.build_live_scoreboard_entry and mod.build_live_scoreboard_entry() or nil)
    if not entry or not mod.render_victory_host then return false end

    view._iy_host_ready = mod.render_victory_host(view, entry)
    if view._iy_host_ready and view.remove_input_legend then
        view:remove_input_legend()
    end

    return view._iy_host_ready == true
end

local function draw_native_fallback(view, dt, input_service, ...)
    local native_draw = view and view._iy_original_draw_widgets_callable
    if type(native_draw) ~= "function" then return end

    -- The compact widgets are merged into Scores' scenegraph before
    -- they can be populated. Hide them for the native fallback pass so an
    -- empty Improve Yourself panel cannot cover the numerical scoreboard.
    local visibility = {}
    for _, name in ipairs(mod.victory_host_compact_widgets or {}) do
        local widget = hosted_widget(view, name)
        if widget then
            visibility[name] = widget.visible
            widget.visible = false
        end
    end

    -- The user may have disabled Scores' own end board because Improve
    -- Yourself normally replaces it. Temporarily restore the native scoreboard
    -- for this one fail-safe draw without changing the saved preference.
    local native_visibility = {}
    local function expose_native(widget)
        if widget and not native_visibility[widget] then
            native_visibility[widget] = {
                visible = widget.visible,
                alpha_multiplier = widget.alpha_multiplier,
            }
            widget.visible = true
            widget.alpha_multiplier = 1
        end
    end
    for name, widget in pairs(view._widgets_by_name or {}) do
        if name == "scoreboard" or string.sub(name or "", 1, 15) == "scoreboard_row_" then
            expose_native(widget)
        end
    end
    for _, widget in ipairs(view.row_widgets or {}) do expose_native(widget) end
    local end_scoreboard_visible = view._end_scoreboard_visible
    view._end_scoreboard_visible = true

    local result = native_draw(view, dt, input_service, ...)

    view._end_scoreboard_visible = end_scoreboard_visible
    for widget, state in pairs(native_visibility) do
        widget.visible = state.visible
        widget.alpha_multiplier = state.alpha_multiplier
    end

    for name, visible in pairs(visibility) do
        local widget = hosted_widget(view, name)
        if widget then widget.visible = visible end
    end
    return result
end

-- Draw Improve Yourself inside the actual Scores end view.
local function draw_replacement(view, dt, input_service)
    local renderer = view._ui_renderer
    if not renderer or not view._ui_scenegraph then return end

    -- Reward views render on a high layer. Draw the hosted Improve Yourself
    -- replacement on an isolated high-layer settings table so it stays above
    -- Mission Reward Experience / Primary Objective Reward without mutating
    -- Scores' own render settings.
    local render_settings = table.clone(view._render_settings or {})
    render_settings.layer = math.max(render_settings.layer or 0, VisualConstants.render_layer)

    UIRenderer.begin_pass(renderer, view._ui_scenegraph, input_service, dt, render_settings)
    for _, name in ipairs(mod.victory_host_draw_widgets or mod.victory_host_compact_widgets or {}) do
        local widget = hosted_widget(view, name)
        if widget then
            -- Keep merged IY widgets invisible to Scores' native draw-all pass;
            -- expose each widget only for its dedicated replacement draw.
            widget.visible = true
            UIWidget.draw(widget, renderer)
            widget.visible = false
        end
    end
    UIRenderer.end_pass(renderer)
end

-- Scores owns horizontal movement by rebuilding every widget offset from
-- style.original_offset on each update. Reward-phase vertical alignment therefore
-- has to modify that authoritative base offset as well as the current offset.
-- Apply the stabilized reward-stage position and layer adjustment.
-- This protects the Victory Board when Darktide transitions to the reward phase.
local function apply_reward_phase_position(view, active)
    if not view or not view._widgets_by_name then
        return
    end

    local target = active and REWARD_PHASE_Y_OFFSET or 0

    if view._iy_reward_phase_y == target then
        return
    end

    -- Move complete hosted widgets, never their nested style passes.
    --
    -- Scores rebuilds style.offset from style.original_offset, while the
    -- Victory Board renderers also rewrite many bar and label style offsets.
    -- Changing those nested style values breaks the internal bar geometry.
    --
    -- widget.offset translates each complete widget after its internal styles
    -- have been calculated and is not rebuilt by Scores' offset update.
    for _, name in ipairs(mod.victory_host_compact_widgets or {}) do
        local widget = hosted_widget(view, name)

        if widget then
            widget.offset = widget.offset or {0, 0, 0}

            if widget._iy_reward_base_y == nil then
                widget._iy_reward_base_y = tonumber(widget.offset[2]) or 0
            end

            widget.offset[2] = widget._iy_reward_base_y + target
        end
    end

    view._iy_reward_phase_y = target
end

-- Restore host state so temporary Scores mutations cannot persist.
local function restore_view(view)
    if not view then return end
    set_compact_visibility(view, false)
    if not view._iy_live_host_attached then return end
    if view._iy_original_draw_widgets_field ~= nil then
        view._draw_widgets = view._iy_original_draw_widgets_field
    else
        view._draw_widgets = nil
    end
    view._iy_live_host_attached = nil
    view._iy_host_ready = nil
    view._iy_host_elapsed = nil
    view._iy_host_retry = nil
    view._iy_host_stable_elapsed = nil
    view._iy_host_last_signature = nil
    view._iy_host_finalized = nil
    view._iy_host_wait_warned = nil
    view._iy_host_replacement_enabled = nil
    view._iy_saved_entry = nil
    view._iy_host_attached_at = nil
    view._iy_original_draw_widgets_callable = nil
    apply_reward_phase_position(view, false)
    view._iy_reward_phase_y = nil
    view._iy_reward_base_panel_y = nil
    view._iy_original_draw_widgets_field = nil
    -- Release the Tactical exclusion only for the end-view that owns it.
    if mod._iy_host_live_view == view then
        mod._iy_scores_end_view_active = false
    end
end

attach_live_view = function(view)
    if not view or view._iy_live_host_attached then return false end
    if not view.end_view then return false end

    set_compact_visibility(view, false)
    view._iy_original_draw_widgets_field = rawget(view, "_draw_widgets")
    view._iy_original_draw_widgets_callable = view._draw_widgets
    view._iy_live_host_attached = true
    view._iy_host_attached_at = os.time()
    view._iy_host_ready = false
    view._iy_host_elapsed = 0
    view._iy_host_retry = 0
    view._iy_host_stable_elapsed = 0
    view._iy_host_last_signature = nil
    view._iy_host_finalized = false
    view._iy_host_replacement_enabled = replacement_enabled()
    -- Tactical and mission-end views are separate layers; this shared state
    -- prevents either Tactical board from drawing over the result screen.
    mod._iy_scores_end_view_active = true

    -- One permanent wrapper owns the mode switch for this end-view instance,
    -- matching History's numbers/bars design. Scores mode always takes the
    -- untouched native path; Improve Yourself mode uses the hosted board only
    -- after it has populated successfully.
    view._draw_widgets = function(self, dt, input_service, ...)
        if not replacement_enabled() or not self._iy_host_ready then
            return draw_native_fallback(self, dt, input_service, ...)
        end
        return draw_replacement(self, dt, input_service)
    end

    -- Scores finalizes/saves the entry synchronously during on_enter.
    -- Populate now so the draw override is already ready on its first frame.
    -- If that is not possible, _iy_host_ready stays false and the established
    -- native fail-safe remains visible until the update poll succeeds.
    if view._iy_host_replacement_enabled then
        prepare_initial_host(view)
    end

    return true
end

-- Scores rebuilds the view during on_enter. Attach immediately after
-- that native setup has created the widgets from the merged definitions.
-- Polling remains as a safety fallback if the class is not yet available.
if CLASS and CLASS.ScoreboardView and type(CLASS.ScoreboardView.on_enter) == "function" then
    mod:hook(CLASS.ScoreboardView, "on_enter", function(func, view, ...)
        local result = func(view, ...)
        if view and view.end_view then
            local ui = scoreboard.ui_manager or mod.ui_manager or (Managers and Managers.ui)
            local active_view = ui and type(ui.view_instance) == "function"
                and ui:view_instance("scores_view") or view
            if mod._iy_host_live_view and mod._iy_host_live_view ~= active_view then
                restore_view(mod._iy_host_live_view)
            end
            mod._iy_host_live_view = active_view
            attach_live_view(active_view)
        end
        return result
    end)
end

local function entry_signature(entry)
    if type(entry) ~= "table" then return "nil" end
    local parts = {}
    local players = entry.players or {}
    for key, player in pairs(players) do
        parts[#parts + 1] = string.format("p:%s:%s", tostring(key), tostring(player and (player.account_id or player.name) or ""))
    end
    local rows = entry.rows or {}
    for index, row in ipairs(rows) do
        parts[#parts + 1] = "r:" .. tostring(row.name or index)
        for account_id, data in pairs(row.data or {}) do
            parts[#parts + 1] = string.format("v:%s:%s", tostring(account_id), tostring(data and (data.score or data.value) or 0))
        end
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

-- Poll the mission-end host lifecycle and attach/detach at safe boundaries.
-- Coordinates definition refresh, finalized entry changes, reward phase, and cleanup.
function mod.poll_scores_end_host(dt)
    local ui = scoreboard.ui_manager or mod.ui_manager or (Managers and Managers.ui)
    if not ui or type(ui.view_instance) ~= "function" then return end

    local active = type(ui.view_active) == "function" and ui:view_active("scores_view")
    local view = ui:view_instance("scores_view")

    if not active or not view or not view.end_view then
        if mod._iy_host_live_view then
            restore_view(mod._iy_host_live_view)
            mod._iy_host_live_view = nil
        end
        return
    end

    if mod._iy_host_live_view ~= view then
        if mod._iy_host_live_view then restore_view(mod._iy_host_live_view) end
        mod._iy_host_live_view = view
    end

    if not view._iy_live_host_attached and not attach_live_view(view) then return end
    set_compact_visibility(view, false)

    local enabled = replacement_enabled()
    if view._iy_host_replacement_enabled ~= enabled then
        -- Keep the same wrapper when the user changes boards, just as History
        -- switches numbers/bars without creating a second overlapping view.
        view._iy_host_replacement_enabled = enabled
        view._iy_host_ready = false
        view._iy_host_elapsed = 0
        view._iy_host_retry = 0
        view._iy_host_stable_elapsed = 0
        view._iy_host_last_signature = nil
        view._iy_host_finalized = false
        view._iy_host_wait_warned = nil
    end

    if not enabled then
        apply_reward_phase_position(view, false)
        return
    end

    local step = dt or 0
    view._iy_host_elapsed = (view._iy_host_elapsed or 0) + step
    local widgets_ready, missing_widget = compact_widgets_exist(view)
    if not widgets_ready then
        if (view._iy_host_elapsed or 0) > 5 and not view._iy_host_wait_warned then
            view._iy_host_wait_warned = true
            mod:warning("Improve Yourself end host is missing widget %s; keeping Scores visible.", tostring(missing_widget))
        end
        return
    end
    apply_reward_phase_position(view, mod._iy_reward_phase_active == true)
    view._iy_host_retry = (view._iy_host_retry or 0) - step
    if view._iy_host_finalized or view._iy_host_retry > 0 then return end
    view._iy_host_retry = 0.1

    local entry = mod._iy_eom_test_entry
        or recently_saved_entry(view)
        or (mod.build_live_scoreboard_entry and mod.build_live_scoreboard_entry() or nil)
    if entry and mod.render_victory_host then
        local signature = entry_signature(entry)
        if signature == view._iy_host_last_signature then
            view._iy_host_stable_elapsed = (view._iy_host_stable_elapsed or 0) + 0.1
        else
            view._iy_host_last_signature = signature
            view._iy_host_stable_elapsed = 0
        end

        view._iy_host_ready = mod.render_victory_host(view, entry)

        -- Suppress the native input legend only after the replacement has
        -- rendered successfully. Until then the untouched Scores board
        -- remains the visible, interactive fail-safe.
        if view._iy_host_ready and view.remove_input_legend then
            view:remove_input_legend()
        end

        -- Keep refreshing briefly so late player snapshots and final Scores
        -- values can settle. Freeze only after at least 1.5 seconds and 0.5
        -- seconds without a data change, with a hard cap of 3 seconds.
        if view._iy_host_ready and ((view._iy_host_elapsed >= 1.5 and view._iy_host_stable_elapsed >= 0.5) or view._iy_host_elapsed >= 3.0) then
            view._iy_host_finalized = true
        end
    elseif (view._iy_host_elapsed or 0) > 5 and not view._iy_host_wait_warned then
        view._iy_host_wait_warned = true
        mod:warning("Improve Yourself host is still waiting for finalized Scores data; keeping Scores visible.")
    end
end

-- Darktide draws the previous reward card while it retracts and slides left to
-- make room for the next card. That outgoing card is the only reward widget
-- that crosses the Scores lane. Preserve the native carousel geometry
-- and suppress only the outgoing card for carousel state 1
-- (slide_cards_to_the_left). The current card, progress bar, wallets, and all
-- other EndPlayerView widgets continue through the original draw path.
local CAROUSEL_STATE_SLIDE_LEFT = 1

if CLASS and CLASS.EndPlayerView and type(CLASS.EndPlayerView._draw_widgets) == "function" then
    mod:hook(CLASS.EndPlayerView, "_draw_widgets", function(func, self, dt, t, input_service, ui_renderer, ...)
        local previous_card
        local previous_x
        local current_card = tonumber(self._current_card)

        if mod._iy_reward_phase_active
            and self._current_carousel_state == CAROUSEL_STATE_SLIDE_LEFT
            and current_card and current_card > 1
            and type(self._card_widgets) == "table" then
            previous_card = self._card_widgets[current_card - 1]
            if previous_card and type(previous_card.offset) == "table" then
                previous_x = previous_card.offset[1]
                -- EndPlayerView only draws cards whose X offset lies between
                -- its carousel borders. Put the outgoing card just outside the
                -- left border for this draw call, then restore it immediately.
                previous_card.offset[1] = (self._carousel_left_border or -10000) - 1
            end
        end

        local result = func(self, dt, t, input_service, ui_renderer, ...)

        if previous_card and previous_x ~= nil then
            previous_card.offset[1] = previous_x
        end

        return result
    end)
end

if CLASS and CLASS.EndPlayerView then
    mod:hook_safe(CLASS.EndPlayerView, "on_enter", function(self, ...)
        mod._iy_reward_phase_active = true
        if mod._iy_host_live_view then
            apply_reward_phase_position(mod._iy_host_live_view, true)
        end
    end)

    mod:hook_safe(CLASS.EndPlayerView, "on_exit", function(self, ...)
        mod._iy_reward_phase_active = false
        if mod._iy_host_live_view then
            apply_reward_phase_position(mod._iy_host_live_view, false)
        end
    end)
end

return mod
