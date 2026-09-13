local mod = get_mod("minimap")

mod.settings = {}
mod.settings.icon_vis = {}

local default_enemy_colors = {
    human_boss = { 255, 255, 50, 100 },
    monster = { 255, 255, 0, 0 },
    disabler = { 255, 0, 255, 0 },
    ranged_special = { 255, 0, 255, 255 },
    poxburster = { 255, 255, 255, 0 },
    ranged_elite = { 255, 0, 0, 255 },
    crushers_maulers = { 255, 255, 80, 0 },
    melee_elite = { 255, 81, 53, 146 },
    shooters = { 255, 245, 245, 135 },
    chaff = { 255, 105, 55, 20 },
}

local function load_enemy_colors_from_settings()
    local colors = {}
    for category, default_col in pairs(default_enemy_colors) do
        local saved = mod:get("color_" .. category)
        if not saved and category == "human_boss" then saved = mod:get("color_captain") or mod:get("color_boss") end
        if not saved and category == "monster" then saved = mod:get("color_monster") or mod:get("color_boss") end
        if not saved and category == "disabler" then saved = mod:get("color_disabler") end
        if not saved and category == "ranged_special" then saved = mod:get("color_special") or mod:get("color_sniper") end
        if not saved and category == "poxburster" then saved = mod:get("color_chaos_poxwalker_bomber") end
        if not saved and category == "ranged_elite" then saved = mod:get("color_ranged_elite") end
        if not saved and category == "crushers_maulers" then saved = mod:get("color_executor") end
        if not saved and category == "melee_elite" then saved = mod:get("color_melee_elite") or mod:get("color_berzerker") end
        if not saved and category == "shooters" then saved = mod:get("color_roamer") end
        if not saved and category == "chaff" then saved = mod:get("color_horde") end

        if saved and type(saved) == "table" and #saved >= 4 then
            colors[category] = saved
        else
            colors[category] = default_col
        end
    end
    return colors
end

mod.settings.enemy_colors = load_enemy_colors_from_settings()

function mod.get_category_color(category)
    if mod.settings.enemy_colors and mod.settings.enemy_colors[category] then
        return mod.settings.enemy_colors[category]
    end
    return default_enemy_colors[category] or { 255, 255, 255, 255 }
end

mod.fallback_breed_colors = mod.settings.enemy_colors

