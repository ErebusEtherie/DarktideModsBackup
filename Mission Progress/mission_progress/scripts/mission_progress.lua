local mod = get_mod("mission_progress")

-- Load presets
local presets_module = mod:io_dofile("mission_progress/scripts/presets")

-- Load debug scanner (adds /scan command) - optional for development
-- Clear cache to force reload
package.loaded["mission_progress/scripts/debug_scanner"] = nil
local debug_scanner_ok = pcall(function()
    mod:io_dofile("mission_progress/scripts/debug_scanner")
end)

-- State
mod._show_hud = true
mod._medicae_data = {}
mod._beacon_data = {}
mod._grimoire_data = {}
mod._scripture_data = {}
mod._total_marker_length = 0
mod._total_segment_length = 0
mod._cached_path_markers = nil
mod._current_theme = nil

-- ############################################
-- HUD Element Setup (like custom_hud mod)
-- ############################################

local hud_element_path = "mission_progress/scripts/hud/hud_element_progress_bar"

-- Add require path so the game can find our HUD element file
mod:add_require_path(hud_element_path)

-- Define the hook function
local function ui_hud_init_hook(func, self, elements, visibility_groups, params)
    local class_name = "HudElementProgressBar"
    
    -- Remove existing entry if present (prevent duplicates)
    local element_index = table.find_by_key(elements, "class_name", class_name)
    if element_index then
        table.remove(elements, element_index)
    end
    
    -- Add our HUD element
    table.insert(elements, {
        class_name = class_name,
        filename = hud_element_path,
        use_hud_scale = true,
        visibility_groups = {
            "alive",
        },
    })
    
    return func(self, elements, visibility_groups, params)
end

-- Register the hook
mod:hook("UIHud", "init", ui_hud_init_hook)

-- Function to recreate HUD (forces our element to be created)
local function recreate_hud()
    -- Always invalidate theme cache first so definitions get fresh values
    mod:invalidate_theme_cache()
    
    local ui_manager = Managers.ui
    if ui_manager then
        local hud = ui_manager._hud
        if hud then
            local player_manager = Managers.player
            local player = player_manager:local_player(1)
            if player then
                local peer_id = player:peer_id()
                local local_player_id = player:local_player_id()
                local elements = hud._element_definitions
                local visibility_groups = hud._visibility_groups
                
                -- Clear cached definitions so they reload with new theme
                package.loaded["mission_progress/scripts/hud/hud_element_progress_bar_definitions"] = nil
                package.loaded["mission_progress/scripts/hud/hud_element_progress_bar"] = nil
                
                ui_manager:destroy_player_hud()
                ui_manager:create_player_hud(peer_id, local_player_id, elements, visibility_groups)
            end
        end
    end
end

-- ############################################
-- Keybind Callback
-- ############################################

function mod.toggle_visibility()
    mod._show_hud = not mod._show_hud
end

-- ############################################
-- Theme System
-- ############################################

