local mod = get_mod("FaithMeter")

local HudElementFaithMeter = class("HudElementFaithMeter", "HudElementBase")

local definitions = mod:io_dofile("FaithMeter/scripts/mods/FaithMeter/HudElements/HudElementFaithMeterDefinitions")

local function clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerp_color(out, c1, c2, t)
    -- Colors in UI styles are expected to be integer ARGB values.
    out[1] = math.floor(lerp(c1[1], c2[1], t) + 0.5)
    out[2] = math.floor(lerp(c1[2], c2[2], t) + 0.5)
    out[3] = math.floor(lerp(c1[3], c2[3], t) + 0.5)
    out[4] = math.floor(lerp(c1[4], c2[4], t) + 0.5)
end

local function set_argb(dst, a, r, g, b)
    dst[1] = a
    dst[2] = r
    dst[3] = g
    dst[4] = b
end

function HudElementFaithMeter:init(parent, draw_layer, start_scale)
    HudElementFaithMeter.super.init(self, parent, draw_layer, start_scale, definitions)

    self._faith_norm = 0.5
    self._faith_norm_target = 0.5
    self._bar_max_width = 170
    self._bar_max_height = 120

    -- Layout base values (do not change; sliders apply deltas/multipliers).
    self._base_root_pos = { 470, -148, 60 }
    self._base_root_size = { 260, 56 }
    self._base_sizes = {
        glow = { 240, 48 },
        plate_bg = { 240, 48 },
        icon = { 34, 34 },
        bar_bg = { 170, 10 },
        bar_fill = { 170, 10 },
        label = { 170, 18 },
        flavor = { 300, 18 },
    }
    self._base_offsets = {
        glow = { 0, 4, 0 },
        plate_bg = { 0, 4, 1 },
        icon = { 10, 11, 3 },
        bar_bg = { 54, 25, 2 },
        bar_fill = { 54, 25, 3 },
        label = { 54, 6, 3 },
        flavor = { 54, 40, 3 },
    }

    -- Dual-bar layout base values (Pressure left, Faith right). Kept isolated so the classic
    -- layout remains unchanged unless explicitly selected.
    self._base_dual_root_pos = { 470, -148, 60 }
    self._base_dual_root_size = { 220, 170 }
    self._base_dual_sizes = {
        dual_plate_bg = { 220, 170 },
        dual_icon = { 40, 40 },
        pressure_bg = { 22, 120 },
        faith_bg_v = { 22, 120 },
        pressure_fill = { 22, 120 },
        faith_fill_v = { 22, 120 },
        dual_label = { 200, 18 },
        dual_flavor = { 300, 18 },
        dual_debug = { 240, 28 },
    }
    self._base_dual_offsets = {
        dual_plate_bg = { 0, 0, 1 },
        dual_icon = { 90, 112, 3 },
        pressure_bg = { 52, 28, 2 },
        faith_bg_v = { 146, 28, 2 },
        pressure_fill = { 52, 28, 3 },
        faith_fill_v = { 146, 28, 3 },
        dual_label = { 12, 6, 4 },
        dual_flavor = { 38, 152, 4 },
        dual_debug = { 18, -12, 4 },
    }

    self._layout_last_x = nil
    self._layout_last_y = nil
    self._layout_last_scale = nil

    -- Colors are {a,r,g,b}
    self._color_low = { 220, 200, 70, 40 }
    self._color_mid = { 220, 235, 220, 170 }
    self._color_high = { 230, 245, 220, 120 }
    -- Pressure palette for dual layout
    self._pressure_color_low = { 170, 35, 35, 35 }
    self._pressure_color_high = { 220, 170, 60, 40 }
    self._tmp_color = { 255, 255, 255, 255 }
    self._tmp_pressure_color = { 255, 255, 255, 255 }
end

local function _round_int(x)
    return math.floor(x + 0.5)
end

