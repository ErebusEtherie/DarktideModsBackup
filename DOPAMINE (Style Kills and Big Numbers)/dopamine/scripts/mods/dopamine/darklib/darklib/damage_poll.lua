

local ScriptUnit = ScriptUnit
local Unit = Unit
local Managers = Managers

---@class DarkLib
---@field damage_poll DL_DamagePoll

---@param mod mod
return function(mod)
	if mod.damage_poll then
		return mod.damage_poll
	end

	---@class DL_DamagePollState
	---@field health? number Current health fraction (nil if unreadable).
	---@field toughness? number Current toughness fraction (nil if unreadable).
	---@field health_lost number Health fraction lost this tick.
	---@field toughness_lost number Toughness fraction lost this tick.
	---@field lost number Combined fraction lost this tick.

	---@alias DamagePollEvent "damage_taken"
	---@alias DamagePollHook fun(state: DL_DamagePollState, poll: DL_DamagePoll)

	---@class DL_DamagePoll
	---@field last_health? number Health fraction seen on the previous tick.
	---@field last_toughness? number Toughness fraction seen on the previous tick.
	---@field hooks table<DamagePollEvent, DamagePollHook[]> Registered hooks per event.
	local DamagePoll = {}
	DamagePoll.__index = DamagePoll

	---@return DL_DamagePoll
	function DamagePoll.new()
		local self = setmetatable({}, DamagePoll)

		self.last_health = nil
		self.last_toughness = nil
		self.hooks = {}

		return self
	end

	local _shared = {}

	---@param key string
	---@return DL_DamagePoll
	function DamagePoll.shared(key)
		local existing = _shared[key]
		if existing then
			return existing
		end

		local poll = DamagePoll.new()
		_shared[key] = poll
		return poll
	end

	---@return number?
	function DamagePoll:health()
		return self.last_health
	end

	---@return number?
	function DamagePoll:toughness()
		return self.last_toughness
	end

	---@param event DamagePollEvent
	---@param hook DamagePollHook
	function DamagePoll:on(event, hook)
		local list = self.hooks[event]
		if not list then
			list = {}
			self.hooks[event] = list
		end
		list[#list + 1] = hook
	end

	---@param hook DamagePollHook
	function DamagePoll:on_damage_taken(hook)
		self:on("damage_taken", hook)
	end

	---@param event DamagePollEvent
	---@param state DL_DamagePollState
	function DamagePoll:emit(event, state)
		local list = self.hooks[event]
		if not list then
			return
		end
		for i = 1, #list do
			list[i](state, self)
		end
	end

	function DamagePoll:reset()
		self.last_health = nil
		self.last_toughness = nil
	end

	---@return any? player_unit
	function DamagePoll:resolve_unit()
		local player_manager = Managers.player
		local local_player = player_manager and player_manager:local_player_safe(1)
		return local_player and local_player.player_unit or nil
	end

	function DamagePoll:tick()
		local player_unit = self:resolve_unit()

		if not player_unit or not Unit.alive(player_unit) then
			self:reset()
			return
		end

		local health_ext = ScriptUnit.has_extension(player_unit, "health_system")
		local health = health_ext and health_ext:current_health_percent() or nil

		local toughness_ext = ScriptUnit.has_extension(player_unit, "toughness_system")
		local toughness = toughness_ext
				and toughness_ext.current_toughness_percent
				and toughness_ext:current_toughness_percent()
			or nil

		local last_health = self.last_health
		local last_toughness = self.last_toughness

		local health_lost = 0
		if health and last_health and health < last_health then
			health_lost = last_health - health
		end

		local toughness_lost = 0
		if toughness and last_toughness and toughness < last_toughness then
			toughness_lost = last_toughness - toughness
		end

		self.last_health = health
		self.last_toughness = toughness

		local lost = health_lost + toughness_lost
		if lost > 0 then
			self:emit("damage_taken", {
				health = health,
				toughness = toughness,
				health_lost = health_lost,
				toughness_lost = toughness_lost,
				lost = lost,
			})
		end
	end

	mod.damage_poll = DamagePoll

	return mod.damage_poll
end
