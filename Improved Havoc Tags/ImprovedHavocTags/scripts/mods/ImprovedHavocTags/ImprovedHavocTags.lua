local mod = get_mod("ImprovedHavocTags")

--[[
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Mod Name: Improved Havoc Tags                                                                                                    │
│ Mod Author: Brunin (brufgsilva on Nexus)                                                                                        │
│ Version: 3.2                                                                                                                    │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
--]]

-- Migration function to convert old color name strings to ARGB tables
local function migrate_color_settings()
    local color_setting_ids = {
        "increased_difficulty",
        "highest_difficulty",
        "bolstering_enemies",
        "encroaching_garden",
        "enraged",
        "chaos_ritual",
        "armored_infected",
        "enemies_corrupted",
        "enemies_parasite_headshot",
        "tougher_skin",
        "rotten_armor",
        "stimmed_minions",
        "ember",
        "toxic_gas",
        "toxic_gas_cultist_grenadier",
        "ventilation_purge",
        "ventilation_purge_with_snipers",
        "darkness",
        "darkness_hunting_grounds",
    }
    
    -- Default ARGB values for each color setting
    local default_colors = {
        increased_difficulty = {255, 255, 255, 255},
        highest_difficulty = {255, 255, 255, 255},
        bolstering_enemies = {255, 208, 136, 48},
        encroaching_garden = {255, 138, 43, 226},
        enraged = {255, 255, 54, 36},
        chaos_ritual = {255, 0, 255, 0},
        armored_infected = {255, 70, 130, 180},
        enemies_corrupted = {255, 128, 128, 0},
        enemies_parasite_headshot = {255, 255, 160, 122},
        tougher_skin = {255, 157, 169, 75},
        rotten_armor = {255, 132, 156, 99},
        stimmed_minions = {255, 255, 242, 0},
        ember = {255, 160, 82, 45},
        toxic_gas = {255, 154, 205, 50},
        toxic_gas_cultist_grenadier = {255, 154, 205, 50},
        ventilation_purge = {255, 128, 128, 128},
        ventilation_purge_with_snipers = {255, 128, 128, 128},
        darkness = {255, 20, 16, 14},
        darkness_hunting_grounds = {255, 20, 16, 14},
    }
    
    for _, setting_id in ipairs(color_setting_ids) do
        local value = mod:get(setting_id)
        
        -- If value is a string (old color name), convert it
        if type(value) == "string" then
            local color = Color[value]
            if color then
                local argb = color(255, true)
                mod:set(setting_id, {argb[1], argb[2], argb[3], argb[4]})
            else
                -- Unknown color name, use default
                mod:set(setting_id, default_colors[setting_id] or {255, 255, 255, 255})
            end
        -- If value is not a table or doesn't have 4 elements, reset it
        elseif type(value) ~= "table" or #value < 4 then
            mod:set(setting_id, default_colors[setting_id] or {255, 255, 255, 255})
        end
    end
end

migrate_color_settings()

local function get_color_string(color_value)
    -- Validate the color value
    if not color_value or type(color_value) ~= "table" or #color_value < 4 then
        return "255,255,255"  -- fallback to white
    end
    return string.format("%d,%d,%d", color_value[2], color_value[3], color_value[4])
end

