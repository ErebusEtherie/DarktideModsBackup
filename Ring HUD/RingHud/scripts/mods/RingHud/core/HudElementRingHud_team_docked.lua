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

local function _peer_id(player)
    if not player then return nil end
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

-- Compatibility shim:
-- LoadoutMonitor expects this method to exist because it normally runs inside HudElementPlayerPanelBase descendants.
function HudElementRingHud_team_docked:_set_widget_visible(widget, visible, ui_renderer)
    if not widget then
        return
    end

    widget.content = widget.content or {}

    if not widget.dirty then
        widget.dirty = (widget.content.visible ~= visible)
    end

    widget.content.visible = visible

    if not visible and ui_renderer then
        UIWidget.destroy(ui_renderer, widget)
    end
end

-- Delegates LoadoutMonitor's own update+visibility logic onto one of our per-tile widgets.
local function _update_loadout_monitor_widget(self, lm_mod, loadout_w, dt, t, player, ui_renderer)
    if not (lm_mod and loadout_w and player and ui_renderer) then
        if loadout_w then
            loadout_w.visible = false
            if loadout_w.content then loadout_w.content.visible = false end
        end
        return
    end

    -- LoadoutMonitor intentionally ignores bots; we should force-hide in that case
    if type(player.is_human_controlled) == "function" and not player:is_human_controlled() then
        self:_set_widget_visible(loadout_w, false, ui_renderer)
        loadout_w.visible = false
        return
    end

    -- LoadoutMonitor expects to find the widget at _widgets_by_name.playerloadout_intel
    local saved = self._widgets_by_name and self._widgets_by_name.playerloadout_intel
    self._widgets_by_name.playerloadout_intel = loadout_w

    if type(lm_mod.update_loadout) == "function" then
        lm_mod.update_loadout(self, dt, t, player, ui_renderer)
    else
        self:_set_widget_visible(loadout_w, false, ui_renderer)
    end

    -- Restore whatever was there (or nil)
    self._widgets_by_name.playerloadout_intel = saved

    -- Keep our element-level widget.visible aligned with what LM sets on widget.content.visible
    local cv = loadout_w.content and loadout_w.content.visible
    loadout_w.visible = (cv == true)
end

function HudElementRingHud_team_docked:init(parent, draw_layer, start_scale)
    HudElementRingHud_team_docked.super.init(self, parent, draw_layer, start_scale, Definitions)

    self._tile_widget_names    = { "rh_team_tile_1", "rh_team_tile_2", "rh_team_tile_3" }
    self._name_widget_names    = { "rh_team_name_1", "rh_team_name_2", "rh_team_name_3" }
    self._loadout_widget_names = { "rh_team_loadout_1", "rh_team_loadout_2", "rh_team_loadout_3" }

    for name, w in pairs(self._widgets_by_name or {}) do
        if string.find(name, "^rh_team_") then
            w._ringhud_is_team_tile = true
        end
    end

    self._show_respawns_in_floating = false
    self._switching_any_visible     = false
end

