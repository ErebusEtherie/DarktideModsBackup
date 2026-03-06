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
local function _clamp_int(v, lo, hi) return math.clamp(math.floor(tonumber(v) or lo), lo, hi) end
local function _clamp_num(v, lo, hi) return math.clamp(tonumber(v) or lo, lo, hi) end

-- ===== Init =====

local function _prime_settings_cache()
    mod:info(mod.version)
    -- 1. Load HUD settings from our custom Prefs (not DMF standard storage)
    -- We sync these into mod._settings so the sliders show the correct stored value on load.
    local h                        = mod.prefs_get_hud()
    mod._settings["bars_x_offset"] = h.x
    mod._settings["bars_y_offset"] = h.y
    mod._settings["bars_scale"]    = h.scale
    mod._settings["bars_opacity"]  = h.opacity

    -- 2. Ensure initial HUD application
    if mod.apply_hud_transforms then
        mod.apply_hud_transforms()
    end
end

function mod.on_all_mods_loaded()
    _prime_settings_cache()
end

-- ===== Change Handler =====

function mod.on_setting_changed(setting_id)
    -- 1. HUD Transforms
    --    Map DMF slider changes directly to mod.prefs.hud
    if setting_id == "bars_x_offset" or setting_id == "bars_y_offset" or
        setting_id == "bars_scale" or setting_id == "bars_opacity" then
        local val = mod:get(setting_id)

        if setting_id == "bars_x_offset" then
            mod.prefs_set_hud("x", _clamp_int(val, -1500, 1500))
        elseif setting_id == "bars_y_offset" then
            mod.prefs_set_hud("y", _clamp_int(val, -1500, 1500))
        elseif setting_id == "bars_scale" then
            mod.prefs_set_hud("scale", _clamp_num(val, 0.5, 3.0))
        elseif setting_id == "bars_opacity" then
            mod.prefs_set_hud("opacity", _clamp_int(val, 0, 255))
        end

        if mod.apply_hud_transforms then
            mod.apply_hud_transforms()
        end
        return
    end

    -- 2. Rule Changes (User changed "Allow" -> "Hide")
    --    Pattern: setting_id ends in "_rule" (e.g. "arch_veteran_rule", "traits_melee_rule")
    if setting_id:match("_rule$") then
        -- Identify the corresponding Item Choice setting ID
        local choice_id = setting_id:gsub("_rule$", "_choice")
        if setting_id:match("^arch_") then
            choice_id = setting_id:gsub("_rule$", "_talent") -- Archetypes use "_talent" suffix
        end

        local selected_loc = mod:get(choice_id)
        local new_rule     = mod:get(setting_id)

        -- If a valid item is selected, update ALL buffs sharing this localization key
        if selected_loc and selected_loc ~= "" and selected_loc ~= "__collect__" then
            mod.prefs_set_rule_by_loc(selected_loc, new_rule)

            -- Trigger a silent options rebuild to refresh color tints
            local Rebuilder = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/options_rebuilder")
            if Rebuilder and Rebuilder.rebuild_debounced then
                Rebuilder.rebuild_debounced(false)
            end
        end
        return
    end

    -- 3. Item Selection Changes (User selected a different item in the dropdown)
    --    Pattern: Ends in "_choice" or "_talent"
    --    Action: We must update the Rule dropdown to show the saved rule for the newly selected item.
    if setting_id:match("_choice$") or setting_id:match("_talent$") then
        local selected_loc = mod:get(setting_id)

        -- Derive the corresponding rule setting ID
        local rule_id = setting_id:gsub("_choice$", "_rule"):gsub("_talent$", "_rule")

        -- Find the rule for this loc in our prefs
        local current_rule = "allow" -- default
        if mod.prefs and mod.prefs.buffs then
            for _, entry in pairs(mod.prefs.buffs) do
                if entry.loc == selected_loc then
                    current_rule = entry.rule
                    break
                end
            end
        end

        -- Update the UI setting silently (false = no event trigger) so the dropdown reflects reality
        mod:set(rule_id, current_rule, false)
        return
    end

    -- 4. Maintenance / Manual Actions
    if setting_id == "tbuff_refresh_now" and mod:get("tbuff_refresh_now") then
        local Rebuilder = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/options_rebuilder")
        if Rebuilder then Rebuilder.rebuild_and_flash_now() end
        mod:set("tbuff_refresh_now", false)
    elseif setting_id == "tbuff_wipe_now" and mod:get("tbuff_wipe_now") then
        local target = mod:get("tbuff_wipe_target") or "__all__"

        if target == "__all__" then
            mod.prefs_wipe_all()
        else
            -- Map special wipe targets if necessary, or pass group name directly
            if target == "__traits_melee__" then target = "melee" end
            if target == "__traits_ranged__" then target = "ranged" end
            if target == "__misc__" then target = "misc" end

            mod.prefs_wipe_group(target)
        end

        local Rebuilder = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/options_rebuilder")
        if Rebuilder then Rebuilder.rebuild_and_flash_now() end
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
