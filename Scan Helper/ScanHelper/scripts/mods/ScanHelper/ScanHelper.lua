local mod = get_mod("ScanHelper")

local scannable_units = {}

local _set_outline_and_highlight = function(active)
    for i = 1, #scannable_units do
        local scannable_unit = scannable_units[i]
        local scannable_extension = ScriptUnit.has_extension(scannable_unit, "mission_objective_zone_scannable_system")

        if scannable_extension then
            local is_active = scannable_extension:is_active()

            if is_active then
                scannable_extension:set_scanning_outline(active)
                scannable_extension:set_scanning_highlight(active)
            end
        end
    end
end

mod:hook_safe(CLASS.AuspexScanningEffects, "init", function (...)
    local mission_objective_zone_system = Managers.state.extension:system("mission_objective_zone_system")
    local current_scan_mission_zone = mission_objective_zone_system:current_active_zone()

    if not current_scan_mission_zone then
        return
    end

    scannable_units = current_scan_mission_zone:scannable_units()

    _set_outline_and_highlight(true)
end)

