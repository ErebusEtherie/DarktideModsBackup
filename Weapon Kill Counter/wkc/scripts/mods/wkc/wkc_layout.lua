local mod = get_mod("wkc")

local lua_io         = Mods and Mods.lua and Mods.lua.io
local lua_loadstring = Mods and Mods.lua and Mods.lua.loadstring

local POLL_INTERVAL = 0.25

mod._LAYOUT_EXTRA_SLOTS = 32

local _material_cache = {}

function mod._material_ok(path)
	if type(path) ~= "string" or path == "" then return false end
	local cached = _material_cache[path]
	if cached ~= nil then return cached end
	local ok, exists = pcall(function()
		return Application and Application.can_get_resource
			and Application.can_get_resource("material", path)
	end)
	local result = (ok and exists) and true or false
	_material_cache[path] = result
	return result
end

function mod._safe_material(path, fallback)
	if mod._material_ok(path) then return path end
	if fallback and mod._material_ok(fallback) then return fallback end
	return nil
end

local TERMINAL_PRIMARY   = { a = 255, r = 216, g = 229, b = 207 }
local TERMINAL_TINT      = { a = 255, r =  90, g = 115, b =  83 }
local TERMINAL_PLATE     = { a = 100, r =  49, g =  56, b =  49 }
local WHITE              = { a = 255, r = 255, g = 255, b = 255 }

local ROW_LEVEL_COLORS = {
	[0] = { { 255, 255, 255, 255 }, { 255, 255, 255, 255 }, 28, 34, 22 },
	[1] = { { 255, 216, 229, 207 }, { 255, 255, 242, 230 }, 22, 23, 22 },
	[2] = { { 255, 190, 208, 178 }, { 255, 216, 229, 207 }, 16, 20, 29 },
	[3] = { { 255, 109, 100, 111 }, { 255, 109, 100, 111 }, 15, 17, 27 },
	[4] = { { 255, 165, 154, 121 }, { 255, 166, 186, 152 }, 14, 26, 22 },
}

function mod._card_offsets(cfg, card_w, card_h)
	local block = cfg.text_w
	if cfg.icon_on then block = block + cfg.icon_size + cfg.gap end

	local x = cfg.x
	if card_w and card_w > 0 then
		local min_x = block - card_w
		if min_x > 0 then min_x = 0 end
		if x > 0 then x = 0 end
		if x < min_x then x = min_x end
	end

	local y = cfg.y
	if card_h and card_h > 0 then
		local reach = (card_h - cfg.font_size) * 0.5
		if reach < 0 then reach = 0 end
		if y > reach then y = reach end
		if y < -reach then y = -reach end
	end

	return x, y
end

function mod._detail_text_dx(cfg, box_w)
	return cfg.icon_dx + cfg.icon_size * 0.5 + cfg.gap + box_w * 0.5
end

function mod._lobby_offsets(cfg, box_w)
	return cfg.x + box_w * 0.5, cfg.x - cfg.gap - cfg.icon_size * 0.5
end

function mod._no_wrap_w(font_size, text, min_w)
	local n = #tostring(text or "")
	local w = (n + 2) * math.max(font_size or 0, 0)
	if min_w and min_w > w then w = min_w end
	return w
end

function mod._abbrev_num(n)
	n = math.floor((n or 0) + 0.5)
	if n == 0 then return "0" end
	local a = math.abs(n)
	local sign = n < 0 and "-" or ""
	local scaled, suffix
	if a >= 1e9 then
		scaled, suffix = a / 1e9, "B"
	elseif a >= 1e6 then
		scaled, suffix = a / 1e6, "M"
	elseif a >= 1000 then
		scaled, suffix = a / 1e3, "k"
	else
		return sign .. tostring(a)
	end
	local str = string.format("%.1f", scaled)
	str = str:gsub("%.0$", "")
	return sign .. str .. suffix
end

local function rgba(t)
	return { a = t[1], r = t[2], g = t[3], b = t[4] }
