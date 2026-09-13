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
		schema_builder = base_path .. "/schema_builder",
		manager = base_path .. "/managers/manager",
		layout_manager = base_path .. "/managers/layout_manager",
	}

	mod:io_dofile(paths.schema_builder)(Module)
	mod:io_dofile(paths.constants)(Module, mod)

	mod:io_dofile(paths.layout_manager)(Module)
	mod:io_dofile(paths.manager)(Module, mod, base_path)

	Module.build_menu = Module.manager.build_menu
	Module.open = Module.manager.open
	Module.close = Module.manager.close
	Module.toggle = Module.manager.toggle
	Module.is_open = Module.manager.is_open

	return Module
end
