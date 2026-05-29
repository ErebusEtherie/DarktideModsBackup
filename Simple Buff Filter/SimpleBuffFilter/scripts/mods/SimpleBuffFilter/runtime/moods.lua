-- File: scripts/mods/SimpleBuffFilter/runtime/moods.lua
local mod = get_mod("SimpleBuffFilter"); if not mod then return end

mod.tbf_moods = mod.tbf_moods or {}

local BuffTemplates = require("scripts/settings/buff/buff_templates")
local MoodSettings = require("scripts/settings/camera/mood/mood_settings")

local moods = MoodSettings.moods or {}

local Localize = Localize
local HARDCODED_MOOD_LOCS = {
    -- danger
    last_wound                                                              = "loc_veteran_male_a__com_wheel_vo_need_health_01",
    critical_health                                                         = "loc_veteran_male_a__com_wheel_vo_need_health_01",
    knocked_down                                                            = "loc_veteran_male_a__knocked_down_1_01",
    toughness_absorbed                                                      = "loc_tg_toughness_damage_objective_1", -- "Take Toughness Damage"
    toughness_broken                                                        = "loc_tg_toughness_damage_objective_2", -- "Have Toughness Broken"
    no_toughness                                                            = "loc_tg_toughness_damage_objective_2", -- "Have Toughness Broken"
    damage_taken                                                            = "loc_tg_toughness_damage_objective_3", -- "Take Health Damage"
    corruption_taken                                                        = "loc_corruption_tutorial",
    suppression_ongoing                                                     = "loc_ranged_suppression",
    suppression_low                                                         = "loc_ranged_suppression",
    suppression_high                                                        = "loc_ranged_suppression",
    expeditions_death_imminent                                              = "loc_game_mode_expedition_timer_popup_warning_desc_final", -- "Rad-Stimm effectiveness nullified.  Extreme danger of Corruption."
    ["content/fx/particles/screenspace/screen_blood_splatter"]              = "loc_blood_decals_enabled",
    ["content/fx/particles/screenspace/screen_stunned_heavy"]               = "loc_stagger",
    ["content/fx/particles/screenspace/screen_stunned_light"]               = "loc_stagger",
    ["content/fx/particles/screenspace/player_screen_twins_gas"]            = "loc_circumstance_toxic_gas_title",
    ["content/fx/particles/screenspace/screen_player_electrified"]          = "loc_weapon_keyword_shock_weapon",
    ["content/fx/particles/screenspace/screen_bon_vomit_loop"]              = "loc_breed_display_name_chaos_beast_of_nurgle",
    ["content/fx/particles/screenspace/screen_plasma_rifle_warning"]        = "loc_weapon_family_plasmagun_p1_m1",

    -- misc
    sprinting                                                               = "loc_player_buff_sprint_with_stamina_buff",
    sprinting_overtime                                                      = "loc_player_buff_sprint_with_stamina_buff",
    syringe_ability                                                         = "loc_broker_stimm_builder_view_display_name",
    story_echo                                                              = "loc_interaction_story_echo_zola", -- mortis memory echoes
    ["content/fx/particles/screenspace/screen_coherence_enter"]             = "loc_player_buff_coherency_toughness_regen",
    ["content/fx/particles/screenspace/player_heal_tick"]                   = "loc_pickup_pocketable_medical_crate_01",
    ["content/fx/particles/screenspace/screen_gardens_embrace"]             = "loc_havoc_encroaching_garden_name",

    -- veteran
    veteran_stealth                                                         = "loc_talent_veteran_invisibility_on_combat_ability",
    ["content/fx/particles/screenspace/screen_veteran_focus_target"]        = "loc_talent_veteran_improved_tag",

    -- zealot
    zealot_combat_ability_dash                                              = "loc_talent_zealot_2_combat",
    ["content/fx/particles/screenspace/screen_buff_bolstering_prayer_proc"] = "loc_talent_zealot_bolstering_prayer",

    -- psyker
    warped                                                                  = "loc_settings_menu_peril_effect",
    warped_low_to_high                                                      = Localize("loc_settings_menu_peril_effect") ..
        " (" .. Localize("loc_settings_menu_low") .. ")",
    warped_high_to_critical                                                 = Localize("loc_settings_menu_peril_effect") ..
        " (" .. Localize("loc_settings_menu_medium") .. ")",
    warped_critical                                                         = Localize("loc_settings_menu_peril_effect") ..
        " (" .. Localize("loc_settings_menu_high") .. ")",
    psyker_force_field_sphere                                               = "loc_talent_psyker_force_field_dome",
    ["content/fx/particles/screenspace/screen_biomancer_maxsouls"]          = "loc_talent_psyker_souls", -- warp siphon
    ["content/fx/particles/screenspace/screen_biomancer_souls"]             = "loc_talent_psyker_souls", -- warp siphon

    -- ogryn
    ogryn_combat_ability_charge                                             = "loc_ability_ogryn_charge",
    ogryn_combat_ability_shout                                              = "loc_ability_ogryn_taunt_shout",
    ogryn_combat_ability_stance                                             = "loc_talent_ogryn_combat_ability_special_ammo", -- PBB
}

