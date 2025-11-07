local mod = get_mod("BuffStackHUD")

mod:register_hud_element({
	class_name = "HudElementStackBuff",
	filename = "BuffStackHUD/scripts/mods/BuffStackHUD/HudElementStackBuff",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
})

mod.last_buff_idx = {}
mod.colors = {}
mod.labels = {}
mod.reserve = {}
mod.emptyslots = {}
mod.stack_font_size = 30
mod.label_font_size = 15
mod.redraw_required = false

local function get_toggles()
	mod.colors = {}
	mod.labels = {}
	local reserve_grp = {}
	for i = 1, mod.buff_max do
		local reserve_name = mod:get("lock_slot_" .. i)
		mod.emptyslots[i] = reserve_name ~= ""
		if mod.emptyslots[i] then
			reserve_grp[reserve_name] = i
			mod.emptyslots[i] = true
		end
	end
	for _, buff_name in ipairs(mod.buff_names) do
		if mod:get("enable_" .. buff_name) then
			mod.colors[buff_name] = mod:get("color_" .. buff_name) or "dark_magenta"
			mod.labels[buff_name] = mod:get("showlabel_" .. buff_name)
			local reserve_idx = reserve_grp[buff_name]
			if reserve_idx then
				mod.reserve[buff_name] = reserve_idx
			end
		end
	end
	for group_name, group in pairs(mod.group_overrides) do
		if mod:get("enable_g_" .. group_name) then
			local reserve_idx = reserve_grp["g_" .. group_name]
			for _, buff_name in ipairs(group.buffs) do
				mod.colors[buff_name] = mod:get("color_g_" .. group_name) or "dark_magenta"
				mod.labels[buff_name] = mod:get("showlabel_g_" .. group_name)
				if reserve_idx then
					mod.reserve[buff_name] = reserve_idx
				end
			end
		end
	end

	local temp_int = mod:get("stack_font_size")
	if mod.stack_font_size ~= temp_int then
		mod.stack_font_size = temp_int
		mod.redraw_required = true
	end

	temp_int = mod:get("label_font_size")
	if mod.label_font_size ~= temp_int then
		mod.label_font_size = temp_int
		mod.redraw_required = true
	end
end

get_toggles()

mod.on_setting_changed = function()
	get_toggles()
end
