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

local function load_breed_colors_from_settings()
	local function get_color(r_key, g_key, b_key, default_r, default_g, default_b)
		return {
			mod:get(r_key) or default_r,
			mod:get(g_key) or default_g,
			mod:get(b_key) or default_b
		}
	end

	return {
		boss = get_color("color_boss_r", "color_boss_g", "color_boss_b", 255, 0, 0),
		disabler = get_color("color_disabler_r", "color_disabler_g", "color_disabler_b", 200, 0, 255),
		sniper = get_color("color_sniper_r", "color_sniper_g", "color_sniper_b", 255, 0, 150),
		shield = get_color("color_shield_r", "color_shield_g", "color_shield_b", 100, 150, 255),
		ranged_elite = get_color("color_ranged_elite_r", "color_ranged_elite_g", "color_ranged_elite_b", 255, 100, 0),
		melee_elite = get_color("color_melee_elite_r", "color_melee_elite_g", "color_melee_elite_b", 255, 165, 0),
		special = get_color("color_special_r", "color_special_g", "color_special_b", 255, 0, 255),
		horde = get_color("color_horde_r", "color_horde_g", "color_horde_b", 150, 150, 150),
		roamer = get_color("color_roamer_r", "color_roamer_g", "color_roamer_b", 180, 180, 180),
		default = { 255, 255, 255 },

		chaos_hound = get_color("color_chaos_hound_r", "color_chaos_hound_g", "color_chaos_hound_b", 180, 0, 255),
		renegade_netgunner = get_color("color_renegade_netgunner_r", "color_renegade_netgunner_g", "color_renegade_netgunner_b", 180, 0, 255),

		renegade_sniper = get_color("color_renegade_sniper_r", "color_renegade_sniper_g", "color_renegade_sniper_b", 255, 0, 150),

		renegade_flamer = get_color("color_flamer_r", "color_flamer_g", "color_flamer_b", 100, 255, 100),
		cultist_flamer = get_color("color_flamer_r", "color_flamer_g", "color_flamer_b", 100, 255, 100),

		renegade_grenadier = get_color("color_grenadier_r", "color_grenadier_g", "color_grenadier_b", 100, 255, 100),
		cultist_grenadier = get_color("color_grenadier_r", "color_grenadier_g", "color_grenadier_b", 100, 255, 100),
		chaos_poxwalker_bomber = get_color("color_chaos_poxwalker_bomber_r", "color_chaos_poxwalker_bomber_g", "color_chaos_poxwalker_bomber_b", 100, 255, 100),

		chaos_ogryn_executor = get_color("color_executor_r", "color_executor_g", "color_executor_b", 255, 220, 0),
		renegade_executor = get_color("color_executor_r", "color_executor_g", "color_executor_b", 255, 220, 0),
		renegade_berzerker = get_color("color_berzerker_r", "color_berzerker_g", "color_berzerker_b", 255, 220, 0),
		cultist_berzerker = get_color("color_berzerker_r", "color_berzerker_g", "color_berzerker_b", 255, 220, 0),
		renegade_plasma_gunner = get_color("color_renegade_plasma_gunner_r", "color_renegade_plasma_gunner_g", "color_renegade_plasma_gunner_b", 255, 120, 0),
		chaos_ogryn_bulwark = get_color("color_chaos_ogryn_bulwark_r", "color_chaos_ogryn_bulwark_g", "color_chaos_ogryn_bulwark_b", 0, 200, 255),
	}
end

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

        if mod.fallback_breed_colors[breed_name] then
            return mod.fallback_breed_colors[breed_name]
        end

        if tags.captain or tags.cultist_captain or tags.monster then
            return mod.fallback_breed_colors.boss
        elseif tags.elite then
            local ranged_elites = {
                renegade_gunner = true,
                renegade_shocktrooper = true,
                cultist_gunner = true,
                chaos_ogryn_gunner = true,
                cultist_shocktrooper = true
            }
            if ranged_elites[breed_name] or tags.far then
                return mod.fallback_breed_colors.ranged_elite
            else
                return mod.fallback_breed_colors.melee_elite
            end
        elseif breed_name == "cultist_vanguard" or breed_name == "renegade_vanguard" then
            return mod.fallback_breed_colors.shield
        elseif tags.disabler then
            return mod.fallback_breed_colors.disabler
        elseif tags.special and tags.sniper then
            return mod.fallback_breed_colors.sniper
        elseif tags.special then
            return mod.fallback_breed_colors.special
        elseif tags.horde then
            return mod.fallback_breed_colors.horde
        elseif tags.roamer then
            return mod.fallback_breed_colors.roamer
        end

        return nil
    end)

    return success and breed_color or mod.fallback_breed_colors.default
end

