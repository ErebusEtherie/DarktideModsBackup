---@param mod mod
return function(mod, path_to_darklib)
	if mod.dl and mod.dl_hud then
		return mod.dl
	end

	path_to_darklib = (path_to_darklib .. "/"):gsub("/+", "/")

	---@class DL_Mod: DMFMod
	---@field dl DarkLib
	---@field dl_hud DarkLibHUD

	---@class DarkLib
	local DarkLib = {
		report = function(library_name, function_name, line_number, message)
			mod:error(
				"[DarkLib | "
					.. library_name
					.. "] Error in "
					.. function_name
					.. " at line "
					.. line_number
					.. ": "
					.. message
			)
		end,
	}

	---@type table<string, string|boolean>
	local _libraries = {
		game_hooks = "darklib/game_hooks",
		fonts = "darklib/fonts",
		str = "darklib/str",
		uv = "darklib/uv",
		data = "darklib/data",
		settings = "darklib/settings",
		loc_helpers = "darklib/loc_helpers",
		colors = "darklib/colors",
		breeds = "darklib/breeds",
		icons = "darklib/icons",
		player = "darklib/player",
		movement = "darklib/movement",
		gameplay = "darklib/gameplay",
		archetypes = "darklib/archetypes",
		on_hit = "darklib/on_hit",
		on_death = "darklib/on_death",
		on_horde_signal = "darklib/on_horde_signal",
		animation = "darklib/animation",
		dps = "darklib/dps",
		damage_poll = "darklib/damage_poll",
		debug = "darklib/debug",
		defs = "darklib/defs",
		file = "darklib/file",
		log = "darklib/log",
		time = "darklib/time",
		md = "darklib/md",
	}

	---@class DarkLibHUD
	local DarkLibHUD = {

		__hud_modules = {},
		report = function(library_name, function_name, message)
			mod:error("[DarkLibHUD | " .. library_name .. "] Error in " .. function_name .. "() : " .. message)
		end,
	}

	---@type table<string, string|boolean>
	local _hud_libraries = {
		mission_speaker = "darklib_hud/mission_speaker/mission_speaker",
		marker = "darklib_hud/markers/markers",
		settings_menu = "darklib_hud/settings_menu/settings_menu",
		mod_menu = "darklib_hud/mod_menu/mod_menu",
	}

	local function report_load_error(lib_type, name)
		local inst = lib_type == "hud" and DarkLibHUD or DarkLib
		inst.report(
			"darklib.lua",
			"load_library",
			"Requested library " .. name .. " does not exist or is not registered. Maybe you wrote a typo?"
		)
	end

	local function load_library(lib_type, ref, name)

		local lib_table = lib_type == "hud" and _hud_libraries or _libraries
		local lib_relative_path = lib_table[name]

		if lib_relative_path == false or type(lib_relative_path) ~= "string" then
			report_load_error(lib_type, name)
		end

		local lib_path = path_to_darklib .. lib_relative_path

		if lib_relative_path ~= false then
			local library = mod:io_dofile(lib_path)
			if library then
				local built = library(mod, lib_path)

				if built == nil then
					local inst = lib_type == "hud" and DarkLibHUD or DarkLib
					inst.report("darklib.lua", "load_library", "Library " .. name .. " declined to build.")
					return nil
				end

				ref[name] = built
				return built
			else
				report_load_error(lib_type, name)
				lib_table[name] = false 
			end
		end
		return nil
	end

	setmetatable(DarkLib, {
		__index = function(self, name)
			return load_library("lib", self, name)
		end,
	})

	mod.dl = DarkLib

	setmetatable(DarkLibHUD, {
		__index = function(self, name)
			return load_library("hud", self, name)
		end,
	})

	mod.dl_hud = DarkLibHUD

	return {
		DarkLib,
		DarkLibHUD,
	}
end