function mod:get_current_theme()
    -- Cache theme to avoid rebuilding every frame
    if self._current_theme then
        return self._current_theme
    end
    
    local preset_name = self:get("theme_preset") or "default"
    
    -- Get global position/size settings (these override any preset)
    local global_width = self:get("bar_width")
    local global_height = self:get("bar_height")
    local global_edge_offset = self:get("bar_edge_offset")
    local global_vertical_offset = self:get("bar_vertical_offset")
    local global_screen_edge = self:get("bar_screen_edge")
    local global_opacity = self:get("bar_opacity") or 100
    local global_orientation = self:get("bar_orientation") or "vertical"
    local global_invert = self:get("bar_invert_direction") or false
    local global_invert_tags = self:get("bar_invert_tags") or false
    local global_font_size = self:get("bar_font_size") or 14
    -- Derive marker size from font size (proportional scaling)
    local global_marker_size = math.max(4, math.floor(global_font_size / 2))
    
    local theme
    
    if preset_name == "custom" then
        -- Build theme from individual settings
        theme = {
            name = "Custom",
            
            -- Dimensions from settings (use global settings, fall back to custom settings)
            bar_width = global_width or self:get("custom_bar_width") or 10,
            bar_height = global_height or self:get("custom_bar_height") or 300,
            edge_offset = global_edge_offset or self:get("custom_edge_offset") or 20,
            vertical_offset = global_vertical_offset or self:get("custom_vertical_offset") or 50,
            screen_edge = global_screen_edge or self:get("custom_screen_edge") or "right",
            opacity = global_opacity,
            orientation = global_orientation,
            invert_direction = global_invert,
            invert_tags = global_invert_tags,
            font_size = global_font_size,
            marker_size = global_marker_size,
            
            -- Colors from settings (ARGB format)
            bar_bg = {
                self:get("custom_bar_bg_a") or 200,
                self:get("custom_bar_bg_r") or 20,
                self:get("custom_bar_bg_g") or 20,
                self:get("custom_bar_bg_b") or 30,
            },
            bar_fill = {
                self:get("custom_bar_fill_a") or 255,
                self:get("custom_bar_fill_r") or 40,
                self:get("custom_bar_fill_g") or 100,
                self:get("custom_bar_fill_b") or 40,
            },
            bar_border = {
                self:get("custom_bar_border_a") or 220,
                self:get("custom_bar_border_r") or 60,
                self:get("custom_bar_border_g") or 60,
                self:get("custom_bar_border_b") or 60,
            },
            
            -- Default marker colors for custom mode (from custom settings)
            medicae_full = { 200, self:get("custom_medicae_r") or 40, (self:get("custom_medicae_g") or 100) + 20, self:get("custom_medicae_b") or 80 },
            medicae_partial = { 200, self:get("custom_medicae_r") or 40, self:get("custom_medicae_g") or 100, self:get("custom_medicae_b") or 80 },
            medicae_empty = { 150, 60, 60, 60 },
            medicae_passed = { 150, 40, 40, 40 },
            tick_active = { 255, 180, 180, 180 },
            tick_passed = { 255, 80, 80, 80 },
            beacon_active = { 220, self:get("custom_beacon_r") or 80, self:get("custom_beacon_g") or 200, self:get("custom_beacon_b") or 80 },
            beacon_passed = { 120, math.floor((self:get("custom_beacon_r") or 80)/2), math.floor((self:get("custom_beacon_g") or 200)/2), math.floor((self:get("custom_beacon_b") or 80)/2) },
            grimoire_active = { 220, self:get("custom_grimoire_r") or 160, self:get("custom_grimoire_g") or 60, self:get("custom_grimoire_b") or 200 },
            grimoire_passed = { 120, math.floor((self:get("custom_grimoire_r") or 160)/2), math.floor((self:get("custom_grimoire_g") or 60)/2), math.floor((self:get("custom_grimoire_b") or 200)/2) },
            scripture_active = { 220, self:get("custom_scripture_r") or 200, self:get("custom_scripture_g") or 180, self:get("custom_scripture_b") or 80 },
            scripture_passed = { 120, math.floor((self:get("custom_scripture_r") or 200)/2), math.floor((self:get("custom_scripture_g") or 180)/2), math.floor((self:get("custom_scripture_b") or 80)/2) },
            text_primary = { 255, 255, 255, 255 },
            text_secondary = { 180, 180, 180, 180 },
            current_marker = { 255, 255, 255, 255 },
            extraction = { 255, 255, 220, 100 },
            marker_size = 8,
            
            -- Display options from settings
            show_distance = self:get("show_distance"),
            show_percentage = self:get("show_percentage"),
            show_medicae = self:get("show_medicae_markers"),
            decimal_precision = self:get("decimal_precision") or 1,
        }
    else
        -- Get preset from presets module (make a copy so we can modify it)
        local base_preset = presets_module.get_preset(preset_name)
        theme = {}
        for k, v in pairs(base_preset) do
            theme[k] = v
        end
        
        -- Apply global position/size overrides to preset
        if global_width then theme.bar_width = global_width end
        if global_height then theme.bar_height = global_height end
        if global_edge_offset then theme.edge_offset = global_edge_offset end
        if global_vertical_offset then theme.vertical_offset = global_vertical_offset end
        if global_screen_edge then theme.screen_edge = global_screen_edge end
        theme.opacity = global_opacity
        theme.orientation = global_orientation
        theme.invert_direction = global_invert
        theme.invert_tags = global_invert_tags
        theme.font_size = global_font_size
        theme.marker_size = global_marker_size
    end
    
    -- Apply marker color overrides if enabled (works with any theme)
    if self:get("override_marker_colors") then
        -- Grimoire colors (ARGB: alpha, R, G, B)
        local grim_r = self:get("grimoire_color_r") or 160
        local grim_g = self:get("grimoire_color_g") or 60
        local grim_b = self:get("grimoire_color_b") or 200
        theme.grimoire_active = { 220, grim_r, grim_g, grim_b }
        theme.grimoire_passed = { 120, math.floor(grim_r/2), math.floor(grim_g/2), math.floor(grim_b/2) }
        
        -- Scripture colors (ARGB)
        local scrip_r = self:get("scripture_color_r") or 160
        local scrip_g = self:get("scripture_color_g") or 60
        local scrip_b = self:get("scripture_color_b") or 200
        theme.scripture_active = { 220, scrip_r, scrip_g, scrip_b }
        theme.scripture_passed = { 120, math.floor(scrip_r/2), math.floor(scrip_g/2), math.floor(scrip_b/2) }
        
        -- Beacon colors (ARGB)
        local beacon_r = self:get("beacon_color_r") or 80
        local beacon_g = self:get("beacon_color_g") or 200
        local beacon_b = self:get("beacon_color_b") or 80
        theme.beacon_active = { 220, beacon_r, beacon_g, beacon_b }
        theme.beacon_passed = { 120, math.floor(beacon_r/2), math.floor(beacon_g/2), math.floor(beacon_b/2) }
        
        -- Medicae colors (ARGB) - applies to partial/full (empty uses different logic)
        local med_r = self:get("medicae_color_r") or 100
        local med_g = self:get("medicae_color_g") or 80
        local med_b = self:get("medicae_color_b") or 40
        theme.medicae_full = { 200, med_r, med_g + 20, med_b }  -- Slightly greener for full
        theme.medicae_partial = { 200, med_r, med_g, med_b }
    end
    
    self._current_theme = theme
    return self._current_theme
