local mod = get_mod("scores")

mod.combat_ability_charges = mod.combat_ability_charges or {}
mod.combat_ability_names = mod.combat_ability_names or {}

local function combat_ability_enabled(extension)
	if type(extension.ability_enabled) == "function" and extension:ability_enabled("combat_ability") then
		return true
	end

	return false
end

local function combat_ability_name(extension)
	local equipped = extension._equipped_abilities
	local ability = equipped and equipped.combat_ability

	return ability and ability.name
end

local function combat_ability_charges(extension)
	local components = extension._ability_components or extension._components
	local component = components and components.combat_ability

	return component and component.num_charges
end

local function update_combat_ability_use(extension, unit)
	if not unit then
		return
	end

	if not mod:row_tracking_enabled("combat_ability_uses") then
		if not mod.combat_ability_tracking_disabled then
			table.clear(mod.combat_ability_charges)
			table.clear(mod.combat_ability_names)
			mod.combat_ability_tracking_disabled = true
		end
		return
	end

	mod.combat_ability_tracking_disabled = false

	if not combat_ability_enabled(extension) then
		return
	end

	local account_id = mod.player_account_ids_by_unit and mod.player_account_ids_by_unit[unit]
	if not account_id then
		account_id = mod:account_id_from_unit(unit)
		if account_id and mod.player_account_ids_by_unit then
			mod.player_account_ids_by_unit[unit] = account_id
		end
	end

	if not account_id then
		return
	end

	local charges = combat_ability_charges(extension)
	if charges == nil then
		return
	end

	local ability_name = combat_ability_name(extension)
	local previous_name = mod.combat_ability_names[account_id]
	local previous_charges = mod.combat_ability_charges[account_id]

	if ability_name == previous_name and previous_charges and charges < previous_charges then
		mod:update_stat("combat_ability_uses", account_id, previous_charges - charges)
	end

	mod.combat_ability_names[account_id] = ability_name
	mod.combat_ability_charges[account_id] = charges
end

if CLASS and CLASS.PlayerUnitAbilityExtension then
	mod:hook_safe(CLASS.PlayerUnitAbilityExtension, "update", function(extension, unit, ...)
		update_combat_ability_use(extension, unit)
	end)
end

if CLASS and CLASS.PlayerHuskAbilityExtension then
	mod:hook_safe(CLASS.PlayerHuskAbilityExtension, "update", function(extension, unit, ...)
		update_combat_ability_use(extension, unit)
	end)
end

return mod
