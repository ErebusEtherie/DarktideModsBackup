local mod = get_mod('better_buff_management')
mod:io_dofile('better_buff_management/scripts/mods/better_buff_management/utilities/table')
mod:io_dofile('better_buff_management/scripts/mods/better_buff_management/utilities/imgui')
mod:io_dofile('better_buff_management/scripts/mods/better_buff_management/ui/components/base_buff_component')
local UiSettings = mod:io_dofile('better_buff_management/scripts/mods/better_buff_management/ui/settings')
local BarConfig = mod:io_dofile('better_buff_management/scripts/mods/better_buff_management/models/bar_config')

local MOD_NAME = mod:localize('mod_name')
local CLASS_NAME = 'BuffBarsComponent'

local ERROR_PREFIX = ('[%s][%s]'):format(MOD_NAME, CLASS_NAME)
local ERRORS = {
}

local BARS_SETTING_ID = 'bars'
local CREATE_BUFF_BAR_BUTTON_LOC_ID = 'create_buff_bar_button'
local SELECT_BUFF_BAR_LABEL_LOC_ID = 'select_buff_bar_label'
local CLEAR_BUFF_BAR_BUTTON_LOC_ID = 'clear_buff_bar_button'
local DELETE_BUFF_BAR_BUTTON_LOC_ID = 'delete_buff_bar_button'
local REMOVE_BUFF_FROM_BUFF_BAR_LOC_ID = 'remove_buff_from_buff_bar'
local BAR_POS_X_LOC_ID = 'bar_pos_x'
local BAR_POS_Y_LOC_ID = 'bar_pos_y'
local SNAP_TO_DEFAULT_LOC_ID = 'snap_to_default_bar'
local DIRECTION_LABEL_LOC_ID = 'buff_direction_label'
local ORDER_LABEL_LOC_ID = 'buff_order_label'
local OPACITY_LABEL_LOC_ID = 'bar_opacity'
local RENAME_BAR_LABEL_LOC_ID = 'rename_buff_bar_label'
local RENAME_BAR_BUTTON_LOC_ID = 'rename_buff_bar_button'
local CLASS_FILTER_LABEL_LOC_ID = 'class_filter_label'
local CLASS_FILTER_ALL_LOC_ID = 'class_filter_all'
local CLASS_FILTER_NONE_LOC_ID = 'class_filter_none'

local function _clear_table(tbl)
    if table.clear then
        table.clear(tbl)
        return
    end

    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

-- -------------------------------
-- ------- Local Functions -------
-- -------------------------------

local function _update_buffs(window_id, buffs)
    local same_line_flag = false
    for i = 1, #buffs do
        local buff = buffs[i]
        if buff then
            if same_line_flag then
                Imgui.same_line()
            end

            buff._bbm_ui_id = buff._bbm_ui_id or string.to_pascal_case(buff.name or 'unknown', '_')
            local buff_window_id = ('%s_%s'):format(window_id, buff._bbm_ui_id)
            Imgui.begin_child_window(buff_window_id, UiSettings.BUFF_WINDOW_SIZE[1], UiSettings.BUFF_WINDOW_SIZE[2], false)

            if buff.icon and buff.icon ~= '' then
                Imgui.image_button(buff.icon, UiSettings.BUFF_IMAGE_SIZE[1], UiSettings.BUFF_IMAGE_SIZE[2], 255, 255, 255, 1)
            else
                Imgui.text(buff.name or '???')
            end

            local remove = Imgui.button(mod:localize(REMOVE_BUFF_FROM_BUFF_BAR_LOC_ID))

            Imgui.end_child_window()

            if Imgui.is_item_hovered() then
                Imgui.begin_tool_tip()
                Imgui.text(buff.name)
                Imgui.end_tool_tip()
            end

            if remove then
                buff.bar_name = ''
                mod:bump_buffs_data_revision()
            end

            same_line_flag = true
        end
    end
end

