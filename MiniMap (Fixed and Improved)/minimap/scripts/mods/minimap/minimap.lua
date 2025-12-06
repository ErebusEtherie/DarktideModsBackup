local mod = get_mod("minimap")

mod.settings = {}
mod.settings.icon_vis = {}

local color_presets = {}
for _, name in ipairs(Color.list or {}) do
    local c = Color[name](255, true)
    color_presets[#color_presets+1] = { id = name, name = name, r = c[2], g = c[3], b = c[4] }
end

local color_defaults = {
    color_chaos_hound = { 255, 0, 200 },
    color_renegade_netgunner = { 200, 0, 255 },
    color_renegade_sniper = { 255, 0, 150 },
    color_flamer = { 255, 80, 0 },
    color_grenadier = { 180, 255, 0 },
    color_chaos_poxwalker_bomber = { 220, 255, 0 },
    color_executor = { 150, 0, 200 },
    color_berzerker = { 220, 0, 0 },
    color_renegade_plasma_gunner = { 0, 220, 255 },
    color_chaos_ogryn_bulwark = { 255, 200, 0 },
    color_special = { 255, 0, 255 },
    color_elite_ranged = { 255, 100, 0 },
    color_elite_melee = { 255, 165, 0 },
    color_monster = { 255, 0, 0 },
    color_captain = { 128, 0, 128 },
    color_horde = { 150, 150, 150 },
    color_roamer = { 180, 180, 180 },
}

-- Load colors from settings
local function load_breed_colors_from_settings()
	local function get_color(r_key, g_key, b_key, default_r, default_g, default_b)
		return {
			mod:get(r_key) or default_r,
			mod:get(g_key) or default_g,
			mod:get(b_key) or default_b
		}
	end
	
	return {
		-- Generic categories (used as fallback)
		horde = get_color("color_horde_r", "color_horde_g", "color_horde_b", 150, 150, 150),
		roamer = get_color("color_roamer_r", "color_roamer_g", "color_roamer_b", 180, 180, 180),
		elite_melee = get_color("color_elite_melee_r", "color_elite_melee_g", "color_elite_melee_b", 255, 165, 0),
		elite_ranged = get_color("color_elite_ranged_r", "color_elite_ranged_g", "color_elite_ranged_b", 255, 100, 0),
		special = get_color("color_special_r", "color_special_g", "color_special_b", 255, 0, 255),
		monster = get_color("color_monster_r", "color_monster_g", "color_monster_b", 255, 0, 0),
		captain = get_color("color_captain_r", "color_captain_g", "color_captain_b", 128, 0, 128),
		default = { 255, 255, 255 },
		
		-- Specific special enemy breeds (prioritized)
		-- Disablers (Purple/Magenta tones - similar to generic special)
		chaos_hound = get_color("color_chaos_hound_r", "color_chaos_hound_g", "color_chaos_hound_b", 255, 0, 200),
		renegade_netgunner = get_color("color_renegade_netgunner_r", "color_renegade_netgunner_g", "color_renegade_netgunner_b", 200, 0, 255),
		
		-- Snipers (Pink - high threat ranged)
		renegade_sniper = get_color("color_renegade_sniper_r", "color_renegade_sniper_g", "color_renegade_sniper_b", 255, 0, 150),
		
		-- Flamers (Orange-Red - fire theme)
		renegade_flamer = get_color("color_flamer_r", "color_flamer_g", "color_flamer_b", 255, 80, 0),
		cultist_flamer = get_color("color_flamer_r", "color_flamer_g", "color_flamer_b", 255, 80, 0),
		
		-- Grenadiers (Yellow-Lime - explosive theme)
		renegade_grenadier = get_color("color_grenadier_r", "color_grenadier_g", "color_grenadier_b", 180, 255, 0),
		cultist_grenadier = get_color("color_grenadier_r", "color_grenadier_g", "color_grenadier_b", 180, 255, 0),
		chaos_poxwalker_bomber = get_color("color_chaos_poxwalker_bomber_r", "color_chaos_poxwalker_bomber_g", "color_chaos_poxwalker_bomber_b", 220, 255, 0),
		
		-- Specific elite enemy breeds
		-- Executors (Dark Purple - elite melee threat)
		chaos_ogryn_executor = get_color("color_executor_r", "color_executor_g", "color_executor_b", 150, 0, 200),
		renegade_executor = get_color("color_executor_r", "color_executor_g", "color_executor_b", 150, 0, 200),
		-- Ragers (Crimson - aggressive melee)
		renegade_berzerker = get_color("color_berzerker_r", "color_berzerker_g", "color_berzerker_b", 220, 0, 0),
		cultist_berzerker = get_color("color_berzerker_r", "color_berzerker_g", "color_berzerker_b", 220, 0, 0),
		-- Plasma Gunner (Cyan - tech/plasma weapon)
		renegade_plasma_gunner = get_color("color_renegade_plasma_gunner_r", "color_renegade_plasma_gunner_g", "color_renegade_plasma_gunner_b", 0, 220, 255),
		-- Bulwark (Gold - shield/tank)
		chaos_ogryn_bulwark = get_color("color_chaos_ogryn_bulwark_r", "color_chaos_ogryn_bulwark_g", "color_chaos_ogryn_bulwark_b", 255, 200, 0),
	}
end

-- Initialize breed colors
mod.fallback_breed_colors = load_breed_colors_from_settings()

function mod.get_breed_color_fallback(unit)
    if not unit then
        return mod.fallback_breed_colors.default
    end
    
    local success, breed_color = pcall(function()
        local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
        if not unit_data_extension then
            return nil
        end
        
        local breed = unit_data_extension:breed()
        if not breed or not breed.tags then
            return nil
        end
        
        local tags = breed.tags
        local breed_name = breed.name
        
        -- PRIORITY 1: Check for specific breed name first (most specific)
        -- This allows differentiation between pox hounds, flamers, grenadiers, etc.
        if mod.fallback_breed_colors[breed_name] then
            return mod.fallback_breed_colors[breed_name]
        end
        
        -- PRIORITY 2: Fall back to generic tag-based colors (catch-all)
        if tags.captain or tags.cultist_captain then
            return mod.fallback_breed_colors.captain
        elseif tags.elite then
            local ranged_elites = {
                renegade_gunner = true,
                renegade_shocktrooper = true,
                cultist_gunner = true,
                chaos_ogryn_gunner = true,
                cultist_shocktrooper = true
            }
            if ranged_elites[breed_name] then
                return mod.fallback_breed_colors.elite_ranged
            else
                return mod.fallback_breed_colors.elite_melee
            end
        elseif tags.special then
            -- Generic special color (catch-all for any special without specific color)
            return mod.fallback_breed_colors.special
        elseif tags.monster then
            return mod.fallback_breed_colors.monster
        elseif tags.horde then
            return mod.fallback_breed_colors.horde
        elseif tags.roamer then
            return mod.fallback_breed_colors.roamer
        end
        
        return nil
    end)
    
    return success and breed_color or mod.fallback_breed_colors.default
end

local hud_elements = {
    {
        filename = "minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap",
        class_name = "HudElementMinimap",
    },
}

mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap_settings")

for _, hud_element in ipairs(hud_elements) do
    mod:add_require_path(hud_element.filename)
end

mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap_definitions")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/assistance")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/attention")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/companion_target")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/enemy")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/interactable")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/objective")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/ping")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/player")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/player_class")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/teammate")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/teammate_class")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/teammate_status")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/threat")
mod:add_require_path("minimap/scripts/mods/minimap/hud_element_minimap/templates/unknown")

