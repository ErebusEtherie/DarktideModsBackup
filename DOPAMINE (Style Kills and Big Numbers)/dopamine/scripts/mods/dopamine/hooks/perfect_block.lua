---@type mod
local mod = get_mod("dopamine")

if mod.perfect_block then
	return mod.perfect_block
end

local EventManager = mod:core(mod.event_manager, "utils/event/manager")

---@param unit Unit
---@return boolean
local function is_perfect_blocking(unit)
	local unit_data = mod.dl.player.extensions(unit, "unit_data_system")
	local block = unit_data and unit_data:read_component("block")
	return block ~= nil and block.is_blocking and block.is_perfect_blocking or false
end

---@param unit Unit
---@return boolean
local function current_action_is_parry(unit)
	local unit_data, weapon_ext = mod.dl.player.extensions(unit, "unit_data_system", "weapon_system")
	if not unit_data or not weapon_ext then
		return false
	end

	local weapon_template = weapon_ext:weapon_template()
	local weapon_action = unit_data:read_component("weapon_action")
	if not weapon_template or not weapon_action then
		return false
	end

	local action = weapon_template.actions[weapon_action.current_action_name]
	return action ~= nil and action.parry_block == true
end

mod.dl.game_hooks.hook_safe(
	"PlayerUnitWeaponExtension",
	"blocked_attack",
	function(self, _attacking_unit, _hit_world_position, block_broken, _weapon_template, _attack_type, _block_cost, is_perfect_block)
		if not is_perfect_block or block_broken then
			return
		end

		if self._unit ~= mod.dl.player.local_player_unit() then
			return
		end

		EventManager.on_perfect_block()
		if current_action_is_parry(self._unit) then
			EventManager.on_parry()
		end
	end
)

mod.dl.game_hooks.hook_safe(
	"WeaponSystem",
	"rpc_player_blocked_attack",
	function(_self, _channel_id, unit_id, _attacking_unit_id, _hit_world_position, block_broken, _weapon_template_id, _attack_type_id)
		if block_broken then
			return
		end

		local unit_spawner = Managers.state.unit_spawner
		local blocking_unit = unit_spawner and unit_spawner:unit(unit_id)

		if not blocking_unit or blocking_unit ~= mod.dl.player.local_player_unit() then
			return
		end

		if is_perfect_blocking(blocking_unit) then
			EventManager.on_perfect_block()
			if current_action_is_parry(blocking_unit) then
				EventManager.on_parry()
			end
		end
	end
)

---@class PerfectBlock
local PerfectBlock = {}

mod.perfect_block = PerfectBlock

return PerfectBlock
