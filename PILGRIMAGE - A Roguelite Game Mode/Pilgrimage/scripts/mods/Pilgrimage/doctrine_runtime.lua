-- doctrine_runtime.lua
--
-- Stateful Doctrine effects which cannot be represented by one static buff.
-- Every hook is owner-scoped to the local Pilgrimage player and leaves normal
-- missions, bots and other players unchanged.

local M = {}

local _mod
local _shared
local _boons
local _debug_log

local _state = {
	marks = setmetatable({}, { __mode = "k" }),
	crossfire_ready = 0,
	ablative = setmetatable({}, { __mode = "k" }),
	overkill = setmetatable({}, { __mode = "k" }),
	quarry = setmetatable({}, { __mode = "k" }),
}

local function _active(id)
	return _boons and _boons.custom_boon_active
		and _boons.custom_boon_active(id) == true
end

local function _now()
	return _shared and _shared.fixed_time and _shared.fixed_time() or 0
end

local function _local_unit()
	return _shared and _shared.local_player_unit and _shared.local_player_unit() or nil
end

local function _arg(name, ...)
	for i = 1, select("#", ...), 2 do
		if select(i, ...) == name then return select(i + 1, ...) end
	end
	return nil
end

local function _owner(attacking_unit, explicit_owner)
	if explicit_owner then return explicit_owner end
	if not attacking_unit then return nil end
	local spawn = Managers and Managers.state and Managers.state.player_unit_spawn
	if spawn and type(spawn.owner) == "function" then
		local ok, player = pcall(spawn.owner, spawn, attacking_unit)
		if ok and player and player.player_unit then return player.player_unit end
	end
	return attacking_unit
end

local function _is_local_owner(unit)
	return unit ~= nil and unit == _local_unit()
end

local function _direct_attack(attack_type, profile)
	if attack_type ~= "melee" and attack_type ~= "ranged" then return false end
	local name = profile and profile.name or ""
	return name ~= "pilgrimage_secondary_damage"
		and string.find(name, "pilgrimage_secondary", 1, true) == nil
end

local function _boss(unit)
	local unit_data = unit and ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = unit_data and unit_data:breed()
	local tags = breed and breed.tags or {}
	local name = breed and tostring(breed.name) or ""
	return breed ~= nil and (breed.is_boss == true or tags.monster == true
		or tags.captain == true or string.find(name, "captain", 1, true) ~= nil)
end

local function _alive(unit)
	return unit ~= nil and (not rawget(_G, "HEALTH_ALIVE") or HEALTH_ALIVE[unit])
end

local function _allied(a, b)
	local ext = Managers and Managers.state and Managers.state.extension
	local system = ext and ext:system("side_system")
	if not system or type(system.is_ally) ~= "function" then return false end
	local ok, result = pcall(system.is_ally, system, a, b)
	return ok and result == true
end

local function _replenish_toughness(unit, amount)
	local ok, Toughness = pcall(require, "scripts/utilities/toughness/toughness")
	if ok and Toughness and Toughness.replenish_percentage then
		pcall(Toughness.replenish_percentage, unit, amount, false, "shared")
	end
end

local function _force_heavy_stagger(target, source, direction)
	local ok, Stagger = pcall(require, "scripts/utilities/attack/stagger")
	if ok and Stagger and Stagger.force_stagger then
		-- Some damage paths do not forward an attack direction. Native stagger
		-- still requires a vector, so fall back to an upward impulse instead of
		-- silently losing Crossfire Catechism's control effect.
		direction = direction or (rawget(_G, "Vector3") and Vector3.up())
		pcall(Stagger.force_stagger, target, "heavy", direction, 2, 1, 2, source)
	end
end

local function _health_before(unit)
	local ext = unit and ScriptUnit.has_extension(unit, "health_system")
	if ext and type(ext.current_health) == "function" then
		local ok, value = pcall(ext.current_health, ext)
		if ok then return tonumber(value) end
	end
	return nil
end

