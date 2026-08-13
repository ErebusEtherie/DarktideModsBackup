-- File: RingHud/scripts/mods/RingHud/team/floating_marker_template.lua
local mod = get_mod("RingHud"); if not mod then return end

local C                           = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
local WM                          = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_definitions_team_nameplate")

-- View-model + appliers (move the art, not the container)
local RingHud_state_team          = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_state_team")
local Apply                       = mod:io_dofile("RingHud/scripts/mods/RingHud/team/markers/apply")

local UIResolution                = require("scripts/managers/ui/ui_resolution")

-- ############################################
-- Template fields (World Marker configuration)
-- ############################################
local template                    = {}

template.name                     = "ringhud_teammate_tile"
template.unit_node                = "j_head"
template.position_offset          = { 0, 0, 0.45 }
template.check_line_of_sight      = false
template.screen_clamp             = true
template.max_distance             = 1000
template.remove_on_death_duration = 0.25

template.size                     = { C.MARKER_SIZE_BASE[1], C.MARKER_SIZE_BASE[2] }

template.scale_settings           = {
    distance_max    = 30,
    distance_min    = 5,
    scale_from      = 0.8,
    scale_to        = 1.0,
    easing_function = nil, -- linear
}

local function _mode()
    return (mod._settings and mod._settings.team_hud_mode) or "team_hud_docked"
end

-- =========================
-- Clamp margins:
--  * Left/Right  = 0.7 × TILE_WIDTH
--  * Top/Bottom  = 0.7 × TILE_WIDTH
-- In fragment space, then normalize by 1920/1080.
-- =========================
local function _fragments()
    return UIResolution.width_fragments(), UIResolution.height_fragments() -- 1920,1080
end

local function _compute_one_tile_margins()
    local s      = (mod._settings and mod._settings.team_tiles_scale) or 1
    local fw, fh = _fragments()
    local tile_w = C.MARKER_SIZE_BASE[1] * s -- fragments

    local lr     = (tile_w * 0.7) / fw       -- normalized (0..1)
    local ud     = (tile_w * 0.7) / fh       -- normalized (0..1)

    return { left = lr, right = lr, up = ud, down = ud }
end

-- Recompute margins if scale changes or resolution changed this frame.
template._last_margin_s = nil
local function _refresh_screen_margins_if_needed()
    local s = (mod._settings and mod._settings.team_tiles_scale) or 1
    if (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.modified) or s ~= template._last_margin_s then
        template.screen_margins = _compute_one_tile_margins()
        template._last_margin_s = s
    end
end

-- Initialize clamp margins
_refresh_screen_margins_if_needed()

-- No distance fading (keep alpha fixed)
template.fade_settings = {
    default_fade    = 1,
    fade_from       = 1,
    fade_to         = 1,
    distance_max    = template.max_distance,
    distance_min    = template.max_distance,
    easing_function = math.ease_out_quad,
}

-- Helper: scale all style offsets by factor (x,y only; leave z alone)
local function _apply_offset_compensation(widget_def, factor)
    local style = widget_def and widget_def.style
    if not style then return end

    for _, st in pairs(style) do
        local off = st and st.offset
        local material_values = st and st.material_values
        local keep_material_offset = material_values and material_values.SizeThicknessOutline

        if not keep_material_offset and off and type(off[1]) == "number" and type(off[2]) == "number" then
            off[1] = off[1] * factor
            off[2] = off[2] * factor
        end
    end
end

-- (Engine looks for this exact field name in the template)
template.create_widget_defintion = function(tpl, scenegraph_id)
    _refresh_screen_margins_if_needed()

    local def = WM.build_marker_definitions(1.0, scenegraph_id)

    local s = (mod._settings and mod._settings.team_tiles_scale) or 1
    if s ~= 1 then
        _apply_offset_compensation(def, 1 / s)
    end

    return def
end

-- ############################################
-- Template lifecycle hooks
-- ############################################

function template.on_enter(widget, marker, tpl)
    marker.draw = false
    widget.alpha_multiplier = 1
    widget.visible = true
    marker._state_accum = 0
end

function template.on_exit(widget, marker, tpl)
    -- nothing special
end

-- Robust peer id extraction for this template (no pcalls)
local function _peer_id_for_player(player)
    if not player or player.__deleted then return nil end

    if type(player.peer_id) == "function" then
        local val = player:peer_id()
        if val ~= nil then return tostring(val) end
    end

    local pid = rawget(player, "peer_id")
    if type(pid) == "string" or type(pid) == "number" then
        return tostring(pid)
    end

    if type(player.unique_id) == "function" then
        local uid = player:unique_id()
        if uid ~= nil then return tostring(uid) end
    end

    if type(player.name) == "function" then
        local nm = player:name()
        if nm ~= nil then return "name:" .. tostring(nm) end
    end

    return nil