end

function mod:invalidate_theme_cache()
    self._current_theme = nil
end

-- Settings changed callback
mod:command("reload_theme", "Reload theme settings", function()
    mod:invalidate_theme_cache()
end)

-- ############################################
-- Settings Accessors (for HUD element)
-- ############################################

function mod:should_show_hud()
    -- Don't show if not in a mission
    if not self:is_in_mission() then
        return false
    end
    -- Check internal visibility toggle
    if not self._show_hud then
        return false
    end
    -- Check settings (if explicitly disabled)
    local show_setting = self:get("show_progress_bar")
    if show_setting == false then
        return false
    end
    return true
end

function mod:get_setting(setting_id, default)
    local value = self:get(setting_id)
    if value == nil then
        return default
    end
    return value
end

function mod:is_in_mission()
    local game_mode_manager = Managers.state and Managers.state.game_mode
    if not game_mode_manager then
        return false
    end
    
    local game_mode_name = game_mode_manager:game_mode_name()
    return game_mode_name == "coop_complete_objective" or game_mode_name == "coop_survival"
end

function mod:get_medicae_data()
    return self._medicae_data or {}
end

-- Get local player unit
local function get_local_player_unit()
    local player_manager = Managers.player
    if not player_manager then return nil end
    
    local local_player = player_manager:local_player(1)
    if not local_player then return nil end
    
    return local_player.player_unit
end

-- Get path markers (cached)
function mod:get_path_markers()
    if self._cached_path_markers then
        return self._cached_path_markers
    end
    
    if not Managers.state or not Managers.state.main_path then
        return nil
    end
    
    local main_path = Managers.state.main_path
    self._cached_path_markers = main_path._path_markers
    return self._cached_path_markers
end

