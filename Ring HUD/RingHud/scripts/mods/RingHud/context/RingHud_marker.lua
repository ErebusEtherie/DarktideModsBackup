-- File: RingHud/scripts/mods/RingHud/context/RingHud_marker.lua
local mod = get_mod("RingHud")
if not mod then return end

local UIWidget = require("scripts/managers/ui/ui_widget")
local template = {}

template.name = "RingHud_ItemTrackerMarker"
template.unit_node = "ui_marker"
template.max_distance = 200
template.min_distance = 0
template.evolve_distance = 1

template.scale_settings = {
    scale_from = 1,
    scale_to = 1,
    distance_max = template.max_distance,
    distance_min = template
        .max_distance,
    easing_function = math.linear
}
template.fade_settings = {
    default_fade = 1,
    fade_from = 1,
    fade_to = 1,
    distance_max = template.max_distance,
    distance_min =
        template.max_distance,
    easing_function = math.linear
}

template.create_widget_defintion = function(template_arg, scenegraph_id)
    local empty_style = { size = { 1, 1 }, color = { 0, 0, 0, 0 }, offset = { 0, 0, 0 }, visibility = false }
    local empty_text_style = { size = { 1, 1 }, color = { 0, 0, 0, 0 }, offset = { 0, 0, 0 }, visibility = false, font_size = 1, text_color = { 0, 0, 0, 0 } }

    local pass_definitions = {
        { value = "",          value_id = "rh_tracker_pass", pass_type = "texture",            style = { size = { 1, 1 }, color = { 0, 0, 0, 0 }, visibility = false } },
        -- the rest are dummy passes to ensure compat with other mods
        { pass_type = "logic", style_id = "ring",            value_id = "compat_ring",         style = table.clone(empty_style) },
        { pass_type = "logic", style_id = "icon",            value_id = "compat_icon",         style = table.clone(empty_style) },
        { pass_type = "logic", style_id = "background",      value_id = "compat_background",   style = table.clone(empty_style) },
        { pass_type = "logic", style_id = "marker_text",     value_id = "compat_marker_text",  style = table.clone(empty_text_style) },
        { pass_type = "text",  style_id = "remaining_count", value_id = "remaining_count",     style = table.clone(empty_text_style) }, -- Decoy pass for Ration Pack compatibility
        { pass_type = "logic", style_id = "field_improv",    value_id = "compat_field_improv", style = table.clone(empty_style) }
    }

    local content_overrides = {
        remaining_count = "", -- Initialize content for the Ration Pack decoy pass
    }

    return UIWidget.create_definition(pass_definitions, scenegraph_id, content_overrides)
end

template.on_enter = function(widget)
    widget.content.spawn_progress_timer = 0
    widget.content.icon = ""
    widget.content.field_improv = ""
    widget.content.marker_text = ""
    widget.content.tagged = false
    widget.content.arrow = nil
end

template.update_function = function(parent, ui_renderer, widget, marker, template_ref, dt, t)
    -- Compatibility logic for Ration Pack.
    -- This runs on the first update for each marker instance, after all other mods
    -- have had a chance to run their initialization hooks.
    if not widget.content.ringhud_pass_neutralized then
        if widget.passes then
            for i, pass in ipairs(widget.passes) do
                if pass.style_id == "remaining_count" then
                    -- This is the pass. Overwrite its functions to ensure it's never visible and never updated.
                    pass.visibility_function = function() return false end
                    pass.change_function = nil

                    -- Also force the style to be invisible as a final guarantee.
                    if widget.style and widget.style.remaining_count then
                        local style = widget.style.remaining_count
                        style.visible = false
                        style.font_size = 0
                        if style.text_color then style.text_color[1] = 0 end
                    end
                    break
                end
            end
        end
        widget.content.ringhud_pass_neutralized = true -- Set flag so this logic only runs once.
    end

    -- Original update logic from RingHud
    local animating = false
    local content = widget.content
    local distance = content.distance
    local data = marker.data

    if data then
        data.distance = distance
    end

    return animating
end

return template
