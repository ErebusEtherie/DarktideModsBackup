local mod = get_mod("StickyFingers")
local kd  = get_mod("keep_dodging")
local MOD_ENABLED = true
local TARGET = {
    TYPE = "NONE",
    PRESENT = false,
    MANUAL = false,
    PROGRESS = 0,
}
local INPUT = {
    KD = false,  -- Keep Dodging flag
    ACTUAL = { interact_primary_pressed = false, interact_secondary_pressed = true, interact_hold = false, interact_pressed = false, jump = false, jump_held = false, dodge = false },
    SIMULATED = { interact_primary_pressed = false, interact_secondary_pressed = true, interact_hold = false, interact_pressed = false, jump = false, jump_held = false, dodge = false },
    DESIRED = { interact_primary_pressed = false, interact_secondary_pressed = true, interact_hold = false, interact_pressed = false, jump = false, jump_held = false, dodge = false },
    CONTROLLED = { interact_primary_pressed = true, interact_secondary_pressed = true, interact_hold = true, interact_pressed = true, jump = true, jump_held = true, dodge = true }
}
local SPECIAL_INTERACT = { interact_primary_pressed = true, interact_secondary_pressed = true }
local COOLDOWN = {
    TIME = 0,
    IGNORED = { interact_primary_pressed = true, interact_secondary_pressed = true, interact_hold = true, jump = true, dodge = true },
    DOOR = { SNAPSHOT = 0, DELAY = 1.5 },
    MENU = { SNAPSHOT = 0, DELAY = 1.5 },
    MANUAL = { SNAPSHOT = 0, DELAY = 0.25 },
    GENERIC = { SNAPSHOT = 0, DELAY = 0.5 },
    LUGGABLE = { SNAPSHOT = 0, DELAY = 0.75 },
    LAGSWITCH = { SNAPSHOT = 0, DELAY = 1 },
}
local AUTO = {
    ENABLED = false,
    MEDSTATION = {
        ENABLED = false,
        THRESHOLD = 1,
        CURRENT = 0,
        KEYWORDS = { loc_action_interaction_use = true, health = true, health_station = true },
    },
    TEAMMATE = {
        ENABLED = { RESCUE = false, REVIVE = false, NET = false, LEDGE = false },
        RESCUE = { loc_action_interaction_rescue = true },
        REVIVE = { loc_action_interaction_revive = true },
        NET = { loc_action_interaction_help = true, loc_remove_net = true },
        LEDGE = { loc_action_interaction_help = true, loc_pull_up = true },
    },
    MISSION = {
        ENABLED = false,
        KEYWORDS = {loc_action_interaction_use = true, loc_action_interaction_press = true, loc_interactable_servo_skull_scanner_deploy = true, loc_interactable_servo_skull_scanner_continue = true, loc_action_interaction_plant = true, loc_generic_interaction = true},
        BLACKLIST = {loc_chest = true, loc_interactable_door = true, loc_health_station = true, loc_sg_exit_shooting_range = true},
    },
    DOOR = {
        ENABLED = false,
        TARGET = "closed",
        KEYWORDS = {loc_action_interaction_use = true, door_control_panel = true},
    },
    MINIGAME = {
        ENABLED = false,
        KEYWORDS = {loc_action_interaction_decode = true},
    },
    LUGGABLE = {
        ENABLED = false,
        KEYWORDS = {loc_action_interaction_pickup = true, loc_action_interaction_insert = true, luggable = true, luggable_socket = true},
    },
    -- Events
    SPECIAL = {
        KEYWORDS = {loc_action_interaction_tainted_skull = true, loc_action_interaction_stolen_rations_recover = true}
    },
    -- Selector for special interactibles
    PRIMARY_SECONDARY = "disabled"
}

mod.on_setting_changed = function(setting)
    if setting == "EnableAuto" then
        AUTO.ENABLED = mod:get(setting)
    elseif setting == "MedStation" then
        AUTO.MEDSTATION.ENABLED = mod:get(setting)
    elseif setting == "MedThreshold" then
        AUTO.MEDSTATION.THRESHOLD = mod:get(setting) / 100
    elseif setting == "TeammateRevive" then
        AUTO.TEAMMATE.ENABLED.REVIVE = mod:get(setting)
    elseif setting == "TeammateRescue" then
        AUTO.TEAMMATE.ENABLED.RESCUE = mod:get(setting)
    elseif setting == "TeammateLedge" then
        AUTO.TEAMMATE.ENABLED.LEDGE = mod:get(setting)
    elseif setting == "TeammateNet" then
        AUTO.TEAMMATE.ENABLED.NET = mod:get(setting)
    elseif setting == "Mission" then
        AUTO.MISSION.ENABLED = mod:get(setting)
    elseif setting == "Door" then
        AUTO.DOOR.ENABLED = mod:get(setting)
    elseif setting == "DoorType" then
        AUTO.DOOR.TARGET = mod:get(setting)
    elseif setting == "Minigame" then
        AUTO.MINIGAME.ENABLED = mod:get(setting)
    elseif setting == "Luggable" then
        AUTO.LUGGABLE.ENABLED = mod:get(setting)
    elseif setting == "Special" then
        AUTO.PRIMARY_SECONDARY = mod:get(setting)
    end
