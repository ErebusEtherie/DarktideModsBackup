-- File: scripts/mods/BetterLoadouts/preset_drag_reorder.lua

local mod = get_mod("BetterLoadouts")
if not mod then
    return
end

local ProfileUtils = require("scripts/utilities/profile_utils")
local UIResolution = require("scripts/managers/ui/ui_resolution")

local HOLD_SECONDS = 0.35
local SLIDE_SPEED = 18
local DRAG_Z_OFFSET = 20
local ACTIVE_SCALE = 1.18

local SYMBOL_STYLE_IDS = {
    "icon",
    "unicode",
    "custom_text",
}

local function _cursor_navigation_active()
    local ui_manager = Managers.ui
    return not ui_manager or ui_manager:using_cursor_navigation()
end

local function _cursor_position(input_service)
    if not input_service then
        return nil
    end

    local cursor = input_service:get("cursor")
    if not cursor then
        return nil
    end

    local inverse_scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale
    if inverse_scale then
        return UIResolution.inverse_scale_vector(cursor, inverse_scale)
    end

    return cursor
end

local function _restore_callback(widget)
    local hotspot = widget and widget.content and widget.content.hotspot
    if not hotspot or not hotspot.betterloadouts_drag_wrapped then
        return
    end

    hotspot.pressed_callback = hotspot.betterloadouts_drag_original_pressed_callback
    hotspot.betterloadouts_drag_original_pressed_callback = nil
    hotspot.betterloadouts_drag_wrapped = nil
end

local function _restore_offsets(state)
    local widgets = state and state.widgets
    local slots = state and state.slots
    if not widgets or not slots then
        return
    end

    for i = 1, #widgets do
        local widget = widgets[i]
        local slot = slots[i]
        local offset = widget and widget.offset

        if offset and slot then
            offset[1] = slot[1]
            offset[2] = slot[2]
            offset[3] = slot[3]
        end
    end
end

