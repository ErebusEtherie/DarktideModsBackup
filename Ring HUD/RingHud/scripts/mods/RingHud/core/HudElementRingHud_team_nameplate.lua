-- File: RingHud/scripts/mods/RingHud/core/HudElementRingHud_team_nameplate.lua
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
local C                        = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")

-- Central teammate-name helper (vanilla name + slot-tinted markup)
local Name                     = mod.team_names or mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_names")

-- Visibility helpers (kept for other uses)
mod.team_visibility            = mod.team_visibility or mod:io_dofile("RingHud/scripts/mods/RingHud/team/visibility")
local V                        = mod.team_visibility

-- Ensure a central, scale-aware step is available for the template (optional override via settings)
mod.EDGE_STACK_GAP             = mod.EDGE_STACK_GAP or C.TILE_SIZE

----------------------------------------------------------------
-- Mode helpers
----------------------------------------------------------------
-- "Any floating-related" modes (used for hijacking + resolution refresh)
local function _mode_is_floating()
    local m = mod._settings and mod._settings.team_hud_mode
    return m == "team_hud_floating"
        or m == "team_hud_floating_docked"
        or m == "team_hud_floating_vanilla"
        or m == "team_hud_floating_thin"
end

-- Setting gate: are floating nameplate names enabled by team_name_icon?
local function _floating_name_setting_enabled()
    local s = mod._settings and mod._settings.team_name_icon or ""

    return s == "name1_icon1_status1"
        or s == "name1_icon1_status0"
        or s == "name1_icon0_status1"
        or s == "name1_icon0_status0"
end

----------------------------------------------------------------
-- true_level compat bucket helper (harmless even if TL unused)
----------------------------------------------------------------
local function _ensure_vanilla_nameplate_buckets(hewm)
    if not hewm or not hewm._markers_by_type then return end
    local bt            = hewm._markers_by_type
    bt.nameplate_party  = bt.nameplate_party or {}
    bt.nameplate_combat = bt.nameplate_combat or {}
end

local function _my_player()
    local pm = Managers.player
    if not pm or not pm.local_player_safe then return nil end
    return pm:local_player_safe(1)
end

local function _player_for_unit(unit)
    local pm = Managers.player
    if not pm or not unit or not Unit.alive(unit) or not pm.players then return nil end
    local list = pm:players()
    if type(list) ~= "table" then return nil end
    for _, p in pairs(list) do
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

    -- Any floating-related mode ⇒ hijack.
    if _mode_is_floating() then
        return true
    end

    return false
end

-- Light refresh cadence for marker name
local function _name_refresh_interval()
    -- Simple fixed interval; central Name helper handles tinting/markup.
    return 1.0
end

-- Compose teammate name for marker data:
-- Uses Name.default(player, "floating"), which returns slot-tinted markup.
-- The optional "floating" context lets compat (e.g. who_are_you) suppress
-- docked-only additions (account tags, TL, etc.) for nameplates.
local function _compose_name_for_marker_data(player)
    if not player then
        return ""
    end

    -- Extra arguments are ignored by older Name.default implementations.
    local text = Name.default and Name.default(player, "floating") or ""

    if type(text) ~= "string" or text == "" then
        text = "?"
    end

    return text
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
        local tpl = mod:io_dofile("RingHud/scripts/mods/RingHud/team/floating_marker_template")
        if tpl and tpl.name == "ringhud_teammate_tile" then
            _sanitize_fade_settings_on_tpl(tpl)
            mt[tpl.name] = tpl
        end
    end
    -- Also sanitize any other RingHud templates that may have been registered elsewhere (e.g. item tracker).
    _sanitize_all_ringhud_templates(hewm)

    -- Ensure vanilla buckets exist (used by TL and others)
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
                for k in pairs(list) do k = nil end
            end
        end
    end
end

----------------------------------------------------------------
-- Resolution change watcher (once per frame via HEWM:update)
-- We rely on the engine's own flag instead of sampling pixels.
----------------------------------------------------------------
local function _watch_resolution_and_refresh()
    if not _mode_is_floating() then return end
    if RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.modified then
        _refresh_existing_nameplates()
    end
end

