local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UISettings = require("scripts/settings/ui/ui_settings")

require("scripts/ui/hud/elements/hud_element_base")

local mod = get_mod("strikemap")

local SCREEN_W = UIWorkspaceSettings.screen.size[1]
local SCREEN_H = UIWorkspaceSettings.screen.size[2]

-- The static 1920x1080 workspace is only the size of the screen at 16:9. On
-- ultrawide the virtual space is wider (real resolution / UI scale), and
-- anchoring to 1920 pushes "right"/"center" well left of where they belong.
local function virtual_screen_size(draw_scale)
	local rl = rawget(_G, "RESOLUTION_LOOKUP")
	local w = rl and tonumber(rl.width)
	local h = rl and tonumber(rl.height)

	if w and h and draw_scale and draw_scale > 0 then
		return w / draw_scale, h / draw_scale
	end

	return SCREEN_W, SCREEN_H
end

local MARGIN_X = 28
local MARGIN_TOP = 140
local MARGIN_BOTTOM = 170

local BASE_LAYER = 120
local ICON_LAYER = 150
local MAX_TRIS_PER_FRAME = 1400
local SKIN_POOL = 24
local ICON_POOL = 160
local TEXT_POOL = 80

-- Full-map (overview) projection tuning.
local FM_MARGIN = 84
local FM_TITLE_H = 60
local FM_TILT = 0.60       -- vertical squash: cos of the viewing pitch
local FM_HEIGHT = 0.55     -- screen rise per metre of elevation (x fit)

-- Pitch presets, cycled with the strikemap key while the full map is open.
local FM_PITCH_PRESETS = {
	{ tilt = 1.0, lift = 0.06, label = "TOP-DOWN" },
	{ tilt = FM_TILT, lift = FM_HEIGHT, label = "TACTICAL" },
	{ tilt = 0.38, lift = 0.85, label = "LOW ORBIT" },
}
local FM_BAND = 2.5        -- metres per height/shading band
local FM_MAX_BAND = 22
local MAX_FULLMAP_TRIS = 12000

-- Once elevation is anchored to the navmesh under the player, small ramps,
-- kerbs and recording noise should remain one floor. 1.5 m is comfortably
-- above a one-foot step while still separating Darktide's actual decks.
local CURRENT_FLOOR_DZ = 1.5
local FAR_BELOW_DZ = 7
local FLOOR_CROSSFADE_DZ = 0.75
-- Markers this far off the player's floor get dimmed.
local MARKER_DIM_DZ = 4.5
local SIGHT_CONE_RANGE = 90
local SIGHT_CONE_HALF_ANGLE = 62 * math.pi / 180
local SIGHT_CONE_SEGMENTS = 9

-- Quiet neutral elevation palette. The current deck carries the contrast;
-- other decks recede mostly through opacity instead of competing hues.
local FLOOR_RGB = {
	far_below = { 58, 66, 78 },
	below = { 92, 102, 116 },
	current = { 168, 178, 190 },
	above = { 120, 140, 160 },
}

-- Tactical palette, matched to the AAA preview stills (tools/previews/).
-- One flat neutral silver carries the walkable mass; bone wall strokes carry
-- the structure; below decks keep dimmer fill so ledges never face a void.
local TACTICAL_FLOOR_RGB = {
	far_below = { 78, 86, 84 },
	below = { 110, 118, 114 },
	current = { 168, 172, 166 },
	above = { 150, 159, 161 },
}
local TACTICAL_WALL_RGB = { 228, 224, 205 }
local TACTICAL_INK_RGB = { 38, 45, 43 }
local TACTICAL_UNDER_RGB = { 8, 11, 10 }
-- The hero surface's distance gradient: warm bone near the player rolling to
-- cool steel at range (the mockup's lamp-lit fade), with one uniform faint
-- wash for every off-level deck.
local TACTICAL_NEAR_RGB = { 186, 183, 168 }
local TACTICAL_FAR_RGB = { 118, 126, 130 }
local TACTICAL_CTX_RGB = { 88, 95, 97 }
-- Full-brightness fill band around the active floor; beyond it fill dims
-- CONTINUOUSLY with height distance (never discrete tiers - they checkerboard
-- on banded terrain).
local FILL_BAND = CURRENT_FLOOR_DZ + FLOOR_CROSSFADE_DZ

-- Mockup-parity polish (mirrored by tools/render_tactical_preview.py, style
-- "aaa"): below decks carry the fine world-anchored line pattern, gentle
-- ramps carry diagonal incline ink, and a panel-space rear fade + player
-- lamp glow sit ON TOP of the static cartography. The overlays are
-- screen-anchored, so the map itself never pops while walking - explicitly
-- NOT fog of war.
local BELOW_HATCH_RGB = { 132, 140, 138 }
local FAR_HATCH_RGB = { 92, 100, 98 }
local SLOPE_INK_RGB = { 44, 52, 49 }
local REAR_VEIL_RGB = { 5, 8, 8 }
local GLOW_RGB = { 255, 241, 205 }
local REAR_VEIL_STEPS = 24
local REAR_VEIL_STEP_ALPHA = 10
local GLOW_STEPS = 14
local GLOW_STEP_ALPHA = 5
local GLOW_RADIUS_FRAC = 0.16
local SLOPE_ANCHOR_RADIUS = 3.4
local SLOPE_MIN_SPAN = 1.6

local Gui_triangle = Gui.triangle

-- All materials below were verified rendering in-game by the old radar mod.
local MAT = {
	panel = "content/ui/materials/backgrounds/terminal_basic",
	panel_fill = "content/ui/materials/backgrounds/default_square",
	panel_gradient = "content/ui/materials/gradients/gradient_vertical",
	shadow = "content/ui/materials/frames/dropshadow_heavy",
	inner_shadow = "content/ui/materials/frames/inner_shadow_medium",
	frame = "content/ui/materials/frames/frame_tile_2px",
	corner = "content/ui/materials/frames/frame_corner_2px",
	auspex = "content/ui/materials/icons/pocketables/hud/auspex_scanner",
	enemy = "content/ui/materials/hud/interactions/icons/enemy",
	enemy_priority = "content/ui/materials/hud/interactions/icons/enemy_priority",
	skull = "content/ui/materials/icons/difficulty/difficulty_skull_damnation",
	medicae = "content/ui/materials/hud/communication_wheel/icons/health",
	objective = "content/ui/materials/hud/interactions/icons/objective_main",
	ammo = "content/ui/materials/hud/interactions/icons/ammunition",
	grenade = "content/ui/materials/hud/interactions/icons/grenade",
	ammo_crate = "content/ui/materials/hud/interactions/icons/pocketable_ammo",
	med_crate = "content/ui/materials/hud/interactions/icons/pocketable_medkit",
	stimm_ability = "content/ui/materials/hud/interactions/icons/pocketable_syringe_ability",
	stimm_corruption = "content/ui/materials/hud/interactions/icons/pocketable_syringe_corruption",
	stimm_power = "content/ui/materials/hud/interactions/icons/pocketable_syringe_power",
	stimm_speed = "content/ui/materials/hud/interactions/icons/pocketable_syringe_speed",
	pickup = "content/ui/materials/hud/interactions/icons/default",
	ring = "content/ui/materials/base/ui_portrait_frame_base",
}

local COLOR_NAMES = {
	"red",
	"crimson",
	"scarlet",
	"vermilion",
	"coral",
	"salmon",
	"orange",
	"tangerine",
	"amber",
	"gold",
	"yellow",
	"lemon",
	"chartreuse",
	"lime",
	"green",
	"emerald",
	"jade",
	"mint",
	"teal",
	"turquoise",
	"cyan",
	"aqua",
	"sky",
	"azure",
	"blue",
	"cobalt",
	"indigo",
	"violet",
	"purple",
	"plum",
	"magenta",
	"pink",
	"hot_pink",
	"rose",
	"lavender",
	"white",
	"ivory",
	"silver",
	"steel",
}

-- Named palette for the colour dropdowns (r, g, b).
local PALETTE = {
	red = { 255, 92, 74 },
	crimson = { 220, 38, 70 },
	scarlet = { 255, 68, 58 },
	vermilion = { 255, 86, 40 },
	coral = { 255, 116, 92 },
	salmon = { 255, 142, 124 },
	orange = { 255, 150, 60 },
	tangerine = { 255, 174, 68 },
	amber = { 255, 190, 70 },
	gold = { 240, 200, 110 },
	yellow = { 255, 232, 96 },
	lemon = { 246, 244, 118 },
	chartreuse = { 190, 236, 82 },
	lime = { 142, 230, 86 },
	green = { 96, 220, 130 },
	emerald = { 72, 216, 154 },
	jade = { 84, 205, 170 },
	mint = { 126, 236, 194 },
	teal = { 72, 202, 202 },
	turquoise = { 72, 224, 220 },
	cyan = { 110, 214, 235 },
	aqua = { 102, 235, 255 },
	sky = { 120, 200, 255 },
	azure = { 92, 174, 255 },
	blue = { 116, 164, 255 },
	cobalt = { 80, 122, 245 },
	indigo = { 126, 112, 235 },
	violet = { 168, 116, 240 },
	purple = { 190, 126, 235 },
	plum = { 205, 116, 210 },
	magenta = { 238, 94, 220 },
	pink = { 255, 126, 194 },
	hot_pink = { 255, 92, 174 },
	rose = { 255, 112, 150 },
	lavender = { 210, 178, 255 },
	white = { 236, 236, 236 },
	ivory = { 246, 238, 198 },
	silver = { 192, 205, 218 },
	steel = { 148, 168, 190 },
}

local ENEMY_TYPE_DEFAULTS = {
	chaos_poxwalker = { color = "red", icon = "dot" },
	chaos_newly_infected = { color = "red", icon = "dot" },
	chaos_lesser_mutated_poxwalker = { color = "red", icon = "dot" },
	chaos_mutated_poxwalker = { color = "red", icon = "dot" },
	chaos_armored_infected = { color = "red", icon = "dot" },
	renegade_melee = { color = "red", icon = "dot" },
	renegade_assault = { color = "red", icon = "dot" },
	renegade_rifleman = { color = "red", icon = "dot" },
	cultist_melee = { color = "red", icon = "dot" },
	cultist_assault = { color = "red", icon = "dot" },
	cultist_rifleman = { color = "red", icon = "dot" },
	renegade_executor = { color = "orange", icon = "enemy" },
	chaos_ogryn_executor = { color = "orange", icon = "enemy" },
	chaos_ogryn_bulwark = { color = "orange", icon = "enemy" },
	chaos_ogryn_gunner = { color = "orange", icon = "enemy" },
	renegade_berzerker = { color = "orange", icon = "enemy" },
	cultist_berzerker = { color = "orange", icon = "enemy" },
	renegade_gunner = { color = "orange", icon = "enemy" },
	cultist_gunner = { color = "orange", icon = "enemy" },
	renegade_shocktrooper = { color = "orange", icon = "enemy" },
	cultist_shocktrooper = { color = "orange", icon = "enemy" },
	renegade_plasma_gunner = { color = "orange", icon = "enemy" },
	renegade_flamer = { color = "yellow", icon = "enemy_priority" },
	cultist_flamer = { color = "yellow", icon = "enemy_priority" },
	renegade_netgunner = { color = "yellow", icon = "enemy_priority" },
	renegade_grenadier = { color = "yellow", icon = "enemy_priority" },
	cultist_grenadier = { color = "yellow", icon = "enemy_priority" },
	renegade_sniper = { color = "yellow", icon = "enemy_priority" },
	cultist_mutant = { color = "yellow", icon = "enemy_priority" },
	chaos_hound = { color = "yellow", icon = "enemy_priority" },
	chaos_armored_hound = { color = "yellow", icon = "enemy_priority" },
	chaos_ogryn_houndmaster = { color = "yellow", icon = "enemy_priority" },
	chaos_poxwalker_bomber = { color = "yellow", icon = "enemy_priority" },
	renegade_radio_operator = { color = "yellow", icon = "enemy_priority" },
	cultist_ritualist = { color = "yellow", icon = "enemy_priority" },
	chaos_plague_ogryn = { color = "red", icon = "enemy_priority" },
	chaos_spawn = { color = "red", icon = "enemy_priority" },
	chaos_beast_of_nurgle = { color = "red", icon = "enemy_priority" },
	chaos_daemonhost = { color = "red", icon = "enemy_priority" },
	renegade_captain = { color = "red", icon = "enemy_priority" },
	cultist_captain = { color = "red", icon = "enemy_priority" },
	renegade_twin_captain = { color = "red", icon = "enemy_priority" },
	cultist_twin_captain = { color = "red", icon = "enemy_priority" },
}

local function palette_rgb(name, fallback)
	return PALETTE[name] or PALETTE[fallback] or PALETTE.white
end

local function auto_enemy_color_name(enemy_type, fallback)
	return fallback
end

local PING_KIND_VISUALS = {
	ammo = { material = MAT.ammo, color = "amber", size = 16 },
	grenade = { material = MAT.grenade, color = "orange", size = 16 },
	ammo_crate = { material = MAT.ammo_crate, color = "amber", size = 20 },
	med_crate = { material = MAT.med_crate, color = "green", size = 20 },
	medicae = { material = MAT.medicae, color = "green", size = 20 },
	book = { style = "diamond", color = "violet", size = 17 },
	material = { style = "dot", color = "steel", size = 12 },
	luggable = { style = "square", color = "cyan", size = 17 },
	pickup = { material = MAT.pickup, color = "steel", size = 16 },
	stimm_ability = { material = MAT.stimm_ability, color = "cyan", size = 19 },
	stimm_corruption = { material = MAT.stimm_corruption, color = "purple", size = 19 },
	stimm_power = { material = MAT.stimm_power, color = "red", size = 19 },
	stimm_speed = { material = MAT.stimm_speed, color = "blue", size = 19 },
	stimm_broker = { material = MAT.stimm_ability, color = "gold", size = 19 },
}

-- ---------------------------------------------------------------------------
-- Geometry helpers (module-level reused buffers; one element instance draws
-- once per frame so this is safe).
-- ---------------------------------------------------------------------------
local _in_x, _in_y = {}, {}
local _out_x, _out_y = {}, {}

-- Sutherland-Hodgman clip of a convex polygon against one rect edge.
-- edge: 1 = x >= bound, 2 = x <= bound, 3 = y >= bound, 4 = y <= bound
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

local function draw_tri(gui, scale, x1, y1, x2, y2, x3, y3, layer, color)
	Gui_triangle(
		gui,
		Vector3(x1 * scale, 0, y1 * scale),
		Vector3(x2 * scale, 0, y2 * scale),
		Vector3(x3 * scale, 0, y3 * scale),
		layer,
		color
	)
end

-- Clip triangle to rect and draw the surviving polygon as a fan.
local function draw_tri_clipped(gui, scale, x1, y1, x2, y2, x3, y3, left, top, right, bottom, layer, color)
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
		draw_tri(gui, scale, _in_x[1], _in_y[1], _in_x[i], _in_y[i], _in_x[i + 1], _in_y[i + 1], layer, color)
	end
end

local function draw_rect(gui, scale, x, y, w, h, layer, color)
	draw_tri(gui, scale, x, y, x + w, y, x + w, y + h, layer, color)
	draw_tri(gui, scale, x, y, x + w, y + h, x, y + h, layer, color)
end

local function draw_rect_outline(gui, scale, x, y, w, h, thickness, layer, color)
	draw_rect(gui, scale, x, y, w, thickness, layer, color)
	draw_rect(gui, scale, x, y + h - thickness, w, thickness, layer, color)
	draw_rect(gui, scale, x, y, thickness, h, layer, color)
	draw_rect(gui, scale, x + w - thickness, y, thickness, h, layer, color)
end

-- Auspex-style corner brackets around a rect (the frame the eye expects on a
-- cogitator readout, without boxing the whole map in).
local function draw_brackets(gui, scale, x, y, w, h, len, thickness, layer, color)
	draw_rect(gui, scale, x, y, len, thickness, layer, color)
	draw_rect(gui, scale, x, y, thickness, len, layer, color)
	draw_rect(gui, scale, x + w - len, y, len, thickness, layer, color)
	draw_rect(gui, scale, x + w - thickness, y, thickness, len, layer, color)
	draw_rect(gui, scale, x, y + h - thickness, len, thickness, layer, color)
	draw_rect(gui, scale, x, y + h - len, thickness, len, layer, color)
	draw_rect(gui, scale, x + w - len, y + h - thickness, len, thickness, layer, color)
	draw_rect(gui, scale, x + w - thickness, y + h - len, thickness, len, layer, color)
end

local function draw_diamond(gui, scale, x, y, r, layer, color)
	draw_tri(gui, scale, x, y - r, x + r, y, x, y + r, layer, color)
	draw_tri(gui, scale, x, y - r, x, y + r, x - r, y, layer, color)
end

local function draw_line(gui, scale, x1, y1, x2, y2, thickness, layer, color)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)

	if len <= 0.001 then
		return
	end

	local nx = -dy / len * thickness * 0.5
	local ny = dx / len * thickness * 0.5

	draw_tri(gui, scale, x1 + nx, y1 + ny, x2 + nx, y2 + ny, x2 - nx, y2 - ny, layer, color)
	draw_tri(gui, scale, x1 + nx, y1 + ny, x2 - nx, y2 - ny, x1 - nx, y1 - ny, layer, color)
end

-- Clip a segment to a rectangle (Liang-Barsky). Stable floor vectors are
-- stored in world space and only clipped after projection; the clip boundary
-- therefore cannot invent or reorder map edges as the player moves.
local function clip_line_rect(x1, y1, x2, y2, left, top, right, bottom)
	local dx, dy = x2 - x1, y2 - y1
	local u0, u1 = 0, 1
	local p = { -dx, dx, -dy, dy }
	local q = { x1 - left, right - x1, y1 - top, bottom - y1 }

	for i = 1, 4 do
		if math.abs(p[i]) < 0.000001 then
			if q[i] < 0 then
				return nil
			end
		else
			local u = q[i] / p[i]

			if p[i] < 0 then
				if u > u1 then return nil end
				if u > u0 then u0 = u end
			else
				if u < u0 then return nil end
				if u < u1 then u1 = u end
			end
		end
	end

	return x1 + dx * u0, y1 + dy * u0, x1 + dx * u1, y1 + dy * u1
end

local function clip_line_circle(x1, y1, x2, y2, ox, oy, radius)
	local dx, dy = x2 - x1, y2 - y1
	local fx, fy = x1 - ox, y1 - oy
	local a = dx * dx + dy * dy

	if a < 0.000001 then
		return nil
	end

	local b = 2 * (fx * dx + fy * dy)
	local c = fx * fx + fy * fy - radius * radius
	local disc = b * b - 4 * a * c
	local inside1 = fx * fx + fy * fy <= radius * radius
	local ex, ey = x2 - ox, y2 - oy
	local inside2 = ex * ex + ey * ey <= radius * radius

	if disc < 0 then
		return inside1 and inside2 and x1 or nil, inside1 and inside2 and y1 or nil,
			inside1 and inside2 and x2 or nil, inside1 and inside2 and y2 or nil
	end

	local root = math.sqrt(disc)
	local ta = (-b - root) / (2 * a)
	local tb = (-b + root) / (2 * a)
	local u0 = inside1 and 0 or math.max(0, ta)
	local u1 = inside2 and 1 or math.min(1, tb)

	if u0 > u1 or u1 < 0 or u0 > 1 then
		return nil
	end

	u0, u1 = math.max(0, u0), math.min(1, u1)
	return x1 + dx * u0, y1 + dy * u0, x1 + dx * u1, y1 + dy * u1
end

-- ---------------------------------------------------------------------------
-- Circle drawing/clipping for the round theme. The circle is treated as a
-- 16-sided tangent polygon for clipping (visually indistinguishable at panel
-- sizes; boundary triangles pay 16 half-plane passes, interior ones a cheap
-- radius test).
-- ---------------------------------------------------------------------------
local NGON = 16
local _ng_nx, _ng_ny = {}, {}

for k = 1, NGON do
	local a = (k - 0.5) * (2 * math.pi / NGON)

	_ng_nx[k] = math.cos(a)
	_ng_ny[k] = math.sin(a)
end

-- Clip polygon against half-plane (x-ox)*nx + (y-oy)*ny <= d.
local function clip_halfplane(in_x, in_y, cnt, out_x, out_y, nx, ny, d, ox, oy)
	local m = 0

	for i = 1, cnt do
		local j = i % cnt + 1
		local xi, yi = in_x[i], in_y[i]
		local xj, yj = in_x[j], in_y[j]
		local vi = (xi - ox) * nx + (yi - oy) * ny - d
		local vj = (xj - ox) * nx + (yj - oy) * ny - d

		if vi <= 0 then
			m = m + 1
			out_x[m], out_y[m] = xi, yi
		end

		if (vi <= 0) ~= (vj <= 0) then
			local t = vi / (vi - vj)

			m = m + 1
			out_x[m] = xi + (xj - xi) * t
			out_y[m] = yi + (yj - yi) * t
		end
	end

	return m
end

local function draw_tri_clipped_circle(gui, scale, x1, y1, x2, y2, x3, y3, ox, oy, r, layer, color)
	_in_x[1], _in_y[1] = x1, y1
	_in_x[2], _in_y[2] = x2, y2
	_in_x[3], _in_y[3] = x3, y3

	local src_x, src_y, dst_x, dst_y = _in_x, _in_y, _out_x, _out_y
	local cnt = 3

	for k = 1, NGON do
		cnt = clip_halfplane(src_x, src_y, cnt, dst_x, dst_y, _ng_nx[k], _ng_ny[k], r, ox, oy)

		if cnt < 3 then
			return
		end

		src_x, src_y, dst_x, dst_y = dst_x, dst_y, src_x, src_y
	end

	for i = 2, cnt - 1 do
		draw_tri(gui, scale, src_x[1], src_y[1], src_x[i], src_y[i], src_x[i + 1], src_y[i + 1], layer, color)
	end
end

local function draw_circle_fill(gui, scale, ox, oy, r, segs, layer, color)
	local step = 2 * math.pi / segs
	local prev_x, prev_y = ox + r, oy

	for k = 1, segs do
		local a = k * step
		local x, y = ox + math.cos(a) * r, oy + math.sin(a) * r

		draw_tri(gui, scale, ox, oy, prev_x, prev_y, x, y, layer, color)
		prev_x, prev_y = x, y
	end
end

local function draw_circle_outline(gui, scale, ox, oy, r, thickness, segs, layer, color)
	local step = 2 * math.pi / segs
	local prev_x, prev_y = ox + r, oy

	for k = 1, segs do
		local a = k * step
		local x, y = ox + math.cos(a) * r, oy + math.sin(a) * r

		draw_line(gui, scale, prev_x, prev_y, x, y, thickness, layer, color)
		prev_x, prev_y = x, y
	end
end

local GATE_EVENT_TTL = 4.5
local GATE_LABEL_TTL = 2.4

