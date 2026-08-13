

---@class DarkLib
---@field player DL_Player

---@param mod mod
return function(mod)
	local FS_Unit = Unit
	local FS_Managers = Managers
	local FS_ScriptUnit = ScriptUnit
	local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")

	---@alias Unit userdata  Boxed engine unit handle.

	---@class DL_PlayerProfileArchetype
	---@field name string   Internal class name, e.g. "veteran", "ogryn".
	---@field breed string  Breed name, e.g. "human", "ogryn".

	---@class DL_PlayerProfile
	---@field archetype DL_PlayerProfileArchetype|nil

	---@class DL_PlayerObject
	---@field player_unit Unit|nil                 Controlled unit; may be absent/dead.
	---@field profile fun(self:DL_PlayerObject):DL_PlayerProfile|nil
	---@field name fun(self:DL_PlayerObject):string
	---@field account_id fun(self: DL_PlayerObject) : string
	---@field is_human_controlled fun(self: DL_PlayerObject) : boolean

	---@alias DL_PlayerOrUnit DL_PlayerObject|Unit  A player object (table) or a unit (userdata).

	---@class DL_CharacterStateComponent
	---@field state_name string  e.g. "dead", "knocked_down", "sprinting".

	---@class DL_HealthExtension
	---@field current_health fun(self:DL_HealthExtension):number
	---@field max_health fun(self:DL_HealthExtension):number
	---@field current_health_percent fun(self:DL_HealthExtension):number

	---@class DL_ToughnessExtension
	---@field remaining_toughness fun(self:DL_ToughnessExtension):number
	---@field max_toughness fun(self:DL_ToughnessExtension):number
	---@field current_toughness_percent fun(self:DL_ToughnessExtension):number

	---@alias DL_NamedExtension "health_system" | "toughness_system" | "buff_system" | "unit_data_system"

	local function ensure_managers()
		FS_Managers = FS_Managers or _G.Managers
		return FS_Managers
	end

	local function ensure_unit()
		FS_Unit = FS_Unit or _G.Unit
		return FS_Unit
	end

	local function ensure_script_unit()
		FS_ScriptUnit = FS_ScriptUnit or _G.ScriptUnit
		return FS_ScriptUnit
	end

	local function player_manager()
		return ensure_managers() and FS_Managers.player or nil
	end

	---@class DL_Player
	local Player = {}

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return Unit | nil
	local function resolve_unit(player_or_unit)
		if player_or_unit == nil then
			return Player.local_player_unit()
		end

		if type(player_or_unit) == "table" then
			return Player.unit(player_or_unit)
		end

		if ensure_unit() and FS_Unit.alive(player_or_unit) then
			return player_or_unit
		end

		return nil
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return DL_PlayerObject | nil
	local function resolve_player(player_or_unit)
		if player_or_unit == nil then
			return Player.local_player()
		end

		if type(player_or_unit) == "table" then
			return player_or_unit
		end

		return Player.from_unit(player_or_unit)
	end

	---@param ... DL_NamedExtension
	---@return any | nil ...
	function Player.local_player_extensions(...)
		return Player.extensions(Player.local_player_unit(), ...)
	end

	---@param unit Unit | nil
	---@param ... DL_NamedExtension
	---@return any | nil ...
	function Player.extensions(unit, ...)
		if not unit or not ensure_script_unit() then
			return
		end

		local results = {}

		for i = 1, select("#", ...) do
			local name = select(i, ...)
			results[i] = FS_ScriptUnit.has_extension(unit, name)
		end

		return unpack(results)
	end

	---@param unit Unit | nil
	---@param name string
	---@return any | nil
	local function read_component(unit, name)
		local unit_data = Player.extensions(unit, "unit_data_system")
		return unit_data and unit_data:read_component(name) or nil
	end

	---@return DL_PlayerObject | nil
	function Player.local_player()
		local pm = player_manager()
		return pm and pm:local_player_safe(1) or nil
	end

	---@param player DL_PlayerObject | nil
	---@return Unit | nil
	function Player.unit(player)
		if not ensure_unit() then
			return nil
		end
		player = player or Player.local_player()
		local unit = player and player.player_unit

		if unit and FS_Unit.alive(unit) then
			return unit
		end

		return nil
	end

	---@return Unit | nil
	function Player.local_player_unit()
		return Player.unit(Player.local_player())
	end

	---@param unit Unit | nil
	---@return DL_PlayerObject | nil
	function Player.from_unit(unit)
		local pm = unit and player_manager()
		return pm and pm:player_by_unit(unit) or nil
	end

	---@param unit Unit | nil
	---@return DL_PlayerObject | nil
	function Player.local_from_unit(unit)
		if not unit then
			return nil
		end

		local local_player = Player.local_player()

		if local_player and local_player.player_unit == unit then
			return local_player
		end

		return nil
	end

	---@return table<string, DL_PlayerObject>
	function Player.players()
		local pm = player_manager()
		return pm and pm:players() or {}
	end

	---@return table<string, DL_PlayerObject>
	function Player.human_players()
		local pm = player_manager()
		return pm and pm:human_players() or {}
	end

	---@return table<string, DL_PlayerObject>
	function Player.bot_players()
		local pm = player_manager()
		return pm and pm:bot_players() or {}
	end

	---@param include_self boolean | nil
	---@return DL_PlayerObject[]
	function Player.teammates(include_self)
		local local_player = Player.local_player()
		local out = {}

		for _, player in pairs(Player.human_players()) do
			if include_self or player ~= local_player then
				out[#out + 1] = player
			end
		end

		return out
	end

	---@param players DL_PlayerObject[] | table<string, DL_PlayerObject> | nil
	---@return Unit[]
	function Player.player_units(players)
		local out = {}

		for _, player in pairs(players or Player.players()) do
			local unit = Player.unit(player)
			if unit then
				out[#out + 1] = unit
			end
		end

		return out
	end

	---@param player DL_PlayerObject | nil
	---@return DL_PlayerProfile | nil
	function Player.profile(player)
		player = player or Player.local_player()
		if not player then
			return nil
		end

		local ok, profile = pcall(function()
			return player:profile()
		end)
		if not ok then
			return nil
		end

		return profile or nil
	end

	---@param player DL_PlayerObject | nil
	---@return string | nil
	function Player.account_id(player)
		return player and player:account_id() or nil
	end

	---@param player DL_PlayerObject | nil
	---@return DL_PlayerProfileArchetype | nil
	function Player.archetype(player)
		local profile = Player.profile(player)
		return profile and profile.archetype or nil
	end

	---@param player DL_PlayerObject | nil
	---@return string | nil
	function Player.archetype_name(player)
		local archetype = Player.archetype(player)
		return archetype and archetype.name or nil
	end

	---@param player DL_PlayerObject | nil
	---@return string | nil
	function Player.breed_name(player)
		local archetype = Player.archetype(player)
		return archetype and archetype.breed or nil
	end

	---@param player DL_PlayerObject | nil
	---@return string | nil
	function Player.name(player)
		player = player or Player.local_player()
		if not player then
			return nil
		end

		local ok, name = pcall(function()
			return player:name()
		end)
		return ok and name or nil
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Player.is_alive(player_or_unit)
		return resolve_unit(player_or_unit) ~= nil
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Player.is_in_game(player_or_unit)
		local player = resolve_player(player_or_unit)
		local pm = player and player_manager()
		if not pm then
			return false
		end

		local ok, unique_id = pcall(function()
			return player:unique_id()
		end)
		if not ok or unique_id == nil then
			return false
		end

		return pm:player_from_unique_id(unique_id) == player
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return string | nil
	function Player.character_state(player_or_unit)
		---@type DL_CharacterStateComponent | nil
		local component = read_component(resolve_unit(player_or_unit), "character_state")
		return component and component.state_name or nil
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean disabled, boolean requires_help
	function Player.is_disabled(player_or_unit)
		local component = read_component(resolve_unit(player_or_unit), "character_state")
		if not component then
			return false, false
		end
		local disabled, requires_help = PlayerUnitStatus.is_disabled(component)
		return disabled or false, requires_help or false
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Player.is_knocked_down(player_or_unit)
		local component = read_component(resolve_unit(player_or_unit), "character_state")
		return component ~= nil and PlayerUnitStatus.is_knocked_down(component)
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Player.is_hogtied(player_or_unit)
		local component = read_component(resolve_unit(player_or_unit), "character_state")
		return component ~= nil and PlayerUnitStatus.is_hogtied(component)
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Player.is_ledge_hanging(player_or_unit)
		local component = read_component(resolve_unit(player_or_unit), "character_state")
		return component ~= nil and PlayerUnitStatus.is_ledge_hanging(component)
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean
	function Player.is_dead(player_or_unit)
		local component = read_component(resolve_unit(player_or_unit), "character_state")
		return component ~= nil and PlayerUnitStatus.is_dead(component)
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean pounced, Unit | nil disabling_unit
	function Player.is_pounced(player_or_unit)
		local component = read_component(resolve_unit(player_or_unit), "disabled_character_state")
		if not component then
			return false, nil
		end
		return PlayerUnitStatus.is_pounced(component)
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean netted, Unit | nil disabling_unit
	function Player.is_netted(player_or_unit)
		local component = read_component(resolve_unit(player_or_unit), "disabled_character_state")
		if not component then
			return false, nil
		end
		return PlayerUnitStatus.is_netted(component)
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean grabbed, Unit | nil disabling_unit
	function Player.is_grabbed(player_or_unit)
		local component = read_component(resolve_unit(player_or_unit), "disabled_character_state")
		if not component then
			return false, nil
		end
		return PlayerUnitStatus.is_grabbed(component)
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return DL_HealthExtension | nil
	local function health_extension(player_or_unit)
		return Player.extensions(resolve_unit(player_or_unit), "health_system")
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return DL_ToughnessExtension | nil
	local function toughness_extension(player_or_unit)
		return Player.extensions(resolve_unit(player_or_unit), "toughness_system")
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return number | nil
	function Player.health(player_or_unit)
		local ext = health_extension(player_or_unit)
		return ext and ext:current_health() or nil
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return number | nil
	function Player.max_health(player_or_unit)
		local ext = health_extension(player_or_unit)
		return ext and ext:max_health() or nil
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return number | nil
	function Player.health_percent(player_or_unit)
		local ext = health_extension(player_or_unit)
		return ext and ext:current_health_percent() or nil
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return number | nil
	function Player.toughness(player_or_unit)
		local ext = toughness_extension(player_or_unit)
		return ext and ext:remaining_toughness() or nil
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return number | nil
	function Player.max_toughness(player_or_unit)
		local ext = toughness_extension(player_or_unit)
		return ext and ext:max_toughness() or nil
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return number | nil
	function Player.toughness_percent(player_or_unit)
		local ext = toughness_extension(player_or_unit)
		return ext and ext:current_toughness_percent() or nil
	end

	---@param player_or_unit DL_PlayerObject | Unit | nil
	---@return boolean critical, number status
	function Player.is_in_critical_health(player_or_unit)
		local unit = resolve_unit(player_or_unit)
		local health, toughness = Player.extensions(unit, "health_system", "toughness_system")
		if not health or not toughness then
			return false, 0
		end
		return PlayerUnitStatus.is_in_critical_health(health, toughness)
	end

	return Player
end
