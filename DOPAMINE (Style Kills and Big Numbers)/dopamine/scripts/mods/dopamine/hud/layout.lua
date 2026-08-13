

---@type mod
local mod = get_mod("dopamine")

if mod.layout then
	return mod.layout
end

local StyleHud = mod:core(mod.style_meter_constants, "hud/style_meter/constants").PRESENTATION
local FuryMeterConstants = mod:core(mod.fury_meter_constants, "hud/fury_meter/constants")
local TaskConstants = mod:core(mod.task_constants, "hud/task/constants").PRESENTATION
local StatChartConstants = mod:core(mod.stat_chart_constants, "hud/stat_chart/constants").PRESENTATION

local Hud = require("scripts/utilities/ui/hud")

local math_floor = math.floor
local math_max = math.max

---@alias LayoutElement "score" | "fury" | "objective" | "stats"

---@class ElementSpace
---@field above number Space (design px) kept between this element's top and the element stacked above it.
---@field below number Space (design px) kept between this element's bottom and the element stacked below it.

---@type table<LayoutElement, ElementSpace>
local ELEMENT_SPACE = {
	score = { above = 0, below = 24 },
	fury = { above = 12, below = 0 }, 
	objective = { above = 0, below = 14 },
	stats = { above = 0, below = 14 },
}

---@param element LayoutElement
---@return ElementSpace
local function element_space(element)
	return ELEMENT_SPACE[element]
end

local NATIVE_MISSION_SPEAKER_Y = 300

local MISSION_SPEAKER_CLEAR_GAP = 20

local NATIVE_CHAT_TOP_Y = -490 + 1080 - 250

local CHAT_CLEAR_GAP = 12

local EVENT_ROW_GROWTH = 1
local EVENT_PAD_GROWTH = 0.5

local function events_font_delta()
	return mod.dl.settings.events_font_size or 0
end

local function event_font_size()
	return StyleHud.SLOT_FONT_SIZE + events_font_delta()
end

local function multiplier_label_font_size()
	return StyleHud.MULT_LABEL_FONT_SIZE + events_font_delta()
end

local function event_slot_height()
	return StyleHud.SLOT_HEIGHT + events_font_delta() * EVENT_ROW_GROWTH
end

local function event_panel_vertical_pad()
	return StyleHud.EVENT_PANEL_VERTICAL_PAD + events_font_delta() * EVENT_PAD_GROWTH
end

local function sp_counter_delta()
	return mod.dl.settings.sp_counter_font_size or 0
end

local function sp_font_size()
	return StyleHud.SP_FONT_SIZE + sp_counter_delta()
end

local function sp_label_font_size()
	return StyleHud.SP_LABEL_FONT_SIZE + sp_counter_delta()
end

local function sp_popup_font_size()
	return StyleHud.SP_POPUP_FONT_SIZE + sp_counter_delta()
end

local function event_panel_bottom_rel()
	return StyleHud.EVENT_STACK_OFFSET_Y + math_floor(event_font_size() * 0.5 + event_panel_vertical_pad() + 0.5)
end

local function sp_block_y()
	local sp_panel_top_rel_to_block = StyleHud.SP_LABEL_OFFSET_Y
		- math_floor(sp_label_font_size() * 0.5 + StyleHud.SP_PANEL_TOP_PAD)
	return event_panel_bottom_rel() + StyleHud.SP_COUNTER_GAP - sp_panel_top_rel_to_block
end

local function score_root_to_sp_bottom()
	local sp_panel_bottom_rel = sp_block_y()
		+ StyleHud.SP_VALUE_OFFSET_Y
		+ math_floor(sp_font_size() * 0.5 + StyleHud.SP_PANEL_BOTTOM_PAD)
	return StyleHud.ROOT_HEIGHT * 0.5 + sp_panel_bottom_rel
end

local function style_panel_top_rel()
	return StyleHud.EVENT_STACK_OFFSET_Y
		- mod.dl.settings.max_event_slots * event_slot_height()
		- StyleHud.MULT_ROW_GAP
		- math_floor(multiplier_label_font_size() * 0.5 + event_panel_vertical_pad() + 0.5)
end

local function style_top_to_root()
	return -(StyleHud.ROOT_HEIGHT * 0.5 + style_panel_top_rel())
end

local function style_track_height()
	return style_top_to_root() + score_root_to_sp_bottom()
end

local LR_SLOTS = {
	{ setting = "slot_left", side = "left", order = 1 },
	{ setting = "slot_left_2", side = "left", order = 2 },
	{ setting = "slot_left_3", side = "left", order = 3 },
	{ setting = "slot_left_4", side = "left", order = 4 },
	{ setting = "slot_right_1", side = "right", order = 1 },
	{ setting = "slot_right_2", side = "right", order = 2 },
	{ setting = "slot_right_3", side = "right", order = 3 },
	{ setting = "slot_right_4", side = "right", order = 4 },
}

local PLACEABLE = { score = true, objective = true, stats = true, fury = true }

---@class Layout
local Layout = {}

