local mod = get_mod("realms_loadout")
if not mod then
  return
end

local better = get_mod("BetterLoadouts")
if not better or not better.BL then
  return
end

local RealmsViewElementProfilePresets = mod._realms_bl_compat_class

if not RealmsViewElementProfilePresets then
  RealmsViewElementProfilePresets = require("realms_loadout/scripts/mods/realms_loadout/official_ui/view_element_profile_presets/view_element_profile_presets")
end

local Storage = require("realms_loadout/scripts/mods/realms_loadout/storage")

do

-- Small helper to nudge the ViewElementGrid scrollbar on the tooltip grid.
-- (Duplicated locally to keep this hook self-contained.)
local function _nudge_grid_scrollbar(grid_obj, dx)
    if not grid_obj or not grid_obj._ui_scenegraph then return end
    local names = { "grid_scrollbar", "scrollbar" } -- try common ids
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

-- After vanilla sizes the grid/tooltip: widen slightly and clear selection/glow
mod:hook_safe(RealmsViewElementProfilePresets, "cb_on_profile_preset_icon_grid_layout_changed", function(self)
    local node = self._ui_scenegraph and self._ui_scenegraph.profile_preset_tooltip
    if node and node.size then
        local w = node.size[1] or 265
        local h = node.size[2] or 460
        self:_set_scenegraph_size("profile_preset_tooltip", w + 10, h + 0)
        self:_force_update_scenegraph()
    end

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

    if grid then
        _nudge_grid_scrollbar(grid, 5)
    end
end)
end

do

-- Storage is already required by the compat header.
local ViewElementProfilePresetsSettings = require(
    "scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings"
)

require("scripts/foundation/utilities/math")
require("scripts/foundation/utilities/table")

-- Apply the current limit locally (safe even if main file did it already)
local function _apply_limit_to_settings_local()
    local cap = better.preset_limit or 28

    if ViewElementProfilePresetsSettings then
        ViewElementProfilePresetsSettings.max_profile_presets = cap
    end

    local S = rawget(_G, "ViewElementProfilePresetsSettings")
    if S then
        S.max_profile_presets = cap
    end
end

local s_sub = string.sub
local t_clear = table.clear
local m_min, m_floor, m_ceil, m_max = math.min, math.floor, math.ceil, math.max

-- Layout constants per mode
local function _layout()
    return better.BL.layout_for_limit(better.preset_limit or 28)
end

local function _is_wide_layout(num_cols, num_rows)
    return (num_cols or 0) > (num_rows or 0)
end

local function _cache_loadoutnames_base_positions(sgN)
    if not sgN then
        return
    end

    local tbox = sgN.loadout_name_tbox_area
    local tip = sgN.loadout_name_tooltip_area

    if tbox and tbox.position then
        better._ln_base_x_tbox = better._ln_base_x_tbox or tbox.position[1] or -75
        better._ln_base_y_tbox = better._ln_base_y_tbox or tbox.position[2] or -360
        better._ln_base_z_tbox = better._ln_base_z_tbox or tbox.position[3] or 0
    end

    if tip and tip.position then
        better._ln_base_x_tip = better._ln_base_x_tip or tip.position[1] or -75
        better._ln_base_y_tip = better._ln_base_y_tip or tip.position[2] or 50
        better._ln_base_z_tip = better._ln_base_z_tip or tip.position[3] or 50
    end
end

local function _position_loadoutnames(self, panel_width, panel_height, bar_top_y, is_wide_layout)
    if not better._has_loadoutnames then
        return
    end

    local sgN = self._ui_scenegraph
    if not sgN then
        return
    end

    _cache_loadoutnames_base_positions(sgN)

    local SAFE_GAP_X = 16
    local SAFE_GAP_Y = 16

    local shift_x = m_floor((panel_width + SAFE_GAP_X) * 0.5)

    local tbox = sgN.loadout_name_tbox_area
    local tip = sgN.loadout_name_tooltip_area

    if is_wide_layout then
        local tbox_height = (tbox and tbox.size and tbox.size[2]) or 40
        local below_y = bar_top_y + panel_height + SAFE_GAP_Y
        local tip_y = below_y + tbox_height + 8

        if tbox and tbox.position then
            self:_set_scenegraph_position(
                "loadout_name_tbox_area",
                (better._ln_base_x_tbox or -75) - shift_x,
                m_max(better._ln_base_y_tbox or below_y, below_y),
                better._ln_base_z_tbox or 0
            )
        end

        if tip and tip.position then
            self:_set_scenegraph_position(
                "loadout_name_tooltip_area",
                (better._ln_base_x_tip or -75) - shift_x,
                m_max(better._ln_base_y_tip or tip_y, tip_y),
                better._ln_base_z_tip or 50
            )
        end
    else
        if tbox and tbox.position then
            self:_set_scenegraph_position(
                "loadout_name_tbox_area",
                (better._ln_base_x_tbox or -75) - shift_x,
                better._ln_base_y_tbox or -360,
                better._ln_base_z_tbox or 0
            )
        end

        if tip and tip.position then
            self:_set_scenegraph_position(
                "loadout_name_tooltip_area",
                (better._ln_base_x_tip or -75) - shift_x,
                better._ln_base_y_tip or 50,
                better._ln_base_z_tip or 50
            )
        end
    end