local SCREEN_EFFECT_PATH_TO_MOODS = {}

local function _append_unique(list, value)
    for i = 1, #list do
        if list[i] == value then
            return
        end
    end

    list[#list + 1] = value
end

local function _index_screen_effect_path(screen_effect_path, mood_type)
    if type(screen_effect_path) ~= "string" or screen_effect_path == "" then
        return
    end

    local list = SCREEN_EFFECT_PATH_TO_MOODS[screen_effect_path]

    if not list then
        list = {}
        SCREEN_EFFECT_PATH_TO_MOODS[screen_effect_path] = list
    end

    _append_unique(list, mood_type)
end

for mood_type, mood in pairs(moods) do
    local particle_effects_on_enter = mood.particle_effects_on_enter
    local particle_effects_looping = mood.particle_effects_looping
    local particle_effects_on_exit = mood.particle_effects_on_exit

    if particle_effects_on_enter then
        for i = 1, #particle_effects_on_enter do
            _index_screen_effect_path(particle_effects_on_enter[i], mood_type)
        end
    end

    if particle_effects_looping then
        for i = 1, #particle_effects_looping do
            _index_screen_effect_path(particle_effects_looping[i], mood_type)
        end
    end

    if particle_effects_on_exit then
        for i = 1, #particle_effects_on_exit do
            _index_screen_effect_path(particle_effects_on_exit[i], mood_type)
        end
    end
end

local SCREEN_EFFECT_PATH_TO_BUFF_TEMPLATES = {
    -- Hardcoded mappings for effects not declared in player_effects.on_screen_effect
    ["content/fx/particles/screenspace/screen_psyker_protectorate_passive_add_stack"] = { "psyker_empowered_grenades_passive_visual_buff", "psyker_empowered_grenades_passive_visual_buff_increased" },
    ["content/fx/particles/screenspace/screen_biomancer_maxsouls"] = { "psyker_souls", "psyker_souls_increased_max_stacks" },
    ["content/fx/particles/screenspace/screen_biomancer_souls"] = { "psyker_souls", "psyker_souls_increased_max_stacks" },
}

-- Performance Impact: Negligible. This iteration over BuffTemplates occurs only once during module loading and builds a fast lookup map.
for template_name, template in pairs(BuffTemplates) do
    if template then
        -- 1. Check continuous player_effects
        local player_effects = template.player_effects
        if player_effects then
            local on_screen_effect = player_effects.on_screen_effect
            if type(on_screen_effect) == "string" and on_screen_effect ~= "" then
                local list = SCREEN_EFFECT_PATH_TO_BUFF_TEMPLATES[on_screen_effect]
                if not list then
                    list = {}
                    SCREEN_EFFECT_PATH_TO_BUFF_TEMPLATES[on_screen_effect] = list
                end
                _append_unique(list, template_name)
            end
        end

        -- 2. Check momentary proc_effects (e.g. damage_reduction_on_critical_hit)
        local proc_effects = template.proc_effects
        local proc_player_effects = proc_effects and proc_effects.player_effects
        if proc_player_effects then
            local on_screen_effect = proc_player_effects.on_screen_effect
            if type(on_screen_effect) == "string" and on_screen_effect ~= "" then
                local list = SCREEN_EFFECT_PATH_TO_BUFF_TEMPLATES[on_screen_effect]
                if not list then
                    list = {}
                    SCREEN_EFFECT_PATH_TO_BUFF_TEMPLATES[on_screen_effect] = list
                end
                _append_unique(list, template_name)
            end
        end
    end
end

local function _screen_effect_path_for_lookup_id(lookup_id)
    if type(lookup_id) ~= "string" or lookup_id == "" then
        return nil
    end

    if lookup_id:find("^content/") then
        return lookup_id
    end

    local template = BuffTemplates[lookup_id]
    if template then
        local player_effects = template.player_effects
        local on_screen_effect = player_effects and player_effects.on_screen_effect

        if type(on_screen_effect) == "string" and on_screen_effect ~= "" then
            return on_screen_effect
        end

        local proc_effects = template.proc_effects
        local proc_player_effects = proc_effects and proc_effects.player_effects
        local proc_on_screen_effect = proc_player_effects and proc_player_effects.on_screen_effect

        if type(proc_on_screen_effect) == "string" and proc_on_screen_effect ~= "" then
            return proc_on_screen_effect
        end
    end

    return nil
end

-- Performance Impact: Negligible. Just a few fast dictionary lookups and tiny iterations, keeping memory allocation minimal.
local function _candidate_ids_for_lookup(lookup_id)
    local candidates = { lookup_id }
    local screen_effect_path = _screen_effect_path_for_lookup_id(lookup_id)

    if screen_effect_path then
        local matching_moods = SCREEN_EFFECT_PATH_TO_MOODS[screen_effect_path]

        if matching_moods then
            for i = 1, #matching_moods do
                local mood_type = matching_moods[i]

                if mood_type ~= lookup_id then
                    _append_unique(candidates, mood_type)
                end
            end
        end

        local matching_buffs = SCREEN_EFFECT_PATH_TO_BUFF_TEMPLATES[screen_effect_path]
        if matching_buffs then
            for i = 1, #matching_buffs do
                _append_unique(candidates, matching_buffs[i])
            end
        end

        if screen_effect_path ~= lookup_id then
            _append_unique(candidates, screen_effect_path)
        end
    else
        local matching_buffs = SCREEN_EFFECT_PATH_TO_BUFF_TEMPLATES[lookup_id]
        if matching_buffs then
            for i = 1, #matching_buffs do
                _append_unique(candidates, matching_buffs[i])
            end
        end
    end

    return candidates
end

local function _fallback_label_for_id(original_id, lookup_id)
    if type(original_id) == "string" and original_id ~= "" then
        return original_id
    end

    return lookup_id
end

-- Returns: group (string: "moods"), loc_key (string)
function mod.tbf_moods.resolve(mood_type, buff_extension)
    if type(mood_type) ~= "string" or mood_type == "" then
        return nil, nil
    end

    local original_id = mood_type
    local lookup_id = mood_type
    if lookup_id:sub(1, 3) == "fx:" then
        lookup_id = lookup_id:sub(4)
    end

    local candidate_ids = _candidate_ids_for_lookup(lookup_id)
    local loc_key = nil

    -- 1. Fast Path: Hardcoded mood mappings
    for i = 1, #candidate_ids do
        local candidate_id = candidate_ids[i]
        loc_key = HARDCODED_MOOD_LOCS[candidate_id]

        if loc_key then
            break
        end
    end

    -- 2. Try leveraging SBF's native generic resolution fallback logic
    if not loc_key then
        local Resolve = mod.resolve or mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/resolve")

        if Resolve then
            for i = 1, #candidate_ids do
                local candidate_id = candidate_ids[i]

                if Resolve.static_misc_loc_key_for_template then
                    loc_key = Resolve.static_misc_loc_key_for_template(candidate_id)
                end

                if not loc_key and Resolve.breed_loc_key_from_id then
                    loc_key = Resolve.breed_loc_key_from_id(candidate_id)
                end

                if not loc_key and Resolve.talent_from_template_key then
                    local mock_template = BuffTemplates[candidate_id] or {
                        name = candidate_id,
                        hud_icon = "content/ui/textures/icons/buffs/hud/psyker/psyker_ability_overcharge_stance",
                    }
                    local _, _, disp = Resolve.talent_from_template_key(mock_template, candidate_id)

                    if disp then
                        loc_key = disp
                    end
                end

                if loc_key then
                    break
                end
            end
        end
    end

    -- 3. Piggyback Syringe Loc Mapper
    if not loc_key then
        for i = 1, #candidate_ids do
            local candidate_id = candidate_ids[i]

            if candidate_id:find("^syringe_") then
                if mod.syringe_loc_for_buff then
                    loc_key = mod.syringe_loc_for_buff(candidate_id, nil)
                end

                if loc_key then
                    break
                end
            end
        end
    end

    -- 4. Dynamically locate the associated active Buff driving this Mood/Screen Effect
    if not loc_key and buff_extension then
        local buffs = buff_extension:buffs()
        local matched_buff = nil

        if buffs then
            for i = 1, #buffs do
                local b = buffs[i]
                local t = b and b:template()

                if t then
                    local resolved_name = mod.tbf_buff and mod.tbf_buff.template_name and mod.tbf_buff.template_name(b)

                    for j = 1, #candidate_ids do
                        local candidate_id = candidate_ids[j]

                        if t.name == candidate_id or resolved_name == candidate_id then
                            matched_buff = b
                            break
                        end

                        if t.keywords then
                            for k = 1, #t.keywords do
                                if t.keywords[k] == candidate_id then
                                    matched_buff = b
                                    break
                                end
                            end
                        end
                    end
                end

                if matched_buff then
                    break
                end
            end
        end

        if matched_buff then
            local _, loc = nil, nil

            if mod.tbf_talents and mod.tbf_talents.resolve then
                _, loc = mod.tbf_talents.resolve(matched_buff)
            end
            if not loc and mod.tbf_traits and mod.tbf_traits.resolve then
                _, loc = mod.tbf_traits.resolve(matched_buff)
            end
            if not loc and mod.tbf_misc and mod.tbf_misc.resolve then
                _, loc = mod.tbf_misc.resolve(matched_buff)
            end

            if loc then
                loc_key = loc
            end
        end
    end

    if not loc_key then
        loc_key = _fallback_label_for_id(original_id, lookup_id)
    end

    -- ALWAYS map to the "moods" group so the moods dropdown shares rules for
    -- native moods and screen effects, while buff icons stay separate by group.
    return "moods", loc_key
end
