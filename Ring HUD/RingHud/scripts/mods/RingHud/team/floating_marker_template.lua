-- File: RingHud/scripts/mods/RingHud/team/floating_marker_template.lua
local mod = get_mod("RingHud"); if not mod then return end

-- Reuse RingHud helpers where still needed in-template
local C                           = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
local WM                          = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_definitions_team_nameplate")

-- View-model + appliers (Option A: move the art, not the container)
local RingHud_state_team          = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_state_team")
local Apply                       = mod:io_dofile("RingHud/scripts/mods/RingHud/team/markers/apply")

-- Shared edge-packing module (single source of truth)
local Edge                        = (mod.team_edge_stack or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/edge_stack"))
mod.team_edge_stack               = Edge -- ensure it's published under mod.*

-- NEW: fragment-space helpers (virtual 1920×1080)
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

-- Base size for clamping (match constants)
template.size                     = { C.MARKER_SIZE_BASE[1], C.MARKER_SIZE_BASE[2] }

template.scale_settings           = {
    distance_max    = 30,
    distance_min    = 5,
    scale_from      = 0.8,
    scale_to        = 1.0,
    easing_function = nil, -- linear
}

-- Current mode helper (use cached settings table)
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
        if off and type(off[1]) == "number" and type(off[2]) == "number" then
            off[1] = off[1] * factor
            off[2] = off[2] * factor
        end
    end
end

-- Distance → scale helper (match engine’s marker scale behavior)
local function _distance_scale(dist, ss)
    local dmin, dmax = ss.distance_min or 0, ss.distance_max or 1
    local sf, st = ss.scale_from or 1, ss.scale_to or 1
    local t = 0
    if dmax > dmin then
        t = math.clamp((dist - dmin) / (dmax - dmin), 0, 1)
    end
    -- Close (t=0) -> st; Far (t=1) -> sf
    return (st + (sf - st) * t)
end

-- (Engine looks for this exact field name in the template)
template.create_widget_defintion = function(tpl, scenegraph_id)
    _refresh_screen_margins_if_needed()

    local def = WM.build_marker_definitions(1.0, scenegraph_id)

    -- Use centralized settings cache (no direct mod:get calls here).
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
    -- ensure per-marker base offsets are captured next update
    marker._edge_stack_bases = nil
    marker._edge_stack_last = { 0, 0 }
end

function template.on_exit(widget, marker, tpl)
    -- nothing special
end

-- Robust peer id extraction for this template (no pcalls)
local function _peer_id_for_player(player)
    if not player then return nil end

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

-- Main per-frame update — thin orchestrator:
--  1) capture bases (once) + ensure per-frame reset
--  2) build/apply RingHud_state_team (engine clamp stays on)
--  3) APPLY EDGE PUSH LAST (so Apply.apply_all can’t overwrite it)
function template.update_function(parent, ui_renderer, widget, marker, tpl, dt, t)
    local unit = marker.unit
    if not (unit and Unit.alive(unit)) then
        marker.remove = true
        return
    end

    if widget.content.distance then
        marker.draw = true
    end

    -- [CHANGE] Redundant frame counter increment removed.
    -- We now rely on HudElementRingHud_team_nameplate.lua to handle the
    -- mod._edge_stack_frame_id increment globally per frame.

    -- 1) bases + per-frame reset (do this BEFORE Apply touches any styles)
    _refresh_screen_margins_if_needed()
    Edge.reset_if_needed() -- uses mod._edge_stack_frame_id internally
    Edge.ensure_bases(marker, widget.style)

    -- 2) Build view-model + apply to widget
    local player_opt
    do
        if marker.data and marker.data.player then
            player_opt = marker.data.player
        else
            local pm = Managers.player
            if pm and pm.player_by_unit then
                player_opt = pm:player_by_unit(unit)
            end
        end
    end

    local pid = _peer_id_for_player(player_opt)

    local vm = RingHud_state_team.build(unit, marker, {
        player     = player_opt,
        force_show = ((mod.show_all_hud_hotkey_active == true) and (_mode() ~= "team_hud_disabled")),
        t          = t,
        peer_id    = pid,
    })

    if not (vm and vm.ok) then
        marker.remove = true
        return
    end

    Apply.apply_all(widget, marker, vm, {
        unit           = unit,
        screen_margins = template.screen_margins,
    })

    -- Freeze distance scaling while clamped (vanilla pattern).
    do
        local content       = widget.content
        local is_clamped    = content and content.is_clamped or false
        marker.ignore_scale = is_clamped
        marker.is_clamped   = is_clamped -- allow Edge.update_push to infer edge when clamped
        if content then
            content.scale = is_clamped and 1 or (marker.scale or 1)
        end
    end

    -- 3) APPLY EDGE PUSH LAST (style-offset only; container stays clamped)
    do
        -- Our style offsets were compensated by 1/s at create time, so push in the same space.
        local s           = (mod._settings and mod._settings.team_tiles_scale) or 1
        local style_space = (s ~= 1) and (1 / s) or 1

        -- Distance factor: if clamped, freeze at 1; else compute from distance.
        local content     = widget.content
        local is_clamped  = content and content.is_clamped or false
        local dist        = (content and content.distance) or template.scale_settings.distance_min or 0
        local dscale      = is_clamped and 1 or _distance_scale(dist, template.scale_settings)
        if dscale <= 0 then dscale = 1 end

        local base_w = C.MARKER_SIZE_BASE[1]
        local base_h = C.MARKER_SIZE_BASE[2]

        -- Target on-screen gaps ~90% of a scaled tile (screen space)
        local step_screen_x = base_w * s * 0.90
        local step_screen_y = base_h * s * 0.90

        -- Use *inverse* distance scale so the on-screen gap stays constant when not clamped.
        local factor = 1 / dscale

        -- Convert to style space: multiply by our 1/s compensation and the distance factor
        local STEP_X = math.floor(step_screen_x * style_space * factor + 0.5)
        local STEP_Y = math.floor(step_screen_y * style_space * factor + 0.5)

        Edge.update_push(widget, marker, widget.style, STEP_X, STEP_Y, template.screen_margins)
    end

    widget.dirty = true
end

return template
