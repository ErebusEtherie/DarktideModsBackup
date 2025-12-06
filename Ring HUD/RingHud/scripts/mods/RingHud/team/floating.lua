-- File: RingHud/scripts/mods/RingHud/team/floating.lua
-- Note: Compatible with Option-A edge stacking (style-offset pushes). This file does NOT
-- adjust widget.root offsets; it only hijacks nameplates to our template and handles refresh.
local mod = get_mod("RingHud")
if not mod then return {} end

-- Expose this module so RingHud.lua can call .on_hewm_ready(...)
mod.floating_manager           = mod.floating_manager or {}

-- Shared state
mod._deferred_marker_additions = mod._deferred_marker_additions or {}
mod._tracked_item_units        = mod._tracked_item_units or mod:persistent_table("tracked_item_units")

-- Frame counter for edge-stacker resets (incremented once per HEWM:update)
mod._edge_stack_frame_id       = mod._edge_stack_frame_id or 0

----------------------------------------------------------------
-- Imports (sizes / settings constants)
----------------------------------------------------------------
local C                        = mod:io_dofile("RingHud/scripts/mods/RingHud/team/constants")
-- Load the name cache for side-effects (registers mod.name_cache).
mod:io_dofile("RingHud/scripts/mods/RingHud/team/name_cache")

-- Visibility helpers (kept for other uses; not used by name-gate anymore)
mod.team_visibility = mod.team_visibility or mod:io_dofile("RingHud/scripts/mods/RingHud/team/visibility")
local V             = mod.team_visibility

-- UI settings (require once; avoid doing it in hot paths)
local UISettings    = require("scripts/settings/ui/ui_settings")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

-- Ensure a central, scale-aware step is available for the template (optional override via settings)
mod.EDGE_STACK_GAP  = mod.EDGE_STACK_GAP or C.TILE_SIZE

----------------------------------------------------------------
-- Global resolution cache (updated when we detect a change)
----------------------------------------------------------------
mod._edge_res_cache = mod._edge_res_cache or { w = 1920, h = 1080 }

-- "Any floating-related" modes (used for hijacking + resolution refresh)
local function _mode_is_floating()
    local m = mod._settings.team_hud_mode
    return m == "team_hud_floating"
        or m == "team_hud_floating_docked"
        or m == "team_hud_floating_vanilla"
        or m == "team_hud_icons_vanilla"
        or m == "team_hud_icons_docked"
end

-- STRICT floating (used for name composition/visibility)
local function _mode_is_floating_strict()
    local m = mod._settings and mod._settings.team_hud_mode
    return m == "team_hud_floating"
end

-- ─────────────────────────────────────────────────────────────
-- Floating name text visibility (visible-but-blank strategy)
-- * ONLY populate/visible when team_hud_mode == "team_hud_floating"
-- * All other modes → ALWAYS blank ("")
-- * No interlude / force-show / ADS-force-show overrides.
-- ─────────────────────────────────────────────────────────────
local function _should_show_floating_name_text()
    return _mode_is_floating_strict()
end

-- true_level compat: keep vanilla buckets non-nil
local function _ensure_vanilla_nameplate_buckets(hewm)
    if not hewm or not hewm._markers_by_type then return end
    local bt            = hewm._markers_by_type
    bt.nameplate_party  = bt.nameplate_party or {}
    bt.nameplate_combat = bt.nameplate_combat or {}
end

local function _my_player()
    local pm = Managers.player
    if not pm then return nil end
    return pm:local_player_safe(1)
end

local function _player_for_unit(unit)
    local pm = Managers.player
    if not pm or not unit or not Unit.alive(unit) then return nil end
    for _, p in pairs(pm:players() or {}) do
        if p and p.player_unit == unit then
            return p
        end
    end
    return nil
end

-- Hijack BOTH mission teammate plate types so we always render our floating tiles at the edge.
local HIJACKABLE_TYPES = { nameplate_party = true, nameplate_combat = true }

