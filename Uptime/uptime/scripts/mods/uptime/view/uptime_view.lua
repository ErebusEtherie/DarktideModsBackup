local mod = get_mod("uptime")
local renderer = mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_row_v1")
local Definitions = mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_view_definitions")
mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_view_data_handler")
local tooltip_definition = mod:io_dofile("uptime/scripts/mods/uptime/view/tooltip_definition")
local uptime_mission_overview = mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_mission_overview")

local UptimeView = class("UptimeView", "BaseView")

local show_mission_overview = true

function UptimeView:init(settings, context)
    self._definitions = Definitions
    local mission_secene = self._definitions.mission_section_scene_graph_id
    if not show_mission_overview then
        local row_scene = self._definitions.row_scene_graph_id
        local mission_height = self._definitions.scenegraph_definition[mission_secene].size[2]
        self._definitions.scenegraph_definition[mission_secene].size[2] = 0
        self._definitions.scenegraph_definition[row_scene].position[2] = self._definitions.scenegraph_definition[row_scene].position[2] - mission_height
    end
    self._mission_scene = self._definitions.scenegraph_definition[mission_secene]
    self.display_values = mod:generate_display_values(context.entry)
    self._widgets, self._widgets_by_name = {}, {}
    UptimeView.super.init(self, self._definitions, settings)
    self._pass_input = true
end

function UptimeView:on_enter()
    self:for_all_icons(mod.packages.load_resource)
    if show_mission_overview then
        self:create_mission_section(self.display_values.mission)
    end
    self:create_rows(self.display_values.buffs, self.display_values.weapons)
    UptimeView.super.on_enter(self)
end

function UptimeView:create_mission_section(mission)
    local widgets = uptime_mission_overview(self, mission, renderer.get_width())
    for _, widget in pairs(widgets) do
        self._widgets[#self._widgets + 1] = widget
    end
end

function UptimeView:on_exit(...)
    self:for_all_icons(mod.packages.unload_resource)
    UptimeView.super.on_exit(self, ...)
end

function UptimeView:for_all_icons(func)
    for _, buff in pairs(self.display_values.buffs) do
        func(buff.icon)
    end
end

function UptimeView:create_rows(buffs, weapons)

    local sorted_buffs = {}
    for _, buff in pairs(buffs) do
        table.insert(sorted_buffs, buff)
    end
    table.sort(sorted_buffs, function(a, b)
        return a.uptime_combat > b.uptime_combat
    end)

    local header_row = renderer.create_header_row(self)
    self._widgets[#self._widgets + 1] = header_row

    local index = 2 -- header row is double height

    for _, buff in ipairs(sorted_buffs) do
        local widgets = renderer.create_row(self, buff, index)
        for _, widget in pairs(widgets) do
            self._widgets[#self._widgets + 1] = widget
        end
        index = index + 1
    end

    for weapon_name, weapon_entry in pairs(weapons or {}) do
        local weapon_widget = renderer.create_weapon_row(self, weapon_name, weapon_entry, index)
        self._widgets[#self._widgets + 1] = weapon_widget
        index = index + 1
        for _, buff in pairs(weapon_entry.buffs) do
            local widgets = renderer.create_row(self, buff, index)
            for _, widget in pairs(widgets) do
                self._widgets[#self._widgets + 1] = widget
            end
            index = index + 1
        end
    end

    local horizontal_margins_for_border = 75
    local final_width = renderer.get_width() + horizontal_margins_for_border

    local vertical_margins_for_border = 250
    local rows_height = index * renderer.row_height
    local mission_height = self._mission_scene and self._mission_scene.size[2] or 0
    local final_height = rows_height + mission_height + vertical_margins_for_border

    self:_set_scenegraph_size("container", final_width, final_height)
end

function UptimeView:update(...)
    local show_tooltip = false
    for _, widget in pairs(self._widgets) do
        if (widget.content.hotspot or {}).is_hover and widget.buff and widget.buff.tooltip then
            show_tooltip = true
            self:setup_tooltip(widget.buff, widget)
        end
    end
    local tooltip = self._widgets_by_name.tooltip
    tooltip.visible = show_tooltip
    return UptimeView.super.update(self, ...)
end

function UptimeView:setup_tooltip(buff, hovered_widget)
    local widget = self._widgets_by_name.tooltip
    local content = widget.content
    content.title = buff.tooltip.title
    content.description = buff.tooltip.description
    tooltip_definition.resize_tooltip(self, widget, self._ui_renderer)
    local tooltip_offset = widget.offset
    tooltip_offset[1] = hovered_widget.offset[1]
    tooltip_offset[2] = hovered_widget.offset[2]
    return true
end

return UptimeView