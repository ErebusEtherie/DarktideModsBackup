-- Definition/package fingerprints only; Lua is never transmitted. Availability uses compact
-- three-bit reasons per peer so a full library does not duplicate player names.
local T={max_players=7}
T.reasons={"missing","different","disabled","pending","unconfirmed","disconnected"}
local function id(s) return type(s)=="string" and #s<=64 and s:match("^[a-z][a-z0-9_%-]*$") end
function T.valid(m)
    if type(m)~="table" or type(m.enabled)~="boolean" or type(m.entries)~="table" then return false end
    for k in pairs(m)do if k~="enabled" and k~="entries" then return false end end
    local count=0
    for key,value in pairs(m.entries)do
        count=count+1
        if count>128 or not id(key) or type(value)~="string" or #value>80 or not value:match("^[0-9a-f]+:%d+$") then return false end
        local size=#value:match("^([^:]+)");if size~=64 and size~=16 then return false end
    end
    return true
end
function T.valid_availability(v)
    if type(v)~="table" or not id(v.library) or type(v.players)~="table" or type(v.blocked)~="table" or #v.players>T.max_players then return false end
    for k in pairs(v)do if k~="library" and k~="players" and k~="blocked" then return false end end
    local n=0
    for i,name in pairs(v.players)do
        n=n+1
        if type(i)~="number" or i%1~=0 or i<1 or i>#v.players or type(name)~="string" or #name>128 then return false end
    end
    if n~=#v.players then return false end
    n=0
    for key,mask in pairs(v.blocked)do
        n=n+1
        if n>128 or not id(key) or type(mask)~="number" or mask~=mask or mask%1~=0 or mask<1 or mask>=8^#v.players then return false end
        for i=1,#v.players do if math.floor(mask/8^(i-1))%8>6 then return false end end
    end
    return true
end
function T.build(library,manifest,peers)
    local out={library=library,players={},blocked={}}
    for i,p in ipairs(peers)do if i<=T.max_players then out.players[i]=p.name end end
    for key,hash in pairs(manifest.entries)do
        local mask=0
        for i,p in ipairs(peers)do if i<=T.max_players then
            local reason=p.reason
            if not reason then
                local m=p.manifest
                if not m then reason=4
                elseif not m.enabled then reason=3
                elseif not m.entries[key] then reason=1
                elseif m.entries[key]~=hash then reason=2 end
            end
            if reason then mask=mask+reason*8^(i-1) end
        end end
        if mask>0 then out.blocked[key]=mask end
    end
    return out
end
function T.missing(v,key)
    local out={};local mask=v and v.blocked[key] or 0
    for i,name in ipairs(v and v.players or {})do
        local reason=math.floor(mask/8^(i-1))%8
        if reason>0 then out[#out+1]={name=name,reason=T.reasons[reason]} end
    end
    return out
end
function T.valid_limits(v)
    if type(v)~="table" or type(v.max_total)~="number" or v.max_total~=v.max_total or v.max_total%1~=0 or v.max_total<0 or v.max_total>99 then return false end
    for k in pairs(v)do if k~="max_total" then return false end end
    return true
end
return T
