-- Native boundary for the v1 data runtime. Shared source, independently owned hooks.
local G={}
local function weak() return setmetatable({},{__mode="k"}) end
local function copy(t) local out={};for k,v in pairs(t or {}) do out[k]=v end;return out end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
function G.new(mod,catalog,Engine,options)
    -- DMF loads mods before native network types exist. Never force gameplay
    -- files from here: BuffExtensionBase reads those types at file scope.
    local Attack,DamageProfiles,BuffTemplates,Ammo,Stamina,WarpCharge,Overheat,FixedFrame,UISounds,PlayerStatus
    local native_ready=false
    local function load_native_utilities()
        if native_ready then return end
        Attack=require("scripts/utilities/attack/attack")
        DamageProfiles=require("scripts/settings/damage/damage_profile_templates")
        BuffTemplates=require("scripts/settings/buff/buff_templates")
        Ammo=require("scripts/utilities/ammo")
        Stamina=require("scripts/utilities/attack/stamina")
        WarpCharge=require("scripts/utilities/warp_charge")
        Overheat=require("scripts/utilities/overheat")
        FixedFrame=require("scripts/utilities/fixed_frame")
        UISounds=require("scripts/settings/ui/ui_sound_events")
        PlayerStatus=require("scripts/utilities/attack/player_unit_status")
        native_ready=true
    end
    local function on_require(path,callback)
        local seen=weak()
        mod:hook_require(path,function(object)
            -- DMF can revisit an existing file instance on later require calls.
            if seen[object] then return end
            callback(object);seen[object]=true
        end)
    end
    local owner_mod=get_mod("DMF") or mod
    local updates=owner_mod._diy_minion_updates
    if not updates then updates={providers={},owned=weak()};owner_mod._diy_minion_updates=updates end
    updates.providers[options.name]=false
    local function needs_updates()
        for _,needed in pairs(updates.providers) do if needed then return true end end
        return false
    end
    local function retired(ext)
        return rawget(ext,"__deleted") or rawget(ext,"_diy_minion_destroying")
    end
    local function enable_minion(ext)
        if retired(ext) then return end
        if not ext._update_enabled and ext._owner_system then
            ext._update_enabled=true;updates.owned[ext]=true
            ext._owner_system:enable_update_function(ext.__class_name,"update",ext._unit,ext)
        end
    end
    local function restore_minions()
        if needs_updates() then return end
        updates.restoring=true
        for ext in pairs(updates.owned) do
            if not retired(ext) and ALIVE[ext._unit] and ext._owner_system and #ext._buffs==0 then
                FixedFrame=FixedFrame or require("scripts/utilities/fixed_frame")
                ext:_update_stat_buffs_and_keywords(FixedFrame.get_latest_fixed_time())
                ext._update_enabled=false
                ext._owner_system:disable_update_function(ext.__class_name,"update",ext._unit,ext)
            end
            updates.owned[ext]=nil
        end
        updates.restoring=false
    end
    local keys,serial,cache=weak(),0,weak()
    local owned_buffs={};local pickups_created=0;local spawned=weak();local reported={};local combat_times=weak()
    local api={}
    local finishing=false
    local function extension(unit,name)
        if not unit or not ALIVE[unit] then return end
        return ScriptUnit.has_extension(unit,name)
    end
    function api.alive(unit) return unit~=nil and HEALTH_ALIVE[unit] or false end
    function api.key(unit)
        if not keys[unit] then
            local state=Managers.state or {};local spawn=state.player_unit_spawn
            local player=spawn and spawn.owner and spawn:owner(unit)
            if player then keys[unit]="player/"..tostring(player:peer_id()).."/"..tostring(player:local_player_id()).."/"..tostring(player:character_id())
            else
                local spawner=state.unit_spawner;local id=spawner and spawner.game_object_id and spawner:game_object_id(unit)
                serial=serial+1;keys[unit]=id and string.format("unit/%010d",id) or string.format("local/%010d",serial)
            end
        end
        return keys[unit]
    end
    function api.info(unit)
        local data=extension(unit,"unit_data_system")
        local breed=data and data.breed and data:breed()
        if not breed then return nil end
        -- Minion/prop extensions expose archetype() as an unsupported method
        -- that raises ferror. Method presence is not a capability check; use
        -- the native breed type before touching player-only data.
        local player=breed.breed_type=="player"
        local archetype
        if player and data.archetype then archetype=data:archetype() end
        return {kind=player and "players" or breed.breed_type=="minion" and "minions" or "other",
            breed=breed.name,tags=breed.tags or {},archetype=archetype and archetype.name}
    end
    function api.available(entry,unit)
        if options.available then return options.available(entry,unit) end
        local a=entry.availability;if not a then return true end
        local spawn=Managers.state and Managers.state.player_unit_spawn
        local player=spawn and unit and spawn:owner(unit)
        if not player then return false end
        local function contains(list,value)
            if not list or #list==0 then return true end
            for _,v in ipairs(list) do if v==value then return true end end;return false
        end
        if not contains(a.archetypes,player:archetype_name()) or not contains(a.families,options.family and options.family(player)) then return false end
        local profile=player:profile();local talents=profile and profile.talents or {}
        for _,name in ipairs(a.talents or {}) do if talents[name]~=true and not (type(talents[name])=="number" and talents[name]>0) then return false end end
        return true
    end
    function api.units(selector,center,radius,limit)
        local out,seen={},{}
        local origin=center and POSITION_LOOKUP[center]
        if center and not origin then return out end
        local state=Managers.state or {}
        local function add(unit)
            if not seen[unit] and api.alive(unit) and Engine.matches(selector,api.info(unit)) then
                local position=POSITION_LOOKUP[unit]
                if not radius or position and Vector3.distance_squared(position,origin)<=radius*radius then out[#out+1]=unit;seen[unit]=true end
            end
        end
        if selector.kind~="minions" then
            local systems=state.extension
            local side_system=systems and systems:system("side_system")
            local side=side_system and side_system:get_side(1)
            if side then for _,unit in ipairs(side.valid_player_units or {}) do add(unit) end
            elseif Managers.player and Managers.player.human_players then
                for _,player in pairs(Managers.player:human_players()) do if player.player_unit then add(player.player_unit) end end
            end
        end
        if selector.kind~="players" and state.minion_spawn then
            for _,unit in ipairs(state.minion_spawn:spawned_minions()) do add(unit) end
        end
        table.sort(out,function(a,b) return api.key(a)<api.key(b) end)
        for i=#out,(limit or 64)+1,-1 do out[i]=nil end
        return out
    end
    local function component(data,name)
        if not data or not data.read_component then return nil end
        -- Player-only components are queried only on a player unit. Available
        -- components come from the native player template, not imported paths.
        return data:read_component(name)
    end
    function api.context(unit,event)
        load_native_utilities()
        local c=copy(options.context and options.context() or {})
        if not options.context then
            local state=Managers.state or {};local pacing=state.pacing
            if pacing then
                c.stage=pacing:state();c.load=pacing:total_challenge_rating();c.monsters=pacing:num_aggroed_monsters();c.progress=pacing:get_mission_progression()
            end
            c.players=0
            for _,u in ipairs(api.units({kind="players"},nil,nil,4)) do
                local data=extension(u,"unit_data_system")
                if data and not PlayerStatus.requires_help(data:read_component("character_state")) then c.players=c.players+1 end
            end
            c.native_condition={}
            local d=state.difficulty;local havoc=d and d.get_parsed_havoc_data and d:get_parsed_havoc_data()
            for _,id in ipairs(havoc and havoc.circumstances or {}) do c.native_condition[id]=true end
            local circumstance=state.circumstance and state.circumstance._circumstance_name
            if circumstance then c.native_condition[circumstance]=true end
            local hcm=get_mod("HavocConditionManager");if hcm and hcm.diy_api then hcm.diy_api.context(c) end
            local hed=get_mod("HavocEnemyDirector");if hed and hed.diy_api then c.phase=hed.diy_api.status().phase end
        end
        local info=unit and api.info(unit)
        if info then c.breed=info.breed;c.archetype=info.archetype;c.tag=info.tags end
        local health=extension(unit,"health_system")
        if health then
            c.health=health:current_health_percent()
            c.corruption=health.permanent_damage_taken_percent and health:permanent_damage_taken_percent()
        end
        local toughness=extension(unit,"toughness_system")
        if toughness and toughness.current_toughness_percent then c.toughness=toughness:current_toughness_percent() end
        local coherency=extension(unit,"coherency_system")
        if coherency then c.coherency=coherency:num_units_in_coherency() end
        if info and info.kind=="players" then
            local data=extension(unit,"unit_data_system")
            local character=component(data,"character_state")
            c.knocked_down=character and character.state_name=="knocked_down"
            local sprint=component(data,"sprint_character_state")
            c.sprinting=sprint and sprint.is_sprinting
            c.dodging=character and character.state_name=="dodging"
            c.sliding=character and character.state_name=="sliding"
            local stamina=component(data,"stamina");c.stamina=stamina and stamina.current_fraction
            local warp=component(data,"warp_charge");c.warp_charge=warp and warp.current_percentage
            local slot=component(data,"slot_secondary")
            if slot then
                local maximum=(slot.max_ammunition_reserve or 0)+Ammo.max_ammo_in_clips(slot)
                if maximum>0 then c.ammo=((slot.current_ammunition_reserve or 0)+Ammo.current_ammo_in_clips(slot))/maximum end
                c.overheat=slot.overheat_current_percentage
            end
            local engine=options.engine()
            c.in_combat=engine and combat_times[unit] and engine.now-combat_times[unit]<8 or false
        end
        if event then
            c.attack_type=event.attack_type
            c.critical=event.is_critical_strike
            if c.critical==nil then c.critical=event.is_critical_hit end
            c.weakspot=event.hit_weakspot
            if c.weakspot==nil then c.weakspot=event.is_weakspot_hit end
        end
        return c
    end
    local direct_profile,override_amount
    local function damage(unit,amount,event,kill)
        if not direct_profile then
            local original=DamageProfiles.liquid_area_fire_burning
            if not original then return false end
            direct_profile=copy(original)
            direct_profile.ignore_toughness=true;direct_profile.override_allow_friendly_fire=true
            direct_profile.power_distribution=copy(original.power_distribution);direct_profile.power_distribution.impact=0
            direct_profile.no_hit_reaction=true
        end
        local info=api.info(unit)
        if kill and (not info or info.kind~="minions" or not catalog.spawn_breeds[info.breed]) then return false end
        override_amount=amount
        local ok,err=pcall(Attack.execute,unit,direct_profile,"power_level",1,"damage_type","buff","attack_type","buff",
            "attacking_unit",event and event.attacker,"instakill",kill==true)
        override_amount=nil
        if not ok then error(err,0) end
        return true
    end
    on_require("scripts/utilities/attack/damage_calculation",function(DamageCalculation)
        mod:hook(DamageCalculation,"calculate",function(fn,profile,...)
            if profile==direct_profile and override_amount~=nil then return override_amount,"full",override_amount,0,0,0,0,0,1,1 end
            return fn(profile,...)
        end)
    end)
    local function amount(a,unit,event,maximum)
        if a.amount_kind=="event_damage" then return clamp((event.damage or event.damage_amount or event.damage_dealt or 0)*a.amount,0,100000) end
        if a.amount_kind=="fraction" then return (maximum or 1)*a.amount end
        return a.amount
    end
    local function perform(a,unit,event,meta)
        load_native_utilities()
        local health=extension(unit,"health_system")
        if a.type=="heal" or a.type=="corruption" then
            if not health then return false end
            health:add_heal(amount(a,unit,event,health:max_health()),a.type=="corruption" and "buff_corruption_healing" or "buff");return true
        elseif a.type=="toughness" then
            local ext=extension(unit,"toughness_system");if not ext or not ext.recover_flat_toughness then return false end
            local delta=amount(a,unit,event,ext:max_toughness())
            if delta<0 then ext:add_damage(-delta,nil,nil,nil,"melee",Vector3.zero())
            else ext:recover_flat_toughness(delta,false,"buff") end;return true
        elseif a.type=="damage" then
            if not health then return false end
            return damage(unit,amount(a,unit,event,health:max_health()),event,false)
        elseif a.type=="kill" then return damage(unit,health and health:max_health() or 0,event,true)
        elseif a.type=="ammo" then
            local data=extension(unit,"unit_data_system");local visual=extension(unit,"visual_loadout_system")
            local info=api.info(unit);if not data or not visual or not info or info.kind~="players" then return false end
            local total=0
            for slot_name in pairs(visual:slot_configuration_by_type("weapon")) do
                local slot=data:write_component(slot_name)
                local maximum=(slot.max_ammunition_reserve or 0)+Ammo.max_ammo_in_clips(slot)
                if maximum>0 then
                    local value=a.amount_kind=="current_fraction" and
                        (Ammo.current_ammo_in_reserve(slot)+Ammo.current_ammo_in_clips(slot))*a.amount or amount(a,unit,event,maximum)
                    value=value<0 and math.ceil(value) or math.floor(value)
                    if value>=0 then total=total+Ammo.add_to_reserve(slot,value)
                    else
                        local reserve=Ammo.current_ammo_in_reserve(slot)
                        local removed=math.min(reserve,-value)
                        Ammo.add_to_reserve(slot,-removed)
                        Ammo.add_to_clip(slot,math.min(0,value+removed));total=total+removed
                    end
                end
            end
            return true
        elseif a.type=="grenades" or a.type=="ability_cooldown" then
            local ext=extension(unit,"ability_system");if not ext then return false end
            local kind=a.type=="grenades" and "grenade_ability" or "combat_ability"
            if not ext:has_ability_type(kind) then return false end
            if a.type=="grenades" then
                local delta=amount(a,unit,event,ext:max_ability_charges(kind))
                ext:set_ability_charges(kind,clamp(ext:remaining_ability_charges(kind)+(delta<0 and math.ceil(delta) or math.floor(delta)),0,ext:max_ability_charges(kind)))
            else ext:reduce_ability_cooldown_time(kind,amount(a,unit,event,ext:max_ability_cooldown(kind))) end
            return true
        elseif a.type=="stamina" then
            local info=api.info(unit);if not info or info.kind~="players" then return false end
            if a.amount_kind=="fraction" then
                if a.amount<0 then Stamina.drain_pecentage(unit,-a.amount,FixedFrame.get_latest_fixed_time())
                else Stamina.add_stamina_percent(unit,a.amount) end
            elseif a.amount<0 then Stamina.drain(unit,-a.amount,FixedFrame.get_latest_fixed_time())
            else Stamina.add_stamina(unit,a.amount) end
            return true
        elseif a.type=="warp_charge" or a.type=="overheat" then
            local info=api.info(unit);local data=extension(unit,"unit_data_system")
            if not data or not info or info.kind~="players" then return false end
            -- Positive values add percentage points; negative values vent/quell.
            local value=a.amount_kind=="fraction" and a.amount or a.amount/100
            if a.type=="warp_charge" then
                local archetype=data:archetype()
                if not archetype or not archetype.warp_charge then return false end
                local c=data:write_component("warp_charge");local ext=extension(unit,"buff_system")
                if value<=0 then WarpCharge.decrease_immediate(-value,c,unit)
                else c.current_percentage=clamp(c.current_percentage+value,0,1);WarpCharge.check_and_set_state(FixedFrame.get_latest_fixed_time(),c,ext,true) end
            else
                local c=data:write_component("slot_secondary")
                local visual=extension(unit,"visual_loadout_system")
                if not visual or not Overheat.configuration(visual,"slot_secondary") then return false end
                if value<=0 then Overheat.decrease_immediate(-value,c)
                else Overheat.increase_immediate(FixedFrame.get_latest_fixed_time(),1,c,{use_charge=false,overheat_percent=value},unit,false) end
            end
            return true
        elseif a.type=="native_buff" then
            local spec=catalog.native_buffs[a.name];local info=api.info(unit);local ext=extension(unit,"buff_system")
            local template=BuffTemplates[a.name]
            if not ext or not template or not info or spec.target~=info.kind or #owned_buffs>=256 then return false end
            if ext._buff_context and ext._buff_context.is_local_unit and info.kind=="minions" then return false end
            local made=false
            for i=1,a.count or 1 do
                local denied,index,component_index=ext:add_externally_controlled_buff(a.name,FixedFrame.get_latest_fixed_time(),"owner_unit",event.attacker or event.unit)
                if not denied and index then
                    owned_buffs[#owned_buffs+1]={unit=unit,extension=ext,index=index,component=component_index,expires=meta.now+(a.duration or 10),owner=meta.owner,entry=meta.entry}
                    made=true
                end
            end
            return made
        elseif a.type=="spawn_formation" or a.type=="spawn_enemy" then
            local director=get_mod("HavocEnemyDirector")
            local interface=director and director.diy_api
            if not interface or interface.version~=1 or not interface.request then return false end
            return interface.request({formation=a.type=="spawn_formation" and a.name or nil,breed=a.breed,count=a.count or 1,
                source=options.name.."/"..meta.entry.."/"..tostring(meta.rule),seed=meta.seed})
        elseif a.type=="pickup" then
            if pickups_created>=32 then return false end
            local state=Managers.state or {};local system=state.extension and state.extension:system("pickup_system")
            local position=unit and POSITION_LOOKUP[unit];if not system or not position then return false end
            local source=state.player_unit_spawn and state.player_unit_spawn:owner(unit)
            local made=false
            for i=1,math.min(a.count or 1,32-pickups_created) do
                local pickup=system:spawn_pickup(a.name,position+Vector3(0,0,.25),Quaternion.identity(),nil,nil,1,source)
                if pickup then made=true;pickups_created=pickups_created+1 end
            end
            return made
        elseif a.type=="sound" then
            if not UISounds[a.name] or not Managers.ui then return false end
            Managers.ui:play_2d_sound(UISounds[a.name]);return true
        elseif a.type=="notification" then
            local lang=options.language and options.language() or "en"
            local v=a.text;local text=type(v)=="table" and (v[lang] or v.en or v["zh-cn"]) or v
            mod:notify("%s",text);return true
        end
        return false
    end
    function api.action(a,unit,event,meta)
        if not options.authority() then return false end
        owner_mod._diy_action_depth=(owner_mod._diy_action_depth or 0)+1
        local ok,result=pcall(perform,a,unit,event or {},meta or {})
        owner_mod._diy_action_depth=owner_mod._diy_action_depth-1
        if not ok then error(result,0) end
        return result
    end
    function api.error(message,entry,action)
        local key=tostring(entry).."/"..tostring(action)
        if not reported[key] then reported[key]=true;mod:warning("DIY %s: %s",key,tostring(message)) end
    end
    local function release(record)
        local ext=record.extension
        if not retired(ext) and ALIVE[record.unit] and (ext._buffs_by_index and ext._buffs_by_index[record.index] or ext._muted_external_buffs and ext._muted_external_buffs[record.index]) then
            ext:remove_externally_controlled_buff(record.index,record.component)
        end
    end
    function api.owner_changed(unit,removed)
        for i=#owned_buffs,1,-1 do local record=owned_buffs[i]
            if record.owner==unit and removed[record.entry] then release(record);table.remove(owned_buffs,i) end
        end
    end
    function api.update()
        local engine=options.engine()
        if not engine then return end
        local needed=not engine.finished and engine.needs_minion_updates()
        local previous=updates.providers[options.name];updates.providers[options.name]=needed
        if needed and not previous then
            -- One scan at activation covers units created before this runtime.
            local spawn=Managers.state and Managers.state.minion_spawn
            for _,unit in ipairs(spawn and spawn:spawned_minions() or {}) do
                local ext=extension(unit,"buff_system");if ext then enable_minion(ext) end
            end
        elseif previous and not needed then restore_minions() end
        for i=#owned_buffs,1,-1 do local record=owned_buffs[i]
            if record.expires<=engine.now or not api.alive(record.unit) then release(record);table.remove(owned_buffs,i) end
        end
        for _,unit in ipairs(api.units({kind="players"},nil,nil,4)) do
            if not spawned[unit] and extension(unit,"buff_system") then
                spawned[unit]=true;engine.dispatch("spawn",unit,{target=unit})
                engine.dispatch("mission_start",unit,{target=unit})
            end
        end
    end
    function api.finish()
        finishing=true
        updates.providers[options.name]=false
        restore_minions()
        for _,record in ipairs(owned_buffs) do release(record) end
        owned_buffs={};keys=weak();serial=0;cache=weak();spawned=weak();pickups_created=0;reported={};combat_times=weak()
        finishing=false
    end
    function api.invalidate() cache=weak() end
    local function active_engine()
        if not finishing and options.authority() and (owner_mod._diy_action_depth or 0)==0 then return options.engine() end
    end
    on_require("scripts/utilities/ammo",function(Ammo)
      mod:hook(Ammo,"add_ammo_using_pickup_data",function(fn,unit,pickup,skip_proc)
        local e=active_engine()
        if not e or not pickup or type(pickup.ammo_amount_func)~="function" then return fn(unit,pickup,skip_proc) end
        local modifiers=e.effects(unit).modifiers
        local factor=modifiers.ammo_pickup_multiplier or 1
        local failure=modifiers.ammo_pickup_failure_chance or 0
        if failure>0 and e.roll("ammo_pickup",unit,failure) then factor=0 end
        if factor==1 then return fn(unit,pickup,skip_proc) end
        local private=copy(pickup);local original=pickup.ammo_amount_func
        private.ammo_amount_func=function(...) return math.floor(original(...)*factor) end
        return fn(unit,private,skip_proc)
      end)
    end)
    function api.enemy_died(unit,attacker,damage_amount,attack_type,critical)
        local engine=active_engine()
        if engine then engine.dispatch("enemy_died",unit,{target=unit,attacker=attacker,damage=damage_amount,attack_type=attack_type,is_critical_strike=critical}) end
    end
    local function on_proc(self,event,params)
        local engine=active_engine()
        if engine and catalog.events[event] then
            if event=="on_damage_dealt" or event=="on_damage_taken" or event=="on_hit" then combat_times[self._unit]=engine.now end
            engine.dispatch(event,self._unit,params)
        end
    end
    local function on_stats(self)
        if finishing or updates.restoring then return end
        local unit=self._unit
        local effect=options.client_effects and options.client_effects(unit)
        if not effect and options.authority() then
            local engine=options.engine()
            if engine then
                local record=cache[unit]
                if not record or record.engine~=engine or record.revision~=engine.revision or record.now~=engine.now then
                    record={engine=engine,revision=engine.revision,now=engine.now,effects=engine.effects(unit)};cache[unit]=record
                end
                effect=record.effects
            end
        end
        if effect then Engine.apply(effect,self._stat_buffs,self._keywords,catalog) end
    end
    -- Native classes copy inherited methods when declared. Hook each concrete
    -- class after the game's loader has finished defining its overrides.
    local function hook_buff(class)
        mod:hook_safe(class,"add_proc_event",on_proc)
        mod:hook_safe(class,"_update_stat_buffs_and_keywords",on_stats)
    end
    on_require("scripts/extension_systems/buff/player_unit_buff_extension",hook_buff)
    on_require("scripts/extension_systems/buff/minion_buff_extension",function(MinionBuff)
        hook_buff(MinionBuff)
        mod:hook(MinionBuff,"destroy",function(fn,self,...)
            -- Native removal unregisters this extension before destroy removes
            -- its buffs. Keep those callbacks from registering it again while
            -- the unit is still alive; both DIY managers observe this marker.
            self._diy_minion_destroying=true
            updates.owned[self]=nil
            return fn(self,...)
        end)
        mod:hook_safe(MinionBuff,"init",function(self) if needs_updates() then enable_minion(self) end end)
        mod:hook_safe(MinionBuff,"_on_remove_buff",function(self) if needs_updates() then enable_minion(self) end end)
    end)
    if not options.skip_attack_report then
        on_require("scripts/managers/attack_report/attack_report_manager",function(AttackReport)
            mod:hook_safe(AttackReport,"add_attack_result",function(self,profile,victim,attacker,direction,position,weakspot,damage_amount,result,attack_type,efficiency,critical)
                if self._is_server and result=="died" then api.enemy_died(victim,attacker,damage_amount,attack_type,critical) end
            end)
        end)
    end
    return api
end
return G
