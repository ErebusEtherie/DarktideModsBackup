-- weapon_special_timed_cooldown.lua
--
-- A one-charge weapon special that remains active through every hit for a
-- fixed window, then recovers its charge after a separate cooldown. This is
-- intentionally small: attack damage still belongs to the weapon template,
-- while this class owns only activation lifetime and recharge state.

local BuffSettings = require("scripts/settings/buff/buff_settings")
local WeaponSpecialInterface = require(
	"scripts/extension_systems/weapon/special_classes/weapon_special_interface")
local stat_buff_types = BuffSettings.stat_buffs

local PilgrimageWeaponSpecialTimedCooldown = class(
	"PilgrimageWeaponSpecialTimedCooldown")

PilgrimageWeaponSpecialTimedCooldown.UPDATE_WHEN_UNWIELDED = true

-- Power Cycler and Veteran's power-weapon talent both use the native
-- weapon_special_max_activations stat. A timed mode no longer counts hits, so
-- translate that stat into extra powered seconds when the template opts in.
local function effective_active_duration(tweak_data, buff_extension)
	local duration = tonumber(tweak_data.active_duration) or 0
	local seconds_per_extra =
		tonumber(tweak_data.active_duration_per_extra_activation) or 0
	if seconds_per_extra == 0 or not buff_extension then return duration end

	local stat_buffs = buff_extension:stat_buffs()
	local extra = tonumber(stat_buffs
		and stat_buffs[stat_buff_types.weapon_special_max_activations]) or 0
	return duration + math.max(extra, 0) * seconds_per_extra
end

local function begin_cooldown(self, t)
	local tweak_data = self._tweak_data
	local component = self._inventory_slot_component
	local active_duration = effective_active_duration(
		tweak_data, self._buff_extension)

	-- The HUD derives its two phases from this timestamp. Rebase it so an
	-- overrun caused by a chain latch begins a complete cooldown now, rather
	-- than consuming recovery time while the weapon is still sawing.
	component.special_active_start_t = t - active_duration
	self._next_charge_recovery_time = t + (tweak_data.cooldown or 0)
end

PilgrimageWeaponSpecialTimedCooldown.init = function (self, context, init_data)
	self._input_extension = context.input_extension
	self._weapon_extension = context.weapon_extension
	self._inventory_slot_component = init_data.inventory_slot_component
	self._tweak_data = init_data.tweak_data
	self._player_unit = context.player_unit
	self._buff_extension = ScriptUnit.extension(
		self._player_unit, "buff_system")
	local unit_data_extension = context.unit_data_extension
	self._action_sweep_component = unit_data_extension
		and unit_data_extension:read_component("action_sweep")
	self._next_charge_recovery_time = 0
	self._deactivation_deferred = false

	local max_charges = self._tweak_data.max_num_charges or 1
	self._inventory_slot_component.max_num_special_charges = max_charges
	self._inventory_slot_component.num_special_charges = max_charges
end

PilgrimageWeaponSpecialTimedCooldown.on_wieldable_slot_equipped = function (self)
	-- Native equip constructs this class, then resets every slot component to
	-- its defaults (including zero charges), then calls this callback. Initialise
	-- ready state here as well, not only in init. This is equip, not each wield.
	local component = self._inventory_slot_component
	local max_charges = self._tweak_data.max_num_charges or 1
	component.max_num_special_charges = max_charges
	component.num_special_charges = max_charges
	self._next_charge_recovery_time = 0
	self._deactivation_deferred = false
end

PilgrimageWeaponSpecialTimedCooldown.fixed_update = function (self, dt, t)
	local component = self._inventory_slot_component
	local tweak_data = self._tweak_data

	-- Hits do not call any deactivation path in this class. Duration is checked
	-- directly so optional activation-count bonuses can become extra time.
	if component.special_active then
		local active_duration = effective_active_duration(
			tweak_data, self._buff_extension)
		local start_t = component.special_active_start_t or t
		if start_t + active_duration <= t then
			local action_sweep = self._action_sweep_component
			local is_latched = action_sweep and action_sweep.is_sticky == true
			if is_latched then
				self._deactivation_deferred = true
			else
				local reason = self._deactivation_deferred
					and "active_duration_end_after_latch"
					or "active_duration_end"
				self._deactivation_deferred = false
				begin_cooldown(self, t)
				self._weapon_extension:set_wielded_weapon_weapon_special_active(
					t, false, reason)
			end
		end
	end

	local max_charges = tweak_data.max_num_charges or 1
	if not component.special_active
		and component.num_special_charges < max_charges
		and t >= self._next_charge_recovery_time then
		component.num_special_charges = max_charges
	end