-- Helper function to get the appropriate name based on toggle setting
local function get_encroaching_garden_name()
    local use_original = mod:get("revert_to_original_names")
    local color = get_color_string(mod:get("encroaching_garden"))
    
    if use_original then
        -- Use original game names
        return {
            en = "{#color(" .. color .. ")}" .. Localize("loc_havoc_encroaching_garden_name") .. "{#reset()}",
            de = "{#color(" .. color .. ")}" .. Localize("loc_havoc_encroaching_garden_name") .. "{#reset()}",
            fr = "{#color(" .. color .. ")}" .. Localize("loc_havoc_encroaching_garden_name") .. "{#reset()}",
            it = "{#color(" .. color .. ")}" .. Localize("loc_havoc_encroaching_garden_name") .. "{#reset()}",
            ko = "{#color(" .. color .. ")}" .. Localize("loc_havoc_encroaching_garden_name") .. "{#reset()}",
            es = "{#color(" .. color .. ")}" .. Localize("loc_havoc_encroaching_garden_name") .. "{#reset()}",
            ["zh-cn"] = "{#color(" .. color .. ")}" .. Localize("loc_havoc_encroaching_garden_name") .. "{#reset()}",
            ["zh-tw"] = "{#color(" .. color .. ")}" .. Localize("loc_havoc_encroaching_garden_name") .. "{#reset()}",
            ru = "{#color(" .. color .. ")}" .. Localize("loc_havoc_encroaching_garden_name") .. "{#reset()}",
            ja = "{#color(" .. color .. ")}" .. Localize("loc_havoc_encroaching_garden_name") .. "{#reset()}",
            pl = "{#color(" .. color .. ")}" .. Localize("loc_havoc_encroaching_garden_name") .. "{#reset()}",
            ["pt-br"] = "{#color(" .. color .. ")}" .. Localize("loc_havoc_encroaching_garden_name") .. "{#reset()}",
        }
    else
        -- Use custom names
        return {
            en = "{#color(" .. color .. ")}Marked Healers{#reset()}",
            de = "{#color(" .. color .. ")}Markierte Heiler{#reset()}",
            fr = "{#color(" .. color .. ")}Soigneurs Marqués{#reset()}",
            it = "{#color(" .. color .. ")}Guaritori Segnati{#reset()}",
            ko = "{#color(" .. color .. ")}표식된 치유사{#reset()}",
            es = "{#color(" .. color .. ")}Sanadores Marcados{#reset()}",
            ["zh-cn"] = "{#color(" .. color .. ")}瘟疫袭来(回血){#reset()}",
            ["zh-tw"] = "{#color(" .. color .. ")}蔓生花園(回血){#reset()}",
            ru = "{#color(" .. color .. ")}Помеченные целители{#reset()}",
            ja = "{#color(" .. color .. ")}刻印のヒーラー{#reset()}",
            pl = "{#color(" .. color .. ")}Naznaczeni Uzdrowiciele{#reset()}",
            ["pt-br"] = "{#color(" .. color .. ")}Curandeiros Marcados{#reset()}",
        }
    end
end

local function get_enraged_name()
    local use_original = mod:get("revert_to_original_names")
    local color = get_color_string(mod:get("enraged"))
    
    if use_original then
        -- Use original game names
        return {
            en = "{#color(" .. color .. ")}" .. Localize("loc_havoc_mutator_enraged_name") .. "{#reset()}",
            de = "{#color(" .. color .. ")}" .. Localize("loc_havoc_mutator_enraged_name") .. "{#reset()}",
            fr = "{#color(" .. color .. ")}" .. Localize("loc_havoc_mutator_enraged_name") .. "{#reset()}",
            it = "{#color(" .. color .. ")}" .. Localize("loc_havoc_mutator_enraged_name") .. "{#reset()}",
            ko = "{#color(" .. color .. ")}" .. Localize("loc_havoc_mutator_enraged_name") .. "{#reset()}",
            es = "{#color(" .. color .. ")}" .. Localize("loc_havoc_mutator_enraged_name") .. "{#reset()}",
            ["zh-cn"] = "{#color(" .. color .. ")}" .. Localize("loc_havoc_mutator_enraged_name") .. "{#reset()}",
            ["zh-tw"] = "{#color(" .. color .. ")}" .. Localize("loc_havoc_mutator_enraged_name") .. "{#reset()}",
            ru = "{#color(" .. color .. ")}" .. Localize("loc_havoc_mutator_enraged_name") .. "{#reset()}",
            ja = "{#color(" .. color .. ")}" .. Localize("loc_havoc_mutator_enraged_name") .. "{#reset()}",
            pl = "{#color(" .. color .. ")}" .. Localize("loc_havoc_mutator_enraged_name") .. "{#reset()}",
            ["pt-br"] = "{#color(" .. color .. ")}" .. Localize("loc_havoc_mutator_enraged_name") .. "{#reset()}",
        }
    else
        -- Use custom names
        return {
            en = "{#color(" .. color .. ")}Enraging Elites{#reset()}",
            de = "{#color(" .. color .. ")}Wütende Eliten{#reset()}",
            fr = "{#color(" .. color .. ")}Élites Enragées{#reset()}",
            it = "{#color(" .. color .. ")}Élite Furente{#reset()}",
            ko = "{#color(" .. color .. ")}분노한 정예병{#reset()}",
            es = "{#color(" .. color .. ")}Élites Enfurecidos{#reset()}",
            ["zh-cn"] = "{#color(" .. color .. ")}最后的钟声(狂暴){#reset()}",
            ["zh-tw"] = "{#color(" .. color .. ")}背水一戰(狂暴){#reset()}",
            ru = "{#color(" .. color .. ")}Разъярённая элита{#reset()}",
            ja = "{#color(" .. color .. ")}怒れる精鋭{#reset()}",
            pl = "{#color(" .. color .. ")}Wściekła Elita{#reset()}",
            ["pt-br"] = "{#color(" .. color .. ")}Elites Enfurecidos{#reset()}",
        }
    end
