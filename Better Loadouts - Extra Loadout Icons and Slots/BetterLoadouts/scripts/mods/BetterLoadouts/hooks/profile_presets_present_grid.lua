-- File: scripts/mods/BetterLoadouts/hooks/profile_presets_present_grid.lua

local mod = get_mod("BetterLoadouts")
if not mod then return end

local ProfileUtils = require("scripts/utilities/profile_utils")
local ViewElementProfilePresetsSettings = require(
    "scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings"
)

require("scripts/foundation/utilities/math")
require("scripts/foundation/utilities/table")

local s_lower, s_sub, s_format = string.lower, string.sub, string.format
local t_clear_array = table.clear_array
local t_append = table.append

-- Layout helper
local function _layout()
    return mod.BL.layout_for_limit(mod.preset_limit or 28)
end

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
    local S   = ViewElementProfilePresetsSettings
    local ref = S and S.optional_preset_icon_reference_keys or {}
    local lu  = S and S.optional_preset_icons_lookup or {}

    for i = 1, #ref do
        local vk   = ref[i]
        local vmat = lu[vk]
        if vk and vmat and not PRIVATE_ICON_LOOKUP[vk] then
            PRIVATE_ICON_LOOKUP[vk] = vmat
            PRIVATE_ICON_KEYS[#PRIVATE_ICON_KEYS + 1] = vk
        end
    end

    _register_private(mod.BL.DEFAULT_CUSTOM_ICON_PATHS)
end

_seed_private_from_vanilla_then_custom()

-- Small helper to nudge the ViewElementGrid scrollbar on the tooltip grid
local function _nudge_grid_scrollbar(grid_obj, dx)
    if not grid_obj or not grid_obj._ui_scenegraph then return end
    local names = { "grid_scrollbar", "scrollbar" }
    for i = 1, #names do
        local id   = names[i]
        local node = grid_obj._ui_scenegraph[id]
        if node and node.position then
            local x = (node.position[1] or 0) + (dx or 0)
            local y = node.position[2] or 0
            local z = node.position[3] or 13
            if grid_obj._set_scenegraph_position then
                grid_obj:_set_scenegraph_position(id, x, y, z)
            elseif grid_obj._ui_scenegraph and grid_obj._ui_scenegraph[id] then
                grid_obj._ui_scenegraph[id].position[1] = x
                grid_obj._ui_scenegraph[id].position[2] = y
                grid_obj._ui_scenegraph[id].position[3] = z
            end
            if grid_obj._force_update_scenegraph then
                grid_obj:_force_update_scenegraph()
            end
            return true
        end
    end
end

-- Hook: build & present the tooltip grid layout (icons + unicode)
mod:hook(CLASS.ViewElementProfilePresets, "_present_tooltip_grid_layout", function(func, self, layout)
    local L           = _layout()

    local ty, tz      = 0, 1
    local tooltip_def = self._definitions and self._definitions.scenegraph_definition and
        self._definitions.scenegraph_definition.profile_preset_tooltip
    if tooltip_def and tooltip_def.position then
        ty = tooltip_def.position[2] or 0
        tz = tooltip_def.position[3] or 1
    end

    local panel_node = self._ui_scenegraph and self._ui_scenegraph.profile_preset_button_panel
    local panel_w = (panel_node and panel_node.size and panel_node.size[1])
        or (L.BUTTON_WIDTH * 2 + L.COLUMN_GAP)
    local x = -(panel_w + (L.SAFE_GAP or 40))

    -- If LoadoutNames is installed, move our tooltip panel + grid DOWN to clear it
    local ln = get_mod and get_mod("LoadoutNames")
    if ln then
        local sgN = self._ui_scenegraph
        local function bottom(n)
            if not (n and n.position and n.size) then return nil end
            return (n.position[2] or 0) + (n.size[2] or 0)
        end
        local b1 = sgN and bottom(sgN.loadout_name_tbox_area)
        local b2 = sgN and bottom(sgN.loadout_name_tooltip_area)
        local ln_bottom = math.max(b1 or -math.huge, b2 or -math.huge)
        if ln_bottom > -math.huge then
            local GAP_Y = 16
            ty = math.max(ty, ln_bottom + GAP_Y)
        end
    end

    self:_set_scenegraph_position("profile_preset_tooltip", x + 12, ty, tz)
    self:_force_update_scenegraph()

    -- Build a fresh layout from the PRIVATE pool (vanilla first, then custom),
    -- but keep the delete button (if present) from the original layout.
    local icons, delete_entry = self._vp_icons or (Script and Script.new_array and Script.new_array(64)) or {}, nil
    t_clear_array(icons, #icons)
    self._vp_icons = icons

    for i = 1, #layout do
        local e = layout[i]
        if e.delete_button or e.widget_type == "dynamic_button" then
            delete_entry = e
        end
    end

    -- Add private icons
    for i = 1, #PRIVATE_ICON_KEYS do
        local key = PRIVATE_ICON_KEYS[i]
        local mat = PRIVATE_ICON_LOOKUP[key]
        if mat then
            icons[#icons + 1] = { widget_type = "icon", icon_key = key, icon = mat }
        end
    end

    -- Add extra unicode + any global codes
    local function make_unicode(cp)
        local key = s_format("unicode:%X", cp)
        return { widget_type = "unicode_icon", text = utf8(cp), icon_key = key }
    end
    for i = 1, #mod.BL.UNICODE_EXTRA_CODES do
        icons[#icons + 1] = make_unicode(mod.BL.UNICODE_EXTRA_CODES[i])
    end
    local G = _G.UNICODE_PRESET_CODES
    if G then
        for i = 1, #G do
            icons[#icons + 1] = make_unicode(G[i])
        end
    end

    -- Build final layout (header/spacing were already in the original 'layout')
    local grid_w = 225
    do
        local sg2 = self._definitions and self._definitions.scenegraph_definition
        local node = sg2 and sg2.profile_preset_tooltip_grid
        if node and node.size then grid_w = node.size[1] or grid_w end
    end

    local spacing_proto = self._vp_spacing_proto or { widget_type = "dynamic_spacing", size = { 0, 10 } }
    spacing_proto.size[1] = grid_w
    self._vp_spacing_proto = spacing_proto

    local new_layout = { spacing_proto }
    t_append(new_layout, icons)
    new_layout[#new_layout + 1] = spacing_proto
    if delete_entry then new_layout[#new_layout + 1] = delete_entry end
    new_layout[#new_layout + 1] = spacing_proto

    local defs2                 = self._definitions
    local blueprints2           = defs2 and defs2.profile_preset_grid_blueprints
    local grid_obj              = self._profile_preset_tooltip_grid
    if grid_obj and blueprints2 then
        grid_obj:present_grid_layout(
            new_layout,
            blueprints2,
            callback(self, "cb_on_profile_preset_icon_grid_left_pressed"),
            nil, nil, nil,
            callback(self, "cb_on_profile_preset_icon_grid_layout_changed"),
            nil
        )

        -- clear sticky selection/glow
        local widgets = grid_obj:widgets()
        if widgets then
            for i = 1, #widgets do
                local c = widgets[i].content
                if c then
                    c.equipped = false
                    c.force_glow = false
                    if c.hotspot then
                        c.hotspot.is_selected = false
                        c.hotspot.is_focused = false
                    end
                end
            end
        end

        -- nudge the grid's scrollbar +5px to the right
        _nudge_grid_scrollbar(grid_obj, 5)
    end
end)
