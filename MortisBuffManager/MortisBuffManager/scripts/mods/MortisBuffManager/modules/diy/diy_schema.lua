-- Public v1 contract. The native catalog is injected, never guessed by the runtime.
local S={format="Darktide.DIY",version=1,max_entries=128,max_rules=16,max_actions=8}
function S.copy(v) if type(v)~="table" then return v end;local out={};for k,x in pairs(v) do out[k]=S.copy(x) end;return out end
function S.finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function fail(path,message) error(path..": "..message,0) end
local function object(v,fields,path)
    if type(v)~="table" or getmetatable(v) then fail(path,"expected data object") end
    for k in pairs(v) do if not fields[k] then fail(path.."."..tostring(k),"unknown field") end end
end
local function keys(s) local out={};for k in s:gmatch("%S+") do out[k]=true end;return out end
local function array(v,max,path)
    if type(v)~="table" or getmetatable(v) or #v>max then fail(path,"expected array, max "..max) end
    local count=0;for k in pairs(v) do count=count+1;if type(k)~="number" or k%1~=0 or k<1 or k>#v then fail(path,"dense array required") end end
    if count~=#v then fail(path,"dense array required") end
end
local function number(v,low,high,path,integer)
    if not S.finite(v) or v<low or v>high or integer and v%1~=0 then fail(path,"expected "..(integer and "integer " or "number ")..low..".."..high) end
    return v
end
local function id(v,path)
    if type(v)~="string" or #v>64 or not v:match("^[a-z][a-z0-9_%-]*$") then fail(path,"use 1..64 lowercase letters, digits, _ or -; start with a letter") end
    return v
end
local function text(v,path,max,optional)
    if v==nil and optional then return end
    if type(v)=="string" then if #v==0 or #v>(max or 1024) or v:find("[%z\1-\8\11\12\14-\31]") then fail(path,"invalid text") end
    else
        object(v,keys("en zh-cn zh-tw"),path)
        if not v.en and not v["zh-cn"] then fail(path,"name or description needs en or zh-cn") end
        for k,s in pairs(v) do if type(s)~="string" then fail(path.."."..k,"text required") end;text(s,path.."."..k,max) end
    end
end
local function strings(v,max,path,known)
    array(v,max,path);local seen={}
    for i,s in ipairs(v) do if type(s)~="string" or #s<1 or #s>128 or seen[s] or known and not known[s] then fail(path.."["..i.."]","unknown or duplicate identifier "..tostring(s)) end;seen[s]=true end
end
S.target_fields=keys("kind tags breeds archetypes exclude_tags")
S.condition_fields={
    health="number",toughness="number",corruption="number",coherency="number",ammo="number",stamina="number",
    warp_charge="number",overheat="number",progress="number",load="number",players="number",monsters="number",
    elapsed="number",stage="string",phase="string",breed="string",archetype="string",attack_type="string",
    critical="boolean",weakspot="boolean",sprinting="boolean",dodging="boolean",sliding="boolean",
    in_combat="boolean",knocked_down="boolean",native_condition="set",affix="set",signal="set",tag="set",
}
function S.localize(value,lang)
    if type(value)~="table" then return tostring(value or "") end
    return value[lang] or value.en or value["zh-cn"] or value["zh-tw"] or ""
end
local function selector(v,path,catalog)
    object(v,S.target_fields,path)
    if v.kind~="players" and v.kind~="minions" and v.kind~="all" then fail(path..".kind","players, minions or all") end
    if v.tags then strings(v.tags,16,path..".tags",catalog.tags) end
    if v.exclude_tags then strings(v.exclude_tags,16,path..".exclude_tags",catalog.tags) end
    if v.breeds then strings(v.breeds,64,path..".breeds",catalog.breeds) end
    if v.archetypes then strings(v.archetypes,16,path..".archetypes",catalog.archetypes) end
