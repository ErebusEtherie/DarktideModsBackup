-- DMF toggles hooks immediately. Keep the current local mission's decision
-- until its owners are destroyed; condition resources and map pools were
-- already initialized and cannot be safely undone halfway through a mission.
return function(mod, authority, dependency)
    local requested=mod:is_enabled()
    local owner,enabled,finished_owner
    local api={}
    local function session_owner()
        if not authority() then return end
        local state=Managers.state
        return state and (state.game_session or state.difficulty)
    end
    local function configured()
        return requested and (not dependency or dependency:is_enabled())
    end
    local function dependency_active()
        if not dependency then return true end
        if dependency.is_gameplay_enabled then return dependency.is_gameplay_enabled() end
        return dependency:is_enabled()
    end
    local function set_hooks(value)
        if value then mod:enable_all_hooks() else mod:disable_all_hooks() end
    end
    api.active=function()
        local current=session_owner()
        if current and current~=finished_owner then
            if current~=owner then
                owner=current
                enabled=requested and dependency_active()
            end
            return enabled
        end
        return configured()
    end
    api.changed=function(initial_call)
        if initial_call then
            requested=mod:is_enabled()
            owner=nil; enabled=nil; finished_owner=nil
        else
            -- Capture the old request before DMF's newly selected state is used.
            api.active()
            requested=mod:is_enabled()
        end
        local active=api.active()
        set_hooks(active)
        if not initial_call and owner and active~=configured() then
            mod:notify(mod:localize("toggle_next_mission"))
        end
        return active
    end
    api.finish=function()
        finished_owner=owner or session_owner()
        owner=nil; enabled=nil
        requested=mod:is_enabled()
        set_hooks(configured())
    end
    api.start=function()
        -- Some session managers are reused between maps; the lifecycle event
        -- is an additional boundary even when the owner identity is unchanged.
        owner=nil; enabled=nil; finished_owner=nil
        requested=mod:is_enabled()
        set_hooks(api.active())
    end
    return api
end
