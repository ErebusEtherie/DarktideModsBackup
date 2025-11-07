local mod = get_mod("uptime")
local DMF = get_mod("DMF")

local ScriptWorld = mod:original_require("scripts/foundation/utilities/script_world")
local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIWidgetGrid = mod:original_require("scripts/ui/widget_logic/ui_widget_grid")
local ViewElementInputLegend = mod:original_require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")

local UptimeHistoryData = mod:io_dofile("uptime/scripts/mods/uptime/history/uptime_history_data")

local ENTRIES_GRID = 1
local UptimeHistoryView = class("UptimeHistoryView", "BaseView")

UptimeHistoryView.init = function(self, settings)
    self._definitions = mod:io_dofile("uptime/scripts/mods/uptime/history/uptime_history_view_definitions")
    self._blueprints = mod:io_dofile("uptime/scripts/mods/uptime/history/uptime_history_view_blueprints")
    self._settings = mod:io_dofile("uptime/scripts/mods/uptime/history/uptime_history_view_settings")
    UptimeHistoryView.super.init(self, self._definitions, settings)
    self._pass_draw = false
    self.ui_manager = Managers.ui
    self:_setup_offscreen_gui()
    self._data_handler = UptimeHistoryData:new()
end

UptimeHistoryView._setup_offscreen_gui = function(self)
    local ui_manager = Managers.ui
    local class_name = self.__class_name
    local timer_name = "ui"
    local world_layer = 10
    local world_name = class_name .. "_ui_offscreen_world"
    local view_name = self.view_name
    self._offscreen_world = ui_manager:create_world(world_name, world_layer, timer_name, view_name)
    local shading_environment = self._settings.shading_environment
    local viewport_name = class_name .. "_ui_offscreen_world_viewport"
    local viewport_type = "overlay_offscreen"
    local viewport_layer = 1
    self._offscreen_viewport = ui_manager:create_viewport(self._offscreen_world, viewport_name, viewport_type, viewport_layer, shading_environment)
    self._offscreen_viewport_name = viewport_name
    self._ui_offscreen_renderer = ui_manager:create_renderer(class_name .. "_ui_offscreen_renderer", self._offscreen_world)
end

UptimeHistoryView.on_enter = function(self)
    UptimeHistoryView.super.on_enter(self)

    self._default_entry = nil
    self._using_cursor_navigation = Managers.ui:using_cursor_navigation()

    self:_setup_entries_config()
    self:_setup_input_legend()
    self:_enable_settings_overlay(false)
    self:_update_grid_navigation_selection()
end

UptimeHistoryView._setup_input_legend = function(self)
    self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 10)
    local legend_inputs = self._definitions.legend_inputs
    for i = 1, #legend_inputs do
        local legend_input = legend_inputs[i]
        local on_pressed_callback = legend_input.on_pressed_callback and callback(self, legend_input.on_pressed_callback)
        local visibility_function = legend_input.visibility_function
        if legend_input.display_name == "loc_delete_entry" then
            visibility_function = function()
                return self.entry
            end
        end
        self._input_legend_element:add_entry(legend_input.display_name, legend_input.input_action, visibility_function, on_pressed_callback, legend_input.alignment)
    end
end

UptimeHistoryView._enable_settings_overlay = function(self, enable)
    local widgets_by_name = self._widgets_by_name
    local settings_overlay_widget = widgets_by_name.settings_overlay
    settings_overlay_widget.content.visible = enable
end

UptimeHistoryView.present_entry_widgets = function(self)
    if self.entry then
        local context = {
            entry = self.entry
        }
        mod:close_view()
        Managers.ui:open_view("uptime_view", nil, false, false, nil, context, { use_transition_ui = false })
    end
end

-- Set up scrollbar for content grid with optional scrolling speed from DMF settings
UptimeHistoryView._setup_content_grid_scrollbar = function(self, grid, widget_id, grid_scenegraph_id, grid_pivot_scenegraph_id)
    local widgets_by_name = self._widgets_by_name
    local scrollbar_widget = widgets_by_name[widget_id]

    -- Apply DMF scrolling speed setting if available
    if DMF:get("dmf_options_scrolling_speed") and widgets_by_name["scrollbar"] then
        widgets_by_name["scrollbar"].content.scroll_speed = DMF:get("dmf_options_scrolling_speed")
    end

    grid:assign_scrollbar(scrollbar_widget, grid_pivot_scenegraph_id, grid_scenegraph_id)
    grid:set_scrollbar_progress(0)
