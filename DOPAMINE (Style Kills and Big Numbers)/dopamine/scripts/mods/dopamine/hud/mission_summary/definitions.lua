

---@type mod
local mod = get_mod("dopamine")

local C = mod:core(mod.mission_summary_constants, "hud/mission_summary/constants")
local Presentation = mod:core(mod.mission_summary_presentation, "hud/mission_summary/presentation")

local build, make, passes, scene, _insert, screen = mod.dl.defs()
local text, rect, texture = passes.text, passes.rect, passes.texture

local g = Presentation.geometry()

---@param r { x: number, y: number, w: number, h: number }
local function at_block(r)
	return scene:child_of("panel"):align("top", "left"):at(r.x, r.y):sizes(r.w, r.h)
end

---@param width number
---@param label string
local function heading_passes(width, label)
	return {
		text:id("heading")
			:val(label)
			:font(C.FONTS.heading)
			:size(C.FONT_SIZE.heading)
			:at(0, 0)
			:sizes(width, C.HEADING_H)
			:align("center", "left")
			:color(C.COLOR.HEADING),
		rect:id("heading_rule")
			:at(0, C.HEADING_H - C.HEADING_RULE_H)
			:sizes(width, C.HEADING_RULE_H)
			:color(C.COLOR.RULE),
	}
end

local header_block = (function()
	local bar_y = (C.HEADER_H - C.PROGRESS_BAR_H) * 0.5
	return make(
		"header",
		at_block(g.header),
		text:id("mission_name")
			:val("")
			:font(C.FONTS.title)
			:size(C.FONT_SIZE.mission_name)
			:at(0, 0)
			:sizes(g.header.w, C.HEADER_H)
			:align("center", "left")
			:color(C.COLOR.TITLE),

		text:id("progress_points")
			:val("")
			:font(C.FONTS.value)
			:size(C.FONT_SIZE.level_points)
			:at(0, 0)
			:sizes(g.header.w, C.HEADER_H)
			:align("center", "left")
			:color(C.COLOR.VALUE),

		text:id("progress_rank")
			:val("")
			:font(C.FONTS.rank)
			:size(C.FONT_SIZE.level_label)
			:at(0, 0)
			:sizes(g.header.w, C.HEADER_H)
			:align("center", "left")
			:color(C.COLOR.WHITE),

		rect:id("progress_bar_bg")
			:at(0, bar_y)
			:sizes(C.PROGRESS_POINTS_W, C.PROGRESS_BAR_H)
			:color(C.COLOR.PROGRESS_BAR_BG),
		rect:id("progress_fill")
			:at(0, bar_y)
			:sizes(C.PROGRESS_POINTS_W, C.PROGRESS_BAR_H)
			:color(C.COLOR.PROGRESS_BAR_FILL),

		text:id("progress_next")
			:val("")
			:font(C.FONTS.rank)
			:size(C.FONT_SIZE.level_next)
			:at(0, 0)
			:sizes(g.header.w, C.HEADER_H)
			:align("center", "right")
			:color(C.COLOR.PROGRESS_NEXT),
		text:id("progress_points_next")
			:val("")
			:font(C.FONTS.value)
			:size(C.FONT_SIZE.level_points)
			:at(0, 0)
			:sizes(g.header.w, C.HEADER_H)
			:align("center", "right")
			:color(C.COLOR.VALUE)
	)
end)()

