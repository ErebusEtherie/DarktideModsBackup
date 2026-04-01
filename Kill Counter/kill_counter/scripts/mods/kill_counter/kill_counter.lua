local mod = get_mod("kill_counter")
local Breed = mod:original_require("scripts/utilities/breed")

mod.kill_counter = 0

local hud_elements = {
    {
        filename = "kill_counter/scripts/mods/kill_counter/HudElementKillCounter",
        class_name = "HudElementKillCounter",
        visibility_groups = {
            "tactical_overlay",
            "alive",
            "communication_wheel",
        },
    },
}

for _, hud_element in ipairs(hud_elements) do
    mod:add_require_path(hud_element.filename)
end

local function player_from_unit(unit)
    if not unit then
        return nil
    end

    local player_manager = Managers and Managers.player
    if not player_manager then
        return nil
    end

    local local_player = player_manager:local_player(1)
    if local_player and local_player.player_unit == unit then
        return local_player
    end

    return nil
end

local function recreate_hud(reset_counter)
    if reset_counter then
        mod.kill_counter = 0
    end

    local ui_manager = Managers and Managers.ui
    if not ui_manager then
        return
    end

    local hud = ui_manager._hud
    if not hud then
        return
    end

    local player_manager = Managers and Managers.player
    local player = player_manager and player_manager:local_player(1)
    if not player then
        return
    end

    local peer_id = player:peer_id()
    local local_player_id = player:local_player_id()
    local elements = hud._element_definitions
    local visibility_groups = hud._visibility_groups

    hud:destroy()
    ui_manager:create_player_hud(peer_id, local_player_id, elements, visibility_groups)
end

mod:hook("UIHud", "init", function(func, self, elements, visibility_groups, params)
    for _, hud_element in ipairs(hud_elements) do
        if not table.find_by_key(elements, "class_name", hud_element.class_name) then
            table.insert(elements, {
                class_name = hud_element.class_name,
                filename = hud_element.filename,
                use_hud_scale = true,
                visibility_groups = hud_element.visibility_groups,
            })
        end
    end

    return func(self, elements, visibility_groups, params)
end)

mod.on_all_mods_loaded = function()
    recreate_hud(false)
end

mod.on_setting_changed = function()
    recreate_hud(false)
end

mod.on_game_state_changed = function(status, state_name)
    if status == "enter" and (state_name == "GameplayStateRun" or state_name == "StateGameplay") then
        recreate_hud(true)
    end
end

mod:hook_safe(CLASS.AttackReportManager, "add_attack_result", function(
    _self,
    _damage_profile,
    attacked_unit,
    attacking_unit,
    _attack_direction,
    _hit_world_position,
    _hit_weakspot,
    _damage,
    attack_result
)
    local player = player_from_unit(attacking_unit)
    if not player or attack_result ~= "died" then
        return
    end

    local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
    local breed_or_nil = unit_data_extension and unit_data_extension:breed()
    local target_is_minion = breed_or_nil and Breed.is_minion(breed_or_nil)

    if target_is_minion then
        mod.kill_counter = mod.kill_counter + 1
    end
end)

if mod.command then
    mod:command("kill_counter_reset", "Reset the kill counter.", function()
        mod.kill_counter = 0
        mod:echo("Kill counter reset.")
    end)
end

return mod