end

PilgrimageWeaponSpecialTimedCooldown.on_special_activation = function (self, t)
	local component = self._inventory_slot_component
	local tweak_data = self._tweak_data
	local cost = tweak_data.num_charges_to_consume_on_activation or 1
	component.num_special_charges = math.max(
		component.num_special_charges - cost, 0)
	self._deactivation_deferred = false
	self._next_charge_recovery_time = t
		+ effective_active_duration(tweak_data, self._buff_extension)
		+ (tweak_data.cooldown or 0)
end

PilgrimageWeaponSpecialTimedCooldown.on_special_deactivation = function (self, t)
	local component = self._inventory_slot_component
	local max_charges = self._tweak_data.max_num_charges or 1
	if component.num_special_charges < max_charges then
		begin_cooldown(self, t)
	end
	self._deactivation_deferred = false
end

PilgrimageWeaponSpecialTimedCooldown.on_sweep_action_start = function (self, t)
	return
end

PilgrimageWeaponSpecialTimedCooldown.on_sweep_action_finish = function (
		self, t, num_hit_enemies)
	return
end

PilgrimageWeaponSpecialTimedCooldown.process_hit = function (
		self, t, weapon, action_settings, num_hit_enemies, target_is_alive,
		target_unit, damage, result, damage_efficiency, stagger_result,
		hit_position, attack_direction, abort_attack, optional_origin_slot)
	return
end

PilgrimageWeaponSpecialTimedCooldown.blocked_attack = function (
		self, attacking_unit, block_cost, block_broken, is_perfect_block)
	return
end

PilgrimageWeaponSpecialTimedCooldown.on_exit_damage_window = function (
		self, t, num_hit_enemies)
	return
end

PilgrimageWeaponSpecialTimedCooldown.on_weapon_shout_action_finish = function (
		self, t, aborted)
	return
end

implements(PilgrimageWeaponSpecialTimedCooldown, WeaponSpecialInterface)

PilgrimageWeaponSpecialTimedCooldown.effective_active_duration =
	effective_active_duration
PilgrimageWeaponSpecialTimedCooldown.begin_cooldown = begin_cooldown

-- A weapon constructed before the template patch can retain the native
-- one-hit special object. Route only that legacy Ironhelm object through the
-- same timed implementation, without touching Crucis or native missions.
function PilgrimageWeaponSpecialTimedCooldown.install_legacy_ironhelm(native, mod, owned_tweak)
	if native.__pilgrimage_timed_ironhelm_bridge then return end
	native.__pilgrimage_timed_ironhelm_bridge = true
	local function delegate(self)
		local weapon_template = self._weapon_template
		local tweak = weapon_template and owned_tweak(weapon_template.name)
		if not tweak then self._pilgrimage_timed_delegate = nil; return nil end
		if not self._pilgrimage_timed_delegate then
			local component = self._inventory_slot_component
			local charges, max_charges = component.num_special_charges, component.max_num_special_charges
			local timed = PilgrimageWeaponSpecialTimedCooldown:new({
				input_extension = self._input_extension,
				weapon_extension = self._weapon_extension,
				player_unit = self._player_unit,
				unit_data_extension = self._unit_data_extension,
			}, { inventory_slot_component = component, tweak_data = tweak })
			if component.special_active then
				component.num_special_charges = 0
				timed._next_charge_recovery_time = component.special_active_start_t
					+ effective_active_duration(tweak, timed._buff_extension) + tweak.cooldown
			elseif max_charges and max_charges > 0 then
				component.num_special_charges = charges
			end
			self._pilgrimage_timed_delegate = timed
		end
		return self._pilgrimage_timed_delegate
	end
	for _, name in ipairs({ "fixed_update", "on_special_activation",
		"on_special_deactivation", "process_hit", "on_sweep_action_finish" }) do
		local method = name
		mod:hook(native, method, function(func, self, ...)
			local timed = delegate(self)
			if timed then return timed[method](timed, ...) end
			return func(self, ...)
		end)
	end
end

return PilgrimageWeaponSpecialTimedCooldown
