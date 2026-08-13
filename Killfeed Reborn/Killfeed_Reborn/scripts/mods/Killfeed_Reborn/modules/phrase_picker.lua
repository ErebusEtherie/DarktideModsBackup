local phrase_picker = {}

local BROAD_CATEGORIES = { "melee", "ranged" }
local phrase_bags = {}
local last_phrase_indices = {}

local function is_broad_category(category)
    return category == "generic" or category == "melee" or category == "ranged"
end

local function choose_random_category(categories)
    return categories and categories[#categories > 0 and math.random(#categories) or 1] or nil
end

local function choose_phrase_pool(detected_category, source_entry, settings)
    if source_entry then
        local broad = source_entry.broad or {}
        local specific = source_entry.specific or {}

        if #broad > 0 and #specific > 0 then
            local roll = math.random(100)
            local choose_broad = roll <= settings.generic_specific

            return choose_broad and choose_random_category(broad) or choose_random_category(specific)
        end

        if #specific > 0 then
            return choose_random_category(specific)
        end

        if #broad > 0 then
            return choose_random_category(broad)
        end
    end

    if detected_category and not is_broad_category(detected_category) then
        local roll = math.random(100)

        if roll <= settings.generic_specific then
            return choose_random_category(BROAD_CATEGORIES)
        end

        return detected_category
    end

    if detected_category == "generic" then
        return choose_random_category(BROAD_CATEGORIES)
    end

    return detected_category or "melee"
end

local function apply_funny_override(category, settings)
    if not category or is_broad_category(category) or settings.funny_chance <= 0 then
        return category
    end

    local roll = math.random(100)
    return roll <= settings.funny_chance and "funny" or category
end

-- Phrases: bag selection
-- Shuffles each phrase pool and avoids repeating the previous phrase when possible.
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

    return bag
end

function phrase_picker.reset()
    phrase_bags = {}
    last_phrase_indices = {}
end

function phrase_picker.random_phrase(phrases, detected_category, source_entry, settings)
    local base_category = choose_phrase_pool(detected_category, source_entry, settings)
    local category = apply_funny_override(base_category, settings)
    local pool = phrases[category] or phrases.funny or phrases.melee or phrases.ranged

    if not pool or #pool == 0 then
        return { text = "deleted", use_determiner = true }, "funny"
    end

    if #pool == 1 then
        return pool[1], category
    end

    local bag = phrase_bags[category]
    if not bag or #bag == 0 then
        bag = refill_phrase_bag(category, pool)
    end

    local phrase_index = table.remove(bag)
    last_phrase_indices[category] = phrase_index

    return pool[phrase_index], category
end

function phrase_picker.random_death_phrase(phrases, bucket)
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

return phrase_picker