-- -------------------------------
-- --------- Constructor ---------
-- -------------------------------
local BuffBarsComponent = class(CLASS_NAME, 'BaseBuffComponent')
function BuffBarsComponent:init(buffs_data)
    BuffBarsComponent.super.init(self, buffs_data)

    self._bars = mod:get(BARS_SETTING_ID)
    self._new_bar_name = ''
    self._selected_bar_index = nil
    self._cached_bar_data = {}
    self._data_is_dirty = true
    self._last_buffs_data_revision = mod:get_buffs_data_revision()

    -- Working copy of per-bar configs; mutated in place and written through to the
    -- 'bar_configs' setting on edit. Applied to the HUD on the next recreate_hud.
    self._bar_configs = BarConfig.get_all()

    -- Per-bar pending rename text (keyed by current bar name).
    self._rename_inputs = {}

    -- Localized dropdown labels, built once (localization is a DMF-internal call).
    self._direction_labels = {}
    for i = 1, #BarConfig.DIRECTIONS do
        self._direction_labels[i] = mod:localize('buff_direction_option_' .. BarConfig.DIRECTIONS[i])
    end

    self._order_labels = {}
    for i = 1, #BarConfig.ORDER_MODES do
        self._order_labels[i] = mod:localize('buff_order_option_' .. BarConfig.ORDER_MODES[i])
    end

    -- Per-class tickbox labels, parallel to BarConfig.CLASS_NAMES. Fall back to a
    -- capitalized internal name for any class without a class_label_<name> string
    -- (e.g. a future archetype the localization file doesn't cover yet).
    self._class_labels = {}
    for i = 1, #BarConfig.CLASS_NAMES do
        local name = BarConfig.CLASS_NAMES[i]
        local key = 'class_label_' .. name
        local label = mod:localize(key)
        if type(label) ~= 'string' or label == '' or label == key or label:find('^<') then
            label = name:sub(1, 1):upper() .. name:sub(2)
        end
        self._class_labels[i] = label
    end
end

-- -------------------------------
-- ------ Config Controls --------
-- -------------------------------

function BuffBarsComponent:_get_bar_config(bar)
    local cfg = self._bar_configs[bar]
    if type(cfg) ~= 'table' or type(cfg.pos_x) ~= 'number' or cfg.direction == nil then
        cfg = BarConfig.normalize(cfg)
        self._bar_configs[bar] = cfg
    end
    return cfg
end

function BuffBarsComponent:_save_bar_configs()
    mod:set(BarConfig.SETTING_ID, self._bar_configs)
end

-- Rename a bar. The name is the identity key everywhere, so rekey all three
-- stores: the `bars` order array (in place -- length/order unchanged, safe to do
-- mid render loop), every buff's `bar_name` assignment, and the `bar_configs`
-- entry. Applied to the HUD on the next recreate_hud (window close). Rejects
-- empty/whitespace names and collisions with an existing bar.
function BuffBarsComponent:_rename_bar(old_name, new_name)
    if string.is_nil_or_whitespace(new_name) or new_name == old_name then
        return false
    end

    if self._bars == nil or table.contains(self._bars, new_name) then
        return false
    end

    local index = table.index_of(self._bars, old_name)
    if not index or index < 1 then
        return false
    end

    self._bars[index] = new_name
    mod:set(BARS_SETTING_ID, self._bars)

    -- Move buff assignments from the old bar to the new name.
    if not table.is_nil_or_empty(self._buffs_data) then
        for _, data in pairs(self._buffs_data) do
            if data.bar_name == old_name then
                data.bar_name = new_name
            end
        end
        mod:bump_buffs_data_revision()
    end

    -- Move the per-bar config to the new key.
    local cfg = self._bar_configs[old_name]
    if cfg ~= nil then
        self._bar_configs[old_name] = nil
        self._bar_configs[new_name] = cfg
        self:_save_bar_configs()
    end

    self:_mark_dirty()
    return true
end

-- Narrow numeric field. input_text otherwise fills most of the window width, so
-- constrain it: push_item_width when the engine binding exposes it, else wrap in
-- a fixed-width borderless child window (always available).
local NUM_FIELD_W = 64
local NUM_FIELD_H = 26
-- Width for the rename input and class dropdown -- ~1/3 of their old full-row
-- width so they don't stretch across the whole bar panel.
local WIDE_FIELD_W = 150
function BuffBarsComponent:_number_field(id, value)
    local text = tostring(value)

    if Imgui.push_item_width ~= nil and Imgui.pop_item_width ~= nil then
        Imgui.push_item_width(NUM_FIELD_W)
        local out = Imgui.ided_input_text(id, text)
        Imgui.pop_item_width()
        return out
    end

    Imgui.begin_child_window(id .. '_W', NUM_FIELD_W, NUM_FIELD_H, false)
    local out = Imgui.ided_input_text(id, text)
    Imgui.end_child_window()
    return out
end

-- Imgui.combo wrapped at WIDE_FIELD_W. The wrapper runs begin_combo/end_combo
-- internally, so the popup window-switch is fully contained -- popping item width
-- after it returns is always in the parent window (see _update_class_filter).
function BuffBarsComponent:_narrow_combo(...)
    local narrow = Imgui.push_item_width ~= nil and Imgui.pop_item_width ~= nil
    if narrow then
        Imgui.push_item_width(WIDE_FIELD_W)
    end
    local result = Imgui.combo(...)
    if narrow then
        Imgui.pop_item_width()
    end
    return result
end

-- Multi-select "dropdown of tickboxes" picking which classes the bar shows on.
-- Preview reads All / None / N/total. cfg.classes is nil (all) or a map of enabled
-- archetype names; toggling routes through BarConfig.toggle_class which collapses
-- all-on back to nil. Returns true if the selection changed this frame.
function BuffBarsComponent:_update_class_filter(bar, cfg)
    local names = BarConfig.CLASS_NAMES
    local total = #names
    local classes = cfg.classes

    local preview
    if classes == nil then
        preview = mod:localize(CLASS_FILTER_ALL_LOC_ID)
    else
        local count = 0
        for _ in pairs(classes) do
            count = count + 1
        end
        if count == 0 then
            preview = mod:localize(CLASS_FILTER_NONE_LOC_ID)
        else
            preview = ('%d/%d'):format(count, total)
        end
    end

    local changed = false

    Imgui.text(mod:localize(CLASS_FILTER_LABEL_LOC_ID))
    Imgui.same_line()

    Imgui.push_id(('%s_%s_CLASSES'):format(self.__class_name, bar))
    -- push_item_width sizes the combo box. It must be popped in the SAME window it
    -- was pushed in (the parent), but an open combo switches the current window to
    -- the popup between begin_combo and end_combo -- so pop only AFTER end_combo has
    -- returned to the parent window, never in between (that pops the popup's empty
    -- stack -> "PopItemWidth() too many times").
    local narrow = Imgui.push_item_width ~= nil and Imgui.pop_item_width ~= nil
    if narrow then
        Imgui.push_item_width(WIDE_FIELD_W)
    end
    if Imgui.begin_combo('', preview) then
        for i = 1, total do
            local name = names[i]
            local is_on = BarConfig.class_enabled(classes, name)
            local new_on = Imgui.checkbox(self._class_labels[i], is_on)
            if new_on ~= is_on then
                classes = BarConfig.toggle_class(classes, name, new_on)
                cfg.classes = classes
                changed = true
            end
        end
        Imgui.end_combo()
    end
    if narrow then
        Imgui.pop_item_width()
    end
    Imgui.pop_id()

    return changed
end

function BuffBarsComponent:_update_bar_config_controls(bar)
    local cfg = self:_get_bar_config(bar)
    local changed = false

    -- Position X / Y (top-left workspace coords, ~0-1920 x, ~0-1080 y). Compact
    -- fields with the label as separate text so the input stays small.
    Imgui.text(mod:localize(BAR_POS_X_LOC_ID))
    Imgui.same_line()
    local x_str = self:_number_field(('%s_%s_X'):format(self.__class_name, bar), cfg.pos_x)
    local x_num = tonumber(x_str)
    if x_num and x_num ~= cfg.pos_x then
        cfg.pos_x = x_num
        changed = true
    end

    Imgui.same_line()
    Imgui.text(mod:localize(BAR_POS_Y_LOC_ID))
    Imgui.same_line()
    local y_str = self:_number_field(('%s_%s_Y'):format(self.__class_name, bar), cfg.pos_y)
    local y_num = tonumber(y_str)
    if y_num and y_num ~= cfg.pos_y then
        cfg.pos_y = y_num
        changed = true
    end

    Imgui.same_line()

    Imgui.push_id(('%s_%s_SNAP'):format(self.__class_name, bar))
    if Imgui.button(mod:localize(SNAP_TO_DEFAULT_LOC_ID)) then
        cfg.pos_x = BarConfig.DEFAULT_SNAP_POS[1]
        cfg.pos_y = BarConfig.DEFAULT_SNAP_POS[2]
        changed = true
    end
    Imgui.pop_id()

    -- Growth direction.
    local dir_index = BarConfig.direction_index(cfg.direction)
    local new_dir_index = self:_narrow_combo(('%s_%s_DIR'):format(self.__class_name, bar),
        mod:localize(DIRECTION_LABEL_LOC_ID), self._direction_labels, dir_index, false)
    if new_dir_index and new_dir_index ~= dir_index then
        cfg.direction = BarConfig.DIRECTIONS[new_dir_index] or cfg.direction
        changed = true
    end

    -- Buff order mode.
    local order_index = BarConfig.order_mode_index(cfg.order_mode)
    local new_order_index = self:_narrow_combo(('%s_%s_ORDER'):format(self.__class_name, bar),
        mod:localize(ORDER_LABEL_LOC_ID), self._order_labels, order_index, false)
    if new_order_index and new_order_index ~= order_index then
        cfg.order_mode = BarConfig.ORDER_MODES[new_order_index] or cfg.order_mode
        changed = true
    end

    -- Buff opacity, edited as a whole percent (0-100), stored as 0-1.
    Imgui.text(mod:localize(OPACITY_LABEL_LOC_ID))
    Imgui.same_line()
    local opacity_pct = math.floor((cfg.opacity or 1) * 100 + 0.5)
    local op_str = self:_number_field(('%s_%s_OPACITY'):format(self.__class_name, bar), opacity_pct)
    local op_num = tonumber(op_str)
    if op_num then
        if op_num < 0 then
            op_num = 0
        elseif op_num > 100 then
            op_num = 100
        end
        local new_opacity = op_num / 100
        if new_opacity ~= cfg.opacity then
            cfg.opacity = new_opacity
            changed = true
        end
    end

    -- Class restriction (which classes the bar shows on).
    if self:_update_class_filter(bar, cfg) then
        changed = true
    end

    if changed then
        self:_save_bar_configs()
    end

    -- Rename bar. Field prefills with the current name; Rename commits it.
    local pending = self._rename_inputs[bar]
    if pending == nil then
        pending = bar
    end
    local narrow_rename = Imgui.push_item_width ~= nil and Imgui.pop_item_width ~= nil
    if narrow_rename then
        Imgui.push_item_width(WIDE_FIELD_W)
    end
    pending = Imgui.ided_input_text(('%s_%s_RENAME'):format(self.__class_name, bar),
        mod:localize(RENAME_BAR_LABEL_LOC_ID), pending)
    if narrow_rename then
        Imgui.pop_item_width()
    end
    self._rename_inputs[bar] = pending

    Imgui.same_line()
    Imgui.push_id(('%s_%s_RENAME_BTN'):format(self.__class_name, bar))
    local do_rename = Imgui.button(mod:localize(RENAME_BAR_BUTTON_LOC_ID))
    Imgui.pop_id()

    if do_rename and self:_rename_bar(bar, pending) then
        -- Bar key changed; drop both stale pending entries so the renamed bar's
        -- field prefills fresh next frame.
        self._rename_inputs[bar] = nil
        self._rename_inputs[pending] = nil
    end
end

-- -------------------------------
-- ------ Private Functions ------
-- -------------------------------

function BuffBarsComponent:_mark_dirty()
    self._data_is_dirty = true
end

function BuffBarsComponent:_sync_dirty_state()
    local revision = mod:get_buffs_data_revision()
    if revision ~= self._last_buffs_data_revision then
        self._last_buffs_data_revision = revision
        self._data_is_dirty = true
    end
end

function BuffBarsComponent:_rebuild_cache()
    _clear_table(self._cached_bar_data)

    if self._bars == nil or #self._bars == 0 or table.is_nil_or_empty(self._buffs_data) then
        self._data_is_dirty = false
        return
    end

    for _, bar in ipairs(self._bars) do
        local bar_data = {}
        local count = 0

        for _, data in pairs(self._buffs_data) do
            if data.bar_name == bar then
                count = count + 1
                bar_data[count] = data
            end
        end

        if count > 0 then
            table.sort(bar_data, function(data_a, data_b)
                return (data_a.name or '') < (data_b.name or '')
            end)
        end

        self._cached_bar_data[bar] = bar_data
    end

    self._data_is_dirty = false
end

function BuffBarsComponent:_update_create_bar()
    local create_bar = Imgui.button(mod:localize(CREATE_BUFF_BAR_BUTTON_LOC_ID))
    Imgui.same_line()
    self._new_bar_name = Imgui.ided_input_text(self.__class_name .. '_BAR_NAME_INPUT', self._new_bar_name)

    if not string.is_nil_or_whitespace(self._new_bar_name) and create_bar then
        local bar_added = false

        if self._bars == nil or #self._bars == 0 then
            self._bars = { self._new_bar_name }
            bar_added = true
        elseif not table.contains(self._bars, self._new_bar_name) then
            table.insert(self._bars, self._new_bar_name)
            bar_added = true
        end

        if bar_added then
            mod:set(BARS_SETTING_ID, self._bars)
            self:_mark_dirty()
        end

        self._new_bar_name = ''
    end
end

function BuffBarsComponent:_update_clear_or_delete_bar()
    self._selected_bar_index = Imgui.combo(self.__class_name .. '_SELECT_BAR_INPUT',
        mod:localize(SELECT_BUFF_BAR_LABEL_LOC_ID), self._bars, self._selected_bar_index)
    Imgui.same_line()
    Imgui.push_id(self.__class_name .. '_' .. CLEAR_BUFF_BAR_BUTTON_LOC_ID:upper())
    local clear_bar = Imgui.button(mod:localize(CLEAR_BUFF_BAR_BUTTON_LOC_ID))
    Imgui.pop_id()

    Imgui.same_line()
    local delete_bar = Imgui.button(mod:localize(DELETE_BUFF_BAR_BUTTON_LOC_ID))

    if self._selected_bar_index then
        local assignments_changed = false

        if not table.is_nil_or_empty(self._buffs_data) and (clear_bar or delete_bar) then
            local selected_bar = self._bars[self._selected_bar_index]
            for _, data in pairs(self._buffs_data) do
                if data.bar_name == selected_bar then
                    data.bar_name = ''
                    assignments_changed = true
                end
            end

            if clear_bar then
                self._selected_bar_index = nil
            end
        end

        if assignments_changed then
            mod:bump_buffs_data_revision()
        end

        if delete_bar then
            local deleted_bar = self._bars[self._selected_bar_index]
            table.remove(self._bars, self._selected_bar_index)
            mod:set(BARS_SETTING_ID, self._bars)
            -- Drop the deleted bar's config so it can't resurrect on a name reuse.
            if deleted_bar ~= nil and self._bar_configs[deleted_bar] ~= nil then
                self._bar_configs[deleted_bar] = nil
                self:_save_bar_configs()
            end
            self._selected_bar_index = nil
            self:_mark_dirty()
        elseif assignments_changed then
            self:_mark_dirty()
        end
    end
end

function BuffBarsComponent:_update_bar_windows()
    if self._bars == nil or #self._bars == 0 then
        return
    end

    self:_sync_dirty_state()
    if self._data_is_dirty then
        self:_rebuild_cache()
    end

    for _, bar in ipairs(self._bars) do
        local bar_ui_id = string.to_pascal_case(bar, ' ')
        Imgui.push_id(('%s_%s'):format(self.__class_name, bar_ui_id))
        if Imgui.collapsing_header(bar) then
            self:_update_bar_config_controls(bar)
            Imgui.separator()

            local sorted_data = self._cached_bar_data[bar]
            local window_id = ('%s_%s'):format(self.__class_name, bar_ui_id:upper())
            Imgui.begin_child_window(window_id, UiSettings.BAR_WINDOW_SIZE[1], UiSettings.BAR_WINDOW_SIZE[2], true,
                'always_auto_resize', 'horizontal_scrollbar')

            if sorted_data and #sorted_data > 0 then
                _update_buffs(window_id, sorted_data)
            end

            Imgui.end_child_window()
        end
        Imgui.pop_id()
    end
end

-- -------------------------------
-- ------- Public Functions ------
-- -------------------------------

function BuffBarsComponent:update()
    self:_update_create_bar()
    self:_update_clear_or_delete_bar()
    self:_update_bar_windows()
end

return BuffBarsComponent