mod:hook("UIHud", "init", function(func, self, elements, visibility_groups, params)
    for _, hud_element in ipairs(hud_elements) do
        if not table.find_by_key(elements, "class_name", hud_element.class_name) then
            table.insert(elements, {
                class_name = hud_element.class_name,
                filename = hud_element.filename,
                use_hud_scale = true,
                visibility_groups = {
                    "alive",
                    "communication_wheel"
                },
            })
        end
    end

    return func(self, elements, visibility_groups, params)
end)

---@param elements any[]
---@return HudElementMinimap?
local function get_hud_minimap_element(elements)
    if not elements or table.is_empty(elements) then
        return nil
    end

    return elements[hud_elements[1].class_name]
end

local function update_minimap_style_settings(hud)
    if not hud or not hud._elements then
        return
    end

    local minimap = get_hud_minimap_element(hud._elements)
    if minimap then
        minimap:set_scenegraph_position("minimap", mod:get("minimap_offset_x"), mod:get("minimap_offset_y"), 0, mod:get("minimap_horizontal_alignment"), mod:get("minimap_vertical_alignment"))

        if minimap._update_background_color then
            minimap:_update_background_color()
        end
    end
end

local function recreate_hud()
    local ui_manager = Managers.ui
    if not ui_manager then
        return
    end
    
        local hud = ui_manager._hud
    if not hud then
        return
    end
    
            local player_manager = Managers.player
            local player = player_manager:local_player(1)
    if not player then
        return
    end
    
            local peer_id = player:peer_id()
            local local_player_id = player:local_player_id()
            local elements = hud._element_definitions
            local visibility_groups = hud._visibility_groups

            hud:destroy()
            ui_manager:create_player_hud(peer_id, local_player_id, elements, visibility_groups)
            update_minimap_style_settings(ui_manager._hud)
