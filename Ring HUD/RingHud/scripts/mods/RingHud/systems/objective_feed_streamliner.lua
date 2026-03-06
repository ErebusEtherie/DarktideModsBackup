-- File: RingHud/scripts/mods/RingHud/systems/objective_feed_streamliner.lua
local mod = get_mod("RingHud")
if not mod then
    return {}
end

mod.objective_feed_streamliner  = mod.objective_feed_streamliner or {}
local Streamliner               = mod.objective_feed_streamliner

-- Shared HUD helpers
local U                         = mod.utils
    or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local get_current_hud_instances = U.get_current_hud_instances
local resolve_element_instance  = U.resolve_element_instance

----------------------------------------------------------------
-- Local helpers / state
----------------------------------------------------------------

Streamliner._end_event_latched  = false

local STREAMLINE_RULES          = {
    HudElementAreaNotificationPopup = {
        background = { texture = false },
    },
    HudElementInteraction = {
        background = { background = false },
        frame      = { frame = false },
        tag_text   = { text = false },
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
    },
}

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

    if class_name == "HudElementMissionObjectiveFeed" then
        for _, widget in pairs(widgets_by_name) do
            local style = widget.style
            local content = widget.content

            if style then
                -- 1. Hazard Stripes (Only visible if Alert is active)
                if style.hazard_above then
                    local show_hazard = (content and content.show_alert == true)
                    if style.hazard_above.visible ~= show_hazard then
                        style.hazard_above.visible = show_hazard
                        widget.dirty = true
                    end
                end

                -- 2. Overarching Background (Always hidden)
                if style.overarching_background then
                    if style.overarching_background.visible ~= false then
                        style.overarching_background.visible = false
                        widget.dirty = true
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------
-- Mission Objective Feed gating + filtering helpers
----------------------------------------------------------------

local function _get_obj_property(obj, key)
    if type(obj) ~= "table" then return nil end
    local m = obj[key]
    if type(m) == "function" then return m(obj) end
    return rawget(obj, key)
end

local function _hud_wrapper_is_interesting(hud_wrapper)
    if not hud_wrapper then return false end

    local obj
    if type(hud_wrapper.objective) == "function" then
        obj = hud_wrapper:objective()
    else
        obj = hud_wrapper._objective
    end

    if not obj then return false end

    -- 1. Rules that Force Retention (Do Not Filter)
    local cat = _get_obj_property(obj, "objective_category")
    if cat == "side_mission" then return true end

    local evt = _get_obj_property(obj, "event_type")
    if evt == "mid_event" or evt == "end_event" then return true end

    local has_bar = _get_obj_property(obj, "progress_bar")
    if has_bar == true then return true end

    -- 2. Rules per Mission Objective Type
    local o_type = _get_obj_property(obj, "mission_objective_type")
    if not o_type then o_type = _get_obj_property(obj, "objective_type") end

    if o_type == "timed" or o_type == "kill" or o_type == "luggable" or
        o_type == "decode" or o_type == "collect" or o_type == "demolition" then
        return true
    end

    -- 3. Filter "goal" type
    if o_type == "goal" then
        return false
    end

    -- 4. Default: Filter out unknown types
    return false
end

-- Check if any current objective is an "end_event" to trigger the latch
local function _check_for_end_event_trigger(hud_wrappers_list)
    if not hud_wrappers_list then return false end

    for i = 1, #hud_wrappers_list do
        local hud_wrapper = hud_wrappers_list[i]
        local obj = hud_wrapper and hud_wrapper:objective()
        if obj then
            local evt = _get_obj_property(obj, "event_type")
            if evt == "end_event" then
                return true
            end
        end
    end
    return false
end

----------------------------------------------------------------
-- Init: register hooks
----------------------------------------------------------------

function Streamliner.init()
    for class_name, _ in pairs(STREAMLINE_RULES) do
        if CLASS[class_name] and class_name ~= "HudElementMissionObjectiveFeed" then
            mod:hook_safe(CLASS[class_name], "draw", function(self)
                _enforce_streamlined_styles(self)
            end)
        end
    end

    if CLASS and CLASS.HudElementMissionObjectiveFeed then
        mod:hook(CLASS.HudElementMissionObjectiveFeed, "draw",
            function(func, self_element, dt, t, ui_renderer, render_settings, input_service)
                _enforce_streamlined_styles(self_element)
                return func(self_element, dt, t, ui_renderer, render_settings, input_service)
            end
        )

        mod:hook(CLASS.HudElementMissionObjectiveFeed, "_align_objective_widgets",
            function(func, self_element, ...)
                local original_list = self_element._hud_objectives_sorted

                if not Streamliner._end_event_latched then
                    if _check_for_end_event_trigger(original_list) then
                        Streamliner._end_event_latched = true
                    end
                end

                local should_filter = true

                if not (mod:is_enabled() and mod._settings and mod._settings.minimal_objective_feed_enabled) then
                    should_filter = false
                end

                if should_filter then
                    local gm = Managers.state and Managers.state.game_mode
                    local gm_name = gm and gm:game_mode_name()
                    if gm_name == "hub" or gm_name == "shooting_range" or gm_name == "prologue_hub" then
                        should_filter = false
                    end
                end

                if should_filter then
                    if Streamliner._end_event_latched then
                        should_filter = false
                    end
                end

                local filtered_list = nil

                if original_list then
                    local filtered = {}

                    for i = 1, #original_list do
                        local hud_wrapper = original_list[i]
                        local keep = true

                        if should_filter then
                            if not _hud_wrapper_is_interesting(hud_wrapper) then
                                keep = false
                            end
                        end

                        local obj = hud_wrapper:objective()
                        local widget = self_element._objective_widgets[obj]
                        if widget then
                            widget.visible = keep
                        end

                        if keep then
                            filtered[#filtered + 1] = hud_wrapper
                        end
                    end

                    if should_filter then
                        if #filtered < #original_list then
                            self_element._hud_objectives_sorted = filtered
                            filtered_list = filtered
                        end
                    end
                end

                local ret = func(self_element, ...)

                if filtered_list then
                    self_element._hud_objectives_sorted = original_list
                end

                return ret
            end
        )
    end
end

function Streamliner.on_game_state_changed(status, state_name)
    if state_name == "StateGameplay" and status == "enter" then
        Streamliner._end_event_latched = false
    end
end

return Streamliner