local highscores_block = make(
	"highscores",
	at_block(g.highscores),
	heading_passes(g.highscores.w, mod:localize(C.HEADINGS.highscores)),
	function()
		local out = {}
		for i = 1, C.HIGHSCORE_SLOTS do
			local rr = Presentation.highscore_row_local(i)
			rr.y = rr.y + C.HIGHSCORE_ROW_GAP * 2
			local line1_h = rr.h * 0.58
			out[#out + 1] =
				rect:id("hs_bg_" .. i):at(rr.x, rr.y):sizes(rr.w, rr.h - C.HIGHSCORE_ROW_GAP):color(C.COLOR.ROW_BG)
			out[#out + 1] = text:id("hs_icon_" .. i)
				:val("")
				:font(C.FONTS.icon)
				:size(C.FONT_SIZE.highscore_icon)
				:at(rr.x + 8, rr.y - 2)
				:sizes(C.HIGHSCORE_ICON_W, rr.h)
				:align("center", "center")
				:color(C.COLOR.ROW_TEXT)
			out[#out + 1] = text:id("hs_rank_" .. i)
				:val("")
				:font(C.FONTS.rank)
				:size(C.FONT_SIZE.highscore_rank)
				:at(rr.x + C.HIGHSCORE_ICON_W + 16, rr.y, 1)
				:sizes(rr.w * 0.5, line1_h)
				:align("center", "left")
				:color(C.COLOR.ROW_TEXT)
			out[#out + 1] = text:id("hs_points_" .. i)
				:val("")
				:font(C.FONTS.value_bold)
				:size(C.FONT_SIZE.highscore_points)
				:at(rr.x, rr.y)
				:sizes(rr.w - 10, line1_h)
				:align("center", "right")
				:color(C.COLOR.ROW_TEXT)
			out[#out + 1] = text:id("hs_diff_" .. i)
				:val("")
				:font(C.FONTS.label)
				:size(C.FONT_SIZE.highscore_difficulty)
				:at(rr.x + C.HIGHSCORE_ICON_W + 14, rr.y + rr.h * 0.475)
				:sizes(rr.w - C.HIGHSCORE_ICON_W - 18 - C.HIGHSCORE_DATE_W, rr.h * 0.4)
				:align("center", "left")
				:color(C.COLOR.ROW_DIFFICULTY)

			out[#out + 1] = text:id("hs_date_" .. i)
				:val("")
				:font(C.FONTS.label)
				:size(C.FONT_SIZE.highscore_difficulty)
				:at(rr.x, rr.y + rr.h * 0.5)
				:sizes(rr.w - 10, rr.h * 0.4)
				:align("center", "right")
				:color(C.COLOR.ROW_DIFFICULTY)

			out[#out + 1] = text:id("hs_dots_" .. i)
				:val("")
				:font(C.FONTS.heading)
				:size(C.FONT_SIZE.highscore_rank)
				:at(rr.x, rr.y)
				:sizes(rr.w, rr.h - C.HIGHSCORE_ROW_GAP)
				:align("center", "center")
				:color(C.COLOR.ROW_DIFFICULTY)
		end
		return out
	end
)

local run_block = make("run", at_block(g.run), heading_passes(g.run.w, mod:localize(C.HEADINGS.run)), function()
	local out = {}
	for i = 1, #C.RUN_ROWS do
		local row = C.RUN_ROWS[i]
		local rr = Presentation.block_row_local(g.run.w, g.run.h, #C.RUN_ROWS, i, C.HEADING_H, nil, C.STATS_ROW_H)
		local label = mod:localize(row.label_key)
		if row.icon then
			label = row.icon .. " " .. label
		end
		out[#out + 1] = text:id("run_l_" .. row.id)
			:val(label)
			:font(C.FONTS.label)
			:size(C.FONT_SIZE.run_label)
			:at(rr.x, rr.y)
			:sizes(rr.w, rr.h)
			:align("center", "left")
			:color(C.COLOR.LABEL)
		out[#out + 1] = text:id("run_v_" .. row.id)
			:val("")
			:font(C.FONTS.value)
			:size(C.FONT_SIZE.run_value)
			:at(rr.x, rr.y)
			:sizes(rr.w, rr.h)
			:align("center", "right")
			:color(C.COLOR.VALUE)
	end
	return out
end)

local big_stats_block = make("big_stats", at_block(g.big_stats), function()
	local out = {}
	for i = 1, #C.BIG_ROWS do
		local row = C.BIG_ROWS[i]
		local rr = Presentation.block_row_local(g.big_stats.w, g.big_stats.h, #C.BIG_ROWS, i, 0, nil, C.BIG_ROW_H)
		out[#out + 1] = text:id("big_l_" .. row.id)
			:val(mod:localize(row.label_key))
			:font(C.FONTS.big_label)
			:size(C.FONT_SIZE.big_label)
			:at(rr.x, rr.y)
			:sizes(rr.w, rr.h)
			:align("center", "left")
			:color(C.COLOR.VALUE)
		out[#out + 1] = text:id("big_v_" .. row.id)
			:val("")
			:font(C.FONTS.big_value)
			:size(row.kind == "rank" and C.FONT_SIZE.big_value_rank or C.FONT_SIZE.big_value)
			:at(rr.x, rr.y)
			:sizes(rr.w, rr.h)
			:align("center", "right")
			:color(C.COLOR.VALUE)
	end
	return out
end)

local rank_box_block = make(
	"rank_box",
	at_block(g.rank_box),

	rect:id("rank_bg"):color(C.COLOR.RANK_BOX_BG),
	texture:id("rank_border"):material(C.MATERIAL.frame_tile):color(C.COLOR.RANK_BOX_BORDER):scale(),

	function()
		local out = {}
		for i = 1, C.RANK_MAX_GLYPHS do
			out[#out + 1] = text:id("rank_shadow_" .. i)
				:val("")
				:font(C.FONTS.rank)
				:size(C.FONT_SIZE.rank_shadow)
				:align("center", "center")
				:color(C.COLOR.RANK_SHADOW)
			out[#out + 1] = text:id("rank_letter_" .. i)
				:val("")
				:font(C.FONTS.rank)
				:size(C.FONT_SIZE.rank)
				:align("center", "center")
				:color(C.COLOR.WHITE)
		end
		return out
	end
)

local delete_run_block = make(
	"delete_run",
	at_block(g.delete_run),
	rect:id("del_bg"):color(C.COLOR.DELETE_RUN_BG):z(10),
	text:id("del_text")
		:val(mod:localize("mission_summary_delete_run"))
		:font(C.FONTS.heading)
		:size(C.FONT_SIZE.heading)
		:align("center", "center")
		:color(C.COLOR.DELETE_RUN_TEXT)
		:z(15)
)

---@param name string
---@param block { x: number, y: number, w: number, h: number }
---@param heading_key string
---@param rows { id: string, label: string|nil, label_key: string|nil, stat: boolean|nil, is_time: boolean|nil }[]
local function event_block(name, block, heading_key, rows)
	return make(name, at_block(block), heading_passes(block.w, mod:localize(heading_key)), function()
		local out = {}
		for i = 1, #rows do
			local rr = Presentation.block_row_local(block.w, block.h, #rows, i, C.HEADING_H, nil, C.EVENT_ROW_H)
			out[#out + 1] = text:id(name .. "_l_" .. i)
				:val(Presentation.row_label(rows[i]))
				:font(C.FONTS.label)
				:size(C.FONT_SIZE.event_label)
				:at(rr.x, rr.y)
				:sizes(rr.w * 0.72, rr.h)
				:align("center", "left")
				:color(C.COLOR.LABEL)
			out[#out + 1] = text:id(name .. "_v_" .. i)
				:val("")
				:font(C.FONTS.value)
				:size(C.FONT_SIZE.event_value)
				:at(rr.x, rr.y)
				:sizes(rr.w, rr.h)
				:align("center", "right")
				:color(C.COLOR.VALUE)
		end
		return out
	end)
end

local victims_block = event_block("victims", g.victims, C.HEADINGS.victims, C.VICTIMS_EVENTS)
local method_block = event_block("method", g.method, C.HEADINGS.method, C.METHOD_EVENTS)
local style_block = event_block("style", g.style, C.HEADINGS.style, C.STYLE_EVENTS)
local competence_block = event_block("competence", g.competence, C.HEADINGS.competence, C.COMPETENCE_EVENTS)

local magnitude_block = make(
	"magnitude",
	at_block(g.magnitude),
	heading_passes(g.magnitude.w, mod:localize(C.HEADINGS.magnitude)),
	function()
		local out = {}
		for i = 1, #C.MAGNITUDE_ROWS do
			local row = C.MAGNITUDE_ROWS[i]
			local rr = Presentation.block_row_local(
				g.magnitude.w,
				g.magnitude.h,
				#C.MAGNITUDE_ROWS,
				i,
				C.HEADING_H,
				nil,
				C.MAGNITUDE_ROW_H
			)
			local label_x = rr.x
			if row.sub then

				local mid = rr.y + rr.h * 0.5
				out[#out + 1] = rect:id("mag_conn_v_" .. i)
					:at(rr.x + C.MAGNITUDE_CONNECTOR_X, rr.y + 3)
					:sizes(C.MAGNITUDE_CONNECTOR_THICK, rr.h * 0.5 - 3 + C.MAGNITUDE_CONNECTOR_THICK)
					:color(C.COLOR.RULE)
				out[#out + 1] = rect:id("mag_conn_h_" .. i)
					:at(rr.x + C.MAGNITUDE_CONNECTOR_X, mid)
					:sizes(C.MAGNITUDE_CONNECTOR_W, C.MAGNITUDE_CONNECTOR_THICK)
					:color(C.COLOR.RULE)
				label_x = rr.x + C.MAGNITUDE_SUB_INDENT
			end
			out[#out + 1] = text:id("mag_l_" .. row.id)
				:val(mod:localize(row.label_key))
				:font(C.FONTS.label)
				:size(C.FONT_SIZE.event_label)
				:at(label_x, rr.y)
				:sizes(rr.w * 0.7, rr.h)
				:align("center", "left")
				:color(row.sub and C.COLOR.LABEL or C.COLOR.VALUE)
			out[#out + 1] = text:id("mag_v_" .. row.id)
				:val("")
				:font(C.FONTS.value)
				:size(C.FONT_SIZE.event_value)
				:at(rr.x, rr.y)
				:sizes(rr.w, rr.h)
				:align("center", "right")
				:color(C.COLOR.VALUE)
		end
		return out
	end
)

local team_block = event_block("team", g.team, C.HEADINGS.team, C.TEAM_EVENTS)

local mission_grid_block = make("mission_grid", at_block(g.mission_grid), function()
	local out = {}
	local level_w = C.MISSION_TILE_LEVEL_W
	local pad = C.MISSION_TILE_PAD_X
	for i = 1, C.MAX_MISSION_TILES do
		local t = Presentation.mission_tile_local(i)
		out[#out + 1] = rect:id("tile_bg_" .. i):at(t.x, t.y):sizes(t.w, t.h):color(C.COLOR.ROW_BG)

		out[#out + 1] = rect:id("tile_fill_" .. i):at(t.x, t.y):sizes(t.w, t.h):color(C.COLOR.TILE_PROGRESS_FILL)
		out[#out + 1] = text:id("tile_name_" .. i)
			:val("")
			:font(C.FONTS.label_bold)
			:size(C.FONT_SIZE.tile_name)
			:at(t.x + pad, t.y, 1)
			:sizes(t.w - pad * 2 - level_w, t.h)
			:align("center", "left")
			:color(C.COLOR.ROW_TEXT)
		out[#out + 1] = text:id("tile_level_" .. i)
			:val("")
			:font(C.FONTS.rank)
			:size(C.FONT_SIZE.tile_level)
			:at(t.x + t.w - level_w - 6, t.y)
			:sizes(level_w, t.h)
			:align("center", "right")
			:color(C.COLOR.WHITE)
	end
	return out
end)

local live_button_block = make(
	"live_button",
	at_block(g.live_button),
	rect:id("button_bg"):color(C.COLOR.BUTTON_LIVE_MISSION_BG):z(10),
	text:id("button_text")
		:val(mod:localize("mission_summary_show_live"))
		:font(C.FONTS.heading)
		:size(C.FONT_SIZE.button)
		:align("center", "center")
		:color(C.COLOR.BUTTON_TEXT)
		:z(10)
)

local hell_yeah_block = make(
	"hell_yeah",
	at_block(g.hell_yeah),
	rect:id("hy_bg"):color(C.COLOR.HELL_YEAH_BG):z(10),

	rect:id("hy_bg_shadow"):at(C.HELL_YEAH_SHADOW_MIN, C.HELL_YEAH_SHADOW_MIN):color(Color.black(255, true)):z(5),
	text:id("hy_text")
		:val(mod:localize("mission_summary_hell_yeah"))
		:font(C.FONTS.heading)
		:size(C.FONT_SIZE.hell_yeah)
		:align("center", "center")
		:color(C.COLOR.HELL_YEAH_TEXT)
		:z(20)
)

local skip_recap_block = (function()
	local icon_y = (C.HELL_YEAH_BUTTON_H - C.SKIP_RECAP_ICON_SIZE) * 0.5
	return make(
		"skip_recap",
		at_block(g.skip_recap),
		rect:id("skip_bg"):color(C.COLOR.SKIP_RECAP_BG):z(10),
		text:id("skip_text")
			:val(mod:localize("mission_summary_skip_recap"))
			:font(C.FONTS.heading)
			:size(C.FONT_SIZE.hell_yeah)
			:at(0, 0)
			:sizes(g.skip_recap.w, C.HELL_YEAH_BUTTON_H)
			:align("center", "left")
			:color(C.COLOR.SKIP_RECAP_TEXT)
			:z(20),
		texture
			:id("skip_icon")
			:material(C.MATERIAL.skip_recap_icon)
			:scale(false)
			:at(0, icon_y)
			:sizes(C.SKIP_RECAP_ICON_SIZE, C.SKIP_RECAP_ICON_SIZE)
			:color(C.COLOR.SKIP_RECAP_TEXT)
			:z(20)
	)
end)()

return build(
	screen(),

	make(
		"panel",
		scene
			:child_of("screen")
			:align("center", "center")
			:at(C.PANEL_OFFSET_X, C.PANEL_OFFSET_Y)
			:sizes(C.PANEL_WIDTH, C.PANEL_HEIGHT)
	),
	header_block,
	highscores_block,
	run_block,
	big_stats_block,
	rank_box_block,
	delete_run_block,
	victims_block,
	magnitude_block,
	method_block,
	style_block,
	competence_block,
	team_block,
	mission_grid_block,
	live_button_block,
	hell_yeah_block,
	skip_recap_block
)
