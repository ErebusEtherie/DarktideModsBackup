local mod=get_mod("HavocConditionManager")
mod:hook_require("scripts/managers/presence/presence_manager",function(PresenceManager)
    local Settings=require("scripts/settings/presence/presence_settings")
    mod:hook(PresenceManager,"_check_activity",function(func,self,...)
        -- MMB's cached menu activity can remain "hub" during a Realms mission.
        -- Suppress only the redundant check after native presence has already
        -- stored Realms' activity. Genuine transitions still use the full method.
        local menu=get_mod("modular_menu_buttons")
        if mod.has_local_gameplay_authority() and get_mod("Realms") and menu
            and self._current_game_state_name=="StateGameplay"
            and (menu._current_state=="main_menu" or menu._current_state=="shooting_range") then
            local difficulty=Managers.state and Managers.state.difficulty
            local myself=self._myself
            if difficulty and type(difficulty:get_parsed_havoc_data())=="table"
                and myself and myself._activity_id=="training_grounds"
                and Settings.evaluate_presence(self._current_game_state_name)=="training_grounds"
                and myself:activity_id()=="hub" then return end
        end
        return func(self,...)
    end)
end)
