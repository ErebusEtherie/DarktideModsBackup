local pcall = pcall
local pairs = pairs
local type = type
local tostring = tostring

return function(deps)
    local mod = deps.mod
    local managers = deps.managers
    local class = deps.class

    local p = {}
    local reported = {}

    local function report_once(tag, message)
        if reported[tag] then
            return
        end
        reported[tag] = true
        mod:error(message)
    end

    local watched = {}
    local revive_failed = {}

    local function ref_key(ref)
        if type(ref) ~= "table" or ref.id == nil then
            return nil
        end
        if ref.platform then
            return "p:" .. tostring(ref.platform) .. ":" .. tostring(ref.id)
        end
        return "a:" .. tostring(ref.id)
    end

    local function resolve_entry(ref)
        local presence_manager = managers and managers.presence

        if not presence_manager then
            return nil, "Managers.presence is unavailable"
        end

        local fn_name = ref.platform and "get_presence_by_platform" or "get_presence"

        if type(presence_manager[fn_name]) ~= "function" then
            report_once("watch_" .. fn_name,
                "[Vox Manifold] Managers.presence." .. fn_name .. " is missing. " ..
                "The game has changed; watched accounts cannot be read.")
            return nil, fn_name .. " is missing"
        end

        local ok, entry, first_update_promise

        if ref.platform then
            ok, entry, first_update_promise = pcall(presence_manager[fn_name], presence_manager, ref.platform, ref.id)
        else
            ok, entry, first_update_promise = pcall(presence_manager[fn_name], presence_manager, ref.id)
        end

        if not ok then
            return nil, fn_name .. " failed: " .. tostring(entry)
        end

        if not entry then
            return nil, "no presence entry for " .. tostring(ref.id)
        end

        if type(first_update_promise) == "table" and type(first_update_promise.catch) == "function" then
            pcall(first_update_promise.catch, first_update_promise, function() end)
        end

        return entry
    end

    local function entry_is_alive(entry)
        if type(entry) ~= "table" then
            return false
        end

        if type(entry.is_alive) ~= "function" then
            report_once("is_alive",
                "[Vox Manifold] presence entry has no is_alive. " ..
                "The game has changed; watched accounts cannot be held open and will go stale.")
            return true
        end

        local ok, alive = pcall(entry.is_alive, entry)

        if not ok or not alive then
            return false
        end

        return true
    end

    p.ref_key = ref_key

    function p.watch(ref)
        local key = ref_key(ref)

        if not key then
            return nil, "watch requires a table with an id"
        end

        local existing = watched[key]

        if existing then
            if entry_is_alive(existing.vm_entry) then
                return existing
            end

            local revived, revive_err = resolve_entry(existing.vm_ref)

            if not revived then
                return nil, revive_err
            end

            existing.vm_entry = revived

            return existing
        end

        local entry, err = resolve_entry(ref)

        if not entry then
            return nil, err
        end

        local handle

        handle = {
            vm_ref_key = key,
            vm_ref = { id = ref.id, platform = ref.platform },
            vm_entry = entry,
            presence = function()
                return handle.vm_entry
            end,
        }

        watched[key] = handle

        return handle
    end

    function p.keep_alive()
        local revived_count = 0

        for key, handle in pairs(watched) do
            if not entry_is_alive(handle.vm_entry) then
                local revived, err = resolve_entry(handle.vm_ref)

                if revived then
                    handle.vm_entry = revived
                    revive_failed[key] = nil
                    revived_count = revived_count + 1
                    mod:info("[Vox Manifold] watched account " .. key ..
                        " was reclaimed by the game and has been re-resolved")
                elseif not revive_failed[key] then
                    revive_failed[key] = true
                    mod:info("[Vox Manifold] watched account " .. key ..
                        " could not be re-resolved: " .. tostring(err) ..
                        ". Retrying every keep-alive tick until it comes back.")
                end
            end
        end

        return revived_count
    end

    function p.unwatch(ref_or_key)
        local key = type(ref_or_key) == "string" and ref_or_key or ref_key(ref_or_key)

        if not key or not watched[key] then
            return false
        end

        watched[key] = nil
        revive_failed[key] = nil

        return true
    end

    function p.handle(key)
        return watched[key]
    end

    function p.watched()
        local out = {}

        for _, handle in pairs(watched) do
            out[#out + 1] = handle
        end

        return out
    end

    function p.clear_watches()
        watched = {}
        revive_failed = {}
    end

    function p.install(get_keys)
        local myself = class and class.PresenceEntryMyself

        if not myself or type(myself.create_key_values) ~= "function" then
            report_once("hook",
                "[Vox Manifold] PresenceEntryMyself.create_key_values is missing. " ..
                "The game has changed; no mod state can be published.")
            return false
        end

        mod:hook(myself, "create_key_values", function(func, self, white_list)
            local ok, key_values = pcall(func, self, white_list)

            if not ok or type(key_values) ~= "table" then
                report_once("hook_call",
                    "[Vox Manifold] create_key_values failed upstream: " .. tostring(key_values) ..
                    ". Publishing mod keys only; engine presence fields are left as they are.")
                key_values = {}
            end

            local keys = get_keys()

            if keys then
                for key, value in pairs(keys) do
                    key_values[key] = value
                end
            end

            return key_values
        end)

        return true
    end

    function p.push(keys)
        local presence = managers and managers.presence

        if not presence or type(presence._update_my_presence) ~= "function" then
            report_once("push",
                "[Vox Manifold] Managers.presence._update_my_presence is missing. " ..
                "The game has changed; mod state cannot be published.")
            return false
        end

        local white_list = {}
        if keys then
            for key in pairs(keys) do
                white_list[key] = true
            end
        end

        local ok, err = pcall(function()
            presence:_update_my_presence(white_list)
        end)

        if not ok then
            report_once("push_err",
                "[Vox Manifold] presence push failed: " .. tostring(err))
            return false
        end

        return true
    end

    local function entry_for(member)
        if not member or type(member.presence) ~= "function" then
            return nil
        end
        local ok, entry = pcall(member.presence, member)
        if not ok or not entry then
            return nil
        end
        return entry
    end

    local function entry_is_myself(entry)
        if type(entry.is_myself) ~= "function" then
            return false
        end
        local ok, res = pcall(entry.is_myself, entry)
        return ok and res == true
    end

    function p.read(member, key)
        local entry = entry_for(member)
        if not entry then
            return nil
        end

        if type(member) == "table" and member.vm_ref_key ~= nil and not entry_is_alive(entry) then
            local revived = resolve_entry(member.vm_ref)
            if revived then
                member.vm_entry = revived
                entry = revived
            end
        end

        if entry_is_myself(entry) then
            return nil
        end

        if type(entry._key_value_string) ~= "function" then
            report_once("read",
                "[Vox Manifold] presence entry has no _key_value_string. " ..
                "The game has changed; no party member state can be read.")
            return nil
        end

        local ok, raw = pcall(entry._key_value_string, entry, key)
        if not ok then
            return nil
        end

        return raw
    end

    function p.is_myself(member)
        local entry = entry_for(member)
        if not entry then
            return false
        end
        return entry_is_myself(entry)
    end

    function p.members()
        local pim = managers and managers.party_immaterium
        if not pim or type(pim.all_members) ~= "function" then
            return {}
        end
        local ok, members = pcall(pim.all_members, pim)
        if not ok or type(members) ~= "table" then
            return {}
        end

        local out = {}
        for i = 1, #members do
            out[i] = members[i]
        end
        return out
    end

    return p
end
