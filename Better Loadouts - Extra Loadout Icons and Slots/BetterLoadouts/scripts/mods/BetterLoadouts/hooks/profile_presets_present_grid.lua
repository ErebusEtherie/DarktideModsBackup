-- File: scripts/mods/BetterLoadouts/hooks/profile_presets_present_grid.lua

local mod = get_mod("BetterLoadouts")
if not mod then
    return
end

local ViewElementProfilePresetsSettings = require(
    "scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings"
)

require("scripts/foundation/utilities/math")
require("scripts/foundation/utilities/table")

local s_format = string.format
local t_clear_array = table.clear_array
local t_append = table.append
local m_floor, m_max = math.floor, math.max

-- Layout helper
local function _layout()
    return mod.BL.layout_for_limit(mod.preset_limit or 28)
end

local function _node_bottom(node)
    if not (node and node.position and node.size) then
        return nil
    end

    return (node.position[2] or 0) + (node.size[2] or 0)
end

local function _is_wide_layout()
    if mod._bl_is_wide_preset_layout ~= nil then
        return mod._bl_is_wide_preset_layout == true
    end

    local cols = mod._bl_profile_preset_num_cols or 0
    local rows = mod._bl_profile_preset_num_rows or 0

    return cols > rows
end

local function _tooltip_width(self)
    local defs = self._definitions
    local sg = defs and defs.scenegraph_definition
    local node = sg and sg.profile_preset_tooltip

    if node and node.size then
        return node.size[1] or 265
    end

    local live_node = self._ui_scenegraph and self._ui_scenegraph.profile_preset_tooltip
    if live_node and live_node.size then
        return live_node.size[1] or 265
    end

    return 265
end

local function _tooltip_anchor_x(self, layout)
    local panel_node = self._ui_scenegraph and self._ui_scenegraph.profile_preset_button_panel
    local panel_w = mod._bl_profile_preset_panel_width
        or (panel_node and panel_node.size and panel_node.size[1])
        or (layout.BUTTON_WIDTH * 2 + layout.COLUMN_GAP)

    if _is_wide_layout() then
        local tooltip_w = _tooltip_width(self)
        return m_floor((tooltip_w - panel_w) * 0.5)
    end

    return -(panel_w + (layout.SAFE_GAP or 40)) + 12
end

local function _tooltip_anchor_y(self, default_ty)
    local tooltip_y = default_ty

    if _is_wide_layout() then
        local panel_bottom_y = mod._bl_profile_preset_panel_bottom_y
            or ((mod._bl_profile_preset_panel_top_y or default_ty) + (mod._bl_profile_preset_panel_height or 0))

        tooltip_y = panel_bottom_y + 16
    end

    if mod._has_loadoutnames then
        local sgN = self._ui_scenegraph
        local ln_bottom = m_max(
            _node_bottom(sgN and sgN.loadout_name_tbox_area) or -math.huge,
            _node_bottom(sgN and sgN.loadout_name_tooltip_area) or -math.huge
        )

        if ln_bottom > -math.huge then
            tooltip_y = m_max(tooltip_y, ln_bottom + 16)
        end
    end

    return tooltip_y
end

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

-- Small helper to nudge the ViewElementGrid scrollbar on the tooltip grid
local function _nudge_grid_scrollbar(grid_obj, dx)
    if not grid_obj or not grid_obj._ui_scenegraph then
        return
    end

    local names = { "grid_scrollbar", "scrollbar" }

    for i = 1, #names do
        local id = names[i]
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

-- Hook: build & present the tooltip grid layout (icons + unicode + text)
mod:hook(CLASS.ViewElementProfilePresets, "_present_tooltip_grid_layout", function(func, self, layout)
    local L = _layout()

    local ty, tz = 0, 1
    local tooltip_def = self._definitions
        and self._definitions.scenegraph_definition
        and self._definitions.scenegraph_definition.profile_preset_tooltip

    if tooltip_def and tooltip_def.position then
        ty = tooltip_def.position[2] or 0
        tz = tooltip_def.position[3] or 1
    end

    local x = _tooltip_anchor_x(self, L)
    local y = _tooltip_anchor_y(self, ty)

    self:_set_scenegraph_position("profile_preset_tooltip", x, y, tz)
    self:_force_update_scenegraph()

    -- Build a fresh layout from the private pool, but keep the delete button
    -- (if present) from the original layout.
    local icons = self._vp_icons or (Script and Script.new_array and Script.new_array(64)) or {}
    local delete_entry = nil

    t_clear_array(icons, #icons)
    self._vp_icons = icons

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
