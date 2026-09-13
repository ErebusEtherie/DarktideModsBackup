-- Adapt the per-call loadout only; native definitions and Buff/network IDs stay intact.
local AuraLoadout = {}

local function shallow_copy(source)
	-- Game table.clone recursively invokes the native duplicator, which rejects
	-- metatables in profile/loadout data. Only these containers need local edits.
	local copy = {}
	for key, value in pairs(source) do copy[key] = value end
	return copy
end

function AuraLoadout.build(func, profile, destination, force_base, talents, mute_log)
	local archetype = profile.archetype
	local layout = require(archetype.talent_layout_file_path)
	local auras = {}
	for _, node in ipairs(layout.nodes) do
		if node.type == "aura" and talents[node.talent] and archetype.talents[node.talent]
			and archetype.talents[node.talent].coherency then
			auras[#auras + 1] = node.talent
		end
	end
	if #auras < 2 then return func(profile, destination, force_base, talents, mute_log) end
	table.sort(auras, function(a, b)
		-- The companion-counting aura takes precedence over the native helper that
		-- disables companion coherency. The other auras still supply their Buffs.
		if a == "adamant_companion_coherency" then return b ~= a end
		if b == "adamant_companion_coherency" then return false end
		return a < b
	end)
	local adapted = shallow_copy(profile)
	adapted.archetype = shallow_copy(archetype)
	adapted.archetype.talents = shallow_copy(archetype.talents)
	for i = 2, #auras do
		local name = auras[i]
		local talent = shallow_copy(archetype.talents[name])
		talent.coherency = nil
		if auras[1] == "adamant_companion_coherency"
			and (name == "adamant_reload_speed_aura" or name == "adamant_damage_vs_staggered_aura") then
			talent.passive = nil
			talent.special_rule = nil
		end
		adapted.archetype.talents[name] = talent
	end
	local result = func(adapted, destination, force_base, talents, mute_log)
	if destination.coherency then
		for i = 1, #auras do
			local name = auras[i]
			local buff = archetype.talents[name].coherency.buff_template_name
			if buff then
				if i > 1 then destination.coherency[name] = { buff } end
				if destination.buff_template_tiers and not destination.buff_template_tiers[buff] then
					destination.buff_template_tiers[buff] = talents[name]
				end
			end
		end
	end
	return result
end

return AuraLoadout
