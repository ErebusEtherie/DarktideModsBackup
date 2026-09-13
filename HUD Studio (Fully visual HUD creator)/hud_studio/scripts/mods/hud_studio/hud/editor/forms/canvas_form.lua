---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_canvas_form then
	return mod.hud_studio_canvas_form
end

local FIXED_ONLY_MODE_OPTIONS = {
	{ value = "fixed", text = mod:localize("static") },
}

local GRID_MIN = 0
local GRID_MAX = 100

local CanvasForm = {}

local function grid_number(canvas, field, label)
	return {
		kind = "numeric",
		label = label,
		token = "canvas/grid." .. field,
		half = true,
		step = 1,
		min = GRID_MIN,
		max = GRID_MAX,
		decimals = 0,
		get = function()
			return canvas[field] or 0
		end,
		set = function(value)
			canvas[field] = value
		end,
	}
end

local function grid_group(canvas)
	return {
		group = true,
		field = "grid",
		label = mod:localize("grid"),
		mode = {
			kind = "dropdown",
			options = FIXED_ONLY_MODE_OPTIONS,
			get = function()
				return "fixed"
			end,
			set = function() end,
		},
		controls = {
			grid_number(canvas, "grid_rows", mod:localize("rows")),
			grid_number(canvas, "grid_cols", mod:localize("columns")),
		},
	}
end

local HIDE_HIDDEN_HELP = mod:localize("canvas_hide_hidden_help")

local function hide_hidden_row(canvas)
	return {
		kind = "checkbox",
		label = mod:localize("canvas_hide_hidden"),
		get = function()
			return canvas.hide_hidden_in_editor == true
		end,
		set = function(on)
			canvas.hide_hidden_in_editor = on or nil
		end,
	}
end

local function hide_hidden_help_row()
	return {
		kind = "note",
		wrap = true,
		value = function()
			return HIDE_HIDDEN_HELP
		end,
	}
end

---@param canvas CanvasData
---@return FormSection[]
function CanvasForm.build(canvas)
	return {
		{
			key = "canvas",
			title = mod:localize("canvas_title"),
			flat = true,
			rows = {
				grid_group(canvas),
				hide_hidden_row(canvas),
				hide_hidden_help_row(),
			},
		},
	}
end

mod.hud_studio_canvas_form = CanvasForm

return CanvasForm
