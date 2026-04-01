-- File: ZipIt2/scripts/mods/ZipIt2/core/ZipIt2_rules.lua
local mod = get_mod("ZipIt2"); if not mod then return end

local type, string, pairs, rawget, _G = type, string, pairs, rawget, _G

local PLAYER_COM_WHEEL_CONCEPT_FRAGMENTS = {
    "on_demand_com_wheel",
    "on_demand_vo_tag_enemy",
    "on_demand_vo_tag_item",
}

local PLAYER_COMBAT_CONCEPT_FRAGMENTS = {
    "combat_ability",
    "enemy_kill",
    "heard_enemy",
    "heard_horde",
    "higher_elite_threat",
    "interaction_vo",
    "knocked_down",
    "player_death",
    "player_enemy_alert",
    "seen_enemy_group_far_range_shooting_behind_cover",
    "seen_enemy",
    "seen_horde",
    "throwing_item",
    "throwing_net",
    "warning",
    "catching_net",
    "heal_start",
    "ledge_hanging",
    "pounced_by_special_attack",
    "rapid_loosing_health",
}

local PLAYER_SOCIAL_CONCEPT_FRAGMENTS = {
    "confessional_vo",
    "enemy_near_death_monster",
    "environmental_story",
    "friendly_fire",
    "friends_close",
    "friends_distant",
    "head_shot",
    "health_hog",
    "heard_speak",
    "heat_vo",
    "kill_spree_self",
    "knocked_down_multiple_times",
    "multiple_head_pops",
    "pinned_by_enemies",
    "player_tip_armor_hit",
    "ranged_idle_player_out_of_ammo",
    "reload_failed",
    "reloading",
    "short_story_talk",
    "start_banter",
    "story_talk",
    "combat_story_talk",
    "cutscene_vo_line",
    "ammo_hog",
    "seen_killstreak_",
}

local function _contains(value, fragment)
    return type(value) == "string" and type(fragment) == "string" and string.find(value, fragment, 1, true) ~= nil
end

local function _contains_any(value, fragments)
    if type(value) ~= "string" or value == "" or type(fragments) ~= "table" then
        return false
    end

    local count = #fragments

    for i = 1, count do
        if _contains(value, fragments[i]) then
            return true
        end
    end

    return false
end

local function _starts_with_any(value, prefixes)
    if type(value) ~= "string" or value == "" or type(prefixes) ~= "table" then
        return false
    end

    local count = #prefixes

    for i = 1, count do
        if mod.starts_with(value, prefixes[i]) then
            return true
        end
    end

    return false
end

local function _sanitize_player_mode(value)
    local valid = {
        all = true,
        muted = true,
        com_wheel = true,
        combat = true,
        social = true,
        com_wheel_combat = true,
        com_wheel_social = true,
        combat_social = true
    }

    if valid[value] then
        return value
    end

    -- Legacy migration
    if value == "none" then return "all" end
    if value == "combat" then return "com_wheel_social" end
    if value == "social" then return "com_wheel_combat" end
    if value == "both" then return "com_wheel" end

    return "all"
end

local function _classify_explicit_player_concept(identifier)
    if type(identifier) ~= "string" or identifier == "" then
        return nil
    end

    if _contains_any(identifier, PLAYER_COM_WHEEL_CONCEPT_FRAGMENTS) then
        return "com_wheel"
    end

    -- Social is intentionally checked before combat so explicit social concepts like
    -- knocked_down_multiple_times, combat_story_talk, pinned_by_enemies and the
    -- seen_killstreak_* family are not swallowed by broader combat rules.
    if _contains_any(identifier, PLAYER_SOCIAL_CONCEPT_FRAGMENTS) then
        return "social"
    end

    if _contains_any(identifier, PLAYER_COMBAT_CONCEPT_FRAGMENTS) then
        return "combat"
    end

    return nil
end

local function _is_player_ping_or_com_wheel_event(identifier)
    if type(identifier) ~= "string" or identifier == "" then
        return false
    end

    return _contains(identifier, "com_wheel_vo")
end

local function _is_player_explicit_social_event(identifier)
    if type(identifier) ~= "string" or identifier == "" then
        return false
    end

    if _contains(identifier, "conversation") then return true end
    if _contains(identifier, "bonding") then return true end
    if _contains(identifier, "reply") and not _contains(identifier, "no_reply") then return true end

    return false
end

local function _is_player_combat_event(identifier)
    if type(identifier) ~= "string" or identifier == "" then
        return false
    end

    if _starts_with_any(identifier, {
            "player_death",
            "team_downed",
            "player_ability",
            "player_kill",
            "player_horde",
            "player_throw",
            "team_warning",
            "team_hacking",
            "team_monster",
            "player_blitz",
            "seen_netgunner",
            "seen_enemy_",
        })
    then
        return true
    end

    if _contains_any(identifier, {
            "ability",
            "blitz",
            "throwing_grenade",
            "enemy_daemonhost",
            "event_scan",
            "luggable",
            "warning_exploding_barrel",
            "critical_health",
            "response_to_hacking_fix_decode",
            "hacking_fix_decode",
            "monster_fight_start_reaction",
            "disabled_by_enemy",
            "need_rescue",
            "disabled_by_chaos_hound",
            "response_for_pinned_by_enemies",
            "_kill",
        })
    then
        return true
    end

    return false