end

local function collect_settings()
    mod.settings.display_class_icon = mod:get("display_class_icon")

    -- Icon visibility settings
    mod.settings.icon_vis.location_attention = mod:get("location_attention_vis")
    mod.settings.icon_vis.location_ping = mod:get("location_ping_vis")
    mod.settings.icon_vis.location_threat = mod:get("location_threat_vis")
    mod.settings.icon_vis.unit_threat = mod:get("unit_threat_vis")
    mod.settings.icon_vis.unit_threat_adamant = mod:get("unit_threat_adamant_vis")
    
    -- Player/teammate visibility (all nameplate types use the same setting)
    local player_vis = mod:get("player_vis")
    mod.settings.icon_vis.nameplate = player_vis
    mod.settings.icon_vis.nameplate_party = player_vis
    mod.settings.icon_vis.nameplate_party_hud = player_vis
    mod.settings.icon_vis.nameplate_combat = player_vis
    mod.settings.icon_vis.nameplate_companion = player_vis
    mod.settings.icon_vis.nameplate_companion_hub = player_vis
    mod.settings.icon_vis.ringhud_teammate_tile = player_vis
    
    mod.settings.icon_vis.objective = mod:get("objective_vis")
    mod.settings.icon_vis.interaction = mod:get("tagged_interaction_vis")
    
    -- Status icon style
    local status_icon_style = mod:get("status_icon_style")
    mod.settings.status_icon_style = status_icon_style
    mod.settings.icon_vis.player_assistance = (status_icon_style ~= "hidden")
    
    -- General settings
    mod.settings.hide_bots = mod:get("hide_bots")
    mod.settings.dog_icon_style = mod:get("dog_icon_style")
    mod.settings.own_dog_vis = mod:get("own_dog_vis")
    mod.settings.teammate_dog_vis = mod:get("teammate_dog_vis")
    mod.settings.show_in_hub = mod:get("show_in_hub")
    mod.settings.show_in_shooting_range = mod:get("show_in_shooting_range")
    mod.settings.show_when_dead = mod:get("show_when_dead")
    mod.settings.minimap_background_color_r = mod:get("minimap_background_color_r") or 180
    mod.settings.minimap_background_color_g = mod:get("minimap_background_color_g") or 180
    mod.settings.minimap_background_color_b = mod:get("minimap_background_color_b") or 180
    mod.settings.minimap_background_opacity = mod:get("minimap_background_opacity")
    
    -- Enemy Radar settings
    mod.settings.enemy_radar_enabled = mod:get("enemy_radar_enabled")
    
    mod.settings.icon_vis.color_coded_healthbar = mod.settings.enemy_radar_enabled
    mod.settings.icon_vis.custom_healthbar = mod.settings.enemy_radar_enabled
    
    mod.settings.enemy_radar_filters = {
        elite = mod:get("enemy_radar_filter_elite"),
        special = mod:get("enemy_radar_filter_special"),
        boss = mod:get("enemy_radar_filter_boss"),
        horde = mod:get("enemy_radar_filter_horde"),
        fodder = mod:get("enemy_radar_filter_fodder"),
        roamer = mod:get("enemy_radar_filter_roamer"),
    }
    mod.settings.enemy_radar_limits = {
        elite = mod:get("enemy_radar_limit_elite"),
        special = mod:get("enemy_radar_limit_special"),
        boss = mod:get("enemy_radar_limit_boss"),
        horde = mod:get("enemy_radar_limit_horde"),
        fodder = mod:get("enemy_radar_limit_fodder"),
        roamer = mod:get("enemy_radar_limit_roamer"),
    }
    
    -- Priority mode setting
    mod.settings.enemy_radar_priority_mode = mod:get("enemy_radar_priority_mode") or "damage"
    
    -- Melee range ring settings
    mod.settings.enemy_radar_melee_ring_enabled = mod:get("enemy_radar_melee_ring_enabled")
    mod.settings.enemy_radar_melee_range = mod:get("enemy_radar_melee_range")
    mod.settings.enemy_radar_melee_ring_color_r = mod:get("enemy_radar_melee_ring_color_r") or 180
    mod.settings.enemy_radar_melee_ring_color_g = mod:get("enemy_radar_melee_ring_color_g") or 180
    mod.settings.enemy_radar_melee_ring_color_b = mod:get("enemy_radar_melee_ring_color_b") or 180
    mod.settings.enemy_radar_melee_ring_opacity = mod:get("enemy_radar_melee_ring_opacity")
    
    -- Vertical distance transparency settings
    mod.settings.enemy_radar_vertical_distance_enabled = mod:get("enemy_radar_vertical_distance_enabled")
    mod.settings.enemy_radar_vertical_distance_threshold = mod:get("enemy_radar_vertical_distance_threshold")
    mod.settings.enemy_radar_vertical_distance_transparency = mod:get("enemy_radar_vertical_distance_transparency")
    
    -- Distance marker settings
    mod.settings.distance_markers = {
        players = mod:get("distance_marker_players"),
        companions = mod:get("distance_marker_companions"),
        enemies = mod:get("distance_marker_enemies"),
        objectives = mod:get("distance_marker_objectives"),
        interactables = mod:get("distance_marker_interactables"),
        pings = mod:get("distance_marker_pings"),
        only_out_of_range = mod:get("distance_marker_only_out_of_range"),
    }
