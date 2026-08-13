---@class DarkLib
---@field on_hit DL_OnHit

---@class DL_HitEvent
---@field attacked_unit Unit                  The unit that was hit.
---@field attacking_unit Unit                 The unit that dealt the hit.
---@field attacking_player DL_PlayerObject | nil  Resolved once from attacking_unit; nil for non-player (minion / DoT) attackers. Reuse this instead of calling player.from_unit again.
---@field attack_direction Vector3
---@field hit_world_position Vector3 | nil    nil for DoT / non-positional damage.
---@field hit_weakspot boolean
---@field damage number
---@field attack_result "damaged" | "died"
---@field attack_type "melee" | "ranged" | nil
---@field damage_efficiency FS_DamageEfficiency
---@field damage_profile FS_DamageProfile | nil
---@field damage_profile_name string | nil
---@field is_critical_strike boolean

---@param mod mod
return function(mod)
	---@class DL_OnHit
	local OnHit = {}

	---@type table<"on_damaged_hooks", table<number, fun(event: DL_HitEvent)>>
	local _hooks = {
		on_damaged_hooks = {},
	}

	---@type table<string, {

	local _stats_per_account = {}
	local _tracking_stats = false

	local _hooked_game = false

	local PERSIST_SYNC_INTERVAL = 2 
	local _persist = nil 
	local _persist_accounts = {} 
	local _persist_sync_timer = 0

	local function ensure_persist()
		_persist = _persist or mod:persistent_table("darklib_on_hit_stats", {})
		return _persist
	end

	---@return DL_HitEvent
	local function make_event(
		damage_profile,
		attacked_unit,
		attacking_unit,
		attack_direction,
		hit_world_position,
		hit_weakspot,
		damage,
		attack_result,
		attack_type,
		damage_efficiency,
		is_critical_strike,
		attacking_player
	)
		return {
			attacked_unit = attacked_unit,
			attacking_unit = attacking_unit,
			attacking_player = attacking_player,
			attack_direction = attack_direction,
			hit_world_position = hit_world_position,
			hit_weakspot = hit_weakspot or false,
			damage = damage or 0,
			attack_result = attack_result,
			attack_type = attack_type,
			damage_efficiency = damage_efficiency,
			damage_profile = damage_profile,
			damage_profile_name = damage_profile and damage_profile.name or nil,
			is_critical_strike = is_critical_strike or false,
		}
	end

	---@type FS_HookCallback_AttackReportManager_AddAttackResult
	local function on_hit(
		self,
		damage_profile,
		attacked_unit,
		attacking_unit,
		attack_direction,
		hit_world_position,
		hit_weakspot,
		damage,
		attack_result,
		attack_type,
		damage_efficiency,
		is_critical_strike
	)
		local died = attack_result == "died"

		if not died and not (damage and damage > 0) then
			return
		end

		local attacking_player = mod.dl.player.from_unit(attacking_unit)

		if _tracking_stats and attacking_player then
			local stats_table = _stats_per_account[attacking_player:account_id()]

			if stats_table then

				stats_table.damage_total = stats_table.damage_total + damage
				stats_table.weakspot_hits = (hit_weakspot and stats_table.weakspot_hits + 1)
					or stats_table.weakspot_hits

				if died then
					stats_table.kills = (died and stats_table.kills + 1) or stats_table.kills
					stats_table.weakspot_kills = (hit_weakspot and stats_table.weakspot_kills + 1)
						or stats_table.weakspot_kills
				end
			end
		end

		local event = make_event(
			damage_profile,
			attacked_unit,
			attacking_unit,
			attack_direction,
			hit_world_position,
			hit_weakspot,
			damage,
			attack_result,
			attack_type,
			damage_efficiency,
			is_critical_strike,
			attacking_player
		)

		for i = 1, #_hooks.on_damaged_hooks do
			_hooks.on_damaged_hooks[i](event)
		end
	end

	local function register_game_hook()
		mod.dl.game_hooks.hook_safe(CLASS.AttackReportManager, "add_attack_result", on_hit)
		_hooked_game = true
	end

	function OnHit.track_stats_for(player, opts)
		opts = opts or {}
		if player and player.account_id then
			local account_id = player:account_id()

			if _stats_per_account[account_id] then
				return
			end

			local stats = {
				kills = 0,
				damage_total = 0,
				weakspot_hits = 0,
				weakspot_kills = 0,
			}

			if opts.persist then
				local persist = ensure_persist()
				local saved = persist[account_id]

				if saved then
					stats.kills = saved.kills or 0
					stats.damage_total = saved.damage_total or 0
					stats.weakspot_hits = saved.weakspot_hits or 0
					stats.weakspot_kills = saved.weakspot_kills or 0
				else
					persist[account_id] = {
						kills = 0,
						damage_total = 0,
						weakspot_hits = 0,
						weakspot_kills = 0,
					}
				end

				_persist_accounts[account_id] = true
			end

			_stats_per_account[account_id] = stats

			_tracking_stats = true
		end
	end

	function OnHit.tick(dt)
		if not _persist then
			return
		end

		_persist_sync_timer = _persist_sync_timer + dt

		if _persist_sync_timer < PERSIST_SYNC_INTERVAL then
			return
		end

		_persist_sync_timer = _persist_sync_timer - PERSIST_SYNC_INTERVAL

		for account_id in pairs(_persist_accounts) do
			local stats = _stats_per_account[account_id]
			local slot = _persist[account_id]

			if stats and slot then
				slot.kills = stats.kills
				slot.damage_total = stats.damage_total
				slot.weakspot_hits = stats.weakspot_hits
				slot.weakspot_kills = stats.weakspot_kills
			end
		end
	end

	function OnHit.reset_stats()
		for _, stats in pairs(_stats_per_account) do
			stats.kills = 0
			stats.damage_total = 0
			stats.weakspot_hits = 0
			stats.weakspot_kills = 0
		end

		if _persist then
			for account_id in pairs(_persist_accounts) do
				local slot = _persist[account_id]

				if slot then
					slot.kills = 0
					slot.damage_total = 0
					slot.weakspot_hits = 0
					slot.weakspot_kills = 0
				end
			end
		end

		_persist_sync_timer = 0
	end

	---@param attacker "controlling player" | "human players" | "enemies" | "everything"
	---@param callback fun(event: DL_HitEvent)
	function OnHit.execute(attacker, callback)
		if not _hooked_game then
			register_game_hook()
		end

		local condition = nil

		if attacker == "controlling player" then
			condition = function(event)
				return mod.dl.player.local_player_unit() == event.attacking_unit
			end
		elseif attacker == "human players" then
			condition = function(event)
				local player = event.attacking_player
				return player ~= nil and player:is_human_controlled()
			end
		elseif attacker == "enemies" then
			condition = function(event)
				return mod.dl.breeds.is_minion(event.attacking_unit)
			end
		end

		_hooks.on_damaged_hooks[#_hooks.on_damaged_hooks + 1] = function(event)
			if condition ~= nil and not condition(event) then
				return
			end

			callback(event)
		end
	end

	function OnHit.get_stats_for(player)
		local index = player and player.account_id and player:account_id()
		return index and _stats_per_account[index]
	end

	return OnHit
end
