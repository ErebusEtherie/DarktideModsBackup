local mod = get_mod("improve-yourself")

local Tracker = {
    categories = {"area", "ranged", "melee", "other"},
    row_names = {
        area = "iy_damage_taken_area",
        ranged = "iy_damage_taken_ranged",
        melee = "iy_damage_taken_melee",
        other = "iy_damage_taken_other",
    },
    other_label_row_name = "iy_damage_taken_other_label",
    source_label_row_names = {
        area = "iy_damage_taken_area_sources",
        ranged = "iy_damage_taken_ranged_sources",
        melee = "iy_damage_taken_melee_sources",
        other = "iy_damage_taken_other_sources",
    },
    totals = {},
    pending_attacks = {},
    pending_scoreboard_damage = {},
    other_groups = {},
    other_order = {},
    source_groups = {},
    diagnostic = {
        active = false,
        groups = {},
        order = {},
        local_groups = {},
        local_order = {},
        timeline = {},
        event_count = 0,
    },
}

local row_score

local DAMAGE_DEBUG_FILE = "improve_yourself_damage_debug.txt"
-- Live missions may place several zero-DIFF Scoreboard polls between an
-- attack report and the Damage Taken increment for that hit. Keep both sides
-- of the correlation alive for the same short window; Psykhanium usually
-- happens to deliver them without those intervening polls.
local DAMAGE_CORRELATION_GRACE_SECONDS = 1.0
local DAMAGE_CORRELATION_ZERO_UPDATE_LIMIT = 12
-- Scores samples the health extension cumulatively. When the local player
-- replaces a damaged bot, the adopted unit can therefore arrive with a
-- positive _damage value before Scores has created the local account's row.
-- Limit takeover seeding to the first seconds after entering gameplay so a
-- later, genuinely unreported first hit is still reconciled normally.
local TAKEOVER_BASELINE_WINDOW_SECONDS = 10

local area_name_tokens = {
    "aoe", "area", "barrel", "bomb", "burster", "burn", "cloud",
    "detonat", "explosion", "fire", "flame", "gas", "grenade",
    "ground", "incendiary", "mine", "napalm", "poxburster", "pool",
    "shockwave", "storm", "tox", "zone",
}

-- Confirmed through /iy_debug_damage. Both profiles are persistent Beast of
-- Nurgle vomit hazards even though one reports hook=ranged and the other has
-- no direct Area metadata.
local exact_area_profiles = {
    beast_of_nurgle_hit_by_vomit = true,
    beast_of_nurgle_slime_liquid = true,
}

-- Power DI 1.1.21 derives attacker_attack_type from the attacking unit's
-- breed through templates/custom_lookup_table_templates/minion_categories.lua.
-- Keep the same breed definitions locally so Power DI is not a runtime
-- dependency. These are a fallback after per-event Area/direct-hit evidence.
local power_di_breed_groups = {
    ranged = {
        "cultist_gunner", "renegade_captain", "renegade_netgunner",
        "renegade_sniper", "renegade_berzerker", "renegade_grenadier",
        "cultist_assault", "renegade_twin_captain", "renegade_gunner",
        "renegade_shocktrooper", "chaos_ogryn_gunner",
        "cultist_shocktrooper", "renegade_flamer", "renegade_assault",
        "renegade_rifleman", "cultist_grenadier", "cultist_captain",
        "renegade_radio_operator", "renegade_plasma_gunner",
        "attack_valkyrie",
    },
    melee = {
        "renegade_executor", "chaos_ogryn_bulwark", "chaos_hound",
        "chaos_plague_ogryn", "chaos_daemonhost", "chaos_ogryn_executor",
        "renegade_melee", "chaos_spawn", "chaos_newly_infected",
        "cultist_berzerker", "chaos_poxwalker", "cultist_mutant",
        "renegade_twin_captain_two", "chaos_beast_of_nurgle",
        "chaos_poxwalker_bomber", "cultist_melee", "cultist_flamer",
        "chaos_hound_mutator", "chaos_armored_infected",
        "chaos_mutated_poxwalker", "chaos_lesser_mutated_poxwalker",
        "cultist_mutant_mutator", "cultist_ritualist",
        "chaos_armored_hound", "chaos_ogryn_houndmaster", "nurgle_flies",
        "sand_vortex",
    },
    other = {"player", "human", "ogryn"},
}

local power_di_breed_category = {}
for category, breed_names in pairs(power_di_breed_groups) do
    for i = 1, #breed_names do
        power_di_breed_category[breed_names[i]] = category
    end
end

