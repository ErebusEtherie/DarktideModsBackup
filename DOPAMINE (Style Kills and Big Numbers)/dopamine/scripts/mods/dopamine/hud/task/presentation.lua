

---@type mod
local mod = get_mod("dopamine")

if mod.task_presentation then
	return mod.task_presentation
end

local Constants = mod:core(mod.task_constants, "hud/task/constants").PRESENTATION
local Layout = mod:core(mod.layout, "hud/layout")
local Registry = mod:core(mod.task_registry, "utils/task/registry")
local StyleMeterPresentation = mod:core(mod.style_meter_presentation, "hud/style_meter/presentation")

---@class TaskLayout
---@field left boolean -- true when the track docks to the LEFT screen edge
---@field halign "left"|"right"
---@field root_valign "top"
---@field root_margin_x number -- signed inset of the root from the docked edge
---@field offset_y number -- root drop from hud/layout.lua
---@field text_pad_x number -- signed row-text inset from the panel's outer edge
---@field exit_slide_sign 1|-1 -- direction a row slides on enter/exit

---@class TaskPresentation
local TaskPresentation = {}

---@return TaskLayout
function TaskPresentation.layout_side()
	local left = Layout.objective_side() == "left"

	local root_margin_x = Layout.margin_x(left and "left" or "right")
	local offset_y = Layout.task_track_top_y()

	return {
		left = left,
		halign = left and "left" or "right",
		root_valign = "top",
		root_margin_x = root_margin_x,
		offset_y = offset_y,
		text_pad_x = left and Constants.TEXT_PAD_X or -Constants.TEXT_PAD_X,
		exit_slide_sign = left and -1 or 1,
	}
end

---@return "simple"|"ui"
function TaskPresentation.theme()
	local value = mod.dl.settings.task_track_theme
	return value == "ui" and "ui" or "simple"
end

---@return boolean
function TaskPresentation.is_ui_theme()
	return TaskPresentation.theme() == "ui"
end

---@return boolean
function TaskPresentation.tasks_enabled()
	return Layout.tasks_enabled()
end

---@return string
function TaskPresentation.title_text()
	return mod:localize("task_track_title")
end

---@return argb_table
function TaskPresentation.title_color()
	return TaskPresentation.is_ui_theme() and Constants.TITLE_COLOR_UI or Constants.TITLE_COLOR_SIMPLE
end

local ROWS_TOP_OFFSET = Constants.TITLE_AREA_HEIGHT + Constants.PANEL_VERTICAL_PAD

---@param slot_index integer -- 1 = top row
---@return number y
function TaskPresentation.slot_y(slot_index)

	return ROWS_TOP_OFFSET + (slot_index - 1) * Constants.ROW_HEIGHT
end

---@return number top_y, number height
function TaskPresentation.panel_layout()
	local height = Constants.PANEL_SLOTS * Constants.ROW_HEIGHT
		+ Constants.PANEL_VERTICAL_PAD * 2
		+ Constants.TITLE_AREA_HEIGHT
	return 0, height
end

---@return number y
function TaskPresentation.title_y()
	return Constants.TITLE_TOP_PAD
end

---@param style table|nil -- a widget text style pass
---@param layout TaskLayout
function TaskPresentation.apply_text_align(style, layout)
	if not style then
		return
	end
	style.horizontal_alignment = layout.halign
	style.text_horizontal_alignment = layout.halign
end

---@param style table|nil -- a widget panel style pass
---@param layout TaskLayout
function TaskPresentation.apply_panel_align(style, layout)
	if not style then
		return
	end
	style.horizontal_alignment = layout.halign
end

---@param style table|nil -- the panel background style pass (mutated in place)
---@param layout TaskLayout
function TaskPresentation.apply_panel_texture_uv(style, layout)
	if not style then
		return
	end
	if not style.uvs then
		style.uvs = { { 0, 0 }, { 1, 1 } }
	end
	local uvs = style.uvs
	if layout.left then
		uvs[1][1], uvs[1][2], uvs[2][1], uvs[2][2] = 1, 0, 0, 1
	else
		uvs[1][1], uvs[1][2], uvs[2][1], uvs[2][2] = 0, 0, 1, 1
	end
