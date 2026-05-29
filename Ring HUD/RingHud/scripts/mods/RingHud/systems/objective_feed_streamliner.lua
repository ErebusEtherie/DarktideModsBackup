-- File: RingHud/scripts/mods/RingHud/systems/objective_feed_streamliner.lua
local mod = get_mod("RingHud")
if not mod then
    return {}
end

mod.objective_feed_streamliner           = mod.objective_feed_streamliner or {}
local Streamliner                        = mod.objective_feed_streamliner

-- Shared HUD helpers
local U                                  = mod.utils
    or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local get_current_hud_instances          = U.get_current_hud_instances
local resolve_element_instance           = U.resolve_element_instance

local Text                               = require("scripts/utilities/ui/text")

local math_floor                         = math.floor
local math_max                           = math.max
local string_format                      = string.format

----------------------------------------------------------------
-- Local helpers / state
----------------------------------------------------------------

Streamliner._end_event_latched           = false

local EXPEDITION_LOCATION_OBJECTIVE_NAME = "expedition_location"
local EXPEDITION_TIMER_OBJECTIVE_NAME    = "objective_expedition_timer"
local MERGED_COUNTER_TIMER_GAP           = 16

local STREAMLINE_RULES                   = {
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

----------------------------------------------------------------
-- Mission Objective Feed gating + filtering helpers
----------------------------------------------------------------

local function _get_obj_property(obj, key)
    if type(obj) ~= "table" then return nil end
    local m = obj[key]
    if type(m) == "function" then return m(obj) end
    return rawget(obj, key)
end

local function _get_hud_wrapper_objective(hud_wrapper)
    if not hud_wrapper then
        return nil
    end

    if type(hud_wrapper.objective) == "function" then
        return hud_wrapper:objective()
    end

    return hud_wrapper._objective
end

local function _get_objective_name(obj)
    return _get_obj_property(obj, "name")
end

local function _is_streamlining_active()
    if not (mod:is_enabled() and mod._settings and mod._settings.minimal_objective_feed_enabled) then
        return false
    end

    local gm = Managers.state and Managers.state.game_mode
    local gm_name = gm and gm:game_mode_name()

    if gm_name == "hub" or gm_name == "shooting_range" or gm_name == "prologue_hub" then
        return false
    end

    if Streamliner._end_event_latched then
        return false
    end

    return true
end

local function _remember_counter_style_defaults(counter_style)
    if not counter_style then
        return
    end

    if not counter_style._ringhud_default_offset then
        local offset = counter_style.offset or { 0, 0, 0 }

        counter_style._ringhud_default_offset = {
            offset[1] or 0,
            offset[2] or 0,
            offset[3] or 0,
        }
    end

    if not counter_style._ringhud_default_size then
        local size = counter_style.size or {}

        counter_style._ringhud_default_size = {
            size[1],
            size[2],
        }
    end
end

local function _restore_expedition_location_widget(widget)
    if not widget then
        return
    end

    local content = widget.content
    local style = widget.style
    local dirty = false

    if content and content._ringhud_expedition_timer_merged then
        content._ringhud_expedition_timer_merged = nil
        content.timer_text = ""
        dirty = true
    end

    if style then
        local counter_style = style.counter_text
        local timer_style = style.timer_text

        if counter_style and counter_style._ringhud_default_offset then
            local default_offset = counter_style._ringhud_default_offset
            local default_size = counter_style._ringhud_default_size

            counter_style.offset[1] = default_offset[1]
            counter_style.offset[2] = default_offset[2]
            counter_style.offset[3] = default_offset[3]

            if default_size then
                counter_style.size[1] = default_size[1]
                counter_style.size[2] = default_size[2]
            end

            dirty = true
        end

        if timer_style and timer_style.default_offset then
            timer_style.offset[1] = timer_style.default_offset[1]
            timer_style.offset[2] = timer_style.default_offset[2]
            timer_style.offset[3] = timer_style.default_offset[3]
            dirty = true
        end
    end

    if dirty then
        widget.dirty = true
    end
end

local function _set_counter_text_from_hud_objective(hud_objective, widget)
    if not (hud_objective and widget and widget.content) then
        return
    end

    local content = widget.content

    if hud_objective:use_counter() then
        local max_increment_hidden = hud_objective:max_increment_hidden()
        local current_amount = hud_objective:current_counter_amount()
        local max_amount = hud_objective:max_counter_amount()

        if max_increment_hidden then
            content.counter_text = tostring(current_amount)
        else
            content.counter_text = tostring(current_amount) .. "/" .. tostring(max_amount)
        end
    else
        content.counter_text = ""
    end
end

local function _format_timer_text_and_realign_text(timer_hud_objective)
    if not timer_hud_objective then
        return "", "00:00", false
    end

    local max_counter_amount = timer_hud_objective:max_counter_amount() or 0
    local minutes = math_floor(max_counter_amount / 60 % 60)
    local show_minutes = minutes > 0
    local show_hours = minutes > 60
    local time_left = math_max(timer_hud_objective:time_left(), 0)
    local text
    local realign_text

    if show_hours then
        local use_short = true
        local allow_skip = false
        local max_detail

        text = Text.format_time_span_localized(time_left, use_short, allow_skip, max_detail)
        realign_text = text
    elseif show_minutes then
        local millis = math_floor(time_left % 1 * 100)

        text = string_format("%.2d:%.2d:%.2d", time_left / 60 % 60, time_left % 60, millis)
        realign_text = "00:00:00"
    else
        local millis = math_floor(time_left % 1 * 100)

        text = string_format("%.2d:%.2d", time_left % 60, millis)
        realign_text = "00:00"
    end

    return text, realign_text, show_hours
end

local function _find_expedition_merge_context(self_element)
    local hud_wrappers_list = self_element and self_element._hud_objectives_sorted
    local objective_widgets = self_element and self_element._objective_widgets
    local hud_objectives = self_element and self_element._hud_objectives
    local context = {
        active = false,
        has_location = false,
        has_timer = false,
        location_objective = nil,
        location_hud_objective = nil,
        location_widget = nil,
        timer_objective = nil,
        timer_hud_objective = nil,
        timer_widget = nil,
    }

    if not hud_wrappers_list then
        return context
    end

    for i = 1, #hud_wrappers_list do
        local hud_wrapper = hud_wrappers_list[i]
        local objective = _get_hud_wrapper_objective(hud_wrapper)
        local objective_name = _get_objective_name(objective)

        if objective_name == EXPEDITION_LOCATION_OBJECTIVE_NAME then
            context.has_location = true
            context.location_objective = objective
            context.location_hud_objective = hud_objectives and hud_objectives[objective] or nil
            context.location_widget = objective_widgets and objective_widgets[objective] or nil
        elseif objective_name == EXPEDITION_TIMER_OBJECTIVE_NAME then
            context.has_timer = true
            context.timer_objective = objective
            context.timer_hud_objective = hud_objectives and hud_objectives[objective] or nil
            context.timer_widget = objective_widgets and objective_widgets[objective] or nil
        end
    end

    context.active = context.has_location
        and context.has_timer
        and context.location_hud_objective ~= nil
        and context.location_widget ~= nil
        and context.timer_hud_objective ~= nil

    return context
end

local function _apply_expedition_location_timer_merge(self_element)
    local context = _find_expedition_merge_context(self_element)

    if not _is_streamlining_active() or not context.active then
        if context.location_widget then
            _restore_expedition_location_widget(context.location_widget)
        end

        return
    end

    local location_widget = context.location_widget
    local location_hud_objective = context.location_hud_objective
    local timer_hud_objective = context.timer_hud_objective
    local content = location_widget.content
    local style = location_widget.style

    if not (content and style and location_hud_objective and timer_hud_objective) then
        return
    end

    _set_counter_text_from_hud_objective(location_hud_objective, location_widget)

    local timer_text, realign_text = _format_timer_text_and_realign_text(timer_hud_objective)
    local dirty = false

    if content.timer_text ~= timer_text then
        content.timer_text = timer_text
        dirty = true
    end

    content._ringhud_expedition_timer_merged = true

    local counter_style = style.counter_text
    local timer_style = style.timer_text

    if timer_style and timer_style.default_offset then
        local ui_renderer = self_element._parent and self_element._parent:ui_renderer()

        if ui_renderer and self_element._text_size then
            local optional_size = {
                500,
                40,
            }
            local width = self_element:_text_size(ui_renderer, realign_text, timer_style, optional_size)
            local desired_offset_x = timer_style.default_offset[1] - width

            if timer_style.offset[1] ~= desired_offset_x then
                timer_style.offset[1] = desired_offset_x
                timer_style.offset[2] = timer_style.default_offset[2]
                timer_style.offset[3] = timer_style.default_offset[3]
                dirty = true
            end

            if counter_style then
                _remember_counter_style_defaults(counter_style)

                local default_size = counter_style._ringhud_default_size
                local counter_width = default_size and default_size[1] or (counter_style.size and counter_style.size[1]) or
                    0
                local desired_counter_offset_x = desired_offset_x - MERGED_COUNTER_TIMER_GAP - counter_width

                if counter_style.offset[1] ~= desired_counter_offset_x then
                    counter_style.offset[1] = desired_counter_offset_x
                    counter_style.offset[2] = counter_style._ringhud_default_offset[2]
                    counter_style.offset[3] = counter_style._ringhud_default_offset[3]
                    dirty = true
                end
            end
        end
    end

    if dirty then
        location_widget.dirty = true
    end
end

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

    if class_name == "HudElementInteraction" then
        local hud, hud_const = get_current_hud_instances()
        local feed = resolve_element_instance(hud, hud_const, "HudElementMissionObjectiveFeed")
        if feed then
            _apply_expedition_location_timer_merge(feed)
        else
        end
    end

    if class_name == "HudElementMissionObjectiveFeed" then
        _apply_expedition_location_timer_merge(element_instance)
        for _, widget in pairs(widgets_by_name) do
            local style = widget.style
            local content = widget.content

            if style then
                if style.icon and style.icon.visible ~= false then
                    style.icon.visible = false
                    widget.dirty = true
                end

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

local function _hud_wrapper_is_interesting(hud_wrapper)
    if not hud_wrapper then return false end

    local obj = _get_hud_wrapper_objective(hud_wrapper)

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
        local obj = _get_hud_wrapper_objective(hud_wrapper)

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

                local should_filter = _is_streamlining_active()
                local expedition_context = _find_expedition_merge_context(self_element)
                local filtered_list = nil

                if original_list then
                    local filtered = {}

                    for i = 1, #original_list do
                        local hud_wrapper = original_list[i]
                        local keep = true
                        local obj = _get_hud_wrapper_objective(hud_wrapper)
                        local obj_name = _get_objective_name(obj)

                        if should_filter then
                            if expedition_context.active and obj_name == EXPEDITION_LOCATION_OBJECTIVE_NAME then
                                keep = true
                            elseif expedition_context.active and obj_name == EXPEDITION_TIMER_OBJECTIVE_NAME then
                                keep = false
                            elseif not _hud_wrapper_is_interesting(hud_wrapper) then
                                keep = false
                            end
                        end

                        if obj then
                            local widget = self_element._objective_widgets[obj]
                            if widget then
                                widget.visible = keep
                            end
                        end

                        if keep then
                            filtered[#filtered + 1] = hud_wrapper
                        end
                    end

                    if should_filter and #filtered < #original_list then
                        self_element._hud_objectives_sorted = filtered
                        filtered_list = filtered
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