end

local function _local_player_voice_profile()
    local _Managers = rawget(_G, "Managers")
    local player_manager = _Managers and _Managers.player
    local local_player = player_manager and player_manager:local_player_safe(1)
    local player_unit = local_player and local_player.player_unit
    local dialogue_extension = player_unit and ScriptUnit.has_extension(player_unit, "dialogue_system")
    local voice_profile = dialogue_extension and dialogue_extension._vo_profile_name

    if type(voice_profile) == "string" and voice_profile ~= "" then
        return voice_profile
    end

    return nil
end

mod.zipit2_classify_player_voice_identifier = mod.zipit2_classify_player_voice_identifier or function(identifier)
    local explicit_category = _classify_explicit_player_concept(identifier)

    if explicit_category then
        return explicit_category
    end

    if _is_player_ping_or_com_wheel_event(identifier) then
        return "com_wheel"
    end

    if _is_player_explicit_social_event(identifier) then
        return "social"
    end

    if _is_player_combat_event(identifier) then
        return "combat"
    end

    return "social" -- anything not allocated already is dumped into social
end

local function _should_mute_player_voice_mode(player_mode, identifier)
    player_mode = _sanitize_player_mode(player_mode)

    if player_mode == "all" then
        return false
    end

    if player_mode == "muted" then
        return true
    end

    local category = mod.zipit2_classify_player_voice_identifier(identifier)

    -- If category string is found in the combination string, it's enabled and should not be muted
    return string.find(player_mode, category, 1, true) == nil
end

function mod.zipit2_should_mute_voice_profile(voice_profile, identifier)
    if type(voice_profile) ~= "string" or voice_profile == "" then
        return false
    end

    local d = mod._zipit2_discovery

    if type(d) ~= "table" then
        return false
    end

    local st = mod._zipit2_state
    local s = mod._zipit2_settings
    local in_briefings = st.in_lobby_view or st.in_mission_intro_view or st.in_briefing_state

    if in_briefings then
        local mode = s.briefing_mute_mode
        local should_skip = false

        if st.started_from_lobby then
            should_skip = mode == "lobby_only" or mode == "both"
        else
            should_skip = mode == "rejoin_only" or mode == "both"
        end

        if should_skip then
            return true
        end
    end

    local player_voice_set = d.player_voice_set or {}

    if player_voice_set[voice_profile] then
        return _should_mute_player_voice_mode(s.player_mode[voice_profile], identifier)
    end

    local major_voice_to_class = d.major_voice_to_class or {}
    local major_key = major_voice_to_class[voice_profile]

    if major_key then
        local major_state = s.major[major_key]

        if not major_state then
            return false
        end

        if in_briefings then
            return major_state.briefings_enabled == false
        end

        local chatter = major_state.chatter

        if chatter == "none" then
            return false
        end

        if chatter == "both" then
            return true
        end

        local _Managers = rawget(_G, "Managers")
        local mech = _Managers and _Managers.mechanism
        local is_hub = mech and mech:mechanism_name() == "hub"

        if is_hub then
            return chatter == "mission"
        end

        return chatter == "hub"
    end

    local minor_voice_to_group = d.minor_voice_to_group or {}
    local minor_key = minor_voice_to_group[voice_profile]

    if minor_key then
        return s.minor_enabled[minor_key] == false
    end

    return false
end

function mod.zipit2_should_suppress_muted_voice_ui(voice_profile, identifier)
    local s = mod._zipit2_settings

    return not s.subtitles_enabled and mod.zipit2_should_mute_voice_profile(voice_profile, identifier)
end

function mod.zipit2_should_mute_breed_sound_event(event_name)
    if type(event_name) ~= "string" or event_name == "" then
        return false
    end

    local d = mod._zipit2_discovery

    if type(d) ~= "table" then
        return false
    end

    local breed_sound_event_to_groups = d.breed_sound_event_to_groups

    if type(breed_sound_event_to_groups) ~= "table" then
        return false
    end

    local group_map = breed_sound_event_to_groups[event_name]

    if type(group_map) ~= "table" then
        return false
    end

    local s = mod._zipit2_settings
    local have_any_group = false

    for group_key, included in pairs(group_map) do
        if included then
            have_any_group = true

            if s.breed_enabled[group_key] ~= false then
                return false
            end
        end
    end

    return have_any_group
end

function mod.zipit2_should_mute_ping_tag_sounds()
    local s = mod._zipit2_settings
    return s.ping_sound_mode == "muted"
end

function mod.zipit2_should_mute_on_demand_sound_event(concept)
    if type(concept) ~= "string" or concept == "" then
        return false
    end

    local voice_profile = _local_player_voice_profile()

    if voice_profile then
        return mod.zipit2_should_mute_voice_profile(voice_profile, concept)
    end

    return false
end