end

---@param sp_reward number|nil
---@return string
function TaskPresentation.format_reward(sp_reward)
	return "+" .. StyleMeterPresentation.format_sp(sp_reward or 0)
end

---@param sp_multiplier number|nil
---@return string|nil -- nil at base multiplier (<= 1)
function TaskPresentation.format_mult(sp_multiplier)
	if not sp_multiplier or sp_multiplier <= 1 then
		return nil
	end
	return "×" .. string.format("%g", sp_multiplier)
end

---@param current number|nil
---@param target number|nil
---@param tagged boolean|nil -- true wraps each side in its own rich-text color
---@return string
function TaskPresentation.format_progress(current, target, tagged)
	local current_text = mod.dl.str.format_number(current or 0)
	local target_text = mod.dl.str.format_number(target or 0)
	if tagged then
		return mod.dl.str.rich_text(current_text, { color = Constants.COLOR_CURRENT })
			.. mod.dl.str.rich_text(" / " .. target_text, { color = Constants.COLOR_TARGET })
	end
	return current_text .. " / " .. target_text
end

---@param seconds number|nil
---@return string
function TaskPresentation.format_timer(seconds)
	return mod.dl.str.format_timer(seconds)
end

---@param task ActiveTask
---@return string
function TaskPresentation.label_text(task)
	local label = Registry.fill_label(task.event_label, task)
	local icon = Registry.difficulty_icon(task.tier)
	if icon then
		if TaskPresentation.layout_side().halign == "left" then
			return label .. " " .. icon
		else
			return icon .. " " .. label
		end
	end
	return label
end

---@param task ActiveTask
---@param layout TaskLayout|nil
---@param status "done"|"fail"|nil
---@return string rich_text
function TaskPresentation.row1(task, layout, status)
	local label = mod.dl.str.rich_text(TaskPresentation.label_text(task), { color = Constants.COLOR_LABEL })

	if status ~= "done" then
		return label
	end

	local reward_block =
		mod.dl.str.rich_text(TaskPresentation.format_reward(task.sp_reward), { color = Constants.COLOR_REWARD })
	local mult = TaskPresentation.format_mult(task.sp_multiplier)
	if mult then
		reward_block = reward_block .. " " .. mod.dl.str.rich_text(mult, { color = Constants.COLOR_MULT })
	end

	if layout and not layout.left then

		return reward_block .. "   " .. label
	end

	return label .. "   " .. reward_block
end

---@param task ActiveTask
---@param layout TaskLayout|nil
---@return string rich_text
function TaskPresentation.row2_progress(task, layout)
	local progress = TaskPresentation.format_progress(task.current_count, task.target_count, true)

	if not task.timer_enabled then
		return progress
	end

	local timer = mod.dl.str.rich_text(
		TaskPresentation.format_timer(task.timer_remaining),
		{ color = TaskPresentation.timer_color_rgb(task.timer_remaining) }
	)

	if layout and not layout.left then
		return progress .. "   " .. timer
	end

	return timer .. "   " .. progress
end

---@param task ActiveTask
---@return string rich_text
function TaskPresentation.row2_status(task)
	if task.status == "done" then
		return mod.dl.str.rich_text("DONE", { color = Constants.COLOR_DONE_RGB })
	end

	return mod.dl.str.rich_text("FAILED", { color = Constants.COLOR_FAILED_RGB })
end

---@param timer_remaining number|nil
---@return rgb_table
function TaskPresentation.timer_color_rgb(timer_remaining)
	if timer_remaining ~= nil and timer_remaining <= Constants.TIMER_WARN_SECONDS then
		return Constants.COLOR_TIMER_WARN
	end
	return Constants.COLOR_TIMER
end

mod.task_presentation = TaskPresentation

return mod.task_presentation
