-- Setup (core references)
local mod = get_mod("Killfeed_Reborn")
local Breed = mod:original_require("scripts/utilities/breed")
local AttackSettings = mod:original_require("scripts/settings/damage/attack_settings")
local PlayerUnitStatus = mod:original_require("scripts/utilities/attack/player_unit_status")
local attack_results = AttackSettings.attack_results

-- Paths (external files)
local PATHS = {
    phrases = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/Killfeed_Reborn_phrases",
    debug = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/Killfeed_Reborn_debug",
    localization = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/Killfeed_Reborn_localization",
    classification = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/Killfeed_Reborn_classification",
}
local COMBAT_FEED_DEFINITIONS_PATH = "scripts/ui/hud/elements/combat_feed/hud_element_combat_feed_definitions"
local COMBAT_FEED_SETTINGS_PATH = "scripts/ui/hud/elements/combat_feed/hud_element_combat_feed_settings"

-- Categories (kill classification)
local BROAD_CATEGORIES = { "melee", "ranged" }
local EXACT_CATEGORY_ORDER = { "electric", "warp", "burn", "bleed", "toxin", "explosive", "sharp", "blunt" }

-- Settings (color group titles)
local CATEGORY_TITLE_BY_SETTING = {
    killer_1_r = "killer_1_color_group",
    killer_1_g = "killer_1_color_group",
    killer_1_b = "killer_1_color_group",
    killer_2_r = "killer_2_color_group",
    killer_2_g = "killer_2_color_group",
    killer_2_b = "killer_2_color_group",
    killer_3_r = "killer_3_color_group",
    killer_3_g = "killer_3_color_group",
    killer_3_b = "killer_3_color_group",
    killer_4_r = "killer_4_color_group",
    killer_4_g = "killer_4_color_group",
    killer_4_b = "killer_4_color_group",
    action_r = "action_color_group",
    action_g = "action_color_group",
    action_b = "action_color_group",
    death_action_r = "death_action_color_group",
    death_action_g = "death_action_color_group",
    death_action_b = "death_action_color_group",
    victim_r = "victim_color_group",
    victim_g = "victim_color_group",
    victim_b = "victim_color_group",
}

-- State (runtime caches)
local phrases = {}
local debug_utils
local phrase_bags = {}
local phrase_bag_cycles = {}
local last_phrase_indices = {}
local last_damage = {}
local recent_player_state_messages = {}
local active_combat_feed
local get_killer_color
local is_player_unit
local is_local_player_unit
local should_show_for_metrics

-- Settings (cached values)
local settings = {
    metrics = "team",
    message_duration = 5,
    fade_out = 1,
    category_check = false,
    output_to_file = false,
    local_player = false,
    generic_specific = 70,
    funny_chance = 10,
    neon = true,
    max_messages = 8,
}

-- Colors (cached values)
local colors = {
    killers = {
        [1] = { 255, 230, 130 },
        [2] = { 120, 180, 255 },
        [3] = { 140, 230, 170 },
        [4] = { 255, 150, 210 },
    },
    action = { 255, 255, 255 },
    death_action = { 175, 0, 255 },
    victim = { 255, 90, 90 },
}

-- Classification (external tables)
local classification = mod:io_dofile(PATHS.classification) or {}
local damage_tables = classification.kill or {}
local death_bucket_map = classification.death or {}

-- Feed Layout (combat feed definitions)
mod:hook_require(COMBAT_FEED_DEFINITIONS_PATH, function(instance)
    local width = 600
    local side_padding = 10
    local icon_width = 40
    local text_width = width - (icon_width + side_padding * 2)

    instance.scenegraph_definition.background.size[1] = width

    local widget = instance.notification_message_default
    local text_style = widget.style and widget.style.text

    if text_style then
        text_style.size[1] = text_width
    end
end)

-- Feed Defaults (combat feed settings)
mod:hook_require(COMBAT_FEED_SETTINGS_PATH, function(instance)
    instance.max_messages = mod:get("max_messages") or settings.max_messages or instance.max_messages
end)

-- Localization (DMF strings)
mod:io_dofile(PATHS.localization)

-- Determiners (message grammar)
local determiners = {
    { text = "a", weight = 2 },
    { text = "the", weight = 2 },
    { text = "another", weight = 1 },
}
local death_source_determiners = {
    { text = "A", weight = 2 },
    { text = "The", weight = 2 },
}