function HudElementFaithMeter:_apply_layout_if_needed()
    local x = mod:get("hud_offset_x") or 0
    local y = mod:get("hud_offset_y") or 0
    local s = mod:get("hud_scale") or 1.0
    -- Back-compat: older versions stored hud_scale as percentage (e.g. 100)
    if type(s) == "number" and s > 10 then
        s = s / 100
    end
    if type(s) ~= "number" then
        s = 1.0
    end
    if s < 0.25 then s = 0.25 end
    if s > 4.0 then s = 4.0 end

    if type(x) ~= "number" then x = 0 end
    if type(y) ~= "number" then y = 0 end
    if type(s) ~= "number" then s = 1.0 end
    if s < 0.5 then s = 0.5 end
    if s > 2.0 then s = 2.0 end

    if self._layout_last_x == x and self._layout_last_y == y and self._layout_last_scale == s then
        return
    end

    self._layout_last_x = x
    self._layout_last_y = y
    self._layout_last_scale = s

    -- Scenegraph position/size
    self:set_scenegraph_position(
        "faith_meter_root",
        self._base_root_pos[1] + x,
        self._base_root_pos[2] + y,
        self._base_root_pos[3]
    )
    self:_set_scenegraph_size(
        "faith_meter_root",
        _round_int(self._base_root_size[1] * s),
        _round_int(self._base_root_size[2] * s)
    )

    local widget = self._widgets_by_name.faith_meter
    if not widget then
        return
    end

    -- Scale widget styles (sizes and offsets)
    for id, size in pairs(self._base_sizes) do
        if widget.style[id] and widget.style[id].size then
            widget.style[id].size[1] = _round_int(size[1] * s)
            widget.style[id].size[2] = _round_int(size[2] * s)
        end
    end
    for id, off in pairs(self._base_offsets) do
        if widget.style[id] and widget.style[id].offset then
            widget.style[id].offset[1] = _round_int(off[1] * s)
            widget.style[id].offset[2] = _round_int(off[2] * s)
            widget.style[id].offset[3] = off[3]
        end
    end

    -- Bar max width must match scaled fill/background.
    self._bar_max_width = _round_int(self._base_sizes.bar_fill[1] * s)

    widget.dirty = true

    -- Dual layout scenegraph + style scaling
    self:set_scenegraph_position(
        "faith_meter_dual_root",
        self._base_dual_root_pos[1] + x,
        self._base_dual_root_pos[2] + y,
        self._base_dual_root_pos[3]
    )
    self:_set_scenegraph_size(
        "faith_meter_dual_root",
        _round_int(self._base_dual_root_size[1] * s),
        _round_int(self._base_dual_root_size[2] * s)
    )

    local widget_dual = self._widgets_by_name.faith_meter_dual
    if widget_dual then
        for id, size in pairs(self._base_dual_sizes) do
            if widget_dual.style[id] and widget_dual.style[id].size then
                widget_dual.style[id].size[1] = _round_int(size[1] * s)
                widget_dual.style[id].size[2] = _round_int(size[2] * s)
            end
        end
        for id, off in pairs(self._base_dual_offsets) do
            if widget_dual.style[id] and widget_dual.style[id].offset then
                widget_dual.style[id].offset[1] = _round_int(off[1] * s)
                widget_dual.style[id].offset[2] = _round_int(off[2] * s)
                widget_dual.style[id].offset[3] = off[3]
            end
        end
        widget_dual.dirty = true
    end

    -- Vertical bar max height must match scaled fill/background.
    self._bar_max_height = _round_int(self._base_dual_sizes.faith_fill_v[2] * s)
end

