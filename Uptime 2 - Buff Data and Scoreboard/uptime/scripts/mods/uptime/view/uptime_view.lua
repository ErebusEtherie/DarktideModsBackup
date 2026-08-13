-- File: uptime/scripts/mods/uptime/view/uptime_view.lua
local mod = get_mod("uptime"); if not mod then return end
local DMF = get_mod("DMF")

local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIWidgetGrid = mod:original_require("scripts/ui/widget_logic/ui_widget_grid")
local renderer = mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_row_v1")
local Definitions = mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_view_definitions")
mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_view_data_handler")
local tooltip_definition = mod:io_dofile("uptime/scripts/mods/uptime/view/tooltip_definition")
local uptime_mission_overview = mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_mission_overview")
local get_scoreboard_widgets = mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_scoreboard")

local UptimeView = class("UptimeView", "BaseView")

local show_mission_overview = true

local function scoreboard_tracking_enabled()
    if type(mod.scoreboard_tracking_enabled) ~= "function" then
        return false
    end

    return mod.scoreboard_tracking_enabled()
end

function UptimeView:init(settings, context)
    self._definitions = Definitions
    local mission_secene = self._definitions.mission_section_scene_graph_id
    if not show_mission_overview then
        local row_scene = self._definitions.row_grid_scene_graph_id
        local mission_height = self._definitions.scenegraph_definition[mission_secene].size[2]
        self._definitions.scenegraph_definition[mission_secene].size[2] = 0
        self._definitions.scenegraph_definition[row_scene].position[2] = self._definitions.scenegraph_definition
            [row_scene].position[2] - mission_height
    end
    self._mission_scene = self._definitions.scenegraph_definition[mission_secene]
    self.display_values = mod:generate_display_values(context.entry)
    self._widgets, self._widgets_by_name = {}, {}
    self._row_content_widgets = {}
    self._row_alignment_widgets = {}
    self._row_extra_widgets_by_row = {}
    self._scoreboard_widgets = {}
    self._scoreboard_alignment_widgets = {}

    UptimeView.super.init(self, self._definitions, settings)
    self._pass_input = true
end

function UptimeView:on_enter()
    self._uptime_icon_packages_unloaded = false
    self:for_all_icons(mod.packages.load_resource)
    if show_mission_overview then
        self:create_mission_section(self.display_values.mission)
    end
    self:create_rows(self.display_values.buffs, self.display_values.weapons)

    if self.display_values.damage and scoreboard_tracking_enabled() then
        self:create_scoreboard_section(self.display_values.damage)
    end

    UptimeView.super.on_enter(self)
end

