-- File: scripts/mods/BetterLoadouts/hooks/profile_presets_layout_changed.lua

local mod = get_mod("BetterLoadouts")
if not mod then return end

local ProfileUtils = require("scripts/utilities/profile_utils")

-- Small helper to nudge the ViewElementGrid scrollbar on the tooltip grid.
-- (Duplicated locally to keep this hook self-contained.)
local function _nudge_grid_scrollbar(grid_obj, dx)
    if not grid_obj or not grid_obj._ui_scenegraph or grid_obj._betterloadouts_scrollbar_nudged then return end
    local names = { "grid_scrollbar", "scrollbar" } -- try common ids
    for i = 1, #names do
        local id   = names[i]
        local node = grid_obj._ui_scenegraph[id]
        if node and node.position then
            local x = (node.position[1] or 0) + (dx or 0)
            local y = node.position[2] or 0
            local z = node.position[3] or 13
            if grid_obj._set_scenegraph_position then
                grid_obj:_set_scenegraph_position(id, x, y, z)
            elseif grid_obj._ui_scenegraph and grid_obj._ui_scenegraph[id] then
                grid_obj._ui_scenegraph[id].position[1] = x
                grid_obj._ui_scenegraph[id].position[2] = y
                grid_obj._ui_scenegraph[id].position[3] = z
            end
            if grid_obj._force_update_scenegraph then
                grid_obj:_force_update_scenegraph()
            end
            grid_obj._betterloadouts_scrollbar_nudged = true
            return true
        end
    end
end

-- After vanilla sizes the grid/tooltip: restore BetterLoadouts selection state.
mod:hook_safe(CLASS.ViewElementProfilePresets, "cb_on_profile_preset_icon_grid_layout_changed", function(self)
    local profile_preset
    local customize_index = self._active_customize_preset_index
    if customize_index then
        local profile_preset_id = self:_get_profile_preset_id_by_widget_index(customize_index)
        profile_preset = ProfileUtils.get_profile_preset(profile_preset_id)
    end

    local grid = self._profile_preset_tooltip_grid
    mod.position_preset_tooltip(self)
    mod.sync_preset_customization_selection(self, profile_preset)

    if grid then
        _nudge_grid_scrollbar(grid, 5)
    end
end)
