
local mod = get_mod("hud_studio")

if mod.hud_studio_material_browser then
	return mod.hud_studio_material_browser
end

---@class Rect
---@field x number
---@field y number
---@field w number
---@field h number

---@class BrowserGrid
---@field slots Rect[]             one per visible cell, `cols * visible_rows` of them
---@field cols integer             fixed at COLS
---@field visible_rows integer     rows the grid window shows at once
---@field x number
---@field y number
---@field w number
---@field h number
---@field thumb number             square thumbnail edge, derived from the panel width

---@class BrowserLayout
---@field frame Rect               the whole panel, title bar included
---@field title Rect               the title bar
---@field cats Rect[]              one button per category, top to bottom
---@field grid BrowserGrid
---@field scrollbar Rect
---@field n_mats integer?          materials in the open category (host-filled)
---@field max_scroll integer?      max scroll_row for that count (host-filled)

---@class MaterialBrowser
local MaterialBrowser = {}

local floor = math.floor
local ceil = math.ceil
local max = math.max

local TITLE_H = 26
local PAD = 8

local CAT_COL_W = 156
local CAT_BTN_H = 24
local CAT_GAP = 4

local COL_GAP = 12 
local COLS = 6
local THUMB_GAP = 8
local SB_GAP = 6
local SCROLLBAR_W = 10
local MIN_ROWS = 8

MaterialBrowser.TITLE_H = TITLE_H
MaterialBrowser.PAD = PAD

---@param n_mats integer        materials in the open category
---@param visible_rows integer  rows the grid window shows at once
---@return integer max_scroll
function MaterialBrowser.max_scroll(n_mats, visible_rows)
	return max(0, ceil(n_mats / COLS) - visible_rows)
end

---@param x number
---@param y number
---@param w number
---@param n_cats integer   number of category buttons
---@return BrowserLayout layout
function MaterialBrowser.layout(x, y, w, n_cats)
	local title = { x = x, y = y, w = w, h = TITLE_H }

	local content_y = y + TITLE_H + PAD
	local cat_x = x + PAD

	local cats = {}
	for i = 1, n_cats do
		cats[i] = { x = cat_x, y = content_y + (i - 1) * (CAT_BTN_H + CAT_GAP), w = CAT_COL_W, h = CAT_BTN_H }
	end
	local cat_h = n_cats > 0 and (n_cats * (CAT_BTN_H + CAT_GAP) - CAT_GAP) or 0

	local grid_x = cat_x + CAT_COL_W + COL_GAP
	local grid_area_w = (x + w - PAD) - grid_x
	local thumb = floor((grid_area_w - SCROLLBAR_W - SB_GAP - (COLS - 1) * THUMB_GAP) / COLS)
	if thumb < 8 then
		thumb = 8
	end
	local cell = thumb + THUMB_GAP

	local min_grid_h = MIN_ROWS * thumb + (MIN_ROWS - 1) * THUMB_GAP
	local body_h = max(cat_h, min_grid_h)
	local visible_rows = max(1, floor((body_h + THUMB_GAP) / cell) + 1)
	local grid_h = visible_rows * thumb + (visible_rows - 1) * THUMB_GAP
	body_h = max(cat_h, grid_h)

	local slots = {}
	local slot_count = COLS * visible_rows
	for s = 1, slot_count do
		local col = (s - 1) % COLS
		local row = floor((s - 1) / COLS)
		slots[s] = { x = grid_x + col * cell, y = content_y + row * cell, w = thumb, h = thumb }
	end

	local grid_w = COLS * thumb + (COLS - 1) * THUMB_GAP
	local scrollbar = { x = grid_x + grid_w + SB_GAP, y = content_y, w = SCROLLBAR_W, h = grid_h }

	return {
		frame = { x = x, y = y, w = w, h = TITLE_H + PAD + body_h + PAD },
		title = title,
		cats = cats,
		grid = {
			slots = slots,
			cols = COLS,
			visible_rows = visible_rows,
			x = grid_x,
			y = content_y,
			w = grid_w,
			h = grid_h,
			thumb = thumb,
		},
		scrollbar = scrollbar,
	}
end

mod.hud_studio_material_browser = MaterialBrowser

return MaterialBrowser