end

mod.on_all_mods_loaded = function()
    AUTO.ENABLED = mod:get("EnableAuto")
    AUTO.MEDSTATION.ENABLED = mod:get("MedStation")
    AUTO.MEDSTATION.THRESHOLD = mod:get("MedThreshold") / 100
    AUTO.TEAMMATE.ENABLED.REVIVE = mod:get("TeammateRevive")
    AUTO.TEAMMATE.ENABLED.RESCUE = mod:get("TeammateRescue")
    AUTO.TEAMMATE.ENABLED.LEDGE = mod:get("TeammateLedge")
    AUTO.TEAMMATE.ENABLED.NET = mod:get("TeammateNet")
    AUTO.MISSION.ENABLED = mod:get("Mission")
    AUTO.DOOR.ENABLED = mod:get("Door")
    AUTO.DOOR.TARGET = mod:get("DoorType")
    AUTO.MINIGAME.ENABLED = mod:get("Minigame")
    AUTO.LUGGABLE.ENABLED = mod:get("Luggable")
    AUTO.PRIMARY_SECONDARY = mod:get("Special")
end

mod.on_enabled = function()
    MOD_ENABLED = true
end

mod.on_disabled = function()
    MOD_ENABLED = false
end

mod.on_game_state_changed = function ()
    COOLDOWN.MENU.SNAPSHOT, COOLDOWN.DOOR.SNAPSHOT, COOLDOWN.MANUAL.SNAPSHOT, COOLDOWN.GENERIC.SNAPSHOT, COOLDOWN.LUGGABLE.SNAPSHOT, COOLDOWN.LAGSWITCH.SNAPSHOT = 0, 0, 0, 0, 0, 0
end

mod.update = function()
    if not MOD_ENABLED then
        return
    end
    INPUT.KD = kd and kd._is_active or false                           -- Check if Keep Dodging is actively trying to dodge
    COOLDOWN.TIME = Managers.time:time("main")
    local active_views = Managers.ui:active_views()
    if active_views and #active_views > 0 then
        COOLDOWN.MENU.SNAPSHOT = COOLDOWN.TIME
    end
    local player_manager = Managers and Managers.player
    if player_manager and not Managers.ui:using_input() then
        local player = player_manager:local_player_safe(1)
        local player_unit = player and player.player_unit
        local health_system = player_unit and ScriptUnit.has_extension(player_unit, "health_system")
        local health = health_system and health_system:current_health_percent()
        local visual_loadout = player_unit and ScriptUnit.has_extension(player_unit, "visual_loadout_system")
        wielded_slot = visual_loadout and visual_loadout._inventory_component and visual_loadout._inventory_component.wielded_slot
        if wielded_slot and wielded_slot == "slot_luggable" then
            COOLDOWN.LUGGABLE.SNAPSHOT = COOLDOWN.TIME                 -- Update luggable snapshot while held to apply cooldown upon drop/throw
        end
        AUTO.MEDSTATION.CURRENT = health or 0                          -- Update current health for Medicae Station auto-interact
        if not INPUT.ACTUAL.interact_hold then  -- Reset TARGET/DESIRED if no interaction is present and interact is not held
            if TARGET.PROGRESS == 1 then
                if (COOLDOWN.TIME - COOLDOWN.LAGSWITCH.SNAPSHOT > COOLDOWN.LAGSWITCH.DELAY) or (COOLDOWN.TIME - COOLDOWN.DOOR.SNAPSHOT > COOLDOWN.DOOR.DELAY) then
                    TARGET.TYPE = "NONE"                                   -- Reset after delay when interaction is complete to avoid both lag interruptions and door spam
                    INPUT.DESIRED.interact_pressed = false
                    INPUT.DESIRED.interact_hold = false
                end
            elseif TARGET.PROGRESS > 0 and TARGET.PROGRESS < 1 then        -- Exit interaction immediately if button is released mid-interact
                if TARGET.TYPE ~= "MANUAL" then
                    COOLDOWN.LAGSWITCH.SNAPSHOT = COOLDOWN.TIME
                else
                TARGET.TYPE = "NONE"
                INPUT.DESIRED.interact_pressed = false
                INPUT.DESIRED.interact_hold = false
                end
            end
        end
    end
end