local determiner_total = 0
for i = 1, #determiners do
    determiner_total = determiner_total + determiners[i].weight
end
local death_source_determiner_total = 0
for i = 1, #death_source_determiners do
    death_source_determiner_total = death_source_determiner_total + death_source_determiners[i].weight
end

-- Files (lazy loading)
local function get_debug_utils()
    if not debug_utils then
        debug_utils = mod:io_dofile(PATHS.debug)
    end

    return debug_utils
end

local function load_phrases()
    phrases = mod:io_dofile(PATHS.phrases) or {}
    phrase_bags = {}
    phrase_bag_cycles = {}
    last_phrase_indices = {}
end

-- Settings (cache refresh)
local function refresh_cached_settings()
    settings.metrics = mod:get("metrics") or "team"
    settings.message_duration = mod:get("message_duration") or 5
    settings.fade_out = mod:get("fade_out") or 1
    settings.category_check = mod:get("category_check") == true
    settings.output_to_file = mod:get("output_to_file") == true
    settings.local_player = mod:get("local_player") == true
    settings.generic_specific = mod:get("generic_specific") or 70
    settings.funny_chance = mod:get("funny_chance") or 10
    settings.neon = mod:get("neon") ~= false
    settings.max_messages = mod:get("max_messages") or 8

    colors.killers[1][1] = mod:get("killer_1_r") or 255
    colors.killers[1][2] = mod:get("killer_1_g") or 230
    colors.killers[1][3] = mod:get("killer_1_b") or 130

    colors.killers[2][1] = mod:get("killer_2_r") or 120
    colors.killers[2][2] = mod:get("killer_2_g") or 180
    colors.killers[2][3] = mod:get("killer_2_b") or 255

    colors.killers[3][1] = mod:get("killer_3_r") or 140
    colors.killers[3][2] = mod:get("killer_3_g") or 230
    colors.killers[3][3] = mod:get("killer_3_b") or 170

    colors.killers[4][1] = mod:get("killer_4_r") or 255
    colors.killers[4][2] = mod:get("killer_4_g") or 150
    colors.killers[4][3] = mod:get("killer_4_b") or 210

    colors.action[1] = mod:get("action_r") or 255
    colors.action[2] = mod:get("action_g") or 255
    colors.action[3] = mod:get("action_b") or 255

    colors.death_action[1] = mod:get("death_action_r") or 175
    colors.death_action[2] = mod:get("death_action_g") or 0
    colors.death_action[3] = mod:get("death_action_b") or 255

    colors.victim[1] = mod:get("victim_r") or 255
    colors.victim[2] = mod:get("victim_g") or 90
    colors.victim[3] = mod:get("victim_b") or 90
end

-- Feed Settings (runtime apply)
local function apply_combat_feed_timing(combat_feed)
    if not combat_feed then
        return
    end

    local fade_out = settings.fade_out or 1
    local visible_duration = settings.message_duration or 5

    combat_feed._message_duration = visible_duration + fade_out

    local default_template = combat_feed._notification_templates and combat_feed._notification_templates.default
    if default_template then
        default_template.fade_out = fade_out
    end

    local notifications = combat_feed._notifications
    if notifications then
        for i = 1, #notifications do
            notifications[i].fade_out = fade_out
        end
    end
end

local function apply_combat_feed_message_limit(combat_feed)
    if not combat_feed then
        return
    end

    combat_feed._max_messages = settings.max_messages or 8
end

local function apply_combat_feed_settings(combat_feed)
    apply_combat_feed_timing(combat_feed)
    apply_combat_feed_message_limit(combat_feed)
end

-- Text (markup helpers)
local function strip_markup(text)
    if not text then
        return nil
    end

    local clean = string.gsub(text, "{#.-}", "")
    clean = string.gsub(clean, "{#reset%(%)%}", "")

    return clean
end

