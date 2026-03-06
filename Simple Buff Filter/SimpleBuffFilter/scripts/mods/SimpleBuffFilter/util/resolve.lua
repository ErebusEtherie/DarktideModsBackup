-- File: scripts/mods/SimpleBuffFilter/util/resolve.lua
local mod = get_mod("SimpleBuffFilter"); if not mod then return {} end
--[[
resolve.lua – shared resolver utilities: archetype discovery & order; talent lookups; archetype-prefix checks; player_buff display_title fallback; breed display name mapping; derives ids from hud_icon paths; exported as mod.resolve.
]]
local M = {}
mod.resolve = M -- expose on mod.* for cross-file use

-- ------- utils -------
local function _try_require(path)
    return require(path)
end

local function _starts_with(s, p)
    return type(s) == "string" and type(p) == "string" and s:sub(1, #p) == p
end

-- Returns true if `s` has `prefix` at position `pos` (default 1) and
-- the next character is a "boundary" (EOS, "_" or non-alphanumeric).
local function _starts_with_prefix_and_boundary_at(s, prefix, pos)
    if type(s) ~= "string" or type(prefix) ~= "string" then
        return false
    end
    pos = tonumber(pos) or 1
    if pos < 1 then pos = 1 end

    local e = pos + #prefix - 1
    if s:sub(pos, e) ~= prefix then
        return false
    end

    local next_char = s:sub(e + 1, e + 1)
    if next_char == "" or next_char == "_" then
        return true
    end
    -- Non-alphanumeric counts as a boundary (e.g. "-", space)
    return not next_char:match("[%w]")
end

-- Collapse "zealot_1"/"zealot_3" -> "zealot"
local function _base_arch(key)
    return string.match(key or "", "^([A-Za-z]+)") or key
end

-- Derive a template id from the hud_icon path: ".../<arch>/<id>" -> "id"
local function _key_from_hud_icon(t)
    local p = t and t.hud_icon
    if type(p) ~= "string" or p == "" then return nil end
    local base = p:match("([^/]+)$") -- last segment
    if not base or base == "" then return nil end
    -- DT paths usually have no extension; be defensive anyway
    base = base:gsub("%.%w+$", "")
    return base
end

-- Generic negative-check helper (defensive across builds)
local function _is_negative_buff_template(t)
    return t and (
        t.is_negative == true or t.is_debuff == true or t.negative_stat == true or t.negative == true
    ) or false
end

-- Helper to strip noise for fuzzy matching (e.g. area, buff, ability, underscores)
-- Used to link adamant_drone_improved_buff -> adamant_area_buff_drone_improved
local function _to_skeleton(str)
    if type(str) ~= "string" then return "" end
    -- Remove noise words and underscores
    return str:gsub("[%_%-]", "")
        :gsub("buff", ""):gsub("area", ""):gsub("ability", "")
        :gsub("keystone", ""):gsub("passive", ""):gsub("stat", "")
        :gsub("proc", ""):gsub("effect", "")
end

-- Lightweight caches to avoid repeated pcall(require, ...) + table lookups
mod._arch_data_cache          = mod._arch_data_cache or {}     -- [arch] -> archetype data table
mod._talents_table_cache      = mod._talents_table_cache or {} -- [arch] -> talents file table (any supported shape)
mod._breed_prefix_to_display  = mod._breed_prefix_to_display or
    nil                                                        -- { ["renegade_flamer"] = "loc_breed_display_name_renegade_flamer", ... }

-- NEW: in-session memo for template→talent fallback
mod._template_to_talent_cache = mod._template_to_talent_cache or {} -- [template_id] = {arch, tid, disp|false} | false

-- =========================================
--  ARCHETYPE DISCOVERY + TALENT LOOKUPS
-- =========================================

-- ------- archetypes (discover + order) -------
function M.init_archetypes()
    if type(mod._archetypes) ~= "table" then mod._archetypes = {} end
    if type(mod._arch_order) ~= "table" then mod._arch_order = {} end
    if next(mod._archetypes) ~= nil then
        return mod._archetypes
    end

    -- PRIMARY SOURCE OF TRUTH: UI lists (only these get groups)
    local UiSettings = _try_require("scripts/settings/ui/ui_settings")
    if UiSettings and type(UiSettings.archetype_font_icon) == "table" then
        for base, _ in pairs(UiSettings.archetype_font_icon) do
            mod._archetypes[base] = true

            -- optional: pick up UI ordering if the per-archetype file exposes it
            if mod._arch_order[base] == nil then
                local ad = _try_require(("scripts/settings/archetype/archetypes/%s_archetype"):format(base))
                if ad and ad.ui_selection_order ~= nil then
                    mod._arch_order[base] = ad.ui_selection_order
                    mod._arch_data_cache[base] = ad
                end
            end
        end
    end

    -- FALLBACK (only if UI list wasn’t available): old TalentSettings scan
    if next(mod._archetypes) == nil then
        local TalentSettings = _try_require("scripts/settings/talent/talent_settings")
        if TalentSettings then
            for k, v in pairs(TalentSettings) do
                if type(v) == "table" then
                    local base = string.match(k or "", "^([A-Za-z]+)") or k
                    if base and base ~= "" then
                        mod._archetypes[base] = true
                    end
                end
            end
        end
    end

    return mod._archetypes
end

function M.sorted_archetypes()
    local list = {}
    for a in pairs(mod._archetypes or {}) do
        list[#list + 1] = a
    end
    table.sort(list, function(a, b)
        local oa = (mod._arch_order and mod._arch_order[a]) or 999
        local ob = (mod._arch_order and mod._arch_order[b]) or 999
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return list
end

-- archetype-prefixed name check (e.g., adamant_*, zealot_*, ogryn_*, veteran_*, psyker_*, broker_*, cryptic_*)
function M.is_archetype_prefixed_name(name)
    if type(name) ~= "string" then return false end
    M.init_archetypes()
    for arch in pairs(mod._archetypes or {}) do
        if name:find("^" .. arch .. "_") == 1 then
            return true
        end
    end
    return false
end

-- ------- lookups (buffs/talents/archetypes) -------
function M.archetype_from_talent_id(talent_id)
    if not (talent_id and type(talent_id) == "string") then return nil end
    M.init_archetypes()
    local archs = mod._archetypes or {}
    local prefix = string.match(talent_id, "^([A-Za-z]+)%_")
    if prefix and archs[prefix] then
        return prefix
    end
    if archs[talent_id] then
        return talent_id
    end
    return nil
end

local function _talent_bank_for(archetype)
    local talents_file = mod._talents_table_cache[archetype]
    if talents_file == nil then
        talents_file = _try_require(("scripts/settings/ability/archetype_talents/talents/%s_talents"):format(archetype))
        mod._talents_table_cache[archetype] = talents_file or false
    elseif talents_file == false then
        return nil
    end
    if not talents_file then return nil end
    return talents_file.talents or talents_file.talents_by_name or talents_file.Talents or talents_file
end

-- Find by talent id or a few common alias fields
local function _find_talent_entry(bank, talent_id)
    if type(bank) ~= "table" then return nil end
    local entry = bank[talent_id]
    if entry then return entry end
    for _, def in pairs(bank) do
        if type(def) == "table" then
            if def.identifier == talent_id or def.talent == talent_id or def.name == talent_id then
                return def
            end
        end
    end
    return nil
end

-- match a buff template name against a talent's passive.buff_template_name(s)
local function _passive_declares_template(def, candidate)
    if type(def) ~= "table" or type(candidate) ~= "string" or candidate == "" then return false end
    local p = def.passive
    if not p then return false end

    local function _match(v)
        if type(v) == "string" then return v == candidate end
        return false
    end

    -- string
    if _match(p.buff_template_name) then return true end
    -- plural (some talents expose arrays)
    if type(p.buff_template_names) == "table" then
        for _, v in ipairs(p.buff_template_names) do
            if _match(v) then return true end
        end
    end
    -- some talents use identifier as the template id
    if _match(p.identifier) then return true end
    -- or arrays of identifiers
    if type(p.identifier) == "table" then
        for _, v in ipairs(p.identifier) do
            if _match(v) then return true end
        end
    end

    return false
end

-- NEW: Recursive search for buff_template_name within a talent definition (e.g. inside format_values)
-- Limit depth to avoid stack issues, though 5 is plenty for talent data structures.
local function _recursively_find_buff_ref(t, target, depth)
    if depth <= 0 then return false end
    for k, v in pairs(t) do
        if k == "buff_template_name" and v == target then
            return true
        end
        if type(v) == "table" then
            if _recursively_find_buff_ref(v, target, depth - 1) then
                return true
            end
        end
    end
    return false
end

-- Find the talent KEY whose passive references the given buff template
local function _find_talent_by_buff_template(bank, candidate)
    if type(bank) ~= "table" then return nil, nil end
    for key, def in pairs(bank) do
        if type(def) == "table" and _passive_declares_template(def, candidate) then
            return key, def
        end
    end
    return nil, nil
end

function M.talent_display_name_loc(archetype, talent_id)
    if not (archetype and talent_id) then return nil end
    local bank = _talent_bank_for(archetype)
    if not bank then return nil end
    local entry = _find_talent_entry(bank, talent_id)
    local key   = entry and entry.display_name
    if type(key) == "string" and key ~= "" and key ~= "-" then
        return key
    end
    return nil
end

-- ===== suffix-stripping for buff→talent fallback matching =====
local _TALENT_SUFFIXES = {
    "_stat_buff", "_ranged_visual", "_melee_visual", "_buff", "_stacks", "_stack", "_parent", "_child", "_duration",
    "_proc", "_stat", "_passive", "_ranged", "_melee", "_visual", "_effect", "_exhaustion", "_improved",
}

-- Public: normalize a buff template id for talent lookup (strip known suffixes)
function M.normalize_buff_id_for_talent_lookup(id)
    if type(id) ~= "string" or id == "" then return id end
    local out = id
    local changed = true
    while changed do
        changed = false
        for i = 1, #_TALENT_SUFFIXES do
            local suf = _TALENT_SUFFIXES[i]
            if out:sub(- #suf) == suf then
                out = out:sub(1, - #suf - 1)
                changed = true
                break
            end
        end
    end
    return out
end

-- ============================================================
--  Fallback: by TABLE KEY / RUNTIME TEMPLATE NAME (no t.name)
-- ============================================================
-- Map a buff template to a talent without using t.name:
--  • prefer the provided key (runtime template id)
--  • if missing, derive from the hud_icon basename
--  • require archetype prefix (raw or normalized)
--  • then probe the talent bank by:
--      a) direct key match (raw → normalized)
--      b) passive.buff_template_name(s) matching the buff id (raw → normalized)
--      c) DEEP SEARCH: recursively check sub-tables (format_values, etc)
--      d) NEW: "Skeleton" Fuzzy match against Special Rule Identifier or Talent ID
--      e) "starts with" prefix match, preferring the longest match
--  • require a valid talent display_name
function M.talent_from_template_key(t, key)
    if not (t and t.hud_icon) then return nil end -- gate non-HUD/system templates

    local raw = (type(key) == "string" and key ~= "" and key) or _key_from_hud_icon(t)
    if not raw then return nil end

    -- MEMO: return immediately if we've seen this template id before
    local memo = mod._template_to_talent_cache[raw]
    if memo ~= nil then
        if memo == false then return nil end
        return memo[1], memo[2], (memo[3] ~= false and memo[3] or nil)
    end

    local norm = M.normalize_buff_id_for_talent_lookup(raw)

    -- Determine archetypes to check
    local archetypes_to_check = {}
    local seen_archs = {}

    -- 1. Try derived prefix
    local prefix_arch = M.archetype_from_talent_id(raw) or M.archetype_from_talent_id(norm)
    if prefix_arch then
        table.insert(archetypes_to_check, prefix_arch)
        seen_archs[prefix_arch] = true
    else
        -- 2. Try local player archetype (heuristic for unprefixed buffs like 'vultures_mark')
        local lp_profile = mod.tbf_ctx and mod.tbf_ctx.local_player_profile and mod.tbf_ctx.local_player_profile()
        local lp_arch = lp_profile and lp_profile.archetype and lp_profile.archetype.name
        if lp_arch and mod._archetypes[lp_arch] then
            table.insert(archetypes_to_check, lp_arch)
            seen_archs[lp_arch] = true
        end

        -- 3. Fallback: all other archetypes
        for a in pairs(mod._archetypes or {}) do
            if not seen_archs[a] then
                table.insert(archetypes_to_check, a)
            end
        end
    end

    -- Precompute skeleton for the raw buff ID AND normalized ID (fuzzy match targets)
    local buff_skeleton = _to_skeleton(raw)
    local buff_norm_skeleton = _to_skeleton(norm)

    -- === MATCHING LOGIC ===

    for _, arch in ipairs(archetypes_to_check) do
        local bank = _talent_bank_for(arch)

        if bank then
            local best_match_key = nil
            local best_match_len = 0

            for talent_id, talent_def in pairs(bank) do
                if type(talent_def) == "table" then
                    -- 1. Direct key match (highest priority)
                    if talent_id == raw or talent_id == norm then
                        local disp = M.talent_display_name_loc(arch, talent_id)
                        if disp then
                            mod._template_to_talent_cache[raw] = { arch, talent_id, disp or false }
                            return arch, talent_id, disp
                        end
                    end

                    -- 2. Passive buff_template_name match (high priority)
                    if _passive_declares_template(talent_def, raw) or _passive_declares_template(talent_def, norm) then
                        local disp = M.talent_display_name_loc(arch, talent_id)
                        if disp then
                            mod._template_to_talent_cache[raw] = { arch, talent_id, disp or false }
                            return arch, talent_id, disp
                        end
                    end

                    -- 3. Deep search in format_values/find_value
                    if _recursively_find_buff_ref(talent_def, raw, 5) or _recursively_find_buff_ref(talent_def, norm, 5) then
                        local disp = M.talent_display_name_loc(arch, talent_id)
                        if disp then
                            mod._template_to_talent_cache[raw] = { arch, talent_id, disp or false }
                            return arch, talent_id, disp
                        end
                    end

                    -- 4. Fuzzy / Skeleton Matching
                    local tid_skeleton = _to_skeleton(talent_id)
                    local is_skeleton_match = (tid_skeleton == buff_skeleton or tid_skeleton == buff_norm_skeleton)

                    -- Check Special Rule Identifier first
                    local sr = talent_def.special_rule and talent_def.special_rule.identifier
                    if sr then
                        if type(sr) == "string" then
                            local sr_skeleton = _to_skeleton(sr)
                            if sr_skeleton == buff_skeleton or sr_skeleton == buff_norm_skeleton then
                                is_skeleton_match = true
                            end
                        elseif type(sr) == "table" then
                            for _, identifier in ipairs(sr) do
                                if type(identifier) == "string" then
                                    local sr_skeleton = _to_skeleton(identifier)
                                    if sr_skeleton == buff_skeleton or sr_skeleton == buff_norm_skeleton then
                                        is_skeleton_match = true
                                        break
                                    end
                                end
                            end
                        end
                    end

                    -- 4b. Substring Fuzzy Match (Long IDs only)
                    -- Captures cases like 'vulturesmark' inside 'brokerkeystonevulturesmarkonkill'
                    if not is_skeleton_match and (#tid_skeleton > 10 or #buff_skeleton > 10) then
                        if tid_skeleton:find(buff_skeleton, 1, true) or buff_skeleton:find(tid_skeleton, 1, true) then
                            is_skeleton_match = true
                        end
                    end

                    if is_skeleton_match then
                        local disp = M.talent_display_name_loc(arch, talent_id)
                        if disp then
                            mod._template_to_talent_cache[raw] = { arch, talent_id, disp or false }
                            return arch, talent_id, disp
                        end
                    end

                    -- 5. "Starts with" prefix match (fallback)
                    local norm_talent_id = M.normalize_buff_id_for_talent_lookup(talent_id)
                    if norm:find("^" .. norm_talent_id) == 1 then
                        local current_len = #norm_talent_id
                        if current_len > best_match_len then
                            best_match_len = current_len
                            best_match_key = talent_id
                        end
                    end
                end
            end

            -- If we found a prefix match in this archetype, use it
            if best_match_key then
                local disp = M.talent_display_name_loc(arch, best_match_key)
                if disp then
                    mod._template_to_talent_cache[raw] = { arch, best_match_key, disp or false }
                    return arch, best_match_key, disp
                end
            end
        end
    end

    -- Negative memo (no match)
    mod._template_to_talent_cache[raw] = false
    return nil -- No match found
end

function M.archetype_loc_keys(archetype)
    local ad = mod._arch_data_cache[archetype]
    if ad == nil then
        ad = _try_require(("scripts/settings/archetype/archetypes/%s_archetype"):format(archetype))
        mod._arch_data_cache[archetype] = ad or false
    elseif ad == false then
        return nil
    end
    if not ad then return nil end
    return {
        name_loc  = ad.archetype_name,
        title_loc = ad.archetype_title,
        desc_loc  = ad.archetype_description,
        order     = ad.ui_selection_order,
    }
end

-- =========================================
--  BREED-NEGATIVE HUD → breed.display_name (loc_*)
-- =========================================

local function _normalize_breed_key(k)
    if type(k) ~= "string" then return nil end
    if k:sub(-6) == "_breed" then
        return k:sub(1, -7)
    end
    return k
end

-- NEW: allow aliasing hazards that drop the faction prefix (e.g., beast_of_nurgle_* instead of chaos_beast_of_nurgle_*)
local FACTION_PREFIXES = { "chaos_", "renegade_", "cultist_" }

local function _strip_faction_prefix(s)
    if type(s) ~= "string" then return s end
    for i = 1, #FACTION_PREFIXES do
        local p = FACTION_PREFIXES[i]
        if s:sub(1, #p) == p then
            return s:sub(#p + 1)
        end
    end
    return s
end

local function _ensure_breed_prefix_map()
    if type(mod._breed_prefix_to_display) == "table" and next(mod._breed_prefix_to_display) ~= nil then
        return
    end
    local Breeds = _try_require("scripts/settings/breed/breeds")
    local map = {}
    if type(Breeds) == "table" then
        for key, data in pairs(Breeds) do
            local short = _normalize_breed_key(key) or (data and _normalize_breed_key(data.name)) or key
            local loc   = data and data.display_name
            if type(short) == "string" and short ~= "" and type(loc) == "string" and loc:find("^loc_") then
                -- 1) Full key (e.g., chaos_beast_of_nurgle)
                map[short] = loc

                -- 2) Alias without faction (e.g., beast_of_nurgle)
                local alias = _strip_faction_prefix(short)
                if alias ~= short and map[alias] == nil then
                    map[alias] = loc
                end
            end
        end
    end
    mod._breed_prefix_to_display = map
end

-- Public: return loc_breed_display_name_* if this buff template is a negative HUD hazard
-- whose template name starts with a known breed prefix (with "_" boundary).
-- Handles plain prefix (e.g., "cultist_grenadier_*") and "in_" lead-in (e.g., "in_cultist_grenadier_*").
-- Expects a buff template table `t` that includes fields: t.name, t.hud_icon, t.is_negative.
-- (This grouping logic still uses t.name by design; it is unrelated to talent mapping.)
function M.breed_loc_key_from_buff_template(t)
    if not (t and t.name and t.hud_icon and t.is_negative) then return nil end
    local name = t.name
    if type(name) ~= "string" or name == "" then return nil end
    _ensure_breed_prefix_map()

    -- Check both the start of the string and (if present) after an "in_" lead-in.
    local has_in_prefix = name:sub(1, 3) == "in_"

    for prefix, loc in pairs(mod._breed_prefix_to_display or {}) do
        -- Direct match at start
        if _starts_with_prefix_and_boundary_at(name, prefix, 1) then
            return loc
        end
        -- "in_" + breed prefix + "_" (offset = 4 because "in_" is 3 chars)
        if has_in_prefix and _starts_with_prefix_and_boundary_at(name, prefix, 4) then
            return loc
        end
    end
    return nil
end

-- NEW: prop_* negative HUD hazards → fixed loc key group
local PROP_GROUP_LOC = "loc_adamant_male_c__warning_exploding_barrel_03"

-- Public: return PROP_GROUP_LOC if (a) hud_icon, (b) is_negative, (c) name starts with "prop_",
-- and (d) it did NOT match a breed group.
function M.prop_group_loc_key_from_buff_template(t)
    if not (t and t.name and t.hud_icon and t.is_negative) then return nil end
    if not _starts_with(t.name, "prop_") then return nil end
    -- Do not overlap with breed-grouping
    local breed_loc = M.breed_loc_key_from_buff_template and M.breed_loc_key_from_buff_template(t)
    if breed_loc then return nil end
    return PROP_GROUP_LOC
end

-- NEW: knocked_down_* HUD hazards -> fixed loc key group
local KNOCKED_DOWN_GROUP_LOC = "loc_veteran_male_a__knocked_down_1_01"

-- Public: return KNOCKED_DOWN_GROUP_LOC if (a) hud_icon, (b) name starts with "knocked_down_".
function M.knocked_down_group_loc_key_from_buff_template(t)
    if not (t and t.hud_icon) then return nil end
    if not _starts_with(t.name, "knocked_down_") then return nil end
    return KNOCKED_DOWN_GROUP_LOC
end

-- NEW: hazard groups by hud_icon basename
--   • *_toxic_gas   → loc_circumstance_toxic_gas_title  (requires negative)
--   • *_smoke_fog   → loc_ability_smoke_grenade         (may be non-negative)
local TOXIC_GAS_GROUP_LOC = "loc_circumstance_toxic_gas_title"
local SMOKE_FOG_GROUP_LOC = "loc_ability_smoke_grenade"
local SLIME_GROUP_LOC     = "loc_havoc_enemies_corrupted_name"

-- Public: map certain environmental hazards (by hud_icon basename) to fixed loc keys.
-- Avoid overlapping with breed/prop groupings.
function M.hazard_group_loc_key_from_buff_template(t, tname)
    if not (t and t.hud_icon) then return nil end

    -- Don't override breed/prop groupings
    if M.breed_loc_key_from_buff_template and M.breed_loc_key_from_buff_template(t) then return nil end
    if M.prop_group_loc_key_from_buff_template and M.prop_group_loc_key_from_buff_template(t) then return nil end

    local key = (type(tname) == "string" and tname ~= "" and tname) or _key_from_hud_icon(t)
    if type(key) ~= "string" or key == "" then return nil end

    -- Toxic gas: only when negative
    if key:match("_toxic_gas$") and _is_negative_buff_template(t) then
        return TOXIC_GAS_GROUP_LOC
    end

    -- Smoke/fog: can be non-negative
    if key:match("_smoke_fog$") then
        return SMOKE_FOG_GROUP_LOC
    end

    -- Slime: only when negative
    if key:find("_slime", 1, true) and _is_negative_buff_template(t) then
        return SLIME_GROUP_LOC
    end

    -- Liquid Fire: map to Prop (Exploding Barrel) group, only when negative
    if key:find("leaving_liquid_fire", 1, true) and _is_negative_buff_template(t) then
        return PROP_GROUP_LOC
    end

    return nil
end

-- =========================================
--  HARDCODED LOC OVERRIDES (General Purpose)
-- =========================================
-- General table of hardcoded mappings used for scenarios where standard resolution
-- (via talents/items) yields incorrect results or is not practical.
local HARDCODED_BUFF_LOCS = {
    -- Misc
    ["player_spawn_grace"] = "loc_interrogator_a__mission_core_objective_02_a_01",
    ["syringe_broker_buff"] = "loc_broker_stimm_builder_view_display_name",
    ["windup_increases_power_default_parent"] = "loc_weapon_family_crowbar_p1_m1",

    -- Veteran (Fix for incorrect related_talents in source)
    ["veteran_melee_crits_increase_damage"] = "loc_talent_veteran_crits_rend",
}

function M.static_misc_loc_key_for_template(id_or_key)
    if type(id_or_key) == "string" then
        -- NEW: direct mechanical localization for hordes buffs
        -- e.g. "hordes_buff_stacking_crit_damage_on_critical_hit"
        --   -> "loc_hordes_buff_stacking_crit_damage_on_critical_hit_title"
        if id_or_key:sub(1, 12) == "hordes_buff_" then
            return "loc_" .. id_or_key .. "_title"
        end

        -- Group any *_toxic_gas or *_smoke_fog id under unified labels
        if id_or_key:match("_toxic_gas$") then
            return TOXIC_GAS_GROUP_LOC
        end
        if id_or_key:match("_smoke_fog$") then
            return SMOKE_FOG_GROUP_LOC
        end
        if id_or_key:find("in_slime", 1, true) then
            return SLIME_GROUP_LOC
        end
        if id_or_key:find("leaving_liquid_fire", 1, true) then
            return PROP_GROUP_LOC
        end

        local v = HARDCODED_BUFF_LOCS[id_or_key]
        if v then return v end
    end
    return nil
end

-- Convenience: directly localize breed display (returns string or nil).
function M.localized_breed_name_from_buff_template(t)
    local key = M.breed_loc_key_from_buff_template(t)
    if not key then return nil end

    local val
    if _G.Localize then
        val = _G.Localize(key)
    elseif Managers and Managers.localization then
        val = Managers.localization:localize(key)
    end

    if type(val) == "string" and val ~= "" and val ~= ("<" .. key .. ">") then
        return val
    end
    return nil
end

-- =========================================
--  PLAYER BUFF TEMPLATES → display_title (loc_*)
-- =========================================

-- lookup display_title loc_* from player buff templates
function M.player_buff_display_title_loc(template_name)
    if type(template_name) ~= "string" then return nil end
    local tbl = require("scripts/settings/buff/player_buff_templates")
    if type(tbl) ~= "table" then return nil end
    local t = tbl[template_name] or (tbl.templates and tbl.templates[template_name])
    local key = t and t.display_title
    return (type(key) == "string" and key:find("^loc_")) and key or nil
end

-- =========================================
--  SYRINGE → loc_*  (DEPRECATED LOGIC REMOVED)
--  Compatibility shim: delegate to util/syringe_loc.lua
-- =========================================

-- Keep the public surface but route through the new pickup-driven mapper.
-- NOTE: util/syringe_loc.lua must be loaded somewhere (e.g., SimpleBuffFilter.lua bootstrap).
local function _ensure_mapper_loaded()
    if not mod.syringe_loc_for_buff then
        mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/syringe_loc")
    end
end

-- Broad check: anything beginning with "syringe_" counts as a syringe buff.
function M.is_syringe_buff(template_name)
    return type(template_name) == "string" and template_name:find("^syringe_") ~= nil
end

-- Return the loc_* key for a syringe buff template name, or nil.
function M.syringe_loc_key_from_buff(template_name)
    if type(template_name) ~= "string" then return nil end
    _ensure_mapper_loaded()
    if not mod.syringe_loc_for_buff then return nil end
    local loc_key = mod.syringe_loc_for_buff(template_name, nil)
    if type(loc_key) == "string" and loc_key:find("^loc_") then
        return loc_key
    end
    return nil
end

-- Convenience: directly localize (returns localized string or nil).
function M.localized_syringe_name_from_buff(template_name)
    local key = M.syringe_loc_key_from_buff(template_name)
    if not key then return nil end

    local val
    if _G.Localize then
        val = _G.Localize(key)
    elseif Managers and Managers.localization then
        val = Managers.localization:localize(key)
    end

    if type(val) == "string" and val ~= "" and val ~= ("<" .. key .. ">") then
        return val
    end

    return nil
end

return M
