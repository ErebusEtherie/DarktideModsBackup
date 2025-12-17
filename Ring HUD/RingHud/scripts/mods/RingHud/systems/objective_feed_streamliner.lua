-- File: RingHud/scripts/mods/RingHud/systems/objective_feed_streamliner.lua
local mod = get_mod("RingHud")
if not mod then
    return {}
end

-- Public API surface
mod.objective_feed_streamliner  = mod.objective_feed_streamliner or {}
local Streamliner               = mod.objective_feed_streamliner

-- Shared HUD helpers now come from mod.utils
local U                         = mod.utils
    or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local get_current_hud_instances = U.get_current_hud_instances
local resolve_element_instance  = U.resolve_element_instance

----------------------------------------------------------------
-- Local helpers / state
----------------------------------------------------------------

-- Streamline Rules (Minimal Objective Feed / General Declutter)
local STREAMLINE_RULES          = {
    HudElementAreaNotificationPopup = {
        background = { texture = false },
    },
    HudElementMissionObjectiveFeed = {
        background = { background = false, ground_emitter = false },
        live_event_background = { background = false, ground_emitter = false },
    },
    HudElementMissionObjectivePopup = {
        mission_popup = {
            background = false,
            description_text = false,
            effect = false,
            frame = false,
            title_text = false,
        },
    },
    HudElementMissionSpeakerPopup = {
        bar_1 = { background = false, bar = false, frame = false },
        bar_2 = { background = false, bar = false, frame = false },
        bar_3 = { background = false, bar = false, frame = false },
        bar_4 = { background = false, bar = false, frame = false },
        bar_5 = { background = false, bar = false, frame = false },
        bar_6 = { background = false, bar = false, frame = false },
        bar_7 = { background = false, bar = false, frame = false },
        radio = { soundwave = false },
        title_text = { title_text = false },
    },
    HudElementSpectatorText = {
        cycle_text = { style_id_1 = false },
        rescued_text = {
            background = false,
            background_frame = false,
            background_overlay = false,
            text = false,
        },
        -- spectating_text is intentionally omitted to remain visible
    },
}

-- Enforce streamlined styles during draw
local function _enforce_streamlined_styles(element_instance)
    if not (mod._settings and mod._settings.minimal_objective_feed_enabled) then
        return
    end

    local class_name = element_instance.__class_name
    local rules = STREAMLINE_RULES[class_name]
    if not rules then
        return
    end

    local widgets_by_name = element_instance._widgets_by_name
    if not widgets_by_name then
        return
    end

    -- Apply visibility tweaks from STREAMLINE_RULES
    for widget_name, style_overrides in pairs(rules) do
        local widget = widgets_by_name[widget_name]
        if widget and widget.style then
            for style_id, desired_visibility in pairs(style_overrides) do
                local pass_style = widget.style[style_id]
                if pass_style and pass_style.visible ~= desired_visibility then
                    pass_style.visible = desired_visibility
                    widget.dirty = true
                end
            end
        end
    end
end

----------------------------------------------------------------
-- Mission Objective Feed gating + filtering helpers
----------------------------------------------------------------

-- Detect Tactical Overlay element "active" state (vanilla sets self._active)
local function _tactical_overlay_is_active()
    local hud, const = get_current_hud_instances()
    local tac = resolve_element_instance(hud, const, "HudElementTacticalOverlay")
    return tac and tac._active == true or false
end

-- ADS detection to mirror hotkey_active_override exactly
local function _is_ads_now()
    local player_manager = Managers.player
    local local_player = player_manager and player_manager.local_player_safe
        and player_manager:local_player_safe(1)

    if local_player and local_player.player_unit then
        local unit_data_extension = ScriptUnit.has_extension(local_player.player_unit, "unit_data_system")
            and ScriptUnit.extension(local_player.player_unit, "unit_data_system")

        if unit_data_extension and unit_data_extension.read_component then
            local alternate_fire_comp = unit_data_extension:read_component("alternate_fire")
            return (alternate_fire_comp and alternate_fire_comp.is_active) or false
        end
    end

    return false
end

-- Force show == the same "hotkey_active_override" RingHud computes:
-- show_all_hud_hotkey_active OR (ads_visibility_dropdown == "ads_vis_hotkey" and ADS is active)
local function _force_show_is_active()
    local hotkey = (mod.show_all_hud_hotkey_active == true)
    local vis_mode = mod._settings and mod._settings.ads_visibility_dropdown

    if vis_mode == "ads_vis_hotkey" and _is_ads_now() then
        hotkey = true
    end

    return hotkey
end

-- Safe read of event_type from mission objective objects (no pcall)
local function _objective_event_type(obj)
    if type(obj) ~= "table" then
        return nil
    end

    local m = obj.event_type
    if type(m) == "function" then
        return m(obj)
    end

    return rawget(obj, "event_type")
end

local function _has_active_event_objective()
    local extm = Managers.state and Managers.state.extension
    local mos  = extm and extm.system and extm:system("mission_objective_system")

    if not mos then
        return false
    end

    local active = mos.active_objectives and mos:active_objectives()
    if type(active) ~= "table" then
        return false
    end

    for objective, _ in pairs(active) do
        local et = _objective_event_type(objective)
        if et == "mid_event" or et == "end_event" then
            return true
        end
    end

    return false
end

-- Test if a hud row is interesting and NOT a "goal" type
local function _is_goal_objective(hud_row_or_obj)
    if not hud_row_or_obj then
        return false
    end

    local underlying = hud_row_or_obj

    if type(hud_row_or_obj.objective) == "function" then
        local obj = hud_row_or_obj:objective()
        if obj then
            underlying = obj
        end
    end

    local function try_callable(obj, name)
        local m = obj and obj[name]
        if type(m) == "function" then
            return m(obj)
        end
        return nil
    end

    local mtype =
        try_callable(underlying, "objective_type")
        or try_callable(underlying, "mission_objective_type")
        or rawget(underlying, "objective_type")
        or rawget(underlying, "mission_objective_type")

    return mtype == "goal"
