-- weapon_special_persistent_shovel.lua
--
-- The folding Sapper Shovels already use a genuine toggle action. Their native
-- special class unfolds them after the first connected attack. This replacement
-- preserves the native on-hit push, but leaves manual use of the same special
-- action as the only way to change form.

local AttackSettings = require("scripts/settings/damage/attack_settings")
local Push = require(
	"scripts/extension_systems/character_state_machine/character_states/utilities/push")
local WeaponSpecialInterface = require(
	"scripts/extension_systems/weapon/special_classes/weapon_special_interface")
local attack_types = AttackSettings.attack_types

local PilgrimageWeaponSpecialPersistentShovel = class(
	"PilgrimageWeaponSpecialPersistentShovel")

PilgrimageWeaponSpecialPersistentShovel.init = function (self, context, init_data)
	self._weapon_extension = context.weapon_extension
	self._animation_extension = context.animation_extension
	self._inventory_slot_component = init_data.inventory_slot_component
	self._tweak_data = init_data.tweak_data
	self._player_unit = context.player_unit
	local unit_data_extension = context.unit_data_extension
	self._locomotion_push_component =
		unit_data_extension:write_component("locomotion_push")
	self._restore_folded_idle_at = nil
end

PilgrimageWeaponSpecialPersistentShovel.on_wieldable_slot_equipped = function (self)
	return
end

PilgrimageWeaponSpecialPersistentShovel.fixed_update = function (self, dt, t)
	local restore_at = self._restore_folded_idle_at
	if not restore_at or t < restore_at then return end

	self._restore_folded_idle_at = nil
	if self._inventory_slot_component.special_active then
		-- Folded shovel attacks end in the ordinary unfolded idle animation even
		-- when the mechanical special state remains active. Replay the weapon's
		-- native active-equip event once the attack has fully finished to restore
		-- the matching folded idle pose in both perspectives.
		self:_trigger_anim_event("equip_activated", "equip_activated")
	end
end

PilgrimageWeaponSpecialPersistentShovel.on_special_activation = function (self, t)
	return
end

PilgrimageWeaponSpecialPersistentShovel.on_special_deactivation = function (self, t)
	self._restore_folded_idle_at = nil
end

PilgrimageWeaponSpecialPersistentShovel.on_sweep_action_start = function (self, t)
	return
end

PilgrimageWeaponSpecialPersistentShovel.on_sweep_action_finish = function (
		self, t, num_hit_enemies)
	if self._inventory_slot_component.special_active then
		-- Defer one frame so the action's own finishing event cannot overwrite
		-- the folded-idle restoration.
		self._restore_folded_idle_at = t + 0.01
	end
end

PilgrimageWeaponSpecialPersistentShovel.process_hit = function (
		self, t, weapon, action_settings, num_hit_enemies, target_is_alive,
		target_unit, damage, result, damage_efficiency, stagger_result,
		hit_position, attack_direction, abort_attack, optional_origin_slot)
	if not self._inventory_slot_component.special_active
		or not target_is_alive then
		return
	end

	local only_deactive_on_abort = self._tweak_data
		and self._tweak_data.only_deactive_on_abort
	if only_deactive_on_abort and not abort_attack then return end

	local push_template = self._tweak_data and self._tweak_data.push_template
	if push_template then
		local direction = Vector3.normalize(
			POSITION_LOOKUP[self._player_unit] - POSITION_LOOKUP[target_unit])
		Push.add(self._player_unit, self._locomotion_push_component,
			direction, push_template, attack_types.melee)
	end
end

PilgrimageWeaponSpecialPersistentShovel.blocked_attack = function (
		self, attacking_unit, block_cost, block_broken, is_perfect_block)
	return
end

PilgrimageWeaponSpecialPersistentShovel.on_exit_damage_window = function (
		self, t, num_hit_enemies, aborted)
	return
end

PilgrimageWeaponSpecialPersistentShovel.on_weapon_shout_action_finish = function (
		self, t, aborted)
	return
end

PilgrimageWeaponSpecialPersistentShovel._trigger_anim_event = function (
		self, anim_event, anim_event_3p, action_time_offset, ...)
	local animation_extension = self._animation_extension
	if not animation_extension then return end

	action_time_offset = action_time_offset or 0
	animation_extension:anim_event_with_variable_floats_1p(
		anim_event, "attack_speed", 1, "action_time_offset",
		action_time_offset, ...)
	if anim_event_3p then
		animation_extension:anim_event_with_variable_floats(
			anim_event_3p, "attack_speed", 1, "action_time_offset",
			action_time_offset, ...)
	end
end

implements(PilgrimageWeaponSpecialPersistentShovel, WeaponSpecialInterface)

return PilgrimageWeaponSpecialPersistentShovel
