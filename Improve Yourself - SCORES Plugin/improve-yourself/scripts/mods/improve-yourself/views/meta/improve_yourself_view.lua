local mod = get_mod("improve-yourself")

local Danger = mod:original_require("scripts/utilities/danger")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")
local ViewElementProfilePresetsSettings = mod:original_require("scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings")

local CUSTOM_ICON_PATHS = {
    "content/ui/materials/icons/item_types/ranged_weapons",
    "content/ui/materials/icons/circumstances/assault_01",
    "content/ui/materials/icons/item_types/weapons",
    "content/ui/materials/icons/item_types/melee_weapons",
    "content/ui/materials/hud/interactions/icons/grenade",
    "content/ui/materials/icons/circumstances/hunting_grounds_01",
    "content/ui/materials/icons/circumstances/ventilation_purge_01",
    "content/ui/materials/icons/circumstances/nurgle_manifestation_01",
    "content/ui/materials/icons/pocketables/hud/scripture",
    "content/ui/materials/icons/pocketables/hud/corrupted_auspex_scanner",
    "content/ui/materials/hud/interactions/icons/barber",
    "content/ui/materials/hud/interactions/icons/forge",
    "content/ui/materials/hud/interactions/icons/mission_board",
    "content/ui/materials/icons/throwables/hud/missile_launcher",
    "content/ui/materials/icons/pocketables/hud/syringe_power",
    "content/ui/materials/hud/interactions/icons/expeditions",
    "content/ui/materials/hud/interactions/icons/valkyrie_payload",
    "content/ui/materials/hud/interactions/icons/artillery_strike",
    "content/ui/materials/hud/interactions/icons/big_fn_grenade",
    "content/ui/materials/hud/interactions/icons/valkyrie_hover",
    "content/ui/materials/hud/interactions/icons/landmine_fire",
    "content/ui/materials/hud/interactions/icons/landmine_shock",
    "content/ui/materials/hud/interactions/icons/time_syringe",
    "content/ui/materials/hud/interactions/icons/barrel_explosive",
    "content/ui/materials/backgrounds/scanner/scanner_decoration_skull",
    "content/ui/materials/hud/interactions/icons/expeditions_death",
    "content/ui/materials/hud/interactions/icons/help",
    "content/ui/materials/icons/weapons/actions/ads",
    "content/ui/materials/icons/weapons/actions/flashlight",
}

local UNICODE_ICON_CODES = {
    0xE053, 0xE000, 0xE001, 0xE002, 0xE003, 0xE004, 0xE005, 0xE006, 0xE007,
    0xE01F, 0xE021, 0xE026, 0xE029, 0xE02E, 0xE041, 0xE042, 0xE045, 0xE046,
    0xE049, 0xE04D, 0xE04F, 0xE051, 0xE107, 0xE108, 0xE109, 0xE10A, 0xE010,
    0xE011, 0xE012, 0xE013, 0xE014, 0xE015, 0xE016, 0xE017, 0xE018, 0xE019,
}

local function encode_utf8(decimal)
    if decimal < 128 then return string.char(decimal) end
    local charbytes = {}
    local markers = {{0x7FF, 192}, {0xFFFF, 224}, {0x1FFFFF, 240}}
    for bytes, vals in ipairs(markers) do
        if decimal <= vals[1] then
            for b = bytes + 1, 2, -1 do
                local rem = decimal % 64
                decimal = (decimal - rem) / 64
                charbytes[b] = string.char(128 + rem)
            end
            charbytes[1] = string.char(vals[2] + decimal)
            break
        end
    end
    return table.concat(charbytes)
end

