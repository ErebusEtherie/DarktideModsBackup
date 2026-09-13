-- Build eligibility is evaluated before selection, independently of combat
-- conditions such as low health. The host always uses its own player data.
local Q={version=1}
Q.resources={ammo=true,reload=true,overheat=true,warp_charge=true,grenade_charges=true,combat_ability=true,melee=true,ranged=true}
local function selected(v) return v==true or type(v)=="number" and v>0 end
local function contains(list,value)
    if not list or #list==0 then return true end
    for _,v in ipairs(list) do if v==value then return true end end;return false
end
local function any(list,set)
    if not list or #list==0 then return true end
    for _,v in ipairs(list) do if set[v] then return true end end;return false
end
local weapon_metadata=setmetatable({},{__mode="k"})
local function weapon_resources(template)
    local hud=template.hud_configuration or {}
    local cached=weapon_metadata[template]
    -- Native action/keyword tables are static template data. Equipment swaps
    -- and replacement template tables get their own classification.
    if cached and cached.actions==template.actions and cached.keywords==template.keywords
        and cached.ammo==(hud.uses_ammunition==true) and cached.overheat==(type(template.overheat_configuration)=="table") then
        return cached.tags,cached.resources
    end
    local tags={};for _,tag in ipairs(template.keywords or {}) do tags[tag]=true end
    local r={ammo=hud.uses_ammunition==true,overheat=type(template.overheat_configuration)=="table",melee=tags.melee==true,ranged=tags.ranged==true}
    for _,a in pairs(template.actions or {}) do
        if a.kind=="reload_state" or a.kind=="reload_shotgun" or a.kind=="ranged_load_special" then r.reload=true;break end
    end
    weapon_metadata[template]={actions=template.actions,keywords=template.keywords,ammo=r.ammo,overheat=r.overheat,tags=tags,resources=r}
    return tags,r
