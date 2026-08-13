---@type mod
local mod = get_mod("dopamine")

if mod.hud_registration then
	return mod.hud_registration
end

mod:register_hud_element({
	class_name = "HudFuryMeter",
	filename = "dopamine/scripts/mods/dopamine/hud/HudFuryMeter",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
	validation_function = function(params)
		return mod.dl.gameplay.in_gameplay()
	end,
})

mod:register_hud_element({
	class_name = "HudStyleMeter",
	filename = "dopamine/scripts/mods/dopamine/hud/HudStyleMeter",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
	validation_function = function(params)
		return mod.dl.gameplay.in_gameplay()
	end,
})

mod:register_hud_element({
	class_name = "HudTaskTrack",
	filename = "dopamine/scripts/mods/dopamine/hud/HudTaskTrack",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
	validation_function = function(params)
		return mod.dl.gameplay.in_gameplay()
	end,
})

mod:register_hud_element({
	class_name = "HudStatChart",
	filename = "dopamine/scripts/mods/dopamine/hud/HudStatChart",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
	validation_function = function(params)
		return mod.dl.gameplay.in_gameplay()
	end,
})

mod:register_hud_element({
	class_name = "HudLayoutDebug",
	filename = "dopamine/scripts/mods/dopamine/hud/HudLayoutDebug",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
	validation_function = function(params)
		return mod.dl.gameplay.in_gameplay()
	end,
})

mod:register_hud_element({
	class_name = "HudMarginEditor",
	filename = "dopamine/scripts/mods/dopamine/hud/HudMarginEditor",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
	validation_function = function(params)
		return mod.dl.gameplay.in_gameplay()
	end,
})

mod.__toggle_margin_editor = function(self, is_pressed)
	if is_pressed == false then
		return
	end
	mod.margin_editor_active = not mod.margin_editor_active
end

local HudRegistration = {}

mod.hud_registration = HudRegistration

return HudRegistration