local function finite_number(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return value
end

local function gameplay_time()
    local time_manager = Managers and Managers.time
    if time_manager and type(time_manager.time) == "function" then
        local ok, value = pcall(time_manager.time, time_manager, "gameplay")
        if ok then
            return finite_number(value)
        end
    end
end

local function local_account_id(scoreboard)
    local account_id = scoreboard and type(scoreboard.me) == "function"
        and scoreboard:me()
        or nil
    if account_id == nil and type(mod.local_identity) == "function" then
        account_id = select(1, mod:local_identity())
    end
    return account_id
end

local function in_takeover_baseline_window(tracker)
    local entered_at = finite_number(tracker.gameplay_entered_at)
    local now = gameplay_time()
    return entered_at ~= nil and now ~= nil
        and now >= entered_at
        and now - entered_at <= TAKEOVER_BASELINE_WINDOW_SECONDS
end

local function has_live_pending_scoreboard_damage(tracker, account_id)
    local pending = tracker.pending_scoreboard_damage[tostring(account_id)]
    if not pending then
        return false
    end

    local now = gameplay_time()
    if pending.expires_at and now and now >= pending.expires_at then
        return false
    end
    if not pending.expires_at and (pending.zero_updates or 0) >= DAMAGE_CORRELATION_ZERO_UPDATE_LIMIT then
        return false
    end

    return true
end

local function safe_field(object, name)
    local ok, value = pcall(function()
        return object and object[name]
    end)
    return ok and value or nil
end

local function safe_method(object, name, ...)
    local fn = safe_field(object, name)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, value = pcall(fn, object, ...)
    return ok and value or nil
end

local function contains_area_token(name)
    name = type(name) == "string" and string.lower(name) or ""
    for i = 1, #area_name_tokens do
        if string.find(name, area_name_tokens[i], 1, true) then
            return true
        end
    end
    return false
end

local function contains_token(value, token)
    value = type(value) == "string" and string.lower(value) or ""
    return string.find(value, token, 1, true) ~= nil
end

-- Friendly source names
-- Convert internal profile and breed identifiers into compact labels shown
-- beneath each damage category. Other Damage keeps its broad category heading;
-- this mapping explains the actual remainder (Falling, Corruption, etc.).
local function friendly_other_source(group)
    local profile_name = group and group.profile_name or ""
    local damage_type = group and group.damage_type or ""
    local breed_name = group and group.breed_name or ""

    if contains_token(profile_name, "fall") or contains_token(profile_name, "ledge")
        or contains_token(profile_name, "void") then
        return "Falling"
    elseif contains_token(profile_name, "grimoire") or contains_token(profile_name, "corrupt")
        or contains_token(damage_type, "grimoire") or contains_token(damage_type, "corrupt") then
        return "Corruption"
    elseif contains_token(profile_name, "warp") then
        return "Warp"
    elseif contains_token(profile_name, "overheat") then
        return "Overheat"
    elseif contains_token(profile_name, "netted") or contains_token(profile_name, "net_") then
        return "Netted"
    elseif contains_token(profile_name, "scoreboard_delta_without_attack_report") then
        return "Untracked"
    elseif breed_name == "player" or breed_name == "human" or breed_name == "ogryn" then
        return "Self Damage"
    end

    return "Untracked"
end

local friendly_breed_names = {
    chaos_armored_hound = "Armored Hound",
    chaos_beast_of_nurgle = "Beast of Nurgle",
    chaos_hound = "Hound",
    chaos_lesser_mutated_poxwalker = "Mutated Poxwalker",
    chaos_mutated_poxwalker = "Mutated Poxwalker",
    chaos_newly_infected = "Groaner",
    chaos_ogryn_bulwark = "Bulwark",
    chaos_ogryn_executor = "Crusher",
    chaos_ogryn_gunner = "Reaper",
    chaos_ogryn_houndmaster = "Houndmaster",
    chaos_plague_ogryn = "Plague Ogryn",
    chaos_poxwalker = "Poxwalker",
    chaos_poxwalker_bomber = "Poxburster",
    chaos_spawn = "Chaos Spawn",
    cultist_assault = "Shotgunner",
    cultist_berzerker = "Rager",
    cultist_captain = "Captain",
    cultist_flamer = "Flamer",
    cultist_grenadier = "Bomber",
    cultist_gunner = "Gunner",
    cultist_melee = "Bruiser",
    cultist_mutant = "Mutant",
    cultist_shocktrooper = "Shotgunner",
    cultist_vanguard = "Shotgunner",
    renegade_assault = "Shotgunner",
    renegade_berzerker = "Rager",
    renegade_captain = "Captain",
    renegade_executor = "Mauler",
    renegade_flamer = "Flamer",
    renegade_grenadier = "Bomber",
    renegade_gunner = "Gunner",
    renegade_melee = "Bruiser",
    renegade_rifleman = "Shooter",
    renegade_shocktrooper = "Shotgunner",
    renegade_sniper = "Sniper",
    renegade_vanguard = "Shotgunner",
}

local function friendly_area_source(profile_name, breed_name)
    profile_name = type(profile_name) == "string" and string.lower(profile_name) or ""
    if contains_token(profile_name, "gas") then
        return "Pox Gas"
    elseif contains_token(profile_name, "barrel") and contains_token(profile_name, "fire") then
        return "Barrel Fire"
    elseif contains_token(profile_name, "barrel") then
        return "Barrel Explosion"
    elseif contains_token(profile_name, "poxwalker_explosion") or contains_token(profile_name, "burster") then
        return "Poxburster"
    elseif contains_token(profile_name, "liquid_fire") or contains_token(profile_name, "flame")
        or contains_token(profile_name, "burn") then
        return "Flamer Fire"
    elseif contains_token(profile_name, "vomit") or contains_token(profile_name, "slime") then
        return "Beast Slime"
    elseif contains_token(profile_name, "ground_slam") or contains_token(profile_name, "shockwave") then
        return "Ground Slam"
    elseif contains_token(profile_name, "explosion") then
        return "Explosion"
    end
    return friendly_breed_names[breed_name] or "Area Effect"
end

local function friendly_category_source(category, damage_profile, breed_name)
    if category == "other" then
        return friendly_other_source({
            profile_name = tostring(safe_field(damage_profile, "name") or ""),
            damage_type = tostring(safe_field(damage_profile, "damage_type") or ""),
            breed_name = tostring(breed_name or ""),
        })
    elseif category == "area" then
        return friendly_area_source(safe_field(damage_profile, "name"), breed_name)
    end
    return friendly_breed_names[breed_name] or (category == "ranged" and "Ranged Attack" or "Melee Attack")
end

local function is_area_damage(damage_profile, attack_type)
    local profile_attack_type = safe_field(damage_profile, "attack_type")
    local damage_type = safe_field(damage_profile, "damage_type")
    local profile_name = safe_field(damage_profile, "name")

    if exact_area_profiles[profile_name] then
        return true
    end

    if attack_type == "explosion" or attack_type == "aoe" or attack_type == "area"
        or profile_attack_type == "explosion" or profile_attack_type == "aoe" or profile_attack_type == "area" then
        return true
    end

    if safe_field(damage_profile, "is_aoe") == true
        or safe_field(damage_profile, "is_area_damage") == true
        or safe_field(damage_profile, "explosion_template") ~= nil
        or (finite_number(safe_field(damage_profile, "radius")) or 0) > 0
        or (finite_number(safe_field(damage_profile, "damage_radius")) or 0) > 0 then
        return true
    end

    return contains_area_token(profile_name) or contains_area_token(damage_type)
end

local function direct_attack_category(value)
    value = type(value) == "string" and string.lower(value) or ""
    if value == "ranged" or value == "projectile" then
        return "ranged"
    elseif value == "melee" then
        return "melee"
    end
end

local function attacker_breed_name(scoreboard, attacking_unit)
    if not attacking_unit or not scoreboard or type(scoreboard.safe_extension) ~= "function" then
        return nil
    end
    local ok, breed_name = pcall(function()
        local unit_data_extension = scoreboard:safe_extension(attacking_unit, "unit_data_system")
        local breed = unit_data_extension and unit_data_extension:breed()
        return breed and breed.name
    end)
    return ok and breed_name or nil
end

local function player_state_name(scoreboard, unit)
    if not unit or not scoreboard or type(scoreboard.safe_extension) ~= "function" then
        return nil
    end
    local unit_data_extension = scoreboard:safe_extension(unit, "unit_data_system")
    local component = safe_method(unit_data_extension, "read_component", "character_state")
    if component and component.state_name then
        return component.state_name
    end
    local health_extension = scoreboard:safe_extension(unit, "health_system")
    component = safe_field(health_extension, "_character_state_read_component")
        or safe_field(health_extension, "_character_state_component")
    return safe_field(component, "state_name")
end

local function scoreboard_previous_state(scoreboard, account_id)
    local states = scoreboard and safe_field(scoreboard, "player_state_tracker")
    if type(states) ~= "table" or account_id == nil then
        return nil
    end
    return states[account_id] or states[tostring(account_id)]
end

local function pending_attack_summary(tracker, account_id)
    local queue = tracker.pending_attacks[tostring(account_id)]
    if not queue or #queue == 0 then
        return "none"
    end
    local counts = {}
    for i = 1, #queue do
        local category = tostring(queue[i].category or "other")
        counts[category] = (counts[category] or 0) + 1
    end
    local parts = {}
    for _, category in ipairs(tracker.categories) do
        if counts[category] then
            parts[#parts + 1] = string.format("%s:%d", category, counts[category])
        end
    end
    return table.concat(parts, ",")
end

function Tracker:add_local_timeline(account_id, text)
    local diagnostic = self.diagnostic
    if not diagnostic.active or account_id == nil then
        return
    end
    if diagnostic.local_id == nil then
        local resolved_id = type(self.scoreboard.me) == "function" and self.scoreboard:me() or nil
        if resolved_id == nil and type(mod.local_identity) == "function" then
            resolved_id = select(1, mod:local_identity())
        end
        if resolved_id == nil then
            return
        end
        diagnostic.local_id = resolved_id
        local damage_row = type(self.scoreboard.get_scoreboard_row) == "function"
            and self.scoreboard:get_scoreboard_row("damage_taken")
            or nil
        diagnostic.start_scoreboard = row_score(damage_row, resolved_id) or 0
        diagnostic.start_sources = {area = 0, ranged = 0, melee = 0, other = 0}
    end
    if tostring(diagnostic.local_id) ~= tostring(account_id) then
        return
    end
    local relative_time = gameplay_time()
    local started_time = finite_number(diagnostic.started_gameplay_time)
    if relative_time and started_time then
        relative_time = relative_time - started_time
    end
    diagnostic.timeline[#diagnostic.timeline + 1] = string.format("t=%s | %s",
        relative_time and string.format("%.3f", relative_time) or "nil", tostring(text))
end

-- Category classification
-- Precedence is intentional: Area evidence overrides projectile/contact
-- metadata, direct Ranged/Melee evidence follows, and unresolved or
-- player-attributed damage falls back to Other.
local function classify(damage_profile, attack_type, player_attributed, breed_name)
    attack_type = type(attack_type) == "string" and string.lower(attack_type) or ""

    -- Deliberate precedence: zones/explosions override projectile or contact
    -- metadata carried by the same damage profile.
    if is_area_damage(damage_profile, attack_type) then
        return "area"
    elseif player_attributed then
        return "other"
    end

    local direct_category = direct_attack_category(attack_type)
        or direct_attack_category(safe_field(damage_profile, "attack_type"))
    if direct_category then
        return direct_category
    end

    return power_di_breed_category[breed_name] or "other"
end

function Tracker:reset()
    self.totals = {}
    self.pending_attacks = {}
    self.pending_scoreboard_damage = {}
    self.other_groups = {}
    self.other_order = {}
    self.source_groups = {}
    self.gameplay_entered_at = gameplay_time()
end

local function clear_table(values)
    for key in pairs(values or {}) do
        values[key] = nil
    end
end

-- Reset only the current mission's damage-taken test data. Scores'
-- damage_taken row uses DIFF iteration: value is the previous cumulative
-- health-extension damage sample, while score is the accumulated mission
-- total. Seeding value from the live extension prevents pre-reset damage from
-- being counted again on the next fixed update.
function Tracker:reset_live_damage()
    local scoreboard = self.scoreboard
    if not scoreboard or type(scoreboard.get_scoreboard_row) ~= "function" then
        return false, "Scores is not available."
    end

    local damage_row = scoreboard:get_scoreboard_row("damage_taken")
    if not damage_row then
        return false, "Scores' Damage Taken row is not available."
    end

    self.totals = {}
    self.pending_attacks = {}
    self.pending_scoreboard_damage = {}
    self.other_groups = {}
    self.other_order = {}
    self.source_groups = {}
    damage_row.data = damage_row.data or {}
    clear_table(damage_row.data)

    local player_manager = scoreboard.player_manager or (Managers and Managers.player)
    local players = type(scoreboard.scoreboard_players) == "function"
        and scoreboard:scoreboard_players(player_manager, nil, true)
        or {}
    local seeded = 0

    for _, player in pairs(players or {}) do
        local account_id = type(scoreboard.account_id_from_player) == "function"
            and scoreboard:account_id_from_player(player)
            or nil
        local unit = safe_field(player, "player_unit")
        local health_extension = unit and type(scoreboard.safe_extension) == "function"
            and scoreboard:safe_extension(unit, "health_system")
            or nil
        local current_damage = finite_number(safe_field(health_extension, "_damage"))

        if account_id and current_damage then
            damage_row.data[account_id] = {
                value = math.max(0, current_damage),
                score = 0,
                text = nil,
            }
            seeded = seeded + 1
        end
    end

    if seeded == 0 then
        return false, "No active player health data was available; nothing was reset."
    end

    return true, string.format("Damage test data cleared for %d active player%s.", seeded, seeded == 1 and "" or "s")
end

-- Bidirectional damage correlation
-- Attack reports and Scores' effective-health increments may arrive in
-- either order. Keep each side briefly, then allocate the official increment
-- across the matching reports so category totals reconcile to Scores.
function Tracker:queue_attack(account_id, event)
    if not account_id or type(event) ~= "table" then
        return
    end
    local key = tostring(account_id)

    -- Do not let an expired batch on either side consume an unrelated later
    -- hit. Conversely, if a still-live Scoreboard increment arrived first,
    -- let this report claim it immediately instead of waiting for another
    -- Scoreboard poll.
    self:flush_pending_scoreboard_damage(account_id, false)
    local queue = self.pending_attacks[key]
    if not queue then
        queue = {}
        self.pending_attacks[key] = queue
    end
    local now = gameplay_time()
    if now then
        queue.expires_at = now + DAMAGE_CORRELATION_GRACE_SECONDS
    end
    queue.zero_updates = 0
    queue[#queue + 1] = event

    self:resolve_pending_scoreboard_damage(account_id)
end

function Tracker:resolve_pending_attacks(account_id, actual_damage)
    local key = tostring(account_id)
    local queue = self.pending_attacks[key]
    self.pending_attacks[key] = nil
    if not queue or #queue == 0 then
        return false
    end

    local raw_total = 0
    for i = 1, #queue do
        raw_total = raw_total + math.max(0, finite_number(queue[i].raw_damage) or 0)
    end

    for i = 1, #queue do
        local event = queue[i]
        local weight = raw_total > 0 and math.max(0, finite_number(event.raw_damage) or 0) / raw_total or 0
        local allocated_damage = actual_damage * weight
        self:record(account_id, event.category, allocated_damage)
        self:record_category_source(account_id, event.category, event.damage_profile, event.breed_name,
            allocated_damage)
        if event.category == "other" then
            self:record_other_source(account_id, event.damage_profile, event.attack_type, event.breed_name,
                allocated_damage, event.attack_result)
        end
        if event.diagnostic then
            self:capture_diagnostic(event.damage_profile, event.attack_type, event.breed_name, event.raw_damage,
                allocated_damage, event.category, event.attacked_unit, event.attack_result, event.state_name,
                account_id)
        end
        self:add_local_timeline(account_id, string.format(
            "ALLOCATE %.2f => %s | profile=%s result=%s captured_state=%s",
            allocated_damage, tostring(event.category),
            tostring(safe_field(event.damage_profile, "name") or "nil"),
            tostring(event.attack_result), tostring(event.state_name)))
    end
    return true
end

function Tracker:discard_pending_attacks(account_id)
    local key = tostring(account_id)
    local queue = self.pending_attacks[key]
    local summary = pending_attack_summary(self, account_id)
    self.pending_attacks[key] = nil
    if not queue then
        return
    end
    self:add_local_timeline(account_id, "DISCARD expired report batch | pending=" .. summary)
    for i = 1, #queue do
        local event = queue[i]
        if event.diagnostic then
            self:capture_diagnostic(event.damage_profile, event.attack_type, event.breed_name, event.raw_damage,
                0, event.category, event.attacked_unit, event.attack_result, event.state_name, account_id)
        end
    end
end

function Tracker:store_pending_scoreboard_damage(account_id, actual_damage)
    local key = tostring(account_id)
    local now = gameplay_time()
    local pending = self.pending_scoreboard_damage[key]
    if pending then
        pending.damage = pending.damage + actual_damage
        if now then
            pending.expires_at = now + DAMAGE_CORRELATION_GRACE_SECONDS
        end
        pending.zero_updates = 0
    else
        self.pending_scoreboard_damage[key] = {
            damage = actual_damage,
            expires_at = now and (now + DAMAGE_CORRELATION_GRACE_SECONDS) or nil,
            zero_updates = 0,
        }
    end
end

function Tracker:resolve_pending_scoreboard_damage(account_id)
    local key = tostring(account_id)
    local pending = self.pending_scoreboard_damage[key]
    if not pending or not self.pending_attacks[key] then
        return false
    end
    self.pending_scoreboard_damage[key] = nil
    return self:resolve_pending_attacks(account_id, pending.damage)
end

function Tracker:flush_pending_scoreboard_damage(account_id, force)
    local key = tostring(account_id)
    local pending = self.pending_scoreboard_damage[key]
    if not pending then
        return false
    end

    if self.pending_attacks[key] then
        return self:resolve_pending_scoreboard_damage(account_id)
    end

    local now = gameplay_time()
    local expired = force
        or (pending.expires_at and now and now >= pending.expires_at)
        or (not pending.expires_at and pending.zero_updates >= DAMAGE_CORRELATION_ZERO_UPDATE_LIMIT)
    if not expired then
        return false
    end

    self.pending_scoreboard_damage[key] = nil
    self:add_local_timeline(account_id, string.format(
        "FALLBACK Untracked %.2f | force=%s", pending.damage, tostring(force == true)))
    self:record(account_id, "other", pending.damage)
    self:record_category_source(account_id, "other", {name = "scoreboard_delta_without_attack_report"}, nil,
        pending.damage)
    self:record_other_source(account_id, {name = "scoreboard_delta_without_attack_report"}, nil, nil,
        pending.damage, "scoreboard_update")
    return true
end

function Tracker:sync_scoreboard_damage(account_id, actual_damage)
    local key = tostring(account_id)
    actual_damage = math.max(0, finite_number(actual_damage) or 0)
    if actual_damage > 0 then
        self:add_local_timeline(account_id, string.format(
            "SCOREBOARD +%.2f | pending_reports=%s | pending_increment=%.2f",
            actual_damage, pending_attack_summary(self, account_id),
            finite_number(self.pending_scoreboard_damage[key] and self.pending_scoreboard_damage[key].damage) or 0))
        local queue = self.pending_attacks[key]
        if queue then
            local now = gameplay_time()
            local expired = (queue.expires_at and now and now >= queue.expires_at)
                or (not queue.expires_at and (queue.zero_updates or 0) >= DAMAGE_CORRELATION_ZERO_UPDATE_LIMIT)
            if expired then
                self:discard_pending_attacks(account_id)
            end
        end

        -- A previous Scoreboard increment may have arrived before its attack
        -- report. Resolve that older credit first if the report has now
        -- appeared; otherwise combine consecutive increments into one short
        -- correlation window.
        local pending = self.pending_scoreboard_damage[key]
        if pending then
            if self.pending_attacks[key] then
                self:resolve_pending_scoreboard_damage(account_id)
            else
                self:store_pending_scoreboard_damage(account_id, actual_damage)
                return
            end
        end

        -- The usual ordering is still handled immediately: classified report
        -- first, exact Scores DIFF second. If the DIFF arrived first,
        -- retain it briefly instead of prematurely turning it into Other.
        if not self:resolve_pending_attacks(account_id, actual_damage) then
            self:store_pending_scoreboard_damage(account_id, actual_damage)
        end
    else
        local pending = self.pending_scoreboard_damage[key]
        if pending then
            pending.zero_updates = pending.zero_updates + 1
            if self:resolve_pending_scoreboard_damage(account_id) then
                return
            end
            self:flush_pending_scoreboard_damage(account_id, false)
        else
            -- A zero DIFF does not close the report-first interval immediately.
            -- Otherwise an intervening zero poll can discard Ranged or Area
            -- reports before their positive Damage Taken increment arrives.
            -- Expired batches are still discarded so toughness-only reports
            -- cannot steal a later, unrelated health hit.
            local queue = self.pending_attacks[key]
            if queue then
                queue.zero_updates = (queue.zero_updates or 0) + 1
                local now = gameplay_time()
                local expired = (queue.expires_at and now and now >= queue.expires_at)
                    or (not queue.expires_at and queue.zero_updates >= DAMAGE_CORRELATION_ZERO_UPDATE_LIMIT)
                if expired then
                    self:discard_pending_attacks(account_id)
                end
            end
        end
    end
end

-- Category and source aggregation
-- Store committed effective-health damage by category and by friendly source.
-- Unmatched Scoreboard increments are reconciled into Other as Untracked.
function Tracker:record(account_id, category, damage)
    damage = finite_number(damage)
    if not account_id or not damage or damage <= 0 then
        return
    end

    local key = tostring(account_id)
    local player = self.totals[key]
    if not player then
        player = {area = 0, ranged = 0, melee = 0, other = 0}
        self.totals[key] = player
    end
    category = self.row_names[category] and category or "other"
    player[category] = player[category] + damage
end

function Tracker:record_category_source(account_id, category, damage_profile, breed_name, damage)
    damage = finite_number(damage)
    if not account_id or not damage or damage <= 0 then
        return
    end
    category = self.row_names[category] and category or "other"
    local account_key = tostring(account_id)
    local account_groups = self.source_groups[account_key]
    if not account_groups then
        account_groups = {}
        self.source_groups[account_key] = account_groups
    end
    local category_groups = account_groups[category]
    if not category_groups then
        category_groups = {}
        account_groups[category] = category_groups
    end
    local label = friendly_category_source(category, damage_profile, breed_name)
    category_groups[label] = (category_groups[label] or 0) + damage
end

function Tracker:source_label(account_id, category)
    local account_groups = self.source_groups[tostring(account_id)]
    local category_groups = account_groups and account_groups[category]
    if not category_groups then
        return ""
    end
    local ranked = {}
    for label, damage in pairs(category_groups) do
        ranked[#ranked + 1] = {label = label, damage = damage}
    end
    table.sort(ranked, function(a, b)
        if a.damage == b.damage then
            return a.label < b.label
        end
        return a.damage > b.damage
    end)
    local labels = {}
    for i = 1, math.min(3, #ranked) do
        labels[#labels + 1] = ranked[i].label
    end
    return table.concat(labels, ", ") .. (#ranked > 3 and ", ..." or "")
end

function Tracker:record_other_source(account_id, damage_profile, attack_type, breed_name, damage, attack_result)
    local key = tostring(account_id)
    local profile_name = tostring(safe_field(damage_profile, "name") or "nil")
    local profile_attack_type = tostring(safe_field(damage_profile, "attack_type") or "nil")
    local damage_type = tostring(safe_field(damage_profile, "damage_type") or "nil")
    local signature = table.concat({key, profile_name, tostring(attack_type), profile_attack_type,
        damage_type, tostring(breed_name), tostring(attack_result)}, "|")
    local group = self.other_groups[signature]
    if not group then
        group = {
            account_id = key,
            profile_name = profile_name,
            attack_type = tostring(attack_type),
            profile_attack_type = profile_attack_type,
            damage_type = damage_type,
            breed_name = tostring(breed_name),
            attack_result = tostring(attack_result),
            count = 0,
            damage = 0,
        }
        self.other_groups[signature] = group
        self.other_order[#self.other_order + 1] = signature
    end
    group.count = group.count + 1
    group.damage = group.damage + (finite_number(damage) or 0)
end

function Tracker:other_source_label(account_id, expected_other)
    local key = tostring(account_id)
    local totals = {}
    local grouped_total = 0
    for _, signature in ipairs(self.other_order or {}) do
        local group = self.other_groups[signature]
        if group and group.account_id == key then
            local damage = math.max(0, finite_number(group.damage) or 0)
            if damage > 0 then
                local label = friendly_other_source(group)
                totals[label] = (totals[label] or 0) + damage
                grouped_total = grouped_total + damage
            end
        end
    end
    expected_other = math.max(0, finite_number(expected_other) or grouped_total)
    if expected_other > grouped_total + 0.01 then
        totals.Untracked = (totals.Untracked or 0) + expected_other - grouped_total
    end

    local ranked = {}
    for label, damage in pairs(totals) do
        ranked[#ranked + 1] = {label = label, damage = damage}
    end
    table.sort(ranked, function(a, b)
        if a.damage == b.damage then
            return a.label < b.label
        end
        return a.damage > b.damage
    end)

    if #ranked == 0 then
        return "Other"
    end
    return ranked[1].label .. (#ranked > 1 and ", [...]" or "")
end

local function report_timestamp(scoreboard)
    local report_os = scoreboard and scoreboard.scoreboard_history_os
    if report_os and type(report_os.date) == "function" then
        local ok, value = pcall(report_os.date, "%Y-%m-%d %H:%M:%S")
        if ok and value then
            return tostring(value)
        end
    end
    return "unknown time"
end

local function report_file_timestamp(scoreboard)
    local report_os = scoreboard and scoreboard.scoreboard_history_os
    if report_os and type(report_os.date) == "function" then
        local ok, value = pcall(report_os.date, "%Y%m%d-%H%M%S")
        if ok and value then
            return tostring(value)
        end
    end
    return tostring(math.floor((gameplay_time() or 0) * 1000 + 0.5))
end

-- Diagnostic reports
-- Manual and automatic captures share one chronological format so an isolated
-- Untracked value can be matched to reports, player state, and Scoreboard DIFFs.
function Tracker:write_debug_report(file_name, lines)
    local scoreboard = self.scoreboard
    if not scoreboard then
        return false, nil, "Scores is not available."
    end

    if type(scoreboard.create_scoreboard_history_directory) == "function" then
        pcall(scoreboard.create_scoreboard_history_directory, scoreboard)
    end

    local base_path = type(scoreboard.appdata_path) == "function" and scoreboard:appdata_path() or nil
    local report_io = scoreboard.scoreboard_history_io
    if not base_path or not report_io or type(report_io.open) ~= "function" then
        return false, nil, "Scores' writable data path is unavailable."
    end

    local path = base_path .. file_name
    local file, open_error = report_io.open(path, "w")
    if not file then
        return false, path, tostring(open_error or "the file could not be opened")
    end

    local ok, write_error = pcall(function()
        file:write(table.concat(lines or {}, "\n"), "\n")
        if type(file.flush) == "function" then
            file:flush()
        end
    end)
    pcall(file.close, file)

    if not ok then
        return false, path, tostring(write_error)
    end
    return true, path
end

row_score = function(row, account_id)
    local data = row and row.data and row.data[account_id]
    if not data and account_id ~= nil then
        data = row and row.data and row.data[tostring(account_id)]
    end
    return finite_number(type(data) == "table" and (data.score or data.value or data.total) or data)
end

local function find_row(groups, row_name)
    for _, group in ipairs(groups or {}) do
        for _, row in ipairs(group or {}) do
            if row and row.name == row_name then
                return row
            end
        end
    end
end

function Tracker:normalized_sources(account_id, official_total, include_reconciliation)
    official_total = math.max(0, finite_number(official_total) or 0)
    local recorded = self.totals[tostring(account_id)]
    local result = {area = 0, ranged = 0, melee = 0, other = 0}
    if not recorded then
        if include_reconciliation ~= false and official_total > 0 then
            result.other = official_total
        end
        return result
    end

    local recorded_total = 0
    for _, category in ipairs(self.categories) do
        local value = math.max(0, finite_number(recorded[category]) or 0)
        result[category] = value
        recorded_total = recorded_total + value
    end

    if recorded_total > official_total and recorded_total > 0 then
        local scale = official_total / recorded_total
        for _, category in ipairs(self.categories) do
            result[category] = result[category] * scale
        end
    elseif include_reconciliation ~= false and official_total > recorded_total then
        result.other = result.other + official_total - recorded_total
    end
    return result
end

local function source_snapshot(tracker, account_id)
    local recorded = account_id ~= nil and tracker.totals[tostring(account_id)] or nil
    local snapshot = {}
    for _, category in ipairs(tracker.categories) do
        snapshot[category] = math.max(0, finite_number(recorded and recorded[category]) or 0)
    end
    return snapshot
end

local function health_snapshot(scoreboard)
    local player_manager = scoreboard and (scoreboard.player_manager or (Managers and Managers.player))
    local player = player_manager and player_manager.local_player and player_manager:local_player(1)
    local unit = player and safe_field(player, "player_unit")
    local extension = unit and scoreboard and type(scoreboard.safe_extension) == "function"
        and scoreboard:safe_extension(unit, "health_system")
        or nil
    return {
        damage_field = finite_number(safe_field(extension, "_damage")),
        permanent_field = finite_number(safe_field(extension, "_permanent_damage")),
        damage_taken = finite_number(safe_method(extension, "damage_taken")),
        permanent_taken = finite_number(safe_method(extension, "permanent_damage_taken")),
        state = player_state_name(scoreboard, unit),
    }
end

local function snapshot_text(snapshot)
    snapshot = snapshot or {}
    return string.format("_damage=%s permanent=%s damage_taken()=%s permanent_taken()=%s state=%s",
        tostring(snapshot.damage_field), tostring(snapshot.permanent_field), tostring(snapshot.damage_taken),
        tostring(snapshot.permanent_taken), tostring(snapshot.state))
end

function Tracker:capture_diagnostic(damage_profile, attack_type, breed_name, raw_damage, actual_damage, category,
    attacked_unit, attack_result, captured_state_name, account_id)
    local diagnostic = self.diagnostic
    if not diagnostic.active then
        return
    end
    local profile_name = tostring(safe_field(damage_profile, "name") or "nil")
    local profile_attack_type = tostring(safe_field(damage_profile, "attack_type") or "nil")
    local damage_type = tostring(safe_field(damage_profile, "damage_type") or "nil")
    local state_name = tostring(captured_state_name or player_state_name(self.scoreboard, attacked_unit) or "nil")
    local area_evidence = string.format("aoe=%s area=%s radius=%s damage_radius=%s explosion=%s",
        tostring(safe_field(damage_profile, "is_aoe")), tostring(safe_field(damage_profile, "is_area_damage")),
        tostring(safe_field(damage_profile, "radius")), tostring(safe_field(damage_profile, "damage_radius")),
        tostring(safe_field(damage_profile, "explosion_template") ~= nil))
    account_id = account_id or (self.scoreboard and type(self.scoreboard.account_id_from_unit) == "function"
        and self.scoreboard:account_id_from_unit(attacked_unit))
    local signature = table.concat({profile_name, tostring(attack_type), profile_attack_type, damage_type,
        tostring(breed_name), tostring(category), state_name, tostring(attack_result), area_evidence}, "|")
    local group = diagnostic.groups[signature]
    if not group then
        group = {
            profile_name = profile_name,
            attack_type = tostring(attack_type),
            profile_attack_type = profile_attack_type,
            damage_type = damage_type,
            breed_name = tostring(breed_name),
            category = tostring(category),
            state_name = state_name,
            attack_result = tostring(attack_result),
            area_evidence = area_evidence,
            count = 0,
            raw_damage = 0,
            actual_damage = 0,
        }
        diagnostic.groups[signature] = group
        diagnostic.order[#diagnostic.order + 1] = signature
    end
    group.count = group.count + 1
    group.raw_damage = group.raw_damage + (finite_number(raw_damage) or 0)
    group.actual_damage = group.actual_damage + (finite_number(actual_damage) or 0)
    diagnostic.event_count = diagnostic.event_count + 1
    if diagnostic.local_id ~= nil and account_id ~= nil
        and tostring(diagnostic.local_id) == tostring(account_id) then
        local local_group = diagnostic.local_groups[signature]
        if not local_group then
            local_group = {
                profile_name = profile_name,
                attack_type = tostring(attack_type),
                profile_attack_type = profile_attack_type,
                damage_type = damage_type,
                breed_name = tostring(breed_name),
                category = tostring(category),
                state_name = state_name,
                attack_result = tostring(attack_result),
                area_evidence = area_evidence,
                count = 0,
                raw_damage = 0,
                actual_damage = 0,
            }
            diagnostic.local_groups[signature] = local_group
            diagnostic.local_order[#diagnostic.local_order + 1] = signature
        end
        local_group.count = local_group.count + 1
        local_group.raw_damage = local_group.raw_damage + (finite_number(raw_damage) or 0)
        local_group.actual_damage = local_group.actual_damage + (finite_number(actual_damage) or 0)
    end
    if category ~= "excluded_downed" then
        diagnostic.raw_included = diagnostic.raw_included + (finite_number(raw_damage) or 0)
        diagnostic.actual_included = diagnostic.actual_included + (finite_number(actual_damage) or 0)
        if diagnostic.local_id ~= nil and account_id ~= nil
            and tostring(diagnostic.local_id) == tostring(account_id) then
            diagnostic.local_raw_included = diagnostic.local_raw_included + (finite_number(raw_damage) or 0)
            diagnostic.local_actual_included = diagnostic.local_actual_included + (finite_number(actual_damage) or 0)
        end
    end
end

local function official_damage_total(scoreboard, account_id)
    local row = scoreboard and type(scoreboard.get_scoreboard_row) == "function"
        and scoreboard:get_scoreboard_row("damage_taken")
        or nil
    return row_score(row, account_id) or 0
end

function Tracker:start_damage_diagnostic(file_name, automatic)
    local diagnostic = self.diagnostic
    if diagnostic.active then
        return false
    end
    file_name = file_name or DAMAGE_DEBUG_FILE
    local start_health = health_snapshot(self.scoreboard)
    local ok, path, err = self:write_debug_report(file_name, {
        "Improve Yourself - Damage diagnostic",
        "Capture started: " .. report_timestamp(self.scoreboard),
        "Start: " .. snapshot_text(start_health),
        "",
        automatic and "Automatic capture is active for this mission."
            or "Capture is active. Run /iy_debug_damage again after reproducing the damage to write the complete report.",
    })
    if not ok then
        mod:error("Damage diagnostic could not start because its report file could not be written%s: %s",
            path and (" to " .. path) or "", tostring(err))
        return false
    end
    diagnostic.active = true
    diagnostic.automatic = automatic == true
    diagnostic.file_name = file_name
    diagnostic.groups = {}
    diagnostic.order = {}
    diagnostic.local_groups = {}
    diagnostic.local_order = {}
    diagnostic.timeline = {}
    diagnostic.event_count = 0
    diagnostic.raw_included = 0
    diagnostic.actual_included = 0
    diagnostic.local_raw_included = 0
    diagnostic.local_actual_included = 0
    diagnostic.start_health = start_health
    local local_id = type(self.scoreboard.me) == "function" and self.scoreboard:me() or nil
    if local_id == nil and type(mod.local_identity) == "function" then
        local_id = select(1, mod:local_identity())
    end
    diagnostic.local_id = local_id
    diagnostic.start_scoreboard = local_id and official_damage_total(self.scoreboard, local_id) or 0
    diagnostic.start_sources = source_snapshot(self, local_id)
    diagnostic.started_at = report_timestamp(self.scoreboard)
    diagnostic.started_gameplay_time = gameplay_time()
    if not automatic then
        mod:echo("Damage diagnostic started. Report file: " .. path)
    end
    return true
end

function Tracker:finish_damage_diagnostic(reason, quiet)
    local diagnostic = self.diagnostic
    if not diagnostic.active then
        return false
    end
    for account_id in pairs(self.pending_scoreboard_damage) do
        self:flush_pending_scoreboard_damage(account_id, true)
    end
    for account_id in pairs(self.pending_attacks) do
        self:discard_pending_attacks(account_id)
    end
    diagnostic.active = false
    local finish_health = health_snapshot(self.scoreboard)
    local lines = {
        "Improve Yourself - Damage diagnostic",
        "Capture started: " .. tostring(diagnostic.started_at or "unknown time"),
        "Capture stopped: " .. report_timestamp(self.scoreboard),
        "Stop reason: " .. tostring(reason or "manual"),
        string.format("Attack-report events: %d", diagnostic.event_count),
        "Start: " .. snapshot_text(diagnostic.start_health),
        "End:   " .. snapshot_text(finish_health),
        "",
        "Local-player chronological correlation timeline:",
    }
    for i = 1, #(diagnostic.timeline or {}) do
        lines[#lines + 1] = string.format("[T%d] %s", i, diagnostic.timeline[i])
    end
    if #(diagnostic.timeline or {}) == 0 then
        lines[#lines + 1] = "No local-player timeline events were captured."
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Grouped attack-report events:"
    for i = 1, #diagnostic.order do
        local group = diagnostic.groups[diagnostic.order[i]]
        lines[#lines + 1] = string.format(
            "[%d] %dx raw=%.2f actual=%.2f => %s | profile=%s | hook=%s | profile_attack=%s | damage_type=%s | breed=%s | result=%s | state=%s | %s",
            i, group.count, group.raw_damage, group.actual_damage, group.category, group.profile_name, group.attack_type,
            group.profile_attack_type, group.damage_type, group.breed_name, group.attack_result,
            group.state_name, group.area_evidence)
    end
    if #diagnostic.order == 0 then
        lines[#lines + 1] = "No attack-report events were captured."
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Local-player attack-report events:"
    for i = 1, #diagnostic.local_order do
        local group = diagnostic.local_groups[diagnostic.local_order[i]]
        lines[#lines + 1] = string.format(
            "[L%d] %dx raw=%.2f actual=%.2f => %s | profile=%s | hook=%s | profile_attack=%s | damage_type=%s | breed=%s | result=%s | state=%s | %s",
            i, group.count, group.raw_damage, group.actual_damage, group.category, group.profile_name, group.attack_type,
            group.profile_attack_type, group.damage_type, group.breed_name, group.attack_result,
            group.state_name, group.area_evidence)
    end
    if #diagnostic.local_order == 0 then
        lines[#lines + 1] = "No local-player attack-report events were captured."
    end

    lines[#lines + 1] = ""
    local local_id = diagnostic.local_id
        or (type(self.scoreboard.me) == "function" and self.scoreboard:me() or nil)
    if local_id == nil and type(mod.local_identity) == "function" then
        local_id = select(1, mod:local_identity())
    end
    if local_id then
        local official = math.max(0, official_damage_total(self.scoreboard, local_id)
            - (finite_number(diagnostic.start_scoreboard) or 0))
        lines[#lines + 1] = string.format(
            "Local totals: raw_hook=%.2f actual_recorded=%.2f scoreboard=%.2f difference=%.2f",
            diagnostic.local_raw_included, diagnostic.local_actual_included, official,
            official - diagnostic.local_actual_included)
        local current_sources = source_snapshot(self, local_id)
        local start_sources = diagnostic.start_sources or {}
        lines[#lines + 1] = string.format(
            "Local tracked categories: melee=%.2f ranged=%.2f area=%.2f other=%.2f total=%.2f",
            current_sources.melee - (start_sources.melee or 0),
            current_sources.ranged - (start_sources.ranged or 0),
            current_sources.area - (start_sources.area or 0),
            current_sources.other - (start_sources.other or 0),
            (current_sources.melee - (start_sources.melee or 0))
                + (current_sources.ranged - (start_sources.ranged or 0))
                + (current_sources.area - (start_sources.area or 0))
                + (current_sources.other - (start_sources.other or 0)))
        lines[#lines + 1] = string.format(
            "All-player diagnostic totals: raw_hook=%.2f actual_recorded=%.2f",
            diagnostic.raw_included, diagnostic.actual_included)
    else
        lines[#lines + 1] = "Totals unavailable because the local player could not be resolved."
    end

    local file_name = diagnostic.file_name or DAMAGE_DEBUG_FILE
    diagnostic.file_name = nil
    diagnostic.automatic = false
    local ok, path, err = self:write_debug_report(file_name, lines)
    if ok then
        if not quiet then
            mod:echo("Damage diagnostic written to: " .. path)
        end
    else
        mod:error("Could not write damage diagnostic%s: %s",
            path and (" to " .. path) or "", tostring(err))
    end
    return ok
end

function Tracker:toggle_damage_diagnostic()
    if self.diagnostic.active then
        if self.diagnostic.automatic then
            mod:echo("Automatic damage capture is active and will be written when this mission ends.")
            return false
        end
        return self:finish_damage_diagnostic("manual command", false)
    end
    return self:start_damage_diagnostic(DAMAGE_DEBUG_FILE, false)
end

function Tracker:start_automatic_damage_diagnostic()
    if mod:get("auto_damage_diagnostics") ~= true then
        return false
    end
    local file_name = "improve_yourself_damage_debug_"
        .. report_file_timestamp(self.scoreboard) .. ".txt"
    return self:start_damage_diagnostic(file_name, true)
end

function Tracker:poll_automatic_damage_diagnostic()
    if not self.auto_capture_pending or self.diagnostic.active then
        return
    end
    if mod:get("auto_damage_diagnostics") ~= true then
        self.auto_capture_pending = false
        return
    end
    local game_mode_manager = Managers and Managers.state and Managers.state.game_mode
    local mode = game_mode_manager and type(game_mode_manager.game_mode_name) == "function"
        and game_mode_manager:game_mode_name()
        or nil
    if mode and mode ~= "hub" and mode ~= "prologue_hub" then
        self.auto_capture_pending = false
        self:start_automatic_damage_diagnostic()
    end
end

function Tracker:on_gameplay_exit()
    self.auto_capture_pending = false
    if self.diagnostic.active then
        self:finish_damage_diagnostic("gameplay state exit", self.diagnostic.automatic == true)
    end
end

-- Hidden History persistence
-- Scores serializes these invisible rows with the ordinary match entry. This
-- preserves category totals and condensed source labels for Victory/History
-- without maintaining a second archive format.
local function history_row(name, row_mod)
    return {
        mod = row_mod,
        name = name,
        -- Reuse Scores' existing localized label. The row is hidden,
        -- but its serializer still localizes every row before writing it.
        text = "row_damage_taken",
        validation = "ASC",
        validation_type = "ASC",
        iteration = "ADD",
        iteration_type = "ADD",
        visible = false,
        group = "improve_yourself_internal",
        data = {},
    }
end

function Tracker:history_rows(sorted_rows)
    for account_id in pairs(self.pending_scoreboard_damage) do
        self:flush_pending_scoreboard_damage(account_id, true)
    end
    local damage_row = find_row(sorted_rows, "damage_taken")
    if not damage_row then
        return nil
    end

    local rows = {}
    for _, category in ipairs(self.categories) do
        rows[category] = history_row(self.row_names[category], self.scoreboard)
    end
    local other_label_row = history_row(self.other_label_row_name, self.scoreboard)
    local source_label_rows = {}
    for _, category in ipairs(self.categories) do
        source_label_rows[category] = history_row(self.source_label_row_names[category], self.scoreboard)
    end
    for account_id in pairs(damage_row.data or {}) do
        local official_total = row_score(damage_row, account_id) or 0
        local sources = self:normalized_sources(account_id, official_total)
        for _, category in ipairs(self.categories) do
            local value = sources[category]
            rows[category].data[account_id] = {score = value, value = value}
        end
        other_label_row.data[account_id] = {
            score = sources.other,
            value = sources.other,
            text = self:other_source_label(account_id, sources.other),
        }
        for _, category in ipairs(self.categories) do
            source_label_rows[category].data[account_id] = {
                score = sources[category],
                value = sources[category],
                text = self:source_label(account_id, category),
            }
        end
    end

    local ordered = {}
    for _, category in ipairs(self.categories) do
        ordered[#ordered + 1] = rows[category]
    end
    ordered[#ordered + 1] = other_label_row
    for _, category in ipairs(self.categories) do
        ordered[#ordered + 1] = source_label_rows[category]
    end
    return ordered
end

function Tracker:append_history_rows(entry)
    if type(entry) ~= "table" or type(entry.rows) ~= "table" then
        return entry
    end
    for account_id in pairs(self.pending_scoreboard_damage) do
        self:flush_pending_scoreboard_damage(account_id, true)
    end

    local existing = {}
    for _, row in ipairs(entry.rows) do
        if row and row.name then
            existing[row.name] = true
        end
    end

    local damage_row
    for _, row in ipairs(entry.rows) do
        if row and row.name == "damage_taken" then
            damage_row = row
            break
        end
    end
    if not damage_row then
        return entry
    end

    local rows = {}
    for _, category in ipairs(self.categories) do
        local name = self.row_names[category]
        if not existing[name] then
            rows[category] = history_row(name, self.scoreboard)
        end
    end
    local other_label_row = not existing[self.other_label_row_name]
        and history_row(self.other_label_row_name, self.scoreboard)
        or nil
    local source_label_rows = {}
    for _, category in ipairs(self.categories) do
        local name = self.source_label_row_names[category]
        if not existing[name] then
            source_label_rows[category] = history_row(name, self.scoreboard)
        end
    end
    for _, player in pairs(entry.players or {}) do
        local account_id = player and player.account_id
        if account_id then
            local official_total = row_score(damage_row, account_id) or 0
            local sources = self:normalized_sources(account_id, official_total)
            player.damage_taken_sources = sources
            for _, category in ipairs(self.categories) do
                local row = rows[category]
                if row then
                    local value = sources[category]
                    row.data[account_id] = {score = value, value = value}
                end
            end
            if other_label_row then
                other_label_row.data[account_id] = {
                    score = sources.other,
                    value = sources.other,
                    text = self:other_source_label(account_id, sources.other),
                }
            end
            for _, category in ipairs(self.categories) do
                local row = source_label_rows[category]
                if row then
                    row.data[account_id] = {
                        score = sources[category],
                        value = sources[category],
                        text = self:source_label(account_id, category),
                    }
                end
            end
        end
    end

    for _, category in ipairs(self.categories) do
        if rows[category] then
            entry.rows[#entry.rows + 1] = rows[category]
        end
    end
    if other_label_row then
        entry.rows[#entry.rows + 1] = other_label_row
    end
    for _, category in ipairs(self.categories) do
        if source_label_rows[category] then
            entry.rows[#entry.rows + 1] = source_label_rows[category]
        end
    end
    return entry
end

function Tracker:augment_match(match)
    if type(match) ~= "table" then
        return match
    end
    for account_id in pairs(self.pending_scoreboard_damage) do
        -- Tactical refresh is observational. Never force an unresolved live
        -- Scoreboard increment to Other merely because the player opened TAB.
        self:flush_pending_scoreboard_damage(account_id, false)
    end
    for _, player in ipairs(match.players or {}) do
        local official_total = player.metrics and player.metrics.damage_taken
        -- While correlation is still pending, show only committed categories.
        -- The unresolved remainder must not appear temporarily as Other.
        player.damage_taken_sources = self:normalized_sources(player.account_id, official_total, false)
        player.damage_taken_other_label = self:other_source_label(
            player.account_id,
            player.damage_taken_sources.other
        )
        player.damage_taken_source_labels = {}
        for _, category in ipairs(self.categories) do
            player.damage_taken_source_labels[category] = self:source_label(player.account_id, category)
        end
    end
    local team_total = 0
    local available = false
    for _, player in ipairs(match.players or {}) do
        local value = player.metrics and finite_number(player.metrics.damage_taken)
        if value then
            team_total = team_total + value
            available = true
        end
    end
    match.team_totals = match.team_totals or {}
    match.team_totals.damage_taken = available and team_total or nil
    for _, player in ipairs(match.players or {}) do
        player.shares = player.shares or {}
        local value = player.metrics and finite_number(player.metrics.damage_taken)
        player.shares.damage_taken = value and available and team_total ~= 0 and (value / team_total * 100) or nil
    end
    match.damage_taken_sources_available = true
    return match
end

-- Installation and lifecycle hooks
-- Attach to Scores' attack-report, row-update, History-save, and
-- gameplay lifecycle paths while keeping the tracker optional and nil-safe.
function Tracker:install(scoreboard)
    if self.installed or not scoreboard then
        return false
    end
    self.installed = true
    self.scoreboard = scoreboard

    mod:command("iy_reset_damage", "Clear live Improve Yourself and Scores Damage Taken data.", function()
        local ok, message = self:reset_live_damage()
        if ok then
            mod:echo(message)
        else
            mod:error(message)
        end
    end)

    mod:command("iy_debug_damage", "Start or stop grouped incoming-damage diagnostics.", function()
        self:toggle_damage_diagnostic()
    end)

    if CLASS and CLASS.StateGameplay then
        mod:hook_safe(CLASS.StateGameplay, "on_enter", function()
            if self.diagnostic.active then
                self:finish_damage_diagnostic("new gameplay state entered", self.diagnostic.automatic == true)
            end
            self:reset()
            self.auto_capture_pending = true
        end)
    end

    if CLASS and CLASS.AttackReportManager then
        mod:hook(CLASS.AttackReportManager, "add_attack_result", function(func, manager, damage_profile, attacked_unit, attacking_unit,
            attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, ...)
            local ok, err = pcall(function()
                local account_id
                if attacked_unit and type(scoreboard.account_id_from_unit) == "function" then
                    account_id = scoreboard:account_id_from_unit(attacked_unit)
                end
                -- Match Power DI's Defense-report selection: the defender is
                -- a player and the reported damage is positive. Power DI does
                -- not require an incoming event's attack_result to be
                -- "damaged" or "died".
                if account_id and (finite_number(damage) or 0) > 0 then
                    local attacker_account_id
                    if attacking_unit and type(scoreboard.account_id_from_unit) == "function" then
                        attacker_account_id = scoreboard:account_id_from_unit(attacking_unit)
                    end
                    local breed_name = attacker_breed_name(scoreboard, attacking_unit)
                    local category = classify(damage_profile, attack_type, attacker_account_id ~= nil, breed_name)
                    local state_name = player_state_name(scoreboard, attacked_unit)
                    local previous_state = scoreboard_previous_state(scoreboard, account_id)
                    -- The hit that causes a down can update Scores before
                    -- its attack report arrives. By then the player state is
                    -- already knocked_down. Let only that report claim an
                    -- already-waiting, still-live Damage Taken increment;
                    -- reports received while simply lying down remain excluded.
                    local downing_hit = state_name == "knocked_down"
                        and has_live_pending_scoreboard_damage(self, account_id)
                    local exclude_downed = state_name == "knocked_down" and not downing_hit
                    local decision = exclude_downed and "EXCLUDE current_state_down"
                        or downing_hit and "QUEUE pending_downing_hit " .. tostring(category)
                        or "QUEUE " .. tostring(category)
                    self:add_local_timeline(account_id, string.format(
                        "REPORT %s | raw=%.2f profile=%s result=%s current_state=%s scoreboard_previous_state=%s decision=%s",
                        tostring(category), finite_number(damage) or 0,
                        tostring(safe_field(damage_profile, "name") or "nil"), tostring(attack_result),
                        tostring(state_name), tostring(previous_state), decision))
                    if exclude_downed then
                        self:capture_diagnostic(damage_profile, attack_type, breed_name, damage, 0, "excluded_downed",
                            attacked_unit, attack_result, state_name, account_id)
                    else
                        self:queue_attack(account_id, {
                            damage_profile = damage_profile,
                            attack_type = attack_type,
                            breed_name = breed_name,
                            raw_damage = damage,
                            category = category,
                            attacked_unit = attacked_unit,
                            attack_result = attack_result,
                            state_name = state_name,
                            diagnostic = self.diagnostic.active,
                        })
                    end
                end
            end)
            if not ok and not self.reported_attack_error then
                self.reported_attack_error = true
                mod:warning("Damage-source tracking skipped an event: %s", tostring(err))
            end
            return func(manager, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position,
                hit_weakspot, damage, attack_result, attack_type, damage_efficiency, ...)
        end)
    end

    if type(scoreboard.update_row_value) == "function" then
        mod:hook(scoreboard, "update_row_value", function(func, source, row_name, account_id, value, ...)
            if row_name ~= "damage_taken" or not account_id then
                return func(source, row_name, account_id, value, ...)
            end

            local row = source:get_scoreboard_row("damage_taken")
            local row_data = row and safe_field(row, "data")
            local had_row_sample = type(row_data) == "table" and rawget(row_data, account_id) ~= nil
            local before = row_score(row, account_id) or 0
            local result = func(source, row_name, account_id, value, ...)
            local after = row_score(row, account_id) or before

            -- A late join can hand the local player a bot unit whose health
            -- extension already contains accumulated damage. Scores' DIFF row
            -- sees that first cumulative sample as new damage because the new
            -- account has no previous value. Keep the sample as the DIFF
            -- baseline, but undo only its newly accumulated score. A normal
            -- first hit has a queued attack report and follows the ordinary
            -- correlation path below.
            local key = tostring(account_id)
            local local_id = local_account_id(source)
            local inherited_takeover_sample = not had_row_sample
                and after > before
                and local_id ~= nil
                and tostring(local_id) == key
                and self.pending_attacks[key] == nil
                and in_takeover_baseline_window(self)
            if inherited_takeover_sample then
                row_data = row and safe_field(row, "data")
                local sample = type(row_data) == "table" and rawget(row_data, account_id) or nil
                if type(sample) == "table" then
                    sample.score = before
                    self:add_local_timeline(account_id, string.format(
                        "BASELINE inherited takeover damage %.2f | cumulative_value=%.2f",
                        after - before, finite_number(value) or 0))
                    return result
                end
            end

            self:sync_scoreboard_damage(account_id, math.max(0, after - before))
            return result
        end)
    end

    if type(scoreboard.save_scoreboard_history_entry) == "function" then
        mod:hook(scoreboard, "save_scoreboard_history_entry", function(func, source, sorted_rows, ...)
            local groups = {}
            for index, group in ipairs(sorted_rows or {}) do
                groups[index] = group
            end

            -- Scores filters its saved rows through the user's numerical-board
            -- settings. The adapter deliberately adds no standard rows here;
            -- only Improve Yourself's mandatory Damage Taken source rows follow.
            local adapter = mod.collector_manager
                and mod.collector_manager.adapters
                and mod.collector_manager.adapters.scores
            local required = adapter
                and adapter.required_history_rows
                and adapter:required_history_rows(groups)
                or nil
            if required and #required > 0 then
                groups[#groups + 1] = required
            end

            local extra = self:history_rows(groups)
            if extra then
                groups[#groups + 1] = extra
            end
            return func(source, groups, ...)
        end)
    end

    return true
end

return Tracker
