-- File: RingHud/scripts/mods/RingHud/core/HudElementRingHud_team_docked.lua
local mod = get_mod("RingHud"); if not mod then return end

-- UI defs for the docked team tiles
local W                             = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_definitions_team_docked")

-- Shared helpers we still need here
local U                             = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local C                             = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")

-- Option C: pure view-model + appliers
local RingHud_state_team            = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_state_team")
local Apply                         = mod:io_dofile("RingHud/scripts/mods/RingHud/team/markers/apply")

-- Simple teammate-name helper (vanilla default character name)
local Name                          = mod.team_names or mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_names")

local Definitions                   = W.build_definitions()
local HudElementRingHud_team_docked = class("HudElementRingHud_team_docked", "HudElementBase")

function HudElementRingHud_team_docked:init(parent, draw_layer, start_scale)
    HudElementRingHud_team_docked.super.init(self, parent, draw_layer, start_scale, Definitions)

    -- Mark all *team* widgets so generic writers elsewhere won't touch them.
    for name, w in pairs(self._widgets_by_name or {}) do
        if string.find(name, "^rh_team_") then
            w._ringhud_is_team_tile = true
        end
    end

    -- Floating-mode draw gates
    self._show_respawns_in_floating = false
    self._switching_any_visible = false
end

-- Small helper: apply RingHud_state_team to the tile + name widgets
local function _apply_RingHud_state_team_to_widgets(tile_w, name_w, RingHud_state_team_tbl, unit)
    if not (tile_w and RingHud_state_team_tbl) then return end

    -- Mutate the main tile from the RingHud_state_team (bars, icons, counters, etc.)
    Apply.apply_all(tile_w, nil, RingHud_state_team_tbl, { unit = unit })

    -- Name widget: delegate to applier helper
    if name_w then
        Apply.apply_name(name_w, RingHud_state_team_tbl)
    end
end

-- Helper to safely get peer ID
local function _peer_id(player)
    if not player then return nil end
    if type(player.peer_id) == "function" then
        return player:peer_id()
    end
    return rawget(player, "peer_id")
end

