-- File: scripts/mods/BetterLoadouts/hooks/profile_presets_setup_buttons.lua

local mod = get_mod("BetterLoadouts")
if not mod then
    return
end

local ProfileUtils = require("scripts/utilities/profile_utils")
local ViewElementProfilePresetsSettings = require(
    "scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings"
)

require("scripts/foundation/utilities/math")
require("scripts/foundation/utilities/table")

-- Apply the current limit locally (safe even if main file did it already)
local function _apply_limit_to_settings_local()
    local cap = mod.preset_limit or 28

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
local m_min, m_floor, m_ceil = math.min, math.floor, math.ceil

local HORIZONTAL_ADD_SLOT_WIDTH = 48
local PRESET_PIVOT_EXTRA_LIFT = 4

-- Layout constants per mode
local function _layout()
    return mod.BL.layout_for_limit(mod.preset_limit or 28)
end

local function _bar_alignment()
    local alignment = mod.preset_alignment

    if alignment == "left" or alignment == "center" then
        return alignment
    end

    return "right"
end

local function _aligned_bar_x(base_x, alignment)
    if alignment == "left" then
        return math.abs(base_x or 0)
    elseif alignment == "center" then
        return 0
    end

    return base_x or 0
end

local function _cache_loadoutnames_base_positions(sgN)
    if not sgN then
        return
    end

    local tbox = sgN.loadout_name_tbox_area
    local tip = sgN.loadout_name_tooltip_area

    if tbox and tbox.position then
        mod._ln_base_x_tbox = mod._ln_base_x_tbox or tbox.position[1] or -75
        mod._ln_base_y_tbox = mod._ln_base_y_tbox or tbox.position[2] or -360
        mod._ln_base_z_tbox = mod._ln_base_z_tbox or tbox.position[3] or 0
        mod._ln_base_valign_tbox = mod._ln_base_valign_tbox or tbox.vertical_alignment or "center"
    end

    if tip and tip.position then
        mod._ln_base_x_tip = mod._ln_base_x_tip or tip.position[1] or -75
        mod._ln_base_y_tip = mod._ln_base_y_tip or tip.position[2] or 50
        mod._ln_base_z_tip = mod._ln_base_z_tip or tip.position[3] or 50
        mod._ln_base_valign_tip = mod._ln_base_valign_tip or tip.vertical_alignment or "top"
    end
end

local function _position_loadoutnames(self, panel_width, panel_height, bar_top_x, bar_top_y, is_wide_layout, alignment)
    if not mod._has_loadoutnames then
        return
    end

    local sgN = self._ui_scenegraph
    if not sgN then
        return
    end

    _cache_loadoutnames_base_positions(sgN)

    local SAFE_GAP_X = 16
    local SAFE_GAP_Y = 16
    local tbox = sgN.loadout_name_tbox_area
    local tip = sgN.loadout_name_tooltip_area

    if is_wide_layout then
        -- Horizontal bars put both LoadoutNames widgets below the bar and use
        -- the same screen anchor as BetterLoadouts.  This makes live changes
        -- between left/center/right alignment deterministic instead of keeping
        -- LoadoutNames anchored to the screen-right edge.
        local tbox_height = (tbox and tbox.size and tbox.size[2]) or 40
        local below_y = bar_top_y + panel_height + SAFE_GAP_Y
        local tip_y = below_y + tbox_height + 8

        if tbox and tbox.position then
            tbox.horizontal_alignment = alignment
            tbox.vertical_alignment = "top"
            self:_set_scenegraph_position(
                "loadout_name_tbox_area",
                bar_top_x,
                below_y,
                mod._ln_base_z_tbox or 0
            )
        end

        if tip and tip.position then
            tip.horizontal_alignment = alignment
            tip.vertical_alignment = "top"
            self:_set_scenegraph_position(
                "loadout_name_tooltip_area",
                bar_top_x,
                tip_y,
                mod._ln_base_z_tip or 50
            )
        end

        return
    end

    -- Vertical bars keep LoadoutNames' original vertical placement, but move
    -- both widgets to the inward side of a left/right bar.  A centered bar
    -- puts them immediately to its right.
    local name_alignment
    local name_x

    if alignment == "right" then
        name_alignment = "right"
        name_x = bar_top_x - panel_width - SAFE_GAP_X
    elseif alignment == "left" then
        name_alignment = "left"
        name_x = bar_top_x + panel_width + SAFE_GAP_X
    else
        local screen_width = sgN.screen and sgN.screen.size and sgN.screen.size[1] or 1920

        name_alignment = "left"
        name_x = screen_width * 0.5 + panel_width * 0.5 + SAFE_GAP_X
    end

    if tbox and tbox.position then
        tbox.horizontal_alignment = name_alignment
        tbox.vertical_alignment = mod._ln_base_valign_tbox or "center"
        self:_set_scenegraph_position(
            "loadout_name_tbox_area",
            name_x,
            mod._ln_base_y_tbox or -360,
            mod._ln_base_z_tbox or 0
        )
    end

    if tip and tip.position then
        tip.horizontal_alignment = name_alignment
        tip.vertical_alignment = mod._ln_base_valign_tip or "top"
        self:_set_scenegraph_position(
            "loadout_name_tooltip_area",
            name_x,
            mod._ln_base_y_tip or 50,
            mod._ln_base_z_tip or 50
        )
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

    _register_private(mod.BL.DEFAULT_CUSTOM_ICON_PATHS)
