--[[
  Uptime History View Settings
  
  This file defines the configuration settings for the uptime history view,
  including dimensions, spacing, and visual properties.
--]]

local uptime_history_view_settings = {
    -- ===== UI Layout Settings =====
    -- Width of the scrollbar in pixels
    scrollbar_width = 10,
    
    -- Maximum number of dropdown options to show at once
    max_visible_dropdown_options = 5,
    
    -- Spacing for indented content (in pixels)
    indentation_spacing = 40,
    
    -- ===== Grid Settings =====
    -- Size of the content grid (width, height) in pixels
    grid_size = {500, 760},
    
    -- Spacing between grid items (horizontal, vertical) in pixels
    grid_spacing = {0, 10},
    
    -- Size of the blur edge around the grid (for visual polish)
    grid_blur_edge_size = {8, 8},
    
    -- ===== Visual Settings =====
    -- Shading environment to use for the view
    shading_environment = "content/shading_environments/ui/system_menu",
}

return settings("UptimeHistoryViewSettings", uptime_history_view_settings)