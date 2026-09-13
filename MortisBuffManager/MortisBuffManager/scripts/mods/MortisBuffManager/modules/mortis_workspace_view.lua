local mod=get_mod("MortisBuffManager")
if mod._mortis_catalog_class then return mod._mortis_catalog_class end
local BaseView=require("scripts/ui/views/base_view")
local UIWidget=require("scripts/managers/ui/ui_widget")
local Buttons=require("scripts/ui/pass_templates/button_pass_templates")
local Scrollbars=require("scripts/ui/pass_templates/scrollbar_pass_templates")
local UIRenderer=require("scripts/managers/ui/ui_renderer")
local path="MortisBuffManager/scripts/mods/MortisBuffManager/modules/"
local U,Model=mod:io_dofile(path.."mortis_workspace_ui"),mod:io_dofile(path.."mortis_workspace_model")
local Examples=mod:io_dofile(path.."diy/diy_examples")
local Lifecycle=mod:io_dofile(path.."workspace_lifecycle")
local View=class("MBMWorkspaceMortisCatalogView","BaseView");mod._mortis_catalog_class=View
local colors={text={255,222,229,214},gold={255,221,194,122},muted={255,151,167,152},danger={255,220,133,117}}
local Definitions={scenegraph_definition={screen={size={1920,1080},scale="fit"},canvas={parent="screen",size={1920,1080},position={0,0,0}}},widget_definitions={}}
Definitions.widget_definitions.background=UIWidget.create_definition({
    {pass_type="rect",style_id="background",style={color={255,12,18,20}}},
},"screen")
for i=1,64 do
    for _,kind in ipairs({"text","button"})do
        local id="catalog_"..kind.."_"..i
        Definitions.scenegraph_definition[id]={parent="canvas",horizontal_alignment="left",vertical_alignment="top",size={100,48},position={0,0,3}}
        if kind=="button" then Definitions.widget_definitions[id]=UIWidget.create_definition(Buttons.terminal_button,id,{text="",original_text=""},nil,{text={font_size=20,character_spacing=.1}})
        else Definitions.widget_definitions[id]=UIWidget.create_definition({{pass_type="text",style_id="text",value_id="text",value="",style={
            font_type="proxima_nova_bold",font_size=22,text_color=table.clone(colors.text),text_horizontal_alignment="left",text_vertical_alignment="top",size={100,48}}}},id,{text=""})end
    end
end
local scrollbars={
    talent_scrollbar={name="catalog_scrollbar",area="catalog_scroll_area",field="_workspace_scroll_index",reset="_workspace_scroll_reset",x=105,y=575,w=1010,h=378},
    detail_scrollbar={name="catalog_detail_scrollbar",area="catalog_detail_scroll_area",field="_workspace_detail_scroll_index",reset="_workspace_detail_scroll_reset",x=1155,y=575,w=640,h=294},
}
for _,bar in pairs(scrollbars)do
    Definitions.scenegraph_definition[bar.area]={parent="canvas",horizontal_alignment="left",vertical_alignment="top",size={bar.w,bar.h},position={bar.x,bar.y,3}}
    Definitions.scenegraph_definition[bar.name]={parent="canvas",horizontal_alignment="left",vertical_alignment="top",size={12,bar.h},position={bar.x+bar.w-12,bar.y,4}}
    Definitions.widget_definitions[bar.name]=UIWidget.create_definition(Scrollbars.simple_scrollbar,bar.name,
        {axis=2,min_thumb_length=.08,scroll_speed=18,value=0},nil,{mouse_scroll={scenegraph_id=bar.area}})