function HudElementRingHud_team_docked:update(dt, t, ui_renderer, render_settings, input_service)
    -- NEW: hot-rebuild docked team tiles when team_tiles_scale changes
    if mod._teamhud_needs_rebuild then
        mod._teamhud_needs_rebuild = false

        -- Re-pull constants and widgets (sizes depend on team_tiles_scale)
        C = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
        W = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_definitions_team_docked")

        -- Rebuild definitions and reinit this element with the new geometry
        Definitions = W.build_definitions()
        HudElementRingHud_team_docked.super.init(self, self._parent, self._draw_layer, self._scale, Definitions)

        -- Re-mark all team widgets
        for name, w in pairs(self._widgets_by_name or {}) do
            if string.find(name, "^rh_team_") then
                w._ringhud_is_team_tile = true
            end
        end
    end

    local s               = mod._settings or {}
    local mode            = s.team_hud_mode or "team_hud_docked"
    local mode_is_docked  = (mode == "team_hud_docked"
        or mode == "team_hud_floating_docked")
    local players         = U.sorted_teammates() -- deterministic order, excludes local player

    -- Force-show is ONLY the dedicated hotkey, never ADS; and only when team HUD isn't disabled
    local force_show_team = (mod.show_all_hud_hotkey_active == true) and (mode ~= "team_hud_disabled")

    -- In 'disabled' and 'floating_vanilla' modes: never render docked tiles
    if mode == "team_hud_disabled" or mode == "team_hud_floating_vanilla" then
        for i = 1, 3 do
            local tile_w = self._widgets_by_name[string.format("rh_team_tile_%d", i)]
            local name_w = self._widgets_by_name[string.format("rh_team_name_%d", i)]
            if tile_w then tile_w.visible = false end
            if name_w then name_w.visible = false end
        end
        self._show_respawns_in_floating = false
        self._switching_any_visible = false
        return
    end

    -- Floating-only (non-docked) path (legacy 'team_hud_floating' with respawn-only exception)
    if not mode_is_docked then
        if mode ~= "team_hud_floating" then
            for i = 1, 3 do
                local tile_w = self._widgets_by_name[string.format("rh_team_tile_%d", i)]
                local name_w = self._widgets_by_name[string.format("rh_team_name_%d", i)]
                if tile_w then tile_w.visible = false end
                if name_w then name_w.visible = false end
            end
            self._show_respawns_in_floating = false
            self._switching_any_visible = false
            return
        end

        -- Only show docked tiles while a teammate is awaiting respawn; hide otherwise.
        local any_respawns = false
        for i = 1, #players do
            local p        = players[i]
            local ally_tbl = RingHud_state_team.build(p and p.player_unit, nil, {
                player     = p,
                t          = t,
                force_show = force_show_team,
                peer_id    = _peer_id(p),
            })
            if ally_tbl
                and ally_tbl.status
                and ally_tbl.status.kind == "dead"
                and ally_tbl.assist
                and ally_tbl.assist.respawn_digits
            then
                any_respawns = true
                break
            end
        end

        self._show_respawns_in_floating = any_respawns
        self._switching_any_visible = false

        if not any_respawns then
            -- Hide all tiles/names and bail
            for i = 1, 3 do
                local tile_w = self._widgets_by_name[string.format("rh_team_tile_%d", i)]
                local name_w = self._widgets_by_name[string.format("rh_team_name_%d", i)]
                if tile_w then tile_w.visible = false end
                if name_w then name_w.visible = false end
            end
            return
        end

        -- Populate only tiles that are in respawn state
        for i = 1, 3 do
            local tile_w = self._widgets_by_name[string.format("rh_team_tile_%d", i)]
            local name_w = self._widgets_by_name[string.format("rh_team_name_%d", i)]
            if not tile_w or not name_w then goto continue end

            tile_w._ringhud_is_team_tile = true
            name_w._ringhud_is_team_tile = true

            local player = players[i]
            if not player then
                tile_w.visible = false
                name_w.visible = false
                goto continue
            end

            local unit        = player.player_unit

            -- Compose plain vanilla teammate name
            local name_str    = Name.default(player)
            local fake_marker = { data = { rh_name_composed = name_str } }

            local ally_tbl    = RingHud_state_team.build(unit, fake_marker, {
                player     = player,
                t          = t,
                force_show = force_show_team,
                peer_id    = _peer_id(player),
            })

            local show_this   = ally_tbl
                and ally_tbl.status
                and (ally_tbl.status.kind == "dead")
                and (ally_tbl.assist and ally_tbl.assist.respawn_digits)

            tile_w.visible    = show_this and true or false
            name_w.visible    = show_this and true or false
            if not show_this then goto continue end

            _apply_RingHud_state_team_to_widgets(tile_w, name_w, ally_tbl, unit)

            ::continue::
        end

        -- DRAW AFTER applying RingHud_state_team mutations this frame
        HudElementRingHud_team_docked.super.update(self, dt, t, ui_renderer, render_settings, input_service)
        return
    end

    -- Docked (normal and "floating_docked")
    self._show_respawns_in_floating = false
    self._switching_any_visible = false

    for i = 1, 3 do
        local tile_wname = string.format("rh_team_tile_%d", i)
        local name_wname = string.format("rh_team_name_%d", i)

        local tile_w = self._widgets_by_name[tile_wname]
        local name_w = self._widgets_by_name[name_wname]
        if not tile_w or not name_w then goto continue end

        tile_w._ringhud_is_team_tile = true
        name_w._ringhud_is_team_tile = true

        local player = players[i]
        if not player then
            tile_w.visible = false
            name_w.visible = false
            goto continue
        end

        local unit     = player.player_unit

        -- Pass nil marker to allow decorations (Who Are You, True Level) on docked tiles
        local ally_tbl = RingHud_state_team.build(unit, nil, {
            player     = player,
            t          = t,
            force_show = force_show_team,
            peer_id    = _peer_id(player),
        })

        -- Safety: if state can't be built (or isn't ok), hide this tile immediately.
        if not (ally_tbl and ally_tbl.ok) then
            tile_w.visible = false
            name_w.visible = false
            goto continue
        end

        tile_w.visible = true
        name_w.visible = true

        _apply_RingHud_state_team_to_widgets(tile_w, name_w, ally_tbl, unit)

        ::continue::
    end

    -- DRAW AFTER applying RingHud_state_team mutations this frame
    HudElementRingHud_team_docked.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

-- Gate rendering entirely when not docked (even if element is present)
function HudElementRingHud_team_docked:draw(dt, t, ui_renderer, render_settings, input_service)
    local s    = mod._settings or {}
    local mode = s.team_hud_mode or "team_hud_docked"

    if not (mode == "team_hud_docked"
            or mode == "team_hud_floating_docked")
        and not self._show_respawns_in_floating
    then
        return
    end

    return HudElementRingHud_team_docked.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudElementRingHud_team_docked
