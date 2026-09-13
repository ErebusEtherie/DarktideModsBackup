-- File: scripts/mods/BetterLoadouts/preset_colors.lua

local mod = get_mod("BetterLoadouts")
if not mod then
    return
end

local DEFAULT_ICON_COLOR = { 255, 255, 255, 255 }

mod.BL.PRESET_COLORS = {
    { color = DEFAULT_ICON_COLOR },
    { key = "crimson", color = { 255, 220, 68, 68 } },
    { key = "orange",  color = { 255, 238, 132, 55 } },
    { key = "gold",    color = { 255, 235, 202, 69 } },
    { key = "lime",    color = { 255, 153, 218, 76 } },
    { key = "green",   color = { 255, 74, 190, 112 } },
    { key = "teal",    color = { 255, 66, 194, 180 } },
    { key = "cyan",    color = { 255, 78, 202, 230 } },
    { key = "blue",    color = { 255, 86, 137, 224 } },
    { key = "violet",  color = { 255, 143, 105, 224 } },
    { key = "magenta", color = { 255, 211, 91, 196 } },
    { key = "grey",    color = { 255, 128, 128, 128 } },
}

mod.BL.PRESET_COLOR_LOOKUP = Script.new_map(#mod.BL.PRESET_COLORS - 1)

for i = 1, #mod.BL.PRESET_COLORS do
    local entry = mod.BL.PRESET_COLORS[i]
    if entry.key then
        mod.BL.PRESET_COLOR_LOOKUP[entry.key] = entry.color
    end
end

local function _write_color(target, source)
    if not target then
        target = { 255, 255, 255, 255 }
    end

    target[1] = source[1]
    target[2] = source[2]
    target[3] = source[3]
    target[4] = source[4]

    return target
end

local function _set_icon_style_color(icon_style, color, visible)
    if not icon_style then
        return
    end

    icon_style.color = _write_color(icon_style.color, color)
    icon_style.default_color = _write_color(icon_style.default_color, color)
    icon_style.hover_color = _write_color(icon_style.hover_color, color)
    icon_style.selected_color = _write_color(icon_style.selected_color, color)

    local alpha = visible and 255 or 0

    icon_style.color[1] = alpha
    icon_style.default_color[1] = alpha
    icon_style.hover_color[1] = alpha
    icon_style.selected_color[1] = alpha
end

function mod.BL.preset_color_for_key(key)
    return key and mod.BL.PRESET_COLOR_LOOKUP[key] or nil
end

function mod.apply_preset_color(widget, profile_preset)
    if not widget then
        return
    end

    local content = widget.content
    local style = widget.style
    if not content or not style then
        return
    end

    local color_key = profile_preset and profile_preset.betterloadouts_color_key
    local custom_color = mod.BL.preset_color_for_key(color_key)

    if color_key and not custom_color and profile_preset then
        profile_preset.betterloadouts_color_key = nil
        color_key = nil
    end

    local icon_color = custom_color or DEFAULT_ICON_COLOR
    local is_text = content.custom_text ~= nil and content.custom_text ~= ""
    local is_unicode = content.unicode ~= nil and content.unicode ~= ""
    local has_material_icon = content.icon ~= nil and not is_text and not is_unicode

    content.betterloadouts_color_key = custom_color and color_key or nil
    content.betterloadouts_icon_color = _write_color(content.betterloadouts_icon_color, icon_color)

    _set_icon_style_color(style.icon, icon_color, has_material_icon)

    local unicode_style = style.unicode
    if unicode_style then
        unicode_style.text_color = _write_color(unicode_style.text_color, icon_color)
    end

    local custom_text_style = style.custom_text
    if custom_text_style then
        custom_text_style.text_color = _write_color(custom_text_style.text_color, icon_color)
    end
end

function mod.sync_preset_customization_selection(self, profile_preset, navigation_group)
    local grid = self and self._profile_preset_tooltip_grid
    local widgets = grid and grid:widgets()
    if not widgets then
        return
    end

    if navigation_group == "icon" or navigation_group == "color" then
        self._betterloadouts_picker_navigation_group = navigation_group
    else
        navigation_group = self._betterloadouts_picker_navigation_group or "icon"
    end

    local current_icon_key = profile_preset and profile_preset.custom_icon_key
    local current_color_key = profile_preset and profile_preset.betterloadouts_color_key
    local current_icon_key_lower = type(current_icon_key) == "string" and string.lower(current_icon_key) or nil

    for i = 1, #widgets do
        local content = widgets[i].content
        local element = content and content.element
        local hotspot = content and content.hotspot

        if element and element.widget_type == "betterloadouts_color_swatch" then
            local selected = element.color_key == current_color_key

            content.betterloadouts_color_selected = selected
            content.equipped = navigation_group == "color" and selected
            content.force_glow = false
            content.current_key = current_color_key
            element.current_key = current_color_key

            if hotspot then
                hotspot.is_selected = navigation_group == "color" and selected
                hotspot.is_focused = false
            end
        elseif element and element.icon_key then
            local icon_key = element.icon_key
            local selected = current_icon_key_lower ~= nil
                and type(icon_key) == "string"
                and string.lower(icon_key) == current_icon_key_lower

            content.equipped = navigation_group == "icon" and selected
            content.force_glow = selected
            content.current_key = current_icon_key
            element.current_key = current_icon_key

            if hotspot then
                hotspot.is_selected = navigation_group == "icon" and selected
                hotspot.is_focused = false
            end
        elseif content then
            content.equipped = false
            content.force_glow = false

            if hotspot then
                hotspot.is_selected = false
                hotspot.is_focused = false
            end
        end
    end
end
