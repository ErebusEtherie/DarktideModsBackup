

---@class DarkLib
---@field movement DL_Movement

---@alias DL_MovementMethod

---@class DL_MovementStateComponent
---@field method DL_MovementMethod
---@field is_crouching boolean
---@field is_dodging boolean
---@field is_effective_dodge boolean
---@field can_crouch boolean
---@field can_exit_crouch boolean
---@field can_jump boolean

---@alias DL_MovementEdgeCallback fun(active: boolean, unit: Unit | nil, dt: number)

---@alias DL_MovementDodgeCallback fun(unit: Unit, is_slide: boolean)

local DODGE_SUCCESS_EVENTS = {
	["wwise/events/player/play_player_dodge_melee_success"] = true,
	["wwise/events/player/play_player_dodge_melee_success_specials"] = true,
}

local EDGE_STATES = { "slide", "dodge", "jump", "crouch", "sprint" }

---@param mod mod
return function(mod)
	local FS_Unit = Unit
	local FS_ScriptUnit = ScriptUnit

	local function ensure_unit()
		FS_Unit = FS_Unit or _G.Unit
		return FS_Unit ~= nil
	end

	local function ensure_script_unit()
		FS_ScriptUnit = FS_ScriptUnit or _G.ScriptUnit
		return FS_ScriptUnit ~= nil
	end

	local MOVING_METHODS = {
		move_fwd = true,
		move_bwd = true,
		sprint = true,
	}

	---@class DL_Movement
	local Movement = {}

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return Unit | nil
	local function resolve_unit(player_or_unit)
		if player_or_unit == nil then
			return mod.dl.player.local_player_unit()
		end

		if type(player_or_unit) == "table" then
			return mod.dl.player.unit(player_or_unit)
		end

		if ensure_unit() and FS_Unit.alive(player_or_unit) then
			return player_or_unit
		end

		return nil
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return DL_MovementStateComponent | nil
	function Movement.component(player_or_unit)
		local unit = resolve_unit(player_or_unit)
		if not unit or not ensure_script_unit() then
			return nil
		end

		local unit_data_extension = FS_ScriptUnit.has_extension(unit, "unit_data_system")
		return unit_data_extension and unit_data_extension:read_component("movement_state") or nil
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return DL_MovementMethod | nil
	function Movement.method(player_or_unit)
		local component = Movement.component(player_or_unit)
		return component and component.method or nil
	end

	---@param method DL_MovementMethod
	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Movement.is_method(method, player_or_unit)
		return Movement.method(player_or_unit) == method
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Movement.is_moving(player_or_unit)
		local method = Movement.method(player_or_unit)
		return method ~= nil and MOVING_METHODS[method] == true
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Movement.is_sprinting(player_or_unit)
		return Movement.method(player_or_unit) == "sprint"
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Movement.is_sliding(player_or_unit)
		return Movement.method(player_or_unit) == "sliding"
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Movement.is_jumping(player_or_unit)
		return Movement.method(player_or_unit) == "jumping"
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Movement.is_falling(player_or_unit)
		return Movement.method(player_or_unit) == "falling"
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Movement.is_airborne(player_or_unit)
		local method = Movement.method(player_or_unit)
		return method == "jumping" or method == "falling"
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Movement.is_idle(player_or_unit)
		return Movement.method(player_or_unit) == "idle"
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Movement.is_crouching(player_or_unit)
		local component = Movement.component(player_or_unit)
		return component ~= nil and component.is_crouching == true
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Movement.is_dodging(player_or_unit)
		local component = Movement.component(player_or_unit)
		return component ~= nil and component.is_dodging == true
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Movement.can_jump(player_or_unit)
		local component = Movement.component(player_or_unit)
		return component ~= nil and component.can_jump == true
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Movement.can_crouch(player_or_unit)
		local component = Movement.component(player_or_unit)
		return component ~= nil and component.can_crouch == true
	end

	---@type table<string, table<number, DL_MovementEdgeCallback>>
	local _edge_hooks = {}
	for _, key in ipairs(EDGE_STATES) do
		_edge_hooks[key] = {}
	end

	---@type table<string, boolean>
	local _prev = {}

	---@param component DL_MovementStateComponent
	local function derive(component)
		local method = component.method
		return {
			slide = method == "sliding",
			dodge = component.is_dodging == true,
			jump = method == "jumping",
			crouch = component.is_crouching == true,
			sprint = method == "sprint",
		}
	end

	---@param key string
	---@param callback DL_MovementEdgeCallback
	local function register_edge(key, callback)
		_edge_hooks[key][#_edge_hooks[key] + 1] = callback
	end

	---@param callback DL_MovementEdgeCallback
	function Movement.on_slide(callback)
		register_edge("slide", callback)
	end

	---@param callback DL_MovementEdgeCallback
	function Movement.on_dodge(callback)
		register_edge("dodge", callback)
	end

	---@param callback DL_MovementEdgeCallback
	function Movement.on_jump(callback)
		register_edge("jump", callback)
	end

	---@param callback DL_MovementEdgeCallback
	function Movement.on_crouch(callback)
		register_edge("crouch", callback)
	end

	---@param callback DL_MovementEdgeCallback
	function Movement.on_sprint(callback)
		register_edge("sprint", callback)
	end

	---@param dt number
	function Movement.tick(dt)
		local unit = mod.dl.player.local_player_unit()
		local component = unit and Movement.component(unit) or nil

		local now
		if component then
			now = derive(component)
		else
			now = { slide = false, dodge = false, jump = false, crouch = false, sprint = false }
			unit = nil
		end

		for i = 1, #EDGE_STATES do
			local key = EDGE_STATES[i]
			local active = now[key]
			if active ~= (_prev[key] or false) then
				_prev[key] = active
				local hooks = _edge_hooks[key]
				for h = 1, #hooks do
					hooks[h](active, unit, dt)
				end
			end
		end
	end

	function Movement.reset()
		for i = 1, #EDGE_STATES do
			_prev[EDGE_STATES[i]] = false
		end
	end

	---@type table<number, DL_MovementDodgeCallback>
	local _effective_dodge_hooks = {}
	local _wwise_hooked = false

	local function register_wwise_hook()
		mod.dl.game_hooks.hook_safe("WwiseWorld", "trigger_resource_event", function(self, file_path)
			if not DODGE_SUCCESS_EVENTS[file_path] then
				return
			end

			local player_unit = mod.dl.player.local_player_unit()
			if not player_unit then
				return
			end

			if mod.dl.player.is_dead(player_unit) or mod.dl.player.is_disabled(player_unit) then
				return
			end

			local is_slide = Movement.is_sliding(player_unit)
			for i = 1, #_effective_dodge_hooks do
				_effective_dodge_hooks[i](player_unit, is_slide)
			end
		end)

		_wwise_hooked = true
	end

	---@param callback DL_MovementDodgeCallback
	function Movement.on_effective_dodge(callback)
		if not _wwise_hooked then
			register_wwise_hook()
		end

		_effective_dodge_hooks[#_effective_dodge_hooks + 1] = callback
	end

	return Movement
end