-- Draw a physical barrier rather than another point icon. Blocked gates are
-- solid and hatched; a newly-opened gate breaks into phosphor route segments.
-- Returns an optional transient callout for the pooled text layer.
local function draw_live_gate(gui, scale, gate, mission_time, project, layer, alpha_mult)
	if not gate or type(gate.x) ~= "number" or type(gate.y) ~= "number" then
		return nil
	end

	local dx, dy = gate.dx or 1, gate.dy or 0
	local half = gate.half or 1.5
	local x1, y1 = project(gate.x - dx * half, gate.y - dy * half, gate.z)
	local x2, y2 = project(gate.x + dx * half, gate.y + dy * half, gate.z)

	if not x1 or not x2 then
		return nil
	end

	local sx, sy = x2 - x1, y2 - y1
	local len = math.sqrt(sx * sx + sy * sy)

	if len <= 0.5 then
		return nil
	end

	local ux, uy = sx / len, sy / len
	local nx, ny = -uy, ux
	local mx, my = (x1 + x2) * 0.5, (y1 + y2) * 0.5
	local changed_at = tonumber(gate.changed_at)
	local age = changed_at and math.max(0, (mission_time or changed_at) - changed_at) or nil
	local rgb

	if gate.blocked then
		rgb = gate.locked and { 232, 70, 48 } or { 238, 177, 68 }
		local closing = age and (gate.event == "sealed" or gate.event == "locked") and age < 0.55
		local close_progress = closing and math.min(1, age / 0.55) or 1
		local lx, ly = x1 + sx * 0.5 * close_progress, y1 + sy * 0.5 * close_progress
		local rx, ry = x2 - sx * 0.5 * close_progress, y2 - sy * 0.5 * close_progress

		-- Two leaves slam together from the corridor edges rather than popping
		-- instantly into existence.
		draw_line(gui, scale, x1, y1, lx, ly, 5.5, layer, Color(155 * alpha_mult, 5, 7, 7))
		draw_line(gui, scale, rx, ry, x2, y2, 5.5, layer, Color(155 * alpha_mult, 5, 7, 7))
		draw_line(gui, scale, x1, y1, lx, ly, 2.5, layer + 1, Color(235 * alpha_mult, rgb[1], rgb[2], rgb[3]))
		draw_line(gui, scale, rx, ry, x2, y2, 2.5, layer + 1, Color(235 * alpha_mult, rgb[1], rgb[2], rgb[3]))

		for i = 1, math.floor(3 * close_progress + 0.01) do
			local q = i * 0.25
			local hx, hy = x1 + sx * q, y1 + sy * q

			draw_line(gui, scale, hx - nx * 4.5 - ux * 2, hy - ny * 4.5 - uy * 2,
				hx + nx * 4.5 + ux * 2, hy + ny * 4.5 + uy * 2, 1.5, layer + 2,
				Color(215 * alpha_mult, rgb[1], rgb[2], rgb[3]))
		end

		if gate.locked then
			draw_diamond(gui, scale, mx, my, 4.5, layer + 3, Color(225 * alpha_mult, rgb[1], rgb[2], rgb[3]))
			draw_diamond(gui, scale, mx, my, 2.1, layer + 4, Color(235 * alpha_mult, 12, 12, 10))
		end
	else
		rgb = { 82, 226, 185 }
		local burn = age and gate.event == "opened" and math.min(1, age / 0.7) or 1
		local bx1, by1 = mx - sx * 0.5 * burn, my - sy * 0.5 * burn
		local bx2, by2 = mx + sx * 0.5 * burn, my + sy * 0.5 * burn

		draw_line(gui, scale, bx1, by1, bx2, by2, 4.5, layer,
			Color(55 * alpha_mult, rgb[1], rgb[2], rgb[3]))

		for i = 0, 2 do
			local q0 = 0.08 + i * 0.32
			local q1 = q0 + 0.20

			draw_line(gui, scale, x1 + sx * q0, y1 + sy * q0, x1 + sx * q1, y1 + sy * q1,
				2.1, layer + 1, Color(205 * alpha_mult, rgb[1], rgb[2], rgb[3]))
		end
	end

	if age and age <= GATE_EVENT_TTL then
		local event_rgb = (gate.event == "opened" or gate.event == "unlocked") and { 82, 238, 190 } or { 242, 74, 50 }
		local phase = age / GATE_EVENT_TTL
		local ring_alpha = 220 * (1 - phase) * alpha_mult

		for i = 0, 1 do
			local p = (phase + i * 0.42) % 1

			draw_circle_outline(gui, scale, mx, my, 7 + p * 24, 1.7, 18, layer + 4,
				Color(ring_alpha * (1 - p * 0.45), event_rgb[1], event_rgb[2], event_rgb[3]))
		end

		if age <= GATE_LABEL_TTL then
			local labels = {
				opened = "ACCESS OPEN",
				unlocked = "ACCESS GRANTED",
				sealed = "ROUTE SEALED",
				locked = "ROUTE LOCKED",
			}

			return mx, my - 13, labels[gate.event], event_rgb,
				235 * (1 - age / GATE_LABEL_TTL) * alpha_mult
		end
	end

	return mx, my
end

local OBJECTIVE_EVENT_TTL = 5.5

local function draw_tactical_event(gui, scale, event, mission_time, project, layer, alpha_mult)
	if not event or type(event.x) ~= "number" or type(event.y) ~= "number" then
		return nil
	end

	local changed_at = tonumber(event.changed_at)
	local age = changed_at and math.max(0, (mission_time or changed_at) - changed_at) or 0

	if age > OBJECTIVE_EVENT_TTL then
		return nil
	end

	local mx, my = project(event.x, event.y, event.z)

	if not mx then
		return nil
	end

	local label = event.label or "TACTICAL UPDATE"
	local rgb = label == "EXTRACTION OPEN" and { 242, 204, 92 }
		or label == "ROUTE SEALED" and { 242, 74, 50 }
		or { 82, 238, 190 }
	local life = 1 - age / OBJECTIVE_EVENT_TTL
	local base_phase = (age * 0.72) % 1

	for i = 0, 2 do
		local phase = (base_phase + i / 3) % 1
		local radius = 9 + phase * 34
		local a = 190 * life * (1 - phase * 0.55) * alpha_mult

		draw_circle_outline(gui, scale, mx, my, radius, 1.6, 20, layer + i,
			Color(a, rgb[1], rgb[2], rgb[3]))
	end

	local bracket = 9 + math.sin(age * 5) * 1.5

	draw_line(gui, scale, mx - bracket, my, mx - 3, my, 1.5, layer + 4, Color(210 * life * alpha_mult, rgb[1], rgb[2], rgb[3]))
	draw_line(gui, scale, mx + 3, my, mx + bracket, my, 1.5, layer + 4, Color(210 * life * alpha_mult, rgb[1], rgb[2], rgb[3]))
	draw_line(gui, scale, mx, my - bracket, mx, my - 3, 1.5, layer + 4, Color(210 * life * alpha_mult, rgb[1], rgb[2], rgb[3]))
	draw_line(gui, scale, mx, my + 3, mx, my + bracket, 1.5, layer + 4, Color(210 * life * alpha_mult, rgb[1], rgb[2], rgb[3]))

	return mx, my - 16, label, rgb, 235 * math.min(1, life * 2) * alpha_mult
end

-- Per-frame settings snapshot: _draw_widgets bumps _setting_frame once per
-- drawn frame, so every id pays at most ONE live mod:get per frame no matter
-- how many markers read it (the old path re-fetched per marker AND allocated a
-- closure per call). _settings_changed flips when a fetched value differs
-- from the previous frame; settings-derived caches key off it.
local _setting_values = {}
local _setting_fetched = {}
local _setting_frame = 0
local _settings_changed = false

-- Must run at the top of every drawn frame. Without it the snapshot freezes on
-- generation 0 and settings changes never reach the map.
local function advance_setting_frame()
	_setting_frame = _setting_frame + 1
	_settings_changed = false
end

-- True when any id read so far this frame changed value since last frame.
local function settings_changed()
	return _settings_changed
end


local function setting(id, default)
	if _setting_fetched[id] ~= _setting_frame then
		local ok, value = pcall(mod.get, mod, id)

		if not ok then
			value = nil
		end

		if value ~= _setting_values[id] then
			_settings_changed = true
		end

		_setting_values[id] = value
		_setting_fetched[id] = _setting_frame
	end

	local value = _setting_values[id]

	if value ~= nil then
		return value
	end

	return default
end

-- Cosmetic overlays (rear fade, lamp glow, decorative theme rings) are pure
-- triangle cost and carry no map data, so they are the first thing a player
-- short on frames should be able to turn down.
local function effects_quality()
	local q = setting("perf_effects_quality", "high")

	return q == "low" and "low" or q == "off" and "off" or "high"
end

-- Multiplier on step/segment counts for those overlays.
local function effects_scale()
	return effects_quality() == "low" and 0.5 or 1
end

-- Darktide exposes the same archetype symbols used by its nameplates as font
-- glyphs. Resolve them from the Player first, with the live unit-data extension
-- as a fallback for bots / partially replicated profiles. Archetype never
-- changes mid-mission, so a resolved glyph is memoised per player object
-- (weak-keyed; unresolved lookups retry so late-replicating profiles fill in).
local _archetype_icon_cache = setmetatable({}, { __mode = "k" })

local function player_archetype_icon(player)
	local icons = UISettings and UISettings.archetype_font_icon

	if not player or type(icons) ~= "table" then
		return nil
	end

	local cached = _archetype_icon_cache[player]

	if cached then
		return cached
	end

	local archetype
	local ok, value = pcall(function()
		return player.archetype_name and player:archetype_name()
	end)

	if ok then
		archetype = value
	end

	if type(archetype) ~= "string" then
		ok, value = pcall(function()
			local profile = player.profile and player:profile()
			local arch = profile and profile.archetype

			return arch and (arch.name or arch.archetype_name)
		end)

		if ok then
			archetype = value
		end
	end

	if type(archetype) ~= "string" then
		ok, value = pcall(function()
			local unit = player.player_unit
			local ext = unit and ScriptUnit.has_extension(unit, "unit_data_system")

			return ext and ext.archetype_name and ext:archetype_name()
		end)

		if ok then
			archetype = value
		end
	end

	local icon = type(archetype) == "string" and icons[archetype] or nil

	if icon then
		_archetype_icon_cache[player] = icon
	end

	return icon
end

local function draw_arc_outline(gui, scale, ox, oy, radius, thickness, progress, layer, color)
	progress = math.max(0, math.min(1, tonumber(progress) or 0))

	if progress <= 0 then
		return
	end

	local segments = 20
	local count = math.max(1, math.ceil(segments * progress))
	local start = -math.pi * 0.5
	local previous_x, previous_y = ox + math.cos(start) * radius, oy + math.sin(start) * radius

	for i = 1, count do
		local p = math.min(progress, i / segments)
		local angle = start + p * math.pi * 2
		local x, y = ox + math.cos(angle) * radius, oy + math.sin(angle) * radius

		draw_line(gui, scale, previous_x, previous_y, x, y, thickness, layer, color)
		previous_x, previous_y = x, y
	end
end

-- teammate_live_status helpers, hoisted to file scope: the old anonymous
-- pcall closures were re-created per teammate per frame (GC churn + trace
-- aborts on the hot path).
local function ally_status_health(unit, status)
	local health = ScriptUnit.has_extension(unit, "health_system")

	if health and health.current_health_percent then
		status.health = health:current_health_percent()
	end
end

local function ally_status_state(unit, status)
	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")

	if unit_data then
		local character_state = unit_data:read_component("character_state")

		status.downed = character_state and character_state.state_name == "knocked_down" or false
	end

	return unit_data
end

local function ally_status_facing(unit, status)
	local forward = Quaternion.forward(Unit.world_rotation(unit, 1))
	local len = math.sqrt(forward.x * forward.x + forward.y * forward.y)

	if len > 0.001 then
		status.fx, status.fy = forward.x / len, forward.y / len
	end
end