-- Interactible Detection
mod:hook_safe("HudElementInteraction", "update", function(self)
    local player_unit = self._parent and self._parent:player().player_unit
    local interactor_extension = ScriptUnit.has_extension(player_unit, "interactor_system")
    local target_unit = interactor_extension and (interactor_extension:target_unit() or interactor_extension:focus_unit())
    local interactee_extension = ScriptUnit.extension(target_unit, "interactee_system")
    TARGET.PROGRESS = interactor_extension and interactor_extension:interaction_progress()
    if target_unit and interactee_extension then
        local interaction = interactor_extension and interactor_extension:interaction()
        local hud_text = interaction and interaction:action_text()
        local hud_description = interactor_extension:hud_description() or "NONE"
        local interaction_class = interaction and interaction._template and interaction._template.interaction_class_name or "NONE"
        TARGET.MANUAL = (hud_text and true) or false
        if hud_text and AUTO.ENABLED then
            -- Event Pickups
            if AUTO.SPECIAL.KEYWORDS[hud_text] then
                TARGET.TYPE, TARGET.PRESENT = TARGET.TYPE ~= "MANUAL" and "GENERIC" or TARGET.TYPE, true
            elseif AUTO.MEDSTATION.ENABLED and AUTO.MEDSTATION.KEYWORDS[hud_text] and AUTO.MEDSTATION.KEYWORDS[interaction_class] and AUTO.MEDSTATION.CURRENT <= AUTO.MEDSTATION.THRESHOLD then
                TARGET.TYPE, TARGET.PRESENT = TARGET.TYPE ~= "MANUAL" and "GENERIC" or TARGET.TYPE, true
            -- Teammate
            elseif AUTO.TEAMMATE.ENABLED.REVIVE and AUTO.TEAMMATE.REVIVE[hud_text]
            or AUTO.TEAMMATE.ENABLED.RESCUE and AUTO.TEAMMATE.RESCUE[hud_text]
            or AUTO.TEAMMATE.ENABLED.LEDGE and AUTO.TEAMMATE.LEDGE[hud_text] and AUTO.TEAMMATE.LEDGE[hud_description]
            or AUTO.TEAMMATE.ENABLED.NET and AUTO.TEAMMATE.NET[hud_text] and AUTO.TEAMMATE.NET[hud_description] then
                TARGET.TYPE, TARGET.PRESENT = TARGET.TYPE ~= "MANUAL" and "GENERIC" or TARGET.TYPE, true
            -- Mission-related Interactions
            elseif AUTO.MISSION.ENABLED and AUTO.MISSION.KEYWORDS[hud_text] and not (AUTO.MISSION.BLACKLIST[hud_description] or string.find(hud_description, "pickup")) then
                TARGET.TYPE, TARGET.PRESENT = TARGET.TYPE ~= "MANUAL" and "GENERIC" or TARGET.TYPE, true
            -- Doors
            elseif AUTO.DOOR.ENABLED and AUTO.DOOR.KEYWORDS[hud_text] then
                local door_control = ScriptUnit.has_extension(target_unit, "door_control_panel_system")
                local door_state = door_control and door_control._door_extension and door_control._door_extension._current_state
                TARGET.PRESENT = (door_state == AUTO.DOOR.TARGET or AUTO.DOOR.TARGET == "any") and true or false
                TARGET.TYPE = TARGET.TYPE ~= "MANUAL" and "DOOR" or TARGET.TYPE
            -- Minigame
            elseif AUTO.MINIGAME.ENABLED and AUTO.MINIGAME.KEYWORDS[hud_text] then
                TARGET.TYPE, TARGET.PRESENT = TARGET.TYPE ~= "MANUAL" and "GENERIC" or TARGET.TYPE, true
            -- Luggables
            elseif AUTO.LUGGABLE.ENABLED and AUTO.LUGGABLE.KEYWORDS[hud_text] and AUTO.LUGGABLE.KEYWORDS[interaction_class] then
                if hud_text == "loc_action_interaction_insert" then
                    TARGET.TYPE, TARGET.PRESENT = TARGET.TYPE ~= "MANUAL" and "GENERIC" or TARGET.TYPE, true
                else
                    TARGET.TYPE, TARGET.PRESENT = TARGET.TYPE ~= "MANUAL" and "LUGGABLE" or TARGET.TYPE, true
                end
            else
                TARGET.PRESENT = false
            end
        else
            TARGET.PRESENT = false
        end
    else
        TARGET.PRESENT, TARGET.MANUAL = false, false
    end
    -- Mark interaction as desired if a target has been set either through this hook or via manual input
    INPUT.DESIRED.interact_pressed = INPUT.ACTUAL.interact_hold or TARGET.PRESENT
    INPUT.DESIRED.interact_primary_pressed = INPUT.ACTUAL.interact_hold or TARGET.PRESENT
    INPUT.DESIRED.interact_secondary_pressed = INPUT.ACTUAL.interact_hold or TARGET.PRESENT
    INPUT.DESIRED.interact_hold = TARGET.TYPE ~= "NONE" or false
    COOLDOWN.LAGSWITCH.SNAPSHOT = INPUT.DESIRED.interact_hold and COOLDOWN.TIME or COOLDOWN.LAGSWITCH.SNAPSHOT
end)

