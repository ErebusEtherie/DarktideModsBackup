
local mod = get_mod("hud_studio")

if mod.hud_studio_block_library_layout then
	return mod.hud_studio_block_library_layout
end

---@class LibraryGrid
---@field slots Rect[]
---@field cols integer
---@field visible_rows integer
---@field x number
---@field y number
---@field w number
---@field h number

---@class LibraryDetailsRects
---@field x number
---@field y number
---@field w number
---@field h number
---@field heading Rect
---@field summary Rect
---@field meta Rect            derived metadata lines (tags / nodes / sources / saved)
---@field bind_label Rect
---@field bind_slots Rect[]    one button per offered rebind target
---@field rename_label Rect
---@field rename Rect
---@field add Rect
---@field update Rect        only drawn when the entry ships a newer version than a copy on the

---@field confirm Rect         the "Are you sure?" arming dropdown, left half of the delete row
---@field delete Rect          only drawn for user entries; laid out regardless

---@class LibraryHeaderRects
---@field x number
---@field y number
---@field w number
---@field h number
---@field heading Rect
---@field disclaimer Rect

---@class LibraryLayout
---@field frame Rect
---@field title Rect
---@field cats Rect[]
---@field header LibraryHeaderRects?
---@field grid LibraryGrid
---@field scrollbar Rect
---@field details LibraryDetailsRects
---@field n_entries integer?
---@field max_scroll integer?

---@class BlockLibraryLayout
local BlockLibraryLayout = {}

local floor = math.floor
local ceil = math.ceil
local max = math.max

local TITLE_H = 26
local PAD = 8

local CAT_COL_W = 140
local CAT_BTN_H = 36
local CAT_GAP = 4

local COL_GAP = 12
local COLS = 2
local CELL_H = 30
local CELL_GAP = 6
local SB_GAP = 6
local SCROLLBAR_W = 10
local MIN_ROWS = 10

local HEADER_ROW_H = 20
local HEADER_LINE_H = 16
local HEADER_LINES = 2

local HEADER_TITLE_GAP = 6
local HEADER_H = HEADER_ROW_H + HEADER_TITLE_GAP + HEADER_LINES * HEADER_LINE_H
local HEADER_GAP = 8

local DETAILS_W = 250

local HEADING_H = 30
local HEADING_GAP = 6
local SUMMARY_H = 200 
local META_H = 64 
local ROW_H = 22
local ROW_GAP = 6
local SECTION_GAP = 10
local BIND_SLOT_GAP = 4
local DELETE_SPLIT_GAP = 4 
local BTN_H = 26

BlockLibraryLayout.TITLE_H = TITLE_H
BlockLibraryLayout.PAD = PAD
BlockLibraryLayout.COLS = COLS
BlockLibraryLayout.CELL_H = CELL_H

BlockLibraryLayout.WIDTH = PAD + CAT_COL_W + COL_GAP + 320 + SB_GAP + SCROLLBAR_W + COL_GAP + DETAILS_W + PAD

---@param n_entries integer
---@param visible_rows integer
---@return integer max_scroll
function BlockLibraryLayout.max_scroll(n_entries, visible_rows)
	return max(0, ceil(n_entries / COLS) - visible_rows)
end