Layout.event_font_size = event_font_size
Layout.multiplier_label_font_size = multiplier_label_font_size
Layout.event_slot_height = event_slot_height
Layout.event_panel_vertical_pad = event_panel_vertical_pad
Layout.event_panel_bottom_rel = event_panel_bottom_rel
Layout.sp_font_size = sp_font_size
Layout.sp_label_font_size = sp_label_font_size
Layout.sp_popup_font_size = sp_popup_font_size
Layout.sp_block_y = sp_block_y

mod.dl.settings.derive("slot_layout", function()
	local placement = {}
	local columns = { left = {}, right = {} }

	for i = 1, #LR_SLOTS do
		local meta = LR_SLOTS[i]
		local element = mod.dl.settings[meta.setting]
		if PLACEABLE[element] then

			if not placement[element] then
				placement[element] = { side = meta.side, order = meta.order }
				local column = columns[meta.side]
				column[#column + 1] = { element = element, order = meta.order }
			end
		end
	end

	local function by_order(a, b)
		return a.order < b.order
	end
	table.sort(columns.left, by_order)
	table.sort(columns.right, by_order)

	return { placement = placement, columns = columns }
end)

local function slot_layout()
	return mod.dl.settings.slot_layout
end

---@return "left" | "right"
function Layout.score_side()
	local p = slot_layout().placement.score
	return p and p.side or "left"
end

---@return "left" | "right"
function Layout.objective_side()
	local p = slot_layout().placement.objective
	return p and p.side or "right"
end

---@return boolean
function Layout.score_enabled()
	return slot_layout().placement.score ~= nil
end

---@return boolean
function Layout.tasks_enabled()
	return slot_layout().placement.objective ~= nil
end

---@return boolean
function Layout.fury_centered()
	return mod.dl.settings.slot_center == "fury"
end

---@return boolean
function Layout.fury_slotted()
	return slot_layout().placement.fury ~= nil
end

---@return "left" | "right"
function Layout.fury_side()
	local p = slot_layout().placement.fury
	return p and p.side or "left"
end

---@return boolean
function Layout.fury_visible()
	return Layout.fury_centered() or Layout.fury_slotted()
end

function Layout.column_offset(side)
	return Layout.editable_value("offset_" .. ((side == "right") and "right" or "left"))
end

local EDITABLE = {
	margin_left = { setting = "hud_margin_left", min = 0, max = 700, default = 50 },
	margin_right = { setting = "hud_margin_right", min = 0, max = 700, default = 50 },
	offset_left = { setting = "hud_offset_left", min = 0, max = 1000, default = 190 },
	offset_right = { setting = "hud_offset_right", min = 0, max = 1000, default = 200 },
	offset_center = { setting = "fury_meter_offset_y", min = 0, max = 1000, default = 275 },
}

local _override = {}

Layout.EDITABLE = EDITABLE

---@param key string
---@param value number
---@return number
function Layout.clamp_editable(key, value)
	local spec = EDITABLE[key]
	if not spec then

		mod.dl.report("layout", "clamp_editable", 0, ("no EDITABLE spec for '%s' - value unclamped"):format(key))
		return value
	end
	return math.clamp(value, spec.min, spec.max)
end

---@param key string
---@return number
function Layout.editable_value(key)
	local override = _override[key]
	if override then
		return override
	end
	local spec = EDITABLE[key]
	if not spec then
		return 0
	end
	local value = mod.dl.settings[spec.setting]
	if value == nil then
		value = spec.default
	end

	return Layout.clamp_editable(key, value)
end

---@param key string
---@param value number | nil
function Layout.set_editable_override(key, value)
	_override[key] = value and Layout.clamp_editable(key, value) or nil
end

---@param key string
function Layout.commit_editable(key)
	local value = _override[key]
	local spec = EDITABLE[key]
	if not value or not spec then
		return
	end
	_override[key] = nil
	mod:set(spec.setting, Layout.clamp_editable(key, value), true)
end

---@param side "left" | "right"
---@return number
function Layout.margin_value(side)
	return Layout.editable_value("margin_" .. side)
end

---@param side "left" | "right"
---@return number
function Layout.margin_x(side)
	local value = Layout.margin_value(side)
	return side == "left" and value or -value
end

---@return number
function Layout.center_offset_y()
	return Layout.editable_value("offset_center")
end

---@param element LayoutElement
---@return number
function Layout.element_height(element)
	if element == "score" then
		return style_track_height()
	elseif element == "fury" then
		return Layout.fury_height()
	elseif element == "objective" then
		return Layout.task_track_height()
	elseif element == "stats" then
		return Layout.stats_height()
	end
	return 0
end

---@param element LayoutElement
---@return number
function Layout.element_top_y(element)
	local layout = slot_layout()
	local p = layout.placement[element]
	if not p then

		return 0
	end

	local y = Layout.column_offset(p.side)
	local column = layout.columns[p.side]
	for i = 1, #column do
		local entry = column[i]
		if entry.order >= p.order then
			break 
		end
		local below = column[i + 1] and column[i + 1].element
		y = y
			+ Layout.element_height(entry.element)
			+ element_space(entry.element).below
			+ (below and element_space(below).above or 0)
	end
	return y
end

function Layout.column_bottom_y(side)
	local column = slot_layout().columns[side]
	local lowest = column[#column]
	if not lowest then
		return nil
	end
	return Layout.element_top_y(lowest.element) + Layout.element_height(lowest.element)
end

---@return boolean
function Layout.left_column_occupied()
	return slot_layout().columns.left[1] ~= nil
end

local function fury_theme_ui()
	return (mod.dl.settings.fury_meter_theme or "ui") == "ui"
end

local function fury_above_bar()
	local above = 0
	if fury_theme_ui() then
		above = FuryMeterConstants.PRESENTATION.UI_FRAME_ABOVE + FuryMeterConstants.PRESENTATION.UI_FRAME_H
	end
	if mod.dl.settings.enable_fury_rank_text ~= false then
		local font = mod.dl.settings.fury_rank_font_size or FuryMeterConstants.PRESENTATION.CALLOUT_FONT_SIZE
		above = math_max(above, font + FuryMeterConstants.PRESENTATION.CALLOUT_ABOVE_GAP)
	end
	return above
end

function Layout.fury_height()
	if not Layout.fury_slotted() then
		return 0
	end
	local bar_height = mod.dl.settings.fury_meter_height or FuryMeterConstants.PRESENTATION.DEFAULT_BAR_HEIGHT
	return fury_above_bar()
		+ bar_height
		+ FuryMeterConstants.PRESENTATION.STATLINE_GAP
		+ FuryMeterConstants.PRESENTATION.STAT_ROW_HEIGHT
end

function Layout.fury_top_y()
	return Layout.element_top_y("fury")
end

function Layout.fury_bottom_y()
	return Layout.fury_top_y() + Layout.fury_height()
end

---@param bar_height number
---@return number
function Layout.fury_bar_center_y(bar_height)
	return Layout.fury_top_y() + fury_above_bar() + bar_height * 0.5
end

function Layout.score_top_y()
	return Layout.element_top_y("score")
end

function Layout.style_top_y()
	return Layout.score_top_y()
end

function Layout.style_height()
	return style_track_height()
end

function Layout.score_anchor_y()
	return Layout.style_top_y() + style_top_to_root()
end

function Layout.score_bottom_y()
	return Layout.score_anchor_y() + score_root_to_sp_bottom()
end

function Layout.style_bottom_y()
	return Layout.score_bottom_y()
end

function Layout.task_track_height()
	if not Layout.tasks_enabled() then
		return 0
	end
	return TaskConstants.PANEL_SLOTS * TaskConstants.ROW_HEIGHT
		+ TaskConstants.PANEL_VERTICAL_PAD * 2
		+ TaskConstants.TITLE_AREA_HEIGHT
end

function Layout.task_track_top_y()
	return Layout.element_top_y("objective")
end

function Layout.task_track_bottom_y()
	return Layout.task_track_top_y() + Layout.task_track_height()
end

function Layout.objective_bottom_y()
	return Layout.task_track_bottom_y()
end

---@return "left" | "right"
function Layout.stats_side()
	local p = slot_layout().placement.stats
	return p and p.side or "right"
end

---@return boolean
function Layout.stats_enabled()
	return slot_layout().placement.stats ~= nil
end

function Layout.stats_height()
	if not Layout.stats_enabled() then
		return 0
	end
	return StatChartConstants.MAX_ROWS * StatChartConstants.ROW_HEIGHT
		+ StatChartConstants.PANEL_VERTICAL_PAD * 2
		+ StatChartConstants.TITLE_AREA_HEIGHT
end

function Layout.stats_top_y()
	return Layout.element_top_y("stats")
end

function Layout.stats_bottom_y()
	return Layout.stats_top_y() + Layout.stats_height()
end

function Layout.right_column_bottom_y()
	return Layout.column_bottom_y("right")
end

function Layout.native_mission_speaker_push_y()
	local bottom = Layout.right_column_bottom_y()
	if not bottom then
		return 0
	end
	local target_top = bottom + MISSION_SPEAKER_CLEAR_GAP
	return math_max(0, target_top - NATIVE_MISSION_SPEAKER_Y)
end

function Layout.left_column_bottom_y()
	return Layout.column_bottom_y("left")
end

local function hud_to_chat_scale()
	local base_scale = RESOLUTION_LOOKUP.scale
	if not base_scale or base_scale == 0 then
		return 1
	end
	return Hud.hud_scale() / base_scale
end

function Layout.native_chat_push_y()
	local bottom = Layout.left_column_bottom_y()
	if not bottom then
		return 0
	end
	local chat_space_bottom = (bottom - 10) * hud_to_chat_scale()
	return math_max(0, chat_space_bottom + CHAT_CLEAR_GAP - NATIVE_CHAT_TOP_Y)
end

mod.layout = Layout

return Layout