end

local function copy_color(c)
	return { a = c.a, r = c.r, g = c.g, b = c.b }
end

local function build_defaults()
	local ranks = {}
	do
		local function put(idx, tier)
			local c = tier and tier.color
			ranks[idx] = {
				name  = "",
				color = { a = c and c[1] or 255, r = c and c[2] or 255,
				          g = c and c[3] or 255, b = c and c[4] or 255 },
			}
		end
		put(1, mod._HONORIFIC_DEFAULT)
		local tiers = mod._HONORIFIC_TIERS or {}
		for n = 1, #tiers do put(n + 1, tiers[n]) end
	end

	local levels = {}
	for i = 0, 4 do
		local spec = ROW_LEVEL_COLORS[i]
		levels[i] = {
			font_size   = spec[3],
			height      = spec[4],
			indent      = spec[5],
			label_color = rgba(spec[1]),
			value_color = rgba(spec[2]),
		}
	end

	return {
		version = 8,
		panel = { x = -18, y = -3, w = 705, h = 793, layer = 51,
			color = { a = 100, r = 0, g = 0, b = 0 } },
		preview = {
			enabled = 1, layer = 10, rotate = 1,
			vx = -4, vy = -24, vw = 71, vh = 100,
			wx = 24, wy = 50, zoom = 0,
		},
		body = {
			dx = -1, dy = -23, w_add = -7, h_add = 24,
			layer = 51, color = { a = 255, r = 90, g = 88, b = 83 },
			material = "content/ui/materials/backgrounds/terminal_basic",
		},
		shadow = {
			enabled = 1, expand = 50, layer = 17,
			color = { a = 200, r = 0, g = 0, b = 0 },
			material = "content/ui/materials/frames/dropshadow_large",
		},
		header = {
			dx = 0, dy = -54, h = 148, inset = -11, rise = 54, layer = 57,
			candles_inset = -600, candles_h = 0, candles_dy = -400,
			color = copy_color(WHITE),
			material = "content/ui/materials/frames/character_selection_top",
			candles = "content/ui/materials/effects/masteries/panel_main_top_frame_candles",
			candles_color = copy_color(WHITE),
		},
		footer = {
			dx = 0, dy = 0, h = 72, inset = -11, drop = 40, layer = 57,
			candles_inset = -105, candles_h = 427, candles_dy = -59,
			color = copy_color(WHITE),
			material = "content/ui/materials/frames/masteries/panel_main_lower_frame",
			candles = "content/ui/materials/effects/masteries/panel_main_lower_frame_candles",
			candles_color = copy_color(WHITE),
		},
		frame = {
			enabled = 0, layer = 52, color = copy_color(TERMINAL_TINT),
			material = "content/ui/materials/frames/frame_tile_2px",
		},
		divider_top = {
			dx = 0, dy = -23, top_offset = 0, inset = 0, h = 36, layer = 53,
			color = copy_color(WHITE),
			material = "content/ui/materials/dividers/horizontal_frame_big_upper",
		},
		divider_title = {
			dx = 0, dy = 7, top_offset = 48, inset = 0, h = 40, layer = 55,
			color = copy_color(WHITE),
			material = "content/ui/materials/dividers/horizontal_frame_big_middle",
		},
		divider_bottom = {
			dx = 0, dy = -38, bottom_offset = 38, inset = -103, h = 27, layer = 53,
			color = copy_color(WHITE),
			material = "content/ui/materials/dividers/horizontal_frame_big_lower",
		},
		title_plate = {
			dx = 0, dy = 0, top_offset = 16, inset = 4, h = 58, layer = 53,
			color = { a = 34, r = 255, g = 255, b = 255 },
			plate_color = copy_color(TERMINAL_PLATE),
			material = "content/ui/materials/backgrounds/headline_terminal",
		},
		title = {
			dx = 0, dy = -7, top_offset = 22, inset = 60, h = 59, layer = 56,
			font_size = 27, color = copy_color(WHITE),
			font_type = "proxima_nova_light",
			material = "",
		},
		section = {
			font_size = 34, gap_before = 2, gap_after = 1, layer = 53,
			font_type = "proxima_nova_bold",
			color = copy_color(TERMINAL_PRIMARY),
		},
		scrollbar = {
			enabled = 1, w = 1, inset = 10, top_pad = 0, bottom_pad = 0,
			min_thumb = 40, layer = 58, hold = 90, fade = 60,
			color = { a = 255, r = 60, g = 78, b = 57 },
			track_color = { a = 200, r = 0, g = 0, b = 0 },
			thumb_color = { a = 255, r = 169, g = 191, b = 153 },
			material = "content/ui/materials/scrollbars/scrollbar_frame_default",
			thumb_material = "content/ui/materials/scrollbars/scrollbar_thumb_default",
		},
		rows = {
			dx = -11, dy = -23, top_offset = 130, bottom_pad = 96, height = 29,
			inset = 92, layer = 53, indent = 22, value_pad = 0,
		},
		tree = {
			marker_w = 20, scale = 65, open_angle = 90, closed_angle = 0,
			open = "v", closed = ">",
			material = "content/ui/materials/buttons/triangle",
			color = copy_color(TERMINAL_PRIMARY),
			hover_color = { a = 255, r = 255, g = 242, b = 230 },
		},
		card = {
			enabled = 1, icon = 1, x = -246, y = 10, layer = 0,
			icon_size = 38, gap = 0, font_size = 22, text_w = 70,
			font_type = "proxima_nova_bold",
			color = copy_color(TERMINAL_PRIMARY),
			icon_color = copy_color(TERMINAL_PRIMARY),
			material = "content/ui/materials/hud/interactions/icons/enemy_priority",
		},
		lobby = {
			enabled = 1, icon = 1, x = -12, y = 30, layer = 0,
			icon_size = 21, gap = 4, font_size = 18, text_w = 66,
			font_type = "proxima_nova_bold",
			color = copy_color(TERMINAL_PRIMARY),
			icon_color = copy_color(TERMINAL_PRIMARY),
			material = "content/ui/materials/hud/interactions/icons/enemy_priority",
		},
		detail = {
			enabled = 1, x = 266, y = 181, w = 397, h = 0, layer = 0,
			font_size = 16, icon_size = 32, gap = -2, icon_dx = -2, icon_dy = -2,
			font_type = "proxima_nova_bold",
			color = { a = 255, r = 208, g = 241, b = 207 },
			icon_color = { a = 255, r = 174, g = 180, b = 174 },
			material = "content/ui/materials/hud/interactions/icons/enemy_priority",
		},
		levels = levels,
		ranks = ranks,
		reset = { x = 760, y = 989, w = 360, h = 70, layer = 55 },
		extras = {},
	}
