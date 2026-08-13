

---@type mod
local mod = get_mod("dopamine")

if mod.event_resolver then
	return mod.event_resolver
end

local EventRegistry = mod:core(mod.event_registry, "utils/event/registry")

---@param definition_a Event
---@param definition_b Event
---@return boolean
local function can_coexist(definition_a, definition_b)
	if definition_a.id == definition_b.id then
		return false
	end

	if definition_a.always_coexist or definition_b.always_coexist then
		return true
	end

	if definition_a.exclusive_group and definition_a.exclusive_group == definition_b.exclusive_group then
		return false
	end

	local coexist_list_a = definition_a.can_coexist
	local coexist_list_b = definition_b.can_coexist

	if coexist_list_a then
		for i = 1, #coexist_list_a do
			if coexist_list_a[i] == definition_b.id then
				return true
			end
		end
	end

	if coexist_list_b then
		for i = 1, #coexist_list_b do
			if coexist_list_b[i] == definition_a.id then
				return true
			end
		end
	end

	return false
end

---@param candidates Event[]
---@return Event[]
local function pick_exclusive_winners(candidates)
	local winners = {}
	local best_by_group = {}

	for i = 1, #candidates do
		local definition = candidates[i]
		local group = definition.exclusive_group

		if not group then
			winners[#winners + 1] = definition
		else
			local best = best_by_group[group]
			if not best or (definition.priority or 0) > (best.priority or 0) then
				best_by_group[group] = definition
			end
		end
	end

	for _, definition in pairs(best_by_group) do
		winners[#winners + 1] = definition
	end

	return winners
end

---@param candidates Event[]
---@return Event[]
local function filter_coexistence(candidates)
	local kept = {}

	for i = 1, #candidates do
		local definition = candidates[i]

		for kept_index = #kept, 1, -1 do
			if not can_coexist(definition, kept[kept_index]) then
				if (definition.priority or 0) >= (kept[kept_index].priority or 0) then
					table.remove(kept, kept_index)
				end
			end
		end

		local keep_definition = true
		for kept_index = 1, #kept do
			if
				not can_coexist(definition, kept[kept_index])
				and (definition.priority or 0) < (kept[kept_index].priority or 0)
			then
				keep_definition = false
				break
			end
		end

		if keep_definition then
			kept[#kept + 1] = definition
		end
	end

	table.sort(kept, function(definition_a, definition_b)
		return (definition_a.priority or 0) > (definition_b.priority or 0)
	end)

	return kept
end

---@class EventResolver
local EventResolver = {}

---@param context EventContext
---@param signal_name SignalID
---@return EventID[]
function EventResolver.resolve(context, signal_name)
	local candidates = {}
	local all_definitions = EventRegistry.all()

	for i = 1, #all_definitions do
		local definition = all_definitions[i]

		if EventRegistry.listens_to(definition, signal_name) then
			local ok, matched = pcall(definition.matches, context)

			if not ok then
				mod:error(
				"event '%s' matches() errored on signal '%s': %s",
					definition.id,
					tostring(signal_name),
					tostring(matched)
				)
			elseif matched then
				candidates[#candidates + 1] = definition
			end
		end
	end

	if #candidates == 0 then
		return {}
	end

	local winners = pick_exclusive_winners(candidates)
	local resolved = filter_coexistence(winners)
	local event_ids = {}

	for i = 1, #resolved do
		event_ids[#event_ids + 1] = resolved[i].id
	end

	return event_ids
end

mod.event_resolver = EventResolver

return EventResolver
