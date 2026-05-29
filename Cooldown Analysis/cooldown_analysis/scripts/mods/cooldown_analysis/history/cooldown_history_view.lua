--[[
    cooldown_history_view.lua

    Scrollable list of past cooldown analysis sessions.
    Clicking a session loads it into the chart view on the right.
    Uses overlay_offscreen viewport, matching the scoreboard/uptime/peril pattern.
--]]

local mod = get_mod("cooldown_analysis")

local ScriptWorld            = mod:original_require("scripts/foundation/utilities/script_world")
local UIRenderer             = mod:original_require("scripts/managers/ui/ui_renderer")
local UIWidget               = mod:original_require("scripts/managers/ui/ui_widget")
local UIWidgetGrid           = mod:original_require("scripts/ui/widget_logic/ui_widget_grid")
local ViewElementInputLegend = mod:original_require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local UIFontSettings         = mod:original_require("scripts/managers/ui/ui_font_settings")

local CHART_VIEW_NAME   = "cooldown_chart_view"
local HISTORY_VIEW_NAME = "cooldown_history_view"

local CooldownHistoryView = class("CooldownHistoryView", "BaseView")

-- ===== Helpers =====

local function format_timestamp(ts)
    if not ts then return "unknown date" end
    local ok, result = pcall(function()
        local t = mod.lib_os.date("*t", ts)
        return string.format("%04d-%02d-%02d %02d:%02d", t.year, t.month, t.day, t.hour, t.min)
    end)
    return ok and result or "unknown date"
end

-- Compute session aggregate stats for display in the list entry subtitle
local function session_stats(session)
    local uses       = session.uses or {}
    local count      = #uses
    local flagged    = 0
    local n, sum     = 0, 0
    local min_d, max_d = math.huge, 0
    local souls_sum, souls_n = 0, 0

    for _, u in ipairs(uses) do
        if u.flagged then
            flagged = flagged + 1
        else
            n   = n + 1
            sum = sum + u.duration
            if u.duration < min_d then min_d = u.duration end
            if u.duration > max_d then max_d = u.duration end
        end
        if u.souls_stacks and u.souls_stacks > 0 then
            souls_sum = souls_sum + math.min(6, u.souls_stacks)
            souls_n   = souls_n + 1
        end
    end

    return {
        count     = count,
        flagged   = flagged,
        valid     = n,
        avg       = n > 0 and (sum / n) or nil,
        min       = n > 0 and min_d or nil,
        max       = n > 0 and max_d or nil,
        souls_avg = souls_n > 0 and (souls_sum / souls_n) or nil,
    }
end

local function session_to_entry(session)
    local map   = mod.lib_missions.localize_name(session.map) or session.map or "Unknown Map"
    local date  = format_timestamp(session.timestamp)
    local plr   = session.player or ""
    local arch  = session.archetype or "unknown"
    local arch_display = arch:sub(1,1):upper() .. arch:sub(2)
    local dur_m = math.floor((session.duration or 0) / 60)
    local dur_s = math.floor((session.duration or 0) % 60)

    local st    = session_stats(session)

    local cd_str
    if st.valid > 0 then
        cd_str = string.format(
            "Uses: %d  |  Avg: %.1fs  |  Min: %.1fs  |  Max: %.1fs",
            st.count, st.avg, st.min, st.max
        )
        if st.flagged > 0 then
            cd_str = cd_str .. string.format("  |  Flagged: %d", st.flagged)
        end
    elseif st.count > 0 then
        cd_str = string.format("Uses: %d  (all flagged)", st.count)
    else
        cd_str = "No completed uses"
    end

    if session.is_psyker and st.souls_avg then
        cd_str = cd_str .. string.format("  |  Avg souls: %.1f", st.souls_avg)
    end

    return {
        widget_type = "session_button",
        title       = string.format("%s  |  %s", map, date),
        subtitle    = string.format("%s  |  %s  |  %dm %ds  |  %s",
                        plr, arch_display, dur_m, dur_s, cd_str),
        session     = session,
    }
end

-- ===== Init =====

CooldownHistoryView.init = function(self, settings_arg)
    self._definitions      = mod:io_dofile("cooldown_analysis/scripts/mods/cooldown_analysis/history/cooldown_history_view_definitions")
    self._blueprints       = mod:io_dofile("cooldown_analysis/scripts/mods/cooldown_analysis/history/cooldown_history_view_blueprints")
    self._view_settings    = mod:io_dofile("cooldown_analysis/scripts/mods/cooldown_analysis/history/cooldown_history_view_settings")
    self._selected_session = nil
    self._entry_widgets    = {}
    self._entries_grid     = nil
    CooldownHistoryView.super.init(self, self._definitions, settings_arg)
    self._pass_draw = false
    self:_setup_offscreen_gui()