function M.install_attack(Attack)
	if not _mod or not Attack or Attack.__pilgrimage_doctrines then return end
	Attack.__pilgrimage_doctrines = true
	_mod:hook(Attack, "execute", function(func, attacked_unit, damage_profile, ...)
		local attacking_unit = _arg("attacking_unit", ...)
		local attacking_owner = _owner(attacking_unit,
			_arg("attacking_unit_owner_unit", ...))
		local attack_type = _arg("attack_type", ...)
		local instakill = _arg("instakill", ...) == true
		local before = _health_before(attacked_unit)
		local damage, result, efficiency, stagger, weakspot =
			func(attacked_unit, damage_profile, ...)

		if type(damage) == "number" and damage > 0 then
			local local_player = _local_unit()
			if _active("pilgrim_boon_sanctioned_discord") and local_player then
				local now = _now()
				if attacking_owner == local_player and _alive(attacked_unit) then
					_state.marks[attacked_unit] = now + 5
				elseif attacking_owner and attacking_owner ~= local_player
					and _allied(local_player, attacking_owner)
					and (_state.marks[attacked_unit] or 0) >= now
					and now >= _state.crossfire_ready then
					_state.marks[attacked_unit] = nil
					_state.crossfire_ready = now + 5
					local direction = _arg("attack_direction", ...)
					_force_heavy_stagger(attacked_unit, local_player, direction)
					_replenish_toughness(local_player, 0.10)
					_replenish_toughness(attacking_owner, 0.10)
				end
			end

			if _is_local_owner(attacking_owner)
				and _active("pilgrim_doctrine_overkill_dividend")
				and result == "died" and not instakill and before
				and _direct_attack(attack_type, damage_profile) and damage > before then
				local state = _state.overkill[attacking_owner] or { bank = 0 }
				state.bank = math.max(0, state.bank or 0) + (damage - before) * 0.5
				state.deposited_at = _now()
				state.consume_at = nil
				_state.overkill[attacking_owner] = state
			end
		end
		return damage, result, efficiency, stagger, weakspot
	end)
end

function M.install_damage_calculation(DamageCalculation)
	if not _mod or not DamageCalculation
		or DamageCalculation.__pilgrimage_doctrines then return end
	DamageCalculation.__pilgrimage_doctrines = true
	_mod:hook(DamageCalculation, "calculate", function(func, ...)
		local damage, efficiency, base_damage, base_buff_damage, rending_damage,
			finesse_damage, backstab_damage, flanking_damage, armor_modifier,
			hit_zone_multiplier = func(...)
		local attack_type = select(17, ...)
		local profile = select(1, ...)
		local target = select(30, ...)
		-- DamageCalculation.calculate argument 35 is the owner unit. Argument
		-- 36 is its buff extension, which is deliberately not interchangeable.
		local owner = select(35, ...)
		local now = _now()

		if _is_local_owner(owner) and type(damage) == "number" and damage > 0 then
			if _active("pilgrim_boon_bigger_they_are") and target
				and not _allied(owner, target) then
				local quarry = _state.quarry[owner]
				if quarry and not _alive(quarry) then quarry = nil end
				if not quarry and _boss(target) then
					quarry = target
					_state.quarry[owner] = target
				end
				if quarry then damage = damage * (target == quarry and 1.75 or 0.75) end
			end

			if _direct_attack(attack_type, profile)
				and _active("pilgrim_boon_redline_cogitator") then
				local transaction = _state.ablative[owner]
				if not transaction or transaction.at ~= now then
					local toughness = ScriptUnit.has_extension(owner, "toughness_system")
					local active = toughness and toughness:current_toughness_percent() > 0.75
					transaction = { at = now, active = active == true }
					_state.ablative[owner] = transaction
					if transaction.active then
						pcall(toughness.add_damage, toughness,
							toughness:max_toughness() * 0.05,
							"toughness_absorbed", nil, nil, "melee")
					end
				end
				if transaction.active then damage = damage * 1.25 end
			end

			if _direct_attack(attack_type, profile)
				and _active("pilgrim_doctrine_overkill_dividend") then
				local state = _state.overkill[owner]
				if state and (state.bank or 0) > 0 and state.deposited_at ~= now then
					-- The bank belongs to exactly one attack. All pellets or cleave
					-- targets resolved in the same engine transaction share it; any
					-- residue expires before a later attack can use it.
					if state.consume_at == nil then state.consume_at = now end
					if state.consume_at == now then
						local bonus = math.min(damage * 0.5, state.bank)
						damage = damage + bonus
						state.bank = state.bank - bonus
					else
						state.bank = 0
						state.consume_at = nil
					end
				end
			end
		end

		return damage, efficiency, base_damage, base_buff_damage, rending_damage,
			finesse_damage, backstab_damage, flanking_damage, armor_modifier,
			hit_zone_multiplier
	end)
end

function M.install_ammo(Ammo)
	if not _mod or not Ammo or Ammo.__pilgrimage_doctrines then return end
	Ammo.__pilgrimage_doctrines = true
	_mod:hook(Ammo, "add_ammo_using_pickup_data", function(func, unit, pickup_data, ...)
		if _is_local_owner(unit)
			and _active("pilgrim_doctrine_munitorum_dispensation")
			and type(pickup_data) == "table" then
			local name = pickup_data.name
			if name == "small_clip" or name == "large_clip" then
				local copy = table.clone(pickup_data)
				if name == "small_clip" then
					local ok, Pickups = pcall(require, "scripts/settings/pickup/pickups")
					local large = ok and Pickups.by_name and Pickups.by_name.large_clip
					if large and large.ammo_amount_func then
						copy.ammo_amount_func = large.ammo_amount_func
					end
				else
					copy.ammo_amount_func = function(max_reserve)
						return max_reserve
					end
				end
				pickup_data = copy
			end
		end
		return func(unit, pickup_data, ...)
	end)
