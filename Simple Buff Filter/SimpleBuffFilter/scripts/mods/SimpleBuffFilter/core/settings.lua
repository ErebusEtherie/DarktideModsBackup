-- File: scripts/mods/SimpleBuffFilter/core/settings.lua
local mod = get_mod("SimpleBuffFilter")
if not mod then return end

--[[
settings.lua – Centralized settings handler.
Updates the flat prefs structure based on UI interactions.
]]

-- Ensure prefs API is loaded
if not mod.flush_prefs_now then
    mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/core/prefs")
end

mod._settings = mod._settings or {}
mod.settings = mod._settings

-- Helpers
local function _clamp_int(v, lo, hi)
    return math.clamp(math.floor(tonumber(v) or lo), lo, hi)
end

local function _clamp_num(v, lo, hi)
    return math.clamp(tonumber(v) or lo, lo, hi)
end

local function _choice_id_for_setting_id(setting_id)
    if type(setting_id) ~= "string" then
        return nil
    end

    if setting_id:match("^arch_") then
        return setting_id:gsub("_rule$", "_talent"):gsub("_bar$", "_talent")
    end

    return setting_id:gsub("_rule$", "_choice"):gsub("_bar$", "_choice")
end

local function _rule_id_for_choice_id(setting_id)
    if type(setting_id) ~= "string" then
        return nil
    end

    return setting_id:gsub("_choice$", "_rule"):gsub("_talent$", "_rule")
end

local function _bar_id_for_choice_id(setting_id)
    if type(setting_id) ~= "string" then
        return nil
    end

    return setting_id:gsub("_choice$", "_bar"):gsub("_talent$", "_bar")
end

local function _group_for_setting_id(setting_id)
    if type(setting_id) ~= "string" then
        return nil
    end

    local archetype = setting_id:match("^arch_(.+)_talent$") or
        setting_id:match("^arch_(.+)_rule$") or
        setting_id:match("^arch_(.+)_bar$")
    if archetype then
        return archetype
    end

    if setting_id:match("^traits_melee_") then
        return "melee"
    end

    if setting_id:match("^traits_ranged_") then
        return "ranged"
    end

    if setting_id:match("^misc_") then
        return "misc"
    end

    if setting_id:match("^moods_") then
        return "moods"
    end

    return nil
end

local function _selected_loc_is_valid(selected_loc)
    return selected_loc and selected_loc ~= "" and selected_loc ~= "__collect__"
end

local function _rebuild_options_silently()
    local Rebuilder = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/options_rebuilder")
    if Rebuilder and Rebuilder.rebuild_debounced then
        Rebuilder.rebuild_debounced(false)
    end
end

-- ===== Init =====

local function _prime_settings_cache()
    mod:info(mod.version)

    local target_bar = mod:get("bars_target_bar") or 1
    local h = mod.prefs_get_hud(target_bar)

    mod._settings["bars_x_offset"] = h.x
    mod._settings["bars_y_offset"] = h.y
    mod._settings["bars_scale"] = h.scale
    mod._settings["bars_opacity"] = h.opacity

    -- Ensure initial HUD application
    if mod.apply_hud_transforms then
        mod.apply_hud_transforms()
    end
end

function mod.on_all_mods_loaded()
    _prime_settings_cache()
end

-- ===== Change Handler =====

