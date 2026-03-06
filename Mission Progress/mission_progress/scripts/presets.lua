--[[
    Theme Presets for Mission Progress
    
    Each preset defines the complete visual style of the progress bar.
    Users can select a preset or choose "Custom" to unlock individual settings.
    
    Color format: { Alpha, Red, Green, Blue } (ARGB)
]]

local presets = {
    -- ############################################
    -- Default: Subtle dark theme
    -- ############################################
    default = {
        name = "Default",
        description = "Subtle dark theme that blends with the HUD",
        
        bar_width = 10,
        bar_height = 250,
        edge_offset = 20,
        vertical_offset = 20,
        screen_edge = "right",
        
        bar_bg = { 200, 20, 20, 30 },
        bar_fill = { 255, 40, 100, 40 },
        bar_border = { 220, 60, 60, 60 },
        
        medicae_full = { 200, 40, 100, 80 },
        medicae_partial = { 200, 100, 80, 40 },
        medicae_empty = { 150, 60, 60, 60 },
        medicae_passed = { 150, 40, 40, 40 },
        tick_active = { 255, 180, 180, 180 },
        tick_passed = { 255, 80, 80, 80 },
        
        beacon_active = { 220, 80, 200, 80 },
        beacon_passed = { 120, 40, 100, 40 },
        
        grimoire_active = { 220, 160, 60, 200 },
        grimoire_passed = { 120, 80, 30, 100 },
        
        scripture_active = { 220, 200, 180, 80 },
        scripture_passed = { 120, 100, 90, 40 },
        
        text_primary = { 255, 255, 255, 255 },
        text_secondary = { 180, 180, 180, 180 },
        
        current_marker = { 255, 255, 255, 255 },
        extraction = { 255, 255, 220, 100 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 1,
    },
    
    -- ############################################
    -- Minimal: Clean and understated
    -- ############################################
    minimal = {
        name = "Minimal",
        description = "Thin bar with minimal visual noise",
        
        bar_width = 6,
        bar_height = 200,
        edge_offset = 15,
        vertical_offset = 0,
        screen_edge = "right",
        
        bar_bg = { 150, 15, 15, 20 },
        bar_fill = { 200, 80, 80, 80 },
        bar_border = { 120, 40, 40, 40 },
        
        medicae_full = { 180, 60, 80, 60 },
        medicae_partial = { 180, 80, 60, 40 },
        medicae_empty = { 120, 50, 50, 50 },
        medicae_passed = { 100, 30, 30, 30 },
        tick_active = { 200, 120, 120, 120 },
        tick_passed = { 150, 60, 60, 60 },
        
        beacon_active = { 180, 60, 160, 60 },
        beacon_passed = { 100, 30, 80, 30 },
        
        grimoire_active = { 180, 140, 50, 170 },
        grimoire_passed = { 100, 70, 25, 85 },
        
        scripture_active = { 180, 160, 140, 60 },
        scripture_passed = { 100, 80, 70, 30 },
        
        text_primary = { 200, 200, 200, 200 },
        text_secondary = { 150, 150, 150, 150 },
        
        current_marker = { 220, 220, 220, 220 },
        extraction = { 200, 200, 180, 80 },
        
        show_distance = false,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 0,
    },
    
    -- ############################################
    -- Neon Cyber: Synthwave cyberpunk vibes
    -- ############################################
    neon_cyber = {
        name = "Neon Cyber",
        description = "Hot pink and electric blue synthwave",
        
        bar_width = 8,
        bar_height = 280,
        edge_offset = 25,
        vertical_offset = 0,
        screen_edge = "right",
        
        bar_bg = { 220, 10, 5, 20 },
        bar_fill = { 255, 255, 20, 147 },         -- Hot pink
        bar_border = { 255, 0, 255, 255 },        -- Cyan
        
        medicae_full = { 255, 0, 255, 200 },      -- Electric cyan
        medicae_partial = { 255, 255, 100, 255 }, -- Magenta
        medicae_empty = { 180, 80, 0, 80 },       -- Dark purple
        medicae_passed = { 120, 40, 0, 40 },
        tick_active = { 255, 0, 255, 255 },       -- Cyan
        tick_passed = { 180, 0, 100, 100 },
        
        beacon_active = { 255, 50, 255, 50 },     -- Neon green
        beacon_passed = { 150, 25, 130, 25 },
        
        grimoire_active = { 255, 255, 0, 255 },   -- Magenta
        grimoire_passed = { 150, 130, 0, 130 },
        
        scripture_active = { 255, 255, 200, 0 },  -- Yellow
        scripture_passed = { 150, 130, 100, 0 },
        
        text_primary = { 255, 255, 255, 255 },
        text_secondary = { 255, 0, 200, 255 },
        
        current_marker = { 255, 255, 255, 255 },
        extraction = { 255, 255, 100, 255 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 1,
    },
    
    -- ############################################
    -- Imperium: Gold and crimson Imperial theme
    -- ############################################
    imperium = {
        name = "Imperium",
        description = "Gold and crimson, for the Emperor",
        
        bar_width = 10,
        bar_height = 250,
        edge_offset = 20,
        vertical_offset = 20,
        screen_edge = "right",
        
        bar_bg = { 220, 30, 15, 15 },
        bar_fill = { 255, 180, 140, 40 },
        bar_border = { 255, 140, 100, 30 },
        
        medicae_full = { 220, 40, 150, 80 },
        medicae_partial = { 220, 180, 120, 40 },
        medicae_empty = { 180, 100, 60, 40 },
        medicae_passed = { 150, 60, 40, 30 },
        tick_active = { 255, 200, 160, 80 },
        tick_passed = { 200, 100, 70, 40 },
        
        beacon_active = { 220, 100, 180, 80 },
        beacon_passed = { 130, 50, 90, 40 },
        
        grimoire_active = { 220, 170, 80, 190 },
        grimoire_passed = { 130, 85, 40, 95 },
        
        scripture_active = { 255, 255, 220, 140 },
        scripture_passed = { 150, 130, 110, 70 },
        
        text_primary = { 255, 255, 220, 180 },
        text_secondary = { 200, 180, 140, 100 },
        
        current_marker = { 255, 220, 180, 100 },
        extraction = { 255, 255, 200, 80 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 1,
    },
    
    -- ############################################
    -- Mechanicus: Tech-priest red and teal
    -- ############################################
    mechanicus = {
        name = "Mechanicus",
        description = "Red and teal, praise the Omnissiah",
        
        bar_width = 10,
        bar_height = 250,
        edge_offset = 20,
        vertical_offset = 20,
        screen_edge = "right",
        
        bar_bg = { 200, 20, 10, 15 },
        bar_fill = { 255, 180, 40, 40 },
        bar_border = { 240, 100, 30, 30 },
        
        medicae_full = { 220, 40, 180, 160 },
        medicae_partial = { 220, 60, 140, 120 },
        medicae_empty = { 180, 80, 60, 60 },
        medicae_passed = { 150, 50, 30, 30 },
        tick_active = { 255, 80, 200, 180 },
        tick_passed = { 200, 60, 80, 70 },
        
        beacon_active = { 220, 60, 200, 80 },
        beacon_passed = { 140, 30, 100, 40 },
        
        grimoire_active = { 220, 150, 60, 200 },
        grimoire_passed = { 140, 75, 30, 100 },
        
        scripture_active = { 255, 200, 180, 120 },
        scripture_passed = { 150, 100, 90, 60 },
        
        text_primary = { 255, 200, 80, 60 },
        text_secondary = { 200, 100, 180, 160 },
        
        current_marker = { 255, 220, 60, 40 },
        extraction = { 255, 100, 220, 200 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 2,
    },
    
    -- ############################################
    -- Inquisition: Pure white and blood red
    -- ############################################
    inquisition = {
        name = "Inquisition",
        description = "The Emperor's Holy Ordos demand purity",
        
        bar_width = 10,
        bar_height = 250,
        edge_offset = 20,
        vertical_offset = 20,
        screen_edge = "right",
        
        bar_bg = { 240, 15, 15, 20 },
        bar_fill = { 255, 200, 200, 200 },
        bar_border = { 255, 180, 30, 30 },
        
        medicae_full = { 220, 50, 180, 50 },
        medicae_partial = { 220, 200, 150, 80 },
        medicae_empty = { 180, 100, 100, 100 },
        medicae_passed = { 150, 60, 60, 60 },
        tick_active = { 255, 255, 255, 255 },
        tick_passed = { 200, 120, 120, 120 },
        
        beacon_active = { 220, 60, 200, 60 },
        beacon_passed = { 140, 30, 100, 30 },
        
        grimoire_active = { 255, 180, 40, 180 },
        grimoire_passed = { 150, 90, 20, 90 },
        
        scripture_active = { 255, 255, 220, 180 },
        scripture_passed = { 150, 130, 110, 90 },
        
        text_primary = { 255, 255, 255, 255 },
        text_secondary = { 220, 200, 200, 200 },
        
        current_marker = { 255, 255, 255, 255 },
        extraction = { 255, 255, 230, 180 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 1,
    },
    
    -- ############################################
    -- Chaos: Dark corruption and warp energy
    -- ############################################
    chaos = {
        name = "Chaos",
        description = "Embrace the corruption of the warp",
        
        bar_width = 10,
        bar_height = 250,
        edge_offset = 20,
        vertical_offset = 20,
        screen_edge = "right",
        
        bar_bg = { 220, 15, 5, 20 },
        bar_fill = { 255, 100, 20, 80 },
        bar_border = { 240, 80, 30, 60 },
        
        medicae_full = { 220, 60, 180, 60 },
        medicae_partial = { 220, 120, 80, 80 },
        medicae_empty = { 180, 60, 40, 60 },
        medicae_passed = { 150, 40, 20, 40 },
        tick_active = { 255, 140, 60, 120 },
        tick_passed = { 200, 60, 30, 60 },
        
        beacon_active = { 220, 80, 160, 60 },
        beacon_passed = { 140, 40, 80, 30 },
        
        grimoire_active = { 240, 180, 40, 200 },
        grimoire_passed = { 140, 90, 20, 100 },
        
        scripture_active = { 240, 200, 100, 160 },
        scripture_passed = { 140, 100, 50, 80 },
        
        text_primary = { 255, 200, 180, 200 },
        text_secondary = { 200, 140, 100, 140 },
        
        current_marker = { 255, 200, 100, 180 },
        extraction = { 255, 180, 60, 160 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 1,
    },
    
    -- ############################################
    -- Veteran: Military olive and khaki
    -- ############################################
    veteran = {
        name = "Veteran",
        description = "Standard issue, regulation compliant",
        
        bar_width = 10,
        bar_height = 250,
        edge_offset = 20,
        vertical_offset = 20,
        screen_edge = "right",
        
        bar_bg = { 200, 30, 35, 25 },
        bar_fill = { 255, 80, 100, 60 },
        bar_border = { 240, 100, 90, 70 },
        
        medicae_full = { 220, 60, 180, 60 },
        medicae_partial = { 220, 180, 160, 80 },
        medicae_empty = { 180, 80, 80, 70 },
        medicae_passed = { 150, 50, 50, 45 },
        tick_active = { 255, 180, 170, 140 },
        tick_passed = { 200, 90, 85, 70 },
        
        beacon_active = { 220, 70, 160, 70 },
        beacon_passed = { 140, 35, 80, 35 },
        
        grimoire_active = { 200, 140, 60, 160 },
        grimoire_passed = { 120, 70, 30, 80 },
        
        scripture_active = { 220, 200, 180, 140 },
        scripture_passed = { 130, 100, 90, 70 },
        
        text_primary = { 255, 220, 210, 190 },
        text_secondary = { 200, 160, 150, 130 },
        
        current_marker = { 255, 220, 200, 160 },
        extraction = { 255, 200, 220, 100 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 1,
    },
    
    -- ############################################
    -- Zealot: Holy fire, red and orange
    -- ############################################
    zealot = {
        name = "Zealot",
        description = "Burn the heretic with holy fire",
        
        bar_width = 10,
        bar_height = 250,
        edge_offset = 20,
        vertical_offset = 20,
        screen_edge = "right",
        
        bar_bg = { 220, 25, 10, 10 },
        bar_fill = { 255, 220, 100, 30 },
        bar_border = { 250, 180, 60, 20 },
        
        medicae_full = { 220, 80, 200, 60 },
        medicae_partial = { 220, 200, 140, 40 },
        medicae_empty = { 180, 100, 60, 40 },
        medicae_passed = { 150, 60, 40, 30 },
        tick_active = { 255, 255, 180, 80 },
        tick_passed = { 200, 120, 60, 40 },
        
        beacon_active = { 220, 80, 200, 60 },
        beacon_passed = { 140, 40, 100, 30 },
        
        grimoire_active = { 240, 200, 50, 120 },
        grimoire_passed = { 140, 100, 25, 60 },
        
        scripture_active = { 255, 255, 230, 160 },
        scripture_passed = { 150, 130, 115, 80 },
        
        text_primary = { 255, 255, 220, 180 },
        text_secondary = { 220, 200, 140, 100 },
        
        current_marker = { 255, 255, 200, 120 },
        extraction = { 255, 255, 200, 80 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 1,
    },
    
    -- ############################################
    -- Ogryn: Big, bold, simple
    -- ############################################
    ogryn = {
        name = "Ogryn",
        description = "Big and simple, for da big uns",
        
        bar_width = 20,
        bar_height = 400,
        edge_offset = 30,
        vertical_offset = 0,
        screen_edge = "right",
        
        bar_bg = { 255, 40, 30, 20 },
        bar_fill = { 255, 100, 180, 80 },
        bar_border = { 255, 160, 140, 100 },
        
        medicae_full = { 255, 80, 255, 80 },
        medicae_partial = { 255, 255, 200, 80 },
        medicae_empty = { 255, 255, 100, 100 },
        medicae_passed = { 180, 100, 100, 100 },
        tick_active = { 255, 255, 255, 255 },
        tick_passed = { 200, 100, 100, 100 },
        
        beacon_active = { 255, 80, 255, 80 },
        beacon_passed = { 180, 40, 130, 40 },
        
        grimoire_active = { 255, 200, 80, 255 },
        grimoire_passed = { 180, 100, 40, 130 },
        
        scripture_active = { 255, 255, 200, 100 },
        scripture_passed = { 180, 130, 100, 50 },
        
        text_primary = { 255, 255, 255, 255 },
        text_secondary = { 255, 220, 200, 180 },
        
        current_marker = { 255, 255, 255, 255 },
        extraction = { 255, 255, 255, 100 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 0,
    },
    
    -- ############################################
    -- Psyker: Warp energy blue and purple
    -- ############################################
    psyker = {
        name = "Psyker",
        description = "Channel the energies of the immaterium",
        
        bar_width = 10,
        bar_height = 250,
        edge_offset = 20,
        vertical_offset = 20,
        screen_edge = "right",
        
        bar_bg = { 200, 10, 15, 30 },
        bar_fill = { 255, 80, 120, 200 },
        bar_border = { 230, 60, 80, 160 },
        
        medicae_full = { 220, 60, 200, 120 },
        medicae_partial = { 220, 100, 140, 180 },
        medicae_empty = { 180, 60, 60, 80 },
        medicae_passed = { 140, 40, 40, 60 },
        tick_active = { 255, 120, 160, 220 },
        tick_passed = { 180, 60, 80, 120 },
        
        beacon_active = { 220, 80, 220, 140 },
        beacon_passed = { 140, 40, 110, 70 },
        
        grimoire_active = { 240, 160, 80, 220 },
        grimoire_passed = { 140, 80, 40, 110 },
        
        scripture_active = { 240, 180, 180, 255 },
        scripture_passed = { 140, 90, 90, 130 },
        
        text_primary = { 255, 180, 200, 255 },
        text_secondary = { 200, 120, 140, 200 },
        
        current_marker = { 255, 140, 180, 255 },
        extraction = { 255, 160, 180, 255 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 2,
    },
    
    -- ############################################
    -- Stealth: Nearly invisible
    -- ############################################
    stealth = {
        name = "Stealth",
        description = "Barely visible until you need it",
        
        bar_width = 4,
        bar_height = 150,
        edge_offset = 5,
        vertical_offset = 0,
        screen_edge = "right",
        
        bar_bg = { 80, 10, 10, 10 },
        bar_fill = { 120, 60, 60, 60 },
        bar_border = { 100, 30, 30, 30 },
        
        medicae_full = { 150, 40, 80, 60 },
        medicae_partial = { 140, 60, 60, 40 },
        medicae_empty = { 100, 40, 40, 40 },
        medicae_passed = { 60, 20, 20, 20 },
        tick_active = { 140, 100, 100, 100 },
        tick_passed = { 80, 40, 40, 40 },
        
        beacon_active = { 120, 40, 100, 40 },
        beacon_passed = { 60, 20, 50, 20 },
        
        grimoire_active = { 120, 80, 35, 100 },
        grimoire_passed = { 60, 40, 18, 50 },
        
        scripture_active = { 120, 100, 90, 50 },
        scripture_passed = { 60, 50, 45, 25 },
        
        text_primary = { 160, 160, 160, 160 },
        text_secondary = { 120, 100, 100, 100 },
        
        current_marker = { 160, 160, 160, 160 },
        extraction = { 150, 150, 130, 60 },
        
        show_distance = false,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 0,
    },
    
    -- ############################################
    -- Hive World: Polluted industrial amber
    -- ############################################
    hive_world = {
        name = "Hive World",
        description = "Polluted skies and industrial grime",
        
        bar_width = 12,
        bar_height = 260,
        edge_offset = 22,
        vertical_offset = 10,
        screen_edge = "right",
        
        bar_bg = { 200, 25, 20, 15 },
        bar_fill = { 255, 180, 140, 60 },
        bar_border = { 240, 80, 60, 40 },
        
        medicae_full = { 220, 80, 160, 80 },
        medicae_partial = { 220, 160, 120, 60 },
        medicae_empty = { 180, 100, 70, 50 },
        medicae_passed = { 140, 60, 45, 35 },
        tick_active = { 255, 200, 160, 100 },
        tick_passed = { 180, 100, 80, 50 },
        
        beacon_active = { 220, 100, 180, 80 },
        beacon_passed = { 140, 50, 90, 40 },
        
        grimoire_active = { 220, 160, 60, 160 },
        grimoire_passed = { 140, 80, 30, 80 },
        
        scripture_active = { 240, 220, 180, 100 },
        scripture_passed = { 140, 110, 90, 50 },
        
        text_primary = { 255, 240, 200, 160 },
        text_secondary = { 200, 180, 140, 100 },
        
        current_marker = { 255, 255, 200, 120 },
        extraction = { 255, 240, 180, 80 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 1,
    },
    
    -- ############################################
    -- Void Born: Deep space cold blue
    -- ############################################
    void_born = {
        name = "Void Born",
        description = "The cold emptiness between stars",
        
        bar_width = 8,
        bar_height = 240,
        edge_offset = 18,
        vertical_offset = 0,
        screen_edge = "right",
        
        bar_bg = { 180, 5, 10, 25 },
        bar_fill = { 220, 40, 80, 140 },
        bar_border = { 200, 30, 50, 100 },
        
        medicae_full = { 220, 40, 160, 160 },
        medicae_partial = { 200, 60, 120, 140 },
        medicae_empty = { 160, 40, 60, 80 },
        medicae_passed = { 120, 25, 40, 60 },
        tick_active = { 255, 100, 160, 200 },
        tick_passed = { 180, 50, 80, 120 },
        
        beacon_active = { 220, 60, 180, 120 },
        beacon_passed = { 140, 30, 90, 60 },
        
        grimoire_active = { 220, 120, 60, 180 },
        grimoire_passed = { 140, 60, 30, 90 },
        
        scripture_active = { 240, 160, 180, 220 },
        scripture_passed = { 140, 80, 90, 110 },
        
        text_primary = { 255, 180, 200, 230 },
        text_secondary = { 200, 120, 150, 180 },
        
        current_marker = { 255, 150, 200, 255 },
        extraction = { 255, 100, 180, 220 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 1,
    },
    
    -- ############################################
    -- Death Guard: Putrid green and rot
    -- ############################################
    death_guard = {
        name = "Death Guard",
        description = "Embrace Grandfather Nurgle's gifts",
        
        bar_width = 14,
        bar_height = 270,
        edge_offset = 20,
        vertical_offset = 0,
        screen_edge = "right",
        
        bar_bg = { 200, 20, 25, 15 },
        bar_fill = { 255, 120, 140, 60 },
        bar_border = { 240, 80, 70, 40 },
        
        medicae_full = { 220, 140, 180, 80 },
        medicae_partial = { 220, 160, 140, 60 },
        medicae_empty = { 180, 80, 70, 50 },
        medicae_passed = { 140, 50, 45, 35 },
        tick_active = { 255, 160, 180, 100 },
        tick_passed = { 180, 80, 90, 50 },
        
        beacon_active = { 220, 130, 170, 70 },
        beacon_passed = { 140, 65, 85, 35 },
        
        grimoire_active = { 240, 100, 80, 120 },
        grimoire_passed = { 140, 50, 40, 60 },
        
        scripture_active = { 240, 180, 160, 100 },
        scripture_passed = { 140, 90, 80, 50 },
        
        text_primary = { 255, 200, 220, 140 },
        text_secondary = { 200, 140, 130, 100 },
        
        current_marker = { 255, 180, 200, 120 },
        extraction = { 255, 160, 180, 80 },
        
        show_distance = true,
        show_percentage = true,
        show_medicae = true,
        decimal_precision = 1,
    },
}

-- Preset order for dropdown
local preset_order = {
    "default",
    "custom",
    "minimal",
    "neon_cyber",
    "imperium",
    "mechanicus",
    "inquisition",
    "chaos",
    "veteran",
    "zealot",
    "ogryn",
    "psyker",
    "stealth",
    "hive_world",
    "void_born",
    "death_guard",
}

-- Get preset by name
local function get_preset(name)
    return presets[name] or presets.default
end

return {
    presets = presets,
    preset_order = preset_order,
    get_preset = get_preset,
}
