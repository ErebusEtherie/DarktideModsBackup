local mod = get_mod("strikemap")

require("scripts/ui/views/base_view")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UISettings = require("scripts/settings/ui/ui_settings")

local SCREEN_W = UIWorkspaceSettings.screen.size[1]
local SCREEN_H = UIWorkspaceSettings.screen.size[2]

-- The 1920x1080 workspace constants only match the screen at 16:9; on
-- ultrawide the virtual space is wider and a static-1920 layout sits pushed
-- to the left. Refreshed from the real resolution at the top of every render
-- (all layout below reads these at call time, so the whole view reflows, and
-- cursor hit-tests use the same values).
local function refresh_screen_size(draw_scale)
	local rl = rawget(_G, "RESOLUTION_LOOKUP")
	local w = rl and tonumber(rl.width)
	local h = rl and tonumber(rl.height)

	if w and h and draw_scale and draw_scale > 0 then
		SCREEN_W, SCREEN_H = w / draw_scale, h / draw_scale
	end
end

-- ---------------------------------------------------------------------------
-- Layout / projection.
-- ---------------------------------------------------------------------------
local M = 40                 -- outer margin
local TITLE_H = 56
local LIST_W = 320
local STATS_H = 168
local TIMELINE_H = 30
local SPARK_H = 30           -- combat-intensity graph above the timeline
local RP_TILT = 0.82
local RP_HEIGHT = 0.10
local MAX_TRIS = 12000
local FLOOR_GAP = 5.0        -- merge geometry across vertical gaps up to this (m)
local MAX_FLOORS = 6
local GHOST_A = 34           -- alpha of geometry not on the focused floor

local SPEEDS = { 1, 2, 4, 8, 16, 32, 64 }

local DIFF_NAMES = { "SEDITION", "UPRISING", "MALICE", "HERESY", "DAMNATION" }
local DIFF_RGB = {
	{ 120, 220, 130 },
	{ 170, 214, 104 },
	{ 240, 208, 92 },
	{ 242, 150, 82 },
	{ 255, 96, 84 },
}

local ARCH_LABEL = {
	veteran = "VETERAN",
	zealot = "ZEALOT",
	psyker = "PSYKER",
	ogryn = "OGRYN",
	adamant = "ARBITES",
}

local ICON_POOL = 200
-- Every label on screen comes from this pool per frame (run list + feed +
-- buttons + stats table cells + tooltips); the 13-column scoreboard alone
-- eats ~60. Exhaustion silently drops text, so keep generous headroom.
local TEXT_POOL = 340
local SKIN_POOL = 48

local MAT = {
	panel = "content/ui/materials/backgrounds/terminal_basic",
	panel_fill = "content/ui/materials/backgrounds/default_square",
	skull = "content/ui/materials/icons/difficulty/difficulty_skull_damnation",
}

-- ---------------------------------------------------------------------------
-- Primitives.
-- ---------------------------------------------------------------------------
local Gui_triangle = Gui.triangle

local function draw_tri(gui, s, x1, y1, x2, y2, x3, y3, layer, color)
	Gui_triangle(gui, Vector3(x1 * s, 0, y1 * s), Vector3(x2 * s, 0, y2 * s), Vector3(x3 * s, 0, y3 * s), layer, color)
end

local function draw_rect(gui, s, x, y, w, h, layer, color)
	draw_tri(gui, s, x, y, x + w, y, x + w, y + h, layer, color)
	draw_tri(gui, s, x, y, x + w, y + h, x, y + h, layer, color)
end

local function draw_rect_outline(gui, s, x, y, w, h, th, layer, color)
	draw_rect(gui, s, x, y, w, th, layer, color)
	draw_rect(gui, s, x, y + h - th, w, th, layer, color)
	draw_rect(gui, s, x, y, th, h, layer, color)
	draw_rect(gui, s, x + w - th, y, th, h, layer, color)
end

local function draw_diamond(gui, s, x, y, r, layer, color)
	draw_tri(gui, s, x, y - r, x + r, y, x, y + r, layer, color)
	draw_tri(gui, s, x, y - r, x, y + r, x - r, y, layer, color)
end

local function draw_line(gui, s, x1, y1, x2, y2, th, layer, color)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)

	if len <= 0.001 then
		return
	end

	local nx, ny = -dy / len * th * 0.5, dx / len * th * 0.5

	draw_tri(gui, s, x1 + nx, y1 + ny, x2 + nx, y2 + ny, x2 - nx, y2 - ny, layer, color)
	draw_tri(gui, s, x1 + nx, y1 + ny, x2 - nx, y2 - ny, x1 - nx, y1 - ny, layer, color)
end

local function draw_ring(gui, s, ox, oy, r, th, segs, layer, color)
	local step = 2 * math.pi / segs
	local px, py = ox + r, oy

	for k = 1, segs do
		local a = k * step
		local x, y = ox + math.cos(a) * r, oy + math.sin(a) * r

		draw_line(gui, s, px, py, x, y, th, layer, color)
		px, py = x, y
	end
end

-- Sutherland-Hodgman clip of a convex polygon against one rect edge
-- (module-level buffers; the view draws once per frame so this is safe).
-- edge: 1 = x >= bound, 2 = x <= bound, 3 = y >= bound, 4 = y <= bound
local _in_x, _in_y = {}, {}
local _out_x, _out_y = {}, {}

local function clip_edge(in_x, in_y, cnt, out_x, out_y, edge, bound)
	local m = 0

	for i = 1, cnt do
		local j = i % cnt + 1
		local xi, yi = in_x[i], in_y[i]
		local xj, yj = in_x[j], in_y[j]
		local inside_i, inside_j

		if edge == 1 then
			inside_i, inside_j = xi >= bound, xj >= bound
		elseif edge == 2 then
			inside_i, inside_j = xi <= bound, xj <= bound
		elseif edge == 3 then
			inside_i, inside_j = yi >= bound, yj >= bound
		else
			inside_i, inside_j = yi <= bound, yj <= bound
		end

		if inside_i then
			m = m + 1
			out_x[m], out_y[m] = xi, yi
		end

		if inside_i ~= inside_j then
			local t

			if edge <= 2 then
				t = (bound - xi) / (xj - xi)
			else
				t = (bound - yi) / (yj - yi)
			end

			m = m + 1
			out_x[m] = xi + (xj - xi) * t
			out_y[m] = yi + (yj - yi) * t
		end
	end

	return m
end

-- Clip a triangle to a rect and draw the surviving polygon as a fan, so
-- zoomed/rotated floor geometry never spills over the side panels.
local function draw_tri_clipped(gui, s, x1, y1, x2, y2, x3, y3, left, top, right, bottom, layer, color)
	if x1 >= left and x1 <= right and y1 >= top and y1 <= bottom
		and x2 >= left and x2 <= right and y2 >= top and y2 <= bottom
		and x3 >= left and x3 <= right and y3 >= top and y3 <= bottom then
		draw_tri(gui, s, x1, y1, x2, y2, x3, y3, layer, color)

		return
	end

	_in_x[1], _in_y[1] = x1, y1
	_in_x[2], _in_y[2] = x2, y2
	_in_x[3], _in_y[3] = x3, y3

	local cnt = 3

	cnt = clip_edge(_in_x, _in_y, cnt, _out_x, _out_y, 1, left)

	if cnt < 3 then
		return
	end

	cnt = clip_edge(_out_x, _out_y, cnt, _in_x, _in_y, 2, right)

	if cnt < 3 then
		return
	end

	cnt = clip_edge(_in_x, _in_y, cnt, _out_x, _out_y, 3, top)

	if cnt < 3 then
		return
	end

	cnt = clip_edge(_out_x, _out_y, cnt, _in_x, _in_y, 4, bottom)

	if cnt < 3 then
		return
	end

	for i = 2, cnt - 1 do
		draw_tri(gui, s, _in_x[1], _in_y[1], _in_x[i], _in_y[i], _in_x[i + 1], _in_y[i + 1], layer, color)
	end
end

-- Liang-Barsky clipping for route segments. Gui.line has no scissor support,
-- so without clipping a zoomed/panned replay can draw player routes straight
-- across the run list, event feed and stats panels.
local function clip_line(x1, y1, x2, y2, left, top, right, bottom)
	local dx, dy = x2 - x1, y2 - y1
	local u1, u2 = 0, 1

	-- the four edges unrolled in a numbered loop (a per-call edge() closure
	-- here was a fresh LuaJIT allocation for every route segment every frame)
	for e = 1, 4 do
		local p, q

		if e == 1 then
			p, q = -dx, x1 - left
		elseif e == 2 then
			p, q = dx, right - x1
		elseif e == 3 then
			p, q = -dy, y1 - top
		else
			p, q = dy, bottom - y1
		end

		if p == 0 then
			if q < 0 then
				return nil
			end
		else
			local r = q / p

			if p < 0 then
				if r > u2 then
					return nil
				end

				if r > u1 then
					u1 = r
				end
			elseif r < u1 then
				return nil
			elseif r < u2 then
				u2 = r
			end
		end
	end

	return x1 + u1 * dx, y1 + u1 * dy, x1 + u2 * dx, y1 + u2 * dy
end

local function draw_line_clipped(gui, s, x1, y1, x2, y2, th, left, top, right, bottom, layer, color)
	local ax, ay, bx, by = clip_line(x1, y1, x2, y2, left, top, right, bottom)

	if ax then
		draw_line(gui, s, ax, ay, bx, by, th, layer, color)
	end
end

-- Auspex-style corner brackets around a rect.
local function draw_brackets(gui, s, x, y, w, h, len, th, layer, color)
	draw_rect(gui, s, x, y, len, th, layer, color)
	draw_rect(gui, s, x, y, th, len, layer, color)
	draw_rect(gui, s, x + w - len, y, len, th, layer, color)
	draw_rect(gui, s, x + w - th, y, th, len, layer, color)
	draw_rect(gui, s, x, y + h - th, len, th, layer, color)
	draw_rect(gui, s, x, y + h - len, th, len, layer, color)
	draw_rect(gui, s, x + w - len, y + h - th, len, th, layer, color)
	draw_rect(gui, s, x + w - th, y + h - len, th, len, layer, color)
end

-- ---------------------------------------------------------------------------
-- Helpers.
-- ---------------------------------------------------------------------------
local function safe(fn)
	local ok, r = pcall(fn)

	if ok then
		return r
	end

	return nil
end

-- Thermal ramp for the heat overlays: cold blue -> teal -> green -> amber ->
-- red -> near-white, so hot spots genuinely burn.
local HEAT_STOPS = {
	{ 0.00, 26, 44, 132 },
	{ 0.25, 28, 158, 188 },
	{ 0.50, 96, 208, 96 },
	{ 0.70, 244, 208, 72 },
	{ 0.88, 250, 118, 52 },
	{ 1.00, 255, 238, 214 },
}

