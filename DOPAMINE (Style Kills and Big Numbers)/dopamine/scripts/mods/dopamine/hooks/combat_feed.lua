---@type mod
local mod = get_mod("dopamine")

if mod.combat_feed then
	return mod.combat_feed
end

local function should_hide_vanilla_combat_feed()
	if not mod:is_enabled() or mod.dl.settings.killfeed_disable == "off" then
		return false
	end

	if not mod.dl.gameplay.in_gameplay() then
		return false
	end

	return true
end

mod.dl.game_hooks.hook(CLASS.HudElementCombatFeed, "_enabled", function(func, self)
	if should_hide_vanilla_combat_feed() then
		return false
	end

	return func(self)
end)

local CombatFeed = {}

mod.combat_feed = CombatFeed

return CombatFeed