function mod.get_breed_color_fallback(unit)
    if not unit then
        return mod.get_category_color("chaff")
    end
    local breed_type = mod.get_unit_breed_type and mod.get_unit_breed_type(unit) or "chaff"
    return mod.get_category_color(breed_type)
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
    local breed_type = "chaff"
    local breed_priority = 100

    if tags.captain or tags.cultist_captain then
        breed_type = "human_boss"
        breed_priority = 950
    elseif tags.monster or tags.witch then
        breed_type = "monster"
        breed_priority = 900
    elseif tags.disabler or tags.mutant or breed_name == "cultist_mutant" or breed_name == "mutant_charger" then
        breed_type = "disabler"
        breed_priority = 850
    elseif tags.special then
        if tags.bomber or breed_name == "chaos_poxwalker_bomber" then
            breed_type = "poxburster"
            breed_priority = 800
        elseif breed.ranged or tags.scrambler or tags.sniper or string.find(breed_name, "grenadier") or string.find(breed_name, "flamer") then
            breed_type = "ranged_special"
            breed_priority = 750
        else
            breed_type = "poxburster"
            breed_priority = 800
        end
    elseif tags.elite then
        if breed_name == "chaos_ogryn_executor" or breed_name == "renegade_executor" then
            breed_type = "crushers_maulers"
            breed_priority = 700
        elseif breed.ranged or tags.far or breed_name == "renegade_plasma_gunner" or breed_name == "chaos_ogryn_gunner" then
            breed_type = "ranged_elite"
            breed_priority = 650
        else
            breed_type = "melee_elite"
            breed_priority = 600
        end
    elseif breed_name == "cultist_assault" or breed_name == "renegade_assault" or breed_name == "renegade_rifleman" or breed.ranged then
        breed_type = "shooters"
        breed_priority = 300
    else
        breed_type = "chaff"
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
    mod.settings.minimap_background_color = mod:get("minimap_background_color") or {255, 180, 180, 180}
    mod.settings.minimap_background_opacity = mod:get("minimap_background_opacity")

    mod.settings.enemy_radar_enabled = mod:get("enemy_radar_enabled")
    mod.settings.enemy_radar_scan_range = mod:get("enemy_radar_scan_range") or 50.0


    mod.settings.enemy_colors = load_enemy_colors_from_settings()
    mod.fallback_breed_colors = mod.settings.enemy_colors

    local function get_filter(key, fallback_key, default_val)
        local val = mod:get(key)
        if val == nil and fallback_key then val = mod:get(fallback_key) end
        if val == nil then return default_val end
        return val
    end

    mod.settings.enemy_radar_filters = {
        human_boss = get_filter("enemy_radar_filter_human_boss", "enemy_radar_filter_boss", true),
        monster = get_filter("enemy_radar_filter_monster", "enemy_radar_filter_boss", true),
        disabler = get_filter("enemy_radar_filter_disabler", nil, true),
        ranged_special = get_filter("enemy_radar_filter_ranged_special", "enemy_radar_filter_special", true),
        poxburster = get_filter("enemy_radar_filter_poxburster", "enemy_radar_filter_special", true),
        ranged_elite = get_filter("enemy_radar_filter_ranged_elite", nil, true),
        crushers_maulers = get_filter("enemy_radar_filter_crushers_maulers", "enemy_radar_filter_melee_elite", true),
        melee_elite = get_filter("enemy_radar_filter_melee_elite", nil, true),
        shooters = get_filter("enemy_radar_filter_shooters", "enemy_radar_filter_roamer", false),
        chaff = get_filter("enemy_radar_filter_chaff", "enemy_radar_filter_horde", false),
    }

    local function get_limit(key, fallback_key, default_val)
        local val = mod:get(key)
        if val == nil and fallback_key then val = mod:get(fallback_key) end
        if val == nil then return default_val end
        return val
    end

    mod.settings.enemy_radar_limits = {
        human_boss = get_limit("enemy_radar_limit_human_boss", "enemy_radar_limit_boss", 5),
        monster = get_limit("enemy_radar_limit_monster", "enemy_radar_limit_boss", 5),
        disabler = get_limit("enemy_radar_limit_disabler", nil, 10),
        ranged_special = get_limit("enemy_radar_limit_ranged_special", "enemy_radar_limit_special", 10),
        poxburster = get_limit("enemy_radar_limit_poxburster", "enemy_radar_limit_special", 10),
        ranged_elite = get_limit("enemy_radar_limit_ranged_elite", nil, 10),
        crushers_maulers = get_limit("enemy_radar_limit_crushers_maulers", "enemy_radar_limit_melee_elite", 10),
        melee_elite = get_limit("enemy_radar_limit_melee_elite", nil, 10),
        shooters = get_limit("enemy_radar_limit_shooters", "enemy_radar_limit_roamer", 10),
        chaff = get_limit("enemy_radar_limit_chaff", "enemy_radar_limit_horde", 10),
    }

    mod.settings.enemy_radar_priority_mode = mod:get("enemy_radar_priority_mode") or "damage"

    mod.settings.enemy_clustering_enabled = mod:get("enemy_clustering_enabled")
    mod.settings.enemy_clustering_radius = mod:get("enemy_clustering_radius") or 3.0
    mod.settings.enemy_clustering_threshold = mod:get("enemy_clustering_threshold") or 3
    mod.settings.enemy_clustering_show_type = mod:get("enemy_clustering_show_type")

    mod.settings.enemy_radar_melee_ring_enabled = mod:get("enemy_radar_melee_ring_enabled")
    mod.settings.enemy_radar_melee_range = mod:get("enemy_radar_melee_range")
    mod.settings.enemy_radar_melee_ring_color = mod:get("enemy_radar_melee_ring_color") or {255, 255, 165, 0}
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
        human_boss = get_filter("enemy_name_filter_human_boss", "enemy_name_filter_boss", false),
        monster = get_filter("enemy_name_filter_monster", "enemy_name_filter_boss", false),
        disabler = get_filter("enemy_name_filter_disabler", nil, false),
        ranged_special = get_filter("enemy_name_filter_ranged_special", "enemy_name_filter_special", false),
        poxburster = get_filter("enemy_name_filter_poxburster", "enemy_name_filter_special", false),
        ranged_elite = get_filter("enemy_name_filter_ranged_elite", nil, false),
        crushers_maulers = get_filter("enemy_name_filter_crushers_maulers", "enemy_name_filter_melee_elite", false),
        melee_elite = get_filter("enemy_name_filter_melee_elite", nil, false),
        shooters = get_filter("enemy_name_filter_shooters", nil, false),
        chaff = get_filter("enemy_name_filter_chaff", nil, false),
    }
end

mod.on_all_mods_loaded = function()
    collect_settings()
    recreate_hud()
end

local hud_recreate_timer = 0
local HUD_RECREATE_DELAY = 0.1

mod.on_setting_changed = function(setting_id)
    if not setting_id then
        return
    end

    collect_settings()

    if string.find(setting_id, "^color_") then
        return
    end

    if setting_id == "minimap_background_color" or setting_id == "minimap_background_opacity" then
        local ui_manager = Managers.ui
        if ui_manager and ui_manager._hud and ui_manager._hud._elements then
            local minimap = get_hud_minimap_element(ui_manager._hud._elements)
            if minimap and minimap._update_background_color then
                minimap:_update_background_color()
            end
        end
        return
    end

    local current_time = os.clock()
    if current_time - hud_recreate_timer > HUD_RECREATE_DELAY then
        hud_recreate_timer = current_time
        recreate_hud()
    end
end

mod:io_dofile("minimap/scripts/mods/minimap/compatibility/minimap_strikemap")