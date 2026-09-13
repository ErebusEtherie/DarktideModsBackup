-- Combine audited effects on the current player only. No new Buff templates,
-- network lookup entries, global talent edits, or per-frame unit scans.
local Effects = {}
local MARK_STACKS = "psyker_marked_enemies_passive_bonus_stacking_increased_stacks"

local function shallow_copy(source)
	local copy = {}
	for key, value in pairs(source) do copy[key] = value end
	return copy
end

function Effects.companion_profile(profile, talents, rules)
	if not rules.keep_companion(talents) then return profile end
	local archetype = profile.archetype
	local definition = archetype and archetype.talents and archetype.talents.adamant_disable_companion
	if not definition then return profile end
	-- The native passive still grants its stats, grenade capacity and refill.
	-- _apply_talents then performs its normal companion reset/spawn after all
	-- passives have started. Only the disabling rule is omitted from this call.
	local adapted = shallow_copy(profile)
	adapted.archetype = shallow_copy(archetype)
	adapted.archetype.talents = shallow_copy(archetype.talents)
	local talent = shallow_copy(definition)
	talent.special_rule = nil
	adapted.archetype.talents.adamant_disable_companion = talent
	return adapted
end

function Effects.install(mod)
	-- DMF may replay require callbacks for the same class object.
	local hooked = setmetatable({}, { __mode = "k" })
	mod:hook_require("scripts/extension_systems/buff/buffs/buff", function(Buff)
		if hooked[Buff] then return end
		mod:hook(Buff, "duration", function(func, self)
			local duration = func(self)
			if not duration or self._template.name ~= MARK_STACKS or not mod:is_enabled() then return duration end
			local unit = self._template_context and self._template_context.unit
			local talent = unit and ScriptUnit.has_extension(unit, "talent_system")
			-- The host's applied talents, including native rpc_update_talents on
			-- the owning client, decide this; client preferences are never consulted.
			if talent and talent._tpm_combined_upgrades
				and talent:has_special_rule("psyker_mark_increased_max_stacks")
				and talent:has_special_rule("psyker_mark_increased_duration") then
				return duration + 5
			end
			return duration
		end)
		hooked[Buff] = true
	end)
end

return Effects
