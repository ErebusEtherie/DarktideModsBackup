---@alias class_id "zealot" | "veteran" | "psyker" | "ogryn" | "hive_scum" | "arbitrator" | "skitarii"

---@alias archetype_name_to_class_id_map table<string, class_id>
---@type archetype_name_to_class_id_map
local archetype_name_to_class_id_map = {
    loc_class_zealot_name = "zealot",
    loc_class_veteran_name = "veteran",
    loc_class_psyker_name = "psyker",
    loc_class_ogryn_name = "ogryn",
    loc_class_broker_name = "hive_scum",
    loc_class_adamant_name = "arbitrator",
    loc_class_cryptic_name = "skitarii",
}

---@alias class_id_to_loc_id_map table<class_id, string>
---@type class_id_to_loc_id_map
local class_id_to_loc_id_map = {
    zealot = "zealot_loc",
    veteran = "veteran_loc",
    psyker = "psyker_loc",
    ogryn = "ogryn_loc",
    hive_scum = "hive_scum_loc",
    arbitrator = "arbitrator_loc",
    skitarii = "skitarii_loc",
}

---@alias primary_talent_sequence table<integer, { talent_keys: string[], loc_id: string }>

--- Ordered list: first matching talent in profile.talents wins. Each entry lists game talent keys that map to one display name.
---@type primary_talent_sequence
local primary_talent_sequence = {
    -- ZEALOT
    { talent_keys = { "zealot_attack_speed_post_ability" },                             loc_id = "talent_zealot_dash" },
    { talent_keys = { "zealot_bolstering_prayer" },                                     loc_id = "talent_zealot_chorus" },
    { talent_keys = { "zealot_stealth" },                                               loc_id = "talent_zealot_stealth" },
    -- VETERAN
    { talent_keys = { "veteran_combat_ability_elite_and_special_outlines" },            loc_id = "talent_veteran_outline" },
    { talent_keys = { "veteran_combat_ability_stagger_nearby_enemies" },                loc_id = "talent_veteran_voc" },
    { talent_keys = { "veteran_invisibility_on_combat_ability" },                       loc_id = "talent_veteran_stealth" },
    -- PSYKER
    { talent_keys = { "psyker_combat_ability_force_field" },                            loc_id = "talent_psyker_shield" },
    { talent_keys = { "psyker_shout_vent_warp_charge" },                                loc_id = "talent_psyker_vent_shout" },
    { talent_keys = { "psyker_combat_ability_stance" },                                 loc_id = "talent_psyker_scrier" },
    -- OGRYN
    { talent_keys = { "ogryn_taunt_shout" },                                            loc_id = "talent_ogryn_taunt" },
    { talent_keys = { "ogryn_longer_charge" },                                          loc_id = "talent_ogryn_charge" },
    { talent_keys = { "ogryn_special_ammo" },                                           loc_id = "talent_ogryn_barrage" },
    -- ARBITRATOR
    { talent_keys = { "adamant_stance" },                                               loc_id = "talent_arbitrator_castigator" },
    { talent_keys = { "adamant_charge" },                                               loc_id = "talent_arbitrator_bash" },
    { talent_keys = { "adamant_area_buff_drone", "adamant_area_buff_drone_improved" },  loc_id = "talent_arbitrator_nuncio_aquila" },
    -- HIVE SCUM
    { talent_keys = { "broker_ability_punk_rage" },                                     loc_id = "talent_hive_scum_rage" },
    { talent_keys = { "broker_ability_focus" },                                         loc_id = "talent_hive_scum_desperado" },
    { talent_keys = { "broker_ability_stimm_field" },                                   loc_id = "talent_hive_scum_stimm_field" },
    -- SKITARII
    { talent_keys = { "cryptic_chordclaw" },                                            loc_id = "talent_cryptic_chordclaw" },
    { talent_keys = { "cryptic_discharge" },                                            loc_id = "talent_cryptic_discharge" },
    { talent_keys = { "cryptic_precision_stance" },                                     loc_id = "talent_cryptic_precision_stance" },
}

