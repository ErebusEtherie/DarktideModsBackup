--[[
    cooldown_view.lua

    Displays a bar chart of completed cooldown durations for a single session,
    plus aggregate statistics.

    Chart layout:
      - Each bar = one completed cooldown use
      - Bar height = duration (scaled to chart height)
      - Non-flagged bars: teal or souls-tinted (Psyker)
      - Flagged bars (<4s): amber/orange
      - White horizontal line = average of non-flagged uses
      - Y-axis labels: dynamic based on max duration

    Reads session data from mod._last_cooldown_session.
--]]

local mod      = get_mod("cooldown_analysis")
local Defs     = mod:io_dofile("cooldown_analysis/scripts/mods/cooldown_analysis/view/cooldown_view_definitions")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local ViewElementInputLegend = mod:original_require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")

local CooldownChartView = class("CooldownChartView", "BaseView")

-- ===== Colour constants =====

local COLOR_AVERAGE   = { 255, 255, 255, 255 }    -- white: non-flagged average line
local COLOR_GRIDLINE  = {  60, 160, 160, 160 }
local COLOR_BASELINE  = { 120, 160, 160, 160 }
local COLOR_FLAGGED   = { 220, 210, 110,  20 }    -- amber: flagged bar

-- ===== Session stats helper =====

local function compute_stats(uses)
    local count, flagged_count = #uses, 0
    local sum, n = 0, 0
    local min_dur, max_dur = math.huge, 0
    local souls_sum, souls_n = 0, 0
    local souls_by_count = { [0]=0, [1]=0, [2]=0, [3]=0, [4]=0, [5]=0, [6]=0 }

    for _, u in ipairs(uses) do
        if u.flagged then
            flagged_count = flagged_count + 1
        else
            n   = n + 1
            sum = sum + u.duration
            if u.duration < min_dur then min_dur = u.duration end
            if u.duration > max_dur then max_dur = u.duration end
        end
        -- Souls stats always include all uses (flagged or not)
        local s = math.min(6, math.max(0, u.souls_stacks or 0))
        souls_by_count[s] = (souls_by_count[s] or 0) + 1
        if u.souls_stacks and u.souls_stacks > 0 then
            souls_sum = souls_sum + u.souls_stacks
            souls_n   = souls_n + 1
        end
    end

    return {
        count        = count,
        flagged      = flagged_count,
        valid        = n,
        avg          = n > 0 and (sum / n) or nil,
        min          = n > 0 and min_dur or nil,
        max          = n > 0 and max_dur or nil,
        souls_avg    = souls_n > 0 and (souls_sum / souls_n) or nil,
        souls_by_count = souls_by_count,
    }
end

-- Determine a clean Y-axis ceiling: round max up to the nearest 5s, minimum 30s
local function y_max(stats)
    local raw = stats.max or 30
    if raw < 30 then raw = 30 end
    return math.ceil(raw / 5) * 5
end

-- ===== Widget builders =====

local function make_background_widget(view)
    local W, H = Defs.panel_w, Defs.panel_h
    local def = UIWidget.create_definition({
        { pass_type = "rect", style = { color = { 230, 8, 8, 12 },    size = { W, H } } },
        { pass_type = "rect", style = { color = { 180, 60, 60, 100 }, size = { W, 2 }, offset = { 0, 0 } } },
        { pass_type = "rect", style = { color = { 180, 60, 60, 100 }, size = { W, 2 }, offset = { 0, H - 2 } } },
        { pass_type = "rect", style = { color = { 180, 60, 60, 100 }, size = { 2, H }, offset = { 0, 0 } } },
        { pass_type = "rect", style = { color = { 180, 60, 60, 100 }, size = { 2, H }, offset = { W - 2, 0 } } },
    }, "container")
    return view:_create_widget("background", def)
end

