--[[
    peril_view.lua
    Reads session data directly from mod._last_peril_session rather than
    relying on context being passed through open_view (which doesn't work
    reliably for data passing).
--]]

local mod      = get_mod("peril_tracker")
local Defs     = mod:io_dofile("peril_tracker/scripts/mods/peril_tracker/view/peril_view_definitions")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")

local ViewElementInputLegend = mod:original_require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")

local PerilChartView = class("PerilChartView", "BaseView")

-- ===== Colour helpers =====

local function peril_color(pct)
    if pct < 50 then
        return { 210,  90, 140, 240 }
    elseif pct < 75 then
        return { 220, 230, 160,  50 }
    else
        return { 230, 230,  55,  55 }
    end
end

local COLOR_AVERAGE         = { 255, 255, 255, 255 }   -- white: overall average
local COLOR_COMBAT_AVERAGE  = { 255, 230, 140,  30 }   -- orange: combat average
local COLOR_GRIDLINE        = {  60, 160, 160, 160 }
local COLOR_BASELINE        = { 120, 160, 160, 160 }
local COLOR_WARP_NEXUS      = { 180,  50, 210, 210 }   -- teal

-- Returns true if mission time t falls within any combat window
local function in_combat(t, combats)
    for _, c in ipairs(combats) do
        if t >= c.start_time and t <= c.end_time then return true end
    end
    return false
end

-- ===== Widget builders =====

local function make_solid_background(view)
    -- Solid dark overlay to prevent bleed-through from underlying screens
    local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")
    local def = UIWidget.create_definition({
        {
            pass_type = "rect",
            style     = {
                color  = { 230, 0, 0, 0 },
                size   = { 1920, 1080 },
                offset = { 0, 0 },
            },
        },
    }, "screen")
    return view:_create_widget("solid_bg", def)
end

local function make_background_widget(view)
    local W, H = Defs.panel_w, Defs.panel_h
    local def = UIWidget.create_definition({
        { pass_type = "rect", style = { color = { 230, 8, 8, 12 },    size = { W, H } } },
        { pass_type = "rect", style = { color = { 180, 80, 80, 100 }, size = { W, 2 }, offset = { 0, 0 } } },
        { pass_type = "rect", style = { color = { 180, 80, 80, 100 }, size = { W, 2 }, offset = { 0, H - 2 } } },
        { pass_type = "rect", style = { color = { 180, 80, 80, 100 }, size = { 2, H }, offset = { 0, 0 } } },
        { pass_type = "rect", style = { color = { 180, 80, 80, 100 }, size = { 2, H }, offset = { W - 2, 0 } } },
    }, "container")
    return view:_create_widget("background", def)
end

local function make_title_widget(view)
    local def = UIWidget.create_definition({
        {
            pass_type = "text",
            value     = "Peril Over Time",
            style     = {
                font_type                 = "proxima_nova_bold",
                font_size                 = 28,
                text_color                = { 255, 200, 160, 255 },
                text_horizontal_alignment = "left",
                text_vertical_alignment   = "center",
                size                      = { Defs.panel_w - 50, 50 },
                offset                    = { 0, 0 },
            },
        },
    }, "title_area")
    return view:_create_widget("title", def)
end

local function make_yaxis_widget(view)
    local H = Defs.chart_h
    local function entry(label, y_offset)
        return {
            pass_type = "text",
            value     = label,
            style     = {
                font_type                 = "proxima_nova_bold",
                font_size                 = 14,
                text_color                = { 200, 180, 180, 180 },
                text_horizontal_alignment = "right",
                size                      = { 40, 20 },
                offset                    = { 0, y_offset },
            },
        }
    end
    local def = UIWidget.create_definition({
        entry("100%", 0),
        entry("75%",  math.floor(H * 0.25) - 10),
        entry("50%",  math.floor(H * 0.50) - 10),
        entry("25%",  math.floor(H * 0.75) - 10),
        entry("0%",   H - 10),
    }, "yaxis_scene")
    return view:_create_widget("yaxis", def)
end

local COLOR_OVERLOAD_SURVIVED = { 255,  50, 200,  50 }   -- green
local COLOR_OVERLOAD_FATAL    = { 255, 180,  50, 220 }   -- purple

