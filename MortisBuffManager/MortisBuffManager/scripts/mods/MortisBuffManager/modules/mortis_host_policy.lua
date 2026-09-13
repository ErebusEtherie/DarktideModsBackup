-- Host-owned exclusions, independent from every player's saved selections.
local P={max_entries=256}
local function copy(t) local out={};for k,v in pairs(t or {})do out[k]=type(v)=="table" and copy(v) or v end;return out end
function P.valid(value)
    if type(value)~="table" then return false end
    for k in pairs(value)do if k~="native" and k~="diy" then return false end end
    local total=0
    for _,kind in ipairs({"native","diy"})do
        if type(value[kind])~="table" then return false end
        if kind=="native" and next(value[kind]) then return false end
        for id,banned in pairs(value[kind])do
            total=total+1
            if total>P.max_entries or banned~=true or type(id)~="string" or #id>129 then return false end
            if kind=="native" and not id:match("^[%w_]+$") or kind=="diy" and not id:match("^[%w_-]+/[%w_-]+$") then return false end
        end
    end
    return true
end
function P.new(mod,api)
    local saved=mod:get("mortis_host_bans_v1")
    local configured=P.valid(saved) and copy(saved) or {native={},diy={}}
    local frozen,mission,connection,identity,remote_rules,remote_valid;local notified={}
    local self={}
    function self.host_rules()
        local active,token=api.mission()
        if not active then frozen=nil;mission=nil
        elseif not frozen or mission~=token then frozen=copy(configured);mission=token end
        return frozen or configured
    end
    function self.current()
        if api.client() then
            local rules=api.remote()
            if remote_rules~=rules then remote_rules=rules;remote_valid=rules and P.valid(rules.bans) end
            return remote_valid and rules and rules.bans or nil
        end
        return self.host_rules()
    end
    function self.revision()
        if api.client() then local rules=api.remote();return self.current() and rules and rules.revision end
        return api.revision()
    end
    function self.editable() return mod:is_enabled() and not api.client() and not api.mission() end
    function self.migrate_package_keys(mapping)
        local updated=copy(configured);local changed=false
        for old,targets in pairs(mapping or {})do if updated.diy[old] then
            updated.diy[old]=nil
            for _,id in ipairs(targets)do updated.diy[id]=true end
            changed=true
        end end
        if changed and P.valid(updated) then
            configured=updated;mod:set("mortis_host_bans_v1",copy(configured));api.changed()
        end
    end
    local function key(kind,id)
        if kind~="diy" or not api.availability then return id end
        local availability=api.availability()
        local entry=id:match("/([^/]+)$") or id
        return availability and availability.library.."/"..entry or id
    end
    function self.missing(id)
        if not api.missing then return {} end
        return api.missing(id:match("/([^/]+)$") or id)
    end
    function self.allowed(kind,id)
        local rules=self.current()
        if not rules then return false,"diy_policy_pending" end
        id=key(kind,id)
        if kind=="diy" and #self.missing(id)>0 then return false,"diy_peer_missing" end
        return not rules[kind][id],rules[kind][id] and "diy_host_banned" or nil
    end
    function self.set(kind,id,enabled)
        if kind~="diy" or not self.editable() or type(enabled)~="boolean" or not api.known(kind,id) or enabled and #self.missing(id)>0 then return false end
        local next_rules=copy(configured);next_rules[kind][id]=not enabled or nil
        if not P.valid(next_rules) then return false end
        configured=next_rules;mod:set("mortis_host_bans_v1",copy(configured));api.changed();return true
    end
    function self.set_many(ids,enabled)
        if not self.editable() or type(ids)~="table" or #ids>128 or type(enabled)~="boolean" then return 0,type(ids)=="table" and #ids or 0 end
        local count=0;for k,id in pairs(ids)do count=count+1;if type(k)~="number" or k%1~=0 or k<1 or k>#ids or type(id)~="string" then return 0,#ids end end
        if count~=#ids then return 0,#ids end
        local next_rules=copy(configured);local changed,skipped=0,0
        for _,id in ipairs(ids)do
            if not api.known("diy",id) or enabled and #self.missing(id)>0 then skipped=skipped+1
            elseif next_rules.diy[id]~=(not enabled or nil) then next_rules.diy[id]=not enabled or nil;changed=changed+1 end
        end
        if not P.valid(next_rules) then return 0,#ids end
        if changed>0 then configured=next_rules;mod:set("mortis_host_bans_v1",copy(configured));api.changed() end
        return changed,skipped
    end
    function self.filter(kind,ids,prefix)
        local result={};for _,id in ipairs(ids or {})do if self.allowed(kind,(prefix or "")..id) then result[#result+1]=id end end;return result
    end
    function self.notify(kind,ids,prefix,name)
        local rules=self.current();if not rules then return end
        local token,character=api.identity()
        if connection~=token or identity~=character then connection=token;identity=character;notified={} end
        local previous=notified[kind] or {};local active={};local names={}
        for _,id in ipairs(ids or {})do
            local entry_key=key(kind,(prefix or "")..id)
            local unavailable=kind=="diy" and #self.missing(id)>0
            if rules[kind][entry_key] or unavailable then
                active[entry_key]=true;if not previous[entry_key] then names[#names+1]=name(id) end
            end
        end
        notified[kind]=active
        if #names>0 then mod:notify(mod:localize("diy_unavailable_notice",table.concat(names,", "))) end
    end
    function self.reset() frozen=nil;mission=nil;connection=nil;identity=nil;remote_rules=nil;remote_valid=nil;notified={} end
    return self
end
return P