end

-- Debug command to check loaded colors
mod:command("minimap_debug_colors", "Show loaded enemy colors", function()
    mod:echo("=== Minimap Enemy Colors ===")
    mod:echo("Specific Specials:")
    mod:echo(string.format("  Pox Hound: %d, %d, %d", 
        mod.fallback_breed_colors.chaos_hound[1],
        mod.fallback_breed_colors.chaos_hound[2],
        mod.fallback_breed_colors.chaos_hound[3]))
    mod:echo(string.format("  Sniper: %d, %d, %d", 
        mod.fallback_breed_colors.renegade_sniper[1],
        mod.fallback_breed_colors.renegade_sniper[2],
        mod.fallback_breed_colors.renegade_sniper[3]))
    mod:echo("")
    mod:echo("Specific Elites:")
    mod:echo(string.format("  Executors (All): %d, %d, %d", 
        mod.fallback_breed_colors.chaos_ogryn_executor[1],
        mod.fallback_breed_colors.chaos_ogryn_executor[2],
        mod.fallback_breed_colors.chaos_ogryn_executor[3]))
    mod:echo(string.format("  Ragers (All): %d, %d, %d", 
        mod.fallback_breed_colors.renegade_berzerker[1],
        mod.fallback_breed_colors.renegade_berzerker[2],
        mod.fallback_breed_colors.renegade_berzerker[3]))
    mod:echo(string.format("  Plasma Gunner: %d, %d, %d", 
        mod.fallback_breed_colors.renegade_plasma_gunner[1],
        mod.fallback_breed_colors.renegade_plasma_gunner[2],
        mod.fallback_breed_colors.renegade_plasma_gunner[3]))
    mod:echo(string.format("  Bulwark: %d, %d, %d", 
        mod.fallback_breed_colors.chaos_ogryn_bulwark[1],
        mod.fallback_breed_colors.chaos_ogryn_bulwark[2],
        mod.fallback_breed_colors.chaos_ogryn_bulwark[3]))
    mod:echo("")
    mod:echo("Generic Categories:")
    mod:echo(string.format("  Special: %d, %d, %d", 
        mod.fallback_breed_colors.special[1],
        mod.fallback_breed_colors.special[2],
        mod.fallback_breed_colors.special[3]))
    mod:echo(string.format("  Elite Melee: %d, %d, %d", 
        mod.fallback_breed_colors.elite_melee[1],
        mod.fallback_breed_colors.elite_melee[2],
        mod.fallback_breed_colors.elite_melee[3]))
    mod:echo(string.format("  Monster: %d, %d, %d", 
        mod.fallback_breed_colors.monster[1],
        mod.fallback_breed_colors.monster[2],
        mod.fallback_breed_colors.monster[3]))
end)

mod.on_all_mods_loaded = function()
    -- Reload breed colors from settings (settings are fully loaded now)
    mod.fallback_breed_colors = load_breed_colors_from_settings()
    collect_settings()
    recreate_hud()
end

local is_syncing_preset = false
local hud_recreate_timer = 0
local HUD_RECREATE_DELAY = 0.1

mod.on_setting_changed = function(setting_id)
    if not setting_id then
        return
    end
    
    if is_syncing_preset then
        return
    end
    
    if string.match(setting_id, "_preset$") then
        local preset_id = mod:get(setting_id)
        local base_setting = string.gsub(setting_id, "_preset$", "")
        
        is_syncing_preset = true
        if preset_id == "default" then
            local defaults = color_defaults[base_setting]
            if defaults then
                mod:set(base_setting .. "_r", defaults[1], false)
                mod:set(base_setting .. "_g", defaults[2], false)
                mod:set(base_setting .. "_b", defaults[3], false)
            end
        else
            for _, p in ipairs(color_presets) do
                if p.id == preset_id then
                    mod:set(base_setting .. "_r", p.r, false)
                    mod:set(base_setting .. "_g", p.g, false)
                    mod:set(base_setting .. "_b", p.b, false)
                    break
                end
            end
        end
        is_syncing_preset = false
        collect_settings()
        return
    end
    
    collect_settings()
    
    if string.find(setting_id, "^color_") and string.find(setting_id, "_[rgb]$") then
        mod.fallback_breed_colors = load_breed_colors_from_settings()
        return
    end

    if setting_id == "minimap_background_color_r" or setting_id == "minimap_background_color_g" or 
       setting_id == "minimap_background_color_b" or setting_id == "minimap_background_opacity" then
        local ui_manager = Managers.ui
        if ui_manager and ui_manager._hud and ui_manager._hud._elements then
            local minimap = get_hud_minimap_element(ui_manager._hud._elements)
            if minimap and minimap._update_background_color then
                minimap:_update_background_color()
            end
        end
        return
    end
    
    if string.find(setting_id, "_[rgb]$") then
        return
    end
    
    local current_time = os.clock()
    if current_time - hud_recreate_timer > HUD_RECREATE_DELAY then
        hud_recreate_timer = current_time
        recreate_hud()
    end
end