function HudElementFaithMeter:update(dt, t, ui_renderer, render_settings, input_service)
    HudElementFaithMeter.super.update(self, dt, t, ui_renderer, render_settings, input_service)

    if not mod:get("hud_enabled") then
        return
    end

    -- Apply HUD layout controls (x/y/scale) without touching visuals.
    self:_apply_layout_if_needed()

    -- Faith logic: by default, reflect real gameplay state.
    -- Debug demo option (if enabled) intentionally overrides gameplay for visual testing.
    if mod:get("debug_demo_oscillate") then
        self._faith_norm_target = (math.sin(t * 0.8) + 1) * 0.5 -- 0..1
    else
        -- Read Faith from the logic layer. Keep backwards compatibility with earlier function names.
        if mod.get_faith_norm then
            self._faith_norm_target = mod:get_faith_norm()
        elseif mod.get_faith_normalized then
            self._faith_norm_target = mod:get_faith_normalized()
        else
            self._faith_norm_target = 0.5
        end
    end

    -- Smooth animation
    local speed = 6
    self._faith_norm = self._faith_norm + (self._faith_norm_target - self._faith_norm) * math.min(1, dt * speed)
    self._faith_norm = clamp01(self._faith_norm)

    local layout = mod:get("hud_layout") or 1
    local widget = self._widgets_by_name.faith_meter
    local widget_dual = self._widgets_by_name.faith_meter_dual

    local active_widget = (layout == 2 and widget_dual) or widget
    if not active_widget then
        return
    end

    -- -----------------------------------------------------
    -- Text + debug (kept identical across layouts)
    -- -----------------------------------------------------
    if active_widget.content then
        local show_label = mod:get("hud_show_text")
        local show_state = mod:get("hud_show_state_text")
        local show_flavor = mod:get("hud_show_flavor_text")

        if show_label then
            if show_state and mod.get_faith_state_text then
                active_widget.content.label_text = mod:get_faith_state_text()
            else
                active_widget.content.label_text = "FAITH"
            end

            if show_flavor and mod.get_faith_flavor_text then
                active_widget.content.flavor_text = mod:get_faith_flavor_text()
            else
                active_widget.content.flavor_text = ""
            end

            local dbg_lines = nil

            if mod:get("debug_pressure") and mod.get_pressure_debug then
                local p = mod:get_pressure_debug()
                if p then
                    dbg_lines = dbg_lines or {}
                    table.insert(dbg_lines, string.format("Pressure: COH %.0f%% | INCAP %d/%d | TOUGH %.0f%% | CRIT %d | RELIEF %s (%s)",
                        (p.coh_coverage or 0) * 100,
                        p.disabled or 0,
                        p.alive or 0,
                        (p.toughness_avg or 0) * 100,
                        p.critical_players or 0,
                        (p.relief and "yes" or "no"),
                        (p.relief_type or "none")
                    ))
                    table.insert(dbg_lines, string.format("Threat silent: %s (since pressure: %.1fs) | Since relief: %.1fs",
                        ((p.threat_silent and "yes") or "no"),
                        p.seconds_since_pressure or 0,
                        p.seconds_since_relief or 0
                    ))
                end
            end

            if mod:get("debug_special_pressure") and mod.get_special_pressure_debug then
                local d = mod:get_special_pressure_debug()
                if d then
                    dbg_lines = dbg_lines or {}
                    table.insert(dbg_lines, string.format(
                        "SPECIAL PRESSURE: %d/%d (%.2f/S) | engaged %.1fs | tracked %d | snd %d/%d +U%d pos%d",
                        d.contributing or 0,
                        d.seen or 0,
                        d.loss_per_s or 0,
                        d.oldest_engaged_s or 0,
                        d.tracked or 0,
                        d.snd_seen or 0,
                        d.snd_match or 0,
                        d.snd_addU or 0,
                        d.snd_pos or 0
                    ) .. ((mod._faith_initial_lock_active and " | LOCK" or "")))
                    table.insert(dbg_lines, string.format(
                        "TEAM X%.2f (%.1fS) | tk seen %d | tk cred %d | tk ign %d",
                        d.team_mult or 1.0,
                        d.team_s or 0,
                        d.tk_seen or 0,
                        d.tk_cred or 0,
                        d.tk_ign or 0
                    ))
                end
            end

            if dbg_lines then
                active_widget.content.debug_text = table.concat(dbg_lines, "\n")
            else
                active_widget.content.debug_text = ""
            end
        else
            active_widget.content.label_text = ""
            active_widget.content.flavor_text = ""
            active_widget.content.debug_text = ""
        end
    end

    -- -----------------------------------------------------
    -- Colors (Faith) and layout-specific bar rendering
    -- -----------------------------------------------------
    local tcol
    if self._faith_norm < 0.5 then
        tcol = self._faith_norm / 0.5
        lerp_color(self._tmp_color, self._color_low, self._color_mid, tcol)
    else
        tcol = (self._faith_norm - 0.5) / 0.5
        lerp_color(self._tmp_color, self._color_mid, self._color_high, tcol)
    end
    local c = self._tmp_color

	    if layout == 2 and widget_dual and widget_dual.style then
	        -- Dual vertical bars are a *single* meter shown in two opposing perspectives.
	        -- LEFT  = Pressure (bad): rises as Faith falls.
	        -- RIGHT = Faith    (good): rises as Faith stabilizes.
	        --
	        -- Both bars always represent the same progression state at the same time:
	        --   pressure = 1 - faith
	        --
	        -- Presentation-only; underlying faith value remains unchanged.

	        local s = self._layout_last_scale or 1.0

	        local faith_stage = clamp01(self._faith_norm)
	        local pressure_stage = clamp01(1.0 - faith_stage)

	        local left_h = math.floor(self._bar_max_height * pressure_stage + 0.5) -- Pressure
	        local right_h = math.floor(self._bar_max_height * faith_stage + 0.5)   -- Faith

	        -- Bottom-anchored fill: keep the bottom edge fixed while height changes.
	        -- This makes draining look like top->bottom (height shrinks from the top).
	        local base_left_y = _round_int(self._base_dual_offsets.pressure_fill[2] * s)
	        local base_right_y = _round_int(self._base_dual_offsets.faith_fill_v[2] * s)

	        -- LEFT bar: Pressure palette
	        lerp_color(self._tmp_pressure_color, self._pressure_color_low, self._pressure_color_high, pressure_stage)
	        local pc = self._tmp_pressure_color

	        if widget_dual.style.pressure_fill then
	            if widget_dual.style.pressure_fill.size then
	                widget_dual.style.pressure_fill.size[2] = left_h
	            end
	            if widget_dual.style.pressure_fill.offset then
	                widget_dual.style.pressure_fill.offset[2] = base_left_y + (self._bar_max_height - left_h)
	            end
	            if widget_dual.style.pressure_fill.color then
	                set_argb(widget_dual.style.pressure_fill.color, pc[1], pc[2], pc[3], pc[4])
	            end
	        end

	        -- RIGHT bar: Faith palette
	        if widget_dual.style.faith_fill_v then
	            if widget_dual.style.faith_fill_v.size then
	                widget_dual.style.faith_fill_v.size[2] = right_h
	            end
	            if widget_dual.style.faith_fill_v.offset then
	                widget_dual.style.faith_fill_v.offset[2] = base_right_y + (self._bar_max_height - right_h)
	            end
	            if widget_dual.style.faith_fill_v.color then
	                set_argb(widget_dual.style.faith_fill_v.color, c[1], c[2], c[3], c[4])
	            end
	        end

        if widget_dual.style.dual_label and widget_dual.style.dual_label.text_color then
            set_argb(widget_dual.style.dual_label.text_color, c[1], c[2], c[3], c[4])
        end
        if widget_dual.style.dual_flavor and widget_dual.style.dual_flavor.text_color then
            set_argb(widget_dual.style.dual_flavor.text_color, math.min(255, c[1]), c[2], c[3], c[4])
        end
        if widget_dual.style.dual_icon and widget_dual.style.dual_icon.color then
            set_argb(widget_dual.style.dual_icon.color, math.floor(120 + 90 * self._faith_norm + 0.5), c[2], c[3], c[4])
        end
    elseif widget and widget.style then
        -- Classic horizontal bar
        local fill_width = math.floor(self._bar_max_width * self._faith_norm + 0.5)
        widget.style.bar_fill.size[1] = fill_width

        set_argb(widget.style.bar_fill.color, c[1], c[2], c[3], c[4])
        set_argb(widget.style.icon.color, math.min(255, c[1] + 15), c[2], c[3], c[4])
        set_argb(widget.style.label.text_color, c[1], c[2], c[3], c[4])
        if widget.style.flavor and widget.style.flavor.text_color then
            set_argb(widget.style.flavor.text_color, math.min(255, c[1]), c[2], c[3], c[4])
        end

        local glow_alpha = math.floor(20 + 90 * self._faith_norm + 0.5)
        set_argb(widget.style.glow.color, glow_alpha, c[2], c[3], c[4])
    end
end

return HudElementFaithMeter