---@alias use_class_r {
---format_class_name: format_class_name,
---format_class_talent_name: format_class_talent_name,
---get_class_id_from_archetype: get_class_id_from_archetype,
---get_localised_class_name_from_archetype: get_localised_class_name_from_archetype,
---get_localised_primary_talent_from_profile: get_localised_primary_talent_from_profile,
---get_primary_talent_loc_id: get_primary_talent_loc_id,
---get_class_color_id: get_class_color_id }

---@alias use_class fun(): use_class_r
---@type use_class
local function use_class()
    ---@alias get_class_id_from_archetype fun(archetype: table): string|nil
    ---@type get_class_id_from_archetype
    local function get_class_id_from_archetype(archetype)
        return archetype and archetype.archetype_name and archetype_name_to_class_id_map[archetype.archetype_name] or nil
    end

    ---@alias get_primary_talent_loc_id fun(talents: table): string|nil
    ---@type get_primary_talent_loc_id
    local function get_primary_talent_loc_id(talents)
        if not talents then return talents end

        for _, entry in ipairs(primary_talent_sequence) do
            for _, key in ipairs(entry.talent_keys) do
                if talents[key] ~= nil then
                    return entry.loc_id
                end
            end
        end
        return nil
    end

    ---@alias format_class_name fun(mod: dmf_mod, class_name: string): string
    ---@type format_class_name
    local format_class_name = function(mod, class_name)
        if not class_name then class_name = "" end

        local use_string = mod:get_module("use_string")()
        ---@cast use_string use_string_r

        local prefix = mod:get("select_class_name_prefix") or ""
        local suffix = mod:get("select_class_name_suffix") or ""

        return prefix .. use_string.apply_case(mod:get("select_class_name_case"), class_name) .. suffix
    end

    ---@alias format_class_talent_name fun(mod: dmf_mod, talent: string): string
    ---@type format_class_talent_name
    local format_class_talent_name = function(mod, talent)
        if not talent then talent = "" end

        local use_string = mod:get_module("use_string")()
        ---@cast use_string use_string_r

        local prefix = mod:get("select_talent_name_prefix") or ""
        local suffix = mod:get("select_talent_name_suffix") or ""

        return prefix .. use_string.apply_case(mod:get("select_talent_name_case"), talent) .. suffix
    end

    ---@alias get_class_color_id fun(mod: dmf_mod, class_id: string|nil): string
    ---@type get_class_color_id
    local function get_class_color_id(mod, class_id)
        return (class_id and class_id ~= "" and mod:get("select_class_color_" .. class_id)) or "default"
    end

    ---@alias get_localised_class_name_from_archetype fun(mod: dmf_mod, archetype: table): string|nil
    ---@type get_localised_class_name_from_archetype
    local function get_localised_class_name_from_archetype(mod, archetype)
        local class_id = get_class_id_from_archetype(archetype)

        if not class_id then return archetype.archetype_name end

        local class_name_loc_id = class_id_to_loc_id_map[class_id]

        -- archetype.name might be localised properly in other languages but in English there are some weird
        -- names like "broker" for Hive Scum or "adamant" for Arbitrator

        local localised_class_name = class_name_loc_id and mod:localize(class_name_loc_id) or archetype.name

        return localised_class_name
    end

    ---@alias get_localised_primary_talent_from_profile fun(mod: dmf_mod, profile: table): string|nil
    ---@type get_localised_primary_talent_from_profile
    local function get_localised_primary_talent_from_profile(mod, profile)
        local talent_loc_id = profile and profile.talents and get_primary_talent_loc_id(profile.talents) or nil

        return talent_loc_id and mod:localize(talent_loc_id) or nil
    end

    return {
        get_localised_class_name_from_archetype = get_localised_class_name_from_archetype,
        get_localised_primary_talent_from_profile = get_localised_primary_talent_from_profile,
        get_class_id_from_archetype = get_class_id_from_archetype,
        get_primary_talent_loc_id = get_primary_talent_loc_id,
        get_class_color_id = get_class_color_id,
        format_class_name = format_class_name,
        format_class_talent_name = format_class_talent_name,
    }
end

return use_class