-- Should we redirect this vanilla nameplate to our RingHud template?
local function _should_hijack_nameplate(marker_type, unit)
    if not HIJACKABLE_TYPES[marker_type] then return false end
    if not unit or not Unit.alive(unit) then return false end

    local lp = _my_player()
    if not lp or unit == lp.player_unit then return false end
    if _player_for_unit(unit) == nil then return false end -- only hijack teammates

    -- Any floating-related mode (including icons_* that still use HEWM) => hijack.
    if _mode_is_floating() then
        return true
    end

    return false
end

-- Slot tint (ARGB-255) for a player/slot index
local function _slot_tint_for_player(player, index_fallback)
    local slot_colors = UISettings.player_slot_colors or UIHudSettings
    local idx = (player and player.slot and player:slot()) or index_fallback or 1
    return (slot_colors and slot_colors[idx]) or { 255, 255, 255, 255 } -- TODO Color
end

-- Light refresh cadence for marker name (aligned with cache)
local function _name_refresh_interval()
    local nc = rawget(mod, "name_cache")
    return (nc and nc._refresh_interval_s) or 1.25
end

-- Seed/update a marker's composed name using the cache (no direct WAY/TL polling)
local function _compose_name_for_marker_data(player, slot_tint_argb255)
    local nc = rawget(mod, "name_cache")
    if not nc or not nc.compose_team_name then
        return nil
    end
    local ok, text = pcall(nc.compose_team_name, nc, player, slot_tint_argb255)
    if ok and text and text ~= "" then
        return text
    end
    return nil
end

----------------------------------------------------------------
-- Fade-settings sanitizer (prevents engine crash on nil easing / NaN fraction)
----------------------------------------------------------------
local function _sanitize_fade_settings_on_tpl(tpl)
    if not tpl or type(tpl) ~= "table" then return end
    local fs = tpl.fade_settings
    if not fs then
        tpl.fade_settings = {
            default_fade    = 1,
            fade_from       = 1,
            fade_to         = 1,
            distance_min    = 0,
            distance_max    = tpl.max_distance or 1000,
            easing_function = math.ease_out_quad,
        }
        return
    end

    fs.default_fade = (fs.default_fade ~= nil) and fs.default_fade or 1
    fs.fade_from    = (fs.fade_from ~= nil) and fs.fade_from or 1
    fs.fade_to      = (fs.fade_to ~= nil) and fs.fade_to or 1
    fs.distance_min = (fs.distance_min ~= nil) and fs.distance_min or 0
    fs.distance_max = (fs.distance_max ~= nil) and fs.distance_max or (tpl.max_distance or 1000)
    if fs.distance_max == fs.distance_min then
        -- Prevent 0/0 in engine fade fraction.
        fs.distance_min = math.max(0, fs.distance_min - 0.001)
    end
    fs.easing_function = fs.easing_function or math.ease_out_quad
end

local function _sanitize_all_ringhud_templates(hewm)
    if not hewm or not hewm._marker_templates then return end
    for key, tpl in pairs(hewm._marker_templates) do
        if type(key) == "string" and (key:match("^RingHud_") or key == "ringhud_teammate_tile") then
            _sanitize_fade_settings_on_tpl(tpl)
        end
    end
end

-- Ensure our RingHud floating tile template is registered in HEWM.
local function _ensure_ringhud_template(hewm)
    if not hewm or not hewm._marker_templates then return end
    local mt = hewm._marker_templates
    if not mt.ringhud_teammate_tile then
        local ok, tpl = pcall(mod.io_dofile, mod, "RingHud/scripts/mods/RingHud/team/floating_marker_template")
        if ok and tpl and tpl.name == "ringhud_teammate_tile" then
            _sanitize_fade_settings_on_tpl(tpl)
            mt[tpl.name] = tpl
        end
    end
    -- Also sanitize any other RingHud templates that may have been registered elsewhere (e.g. item tracker).
    _sanitize_all_ringhud_templates(hewm)

    -- Ensure vanilla buckets exist for true_level
    _ensure_vanilla_nameplate_buckets(hewm)