end

-- UTF-8 encoder (drop-in from PrivateCharMap)
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

-- Private preset-icons pool (local to this file; same content/order as main)
local PRIVATE_ICON_LOOKUP, PRIVATE_ICON_KEYS = {}, {}

local function _register_private(list)
    for i = 1, #list do
        local key = list[i]
        if key and not PRIVATE_ICON_LOOKUP[key] then
            PRIVATE_ICON_LOOKUP[key] = key -- our convention
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

    _register_private(better.BL.DEFAULT_CUSTOM_ICON_PATHS)
end

_seed_private_from_vanilla_then_custom()

-- Hook: build the preset buttons (layout + unicode/custom icon logic)
function RealmsViewElementProfilePresets:_setup_preset_buttons()
    -- Enforce the current cap for this session
    _apply_limit_to_settings_local()

    local existing = self._profile_buttons_widgets
    if existing then
        for i = 1, #existing do
            local w = existing[i]
            if w and w.name then
                self:_unregister_widget_name(w.name)
            end
        end
        t_clear(existing)
    else
        existing = {}
    end

    local L = _layout()
    local BAR_TOP_X = L.BAR_TOP_X
    local BAR_TOP_Y = L.BAR_TOP_Y
    local BUTTON_WIDTH = L.BUTTON_WIDTH
    local BUTTON_HEIGHT = L.BUTTON_HEIGHT
    local BUTTON_GAP = L.BUTTON_GAP
    local TOP_PAD = L.TOP_PAD
    local BOTTOM_PAD = L.BOTTOM_PAD
    local COLUMN_GAP = L.COLUMN_GAP
    local ROWS_PER_COL = L.ROWS_PER_COL
    local MAX_COLUMNS = L.MAX_COLUMNS

    local defs = self._definitions
    local blueprint = defs and defs.profile_preset_button
    local active_id = Storage.get_active_profile_preset_id()
    local presets = Storage.get_profile_presets()

    local count_raw = (presets and #presets) or 0
    local capacity = ROWS_PER_COL * MAX_COLUMNS
    local count = m_min(count_raw, capacity)

    local ref_keys = PRIVATE_ICON_KEYS
    local icons_lu = PRIVATE_ICON_LOOKUP
    local ref_keys_len = #ref_keys

    local num_cols = m_min(m_ceil(count / ROWS_PER_COL), MAX_COLUMNS)
    if num_cols < 1 then
        num_cols = 1
    end

    local max_rows = m_min(count, ROWS_PER_COL)
    local is_wide_layout = _is_wide_layout(num_cols, max_rows)

    for i = 1, count do
        local p = presets[i]
        local pid = p and p.id
        local cky = p and p.custom_icon_key

        local w = self:_create_widget("profile_button_" .. i, blueprint)
        existing[i] = w

        local col = m_floor((i - 1) / ROWS_PER_COL) + 1
        local row = ((i - 1) % ROWS_PER_COL) + 1

        local off = w.offset
        off[1] = -(col - 1) * (BUTTON_WIDTH + COLUMN_GAP)
        off[2] = (row - 1) * (BUTTON_HEIGHT + BUTTON_GAP)

        local content = w.content
        local hs = content.hotspot
        hs.pressed_callback = callback(self, "on_profile_preset_index_change", i)
        hs.right_pressed_callback = callback(self, "on_profile_preset_index_customize", i)

        local selected = pid == active_id
        if selected then
            self._active_profile_preset_id = pid
        end
        hs.is_selected = selected

        local def_idx = math.index_wrapper(i, ref_keys_len)
        local def_key = ref_keys[def_idx]
        local is_text = type(cky) == "string" and s_sub(cky, 1, 5) == "text:"
        local is_unicode = type(cky) == "string" and s_sub(cky, 1, 8) == "unicode:"

        if is_text then
            content.custom_text = s_sub(cky, 6)
            content.unicode = nil
            content.icon = nil

            if w.style and w.style.icon and w.style.icon.color then
                w.style.icon.color[1] = 0
            end
        elseif is_unicode then
            local hex = s_sub(cky, 9)
            local cp = tonumber(hex, 16)

            content.custom_text = nil
            content.unicode = cp and utf8(cp) or "?"
            content.icon = nil

            if w.style and w.style.icon and w.style.icon.color then
                w.style.icon.color[1] = 0
            end
        else
            local icon = (cky and icons_lu[cky]) or icons_lu[def_key] or
                (type(cky) == "string" and cky or nil)

            content.custom_text = nil
            content.icon = icon
            content.unicode = nil

            if w.style and w.style.icon and w.style.icon.color then
                w.style.icon.color[1] = icon and 255 or 0
            end
        end

        content.profile_preset_id = pid
    end

    self._profile_buttons_widgets = existing

    local function col_height(n)
        if n <= 0 then
            return 0
        end

        return n * BUTTON_HEIGHT + (n - 1) * BUTTON_GAP
    end

    local panel_height = TOP_PAD + col_height(max_rows) + BOTTOM_PAD
    local panel_width = BUTTON_WIDTH * num_cols + COLUMN_GAP * (num_cols - 1)

    self:_set_scenegraph_size("profile_preset_button_panel", panel_width, panel_height)
    self:_set_scenegraph_position("profile_preset_button_panel", BAR_TOP_X, BAR_TOP_Y, 100)

    better._bl_is_wide_preset_layout = is_wide_layout
    better._bl_profile_preset_panel_width = panel_width
    better._bl_profile_preset_panel_height = panel_height
    better._bl_profile_preset_panel_top_x = BAR_TOP_X
    better._bl_profile_preset_panel_top_y = BAR_TOP_Y
    better._bl_profile_preset_panel_bottom_y = BAR_TOP_Y + panel_height
    better._bl_profile_preset_num_cols = num_cols
    better._bl_profile_preset_num_rows = max_rows

    _position_loadoutnames(self, panel_width, panel_height, BAR_TOP_Y, is_wide_layout)

    self:_force_update_scenegraph()
    self:_sync_profile_buttons_items_status()
end
end

do

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
    return better.BL.layout_for_limit(better.preset_limit or 28)
end

local function _node_bottom(node)
    if not (node and node.position and node.size) then
        return nil
    end

    return (node.position[2] or 0) + (node.size[2] or 0)
end

local function _is_wide_layout()
    if better._bl_is_wide_preset_layout ~= nil then
        return better._bl_is_wide_preset_layout == true
    end

    local cols = better._bl_profile_preset_num_cols or 0
    local rows = better._bl_profile_preset_num_rows or 0

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
    local panel_w = better._bl_profile_preset_panel_width
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
        local panel_bottom_y = better._bl_profile_preset_panel_bottom_y
            or ((better._bl_profile_preset_panel_top_y or default_ty) + (better._bl_profile_preset_panel_height or 0))

        tooltip_y = panel_bottom_y + 16
    end

    if better._has_loadoutnames then
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

    _register_private(better.BL.DEFAULT_CUSTOM_ICON_PATHS)
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
function RealmsViewElementProfilePresets:_present_tooltip_grid_layout(layout)
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
    for i = 1, #better.BL.UNICODE_EXTRA_CODES do
        icons[#icons + 1] = make_unicode(better.BL.UNICODE_EXTRA_CODES[i])
    end

    local G = _G.UNICODE_PRESET_CODES
    if G then
        for i = 1, #G do
            icons[#icons + 1] = make_unicode(G[i])
        end
    end

    -- Add short text icons last
    for i = 1, #better.BL.TEXT_PRESET_ICONS do
        local entry = better.BL.TEXT_PRESET_ICONS[i]
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
end
end

do

-- Storage is already required by the compat header.
local ViewElementProfilePresetsSettings = require(
    "scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings"
)

require("scripts/foundation/utilities/math")
require("scripts/foundation/utilities/table")

local s_sub = string.sub

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

-- Private icon lookup (local copy; same content as other files)
local PRIVATE_ICON_LOOKUP = {}

local function _seed_lookup()
    local S = ViewElementProfilePresetsSettings
    local ref = S and S.optional_preset_icon_reference_keys or {}
    local lu = S and S.optional_preset_icons_lookup or {}

    for i = 1, #ref do
        local vk = ref[i]
        local vmat = lu[vk]

        if vk and vmat and not PRIVATE_ICON_LOOKUP[vk] then
            PRIVATE_ICON_LOOKUP[vk] = vmat
        end
    end

    for i = 1, #better.BL.DEFAULT_CUSTOM_ICON_PATHS do
        local key = better.BL.DEFAULT_CUSTOM_ICON_PATHS[i]
        if key and not PRIVATE_ICON_LOOKUP[key] then
            PRIVATE_ICON_LOOKUP[key] = key -- material path == key
        end
    end
end

_seed_lookup()

-- Hook: handle clicks on an icon tile (set text, unicode, or material, or delete)
mod:hook(
    RealmsViewElementProfilePresets,
    "cb_on_profile_preset_icon_grid_left_pressed",
    function(func, self, widget, element)
        if element and element.delete_button then
            if func then
                return func(self, widget, element)
            end

            if self._remove_profile_preset then
                return self:_remove_profile_preset(widget, element)
            end

            return
        end

        local icon_key = element and element.icon_key
        if not icon_key then
            if func then
                return func(self, widget, element)
            end

            return
        end

        local index = self._active_customize_preset_index
        if not index then
            return
        end

        local profile_preset_id = self:_get_profile_preset_id_by_widget_index(index)
        local profile_preset = Storage.get_profile_preset(profile_preset_id)
        if not profile_preset then
            return
        end

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
                        c.hotspot.is_focused = false
                    end
                end
            end
        end

        local buttons = self._profile_buttons_widgets
        local btn = buttons and buttons[index]

        -- Text tile
        if s_sub(icon_key, 1, 5) == "text:" then
            local chosen_text = (element and element.text and element.text ~= "") and element.text or s_sub(icon_key, 6)

            if btn then
                local content = btn.content
                content.custom_text = chosen_text
                content.unicode = nil
                content.icon = nil

                if btn.style and btn.style.icon and btn.style.icon.color then
                    btn.style.icon.color[1] = 0
                end
            end

            profile_preset.custom_icon_key = icon_key
            Storage.persist_current_loadouts()

            return
        end

        -- Unicode tile
        if s_sub(icon_key, 1, 8) == "unicode:" then
            local hex = s_sub(icon_key, 9)
            local cp = tonumber(hex, 16)
            local ch = (element and element.text and element.text ~= "") and element.text or utf8(cp)

            if btn then
                local content = btn.content
                content.custom_text = nil
                content.unicode = ch
                content.icon = nil

                if btn.style and btn.style.icon and btn.style.icon.color then
                    btn.style.icon.color[1] = 0
                end
            end

            profile_preset.custom_icon_key = icon_key
            Storage.persist_current_loadouts()

            return
        end

        -- Non-unicode/text: prefer PRIVATE lookup ...
        local default_icon = PRIVATE_ICON_LOOKUP[icon_key]
        if default_icon and btn then
            local content = btn.content
            content.custom_text = nil
            content.icon = default_icon
            content.unicode = nil

            if btn.style and btn.style.icon and btn.style.icon.color then
                btn.style.icon.color[1] = 255
            end

            profile_preset.custom_icon_key = icon_key
            Storage.persist_current_loadouts()

            return
        end

        -- ...fallback to treating icon_key as a direct material path.
        if type(icon_key) == "string" and btn then
            local content = btn.content
            content.custom_text = nil
            content.icon = icon_key
            content.unicode = nil

            if btn.style and btn.style.icon and btn.style.icon.color then
                btn.style.icon.color[1] = 255
            end

            profile_preset.custom_icon_key = icon_key
            Storage.persist_current_loadouts()

            return
        end

        -- If none of the above, pass through to vanilla.
        if func then
            return func(self, widget, element)
        end
    end
)
end

-- Track local preset element for BetterLoadouts keybind reordering. Store the
-- element on the mod table instead of a chunk-local so repeated re-applications
-- of this file do not create stale closures.
mod:hook_safe(RealmsViewElementProfilePresets, "init", function(self)
  mod._realms_bl_active_preset_element = self
end)

mod:hook_safe(RealmsViewElementProfilePresets, "destroy", function(self)
  if mod._realms_bl_active_preset_element == self then
    mod._realms_bl_active_preset_element = nil
  end
end)

-- Cache the original BetterLoadouts functions once. Re-executing this file must
-- not keep wrapping our own previous wrappers.
if mod._realms_bl_original_move_preset_backward == nil then
  mod._realms_bl_original_move_preset_backward = better.move_preset_backward
  mod._realms_bl_original_move_preset_forward = better.move_preset_forward
end

local better_move_backward = mod._realms_bl_original_move_preset_backward
local better_move_forward = mod._realms_bl_original_move_preset_forward

function better.move_preset_backward()
  local element = mod._realms_bl_active_preset_element

  if element and not element:is_costumization_open() then
    if Storage.move_active_loadout(false) then
      element:_setup_preset_buttons()
    end

    return
  end

  if better_move_backward then
    return better_move_backward()
  end
end

function better.move_preset_forward()
  local element = mod._realms_bl_active_preset_element

  if element and not element:is_costumization_open() then
    if Storage.move_active_loadout(true) then
      element:_setup_preset_buttons()
    end

    return
  end

  if better_move_forward then
    return better_move_forward()
  end
end
return true