end

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

mod._PREVIEW_ZOOM_MIN = -3
mod._PREVIEW_ZOOM_MAX = 1

local function pct(v, lo, hi)
	return clamp((tonumber(v) or 0) / 100, lo, hi)
end

local _geom_cache, _geom_rev = nil, -1

local function build_geom()
	local L = mod._layout or mod._layout_defaults
	local p = L.panel
	local top    = p.y - p.h * 0.5
	local bottom = p.y + p.h * 0.5

	local title_h  = clamp(L.title.h, 8, p.h)
	local title_to = clamp(L.title.top_offset, 0, p.h - title_h)
	local row_h    = clamp(L.rows.height, 8, p.h)
	local row_to   = clamp(L.rows.top_offset, row_h * 0.5, p.h - row_h * 0.5)

	local head_h = math.max(L.header.h, 0)
	local foot_h = math.max(L.footer.h, 0)

	local function dx(t) return (t and t.dx) or 0 end
	local function dy(t) return (t and t.dy) or 0 end

	local function band_from_top(cfg)
		local h = clamp(cfg.h, 2, p.h)
		local to = clamp(cfg.top_offset, 0, p.h - h)
		return {
			x = p.x + dx(cfg),
			y = top + to + h * 0.5 + dy(cfg),
			w = clamp(p.w - cfg.inset, 8, p.w), h = h,
		}
	end

	local function band_from_bottom(cfg)
		local h = clamp(cfg.h, 2, p.h)
		local bo = clamp(cfg.bottom_offset, 0, p.h - h)
		return {
			x = p.x + dx(cfg),
			y = bottom - bo - h * 0.5 + dy(cfg),
			w = clamp(p.w - cfg.inset, 8, p.w), h = h,
		}
	end

	local pv = L.preview or mod._layout_defaults.preview
	local zmin, zmax = mod._PREVIEW_ZOOM_MIN, mod._PREVIEW_ZOOM_MAX

	local levels = {}
	for i, lv in pairs(L.levels or {}) do
		levels[i] = {
			font_size   = clamp(lv.font_size or 20, 6, 120),
			height      = clamp(lv.height or L.rows.height, 4, 200),
			indent      = clamp(lv.indent or L.rows.indent, 0, 400),
			label_color = lv.label_color,
			value_color = lv.value_color,
		}
	end

	local rows_base   = clamp(top + row_to + dy(L.rows),
	                          top + row_h * 0.5, bottom - row_h * 0.5)
	local rows_top    = rows_base - row_h * 0.5
	local rows_bottom = bottom - row_h * 0.5 - L.rows.bottom_pad

	local sb = L.scrollbar
	local sb_top    = rows_top + sb.top_pad
	local sb_bottom = rows_bottom - sb.bottom_pad
	if sb_bottom < sb_top + 8 then sb_bottom = sb_top + 8 end

	local head = {
		x = p.x + dx(L.header),
		y = top + head_h * 0.5 - L.header.rise + dy(L.header),
		w = math.max(p.w - L.header.inset, 8), h = head_h,
	}
	local foot = {
		x = p.x + dx(L.footer),
		y = bottom - foot_h * 0.5 + L.footer.drop + dy(L.footer),
		w = math.max(p.w - L.footer.inset, 8), h = foot_h,
	}

	return {
		panel   = { x = p.x, y = p.y, w = p.w, h = p.h },
		frame   = { x = p.x, y = p.y, w = p.w, h = p.h },
		preview = {
			on     = (pv.enabled or 0) ~= 0,
			layer  = clamp(pv.layer or 10, 0, 90),
			rotate = (pv.rotate or 0) ~= 0,
			vx     = pct(pv.vx, -1, 2),
			vy     = pct(pv.vy, -1, 2),
			vw     = pct(pv.vw, 0.05, 3),
			vh     = pct(pv.vh, 0.05, 3),
			wx     = pct(pv.wx, -2, 2),
			wy     = pct(pv.wy, -2, 2),
			zoom   = zmin + (zmax - zmin) * pct(pv.zoom, -3, 3),
		},
		body    = {
			x = p.x + dx(L.body), y = p.y + dy(L.body),
			w = math.max(p.w + (L.body.w_add or 0), 8),
			h = math.max(p.h + (L.body.h_add or 0), 8),
		},
		shadow  = {
			x = p.x, y = p.y,
			w = p.w + L.shadow.expand * 2, h = p.h + L.shadow.expand * 2,
		},
		header  = head,
		footer  = foot,
		header_candles = {
			x = head.x, y = head.y + (L.header.candles_dy or 0),
			w = math.max(p.w - (L.header.candles_inset or 0), 8),
			h = math.max(L.header.candles_h or head.h, 0),
		},
		footer_candles = {
			x = foot.x, y = foot.y + (L.footer.candles_dy or 0),
			w = math.max(p.w - (L.footer.candles_inset or 0), 8),
			h = math.max(L.footer.candles_h or foot.h, 0),
		},
		section = {
			font_size  = clamp(L.section.font_size, 8, 120),
			font_type  = L.section.font_type,
			color      = L.section.color,
			layer      = L.section.layer,
			gap_before = clamp(L.section.gap_before, 0, 10),
			gap_after  = clamp(L.section.gap_after, 0, 10),
		},
		divider_top    = band_from_top(L.divider_top),
		divider_title  = band_from_top(L.divider_title),
		divider_bottom = band_from_bottom(L.divider_bottom),
		title_plate    = band_from_top(L.title_plate),
		title = {
			x = p.x + dx(L.title),
			y = clamp(top + title_to + title_h * 0.5 + dy(L.title),
			          top + title_h * 0.5, bottom - title_h * 0.5),
			w = clamp(p.w - L.title.inset, 8, p.w), h = title_h,
		},
		scrollbar = {
			on          = (sb.enabled or 0) ~= 0,
			w           = clamp(sb.w, 1, p.w),
			x           = p.x + p.w * 0.5 - sb.inset,
			top         = sb_top,
			bottom      = sb_bottom,
			h           = sb_bottom - sb_top,
			y           = (sb_top + sb_bottom) * 0.5,
			min_thumb   = clamp(sb.min_thumb, 8, math.max(sb_bottom - sb_top, 8)),
			layer       = clamp(sb.layer, 0, 90),
			hold        = math.max(sb.hold, 0) / 100,
			fade        = math.max(sb.fade, 1) / 100,
			color       = sb.color,
			track_color = sb.track_color,
			thumb_color = sb.thumb_color,
		},
		tree = {
			marker_w     = clamp((L.tree and L.tree.marker_w) or 0, 0, 200),
			scale        = clamp((L.tree and L.tree.scale) or 65, 5, 300) / 100,
			open_angle   = ((L.tree and L.tree.open_angle) or 0) * math.pi / 180,
			closed_angle = ((L.tree and L.tree.closed_angle) or 0) * math.pi / 180,
			open         = (L.tree and L.tree.open) or "",
			closed       = (L.tree and L.tree.closed) or "",
			material     = (L.tree and L.tree.material) or "",
			color        = (L.tree and L.tree.color) or L.section.color,
			hover_color  = (L.tree and L.tree.hover_color) or L.section.color,
		},
		card = {
			on         = ((L.card and L.card.enabled) or 0) ~= 0,
			icon_on    = ((L.card and L.card.icon) or 0) ~= 0,
			x          = (L.card and L.card.x) or 0,
			y          = (L.card and L.card.y) or 0,
			icon_size  = clamp((L.card and L.card.icon_size) or 22, 0, 200),
			gap        = clamp((L.card and L.card.gap) or 4, 0, 100),
			text_w     = clamp((L.card and L.card.text_w) or 34, 0, 400),
			font_size  = clamp((L.card and L.card.font_size) or 20, 6, 120),
			font_type  = (L.card and L.card.font_type) or "proxima_nova_bold",
			layer      = clamp((L.card and L.card.layer) or 12, 0, 90),
			color      = (L.card and L.card.color) or L.section.color,
			icon_color = (L.card and L.card.icon_color) or L.section.color,
			material   = (L.card and L.card.material) or "",
		},
		lobby = {
			on         = ((L.lobby and L.lobby.enabled) or 0) ~= 0,
			icon_on    = ((L.lobby and L.lobby.icon) or 0) ~= 0,
			x          = (L.lobby and L.lobby.x) or 0,
			y          = (L.lobby and L.lobby.y) or 0,
			icon_size  = clamp((L.lobby and L.lobby.icon_size) or 14, 0, 200),
			gap        = clamp((L.lobby and L.lobby.gap) or 1, 0, 100),
			text_w     = clamp((L.lobby and L.lobby.text_w) or 26, 0, 400),
			font_size  = clamp((L.lobby and L.lobby.font_size) or 14, 6, 120),
			font_type  = (L.lobby and L.lobby.font_type) or "proxima_nova_bold",
			layer      = clamp((L.lobby and L.lobby.layer) or 30, 0, 90),
			color      = (L.lobby and L.lobby.color) or L.section.color,
			icon_color = (L.lobby and L.lobby.icon_color) or L.section.color,
			material   = (L.lobby and L.lobby.material) or "",
		},
		detail = {
			on         = ((L.detail and L.detail.enabled) or 0) ~= 0,
			x          = (L.detail and L.detail.x) or 0,
			y          = (L.detail and L.detail.y) or 0,
			w          = clamp((L.detail and L.detail.w) or 360, 20, 1200),
			h          = clamp((L.detail and L.detail.h) or 60, 12, 400),
			font_size  = clamp((L.detail and L.detail.font_size) or 20, 6, 120),
			icon_size  = clamp((L.detail and L.detail.icon_size) or 26, 0, 200),
			gap        = clamp((L.detail and L.detail.gap) or 0, -400, 400),
			icon_dx    = (L.detail and L.detail.icon_dx) or 0,
			icon_dy    = (L.detail and L.detail.icon_dy) or 0,
			font_type  = (L.detail and L.detail.font_type) or "proxima_nova_bold",
			layer      = clamp((L.detail and L.detail.layer) or 12, 0, 90),
			color      = (L.detail and L.detail.color) or L.section.color,
			icon_color = (L.detail and L.detail.icon_color) or L.section.color,
			material   = (L.detail and L.detail.material) or "",
		},
		levels = levels,
		rows = {
			base_y  = rows_base,
			height  = row_h,
			avail   = clamp(p.w - L.rows.inset, 40, p.w),
			centre  = p.x + dx(L.rows),
			top     = rows_top,
			bottom  = rows_bottom,
			indent  = L.rows.indent,
			value_pad = L.rows.value_pad,
			layer   = L.rows.layer,
		},
	}