-- Calculate total path length from _main_path_segments (the REAL path length)
-- This is more accurate than markers which often don't cover the full path
function mod:_get_total_from_segments()
    if self._total_segment_length and self._total_segment_length > 0 then
        return self._total_segment_length
    end
    
    local ok, result = pcall(function()
        local main_path = Managers.state and Managers.state.main_path
        if not main_path or not main_path._main_path_segments then
            return 0
        end
        
        local total = 0
        for i, seg in ipairs(main_path._main_path_segments) do
            if seg.path_length then
                total = total + seg.path_length
            end
        end
        return total
    end)
    
    if ok and result and result > 0 then
        self._total_segment_length = result
        return result
    end
    
    return 0
end

-- Calculate total path length from path markers (FALLBACK - less accurate)
function mod:_get_total_from_markers()
    if self._total_marker_length and self._total_marker_length > 0 then
        return self._total_marker_length
    end
    
    local ok, result = pcall(function()
        local markers = self:get_path_markers()
        if not markers or #markers < 2 then
            return 0
        end
        
        local total = 0
        for i = 1, #markers - 1 do
            local marker1 = markers[i]
            local marker2 = markers[i + 1]
            
            if marker1 and marker2 and marker1.position and marker2.position then
                local p1 = marker1.position:unbox()
                local p2 = marker2.position:unbox()
                
                local dx = p2.x - p1.x
                local dy = p2.y - p1.y
                local dz = p2.z - p1.z
                total = total + math.sqrt(dx * dx + dy * dy + dz * dz)
            end
        end
        
        return total
    end)
    
    if ok and result and result > 0 then
        self._total_marker_length = result
        return result
    end
    
    return 0
end

-- Calculate total path length
-- Use segments (accurate) first, fall back to markers if needed
function mod:get_total_path_length()
    -- Try segments first - this is the REAL path length from the game
    local segment_total = self:_get_total_from_segments()
    if segment_total > 0 then
        return segment_total
    end
    
    -- Fall back to markers (less accurate, may not cover full path)
    return self:_get_total_from_markers()
end

-- Get player's travel distance along main path
-- Uses marker-based calculation for consistency (works on both host and client)
function mod:get_player_travel_distance()
    local ok, result = pcall(function()
        local player_unit = get_local_player_unit()
        if not player_unit or not Unit.alive(player_unit) then
            return self._last_valid_distance or 0
        end
        
        local player_pos = Unit.local_position(player_unit, 1)
        if not player_pos then
            return self._last_valid_distance or 0
        end
        
        -- Always use marker-based calculation for consistency with total path length
        local distance = self:_calculate_distance_from_markers(player_pos)
        if distance and distance > 0 then
            -- Cap distance to total path length to prevent exceeding 100%
            local total = self:get_total_path_length()
            if total > 0 and distance > total then
                distance = total
            end
            self._last_valid_distance = distance
            return distance
        end
        
        return self._last_valid_distance or 0
    end)
    
    if ok then
        return result
    end
    return self._last_valid_distance or 0
end