-- Settings (color titles)
local function refresh_color_group_title(setting_id)
    local base_key = CATEGORY_TITLE_BY_SETTING[setting_id]
    if not base_key or not mod.apply_colours then
        return
    end

    local dmf = get_mod("DMF")
    if not dmf then
        return
    end

    local updated_loc = mod.apply_colours()
    local localized_group = updated_loc and updated_loc[base_key]
    local language = Managers.localization and Managers.localization:language() or "en"
    local new_title = localized_group and (localized_group[language] or localized_group.en)

    if not new_title or not dmf.options_widgets_data then
        return
    end

    local mod_name = mod:get_name()
    local category_names = { mod:localize("mod_name") }

    for i = 1, #dmf.options_widgets_data do
        local mod_data = dmf.options_widgets_data[i]
        if mod_data[1] and mod_data[1].mod_name == mod_name then
            category_names[#category_names + 1] = mod_data[1].readable_mod_name
            category_names[#category_names + 1] = mod_data[1].title

            for j = 1, #mod_data do
                if mod_data[j].setting_id == base_key then
                    mod_data[j].title = new_title
                    break
                end
            end

            break
        end
    end

    local view = Managers.ui and Managers.ui:view_instance("dmf_options_view")
    local widgets_by_category = view and view._settings_category_widgets
    if not widgets_by_category then
        return
    end

    local mod_widgets
    for i = 1, #category_names do
        if category_names[i] and widgets_by_category[category_names[i]] then
            mod_widgets = widgets_by_category[category_names[i]]
            break
        end
    end

    if not mod_widgets then
        return
    end

    local clean_target = strip_markup(new_title)

    for i = 1, #mod_widgets do
        local content = mod_widgets[i].widget and mod_widgets[i].widget.content
        local entry = content and content.entry

        if entry and entry.setting_id == base_key then
            entry.display_name = new_title
            content.text = new_title
            return
        end

        if content and strip_markup(content.text) == clean_target then
            if entry then
                entry.display_name = new_title
            end
            content.text = new_title
            return
        end
    end
end

-- Categories (phrase selection)
local function is_broad_category(category)
    return category == "generic" or category == "melee" or category == "ranged"
end

local function choose_random_category(categories)
    return categories and categories[#categories > 0 and math.random(#categories) or 1] or nil
end

local function choose_phrase_pool(detected_category, source_entry)
    if source_entry then
        local broad = source_entry.broad or {}
        local specific = source_entry.specific or {}

        if #broad > 0 and #specific > 0 then
            local roll = math.random(100)
            local choose_broad = roll <= settings.generic_specific

            return choose_broad and choose_random_category(broad) or choose_random_category(specific), {
                mode = "source_split",
                roll = roll,
                threshold = settings.generic_specific,
                bucket = choose_broad and "broad" or "specific",
                broad = table.concat(broad, ","),
                specific = table.concat(specific, ","),
            }
        end

        if #specific > 0 then
            return choose_random_category(specific), {
                mode = "source_fixed",
                bucket = "specific",
                broad = "nil",
                specific = table.concat(specific, ","),
            }
        end

        if #broad > 0 then
            return choose_random_category(broad), {
                mode = "source_fixed",
                bucket = "broad",
                broad = table.concat(broad, ","),
                specific = "nil",
            }
        end
    end

    if detected_category and not is_broad_category(detected_category) then
        local roll = math.random(100)

        if roll <= settings.generic_specific then
            return choose_random_category(BROAD_CATEGORIES), {
                mode = "fallback_split",
                roll = roll,
                threshold = settings.generic_specific,
                bucket = "broad",
                broad = table.concat(BROAD_CATEGORIES, ","),
                specific = detected_category,
            }
        end

        return detected_category, {
            mode = "fallback_split",
            roll = roll,
            threshold = settings.generic_specific,
            bucket = "specific",
            broad = table.concat(BROAD_CATEGORIES, ","),
            specific = detected_category,
        }
    end

    if detected_category == "generic" then
        local chosen_category = choose_random_category(BROAD_CATEGORIES)

        return chosen_category, {
            mode = "direct_generic",
            bucket = "broad",
            broad = table.concat(BROAD_CATEGORIES, ","),
            specific = "nil",
        }
    end

    return detected_category or "melee", {
        mode = "direct",
        bucket = is_broad_category(detected_category) and "broad" or "specific",
        broad = is_broad_category(detected_category) and tostring(detected_category) or "nil",
        specific = not is_broad_category(detected_category) and tostring(detected_category) or "nil",
    }
end

local function apply_funny_override(category, selection_meta)
    if not category or is_broad_category(category) or settings.funny_chance <= 0 then
        return category, selection_meta
    end

    local roll = math.random(100)
    local funny_applied = roll <= settings.funny_chance

    selection_meta = selection_meta or {}
    selection_meta.funny_roll = roll
    selection_meta.funny_threshold = settings.funny_chance
    selection_meta.funny_applied = funny_applied and "yes" or "no"

    if funny_applied then
        return "funny", selection_meta
    end

    return category, selection_meta
end

-- Phrases (bag selection)
local function refill_phrase_bag(category, pool)
    local bag = {}

    for i = 1, #pool do
        bag[i] = i
    end

    for i = #bag, 2, -1 do
        local j = math.random(i)
        bag[i], bag[j] = bag[j], bag[i]
    end

    local last_phrase_index = last_phrase_indices[category]
    if #bag > 1 and bag[#bag] == last_phrase_index then
        local swap_index = math.random(#bag - 1)
        bag[#bag], bag[swap_index] = bag[swap_index], bag[#bag]
    end

    phrase_bags[category] = bag
    phrase_bag_cycles[category] = (phrase_bag_cycles[category] or 0) + 1
    return bag
end

local function random_phrase(detected_category, source_entry)
    local base_category, selection_meta = choose_phrase_pool(detected_category, source_entry)
    local category
    category, selection_meta = apply_funny_override(base_category, selection_meta)
    local pool = phrases[category] or phrases.funny or phrases.melee or phrases.ranged

    if not pool or #pool == 0 then
        return { text = "deleted", use_determiner = true }, "funny", {
            category = "funny",
            bag_cycle = phrase_bag_cycles.funny or 0,
            bag_remaining = 0,
            pool_size = 0,
            phrase_index = 0,
            selection = selection_meta,
        }
    end

    if #pool == 1 then
        return pool[1], category, {
            category = category,
            bag_cycle = phrase_bag_cycles[category] or 1,
            bag_remaining = 0,
            pool_size = 1,
            phrase_index = 1,
            selection = selection_meta,
        }
    end

    local bag = phrase_bags[category]
    local bag_reset = not bag or #bag == 0

    if bag_reset then
        bag = refill_phrase_bag(category, pool)
    end

    local phrase_index = table.remove(bag)
    last_phrase_indices[category] = phrase_index

    return pool[phrase_index] or pool[1], category, {
        category = category,
        bag_cycle = phrase_bag_cycles[category] or 1,
        bag_remaining = #bag,
        pool_size = #pool,
        phrase_index = phrase_index,
        bag_reset = bag_reset,
        selection = selection_meta,
    }
end

-- Determiners (random selection)
local function random_det()
    local roll = math.random(determiner_total)
    local running_total = 0

    for i = 1, #determiners do
        running_total = running_total + determiners[i].weight
        if roll <= running_total then
            return determiners[i].text
        end
    end

    return "a"
end

local function random_death_source_det()
    local roll = math.random(death_source_determiner_total)
    local running_total = 0

    for i = 1, #death_source_determiners do
        running_total = running_total + death_source_determiners[i].weight
        if roll <= running_total then
            return death_source_determiners[i].text
        end
    end

    return "A"
end

-- Text (color helpers)
local function colorize(text, color)
    return string.format("{#color(%d,%d,%d)}%s{#reset()}", color[1], color[2], color[3], text)
end

local NEON_COLORS = {
    { 255, 0, 180 },
    { 255, 255, 255 },
    { 255, 230, 0 },
}

local function neon_text(text)
    local output = {}
    local char_count = 0
    local char_index = 0

    for i = 1, #text do
        if string.sub(text, i, i) ~= " " then
            char_count = char_count + 1
        end
    end

    for i = 1, #text do
        local char = string.sub(text, i, i)

        if char == " " then
            output[#output + 1] = char
        else
            char_index = char_index + 1
            local t = char_count <= 1 and 0 or (char_index - 1) / (char_count - 1)
            local scaled = t * (#NEON_COLORS - 1)
            local start_index = math.floor(scaled) + 1
            local end_index = math.min(start_index + 1, #NEON_COLORS)
            local local_t = scaled - math.floor(scaled)
            local start_color = NEON_COLORS[start_index]
            local end_color = NEON_COLORS[end_index]
            local r = math.floor(start_color[1] + (end_color[1] - start_color[1]) * local_t + 0.5)
            local g = math.floor(start_color[2] + (end_color[2] - start_color[2]) * local_t + 0.5)
            local b = math.floor(start_color[3] + (end_color[3] - start_color[3]) * local_t + 0.5)

            output[#output + 1] = string.format("{#color(%d,%d,%d)}%s", r, g, b, char)
        end
    end

    output[#output + 1] = "{#reset()}"

    return table.concat(output)
end

-- Feed (message dispatch)
local function add_combat_feed_message(text)
    if Managers.event then
        Managers.event:trigger("event_add_combat_feed_message", text)
    elseif active_combat_feed and active_combat_feed._add_combat_feed_message then
        active_combat_feed:_add_combat_feed_message(text)
    end
end

-- Classification (damage profiles)
local function exact_category_for_profile(profile_name)
    local exact_profiles = damage_tables.exact_profiles or {}

    for i = 1, #EXACT_CATEGORY_ORDER do
        local category = EXACT_CATEGORY_ORDER[i]
        local profile_set = exact_profiles[category]

        if profile_set and profile_set[profile_name] then
            return category
        end
    end

    return nil
end

local function get_category_from_damage(data)
    if not data then
        return "explosive", "fallback no damage data", nil
    end

    local profile_name = string.lower(tostring(data.profile_name or ""))
    local attack_type = string.lower(tostring(data.attack_type or ""))
    local split_entry = damage_tables.split_profiles and damage_tables.split_profiles[profile_name]

    if split_entry then
        local detected = choose_random_category(split_entry.specific) or choose_random_category(split_entry.broad)

        if detected then
            return detected, split_entry.reason or "profile split table", split_entry
        end
    end

    local exact_category = exact_category_for_profile(profile_name)
    if exact_category then
        return exact_category, string.format("exact profile table (%s)", exact_category), nil
    end

    local melee_attack_types = damage_tables.broad_attack_types and damage_tables.broad_attack_types.melee
    if melee_attack_types and melee_attack_types[attack_type] then
        return "melee", "fallback attack_type=melee", nil
    end

    local ranged_attack_types = damage_tables.broad_attack_types and damage_tables.broad_attack_types.ranged
    if ranged_attack_types and ranged_attack_types[attack_type] then
        return "ranged", "fallback attack_type=ranged", nil
    end

    return "generic", "fallback generic", nil
end

-- Names (units)
local function get_name(unit)
    if not unit then
        return nil
    end

    local player_manager = Managers.state and Managers.state.player_unit_spawn
    local player = player_manager and player_manager:owner(unit)
    if player then
        return player:name()
    end

    local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
    local breed = unit_data_extension and unit_data_extension:breed()
    return breed and Breed.is_minion(breed) and Localize(breed.display_name) or nil
end

function is_player_unit(unit)
    local player_manager = Managers.state and Managers.state.player_unit_spawn
    return unit and player_manager and player_manager:owner(unit) ~= nil
end

-- Deaths (source classification)
local function get_death_source(unit)
    if not unit then
        return "environment", "The Environment", false
    end

    local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
    local breed = unit_data_extension and unit_data_extension:breed()

    if not breed or not Breed.is_minion(breed) then
        return "environment", "The Environment", false
    end

    local tags = breed.tags or {}

    if tags.elite or tags.special or tags.monster then
        return death_bucket_map[breed.display_name] or breed.display_name, Localize(breed.display_name), true
    end

    return "lesser_enemy", Localize(breed.display_name), true
end

-- Deaths (phrase selection)
local function random_death_phrase(bucket)
    local death_phrases = phrases.death or {}
    local pool = death_phrases[bucket] or death_phrases.lesser_enemy

    if not pool or #pool == 0 then
        return "Killed"
    end

    local bag_key = "death:" .. tostring(bucket)
    local bag = phrase_bags[bag_key]

    if not bag or #bag == 0 then
        bag = refill_phrase_bag(bag_key, pool)
    end

    local phrase_index = table.remove(bag)
    last_phrase_indices[bag_key] = phrase_index
    local phrase_entry = pool[phrase_index] or pool[1]

    return phrase_entry and phrase_entry.text or "Killed", phrase_entry
end

-- Deaths (message building)
local function add_player_death_message(dead_unit, attacking_unit, state_text, attack_result)
    local player_name = get_name(dead_unit)

    if not player_name then
        return
    end

    local bucket, source_name, use_source_determiner = get_death_source(attacking_unit)
    local phrase, phrase_entry = random_death_phrase(bucket)
    if phrase_entry and phrase_entry.use_determiner == false then
        use_source_determiner = false
    end

    local source_text = source_name
    if use_source_determiner then
        source_text = string.format("%s %s", random_death_source_det(), source_name)
    end

    local text = string.format(
        "%s %s %s",
        colorize(source_text, colors.victim),
        colorize(phrase, colors.death_action),
        colorize(player_name, get_killer_color(dead_unit))
    )

    add_combat_feed_message(text)

    if settings.output_to_file and (is_local_player_unit(dead_unit) or not settings.local_player) then
        get_debug_utils().append_player_state_debug_line(
            dead_unit,
            player_name,
            text,
            state_text,
            bucket,
            attack_result
        )
    end
end

-- Deaths (state detection)
local function maybe_add_player_state_message(attacked_unit, attacking_unit, attack_result)
    if not is_player_unit(attacked_unit) then
        return
    end

    if not should_show_for_metrics(attacked_unit) then
        return
    end

    if attack_result ~= attack_results.knock_down
        and attack_result ~= attack_results.died
        and attack_result ~= attack_results.toughness_broken
        and attack_result ~= attack_results.blocked
        and attack_result ~= attack_results.toughness_absorbed_melee then
        return
    end

    local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
    local character_state_component = unit_data_extension and unit_data_extension:read_component("character_state")
    local action_text

    if character_state_component and PlayerUnitStatus.is_dead(character_state_component) then
        action_text = "Killed"
    elseif character_state_component and PlayerUnitStatus.is_disabled(character_state_component) and character_state_component.state_name == "knocked_down" then
        action_text = "downed"
    elseif attack_result == attack_results.died then
        action_text = "Killed"
    elseif attack_result == attack_results.knock_down then
        action_text = "downed"
    else
        return
    end

    local player_name = get_name(attacked_unit)
    local key = tostring(player_name) .. ":" .. action_text
    local now = os.clock()

    if recent_player_state_messages[key] and now - recent_player_state_messages[key] < 3 then
        return
    end

    recent_player_state_messages[key] = now
    add_player_death_message(attacked_unit, attacking_unit, action_text, attack_result)
end

-- Metrics (local player)
is_local_player_unit = function(unit)
    local local_player = Managers.player and Managers.player:local_player(1)
    return unit and local_player and local_player.player_unit == unit
end

function should_show_for_metrics(unit)
    return settings.metrics ~= "self" or is_local_player_unit(unit)
end

-- Colors (party slots)
local function get_player_slot(unit)
    if not unit or not Managers.player then
        return nil
    end

    local player = Managers.player:player_by_unit(unit)
    return player and player.slot and player:slot() or nil
end

function get_killer_color(unit)
    local slot = get_player_slot(unit)
    return colors.killers[slot] or colors.killers[1]
end

-- Startup (initial cache)
load_phrases()
refresh_cached_settings()

-- Settings (DMF changes)
mod.on_setting_changed = function(setting_id)
    refresh_cached_settings()
    refresh_color_group_title(setting_id)

    if setting_id == "message_duration" or setting_id == "fade_out" then
        apply_combat_feed_timing(active_combat_feed)
    elseif setting_id == "max_messages" then
        apply_combat_feed_message_limit(active_combat_feed)
    end
end

local hooked = false

-- Hooks (registration)
mod.on_all_mods_loaded = function()
    if hooked then
        return
    end

    hooked = true

    -- Hooks (mission lifecycle)
    mod:hook(CLASS.StateGameplay, "on_enter", function(func, self, parent, params, creation_context, ...)
        last_damage = {}
        recent_player_state_messages = {}

        if settings.output_to_file and params and params.mission_name then
            get_debug_utils().begin_mission_output(params.mission_name)
        elseif debug_utils then
            debug_utils.end_mission_output()
        end

        return func(self, parent, params, creation_context, ...)
    end)

    mod:hook(CLASS.StateGameplay, "on_exit", function(func, self, exit_params, ...)
        last_damage = {}
        recent_player_state_messages = {}

        if debug_utils then
            debug_utils.end_mission_output()
        end

        return func(self, exit_params, ...)
    end)

    -- Hooks (attack data)
    mod:hook(CLASS.AttackReportManager, "add_attack_result", function(func, self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
        if attacking_unit and attacked_unit then
            local attacker_cache = last_damage[attacking_unit]

            if not attacker_cache then
                attacker_cache = {}
                last_damage[attacking_unit] = attacker_cache
            end

            attacker_cache[attacked_unit] = {
                profile_name = damage_profile and damage_profile.name or "nil",
                attack_type = attack_type,
                attack_result = attack_result,
                timestamp = os.clock(),
            }
        end

        return func(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
    end)

    mod:hook_safe("AttackReportManager", "_process_attack_result", function(self, buffer_data)
        if not buffer_data then
            return
        end

        maybe_add_player_state_message(buffer_data.attacked_unit, buffer_data.attacking_unit, buffer_data.attack_result)
    end)

    -- Hooks (feed setup)
    mod:hook_safe("HudElementCombatFeed", "init", function(self)
        active_combat_feed = self
        apply_combat_feed_settings(self)
    end)

    local combat_feed = require("scripts/ui/hud/elements/combat_feed/hud_element_combat_feed")

    -- Hooks (feed settings)
    mod:hook(combat_feed, "event_update_combat_feed_message_duration", function(func, self, value)
        func(self, value)
        apply_combat_feed_timing(self)
    end)

    mod:hook(combat_feed, "event_update_combat_feed_max_messages", function(func, self, value)
        func(self, value)
        apply_combat_feed_message_limit(self)
    end)

    mod:hook(combat_feed, "event_add_combat_feed_message", function(func, self, text)
        active_combat_feed = self
        apply_combat_feed_settings(self)

        return func(self, text)
    end)

    -- Hooks (kill messages)
    mod:hook(combat_feed, "event_combat_feed_kill", function(func, self, attacker, victim)
        local killer_name = get_name(attacker)
        local victim_name = get_name(victim)

        if not killer_name or not victim_name then
            return func(self, attacker, victim)
        end

        if not should_show_for_metrics(attacker) then
            return
        end

        local attacker_cache = last_damage[attacker]
        local data = attacker_cache and attacker_cache[victim]
        local detected_category, category_reason, source_entry = get_category_from_damage(data)
        local phrase_entry, chosen_category, phrase_meta = random_phrase(detected_category, source_entry)
        local phrase = phrase_entry and phrase_entry.text or "deleted"
        local use_determiner = phrase_entry == nil or phrase_entry.use_determiner ~= false
        local determiner = use_determiner and random_det() or nil
        local prefix = settings.category_check and colorize("[" .. tostring(chosen_category) .. "]", colors.action) .. " " or ""
        local killer_color = get_killer_color(attacker)
        local use_neon = settings.neon and chosen_category == "funny"
        local phrase_text = use_neon and neon_text(phrase) or colorize(phrase, colors.action)
        local determiner_text = use_determiner and (use_neon and neon_text(determiner) or colorize(determiner, colors.action)) or nil
        local text

        if use_determiner then
            text = string.format(
                "%s%s %s %s %s",
                prefix,
                colorize(killer_name, killer_color),
                phrase_text,
                determiner_text,
                colorize(victim_name, colors.victim)
            )
        else
            text = string.format(
                "%s%s %s %s",
                prefix,
                colorize(killer_name, killer_color),
                phrase_text,
                colorize(victim_name, colors.victim)
            )
        end

        if settings.output_to_file and (is_local_player_unit(attacker) or not settings.local_player) then
            get_debug_utils().append_kill_debug_line(
                attacker,
                killer_name,
                data,
                text,
                detected_category,
                chosen_category,
                category_reason,
                source_entry,
                phrase_meta
            )
        end

        if attacker_cache then
            attacker_cache[victim] = nil

            if next(attacker_cache) == nil then
                last_damage[attacker] = nil
            end
        end

        self:_add_combat_feed_message(text)
    end)
end
