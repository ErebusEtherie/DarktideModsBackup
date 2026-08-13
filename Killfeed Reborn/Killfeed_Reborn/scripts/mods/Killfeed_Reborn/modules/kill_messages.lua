local kill_messages = {}

local function clear_cached_damage(ctx, attacker, victim, attacker_cache)
    if not attacker_cache then
        return
    end

    attacker_cache[victim] = nil

    if next(attacker_cache) == nil then
        ctx.last_damage[attacker] = nil
    end
end

local function report_unclassified_kill(ctx, self, attacker, victim, attacker_cache, profile_name)
    clear_cached_damage(ctx, attacker, victim, attacker_cache)

    if not ctx.settings.unknown_profile_logging then
        return
    end

    ctx.profile_logger.append("kill", profile_name)
    self:_add_combat_feed_message(ctx.colorize("logged unclassified kill profile", ctx.colors.error))
end

local function profile_name_from_damage(data)
    if type(data) == "table" then
        return data.profile_name
    end

    return data
end

-- Classification (damage profiles)
function kill_messages.get_category_from_damage(data, damage_tables, profile_family_lookup, choose_random_category)
    if not data then
        return nil, "missing damage data", nil
    end

    local profile_name = string.lower(tostring(profile_name_from_damage(data) or ""))

    if profile_name == "" or profile_name == "nil" then
        return nil, "missing damage profile", nil
    end

    local profile_overrides = damage_tables.profile_overrides or {}
    local family_defaults = damage_tables.family_defaults or {}
    local profile_entry = profile_overrides[profile_name]

    if profile_entry then
        local detected = choose_random_category(profile_entry.specific) or choose_random_category(profile_entry.broad)

        if detected then
            profile_entry.source = "profile_override"
            return detected, "profile override table", profile_entry
        end
    end

    local family = profile_family_lookup[profile_name]
    local family_entry = family and family_defaults[family]

    if family_entry then
        local detected = choose_random_category(family_entry.specific) or choose_random_category(family_entry.broad)

        if detected then
            family_entry.source = "family_default"
            return detected, string.format("profile family table (%s)", family), family_entry
        end
    end

    return nil, "unclassified damage profile", nil
end

-- Hooks (kill messages)
function kill_messages.handle(ctx, self, attacker, victim)
    local killer_name = ctx.get_name(attacker)
    local victim_name = ctx.get_name(victim)

    if not killer_name or not victim_name then
        return false
    end

    if not ctx.should_show_for_metrics(attacker) then
        return true
    end

    local attacker_cache = ctx.last_damage[attacker]
    local data = attacker_cache and attacker_cache[victim]
    local profile_name = profile_name_from_damage(data)
    local detected_category, _, source_entry = kill_messages.get_category_from_damage(data, ctx.damage_tables, ctx.profile_family_lookup, ctx.choose_random_category)

    if not detected_category then
        report_unclassified_kill(ctx, self, attacker, victim, attacker_cache, profile_name)
        return true
    end

    local phrase_entry, chosen_category = ctx.phrase_picker.random_phrase(ctx.phrases, detected_category, source_entry, ctx.settings)

    if not phrase_entry then
        report_unclassified_kill(ctx, self, attacker, victim, attacker_cache, profile_name)
        return true
    end

    local phrase = phrase_entry.text
    local use_determiner = phrase_entry.use_determiner ~= false
    local determiner = use_determiner and ctx.random_det() or nil
    local killer_color = ctx.get_killer_color(attacker)
    local use_neon = ctx.settings.neon and (ctx.settings.neon_everything or chosen_category == "funny")
    local action_text = use_determiner and phrase .. " " .. determiner or phrase
    local action_color_text = use_neon and ctx.neon_text(action_text, ctx.colors.neon) or ctx.colorize(action_text, ctx.colors.action)
    local text = string.format(
        "%s %s %s",
        ctx.colorize(killer_name, killer_color),
        action_color_text,
        ctx.colorize(victim_name, ctx.colors.victim)
    )

    clear_cached_damage(ctx, attacker, victim, attacker_cache)

    self:_add_combat_feed_message(text)
    return true
end

return kill_messages
