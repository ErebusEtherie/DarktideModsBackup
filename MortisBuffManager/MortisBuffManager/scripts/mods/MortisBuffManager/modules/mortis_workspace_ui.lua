-- One scrollable talent list with explicit pool, DIY and saved-selection filters.
local U={}
-- The check used by native Proxima Nova UI (EndView's ready indicator).
local selected_marker="\238\128\129  "
local function shortened(text,width)
    local chars,used={},0
    for c in text:gmatch("[%z\1-\127\194-\244][\128-\191]*")do
        used=used+(#c>1 and 2 or 1)
        if used>(width or 60) then return table.concat(chars).."…" end
        chars[#chars+1]=c
    end
    return text
end
local function text_pages(text,width,lines)
    local tokens,word={},{}
    local function flush_word()
        if #word>0 then tokens[#tokens+1]=table.concat(word);word={}end
    end
    for c in tostring(text):gmatch("[%z\1-\127\194-\244][\128-\191]*")do
        if #c==1 and not c:match("%s")then word[#word+1]=c
        else flush_word();tokens[#tokens+1]=c end
    end
    flush_word()
    local pages,part={},{};local used,line=0,1
    for _,token in ipairs(tokens)do
        local n=token:byte()>127 and 2 or #token
        if token=="\n" or used+n>width and used>0 then
            line=line+1;used=0
            if line>lines then pages[#pages+1]=table.concat(part);part={};line=1 end
        end
        if token=="\n" then
            if #part>0 then part[#part+1]=token end
        elseif token:match("^%s+$")then
            if #part>0 then part[#part+1]=token end
            if used>0 then used=used+n end
        else
            part[#part+1]=token;used=used+n
        end
    end
    pages[#pages+1]=table.concat(part);return pages
end
function U.build(ui,view,mod,Model,library,Examples)
    local function loc(key,...)return mod:localize("diy_"..key,...)end
    local function action(fn)return function()if mod:is_enabled() then fn();view._diy_revision=nil end end end
    local snapshot=Model.snapshot();if not snapshot then ui:text("waiting",105,230,1690,80,loc("policy_pending"),26);return end
    local rules=snapshot.rules
    local limits=rules.diy_limits or library.options
    local function configure(mode,native,diy,limit)
        return Model.rules(mode or rules.mode,limit or rules.limit,native==nil and rules.native_enabled or native,diy==nil and rules.diy_enabled or diy)
    end
    local function integer(maximum,callback,value)
        view._workspace_number={maximum=maximum,callback=callback,text=tostring(value or 0),replace=true,mode=rules.mode,revision=rules.revision}
        view._workspace_searching=nil;view.is_text_input_focused=true
    end
    if view._workspace_subpage=="library" then
        ui:button("back",105,219,220,48,loc("back_catalog"),action(function()view._workspace_subpage=nil end))
        ui:text("library_title",349,221,1446,48,loc("library_settings"),28)
        ui:text("library_help",105,285,1690,68,loc("library_explanation"),21,"muted")
        local file=library.files[library.selected_file]
        ui:button("library_file",105,371,1078,50,file or loc("no_files"),#library.files>0 and action(function()library.selected_file=library.selected_file%#library.files+1 end))
        ui:button("library_scan",1199,371,290,50,loc("scan"),action(library.scan))
        ui:button("library_load",1505,371,290,50,loc(file and library.package_disabled(file) and "package_enable" or "package_disable"),file and action(function()library.toggle_package(file)end))
        local buttons={
            {"paste",function()local raw=Clipboard and Clipboard.get and Clipboard.get();if type(raw)=="string" then library.import_text(raw,"clipboard")end end,true},
            {"example",function()library.export("starter-mortis.json",Examples.mortis)end,true},
            {"export",function()library.export(library.document.id.."-export.json")end,true},
            {"copy_dir",library.copy_directory,true},
        }
        for i,b in ipairs(buttons)do ui:button("library_"..b[1],105+(i-1)*427,443,411,50,loc(b[1]),b[3] and action(b[2]))end
        local package_status,package_error=library.status_message()
        local message=library.last_error or view._workspace_message or library.last_message
        if view._workspace_number then message=loc("number_typing",view._workspace_number.text,view._workspace_number.maximum)end
        if message and library.format_message then message=library.format_message(message)
        elseif message and message:match("^diy_") then message=mod:localize(message)end
        local status_text=message and (package_status.."\n"..message) or package_status
        if view._package_status_text~=status_text then view._package_status_text=status_text;view._package_status_page=1 end
        local pages=text_pages(status_text,140,3)
        ui:text("library_status",105,555,1500,110,pages[view._package_status_page or 1] or pages[1],19,(library.last_error or package_error) and "danger" or "muted")
        if #pages>1 then ui:button("package_status_more",1621,589,174,46,loc("next"),action(function()view._package_status_page=(view._package_status_page or 1)%#pages+1 end))end
        return
    elseif view._workspace_subpage=="rules" then
        ui:button("back",105,219,220,48,loc("back_catalog"),action(function()view._workspace_subpage=nil;view._workspace_number=nil;view.is_text_input_focused=false end))
        ui:text("reward_settings_title",349,221,1446,48,loc("reward_settings"),28)
        ui:text("reward_settings_help",105,285,1690,100,loc("reward_settings_help"),21,"muted")
        local function stepper(key,y,label,value,maximum,enabled,set)
            ui:text(key.."_label",105,y,660,52,label,25,"gold")
            ui:button(key.."_minus",799,y,96,52,"−",enabled and value>0 and action(function()set(value-1)end))
            ui:button(key,911,y,150,52,tostring(value),enabled and action(function()integer(maximum,set,value)end))
            ui:button(key.."_plus",1077,y,96,52,"+",enabled and value<maximum and action(function()set(value+1)end))
        end
        stepper("native_limit",423,mod:localize("mortis_limit_"..rules.mode),rules.limit,99,snapshot.editable and rules.mode~="draft",function(n)configure(nil,nil,nil,n)end)
        stepper("diy_limit",519,loc("points_limit"),limits.max_total,99,snapshot.editable,function(n)Model.diy_rules(n,rules.diy_enabled)end)
        ui:text("tier_label_help",105,617,1690,80,loc("tier_label_help"),21,"muted")
        local edit=view._workspace_number
        ui:text("reward_settings_status",105,725,1690,88,edit and loc("number_typing",edit.text,edit.maximum) or view._workspace_message or loc(snapshot.editable and "points_help" or "settings_locked"),20,"muted")
        return
    elseif view._workspace_subpage=="family" then
        ui:button("back",105,219,220,48,loc("back_catalog"),action(function()view._workspace_subpage=nil end))
        ui:text("family_title",349,221,1446,48,loc("choose_family"),28)
        ui:text("family_help",105,285,1690,68,loc("family_explanation"),21,"muted")
        for i,name in ipairs(mod.mortis_family_names)do
            local data=mod.mortis_choice_ui_data(name,"family")
            local y=370+(i-1)*76
            ui:button("family_"..name,105,y,510,58,data.display_name,snapshot.selection_editable and action(function()
                local ok,reason,removed=Model.family(name)
                if ok or reason=="unchanged" then
                    view._workspace_subpage=nil;view._workspace_detail=nil;view._workspace_scroll_index=0;view._workspace_scroll_reset=true
                    view._workspace_message=removed and removed>0 and loc("family_pruned",removed) or nil
                else view._workspace_message=mod:localize(reason=="storage" and "mortis_selection_storage_error" or reason and reason:match("^diy_") and reason or "mortis_selection_unknown")end
            end),name==snapshot.family)
            ui:text("family_description_"..name,647,y,1148,64,data.description,18,"muted")
        end
        if view._workspace_message then ui:text("family_status",105,937,1690,60,view._workspace_message,21,"muted")end
        return
    end
    ui:text("workspace_title",105,219,1150,46,loc("workspace_title"),30)
    ui:text("workspace_role",1271,229,524,34,loc(snapshot.editable and "room_editing" or "room_browsing"),20,"muted")
    ui:checkbox("native_pool",105,285,276,52,loc("policy_native"),snapshot.editable and action(function()configure(nil,not rules.native_enabled)end),rules.native_enabled)
    ui:checkbox("diy_pool",397,285,276,52,loc("policy_diy"),snapshot.editable and action(function()configure(nil,nil,not rules.diy_enabled)end),rules.diy_enabled)
    for i,mode in ipairs({"preselect","draft","competition"})do
        ui:button("mode_"..mode,711+(i-1)*222,285,206,52,mod:localize("mortis_mode_"..mode),snapshot.editable and action(function()configure(mode)end),rules.mode==mode)
    end
    ui:button("library_settings",1415,285,380,52,loc("library_settings"),action(function()view._workspace_subpage="library"end))
    local summary
    if snapshot.preselect then summary=loc("preselection_summary",snapshot.native_count,snapshot.limit,snapshot.diy_count,limits.max_total)
    else summary=loc("mode_summary",rules.limit) end
    ui:text("mode_summary",105,352,1280,42,view._workspace_message or summary,21,view._workspace_message and "danger" or "muted")
    ui:button("reward_settings",1415,352,380,42,loc("reward_settings"),action(function()view._workspace_subpage="rules"end))
    local can_batch=snapshot.selection_editable or snapshot.editable
    local bulk=view._workspace_bulk and can_batch
    local filter=view._workspace_filter or "available"
    local category=view._workspace_category or "all"
    -- Old open-page state may still contain the removed all/native tabs.
    -- Do not let the model's compatibility API expose those legacy views.
    if filter~="available" and filter~="diy" and filter~="selected" and filter~="unavailable" then filter="available" end
    if category~="all" and category~="generic" and category~="class" and category~="family" then category="all" end
    view._workspace_filter,view._workspace_category=filter,category
    local search=view._workspace_search or ""
    local rows,counts,category_counts=Model.browse(snapshot,{source=filter,category=category,search=search})
    local function reset_scroll()
        view._workspace_scroll_index=0;view._workspace_scroll_reset=true;view._workspace_detail=nil
    end
    local signature=filter.."/"..category.."/"..search.."/"..tostring(snapshot.family)
    if view._workspace_filter_signature~=signature then reset_scroll();view._workspace_filter_signature=signature end
    for i,kind in ipairs({"available","diy","selected","unavailable"})do
        local key=kind=="selected" and "chosen_tab" or "filter_"..kind
        ui:button("filter_"..kind,105+(i-1)*256,405,238,46,loc(key).." ("..counts[kind]..")",action(function()
            view._workspace_filter=kind
            if kind=="selected" then view._workspace_search=nil end
            if kind=="selected" or kind=="diy" then view._workspace_category="all" end
            view._workspace_searching=nil;view.is_text_input_focused=false;reset_scroll()
        end),filter==kind)
    end
    for i,kind in ipairs({"all","generic","class","family"})do
        ui:button("category_"..kind,105+(i-1)*160,463,148,38,loc("category_"..kind).." ("..category_counts[kind]..")",action(function()
            view._workspace_category=kind;reset_scroll()
        end),category==kind)
    end
    ui:button("choose_family",755,463,360,38,loc("family_prefix")..mod:localize("mortis_talent_ui_family_"..tostring(snapshot.family)),
        snapshot.selection_editable and action(function()view._workspace_subpage="family"end))
    ui:button("search",105,519,596,42,loc("search_input")..shortened(search,38)..(view._workspace_searching and " |" or ""),action(function()
        view._workspace_searching=true;view.is_text_input_focused=true
    end))
    ui:button("search_clear",717,519,190,42,loc("policy_clear_search"),action(function()
        view._workspace_search=nil;view._workspace_searching=nil;view.is_text_input_focused=false;reset_scroll()
    end))
    if can_batch then ui:button("batch",923,519,192,42,loc(bulk and "batch_done" or "batch"),action(function()
        view._workspace_bulk=not view._workspace_bulk;view._workspace_marked={};view._workspace_batch_result=nil
        view._workspace_batch_target=snapshot.selection_editable and "preselection" or "pool"
    end),bulk)end
    local visible=7
    local offset=math.max(0,math.min(view._workspace_scroll_index or 0,math.max(0,#rows-visible)))
    view._workspace_scroll_index=offset
    view._workspace_visible_rows=math.min(visible,#rows)
    local shown
    for _,row in ipairs(rows)do if row.key==view._workspace_detail then shown=row;break end end
    shown=shown or rows[offset+1]
    if shown then view._workspace_detail=shown.key end
    local marked=view._workspace_marked or {};view._workspace_marked=marked
    local target=view._workspace_batch_target or "preselection"
    local function inspect(row)
        if view._workspace_detail~=row.key then
            view._workspace_detail=row.key;view._workspace_detail_scroll_index=0;view._workspace_detail_scroll_reset=true
        end
    end
    local function toggle(row)
        view._workspace_message=nil
        local ok,reason=Model.select(row)
        if not ok then view._workspace_message=reason and mod:localize("mortis_selection_"..reason) or loc("selection_full")end
    end
    for i=1,math.min(visible,#rows-offset)do
        local row=rows[offset+i]
        local selected=snapshot.preselect and row.selected or not snapshot.preselect and row.acquired
        local label=(selected and selected_marker or "").."["..loc("source_"..row.source).."] "..shortened(row.name,76)
        local select_row=action(function()inspect(row)end)
        if snapshot.preselect and not bulk and snapshot.selection_editable and (row.selected or row.available)then
            select_row=action(function()inspect(row);toggle(row)end)
        end
        if bulk then
            label=(marked[row.key] and selected_marker or "").."["..loc("source_"..row.source).."] "..shortened(row.name,76)
            selected=marked[row.key]
            select_row=(target~="pool" or row.source=="diy") and action(function()marked[row.key]=not marked[row.key] or nil end)
        end
        local item=ui:button("skill_"..i,105,575+(i-1)*54,986,46,label,select_row,selected)
        item.on_hover=function()if view._workspace_detail~=row.key then inspect(row);view._diy_revision=nil end end
        item.muted=not row.available or bulk and target=="pool" and row.source=="native";item.font=20;item.row=true
    end
    ui:scrollbar("talent_scrollbar",1103,575,12,378,#rows,visible,offset)
    if #rows==0 then ui:text("catalog_empty",123,603,950,130,loc(filter=="selected" and "chosen_empty" or "policy_empty"),23,"muted")end
    if bulk then
        ui:button("batch_select_all",105,959,684,38,loc("select_filtered"),action(function()
            for _,row in ipairs(rows)do if target~="pool" or row.source=="diy" then marked[row.key]=true end end
        end))
        ui:button("batch_clear",805,959,310,38,loc("clear_marked"),action(function()view._workspace_marked={}end))
    else
        local text=loc("scroll_summary",#rows>0 and offset+1 or 0,math.min(offset+visible,#rows),#rows)
        ui:text("scroll_summary",105,963,800,30,text,19,"muted")
        if filter=="selected" and snapshot.preselect then
            ui:button("clear_selection",923,959,192,38,loc("clear_selection"),snapshot.selection_editable and counts.selected>0 and action(function()
                local keys={};for _,row in ipairs(snapshot.rows)do if row.selected then keys[row.key]=true end end
                local changed,skipped=Model.batch(keys,"preselection",false)
                view._workspace_message=skipped>0 and loc("batch_result",changed,skipped) or nil
            end))
        end
    end
    local dx,dw=1155,640
    if bulk then
        local count=0;for _ in pairs(marked)do count=count+1 end
        ui:text("batch_title",dx,405,dw,76,loc("batch_title",count),29,"gold")
        ui:text("batch_help",dx,499,dw,144,loc("batch_help"),21,"muted")
        if snapshot.selection_editable then ui:button("batch_target_preselection",dx,659,310,52,loc("batch_preselection"),action(function()
            view._workspace_batch_target="preselection";view._workspace_marked={}
        end),target=="preselection")end
        if snapshot.editable then ui:button("batch_target_pool",1481,659,314,52,loc("batch_diy_pool"),action(function()
            view._workspace_batch_target="pool";view._workspace_marked={}
        end),target=="pool")end
        ui:button("batch_add",dx,759,310,54,loc(target=="pool" and "batch_allow" or "batch_add"),count>0 and action(function()
            local changed,skipped=Model.batch(marked,target,true);view._workspace_batch_result=loc("batch_result",changed,skipped)
        end))
        ui:button("batch_remove",1481,759,314,54,loc(target=="pool" and "batch_disable" or "batch_remove"),count>0 and action(function()
            local changed,skipped=Model.batch(marked,target,false);view._workspace_batch_result=loc("batch_result",changed,skipped)
        end))
        ui:text("batch_result",dx,849,dw,130,view._workspace_batch_result or loc(target=="pool" and "native_whole_only" or "batch_preselection_help"),21,"muted")
        return
    end
    if not shown then ui:text("empty",dx,421,dw,170,loc("policy_empty"),26,"muted");return end
    ui:text("detail_title",dx,405,dw,84,shown.name,27,"gold")
    local state=shown.reason and mod:localize(shown.reason) or loc(shown.available and "in_pool" or "not_in_pool")
    ui:text("detail_state",dx,499,dw,66,state,20,shown.available and "text" or "danger")
    local details=Model.description(shown)
    local weight_info=shown.source=="diy" and loc("weight")..shown.weight.."  ·  "..loc("tier")..shown.tier or loc("native_weight")
    details=details.."\n\n"..weight_info
    for _,peer in ipairs(shown.missing)do
        details=details.."\n"..peer.name.." — "..loc(peer.reason=="missing" and "peer_missing_entry" or "peer_"..peer.reason)
    end
    local lines=ui.wrap and ui:wrap(details,dw-42,21) or text_pages(details,52,1)
    local dvisible=10
    if view._workspace_detail_text~=details then
        view._workspace_detail_text=details;view._workspace_detail_scroll_index=0;view._workspace_detail_scroll_reset=true
    end
    local doffset=math.max(0,math.min(view._workspace_detail_scroll_index or 0,math.max(0,#lines-dvisible)))
    view._workspace_detail_scroll_index=doffset
    ui:text("detail_description",dx,575,dw-30,294,table.concat(lines,"\n",doffset+1,math.min(doffset+dvisible,#lines)),21,"text")
    ui:scrollbar("detail_scrollbar",1783,575,12,294,#lines,dvisible,doffset)
    if snapshot.preselect then
        ui:button("select_skill",dx,880,dw,50,loc(shown.selected and "remove_preselection" or "add_preselection"),
            snapshot.selection_editable and (shown.selected or shown.available) and action(function()toggle(shown)end),shown.selected)
    else
        ui:text("reward_state",dx,886,dw,52,loc(shown.acquired and "already_acquired" or "reward_candidate"),21,"muted")
    end
    if shown.source=="diy" and snapshot.editable then
        ui:button("host_permission",dx,944,dw,50,loc(shown.host_banned and "allow_room" or "disable_room"),
            (not shown.host_banned or #shown.missing==0) and action(function()Model.toggle_host(shown)end))
    else
        ui:text("detail_footer",dx,944,dw,50,loc(snapshot.selection_editable and "preselect_hint" or "selection_locked"),18,"muted")
    end
end
return U