function mod.get_enemy_display_name(unit)
    if not unit then return nil end

    local success, name = pcall(function()
        local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
        if not unit_data_extension then return nil end

        local breed = unit_data_extension:breed()
        if not breed then return nil end

        local tags = breed.tags
        if not (tags.captain or tags.cultist_captain or tags.elite or tags.monster or tags.special) then
            return nil
        end

        local function safe_localize(text)
            if not text or text == "" or text == "n/a" then
                return nil
            end

            local success, localized = pcall(Localize, text)
            if not success then
                return nil
            end

            if localized and
                type(localized) == "string" and
                localized ~= text and
                not string.find(localized, "^loc_") and
                not string.find(string.lower(localized), "unlocalized") then
                return localized
            end

            return nil
        end

        local boss_extension = ScriptUnit.has_extension(unit, "boss_system")
        if boss_extension then
            local boss_name = boss_extension:display_name()
            local localized = safe_localize(boss_name)
            if localized then
                return localized
            end
        end

        local smart_tag_extension = ScriptUnit.has_extension(unit, "smart_tag_system")
        if smart_tag_extension then
            local smart_tag_name = smart_tag_extension:display_name()
            local localized = safe_localize(smart_tag_name)
            if localized then
                return localized
            end
        end

        if breed.display_name then
            local localized = safe_localize(breed.display_name)
            if localized then
                return localized
            end
        end

        local clean_name = breed.name
        if clean_name then
            clean_name = string.gsub(clean_name, "_", " ")
            clean_name = string.gsub(clean_name, "(%a)([%w_']*)", function(first, rest)
                return string.upper(first) .. string.lower(rest)
            end)
        end

        return clean_name
    end)

    if success and name then
        return name
    else
        return nil
    end
end

function mod.classify_and_score_unit(unit)
    if not unit then return nil, 0 end

    local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
    if not unit_data_extension then return nil, 0 end

    local breed = unit_data_extension:breed()
    if not breed or not breed.tags then return nil, 0 end

    local tags = breed.tags
    local breed_name = breed.name
    local breed_type = "roamer"
    local breed_priority = 0

    if breed_name == "cultist_vanguard" or breed_name == "renegade_vanguard" then
        breed_type = "shield"
        breed_priority = 650
    elseif tags.monster or tags.captain or tags.cultist_captain then
        breed_type = "boss"
        breed_priority = 900
    elseif tags.witch then
        breed_type = "boss"
        breed_priority = 850
    elseif tags.disabler then
        breed_type = "disabler"
        breed_priority = 800
    elseif tags.special and tags.sniper then
        breed_type = "sniper"
        breed_priority = 750
    elseif tags.elite and tags.far or tags.special and tags.far or (tags.elite and tags.close and breed_name == "renegade_plasma_gunner") then
        breed_type = "ranged_elite"
        breed_priority = 700
    elseif tags.elite then
        breed_type = "melee_elite"
        breed_priority = 650
    elseif tags.special then
        breed_type = "special"
        breed_priority = 600
    elseif tags.horde then
        breed_type = "horde"
        breed_priority = 200
    else
        breed_type = "roamer"
        breed_priority = 100
    end

    local health_extension = ScriptUnit.has_extension(unit, "health_system")
    local health_score = 0
    if health_extension then
        local max_health = health_extension:max_health()
        if max_health > 0 then
            local damage_percent = math.min(health_extension:damage_taken() / max_health, 1.0)
            health_score = damage_percent * 1000
        end
    end

    return breed_type, breed_priority + health_score
end

function mod.get_unit_breed_type(unit)
    local breed_type, _ = mod.classify_and_score_unit(unit)
    return breed_type
end

function mod.get_player_display_name(marker)
    if not marker or not marker.data then return nil end

    if marker.data.player then
        return marker.data.player:name()
    end

    if marker.data.player_unit then
        local player_unit = marker.data.player_unit
        local player_unit_spawn_manager = Managers.state.player_unit_spawn
        local player = player_unit_spawn_manager and player_unit_spawn_manager:owner(player_unit)
        if player then
            return player:name()
        end
    end

    return nil
end