end

function mod._layout_invalidate()
	_geom_cache = nil
end

function mod._layout_geom()
	local rev = mod._layout_revision or 0
	if _geom_cache == nil or _geom_rev ~= rev then
		_geom_cache = build_geom()
		_geom_rev = rev
	end
	return _geom_cache
end

function mod._level_cfg(G, depth)
	local levels = G.levels
	return levels[depth] or levels[0]
end

function mod._row_height(G, row)
	if not row or row.spacer or row.section then return G.rows.height end
	return mod._level_cfg(G, row.depth or 0).height
end

function mod._rows_content_height(G, rows)
	local total = 0
	for i = 1, #rows do
		total = total + mod._row_height(G, rows[i])
	end
	return total
end

local function merge(dst, src)
	if type(src) ~= "table" then return dst end
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			merge(dst[k], v)
		else
			dst[k] = v
		end
	end
	return dst
end

local function serialize(value, indent)
	indent = indent or "\t"
	local t = type(value)
	if t == "number" then
		if value == math.floor(value) then return string.format("%d", value) end
		return string.format("%.4f", value)
	elseif t == "string" then
		return string.format("%q", value)
	elseif t == "boolean" then
		return tostring(value)
	elseif t ~= "table" then
		return "nil"
	end

	local keys, arr = {}, {}
	for k in pairs(value) do
		if type(k) == "number" then arr[#arr + 1] = k else keys[#keys + 1] = k end
	end
	table.sort(keys)
	table.sort(arr)

	local out = { "{\n" }
	for _, k in ipairs(arr) do
		if k == math.floor(k) then
			out[#out + 1] = indent .. "\t[" .. string.format("%d", k) .. "] = "
				.. serialize(value[k], indent .. "\t") .. ",\n"
		end
	end
	for _, k in ipairs(keys) do
		out[#out + 1] = indent .. "\t" .. k .. " = "
			.. serialize(value[k], indent .. "\t") .. ",\n"
	end
	out[#out + 1] = indent .. "}"
	return table.concat(out)
end

mod._layout_serialize = serialize

local function layout_path()
	if not mod._APPDATA_DIR then return nil end
	return mod._APPDATA_DIR .. "wkc_layout.lua"
end

local function read_raw()
	local path = layout_path()
	if not (lua_io and path) then return nil end
	local ok, content = pcall(function()
		local f = lua_io.open(path, "r")
		if not f then return nil end
		local s = f:read("*a")
		f:close()
		return s
	end)
	return ok and content or nil
end

function mod._layout_write(tbl)
	local path = layout_path()
	if not (lua_io and path) then return false end
	local ok = pcall(function()
		local f = lua_io.open(path, "w")
		if not f then return end
		f:write("return " .. serialize(tbl, "") .. "\n")
		f:close()
	end)
	return ok and true or false
end

local function parse(raw)
	if not (raw and raw ~= "" and lua_loadstring) then return nil end
	local ok, result = pcall(function()
		local chunk = lua_loadstring(raw)
		if not chunk then return nil end
		local data = chunk()
		return type(data) == "table" and data or nil
	end)
	return ok and result or nil
end

mod._layout_defaults = build_defaults()
mod._layout = build_defaults()

mod._layout_seen_raw = nil
mod._layout_next_poll = 0
mod._layout_revision = 0

local function adopt(raw)
	local parsed = parse(raw)
	if not parsed then return false end
	local merged = build_defaults()
	if (parsed.version or 0) >= merged.version then
		merge(merged, parsed)
	end
	mod._layout = merged
	mod._layout_revision = mod._layout_revision + 1
	mod._layout_invalidate()
	return true
end

do
	local raw = read_raw()
	if raw then
		mod._layout_seen_raw = raw
		adopt(raw)
	elseif mod._DEV_DEBUG then
		mod._layout_write(mod._layout_defaults)
		mod._layout_seen_raw = read_raw()
	end
end

function mod._layout_poll(dt)
	if not mod._DEV_DEBUG then return false end
	mod._layout_next_poll = mod._layout_next_poll - (dt or 0)
	if mod._layout_next_poll > 0 then return false end
	mod._layout_next_poll = POLL_INTERVAL

	local raw = read_raw()
	if not raw or raw == mod._layout_seen_raw then return false end
	mod._layout_seen_raw = raw
	return adopt(raw)
end

function mod._layout_extras_used()
	local extras = mod._layout and mod._layout.extras or {}
	local used = 0
	for i = 1, mod._LAYOUT_EXTRA_SLOTS do
		local e = extras[i]
		if e and type(e.material) == "string" and e.material ~= "" then
			used = used + 1
		end
	end
	return used, mod._LAYOUT_EXTRA_SLOTS
end

function mod._layout_assign_material(path)
	if type(path) ~= "string" or path == "" then return nil, "no material" end
	if not mod._material_ok(path) then
		return nil, "material is not loaded - cannot be drawn"
	end

	local L = mod._layout
	L.extras = L.extras or {}

	for i = 1, mod._LAYOUT_EXTRA_SLOTS do
		local e = L.extras[i]
		if e and e.material == path then
			return nil, "already in slot " .. i
		end
	end

	local slot
	for i = 1, mod._LAYOUT_EXTRA_SLOTS do
		local e = L.extras[i]
		if not e or type(e.material) ~= "string" or e.material == "" then
			slot = i
			break
		end
	end
	if not slot then
		return nil, "all " .. mod._LAYOUT_EXTRA_SLOTS .. " slots are full"
	end

	L.extras[slot] = {
		material = path,
		x = 0, y = 0, w = 120, h = 120, layer = 54,
		color = { a = 255, r = 255, g = 255, b = 255 },
	}

	mod._layout_write(L)
	mod._layout_seen_raw = nil
	mod._layout_revision = mod._layout_revision + 1
	mod._layout_invalidate()
	return slot
end