end

CooldownHistoryView._setup_offscreen_gui = function(self)
    local ui_manager    = Managers.ui
    local class_name    = self.__class_name
    local timer_name    = "ui"
    local world_layer   = 10
    local world_name    = class_name .. "_ui_offscreen_world"
    local view_name     = self.view_name
    self._offscreen_world = ui_manager:create_world(world_name, world_layer, timer_name, view_name)
    local shading_env    = self._view_settings.shading_environment
    local viewport_name  = class_name .. "_ui_offscreen_world_viewport"
    local viewport_type  = "overlay_offscreen"
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

CooldownHistoryView.on_enter = function(self)
    CooldownHistoryView.super.on_enter(self)
    self:_setup_input_legend()
    local ok, err = pcall(function() self:_load_entries(false) end)
    if not ok then
        mod:echo("[CA] History load error: " .. tostring(err))
    end
end

CooldownHistoryView._setup_input_legend = function(self)
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

CooldownHistoryView._load_entries = function(self, force_scan)
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

CooldownHistoryView._show_no_sessions_message = function(self)
    local def = UIWidget.create_definition({
        {
            pass_type = "text",
            value     = "No cooldown sessions recorded yet.\nPlay a mission first.",
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

CooldownHistoryView._build_entry_widgets = function(self, entries, scenegraph_id)
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

CooldownHistoryView.cb_on_entry_pressed = function(self, widget, entry)
    self._selected_session      = entry.session
    mod._last_cooldown_session  = entry.session

    if Managers.ui:view_active(CHART_VIEW_NAME) and not Managers.ui:is_view_closing(CHART_VIEW_NAME) then
        Managers.ui:close_view(CHART_VIEW_NAME, true)
        self._pending_chart_open = true
    else
        Managers.ui:open_view(CHART_VIEW_NAME, nil, false, false, nil, nil)
    end
end

CooldownHistoryView.cb_on_back_pressed = function(self)
    Managers.ui:close_view(HISTORY_VIEW_NAME)
end

CooldownHistoryView.cb_delete_pressed = function(self)
    if not self._selected_session then return end

    -- Close the chart view first so it releases any file references,
    -- then delete once it has fully closed.
    if Managers.ui:view_active(CHART_VIEW_NAME) and not Managers.ui:is_view_closing(CHART_VIEW_NAME) then
        Managers.ui:close_view(CHART_VIEW_NAME, true)
    end

    local success = mod:delete_cooldown_session(self._selected_session)
    if success then
        self._selected_session = nil
        local ok, err = pcall(function() self:_load_entries(true) end)
        if not ok then mod:echo("[CA] Error reloading after delete: " .. tostring(err)) end
    else
        mod:echo("[CA] Delete failed — could not remove file.")
    end
end

CooldownHistoryView.cb_reload_cache_pressed = function(self)
    self._selected_session = nil
    local ok, err = pcall(function() self:_load_entries(true) end)
    if not ok then mod:echo("[CA] Error reloading: " .. tostring(err)) end
end

-- ===== Update =====

CooldownHistoryView.update = function(self, dt, t, input_service)
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
    return CooldownHistoryView.super.update(self, dt, t, input_service)
end

-- ===== Draw =====

CooldownHistoryView.draw = function(self, dt, t, input_service, layer)
    self:_draw_elements(dt, t, self._ui_renderer, self._render_settings, input_service)

    if self._entry_widgets and #self._entry_widgets > 0 then
        local grid_interaction = self._widgets_by_name.grid_interaction
        self:_draw_grid(self._entries_grid, self._entry_widgets, grid_interaction, dt, t, input_service)
    end

    CooldownHistoryView.super.draw(self, dt, t, input_service, layer)
end

CooldownHistoryView._draw_grid = function(self, grid, widgets, interaction_widget, dt, t, input_service)
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

CooldownHistoryView.on_exit = function(self)
    if self._input_legend_element then
        self:_remove_element("input_legend")
        self._input_legend_element = nil
    end

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

    CooldownHistoryView.super.on_exit(self)
end

return CooldownHistoryView
