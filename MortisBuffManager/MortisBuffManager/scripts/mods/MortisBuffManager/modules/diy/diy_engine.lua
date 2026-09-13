-- Pure bounded encounter/effect runtime. Every random stream belongs to one rule and owner.
local E={api_version=1}
local function weak() return setmetatable({},{__mode="k"}) end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function hash(seed,text)
    local value=math.floor(tonumber(seed) or 1)%2147483647
    for i=1,#text do value=(value*131+text:byte(i))%2147483647 end
    return math.max(1,value)
end
local function random(state)
    local hi=math.floor(state.seed/127773)
    local value=16807*(state.seed-hi*127773)-2836*hi
    state.seed=value>0 and value or value+2147483647
    return (state.seed-1)/2147483646
end
local function contains(values,value)
    if not values or #values==0 then return true end
    for _,v in ipairs(values) do if v==value then return true end end
    return false
end
local function lookup(values) local out={};for _,v in ipairs(values or {}) do out[v]=true end;return out end
function E.matches(selector,info)
    if not info then return false end
    if selector.kind~="all" and selector.kind~=info.kind then return false end
    if not contains(selector.breeds,info.breed) or not contains(selector.archetypes,info.archetype) then return false end
    for _,tag in ipairs(selector.tags or {}) do if not info.tags or not info.tags[tag] then return false end end
    for _,tag in ipairs(selector.exclude_tags or {}) do if info.tags and info.tags[tag] then return false end end
    return true
end
local comparators={
    eq=function(a,b) return a==b end,ne=function(a,b) return a~=b end,
    gt=function(a,b) return type(a)=="number" and a>b end,ge=function(a,b) return type(a)=="number" and a>=b end,
    lt=function(a,b) return type(a)=="number" and a<b end,le=function(a,b) return type(a)=="number" and a<=b end,
    contains=function(a,b) return type(a)=="table" and a[b]==true end,
    not_contains=function(a,b) return type(a)=="table" and a[b]~=true end,
}
function E.test(conditions,match,provider,event)
    if not conditions or #conditions==0 then return true end
    local all=match~="any";local cached={}
    for _,c in ipairs(conditions) do
        local value
        if c.field:sub(1,6)=="event." then value=event and event[c.field:sub(7)]
        else
            local subject=c.subject or "self"
            cached[subject]=cached[subject] or provider(subject) or {}
            value=cached[subject][c.field]
        end
        local compare=comparators[c.op]
        local passed=value~=nil and compare and compare(value,c.value) or false
        if all and not passed then return false elseif not all and passed then return true end
    end
    return all
