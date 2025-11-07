-- File: scripts/mods/BetterLoadouts/hooks/profile_presets_setup_buttons.lua

local mod = get_mod("BetterLoadouts")
if not mod then return end

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

-- Layout constants per mode (28 vs 200)
local function _layout()
    return mod.BL.layout_for_limit(mod.preset_limit or 28)
end

-- UTF-8 encoder (drop-in from PrivateCharMap)
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

-- Hook: build the vertical preset buttons (layout + unicode/custom icon logic)
mod:hook(CLASS.ViewElementProfilePresets, "_setup_preset_buttons", function(func, self)
    -- Enforce the current cap for this session
    _apply_limit_to_settings_local()

    local existing = self._profile_buttons_widgets
    if existing then
        for i = 1, #existing do
            local w = existing[i]
            if w and w.name then self:_unregister_widget_name(w.name) end
        end
        t_clear(existing)
    else
        existing = {}
    end

    local L             = _layout()
    local BAR_TOP_X     = L.BAR_TOP_X
    local BAR_TOP_Y     = L.BAR_TOP_Y
    local BUTTON_WIDTH  = L.BUTTON_WIDTH
    local BUTTON_HEIGHT = L.BUTTON_HEIGHT
    local BUTTON_GAP    = L.BUTTON_GAP
    local TOP_PAD       = L.TOP_PAD
    local BOTTOM_PAD    = L.BOTTOM_PAD
    local COLUMN_GAP    = L.COLUMN_GAP
    local ROWS_PER_COL  = L.ROWS_PER_COL
    local MAX_COLUMNS   = L.MAX_COLUMNS

    local defs          = self._definitions
    local blueprint     = defs and defs.profile_preset_button
    local active_id     = ProfileUtils.get_active_profile_preset_id()
    local presets       = ProfileUtils.get_profile_presets()

    local count_raw     = (presets and #presets) or 0
    local capacity      = ROWS_PER_COL * MAX_COLUMNS
    local count         = m_min(count_raw, capacity)

    local ref_keys      = PRIVATE_ICON_KEYS
    local icons_lu      = PRIVATE_ICON_LOOKUP
    local ref_keys_len  = #ref_keys

    local num_cols      = m_min(m_ceil(count / ROWS_PER_COL), MAX_COLUMNS)
    if num_cols < 1 then num_cols = 1 end
    local max_rows = math.min(count, ROWS_PER_COL)

    for i = 1, count do
        local p                   = presets[i]
        local pid                 = p and p.id
        local cky                 = p and p.custom_icon_key

        local w                   = self:_create_widget("profile_button_" .. i, blueprint)
        existing[i]               = w

        local col                 = m_floor((i - 1) / ROWS_PER_COL) + 1
        local row                 = ((i - 1) % ROWS_PER_COL) + 1

        local off                 = w.offset
        off[1]                    = -(col - 1) * (BUTTON_WIDTH + COLUMN_GAP)
        off[2]                    = (row - 1) * (BUTTON_HEIGHT + BUTTON_GAP)

        local content             = w.content
        local hs                  = content.hotspot
        hs.pressed_callback       = callback(self, "on_profile_preset_index_change", i)
        hs.right_pressed_callback = callback(self, "on_profile_preset_index_customize", i)

        local selected            = (pid == active_id)
        if selected then self._active_profile_preset_id = pid end
        hs.is_selected   = selected

        local def_idx    = math.index_wrapper(i, ref_keys_len)
        local def_key    = ref_keys[def_idx]
        local is_unicode = type(cky) == "string" and s_sub(cky, 1, 8) == "unicode:"
        if is_unicode then
            local hex       = s_sub(cky, 9)
            local cp        = tonumber(hex, 16)
            content.unicode = cp and utf8(cp) or "?"
            content.icon    = nil
            if w.style and w.style.icon and w.style.icon.color then
                w.style.icon.color[1] = 0
            end
        else
            local icon      = (cky and icons_lu[cky]) or icons_lu[def_key] or
                (type(cky) == "string" and cky or nil)
            content.icon    = icon
            content.unicode = nil
            if w.style and w.style.icon and w.style.icon.color then
                w.style.icon.color[1] = icon and 255 or 0
            end
        end
        content.profile_preset_id = pid
    end

    self._profile_buttons_widgets = existing

    local function col_height(n)
        if n <= 0 then return 0 end
        return n * BUTTON_HEIGHT + (n - 1) * BUTTON_GAP
    end

    local panel_height = TOP_PAD + col_height(max_rows) + BOTTOM_PAD
    local panel_width  = BUTTON_WIDTH * num_cols + COLUMN_GAP * (num_cols - 1)

    self:_set_scenegraph_size("profile_preset_button_panel", panel_width, panel_height)
    self:_set_scenegraph_position("profile_preset_button_panel", BAR_TOP_X, BAR_TOP_Y, 100)

    -- LoadoutNames integration: shift LN widget left, out of the bars
    local ln = get_mod and get_mod("LoadoutNames")
    if ln then
        local sgN = self._ui_scenegraph
        if sgN then
            local SAFE_GAP = 16
            local shift    = math.floor((panel_width + SAFE_GAP) * 0.5)

            local tbox     = sgN.loadout_name_tbox_area
            local tip      = sgN.loadout_name_tooltip_area

            if tbox and tbox.position then
                mod._ln_base_x_tbox = mod._ln_base_x_tbox or tbox.position[1] or -75
                self:_set_scenegraph_position("loadout_name_tbox_area", mod._ln_base_x_tbox - shift,
                    tbox.position[2] or -360, tbox.position[3] or 0)
            end
            if tip and tip.position then
                mod._ln_base_x_tip = mod._ln_base_x_tip or tip.position[1] or -75
                self:_set_scenegraph_position("loadout_name_tooltip_area", mod._ln_base_x_tip - shift,
                    tip.position[2] or 50, tip.position[3] or 50)
            end
        end
    end

    self:_force_update_scenegraph()
    self:_sync_profile_buttons_items_status()
end)
