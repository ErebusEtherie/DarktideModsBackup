--[[
    peril_history_view.lua
    Scrollable list of past peril sessions.
    Uses overlay_offscreen viewport (same as scoreboard/uptime mods) to
    render above the character select and other underlying game UI.
--]]

local mod = get_mod("peril_tracker")

local ScriptWorld            = mod:original_require("scripts/foundation/utilities/script_world")
local UIRenderer             = mod:original_require("scripts/managers/ui/ui_renderer")
local UIWidget               = mod:original_require("scripts/managers/ui/ui_widget")
local UIWidgetGrid           = mod:original_require("scripts/ui/widget_logic/ui_widget_grid")
local ViewElementInputLegend = mod:original_require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local UIFontSettings         = mod:original_require("scripts/managers/ui/ui_font_settings")

local CHART_VIEW_NAME   = "peril_chart_view"
local HISTORY_VIEW_NAME = "peril_history_view"

local PerilHistoryView = class("PerilHistoryView", "BaseView")

-- ===== Helpers =====

local function format_timestamp(ts)
    if not ts then return "unknown date" end
    local ok, result = pcall(function()
        local t = mod.lib_os.date("*t", ts)
        return string.format("%04d-%02d-%02d %02d:%02d", t.year, t.month, t.day, t.hour, t.min)
    end)
    return ok and result or "unknown date"
end

local function in_combat(t, combats)
    for _, c in ipairs(combats) do
        if t >= c.start_time and t <= c.end_time then return true end
    end
    return false
end

local function session_to_entry(session)
    local n          = session.samples and #session.samples or 0
    local avg        = 0
    local peak       = 0
    local combat_sum = 0
    local combat_n   = 0
    local combats    = session.combats or {}

    for _, s in ipairs(session.samples or {}) do
        avg  = avg + s.peril
        peak = math.max(peak, s.peril)
        if in_combat(s.time, combats) then
            combat_sum = combat_sum + s.peril
            combat_n   = combat_n + 1
        end
    end
    if n > 0 then avg = avg / n end
    local combat_avg = combat_n > 0 and (combat_sum / combat_n) or nil

    local survived = 0
    local fatal    = 0
    for _, ov in ipairs(session.overloads or {}) do
        if ov.fatal then fatal = fatal + 1 else survived = survived + 1 end
    end

    local map    = session.map or "Unknown Map"
    local player = session.player or ""
    local date   = format_timestamp(session.timestamp)
    local dur_m  = math.floor((session.duration or 0) / 60)
    local dur_s  = math.floor((session.duration or 0) % 60)

    local overload_str = ""
    if survived + fatal > 0 then
        overload_str = string.format("  |  OL: %d survived / %d fatal", survived, fatal)
    end

    local avg_str
    if combat_avg then
        avg_str = string.format("Avg: %.1f%% (Combat: %.1f%%)", avg, combat_avg)
    else
        avg_str = string.format("Avg: %.1f%%", avg)
    end

    return {
        widget_type = "session_button",
        title       = string.format("%s  |  %s", map, date),
        subtitle    = string.format(
            "%s  |  %dm %ds  |  %s  Peak: %.1f%%  Samples: %d%s",
            player, dur_m, dur_s, avg_str, peak, n, overload_str
        ),
        session = session,
    }
end

-- ===== Init =====

PerilHistoryView.init = function(self, settings_arg)
    self._definitions      = mod:io_dofile("peril_tracker/scripts/mods/peril_tracker/history/peril_history_view_definitions")
    self._blueprints       = mod:io_dofile("peril_tracker/scripts/mods/peril_tracker/history/peril_history_view_blueprints")
    self._view_settings    = mod:io_dofile("peril_tracker/scripts/mods/peril_tracker/history/peril_history_view_settings")
    self._selected_session = nil
    self._entry_widgets    = {}
    self._entries_grid     = nil
    PerilHistoryView.super.init(self, self._definitions, settings_arg)
    self._pass_draw = false
    self:_setup_offscreen_gui()
end