local function make_title_widget(view, archetype)
    local arch_display = archetype and (archetype:sub(1,1):upper() .. archetype:sub(2)) or "Unknown"
    local def = UIWidget.create_definition({
        {
            pass_type = "text",
            value     = "Cooldown Analysis  —  " .. arch_display,
            style     = {
                font_type                 = "proxima_nova_bold",
                font_size                 = 28,
                text_color                = { 255, 180, 210, 255 },
                text_horizontal_alignment = "left",
                text_vertical_alignment   = "center",
                size                      = { Defs.panel_w - 50, 50 },
                offset                    = { 0, 0 },
            },
        },
    }, "title_area")
    return view:_create_widget("title", def)
end

local function make_yaxis_widget(view, max_y)
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
        entry(tostring(max_y) .. "s",                       0),
        entry(tostring(math.floor(max_y * 0.75)) .. "s",   math.floor(H * 0.25) - 10),
        entry(tostring(math.floor(max_y * 0.50)) .. "s",   math.floor(H * 0.50) - 10),
        entry(tostring(math.floor(max_y * 0.25)) .. "s",   math.floor(H * 0.75) - 10),
        entry("0s",                                         H - 10),
    }, "yaxis_scene")
    return view:_create_widget("yaxis", def)
end

local function make_chart_widget(view, uses, stats, is_psyker)
    local chart_w = Defs.chart_w
    local chart_h = Defs.chart_h
    local n       = #uses
    local max_y   = y_max(stats)
    local template = {}

    -- Chart background
    template[#template + 1] = {
        pass_type = "rect",
        style     = { color = { 180, 5, 5, 8 }, size = { chart_w, chart_h } },
    }

    -- Gridlines at 25%, 50%, 75%
    for _, frac in ipairs({ 0.25, 0.50, 0.75 }) do
        template[#template + 1] = {
            pass_type = "rect",
            style     = { color = COLOR_GRIDLINE, size = { chart_w, 1 },
                          offset = { 0, math.floor(chart_h - frac * chart_h) } },
        }
    end

    -- Baseline
    template[#template + 1] = {
        pass_type = "rect",
        style     = { color = COLOR_BASELINE, size = { chart_w, 1 }, offset = { 0, chart_h - 1 } },
    }

    if n > 0 then
        -- Determine bar width; minimum 2px, maximum 60px
        local max_bars = math.min(n, chart_w)
        local bar_w    = math.max(2, math.min(60, math.floor(chart_w / max_bars) - 1))
        local spacing  = math.floor(chart_w / max_bars)

        for i, use in ipairs(uses) do
            if i > max_bars then break end
            local dur_clamped = math.min(use.duration, max_y)
            local bar_h       = math.max(2, math.floor(dur_clamped / max_y * chart_h))
            local x           = math.floor((i - 1) * spacing)
            local color       = use.flagged and COLOR_FLAGGED or mod.bar_color(use, is_psyker)
            template[#template + 1] = {
                pass_type = "rect",
                style     = { color = color, size = { bar_w, bar_h }, offset = { x, chart_h - bar_h } },
            }
        end

        -- Average line (white, non-flagged only)
        if stats.avg then
            local avg_clamped = math.min(stats.avg, max_y)
            local avg_y       = math.floor(chart_h - (avg_clamped / max_y) * chart_h)
            template[#template + 1] = {
                pass_type = "rect",
                style     = { color = COLOR_AVERAGE, size = { chart_w, 2 }, offset = { 0, avg_y } },
            }
        end
    end

    local def = UIWidget.create_definition(template, Defs.chart_scene)
    return view:_create_widget("cooldown_chart", def)
end