end

-- Set up the entries configuration for the history view
UptimeHistoryView._setup_entries_config = function(self, scan_dir)
    -- Clear existing widgets if any
    if self._entry_content_widgets then
        for i = 1, #self._entry_content_widgets do
            local widget = self._entry_content_widgets[i]
            self:_unregister_widget_name(widget.name)
        end
        self._entry_content_widgets = {}
    end

    -- Get all uptime history entries from the data handler
    local entries, entries_by_title, default_entry = self._data_handler:get_list_entries(scan_dir)

    -- Set default entry if available
    self._default_entry = default_entry

    -- Set up the grid and widgets
    local scenegraph_id = "grid_content_pivot"
    local callback_name = "cb_on_entry_pressed"
    self._entry_content_widgets, self._entry_alignment_list = self:_setup_list_entry_widgets(entries, scenegraph_id, callback_name)

    -- Configure grid and scrollbar
    local scrollbar_widget_id = "scrollbar"
    local grid_scenegraph_id = "background"
    local grid_pivot_scenegraph_id = "grid_content_pivot"
    local grid_spacing = self._settings.grid_spacing
    self._entries_content_grid = self:_setup_grid(self._entry_content_widgets, self._entry_alignment_list, grid_scenegraph_id, grid_spacing, true)
    self:_setup_content_grid_scrollbar(self._entries_content_grid, scrollbar_widget_id, grid_scenegraph_id, grid_pivot_scenegraph_id)

    -- Set up navigation
    self._navigation_widgets = { self._entry_content_widgets }
    self._navigation_grids = { self._entries_content_grid }
end

-- Set up a grid with the given widgets and settings
UptimeHistoryView._setup_grid = function(self, widgets, alignment_list, grid_scenegraph_id, spacing, use_is_focused)
    local ui_scenegraph = self._ui_scenegraph
    local direction = "down"
    local grid = UIWidgetGrid:new(widgets, alignment_list, ui_scenegraph, grid_scenegraph_id, direction, spacing, nil, use_is_focused)

    -- Apply render scale to the grid
    grid:set_render_scale(self._render_scale)

    return grid
end