----------------------------------------------------------------
-- Marker name refresh (low-frequency)
-- Now runs in ANY floating-related mode
----------------------------------------------------------------
local function _refresh_ringhud_marker_names(self_hewm)
    if not _mode_is_floating() then return end
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
            -- Safety: ensure header_text exists even before first refresh
            local w  = marker.widget
            local wc = w and w.content
            if wc and wc.header_text == nil then
                wc.header_text = ""
            end
            return
        end

        -- Compose teammate name (slot-coloured markup string)
        local text = _compose_name_for_marker_data(player)

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

-- Propagate settings to the name text field.
-- If names are disabled via setting (e.g. name0), force the text blank.
-- Otherwise, leave it alone so the RingHud state/apply logic can set the clean name.
local function _propagate_header_to_name_text(self_hewm)
    if not self_hewm or not self_hewm._markers_by_type then return end
    local list = self_hewm._markers_by_type.ringhud_teammate_tile
    if not list or type(list) ~= "table" then return end

    local names_enabled = _floating_name_setting_enabled()

    local function each(tbl, fn)
        if #tbl > 0 then for i = 1, #tbl do fn(tbl[i]) end else for _, v in pairs(tbl) do fn(v) end end
    end

    each(list, function(marker)
        local w  = marker and marker.widget
        local wc = w and w.content
        if not wc then return end

        if not names_enabled then
            -- Setting disables floating names: force the rendered name text to blank.
            if wc.name_text_value ~= "" then
                wc.name_text_value = ""
                if w then w.dirty = true end
            end
            return
        end

        -- Do NOT overwrite name_text_value with header_text.
        -- header_text is used by other mods (e.g. True Level) to inject data we don't want on floating tiles.
        -- RingHud's Apply system handles setting name_text_value correctly.
    end)
end

-- Ensure the name-text pass stays visible; we rely on the text being blank
-- (from _propagate_header_to_name_text) when the setting disables names.
local function _apply_floating_name_visibility(self_hewm)
    if not self_hewm or not self_hewm._markers_by_type then return end
    local list = self_hewm._markers_by_type.ringhud_teammate_tile
    if not list or type(list) ~= "table" then return end

    local function each(tbl, fn)
        if #tbl > 0 then for i = 1, #tbl do fn(tbl[i]) end else for _, v in pairs(tbl) do fn(v) end end
    end

    each(list, function(marker)
        local widget = marker and marker.widget
        local style  = widget and widget.style
        if not style then return end

        local pass_style = style.name_text or style.name_text_style
        if pass_style and pass_style.visible == false then
            pass_style.visible = true
            widget.dirty = true
        end
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

                -- Redirect mission teammate nameplates to our RingHud template
                if _should_hijack_nameplate(marker_type, unit) then
                    data = data or {}
                    if data.player == nil then
                        data.player = _player_for_unit(unit)
                    end

                    -- Seed a composed name (slot-tinted markup) always.
                    local seeded = _compose_name_for_marker_data(data.player)
                    if seeded and seeded ~= "" then
                        data.rh_name_composed = seeded
                        data.header_text      = seeded
                    else
                        data.header_text = data.header_text or ""
                    end

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
                        for k in pairs(list) do k = nil end
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

                    _watch_resolution_and_refresh()
                    _refresh_ringhud_marker_names(self_hewm)

                    -- Mirror header_text into the text we actually render (setting-gated).
                    _propagate_header_to_name_text(self_hewm)

                    -- Ensure the pass is visible; text content handles setting-based visibility.
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

                    _watch_resolution_and_refresh()
                    _refresh_ringhud_marker_names(self_hewm)
                    _propagate_header_to_name_text(self_hewm)
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
        -- Any layout change: tear down existing plates so the engine re-adds them
        -- under the new mode (floating vs non-floating, vanilla vs RingHud, etc.).
        _refresh_existing_nameplates()
    elseif setting_id == "team_tiles_scale" then
        if type(mod.recompute_edge_marker_size) == "function" then
            mod.recompute_edge_marker_size()
        else
            local C2 = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
            if C2 and type(C2.recompute_edge_marker_size) == "function" then
                C2.recompute_edge_marker_size()
            end
        end
        mod.EDGE_STACK_GAP = C.TILE_SIZE
        if _mode_is_floating() then
            _refresh_existing_nameplates()
        end
    elseif setting_id == "team_hp_bar" or
        setting_id == "team_munitions" or
        setting_id == "team_pockets" then
        if _mode_is_floating() then
            _refresh_existing_nameplates()
        end
    end
end

function mod.floating_manager.update(_dt) end

return mod.floating_manager