end

local _build_opts_pool = {
    player = false,
    force_show = false,
    t = 0,
    peer_id = false
}

local function _hash_state(vm)
    local hash = 0

    hash = hash + (vm.icon_only and 7 or 0)

    local nm = vm.name_markup or ""
    hash = hash + #nm * 31

    local hp = vm.hp
    if hp then
        hash = hash + (hp.hp_frac or 0) * 10000
        hash = hash + (hp.cor_frac or 0) * 10000
        hash = hash + (hp.wounds or 0) * 97
        hash = hash + (hp.bars_enabled and 13 or 0)

        local ts = hp.tough_state
        hash = hash + (
            ts == "ok" and 1
            or ts == "broken" and 2
            or ts == "overshield" and 3
            or 0
        ) * 41
    end

    local ct = vm.counters
    if ct then
        hash = hash + (ct.reserve_frac or 0) * 10000
        hash = hash + (ct.ability_secs or 0) * 100
        hash = hash + (ct.show_cd and 19 or 0)
        hash = hash + (ct.tough_int or 0) * 53
    end

    local st = vm.status
    if st then
        hash = hash + (st.show_icon and 23 or 0)

        local sk = st.kind
        hash = hash + (
            sk == "netted" and 1
            or sk == "hogtied" and 2
            or sk == "knocked_down" and 3
            or sk == "ledge_hanging" and 4
            or sk == "dead" and 5
            or sk == "pounced" and 6
            or 0
        ) * 67
    end

    local assist = vm.assist
    if assist then
        hash = hash + (assist.show and 29 or 0)
        hash = hash + (assist.amount or 0) * 1000
        hash = hash + (assist.respawn_digits and tonumber(assist.respawn_digits) or 0) * 71
    end

    local pockets = vm.pockets
    if pockets then
        hash = hash + (pockets.stimm_enabled and 37 or 0)
        hash = hash + (pockets.crate_enabled and 43 or 0)

        local stimm_icon = pockets.stimm_icon
        if stimm_icon then
            hash = hash + #stimm_icon * 11
        end

        local crate_icon = pockets.crate_icon
        if crate_icon then
            hash = hash + #crate_icon * 13
        end
    end

    return hash
end

local STATE_THROTTLE_RATE = 1 / 30 -- ~33ms

function template.update_function(parent, ui_renderer, widget, marker, tpl, dt, t)
    local unit = marker.unit
    if not (unit and Unit.alive(unit)) then
        marker.remove = true
        return
    end

    if widget.content.distance then
        marker.draw = true
    end

    _refresh_screen_margins_if_needed()

    local did_apply = false

    -- Throttle the heavy Data & Apply step
    marker._state_accum = (marker._state_accum or 0) + dt
    if marker._state_accum >= STATE_THROTTLE_RATE then
        marker._state_accum = 0

        local player_opt
        if marker.data and marker.data.player then
            player_opt = marker.data.player
        else
            local player_manager = Managers.player
            if player_manager and player_manager.player_by_unit then
                player_opt = player_manager:player_by_unit(unit)
            end
        end

        local peer_id = _peer_id_for_player(player_opt)

        _build_opts_pool.player = player_opt
        _build_opts_pool.force_show =
            mod.show_all_hud_hotkey_active == true
            and _mode() ~= "team_hud_disabled"
        _build_opts_pool.t = t
        _build_opts_pool.peer_id = peer_id

        local vm = RingHud_state_team.build(unit, marker, _build_opts_pool)

        if not (vm and vm.ok) then
            marker.remove = true
            return
        end

        local state_hash = _hash_state(vm)
        marker._last_state_hash = marker._last_state_hash or -1

        if state_hash ~= marker._last_state_hash then
            marker._last_state_hash = state_hash

            Apply.apply_all(widget, marker, vm, {
                unit = unit,
                screen_margins = template.screen_margins,
            })

            did_apply = true
        end
    end

    -- Freeze distance scaling while clamped (vanilla pattern).
    do
        local content = widget.content
        local is_clamped = content and content.is_clamped or false

        marker.ignore_scale = is_clamped

        if content then
            content.scale = is_clamped and 1 or (marker.scale or 1)
        end
    end

    if did_apply then
        widget.dirty = true
    end
end

return template
