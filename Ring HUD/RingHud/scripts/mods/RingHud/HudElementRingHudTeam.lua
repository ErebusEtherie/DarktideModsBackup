-- File: RingHud/scripts/mods/RingHud/HudElementRingHudTeam.lua
local mod = get_mod("RingHud"); if not mod then return end

-- UI defs for the docked team tiles
local W                     = mod:io_dofile("RingHud/scripts/mods/RingHud/team/widgets")

-- Shared helpers we still need here
local U                     = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local C                     = mod:io_dofile("RingHud/scripts/mods/RingHud/team/constants")

-- Option C: pure view-model + appliers
local VM                    = mod:io_dofile("RingHud/scripts/mods/RingHud/team/markers/vm")
local Apply                 = mod:io_dofile("RingHud/scripts/mods/RingHud/team/markers/apply")

-- (Team visibility gates are queried inside VM; no need to import here.)

local Definitions           = W.build_definitions()
local HudElementRingHudTeam = class("HudElementRingHudTeam", "HudElementBase")

function HudElementRingHudTeam:init(parent, draw_layer, start_scale)
    HudElementRingHudTeam.super.init(self, parent, draw_layer, start_scale, Definitions)

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

-- Small helper: apply VM to the tile + name widgets
local function _apply_vm_to_widgets(tile_w, name_w, vm, unit)
    if not (tile_w and vm) then return end

    -- Mutate the main tile from the VM (bars, icons, counters, etc.)
    Apply.apply_all(tile_w, nil, vm, { unit = unit })

    -- Name widget: delegate to applier helper
    if name_w then
        Apply.apply_name(name_w, vm)
    end
end

function HudElementRingHudTeam:update(dt, t, ui_renderer, render_settings, input_service)
    local mode            = mod._settings.team_hud_mode
    local mode_is_docked  = (mode == "team_hud_docked"
        or mode == "team_hud_floating_docked"
        or mode == "team_hud_icons_docked")      -- NEW
    local players         = U.sorted_teammates() -- deterministic order, excludes local player

    -- Force-show is ONLY the dedicated hotkey, never ADS; and only when team HUD isn't disabled
    local force_show_team = (mod.show_all_hud_hotkey_active == true) and (mode ~= "team_hud_disabled")

    -- In 'disabled', 'floating_vanilla', and 'icons_vanilla' modes: never render docked tiles
    if mode == "team_hud_disabled" or mode == "team_hud_floating_vanilla" or mode == "team_hud_icons_vanilla" then -- NEW
        for i = 1, 4 do
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
            for i = 1, 4 do
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
            local p  = players[i]
            local vm = VM.build(p and p.player_unit, nil, {
                player     = p,
                t          = t,
                force_show = force_show_team,
            })
            if vm and vm.status and vm.status.kind == "dead" and vm.assist and vm.assist.respawn_digits then
                any_respawns = true
                break
            end
        end

        self._show_respawns_in_floating = any_respawns
        self._switching_any_visible = false

        if not any_respawns then
            -- Hide all tiles/names and bail
            for i = 1, 4 do
                local tile_w = self._widgets_by_name[string.format("rh_team_tile_%d", i)]
                local name_w = self._widgets_by_name[string.format("rh_team_name_%d", i)]
                if tile_w then tile_w.visible = false end
                if name_w then name_w.visible = false end
            end
            return
        end

        -- Populate only tiles that are in respawn state
        for i = 1, 4 do
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

            local unit      = player.player_unit
            local vm        = VM.build(unit, nil, {
                player     = player,
                t          = t,
                force_show = force_show_team,
            })

            local show_this = vm and vm.status and (vm.status.kind == "dead") and
                (vm.assist and vm.assist.respawn_digits)
            tile_w.visible  = show_this and true or false
            name_w.visible  = show_this and true or false
            if not show_this then goto continue end

            _apply_vm_to_widgets(tile_w, name_w, vm, unit)

            ::continue::
        end

        -- DRAW AFTER applying VM mutations this frame
        HudElementRingHudTeam.super.update(self, dt, t, ui_renderer, render_settings, input_service)
        return
    end

    -- Docked (normal, "floating_docked", and "icons_docked")
    self._show_respawns_in_floating = false
    self._switching_any_visible = false

    for i = 1, 4 do
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

        tile_w.visible = true
        name_w.visible = true

        local unit     = player.player_unit
        local vm       = VM.build(unit, nil, {
            player     = player,
            t          = t,
            force_show = force_show_team,
        })

        _apply_vm_to_widgets(tile_w, name_w, vm, unit)

        ::continue::
    end

    -- DRAW AFTER applying VM mutations this frame
    HudElementRingHudTeam.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

-- Gate rendering entirely when not docked (even if element is present)
function HudElementRingHudTeam:draw(dt, t, ui_renderer, render_settings, input_service)
    if not (mod._settings.team_hud_mode == "team_hud_docked"
            or mod._settings.team_hud_mode == "team_hud_floating_docked"
            or mod._settings.team_hud_mode == "team_hud_icons_docked") -- NEW
        and not self._show_respawns_in_floating then
        return
    end
    return HudElementRingHudTeam.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudElementRingHudTeam
