-- Named, snapshot-backed local assets. SimpleAssets owns native loading;
-- this module owns bounded requests, reuse, consumers and callback lifetimes.
local A={version=1,timeout=35,max_records=256,max_scopes=256}
local function copy(value)
    if not value then return nil end
    local out={};for k,v in pairs(value)do out[k]=v end;return out
end
local function message(value)
    return tostring(type(value)=="table" and (value.error or "diy_asset_load_failed") or value or "diy_asset_load_failed")
end
function A.new(mod,Hash,options)
    options=options or {}
    local self={};local scopes,records={},{};local scope_count,record_count,clock=0,0,0
    local function report(pack,why)
        if options.error then pcall(options.error,pack.manifest.id,message(why)) end
    end
    local function enabled()
        return type(mod.is_enabled)~="function" or mod:is_enabled()
    end
    local function provider()
        local find=options.provider or function()return get_mod("SimpleAssets")end
        local ok,value=pcall(find)
        if not ok or not value or type(value.is_enabled)=="function" and not value:is_enabled() then return nil end
        -- This capability exists in the audited v2 interface. The older
        -- font/texture API has different argument/result contracts.
        if type(value.get_resource_name)~="function" or type(value.load_animation)~="function" then return nil end
        return value
    end
    function self.available(kind)
        local p=provider();return p~=nil and (kind==nil or type(p["load_"..tostring(kind)])=="function")
    end
    local function finish_record(record,value,why)
        if record.state~="pending" then return end
        if value then record.state="ready";record.value=value else record.state="failed";record.error=message(why) end
        local listeners=record.listeners;record.listeners={}
        if not value then records[record.key]=nil;record_count=record_count-1 end
        for handle in pairs(listeners)do handle._deliver(record) end
    end
    function self.open(pack,active,on_error)
        if not enabled() then return nil,"diy_asset_inactive" end
        if active~=nil and type(active)~="function" then return nil,"diy_asset_callback" end
        if type(pack)~="table" or type(pack.manifest)~="table" then return nil,"diy_package_missing" end
        if scope_count>=A.max_scopes then return nil,"diy_asset_limit" end
        -- A view needs the staged version and descriptors, not every JSON,
        -- Lua and binary byte in the package snapshot. Do not retain those
        -- buffers across many independently opened/refreshed client views.
        local descriptors={};for i,asset in ipairs(pack.manifest.assets or {})do descriptors[i]=copy(asset) end
        pack={manifest={id=pack.manifest.id,assets=descriptors},asset_base=pack.asset_base,asset_error=pack.asset_error}
        local scope={};local closed=false;local handles,cleanup={},{}
        local definitions={};for _,asset in ipairs(pack.manifest.assets or {})do definitions[asset.id]=asset end
        scope_count=scope_count+1;scopes[scope]=true
        local function alive()
            if closed or not enabled() then return false end
            if active then local ok,value=pcall(active);return ok and value==true end
            return true
        end
        local function error_callback(why)
            report(pack,why)
            if on_error then pcall(on_error,message(why)) end
        end
        function scope:close(reason)
            if closed then return end;closed=true
            for _,handle in pairs(handles)do handle:cancel() end
            handles={};scopes[scope]=nil;scope_count=scope_count-1
            for i=#cleanup,1,-1 do local ok,why=pcall(cleanup[i],reason or "closed");if not ok then error_callback(why) end end
            cleanup={}
        end
        function scope:own(fn)
            if not alive() or type(fn)~="function" or #cleanup>=64 then return nil,"diy_asset_limit" end
            cleanup[#cleanup+1]=fn;return true
        end
        function scope:release(id)
            local handle=handles[id];if handle then handle:cancel();handles[id]=nil end
        end
        function scope:load(id,callback)
            if not alive() then return nil,"diy_asset_inactive" end
            if callback~=nil and type(callback)~="function" then return nil,"diy_asset_callback" end
            local asset=definitions[id];if not asset then return nil,"diy_asset_undeclared" end
            local existing=handles[id]
            if existing then
                if callback then local ok,why=existing:_subscribe(callback);if not ok then return nil,why end end
                return existing
            end
            local handle={};local state,value,why="pending",nil,nil;local callbacks={};local record
            local function notify(fn)
                if not alive() then return end
                local ok,err=pcall(fn,copy(value),why)
                if not ok then error_callback(err) end
            end
            function handle:status()return state,why end
            function handle:get()
                if not alive() then return nil,"diy_asset_inactive" end
                if record and provider()~=record.provider then return nil,"diy_asset_provider_changed" end
                if state=="ready" then return copy(value) end
                return nil,why or "diy_asset_pending"
            end
            function handle:cancel()
                if state=="cancelled" then return end
                state="cancelled";why="diy_asset_cancelled";value=nil;callbacks={}
                if record then record.listeners[handle]=nil end
                if handles[id]==handle then handles[id]=nil end
            end
            function handle:_subscribe(fn)
                if state=="pending" then
                    if #callbacks>=16 then return nil,"diy_asset_limit" end
                    callbacks[#callbacks+1]=fn
                elseif state~="cancelled" then notify(fn) end
                return true
            end
            function handle._deliver(result)
                if state~="pending" then return end
                if not alive() then handle:cancel();return end
                state=result.state;value=result.value;why=result.error
                if why then report(pack,why) end
                local waiting=callbacks;callbacks={}
                for _,fn in ipairs(waiting)do if state~="cancelled" then notify(fn) end end
            end
            handles[id]=handle;if callback then callbacks[1]=callback end
            local p=provider()
            local initial_error=pack.asset_error or (not pack.asset_base and "diy_asset_not_prepared") or
                (not p and "diy_asset_provider_missing") or (type(p["load_"..asset.type])~="function" and "diy_asset_type_unavailable")
            local path=pack.asset_base and pack.asset_base.."/"..asset.path
            local key=path and asset.type..":"..path..":"..tostring(asset.hotspot_x)..":"..tostring(asset.hotspot_y)
            -- Native resources belong to the provider instance. Do not reuse
            -- handles after it has been reloaded/replaced.
            record=key and records[key]
            if record and record.provider~=p then
                if record.state=="pending" then finish_record(record,nil,"diy_asset_provider_changed") else records[key]=nil;record_count=record_count-1 end
                record=nil
            end
            if not initial_error and not record and record_count>=A.max_records then initial_error="diy_asset_limit" end
            if initial_error then handle._deliver({state="failed",error=initial_error});return handle end
            if record then
                if record.state=="pending" then record.listeners[handle]=true else handle._deliver(record) end
                return handle
            end
            record={key=key,provider=p,state="pending",started=clock,listeners={[handle]=true}}
            records[key]=record;record_count=record_count+1
            local alias="diy_"..Hash.hex(key):sub(1,40)
            local ok,promise=pcall(function()
                if asset.type=="font" then return p.load_font(alias,path)
                elseif asset.type=="mouse_cursor" then return p.load_mouse_cursor(path,asset.hotspot_x,asset.hotspot_y)
                else return p["load_"..asset.type](path) end
            end)
            if not ok then finish_record(record,nil,promise);return handle end
            local attached,attach_error=pcall(function()
                assert(promise and type(promise.next)=="function","diy_asset_invalid_promise")
                promise:next(function(result)
                    if type(result)~="table" or result.is_ok~=true then finish_record(record,nil,result);return end
                    local normalized={is_ok=true,type=asset.type}
                    for _,field in ipairs({"resource_name","texture","width","height","url","font_type"})do normalized[field]=result[field] end
                    if asset.type=="texture" and normalized.texture==nil or asset.type~="texture" and type(normalized.resource_name)~="string" or
                        asset.type=="font" and normalized.font_type~=alias then finish_record(record,nil,"diy_asset_invalid_result");return end
                    finish_record(record,normalized)
                end,function(err)finish_record(record,nil,err)end)
            end)
            if not attached then finish_record(record,nil,attach_error) end
            return handle
        end
        scope.is_active=alive
        return scope
    end
    function self.close_all(reason)
        local current={};for scope in pairs(scopes)do current[#current+1]=scope end
        for _,scope in ipairs(current)do scope:close(reason or "manager_end") end
    end
    function self.update(dt)
        if type(dt)=="number" and dt==dt and dt>=0 and dt<math.huge then clock=clock+dt end
        if not enabled() then self.close_all("disabled") end
        local expired={};local current=provider();local changed=false
        for key,record in pairs(records)do
            if record.provider~=current then
                changed=true
                if record.state=="pending" then expired[#expired+1]={record,"diy_asset_provider_changed"}
                else records[key]=nil;record_count=record_count-1 end
            elseif record.state=="pending" and clock-record.started>=A.timeout then expired[#expired+1]={record,"diy_asset_timeout"} end
        end
        for _,item in ipairs(expired)do finish_record(item[1],nil,item[2]) end
        if changed then self.close_all("provider_changed") end
        local inactive={};for scope in pairs(scopes)do if not scope.is_active() then inactive[#inactive+1]=scope end end
        for _,scope in ipairs(inactive)do scope:close("inactive") end
    end
    function self.status()
        local pending=0;for _,r in pairs(records)do if r.state=="pending" then pending=pending+1 end end
        return {provider=self.available(),scopes=scope_count,records=record_count,pending=pending}
    end
    return self
end
return A
