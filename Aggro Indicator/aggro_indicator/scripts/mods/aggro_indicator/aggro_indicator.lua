local mod = get_mod("aggro_indicator")

mod:io_dofile("aggro_indicator/scripts/mods/aggro_indicator/aggro_detection")

mod:add_require_path("aggro_indicator/scripts/mods/aggro_indicator/hud/hud_element_aggro_indicator")

mod:hook("UIHud", "init", function(func, self, elements, visibility_groups, params)
    if not table.find_by_key(elements, "class_name", "HudElementAggroIndicator") then
        table.insert(elements, {
            class_name = "HudElementAggroIndicator",
            filename = "aggro_indicator/scripts/mods/aggro_indicator/hud/hud_element_aggro_indicator",
            use_hud_scale = true,
            visibility_groups = {
                "alive",
                "communication_wheel"
            },
        })
    end
    return func(self, elements, visibility_groups, params)
end)

mod.on_setting_changed = function(setting_id)
    if setting_id == "indicator_offset_x" or setting_id == "indicator_offset_y" or setting_id == "indicator_horizontal_alignment" or setting_id == "indicator_vertical_alignment" then
        local ui_manager = Managers.ui
        if ui_manager and ui_manager._hud and ui_manager._hud._elements then
            local aggro_indicator = ui_manager._hud._elements["HudElementAggroIndicator"]
            if aggro_indicator then
                local offset_x = mod:get("indicator_offset_x") or -30
                local offset_y = mod:get("indicator_offset_y") or 0
                local horiz_align = mod:get("indicator_horizontal_alignment") or "center"
                local vert_align = mod:get("indicator_vertical_alignment") or "center"
                aggro_indicator:set_scenegraph_position("aggro_indicator_anchor", offset_x, offset_y, 100, horiz_align, vert_align)
            end
        end
    end
end

mod.on_disabled = function(is_first_call)
    local aggro_detection = mod:io_dofile("aggro_indicator/scripts/mods/aggro_indicator/aggro_detection")
    if aggro_detection and aggro_detection.clear then
        aggro_detection.clear()
    end
end