end
function Q.capture(player,family,resolve_weapon,prefer_profile)
    local profile=player and player.profile and player:profile()
    local out={ready=type(profile)=="table",family=family,talents={},weapons={},weapon_keywords={},resources={},weapon_slots={}}
    if not out.ready then return out end
    local archetype=profile.archetype or {}
    out.archetype=player.archetype_name and player:archetype_name() or archetype.name
    local records={};local ambiguous={}
    local function inspect(talents,base)
        local names={};for name,value in pairs(talents or {}) do if selected(value) then names[#names+1]=name;out.talents[name]=true end end
        table.sort(names)
        for _,name in ipairs(names) do
            local talent=archetype.talents and archetype.talents[name];local pa=talent and talent.player_ability
            if pa and pa.ability then
                local kind=pa.ability_type
                if not records[kind] then records[kind]=pa.ability
                elseif not base and records[kind].name~=pa.ability.name then
                    local a,b=records[kind],pa.ability
                    -- Upgrades in one native ability group have the same pool.
                    if not a.ability_group or a.ability_group~=b.ability_group then ambiguous[kind]=true end
                end
            end
        end
    end
    local unit=player.player_unit
    local alive=unit and ALIVE and ALIVE[unit]
    local ability=alive and ScriptUnit.has_extension(unit,"ability_system")
    if ability and not prefer_profile then
        -- The native extension has already resolved talent upgrades and the
        -- equipped abilities. Retain talent membership without resolving them again.
        for name,value in pairs(profile.talents or {}) do if selected(value) then out.talents[name]=true end end
        for name,value in pairs(archetype.base_talents or {}) do if selected(value) then out.talents[name]=true end end
        local equipped=ability:equipped_abilities() or {}
        for _,kind in ipairs({"grenade_ability","combat_ability"}) do
            records[kind]=equipped[kind];ambiguous[kind]=nil
        end
    elseif archetype.talent_layout_file_path then
        -- Native profiles can contain both the base Blitz and its replacement.
        -- CharacterSheet resolves upgrades by tree depth, including variants
        -- without an ability_group; treating them as conflicts drops their pool.
        for name,value in pairs(profile.talents or {}) do if selected(value) then out.talents[name]=value end end
        local loadout={}
        require("scripts/utilities/character_sheet").class_loadout(profile,loadout,false,out.talents,true)
        records.grenade_ability,records.combat_ability=loadout.grenade_ability,loadout.combat_ability
        for name,value in pairs(archetype.base_talents or {}) do if selected(value) then out.talents[name]=true end end
    else inspect(profile.talents,false);inspect(archetype.base_talents,true) end
    for kind in pairs(ambiguous) do records[kind]=nil end
    local grenade,combat=records.grenade_ability,records.combat_ability
    out.grenade_ability=grenade and grenade.name
    out.combat_ability=combat and combat.ability_group
    out.resources.grenade_charges=grenade and (grenade.max_charges or 0)>0 or false
    out.resources.combat_ability=combat and (combat.cooldown or 0)>0 or false
    out.resources.warp_charge=type(archetype.warp_charge)=="table"
    local visual=alive and not prefer_profile and ScriptUnit.has_extension(unit,"visual_loadout_system")
    local data=alive and ScriptUnit.has_extension(unit,"unit_data_system")
    local breed=data and data.breed and data:breed()
    out.breed=breed and breed.name
    out.tags=breed and breed.tags or {player=true}
    for _,slot in ipairs({"slot_primary","slot_secondary"}) do
        local item=profile.loadout and profile.loadout[slot]
        local template=visual and visual.weapon_template_from_slot and visual:weapon_template_from_slot(slot)
        if not template and item and resolve_weapon then template=resolve_weapon(item) end
        if template then
            local name=template.name or item and (item.weapon_progression_template or item.weapon_template)
            if name then out.weapons[name]=true end
            local tags,r=weapon_resources(template)
            for tag in pairs(tags) do out.weapon_keywords[tag]=true end
            local slot_resources={};out.weapon_slots[slot]=slot_resources
            for key,value in pairs(r) do slot_resources[key]=value;if value then out.resources[key]=true end end
        end
    end
    out.complete=out.archetype~=nil and grenade~=nil and combat~=nil and out.weapon_slots.slot_primary~=nil and out.weapon_slots.slot_secondary~=nil
    return out
end
-- Only mechanics with an audited hard resource dependency are inferred.
-- Other custom weapon/ability dependencies must be declared in availability.
local stat_resources={ammo_reserve_capacity="ammo",ammo_clip_size="ammo",clip_size_modifier="ammo",
    reload_speed="reload",reload_decrease_movement_reduction="reload",extra_max_amount_of_grenades="grenade_charges",
    ability_cooldown_modifier="combat_ability",ability_cooldown_multiplier="combat_ability",
    combat_ability_cooldown_regen_modifier="combat_ability",overheat_amount="overheat",overheat_dissipation_multiplier="overheat",
    overheat_immediate_amount="overheat",overheat_immediate_amount_critical_strike="overheat",overheat_over_time_amount="overheat",
    warp_charge_amount="warp_charge",warp_charge_amount_smite="warp_charge",warp_charge_dissipation_multiplier="warp_charge",
    warp_charge_immediate_amount="warp_charge",warp_charge_over_time_amount="warp_charge"}
local keyword_resources={no_ammo_consumption="ammo",no_ammo_consumption_on_crits="ammo"}
local action_resources={ammo="ammo",grenades="grenade_charges",ability_cooldown="combat_ability",warp_charge="warp_charge",overheat="overheat"}
local function effect_requirements(e,out)
    for key in pairs(e and e.stats or {}) do if stat_resources[key] then out[stat_resources[key]]=true end end
    for _,key in ipairs(e and e.keywords or {}) do if keyword_resources[key] then out[keyword_resources[key]]=true end end
    local m=e and e.modifiers or {}
    if m.ammo_pickup_multiplier~=nil or m.ammo_pickup_failure_chance~=nil then out.ammo=true end
    if m.ranged_salvo_count and m.ranged_salvo_count>1 then out.ranged=true end
end
function Q.matches(entry,setup)
    if not setup or not setup.complete then return false,"diy_build_pending" end
    local a=entry.availability or {};local r=setup.resources
    if not contains(a.archetypes,setup.archetype) or not contains(entry.targets and entry.targets.archetypes,setup.archetype) then return false,"diy_need_archetype" end
    local target=entry.targets or {}
    if not contains(target.breeds,setup.breed) then return false,"diy_incompatible" end
    for _,tag in ipairs(target.tags or {}) do if not setup.tags[tag] then return false,"diy_incompatible" end end
    for _,tag in ipairs(target.exclude_tags or {}) do if setup.tags[tag] then return false,"diy_incompatible" end end
    if not contains(a.families,setup.family) then return false,"diy_need_family" end
    if not contains(a.grenade_abilities,setup.grenade_ability) then return false,"diy_need_blitz" end
    if not contains(a.combat_abilities,setup.combat_ability) then return false,"diy_need_ability" end
    if not any(a.weapons,setup.weapons) or not any(a.weapon_keywords,setup.weapon_keywords) then return false,"diy_need_weapon" end
    for _,id in ipairs(a.talents or {}) do if not setup.talents[id] then return false,"diy_need_talents" end end
    for _,key in ipairs(a.resources or {}) do if not r[key] then return false,"diy_need_"..key end end
    if not any(a.any_resources,r) then return false,"diy_need_resources" end
    local inferred={};effect_requirements(entry.passive,inferred)
    local alternatives={};for _,key in ipairs(a.any_resources or {}) do alternatives[key]=true end
    for _,rule in ipairs(entry.rules or {}) do for _,action in ipairs(rule.actions) do
        if not action.target or action.target=="self" then
            local resource=action_resources[action.type]
            if resource and not alternatives[resource] then inferred[resource]=true end
            if action.type=="effect" then effect_requirements(action.effects,inferred) end
        end
    end end
    for key in pairs(inferred) do if not r[key] then return false,"diy_need_"..key end end
    return true
end
return Q
