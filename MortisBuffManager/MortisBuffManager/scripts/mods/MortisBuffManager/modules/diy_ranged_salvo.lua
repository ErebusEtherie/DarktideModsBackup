-- Five copies of the native ranged attack, with the original action paying once.
-- Only authoritative SoloPlay/Realms effects may request extra attacks. Do not
-- replay action start/update: those also spend ammo, warp charge and overheat.
local mod=get_mod("MortisBuffManager")
local Salvo={version=1};mod.diy_ranged_salvo=Salvo
local installed=setmetatable({},{__mode="k"})
local repeating=setmetatable({},{__mode="k"})
local pellet_context
local primitive_depth=0
local function pack(...) return {n=select("#",...),...} end
local function shallow(value) local out={};for k,v in pairs(value or {})do out[k]=v end;return out end
local function count_for(action)
    if not action._is_server or repeating[action] or not mod:is_enabled() then return 1 end
    local slot=action._inventory_component and action._inventory_component.wielded_slot
    if slot~="slot_secondary" then return 1 end
    local template=action._weapon_template or action._weapon and action._weapon.weapon_template
    local ranged=false
    for _,keyword in ipairs(template and template.keywords or {})do if keyword=="ranged" then ranged=true;break end end
    if not ranged then return 1 end
    local diy=mod.diy_mortis
    local n=diy and diy.ranged_salvo_count and diy.ranged_salvo_count(action._player_unit) or 1
    return type(n)=="number" and n==n and math.max(1,math.min(5,math.floor(n))) or 1
end
local function repeat_native(fn,self,...)
    local count=count_for(self)
    if count==1 then return fn(self,...) end
    local args=pack(...);local result;local flags={}
    repeating[self]=true
    local ok,err=pcall(function()
        for i=1,count do
            local values=pack(fn(self,unpack(args,1,args.n)))
            result=result or values
            for k,v in pairs(self._shot_result or {})do if type(v)=="boolean" then flags[k]=flags[k] or v end end
        end
    end)
    repeating[self]=nil
    for k,v in pairs(flags)do self._shot_result[k]=v end
    if not ok then error(err,0) end
    return unpack(result,1,result.n)
end
local function once(class,method,hook)
    local methods=installed[class]
    if not methods then methods={};installed[class]=methods end
    if methods[method] then return end
    assert(type(class[method])=="function","Missing native ranged method: "..method)
    methods[method]=true;mod:hook(class,method,hook)
end
local function action(name,install)
    mod:hook_require("scripts/extension_systems/weapon/actions/"..name,install)
end
action("action_shoot_hit_scan",function(class)once(class,"_shoot",repeat_native)end)
action("action_shoot_projectile",function(class)once(class,"_shoot",repeat_native)end)
action("action_trigger_explosion",function(class)once(class,"_explode",repeat_native)end)
action("action_chain_lightning",function(class)once(class,"_deal_damage",repeat_native)end)

action("action_spawn_projectile",function(class)
    -- Save the charge before the action pays/resets it. This also covers a paid
    -- interrupted action whose first projectile is launched by native finish().
    once(class,"_spawn_projectile_unit",function(fn,self,critical)
        local charge=self._charge_component and self._charge_component.charge_level
        local unit=fn(self,critical)
        if self._is_server and unit then
            self._diy_salvo_projectiles=self._diy_salvo_projectiles or setmetatable({},{__mode="k"})
            self._diy_salvo_projectiles[unit]={critical=critical,charge=charge}
        end
        return unit
    end)
    once(class,"_fire_projectile",function(fn,self,t,unit,time_difference,locomotion,offset)
        local count=count_for(self)
        local seed=self._diy_salvo_projectiles and self._diy_salvo_projectiles[unit]
        if count==1 or not seed then return fn(self,t,unit,time_difference,locomotion,offset) end
        local charge_component=self._charge_component
        local result,pending_extra
        repeating[self]=true
        local ok,err=pcall(function()
            result=pack(fn(self,t,unit,time_difference,locomotion,offset))
            for i=2,count do
                self._charge_component=seed.charge~=nil and {charge_level=seed.charge} or charge_component
                local extra=self:_spawn_projectile_unit(seed.critical);pending_extra=extra
                self._charge_component=charge_component
                if extra then
                    local extra_locomotion=ScriptUnit.extension(extra,"locomotion_system")
                    fn(self,t,extra,time_difference,extra_locomotion,offset)
                    self._diy_salvo_projectiles[extra]=nil
                    pending_extra=nil
                end
            end
        end)
        self._charge_component=charge_component;repeating[self]=nil
        if not ok then
            if pending_extra then
                local state=Managers.state
                pcall(function()
                    state.player_unit_spawn:relinquish_unit_ownership(pending_extra)
                    state.unit_spawner:mark_for_deletion(pending_extra)
                end)
            end
            error(err,0)
        end
        return unpack(result,1,result.n)
    end)
    once(class,"finish",function(fn,self,...)
        local result=pack(pcall(fn,self,...));self._diy_salvo_projectiles=nil
        if not result[1] then error(result[2],0) end
        return unpack(result,2,result.n)
    end)
end)

