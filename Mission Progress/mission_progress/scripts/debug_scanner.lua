local mod = get_mod("mission_progress")

local SCANNER_VERSION = "v3.0"

print("[mission_progress] Debug scanner " .. SCANNER_VERSION .. " loaded")

-- Helper to get mission name
local function get_mission_name()
    local mission_name = "unknown"
    pcall(function()
        local mission_manager = Managers.state and Managers.state.mission
        if mission_manager then
            local mission = mission_manager:mission()
            if mission then
                mission_name = mission.name or mission.id or "unknown"
            end
        end
    end)
    return mission_name
end

-- Debug scan function
local function run_scan()
    print("[mission_progress] ========== SCAN " .. SCANNER_VERSION .. " ==========")
    
    if not Managers.state then
        print("[mission_progress] No Managers.state - not in mission")
        print("[mission_progress] ========== SCAN END ==========")
        return
    end
    
    -- Mission info
    local mission_name = get_mission_name()
    print("[mission_progress] mission: " .. mission_name)
    
    -- Connection status
    local is_host = false
    pcall(function()
        is_host = Managers.connection and Managers.connection:is_host()
    end)
    print("[mission_progress] is_host: " .. tostring(is_host))
    
    -- Progress data
    local progress = 0
    local player_distance = 0
    local segment_total = 0
    local marker_total = 0
    local player_pos = nil
    
    pcall(function() progress = mod:get_progress_percentage() or 0 end)
    pcall(function() player_distance = mod:get_player_travel_distance() or 0 end)
    pcall(function() segment_total = mod:_get_total_from_segments() or 0 end)
    pcall(function() marker_total = mod:_get_total_from_markers() or 0 end)
    
    -- Get player position
    pcall(function()
        local pm = Managers.player
        local local_player = pm and pm:local_player(1)
        local player_unit = local_player and local_player.player_unit
        if player_unit and Unit.alive(player_unit) then
            player_pos = Unit.local_position(player_unit, 1)
        end
    end)
    
    print(string.format("[mission_progress] progress: %.1f%%", progress))
    print(string.format("[mission_progress] player_dist: %.1fm", player_distance))
    print(string.format("[mission_progress] segment_total: %.1fm (used for progress)", segment_total))
    print(string.format("[mission_progress] marker_total: %.1fm (fallback)", marker_total))
    
    if player_pos then
        print(string.format("[mission_progress] player_pos: (%.0f, %.0f, %.0f)", player_pos.x, player_pos.y, player_pos.z))
    end
    
    -- Path markers info
    local main_path = Managers.state.main_path
    if main_path and main_path._path_markers then
        local markers = main_path._path_markers
        print("[mission_progress] path_markers: " .. #markers)
        if #markers >= 2 then
            local first = markers[1].position:unbox()
            local last = markers[#markers].position:unbox()
            print(string.format("[mission_progress] first_marker: (%.0f, %.0f, %.0f)", first.x, first.y, first.z))
            print(string.format("[mission_progress] last_marker: (%.0f, %.0f, %.0f)", last.x, last.y, last.z))
        end
    end
    
    -- Segments info
    if main_path and main_path._main_path_segments then
        print("[mission_progress] segments: " .. #main_path._main_path_segments)
        for i, seg in ipairs(main_path._main_path_segments) do
            if seg.path_length then
                print(string.format("[mission_progress]   seg#%d: %.1fm", i, seg.path_length))
            end
        end
    end
    
    -- Mod data counts
    print("[mission_progress] medicae: " .. #(mod._medicae_data or {}))
    print("[mission_progress] beacons: " .. #(mod._beacon_data or {}))
    print("[mission_progress] grimoires: " .. #(mod._grimoire_data or {}))
    print("[mission_progress] scriptures: " .. #(mod._scripture_data or {}))
    
    -- Medicae details
    local medicae_data = mod._medicae_data or {}
    for i, med in ipairs(medicae_data) do
        print(string.format("[mission_progress] Med#%d: %.1f%% dist=%.0fm charges=%d/%d", 
            i, med.percentage or 0, med.distance or 0, med.charges or 0, med.max_charges or 4))
    end
    
    print("[mission_progress] ========== SCAN END ==========")
end

-- Store scan function on mod
mod.run_scan = run_scan

-- Register command
mod:command("scan", "Run debug scan", function()
    run_scan()
end)
