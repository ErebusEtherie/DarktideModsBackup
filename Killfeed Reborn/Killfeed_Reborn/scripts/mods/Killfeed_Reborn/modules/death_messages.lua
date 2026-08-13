local death_messages = {}

local function get_classification_pool(entry)
    return entry and entry.broad and entry.broad[1] or nil
end

local function is_known_kill_profile(profile, damage_tables, profile_family_lookup)
    damage_tables = damage_tables or {}

    if damage_tables.profile_overrides and damage_tables.profile_overrides[profile] then
        return true
    end

    if profile_family_lookup and profile_family_lookup[profile] then
        return true
    end

    return false
end

local message_states = {
    consumed = "downed",
    dead = "Killed",
    grabbed = "downed",
    hogtied = "downed",
    knocked_down = "downed",
    ledge_hanging = "downed",
    mutant_charged = "downed",
    netted = "downed",
    pounced = "downed",
    warp_grabbed = "downed",
}

local function profile_name_from_damage(data)
    if type(data) == "table" then
        return data.profile_name
    end

    return data
end

-- Deaths (explicit profile classification)
function death_messages.get_profile_death_source(profile_name, death_classifications, damage_tables, profile_family_lookup)
    local profile = string.lower(tostring(profile_name or ""))
    death_classifications = death_classifications or {}

    if profile == "" or profile == "nil" then
        return nil, nil, nil, "unclassified"
    end

    local entry = death_classifications.profile_overrides and death_classifications.profile_overrides[profile]
    local bucket = get_classification_pool(entry)

    local source_name = death_classifications.source_names and death_classifications.source_names[bucket]

    if not source_name then
        if is_known_kill_profile(profile, damage_tables, profile_family_lookup) then
            return nil, nil, nil, "ignored"
        end

        return nil, nil, nil, "unclassified"
    end

    return bucket, source_name, true
end

local function report_unclassified_death(ctx, profile_name)
    if not ctx.settings.unknown_profile_logging then
        return
    end

    ctx.profile_logger.append("death", profile_name)
    ctx.add_combat_feed_message(ctx.colorize("logged unclassified death profile", ctx.colors.error))
end

-- Deaths (message building)
function death_messages.add_player_death_message(ctx, dead_unit, bucket, source_name, use_source_determiner)
    local player_name = ctx.get_name(dead_unit)

    if not player_name then
        return
    end

    if not bucket then
        return
    end

    local phrase, phrase_entry = ctx.phrase_picker.random_death_phrase(ctx.phrases, bucket)
    if phrase_entry and phrase_entry.use_determiner == false then
        use_source_determiner = false
    end

    local text

    local phrase_text = ctx.settings.neon and ctx.settings.neon_everything
        and ctx.neon_text(phrase, ctx.colors.neon)
        or ctx.colorize(phrase, ctx.colors.death_action)

    if ctx.death_classifications.non_entity_pools and ctx.death_classifications.non_entity_pools[bucket] then
        text = string.format(
            "%s %s",
            ctx.colorize(player_name, ctx.get_killer_color(dead_unit)),
            phrase_text
        )
    else
        local source_text = source_name
        if use_source_determiner then
            source_text = string.format("%s %s", ctx.random_death_source_det(), source_name)
        end

        text = string.format(
            "%s %s %s",
            ctx.colorize(source_text, ctx.colors.victim),
            phrase_text,
            ctx.colorize(player_name, ctx.get_killer_color(dead_unit))
        )
    end

    ctx.add_combat_feed_message(text)

    return text
end

-- Deaths (state detection)
local function get_player_message_state(ctx, attacked_unit)
    local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
    local character_state_component = unit_data_extension and unit_data_extension:read_component("character_state")
    local disabled_character_state_component = unit_data_extension and unit_data_extension:read_component("disabled_character_state")
    local state_name = character_state_component and character_state_component.state_name
    local disabling_type = disabled_character_state_component and disabled_character_state_component.is_disabled and disabled_character_state_component.disabling_type

    if disabling_type and disabling_type ~= "none" then
        state_name = disabling_type
    end

    if not message_states[state_name] then
        return nil
    end

    return state_name
end

function death_messages.maybe_add_player_state_message(ctx, attacked_unit, attacking_unit, damage_profile_name)
    if not ctx.is_player_unit(attacked_unit) then
        return
    end

    if not ctx.should_show_for_metrics(attacked_unit) then
        return
    end

    local player_name = ctx.get_name(attacked_unit)
    if not player_name then
        return
    end

    local state_name = get_player_message_state(ctx, attacked_unit)
    local action_text = message_states[state_name]

    if not action_text then
        ctx.active_player_state_messages[player_name] = nil
        return
    end

    if ctx.active_player_state_messages[player_name] == state_name then
        return
    end

    local attacker_cache = attacking_unit and ctx.last_damage[attacking_unit]
    local damage_data = attacker_cache and attacker_cache[attacked_unit]

    local profile_name = damage_profile_name or profile_name_from_damage(damage_data)
    local bucket, source_name, use_source_determiner, reason = death_messages.get_profile_death_source(profile_name, ctx.death_classifications, ctx.damage_tables, ctx.profile_family_lookup)

    if not bucket then
        if reason == "unclassified" then
            report_unclassified_death(ctx, profile_name)
        end

        return
    end

    ctx.active_player_state_messages[player_name] = state_name
    death_messages.add_player_death_message(ctx, attacked_unit, bucket, source_name, use_source_determiner)
end

return death_messages
