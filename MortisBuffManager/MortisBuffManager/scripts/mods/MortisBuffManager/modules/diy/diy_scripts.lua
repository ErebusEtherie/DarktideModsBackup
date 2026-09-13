-- Trusted local Lua extensions. There is one isolated module cache per
-- package/mission; native authority and selected entries control callbacks.
local S={api_version={major=1,minor=1}}
local compile=Mods and Mods.lua and Mods.lua.loadstring or loadstring
local environment=Mods and Mods.lua and (Mods.lua.setfenv or Mods.lua.debug and Mods.lua.debug.setfenv) or rawget(_G,"setfenv")
local function weak() return setmetatable({},{__mode="k"}) end
local function keys(s) local out={};for k in s:gmatch("%S+")do out[k]=true end;return out end
local callback_fields=keys("on_activate on_deactivate on_update on_event interval events")
local module_fields=keys("api_version entries exports")
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
function S.attach(engine,snapshot,options)
    engine.package_sources=snapshot.sources or {}
    local packages=snapshot.packages or {};local sources=snapshot.sources or {}
    local needed=false
    for _,entry in ipairs(snapshot.document.entries)do if entry.script then needed=true;break end end
    if not needed then return engine end
    local Schema,Packages,PackageAPI=options.Schema,options.Packages,options.PackageAPI
    local native,catalog,kind=options.native,options.catalog,snapshot.document.kind
    local global_env=_G;local native_require=require
    local caches,loading,modules,failed,environments={},{},{},{},{}
    local globals,owners={},weak();local event_global,event_owners={},weak()
    local running=false;local finished=false;local callbacks_left=128
    local timers={};local binding_count=0
    local function report(package_id,message)
        if options.error then options.error(package_id,tostring(message)) end
        if native.error then native.error(message,package_id,"lua") end
    end
    local load_module,module_for
    local function declared_dependency(package_id,id)
        local pack=packages[package_id];local permitted=false
        for _,dep in ipairs(pack.manifest.dependencies or {})do if dep.id==id then permitted=true end end
        if not permitted or not packages[id] then error("Undeclared/unavailable package dependency: "..tostring(id),0) end
        return packages[id]
    end
    local function dependency(package_id,id,path)
        local other=declared_dependency(package_id,id)
        if path then return load_module(id,path) end
        if not other.manifest.entrypoint then return {} end
        local result=module_for(id)
        if not result then error("Dependency Lua entrypoint failed: "..id,0) end
        return result.exports or {}
    end
    load_module=function(id,path)
        local pack=assert(packages[id],"Unknown package: "..tostring(id))
        if not Packages.path(path) or not path:match("^lua/.+%.lua$") or type(pack.files[path])~="string" then error("Undeclared Lua module: "..tostring(path),0) end
        caches[id]=caches[id] or {};loading[id]=loading[id] or {}
        if caches[id][path]~=nil then return caches[id][path] end
        if loading[id][path] then error("Lua module cycle: "..id.."/"..path,0) end
        loading[id][path]=true
        local env=environments[id]
        if not env then
        env={package_id=id,api_version={major=1,minor=1},package_version=pack.manifest.package_version}
        env._G=env
        env.package_require=function(relative) return load_module(id,relative) end
        env.dependency_require=function(other,relative) return dependency(id,other,relative) end
        env.require=function(name)
            if type(name)=="string" and name:sub(1,2)=="./" then return load_module(id,"lua/"..name:sub(3)) end
            return native_require(name)
        end
        -- The game makes reads of unknown global names an error. Package
        -- private globals must still start as nil instead of consulting that
        -- strict-environment metatable.
        setmetatable(env,{__index=function(_,key)return rawget(global_env,key) end})
        environments[id]=env
        end
        local chunk,why=compile(pack.files[path],"@DIY/"..id.."/"..path)
        if not chunk then loading[id][path]=nil;error(why,0) end
        environment(chunk,env)
        local ok,value=pcall(chunk);loading[id][path]=nil
        if not ok then error(value,0) end
        if value==nil then value=true end;caches[id][path]=value;return value
    end
    module_for=function(package_id)
        if failed[package_id] then return nil end
        if not modules[package_id] then
            local pack=packages[package_id]
            local ok,value=pcall(function()
                local m=load_module(package_id,pack.manifest.entrypoint)
                if type(m)~="table" then error("Lua entrypoint must return an API module") end
                for key in pairs(m)do if not module_fields[key] then error("Unknown Lua module field: "..tostring(key)) end end
                if type(m.api_version)~="table" or m.api_version.major~=1 or not finite(m.api_version.minor) or m.api_version.minor<0 or m.api_version.minor>S.api_version.minor or m.api_version.minor%1~=0 then error("Unsupported Lua API version") end
                if type(m.entries)~="table" or m.exports~=nil and type(m.exports)~="table" then error("entries and exports must be tables") end
                local known={};for _,e in ipairs(pack.document.entries)do known[e.id]=e end
                for id,hooks in pairs(m.entries)do
                    if not known[id] or not known[id].script or type(hooks)~="table" then error("Lua entry requires a matching script=true definition: "..tostring(id)) end
                    for key,v in pairs(hooks)do
                        if not callback_fields[key] then error("Unknown entry callback field: "..tostring(key)) end
                        if key:sub(1,3)=="on_" and type(v)~="function" then error(key.." must be a function") end
                    end
                    if hooks.on_update and (not finite(hooks.interval) or hooks.interval<.1 or hooks.interval>600) then error("on_update requires interval from 0.1 to 600 seconds") end
                    if hooks.events~=nil then
                        if type(hooks.events)~="table" or #hooks.events>64 then error("events must be an array of at most 64 event names") end
                        local count,seen=0,{}
                        for index,name in pairs(hooks.events)do
                            count=count+1
                            if type(index)~="number" or index%1~=0 or index<1 or index>#hooks.events or not (catalog.events[name] or keys("spawn enemy_died mission_start signal")[name]) or seen[name] then error("Unknown, sparse or duplicate event subscription: "..tostring(name)) end
                            seen[name]=true
                        end
                        if count~=#hooks.events then error("Sparse events array") end
                    end
                    if hooks.on_event and (not hooks.events or #hooks.events==0) then error("on_event requires explicit event subscriptions") end
                end
                for id,entry in pairs(known)do if entry.script and not m.entries[id] then error("Missing callbacks for script entry: "..id) end end
                return m
            end)
            if not ok then failed[package_id]=true;report(package_id,value);return nil end
            modules[package_id]=value
        end
        return modules[package_id]
    end
    local function definition(package_id,entry_id)
        local m=module_for(package_id);return m and m.entries[entry_id]
    end
    local function applicable(binding,unit,event)
        if not binding.active or engine.finished then return false end
        local entry=engine.entry_by_id[binding.id]
        if native.available and not native.available(entry,binding.owner or unit) then return false end
        return options.Engine.test(entry.conditions,entry.match,function(subject)
            local target=unit
            if subject=="target" then target=event and event.target elseif subject=="attacker" then target=event and event.attacker end
            return engine.context(target,event)
        end,event)
    end
    local deactivate
    local function call(binding,name,unit,...)
        local fn=binding.hooks[name]
        if not fn or not binding.active then return true end
        if callbacks_left<=0 and name~="on_deactivate" then engine.metrics.dropped=engine.metrics.dropped+1;return false end
        callbacks_left=callbacks_left-1
        local ctx=binding.context;local old_unit=ctx.unit;ctx.unit=unit;ctx.time=engine.now
        local old_running=running;running=true
        local ok,why=pcall(fn,ctx,...);running=old_running;ctx.unit=old_unit
        if not ok then
            report(binding.source.package_id,binding.source.entry_id.."/"..name..": "..tostring(why))
            if name~="on_deactivate" then deactivate(binding,"error",true) end
        end
        return ok
    end
    deactivate=function(binding,reason,skip_callback)
        if not binding.active then return end
        if not skip_callback then call(binding,"on_deactivate",binding.owner,reason) end
        binding.active=false
        engine.clear_script(binding.id,binding.owner)
        for i=#binding.cleanup,1,-1 do
            local ok,why=pcall(binding.cleanup[i],reason)
            if not ok then report(binding.source.package_id,"cleanup: "..tostring(why)) end
        end
        binding.cleanup={};binding_count=binding_count-1
        if binding.asset_scope then binding.asset_scope:close(reason);binding.asset_scope=nil end
    end
    local function context(binding)
        local source=binding.source;local pack=packages[source.package_id]
        local ctx={api_version={major=1,minor=1},package_id=source.package_id,package_version=pack.manifest.package_version,
            entry_id=source.entry_id,qualified_id=binding.id,owner=binding.owner,unit=binding.owner,state={},role="authority"}
        function ctx:resource(path)
            if not binding.active or not Packages.path(path) or not path:match("^resources/") then return nil,"Invalid/inactive resource path" end
            return pack.files[path],pack.files[path]==nil and "Resource is not in the package snapshot" or nil
        end
        function ctx:load_asset(id,callback)
            if not binding.active then return nil,"diy_asset_inactive" end
            if callback~=nil and type(callback)~="function" then return nil,"diy_asset_callback" end
            if not options.assets then return nil,"diy_asset_provider_missing" end
            if not binding.asset_scope then
                local scope,why=options.assets.open(pack,function()
                    return binding.active and not engine.finished and (not binding.owner or native.alive(binding.owner)) and
                        (not options.authority or options.authority())
                end,function(why)
                    report(source.package_id,source.entry_id.."/asset callback: "..why)
                    deactivate(binding,"error",true)
                end)
                if not scope then return nil,why end;binding.asset_scope=scope
            end
            local wrapped
            if callback then wrapped=function(result,why)
                local previous_unit,previous_running=ctx.unit,running;ctx.unit=binding.owner;ctx.time=engine.now;running=true
                local ok,err=pcall(callback,result,why);ctx.unit=previous_unit;running=previous_running
                if not ok then error(err,0) end
            end end
            return binding.asset_scope:load(id,wrapped)
        end
        function ctx:release_asset(id)
            if binding.asset_scope then binding.asset_scope:release(id) end
        end
        function ctx:require(path) assert(binding.active,"Inactive entry context");return load_module(source.package_id,path) end
        function ctx:dependency(id,path) assert(binding.active,"Inactive entry context");return dependency(source.package_id,id,path) end
        function ctx:on_cleanup(fn)
            assert(binding.active and type(fn)=="function" and #binding.cleanup<64,"At most 64 active cleanup callbacks")
            binding.cleanup[#binding.cleanup+1]=fn
        end
        function ctx:context(unit,event) return engine.context(unit or self.unit,event) end
        function ctx:units(selector,radius)
            local ok,why=Schema.validate_selector(selector,catalog);assert(ok,why)
            if radius~=nil then assert(self.unit and finite(radius) and radius>=1 and radius<=50,"Radius requires a callback unit and must be from 1 to 50") end
            return native.units(selector,radius and self.unit or nil,radius,selector.kind=="players" and 4 or 64)
        end
        function ctx:set_effects(effects)
            if not binding.active then return false end
            if effects then local ok,why=Schema.validate_effect(effects,catalog,kind);assert(ok,why) end
            return engine.set_script_effects(binding.id,binding.owner,effects and Schema.copy(effects))
        end
        function ctx:compile_action(action,slot)
            local ok,why=Schema.validate_action(action,catalog,kind);assert(ok,why)
            slot=slot or "default";assert(type(slot)=="string" and #slot<=64 and slot:match("^[%w_%-]+$"),"Invalid action slot")
            local prepared=Schema.copy(action)
            if prepared.type=="signal" then prepared.name=PackageAPI.signal_id(pack,prepared.name) end
            return function(event)
                if not applicable(binding,ctx.unit,event) then return false end
                return engine.script_action(binding.id,binding.owner,ctx.unit,prepared,event,slot)
            end
        end
        function ctx:action(action,event,slot) return self:compile_action(action,slot)(event) end
        function ctx:qualify(id,package_id)
            package_id=package_id or source.package_id
            if package_id~=source.package_id then declared_dependency(source.package_id,package_id) end
            assert(Packages.id(id),"Invalid entry ID");return PackageAPI.entry_identity(packages[package_id],id)
        end
        function ctx:signal(name,duration)
            if not binding.active then return false end
            assert(Packages.id(name),"Invalid signal ID")
            return engine.emit_signal(PackageAPI.signal_id(pack,name),duration)
        end
        function ctx:global_signal(name,duration)
            return binding.active and engine.emit_signal(name,duration) or false
        end
        function ctx:random(key,chance)
            assert(type(key)=="string" and #key<=64 and finite(chance) and chance>=0 and chance<=1,"Invalid random stream/chance")
            return engine.roll("script/"..source.package_id.."/"..source.entry_id.."/"..key,self.unit or engine.global_token,chance)
        end
        function ctx:log(message)
            if options.log then options.log(source.package_id.."/"..source.entry_id,tostring(message)) end
        end
        return ctx
    end
    local function rebuild_index()
        event_global={};event_owners=weak();timers={}
        local function add(binding,index)
            if not binding.active then return end
            for _,name in ipairs(binding.hooks.events or {})do index[name]=index[name] or {};index[name][#index[name]+1]=binding end
            if binding.hooks.on_update then timers[#timers+1]=binding end
        end
        local ids={};for id in pairs(globals)do ids[#ids+1]=id end;table.sort(ids)
        for _,id in ipairs(ids)do add(globals[id],event_global) end
        local units={};for unit in pairs(owners)do units[#units+1]=unit end
        table.sort(units,function(a,b)return native.key(a)<native.key(b) end)
        for _,unit in ipairs(units)do
            local index={};event_owners[unit]=index;ids={};for id in pairs(owners[unit])do ids[#ids+1]=id end;table.sort(ids)
            for _,id in ipairs(ids)do add(owners[unit][id],index) end
        end
    end
    local function reconcile(owner,ids)
        local group
        if owner then group=owners[owner];if not group then group={};owners[owner]=group end
        else group=globals end
        local wanted={};for id in pairs(ids or {})do if engine.entry_by_id[id].script then wanted[id]=true end end
        local changed=false
        for id,b in pairs(group)do if not wanted[id] then deactivate(b,"removed");group[id]=nil;changed=true end end
        local names={};for id in pairs(wanted)do names[#names+1]=id end;table.sort(names)
        for _,id in ipairs(names)do if not group[id] then
            local source=sources[id];local hooks=source and definition(source.package_id,source.entry_id)
            if hooks then
                local b={id=id,source=source,hooks=hooks,owner=owner,active=true,cleanup={},next_tick=engine.now+(hooks.interval or 1),last_tick=engine.now}
                b.context=context(b);group[id]=b;binding_count=binding_count+1;changed=true
                call(b,"on_activate",owner)
            end
        end end
        if owner and not next(group) then owners[owner]=nil end
        if changed then rebuild_index() end
    end
    local set_global,set_owner,tick,dispatch,finish=engine.set_global,engine.set_owner,engine.tick,engine.dispatch,engine.finish
    engine.set_global=function(ids)
        if finished then return end
        set_global(ids);reconcile(nil,engine.globals)
    end
    engine.set_owner=function(unit,ids)
        if finished then return end
        set_owner(unit,ids);reconcile(unit,engine.owners[unit])
    end
    engine.dispatch=function(name,unit,event)
        if finished or running or engine.in_action then return end
        dispatch(name,unit,event)
        if binding_count==0 then return end
        local normalized={};for k,v in pairs(event or {})do normalized[k]=v end
        normalized.unit=unit;normalized.name=name
        normalized.target=normalized.target or normalized.attacked_unit or normalized.victim_unit or normalized.target_unit
        normalized.attacker=normalized.attacker or normalized.attacking_unit or unit
        local info=unit and native.info(unit)
        for _,b in ipairs(event_global[name] or {})do
            if (not unit or options.Engine.matches(engine.entry_by_id[b.id].targets,info)) and applicable(b,unit,normalized) then call(b,"on_event",unit,name,normalized) end
        end
        if name=="enemy_died" or name=="signal" then
            local units={};for owner in pairs(event_owners)do units[#units+1]=owner end
            table.sort(units,function(a,b)return native.key(a)<native.key(b) end)
            for _,owner in ipairs(units)do if native.alive(owner) then
                for _,b in ipairs(event_owners[owner][name] or {})do if applicable(b,owner,normalized) then call(b,"on_event",owner,name,normalized) end end
            end end
        else
            local index=event_owners[unit]
            for _,b in ipairs(index and index[name] or {})do if applicable(b,unit,normalized) then call(b,"on_event",unit,name,normalized) end end
        end
    end
    engine.tick=function(dt)
        callbacks_left=128;tick(dt)
        for unit,group in pairs(owners)do if not native.alive(unit) then for _,b in pairs(group)do deactivate(b,"death") end end end
        for _,b in ipairs(timers)do if b.active then
            if b.owner and not native.alive(b.owner) then deactivate(b,"death")
            elseif engine.now>=b.next_tick then
                local elapsed=engine.now-b.last_tick;b.last_tick=engine.now;b.next_tick=engine.now+b.hooks.interval
                if applicable(b,b.owner) then call(b,"on_update",b.owner,elapsed) end
            end
        end end
    end
    engine.finish=function()
        if finished then return end;finished=true
        for _,b in pairs(globals)do deactivate(b,"mission_end") end
        for _,group in pairs(owners)do for _,b in pairs(group)do deactivate(b,"mission_end") end end
        globals={};owners=weak();event_global={};event_owners=weak();timers={};caches={};modules={};loading={};environments={}
        finish()
    end
    return engine
end
return S
