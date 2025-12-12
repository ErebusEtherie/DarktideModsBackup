-- File: RingHud/scripts/mods/RingHud/features/pocketable_feature.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local RingHudColors     = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")
local RSBridge          = mod:io_dofile("RingHud/scripts/mods/RingHud/compat/recolor_stimms_bridge")
local U                 = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local PV                = mod:io_dofile("RingHud/scripts/mods/RingHud/context/pocketables_visibility")
local AbilityFeature    = mod:io_dofile("RingHud/scripts/mods/RingHud/features/ability_feature")

local PocketableFeature = {}

-- Default tints for known pocketables (ARGB 0..255)
local pocketable_colors = {
    syringe_corruption_pocketable    = { color = mod.PALETTE_ARGB255.HEALTH_GREEN },
    syringe_power_boost_pocketable   = { color = mod.PALETTE_ARGB255.POWER_RED },
    syringe_speed_boost_pocketable   = { color = mod.PALETTE_ARGB255.SPEED_BLUE },
    syringe_ability_boost_pocketable = { color = mod.PALETTE_ARGB255.COOLDOWN_YELLOW },
    syringe_broker_pocketable        = { color = mod.PALETTE_ARGB255.PUNKY_PINK },
}

local ALL_COLORS        = {} -- TODO Color? Figure out where this is used
do
    local C  = RingHudColors or {}
    local PA = C.PALETTE or mod.PALETTE_ARGB255

    -- A) entries with .color
    for k, v in pairs(C) do
        if type(v) == "table" and v.color then
            ALL_COLORS[k] = v.color
        end
    end

    -- Also include our local item -> color map so names resolve directly.
    for k, v in pairs(pocketable_colors) do
        if type(v) == "table" and v.color then
            ALL_COLORS[k] = v.color
        end
    end

    -- B) palette keys
    if type(PA) == "table" then
        for name, rgba in pairs(PA) do
            if type(rgba) == "table" and rgba[1] then
                ALL_COLORS[name] = rgba
            end
        end
    end
end

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

-- Resolve the *actual* local player's stimm id (matches RS ids) from visual loadout.
local function _current_local_stimm_rs_id()
    local player = Managers.player and Managers.player:local_player_safe(1)
    local unit   = player and player.player_unit
    if not (unit and Unit.alive(unit)) then
        return nil
    end

    local vload = ScriptUnit.has_extension(unit, "visual_loadout_system")
        and ScriptUnit.extension(unit, "visual_loadout_system")
    if not vload or not vload.weapon_template_from_slot then
        return nil
    end

    local tmpl = vload:weapon_template_from_slot("slot_pocketable_small")
    return tmpl and tmpl.name or nil -- e.g. "syringe_power_boost_pocketable"
end

-- Prefer RecolorStimms colour; fallback to RingHud palette.
-- preferred_name is typically hud_state.stimm_item_name.
local function _stimm_base_color_argb255(preferred_name)
    local rs_id    = _current_local_stimm_rs_id() or preferred_name
    local entry    = pocketable_colors[rs_id] or pocketable_colors[preferred_name]
    local fallback = (entry and entry.color)
        or ALL_COLORS[rs_id]
        or ALL_COLORS[preferred_name]
        or ALL_COLORS.GENERIC_WHITE

    if RSBridge and RSBridge.stimm_argb255 then
        local c = RSBridge.stimm_argb255(rs_id, fallback)
        return c or fallback
    end

    return fallback
end

local function _apply_alpha(base_color, alpha)
    if not base_color then
        return { alpha or 255, 255, 255, 255 }
    end

    local a = alpha or base_color[1] or 255
    if a < 0 then
        a = 0
    elseif a > 255 then
        a = 255
    end

    return { a, base_color[2], base_color[3], base_color[4] }
end

