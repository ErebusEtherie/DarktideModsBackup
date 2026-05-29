-- File: scripts/mods/SimpleBuffFilter/util/options_rebuilder.lua
-- Purpose: Rebuild DMF options in-place so newly discovered talents appear immediately,
--          without accumulating duplicate blocks — and without disappearing from DMF.
-- Notes:
--   * Uses DMF dot-call signature (dmf.initialize_mod_options(mod, data))
--   * Never mutates mod._data (avoids DMF "internal mod data" warnings)
--   * Flash refresh: specifically targets "dmf_options_view" (only view we need)
--   * Flashing is opt-in (silent by default). Call rebuild_and_flash_now()
--     or rebuild_now(true / {flash=true}) for the refresh/wipe buttons.
--   * IMPORTANT: During rebuilds we pass ONLY the { options = {…} } payload
--     (widgets + localize), never full mod metadata — prevents duplicate toggle rows.

local mod = get_mod("SortModMenu"); if not mod then return {} end
--[[
options_rebuilder.lua – helper to rebuild/refresh option lists after discovery or wipes. (Utility referenced by options flow.)
]]

local M = {}
mod.options_rebuilder = M -- expose for cross-file use

-- --- tiny utils -------------------------------------------------------------
local function _count(t)
    if type(t) ~= "table" then return 0 end
    local n = 0; for _ in pairs(t) do n = n + 1 end
    return n
end

-- Register any dynamic localization keys used in widgets (labels/descriptions).
local function _register_loc_for_widgets(widgets)
    local loc = rawget(_G, "Managers") and Managers.localization
    if not loc or type(widgets) ~= "table" then return end

    local add = {}

    local function _resolved_or_nil(key)
        if type(key) ~= "string" or key == "" then return nil end
        local out = Localize(key)
        if type(out) == "string" and out ~= ("<" .. key .. ">") then
            return out
        end
        return nil
    end

    local function _missing_in_game(key)
        local out = Localize(key)
        return (type(out) ~= "string") or (out == ("<" .. key .. ">"))
    end

    local function _add_if_missing(key, value)
        if type(key) == "string" and key ~= "" and type(value) == "string" and value ~= "" then
            if _missing_in_game(key) then
                add[key] = { en = value }
            end
        end
    end

    local function _walk(w)
        if type(w) ~= "table" then return end

        -- Resolve label/description (from widget.text / widget.title / widget.description)
        local label = nil

        -- Prefer explicit title if present; otherwise fall back to text.
        if w.localize ~= false and type(w.title) == "string" then
            label = _resolved_or_nil(w.title) or w.title
            _add_if_missing(w.title, label)
        end

        if not label and w.localize ~= false and type(w.text) == "string" then
            label = _resolved_or_nil(w.text) or w.text
            _add_if_missing(w.text, label)
        end

        if w.localize ~= false and type(w.description) == "string" then
            local desc = _resolved_or_nil(w.description)
            if desc then _add_if_missing(w.description, desc) end
        end

        -- ★ Key bit: alias widget.setting_id -> resolved label
        if type(w.setting_id) == "string" and label and w.localize ~= false then
            _add_if_missing(w.setting_id, label)
        end

        -- Recurse
        if type(w.sub_widgets) == "table" then
            for i = 1, #w.sub_widgets do _walk(w.sub_widgets[i]) end
        end
    end

    for i = 1, #widgets do _walk(widgets[i]) end
    if next(add) then loc:add_localized_strings(add) end
end

-- --- load fresh *options-only* payload from our data file -------------------
-- Returns a table suitable to pass directly to DMF.initialize_mod_options:
--   { localize = boolean, widgets = { … } }
local function _load_options_payload()
    local data = mod:io_dofile("SortModMenu/scripts/mods/SortModMenu/SortModMenu_data")

    if type(data) ~= "table" then
        return nil
    end

    local widgets, localize

    if data.options and type(data.options.widgets) == "table" then
        widgets  = data.options.widgets
        localize = (data.options.localize ~= false)
    elseif type(data.widgets) == "table" then
        -- fallback shape
        widgets  = data.widgets
        localize = (data.localize ~= false)
    else
        return nil
    end

    if _count(widgets) == 0 then
        return nil
    end

    _register_loc_for_widgets(widgets)

    -- IMPORTANT: Do NOT include name/description/is_togglable here.
    return {
        localize = localize,
        widgets  = widgets,
    }
end

-- --- duplicate-prevention (fallback if DMF lacks remove_mod_options) --------
local function _build_sentinels_from_ui()
    -- keep fixed maintenance/debug entries
    local s = {
        ["sort_order"]        = true,
        ["pinned_icon"]       = true,
        ["searchbox_enabled"] = true,
        ["pinned_mods_group"] = true,
        ["hidden_mods_group"] = true,
    }

    -- Also add the individual pin IDs (pin_0 through pin_9)
    for i = 0, 9 do
        s["pin_" .. i] = true
    end

    -- Commented out to fix Simple Buff Filter not appearing in mod list 3/3/2026
    -- -- add one group sentinel per archetype in UiSettings.archetype_font_icon_simple
    -- local UiSettings = require("scripts/settings/ui/ui_settings")
    -- if UiSettings and type(UiSettings.archetype_font_icon_simple) == "table" then
    --     for arch, _ in pairs(UiSettings.archetype_font_icon_simple) do
    --         s["group_" .. tostring(arch)] = true
    --     end
    -- end

    return s
end

local SENTINELS = _build_sentinels_from_ui()

