local mod = get_mod("custom_hud")

local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local ColorUtilities = mod:original_require("scripts/utilities/ui/colors")
local UIHudSettings = mod:original_require("scripts/settings/ui/ui_hud_settings")

local function _mod_enabled()
    return not mod.is_enabled or mod:is_enabled()
end

-- NOTE: this file is re-executed by the engine's require on every HUD
-- (re)build, so it must stay idempotent: no top-level mod:hook calls here.
-- The repin pass and the latched set_scenegraph_position helper live in
-- custom_hud.lua (main script); the helper is reached via
-- mod._set_element_sg_position, looked up at call time.

-- Draw hook: suppresses draw while right-click hidden (vanilla draw ignores
-- _is_hidden - it's a mod-invented field). Opted into per instance, but INSTALLED
-- ON THE CLASS, never on the instance.
--
-- DMF has no unhook API, and every hook strong-refs its target forever:
-- _origs[obj][method], _registry[mod][uid].obj and the _hooks[type][uid] closure
-- chain are never cleared. Hooking an element instance therefore pins that element
-- - and through it its widgets, its ui_renderer, and the Gui/World handles the
-- engine frees at world teardown - for the rest of the process. HUD elements are
-- rebuilt on every mission/hub transition AND on every mod hot reload, so those
-- dead graphs pile up and the GC keeps walking them. Class tables live in CLASSES
-- for the whole process, so hooking them retains nothing that wasn't permanent.
--
-- The class table has to be the element's OWN: Darktide's class() flat-copies
-- super's members into the subclass at definition time (no __index chain up to
-- super), so a hook installed later on HudElementBase.draw never reaches a
-- subclass that already took its own copy of draw.
local function _element_draw_hook(func, self, dt, t, ui_renderer, render_settings, input_service)
    -- Opt-in marker. The hook now fires for every instance of the class, so this
    -- keeps the affected set identical to the old per-instance hook: only elements
    -- _ensure_element_draw_hook was called for take the customizer path.
    if not rawget(self, "_custom_hud_draw_hooked") then
        return func(self, dt, t, ui_renderer, render_settings, input_service)
    end

    if self._is_hidden and _mod_enabled() then
        return
    end

    local opacity = mod._opacity or 1
    if opacity ~= 1 and render_settings then
        render_settings.alpha_multiplier = opacity
    end

    return func(self, dt, t, ui_renderer, render_settings, input_service)
end

-- The guard for the hook above is mod._hooked_draw_classes (declared in
-- custom_hud.lua): class table -> the function DMF installed on it.
--
-- WHERE it lives matters. It must die exactly when DMF's hooks die, and they die on
-- a mods reload: dmf_loader's on_reload calls hooks_unload, which walks _origs and
-- restores every hooked method to its original. A guard kept ON THE CLASS TABLE
-- outlives that -- vanilla class tables are process-lifetime -- so after any hot
-- reload the flag still said "hooked" while the hook was gone, and every hidden
-- element came back and could not be re-hidden. The mod object is re-created by the
-- same reload (dmf_mod_manager's _mods table is rebuilt), so a field on it has the
-- right lifetime. It must NOT be reset per HUD rebuild either: the old mod object
-- keeps its entries, so a surviving old customizer instance won't re-hook and trip
-- DMF's "rehook active hook [draw]" warning.
--
-- WHAT it stores matters too. class() (scripts/foundation/utilities/class.lua:100)
-- re-copies every super member into the subclass on each run --
-- `class_table.draw = HudElementBase.draw` -- silently dropping our hook. Vanilla
-- element files hit that once, but a mod element registered with
-- mod:add_require_path is routed to io_dofile, which has no module cache
-- (dmf/modules/core/require.lua:66), so every require re-executes its file and
-- re-clobbers the hook -- and every HUD rebuild require()s them all. Storing the
-- installed function instead of a boolean lets us put it straight back. Re-hooking
-- would not work there: _origs[class_table].draw still exists, so DMF takes the
-- bare original as the unique id and appends to a chain nothing calls.
local function _ensure_element_draw_hook(element)
    -- Instance flag: opt-in marker read by the handler above.
    element._custom_hud_draw_hooked = true

    local class_name = element.__class_name
    if not class_name then
        return
    end

    -- CLASS.__index returns the key itself for unknown names, so rawget is what
    -- distinguishes a real class table from that string fallback.
    local class_table = rawget(CLASS, class_name)
    if type(class_table) ~= "table" or type(rawget(class_table, "draw")) ~= "function" then
        return
    end

    local hooked = mod._hooked_draw_classes
    local installed = hooked[class_table]
    if installed then
        if rawget(class_table, "draw") ~= installed then
            class_table.draw = installed
        end
        return
    end

    mod:hook(class_table, "draw", _element_draw_hook)
    -- Whatever DMF left in place: its internal chain entry for this obj/method.
    hooked[class_table] = rawget(class_table, "draw")
end

-- ============================================================================
-- Constants
-- ============================================================================

local PANEL_WIDTH_DEFAULT = 340
local PANEL_MARGIN = 10
local PANEL_LINE_HEIGHT = 22

-- Resolution anchoring for the info panel. The layout was tuned at this height;
-- the panel's SIZE scale is multiplied by (screen_height / reference) so the panel
-- grows/shrinks proportionally with resolution instead of staying a fixed pixel
-- size (which looked oversized at 1080p, tiny at 4K). Anchored to height so
-- ultrawide/widescreen don't stretch it. Applied to the size scale only — never
-- to positions or cursor mapping, which must use the real inverse_scale so
-- hit-testing lines up with drawing. Clamped to keep extremes sane.
local PANEL_REFERENCE_HEIGHT = 1440
local function _panel_res_factor()
    local h = RESOLUTION_LOOKUP.height
    if not h or h <= 0 then
        return 1
    end
    return math.clamp(h / PANEL_REFERENCE_HEIGHT, 0.5, 2.5)
end
-- Two-row header: title band on top, button band below.
local PANEL_HEADER_HEIGHT = 56
local PANEL_HEADER_TITLE_BAND = 26
local PANEL_DETAIL_HEIGHT = 310
local PANEL_MAX_VISIBLE_LINES = 30
local PANEL_BG_COLOR = { 200, 15, 15, 15 }
local PANEL_HEADER_COLOR = { 220, 25, 25, 30 }
local PANEL_LINE_COLOR = { 0, 0, 0, 0 }
local PANEL_LINE_HOVER_COLOR = { 100, 60, 60, 80 }
local PANEL_LINE_SELECTED_COLOR = { 150, 80, 120, 80 }
local PANEL_DETAIL_BG_COLOR = { 200, 20, 20, 25 }
local PANEL_TEXT_COLOR = { 255, 200, 200, 200 }
local PANEL_TEXT_HIDDEN_COLOR = { 180, 120, 60, 60 }
local PANEL_DETAIL_LABEL_COLOR = { 200, 140, 140, 140 }
local PANEL_DETAIL_VALUE_COLOR = { 255, 220, 220, 220 }
local PANEL_SCROLL_SPEED = 3

-- Ignore-list toggle button colors. Muted to match the panel's dark theme; a
-- faint accent (the panel's selected-line purple) marks the open state, and a
-- subtle hover lift gives click feedback.
local IGNORE_BTN_COLOR = { 170, 38, 38, 46 }
local IGNORE_BTN_COLOR_HOVER = { 220, 58, 58, 70 }
local IGNORE_BTN_COLOR_OPEN = { 200, 72, 48, 78 }
local IGNORE_BTN_COLOR_OPEN_HOVER = { 235, 96, 64, 104 }
local IGNORE_BTN_BORDER_COLOR = { 110, 120, 120, 135 }
local IGNORE_BTN_TEXT_COLOR = { 255, 236, 236, 236 }
-- Header buttons size themselves to their measured label, resolution-independent.
-- text_size / draw_text use raw (unscaled) font pixels while draw_rect scales by
-- self.scale, so the button width (a rect) is converted from the actual-pixel
-- text width via inverse_scale: bw_pass = (text_px + 2*pad) * inverse_scale. This
-- makes the button wrap the text identically at every resolution -- no per-button
-- pixel trims. PANEL_BTN_PAD is the actual-pixel inset on each side of the label.
local PANEL_BTN_PAD = 6


-- Per-row edit-hide toggle. A small square at the right of each panel row:
-- filled green-ish while the editor box is shown, muted amber once it is
-- edit-hidden. The header "Reveal" button reuses the ignore-button palette but
-- lights up with its own accent while reveal is active.
local EDIT_TOGGLE_SHOWN_COLOR = { 200, 70, 120, 70 }
local EDIT_TOGGLE_HIDDEN_COLOR = { 200, 120, 80, 45 }
local EDIT_TOGGLE_BORDER_COLOR = { 140, 120, 120, 130 }
local EDIT_TOGGLE_HOVER_BORDER_COLOR = { 255, 220, 220, 220 }
local REVEAL_BTN_COLOR_ON = { 210, 60, 96, 72 }
local REVEAL_BTN_COLOR_ON_HOVER = { 240, 80, 128, 96 }

-- Row text color by tag state:
--   [S] only      -> orange    (stashed from edit mode, still live in the HUD)
--   [H] only      -> dark red  (hidden from the live HUD)
--   [S]+[H]       -> dark purple (hidden both places; lowest priority)
local ROW_COLOR_EDIT = { 255, 235, 150, 45 }
local ROW_COLOR_HIDDEN = { 255, 150, 45, 45 }
local ROW_COLOR_BOTH = { 255, 120, 70, 140 }

-- End-of-row toggle-box icons, by tag state. Drawn (tinted) over the box fill.
local TOGGLE_ICON_NORMAL = "content/ui/materials/hud/interactions/icons/attention"
local TOGGLE_ICON_STASHED = "content/ui/materials/icons/generic/loot"
local TOGGLE_ICON_HIDDEN = "content/ui/materials/icons/circumstances/ventilation_purge_01"
local TOGGLE_ICON_BOTH = "content/ui/materials/icons/system/settings/category_interface"
local TOGGLE_ICON_COLOR = { 255, 240, 240, 240 }
-- Icon size as a fraction of the toggle box (1.0 = fills the box, lower = smaller,
-- centered). Raise above 1.0 to overflow the box edges. One per icon type.
local TOGGLE_ICON_SCALE_NORMAL = 1.5
local TOGGLE_ICON_SCALE_STASHED = 1.35
local TOGGLE_ICON_SCALE_HIDDEN = 1.1
local TOGGLE_ICON_SCALE_BOTH = 1.25


local PANEL_FONT_TYPE = "proxima_nova_bold"
local PANEL_FONT_SIZE = 18
local PANEL_FONT_SIZE_SMALL = 15

local _FONT_OPTIONS = {
    "proxima_nova_bold",
    "proxima_nova_light",
    "proxima_nova_medium",
    "machine_medium",
    "itc_novarese_medium",
    "friz_quadrata",
    "rexlia",
}

local PANEL_SCALE_DEFAULT = 1
local PANEL_LIST_ROWS_DEFAULT = 18
local _cached_panel_scale = PANEL_SCALE_DEFAULT
local _cached_panel_list_rows = PANEL_LIST_ROWS_DEFAULT
local _cached_panel_width = PANEL_WIDTH_DEFAULT

-- Arrow-key movement (edit mode). When fixed move is on, each arrow tap nudges
-- the selected element by a fixed pixel step instead of the default ±1px/frame.
local _cached_fixed_arrow_move = false
local _cached_arrow_move_step = 5
local _cached_resize_step = 5
local _cached_z_step = 1
-- Editor-box fill mode: 1 = Fill (standard), 2 = No Fill (outline only).
local _cached_box_fill_mode = 1

local function _refresh_panel_font()
    local idx = mod:get("panel_font") or 1
    PANEL_FONT_TYPE = _FONT_OPTIONS[idx] or "proxima_nova_bold"
    local base = mod:get("panel_font_size") or 18
    PANEL_FONT_SIZE = base
    PANEL_FONT_SIZE_SMALL = math.max(base - 3, 8)
    _cached_panel_scale = tonumber(mod:get("panel_scale")) or PANEL_SCALE_DEFAULT
    _cached_panel_list_rows = math.max(6, math.floor(tonumber(mod:get("panel_list_rows")) or PANEL_LIST_ROWS_DEFAULT))
    _cached_panel_width = math.clamp(math.floor(tonumber(mod:get("panel_width")) or PANEL_WIDTH_DEFAULT), 220, 700)
    _cached_fixed_arrow_move = mod:get("fixed_arrow_move") and true or false
    _cached_arrow_move_step = math.max(1, math.floor(tonumber(mod:get("arrow_move_step")) or 5))
    _cached_resize_step = math.max(1, math.floor(tonumber(mod:get("resize_step")) or 5))
    _cached_z_step = math.max(1, math.floor(tonumber(mod:get("z_step")) or 1))
    _cached_box_fill_mode = math.floor(tonumber(mod:get("box_fill_mode")) or 1)
end

mod._refresh_panel_font = _refresh_panel_font

-- Pooled metrics table to avoid per-frame allocation
local _metrics_pool = {
    scale = 1, width = 0, margin = 0, line_h = 0, header_h = 0,
    detail_h = 0, list_rows = 18, font = 18, font_small = 15,
}

local function _get_panel_metrics(inverse_scale, has_selected, has_active_edit)
    -- Size scale folds in the resolution factor; positions/cursor still use the
    -- raw inverse_scale (passed in), so hit-testing stays aligned with drawing.
    local panel_scale = _cached_panel_scale * _panel_res_factor()
    local list_rows = _cached_panel_list_rows
    local ps_is = panel_scale * inverse_scale

    local m = _metrics_pool
    m.scale = panel_scale
    m.width = _cached_panel_width * ps_is
    m.margin = PANEL_MARGIN * ps_is
    m.line_h = PANEL_LINE_HEIGHT * ps_is
    m.header_h = PANEL_HEADER_HEIGHT * ps_is
    m.list_rows = list_rows
    -- Font sizes are ACTUAL pixels: draw_text / text_size do not scale font_size
    -- by self.scale (unlike draw_rect for geometry). So font = author * panel_scale
    -- (which already folds in the resolution factor) and NOT * inverse_scale --
    -- otherwise the inverse cancels the factor and the font stays a fixed size
    -- while the rest of the panel scales. This keeps font in step with geometry at
    -- every resolution.
    m.font = math.max(10, math.floor(PANEL_FONT_SIZE * panel_scale))
    m.font_small = math.max(8, math.floor(PANEL_FONT_SIZE_SMALL * panel_scale))

    local detail_h = 0
    if has_selected then
        local title_h = 24 * ps_is
        local helper_line_h = 18 * ps_is
        local helper_gap = 8 * ps_is
        local info_top = 8 * ps_is
        local helper1_y = info_top + title_h + 6 * ps_is
        local helper2_y = helper1_y + helper_line_h + helper_gap
        local editing_y = helper2_y + helper_line_h + helper_gap
        local fields_top = editing_y + helper_line_h + 14 * ps_is
        local row_h = 24 * ps_is
        local row_gap = 8 * ps_is
        local status_y = fields_top + 5 * (row_h + row_gap) + 10 * ps_is
        detail_h = status_y + 24 * ps_is
        if has_active_edit then
            detail_h = detail_h + 4 * ps_is
        end
    end
    m.detail_h = detail_h

    return m
end

-- Ignore-list panel geometry. Helpers are shared by draw + hit-testing so the
-- clickable regions always match what is rendered.
local IGNORE_PANEL_WIDTH = 230
local PANEL_DCLICK_TIME = 0.35

-- Side panels (Controls / Ignore) use a single-row header; only the main panel
-- carries the two-row header.
local PANEL_SIDE_HEADER_HEIGHT = 28
local function _side_header_h(scale, inverse_scale)
    return PANEL_SIDE_HEADER_HEIGHT * scale * inverse_scale
end

-- Horizontal room the ignore list needs to the right of the main panel (gap +
-- its own width). Used to keep the list on screen: see _update_side_panel_shift.
local function _ignore_panel_span(scale, inverse_scale)
    return (6 + IGNORE_PANEL_WIDTH) * scale * inverse_scale
end

local function _get_ignore_panel_rect(px, py, pw, line_h, count, scale, inverse_scale)
    local gap = 6 * scale * inverse_scale
    local ipx = px + pw + gap
    local ipw = IGNORE_PANEL_WIDTH * scale * inverse_scale
    local rows = math.max(count, 1)
    local iph = _side_header_h(scale, inverse_scale) + rows * line_h + 8 * scale * inverse_scale
    return ipx, py, ipw, iph
end

-- Legend (controls reference) side panel. Drawn to the LEFT of the main panel.
local LEGEND_PANEL_WIDTH = 370
local LEGEND_KEY_COL = 132
local PANEL_LEGEND_SECTION_COLOR = { 255, 235, 185, 95 }
local PANEL_LEGEND_KEY_COLOR = { 255, 225, 225, 170 }

-- Horizontal room the legend needs to the LEFT of the main panel (gap + its own
-- width). Mirror of _ignore_panel_span; see _update_side_panel_shift.
local function _legend_panel_span(scale, inverse_scale)
    return (6 + LEGEND_PANEL_WIDTH) * scale * inverse_scale
end

local function _get_legend_panel_rect(px, py, line_h, count, scale, inverse_scale)
    local gap = 6 * scale * inverse_scale
    local lpw = LEGEND_PANEL_WIDTH * scale * inverse_scale
    local lpx = math.max(0, px - gap - lpw)
    local rows = math.max(count, 1)
    local lph = _side_header_h(scale, inverse_scale) + rows * line_h + 8 * scale * inverse_scale
    return lpx, py, lpw, lph
end

-- Control reference rows. `section` entries are headers (loc key); the rest carry
-- a literal `key` (input combo, not translated) + an `action` loc key. Section and
-- action are resolved via mod:localize at draw time.
local _LEGEND_ROWS = {
    { section = "legend_sec_select" },
    { key = "Left-click", action = "legend_a_select" },
    { key = "Ctrl+Click", action = "legend_a_addremove" },
    { key = "Double-click row", action = "legend_a_ignore" },
    { section = "legend_sec_move" },
    { key = "Shift+Drag", action = "legend_a_move" },
    { key = "Arrow keys", action = "legend_a_nudge" },
    { key = "Shift+Ctrl drag", action = "legend_a_invertsnap" },
    { key = "Ctrl+Shift+C", action = "legend_a_center" },
    { key = "Tab", action = "legend_a_reset" },
    { section = "legend_sec_size" },
    { key = "Alt+Drag edge", action = "legend_a_resize" },
    { key = "Alt+Arrows", action = "legend_a_resizestep" },
    { key = "Shift+Up/Down", action = "legend_a_zorder" },
    { key = "Scroll on elem", action = "legend_a_scale" },
    { section = "legend_sec_visibility" },
    { key = "Right-click", action = "legend_a_hide" },
    { key = "Row box", action = "legend_a_stash" },
    { section = "legend_sec_panel" },
    { key = "Drag header", action = "legend_a_movepanel" },
    { key = "Scroll list", action = "legend_a_scrollrows" },
    { key = "Click value", action = "legend_a_edit" },
}

-- Detect the correct draw_text API signature once, then reuse it.
local _draw_text_variant -- nil = not yet detected, 1-6 = detected variant

local function _safe_draw_text(ui_renderer, text, font_type, font_size, position, size, color, horizontal_alignment, vertical_alignment)
    if text == nil then
        return false
    end
    text = tostring(text)
    if text == "" then
        return false
    end

    local options = {
        horizontal_alignment = horizontal_alignment or "left",
        vertical_alignment = vertical_alignment or "center",
        drop_shadow = true,
        word_wrap = false,
    }

    if _draw_text_variant then
        local v = _draw_text_variant
        if v == 1 then UIRenderer.draw_text(ui_renderer, text, font_type, font_size, position, size, color, options)
        elseif v == 2 then UIRenderer.draw_text(ui_renderer, text, font_type, font_size, position, size, color)
        elseif v == 3 then UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, color, options)
        elseif v == 4 then UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, color)
        elseif v == 5 then UIRenderer.draw_text(ui_renderer, text, nil, font_size, font_type, position, size, color, options)
        elseif v == 6 then UIRenderer.draw_text(ui_renderer, text, nil, font_size, font_type, position, size, color)
        end
        return true
    end

    -- First call: probe each variant once to find the right one
    local probes = {
        function() UIRenderer.draw_text(ui_renderer, text, font_type, font_size, position, size, color, options) end,
        function() UIRenderer.draw_text(ui_renderer, text, font_type, font_size, position, size, color) end,
        function() UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, color, options) end,
        function() UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, color) end,
        function() UIRenderer.draw_text(ui_renderer, text, nil, font_size, font_type, position, size, color, options) end,
        function() UIRenderer.draw_text(ui_renderer, text, nil, font_size, font_type, position, size, color) end,
    }
    for i = 1, #probes do
        local ok = pcall(probes[i])
        if ok then
            _draw_text_variant = i
            return true
        end
    end

    return false