---@param x number
---@param y number
---@param w number
---@param n_cats integer      number of category buttons
---@param n_bind_slots integer  rebind targets offered for the selected entry (0 == no bind section)
---@param with_header boolean?  reserve the third-party banner above the grid
---@param with_update boolean?  reserve the Update row (false for entries that can never update)
---@return LibraryLayout
function BlockLibraryLayout.layout(x, y, w, n_cats, n_bind_slots, with_header, with_update)
	local title = { x = x, y = y, w = w, h = TITLE_H }

	local content_y = y + TITLE_H + PAD
	local cat_x = x + PAD

	local cats = {}
	for i = 1, n_cats do
		cats[i] = { x = cat_x, y = content_y + (i - 1) * (CAT_BTN_H + CAT_GAP), w = CAT_COL_W, h = CAT_BTN_H }
	end
	local cat_h = n_cats > 0 and (n_cats * (CAT_BTN_H + CAT_GAP) - CAT_GAP) or 0

	local details_x = x + w - PAD - DETAILS_W
	local grid_x = cat_x + CAT_COL_W + COL_GAP
	local grid_w = max(80, (details_x - COL_GAP - SB_GAP - SCROLLBAR_W) - grid_x)
	local cell_w = floor((grid_w - (COLS - 1) * CELL_GAP) / COLS)

	local bind_h = n_bind_slots > 0 and (ROW_H + ROW_GAP + BTN_H + SECTION_GAP) or 0

	local update_h = with_update and (BTN_H + ROW_GAP) or 0
	local details_h = HEADING_H
		+ HEADING_GAP
		+ SUMMARY_H
		+ META_H
		+ SECTION_GAP
		+ bind_h
		+ ROW_H
		+ ROW_GAP
		+ BTN_H
		+ SECTION_GAP
		+ BTN_H
		+ update_h
		+ BTN_H

	local header_h = with_header and (HEADER_H + HEADER_GAP) or 0
	local grid_y = content_y + header_h

	local min_grid_h = MIN_ROWS * CELL_H + (MIN_ROWS - 1) * CELL_GAP
	local body_h = max(cat_h, details_h, header_h + min_grid_h)
	local cell_pitch = CELL_H + CELL_GAP
	local visible_rows = max(1, floor((body_h - header_h + CELL_GAP) / cell_pitch))
	local grid_h = visible_rows * CELL_H + (visible_rows - 1) * CELL_GAP
	body_h = max(body_h, header_h + grid_h)

	local slots = {}
	for s = 1, COLS * visible_rows do
		local col = (s - 1) % COLS
		local row = floor((s - 1) / COLS)
		slots[s] = {
			x = grid_x + col * (cell_w + CELL_GAP),
			y = grid_y + row * cell_pitch,
			w = cell_w,
			h = CELL_H,
		}
	end

	local scrollbar = { x = grid_x + grid_w + SB_GAP, y = grid_y, w = SCROLLBAR_W, h = grid_h }

	local header = nil
	if with_header then
		local header_w = grid_w + SB_GAP + SCROLLBAR_W
		header = {
			x = grid_x,
			y = content_y,
			w = header_w,
			h = HEADER_H,
			heading = { x = grid_x, y = content_y, w = header_w, h = HEADER_ROW_H },
			disclaimer = {
				x = grid_x,
				y = content_y + HEADER_ROW_H + HEADER_TITLE_GAP,
				w = header_w,
				h = HEADER_LINES * HEADER_LINE_H,
			},
		}
	end

	local dy = content_y
	local function band(h)
		local r = { x = details_x, y = dy, w = DETAILS_W, h = h }
		dy = dy + h
		return r
	end

	local heading = band(HEADING_H)
	dy = dy + HEADING_GAP
	local summary = band(SUMMARY_H)
	local meta = band(META_H)
	dy = dy + SECTION_GAP

	local bind_label, bind_slots = nil, {}
	if n_bind_slots > 0 then
		bind_label = band(ROW_H)
		dy = dy + ROW_GAP
		local slot_w = floor((DETAILS_W - (n_bind_slots - 1) * BIND_SLOT_GAP) / n_bind_slots)
		for i = 1, n_bind_slots do
			bind_slots[i] = {
				x = details_x + (i - 1) * (slot_w + BIND_SLOT_GAP),
				y = dy,
				w = slot_w,
				h = BTN_H,
			}
		end
		dy = dy + BTN_H + SECTION_GAP
	else
		bind_label = { x = details_x, y = dy, w = DETAILS_W, h = 0 }
	end

	local rename_label = band(ROW_H)
	dy = dy + ROW_GAP
	local rename = band(BTN_H)
	dy = dy + SECTION_GAP
	local add = band(BTN_H)

	local update
	if with_update then
		dy = dy + ROW_GAP
		update = band(BTN_H)
		dy = dy + ROW_GAP
	else
		dy = dy + ROW_GAP
		update = { x = details_x, y = dy, w = DETAILS_W, h = 0 }
	end

	local delete_row = band(BTN_H)
	local half_w = floor((DETAILS_W - DELETE_SPLIT_GAP) / 2)
	local confirm = { x = delete_row.x, y = delete_row.y, w = half_w, h = BTN_H }
	local delete = {
		x = delete_row.x + half_w + DELETE_SPLIT_GAP,
		y = delete_row.y,
		w = DETAILS_W - half_w - DELETE_SPLIT_GAP,
		h = BTN_H,
	}

	return {
		frame = { x = x, y = y, w = w, h = TITLE_H + PAD + body_h + PAD },
		title = title,
		cats = cats,
		header = header,
		grid = {
			slots = slots,
			cols = COLS,
			visible_rows = visible_rows,
			x = grid_x,
			y = grid_y,
			w = grid_w,
			h = grid_h,
		},
		scrollbar = scrollbar,
		details = {
			x = details_x,
			y = content_y,
			w = DETAILS_W,
			h = dy - content_y,
			heading = heading,
			summary = summary,
			meta = meta,
			bind_label = bind_label,
			bind_slots = bind_slots,
			rename_label = rename_label,
			rename = rename,
			add = add,
			update = update,
			confirm = confirm,
			delete = delete,
		},
	}
end

mod.hud_studio_block_library_layout = BlockLibraryLayout

return BlockLibraryLayout
