-- File: scripts/mods/SimpleBuffFilter/hooks/hud_buffs.lua
local mod = get_mod("SimpleBuffFilter"); if not mod then return end
--[[
hud_buffs.lua – the HUD integration. Hooks the stock buffs HUD class to apply visibility rules, handle discovery, and apply transforms.

Updated:
• Resolution: always use RAW template id for prefs/rules (never talent-alias),
  while talent resolution can apply Option-B normalization internally.
• Robustness: avoid nil HudElementPlayerBuffsSettings access; avoid double-hooking on reload.
• Safety: only set retry flags on table buffs.
]]

local BuffSettings = require("scripts/settings/buff/buff_settings")
local Text = require("scripts/utilities/ui/text")

-- Ensure HUD elements are present and capture the class
local HudElementPlayerBuffs = rawget(_G, "HudElementPlayerBuffs")
local HudElementPlayerBuffsSettings = nil

local function _can_get(path)
    if Application and Application.can_get_resource then
        return Application.can_get_resource("lua", path)
    end
    return false
end

if not HudElementPlayerBuffs then
    local path = "scripts/ui/hud/elements/player_buffs/hud_element_player_buffs"
    if _can_get(path) then
        local class_ref = require(path)
        if class_ref then
            HudElementPlayerBuffs = class_ref
        end
    end
end

-- Fallback to polling version if standard not found (or if game prefers it)
if not HudElementPlayerBuffs then
    local path = "scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_polling"
    if _can_get(path) then
        local class_ref = require(path)
        if class_ref then
            HudElementPlayerBuffs = class_ref
        end
    end
end

-- Get Settings for spacing scaling
if _can_get("scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_settings") then
    HudElementPlayerBuffsSettings = require("scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_settings")
end

-- Final check
if not HudElementPlayerBuffs then
    mod:error("Could not resolve HudElementPlayerBuffs class. HUD hooks will not be applied.")
    return
end

-- Load Runtimes
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/runtime/context")
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/runtime/buff_introspect")
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/runtime/traits")
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/runtime/talents")
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/runtime/misc")

-- Session cache for IDs that failed resolution, so we don't retry them endlessly.
-- Reset on mod load/reload so improved resolution logic (like fuzzy matching) runs again.
mod.tbf_session_ignore = {}

-- ---------------------------------------------------------------------------
-- RAW buff id (prefs/rules key)
-- ---------------------------------------------------------------------------
local function _buff_id(buff)
    local id = mod.tbf_buff and mod.tbf_buff.template_name and mod.tbf_buff.template_name(buff)
    if id then return id end

    local t = mod.tbf_buff and mod.tbf_buff.template_from and mod.tbf_buff.template_from(buff)
    local tn = t and t.name
    if type(tn) == "string" and tn ~= "" then
        if type(buff) == "table" then rawset(buff, "_tbf_template_name", tn) end
        return tn
    end

    return nil
end

-- Core Logic: Resolve buff identity -> Record -> Check Rule
local function _resolve_and_check(buff)
    local id = _buff_id(buff)
    if not id then
        return true
    end

    -- 1. Check if already known (Fast Path)
    local entry = mod.prefs.buffs[id]
    if entry then
        local rule = entry.rule
        if rule == "hide" then return false end
        if rule == "only_in_psykhanium" and not mod.tbf_ctx.is_psykhanium() then return false end
        return true
    end

    -- 1.5 Check if we already tried and failed to resolve this ID this session
    if mod.tbf_session_ignore[id] then return true end

    -- 2. Resolve (Slow Path / Discovery)
    local group, loc = nil, nil
    if not group and mod.tbf_talents.resolve then group, loc = mod.tbf_talents.resolve(buff) end
    if not group and mod.tbf_traits.resolve then group, loc = mod.tbf_traits.resolve(buff) end
    if not group and mod.tbf_misc.resolve then group, loc = mod.tbf_misc.resolve(buff) end

    -- 3. Record
    if group and loc then
        mod.prefs_record_buff(id, group, loc, "allow")
        local new_entry = mod.prefs.buffs[id]
        if new_entry then
            local rule = new_entry.rule
            if rule == "hide" then return false end
            if rule == "only_in_psykhanium" and not mod.tbf_ctx.is_psykhanium() then return false end
        end
        return true
    else
        -- Retry once next frame (parent index etc may be assigned after _add_buff returns)
        if type(buff) == "table" then
            buff._tbf_retry_resolve = true
        else
            -- If we can't tag it, avoid wasting time re-trying constantly.
            mod.tbf_session_ignore[id] = true
        end
        return true
    end
