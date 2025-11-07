--[[
    Author: Igromanru
    Mod Name: Remove Tag Skulls
    Version: 1.2.0
]]
local mod = get_mod("RemoveTagSkulls")

local SettingNames = mod:io_dofile("RemoveTagSkulls/scripts/setting_names")

local function ShouldFilterDaemonhost(marker)
    if marker and mod:get(SettingNames.KeepDaemonhostMarker) then
        local unit_data_extension = ScriptUnit.extension(marker.unit, "unit_data_system")
        if unit_data_extension and unit_data_extension:breed_name() == "chaos_daemonhost" then
            return false
        end
    end
    return true
end

mod:hook_require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_unit_threat", function(instance)
	mod:hook(instance, "on_enter", function(func, widget, marker, template)
        if mod:get(SettingNames.RemoveTagSkull) then
            if marker and ShouldFilterDaemonhost(marker) then
                marker.template.max_distance = 0
            end
        end

		return func(widget, marker, template)
	end)
end)

mod:hook_require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_unit_threat_veteran", function(instance)
	mod:hook(instance, "on_enter", function(func, widget, marker, template)
        if mod:get(SettingNames.RemoveVeteranTagSkull) then
            if marker and ShouldFilterDaemonhost(marker) then
                marker.template.max_distance = 0
            end
        end

		return func(widget, marker, template)
	end)
end)

mod:hook_require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_unit_threat_adamant", function(instance)
	mod:hook(instance, "on_enter", function(func, widget, marker, template)
        if mod:get(SettingNames.RemoveAdamantTagSkull) then
            if marker and ShouldFilterDaemonhost(marker) then
                marker.template.max_distance = 0
            end
        end

		return func(widget, marker, template)
	end)
end)