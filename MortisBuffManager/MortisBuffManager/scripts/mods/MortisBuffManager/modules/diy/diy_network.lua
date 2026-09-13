-- Bounded Realms protocol: clients submit IDs, hosts submit aggregate effects.
-- No JSON program, action, unit handle or executable data crosses this boundary.
local N={}
function N.realms()
    local r=get_mod("Realms");return r and r:is_enabled() and r or nil
end
function N.context()
    local r=N.realms();local s=r and r._session;local m=Managers.connection
    local token=Managers.state and Managers.state.game_session or m and (m._connection_host or m._connection_client)
    if s and m then
        if s.is_active_host() and m:is_host() then return token,"host" end
        if s.is_active_client() and m:is_client() then return token,"client",m:host() end
    end
    return token,"local"
end
function N.local_player() return Managers.player and Managers.player:local_player_safe(1) end
function N.players() return Managers.player and Managers.player:human_players() or {} end
local function peer(value) return value and tostring(value):lower() end
local function finite(n) return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
function N.valid_effect(value,catalog)
    if type(value)~="table" or type(value.stats)~="table" or type(value.keywords)~="table" then return false end
    for k in pairs(value) do if k~="stats" and k~="keywords" and k~="modifiers" then return false end end
    if value.modifiers~=nil then
        if type(value.modifiers)~="table" then return false end
        for k,v in pairs(value.modifiers) do
            if k=="ranged_salvo_count" then
                if not finite(v) or v%1~=0 or v<1 or v>5 then return false end
            elseif (k~="ammo_pickup_multiplier" and k~="ammo_pickup_failure_chance") or not finite(v) or v<0 or v>(k=="ammo_pickup_failure_chance" and 1 or 1000) then return false end
        end
    end
    local n=0
    for k,v in pairs(value.stats) do
        n=n+1;local kind=catalog.stats[k]
        if n>512 or not kind or not finite(v) or v>1000 or v< -1000 or
            ((kind=="multiplicative_multiplier" or kind=="max_value") and v<0) or kind=="additive_multiplier" and v< -1 then return false end
    end
    n=0;local seen={}
    for i,k in pairs(value.keywords) do
        n=n+1
        if n>256 or type(i)~="number" or i%1~=0 or i<1 or i>#value.keywords or not catalog.keywords[k] or seen[k] then return false end
        seen[k]=true
    end
    return n==#value.keywords
end
function N.new(mod,catalog,api)
    local self={now=0,elapsed=0,serial=0,peers={},status="offline",sequence=0}
    local rpc="darktide_diy_v1"
    local function next_sequence()
        local persistent=mod:persistent_table("diy_network_v1")
        persistent.sequence=(persistent.sequence or 0)+1
        self.sequence=persistent.sequence
        return self.sequence
    end
    local function local_player() return api.local_player() end
    local function find(id)
        for _,p in pairs(api.players() or {}) do if peer(p:peer_id())==id and p:local_player_id()==1 then return p end end
    end
    local function send(id,packet)
        local realms=api.realms()
        if mod:is_enabled() and realms and realms.network_is_available and realms.network_is_available() then
            packet.protocol=1;return realms.network_send(mod,rpc,id,packet)
        end
    end
    function self.reset()
        self.peers={};self.effect=nil;self.status="offline";self.last_seen=nil;self.sequence=0;self.last_sequence=0
        self.serial=self.serial+1
        local persistent=mod:persistent_table("diy_network_v1");persistent.serial=(persistent.serial or 0)+1
        self.nonce=tostring(persistent.serial)..":"..self.serial;self.elapsed=1
        if api.clear then api.clear() end
    end
    local function context()
        local token,role,host=api.context();host=peer(host)
        local p=local_player();local character=p and p:character_id()
        if self.token~=token or self.role~=role or self.host~=host or self.character~=character then
            self.token,self.role,self.host,self.character=token,role,host,character;self.reset()
        end
    end
    local function snapshot(id,p,record)
        next_sequence()
        local effect,status=api.snapshot(p,record.accepted)
        send(id,{kind="state",nonce=record.nonce,character=p:character_id(),sequence=self.sequence,
            effects=effect or {stats={},keywords={}},status=status or record.status or "ready"})
    end
    function self.receive(id,packet)
        if not mod:is_enabled() or type(packet)~="table" or packet.protocol~=1 then return end
        context();id=peer(id)
        if self.role=="host" then
            local p=find(id)
            if not p or packet.kind~="hello" or packet.character~=p:character_id() or type(packet.nonce)~="string" or #packet.nonce>100 then return end
            local record=self.peers[id]
            if record and self.now-record.last_seen<.2 then return end
            local accepted,status=api.accept(p,packet.request)
            record={nonce=packet.nonce,character=packet.character,last_seen=self.now,accepted=accepted,status=status}
            self.peers[id]=record;snapshot(id,p,record)
        elseif self.role=="client" and id==self.host and packet.kind=="state" and packet.nonce==self.nonce and
            packet.character==self.character and finite(packet.sequence) and packet.sequence%1==0 and packet.sequence>self.last_sequence and
            type(packet.status)=="string" and #packet.status<=64 and N.valid_effect(packet.effects,catalog) then
            self.last_sequence=packet.sequence;self.effect=packet.effects;self.last_seen=self.now;self.status=packet.status
        end
    end
    function self.effects(unit)
        context()
        local p=local_player()
        if self.role=="client" and p and p.player_unit==unit and self.last_seen and self.now-self.last_seen<=3 then return self.effect end
    end
    function self.eligible(p)
        local r=self.peers[peer(p:peer_id())]
        return r and r.character==p:character_id() and r.accepted and self.now-r.last_seen<=3 or false
    end
    function self.update(dt)
        self.now=self.now+math.max(0,dt);context()
        if self.last_seen and self.now-self.last_seen>3 then self.effect=nil;self.status="disconnected" end
        self.elapsed=self.elapsed+dt;if self.elapsed<.5 then return end;self.elapsed=0
        local realms=api.realms()
        if not realms or not realms.network_register then return end
        if self.registered~=realms then
            if realms.network_register(mod,rpc,self.receive) then self.registered=realms end
        end
        if self.role=="client" and self.host and self.character then
            send(self.host,{kind="hello",nonce=self.nonce,character=self.character,request=api.request()})
        elseif self.role=="host" then
            for id,record in pairs(self.peers) do
                local p=find(id)
                if not p or p:character_id()~=record.character or self.now-record.last_seen>3 then self.peers[id]=nil
                else snapshot(id,p,record) end
            end
        end
    end
    function self.finish()
        if self.role=="host" then for id,r in pairs(self.peers) do
            next_sequence()
            send(id,{kind="state",nonce=r.nonce,character=r.character,sequence=self.sequence,effects={stats={},keywords={}},status="disabled"})
        end end
        self.reset();self.token=nil
    end
    return self
end
return N
