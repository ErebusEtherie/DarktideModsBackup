local mod = get_mod("HavocConditionManager")
local UIWidget = require("scripts/managers/ui/ui_widget")
local TextInputPassTemplates = require("scripts/ui/pass_templates/text_input_pass_templates")
local Input = {hold_delay=0.4, repeat_interval=0.08}

Input.definition=function()
    -- Clone deeply: changing our focus behavior must not change other native inputs.
    local passes=table.clone_instance(TextInputPassTemplates.simple_input_field)
    for _,pass in ipairs(passes) do
        if pass.pass_type=="hotspot" then
            pass.change_function=function(hotspot)
                if hotspot.on_pressed then hotspot.parent.is_writing=true end
                hotspot.double_click_timer=0
            end
        elseif pass.style_id=="limit_text" then
            pass.visibility_function=function() return false end
        elseif pass.style_id=="focused" then
            pass.visibility_function=function(c) return c.is_writing end
        elseif pass.style_id=="display_text" then
            pass.style.font_type="proxima_nova_bold"; pass.style.font_size=24
        end
    end
    return UIWidget.create_definition(passes,"hcm_number_input",{input_text="",max_length=32,close_on_backspace=false},{236,50})
end

Input.cancel=function(view)
    view._hcm_hold=nil
    if not view._hcm_number then return false end
    view._hcm_number=nil; view._hcm_refresh=true; view.is_text_input_focused=false
    local widget=view._widgets_by_name.hcm_number_input
    widget.content.is_writing=false; widget.content.selected_text=nil
    widget.content._selection_start=nil; widget.content._selection_end=nil
    widget.content.hotspot.disabled=true; widget.visible=false
    return true
end

Input.open=function(view,item)
    Input.cancel(view)
    view:_set_exclusive_focus_on_setting(nil)
    view._hcm_choice=nil
    local spec=item.number
    local text=tostring(spec.value)
    view._hcm_number={key=item.key,spec=spec,original=text,page=view._hcm_page,generator=view._hed_generator_id,
        x=math.max(110,math.min(item.x,1370)),y=item.y+item.h+180<=964 and item.y+item.h+6 or item.y-180}
    view.is_text_input_focused=true; view._hcm_refresh=true
    local c=view._widgets_by_name.hcm_number_input.content
    c.input_text=text; c.display_text=text; c._input_text=text
    c.caret_position=#text+1; c._caret_position=#text+1
    c.selected_text=text; c._selection_start=1; c._selection_end=#text+1
    c._selection_changed=true; c._is_selecting=nil; c.last_input=nil
    c._input_text_first_visible_pos=1; c.force_caret_update=true; c._blink_time=0
    c.is_writing=true
end

Input.parse=function(text,spec)
    text=text:match("^%s*(.-)%s*$")
    if not (text:match("^[+-]?%d+%.?%d*$") or text:match("^[+-]?%.%d+$")) then return nil end
    local value=tonumber(text)
    if not value or value~=value or value<spec.min or value>spec.max then return nil end
    if spec.integer and value%1~=0 then return nil end
    return value
end

Input.commit=function(view)
    local edit=view._hcm_number
    if not edit then return false end
    if edit.page~=view._hcm_page or edit.generator~=view._hed_generator_id then Input.cancel(view); return false end
    local text=view._widgets_by_name.hcm_number_input.content.input_text or ""
    -- Opening/confirming an unedited rounded label must preserve full source precision.
    if text==edit.original then Input.cancel(view); return true end
    local value=Input.parse(text,edit.spec)
    if not value then
        edit.error=mod:localize("ui_028")..edit.spec.min.."–"..edit.spec.max..(edit.spec.integer and mod:localize("ui_029") or mod:localize("ui_030"))
        view._hcm_refresh=true
        return false
    end
    Input.cancel(view)
    if value~=edit.spec.value then edit.spec.set(value) end
    return true
end

Input.build=function(view,ui)
    local edit=view._hcm_number
    if not edit then return end
    local anchor
    for _,item in ipairs(ui.items) do if item.key==edit.key then anchor=item; break end end
    if edit.page~=view._hcm_page or edit.generator~=view._hed_generator_id or not anchor or not anchor.number then
        Input.cancel(view); return
    end
    local x,y=edit.x,edit.y
    for _,item in ipairs(ui.items) do item.blocked=true end
    ui.popup={key=edit.key,x=x,y=y,w=440,h=174,numeric=true}
    local first=#ui.items+1
    ui:panel("number_panel",x,y,440,174)
    ui:text("number_title",x+8,y+6,424,34,edit.spec.label.." · "..edit.spec.min.."–"..edit.spec.max,20,"gold")
    -- The native field itself is a separate persistent widget so UI refreshes retain selection/caret.
    ui:button("number_confirm",x+260,y+48,80,50,mod:localize("ui_031"),function() Input.commit(view) end)
    ui:button("number_cancel",x+348,y+48,80,50,mod:localize("ui_032"),function() Input.cancel(view) end)
    ui:text("number_hint",x+8,y+108,424,58,edit.error or mod:localize("ui_033"),18,edit.error and "danger" or "muted")
    for i=first,#ui.items do ui.items[i].overlay=true end
end

Input.refresh=function(view,visible)
    local widget=view._widgets_by_name.hcm_number_input
    local edit=view._hcm_number
    visible(widget,edit~=nil)
    if edit then
        view:_set_scenegraph_position("hcm_number_input",edit.x+12,edit.y+48,50)
        widget.style.display_text.text_color=edit.error and {255,220,133,117} or {255,222,229,214}
    end
end

Input.update=function(view,input_service)
    local edit=view._hcm_number
    if input_service.is_null_service and input_service:is_null_service() or view._input_disabled then
        Input.cancel(view); return
    end
    if view._hcm_hold and not input_service:get("left_hold") then view._hcm_hold=nil end
    if not edit then return end
    local text=view._widgets_by_name.hcm_number_input.content.input_text
    if edit.last_text~=text then edit.last_text=text; if edit.error then edit.error=nil; view._hcm_refresh=true end end
    if input_service:get("confirm_pressed") then Input.commit(view) end
end

Input.activate=function(view,item)
    view._hcm_hold=nil
    if not item.action or item.blocked then return end
    item.action(); view._hcm_refresh=true
    if item.repeatable then
        view._hcm_hold={key=item.key,page=view._hcm_page,generator=view._hed_generator_id,elapsed=0,next=Input.hold_delay}
    end
end

Input.hold=function(view,item,hotspot,dt)
    local held=view._hcm_hold
    if not held or held.key~=item.key then return end
    if held.page~=view._hcm_page or held.generator~=view._hed_generator_id or view._hcm_ui.popup or
        hotspot.disabled or not hotspot.is_hover or not hotspot._input_pressed then view._hcm_hold=nil; return end
    if hotspot.on_pressed or hotspot.on_double_click then return end
    -- Run after the native hotspot resolves current hover/release. One repeat per frame;
    -- the next frame rebuilds callbacks from saved values before another repeat can run.
    held.elapsed=held.elapsed+math.min(dt or 0,0.1)
    if held.elapsed+0.000001>=held.next then
        held.next=held.elapsed+Input.repeat_interval
        item.action(); view._hcm_refresh=true
    end
end
return Input