function UptimeView:create_mission_section(mission)
    local widgets = uptime_mission_overview(self, mission, renderer.get_width())
    for _, widget in pairs(widgets) do
        self._widgets[#self._widgets + 1] = widget
    end
end

function UptimeView:create_scoreboard_section(damage)
    local sb_width = 250

    local current_width, current_height = self:_scenegraph_size("container")

    -- Expand container so the background stretches to fit the scoreboard
    local padding = 40
    local new_width = current_width + sb_width + padding
    self:_set_scenegraph_size("container", new_width, current_height)

    -- Position the scoreboard section to the right of the main uptime rows
    self:_set_scenegraph_position("scoreboard_grid_base", current_width, 175, 0)

    -- Set height to match the visible row boundaries
    local sb_height = current_height - 250
    if sb_height < 400 then sb_height = 400 end

    self:_set_scenegraph_size("scoreboard_grid_base", sb_width, sb_height)
    self:_set_scenegraph_size("scoreboard_scrollbar", nil, sb_height)

    -- Fetch the array of individual row widgets
    local widgets = get_scoreboard_widgets(self, damage, sb_width)

    for _, widget in ipairs(widgets) do
        self._scoreboard_widgets[#self._scoreboard_widgets + 1] = widget
        self._scoreboard_alignment_widgets[#self._scoreboard_alignment_widgets + 1] = {
            name = widget.name,
            size = widget.content.size,
        }
        self._widgets_by_name[widget.name] = widget
    end

    self:_setup_scoreboard_grid()
end

function UptimeView:on_exit(...)
    UptimeView.super.on_exit(self, ...)
end

function UptimeView:destroy(...)
    UptimeView.super.destroy(self, ...)

    if not self._uptime_icon_packages_unloaded then
        self._uptime_icon_packages_unloaded = true
        self:for_all_icons(mod.packages.unload_resource)
    end
end

function UptimeView:for_all_icons(func)
    if not func then
        return
    end

    local display_values = self.display_values or {}
    local buffs = display_values.buffs or {}

    for _, buff in pairs(buffs) do
        func(buff.icon)
    end

    local damage = display_values.damage
    local team = damage and damage.team or {}

    for i = 1, #team do
        local loadout_icons = team[i].loadout_icons or {}
        for j = 1, #loadout_icons do
            local icon_data = loadout_icons[j]
            if icon_data then
                func(icon_data.icon)
            end
        end

        local loadout_weapons = team[i].loadout_weapons or {}
        for j = 1, #loadout_weapons do
            local weapon_data = loadout_weapons[j]
            if weapon_data then
                func(weapon_data.icon)
            end
        end
    end
end

function UptimeView:_add_row_content_widget(widget, height, extra_widgets)
    if not widget then
        return
    end

    local row_width = renderer.get_width()
    widget.content.size = widget.content.size or { row_width, height }
    widget.content.size[1] = row_width
    widget.content.size[2] = height

    local row_content_widgets = self._row_content_widgets
    local row_alignment_widgets = self._row_alignment_widgets

    row_content_widgets[#row_content_widgets + 1] = widget
    row_alignment_widgets[#row_alignment_widgets + 1] = {
        name = widget.name,
        size = widget.content.size,
    }

    self._row_extra_widgets_by_row[widget] = extra_widgets or {}
end

function UptimeView:create_rows(buffs, weapons)
    self._row_content_widgets = {}
    self._row_alignment_widgets = {}
    self._row_extra_widgets_by_row = {}

    local sorted_buffs = {}
    for _, buff in pairs(buffs) do
        table.insert(sorted_buffs, buff)
    end
    table.sort(sorted_buffs, function(a, b)
        return a.uptime_combat > b.uptime_combat
    end)

    local header_row = renderer.create_header_row(self)
    self:_add_row_content_widget(header_row, renderer.row_height * 2)

    local index = 2 -- header row is double height

    for _, buff in ipairs(sorted_buffs) do
        local widgets = renderer.create_row(self, buff, index)
        local row_widget = widgets[1]
        local extra_widgets = {}

        for i = 2, #widgets do
            extra_widgets[#extra_widgets + 1] = widgets[i]
        end

        self:_add_row_content_widget(row_widget, renderer.row_height, extra_widgets)
        index = index + 1
    end

    for weapon_name, weapon_entry in pairs(weapons or {}) do
        local weapon_widget = renderer.create_weapon_row(self, weapon_name, weapon_entry, index)
        self:_add_row_content_widget(weapon_widget, renderer.row_height)
        index = index + 1

        for _, buff in pairs(weapon_entry.buffs) do
            local widgets = renderer.create_row(self, buff, index)
            local row_widget = widgets[1]
            local extra_widgets = {}

            for i = 2, #widgets do
                extra_widgets[#extra_widgets + 1] = widgets[i]
            end

            self:_add_row_content_widget(row_widget, renderer.row_height, extra_widgets)
            index = index + 1
        end
    end

    local horizontal_margins_for_border = 75
    local final_width = renderer.get_width() + horizontal_margins_for_border

    local vertical_margins_for_border = 250
    local rows_height = index * renderer.row_height
    local mission_height = self._mission_scene and self._mission_scene.size[2] or 0
    local max_panel_height = self._definitions.max_panel_height or 1000
    local max_rows_height = math.max(max_panel_height - mission_height - vertical_margins_for_border, renderer
        .row_height)
    local visible_rows_height = max_rows_height
    local final_height = max_panel_height
    local row_grid_scene_graph_id = self._definitions.row_grid_scene_graph_id

    self:_set_scenegraph_size("container", final_width, final_height)
    self:_set_scenegraph_size(row_grid_scene_graph_id, renderer.get_width(), visible_rows_height)
    self:_set_scenegraph_size("scrollbar", nil, visible_rows_height)

    self:_setup_row_grid()
end

function UptimeView:_setup_row_grid()
    local widgets_by_name = self._widgets_by_name
    local scrollbar_widget = widgets_by_name and widgets_by_name.scrollbar
    local row_grid_scene_graph_id = self._definitions.row_grid_scene_graph_id
    local row_scene_graph_id = self._definitions.row_scene_graph_id

    if not (scrollbar_widget and row_grid_scene_graph_id and row_scene_graph_id and self._row_content_widgets) then
        return
    end

    local grid = UIWidgetGrid:new(
        self._row_content_widgets,
        self._row_alignment_widgets,
        self._ui_scenegraph,
        row_grid_scene_graph_id,
        "down",
        { 0, 0 },
        nil,
        false
    )

    grid:set_render_scale(self._render_scale)
    grid:assign_scrollbar(scrollbar_widget, row_scene_graph_id, row_grid_scene_graph_id)
    grid:set_scrollbar_progress(0)
    grid:set_scroll_step_length(100)

    if DMF and DMF.get and scrollbar_widget.content then
        local scroll_speed = DMF:get("dmf_options_scrolling_speed")
        if scroll_speed then
            scrollbar_widget.content.scroll_speed = scroll_speed
        end
    end

    if scrollbar_widget.content then
        scrollbar_widget.content.visible = grid:can_scroll()
    end

    self._row_content_grid = grid
end

function UptimeView:_setup_scoreboard_grid()
    local scrollbar_widget = self._widgets_by_name.scoreboard_scrollbar

    if not (scrollbar_widget and self._scoreboard_widgets and #self._scoreboard_widgets > 0) then
        return
    end

    local grid = UIWidgetGrid:new(
        self._scoreboard_widgets,
        self._scoreboard_alignment_widgets,
        self._ui_scenegraph,
        "scoreboard_grid_base",
        "down",
        { 0, 0 },
        nil,
        false
    )

    grid:set_render_scale(self._render_scale)
    grid:assign_scrollbar(scrollbar_widget, "scoreboard_grid_content", "scoreboard_grid_base")
    grid:set_scrollbar_progress(0)
    grid:set_scroll_step_length(100)

    if DMF and DMF.get and scrollbar_widget.content then
        local scroll_speed = DMF:get("dmf_options_scrolling_speed")
        if scroll_speed then
            scrollbar_widget.content.scroll_speed = scroll_speed
        end
    end

    if scrollbar_widget.content then
        scrollbar_widget.content.visible = grid:can_scroll()
    end

    self._scoreboard_grid = grid
end

function UptimeView:_scenegraph_position_relative_to_container(scenegraph_id)
    local x = 0
    local y = 0
    local current_id = scenegraph_id
    local scenegraph_definition = self._definitions and self._definitions.scenegraph_definition
    local ui_scenegraph = self._ui_scenegraph
    local visited = {}

    while current_id and current_id ~= "container" and not visited[current_id] do
        visited[current_id] = true

        local scene = ui_scenegraph and ui_scenegraph[current_id]
        local position = scene and scene.position

        if position then
            x = x + (position[1] or 0)
            y = y + (position[2] or 0)
        end

        local definition = scenegraph_definition and scenegraph_definition[current_id]
        current_id = definition and definition.parent
    end

    return x, y
end

function UptimeView:_get_hovered_loadout_tooltip(widget)
    if not widget then
        return nil
    end

    local loadout_tooltips = widget.loadout_tooltips
    local loadout_hotspot_ids = widget.loadout_hotspot_ids

    if not loadout_tooltips or not loadout_hotspot_ids then
        return nil
    end

    for i = 1, #loadout_hotspot_ids do
        local hotspot_id = loadout_hotspot_ids[i]
        local hotspot_content = widget.content and widget.content[hotspot_id]
        local tooltip = loadout_tooltips[i]

        if hotspot_content and hotspot_content.is_hover and tooltip then
            local hotspot_style = widget.style and widget.style[hotspot_id]
            local hotspot_offset = hotspot_style and hotspot_style.offset

            return tooltip, hotspot_offset
        end
    end

    return nil
end

function UptimeView:update(dt, t, input_service, ...)
    local row_grid = self._row_content_grid
    if row_grid then
        row_grid:update(dt, t, input_service)
    end

    local sb_grid = self._scoreboard_grid
    if sb_grid then
        sb_grid:update(dt, t, input_service)
    end

    local show_tooltip = false
    local row_widgets = self._row_content_widgets or {}
    for i = 1, #row_widgets do
        local widget = row_widgets[i]
        if (not row_grid or row_grid:is_widget_visible(widget, renderer.row_height)) and (widget.content.hotspot or {}).is_hover and widget.buff and widget.buff.tooltip then
            show_tooltip = true
            self:setup_tooltip(widget.buff.tooltip, widget)
        end
    end

    local sb_widgets = self._scoreboard_widgets or {}
    for i = 1, #sb_widgets do
        local widget = sb_widgets[i]

        if widget and (not sb_grid or sb_grid:is_widget_visible(widget)) then
            local tooltip, hotspot_offset = self:_get_hovered_loadout_tooltip(widget)

            if tooltip then
                show_tooltip = true
                self:setup_tooltip(tooltip, widget, hotspot_offset)
            end
        end
    end

    local tooltip = self._widgets_by_name.tooltip
    tooltip.visible = show_tooltip
    return UptimeView.super.update(self, dt, t, input_service, ...)
end

function UptimeView:draw(dt, t, input_service, layer)
    self:_draw_row_grid(dt, t, input_service)
    self:_draw_scoreboard_grid(dt, t, input_service)
    return UptimeView.super.draw(self, dt, t, input_service, layer)
end

function UptimeView:_draw_row_grid(dt, t, input_service)
    local row_grid = self._row_content_grid
    local row_widgets = self._row_content_widgets

    if not (row_grid and row_widgets and self._ui_renderer and self._ui_scenegraph) then
        return
    end

    local ui_renderer = self._ui_renderer
    local render_settings = self._render_settings

    UIRenderer.begin_pass(ui_renderer, self._ui_scenegraph, input_service, dt, render_settings)

    for i = 1, #row_widgets do
        local widget = row_widgets[i]

        if widget and row_grid:is_widget_visible(widget, renderer.row_height) then
            UIWidget.draw(widget, ui_renderer)

            local extra_widgets = self._row_extra_widgets_by_row and self._row_extra_widgets_by_row[widget]
            if extra_widgets then
                for j = 1, #extra_widgets do
                    local extra_widget = extra_widgets[j]
                    if extra_widget then
                        UIWidget.draw(extra_widget, ui_renderer)
                    end
                end
            end
        end
    end

    UIRenderer.end_pass(ui_renderer)
end

function UptimeView:_draw_scoreboard_grid(dt, t, input_service)
    local sb_grid = self._scoreboard_grid
    local sb_widgets = self._scoreboard_widgets

    if not (sb_grid and sb_widgets and self._ui_renderer and self._ui_scenegraph) then
        return
    end

    UIRenderer.begin_pass(self._ui_renderer, self._ui_scenegraph, input_service, dt, self._render_settings)

    for i = 1, #sb_widgets do
        local widget = sb_widgets[i]

        if widget and sb_grid:is_widget_visible(widget) then
            UIWidget.draw(widget, self._ui_renderer)
        end
    end

    UIRenderer.end_pass(self._ui_renderer)
end

function UptimeView:setup_tooltip(tooltip_data, hovered_widget, hotspot_offset)
    if not tooltip_data or not hovered_widget then
        return false
    end

    local widget = self._widgets_by_name.tooltip

    if not widget then
        return false
    end

    local content = widget.content
    content.title = tooltip_data.title
    content.description = tooltip_data.description
    tooltip_definition.resize_tooltip(self, widget, self._ui_renderer)

    local hovered_scene_x, hovered_scene_y = self:_scenegraph_position_relative_to_container(hovered_widget
        .scenegraph_id)
    local tooltip_scene_x, tooltip_scene_y = self:_scenegraph_position_relative_to_container(widget.scenegraph_id)

    local hovered_offset = hovered_widget.offset or { 0, 0, 0 }
    local hotspot_x = hotspot_offset and hotspot_offset[1] or 0
    local hotspot_y = hotspot_offset and hotspot_offset[2] or 0
    local is_hotspot_tooltip = hotspot_offset ~= nil

    local tooltip_width = 400
    local tooltip_size = widget.content and widget.content.size

    if tooltip_size and tooltip_size[1] then
        tooltip_width = tooltip_size[1]
    else
        local scene_width = self:_scenegraph_size(widget.scenegraph_id)
        if scene_width then
            tooltip_width = scene_width
        end
    end

    local tooltip_offset = widget.offset
    local anchor_x = hovered_scene_x + hovered_offset[1] + hotspot_x - tooltip_scene_x
    local anchor_y = hovered_scene_y + hovered_offset[2] + hotspot_y - tooltip_scene_y

    if is_hotspot_tooltip then
        tooltip_offset[1] = anchor_x - tooltip_width - 8
        tooltip_offset[2] = anchor_y
    else
        tooltip_offset[1] = anchor_x + 36
        tooltip_offset[2] = anchor_y
    end

    return true
end

return UptimeView