local function make_no_data_widget(view)
    local def = UIWidget.create_definition({
        {
            pass_type = "text",
            value     = "No completed cooldowns recorded for this session.",
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

local function make_label_widget(view, stats, is_psyker)
    -- Line 1: cooldown stats
    local line1
    if stats.valid > 0 then
        line1 = string.format(
            "Uses: %d  (Flagged: %d)    Avg: %.1fs    Min: %.1fs    Max: %.1fs",
            stats.count, stats.flagged, stats.avg, stats.min, stats.max
        )
    elseif stats.count > 0 then
        line1 = string.format(
            "Uses: %d  (all %d flagged — no valid average)",
            stats.count, stats.flagged
        )
    else
        line1 = "No completed uses recorded."
    end

    -- Line 2: souls info (Psyker only), or legend
    local line2
    if is_psyker then
        local sc = stats.souls_by_count
        if stats.souls_avg then
            line2 = string.format(
                "Souls at use:  Avg %.1f    6: x%d    5: x%d    4: x%d    3: x%d    2: x%d    1: x%d    0: x%d",
                stats.souls_avg,
                sc[6] or 0, sc[5] or 0, sc[4] or 0, sc[3] or 0, sc[2] or 0, sc[1] or 0, sc[0] or 0
            )
        else
            line2 = "Souls: no data  (no souls were active on any use)"
        end
    else
        line2 = "Flagged entries (amber bars) are excluded from average, min, and max."
    end

    -- Line 3: legend note (Psyker)
    local line3 = ""
    if is_psyker then
        line3 = "Bar colour: more souls = greener teal.  Amber = flagged (reset / <4s)."
    end

    local function text_pass(value, y_offset, font_size, color)
        return {
            pass_type = "text",
            value     = value,
            style     = {
                font_type                 = "proxima_nova_bold",
                font_size                 = font_size or 18,
                text_color                = color or { 255, 220, 200, 255 },
                text_horizontal_alignment = "left",
                text_vertical_alignment   = "top",
                size                      = { Defs.panel_w - 50, 30 },
                offset                    = { 0, y_offset },
            },
        }
    end

    local passes = {
        text_pass(line1, 0,  18, { 255, 220, 200, 255 }),
        text_pass(line2, 28, 16, { 220, 200, 200, 200 }),
    }
    if line3 ~= "" then
        passes[#passes + 1] = text_pass(line3, 54, 14, { 180, 160, 160, 160 })
    end

    local def = UIWidget.create_definition(passes, Defs.label_scene)
    return view:_create_widget("cooldown_labels", def)
end

-- ===== View lifecycle =====

function CooldownChartView:init(settings, context)
    self._definitions     = Defs
    self._widgets         = {}
    self._widgets_by_name = {}
    CooldownChartView.super.init(self, Defs, settings)
    self._pass_input = true
end

function CooldownChartView:on_enter()
    local session   = mod._last_cooldown_session
    local uses      = session and session.uses or {}
    local is_psyker = session and session.is_psyker or false
    local archetype = session and session.archetype or nil
    local stats     = compute_stats(uses)

    self._widgets[#self._widgets + 1] = make_background_widget(self)
    self._widgets[#self._widgets + 1] = make_title_widget(self, archetype)

    if #uses == 0 then
        self._widgets[#self._widgets + 1] = make_no_data_widget(self)
    else
        local max_y = y_max(stats)
        self._widgets[#self._widgets + 1] = make_yaxis_widget(self, max_y)
        self._widgets[#self._widgets + 1] = make_chart_widget(self, uses, stats, is_psyker)
        self._widgets[#self._widgets + 1] = make_label_widget(self, stats, is_psyker)
    end

    self._input_legend = self:_add_element(ViewElementInputLegend, "input_legend", 10)
    self._input_legend:add_entry(
        "loc_settings_menu_close_menu", "back", nil,
        callback(self, "cb_on_back_pressed"), "left_alignment"
    )

    CooldownChartView.super.on_enter(self)
end

function CooldownChartView:cb_on_back_pressed()
    Managers.ui:close_view("cooldown_chart_view")
end

function CooldownChartView:update(...)
    return CooldownChartView.super.update(self, ...)
end

function CooldownChartView:on_exit(...)
    if self._input_legend then
        self:_remove_element("input_legend")
        self._input_legend = nil
    end
    CooldownChartView.super.on_exit(self, ...)
end

return CooldownChartView
