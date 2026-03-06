--[[
    HUD Element: Progress Bar
    
    Displays mission progress with medicae station markers.
    - Vertical bar on the screen edge (configurable)
    - Medicae markers with charge counts
    - Current position marker with percentage
    - Distance remaining above bar
    - Fully customizable via theme presets
]]

local mod = get_mod("mission_progress")

local UIWidget = require("scripts/managers/ui/ui_widget")

-- Load definitions fresh each time (not cached at module level)
local function load_definitions()
    -- Force fresh load by clearing any cached version
    package.loaded["mission_progress/scripts/hud/hud_element_progress_bar_definitions"] = nil
    return mod:io_dofile("mission_progress/scripts/hud/hud_element_progress_bar_definitions")
end

-- Constants that don't change
local max_medicae_markers = 10
local max_beacon_markers = 12
local max_grimoire_markers = 6
local max_scripture_markers = 6

-- ############################################
-- HUD Element Class
-- ############################################

local HudElementProgressBar = class("HudElementProgressBar", "HudElementBase")

function HudElementProgressBar:init(parent, draw_layer, start_scale)
    -- Load fresh definitions with current theme settings
    local definitions = load_definitions()
    
    local ok, err = pcall(function()
        HudElementProgressBar.super.init(self, parent, draw_layer, start_scale, definitions)
    end)
    
    if not ok then
        return
    end
    
    self._definitions = definitions
    self._widgets_by_name = {}
    self._update_timer = 0
    self._update_interval = 0.2
    self._cached_medicae = {}
    self._cached_beacons = {}
    self._cached_grimoires = {}
    self._medicae_cache_timer = 0
    self._medicae_cache_interval = 5.0
    self._first_update = true
    self._cached_progress = 0  -- Cached progress to prevent glitches
    self._max_progress = 0     -- Track maximum progress (can't go backwards)
    
    -- Get initial theme (will be refreshed each update cycle)
    local theme = mod:get_current_theme()
    self._bar_height = theme.bar_height or 300
    self._bar_width = theme.bar_width or 10
    
    self:_create_widgets(definitions)
end

function HudElementProgressBar:_create_widgets(definitions)
    local widgets = {}
    local widgets_by_name = {}
    
    if not definitions or not definitions.widget_definitions then
        return
    end
    
    for name, definition in pairs(definitions.widget_definitions) do
        local widget = self:_create_widget(name, definition)
        widgets[#widgets + 1] = widget
        widgets_by_name[name] = widget
    end
    
    self._widgets = widgets
    self._widgets_by_name = widgets_by_name
end

function HudElementProgressBar:destroy(ui_renderer)
    HudElementProgressBar.super.destroy(self, ui_renderer)
end

function HudElementProgressBar:update(dt, t, ui_renderer, render_settings, input_service)
    HudElementProgressBar.super.update(self, dt, t, ui_renderer, render_settings, input_service)
    
    -- Check visibility - just check should_show_hud which handles everything
    if not mod:should_show_hud() then
        self:_hide_all()
        return
    end
    
    -- Initial medicae scan on first update
    if self._first_update then
        self._first_update = false
        self:_refresh_medicae_cache()
    end
    
    -- Throttle updates
    self._update_timer = self._update_timer + dt
    if self._update_timer >= self._update_interval then
        self._update_timer = 0
        self:_update_all()
    end
    
    -- Refresh medicae cache periodically
    self._medicae_cache_timer = self._medicae_cache_timer + dt
    if self._medicae_cache_timer >= self._medicae_cache_interval then
        self._medicae_cache_timer = 0
        self:_refresh_medicae_cache()
    end
end

function HudElementProgressBar:_hide_all()
    for _, widget in pairs(self._widgets_by_name) do
        if widget.content then
            widget.content.visible = false
        end
    end
end

function HudElementProgressBar:_refresh_medicae_cache()
    mod:find_medicae_stations()
    self._cached_medicae = mod:get_medicae_data()
    mod:find_respawn_beacons()
    self._cached_beacons = mod:get_beacon_data()
    mod:find_grimoires()
    self._cached_grimoires = mod:get_grimoire_data()
    mod:find_scriptures()
    self._cached_scriptures = mod:get_scripture_data()
end

-- Helper function to apply opacity to a color (ARGB format)
local function apply_opacity(color, opacity_percent)
    if not color or not opacity_percent then return color end
    local scale = opacity_percent / 100
    return {
        math.floor(color[1] * scale),  -- Alpha
        color[2],  -- R
        color[3],  -- G
        color[4],  -- B
    }
end

function HudElementProgressBar:_update_all()
    local widgets = self._widgets_by_name
    if not widgets then
        return
    end
    
    local ok, err = pcall(function()
        local raw_progress = mod:get_progress_percentage() or 0
        local total_distance = mod:get_total_path_length() or 0
        local traveled = mod:get_player_travel_distance() or 0
        local remaining = math.max(0, total_distance - traveled)
        
        -- Get fresh theme for colors and settings (allows live preset changes)
        local theme = mod:get_current_theme()
        local bar_h = theme.bar_height or 300
        local bar_w = theme.bar_width or 10
        local opacity = theme.opacity or 100
        local is_horiz = theme.orientation == "horizontal"
        local invert = theme.invert_direction or false
        local invert_tags = theme.invert_tags or false
        local font_sz = theme.font_size or 14
        local marker_sz = theme.marker_size or 8
        
        -- Update scenegraph if bar height changed (for dynamic theme switching)
        if bar_h ~= self._bar_height and self._ui_scenegraph then
            local scenegraph = self._ui_scenegraph
            -- Update progress_bar_container size
            if scenegraph.progress_bar_container then
                scenegraph.progress_bar_container.size[2] = bar_h + 60
            end
            -- Update progress_bar size
            if scenegraph.progress_bar then
                scenegraph.progress_bar.size[2] = bar_h
                scenegraph.progress_bar.size[1] = bar_w
            end
            -- Update background widget style sizes
            local bg_widget = widgets.progress_bar_bg
            if bg_widget and bg_widget.style then
                if bg_widget.style.background then
                    bg_widget.style.background.size = { bar_w, bar_h }
                end
                if bg_widget.style.border_bottom then
                    bg_widget.style.border_bottom.offset[2] = bar_h - 1
                end
            end
        end
        self._bar_height = bar_h
        self._bar_width = bar_w
        
        -- Get display settings (override theme if explicitly set)
        local show_distance = mod:get_setting("show_distance", theme.show_distance ~= false)
        local show_percentage = mod:get_setting("show_percentage", theme.show_percentage ~= false)
        local show_medicae = mod:get_setting("show_medicae_markers", theme.show_medicae ~= false)
        local decimal_precision = mod:get_setting("decimal_precision", theme.decimal_precision or 1)
        
        -- Smooth progress: prevent large backwards jumps (terrain glitches)
        -- But allow normal movement in both directions
        local progress_diff = raw_progress - self._cached_progress
        if progress_diff >= -5 then
            -- Normal movement (forward or small backward) - update immediately
            self._cached_progress = raw_progress
            self._max_progress = math.max(self._max_progress, raw_progress)
        elseif raw_progress > self._max_progress then
            -- New max - always update
            self._cached_progress = raw_progress
            self._max_progress = raw_progress
        end
        -- Otherwise keep cached value (prevents large backward glitches)
        local progress = self._cached_progress or 0
        
        -- Clamp progress to valid range
        progress = math.max(0, math.min(100, progress))
        
        -- Show background and update colors from theme
        local bg_widget = widgets.progress_bar_bg
        if bg_widget and bg_widget.content then
            bg_widget.content.visible = true
            -- Update background color from theme
            if bg_widget.style then
                if bg_widget.style.background and theme.bar_bg then
                    bg_widget.style.background.color = apply_opacity(theme.bar_bg, opacity)
                end
                if bg_widget.style.border_left and theme.bar_border then
                    bg_widget.style.border_left.color = apply_opacity(theme.bar_border, opacity)
                end
                if bg_widget.style.border_right and theme.bar_border then
                    bg_widget.style.border_right.color = apply_opacity(theme.bar_border, opacity)
                end
                if bg_widget.style.border_top and theme.bar_border then
                    bg_widget.style.border_top.color = apply_opacity(theme.bar_border, opacity)
                end
                if bg_widget.style.border_bottom and theme.bar_border then
                    bg_widget.style.border_bottom.color = apply_opacity(theme.bar_border, opacity)
                end
            end
        end
        
        -- Update progress bar fill
        local fill_widget = widgets.progress_bar_fill
        if fill_widget and fill_widget.style and fill_widget.style.fill then
            -- Update fill color from theme
            if theme.bar_fill then
                fill_widget.style.fill.color = apply_opacity(theme.bar_fill, opacity)
            end
            -- Update fill size based on orientation
            if fill_widget.style.fill.size then
                local fill_amount = math.floor((progress / 100) * bar_h)
                fill_amount = math.max(0, math.min(fill_amount, bar_h - 2))
                
                if is_horiz then
                    -- Horizontal: width changes, height is bar thickness
                    fill_widget.style.fill.size[1] = fill_amount
                    fill_widget.style.fill.size[2] = bar_w - 2
                    -- Handle invert for horizontal
                    fill_widget.style.fill.horizontal_alignment = invert and "right" or "left"
                else
                    -- Vertical: height changes, width is bar thickness
                    fill_widget.style.fill.size[1] = bar_w - 2
                    fill_widget.style.fill.size[2] = fill_amount
                    -- Handle invert for vertical
                    fill_widget.style.fill.vertical_alignment = invert and "top" or "bottom"
                end
            end
            if fill_widget.content then
                fill_widget.content.visible = true
            end
        end
        
        -- Update distance text
        local distance_widget = widgets.distance_text
        if distance_widget and distance_widget.content then
            if show_distance then
                -- Update text color and size from theme
                if distance_widget.style and distance_widget.style.text then
                    if theme.text_secondary then
                        distance_widget.style.text.text_color = apply_opacity(theme.text_secondary, opacity)
                    end
                    distance_widget.style.text.font_size = font_sz
                end
                if remaining >= 1000 then
                    distance_widget.content.text = string.format("%.1fkm", remaining / 1000)
                else
                    distance_widget.content.text = string.format("%.0fm", remaining)
                end
                distance_widget.content.visible = true
            else
                distance_widget.content.visible = false
            end
        end
        
        -- Update current position marker (with %)
        local current_marker = widgets.current_position_marker
        if current_marker and current_marker.content then
            if show_percentage then
                -- Update marker colors and sizes from theme
                if current_marker.style then
                    if current_marker.style.arrow and theme.current_marker then
                        current_marker.style.arrow.color = apply_opacity(theme.current_marker, opacity)
                        -- Arrow size based on orientation
                        if is_horiz then
                            current_marker.style.arrow.size = { 3, bar_w }
                        else
                            current_marker.style.arrow.size = { bar_w, 3 }
                        end
                    end
                    if current_marker.style.text and theme.text_primary then
                        current_marker.style.text.text_color = apply_opacity(theme.text_primary, opacity)
                        current_marker.style.text.font_size = font_sz
                        -- Position text on opposite side from medicae markers
                        -- Default: horizontal = below bar (positive y), vertical = right of bar (positive x)
                        -- Invert Tags: flips to same side as medicae (swaps the offset sign)
                        if is_horiz then
                            local y_off = invert_tags and -(bar_w/2 + 10) or (bar_w/2 + 10)
                            current_marker.style.text.offset = { 0, y_off, 2 }
                        else
                            local x_off = invert_tags and -(bar_w/2 + 30) or (bar_w/2 + 30)
                            current_marker.style.text.offset = { x_off, 0, 2 }
                            current_marker.style.text.text_horizontal_alignment = invert_tags and "right" or "left"
                        end
                    end
                end
                
                -- Position at current progress along the bar
                -- Handle both orientation and invert
                local pos_fraction = progress / 100
                if invert then
                    pos_fraction = 1 - pos_fraction
                end
                
                current_marker.offset = current_marker.offset or { 0, 0, 0 }
                if is_horiz then
                    -- Horizontal: X position changes
                    local x_pos = -((bar_h / 2) - math.floor(pos_fraction * bar_h))
                    current_marker.offset[1] = x_pos
                    current_marker.offset[2] = 0
                else
                    -- Vertical: Y position changes
                    local y_pos = (bar_h / 2) - math.floor(pos_fraction * bar_h)
                    current_marker.offset[1] = 0
                    current_marker.offset[2] = y_pos
                end
                
                -- Format with user's preferred precision
                local format_str = "%." .. tostring(decimal_precision) .. "f%%"
                current_marker.content.text = string.format(format_str, progress)
                current_marker.content.visible = true
            else
                current_marker.content.visible = false
            end
        end
        
        -- Hide extraction marker (we only show distance text)
        local extraction_widget = widgets.extraction_marker
        if extraction_widget and extraction_widget.content then
            extraction_widget.content.visible = false
        end
        
        -- Update medicae markers with theme
        self:_update_medicae_markers(progress, show_medicae, theme, bar_h, opacity, is_horiz, invert, marker_sz, invert_tags)
        
        -- Update beacon markers
        local show_beacons = mod:get_setting("show_beacon_markers", true)
        self:_update_beacon_markers(progress, show_beacons, theme, bar_h, opacity, is_horiz, invert, marker_sz)
        
        -- Update grimoire markers
        local show_grimoires = mod:get_setting("show_grimoire_markers", true)
        self:_update_grimoire_markers(progress, show_grimoires, theme, bar_h, opacity, is_horiz, invert, marker_sz)
        
        -- Update scripture markers (separate setting)
        local show_scriptures = mod:get_setting("show_scripture_markers", true)
        self:_update_scripture_markers(progress, show_scriptures, theme, bar_h, opacity, is_horiz, invert, marker_sz)
    end)
    
    if not ok then
        -- Silently fail - don't crash the game
    end
end

function HudElementProgressBar:_update_medicae_markers(player_progress, show_medicae, theme, bar_h, opacity, is_horiz, invert, marker_sz, invert_tags)
    local widgets = self._widgets_by_name
    if not widgets then
        return
    end
    
    local medicae_data = self._cached_medicae or {}
    theme = theme or {}
    bar_h = bar_h or self._bar_height or 300
    local bar_w = self._bar_width or 10
    opacity = opacity or 100
    is_horiz = is_horiz or false
    invert = invert or false
    marker_sz = marker_sz or 8
    invert_tags = invert_tags or false
    
    local ok, err = pcall(function()
        for i = 1, max_medicae_markers do
            local widget = widgets["medicae_marker_" .. i]
            
            if widget then
                local med = medicae_data[i]
                
                -- Filter out medicae stations at very low percentages (likely spawn area leftovers)
                local med_pct = med and med.percentage or 0
                local is_valid = med and med_pct >= 5  -- Only ignore stations below 5%
                
                if is_valid and show_medicae then
                    if widget.content then
                        widget.content.visible = true
                    end
                    
                    -- Position marker based on percentage and orientation
                    med_pct = math.max(0, math.min(100, med_pct))
                    local pos_fraction = med_pct / 100
                    if invert then
                        pos_fraction = 1 - pos_fraction
                    end
                    
                    widget.offset = widget.offset or { 0, 0, 0 }
                    if is_horiz then
                        local x_offset = -((bar_h / 2) - math.floor(pos_fraction * bar_h))
                        widget.offset[1] = x_offset
                        widget.offset[2] = 0
                    else
                        local y_offset = (bar_h / 2) - math.floor(pos_fraction * bar_h)
                        widget.offset[1] = 0
                        widget.offset[2] = y_offset
                    end
                    
                    local current_charges = med.charges or 0
                    local passed = player_progress >= med_pct
                    
                    -- Tick color from theme
                    local tick_color
                    if passed then
                        tick_color = theme.tick_passed or { 255, 80, 80, 80 }
                    else
                        tick_color = theme.tick_active or { 255, 180, 180, 180 }
                    end
                    
                    -- Background color based on charges (using theme colors)
                    local bg_color
                    if passed then
                        bg_color = theme.medicae_passed or { 150, 40, 40, 40 }
                    elseif current_charges >= 3 then
                        bg_color = theme.medicae_full or { 200, 40, 100, 80 }
                    elseif current_charges >= 1 then
                        bg_color = theme.medicae_partial or { 200, 100, 80, 40 }
                    else
                        bg_color = theme.medicae_empty or { 150, 60, 60, 60 }
                    end
                    
                    -- Update tick color and size
                    if widget.style and widget.style.tick then
                        widget.style.tick.color = apply_opacity(tick_color, opacity)
                        -- Update tick size based on marker_sz
                        local tick_thickness = math.max(2, math.floor(marker_sz / 3))
                        if is_horiz then
                            widget.style.tick.size = { tick_thickness, bar_w }
                        else
                            widget.style.tick.size = { bar_w, tick_thickness }
                        end
                    end
                    
                    -- Update background color and apply invert_tags
                    if widget.style and widget.style.marker_bg then
                        widget.style.marker_bg.color = apply_opacity(bg_color, opacity)
                        -- Invert the position of the charges box
                        if is_horiz then
                            local y_off = invert_tags and (bar_w/2 + 12) or -(bar_w/2 + 12)
                            widget.style.marker_bg.offset = { 0, y_off, 5 }
                        else
                            local x_off = invert_tags and (bar_w/2 + 12) or -(bar_w/2 + 12)
                            widget.style.marker_bg.offset = { x_off, 0, 5 }
                        end
                    end
                    
                    -- Update charges text and apply invert_tags
                    if widget.style and widget.style.charges then
                        if is_horiz then
                            local y_off = invert_tags and (bar_w/2 + 12) or -(bar_w/2 + 12)
                            widget.style.charges.offset = { 0, y_off, 6 }
                        else
                            local x_off = invert_tags and (bar_w/2 + 12) or -(bar_w/2 + 12)
                            widget.style.charges.offset = { x_off, 0, 6 }
                        end
                    end
                    
                    -- Update charges text
                    if widget.content then
                        widget.content.charges_text = tostring(current_charges)
                        widget.content.percentage_text = string.format("%.0f%%", med_pct)
                    end
                else
                    if widget.content then
                        widget.content.visible = false
                    end
                end
            end
        end
    end)
end

function HudElementProgressBar:_update_beacon_markers(player_progress, show_beacons, theme, bar_h, opacity, is_horiz, invert, marker_sz)
    local widgets = self._widgets_by_name
    if not widgets then
        return
    end
    
    local beacon_data = self._cached_beacons or {}
    theme = theme or {}
    bar_h = bar_h or self._bar_height or 300
    opacity = opacity or 100
    is_horiz = is_horiz or false
    invert = invert or false
    marker_sz = marker_sz or 8
    
    local ok, err = pcall(function()
        for i = 1, max_beacon_markers do
            local widget = widgets["beacon_marker_" .. i]
            
            if widget then
                local beacon = beacon_data[i]
                
                if beacon and show_beacons then
                    if widget.content then
                        widget.content.visible = true
                    end
                    
                    -- Position marker based on percentage and orientation
                    local beacon_pct = math.max(0, math.min(100, beacon.percentage or 0))
                    local pos_fraction = beacon_pct / 100
                    if invert then
                        pos_fraction = 1 - pos_fraction
                    end
                    
                    widget.offset = widget.offset or { 0, 0, 0 }
                    if is_horiz then
                        local x_offset = -((bar_h / 2) - math.floor(pos_fraction * bar_h))
                        widget.offset[1] = x_offset
                        widget.offset[2] = 0
                    else
                        local y_offset = (bar_h / 2) - math.floor(pos_fraction * bar_h)
                        widget.offset[1] = 0
                        widget.offset[2] = y_offset
                    end
                    
                    local passed = player_progress >= beacon_pct
                    
                    -- Color from theme
                    local beacon_color
                    if passed then
                        beacon_color = theme.beacon_passed or { 120, 50, 90, 110 }
                    else
                        beacon_color = theme.beacon_active or { 220, 100, 180, 220 }
                    end
                    
                    -- Update tick color and size
                    if widget.style and widget.style.tick then
                        widget.style.tick.color = apply_opacity(beacon_color, opacity)
                        -- Update tick size: marker_sz controls thickness, bar_width is the cross dimension
                        local bar_w = self._bar_width or 10
                        local tick_thickness = math.max(2, math.floor(marker_sz / 3))
                        if is_horiz then
                            widget.style.tick.size = { tick_thickness, bar_w }
                        else
                            widget.style.tick.size = { bar_w, tick_thickness }
                        end
                    end
                else
                    if widget.content then
                        widget.content.visible = false
                    end
                end
            end
        end
    end)
end

function HudElementProgressBar:_update_grimoire_markers(player_progress, show_grimoires, theme, bar_h, opacity, is_horiz, invert, marker_sz)
    local widgets = self._widgets_by_name
    if not widgets then
        return
    end
    
    theme = theme or {}
    bar_h = bar_h or self._bar_height or 300
    opacity = opacity or 100
    is_horiz = is_horiz or false
    invert = invert or false
    marker_sz = marker_sz or 8
    local grimoire_data = self._cached_grimoires or {}
    
    local ok, err = pcall(function()
        for i = 1, max_grimoire_markers do
            local widget = widgets["grimoire_marker_" .. i]
            
            if widget then
                local grim = grimoire_data[i]
                
                if grim and show_grimoires then
                    if widget.content then
                        widget.content.visible = true
                    end
                    
                    -- Position marker based on percentage and orientation
                    local grim_pct = math.max(0, math.min(100, grim.percentage or 0))
                    local pos_fraction = grim_pct / 100
                    if invert then
                        pos_fraction = 1 - pos_fraction
                    end
                    
                    widget.offset = widget.offset or { 0, 0, 0 }
                    if is_horiz then
                        local x_offset = -((bar_h / 2) - math.floor(pos_fraction * bar_h))
                        widget.offset[1] = x_offset
                        widget.offset[2] = 0
                    else
                        local y_offset = (bar_h / 2) - math.floor(pos_fraction * bar_h)
                        widget.offset[1] = 0
                        widget.offset[2] = y_offset
                    end
                    
                    local passed = player_progress >= grim_pct
                    
                    -- Color from theme
                    local grim_color
                    if passed then
                        grim_color = theme.grimoire_passed or { 120, 75, 40, 90 }
                    else
                        grim_color = theme.grimoire_active or { 220, 107, 186, 195 }
                    end
                    
                    -- Update tick color and size
                    if widget.style and widget.style.tick then
                        widget.style.tick.color = apply_opacity(grim_color, opacity)
                        -- Update tick size: marker_sz controls thickness, bar_width is the cross dimension
                        local bar_w = self._bar_width or 10
                        local tick_thickness = math.max(2, math.floor(marker_sz / 3))
                        if is_horiz then
                            widget.style.tick.size = { tick_thickness, bar_w }
                        else
                            widget.style.tick.size = { bar_w, tick_thickness }
                        end
                    end
                else
                    if widget.content then
                        widget.content.visible = false
                    end
                end
            end
        end
    end)
end

function HudElementProgressBar:_update_scripture_markers(player_progress, show_scriptures, theme, bar_h, opacity, is_horiz, invert, marker_sz)
    local widgets = self._widgets_by_name
    if not widgets then
        return
    end
    
    theme = theme or {}
    bar_h = bar_h or self._bar_height or 300
    opacity = opacity or 100
    is_horiz = is_horiz or false
    invert = invert or false
    marker_sz = marker_sz or 8
    local scripture_data = self._cached_scriptures or {}
    
    local ok, err = pcall(function()
        for i = 1, max_scripture_markers do
            local widget = widgets["scripture_marker_" .. i]
            
            if widget then
                local scripture = scripture_data[i]
                
                if scripture and show_scriptures then
                    if widget.content then
                        widget.content.visible = true
                    end
                    
                    -- Position marker based on percentage and orientation
                    local scripture_pct = math.max(0, math.min(100, scripture.percentage or 0))
                    local pos_fraction = scripture_pct / 100
                    if invert then
                        pos_fraction = 1 - pos_fraction
                    end
                    
                    widget.offset = widget.offset or { 0, 0, 0 }
                    if is_horiz then
                        local x_offset = -((bar_h / 2) - math.floor(pos_fraction * bar_h))
                        widget.offset[1] = x_offset
                        widget.offset[2] = 0
                    else
                        local y_offset = (bar_h / 2) - math.floor(pos_fraction * bar_h)
                        widget.offset[1] = 0
                        widget.offset[2] = y_offset
                    end
                    
                    local passed = player_progress >= scripture_pct
                    
                    -- Use scripture-specific colors (defaults to same as grimoire)
                    local scripture_color
                    if passed then
                        scripture_color = theme.scripture_passed or theme.grimoire_passed or { 120, 80, 30, 100 }
                    else
                        scripture_color = theme.scripture_active or theme.grimoire_active or { 220, 160, 60, 200 }
                    end
                    
                    -- Update tick color and size
                    if widget.style and widget.style.tick then
                        widget.style.tick.color = apply_opacity(scripture_color, opacity)
                        -- Update tick size: marker_sz controls thickness, bar_width is the cross dimension
                        local bar_w = self._bar_width or 10
                        local tick_thickness = math.max(2, math.floor(marker_sz / 3))
                        if is_horiz then
                            widget.style.tick.size = { tick_thickness, bar_w }
                        else
                            widget.style.tick.size = { bar_w, tick_thickness }
                        end
                    end
                else
                    if widget.content then
                        widget.content.visible = false
                    end
                end
            end
        end
    end)
end

return HudElementProgressBar