local function make_chart_widget(view, samples, overloads, combats)
    local chart_w = Defs.chart_w
    local chart_h = Defs.chart_h
    local n       = #samples
    local template = {}

    template[#template + 1] = {
        pass_type = "rect",
        style     = { color = { 180, 5, 5, 8 }, size = { chart_w, chart_h } },
    }

    for _, frac in ipairs({ 0.25, 0.50, 0.75 }) do
        template[#template + 1] = {
            pass_type = "rect",
            style     = { color = COLOR_GRIDLINE, size = { chart_w, 1 },
                          offset = { 0, math.floor(chart_h - frac * chart_h) } },
        }
    end

    template[#template + 1] = {
        pass_type = "rect",
        style     = { color = COLOR_BASELINE, size = { chart_w, 1 },
                      offset = { 0, chart_h - 1 } },
    }

    local mission_duration = 0
    if n > 0 then
        local display_cols = math.min(n, chart_w)
        local step         = n / display_cols
        local col_w        = math.max(1, math.floor(chart_w / display_cols))
        local sum          = 0
        local combat_sum   = 0
        local combat_n     = 0

        for _, s in ipairs(samples) do
            sum = sum + s.peril
            if s.time > mission_duration then mission_duration = s.time end
            if in_combat(s.time, combats) then
                combat_sum = combat_sum + s.peril
                combat_n   = combat_n + 1
            end
        end
        local avg        = sum / n
        local combat_avg = combat_n > 0 and (combat_sum / combat_n) or nil

        for i = 1, display_cols do
            local src_idx = math.min(n, math.max(1, math.floor((i - 0.5) * step + 0.5)))
            local pct     = math.min(100, math.max(0, samples[src_idx].peril))
            local bar_h   = math.max(1, math.floor(pct / 100 * chart_h))
            local x       = math.floor((i - 1) * chart_w / display_cols)
            template[#template + 1] = {
                pass_type = "rect",
                style     = {
                    color  = peril_color(pct),
                    size   = { col_w, bar_h },
                    offset = { x, chart_h - bar_h },
                },
            }
        end

        -- Overall average line (white)
        local avg_y = math.floor(chart_h - (avg / 100) * chart_h)
        template[#template + 1] = {
            pass_type = "rect",
            style     = { color = COLOR_AVERAGE, size = { chart_w, 2 },
                          offset = { 0, avg_y } },
        }

        -- Combat average line (orange), only if we have combat samples
        if combat_avg then
            local combat_avg_y = math.floor(chart_h - (combat_avg / 100) * chart_h)
            template[#template + 1] = {
                pass_type = "rect",
                style     = { color = COLOR_COMBAT_AVERAGE, size = { chart_w, 2 },
                              offset = { 0, combat_avg_y } },
            }
        end
    end

    -- Warp Nexus stack breakpoints at 20/40/60/80% — drawn after bars so they appear on top
    if mod:get("show_warp_nexus_lines") then
        for _, frac in ipairs({ 0.20, 0.40, 0.60, 0.80 }) do
            template[#template + 1] = {
                pass_type = "rect",
                style     = { color = COLOR_WARP_NEXUS, size = { chart_w, 1 },
                              offset = { 0, math.floor(chart_h - frac * chart_h) } },
            }
        end
    end

    -- Draw overload markers as vertical lines spanning the full chart height.
    -- Yellow = survived, Red = fatal. Drawn on top of bars.
    if overloads and mission_duration > 0 then
        for _, ov in ipairs(overloads) do
            local x = math.floor((ov.time / mission_duration) * (chart_w - 1))
            x = math.min(chart_w - 2, math.max(0, x))
            local color = ov.fatal and COLOR_OVERLOAD_FATAL or COLOR_OVERLOAD_SURVIVED
            -- Draw a 2px wide full-height marker
            template[#template + 1] = {
                pass_type = "rect",
                style     = {
                    color  = color,
                    size   = { 2, chart_h },
                    offset = { x, 0 },
                },
            }
        end
    end

    local def = UIWidget.create_definition(template, Defs.chart_scene)
    return view:_create_widget("peril_chart", def)