end

local RESIZE_HANDLE_SIZE = 12
local RESIZE_HANDLE_COLOR = { 220, 255, 200, 50 }
local RESIZE_HANDLE_HOVER_COLOR = { 255, 255, 255, 100 }
local RESIZE_EDGE_THRESHOLD = 10

-- Outline drawn around every selected node (border only, no fill) so a selection
-- stays visible even when its editor box is hidden (stashed / hidden).
local SELECTION_OUTLINE_COLOR = { 255, 120, 210, 255 }
local SELECTION_OUTLINE_THICKNESS = 2

-- No-fill mode draws a plain outline around every visible (non-stashed) box so the
-- elements stay locatable without their grey fill.
local BOX_OUTLINE_COLOR = { 200, 180, 180, 180 }
local BOX_OUTLINE_THICKNESS = 1

local _excluded_element_names = {
    HudElementCustomizer = true,
    HudElementPrologueTutorialSequenceTransitionEnd = true,
    HudElementPrologueTutorialInfoBox = true,
    HudElementCrosshair = true,
    -- Crosshair HUD (third-party element) stays editable: shipped editable in
    -- 2.1.5 and users position it. Not to be confused with HudElementCrosshair
    -- (the actual crosshair) above, which stays locked.
    HudElementCrosshairHud = false,
    HudElementInteraction = true,
    HudElementWorldMarkers = true,
    HudElementEmoteWheel = true,
    HudElementSmartTagging = true,
    HudElementDamageIndicator = true,
    HudElementRingHud_player = true,
    HudElementRingHud_team_docked = true,
    ConstantElementWatermark = true,
    ConstantElementPopupHandler = true,
    ConstantElementSoftwareCursor = true
}

local _excluded_scenegraphs_by_element = {
    HudElementPlayerWeaponHandler = {
        weapon_slot_1 = true,
        weapon_slot_2 = true,
        weapon_slot_3 = true,
        weapon_slot_4 = true
    },
    HudElementTacticalOverlay = {
        background = true,
        canvas = true,
    }
}

local _allowed_scenegraphs_by_element = {
}

-- ============================================================================
-- Ignore list
-- ============================================================================
-- `_excluded_element_names` above are the built-in (system) ignores: the editor
-- itself, crosshairs, world markers, etc. They are never user-editable.
-- `_user_ignored` is the player-managed set, persisted in settings and toggled
-- live from the edit-mode info panel. Effective ignore = system OR user.

local USER_IGNORED_SETTING_ID = "user_ignored_elements"
local _user_ignored = {}

local function _is_element_ignored(element_name)
    return _excluded_element_names[element_name] == true or _user_ignored[element_name] == true
end

local function _load_user_ignored()
    local saved = mod:get(USER_IGNORED_SETTING_ID)
    _user_ignored = {}
    if type(saved) == "table" then
        for _, name in ipairs(saved) do
            if type(name) == "string" and name ~= "" then
                _user_ignored[name] = true
            end
        end
    end
end

