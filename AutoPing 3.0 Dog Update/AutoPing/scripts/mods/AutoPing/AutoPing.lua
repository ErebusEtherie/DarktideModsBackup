local mod = get_mod("AutoPing")

local tag = false
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
    "chaos_beast_of_nurgle"
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
        "chaos_spawn"
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
local last_tag_time = 0
local pending_priority_switch = nil  -- Track pending priority switches
local creating_companion_tag = false  -- Prevent recursion

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

-- Hook into the HUD element that handles smart tagging to detect what's under crosshair
mod:hook("HudElementSmartTagging", "_find_best_smart_tag_interaction", function(func, self, ui_renderer, render_settings, force_update_targets)
    local best_marker, best_unit, best_position = func(self, ui_renderer, render_settings, force_update_targets)
    
    -- Only proceed if we have a valid unit and are not on cooldown
    if best_unit and cooldown <= 0 and not manual then
        local target_type = Unit.get_data(best_unit, "smart_tag_target_type")
        
        if target_type == "breed" then
            local unit_data = ScriptUnit.has_extension(best_unit, "unit_data_system")
            local target_breed = unit_data and unit_data:breed()
            local enemy_name = target_breed and target_breed.name
            
            if enemy_name and shouldTagEnemy(enemy_name) then
                -- Priority targeting logic
                if mod:get("priority_targeting") and taggedTarget and taggedTarget ~= best_unit then
                    local tagged_unit_data = ScriptUnit.has_extension(taggedTarget, "unit_data_system")
                    local tagged_breed = tagged_unit_data and tagged_unit_data:breed()
                    local tagged_enemy_name = tagged_breed and tagged_breed.name
                    
                    -- Only switch targets if new target has higher priority (lower number = higher priority)
                    if tagged_enemy_name and getEnemyPriority(enemy_name) < getEnemyPriority(tagged_enemy_name) then
                        -- Instead of immediate cancellation, queue a priority switch
                        pending_priority_switch = {
                            old_target = taggedTarget,
                            new_target = best_unit,
                            old_enemy_name = tagged_enemy_name,
                            new_enemy_name = enemy_name,
                            switch_time = Managers.time:time("main") + 0.1,  -- Small delay
                            -- Include companion command for the NEW target if enabled
                            needs_companion_command = shouldSendCompanionCommand()
                        }
                        
                        if mod:get("debug_mode") then
                            mod:echo("Queued priority switch from: " .. tagged_enemy_name .. " (P:" .. getEnemyPriority(tagged_enemy_name) .. ") to: " .. enemy_name .. " (P:" .. getEnemyPriority(enemy_name) .. ")")
                        end
                        
                        tag = false  -- Don't tag immediately, let the pending switch handle it
                    else
                        if mod:get("debug_mode") then
                            mod:echo("NOT switching from: " .. tagged_enemy_name .. " (P:" .. getEnemyPriority(tagged_enemy_name) .. ") to: " .. enemy_name .. " (P:" .. getEnemyPriority(enemy_name) .. ") - lower/same priority")
                        end
                        tag = false
                    end
                elseif best_unit ~= taggedTarget then
                    -- No existing tag, priority targeting disabled, or same unit - tag normally
                    tag = true
                else
                    -- Same unit as already tagged, don't retag
                    tag = false
                end
                
                -- Debug output for what would be tagged
                if mod:get("debug_mode") and tag then
                    mod:echo("Detected target: " .. enemy_name .. " (Priority: " .. getEnemyPriority(enemy_name) .. ")")
                end
                
                -- Handle companion commands at the detection level (only for non-priority-switch cases)
                if shouldSendCompanionCommand() and tag and not creating_companion_tag and not pending_priority_switch then
                    -- Queue companion command for the target that WOULD be auto-tagged
                    pending_priority_switch = {
                        companion_command = true,
                        target_unit = best_unit,
                        switch_time = Managers.time:time("main") + 0.02  -- Very small delay, before normal tag
                    }
                end
            else
                tag = false
            end
        else
            tag = false
        end
    else
        tag = false
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
    if cooldown > 0.5 and not mod:get("manualoverride") then 
        manual = true
    end
    if tagger_unit == Managers.player:local_player_safe(1).player_unit then
        cooldown = mod:get("cd")
        tag = false
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

mod:hook("InputService", "_get", function(f, s, action_name)
    -- Handle manual ping inputs
    if action_name == "smart_tag" then
        local current_time = Managers.time:time("main")
        last_tag_time = current_time
        
        -- If this is our auto-tag, proceed (whether normal ping or companion command)
        if tag and (cooldown <= 0 or pending_priority_switch) then
            -- Reset cooldown for priority targeting or normal operation
            cooldown = 0.05
            return true 
        end
    end
    
    return f(s, action_name)
end)

function mod.update(dt)
    if cooldown > 0 then 
        cooldown = cooldown - dt 
    end
    
    -- Handle pending priority switches and companion commands
    if pending_priority_switch then
        local current_time = Managers.time:time("main")
        if current_time >= pending_priority_switch.switch_time then
            
            -- Handle companion command
            if pending_priority_switch.companion_command then
                if pending_priority_switch.target_unit and HEALTH_ALIVE[pending_priority_switch.target_unit] then
                    sendCompanionAttackCommand(pending_priority_switch.target_unit)
                end
                pending_priority_switch = nil
                
            -- Handle priority switch
            else
                local smart_tag_system = Managers.state.extension:system("smart_tag_system")
                if smart_tag_system and taggedTarget == pending_priority_switch.old_target then
                    local existing_tag_id = smart_tag_system:unit_tag_id(pending_priority_switch.old_target)
                    if existing_tag_id then
                        local player_unit = Managers.player:local_player_safe(1).player_unit
                        if player_unit then
                            -- Cancel old tag
                            smart_tag_system:cancel_tag(existing_tag_id, player_unit, false)
                            
                            -- Clear our tracking
                            taggedTarget = nil
                            cooldown = 0
                            
                            -- Set up for immediate new tag on next frame
                            tag = true
                            
                            -- Send companion command for the NEW target if needed
                            if pending_priority_switch.needs_companion_command and pending_priority_switch.new_target and HEALTH_ALIVE[pending_priority_switch.new_target] then
                                sendCompanionAttackCommand(pending_priority_switch.new_target)
                            end
                            
                            if mod:get("debug_mode") then
                                mod:echo("Executed priority switch from: " .. pending_priority_switch.old_enemy_name .. " to: " .. pending_priority_switch.new_enemy_name)
                                if pending_priority_switch.needs_companion_command then
                                    mod:echo("Companion command sent to new priority target: " .. pending_priority_switch.new_enemy_name)
                                end
                            end
                        end
                    end
                end
                pending_priority_switch = nil
            end
        end
    end
    
    -- Clean up tagged target if it's no longer valid
    if taggedTarget and not HEALTH_ALIVE[taggedTarget] then
        taggedTarget = nil
        if mod:get("refresh") then
            cooldown = 0
        end
        manual = false
        pending_priority_switch = nil  -- Clear any pending switches for dead targets
    end
    
    -- Clean up pending companion commands for dead targets
    if pending_priority_switch then
        if pending_priority_switch.companion_command and pending_priority_switch.target_unit and not HEALTH_ALIVE[pending_priority_switch.target_unit] then
            pending_priority_switch = nil
        elseif pending_priority_switch.new_target and not HEALTH_ALIVE[pending_priority_switch.new_target] then
            pending_priority_switch = nil
        elseif pending_priority_switch.old_target and not HEALTH_ALIVE[pending_priority_switch.old_target] then
            pending_priority_switch = nil
        end
    end
end