end

-- Remove existing combat/party plates so the engine re-adds them next frame (hitting our redirect).
local function _refresh_existing_nameplates()
    local hewm = rawget(mod, "_hewm_world_markers")
    if not hewm or not hewm._markers_by_type then return end

    -- Ensure buckets exist before we start removing
    _ensure_vanilla_nameplate_buckets(hewm)

    for marker_type, list in pairs(hewm._markers_by_type) do
        if (marker_type == "nameplate_party" or marker_type == "nameplate_combat")
            and type(list) == "table" then
            -- list can be array-like or keyed; clear robustly
            if #list > 0 then
                for i = #list, 1, -1 do
                    local m = list[i]
                    if m and m.unit then
                        Managers.event:trigger("remove_world_marker_by_unit", marker_type, m.unit)
                    end
                    list[i] = nil
                end
            else
                for _, m in pairs(list) do
                    if m and m.unit then
                        Managers.event:trigger("remove_world_marker_by_unit", marker_type, m.unit)
                    end
                end
                for k in pairs(list) do list[k] = nil end
            end
        end
    end
end

----------------------------------------------------------------
-- Resolution change watcher (once per frame via HEWM:update)
----------------------------------------------------------------
local function _read_renderer_resolution(self_hewm, ui_renderer)
    local w, h = nil, nil
    if type(ui_renderer) == "table" then
        local r = rawget(ui_renderer, "resolution")
        if type(r) == "table" then w, h = r[1], r[2] end
    end
    if (not w or not h) and self_hewm and type(self_hewm._ui_renderer) == "table" then
        local r = rawget(self_hewm._ui_renderer, "resolution")
        if type(r) == "table" then w, h = r[1], r[2] end
    end
    if (not w or not h) and _G.RESOLUTION_LOOKUP then
        w = _G.RESOLUTION_LOOKUP.width or _G.RESOLUTION_LOOKUP.res_w or _G.RESOLUTION_LOOKUP[1] or w
        h = _G.RESOLUTION_LOOKUP.height or _G.RESOLUTION_LOOKUP.res_h or _G.RESOLUTION_LOOKUP[2] or h
    end
    if not w or not h then
        local c = mod._edge_res_cache
        return c.w, c.h
    end
    return w, h
end

local function _watch_resolution_and_refresh(self_hewm, ui_renderer)
    if not _mode_is_floating() then return end
    local w, h = _read_renderer_resolution(self_hewm, ui_renderer)
    local c = mod._edge_res_cache
    if w ~= c.w or h ~= c.h then
        c.w, c.h = w, h
        _refresh_existing_nameplates()
    end
end

----------------------------------------------------------------
-- Marker name refresh (low-frequency; uses cache)
-- STRICT: only run in team_hud_floating
----------------------------------------------------------------
local function _refresh_ringhud_marker_names(self_hewm)
    if not _mode_is_floating_strict() then return end
    if not self_hewm or not self_hewm._markers_by_type then return end

    local list = self_hewm._markers_by_type.ringhud_teammate_tile
    if not list or type(list) ~= "table" then return end

    local now = (Managers.time and Managers.time:time("ui")) or (Managers.time and Managers.time:time("gameplay")) or
        os.clock()
    local interval = _name_refresh_interval()

    local function _each(tbl, fn)
        if #tbl > 0 then
            for i = 1, #tbl do fn(tbl[i]) end
        else
            for _, v in pairs(tbl) do fn(v) end
        end
    end

    _each(list, function(marker)
        if not marker or not marker.data then return end
        local data   = marker.data
        local player = rawget(data, "player")
        if not player then return end

        local next_at = rawget(marker, "_rh_name_next_refresh_at") or 0
        if now < next_at then
            -- TL safety: ensure header_text exists even before first refresh
            local w  = marker.widget
            local wc = w and w.content
            if wc and wc.header_text == nil then
                wc.header_text = ""
            end
            return
        end

        -- Compose (cached) with current slot tint
        local tint = _slot_tint_for_player(player)
        local text = _compose_name_for_marker_data(player, tint)

        if text and text ~= "" then
            -- Update RingHud seed (for our own logic)
            data.rh_name_composed = text
            data.header_text      = text

            -- Only SEED widget.header_text if it's empty; never overwrite non-empty
            local w               = marker.widget
            local wc              = w and w.content
            if wc and (wc.header_text == nil or wc.header_text == "") then
                wc.header_text = text
            end
        else
            -- Ensure a string exists; avoid nil for external consumers
            local w  = marker.widget
            local wc = w and w.content
            if wc and wc.header_text == nil then
                wc.header_text = ""
            end
        end

        marker._rh_name_next_refresh_at = now + interval
    end)
