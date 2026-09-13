---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_state then
	return mod.hud_studio_player_state
end

local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")
local WeaponTemplates = mod:original_require("scripts/settings/equipment/weapon_templates/weapon_templates")
local Party = mod:core(mod.hud_studio_player_party, "sources/player/party")
local Movement = mod.dl.movement
local Player = mod.dl.player

local ATTACK_ACTION_KINDS = {
	sweep = true,
	windup = true,
	push = true,
	melee_explosive = true,
	shoot_hit_scan = true,
	shoot_pellets = true,
	shoot_projectile = true,
	spawn_projectile = true,
	throw_grenade = true,
	weapon_throw = true,
	charge = true,
	charge_ammo = true,
	chain_lightning = true,
	flamer_gas = true,
	flamer_gas_burst = true,
	damage_target = true,
	overload_charge = true,
	overload_explosion = true,
	trigger_explosion = true,
}

---@param unit Unit
---@return boolean attacking, boolean blocking
local function read_combat(unit)
	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	if not unit_data then
		return false, false
	end

	local attacking = false
	local weapon_action = unit_data:read_component("weapon_action")
	local action_name = weapon_action and weapon_action.current_action_name or "none"
	if action_name ~= "none" then
		local weapon_template = WeaponTemplates[weapon_action.template_name]
		local action_settings = weapon_template and weapon_template.actions[action_name]
		attacking = action_settings ~= nil and ATTACK_ACTION_KINDS[action_settings.kind] == true
	end

	local block = unit_data:read_component("block")
	local blocking = block ~= nil and block.is_blocking == true

	local alternate_fire = unit_data:read_component("alternate_fire")
	local aiming = alternate_fire ~= nil and alternate_fire.is_active == true

	return attacking, blocking, aiming
end

---@param player DL_PlayerObject
---@return boolean
local function is_bot(player)
	local ok, human_controlled = pcall(player.is_human_controlled, player)
	if not ok then
		return false
	end
	return human_controlled == false
end

---@param player DL_PlayerObject
---@return boolean
local function is_speaking(player)
	local Managers = _G.Managers
	local chat_manager = Managers and Managers.chat or nil
	if not chat_manager then
		return false
	end

	local ok, account_id = pcall(Player.account_id, player)
	if not ok or type(account_id) ~= "string" or account_id == "" then
		return false
	end

	local sessions_ok, sessions = pcall(chat_manager.sessions, chat_manager)
	if not sessions_ok or type(sessions) ~= "table" then
		return false
	end

	for _, session in pairs(sessions) do
		local participants = type(session) == "table" and session.participants or nil
		if type(participants) == "table" then
			for _, participant in pairs(participants) do
				if participant.account_id == account_id and participant.is_speaking then
					return true
				end
			end
		end
	end

	return false
end

---@param player DL_PlayerObject | nil
---@param hogtied boolean
---@return number
local function read_seconds_until_rescuable(player, hogtied)
	if not player or hogtied then
		return 0
	end

	local Managers = _G.Managers
	local time_manager = Managers and Managers.time or nil
	local game_mode = Managers and Managers.state and Managers.state.game_mode or nil

	if not time_manager or not game_mode or not time_manager:has_timer("gameplay") then
		return 0
	end

	local ok, ready_time = pcall(game_mode.player_time_until_spawn, game_mode, player)
	if not ok or not ready_time then
		return 0
	end

	return math.max(0, ready_time - time_manager:time("gameplay"))
end

---@param unit Unit | nil
---@return number count, number others
local function read_coherency(unit)
	if not unit then
		return 0, 0
	end

	local coherency_extension = ScriptUnit.has_extension(unit, "coherency_system")
	if not coherency_extension then
		return 0, 0
	end

	local count = coherency_extension:num_units_in_coherency() or 0

	return count, math.max(0, count - 1)
end

