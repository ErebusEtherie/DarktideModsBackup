-- File: RingHud/scripts/mods/RingHud/core/HudElementRingHud_team_docked.lua
local mod = get_mod("RingHud"); if not mod then return end

local UIWidget                      = require("scripts/managers/ui/ui_widget")

local W                             = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_definitions_team_docked")

local U                             = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local C                             = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")

local RingHud_state_team            = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_state_team")
local Apply                         = mod:io_dofile("RingHud/scripts/mods/RingHud/team/markers/apply")

local Name                          = mod.team_names or mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_names")

local Definitions                   = W.build_definitions()
local HudElementRingHud_team_docked = class("HudElementRingHud_team_docked", "HudElementBase")

local STATE_THROTTLE_RATE           = 1 / 30 -- ~33ms

local function _peer_id(player)
    if not player or player.__deleted then return nil end
    if type(player.peer_id) == "function" then
        return player:peer_id()
    end
    return rawget(player, "peer_id")
end

local function _apply_RingHud_state_team_to_widgets(tile_w, name_w, RingHud_state_team_tbl, unit)
    if not (tile_w and RingHud_state_team_tbl) then return end

    Apply.apply_all(tile_w, nil, RingHud_state_team_tbl, { unit = unit })

    if name_w then
        Apply.apply_name(name_w, RingHud_state_team_tbl)
    end
end

function HudElementRingHud_team_docked:init(parent, draw_layer, start_scale)
    HudElementRingHud_team_docked.super.init(self, parent, draw_layer, start_scale, Definitions)

    self._tile_widget_names = { "rh_team_tile_1", "rh_team_tile_2", "rh_team_tile_3" }
    self._name_widget_names = { "rh_team_name_1", "rh_team_name_2", "rh_team_name_3" }

    for name, w in pairs(self._widgets_by_name or {}) do
        if string.find(name, "^rh_team_") then
            w._ringhud_is_team_tile = true
        end
    end

    self._show_respawns_in_floating = false
    self._switching_any_visible     = false

    self._state_rebuild_dt_accum    = 0
end

-- Override base _draw_widgets to skip widget.visible==false entirely.
-- Base calls UIWidget.draw on every widget; engine respects .visible internally,
-- but the FFI call and Lua pass loop still run.
function HudElementRingHud_team_docked:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    local widgets = self._widgets
    if not widgets then return end

    local draw_widget = UIWidget.draw

    for i = 1, #widgets do
        local widget = widgets[i]

        if widget and widget.visible ~= false then
            draw_widget(widget, ui_renderer)
        end
    end
end

local function _hide_all_widgets(self_elem)
    local wbn = self_elem._widgets_by_name
    local twn = self_elem._tile_widget_names
    local nwn = self_elem._name_widget_names

    for i = 1, 3 do
        local tile_w = wbn[twn[i]]
        local name_w = wbn[nwn[i]]

        if tile_w then
            tile_w.visible = false
        end

        if name_w then
            name_w.visible = false
        end
    end
end