end

local function _hud_row_is_interesting(hud_row)
    if not hud_row then
        return false
    end

    if _is_goal_objective(hud_row) then
        return false
    end

    local function _try_row(method_name)
        local f = hud_row[method_name]
        if type(f) ~= "function" then
            return nil
        end
        return f(hud_row)
    end

    if _try_row("progress_bar") == true then
        return true
    end
    if _try_row("progress_timer") == true then
        return true
    end
    if _try_row("use_counter") == true then
        return true
    end
    if _try_row("has_second_progression") == true then
        return true
    end

    local cat = _try_row("objective_category") or rawget(hud_row, "_category") or rawget(hud_row, "category")
    return cat == "luggable" or cat == "collect" or cat == "side"
end

----------------------------------------------------------------
-- Init: register hooks
----------------------------------------------------------------

function Streamliner.init()
    -- Streamline styles for a bunch of vanilla HUD elements (except MissionObjectiveFeed)
    for class_name, _ in pairs(STREAMLINE_RULES) do
        if CLASS[class_name] and class_name ~= "HudElementMissionObjectiveFeed" then
            mod:hook_safe(CLASS[class_name], "draw", function(self)
                _enforce_streamlined_styles(self)
            end)
        end
    end

    -- Dynamic gating + filtering for Mission Objective Feed
    if CLASS and CLASS.HudElementMissionObjectiveFeed then
        -- DRAW: final hide after UPDATE decided (empty after filtering), unless exceptions apply
        mod:hook(CLASS.HudElementMissionObjectiveFeed, "draw",
            function(func, self_element, dt, t, ui_renderer, render_settings, input_service)
                _enforce_streamlined_styles(self_element)

                local has_event = _has_active_event_objective()
                if mod.intensity and mod.intensity.objectives_polled_this_frame then
                    mod.intensity.objectives_polled_this_frame()
                end

                -- If any exception is active, we never suppress drawing.
                if _tactical_overlay_is_active() or _force_show_is_active() or has_event then
                    return func(self_element, dt, t, ui_renderer, render_settings, input_service)
                end

                -- Otherwise, obey the update-time decision for empty filtered lists
                if self_element._ringhud_hide_entire_element then
                    return
                end

                return func(self_element, dt, t, ui_renderer, render_settings, input_service)
            end
        )

        -- Belt-and-braces: prune stale names before vanilla sorts/aligns to prevent nil lookups.
        mod:hook(CLASS.HudElementMissionObjectiveFeed, "_align_objective_widgets",
            function(func, self_element, ...)
                local names = self_element._hud_objectives_names_array
                local map   = self_element._hud_objectives

                if names and map then
                    for i = #names, 1, -1 do
                        if map[names[i]] == nil then
                            table.remove(names, i)
                        end
                    end
                end

                return func(self_element, ...)
            end
        )

        -- UPDATE: build filtered list unless any exception applies; hide element if empty after filtering
        mod:hook(CLASS.HudElementMissionObjectiveFeed, "update",
            function(func, self_element, dt, t, ui_renderer, render_settings, input_service)
                local has_event = _has_active_event_objective()
                if mod.intensity and mod.intensity.objectives_polled_this_frame then
                    mod.intensity.objectives_polled_this_frame()
                end

                local filtering_allowed =
                    mod:is_enabled()
                    and mod._settings
                    and mod._settings.minimal_objective_feed_enabled
                    and not has_event
                    and not _tactical_overlay_is_active()
                    and not _force_show_is_active()

                local original_names = self_element._hud_objectives_names_array
                local filtered_names = nil
                local keep_set = nil

                if filtering_allowed and original_names and self_element._hud_objectives then
                    local filtered = {}

                    for i = 1, #original_names do
                        local name = original_names[i]
                        local row  = self_element._hud_objectives[name]

                        if _hud_row_is_interesting(row) then
                            filtered[#filtered + 1] = name
                        end
                    end

                    if #filtered == 0 then
                        -- Nothing left after filtering: mark whole element hidden this frame.
                        self_element._ringhud_hide_entire_element = true
                    else
                        self_element._ringhud_hide_entire_element = false

                        if #filtered < #original_names then
                            self_element._hud_objectives_names_array = filtered
                            filtered_names = filtered
                            keep_set = {}

                            for i = 1, #filtered do
                                keep_set[filtered[i]] = true
                            end
                        end
                    end
                else
                    -- Any exception or minimal disabled: ensure element is visible and restored.
                    self_element._ringhud_hide_entire_element = false
                end

                local ret = func(self_element, dt, t, ui_renderer, render_settings, input_service)

                -- Post-call: enforce per-row visibility for filtered lists and always restore names
                if keep_set and self_element._objective_widgets_by_name then
                    for name, widget in pairs(self_element._objective_widgets_by_name) do
                        widget.visible = keep_set[name] == true
                    end

                    if self_element._hud_objectives_names_array == filtered_names then
                        self_element._hud_objectives_names_array = original_names
                    end

                    self_element._ringhud_forced_visibility = true
                else
                    if self_element._ringhud_forced_visibility and self_element._objective_widgets_by_name then
                        for _, widget in pairs(self_element._objective_widgets_by_name) do
                            widget.visible = true
                        end

                        self_element._ringhud_forced_visibility = false
                    end
                end

                return ret
            end
        )
    end
end

return Streamliner