-- Create widgets from content entries and set up their alignment
UptimeHistoryView._setup_list_entry_widgets = function(self, entries, scenegraph_id, callback_name)
    local widget_definitions = {}
    local widgets = {}
    local alignment_list = {}
    local amount = #entries

    -- Process entries in reverse order (newest first)
    for i = amount, 1, -1 do
        local entry = entries[i]
        local widget_type = entry.widget_type
        local template = self._blueprints[widget_type]
        local size = template.size
        local widget = nil

        -- Create widget definition if not already created for this type
        if template.pass_template and not widget_definitions[widget_type] then
            widget_definitions[widget_type] = UIWidget.create_definition(
                    template.pass_template,
                    scenegraph_id,
                    nil,
                    size
            )
        end

        -- Create and initialize the widget
        local widget_definition = widget_definitions[widget_type]
        if widget_definition then
            local name = scenegraph_id .. "_widget_" .. i
            widget = self:_create_widget(name, widget_definition)

            -- Initialize widget with template
            if template.init then
                template.init(self, widget, entry, callback_name)
            end

            widgets[#widgets + 1] = widget
        end

        -- Add to alignment list (either the widget or a placeholder with size)
        alignment_list[#alignment_list + 1] = widget or { size = size }
    end

    return widgets, alignment_list
end

-- Update the grid navigation selection based on cursor or keyboard navigation
UptimeHistoryView._update_grid_navigation_selection = function(self)
    local selected_column_index = self._selected_navigation_column_index
    local selected_row_index = self._selected_navigation_row_index

    -- Handle cursor navigation
    if self._using_cursor_navigation then
        -- Clear selection when using cursor
        if selected_row_index or selected_column_index then
            self:_set_selected_navigation_widget(nil)
        end
    else
        -- Handle keyboard navigation
        local navigation_widgets = self._navigation_widgets[selected_column_index]
        local selected_widget = navigation_widgets and navigation_widgets[selected_row_index] or self._selected_settings_widget

        if selected_widget then
            -- Ensure widget is properly selected in grid
            local selected_grid = self._navigation_grids[selected_column_index]
            if not selected_grid or not selected_grid:selected_grid_index() then
                self:_set_selected_navigation_widget(selected_widget)
            end
        elseif navigation_widgets or self._settings_content_widgets then
            -- Set default widget if none selected
            self:_set_default_navigation_widget()
        elseif self._default_entry then
            -- Present default entry if available
            self:present_entry_widgets(self._default_entry)
        end
    end
end

-- Change the navigation to a specific column
UptimeHistoryView._change_navigation_column = function(self, column_index)
    local navigation_widgets = self._navigation_widgets
    local num_columns = #navigation_widgets

    -- Validate column index and prevent multiple changes in same frame
    if column_index < 1 or num_columns < column_index or self._navigation_column_changed_this_frame then
        return false
    end

    -- Mark that we've changed column this frame
    self._navigation_column_changed_this_frame = true

    -- Get widgets in the target column
    local widgets = navigation_widgets[column_index]

    -- First try to find a widget that's already selected
    for i = 1, #widgets do
        local widget = widgets[i]
        local hotspot = widget.content.hotspot or widget.content.button_hotspot

        if hotspot and hotspot.is_selected then
            self:_set_selected_navigation_widget(widget)
            return true
        end
    end

    -- If no widget is selected, find the first visible one based on scrollbar position
    local navigation_grid = self._navigation_grids[column_index]
    local scrollbar_progress = navigation_grid:scrollbar_progress()

    for i = 1, #widgets do
        local widget = widgets[i]
        local hotspot = widget.content.hotspot or widget.content.button_hotspot

        if hotspot then
            local scroll_position = navigation_grid:get_scrollbar_percentage_by_index(i) or 0

            if scrollbar_progress <= scroll_position then
                self:_set_selected_navigation_widget(widget)
                return true
            end
        end
    end

    return false
end

-- Set the default navigation widget by trying each column
UptimeHistoryView._set_default_navigation_widget = function(self)
    local navigation_widgets = self._navigation_widgets

    -- Try each column until we successfully change to one
    for i = 1, #navigation_widgets do
        if self:_change_navigation_column(i) then
            return
        end
    end
end

-- Set the selected navigation widget and update all related UI elements
UptimeHistoryView._set_selected_navigation_widget = function(self, widget)
    local widget_name = widget and widget.name
    local selected_row, selected_column = nil, nil
    local navigation_widgets = self._navigation_widgets

    -- Process each column to find and focus the selected widget
    for column_index = 1, #navigation_widgets do
        local widgets = navigation_widgets[column_index]
        local _, focused_grid_index = self:_set_focused_grid_widget(widgets, widget_name)

        -- If we found the widget in this column, mark it as selected
        if focused_grid_index then
            self:_set_selected_grid_widget(widgets, widget_name)
            selected_row = focused_grid_index
            selected_column = column_index
        end
    end

    -- Update all navigation grids with the new selection
    local navigation_grids = self._navigation_grids
    for column_index = 1, #navigation_grids do
        local is_selected_column = column_index == selected_column
        local navigation_grid = navigation_grids[column_index]

        -- Only set grid index for the selected column
        local grid_index = is_selected_column and selected_row or nil
        navigation_grid:select_grid_index(
                grid_index,
                nil,
                nil,
                column_index == ENTRIES_GRID
        )
    end

    -- Store the selected indices for future reference
    self._selected_navigation_row_index = selected_row
    self._selected_navigation_column_index = selected_column
end

-- Set focus state for widgets in a grid based on the widget name
UptimeHistoryView._set_focused_grid_widget = function(self, widgets, widget_name)
    local focused_widget = nil
    local focused_grid_index = nil

    -- Process all widgets in the grid
    for i = 1, #widgets do
        local widget = widgets[i]
        local content = widget.content
        local hotspot = content.hotspot or content.button_hotspot

        if hotspot then
            -- Set focus state based on widget name match
            if widget.name == widget_name then
                hotspot.is_focused = true
                focused_widget = widget
                focused_grid_index = i
            else
                hotspot.is_focused = false
            end
        end
    end

    return focused_widget, focused_grid_index
end

-- Set selection state for widgets in a grid based on the widget name
UptimeHistoryView._set_selected_grid_widget = function(self, widgets, widget_name)
    -- Process all widgets in the grid
    for i = 1, #widgets do
        local widget = widgets[i]
        local content = widget.content
        local hotspot = content.hotspot or content.button_hotspot

        if hotspot then
            -- Set selection state based on widget name match
            hotspot.is_selected = (widget.name == widget_name)
        end
    end
end

UptimeHistoryView.on_exit = function(self)
    if self._input_legend_element then
        self._input_legend_element = nil
        self:_remove_element("input_legend")
    end

    if self._popup_id then
        Managers.event:trigger("event_remove_ui_popup", self._popup_id)
    end

    if self._ui_offscreen_renderer then
        self._ui_offscreen_renderer = nil

        Managers.ui:destroy_renderer(self.__class_name .. "_ui_offscreen_renderer")

        local offscreen_world = self._offscreen_world
        local offscreen_viewport_name = self._offscreen_viewport_name

        ScriptWorld.destroy_viewport(offscreen_world, offscreen_viewport_name)
        Managers.ui:destroy_world(offscreen_world)

        self._offscreen_viewport = nil
        self._offscreen_viewport_name = nil
        self._offscreen_world = nil
    end

    mod:close_view()

    UptimeHistoryView.super.on_exit(self)
end

-- Callback for when an entry is pressed in the history view
UptimeHistoryView.cb_on_entry_pressed = function(self, widget, entry)
    -- Load the uptime history entry from file
    self.entry = entry.history_entry
    self:present_entry_widgets()
end

-- Callback for when the back button is pressed
UptimeHistoryView.cb_on_back_pressed = function(self)
    -- Close the uptime history view
    self.ui_manager:close_view("uptime_history_view")
end

-- Callback for when the delete button is pressed
UptimeHistoryView.cb_delete_pressed = function(self)
    if self._data_handler:delete_entry(self.entry) then
        self.entry = nil
        mod:close_view()
        self:_setup_entries_config()
    end
end

-- Callback for when the reload cache button is pressed
UptimeHistoryView.cb_reload_cache_pressed = function(self)
    -- Clear current entry and reload with scan_dir=true to force refresh
    self.entry = nil
    self:_setup_entries_config(true)
end

-- Main update function for the view
UptimeHistoryView.update = function(self, dt, t, input_service, view_data)
    local drawing_view = view_data and view_data.drawing_view
    local using_cursor_navigation = Managers.ui:using_cursor_navigation()

    -- Handle keybinding state
    if self:_handling_keybinding() then
        -- Close keybind popup if view is not drawing or not using cursor
        if not drawing_view or not using_cursor_navigation then
            self:close_keybind_popup(true)
        end

        -- Disable input while handling keybinding
        input_service = input_service:null_service()
    end

    -- Process keybind rebinding
    self:_handle_keybind_rebind(dt, t, input_service)

    -- Handle keybind popup closing timer
    local close_keybind_popup_duration = self._close_keybind_popup_duration
    if close_keybind_popup_duration then
        if close_keybind_popup_duration < 0 then
            -- Timer expired, close popup
            self._close_keybind_popup_duration = nil
            self:close_keybind_popup(true)
        else
            -- Update timer
            self._close_keybind_popup_duration = close_keybind_popup_duration - dt
        end
    end

    -- Update grid length if changed
    local grid_length = self._entries_content_grid:length()
    if grid_length ~= self._grid_length then
        self._grid_length = grid_length
    end

    -- Update grid with appropriate input service
    local entry_grid_is_focused = self._selected_navigation_column_index == ENTRIES_GRID
    local entry_grid_input_service = entry_grid_is_focused and input_service or input_service:null_service()
    self._entries_content_grid:update(dt, t, entry_grid_input_service)

    -- Update entry widgets
    self:_update_entry_content_widgets(dt, t)

    -- Call parent update
    return UptimeHistoryView.super.update(self, dt, t, input_service)
end

-- Update the entry content widgets (selection, focus, etc.)
UptimeHistoryView._update_entry_content_widgets = function(self, dt, t)
    local entry_content_widgets = self._entry_content_widgets
    if not entry_content_widgets then
        return
    end

    local is_focused_grid = self._selected_navigation_column_index == ENTRIES_GRID
    local selected_entry_widget = self._selected_entry_widget

    -- Process each widget in the entry grid
    for i = 1, #entry_content_widgets do
        local widget = entry_content_widgets[i]
        local hotspot = widget.content.hotspot

        if hotspot.is_focused then
            -- Mark focused widget as selected
            hotspot.is_selected = true

            -- If this is a new selection, call the select function
            if widget ~= selected_entry_widget then
                self._selected_entry_widget = widget
                local entry = widget.content.entry

                if entry and entry.select_function then
                    entry.select_function(self, widget, entry)
                end
            end
        elseif is_focused_grid then
            -- Clear selection for non-focused widgets when grid is focused
            hotspot.is_selected = false
        end
    end
end

-- Handle keybind rebinding process
UptimeHistoryView._handle_keybind_rebind = function(self, dt, t, input_service)
    -- Only process if we're currently handling a keybind
    if not self._handling_keybind then
        return
    end

    -- Check for key watch results
    local input_manager = Managers.input
    local results = input_manager:key_watch_result()

    if results then
        local entry = self._active_keybind_entry
        local value = entry.value

        -- Activate the keybind and check if we can close
        local can_close = entry.on_activated(results, value)

        if can_close then
            -- Close the popup if activation was successful
            self:close_keybind_popup()
        else
            -- Restart key watch with the entry's devices
            Managers.input:stop_key_watch()
            Managers.input:start_key_watch(entry.devices)
        end
    end
end

-- Check if we're currently handling a keybinding
UptimeHistoryView._handling_keybinding = function(self)
    -- We're handling a keybind if either actively binding or in the closing animation
    return self._handling_keybind or self._close_keybind_popup_duration ~= nil
end

-- Close the keybind popup
UptimeHistoryView.close_keybind_popup = function(self, force_close)
    if force_close then
        -- Immediately close the popup
        Managers.input:stop_key_watch()

        -- Remove the popup element
        local reference_name = "keybind_popup"
        self._keybind_popup = nil
        self:_remove_element(reference_name)

        -- Allow the view to be exited
        self:set_can_exit(true, true)
    else
        -- Start the closing animation
        self._close_keybind_popup_duration = 0.2
    end

    -- Reset keybind state
    self._handling_keybind = false
    self._active_keybind_entry = nil
    self._active_keybind_widget = nil
end

-- Main draw function for the view
UptimeHistoryView.draw = function(self, dt, t, input_service, layer)
    -- Draw main UI elements
    self:_draw_elements(dt, t, self._ui_renderer, self._render_settings, input_service)

    -- Draw grid content
    local widgets_by_name = self._widgets_by_name
    local grid_interaction_widget = widgets_by_name.grid_interaction
    self:_draw_grid(
            self._entries_content_grid,
            self._entry_content_widgets,
            grid_interaction_widget,
            dt,
            t,
            input_service
    )

    -- Call parent draw method
    UptimeHistoryView.super.draw(self, dt, t, input_service, layer)
end

-- Draw grid widgets with proper interaction handling
UptimeHistoryView._draw_grid = function(self, grid, widgets, interaction_widget, dt, t, input_service)
    -- Create null input service for non-interactive elements
    local null_input_service = input_service:null_service()

    -- Get rendering resources
    local render_settings = self._render_settings
    local ui_renderer = self._ui_offscreen_renderer
    local ui_scenegraph = self._ui_scenegraph

    -- Begin rendering pass
    UIRenderer.begin_pass(ui_renderer, ui_scenegraph, input_service, dt, render_settings)

    -- Draw each widget in the grid
    for j = 1, #widgets do
        local widget = widgets[j]

        -- Skip selected settings widget
        if widget ~= self._selected_settings_widget then
            -- Use null input service if we have a selected settings widget
            if self._selected_settings_widget then
                ui_renderer.input_service = null_input_service
            end
            if grid:is_widget_visible(widget) then
                UIWidget.draw(widget, ui_renderer)
            end
        end
    end

    -- End rendering pass
    UIRenderer.end_pass(ui_renderer)
end

return UptimeHistoryView