local mod = get_mod("what_are_you")

---@alias use_game_state_r { is_in_game: is_in_game,is_in_map: is_in_map, is_in_hub: is_in_hub, get_units: get_units, update_game_state: update_game_state }
---@alias use_game_state fun() : use_game_state_r
---@type use_game_state
local function use_game_state()
    ---@alias is_in_hub fun() : boolean
    ---@type is_in_hub
    local function is_in_hub()
        local game_mode_manager = Managers.state.game_mode
        local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()
        return game_mode_name == "hub" or game_mode_name == "prologue_hub"
    end

    ---@alias is_in_map fun() : boolean
    ---@type is_in_map
    local function is_in_map()
        local player = Managers.player and Managers.player:local_player(1)
        local player_unit = player.player_unit
        local world = Managers.world and Managers.world:world("level_world")

        return (player and player.player_unit and POSITION_LOOKUP[player_unit]) and world
    end

    ---@alias is_in_game fun() : boolean
    ---@type is_in_game
    local function is_in_game()
        if mod:get("_game_state") == "GameplayStateRun" then
            return is_in_map() and not is_in_hub()
        else
            return false
        end
    end

    ---@alias update_game_state fun(state: "StateSplash" | "StateMainMenu" | "StateLoading" | "StateGameplay")
    ---@type update_game_state
    local function update_game_state(state)
        mod:set("_game_state", state)
    end


    return {
        is_in_game = is_in_game,
        is_in_hub = is_in_hub,
        is_in_map = is_in_map,
        update_game_state = update_game_state
    }
end



return use_game_state
