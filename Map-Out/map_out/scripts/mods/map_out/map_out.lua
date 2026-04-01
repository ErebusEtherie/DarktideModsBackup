local mod = get_mod("map_out")
local input_request = nil
local is_holding_map = false
local hold_keys = mod:get("hold_mode_keys")
local wheel_input = mod:get("wheel_input")
local wheel_move_t = 0
local is_map_currently_wielded = false
local previous_slot = "slot_primary"


local function is_hold_key_down()
    if not hold_keys or not next(hold_keys) then return false end
    for i = 1, #hold_keys do
        local key_name = hold_keys[i]
        local key_index = Keyboard.button_index(key_name)
        if not key_index or Keyboard.button(key_index) <= 0.5 then
            return false
        end
    end
    return true
end

mod.on_setting_changed = function(setting_id)
    if setting_id == "hold_mode_keys" then 
        hold_keys = mod:get("hold_mode_keys") 
    end
end

mod.on_unload = function(exit_game)
    input_request = nil
    is_holding_map = false
    is_map_currently_wielded = false
end

mod:hook_safe("PlayerUnitWeaponExtension", "on_slot_wielded", function(self, slot_name, ...)
    if self._player == Managers.player:local_player(1) then
        is_map_currently_wielded = (slot_name == "slot_device")
        
        if slot_name ~= "slot_device" then
            previous_slot = slot_name
        end
    end
end)

mod.stow_map_action = function()
    if is_map_currently_wielded then
        input_request = (previous_slot == "slot_secondary") and "wield_2" or "wield_1"
    end
end

mod:hook("InputService", "_get", function(func, self, action_name, ...)
    if input_request and action_name == input_request then
        input_request = nil
        return true
    end

    if action_name == "cursor" then
        if hold_keys and next(hold_keys) then
            local currently_pressed = is_hold_key_down()

            if currently_pressed then
                if not is_map_currently_wielded then
                    input_request = "wield_5"
                end
                is_holding_map = true
            elseif is_holding_map then
                is_holding_map = false
                if is_map_currently_wielded then
                    mod.stow_map_action()
                end
            end
        end
    end

    return func(self, action_name, ...)
end)

mod:hook("UIManager", "open_view", function(func, self, view_name, ...)
    if view_name == "system_view" then
        if is_map_currently_wielded then
            mod.stow_map_action()
            return
        end
    end
    return func(self, view_name, ...)
end)

mod:hook("MinigameExpeditionMap", "selected_level", function(func, self, ...)
    local is_enabled = mod:get("wheel_input")

    if is_enabled and self._register_input then
        local scroll_axis = Mouse.axis(Mouse.axis_index("wheel"))
        local scroll_y = scroll_axis.y

        if scroll_y ~= 0 then
            local t = Managers.time:time("main")
            
            if t > wheel_move_t + 0.15 then 
                local targets = self._selectable
                if targets and #targets > 0 then
                    local current_index = self._selected or 1
                    local step = (scroll_y > 0) and 1 or -1
                    local next_index = nil
                    
                    local attempts = 0
                    local temp_idx = current_index
                    
                    repeat
                        attempts = attempts + 1
                        temp_idx = temp_idx + step
                        
                        if temp_idx > #targets then temp_idx = 1 end
                        if temp_idx < 1 then temp_idx = #targets end
                        
                        if self._handler and not self._handler:is_level_completed(targets[temp_idx]) then
                            next_index = temp_idx
                            break
                        end
                    until attempts >= #targets

                    if next_index and next_index ~= current_index then
                        self._selected = next_index
                        wheel_move_t = t 
                        self:play_sound("sfx_minigame_map_move", false, true)
                    end
                end
            end
        end
    end

    return func(self, ...)
end)

mod.empty_function = function() end