-- Author: defallt
-- Description: HeatPercentage converts the Relic Blade's heat bar into a movable (with Custom Hud) UI element
-- that displays a color-changing heat percentage. The percentage is green until heat reaches 85%, then switches
-- to yellow until the lockout is reached at 100% where it changes to red until the lockout is over.

local mod = get_mod("HeatPercentage")

mod:register_hud_element({
	class_name = "HudElementHeatPercentage",
	filename = "HeatPercentage/scripts/mods/HeatPercentage/HudElementHeatPercentage",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
	},
})