function mod.get_companion_display_name(marker)
    if not marker or not marker.data then return nil end

    if type(marker.data) == "table" and type(marker.data.companion_name) == "function" then
        local name = marker.data:companion_name()
        if name and name ~= "" then
            return name
        end
    end

    if marker.data.player_unit then
        local unit = marker.data.player_unit
        local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
        if unit_data_extension then
            local breed = unit_data_extension:breed()
            if breed then
                if breed.display_name then
                    local success, localized = pcall(Localize, breed.display_name)
                    if success and localized and localized ~= breed.display_name and not string.find(localized, "^loc_") then
                        return localized
                    end
                end

                local clean = breed.name
                if clean then
                    clean = string.gsub(clean, "_", " ")
                    clean = string.gsub(clean, "(%a)([%w_']*)", function(first, rest)
                        return string.upper(first) .. string.lower(rest)
                    end)
                    return clean
                end
            end
        end
    end
    return nil
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

    mod.settings.icon_vis.location_attention = mod:get("location_attention_vis")
    mod.settings.icon_vis.location_ping = mod:get("location_ping_vis")
    mod.settings.icon_vis.location_threat = mod:get("location_threat_vis")
    mod.settings.icon_vis.unit_threat = mod:get("unit_threat_vis")
    mod.settings.icon_vis.unit_threat_adamant = mod:get("unit_threat_adamant_vis")
    mod.settings.icon_vis.unit_threat_companion = mod:get("unit_threat_adamant_vis")
    mod.settings.icon_vis.unit_threat_veteran = mod:get("unit_threat_adamant_vis")

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

    local status_icon_style = mod:get("status_icon_style")
    mod.settings.status_icon_style = status_icon_style
    mod.settings.icon_vis.player_assistance = (status_icon_style ~= "hidden")

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

    mod.settings.enemy_radar_enabled = mod:get("enemy_radar_enabled")
    mod.settings.enemy_radar_scan_range = mod:get("enemy_radar_scan_range") or 50.0


    mod.settings.enemy_radar_filters = {
        disabler = mod:get("enemy_radar_filter_disabler"),
        sniper = mod:get("enemy_radar_filter_sniper"),
        shield = mod:get("enemy_radar_filter_shield"),
        ranged_elite = mod:get("enemy_radar_filter_ranged_elite"),
        melee_elite = mod:get("enemy_radar_filter_melee_elite"),
        special = mod:get("enemy_radar_filter_special"),
        boss = mod:get("enemy_radar_filter_boss"),
        horde = mod:get("enemy_radar_filter_horde"),
        roamer = mod:get("enemy_radar_filter_roamer"),
    }
    mod.settings.enemy_radar_limits = {
        disabler = mod:get("enemy_radar_limit_disabler"),
        sniper = mod:get("enemy_radar_limit_sniper"),
        shield = mod:get("enemy_radar_limit_shield"),
        ranged_elite = mod:get("enemy_radar_limit_ranged_elite"),
        melee_elite = mod:get("enemy_radar_limit_melee_elite"),
        special = mod:get("enemy_radar_limit_special"),
        boss = mod:get("enemy_radar_limit_boss"),
        horde = mod:get("enemy_radar_limit_horde"),
        roamer = mod:get("enemy_radar_limit_roamer"),
    }

    mod.settings.enemy_radar_priority_mode = mod:get("enemy_radar_priority_mode") or "damage"

    mod.settings.enemy_clustering_enabled = mod:get("enemy_clustering_enabled")
    mod.settings.enemy_clustering_radius = mod:get("enemy_clustering_radius") or 3.0
    mod.settings.enemy_clustering_threshold = mod:get("enemy_clustering_threshold") or 3
    mod.settings.enemy_clustering_show_type = mod:get("enemy_clustering_show_type")

    mod.settings.enemy_radar_melee_ring_enabled = mod:get("enemy_radar_melee_ring_enabled")
    mod.settings.enemy_radar_melee_range = mod:get("enemy_radar_melee_range")
    mod.settings.enemy_radar_melee_ring_color_r = mod:get("enemy_radar_melee_ring_color_r") or 180
    mod.settings.enemy_radar_melee_ring_color_g = mod:get("enemy_radar_melee_ring_color_g") or 180
    mod.settings.enemy_radar_melee_ring_color_b = mod:get("enemy_radar_melee_ring_color_b") or 180
    mod.settings.enemy_radar_melee_ring_opacity = mod:get("enemy_radar_melee_ring_opacity")

    mod.settings.enemy_radar_vertical_distance_enabled = mod:get("enemy_radar_vertical_distance_enabled")
    mod.settings.enemy_radar_vertical_distance_threshold = mod:get("enemy_radar_vertical_distance_threshold")
    mod.settings.enemy_radar_vertical_distance_transparency = mod:get("enemy_radar_vertical_distance_transparency")

    mod.settings.distance_markers = {
        players = mod:get("distance_marker_players"),
        companions = mod:get("distance_marker_companions"),
        enemies = mod:get("distance_marker_enemies"),
        objectives = mod:get("distance_marker_objectives"),
        interactables = mod:get("distance_marker_interactables"),
        pings = mod:get("distance_marker_pings"),
        only_out_of_range = mod:get("distance_marker_only_out_of_range"),
    }

    mod.settings.display_names = {
        display_name_players = mod:get("display_name_players"),
        display_name_companions = mod:get("display_name_companions"),
    }

    mod.settings.enemy_name_filters = {
        only_pinged = mod:get("enemy_name_filter_only_pinged"),
        boss = mod:get("enemy_name_filter_boss"),
        disabler = mod:get("enemy_name_filter_disabler"),
        sniper = mod:get("enemy_name_filter_sniper"),
        shield = mod:get("enemy_name_filter_shield"),
        ranged_elite = mod:get("enemy_name_filter_ranged_elite"),
        melee_elite = mod:get("enemy_name_filter_melee_elite"),
        special = mod:get("enemy_name_filter_special"),
    }
end


mod.on_all_mods_loaded = function()
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

mod:io_dofile("minimap/scripts/mods/minimap/compatibility/minimap_strikemap")