-- Calculate travel distance using EngineOptimized (preferred) or path markers (fallback)
function mod:_calculate_distance_from_markers(player_pos)
    if not player_pos then
        return 0
    end
    
    -- Try EngineOptimized first (works in multiplayer)
    local engine_ok, closest_pos, travel_distance = pcall(function()
        return EngineOptimized.closest_pos_at_main_path(player_pos)
    end)
    
    if engine_ok and travel_distance and travel_distance > 0 then
        return travel_distance
    end
    
    -- Fallback to marker-based calculation
    local ok, result = pcall(function()
        local markers = self:get_path_markers()
        if not markers or #markers < 2 then
            return 0
        end
        
        local player_x, player_y, player_z = player_pos.x, player_pos.y, player_pos.z
        if not player_x or not player_y or not player_z then
            return 0
        end
        
        -- Find the closest segment and calculate distance along path
        local best_distance_along_path = 0
        local best_dist_to_segment = math.huge
        local accumulated_distance = 0
        
        for i = 1, #markers - 1 do
            local marker1 = markers[i]
            local marker2 = markers[i + 1]
            
            if marker1 and marker2 and marker1.position and marker2.position then
                local p1 = marker1.position:unbox()
                local p2 = marker2.position:unbox()
                
                -- Calculate segment length
                local seg_dx = p2.x - p1.x
                local seg_dy = p2.y - p1.y
                local seg_dz = p2.z - p1.z
                local seg_length = math.sqrt(seg_dx * seg_dx + seg_dy * seg_dy + seg_dz * seg_dz)
                
                if seg_length > 0 then
                    -- Project player position onto segment
                    local to_player_x = player_x - p1.x
                    local to_player_y = player_y - p1.y
                    local to_player_z = player_z - p1.z
                    
                    -- Dot product to find projection
                    local t = (to_player_x * seg_dx + to_player_y * seg_dy + to_player_z * seg_dz) / (seg_length * seg_length)
                    t = math.max(0, math.min(1, t))  -- Clamp to segment
                    
                    -- Closest point on segment
                    local closest_x = p1.x + t * seg_dx
                    local closest_y = p1.y + t * seg_dy
                    local closest_z = p1.z + t * seg_dz
                    
                    -- Distance from player to closest point
                    local dx = player_x - closest_x
                    local dy = player_y - closest_y
                    local dz = player_z - closest_z
                    local dist_to_segment = math.sqrt(dx * dx + dy * dy + dz * dz)
                    
                    -- Check if this is the closest segment so far
                    if dist_to_segment < best_dist_to_segment then
                        best_dist_to_segment = dist_to_segment
                        best_distance_along_path = accumulated_distance + (t * seg_length)
                    end
                end
                
                accumulated_distance = accumulated_distance + seg_length
            end
        end
        
        return best_distance_along_path
    end)
    
    if ok and result then
        return result
    end
    return 0
end

-- Get player progress as percentage (0-100)
function mod:get_progress_percentage()
    local total = self:get_total_path_length()
    if total <= 0 then
        return 0
    end
    
    local traveled = self:get_player_travel_distance()
    return math.min(100, math.max(0, (traveled / total) * 100))
end

-- Find health stations and calculate their path percentages
function mod:find_medicae_stations()
    -- Clear old data
    if self._medicae_data then
        for _, med in ipairs(self._medicae_data) do
            if med.position then
                med.position = nil
            end
        end
    end
    self._medicae_data = {}
    
    if not Managers.state or not Managers.state.extension then
        return
    end
    
    local ext_manager = Managers.state.extension
    local main_path = Managers.state.main_path
    
    if not main_path then
        return
    end
    
    local ok, health_sys = pcall(function()
        return ext_manager:system("health_station_system")
    end)
    
    if not ok or not health_sys or not health_sys._unit_to_extension_map then
        return
    end
    
    local total = self:get_total_path_length()
    if total <= 0 then
        return
    end
    
    for unit, ext in pairs(health_sys._unit_to_extension_map) do
        if Unit.alive(unit) then
            local pos = Unit.local_position(unit, 1)
            local distance = self:_calculate_distance_from_markers(pos) or 0
            local percentage = (distance > 0 and total > 0) and (distance / total) * 100 or 0
            
            local charges = 0
            local max_charges = 4
            if type(ext) == "table" then
                charges = ext._charge_amount or 0
            end
            
            table.insert(self._medicae_data, {
                pos_x = pos.x,
                pos_y = pos.y,
                pos_z = pos.z,
                percentage = percentage,
                distance = distance,
                charges = charges,
                max_charges = max_charges,
                unit = unit
            })
        end
    end
    
    table.sort(self._medicae_data, function(a, b) return a.percentage < b.percentage end)
end