PerilHistoryView._setup_offscreen_gui = function(self)
    local ui_manager    = Managers.ui
    local class_name    = self.__class_name
    local timer_name    = "ui"
    local world_layer   = 10
    local world_name    = class_name .. "_ui_offscreen_world"
    local view_name     = self.view_name
    self._offscreen_world = ui_manager:create_world(world_name, world_layer, timer_name, view_name)
    local shading_env   = self._view_settings.shading_environment
    local viewport_name = class_name .. "_ui_offscreen_world_viewport"
    local viewport_type = "overlay_offscreen"
    local viewport_layer = 1
    self._offscreen_viewport = ui_manager:create_viewport(
        self._offscreen_world, viewport_name, viewport_type, viewport_layer, shading_env
    )
    self._offscreen_viewport_name = viewport_name
    self._ui_offscreen_renderer   = ui_manager:create_renderer(
        class_name .. "_ui_offscreen_renderer", self._offscreen_world
    )
end

-- ===== on_enter =====

PerilHistoryView.on_enter = function(self)
    PerilHistoryView.super.on_enter(self)
    self:_setup_input_legend()
    local ok, err = pcall(function() self:_load_entries(false) end)
    if not ok then
        mod:echo("Peril history load error: " .. tostring(err))
    end
end

PerilHistoryView._setup_input_legend = function(self)
    self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 10)
    for _, leg in ipairs(self._definitions.legend_inputs) do
        local cb  = leg.on_pressed_callback and callback(self, leg.on_pressed_callback)
        local vis = nil
        if leg.display_name == "loc_delete_entry" then
            vis = function() return self._selected_session ~= nil end
        end
        self._input_legend_element:add_entry(leg.display_name, leg.input_action, vis, cb, leg.alignment)
    end
end

-- ===== Load entries =====