end

-- Mirror header_text into the text field our widget renders (name_text_value),
-- but in hidden modes hard-blank BOTH fields to defeat late writers.
local function _propagate_header_to_name_text(self_hewm)
    if not self_hewm or not self_hewm._markers_by_type then return end
    local list = self_hewm._markers_by_type.ringhud_teammate_tile
    if not list or type(list) ~= "table" then return end

    local show = _should_show_floating_name_text()

    local function each(tbl, fn)
        if #tbl > 0 then for i = 1, #tbl do fn(tbl[i]) end else for _, v in pairs(tbl) do fn(v) end end
    end

    each(list, function(marker)
        local w  = marker and marker.widget
        local wc = w and w.content
        if not wc then return end

        if not show then
            local dirt = false
            if wc.name_text_value ~= "" then
                wc.name_text_value = ""; dirt = true
            end
            if wc.header_text ~= "" then
                wc.header_text = ""; dirt = true
            end
            if dirt and w then w.dirty = true end
            return
        end

        local ht = wc.header_text
        if type(ht) == "string" and wc.name_text_value ~= ht then
            wc.name_text_value = ht
            if w then w.dirty = true end
        end
    end)
end

-- Final enforcement of the "visible-but-blank" rule (keeps style visible, controls content).
local function _apply_floating_name_visibility(self_hewm)
    if not self_hewm or not self_hewm._markers_by_type then return end
    local list = self_hewm._markers_by_type.ringhud_teammate_tile
    if not list or type(list) ~= "table" then return end

    local show_text = _should_show_floating_name_text()

    local function each(tbl, fn)
        if #tbl > 0 then for i = 1, #tbl do fn(tbl[i]) end else for _, v in pairs(tbl) do fn(v) end end
    end

    each(list, function(marker)
        local widget = marker and marker.widget
        local wc     = widget and widget.content
        local style  = widget and widget.style
        if not wc or not style then return end

        -- Ensure the pass itself stays visible (template may assume true)
        local pass_style = style.name_text or style.name_text_style
        if pass_style and pass_style.visible == false then
            pass_style.visible = true
            widget.dirty = true
        end

        -- Enforce desired text content
        local want = show_text and (wc.header_text or "") or ""
        local dirt = false
        if wc.name_text_value ~= want then
            wc.name_text_value = want; dirt = true
        end
        if not show_text and wc.header_text ~= "" then
            wc.header_text = ""; dirt = true
        end
        if dirt then widget.dirty = true end
    end)
end

