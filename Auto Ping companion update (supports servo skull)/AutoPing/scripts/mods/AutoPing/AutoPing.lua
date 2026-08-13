local mod = get_mod("AutoPing")

local cooldown = 0.0

-- All available enemies that can be tagged (updated with missing boss enemies)
local all_enemies = {
    "renegade_berzerker",
    "cultist_berzerker",
    "cultist_flamer",
    "renegade_flamer",
    "renegade_netgunner",
    "renegade_sniper",
    "cultist_grenadier",
    "renegade_grenadier",
    "chaos_hound",
    "chaos_poxwalker_bomber",
    "renegade_gunner",
    "cultist_gunner",
    "renegade_shocktrooper",
    "cultist_shocktrooper",
    "chaos_ogryn_executor",
    "chaos_ogryn_gunner",
    "chaos_ogryn_bulwark",
    "renegade_executor",
    "cultist_mutant",
    "chaos_spawn",
    "chaos_daemonhost",
    "chaos_plague_ogryn",
    "chaos_beast_of_nurgle",
    "renegade_plasma_gunner",
    "chaos_ogryn_houndmaster",
    "chaos_armored_hound"
}

-- Function to get enemies by priority level based on user settings
local function getEnemiesByPriority(priority_level)
    local enemies = {}
    for _, enemy in ipairs(all_enemies) do
        local setting_key = "priority_" .. enemy
        local enemy_priority = mod:get(setting_key)
        if enemy_priority == priority_level then
            table.insert(enemies, enemy)
        end
    end
    return enemies
end

-- Function to check if enemy is in a specific priority category
local function isInPriorityCategory(enemy_name, priority_level)
    local setting_key = "priority_" .. enemy_name
    local enemy_priority = mod:get(setting_key)
    return enemy_priority == priority_level
end

-- Function to check if enemy should be tagged based on current settings
local function shouldTagEnemy(enemy_name)
    if not enemy_name then
        return false
    end

    -- Check filter mode
    local filter_mode = mod:get("filter_mode")

    if filter_mode == "all_pingable" then
        -- Tag anything that's not disabled
        local setting_key = "priority_" .. enemy_name
        local enemy_priority = mod:get(setting_key)
        return enemy_priority and enemy_priority ~= "disabled"
    elseif filter_mode == "high_priority_only" then
        return isInPriorityCategory(enemy_name, "high")
    elseif filter_mode == "specials_and_elites" then
        return isInPriorityCategory(enemy_name, "high") or isInPriorityCategory(enemy_name, "medium")
    elseif filter_mode == "custom" then
        -- Check individual enemy type settings (legacy support)
        local setting_key = "tag_" .. enemy_name
        return mod:get(setting_key)
    end

    return false
end

-- Function to get enemy priority (lower number = higher priority)
local function getEnemyPriority(enemy_name)
    -- Boss enemies always have highest priority (fixed boss list)
    local boss_enemies = {
        "chaos_beast_of_nurgle",
        "chaos_plague_ogryn",
        "chaos_daemonhost",
        "chaos_spawn",
        "chaos_ogryn_houndmaster"
    }

    for _, boss in ipairs(boss_enemies) do
        if boss == enemy_name then
            return 1
        end
    end

    -- Get priority from user settings
    local setting_key = "priority_" .. enemy_name
    local enemy_priority = mod:get(setting_key)

    if enemy_priority == "high" then
        return 2
    elseif enemy_priority == "medium" then
        return 3
    else
        return 4  -- disabled or unknown
    end
end

local taggedTarget = nil
local manual = false
local creating_companion_tag = false  -- Prevent recursion
local creating_auto_tag = false  -- Distinguish the mod's own regular tag calls from real manual taps

-- Function to detect if we should send companion attack command instead of regular ping
local function shouldSendCompanionCommand()
    -- Check if companion commands are enabled
    if not mod:get("companion_attack_mode") then
        return false
    end

    local player_unit = Managers.player:local_player_safe(1).player_unit
    if not player_unit then
        return false
    end

    local companion_spawner_extension = ScriptUnit.has_extension(player_unit, "companion_spawner_system")
    local has_companion = companion_spawner_extension and companion_spawner_extension:should_have_companion()

    return has_companion
end

-- Function to send companion attack command
local function sendCompanionAttackCommand(target_unit)
    if not target_unit or creating_companion_tag or not HEALTH_ALIVE[target_unit] then
        return false
    end

    local player_unit = Managers.player:local_player_safe(1).player_unit
    if not player_unit then
        return false
    end

    -- Double-check the target is still valid
    local unit_data = ScriptUnit.has_extension(target_unit, "unit_data_system")
    if not unit_data then
        return false
    end

    -- Set flag to prevent recursion
    creating_companion_tag = true

    -- Use the game's existing smart tag system to create a companion command tag
    local smart_tag_system = Managers.state.extension:system("smart_tag_system")
    if smart_tag_system then
        -- Set a contextual tag that the companion system recognizes
        smart_tag_system:set_contextual_unit_tag(player_unit, target_unit, true) -- true for alternate/companion mode

        if mod:get("debug_mode") then
            local target_breed = unit_data:breed()
            local enemy_name = target_breed and target_breed.name
            mod:echo("Companion tag sent to: " .. (enemy_name or "unknown"))
        end

        -- Reset flag
        creating_companion_tag = false
        return true
    end

    -- Reset flag on failure
    creating_companion_tag = false
    return false