end
S.modifiers={ammo_pickup_multiplier={0,10},ammo_pickup_failure_chance={0,1},ranged_salvo_count={1,5}}
local function effect(v,path,catalog,kind)
    object(v,keys("stats keywords modifiers"),path)
    if v.modifiers then
        object(v.modifiers,S.modifiers,path..".modifiers")
        for key,value in pairs(v.modifiers) do
            local range=S.modifiers[key];number(value,range[1],range[2],path..".modifiers."..key,key=="ranged_salvo_count")
            if key=="ranged_salvo_count" and kind and kind~="mortis" then fail(path..".modifiers."..key,"Mortis-only capability") end
        end
    end
    if v.stats then
        if type(v.stats)~="table" or getmetatable(v.stats) then fail(path..".stats","object required") end
        local count=0
        for k,value in pairs(v.stats) do
            count=count+1;if count>64 then fail(path..".stats","max 64") end
            local kind=catalog.stats[k];if not kind then fail(path..".stats."..tostring(k),"unknown native stat") end
            number(value,(kind=="multiplicative_multiplier" or kind=="max_value") and 0 or -1000,1000,path..".stats."..k)
            if kind=="additive_multiplier" and value< -1 then fail(path..".stats."..k,"additive delta must be at least -1") end
        end
    end
    if v.keywords then strings(v.keywords,32,path..".keywords",catalog.keywords) end
    if not v.stats and not v.keywords and not v.modifiers then fail(path,"empty effect") end
end
local function conditions(v,path,catalog)
    array(v,12,path)
    for i,c in ipairs(v) do
        local p=path.."["..i.."]";object(c,keys("subject field op value"),p)
        if c.subject~=nil and c.subject~="self" and c.subject~="target" and c.subject~="attacker" then fail(p..".subject","unknown subject") end
        local kind=S.condition_fields[c.field]
        if not kind and type(c.field)=="string" and c.field:sub(1,6)=="event." then kind=catalog.event_fields[c.field:sub(7)] end
        if not kind then fail(p..".field","unsupported condition field") end
        if kind=="number" then
            if not keys("eq ne gt ge lt le")[c.op] then fail(p..".op","numeric comparator required") end
            number(c.value,-10000000,10000000,p..".value")
        elseif kind=="set" then
            if c.op~="contains" and c.op~="not_contains" then fail(p..".op","contains or not_contains required") end
            if type(c.value)~="string" or #c.value<1 or #c.value>128 then fail(p..".value","identifier required") end
        else
            if c.op~="eq" and c.op~="ne" then fail(p..".op","eq or ne required") end
            if type(c.value)~=kind then fail(p..".value",kind.." required") end
            if kind=="string" and #c.value>128 then fail(p..".value","text too long") end
        end
    end