local function heat_rgb(v)
	if v <= 0 then
		return HEAT_STOPS[1][2], HEAT_STOPS[1][3], HEAT_STOPS[1][4]
	end

	if v >= 1 then
		local s = HEAT_STOPS[#HEAT_STOPS]

		return s[2], s[3], s[4]
	end

	for i = 1, #HEAT_STOPS - 1 do
		local a, b = HEAT_STOPS[i], HEAT_STOPS[i + 1]

		if v >= a[1] and v <= b[1] then
			local f = (v - a[1]) / (b[1] - a[1])

			return a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, a[4] + (b[4] - a[4]) * f
		end
	end

	local s = HEAT_STOPS[#HEAT_STOPS]

	return s[2], s[3], s[4]
end

-- "2H AGO" style stamp for the run list (best effort; nil without os.time).
local function fmt_ago(stamp)
	local now = safe(function()
		local mods = rawget(_G, "Mods")
		local os_lib = (mods and mods.lua and mods.lua.os) or rawget(_G, "os")

		return os_lib and os_lib.time and os_lib.time() or nil
	end)

	if not (stamp and now) or now < stamp then
		return nil
	end

	local d = now - stamp

	if d < 60 then
		return "JUST NOW"
	elseif d < 5400 then
		return math.floor(d / 60) .. "M AGO"
	elseif d < 129600 then
		return math.floor(d / 3600 + 0.5) .. "H AGO"
	end

	return math.floor(d / 86400 + 0.5) .. "D AGO"
end

local function diff_label(difficulty)
	local d = tonumber(difficulty)

	if d and DIFF_NAMES[d] then
		return DIFF_NAMES[d], DIFF_RGB[d]
	end

	return nil, nil
end

local function arch_label(arch)
	if type(arch) ~= "string" or arch == "" then
		return nil
	end

	return ARCH_LABEL[arch] or arch:upper()
end

local function parse_flat(str)
	local t, n = {}, 0

	if type(str) == "string" then
		for v in str:gmatch("[^,;]+") do
			n = n + 1
			t[n] = tonumber(v) or 0
		end
	end

	return t, n
end

local function fmt_time(sec)
	sec = math.max(0, math.floor(sec or 0))

	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function hash_rgb(seed)
	local h = 2166136261

	for i = 1, #seed do
		h = (h * 31 + seed:byte(i)) % 4294967296
	end

	return { 90 + h % 150, 90 + math.floor(h / 256) % 150, 90 + math.floor(h / 65536) % 150 }
end

local function player_rgb(p)
	local sc = UISettings.player_slot_colors

	if sc and p.slot and p.slot > 0 and sc[p.slot] and #sc[p.slot] >= 4 then
		return { sc[p.slot][2], sc[p.slot][3], sc[p.slot][4] }
	end

	return hash_rgb(tostring(p.name or "?"))
end

local function inside(cx, cy, r)
	return cx >= r.x and cx <= r.x + r.w and cy >= r.y and cy <= r.y + r.h
end

local DOWN_VERB = {
	[1] = "downed",
	[2] = "grabbed",
	[3] = "killed",
	[4] = "back in the fight",
	[5] = "encountered", -- boss appeared
	[6] = "slain",       -- boss killed
}

local BOSS_RGB = { 226, 136, 222 }

-- "231.4k" style damage numbers for leaderboards and stats.
local function fmt_dmg(v)
	v = tonumber(v) or 0

	if v >= 1000000 then
		return string.format("%.1fM", v / 1000000)
	elseif v >= 10000 then
		return math.floor(v / 1000 + 0.5) .. "k"
	elseif v >= 1000 then
		return string.format("%.1fk", v / 1000)
	end

	return tostring(math.floor(v + 0.5))
end

-- Kills a player has at replay time T (killt = flat stride-length records,
-- "t,class" in v3.0 archives, "t,class,x,y" from v3.1 on; time-sorted).
local function kills_at(p, T, stride)
	if not T then
		return p.kills or 0
	end

	stride = stride or 2

	local n = math.floor((p.killtn or 0) / stride)
	local count = 0

	for i = 0, n - 1 do
		if p.killt[i * stride + 1] <= T then
			count = count + 1
		else
			break
		end
	end

	return count
end

-- The game's class symbol glyph for an archetype ("" when unknown).
local function arch_icon(arch)
	local icons = UISettings and UISettings.archetype_font_icon

	return (arch and icons and icons[arch]) or nil
end

-- Downs and deaths a player has by replay time T (nil = whole run).
local function downs_at(p, T)
	local downs, deaths = 0, 0

	for _, ev in ipairs(p.downs or {}) do
		if not T or ev.t <= T then
			if ev.code == 3 then
				deaths = deaths + 1
			elseif ev.code ~= 4 then
				downs = downs + 1
			end
		end
	end

	return downs, deaths
end

-- Damage dealt by replay time T, from the 10s buckets (linear inside a bucket).
local function dmg_at(p, T)
	if not T then
		return p.dmg or 0
	end

	local n = p.dmgbn or 0

	if n == 0 then
		return 0
	end

	local full = math.floor(T / 10)
	local base = full > 0 and p.dmgcum[math.min(full, n)] or 0

	if full < n then
		base = base + ((T - full * 10) / 10) * (p.dmgb[full + 1] or 0)
	end

	return base
end

-- Prefer the archived display name ("Silo Cluster 18-66/a") over the raw id.
local function run_title(r)
	if type(r.title) == "string" and r.title ~= "" then
		return r.title:upper()
	end

	return (tostring(r.mission or ""):upper():gsub("_", " "))
end

-- ---------------------------------------------------------------------------
-- Widget defs (pooled).
-- ---------------------------------------------------------------------------
local function texture_def(material)
	return UIWidget.create_definition({
		{ pass_type = "texture", value = material or MAT.panel_fill, value_id = "icon", style_id = "icon",
			style = { size = { 24, 24 }, offset = { 0, 0, 0 }, color = { 255, 255, 255, 255 } } },
	}, "screen")
end

local function text_def()
	return UIWidget.create_definition({
		{ pass_type = "text", value = "", value_id = "text", style_id = "text",
			style = { font_size = 14, font_type = "machine_medium", text_color = { 255, 255, 255, 255 },
				text_horizontal_alignment = "center", text_vertical_alignment = "center",
				size = { 120, 20 }, offset = { 0, 0, 0 } } },
	}, "screen")
end

local function build_definitions()
	local defs = {}

	for i = 1, SKIN_POOL do
		defs["skin_" .. i] = texture_def(MAT.panel_fill)
	end

	for i = 1, ICON_POOL do
		defs["icon_" .. i] = texture_def(MAT.skull)
	end

	for i = 1, TEXT_POOL do
		defs["text_" .. i] = text_def()
	end

	return { scenegraph_definition = { screen = UIWorkspaceSettings.screen }, widget_definitions = defs }
end

-- ---------------------------------------------------------------------------
local View = class("StrikemapReportView", "BaseView")

function View:init(settings, context)
	self._definitions = build_definitions()

	View.super.init(self, self._definitions, settings, context)

	self._pass_input = true
	self._pass_draw = true
	self._cursor = { 0, 0 }
	self._draw_scale = 1
	self._prev_hold = false
	self._prev_pressed = false
	self._dragging = false
	self._drag_moved = false
	self._drag_last = { 0, 0 }
	self._buttons = {}
	self._markers = {}
	self._event_rows = {}

	-- view params (reset per report)
	self._zoom = 1
	self._pan_x = 0
	self._pan_y = 0
	self._focus = nil       -- floor index, or nil = all floors
	self._time = nil        -- replay time, nil = full overview
	self._playing = false
	self._speed = 1         -- replay speed multiplier
	self._follow = false    -- camera tracks the squad during replay
	self._yaw = 0           -- orbit rotation (radians)
	self._pitch = RP_TILT   -- 1 = top-down, low = dramatic 3D
	self._orbit = false     -- left-drag rotates instead of panning
	self._auto_play_pending = false
	self._feed_scroll = 0
	self._spark = nil       -- combat-intensity buckets for the timeline
	self._heat_filter = nil -- player index the killzones layer is filtered to
	self._inv = nil         -- current map projection, for cursor -> world

	self._loaded_id = nil
	self._cache = nil
	self._floors = nil
	self._map_rect = { x = 0, y = 0, w = 1, h = 1 }
	self._timeline_rect = { x = 0, y = 0, w = 1, h = 1 }
	self._feed_rect = { x = 0, y = 0, w = 1, h = 1 }
end

function View:on_enter()
	View.super.on_enter(self)

	local rl = rawget(_G, "RESOLUTION_LOOKUP")

	if rl and rl.scale then
		self._render_scale = rl.scale
	end

	self._ui_scenegraph = self:_create_scenegraph(self._definitions)
	self._widgets, self._widgets_by_name = self:_create_widgets(self._definitions)
	self._skin, self._icon, self._text = {}, {}, {}

	for i = 1, SKIN_POOL do
		self._skin[i] = self._widgets_by_name["skin_" .. i]
	end

	for i = 1, ICON_POOL do
		self._icon[i] = self._widgets_by_name["icon_" .. i]
	end

	for i = 1, TEXT_POOL do
		self._text[i] = self._widgets_by_name["text_" .. i]
	end

	-- opened automatically at mission end -> run a cinematic replay of the run
	if mod._auto_replay_pending then
		mod._auto_replay_pending = nil
		self._auto_play_pending = true
		self._loaded_id = nil -- force a fresh sync even if this instance is reused
	end

	if mod.report_browser_set_open then
		mod.report_browser_set_open(true)
	end
end

function View:on_exit()
	if mod.report_browser_set_open then
		mod.report_browser_set_open(false)
	end

	View.super.on_exit(self)
end

-- ---------------------------------------------------------------------------
-- Input.
-- ---------------------------------------------------------------------------
function View:update(dt, t, input_service)
	View.super.update(self, dt, t, input_service)

	self._now = t or ((self._now or 0) + dt)

	pcall(function()
		local cursor = input_service:get("cursor")

		if cursor then
			local inv = (self._draw_scale > 0) and (1 / self._draw_scale) or 1

			self._cursor[1] = cursor[1] * inv
			self._cursor[2] = cursor[2] * inv
		end

		local pressed = input_service:get("left_pressed")
		local hold = input_service:get("left_hold")
		local scroll = input_service:get("scroll_axis")

		-- advance replay (at the chosen speed)
		if self._playing and self._duration then
			self._time = (self._time or 0) + dt * (self._speed or 1)

			if self._time >= self._duration then
				self._time = self._duration
				self._playing = false
			end
		end

		-- wheel: zoom map when over it, else scroll the event feed
		if scroll and scroll[2] and scroll[2] ~= 0 then
			if inside(self._cursor[1], self._cursor[2], self._feed_rect) then
				self._feed_scroll = math.max(0, self._feed_scroll - (scroll[2] > 0 and 1 or -1))
			elseif inside(self._cursor[1], self._cursor[2], self._map_rect) then
				self:_zoom_at(self._cursor[1], self._cursor[2], scroll[2] > 0 and 1.15 or 1 / 1.15)
			end
		end

		if pressed and not self._prev_pressed then
			self:_on_press()
		end

		if hold and self._dragging then
			local dx = self._cursor[1] - self._drag_last[1]
			local dy = self._cursor[2] - self._drag_last[2]

			if math.abs(dx) + math.abs(dy) > 1.5 then
				self._drag_moved = true
			end

			if self._drag_kind == "map" and self._orbit then
				-- orbit: horizontal = rotate, vertical = tilt (down = more 3D)
				self._yaw = self._yaw + dx * 0.007
				self._pitch = math.max(0.34, math.min(1, self._pitch - dy * 0.004))
			elseif self._drag_kind == "map" then
				self._follow = false -- manual pan takes the camera back

				local ax, ay = self:_screen_to_world(self._drag_last[1], self._drag_last[2])
				local bx, by = self:_screen_to_world(self._cursor[1], self._cursor[2])

				if ax and bx then
					self._pan_x = self._pan_x - (bx - ax)
					self._pan_y = self._pan_y - (by - ay)
				end
			elseif self._drag_kind == "timeline" then
				self:_scrub(self._cursor[1])
			end

			self._drag_last[1] = self._cursor[1]
			self._drag_last[2] = self._cursor[2]
		end

		if self._prev_hold and not hold then
			-- release: a non-dragged press on the map counts as a click
			if self._dragging and not self._drag_moved and self._drag_kind == "map" then
				self:_click_map()
			end

			self._dragging = false
			self._drag_kind = nil
		end

		-- alternate orbit: hold middle (or right) mouse over the map to orbit
		-- without toggling ORBIT mode first
		local alt_hold = self:_alt_orbit_hold(input_service)

		if alt_hold and not self._prev_alt_hold then
			if inside(self._cursor[1], self._cursor[2], self._map_rect) then
				self._alt_orbiting = true
				self._alt_last = self._alt_last or { 0, 0 }
				self._alt_last[1], self._alt_last[2] = self._cursor[1], self._cursor[2]
			end
		elseif not alt_hold then
			self._alt_orbiting = false
		end

		if self._alt_orbiting and alt_hold then
			local adx = self._cursor[1] - self._alt_last[1]
			local ady = self._cursor[2] - self._alt_last[2]

			self._yaw = (self._yaw or 0) + adx * 0.007
			self._pitch = math.max(0.34, math.min(1, (self._pitch or RP_TILT) - ady * 0.004))
			self._alt_last[1], self._alt_last[2] = self._cursor[1], self._cursor[2]
		end

		self._prev_alt_hold = alt_hold and true or false
		self._prev_pressed = pressed and true or false
		self._prev_hold = hold and true or false
	end)
end

-- Which alternate hold actions this input service actually has (probed once;
-- unknown action names make input_service:get error, hence the pcalls).
local ALT_ORBIT_ACTIONS = { "middle_hold", "right_hold" }

function View:_alt_orbit_hold(input_service)
	local probed = self._alt_actions

	if not probed then
		probed = {}

		for i = 1, #ALT_ORBIT_ACTIONS do
			local ok = pcall(input_service.get, input_service, ALT_ORBIT_ACTIONS[i])

			if ok then
				probed[#probed + 1] = ALT_ORBIT_ACTIONS[i]
			end
		end

		self._alt_actions = probed
	end

	for i = 1, #probed do
		local held = safe(function()
			return input_service:get(probed[i])
		end)

		if held then
			return true
		end
	end

	return false
end

-- Invert the current map projection at the ground plane: screen -> world.
-- Uses the projection snapshot from the last rendered frame.
function View:_screen_to_world(sx, sy)
	local inv = self._inv

	if not inv or not inv.fit or inv.fit <= 0 then
		return nil
	end

	local rx = (sx - inv.rcx) / inv.fit
	local ry = (inv.rcy - sy) / (inv.fit * inv.tilt)
	local c, sn = inv.cos, inv.sin
	local dx = rx * c + ry * sn
	local dy = ry * c - rx * sn

	return dx + inv.cxw, dy + inv.cyw
end

function View:_zoom_at(cx, cy, factor)
	local wx, wy = self:_screen_to_world(cx, cy)
	local z1 = self._zoom

	self._zoom = math.max(0.5, math.min(12, self._zoom * factor))

	if not wx then
		return
	end

	-- keep the world point under the cursor fixed while the scale changes
	local ratio = z1 / self._zoom
	local cxw = (self._mcx or 0) + self._pan_x
	local cyw = (self._mcy or 0) + self._pan_y

	self._pan_x = wx - (wx - cxw) * ratio - (self._mcx or 0)
	self._pan_y = wy - (wy - cyw) * ratio - (self._mcy or 0)
end

function View:_on_press()
	local cx, cy = self._cursor[1], self._cursor[2]

	-- buttons first
	for i = 1, #self._buttons do
		local b = self._buttons[i]

		if inside(cx, cy, b) then
			self:_do_action(b)
			return
		end
	end

	-- a click anywhere else disarms a pending delete confirmation
	self._confirm_delete = nil

	-- event rows
	for i = 1, #self._event_rows do
		local r = self._event_rows[i]

		if inside(cx, cy, r) then
			self:_focus_event(r.event)
			return
		end
	end

	-- timeline scrub start
	if inside(cx, cy, self._timeline_rect) then
		self._dragging = true
		self._drag_kind = "timeline"
		self._drag_moved = false
		self._drag_last[1], self._drag_last[2] = cx, cy
		self:_scrub(cx)
		return
	end

	-- otherwise, start a potential map drag (pan) / click.
	-- A quick second click in the same spot zooms in on it.
	if inside(cx, cy, self._map_rect) then
		local now = self._now or 0
		local lp = self._last_press

		if lp and (now - lp.t) < 0.35 and math.abs(cx - lp.x) + math.abs(cy - lp.y) < 10 then
			self._last_press = nil
			self:_zoom_at(cx, cy, 1.9)

			return
		end

		self._last_press = { t = now, x = cx, y = cy }
		self._dragging = true
		self._drag_kind = "map"
		self._drag_moved = false
		self._drag_last[1], self._drag_last[2] = cx, cy
	end
end

function View:_do_action(b)
	-- any other click disarms a pending delete confirmation
	if b.action ~= "delete" then
		self._confirm_delete = nil
	end

	if b.action == "close" then
		Managers.ui:close_view(self.view_name or "strikemap_report_view")
	elseif b.action == "delete" then
		if self._confirm_delete == b.id then
			self._confirm_delete = nil

			safe(function()
				mod.report_delete(b.id)
			end)
		else
			self._confirm_delete = b.id
		end
	elseif b.action == "favorite" then
		safe(function()
			mod.report_toggle_favorite(b.id)
		end)
	elseif b.action == "next" then
		mod.report_browser_next()
	elseif b.action == "prev" then
		mod.report_browser_prev()
	elseif b.action == "select" then
		mod.report_browser_select(b.index)
	elseif b.action == "layer" then
		local rv = mod.report_view()

		while rv.layer ~= b.arg do
			mod.report_cycle_layer()
			rv = mod.report_view()
		end
	elseif b.action == "floor" then
		self:_cycle_floor(b.arg)
	elseif b.action == "heatfilter" then
		self._heat_filter = b.arg -- player index, or nil = whole squad
		self._heat = nil          -- rebuild the grid from the new source
	elseif b.action == "play" then
		if not self._time or self._time >= (self._duration or 0) then
			self._time = 0
		end

		self._playing = not self._playing
	elseif b.action == "speed_set" then
		self._speed = b.arg or 1
	elseif b.action == "follow" then
		self._follow = not self._follow

		if self._follow then
			if self._zoom < 2 then
				self._zoom = 2.4
			end

			-- following needs a moment on the clock to have something to track
			if not self._time then
				self._time = 0
			end
		end
	elseif b.action == "overview" then
		self._time = nil
		self._playing = false
		self._follow = false
	elseif b.action == "orbit" then
		self._orbit = not self._orbit
	elseif b.action == "recenter" then
		self._zoom = 1
		self._pan_x = 0
		self._pan_y = 0
		self._follow = false
		self._yaw = 0
		self._pitch = RP_TILT
	end
end

function View:_cycle_floor(dir)
	local n = self._floors and #self._floors or 0

	if n == 0 then
		return
	end

	-- order: All (nil) -> 1 -> 2 -> ... -> All
	if self._focus == nil then
		self._focus = dir > 0 and 1 or n
	else
		self._focus = self._focus + dir

		if self._focus < 1 or self._focus > n then
			self._focus = nil
		end
	end
end

function View:_scrub(cx)
	local r = self._timeline_rect
	local frac = math.max(0, math.min(1, (cx - r.x) / math.max(1, r.w)))

	self._time = frac * (self._duration or 0)
	self._playing = false
end

function View:_click_map()
	-- select the nearest hovered marker (tooltip already shows it; clicking a
	-- marker focuses its floor + time)
	local cx, cy = self._cursor[1], self._cursor[2]

	for i = 1, #self._markers do
		local mk = self._markers[i]
		local dx, dy = cx - mk.x, cy - mk.y

		if dx * dx + dy * dy <= (mk.r + 4) * (mk.r + 4) and mk.event then
			self:_focus_event(mk.event)
			return
		end
	end
end

function View:_focus_event(ev)
	self._time = ev.t
	self._playing = false
	self._pan_x = ev.x - (self._mcx or ev.x)
	self._pan_y = ev.y - (self._mcy or ev.y)
	self._zoom = math.max(self._zoom, 3)

	if self._floors then
		for i = 1, #self._floors do
			local fl = self._floors[i]

			if ev.z >= fl.zmin - 1.5 and ev.z <= fl.zmax + 1.5 then
				self._focus = i
				break
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Pool accessors.
-- ---------------------------------------------------------------------------
function View:_skin_at(mat, x, y, w, h, rgba, layer)
	local n = self._skins_used + 1

	if n > SKIN_POOL then
		return
	end

	self._skins_used = n

	local wd = self._skin[n]
	local st = wd.style.icon

	wd.content.icon = mat
	st.size[1], st.size[2] = w, h
	st.offset[1], st.offset[2], st.offset[3] = x, y, layer
	st.color[1], st.color[2], st.color[3], st.color[4] = rgba[1], rgba[2], rgba[3], rgba[4]
	wd.dirty = true
end

function View:_icon_at(mat, x, y, size, rgb, alpha, layer)
	local n = self._icons_used + 1

	if n > ICON_POOL then
		return
	end

	self._icons_used = n

	local wd = self._icon[n]
	local st = wd.style.icon

	wd.content.icon = mat
	st.size[1], st.size[2] = size, size
	st.offset[1], st.offset[2], st.offset[3] = x - size * 0.5, y - size * 0.5, layer
	st.color[1], st.color[2], st.color[3], st.color[4] = alpha, rgb[1], rgb[2], rgb[3]
	wd.dirty = true
end

function View:_text_at(text, x, y, w, h, size, rgb, alpha, layer, align)
	local n = self._texts_used + 1

	if n > TEXT_POOL then
		return
	end

	self._texts_used = n

	local wd = self._text[n]
	local st = wd.style.text

	wd.content.text = text
	st.font_size = size
	st.size[1], st.size[2] = w, h
	st.offset[1] = align == "left" and x or (x - w * 0.5)
	st.offset[2] = y - h * 0.5
	st.offset[3] = layer
	st.text_horizontal_alignment = align or "center"
	st.text_color[1], st.text_color[2], st.text_color[3], st.text_color[4] = alpha, rgb[1], rgb[2], rgb[3]
	wd.dirty = true
end

function View:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
	self._skins_used, self._icons_used, self._texts_used = 0, 0, 0

	local ok, err = pcall(self._render, self, ui_renderer, render_settings, t)

	if not ok then
		mod._report_view_error = err
	end

	for i = 1, self._skins_used do
		UIWidget.draw(self._skin[i], ui_renderer)
	end

	for i = 1, self._icons_used do
		UIWidget.draw(self._icon[i], ui_renderer)
	end

	for i = 1, self._texts_used do
		UIWidget.draw(self._text[i], ui_renderer)
	end
end

-- ---------------------------------------------------------------------------
-- Data: parse selected report, cluster floors, build event list.
-- ---------------------------------------------------------------------------
function View:_sync(rv)
	local report = rv.report

	if not report then
		self._cache = nil
		return nil
	end

	if self._loaded_id == report.id then
		return self._cache
	end

	self._loaded_id = report.id

	local players = {}

	for _, p in ipairs(report.players or {}) do
		local path, pathn = parse_flat(p.path)
		local downs = {}
		local nd, dd = 0, 0

		for _, d in ipairs(p.downs or {}) do
			downs[#downs + 1] = d

			if d.code == 3 then
				dd = dd + 1
			elseif d.code ~= 4 then
				nd = nd + 1
			end
		end

		-- attributed combat stats (v3 reports; zeros/empty on older archives)
		local killt, killtn = parse_flat(p.killt)
		local dmgb, dmgbn = parse_flat(p.dmgt)
		local dmgcum = {}
		local running = 0

		for i = 1, dmgbn do
			running = running + dmgb[i]
			dmgcum[i] = running
		end

		players[#players + 1] = {
			slot = p.slot, name = p.name, arch = p.arch, icon = arch_icon(p.arch),
			ps = report.path_stride or 3,
			is_local = p.is_local, is_bot = p.is_bot,
			dist = p.dist or 0, downtime = p.downtime, path = path, pathn = pathn,
			downs = downs, ndowns = nd, ndeaths = dd,
			dmg = p.dmg or 0, taken = p.taken or 0, kills = p.kills or 0,
			hits = p.hits or 0, wk = p.wk or 0, crit = p.crit or 0,
			revs = p.revs or 0, ammo = p.ammo or 0, med = p.med or 0,
			plasteel = p.plasteel or 0, diamantine = p.diamantine or 0,
			killt = killt, killtn = killtn, dmgb = dmgb, dmgbn = dmgbn, dmgcum = dmgcum,
			scan = 0,
		}
	end

	table.sort(players, function(a, b)
		if a.is_local ~= b.is_local then
			return a.is_local
		end

		if (a.is_bot or false) ~= (b.is_bot or false) then
			return not a.is_bot
		end

		return (a.slot or 99) < (b.slot or 99)
	end)

	-- event feed
	local events = {}

	for _, p in ipairs(players) do
		for _, d in ipairs(p.downs) do
			events[#events + 1] = {
				t = d.t, x = d.x, y = d.y, z = d.z, code = d.code, cause = d.cause or "",
				name = p.name, rgb = player_rgb(p), icon = p.icon,
			}
		end
	end

	-- boss encounters/kills join the event stream (feed + timeline + map)
	local bosses_slain = 0

	for _, bz in ipairs(report.bosses or {}) do
		events[#events + 1] = {
			t = bz.t0 or 0, x = bz.x, y = bz.y, z = bz.z, code = 5,
			cause = "", name = bz.label or "Boss", rgb = BOSS_RGB,
		}

		if bz.t1 then
			bosses_slain = bosses_slain + 1
			events[#events + 1] = {
				t = bz.t1, x = bz.x, y = bz.y, z = bz.z, code = 6,
				cause = bz.by or "", name = bz.label or "Boss", rgb = BOSS_RGB,
			}
		end
	end

	table.sort(events, function(a, b)
		return a.t < b.t
	end)

	local kills, killsn = parse_flat(report.kills)
	local has_combat = false

	for _, p in ipairs(players) do
		if (p.dmg or 0) > 0 or (p.kills or 0) > 0 then
			has_combat = true
		end
	end

	self._cache = {
		id = report.id, players = players, events = events,
		kills = kills, killsn = killsn, kstride = report.kills_stride or 3,
		kt_stride = report.killt_stride or 2,
		bosses_slain = bosses_slain, has_combat = has_combat,
	}
	self._duration = report.duration or 0
	self._heat = nil
	self._heat_filter = nil
	self._spark = nil
	self._yaw = 0
	self._pitch = RP_TILT
	self._orbit = false

	-- floors from the map + a sensible default focus
	self._floors = self:_floors_for(rv.map)
	self._focus = self:_default_focus(rv.map)

	-- legacy paths (recorded without elevation) draw at the dominant floor's
	-- height, not the map's absolute lowest point (which dangles them in space)
	self._flat_z = nil

	if self._floors then
		local best

		for _, fl in ipairs(self._floors) do
			if not best or fl.count > best.count then
				best = fl
			end
		end

		self._flat_z = best and best.zmid or nil
	end
	self._zoom = 1
	self._pan_x, self._pan_y = 0, 0
	self._time = nil
	self._playing = false
	self._speed = 1
	self._follow = false
	self._feed_scroll = 0

	-- auto-debrief: play the whole run back like a after-action holo-recording
	if self._auto_play_pending then
		self._auto_play_pending = false
		self._time = 0
		self._playing = true
		self._follow = true
		self._focus = nil -- follow-cam works across floors; don't hide any
		self._zoom = 2.2
		self._pitch = 0.62 -- a touch of 3D for the cinematic replay

		local speed = tonumber(safe(function()
			return mod:get("auto_replay_speed")
		end))

		self._speed = speed or 8
	end

	return self._cache
end

-- Agglomerative floor clustering: bin triangle heights, merge nearest bands
-- until the gap exceeds FLOOR_GAP or we are down to MAX_FLOORS.
function View:_floors_for(map)
	if not map or not map.t or not map.tri_count then
		return nil
	end

	local t = map.t
	local bins = {}

	for i = 0, map.tri_count - 1 do
		local z = math.floor(t[i * 7 + 7])

		bins[z] = (bins[z] or 0) + 1
	end

	local zs = {}

	for z in pairs(bins) do
		zs[#zs + 1] = z
	end

	table.sort(zs)

	if #zs == 0 then
		return nil
	end

	local floors = {}

	for _, z in ipairs(zs) do
		floors[#floors + 1] = { zmin = z, zmax = z + 1, count = bins[z] }
	end

	local function smallest_gap()
		local bi, bg = nil, math.huge

		for i = 1, #floors - 1 do
			local g = floors[i + 1].zmin - floors[i].zmax

			if g < bg then
				bg, bi = g, i
			end
		end

		return bi, bg
	end

	while #floors > 1 do
		local i, g = smallest_gap()

		if not i or (g > FLOOR_GAP and #floors <= MAX_FLOORS) then
			break
		end

		floors[i].zmax = floors[i + 1].zmax
		floors[i].count = floors[i].count + floors[i + 1].count
		table.remove(floors, i + 1)
	end

	for _, f in ipairs(floors) do
		f.zmid = (f.zmin + f.zmax) * 0.5
	end

	return floors
end

-- Default to the floor holding the most player-path samples (where the run
-- actually happened), so it opens somewhere useful rather than on a blob.
-- Default to the floor that holds the most player down/death events (where the
-- run's drama was), else the floor with the most geometry.
function View:_default_focus(map)
	if not self._floors or not self._cache then
		return nil
	end

	local votes = {}

	for _, ev in ipairs(self._cache.events) do
		for i = 1, #self._floors do
			local fl = self._floors[i]

			if ev.z >= fl.zmin - 1.5 and ev.z <= fl.zmax + 1.5 then
				votes[i] = (votes[i] or 0) + 1
				break
			end
		end
	end

	local best, bi = -1, nil

	for i = 1, #self._floors do
		local score = (votes[i] or 0) * 10000 + self._floors[i].count

		if score > best then
			best, bi = score, i
		end
	end

	return bi
end

-- Consecutive path samples further apart than this are a teleport (Mortis
-- Trials arena transitions, respawns), not movement: don't draw or lerp them.
local TELEPORT_JUMP_SQ = 40 * 40

-- Auspex depth ramp for floor geometry: the hive's depths sink into murk,
-- higher levels rise into pale phosphor (th = 0 lowest .. 1 highest).
local function floor_rgb(th)
	return 52 + 96 * th, 68 + 116 * th, 64 + 100 * th
end

-- Interpolate a player's position (and elevation, when recorded) at replay
-- time T. Paths are "x,y,t" in old archives, "x,y,z,t" from v3.2 on.
local function pos_at(p, T)
	local ps = p.ps or 3
	local n = math.floor(p.pathn / ps)

	if n == 0 then
		return nil
	end

	local path = p.path
	local has_z = ps >= 4

	local function point(i) -- 0-based sample index
		local o = i * ps

		return path[o + 1], path[o + 2], has_z and path[o + 3] or nil, path[o + ps]
	end

	local x0, y0, z0, t0 = point(0)

	if T <= t0 then
		return x0, y0, z0
	end

	local xl, yl, zl, tl = point(n - 1)

	if T >= tl then
		return xl, yl, zl
	end

	for i = 1, n - 1 do
		local ax, ay, az, at = point(i - 1)
		local bx, by, bz, bt = point(i)

		if T >= at and T <= bt then
			local f = (bt > at) and (T - at) / (bt - at) or 0
			local dx, dy = bx - ax, by - ay

			-- teleports snap to the nearer end instead of gliding across the map
			if dx * dx + dy * dy > TELEPORT_JUMP_SQ then
				if f < 0.5 then
					return ax, ay, az
				end

				return bx, by, bz
			end

			return ax + dx * f, ay + dy * f, (az and bz) and (az + (bz - az) * f) or nil
		end
	end

	return x0, y0, z0
end

-- ---------------------------------------------------------------------------
-- Render.
-- ---------------------------------------------------------------------------
function View:_render(ui_renderer, render_settings, t)
	local gui = ui_renderer.gui
	local scale = ui_renderer.scale or (render_settings and render_settings.scale) or 1

	self._draw_scale = scale
	refresh_screen_size(scale)

	local am = render_settings and render_settings.alpha_multiplier or 1
	local layer0 = (render_settings and render_settings.start_layer or 0) + 10
	local sw, sh = SCREEN_W, SCREEN_H

	self._buttons, self._markers, self._event_rows = {}, {}, {}

	draw_rect(gui, scale, 0, 0, sw, sh, layer0, Color(252 * am, 5, 7, 9))

	local rv = mod.report_view and mod.report_view()

	if not rv then
		return
	end

	local data = self:_sync(rv)
	local runs = rv.runs or {}

	self._layer_now = rv.layer

	self:_text_at("++ MISSION DEBRIEF ++", M + 4, M + 10, 520, 28, 22, { 216, 236, 228 }, 244 * am, layer0 + 60, "left")
	self:_text_at("MOURNINGSTAR TACTICAL ARCHIVE // COGITATOR RECALL", M + 6, M + 33, 620, 14, 10,
		{ 136, 178, 170 }, 182 * am, layer0 + 60, "left")
	draw_rect(gui, scale, M, M + 44, sw - 2 * M, 1.25, layer0 + 40, Color(120 * am, 140, 196, 184))

	-- top-right controls
	local top_y = M + 2
	local x = sw - M - 96

	self:_button(gui, scale, am, layer0 + 40, x, top_y, 92, 28, "CLOSE", { action = "close" })
	x = x - 8 - 92

	for _, ol in ipairs({ { "KILLZONES", "kills" }, { "PRESENCE", "time" }, { "ROUTES", "path" } }) do
		self:_button(gui, scale, am, layer0 + 40, x, top_y, 88, 28, ol[1], { action = "layer", arg = ol[2] },
			rv.layer == ol[2])
		x = x - 6 - 88
	end

	if #runs == 0 then
		self:_text_at("No missions recorded yet. Play a run to build your archive.",
			sw * 0.5, sh * 0.5, 900, 24, 16, { 150, 190, 182 }, 180 * am, layer0 + 60)

		return
	end

	self:_draw_run_list(gui, scale, am, layer0, rv, runs)
	self:_draw_map(gui, scale, am, layer0, rv, data)
	self:_draw_event_feed(gui, scale, am, layer0, data)
	self:_draw_timeline(gui, scale, am, layer0, data)
	self:_draw_stats(gui, scale, am, layer0, rv.report, data)
	self:_draw_tooltip(gui, scale, am, layer0)
end

function View:_button(gui, s, am, layer, x, y, w, h, label, action, active)
	local cx, cy = self._cursor[1], self._cursor[2]
	local hover = cx >= x and cx <= x + w and cy >= y and cy <= y + h
	local a = active and 210 or (hover and 200 or 150)

	draw_rect(gui, s, x, y, w, h, layer, Color(a * am, active and 26 or 14, active and 66 or 30, active and 62 or 30))
	draw_rect_outline(gui, s, x, y, w, h, 1.25, layer + 1, Color((active or hover) and 230 * am or 150 * am, 130, 190, 178))
	self:_text_at(label, x + w * 0.5, y + h * 0.5, w - 6, 18, 13,
		active and { 235, 246, 238 } or { 196, 220, 214 }, 240 * am, layer + 2)

	action.x, action.y, action.w, action.h = x, y, w, h
	self._buttons[#self._buttons + 1] = action
end

function View:_draw_run_list(gui, s, am, layer0, rv, runs)
	local lx, ly = M, M + TITLE_H
	local lh = math.floor((SCREEN_H - ly - M) * 0.42)

	self._list_h = lh

	draw_rect(gui, s, lx - 4, ly - 4, LIST_W + 8, lh + 8, layer0 + 8, Color(170 * am, 0, 0, 0))
	self:_skin_at(MAT.panel, lx - 4, ly - 4, LIST_W + 8, lh + 8, { 150 * am, 50, 70, 66 }, layer0 + 9)
	draw_rect_outline(gui, s, lx - 4, ly - 4, LIST_W + 8, lh + 8, 1.25, layer0 + 16, Color(150 * am, 126, 180, 170))

	local row_h = 62
	local vis = math.max(1, math.floor(lh / row_h))
	local first = math.max(1, math.min(rv.sel - math.floor(vis / 2), #runs - vis + 1))

	for i = first, math.min(#runs, first + vis - 1) do
		local r = runs[i]
		local ry = ly + (i - first) * row_h
		local sel = i == rv.sel
		local hover = inside(self._cursor[1], self._cursor[2], { x = lx, y = ry, w = LIST_W, h = row_h - 4 })

		if sel or hover then
			self:_skin_at(MAT.panel_fill, lx, ry, LIST_W, row_h - 4, { (sel and 200 or 120) * am, 24, 54, 52 }, layer0 + 10)
		end

		if sel then
			draw_rect(gui, s, lx, ry, 3, row_h - 4, layer0 + 17, Color(240 * am, 120, 235, 210))

			-- delete control on the selected run: first click arms, second
			-- deletes. Same chrome as _button, tinted for a destructive action.
			local armed = self._confirm_delete == r.id
			local bw, bh = armed and 60 or 46, 20
			local bx, by = lx + LIST_W - bw - 10, ry + 8
			local bhover = inside(self._cursor[1], self._cursor[2], { x = bx, y = by, w = bw, h = bh })
			local ba = armed and 215 or (bhover and 200 or 135)

			draw_rect(gui, s, bx, by, bw, bh, layer0 + 21,
				Color(ba * am, armed and 92 or 38, armed and 24 or 18, armed and 22 or 16))
			draw_rect_outline(gui, s, bx, by, bw, bh, 1.25, layer0 + 22,
				Color((armed or bhover) and 230 * am or 160 * am, 222, 130, 118))
			self:_text_at(armed and "SURE?" or "DEL", bx + bw * 0.5, by + bh * 0.5, bw - 6, 18, 12,
				armed and { 255, 210, 200 } or { 226, 170, 160 }, 240 * am, layer0 + 23)

			self._buttons[#self._buttons + 1] = { x = bx, y = by, w = bw, h = bh, action = "delete", id = r.id }

			-- Favorite toggle: protected reports are exempt from automatic
			-- retention pruning but can still be deleted manually.
			local fw, fh = r.favorite and 48 or 38, 20
			local fx, fy = bx - fw - 6, by
			local fhover = inside(self._cursor[1], self._cursor[2], { x = fx, y = fy, w = fw, h = fh })
			local fa = r.favorite and 215 or (fhover and 190 or 125)

			draw_rect(gui, s, fx, fy, fw, fh, layer0 + 21,
				Color(fa * am, r.favorite and 82 or 30, r.favorite and 66 or 28, 14))
			draw_rect_outline(gui, s, fx, fy, fw, fh, 1.25, layer0 + 22,
				Color((r.favorite or fhover) and 230 * am or 145 * am, 238, 202, 112))
			self:_text_at(r.favorite and "FAVED" or "FAV", fx + fw * 0.5, fy + fh * 0.5, fw - 4, 18, 11,
				r.favorite and { 255, 230, 150 } or { 212, 194, 138 }, 240 * am, layer0 + 23)

			self._buttons[#self._buttons + 1] = { x = fx, y = fy, w = fw, h = fh, action = "favorite", id = r.id }
		end

		local title = (r.favorite and "* " or "") .. run_title(r)

		self:_text_at(title, lx + 12, ry + 13, sel and (LIST_W - 150) or (LIST_W - 24), 18, 14,
			sel and { 230, 244, 236 } or { 186, 210, 202 }, 240 * am, layer0 + 20, "left")

		local meta = fmt_time(r.duration) .. "  ·  " .. (r.downs or 0) .. " downs  ·  " .. (r.deaths or 0) .. " deaths"

		if r.kills and r.kills > 0 then
			meta = meta .. "  ·  " .. r.kills .. " kills"
		end

		if r.players and r.players > 0 then
			meta = meta .. "  ·  " .. r.players .. "p"
		end

		self:_text_at(meta, lx + 12, ry + 31, LIST_W - 24, 14, 11, { 150, 190, 182 }, 200 * am, layer0 + 20, "left")

		local dname, drgb = diff_label(r.difficulty)

		if dname then
			self:_text_at(dname, lx + 12, ry + 47, 130, 13, 10, drgb, 225 * am, layer0 + 20, "left")
		end

		local ago = fmt_ago(r.date)

		if ago then
			self:_text_at(ago, lx + LIST_W - 86, ry + 47, 76, 13, 10, { 132, 168, 162 }, 190 * am, layer0 + 20, "left")
		end

		self._buttons[#self._buttons + 1] = { x = lx, y = ry, w = LIST_W, h = row_h - 4, action = "select", index = i }
	end
end

function View:_draw_map(gui, s, am, layer0, rv, data)
	local region_x = M + LIST_W + 22
	local region_y = M + TITLE_H
	local region_w = SCREEN_W - region_x - M
	local region_h = SCREEN_H - region_y - STATS_H - TIMELINE_H - SPARK_H - M - 16

	self._map_rect = { x = region_x, y = region_y, w = region_w, h = region_h }

	draw_rect(gui, s, region_x - 4, region_y - 4, region_w + 8, region_h + 8, layer0 + 6, Color(150 * am, 0, 0, 0))
	draw_rect_outline(gui, s, region_x - 4, region_y - 4, region_w + 8, region_h + 8, 1.25, layer0 + 40,
		Color(140 * am, 110, 150, 145))
	draw_brackets(gui, s, region_x - 4, region_y - 4, region_w + 8, region_h + 8, 20, 2.5, layer0 + 41,
		Color(220 * am, 150, 214, 198))

	-- floor controls (top of map)
	local n_floors = self._floors and #self._floors or 0
	local flabel = self._focus and ("FLOOR " .. self._focus .. "/" .. n_floors) or ("ALL FLOORS")

	if n_floors > 1 then
		self:_button(gui, s, am, layer0 + 44, region_x + 4, region_y + 4, 30, 26, "<", { action = "floor", arg = -1 })
		self:_button(gui, s, am, layer0 + 44, region_x + 38, region_y + 4, 120, 26, flabel, { action = "floor", arg = 1 })
		self:_button(gui, s, am, layer0 + 44, region_x + 162, region_y + 4, 30, 26, ">", { action = "floor", arg = 1 })
	end

	self:_button(gui, s, am, layer0 + 44, region_x + region_w - 96, region_y + 4, 92, 26, "RECENTER",
		{ action = "recenter" })
	self:_button(gui, s, am, layer0 + 44, region_x + region_w - 96 - 74, region_y + 4, 68, 26, "ORBIT",
		{ action = "orbit" }, self._orbit)

	if self._orbit then
		self:_text_at("drag: rotate  ·  vertical drag: tilt", region_x + 8, region_y + region_h - 12, 260, 14, 10,
			{ 150, 196, 184 }, 195 * am, layer0 + 44, "left")
	end

	-- killzones source filter: whole squad, or one player's attributed kills
	-- (per-player positions exist from v3.1 archives on)
	if rv.layer == "kills" and data and data.has_combat and (data.kt_stride or 2) >= 4 then
		local fx2 = region_x + 4
		local fy2 = region_y + 36

		self:_button(gui, s, am, layer0 + 44, fx2, fy2, 66, 24, "SQUAD",
			{ action = "heatfilter", arg = nil }, self._heat_filter == nil)
		fx2 = fx2 + 70

		for pi = 1, math.min(#data.players, 4) do
			local p = data.players[pi]

			if (p.kills or 0) > 0 then
				local label = tostring(p.name or "?"):sub(1, 10):upper()

				self:_button(gui, s, am, layer0 + 44, fx2, fy2, 94, 24, label,
					{ action = "heatfilter", arg = pi }, self._heat_filter == pi)

				local rgb = player_rgb(p)

				draw_rect(gui, s, fx2 + 3, fy2 + 3, 4, 18, layer0 + 47, Color(240 * am, rgb[1], rgb[2], rgb[3]))
				fx2 = fx2 + 98
			end
		end
	end

	local map = rv.map
	local bounds = (map and mod.map_bounds and mod.map_bounds(map)) or (rv.report and rv.report.bounds and {
		x0 = rv.report.bounds[1], y0 = rv.report.bounds[2], x1 = rv.report.bounds[3],
		y1 = rv.report.bounds[4], z0 = rv.report.bounds[5], z1 = rv.report.bounds[6],
	})

	if not (bounds and data) then
		self:_text_at("No floor plan for this mission - record it to see the map.",
			region_x + region_w * 0.5, region_y + region_h * 0.5, region_w, 22, 15, { 150, 190, 182 }, 175 * am,
			layer0 + 60)
		return
	end

	local b = bounds
	local mcx, mcy = (b.x0 + b.x1) * 0.5, (b.y0 + b.y1) * 0.5
	local map_w = math.max(1, b.x1 - b.x0)
	local map_h = math.max(1, b.y1 - b.y0)
	local z_range = math.max(0, b.z1 - b.z0)

	-- orbit camera: yaw rotates the plan, pitch runs from 1 (pure top-down)
	-- to 0.34 (dramatic 3D); elevation lift grows as the camera comes down
	local tilt = self._pitch or RP_TILT
	local lift = math.max(0.03, RP_HEIGHT + (RP_TILT - tilt) * 0.85)
	local ycos, ysin = math.cos(self._yaw or 0), math.sin(self._yaw or 0)
	local rotated = math.abs(ysin) > 0.03
	local span_w = rotated and (map_w + map_h) * 0.72 or map_w
	local span_h = rotated and span_w or map_h
	local base_fit = math.min(region_w / span_w, region_h / (span_h * tilt + z_range * lift))
	local fit = base_fit * self._zoom
	local rcx = region_x + region_w * 0.5
	local rcy = region_y + region_h * 0.5

	self._mcx, self._mcy, self._fit, self._base_fit = mcx, mcy, fit, base_fit

	-- follow-cam: ease the pan toward the squad centroid at the replay clock
	if self._follow and self._time then
		local fx, fy, n = 0, 0, 0

		for _, p in ipairs(data.players) do
			local lx, ly = pos_at(p, self._time)

			if lx then
				fx, fy, n = fx + lx, fy + ly, n + 1
			end
		end

		if n > 0 then
			local tx = fx / n - mcx
			local ty = fy / n - mcy

			-- Ease on SCREEN error, not world error: the fixed world-space
			-- rate lagged more the further you zoomed in, letting the squad
			-- slide off the panel. Ease harder with zoom, and hard-clamp the
			-- residual so the followed point never leaves the middle of the
			-- region no matter the replay speed.
			local rate = math.min(0.55, 0.14 * math.max(1, self._zoom or 1))

			self._pan_x = self._pan_x + (tx - self._pan_x) * rate
			self._pan_y = self._pan_y + (ty - self._pan_y) * rate

			local max_err = (math.min(region_w, region_h) * 0.30) / math.max(fit, 0.0001)
			local ex, ey = tx - self._pan_x, ty - self._pan_y
			local e2 = ex * ex + ey * ey

			if e2 > max_err * max_err then
				local k = 1 - max_err / math.sqrt(e2)

				self._pan_x = self._pan_x + ex * k
				self._pan_y = self._pan_y + ey * k
			end
		end
	end

	local cxw, cyw = mcx + self._pan_x, mcy + self._pan_y

	local function proj(wx, wy, wz)
		local dx, dy = wx - cxw, wy - cyw
		local rxx = dx * ycos - dy * ysin
		local ryy = dx * ysin + dy * ycos

		return rcx + rxx * fit, rcy - ryy * fit * tilt - ((wz or b.z0) - b.z0) * fit * lift
	end

	-- projection snapshot for cursor -> world (pan drag, zoom, heat hover)
	self._inv = self._inv or {}
	self._inv.fit, self._inv.cxw, self._inv.cyw = fit, cxw, cyw
	self._inv.rcx, self._inv.rcy = rcx, rcy
	self._inv.tilt, self._inv.cos, self._inv.sin = tilt, ycos, ysin

	local focus = self._focus and self._floors and self._floors[self._focus]

	-- geometry: elevation-banded painter's order (low floors first) with the
	-- auspex depth tint, clipped to the map region so nothing spills over the
	-- side panels; focused floor bright, others ghost
	local tris = map.t
	-- Debrief map detail budget (menu-only cost, never gameplay).
	local tri_budget = tonumber(mod:get("perf_debrief_tri_budget")) or MAX_TRIS
	local nT = math.min(map.tri_count, tri_budget)
	local clip_l, clip_t = region_x, region_y
	local clip_r, clip_b = region_x + region_w, region_y + region_h
	local inv_zr = z_range > 0 and (1 / z_range) or 0
	local geo_base = layer0 + 8

	for i = 0, nT - 1 do
		local o = i * 7
		local tz = tris[o + 7]
		local on_floor = (not focus) or (tz >= focus.zmin - 1.5 and tz <= focus.zmax + 1.5)
		local ax, ay = proj(tris[o + 1], tris[o + 2], tz)
		local bx, by = proj(tris[o + 3], tris[o + 4], tz)
		local cx2, cy2 = proj(tris[o + 5], tris[o + 6], tz)
		local minx = math.min(ax, bx, cx2)
		local maxx = math.max(ax, bx, cx2)
		local miny = math.min(ay, by, cy2)
		local maxy = math.max(ay, by, cy2)

		if maxx >= clip_l and minx <= clip_r and maxy >= clip_t and miny <= clip_b then
			local band = math.floor((tz - b.z0) / 3)

			if band < 0 then
				band = 0
			elseif band > 14 then
				band = 14
			end

			local layer = geo_base + band * 2
			local th = (tz - b.z0) * inv_zr

			if on_floor then
				local fr, fg, fb = floor_rgb(th)

				draw_tri_clipped(gui, s, ax + 1.5, ay + 5, bx + 1.5, by + 5, cx2 + 1.5, cy2 + 5,
					clip_l, clip_t, clip_r, clip_b, layer, Color(225 * am, 10, 16, 15))
				draw_tri_clipped(gui, s, ax, ay, bx, by, cx2, cy2,
					clip_l, clip_t, clip_r, clip_b, layer + 1, Color(238 * am, fr, fg, fb))
			else
				draw_tri_clipped(gui, s, ax, ay, bx, by, cx2, cy2,
					clip_l, clip_t, clip_r, clip_b, layer + 1,
					Color(GHOST_A * am, 46 + 40 * th, 62 + 44 * th, 58 + 38 * th))
			end
		end
	end

	local T = self._time

	-- heat overlay + its gradient legend
	if rv.layer == "time" or rv.layer == "kills" then
		self:_draw_heat(gui, s, am, layer0, data, rv.layer, proj, fit)

		local lw, lh = 144, 8
		local lx2 = region_x + region_w - lw - 16
		local ly2 = region_y + region_h - 24
		local steps = 18

		local hlabel = rv.layer ~= "kills" and "SQUAD PRESENCE"
			or (self._heat and self._heat.fname and (tostring(self._heat.fname):upper() .. " - KILLS"))
			or "COMBAT DENSITY"

		self:_text_at(hlabel, lx2 + lw * 0.5, ly2 - 12, lw + 60, 13, 10, { 190, 214, 206 }, 215 * am, layer0 + 45)

		for k = 0, steps - 1 do
			local hr, hg, hb = heat_rgb(k / (steps - 1))

			draw_rect(gui, s, lx2 + k * (lw / steps), ly2, lw / steps + 0.5, lh, layer0 + 45,
				Color(235 * am, hr, hg, hb))
		end

		self:_text_at("LOW", lx2 - 26, ly2 + 4, 26, 12, 9, { 150, 186, 180 }, 195 * am, layer0 + 45, "left")
		self:_text_at("HIGH", lx2 + lw + 6, ly2 + 4, 30, 12, 9, { 150, 186, 180 }, 195 * am, layer0 + 45, "left")
	end

	-- replay badge (top-centre of the map): state + speed + clock
	if T then
		local badge = (self._playing and "REPLAY  x" or "PAUSED  x") .. (self._speed or 1)
			.. "   " .. fmt_time(T)
		local bw = 210

		draw_rect(gui, s, rcx - bw * 0.5, region_y + 6, bw, 24, layer0 + 44, Color(170 * am, 6, 12, 12))
		draw_rect_outline(gui, s, rcx - bw * 0.5, region_y + 6, bw, 24, 1.25, layer0 + 45,
			Color(190 * am, 130, 214, 192))
		self:_text_at(badge, rcx, region_y + 18, bw - 8, 16, 12,
			self._playing and { 168, 240, 208 } or { 220, 214, 160 }, 240 * am, layer0 + 46)
	end

	-- paths (full, or trail up to T during replay)
	if rv.layer == "path" or T then
		local flat_z = self._flat_z

		for _, p in ipairs(data.players) do
			local ps = p.ps or 3
			local has_z = ps >= 4
			local groups = math.floor(p.pathn / ps)

			if groups > 1 then
				local rgb = player_rgb(p)
				local stride = math.max(1, math.floor(groups / 600))
				-- decimated samples sit up to ~stride segments apart, so the
				-- teleport cutoff scales with stride to keep sprints connected
				local jump_limit_sq = TELEPORT_JUMP_SQ * stride * stride
				local prevx, prevy, prevwx, prevwy

				for gi = 0, groups - 1, stride do
					local pt = gi * ps
					local tt = p.path[pt + ps]

					if T and tt > T then
						break
					end

					local wx, wy = p.path[pt + 1], p.path[pt + 2]
					local wz = has_z and p.path[pt + 3] or flat_z
					local mx, my = proj(wx, wy, wz)
					local frac = gi / math.max(1, groups - 1)

					if prevx then
						local jx, jy = wx - prevwx, wy - prevwy

						if jx * jx + jy * jy <= jump_limit_sq then
							-- dark under-stroke keeps the route readable over
							-- bright geometry; early segments used to fade to
							-- alpha 60 and vanish against lit floor plates
							local th = p.is_local and 2.2 or 1.5
							local a = 110 + 105 * frac

							draw_line_clipped(gui, s, prevx, prevy, mx, my, th + 2.4,
								clip_l, clip_t, clip_r, clip_b, layer0 + 40, Color(a * 0.75 * am, 0, 0, 0))
							draw_line_clipped(gui, s, prevx, prevy, mx, my, th,
								clip_l, clip_t, clip_r, clip_b, layer0 + 41, Color(a * am, rgb[1], rgb[2], rgb[3]))
						else
							-- teleport / transit (train rides, respawns): a faint
							-- straight connector instead of a silent gap
							draw_line_clipped(gui, s, prevx, prevy, mx, my, 1,
								clip_l, clip_t, clip_r, clip_b, layer0 + 40, Color(42 * am, rgb[1], rgb[2], rgb[3]))
						end
					end

					prevx, prevy, prevwx, prevwy = mx, my, wx, wy
				end

				-- live position during replay, pinned to the ground by a stem
				if T then
					local lx, ly, lz = pos_at(p, T)

					if lx then
						local mx, my = proj(lx, ly, lz or flat_z)

						if lz then
							local _, gy = proj(lx, ly, nil)
							local drop = gy - my

							if drop > 8 then
								local pin = math.min(drop, 42)

								draw_line(gui, s, mx, my, mx, my + pin, 2.6, layer0 + 40,
									Color(110 * am, 0, 0, 0))
								draw_line(gui, s, mx, my, mx, my + pin, 1.2, layer0 + 41,
									Color(130 * am, rgb[1], rgb[2], rgb[3]))

								if pin >= drop - 1 then
									draw_diamond(gui, s, mx, gy, 2.4, layer0 + 41,
										Color(160 * am, rgb[1], rgb[2], rgb[3]))
								end
							end
						end

						-- offset shadow + dark backing lift the diamond off
						-- route spaghetti and bright geometry alike
						draw_diamond(gui, s, mx + 1.5, my + 2.5, 6, layer0 + 42, Color(120 * am, 0, 0, 0))
						draw_diamond(gui, s, mx, my, 6.5, layer0 + 42, Color(205 * am, 0, 0, 0))
						draw_diamond(gui, s, mx, my, 4.5, layer0 + 43, Color(250 * am, rgb[1], rgb[2], rgb[3]))
						self:_text_at(p.name, mx, my - 12, 120, 14, 11, rgb, 220 * am, layer0 + 60)
					end
				end
			end
		end
	end

	-- down/death/boss markers (all, or those up to T); collect for hover.
	-- Recoveries (4) and boss encounters (5) live in the feed/timeline only.
	for _, ev in ipairs(data.events) do
		if ev.code ~= 4 and ev.code ~= 5 and not (ev.x == 0 and ev.y == 0)
			and (not T or ev.t <= T) then
			local mx, my = proj(ev.x, ev.y, ev.z)

			if mx >= region_x - 20 and mx <= region_x + region_w + 20 and my >= region_y - 20 and my <= region_y + region_h + 20 then
				local recent = T and (T - ev.t) < 3
				local r

				-- short ground pin so lifted markers read at the right height
				-- (clamped: full-length pins on tall maps read as a curtain)
				local _, gy = proj(ev.x, ev.y, nil)
				local drop = gy - my

				if drop > 10 then
					local pin = math.min(drop, 42)

					draw_line(gui, s, mx, my + 4, mx, my + 4 + pin, 1.1, layer0 + 41, Color(70 * am, 190, 214, 202))

					if pin >= drop - 1 then
						draw_diamond(gui, s, mx, gy, 2, layer0 + 41, Color(100 * am, 190, 214, 202))
					end
				end

				-- every event icon sits on a dark backing disc + offset shadow
				-- so it reads as elevated above route lines and lit geometry
				if ev.code == 6 then
					-- boss slain: big skull with a ring, unmistakable
					local br = recent and 19 or 16

					draw_diamond(gui, s, mx + 2, my + 3, br + 2, layer0 + 47, Color(110 * am, 0, 0, 0))
					draw_diamond(gui, s, mx, my, br + 2, layer0 + 48, Color(195 * am, 0, 0, 0))
					draw_ring(gui, s, mx, my, recent and 17 or 14, 2, 16, layer0 + 50,
						Color(230 * am, BOSS_RGB[1], BOSS_RGB[2], BOSS_RGB[3]))
					self:_icon_at(MAT.skull, mx, my, recent and 38 or 32, BOSS_RGB, 250 * am, layer0 + 51)
					r = 17
				elseif ev.code == 3 then
					local br = recent and 15 or 12

					draw_diamond(gui, s, mx + 1.5, my + 2.5, br, layer0 + 47, Color(110 * am, 0, 0, 0))
					draw_diamond(gui, s, mx, my, br, layer0 + 48, Color(195 * am, 0, 0, 0))
					self:_icon_at(MAT.skull, mx, my, recent and 30 or 24, { 255, 92, 84 }, 248 * am, layer0 + 50)
					r = 13
				else
					local col = ev.code == 2 and { 235, 150, 70 } or { 255, 210, 90 }

					draw_diamond(gui, s, mx + 1.5, my + 2.5, 8, layer0 + 47, Color(110 * am, 0, 0, 0))
					draw_diamond(gui, s, mx, my, 8, layer0 + 48, Color(195 * am, 0, 0, 0))
					draw_ring(gui, s, mx, my, recent and 8 or 6, 2, 12, layer0 + 49, Color(250 * am, col[1], col[2], col[3]))
					r = 8
				end

				self._markers[#self._markers + 1] = { x = mx, y = my, r = r, event = ev }
			end
		end
	end

	-- live squad leaderboard during replay
	if T and data.has_combat then
		self:_draw_leaderboard(gui, s, am, layer0, data, T)
	end

	-- compass: true north under any orbit angle (auspex bearing ring)
	local ndx, ndy = -ysin, -ycos * tilt
	local ndl = math.sqrt(ndx * ndx + ndy * ndy)

	if ndl > 0.001 then
		ndx, ndy = ndx / ndl, ndy / ndl

		local cpx = region_x + 26
		local cpy = region_y + region_h - 34

		draw_ring(gui, s, cpx, cpy, 13, 1.5, 16, layer0 + 46, Color(140 * am, 150, 196, 184))
		draw_line(gui, s, cpx - ndx * 8, cpy - ndy * 8, cpx + ndx * 8, cpy + ndy * 8, 1.8, layer0 + 46,
			Color(210 * am, 255, 234, 180))
		draw_tri(gui, s,
			cpx + ndx * 12, cpy + ndy * 12,
			cpx + ndx * 5 - ndy * 4, cpy + ndy * 5 + ndx * 4,
			cpx + ndx * 5 + ndy * 4, cpy + ndy * 5 - ndx * 4,
			layer0 + 46, Color(230 * am, 255, 234, 180))
		self:_text_at("N", cpx + ndx * 22, cpy + ndy * 22, 16, 13, 11, { 255, 240, 190 }, 210 * am, layer0 + 46)
	end
end

-- Kills and damage counting up with the replay clock, re-ranked live.
function View:_draw_leaderboard(gui, s, am, layer0, data, T)
	local rows = {}
	local max_dmg = 1

	for _, p in ipairs(data.players) do
		if (p.dmg or 0) > 0 or (p.kills or 0) > 0 then
			local row = { p = p, kills = kills_at(p, T, data.kt_stride), dmg = dmg_at(p, T) }

			rows[#rows + 1] = row
			max_dmg = math.max(max_dmg, row.dmg)
		end
	end

	if #rows == 0 then
		return
	end

	table.sort(rows, function(a, b)
		if a.dmg ~= b.dmg then
			return a.dmg > b.dmg
		end

		return a.kills > b.kills
	end)

	local mr = self._map_rect
	local w = 256
	local row_h = 32
	local x = mr.x + mr.w - w - 12
	local y = mr.y + 42
	local h = 24 + #rows * row_h + 6

	draw_rect(gui, s, x, y, w, h, layer0 + 52, Color(178 * am, 5, 10, 11))
	draw_rect_outline(gui, s, x, y, w, h, 1.25, layer0 + 53, Color(170 * am, 126, 180, 170))
	self:_text_at("SQUAD PERFORMANCE", x + 10, y + 12, w - 130, 14, 10, { 178, 208, 200 }, 220 * am,
		layer0 + 54, "left")

	-- column headers so the numbers explain themselves
	self:_text_at("KILLS", x + w - 112, y + 12, 44, 13, 9, { 148, 182, 176 }, 205 * am, layer0 + 54, "left")
	self:_text_at("DAMAGE", x + w - 64, y + 12, 58, 13, 9, { 148, 182, 176 }, 205 * am, layer0 + 54, "left")

	for i = 1, #rows do
		local row = rows[i]
		local p = row.p
		local rgb = player_rgb(p)
		local ry = y + 22 + (i - 1) * row_h

		draw_rect(gui, s, x + 10, ry + 4, 9, 9, layer0 + 54, Color(244 * am, rgb[1], rgb[2], rgb[3]))
		self:_text_at((p.icon and (p.icon .. " ") or "") .. tostring(p.name), x + 26, ry + 8, w - 140, 14, 12,
			p.is_local and { 235, 246, 238 } or { 205, 224, 218 }, 240 * am, layer0 + 54, "left")
		self:_text_at(tostring(row.kills), x + w - 112, ry + 8, 44, 14, 12, { 240, 214, 130 }, 240 * am,
			layer0 + 54, "left")
		self:_text_at(fmt_dmg(row.dmg), x + w - 64, ry + 8, 58, 14, 12, { 226, 170, 130 }, 240 * am,
			layer0 + 54, "left")

		-- damage race bar under each row
		draw_rect(gui, s, x + 26, ry + 18, w - 40, 2.5, layer0 + 54, Color(70 * am, 55, 72, 70))
		draw_rect(gui, s, x + 26, ry + 18, (w - 40) * (row.dmg / max_dmg), 2.5, layer0 + 55,
			Color(220 * am, rgb[1], rgb[2], rgb[3]))
	end
end

function View:_draw_heat(gui, s, am, layer0, data, kind, proj, fit)
	local heat = self._heat
	local filter = kind == "kills" and self._heat_filter or nil

	local cell_size = tonumber(mod:get("perf_debrief_heat_cell")) or 4

	-- Cell size is part of the cache identity: without it, changing the
	-- resolution setting would keep serving the grid built at the old size.
	if not heat or heat.kind ~= kind or heat.filter ~= (filter or 0) or heat.cell ~= cell_size then
		local cells, order, maxc = {}, {}, 1
		local CELL = cell_size

		local function bin(x, y)
			local gx, gy = math.floor(x / CELL), math.floor(y / CELL)
			local key = gx .. ":" .. gy
			local c = cells[key]

			if not c then
				c = { gx = gx, gy = gy, c = 0 }
				cells[key] = c
				order[#order + 1] = c
			end

			c.c = c.c + 1
			maxc = math.max(maxc, c.c)
		end

		local fname

		if kind == "kills" and filter and data.players[filter] then
			-- one player's attributed kill positions (v3.1 archives)
			local p = data.players[filter]
			local st = data.kt_stride or 2

			fname = p.name

			if st >= 4 then
				for i = 0, math.floor((p.killtn or 0) / st) - 1 do
					local x, y = p.killt[i * st + 3], p.killt[i * st + 4]

					if not (x == 0 and y == 0) then
						bin(x, y)
					end
				end
			end
		elseif kind == "kills" then
			local stride = data.kstride or 3

			for i = 0, math.floor(data.killsn / stride) - 1 do
				bin(data.kills[i * stride + 1], data.kills[i * stride + 2])
			end
		else
			for _, p in ipairs(data.players) do
				local ps = p.ps or 3

				for i = 0, math.floor(p.pathn / ps) - 1 do
					bin(p.path[i * ps + 1], p.path[i * ps + 2])
				end
			end
		end

		heat = {
			kind = kind, order = order, cells = cells, maxc = maxc, cell = CELL,
			filter = filter or 0, fname = fname,
		}
		self._heat = heat
	end

	local hw = math.max(3, heat.cell * fit)
	local hh = math.max(2, heat.cell * fit * RP_TILT)
	local pad = math.min(1.5, hw * 0.10) -- hairline gaps read as a sensor grid
	local mr = self._map_rect

	for i = 1, #heat.order do
		local c = heat.order[i]
		local hx, hy = proj((c.gx + 0.5) * heat.cell, (c.gy + 0.5) * heat.cell, nil)

		if hx >= mr.x - hw and hx <= mr.x + mr.w + hw and hy >= mr.y - hh and hy <= mr.y + mr.h + hh then
			-- lift the low end so single events still read on the cold ramp
			local v = (c.c / heat.maxc) ^ 0.6
			local hr, hg, hb = heat_rgb(v)

			draw_rect(gui, s, hx - hw * 0.5 + pad, hy - hh * 0.5 + pad, hw - 2 * pad, hh - 2 * pad,
				layer0 + 40, Color((52 + 186 * v) * am, hr, hg, hb))
		end
	end
end

function View:_draw_event_feed(gui, s, am, layer0, data)
	local fx = M
	local fy = M + TITLE_H + (self._list_h or 300) + 12
	local fw = LIST_W
	local fh = SCREEN_H - fy - M

	self._feed_rect = { x = fx, y = fy, w = fw, h = fh }

	draw_rect(gui, s, fx - 4, fy - 4, fw + 8, fh + 8, layer0 + 8, Color(170 * am, 0, 0, 0))
	self:_skin_at(MAT.panel, fx - 4, fy - 4, fw + 8, fh + 8, { 150 * am, 50, 70, 66 }, layer0 + 9)
	draw_rect_outline(gui, s, fx - 4, fy - 4, fw + 8, fh + 8, 1.25, layer0 + 16, Color(150 * am, 126, 180, 170))

	self:_text_at("EVENTS", fx + 10, fy + 12, 200, 16, 13, { 200, 224, 216 }, 232 * am, layer0 + 20, "left")

	local events = data and data.events or {}

	if #events == 0 then
		self:_text_at("No downs or deaths - clean run.", fx + 10, fy + 40, fw - 20, 16, 12, { 150, 190, 182 },
			190 * am, layer0 + 20, "left")
		return
	end

	-- Stream mode: during a replay only list what has already happened, so
	-- events tick in as the playhead passes them. Overview still shows all.
	local n = #events
	local T = self._time

	if T and safe(function()
		return mod:get("feed_stream_replay")
	end) ~= false then
		n = 0

		for i = 1, #events do
			if events[i].t <= T then
				n = i
			else
				break
			end
		end
	end

	local row_h = 30
	local top = fy + 30
	local vis = math.max(1, math.floor((fh - 34) / row_h))
	local maxscroll = math.max(0, n - vis)

	if T and self._playing then
		-- keep the newest events in view while the replay runs
		self._feed_scroll = maxscroll
	end

	self._feed_scroll = math.min(self._feed_scroll, maxscroll)

	local first = 1 + self._feed_scroll

	for i = first, math.min(n, first + vis - 1) do
		local ev = events[i]
		local ry = top + (i - first) * row_h
		local hover = inside(self._cursor[1], self._cursor[2], { x = fx, y = ry, w = fw, h = row_h - 2 })
		local sel = self._time and math.abs(ev.t - self._time) < 0.6

		if hover or sel then
			self:_skin_at(MAT.panel_fill, fx, ry, fw, row_h - 2, { (sel and 180 or 110) * am, 24, 54, 52 }, layer0 + 18)
		end

		draw_rect(gui, s, fx + 6, ry + 6, 8, 8, layer0 + 20,
			Color(240 * am, ev.rgb[1], ev.rgb[2], ev.rgb[3]))

		local verb = DOWN_VERB[ev.code] or "downed"
		local txt

		if ev.code == 2 and ev.cause == "ledge" then
			txt = "hanging from a ledge"
		elseif ev.code == 2 and ev.cause ~= "" then
			txt = "grabbed by " .. ev.cause
		elseif ev.code == 1 and ev.cause ~= "" then
			txt = "downed by " .. ev.cause
		elseif ev.code == 4 and ev.cause ~= "" then
			txt = "revived by " .. ev.cause
		elseif ev.code == 6 and ev.cause ~= "" then
			txt = "slain by " .. ev.cause
		else
			txt = verb
		end

		local col = ev.code == 3 and { 255, 120, 110 }
			or ev.code == 4 and { 140, 225, 152 }
			or (ev.code == 5 or ev.code == 6) and BOSS_RGB
			or (ev.code == 2 and { 240, 180, 110 } or { 240, 220, 130 })

		self:_text_at(fmt_time(ev.t) .. "  " .. (ev.icon and (ev.icon .. " ") or "") .. ev.name,
			fx + 20, ry + 9, fw - 26, 14, 12, { 220, 234, 228 }, 236 * am, layer0 + 20, "left")
		self:_text_at(txt, fx + 20, ry + 22, fw - 26, 12, 11, col, 220 * am, layer0 + 20, "left")

		self._event_rows[#self._event_rows + 1] = { x = fx, y = ry, w = fw, h = row_h - 2, event = ev }
	end

	if maxscroll > 0 then
		self:_text_at("scroll", fx + fw - 48, fy + 12, 40, 14, 10, { 140, 176, 170 }, 170 * am, layer0 + 20, "left")

		-- slim scrollbar showing where the window sits in the feed
		local track_y = top
		local track_h = vis * row_h - 6
		local thumb_h = math.max(18, track_h * vis / n)
		local thumb_y = track_y + (track_h - thumb_h) * (self._feed_scroll / maxscroll)

		draw_rect(gui, s, fx + fw - 5, track_y, 3, track_h, layer0 + 20, Color(90 * am, 60, 84, 80))
		draw_rect(gui, s, fx + fw - 5, thumb_y, 3, thumb_h, layer0 + 21, Color(210 * am, 130, 196, 180))
	end
end

-- Combat-intensity buckets across the run: timed enemy kills (v2 reports)
-- plus downs/deaths weighted heavier. Nil when the run has nothing to plot.
function View:_spark_for(data, dur)
	if self._spark and self._spark.id == data.id then
		return self._spark.maxv > 0 and self._spark or nil
	end

	local B = 72
	local buckets = {}

	for i = 1, B do
		buckets[i] = 0
	end

	if dur > 0 then
		local stride = data.kstride or 3

		if stride >= 4 then
			for i = 0, math.floor(data.killsn / stride) - 1 do
				local kt = data.kills[i * stride + 4]
				local bi = math.max(1, math.min(B, 1 + math.floor(kt / dur * B)))

				buckets[bi] = buckets[bi] + 1
			end
		end

		for _, ev in ipairs(data.events) do
			if ev.code ~= 4 then
				local bi = math.max(1, math.min(B, 1 + math.floor(ev.t / dur * B)))

				buckets[bi] = buckets[bi] + 4
			end
		end
	end

	local maxv = 0

	for i = 1, B do
		maxv = math.max(maxv, buckets[i])
	end

	self._spark = { id = data.id, buckets = buckets, n = B, maxv = maxv }

	return maxv > 0 and self._spark or nil
end

function View:_draw_timeline(gui, s, am, layer0, data)
	local tx = M + LIST_W + 22
	local tw = SCREEN_W - tx - M
	local ty = SCREEN_H - M - STATS_H - TIMELINE_H - 8
	local dur = self._duration or 0

	-- transport controls: play/pause, direct speed chips, follow-cam, overview
	self:_button(gui, s, am, layer0 + 44, tx, ty, 64, TIMELINE_H, self._playing and "PAUSE" or "PLAY",
		{ action = "play" })

	local chip_x = tx + 70

	for i = 1, #SPEEDS do
		local sp = SPEEDS[i]
		local cw = sp >= 10 and 30 or 24

		self:_button(gui, s, am, layer0 + 44, chip_x, ty, cw, TIMELINE_H, tostring(sp),
			{ action = "speed_set", arg = sp }, self._speed == sp)
		chip_x = chip_x + cw + 2
	end

	self:_text_at("x", chip_x + 2, ty + TIMELINE_H * 0.5, 12, 13, 11, { 150, 186, 180 }, 190 * am,
		layer0 + 44, "left")
	chip_x = chip_x + 14

	self:_button(gui, s, am, layer0 + 44, chip_x + 6, ty, 78, TIMELINE_H, "FOLLOW",
		{ action = "follow" }, self._follow)
	self:_button(gui, s, am, layer0 + 44, chip_x + 90, ty, 88, TIMELINE_H, "OVERVIEW", { action = "overview" })

	local bar_x = chip_x + 188
	local bar_w = tw - (bar_x - tx)
	local bar_y = ty + TIMELINE_H * 0.5
	local T = self._time

	self._timeline_rect = { x = bar_x, y = ty, w = bar_w, h = TIMELINE_H }

	-- combat-intensity sparkline above the scrub bar
	local spark = data and self:_spark_for(data, dur)

	if spark then
		local sy = ty - SPARK_H + 2
		local bw = bar_w / spark.n

		self:_text_at("COMBAT INTENSITY", tx + 2, sy + SPARK_H * 0.5 - 2, 290, 13, 10,
			{ 150, 186, 180 }, 190 * am, layer0 + 44, "left")
		draw_rect(gui, s, bar_x, sy + SPARK_H - 5, bar_w, 1, layer0 + 43, Color(110 * am, 70, 92, 88))

		for i = 1, spark.n do
			local v = spark.buckets[i] / spark.maxv

			if v > 0 then
				local bh = math.max(1.5, v * (SPARK_H - 8))
				local bx2 = bar_x + (i - 1) * bw
				local done = not T or ((i - 0.5) / spark.n * dur <= T)
				local hr, hg, hb = heat_rgb(0.35 + v * 0.55)

				draw_rect(gui, s, bx2, sy + SPARK_H - 5 - bh, math.max(1.5, bw - 1.5), bh, layer0 + 44,
					Color((done and 205 or 70) * am, hr, hg, hb))
			end
		end
	end

	draw_rect(gui, s, bar_x, bar_y - 2, bar_w, 4, layer0 + 44, Color(180 * am, 40, 54, 58))

	-- minute graduations
	if dur > 60 then
		for m = 60, dur - 1, 60 do
			local gx = bar_x + (m / dur) * bar_w

			draw_rect(gui, s, gx, bar_y - 4, 1, 8, layer0 + 44, Color(140 * am, 90, 116, 112))
		end
	end

	-- event ticks (deaths tall red, downs amber, recoveries short green)
	if data and dur > 0 then
		for _, ev in ipairs(data.events) do
			local ex = bar_x + (ev.t / dur) * bar_w
			local col = ev.code == 3 and { 255, 110, 100 }
				or ev.code == 4 and { 130, 215, 145 }
				or (ev.code == 5 or ev.code == 6) and BOSS_RGB
				or (ev.code == 2 and { 240, 175, 100 } or { 240, 220, 120 })

			if ev.code == 5 or ev.code == 6 then
				-- bosses read as diamonds on the bar, kills bigger than sightings
				draw_diamond(gui, s, ex, bar_y, ev.code == 6 and 7 or 4.5, layer0 + 46,
					Color(240 * am, col[1], col[2], col[3]))
			else
				local th = ev.code == 3 and (TIMELINE_H - 6) or ev.code == 4 and 10 or (TIMELINE_H - 12)

				draw_rect(gui, s, ex - 1, bar_y - th * 0.5, 2, th, layer0 + 45, Color(230 * am, col[1], col[2], col[3]))
			end
		end
	end

	-- playhead + clock
	if T and dur > 0 then
		local hx = bar_x + (T / dur) * bar_w

		draw_rect(gui, s, hx - 1.5, ty - 2, 3, TIMELINE_H + 4, layer0 + 47, Color(250 * am, 130, 235, 210))
		draw_tri(gui, s, hx - 5, ty - 7, hx + 5, ty - 7, hx, ty - 1, layer0 + 47, Color(250 * am, 130, 235, 210))
		self:_text_at(fmt_time(T) .. " / " .. fmt_time(dur), bar_x + bar_w - 92, ty + TIMELINE_H + 9, 92, 14, 11,
			{ 170, 220, 208 }, 215 * am, layer0 + 48, "left")
	else
		self:_text_at("OVERVIEW - " .. fmt_time(dur) .. " run   (click the bar or PLAY to replay)",
			bar_x + 8, bar_y - 10, bar_w - 16, 14, 11, { 150, 190, 184 }, 190 * am, layer0 + 48, "left")
	end

	-- hovering the bar previews the time it would scrub to
	if dur > 0 and inside(self._cursor[1], self._cursor[2], self._timeline_rect) then
		local frac = math.max(0, math.min(1, (self._cursor[1] - bar_x) / math.max(1, bar_w)))
		local label = fmt_time(frac * dur)
		local lx2 = math.max(bar_x, math.min(self._cursor[1] - 24, bar_x + bar_w - 48))

		draw_rect(gui, s, lx2, ty - 22, 48, 16, layer0 + 49, Color(220 * am, 8, 12, 14))
		self:_text_at(label, lx2 + 24, ty - 14, 46, 13, 11, { 210, 236, 226 }, 240 * am, layer0 + 50)
	end
end

function View:_draw_stats(gui, s, am, layer0, report, data)
	local sx = M + LIST_W + 22
	local sw2 = SCREEN_W - sx - M
	local sy = SCREEN_H - M - STATS_H + 6

	draw_rect(gui, s, sx - 4, sy - 4, sw2 + 8, STATS_H, layer0 + 8, Color(180 * am, 0, 0, 0))
	self:_skin_at(MAT.panel, sx - 4, sy - 4, sw2 + 8, STATS_H, { 150 * am, 50, 70, 66 }, layer0 + 9)
	draw_rect_outline(gui, s, sx - 4, sy - 4, sw2 + 8, STATS_H, 1.25, layer0 + 16, Color(150 * am, 126, 180, 170))

	if not report then
		return
	end

	local td, tk, tdist = 0, 0, 0

	for _, p in ipairs(data.players) do
		td = td + (p.ndowns or 0)
		tk = tk + (p.ndeaths or 0)
		tdist = tdist + (p.dist or 0)
	end

	local nkills = math.floor((data.killsn or 0) / (data.kstride or 3))
	local dur = report.duration or 0

	-- header row: mission title, difficulty, recency
	self:_text_at(run_title(report), sx + 12, sy + 12, sw2 - 320, 20, 17,
		{ 224, 240, 232 }, 244 * am, layer0 + 20, "left")

	local dname, drgb = diff_label(report.difficulty)

	if dname then
		self:_text_at(dname, sx + sw2 - 250, sy + 12, 130, 16, 12, drgb, 240 * am, layer0 + 20, "left")
	end

	local ago = fmt_ago(report.date)

	if ago then
		self:_text_at(ago, sx + sw2 - 110, sy + 12, 100, 16, 11, { 140, 176, 170 }, 200 * am, layer0 + 20, "left")
	end

	local team = string.format("Duration %s   ·   %d downs, %d deaths", fmt_time(dur), td, tk)
	local squad_kills = 0

	for _, p in ipairs(data.players) do
		squad_kills = squad_kills + (p.kills or 0)
	end

	if squad_kills > 0 then
		team = team .. string.format("   ·   %d kills", squad_kills)
	elseif nkills > 0 then
		team = team .. string.format("   ·   %d hostiles destroyed near the squad", nkills)
	end

	if (data.bosses_slain or 0) > 0 then
		team = team .. string.format("   ·   %d boss%s slain", data.bosses_slain,
			data.bosses_slain == 1 and "" or "es")
	end

	if tdist > 0 then
		team = team .. string.format("   ·   %.1f km covered", tdist / 1000)
	end

	self:_text_at(team, sx + 12, sy + 34, sw2 - 24, 16, 12, { 160, 200, 192 }, 212 * am, layer0 + 20, "left")

	-- per-operative leaderboard table: ranked by damage (when the run has
	-- attributed combat data), with a damage race bar as the visual anchor.
	-- While the replay is scrubbed, time-stamped columns show the state at T.
	local T = self._time
	local ranked = {}

	for i = 1, #data.players do
		local p = data.players[i]

		ranked[i] = p
		p._dmg_now = dmg_at(p, T)
		p._kills_now = kills_at(p, T, data.kt_stride)
		p._downs_now, p._deaths_now = downs_at(p, T)
	end

	if data.has_combat then
		table.sort(ranked, function(a, b)
			if a._dmg_now ~= b._dmg_now then
				return a._dmg_now > b._dmg_now
			end

			return a._kills_now > b._kills_now
		end)
	end

	local shown = math.min(#ranked, 4)
	local max_dmg = 1

	for i = 1, shown do
		max_dmg = math.max(max_dmg, ranked[i]._dmg_now or 0)
	end

	local cols = {
		{ label = "KILLS", x = 322, w = 56 },
		{ label = "DAMAGE", x = 388, w = 150 },
		{ label = "TAKEN", x = 562, w = 62 },
		{ label = "WS%", x = 634, w = 46 },
		{ label = "CRIT%", x = 690, w = 50 },
		{ label = "DOWNS", x = 752, w = 54 },
		{ label = "DEATHS", x = 814, w = 58 },
		{ label = "DOWNED", x = 882, w = 62 },
		{ label = "SAVES", x = 952, w = 50 },
		{ label = "AMMO", x = 1010, w = 48 },
		{ label = "MATERIALS", x = 1068, w = 96 },
		{ label = "DIST", x = 1176, w = 70 },
	}

	local head_y = sy + 54

	self:_text_at("OPERATIVE", sx + 34, head_y, 200, 13, 10, { 140, 176, 170 }, 205 * am, layer0 + 20, "left")

	for _, c in ipairs(cols) do
		self:_text_at(c.label, sx + c.x, head_y, c.w, 13, 10, { 140, 176, 170 }, 205 * am, layer0 + 20, "left")
	end

	-- kills/damage/downs/deaths follow the playhead while replaying
	if T then
		self:_text_at("REPLAY @ " .. fmt_time(T), sx + sw2 - 152, head_y, 140, 13, 10,
			{ 150, 226, 196 }, 230 * am, layer0 + 20, "left")
	end

	draw_rect(gui, s, sx + 8, head_y + 8, sw2 - 24, 1, layer0 + 19, Color(110 * am, 100, 132, 126))

	local nc = data.has_combat

	for i = 1, shown do
		local p = ranked[i]
		local rgb = player_rgb(p)
		local ry = sy + 66 + (i - 1) * 23

		if p.is_local then
			draw_rect(gui, s, sx + 6, ry - 3, sw2 - 20, 21, layer0 + 18, Color(70 * am, 26, 58, 54))
		end

		if nc then
			self:_text_at(tostring(i), sx + 10, ry + 6, 16, 14, 11, { 150, 186, 180 }, 210 * am, layer0 + 20, "left")
		end

		draw_rect(gui, s, sx + 22, ry + 1, 9, 9, layer0 + 19, Color(244 * am, rgb[1], rgb[2], rgb[3]))

		local label = (p.icon and (p.icon .. " ") or "") .. p.name
			.. (p.is_local and " (you)" or (p.is_bot and " [BOT]" or ""))

		self:_text_at(label, sx + 36, ry + 6, 276, 15, 12,
			p.is_local and { 235, 246, 238 } or { 208, 226, 220 }, 240 * am, layer0 + 20, "left")

		local ws = (p.hits or 0) > 0 and (math.floor((p.wk or 0) / p.hits * 100 + 0.5) .. "%") or "-"
		local cr = (p.hits or 0) > 0 and (math.floor((p.crit or 0) / p.hits * 100 + 0.5) .. "%") or "-"
		local mats = ((p.plasteel or 0) > 0 or (p.diamantine or 0) > 0)
			and ((p.plasteel or 0) .. " / " .. (p.diamantine or 0)) or "-"
		local dist = (p.dist or 0) >= 1000 and string.format("%.1fkm", p.dist / 1000)
			or (math.floor(p.dist or 0) .. "m")
		local cells = {
			nc and tostring(p._kills_now or 0) or "-",
			nc and fmt_dmg(p._dmg_now) or "-",
			nc and fmt_dmg(p.taken) or "-",
			ws,
			cr,
			tostring(p._downs_now or 0),
			tostring(p._deaths_now or 0),
			p.downtime and (math.floor(p.downtime + 0.5) .. "s") or "-",
			nc and tostring(p.revs or 0) or "-",
			nc and tostring(p.ammo or 0) or "-",
			mats,
			dist,
		}

		for ci = 1, #cols do
			local hot = nc and (ci == 1 or ci == 2)

			self:_text_at(cells[ci], sx + cols[ci].x, ry + 6, cols[ci].w, 15, 12,
				hot and { 232, 198, 138 } or { 172, 204, 196 }, hot and 240 * am or 215 * am, layer0 + 20, "left")
		end

		-- damage race bar under the damage cell
		if nc and (p._dmg_now or 0) > 0 then
			draw_rect(gui, s, sx + 388, ry + 15, 140, 2.5, layer0 + 19, Color(70 * am, 55, 72, 70))
			draw_rect(gui, s, sx + 388, ry + 15, 140 * (p._dmg_now / max_dmg), 2.5, layer0 + 20,
				Color(225 * am, rgb[1], rgb[2], rgb[3]))
		end
	end

	if #ranked > shown then
		self:_text_at("+" .. (#ranked - shown) .. " more", sx + sw2 - 88, sy + 54, 80, 13, 10,
			{ 150, 186, 180 }, 190 * am, layer0 + 20, "left")
	end
end

function View:_tooltip_box(gui, s, am, layer0, lines)
	local n = #lines

	if n == 0 then
		return
	end

	local cx, cy = self._cursor[1], self._cursor[2]
	local longest = 0

	for i = 1, n do
		longest = math.max(longest, #lines[i])
	end

	local w = 16 + longest * 7.0
	local h = 10 + n * 17
	local tx = math.min(cx + 14, SCREEN_W - w - 6)
	local ty = math.max(cy - h - 6, M)

	draw_rect(gui, s, tx, ty, w, h, layer0 + 90, Color(242 * am, 8, 12, 14))
	draw_rect_outline(gui, s, tx, ty, w, h, 1.25, layer0 + 91, Color(220 * am, 130, 190, 178))

	for i = 1, n do
		self:_text_at(lines[i], tx + 8, ty + 5 + (i - 0.5) * 17, w - 12, 16, i == 1 and 12 or 11,
			i == 1 and { 232, 244, 238 } or { 170, 202, 194 }, 245 * am, layer0 + 92, "left")
	end
end

function View:_draw_tooltip(gui, s, am, layer0)
	local cx, cy = self._cursor[1], self._cursor[2]
	local best

	for i = 1, #self._markers do
		local mk = self._markers[i]
		local dx, dy = cx - mk.x, cy - mk.y

		if dx * dx + dy * dy <= (mk.r + 5) * (mk.r + 5) then
			best = mk
			break
		end
	end

	if best then
		local ev = best.event
		local verb = DOWN_VERB[ev.code] or "downed"
		local what = ev.code == 2 and ev.cause == "ledge" and "left hanging from a ledge"
			or (ev.code == 2 and ev.cause ~= "" and ("grabbed by a " .. ev.cause))
			or (ev.code == 1 and ev.cause ~= "" and ("downed by a " .. ev.cause))
			or (ev.code == 6 and ev.cause ~= "" and ("slain by " .. ev.cause))
			or verb

		self:_tooltip_box(gui, s, am, layer0, {
			ev.name .. " " .. what .. "  @" .. fmt_time(ev.t),
			"click to focus the replay there",
		})

		return
	end

	-- no marker under the cursor: if a heat layer is up, inspect its cell
	local heat = self._heat
	local inv = self._inv

	if heat and inv and self._layer_now ~= "path" and heat.kind == self._layer_now
		and inside(cx, cy, self._map_rect) then
		local wx, wy = self:_screen_to_world(cx, cy)

		if not wx then
			return
		end

		local key = math.floor(wx / heat.cell) .. ":" .. math.floor(wy / heat.cell)
		local cell = heat.cells and heat.cells[key]

		if cell and cell.c > 0 then
			local pct = math.floor(cell.c / heat.maxc * 100 + 0.5)
			local lines

			if heat.kind == "kills" and heat.fname then
				lines = {
					cell.c .. (cell.c == 1 and " kill by " or " kills by ") .. heat.fname .. " in this zone",
					pct .. "% of their hottest cell",
				}
			elseif heat.kind == "kills" then
				lines = {
					cell.c .. (cell.c == 1 and " enemy destroyed in this zone" or " enemies destroyed in this zone"),
					pct .. "% of the run's hottest cell",
				}
			else
				lines = {
					"squad presence: ~" .. math.floor(cell.c * 1.5 + 0.5) .. "s in this zone",
					pct .. "% of the most-camped cell",
				}
			end

			self:_tooltip_box(gui, s, am, layer0, lines)
		end
	end
end

-- Offline verifier hook; unused in game.
mod.__test_report_view = {
	clip_line = clip_line,
}

return View