end

-- Tag a unit directly through the smart tag system, the same way
-- HudElementSmartTagging._handle_selected_unit does for a manual ping.
-- This replaces a unit's existing tag (if any) instead of requiring a
-- separate cancel step.
local function tagUnit(target_unit)
    local player_unit = Managers.player:local_player_safe(1).player_unit
    if not player_unit then
        return false
    end

    local smart_tag_system = Managers.state.extension:system("smart_tag_system")
    if not smart_tag_system then
        return false
    end

    creating_auto_tag = true

    local existing_tag_id = smart_tag_system:unit_tag_id(target_unit)

    if existing_tag_id then
        smart_tag_system:trigger_tag_interaction(existing_tag_id, player_unit, target_unit)
    else
        smart_tag_system:set_contextual_unit_tag(player_unit, target_unit, false)
    end

    creating_auto_tag = false

    return true
end

-- Hook into the HUD element that handles smart tagging to detect what's under crosshair
mod:hook("HudElementSmartTagging", "_find_best_smart_tag_interaction", function(func, self, ui_renderer, render_settings, force_update_targets)
    local best_marker, best_unit, best_position = func(self, ui_renderer, render_settings, force_update_targets)

    -- Only proceed if we have a valid unit and aren't under manual override.
    -- Note: cooldown is checked per-branch below, not here, so that priority
    -- targeting can still interrupt an existing tag while on cooldown.
    if best_unit and not manual then
        local target_type = Unit.get_data(best_unit, "smart_tag_target_type")

        if target_type == "breed" then
            local unit_data = ScriptUnit.has_extension(best_unit, "unit_data_system")
            local target_breed = unit_data and unit_data:breed()
            local enemy_name = target_breed and target_breed.name

            if enemy_name and shouldTagEnemy(enemy_name) then
                local should_tag = false

                -- Priority targeting logic
                if mod:get("priority_targeting") and taggedTarget and taggedTarget ~= best_unit then
                    local tagged_unit_data = ScriptUnit.has_extension(taggedTarget, "unit_data_system")
                    local tagged_breed = tagged_unit_data and tagged_unit_data:breed()
                    local tagged_enemy_name = tagged_breed and tagged_breed.name

                    -- Only switch targets if new target has higher priority (lower number = higher priority)
                    if tagged_enemy_name and getEnemyPriority(enemy_name) < getEnemyPriority(tagged_enemy_name) then
                        should_tag = true

                        if mod:get("debug_mode") then
                            mod:echo("Switching priority from: " .. tagged_enemy_name .. " (P:" .. getEnemyPriority(tagged_enemy_name) .. ") to: " .. enemy_name .. " (P:" .. getEnemyPriority(enemy_name) .. ")")
                        end
                    elseif mod:get("debug_mode") then
                        mod:echo("NOT switching from: " .. tagged_enemy_name .. " (P:" .. getEnemyPriority(tagged_enemy_name) .. ") to: " .. enemy_name .. " (P:" .. getEnemyPriority(enemy_name) .. ") - lower/same priority")
                    end
                elseif cooldown <= 0 and best_unit ~= taggedTarget then
                    -- No existing tag, priority targeting disabled, or same unit - tag normally.
                    -- Cooldown only applies here, not to priority switches above.
                    should_tag = true
                end

                if should_tag then
                    local use_companion = shouldSendCompanionCommand() and not creating_companion_tag
                    local tagged

                    if use_companion then
                        tagged = sendCompanionAttackCommand(best_unit)
                    else
                        tagged = tagUnit(best_unit)
                    end

                    if tagged and mod:get("debug_mode") then
                        mod:echo("Detected target: " .. enemy_name .. " (Priority: " .. getEnemyPriority(enemy_name) .. ")")
                    end
                end
            end
        end
    end

    return best_marker, best_unit, best_position
end)

mod:hook("SmartTag", "destroy", function(f, s, ...)
    if s._tagger_unit == Managers.player:local_player_safe(1).player_unit and taggedTarget == s._target_unit then
        if mod:get("refresh") then
            cooldown = 0
        end
        manual = false
        taggedTarget = nil
    end
    return f(s, ...)
end)

mod:hook_safe("SmartTag", "init", function(s, tag_id, template, tagger_unit, target_unit, ...)
    if tagger_unit == Managers.player:local_player_safe(1).player_unit then
        if cooldown > 0.5 and not mod:get("manualoverride") and not creating_auto_tag and not creating_companion_tag then
            manual = true
        end

        cooldown = mod:get("cd")
        taggedTarget = target_unit

        -- Log tagged enemy for debugging (if debug mode is enabled)
        if mod:get("debug_mode") then
            local unit_data = ScriptUnit.has_extension(target_unit, "unit_data_system")
            local target_breed = unit_data and unit_data:breed()
            local enemy_name = target_breed and target_breed.name
            mod:echo("Auto-tagged: " .. (enemy_name or "unknown") .. " (Priority: " .. getEnemyPriority(enemy_name or "unknown") .. ")")
        end
    end
end)

function mod.update(dt)
    if cooldown > 0 then
        cooldown = cooldown - dt
    end

    -- Clean up tagged target if it's no longer valid
    if taggedTarget and not HEALTH_ALIVE[taggedTarget] then
        taggedTarget = nil
        if mod:get("refresh") then
            cooldown = 0
        end
        manual = false
    end
end
