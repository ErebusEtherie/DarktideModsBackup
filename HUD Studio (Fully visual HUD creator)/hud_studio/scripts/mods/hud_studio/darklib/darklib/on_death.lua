

---@class DarkLib
---@field on_death DL_OnDeath

---@alias DL_OnDeath_VictimFilter "players" | "enemies" | "anyone"

---@alias DL_OnDeath_Kind "died" | "knocked_down"

---@class DL_DeathEvent
---@field victim_unit Unit                     The unit that died / went down.
---@field attacker_unit Unit | nil             The killing unit, if known.
---@field hit_world_position Vector3 | nil
---@field hit_weakspot boolean
---@field victim_is_player boolean
---@field attacker_is_player boolean
---@field victim_player DL_PlayerObject | nil  Player object if the victim is a player.
---@field attacker_player DL_PlayerObject | nil
---@field victim_breed FatsharkBreedData | nil Breed data if the victim is a minion.
---@field kind DL_OnDeath_Kind
---@field damage number
---@field is_critical_strike boolean
---@field damage_profile FS_DamageProfile | nil
---@field attack_type "melee" | "ranged" | nil

---@alias DL_OnDeath_Callback fun(event: DL_DeathEvent)

---@param mod mod
return function(mod)
	---@class DL_OnDeath
	local OnDeath = {}

	---@type table<number, { filter: DL_OnDeath_VictimFilter, callback: DL_OnDeath_Callback }>
	local _hooks = {}

	---@type table<string, DL_OnDeath_Kind | nil>
	local _player_state = {}

	local _subscribed = false

	---@param event DL_DeathEvent
	local function dispatch(event)
		for i = 1, #_hooks do
			local entry = _hooks[i]
			local filter = entry.filter
			local matches = filter == "anyone"
				or (filter == "players" and event.victim_is_player)
				or (filter == "enemies" and not event.victim_is_player)

			if matches then
				entry.callback(event)
			end
		end
	end

	---@return DL_DeathEvent
	local function make_event(
		kind,
		attacked_unit,
		attacking_unit,
		hit_world_position,
		hit_weakspot,
		damage,
		is_critical_strike,
		damage_profile,
		attack_type
	)
		local victim_player = mod.dl.player.from_unit(attacked_unit)
		local attacker_player = mod.dl.player.from_unit(attacking_unit)

		return {
			victim_unit = attacked_unit,
			attacker_unit = attacking_unit,
			victim_is_player = victim_player ~= nil,
			attacker_is_player = attacker_player ~= nil,
			hit_world_position = hit_world_position,
			hit_weakspot = hit_weakspot or false,
			victim_player = victim_player,
			attacker_player = attacker_player,
			victim_breed = victim_player == nil and mod.dl.breeds.data_from_unit(attacked_unit) or nil,
			kind = kind,
			damage = damage or 0,
			is_critical_strike = is_critical_strike or false,
			damage_profile = damage_profile,
			attack_type = attack_type,
		}
	end

	---@param unit Unit
	---@return DL_OnDeath_Kind | nil
	local function player_kind(unit)
		if mod.dl.player.is_dead(unit) then
			return "died"
		end
		if mod.dl.player.is_knocked_down(unit) then
			return "knocked_down"
		end
		return nil
	end

	---@param event DL_HitEvent
	local function on_damaged(event)
		local attacked_unit = event.attacked_unit

		if not attacked_unit then
			return
		end

		local victim_player = mod.dl.player.from_unit(attacked_unit)

		if victim_player then

			local account_id = victim_player:account_id()
			if not account_id then
				return
			end

			local kind = player_kind(attacked_unit)

			if kind == nil then
				_player_state[account_id] = nil
				return
			end

			if _player_state[account_id] == kind then
				return
			end
			_player_state[account_id] = kind

			dispatch(
				make_event(
					kind,
					attacked_unit,
					event.attacking_unit,
					event.hit_world_position,
					event.hit_weakspot,
					event.damage,
					event.is_critical_strike,
					event.damage_profile,
					event.attack_type
				)
			)
			return
		end

		if event.attack_result == "died" then
			dispatch(
				make_event(
					"died",
					attacked_unit,
					event.attacking_unit,
					event.hit_world_position,
					event.hit_weakspot,
					event.damage,
					event.is_critical_strike,
					event.damage_profile,
					event.attack_type
				)
			)
		end
	end

	---@param victims DL_OnDeath_VictimFilter
	---@param callback DL_OnDeath_Callback
	function OnDeath.execute(victims, callback)

		if not _subscribed then
			mod.dl.on_hit.execute("everything", on_damaged)
			_subscribed = true
		end

		_hooks[#_hooks + 1] = { filter = victims, callback = callback }
	end

	return OnDeath
end
