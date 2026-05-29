--[[
Title: Compass Range Finder
Author: Wobin
Date: 27/03/2026
Repository: https://github.com/Wobin/CompassRangeFinder
Version: 1.3
--]]

local mod = get_mod("Compass Range Finder")

mod.version = "1.3"

mod:register_hud_element({
	class_name = "HudElementCompassRangeFinder",
	filename = "Compass Range Finder/scripts/mods/Compass Range Finder/HudElementCompassRangeFinder",
	visibility_groups = {
		"alive",
	},
	use_hud_scale = true,
})

mod.on_all_mods_loaded = function()
	mod:info(mod.version)
end

return mod