local function ally_slot_badge(visual, inventory, status, slot_name)
	local item = visual.item_from_slot and visual:item_from_slot(slot_name)
	local template = visual.weapon_template_from_slot and visual:weapon_template_from_slot(slot_name)
	local inventory_name = inventory and inventory[slot_name]
	local equipped = item ~= nil or template ~= nil
		or inventory_name ~= nil and inventory_name ~= "not_equipped" and inventory_name ~= "none"

	if not equipped then
		return
	end

	local material = template and template.hud_icon_small
	local name = string.lower(tostring(item and item.name or inventory_name or "")
		.. " " .. tostring(template and (template.name or template.swap_pickup_name or template.give_pickup_name) or ""))
	local badge

	if material and material:find("party_grimoire", 1, true) or name:find("grimoire", 1, true) then
		badge = { kind = "grimoire", material = material or "content/ui/materials/icons/pocketables/hud/small/party_grimoire" }
	elseif material and material:find("party_scripture", 1, true)
		or name:find("scripture", 1, true) or name:find("tome", 1, true) then
		badge = { kind = "scripture", material = material or "content/ui/materials/icons/pocketables/hud/small/party_scripture" }
	elseif slot_name == "slot_luggable" then
		badge = { kind = name:find("battery", 1, true) and "battery" or "objective" }
	elseif name:find("objective", 1, true) or name:find("communication", 1, true)
		or name:find("device", 1, true) or name:find("decoder", 1, true)
		or name:find("prismata", 1, true) or name:find("loot_crate", 1, true) then
		badge = { kind = "objective", material = material }
	end

	if badge and #status.badges < 2 then
		status.badges[#status.badges + 1] = badge
	end
end

local function ally_status_badges(unit, unit_data, status)
	local visual = ScriptUnit.has_extension(unit, "visual_loadout_system")
	local inventory = unit_data and unit_data:read_component("inventory")

	if not visual then
		return
	end

	ally_slot_badge(visual, inventory, status, "slot_luggable")
	ally_slot_badge(visual, inventory, status, "slot_pocketable")
	ally_slot_badge(visual, inventory, status, "slot_pocketable_small")
end

-- Health/state/badge reads are cached per unit for perf_ally_status_rate ms
-- (0 = every frame). Facing is ALWAYS re-read so ally arrows stay smooth.
-- Callers without a clock (offline harness) bypass the cache entirely.
local _ally_status_cache = setmetatable({}, { __mode = "k" })

local function teammate_live_status(unit, now)
	local rate = setting("perf_ally_status_rate", 100)

	if now and type(rate) == "number" and rate > 0 then
		local entry = _ally_status_cache[unit]

		if entry then
			local age = now - entry.at

			if age >= 0 and age * 1000 < rate then
				pcall(ally_status_facing, unit, entry.status)

				return entry.status
			end
		end
	end

	local status = { health = nil, downed = false, fx = 0, fy = 1, badges = {} }

	pcall(ally_status_health, unit, status)

	local ok, unit_data = pcall(ally_status_state, unit, status)

	pcall(ally_status_facing, unit, status)
	pcall(ally_status_badges, unit, ok and unit_data or nil, status)

	if now and type(rate) == "number" and rate > 0 then
		_ally_status_cache[unit] = { status = status, at = now }
	end

	return status
end

mod.__test_teammate_live_status = teammate_live_status

local function draw_ally_status(gui, scale, mx, my, status, rgb, dirx, diry, t, layer, alpha_mult, radius)
	radius = radius or 10.5
	draw_circle_outline(gui, scale, mx, my, radius, 1.25, 18, layer,
		Color(225 * alpha_mult, rgb[1], rgb[2], rgb[3]))

	if setting("show_ally_health", true) ~= false and type(status.health) == "number" then
		local hp = math.max(0, math.min(1, status.health))
		local health_rgb = hp > 0.5 and { 96, 220, 130 }
			or hp > 0.25 and { 255, 190, 70 } or { 255, 92, 74 }
		local outer = radius + 2.7

		draw_circle_outline(gui, scale, mx, my, outer, 2.2, 20, layer,
			Color(135 * alpha_mult, 4, 7, 7))
		draw_arc_outline(gui, scale, mx, my, outer, 2.2, status.downed and 1 or hp, layer + 1,
			Color((status.downed and 170 + 75 * math.abs(math.sin((t or 0) * 5)) or 235) * alpha_mult,
				status.downed and 255 or health_rgb[1], status.downed and 62 or health_rgb[2],
				status.downed and 48 or health_rgb[3]))
	end

	if setting("show_ally_facing", true) ~= false and not status.downed and dirx and diry then
		local len = math.sqrt(dirx * dirx + diry * diry)

		if len > 0.001 then
			dirx, diry = dirx / len, diry / len
			local px2, py2 = -diry, dirx
			local tip = radius + 7
			local base = radius + 1.5

			draw_tri(gui, scale,
				mx + dirx * tip, my + diry * tip,
				mx + dirx * base + px2 * 3.2, my + diry * base + py2 * 3.2,
				mx + dirx * base - px2 * 3.2, my + diry * base - py2 * 3.2,
				layer + 2, Color(240 * alpha_mult, rgb[1], rgb[2], rgb[3]))
		end
	end

	if setting("show_ally_distress", true) ~= false and status.downed then
		local base_phase = ((t or 0) * 1.25) % 1

		for i = 0, 1 do
			local phase = (base_phase + i * 0.5) % 1
			local a = 220 * (1 - phase) * alpha_mult

			draw_circle_outline(gui, scale, mx, my, radius + 5 + phase * 18, 2, 20, layer + 3,
				Color(a, 255, 62, 48))
		end
	end
end

local function draw_ally_badges(element, gui, scale, mx, my, badges, layer, alpha_mult)
	if setting("show_ally_badges", true) == false or type(badges) ~= "table" then
		return
	end

	for i = 1, math.min(2, #badges) do
		local badge = badges[i]
		local bx, by = mx + 10 + (i - 1) * 9, my - 10

		draw_circle_fill(gui, scale, bx, by, 6.5, 12, layer, Color(225 * alpha_mult, 4, 7, 7))

		if badge.material then
			element:_queue_icon(badge.material, bx, by, 13, { 240, 218, 132 }, 245 * alpha_mult, layer + 1)
		elseif badge.kind == "battery" then
			draw_rect(gui, scale, bx - 3.8, by - 3, 7.6, 7, layer + 1, Color(240 * alpha_mult, 238, 176, 64))
			draw_rect(gui, scale, bx - 1.5, by - 4.5, 3, 1.8, layer + 2, Color(240 * alpha_mult, 238, 176, 64))
		else
			element:_queue_icon(MAT.objective, bx, by, 12, { 242, 204, 92 }, 245 * alpha_mult, layer + 1)
		end
	end
end

local function texture_widget_definition(default_material)
	return UIWidget.create_definition({
		{
			pass_type = "texture",
			value = default_material or MAT.panel_fill,
			value_id = "icon",
			style_id = "icon",
			style = {
				size = { 24, 24 },
				offset = { 0, 0, 0 },
				color = { 255, 255, 255, 255 },
			},
		},
	}, "screen")
end

local function icon_widget_definition()
	return texture_widget_definition(MAT.enemy)
end

local function text_widget_definition()
	return UIWidget.create_definition({
		{
			pass_type = "text",
			value = "",
			value_id = "text",
			style_id = "text",
			style = {
				font_size = 14,
				font_type = "machine_medium",
				text_color = { 255, 255, 255, 255 },
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				size = { 120, 20 },
				offset = { 0, 0, ICON_LAYER + 2 },
			},
		},
	}, "screen")
end

local _no_map_text

local function no_map_text()
	if not _no_map_text then
		local ok, text = pcall(function()
			return mod:localize("hud_no_floor_plan")
		end)

		if ok and type(text) == "string" and not text:find("^<") then
			_no_map_text = text
		else
			_no_map_text = "NO FLOOR PLAN - MARKERS ONLY"
		end
	end

	return _no_map_text
end

-- ---------------------------------------------------------------------------
local StrikemapElement = class("StrikemapElement", "HudElementBase")

function StrikemapElement:init(parent, draw_layer, start_scale)
	local defs = {}

	for i = 1, SKIN_POOL do
		defs["skin_" .. i] = texture_widget_definition(MAT.panel_fill)
	end

	for i = 1, ICON_POOL do
		defs["icon_" .. i] = icon_widget_definition()
	end

	for i = 1, TEXT_POOL do
		defs["text_" .. i] = text_widget_definition()
	end

	StrikemapElement.super.init(self, parent, draw_layer, start_scale, {
		scenegraph_definition = {
			screen = UIWorkspaceSettings.screen,
		},
		widget_definitions = defs,
	})

	self._skin_widgets = {}
	self._icon_widgets = {}
	self._text_widgets = {}

	for i = 1, SKIN_POOL do
		self._skin_widgets[i] = self._widgets_by_name["skin_" .. i]
	end

	for i = 1, ICON_POOL do
		self._icon_widgets[i] = self._widgets_by_name["icon_" .. i]
	end

	for i = 1, TEXT_POOL do
		self._text_widgets[i] = self._widgets_by_name["text_" .. i]
	end

	self._skins_used = 0
	self._icons_used = 0
	self._texts_used = 0
	self._seen = {}
	self._frame = 0

	mod._element_inited = true
end

-- Full override: widgets are a pool positioned per frame, so the base class
-- must not draw them all blindly.
function StrikemapElement:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
	-- Opens a new settings-snapshot generation: the first setting() call for an
	-- id this frame fetches it, the rest read the cached value.
	advance_setting_frame()

	self._skins_used = 0
	self._icons_used = 0
	self._texts_used = 0

	local ok, err = pcall(self._draw_map, self, ui_renderer, render_settings, t)

	if not ok then
		mod._element_error = err
	end

	mod._draw_ticks = (mod._draw_ticks or 0) + 1

	for i = 1, self._skins_used do
		UIWidget.draw(self._skin_widgets[i], ui_renderer)
	end

	for i = 1, self._icons_used do
		UIWidget.draw(self._icon_widgets[i], ui_renderer)
	end

	for i = 1, self._texts_used do
		UIWidget.draw(self._text_widgets[i], ui_renderer)
	end
end

function StrikemapElement:_queue_skin(material, x, y, w, h, rgba, layer)
	local used = self._skins_used + 1

	if used > SKIN_POOL then
		return
	end

	self._skins_used = used

	local widget = self._skin_widgets[used]
	local style = widget.style.icon

	widget.content.icon = material
	style.size[1] = w
	style.size[2] = h
	style.offset[1] = x
	style.offset[2] = y
	style.offset[3] = layer
	style.color[1] = rgba[1]
	style.color[2] = rgba[2]
	style.color[3] = rgba[3]
	style.color[4] = rgba[4]
	widget.dirty = true
end

-- Queue a pooled text widget. Centred at x, y by default; align "left" anchors
-- the text box's left edge at x instead.
function StrikemapElement:_queue_text(text, x, y, w, h, font_size, rgb, alpha, layer, align)
	local used = self._texts_used + 1

	if used > TEXT_POOL then
		return
	end

	self._texts_used = used

	local widget = self._text_widgets[used]
	local style = widget.style.text

	widget.content.text = text
	style.font_size = font_size
	style.size[1] = w
	style.size[2] = h
	style.offset[1] = align == "left" and x or (x - w * 0.5)
	style.offset[2] = y - h * 0.5
	style.offset[3] = layer or (ICON_LAYER + 2)
	style.text_horizontal_alignment = align or "center"
	style.text_color[1] = alpha
	style.text_color[2] = rgb[1]
	style.text_color[3] = rgb[2]
	style.text_color[4] = rgb[3]
	widget.dirty = true
end

-- Queue a pooled icon widget at panel position x, y (centre), virtual px.
function StrikemapElement:_queue_icon(material, x, y, size, rgb, alpha, layer)
	local used = self._icons_used + 1

	if used > ICON_POOL then
		return
	end

	self._icons_used = used

	local widget = self._icon_widgets[used]
	local style = widget.style.icon

	widget.content.icon = material
	style.size[1] = size
	style.size[2] = size
	style.offset[1] = x - size * 0.5
	style.offset[2] = y - size * 0.5
	style.offset[3] = layer or ICON_LAYER
	style.color[1] = alpha
	style.color[2] = rgb[1]
	style.color[3] = rgb[2]
	style.color[4] = rgb[3]
	widget.dirty = true
end

-- Parse a cell's packed "1,5,9,..." index string on first use. Runtime maps
-- may already contain numeric lists, so both representations share one path.
local function indexed_ids(cells, cache, key)
	local cached = cache[key]

	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	local packed = cells[key]

	if type(packed) == "table" then
		cache[key] = packed
		return packed
	end

	if type(packed) ~= "string" then
		cache[key] = false
		return nil
	end

	local ids = {}
	local n = 0

	for num in packed:gmatch("[^,]+") do
		n = n + 1
		ids[n] = tonumber(num)
	end

	cache[key] = ids

	return ids
end

local function cell_ids(map, key)
	return indexed_ids(map.cells, map.cell_cache, key)
end

local function add_segment_to_grid(grid, cell, idx, x1, y1, x2, y2)
	local gx0, gx1 = math.floor(math.min(x1, x2) / cell), math.floor(math.max(x1, x2) / cell)
	local gy0, gy1 = math.floor(math.min(y1, y2) / cell), math.floor(math.max(y1, y2) / cell)

	for gx = gx0, gx1 do
		for gy = gy0, gy1 do
			local key = gx .. ":" .. gy
			local ids = grid[key]

			if not ids then
				ids = {}
				grid[key] = ids
			end

			ids[#ids + 1] = idx
		end
	end
end

local function quantized_point_key(x, y)
	return math.floor(x * 20 + 0.5) .. ":" .. math.floor(y * 20 + 0.5)
end

-- Expeditions grow their mesh at runtime, and legacy v1 maps have no baked
-- vector layer. Build the same persistent world-space representation once per
-- geometry revision. Nothing here depends on the camera or viewport.
local function ensure_floor_vectors(map)
	local revision = map.revision or 0

	if (map.contour_count or 0) > 0 and (map.hatch_count or 0) > 0
		and (map.format_version or 1) >= 3 and type(map.s) == "table" then
		return
	end

	if map._floor_vector_revision == revision and (map.contour_count or 0) > 0 then
		return
	end

	local tris = map.t
	local tri_count = map.tri_count or 0
	local edge_buckets = {}
	local edge_order = {}
	local stairs = {}
	local hatches = {}
	local cell = map.grid_cell or 16
	local spacing = map.hatch_spacing or 2

	local function remember_edge(ax, ay, bx, by, z)
		local ka, kb = quantized_point_key(ax, ay), quantized_point_key(bx, by)
		local key = ka < kb and ka .. "|" .. kb or kb .. "|" .. ka
		local bucket = edge_buckets[key]

		if bucket then
			for i = 1, #bucket do
				local edge = bucket[i]

				if math.abs(edge[5] - z) <= 1.8 then
					edge.count = edge.count + 1

					if math.abs(edge[5] - z) >= 0.15 then
						stairs[#stairs + 1] = { ax, ay, bx, by, math.min(edge[5], z), math.max(edge[5], z) }
					end

					return
				end
			end
		else
			bucket = {}
			edge_buckets[key] = bucket
		end

		local edge = { ax, ay, bx, by, z, count = 1 }
		bucket[#bucket + 1] = edge
		edge_order[#edge_order + 1] = edge
	end

	local function hatch_triangle(ax, ay, bx, by, cx, cy, z)
		local min_k = math.min(ax + ay, bx + by, cx + cy)
		local max_k = math.max(ax + ay, bx + by, cx + cy)
		local k = math.ceil(min_k / spacing) * spacing

		while k <= max_k + 0.001 do
			local hx, hy = {}, {}

			local function intersect(x1, y1, x2, y2)
				local d = (x2 + y2) - (x1 + y1)

				if math.abs(d) < 0.00001 then return end

				local u = (k - x1 - y1) / d

				if u < -0.001 or u > 1.001 then return end

				local x, y = x1 + (x2 - x1) * u, y1 + (y2 - y1) * u

				if #hx == 0 or math.abs(x - hx[1]) + math.abs(y - hy[1]) > 0.02 then
					hx[#hx + 1], hy[#hy + 1] = x, y
				end
			end

			intersect(ax, ay, bx, by)
			intersect(bx, by, cx, cy)
			intersect(cx, cy, ax, ay)

			if #hx >= 2 then
				hatches[#hatches + 1] = { hx[1], hy[1], hx[2], hy[2], z }
			end

			k = k + spacing
		end
	end

	for idx = 1, tri_count do
		local o = (idx - 1) * 7
		local ax, ay = tris[o + 1], tris[o + 2]
		local bx, by = tris[o + 3], tris[o + 4]
		local cx, cy = tris[o + 5], tris[o + 6]
		local z = tris[o + 7]

		remember_edge(ax, ay, bx, by, z)
		remember_edge(bx, by, cx, cy, z)
		remember_edge(cx, cy, ax, ay, z)
		hatch_triangle(ax, ay, bx, by, cx, cy, z)
	end

	local contours = {}

	for i = 1, #edge_order do
		local edge = edge_order[i]

		if edge.count == 1 then
			contours[#contours + 1] = edge
		end
	end

	map.c, map.contour_count, map.contour_cells, map.contour_cell_cache = {}, #contours, {}, {}
	map.s, map.stair_count, map.stair_cells, map.stair_cell_cache = {}, #stairs, {}, {}
	map.h, map.hatch_count, map.hatch_cells, map.hatch_cell_cache = {}, #hatches, {}, {}

	for i = 1, #contours do
		local s = contours[i]
		local o = (i - 1) * 5
		map.c[o + 1], map.c[o + 2], map.c[o + 3], map.c[o + 4], map.c[o + 5] = s[1], s[2], s[3], s[4], s[5]
		add_segment_to_grid(map.contour_cells, cell, i, s[1], s[2], s[3], s[4])
	end

	for i = 1, #stairs do
		local s = stairs[i]
		local o = (i - 1) * 6
		map.s[o + 1], map.s[o + 2], map.s[o + 3], map.s[o + 4], map.s[o + 5], map.s[o + 6] =
			s[1], s[2], s[3], s[4], s[5], s[6]
		add_segment_to_grid(map.stair_cells, cell, i, s[1], s[2], s[3], s[4])
	end

	for i = 1, #hatches do
		local s = hatches[i]
		local o = (i - 1) * 5
		map.h[o + 1], map.h[o + 2], map.h[o + 3], map.h[o + 4], map.h[o + 5] = s[1], s[2], s[3], s[4], s[5]
		add_segment_to_grid(map.hatch_cells, cell, i, s[1], s[2], s[3], s[4])
	end

	map._floor_vector_revision = revision
end

local function point_in_triangle_2d(px, py, ax, ay, bx, by, cx, cy)
	local d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by)
	local d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy)
	local d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
	local has_negative = d1 < -0.0001 or d2 < -0.0001 or d3 < -0.0001
	local has_positive = d1 > 0.0001 or d2 > 0.0001 or d3 > 0.0001

	return not (has_negative and has_positive)
end

-- Unit.world_position is not guaranteed to use the same vertical origin as
-- the baked navigation mesh. Find the walkable triangle under the player and
-- use its Z as the tier baseline; this prevents a small origin offset from
-- making an entire walkway look above/below the player.
local function current_floor_reference(map, tris, cell, px, py, pz)
	local ids = cell_ids(map, math.floor(px / cell) .. ":" .. math.floor(py / cell))

	if not ids then
		return pz
	end

	local best_z
	local best_vertical = math.huge
	local nearby_z
	local nearby_score = math.huge

	for i = 1, #ids do
		local base = (ids[i] - 1) * 7
		local tz = tris[base + 7]

		if tz then
			local ax, ay = tris[base + 1], tris[base + 2]
			local bx, by = tris[base + 3], tris[base + 4]
			local cx, cy = tris[base + 5], tris[base + 6]
			local vertical = math.abs(tz - pz)

			if point_in_triangle_2d(px, py, ax, ay, bx, by, cx, cy) then
				if vertical < best_vertical then
					best_vertical, best_z = vertical, tz
				end
			else
				local tx, ty = (ax + bx + cx) / 3, (ay + by + cy) / 3
				local horizontal_sq = (tx - px) * (tx - px) + (ty - py) * (ty - py)
				local score = horizontal_sq + vertical * vertical

				if horizontal_sq <= 16 and score < nearby_score then
					nearby_score, nearby_z = score, tz
				end
			end
		end
	end

	-- A containing triangle far below the player means an overhang or hole
	-- edge (the pit floor "contains" the player's xy) - never let it hijack
	-- the reference or the whole map re-tiers around the pit and blanks.
	local best = best_z or nearby_z or pz

	if best_z and math.abs(best_z - pz) > 4 and nearby_z
		and math.abs(nearby_z - pz) < math.abs(best_z - pz) then
		best = nearby_z
	end

	if math.abs(best - pz) > 4 then
		best = pz
	end

	return best
end

local function elevation_tier(dz)
	if dz < -FAR_BELOW_DZ then
		return "far_below"
	elseif dz < -CURRENT_FLOOR_DZ then
		return "below"
	elseif dz <= CURRENT_FLOOR_DZ then
		return "current"
	end

	return "above"
end

-- Blend the active deck into the neighbouring treatment over a narrow height
-- band. Ramps and stairs then crossfade across successive navmesh triangles
-- instead of flipping an entire walkway on a single frame.
local function tactical_floor_blend(dz)
	local distance = math.abs(dz)
	local start = CURRENT_FLOOR_DZ - FLOOR_CROSSFADE_DZ
	local finish = CURRENT_FLOOR_DZ + FLOOR_CROSSFADE_DZ

	if distance <= start then
		return 1
	elseif distance >= finish then
		return 0
	end

	local p = (distance - start) / (finish - start)

	-- Smoothstep avoids a visible opacity kink at either end of the band.
	return 1 - p * p * (3 - 2 * p)
end

local function smoothed_floor_reference(self, map, target_z, now)
	local revision = map.revision or 0
	local clock = now or 0

	if self._floor_map ~= map or self._floor_revision ~= revision or not self._display_floor_z then
		self._floor_map = map
		self._floor_revision = revision
		self._display_floor_z = target_z
		self._floor_clock = clock
	else
		local dt = math.max(0, math.min(0.1, clock - (self._floor_clock or clock)))
		local alpha = 1 - math.exp(-dt / 0.24)
		self._display_floor_z = self._display_floor_z + (target_z - self._display_floor_z) * alpha
		self._floor_clock = clock
	end

	return self._display_floor_z
end

local function nearby_ramp_transitions(map, px, py)
	if not map.r or (map.transition_count or 0) == 0 then
		return nil
	end

	local cell = map.grid_cell or 16
	local gx, gy = math.floor(px / cell), math.floor(py / cell)
	local found, seen = {}, {}

	for ix = gx - 1, gx + 1 do
		for iy = gy - 1, gy + 1 do
			local ids = indexed_ids(map.transition_cells, map.transition_cell_cache, ix .. ":" .. iy)

			if ids then
				for i = 1, #ids do
					local id = ids[i]

					if not seen[id] then
						seen[id] = true
						found[#found + 1] = id
					end
				end
			end
		end
	end

	return found
end

-- A fine Z band still quantizes a continuous ramp into slices. Near a baked
-- boundary contact, gently pull adjacent slices into the current treatment.
-- Stacked decks do not get transition records, so they remain separated.
local function ramp_adjusted_dz(map, ramp_ids, wx, wy, tz, px, py, floor_z)
	local dz = tz - floor_z

	if not ramp_ids then
		return dz
	end

	for i = 1, #ramp_ids do
		local o = (ramp_ids[i] - 1) * 4
		local rx, ry = map.r[o + 1], map.r[o + 2]
		local z1, z2 = map.r[o + 3], map.r[o + 4]
		local pd = math.sqrt((px - rx) * (px - rx) + (py - ry) * (py - ry))
		local sd = math.sqrt((wx - rx) * (wx - rx) + (wy - ry) * (wy - ry))

		if pd < 14 and sd < 18
			and math.min(math.abs(tz - z1), math.abs(tz - z2)) < 0.75
			and math.min(math.abs(floor_z - z1), math.abs(floor_z - z2)) < 1.8 then
			local proximity = 1 - math.max(pd / 14, sd / 18)
			dz = dz * (1 - proximity * 0.72)
		end
	end

	return dz
end

local function collect_indexed_ids(cells, cache, cell, x0, y0, x1, y1)
	local ids, seen = {}, {}

	for gx = math.floor(x0 / cell), math.floor(x1 / cell) do
		for gy = math.floor(y0 / cell), math.floor(y1 / cell) do
			local found = indexed_ids(cells, cache, gx .. ":" .. gy)

			if found then
				for i = 1, #found do
					local id = found[i]

					if not seen[id] then
						seen[id] = true
						ids[#ids + 1] = id
					end
				end
			end
		end
	end

	return ids
end

local function smoothstep01(p)
	if p <= 0 then
		return 0
	elseif p >= 1 then
		return 1
	end

	return p * p * (3 - 2 * p)
end

-- Transition anchors (rdata) each cover ~1.4m of height: a long staircase is
-- a CHAIN of them. Only the connected chain describes the full climb, so the
-- chain decides "the player is on this flight" while each anchor's own z
-- slice decides which geometry lights - a deck stacked over the flight's top
-- must not light from its bottom.
local CHAIN_LINK_XY_SQ = 49 -- 7m
local CHAIN_LINK_Z = 1.2
local CHAIN_ACTIVE_Z = 1.8
local CORRIDOR_NEAR = 4.5
local CORRIDOR_FAR = 10.5
local CORRIDOR_ANCHOR_CAP = 160

local function ensure_stair_chains(map)
	if map._chains_built then
		return
	end

	map._chains_built = true

	local count = map.transition_count or 0
	local r = map.r

	if not r or count == 0 then
		return
	end

	local cell = map.grid_cell or 16
	local parent = {}

	for i = 1, count do
		parent[i] = i
	end

	local function find(a)
		while parent[a] ~= a do
			parent[a] = parent[parent[a]]
			a = parent[a]
		end

		return a
	end

	for i = 1, count do
		local o = (i - 1) * 4
		local xi, yi = r[o + 1], r[o + 2]
		local lo_i = math.min(r[o + 3], r[o + 4])
		local hi_i = math.max(r[o + 3], r[o + 4])
		local gx, gy = math.floor(xi / cell), math.floor(yi / cell)

		for ix = gx - 1, gx + 1 do
			for iy = gy - 1, gy + 1 do
				local ids = indexed_ids(map.transition_cells, map.transition_cell_cache, ix .. ":" .. iy)

				if ids then
					for k = 1, #ids do
						local j = ids[k]

						if j > i then
							local oj = (j - 1) * 4
							local dx, dy = r[oj + 1] - xi, r[oj + 2] - yi

							if dx * dx + dy * dy <= CHAIN_LINK_XY_SQ then
								local lo_j = math.min(r[oj + 3], r[oj + 4])
								local hi_j = math.max(r[oj + 3], r[oj + 4])

								if lo_i - CHAIN_LINK_Z <= hi_j and lo_j - CHAIN_LINK_Z <= hi_i then
									local pa, pb = find(i), find(j)

									if pa ~= pb then
										parent[pa] = pb
									end
								end
							end
						end
					end
				end
			end
		end
	end

	local by_root = {}
	local anchor_chain = {}

	for i = 1, count do
		local root = find(i)
		local chain = by_root[root]

		if not chain then
			chain = { anchors = {}, zlo = math.huge, zhi = -math.huge,
				xmin = math.huge, xmax = -math.huge, ymin = math.huge, ymax = -math.huge }
			by_root[root] = chain
		end

		local o = (i - 1) * 4
		local x, y = r[o + 1], r[o + 2]
		local lo = math.min(r[o + 3], r[o + 4])
		local hi = math.max(r[o + 3], r[o + 4])
		local anchors = chain.anchors
		local n = #anchors

		anchors[n + 1] = x
		anchors[n + 2] = y
		anchors[n + 3] = lo
		anchors[n + 4] = hi

		if lo < chain.zlo then
			chain.zlo = lo
		end

		if hi > chain.zhi then
			chain.zhi = hi
		end

		if x < chain.xmin then chain.xmin = x end
		if x > chain.xmax then chain.xmax = x end
		if y < chain.ymin then chain.ymin = y end
		if y > chain.ymax then chain.ymax = y end

		anchor_chain[i] = chain
	end

	-- Steep chains are real staircases/ramps (metres of climb over a short
	-- run); gentle-terrain chains span the same metres over a whole dune and
	-- must not draw stair ticks.
	for _, chain in pairs(by_root) do
		local span = chain.zhi - chain.zlo
		local extent = math.max(chain.xmax - chain.xmin, chain.ymax - chain.ymin, 3)

		chain.steep = span >= 2.6 and span / extent >= 0.22
	end

	-- Incline ink: build the diagonal slope-hatch vectors ONCE. The baked
	-- polygon-level hatch data skips the thin per-band strips ramps are made
	-- of, so instead the world hatch family (x+y=k) is clipped to every
	-- triangle near a gentle-chain anchor (steep chains keep stair ticks).
	-- Static, world-anchored data - nothing depends on the player.
	local slope_segs = {}
	local slope_grid = {}
	local seen_tri = {}
	local tris = map.t
	local spacing = map.hatch_spacing or 2
	local reach2 = (SLOPE_ANCHOR_RADIUS + 1.0) * (SLOPE_ANCHOR_RADIUS + 1.0)

	local function ink_triangle(ax, ay, bx, by, cx, cy, z)
		local min_k = math.min(ax + ay, bx + by, cx + cy)
		local max_k = math.max(ax + ay, bx + by, cx + cy)
		local k = math.ceil(min_k / spacing) * spacing

		while k <= max_k + 0.001 do
			local hx, hy = {}, {}

			local function intersect(x1, y1, x2, y2)
				local d = (x2 + y2) - (x1 + y1)

				if math.abs(d) < 0.00001 then return end

				local u = (k - x1 - y1) / d

				if u < -0.001 or u > 1.001 then return end

				local x, y = x1 + (x2 - x1) * u, y1 + (y2 - y1) * u

				if #hx == 0 or math.abs(x - hx[1]) + math.abs(y - hy[1]) > 0.02 then
					hx[#hx + 1], hy[#hy + 1] = x, y
				end
			end

			intersect(ax, ay, bx, by)
			intersect(bx, by, cx, cy)
			intersect(cx, cy, ax, ay)

			if #hx >= 2 then
				local n = #slope_segs

				slope_segs[n + 1], slope_segs[n + 2] = hx[1], hy[1]
				slope_segs[n + 3], slope_segs[n + 4] = hx[2], hy[2]
				slope_segs[n + 5] = z
				add_segment_to_grid(slope_grid, cell, n / 5 + 1, hx[1], hy[1], hx[2], hy[2])
			end

			k = k + spacing
		end
	end

	if tris then
		for _, chain in pairs(by_root) do
			if not chain.steep and chain.zhi - chain.zlo >= SLOPE_MIN_SPAN then
				local anchors = chain.anchors

				for k0 = 1, #anchors, 4 do
					local ax0, ay0 = anchors[k0], anchors[k0 + 1]
					local alo, ahi = anchors[k0 + 2], anchors[k0 + 3]
					local gx, gy = math.floor(ax0 / cell), math.floor(ay0 / cell)

					for ix = gx - 1, gx + 1 do
						for iy = gy - 1, gy + 1 do
							local ids = cell_ids(map, ix .. ":" .. iy)

							if ids then
								for i = 1, #ids do
									local idx = ids[i]

									if not seen_tri[idx] then
										local o = (idx - 1) * 7
										local tz = tris[o + 7]

										if tz >= alo - 1.2 and tz <= ahi + 1.2 then
											local mx = (tris[o + 1] + tris[o + 3] + tris[o + 5]) / 3
											local my = (tris[o + 2] + tris[o + 4] + tris[o + 6]) / 3
											local dx, dy = mx - ax0, my - ay0

											if dx * dx + dy * dy <= reach2 then
												seen_tri[idx] = true
												ink_triangle(tris[o + 1], tris[o + 2], tris[o + 3],
													tris[o + 4], tris[o + 5], tris[o + 6], tz)
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end

	map.slope_segs = slope_segs
	map.slope_seg_count = #slope_segs / 5
	map.slope_seg_cells = slope_grid
	map.slope_seg_cell_cache = {}

	map.anchor_chain = anchor_chain
end

-- Flat x,y,zlo,zhi record array of every anchor on the chains the player is
-- currently close to (in xy AND height). Cached until the player moves ~2m.
local function corridor_anchors(self, map, px, py, floor_z)
	if not map.anchor_chain then
		return nil, 0
	end

	local key = math.floor(px * 0.5) .. ":" .. math.floor(py * 0.5) .. ":" .. math.floor(floor_z * 2)
	local cache = self._corridor_cache

	if cache and cache.map == map and cache.key == key then
		return cache.anchors, cache.count
	end

	local ids = nearby_ramp_transitions(map, px, py)
	local out = {}
	local n = 0

	if ids then
		local seen = {}

		for i = 1, #ids do
			local chain = map.anchor_chain[ids[i]]

			if chain and not seen[chain]
				and floor_z >= chain.zlo - CHAIN_ACTIVE_Z and floor_z <= chain.zhi + CHAIN_ACTIVE_Z then
				seen[chain] = true
				local anchors = chain.anchors
				local steep = chain.steep and 1 or 0

				for k = 1, #anchors, 4 do
					if n + 5 > CORRIDOR_ANCHOR_CAP * 5 then
						break
					end

					out[n + 1] = anchors[k]
					out[n + 2] = anchors[k + 1]
					out[n + 3] = anchors[k + 2]
					out[n + 4] = anchors[k + 3]
					out[n + 5] = steep
					n = n + 5
				end
			end

			if n + 5 > CORRIDOR_ANCHOR_CAP * 5 then
				break
			end
		end
	end

	self._corridor_cache = { map = map, key = key, anchors = out, count = n / 5 }

	return out, n / 5
end

-- Contour classification: keep only lines that read as architecture. A true
-- wall has walkable ground on ONE side. Interior band-lines (ground both
-- sides - terracing noise on organic terrain) and small-obstacle outlines
-- (ground reappears within a few metres past the void side - junk, crates)
-- render as scribble and are suppressed; their fill holes still show.
local function walkable_near(map, tris, cell, qx, qy, z)
	local ids = cell_ids(map, math.floor(qx / cell) .. ":" .. math.floor(qy / cell))

	if not ids then
		return false
	end

	for i = 1, #ids do
		local o = (ids[i] - 1) * 7
		local tz = tris[o + 7]

		if tz and tz > z - 2.6 and tz < z + 2.6
			and point_in_triangle_2d(qx, qy, tris[o + 1], tris[o + 2],
				tris[o + 3], tris[o + 4], tris[o + 5], tris[o + 6]) then
			return true
		end
	end

	return false
end

local function classify_contour(map, tris, cell, wx1, wy1, wx2, wy2, tz)
	local dx, dy = wx2 - wx1, wy2 - wy1
	local length = math.sqrt(dx * dx + dy * dy)

	if length < 0.7 then
		return 0
	end

	local mx, my = (wx1 + wx2) * 0.5, (wy1 + wy2) * 0.5
	local nx, ny = -dy / length, dx / length
	local side_a = walkable_near(map, tris, cell, mx + nx * 0.55, my + ny * 0.55, tz)
	local side_b = walkable_near(map, tris, cell, mx - nx * 0.55, my - ny * 0.55, tz)

	if side_a == side_b then
		return 0
	end

	local sign = side_b and 1 or -1

	if walkable_near(map, tris, cell, mx + nx * sign * 1.4, my + ny * sign * 1.4, tz)
		or walkable_near(map, tris, cell, mx + nx * sign * 2.6, my + ny * sign * 2.6, tz)
		or walkable_near(map, tris, cell, mx + nx * sign * 4.2, my + ny * sign * 4.2, tz) then
		return 0
	end

	return 1
end

-- Per-triangle height averaged over the connected surface within ~3m (same
-- surface = within 2m of height). The 1m band quantization gives neighbouring
-- triangles stepped z; any fill treatment keyed on raw z turns that into torn
-- facet patchwork (proven repeatedly). Averaging erases band noise while true
-- deck separations (>2m) stay intact. Computed lazily with a frame budget and
-- cached for the map's lifetime.
local function smoothed_tri_z(map, tris, cell, mx, my, tz)
	local acc, n = tz, 1
	local zmin, zmax = tz, tz
	local gx, gy = math.floor(mx / cell), math.floor(my / cell)

	for ix = gx - 1, gx + 1 do
		for iy = gy - 1, gy + 1 do
			local ids = cell_ids(map, ix .. ":" .. iy)

			if ids then
				for k = 1, #ids do
					local o = (ids[k] - 1) * 7
					local zj = tris[o + 7]

					if zj and zj > tz - 2 and zj < tz + 2 then
						local jx = (tris[o + 1] + tris[o + 3] + tris[o + 5]) / 3
						local dx = jx - mx

						if dx > -3 and dx < 3 then
							local jy = (tris[o + 2] + tris[o + 4] + tris[o + 6]) / 3
							local dy = jy - my

							if dy > -3 and dy < 3 and dx * dx + dy * dy <= 9 then
								acc = acc + zj
								n = n + 1

								if zj < zmin then zmin = zj end
								if zj > zmax then zmax = zj end
							end
						end
					end
				end
			end
		end
	end

	-- Relief = same-surface height range within 3m: ~0 on flat decks, metres
	-- on slopes. The hero band stretches with it, so a dune rolls off in one
	-- long fade instead of cutting to a small patch around the player.
	return acc / n, zmax - zmin
end

-- Offline harness hooks; unused by the live HUD.
mod.__test_floor_reference = current_floor_reference
mod.__test_elevation_tier = elevation_tier
mod.__test_floor_blend = tactical_floor_blend
mod.__test_ensure_floor_vectors = ensure_floor_vectors
mod.__test_ensure_stair_chains = ensure_stair_chains
mod.__test_classify_contour = classify_contour

-- Compatibility API support: the vector layers (contours/stairs/hatches come
-- baked or from ensure_floor_vectors; slope ink + chain classification are
-- built lazily at draw time). A geometry-only consumer may request them
-- before this element ever draws, so the builders are exported for
-- get_vector_context() to trigger on demand. Idempotent and static per map.
mod._ensure_map_vectors = function(map)
	ensure_floor_vectors(map)
	ensure_stair_chains(map)
end

function StrikemapElement:_draw_tactical_floor(gui, scale, now, map, px, py, pz, c, s, ppm,
		left, top, right, bottom, cx, cy, radius, round_layout, layer0, am, z_above, z_below)
	ensure_floor_vectors(map)
	ensure_stair_chains(map)

	local cell = map.grid_cell or 16
	local tris = map.t
	local view_radius = (round_layout and (radius + 6) or (right - left) * 0.7072) / ppm
	local clip_r = radius - 1
	local clip_r2 = clip_r * clip_r
	local target_floor_z = current_floor_reference(map, tris, cell, px, py, pz)
	local floor_z = smoothed_floor_reference(self, map, target_floor_z, now)
	local tier_counts = { current = 0, above = 0, below = 0, far_below = 0 }
	local show_hatches = setting("show_hatchwork", false) == true

	local function project(wx, wy)
		local dx, dy = wx - px, wy - py

		return cx + (dx * c - dy * s) * ppm,
			cy - (dx * s + dy * c) * ppm
	end

	local function draw_clipped_line(x1, y1, x2, y2, thickness, layer, color)
		local ax, ay, bx, by

		if round_layout then
			ax, ay, bx, by = clip_line_circle(x1, y1, x2, y2, cx, cy, clip_r)
		else
			ax, ay, bx, by = clip_line_rect(x1, y1, x2, y2, left, top, right, bottom)
		end

		if ax then
			draw_line(gui, scale, ax, ay, bx, by, thickness, layer, color)
			return true
		end

		return false
	end

	local function draw_world_line(wx1, wy1, wx2, wy2, thickness, layer, color)
		local x1, y1 = project(wx1, wy1)
		local x2, y2 = project(wx2, wy2)

		return draw_clipped_line(x1, y1, x2, y2, thickness, layer, color)
	end

	local function draw_world_dashes(wx1, wy1, wx2, wy2, thickness, layer, color)
		local dx, dy = wx2 - wx1, wy2 - wy1
		local length = math.sqrt(dx * dx + dy * dy)

		if length < 0.01 then return 0 end

		local period, dash = 1.35, 0.46
		local phase = math.abs(wx1 * 0.754877666 + wy1 * 0.569840291) % period
		local distance = -phase
		local drawn = 0

		while distance < length do
			local a = math.max(0, distance)
			local b = math.min(length, distance + dash)

			if b > a then
				local u0, u1 = a / length, b / length

				if draw_world_line(wx1 + dx * u0, wy1 + dy * u0,
					wx1 + dx * u1, wy1 + dy * u1, thickness, layer, color) then
					drawn = drawn + 1
				end
			end

			distance = distance + period
		end

		return drawn
	end

	local function fill_triangle(x1, y1, x2, y2, x3, y3, layer, color, fully_inside)
		if fully_inside then
			draw_tri(gui, scale, x1, y1, x2, y2, x3, y3, layer, color)
		elseif round_layout then
			draw_tri_clipped_circle(gui, scale, x1, y1, x2, y2, x3, y3,
				cx, cy, clip_r, layer, color)
		else
			draw_tri_clipped(gui, scale, x1, y1, x2, y2, x3, y3,
				left, top, right, bottom, layer, color)
		end
	end

	-- Stair-chain anchors are used ONLY to place static stair ticks now; the
	-- fill no longer has any "corridor lighting" (that was dynamic fog-of-war
	-- behaviour the user explicitly never wanted).
	local ca, ca_count = corridor_anchors(self, map, px, py, floor_z)

	-- True only right at an anchor of a STEEP chain (a real flight) - the
	-- gate for stair ticks, so gentle banded terrain never speckles.
	local function steep_flight_near(wx, wy, tz)
		for i = 0, ca_count - 1 do
			local o = i * 5

			if ca[o + 5] == 1 and tz >= ca[o + 3] - 1.4 and tz <= ca[o + 4] + 1.4 then
				local dx = wx - ca[o + 1]

				if dx > -2.5 and dx < 2.5 then
					local dy = wy - ca[o + 2]

					if dy > -2.5 and dy < 2.5 then
						return true
					end
				end
			end
		end

		return false
	end

	-- NO distance-based grading of geometry: the map is static cartography;
	-- the rim vignette is a panel-space overlay drawn in _draw_map.

	-- Geometry id collection is cached until the player moves ~4m (collected
	-- with a 6m margin so the cache never under-covers the view). Rebuilding
	-- four id tables every frame was measurable during hordes.
	local geo = self._geo_cache
	local geo_key = math.floor(px * 0.25) .. ":" .. math.floor(py * 0.25) .. ":" .. math.floor(view_radius)

	if not geo or geo.map ~= map or geo.key ~= geo_key then
		local margin = 6
		local x0, y0 = px - view_radius - margin, py - view_radius - margin
		local x1c, y1c = px + view_radius + margin, py + view_radius + margin
		local tri_ids = collect_indexed_ids(map.cells, map.cell_cache, cell, x0, y0, x1c, y1c)

		-- A malformed/partial cell index must not blank the local map. This
		-- scan is deterministic and uncapped; it is only used when the index
		-- is clearly missing the player's neighbourhood.
		if #tri_ids < 8 then
			local seen = {}
			for i = 1, #tri_ids do seen[tri_ids[i]] = true end
			local margin2 = (view_radius + margin + 8) * (view_radius + margin + 8)

			for idx = 1, map.tri_count do
				local o = (idx - 1) * 7
				local mx = (tris[o + 1] + tris[o + 3] + tris[o + 5]) / 3
				local my = (tris[o + 2] + tris[o + 4] + tris[o + 6]) / 3

				if not seen[idx] and (mx - px) * (mx - px) + (my - py) * (my - py) <= margin2 then
					seen[idx] = true
					tri_ids[#tri_ids + 1] = idx
				end
			end
		end

		-- Lower decks first, so the active floor always paints on top and
		-- stacked-band overlaps stop reading as scratchy seams.
		table.sort(tri_ids, function(a, b)
			return tris[(a - 1) * 7 + 7] < tris[(b - 1) * 7 + 7]
		end)

		-- Fill budget: the id list is z-sorted so lower decks paint first, so a
		-- plain "stop at N" would delete the upper decks. Instead the rebuild
		-- works out how far from the player the budget-th nearest triangle sits
		-- and the draw loop skips anything past it -- the periphery thins, the
		-- ground under your feet is always complete, and paint order is intact.
		local budget = tonumber(setting("perf_map_tri_budget", MAX_TRIS_PER_FRAME)) or MAX_TRIS_PER_FRAME
		local cutoff = nil

		if budget > 0 and #tri_ids > budget then
			-- A histogram, not a sort: this runs on every cache rebuild (~4 m of
			-- walking), so an O(n log n) sort plus an n-entry array here is a
			-- stutter of its own. Triangles are spread roughly evenly per unit
			-- of AREA, so linear buckets over squared distance land close to a
			-- true quantile, and the cutoff only has to be approximate.
			local hist = self._dist_hist

			if not hist then
				hist = {}
				self._dist_hist = hist
			end

			local nb = 64
			local reach = view_radius + 6 + 8
			local max_d2 = reach * reach

			for i = 1, nb do
				hist[i] = 0
			end

			for i = 1, #tri_ids do
				local o = (tri_ids[i] - 1) * 7
				local mx = (tris[o + 1] + tris[o + 3] + tris[o + 5]) / 3 - px
				local my = (tris[o + 2] + tris[o + 4] + tris[o + 6]) / 3 - py
				local slot = math.floor((mx * mx + my * my) / max_d2 * nb) + 1

				if slot < 1 then
					slot = 1
				elseif slot > nb then
					slot = nb
				end

				hist[slot] = hist[slot] + 1
			end

			local acc = 0

			for i = 1, nb do
				acc = acc + hist[i]

				if acc >= budget then
					cutoff = i / nb * max_d2
					break
				end
			end

			cutoff = cutoff or max_d2
		end

		geo = {
			map = map,
			key = geo_key,
			tri_ids = tri_ids,
			fill_cutoff = cutoff,
			cutoff_px = px,
			cutoff_py = py,
			stair_ids = collect_indexed_ids(map.stair_cells, map.stair_cell_cache, cell, x0, y0, x1c, y1c),
			contour_ids = collect_indexed_ids(map.contour_cells, map.contour_cell_cache, cell, x0, y0, x1c, y1c),
			hatch_ids = collect_indexed_ids(map.hatch_cells, map.hatch_cell_cache, cell, x0, y0, x1c, y1c),
			slope_ids = map.slope_seg_cells and collect_indexed_ids(map.slope_seg_cells,
				map.slope_seg_cell_cache, cell, x0, y0, x1c, y1c) or nil,
		}
		self._geo_cache = geo
	end

	local tri_ids = geo.tri_ids
	local drawn = 0
	local sz_cache = map.smoothed_z
	local relief_cache = map.relief
	local dw_cache = map.display_w

	local birth_cache = map.birth

	if not sz_cache then
		sz_cache = {}
		relief_cache = {}
		dw_cache = {}
		birth_cache = {}
		map.smoothed_z = sz_cache
		map.relief = relief_cache
		map.display_w = dw_cache
		map.birth = birth_cache
	end

	-- Temporal easing: each triangle's DISPLAYED weight glides toward its
	-- target (~0.2s), so geometry fades in/out smoothly while walking
	-- instead of flipping state per-triangle at the frontier - the
	-- "segmented, you can see the triangles arriving" complaint.
	local clock = now or 0
	local dt = math.max(0, math.min(0.1, clock - (self._fill_clock or clock)))
	self._fill_clock = clock
	local ease = 1 - math.exp(-dt / 0.18)

	local sz_budget = 900
	local near_rgb, ctx_rgb = TACTICAL_NEAR_RGB, TACTICAL_CTX_RGB
	local fill_cutoff = geo.fill_cutoff
	local cut_px, cut_py = geo.cutoff_px or px, geo.cutoff_py or py

	for i = 1, #tri_ids do
		local idx = tri_ids[i]
		local o = (idx - 1) * 7
		local tz = tris[o + 7]
		local dz = tz - floor_z

		if dz >= -z_below and dz <= z_above then
			local mx = (tris[o + 1] + tris[o + 3] + tris[o + 5]) / 3
			local my = (tris[o + 2] + tris[o + 4] + tris[o + 6]) / 3
			local szv = sz_cache[idx]

			if szv == nil and sz_budget > 0 then
				sz_budget = sz_budget - 1
				local relief
				szv, relief = smoothed_tri_z(map, tris, cell, mx, my, tz)
				sz_cache[idx] = szv
				relief_cache[idx] = relief
			end

			-- STATIC cartography - the model every real minimap uses. The
			-- walkable floor around the player's level (slopes included via
			-- the stable relief-stretched band) draws FULLY SOLID, decks
			-- below draw as one flat dim wash, decks above as outlines only.
			-- NOTHING here depends on distance from the player: a room is a
			-- whole rectangle whether you are in it or leaving it. The rim
			-- vignette is an overlay drawn ON TOP in panel space. Distance/
			-- gradient-modulated fills were tried for seven rounds and are
			-- exactly what read as "broken triangles while walking" - never
			-- reintroduce them.
			local stretch = 1 + (relief_cache[idx] or 0) * 0.8
			local sdz = (szv or tz) - floor_z
			local abs_sdz = sdz >= 0 and sdz or -sdz
			local band = 3.4 * stretch
			local w = 1 - smoothstep01((abs_sdz - band) / 1.2)

			local tier = w >= 0.5 and "current" or elevation_tier(dz)
			tier_counts[tier] = tier_counts[tier] + 1

			-- Temporal easing stays as insurance: on stairs the floor
			-- reference moves, and gliding beats flipping.
			local dw = dw_cache[idx]

			if dw == nil then
				dw = 0
			end

			dw = dw + (w - dw) * ease
			dw_cache[idx] = dw
			w = dw

			local b = birth_cache[idx] or 0
			b = b + (1 - b) * ease
			birth_cache[idx] = b

			do
				local wash = sdz < 0 and 88 or 0
				local alpha = (wash * (1 - w) + 252 * w) * am * b

				if fill_cutoff then
					local ddx, ddy = mx - cut_px, my - cut_py

					if ddx * ddx + ddy * ddy > fill_cutoff then
						alpha = 0
					end
				end

				if alpha > 4 then
					local fr = ctx_rgb[1] + (near_rgb[1] - ctx_rgb[1]) * w
					local fg = ctx_rgb[2] + (near_rgb[2] - ctx_rgb[2]) * w
					local fb = ctx_rgb[3] + (near_rgb[3] - ctx_rgb[3]) * w
					local x1, y1 = project(tris[o + 1], tris[o + 2])
					local x2, y2 = project(tris[o + 3], tris[o + 4])
					local x3, y3 = project(tris[o + 5], tris[o + 6])

					if not ((x1 < left and x2 < left and x3 < left)
						or (x1 > right and x2 > right and x3 > right)
						or (y1 < top and y2 < top and y3 < top)
						or (y1 > bottom and y2 > bottom and y3 > bottom)) then
						local fully_inside

						if round_layout then
							local d1 = (x1 - cx) * (x1 - cx) + (y1 - cy) * (y1 - cy)
							local d2 = (x2 - cx) * (x2 - cx) + (y2 - cy) * (y2 - cy)
							local d3 = (x3 - cx) * (x3 - cx) + (y3 - cy) * (y3 - cy)
							fully_inside = d1 <= clip_r2 and d2 <= clip_r2 and d3 <= clip_r2
						else
							fully_inside = x1 >= left and x1 <= right and y1 >= top and y1 <= bottom
								and x2 >= left and x2 <= right and y2 >= top and y2 <= bottom
								and x3 >= left and x3 <= right and y3 >= top and y3 <= bottom
						end

						-- Hero surface paints ABOVE every context wash: stacked
						-- upper decks otherwise smear translucent blotches
						-- across the bright floor (screenshot-proven).
						fill_triangle(x1, y1, x2, y2, x3, y3,
							w >= 0.5 and layer0 + 3 or layer0 + 2,
							Color(alpha, fr, fg, fb), fully_inside)
						drawn = drawn + 1
					end
				end
			end
		end
	end

	local stair_drawn = 0
	local stair_ids = geo.stair_ids

	for i = 1, #stair_ids do
		local o = (stair_ids[i] - 1) * 6
		local wx1, wy1, wx2, wy2 = map.s[o + 1], map.s[o + 2], map.s[o + 3], map.s[o + 4]
		local z1, z2 = map.s[o + 5], map.s[o + 6]
		local zmid = (z1 + z2) * 0.5
		local dz = zmid - floor_z

		-- Ticks only near the player's own level (|dz| <= 4): a flight on a
		-- deck below otherwise draws its ink on top of the current floor -
		-- "random black lines on flat terrain" (screenshot-proven). And only
		-- at anchors of STEEP chains (real flights). Static ink.
		if dz >= -4 and dz <= 4 then
			local mx, my = (wx1 + wx2) * 0.5, (wy1 + wy2) * 0.5

			if steep_flight_near(mx, my, zmid) then
				if draw_world_line(wx1, wy1, wx2, wy2, 1.4, layer0 + 5,
					Color(185 * am, TACTICAL_INK_RGB[1], TACTICAL_INK_RGB[2], TACTICAL_INK_RGB[3])) then
					stair_drawn = stair_drawn + 1
				end
			end
		end
	end

	local contour_drawn = 0
	local contour_ids = geo.contour_ids
	local contour_class = map.contour_class

	if not contour_class then
		contour_class = {}
		map.contour_class = contour_class
	end

	-- Classification is cached per contour for the map's lifetime; at most a
	-- small budget of new contours is classified per frame so a fresh area
	-- never stutters (unclassified lines draw normally until their verdict).
	local classify_budget = 220

	for i = 1, #contour_ids do
		local idx = contour_ids[i]
		local o = (idx - 1) * 5
		local wx1, wy1, wx2, wy2, tz = map.c[o + 1], map.c[o + 2], map.c[o + 3], map.c[o + 4], map.c[o + 5]
		local dz = tz - floor_z
		local class = contour_class[idx]

		if class == nil and classify_budget > 0 then
			classify_budget = classify_budget - 1
			class = classify_contour(map, tris, cell, wx1, wy1, wx2, wy2, tz)
			contour_class[idx] = class
		end

		if class ~= 0 and dz >= -z_below and dz <= z_above then
			local weight = tactical_floor_blend(dz)
			local rad = 1
			local adz = dz >= 0 and dz or -dz

			-- Off-level lines fade hard within a few metres of height
			-- distance, or every band outline scribbles across terraces.
			if adz > FILL_BAND then
				rad = rad * (1 - smoothstep01((adz - FILL_BAND) / 4.5) * 0.85)
			end

			if weight >= 0.5 then
				-- Active-deck walls: bone core on a dark undercoat, with a
				-- soft half-alpha halo pass between them - Gui.triangle has
				-- no line anti-aliasing, so the halo fakes it. This is where
				-- most of the "engine lines look rough vs the mockup" lived.
				local a = (150 + 100 * weight) * rad * am

				if a > 5 then
					draw_world_line(wx1, wy1, wx2, wy2, 3.1, layer0 + 6,
						Color(a * 0.8, TACTICAL_UNDER_RGB[1], TACTICAL_UNDER_RGB[2], TACTICAL_UNDER_RGB[3]))
					draw_world_line(wx1, wy1, wx2, wy2, 2.0, layer0 + 7,
						Color(a * 0.4, TACTICAL_WALL_RGB[1], TACTICAL_WALL_RGB[2], TACTICAL_WALL_RGB[3]))

					if draw_world_line(wx1, wy1, wx2, wy2, 1.15, layer0 + 7,
						Color(a, TACTICAL_WALL_RGB[1], TACTICAL_WALL_RGB[2], TACTICAL_WALL_RGB[3])) then
						contour_drawn = contour_drawn + 1
					end
				end
			elseif dz > 0 then
				-- Faint ghost-deck outlines skip the AA halo: at their alpha
				-- the jaggies are invisible and the extra pass is pure cost.
				local a = 150 * rad * am

				if a > 5 and draw_world_line(wx1, wy1, wx2, wy2, 0.85, layer0 + 7,
					Color(a, TACTICAL_FLOOR_RGB.above[1], TACTICAL_FLOOR_RGB.above[2], TACTICAL_FLOOR_RGB.above[3])) then
					contour_drawn = contour_drawn + 1
				end
			else
				local rgb = dz >= -FAR_BELOW_DZ and TACTICAL_FLOOR_RGB.below or TACTICAL_FLOOR_RGB.far_below
				local a = (dz >= -FAR_BELOW_DZ and 165 or 100) * rad * am

				if a > 5 then
					contour_drawn = contour_drawn + draw_world_dashes(wx1, wy1, wx2, wy2, 1.05, layer0 + 7,
						Color(a, rgb[1], rgb[2], rgb[3]))
				end
			end
		end
	end

	local hatch_drawn = 0
	local hatch_ids = geo.hatch_ids

	-- Below decks: the mockup's fine line pattern. World-anchored diagonals
	-- drawn over the dim wash (same layer, later submission wins) and under
	-- the hero surface at layer0+3, so the active floor always paints on
	-- top. Deeper decks go fainter. Always on: this is the tactical style's
	-- below-deck texture, not the optional above-deck hatchwork.
	for i = 1, #hatch_ids do
		local o = (hatch_ids[i] - 1) * 5
		local wx1, wy1, wx2, wy2, tz = map.h[o + 1], map.h[o + 2], map.h[o + 3], map.h[o + 4], map.h[o + 5]
		local dz = tz - floor_z

		if dz < 0 and dz >= -z_below then
			local wb = 1 - tactical_floor_blend(dz)

			if wb > 0.15 then
				local near = dz >= -FAR_BELOW_DZ
				local rgb = near and BELOW_HATCH_RGB or FAR_HATCH_RGB
				local a = (near and 108 or 62) * wb * am

				if a > 4 and draw_world_line(wx1, wy1, wx2, wy2, 0.72, layer0 + 2,
					Color(a, rgb[1], rgb[2], rgb[3])) then
					hatch_drawn = hatch_drawn + 1
				end
			end
		end
	end

	-- Gentle ramps: diagonal incline ink on the lit surface, drawn from the
	-- static slope vectors built alongside the stair chains.
	if (map.slope_seg_count or 0) > 0 and geo.slope_ids then
		local sv = map.slope_segs
		local slope_ids = geo.slope_ids

		for i = 1, #slope_ids do
			local o = (slope_ids[i] - 1) * 5
			local tz = sv[o + 5]
			local dz = tz - floor_z

			if dz >= -4.5 and dz <= 4.5 then
				local a = 110 * (0.35 + 0.65 * tactical_floor_blend(dz)) * am

				if a > 5 then
					draw_world_line(sv[o + 1], sv[o + 2], sv[o + 3], sv[o + 4], 0.8, layer0 + 4,
						Color(a, SLOPE_INK_RGB[1], SLOPE_INK_RGB[2], SLOPE_INK_RGB[3]))
				end
			end
		end
	end

	if show_hatches then
		for i = 1, #hatch_ids do
			local o = (hatch_ids[i] - 1) * 5
			local wx1, wy1, wx2, wy2, tz = map.h[o + 1], map.h[o + 2], map.h[o + 3], map.h[o + 4], map.h[o + 5]
			local dz = tz - floor_z
			local hatch_weight = dz > 0 and (1 - tactical_floor_blend(dz)) or 0

			if dz <= z_above and hatch_weight > 0.08 then
				local a = (52 + hatch_weight * 74) * am

				if a > 5 and draw_world_line(wx1, wy1, wx2, wy2, 0.72, layer0 + 5,
					Color(a, TACTICAL_FLOOR_RGB.above[1], TACTICAL_FLOOR_RGB.above[2], TACTICAL_FLOOR_RGB.above[3])) then
					hatch_drawn = hatch_drawn + 1
				end
			end
		end
	end

	mod._floor_diag = {
		player_z = pz,
		target_z = target_floor_z,
		display_z = floor_z,
		current = tier_counts.current,
		above = tier_counts.above,
		below = tier_counts.below,
		far_below = tier_counts.far_below,
		contours = contour_drawn,
		stairs = stair_drawn,
		hatches = hatch_drawn,
		transitions = ca_count,
	}
	mod._last_geometry_drawn = drawn
end

function StrikemapElement:_draw_map(ui_renderer, render_settings, t)
	-- (The mission-report browser is a separate cursor-driven UIView, not drawn
	-- by this HUD element.)
	local state = mod.strikemap_state and mod.strikemap_state()

	if not state or not state.active then
		return
	end

	-- A compatible external renderer owns all live map presentation in this
	-- mode. Mission Debrief is a separate UIView and remains available.
	if state.geometry_only then
		return
	end

	local map = state.map

	-- Full-map overview takes over the whole screen; it works even when the
	-- corner strikemap is toggled hidden.
	if state.fullmap then
		if map and map.t and (map.tri_count or 0) > 0 then
			self:_draw_fullmap(ui_renderer, render_settings, t, map, state)
		else
			self:_draw_fullmap_empty(ui_renderer, render_settings, state)
		end

		return
	end

	if setting("enable_minimap", true) == false then
		return
	end

	if not state.visible then
		return
	end

	if not map and setting("show_when_no_map", true) == false then
		return
	end

	-- -----------------------------------------------------------------------
	-- Settings
	-- -----------------------------------------------------------------------
	local size = setting("map_size", 280)
	local zoom = math.max(10, (setting("map_zoom", 55)) * (state.zoom_mult or 1))
	local opacity = setting("map_opacity", 60)
	local corner = setting("map_corner", "top_right")
	local rotate = setting("rotate_with_camera", true) ~= false
	local z_above = setting("floors_above", 12)
	local z_below = setting("floors_below", 16)

	-- Theme: terminal (full cogitator skin), round (circular auspex), clean
	-- (flat square/circle, no textures), ghost (geometry and markers only).
	local theme = setting("map_theme", "terminal")
	local round_layout = theme == "round" or theme == "clean_circle"
	local auspex = theme == "round"

	-- -----------------------------------------------------------------------
	-- Player position + camera heading (client-safe accessors only)
	-- -----------------------------------------------------------------------
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(1)
	local player_unit = player and player.player_unit

	local parent = self._parent
	local camera = parent and parent.player_camera and parent:player_camera()

	local px, py, pz

	if player_unit and Unit.alive(player_unit) then
		local pos = Unit.world_position(player_unit, 1)
		px, py, pz = pos.x, pos.y, pos.z
	elseif camera then
		local pos = Camera.local_position(camera)
		px, py, pz = pos.x, pos.y, pos.z
	else
		return
	end

	local yaw = 0

	if camera then
		local fwd = Quaternion.forward(Camera.local_rotation(camera))
		yaw = math.atan2(fwd.x, fwd.y)
	end

	mod._camera_forward_x = math.sin(yaw)
	mod._camera_forward_y = math.cos(yaw)

	local c, s = math.cos(yaw), math.sin(yaw)

	if not rotate then
		c, s = 1, 0
	end

	-- -----------------------------------------------------------------------
	-- Panel layout (virtual space at the current draw scale; on 16:9 this is
	-- the classic 1920x1080, on ultrawide it is proportionally wider)
	-- -----------------------------------------------------------------------
	local gui = ui_renderer.gui
	local scale = ui_renderer.scale or 1
	local vw, vh = virtual_screen_size(scale)
	local left, top

	if corner == "top_left" then
		left, top = MARGIN_X, MARGIN_TOP
	elseif corner == "bottom_left" then
		left, top = MARGIN_X, vh - MARGIN_BOTTOM - size
	elseif corner == "bottom_right" then
		left, top = vw - MARGIN_X - size, vh - MARGIN_BOTTOM - size
	elseif corner == "top_center" then
		left, top = (vw - size) * 0.5, MARGIN_TOP
	elseif corner == "bottom_center" then
		left, top = (vw - size) * 0.5, vh - MARGIN_BOTTOM - size
	elseif corner == "center" then
		-- Dead centre of the screen, for an overlay-style map. Pair it with
		-- Map Contents Opacity so it does not block what is behind it.
		left, top = (vw - size) * 0.5, (vh - size) * 0.5
	else
		left, top = vw - MARGIN_X - size, MARGIN_TOP
	end

	-- Fine positioning on top of the anchor (1080p-reference pixels).
	left = left + (setting("map_offset_x", 0) or 0)
	top = top + (setting("map_offset_y", 0) or 0)

	local right = left + size
	local bottom = top + size
	local cx = left + size * 0.5
	local cy = top + size * 0.5
	local am = render_settings and render_settings.alpha_multiplier or 1
	-- Global fade for EVERYTHING the panel draws - floor, walls, markers, text.
	-- (map_opacity only ever governed the backdrop.) Folding it into the alpha
	-- multiplier here means every downstream draw inherits it for free.
	local contents = tonumber(setting("map_contents_opacity", 100)) or 100
	am = am * math.max(0.05, math.min(1, contents / 100))

	local layer0 = (render_settings and render_settings.start_layer or 0) + BASE_LAYER

	-- -----------------------------------------------------------------------
	-- Backdrop + border (per theme)
	-- -----------------------------------------------------------------------
	local panel_alpha = math.min(235, opacity * 2.55) * am
	local R = size * 0.5

	if theme == "terminal" then
		if opacity > 0 then
			draw_rect(gui, scale, left - 4, top - 4, size + 8, size + 8, layer0 - 9, Color(220 * am, 0, 0, 0))
			self:_queue_skin(MAT.shadow, left - 16, top - 16, size + 32, size + 32, { 210 * am, 0, 0, 0 }, layer0 - 8)
			self:_queue_skin(MAT.panel_fill, left - 3, top - 3, size + 6, size + 6, { panel_alpha, 5, 9, 10 }, layer0 - 7)
			self:_queue_skin(MAT.panel, left - 3, top - 3, size + 6, size + 6, { 145 * am, 50, 70, 66 }, layer0 - 6)
			self:_queue_skin(MAT.panel_gradient, left + 5, top + 5, size - 10, size - 10, { 52 * am, 0, 0, 0 }, layer0 - 4)
		end

		self:_queue_skin(MAT.inner_shadow, left + 4, top + 4, size - 8, size - 8, { 155 * am, 5, 12, 14 }, layer0 + 11)
		self:_queue_skin(MAT.frame, left - 4, top - 4, size + 8, size + 8, { 190 * am, 126, 156, 151 }, layer0 + 12)
		self:_queue_skin(MAT.corner, left - 4, top - 4, size + 8, size + 8, { 235 * am, 188, 214, 206 }, layer0 + 13)
		self:_queue_skin(MAT.auspex, left + 7, top + 6, 28, 28, { 115 * am, 150, 235, 215 }, layer0 + 14)

		local border_color = Color(85 * am, 126, 180, 170)
		local corner_color = Color(150 * am, 200, 230, 220)
		draw_rect_outline(gui, scale, left + 5, top + 5, size - 10, size - 10, 1.25, layer0 + 10, border_color)
		draw_rect(gui, scale, left + 8, top + 34, 40, 1.25, layer0 + 10, corner_color)
		draw_rect(gui, scale, left + 34, top + 8, 1.25, 40, layer0 + 10, corner_color)
		draw_rect(gui, scale, right - 48, bottom - 35, 40, 1.25, layer0 + 10, corner_color)
		draw_rect(gui, scale, right - 35, bottom - 48, 1.25, 40, layer0 + 10, corner_color)
	elseif auspex then
		if opacity > 0 then
			draw_circle_fill(gui, scale, cx, cy, R + 3, 36, layer0 - 9, Color(math.min(220, panel_alpha + 40), 0, 0, 0))
			draw_circle_fill(gui, scale, cx, cy, R, 36, layer0 - 7, Color(panel_alpha, 5, 9, 10))
		end

		-- Triangle-drawn bezel. Do NOT use ui_portrait_frame_base here: at
		-- panel scale it renders the whole ornate portrait plate (skull and
		-- all) on top of the map, not a ring.
		draw_circle_outline(gui, scale, cx, cy, R + 4, 7, 36, layer0 + 12, Color(215 * am, 26, 33, 33))
		draw_circle_outline(gui, scale, cx, cy, R + 8, 1.5, 36, layer0 + 13, Color(190 * am, 126, 156, 151))
		draw_circle_outline(gui, scale, cx, cy, R + 0.5, 1.5, 36, layer0 + 13, Color(235 * am, 188, 214, 206))
		draw_circle_outline(gui, scale, cx, cy, R - 5, 1, 30, layer0 + 10, Color(75 * am, 126, 180, 170))

		-- cardinal tick marks on the bezel
		for k = 0, 3 do
			local a = k * math.pi * 0.5
			local dx, dy = math.cos(a), math.sin(a)

			draw_line(gui, scale, cx + dx * (R - 1), cy + dy * (R - 1),
				cx + dx * (R + 8), cy + dy * (R + 8), 2.5, layer0 + 13, Color(200 * am, 188, 214, 206))
		end
	elseif theme == "clean_circle" then
		if opacity > 0 then
			draw_circle_fill(gui, scale, cx, cy, R + 2, 36, layer0 - 9, Color(math.min(220, panel_alpha + 40), 0, 0, 0))
			draw_circle_fill(gui, scale, cx, cy, R, 36, layer0 - 7, Color(panel_alpha, 6, 10, 11))
		end

		draw_circle_outline(gui, scale, cx, cy, R + 1, 1.5, 36, layer0 + 12, Color(175 * am, 148, 172, 166))
	elseif theme == "clean" then
		if opacity > 0 then
			draw_rect(gui, scale, left - 2, top - 2, size + 4, size + 4, layer0 - 9, Color(math.min(220, panel_alpha + 40), 0, 0, 0))
			draw_rect(gui, scale, left, top, size, size, layer0 - 7, Color(panel_alpha, 6, 10, 11))
		end

		draw_rect_outline(gui, scale, left - 1, top - 1, size + 2, size + 2, 1.5, layer0 + 12, Color(175 * am, 148, 172, 166))
	elseif theme == "ghost" and opacity > 0 and setting("show_veil", true) ~= false then
		-- "ghost" has no chrome; instead a soft dark halo sits behind the
		-- plan and dissolves outward - the mockup's backdrop, where its
		-- contrast comes from. Drawn with MANY thin rings at small alpha
		-- steps: the dropshadow material was never confirmed rendering at
		-- this size (user screenshots show no halo at all), and few coarse
		-- discs band visibly (video-proven). Deterministic triangles only.
		local quality = effects_quality()

		if quality ~= "off" then
			local va = math.min(140, 60 + opacity * 0.9) * am
			-- 12 rings x 36 segments x 2 tris is ~900 triangles a frame for a
			-- backdrop; the low setting halves both without visible banding.
			local rings = quality == "low" and 6 or 12
			local segs = quality == "low" and 20 or 36
			local inner = R * 0.30
			local step = (R * 1.05 - inner) / rings

			draw_circle_fill(gui, scale, cx, cy, inner + 0.8, 24, layer0 - 9, Color(va * 0.55, 4, 6, 6))

			for i = 0, rings - 1 do
				local p = i / rings
				local ring_alpha = va * 0.55 * (1 - p * p)

				draw_circle_outline(gui, scale, cx, cy, inner + (i + 0.5) * step, step + 0.8, segs,
					layer0 - 9, Color(ring_alpha, 4, 6, 6))
			end
		end

	end

	local ppm = size / zoom -- pixels per metre

	-- -----------------------------------------------------------------------
	-- Walkable geometry (skipped gracefully when this mission has no data)
	-- -----------------------------------------------------------------------
	if map and map.t and setting("floor_style", "tactical") ~= "classic" then
		self:_draw_tactical_floor(gui, scale, t, map, px, py, pz, c, s, ppm,
			left, top, right, bottom, cx, cy, R, round_layout, layer0, am, z_above, z_below)
	elseif map and map.t then
		-- circular panels only need the inscribed circle; square ones must cover
		-- their rotated corners
		local view_radius = (round_layout and (R + 6) or size * 0.7072) / ppm
		local clip_r = R - 1
		local clip_r2 = clip_r * clip_r
		local cell = map.grid_cell or 16
		local tris = map.t
		local floor_z = current_floor_reference(map, tris, cell, px, py, pz)
		local tactical_floors = false

		local col_far_below = Color(105 * am, FLOOR_RGB.far_below[1], FLOOR_RGB.far_below[2], FLOOR_RGB.far_below[3])
		local col_below = Color(135 * am, FLOOR_RGB.below[1], FLOOR_RGB.below[2], FLOOR_RGB.below[3])
		local col_current = Color(175 * am, FLOOR_RGB.current[1], FLOOR_RGB.current[2], FLOOR_RGB.current[3])
		local col_above = Color(70 * am, FLOOR_RGB.above[1], FLOOR_RGB.above[2], FLOOR_RGB.above[3])
		local boundary_by_key = {}
		local boundary_list = {}
		local hatch_count = 0

		local function edge_key(ax, ay, bx, by)
			local a = math.floor(ax * 100 + 0.5) .. ":" .. math.floor(ay * 100 + 0.5)
			local b = math.floor(bx * 100 + 0.5) .. ":" .. math.floor(by * 100 + 0.5)

			return a < b and a .. "|" .. b or b .. "|" .. a
		end

		local function remember_edge(wax, way, wbx, wby, ax, ay, bx, by, tier, edge_alpha)
			local key = edge_key(wax, way, wbx, wby)
			local entry = boundary_by_key[key]

			if entry then
				entry.count = entry.count + 1
				return
			end

			entry = {
				x1 = ax,
				y1 = ay,
				x2 = bx,
				y2 = by,
				tier = tier,
				alpha = edge_alpha,
				count = 1,
			}
			boundary_by_key[key] = entry
			boundary_list[#boundary_list + 1] = entry
		end

		local function render_floor_fill(x1, y1, x2, y2, x3, y3, lofs, color, fully_inside)
			if not color then
				return
			end

			if fully_inside then
				draw_tri(gui, scale, x1, y1, x2, y2, x3, y3, layer0 + lofs, color)
			elseif round_layout then
				draw_tri_clipped_circle(gui, scale, x1, y1, x2, y2, x3, y3, cx, cy, clip_r, layer0 + lofs, color)
			else
				draw_tri_clipped(gui, scale, x1, y1, x2, y2, x3, y3, left, top, right, bottom, layer0 + lofs, color)
			end
		end

		local function draw_map_tri(idx, force_visible)
			local base = (idx - 1) * 7
			local tz = tris[base + 7]

			if not tz then
				return false
			end

			local dz = tz - floor_z
			local tier = force_visible and "current" or elevation_tier(dz)
			local color, lofs, line_tier, edge_alpha, hatch_weight

			if force_visible then
				color, lofs, line_tier, edge_alpha = tactical_floors
					and Color(160 * am, TACTICAL_FLOOR_RGB.current[1], TACTICAL_FLOOR_RGB.current[2], TACTICAL_FLOOR_RGB.current[3])
					or col_current, 3, "current", 225
			elseif dz >= -z_below and dz <= z_above then
				if tactical_floors then
					local current_weight = tactical_floor_blend(dz)

					if tier == "far_below" then
						-- Far lower decks are negative space with only a faint broken
						-- perimeter; opaque slabs were visually swallowing the map.
						color = nil
						lofs, line_tier, edge_alpha = 1, "far_below", 120
					elseif dz < 0 then
						local lower_weight = 1 - current_weight
						local cr, cg, cb = TACTICAL_FLOOR_RGB.current[1], TACTICAL_FLOOR_RGB.current[2], TACTICAL_FLOOR_RGB.current[3]
						local lr, lg, lb = TACTICAL_FLOOR_RGB.below[1], TACTICAL_FLOOR_RGB.below[2], TACTICAL_FLOOR_RGB.below[3]

						if current_weight > 0.02 then
							color = Color(160 * current_weight * am,
								lr * lower_weight + cr * current_weight,
								lg * lower_weight + cg * current_weight,
								lb * lower_weight + cb * current_weight)
						end

						lofs = current_weight >= 0.5 and 3 or 2
						line_tier = current_weight >= 0.5 and "current" or "below"
						edge_alpha = 170 + current_weight * 65
					else
						-- Upper decks surrender their fill as the ramp rises, leaving
						-- only cold-steel contours and sparse diagonal hatching.
						if current_weight > 0.02 then
							color = Color(160 * current_weight * am,
								TACTICAL_FLOOR_RGB.current[1], TACTICAL_FLOOR_RGB.current[2], TACTICAL_FLOOR_RGB.current[3])
						end

						lofs = current_weight >= 0.5 and 3 or 4
						line_tier = current_weight >= 0.5 and "current" or "above"
						edge_alpha = 185 + current_weight * 50
						hatch_weight = 1 - current_weight
					end
				elseif tier == "far_below" then
					color, lofs = col_far_below, 1
				elseif tier == "below" then
					color, lofs = col_below, 2
				elseif tier == "current" then
					color, lofs = col_current, 3
				else
					color, lofs = col_above, 4
				end
			else
				return false
			end

			-- world -> rotated map space -> screen px
			local dx1, dy1 = tris[base + 1] - px, tris[base + 2] - py
			local dx2, dy2 = tris[base + 3] - px, tris[base + 4] - py
			local dx3, dy3 = tris[base + 5] - px, tris[base + 6] - py

			local x1 = cx + (dx1 * c - dy1 * s) * ppm
			local y1 = cy - (dx1 * s + dy1 * c) * ppm
			local x2 = cx + (dx2 * c - dy2 * s) * ppm
			local y2 = cy - (dx2 * s + dy2 * c) * ppm
			local x3 = cx + (dx3 * c - dy3 * s) * ppm
			local y3 = cy - (dx3 * s + dy3 * c) * ppm

			-- trivial reject: fully outside one edge (the circle is inscribed
			-- in the same rect, so this reject is valid for both shapes)
			if (x1 < left and x2 < left and x3 < left)
				or (x1 > right and x2 > right and x3 > right)
				or (y1 < top and y2 < top and y3 < top)
				or (y1 > bottom and y2 > bottom and y3 > bottom) then
				return false
			end

			local fully_inside

			if round_layout then
				local d1 = (x1 - cx) * (x1 - cx) + (y1 - cy) * (y1 - cy)
				local d2 = (x2 - cx) * (x2 - cx) + (y2 - cy) * (y2 - cy)
				local d3 = (x3 - cx) * (x3 - cx) + (y3 - cy) * (y3 - cy)

				fully_inside = d1 <= clip_r2 and d2 <= clip_r2 and d3 <= clip_r2
			else
				fully_inside = x1 >= left and x1 <= right and y1 >= top and y1 <= bottom
				and x2 >= left and x2 <= right and y2 >= top and y2 <= bottom
				and x3 >= left and x3 <= right and y3 >= top and y3 <= bottom
			end

			render_floor_fill(x1, y1, x2, y2, x3, y3, lofs, color, fully_inside)

			if tactical_floors and fully_inside then
				remember_edge(tris[base + 1], tris[base + 2], tris[base + 3], tris[base + 4],
					x1, y1, x2, y2, line_tier, edge_alpha)
				remember_edge(tris[base + 3], tris[base + 4], tris[base + 5], tris[base + 6],
					x2, y2, x3, y3, line_tier, edge_alpha)
				remember_edge(tris[base + 5], tris[base + 6], tris[base + 1], tris[base + 2],
					x3, y3, x1, y1, line_tier, edge_alpha)

				if hatch_weight and hatch_weight > 0.08 and hatch_count < FLOOR_HATCH_CAP then
					local added = draw_triangle_hatches(gui, scale, x1, y1, x2, y2, x3, y3,
						6, layer0 + 6,
						Color((145 + 75 * hatch_weight) * am,
							TACTICAL_FLOOR_RGB.above[1], TACTICAL_FLOOR_RGB.above[2], TACTICAL_FLOOR_RGB.above[3]),
						FLOOR_HATCH_CAP - hatch_count)

					hatch_count = hatch_count + added
				end
			end

			return true
		end

		local frame = self._frame + 1
		self._frame = frame
		local seen = self._seen

		local cx0 = math.floor((px - view_radius) / cell)
		local cx1 = math.floor((px + view_radius) / cell)
		local cy0 = math.floor((py - view_radius) / cell)
		local cy1 = math.floor((py + view_radius) / cell)

		local drawn = 0

		for gx = cx0, cx1 do
			for gy = cy0, cy1 do
				local ids = cell_ids(map, gx .. ":" .. gy)

				if ids then
					for k = 1, #ids do
						local idx = ids[k]

						if seen[idx] ~= frame then
							seen[idx] = frame

							if draw_map_tri(idx, false) then
								drawn = drawn + 1

								if drawn >= MAX_TRIS_PER_FRAME then
									break
								end
							end
						end
					end
				end

				if drawn >= MAX_TRIS_PER_FRAME then
					break
				end
			end

			if drawn >= MAX_TRIS_PER_FRAME then
				break
			end
		end

		-- If the baked cell index or floor-height band misses the player's
		-- current runtime position, keep the mod useful by scanning nearby
		-- triangles directly. Markers still use live positions; this fallback
		-- restores the actual floor plan instead of leaving an empty frame.
		if drawn < 8 then
			-- The full-mesh sweep is O(tri_count); cache its result and only
			-- rescan after the player moves, instead of paying it every frame.
			local fb = self._fallback
			local moved_sq = fb and ((px - fb.x) * (px - fb.x) + (py - fb.y) * (py - fb.y)) or math.huge

			if not fb or fb.map ~= map or moved_sq > 36 or fb.radius < view_radius then
				fb = { map = map, x = px, y = py, radius = view_radius, ids = {} }

				local ids = fb.ids
				local n = 0
				local margin = view_radius + 8
				local radius_sq = margin * margin

				for idx = 1, map.tri_count do
					local base = (idx - 1) * 7
					local mx = (tris[base + 1] + tris[base + 3] + tris[base + 5]) / 3
					local my = (tris[base + 2] + tris[base + 4] + tris[base + 6]) / 3
					local dx = mx - px
					local dy = my - py

					if dx * dx + dy * dy <= radius_sq then
						n = n + 1
						ids[n] = idx
					end
				end

				self._fallback = fb
			end

			local ids = fb.ids

			for i = 1, #ids do
				if draw_map_tri(ids[i], true) then
					drawn = drawn + 1

					if drawn >= MAX_TRIS_PER_FRAME then
						break
					end
				end
			end
		end

		-- Only unmatched navmesh edges are actual walkable-surface contours;
		-- shared triangle edges stay hidden. Upper decks use a thin continuous
		-- outline, while lower decks use short broken segments to recede.
		if tactical_floors then
			local edge_count = 0
			local tier_caps = { current = 55, above = 55, below = 75, far_below = 25 }
			local tier_order = { "current", "above", "below", "far_below" }

			for tindex = 1, #tier_order do
				local wanted_tier = tier_order[tindex]
				local tier_count = 0

				for i = 1, #boundary_list do
					local edge = boundary_list[i]

					if edge.count == 1 and edge.tier == wanted_tier
						and tier_count < tier_caps[wanted_tier] and edge_count < FLOOR_EDGE_CAP then
						local rgb = TACTICAL_FLOOR_RGB[edge.tier] or TACTICAL_FLOOR_RGB.current
						local alpha = (edge.alpha or 180) * am

						if edge.tier == "below" or edge.tier == "far_below" then
							local sx, sy = edge.x2 - edge.x1, edge.y2 - edge.y1

							-- One short segment per boundary edge; the gaps between
							-- neighbouring segments form a stable dotted/broken contour.
							draw_line(gui, scale, edge.x1 + sx * 0.16, edge.y1 + sy * 0.16,
								edge.x1 + sx * 0.52, edge.y1 + sy * 0.52, 1.2, layer0 + 6,
								Color(alpha, rgb[1], rgb[2], rgb[3]))
						else
							draw_line(gui, scale, edge.x1, edge.y1, edge.x2, edge.y2,
								edge.tier == "current" and 1.45 or 1.1, layer0 + 6,
								Color(alpha, rgb[1], rgb[2], rgb[3]))
						end

						tier_count = tier_count + 1
						edge_count = edge_count + 1
					end
				end
			end
		end

		mod._last_geometry_drawn = drawn
	end

	-- -----------------------------------------------------------------------
	-- Rear fade + player lamp glow: panel-space overlays above the floor plan
	-- (layer0+8) and below every marker (+9). Screen-anchored, so the static
	-- cartography never pops while walking - explicitly NOT fog of war. The
	-- ground ahead stays bright; covered ground rolls off toward the rim, and
	-- a warm lamp sits on the panel centre where the player always is.
	-- Stacked low-alpha passes build the smooth ramp: Gui.triangle has no
	-- gradients, and the dropshadow materials were never confirmed rendering
	-- at panel size (ghost-veil precedent).
	-- -----------------------------------------------------------------------
	if map and map.t and setting("show_veil", true) ~= false and effects_quality() ~= "off" then
		-- Behind = opposite the facing: screen-down while the map rotates
		-- with the camera, opposite the heading arrow when north-locked.
		local bxv, byv

		if rotate then
			bxv, byv = 0, 1
		else
			bxv, byv = -math.sin(yaw), math.cos(yaw)
		end

		local pxv, pyv = -byv, bxv
		local reach = size * 0.72
		local d0 = size * 0.06
		local d1 = size * 0.5
		-- Fewer, proportionally denser slices: same ramp, half the triangles.
		local veil_steps = math.max(4, math.floor(REAR_VEIL_STEPS * effects_scale()))
		local veil_color = Color(REAR_VEIL_STEP_ALPHA * am * (REAR_VEIL_STEPS / veil_steps),
			REAR_VEIL_RGB[1], REAR_VEIL_RGB[2], REAR_VEIL_RGB[3])

		for i = 0, veil_steps - 1 do
			local f = (i / veil_steps) ^ 1.35
			local d = d0 + (d1 - d0) * f
			local ax0 = cx + bxv * d - pxv * reach
			local ay0 = cy + byv * d - pyv * reach
			local ax1 = cx + bxv * d + pxv * reach
			local ay1 = cy + byv * d + pyv * reach
			local ex0 = cx + bxv * reach - pxv * reach
			local ey0 = cy + byv * reach - pyv * reach
			local ex1 = cx + bxv * reach + pxv * reach
			local ey1 = cy + byv * reach + pyv * reach

			if round_layout then
				draw_tri_clipped_circle(gui, scale, ax0, ay0, ax1, ay1, ex1, ey1,
					cx, cy, R - 1, layer0 + 8, veil_color)
				draw_tri_clipped_circle(gui, scale, ax0, ay0, ex1, ey1, ex0, ey0,
					cx, cy, R - 1, layer0 + 8, veil_color)
			else
				draw_tri_clipped(gui, scale, ax0, ay0, ax1, ay1, ex1, ey1,
					left, top, right, bottom, layer0 + 8, veil_color)
				draw_tri_clipped(gui, scale, ax0, ay0, ex1, ey1, ex0, ey0,
					left, top, right, bottom, layer0 + 8, veil_color)
			end
		end

		local glow_r = size * GLOW_RADIUS_FRAC
		local glow_steps = math.max(4, math.floor(GLOW_STEPS * effects_scale()))
		local glow_segs = effects_scale() < 1 and 12 or 20
		local glow_color = Color(GLOW_STEP_ALPHA * am * (GLOW_STEPS / glow_steps),
			GLOW_RGB[1], GLOW_RGB[2], GLOW_RGB[3])

		for i = 0, glow_steps - 1 do
			-- linear radii: even, fine steps read as one smooth lamp falloff
			local gr = glow_r * (1 - i / glow_steps)

			draw_circle_fill(gui, scale, cx, cy, gr, glow_segs, layer0 + 8, glow_color)
		end
	end

	-- -----------------------------------------------------------------------
	-- Scanner/radar treatment: subtle enough to keep the floor plan readable.
	-- Terminal gets the crosshair grid + boxes, Auspex gets range rings; clean
	-- and ghost stay untreated.
	-- -----------------------------------------------------------------------
	if theme == "terminal" or auspex then
		local grid_col_soft = Color(22 * am, 96, 205, 186)

		if auspex then
			draw_circle_outline(gui, scale, cx, cy, R * 0.33, 1, 24, layer0 + 5, grid_col_soft)
			draw_circle_outline(gui, scale, cx, cy, R * 0.66, 1, 24, layer0 + 5, grid_col_soft)
			draw_line(gui, scale, cx, cy - R + 8, cx, cy + R - 8, 1, layer0 + 5, grid_col_soft)
			draw_line(gui, scale, cx - R + 8, cy, cx + R - 8, cy, 1, layer0 + 5, grid_col_soft)
		else
			local grid_inset = 14

			draw_line(gui, scale, cx, top + grid_inset, cx, bottom - grid_inset, 1, layer0 + 5, grid_col_soft)
			draw_line(gui, scale, left + grid_inset, cy, right - grid_inset, cy, 1, layer0 + 5, grid_col_soft)

			for i = 1, 3 do
				local box = size * i * 0.24
				draw_rect_outline(gui, scale, cx - box * 0.5, cy - box * 0.5, box, box, 1, layer0 + 5, grid_col_soft)
			end
		end

		if setting("show_scanner_sweep", true) ~= false then
			local scan_radius = auspex and R * 0.94 or size * 0.48
			local scan_angle = ((t or 0) * 1.85) % (math.pi * 2)
			local scan_width = 0.32
			local sx1 = cx + math.cos(scan_angle) * scan_radius
			local sy1 = cy + math.sin(scan_angle) * scan_radius
			local sx2 = cx + math.cos(scan_angle - scan_width) * scan_radius
			local sy2 = cy + math.sin(scan_angle - scan_width) * scan_radius

			draw_tri(gui, scale, cx, cy, sx1, sy1, sx2, sy2, layer0 + 6, Color(24 * am, 120, 255, 210))
			draw_line(gui, scale, cx, cy, sx1, sy1, 2, layer0 + 7, Color(78 * am, 155, 255, 225))
			-- triangle-drawn: ui_portrait_frame_base shows a portrait plate even small
			draw_circle_outline(gui, scale, cx, cy, 13, 1.2, 16, layer0 + 8, Color(85 * am, 145, 235, 215))
		end
	end

	-- -----------------------------------------------------------------------
	-- Orientation + scale readouts
	-- -----------------------------------------------------------------------
	-- North indicator: world +Y projected into panel space, pinned inside the
	-- frame. Keeps you oriented while the map rotates with the camera.
	local north_x = cx + (-s) * (R - 17)
	local north_y = cy + (-c) * (R - 17)

	if not round_layout then
		north_x = math.max(left + 17, math.min(right - 17, north_x))
		north_y = math.max(top + 17, math.min(bottom - 17, north_y))
	end

	draw_diamond(gui, scale, north_x, north_y, 9, layer0 + 9, Color(120 * am, 12, 22, 22))
	self:_queue_text("N", north_x, north_y, 24, 18, 15, { 178, 232, 214 }, 215 * am)

	-- Current zoom span (updates live with the zoom keybinds); centred at the
	-- bottom for circular panels, bottom-left for square ones.
	self:_queue_text(string.format("%d M", math.floor(zoom + 0.5)),
		round_layout and cx or left + 33, bottom - 17, 60, 14, 12, { 150, 220, 202 }, 135 * am)

	if not map then
		self:_queue_text(no_map_text(), cx, cy + size * 0.30, size - 36, 16, 12, { 165, 205, 196 }, 150 * am)
	end

	-- -----------------------------------------------------------------------
	-- Objective strip: the vanilla objective feed, integrated into the panel
	-- (the vanilla HUD element is suppressed while this draws). Attached to
	-- the map edge facing screen centre; themed like the panel itself.
	-- -----------------------------------------------------------------------
	local obj_lines = setting("integrate_objectives", true) ~= false and state.objective_lines

	if obj_lines and #obj_lines > 0 then
		local rows = math.min(#obj_lines, 3)
		local strip_h = 12

		for i = 1, rows do
			strip_h = strip_h + (obj_lines[i].progress and 27 or 21)
		end

		local strip_w = size + 6
		local sx0 = left - 3
		-- Centre-anchored maps have room either side; hang the strip below, as
		-- the top anchors do, so it never runs off the top of the screen.
		local below = corner == "top_left" or corner == "top_right"
			or corner == "top_center" or corner == "center"
		local gap = theme == "terminal" and 10 or 6
		local sy0 = below and (bottom + gap) or (top - strip_h - gap)

		if theme ~= "ghost" then
			draw_rect(gui, scale, sx0, sy0, strip_w, strip_h, layer0 + 3,
				Color(math.min(215, opacity * 2.1 + 70) * am, 4, 8, 8))
			draw_rect(gui, scale, sx0, sy0, strip_w, 1.5, layer0 + 4, Color(150 * am, 126, 180, 170))
			draw_rect(gui, scale, sx0, sy0 + strip_h - 1.5, strip_w, 1.5, layer0 + 4,
				Color(70 * am, 126, 180, 170))
		end

		local ty = sy0 + 9

		for i = 1, rows do
			local o = obj_lines[i]
			local bullet = o.side and { 186, 150, 238 } or { 255, 214, 120 }

			draw_diamond(gui, scale, sx0 + 13, ty + 7, 4, layer0 + 5,
				Color(235 * am, bullet[1], bullet[2], bullet[3]))
			self:_queue_text(tostring(o.text), sx0 + 24, ty + 7, strip_w - 34, 15, 12,
				{ 214, 234, 226 }, 235 * am, layer0 + 5, "left")

			if o.progress then
				local track_w = strip_w - 38
				local frac = math.max(0, math.min(1, o.progress))

				draw_rect(gui, scale, sx0 + 24, ty + 17, track_w, 3, layer0 + 5,
					Color(120 * am, 30, 48, 46))
				draw_rect(gui, scale, sx0 + 24, ty + 17, track_w * frac, 3, layer0 + 6,
					Color(230 * am, 140, 230, 205))
			end

			ty = ty + (o.progress and 27 or 21)
		end
	end

	-- -----------------------------------------------------------------------
	-- Point markers. project() maps a world position into panel px; clamps to
	-- the panel edge when requested (returns clamped flag for dimming).
	-- -----------------------------------------------------------------------
	local function project(wx, wy, clamp)
		local dx, dy = wx - px, wy - py
		local mx = cx + (dx * c - dy * s) * ppm
		local my = cy - (dx * s + dy * c) * ppm
		local clamped = false
		local pad = 12

		if round_layout then
			local ox, oy = mx - cx, my - cy
			local lim = R - pad
			local d2 = ox * ox + oy * oy

			if d2 > lim * lim then
				if not clamp then
					return nil
				end

				clamped = true

				local d = math.sqrt(d2)

				mx = cx + ox / d * lim
				my = cy + oy / d * lim
			end
		elseif mx < left + pad or mx > right - pad or my < top + pad or my > bottom - pad then
			if not clamp then
				return nil
			end

			clamped = true
			mx = math.max(left + pad, math.min(right - pad, mx))
			my = math.max(top + pad, math.min(bottom - pad, my))
		end

		return mx, my, clamped
	end

	local function dim_for_dz(base_alpha, wz)
		if wz and math.abs(wz - pz) > MARKER_DIM_DZ then
			return base_alpha * 0.5
		end

		return base_alpha
	end

	local sight_mode = setting("marker_visibility_mode", "team_los")
	local sight_filter = sight_mode ~= "all"

	local function marker_visible(entry)
		return not sight_filter or entry == nil or entry.visible_by_sight ~= false
	end

	local function draw_sight_cone(observer, rgb, alpha)
		if not observer or type(observer.x) ~= "number" or type(observer.y) ~= "number" then
			return
		end

		local ox, oy = project(observer.x, observer.y, false)

		if not ox then
			return
		end

		local fx, fy = observer.fx, observer.fy

		if observer.is_local then
			fx, fy = math.sin(yaw), math.cos(yaw)
		end

		local fl = fx and fy and math.sqrt(fx * fx + fy * fy) or 0

		if fl <= 0.001 then
			return
		end

		fx, fy = fx / fl, fy / fl

		local prev_x, prev_y
		local first_x, first_y

		for i = 0, SIGHT_CONE_SEGMENTS do
			local a = -SIGHT_CONE_HALF_ANGLE + (SIGHT_CONE_HALF_ANGLE * 2) * (i / SIGHT_CONE_SEGMENTS)
			local ca, sa = math.cos(a), math.sin(a)
			local dx = fx * ca - fy * sa
			local dy = fx * sa + fy * ca
			local ex = observer.x + dx * SIGHT_CONE_RANGE
			local ey = observer.y + dy * SIGHT_CONE_RANGE
			local sx, sy = project(ex, ey, true)

			if sx then
				if prev_x then
					draw_tri(gui, scale, ox, oy, prev_x, prev_y, sx, sy, layer0 + 6, Color(alpha, rgb[1], rgb[2], rgb[3]))
					draw_line(gui, scale, prev_x, prev_y, sx, sy, 1, layer0 + 7, Color(alpha * 1.7, rgb[1], rgb[2], rgb[3]))
				else
					first_x, first_y = sx, sy
				end

				prev_x, prev_y = sx, sy
			else
				prev_x, prev_y = nil, nil
			end
		end

		if first_x and prev_x then
			draw_line(gui, scale, ox, oy, first_x, first_y, 1.2, layer0 + 7, Color(alpha * 2.2, rgb[1], rgb[2], rgb[3]))
			draw_line(gui, scale, ox, oy, prev_x, prev_y, 1.2, layer0 + 7, Color(alpha * 2.2, rgb[1], rgb[2], rgb[3]))
		end
	end

	if sight_filter and setting("show_sight_cones", true) ~= false then
		local observers = state.sight_observers

		if observers and #observers > 0 then
			for i = 1, #observers do
				local observer = observers[i]
				local rgb = observer.is_local and { 255, 236, 182 } or { 110, 214, 235 }
				local alpha = (observer.is_local and 26 or 18) * am

				draw_sight_cone(observer, rgb, alpha)
			end
		else
			draw_sight_cone({ x = px, y = py, z = pz, fx = math.sin(yaw), fy = math.cos(yaw), is_local = true },
				{ 255, 236, 182 }, 26 * am)
		end
	end

	-- Live mission topology: objective locks and tunnel-routing doors are
	-- barriers on the map, with short pulses when their state changes.
	if setting("show_live_gates", true) ~= false and state.gates then
		for i = 1, #state.gates do
			local gate = state.gates[i]
			local gate_am = dim_for_dz(1, gate.z) * am
			local lx, ly, label, rgb, label_alpha = draw_live_gate(gui, scale, gate, state.mission_time,
				function(wx, wy)
					return project(wx, wy, false)
				end, layer0 + 12, gate_am)

			if label and lx then
				self:_queue_text(label, lx, ly, 116, 15, 11, rgb, label_alpha, ICON_LAYER + 8)
			end
		end
	end

	if setting("show_tactical_updates", true) ~= false and state.objective_events then
		for i = 1, #state.objective_events do
			local event = state.objective_events[i]
			local lx, ly, label, rgb, label_alpha = draw_tactical_event(gui, scale, event, state.mission_time,
				function(wx, wy)
					return project(wx, wy, false)
				end, layer0 + 18, dim_for_dz(1, event.z) * am)

			if label and lx then
				self:_queue_text(label, lx, ly, 132, 16, 11, rgb, label_alpha, ICON_LAYER + 10)
			end
		end
	end

	-- Small chevron on edge-clamped markers pointing off-map, so a pinned icon
	-- reads as "further that way" instead of "right at the wall".
	local function draw_clamp_pointer(mx, my, alpha)
		local dx, dy = mx - cx, my - cy
		local len = math.sqrt(dx * dx + dy * dy)

		if len < 1 then
			return
		end

		dx, dy = dx / len, dy / len

		local bx, by = mx + dx * 10, my + dy * 10
		local qx, qy = -dy, dx

		draw_tri(gui, scale,
			bx + dx * 6, by + dy * 6,
			bx + qx * 4.5, by + qy * 4.5,
			bx - qx * 4.5, by - qy * 4.5,
			layer0 + 9, Color(alpha, 224, 238, 232))
	end

	-- Draw one marker in the chosen style: game-material icon or flat shape.
	local function draw_marker(style_name, mx, my, msize, rgb, alpha, ring_material)
		if style_name == "dot" then
			draw_diamond(gui, scale, mx, my, msize * 0.28, layer0 + 8, Color(alpha, rgb[1], rgb[2], rgb[3]))
		elseif style_name == "diamond" then
			draw_diamond(gui, scale, mx, my, msize * 0.45, layer0 + 8, Color(60 * am, 0, 0, 0))
			draw_diamond(gui, scale, mx, my, msize * 0.34, layer0 + 8, Color(alpha, rgb[1], rgb[2], rgb[3]))
		elseif style_name == "square" then
			local r = msize * 0.34
			draw_rect(gui, scale, mx - r - 1.5, my - r - 1.5, r * 2 + 3, r * 2 + 3, layer0 + 8, Color(60 * am, 0, 0, 0))
			draw_rect(gui, scale, mx - r, my - r, r * 2, r * 2, layer0 + 8, Color(alpha, rgb[1], rgb[2], rgb[3]))
		elseif style_name == "triangle" then
			draw_tri(gui, scale,
				mx, my - msize * 0.50,
				mx + msize * 0.46, my + msize * 0.38,
				mx - msize * 0.46, my + msize * 0.38,
				layer0 + 8, Color(60 * am, 0, 0, 0))
			draw_tri(gui, scale,
				mx, my - msize * 0.38,
				mx + msize * 0.34, my + msize * 0.28,
				mx - msize * 0.34, my + msize * 0.28,
				layer0 + 8, Color(alpha, rgb[1], rgb[2], rgb[3]))
		elseif style_name == "cross" then
			local arm = msize * 0.28
			local bar = msize * 0.14
			local col = Color(alpha, rgb[1], rgb[2], rgb[3])
			draw_rect(gui, scale, mx - arm, my - bar, arm * 2, bar * 2, layer0 + 8, col)
			draw_rect(gui, scale, mx - bar, my - arm, bar * 2, arm * 2, layer0 + 8, col)
		elseif style_name == "ring" then
			draw_circle_outline(gui, scale, mx, my, msize * 0.42, math.max(1.5, msize * 0.12), 12,
				layer0 + 8, Color(alpha, rgb[1], rgb[2], rgb[3]))
		elseif style_name == "skull" then
			self:_queue_icon(MAT.skull, mx, my, msize, rgb, alpha)
		elseif style_name == "enemy_priority" then
			self:_queue_icon(MAT.enemy_priority, mx, my, msize, rgb, alpha)
		else -- "enemy" and any unknown value: enemy silhouette icon
			self:_queue_icon(MAT.enemy, mx, my, msize, rgb, alpha)
		end
	end

	local function draw_player_ping(mx, my, rgb, alpha, radius)
		if alpha <= 1 then
			return
		end

		local base_phase = ((t or 0) * 1.65) % 1
		local inner = radius * 0.28

		for i = 0, 2 do
			local p = (base_phase + i / 3) % 1
			local r = radius - p * (radius - inner)
			local end_fade = p > 0.82 and (1 - (p - 0.82) / 0.18) or 1
			local ring_alpha = alpha * (0.32 + 0.58 * p) * end_fade

			draw_circle_outline(gui, scale, mx, my, r, math.max(1.15, radius * 0.055), 18,
				layer0 + 10, Color(ring_alpha, rgb[1], rgb[2], rgb[3]))
		end

		draw_diamond(gui, scale, mx, my, math.max(3.5, radius * 0.15), layer0 + 11,
			Color(alpha * 0.88, rgb[1], rgb[2], rgb[3]))
	end

	local function draw_ping_item(kind, mx, my, alpha)
		local visual = kind and PING_KIND_VISUALS[kind]

		if not visual then
			return
		end

		local item_rgb = palette_rgb(visual.color, "white")
		local item_alpha = math.min(255, alpha * 1.08)

		if visual.material then
			self:_queue_icon(visual.material, mx, my, visual.size or 18, item_rgb, item_alpha, ICON_LAYER + 4)
		else
			draw_marker(visual.style or "dot", mx, my, visual.size or 14, item_rgb, item_alpha)
		end
	end

	-- Objectives (game world-marker mirror)
	if setting("show_objectives", true) ~= false and state.objectives then
		local o_style = setting("objective_style", "icon")
		local rgb = palette_rgb(setting("objective_color", "gold"), "gold")

		for i = 1, #state.objectives do
			local o = state.objectives[i]
			local mx, my, clamped = project(o.x, o.y, true)

			if marker_visible(o) and mx then
				local alpha = (clamped and 150 or 245) * am

				if o_style == "icon" then
					self:_queue_icon(MAT.objective, mx, my, 24, rgb, alpha)
				else
					draw_diamond(gui, scale, mx, my, 10, layer0 + 7, Color(alpha, rgb[1], rgb[2], rgb[3]))
					draw_diamond(gui, scale, mx, my, 5, layer0 + 7, Color(alpha, 30, 26, 16))
				end

				if clamped then
					draw_clamp_pointer(mx, my, 170 * am)
				end
			end
		end
	end

	-- Medicae stations
	if setting("show_medicae", true) ~= false and state.medicae then
		local m_style = setting("medicae_style", "icon")
		local rgb = palette_rgb(setting("medicae_color", "green"), "green")

		for i = 1, #state.medicae do
			local m = state.medicae[i]
			local mx, my, clamped = project(m.x, m.y, true)

			if marker_visible(m) and mx then
				local alpha = dim_for_dz(clamped and 130 or 235, m.z) * am

				if m_style == "icon" then
					self:_queue_icon(MAT.medicae, mx, my, 22, rgb, alpha)
				else
					local col = Color(alpha, rgb[1], rgb[2], rgb[3])
					draw_rect(gui, scale, mx - 7, my - 2.5, 14, 5, layer0 + 6, col)
					draw_rect(gui, scale, mx - 2.5, my - 7, 5, 14, layer0 + 6, col)
				end

				-- Remaining charge count, live from the station extension.
				if setting("show_medicae_charges", true) ~= false and m.charges then
					if m.charges > 0 then
						self:_queue_text(tostring(m.charges), mx + 11, my - 9, 18, 13, 12, rgb, alpha)
					else
						self:_queue_text("0", mx + 11, my - 9, 18, 13, 12, { 255, 110, 96 }, alpha)
					end
				end

				if clamped then
					draw_clamp_pointer(mx, my, 140 * am)
				end
			end
		end
	end

	-- Containers/books/materials use compact shapes; actionable pickups keep
	-- their game icons so ammo, grenades, crates and stimms read at a glance.
	local function draw_station_group(list, style_name, rgb, msize, base_alpha)
		for i = 1, #list do
			local u = list[i]
			local mx, my, clamped = project(u.x, u.y, true)

			if marker_visible(u) and mx and not clamped then
				draw_marker(style_name, mx, my, msize, rgb, dim_for_dz(base_alpha, u.z) * am)
			end
		end
	end

	local function draw_pickup_icon_group(list, material, color_setting, fallback_color, size, base_alpha)
		local rgb = palette_rgb(setting(color_setting, fallback_color), fallback_color)

		for i = 1, #list do
			local item = list[i]
			local mx, my, clamped = project(item.x, item.y, true)

			if marker_visible(item) and mx and not clamped then
				self:_queue_icon(material, mx, my, size, rgb, dim_for_dz(base_alpha, item.z) * am, ICON_LAYER + 3)
			end
		end
	end

	local function draw_stimms(list)
		local color_setting = setting("stimms_color", "by_type")

		for i = 1, #list do
			local item = list[i]
			local visual = PING_KIND_VISUALS[item.kind] or PING_KIND_VISUALS.pickup
			local mx, my, clamped = project(item.x, item.y, true)

			if marker_visible(item) and mx and not clamped then
				local color_name = color_setting == "by_type" and visual.color or color_setting
				local rgb = palette_rgb(color_name, visual.color or "cyan")
				self:_queue_icon(visual.material or MAT.pickup, mx, my, visual.size or 19, rgb,
					dim_for_dz(235, item.z) * am, ICON_LAYER + 3)
			end
		end
	end

	if setting("show_supplies", true) ~= false and state.supplies then
		draw_station_group(state.supplies, "square", palette_rgb(setting("supplies_color", "amber"), "amber"), 13, 225)
	end

	if setting("show_books", true) ~= false and state.books then
		draw_station_group(state.books, "diamond", palette_rgb(setting("books_color", "violet"), "violet"), 16, 240)
	end

	if setting("show_ammo_pickups", true) ~= false and state.ammo then
		draw_pickup_icon_group(state.ammo, MAT.ammo, "ammo_pickups_color", "amber", 17, 230)
	end

	if setting("show_grenades", true) ~= false and state.grenades then
		draw_pickup_icon_group(state.grenades, MAT.grenade, "grenades_color", "orange", 18, 235)
	end

	if setting("show_ammo_crates", true) ~= false and state.ammo_crates then
		draw_pickup_icon_group(state.ammo_crates, MAT.ammo_crate, "ammo_crates_color", "amber", 21, 240)
	end

	if setting("show_med_crates", true) ~= false and state.med_crates then
		draw_pickup_icon_group(state.med_crates, MAT.med_crate, "med_crates_color", "green", 21, 240)
	end

	if setting("show_stimms", true) ~= false and state.stimms then
		draw_stimms(state.stimms)
	end

	if setting("show_materials", false) == true and state.materials then
		draw_station_group(state.materials, "dot", palette_rgb(setting("materials_color", "steel"), "steel"), 11, 170)
	end

	-- Enemies (in view range only, never clamped to the edge)
	local enemies = state.enemies

	if enemies then
		local use_type_overrides = setting("enemy_type_overrides", false) ~= false
		local enemy_visual_cache = {}

		local function enemy_visual(enemy, fallback_style, fallback_rgb, fallback_color_name)
			local enemy_type = use_type_overrides and enemy and enemy.enemy_type

			if enemy_type then
				local cached = enemy_visual_cache[enemy_type]

				if cached then
					return cached.style, cached.rgb, cached.scale
				end

				local defaults = ENEMY_TYPE_DEFAULTS[enemy_type]
				local default_style = (defaults and defaults.icon) or fallback_style
				local default_color = (defaults and defaults.color) or auto_enemy_color_name(enemy_type, fallback_color_name)
				local prefix = "enemy_type_" .. enemy_type
				local style_name = setting(prefix .. "_icon", default_style)
				local rgb = palette_rgb(setting(prefix .. "_color", default_color), default_color)
				local marker_scale = math.max(0.5,
					math.min(2.5, (tonumber(setting(prefix .. "_scale", 100)) or 100) / 100))

				cached = { style = style_name, rgb = rgb, scale = marker_scale }
				enemy_visual_cache[enemy_type] = cached

				return style_name, rgb, marker_scale
			end

			return fallback_style, fallback_rgb, 1
		end

		if setting("show_monsters", true) ~= false and enemies.monster then
			local e_style = setting("monster_icon", "enemy_priority")
			local rgb = palette_rgb(setting("monster_color", "red"), "red")

			for i = 1, #enemies.monster do
				local e = enemies.monster[i]
				local mx, my = project(e.x, e.y, false)

				if marker_visible(e) and mx then
					local style_name, marker_rgb, marker_scale = enemy_visual(e, e_style, rgb, "red")

					draw_marker(style_name, mx, my, 26 * marker_scale, marker_rgb, dim_for_dz(245, e.z) * am)
				end
			end
		end

		if setting("show_specials", true) ~= false and enemies.special then
			local e_style = setting("special_icon", "enemy_priority")
			local rgb = palette_rgb(setting("special_color", "yellow"), "yellow")

			for i = 1, #enemies.special do
				local e = enemies.special[i]
				local mx, my = project(e.x, e.y, false)

				if marker_visible(e) and mx then
					local style_name, marker_rgb, marker_scale = enemy_visual(e, e_style, rgb, "yellow")

					draw_marker(style_name, mx, my, 19 * marker_scale, marker_rgb, dim_for_dz(235, e.z) * am)
				end
			end
		end

		if setting("show_elites", true) ~= false and enemies.elite then
			local e_style = setting("elite_icon", "enemy")
			local rgb = palette_rgb(setting("elite_color", "orange"), "orange")

			for i = 1, #enemies.elite do
				local e = enemies.elite[i]
				local mx, my = project(e.x, e.y, false)

				if marker_visible(e) and mx then
					local style_name, marker_rgb, marker_scale = enemy_visual(e, e_style, rgb, "orange")

					draw_marker(style_name, mx, my, 18 * marker_scale, marker_rgb, dim_for_dz(225, e.z) * am)
				end
			end
		end

		if setting("show_horde", true) ~= false and enemies.horde then
			local e_style = setting("horde_icon", "dot")
			local rgb = palette_rgb(setting("horde_color", "red"), "red")

			for i = 1, #enemies.horde do
				local e = enemies.horde[i]
				local mx, my = project(e.x, e.y, false)

				if marker_visible(e) and mx then
					local style_name, marker_rgb, marker_scale = enemy_visual(e, e_style, rgb, "red")

					draw_marker(style_name, mx, my, 12 * marker_scale, marker_rgb, dim_for_dz(190, e.z) * am)
				end
			end
		end
	end

	-- Teammates
	if setting("show_teammates", true) ~= false and player_manager then
		local a_style = setting("ally_style", "class_icon")
		local color_mode = setting("ally_color_mode", "slot_colors")
		local fixed_rgb = palette_rgb(setting("ally_color", "cyan"), "cyan")
		local slot_colors = UISettings.player_slot_colors

		local players = player_manager:players()

		for _, other in pairs(players) do
			if other ~= player then
				local unit = other.player_unit

				if unit and Unit.alive(unit) then
					local pos = Unit.world_position(unit, 1)
					local mx, my, clamped = project(pos.x, pos.y, true)

					if mx then
						local rgb = fixed_rgb
						local status = teammate_live_status(unit)

						if color_mode == "slot_colors" and slot_colors then
							local slot = other.slot and other:slot()
							local slot_color = slot and slot_colors[slot]

							if type(slot_color) == "table" and #slot_color >= 4 then
								rgb = { slot_color[2], slot_color[3], slot_color[4] }
							end
						end

						local alpha = (clamped and 140 or 240) * am
						local class_icon = a_style == "class_icon" and player_archetype_icon(other)

						if class_icon then
							-- Dark underlay keeps thin class glyphs legible over every
							-- elevation colour; the party-slot ring preserves identity.
							draw_circle_fill(gui, scale, mx, my, 9.5, 14, layer0 + 8, Color(alpha * 0.72, 5, 8, 8))
							self:_queue_text(class_icon, mx, my - 0.5, 24, 24, 20, rgb, alpha, layer0 + 10)
						else
							draw_marker(a_style == "class_icon" and "diamond" or a_style,
								mx, my, 18, rgb, alpha, MAT.ring)
						end

						local dirx = status.fx * c - status.fy * s
						local diry = -(status.fx * s + status.fy * c)

						draw_ally_status(gui, scale, mx, my, status, rgb, dirx, diry, t,
							layer0 + 9, clamped and 0.58 * am or am, 10.5)
						draw_ally_badges(self, gui, scale, mx, my, status.badges, ICON_LAYER + 6,
							clamped and 0.58 * am or am)

						if clamped then
							draw_clamp_pointer(mx, my, 150 * am)
						end
					end
				end
			end
		end
	end

	-- Player pings from Darktide's smart-tag system.
	if setting("show_player_pings", true) ~= false and state.pings then
		for i = 1, #state.pings do
			local ping = state.pings[i]
			local mx, my, clamped = project(ping.x, ping.y, true)

			if marker_visible(ping) and mx then
				local rgb = ping.rgb or PALETTE.cyan
				local fade = ping.fade or 1
				local alpha = dim_for_dz(clamped and 150 or 245, ping.z) * am * fade

				draw_player_ping(mx, my, rgb, alpha, clamped and 22 or 28)
				draw_ping_item(ping.kind, mx, my, alpha)

				if clamped then
					draw_clamp_pointer(mx, my, 150 * am * fade)
				end
			end
		end
	end

	-- -----------------------------------------------------------------------
	-- Local player arrow (screen direction of world heading h = (sin yaw, cos yaw))
	-- -----------------------------------------------------------------------
	local hx, hy = math.sin(yaw), math.cos(yaw)
	local dirx = hx * c - hy * s
	local diry = -(hx * s + hy * c)
	local perpx, perpy = -diry, dirx

	local tipx, tipy = cx + dirx * 13, cy + diry * 13
	local blx, bly = cx - dirx * 8 + perpx * 8, cy - diry * 8 + perpy * 8
	local brx, bry = cx - dirx * 8 - perpx * 8, cy - diry * 8 - perpy * 8
	local notchx, notchy = cx - dirx * 3, cy - diry * 3

	-- dark outline, then two-half fill meeting at a rear notch
	draw_tri(gui, scale, cx + dirx * 16, cy + diry * 16,
		cx - dirx * 11 + perpx * 11, cy - diry * 11 + perpy * 11,
		cx - dirx * 11 - perpx * 11, cy - diry * 11 - perpy * 11,
		layer0 + 9, Color(150 * am, 10, 10, 12))
	draw_tri(gui, scale, tipx, tipy, blx, bly, notchx, notchy, layer0 + 9, Color(235 * am, 255, 234, 180))
	draw_tri(gui, scale, tipx, tipy, notchx, notchy, brx, bry, layer0 + 9, Color(235 * am, 255, 234, 180))
end

-- ---------------------------------------------------------------------------
-- Full-map overview: the entire floor plan, projected in a tilted 2.5D view
-- with floors lifted by elevation and lit from the front, opened on a hotkey.
-- ---------------------------------------------------------------------------
function StrikemapElement:_fullmap_bounds(map)
	local b = self._fm_bounds

	-- revision guards live maps (expedition scan): geometry grows in place,
	-- so table identity alone would pin stale bounds
	if b and b.map == map and b.rev == (map.revision or 0) then
		return b
	end

	local tris = map.t
	local n = map.tri_count
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	local z0, z1 = math.huge, -math.huge

	for i = 0, n - 1 do
		local o = i * 7

		for k = 0, 2 do
			local x = tris[o + 1 + k * 2]
			local y = tris[o + 2 + k * 2]

			if x < x0 then x0 = x end
			if x > x1 then x1 = x end
			if y < y0 then y0 = y end
			if y > y1 then y1 = y end
		end

		local z = tris[o + 7]

		if z < z0 then z0 = z end
		if z > z1 then z1 = z end
	end

	b = { map = map, x0 = x0, y0 = y0, x1 = x1, y1 = y1, z0 = z0, z1 = z1 }
	self._fm_bounds = b

	return b
end

function StrikemapElement:_draw_fullmap_empty(ui_renderer, render_settings, state)
	local gui = ui_renderer.gui
	local scale = ui_renderer.scale or 1
	local am = render_settings and render_settings.alpha_multiplier or 1
	local layer0 = (render_settings and render_settings.start_layer or 0) + BASE_LAYER
	local sw, sh = virtual_screen_size(scale)

	draw_rect(gui, scale, 0, 0, sw, sh, layer0, Color(212 * am, 3, 5, 6))
	self:_queue_text("++ TACTICAL AUSPEX ++", sw * 0.5, sh * 0.5 - 14, 600, 34, 26,
		{ 214, 236, 228 }, 240 * am, layer0 + 100)
	self:_queue_text(no_map_text(), sw * 0.5, sh * 0.5 + 18, 600, 20, 15,
		{ 150, 190, 182 }, 175 * am, layer0 + 100)
end

function StrikemapElement:_draw_tactical_fullmap_geometry(gui, scale, now, map, px, py, pz,
		proj, z0, z_range, layer0, am, shade_top, shade_bottom)
	ensure_floor_vectors(map)

	local tris = map.t
	local target_floor_z = current_floor_reference(map, tris, map.grid_cell or 16, px, py, pz)
	local floor_z = smoothed_floor_reference(self, map, target_floor_z, now)
	local ramp_ids = nearby_ramp_transitions(map, px, py)
	local drawn = 0
	-- Declared before draw_full_shaded_surface so the closure captures it.
	local low_fidelity = setting("perf_fullmap_fidelity", "high") == "low"

	local function draw_full_shaded_surface(ax, ay, bx, by, cx, cy, layer,
			r, g, b, alpha, current_weight)
		local function shade(y)
			local p = math.max(0, math.min(1, (y - shade_top) / math.max(1, shade_bottom - shade_top)))
			return 1.20 - p * 0.42, 1.15 - p * 0.34, 1.06 - p * 0.20
		end

		local rf, gf, bf = shade((ay + by + cy) / 3)
		draw_tri(gui, scale, ax, ay, bx, by, cx, cy, layer,
			Color(alpha, math.min(255, r * rf), math.min(255, g * gf), math.min(255, b * bf)))

		local area2 = math.abs((bx - ax) * (cy - ay) - (cx - ax) * (by - ay))
		if not low_fidelity and current_weight > 0.18 and area2 > 180 then
			local x12, y12 = (ax + bx) * 0.5, (ay + by) * 0.5
			local x23, y23 = (bx + cx) * 0.5, (by + cy) * 0.5
			local x31, y31 = (cx + ax) * 0.5, (cy + ay) * 0.5
			local facets = {
				{ ax, ay, x12, y12, x31, y31 },
				{ x12, y12, bx, by, x23, y23 },
				{ x31, y31, x23, y23, cx, cy },
				{ x12, y12, x23, y23, x31, y31 },
			}

			for i = 1, 4 do
				local f = facets[i]
				local fy = (f[2] + f[4] + f[6]) / 3
				local p = math.max(0, math.min(1, (fy - shade_top) / math.max(1, shade_bottom - shade_top)))
				local signed = 0.5 - p
				local overlay_alpha = math.abs(signed) * 108 * current_weight * am
				local or_, og, ob = 34, 45, 46

				if signed > 0 then or_, og, ob = 236, 229, 199 end
				draw_tri(gui, scale, f[1], f[2], f[3], f[4], f[5], f[6], layer + 1,
					Color(overlay_alpha, or_, og, ob))
			end
		end
	end

	-- This walked EVERY triangle in the level with no ceiling; the classic path
	-- has always been capped. Low fidelity also drops the drop-shadow pass and
	-- the per-triangle relief facets, which together are most of the cost.
	local fm_cap = low_fidelity and 6000 or MAX_FULLMAP_TRIS
	local fm_count = math.min(map.tri_count, fm_cap)
	local fm_stride = map.tri_count > fm_count and (map.tri_count / fm_count) or 1
	local fm_pos = 1

	for _ = 1, fm_count do
		local idx = fm_stride > 1 and math.floor(fm_pos) or fm_pos
		fm_pos = fm_pos + fm_stride

		local o = (idx - 1) * 7
		local tz = tris[o + 7]
		local mx = (tris[o + 1] + tris[o + 3] + tris[o + 5]) / 3
		local my = (tris[o + 2] + tris[o + 4] + tris[o + 6]) / 3
		local dz = ramp_adjusted_dz(map, ramp_ids, mx, my, tz, px, py, floor_z)
		local current_weight = tactical_floor_blend(dz)
		local tier = elevation_tier(dz)
		local band = math.max(0, math.min(FM_MAX_BAND, math.floor((tz - z0) / FM_BAND)))
		local layer = layer0 + 4 + band * 3
		local ax, ay = proj(tris[o + 1], tris[o + 2], tz)
		local bx, by = proj(tris[o + 3], tris[o + 4], tz)
		local cx, cy = proj(tris[o + 5], tris[o + 6], tz)

		if current_weight > 0.015 then
			if not low_fidelity then
				draw_tri(gui, scale, ax + 1.5, ay + 5, bx + 1.5, by + 5, cx + 1.5, cy + 5, layer,
					Color(155 * current_weight * am, 6, 9, 9))
			end

			draw_tri(gui, scale, ax, ay, bx, by, cx, cy, layer + 1,
				Color(88 * current_weight * am, 19, 22, 20))

			local other = 1 - current_weight
			local accent = dz < 0 and TACTICAL_FLOOR_RGB.below or TACTICAL_FLOOR_RGB.above
			draw_full_shaded_surface(ax, ay, bx, by, cx, cy, layer + 2,
				TACTICAL_FLOOR_RGB.current[1] * current_weight + accent[1] * other,
				TACTICAL_FLOOR_RGB.current[2] * current_weight + accent[2] * other,
				TACTICAL_FLOOR_RGB.current[3] * current_weight + accent[3] * other,
				(210 * current_weight + 14 * other) * am, current_weight)
		elseif tier ~= "far_below" then
			local rgb = TACTICAL_FLOOR_RGB[tier]
			draw_tri(gui, scale, ax, ay, bx, by, cx, cy, layer + 1,
				Color((tier == "below" and 20 or 12) * am, rgb[1], rgb[2], rgb[3]))
		end

		drawn = drawn + 1
	end

	for idx = 1, map.stair_count or 0 do
		local o = (idx - 1) * 6
		local wx1, wy1, wx2, wy2 = map.s[o + 1], map.s[o + 2], map.s[o + 3], map.s[o + 4]
		local z1, z2 = map.s[o + 5], map.s[o + 6]
		local zmid = (z1 + z2) * 0.5
		local dz = ramp_adjusted_dz(map, ramp_ids, (wx1 + wx2) * 0.5, (wy1 + wy2) * 0.5,
			zmid, px, py, floor_z)
		local weight = math.max(tactical_floor_blend(z1 - floor_z), tactical_floor_blend(z2 - floor_z))

		if weight > 0.08 and dz >= -12 and dz <= 8 then
			local x1, y1 = proj(wx1, wy1, zmid)
			local x2, y2 = proj(wx2, wy2, zmid)
			draw_line(gui, scale, x1, y1, x2, y2, 2.25, layer0 + 72,
				Color((58 + 62 * weight) * am, 20, 26, 24))
			draw_line(gui, scale, x1, y1, x2, y2, 0.86, layer0 + 73,
				Color((88 + 112 * weight) * am, 216, 210, 182))
		end
	end

	for idx = 1, map.hatch_count or 0 do
		local o = (idx - 1) * 5
		local wx1, wy1, wx2, wy2, tz = map.h[o + 1], map.h[o + 2], map.h[o + 3], map.h[o + 4], map.h[o + 5]
		local dz = ramp_adjusted_dz(map, ramp_ids, (wx1 + wx2) * 0.5, (wy1 + wy2) * 0.5, tz, px, py, floor_z)
		local weight = dz > 0 and 1 - tactical_floor_blend(dz) or 0

		if weight > 0.08 then
			local x1, y1 = proj(wx1, wy1, tz)
			local x2, y2 = proj(wx2, wy2, tz)
			draw_line(gui, scale, x1, y1, x2, y2, 0.72, layer0 + 73,
				Color((82 + 112 * weight) * am,
					TACTICAL_FLOOR_RGB.above[1], TACTICAL_FLOOR_RGB.above[2], TACTICAL_FLOOR_RGB.above[3]))
		end
	end

	for idx = 1, map.contour_count or 0 do
		local o = (idx - 1) * 5
		local wx1, wy1, wx2, wy2, tz = map.c[o + 1], map.c[o + 2], map.c[o + 3], map.c[o + 4], map.c[o + 5]
		local dz = ramp_adjusted_dz(map, ramp_ids, (wx1 + wx2) * 0.5, (wy1 + wy2) * 0.5, tz, px, py, floor_z)
		local weight = tactical_floor_blend(dz)
		local tier = weight >= 0.5 and "current" or elevation_tier(dz)
		local rgb = TACTICAL_FLOOR_RGB[tier]
		local length = math.sqrt((wx2 - wx1) * (wx2 - wx1) + (wy2 - wy1) * (wy2 - wy1))

		if tier == "below" or tier == "far_below" then
			local period, dash = 1.35, 0.46
			local phase = math.abs(wx1 * 0.754877666 + wy1 * 0.569840291) % period
			local distance = -phase

			while length > 0.01 and distance < length do
				local a, b = math.max(0, distance), math.min(length, distance + dash)

				if b > a then
					local u0, u1 = a / length, b / length
					local x1, y1 = proj(wx1 + (wx2 - wx1) * u0, wy1 + (wy2 - wy1) * u0, tz)
					local x2, y2 = proj(wx1 + (wx2 - wx1) * u1, wy1 + (wy2 - wy1) * u1, tz)
					draw_line(gui, scale, x1, y1, x2, y2, 1.05, layer0 + 75,
						Color((tier == "below" and 184 or 112) * am, rgb[1], rgb[2], rgb[3]))
				end

				distance = distance + period
			end
		else
			local x1, y1 = proj(wx1, wy1, tz)
			local x2, y2 = proj(wx2, wy2, tz)
			draw_line(gui, scale, x1, y1, x2, y2, tier == "current" and 3.1 or 1.9, layer0 + 74,
				Color((tier == "current" and 138 or 92) * am, 17, 22, 21))
			draw_line(gui, scale, x1, y1, x2, y2, tier == "current" and 1.25 or 0.8, layer0 + 75,
				Color((tier == "current" and 234 or 190) * am,
					tier == "current" and 222 or rgb[1],
					tier == "current" and 219 or rgb[2],
					tier == "current" and 193 or rgb[3]))
		end
	end

	mod._last_geometry_drawn = drawn
	return drawn
end

function StrikemapElement:_draw_fullmap(ui_renderer, render_settings, t, map, state)
	local gui = ui_renderer.gui
	local scale = ui_renderer.scale or 1
	local am = render_settings and render_settings.alpha_multiplier or 1
	local layer0 = (render_settings and render_settings.start_layer or 0) + BASE_LAYER
	local sw, sh = virtual_screen_size(scale)

	-- Player view (computed independently of the corner-strikemap path).
	local parent = self._parent
	local camera = parent and parent.player_camera and parent:player_camera()
	local player = Managers.player and Managers.player:local_player(1)
	local unit = player and player.player_unit
	local px, py, pz

	if unit and Unit.alive(unit) then
		local p = Unit.world_position(unit, 1)
		px, py, pz = p.x, p.y, p.z
	elseif camera then
		local p = Camera.local_position(camera)
		px, py, pz = p.x, p.y, p.z
	end

	local yaw = 0

	if camera then
		local f = Quaternion.forward(Camera.local_rotation(camera))
		yaw = math.atan2(f.x, f.y)
	end

	mod._camera_forward_x = math.sin(yaw)
	mod._camera_forward_y = math.cos(yaw)

	-- Backdrop dims the game behind the overview.
	draw_rect(gui, scale, 0, 0, sw, sh, layer0, Color(214 * am, 3, 5, 6))

	local b = self:_fullmap_bounds(map)
	local mcx, mcy = (b.x0 + b.x1) * 0.5, (b.y0 + b.y1) * 0.5
	local map_w = math.max(1, b.x1 - b.x0)
	local map_h = math.max(1, b.y1 - b.y0)
	local z_range = math.max(0, b.z1 - b.z0)

	local rotate = setting("fullmap_rotate", false) == true
	local rc, rsin = 1, 0

	if rotate then
		rc, rsin = math.cos(yaw), math.sin(yaw)
	end

	local preset = FM_PITCH_PRESETS[state.fullmap_pitch_idx or 2] or FM_PITCH_PRESETS[2]
	local tilt, lift = preset.tilt, preset.lift
	local zoom = state.fullmap_zoom or 1
	local region_w = sw - 2 * FM_MARGIN
	local region_h = sh - 2 * FM_MARGIN - FM_TITLE_H
	-- rotating can swing either world axis onto either screen axis
	local span = rotate and (map_w + map_h) * 0.72 or nil
	local span_w = span or map_w
	local span_h = span or map_h
	local proj_h = span_h * tilt + z_range * lift
	local fit = math.min(region_w / span_w, region_h / proj_h) * zoom
	local center_x = sw * 0.5
	local center_y = FM_MARGIN + FM_TITLE_H + region_h * 0.5

	local function proj(wx, wy, wz)
		local dx, dy = wx - mcx, wy - mcy
		local rx = dx * rc - dy * rsin
		local ry = dx * rsin + dy * rc

		return center_x + rx * fit,
			center_y - ry * fit * tilt - (wz - b.z0) * fit * lift
	end

	-- Geometry: the selected floor language is shared with every corner frame.
	-- Classic keeps the original shaded slab model; Tactical Contours anchors
	-- its solid/high/low treatment to the player's current walkable floor.
	local tris = map.t
	local base_layer = layer0 + 4
	local drawn = 0
	local requested_tactical = setting("floor_style", "tactical") ~= "classic" and px ~= nil

	if requested_tactical then
		drawn = self:_draw_tactical_fullmap_geometry(gui, scale, t, map, px, py, pz,
			proj, b.z0, z_range, layer0, am, FM_MARGIN + FM_TITLE_H, sh - FM_MARGIN)
	end

	-- The legacy loop below is retained solely for Classic. Giving Tactical a
	-- zero-length legacy pass guarantees it cannot fall back to triangle-local
	-- hatches or viewport-derived outlines.
	local n = requested_tactical and 0 or math.min(map.tri_count, MAX_FULLMAP_TRIS)
	local fullmap_tactical = false
	local floor_z = px and current_floor_reference(map, tris, map.grid_cell or 16, px, py, pz) or nil
	local fullmap_hatches = 0
	local fm_edge_by_key = {}
	local fm_edge_list = {}

	local function fm_edge_key(ax, ay, bx, by)
		local a = math.floor(ax * 100 + 0.5) .. ":" .. math.floor(ay * 100 + 0.5)
		local bkey = math.floor(bx * 100 + 0.5) .. ":" .. math.floor(by * 100 + 0.5)

		return a < bkey and a .. "|" .. bkey or bkey .. "|" .. a
	end

	local function fm_remember_edge(wax, way, wbx, wby, ax, ay, bx, by, tier)
		local key = fm_edge_key(wax, way, wbx, wby)
		local edge = fm_edge_by_key[key]

		if edge then
			edge.count = edge.count + 1
			return
		end

		edge = { x1 = ax, y1 = ay, x2 = bx, y2 = by, tier = tier, count = 1 }
		fm_edge_by_key[key] = edge
		fm_edge_list[#fm_edge_list + 1] = edge
	end

	for i = 0, n - 1 do
		local o = i * 7
		local tz = tris[o + 7]
		local ax, ay = proj(tris[o + 1], tris[o + 2], tz)
		local bx2, by2 = proj(tris[o + 3], tris[o + 4], tz)
		local cx2, cy2 = proj(tris[o + 5], tris[o + 6], tz)

		local band = math.floor((tz - b.z0) / FM_BAND)

		if band < 0 then
			band = 0
		elseif band > FM_MAX_BAND then
			band = FM_MAX_BAND
		end

		local layer = base_layer + band * 3

		-- shade: higher floors brighter; the far (north) side falls into shadow
		local th = z_range > 0 and (tz - b.z0) / z_range or 0
		local ny = ((tris[o + 2] + tris[o + 4] + tris[o + 6]) / 3 - mcy) / map_h
		local lit = (0.74 + th * 0.42) * (1 - ny * 0.28)

		if lit < 0.35 then
			lit = 0.35
		elseif lit > 1.25 then
			lit = 1.25
		end

		if fullmap_tactical and floor_z then
			local dz = tz - floor_z
			local tier = elevation_tier(dz)
			local current_weight = tactical_floor_blend(dz)
			local line_tier = current_weight >= 0.5 and "current" or tier
			local surface_color

			if tier == "far_below" then
				surface_color = nil
			elseif dz < 0 then
				local lower_weight = 1 - current_weight
				local cr, cg, cb = TACTICAL_FLOOR_RGB.current[1], TACTICAL_FLOOR_RGB.current[2], TACTICAL_FLOOR_RGB.current[3]
				local lr, lg, lb = TACTICAL_FLOOR_RGB.below[1], TACTICAL_FLOOR_RGB.below[2], TACTICAL_FLOOR_RGB.below[3]

				if current_weight > 0.02 then
					surface_color = Color(205 * current_weight * am,
						lr * lower_weight + cr * current_weight,
						lg * lower_weight + cg * current_weight,
						lb * lower_weight + cb * current_weight)
				end
			else
				local upper_weight = 1 - current_weight

				if current_weight > 0.02 then
					surface_color = Color(205 * current_weight * am,
						TACTICAL_FLOOR_RGB.current[1] * current_weight + TACTICAL_FLOOR_RGB.above[1] * upper_weight,
						TACTICAL_FLOOR_RGB.current[2] * current_weight + TACTICAL_FLOOR_RGB.above[2] * upper_weight,
						TACTICAL_FLOOR_RGB.current[3] * current_weight + TACTICAL_FLOOR_RGB.above[3] * upper_weight)
				end
			end

			-- Only the active part of a transition receives slab depth. Separate
			-- upper/lower decks are deliberately reduced to line language.
			if current_weight > 0.02 then
				draw_tri(gui, scale, ax + 2, ay + 7, bx2 + 2, by2 + 7, cx2 + 2, cy2 + 7, layer,
					Color(185 * current_weight * am, 9, 12, 12))
			end

			if surface_color then
				draw_tri(gui, scale, ax, ay, bx2, by2, cx2, cy2, layer + 1, surface_color)
			end

			if dz > 0 and 1 - current_weight > 0.08 and fullmap_hatches < 280 then
				local added = draw_triangle_hatches(gui, scale, ax, ay, bx2, by2, cx2, cy2,
					10, layer + 2,
					Color((135 + 75 * (1 - current_weight)) * am,
						TACTICAL_FLOOR_RGB.above[1], TACTICAL_FLOOR_RGB.above[2], TACTICAL_FLOOR_RGB.above[3]),
					280 - fullmap_hatches)

				fullmap_hatches = fullmap_hatches + added
			end

			fm_remember_edge(tris[o + 1], tris[o + 2], tris[o + 3], tris[o + 4], ax, ay, bx2, by2, line_tier)
			fm_remember_edge(tris[o + 3], tris[o + 4], tris[o + 5], tris[o + 6], bx2, by2, cx2, cy2, line_tier)
			fm_remember_edge(tris[o + 5], tris[o + 6], tris[o + 1], tris[o + 2], cx2, cy2, ax, ay, line_tier)
		else
			-- Classic auspex depth palette: hive murk below, pale phosphor above.
			draw_tri(gui, scale, ax + 2, ay + 7, bx2 + 2, by2 + 7, cx2 + 2, cy2 + 7, layer,
				Color(238 * am, 10 + band, 16 + band, 15 + band))
			draw_tri(gui, scale, ax, ay, bx2, by2, cx2, cy2, layer + 1,
				Color(242 * am, math.min(255, (56 + 96 * th) * lit), math.min(255, (72 + 116 * th) * lit),
					math.min(255, (68 + 100 * th) * lit)))
		end

		drawn = drawn + 1
	end

	if fullmap_tactical and floor_z then
		local rendered_edges = 0

		for i = 1, #fm_edge_list do
			local edge = fm_edge_list[i]

			if edge.count == 1 and rendered_edges < 500 then
				local rgb = TACTICAL_FLOOR_RGB[edge.tier] or TACTICAL_FLOOR_RGB.current

				if edge.tier == "below" or edge.tier == "far_below" then
					local sx, sy = edge.x2 - edge.x1, edge.y2 - edge.y1

					draw_line(gui, scale, edge.x1 + sx * 0.16, edge.y1 + sy * 0.16,
						edge.x1 + sx * 0.52, edge.y1 + sy * 0.52, 1.2, layer0 + 74,
						Color(165 * am, rgb[1], rgb[2], rgb[3]))
				else
					draw_line(gui, scale, edge.x1, edge.y1, edge.x2, edge.y2,
						edge.tier == "current" and 1.45 or 1.1, layer0 + 74,
						Color(edge.tier == "current" and 230 * am or 195 * am, rgb[1], rgb[2], rgb[3]))
				end

				rendered_edges = rendered_edges + 1
			end
		end
	end

	mod._last_geometry_drawn = drawn

	local mlayer = layer0 + 90
	local ilayer = layer0 + 95
	local tlayer = layer0 + 100

	-- ground pin: shows a lifted marker's height without dropping a full line
	-- to the map's lowest point (that reads as a curtain on tall levels)
	local function fm_stem(wx, wy, wz, rgb, a)
		local mx, my = proj(wx, wy, wz)
		local _, gy = proj(wx, wy, b.z0)
		local drop = gy - my

		if drop > 12 then
			local pin = math.min(drop, 40)

			draw_line(gui, scale, mx, my, mx, my + pin, 1.2, mlayer - 2, Color(a * 0.38, rgb[1], rgb[2], rgb[3]))

			if pin >= drop - 1 then
				draw_diamond(gui, scale, mx, gy, 2.2, mlayer - 2, Color(a * 0.5, rgb[1], rgb[2], rgb[3]))
			end
		end
	end

	local function fm_diamond(wx, wy, wz, r, rgb, a)
		local mx, my = proj(wx, wy, wz)

		fm_stem(wx, wy, wz, rgb, a)
		draw_diamond(gui, scale, mx, my, r + 1.5, mlayer, Color(130 * am, 0, 0, 0))
		draw_diamond(gui, scale, mx, my, r, mlayer + 1, Color(a, rgb[1], rgb[2], rgb[3]))
	end

	local function fm_ping(wx, wy, wz, rgb, a)
		if a <= 1 then
			return
		end

		local mx, my = proj(wx, wy, wz)
		local radius = 34
		local inner = 8
		local base_phase = ((t or 0) * 1.65) % 1

		for i = 0, 2 do
			local p = (base_phase + i / 3) % 1
			local r = radius - p * (radius - inner)
			local end_fade = p > 0.82 and (1 - (p - 0.82) / 0.18) or 1
			local ring_alpha = a * (0.30 + 0.56 * p) * end_fade

			draw_circle_outline(gui, scale, mx, my, r, 2.1, 22, mlayer + 4,
				Color(ring_alpha, rgb[1], rgb[2], rgb[3]))
		end

		draw_diamond(gui, scale, mx, my, 5.5, mlayer + 5, Color(a * 0.90, rgb[1], rgb[2], rgb[3]))
	end

	local function fm_ping_item(kind, wx, wy, wz, a)
		local visual = kind and PING_KIND_VISUALS[kind]

		if not visual then
			return
		end

		local mx, my = proj(wx, wy, wz)
		local item_rgb = palette_rgb(visual.color, "white")
		local item_alpha = math.min(255, a * 1.05)

		if visual.material then
			self:_queue_icon(visual.material, mx, my, (visual.size or 18) + 4, item_rgb, item_alpha, ilayer + 6)
		elseif visual.style == "square" then
			draw_rect(gui, scale, mx - 5.5, my - 5.5, 11, 11, mlayer + 6,
				Color(item_alpha, item_rgb[1], item_rgb[2], item_rgb[3]))
		else
			draw_diamond(gui, scale, mx, my, visual.style == "dot" and 4.5 or 8, mlayer + 6,
				Color(item_alpha, item_rgb[1], item_rgb[2], item_rgb[3]))
		end
	end

	local sight_mode = setting("marker_visibility_mode", "team_los")
	local sight_filter = sight_mode ~= "all"

	local function marker_visible(entry)
		return not sight_filter or entry == nil or entry.visible_by_sight ~= false
	end

	local function fm_sight_cone(observer, rgb, alpha)
		if not observer or type(observer.x) ~= "number" or type(observer.y) ~= "number" then
			return
		end

		local ox, oy = proj(observer.x, observer.y, observer.z or pz or 0)
		local fx, fy = observer.fx, observer.fy

		if observer.is_local then
			fx, fy = math.sin(yaw), math.cos(yaw)
		end

		local fl = fx and fy and math.sqrt(fx * fx + fy * fy) or 0

		if fl <= 0.001 then
			return
		end

		fx, fy = fx / fl, fy / fl

		local prev_x, prev_y
		local first_x, first_y
		local wz = observer.z or pz or 0

		for i = 0, SIGHT_CONE_SEGMENTS do
			local a = -SIGHT_CONE_HALF_ANGLE + (SIGHT_CONE_HALF_ANGLE * 2) * (i / SIGHT_CONE_SEGMENTS)
			local ca, sa = math.cos(a), math.sin(a)
			local dx = fx * ca - fy * sa
			local dy = fx * sa + fy * ca
			local sx, sy = proj(observer.x + dx * SIGHT_CONE_RANGE, observer.y + dy * SIGHT_CONE_RANGE, wz)

			if prev_x then
				draw_tri(gui, scale, ox, oy, prev_x, prev_y, sx, sy, mlayer - 4, Color(alpha, rgb[1], rgb[2], rgb[3]))
				draw_line(gui, scale, prev_x, prev_y, sx, sy, 1.1, mlayer - 3, Color(alpha * 1.6, rgb[1], rgb[2], rgb[3]))
			else
				first_x, first_y = sx, sy
			end

			prev_x, prev_y = sx, sy
		end

		if first_x and prev_x then
			draw_line(gui, scale, ox, oy, first_x, first_y, 1.4, mlayer - 3, Color(alpha * 2, rgb[1], rgb[2], rgb[3]))
			draw_line(gui, scale, ox, oy, prev_x, prev_y, 1.4, mlayer - 3, Color(alpha * 2, rgb[1], rgb[2], rgb[3]))
		end
	end

	if sight_filter and setting("show_sight_cones", true) ~= false then
		local observers = state.sight_observers

		if observers and #observers > 0 then
			for i = 1, #observers do
				local observer = observers[i]
				local rgb = observer.is_local and { 255, 236, 182 } or { 110, 214, 235 }
				local alpha = (observer.is_local and 30 or 22) * am

				fm_sight_cone(observer, rgb, alpha)
			end
		elseif px then
			fm_sight_cone({ x = px, y = py, z = pz, fx = math.sin(yaw), fy = math.cos(yaw), is_local = true },
				{ 255, 236, 182 }, 30 * am)
		end
	end

	if setting("show_live_gates", true) ~= false and state.gates then
		for i = 1, #state.gates do
			local gate = state.gates[i]
			local lx, ly, label, rgb, label_alpha = draw_live_gate(gui, scale, gate, state.mission_time,
				function(wx, wy, wz)
					return proj(wx, wy, wz or gate.z or b.z0)
				end, mlayer + 8, am)

			if label and lx then
				self:_queue_text(label, lx, ly - 3, 150, 18, 13, rgb, label_alpha, tlayer + 4)
			end
		end
	end

	if setting("show_tactical_updates", true) ~= false and state.objective_events then
		for i = 1, #state.objective_events do
			local event = state.objective_events[i]
			local lx, ly, label, rgb, label_alpha = draw_tactical_event(gui, scale, event, state.mission_time,
				function(wx, wy, wz)
					return proj(wx, wy, wz or event.z or b.z0)
				end, mlayer + 14, am)

			if label and lx then
				self:_queue_text(label, lx, ly - 3, 180, 20, 14, rgb, label_alpha, tlayer + 6)
			end
		end
	end

	-- Objectives + medicae (with charges) as game-material icons.
	if setting("show_objectives", true) ~= false and state.objectives then
		local rgb = palette_rgb(setting("objective_color", "gold"), "gold")

		for i = 1, #state.objectives do
			local ob = state.objectives[i]

			if marker_visible(ob) then
				local mx, my = proj(ob.x, ob.y, ob.z)

				fm_stem(ob.x, ob.y, ob.z, rgb, 245 * am)
				self:_queue_icon(MAT.objective, mx, my, 30, rgb, 245 * am, ilayer)
			end
		end
	end

	if setting("show_medicae", true) ~= false and state.medicae then
		local rgb = palette_rgb(setting("medicae_color", "green"), "green")

		for i = 1, #state.medicae do
			local m = state.medicae[i]

			if marker_visible(m) then
				local mx, my = proj(m.x, m.y, m.z)

				fm_stem(m.x, m.y, m.z, rgb, 235 * am)
				self:_queue_icon(MAT.medicae, mx, my, 26, rgb, 235 * am, ilayer)

				if setting("show_medicae_charges", true) ~= false and m.charges then
					local crgb = m.charges > 0 and rgb or { 255, 110, 96 }

					self:_queue_text(tostring(m.charges), mx + 13, my - 11, 20, 14, 13, crgb, 240 * am, tlayer)
				end
			end
		end
	end

	local function fm_pickup_icon_group(list, material, color_setting, fallback_color, size, alpha)
		local rgb = palette_rgb(setting(color_setting, fallback_color), fallback_color)

		for i = 1, #list do
			local item = list[i]

			if marker_visible(item) then
				local mx, my = proj(item.x, item.y, item.z)
				self:_queue_icon(material, mx, my, size, rgb, alpha * am, ilayer + 2)
			end
		end
	end

	local function fm_stimms(list)
		local color_setting = setting("stimms_color", "by_type")

		for i = 1, #list do
			local item = list[i]
			local visual = PING_KIND_VISUALS[item.kind] or PING_KIND_VISUALS.pickup

			if marker_visible(item) then
				local mx, my = proj(item.x, item.y, item.z)
				local color_name = color_setting == "by_type" and visual.color or color_setting
				local rgb = palette_rgb(color_name, visual.color or "cyan")

				self:_queue_icon(visual.material or MAT.pickup, mx, my, (visual.size or 19) + 3,
					rgb, 245 * am, ilayer + 2)
			end
		end
	end

	if setting("show_books", true) ~= false and state.books then
		local rgb = palette_rgb(setting("books_color", "violet"), "violet")

		for i = 1, #state.books do
			local book = state.books[i]

			if marker_visible(book) then
				fm_diamond(book.x, book.y, book.z, 8, rgb, 245 * am)
			end
		end
	end

	if setting("show_ammo_pickups", true) ~= false and state.ammo then
		fm_pickup_icon_group(state.ammo, MAT.ammo, "ammo_pickups_color", "amber", 21, 240)
	end

	if setting("show_grenades", true) ~= false and state.grenades then
		fm_pickup_icon_group(state.grenades, MAT.grenade, "grenades_color", "orange", 22, 245)
	end

	if setting("show_ammo_crates", true) ~= false and state.ammo_crates then
		fm_pickup_icon_group(state.ammo_crates, MAT.ammo_crate, "ammo_crates_color", "amber", 25, 245)
	end

	if setting("show_med_crates", true) ~= false and state.med_crates then
		fm_pickup_icon_group(state.med_crates, MAT.med_crate, "med_crates_color", "green", 25, 245)
	end

	if setting("show_stimms", true) ~= false and state.stimms then
		fm_stimms(state.stimms)
	end

	if setting("show_materials", false) == true and state.materials then
		local rgb = palette_rgb(setting("materials_color", "steel"), "steel")

		for i = 1, #state.materials do
			local item = state.materials[i]

			if marker_visible(item) then
				fm_diamond(item.x, item.y, item.z, 3.5, rgb, 210 * am)
			end
		end
	end

	if setting("show_supplies", true) ~= false and state.supplies then
		local rgb = palette_rgb(setting("supplies_color", "amber"), "amber")

		for i = 1, #state.supplies do
			local s = state.supplies[i]

			if marker_visible(s) then
				local mx, my = proj(s.x, s.y, s.z)

				draw_rect(gui, scale, mx - 4.5, my - 4.5, 9, 9, mlayer, Color(60 * am, 0, 0, 0))
				draw_rect(gui, scale, mx - 3, my - 3, 6, 6, mlayer + 1, Color(232 * am, rgb[1], rgb[2], rgb[3]))
			end
		end
	end

	-- Enemies as compact dots per category (kept simple so the map stays clean).
	local enemies = state.enemies

	if enemies then
		local cats = {
			{ enemies.monster, "monster_color", "red", 8 },
			{ enemies.special, "special_color", "yellow", 6 },
			{ enemies.elite, "elite_color", "orange", 6 },
			{ enemies.horde, "horde_color", "red", 4 },
		}

		for c = 1, #cats do
			local list = cats[c][1]

			if list then
				local rgb = palette_rgb(setting(cats[c][2], cats[c][3]), cats[c][3])
				local r = cats[c][4]

				for i = 1, #list do
					local e = list[i]

					if marker_visible(e) then
						local mx, my = proj(e.x, e.y, e.z)

						-- stems for the threats worth tracking; horde would be noise
						if c <= 2 then
							fm_stem(e.x, e.y, e.z, rgb, 225 * am)
						end

						draw_diamond(gui, scale, mx, my, r, mlayer, Color(225 * am, rgb[1], rgb[2], rgb[3]))
					end
				end
			end
		end
	end

	-- Teammates use the same class glyph + party-colour treatment as the
	-- corner map. Legacy shape styles remain available in Mod Options.
	if setting("show_teammates", true) ~= false and Managers.player then
		local slot_colors = UISettings.player_slot_colors
		local a_style = setting("ally_style", "class_icon")
		local color_mode = setting("ally_color_mode", "slot_colors")

		for _, other in pairs(Managers.player:players()) do
			local ou = other and other.player_unit

			if ou and ou ~= unit and Unit.alive(ou) then
				local p = Unit.world_position(ou, 1)
				local rgb = palette_rgb(setting("ally_color", "cyan"), "cyan")

				if color_mode == "slot_colors" and slot_colors and other.slot then
					local sc = slot_colors[other:slot()]

					if type(sc) == "table" and #sc >= 4 then
						rgb = { sc[2], sc[3], sc[4] }
					end
				end

				local class_icon = a_style == "class_icon" and player_archetype_icon(other)
				local status = teammate_live_status(ou)
				local mx, my = proj(p.x, p.y, p.z)

				if class_icon then
					fm_stem(p.x, p.y, p.z, rgb, 245 * am)
					draw_circle_fill(gui, scale, mx, my, 10.5, 14, mlayer, Color(190 * am, 5, 8, 8))
					self:_queue_text(class_icon, mx, my - 0.5, 26, 26, 22, rgb, 250 * am, tlayer)
				else
					fm_diamond(p.x, p.y, p.z, 9, rgb, 245 * am)
				end

				local rhx = status.fx * rc - status.fy * rsin
				local rhy = status.fx * rsin + status.fy * rc

				draw_ally_status(gui, scale, mx, my, status, rgb, rhx, -rhy * tilt, t,
					mlayer + 1, am, 11.5)
				draw_ally_badges(self, gui, scale, mx, my, status.badges, ilayer + 8, am)
			end
		end
	end

	if setting("show_player_pings", true) ~= false and state.pings then
		for i = 1, #state.pings do
			local ping = state.pings[i]

			if marker_visible(ping) then
				local rgb = ping.rgb or PALETTE.cyan
				local fade = ping.fade or 1

				fm_ping(ping.x, ping.y, ping.z, rgb, 245 * am * fade)
				fm_ping_item(ping.kind, ping.x, ping.y, ping.z, 245 * am * fade)
			end
		end
	end

	-- Local player arrow.
	if px then
		local mx, my = proj(px, py, pz)

		fm_stem(px, py, pz, { 255, 236, 182 }, 246 * am)

		local hx, hy = math.sin(yaw), math.cos(yaw)
		local rhx = hx * rc - hy * rsin
		local rhy = hx * rsin + hy * rc
		local dirx, diry = rhx, -rhy * tilt
		local dl = math.sqrt(dirx * dirx + diry * diry)

		if dl > 0.001 then
			dirx, diry = dirx / dl, diry / dl
		end

		local perpx, perpy = -diry, dirx

		draw_tri(gui, scale,
			mx + dirx * 20, my + diry * 20,
			mx - dirx * 13 + perpx * 13, my - diry * 13 + perpy * 13,
			mx - dirx * 13 - perpx * 13, my - diry * 13 - perpy * 13,
			mlayer + 3, Color(165 * am, 8, 10, 12))
		draw_tri(gui, scale,
			mx + dirx * 16, my + diry * 16,
			mx - dirx * 10 + perpx * 10, my - diry * 10 + perpy * 10,
			mx - dirx * 3, my - diry * 3,
			mlayer + 4, Color(246 * am, 255, 236, 182))
		draw_tri(gui, scale,
			mx + dirx * 16, my + diry * 16,
			mx - dirx * 3, my - diry * 3,
			mx - dirx * 10 - perpx * 10, my - diry * 10 - perpy * 10,
			mlayer + 4, Color(246 * am, 255, 236, 182))
	end

	-- Chrome: title rule, corner brackets, compass, zoom readout and scale bar.
	local accent = Color(150 * am, 200, 230, 220)
	local region_top = FM_MARGIN + FM_TITLE_H

	draw_rect(gui, scale, FM_MARGIN, FM_MARGIN + FM_TITLE_H - 16, sw - 2 * FM_MARGIN, 1.5, layer0 + 92, accent)
	draw_brackets(gui, scale, FM_MARGIN - 10, region_top - 6, sw - 2 * FM_MARGIN + 20, sh - region_top - FM_MARGIN + 12,
		26, 2.5, layer0 + 92, Color(190 * am, 170, 220, 205))
	self:_queue_text("++ TACTICAL AUSPEX ++", center_x, FM_MARGIN + 18, 600, 34, 26, { 214, 236, 228 }, 242 * am, tlayer)
	self:_queue_text((tostring(state.mission or ""):upper():gsub("_", " ")), center_x, FM_MARGIN + 44, 600, 20, 14,
		{ 150, 190, 182 }, 175 * am, tlayer)

	-- compass: points at true north even when the map rotates with the camera
	local comp_x = sw - FM_MARGIN - 26
	local comp_y = region_top + 26
	local ndx, ndy = -rsin, -rc * FM_TILT
	local ndl = math.sqrt(ndx * ndx + ndy * ndy)

	if ndl > 0.001 then
		ndx, ndy = ndx / ndl, ndy / ndl
	end

	draw_circle_outline(gui, scale, comp_x, comp_y, 15, 1.5, 18, layer0 + 92, Color(150 * am, 170, 214, 200))
	draw_line(gui, scale, comp_x - ndx * 10, comp_y - ndy * 10, comp_x + ndx * 10, comp_y + ndy * 10, 2,
		layer0 + 93, Color(220 * am, 255, 234, 180))
	draw_tri(gui, scale,
		comp_x + ndx * 14, comp_y + ndy * 14,
		comp_x + ndx * 6 - ndy * 5, comp_y + ndy * 6 + ndx * 5,
		comp_x + ndx * 6 + ndy * 5, comp_y + ndy * 6 - ndx * 5,
		layer0 + 93, Color(235 * am, 255, 234, 180))
	self:_queue_text("N", comp_x + ndx * 26, comp_y + ndy * 26, 20, 14, 12, { 255, 240, 190 }, 220 * am, tlayer)

	-- zoom + pitch readout under the compass
	self:_queue_text(string.format("ZOOM %.1fx", zoom), comp_x - 8, comp_y + 44, 90, 14, 11,
		{ 150, 220, 202 }, 175 * am, tlayer)
	self:_queue_text(preset.label, comp_x - 8, comp_y + 60, 110, 14, 11, { 150, 220, 202 }, 175 * am, tlayer)

	local bar_m = 20
	local bar_px = bar_m * fit
	local barx = FM_MARGIN + 6
	local bary = sh - FM_MARGIN + 8

	draw_rect(gui, scale, barx, bary, bar_px, 2, layer0 + 92, accent)
	draw_rect(gui, scale, barx, bary - 4, 2, 9, layer0 + 92, accent)
	draw_rect(gui, scale, barx + bar_px, bary - 4, 2, 9, layer0 + 92, accent)
	self:_queue_text(bar_m .. " M", barx + bar_px * 0.5, bary - 15, 60, 14, 12, { 150, 220, 202 }, 165 * am, tlayer)

	-- control hints, bottom-right
	self:_queue_text("ZOOM -/+     STRIKEMAP KEY: PITCH     FULL MAP KEY: CLOSE", sw - FM_MARGIN - 230, bary - 15,
		460, 14, 11, { 140, 186, 176 }, 150 * am, tlayer)
end

return StrikemapElement
