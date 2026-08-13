-- File: scripts/mods/SimpleBuffFilter/core/options_builders.lua
local mod = get_mod("SimpleBuffFilter")
if not mod then return end

--[[
options_builders.lua – helper builders for DMF dropdowns: pre-tints rule labels and supplies rule lists.
]]

-- Ensure prefs helpers are available even when DMF loads the data file first
if not mod.prefs then
    mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/core/prefs")
end

local Colors = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/colors")

-- ---------- rule labels (mix of mod & game loc) -----------------------------
local RULE_LABEL_KEYS = {
    allow              = "loc_settings_menu_group_display",
    hide               = "loc_social_menu_player_blocked",
    only_in_psykhanium = "loc_training_grounds_view_intro_title",
}

local function _resolve_label_key(key)
    if not key then return "" end
    if type(key) == "string" and key:find("^loc_") then
        local s = Localize(key)
        if type(s) == "string" and s ~= ("<" .. key .. ">") then
            return s
        end
        return key
    else
        local s = mod:localize(key)
        if type(s) == "string" then return s end
        return key
    end
end

-- ---------- shared, pre-tinted rule option arrays ---------------------------

local function _build_rule_options()
    local order = { "allow", "hide", "only_in_psykhanium" }
    local out = {}
    for i = 1, #order do
        local v       = order[i]
        local label   = _resolve_label_key(RULE_LABEL_KEYS[v])
        out[#out + 1] = { text = Colors.tint_rule(label, v), value = v, localize = false }
    end
    return out
end

mod.rules_shared_options        = _build_rule_options()
mod.weapon_rules_shared_options = _build_rule_options()

-- ---------- Generic builder for any group -----------------------------------

local function _get_options_for_group(target_group)
    local opts = {
        {
            title    = Localize("loc_group_finder_slot_tag_button_default_value"), -- "None"
            text     = Localize("loc_group_finder_slot_tag_button_default_value"),
            value    = "",
            localize = false
        },
        {
            title    = Localize("loc_enginseer_a__event_scan_more_data_01"), -- "Refresh..."
            text     = Localize("loc_enginseer_a__event_scan_more_data_01"),
            value    = "__collect__",
            localize = false
        },
    }

    local p = mod.prefs and mod.prefs.buffs or {}
    local unique = {} -- [loc_key] = rule

    -- First pass: Collect unique locs for this group
    for _, entry in pairs(p) do
        if entry.group == target_group and entry.loc then
            -- We assume all buffs with same Loc have same Rule (enforced by setter)
            unique[entry.loc] = entry.rule
        end
    end

    -- Sort keys (case-insensitive)
    local keys = {}
    for k in pairs(unique) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return string.lower(a) < string.lower(b) end)

    -- Build list
    for _, loc in ipairs(keys) do
        local rule = unique[loc]
        local label = loc

        -- Try to resolve localization for the label
        if loc:find("^loc_") then
            local s = Localize(loc)
            if type(s) == "string" and s ~= ("<" .. loc .. ">") then
                label = s
            end
        end

        local text = Colors.tint_rule(label, rule)
        opts[#opts + 1] = { text = text, value = loc, localize = false }
    end

    return opts
end

-- ---------- Specific group exports ------------------------------------------

function mod.get_talent_options_for(archetype)
    return _get_options_for_group(archetype)
end

function mod.get_weapon_trait_options(category)
    return _get_options_for_group(category)
end

function mod.get_misc_buff_options()
    return _get_options_for_group("misc")
end

function mod.get_mood_options()
    return _get_options_for_group("moods")
end
