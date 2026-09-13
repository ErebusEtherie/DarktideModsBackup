local mod=get_mod("MortisBuffManager")
local path="MortisBuffManager/scripts/mods/MortisBuffManager/modules/diy/"
local function load(name) return mod:io_dofile(path..name) end
local Schema,Codec,Catalog,Engine=load("diy_schema"),load("diy_codec"),load("diy_catalog"),load("diy_engine")
local Library,Files,Game,Network=load("diy_library"),load("diy_files"),load("diy_game"),load("diy_network")
local Eligibility=load("diy_eligibility")
local PackageLibrary,Packages,Hash,Scripts=load("diy_package_library"),load("diy_packages"),load("diy_sha256"),load("diy_scripts")
local PackageAPI=Packages.new(Schema,Codec,Hash)
local Assets=load("diy_assets")
local assets
local WeaponTemplate=require("scripts/utilities/weapon/weapon_template")
local M={};mod.diy_mortis=M
local snapshot,owner,engine,api,network,elapsed,bindings,remote
local manifest_document,manifest_value
local notice_elapsed,notice_rules=.5,nil
local setup_cache=setmetatable({},{__mode="k"})
local function busy()
    local mode=mod.session_context().game_mode_name
    return mode and mode~="hub" and mode~="prologue_hub" and mode~="shooting_range" and mode~="prologue" or false
end
local function build(player)
    return Eligibility.capture(player,mod.mortis_diy_family and mod.mortis_diy_family(player),WeaponTemplate.weapon_template_from_item,not busy())
end
mod.mortis_build_setup=build
local function policy_allowed(doc,entry)
    local policy=mod.mortis_host_policy
    if policy then return policy.allowed("diy",doc.id.."/"..entry.id) end
    return true
end
local function choose(snap,player,selected_ids)
    local setup=build(player)
    local options=snap.options
    if selected_ids or mod.mortis_reward_mode then options=Schema.copy(options);options.mode="manual";options.selected=selected_ids or options.selected end
    if mod.session_context().is_realms_client and mod.mortis_rules then
        local rules=mod.mortis_rules();local limits=rules and rules.diy_limits
        if limits then options=Schema.copy(options);options.max_total=limits.max_total end
    end
    return Engine.choose(snap.document,options,options.seed,function(entry) return policy_allowed(snap.document,entry) and Eligibility.matches(entry,setup) end)
end
local library=PackageLibrary.new(mod,"mortis",Catalog,Schema,Codec,Files,Library,Packages,Hash,{name="MortisBuffManager",busy=busy,
    starter=function()return load("diy_examples").mortis end,
    changed=function()
        if mod.mortis_host_policy and mod.mortis_host_policy.migrate_package_keys then mod.mortis_host_policy.migrate_package_keys(mod.diy_library.legacy_policy_keys)end
        if mod.mortis_diy_configuration_changed then mod.mortis_diy_configuration_changed()end
    end,
    selection_limit=function()
        local rules=mod.mortis_rules and mod.mortis_rules()
        return rules and rules.diy_limits and rules.diy_limits.max_total or mod.diy_library.options.max_total
    end,
    eligible=function(entry)
        local allowed,reason=policy_allowed(mod.diy_library.document,entry)
        if not allowed then return false,reason end
        return Eligibility.matches(entry,build(Network.local_player()))
    end})
mod.diy_library=library
assets=Assets.new(mod,Hash,{error=library.runtime_error})
local function authority()
    if not mod:is_enabled() or not (snapshot and snapshot.options or library.options).enabled then return false end
    local c=mod.session_context()
    return (c.is_solo_play or c.is_realms_host) and c.is_server
end
local function finish()
    if engine then engine.finish() elseif api then api.finish() end
    if assets then assets.close_all("manager_end") end
    snapshot=nil;owner=nil;engine=nil;elapsed=0;bindings=setmetatable({},{__mode="k"});remote={};M.local_choices=nil
    setup_cache=setmetatable({},{__mode="k"})
    notice_elapsed=.5;notice_rules=nil