function mod.on_setting_changed(setting_id)
    -- 1. HUD Target Swap
    --    Silently update the sliders to reflect the newly targeted bar
    if setting_id == "bars_target_bar" then
        local target_bar = mod:get(setting_id) or 1
        local h = mod.prefs_get_hud(target_bar)

        mod:set("bars_x_offset", h.x, false)
        mod:set("bars_y_offset", h.y, false)
        mod:set("bars_scale", h.scale, false)
        mod:set("bars_opacity", h.opacity, false)
        return
    end

    -- 2. HUD Transforms
    --    Map DMF slider changes directly to mod.prefs.hud[target_bar]
    if setting_id == "bars_x_offset" or setting_id == "bars_y_offset" or
        setting_id == "bars_scale" or setting_id == "bars_opacity" then
        local target_bar = mod:get("bars_target_bar") or 1
        local val = mod:get(setting_id)

        if setting_id == "bars_x_offset" then
            mod.prefs_set_hud(target_bar, "x", _clamp_int(val, -1500, 1500))
        elseif setting_id == "bars_y_offset" then
            mod.prefs_set_hud(target_bar, "y", _clamp_int(val, -1500, 1500))
        elseif setting_id == "bars_scale" then
            mod.prefs_set_hud(target_bar, "scale", _clamp_num(val, 0.5, 3.0))
        elseif setting_id == "bars_opacity" then
            mod.prefs_set_hud(target_bar, "opacity", _clamp_int(val, 0, 255))
        end

        if mod.apply_hud_transforms then
            mod.apply_hud_transforms()
        end

        return
    end

    -- 3. Bar Changes (User changed Buff Bar 1 -> 2)
    if setting_id:match("_bar$") then
        local choice_id = _choice_id_for_setting_id(setting_id)
        local target_group = _group_for_setting_id(setting_id)
        local selected_loc = choice_id and mod:get(choice_id) or nil
        local new_bar = mod:get(setting_id)

        if target_group and _selected_loc_is_valid(selected_loc) then
            mod.prefs_set_bar_by_loc(target_group, selected_loc, new_bar)
            _rebuild_options_silently()
        end

        return
    end

    -- 4. Rule Changes (User changed "Allow" -> "Hide")
    if setting_id:match("_rule$") then
        local choice_id = _choice_id_for_setting_id(setting_id)
        local target_group = _group_for_setting_id(setting_id)
        local selected_loc = choice_id and mod:get(choice_id) or nil
        local new_rule = mod:get(setting_id)

        if target_group and _selected_loc_is_valid(selected_loc) then
            mod.prefs_set_rule_by_loc(target_group, selected_loc, new_rule)
            _rebuild_options_silently()
        end

        return
    end

    -- 5. Item Selection Changes (User selected a different item in the dropdown)
    --    Action: Update both Rule and Bar dropdowns to show the saved values for the newly selected item.
    if setting_id:match("_choice$") or setting_id:match("_talent$") then
        local selected_loc = mod:get(setting_id)
        local target_group = _group_for_setting_id(setting_id)
        local rule_id = _rule_id_for_choice_id(setting_id)
        local bar_id = _bar_id_for_choice_id(setting_id)
        local current_rule = "allow"
        local current_bar = 1

        if target_group and _selected_loc_is_valid(selected_loc) then
            if mod.prefs_get_rule_by_loc then
                current_rule = mod.prefs_get_rule_by_loc(target_group, selected_loc, "allow")
            end
            if mod.prefs_get_bar_by_loc then
                current_bar = mod.prefs_get_bar_by_loc(target_group, selected_loc, 1)
            end
        end

        -- Update the UI settings silently
        if rule_id then mod:set(rule_id, current_rule, false) end
        if bar_id then mod:set(bar_id, current_bar, false) end
        return
    end

    -- 6. Maintenance / Manual Actions
    if setting_id == "tbuff_refresh_now" and mod:get("tbuff_refresh_now") then
        local Rebuilder = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/options_rebuilder")
        if Rebuilder then
            Rebuilder.rebuild_and_flash_now()
        end
        mod:set("tbuff_refresh_now", false)
    elseif setting_id == "tbuff_wipe_now" and mod:get("tbuff_wipe_now") then
        local target = mod:get("tbuff_wipe_target") or "__all__"

        if target == "__all__" then
            mod.prefs_wipe_all()
        else
            if target == "__traits_melee__" then target = "melee" end
            if target == "__traits_ranged__" then target = "ranged" end
            if target == "__misc__" then target = "misc" end
            if target == "__moods__" then target = "moods" end

            mod.prefs_wipe_group(target)
        end

        local Rebuilder = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/options_rebuilder")
        if Rebuilder then
            Rebuilder.rebuild_and_flash_now()
        end
        mod:set("tbuff_wipe_now", false)
    end
end

-- Flush prefs when entering/exiting gameplay
function mod.on_game_state_changed(status, state_name)
    if status == "enter" or status == "exit" then
        if mod.flush_prefs_now then
            mod.flush_prefs_now()
        end
    end
end
