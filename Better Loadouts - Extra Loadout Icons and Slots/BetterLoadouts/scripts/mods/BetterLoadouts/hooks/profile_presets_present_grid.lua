-- File: scripts/mods/BetterLoadouts/hooks/profile_presets_present_grid.lua

local mod = get_mod("BetterLoadouts")
if not mod then
    return
end

local ViewElementProfilePresetsSettings = require(
    "scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings"
)
local ProfileUtils = require("scripts/utilities/profile_utils")

require("scripts/foundation/utilities/table")

local s_format = string.format
local t_clear_array = table.clear_array
local t_append = table.append

-- UTF-8 encoder
local bytemarkers = {
    { 0x7FF,    192 },
    { 0xFFFF,   224 },
    { 0x1FFFFF, 240 },
}

local function utf8(decimal)
    if decimal < 128 then
        return string.char(decimal)
    end

    local charbytes = {}

    for bytes = 1, #bytemarkers do
        local vals = bytemarkers[bytes]

        if decimal <= vals[1] then
            for b = bytes + 1, 2, -1 do
                local rem = decimal % 64
                decimal = (decimal - rem) / 64
                charbytes[b] = string.char(128 + rem)
            end

            charbytes[1] = string.char(vals[2] + decimal)
            break
        end
    end

    return table.concat(charbytes)
end

-- Private preset-icons pool (local copy)
local PRIVATE_ICON_LOOKUP, PRIVATE_ICON_KEYS = {}, {}

local function _register_private(list)
    for i = 1, #list do
        local key = list[i]
        if key and not PRIVATE_ICON_LOOKUP[key] then
            PRIVATE_ICON_LOOKUP[key] = key
            PRIVATE_ICON_KEYS[#PRIVATE_ICON_KEYS + 1] = key
        end
    end
end

local function _seed_private_from_vanilla_then_custom()
    local S = ViewElementProfilePresetsSettings
    local ref = S and S.optional_preset_icon_reference_keys or {}
    local lu = S and S.optional_preset_icons_lookup or {}

    for i = 1, #ref do
        local vk = ref[i]
        local vmat = lu[vk]
        if vk and vmat and not PRIVATE_ICON_LOOKUP[vk] then
            PRIVATE_ICON_LOOKUP[vk] = vmat
            PRIVATE_ICON_KEYS[#PRIVATE_ICON_KEYS + 1] = vk
        end
    end

    _register_private(mod.BL.DEFAULT_CUSTOM_ICON_PATHS)
end

_seed_private_from_vanilla_then_custom()

local function make_unicode(cp)
    local key = s_format("unicode:%X", cp)

    return {
        widget_type = "unicode_icon",
        text = utf8(cp),
        icon_key = key,
    }
end

local function make_text_icon(key, text)
    return {
        widget_type = "text_icon",
        text = text,
        icon_key = key,
    }
end

local function make_color_swatch(entry, current_key)
    return {
        widget_type = "betterloadouts_color_swatch",
        color_key = entry.key,
        color = entry.color,
        current_key = current_key,
    }
end

-- Hook: build & present the tooltip grid layout (icons + unicode + text)
mod:hook(CLASS.ViewElementProfilePresets, "_present_tooltip_grid_layout", function(func, self, layout)
    mod.position_preset_tooltip(self)

    -- Build a fresh layout from the private pool, but keep the delete button
    -- (if present) from the original layout.
    local icons = self._vp_icons or (Script and Script.new_array and Script.new_array(64)) or {}
    local delete_entry = nil

    t_clear_array(icons, #icons)
    self._vp_icons = icons

    local current_color_key
    local customize_index = self._active_customize_preset_index
    if customize_index then
        local profile_preset_id = self:_get_profile_preset_id_by_widget_index(customize_index)
        local profile_preset = ProfileUtils.get_profile_preset(profile_preset_id)
        current_color_key = profile_preset and profile_preset.betterloadouts_color_key
    end

    for i = 1, #layout do
        local e = layout[i]
        if e.delete_button or e.widget_type == "dynamic_button" then
            delete_entry = e
        end
    end

    -- Add private material icons first
    for i = 1, #PRIVATE_ICON_KEYS do
        local key = PRIVATE_ICON_KEYS[i]
        local mat = PRIVATE_ICON_LOOKUP[key]

        if mat then
            icons[#icons + 1] = {
                widget_type = "icon",
                icon_key = key,
                icon = mat,
            }
        end
    end

    -- Add extra unicode + any global codes
    for i = 1, #mod.BL.UNICODE_EXTRA_CODES do
        icons[#icons + 1] = make_unicode(mod.BL.UNICODE_EXTRA_CODES[i])
    end

    local G = _G.UNICODE_PRESET_CODES
    if G then
        for i = 1, #G do
            icons[#icons + 1] = make_unicode(G[i])
        end
    end

    -- Add short text icons last
    for i = 1, #mod.BL.TEXT_PRESET_ICONS do
        local entry = mod.BL.TEXT_PRESET_ICONS[i]
        if entry and entry.key and entry.text then
            icons[#icons + 1] = make_text_icon(entry.key, entry.text)
        end
    end

    -- Build final layout (header/spacing were already in the original 'layout')
    local grid_w = 225
    do
        local sg2 = self._definitions and self._definitions.scenegraph_definition
        local node = sg2 and sg2.profile_preset_tooltip_grid
        if node and node.size then
            grid_w = node.size[1] or grid_w
        end
    end

    local spacing_proto = self._vp_spacing_proto or { widget_type = "dynamic_spacing", size = { 0, 10 } }
    spacing_proto.size[1] = grid_w
    self._vp_spacing_proto = spacing_proto

    local new_layout = { spacing_proto }

    for i = 1, #mod.BL.PRESET_COLORS do
        new_layout[#new_layout + 1] = make_color_swatch(mod.BL.PRESET_COLORS[i], current_color_key)
    end

    new_layout[#new_layout + 1] = spacing_proto

    t_append(new_layout, icons)
    new_layout[#new_layout + 1] = spacing_proto

    if delete_entry then
        new_layout[#new_layout + 1] = delete_entry
    end

    new_layout[#new_layout + 1] = spacing_proto

    local defs2 = self._definitions
    local blueprints2 = defs2 and defs2.profile_preset_grid_blueprints
    local grid_obj = self._profile_preset_tooltip_grid

    if grid_obj and blueprints2 then
        grid_obj:present_grid_layout(
            new_layout,
            blueprints2,
            callback(self, "cb_on_profile_preset_icon_grid_left_pressed"),
            nil,
            nil,
            nil,
            callback(self, "cb_on_profile_preset_icon_grid_layout_changed"),
            nil
        )

        local profile_preset
        if customize_index then
            local profile_preset_id = self:_get_profile_preset_id_by_widget_index(customize_index)
            profile_preset = ProfileUtils.get_profile_preset(profile_preset_id)
        end
        mod.sync_preset_customization_selection(self, profile_preset)

    end
end)