end

function M.install_ammunition_interaction(AmmunitionInteraction)
	if not _mod or not AmmunitionInteraction
		or AmmunitionInteraction.__pilgrimage_doctrines then return end
	AmmunitionInteraction.__pilgrimage_doctrines = true
	_mod:hook(AmmunitionInteraction, "_add_ammo",
		function(func, self, interactor_unit, pickup_data)
			local result = func(self, interactor_unit, pickup_data)
			if _is_local_owner(interactor_unit)
				and _active("pilgrim_doctrine_munitorum_dispensation")
				and pickup_data and pickup_data.allow_grenade_sharing then
				local ability = ScriptUnit.has_extension(interactor_unit, "ability_system")
				if ability and ability:ability_is_equipped("grenade_ability") then
					local max = ability:max_ability_charges("grenade_ability")
					local current = ability:remaining_ability_charges("grenade_ability")
					if max > current then
						ability:restore_ability_charge("grenade_ability", max - current)
					end
				end
			end
			return result
		end)
end

local function _distance_squared(a, b)
	local positions = rawget(_G, "POSITION_LOOKUP")
	local pa, pb = positions and positions[a], positions and positions[b]
	if not pa or not pb then return math.huge end
	return Vector3.distance_squared(pa, pb)
end

local function _eligible_allies(unit)
	local ext = Managers and Managers.state and Managers.state.extension
	local side_system = ext and ext:system("side_system")
	local side = side_system and side_system.side_by_unit[unit]
	return side and side.player_units or {}
end

local function _timed_stimm_target(unit)
	local best, best_distance
	for _, ally in pairs(_eligible_allies(unit)) do
		local distance = ally ~= unit and _alive(ally) and _distance_squared(unit, ally)
		if distance and distance <= 64 and (not best_distance or distance < best_distance) then
			best, best_distance = ally, distance
		end
	end
	return best
end

local function _med_stimm_target(unit)
	local best, best_missing = nil, 0
	for _, ally in pairs(_eligible_allies(unit)) do
		if ally ~= unit and _alive(ally) and _distance_squared(unit, ally) <= 64 then
			local health = ScriptUnit.has_extension(ally, "health_system")
			if health then
				local max = health:max_health()
				local missing = max > 0 and (max - health:current_health()) / max or 0
				if missing > best_missing then best, best_missing = ally, missing end
			end
		end
	end
	return best
end

function M.install_syringe_templates(templates)
	if not _mod or type(templates) ~= "table" or templates.__pilgrimage_doctrines then return end
	templates.__pilgrimage_doctrines = true
	local timed = {
		syringe_ability_boost_buff = "pilgrim_shared_syringe_ability",
		syringe_power_boost_buff = "pilgrim_shared_syringe_power",
		syringe_speed_boost_buff = "pilgrim_shared_syringe_speed",
	}
	for native_name, shared_name in pairs(timed) do
		local native = templates[native_name]
		if native then
			local shared = table.clone(native)
			shared.name = shared_name
			shared.duration = (tonumber(native.duration) or 15) * 0.5
			templates[shared_name] = shared
			local native_start = native.start_func
			native.start_func = function(template_data, template_context)
				if native_start then native_start(template_data, template_context) end
				local unit = template_context.unit
				if template_context.is_server and unit == _local_unit()
					and _active("pilgrim_doctrine_shared_dosage") then
					local ally = _timed_stimm_target(unit)
					local ext = ally and ScriptUnit.has_extension(ally, "buff_system")
					if ext then ext:add_internally_controlled_buff(shared_name, _now()) end
				end
			end
		end
	end

	local heal = templates.syringe_heal_corruption_buff
	if heal then
		local shared = table.clone(heal)
		shared.name = "pilgrim_shared_syringe_heal"
		shared.heal_settings = table.clone(heal.heal_settings)
		shared.heal_settings.min_percentage_of_heal =
			(tonumber(shared.heal_settings.min_percentage_of_heal) or 0.25) * 0.5
		shared.heal_settings.number_of_health_segments =
			(tonumber(shared.heal_settings.number_of_health_segments) or 1) * 0.5
		templates.pilgrim_shared_syringe_heal = shared
		local native_start = heal.start_func
		heal.start_func = function(template_data, template_context)
			if native_start then native_start(template_data, template_context) end
			local unit = template_context.unit
			if template_context.is_server and unit == _local_unit()
				and _active("pilgrim_doctrine_shared_dosage") then
				local ally = _med_stimm_target(unit)
				local ext = ally and ScriptUnit.has_extension(ally, "buff_system")
				if ext then
					ext:add_internally_controlled_buff("pilgrim_shared_syringe_heal", _now())
				end
			end
		end
	end
end

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_boons = deps.boons
	_debug_log = deps.debug_log or function() end
end

return M
