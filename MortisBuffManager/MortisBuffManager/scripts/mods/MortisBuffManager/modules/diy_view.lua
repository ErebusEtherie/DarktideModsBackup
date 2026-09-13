local mod=get_mod("MortisBuffManager")
if mod._diy_workspace_class then return mod._diy_workspace_class end
local BaseView=require("scripts/ui/views/base_view")
local UIWidget=require("scripts/managers/ui/ui_widget")
local Buttons=require("scripts/ui/pass_templates/button_pass_templates")
local path="MortisBuffManager/scripts/mods/MortisBuffManager/modules/diy/"
local U=mod:io_dofile(path.."diy_library_ui")
local Schema,Engine=mod:io_dofile(path.."diy_schema"),mod:io_dofile(path.."diy_engine")
local Examples=mod:io_dofile(path.."diy_examples")
local View=class("MBMWorkspaceDIYView","BaseView");mod._diy_workspace_class=View
local colors={text={255,222,229,214},gold={255,221,194,122},muted={255,151,167,152},danger={255,220,133,117}}
local Definitions={scenegraph_definition={screen={size={1920,1080},scale="fit"},canvas={parent="screen",size={1920,1080},position={0,0,0}}},widget_definitions={}}
for i=1,64 do
    for _,kind in ipairs({"text","button"}) do
        local id="diy_"..kind.."_"..i
        Definitions.scenegraph_definition[id]={parent="canvas",horizontal_alignment="left",vertical_alignment="top",size={100,48},position={0,0,3}}
        if kind=="button" then Definitions.widget_definitions[id]=UIWidget.create_definition(Buttons.terminal_button,id,{text="",original_text=""},nil,{text={font_size=20,character_spacing=.1}})
        else Definitions.widget_definitions[id]=UIWidget.create_definition({{pass_type="text",style_id="text",value_id="text",value="",style={
            font_type="proxima_nova_bold",font_size=22,text_color=table.clone(colors.text),text_horizontal_alignment="left",text_vertical_alignment="top",size={100,48}}}},id,{text=""}) end
    end
end
local function refresh(view)
    local items={};local ui={}
    function ui:text(key,x,y,w,h,text,font,color) items[#items+1]={kind="text",key=key,x=x,y=y,w=w,h=h,text=text,font=font,color=color} end
    function ui:button(key,x,y,w,h,text,action,selected)
        local item={kind="button",key=key,x=x,y=y,w=w,h=h,text=text,action=action,selected=selected};items[#items+1]=item;return item
    end
    function ui:checkbox(key,x,y,w,h,text,action,checked)
        return self:button(key,x,y,w,h,(checked and "●  " or "○  ")..text,action,checked)
    end
    U.build(ui,view,mod,mod.diy_library,Schema,Engine,Examples,mod.diy_mortis.status)
    for _,widget in pairs(view._widgets_by_name) do widget.visible=false;if widget.content.hotspot then widget.content.hotspot.disabled=true end end
    local counts={text=0,button=0};view._diy_items=items
    for _,item in ipairs(items) do
        counts[item.kind]=counts[item.kind]+1;local id="diy_"..item.kind.."_"..counts[item.kind]
        local widget=view._widgets_by_name[id];widget.visible=true
        item.widget=widget
        view:_set_scenegraph_position(id,item.x,item.y);view:_set_scenegraph_size(id,item.w,item.h)
        widget.content.text=item.text;widget.content.original_text=item.text;widget.content.size={item.w,item.h}
        if item.kind=="button" then
            widget.content.hotspot.disabled=not (item.action or item.on_hover);widget.content.hotspot.is_selected=item.selected==true
            widget.content.hotspot.pressed_callback=item.action
        else
            widget.style.text.size={item.w,item.h};widget.style.text.font_size=item.font or 22
            widget.style.text.text_color=table.clone(colors[item.color or "text"] or colors.text)
        end
    end
end
function View:init(settings,context) self._context=context;View.super.init(self,Definitions,settings,context);self._pass_input,self._pass_draw=true,true end
function View:on_enter() View.super.on_enter(self);refresh(self) end
function View:update(dt,t,input)
    if mod:is_enabled() then for _,item in ipairs(self._diy_items or {})do
        local hotspot=item.widget and item.widget.content.hotspot
        if item.on_hover and hotspot and hotspot.is_hover and not hotspot.disabled then item.on_hover();break end
    end end
    self._elapsed=(self._elapsed or 0)+dt
    if self._elapsed>=.25 or self._diy_revision~=mod.diy_library.revision then self._elapsed=0;refresh(self);self._diy_revision=mod.diy_library.revision end
    return View.super.update(self,dt,t,input)
end
local page={view_name="mbm_workspace_diy_view",available=function(player)
    local c=mod.session_context();return mod:is_enabled() and c.is_hub and player==Managers.player:local_player_safe(1)
end}
mod.workspace_pages[#mod.workspace_pages+1]={id="mortis_diy",order=51,label=function() return mod:localize("diy_talents") end,page=page,applies=page.available}
mod:add_require_path("MortisBuffManager/scripts/mods/MortisBuffManager/modules/diy_view")
mod:register_view({view_name=page.view_name,view_settings={class="MBMWorkspaceDIYView",path="MortisBuffManager/scripts/mods/MortisBuffManager/modules/diy_view",
    package="packages/ui/views/talent_builder_view/talent_builder_view",state_bound=true,init_view_function=function() return true end},view_transitions={}})
return View