local function damage_source_layout(values, category_order, total_height, minimum_height)
    local layout = {}
    local total_value = 0

    for order, category in ipairs(category_order) do
        local value = math.max(0, tonumber(values[category]) or 0)
        if value > 0 then
            layout[#layout + 1] = {category = category, value = value, order = order}
            total_value = total_value + value
        end
    end

    table.sort(layout, function(a, b)
        if a.value == b.value then
            return a.order < b.order
        end
        return a.value > b.value
    end)

    local count = #layout
    if count == 0 then
        return layout
    end

    local effective_minimum = math.min(minimum_height, total_height / count)
    local unresolved = {}
    for i = 1, count do
        unresolved[i] = layout[i]
    end

    local remaining_height = total_height
    local remaining_value = total_value
    while #unresolved > 0 do
        local fixed_one = false
        for i = #unresolved, 1, -1 do
            local item = unresolved[i]
            local proportional_height = remaining_value > 0 and item.value / remaining_value * remaining_height or remaining_height / #unresolved
            if proportional_height < effective_minimum then
                item.height = effective_minimum
                remaining_height = remaining_height - effective_minimum
                remaining_value = remaining_value - item.value
                table.remove(unresolved, i)
                fixed_one = true
                break
            end
        end
        if not fixed_one then
            break
        end
    end

    for _, item in ipairs(unresolved) do
        item.height = remaining_value > 0 and item.value / remaining_value * remaining_height or remaining_height / #unresolved
    end

    return layout
end

local function resolve_catalogue_icon(index)
    index = tonumber(index)
    if not index then return {kind = "none"} end
    local settings = ViewElementProfilePresetsSettings or {}
    local refs = settings.optional_preset_icon_reference_keys or {}
    local lookup = settings.optional_preset_icons_lookup or {}
    local vanilla_count = #refs
    if index >= 1 and index <= vanilla_count then
        local key = refs[index]
        local material = key and lookup[key]
        if material then return {kind = "material", value = material} end
        return {kind = "none"}
    end
    local custom_index = index - vanilla_count
    if custom_index >= 1 and custom_index <= #CUSTOM_ICON_PATHS then
        return {kind = "material", value = CUSTOM_ICON_PATHS[custom_index]}
    end
    local unicode_index = custom_index - #CUSTOM_ICON_PATHS
    local code = UNICODE_ICON_CODES[unicode_index]
    if code then return {kind = "unicode", value = encode_utf8(code)} end
    return {kind = "none"}
end

local metric_sections = {
    {
        widget = "section_defense",
        text = "Defense",
        direction = "lower",
        metrics = {
            {widget = "damage_taken", text = "Damage taken", source = "damage_taken", icon_index = 14},
            {widget = "times_downed", text = "Times downed", source = "times_downed", icon_index = 60},
            {widget = "times_disabled", text = "Times disabled", source = "times_disabled", icon_index = 32},
            {widget = "deaths", text = "Deaths", source = "deaths", icon_index = 15},
        },
    },
    {
        widget = "section_offense",
        text = "Offense",
        direction = "higher",
        metrics = {
            {widget = "damage_dealt", text = "Damage total", source = "damage_dealt", icon_index = 11},
            {widget = "weakspot_hits", text = "Weakspot hits", source = "weakspot_hits", icon_index = 19},
            {widget = "melee_kills", text = "Melee kills", source = "melee_kills", icon_index = 29},
            {widget = "ranged_kills", text = "Ranged kills", source = "ranged_kills", icon_index = 26},
            {widget = "lesser_enemies", text = "Swarmers killed", source = "lesser_enemies", icon_index = 33},
            {widget = "elites", text = "Elites killed", source = "melee_ranged_threats", icon_index = 65},
            {widget = "specials", text = "Specials killed", source = "special_threats", icon_index = 25},
            {widget = "boss_damage", text = "Boss damage", source = "boss_damage_dealt", icon_index = 70},
        },
    },
    {
        widget = "section_team",
        text = "Team Contribution",
        direction = "higher",
        metrics = {
            {widget = "coherency", text = "Coherency score", source = "coherency_efficiency", icon_index = 62},
            {widget = "revives", text = "Revives", source = "revived_operative", icon_index = 13},
            {widget = "saves", text = "Saves", source = "team_saves", icon_index = 17},
            {widget = "ammo", text = "Ammo score", source = "ammo_score", icon_index = 21},
        },
    },
}

local function active_section_metrics(section)
    local result = {}
    for _, metric in ipairs(section.metrics or {}) do
        local tier_metric = metric.source == "lesser_enemies"
            or metric.source == "melee_ranged_threats"
            or metric.source == "special_threats"
        if not tier_metric and mod:is_metric_enabled(metric.source) then
            result[#result + 1] = metric
        elseif tier_metric and mod:detailed_kill_split_enabled() then
            result[#result + 1] = metric
        end
    end
    return result
end

local function metric_target(role, metric)
    return tonumber(role.targets[metric.source]) or 25
end


local default_role_profiles = {
    generalist = {
        label = "Generalist",
        targets = {
            damage_taken = 27, times_downed = 25, times_disabled = 25, deaths = 25,
            damage_dealt = 22, weakspot_hits = 20, melee_kills = 20, ranged_kills = 18,
            lesser_enemies = 22, melee_ranged_threats = 20, special_threats = 20, boss_damage_dealt = 18,
            coherency_efficiency = 25, revived_operative = 25, team_saves = 25, ammo_score = 25,
        },
    },
    frontline = {
        label = "Melee Anchor",
        targets = {
            damage_taken = 30, times_downed = 30, times_disabled = 30, deaths = 25,
            damage_dealt = 25, weakspot_hits = 18, melee_kills = 30, ranged_kills = 15,
            lesser_enemies = 28, melee_ranged_threats = 28, special_threats = 18, boss_damage_dealt = 18,
            coherency_efficiency = 25, revived_operative = 25, team_saves = 25, ammo_score = 25,
        },
    },
    horde_control = {
        label = "Horde Control",
        targets = {
            damage_taken = 28, times_downed = 27, times_disabled = 27, deaths = 25,
            damage_dealt = 28, weakspot_hits = 15, melee_kills = 22, ranged_kills = 20,
            lesser_enemies = 30, melee_ranged_threats = 20, special_threats = 18, boss_damage_dealt = 15,
            coherency_efficiency = 25, revived_operative = 25, team_saves = 25, ammo_score = 25,
        },
    },
    ranged_specialist = {
        label = "Ranged Specialist",
        targets = {
            damage_taken = 22, times_downed = 22, times_disabled = 22, deaths = 20,
            damage_dealt = 28, weakspot_hits = 28, melee_kills = 15, ranged_kills = 32,
            lesser_enemies = 18, melee_ranged_threats = 28, special_threats = 28, boss_damage_dealt = 20,
            coherency_efficiency = 25, revived_operative = 20, team_saves = 20, ammo_score = 25,
        },
    },
    elite_boss = {
        label = "Elite & Boss Killer",
        targets = {
            damage_taken = 27, times_downed = 25, times_disabled = 25, deaths = 25,
            damage_dealt = 28, weakspot_hits = 25, melee_kills = 20, ranged_kills = 20,
            lesser_enemies = 18, melee_ranged_threats = 30, special_threats = 22, boss_damage_dealt = 32,
            coherency_efficiency = 25, revived_operative = 20, team_saves = 20, ammo_score = 25,
        },
    },
    support_control = {
        label = "Support & Control",
        targets = {
            damage_taken = 25, times_downed = 22, times_disabled = 22, deaths = 20,
            damage_dealt = 20, weakspot_hits = 15, melee_kills = 18, ranged_kills = 18,
            lesser_enemies = 18, melee_ranged_threats = 20, special_threats = 25, boss_damage_dealt = 15,
            coherency_efficiency = 25, revived_operative = 25, team_saves = 25, ammo_score = 20,
        },
    },
}

local role_order = {"generalist", "frontline", "horde_control", "ranged_specialist", "elite_boss", "support_control"}
local canonical_role_labels = {
    generalist = "Generalist",
    frontline = "Melee Anchor",
    horde_control = "Horde Control",
    ranged_specialist = "Ranged Specialist",
    elite_boss = "Elite & Boss",
    support_control = "Support & Control",
}

-- Configured role-target resolver shared by all visual boards.
local function selected_role_profile(role_key)
    local defaults = default_role_profiles[role_key] or default_role_profiles.generalist
    local profile = {label = defaults.label, targets = {}}
    for source, default_value in pairs(defaults.targets) do
        local setting_id = "goal_" .. role_key .. "_" .. source
        local configured = tonumber(mod:get(setting_id))
        profile.targets[source] = configured or default_value
    end
    return profile
end

local function row_index(rows)
    local index = {}
    for _, row in ipairs(rows or {}) do
        if row and row.name then
            index[row.name] = row
        end
    end
    return index
end

-- Resolve direct or recursive summary-row scores from saved match data.
local function source_score(index, source, account_id, visited)
    if source == "ammo_score" then source = "ammo_collected" end
    local row = index[source]
    if not row or not account_id then return 0 end
    visited = visited or {}
    if visited[source] then return 0 end
    visited[source] = true

    local value = 0
    if row.summary then
        for _, child in ipairs(row.summary) do
            value = value + source_score(index, child, account_id, visited)
        end
    else
        local data = row.data and row.data[account_id]
        value = tonumber(data and (data.score or data.value)) or 0
    end

    visited[source] = nil
    return value
end

local function source_recorded(index, source)
    if source == "ammo_score" then source = "ammo_collected" end
    return index[source] ~= nil
end

local function source_text(index, source, account_id)
    local row = index[source]
    local data = row and row.data and account_id and row.data[account_id]
    local value = data and (data.text_data or data.text)
    return type(value) == "string" and value ~= "" and value or nil
end

-- Read the persisted display value used by visible metric labels.
local function source_display_value(index, source, account_id, visited)
    local row = index[source]
    if not row or not account_id then return nil end
    visited = visited or {}
    if visited[source] then return nil end
    visited[source] = true

    local value
    if row.summary then
        -- Summary rows do not persist a display string of their own. Keep the
        -- established numeric fallback for those composite metrics.
        value = nil
    else
        local data = row.data and row.data[account_id]
        local text = data and data.text_data
        if text ~= nil and tostring(text) ~= "" and tostring(text) ~= "nil" then
            value = tostring(text)
        end
    end

    visited[source] = nil
    return value
end

local function ordered_players(entry)
    local players = {}
    for _, player in pairs(entry.players or {}) do
        players[#players + 1] = player
    end
    table.sort(players, function(a, b)
        return (tonumber(a.index) or 99) < (tonumber(b.index) or 99)
    end)
    return players
end

local green = {255, 35, 190, 110}
local close_grey_green = {255, 126, 148, 126}
local grey = Color.terminal_text_body(180, true)
local gold_fill = {255, 202, 154, 32}
local gold_highlight = {255, 255, 226, 112}

local function copy_color(color)
    return {color[1], color[2], color[3], color[4]}
end

local function team_comparison_enabled()
    return mod:get("color_scheme") == "team_comparison"
end

-- Dense team ranking: tied values share a rank. Last place remains neutral
-- grey-green instead of using a punitive red state.
local function team_rank_color(rank, rank_count)
    rank = tonumber(rank)
    rank_count = math.max(1, tonumber(rank_count) or 1)
    if not rank then return nil end
    if rank_count <= 1 then return copy_color(gold_fill) end
    local palette
    if rank_count == 2 then
        palette = {gold_fill, close_grey_green}
    elseif rank_count == 3 then
        palette = {gold_fill, green, close_grey_green}
    else
        palette = {gold_fill, green, close_grey_green, close_grey_green}
    end
    return copy_color(palette[math.max(1, math.min(#palette, rank))])
end

local function result_display_color(result, goal_color, valid)
    if team_comparison_enabled() then
        if valid ~= false and result and result.is_local then
            return team_rank_color(result.team_rank, result.rank_count) or copy_color(goal_color or grey)
        end
        -- Team Comparison is personal feedback only. Never rank-color or gold
        -- another player through the ordinary best-in-team fallback.
        return copy_color(goal_color or grey)
    end
    if result and result.is_best then return copy_color(gold_fill) end
    return copy_color(goal_color or grey)
end

local function result_is_gold(result, valid)
    if not result or valid == false then return false end
    if team_comparison_enabled() then return result.is_local == true and tonumber(result.team_rank) == 1 end
    return result.is_best == true
end

local function fulfillment(direction, actual, target, is_zero_event)
    if is_zero_event then
        if direction == "lower" then
            return 5, string.format("Exceeded  %+0.1f%%", math.max(0, tonumber(target) or 0)), copy_color(green)
        end
        return 0, "Not applicable", copy_color(grey)
    end

    local gap = actual - target
    -- Avoid floating-point artefacts such as 25.0% being displayed as
    -- "Close -0.0%" when the calculated share is microscopically below target.
    if math.abs(gap) < 0.05 then
        gap = 0
    end
    local favorable_gap = direction == "higher" and gap or -gap
    local blocks

    if direction == "higher" then
        blocks = target > 0 and math.floor(math.min(1, actual / target) * 5 + 0.0001) or 5
    else
        blocks = actual <= target and 5 or math.floor(math.min(1, target / math.max(actual, 0.001)) * 5 + 0.0001)
    end
    blocks = math.max(0, math.min(5, blocks))

    if favorable_gap >= 5 then
        return 5, string.format("Exceeded  %+0.1f%%", favorable_gap), copy_color(green)
    elseif favorable_gap >= 0 then
        return 5, string.format("Met  %+0.1f%%", favorable_gap), copy_color(green)
    elseif favorable_gap >= -5 then
        return math.max(blocks, 4), string.format("Close  %0.1f%%", favorable_gap), copy_color(close_grey_green)
    end

    return math.max(blocks, 1), string.format("Below goal  %0.1f%%", favorable_gap), copy_color(close_grey_green)
end

local function muted_comparison_color(color)
    local source = color or grey
    local function blend(channel, target)
        return math.floor((channel or 0) * 0.45 + target * 0.55 + 0.5)
    end
    return {
        210,
        blend(source[2], 92),
        blend(source[3], 102),
        blend(source[4], 98),
    }
end

local function find_me(players)
    for _, player in ipairs(players) do
        if mod:is_local_history_player(player) then
            return player
        end
    end
    return nil
end

local function display_mission_name(name)
    name = tostring(name or "Saved match")
    name = name:gsub("_+", " ")
    name = name:gsub("(%a)([%w']*)", function(first, rest)
        return string.upper(first) .. string.lower(rest)
    end)
    return name
end

local function difficulty_text(entry)
    local havoc_rank = tonumber(entry and entry.mission_havoc_rank)
    if havoc_rank then return "Havoc " .. tostring(havoc_rank) end
    local challenge = tonumber(entry and entry.mission_challenge)
    local resistance = tonumber(entry and entry.mission_resistance)
    local danger = challenge and Danger.danger_by_difficulty(challenge, resistance or challenge) or nil
    if danger and danger.display_name then
        local ok, text = pcall(Localize, danger.display_name)
        if ok and text and text ~= "" then return text end
    end
    local fallback = {[1] = "Sedition", [2] = "Uprising", [3] = "Malice", [4] = "Heresy", [5] = "Damnation"}
    if challenge and fallback[challenge] then return fallback[challenge] end
    local raw = entry and (entry.mission_resistance or entry.mission_challenge)
    return raw and tostring(raw) or "—"
end

local function display_duration(timer)
    local numeric = tonumber(timer)
    if numeric and numeric >= 0 and numeric < 86400 then
        local total = math.floor(numeric + 0.5)
        local hours = math.floor(total / 3600)
        local minutes = math.floor((total % 3600) / 60)
        local seconds = total % 60
        if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, seconds) end
        return string.format("%d:%02d", minutes, seconds)
    end
    timer = tostring(timer or "")
    local hours, minutes, seconds = string.match(timer, "^(%d+):(%d%d):(%d%d)$")
    if not hours then return timer ~= "" and timer or "—" end
    hours, minutes, seconds = tonumber(hours), tonumber(minutes), tonumber(seconds)
    if not hours or hours > 12 then return "—" end
    if hours > 0 then return string.format("%d:%02d:%02d", hours, minutes, seconds) end
    return string.format("%d:%02d", minutes, seconds)
end

local function compact_match_title(entry)
    if entry and entry.victory_defeat == "won" then
        return "VICTORY"
    elseif entry and entry.victory_defeat == "lost" then
        return "LOST"
    end
    return "IMPROVE YOURSELF!"
end

local function compact_mission_subtitle(entry)
    local parts = {
        string.upper(display_mission_name(entry.mission_name)),
        string.upper(difficulty_text(entry)),
        string.upper(display_duration(entry.timer)),
    }
    return table.concat(parts, " | ")
end

local function player_for_account_id(players, account_id)
    for _, player in ipairs(players or {}) do
        if player.account_id == account_id then
            return player
        end
    end
    return nil
end

-- Normalized metric calculation shared by visual boards and role evaluation.
local function metric_result_for_entry(entry, metric, direction, focus_account_id)
    local players = ordered_players(entry)
    local me = focus_account_id and player_for_account_id(players, focus_account_id) or find_me(players)
    if not me then
        return nil
    end

    local index = row_index(entry.rows)
    if not source_recorded(index, metric.source) then
        return nil
    end
    local total = 0
    local mine = 0
    local scores = {}

    local function metric_score(player)
        local score = source_score(index, metric.source, player.account_id)
        return score
    end

    for i = 1, math.min(#players, 4) do
        local player = players[i]
        local score = metric_score(player)
        scores[#scores + 1] = score
        total = total + score
        if player.account_id == me.account_id then
            mine = score
        end
    end

    local is_best = false
    local best = 0
    local team_rank = nil
    local rank_count = 0
    if #scores > 0 then
        best = scores[1]
        for i = 2, #scores do
            if direction == "higher" then
                best = math.max(best, scores[i])
            else
                best = math.min(best, scores[i])
            end
        end
        local best_count = 0
        local unique = {}
        for i = 1, #scores do
            if scores[i] == best then best_count = best_count + 1 end
            unique[scores[i]] = true
        end
        is_best = mine == best and best_count == 1
        local ordered = {}
        for value in pairs(unique) do ordered[#ordered + 1] = value end
        table.sort(ordered, function(a, b)
            if direction == "higher" then
                return a > b
            end
            return a < b
        end)
        rank_count = #ordered
        for i, value in ipairs(ordered) do
            if value == mine then team_rank = i break end
        end
    end

    return {
        is_local = mod:is_local_history_player(me),
        total = total,
        mine = mine,
        best = best,
        share = total > 0 and (mine / total * 100) or 0,
        is_best = is_best,
        team_rank = team_rank,
        rank_count = rank_count,
        -- Scores persists the exact formatted value shown to the player
        -- (for example 131.1k boss damage or 99 coherency) in text_data. Use
        -- that for victory callouts while retaining numeric score for shares.
        raw_display = metric.source == "coherency_efficiency"
            and string.format("%.0f", (#players > 0 and total > 0) and (mine / (total / math.min(#players, 4)) * 100) or 0)
            or source_display_value(index, metric.source, me.account_id),
    }
end

local function add_thousands_separators(value_string)
    local sign, integer, fraction = string.match(value_string, "^([%-]?)(%d+)(%.?%d*)$")
    if not integer then
        return value_string
    end

    local formatted = integer
    while true do
        local replaced, count = string.gsub(formatted, "^(%d+)(%d%d%d)", "%1,%2")
        formatted = replaced
        if count == 0 then
            break
        end
    end

    return sign .. formatted .. (fraction or "")
end

local function format_raw_metric(value, averaged)
    value = tonumber(value) or 0
    local formatted = averaged and string.format("%.1f", value) or tostring(math.floor(value + 0.5))
    return add_thousands_separators(formatted)
end

local function summary_state_for_result(direction, result, target, metric_source)
    if not result then return nil end
    local is_zero_event = result.valid_count ~= nil and result.valid_count <= 0 or result.total <= 0

    -- Avoiding a discrete defensive failure is still a successfully met goal.
    -- Count it for the role result and goal text, but keep it hidden from the
    -- compact bar because there is no event magnitude to visualize.
    if direction == "lower" and metric_source ~= "damage_taken" and (tonumber(result.mine) or 0) <= 0 then
        return "met", 1.5, true
    end

    if is_zero_event then
        return nil
    end
    local _, status = fulfillment(direction, result.share, target, false)
    local state
    if string.sub(status or "", 1, 8) == "Exceeded" or string.sub(status or "", 1, 3) == "Met" then
        state = "met"
    elseif string.sub(status or "", 1, 5) == "Close" then
        state = "close"
    elseif string.sub(status or "", 1, 10) == "Below goal" then
        state = "missed"
    else
        return nil
    end

    local actual = tonumber(result.share) or 0
    target = math.max(0.001, tonumber(target) or 25)
    local achievement
    if direction == "higher" then
        achievement = actual / target
    else
        achievement = target / math.max(actual, 0.001)
    end

    return state, math.max(0, math.min(1.5, achievement))
end

local function summary_score(values)
    local points = 0
    for _, value in ipairs(values) do
        if value.state == "met" then points = points + 1
        elseif value.state == "close" then points = points + 0.5 end
    end
    return #values > 0 and points / #values or 0
end

-- Populate the hidden goal summary that feeds praise and goal counts.
local function apply_summary_widget(widget, section, values, compact)
    widget.content.text = section.text
    local met, close, missed = 0, 0, 0
    local missed_names = {}
    for _, value in ipairs(values) do
        if value.state == "met" then met = met + 1
        elseif value.state == "close" then close = close + 1
        else
            missed = missed + 1
            missed_names[#missed_names + 1] = value.text
        end
    end

    local total = #values
    local visible_values = {}
    for _, value in ipairs(values) do
        if not value.hidden then
            visible_values[#visible_values + 1] = value
        end
    end
    local visible_total = #visible_values
    widget.content.score = total > 0 and string.format("%d/%d goals", met, total) or "No goals"

    local status_parts = {}
    if met > 0 then status_parts[#status_parts + 1] = string.format("%d met", met) end
    if close > 0 then status_parts[#status_parts + 1] = string.format("%d close", close) end
    if missed > 0 then status_parts[#status_parts + 1] = string.format("%d missed", missed) end

    local best_names = {}
    for _, value in ipairs(values) do
        if not value.hidden and value.is_best and value.text then
            best_names[#best_names + 1] = value.text
        end
    end
    if #best_names > 0 then
        status_parts[#status_parts + 1] = "Best of match: " .. table.concat(best_names, ", ")
    end
    local status_text = table.concat(status_parts, "  ·  ")

    local all_goals_met = total > 0 and met == total
    local one_goal_short = total > 0 and met == total - 1
    if compact and all_goals_met then
        widget.content.praise = "OUTSTANDING!"
    elseif compact and one_goal_short then
        widget.content.praise = "IMPRESSIVE!"
    else
        widget.content.praise = ""
    end
    local improve
    if all_goals_met then
        improve = ""
    elseif #missed_names > 0 then
        improve = "Improve: " .. table.concat(missed_names, " · ")
    else
        improve = "All goals within reach"
    end
    if string.len(improve) > 78 then
        improve = string.sub(improve, 1, 75) .. "..."
    end
    if compact and improve ~= "" then
        status_text = status_text ~= "" and (status_text .. "  |  " .. improve) or improve
    end
    widget.content.status = status_text
    widget.content.drivers = ""
    if widget.style.drivers then
        widget.style.drivers.text_color = Color.terminal_text_body(205, true)
    end

    local bar_x = widget.style.bar_background.offset[1]
    local bar_y = widget.style.bar_background.offset[2]
    local bar_w = widget.style.bar_background.size[1]
    local bar_h = widget.style.bar_background.size[2]
    local x = bar_x
    local colors = {met = green, close = close_grey_green, missed = close_grey_green}
    local maximum_metric_count = math.max(1, #active_section_metrics(section))
    -- The full track contains 150% capacity for every possible metric in the
    -- category. Only applicable metrics contribute goal steps.
    local goal_ratio = visible_total / (maximum_metric_count * 1.5)
    local goal_x = bar_x + math.floor(bar_w * math.max(0, math.min(1, goal_ratio)))
    local divider_color = {140, 16, 27, 25}
    local available = bar_w

    for i = 1, 8 do
        local style = widget.style["segment_" .. i]
        local highlight = widget.style["segment_highlight_" .. i]
        local divider = widget.style["segment_divider_" .. i]
        local icon_style = widget.style["segment_icon_" .. i]
        local glyph_style = widget.style["segment_glyph_" .. i]
        local value = visible_values[i]
        if value and visible_total > 0 and available > 0 then
            local target = math.max(0.001, tonumber(value.target) or 25)
            local share = math.max(0, tonumber(value.share) or 0)
            local proportional
            if section.direction == "lower" then
                -- Mirror the actual share around its limit. At the goal this is
                -- exactly 100%; beating the limit extends beyond the goal by the
                -- same percentage-point gap, while exceeding it falls short.
                proportional = (2 * target - share) / target
            else
                proportional = share / target
            end
            proportional = math.max(0, math.min(1.5, proportional))
            local raw_w = math.floor(bar_w * proportional / (maximum_metric_count * 1.5) + 0.5)
            local w = math.min(raw_w, available)
            if w > 0 and i < visible_total then
                w = math.max(1, w - 1)
            end
            local goal_color = colors[value.state] or grey
            local color = team_comparison_enabled()
                and (team_rank_color(value.team_rank, value.rank_count) or copy_color(goal_color))
                or (value.is_best and gold_fill or goal_color)
            style.offset = {x, bar_y, 8}
            style.size = {w, bar_h}
            style.color = copy_color(color)
            highlight.offset = {x, bar_y, 9}
            highlight.size = {w, 2}
            local segment_gold = team_comparison_enabled() and tonumber(value.team_rank) == 1 or value.is_best
            highlight.color = segment_gold and copy_color(gold_highlight) or {
                math.min(255, color[1] or 255),
                math.min(255, (color[2] or 0) + 35),
                math.min(255, (color[3] or 0) + 35),
                math.min(255, (color[4] or 0) + 35),
            }
            local icon_size = math.min(16, math.max(10, w - 6))
            local icon = value.icon or {kind = "none"}
            widget.content["segment_icon_" .. i] = icon.kind == "material" and icon.value or "content/ui/materials/base/ui_default_base"
            widget.content["segment_glyph_" .. i] = icon.kind == "unicode" and icon.value or ""
            widget.content["segment_icon_visible_" .. i] = icon.kind == "material" and w >= 12
            widget.content["segment_glyph_visible_" .. i] = icon.kind == "unicode" and w >= 12
            icon_style.offset = {x + math.floor((w - icon_size) / 2), bar_y + math.floor((bar_h - icon_size) / 2), 11}
            icon_style.size = {icon_size, icon_size}
            glyph_style.offset = {x, bar_y, 11}
            glyph_style.size = {w, bar_h}
            if i < visible_total then
                divider.offset = {x + w, bar_y + 1, 10}
                divider.size = {1, bar_h - 2}
                divider.color = divider_color
                x = x + w + 1
                available = bar_x + bar_w - x
            else
                divider.size = {0, 0}
                divider.color = {0, 0, 0, 0}
                x = x + w
                available = bar_x + bar_w - x
            end
        else
            style.size = {0, 0}
            style.color = {0, 0, 0, 0}
            highlight.size = {0, 0}
            highlight.color = {0, 0, 0, 0}
            divider.size = {0, 0}
            divider.color = {0, 0, 0, 0}
            widget.content["segment_icon_visible_" .. i] = false
            widget.content["segment_glyph_visible_" .. i] = false
        end
    end

    widget.style.warning_zone.offset = {goal_x, bar_y, 6}
    widget.style.warning_zone.size = {math.max(0, bar_x + bar_w - goal_x), bar_h}
    widget.style.goal_marker.offset = {goal_x - 1, bar_y + bar_h - 1, 11}
    widget.style.goal_label.offset = {goal_x - 23, bar_y - 14, 12}
    return summary_score(values)
end

local compact_widget_by_section = {section_defense = "compact_defense", section_offense = "compact_offense", section_team = "compact_team"}

-- Synchronizes Defense, Offense, and Teamplay summary widgets.
local function update_section_summaries(self, detail_summaries, compact_summaries)
    compact_summaries = compact_summaries or detail_summaries
    for _, section in ipairs(metric_sections) do
        local compact_values = compact_summaries[section.widget] or {}
        local compact_widget = self._widgets_by_name[compact_widget_by_section[section.widget]]
        if section.widget == "section_team" then
            local met = 0
            for _, value in ipairs(compact_values) do
                if value.state == "met" then met = met + 1 end
            end
            local total = #compact_values
            local all_goals_met = total > 0 and met == total
            local one_goal_short = total > 0 and met == total - 1
            compact_widget.content.praise = all_goals_met and "OUTSTANDING!" or (one_goal_short and "IMPRESSIVE!" or "")
            compact_widget.content.score = total > 0 and string.format("%d/%d goals", met, total) or "No goals"
            -- Preserve the centered three-line stack when praise is present.
            -- Without praise, center TEAMPLAY and its goal count as two lines.
            local has_praise = compact_widget.content.praise ~= ""
            compact_widget.style.section_label.offset[2] = has_praise and 33 or 20
            compact_widget.style.score.offset[2] = has_praise and 60 or 47
        else
            apply_summary_widget(compact_widget, section, compact_values, true)
        end
    end
end

-- One-match role evaluation used by the visual boards.
local function role_summary_for_entry(entry, role, focus_account_id)
    local summaries = {}
    local category_scores = {}
    for _, section in ipairs(metric_sections) do
        local values = {}
        for _, metric in ipairs(active_section_metrics(section)) do
            local result = metric_result_for_entry(entry, metric, section.direction, focus_account_id)
            local target = metric_target(role, metric)
            local state, achievement, hidden = summary_state_for_result(section.direction, result, target, metric.source)
            if state then
                values[#values + 1] = {
                    state = state,
                    achievement = achievement,
                    is_best = result.is_best == true,
                    team_rank = result.team_rank,
                    rank_count = result.rank_count,
                    text = metric.text,
                    raw = result.raw_display or format_raw_metric(result.mine, result.averaged == true),
                    share = result.share,
                    target = target,
                    icon = resolve_catalogue_icon(metric.icon_index),
                    hidden = hidden == true,
                }
            end
        end
        summaries[section.widget] = values
        category_scores[#category_scores + 1] = summary_score(values)
    end
    local total = 0
    for _, value in ipairs(category_scores) do total = total + value end
    return summaries, #category_scores > 0 and total / #category_scores or 0
end

local function most_favorable_role(summary_builder)
    local best_key, best_role, best_summaries, best_score
    for _, role_key in ipairs(role_order) do
        local role = selected_role_profile(role_key)
        local summaries, score = summary_builder(role)
        if best_score == nil or score > best_score then
            best_key, best_role, best_summaries, best_score = role_key, role, summaries, score
        end
    end
    return best_key, best_role, best_summaries, best_score
end

-- Rank roles to determine the displayed best and second role.
local function ranked_role_keys(summary_builder)
    local ranked = {}
    for _, role_key in ipairs(role_order) do
        local role = selected_role_profile(role_key)
        local _, score = summary_builder(role)
        ranked[#ranked + 1] = {key = role_key, score = score or 0}
    end
    table.sort(ranked, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return tostring(a.key) < tostring(b.key)
    end)
    return ranked
end

-- Populate player names, class icons, and role labels for Victory and History.
local function populate_compact_players(self, entry)
    local players = ordered_players(entry)
    local count = math.min(4, #players)
    local slot_width = 180
    local slot_step = 185
    local player_area_x = 270
    local player_area_width = 750
    local total_width = count > 0 and (slot_width + (count - 1) * slot_step) or 0
    local start_x = count > 0 and math.floor(player_area_x + (player_area_width - total_width) / 2 + 0.5) or player_area_x
    local base_x = {270, 455, 640, 825}
    for i = 1, 4 do
        local widget = self._widgets_by_name["compact_player_" .. i]
        local player = players[i]
        if widget then
            widget.offset = widget.offset or {0, 0, 0}
            widget.offset[1] = player and ((start_x + (i - 1) * slot_step) - base_x[i]) or 0
        end
        if widget and player then
            local ranked = ranked_role_keys(function(candidate_role)
                return role_summary_for_entry(entry, candidate_role, player.account_id)
            end)
            local primary_key = ranked[1] and ranked[1].key or nil
            local secondary_key = ranked[2] and ranked[2].key or nil
            local primary_label = canonical_role_labels[primary_key] or "Operative"
            local secondary_label = secondary_key and canonical_role_labels[secondary_key] or nil
            local detail = primary_label
            if secondary_label and secondary_label ~= primary_label then
                detail = string.format("%s / %s", primary_label, secondary_label)
            end
            local is_local = mod:is_local_history_player(player)
            local archetype_name = player.archetype_name or player.archetype
            local archetype_symbol = archetype_name and UISettings.archetype_font_icon and UISettings.archetype_font_icon[archetype_name]
            widget.content.icon = tostring(player.string_symbol or archetype_symbol or "")
            widget.content.name = tostring(player.name or player.account_name or "Unknown")
            widget.content.detail = detail
            widget.style.icon.text_color = is_local and Color.terminal_text_header(255, true) or Color.white(255, true)
            widget.style.name.text_color = is_local and Color.terminal_text_header(255, true) or Color.white(255, true)
            widget.style.detail.text_color = is_local and Color.terminal_text_body(255, true) or Color.terminal_text_body(220, true)
        elseif widget then
            widget.content.icon = ""
            widget.content.name = ""
            widget.content.detail = ""
            widget.style.icon.text_color = Color.white(255, true)
            widget.style.name.text_color = Color.white(255, true)
            widget.style.detail.text_color = Color.terminal_text_body(220, true)
        end
    end
end

local function single_line_player_name(value, max_characters)
    local name = tostring(value or "Unknown"):gsub("[%c]", " "):gsub("%s+", " ")
    max_characters = math.max(2, tonumber(max_characters) or 14)
    local offsets = {}
    local byte_index = 1
    while byte_index <= #name do
        offsets[#offsets + 1] = byte_index
        local lead = string.byte(name, byte_index)
        local width = lead and (lead < 0x80 and 1 or lead < 0xE0 and 2 or lead < 0xF0 and 3 or 4) or 1
        byte_index = byte_index + width
    end
    if #offsets <= max_characters then
        return name
    end
    return string.sub(name, 1, offsets[max_characters] - 1) .. "…"
end

local function damage_source_detail(value, segment_height, detail_width)
    local detail = tostring(value or ""):gsub("[%c]", " "):gsub("%s+", " ")
    if detail == "" then
        return ""
    end
    local line_limit = math.max(8, math.floor((tonumber(detail_width) or 79) / 4.2))
    if (tonumber(segment_height) or 0) < 34 then
        return single_line_player_name(detail, line_limit)
    end

    local parts = {}
    for part in string.gmatch(detail, "[^,]+") do
        part = part:gsub("^%s+", ""):gsub("%s+$", "")
        if part ~= "" then
            parts[#parts + 1] = part
        end
    end
    if #parts < 2 then
        return single_line_player_name(detail, line_limit)
    end

    local first_line = parts[1]
    local next_part = 2
    while next_part <= #parts do
        local candidate = first_line .. ", " .. parts[next_part]
        if #candidate > line_limit then
            break
        end
        first_line = candidate
        next_part = next_part + 1
    end
    if next_part > #parts then
        return single_line_player_name(first_line, line_limit)
    end

    local second_parts = {}
    for i = next_part, #parts do
        second_parts[#second_parts + 1] = parts[i]
    end
    return single_line_player_name(first_line, line_limit)
        .. "\n" .. single_line_player_name(table.concat(second_parts, ", "), line_limit)
end


-- Set material or glyph icons on the production compact widgets.
local function set_prototype_icon(widget, prefix, icon)
    icon = icon or {kind = "none"}
    widget.content[prefix .. "_icon"] = icon.kind == "material" and icon.value or "content/ui/materials/base/ui_default_base"
    widget.content[prefix .. "_glyph"] = icon.kind == "unicode" and icon.value or ""
    widget.content[prefix .. "_icon_visible"] = icon.kind == "material"
    widget.content[prefix .. "_glyph_visible"] = icon.kind == "unicode"
end

local offense_pie_base_x = {
    damage_total_icon = 154, damage_total_glyph = 154, damage_total_title = 178,
    damage_total_pct_shadow_1 = 161, damage_total_pct_shadow_2 = 163,
    damage_total_pct_shadow_3 = 161, damage_total_pct_shadow_4 = 163,
    damage_total_pct = 162,
    damage_total_raw_shadow_1 = 145, damage_total_raw_shadow_2 = 147,
    damage_total_raw_shadow_3 = 145, damage_total_raw_shadow_4 = 147,
    damage_total_raw = 146,
    damage_pie_outer_glow = 146, damage_pie_outer_rim = 148,
    damage_pie_background = 149,
}

local function populate_defense_prototype(self, entry, role)
    local widget = self._widgets_by_name.compact_defense_prototype
    if not widget then return end
    local all_counter_metrics = {
        {source = "times_downed", icon = metric_sections[1].metrics[2].icon_index},
        {source = "times_disabled", icon = metric_sections[1].metrics[3].icon_index},
        {source = "deaths", icon = metric_sections[1].metrics[4].icon_index},
    }
    local counter_metrics = {}
    for _, item in ipairs(all_counter_metrics) do
        if mod:is_metric_enabled(item.source) then counter_metrics[#counter_metrics + 1] = item end
    end
    local counter_x, counter_w, counter_gap = 617, 108, 7
    local counters_w = #counter_metrics > 0 and (#counter_metrics * counter_w + (#counter_metrics - 1) * counter_gap) or 0
    local first_counter_x
    local mandatory_shift = 0
    if #counter_metrics < 3 then
        -- Center the complete surviving Defense group in the content area.
        -- The mandatory block spans x=116..615; optional counters retain
        -- their natural 108 px slots and a 10 px separation from that block.
        local content_left, content_right = 125, 970
        local mandatory_left, mandatory_w = 116, 499
        local complete_w = mandatory_w + (#counter_metrics > 0 and (10 + counters_w) or 0)
        local complete_x = content_left + (content_right - content_left - complete_w) / 2
        mandatory_shift = complete_x - mandatory_left
        first_counter_x = complete_x + mandatory_w + 10
    else
        local counter_region_w = 970 - counter_x
        first_counter_x = counter_x + (counter_region_w - counters_w) / 2
    end

    local chart_x, chart_y, chart_w, chart_h, chart_cap = 154 + mandatory_shift, 62, 320, 82, 50
    local bar_w, bar_gap = 42, 34
    local bars_w = bar_w * 4 + bar_gap * 3
    local first_bar_x = chart_x + (chart_w - bars_w) / 2
    local source_x, source_w = 494 + mandatory_shift, 38
    local source_detail_x = source_x + source_w + 4
    local source_detail_right = #counter_metrics > 0 and first_counter_x - 4 or 960
    local source_detail_w = math.max(79, math.floor(source_detail_right - source_detail_x))
    local source_y, source_h = 30, chart_y + chart_h - 30
    local players = ordered_players(entry)
    local history_no_data = self._iy_history_host_attached == true
    local local_player
    for _, player in ipairs(players) do
        if mod:is_local_history_player(player) then local_player = player break end
    end
    local display_players = {}
    local teammate_slot = 1
    for _, player in ipairs(players) do
        if player ~= local_player and teammate_slot <= 3 then
            display_players[teammate_slot] = player
            teammate_slot = teammate_slot + 1
        end
    end
    -- The source breakdown belongs to the local player's bar, so its anchor
    -- must remain slot 4 even after the live roster has been torn down.
    display_players[4] = local_player
    set_prototype_icon(widget, "damage", resolve_catalogue_icon(metric_sections[1].metrics[1].icon_index))
    widget.style.damage_icon.offset[1] = chart_x
    widget.style.damage_glyph.offset[1] = chart_x
    widget.style.damage_title.offset[1] = chart_x + 24
    for _, id in ipairs({"grid_50", "grid_25", "grid_0"}) do widget.style[id].offset[1] = chart_x end
    widget.style.grid_50_text.offset[1] = chart_x - 38
    widget.style.grid_25_text.offset[1] = chart_x - 38
    local goal = tonumber(role.targets.damage_taken) or 25
    local goal_h = math.max(0, math.min(chart_cap, goal)) / chart_cap * chart_h
    for i = 1, 4 do
        local player = display_players[i]
        local result = player and metric_result_for_entry(entry, metric_sections[1].metrics[1], "lower", player.account_id) or nil
        local share = result and tonumber(result.share) or nil
        local raw = result and tonumber(result.mine) or nil
        local visible = math.max(0, math.min(chart_cap, share or 0))
        local result_h = visible / chart_cap * chart_h
        local is_local = player and mod:is_local_history_player(player)
        local color = muted_comparison_color(close_grey_green)
        local is_best = false
        if result then
            if team_comparison_enabled() and is_local then
                -- Team comparison judges only the local player. Teammates stay
                -- neutral so the board does not visually grade other people.
                color = result_display_color(result, color, result.total > 0)
                is_best = result_is_gold(result, result.total > 0)
            elseif is_local then
                local _, _, evaluated = fulfillment("lower", share or 0, goal, result.total <= 0)
                color = evaluated
                local best_share
                for _, comparison_player in ipairs(players) do
                    local comparison_result = metric_result_for_entry(entry, metric_sections[1].metrics[1], "lower", comparison_player.account_id)
                    local comparison_share = comparison_result and tonumber(comparison_result.share) or nil
                    if comparison_share ~= nil then best_share = best_share == nil and comparison_share or math.min(best_share, comparison_share) end
                end
                is_best = best_share ~= nil and share ~= nil and math.abs(share - best_share) < 0.001
                if is_best then color = copy_color(gold_fill) end
            end
        end
        local bx = first_bar_x + (i - 1) * (bar_w + bar_gap)
        local cx = bx + bar_w / 2
        local goal_y = chart_y + chart_h - goal_h
        local result_y = chart_y + chart_h - result_h
        local frame_color = is_best and copy_color(gold_fill) or copy_color(close_grey_green)
        local stripe_color = is_best and {120, gold_fill[2], gold_fill[3], gold_fill[4]} or {95, 90, 112, 92}
        local show_goal_frame = is_local and result_h <= goal_h
        widget.style["goal_stripes_" .. i].offset = {bx, goal_y, 7}; widget.style["goal_stripes_" .. i].size = {show_goal_frame and bar_w or 0, show_goal_frame and goal_h or 0}; widget.style["goal_stripes_" .. i].color = stripe_color
        widget.style["goal_l_" .. i].offset = {bx, goal_y, 8}; widget.style["goal_l_" .. i].size = {show_goal_frame and 1 or 0, show_goal_frame and goal_h or 0}; widget.style["goal_l_" .. i].color = frame_color
        widget.style["goal_r_" .. i].offset = {bx + bar_w - 1, goal_y, 8}; widget.style["goal_r_" .. i].size = {show_goal_frame and 1 or 0, show_goal_frame and goal_h or 0}; widget.style["goal_r_" .. i].color = frame_color
        widget.style["goal_t_" .. i].offset = {bx, goal_y, 8}; widget.style["goal_t_" .. i].size = {show_goal_frame and bar_w or 0, show_goal_frame and 1 or 0}; widget.style["goal_t_" .. i].color = frame_color
        widget.style["result_" .. i].offset = {bx + 1, result_y, 9}; widget.style["result_" .. i].size = {bar_w - 2, result_h}; widget.style["result_" .. i].color = color
        widget.style["result_highlight_" .. i].offset = {bx + 1, result_y, 10}; widget.style["result_highlight_" .. i].size = {bar_w - 2, result_h > 0 and 2 or 0}
        local overflow = share and share > chart_cap
        widget.style["overflow_" .. i].offset = {bx + 1, chart_y - 11, 11}; widget.style["overflow_" .. i].size = {bar_w - 2, overflow and 8 or 0}; widget.style["overflow_" .. i].color = color
        widget.content["raw_" .. i] = not result and history_no_data and is_local and "NO DATA"
            or (result and tonumber(result.total or 0) > 0 and format_raw_metric(raw, false) or (is_local and "--" or ""))
        widget.content["name_" .. i] = player and single_line_player_name(player.name or player.account_name, 11) or "—"
        widget.content["pct_" .. i] = result and tonumber(result.total or 0) > 0 and string.format("%.1f%%", share) or (result and "--" or "")
        widget.style["raw_" .. i].font_size = not result and history_no_data and is_local and 8 or 11
        widget.style["raw_" .. i].text_color = color
        widget.style["name_" .. i].text_color = color
        widget.style["pct_" .. i].text_color = color
        widget.style["raw_" .. i].offset = {cx - 42, overflow and (chart_y - 31) or math.max(chart_y - 27, result_y - 20), 12}
        widget.style["name_" .. i].offset[1] = cx - 36
        widget.style["pct_" .. i].offset[1] = cx - 34
    end

    local index = row_index(entry.rows or {})
    local source_rows = {
        area = "iy_damage_taken_area",
        melee = "iy_damage_taken_melee",
        ranged = "iy_damage_taken_ranged",
        other = "iy_damage_taken_other",
    }
    local source_detail_rows = {
        area = "iy_damage_taken_area_sources",
        melee = "iy_damage_taken_melee_sources",
        ranged = "iy_damage_taken_ranged_sources",
        other = "iy_damage_taken_other_sources",
    }
    local source_order = {"area", "melee", "ranged", "other"}
    local has_source_data = local_player ~= nil
    for _, category in ipairs(source_order) do
        has_source_data = has_source_data and index[source_rows[category]] ~= nil
    end

    local source_values, source_total = {}, 0
    if has_source_data then
        for _, category in ipairs(source_order) do
            local value = math.max(0, source_score(index, source_rows[category], local_player.account_id))
            source_values[category] = value
            source_total = source_total + value
        end
    end
    local show_source_breakdown = has_source_data and source_total > 0
    local source_layout = damage_source_layout(source_values, source_order, source_h, 23)
    widget.content.source_area_label = "Area of Effect"
    widget.content.source_melee_label = "Melee Damage"
    widget.content.source_ranged_label = "Ranged Damage"
    widget.content.source_other_label = "Other Damage"
    local source_details = {}
    for _, category in ipairs(source_order) do
        source_details[category] = local_player and source_text(index, source_detail_rows[category], local_player.account_id) or ""
        widget.content["source_" .. category .. "_detail"] = ""
    end

    local running_bottom = chart_y + chart_h
    for _, category in ipairs(source_order) do
        widget.style["source_" .. category].offset = {source_x, chart_y + chart_h, 10}
        widget.style["source_" .. category].size = {0, 0}
        widget.content["source_" .. category .. "_value"] = ""
        widget.style["source_" .. category .. "_value"].text_color = {0, 0, 0, 0}
        widget.style["source_" .. category .. "_label"].text_color = {0, 0, 0, 0}
        widget.style["source_" .. category .. "_detail"].text_color = {0, 0, 0, 0}
    end
    local source_alpha_by_rank = {255, 205, 155, 105}
    for rank, item in ipairs(source_layout) do
        running_bottom = running_bottom - item.height
        local category = item.category
        widget.style["source_" .. category].offset = {source_x, running_bottom, 10}
        widget.style["source_" .. category].size = {source_w, item.height}
        widget.style["source_" .. category].color = {source_alpha_by_rank[rank] or 105, 177, 189, 181}
        widget.content["source_" .. category .. "_value"] = format_raw_metric(item.value, false)
        local value_y = running_bottom + item.height / 2 - 7
        local allow_two_lines = item.height >= 34
        local label_y = running_bottom + item.height / 2 - (allow_two_lines and 16 or 10)
        widget.style["source_" .. category .. "_value"].offset = {source_x, value_y, 14}
        widget.style["source_" .. category .. "_label"].offset = {source_detail_x, label_y, 14}
        widget.style["source_" .. category .. "_label"].size = {source_detail_w, 11}
        widget.style["source_" .. category .. "_detail"].offset = {source_detail_x, label_y + 11, 14}
        widget.style["source_" .. category .. "_detail"].size = {source_detail_w, allow_two_lines and 20 or 9}
        widget.content["source_" .. category .. "_detail"] = damage_source_detail(source_details[category], item.height, source_detail_w)
        local source_alpha = source_alpha_by_rank[rank] or 105
        widget.style["source_" .. category .. "_value"].text_color = {255, 28, 36, 31}
        widget.style["source_" .. category .. "_label"].text_color = Color.terminal_text_body(source_alpha, true)
        widget.style["source_" .. category .. "_detail"].text_color = Color.terminal_text_body(source_alpha, true)
    end
    local local_bar_x = first_bar_x + 3 * (bar_w + bar_gap)
    local connector_start_x = local_bar_x + bar_w
    local bracket_x = source_x - 7
    local connector_y = chart_y + chart_h - goal_h / 2 - 1
    local connector_w = math.max(0, bracket_x - connector_start_x)
    widget.style.source_connector.offset = {connector_start_x, connector_y, 12}
    widget.style.source_connector.size = {show_source_breakdown and connector_w or 0, 2}
    widget.style.source_bracket_top.offset = {bracket_x, source_y, 12}
    widget.style.source_bracket_top.size = {show_source_breakdown and 5 or 0, 2}
    widget.style.source_bracket_right.offset = {bracket_x, source_y, 12}
    widget.style.source_bracket_right.size = {2, show_source_breakdown and source_h or 0}
    widget.style.source_bracket_bottom.offset = {bracket_x, chart_y + chart_h - 2, 12}
    widget.style.source_bracket_bottom.size = {show_source_breakdown and 5 or 0, 2}
    local blocked_enabled = mod:is_metric_enabled("attacks_blocked")
    local blocked_available = blocked_enabled and local_player ~= nil and index.attacks_blocked ~= nil
    local blocked = blocked_available and source_score(index, "attacks_blocked", local_player.account_id) or nil
    widget.content.source_summary = show_source_breakdown and blocked_enabled
        and (blocked_available and (blocked > 0 and format_raw_metric(blocked, false) or "--") or (history_no_data and "NO DATA" or "--")) or ""
    local blocked_result = blocked_available and metric_result_for_entry(entry, {source = "attacks_blocked"}, "higher", local_player.account_id) or nil
    local blocked_is_best = result_is_gold(blocked_result, blocked_result and tonumber(blocked_result.total or 0) > 0)
    local blocked_color = blocked_available and (blocked_is_best and copy_color(gold_fill) or copy_color(green)) or copy_color(grey)
    widget.style.source_summary.font_size = blocked_available and 20 or (history_no_data and 9 or 20)
    widget.style.source_summary_title.offset[1] = source_x - 2
    widget.style.source_summary.offset[1] = source_x - 2
    widget.style.source_summary_title.text_color = show_source_breakdown and blocked_enabled and blocked_color or {0, 0, 0, 0}
    widget.style.source_summary.text_color = show_source_breakdown and blocked_enabled and blocked_color or {0, 0, 0, 0}

    -- The heading follows the local player's selected presentation scheme.
    -- Goal-oriented retains the historical white/gold treatment; team
    -- comparison uses the local player's actual rank color.
    local local_damage_result = local_player and metric_result_for_entry(entry, metric_sections[1].metrics[1], "lower", local_player.account_id) or nil
    local damage_heading_color = Color.white(255, true)
    if local_damage_result then
        if team_comparison_enabled() then
            damage_heading_color = result_display_color(
                local_damage_result,
                damage_heading_color,
                tonumber(local_damage_result.total or 0) > 0
            )
        else
            local local_share = tonumber(local_damage_result.share) or 0
            local best_share
            for _, comparison_player in ipairs(players) do
                local comparison_result = metric_result_for_entry(entry, metric_sections[1].metrics[1], "lower", comparison_player.account_id)
                local comparison_share = comparison_result and tonumber(comparison_result.share) or nil
                if comparison_share ~= nil then
                    best_share = best_share == nil and comparison_share or math.min(best_share, comparison_share)
                end
            end
            if tonumber(local_damage_result.total or 0) > 0 and best_share ~= nil and math.abs(local_share - best_share) < 0.001 then
                damage_heading_color = copy_color(gold_fill)
            end
        end
    end
    widget.style.damage_title.text_color = damage_heading_color
    widget.style.damage_icon.color = damage_heading_color
    widget.style.damage_glyph.text_color = damage_heading_color

    local counter_chart_y, counter_chart_h = 62, 82
    local comparison_bar_w, own_bar_w, mini_gap = 10, 38, 4
    local comparison_color = muted_comparison_color(close_grey_green)
    for i = 1, 3 do
        local item = counter_metrics[i]
        if item then
        set_prototype_icon(widget, "counter_" .. i, resolve_catalogue_icon(item.icon))
        widget.content["counter_title_" .. i] = item.source == "times_downed" and "Downed" or (item.source == "times_disabled" and "Disabled" or "Deaths")
        local metric
        for _, candidate in ipairs(metric_sections[1].metrics) do
            if candidate.source == item.source then metric = candidate break end
        end

        local row_available = source_recorded(index, item.source)
        local team_total = 0
        local best_raw, worst_raw
        local best_share, worst_share = 0, 0
        for _, player in ipairs(players) do
            local value = source_score(index, item.source, player.account_id)
            team_total = team_total + value
            best_raw = best_raw == nil and value or math.min(best_raw, value)
            worst_raw = worst_raw == nil and value or math.max(worst_raw, value)
        end
        if team_total > 0 then
            best_share = (best_raw or 0) / team_total * 100
            worst_share = (worst_raw or 0) / team_total * 100
        end

        local raw = row_available and local_player and source_score(index, item.source, local_player.account_id) or nil
        local share = raw ~= nil and (team_total > 0 and raw / team_total * 100 or 0) or nil
        local target = tonumber(role.targets[item.source]) or 25
        local result = metric and metric_result_for_entry(entry, metric, "lower", local_player and local_player.account_id) or nil
        local color = copy_color(grey)
        if result then
            local _, _, evaluated = fulfillment("lower", share or 0, target, team_total <= 0)
            color = evaluated
        end
        local is_best = result_is_gold(result, team_total > 0)
        color = result_display_color(result, color, team_total > 0)

        -- Count metrics use a raw-value scale with a minimum span of four. This
        -- prevents a single event from filling the entire chart while preserving
        -- direct Best / You / Worst comparison. Convert the percentage goal to
        -- its equivalent raw team count for the goal frame.
        local raw_scale_max = math.max(4, worst_raw or 0, raw or 0)
        local visible_best = math.min(raw_scale_max, math.max(0, best_raw or 0)) / raw_scale_max * counter_chart_h
        local visible_own = math.min(raw_scale_max, math.max(0, raw or 0)) / raw_scale_max * counter_chart_h
        local visible_worst = math.min(raw_scale_max, math.max(0, worst_raw or 0)) / raw_scale_max * counter_chart_h
        local min_h = 3
        visible_best = math.max(min_h, visible_best)
        visible_worst = math.max(min_h, visible_worst)
        if raw ~= nil then visible_own = math.max(min_h, visible_own) end
        -- Goal frames represent the configured team-share target, not the
        -- current raw event count. A 25% goal therefore always occupies half
        -- of this 0-50% mini-chart, even when only one event occurred.
        local goal_h = math.min(50, math.max(0, target)) / 50 * counter_chart_h

        local x = first_counter_x + (i - 1) * (counter_w + counter_gap)
        local group_w = comparison_bar_w * 2 + own_bar_w + mini_gap * 2
        local group_x = x + (counter_w - group_w) / 2
        local best_x = group_x
        local own_x = best_x + comparison_bar_w + mini_gap
        local worst_x = own_x + own_bar_w + mini_gap
        local own_center_x = own_x + own_bar_w / 2
        local title_w = item.source == "times_disabled" and 64 or (item.source == "times_downed" and 58 or 50)
        local heading_x = own_center_x - (17 + 5 + title_w) / 2
        local base_y = counter_chart_y + counter_chart_h

        widget.style["counter_icon_" .. i].offset = {heading_x, 8, 20}
        widget.style["counter_glyph_" .. i].offset = {heading_x, 6, 20}
        widget.style["counter_title_" .. i].offset = {heading_x + 22, 6, 12}
        widget.style["counter_title_" .. i].size[1] = title_w
        widget.style["counter_best_label_" .. i].offset[1] = best_x - 12
        widget.style["counter_worst_label_" .. i].offset[1] = worst_x - 14
        widget.style["counter_best_label_" .. i].text_color = {190, 126, 148, 126}
        widget.style["counter_worst_label_" .. i].text_color = {190, 126, 148, 126}
        widget.style["counter_baseline_" .. i].offset = {group_x - 3, base_y, 5}
        widget.style["counter_baseline_" .. i].size = {group_w + 6, 1}
        widget.style["counter_pct_" .. i].offset[1] = x

        widget.style["counter_best_bar_" .. i].offset = {best_x, base_y - visible_best, 7}
        widget.style["counter_best_bar_" .. i].size = {comparison_bar_w, visible_best}
        widget.style["counter_best_bar_" .. i].color = comparison_color
        widget.style["counter_worst_bar_" .. i].offset = {worst_x, base_y - visible_worst, 7}
        widget.style["counter_worst_bar_" .. i].size = {comparison_bar_w, visible_worst}
        widget.style["counter_worst_bar_" .. i].color = comparison_color
        widget.style["counter_own_bar_" .. i].offset = {own_x + 1, base_y - visible_own, 9}
        widget.style["counter_own_bar_" .. i].size = {own_bar_w - 2, visible_own}
        widget.style["counter_own_bar_" .. i].color = color
        widget.style["counter_own_highlight_" .. i].offset = {own_x + 1, base_y - visible_own, 10}
        widget.style["counter_own_highlight_" .. i].size = {own_bar_w - 2, visible_own > 0 and 2 or 0}
        widget.style["counter_own_highlight_" .. i].color = is_best and copy_color(gold_highlight) or {150, 235, 245, 235}

        local goal_y = base_y - goal_h
        local frame_color = is_best and copy_color(gold_fill) or copy_color(close_grey_green)
        local stripe_color = is_best and {120, gold_fill[2], gold_fill[3], gold_fill[4]} or {95, 90, 112, 92}
        local show_goal_frame = visible_own <= goal_h
        widget.style["counter_goal_stripes_" .. i].offset = {own_x, goal_y, 8}
        widget.style["counter_goal_stripes_" .. i].size = {show_goal_frame and own_bar_w or 0, show_goal_frame and goal_h or 0}
        widget.style["counter_goal_stripes_" .. i].color = stripe_color
        widget.style["counter_goal_l_" .. i].offset = {own_x, goal_y, 11}
        widget.style["counter_goal_l_" .. i].size = {show_goal_frame and 1 or 0, show_goal_frame and goal_h or 0}
        widget.style["counter_goal_l_" .. i].color = frame_color
        widget.style["counter_goal_r_" .. i].offset = {own_x + own_bar_w - 1, goal_y, 11}
        widget.style["counter_goal_r_" .. i].size = {show_goal_frame and 1 or 0, show_goal_frame and goal_h or 0}
        widget.style["counter_goal_r_" .. i].color = frame_color
        widget.style["counter_goal_t_" .. i].offset = {own_x, goal_y, 11}
        widget.style["counter_goal_t_" .. i].size = {show_goal_frame and own_bar_w or 0, show_goal_frame and 1 or 0}
        widget.style["counter_goal_t_" .. i].color = frame_color

        local has_events = row_available and team_total > 0
        if not has_events then
            widget.style["counter_best_bar_" .. i].size = {0, 0}
            widget.style["counter_own_bar_" .. i].size = {0, 0}
            widget.style["counter_own_highlight_" .. i].size = {0, 0}
            widget.style["counter_worst_bar_" .. i].size = {0, 0}
            widget.style["counter_goal_stripes_" .. i].size = {0, 0}
            widget.style["counter_goal_l_" .. i].size = {0, 0}
            widget.style["counter_goal_r_" .. i].size = {0, 0}
            widget.style["counter_goal_t_" .. i].size = {0, 0}
        end
        widget.content["counter_best_raw_" .. i] = has_events and format_raw_metric(best_raw, false) or ""
        widget.content["counter_own_raw_" .. i] = not row_available
            and (history_no_data and "NO DATA" or "--") or (has_events and format_raw_metric(raw, false) or "--")
        widget.content["counter_worst_raw_" .. i] = has_events and format_raw_metric(worst_raw, false) or ""
        widget.content["counter_pct_" .. i] = not row_available and "" or (has_events and string.format("%.1f%%", share or 0) or "--")
        widget.style["counter_own_raw_" .. i].font_size = row_available and 11 or (history_no_data and 8 or 11)
        widget.style["counter_own_raw_" .. i].text_color = color
        widget.style["counter_pct_" .. i].text_color = color
        widget.style["counter_title_" .. i].text_color = color
        widget.style["counter_icon_" .. i].color = color
        widget.style["counter_glyph_" .. i].text_color = color
        widget.style["counter_best_raw_" .. i].offset = {best_x - 6, math.max(counter_chart_y - 16, base_y - visible_best - 15), 14}
        widget.style["counter_own_raw_" .. i].offset = {own_x - 6, math.max(counter_chart_y - 16, base_y - visible_own - 15), 14}
        widget.style["counter_worst_raw_" .. i].offset = {worst_x - 6, math.max(counter_chart_y - 16, base_y - visible_worst - 15), 14}
        else
            widget.content["counter_" .. i .. "_icon_visible"] = false
            widget.content["counter_" .. i .. "_glyph_visible"] = false
            widget.content["counter_title_" .. i] = ""
            widget.content["counter_best_raw_" .. i] = ""
            widget.content["counter_own_raw_" .. i] = ""
            widget.content["counter_worst_raw_" .. i] = ""
            widget.content["counter_pct_" .. i] = ""
            widget.style["counter_title_" .. i].text_color = {0, 0, 0, 0}
            widget.style["counter_best_label_" .. i].text_color = {0, 0, 0, 0}
            widget.style["counter_worst_label_" .. i].text_color = {0, 0, 0, 0}
            widget.style["counter_baseline_" .. i].size = {0, 0}
            for _, id in ipairs({"counter_best_bar_", "counter_own_bar_", "counter_own_highlight_", "counter_worst_bar_", "counter_goal_stripes_", "counter_goal_l_", "counter_goal_r_", "counter_goal_t_"}) do
                widget.style[id .. i].size = {0, 0}
            end
        end
    end

end


-- Populate the production compact Offense widget.
-- Includes Damage Total radial and all offense category bars.
local function populate_offense_prototype(self, entry, role)
    local widget = self._widgets_by_name.compact_offense_prototype
    if not widget then return end

    local offense = metric_sections[2]
    local local_player
    local players = ordered_players(entry)
    local score_index = row_index(entry.rows)
    local history_no_data = self._iy_history_host_attached == true
    for _, player in ipairs(players) do
        if mod:is_local_history_player(player) then
            local_player = player
            break
        end
    end

    local all_quality_metrics = {
        {source = "weakspot_hit_percent", denominator = "damaging_hits", title = "Weakspot hit %"},
        {source = "critical_hits", denominator = "damaging_hits", title = "Critical hits %"},
        {source = "accuracy", denominator = "ranged_shots_fired", title = "Ranged accuracy"},
    }
    local quality_metrics = {}
    for _, metric in ipairs(all_quality_metrics) do
        if mod:is_metric_enabled(metric.source) then quality_metrics[#quality_metrics + 1] = metric end
    end
    local quality_visible = #quality_metrics > 0
    local active_offense = active_section_metrics(offense)
    local metric_list = {}
    for _, metric in ipairs(active_offense) do
        if metric.source ~= "damage_dealt" then metric_list[#metric_list + 1] = metric end
    end
    local slot_w, bar_w = 55, 36
    local graph_w = #metric_list * slot_w
    local content_left = 125
    local content_right = quality_visible and 715 or 970
    local pie_w, pie_gap = 146, 35
    local complete_w = pie_w + (#metric_list > 0 and (pie_gap + graph_w) or 0)
    local complete_x = content_left + math.max(0, (content_right - content_left - complete_w) / 2)
    local pie_shift = complete_x - 149

    -- The Offense background reclaims Combat Quality's full width when that
    -- separate panel is hidden. The left label rail remains unchanged.
    local offense_w = quality_visible and 735 or 970
    widget.style.background.size[1] = offense_w
    widget.style.bottom_divider.size[1] = offense_w

    for id, x in pairs(offense_pie_base_x) do widget.style[id].offset[1] = x + pie_shift end

    set_prototype_icon(widget, "damage_total", resolve_catalogue_icon(offense.metrics[1].icon_index))

    local function set_material_colour(target, source, intensity)
        intensity = intensity or 1
        target[1] = math.min(((source[2] or 255) / 255) * intensity, 2)
        target[2] = math.min(((source[3] or 255) / 255) * intensity, 2)
        target[3] = math.min(((source[4] or 255) / 255) * intensity, 2)
        target[4] = 1
    end

    local damage_total_metric = offense.metrics[1]
    local damage_total_result = local_player and metric_result_for_entry(entry, damage_total_metric, "higher", local_player.account_id) or nil
    local damage_total_share = damage_total_result and tonumber(damage_total_result.share) or nil
    local damage_total_raw = damage_total_result and tonumber(damage_total_result.mine) or nil
    local damage_total_target = tonumber(role.targets[damage_total_metric.source]) or 25
    local damage_total_color = copy_color(grey)
    if damage_total_result then
        local _, _, evaluated = fulfillment("higher", damage_total_share or 0, damage_total_target, tonumber(damage_total_result.total or 0) <= 0)
        damage_total_color = evaluated
    end
    local damage_total_best = result_is_gold(damage_total_result, damage_total_result and tonumber(damage_total_result.total or 0) > 0)
    damage_total_color = result_display_color(damage_total_result, damage_total_color, damage_total_result and tonumber(damage_total_result.total or 0) > 0)
    local damage_total_has_events = damage_total_result and tonumber(damage_total_result.total or 0) > 0
    widget.content.damage_total_pct = not damage_total_result and history_no_data and "NO DATA"
        or (damage_total_has_events and string.format("%.1f%%", damage_total_share or 0) or "--")
    widget.content.damage_total_raw = not damage_total_result and history_no_data and ""
        or (damage_total_has_events and format_raw_metric(damage_total_raw, false) or "--")
    widget.style.damage_total_pct.font_size = not damage_total_result and history_no_data and 9 or 20
    widget.style.damage_total_pct.text_color = damage_total_color
    widget.style.damage_total_raw.text_color = damage_total_color
    widget.style.damage_total_title.text_color = damage_total_color
    widget.style.damage_total_icon.color = damage_total_color
    widget.style.damage_total_glyph.text_color = damage_total_color

    -- Native triangle-fan pie. The local player's slice is anchored by its
    -- midpoint in the upper-left direction and translated 10 px outward.
    -- Teammate slices follow clockwise in ascending Damage Total order.
    local pie_segments_per_player = 32
    local pie_size = 146
    local pie_radius = pie_size / 2
    local pie_slice_radius = pie_radius - 2.5
    local pie_center = pie_radius
    local pie_players = {}
    local pie_total = tonumber(damage_total_result and damage_total_result.total) or 0

    local local_pie_player
    local teammate_pie_players = {}

    for _, pie_player in ipairs(players) do
        local pie_result = metric_result_for_entry(entry, damage_total_metric, "higher", pie_player.account_id)
        local item = {
            value = math.max(0, tonumber(pie_result and pie_result.mine) or 0),
            is_local = local_player and pie_player.account_id == local_player.account_id,
            name = pie_player.name,
        }

        if item.is_local then
            local_pie_player = item
        else
            teammate_pie_players[#teammate_pie_players + 1] = item
        end
    end

    -- Keep the local player as the first slice. Teammates then follow clockwise
    -- from lowest to highest Damage Total, with name as a stable tie-breaker.
    table.sort(teammate_pie_players, function(a, b)
        if a.value ~= b.value then
            return a.value < b.value
        end
        return tostring(a.name or "") < tostring(b.name or "")
    end)

    if local_pie_player then
        pie_players[#pie_players + 1] = local_pie_player
    end
    for _, teammate in ipairs(teammate_pie_players) do
        if #pie_players >= 4 then
            break
        end
        pie_players[#pie_players + 1] = teammate
    end

    if pie_total <= 0 then
        for _, pie_player in ipairs(pie_players) do
            pie_total = pie_total + pie_player.value
        end
    end

    local teammate_colours = {
        {110, 44, 58, 55},
        {100, 38, 50, 47},
        {90, 32, 42, 40},
    }
    local teammate_index = 1

    -- Anchor the midpoint of the local player's slice at 225 degrees: the
    -- upper-left direction in screen coordinates. Because the slice width can
    -- vary, its start angle is derived from half of its actual angular span.
    local local_fraction = pie_players[1] and pie_players[1].is_local and pie_total > 0
        and pie_players[1].value / pie_total or 0
    local local_mid_angle = -math.pi * 3 / 4
    local start_angle = local_mid_angle - local_fraction * math.pi

    for player_index = 1, 4 do
        local pie_player = pie_players[player_index]
        local fraction = pie_player and pie_total > 0 and pie_player.value / pie_total or 0
        local end_angle = start_angle + fraction * math.pi * 2
        local slice_colour

        if pie_player and pie_player.is_local then
            slice_colour = damage_total_color
        else
            slice_colour = teammate_colours[teammate_index] or close_grey_green
            if pie_player then
                teammate_index = teammate_index + 1
            end
        end

        for segment_index = 1, pie_segments_per_player do
            local style = widget.style["damage_pie_" .. player_index .. "_" .. segment_index]

            if style then
                style.offset[1] = 149 + pie_shift
                if fraction > 0 then
                    local t0 = (segment_index - 1) / pie_segments_per_player
                    local t1 = segment_index / pie_segments_per_player
                    local angle0 = start_angle + (end_angle - start_angle) * t0
                    local angle1 = start_angle + (end_angle - start_angle) * t1
                    local corners = style.triangle_corners

                    corners[1][1], corners[1][2] = pie_center, pie_center
                    corners[2][1] = pie_center + math.cos(angle0) * pie_slice_radius
                    corners[2][2] = pie_center + math.sin(angle0) * pie_slice_radius
                    corners[3][1] = pie_center + math.cos(angle1) * pie_slice_radius
                    corners[3][2] = pie_center + math.sin(angle1) * pie_slice_radius
                    style.color = copy_color(slice_colour)
                else
                    local corners = style.triangle_corners
                    corners[1][1], corners[1][2] = pie_center, pie_center
                    corners[2][1], corners[2][2] = pie_center, pie_center
                    corners[3][1], corners[3][2] = pie_center, pie_center
                    style.color[1] = 0
                end
            end
        end

        local mid_angle = start_angle + (end_angle - start_angle) * 0.5
        local name_style = widget.style["damage_pie_name_" .. player_index]
        local name_id = "damage_pie_name_" .. player_index

        if name_style then
            if pie_player and pie_player.value > 0 then
                local label_w, label_h = 60, 15
                local label_radius = pie_radius - 22
                local px = pie_center + math.cos(mid_angle) * label_radius
                local py = pie_center + math.sin(mid_angle) * label_radius

                if math.sin(mid_angle) < -0.55 then
                    py = py - 1
                elseif math.sin(mid_angle) > 0.55 then
                    py = py + 1
                end

                name_style.offset = {149 + pie_shift + px - label_w / 2, 41 + py - label_h / 2, 28}
                name_style.text_color = {160, 92, 108, 95}

                if pie_player.is_local then
                    widget.content[name_id] = ""
                else
                    widget.content[name_id] = pie_player.name or "—"
                end
            else
                widget.content[name_id] = ""
                name_style.offset = {149 + pie_shift, 41, 28}
                name_style.text_color = {0, 126, 148, 126}
            end
        end

        start_angle = end_angle
    end

    widget.style.quality_background.size = {quality_visible and 225 or 0, quality_visible and 200 or 0}
    widget.style.quality_header_background.size = {quality_visible and 225 or 0, quality_visible and 22 or 0}
    widget.style.quality_bottom_divider.size = {quality_visible and 225 or 0, quality_visible and 2 or 0}
    widget.style.quality_heading.text_color = quality_visible and Color.white(255, true) or {0, 0, 0, 0}

    local chart_y, chart_h, chart_cap = 62, 82, 50
    local chart_x = complete_x + pie_w + (#metric_list > 0 and pie_gap or 0)
    local kill_graph_visible = #metric_list > 0
    for _, id in ipairs({"grid_50", "grid_25", "grid_0"}) do
        widget.style[id].offset[1] = chart_x
        widget.style[id].size[1] = kill_graph_visible and graph_w or 0
    end
    widget.style.grid_50.color = kill_graph_visible and {150, 110, 130, 118} or {0, 110, 130, 118}
    widget.style.grid_25.color = kill_graph_visible and {150, 110, 130, 118} or {0, 110, 130, 118}
    widget.style.grid_0.color = kill_graph_visible and {200, 82, 112, 92} or {0, 82, 112, 92}
    widget.style.grid_50_text.offset[1] = chart_x - 36
    widget.style.grid_25_text.offset[1] = chart_x - 36
    widget.style.grid_50_text.text_color = kill_graph_visible and {180, 126, 148, 126} or {0, 126, 148, 126}
    widget.style.grid_25_text.text_color = kill_graph_visible and {180, 126, 148, 126} or {0, 126, 148, 126}

    for i = 1, 7 do
        local metric = metric_list[i]
        if metric then
            local cx = chart_x + slot_w * (i - 0.5)
            local bx = cx - bar_w / 2
            local result = local_player and metric_result_for_entry(entry, metric, "higher", local_player.account_id) or nil
            local share = result and tonumber(result.share) or nil
            local raw = result and tonumber(result.mine) or nil
            local target = metric_target(role, metric)
            local has_events = result and tonumber(result.total or 0) > 0
            local visible = math.max(0, math.min(chart_cap, share or 0))
            local result_h = has_events and visible / chart_cap * chart_h or 0
            local goal_h = math.max(0, math.min(chart_cap, target)) / chart_cap * chart_h
            local base_y = chart_y + chart_h
            local result_y = base_y - result_h
            local goal_y = base_y - goal_h
            local color = copy_color(grey)
            if result then
                local _, _, evaluated = fulfillment("higher", share or 0, target, not has_events)
                color = evaluated
            end
            local is_best = result_is_gold(result, has_events)
            color = result_display_color(result, color, has_events)
            local frame_color = is_best and copy_color(gold_fill) or copy_color(close_grey_green)
            local stripe_color = is_best and {120, gold_fill[2], gold_fill[3], gold_fill[4]} or {95, 90, 112, 92}
            local show_goal_frame = has_events and result_h <= goal_h

            set_prototype_icon(widget, "metric_" .. i, resolve_catalogue_icon(metric.icon_index))
            widget.content["name_" .. i] = metric.text:gsub(" killed$", ""):gsub(" kills$", "")
            widget.style["metric_icon_" .. i].offset = {cx - 9, 8, 20}
            widget.style["metric_glyph_" .. i].offset = {cx - 9, 6, 20}
            widget.style["goal_stripes_" .. i].offset = {bx, goal_y, 7}
            widget.style["goal_stripes_" .. i].size = {show_goal_frame and bar_w or 0, show_goal_frame and goal_h or 0}
            widget.style["goal_stripes_" .. i].color = stripe_color
            widget.style["goal_l_" .. i].offset = {bx, goal_y, 8}
            widget.style["goal_l_" .. i].size = {show_goal_frame and 1 or 0, show_goal_frame and goal_h or 0}
            widget.style["goal_l_" .. i].color = frame_color
            widget.style["goal_r_" .. i].offset = {bx + bar_w - 1, goal_y, 8}
            widget.style["goal_r_" .. i].size = {show_goal_frame and 1 or 0, show_goal_frame and goal_h or 0}
            widget.style["goal_r_" .. i].color = frame_color
            widget.style["goal_t_" .. i].offset = {bx, goal_y, 8}
            widget.style["goal_t_" .. i].size = {show_goal_frame and bar_w or 0, show_goal_frame and 1 or 0}
            widget.style["goal_t_" .. i].color = frame_color
            widget.style["result_" .. i].offset = {bx + 1, result_y, 9}
            widget.style["result_" .. i].size = {bar_w - 2, result_h}
            widget.style["result_" .. i].color = color
            widget.style["result_highlight_" .. i].offset = {bx + 1, result_y, 10}
            widget.style["result_highlight_" .. i].size = {bar_w - 2, result_h > 0 and 2 or 0}
            widget.style["result_highlight_" .. i].color = is_best and copy_color(gold_highlight) or {150, 235, 245, 235}
            local overflow = has_events and share > chart_cap
            widget.style["overflow_" .. i].offset = {bx + 1, chart_y - 11, 11}
            widget.style["overflow_" .. i].size = {bar_w - 2, overflow and 8 or 0}
            widget.style["overflow_" .. i].color = color
            widget.content["raw_" .. i] = not result and (history_no_data and "NO DATA" or "--") or (not has_events and "--" or format_raw_metric(raw, false))
            widget.content["pct_" .. i] = not result and "" or (not has_events and "--" or string.format("%.1f%%", share or 0))
            widget.style["raw_" .. i].font_size = result and 11 or (history_no_data and 8 or 11)
            widget.style["raw_" .. i].offset = {cx - 38, overflow and (chart_y - 31) or math.max(chart_y - 27, result_y - 20), 12}
            widget.style["name_" .. i].offset = {cx - slot_w / 2, chart_y + chart_h + 5, 12}
            widget.style["pct_" .. i].offset = {cx - slot_w / 2, chart_y + chart_h + 24, 12}
            widget.style["raw_" .. i].text_color = result and color or copy_color(grey)
            widget.style["pct_" .. i].text_color = color
            widget.style["name_" .. i].text_color = color
            widget.style["metric_icon_" .. i].color = color
            widget.style["metric_glyph_" .. i].text_color = color
        else
            widget.content["metric_" .. i .. "_icon_visible"] = false
            widget.content["metric_" .. i .. "_glyph_visible"] = false
            widget.content["name_" .. i] = ""
            widget.content["raw_" .. i] = ""
            widget.content["pct_" .. i] = ""
            for _, id in ipairs({"goal_stripes_", "goal_l_", "goal_r_", "goal_t_", "result_", "result_highlight_", "overflow_"}) do
                widget.style[id .. i].size = {0, 0}
            end
        end
    end

    local quality_bar_w = 91
    local muted_quality = {190, 96, 126, 100}
    local quality_layouts = {
        [1] = {{top = 22, height = 176, y = 92.5}},
        [2] = {{top = 22, height = 88, y = 48.5}, {top = 110, height = 88, y = 136.5}},
        [3] = {{top = 22, height = 59, y = 29}, {top = 81, height = 58, y = 88}, {top = 139, height = 59, y = 146}},
    }
    local quality_layout = quality_layouts[#quality_metrics] or {}
    widget.style.quality_critical_background.size = {0, 0}
    for i = 1, 3 do
        local metric = quality_metrics[i]
        if metric then
        local layout = quality_layout[i]
        local section_top, section_height, y = layout.top, layout.height, layout.y
        widget.content["quality_title_" .. i] = metric.title
        widget.style["quality_title_" .. i].offset[2] = y - 7
        widget.style["quality_best_label_" .. i].offset[2] = y + 8
        widget.style["quality_worst_label_" .. i].offset[2] = y + 35
        widget.style["quality_best_label_" .. i].text_color = {180, 126, 148, 126}
        widget.style["quality_worst_label_" .. i].text_color = {180, 126, 148, 126}
        widget.style["quality_zero_line_" .. i].offset[2] = y + 8
        widget.style["quality_zero_line_" .. i].size = {1, 36}
        local row_geometry = {best = {y + 11, 3}, own = {y + 21, 11}, worst = {y + 39, 3}}
        for name, geometry in pairs(row_geometry) do
            widget.style["quality_" .. name .. "_bar_" .. i].offset[2] = geometry[1]
            widget.style["quality_" .. name .. "_bar_" .. i].size[2] = geometry[2]
            widget.style["quality_" .. name .. "_value_" .. i].offset[2] = geometry[1] + geometry[2] / 2 - 6.5
        end
        if metric.source == "critical_hits" then
            widget.style.quality_critical_background.offset[2] = section_top
            widget.style.quality_critical_background.size = {225, section_height}
        end
        local recorded = source_recorded(score_index, metric.source)
        local denominator_recorded = source_recorded(score_index, metric.denominator)
        if not recorded and history_no_data then
            widget.style["quality_best_label_" .. i].text_color = {0, 0, 0, 0}
            widget.style["quality_worst_label_" .. i].text_color = {0, 0, 0, 0}
            widget.style["quality_zero_line_" .. i].size = {0, 0}
        end
        local valid = {}
        for player_index = 1, math.min(#players, 4) do
            local player = players[player_index]
            local denominator = source_score(score_index, metric.denominator, player.account_id)
            if recorded and (not denominator_recorded or denominator > 0) then
                valid[#valid + 1] = {
                    account_id = player.account_id,
                    value = source_score(score_index, metric.source, player.account_id),
                }
            end
        end
        table.sort(valid, function(a, b) return a.value > b.value end)

        local best = valid[1] and valid[1].value or nil
        local worst = valid[#valid] and valid[#valid].value or nil
        local own, own_rank, previous
        local dense_rank = 0
        for _, item in ipairs(valid) do
            if previous == nil or math.abs(item.value - previous) > 0.0001 then
                dense_rank = dense_rank + 1
                previous = item.value
            end
            if local_player and item.account_id == local_player.account_id then
                own = item.value
                own_rank = dense_rank
            end
        end

        local own_color = copy_color(close_grey_green)
        if own_rank == 1 then
            own_color = copy_color(gold_fill)
        elseif own_rank == 2 then
            own_color = copy_color(green)
        end
        local scale = best and best > 0 and best or 1
        local widths = {
            best = best ~= nil and math.max(0, math.min(quality_bar_w, best / scale * quality_bar_w)) or 0,
            own = own ~= nil and math.max(0, math.min(quality_bar_w, own / scale * quality_bar_w)) or 0,
            worst = worst ~= nil and math.max(0, math.min(quality_bar_w, worst / scale * quality_bar_w)) or 0,
        }
        local values = {best = best, own = own, worst = worst}
        for _, name in ipairs({"best", "own", "worst"}) do
            local style = widget.style["quality_" .. name .. "_bar_" .. i]
            style.size[1] = widths[name]
            style.color = name == "own" and copy_color(own_color) or copy_color(muted_quality)
            widget.content["quality_" .. name .. "_value_" .. i] = not recorded and (name == "own" and (history_no_data and "NO DATA" or "--") or "")
                or (values[name] ~= nil and values[name] > 0 and string.format("%.1f%%", values[name]) or "--")
            local value_style = widget.style["quality_" .. name .. "_value_" .. i]
            value_style.offset[1] = style.offset[1] + widths[name] + 5
            value_style.font_size = name == "own" and (recorded and 10 or (history_no_data and 8 or 10)) or 8
            value_style.text_color = name == "own" and copy_color(own_color) or copy_color(muted_quality)
        end
        local own_bar = widget.style["quality_own_bar_" .. i]
        local own_highlight = widget.style["quality_own_highlight_" .. i]
        local own_width = widths.own or 0
        local highlight_width = own_width > 0 and math.min(2, own_width) or 0
        own_highlight.offset = {
            own_bar.offset[1] + math.max(0, own_width - highlight_width),
            own_bar.offset[2] + 1,
            9,
        }
        own_highlight.size = {highlight_width, own_width > 0 and math.max(0, own_bar.size[2] - 2) or 0}
        own_highlight.color = own_rank == 1 and copy_color(gold_highlight) or {150, 235, 245, 235}
        widget.style["quality_title_" .. i].text_color = copy_color(own_color)
        else
            widget.content["quality_title_" .. i] = ""
            widget.content["quality_best_value_" .. i] = ""
            widget.content["quality_own_value_" .. i] = ""
            widget.content["quality_worst_value_" .. i] = ""
            widget.style["quality_title_" .. i].text_color = {0, 0, 0, 0}
            widget.style["quality_best_label_" .. i].text_color = {0, 0, 0, 0}
            widget.style["quality_worst_label_" .. i].text_color = {0, 0, 0, 0}
            widget.style["quality_zero_line_" .. i].size = {0, 0}
            for _, name in ipairs({"best", "own", "worst"}) do
                widget.style["quality_" .. name .. "_bar_" .. i].size = {0, 0}
            end
            widget.style["quality_own_highlight_" .. i].size = {0, 0}
        end
    end

end

-- Populate the production compact Teamplay widget.
local function populate_teamplay_widget(self, entry, role)
    local widget = self._widgets_by_name.compact_team
    if not widget then return end
    local local_player
    for _, player in ipairs(ordered_players(entry)) do
        if mod:is_local_history_player(player) then
            local_player = player
            break
        end
    end
    local score_index = row_index(entry.rows)
    local history_no_data = self._iy_history_host_attached == true
    local all_teamplay_metrics = {
        {metric = metric_sections[3].metrics[1], label = "Coherency"},
        {metric = metric_sections[3].metrics[3], label = "Saves"},
        {metric = metric_sections[3].metrics[2], label = "Revives"},
        {metric = metric_sections[3].metrics[4], label = "Ammo"},
        {metric = {source = "heal_station_used", icon_index = 22}, label = "Healthstations", context = true},
        {metric = {source = "operated", icon_index = 48}, label = "Objectives", context = true},
        {metric = {source = "resources_collected", icon_index = 50}, label = "Currency", context = true},
    }
    local teamplay_metrics = {}
    for _, item in ipairs(all_teamplay_metrics) do
        if mod:is_metric_enabled(item.metric.source) then teamplay_metrics[#teamplay_metrics + 1] = item end
    end
    local content_x, content_right = 135, 960
    local slot_w = 825 / 7
    local first_x = content_x + (content_right - content_x - #teamplay_metrics * slot_w) / 2
    for i = 1, 7 do
        local item = teamplay_metrics[i]
        if item then
        local metric = item.metric
        local x = first_x + (i - 1) * slot_w
        local icon = resolve_catalogue_icon(metric.icon_index)
        widget.content["row_icon_" .. i] = icon.kind == "material" and icon.value or "content/ui/materials/base/ui_default_base"
        widget.content["row_glyph_" .. i] = icon.kind == "unicode" and icon.value or ""
        widget.content["row_icon_" .. i .. "_visible"] = icon.kind == "material"
        widget.content["row_glyph_" .. i .. "_visible"] = icon.kind == "unicode"
        widget.content["row_name_" .. i] = item.label
        widget.style["row_icon_" .. i].offset[1] = x + slot_w / 2 - 9
        widget.style["row_glyph_" .. i].offset[1] = x + slot_w / 2 - 9
        widget.style["row_name_" .. i].offset[1] = x
        widget.style["row_name_" .. i].size[1] = slot_w
        widget.style["row_raw_" .. i].offset[1] = x
        widget.style["row_raw_" .. i].size[1] = slot_w
        local row_available = source_recorded(score_index, metric.source)
        local result = row_available and local_player and metric_result_for_entry(entry, metric, "higher", local_player.account_id) or nil
        local raw = result and tonumber(result.mine) or nil
        local share = result and tonumber(result.share) or 0
        if metric.source == "coherency_efficiency" and result then
            raw = math.floor((share or 0) * 4 + 0.5)
        end
        local is_context = item.context == true
        local target = metric_target(role, metric)
        local color = copy_color(grey)
        if result and not is_context then
            local _, _, evaluated = fulfillment("higher", share or 0, target, tonumber(result.total or 0) <= 0)
            color = evaluated
            color = result_display_color(result, color, tonumber(result.total or 0) > 0)
        end
        if is_context then color = copy_color(close_grey_green) end
        local has_events = result and tonumber(result.total or 0) > 0
        widget.content["row_raw_" .. i] = not row_available
            and (history_no_data and "NO DATA" or "--") or (has_events and format_raw_metric(raw, false) or "--")
        widget.style["row_raw_" .. i].font_size = row_available and 17 or (history_no_data and 9 or 17)
        widget.style["row_raw_" .. i].text_color = color
        widget.style["row_name_" .. i].text_color = color
        widget.style["row_icon_" .. i].color = color
        widget.style["row_glyph_" .. i].text_color = color
        else
            widget.content["row_icon_" .. i .. "_visible"] = false
            widget.content["row_glyph_" .. i .. "_visible"] = false
            widget.content["row_name_" .. i] = ""
            widget.content["row_raw_" .. i] = ""
            widget.style["row_name_" .. i].text_color = {0, 0, 0, 0}
            widget.style["row_raw_" .. i].text_color = {0, 0, 0, 0}
        end
    end
end

-- Primary single-match visual-board render path.
local function render_single_entry(self, entry)
    self._widgets_by_name.compact_title.content.text = compact_match_title(entry)
    self._widgets_by_name.compact_title.style.text.text_color = Color.white(255, true)
    self._widgets_by_name.compact_subtitle.content.text = compact_mission_subtitle(entry)
    local role = selected_role_profile(self._role_key)
    populate_defense_prototype(self, entry, role)
    populate_offense_prototype(self, entry, role)
    populate_teamplay_widget(self, entry, role)
    local summaries = {}

    for _, section in ipairs(metric_sections) do
        local values = {}
        for _, metric in ipairs(active_section_metrics(section)) do
            local result = metric_result_for_entry(entry, metric, section.direction)
            local target = metric_target(role, metric)
            local state, achievement, hidden = summary_state_for_result(section.direction, result, target, metric.source)
            if state then
                values[#values + 1] = {
                    state = state,
                    achievement = achievement,
                    is_best = result.is_best == true,
                    text = metric.text,
                    raw = result.raw_display or format_raw_metric(result.mine, result.averaged == true),
                    share = result.share,
                    target = target,
                    icon = resolve_catalogue_icon(metric.icon_index),
                    hidden = hidden == true,
                }
            end
        end
        summaries[section.widget] = values
    end
    local _, _, favorable_summaries = most_favorable_role(function(candidate_role)
        return role_summary_for_entry(entry, candidate_role)
    end)
    populate_compact_players(self, entry)
    update_section_summaries(self, summaries, favorable_summaries)
    local prototype = self._widgets_by_name.compact_defense_prototype
    local defense_summary = self._widgets_by_name.compact_defense
    if prototype and defense_summary then
        prototype.content.defense_praise = defense_summary.content.praise or ""
        prototype.content.defense_score = defense_summary.content.score or ""
    end
    local offense_prototype = self._widgets_by_name.compact_offense_prototype
    local offense_summary = self._widgets_by_name.compact_offense
    if offense_prototype and offense_summary then
        offense_prototype.content.offense_praise = offense_summary.content.praise or ""
        offense_prototype.content.offense_score = offense_summary.content.score or ""
    end
end

-- Public host renderer used when Scores owns the end-screen view.
-- The host receives the same merged widget set as this view, so the approved
-- compact Victory Board can be populated without opening a second UI view.
mod.render_victory_host = function(host, entry)
    if not host or not entry or not host._widgets_by_name then return false end
    host._role_key = host._role_key or (default_role_profiles[mod:get("default_role")] and mod:get("default_role") or "generalist")
    local ok, err = pcall(render_single_entry, host, entry)
    if not ok then
        mod:error("Improve Yourself host render failed: %s", tostring(err))
        return false
    end
    return true
end

-- Widgets that must exist in the Scores host. The legacy compact
-- summaries remain available as hidden data helpers because render_single_entry
-- uses them to calculate praise and goal counts for the redesigned widgets.
mod.victory_host_compact_widgets = {
    "compact_panel", "compact_title", "compact_subtitle",
    "compact_player_1", "compact_player_2", "compact_player_3", "compact_player_4",
    "compact_defense", "compact_offense", "compact_team",
    "compact_defense_prototype", "compact_offense_prototype",
}

-- Only these widgets are actually drawn on the mission-end board. In 0.13.49+
-- the host draw loop accidentally included the two legacy summary widgets,
-- producing the large overlapping Defense/Offense bars seen above the finished
-- redesign.
mod.victory_host_draw_widgets = {
    "compact_panel", "compact_title", "compact_subtitle",
    "compact_player_1", "compact_player_2", "compact_player_3", "compact_player_4",
    "compact_defense_prototype", "compact_offense_prototype", "compact_team",
}

return mod
