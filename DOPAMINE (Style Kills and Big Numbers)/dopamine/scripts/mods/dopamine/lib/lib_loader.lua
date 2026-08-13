---@param mod mod
return function(mod, project_path)
	if mod.lib and mod.core then
		return mod.lib
	end

	local assume_path = mod:get_name() .. "/scripts/mods/" .. mod:get_name() .. "/"

	---@alias memo_fn fun<T>(self : mod, lib : T, path: mod_path_short, ...): T

	---@generic T
	---@type memo_fn<T>
	mod.lib = function(self, lib, path, ...)
		return lib or mod:io_dofile(project_path or assume_path .. path)(self, ...)
	end

	---@generic T
	---@type memo_fn<T>
	mod.core = function(self, lib, path, ...)
		return lib or mod:io_dofile(project_path or assume_path .. path)
	end
end