action("action_flamer_gas_burst",function(class)
    once(class,"_damage_target",repeat_native)
    once(class,"_burn_target",repeat_native)
end)
action("action_flamer_gas",function(class)
    once(class,"_damage_target",repeat_native)
    once(class,"_burn_targets",function(fn,self,dt,t,force)
        local count=count_for(self)
        local before=self._burn_time
        if count==1 or before-dt>0 and not force then return fn(self,dt,t,force) end
        local targets=self._dot_targets;local saved=shallow(targets)
        local after,result
        repeating[self]=true
        local ok,err=pcall(function()
            result=pack(fn(self,dt,t,force));after=self._burn_time
            for i=2,count do
                self._dot_targets=shallow(saved);self._burn_time=before
                fn(self,dt,t,force)
            end
        end)
        self._dot_targets=targets;self._burn_time=after or before;repeating[self]=nil
        if not ok then error(err,0) end
        return unpack(result,1,result.n)
    end)
end)

-- Shotguns have a fixed native 32-pellet scratch buffer and per-shell damage
-- aggregation. Reuse the original ray pattern and repeat its resolved attacks,
-- explosions and native status applications. Never enlarge that buffer or
-- multiply the pellet counter; the weapon's payment/timing stays unchanged.
action("action_shoot_pellets",function(class)
    once(class,"_process_hits",function(fn,self,...)
        local count=count_for(self)
        if count==1 then return fn(self,...) end
        local previous=pellet_context
        pellet_context={count=count,unit=self._player_unit}
        local result=pack(pcall(fn,self,...));pellet_context=previous
        if not result[1] then error(result[2],0) end
        return unpack(result,2,result.n)
    end)
    -- Native shells apply status stacks after resolved damage, through this
    -- separate function; each copied shell retains the native stack ceiling.
    once(class,"_add_shotshell_buff",repeat_native)
end)
mod:hook_require("scripts/utilities/action/ranged_action",function(ranged)
    once(ranged,"execute_attack",function(fn,...)
        local context=pellet_context
        if not context or primitive_depth>0 or select(2,...)~=context.unit then return fn(...) end
        local args=pack(...);local proc=args[19];local original_proc=type(proc)=="table" and shallow(proc)
        local result,total,weakspot
        primitive_depth=primitive_depth+1
        local ok,err=pcall(function()
            for i=1,context.count do
                if i>1 and original_proc then args[19]=shallow(original_proc) end
                local values=pack(fn(unpack(args,1,args.n)))
                result=result or values;total=(total or 0)+(values[1] or 0);weakspot=weakspot or values[4]
                if values[2]=="died" then result[2]=values[2] end
            end
        end)
        primitive_depth=primitive_depth-1
        if not ok then error(err,0) end
        result[1]=total;result[4]=weakspot
        return unpack(result,1,result.n)
    end)
end)
mod:hook_require("scripts/utilities/attack/explosion",function(explosion)
    once(explosion,"create_explosion",function(fn,...)
        local context=pellet_context
        if not context or primitive_depth>0 or select(5,...)~=context.unit then return fn(...) end
        local args=pack(...);local result
        primitive_depth=primitive_depth+1
        local ok,err=pcall(function()
            for i=1,context.count do local values=pack(fn(unpack(args,1,args.n)));result=result or values end
        end)
        primitive_depth=primitive_depth-1
        if not ok then error(err,0) end
        return unpack(result,1,result.n)
    end)
end)
return Salvo
