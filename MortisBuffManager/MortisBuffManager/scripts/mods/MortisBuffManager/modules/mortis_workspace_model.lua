local mod=get_mod("MortisBuffManager")
local path="MortisBuffManager/scripts/mods/MortisBuffManager/modules/diy/"
local S=mod:io_dofile(path.."diy_schema")
local Eligibility=mod:io_dofile(path.."diy_eligibility")
local Model={}
local function set(values) local result={};for _,id in ipairs(values or {})do result[id]=true end;return result end
function Model.snapshot()
    local player=Managers.player and Managers.player:local_player_safe(1)
    if not player then return nil end
    local rules=mod.mortis_rules()
    local pending=rules==nil
    rules=rules or {mode="preselect",limit=0,native_enabled=false,diy_enabled=false}
    local policy=mod.mortis_host_policy
    local native_valid,native_selected,family,limit=mod.mortis_inspect_native(player)
    local chosen=set(native_selected);local diy_chosen=set(mod.diy_library.options.selected)
    local acquired=set((mod.mortis_draft_snapshot() or {}).selected)
    local pool=rules.mode~="preselect" and mod.mortis_inspection_pool(player)
    local candidates={}
    if pool then
        for _,route in pairs(pool.routes)do for _,names in pairs(route)do for _,name in ipairs(names)do candidates[name]=true end end end
        for _,names in pairs(pool.legendary)do for _,name in ipairs(names)do candidates[name]=true end end
    end
    local result={rules=rules,pending=pending,rows={},family=family,limit=limit,
        editable=policy.editable(),preselect=rules.mode=="preselect",in_mission=not policy.editable() and not mod.session_context().is_realms_client,
        native_count=0,diy_count=0,player=player}
    local c=mod.session_context()
    -- Realms preparation can have no native game_mode yet. Use the same
    -- decision as the library instead of requiring an already-created hub.
    local preparing=mod.diy_library.can_edit()
    result.can_import=preparing==true and not rules.locked;result.selection_editable=result.preselect and preparing==true and not rules.locked
    for _,id in ipairs(mod.mortis_selectable_buffs)do
        local info=mod.mortis_buff_ui_data(id,false)
        local source=mod.mortis_native_sources and mod.mortis_native_sources[id] or {}
        local allowed,reason=policy.allowed("native",id)
        local compatible=native_valid[id]==true
        if chosen[id] and allowed then result.native_count=result.native_count+1 end
        result.rows[#result.rows+1]={id=id,key="native/"..id,source="native",name=info.display_name,compatible=compatible,selected=chosen[id],acquired=acquired[id],
            category=source.kind,families=source.families,family=source.families and #source.families==1 and source.families[1] or nil,
            archetype=source.archetype,archetypes=source.archetypes,requirement=source.requirement,in_build_catalog=compatible,
            allowed=allowed,host_banned=policy.current() and policy.current().native[id],missing={},
            available=rules.native_enabled and allowed and compatible and (result.preselect or candidates[id]) or false,
            reason=not rules.native_enabled and "diy_pool_closed" or reason or not compatible and "diy_incompatible" or nil,icon=info.icon,gradient=info.gradient}
    end
    local doc=mod.diy_library.document;local setup=mod.mortis_build_setup(player)
    local lang=mod:localize("diy_language")
    for _,entry in ipairs(doc.entries)do
        local allowed,reason=policy.allowed("diy",doc.id.."/"..entry.id)
        local compatible,compatibility_reason=Eligibility.matches(entry,setup)
        local missing=policy.missing(entry.id)
        local key=doc.id.."/"..entry.id;local current=policy.current()
        local availability=rules.diy_availability
        local host_key=(availability and availability.library or doc.id).."/"..entry.id
        local origin=mod.diy_library.entry_sources and mod.diy_library.entry_sources[entry.id]
        if diy_chosen[entry.id] and allowed and compatible then result.diy_count=result.diy_count+1 end
        result.rows[#result.rows+1]={id=entry.id,key="diy/"..entry.id,policy_key=key,source="diy",name=S.localize(entry.name,lang),description=S.localize(entry.description,lang),
            category="diy",in_build_catalog=compatible,
            package_id=origin and origin.package_id,original_id=origin and origin.entry_id,
            compatible=compatible,selected=diy_chosen[entry.id],acquired=acquired["diy::"..entry.id],allowed=allowed and entry.enabled,
            host_banned=current and current.diy[host_key],missing=missing,weight=entry.weight,tier=entry.tier,
            available=rules.diy_enabled and allowed and entry.enabled and compatible and (result.preselect or candidates["diy::"..entry.id]) or false,
            reason=not rules.diy_enabled and "diy_pool_closed" or not entry.enabled and "diy_entry_disabled" or reason or
                not compatible and compatibility_reason or not result.preselect and entry.weight==0 and "diy_zero_weight" or nil}
    end
    table.sort(result.rows,function(a,b)if a.name==b.name then return a.key<b.key end;return a.name<b.name end)
    return result
