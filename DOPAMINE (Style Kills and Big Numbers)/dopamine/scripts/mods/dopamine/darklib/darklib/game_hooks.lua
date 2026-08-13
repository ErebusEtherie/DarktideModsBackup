

---@class DarkLib
---@field game_hooks DL_GameHooks

---@alias DL_GameHookSafeCallback fun(self: any, ...: any)
---@alias DL_GameHookRequireCallback fun(instance: unknown): ...
---@alias DL_GameHookWrapCallback fun(next: fun(...): any, self: any, ...: any): any

---@class DL_HookHandle
---@field enable fun()
---@field disable fun()
---@field remove fun()

---@class DL_GameHooks
---@field hook_safe fun(obj: string|table, method: string, fn: DL_GameHookSafeCallback): DL_HookHandle
---@field hook_require fun(obj_str: string, fn: DL_GameHookRequireCallback): DL_HookHandle
---@field hook fun(obj: string|table, method: string, fn: DL_GameHookWrapCallback): DL_HookHandle

---@param mod mod
return function(mod)
	---@class DL_GameHooks
	local GameHooks = {}

	local registry = {}

	local NOOP_HANDLE = {
		enable = function() end,
		disable = function() end,
		remove = function() end,
	}

	local function install_safe_hook(entry, obj, method)
		mod:hook_safe(obj, method, function(self, ...)
			local subs = entry.subs
			for i = 1, #subs do
				local sub = subs[i]
				if sub.active then
					local ok, err = pcall(sub.fn, self, ...)
					if not ok then
						local info = debug.getinfo(sub.fn, "S")
						mod.dl.report(
							"game_hooks",
							"hook_safe dispatch",
							info and info.linedefined or 0,
							"subscriber for '" .. tostring(method) .. "' errored: " .. tostring(err)
						)
					end
				end
			end
		end)
	end

	local function install_require_hook(entry, obj_str)
		mod:echo("hook require on " .. obj_str)
		mod:hook_require(obj_str, function(instance)
			local subs = entry.subs
			for i = 1, #subs do
				local sub = subs[i]
				if sub.active then
					local ok, err = pcall(sub.fn, instance)
					if not ok then
						local info = debug.getinfo(sub.fn, "S")
						mod.dl.report(
							"game_hooks",
							"hook_require dispatch",
							info and info.linedefined or 0,
							"subscriber for '" .. tostring(obj_str) .. "' errored: " .. tostring(err)
						)
					end
				end
			end
		end)
	end

	local function install_wrap_hook(entry, obj, method)
		mod:hook(obj, method, function(dmf_func, ...)
			local subs = entry.subs

			local function invoke(i, ...)
				while i <= #subs and not subs[i].active do
					i = i + 1
				end
				if i > #subs then
					return dmf_func(...)
				end
				local sub = subs[i]
				local function next_fn(...)
					return invoke(i + 1, ...)
				end
				return sub.fn(next_fn, ...)
			end

			return invoke(1, ...)
		end)
	end

	---@param kind "safe"|"wrap"|"require"
	local function entry_for(obj, method, kind)
		local entry = nil

		if kind == "require" then
			entry = registry[obj]
		else
			registry[obj] = registry[obj] or {}
			entry = registry[obj][method]
		end

		if not entry then
			entry = { kind = kind, subs = {} }

			if kind == "require" then
				registry[obj] = entry
			else
				registry[obj][method] = entry
			end

			if kind == "safe" then
				install_safe_hook(entry, obj, method)
			elseif kind == "wrap" then
				install_wrap_hook(entry, obj, method)
			elseif kind == "require" then
				install_require_hook(entry, obj)
			end

			return entry
		end

		if entry.kind ~= kind then

			local caller = debug.getinfo(3, "l")
			mod.dl.report(
				"game_hooks",
				"subscribe",
				caller and caller.currentline or 0,
				"'"
					.. tostring(method)
					.. "' is already owned by a '"
					.. entry.kind
					.. "' hook; cannot add a '"
					.. kind
					.. "' subscriber (DMF allows only one hook per function per mod)."
			)
			return nil
		end

		return entry
	end

	---@param entry table
	---@param sub table
	---@return DL_HookHandle
	local function make_handle(entry, sub)
		return {
			enable = function()
				sub.active = true
			end,
			disable = function()
				sub.active = false
			end,
			remove = function()
				local subs = entry.subs
				for i = #subs, 1, -1 do
					if subs[i] == sub then
						table.remove(subs, i)
						break
					end
				end
			end,
		}
	end

	---@param obj string|table
	---@param method string
	---@param fn DL_GameHookSafeCallback
	---@return DL_HookHandle
	function GameHooks.hook_safe(obj, method, fn)
		local entry = entry_for(obj, method, "safe")
		if not entry then
			return NOOP_HANDLE
		end

		local sub = { fn = fn, active = true }
		entry.subs[#entry.subs + 1] = sub
		return make_handle(entry, sub)
	end

	---@param obj string|table
	---@param method string
	---@param fn DL_GameHookWrapCallback
	---@return DL_HookHandle
	function GameHooks.hook(obj, method, fn)
		local entry = entry_for(obj, method, "wrap")
		if not entry then
			return NOOP_HANDLE
		end

		local sub = { fn = fn, active = true }
		entry.subs[#entry.subs + 1] = sub
		return make_handle(entry, sub)
	end

	---@param obj_str string
	---@param fn DL_GameHookRequireCallback
	---@return DL_HookHandle
	function GameHooks.hook_require(obj_str, fn)
		local entry = entry_for(obj_str, nil, "require")
		if not entry then
			return NOOP_HANDLE
		end

		local sub = { fn = fn, active = true }
		entry.subs[#entry.subs + 1] = sub
		return make_handle(entry, sub)
	end

	return GameHooks
end