end

local function update_dynamic_localizations()
    mod:add_global_localize_strings({
        loc_havoc_encroaching_garden_name = get_encroaching_garden_name(),
        loc_havoc_mutator_enraged_name = get_enraged_name(),
    })
end

function mod.on_setting_changed(setting_id, value)
	if setting_id == "revert_to_original_names" then
		mod:notify(mod:localize("revert_to_original_names_notification"))
	end
end

update_dynamic_localizations()

-- All other localizations
mod:add_global_localize_strings({
    loc_havoc_increased_difficulty_name = {
        en = "{#color(" .. get_color_string(mod:get("increased_difficulty")) .. ")}" .. Localize("loc_havoc_increased_difficulty_name") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("increased_difficulty")) .. ")}" .. Localize("loc_havoc_increased_difficulty_name") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("increased_difficulty")) .. ")}" .. Localize("loc_havoc_increased_difficulty_name") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("increased_difficulty")) .. ")}" .. Localize("loc_havoc_increased_difficulty_name") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("increased_difficulty")) .. ")}" .. Localize("loc_havoc_increased_difficulty_name") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("increased_difficulty")) .. ")}" .. Localize("loc_havoc_increased_difficulty_name") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("increased_difficulty")) .. ")}" .. Localize("loc_havoc_increased_difficulty_name") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("increased_difficulty")) .. ")}" .. Localize("loc_havoc_increased_difficulty_name") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("increased_difficulty")) .. ")}" .. Localize("loc_havoc_increased_difficulty_name") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("increased_difficulty")) .. ")}" .. Localize("loc_havoc_increased_difficulty_name") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("increased_difficulty")) .. ")}" .. Localize("loc_havoc_increased_difficulty_name") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("increased_difficulty")) .. ")}" .. Localize("loc_havoc_increased_difficulty_name") .. "{#reset()}",
    },
    loc_havoc_highest_difficulty_name = {
        en = "{#color(" .. get_color_string(mod:get("highest_difficulty")) .. ")}" .. Localize("loc_havoc_highest_difficulty_name") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("highest_difficulty")) .. ")}" .. Localize("loc_havoc_highest_difficulty_name") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("highest_difficulty")) .. ")}" .. Localize("loc_havoc_highest_difficulty_name") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("highest_difficulty")) .. ")}" .. Localize("loc_havoc_highest_difficulty_name") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("highest_difficulty")) .. ")}" .. Localize("loc_havoc_highest_difficulty_name") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("highest_difficulty")) .. ")}" .. Localize("loc_havoc_highest_difficulty_name") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("highest_difficulty")) .. ")}" .. Localize("loc_havoc_highest_difficulty_name") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("highest_difficulty")) .. ")}" .. Localize("loc_havoc_highest_difficulty_name") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("highest_difficulty")) .. ")}" .. Localize("loc_havoc_highest_difficulty_name") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("highest_difficulty")) .. ")}" .. Localize("loc_havoc_highest_difficulty_name") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("highest_difficulty")) .. ")}" .. Localize("loc_havoc_highest_difficulty_name") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("highest_difficulty")) .. ")}" .. Localize("loc_havoc_highest_difficulty_name") .. "{#reset()}",
    },
    loc_havoc_bolstering_enemies_name = {
        en = "{#color(" .. get_color_string(mod:get("bolstering_enemies")) .. ")}" .. Localize("loc_havoc_bolstering_enemies_name") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("bolstering_enemies")) .. ")}" .. Localize("loc_havoc_bolstering_enemies_name") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("bolstering_enemies")) .. ")}" .. Localize("loc_havoc_bolstering_enemies_name") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("bolstering_enemies")) .. ")}" .. Localize("loc_havoc_bolstering_enemies_name") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("bolstering_enemies")) .. ")}" .. Localize("loc_havoc_bolstering_enemies_name") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("bolstering_enemies")) .. ")}" .. Localize("loc_havoc_bolstering_enemies_name") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("bolstering_enemies")) .. ")}" .. Localize("loc_havoc_bolstering_enemies_name") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("bolstering_enemies")) .. ")}" .. Localize("loc_havoc_bolstering_enemies_name") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("bolstering_enemies")) .. ")}" .. Localize("loc_havoc_bolstering_enemies_name") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("bolstering_enemies")) .. ")}" .. Localize("loc_havoc_bolstering_enemies_name") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("bolstering_enemies")) .. ")}" .. Localize("loc_havoc_bolstering_enemies_name") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("bolstering_enemies")) .. ")}" .. Localize("loc_havoc_bolstering_enemies_name") .. "{#reset()}",
    },
    loc_havoc_chaos_ritual_name = {
        en = "{#color(" .. get_color_string(mod:get("chaos_ritual")) .. ")}" .. Localize("loc_havoc_chaos_ritual_name") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("chaos_ritual")) .. ")}" .. Localize("loc_havoc_chaos_ritual_name") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("chaos_ritual")) .. ")}" .. Localize("loc_havoc_chaos_ritual_name") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("chaos_ritual")) .. ")}" .. Localize("loc_havoc_chaos_ritual_name") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("chaos_ritual")) .. ")}" .. Localize("loc_havoc_chaos_ritual_name") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("chaos_ritual")) .. ")}" .. Localize("loc_havoc_chaos_ritual_name") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("chaos_ritual")) .. ")}" .. Localize("loc_havoc_chaos_ritual_name") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("chaos_ritual")) .. ")}" .. Localize("loc_havoc_chaos_ritual_name") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("chaos_ritual")) .. ")}" .. Localize("loc_havoc_chaos_ritual_name") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("chaos_ritual")) .. ")}" .. Localize("loc_havoc_chaos_ritual_name") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("chaos_ritual")) .. ")}" .. Localize("loc_havoc_chaos_ritual_name") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("chaos_ritual")) .. ")}" .. Localize("loc_havoc_chaos_ritual_name") .. "{#reset()}",
    },
    loc_havoc_armored_infected_name = {
        en = "{#color(" .. get_color_string(mod:get("armored_infected")) .. ")}" .. Localize("loc_havoc_armored_infected_name") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("armored_infected")) .. ")}" .. Localize("loc_havoc_armored_infected_name") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("armored_infected")) .. ")}" .. Localize("loc_havoc_armored_infected_name") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("armored_infected")) .. ")}" .. Localize("loc_havoc_armored_infected_name") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("armored_infected")) .. ")}" .. Localize("loc_havoc_armored_infected_name") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("armored_infected")) .. ")}" .. Localize("loc_havoc_armored_infected_name") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("armored_infected")) .. ")}" .. Localize("loc_havoc_armored_infected_name") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("armored_infected")) .. ")}" .. Localize("loc_havoc_armored_infected_name") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("armored_infected")) .. ")}" .. Localize("loc_havoc_armored_infected_name") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("armored_infected")) .. ")}" .. Localize("loc_havoc_armored_infected_name") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("armored_infected")) .. ")}" .. Localize("loc_havoc_armored_infected_name") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("armored_infected")) .. ")}" .. Localize("loc_havoc_armored_infected_name") .. "{#reset()}",
    },
    loc_havoc_enemies_corrupted_name = {
        en = "{#color(" .. get_color_string(mod:get("enemies_corrupted")) .. ")}" .. Localize("loc_havoc_enemies_corrupted_name") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("enemies_corrupted")) .. ")}" .. Localize("loc_havoc_enemies_corrupted_name") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("enemies_corrupted")) .. ")}" .. Localize("loc_havoc_enemies_corrupted_name") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("enemies_corrupted")) .. ")}" .. Localize("loc_havoc_enemies_corrupted_name") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("enemies_corrupted")) .. ")}" .. Localize("loc_havoc_enemies_corrupted_name") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("enemies_corrupted")) .. ")}" .. Localize("loc_havoc_enemies_corrupted_name") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("enemies_corrupted")) .. ")}" .. Localize("loc_havoc_enemies_corrupted_name") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("enemies_corrupted")) .. ")}" .. Localize("loc_havoc_enemies_corrupted_name") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("enemies_corrupted")) .. ")}" .. Localize("loc_havoc_enemies_corrupted_name") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("enemies_corrupted")) .. ")}" .. Localize("loc_havoc_enemies_corrupted_name") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("enemies_corrupted")) .. ")}" .. Localize("loc_havoc_enemies_corrupted_name") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("enemies_corrupted")) .. ")}" .. Localize("loc_havoc_enemies_corrupted_name") .. "{#reset()}",
    },
    loc_havoc_enemies_parasite_headshot_name = {
        en = "{#color(" .. get_color_string(mod:get("enemies_parasite_headshot")) .. ")}" .. Localize("loc_havoc_enemies_parasite_headshot_name") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("enemies_parasite_headshot")) .. ")}" .. Localize("loc_havoc_enemies_parasite_headshot_name") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("enemies_parasite_headshot")) .. ")}" .. Localize("loc_havoc_enemies_parasite_headshot_name") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("enemies_parasite_headshot")) .. ")}" .. Localize("loc_havoc_enemies_parasite_headshot_name") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("enemies_parasite_headshot")) .. ")}" .. Localize("loc_havoc_enemies_parasite_headshot_name") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("enemies_parasite_headshot")) .. ")}" .. Localize("loc_havoc_enemies_parasite_headshot_name") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("enemies_parasite_headshot")) .. ")}" .. Localize("loc_havoc_enemies_parasite_headshot_name") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("enemies_parasite_headshot")) .. ")}" .. Localize("loc_havoc_enemies_parasite_headshot_name") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("enemies_parasite_headshot")) .. ")}" .. Localize("loc_havoc_enemies_parasite_headshot_name") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("enemies_parasite_headshot")) .. ")}" .. Localize("loc_havoc_enemies_parasite_headshot_name") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("enemies_parasite_headshot")) .. ")}" .. Localize("loc_havoc_enemies_parasite_headshot_name") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("enemies_parasite_headshot")) .. ")}" .. Localize("loc_havoc_enemies_parasite_headshot_name") .. "{#reset()}",
    },
    loc_havoc_tougher_skin_name = {
        en = "{#color(" .. get_color_string(mod:get("tougher_skin")) .. ")}" .. Localize("loc_havoc_tougher_skin_name") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("tougher_skin")) .. ")}" .. Localize("loc_havoc_tougher_skin_name") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("tougher_skin")) .. ")}" .. Localize("loc_havoc_tougher_skin_name") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("tougher_skin")) .. ")}" .. Localize("loc_havoc_tougher_skin_name") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("tougher_skin")) .. ")}" .. Localize("loc_havoc_tougher_skin_name") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("tougher_skin")) .. ")}" .. Localize("loc_havoc_tougher_skin_name") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("tougher_skin")) .. ")}" .. Localize("loc_havoc_tougher_skin_name") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("tougher_skin")) .. ")}" .. Localize("loc_havoc_tougher_skin_name") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("tougher_skin")) .. ")}" .. Localize("loc_havoc_tougher_skin_name") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("tougher_skin")) .. ")}" .. Localize("loc_havoc_tougher_skin_name") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("tougher_skin")) .. ")}" .. Localize("loc_havoc_tougher_skin_name") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("tougher_skin")) .. ")}" .. Localize("loc_havoc_tougher_skin_name") .. "{#reset()}",
    },
    loc_havoc_rotten_armor_name = {
        en = "{#color(" .. get_color_string(mod:get("rotten_armor")) .. ")}" .. Localize("loc_havoc_rotten_armor_name") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("rotten_armor")) .. ")}" .. Localize("loc_havoc_rotten_armor_name") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("rotten_armor")) .. ")}" .. Localize("loc_havoc_rotten_armor_name") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("rotten_armor")) .. ")}" .. Localize("loc_havoc_rotten_armor_name") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("rotten_armor")) .. ")}" .. Localize("loc_havoc_rotten_armor_name") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("rotten_armor")) .. ")}" .. Localize("loc_havoc_rotten_armor_name") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("rotten_armor")) .. ")}" .. Localize("loc_havoc_rotten_armor_name") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("rotten_armor")) .. ")}" .. Localize("loc_havoc_rotten_armor_name") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("rotten_armor")) .. ")}" .. Localize("loc_havoc_rotten_armor_name") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("rotten_armor")) .. ")}" .. Localize("loc_havoc_rotten_armor_name") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("rotten_armor")) .. ")}" .. Localize("loc_havoc_rotten_armor_name") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("rotten_armor")) .. ")}" .. Localize("loc_havoc_rotten_armor_name") .. "{#reset()}",
    },
    loc_havoc_stimmed_minions_name = {
        en = "{#color(" .. get_color_string(mod:get("stimmed_minions")) .. ")}" .. Localize("loc_havoc_stimmed_minions_name") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("stimmed_minions")) .. ")}" .. Localize("loc_havoc_stimmed_minions_name") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("stimmed_minions")) .. ")}" .. Localize("loc_havoc_stimmed_minions_name") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("stimmed_minions")) .. ")}" .. Localize("loc_havoc_stimmed_minions_name") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("stimmed_minions")) .. ")}" .. Localize("loc_havoc_stimmed_minions_name") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("stimmed_minions")) .. ")}" .. Localize("loc_havoc_stimmed_minions_name") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("stimmed_minions")) .. ")}" .. Localize("loc_havoc_stimmed_minions_name") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("stimmed_minions")) .. ")}" .. Localize("loc_havoc_stimmed_minions_name") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("stimmed_minions")) .. ")}" .. Localize("loc_havoc_stimmed_minions_name") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("stimmed_minions")) .. ")}" .. Localize("loc_havoc_stimmed_minions_name") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("stimmed_minions")) .. ")}" .. Localize("loc_havoc_stimmed_minions_name") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("stimmed_minions")) .. ")}" .. Localize("loc_havoc_stimmed_minions_name") .. "{#reset()}",
    },
    loc_circumstance_ember_title = {
        en = "{#color(" .. get_color_string(mod:get("ember")) .. ")}" .. Localize("loc_circumstance_ember_title") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("ember")) .. ")}" .. Localize("loc_circumstance_ember_title") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("ember")) .. ")}" .. Localize("loc_circumstance_ember_title") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("ember")) .. ")}" .. Localize("loc_circumstance_ember_title") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("ember")) .. ")}" .. Localize("loc_circumstance_ember_title") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("ember")) .. ")}" .. Localize("loc_circumstance_ember_title") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("ember")) .. ")}" .. Localize("loc_circumstance_ember_title") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("ember")) .. ")}" .. Localize("loc_circumstance_ember_title") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("ember")) .. ")}" .. Localize("loc_circumstance_ember_title") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("ember")) .. ")}" .. Localize("loc_circumstance_ember_title") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("ember")) .. ")}" .. Localize("loc_circumstance_ember_title") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("ember")) .. ")}" .. Localize("loc_circumstance_ember_title") .. "{#reset()}",
    },
    loc_circumstance_toxic_gas_title = {
        en = "{#color(" .. get_color_string(mod:get("toxic_gas")) .. ")}" .. Localize("loc_circumstance_toxic_gas_title") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("toxic_gas")) .. ")}" .. Localize("loc_circumstance_toxic_gas_title") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("toxic_gas")) .. ")}" .. Localize("loc_circumstance_toxic_gas_title") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("toxic_gas")) .. ")}" .. Localize("loc_circumstance_toxic_gas_title") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("toxic_gas")) .. ")}" .. Localize("loc_circumstance_toxic_gas_title") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("toxic_gas")) .. ")}" .. Localize("loc_circumstance_toxic_gas_title") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("toxic_gas")) .. ")}" .. Localize("loc_circumstance_toxic_gas_title") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("toxic_gas")) .. ")}" .. Localize("loc_circumstance_toxic_gas_title") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("toxic_gas")) .. ")}" .. Localize("loc_circumstance_toxic_gas_title") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("toxic_gas")) .. ")}" .. Localize("loc_circumstance_toxic_gas_title") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("toxic_gas")) .. ")}" .. Localize("loc_circumstance_toxic_gas_title") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("toxic_gas")) .. ")}" .. Localize("loc_circumstance_toxic_gas_title") .. "{#reset()}",
    },
    loc_circumstance_toxic_gas_cultist_grenadier_title = {
        en = "{#color(" .. get_color_string(mod:get("toxic_gas_cultist_grenadier")) .. ")}" .. Localize("loc_circumstance_toxic_gas_cultist_grenadier_title") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("toxic_gas_cultist_grenadier")) .. ")}" .. Localize("loc_circumstance_toxic_gas_cultist_grenadier_title") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("toxic_gas_cultist_grenadier")) .. ")}" .. Localize("loc_circumstance_toxic_gas_cultist_grenadier_title") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("toxic_gas_cultist_grenadier")) .. ")}" .. Localize("loc_circumstance_toxic_gas_cultist_grenadier_title") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("toxic_gas_cultist_grenadier")) .. ")}" .. Localize("loc_circumstance_toxic_gas_cultist_grenadier_title") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("toxic_gas_cultist_grenadier")) .. ")}" .. Localize("loc_circumstance_toxic_gas_cultist_grenadier_title") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("toxic_gas_cultist_grenadier")) .. ")}" .. Localize("loc_circumstance_toxic_gas_cultist_grenadier_title") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("toxic_gas_cultist_grenadier")) .. ")}" .. Localize("loc_circumstance_toxic_gas_cultist_grenadier_title") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("toxic_gas_cultist_grenadier")) .. ")}" .. Localize("loc_circumstance_toxic_gas_cultist_grenadier_title") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("toxic_gas_cultist_grenadier")) .. ")}" .. Localize("loc_circumstance_toxic_gas_cultist_grenadier_title") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("toxic_gas_cultist_grenadier")) .. ")}" .. Localize("loc_circumstance_toxic_gas_cultist_grenadier_title") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("toxic_gas_cultist_grenadier")) .. ")}" .. Localize("loc_circumstance_toxic_gas_cultist_grenadier_title") .. "{#reset()}",
    },
    loc_circumstance_ventilation_purge_title = {
        en = "{#color(" .. get_color_string(mod:get("ventilation_purge")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_title") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("ventilation_purge")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_title") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("ventilation_purge")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_title") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("ventilation_purge")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_title") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("ventilation_purge")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_title") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("ventilation_purge")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_title") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("ventilation_purge")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_title") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("ventilation_purge")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_title") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("ventilation_purge")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_title") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("ventilation_purge")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_title") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("ventilation_purge")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_title") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("ventilation_purge")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_title") .. "{#reset()}",
    },
    loc_circumstance_ventilation_purge_with_snipers_title = {
        en = "{#color(" .. get_color_string(mod:get("ventilation_purge_with_snipers")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_with_snipers_title") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("ventilation_purge_with_snipers")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_with_snipers_title") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("ventilation_purge_with_snipers")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_with_snipers_title") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("ventilation_purge_with_snipers")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_with_snipers_title") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("ventilation_purge_with_snipers")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_with_snipers_title") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("ventilation_purge_with_snipers")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_with_snipers_title") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("ventilation_purge_with_snipers")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_with_snipers_title") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("ventilation_purge_with_snipers")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_with_snipers_title") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("ventilation_purge_with_snipers")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_with_snipers_title") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("ventilation_purge_with_snipers")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_with_snipers_title") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("ventilation_purge_with_snipers")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_with_snipers_title") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("ventilation_purge_with_snipers")) .. ")}" .. Localize("loc_circumstance_ventilation_purge_with_snipers_title") .. "{#reset()}",
    },
    loc_circumstance_darkness_title = {
        en = "{#color(" .. get_color_string(mod:get("darkness")) .. ")}" .. Localize("loc_circumstance_darkness_title") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("darkness")) .. ")}" .. Localize("loc_circumstance_darkness_title") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("darkness")) .. ")}" .. Localize("loc_circumstance_darkness_title") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("darkness")) .. ")}" .. Localize("loc_circumstance_darkness_title") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("darkness")) .. ")}" .. Localize("loc_circumstance_darkness_title") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("darkness")) .. ")}" .. Localize("loc_circumstance_darkness_title") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("darkness")) .. ")}" .. Localize("loc_circumstance_darkness_title") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("darkness")) .. ")}" .. Localize("loc_circumstance_darkness_title") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("darkness")) .. ")}" .. Localize("loc_circumstance_darkness_title") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("darkness")) .. ")}" .. Localize("loc_circumstance_darkness_title") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("darkness")) .. ")}" .. Localize("loc_circumstance_darkness_title") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("darkness")) .. ")}" .. Localize("loc_circumstance_darkness_title") .. "{#reset()}",
    },
    loc_circumstance_darkness_hunting_grounds_title = {
        en = "{#color(" .. get_color_string(mod:get("darkness_hunting_grounds")) .. ")}" .. Localize("loc_circumstance_darkness_hunting_grounds_title") .. "{#reset()}",
        de = "{#color(" .. get_color_string(mod:get("darkness_hunting_grounds")) .. ")}" .. Localize("loc_circumstance_darkness_hunting_grounds_title") .. "{#reset()}",
        fr = "{#color(" .. get_color_string(mod:get("darkness_hunting_grounds")) .. ")}" .. Localize("loc_circumstance_darkness_hunting_grounds_title") .. "{#reset()}",
        it = "{#color(" .. get_color_string(mod:get("darkness_hunting_grounds")) .. ")}" .. Localize("loc_circumstance_darkness_hunting_grounds_title") .. "{#reset()}",
        ko = "{#color(" .. get_color_string(mod:get("darkness_hunting_grounds")) .. ")}" .. Localize("loc_circumstance_darkness_hunting_grounds_title") .. "{#reset()}",
        es = "{#color(" .. get_color_string(mod:get("darkness_hunting_grounds")) .. ")}" .. Localize("loc_circumstance_darkness_hunting_grounds_title") .. "{#reset()}",
        ["zh-cn"] = "{#color(" .. get_color_string(mod:get("darkness_hunting_grounds")) .. ")}" .. Localize("loc_circumstance_darkness_hunting_grounds_title") .. "{#reset()}",
        ["zh-tw"] = "{#color(" .. get_color_string(mod:get("darkness_hunting_grounds")) .. ")}" .. Localize("loc_circumstance_darkness_hunting_grounds_title") .. "{#reset()}",
        ru = "{#color(" .. get_color_string(mod:get("darkness_hunting_grounds")) .. ")}" .. Localize("loc_circumstance_darkness_hunting_grounds_title") .. "{#reset()}",
        ja = "{#color(" .. get_color_string(mod:get("darkness_hunting_grounds")) .. ")}" .. Localize("loc_circumstance_darkness_hunting_grounds_title") .. "{#reset()}",
        pl = "{#color(" .. get_color_string(mod:get("darkness_hunting_grounds")) .. ")}" .. Localize("loc_circumstance_darkness_hunting_grounds_title") .. "{#reset()}",
        ["pt-br"] = "{#color(" .. get_color_string(mod:get("darkness_hunting_grounds")) .. ")}" .. Localize("loc_circumstance_darkness_hunting_grounds_title") .. "{#reset()}",
    },
})