local function _scan_widgets(list)
    if type(list) ~= "table" then return false end
    for _, w in pairs(list) do
        if type(w) == "table" then
            if SENTINELS[w.setting_id] then return true end
            if _scan_widgets(w.sub_widgets) then return true end
        end
    end
    return false
end

local function _block_belongs_to_us(block)
    if type(block) ~= "table" then return false end
    if block.widgets and _scan_widgets(block.widgets) then return true end
    if _scan_widgets(block) then return true end
    return false
end

local function _has_our_block(dmf)
    local src = dmf and dmf.options_widgets_data
    if type(src) ~= "table" then return false end
    for i = 1, #src do
        if _block_belongs_to_us(src[i]) then return true end
    end
    return false
end

local function _remove_previous_blocks(dmf)
    if not dmf then return end
    if dmf.remove_mod_options then
        -- DMF expects dot-call with (mod)
        dmf.remove_mod_options(mod)
        return
    end
    -- Fallback: filter DMF's options_widgets_data to drop our old block(s)
    local src = dmf.options_widgets_data
    if type(src) ~= "table" then return end
    local out, n = {}, 0
    for i = 1, #src do
        local entry = src[i]
        if not _block_belongs_to_us(entry) then
            n = n + 1; out[n] = entry
        end
    end
    dmf.options_widgets_data = out
end

-- --- flash refresh: specifically for DMF's "dmf_options_view" ---------------
local VIEW_NAME    = "dmf_options_view"
local _FLASH_DELAY = 0.0001

local function _try_close(ui, view_name)
    if ui.close_view then
        ui:close_view(view_name, true, true) -- permissive flags
    end
end

local function _try_open(ui, view_name)
    if ui.open_view then
        ui:open_view(view_name)
        return true
    end
    return false
end

function M.flash_options_view_if_open()
    local ui = rawget(_G, "Managers") and Managers.ui
    if not ui or not ui.view_active then return end

    local is_open = ui:view_active(VIEW_NAME)
    if not is_open then return end

    _try_close(ui, VIEW_NAME)

    -- Try immediate reopen (menus may not tick mod.update)
    local reopened = _try_open(ui, VIEW_NAME)

    -- If close is async, schedule reopen on both UI thread and mod.update as fallback
    if not reopened then
        -- Schedule on UI thread and mod.update as belt-and-braces
        mod.__tbf_reopen_view        = VIEW_NAME
        local now_main               = (Managers.time and Managers.time:time("main") or os.clock())
        mod.__tbf_reopen_at          = now_main + _FLASH_DELAY
        mod.__tbf_ui_reopen_deadline = 0
    end
end

-- Expose a helper so callers can reuse the same refresh primitive.
mod._flash_options_view = M.flash_options_view_if_open

-- UI-thread reopen (runs even with menus open)
if not mod._tbf_ui_tick_installed then
    local UIManager = require("scripts/managers/ui/ui_manager")
    if UIManager and mod.hook_safe then
        mod:hook_safe(UIManager, "update", function(self, dt, t)
            if not mod.__tbf_reopen_view then return end
            local deadline = mod.__tbf_ui_reopen_deadline or 0
            if deadline == 0 then
                mod.__tbf_ui_reopen_deadline = (t or 0) + 0.01 -- ~1 frame
                return
            end
            if (t or 0) >= deadline then
                local view = mod.__tbf_reopen_view
                mod.__tbf_reopen_view, mod.__tbf_ui_reopen_deadline = nil, nil
                _try_open(self, view) -- self is UIManager
            end
        end)
        mod._tbf_ui_tick_installed = true
    end
end

-- --- public API -------------------------------------------------------------

-- Explicit control — pass true / {flash=true} to flash; otherwise silent.
function M.rebuild_now(opts)
    local dmf = get_mod and get_mod("DMF")
    if not (dmf and dmf.initialize_mod_options) then
        return false
    end

    -- Load *options-only* payload
    local options_payload = _load_options_payload()
    if not options_payload then return false end

    _remove_previous_blocks(dmf)

    -- IMPORTANT: pass ONLY the options (prevents duplicate toggle rows)
    dmf.initialize_mod_options(mod, options_payload)

    -- Guard-rail: verify our block exists; retry once with raw data if needed
    if not _has_our_block(dmf) then
        local data = mod:io_dofile("SortModMenu/scripts/mods/SortModMenu/SortModMenu_data")
        if type(data) == "table" then
            local fallback = data.options or data
            if type(fallback) == "table" then
                dmf.initialize_mod_options(mod, fallback)
            end
        end
    end

    if not _has_our_block(dmf) then
        return false
    end

    -- Decide whether to flash (defaults to false).
    local requested = (opts == true)
        or (type(opts) == "table" and opts.flash == true)

    local do_flash = requested
    if rawget(mod, "__tbf_skip_next_flash") then
        mod.__tbf_skip_next_flash = nil
        do_flash = false
    end

    if do_flash then
        if mod._flash_options_view then
            mod._flash_options_view()
        else
            M.flash_options_view_if_open()
        end
    end

    return true
end

-- Convenience wrappers
function M.rebuild_and_flash_now() return M.rebuild_now(true) end

function M.rebuild_silent_now() return M.rebuild_now(false) end

-- Debounced version (propagates the same opts)
local _last_rebuild_t = -math.huge
local _DEBOUNCE_SEC   = 0.15 -- fast, but avoids spam
function M.rebuild_debounced(opts)
    local now = (Managers.time and Managers.time:time("main")) or os.clock() or os.time()
    if (now - _last_rebuild_t) >= _DEBOUNCE_SEC then
        _last_rebuild_t = now
        return M.rebuild_now(opts)
    end
    return false
end

return M