end

local function make_no_data_widget(view)
    local def = UIWidget.create_definition({
        {
            pass_type = "text",
            value     = "No peril data recorded. Play a mission as Psyker first.",
            style     = {
                font_type                 = "proxima_nova_bold",
                font_size                 = 18,
                text_color                = { 200, 180, 180, 180 },
                text_horizontal_alignment = "center",
                text_vertical_alignment   = "center",
                size                      = { Defs.chart_w, Defs.chart_h },
                offset                    = { 0, 0 },
            },
        },
    }, Defs.chart_scene)
    return view:_create_widget("no_data", def)
end

local function make_label_widget(view, samples, overloads, combats)
    local n          = #samples
    local avg        = 0
    local peak       = 0
    local combat_sum = 0
    local combat_n   = 0
    for _, s in ipairs(samples) do
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
    for _, ov in ipairs(overloads or {}) do
        if ov.fatal then fatal = fatal + 1 else survived = survived + 1 end
    end

    local line1
    if combat_avg then
        line1 = string.format(
            "Avg: %.1f%%  (Combat: %.1f%%)    Peak: %.1f%%    Samples: %d",
            avg, combat_avg, peak, n
        )
    else
        line1 = string.format("Avg: %.1f%%    Peak: %.1f%%    Samples: %d", avg, peak, n)
    end

    local line2 = string.format(
        "Overloads:  Survived: %d  |  Fatal: %d  |  Total: %d",
        survived, fatal, survived + fatal
    )

    local def = UIWidget.create_definition({
        {
            pass_type = "text",
            value     = line1,
            style     = {
                font_type                 = "proxima_nova_bold",
                font_size                 = 18,
                text_color                = { 255, 220, 200, 255 },
                text_horizontal_alignment = "left",
                text_vertical_alignment   = "top",
                size                      = { Defs.chart_w, 30 },
                offset                    = { 0, 0 },
            },
        },
        {
            pass_type = "text",
            value     = line2,
            style     = {
                font_type                 = "proxima_nova_bold",
                font_size                 = 16,
                text_color                = { 220, 200, 200, 200 },
                text_horizontal_alignment = "left",
                text_vertical_alignment   = "top",
                size                      = { Defs.chart_w, 30 },
                offset                    = { 0, 28 },
            },
        },
    }, Defs.label_scene)
    return view:_create_widget("peril_labels", def)
end

-- ===== View lifecycle =====

function PerilChartView:init(settings, context)
    self._definitions     = Defs
    self._widgets         = {}
    self._widgets_by_name = {}
    PerilChartView.super.init(self, Defs, settings)
    self._pass_input = true
end

function PerilChartView:on_enter()
    local session   = mod._last_peril_session
    local samples   = session and session.samples or {}
    local overloads = session and session.overloads or {}
    local combats   = session and session.combats or {}

    self._widgets[#self._widgets + 1] = make_background_widget(self)
    self._widgets[#self._widgets + 1] = make_title_widget(self)
    self._widgets[#self._widgets + 1] = make_yaxis_widget(self)

    if #samples == 0 then
        self._widgets[#self._widgets + 1] = make_no_data_widget(self)
    else
        self._widgets[#self._widgets + 1] = make_chart_widget(self, samples, overloads, combats)
        self._widgets[#self._widgets + 1] = make_label_widget(self, samples, overloads, combats)
    end

    -- Input legend so ESC shows as a visible hint
    self._input_legend = self:_add_element(ViewElementInputLegend, "input_legend", 10)
    self._input_legend:add_entry(
        "loc_settings_menu_close_menu", "back", nil,
        callback(self, "cb_on_back_pressed"), "left_alignment"
    )

    PerilChartView.super.on_enter(self)
end

function PerilChartView:cb_on_back_pressed()
    Managers.ui:close_view("peril_chart_view")
end

function PerilChartView:update(...)
    return PerilChartView.super.update(self, ...)
end

function PerilChartView:on_exit(...)
    if self._input_legend then
        self:_remove_element("input_legend")
        self._input_legend = nil
    end
    PerilChartView.super.on_exit(self, ...)
end

return PerilChartView