end
S.action_types=keys("effect heal corruption toughness ammo grenades ability_cooldown stamina warp_charge overheat damage kill native_buff signal pause_spawns spawn_formation spawn_enemy pickup sound notification")
local targets=keys("self target attacker players nearby_players minions nearby_minions matching")
local function action(a,path,catalog,kind)
    object(a,keys("type target radius duration effects max_stacks refresh amount amount_kind name breed count family text"),path)
    if not S.action_types[a.type] then fail(path..".type","unknown action") end
    if a.target and not targets[a.target] then fail(path..".target","unknown target") end
    if a.radius~=nil then number(a.radius,1,50,path..".radius") end
    local allowed={type=true,target=true,radius=true}
    local function allow(s) for k in pairs(keys(s)) do allowed[k]=true end end
    if a.type=="effect" then
        allow("duration effects max_stacks refresh");number(a.duration,.1,600,path..".duration");effect(a.effects,path..".effects",catalog,kind)
        if a.max_stacks then number(a.max_stacks,1,500,path..".max_stacks",true) end
        if a.refresh~=nil and type(a.refresh)~="boolean" then fail(path..".refresh","boolean required") end
    elseif a.type=="signal" or a.type=="pause_spawns" then
        allow("name duration");number(a.duration,.1,600,path..".duration")
        if a.type=="signal" then id(a.name,path..".name")
        elseif not keys("all hordes trickle_hordes roamers specials monsters hed")[a.name] then fail(path..".name","unknown spawn family") end
    elseif a.type=="spawn_formation" then allow("name");id(a.name,path..".name")
    elseif a.type=="spawn_enemy" then
        allow("breed count");if not catalog.spawn_breeds[a.breed] then fail(path..".breed","unsupported free-spawn breed") end
        number(a.count or 1,1,catalog.spawn_breeds[a.breed]=="monsters" and 1 or 16,path..".count",true)
    elseif a.type=="native_buff" then
        allow("name duration count");if not catalog.native_buffs[a.name] then fail(path..".name","native status is not in the supported catalog") end
        number(a.duration or 10,.1,120,path..".duration");number(a.count or 1,1,10,path..".count",true)
    elseif a.type=="pickup" then
        allow("name count");if not catalog.pickups[a.name] then fail(path..".name","unsupported pickup") end
        number(a.count or 1,1,4,path..".count",true)
    elseif a.type=="sound" then allow("name");if not catalog.sounds[a.name] then fail(path..".name","use a native UI sound identifier") end
    elseif a.type=="notification" then allow("text");text(a.text,path..".text",512)
    elseif a.type=="kill" then
        if a.target~="target" and a.target~="minions" and a.target~="nearby_minions" and a.target~="matching" then fail(path..".target","kill is restricted to minions") end
    else
        allow("amount amount_kind")
        local signed=keys("ammo grenades stamina warp_charge overheat toughness")[a.type]
        number(a.amount,signed and -100000 or 0,100000,path..".amount")
        if a.amount_kind and not keys("flat fraction current_fraction event_damage")[a.amount_kind] then fail(path..".amount_kind","flat, fraction, current_fraction or event_damage") end
        if a.amount_kind=="current_fraction" and a.type~="ammo" then fail(path..".amount_kind","current_fraction requires ammo") end
        if a.amount_kind=="fraction" or a.amount_kind=="current_fraction" then number(a.amount,signed and -1 or 0,1,path..".amount") end
        if a.amount_kind=="event_damage" and a.type~="damage" and a.type~="heal" and a.type~="toughness" then fail(path..".amount_kind","event_damage requires damage, heal or toughness") end
        if a.amount_kind=="event_damage" then number(a.amount,0,5,path..".amount") end
    end
    for k in pairs(a) do if not allowed[k] then fail(path.."."..k,"field does not apply to "..a.type) end end