end
function E.new(document,catalog,api,seed)
    local self={document=document,seed=seed or 1,now=0,revision=0,globals={},owners=weak(),layers=weak(),global_layers={},
        queue={},signals={},pauses={},metrics={triggered=0,executed=0,rejected=0,dropped=0},entry_by_id={},global_token={},
        script_globals={},script_owners=weak(),script_minions={}}
    local ordered={};local generation=0;local event_budget,action_budget=128,64
    for _,e in ipairs(document.entries) do self.entry_by_id[e.id]=e;ordered[#ordered+1]=e end
    table.sort(ordered,function(a,b) return a.id<b.id end)
    local global_bindings={};local owner_bindings=weak()
    local rolls={}
    function self.roll(key,unit,chance)
        local id=key.."/"..api.key(unit)
        local state=rolls[id]
        if not state then state={seed=hash(self.seed,document.id.."/"..id)};rolls[id]=state end
        return random(state)<chance
    end
    local selection_revision=0;local minion_revision=-1;local minion_needed=false
    local function bump() self.revision=self.revision+1 end
    local function state_for(binding,unit)
        local key=unit or self.global_token
        local state=binding.states[key]
        if not state then
            state={seed=hash(self.seed,document.id.."/"..binding.entry.id.."/"..binding.rule.id.."/"..(unit and api.key(unit) or "global")),count=0,next_at=0}
            binding.states[key]=state
        end
        return state
    end
    local function binds(e,owner)
        local out={}
        for _,rule in ipairs(e.rules) do
            out[#out+1]={entry=e,rule=rule,owner=owner,states=weak(),next_tick=self.now+(rule.interval or 0),generation=generation,active=true}
        end
        table.sort(out,function(a,b) return a.rule.id<b.rule.id end)
        return out
    end
    local function valid_binding(b)
        if not b.active then return false end
        if b.owner then return owner_bindings[b.owner] and self.owners[b.owner] and self.owners[b.owner][b.entry.id]
        else return self.globals[b.entry.id] end
    end
    function self.set_script_effects(id,owner,effects)
        if self.finished or not self.entry_by_id[id] then return false end
        local selected=owner and self.owners[owner] and self.owners[owner][id] or not owner and self.globals[id]
        if effects and not selected then return false end
        local group=self.script_globals
        if owner then
            group=self.script_owners[owner]
            if not group and not effects then return true end
            if not group then group={};self.script_owners[owner]=group end
        end
        group[id]=effects;bump();return true
    end
    function self.script_action(id,owner,unit,action,event,slot)
        if self.finished or not self.entry_by_id[id] or #self.queue>=512 then return false end
        local b={entry=self.entry_by_id[id],rule={id="script/"..slot},owner=owner,active=true,script=true}
        if not valid_binding(b) then return false end
        if action.type=="effect" and action.target~="self" and action.target~="players" and action.target~="nearby_players" then
            self.script_minions[id]=true;minion_revision=-1
        end
        self.queue[#self.queue+1]={binding=b,unit=unit,event=event or {},action=action,index=1,at=self.now}
        return true
    end
    function self.clear_script(id,owner)
        self.set_script_effects(id,owner,nil)
        local function owned(binding) return binding.script and binding.entry.id==id and binding.owner==owner end
        local queue={};for _,item in ipairs(self.queue)do if not owned(item.binding) then queue[#queue+1]=item end end;self.queue=queue
        for _,group in pairs(self.layers)do for key,layer in pairs(group)do if owned(layer.binding) then group[key]=nil end end end
        for key,layer in pairs(self.global_layers)do if owned(layer.binding) then self.global_layers[key]=nil end end
        if api.owner_changed then api.owner_changed(owner,{["script:"..id]=true}) end
        bump()
    end
    function self.set_global(ids)
        if self.finished then return end
        selection_revision=selection_revision+1
        generation=generation+1;self.globals={};global_bindings={};self.global_layers={};self.queue={}
        for _,id in ipairs(ids or {}) do local e=self.entry_by_id[id];if e and e.enabled then self.globals[id]=true end end
        for _,e in ipairs(ordered) do if self.globals[e.id] then for _,b in ipairs(binds(e)) do global_bindings[#global_bindings+1]=b end end end
        bump()
    end
    function self.set_owner(unit,ids)
        if self.finished then return end
        local next_ids=lookup(ids)
        for id in pairs(next_ids) do local e=self.entry_by_id[id];if not e or not e.enabled then next_ids[id]=nil end end
        local current=self.owners[unit] or {};local same=true
        for id in pairs(current) do if not next_ids[id] then same=false end end
        for id in pairs(next_ids) do if not current[id] then same=false end end
        if same then return end
        selection_revision=selection_revision+1
        local old=owner_bindings[unit] or {};local preserved={}
        local removed={}
        for id in pairs(current) do if not next_ids[id] then removed[id]=true end end
        for _,b in ipairs(old) do if next_ids[b.entry.id] then preserved[b.entry.id.."/"..b.rule.id]=b else b.active=false end end
        self.owners[unit]=next(next_ids) and next_ids or nil;owner_bindings[unit]={}
        for _,e in ipairs(ordered) do if next_ids[e.id] then
            for _,b in ipairs(binds(e,unit)) do owner_bindings[unit][#owner_bindings[unit]+1]=preserved[e.id.."/"..b.rule.id] or b end
        end end
        for _,group in pairs(self.layers) do for key,layer in pairs(group) do
            if layer.binding.owner==unit and not next_ids[layer.binding.entry.id] then group[key]=nil end
        end end
        for key,layer in pairs(self.global_layers) do if layer.binding.owner==unit and not next_ids[layer.binding.entry.id] then self.global_layers[key]=nil end end
        if api.owner_changed and next(removed) then api.owner_changed(unit,removed) end
        bump()
    end
    function self.active_ids()
        local out={};for _,e in ipairs(ordered) do if self.globals[e.id] then out[#out+1]=e.id end end;return out
    end
    function self.needs_minion_updates()
        if self.finished then return false end
        if minion_revision==selection_revision then return minion_needed end
        minion_revision=selection_revision;minion_needed=false
        local function requires(e,global)
            if e.script and self.script_minions[e.id] then return true end
            if global and e.targets.kind~="players" and (e.passive or #e.rules>0 or e.script) then return true end
            for _,r in ipairs(e.rules) do for _,a in ipairs(r.actions) do if a.type=="effect" then
                local target=a.target or "self"
                if target=="target" or target=="attacker" or target=="minions" or target=="nearby_minions" or
                    (target=="matching" or target=="self") and e.targets.kind~="players" then return true end
            end end end
            return false
        end
        for _,e in ipairs(ordered) do
            if self.globals[e.id] and requires(e,true) then minion_needed=true;break end
            for _,ids in pairs(self.owners) do if ids[e.id] and requires(e,false) then minion_needed=true;break end end
            if minion_needed then break end
        end
        return minion_needed
    end
    function self.context(unit,event)
        local c=api.context(unit,event) or {}
        c.elapsed=self.now;c.affix=c.affix or {}
        for id in pairs(self.globals) do c.affix[id]=true end
        c.signal=c.signal or {}
        for name,until_time in pairs(self.signals) do if until_time>self.now then c.signal[name]=true end end
        return c
    end
    local function allowed(b,unit,event)
        if not valid_binding(b) then return false end
        if api.available and not api.available(b.entry,b.owner or unit) then return false end
        local function provider(subject)
            local target=unit
            if subject=="target" then target=event and event.target
            elseif subject=="attacker" then target=event and event.attacker end
            return self.context(target,event)
        end
        return E.test(b.entry.conditions,b.entry.match,provider,event) and E.test(b.rule.conditions,b.rule.match,provider,event)
    end
    local function trigger(b,unit,event)
        if event_budget<=0 then self.metrics.dropped=self.metrics.dropped+1;return end
        event_budget=event_budget-1
        if not allowed(b,unit,event) then return end
        local r=b.rule;local state_unit=unit
        if r.scope=="global" then state_unit=nil end
        local state=state_for(b,state_unit)
        if self.now<state.next_at or r.max_triggers>0 and state.count>=r.max_triggers then return end
        if #self.queue+#r.actions>512 then self.metrics.dropped=self.metrics.dropped+1;return end
        if r.chance==0 or r.chance<1 and random(state)>=r.chance then return end
        state.count=state.count+1;state.next_at=self.now+math.max(.05,r.cooldown)
        self.metrics.triggered=self.metrics.triggered+1
        for i,a in ipairs(r.actions) do
            self.queue[#self.queue+1]={binding=b,unit=unit,event=event or {},action=a,index=i,at=self.now+r.delay}
        end
    end
    function self.dispatch(name,unit,params)
        if self.finished or self.in_action then return end
        local event={}
        for k,v in pairs(params or {}) do if type(v)~="table" or k=="target" or k=="attacker" or k=="attacked_unit" or k=="victim_unit" or k=="target_unit" or k=="attacking_unit" then event[k]=v end end
        event.unit=unit;event.name=name
        event.target=event.target or event.attacked_unit or event.victim_unit or event.target_unit
        event.attacker=event.attacker or event.attacking_unit or unit
        local info=unit and api.info(unit)
        for _,b in ipairs(global_bindings) do if b.rule.event==name and
            (not unit and b.rule.scope=="global" or E.matches(b.entry.targets,info)) then trigger(b,unit,event) end end
        if name=="enemy_died" or name=="signal" then
            local units={};for owner in pairs(owner_bindings) do units[#units+1]=owner end
            table.sort(units,function(a,b) return api.key(a)<api.key(b) end)
            for _,owner in ipairs(units) do if api.alive(owner) then
                for _,b in ipairs(owner_bindings[owner]) do if b.rule.event==name then trigger(b,owner,event) end end
            end end
        else
            for _,b in ipairs(owner_bindings[unit] or {}) do if b.rule.event==name then trigger(b,unit,event) end end
        end
    end
    local function targets(item)
        local a,b,event=item.action,item.binding,item.event;local kind=a.target or "self"
        if kind=="self" then return item.unit and {item.unit} or {}
        elseif kind=="target" then return event.target and {event.target} or {}
        elseif kind=="attacker" then return event.attacker and {event.attacker} or {} end
        local select=kind=="matching" and b.entry.targets or {kind=(kind=="players" or kind=="nearby_players") and "players" or "minions"}
        local nearby=kind=="nearby_players" or kind=="nearby_minions"
        return api.units(select,nearby and item.unit or nil,nearby and (a.radius or 8) or nil,kind:find("player",1,true) and 4 or 64)
    end
    local function add_layer(item,unit,selector)
        local group
        if selector then group=self.global_layers
        else self.layers[unit]=self.layers[unit] or {};group=self.layers[unit] end
        local b,a=item.binding,item.action
        local key=b.entry.id.."/"..b.rule.id.."/"..item.index.."/"..(b.owner and api.key(b.owner) or "global")
        local layer=group[key]
        if layer and layer.expires<=self.now then layer=nil end
        if not layer then
            local n=0;for _ in pairs(group) do n=n+1 end
            if n>=128 then self.metrics.dropped=self.metrics.dropped+1;return false end
            layer={binding=b,effects=a.effects,stacks=0,expires=self.now+a.duration,selector=selector};group[key]=layer
        end
        layer.stacks=math.min(a.max_stacks or 1,layer.stacks+1)
        if a.refresh~=false then layer.expires=self.now+a.duration end
        bump();return true
    end
    local function execute(item)
        if not valid_binding(item.binding) then return false end
        local a,b=item.action,item.binding
        local meta={entry=b.script and "script:"..b.entry.id or b.entry.id,rule=b.rule.id,seed=self.seed,now=self.now,owner=b.owner}
        if b.owner and not api.alive(b.owner) then return false end
        if a.type=="signal" then
            self.emit_signal(a.name,a.duration)
            if api.signal then api.signal(a.name,a.duration,b.entry.id) end;return true
        elseif a.type=="pause_spawns" then
            self.pauses[a.name]=math.max(self.pauses[a.name] or 0,self.now+a.duration)
            if api.pause then api.pause(a.name,a.duration,b.entry.id) end;return true
        elseif a.type=="spawn_formation" or a.type=="spawn_enemy" then
            return api.action(a,nil,item.event,meta)~=false
        end
        if a.type=="effect" and (a.target=="matching" or a.target=="players" or a.target=="minions") then
            local select=a.target=="matching" and b.entry.targets or {kind=a.target}
            return add_layer(item,nil,select)
        end
        if a.type=="sound" or a.type=="notification" then return api.action(a,item.unit,item.event,meta)~=false end
        local done=false
        for _,unit in ipairs(targets(item)) do if api.alive(unit) then
            if a.type=="effect" then done=add_layer(item,unit) or done
            else done=api.action(a,unit,item.event,meta)~=false or done end
        end end
        return done
    end
    function self.tick(dt)
        if self.finished then return end
        self.now=self.now+clamp(tonumber(dt) or 0,0,60);event_budget=128;action_budget=64
        local signals=self.pending_signals or {};self.pending_signals={}
        for _,name in ipairs(signals) do self.dispatch("signal",nil,{signal_name=name}) end
        for _,b in ipairs(global_bindings) do if b.rule.event=="interval" and self.now>=b.next_tick then
            b.next_tick=self.now+b.rule.interval
            if b.rule.scope=="global" then trigger(b,nil,{name="interval"})
            else for _,unit in ipairs(api.units(b.entry.targets,nil,nil,512)) do if api.alive(unit) then trigger(b,unit,{name="interval",unit=unit}) end end end
        end end
        local owners={};for owner in pairs(owner_bindings) do owners[#owners+1]=owner end
        table.sort(owners,function(a,b) return api.key(a)<api.key(b) end)
        for _,owner in ipairs(owners) do local bindings=owner_bindings[owner];if api.alive(owner) then
            for _,b in ipairs(bindings) do if b.rule.event=="interval" and self.now>=b.next_tick then
                b.next_tick=self.now+b.rule.interval;trigger(b,owner,{name="interval",unit=owner})
            end end
        end end
        local queue=self.queue;self.queue={}
        for _,item in ipairs(queue) do
            if item.at<=self.now and action_budget>0 then
                action_budget=action_budget-1;self.in_action=true
                local ok,result=pcall(execute,item);self.in_action=false
                if ok and result then self.metrics.executed=self.metrics.executed+1
                else self.metrics.rejected=self.metrics.rejected+1;if api.error then api.error(ok and "action unavailable" or result,item.binding.entry.id,item.action.type) end end
            elseif #self.queue<512 then self.queue[#self.queue+1]=item
            else self.metrics.dropped=self.metrics.dropped+1 end
        end
        local changed=false
        for _,group in pairs(self.layers) do for k,l in pairs(group) do if l.expires<=self.now or not valid_binding(l.binding) then group[k]=nil;changed=true end end end
        for k,l in pairs(self.global_layers) do if l.expires<=self.now or not valid_binding(l.binding) then self.global_layers[k]=nil;changed=true end end
        for name,t in pairs(self.signals) do if t<=self.now then self.signals[name]=nil;changed=true end end
        for name,t in pairs(self.pauses) do if t<=self.now then self.pauses[name]=nil end end
        if changed then bump() end
    end
    function self.paused(kind) return (self.pauses.all or 0)>self.now or (self.pauses[kind] or 0)>self.now end
    function self.emit_signal(name,duration)
        if self.finished or type(name)~="string" or #name>64 or not name:match("^[a-z][a-z0-9_%-]*$") or
            type(duration)~="number" or duration~=duration or duration<.1 or duration>600 then return false end
        self.signals[name]=math.max(self.signals[name] or 0,self.now+duration);bump()
        self.pending_signals=self.pending_signals or {}
        if #self.pending_signals<64 then self.pending_signals[#self.pending_signals+1]=name else self.metrics.dropped=self.metrics.dropped+1 end
        return true
    end
    function self.effects(unit)
        local out={stats={},keywords={},modifiers={}};local keywords={};local info=api.info(unit)
        local function add(effects,count)
            if not effects then return end
            count=count or 1
            for key,value in pairs(effects.stats or {}) do
                local kind=catalog.stats[key]
                if kind=="multiplicative_multiplier" then out.stats[key]=clamp((out.stats[key] or 1)*value^count,0,1000)
                elseif kind=="max_value" then out.stats[key]=math.max(out.stats[key] or 0,value)
                else out.stats[key]=clamp((out.stats[key] or 0)+value*count,kind=="additive_multiplier" and -1 or -1000,1000) end
            end
            for _,key in ipairs(effects.keywords or {}) do keywords[key]=true end
            for key,value in pairs(effects.modifiers or {}) do
                if key=="ranged_salvo_count" then out.modifiers[key]=math.max(out.modifiers[key] or 1,math.min(5,value))
                elseif key=="ammo_pickup_failure_chance" then out.modifiers[key]=1-(1-(out.modifiers[key] or 0))*(1-value)^count
                else out.modifiers[key]=clamp((out.modifiers[key] or 1)*value^count,0,1000) end
            end
        end
        for _,e in ipairs(ordered) do if (self.globals[e.id] or self.owners[unit] and self.owners[unit][e.id]) and E.matches(e.targets,info) then
            if (not api.available or api.available(e,unit)) and E.test(e.conditions,e.match,function(subject) return self.context(subject=="self" and unit or nil) end) then
                add(e.passive)
                if self.globals[e.id] then add(self.script_globals[e.id]) end
                if self.owners[unit] and self.owners[unit][e.id] then add(self.script_owners[unit] and self.script_owners[unit][e.id]) end
            end
        end end
        for _,layer in pairs(self.layers[unit] or {}) do if layer.expires>self.now and valid_binding(layer.binding) then add(layer.effects,layer.stacks) end end
        for _,layer in pairs(self.global_layers) do if layer.expires>self.now and valid_binding(layer.binding) and E.matches(layer.selector,info) then add(layer.effects,layer.stacks) end end
        for key in pairs(keywords) do out.keywords[#out.keywords+1]=key end;table.sort(out.keywords)
        return out
    end
    function self.health_multiplier(info)
        local factor=1
        for _,e in ipairs(ordered) do if self.globals[e.id] and e.spawn and E.matches(e.targets,info) then factor=factor*e.spawn.health_multiplier end end
        return clamp(factor,.05,100)
    end
    function self.finish()
        self.finished=true;self.queue={};self.globals={};self.owners=weak();self.layers=weak();self.global_layers={};self.signals={};self.pauses={}
        self.script_globals={};self.script_owners=weak();self.script_minions={}
        global_bindings={};owner_bindings=weak();if api.finish then api.finish() end;bump()
    end
    return self
end
function E.choose(document,options,seed,eligible)
    local groups={};local result={}
    local limit=options.max_total or 6
    local pool={}
    for _,e in ipairs(document.entries) do if e.enabled and (not eligible or eligible(e)) then pool[#pool+1]=e end end
    table.sort(pool,function(a,b) return a.id<b.id end)
    if document.kind=="conditions" then
        local selected=lookup(options.selected)
        for _,e in ipairs(pool)do if selected[e.id] then result[#result+1]=e.id end end
        return result
    end
    if options.mode~="random" then
        local selected=lookup(options.selected)
        for _,e in ipairs(pool) do if selected[e.id] and #result<limit and (not e.exclusive_group or not groups[e.exclusive_group]) then
            result[#result+1]=e.id;if e.exclusive_group then groups[e.exclusive_group]=true end
        end end
        return result
    end
    local state={seed=hash(seed or 1,document.id.."/selection")}
    while #pool>0 and #result<limit do
        local total=0
        for i=#pool,1,-1 do
            local e=pool[i]
            if e.weight<=0 or e.exclusive_group and groups[e.exclusive_group] then table.remove(pool,i)
            else total=total+e.weight end
        end
        if total<=0 then break end
        local pick=random(state)*total;local index=#pool
        for i,e in ipairs(pool) do pick=pick-e.weight;if pick<0 then index=i;break end end
        local e=table.remove(pool,index);result[#result+1]=e.id
        if e.exclusive_group then groups[e.exclusive_group]=true end
    end
    table.sort(result);return result
end
function E.apply(effects,stats,keywords,catalog)
    for key,value in pairs(effects.stats or {}) do
        local kind=catalog.stats[key];local current=stats[key]
        if current==nil then current=(kind=="additive_multiplier" or kind=="multiplicative_multiplier") and 1 or 0 end
        if kind=="multiplicative_multiplier" then stats[key]=clamp(current*value,0,1000000)
        elseif kind=="max_value" then stats[key]=math.max(current,value)
        else stats[key]=clamp(current+value,kind=="additive_multiplier" and 0 or -1000000,1000000) end
        if stats._modified_stats then stats._modified_stats[key]=true end
    end
    for _,key in ipairs(effects.keywords or {}) do keywords[key]=true end
end
return E