-- Find respawn beacons and calculate their path percentages
function mod:find_respawn_beacons()
    self._beacon_data = {}
    
    if not Managers.state or not Managers.state.extension then
        return
    end
    
    local ext_manager = Managers.state.extension
    
    local ok, beacon_sys = pcall(function()
        return ext_manager:system("respawn_beacon_system")
    end)
    
    if not ok or not beacon_sys then
        return
    end
    
    local total = self:get_total_path_length()
    if total <= 0 then
        return
    end
    
    -- Collect beacon units from available sources
    local beacon_units = {}
    
    if beacon_sys._unit_to_extension_map then
        for unit, _ in pairs(beacon_sys._unit_to_extension_map) do
            if Unit.alive(unit) then
                beacon_units[unit] = true
            end
        end
    end
    
    if beacon_sys._beacon_main_path_distance_lookup then
        for unit, _ in pairs(beacon_sys._beacon_main_path_distance_lookup) do
            if Unit.alive(unit) then
                beacon_units[unit] = true
            end
        end
    end
    
    if beacon_sys._sorted_beacons then
        for _, unit in ipairs(beacon_sys._sorted_beacons) do
            if Unit.alive(unit) then
                beacon_units[unit] = true
            end
        end
    end
    
    if beacon_sys._spawned_beacons then
        for unit, _ in pairs(beacon_sys._spawned_beacons) do
            if Unit.alive(unit) then
                beacon_units[unit] = true
            end
        end
    end
    
    -- Calculate distance for each beacon
    for unit, _ in pairs(beacon_units) do
        local pos = Unit.local_position(unit, 1)
        if pos then
            local distance = self:_calculate_distance_from_markers(pos) or 0
            local percentage = (distance > 0 and total > 0) and (distance / total) * 100 or 0
            table.insert(self._beacon_data, {
                percentage = percentage,
                distance = distance,
                unit = unit
            })
        end
    end
    
    table.sort(self._beacon_data, function(a, b) return a.percentage < b.percentage end)
end

-- Get beacon data for HUD
function mod:get_beacon_data()
    return self._beacon_data or {}
end

-- Find grimoires and calculate their path percentages
function mod:find_grimoires()
    self._grimoire_data = {}
    
    if not Managers.state or not Managers.state.extension then
        return
    end
    
    local ext_manager = Managers.state.extension
    
    local total = self:get_total_path_length()
    if total <= 0 then
        return
    end
    
    local grimoire_units = {}
    
    -- Try pickup_system (works on host)
    pcall(function()
        local pickup_sys = ext_manager:system("pickup_system")
        if pickup_sys and pickup_sys._pickup_to_spawner then
            for pickup, _ in pairs(pickup_sys._pickup_to_spawner) do
                if Unit.alive(pickup) then
                    local pickup_type = Unit.get_data(pickup, "pickup_type")
                    if pickup_type and string.find(string.lower(pickup_type), "grimoire") then
                        grimoire_units[pickup] = pickup_type
                    end
                end
            end
        end
    end)
    
    -- Also try interactee_system (works on client)
    pcall(function()
        local interactee_sys = ext_manager:system("interactee_system")
        if interactee_sys and interactee_sys._unit_to_extension_map then
            for unit, _ in pairs(interactee_sys._unit_to_extension_map) do
                if Unit.alive(unit) and not grimoire_units[unit] then
                    local pickup_type = Unit.get_data(unit, "pickup_type")
                    if pickup_type and string.find(string.lower(pickup_type), "grimoire") then
                        grimoire_units[unit] = pickup_type
                    end
                end
            end
        end
    end)
    
    -- Calculate distance for each grimoire
    for unit, pickup_type in pairs(grimoire_units) do
        local pos = Unit.local_position(unit, 1)
        if pos then
            local distance = self:_calculate_distance_from_markers(pos) or 0
            local percentage = (distance > 0 and total > 0) and (distance / total) * 100 or 0
            
            table.insert(self._grimoire_data, {
                pos_x = pos.x,
                pos_y = pos.y,
                pos_z = pos.z,
                percentage = percentage,
                distance = distance,
                unit = unit,
                pickup_type = pickup_type
            })
        end
    end
    
    table.sort(self._grimoire_data, function(a, b) return a.percentage < b.percentage end)
end

-- Get grimoire data for HUD
function mod:get_grimoire_data()
    return self._grimoire_data or {}
end

