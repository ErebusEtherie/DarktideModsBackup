local config = {}

config.UNKNOWN_BREED_KEY = "unknown_units"
config.LOS_BEHAVIOR_GLOBAL = "global"
config.LOS_BEHAVIOR_ENABLED = "enabled"
config.LOS_BEHAVIOR_DISABLED = "disabled"

local CATEGORY_ORDER = {
    captain = 1,
    monster = 2,
    witch = 3,
    disabler = 4,
    sniper = 5,
    elite = 6,
    far = 7,
    special = 8,
    shield = 9,
    enemy = 10,
    ranged_horde = 11,
    melee_horde = 12,
    unknown = 13,
}

local CATEGORY_LABELS = {
    melee_horde = "melee horde",
    ranged_horde = "ranged horde",
    monster = "miniboss",
    captain = "boss",
    disabler = "disabler",
    witch = "daemonhost",
    sniper = "sniper",
    far = "ranged elite",
    elite = "melee elite",
    special = "special",
    shield = "vanguard (shields)",
    enemy = "ritualist",
    unknown = "unknown",
}

local CATEGORY_POWER = {
    captain = 1200,
    monster = 1150,
    witch = 1100,
    disabler = 980,
    sniper = 960,
    elite = 900,
    far = 860,
    special = 820,
    shield = 780,
    enemy = 740,
    ranged_horde = 520,
    melee_horde = 420,
    unknown = 0,
}

local BREED_POWER_ADJUST = {
    renegade_twin_captain = 40,
    renegade_twin_captain_two = 35,
    cultist_captain_heavy = 20,

    chaos_beast_of_nurgle = 30,
    chaos_spawn = 20,
    chaos_plague_ogryn = 10,
    chaos_ogryn_houndmaster = 5,
    chaos_mutator_daemonhost = 15,
    chaos_daemonhost = 10,

    cultist_mutant_mutator = 25,
    cultist_mutant = 20,
    renegade_netgunner = 15,
    chaos_hound_mutator = 10,
    chaos_armored_hound = 5,

    chaos_ogryn_gunner = 35,
    chaos_ogryn_executor = 30,
    chaos_ogryn_bulwark = 20,
    renegade_executor = 15,
    renegade_plasma_gunner = 20,
    cultist_plasma_gunner = 18,
    renegade_gunner = 15,
    cultist_gunner = 14,
    renegade_shocktrooper = 12,
    cultist_shocktrooper = 11,
    renegade_radio_operator = 8,
    renegade_berzerker = 10,
    cultist_berzerker = 9,
    renegade_flamer_mutator = 18,
    renegade_flamer = 12,
    cultist_flamer = 11,
    renegade_grenadier = 10,
    cultist_grenadier = 9,
    chaos_poxwalker_bomber = 8,

    chaos_armored_infected = 15,
    chaos_mutated_poxwalker = 12,
    chaos_lesser_mutated_poxwalker = 10,
    chaos_poxwalker = 8,
    chaos_newly_infected = 5,
    renegade_melee = 9,
    cultist_melee = 8,
    renegade_assault = 18,
    cultist_assault = 17,
    renegade_rifleman = 16,
    cultist_rifleman = 15,

    renegade_vanguard = 8,
    cultist_vanguard = 7,
    chaos_mutator_ritualist = 6,
    cultist_ritualist = 5,
}