end

-- Hook Add (Discovery + Initial Filter)
if not mod._tbf_hud_add_buff_hooked then
    mod:hook(HudElementPlayerBuffs, "_add_buff", function(func, self, buff, ...)
        if _resolve_and_check(buff) then
            return func(self, buff, ...)
        end
    end)
    mod._tbf_hud_add_buff_hooked = true
end

-- Hook Data (Frame Update)
local BuffClasses = require("scripts/settings/buff/buff_classes")
if not mod._tbf_hud_rules_hooked then
    for _, BuffClass in pairs(BuffClasses) do
        mod:hook(BuffClass, "get_hud_data", function(original, buff, ...)
            -- Lazy Retry Logic: Attempt resolution again if flagged (now that parent index is set)
            if type(buff) == "table" and buff._tbf_retry_resolve then
                buff._tbf_retry_resolve = nil -- Consume flag

                local group, loc = nil, nil
                if not group and mod.tbf_talents.resolve then group, loc = mod.tbf_talents.resolve(buff) end
                if not group and mod.tbf_traits.resolve then group, loc = mod.tbf_traits.resolve(buff) end
                if not group and mod.tbf_misc.resolve then group, loc = mod.tbf_misc.resolve(buff) end

                local id = _buff_id(buff)
                if group and loc and id then
                    mod.prefs_record_buff(id, group, loc, "allow")
                elseif id then
                    -- Failed twice -> Ignore for session
                    mod.tbf_session_ignore[id] = true
                end
            end

            local hud = original(buff, ...) or {}
            local id = _buff_id(buff)
            if id then
                local entry = mod.prefs.buffs[id]
                if entry then
                    local rule = entry.rule
                    if rule == "hide" then
                        hud.show = false
                    elseif rule == "only_in_psykhanium" and not mod.tbf_ctx.is_psykhanium() then
                        hud.show = false
                    end
                end
            end
            return hud
        end)
    end
    mod._tbf_hud_rules_hooked = true
end

-- ============================================================================
-- Initialization of Spacing Constants
-- ============================================================================

if HudElementPlayerBuffsSettings then
    if not HudElementPlayerBuffsSettings._tbf_original_spacing then
        HudElementPlayerBuffsSettings._tbf_original_spacing = HudElementPlayerBuffsSettings.horizontal_spacing
    end
    mod._tbf_base_spacing = HudElementPlayerBuffsSettings._tbf_original_spacing
else
    mod._tbf_base_spacing = 42
end

-- ============================================================================
-- HUD Alignment & Spacing Logic
-- ============================================================================

