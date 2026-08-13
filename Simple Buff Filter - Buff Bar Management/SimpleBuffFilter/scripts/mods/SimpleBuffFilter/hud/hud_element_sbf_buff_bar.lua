-- File: scripts/mods/SimpleBuffFilter/hud/hud_element_sbf_buff_bar.lua
local mod = get_mod("SimpleBuffFilter")
if not mod then return end

local HUB_GAME_MODES = {
    hub = true,
    prologue_hub = true,
}

local function _can_get(path)
    if Application and Application.can_get_resource then
        return Application.can_get_resource("lua", path)
    end
    return false
end

local function _current_game_mode_name(parent)
    if parent and parent._current_game_mode_name then
        return parent._current_game_mode_name
    end

    local game_mode_manager = Managers and Managers.state and Managers.state.game_mode
    if game_mode_manager and game_mode_manager.game_mode_name then
        return game_mode_manager:game_mode_name()
    end

    return nil
end

local function _is_hub_game_mode(parent)
    local game_mode_name = _current_game_mode_name(parent)

    return HUB_GAME_MODES[game_mode_name] == true
end

local function _hide_buff_widgets(element, ui_renderer)
    local active_buffs_data = element._active_buffs_data
    if active_buffs_data then
        table.clear(active_buffs_data)
    end

    local buff_widgets_array = element._buff_widgets_array
    if not buff_widgets_array then
        return
    end

    for i = 1, #buff_widgets_array do
        local widget = buff_widgets_array[i]

        if widget then
            element:_return_widget(widget, ui_renderer)
        end
    end
end

-- Ensure base class is loaded
if _can_get("scripts/ui/hud/elements/player_buffs/hud_element_player_buffs") then
    require("scripts/ui/hud/elements/player_buffs/hud_element_player_buffs")
elseif _can_get("scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_polling") then
    require("scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_polling")
end

local Definitions = mod:io_dofile(
    "SimpleBuffFilter/scripts/mods/SimpleBuffFilter/hud/hud_element_sbf_buff_bar_definitions")

-- Create the custom class inheriting from the vanilla Buffs HUD
local HudElementSbfBuffBar = class("HudElementSbfBuffBar", "HudElementPlayerBuffs")

function HudElementSbfBuffBar:init(parent, draw_layer, start_scale, context)
    -- Initialize using SBF's definitions to ensure completely separate UI widget instances
    HudElementSbfBuffBar.super.init(self, parent, draw_layer, start_scale, Definitions)

    -- Store the context (which will contain { bar_index = X })
    -- This is read by the `_add_buff`, `_update_buffs`, and `_update_buff_alignments` hooks in `hud_buffs.lua`
    self._context = context or { bar_index = 2 }

    -- Override the class name so UIHud's visibility logic maps it correctly
    -- to the "HudElementSbfBuffBar2" and "HudElementSbfBuffBar3" visibility groups
    self.__class_name = "HudElementSbfBuffBar" .. tostring(self._context.bar_index)
end

function HudElementSbfBuffBar:set_visible(visible, ui_renderer, use_retained_mode)
    if _is_hub_game_mode(self._parent) then
        visible = false
        _hide_buff_widgets(self, ui_renderer)
    end

    return HudElementSbfBuffBar.super.set_visible(self, visible, ui_renderer, use_retained_mode)
end

function HudElementSbfBuffBar:update(dt, t, ui_renderer, render_settings, input_service)
    if _is_hub_game_mode(self._parent) then
        _hide_buff_widgets(self, ui_renderer)
        return
    end

    return HudElementSbfBuffBar.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

function HudElementSbfBuffBar:_draw_widgets(dt, t, input_service, ui_renderer, render_settings)
    if _is_hub_game_mode(self._parent) then
        return
    end

    return HudElementSbfBuffBar.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

return HudElementSbfBuffBar
