local Catalog = {}

Catalog.none_value = "__none__"
Catalog.max_selection = 99
-- These native templates directly consume slot_secondary ammunition or
-- reload events. Native Mortis does not itself filter them by equipped weapon.
Catalog.resource_requirements={
    hordes_buff_auto_clip_fill_while_melee="ammo",
    hordes_buff_no_ammo_consumption_on_crits="ammo",
    hordes_buff_bonus_crit_chance_on_ammo="ammo",
    hordes_buff_melee_damage_missing_ammo_in_clip="ammo",
    hordes_buff_weakspot_ranged_hit_gives_infinite_ammo="ammo",
    hordes_buff_veteran_infinite_ammo_during_stance="ammo",
    hordes_buff_increased_damage_after_reload="reload",
    hordes_buff_improved_weapon_reload_on_melee_kill="reload",
}
function Catalog.resource_compatible(name,setup)
    local resource=Catalog.resource_requirements[name]
    if not resource or not setup or not setup.resources then return true end
    local secondary=setup.weapon_slots and setup.weapon_slots.slot_secondary
    return secondary and secondary[resource]==true or false
end

local source_rank = {
	class = 1,
	generic = 2,
	family = 3,
}

local function record_source(sources, buff_name, source)
	if not sources or not source then
		return
	end

	local existing = sources[buff_name]

	if source.kind == "family" then
		existing = existing or {
			families = {},
			family_lookup = {},
			kind = "family",
		}
		existing.families = existing.families or {}
		existing.family_lookup = existing.family_lookup or {}

		if source.family and not existing.family_lookup[source.family] then
			existing.family_lookup[source.family] = true
			existing.families[#existing.families + 1] = source.family
		end
	end

	if not existing
		or (source_rank[source.kind] or 99) < (source_rank[existing.kind] or 99)
	then
		local families = existing and existing.families or {}
		local family_lookup = existing and existing.family_lookup or {}

		existing = {
			archetype = source.archetype,
			archetypes = existing and existing.archetypes,
			archetype_lookup = existing and existing.archetype_lookup,
			families = families,
			family_lookup = family_lookup,
			kind = source.kind,
			requirement = source.requirement,
		}
	end
	if source.archetype then
		existing.archetypes = existing.archetypes or {}
		existing.archetype_lookup = existing.archetype_lookup or {}
		if not existing.archetype_lookup[source.archetype] then
			existing.archetype_lookup[source.archetype] = true
			existing.archetypes[#existing.archetypes + 1] = source.archetype
		end
		existing.archetype = #existing.archetypes == 1 and existing.archetypes[1] or nil
	end

	sources[buff_name] = existing
end

local function append_unique(result, lookup, values, known_buffs, sources, source)
	if type(values) ~= "table" then
		return
	end

	for i = 1, #values do
		local buff_name = values[i]

		if type(buff_name) == "string" and (not known_buffs or known_buffs[buff_name]) then
			record_source(sources, buff_name, source)

			if not lookup[buff_name] then
				lookup[buff_name] = true
				result[#result + 1] = buff_name
			end
		end
	end
end

local function append_family_buffs(result, lookup, allowed_buffs, known_buffs, sources, only_family)
	local families = allowed_buffs and allowed_buffs.buff_families or {}
	local ordered_names = allowed_buffs and allowed_buffs.available_family_builds or {}
	local visited = {}

	local function append_family(family_name, family)
		if type(family) ~= "table" or visited[family_name] then
			return
		end

		visited[family_name] = true
		local source = {
			family = family_name,
			kind = "family",
		}

		append_unique(result, lookup, family.priority_buffs, known_buffs, sources, source)
		append_unique(result, lookup, family.buffs, known_buffs, sources, source)
	end

	if only_family then
		append_family(only_family, families[only_family])
	else
		for i = 1, #ordered_names do
			local family_name = ordered_names[i]

			append_family(family_name, families[family_name])
		end

		for family_name, family in pairs(families) do
			append_family(family_name, family)
		end
	end
end

function Catalog.family_names(allowed_buffs)
	local result = {}
	local seen = {}
	local families = allowed_buffs and allowed_buffs.buff_families or {}
	local ordered_names = allowed_buffs and allowed_buffs.available_family_builds or {}

	for i = 1, #ordered_names do
		local family_name = ordered_names[i]

		if type(family_name) == "string" and type(families[family_name]) == "table" then
			seen[family_name] = true
			result[#result + 1] = family_name
		end
	end

	local unordered = {}

	for family_name, family in pairs(families) do
		if type(family_name) == "string" and type(family) == "table" and not seen[family_name] then
			unordered[#unordered + 1] = family_name
		end
	end

	table.sort(unordered)

	for i = 1, #unordered do
		result[#result + 1] = unordered[i]
	end

	return result
end

function Catalog.is_valid_family(allowed_buffs, family_name)
	return type(family_name) == "string"
		and type(allowed_buffs) == "table"
		and type(allowed_buffs.buff_families) == "table"
		and type(allowed_buffs.buff_families[family_name]) == "table"
end

-- The talent picker is normally opened in the Mourningstar, where the preview
-- player does not always have a live ability extension. Resolve the equipped
-- Blitz and combat ability from the profile's selected/base talent data so the
-- same class-specific pool used by MissionBuffsSelector remains available.
function Catalog.resolve_profile_abilities(profile)
	if type(profile) ~= "table" then
		return nil, nil
	end

	local archetype = profile.archetype
	local talent_definitions = archetype and archetype.talents

	if type(talent_definitions) ~= "table" then
		return nil, nil
	end

	if archetype.talent_layout_file_path then
		local loadout = {}
		require("scripts/utilities/character_sheet").class_loadout(profile, loadout, false, profile.talents or {}, true)
		local grenade, combat = loadout.grenade_ability, loadout.combat_ability
		return grenade and grenade.name, combat and combat.ability_group
	end

	local grenade_ability
	local combat_ability

	local function inspect(talents)
		if type(talents) ~= "table" then
			return
		end

		for talent_name, tier in pairs(talents) do
			local selected = tier == true or type(tier) == "number" and tier > 0
			local talent = selected and talent_definitions[talent_name]
			local player_ability = talent and talent.player_ability
			local ability = player_ability and player_ability.ability
			local ability_type = player_ability and player_ability.ability_type

			if ability and ability_type == "grenade_ability" and not grenade_ability then
				grenade_ability = ability.name
			elseif ability and ability_type == "combat_ability" and not combat_ability then
				combat_ability = ability.ability_group
			end
		end
	end

	-- Explicit selections take precedence. Base talents only fill an ability
	-- that was not replaced by the current build.
	inspect(profile.talents)
	inspect(archetype.base_talents)

	return grenade_ability, combat_ability
end

function Catalog.infer_family(allowed_buffs, selection)
	local family_names = Catalog.family_names(allowed_buffs)
	local best_family = family_names[1]
	local best_count = 0

	if type(selection) ~= "table" then
		return best_family
	end

	for i = 1, #family_names do
		local family_name = family_names[i]
		local family = allowed_buffs.buff_families[family_name]
		local lookup = {}
		local count = 0

		for _, buff_name in ipairs(family.priority_buffs or {}) do
			lookup[buff_name] = true
		end
		for _, buff_name in ipairs(family.buffs or {}) do
			lookup[buff_name] = true
		end
		for _, buff_name in ipairs(selection) do
			if lookup[buff_name] then
				count = count + 1
			end
		end

		if count > best_count then
			best_count = count
			best_family = family_name
		end
	end

	return best_family
end

function Catalog.all_selectable(allowed_buffs, known_buffs)
	local result = {}
	local lookup = {}
	local sources = {}
	local legendary = allowed_buffs and allowed_buffs.legendary_buffs or {}

	append_family_buffs(result, lookup, allowed_buffs, known_buffs, sources)
	append_unique(result, lookup, legendary.generic, known_buffs, sources, {kind = "generic"})

	for class_name, class_buffs in pairs(legendary) do
		if class_name ~= "generic" and type(class_buffs) == "table" then
			append_unique(result, lookup, class_buffs.generic, known_buffs, sources,
				{kind = "class", archetype = class_name, requirement = "class"})

			for _, buffs in pairs(class_buffs.grenade_ability or {}) do
				append_unique(result, lookup, buffs, known_buffs, sources,
					{kind = "class", archetype = class_name, requirement = "grenade"})
			end

			for _, buffs in pairs(class_buffs.combat_ability or {}) do
				append_unique(result, lookup, buffs, known_buffs, sources,
					{kind = "class", archetype = class_name, requirement = "combat"})
			end

			for _, buffs in pairs(class_buffs.talent_specific or {}) do
				append_unique(result, lookup, buffs, known_buffs, sources,
					{kind = "class", archetype = class_name, requirement = "talent"})
			end
		end
	end

	table.sort(result)

	return result, lookup, sources
end

function Catalog.valid_for_setup(allowed_buffs, known_buffs, setup, family_name)
	local result = {}
	local lookup = {}
	local sources = {}
	local legendary = allowed_buffs and allowed_buffs.legendary_buffs or {}

	if Catalog.is_valid_family(allowed_buffs, family_name) then
		append_family_buffs(result, lookup, allowed_buffs, known_buffs, sources, family_name)
	end
	append_unique(result, lookup, legendary.generic, known_buffs, sources, {
		kind = "generic",
	})

	setup = setup or {}

	local class_buffs = legendary[setup.archetype]

	if type(class_buffs) == "table" then
		append_unique(result, lookup, class_buffs.generic, known_buffs, sources, {
			archetype = setup.archetype,
			kind = "class",
			requirement = "class",
		})
		append_unique(
			result,
			lookup,
			(class_buffs.grenade_ability or {})[setup.grenade_ability],
			known_buffs,
			sources,
			{
				archetype = setup.archetype,
				kind = "class",
				requirement = "grenade",
			}
		)
		append_unique(
			result,
			lookup,
			(class_buffs.combat_ability or {})[setup.combat_ability],
			known_buffs,
			sources,
			{
				archetype = setup.archetype,
				kind = "class",
				requirement = "combat",
			}
		)

		for talent_name, buffs in pairs(class_buffs.talent_specific or {}) do
            local value=setup.talents and setup.talents[talent_name]
            if value==true or type(value)=="number" and value>0 then
				append_unique(result, lookup, buffs, known_buffs, sources, {
					archetype = setup.archetype,
					kind = "class",
					requirement = "talent",
				})
			end
		end
	end

    for i=#result,1,-1 do
        local name=result[i]
        if not Catalog.resource_compatible(name,setup) then table.remove(result,i);lookup[name]=nil;sources[name]=nil end
    end
	table.sort(result)
	return result, lookup, sources
end

function Catalog.filter_valid(selection, known_buffs, valid_buffs, cap)
	local current = Catalog.sanitize(selection, known_buffs, cap)
	local result = {}

	for i = 1, #current do
		local buff_name = current[i]

		if valid_buffs[buff_name] then
			result[#result + 1] = buff_name
		end
	end

	return result
end

function Catalog.sanitize(selection, known_buffs, cap)
	local result = {}
	local seen = {}
	local limit = math.max(0, math.min(math.floor(tonumber(cap) or Catalog.max_selection), Catalog.max_selection))

	if type(selection) ~= "table" then
		return result
	end

	for i = 1, #selection do
		local buff_name = selection[i]

		if #result >= limit then
			break
		end

		if type(buff_name) == "string"
			and buff_name ~= Catalog.none_value
			and (not known_buffs or known_buffs[buff_name])
			and not seen[buff_name]
		then
			seen[buff_name] = true
			result[#result + 1] = buff_name
		end
	end

	return result
end

function Catalog.validate(selection, known_buffs, valid_buffs, cap)
	if type(selection) ~= "table" then
		return nil, "Buff selection is not a table"
	end

	local limit = math.max(0, math.min(math.floor(tonumber(cap) or Catalog.max_selection), Catalog.max_selection))
	local result = {}
	local seen = {}
	local item_count = 0
	local array_length = #selection

	if array_length > limit or array_length > Catalog.max_selection then
		return nil, string.format("Buff selection contains %d entries but the host allows %d", array_length, limit)
	end

	for key in pairs(selection) do
		item_count = item_count + 1

		if item_count > Catalog.max_selection
			or type(key) ~= "number"
			or key % 1 ~= 0
			or key < 1
			or key > array_length
		then
			return nil, "Buff selection contains malformed indexes"
		end
	end

	if item_count ~= array_length then
		return nil, "Buff selection must be a dense array"
	end

	for i = 1, array_length do
		local buff_name = selection[i]

		if type(buff_name) ~= "string" or not known_buffs[buff_name] then
			return nil, "Buff selection contains an unknown Buff"
		end
		if not valid_buffs[buff_name] then
			return nil, string.format("Buff %s is incompatible with the current character setup", buff_name)
		end
		if seen[buff_name] then
			return nil, "Buff selection contains duplicate entries"
		end

		seen[buff_name] = true
		result[#result + 1] = buff_name
	end

	return result
end

function Catalog.add(selection, buff_name, known_buffs, valid_buffs, cap)
	local current = Catalog.sanitize(selection, known_buffs, Catalog.max_selection)
	local limit = math.max(0, math.min(math.floor(tonumber(cap) or Catalog.max_selection), Catalog.max_selection))

	if buff_name == Catalog.none_value or not known_buffs[buff_name] then
		return current, "unknown"
	end
	if not valid_buffs[buff_name] then
		return current, "incompatible"
	end

	for i = 1, #current do
		if current[i] == buff_name then
			return current, "duplicate"
		end
	end

	if #current >= limit then
		return current, "full"
	end

	current[#current + 1] = buff_name

	return current, "added"
end

function Catalog.remove(selection, buff_name, known_buffs)
	local current = Catalog.sanitize(selection, known_buffs, Catalog.max_selection)

	for i = 1, #current do
		if current[i] == buff_name then
			table.remove(current, i)

			return current, "removed"
		end
	end

	return current, "missing"
end

-- Read-only route/legendary pools using the same character filters as native Mortis.
function Catalog.draft_for_setup(allowed, known, setup, data, settings, waves, weights, excluded)
    local pool = { families = Catalog.family_names(allowed), routes = {}, legendary = {}, categories = {},
        wave_weights = settings.filtering_categories_pick_rate_per_wave, legendary_waves = {}, family_weights = weights }
    for _, wave in ipairs(waves.give_legendary_buffs_at_waves) do pool.legendary_waves[wave] = true end
    for _, category in pairs(settings.filtering_categories) do
        pool.categories[#pool.categories + 1] = category; pool.legendary[category] = {}
    end
    table.sort(pool.categories)
    for _, family in ipairs(pool.families) do
        local source = allowed.buff_families[family]
        pool.routes[family] = { priority = Catalog.sanitize(source.priority_buffs, known, Catalog.max_selection), buffs = Catalog.sanitize(source.buffs, known, Catalog.max_selection) }
        for _,list in pairs(pool.routes[family]) do for i=#list,1,-1 do if not Catalog.resource_compatible(list[i],setup) or excluded and excluded[list[i]] then table.remove(list,i) end end end
    end
    for i=#pool.families,1,-1 do
        local name=pool.families[i];local source=allowed.buff_families[name];local route=pool.routes[name]
        if #route.priority==0 and #(source.priority_buffs or {})>0 or #route.priority+#route.buffs==0 then table.remove(pool.families,i) end
    end
    local names = Catalog.valid_for_setup(allowed, known, setup)
    for _, name in ipairs(names) do
        local category = data[name] and data[name].filter_category
        if pool.legendary[category] and not (excluded and excluded[name]) then table.insert(pool.legendary[category], name) end
    end
    return pool
end

return Catalog
