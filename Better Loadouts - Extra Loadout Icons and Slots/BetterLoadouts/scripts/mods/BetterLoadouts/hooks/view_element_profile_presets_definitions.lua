-- File: scripts/mods/BetterLoadouts/hooks/view_element_profile_presets_definitions.lua
local mod = get_mod("BetterLoadouts"); if not mod then return end

-- These are used by the blueprint we inject/tweak
local ProfileUtils        = require("scripts/utilities/profile_utils")
local UISoundEvents       = require("scripts/settings/ui/ui_sound_events")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")

local s_lower             = string.lower

mod:hook_require(
    "scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_definitions",
    function(defs)
        -- (No re-ensuring of global icons; BetterLoadouts uses a private pool elsewhere)

        local sg = defs and defs.scenegraph_definition
        if sg then
            -- Loadout bar node (runtime size is updated later)
            if sg.profile_preset_button_panel then
                sg.profile_preset_button_panel.horizontal_alignment = "right"
                sg.profile_preset_button_panel.vertical_alignment   = "top"
                sg.profile_preset_button_panel.size                 = { 56, 524 }
                local pos                                           = sg.profile_preset_button_panel.position
                if pos then
                    pos[1] = 0
                    pos[2] = 94
                    pos[3] = pos[3] or 100
                else
                    sg.profile_preset_button_panel.position = { 0, 94, 100 }
                end
            end

            -- "+" button
            if sg.profile_preset_add_button then
                sg.profile_preset_add_button.horizontal_alignment = "right"
                sg.profile_preset_add_button.vertical_alignment   = "top"
                sg.profile_preset_add_button.size                 = { 44, 44 }
                sg.profile_preset_add_button.position             = { 0, 0, 1 }
            end

            -- Button list pivot: start under +
            if sg.profile_preset_button_pivot then
                sg.profile_preset_button_pivot.horizontal_alignment = "right"
                sg.profile_preset_button_pivot.vertical_alignment   = "top"
                sg.profile_preset_button_pivot.position             = { 0, 48, 1 }
            end

            -- Tooltip container & grid (baseline; runtime resizes)
            if sg.profile_preset_tooltip then
                sg.profile_preset_tooltip.size = { 265, 460 }
            end
            if sg.profile_preset_tooltip_grid then
                sg.profile_preset_tooltip_grid.size = { 225, 1 }
                sg.profile_preset_tooltip_grid.horizontal_alignment = "center"
                sg.profile_preset_tooltip_grid.position[1] = 0
            end
        end

        -- Hide background graphic for the vertical bar
        local panel_def = defs and defs.widget_definitions and defs.widget_definitions.profile_preset_button_panel
        if panel_def and panel_def.passes then
            panel_def.passes = {}
        end

        -- + icon tweaks (remove stamina_glow pulse, unify colors/size)
        local add_def = defs and defs.widget_definitions and defs.widget_definitions.profile_preset_add_button
        if add_def and add_def.passes then
            for i = #add_def.passes, 1, -1 do
                local p = add_def.passes[i]
                if p and p.pass_type == "texture" and p.value == "content/ui/materials/hud/stamina_glow" then
                    table.remove(add_def.passes, i)
                end
            end
            local list = add_def.passes
            for i = 1, (list and #list or 0) do
                local pass = list[i]
                if pass.pass_type == "texture"
                    and (pass.value == "content/ui/materials/icons/presets/preset_new" or pass.value_id == "texture") then
                    pass.style                = pass.style or {}
                    pass.style.color          = { 255, 255, 255, 255 }
                    pass.style.default_color  = { 255, 255, 255, 255 }
                    pass.style.hover_color    = { 255, 255, 255, 255 }
                    pass.style.disabled_color = { 200, 200, 200, 255 }
                    pass.style.size           = { 44, 44 }
                end
            end
        end

        -- Inject unicode glyphs as grid tiles
        local blueprints = defs and defs.profile_preset_grid_blueprints

        local DISABLE_GRID_HIGHLIGHT = true
        local function _vp_silence_highlight(bp)
            if not (DISABLE_GRID_HIGHLIGHT and bp and bp.pass_template) then return end
            local list = bp.pass_template
            for i = 1, (list and #list or 0) do
                local p = list[i]
                if p.value == "content/ui/materials/frames/inner_shadow_thin" then
                    p.visibility_function = function() return false end
                end
                if p.change_function then
                    p.change_function = nil
                end
                if p.style then
                    local base = p.style.default_color or p.style.color
                    if base then
                        p.style.color          = base
                        p.style.default_color  = base
                        p.style.hover_color    = base
                        p.style.selected_color = base
                        p.style.disabled_color = base
                    end
                end
            end
        end

        _vp_silence_highlight(blueprints and blueprints.icon)

        -- Unicode tile
        if blueprints and not blueprints.unicode_icon then
            blueprints.unicode_icon = {
                size = { 45, 45 },
                pass_template = {
                    {
                        content_id = "hotspot",
                        pass_type = "hotspot",
                        content = {
                            on_hover_sound   = UISoundEvents.default_mouse_hover,
                            on_pressed_sound = UISoundEvents.default_click
                        }
                    },
                    { pass_type = "rect", style = { color = { 100, 0, 0, 0 } } },
                    {
                        pass_type = "texture",
                        value = "content/ui/materials/frames/inner_shadow_thin",
                        style = {
                            scale_to_material = true,
                            color = Color.terminal_corner_selected(nil, true),
                            offset = { 0, 0, 1 }
                        },
                        visibility_function = function(content)
                            if content.force_glow or content.equipped or (content.hotspot and content.hotspot.is_selected) then
                                return true
                            end
                            local ik = content.icon_key or (content.element and content.element.icon_key)
                            local ck = content.current_key or (content.element and content.element.current_key)
                            if type(ik) == "string" then ik = s_lower(ik) end
                            if type(ck) == "string" then ck = s_lower(ck) end
                            return (ik ~= nil and ck ~= nil and ik == ck)
                        end
                    },
                    {
                        pass_type = "texture",
                        style_id = "frame",
                        value = "content/ui/materials/frames/frame_tile_2px",
                        style = {
                            horizontal_alignment = "center",
                            vertical_alignment   = "center",
                            offset               = { 0, 0, 6 },
                            color                = Color.terminal_frame(nil, true),
                            default_color        = Color.terminal_frame(nil, true),
                            selected_color       = Color.terminal_frame_selected(nil, true),
                            hover_color          = Color.terminal_frame_hover(nil, true)
                        },
                        change_function = ButtonPassTemplates.default_button_hover_change_function
                    },
                    {
                        pass_type = "texture",
                        style_id = "corner",
                        value = "content/ui/materials/frames/frame_corner_2px",
                        style = {
                            horizontal_alignment = "center",
                            vertical_alignment   = "center",
                            offset               = { 0, 0, 7 },
                            color                = Color.terminal_corner(nil, true),
                            default_color        = Color.terminal_corner(nil, true),
                            selected_color       = Color.terminal_corner_selected(nil, true),
                            hover_color          = Color.terminal_corner_hover(nil, true)
                        },
                        change_function = ButtonPassTemplates.default_button_hover_change_function
                    },
                    {
                        pass_type = "texture",
                        value = "content/ui/materials/frames/frame_tile_1px",
                        style = { color = { 255, 0, 0, 0 }, offset = { 0, 0, 3 } }
                    },
                    {
                        pass_type = "text",
                        value_id = "text",
                        style = {
                            font_size                 = 28,
                            font_type                 = "proxima_nova_bold",
                            text_horizontal_alignment = "center",
                            text_vertical_alignment   = "center",
                            offset                    = { 0, 0, 2 },
                            text_color                = Color.terminal_icon(255, true)
                        }
                    },
                },
                -- Accept either a function OR a callback-name string (prevents crash)
                init = function(parent, widget, element, on_left_click)
                    local content       = widget.content
                    content.element     = element
                    content.text        = element.text or "?"
                    content.icon_key    = element.icon_key
                    content.current_key = element.current_key

                    local hotspot       = content.hotspot
                    if type(on_left_click) == "function" then
                        hotspot.pressed_callback = function()
                            on_left_click(widget, element)
                        end
                    elseif type(on_left_click) == "string" then
                        hotspot.pressed_callback = callback(parent, on_left_click, widget, element)
                    else
                        hotspot.pressed_callback = nil
                    end
                end,
                update = function(parent, widget)
                    local c  = widget and widget.content
                    local el = c and c.element
                    if not el or el.widget_type ~= "unicode_icon" then return end

                    c.icon_key = c.icon_key or (el and el.icon_key)

                    if not c.current_key then
                        local idx        = parent._active_customize_preset_index
                        local cached_idx = parent._vp_cached_idx
                        local cached_key = parent._vp_cached_current_key
                        if idx and cached_idx == idx and cached_key ~= nil then
                            c.current_key = cached_key
                        elseif idx then
                            local pid                     = parent:_get_profile_preset_id_by_widget_index(idx)
                            local pp                      = ProfileUtils.get_profile_preset(pid)
                            local key                     = pp and pp.custom_icon_key
                            parent._vp_cached_idx         = idx
                            parent._vp_cached_current_key = key
                            if key then c.current_key = key end
                        end
                    end

                    local ik, ck = c.icon_key, c.current_key
                    if type(ik) == "string" and type(ck) == "string" and s_lower(ik) == s_lower(ck) then
                        c.force_glow = true
                        c.equipped   = true
                        if c.hotspot then c.hotspot.is_selected = true end
                    end
                end,
            }
        end
        _vp_silence_highlight(blueprints and blueprints.unicode_icon)

        -- Preset buttons can draw unicode glyphs
        local ppb = defs and defs.profile_preset_button
        if ppb and ppb.passes then
            ppb.style = ppb.style or {}
            ppb.style.unicode = ppb.style.unicode or {
                font_size                 = 24,
                font_type                 = "proxima_nova_bold",
                text_horizontal_alignment = "center",
                text_vertical_alignment   = "center",
                offset                    = { 0, 4, 3 },
                text_color                = Color.terminal_icon(255, true),
            }

            local has_text = false
            for i = 1, #ppb.passes do
                local pass = ppb.passes[i]
                if pass.value_id == "icon" then
                    local prev_vis = pass.visibility_function
                    pass.visibility_function = function(content, style)
                        if content.unicode ~= nil and content.unicode ~= "" then return false end
                        return prev_vis and prev_vis(content, style) or true
                    end
                elseif pass.pass_type == "text" and pass.value_id == "unicode" then
                    has_text = true
                end
            end
            if not has_text then
                table.insert(ppb.passes, {
                    pass_type           = "text",
                    value_id            = "unicode",
                    style_id            = "unicode",
                    visibility_function = function(content)
                        return content.unicode ~= nil and content.unicode ~= ""
                    end,
                })
            end
        end

        -- Silence icon glow/hover on the unicode blueprint too
        local blueprints2 = defs and defs.profile_preset_grid_blueprints
        local unicode_bp  = blueprints2 and blueprints2.unicode_icon
        if unicode_bp then
            -- already handled via _vp_silence_highlight above
        end
    end
)