function HudElementRingHud_team_docked:update(dt, t, ui_renderer, render_settings, input_service)
    if mod._teamhud_needs_rebuild then
        mod._teamhud_needs_rebuild = false

        C = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
        W = mod:io_dofile("RingHud/scripts/mods/RingHud/core/RingHud_definitions_team_docked")

        Definitions = W.build_definitions()
        HudElementRingHud_team_docked.super.init(self, self._parent, self._draw_layer, self._scale, Definitions)

        self._tile_widget_names    = { "rh_team_tile_1", "rh_team_tile_2", "rh_team_tile_3" }
        self._name_widget_names    = { "rh_team_name_1", "rh_team_name_2", "rh_team_name_3" }
        self._loadout_widget_names = { "rh_team_loadout_1", "rh_team_loadout_2", "rh_team_loadout_3" }

        for name, w in pairs(self._widgets_by_name or {}) do
            if string.find(name, "^rh_team_") then
                w._ringhud_is_team_tile = true
            end
        end
    end

    local s               = mod._settings or {}
    local mode            = s.team_hud_mode or "team_hud_docked"
    local mode_is_docked  = (mode == "team_hud_docked" or mode == "team_hud_floating_docked")
    local players         = U.sorted_teammates()

    local force_show_team = (mod.show_all_hud_hotkey_active == true) and (mode ~= "team_hud_disabled")

    -- LoadoutMonitor compat (cached once in RingHud.lua:on_all_mods_loaded)
    local lm_mod          = mod._compat_loadout_monitor

    local function _hide_all()
        for i = 1, 3 do
            local tile_w    = self._widgets_by_name[self._tile_widget_names[i]]
            local name_w    = self._widgets_by_name[self._name_widget_names[i]]
            local loadout_w = self._widgets_by_name[self._loadout_widget_names[i]]
            if tile_w then tile_w.visible = false end
            if name_w then name_w.visible = false end
            if loadout_w then
                loadout_w.visible = false
                if loadout_w.content then loadout_w.content.visible = false end
            end
        end
    end

    if mode == "team_hud_disabled" or mode == "team_hud_floating_vanilla" then
        _hide_all()
        self._show_respawns_in_floating = false
        self._switching_any_visible     = false
        return
    end

    -- Floating modes: this element is only used for respawn digits; never show LoadoutMonitor widgets here.
    if not mode_is_docked then
        if mode ~= "team_hud_floating" then
            _hide_all()
            self._show_respawns_in_floating = false
            self._switching_any_visible     = false
            return
        end

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
        self._switching_any_visible     = false

        if not any_respawns then
            _hide_all()
            return
        end

        for i = 1, 3 do
            local tile_w    = self._widgets_by_name[self._tile_widget_names[i]]
            local name_w    = self._widgets_by_name[self._name_widget_names[i]]
            local loadout_w = self._widgets_by_name[self._loadout_widget_names[i]] -- always hidden in this mode
            if loadout_w then
                loadout_w.visible = false
                if loadout_w.content then loadout_w.content.visible = false end
            end

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

        HudElementRingHud_team_docked.super.update(self, dt, t, ui_renderer, render_settings, input_service)
        return
    end

    -- Docked / floating_docked: normal operation
    self._show_respawns_in_floating = false
    self._switching_any_visible     = false

    for i = 1, 3 do
        local tile_w    = self._widgets_by_name[self._tile_widget_names[i]]
        local name_w    = self._widgets_by_name[self._name_widget_names[i]]
        local loadout_w = self._widgets_by_name[self._loadout_widget_names[i]]

        if not tile_w or not name_w then
            if loadout_w then
                loadout_w.visible = false
                if loadout_w.content then loadout_w.content.visible = false end
            end
            goto continue
        end

        tile_w._ringhud_is_team_tile = true
        name_w._ringhud_is_team_tile = true
        if loadout_w then loadout_w._ringhud_is_team_tile = true end

        local player = players[i]
        if not player then
            tile_w.visible = false
            name_w.visible = false
            if loadout_w then
                loadout_w.visible = false
                if loadout_w.content then loadout_w.content.visible = false end
            end
            goto continue
        end

        local unit     = player.player_unit
        local ally_tbl = RingHud_state_team.build(unit, nil, {
            player     = player,
            t          = t,
            force_show = force_show_team,
            peer_id    = _peer_id(player),
        })

        if not (ally_tbl and ally_tbl.ok) then
            tile_w.visible = false
            name_w.visible = false
            if loadout_w then
                loadout_w.visible = false
                if loadout_w.content then loadout_w.content.visible = false end
            end
            goto continue
        end

        tile_w.visible = true
        name_w.visible = true

        _apply_RingHud_state_team_to_widgets(tile_w, name_w, ally_tbl, unit)

        -- LoadoutMonitor panel (uses LM's *own* tactical-overlay visibility toggles)
        if loadout_w and lm_mod then
            _update_loadout_monitor_widget(self, lm_mod, loadout_w, dt, t, player, ui_renderer)

            -- Hard gate: if our tile isn't visible for any reason, never show the LM panel either.
            if not tile_w.visible then
                self:_set_widget_visible(loadout_w, false, ui_renderer)
                loadout_w.visible = false
            end
        elseif loadout_w then
            loadout_w.visible = false
            if loadout_w.content then loadout_w.content.visible = false end
        end

        ::continue::
    end

    HudElementRingHud_team_docked.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

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