----------------------------------------------------------------
-- Unified hook (ONLY this file hooks event_add_world_marker_unit and update)
----------------------------------------------------------------
function mod.floating_manager.install()
    if CLASS and CLASS.HudElementWorldMarkers and not mod._floating_hijack_hooked then
        mod:hook(CLASS.HudElementWorldMarkers, "event_add_world_marker_unit",
            function(func, self_hewm, marker_type, unit, callback, data)
                _ensure_ringhud_template(self_hewm)
                _sanitize_all_ringhud_templates(self_hewm)
                _ensure_vanilla_nameplate_buckets(self_hewm)

                -- Proximity watcher (ALL syringes via interaction)
                if marker_type == "interaction" and unit and Unit.alive(unit) then
                    local pickup_name = Unit.get_data(unit, "pickup_type")

                    -- Track all four stimm types without creating a visible RingHud marker.
                    local SYRINGE_TYPES = {
                        syringe_corruption_pocketable    = true,
                        syringe_ability_boost_pocketable = true,
                        syringe_power_boost_pocketable   = true,
                        syringe_speed_boost_pocketable   = true,
                    }

                    if SYRINGE_TYPES[pickup_name] then
                        -- Tag for RingHud proximity tracking
                        Unit.set_data(unit, "rh_tracking", true)
                        mod._tracked_item_units[unit] = unit

                        -- Defer adding the invisible tracker marker; ProximitySystem will process this queue.
                        if not mod._deferred_marker_additions[unit] then
                            mod._deferred_marker_additions[unit] = { rh_pickup_name = pickup_name }
                        end
                    end
                end

                -- Redirect mission teammate nameplates to our template
                if _should_hijack_nameplate(marker_type, unit) then
                    data = data or {}
                    if data.player == nil then
                        data.player = _player_for_unit(unit)
                    end

                    -- Seed a composed name (WAY+TL via cache) but only expose it in strict mode.
                    local tint   = _slot_tint_for_player(data.player)
                    local seeded = _compose_name_for_marker_data(data.player, tint)
                    if seeded and seeded ~= "" then
                        data.rh_name_composed = seeded
                        data.header_text      = _mode_is_floating_strict() and seeded or ""
                    else
                        data.header_text = _mode_is_floating_strict() and (data.header_text or "") or ""
                    end
                    data._rh_slot_tint   = tint
                    data._rh_seeded_name = true

                    return func(self_hewm, "ringhud_teammate_tile", unit, callback, data)
                end

                return func(self_hewm, marker_type, unit, callback, data)
            end
        )
        mod._floating_hijack_hooked = true
    end

    local function prepass_merge_safety(self_hewm)
        _ensure_vanilla_nameplate_buckets(self_hewm)

        local DEFAULT_EASING = (math and math.ease_out_quad) or function(x) return x end
        local tmpls = self_hewm._marker_templates
        if tmpls then
            for _, tpl in pairs(tmpls) do
                local fs = tpl and tpl.fade_settings
                if fs and fs.easing_function == nil then
                    fs.easing_function = DEFAULT_EASING
                end
            end
        end

        local templates = self_hewm._marker_templates or {}
        local by_type   = self_hewm._markers_by_type or {}
        for marker_type, list in pairs(by_type) do
            if type(marker_type) == "string" and marker_type:sub(1, 8) == "ringhud_" then
                if not templates[marker_type] and type(list) == "table" and next(list) ~= nil then
                    if #list > 0 then
                        for i = #list, 1, -1 do
                            local m = list[i]
                            if m and m.unit then
                                Managers.event:trigger("remove_world_marker_by_unit", marker_type, m.unit)
                            end
                            list[i] = nil
                        end
                    else
                        for _, m in pairs(list) do
                            if m and m.unit then
                                Managers.event:trigger("remove_world_marker_by_unit", marker_type, m.unit)
                            end
                        end
                        for k in pairs(list) do list[k] = nil end
                    end
                end
            end
        end
    end

    if CLASS and CLASS.HudElementWorldMarkers and not mod._hewm_update_hooked then
        if CLASS.HudElementWorldMarkers.update then
            mod:hook(CLASS.HudElementWorldMarkers, "update",
                function(func, self_hewm, dt, t, ui_renderer, render_settings, input_service, ...)
                    prepass_merge_safety(self_hewm)

                    -- NEW: tick a per-frame id for the edge stacker (templates will reset once per frame)
                    mod._edge_stack_frame_id = (mod._edge_stack_frame_id or 0) + 1

                    local ret = func(self_hewm, dt, t, ui_renderer, render_settings, input_service, ...)

                    _watch_resolution_and_refresh(self_hewm, ui_renderer)
                    _refresh_ringhud_marker_names(self_hewm)

                    -- After everyone (including TL) has had a chance to touch header_text,
                    -- mirror it into the text we actually render (or blank while hidden).
                    _propagate_header_to_name_text(self_hewm)

                    -- Enforce "visible-but-blank" rule
                    _apply_floating_name_visibility(self_hewm)

                    return ret
                end)
            mod._hewm_update_hooked = true
        elseif CLASS.HudElementWorldMarkers.update_function then
            mod:hook(CLASS.HudElementWorldMarkers, "update_function",
                function(func, self_hewm, ui_renderer, dt, t, ...)
                    prepass_merge_safety(self_hewm)

                    -- NEW: tick a per-frame id for the edge stacker (templates will reset once per frame)
                    mod._edge_stack_frame_id = (mod._edge_stack_frame_id or 0) + 1

                    local ret = func(self_hewm, ui_renderer, dt, t, ...)

                    _watch_resolution_and_refresh(self_hewm, ui_renderer)
                    _refresh_ringhud_marker_names(self_hewm)
                    _propagate_header_to_name_text(self_hewm)

                    -- Enforce "visible-but-blank" rule
                    _apply_floating_name_visibility(self_hewm)

                    return ret
                end)
            mod._hewm_update_hooked = true
        end
    end