end
local function current()
    local token=Managers.state and Managers.state.game_session
    if not busy() or not token then if owner then finish() end;return end
    if token~=owner then finish();owner=token;snapshot=library.snapshot() end
    return snapshot
end
function M.manifest()
    local snap=current();local doc=snap and snap.document or library.document
    if doc~=manifest_document then
        manifest_document=doc;manifest_value={enabled=true,entries={}}
        local hashes=snap and snap.hashes or library.entry_hashes
        for _,entry in ipairs(doc.entries)do if entry.enabled and hashes[entry.id] then manifest_value.entries[entry.id]=hashes[entry.id] end end
    end
    return manifest_value,doc.id
end
function M.enabled() local snap=current();return (snap and snap.options or library.options).enabled end
local function document() local snap=current();return snap and snap.document or library.document end
local function reward_entry(name)
    if type(name)~="string" or name:sub(1,5)~="diy::" then return nil end
    local id=name:sub(6)
    for _,entry in ipairs(document().entries)do if entry.id==id then return entry end end
end
function M.reward_known(name) return reward_entry(name)~=nil end
function M.reward_ui_data(name)
    local e=reward_entry(name);if not e then return nil end
    return {display_name=Schema.localize(e.name,mod:localize("diy_language")),description=Schema.localize(e.description,mod:localize("diy_language")),
        subtitle="DIY",icon=nil,gradient=nil}
end
local function pool_snapshot()
    local snap=current() or library.snapshot()
    if mod.session_context().is_realms_client and mod.mortis_rules then
        local rules=mod.mortis_rules();local opts=Schema.copy(snap.options)
        opts.enabled=rules and rules.diy_enabled or false
        if rules and rules.diy_limits then opts.max_total=rules.diy_limits.max_total end
        return {document=snap.document,signature=snap.signature,options=opts}
    end
    return snap
end
function M.pool_key(player,selected)
    local snap=pool_snapshot();if not snap.options.enabled then return nil end
    local revision=mod.mortis_host_policy and mod.mortis_host_policy.revision() or 0
    return snap.signature..":"..tostring(revision)..":"..snap.options.max_total..":"..table.concat(selected,",")