function HudElementRingHud_team_docked:update(dt, t, ui_renderer, render_settings, input_service)
    local accum = (self._state_rebuild_dt_accum or 0) + (dt or 0)

    if accum < STATE_THROTTLE_RATE and not mod._teamhud_needs_rebuild then
        self._state_rebuild_dt_accum = accum

        HudElementRingHud_team_docked.super.update(
            self,
            dt,
            t,
            ui_renderer,
            render_settings,
            input_service
        )

        return
    end

    self._state_rebuild_dt_accum = 0

    if mod._teamhud_needs_rebuild then
        mod._teamhud_needs_rebuild = false

        C = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
        W = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_definitions_team_docked")

        Definitions = W.build_definitions()

        HudElementRingHud_team_docked.super.init(
            self,
            self._parent,
            self._draw_layer,
            self._scale,
            Definitions
        )

        self._tile_widget_names = { "rh_team_tile_1", "rh_team_tile_2", "rh_team_tile_3" }
        self._name_widget_names = { "rh_team_name_1", "rh_team_name_2", "rh_team_name_3" }

        for name, w in pairs(self._widgets_by_name or {}) do
            if string.find(name, "^rh_team_") then
                w._ringhud_is_team_tile = true
            end
        end
    end

    local s               = mod._settings or {}
    local mode            = s.team_hud_mode or "team_hud_docked"
    local mode_is_docked  = mode == "team_hud_docked" or mode == "team_hud_floating_docked"
    local players         = U.sorted_teammates()

    local force_show_team = mod.show_all_hud_hotkey_active == true
        and mode ~= "team_hud_disabled"

    if mode == "team_hud_disabled" or mode == "team_hud_floating_vanilla" then
        _hide_all_widgets(self)

        self._show_respawns_in_floating = false
        self._switching_any_visible     = false

        HudElementRingHud_team_docked.super.update(
            self,
            dt,
            t,
            ui_renderer,
            render_settings,
            input_service
        )

        return
    end

    -- Floating modes: this element is only used for respawn digits.
    if not mode_is_docked then
        if mode ~= "team_hud_floating" then
            _hide_all_widgets(self)

            self._show_respawns_in_floating = false
            self._switching_any_visible     = false

            HudElementRingHud_team_docked.super.update(
                self,
                dt,
                t,
                ui_renderer,
                render_settings,
                input_service
            )

            return
        end

        local any_respawns = false

        for i = 1, #players do
            local p = players[i]
            local ally_tbl = RingHud_state_team.build(
                p and not p.__deleted and p.player_unit,
                nil,
                {
                    player     = p,
                    t          = t,
                    force_show = force_show_team,
                    peer_id    = _peer_id(p),
                }
            )

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
        self._switching_any_visible     = false

        if not any_respawns then
            _hide_all_widgets(self)

            HudElementRingHud_team_docked.super.update(
                self,
                dt,
                t,
                ui_renderer,
                render_settings,
                input_service
            )

            return
        end

        local wbn = self._widgets_by_name or {}

        for i = 1, 3 do
            local tile_w = wbn[self._tile_widget_names[i]]
            local name_w = wbn[self._name_widget_names[i]]

            if not tile_w or not name_w then
                goto continue
            end

            tile_w._ringhud_is_team_tile = true
            name_w._ringhud_is_team_tile = true

            local player = players[i]

            if not player or player.__deleted then
                tile_w.visible = false
                name_w.visible = false
                goto continue
            end

            local unit        = player.player_unit
            local name_str    = Name.default(player)
            local fake_marker = {
                data = {
                    rh_name_composed = name_str
                }
            }

            local ally_tbl    = RingHud_state_team.build(
                unit,
                fake_marker,
                {
                    player     = player,
                    t          = t,
                    force_show = force_show_team,
                    peer_id    = _peer_id(player),
                }
            )

            local show_this   = ally_tbl
                and ally_tbl.status
                and ally_tbl.status.kind == "dead"
                and ally_tbl.assist
                and ally_tbl.assist.respawn_digits

            tile_w.visible    = show_this and true or false
            name_w.visible    = show_this and true or false

            if not show_this then
                goto continue
            end

            _apply_RingHud_state_team_to_widgets(
                tile_w,
                name_w,
                ally_tbl,
                unit
            )

            ::continue::
        end

        HudElementRingHud_team_docked.super.update(
            self,
            dt,
            t,
            ui_renderer,
            render_settings,
            input_service
        )

        return
    end

    -- Docked / floating_docked: normal operation
    self._show_respawns_in_floating = false
    self._switching_any_visible     = false

    local wbn                       = self._widgets_by_name or {}

    for i = 1, 3 do
        local tile_w = wbn[self._tile_widget_names[i]]
        local name_w = wbn[self._name_widget_names[i]]

        if not tile_w or not name_w then
            goto continue
        end

        tile_w._ringhud_is_team_tile = true
        name_w._ringhud_is_team_tile = true

        local player = players[i]

        if not player or player.__deleted then
            tile_w.visible = false
            name_w.visible = false
            goto continue
        end

        local unit = player.player_unit
        local ally_tbl = RingHud_state_team.build(
            unit,
            nil,
            {
                player     = player,
                t          = t,
                force_show = force_show_team,
                peer_id    = _peer_id(player),
            }
        )

        if not ally_tbl or not ally_tbl.ok then
            tile_w.visible = false
            name_w.visible = false
            goto continue
        end

        tile_w.visible = true
        name_w.visible = true

        _apply_RingHud_state_team_to_widgets(
            tile_w,
            name_w,
            ally_tbl,
            unit
        )

        ::continue::
    end

    HudElementRingHud_team_docked.super.update(
        self,
        dt,
        t,
        ui_renderer,
        render_settings,
        input_service
    )
end

function HudElementRingHud_team_docked:draw(dt, t, ui_renderer, render_settings, input_service)
    local s    = mod._settings or {}
    local mode = s.team_hud_mode or "team_hud_docked"

    if not (
            mode == "team_hud_docked"
            or mode == "team_hud_floating_docked"
        )
        and not self._show_respawns_in_floating
    then
        return
    end

    return HudElementRingHud_team_docked.super.draw(
        self,
        dt,
        t,
        ui_renderer,
        render_settings,
        input_service
    )
end

return HudElementRingHud_team_docked
