

---@type mod
local mod = get_mod("dopamine")

if mod.mission_summary_presentation then
	return mod.mission_summary_presentation
end

local C = mod:core(mod.mission_summary_constants, "hud/mission_summary/constants")
local EventRegistry = mod:core(mod.event_registry, "utils/event/registry")

local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min

---@param v number
---@return number
local function clamp01(v)
	if v < 0 then
		return 0
	elseif v > 1 then
		return 1
	end
	return v
end

---@class MissionSummaryPresentation
local Presentation = {}

local SUMMARY_EXCLUDED = {
	kill = true,
}

---@param event_id EventID
---@return boolean
local function is_summary_event(event_id)
	return not SUMMARY_EXCLUDED[event_id] and EventRegistry.by_id(event_id) ~= nil
end

---@param event_id EventID
---@return string
function Presentation.event_label(event_id)
	local definition = EventRegistry.by_id(event_id)
	if not definition then
		return mod.dl.str.machine_to_human_text(event_id)
	end
	if definition.label then
		return definition.label
	end
	return definition.label_key and mod:localize(definition.label_key) or event_id
end

---@param raw table<EventID, integer>|nil
---@return table<string, integer>
function Presentation.event_counts_for_save(raw)
	local out = {}
	if not raw then
		return out
	end
	for event_id, count in pairs(raw) do
		if count > 0 and is_summary_event(event_id) then
			out[event_id] = count
		end
	end
	return out
end

---@param row { id: string, label: string|nil, label_key: string|nil }
---@return string
function Presentation.row_label(row)
	if row.label then
		return row.label
	end
	if row.label_key then
		return mod:localize(row.label_key)
	end
	return Presentation.event_label(row.id)
end

---@param seconds number|nil
---@return string
function Presentation.format_time(seconds)
	return mod.dl.str.format_timer(seconds)
end

---@param value number|nil
---@return string
function Presentation.format_stat(value)
	return mod.dl.str.format_number(value or 0)
end

---@param value number|nil
---@return string
function Presentation.format_compact(value)
	return mod.dl.str.format_compact(value or 0)
end

---@param damage number|nil
---@param pool number|nil
---@return string
function Presentation.format_magnitude(damage, pool)
	local dmg = Presentation.format_compact(damage)
	if not pool then
		return dmg
	end
	local suffix = mod.dl.str.rich_text("/" .. Presentation.format_compact(pool), {
		color = C.COLOR.MUTED,
		size = C.FONT_SIZE.magnitude_pool,
	})
	return dmg .. suffix
end

---@param timestamp number|nil  unix seconds
---@return string
function Presentation.format_date(timestamp)
	return mod.dl.str.format_time_ago(timestamp, false)
end

---@param timestamp number|nil  unix seconds
---@return string
function Presentation.format_date_short(timestamp)
	return mod.dl.str.format_time_ago(timestamp, true)
end

---@param value number|nil
---@return string
function Presentation.format_points(value)
	value = value or 0
	local sign = ""
	if value < 0 then
		sign = "-"
		value = -value
	end

	local scaled, suffix
	if value >= 1000000 then
		scaled, suffix = value / 1000000, "m"
	elseif value >= 1000 then
		scaled, suffix = value / 1000, "k"
	else
		return sign .. tostring(math_floor(value + 0.5))
	end

	local decimals = (scaled >= 10 and 1) or 2
	local str = string.format("%." .. decimals .. "f", scaled)
	return sign .. str .. suffix
end

---@param v any
---@return boolean
local function flag_set(v)
	return v ~= nil and v ~= false and v ~= 0
end

---@param run { difficulty_name: string|nil, is_auric: any, is_maelstrom: any, is_havoc: any, havoc_rank: number|nil }|nil
---@return string
function Presentation.difficulty_display(run)
	if not run then
		return ""
	end
	if flag_set(run.is_havoc) then
		local rank = run.havoc_rank
		return (rank and rank > 0) and ("Havoc " .. tostring(math_floor(rank))) or "Havoc"
	end
	local name = flag_set(run.is_auric) and "Auric" or (run.difficulty_name or "")
	if flag_set(run.is_maelstrom) then
		name = "[MS] " .. name
	end
	return name
