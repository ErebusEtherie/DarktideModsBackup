-- File: scripts/mods/SimpleBuffFilter/hud/hud_element_sbf_buff_bar.lua
local mod = get_mod("SimpleBuffFilter")
if not mod then return end

local function _can_get(path)
    if Application and Application.can_get_resource then
        return Application.can_get_resource("lua", path)
    end
    return false
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

return HudElementSbfBuffBar