local function _save_user_ignored()
    local arr = {}
    for name in pairs(_user_ignored) do
        arr[#arr + 1] = name
    end
    table.sort(arr)
    mod:set(USER_IGNORED_SETTING_ID, arr)
end

-- ============================================================================
-- Edit-mode hide list
-- ============================================================================
-- Distinct from ignore and from per-node `is_hidden`:
--   * Ignore     drops the element entirely (no box, no position override).
--   * is_hidden  hides the element in the LIVE HUD (right-click).
--   * Edit-hide  keeps the element shown in the live HUD with its applied
--                coords, but hides only its EDITOR box so the workspace can be
--                de-cluttered. Per element name, persisted, toggled per row.
-- The header "Reveal" toggle temporarily forces edit-hidden boxes back on so a
-- hidden element can be grabbed in the viewport without un-hiding it.

local USER_EDIT_HIDDEN_SETTING_ID = "user_edit_hidden_elements"
local _user_edit_hidden = {}

local function _is_element_edit_hidden(element_name)
    return _user_edit_hidden[element_name] == true
end

local function _load_user_edit_hidden()
    local saved = mod:get(USER_EDIT_HIDDEN_SETTING_ID)
    _user_edit_hidden = {}
    if type(saved) == "table" then
        for _, name in ipairs(saved) do
            if type(name) == "string" and name ~= "" then
                _user_edit_hidden[name] = true
            end
        end
    end
end

local function _save_user_edit_hidden()
    local arr = {}
    for name in pairs(_user_edit_hidden) do
        arr[#arr + 1] = name
    end
    table.sort(arr)
    mod:set(USER_EDIT_HIDDEN_SETTING_ID, arr)
end

-- ============================================================================
-- Keyboard helpers
-- ============================================================================

local Keyboard = Keyboard
local _kb_index_cache = {}

local function _get_keyboard()
    if not Keyboard then
        Keyboard = rawget(_G, "Keyboard")
    end
    return Keyboard
end

local function _get_button_index(kb, key_name)
    local idx = _kb_index_cache[key_name]
    if idx ~= nil then
        return idx ~= false and idx or nil
    end
    -- Try button_index first, then button_id
    if kb.button_index then
        local ok, result = pcall(kb.button_index, key_name)
        if ok and result then
            _kb_index_cache[key_name] = result
            return result
        end
    end
    if kb.button_id then
        local ok, result = pcall(kb.button_id, key_name)
        if ok and result then
            _kb_index_cache[key_name] = result
            return result
        end
    end
    _kb_index_cache[key_name] = false
    return nil
end

local function is_shift_held()
    local kb = _get_keyboard()
    if not kb then return false end
    local idx = _get_button_index(kb, "left shift")
    return idx and kb.button(idx) > 0.5
end

local function is_alt_held()
    local kb = _get_keyboard()
    if not kb then return false end
    local idx = _get_button_index(kb, "left alt")
    return idx and kb.button(idx) > 0.5
end

local function is_ctrl_held()
    local kb = _get_keyboard()
    if not kb then return false end
    local idx = _get_button_index(kb, "left ctrl")
    return idx and kb.button(idx) > 0.5
end

-- ============================================================================
-- Utilities
-- ============================================================================



local function _point_in_rect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

local function _format_field_value(v)
    if v == nil then
        return ""
    end
    if math.type and math.type(v) == "integer" then
        return tostring(v)
    end
    local n = tonumber(v) or 0
    if math.abs(n - math.floor(n)) < 0.001 then
        return tostring(math.floor(n))
    end
    return string.format("%.2f", n)
end

local function _copy_table(t)
    return t and table.clone(t) or nil
end

local function split_node_name(node_name)
    local splits = string.split(node_name, "|")
    return splits[1], splits[2]
end

local function short_element_name(node_name)
    local element_name, scenegraph_id = split_node_name(node_name)
    -- Strip "HudElement" or "ConstantElement" prefix for display
    local short = element_name:gsub("^HudElement", ""):gsub("^ConstantElement", "C:")
    if scenegraph_id and scenegraph_id ~= "" then
        return short .. "|" .. scenegraph_id
    end
    return short
end

-- ============================================================================
-- Definitions
-- ============================================================================

local _definitions = {
    scenegraph_definition = {
        screen = UIWorkspaceSettings.screen,
        background = {
            parent = "screen",
            scale = "scale",
            size = { 1920, 1080 },
            position = { 0, 0, 50 }
        }
    },
    widget_definitions = {}
}

-- ============================================================================
-- Class
-- ============================================================================

local HudElementCustomizer = class("HudElementCustomizer", "HudElementBase")

function HudElementCustomizer:init(parent, draw_layer, start_scale)
    self._selected_node_list = {}
    self._widget_press_stack = {}
    self._grid_line_positions = { {}, {} }
    self._always_full_alpha = true
    self._start_scale = start_scale

    -- Cached settings
    self._num_rows = mod:get("grid_rows") or 3
    self._num_cols = mod:get("grid_cols") or 3
    self._display_grid = mod:get("display_grid")
    if self._display_grid == nil then self._display_grid = true end
    self._snap_to_grid = mod:get("snap_to_grid")
    if self._snap_to_grid == nil then self._snap_to_grid = true end
    self._snap_to_elements = mod:get("snap_to_elements")
    if self._snap_to_elements == nil then self._snap_to_elements = true end
    self._show_info_panel = mod:get("show_info_panel")
    if self._show_info_panel == nil then self._show_info_panel = true end

    self._saved_node_settings = mod:get("saved_node_settings") or {}
    self._default_node_settings = {}

    -- Persistence dirty-tracking. _settings_dirty = in-memory layout changed but
    -- not yet pushed through mod:set (which deep-clones the whole table, so it
    -- must not run per drag frame). _apply_needed = live-HUD overrides are stale
    -- and the full apply pass must run on the next hide; starts true so the
    -- boot-time set_visible(false) applies the saved layout. Without it, every
    -- gameplay visibility-group flip (comm wheel, tactical overlay, death) would
    -- rerun the whole apply + persist pass and hitch.
    self._settings_dirty = false
    self._apply_needed = true

    -- Cursor tracking - FIX: track our own push state, not input_manager state
    self._cursor_pushed = false
    self._using_cursor = false

    -- Info panel state
    self._panel_scroll_offset = 0
    self._panel_all_node_names = {}  -- ordered list of all node names (full)
    self._panel_normal_list = {}     -- displayed rows (excludes ignored elements)
    self._panel_ignore_list = {}     -- user-ignored element names (for the side panel)
    self._panel_hovered_index = nil
    self._panel_dragging = false
    self._panel_drag_offset = nil
    self._panel_position = mod:get("panel_position")
    self._panel_active_field = nil
    self._panel_field_targets = {}
    self._panel_key_repeat = {}
    self._panel_mouse_over = false
    self._panel_hover_preview_node = nil

    -- Ignore-list panel state
    _load_user_ignored()
    self._show_ignore_panel = false
    self._ignore_hovered_index = nil
    self._ignore_btn_hover = false
    self._ignore_btn_rect = nil
    self._side_shift_x = 0           -- transient shift that makes room for open side panels
    self._panel_dclick_key = nil
    self._panel_dclick_t = 0

    -- Edit-mode hide state
    _load_user_edit_hidden()
    self._reveal_edit_hidden = false
    self._reveal_btn_hover = false
    self._reveal_btn_rect = nil
    self._panel_edit_toggle_targets = {}
    self._edit_toggle_hover_element = nil

    -- Legend (controls reference) panel state
    self._show_legend = false
    self._legend_btn_hover = false
    self._legend_btn_rect = nil

    -- Resize state
    self._resize_mode = false
    self._resize_edge = nil  -- "tl", "tr", "bl", "br", "t", "b", "l", "r"
    self._resize_start_cursor = nil
    self._resize_start_size = nil
    self._resize_start_pos = nil
    self._resize_node_name = nil

    -- Build visibility group data
    local visibility_groups = parent._visibility_groups
    local num_visibility_groups = #visibility_groups
    local elements_by_group = {}
    local scenegraphs = {}
    for i = 2, num_visibility_groups do
        local visibility_group = visibility_groups[i]
        local group_name = visibility_group.name
        local elements = visibility_group.visible_elements or {}
        table.insert(elements_by_group, {
            name = group_name,
            elements = elements
        })
        scenegraphs[group_name] = {}
        for element_name in pairs(elements) do
            scenegraphs[group_name][element_name] = {}
        end
    end

    local selected_group_index = table.find_by_key(elements_by_group, "name", "alive") or 1
    local selected_group = elements_by_group[selected_group_index]
    local selected_group_elements = selected_group.elements

    local constant_elements = Managers.ui:ui_constant_elements()
    local constant_visibility_groups = constant_elements._visibility_groups
    local _, default_visibility_group = table.find_by_key(constant_visibility_groups, "name", "default")
    local visible_elements = (default_visibility_group and default_visibility_group.visible_elements) or {}

    table.merge(selected_group_elements, visible_elements)

    for element_name in pairs(visible_elements) do
        scenegraphs.alive[element_name] = {}
    end

    self._elements_by_group = elements_by_group
    self._selected_group_index = selected_group_index
    self._scenegraphs = scenegraphs

    -- Commands
    mod:command("grid", "", function(num_cols, num_rows)
        local is_displayed = self._display_grid
        if (not num_cols and not num_rows) or (self._num_cols == num_cols and self._num_rows == num_rows) then
            is_displayed = not is_displayed
        else
            is_displayed = true
        end

        self._grid_line_positions = { {}, {} }
        self._num_cols = num_cols or self._num_cols
        self._num_rows = num_rows or self._num_rows
        self._display_grid = is_displayed

        mod:set("grid_rows", self._num_rows)
        mod:set("grid_cols", self._num_cols)
        mod:set("display_grid", self._display_grid)

        mod:notify("Grid (%sx%s): [%s]", self._num_cols, self._num_rows, is_displayed and "on" or "off")
    end)

    mod:command("snap_to_grid", "", function(active)
        if active == nil then
            active = not self._snap_to_grid
        end
        self._snap_to_grid = active
        mod:set("snap_to_grid", active)
        mod:notify("Snap to grid: [%s]", active and "on" or "off")
    end)

    mod:command("snap_to_elements", "", function(active)
        if active == nil then
            active = not self._snap_to_elements
        end
        self._snap_to_elements = active
        mod:set("snap_to_elements", active)
        mod:notify("Snap to elements: [%s]", active and "on" or "off")
    end)

    mod:command("panel", "", function()
        self._show_info_panel = not self._show_info_panel
        mod:set("show_info_panel", self._show_info_panel)
        mod:notify("Info panel: [%s]", self._show_info_panel and "on" or "off")
    end)

    _refresh_panel_font()

    HudElementCustomizer.super.init(self, parent, draw_layer, start_scale, _definitions)
end

-- ============================================================================
-- Element lookup
-- ============================================================================

function HudElementCustomizer:_get_element(element_name)
    local element = self._parent:element(element_name)
    if not element then
        local ui_constant_elements = Managers.ui:ui_constant_elements()
        element = ui_constant_elements:element(element_name)
    end
    return element
end

-- ============================================================================
-- Setup
-- ============================================================================

function HudElementCustomizer:_setup_elements(render_settings)
    local saved_node_settings = self._saved_node_settings
    local default_node_settings = self._default_node_settings
    local inverse_scale = render_settings.inverse_scale
    local font_type = "proxima_nova_bold"
    local font_size = 16
    local all_node_names = {}
    local seen_panel_nodes = {}

    for i, group_data in ipairs(self._elements_by_group) do
        local group_name = group_data.name
        local elements = group_data.elements
        local element_scenegraphs = self._scenegraphs[group_name]

        for element_name in pairs(elements) do
            repeat
                local element = self:_get_element(element_name)
                -- Only system ignores are skipped at build time. User ignores still
                -- get widgets/panel nodes so they can be toggled live (hidden via the
                -- panel filter), then restored without rebuilding the element set.
                if _excluded_element_names[element_name] or not element then
                    break
                end

                local excluded_scenegraphs = _excluded_scenegraphs_by_element[element_name] or {}
                local allowed_scenegraphs = _allowed_scenegraphs_by_element[element_name]
                local ui_scenegraph = element._ui_scenegraph
                local element_definitions = element._definitions
                local scenegraph_definition = element_definitions and element_definitions.scenegraph_definition
                local children_scenegraphs = element_scenegraphs[element_name]
                local hierarchical_scenegraph = (ui_scenegraph and ui_scenegraph.hierarchical_scenegraph) or {}

                if not children_scenegraphs then
                    element_scenegraphs[element_name] = {}
                    children_scenegraphs = element_scenegraphs[element_name]
                end

                for j, scenegraph in ipairs(hierarchical_scenegraph) do
                    local children = scenegraph.children or {}
                    for _, child in ipairs(children) do
                        repeat
                            local child_name = child.name
                            if excluded_scenegraphs[child_name] then
                                break
                            end
                            if allowed_scenegraphs and not allowed_scenegraphs[child_name] then
                                break
                            end

                            child = table.clone(child)

                            local node_name = string.format("%s|%s", element_name, child_name)
                            local node_settings = saved_node_settings[node_name]

                            -- Keep edit-mode boxes on a stable top-left basis.
                            -- Native pivots are preserved in default_settings for reset/reference,
                            -- but using them directly for the editor overlay makes many boxes jump or disappear.
                            local vertical_alignment = "top"
                            local horizontal_alignment = "left"

                            local live_position = child.world_position or child.position or { 0, 0, 0 }
                            local live_size = child.size or { 25, 25 }
                            local saved_position = node_settings and (node_settings.position or {
                                node_settings.x,
                                node_settings.y,
                                node_settings.z,
                            })
                            local position = {
                                (saved_position and saved_position[1]) or live_position[1] or 0,
                                (saved_position and saved_position[2]) or live_position[2] or 0,
                                (saved_position and saved_position[3]) or live_position[3] or 0,
                            }
                            local saved_size = node_settings and node_settings.size
                            local size = {
                                (saved_size and saved_size[1]) or live_size[1] or 25,
                                (saved_size and saved_size[2]) or live_size[2] or 25,
                            }
                            local scenegraph_id = child_name

                            local scenegraph_node = scenegraph_definition and scenegraph_definition[scenegraph_id]
                            local default_settings = (node_settings and node_settings.default_settings) or {
                                size = (scenegraph_node and table.clone(scenegraph_node.size)) or table.clone(child.size),
                                position = (scenegraph_node and table.clone(scenegraph_node.position)) or table.clone(child.position),
                                vertical_alignment = (scenegraph_node and scenegraph_node.vertical_alignment) or child.vertical_alignment,
                                horizontal_alignment = (scenegraph_node and scenegraph_node.horizontal_alignment) or child.horizontal_alignment
                            }

                            default_node_settings[node_name] = default_settings

                            size[1] = ((size[1] ~= 0 and size[1]) or 25)
                            size[2] = ((size[2] ~= 0 and size[2]) or 25)

                            local is_constant_element = string.starts_with(element_name, "ConstantElement")
                            if is_constant_element then
                                local inverse_hud_scale = self:_get_inverse_hud_scale()
                                size[1] = default_settings.size[1] * inverse_hud_scale
                                size[2] = default_settings.size[2] * inverse_hud_scale
                                position[1] = position[1] * inverse_hud_scale
                                position[2] = position[2] * inverse_hud_scale
                            end

                            table.insert(children_scenegraphs, {
                                name = node_name,
                                size = size,
                                position = position,
                                vertical_alignment = vertical_alignment,
                                horizontal_alignment = horizontal_alignment,
                            })

                            _definitions.scenegraph_definition[node_name] = {
                                parent = "screen",
                                size = size,
                                position = position,
                                vertical_alignment = vertical_alignment,
                                horizontal_alignment = horizontal_alignment
                            }

                            local content_overrides = {
                                is_hidden = node_settings and node_settings.is_hidden,
                                size = size,
                                scale = (node_settings and node_settings.scale) or 1
                            }

                            -- Pre-compute inner size to avoid per-frame allocation
                            local inner_w = size[1] - 4
                            local inner_h = size[2] - 4

                            local definition = UIWidget.create_definition({
                                {
                                    pass_type = "hotspot",
                                    content_id = "hotspot",
                                    content = {
                                        pressed_callback = callback(self, "_on_widget_pressed", node_name),
                                        right_pressed_callback = callback(self, "_on_widget_right_pressed", node_name),
                                        double_click_callback = callback(self, "_on_widget_double_clicked", node_name)
                                    }
                                },
                                {
                                    pass_type = "rect",
                                    style_id = "rect",
                                    style = {
                                        color = { 255, 255, 255, 255 },
                                        -- Fill colours resolved from the Editor Colors settings
                                        -- (custom_hud.lua _cached_colors). Captured by reference
                                        -- at build time; a colour change rebuilds the HUD.
                                        color_default = mod._cached_colors.rect_default,
                                        color_hovered = mod._cached_colors.rect_hovered,
                                        color_hidden = mod._cached_colors.rect_hidden,
                                        color_hidden_hovered = mod._cached_colors.rect_hidden_hovered,
                                        anim_hover_speed = 1,
                                        size = { inner_w, inner_h },
                                        offset = { 2, 2, 2 }
                                    },
                                    change_function = function(content, style)
                                        local color = style.color
                                        local hotspot = content.hotspot
                                        local anim_hover_progress = hotspot.anim_hover_progress
                                        local is_hidden = content.is_hidden
                                        local color_from = is_hidden and style.color_hidden or style.color_default
                                        local color_to = is_hidden and style.color_hidden_hovered or style.color_hovered
                                        local content_size = content.size

                                        if content_size then
                                            style.size[1] = content_size[1] - 4
                                            style.size[2] = content_size[2] - 4
                                        end

                                        ColorUtilities.color_lerp(color_from, color_to, anim_hover_progress, color, false)

                                        -- No-fill mode: remove the grey fill (coloured borders are
                                        -- hidden too; outlines are redrawn in _draw_box_outlines).
                                        if _cached_box_fill_mode == 2 then
                                            color[1] = 0
                                        end
                                    end
                                },
                                -- Coloured edge borders (top/bottom/left/right), each themed
                                -- independently via the Editor Colors settings. Lerp is written
                                -- in place (no per-frame table alloc). Size/offset track live
                                -- resize like the fill. Hidden in no-fill mode so _draw_box_outlines
                                -- owns the outline there (avoids a doubled edge).
                                {
                                    pass_type = "rect",
                                    style_id = "border_top",
                                    style = {
                                        color = { 255, 255, 255, 255 },
                                        color_default = mod._cached_colors.border_top_default,
                                        color_hovered = mod._cached_colors.border_top_hovered,
                                        color_hidden = mod._cached_colors.border_top_hidden,
                                        color_hidden_hovered = mod._cached_colors.border_top_hidden_hovered,
                                        anim_hover_speed = 1,
                                        size = { inner_w, 2 },
                                        offset = { 2, 2, 5 }
                                    },
                                    visibility_function = function(content, style)
                                        return _cached_box_fill_mode ~= 2
                                    end,
                                    change_function = function(content, style)
                                        local hotspot = content.hotspot
                                        local is_hidden = content.is_hidden
                                        local color_from = is_hidden and style.color_hidden or style.color_default
                                        local color_to = is_hidden and style.color_hidden_hovered or style.color_hovered
                                        local content_size = content.size
                                        if content_size then
                                            style.size[1] = content_size[1] - 4
                                        end
                                        ColorUtilities.color_lerp(color_from, color_to, hotspot.anim_hover_progress or 0, style.color, false)
                                    end
                                },
                                {
                                    pass_type = "rect",
                                    style_id = "border_bottom",
                                    style = {
                                        color = { 255, 255, 255, 255 },
                                        color_default = mod._cached_colors.border_bottom_default,
                                        color_hovered = mod._cached_colors.border_bottom_hovered,
                                        color_hidden = mod._cached_colors.border_bottom_hidden,
                                        color_hidden_hovered = mod._cached_colors.border_bottom_hidden_hovered,
                                        anim_hover_speed = 1,
                                        size = { inner_w, 2 },
                                        offset = { 2, inner_h, 5 }
                                    },
                                    visibility_function = function(content, style)
                                        return _cached_box_fill_mode ~= 2
                                    end,
                                    change_function = function(content, style)
                                        local hotspot = content.hotspot
                                        local is_hidden = content.is_hidden
                                        local color_from = is_hidden and style.color_hidden or style.color_default
                                        local color_to = is_hidden and style.color_hidden_hovered or style.color_hovered
                                        local content_size = content.size
                                        if content_size then
                                            style.size[1] = content_size[1] - 4
                                            style.offset[2] = content_size[2] - 4
                                        end
                                        ColorUtilities.color_lerp(color_from, color_to, hotspot.anim_hover_progress or 0, style.color, false)
                                    end
                                },
                                {
                                    pass_type = "rect",
                                    style_id = "border_left",
                                    style = {
                                        color = { 255, 255, 255, 255 },
                                        color_default = mod._cached_colors.border_left_default,
                                        color_hovered = mod._cached_colors.border_left_hovered,
                                        color_hidden = mod._cached_colors.border_left_hidden,
                                        color_hidden_hovered = mod._cached_colors.border_left_hidden_hovered,
                                        anim_hover_speed = 1,
                                        size = { 2, inner_h },
                                        offset = { 2, 2, 5 }
                                    },
                                    visibility_function = function(content, style)
                                        return _cached_box_fill_mode ~= 2
                                    end,
                                    change_function = function(content, style)
                                        local hotspot = content.hotspot
                                        local is_hidden = content.is_hidden
                                        local color_from = is_hidden and style.color_hidden or style.color_default
                                        local color_to = is_hidden and style.color_hidden_hovered or style.color_hovered
                                        local content_size = content.size
                                        if content_size then
                                            style.size[2] = content_size[2] - 4
                                        end
                                        ColorUtilities.color_lerp(color_from, color_to, hotspot.anim_hover_progress or 0, style.color, false)
                                    end
                                },
                                {
                                    pass_type = "rect",
                                    style_id = "border_right",
                                    style = {
                                        color = { 255, 255, 255, 255 },
                                        color_default = mod._cached_colors.border_right_default,
                                        color_hovered = mod._cached_colors.border_right_hovered,
                                        color_hidden = mod._cached_colors.border_right_hidden,
                                        color_hidden_hovered = mod._cached_colors.border_right_hidden_hovered,
                                        anim_hover_speed = 1,
                                        size = { 2, inner_h },
                                        offset = { inner_w, 2, 5 }
                                    },
                                    visibility_function = function(content, style)
                                        return _cached_box_fill_mode ~= 2
                                    end,
                                    change_function = function(content, style)
                                        local hotspot = content.hotspot
                                        local is_hidden = content.is_hidden
                                        local color_from = is_hidden and style.color_hidden or style.color_default
                                        local color_to = is_hidden and style.color_hidden_hovered or style.color_hovered
                                        local content_size = content.size
                                        if content_size then
                                            style.size[2] = content_size[2] - 4
                                            style.offset[1] = content_size[1] - 4
                                        end
                                        ColorUtilities.color_lerp(color_from, color_to, hotspot.anim_hover_progress or 0, style.color, false)
                                    end
                                },
                                -- Element name tooltip on hover
                                {
                                    pass_type = "text",
                                    value_id = "text",
                                    value = node_name,
                                    style_id = "text",
                                    style = {
                                        size = { 1920, 1080 },
                                        font_size = font_size * inverse_scale,
                                        font_type = font_type,
                                        text_horizontal_alignment = "left",
                                        text_vertical_alignment = "top",
                                        text_color = Color.terminal_text_body(255, true),
                                        drop_shadow = true,
                                        offset = { 0, -14 * inverse_scale, 4 }
                                    },
                                    visibility_function = function(content, style)
                                        return content.hotspot.is_hover and not content.is_panel_preview_hover and not content.suppress_hover_labels
                                    end
                                },
                                -- Scale label
                                {
                                    pass_type = "text",
                                    value_id = "scale_text",
                                    value = "x1.00",
                                    style = {
                                        font_size = font_size * inverse_scale,
                                        font_type = font_type,
                                        text_horizontal_alignment = "center",
                                        text_vertical_alignment = "center",
                                        text_color = Color.terminal_text_body(255, true),
                                        drop_shadow = true,
                                        offset = { 0, 0, 4 }
                                    },
                                    visibility_function = function(content, style)
                                        return (content.hotspot.is_hover and not content.suppress_hover_labels) or content.hotspot.is_selected
                                    end,
                                    change_function = function(content, style)
                                        content.scale_text = string.format("x%.02f", content.scale or 1)
                                    end
                                },
                                -- Position info when selected
                                {
                                    pass_type = "text",
                                    value_id = "pos_text",
                                    value = "",
                                    style_id = "pos_text",
                                    style = {
                                        size = { 300, 20 },
                                        font_size = (font_size - 2) * inverse_scale,
                                        font_type = font_type,
                                        text_horizontal_alignment = "left",
                                        text_vertical_alignment = "top",
                                        text_color = { 220, 180, 255, 180 },
                                        drop_shadow = true,
                                        offset = { 0, -28 * inverse_scale, 4 }
                                    },
                                    visibility_function = function(content, style)
                                        return content.hotspot.is_selected
                                    end,
                                    change_function = function(content, style)
                                        local sz = content.size
                                        local sc = content.scale or 1
                                        content.pos_text = string.format("%.0f,%.0f  z:%.0f  %dx%d",
                                            content.node_x or 0, content.node_y or 0, content.node_z or 0,
                                            sz and sz[1] or 0, sz and sz[2] or 0)
                                    end
                                }
                            }, node_name, content_overrides)

                            _definitions.widget_definitions[node_name] = definition
                            if not seen_panel_nodes[node_name] then
                                seen_panel_nodes[node_name] = true
                                table.insert(all_node_names, node_name)
                            end

                        until true
                    end
                end
            until true
        end
    end

    -- Sort node names alphabetically for panel display
    table.sort(all_node_names)
    self._panel_all_node_names = all_node_names

    local scale = (self._inverse_scale and 1 / self._inverse_scale) or self._start_scale
    self._ui_scenegraph = self:_create_scenegraph(_definitions, scale)
    self:_create_widgets(_definitions, self._widgets, self._widgets_by_name)
    self:_apply_saved_node_settings()
    self:_rebuild_panel_lists()
    self:_apply_ignore_visibility()
    self._setup_complete = true
end

-- ============================================================================
-- Ignore list
-- ============================================================================

-- Split the full node list into the displayed (non-ignored) rows and the
-- side-panel list of user-ignored element names. Called at setup and whenever
-- the ignore set changes.
function HudElementCustomizer:_rebuild_panel_lists()
    local all = self._panel_all_node_names or {}
    local normal = self._panel_normal_list
    for i = #normal, 1, -1 do normal[i] = nil end

    for i = 1, #all do
        local node_name = all[i]
        local element_name = split_node_name(node_name)
        if not _is_element_ignored(element_name) then
            normal[#normal + 1] = node_name
        end
    end

    local ignore = self._panel_ignore_list
    for i = #ignore, 1, -1 do ignore[i] = nil end
    for element_name in pairs(_user_ignored) do
        ignore[#ignore + 1] = element_name
    end
    table.sort(ignore)

    self:_sort_panel_normal_list()
end

-- Tag rank for list ordering: untagged (0) on top, then [S] (1), then [H] (2),
-- then [S]+[H] (3) at the bottom.
function HudElementCustomizer:_tag_rank(node_name)
    local element_name = split_node_name(node_name)
    local node_settings = self._saved_node_settings[node_name]
    local is_hidden = node_settings and node_settings.is_hidden and true or false
    local stashed = _is_element_edit_hidden(element_name)
    if is_hidden and stashed then
        return 3
    elseif is_hidden then
        return 2
    elseif stashed then
        return 1
    end
    return 0
end

-- Sort the displayed rows by tag rank, keeping the original build order within a
-- rank so untagged rows stay stable. Called on build and whenever a tag changes.
function HudElementCustomizer:_sort_panel_normal_list()
    local list = self._panel_normal_list
    if not list or #list < 2 then
        return
    end

    local all = self._panel_all_node_names or {}
    local order = {}
    for i = 1, #all do
        order[all[i]] = i
    end

    table.sort(list, function(a, b)
        local ra, rb = self:_tag_rank(a), self:_tag_rank(b)
        if ra ~= rb then
            return ra < rb
        end
        return (order[a] or 0) < (order[b] or 0)
    end)
end

-- Hide the editor boxes of ignored / edit-hidden elements and show the rest. The
-- engine honors widget.visible, so hidden boxes are neither drawn nor
-- interactive. Edit-hidden boxes are suppressed only while reveal is off; the
-- elements keep their position overrides in the live HUD regardless.
function HudElementCustomizer:_apply_ignore_visibility()
    local widgets_by_name = self._widgets_by_name
    if not widgets_by_name then
        return
    end

    local reveal = self._reveal_edit_hidden
    for node_name, widget in pairs(widgets_by_name) do
        local element_name = split_node_name(node_name)
        local ignored = _is_element_ignored(element_name)
        local edit_hidden = (not reveal) and _is_element_edit_hidden(element_name)
        local hide_box = ignored or edit_hidden
        widget.visible = not hide_box
        if hide_box then
            local content = widget.content
            local hotspot = content and content.hotspot
            if hotspot then
                hotspot.is_selected = false
            end
        end
    end
end

-- Toggle the edit-hide flag for the element owning `node_name`. Affects only the
-- editor box; the live-HUD position override is untouched.
function HudElementCustomizer:_toggle_edit_hidden_by_node(node_name)
    local element_name = split_node_name(node_name)
    if not element_name or element_name == "" then
        return
    end
    if _excluded_element_names[element_name] then
        return
    end

    if _user_edit_hidden[element_name] then
        _user_edit_hidden[element_name] = nil
    else
        _user_edit_hidden[element_name] = true
    end
    _save_user_edit_hidden()

    -- Drop the element from the active selection when it becomes hidden so the
    -- detail panel does not keep editing an invisible box.
    if (not self._reveal_edit_hidden) and _is_element_edit_hidden(element_name) then
        local selected = self._selected_node_list
        if selected then
            for i = #selected, 1, -1 do
                if split_node_name(selected[i]) == element_name then
                    table.remove(selected, i)
                end
            end
        end
        self._panel_active_field = nil
    end

    self:_apply_ignore_visibility()
    self:_sort_panel_normal_list()
end

-- Header toggle: temporarily force all edit-hidden boxes back on (or off) so a
-- hidden element can be grabbed in the viewport without clearing its flag.
function HudElementCustomizer:_toggle_reveal_edit_hidden()
    self._reveal_edit_hidden = not self._reveal_edit_hidden
    self:_apply_ignore_visibility()
end

function HudElementCustomizer:_apply_ignore_change(element_name)
    -- Drop the element from the current selection if present.
    local selected = self._selected_node_list
    if selected then
        for i = #selected, 1, -1 do
            if split_node_name(selected[i]) == element_name then
                table.remove(selected, i)
            end
        end
    end

    -- Newly ignored elements must not stay stuck hidden from a prior right-click.
    if _is_element_ignored(element_name) then
        local element = self:_get_element(element_name)
        if element then
            element._is_hidden = false
        end
    end

    -- Re-derive position overrides (drops ignored, re-applies restored), refresh
    -- the displayed lists, and update editor-box visibility.
    self:_apply_saved_node_settings()
    self:_rebuild_panel_lists()
    self:_apply_ignore_visibility()
    self._panel_active_field = nil
    self._panel_hovered_index = nil
    self._ignore_hovered_index = nil
    local max_scroll = math.max(0, #self._panel_normal_list - _cached_panel_list_rows)
    self._panel_scroll_offset = math.clamp(self._panel_scroll_offset, 0, max_scroll)
end

function HudElementCustomizer:_ignore_element_by_node(node_name)
    local element_name = split_node_name(node_name)
    if not element_name or element_name == "" then
        return
    end
    -- System ignores are not user-editable, and skip no-ops.
    if _excluded_element_names[element_name] or _user_ignored[element_name] then
        return
    end
    _user_ignored[element_name] = true
    _save_user_ignored()
    self:_apply_ignore_change(element_name)
end

function HudElementCustomizer:_restore_element(element_name)
    if not element_name or not _user_ignored[element_name] then
        return
    end
    _user_ignored[element_name] = nil
    _save_user_ignored()
    self:_apply_ignore_change(element_name)
end

-- ============================================================================
-- Node management
-- ============================================================================

function HudElementCustomizer:reset_node(node_name)
    local node_settings = self._saved_node_settings[node_name]
    if not node_settings then
        return
    end

    local default_node_settings = node_settings.default_settings or self._default_node_settings[node_name]
    if not default_node_settings then
        mod:warning("No default settings for node [%s]!", node_name)
        return
    end

    local default_position = default_node_settings.position or { 0, 0, 0 }
    local default_size = default_node_settings.size or { 0, 0 }

    -- Restore the node live without discarding custom default settings.
    -- Clearing the saved entry entirely causes the next rebuild to fall back
    -- to the authored scenegraph defaults, which can differ from the user's
    -- curated reset target for composite/background nodes.
    node_settings.x = default_position[1] or 0
    node_settings.y = default_position[2] or 0
    node_settings.z = default_position[3] or 0
    node_settings.size = { default_size[1] or 0, default_size[2] or 0 }
    node_settings.scale = 1
    node_settings.is_hidden = nil
    node_settings.position = { node_settings.x, node_settings.y, node_settings.z }
    node_settings.vertical_alignment = nil
    node_settings.horizontal_alignment = nil

    self._default_node_settings[node_name] = default_node_settings
    self:_apply_node_settings_live(node_name, node_settings)
    self:_sort_panel_normal_list()
end

function HudElementCustomizer:_init_node_settings(node_name)
    local scenegraph_position = self:scenegraph_position(node_name)
    local scenegraph_size = self:scenegraph_size(node_name)
    local existing_defaults = self._default_node_settings[node_name] or {}

    -- First-time initialization should snapshot the currently resolved live box,
    -- not the authored scenegraph definition. Many HUD nodes are moved or resized
    -- by the game/mods before the customizer sees them, so using the live values
    -- makes reset/default behavior match what the user actually starts with.
    local default_settings = {
        position = {
            scenegraph_position[1] or 0,
            scenegraph_position[2] or 0,
            scenegraph_position[3] or 0,
        },
        size = {
            scenegraph_size[1] or 0,
            scenegraph_size[2] or 0,
        },
        vertical_alignment = existing_defaults.vertical_alignment,
        horizontal_alignment = existing_defaults.horizontal_alignment,
    }

    self._default_node_settings[node_name] = default_settings

    local node_settings = {
        x = scenegraph_position[1],
        y = scenegraph_position[2],
        z = scenegraph_position[3],
        size = { scenegraph_size[1], scenegraph_size[2] },
        default_settings = default_settings
    }
    self._saved_node_settings[node_name] = node_settings
    self:_persist_saved_settings()
    return node_settings
end


-- Normalizes the in-memory table and marks it dirty. The actual mod:set is
-- deferred to _flush_saved_settings: DMF deep-clones table settings on every
-- set, and this runs per drag/resize frame, so persisting here caused an
-- allocation storm while dragging. Normalization mutates tables in place for
-- the same reason.
function HudElementCustomizer:_persist_saved_settings()
    local saved = self._saved_node_settings or {}

    for _, node_settings in pairs(saved) do
        if node_settings then
            if node_settings.position then
                node_settings.x = (node_settings.x ~= nil and node_settings.x) or node_settings.position[1] or 0
                node_settings.y = (node_settings.y ~= nil and node_settings.y) or node_settings.position[2] or 0
                node_settings.z = (node_settings.z ~= nil and node_settings.z) or node_settings.position[3] or 0
            else
                node_settings.x = node_settings.x or 0
                node_settings.y = node_settings.y or 0
                node_settings.z = node_settings.z or 0
            end

            local position = node_settings.position
            if position then
                position[1], position[2], position[3] = node_settings.x, node_settings.y, node_settings.z
            else
                node_settings.position = { node_settings.x, node_settings.y, node_settings.z }
            end
            node_settings.vertical_alignment = nil
            node_settings.horizontal_alignment = nil

            local size = node_settings.size
            if size then
                size[1] = size[1] or 0
                size[2] = size[2] or 0
            end
        end
    end

    self._settings_dirty = true
    self._apply_needed = true
end

function HudElementCustomizer:_flush_saved_settings()
    if self._settings_dirty then
        self._settings_dirty = false
        mod:set("saved_node_settings", self._saved_node_settings or {})
    end
end

function HudElementCustomizer:_get_selected_node_settings(node_name)
    local settings = self._saved_node_settings[node_name]
    if not settings then
        settings = self:_init_node_settings(node_name)
    end
    return settings
end

function HudElementCustomizer:_apply_node_settings_live(node_name, node_settings)
    node_settings.x = node_settings.x or 0
    node_settings.y = node_settings.y or 0
    node_settings.z = node_settings.z or 0
    node_settings.position = { node_settings.x, node_settings.y, node_settings.z }

    if node_settings.size then
        node_settings.size = {
            node_settings.size[1] or 0,
            node_settings.size[2] or 0,
        }
    end

    local widget = self._widgets_by_name[node_name]
    if widget then
        widget.content.size = node_settings.size
        widget.content.scale = node_settings.scale or 1
        widget.content.node_x = node_settings.x
        widget.content.node_y = node_settings.y
        widget.content.node_z = node_settings.z or 0
    end

    if node_settings.size then
        self:_set_scenegraph_size(node_name, node_settings.size[1], node_settings.size[2])
    end
    self:set_scenegraph_position(node_name, node_settings.x, node_settings.y, node_settings.z)
    self:_persist_saved_settings()
end

function HudElementCustomizer:_get_field_numeric_value(node_name, group_name, field_key)
    local node_settings = self:_get_selected_node_settings(node_name)
    local defaults = node_settings.default_settings or self._default_node_settings[node_name] or {}
    local default_pos = defaults.position or {0,0,0}
    local default_size = defaults.size or {0,0}

    if group_name == "current" then
        if field_key == "x" then return node_settings.x or 0 end
        if field_key == "y" then return node_settings.y or 0 end
        if field_key == "z" then return node_settings.z or 0 end
        if field_key == "w" then return (node_settings.size and node_settings.size[1]) or 0 end
        if field_key == "h" then return (node_settings.size and node_settings.size[2]) or 0 end
    else
        if field_key == "x" then return default_pos[1] or 0 end
        if field_key == "y" then return default_pos[2] or 0 end
        if field_key == "z" then return default_pos[3] or 0 end
        if field_key == "w" then return default_size[1] or 0 end
        if field_key == "h" then return default_size[2] or 0 end
    end

    return 0
end

function HudElementCustomizer:_set_field_numeric_value(node_name, group_name, field_key, value)
    local node_settings = self:_get_selected_node_settings(node_name)
    node_settings.default_settings = node_settings.default_settings or _copy_table(self._default_node_settings[node_name]) or {}
    local defaults = node_settings.default_settings
    defaults.position = defaults.position or {0,0,0}
    defaults.size = defaults.size or {0,0}

    if group_name == "current" then
        if field_key == "x" then node_settings.x = value end
        if field_key == "y" then node_settings.y = value end
        if field_key == "z" then node_settings.z = value end
        if field_key == "w" then
            node_settings.size = node_settings.size or {0,0}
            node_settings.size[1] = math.max(1, math.floor(value + 0.5))
        end
        if field_key == "h" then
            node_settings.size = node_settings.size or {0,0}
            node_settings.size[2] = math.max(1, math.floor(value + 0.5))
        end
        self:_apply_node_settings_live(node_name, node_settings)
    else
        if field_key == "x" then defaults.position[1] = value end
        if field_key == "y" then defaults.position[2] = value end
        if field_key == "z" then defaults.position[3] = value end
        if field_key == "w" then defaults.size[1] = math.max(1, math.floor(value + 0.5)) end
        if field_key == "h" then defaults.size[2] = math.max(1, math.floor(value + 0.5)) end
        self._default_node_settings[node_name] = defaults
        self:_persist_saved_settings()
    end
end

function HudElementCustomizer:_activate_panel_field(node_name, group_name, field_key)
    self._panel_active_field = {
        node_name = node_name,
        group = group_name,
        key = field_key,
        buffer = _format_field_value(self:_get_field_numeric_value(node_name, group_name, field_key)),
        replace_on_first_input = true
    }
    self._panel_key_repeat = {}
end

function HudElementCustomizer:_commit_panel_field()
    local active = self._panel_active_field
    if not active then
        return
    end

    local value = tonumber(active.buffer)
    if value ~= nil then
        self:_set_field_numeric_value(active.node_name, active.group, active.key, value)
    end

    self._panel_active_field = nil
    self._panel_key_repeat = {}
end

function HudElementCustomizer:_apply_panel_active_buffer()
    local active = self._panel_active_field
    if not active then
        return false
    end

    local value = tonumber(active.buffer)
    if value == nil then
        return false
    end

    self:_set_field_numeric_value(active.node_name, active.group, active.key, value)
    return true
end

function HudElementCustomizer:_cancel_panel_field()
    self._panel_active_field = nil
    self._panel_key_repeat = {}
end

function HudElementCustomizer:_panel_take_key(key_name)
    local kb = _get_keyboard()
    if not kb then
        return false
    end

    local idx = _get_button_index(kb, key_name)
    if not idx then
        return false
    end

    local down = kb.button(idx) > 0.5
    local was_down = self._panel_key_repeat[key_name]
    self._panel_key_repeat[key_name] = down

    return down and not was_down
end

function HudElementCustomizer:_panel_take_any_pressed_name(matchers, repeat_key)
    local kb = _get_keyboard()
    if not kb or not kb.any_pressed or not kb.button_name then
        return false
    end

    local ok, pressed_id = pcall(kb.any_pressed)
    if not ok or not pressed_id then
        return false
    end

    local ok_name, pressed_name = pcall(kb.button_name, pressed_id)
    if not ok_name or not pressed_name then
        return false
    end

    local normalized = string.lower(tostring(pressed_name))
    local matched = false

    for _, matcher in ipairs(matchers) do
        local needle = string.lower(tostring(matcher))
        if normalized == needle or normalized:find(needle, 1, true) then
            matched = true
            break
        end
    end

    if not matched then
        return false
    end

    repeat_key = repeat_key or ("any_pressed:" .. normalized)

    if self._panel_key_repeat[repeat_key] then
        return false
    end

    self._panel_key_repeat[repeat_key] = true
    return true
end

-- Hoisted: field row definitions and active-edit highlight color
local _field_rows = {
    { key = "x", label = "X" },
    { key = "y", label = "Y" },
    { key = "z", label = "Z" },
    { key = "w", label = "W" },
    { key = "h", label = "H" },
}
local _active_field_bg_color = { 120, 85, 110, 140 }
local _current_map_pool = { x = 0, y = 0, z = 0, w = 0, h = 0 }
local _default_map_pool = { x = 0, y = 0, z = 0, w = 0, h = 0 }
local _digit_keys = {
    {"0", "0"}, {"1", "1"}, {"2", "2"}, {"3", "3"}, {"4", "4"},
    {"5", "5"}, {"6", "6"}, {"7", "7"}, {"8", "8"}, {"9", "9"},
    {"numpad 0", "0"}, {"numpad 1", "1"}, {"numpad 2", "2"}, {"numpad 3", "3"}, {"numpad 4", "4"},
    {"numpad 5", "5"}, {"numpad 6", "6"}, {"numpad 7", "7"}, {"numpad 8", "8"}, {"numpad 9", "9"}
}

local _minus_matchers = {"-", "minus", "subtract", "hyphen", "dash", "numpad -", "num -", "kp_subtract"}
local _period_matchers = {".", "period", "decimal", "dot", "numpad .", "num .", "kp_decimal"}

local function _prepare_buffer(active)
    if active.replace_on_first_input then
        active.replace_on_first_input = false
        return ""
    end
    return active.buffer or ""
end

local function _append_char(active, char)
    local buffer = _prepare_buffer(active)
    if char == "." then
        if not string.find(buffer, ".", 1, true) then
            active.buffer = (buffer == "" or buffer == "-") and (buffer .. "0.") or (buffer .. ".")
            return true
        end
        return false
    end
    if char == "-" then
        if buffer == "" then
            active.buffer = "-"
            return true
        end
        return false
    end
    active.buffer = buffer .. char
    return true
end

function HudElementCustomizer:_handle_panel_text_input()
    local active = self._panel_active_field
    if not active then
        return false
    end

    local changed = false

    for i = 1, #_digit_keys do
        local entry = _digit_keys[i]
        if self:_panel_take_key(entry[1]) then
            if _append_char(active, entry[2]) then
                changed = true
            end
        end
    end

    if self:_panel_take_key("backspace") then
        local buffer = active.buffer or ""
        if active.replace_on_first_input then
            active.buffer = ""
            active.replace_on_first_input = false
        else
            active.buffer = buffer:sub(1, math.max(0, #buffer - 1))
        end
        changed = true
    end

    if self:_panel_take_key("delete") then
        active.buffer = ""
        active.replace_on_first_input = false
        changed = true
    end

    local minus_pressed = self:_panel_take_key("minus") or self:_panel_take_key("numpad -")
    if not minus_pressed then
        minus_pressed = self:_panel_take_any_pressed_name(_minus_matchers, "minus_fallback")
    end
    if minus_pressed then
        if _append_char(active, "-") then changed = true end
    end

    local period_pressed = self:_panel_take_key("period") or self:_panel_take_key("decimal") or self:_panel_take_key("numpad .")
    if not period_pressed then
        period_pressed = self:_panel_take_any_pressed_name(_period_matchers, "period_fallback")
    end
    if period_pressed then
        if _append_char(active, ".") then changed = true end
    end

    if self:_panel_take_key("escape") then
        self:_cancel_panel_field()
        return true
    end

    if changed then
        self:_apply_panel_active_buffer()
    end

    return true
end

-- ============================================================================
-- Widget press handling
-- ============================================================================

function HudElementCustomizer:_on_widget_pressed(node_name)
    table.insert(self._widget_press_stack, { node_name = node_name, press_type = "left" })
end

function HudElementCustomizer:_on_widget_right_pressed(node_name)
    table.insert(self._widget_press_stack, { node_name = node_name, press_type = "right" })
end

function HudElementCustomizer:_on_widget_double_clicked(node_name)
    self:reset_node(node_name)
end

function HudElementCustomizer:_process_widget_press_left(node_name)
    self._cursor_start_position = nil
    self._cursor_end_position = nil

    local widgets_by_name = self._widgets_by_name
    local selected_node_list = self._selected_node_list
    local num_selected_nodes = #selected_node_list
    local node_name_index = table.index_of(selected_node_list, node_name)
    local ctrl_held = is_ctrl_held()
    local shift_held = is_shift_held()
    local alt_held = is_alt_held()

    if node_name_index > 0 then
        if shift_held then
            self._start_dragging = true
            self._cursor_start_position = nil
            self._cursor_end_position = nil
            return
        elseif alt_held and num_selected_nodes == 1 then
            -- Preserve the current single selection so Alt+hold can start resize mode.
            return
        elseif ctrl_held or num_selected_nodes == 1 then
            table.remove(selected_node_list, node_name_index)
            widgets_by_name[node_name].content.hotspot.is_selected = false
            self:_persist_saved_settings()
            return
        end
    end

    if shift_held then
        return
    end

    if not ctrl_held then
        for _, selected_node_name in ipairs(selected_node_list) do
            widgets_by_name[selected_node_name].content.hotspot.is_selected = false
        end
        table.clear(selected_node_list)
    end

    table.insert(selected_node_list, node_name)
    widgets_by_name[node_name].content.hotspot.is_selected = true
end

function HudElementCustomizer:_process_widget_press_right(node_name)
    local element_name, scenegraph_id = split_node_name(node_name)
    local element = self:_get_element(element_name)
    if not element then
        return
    end

    local node_widget = self._widgets_by_name[node_name]
    if not node_widget then
        return
    end

    local should_hide = not node_widget.content.is_hidden
    node_widget.content.is_hidden = should_hide

    local is_tactical_overlay_node = element_name == "HudElementTacticalOverlay" and scenegraph_id ~= nil and scenegraph_id ~= ""
    if not is_tactical_overlay_node then
        if element.set_visible then
            element:set_visible(not should_hide)
        end
        element._is_hidden = should_hide
        -- _is_hidden only takes effect through the customizer draw hook; install it
        -- now so the hide is immediate (base-class draw hooks may not exist).
        -- Unhiding needs no hook: an existing one passes through, and without
        -- one the element just draws normally.
        if should_hide then
            _ensure_element_draw_hook(element)
        end
    end

    local saved_node_settings = self._saved_node_settings
    local node_settings = saved_node_settings[node_name]
    if not node_settings then
        node_settings = self:_init_node_settings(node_name)
    end
    node_settings.is_hidden = should_hide
    self:_persist_saved_settings()
    self:_sort_panel_normal_list()
end

function HudElementCustomizer:_handle_widget_presses()
    local widget_press_stack = self._widget_press_stack
    local stack_size = #widget_press_stack
    if stack_size == 0 then
        return
    end

    local press_data
    if stack_size == 1 then
        press_data = widget_press_stack[1]
    else
        -- Multiple overlapping widgets pressed: pick highest z
        local highest_z = -math.huge
        local best_index
        for i, pd in ipairs(widget_press_stack) do
            local pos = self:scenegraph_position(pd.node_name)
            if pos and pos[3] > highest_z then
                highest_z = pos[3]
                best_index = i
            end
        end
        press_data = best_index and widget_press_stack[best_index]
    end

    if press_data then
        local func_name = press_data.press_type == "left" and "_process_widget_press_left" or "_process_widget_press_right"
        self[func_name](self, press_data.node_name)
    end

    table.clear(self._widget_press_stack)
end

-- ============================================================================
-- Cursor management - FIXED: tracks own push state to prevent imbalanced pop
-- ============================================================================

function HudElementCustomizer:using_input()
    return self._using_cursor
end

function HudElementCustomizer:_activate_mouse_cursor()
    if not self._cursor_pushed then
        local input_manager = Managers.input
        input_manager:push_cursor(self.__class_name)
        self._cursor_pushed = true
    end
    self._using_cursor = true
end

function HudElementCustomizer:_deactivate_mouse_cursor()
    if self._cursor_pushed then
        local input_manager = Managers.input
        input_manager:pop_cursor(self.__class_name)
        self._cursor_pushed = false
    end
    self._using_cursor = false
end

function HudElementCustomizer:_get_inverse_hud_scale()
    local default_value = 100
    local save_data = Managers.save:account_data()
    local interface_settings = save_data.interface_settings
    local hud_scale = (interface_settings.hud_scale or default_value) / 100
    return 1 / hud_scale
end

-- ============================================================================
-- Visibility
-- ============================================================================

function HudElementCustomizer:set_visible(status)
    if status == false then
        if self._using_cursor then
            self:_deactivate_mouse_cursor()
        end

        -- set_visible(false) fires on EVERY visibility-group change (comm wheel,
        -- tactical overlay, death/spectate), not just when leaving edit mode.
        -- The full apply pass (pcalls per node + whole-table persist) only needs
        -- to run when the layout actually changed since the last apply.
        if self._apply_needed or self._settings_dirty then
            self:_apply_saved_node_settings()
        end
    end
end

function HudElementCustomizer:destroy()
    if self._using_cursor then
        self:_deactivate_mouse_cursor()
    end
    -- pcall: destroy runs inside UIHud.destroy's element loop, and UIHud.destroy
    -- nils _elements partway through its own teardown while UIManager clears its
    -- _hud reference only after destroy returns. Anything thrown from here would
    -- strand a gutted HUD. Losing one settings flush is preferable to that (and
    -- update() already flushes on mouse-release, so nothing is normally pending).
    pcall(self._flush_saved_settings, self)
end

function HudElementCustomizer:_update_group_visibility()
    if not self._group_changed then
        return
    end
    self._group_changed = nil

    local current_group = self._elements_by_group[self._selected_group_index]
    if not current_group then
        return
    end

    local current_group_name = current_group.name
    for group_name, element_scenegraphs in pairs(self._scenegraphs) do
        for element_name, children in pairs(element_scenegraphs) do
            local visible = (current_group_name == group_name) or current_group.elements[element_name] or false
            for _, child in ipairs(children) do
                self:set_scenegraph_widgets_visible(child.name, visible)
            end
        end
    end
end

-- ============================================================================
-- Resize detection
-- ============================================================================

function HudElementCustomizer:_detect_resize_edge(node_name, cursor_pos)
    local sg_pos = self:scenegraph_world_position(node_name)
    local sg_size = self:scenegraph_size(node_name)
    if not sg_pos or not sg_size then
        return nil
    end

    local scale = 1 / (self._inverse_scale or RESOLUTION_LOOKUP.inverse_scale)
    local x = sg_pos[1] * scale
    local y = sg_pos[2] * scale
    local w = sg_size[1] * scale
    local h = sg_size[2] * scale
    local cx, cy = cursor_pos[1], cursor_pos[2]
    local t = RESIZE_EDGE_THRESHOLD

    local near_left = cx >= x and cx <= x + t
    local near_right = cx >= x + w - t and cx <= x + w
    local near_top = cy >= y and cy <= y + t
    local near_bottom = cy >= y + h - t and cy <= y + h
    local in_x = cx >= x and cx <= x + w
    local in_y = cy >= y and cy <= y + h

    if near_top and near_left then return "tl"
    elseif near_top and near_right then return "tr"
    elseif near_bottom and near_left then return "bl"
    elseif near_bottom and near_right then return "br"
    elseif near_top and in_x then return "t"
    elseif near_bottom and in_x then return "b"
    elseif near_left and in_y then return "l"
    elseif near_right and in_y then return "r"
    end

    return nil
end


-- Returns the best snap position for one axis, or nil if no snap within threshold.
local function _best_snap_axis(dest_pos, size_axis, other_pos, other_size_axis, threshold)
    local best_diff = threshold + 1
    local best_snap = nil

    local current_mid = dest_pos + size_axis * 0.5
    local current_max = dest_pos + size_axis
    local other_mid = other_pos + other_size_axis * 0.5
    local other_max = other_pos + other_size_axis

    -- min-min
    local d = math.abs(dest_pos - other_pos)
    if d < best_diff then best_diff = d; best_snap = other_pos end
    -- mid-mid
    d = math.abs(current_mid - other_mid)
    if d < best_diff then best_diff = d; best_snap = other_mid - size_axis * 0.5 end
    -- max-max
    d = math.abs(current_max - other_max)
    if d < best_diff then best_diff = d; best_snap = other_max - size_axis end
    -- min-max
    d = math.abs(dest_pos - other_max)
    if d < best_diff then best_diff = d; best_snap = other_max end
    -- max-min
    d = math.abs(current_max - other_pos)
    if d < best_diff then best_diff = d; best_snap = other_pos - size_axis end

    return best_snap, best_diff
end

function HudElementCustomizer:_apply_element_snapping(node_name, dest_x, dest_y, size)
    local snap_threshold = 10
    local best_x_diff = snap_threshold + 1
    local best_y_diff = snap_threshold + 1
    local snapped_x = dest_x
    local snapped_y = dest_y
    local all_node_names = self._panel_all_node_names or {}

    for i = 1, #all_node_names do
        local other_node_name = all_node_names[i]
        local other_node_settings = self._saved_node_settings and self._saved_node_settings[other_node_name]

        if other_node_name ~= node_name and not (other_node_settings and other_node_settings.is_hidden) then
            local other_pos = self:scenegraph_position(other_node_name)
            local other_size = self:scenegraph_size(other_node_name)

            if other_pos and other_size then
                local snap_x, diff_x = _best_snap_axis(dest_x, size[1], other_pos[1], other_size[1], snap_threshold)
                if snap_x and diff_x < best_x_diff then
                    best_x_diff = diff_x
                    snapped_x = snap_x
                end

                local snap_y, diff_y = _best_snap_axis(dest_y, size[2], other_pos[2], other_size[2], snap_threshold)
                if snap_y and diff_y < best_y_diff then
                    best_y_diff = diff_y
                    snapped_y = snap_y
                end
            end
        end
    end

    return snapped_x, snapped_y
end

-- ============================================================================
-- Input handling
-- ============================================================================

function HudElementCustomizer:_handle_input(input_service)
    local saved_node_settings = self._saved_node_settings
    local selected_node_list = self._selected_node_list
    local num_selected_nodes = #selected_node_list

    if num_selected_nodes == 0 then
        self._resize_mode = false
        return
    end

    local inverse_scale = self._inverse_scale or RESOLUTION_LOOKUP.inverse_scale

    -- Handle resize mode
    if self._resize_mode then
        self:_handle_resize_input(input_service, inverse_scale)
        return
    end

    -- Check for resize initiation on single selected node
    if num_selected_nodes == 1 and input_service:get("left_hold") and is_alt_held() then
        local node_name = selected_node_list[1]
        local cursor = input_service:get("cursor")
        if cursor then
            local cursor_arr = Vector3.to_array(cursor)
            local edge = self:_detect_resize_edge(node_name, cursor_arr)
            if edge then
                local node_settings = saved_node_settings[node_name] or self:_init_node_settings(node_name)
                self._resize_mode = true
                self._resize_edge = edge
                self._resize_node_name = node_name
                self._resize_start_cursor = cursor_arr
                self._resize_start_size = { node_settings.size[1], node_settings.size[2] }
                self._resize_start_pos = { node_settings.x, node_settings.y }
                return
            end
        end
    end

    -- Normal drag with shift+hold
    if input_service:get("left_hold") and is_shift_held() then
        if not self._cursor_start_position then
            self._cursor_start_position = Vector3.to_array(input_service:get("cursor"))
        end
        self._cursor_end_position = Vector3.to_array(input_service:get("cursor"))
    else
        self._start_dragging = false
    end

    -- Edge-triggered nav direction (one tick per tap), shared by stepped arrow
    -- move, resize, and z-order. Edges are detected from the navigation axis so
    -- holding does not auto-repeat.
    local step_nav_x, step_nav_y = 0, 0
    do
        local axis = input_service:get("navigation_keys_virtual_axis")
        local nx = (axis and axis[1]) or 0
        local ny = (axis and axis[2]) or 0
        nx = (nx > 0 and 1) or (nx < 0 and -1) or 0
        ny = (ny > 0 and 1) or (ny < 0 and -1) or 0
        local prev = self._arrow_axis_prev
        local pnx = (prev and prev[1]) or 0
        local pny = (prev and prev[2]) or 0
        if nx ~= 0 and nx ~= pnx then step_nav_x = nx end
        if ny ~= 0 and ny ~= pny then step_nav_y = ny end
        if not prev then
            prev = {}
            self._arrow_axis_prev = prev
        end
        prev[1] = nx
        prev[2] = ny
    end

    -- Fixed-step arrow movement reuses the shared edge so a tap moves a fixed
    -- pixel step (shared across all selected nodes).
    local fixed_move_dx, fixed_move_dy = 0, 0
    if _cached_fixed_arrow_move then
        fixed_move_dx = step_nav_x * _cached_arrow_move_step
        fixed_move_dy = step_nav_y * _cached_arrow_move_step
    end

    local should_clear_cursor_positions = false

    for i, node_name in ipairs(selected_node_list) do
        local node_settings = saved_node_settings[node_name]
        if not node_settings then
            node_settings = self:_init_node_settings(node_name)
        end

        local size = self:scenegraph_size(node_name)
        local scale = node_settings.scale or 1

        -- Scroll wheel: scale
        local scroll_axis = input_service:get("scroll_axis")
        if scroll_axis and scroll_axis[2] ~= 0 then
            local original_size = { size[1] / scale, size[2] / scale }
            local scroll_diff = (scroll_axis[2] > 0 and 0.05) or (scroll_axis[2] < 0 and -0.05) or 0

            scale = math.max(scale + scroll_diff, 0.05)
            node_settings.scale = scale

            local new_size = { original_size[1] * scale, original_size[2] * scale }
            node_settings.size = new_size

            local widget = self._widgets_by_name[node_name]
            if widget then
                widget.content.size = new_size
                widget.content.scale = scale
            end
            self:_set_scenegraph_size(node_name, new_size[1], new_size[2])
        end

        -- Update widget content for position display
        local widget = self._widgets_by_name[node_name]
        if widget then
            widget.content.node_x = node_settings.x
            widget.content.node_y = node_settings.y
            widget.content.node_z = node_settings.z or 0
        end

        -- Cursor-based dragging
        local cursor_end_position = self._cursor_end_position
        if cursor_end_position then
            local cursor_start_position = self._cursor_start_position
            local cursor_diff_x = (cursor_end_position[1] - cursor_start_position[1]) * inverse_scale
            local cursor_diff_y = (cursor_end_position[2] - cursor_start_position[2]) * inverse_scale
            local dest_x = cursor_diff_x + node_settings.x
            local dest_y = cursor_diff_y + node_settings.y

            -- Snapping
            local ctrl_held = is_ctrl_held()
            local should_snap_to_grid = (num_selected_nodes == 1) and self._display_grid
                and ((ctrl_held and not self._snap_to_grid) or (not ctrl_held and self._snap_to_grid))
            local should_snap_to_elements = (num_selected_nodes == 1)
                and ((ctrl_held and not self._snap_to_elements) or (not ctrl_held and self._snap_to_elements))

            if should_snap_to_grid and self._grid_line_positions then
                local alt_held = is_alt_held()
                local grid_y = self._grid_line_positions[1]
                local grid_x = self._grid_line_positions[2]

                if grid_y then
                    for _, line_y in ipairs(grid_y) do
                        local diff_y = cursor_end_position[2] - line_y
                        if alt_held then
                            if math.abs(diff_y) < 5 then
                                dest_y = (line_y * inverse_scale) - (size[2] / 2)
                            end
                        elseif diff_y < -3 and diff_y > -10 then
                            dest_y = (line_y * inverse_scale) - size[2]
                        elseif diff_y > 3 and diff_y < 10 then
                            dest_y = line_y * inverse_scale
                        end
                    end
                end

                if grid_x then
                    for _, line_x in ipairs(grid_x) do
                        local diff_x = (cursor_end_position[1] - line_x) * inverse_scale
                        if alt_held then
                            if math.abs(diff_x) < 5 then
                                dest_x = (line_x * inverse_scale) - (size[1] / 2)
                            end
                        elseif diff_x < -3 and diff_x > -10 then
                            dest_x = (line_x * inverse_scale) - size[1]
                        elseif diff_x > 3 and diff_x < 10 then
                            dest_x = line_x * inverse_scale
                        end
                    end
                end
            end

            if should_snap_to_elements then
                dest_x, dest_y = self:_apply_element_snapping(node_name, dest_x, dest_y, size)
            end

            if self._start_dragging then
                self:set_scenegraph_position(node_name, dest_x, dest_y)
            else
                node_settings.x = dest_x
                node_settings.y = dest_y
                self:set_scenegraph_position(node_name, dest_x, dest_y)
                should_clear_cursor_positions = true
            end
        else
            -- Tab = reset node
            if input_service:get("cycle_chat_channel") then
                self:reset_node(node_name)
            end

            -- Ctrl+Shift+C = center on screen
            if is_ctrl_held() and is_shift_held() then
                local kb = _get_keyboard()
                if kb then
                    local ok, c_idx = pcall(kb.button_index, "c")
                    if ok and c_idx and kb.button(c_idx) > 0.5 and not self._center_key_was_down then
                        local inverse_scale = self._inverse_scale or RESOLUTION_LOOKUP.inverse_scale
                        local screen_w = RESOLUTION_LOOKUP.width * inverse_scale
                        local screen_h = RESOLUTION_LOOKUP.height * inverse_scale
                        local elem_w = size[1]
                        local elem_h = size[2]
                        node_settings.x = (screen_w - elem_w) / 2
                        node_settings.y = (screen_h - elem_h) / 2
                        self:set_scenegraph_position(node_name, node_settings.x, node_settings.y, node_settings.z)
                        self._center_key_was_down = true
                    elseif not (ok and c_idx and kb.button(c_idx) > 0.5) then
                        self._center_key_was_down = false
                    end
                end
            else
                self._center_key_was_down = false
            end

            local input = input_service:get("navigation_keys_virtual_axis")
            if input then
                local alt_held = is_alt_held()

                if alt_held then
                    -- Alt + Arrow keys = resize. Fixed-step mode resizes by the
                    -- configured step per tap; otherwise ±1px while held.
                    local dw, dh
                    if _cached_fixed_arrow_move then
                        dw = step_nav_x * _cached_resize_step
                        dh = -step_nav_y * _cached_resize_step
                    else
                        dw = input[1]
                        dh = -input[2]
                    end
                    if dw ~= 0 or dh ~= 0 then
                        local current_size = node_settings.size or { size[1], size[2] }
                        local new_w = math.max(current_size[1] + dw, 5)
                        local new_h = math.max(current_size[2] + dh, 5)
                        node_settings.size = { new_w, new_h }

                        local base_scale = node_settings.scale or 1
                        local widget_ref = self._widgets_by_name[node_name]
                        if widget_ref then
                            widget_ref.content.size = { new_w, new_h }
                        end
                        self:_set_scenegraph_size(node_name, new_w, new_h)
                    end
                elseif is_shift_held() then
                    -- Shift + Up/Down = z-order. Fixed-step mode changes depth by
                    -- the configured step per tap; otherwise ±1 while held.
                    local dz = _cached_fixed_arrow_move and (step_nav_y * _cached_z_step) or input[2]
                    if dz ~= 0 then
                        node_settings.z = (node_settings.z or self:scenegraph_position(node_name)[3]) + dz
                    end
                elseif _cached_fixed_arrow_move then
                    -- Arrow keys = move a fixed pixel step per tap
                    node_settings.x = node_settings.x + fixed_move_dx
                    node_settings.y = node_settings.y - fixed_move_dy
                else
                    -- Arrow keys = move ±1px while held
                    node_settings.x = node_settings.x + input[1]
                    node_settings.y = node_settings.y - input[2]
                end

                self:set_scenegraph_position(node_name, node_settings.x, node_settings.y, node_settings.z)
            end
        end
    end

    if should_clear_cursor_positions then
        self._cursor_start_position = nil
        self._cursor_end_position = nil
    end

    self:_persist_saved_settings()
end

function HudElementCustomizer:_handle_resize_input(input_service, inverse_scale)
    if not input_service:get("left_hold") then
        -- Released - commit resize
        self._resize_mode = false
        return
    end

    local cursor = input_service:get("cursor")
    if not cursor then
        return
    end

    local cursor_arr = Vector3.to_array(cursor)
    local dx = (cursor_arr[1] - self._resize_start_cursor[1]) * inverse_scale
    local dy = (cursor_arr[2] - self._resize_start_cursor[2]) * inverse_scale
    local edge = self._resize_edge
    local node_name = self._resize_node_name
    local start_w = self._resize_start_size[1]
    local start_h = self._resize_start_size[2]
    local start_x = self._resize_start_pos[1]
    local start_y = self._resize_start_pos[2]

    local new_w, new_h = start_w, start_h
    local new_x, new_y = start_x, start_y

    -- Apply resize based on which edge/corner is being dragged
    if edge == "r" or edge == "tr" or edge == "br" then
        new_w = math.max(start_w + dx, 10)
    end
    if edge == "l" or edge == "tl" or edge == "bl" then
        new_w = math.max(start_w - dx, 10)
        new_x = start_x + (start_w - new_w)
    end
    if edge == "b" or edge == "bl" or edge == "br" then
        new_h = math.max(start_h + dy, 10)
    end
    if edge == "t" or edge == "tl" or edge == "tr" then
        new_h = math.max(start_h - dy, 10)
        new_y = start_y + (start_h - new_h)
    end

    local node_settings = self._saved_node_settings[node_name]
    if node_settings then
        node_settings.size = { new_w, new_h }
        node_settings.x = new_x
        node_settings.y = new_y

        local widget = self._widgets_by_name[node_name]
        if widget then
            widget.content.size = { new_w, new_h }
        end
        self:_set_scenegraph_size(node_name, new_w, new_h)
        self:set_scenegraph_position(node_name, new_x, new_y, node_settings.z)
        self:_persist_saved_settings()
    end
end

-- ============================================================================
-- Update / Draw
-- ============================================================================

-- Re-read grid / snap settings each frame so the options-menu checkboxes apply
-- live (they are otherwise only read once at setup). Runs only in edit mode since
-- the element updates only while customizing.
function HudElementCustomizer:_sync_live_settings()
    local dg = mod:get("display_grid")
    self._display_grid = (dg == nil) and true or (dg and true or false)
    local sg = mod:get("snap_to_grid")
    self._snap_to_grid = (sg == nil) and true or (sg and true or false)
    local se = mod:get("snap_to_elements")
    self._snap_to_elements = (se == nil) and true or (se and true or false)
    self._num_cols = math.max(1, math.floor(tonumber(mod:get("grid_cols")) or self._num_cols or 3))
    self._num_rows = math.max(1, math.floor(tonumber(mod:get("grid_rows")) or self._num_rows or 3))
end

function HudElementCustomizer:update(dt, t, ui_renderer, render_settings, input_service)
    if not self._setup_complete then
        self:_setup_elements(render_settings)
        return
    end

    self._inverse_scale = render_settings.inverse_scale

    self:_sync_live_settings()

    local using_cursor = self._using_cursor
    if not using_cursor and mod.is_customizing then
        self:_activate_mouse_cursor()
    elseif using_cursor and not mod.is_customizing then
        self:_deactivate_mouse_cursor()
        return
    end

    self:_update_group_visibility()

    -- Handle panel input before widget presses so clicks on the panel do not leak
    -- through to HUD element hotspots underneath it.
    local panel_consumed = self:_handle_panel_input(input_service, t)

    if panel_consumed then
        table.clear(self._widget_press_stack)
    else
        self:_handle_widget_presses()
        self:_handle_input(input_service)
    end

    HudElementCustomizer.super.update(self, dt, t, ui_renderer, render_settings, input_service)
    self:_sync_panel_hover_preview()

    -- Deferred persistence: push pending layout changes through mod:set only
    -- once the mouse button is up, so drags/resizes cost one deep-clone at
    -- release instead of one per frame.
    if self._settings_dirty and not input_service:get("left_hold") then
        self:_flush_saved_settings()
    end
end

function HudElementCustomizer:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    HudElementCustomizer.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)

    self:_draw_grid(ui_renderer)
    self:_draw_box_outlines(ui_renderer)
    self:_draw_selection_outlines(ui_renderer)
    self:_draw_resize_handles(ui_renderer)
    self:_draw_info_panel(ui_renderer, input_service)
end

-- ============================================================================
-- Grid drawing
-- ============================================================================

function HudElementCustomizer:_draw_grid(ui_renderer)
    if not self._display_grid then
        return
    end

    local width = RESOLUTION_LOOKUP.width
    local height = RESOLUTION_LOOKUP.height
    local inverse_scale = self._inverse_scale or RESOLUTION_LOOKUP.inverse_scale
    local draw_layer = 999

    local num_rows = self._num_rows
    local num_cols = self._num_cols
    local cell_width = width / num_cols
    local cell_height = height / num_rows

    local grid_line_positions = self._grid_line_positions
    if not grid_line_positions then
        grid_line_positions = { {}, {} }
        self._grid_line_positions = grid_line_positions
    end

    local center_row = num_rows / 2 + 1
    for i = 1, num_rows + 1 do
        local x = 1
        local y = (i - 1) * cell_height - 1
        local is_center = (i == center_row or math.ceil(center_row) == i or math.floor(center_row) == i)
        local color = is_center and { 255, 255, 0, 0 } or { 170, 255, 255, 255 }
        local position = Vector3(x * inverse_scale, y * inverse_scale, draw_layer)
        local size = Vector2(width * inverse_scale, 1)

        grid_line_positions[1][i] = position[2] / inverse_scale
        UIRenderer.draw_rect(ui_renderer, position, size, color)
    end

    local center_col = num_cols / 2 + 1
    for i = 1, num_cols + 1 do
        local x = (i - 1) * cell_width - 1
        local is_center = (i == center_col or math.ceil(center_col) == i or math.floor(center_col) == i)
        local color = is_center and { 255, 255, 0, 0 } or { 170, 255, 255, 255 }
        local position = Vector3(x * inverse_scale, 0, draw_layer)
        local size = Vector2(1, height * inverse_scale)

        grid_line_positions[2][i] = position[1] / inverse_scale
        UIRenderer.draw_rect(ui_renderer, position, size, color)
    end
end

-- ============================================================================
-- Resize handles drawing
-- ============================================================================

function HudElementCustomizer:_draw_resize_handles(ui_renderer)
    local selected_node_list = self._selected_node_list
    if #selected_node_list ~= 1 then
        return
    end

    local node_name = selected_node_list[1]
    local sg_pos = self:scenegraph_world_position(node_name)
    local sg_size = self:scenegraph_size(node_name)
    if not sg_pos or not sg_size then
        return
    end

    local draw_layer = 1000
    local hs = RESIZE_HANDLE_SIZE * (self._inverse_scale or 1)
    local x = sg_pos[1]
    local y = sg_pos[2]
    local w = sg_size[1]
    local h = sg_size[2]
    local color = RESIZE_HANDLE_COLOR

    -- Four corners
    local corners = {
        { x, y },                     -- top-left
        { x + w - hs, y },            -- top-right
        { x, y + h - hs },            -- bottom-left
        { x + w - hs, y + h - hs }    -- bottom-right
    }

    local handle_size = Vector2(hs, hs)
    for _, corner in ipairs(corners) do
        UIRenderer.draw_rect(ui_renderer, Vector3(corner[1], corner[2], draw_layer), handle_size, color)
    end
end

-- No-fill mode: outline every visible (non-stashed) box so elements stay
-- locatable once the grey fill is removed. Stashed boxes have widget.visible
-- false and are skipped.
function HudElementCustomizer:_draw_box_outlines(ui_renderer)
    if _cached_box_fill_mode ~= 2 then
        return
    end

    local widgets_by_name = self._widgets_by_name
    if not widgets_by_name then
        return
    end

    local inverse_scale = self._inverse_scale or 1
    local draw_layer = 999
    local thickness = math.max(1, BOX_OUTLINE_THICKNESS * inverse_scale)
    local color = BOX_OUTLINE_COLOR

    for node_name, widget in pairs(widgets_by_name) do
        if widget.visible ~= false then
            local pos = self:scenegraph_world_position(node_name)
            local size = self:scenegraph_size(node_name)
            if pos and size then
                local x, y = pos[1], pos[2]
                local w, h = size[1], size[2]
                UIRenderer.draw_rect(ui_renderer, Vector3(x, y, draw_layer), Vector2(w, thickness), color)
                UIRenderer.draw_rect(ui_renderer, Vector3(x, y + h - thickness, draw_layer), Vector2(w, thickness), color)
                UIRenderer.draw_rect(ui_renderer, Vector3(x, y, draw_layer), Vector2(thickness, h), color)
                UIRenderer.draw_rect(ui_renderer, Vector3(x + w - thickness, y, draw_layer), Vector2(thickness, h), color)
            end
        end
    end
end

-- Border outline for every selected node. Uses scenegraph bounds directly, so it
-- shows even when the node's editor box widget is hidden (stashed / hidden).
function HudElementCustomizer:_draw_selection_outlines(ui_renderer)
    local selected_node_list = self._selected_node_list
    if not selected_node_list or #selected_node_list == 0 then
        return
    end

    local inverse_scale = self._inverse_scale or 1
    local draw_layer = 999
    local thickness = math.max(1, SELECTION_OUTLINE_THICKNESS * inverse_scale)
    local color = SELECTION_OUTLINE_COLOR

    for i = 1, #selected_node_list do
        local node_name = selected_node_list[i]
        local pos = self:scenegraph_world_position(node_name)
        local size = self:scenegraph_size(node_name)
        if pos and size then
            local x, y = pos[1], pos[2]
            local w, h = size[1], size[2]
            UIRenderer.draw_rect(ui_renderer, Vector3(x, y, draw_layer), Vector2(w, thickness), color)
            UIRenderer.draw_rect(ui_renderer, Vector3(x, y + h - thickness, draw_layer), Vector2(w, thickness), color)
            UIRenderer.draw_rect(ui_renderer, Vector3(x, y, draw_layer), Vector2(thickness, h), color)
            UIRenderer.draw_rect(ui_renderer, Vector3(x + w - thickness, y, draw_layer), Vector2(thickness, h), color)
        end
    end
end

-- ============================================================================
-- Info panel
-- ============================================================================

function HudElementCustomizer:_get_panel_position(inverse_scale)
    -- Compute only the two values we need directly, avoiding a _get_panel_metrics
    -- call that would overwrite the shared pool mid-use by callers. Sizes fold in
    -- the resolution factor (matching _get_panel_metrics); the screen-edge term
    -- (width * inverse_scale) stays on the raw inverse_scale.
    local ps_is = _cached_panel_scale * _panel_res_factor() * inverse_scale
    local panel_w = _cached_panel_width * ps_is
    local panel_margin = PANEL_MARGIN * ps_is
    local width = RESOLUTION_LOOKUP.width
    local default_x = (width * inverse_scale) - panel_w - panel_margin
    local default_y = panel_margin

    if not self._panel_position then
        self._panel_position = { default_x, default_y }
    end

    return self._panel_position[1] or default_x, self._panel_position[2] or default_y
end

function HudElementCustomizer:_save_panel_position()
    if self._panel_position then
        mod:set("panel_position", { self._panel_position[1], self._panel_position[2] })
    end
end

-- Side panels open outside the main panel: the legend to the LEFT, the ignore
-- list to the RIGHT. A main panel parked at a screen edge leaves the open side
-- panel off screen (the legend also clamps to x=0 and overlaps instead). So each
-- open side panel reserves its width, and the main panel slides just far enough
-- to clear the reservation. It slides back when the side panel closes.
-- `_side_shift_x` is the signed delta currently applied. The shift is transient:
-- it is never saved to settings, and a drag drops it (the drag clamp uses the
-- same reservations, so a dragged position never needs a shift).
function HudElementCustomizer:_update_side_panel_shift(panel_w, inverse_scale)
    local pos = self._panel_position
    if not pos then
        return
    end

    -- Position the panel would hold with no shift active.
    local base_x = (pos[1] or 0) - (self._side_shift_x or 0)

    local scale = _cached_panel_scale * _panel_res_factor()
    local left_reserve = self._show_legend and _legend_panel_span(scale, inverse_scale) or 0
    local right_reserve = self._show_ignore_panel and _ignore_panel_span(scale, inverse_scale) or 0
    local width_scaled = RESOLUTION_LOOKUP.width * inverse_scale

    -- Too narrow for both: the legend wins the space, the ignore list clips.
    local min_x = left_reserve
    local max_x = math.max(min_x, width_scaled - panel_w - right_reserve)
    local new_x = math.clamp(base_x, min_x, max_x)

    pos[1] = new_x
    self._side_shift_x = new_x - base_x
end

function HudElementCustomizer:_sync_panel_hover_preview()
    local widgets_by_name = self._widgets_by_name
    if not widgets_by_name then
        return
    end

    if not self._panel_mouse_over then
        return
    end

    local preview_node = self._panel_hover_preview_node

    for node_name, widget in pairs(widgets_by_name) do
        local content = widget and widget.content
        local hotspot = content and content.hotspot
        if content then
            content.is_panel_preview_hover = false
            content.suppress_hover_labels = self._panel_mouse_over
        end
        if hotspot then
            hotspot.is_hover = false
            hotspot.anim_hover_progress = 0
        end
    end

    if preview_node then
        local widget = widgets_by_name[preview_node]
        local content = widget and widget.content
        local hotspot = content and content.hotspot
        if content then
            content.is_panel_preview_hover = true
        end
        if hotspot then
            hotspot.is_hover = true
            hotspot.anim_hover_progress = 1
        end
    end
end

function HudElementCustomizer:_handle_panel_input(input_service, t)
    t = t or 0
    self._panel_mouse_over = false
    self._panel_hover_preview_node = nil
    self._ignore_hovered_index = nil
    self._ignore_btn_hover = false
    self._reveal_btn_hover = false
    self._legend_btn_hover = false
    self._edit_toggle_hover_element = nil

    if not self._show_info_panel then
        return false
    end

    local panel_text_consumed = false
    if self._panel_active_field then
        panel_text_consumed = self:_handle_panel_text_input() or false
    end

    local cursor = input_service:get("cursor")
    if not cursor then
        return panel_text_consumed
    end

    local cursor_arr = Vector3.to_array(cursor)
    local inverse_scale = self._inverse_scale or RESOLUTION_LOOKUP.inverse_scale
    local total_nodes = #self._panel_normal_list
    local has_selected = #self._selected_node_list > 0
    local has_active_edit = self._panel_active_field ~= nil
    local metrics = _get_panel_metrics(inverse_scale, has_selected, has_active_edit)
    local px, py = self:_get_panel_position(inverse_scale)
    local panel_w = metrics.width
    local visible_count = math.min(total_nodes, metrics.list_rows)
    local list_height = visible_count * metrics.line_h
    local panel_h = metrics.header_h + list_height + metrics.detail_h
    local hh = metrics.header_h
    local line_h = metrics.line_h

    local cx = cursor_arr[1] * inverse_scale
    local cy = cursor_arr[2] * inverse_scale

    local left_pressed = input_service:get("left_pressed")

    local in_panel = cx >= px and cx <= px + panel_w and cy >= py and cy <= py + panel_h
    local in_header = cx >= px and cx <= px + panel_w and cy >= py and cy <= py + hh

    if self._panel_dragging then
        if input_service:get("left_hold") then
            local ox = self._panel_drag_offset and self._panel_drag_offset[1] or 0
            local oy = self._panel_drag_offset and self._panel_drag_offset[2] or 0
            local width_scaled = RESOLUTION_LOOKUP.width * inverse_scale
            local height_scaled = RESOLUTION_LOOKUP.height * inverse_scale
            -- Reserve the width of each open side panel (legend left, ignore list
            -- right) so a drag cannot push one off screen or under the main panel.
            -- The saved position is then always a real (unshifted) one.
            local left_reserve = self._show_legend
                and _legend_panel_span(metrics.scale, inverse_scale) or 0
            local right_reserve = self._show_ignore_panel
                and _ignore_panel_span(metrics.scale, inverse_scale) or 0
            local max_x = math.max(left_reserve, width_scaled - panel_w - right_reserve)
            local new_x = math.clamp(cx - ox, left_reserve, max_x)
            local new_y = math.clamp(cy - oy, 0, math.max(0, height_scaled - panel_h))
            self._panel_position = { new_x, new_y }
            self._side_shift_x = 0
            return true
        else
            self._panel_dragging = false
            self._panel_drag_offset = nil
            self:_save_panel_position()
        end
    end

    if left_pressed and self._panel_active_field then
        local clicked_field = false
        for _, box in ipairs(self._panel_field_targets or {}) do
            if _point_in_rect(cx, cy, box.x, box.y, box.w, box.h) then
                clicked_field = true
                break
            end
        end
        if not clicked_field then
            self:_commit_panel_field()
        end
    end

    -- Ignore-list toggle button (rect computed + stored during draw).
    local btn_rect = self._ignore_btn_rect
    if btn_rect then
        self._ignore_btn_hover = _point_in_rect(cx, cy, btn_rect[1], btn_rect[2], btn_rect[3], btn_rect[4])
        if left_pressed and self._ignore_btn_hover then
            self._show_ignore_panel = not self._show_ignore_panel
            self._ignore_hovered_index = nil
            self:_update_side_panel_shift(panel_w, inverse_scale)
            return true
        end
    end

    -- Reveal toggle button (rect computed + stored during draw).
    local reveal_rect = self._reveal_btn_rect
    if reveal_rect then
        self._reveal_btn_hover = _point_in_rect(cx, cy, reveal_rect[1], reveal_rect[2], reveal_rect[3], reveal_rect[4])
        if left_pressed and self._reveal_btn_hover then
            self:_toggle_reveal_edit_hidden()
            return true
        end
    end

    -- Legend button (rect computed + stored during draw).
    local legend_rect = self._legend_btn_rect
    if legend_rect then
        self._legend_btn_hover = _point_in_rect(cx, cy, legend_rect[1], legend_rect[2], legend_rect[3], legend_rect[4])
        if left_pressed and self._legend_btn_hover then
            self._show_legend = not self._show_legend
            self:_update_side_panel_shift(panel_w, inverse_scale)
            return true
        end
    end

    -- Legend side panel: read-only, but consume hits so clicks do not fall through
    -- to the HUD behind it.
    if self._show_legend then
        local lcount = #_LEGEND_ROWS
        local lpx, lpy, lpw, lph = _get_legend_panel_rect(px, py, line_h, lcount, metrics.scale, inverse_scale)
        if cx >= lpx and cx <= lpx + lpw and cy >= lpy and cy <= lpy + lph then
            self._panel_mouse_over = true
            if left_pressed or input_service:get("left_hold")
                or input_service:get("right_pressed") or input_service:get("right_hold") then
                return true
            end
        end
    end

    -- Per-row edit-hide toggles (rects computed + stored during draw). Tested
    -- before row selection so a toggle click never selects the row.
    for _, box in ipairs(self._panel_edit_toggle_targets or {}) do
        if _point_in_rect(cx, cy, box.x, box.y, box.w, box.h) then
            self._edit_toggle_hover_element = box.node_name
            if left_pressed then
                self:_toggle_edit_hidden_by_node(box.node_name)
                return true
            end
            break
        end
    end

    -- Ignore-list side panel: drawn outside the main panel, so test it before the
    -- main-panel early-out. Double-click a row to restore the element.
    if self._show_ignore_panel then
        local ignore_list = self._panel_ignore_list
        local icount = #ignore_list
        local ipx, ipy, ipw, iph = _get_ignore_panel_rect(px, py, panel_w, line_h, icount, metrics.scale, inverse_scale)
        if cx >= ipx and cx <= ipx + ipw and cy >= ipy and cy <= ipy + iph then
            self._panel_mouse_over = true
            local rows_start_y = ipy + _side_header_h(metrics.scale, inverse_scale)
            if icount > 0 and cy >= rows_start_y and cy < rows_start_y + icount * line_h then
                local idx = math.floor((cy - rows_start_y) / line_h) + 1
                if idx >= 1 and idx <= icount then
                    self._ignore_hovered_index = idx
                    if left_pressed then
                        local key = "i:" .. idx
                        if self._panel_dclick_key == key and (t - self._panel_dclick_t) <= PANEL_DCLICK_TIME then
                            self._panel_dclick_key = nil
                            self:_restore_element(ignore_list[idx])
                        else
                            self._panel_dclick_key = key
                            self._panel_dclick_t = t
                        end
                        return true
                    end
                end
            end
            return panel_text_consumed or left_pressed or input_service:get("left_hold")
        end
    end

    if in_header and left_pressed then
        self._panel_dragging = true
        self._panel_drag_offset = { cx - px, cy - py }
        self._panel_hovered_index = nil
        return true
    end

    if not in_panel then
        self._panel_hovered_index = nil
        return panel_text_consumed
    end

    local list_start_y = py + hh
    if cy >= list_start_y and cy < list_start_y + list_height then
        local rel_y = cy - list_start_y
        local line_index = math.floor(rel_y / line_h) + 1 + self._panel_scroll_offset
        if line_index >= 1 and line_index <= total_nodes then
            self._panel_hovered_index = line_index
        else
            self._panel_hovered_index = nil
        end
    else
        self._panel_hovered_index = nil
    end

    self._panel_mouse_over = true
    if self._panel_hovered_index then
        self._panel_hover_preview_node = self._panel_normal_list[self._panel_hovered_index]
    end

    if left_pressed then
        for _, box in ipairs(self._panel_field_targets or {}) do
            if _point_in_rect(cx, cy, box.x, box.y, box.w, box.h) then
                self:_activate_panel_field(box.node_name, box.group, box.key)
                return true
            end
        end

        if self._panel_hovered_index then
            local node_name = self._panel_normal_list[self._panel_hovered_index]
            if node_name and self._widgets_by_name[node_name] then
                -- Double-click a row to move the element to the ignore list.
                local key = "n:" .. self._panel_hovered_index
                if self._panel_dclick_key == key and (t - self._panel_dclick_t) <= PANEL_DCLICK_TIME then
                    self._panel_dclick_key = nil
                    self:_ignore_element_by_node(node_name)
                    return true
                end
                self._panel_dclick_key = key
                self._panel_dclick_t = t
                self:_cancel_panel_field()
                self:_process_widget_press_left(node_name)
                return true
            end
        else
            self:_cancel_panel_field()
        end
    end

    if input_service:get("right_pressed") and self._panel_hovered_index then
        local node_name = self._panel_normal_list[self._panel_hovered_index]
        if node_name and self._widgets_by_name[node_name] then
            self:_cancel_panel_field()
            self:_process_widget_press_right(node_name)
            return true
        end
    end

    local scroll_axis = input_service:get("scroll_axis")
    if scroll_axis and scroll_axis[2] ~= 0 then
        local max_scroll = math.max(0, total_nodes - metrics.list_rows)
        local dir = scroll_axis[2] > 0 and -PANEL_SCROLL_SPEED or PANEL_SCROLL_SPEED
        self._panel_scroll_offset = math.clamp(self._panel_scroll_offset + dir, 0, max_scroll)
        return true
    end

    local mouse_over_panel = in_panel and (
        left_pressed or input_service:get("left_hold") or
        input_service:get("right_pressed") or input_service:get("right_hold")
    )

    return panel_text_consumed or mouse_over_panel
end

function HudElementCustomizer:_measure_text_size(ui_renderer, text, font_size)
    -- UIRenderer.text_size(self, text, font_type, font_size, ...) -> width, height
    local ok, w, h = pcall(UIRenderer.text_size, ui_renderer, text, PANEL_FONT_TYPE, font_size)
    if ok and type(w) == "number" and w > 0 then
        return w, (type(h) == "number" and h or font_size)
    end
    -- Fallback estimate if measurement is unavailable.
    return #text * font_size * 0.5, font_size
end

function HudElementCustomizer:_draw_info_panel(ui_renderer, input_service)
    if not self._show_info_panel then
        return
    end

    local inverse_scale = self._inverse_scale or RESOLUTION_LOOKUP.inverse_scale
    local all_node_names = self._panel_normal_list
    local total_nodes = #all_node_names
    local saved_settings = self._saved_node_settings
    local selected_list = self._selected_node_list
    local draw_layer = 998

    local selected_lookup = {}
    for _, name in ipairs(selected_list) do
        selected_lookup[name] = true
    end

    local has_selected = #selected_list > 0
    local has_active_edit = self._panel_active_field ~= nil
    local metrics = _get_panel_metrics(inverse_scale, has_selected, has_active_edit)
    local visible_count = math.min(total_nodes, metrics.list_rows)
    local panel_content_h = metrics.header_h + visible_count * metrics.line_h + metrics.detail_h
    local px, py = self:_get_panel_position(inverse_scale)
    local pw = metrics.width
    local ph = panel_content_h
    local lh = metrics.line_h
    local hh = metrics.header_h

    UIRenderer.draw_rect(ui_renderer, Vector3(px, py, draw_layer), Vector2(pw, ph), PANEL_BG_COLOR)
    UIRenderer.draw_rect(ui_renderer, Vector3(px, py, draw_layer + 1), Vector2(pw, hh), PANEL_HEADER_COLOR)

    -- Two-row header: title band on top (full width), button band below holding
    -- the Legend + Stash + Ignore toggles, left-aligned. Buttons wrap their
    -- measured label so the text reads centered; rects are stored for hit-testing.
    -- Keep all draws within draw_layer+2 -- higher layers are clipped by the
    -- element's layer range.
    local ps_is = metrics.scale * inverse_scale
    local title_band = PANEL_HEADER_TITLE_BAND * ps_is
    local ignore_pad = 5 * ps_is
    local btn_band_top = py + title_band
    local btn_bh = hh - title_band - 2 * ignore_pad
    local btn_by = btn_band_top + ignore_pad
    local b_border = math.max(1, 1 * ps_is)

    -- Title (top band, full width).
    _safe_draw_text(
        ui_renderer,
        string.format("Custom HUD Panel (%d)", total_nodes),
        PANEL_FONT_TYPE,
        metrics.font,
        Vector3(px + 10 * ps_is, py + 2 * ps_is, draw_layer + 2),
        Vector2(math.max(0, pw - 20 * ps_is), title_band),
        PANEL_TEXT_COLOR,
        "left",
        "center"
    )

    -- Each button is sized to fit its label (see PANEL_BTN_PAD note). The text
    -- inset is the actual-pixel pad converted to pass space (* inverse_scale).
    local btn_text_lead = PANEL_BTN_PAD * inverse_scale
    local function _draw_btn(bx, bw, label, tw, th, fill)
        UIRenderer.draw_rect(ui_renderer, Vector3(bx, btn_by, draw_layer + 1), Vector2(bw, btn_bh), IGNORE_BTN_BORDER_COLOR)
        UIRenderer.draw_rect(ui_renderer, Vector3(bx + b_border, btn_by + b_border, draw_layer + 1), Vector2(bw - 2 * b_border, btn_bh - 2 * b_border), fill)
        local ty = btn_by + math.max(0, (btn_bh - th) * 0.5)
        -- Give the text box the full button width (not the exact measured width):
        -- at scale 1 a box equal to the text width can wrap the last word.
        _safe_draw_text(ui_renderer, label, PANEL_FONT_TYPE, metrics.font_small,
            Vector3(bx + btn_text_lead, ty, draw_layer + 2), Vector2(bw, th), IGNORE_BTN_TEXT_COLOR, "left", "top")
    end

    local edit_hidden_count = 0
    for _ in pairs(_user_edit_hidden) do edit_hidden_count = edit_hidden_count + 1 end

    local legend_label = string.format("Legend %s", self._show_legend and ">" or "<")
    local reveal_label = string.format("Stash (%d) %s", edit_hidden_count, self._reveal_edit_hidden and "On" or "Off")
    local ignore_label = string.format("Ignore (%d) %s", #self._panel_ignore_list, self._show_ignore_panel and "<" or ">")

    local legend_tw, legend_th = self:_measure_text_size(ui_renderer, legend_label, metrics.font_small)
    local reveal_tw, reveal_th = self:_measure_text_size(ui_renderer, reveal_label, metrics.font_small)
    local ignore_tw, ignore_th = self:_measure_text_size(ui_renderer, ignore_label, metrics.font_small)

    -- Button width = (text px + 2*pad) converted from actual pixels to pass space.
    -- Resolution-independent: wraps the label identically at any resolution.
    local btn_pad2 = 2 * PANEL_BTN_PAD
    local legend_bw = (legend_tw + btn_pad2) * inverse_scale
    local reveal_bw = (reveal_tw + btn_pad2) * inverse_scale
    local ignore_bw = (ignore_tw + btn_pad2) * inverse_scale

    local cursor_x = px + ignore_pad
    local legend_bx = cursor_x
    cursor_x = cursor_x + legend_bw + ignore_pad
    local reveal_bx = cursor_x
    cursor_x = cursor_x + reveal_bw + ignore_pad
    local ignore_bx = cursor_x

    local legend_rect = self._legend_btn_rect or {}
    legend_rect[1], legend_rect[2], legend_rect[3], legend_rect[4] = legend_bx, btn_by, legend_bw, btn_bh
    self._legend_btn_rect = legend_rect

    local reveal_rect = self._reveal_btn_rect or {}
    reveal_rect[1], reveal_rect[2], reveal_rect[3], reveal_rect[4] = reveal_bx, btn_by, reveal_bw, btn_bh
    self._reveal_btn_rect = reveal_rect

    local btn_rect = self._ignore_btn_rect or {}
    btn_rect[1], btn_rect[2], btn_rect[3], btn_rect[4] = ignore_bx, btn_by, ignore_bw, btn_bh
    self._ignore_btn_rect = btn_rect

    -- Legend button.
    local legend_fill
    if self._show_legend then
        legend_fill = self._legend_btn_hover and IGNORE_BTN_COLOR_OPEN_HOVER or IGNORE_BTN_COLOR_OPEN
    else
        legend_fill = self._legend_btn_hover and IGNORE_BTN_COLOR_HOVER or IGNORE_BTN_COLOR
    end
    _draw_btn(legend_bx, legend_bw, legend_label, legend_tw, legend_th, legend_fill)

    -- Stash button.
    local reveal_btn_fill
    if self._reveal_edit_hidden then
        reveal_btn_fill = self._reveal_btn_hover and REVEAL_BTN_COLOR_ON_HOVER or REVEAL_BTN_COLOR_ON
    else
        reveal_btn_fill = self._reveal_btn_hover and IGNORE_BTN_COLOR_HOVER or IGNORE_BTN_COLOR
    end
    _draw_btn(reveal_bx, reveal_bw, reveal_label, reveal_tw, reveal_th, reveal_btn_fill)

    -- Ignore button.
    local ignore_btn_fill
    if self._show_ignore_panel then
        ignore_btn_fill = self._ignore_btn_hover and IGNORE_BTN_COLOR_OPEN_HOVER or IGNORE_BTN_COLOR_OPEN
    else
        ignore_btn_fill = self._ignore_btn_hover and IGNORE_BTN_COLOR_HOVER or IGNORE_BTN_COLOR
    end
    _draw_btn(ignore_bx, ignore_bw, ignore_label, ignore_tw, ignore_th, ignore_btn_fill)

    -- Legend side panel (drawn to the left of the main panel).
    self:_draw_legend_panel(ui_renderer, px, py, metrics, inverse_scale, draw_layer)

    local scroll = self._panel_scroll_offset
    local edit_targets = self._panel_edit_toggle_targets
    for i = #edit_targets, 1, -1 do edit_targets[i] = nil end
    for i = 1, visible_count do
        local data_index = i + scroll
        if data_index > total_nodes then
            break
        end

        local node_name = all_node_names[data_index]
        local element_name = split_node_name(node_name)
        local short_name = short_element_name(node_name)
        local line_y = py + hh + (i - 1) * lh
        local is_selected = selected_lookup[node_name]
        local is_hovered = (self._panel_hovered_index == data_index)
        local node_settings = saved_settings[node_name]
        local is_hidden = node_settings and node_settings.is_hidden
        local edit_hidden = _is_element_edit_hidden(element_name)

        local line_color = PANEL_LINE_COLOR
        if is_selected then
            line_color = PANEL_LINE_SELECTED_COLOR
        elseif is_hovered then
            line_color = PANEL_LINE_HOVER_COLOR
        end

        if line_color[1] > 0 then
            UIRenderer.draw_rect(ui_renderer, Vector3(px + 2 * inverse_scale, line_y, draw_layer + 1),
                Vector2(pw - 4 * inverse_scale, lh - 1 * inverse_scale), line_color)
        end

        -- Tags + color coding (shared by the row text and the end-of-row box):
        -- [H] hidden from live HUD, [S] stashed from edit mode.
        local text_color = PANEL_TEXT_COLOR
        local box_fill = EDIT_TOGGLE_SHOWN_COLOR
        local box_icon = TOGGLE_ICON_NORMAL
        local box_icon_scale = TOGGLE_ICON_SCALE_NORMAL
        local suffix = ""
        if is_hidden and edit_hidden then
            text_color = ROW_COLOR_BOTH
            box_fill = ROW_COLOR_BOTH
            box_icon = TOGGLE_ICON_BOTH
            box_icon_scale = TOGGLE_ICON_SCALE_BOTH
            suffix = " [S][H]"
        elseif is_hidden then
            text_color = ROW_COLOR_HIDDEN
            box_fill = ROW_COLOR_HIDDEN
            box_icon = TOGGLE_ICON_HIDDEN
            box_icon_scale = TOGGLE_ICON_SCALE_HIDDEN
            suffix = " [H]"
        elseif edit_hidden then
            text_color = ROW_COLOR_EDIT
            box_fill = ROW_COLOR_EDIT
            box_icon = TOGGLE_ICON_STASHED
            box_icon_scale = TOGGLE_ICON_SCALE_STASHED
            suffix = " [S]"
        end

        -- Per-row stash toggle: a small square at the right edge, filled with the
        -- row's tag color. Hit rect is stored for the input handler; text width is
        -- shrunk to clear it.
        local tgl_size = lh - 5 * ps_is
        local tgl_x = px + pw - tgl_size - 5 * ps_is
        local tgl_y = line_y + 2.5 * ps_is
        local tgl_hovered = (self._edit_toggle_hover_element == node_name)
        local tgl_border = tgl_hovered and EDIT_TOGGLE_HOVER_BORDER_COLOR or EDIT_TOGGLE_BORDER_COLOR
        local tgl_border_w = math.max(1, 1 * ps_is)
        UIRenderer.draw_rect(ui_renderer, Vector3(tgl_x, tgl_y, draw_layer + 1), Vector2(tgl_size, tgl_size), tgl_border)
        UIRenderer.draw_rect(ui_renderer, Vector3(tgl_x + tgl_border_w, tgl_y + tgl_border_w, draw_layer + 1),
            Vector2(tgl_size - 2 * tgl_border_w, tgl_size - 2 * tgl_border_w), box_fill)

        if box_icon then
            local icon_size = tgl_size * box_icon_scale
            local icon_off = (tgl_size - icon_size) * 0.5
            pcall(UIRenderer.draw_texture, ui_renderer, box_icon,
                Vector3(tgl_x + icon_off, tgl_y + icon_off, draw_layer + 2),
                Vector2(icon_size, icon_size),
                TOGGLE_ICON_COLOR)
        end

        edit_targets[#edit_targets + 1] = {
            x = tgl_x, y = tgl_y, w = tgl_size, h = tgl_size, node_name = node_name
        }

        local text_left = px + 10 * metrics.scale * inverse_scale
        _safe_draw_text(
            ui_renderer,
            short_name .. suffix,
            PANEL_FONT_TYPE,
            metrics.font_small,
            Vector3(text_left, line_y, draw_layer + 2),
            Vector2(math.max(0, tgl_x - text_left - 4 * ps_is), lh),
            text_color,
            "left",
            "center"
        )
    end

    self._panel_field_targets = {}

    if #selected_list > 0 then
        local selected_name = selected_list[1]
        local node_settings = self:_get_selected_node_settings(selected_name)
        local detail_y = py + hh + visible_count * lh
        local detail_h = metrics.detail_h
        UIRenderer.draw_rect(ui_renderer, Vector3(px, detail_y, draw_layer + 1),
            Vector2(pw, detail_h), PANEL_DETAIL_BG_COLOR)

        local panel_scale = metrics.scale
        local title_h = 24 * panel_scale * inverse_scale
        local helper_line_h = 18 * panel_scale * inverse_scale
        local helper_gap = 8 * panel_scale * inverse_scale
        local info_pad_x = 12 * panel_scale * inverse_scale
        local info_top = 8 * panel_scale * inverse_scale
        local helper1_y = detail_y + info_top + title_h + 6 * panel_scale * inverse_scale
        local helper2_y = helper1_y + helper_line_h + helper_gap
        local editing_y = helper2_y + helper_line_h + helper_gap
        _safe_draw_text(
            ui_renderer,
            "Selected: " .. short_element_name(selected_name),
            PANEL_FONT_TYPE,
            metrics.font_small,
            Vector3(px + info_pad_x, detail_y + info_top, draw_layer + 2),
            Vector2(pw - info_pad_x * 2, title_h),
            PANEL_DETAIL_VALUE_COLOR,
            "left",
            "center"
        )

        _safe_draw_text(
            ui_renderer,
            "Click a value label and type to replace it live.",
            PANEL_FONT_TYPE,
            math.max(8, metrics.font_small - 1),
            Vector3(px + info_pad_x, helper1_y, draw_layer + 2),
            Vector2(pw - info_pad_x * 2, title_h),
            PANEL_DETAIL_LABEL_COLOR,
            "left",
            "center"
        )

        _safe_draw_text(
            ui_renderer,
            "Click elsewhere to keep it. Esc cancels the active edit.",
            PANEL_FONT_TYPE,
            math.max(8, metrics.font_small - 1),
            Vector3(px + info_pad_x, helper2_y, draw_layer + 2),
            Vector2(pw - info_pad_x * 2, title_h),
            PANEL_DETAIL_LABEL_COLOR,
            "left",
            "center"
        )

        local active = self._panel_active_field
        if active and active.node_name == selected_name then
            _safe_draw_text(
                ui_renderer,
                string.format("Editing %s %s = %s", active.group, string.upper(active.key), tostring(active.buffer or "")),
                PANEL_FONT_TYPE,
                math.max(8, metrics.font_small - 1),
                Vector3(px + info_pad_x, editing_y, draw_layer + 2),
                Vector2(pw - info_pad_x * 2, title_h),
                PANEL_DETAIL_VALUE_COLOR,
                "left",
                "center"
            )
        end

        local defaults = node_settings.default_settings or self._default_node_settings[selected_name] or {}
        defaults.position = defaults.position or {0,0,0}
        defaults.size = defaults.size or {0,0}

        local col_gap = 12 * panel_scale * inverse_scale
        local label_w = 18 * panel_scale * inverse_scale
        local col_w = (pw - 24 * panel_scale * inverse_scale - col_gap) / 2
        local row_h = 24 * panel_scale * inverse_scale
        local row_gap = 8 * panel_scale * inverse_scale
        local fields_top = detail_y + (editing_y - detail_y) + helper_line_h + 14 * panel_scale * inverse_scale
        local left_x = px + 10 * panel_scale * inverse_scale
        local right_x = left_x + col_w + col_gap
        _current_map_pool.x = node_settings.x or 0
        _current_map_pool.y = node_settings.y or 0
        _current_map_pool.z = node_settings.z or 0
        _current_map_pool.w = (node_settings.size and node_settings.size[1]) or 0
        _current_map_pool.h = (node_settings.size and node_settings.size[2]) or 0
        _default_map_pool.x = defaults.position[1] or 0
        _default_map_pool.y = defaults.position[2] or 0
        _default_map_pool.z = defaults.position[3] or 0
        _default_map_pool.w = defaults.size[1] or 0
        _default_map_pool.h = defaults.size[2] or 0

        local function draw_field_column(group_name, base_x, values, title)
            _safe_draw_text(
                ui_renderer,
                title,
                PANEL_FONT_TYPE,
                metrics.font_small,
                Vector3(base_x, fields_top - 24 * panel_scale * inverse_scale, draw_layer + 2),
                Vector2(col_w, 18 * panel_scale * inverse_scale),
                PANEL_DETAIL_VALUE_COLOR,
                "left",
                "center"
            )

            for row_index = 1, #_field_rows do
                local row = _field_rows[row_index]
                local y = fields_top + (row_index - 1) * (row_h + row_gap)
                local active = self._panel_active_field
                local is_active = active and active.node_name == selected_name and active.group == group_name and active.key == row.key
                local display_value = is_active and ((active.buffer ~= "" and active.buffer) or "") or _format_field_value(values[row.key])
                local display_text = tostring(display_value or "")
                local row_x = base_x
                local row_w = col_w

                if is_active then
                    UIRenderer.draw_rect(ui_renderer, Vector3(row_x, y, draw_layer + 1), Vector2(row_w, row_h), _active_field_bg_color)
                end

                _safe_draw_text(
                    ui_renderer,
                    string.format("%s: %s", row.label, display_text ~= "" and display_text or "-"),
                    PANEL_FONT_TYPE,
                    metrics.font_small,
                    Vector3(base_x, y, draw_layer + 2),
                    Vector2(col_w, row_h),
                    is_active and PANEL_DETAIL_VALUE_COLOR or PANEL_DETAIL_LABEL_COLOR,
                    "left",
                    "center"
                )

                table.insert(self._panel_field_targets, {
                    x = row_x, y = y, w = row_w, h = row_h,
                    node_name = selected_name, group = group_name, key = row.key
                })
            end
        end

        draw_field_column("current", left_x, _current_map_pool, "Current")
        draw_field_column("default", right_x, _default_map_pool, "Default / Reset")

        local status_y = fields_top + #_field_rows * (row_h + row_gap) + 10 * panel_scale * inverse_scale
        _safe_draw_text(
            ui_renderer,
            string.format("Scale: %.2f   Hidden: %s", node_settings.scale or 1, node_settings.is_hidden and "yes" or "no"),
            PANEL_FONT_TYPE,
            math.max(8, metrics.font_small - 1),
            Vector3(px + 10 * panel_scale * inverse_scale, status_y, draw_layer + 2),
            Vector2(pw - 20 * panel_scale * inverse_scale, 18 * panel_scale * inverse_scale),
            PANEL_DETAIL_LABEL_COLOR,
            "left",
            "center"
        )
    end

    if self._show_ignore_panel then
        self:_draw_ignore_panel(ui_renderer, px, py, pw, metrics, inverse_scale, draw_layer)
    end
end

function HudElementCustomizer:_draw_legend_panel(ui_renderer, px, py, metrics, inverse_scale, draw_layer)
    if not self._show_legend then
        return
    end

    local lh = metrics.line_h
    local scale = metrics.scale
    local ps_is = scale * inverse_scale
    local hh = _side_header_h(scale, inverse_scale)
    local count = #_LEGEND_ROWS

    local lpx, lpy, lpw, lph = _get_legend_panel_rect(px, py, lh, count, scale, inverse_scale)

    UIRenderer.draw_rect(ui_renderer, Vector3(lpx, lpy, draw_layer), Vector2(lpw, lph), PANEL_BG_COLOR)
    UIRenderer.draw_rect(ui_renderer, Vector3(lpx, lpy, draw_layer + 1), Vector2(lpw, hh), PANEL_HEADER_COLOR)

    _safe_draw_text(
        ui_renderer,
        mod:localize("legend_title"),
        PANEL_FONT_TYPE,
        metrics.font,
        Vector3(lpx + 10 * ps_is, lpy + 2 * ps_is, draw_layer + 2),
        Vector2(math.max(0, lpw - 20 * ps_is), hh),
        PANEL_TEXT_COLOR,
        "left",
        "center"
    )

    local pad_x = 10 * ps_is
    local key_w = LEGEND_KEY_COL * ps_is
    for i = 1, count do
        local row = _LEGEND_ROWS[i]
        local ry = lpy + hh + (i - 1) * lh
        if row.section then
            _safe_draw_text(
                ui_renderer, mod:localize(row.section), PANEL_FONT_TYPE, metrics.font_small,
                Vector3(lpx + pad_x, ry, draw_layer + 2), Vector2(math.max(0, lpw - 2 * pad_x), lh),
                PANEL_LEGEND_SECTION_COLOR, "left", "center"
            )
        else
            _safe_draw_text(
                ui_renderer, row.key, PANEL_FONT_TYPE, metrics.font_small,
                Vector3(lpx + pad_x, ry, draw_layer + 2), Vector2(key_w, lh),
                PANEL_LEGEND_KEY_COLOR, "left", "center"
            )
            _safe_draw_text(
                ui_renderer, mod:localize(row.action), PANEL_FONT_TYPE, metrics.font_small,
                Vector3(lpx + pad_x + key_w + 6 * ps_is, ry, draw_layer + 2),
                Vector2(math.max(0, lpw - 2 * pad_x - key_w - 6 * ps_is), lh),
                PANEL_TEXT_COLOR, "left", "center"
            )
        end
    end
end

function HudElementCustomizer:_draw_ignore_panel(ui_renderer, px, py, pw, metrics, inverse_scale, draw_layer)
    local lh = metrics.line_h
    local scale = metrics.scale
    local hh = _side_header_h(scale, inverse_scale)
    local ignore_list = self._panel_ignore_list
    local count = #ignore_list

    local ipx, ipy, ipw, iph = _get_ignore_panel_rect(px, py, pw, lh, count, scale, inverse_scale)

    UIRenderer.draw_rect(ui_renderer, Vector3(ipx, ipy, draw_layer), Vector2(ipw, iph), PANEL_BG_COLOR)
    UIRenderer.draw_rect(ui_renderer, Vector3(ipx, ipy, draw_layer + 1), Vector2(ipw, hh), PANEL_HEADER_COLOR)

    _safe_draw_text(
        ui_renderer,
        string.format("Ignore List (%d)", count),
        PANEL_FONT_TYPE,
        metrics.font_small,
        Vector3(ipx + 10 * scale * inverse_scale, ipy + 3 * scale * inverse_scale, draw_layer + 2),
        Vector2(ipw - 20 * scale * inverse_scale, hh - 6 * scale * inverse_scale),
        PANEL_TEXT_COLOR,
        "left",
        "center"
    )

    if count == 0 then
        _safe_draw_text(
            ui_renderer,
            "Double-click a row on the left to ignore it.",
            PANEL_FONT_TYPE,
            math.max(8, metrics.font_small - 1),
            Vector3(ipx + 10 * scale * inverse_scale, ipy + hh + 4 * scale * inverse_scale, draw_layer + 2),
            Vector2(ipw - 20 * scale * inverse_scale, lh * 2),
            PANEL_DETAIL_LABEL_COLOR,
            "left",
            "top"
        )
        return
    end

    for i = 1, count do
        local element_name = ignore_list[i]
        local short = (element_name:gsub("^HudElement", ""):gsub("^ConstantElement", "C:"))
        local line_y = ipy + hh + (i - 1) * lh
        local is_hovered = (self._ignore_hovered_index == i)

        if is_hovered then
            UIRenderer.draw_rect(ui_renderer, Vector3(ipx + 2 * inverse_scale, line_y, draw_layer + 1),
                Vector2(ipw - 4 * inverse_scale, lh - 1 * inverse_scale), PANEL_LINE_HOVER_COLOR)
        end

        _safe_draw_text(
            ui_renderer,
            short,
            PANEL_FONT_TYPE,
            metrics.font_small,
            Vector3(ipx + 10 * scale * inverse_scale, line_y, draw_layer + 2),
            Vector2(ipw - 20 * scale * inverse_scale, lh),
            PANEL_TEXT_COLOR,
            "left",
            "center"
        )
    end
end

-- ============================================================================
-- Apply saved settings
-- ============================================================================

function HudElementCustomizer:_apply_saved_node_settings()
    if not _mod_enabled() then
        return
    end

    local saved_node_settings = self._saved_node_settings
    if not saved_node_settings then
        return
    end

    mod._position_overrides = {}
    local inverse_hud_scale = self:_get_inverse_hud_scale()
    for node_name, node_settings in pairs(saved_node_settings) do
        local element_name, scenegraph_id = split_node_name(node_name)
        if _excluded_element_names[element_name] then
            saved_node_settings[node_name] = nil
        elseif _user_ignored[element_name] then
            -- User-ignored: keep saved settings so customization returns on restore,
            -- but skip applying so the element renders at its vanilla position.
        else
            local element = self:_get_element(element_name)
            if element and type(element._ui_scenegraph) == "table" then
            -- rawget bypasses strict-readonly __index that ferrors on missing keys.
            -- Saved layouts may reference scenegraph nodes from now-disabled mods.
            local has_scenegraph_id = rawget(element._ui_scenegraph, scenegraph_id) ~= nil

            if has_scenegraph_id then
                local is_constant_element = string.starts_with(element_name, "ConstantElement")
                local x = node_settings.x
                local y = node_settings.y
                local z = node_settings.z
                if is_constant_element then
                    x = x / inverse_hud_scale
                    y = y / inverse_hud_scale
                end

                if not element._hidden_scenegraphs then
                    element._hidden_scenegraphs = {}
                end

                local ok = mod._set_element_sg_position and mod._set_element_sg_position(element, scenegraph_id, x, y, z)
                if ok then
                    local is_tactical_overlay_node = element_name == "HudElementTacticalOverlay" and scenegraph_id ~= nil and scenegraph_id ~= ""
                    if not is_tactical_overlay_node then
                        element._is_hidden = node_settings.is_hidden
                    end

                    local pos_overrides = mod._position_overrides
                    local entry = pos_overrides[element]
                    if not entry then
                        entry = { nodes = {}, has_delta = false }
                        pos_overrides[element] = entry
                    end
                    local defaults = node_settings.default_settings
                    local default_pos = defaults and defaults.position or {}
                    local delta_x = x - (default_pos[1] or 0)
                    local delta_y = y - (default_pos[2] or 0)
                    entry.nodes[scenegraph_id] = { x, y, z, delta_x = delta_x, delta_y = delta_y }
                    -- Precomputed so the per-frame _draw_widgets hook doesn't
                    -- rescan every override each frame. Overrides are rebuilt
                    -- from scratch on every apply, so this never goes stale.
                    if delta_x ~= 0 or delta_y ~= 0 then
                        entry.has_delta = true
                    end

                    -- Draw hook only for elements that are actually hidden
                    -- (position pinning is handled by the central repin pass;
                    -- opacity by the lazily installed base-class hooks).
                    if node_settings.is_hidden then
                        _ensure_element_draw_hook(element)
                    end

                    local class_name = element.__class_name

                    -- For elements like HudElementWeaponCounter that compute widget positions
                    -- in _draw_widgets from crosshair/aim rather than scenegraph, the scenegraph
                    -- pivot is math-cancelled and set_scenegraph_position has no visual effect.
                    -- Hook _draw_widgets to redraw slot widgets at crosshair + delta offset.
                    -- Gated on the element actually HAVING slot widgets and a nonzero delta:
                    -- _draw_widgets is inherited by every element, so hooking it per customized
                    -- class (the old behavior) added a permanent per-frame DMF chain to each.
                    local hooked_dw = mod._hooked_element_draw_widgets
                    if class_name and CLASS and CLASS[class_name]
                        and element._slot_widgets and entry.has_delta
                        and CLASS[class_name]._draw_widgets
                        and not hooked_dw[class_name] then
                        mod:hook(CLASS[class_name], "_draw_widgets", function(func, self, dt, t, input_service, ui_renderer, render_settings)
                            -- has_delta is precomputed at apply time; the common
                            -- per-frame case reduces to two table lookups.
                            local entry = mod._position_overrides[self]
                            local has_delta = entry and entry.has_delta and self._slot_widgets ~= nil
                                and _mod_enabled()

                            -- Suppress vanilla slot_widget draw so we can reposition them.
                            -- Swap to empty table: pairs({}) = no iterations, no draw.
                            local slot_widgets
                            if has_delta then
                                slot_widgets = self._slot_widgets
                                self._slot_widgets = {}
                            end

                            func(self, dt, t, input_service, ui_renderer, render_settings)

                            if has_delta then
                                self._slot_widgets = slot_widgets
                                local scale = ui_renderer.scale
                                for _, pos in pairs(entry.nodes) do
                                    local dx = pos.delta_x
                                    local dy = pos.delta_y
                                    if dx and dy and (dx ~= 0 or dy ~= 0) then
                                        local cx = self._crosshair_position_x + dx * scale
                                        local cy = self._crosshair_position_y + dy * scale
                                        for _, widget in pairs(slot_widgets) do
                                            local wo = widget.offset
                                            wo[1] = cx
                                            wo[2] = cy
                                            UIWidget.draw(widget, ui_renderer)
                                        end
                                    end
                                end
                            end
                        end)
                        hooked_dw[class_name] = true
                    end
                end
            else
                saved_node_settings[node_name] = nil
            end
            end
        end
    end

    -- One persist per apply (also prunes entries dropped above). Clears both
    -- flags: overrides are now current and the table is flushed.
    self._apply_needed = false
    self._settings_dirty = false
    mod:set("saved_node_settings", saved_node_settings)
end

return HudElementCustomizer
