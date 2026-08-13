local mod = get_mod("SlotFix")
local UISettings = require("scripts/settings/ui/ui_settings")

local function fix_slots(player_manager)
    local is_hub = false
    if Managers.state and Managers.state.game_mode then
        local game_mode_name = Managers.state.game_mode:game_mode_name()
        if game_mode_name and string.find(game_mode_name, "hub") then
            is_hub = true
        end
    elseif Managers.mechanism then
        local mechanism_name = Managers.mechanism:mechanism_name()
        if mechanism_name and mechanism_name == "hub" then
            is_hub = true
        end
    end

    if is_hub then
        return
    end

    local players = player_manager:players()
    local occupied_slots = {}
    local players_to_reassign = {}

    for unique_id, player in pairs(players) do
        local slot = player:slot()
        if slot then
            if slot <= 4 and not occupied_slots[slot] then
                occupied_slots[slot] = true
            else
                table.insert(players_to_reassign, player)
            end
        end
    end

    local fixed_any = false
    for _, player in ipairs(players_to_reassign) do
        local old_slot = player:slot()
        for i = 1, 4 do
            if not occupied_slots[i] then
                player:set_slot(i)
                occupied_slots[i] = true
                fixed_any = true
                
                if mod:get("debug_messages") then
                    mod:echo("FOUND BROKEN SLOT: Changed player from slot %s to slot %s", tostring(old_slot), tostring(i))
                end

                if UISettings then
                    UISettings._colors_revision = (UISettings._colors_revision or 0) + 1
                end

                local color_mod = get_mod("ColorSelection")
                if color_mod and type(color_mod.apply_slot_colors) == "function" then
                    color_mod.apply_slot_colors()
                end
                break
            end
        end
    end

    if not fixed_any and mod:get("debug_messages") then
        mod:echo("No broken slots found.")
    end
end

mod:hook_safe("PlayerManager", "remove_player", function(self, peer_id, local_player_id)
    fix_slots(self)
end)

mod:hook_safe("PlayerManager", "add_player", function(self, peer_id, local_player_id, ...)
    fix_slots(self)
end)