end

-- Called by RingHud.lua’s HEWM init hook
function mod.floating_manager.on_hewm_ready(hewm_instance)
    mod._hewm_world_markers = hewm_instance
    _sanitize_all_ringhud_templates(hewm_instance)
    _ensure_vanilla_nameplate_buckets(hewm_instance)
    if _mode_is_floating() then
        _refresh_existing_nameplates()
    end
end

function mod.floating_manager.set_enabled(is_enabled)
    mod._floating_enabled = (is_enabled == true)
    if mod._floating_enabled then
        _refresh_existing_nameplates()
    end
end

-- Optional helper: force all active floating markers to refresh their names next frame.
function mod.floating_manager.bump_names()
    local hewm = rawget(mod, "_hewm_world_markers")
    local list = hewm and hewm._markers_by_type and hewm._markers_by_type.ringhud_teammate_tile
    if not list then return end

    local function each(tbl, fn)
        if #tbl > 0 then for i = 1, #tbl do fn(tbl[i]) end else for _, v in pairs(tbl) do fn(v) end end
    end

    each(list, function(marker)
        if marker then marker._rh_name_next_refresh_at = 0 end
    end)
end

-- Called by RingHud.lua’s single global on_setting_changed(...)
function mod.floating_manager.apply_settings(setting_id)
    if setting_id == "team_hud_mode" then
        if _mode_is_floating() then
            _refresh_existing_nameplates()
        end
    elseif setting_id == "team_tiles_scale" then
        if type(mod.recompute_edge_marker_size) == "function" then
            pcall(mod.recompute_edge_marker_size)
        else
            local ok, C2 = pcall(mod.io_dofile, mod, "RingHud/scripts/mods/RingHud/team/constants")
            if ok and C2 and C2.recompute_edge_marker_size then
                pcall(C2.recompute_edge_marker_size)
            end
        end
        mod.EDGE_STACK_GAP = C.TILE_SIZE
        if _mode_is_floating() then
            _refresh_existing_nameplates()
        end
    elseif setting_id == "team_hp_bar" or
        setting_id == "team_munitions" or
        setting_id == "team_pockets" or
        setting_id == "team_counters" then
        if _mode_is_floating() then
            _refresh_existing_nameplates()
        end
    end
end

function mod.floating_manager.update(_dt) end

return mod.floating_manager
