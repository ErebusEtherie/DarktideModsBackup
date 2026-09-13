---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_darktide_canvas_form then
	return mod.hud_studio_darktide_canvas_form
end

local ELEMENTS = {
	{ id = "player_1", label = mod:localize("dt_canvas_player_1") },
	{ id = "player_2", label = mod:localize("dt_canvas_player_2") },
	{ id = "player_3", label = mod:localize("dt_canvas_player_3") },
	{ id = "player_4", label = mod:localize("dt_canvas_player_4") },
	{ id = "dodge_stamina", label = mod:localize("dt_canvas_dodge_stamina") },
	{ id = "peril", label = mod:localize("dt_canvas_peril") },
	{ id = "ability", label = mod:localize("dt_canvas_ability") },
	{ id = "equipment", label = mod:localize("dt_canvas_equipment") },
	{ id = "force_greatsword_charge", label = mod:localize("dt_canvas_force_greatsword_charge") },
	{ id = "weapon_heat", label = mod:localize("dt_canvas_weapon_heat") },
	{ id = "weapon_special_charges", label = mod:localize("dt_canvas_weapon_special_charges") },
	{ id = "weapon_charge_up", label = mod:localize("dt_canvas_weapon_charge_up") },
}

local BUFFS_OFFSET_LIMIT = 2000

local DarktideCanvasForm = {}

local function is_shown(canvas, id)
	local set = canvas.vanilla
	return not (set and set[id] == false)
end

local function toggle_row(canvas, element)
	local id = element.id
	return {
		kind = "checkbox",
		label = element.label,
		get = function()
			return is_shown(canvas, id)
		end,
		set = function(on)
			canvas.vanilla = canvas.vanilla or {}

			if on then
				canvas.vanilla[id] = nil
			else
				canvas.vanilla[id] = false
			end
		end,
	}
end

local function buffs_offset_on(canvas)
	return canvas.buffs_offset ~= nil
end

local function buffs_offset_toggle(canvas)
	return {
		kind = "checkbox",
		get = function()
			return buffs_offset_on(canvas)
		end,
		set = function(on)
			if on then
				canvas.buffs_offset = canvas.buffs_offset or { 0, 0 }
			else
				canvas.buffs_offset = nil
			end
		end,
	}
end

local function buffs_offset_number(canvas, index, label)
	return {
		kind = "numeric",
		label = label,
		half = true,
		token = "canvas/buffs_offset." .. index,
		step = 1,
		min = -BUFFS_OFFSET_LIMIT,
		max = BUFFS_OFFSET_LIMIT,
		decimals = 0,
		hidden = function()
			return not buffs_offset_on(canvas)
		end,
		get = function()
			local offset = canvas.buffs_offset
			return (offset and offset[index]) or 0
		end,
		set = function(value)

			canvas.buffs_offset = canvas.buffs_offset or { 0, 0 }
			canvas.buffs_offset[index] = value
		end,
	}
end

local function buffs_offset_group(canvas)
	return {
		group = true,
		field = "buffs_offset",
		label = mod:localize("dt_canvas_move_buffs"),
		mode = buffs_offset_toggle(canvas),
		controls = {
			buffs_offset_number(canvas, 1, "X"),
			buffs_offset_number(canvas, 2, "Y"),
		},
	}
end

---@param canvas CanvasData
---@return FormSection[]
function DarktideCanvasForm.build(canvas)
	local rows = {}
	for i = 1, #ELEMENTS do
		rows[i] = toggle_row(canvas, ELEMENTS[i])
	end

	rows[#rows + 1] = buffs_offset_group(canvas)

	return {
		{
			key = "darktide",
			title = mod:localize("dt_canvas_title"),
			flat = true,
			rows = rows,
		},
	}
end

mod.hud_studio_darktide_canvas_form = DarktideCanvasForm

return DarktideCanvasForm