PerilHistoryView._load_entries = function(self, force_scan)
    if self._entry_widgets then
        for _, w in ipairs(self._entry_widgets) do
            pcall(function() self:_unregister_widget_name(w.name) end)
        end
    end
    self._entry_widgets = {}
    self._entries_grid  = nil

    local sessions = mod:get_all_sessions(force_scan) or {}
    local entries  = {}
    for _, s in ipairs(sessions) do
        entries[#entries + 1] = session_to_entry(s)
    end

    table.sort(entries, function(a, b)
        return (a.session.timestamp or 0) > (b.session.timestamp or 0)
    end)

    if #entries == 0 then
        self:_show_no_sessions_message()
        return
    end

    self._entry_widgets = self:_build_entry_widgets(entries, "grid_content_pivot")

    if #self._entry_widgets > 0 then
        self._entries_grid = UIWidgetGrid:new(
            self._entry_widgets,
            self._entry_widgets,
            self._ui_scenegraph,
            "background",
            "down",
            self._view_settings.grid_spacing,
            nil,
            true
        )
        self._entries_grid:set_render_scale(self._render_scale)

        local scrollbar = self._widgets_by_name.scrollbar
        if scrollbar then
            self._entries_grid:assign_scrollbar(scrollbar, "grid_content_pivot", "background")
            self._entries_grid:set_scrollbar_progress(0)
        end
    end
end

PerilHistoryView._show_no_sessions_message = function(self)
    local def = UIWidget.create_definition({
        {
            pass_type = "text",
            value     = "No peril sessions recorded yet.\nPlay a mission as Psyker first.",
            style     = {
                font_type                 = "proxima_nova_bold",
                font_size                 = 18,
                text_color                = { 200, 180, 180, 180 },
                text_horizontal_alignment = "left",
                text_vertical_alignment   = "top",
                size                      = { 460, 100 },
                offset                    = { 0, 0 },
            },
        },
    }, "grid_content_pivot")
    local widget = self:_create_widget("no_sessions_msg", def)
    self._entry_widgets = { widget }
end

PerilHistoryView._build_entry_widgets = function(self, entries, scenegraph_id)
    local widgets    = {}
    local defs_cache = {}

    for i, entry in ipairs(entries) do
        local wtype    = entry.widget_type
        local template = self._blueprints[wtype]
        if template then
            if not defs_cache[wtype] then
                defs_cache[wtype] = UIWidget.create_definition(
                    template.pass_template, scenegraph_id, nil, template.size
                )
            end
            local widget = self:_create_widget(scenegraph_id .. "_widget_" .. i, defs_cache[wtype])
            if template.init then
                template.init(self, widget, entry, "cb_on_entry_pressed")
            end
            widgets[#widgets + 1] = widget
        end
    end

    return widgets
end

-- ===== Callbacks =====

PerilHistoryView.cb_on_entry_pressed = function(self, widget, entry)
    self._selected_session  = entry.session
    mod._last_peril_session = entry.session

    if Managers.ui:view_active(CHART_VIEW_NAME) and not Managers.ui:is_view_closing(CHART_VIEW_NAME) then
        Managers.ui:close_view(CHART_VIEW_NAME, true)
        self._pending_chart_open = true
    else
        Managers.ui:open_view(CHART_VIEW_NAME, nil, false, false, nil, nil)
    end
end

PerilHistoryView.cb_on_back_pressed = function(self)
    Managers.ui:close_view(HISTORY_VIEW_NAME)
end

PerilHistoryView.cb_delete_pressed = function(self)
    if not self._selected_session then return end

    -- Close the chart view first so it releases any file references,
    -- then delete once it has fully closed.
    if Managers.ui:view_active(CHART_VIEW_NAME) and not Managers.ui:is_view_closing(CHART_VIEW_NAME) then
        Managers.ui:close_view(CHART_VIEW_NAME, true)
    end

    local success = mod:delete_peril_session(self._selected_session)
    if success then
        self._selected_session = nil
        local ok, err = pcall(function() self:_load_entries(true) end)
        if not ok then mod:echo("[PT] Error reloading after delete: " .. tostring(err)) end
    else
        mod:echo("[PT] Delete failed — could not remove file.")
    end
end

PerilHistoryView.cb_reload_cache_pressed = function(self)
    self._selected_session = nil
    local ok, err = pcall(function() self:_load_entries(true) end)
    if not ok then mod:echo("Error reloading: " .. tostring(err)) end
end

-- ===== Update =====

PerilHistoryView.update = function(self, dt, t, input_service)
    -- Open chart once any previous chart has fully closed
    if self._pending_chart_open then
        if not Managers.ui:view_active(CHART_VIEW_NAME) then
            self._pending_chart_open = false
            Managers.ui:open_view(CHART_VIEW_NAME, nil, false, false, nil, nil)
        end
    end

    if self._entries_grid then
        self._entries_grid:update(dt, t, input_service)
    end
    if self._entry_widgets then
        for _, widget in ipairs(self._entry_widgets) do
            local hotspot = widget.content and widget.content.hotspot
            if hotspot and hotspot.is_focused then
                hotspot.is_selected = true
            end
        end
    end
    return PerilHistoryView.super.update(self, dt, t, input_service)
end

-- ===== Draw =====

PerilHistoryView.draw = function(self, dt, t, input_service, layer)
    -- Static widgets (background, title, etc.) via the standard renderer
    self:_draw_elements(dt, t, self._ui_renderer, self._render_settings, input_service)

    -- Scrollable entry list via the offscreen renderer (renders above all game UI)
    if self._entry_widgets and #self._entry_widgets > 0 then
        local grid_interaction = self._widgets_by_name.grid_interaction
        self:_draw_grid(self._entries_grid, self._entry_widgets, grid_interaction, dt, t, input_service)
    end

    PerilHistoryView.super.draw(self, dt, t, input_service, layer)
end

PerilHistoryView._draw_grid = function(self, grid, widgets, interaction_widget, dt, t, input_service)
    local render_settings = self._render_settings
    local ui_renderer     = self._ui_offscreen_renderer
    local ui_scenegraph   = self._ui_scenegraph

    UIRenderer.begin_pass(ui_renderer, ui_scenegraph, input_service, dt, render_settings)
    for _, widget in ipairs(widgets) do
        local visible = not grid or grid:is_widget_visible(widget)
        if visible then
            UIWidget.draw(widget, ui_renderer)
        end
    end
    UIRenderer.end_pass(ui_renderer)
end

-- ===== on_exit =====

PerilHistoryView.on_exit = function(self)
    if self._input_legend_element then
        self:_remove_element("input_legend")
        self._input_legend_element = nil
    end

    -- If the chart is open when history closes (e.g. via F9 or ESC),
    -- close it too so nothing is left orphaned
    if Managers.ui:view_active(CHART_VIEW_NAME) and not Managers.ui:is_view_closing(CHART_VIEW_NAME) then
        Managers.ui:close_view(CHART_VIEW_NAME, true)
    end

    if self._ui_offscreen_renderer then
        Managers.ui:destroy_renderer(self.__class_name .. "_ui_offscreen_renderer")
        ScriptWorld.destroy_viewport(self._offscreen_world, self._offscreen_viewport_name)
        Managers.ui:destroy_world(self._offscreen_world)
        self._ui_offscreen_renderer   = nil
        self._offscreen_viewport      = nil
        self._offscreen_viewport_name = nil
        self._offscreen_world         = nil
    end

    PerilHistoryView.super.on_exit(self)
end

return PerilHistoryView
