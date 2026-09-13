-- File: scripts/mods/BetterLoadouts/preset_tooltip.lua

local mod = get_mod("BetterLoadouts")
if not mod then
    return
end

local function _node_bottom(node)
    if not (node and node.position and node.size) then
        return nil
    end

    return (node.position[2] or 0) + (node.size[2] or 0)
end

local function _is_wide_layout()
    if mod._bl_is_wide_preset_layout ~= nil then
        return mod._bl_is_wide_preset_layout == true
    end

    local layout = mod.BL.layout_for_limit(mod.preset_limit or 28)

    return (layout.MAX_COLUMNS or 0) > (layout.ROWS_PER_COL or 0)
end

local function _bar_alignment()
    local alignment = mod._bl_profile_preset_alignment or mod.preset_alignment

    if alignment == "left" or alignment == "center" then
        return alignment
    end

    return "right"
end

local function _clamp_wide_tooltip_to_screen(self, scenegraph, tooltip_x, tooltip_y, tooltip_z)
    local tooltip_node = scenegraph.profile_preset_tooltip
    local screen_node = scenegraph.screen
    if not (tooltip_node and tooltip_node.size and screen_node and screen_node.size) then
        return tooltip_x
    end

    self:_set_scenegraph_position("profile_preset_tooltip", tooltip_x, tooltip_y, tooltip_z)
    self:_force_update_scenegraph()

    local tooltip_world_position = self:scenegraph_world_position("profile_preset_tooltip")
    local screen_world_position = self:scenegraph_world_position("screen")
    if not (tooltip_world_position and screen_world_position) then
        return tooltip_x
    end

    local tooltip_left = tooltip_world_position[1] or 0
    local tooltip_right = tooltip_left + (tooltip_node.size[1] or 0)
    local screen_left = screen_world_position[1] or 0
    local screen_right = screen_left + (screen_node.size[1] or 0)
    local adjustment = 0

    if tooltip_left < screen_left then
        adjustment = screen_left - tooltip_left
    elseif tooltip_right > screen_right then
        adjustment = screen_right - tooltip_right
    end

    if adjustment ~= 0 then
        tooltip_x = tooltip_x + adjustment
        self:_set_scenegraph_position("profile_preset_tooltip", tooltip_x, tooltip_y, tooltip_z)
        self:_force_update_scenegraph()
    end

    return tooltip_x
end

function mod.BL.tooltip_dimensions()
    local layout = mod.BL.layout_for_limit(mod.preset_limit or 28)
    local max_columns = layout.MAX_COLUMNS or 0
    local rows_per_col = layout.ROWS_PER_COL or 0

    if max_columns > rows_per_col then
        if max_columns >= 80 then
            return 600, 360, 560
        end

        return 500, 340, 460
    end

    return 265, 460, 225
end

function mod.refresh_preset_tooltip_layout(self, rebuild_grid)
    if not self then
        return
    end

    local tooltip_width, tooltip_height, grid_width = mod.BL.tooltip_dimensions()
    local definitions = self._definitions
    local definition_scenegraph = definitions and definitions.scenegraph_definition
    local tooltip_definition = definition_scenegraph and definition_scenegraph.profile_preset_tooltip
    local grid_definition = definition_scenegraph and definition_scenegraph.profile_preset_tooltip_grid

    if tooltip_definition and tooltip_definition.size then
        tooltip_definition.size[1] = tooltip_width
        tooltip_definition.size[2] = tooltip_height
    end

    if grid_definition and grid_definition.size then
        grid_definition.size[1] = grid_width
    end

    local scenegraph = self._ui_scenegraph
    local tooltip_node = scenegraph and scenegraph.profile_preset_tooltip
    local grid_node = scenegraph and scenegraph.profile_preset_tooltip_grid

    if tooltip_node and tooltip_node.size then
        self:_set_scenegraph_size("profile_preset_tooltip", tooltip_width, tooltip_node.size[2] or tooltip_height)
    end

    if grid_node and grid_node.size then
        self:_set_scenegraph_size("profile_preset_tooltip_grid", grid_width, grid_node.size[2] or 1)
    end

    local grid = self._profile_preset_tooltip_grid
    if grid then
        local menu_settings = grid:menu_settings()
        local grid_size = menu_settings and menu_settings.grid_size
        local mask_size = menu_settings and menu_settings.mask_size

        if grid_size then
            grid_size[1] = grid_width
        end

        if mask_size then
            mask_size[1] = grid_width + 40
        end

        if grid.force_update_list_size then
            grid:force_update_list_size()
        end
    end

    mod.position_preset_tooltip(self)

    if rebuild_grid and self._costumization_open and self._setup_custom_icons_grid then
        self:_setup_custom_icons_grid()
    end
end

function mod.position_preset_tooltip(self)
    local scenegraph = self and self._ui_scenegraph
    local tooltip_node = scenegraph and scenegraph.profile_preset_tooltip
    if not tooltip_node then
        return
    end

    local layout = mod.BL.layout_for_limit(mod.preset_limit or 28)
    local definitions = self._definitions
    local tooltip_definition = definitions
        and definitions.scenegraph_definition
        and definitions.scenegraph_definition.profile_preset_tooltip
    local tooltip_y = tooltip_definition
        and tooltip_definition.position
        and tooltip_definition.position[2]
        or 62
    local tooltip_z = tooltip_definition
        and tooltip_definition.position
        and tooltip_definition.position[3]
        or 1
    local tooltip_x

    if _is_wide_layout() then
        tooltip_node.horizontal_alignment = "center"
        tooltip_x = 0

        local panel_bottom_y = mod._bl_profile_preset_panel_bottom_y
            or ((mod._bl_profile_preset_panel_top_y or tooltip_y) + (mod._bl_profile_preset_panel_height or 0))

        tooltip_y = panel_bottom_y + 16
    else
        local panel_node = scenegraph.profile_preset_button_panel
        local panel_width = mod._bl_profile_preset_panel_width
            or (panel_node and panel_node.size and panel_node.size[1])
            or (layout.BUTTON_WIDTH * 2 + layout.COLUMN_GAP)
        local safe_gap = layout.SAFE_GAP or 40

        if _bar_alignment() == "right" then
            tooltip_node.horizontal_alignment = "right"
            tooltip_x = -(panel_width + safe_gap) + 12
        else
            tooltip_node.horizontal_alignment = "left"
            tooltip_x = panel_width + safe_gap - 12
        end
    end

    if mod._has_loadoutnames then
        local loadout_names_bottom = math.max(
            _node_bottom(scenegraph.loadout_name_tbox_area) or -math.huge,
            _node_bottom(scenegraph.loadout_name_tooltip_area) or -math.huge
        )

        if loadout_names_bottom > -math.huge then
            tooltip_y = math.max(tooltip_y, loadout_names_bottom + 16)
        end
    end

    if _is_wide_layout() then
        _clamp_wide_tooltip_to_screen(self, scenegraph, tooltip_x, tooltip_y, tooltip_z)
    else
        self:_set_scenegraph_position("profile_preset_tooltip", tooltip_x, tooltip_y, tooltip_z)
        self:_force_update_scenegraph()
    end

    if self._profile_preset_tooltip_grid and self._update_profile_preset_tooltip_grid_position then
        self:_update_profile_preset_tooltip_grid_position()
    end
end