local function _set_timer_text(widget, text, color_argb, font_type, drop_shadow, font_scale)
    local content = widget.content
    local style   = widget.style.stimm_timer_text
    local changed = false

    if style then
        -- Cache base font size once so we can scale reliably per mode.
        style._ringhud_base_font_size = style._ringhud_base_font_size or style.font_size

        -- Typography
        if font_type and style.font_type ~= font_type then
            style.font_type = font_type
            changed = true
        end

        if drop_shadow ~= nil and style.drop_shadow ~= drop_shadow then
            style.drop_shadow = drop_shadow
            changed = true
        end

        if font_scale and style._ringhud_base_font_size then
            local target_size = style._ringhud_base_font_size * font_scale
            if style.font_size ~= target_size then
                style.font_size = target_size
                changed = true
            end
        end
    end

    if content.stimm_timer_text ~= text then
        content.stimm_timer_text = text
        changed = true
    end

    if style and U.set_style_visible(style, text ~= "" and true or false) then
        changed = true
    end

    if style and color_argb and U.set_style_text_color(style, color_argb) then
        changed = true
    end

    return changed
end

-- Helper to hide the timer text
local function _hide_timer_text(widget)
    local content = widget.content
    local style   = widget.style.stimm_timer_text
    local changed = false

    if content.stimm_timer_text ~= "" then
        content.stimm_timer_text = ""
        changed = true
    end

    if style and U.set_style_visible(style, false) then
        changed = true
    end

    return changed
end

----------------------------------------------------------------
-- Main update
----------------------------------------------------------------