local function _capture_symbol_scale(state)
    local widget = state and state.widget
    local styles = widget and widget.style
    if not styles or state.symbol_scale_originals then
        return
    end

    local saved = Script.new_array(#SYMBOL_STYLE_IDS)
    local count = 0

    for i = 1, #SYMBOL_STYLE_IDS do
        local style = styles[SYMBOL_STYLE_IDS[i]]
        if style then
            local entry = {
                style = style,
                font_size = style.font_size,
                had_size_addition = style.size_addition ~= nil,
                size_addition_x = style.size_addition and (style.size_addition[1] or 0) or 0,
                size_addition_y = style.size_addition and (style.size_addition[2] or 0) or 0,
                width = style.size and style.size[1],
                height = style.size and style.size[2],
            }

            if entry.font_size or (entry.width and entry.height) then
                count = count + 1
                saved[count] = entry
            end
        end
    end

    state.symbol_scale_originals = saved
    state.symbol_scale_originals_count = count
end

local function _enforce_symbol_scale(state)
    local saved = state and state.symbol_scale_originals
    local count = state and state.symbol_scale_originals_count or 0
    if not saved then
        return
    end

    local scale_addition = ACTIVE_SCALE - 1

    for i = 1, count do
        local entry = saved[i]
        local style = entry.style

        if entry.width and entry.height then
            style.size_addition = style.size_addition or { 0, 0 }
            style.size_addition[1] = entry.size_addition_x + entry.width * scale_addition
            style.size_addition[2] = entry.size_addition_y + entry.height * scale_addition
        end

        if entry.font_size then
            style.font_size = entry.font_size * ACTIVE_SCALE
        end
    end
end

local function _restore_symbol_scale(state)
    local saved = state and state.symbol_scale_originals
    local count = state and state.symbol_scale_originals_count or 0
    if not saved then
        return
    end

    for i = 1, count do
        local entry = saved[i]
        local style = entry.style

        if entry.width and entry.height then
            if entry.had_size_addition then
                style.size_addition = style.size_addition or { 0, 0 }
                style.size_addition[1] = entry.size_addition_x
                style.size_addition[2] = entry.size_addition_y
            else
                style.size_addition = nil
            end
        end

        if entry.font_size then
            style.font_size = entry.font_size
        end
    end

    state.symbol_scale_originals = nil
    state.symbol_scale_originals_count = nil
end

function mod.reset_preset_drag_reorder(self)
    if not self then
        return
    end

    local state = self._betterloadouts_drag_state
    if state and state.dragging then
        _restore_offsets(state)
        _restore_symbol_scale(state)
    end

    self._betterloadouts_drag_state = nil
end

local function _begin_press(self, widget, index, original_callback)
    if not self or self._costumization_open or not _cursor_navigation_active() then
        if original_callback then
            return original_callback()
        end
        return
    end

    local widgets = self._profile_buttons_widgets
    if not widgets or #widgets < 2 or widgets[index] ~= widget then
        if original_callback then
            return original_callback()
        end
        return
    end

    self._betterloadouts_drag_state = {
        widget = widget,
        index = index,
        original_callback = original_callback,
    }
end

function mod.attach_preset_drag_reorder(self)
    if not self then
        return
    end

    mod.reset_preset_drag_reorder(self)

    local widgets = self._profile_buttons_widgets
    if not widgets or #widgets < 2 then
        return
    end

    for i = 1, #widgets do
        _restore_callback(widgets[i])
    end

    for i = 1, #widgets do
        local widget = widgets[i]
        local hotspot = widget and widget.content and widget.content.hotspot

        if hotspot and hotspot.pressed_callback then
            local widget_index = i
            local original_callback = hotspot.pressed_callback

            hotspot.betterloadouts_drag_original_pressed_callback = original_callback
            hotspot.betterloadouts_drag_wrapped = true
            hotspot.pressed_callback = function()
                return _begin_press(self, widget, widget_index, original_callback)
            end
        end
    end
end

local function _start_drag(self, state, input_service)
    local widgets = self and self._profile_buttons_widgets
    if not widgets or widgets[state.index] ~= state.widget then
        return false
    end

    local cursor = _cursor_position(input_service)
    if not cursor then
        return false
    end

    local slots = Script.new_array(#widgets)

    for i = 1, #widgets do
        local offset = widgets[i] and widgets[i].offset
        if not offset then
            return false
        end

        slots[i] = {
            offset[1] or 0,
            offset[2] or 0,
            offset[3] or 0,
        }
    end

    state.widgets = widgets
    state.slots = slots
    state.start_index = state.index
    state.target_index = state.index
    state.start_preset_id = state.widget.content and state.widget.content.profile_preset_id
    state.drag_cursor_origin_x = cursor[1]
    state.drag_cursor_origin_y = cursor[2]
    state.drag_widget_origin_x = slots[state.index][1]
    state.drag_widget_origin_y = slots[state.index][2]
    state.dragging = true

    _capture_symbol_scale(state)
    _enforce_symbol_scale(state)

    return true
end

local function _target_index_for_position(state, x, y)
    local slots = state.slots
    local best_index = state.start_index
    local best_distance = math.huge

    for i = 1, #slots do
        local slot = slots[i]
        local dx = x - slot[1]
        local dy = y - slot[2]
        local distance = dx * dx + dy * dy

        if distance < best_distance then
            best_distance = distance
            best_index = i
        end
    end

    return best_index
end

local function _slide_towards(current, target, dt)
    local amount = math.min((dt or 0) * SLIDE_SPEED, 1)
    return current + (target - current) * amount
end

local function _update_drag_visual(state, dt, input_service)
    local cursor = _cursor_position(input_service)
    if not cursor then
        return false
    end

    _enforce_symbol_scale(state)

    local drag_x = state.drag_widget_origin_x + cursor[1] - state.drag_cursor_origin_x
    local drag_y = state.drag_widget_origin_y + cursor[2] - state.drag_cursor_origin_y
    local target_index = _target_index_for_position(state, drag_x, drag_y)
    local start_index = state.start_index
    local widgets = state.widgets
    local slots = state.slots

    state.target_index = target_index

    for i = 1, #widgets do
        local widget = widgets[i]
        local offset = widget and widget.offset
        local slot = slots[i]

        if offset and slot then
            if i == start_index then
                offset[1] = drag_x
                offset[2] = drag_y
                offset[3] = slot[3] + DRAG_Z_OFFSET
            else
                local desired_slot = slot

                if target_index > start_index and i > start_index and i <= target_index then
                    desired_slot = slots[i - 1]
                elseif target_index < start_index and i >= target_index and i < start_index then
                    desired_slot = slots[i + 1]
                end

                offset[1] = _slide_towards(offset[1], desired_slot[1], dt)
                offset[2] = _slide_towards(offset[2], desired_slot[2], dt)
                offset[3] = slot[3]
            end
        end
    end

    return true
end

local function _reorder_presets(start_preset_id, target_preset_id)
    if not start_preset_id or not target_preset_id then
        return false
    end

    local presets = ProfileUtils.get_profile_presets()
    if not presets then
        return false
    end

    local start_index
    local target_index

    for i = 1, #presets do
        local preset_id = presets[i] and presets[i].id

        if preset_id == start_preset_id then
            start_index = i
        end
        if preset_id == target_preset_id then
            target_index = i
        end

        if start_index and target_index then
            break
        end
    end

    if not start_index or not target_index then
        return false
    end

    if start_index ~= target_index then
        local preset = table.remove(presets, start_index)
        table.insert(presets, target_index, preset)
        Managers.save:queue_save()
    end

    return true
end

local function _finish_drag(self, state)
    local start_index = state.start_index
    local target_index = state.target_index or start_index

    if target_index == start_index then
        _restore_offsets(state)
        _restore_symbol_scale(state)
        self._betterloadouts_drag_state = nil
        return
    end

    local target_widget = state.widgets[target_index]
    local target_preset_id = target_widget and target_widget.content and target_widget.content.profile_preset_id
    local reordered = _reorder_presets(state.start_preset_id, target_preset_id)

    self._betterloadouts_drag_state = nil

    if reordered then
        self:_setup_preset_buttons()
    else
        _restore_offsets(state)
        _restore_symbol_scale(state)
    end
end

local function _activate_click(self, state)
    local original_callback = state.original_callback
    self._betterloadouts_drag_state = nil

    if original_callback then
        original_callback()
    end
end

local function _update_drag_reorder(self, dt, t, input_service)
    local state = self and self._betterloadouts_drag_state
    if not state then
        return
    end

    if self._costumization_open or not _cursor_navigation_active() then
        mod.reset_preset_drag_reorder(self)
        return
    end

    if not state.started_at then
        state.started_at = t
    end

    local left_pressed = input_service:get("left_pressed") == true
    local left_hold = input_service:get("left_hold") == true
    local left_released = input_service:get("left_released") == true

    if state.dragging then
        if left_released then
            _finish_drag(self, state)
        elseif left_hold or left_pressed then
            if not _update_drag_visual(state, dt, input_service) then
                mod.reset_preset_drag_reorder(self)
            end
        else
            mod.reset_preset_drag_reorder(self)
        end

        return
    end

    if left_released then
        _activate_click(self, state)
        return
    end

    if not left_hold and not left_pressed then
        mod.reset_preset_drag_reorder(self)
        return
    end

    if t - state.started_at >= HOLD_SECONDS then
        if _start_drag(self, state, input_service) then
            _update_drag_visual(state, dt, input_service)
        else
            mod.reset_preset_drag_reorder(self)
        end
    end
end

mod:hook(CLASS.ViewElementProfilePresets, "update", function(func, self, dt, t, input_service)
    local result = func(self, dt, t, input_service)

    _update_drag_reorder(self, dt, t, input_service)

    return result
end)