end
-- Browsing never changes the saved family or selections. DIY and saved choices
-- remain inspectable even when their build requirements or pool switches fail.
function Model.browse(snapshot,options)
    options=options or {}
    local source=options.source or (options.status and "all" or "available")
    local category=options.category or "all"
    local status=options.status
    local search=string.lower(options.search or "")
    local rows={}
    local counts={available=0,diy=0,selected=0,unavailable=0}
    local category_counts={all=0,generic=0,class=0,family=0}
    for _,row in ipairs(snapshot and snapshot.rows or {})do
        if row.selected then counts.selected=counts.selected+1 end
        local search_matches=search=="" or string.find(string.lower(row.name or ""),search,1,true)
            or string.find(string.lower(row.id or ""),search,1,true)
        local available=row.available==true
        local source_matches=source=="available" and available or source=="unavailable" and not available
            or source==row.source or source=="selected" and row.selected or source=="all"
        local category_matches=category=="all" or row.category==category
        if search_matches then
            if category_matches then
                local availability=available and "available" or "unavailable"
                counts[availability]=counts[availability]+1
                if row.source=="diy" then counts.diy=counts.diy+1 end
            end
            -- Retain explicit status filters for callers of the older model.
            local current=row.in_build_catalog
            if current==nil then current=row.compatible~=false end
            local status_matches=not status or status=="all" or status=="current" and (current or source=="selected")
                or status=="available" and available or status=="unavailable" and not available
            if status_matches and source_matches then
                category_counts.all=category_counts.all+1
                if category_counts[row.category]~=nil then category_counts[row.category]=category_counts[row.category]+1 end
                if category_matches then rows[#rows+1]=row end
            end
        end
    end
    return rows,counts,category_counts
end
function Model.select(row)
    local snapshot=Model.snapshot()
    if not snapshot or not snapshot.selection_editable then return false end
    for _,current in ipairs(snapshot.rows)do
        if current.key==row.key then
            -- A removal callback must never add a choice back after another
            -- control, a loadout switch or a room update has already removed it.
            if (current.selected==true)~=(row.selected==true) then return true end
            if not current.selected and not current.available then return false,"incompatible" end
            if current.source=="diy" then return mod.diy_library.toggle(current.id) end
            return mod.toggle_mortis_buff_from_talent_ui(snapshot.player,current.id)
        end
    end
    return false,"unknown"
end
function Model.toggle_host(row)
    if row.source~="diy" then return false end
    return mod.mortis_host_policy.set(row.source,row.policy_key or row.id,row.host_banned==true)
end
function Model.batch(keys,target,add)
    local snapshot=Model.snapshot();if not snapshot then return 0,0 end
    local rows={};for _,row in ipairs(snapshot.rows)do if keys[row.key] then rows[#rows+1]=row end end
    if target=="pool" then
        local ids={};local skipped=0
        for _,row in ipairs(rows)do if row.source=="diy" then ids[#ids+1]=row.policy_key else skipped=skipped+1 end end
        local changed,rejected=mod.mortis_host_policy.set_many(ids,add);return changed,skipped+rejected
    end
    if not snapshot.selection_editable then return 0,#rows end
    local changed,skipped=0,0
    for _,row in ipairs(rows)do
        if (row.selected==true)~=add then
            local ok=Model.select(row)
            if ok then changed=changed+1 else skipped=skipped+1 end
        end
    end
    return changed,skipped
end
function Model.rules(mode,limit,native,diy) return mod.mortis_workspace_set_rules(mode,limit,native,diy) end
function Model.diy_rules(limit,enabled) return mod.mortis_workspace_set_diy_rules(limit,enabled) end
function Model.description(row)
    local text=row.description or mod.mortis_talent_ui_description(row.id)
    return row.package_id and (row.package_id.." / "..row.original_id.."\n"..text) or text
end
function Model.family(name)
    local before=Model.snapshot()
    if not before or not before.selection_editable then return false,"diy_edit_in_hub",0 end
    local ok,reason,removed=mod.set_mortis_family_from_talent_ui(before.player,name)
    if not ok then return ok,reason,removed end
    removed=tonumber(removed) or 0
    local current=Model.snapshot()
    if not current or not current.selection_editable then return false,"diy_edit_in_hub",removed end
    -- Native family selection already prunes incompatible native rewards.
    -- Recheck the new build to also remove unavailable DIY and closed-pool choices.
    for _,row in ipairs(current.rows)do
        if row.selected and not row.available then
            local removed_ok,remove_error=Model.select(row)
            if not removed_ok then return false,remove_error or "diy_edit_in_hub",removed end
            removed=removed+1
        end
    end
    return true,reason,removed
end
return Model