end
local function refresh(view)
    local items={};local ui={}
    function ui:text(key,x,y,w,h,text,font,color)items[#items+1]={kind="text",key=key,x=x,y=y,w=w,h=h,text=text,font=font,color=color}end
    function ui:button(key,x,y,w,h,text,callback,selected)
        local item={kind="button",key=key,x=x,y=y,w=w,h=h,text=text,action=callback,selected=selected};items[#items+1]=item;return item
    end
    function ui:checkbox(key,x,y,w,h,text,callback,checked)return self:button(key,x,y,w,h,(checked and "\238\128\129  " or "")..text,callback,checked)end
    function ui:scrollbar(key,x,y,w,h,total,visible,index)
        items[#items+1]={kind="scrollbar",key=key,x=x,y=y,w=w,h=h,text="",total=total,visible_count=visible,index=index}
    end
    function ui:wrap(text,width,font_size)
        if not (view._ui_renderer and UIRenderer.word_wrap)then return end
        local cache=view._workspace_wrapped
        local scale=view._ui_renderer.scale
        if not cache or cache.text~=text or cache.width~=width or cache.font~=font_size or cache.scale~=scale then
            local wrapped=UIRenderer.word_wrap(view._ui_renderer,text,"proxima_nova_bold",font_size,width)
            local lines={};for i,line in ipairs(wrapped)do lines[i]=line end
            cache={text=text,width=width,font=font_size,scale=scale,lines=lines};view._workspace_wrapped=cache
        end
        return cache.lines
    end
    U.build(ui,view,mod,Model,mod.diy_library,Examples)
    local count=#items
    for i=1,count do local item=items[i];if item.row then
        ui:text(item.key.."_label",item.x+18,item.y+11,item.w-36,item.h-14,item.text,item.font,item.muted and "muted" or item.selected and "gold" or "text")
        item.text=""
    end end
    for _,widget in pairs(view._widgets_by_name)do widget.visible=false;if widget.content.hotspot then widget.content.hotspot.disabled=true end end
    view._widgets_by_name.background.visible=true
    local counts={text=0,button=0};view._diy_items=items
    for _,item in ipairs(items)do
        local bar=scrollbars[item.key];local id
        if bar then id=bar.name else counts[item.kind]=counts[item.kind]+1;id="catalog_"..item.kind.."_"..counts[item.kind]end
        local widget=view._widgets_by_name[id];widget.visible=true
        item.widget=widget
        view:_set_scenegraph_position(id,item.x,item.y);view:_set_scenegraph_size(id,item.w,item.h)
        widget.content.text=item.text;widget.content.original_text=item.text;widget.content.size={item.w,item.h}
        if bar then
            local content=widget.content;local maximum=math.max(0,item.total-item.visible_count)
            local reset=view[bar.reset] or content.scroll_length~=maximum or math.floor((content.value or 0)*maximum+.5)~=item.index
            if reset then
                content.value=maximum>0 and item.index/maximum or 0
                content.scroll_value=nil;content.scroll_add=nil;content.drag_active=nil;content.input_offset=nil
            end
            content.scroll_length=maximum;content.area_length=math.max(item.total,item.visible_count)
            content.scroll_amount=2/math.max(1,maximum)
            content.hotspot.disabled=maximum==0 or view.is_text_input_focused==true
            widget.visible=maximum>0
            widget.style.mouse_scroll.scenegraph_id=not view.is_text_input_focused and bar.area or nil
            view[bar.reset]=nil
        elseif item.kind=="button" then
            widget.content.hotspot.disabled=not (item.action or item.on_hover);widget.content.hotspot.is_selected=item.selected==true
            widget.content.hotspot.pressed_callback=item.action
            widget.content.hotspot.is_focused=item.key==view._workspace_focus
        else
            widget.style.text.size={item.w,item.h};widget.style.text.font_size=item.font or 22
            widget.style.text.text_color=table.clone(colors[item.color or "text"] or colors.text)
        end
    end
end
function View:init(settings,context)
    self._context=context
    View.super.init(self,Definitions,settings,context)
    local parent=context and context.parent
    local workspace=parent and parent._workspace_session_owned and type(parent.update)=="function"
    if workspace then Lifecycle.attach(parent);self._workspace_parent=parent end
    if workspace and not parent._workspace_blocks_background then
        -- An optional extension may own an older shared window. Contain the
        -- drawing at that instance, below its navigation and every child page.
        -- Keep the boundary through tab switches/loading until this window is
        -- destroyed; no class/global hook or dependency on the other mod.
        local update=parent.update
        parent.update=function(self,...)
            local pass_input=update(self,...)
            return pass_input,false
        end
        parent._workspace_blocks_background=true
    end
    self._pass_input,self._pass_draw=not not workspace,not not workspace
end
function View:on_enter()
    View.super.on_enter(self)
    if mod.mortis_request_assets then mod.mortis_request_assets()end
    refresh(self)
end
local function trim_utf8(text)
    local chars={};for c in text:gmatch("[%z\1-\127\194-\244][\128-\191]*")do chars[#chars+1]=c end
    chars[#chars]=nil;return table.concat(chars)
end
function View:update(dt,t,input)
    if not Lifecycle.is_current(self._workspace_parent,"mbm_workspace_mortis_catalog_view")then return true,true end
    local function get(name)return input and input.get and input:get(name)end
    local editing=self.is_text_input_focused
    if self._workspace_number then
        local snapshot=Model.snapshot();local edit=self._workspace_number
        if not snapshot or not snapshot.editable or snapshot.rules.mode~=edit.mode or snapshot.rules.revision~=edit.revision then
            self._workspace_number=nil;self.is_text_input_focused=false
        end
    end
    if self._workspace_number and Keyboard and Keyboard.keystrokes then
        local edit=self._workspace_number
        if get("select_all_text")then edit.replace=true end
        if get("clipboard_paste")then
            local value=Clipboard and Clipboard.get and Clipboard.get()
            if type(value)=="string" and #value<=3 and value:match("^%d+$")then edit.text=value;edit.replace=nil end
        else for _,key in ipairs(Keyboard.keystrokes())do
            if key==Keyboard.ESCAPE then self._workspace_number=nil;self.is_text_input_focused=false;break
            elseif key==Keyboard.ENTER then
                local value=tonumber(edit.text)
                if value and value>=0 and value<=edit.maximum then edit.callback(value);self._workspace_number=nil;self.is_text_input_focused=false
                else self._workspace_message=mod:localize("diy_number_error",edit.maximum)end
                break
            elseif key==Keyboard.BACKSPACE or key==Keyboard.DELETE then edit.text=edit.replace and "" or edit.text:sub(1,-2);edit.replace=nil
            elseif type(key)=="string" and key:match("^%d+$")then edit.text=((edit.replace and "" or edit.text)..key):sub(1,3);edit.replace=nil end
        end end
        self._diy_revision=nil
    elseif self._workspace_searching and Keyboard and Keyboard.keystrokes then
        local before=self._workspace_search or "";local value=before
        local function get(name)return input and input.get and input:get(name)end
        if get("select_all_text")then self._workspace_replace=true end
        if get("clipboard_paste")then
            local paste=Clipboard and Clipboard.get and Clipboard.get()
            if type(paste)=="string" and #paste<=128 then value=paste:gsub("[\r\n]"," ") end
        else for _,key in ipairs(Keyboard.keystrokes())do
            if key==Keyboard.ENTER or key==Keyboard.ESCAPE then self._workspace_searching=nil;self.is_text_input_focused=false
            elseif key==Keyboard.BACKSPACE or key==Keyboard.DELETE then value=self._workspace_replace and "" or trim_utf8(value);self._workspace_replace=nil
            elseif type(key)=="string" and not key:find("[%z\1-\31]") then
                local next_value=(self._workspace_replace and "" or value)..key
                if #next_value<=128 then value=next_value end;self._workspace_replace=nil
            end
        end end
        if value~=before then self._workspace_search=value;self._workspace_scroll_index=0;self._workspace_scroll_reset=true;self._workspace_detail=nil;self._diy_revision=nil end
    end
    if not editing and not self.is_text_input_focused then
        for _,bar in pairs(scrollbars)do
            local widget=self._widgets_by_name[bar.name]
            if widget.visible and not self[bar.reset] then
                local content=widget.content
                local index=math.floor(math.max(0,math.min(1,content.value or 0))*(content.scroll_length or 0)+.5)
                if index~=self[bar.field] then self[bar.field]=index;self._diy_revision=nil end
            end
        end
    end
    self._elapsed=(self._elapsed or 0)+dt
    if self._elapsed>=.25 or self._diy_revision~=mod.diy_library.revision then self._elapsed=0;refresh(self);self._diy_revision=mod.diy_library.revision end
    if not editing and not self.is_text_input_focused and mod:is_enabled() then
        for _,item in ipairs(self._diy_items or {})do
            local hotspot=item.widget and item.widget.content.hotspot
            if item.on_hover and hotspot and hotspot.is_hover and not hotspot.disabled then item.on_hover();break end
        end
    end
    if not editing and not self.is_text_input_focused then
        local buttons,focus={},nil
        for _,item in ipairs(self._diy_items or {})do if item.kind=="button" and item.action then buttons[#buttons+1]=item;if item.key==self._workspace_focus then focus=item end end end
        if not focus then
            local row=tonumber((self._workspace_focus or ""):match("^skill_(%d+)$"))
            local key=row and "skill_"..math.min(row,self._workspace_visible_rows or 0)
            for _,item in ipairs(buttons)do if item.key==key then focus=item;break end end
            if not focus then
                local key="filter_"..(self._workspace_filter or "available")
                for _,item in ipairs(buttons)do if item.key==key then focus=item;break end end
            end
            focus=focus or buttons[1]
            if focus then
                self._workspace_focus=focus.key
                if focus.on_hover then focus.on_hover()end
            end
        end
        local dx,dy=0,0
        if get("navigate_up_continuous")then dy=-1 elseif get("navigate_down_continuous")then dy=1
        elseif get("navigate_left_continuous")then dx=-1 elseif get("navigate_right_continuous")then dx=1 end
        if focus and (dx~=0 or dy~=0) then
            self._nav_wait=(self._nav_wait or 0)-dt
            if self._nav_wait<=0 then
                local best,score
                local row=tonumber(focus.key:match("^skill_(%d+)$"))
                local offset=self._workspace_scroll_index or 0
                local maximum=self._widgets_by_name.catalog_scrollbar.content.scroll_length or 0
                local scroll=row and dx==0 and ((dy==1 and row==self._workspace_visible_rows and offset<maximum)or(dy==-1 and row==1 and offset>0))
                if scroll then
                    self._workspace_scroll_index=offset+dy;self._workspace_scroll_reset=true;refresh(self)
                    buttons={}
                    for _,item in ipairs(self._diy_items)do if item.kind=="button" and item.action then
                        buttons[#buttons+1]=item;if item.key==focus.key then best=item end
                    end end
                else for _,item in ipairs(buttons)do
                    local x=item.x+item.w/2-focus.x-focus.w/2;local y=item.y+item.h/2-focus.y-focus.h/2
                    local forward=x*dx+y*dy;local side=math.abs(x*dy-y*dx)
                    local distance=forward+side*3
                    if forward>1 and (not score or distance<score)then best=item;score=distance end
                end end
                if best then
                    focus=best;self._workspace_focus=best.key
                    if best.on_hover then best.on_hover()end
                end
                self._nav_wait=self._nav_held and .12 or .35;self._nav_held=true
            end
        else self._nav_wait=0;self._nav_held=nil end
        if focus and get("confirm_pressed")then self._workspace_focus=focus.key;focus.action()end
        for _,item in ipairs(buttons)do item.widget.content.hotspot.is_focused=item.key==self._workspace_focus end
    end
    return View.super.update(self,dt,t,input)
end
function View:draw(...)
    if not Lifecycle.is_current(self._workspace_parent,"mbm_workspace_mortis_catalog_view")then return end
    return View.super.draw(self,...)
end
local page={view_name="mbm_workspace_mortis_catalog_view",available=mod.mortis_talent_ui_available}
mod.workspace_page=page
mod.workspace_pages={{id="mortis",order=50,label=function()return mod:localize("workspace_mortis")end,page=page,applies=page.available}}
mod:add_require_path(path.."mortis_workspace_view")
mod:register_view({view_name=page.view_name,view_settings={class="MBMWorkspaceMortisCatalogView",path=path.."mortis_workspace_view",
    package="packages/ui/views/talent_builder_view/talent_builder_view",state_bound=true,init_view_function=function()return true end},view_transitions={}})
return View