local CATEGORY_DEFAULTS = {
    monster = {
        color_r = 180,
        color_g = 0,
        color_b = 255,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
    captain = {
        color_r = 255,
        color_g = 140,
        color_b = 0,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
    disabler = {
        color_r = 255,
        color_g = 255,
        color_b = 0,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
    witch = {
        color_r = 255,
        color_g = 0,
        color_b = 180,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
    sniper = {
        color_r = 255,
        color_g = 0,
        color_b = 0,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
    far = {
        color_r = 0,
        color_g = 255,
        color_b = 120,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
    elite = {
        color_r = 0,
        color_g = 120,
        color_b = 255,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
    special = {
        color_r = 255,
        color_g = 0,
        color_b = 255,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
    shield = {
        color_r = 200,
        color_g = 200,
        color_b = 200,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
    melee_horde = {
        color_r = 150,
        color_g = 60,
        color_b = 60,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
    ranged_horde = {
        color_r = 190,
        color_g = 110,
        color_b = 60,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
    enemy = {
        color_r = 200,
        color_g = 200,
        color_b = 200,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
    unknown = {
        color_r = 200,
        color_g = 200,
        color_b = 200,
        visibility = 100,
        distance = 120,
        enabled = true,
    },
}

local BREED_CATEGORY_OVERRIDES = {
    chaos_beast_of_nurgle = "monster",
    chaos_daemonhost = "witch",
    chaos_spawn = "monster",
    chaos_plague_ogryn = "monster",
    chaos_ogryn_houndmaster = "monster",
    renegade_captain = "captain",
    cultist_captain = "captain",
    cultist_captain_heavy = "captain",
    renegade_twin_captain = "captain",
    renegade_twin_captain_two = "captain",
    cultist_vanguard = "shield",
    renegade_vanguard = "shield",
}

local BREED_BLACKLIST = {
    attack_valkyrie = true,
    nurgle_flies = true,
    sand_vortex = true,
}

local BREED_ALIASES = {
    renegade_assault = "renegade_rifleman",
    cultist_assault = "cultist_rifleman",
    scab_assault = "renegade_rifleman",
    dreg_assault = "cultist_rifleman",
    scab_rifleman = "renegade_rifleman",
    dreg_rifleman = "cultist_rifleman",
    scab_bomber = "renegade_grenadier",
    scab_flamer = "renegade_flamer",
    dreg_tox_flamer = "cultist_flamer",
    dreg_tox_bomber = "chaos_poxwalker_bomber",
    chaos_grenadier = "cultist_grenadier",
    chaos_mauler = "renegade_executor",
    chaos_mutant = "cultist_mutant",
    chaos_rager = "cultist_berzerker",
    chaos_plague_ogryn_sprayer = "chaos_plague_ogryn",
    cultist_captain = "renegade_captain",
    cultist_captain_heavy = "renegade_captain",
    renegade_twin_captain = "renegade_captain",
    renegade_twin_captain_two = "renegade_captain",
}

local FALLBACK_BREEDS = {
    { breed_name = "chaos_beast_of_nurgle", display_name = "Beast of Nurgle", category = "monster" },
    { breed_name = "chaos_daemonhost", display_name = "Daemonhost", category = "witch" },
    { breed_name = "chaos_spawn", display_name = "Chaos Spawn", category = "monster" },
    { breed_name = "chaos_plague_ogryn", display_name = "Plague Ogryn", category = "monster" },
    { breed_name = "chaos_ogryn_houndmaster", display_name = "Houndmaster", category = "monster" },
    { breed_name = "renegade_captain", display_name = "Captain", category = "captain" },
    { breed_name = "cultist_captain", display_name = "Captain (Cultist)", category = "captain" },
    { breed_name = "cultist_captain_heavy", display_name = "Captain Heavy (Cultist)", category = "captain" },
    { breed_name = "renegade_twin_captain", display_name = "Twin Captain", category = "captain" },
    { breed_name = "renegade_twin_captain_two", display_name = "Twin Captain Two", category = "captain" },

    { breed_name = "chaos_ogryn_bulwark", display_name = "Bulwark", category = "elite" },
    { breed_name = "chaos_ogryn_executor", display_name = "Crusher", category = "elite" },
    { breed_name = "chaos_ogryn_gunner", display_name = "Reaper", category = "far" },
    { breed_name = "cultist_berzerker", display_name = "Rager (Cultist)", category = "elite" },
    { breed_name = "renegade_berzerker", display_name = "Rager (Renegade)", category = "elite" },
    { breed_name = "cultist_shocktrooper", display_name = "Shotgunner (Cultist)", category = "far" },
    { breed_name = "renegade_shocktrooper", display_name = "Shotgunner (Renegade)", category = "far" },
    { breed_name = "renegade_executor", display_name = "Mauler", category = "elite" },
    { breed_name = "cultist_gunner", display_name = "Gunner (Cultist)", category = "far" },
    { breed_name = "renegade_gunner", display_name = "Gunner (Renegade)", category = "far" },

    { breed_name = "chaos_hound", display_name = "Hound", category = "disabler" },
    { breed_name = "chaos_armored_hound", display_name = "Armored Hound", category = "disabler" },
    { breed_name = "chaos_poxwalker_bomber", display_name = "Bomber", category = "special" },
    { breed_name = "cultist_mutant", display_name = "Mutant", category = "disabler" },
    { breed_name = "cultist_mutant_mutator", display_name = "Mutated Mutant", category = "disabler" },
    { breed_name = "renegade_sniper", display_name = "Sniper", category = "sniper" },
    { breed_name = "cultist_flamer", display_name = "Flamer (Cultist)", category = "special" },
    { breed_name = "renegade_flamer", display_name = "Flamer (Renegade)", category = "special" },
    { breed_name = "renegade_flamer_mutator", display_name = "Mutated Flamer (Renegade)", category = "special" },
    { breed_name = "cultist_grenadier", display_name = "Grenadier (Cultist)", category = "special" },
    { breed_name = "renegade_grenadier", display_name = "Grenadier (Renegade)", category = "special" },
    { breed_name = "renegade_netgunner", display_name = "Trapper", category = "disabler" },
    { breed_name = "renegade_plasma_gunner", display_name = "Plasma Gunner (Renegade)", category = "far" },
    { breed_name = "cultist_plasma_gunner", display_name = "Plasma Gunner (Cultist)", category = "far" },

    { breed_name = "chaos_poxwalker", display_name = "Poxwalker", category = "melee_horde" },
    { breed_name = "chaos_armored_infected", display_name = "Armored Infected", category = "melee_horde" },
    { breed_name = "chaos_lesser_mutated_poxwalker", display_name = "Lesser Mutated Poxwalker", category = "melee_horde" },
    { breed_name = "chaos_mutated_poxwalker", display_name = "Mutated Poxwalker", category = "melee_horde" },
    { breed_name = "chaos_newly_infected", display_name = "Newly Infected", category = "melee_horde" },
    { breed_name = "chaos_hound_mutator", display_name = "Mutated Hound", category = "disabler" },
    { breed_name = "chaos_mutator_daemonhost", display_name = "Mutated Daemonhost", category = "witch" },
    { breed_name = "chaos_mutator_ritualist", display_name = "Mutated Ritualist", category = "enemy" },
    { breed_name = "cultist_assault", display_name = "Assault (Cultist)", category = "ranged_horde" },
    { breed_name = "cultist_rifleman", display_name = "Rifleman (Cultist)", category = "ranged_horde" },
    { breed_name = "renegade_assault", display_name = "Assault (Renegade)", category = "ranged_horde" },
    { breed_name = "renegade_rifleman", display_name = "Rifleman (Renegade)", category = "ranged_horde" },
    { breed_name = "cultist_melee", display_name = "Melee (Cultist)", category = "melee_horde" },
    { breed_name = "renegade_melee", display_name = "Melee (Renegade)", category = "melee_horde" },
    { breed_name = "cultist_vanguard", display_name = "Vanguard (Cultist)", category = "shield" },
    { breed_name = "renegade_vanguard", display_name = "Vanguard (Renegade)", category = "shield" },
    { breed_name = "cultist_ritualist", display_name = "Ritualist (Cultist)", category = "enemy" },
    { breed_name = "renegade_radio_operator", display_name = "Radio Operator", category = "far" },
}

local _cached_ordered_entries = nil
local _cached_entry_by_breed = nil

local function shallow_copy(tbl)
    local out = {}
    for key, value in pairs(tbl) do
        out[key] = value
    end
    return out
end

local function format_breed_name(breed_name)
    local text = tostring(breed_name or "Unknown")
    text = text:gsub("_", " ")

    return text:gsub("(%a)([%w]*)", function(first, rest)
        return first:upper() .. rest
    end)
end

local function normalize_breed_key(breed_name)
    if type(breed_name) ~= "string" or breed_name == "" then
        return nil
    end

    local normalized = breed_name
    local alias = BREED_ALIASES[normalized]
    if alias then
        normalized = alias
    end

    if normalized:find("_mutator", 1, true) then
        normalized = normalized:gsub("_mutator", "")
    end

    alias = BREED_ALIASES[normalized]
    if alias then
        normalized = alias
    end

    if normalized:find("houndmaster", 1, true) or normalized:find("pack_master", 1, true) then
        normalized = "chaos_ogryn_houndmaster"
    end

    return normalized
end

local function normalize_display_name(display_name, breed_name)
    if type(display_name) == "string" and display_name ~= "" then
        local ok, localized_name = pcall(Localize, display_name)
        if ok and type(localized_name) == "string" and localized_name ~= "" and localized_name ~= display_name then
            return localized_name
        end

        if not display_name:find("^loc_", 1) then
            return display_name
        end
    end

    return format_breed_name(breed_name)
end

local function is_trackable_enemy(tags)
    if not tags then
        return false
    end

    return tags.horde
        or tags.roamer
        or tags.captain
        or tags.cultist_captain
        or tags.witch
        or tags.monster
        or tags.disabler
        or tags.special
        or tags.elite
        or tags.enemy
end

local function classify_breed(tags, breed_name)
    local category_override = BREED_CATEGORY_OVERRIDES[breed_name]
    if category_override then
        return category_override
    end

    if not tags then
        return "enemy"
    end

    if tags.horde or tags.roamer then
        if tags.far then
            return "ranged_horde"
        end

        return "melee_horde"
    end

    if tags.captain or tags.cultist_captain then
        return "captain"
    end

    if tags.witch then
        return "witch"
    end

    if tags.monster then
        return "monster"
    end

    if tags.disabler then
        return "disabler"
    end

    if tags.special and tags.sniper then
        return "sniper"
    end

    if (tags.elite and tags.far) or (tags.special and tags.far) or (tags.elite and tags.close) then
        return "far"
    end

    if tags.elite then
        return "elite"
    end

    if tags.special then
        return "special"
    end

    return "enemy"
end

local function get_breed_power_score(category, breed_name)
    local base_power = CATEGORY_POWER[category] or 0
    local adjust = BREED_POWER_ADJUST[breed_name] or 0

    return base_power + adjust
end

local function build_entry(breed_name, display_name, category)
    local defaults = shallow_copy(CATEGORY_DEFAULTS[category] or CATEGORY_DEFAULTS.enemy)

    return {
        breed_name = breed_name,
        display_name = display_name,
        category = category,
        category_index = CATEGORY_ORDER[category] or 999,
        power_score = get_breed_power_score(category, breed_name),
        defaults = defaults,
    }
end

local function sort_entries(entries)
    table.sort(entries, function(a, b)
        if a.power_score ~= b.power_score then
            return a.power_score > b.power_score
        end

        if a.category_index ~= b.category_index then
            return a.category_index < b.category_index
        end

        if a.display_name ~= b.display_name then
            return a.display_name:lower() < b.display_name:lower()
        end

        return a.breed_name < b.breed_name
    end)
end

local function merge_missing_fallback_entries(entries, entry_by_breed)
    for i = 1, #FALLBACK_BREEDS do
        local item = FALLBACK_BREEDS[i]
        local normalized_breed_name = normalize_breed_key(item.breed_name)
        if normalized_breed_name and not entry_by_breed[normalized_breed_name] then
            local entry = build_entry(normalized_breed_name, item.display_name, item.category)
            entries[#entries + 1] = entry
            entry_by_breed[normalized_breed_name] = entry
        end
    end
end

local function build_entries_from_game_data()
    local ok_queries, BreedQueries = pcall(require, "scripts/utilities/breed_queries")
    if not ok_queries or not BreedQueries then
        return nil, nil
    end

    local minion_breeds = BreedQueries.minion_breeds_by_name()
    if type(minion_breeds) ~= "table" then
        return nil, nil
    end

    local entries = {}
    local entry_by_breed = {}

    for breed_name, breed in pairs(minion_breeds) do
        local normalized_breed_name = normalize_breed_key(breed_name)
        if normalized_breed_name
            and not BREED_BLACKLIST[breed_name]
            and not BREED_BLACKLIST[normalized_breed_name]
            and not entry_by_breed[normalized_breed_name]
        then
            local tags = breed and breed.tags
            if is_trackable_enemy(tags) then
                local category = classify_breed(tags, normalized_breed_name)
                local display_name = normalize_display_name(breed and breed.display_name, normalized_breed_name)
                local entry = build_entry(normalized_breed_name, display_name, category)

                entries[#entries + 1] = entry
                entry_by_breed[normalized_breed_name] = entry
            end
        end
    end

    if #entries <= 0 then
        return nil, nil
    end

    -- Keep critical known breeds from fallback when runtime BreedQueries omits them.
    merge_missing_fallback_entries(entries, entry_by_breed)

    sort_entries(entries)

    return entries, entry_by_breed
end

local function build_entries_from_fallback()
    local entries = {}
    local entry_by_breed = {}

    for i = 1, #FALLBACK_BREEDS do
        local item = FALLBACK_BREEDS[i]
        local normalized_breed_name = normalize_breed_key(item.breed_name)
        if normalized_breed_name and not entry_by_breed[normalized_breed_name] then
            local entry = build_entry(normalized_breed_name, item.display_name, item.category)
            entries[#entries + 1] = entry
            entry_by_breed[normalized_breed_name] = entry
        end
    end

    sort_entries(entries)

    return entries, entry_by_breed
end

local function ensure_cache()
    if _cached_ordered_entries and _cached_entry_by_breed then
        return
    end

    local entries, entry_by_breed = build_entries_from_game_data()

    if not entries or not entry_by_breed then
        entries, entry_by_breed = build_entries_from_fallback()
    end

    _cached_ordered_entries = entries
    _cached_entry_by_breed = entry_by_breed
end

function config.get_ordered_breed_entries()
    ensure_cache()
    return _cached_ordered_entries
end

function config.get_entry_by_breed()
    ensure_cache()
    return _cached_entry_by_breed
end

function config.get_unknown_defaults()
    return shallow_copy(CATEGORY_DEFAULTS.unknown)
end

function config.get_category_label(category)
    return CATEGORY_LABELS[category] or CATEGORY_LABELS.enemy
end

function config.get_setting_ids(breed_key)
    local safe_key = tostring(breed_key):gsub("[^%w_]", "_")
    local prefix = "breed_" .. safe_key

    return {
        group = prefix .. "_group",
        enabled = prefix .. "_enabled",
        los_behavior = prefix .. "_los_behavior",
        visibility = prefix .. "_visibility",
        distance = prefix .. "_distance",
        color_r = prefix .. "_color_r",
        color_g = prefix .. "_color_g",
        color_b = prefix .. "_color_b",
    }
end

function config.get_outline_slot_name(breed_key)
    local safe_key = tostring(breed_key):gsub("[^%w_]", "_")
    return "emperor_vision_outline_" .. safe_key
end

function config.normalize_breed_name(breed_name)
    return normalize_breed_key(breed_name)
end

function config.normalize_los_behavior(value)
    if value == config.LOS_BEHAVIOR_ENABLED or value == config.LOS_BEHAVIOR_DISABLED then
        return value
    end

    return config.LOS_BEHAVIOR_GLOBAL
end

function config.classify_runtime_breed(tags, breed_name)
    if not is_trackable_enemy(tags) then
        return nil
    end

    return classify_breed(tags, breed_name)
end

return config