end
function S.validate(raw,catalog,kind)
    local function validate()
        object(raw,keys("format version kind id name description entries"),"$")
        if raw.format~=S.format or raw.version~=S.version then fail("$","unsupported DIY format/version") end
        if raw.kind~="mortis" and raw.kind~="conditions" or kind and raw.kind~=kind then fail("$.kind","wrong library kind") end
        id(raw.id,"$.id");text(raw.name,"$.name",256);text(raw.description,"$.description",4096,true)
        array(raw.entries,S.max_entries,"$.entries")
        local seen={}
        for i,e in ipairs(raw.entries) do
            local p="$.entries["..i.."]"
            object(e,keys("id name description enabled tier weight exclusive_group targets availability passive conditions match rules spawn source_row script"),p)
            id(e.id,p..".id");if seen[e.id] then fail(p..".id","duplicate") end;seen[e.id]=true
            text(e.name,p..".name",256);text(e.description,p..".description",4096)
            if e.enabled~=nil and type(e.enabled)~="boolean" then fail(p..".enabled","boolean required") end
            if e.script~=nil and type(e.script)~="boolean" then fail(p..".script","boolean required") end
            if e.tier~=nil then number(e.tier,1,4,p..".tier",true) end
            if e.weight~=nil then number(e.weight,0,1000,p..".weight") end
            if e.exclusive_group then id(e.exclusive_group,p..".exclusive_group") end
            if e.source_row then number(e.source_row,1,10000,p..".source_row",true) end
            selector(e.targets or {kind="players"},p..".targets",catalog)
            if raw.kind=="mortis" and e.targets and e.targets.kind~="players" then fail(p..".targets","Mortis talents belong to players") end
            if e.availability then
                if raw.kind~="mortis" then fail(p..".availability","Mortis-only capability; use targets/conditions for HCM") end
                object(e.availability,keys("archetypes families talents weapons weapon_keywords grenade_abilities combat_abilities resources any_resources"),p..".availability")
                if e.availability.archetypes then strings(e.availability.archetypes,16,p..".availability.archetypes",catalog.archetypes) end
                if e.availability.families then strings(e.availability.families,16,p..".availability.families",catalog.families) end
                if e.availability.talents then strings(e.availability.talents,16,p..".availability.talents") end
                for _,key in ipairs({"weapons","weapon_keywords","grenade_abilities","combat_abilities"}) do
                    if e.availability[key] then strings(e.availability[key],32,p..".availability."..key,catalog[key]) end
                end
                local resources=keys("ammo reload overheat warp_charge grenade_charges combat_ability melee ranged")
                for _,key in ipairs({"resources","any_resources"}) do
                    if e.availability[key] then strings(e.availability[key],8,p..".availability."..key,resources) end
                end
            end
            if e.passive then effect(e.passive,p..".passive",catalog,raw.kind) end
            if e.conditions then conditions(e.conditions,p..".conditions",catalog) end
            if e.match~=nil and e.match~="all" and e.match~="any" then fail(p..".match","all or any") end
            if e.spawn then
                if raw.kind~="conditions" then fail(p..".spawn","HCM-only capability") end
                object(e.spawn,keys("health_multiplier"),p..".spawn")
                number(e.spawn.health_multiplier,.05,100,p..".spawn.health_multiplier")
                if e.conditions and #e.conditions>0 then fail(p..".spawn","spawn health supports static targets only") end
            end
            if e.rules then
                array(e.rules,S.max_rules,p..".rules");local ids={}
                for j,r in ipairs(e.rules) do
                    local q=p..".rules["..j.."]";object(r,keys("id event scope interval chance cooldown max_triggers delay conditions match actions"),q)
                    if r.scope~=nil and r.scope~="unit" and r.scope~="global" then fail(q..".scope","unit or global") end
                    if raw.kind=="mortis" and r.scope=="global" then fail(q..".scope","Mortis triggers belong to the selected player") end
                    id(r.id,q..".id");if ids[r.id] then fail(q..".id","duplicate") end;ids[r.id]=true
                    if not catalog.events[r.event] and not keys("interval spawn enemy_died mission_start signal")[r.event] then fail(q..".event","unknown event") end
                    if r.event=="interval" then number(r.interval,.1,600,q..".interval")
                    elseif r.interval~=nil then fail(q..".interval","interval-only field") end
                    if r.chance~=nil then number(r.chance,0,1,q..".chance") end
                    if r.cooldown~=nil then number(r.cooldown,0,600,q..".cooldown") end
                    if r.max_triggers~=nil then number(r.max_triggers,0,10000,q..".max_triggers",true) end
                    if r.delay~=nil then number(r.delay,0,120,q..".delay") end
                    if r.conditions then conditions(r.conditions,q..".conditions",catalog) end
                    if r.match~=nil and r.match~="all" and r.match~="any" then fail(q..".match","all or any") end
                    array(r.actions,S.max_actions,q..".actions");if #r.actions==0 then fail(q..".actions","at least one action") end
                    for k,a in ipairs(r.actions) do action(a,q..".actions["..k.."]",catalog,raw.kind) end
                end
            end
            if not e.passive and not e.spawn and (not e.rules or #e.rules==0) and not e.script then fail(p,"entry needs an effect or script=true") end
        end
        local doc=S.copy(raw)
        for _,e in ipairs(doc.entries) do
            e.targets=e.targets or {kind="players"};e.tier=e.tier or 1;e.weight=e.weight or 1
            e.enabled=e.enabled~=false;e.rules=e.rules or {};e.conditions=e.conditions or {};e.match=e.match or "all"
            for _,r in ipairs(e.rules) do
                r.chance=r.chance or 1;r.cooldown=r.cooldown or 0;r.max_triggers=r.max_triggers or 0;r.delay=r.delay or 0
                r.conditions=r.conditions or {};r.match=r.match or "all"
            end
        end
        return doc
    end
    local ok,result=pcall(validate);if not ok then return nil,result end;return result
end
function S.validate_effect(v,catalog,kind) local ok,err=pcall(effect,v,"effect",catalog,kind);return ok,err end
function S.validate_action(v,catalog,kind) local ok,err=pcall(action,v,"action",catalog,kind);return ok,err end
function S.validate_selector(v,catalog) local ok,err=pcall(selector,v,"selector",catalog);return ok,err end
return S
