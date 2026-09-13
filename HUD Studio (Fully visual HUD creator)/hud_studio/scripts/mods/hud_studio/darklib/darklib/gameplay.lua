---@class DarkLib
---@field gameplay DL_Gameplay

---@param mod mod
return function(mod)
	local FS_Managers = Managers

	local function ensure_managers()
		FS_Managers = FS_Managers or _G.Managers
		return FS_Managers
	end

	---@class DL_Gameplay
	local Gameplay = {}

	local _cached_in_gameplay = false
	local _fired_enter_gameplay_hooks = false

	local _hooks = {
		enter_gameplay_hooks = {},
		leave_gameplay_hooks = {},
		in_gameplay_hooks = {},
	}

	local _in_gameplay_dirty = false

	function Gameplay.on_enter_gameplay(callback)
		_hooks.enter_gameplay_hooks[#_hooks.enter_gameplay_hooks + 1] = callback
	end

	function Gameplay.on_leave_gameplay(callback)
		_hooks.leave_gameplay_hooks[#_hooks.leave_gameplay_hooks + 1] = callback
	end

	function Gameplay.while_in_gameplay(callback)
		local entry = { fn = callback, removed = false }

		entry.evict = function()
			if not entry.removed then
				entry.removed = true
				_in_gameplay_dirty = true
			end
		end

		_hooks.in_gameplay_hooks[#_hooks.in_gameplay_hooks + 1] = entry
		return entry.evict
	end

	local function fire(hooks, ...)
		for i = 1, #hooks do
			hooks[i](...)
		end
	end

	---@alias GameModeName

	---@return GameModeName | nil
	function Gameplay.game_mode_name()
		if not ensure_managers() then
			return nil
		end
		local state = FS_Managers.state
		local game_mode = state and state.game_mode
		return game_mode and game_mode:game_mode_name() or nil
	end

	---@return boolean
	function Gameplay.is_online()
		if not ensure_managers() then
			return false
		end
		return FS_Managers.state and FS_Managers.state.game_session and FS_Managers.state.game_session:is_server()
	end

	---@return boolean
	function Gameplay.is_in_gameplay()
		local name = Gameplay.game_mode_name()

		return name ~= nil and name ~= "hub" and name ~= "prologue_hub"
	end

	---@return boolean
	function Gameplay.is_in_hub()
		local name = Gameplay.game_mode_name()

		return name == "hub" or name == "hub_singleplay" or name == "prologue_hub"
	end

	function Gameplay.tick(dt)
		local in_gameplay = Gameplay.is_in_gameplay()

		if in_gameplay ~= _cached_in_gameplay then

			_cached_in_gameplay = in_gameplay

			if in_gameplay then

				fire(_hooks.enter_gameplay_hooks, false)
				_fired_enter_gameplay_hooks = true

			else

				fire(_hooks.leave_gameplay_hooks)
			end
		end

		if not _fired_enter_gameplay_hooks and in_gameplay then

			fire(_hooks.enter_gameplay_hooks, true)
			_fired_enter_gameplay_hooks = true
		end

		if not in_gameplay then
			return
		end

		local hooks = _hooks.in_gameplay_hooks
		local count = #hooks
		for i = 1, count do
			local entry = hooks[i]
			if not entry.removed then
				entry.fn(dt, entry.evict)
			end
		end

		if _in_gameplay_dirty then
			_in_gameplay_dirty = false

			local write = 0
			for i = 1, #hooks do
				local entry = hooks[i]
				if not entry.removed then
					write = write + 1
					hooks[write] = entry
				end
			end
			for i = #hooks, write + 1, -1 do
				hooks[i] = nil
			end
		end
	end

	function Gameplay.in_gameplay()
		return _cached_in_gameplay
	end

	_cached_in_gameplay = Gameplay.is_in_gameplay()

	return Gameplay
end