---@type PlayerField
local Field = {
	fields = {
		state = {
			exists = DataTypes.field("boolean", "[true/false] whether the party slot is occupied"),
			dead = DataTypes.field("boolean", "[true/false] whether an occupant is dead"),
			alive = DataTypes.field("boolean", "[true/false] whether an occupant is alive"),
			seconds_until_rescuable = DataTypes.field(
				"number",
				"[0..n] [seconds] until player is rescuable; 0 = rescuable now"
			),

			disabled = DataTypes.field("boolean", "[true/false] whether player is in any disabled state"),
			requires_help = DataTypes.field("boolean", "[true/false] whether an ally has to intervene"),
			downed = DataTypes.field("boolean", "[true/false] whether player is knocked down, awaiting a revive"),
			hogtied = DataTypes.field("boolean", "[true/false] whether player is captured, awaiting a rescue"),
			ledge_hanging = DataTypes.field("boolean", "[true/false] whether player is hanging from a ledge"),
			pounced = DataTypes.field("boolean", "[true/false] whether a hound is pinning the player"),
			netted = DataTypes.field("boolean", "[true/false] whether a trapper net is holding the player"),
			grabbed = DataTypes.field("boolean", "[true/false] whether player is grabbed by a Mutant charge"),

			sprinting = DataTypes.field("boolean", "[true/false] whether player is sprinting"),
			sliding = DataTypes.field("boolean", "[true/false] whether player is sliding"),
			crouching = DataTypes.field("boolean", "[true/false] whether player is crouching (local player only)"),
			dodging = DataTypes.field("boolean", "[true/false] whether player is mid-dodge"),
			airborne = DataTypes.field("boolean", "[true/false] whether player is off the ground, jumping or falling"),
			vaulting = DataTypes.field("boolean", "[true/false] whether player is vaulting over an obstacle"),

			attacking = DataTypes.field("boolean", "[true/false] whether player is mid-attack, melee or ranged"),
			blocking = DataTypes.field("boolean", "[true/false] whether player is blocking"),
			aiming = DataTypes.field("boolean", "[true/false] whether player is aiming"),

			in_coherency = DataTypes.field(
				"boolean",
				"[true/false] whether this player is in coherency of at least 1 other player"
			),
			coherency_count = DataTypes.field(
				"number",
				"[0..n] the game's own coherency count. NOTE: the player counts themselves, so being alone reads 1"
			),
			coherency_others = DataTypes.field(
				"number",
				"[0..n] how many OTHER players are in coherency with this one"
			),
			in_party = DataTypes.field(
				"boolean",
				"[true/false] whether the occupant is on your team, rather than a stranger sharing the hub"
			),

			bot = DataTypes.field("boolean", "[true/false] whether the slot occupant is a bot rather than a human"),
			local_player = DataTypes.field("boolean", "[true/false] whether the slot occupant is you"),

			talking = DataTypes.field("boolean", "[true/false] whether the occupant is speaking on voice chat"),
		},
	},
	sections = {
		{ id = "identity", label = "Identity" },
		{ id = "vitals", label = "Vitals" },
		{ id = "danger", label = "Danger" },
		{ id = "combat", label = "Combat" },
		{ id = "movement", label = "Movement" },
		{ id = "team", label = "Team" },
	},
	field_meta = {
		["state.bot"] = { section = "identity" },
		["state.local_player"] = { section = "identity" },
		["state.exists"] = { section = "vitals" },
		["state.dead"] = { section = "vitals" },
		["state.alive"] = { section = "vitals" },
		["state.downed"] = { section = "vitals" },
		["state.seconds_until_rescuable"] = { section = "vitals" },
		["state.sprinting"] = { section = "movement" },
		["state.sliding"] = { section = "movement" },
		["state.crouching"] = { section = "movement" },
		["state.dodging"] = { section = "movement" },
		["state.airborne"] = { section = "movement" },
		["state.vaulting"] = { section = "movement" },
		["state.attacking"] = { section = "combat" },
		["state.blocking"] = { section = "combat" },
		["state.disabled"] = { section = "danger" },
		["state.requires_help"] = { section = "danger" },
		["state.hogtied"] = { section = "danger" },
		["state.ledge_hanging"] = { section = "danger" },
		["state.pounced"] = { section = "danger" },
		["state.netted"] = { section = "danger" },
		["state.grabbed"] = { section = "danger" },
		["state.aiming"] = { section = "combat" },
		["state.in_party"] = { section = "team" },
		["state.in_coherency"] = { section = "team" },
		["state.coherency_count"] = { section = "team" },
		["state.coherency_others"] = { section = "team" },
		["state.talking"] = { section = "team" },
	},
	write = function(values, player, unit, time_now)
		local state = values.state or {}
		values.state = state

		local exists = player ~= nil
		state.exists = exists

		if not exists then
			state.disabled, state.requires_help = false, false
			state.dead, state.alive = false, false
			state.downed, state.hogtied, state.ledge_hanging = false, false, false
			state.pounced, state.netted, state.grabbed = false, false, false
			state.sprinting, state.sliding, state.crouching = false, false, false
			state.dodging, state.airborne, state.vaulting = false, false, false
			state.attacking, state.blocking = false, false
			state.bot, state.local_player, state.talking = false, false, false
			state.in_party = false
			state.in_coherency = false
			state.coherency_count, state.coherency_others = 0, 0
			state.seconds_until_rescuable = 0
			return
		end

		state.disabled, state.requires_help = Player.is_disabled(unit)
		local dead = not Unit.alive(unit)
		state.dead = dead
		state.alive = not dead
		state.downed = not dead and Player.is_knocked_down(unit) or false
		state.hogtied = not dead and Player.is_hogtied(unit) or false
		state.ledge_hanging = not dead and Player.is_ledge_hanging(unit) or false

		state.pounced = not dead and Player.is_pounced(unit) or false
		state.netted = not dead and Player.is_netted(unit) or false
		state.grabbed = not dead and Player.is_grabbed(unit) or false

		state.sprinting = not dead and Movement.is_sprinting(unit) or false
		state.sliding = not dead and Movement.is_sliding(unit) or false
		state.crouching = not dead and Movement.is_crouching(unit) or false

		state.dodging = not dead and (Movement.is_dodging(unit) or Movement.is_method("dodging", unit)) or false
		state.airborne = not dead and Movement.is_airborne(unit) or false
		state.vaulting = not dead and Movement.is_method("vaulting", unit) or false

		local coherency_count, coherency_others = read_coherency(not dead and unit or nil)
		state.coherency_count = coherency_count
		state.coherency_others = coherency_others
		state.in_coherency = coherency_others > 0

		if dead or not unit then
			state.attacking, state.blocking = false, false
		else
			local ok, attacking, blocking, aiming = pcall(read_combat, unit)
			state.attacking = ok and attacking or false
			state.blocking = ok and blocking or false
			state.aiming = ok and aiming or false
		end

		state.bot = is_bot(player)
		state.local_player = player == Player.local_player()
		state.in_party = Party.is_in_party(player)
		state.talking = is_speaking(player)

		state.seconds_until_rescuable = dead and read_seconds_until_rescuable(player, state.hogtied) or 0
	end,
}

mod.hud_studio_player_state = Field
return Field
