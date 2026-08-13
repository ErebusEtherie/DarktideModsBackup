---@param mod DL_Mod
---@param module_path string full io_dofile path to this entry file
return function(mod, module_path)

	if not mod or type(mod) ~= "table" or not mod.get_name then
		return
	end

	if not mod:is_enabled() then
		return
	end

	local Module = {}

	local base_path = module_path:gsub("/[^/]+$", "")

	local paths = {
		constants = base_path .. "/constants",
		manager = base_path .. "/managers/manager",
		presentation_manager = base_path .. "/managers/presentation_manager",
		hud_definitions = base_path .. "/hud/hud_definitions",
		hud_instance = base_path .. "/hud/hud_instance",
	}

	mod:io_dofile(paths.constants)(Module)

	mod:io_dofile(paths.manager)(Module)

	mod:io_dofile(paths.presentation_manager)(Module)

	Module.manager.hook_native_speaker_system(mod)

	mod.dl.gameplay.while_in_gameplay(function(dt)
		Module.manager.poll_native_speaker_state(dt)
	end)

	---@type DLH_MissionSpeakerHudDefinitions
	local Definitions = mod:io_dofile(paths.hud_definitions)(Module)
	Module.hud_definitions = Definitions

	local class_name = "DarkLibHudMissionSpeaker_" .. mod:get_name()

	mod.dl_hud.__hud_modules["mission_speaker"] = Module

	mod.__dl_registered_hud_elements = mod.__dl_registered_hud_elements or {}
	if not mod.__dl_registered_hud_elements[class_name] then
		mod.__dl_registered_hud_elements[class_name] = true
		mod:register_hud_element({
			class_name = class_name,
			filename = paths.hud_instance,
			use_hud_scale = true,
			visibility_groups = {
				"alive",
			},
			validation_function = function()
				return mod.dl.gameplay.is_in_gameplay()
			end,
			context = {
				mod_name = mod:get_name(),
				class_name = class_name,
			},
		})
	end

	Module.configure = Module.manager.configure
	Module.set_speaker = Module.manager.set_speaker
	Module.set_subtitle = Module.manager.set_subtitle
	Module.set_visible = Module.manager.set_visible
	Module.cycle_speaker = Module.manager.cycle_active_speakers
	Module.reset = Module.manager.reset
	Module.toggle_native = Module.manager.toggle_native_hud

	return Module
end