end

---@param run { difficulty: number|nil, is_auric: any, is_havoc: any, havoc_rank: number|nil }|nil
---@return string|nil key
function Presentation.difficulty_rank_key(run)
	if not run then
		return nil
	end
	if flag_set(run.is_havoc) then
		local r = math_floor(run.havoc_rank or 0)
		if r < 10 then
			return "havoc_0_10"
		elseif r < 20 then
			return "havoc_10_20"
		elseif r < 30 then
			return "havoc_20_30"
		elseif r < 35 then
			return "havoc_30_35"
		else
			return "havoc_35_40"
		end
	end
	if flag_set(run.is_auric) then
		return "auric_damnation"
	end
	local d = run.difficulty or 0
	if d <= 1 then
		return "uprising"
	elseif d == 2 then
		return "malice"
	elseif d == 3 then
		return "heresy"
	else
		return "damnation"
	end
end

---@param sp number
---@param key string|nil  optional RANK_THRESHOLDS_BY_DIFFICULTY key
---@return string letter, argb_table color
function Presentation.rank_for_sp(sp, key)
	sp = sp or 0

	local rounding = C.STYLE_RANK_SP_ROUNDING
	local step = (key and rounding[key]) or rounding.default
	if step and step > 0 then
		sp = math_ceil(sp / step) * step
	end
	local thresholds = (key and C.RANK_THRESHOLDS_BY_DIFFICULTY[key]) or C.RANK_THRESHOLDS
	for i = 1, #thresholds do
		if sp >= thresholds[i].min then
			return thresholds[i].letter, thresholds[i].color
		end
	end
	local last = thresholds[#thresholds]
	return last.letter, last.color
end

---@class MissionLevel
---@field label string          -- current level, with prestige suffix (e.g. "X2")
---@field letter string         -- base rank letter (e.g. "X")
---@field color argb_table
---@field next_label string      -- the next level's label
---@field progress number        -- 0..1 progress toward the next level
---@field points number          -- the cumulative SP this level was computed from
---@field current_min number
---@field next_min number

---@param sp number|nil
---@return MissionLevel
function Presentation.level_for_sp(sp)
	sp = math_max(0, sp or 0)
	local thresholds = C.LEVEL_THRESHOLDS
	local top = thresholds[#thresholds]
	local step = C.LEVEL_PRESTIGE_STEP

	if sp >= top.min then
		local prestige = math_floor((sp - top.min) / step) 
		local current_min = top.min + prestige * step
		local label = top.letter
		if prestige >= 1 then
			label = top.letter .. tostring(prestige + 1)
		end
		return {
			label = label,
			letter = top.letter,
			color = top.color,
			next_label = top.letter .. tostring(prestige + 2),
			progress = (sp - current_min) / step,
			points = sp,
			current_min = current_min,
			next_min = current_min + step,
		}
	end

	for i = #thresholds, 1, -1 do
		if sp >= thresholds[i].min then
			local cur = thresholds[i]
			local nxt = thresholds[i + 1]
			return {
				label = cur.letter,
				letter = cur.letter,
				color = cur.color,
				next_label = nxt and nxt.letter or cur.letter,
				progress = nxt and (sp - cur.min) / (nxt.min - cur.min) or 1,
				points = sp,
				current_min = cur.min,
				next_min = nxt and nxt.min or cur.min,
			}
		end
	end

	local d = thresholds[1]
	return {
		label = d.letter,
		letter = d.letter,
		color = d.color,
		next_label = d.letter,
		progress = 0,
		points = sp,
		current_min = 0,
		next_min = 0,
	}
end

---@param thresholds { min: number, letter: string, color: argb_table }[]
---@param value number
---@return string letter, argb_table color
local function rank_from(thresholds, value)
	for i = 1, #thresholds do
		if value >= thresholds[i].min then
			return thresholds[i].letter, thresholds[i].color
		end
	end
	local last = thresholds[#thresholds]
	return last.letter, last.color
end

---@class FactorRank
---@field score number|nil
---@field letter string
---@field color argb_table
---@field amount number|nil
---@field rank_key string|nil   -- STYLE only: the per-difficulty ladder key used to grade its SP

---@param ladder table[]        list of tiers, each with [cmp_field] and `points`
---@param value number
---@param cmp_field string
---@return number
local function tier_points(ladder, value, cmp_field)
	for i = 1, #ladder do
		if value >= ladder[i][cmp_field] then
			return ladder[i].points
		end
	end
	return 0
end

---@param v table  a stat values table
---@return FactorRank
function Presentation.violence(v)
	local cfg = C.VIOLENCE_CATEGORY_POINTS
	local cats = {
		{ dmg = v.regular_damage, hp = v.regular_health, ladder = cfg.regular },
		{ dmg = v.elite_damage, hp = v.elite_health, ladder = cfg.elite },
		{ dmg = v.special_damage, hp = v.special_health, ladder = cfg.special },
		{ dmg = v.boss_damage, hp = v.boss_max_health, ladder = cfg.boss },
	}
	local total = 0
	for i = 1, #cats do
		local c = cats[i]
		local ladder = c.ladder
		if ladder and ladder[1] then
			if (c.hp or 0) > 0 then
				local pct = clamp01((c.dmg or 0) / c.hp) * 100
				total = total + tier_points(ladder, pct, "pct")
			else

				total = total + ladder[1].points
			end
		end
	end
	local letter, color = rank_from(C.VIOLENCE_POINT_THRESHOLDS, total)
	return { score = total, letter = letter, color = color }
end

---@param v table
---@return FactorRank
function Presentation.unity(v)
	local time = v.time or 0
	local coherency_pct = time > 0 and clamp01((v.coherency_time or 0) / time) * 100 or 0
	local coherency_points = tier_points(C.UNITY_COHERENCY_POINTS, coherency_pct, "pct")
	local objective_points = tier_points(C.UNITY_OBJECTIVE_POINTS, v.objectives or 0, "count")
	local stim_points = math_min((v.stims or 0) * C.UNITY_STIM_POINTS, C.UNITY_STIM_POINTS_MAX)
	local rescue_points = math_min((v.rescues or 0) * C.UNITY_RESCUE_POINTS, C.UNITY_RESCUE_POINTS_MAX)
	local total = coherency_points + objective_points + stim_points + rescue_points
	local letter, color = rank_from(C.UNITY_POINT_THRESHOLDS, total)
	return { score = total, letter = letter, color = color }
end

---@param v table
---@return FactorRank
function Presentation.finesse(v)

	local pools = math_max(0, (v.health_lost or 0) - (v.downs or 0) * C.FINESSE_DOWN_HEALTH_POOLS)
	local damage_penalty = 0
	local ladder = C.FINESSE_DAMAGE_PENALTY
	for i = 1, #ladder do
		if pools >= ladder[i].pools then
			damage_penalty = ladder[i].penalty
			break
		end
	end
	damage_penalty = math_min(damage_penalty, C.FINESSE_DAMAGE_PENALTY_MAX)
	local points = math_max(0, C.FINESSE_MAX_POINTS - damage_penalty - (v.downs or 0) * C.FINESSE_DOWN_PENALTY)
	local letter, color = rank_from(C.FINESSE_POINT_THRESHOLDS, points)
	return { score = points, letter = letter, color = color }
end

---@param v table
---@return FactorRank
function Presentation.style_factor(v)
	local points = v.style_points or 0
	local key = Presentation.difficulty_rank_key(v)
	local letter, color = Presentation.rank_for_sp(points, key)

	return { score = nil, letter = letter, color = color, amount = points, rank_key = key }
end

---@param factors { violence: FactorRank, unity: FactorRank, finesse: FactorRank, style: FactorRank }
---@return number
function Presentation.composite_score(factors)
	local perf = C.PERF_PT_BY_TIER
	local fw = C.FACTOR_POINT_WEIGHT
	local weighted = (perf[factors.violence.letter] or 0) * fw.violence
		+ (perf[factors.unity.letter] or 0) * fw.unity
		+ (perf[factors.finesse.letter] or 0) * fw.finesse
		+ (perf[factors.style.letter] or 0) * fw.style
	local total_weight = fw.violence + fw.unity + fw.finesse + fw.style
	return total_weight > 0 and (weighted / total_weight) or 0
end

---@param factors { violence: FactorRank, unity: FactorRank, finesse: FactorRank, style: FactorRank }
---@return string letter, argb_table color
function Presentation.composite_rank(factors)
	return rank_from(C.COMPOSITE_THRESHOLDS, Presentation.composite_score(factors))
end

---@param category "violence"|"unity"|"finesse"|"style"
---@param factor FactorRank  the settled factor rank (final score / amount)
---@param p number           eased 0..1
---@return string letter, argb_table color, number|nil amount
function Presentation.category_rank_at(category, factor, p)
	if category == "style" then
		local amount = (factor.amount or 0) * p
		local letter, color = Presentation.rank_for_sp(amount, factor.rank_key)
		return letter, color, amount
	end
	if category == "finesse" then

		local final_points = factor.score or 0
		local points = C.FINESSE_MAX_POINTS - (C.FINESSE_MAX_POINTS - final_points) * p
		local letter, color = rank_from(C.FINESSE_POINT_THRESHOLDS, points)
		return letter, color, nil
	end
	local score = (factor.score or 0) * p
	local ladder = (category == "violence") and C.VIOLENCE_POINT_THRESHOLDS or C.UNITY_POINT_THRESHOLDS
	local letter, color = rank_from(ladder, score)
	return letter, color, nil
end

---@class MissionFactors
---@field violence FactorRank
---@field unity FactorRank
---@field finesse FactorRank
---@field style FactorRank
---@field composite_letter string
---@field composite_color argb_table

---@param values table|nil
---@return MissionFactors|nil
function Presentation.factors(values)
	if not values then
		return nil
	end
	local f = {
		violence = Presentation.violence(values),
		unity = Presentation.unity(values),
		finesse = Presentation.finesse(values),
		style = Presentation.style_factor(values),
	}
	f.composite_letter, f.composite_color = Presentation.composite_rank(f)
	return f
end

---@class MissionSummaryGeometry
---@field content { x: number, y: number, w: number, h: number }
---@field header { x: number, y: number, w: number, h: number }
---@field body { x: number, y: number, w: number, h: number }
---@field highscores { x: number, y: number, w: number, h: number }
---@field run { x: number, y: number, w: number, h: number }
---@field big_stats { x: number, y: number, w: number, h: number }
---@field rank_box { x: number, y: number, w: number, h: number }
---@field delete_run { x: number, y: number, w: number, h: number }
---@field victims { x: number, y: number, w: number, h: number }
---@field magnitude { x: number, y: number, w: number, h: number }
---@field method { x: number, y: number, w: number, h: number }
---@field style { x: number, y: number, w: number, h: number }
---@field competence { x: number, y: number, w: number, h: number }
---@field team { x: number, y: number, w: number, h: number }
---@field mission_grid { x: number, y: number, w: number, h: number }
---@field live_button { x: number, y: number, w: number, h: number }
---@field hell_yeah { x: number, y: number, w: number, h: number }
---@field mission_tile_w number
local function build_geometry()
	local content_x = C.CONTENT_PAD_X
	local content_y = C.CONTENT_TOP
	local content_w = C.PANEL_WIDTH - C.CONTENT_PAD_X * 2
	local content_h = C.PANEL_HEIGHT - C.CONTENT_TOP - C.CONTENT_BOTTOM

	local header = { x = content_x, y = content_y, w = content_w, h = C.HEADER_H }

	local grid_h = C.MISSION_GRID_TITLE_H
		+ C.MISSION_GRID_TITLE_GAP
		+ C.MISSION_GRID_ROWS * C.MISSION_TILE_H
		+ (C.MISSION_GRID_ROWS - 1) * C.MISSION_TILE_GAP_Y
	local grid_y = content_y + content_h - grid_h
	local tile_w = (content_w - (C.MISSION_GRID_COLS - 1) * C.MISSION_TILE_GAP_X) / C.MISSION_GRID_COLS

	local body_y = content_y + C.HEADER_H + C.HEADER_GAP
	local body_h = (grid_y - C.GRID_GAP) - body_y

	local hs_w = content_w * C.HIGHSCORES_FRAC
	local stats_x = content_x + hs_w + C.BODY_GAP
	local stats_w = content_w - hs_w - C.BODY_GAP

	local top_h = (body_h - C.STATS_ROW_GAP) * C.STATS_TOP_FRAC
	local bottom_h = (body_h - C.STATS_ROW_GAP) - top_h
	local bottom_y = body_y + top_h + C.STATS_ROW_GAP

	local col_w = (stats_w - C.STATS_BOTTOM_GAP * 2) / 3
	local col2_x = stats_x + col_w + C.STATS_BOTTOM_GAP
	local col3_x = stats_x + (col_w + C.STATS_BOTTOM_GAP) * 2

	local big_stats_h = (#C.BIG_ROWS - 1) * C.BIG_ROW_H + C.RANK_BOX_BOTTOM_LINE - 12

	local style_content_h = C.HEADING_H + #C.STYLE_EVENTS * C.EVENT_ROW_H
	local competence_y = bottom_y + style_content_h + C.COL3_BLOCK_GAP
	local competence_content_h = C.HEADING_H + #C.COMPETENCE_EVENTS * C.EVENT_ROW_H
	local competence = { x = col3_x, y = competence_y, w = col_w, h = competence_content_h }
	local team = {
		x = col3_x,
		y = competence_y + competence_content_h + C.COL3_BLOCK_GAP,
		w = col_w,
		h = C.HEADING_H + #C.TEAM_EVENTS * C.EVENT_ROW_H,
	}

	local magnitude_h = C.HEADING_H + #C.MAGNITUDE_ROWS * C.MAGNITUDE_ROW_H
	local method_y = bottom_y + magnitude_h + C.MAGNITUDE_METHOD_GAP + 8

	return {
		content = { x = content_x, y = content_y, w = content_w, h = content_h },
		header = header,
		body = { x = content_x, y = body_y, w = content_w, h = body_h },
		highscores = { x = content_x, y = body_y, w = hs_w, h = body_h },

		run = { x = stats_x, y = body_y, w = col_w, h = top_h },
		big_stats = { x = col2_x, y = body_y + C.HEADING_H - 6, w = col_w, h = top_h },
		rank_box = { x = col3_x, y = body_y + C.HEADING_H, w = col_w, h = big_stats_h },

		delete_run = { x = col3_x, y = body_y, w = col_w, h = C.HEADING_H },
		victims = { x = stats_x, y = bottom_y, w = col_w, h = bottom_h },
		magnitude = { x = col2_x, y = bottom_y, w = col_w, h = magnitude_h },
		method = { x = col2_x, y = method_y, w = col_w, h = bottom_h - magnitude_h - C.MAGNITUDE_METHOD_GAP },
		style = { x = col3_x, y = bottom_y, w = col_w, h = style_content_h },
		competence = competence,
		team = team,
		mission_grid = { x = content_x, y = grid_y, w = content_w, h = grid_h },
		live_button = {
			x = content_x,
			y = grid_y + C.MISSION_GRID_TITLE_H + C.MISSION_GRID_TITLE_GAP,
			w = content_w,
			h = C.LIVE_BUTTON_H,
		},

		hell_yeah = {
			x = content_x,
			y = grid_y + C.MISSION_GRID_TITLE_GAP + C.MISSION_GRID_TITLE_H,
			w = content_w,
			h = C.HELL_YEAH_BUTTON_H,
		},
		mission_tile_w = tile_w,
	}
end

local _geometry = build_geometry()

---@return MissionSummaryGeometry
function Presentation.geometry()
	return _geometry
end

---@param block_w number
---@param block_h number
---@param count integer
---@param i integer
---@param heading_h number|nil
---@param reserve_bottom number|nil
---@param fixed_row_h number|nil
---@return { x: number, y: number, w: number, h: number }, number row_h
function Presentation.block_row_local(block_w, block_h, count, i, heading_h, reserve_bottom, fixed_row_h)
	heading_h = heading_h or 0
	local row_h = fixed_row_h
	if not row_h then
		local avail = block_h - heading_h - (reserve_bottom or 0)
		row_h = avail / math_max(count, 1)
	end
	return { x = 0, y = heading_h + (i - 1) * row_h, w = block_w, h = row_h }, row_h
end

---@param i integer
---@return { x: number, y: number, w: number, h: number }
function Presentation.highscore_row_local(i)
	return (
		Presentation.block_row_local(
			_geometry.highscores.w,
			_geometry.highscores.h,
			C.HIGHSCORE_SLOTS,
			i,
			C.HEADING_H,
			nil,
			C.HIGHSCORE_ROW_H
		)
	)
end

---@param i integer
---@return { x: number, y: number, w: number, h: number }
function Presentation.highscore_row_panel(i)
	local r = Presentation.highscore_row_local(i)
	return { x = _geometry.highscores.x + r.x, y = _geometry.highscores.y + r.y, w = r.w, h = r.h }
end

---@param i integer
---@return { x: number, y: number, w: number, h: number }
function Presentation.mission_tile_local(i)
	local cols = C.MISSION_GRID_COLS
	local row = math_floor((i - 1) / cols)
	local col = (i - 1) % cols
	local x = col * (_geometry.mission_tile_w + C.MISSION_TILE_GAP_X)
	local y = C.MISSION_GRID_TITLE_H + C.MISSION_GRID_TITLE_GAP + row * (C.MISSION_TILE_H + C.MISSION_TILE_GAP_Y)
	return { x = x, y = y, w = _geometry.mission_tile_w, h = C.MISSION_TILE_H }
end

---@param i integer
---@return { x: number, y: number, w: number, h: number }
function Presentation.mission_tile_panel(i)
	local r = Presentation.mission_tile_local(i)
	return { x = _geometry.mission_grid.x + r.x, y = _geometry.mission_grid.y + r.y, w = r.w, h = r.h }
end

---@param idols_found integer
---@param skulls_found integer
---@return string
function Presentation.secrets_text(idols_found, skulls_found)
	local secrets = C.SECRETS
	local parts = {}

	for i = 1, secrets.idol_total do
		local color = i <= (idols_found or 0) and C.COLOR.IDOL_FOUND or C.COLOR.IDOL_MISSING
		parts[#parts + 1] = mod.dl.str.rich_text(secrets.idol_glyph, { color = color })
	end

	parts[#parts + 1] = "  "

	for i = 1, secrets.skull_total do
		local color = i <= (skulls_found or 0) and C.COLOR.SKULL_FOUND or C.COLOR.SKULL_MISSING
		parts[#parts + 1] = mod.dl.str.rich_text(secrets.skull_glyph, { color = color })
	end

	return table.concat(parts, " ")
end

---@param archetype string|nil
---@return string
function Presentation.class_icon(archetype)
	if archetype then
		local id = mod.dl.archetypes.resolve(archetype) or archetype
		local icon = C.CLASS_ICONS[id]
		if icon then
			return icon
		end
	end
	return mod.dl.icons.icons.profile_circle or ""
end

mod.mission_summary_presentation = Presentation

return mod.mission_summary_presentation