if not mod._tbf_update_buff_alignments_hooked then
    mod:hook(HudElementPlayerBuffs, "_update_buff_alignments", function(func, self, force_update, dt)
        local active_buffs_data = self._active_buffs_data
        local num_active_buffs = #active_buffs_data

        -- Current Scaled Spacing (robust if settings file not present)
        local horizontal_spacing = (HudElementPlayerBuffsSettings and HudElementPlayerBuffsSettings.horizontal_spacing) or
            (mod._tbf_base_spacing or 42)
        local base_spacing = mod._tbf_base_spacing or 42
        local gap_width = 0.5 * base_spacing

        local current_scale = horizontal_spacing / base_spacing

        -- Growth Compensation Constants (Pins Bottom-Center)
        local comp_y = 59 * (current_scale - 1)
        local comp_x = (59 * (current_scale - 1)) / 2

        local use_categories = false
        if Managers.save then
            local account_data = Managers.save:account_data()
            if account_data and account_data.interface_settings.group_buff_icon_in_categories then
                use_categories = true
            end
        end

        local category_starts = {}
        local category_counts = {}

        if use_categories then
            local counts_total = {}
            for i = 1, num_active_buffs do
                local d = active_buffs_data[i]
                if d.show and not d.is_negative then
                    local cat = d.buff_category or BuffSettings.buff_categories.generic
                    counts_total[cat] = (counts_total[cat] or 0) + 1
                end
            end

            local current_px = 0
            local order = BuffSettings.buff_category_order
            for _, cat in ipairs(order) do
                category_starts[cat] = current_px
                local c = counts_total[cat] or 0
                if c > 0 then
                    current_px = current_px + (c * horizontal_spacing)
                    current_px = current_px + gap_width
                end
                category_counts[cat] = 0
            end
        end

        local previous_positive_buff_offset = 0
        local previous_negative_buff_offset = 0

        for i = 1, num_active_buffs do
            local buff_data = active_buffs_data[i]
            local is_negative = buff_data.is_negative
            local widget = buff_data.widget

            if widget then
                local offset = widget.offset
                local old_horizontal_offset = offset[1]
                local target_x = 0

                local row_offset = is_negative and (-42 * current_scale) or 0
                offset[2] = row_offset - comp_y

                if is_negative then
                    target_x = previous_negative_buff_offset
                    previous_negative_buff_offset = previous_negative_buff_offset + horizontal_spacing
                else
                    if use_categories then
                        local cat = buff_data.buff_category or BuffSettings.buff_categories.generic
                        local start = category_starts[cat] or 0
                        local idx = category_counts[cat] or 0

                        target_x = start + (idx * horizontal_spacing)

                        category_counts[cat] = idx + 1
                    else
                        target_x = previous_positive_buff_offset
                        previous_positive_buff_offset = previous_positive_buff_offset + horizontal_spacing
                    end
                end

                target_x = target_x - comp_x

                if force_update then
                    offset[1] = target_x
                    widget.dirty = true
                else
                    local initialize_offset = widget.initialize_offset
                    local content = widget.content

                    if initialize_offset then
                        widget.initialize_offset = nil
                        offset[1] = target_x + horizontal_spacing
                        content.opacity = 0
                    else
                        offset[1] = math.lerp(old_horizontal_offset, target_x, dt * 6)
                        content.opacity = math.lerp(content.opacity, 1, dt * 4)
                    end
                end

                if math.abs(old_horizontal_offset - offset[1]) > 0.001 then
                    widget.dirty = true
                end
            end
        end
    end)

    mod._tbf_update_buff_alignments_hooked = true
end

-- ============================================================================
-- Text Size Hook (Pass-through)
-- ============================================================================

if not mod._tbf_text_size_hooked then
    mod:hook(HudElementPlayerBuffs, "_text_size", function(func, self, ui_renderer, text, style, ...)
        return func(self, ui_renderer, text, style, ...)
    end)
    mod._tbf_text_size_hooked = true
end

-- ============================================================================
-- HUD Transforms (Vanilla Bar)
-- ============================================================================