end

_seed_private_from_vanilla_then_custom()

-- Hook: build the preset buttons (layout + unicode/custom icon logic)
mod:hook(CLASS.ViewElementProfilePresets, "_setup_preset_buttons", function(func, self)
    -- Enforce the current cap for this session
    _apply_limit_to_settings_local()
    mod.reset_preset_drag_reorder(self)

    local alignment = _bar_alignment()
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
    local BAR_TOP_X = _aligned_bar_x(L.BAR_TOP_X, alignment)
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
    local active_id = ProfileUtils.get_active_profile_preset_id()
    local presets = ProfileUtils.get_profile_presets()

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
    local is_wide_layout = MAX_COLUMNS > ROWS_PER_COL

    for i = 1, count do
        local p = presets[i]
        local pid = p and p.id
        local cky = p and p.custom_icon_key

        local w = self:_create_widget("profile_button_" .. i, blueprint)
        existing[i] = w

        local col = m_floor((i - 1) / ROWS_PER_COL) + 1
        local row = ((i - 1) % ROWS_PER_COL) + 1

        local off = w.offset
        local column_offset = (col - 1) * (BUTTON_WIDTH + COLUMN_GAP)
        off[1] = alignment == "left" and column_offset or -column_offset
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
        mod.apply_preset_color(w, p)
    end

    self._profile_buttons_widgets = existing

    local function col_height(n)
        if n <= 0 then
            return 0
        end

        return n * BUTTON_HEIGHT + (n - 1) * BUTTON_GAP
    end

    local panel_height = TOP_PAD + col_height(max_rows) + BOTTOM_PAD
    local preset_width = BUTTON_WIDTH * num_cols + COLUMN_GAP * (num_cols - 1)
    local panel_width = preset_width + (is_wide_layout and HORIZONTAL_ADD_SLOT_WIDTH or 0)

    local scenegraph = self._ui_scenegraph
    if scenegraph then
        if scenegraph.profile_preset_button_panel then
            scenegraph.profile_preset_button_panel.horizontal_alignment = alignment
        end

        local child_alignment = alignment == "left" and "left" or "right"
        local pivot_x = 0
        local add_x = 0
        local pivot_y = 48
        local add_y = is_wide_layout and 48 or 0
        local lift_top_aligned = is_wide_layout or alignment == "center"

        if is_wide_layout then
            pivot_x = alignment == "left" and HORIZONTAL_ADD_SLOT_WIDTH or -HORIZONTAL_ADD_SLOT_WIDTH
        end

        if lift_top_aligned then
            local add_button_node = scenegraph.profile_preset_add_button
            local add_button_height = add_button_node and add_button_node.size and add_button_node.size[2] or 44
            local add_button_lift = add_button_height * 0.5

            add_y = add_y - add_button_lift
            pivot_y = pivot_y - add_button_lift - PRESET_PIVOT_EXTRA_LIFT
        end

        if scenegraph.profile_preset_add_button then
            scenegraph.profile_preset_add_button.horizontal_alignment = child_alignment
            self:_set_scenegraph_position("profile_preset_add_button", add_x, add_y, 1)
        end
        if scenegraph.profile_preset_button_pivot then
            scenegraph.profile_preset_button_pivot.horizontal_alignment = child_alignment
            self:_set_scenegraph_position("profile_preset_button_pivot", pivot_x, pivot_y, 1)
        end
    end

    self:_set_scenegraph_size("profile_preset_button_panel", panel_width, panel_height)
    self:_set_scenegraph_position("profile_preset_button_panel", BAR_TOP_X, BAR_TOP_Y, 100)

    mod._bl_is_wide_preset_layout = is_wide_layout
    mod._bl_profile_preset_panel_width = panel_width
    mod._bl_profile_preset_panel_height = panel_height
    mod._bl_profile_preset_panel_top_x = BAR_TOP_X
    mod._bl_profile_preset_panel_top_y = BAR_TOP_Y
    mod._bl_profile_preset_panel_bottom_y = BAR_TOP_Y + panel_height
    mod._bl_profile_preset_num_cols = num_cols
    mod._bl_profile_preset_num_rows = max_rows
    mod._bl_profile_preset_alignment = alignment

    _position_loadoutnames(self, panel_width, panel_height, BAR_TOP_X, BAR_TOP_Y, is_wide_layout, alignment)

    self:_force_update_scenegraph()
    mod.refresh_preset_tooltip_layout(self, false)
    self:_sync_profile_buttons_items_status()
    mod.attach_preset_drag_reorder(self)
end)