-- Hold checking for a press input..
mod.is_dodge_held = function(InputService)
    local dodge_rule = InputService:action_rule("dodge") -- probably works on other actions but I didn't test it
    local dodge_held = false
    -- Query action_rule for devices and key indices
    if dodge_rule and dodge_rule.debug_info then
        for _, key_name in ipairs(dodge_rule.debug_info) do
            local info = InputService._active_keys_and_axes[key_name]
            if info then
                -- Query device for held state
                local is_held = info.device:held(info.index)
                if is_held then
                    dodge_held = true
                    break
                end
            end
        end
    end
    return dodge_held
end

-- Interaction
mod:hook(CLASS.InputService, "_get", function(func, self, action_name)
    if MOD_ENABLED then
        -- Initial Universal Input Collection
        local action_rule = self._actions[action_name]
        local out
        if action_rule.filter then
            out = action_rule.eval_func(action_rule.eval_obj, action_rule.eval_param)
        else
            out = action_rule.default_func()
            local action_type = action_rule.type
            local combiner = InputService.ACTION_TYPES[action_type].combine_func
            for _, cb in ipairs(action_rule.callbacks) do
                out = combiner(out, cb())
            end
        end
        -- Interaction Handling
        if INPUT.CONTROLLED[action_name] then
            INPUT.ACTUAL[action_name] = out                                                         -- Record actual input state from player input
            if (COOLDOWN.TIME - COOLDOWN.MENU.SNAPSHOT) < COOLDOWN.MENU.DELAY then                      -- Force all interactions to respect exiting menus
                return func(self, action_name)
            end
            TARGET.TYPE = INPUT.ACTUAL.interact_hold and "MANUAL" or TARGET.TYPE                    -- Override TARGET.TYPE / INPUT.DESIRED while holding interact
            if (TARGET.PRESENT or TARGET[TARGET.TYPE]) and INPUT.ACTUAL.interact_pressed and TARGET.TYPE ~= "NONE" then
                COOLDOWN[TARGET.TYPE].SNAPSHOT = COOLDOWN.TIME                                      -- Set cooldown on manual press to avoid duplicate interactions
                COOLDOWN.DOOR.SNAPSHOT = COOLDOWN.TIME                                              -- Also force door cooldown to allow user overrides
            end
            INPUT.DESIRED.interact_pressed = INPUT.ACTUAL.interact_hold and true or INPUT.DESIRED.interact_pressed
            INPUT.DESIRED.interact_primary_pressed = INPUT.ACTUAL.interact_hold and true or INPUT.DESIRED.interact_primary_pressed
            COOLDOWN.IGNORED.interact_hold = not (INPUT.KD or INPUT.ACTUAL.jump or INPUT.ACTUAL.jump_held or mod.is_dodge_held(self))      -- Force interact_hold to respect cooldowns on jump/dodge
            INPUT.DESIRED.dodge = TARGET.PRESENT and (INPUT.KD or INPUT.ACTUAL.jump or INPUT.ACTUAL.jump_held or mod.is_dodge_held(self))  -- Force dodge when disengaging from auto-interact
            if INPUT.DESIRED[action_name] then
                if SPECIAL_INTERACT[action_name] and AUTO.PRIMARY_SECONDARY ~= action_name then
                    INPUT.DESIRED[action_name] = false
                    return func(self, action_name)
                end
                if TARGET.TYPE ~= "NONE" and ((COOLDOWN.TIME - COOLDOWN[TARGET.TYPE].SNAPSHOT > COOLDOWN[TARGET.TYPE].DELAY) or COOLDOWN.IGNORED[action_name]) then
                    if TARGET.PRESENT or TARGET[TARGET.TYPE] then                                   -- Trigger cooldowns and mark as completed upon interaction
                        INPUT.DESIRED[action_name] = action_name ~= "interact_hold" and false or INPUT.DESIRED[action_name]
                        INPUT.SIMULATED[action_name] = true
                        COOLDOWN[TARGET.TYPE].SNAPSHOT = not COOLDOWN.IGNORED[action_name] and COOLDOWN.TIME or COOLDOWN[TARGET.TYPE].SNAPSHOT
                        return true
                    end
                end
            end
            INPUT.SIMULATED[action_name] = false
        end
    end
    return func(self, action_name)
end)