function PocketableFeature.update(widgets, hud_state, hotkey_override)
    if not (widgets and widgets.stimm_indicator_widget and widgets.crate_indicator_widget) then
        return
    end

    local stimm_widget     = widgets.stimm_indicator_widget
    local crate_widget     = widgets.crate_indicator_widget

    local stimm_style      = stimm_widget.style.stimm_icon
    local stimm_content    = stimm_widget.content
    local crate_style      = crate_widget.style.crate_icon
    local crate_content    = crate_widget.content

    local stimm_exists     = (hud_state.stimm_item_name ~= nil) and (hud_state.stimm_icon_path ~= nil)
    local crate_exists     = (hud_state.crate_item_name ~= nil) and (hud_state.crate_icon_path ~= nil)

    -- Ask central policy for player pocketable flags (single call per frame)
    local flags            = PV and PV.player_flags and PV.player_flags(hud_state, hotkey_override) or nil
    local stimm_flags      = flags and flags.stimm or nil
    local crate_flags      = flags and flags.crate or nil

    local stimm_is_visible = (stimm_flags and stimm_flags.enabled and stimm_exists) or false
    local crate_is_visible = (crate_flags and crate_flags.enabled and crate_exists) or false

    local stimm_alpha      = stimm_flags and stimm_flags.alpha or nil
    local crate_alpha      = crate_flags and crate_flags.alpha or nil

    local changed          = false

    ----------------------------------------------------------------
    -- STIMM RENDER (Timer Logic Override)
    ----------------------------------------------------------------
    -- Default to icon logic
    local show_icon        = true
    local timer_mode       = "none" -- "buff", "cooldown", "none"
    local timer_value      = 0
    local timer_max        = 0

    -- Broker Stimm Timer Logic
    local broker_data      = hud_state.broker_stimm_data
    if broker_data and broker_data.is_broker then
        local buff_enabled     = mod._settings.timer_buff_enabled
        local cooldown_enabled = mod._settings.timer_cd_dropdown ~= "disabled"

        if buff_enabled and broker_data.buff_remaining > 0 then
            timer_mode  = "buff"
            timer_value = broker_data.buff_remaining
            timer_max   = broker_data.buff_duration
            show_icon   = false
        elseif cooldown_enabled and broker_data.cooldown_remaining > 0 then
            timer_mode  = "cooldown"
            timer_value = broker_data.cooldown_remaining
            timer_max   = broker_data.cooldown_max
            show_icon   = false
        end
    end

    if not show_icon then
        -- We are showing a timer, hide the icon first
        if stimm_style then
            changed = U.set_style_visible(stimm_style, false, changed) or changed
        end

        local text_str     = ""
        local text_color   = mod.PALETTE_ARGB255.GENERIC_WHITE
        local wants_subsec = false
        local font_type    = nil
        local drop_shadow  = nil
        local font_scale   = 1.0 -- cooldown "normal" size by default

        if timer_mode == "buff" then
            -- Use the shared ability buff helper.
            text_str, text_color   = AbilityFeature.buff_timer_text_and_color(timer_value, timer_max)
            font_type, drop_shadow = AbilityFeature.get_buff_font_settings()
            wants_subsec           = true

            -- Buff timers: ~50% larger than normal cooldown size.
            font_scale             = 1.5
        elseif timer_mode == "cooldown" then
            -- Use the shared ability cooldown formatter + font settings.
            text_str               = AbilityFeature.format_single_cd(timer_value)
            text_color             = mod.PALETTE_ARGB255.GENERIC_WHITE
            font_type, drop_shadow = AbilityFeature.get_cd_font_settings()
            wants_subsec           = (timer_value or 0) <= 1
            font_scale             = 1.0
        end

        local can_update = true
        local content    = stimm_widget.content
        local t          = hud_state.gameplay_t or 0

        if wants_subsec then
            -- Share the same subsecond cadence as the ability timer; always allow first draw.
            can_update = AbilityFeature.should_update_subsecond(stimm_widget, t)
                or content.stimm_timer_text == ""
        end

        if text_str ~= "" and (not wants_subsec or can_update) then
            if _set_timer_text(stimm_widget, text_str, text_color, font_type, drop_shadow, font_scale) then
                changed = true
            end
        elseif text_str == "" then
            -- Defensive: no valid text → hide timer text.
            if _hide_timer_text(stimm_widget) then
                changed = true
            end
        end
    else
        -- Standard Icon Render
        if _hide_timer_text(stimm_widget) then
            changed = true
        end

        if stimm_style then
            changed = U.set_style_visible(stimm_style, stimm_is_visible, changed) or changed
        end

        if stimm_is_visible then
            if stimm_content.stimm_icon ~= hud_state.stimm_icon_path then
                stimm_content.stimm_icon = hud_state.stimm_icon_path
                changed = true
            end

            -- Base colour (RecolorStimms + palette), with alpha from PV.
            local base_color  = _stimm_base_color_argb255(hud_state.stimm_item_name)
            local final_color = _apply_alpha(base_color, stimm_alpha)

            if U.set_style_color(stimm_style, final_color) then
                changed = true
            end
        else
            if stimm_content.stimm_icon ~= nil then
                stimm_content.stimm_icon = nil
                changed = true
            end
        end
    end

    ----------------------------------------------------------------
    -- CRATE RENDER (pure presentation)
    ----------------------------------------------------------------
    if crate_style then
        changed = U.set_style_visible(crate_style, crate_is_visible, changed) or changed
    end

    if crate_is_visible then
        if crate_content.crate_icon ~= hud_state.crate_icon_path then
            crate_content.crate_icon = hud_state.crate_icon_path
            changed = true
        end

        local crate_name = hud_state.crate_item_name
        local base_color

        if crate_name == "medical_crate_pocketable" then
            local key = mod._settings and mod._settings.medical_crate_color
            base_color = (key and mod.PALETTE_ARGB255[key]) or mod.PALETTE_ARGB255.HEALTH_GREEN
        elseif crate_name == "ammo_cache_pocketable" then
            local key = mod._settings and mod._settings.ammo_cache_color
            base_color = (key and mod.PALETTE_ARGB255[key]) or mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_L
        elseif crate_name == "tome_pocketable" then
            base_color = mod.PALETTE_ARGB255.TOME_BLUE
        elseif crate_name == "grimoire_pocketable" then
            base_color = mod.PALETTE_ARGB255.GRIMOIRE_PURPLE
        else
            base_color = mod.PALETTE_ARGB255.GENERIC_WHITE
        end

        local final_color = _apply_alpha(base_color, crate_alpha)
        if U.set_style_color(crate_style, final_color) then
            changed = true
        end
    else
        if crate_content.crate_icon ~= nil then
            crate_content.crate_icon = nil
            changed = true
        end
    end

    if changed then
        stimm_widget.dirty = true
        crate_widget.dirty = true
    end
end

return PocketableFeature
