-- File: scripts/mods/BetterLoadouts/hooks/profile_presets_layout_changed.lua

local mod = get_mod("BetterLoadouts")
if not mod then return end

-- Small helper to nudge the ViewElementGrid scrollbar on the tooltip grid.
-- (Duplicated locally to keep this hook self-contained.)
local function _nudge_grid_scrollbar(grid_obj, dx)
    if not grid_obj or not grid_obj._ui_scenegraph then return end
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
            return true
        end
    end
end

-- After vanilla sizes the grid/tooltip: widen slightly and clear selection/glow
mod:hook_safe(CLASS.ViewElementProfilePresets, "cb_on_profile_preset_icon_grid_layout_changed", function(self)
    local node = self._ui_scenegraph and self._ui_scenegraph.profile_preset_tooltip
    if node and node.size then
        local w = node.size[1] or 265
        local h = node.size[2] or 460
        self:_set_scenegraph_size("profile_preset_tooltip", w + 10, h + 0)
        self:_force_update_scenegraph()
    end

    local grid = self._profile_preset_tooltip_grid
    local widgets = grid and grid:widgets()
    if widgets then
        for i = 1, #widgets do
            local c = widgets[i].content
            if c then
                c.equipped = false
                c.force_glow = false
                if c.hotspot then
                    c.hotspot.is_selected = false
                    c.hotspot.is_focused  = false
                end
            end
        end
    end

    if grid then
        _nudge_grid_scrollbar(grid, 5)
    end
end)
