-- Shared page model. Native views own widgets, focus, scaling and navigation.
local U={}
local function status_pages(text,line_width)
    local pages,lines,part={},{},{};local used=0
    local function flush_line()
        lines[#lines+1]=table.concat(part);part={};used=0
        if #lines==3 then pages[#pages+1]=table.concat(lines,"\n");lines={} end
    end
    for c in text:gmatch("[%z\1-\127\194-\244][\128-\191]*")do
        local width=(#c>1 or c:match("[MWmw@%%&]")) and 2 or 1
        if c=="\n" then flush_line()
        else
            if used+width>(line_width or 52) then flush_line() end
            part[#part+1]=c;used=used+width
        end
    end
    if #part>0 then flush_line() end
    if #lines>0 then pages[#pages+1]=table.concat(lines,"\n") end
    if #pages==0 then pages[1]="" end
    return pages
end
function U.build(ui,view,mod,library,Schema,Engine,examples,status)
    local function loc(key) return mod:localize("diy_"..key) end
    local function change(fn) return function(...) if not mod:is_enabled() then return end;fn(...);view._hcm_refresh=true;view._diy_revision=nil end end
    local doc,options=library.document,library.options
    local language=loc("language")
    local title=Schema.localize(doc.name,language)
    if view._diy_packages then
        ui:button("diy_back",105,219,220,48,loc("back_entries"),change(function()view._diy_packages=nil end))
        ui:text("diy_package_title",349,221,1446,48,loc("library_settings"),28)
        ui:text("diy_package_help",105,285,1690,68,loc("help"),21,"muted")
        local file=library.files[library.selected_file]
        ui:button("diy_file",105,371,1078,50,file and (library.selected_file.."/"..#library.files.."  "..file.."  ›") or loc("no_files"),file and change(function()library.selected_file=library.selected_file%#library.files+1 end))
        ui:button("diy_scan",1199,371,290,50,loc("scan"),change(library.scan))
        ui:button("diy_import",1505,371,290,50,loc(file and library.package_disabled(file) and "package_enable" or "package_disable"),file and change(function()library.toggle_package(file)end))
        local buttons={{"paste",function()
            local raw=Clipboard and Clipboard.get and Clipboard.get()
            if type(raw)=="string" then library.import_text(raw,"clipboard") else library.last_error="diy_no_clipboard" end
        end},{"example",function()library.export("starter-"..library.kind..".json",examples[library.kind])end},
        {"export",function()library.export(doc.id.."-export.json")end},{"directory",library.copy_directory}}
        for i,b in ipairs(buttons)do ui:button("diy_"..b[1],105+(i-1)*427,443,411,50,loc(b[1]=="directory" and "copy_dir" or b[1]),change(b[2]))end
        local summary,issue=library.status_message();local message=library.last_error or library.last_message
        if message then summary=summary.."\n"..(library.format_message and library.format_message(message) or mod:localize(message))end
        if view._diy_status_text~=summary then view._diy_status_text=summary;view._diy_status_page=1 end
        local chunks=status_pages(summary,140);local page=math.min(view._diy_status_page or 1,#chunks)
        ui:text("diy_status",105,555,1500,110,chunks[page],19,(library.last_error or issue) and "danger" or "muted")
        if #chunks>1 then ui:button("diy_status_more",1621,589,174,46,loc("next"),change(function()view._diy_status_page=page%#chunks+1 end))end
        return
    end
    ui:text("diy_title",105,219,1078,42,title.."  ·  "..#doc.entries,28)
    ui:checkbox("diy_enabled",1515,218,280,48,loc(options.enabled and "disable" or "enable"),change(function()
        library.set_options({enabled=not options.enabled}) end),options.enabled)
    ui:button("diy_packages",1200,218,299,48,loc("library_settings"),change(function()view._diy_packages=true end))
    if library.kind~="conditions" then
    ui:button("diy_mode",105,282,270,48,loc(options.mode=="random" and "random" or "manual"),change(function()
        library.set_options({mode=options.mode=="random" and "manual" or "random"}) end))
    ui:button("diy_seed",391,282,510,48,loc("seed")..options.seed,change(library.paste_seed))
    local can_edit=library.can_edit();local function maximum(value)library.set_options({max_total=value})end
    if ui.stepper then
        ui:stepper("diy_maximum",917,282,878,loc("total"),options.max_total,can_edit and change(function(delta)maximum(math.max(0,math.min(99,options.max_total+delta)))end),nil,
            can_edit and {label=loc("total"),value=options.max_total,min=0,max=99,integer=true,set=change(maximum)})
    else
        ui:button("diy_maximum_minus",917,282,90,48,"−",can_edit and options.max_total>0 and change(function()maximum(options.max_total-1)end))
        ui:text("diy_maximum",1023,282,666,48,loc("total")..options.max_total,22)
        ui:button("diy_maximum_plus",1705,282,90,48,"+",can_edit and options.max_total<99 and change(function()maximum(options.max_total+1)end))
    end
    else
        ui:text("diy_selection_intro",105,282,1690,64,loc("conditions_selection_help"),22,"muted")
    end
    ui:text("diy_tier_label_help",105,350,1690,44,loc(library.kind=="conditions" and "conditions_tier_help" or "tier_label_help"),20,"muted")
    local picked={};for _,id in ipairs(options.selected) do picked[id]=true end
    local page=math.max(1,math.min(view._diy_page or 1,math.max(1,math.ceil(#doc.entries/8))));view._diy_page=page
    local start=(page-1)*8
    local shown
    for i=1,math.min(8,#doc.entries-start) do
        local entry=doc.entries[start+i]
        if view._diy_entry==entry.id then shown=entry end
        local eligible,reason=library.eligible(entry)
        local row=ui:checkbox("diy_entry_"..i,105,414+(i-1)*56,850,48,(eligible and "" or "×  ").."["..entry.tier.."] "..Schema.localize(entry.name,language),change(function()
            view._diy_entry=entry.id;library.toggle(entry.id)
        end),picked[entry.id],entry.id)
        row.on_hover=function()
            if mod:is_enabled() and view._diy_entry~=entry.id then
                view._diy_entry=entry.id;view._hcm_refresh=true;view._diy_revision=nil
            end
        end
        if reason=="diy_host_banned" then row.action=nil;row.text=row.text..loc("host_banned_suffix") end
    end
    if not shown then for _,entry in ipairs(doc.entries) do if view._diy_entry==entry.id then shown=entry;break end end end
    shown=shown or doc.entries[start+1]
    if #doc.entries==0 then ui:text("diy_empty",125,435,790,220,loc("empty"),24,"muted") end
    ui:button("diy_prev",105,878,120,44,"‹",page>1 and change(function() view._diy_page=page-1 end))
    ui:text("diy_page",240,878,200,44,page.." / "..math.max(1,math.ceil(#doc.entries/8)),22)
    ui:button("diy_next",435,878,120,44,"›",start+8<#doc.entries and change(function() view._diy_page=page+1 end))
    ui:button("diy_clear",571,878,184,44,loc("clear"),change(function() library.set_options({selected={}}) end))
    ui:text("diy_detail_title",1005,414,780,65,shown and Schema.localize(shown.name,language) or loc("details"),28,"gold")
    local lines={}
    if shown then
        local source=library.entry_sources and library.entry_sources[shown.id]
        lines[#lines+1]=(source and (source.package_id.." / "..source.entry_id) or shown.id).."  ·  "..loc("rules")..#shown.rules..(library.kind~="conditions" and ("  ·  "..loc("weight")..shown.weight) or "")
        lines[#lines+1]=Schema.localize(shown.description,language)
        local allowed,reason=library.eligible(shown)
        if not allowed then lines[#lines+1]=mod:localize(reason or "diy_incompatible") end
        if shown.passive then
            local keys={};for key in pairs(shown.passive.stats or {}) do keys[#keys+1]=key end;table.sort(keys)
            for i,key in ipairs(keys) do if i<=10 then lines[#lines+1]=key.." = "..shown.passive.stats[key] end end
            if #keys>10 then lines[#lines+1]="… +"..(#keys-10) end
        end
    end
    ui:text("diy_detail",1005,488,780,288,table.concat(lines,"\n"),19,"muted")
    local selected=Engine.choose(doc,options,options.seed,library.eligible)
    ui:text("diy_preview",1005,784,780,70,library.kind=="conditions" and mod:localize("diy_conditions_count",#selected) or loc("preview")..#selected.." / "..options.max_total,20)
    local package_status,package_error=library.status_message()
    local message=library.last_error
    if not message and options.enabled then
        local chosen={};for _,id in ipairs(selected) do chosen[id]=true end
        for _,entry in ipairs(doc.entries) do if chosen[entry.id] then
            for _,rule in ipairs(entry.rules) do for _,action in ipairs(rule.actions) do
                if action.type=="spawn_enemy" or action.type=="spawn_formation" then
                    local hed=get_mod("HavocEnemyDirector")
                    if not hed or not hed.diy_api or hed.diy_api.version~=1 then message="diy_need_hed" end
                elseif action.type=="pause_spawns" and action.name~="hed" and library.kind=="mortis" then
                    local hcm=get_mod("HavocConditionManager")
                    if not hcm or not hcm.diy_api then message="diy_need_hcm" end
                end
            end end
        end end
    end
    if not message then message=library.last_message end
    if message and library.format_message then message=library.format_message(message)
    elseif message and message:match("^diy_") then message=mod:localize(message) end
    local status_text=message and (package_status.."\n"..message) or package_status
    if view._diy_status_text~=status_text then view._diy_status_text=status_text;view._diy_status_page=1 end
    local chunks=status_pages(status_text)
    local page=(view._diy_status_page or 1);if page>#chunks then page=1 end
    ui:text("diy_status",1005,854,650,68,chunks[page] or "",18,(message or package_error) and "danger" or "muted")
    if #chunks>1 then ui:button("diy_status_more",1663,878,132,44,"›",change(function()view._diy_status_page=page%#chunks+1 end))end
    ui:text("diy_help",105,934,1690,42,loc("selection_help"),18,"muted")
end
return U