local function _apply_widget_transforms(widget, scale, opacity)
    -- 0. Scale Widget Content Size
    if not widget.content.size then
        widget.content.size = { 59, 59 }
    end

    if not widget._tbf_orig_content_size then
        widget._tbf_orig_content_size = { 59, 59 }
    end

    widget.content.size[1] = widget._tbf_orig_content_size[1] * scale
    widget.content.size[2] = widget._tbf_orig_content_size[2] * scale

    -- 1. Opacity
    widget.alpha_multiplier = opacity / 255

    -- 2. Scale Styles
    if not widget._tbf_orig_style then
        widget._tbf_orig_style = table.clone(widget.style)
    end

    local orig_styles = widget._tbf_orig_style
    local style = widget.style

    local font_scale = (scale + 1) * 0.5

    -- === OFFSETS ===
    -- Icon Shift: (59 - 38) / 2 = 10.5 scaled. Move UP (Negative Y).
    local icon_shift_y = -10.5 * scale

    -- Text Shift (Negative = Inward from Bottom-Right edge)
    -- Padding = 10.5. Nudge = 2. Total = 12.5.
    -- X: -12.5 (Left into box). Y: -12.5 (Up into box).
    local text_shift = -12.5 * scale

    for pass_id, orig_pass_style in pairs(orig_styles) do
        local current_pass_style = style[pass_id]
        if current_pass_style then
            -- Scale Size
            if orig_pass_style.size then
                if pass_id == "text" or pass_id == "text_background" then
                    -- Height: 0.75 factor (25% shorter)
                    current_pass_style.size[2] = (orig_pass_style.size[2] * scale) * 0.75
                else
                    current_pass_style.size[1] = orig_pass_style.size[1] * scale
                    current_pass_style.size[2] = orig_pass_style.size[2] * scale
                end
            end

            -- Scale Offset
            if orig_pass_style.offset then
                current_pass_style.offset[1] = 0
                current_pass_style.offset[2] = 0
                current_pass_style.offset[3] = orig_pass_style.offset[3]
            end

            -- UNIVERSAL VERTICAL ALIGNMENT: BOTTOM
            current_pass_style.vertical_alignment = "bottom"

            -- === COMPONENT POSITIONING ===

            -- ICON: Centered Horizontally, Shifted UP
            if pass_id == "icon" then
                current_pass_style.horizontal_alignment = "center"
                current_pass_style.offset[2] = icon_shift_y
            end

            -- FRAME: Centered / Bottom
            if pass_id == "frame" then
                current_pass_style.horizontal_alignment = "center"
            end

            -- TEXT & BACKGROUND: Bottom-Right of Container -> Shifted Inwards
            if pass_id == "text" or pass_id == "text_background" then
                current_pass_style.horizontal_alignment = "right"

                -- Move Inwards (Left/Up)
                current_pass_style.offset[1] = text_shift
                current_pass_style.offset[2] = text_shift

                if pass_id == "text" then
                    current_pass_style.text_horizontal_alignment = "right"
                    current_pass_style.text_vertical_alignment = "bottom"
                end
            end

            -- Font Scaling
            if orig_pass_style.font_size then
                current_pass_style.font_size = orig_pass_style.font_size * font_scale
            end
        end
    end
end

-- Tighten background + ensure text box never wraps (decouple after vanilla sizing)
local function _apply_stack_label_sizing(element, ui_renderer, scale)
    if not ui_renderer or not element or not element._widgets then
        return
    end

    local font_scale = (scale + 1) * 0.5

    -- Background margin shrinks at low bars_scale, equals vanilla (5) at 3.0
    -- 3.0 -> 5.0, 1.0 -> 2.5, 0.5 -> 1.875
    local bg_margin = math.clamp(5 * ((scale + 1) * 0.25), 1.0, 5.0)

    -- Small "anti-wrap" padding for the text box (a few pixels, scale-aware)
    local text_pad = math.max(1, math.floor(2 * font_scale + 0.5))

    local measure_size = { 2048, 256 } -- huge width so 2 digits never measure as wrapped

    for _, widget in ipairs(element._widgets) do
        local content = widget and widget.content
        local style = widget and widget.style

        local text = content and content.text
        local text_style = style and style.text
        local bg_style = style and style.text_background

        if text and text ~= "" and text_style and text_style.size and bg_style and bg_style.size then
            -- Cache so we only recompute when needed (text or scale change)
            if widget._tbf_stack_text ~= text or widget._tbf_stack_scale ~= scale then
                local tw = select(1, Text.text_size(ui_renderer, text, text_style, measure_size))
                if tw then
                    local text_w = math.ceil(tw + text_pad)
                    local bg_w = math.ceil(tw + bg_margin)

                    -- Ensure background always covers the text box
                    bg_w = math.max(bg_w, text_w)

                    if text_style.size[1] ~= text_w then
                        text_style.size[1] = text_w
                        widget.dirty = true
                    end
                    if bg_style.size[1] ~= bg_w then
                        bg_style.size[1] = bg_w
                        widget.dirty = true
                    end
                end

                widget._tbf_stack_text = text
                widget._tbf_stack_scale = scale
            end
        else
            -- Reset cache if stack text not shown
            if widget then
                widget._tbf_stack_text = nil
                widget._tbf_stack_scale = nil
            end
        end
    end