-- Find scriptures (called "tome" in game) and calculate their path percentages
function mod:find_scriptures()
    self._scripture_data = {}
    
    if not Managers.state or not Managers.state.extension then
        return
    end
    
    local ext_manager = Managers.state.extension
    
    local total = self:get_total_path_length()
    if total <= 0 then
        return
    end
    
    local scripture_units = {}
    
    -- Try pickup_system (works on host)
    pcall(function()
        local pickup_sys = ext_manager:system("pickup_system")
        if pickup_sys and pickup_sys._pickup_to_spawner then
            for pickup, _ in pairs(pickup_sys._pickup_to_spawner) do
                if Unit.alive(pickup) then
                    local pickup_type = Unit.get_data(pickup, "pickup_type")
                    if pickup_type and pickup_type == "tome" then
                        scripture_units[pickup] = pickup_type
                    end
                end
            end
        end
    end)
    
    -- Also try interactee_system (works on client)
    pcall(function()
        local interactee_sys = ext_manager:system("interactee_system")
        if interactee_sys and interactee_sys._unit_to_extension_map then
            for unit, _ in pairs(interactee_sys._unit_to_extension_map) do
                if Unit.alive(unit) and not scripture_units[unit] then
                    local pickup_type = Unit.get_data(unit, "pickup_type")
                    if pickup_type and pickup_type == "tome" then
                        scripture_units[unit] = pickup_type
                    end
                end
            end
        end
    end)
    
    -- Calculate distance for each scripture
    for unit, pickup_type in pairs(scripture_units) do
        local pos = Unit.local_position(unit, 1)
        if pos then
            local distance = self:_calculate_distance_from_markers(pos) or 0
            local percentage = (distance > 0 and total > 0) and (distance / total) * 100 or 0
            
            table.insert(self._scripture_data, {
                pos_x = pos.x,
                pos_y = pos.y,
                pos_z = pos.z,
                percentage = percentage,
                distance = distance,
                unit = unit,
                pickup_type = pickup_type
            })
        end
    end
    
    -- Sort by percentage
    table.sort(self._scripture_data, function(a, b) return a.percentage < b.percentage end)
end

-- Get scripture data for HUD
function mod:get_scripture_data()
    return self._scripture_data or {}
end

-- Events
function mod.on_enabled(initial_call)
    -- No action needed
end

function mod.on_disabled(initial_call)
    mod._show_hud = false
end

-- Invalidate theme cache when settings change
function mod.on_setting_changed(setting_id)
    mod:invalidate_theme_cache()
    
    -- Recreate HUD when theme preset or position/size settings change
    local requires_hud_recreate = {
        theme_preset = true,
        bar_width = true,
        bar_height = true,
        bar_edge_offset = true,
        bar_vertical_offset = true,
        bar_screen_edge = true,
        bar_orientation = true,
        bar_invert_tags = true,
    }
    
    if requires_hud_recreate[setting_id] then
        recreate_hud()
    end
end

-- Reset cache on new mission
function mod.on_game_state_changed(status, state_name)
    if state_name == "StateLoading" then
        mod._cached_path_markers = nil
        mod._total_marker_length = 0
        mod._total_segment_length = 0  -- Reset segment-based length too
        mod._medicae_data = {}
        mod._beacon_data = {}
        mod._grimoire_data = {}
        mod._scripture_data = {}
        mod._last_valid_distance = nil
        mod:invalidate_theme_cache()
    end
end



-- ############################################
-- Lifecycle Callbacks
-- ############################################

function mod.on_all_mods_loaded()
    mod._medicae_refresh_timer = 0
    
    -- Recreate HUD to inject our element (like custom_hud does)
    recreate_hud()
end

-- Update function to refresh medicae, beacon, and grimoire data periodically
function mod.update(dt)
    if not mod:is_in_mission() then
        return
    end
    
    mod._medicae_refresh_timer = (mod._medicae_refresh_timer or 0) + dt
    if mod._medicae_refresh_timer >= 2.0 then
        mod._medicae_refresh_timer = 0
        mod:find_medicae_stations()
        mod:find_respawn_beacons()
        mod:find_grimoires()
        mod:find_scriptures()
    end
end
