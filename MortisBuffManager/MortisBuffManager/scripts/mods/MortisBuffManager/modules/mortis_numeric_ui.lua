-- Keep DMF's native numeric editor and expose its input box while idle.
local mod = get_mod("MortisBuffManager")
local Numeric = {}
local fields = { mortis_buff_limit = true, mortis_kill_horde = true, mortis_kill_special = true,
    mortis_kill_elite = true, mortis_kill_boss = true, mortis_kill_weakened_boss = true, mortis_kill_captain = true }
local function maximum() return mod._settings.mortis_mode == "draft" and 10 or 99 end
local function fixed() return mod:is_enabled() and mod._settings.mortis_mode == "draft" end
function Numeric.configure(entry)
    if entry.setting_id ~= "mortis_buff_limit" or entry._mbm_limit then return end
    entry._mbm_limit = true
    entry._mbm_disabled = entry.disabled
    local get_value, activate = entry.get_function, entry.on_activated
    entry.get_function = function(...)
        if fixed() then return 10 end
        return get_value(...)
    end
    entry.on_activated = function(value, ...)
        if fixed() then return end
        return activate(math.clamp(value, 0, maximum()), ...)
    end
    entry.max_value = maximum()
    entry.disabled = entry._mbm_disabled or fixed()
end
function Numeric.sync_limit(view, widget)
    local content, entry = widget.content, widget.content.entry
    if not entry or entry.setting_id ~= "mortis_buff_limit" then return end
    Numeric.configure(entry)
    local mode = mod._settings.mortis_mode or "preselect"
    entry.max_value = maximum()
    entry.disabled = entry._mbm_disabled or fixed()
    content.text = mod:localize("mortis_limit_" .. mode)
    if widget._mbm_mode ~= mode or fixed() then
        -- Drop stale typed/dragged values before DMF's click-away commit path.
        content.is_writing, content.numeric_input_was_writing = false, false
        content.drag_active, content.drag_previously_active, content.exclusive_focus = false, false, false
        content.input_text = string.format(content.numeric_number_format, entry.get_function(entry) or entry.default_value)
        content.display_text = content.input_text
        content.scroll_add = nil
        for _, name in ipairs({ "hotspot", "input_hotspot" }) do
            local hotspot = content[name]
            if hotspot then hotspot.on_pressed = nil; hotspot.is_selected = false; hotspot.disabled = entry.disabled end
        end
        if view._selected_settings_widget == widget then view._selected_settings_widget = nil; view.is_text_input_focused = false end
    end
    content.disabled = entry.disabled
    widget._mbm_mode = mode
end
function Numeric.decorate(widget, config)
    if not widget or not fields[config.setting_id] or not widget.content.input_hotspot then return end
    widget._mbm_numeric = true
    for _, pass in ipairs(widget.passes) do
        if pass.style_id == "background" or pass.style_id == "baseline" then
            local original = pass.visibility_function
            pass.visibility_function = function(content, style)
                if mod:is_enabled() then return true end
                return not original or original(content, style)
            end
        end
    end
end
function Numeric.cancel(view, input)
    local widget = view._selected_settings_widget
    if not mod:is_enabled() or not widget or not widget._mbm_numeric or not input or not input:get("back") then return end
    local content = widget.content
    if not content.is_writing then return end
    local entry = content.entry
    -- Native finish_editing still clears focus, selection and validation.
    -- Restoring the current value first makes Esc a cancel rather than a commit.
    content.input_text = string.format(content.numeric_number_format, entry.get_function(entry) or entry.default_value)
end
mod:hook("DMFOptionsView", "_create_settings_widget_from_config", function(func, view, config, ...)
    Numeric.configure(config)
    local widget, alignment = func(view, config, ...)
    Numeric.decorate(widget, config)
    if widget and widget._mbm_numeric then
        view._mbm_numeric_widgets = view._mbm_numeric_widgets or setmetatable({}, { __mode = "k" })
        view._mbm_numeric_widgets[widget] = true
        Numeric.sync_limit(view, widget)
    end
    return widget, alignment
end)
mod:hook("DMFOptionsView", "update", function(func, view, dt, t, input, ...)
    for widget in pairs(view._mbm_numeric_widgets or {}) do
        Numeric.sync_limit(view, widget)
    end
    Numeric.cancel(view, input)
    return func(view, dt, t, input, ...)
end)
return Numeric