end

-- Apply transforms to the vanilla HUD element
function mod.apply_hud_transforms(optional_element)
    local element = optional_element

    if not element then
        local hud = Managers.ui and Managers.ui:get_hud()
        if not hud then return end
        element = hud:element("HudElementPlayerBuffs")
    end

    if not element then return end

    local p = mod.prefs_get_hud()
    local scale = p.scale
    local opacity = p.opacity

    -- 1. Position (X/Y Offset)
    if element._ui_scenegraph then
        local def = rawget(element._ui_scenegraph, "background") or rawget(element._ui_scenegraph, "buffs_pivot")

        if def then
            if not element._tbf_orig_pos then
                element._tbf_orig_pos = { x = def.position[1], y = def.position[2] }
            end

            local target_x = element._tbf_orig_pos.x + p.x
            local target_y = element._tbf_orig_pos.y + p.y

            if def.position[1] ~= target_x or def.position[2] ~= target_y then
                def.position[1] = target_x
                def.position[2] = target_y
                element._update_scenegraph = true
            end
        end
    end

    -- 2. Spacing (Horizontal)
    if HudElementPlayerBuffsSettings and mod._tbf_base_spacing then
        HudElementPlayerBuffsSettings.horizontal_spacing = mod._tbf_base_spacing * scale
    end

    -- 3. Widget Styles (Size, Font, Opacity)
    if element._widgets then
        for _, widget in ipairs(element._widgets) do
            _apply_widget_transforms(widget, scale, opacity)
        end
    end
end

-- Hook Update to enforce transforms continuously (Persistence) + apply stack sizing fix
if not mod._tbf_hud_update_hooked then
    mod:hook_safe(HudElementPlayerBuffs, "update", function(self, dt, t, ui_renderer, ...)
        mod.apply_hud_transforms(self)

        local p = mod.prefs_get_hud and mod.prefs_get_hud()
        local scale = p and p.scale or 1.0
        _apply_stack_label_sizing(self, ui_renderer, scale)
    end)
    mod._tbf_hud_update_hooked = true
end

-- Hook HUD Init to apply transforms early
if not mod._tbf_hud_init_hooked then
    mod:hook("UIHud", "init", function(func, self, ...)
        local ret = func(self, ...)
        mod.apply_hud_transforms()
        return ret
    end)
    mod._tbf_hud_init_hooked = true
end

-- ============================================================================
-- CRASH FIXES
-- ============================================================================

local StimmFieldPath = "scripts/extension_systems/proximity/side_relation_gameplay_logic/proximity_broker_stimm_field"
if not mod._tbf_stimm_field_crash_fix_hooked and _can_get(StimmFieldPath) then
    local ProximityBrokerStimmField = require(StimmFieldPath)
    if ProximityBrokerStimmField then
        mod:hook(ProximityBrokerStimmField, "_make_linger", function(func, self, unit, t, linger_time)
            if not unit or not HEALTH_ALIVE[unit] then
                if self._units_in_proximity then self._units_in_proximity[unit] = nil end
                if self._lingering_units then self._lingering_units[unit] = nil end
                if self._previously_proximate_units then self._previously_proximate_units[unit] = nil end
                return
            end
            return func(self, unit, t, linger_time)
        end)
        mod._tbf_stimm_field_crash_fix_hooked = true
    end
end
