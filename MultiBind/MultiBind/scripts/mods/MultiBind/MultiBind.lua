--[[
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│ Mod Name: Multi Bind                                                                      │
│ Mod Description: Allows a secondary binding for all actions.                              │
│ Mod Author: Seph (Steam: Concoction of Constitution)                                      │
└───────────────────────────────────────────────────────────────────────────────────────────┘
--]]

local mod = get_mod("MultiBind")

local aliases = {
    action_one = {false, false},
    action_two = {false, false},
    weapon_extra = {false, false},
    interact = {false, false},
    interact_inspect = {false, false},
    wield_1 = {false, false},
    wield_2 = {false, false},
    wield_3 = {false, false},
    wield_4 = {false, false},
    wield_5 = {false, false},
    quick_wield = {false, false},
    wield_scroll_down = {false, false},
    wield_scroll_up = {false, false},
    weapon_reload = {false, false},
    grenade_ability = {false, false},
    combat_ability = {false, false},
    smart_tag = {false, false},
    com_wheel = {false, false},
    tactical_overlay = {false, false},
    weapon_inspect = {false, false},
    spectate_next = {false, false},
    voip_push_to_talk = {false, false},
    hotkey_inventory = {false, false},
    show_chat = {false, false},
    keyboard_move_forward = {false, false},
    keyboard_move_backward = {false, false},
    keyboard_move_left = {false, false},
    keyboard_move_right = {false, false},
    dodge = {false, false},
    jump = {false, false},
    crouch = {false, false},
    sprint = {false, false}
}


local enabled = true
local z
mod:hook("InputService", "_get", function(f, s, action_name)
    local a = s._actions[action_name]
    if a.key_alias == "keyboard_move_forward" and a.filter == true then mod:echo(a.filter) end
    if enabled and aliases[a.key_alias] then
        if a.filter == true then
            if aliases[a.eval_obj.input_mappings.button_2][1] == true then return 1 end
        elseif a.key_alias ~= "keyboard_move_forward" and a.key_alias ~= "keyboard_move_backward" and a.key_alias ~= "keyboard_move_left" and a.key_alias ~= "keyboard_move_right" then
            if aliases[a.key_alias][1] == true and a.type ~= "released" and a.type ~= "pressed" then 
                return true
            elseif a.type == "pressed" and aliases[a.key_alias][2] == true then
                aliases[a.key_alias][2] = false
                return true
            end
        elseif aliases[a.key_alias][1] == true then
            return 1
        end
    end

    return f(s, action_name)
end)





mod.action_one = function(e)
    aliases["action_one"] = {e,e}
end

mod.action_two = function(e)
    aliases["action_two"] = {e,e}
end

mod.weapon_extra = function(e)
    aliases["weapon_extra"] = {e,e}
end

mod.interact = function(e)
    aliases["interact"] = {e,e}
end

mod.interact_inspect = function(e)
    aliases["interact_inspect"] = {e,e}
end

mod.wield_1 = function(e)
    aliases["wield_1"] = {e,e}
end

mod.wield_2 = function(e)
    aliases["wield_2"] = {e,e}
end

mod.wield_3 = function(e)
    aliases["wield_3"] = {e,e}
end

mod.wield_4 = function(e)
    aliases["wield_4"] = {e,e}
end

mod.wield_5 = function(e)
    aliases["wield_5"] = {e,e}
end

mod.quick_wield = function(e)
    aliases["quick_wield"] = {e,e}
end

mod.wield_scroll_down = function(e)
    aliases["wield_scroll_down"] = {e,e}
end

mod.wield_scroll_up = function(e)
    aliases["wield_scroll_up"] = {e,e}
end

mod.weapon_reload = function(e)
    aliases["weapon_reload"] = {e,e}
end

mod.grenade_ability = function(e)
    aliases["grenade_ability"] = {e,e}
end

mod.combat_ability = function(e)
    aliases["combat_ability"] = {e,e}
end

mod.smart_tag = function(e)
    aliases["smart_tag"] = {e,e}
end

mod.com_wheel = function(e)
    aliases["com_wheel"] = {e,e}
end

mod.tactical_overlay = function(e)
    aliases["tactical_overlay"] = {e,e}
end

mod.weapon_inspect = function(e)
    aliases["weapon_inspect"] = {e,e}
end

mod.spectate_next = function(e)
    aliases["spectate_next"] = {e,e}
end

mod.voip_push_to_talk = function(e)
    aliases["voip_push_to_talk"] = {e,e}
end

mod.hotkey_inventory = function(e)
    aliases["hotkey_inventory"] = {e,e}
end

mod.show_chat = function(e)
    aliases["show_chat"] = {e,e}
end

mod.keyboard_move_forward = function(e)
    aliases["keyboard_move_forward"] = {e,e}
end

mod.keyboard_move_backward = function(e)
    aliases["keyboard_move_backward"] = {e,e}
end

mod.keyboard_move_left = function(e)
    aliases["keyboard_move_left"] = {e,e}
end

mod.keyboard_move_right = function(e)
    aliases["keyboard_move_right"] = {e,e}
end

mod.dodge = function(e)
    aliases["dodge"] = {e,e}
end

mod.jump = function(e)
    aliases["jump"] = {e,e}
end

mod.crouch = function(e)
    aliases["crouch"] = {e,e}
end

mod.sprint = function(e)
    aliases["sprint"] = {e,e}
end



-- Unassign bindings
mod:hook("InputAliases", "set_keys_for_alias", function(f, s, name, device_types, new_key_info, device_index)
    if (new_key_info and new_key_info.main == "keyboard_delete") then new_key_info.main = "keybind_unassigned" end
    return f(s, name, device_types, new_key_info, device_index)
end)