end
function M.add_to_pool(pool,player,selected)
    local snap=pool_snapshot();if not snap.options.enabled then return end
    local used,total,groups={},0,{}
    for _,name in ipairs(selected)do local e=reward_entry(name);if e then
        used[e.id]=true;total=total+1;if e.exclusive_group then groups[e.exclusive_group]=true end
    end end
    local native_categories,native_legendary=pool.categories,pool.legendary
    pool.refresh=function(ids)
        pool.categories=native_categories;pool.legendary=native_legendary
        M.add_to_pool(pool,player,ids)
    end
    local mixed,weights={},{}
    for _,category in ipairs(pool.categories)do for _,name in ipairs(pool.legendary[category])do mixed[#mixed+1]=name;weights[name]=1 end end
    local setup=build(player)
    if total<snap.options.max_total then for _,e in ipairs(snap.document.entries)do
        if e.enabled and not used[e.id] and e.weight>0
            and (not e.exclusive_group or not groups[e.exclusive_group]) and policy_allowed(snap.document,e) and Eligibility.matches(e,setup) then
            local name="diy::"..e.id;mixed[#mixed+1]=name;weights[name]=e.weight
        end
    end end
    table.sort(mixed);pool.categories={"mixed"};pool.legendary={mixed=mixed};pool.entry_weights=weights
end
local function ensure()
    local snap=current()
    if not authority() then
        if engine then engine.finish();engine=nil;bindings=setmetatable({},{__mode="k"}) end
        return nil
    end
    if snap and authority() and snap.options.enabled and not engine then
        engine=Scripts.attach(Engine.new(snap.document,Catalog,api,snap.options.seed),snap,
            {Schema=Schema,Packages=Packages,PackageAPI=PackageAPI,Engine=Engine,native=api,catalog=Catalog,error=library.runtime_error,assets=assets,authority=authority,
             log=function(id,message)mod:info("[DIY %s] %s",id,message)end})
    end
    return authority() and engine or nil
end
local function request()
    local snap=current() or library.snapshot()
    local ids={}
    local enabled=snap.options.enabled
    if mod.session_context().is_realms_client and mod.mortis_rules then local rules=mod.mortis_rules();enabled=rules and rules.diy_enabled end
    if enabled and (not mod.mortis_reward_mode or mod.mortis_reward_mode()=="preselect") then
        local p=Network.local_player()
        if busy() and p and build(p).complete and (not mod.mortis_host_policy or mod.mortis_host_policy.current()) then
            M.local_choices=M.local_choices or {};local key=tostring(p:character_id())
            if mod.mortis_reward_mode then ids=choose(snap,p)
            else
                if not M.local_choices[key] then M.local_choices[key]=choose(snap,p) end
                ids=choose(snap,p,M.local_choices[key])
            end
        else ids=choose(snap,p) end
    end
    local definitions={};local manifest=M.manifest()
    for _,id in ipairs(ids)do definitions[id]=manifest.entries[id] end
    local selection_ready=true
    if enabled and mod.mortis_host_policy and (not mod.mortis_reward_mode or mod.mortis_reward_mode()=="preselect") then
        for _,id in ipairs(snap.options.selected)do for _,peer in ipairs(mod.mortis_host_policy.missing(id))do
            if peer.reason=="pending" then selection_ready=false end
        end end
    end
    return {signature=snap.signature,ids=ids,definitions=definitions,selection_ready=selection_ready,policy_revision=mod.mortis_host_policy and mod.mortis_host_policy.revision()}
end
local function accept(p,value)
    local snap=current() or library.snapshot()
    if not snap.options.enabled then return false,"host_disabled" end
    if type(value)~="table" or type(value.definitions)~="table" then return false,"config_mismatch" end
    if value.selection_ready==false then return false,"policy_pending" end
    if mod.mortis_host_policy and value.policy_revision~=mod.mortis_host_policy.revision() then return false,"policy_pending" end
    if not build(p).complete then return false,"build_pending" end
    if type(value.ids)~="table" or #value.ids>99 then return false,"invalid_selection" end
    local available={};for _,e in ipairs(snap.document.entries) do if e.enabled then available[e.id]=true end end
    local seen={};local n=0
    for k,id in pairs(value.ids) do
        n=n+1
        if type(k)~="number" or k%1~=0 or k<1 or k>#value.ids or not available[id] or seen[id] then return false,"invalid_selection" end
        seen[id]=true
    end
    if n~=#value.ids or n>snap.options.max_total then return false,"invalid_selection" end
    local manifest=M.manifest();local count=0
    for id,hash in pairs(value.definitions)do
        count=count+1
        if not seen[id] or manifest.entries[id]~=hash then return false,"config_mismatch" end
    end
    if count~=#value.ids then return false,"config_mismatch" end
    local chosen=choose(snap,p,value.ids)
    if #chosen~=#value.ids then return false,"incompatible_selection" end
    local key=tostring(p:peer_id()):lower().."/"..tostring(p:character_id())
    remote=remote or {}
    if not remote[key] or not busy() then remote[key]=Schema.copy(value.ids) end
    return true,"ready"
end
network=Network.new(mod,Catalog,{context=Network.context,realms=Network.realms,local_player=Network.local_player,players=Network.players,
    request=request,accept=accept,snapshot=function(p,accepted)
        local e=ensure();return e and accepted and p.player_unit and e.effects(p.player_unit),accepted and "ready" or nil
    end})
api=Game.new(mod,Catalog,Engine,{name="MortisBuffManager",engine=ensure,authority=authority,skip_attack_report=true,
    family=mod.mortis_diy_family,
    available=function(entry,unit)
        local spawn=Managers.state and Managers.state.player_unit_spawn
        local p=spawn and spawn.owner and spawn:owner(unit)
        if not p then for _,candidate in pairs(Network.players()) do if candidate.player_unit==unit then p=candidate;break end end end
        if not p then return false end
        local setup=setup_cache[p];if not setup then setup=build(p);setup_cache[p]=setup end
        return policy_allowed((snapshot or library.snapshot()).document,entry) and Eligibility.matches(entry,setup)
    end,
    client_effects=function(unit)
        -- Host/local native Buff updates cannot consume a client snapshot.
        if network.role=="client" then return network.effects(unit) end
    end,language=function() return mod:localize("diy_language") end})
function M.update(dt)
    assets.update(dt)
    local policy=mod.mortis_host_policy
    local rules=mod.mortis_rules and mod.mortis_rules()
    notice_elapsed=notice_elapsed+dt
    local check_notices=notice_rules~=(rules or library.options) or notice_elapsed>=.5
    if check_notices then notice_elapsed=0;notice_rules=rules or library.options end
    if check_notices and policy and (rules and rules.diy_enabled or not rules and library.options.enabled) then
        local snap=current() or library.snapshot();local p=Network.local_player()
        local mode=mod.mortis_reward_mode and mod.mortis_reward_mode() or "preselect"
        local ids=mode~="preselect" and p and mod.mortis_diy_reward_ids(p) or snap.options.selected
        policy.notify("diy",ids,snap.document.id.."/",function(id)
            for _,entry in ipairs(snap.document.entries)do if entry.id==id then return Schema.localize(entry.name,mod:localize("diy_language")) end end
            return id
        end)
    end
    network.update(dt)
    local e=ensure();if not e then return end
    elapsed=(elapsed or 0)+dt;if elapsed<.1 then return end;local step=elapsed;elapsed=0
    setup_cache=setmetatable({},{__mode="k"})
    local active={};local p=Network.local_player()
    for _,player in pairs(Network.players()) do
        local unit=player.player_unit
        if unit and api.alive(unit) then
            local ids={}
            if mod.mortis_reward_mode and mod.mortis_reward_mode()~="preselect" then
                if player==p or network.eligible(player) then ids=choose(snapshot,player,mod.mortis_diy_reward_ids(player)) end
            elseif player==p then ids=request().ids
            elseif network.eligible(player) then ids=choose(snapshot,player,remote[tostring(player:peer_id()):lower().."/"..tostring(player:character_id())] or {}) end
            e.set_owner(unit,ids);active[unit]=true;bindings[unit]=true
        end
    end
    for unit in pairs(bindings) do if not active[unit] then e.set_owner(unit,{});bindings[unit]=nil end end
    api.update();e.tick(step)
end
function M.finish() network.finish();finish() end
function M.ranged_salvo_count(unit)
    if not authority() or not unit or not api.alive(unit) then return 1 end
    local e=ensure();if not e then return 1 end
    local count=e.effects(unit).modifiers.ranged_salvo_count or 1
    return math.max(1,math.min(5,math.floor(count)))
end
M.enemy_died=api.enemy_died
function M.status() return {network=network.status,active=ensure()~=nil,signature=(current() or library.snapshot()).signature} end
mod.diy_api={version=1,minor=1}
-- Local views/HUDs may acquire resources on clients without creating an
-- authority engine. Close the scope when the consuming view exits.
function mod.diy_api.open_assets(package_id,active)
    if not Packages.id(package_id) then return nil,"diy_package_missing" end
    local pack=library.snapshot().packages[package_id]
    if not pack then return nil,"diy_package_missing" end
    return assets.open(pack,active)
end
mod.diy_api.assets_available=assets.available
mod.diy_api.asset_status=assets.status
function mod.diy_api.qualify(package_id,entry_id)
    if not Packages.id(package_id) or not Packages.id(entry_id) then return nil end
    local pack=library.packages[package_id]
    return pack and PackageAPI.entry_identity(pack,entry_id) or PackageAPI.identity(package_id,entry_id)
end
function mod.diy_api.paused(family) local e=ensure();return e and e.paused(family) or false end
function mod.diy_api.context(c)
    c=c or {};c.signal=c.signal or {};local e=ensure()
    if e then for name,t in pairs(e.signals) do if t>e.now then c.signal[name]=true end end end
    return c
end
mod.diy_api.status=M.status
finish()
if mod.mortis_host_policy and mod.mortis_host_policy.migrate_package_keys then mod.mortis_host_policy.migrate_package_keys(library.legacy_policy_keys)end
return M
