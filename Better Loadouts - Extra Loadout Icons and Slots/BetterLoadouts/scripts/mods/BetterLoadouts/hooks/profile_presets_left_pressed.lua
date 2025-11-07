-- File: scripts/mods/BetterLoadouts/hooks/profile_presets_left_pressed.lua

local mod = get_mod("BetterLoadouts")
if not mod then return end

local ProfileUtils = require("scripts/utilities/profile_utils")
local ViewElementProfilePresetsSettings = require(
    "scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings"
)

require("scripts/foundation/utilities/math")
require("scripts/foundation/utilities/table")

local s_sub = string.sub

-- UTF-8 encoder
local bytemarkers = { { 0x7FF, 192 }, { 0xFFFF, 224 }, { 0x1FFFFF, 240 } }
local function utf8(decimal)
    if decimal < 128 then return string.char(decimal) end
    local charbytes = {}
    for bytes, vals in ipairs(bytemarkers) do
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

-- Private icon lookup (local copy; same content as other files)
local PRIVATE_ICON_LOOKUP = {}

local function _seed_lookup()
    local S   = ViewElementProfilePresetsSettings
    local ref = S and S.optional_preset_icon_reference_keys or {}
    local lu  = S and S.optional_preset_icons_lookup or {}

    for i = 1, #ref do
        local vk   = ref[i]
        local vmat = lu[vk]
        if vk and vmat and not PRIVATE_ICON_LOOKUP[vk] then
            PRIVATE_ICON_LOOKUP[vk] = vmat
        end
    end

    for i = 1, #mod.BL.DEFAULT_CUSTOM_ICON_PATHS do
        local key = mod.BL.DEFAULT_CUSTOM_ICON_PATHS[i]
        if key and not PRIVATE_ICON_LOOKUP[key] then
            PRIVATE_ICON_LOOKUP[key] = key -- material path == key
        end
    end
end

_seed_lookup()

-- Hook: handle clicks on an icon tile (set unicode or material, or delete)
mod:hook(CLASS.ViewElementProfilePresets, "cb_on_profile_preset_icon_grid_left_pressed",
    function(func, self, widget, element)
        if element and element.delete_button then
            if func then return func(self, widget, element) end
            if self._remove_profile_preset then return self:_remove_profile_preset(widget, element) end
            return
        end

        local icon_key = element and element.icon_key
        if not icon_key then
            if func then return func(self, widget, element) end
            return
        end

        local index = self._active_customize_preset_index
        if not index then return end
        local profile_preset_id = self:_get_profile_preset_id_by_widget_index(index)
        local profile_preset = ProfileUtils.get_profile_preset(profile_preset_id)
        if not profile_preset then return end

        -- Clear selection/highlight from the grid
        local grid = self._profile_preset_tooltip_grid
        local widgets = grid and grid:widgets()
        if widgets then
            for i = 1, #widgets do
                local c = widgets[i].content
                if c then
                    c.equipped = false
                    c.force_glow = false
                    if c.hotspot then
                        c.hotspot.is_selected = false
                        c.hotspot.is_focused  = false
                    end
                end
            end
        end

        local buttons = self._profile_buttons_widgets
        local btn = buttons and buttons[index]

        -- Unicode tile
        if s_sub(icon_key, 1, 8) == "unicode:" then
            local hex = s_sub(icon_key, 9)
            local cp  = tonumber(hex, 16)
            local ch  = (element and element.text and element.text ~= "") and element.text or utf8(cp)
            if btn then
                btn.content.unicode = ch
                btn.content.icon    = nil
                if btn.style and btn.style.icon and btn.style.icon.color then
                    btn.style.icon.color[1] = 0
                end
            end
            profile_preset.custom_icon_key = icon_key
            Managers.save:queue_save()
            return
        end

        -- Non-unicode: prefer PRIVATE lookup ...
        local default_icon = PRIVATE_ICON_LOOKUP[icon_key]
        if default_icon and btn then
            local content   = btn.content
            content.icon    = default_icon
            content.unicode = nil
            if btn.style and btn.style.icon and btn.style.icon.color then
                btn.style.icon.color[1] = 255
            end
            profile_preset.custom_icon_key = icon_key
            Managers.save:queue_save()
            return
        end

        -- ...fallback to treating icon_key as a direct material path.
        if type(icon_key) == "string" and btn then
            local content   = btn.content
            content.icon    = icon_key
            content.unicode = nil
            if btn.style and btn.style.icon and btn.style.icon.color then
                btn.style.icon.color[1] = 255
            end
            profile_preset.custom_icon_key = icon_key
            Managers.save:queue_save()
            return
        end

        -- If none of the above, pass through to vanilla.
        if func then return func(self, widget, element) end
    end)
