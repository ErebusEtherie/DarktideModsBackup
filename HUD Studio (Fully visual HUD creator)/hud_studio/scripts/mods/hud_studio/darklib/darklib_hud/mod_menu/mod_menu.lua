---@param mod DL_Mod
---@param module_path string full io_dofile path to this entry file
return function(mod, module_path)

	if not mod or type(mod) ~= "table" or not mod.get_name then
		return
	end

	if not mod:is_enabled() then
		return
	end

	local function loc_or(key, fallback)
		local text = mod:localize(key)
		if not text or text == "<" .. key .. ">" then
			return fallback
		end
		return text
	end

	local Module = {
		bootup_print = nil,
	}

	local base_path = module_path:gsub("/[^/]+$", "")

	local paths = {
		bootup_print = base_path .. "/overlay/bootup_print",
		constants = base_path .. "/constants",
		presentation = base_path .. "/hud/presentation",
		hud_definitions = base_path .. "/hud/hud_definitions",
		overlay_definitions = base_path .. "/overlay/definitions",
		manager = base_path .. "/managers/manager",
		flappy_constants = base_path .. "/flappy/constants",
		flappy_definitions = base_path .. "/flappy/definitions",
	}

	mod:io_dofile(paths.bootup_print)(Module, mod)

	mod:io_dofile(paths.constants)(Module, mod)
	mod:io_dofile(paths.presentation)(Module)
	mod:io_dofile(paths.hud_definitions)(Module, mod)

	mod:io_dofile(paths.overlay_definitions)(Module, mod)
	Module.overlay_element_path = base_path .. "/overlay/element"

	mod.dl_hud.__hud_modules["mod_menu"] = Module

	mod:io_dofile(paths.manager)(Module, mod, base_path)

	mod:io_dofile(paths.flappy_constants)(Module, mod)
	mod:io_dofile(paths.flappy_definitions)(Module, mod)
	Module.manager.add_page({
		id = "flappy",
		label = loc_or("flappy_module", "COGITATOR REVERIE"),
		element_path = base_path .. "/flappy/element",
		element_context = { mod_name = mod:get_name() },
		secret = true,
	})

	Module.add_page = Module.manager.add_page
	Module.add_aside_item = Module.manager.add_aside_item
	Module.open = Module.manager.open
	Module.close = Module.manager.close
	Module.toggle = Module.manager.toggle
	Module.is_open = Module.manager.is_open
	Module.set_active_page = Module.manager.set_active_page
	Module.active_page_id = Module.manager.active_page_id

	return Module
end
