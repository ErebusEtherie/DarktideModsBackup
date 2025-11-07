# Creating a Grid with UIWidgetGrid API

This guide explains how to create a grid of UI elements using the UIWidgetGrid API in Warhammer 40,000 DARKTIDE. The guide focuses on the minimal necessary setup to create a functional grid.

## Table of Contents

1. [Required Dependencies](#required-dependencies)
2. [Basic Grid Structure](#basic-grid-structure)
3. [Step 1: Setting Up the Scenegraph](#step-1-setting-up-the-scenegraph)
4. [Step 2: Creating Widget Templates](#step-2-creating-widget-templates)
5. [Step 3: Creating and Configuring Widgets](#step-3-creating-and-configuring-widgets)
6. [Step 4: Initializing the Grid](#step-4-initializing-the-grid)
7. [Step 5: Setting Up Scrollbar (Optional)](#step-5-setting-up-scrollbar-optional)
8. [Step 6: Drawing the Grid](#step-6-drawing-the-grid)
9. [Complete Example](#complete-example)

## Required Dependencies

To use the UIWidgetGrid API, you need to import the following dependencies:

```lua
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIWidgetGrid = mod:original_require("scripts/ui/widget_logic/ui_widget_grid")
local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
```

If you want to include a scrollbar, you'll also need:

```lua
local ScrollbarPassTemplates = mod:original_require("scripts/ui/pass_templates/scrollbar_pass_templates")
```

## Basic Grid Structure

A grid in the UIWidgetGrid API consists of:

1. **Scenegraph**: Defines the layout and positioning of UI elements
2. **Widgets**: The individual UI elements that make up the grid
3. **Alignment List**: Defines how widgets are positioned within the grid
4. **Grid Object**: Manages the widgets, handles scrolling, and provides navigation

## Step 1: Setting Up the Scenegraph

The scenegraph defines the layout and positioning of UI elements. For a grid, you need at least:

1. A container node for the grid
2. A pivot node for the grid content (for scrolling)

Here's a minimal scenegraph definition:

```lua
local scenegraph_definition = {
    -- Root screen element
    screen = UIWorkspaceSettings.screen,
    
    -- Grid container
    grid_container = {
        vertical_alignment = "top",
        parent = "screen",
        horizontal_alignment = "left",
        size = {500, 760}, -- Width and height of the grid
        position = {180, 240, 1} -- X, Y, Z position
    },
    
    -- Grid content pivot (for scrolling)
    grid_content_pivot = {
        vertical_alignment = "top",
        parent = "grid_container",
        horizontal_alignment = "left",
        size = {0, 0},
        position = {0, 0, 1}
    },
    
    -- Scrollbar (optional)
    scrollbar = {
        vertical_alignment = "center",
        parent = "grid_container",
        horizontal_alignment = "right",
        size = {10, 760}, -- Width and height of scrollbar
        position = {50, 0, 1}
    }
}
```

## Step 2: Creating Widget Templates

Widget templates define the appearance and behavior of widgets in the grid. Here's a minimal widget template:

```lua
local widget_template = {
    -- Widget size
    size = {500, 75},
    
    -- Pass template (defines how the widget is rendered)
    pass_template = {
        -- Hotspot (clickable area)
        {
            style_id = "hotspot",
            pass_type = "hotspot",
            content_id = "hotspot",
            content = {
                use_is_focused = true,
            },
            style = {
                anim_hover_speed = 8,
                anim_select_speed = 8,
                anim_focus_speed = 8,
            }
        },
        
        -- Background
        {
            pass_type = "rect",
            style_id = "background",
            style = {
                color = {160, 0, 0, 0}
            }
        },
        
        -- Text
        {
            pass_type = "text",
            style_id = "text",
            value_id = "text",
            style = {
                text_vertical_alignment = "center",
                text_horizontal_alignment = "left",
                offset = {10, 0, 1},
                font_size = 20,
                font_type = "machine_medium",
                text_color = Color.terminal_text_body(255, true)
            }
        }
    },
    
    -- Initialization function
    init = function(parent, widget, data, callback_name)
        local content = widget.content
        local hotspot = content.hotspot
        
        -- Set up pressed callback
        hotspot.pressed_callback = function()
            callback(parent, callback_name, widget, data)()
        end
        
        -- Set up text content
        content.text = data.text
        
        -- Store data reference
        content.data = data
    end
}
```

## Step 3: Creating and Configuring Widgets

To create widgets for the grid, you need to:

1. Create widget definitions based on templates
2. Create and initialize widgets
3. Build an alignment list for positioning widgets

Here's a minimal implementation:

```lua
local function setup_content_widgets(self, items, scenegraph_id, callback_name)
    local widget_definitions = {}
    local widgets = {}
    local alignment_list = {}
    
    for i = 1, #items do
        local item = items[i]
        local widget_type = "grid_item" -- Use your widget template name
        local template = self._templates[widget_type]
        local size = template.size
        
        -- Create widget definition if not already created
        if not widget_definitions[widget_type] then
            widget_definitions[widget_type] = UIWidget.create_definition(
                template.pass_template,
                scenegraph_id,
                nil,
                size
            )
        end
        
        -- Create and initialize widget
        local widget_definition = widget_definitions[widget_type]
        local name = scenegraph_id .. "_widget_" .. i
        local widget = self:_create_widget(name, widget_definition)
        
        -- Initialize widget with template
        if template.init then
            template.init(self, widget, item, callback_name)
        end
        
        widgets[#widgets + 1] = widget
        alignment_list[#alignment_list + 1] = widget
    end
    
    return widgets, alignment_list
end
```

## Step 4: Initializing the Grid

To initialize the grid, you need to:

1. Create a new UIWidgetGrid object
2. Configure the grid properties

Here's a minimal implementation:

```lua
local function setup_grid(self, widgets, alignment_list, grid_scenegraph_id, spacing, use_is_focused)
    local ui_scenegraph = self._ui_scenegraph
    local direction = "down" -- Can be "down", "right", "up", or "left"
    
    -- Create the grid
    local grid = UIWidgetGrid:new(
        widgets,             -- Widgets to include in the grid
        alignment_list,      -- How to position widgets
        ui_scenegraph,       -- Scenegraph for layout
        grid_scenegraph_id,  -- ID of the grid container in the scenegraph
        direction,           -- Direction of the grid
        spacing,             -- Spacing between items (e.g., {0, 10})
        nil,                 -- Optional custom sorting function
        use_is_focused       -- Whether to use focus state
    )
    
    -- Apply render scale if needed
    if self._render_scale then
        grid:set_render_scale(self._render_scale)
    end
    
    return grid
end
```

## Step 5: Setting Up Scrollbar (Optional)

If you want to add a scrollbar to the grid, you need to:

1. Create a scrollbar widget
2. Assign it to the grid

Here's a minimal implementation:

```lua
local function setup_scrollbar(self, grid, scrollbar_widget_id, grid_scenegraph_id, grid_pivot_scenegraph_id)
    local scrollbar_widget = self._widgets_by_name[scrollbar_widget_id]
    
    -- Assign scrollbar to grid
    grid:assign_scrollbar(
        scrollbar_widget,
        grid_pivot_scenegraph_id,
        grid_scenegraph_id
    )
    
    -- Set initial scrollbar position
    grid:set_scrollbar_progress(0)
end
```

## Step 6: Drawing the Grid

To draw the grid, you need to:

1. Update the grid with input
2. Draw the widgets in the grid

Here's a minimal implementation:

```lua
local function draw_grid(self, grid, widgets, dt, t, input_service)
    -- Get rendering resources
    local render_settings = self._render_settings
    local ui_renderer = self._ui_renderer
    local ui_scenegraph = self._ui_scenegraph
    
    -- Begin rendering pass
    UIRenderer.begin_pass(ui_renderer, ui_scenegraph, input_service, dt, render_settings)
    
    -- Draw each widget in the grid
    for i = 1, #widgets do
        local widget = widgets[i]
        
        -- Only draw visible widgets
        if grid:is_widget_visible(widget) then
            UIWidget.draw(widget, ui_renderer)
        end
    end
    
    -- End rendering pass
    UIRenderer.end_pass(ui_renderer)
end
```

In your main update function, you should update the grid:

```lua
function YourView:update(dt, t, input_service)
    -- Update grid
    self._grid:update(dt, t, input_service)
    
    -- Rest of your update code...
end
```

And in your main draw function, you should draw the grid:

```lua
function YourView:draw(dt, t, input_service)
    -- Draw grid
    self:draw_grid(
        self._grid,
        self._widgets,
        dt,
        t,
        input_service
    )
    
    -- Rest of your draw code...
end
```

## Complete Example

Here's a complete minimal example of creating a grid:

```lua
local mod = get_mod("your_mod")

-- Required dependencies
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIWidgetGrid = mod:original_require("scripts/ui/widget_logic/ui_widget_grid")
local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local ScrollbarPassTemplates = mod:original_require("scripts/ui/pass_templates/scrollbar_pass_templates")
local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")

-- Create a view class
local YourView = class("YourView")

-- Initialize the view
function YourView:init()
    -- Define scenegraph
    self._scenegraph_definition = {
        screen = UIWorkspaceSettings.screen,
        
        grid_container = {
            vertical_alignment = "top",
            parent = "screen",
            horizontal_alignment = "left",
            size = {500, 760},
            position = {180, 240, 1}
        },
        
        grid_content_pivot = {
            vertical_alignment = "top",
            parent = "grid_container",
            horizontal_alignment = "left",
            size = {0, 0},
            position = {0, 0, 1}
        },
        
        scrollbar = {
            vertical_alignment = "center",
            parent = "grid_container",
            horizontal_alignment = "right",
            size = {10, 760},
            position = {50, 0, 1}
        }
    }
    
    -- Define widget templates
    self._templates = {
        grid_item = {
            size = {500, 75},
            
            pass_template = {
                {
                    style_id = "hotspot",
                    pass_type = "hotspot",
                    content_id = "hotspot",
                    content = {
                        use_is_focused = true,
                    },
                    style = {
                        anim_hover_speed = 8,
                        anim_select_speed = 8,
                        anim_focus_speed = 8,
                    }
                },
                
                {
                    pass_type = "rect",
                    style_id = "background",
                    style = {
                        color = {160, 0, 0, 0}
                    }
                },
                
                {
                    pass_type = "text",
                    style_id = "text",
                    value_id = "text",
                    style = {
                        text_vertical_alignment = "center",
                        text_horizontal_alignment = "left",
                        offset = {10, 0, 1},
                        font_size = 20,
                        font_type = "machine_medium",
                        text_color = Color.terminal_text_body(255, true)
                    }
                }
            },
            
            init = function(parent, widget, data, callback_name)
                local content = widget.content
                local hotspot = content.hotspot
                
                hotspot.pressed_callback = function()
                    callback(parent, callback_name, widget, data)()
                end
                
                content.text = data.text
                content.data = data
            end
        }
    }
    
    -- Define widget definitions
    self._widget_definitions = {
        scrollbar = UIWidget.create_definition(ScrollbarPassTemplates.default_scrollbar, "scrollbar")
    }
    
    -- Initialize UI
    self:_setup_ui()
end

-- Set up UI
function YourView:_setup_ui()
    -- Create UI scenegraph
    self._ui_scenegraph = UISceneGraph.init_scenegraph(self._scenegraph_definition)
    
    -- Create widgets
    self._widgets_by_name = {}
    self._widgets = {}
    
    -- Create scrollbar widget
    local scrollbar_widget = UIWidget.init(self._widget_definitions.scrollbar)
    self._widgets_by_name.scrollbar = scrollbar_widget
    self._widgets[#self._widgets + 1] = scrollbar_widget
    
    -- Create sample data
    local items = {
        { text = "Item 1" },
        { text = "Item 2" },
        { text = "Item 3" },
        { text = "Item 4" },
        { text = "Item 5" },
        { text = "Item 6" },
        { text = "Item 7" },
        { text = "Item 8" },
        { text = "Item 9" },
        { text = "Item 10" }
    }
    
    -- Set up grid widgets
    local scenegraph_id = "grid_content_pivot"
    local callback_name = "cb_on_item_pressed"
    self._grid_widgets, self._grid_alignment_list = self:_setup_content_widgets(items, scenegraph_id, callback_name)
    
    -- Set up grid
    local grid_scenegraph_id = "grid_container"
    local grid_pivot_scenegraph_id = "grid_content_pivot"
    local grid_spacing = {0, 10}
    self._grid = self:_setup_grid(self._grid_widgets, self._grid_alignment_list, grid_scenegraph_id, grid_spacing, true)
    
    -- Set up scrollbar
    self:_setup_scrollbar(self._grid, "scrollbar", grid_scenegraph_id, grid_pivot_scenegraph_id)
end

-- Set up content widgets
function YourView:_setup_content_widgets(items, scenegraph_id, callback_name)
    local widget_definitions = {}
    local widgets = {}
    local alignment_list = {}
    
    for i = 1, #items do
        local item = items[i]
        local widget_type = "grid_item"
        local template = self._templates[widget_type]
        local size = template.size
        
        if not widget_definitions[widget_type] then
            widget_definitions[widget_type] = UIWidget.create_definition(
                template.pass_template,
                scenegraph_id,
                nil,
                size
            )
        end
        
        local widget_definition = widget_definitions[widget_type]
        local name = scenegraph_id .. "_widget_" .. i
        local widget = UIWidget.init(widget_definition)
        widget.name = name
        
        if template.init then
            template.init(self, widget, item, callback_name)
        end
        
        widgets[#widgets + 1] = widget
        alignment_list[#alignment_list + 1] = widget
        self._widgets[#self._widgets + 1] = widget
    end
    
    return widgets, alignment_list
end

-- Set up grid
function YourView:_setup_grid(widgets, alignment_list, grid_scenegraph_id, spacing, use_is_focused)
    local direction = "down"
    
    local grid = UIWidgetGrid:new(
        widgets,
        alignment_list,
        self._ui_scenegraph,
        grid_scenegraph_id,
        direction,
        spacing,
        nil,
        use_is_focused
    )
    
    return grid
end

-- Set up scrollbar
function YourView:_setup_scrollbar(grid, scrollbar_widget_id, grid_scenegraph_id, grid_pivot_scenegraph_id)
    local scrollbar_widget = self._widgets_by_name[scrollbar_widget_id]
    
    grid:assign_scrollbar(
        scrollbar_widget,
        grid_pivot_scenegraph_id,
        grid_scenegraph_id
    )
    
    grid:set_scrollbar_progress(0)
end

-- Item pressed callback
function YourView:cb_on_item_pressed(widget, data)
    mod:echo("Item pressed: " .. data.text)
end

-- Update function
function YourView:update(dt, t, input_service)
    -- Update grid
    self._grid:update(dt, t, input_service)
end

-- Draw function
function YourView:draw(dt, t, input_service)
    -- Get rendering resources
    local render_settings = {
        alpha_multiplier = 1
    }
    local ui_renderer = self._ui_renderer
    
    -- Begin rendering pass
    UIRenderer.begin_pass(ui_renderer, self._ui_scenegraph, input_service, dt, render_settings)
    
    -- Draw widgets
    for i = 1, #self._widgets do
        local widget = self._widgets[i]
        UIWidget.draw(widget, ui_renderer)
    end
    
    -- Draw grid widgets
    for i = 1, #self._grid_widgets do
        local widget = self._grid_widgets[i]
        
        if self._grid:is_widget_visible(widget) then
            UIWidget.draw(widget, ui_renderer)
        end
    end
    
    -- End rendering pass
    UIRenderer.end_pass(ui_renderer)
end

return YourView
```

This example provides a minimal setup for creating a grid with the UIWidgetGrid API. You can customize it to fit your specific needs by modifying the widget templates, adding more functionality, or changing the layout.