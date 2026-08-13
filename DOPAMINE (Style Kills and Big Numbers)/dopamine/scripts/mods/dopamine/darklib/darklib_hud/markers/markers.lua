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
		animate = base_path .. "/animate/animate",
		manager = base_path .. "/managers/manager",
		hud_definitions = base_path .. "/hud/hud_definitions",
		hud_instance = base_path .. "/hud/hud_instance",
	}

	mod:io_dofile(paths.animate)(Module)

	mod:io_dofile(paths.manager)(Module, mod)

	---@type DLH_MarkerHudDefinitions
	local Definitions = mod:io_dofile(paths.hud_definitions)(Module)
	Module.hud_definitions = Definitions

	local class_name = "DarkLibHudMarker_" .. mod:get_name()

	mod.dl_hud.__hud_modules["marker"] = Module

	mod.__dl_registered_hud_elements = mod.__dl_registered_hud_elements or {}
	if not mod.__dl_registered_hud_elements[class_name] then
		mod.__dl_registered_hud_elements[class_name] = true
		mod:register_hud_element({
			class_name = class_name,
			filename = paths.hud_instance,
			use_hud_scale = false,
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

	Module.register_style = Module.manager.register_style
	Module.fire = Module.manager.fire
	Module.has_style = Module.manager.has_style
	Module.remove = Module.manager.remove
	Module.is_active = Module.manager.is_active
	Module.clear = Module.manager.clear

	return Module
end
