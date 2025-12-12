-- File: RingHud/scripts/mods/RingHud/features/ability_feature.lua
local mod = get_mod("RingHud"); if not mod then return end

local U              = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local Colors         = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")

local AbilityFeature = {}

local CHARGE_GLYPH   = "" -- private-use glyph

----------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------

local function has_no_ability_charges_for_timer_fallback()
    local player = Managers.player:local_player_safe(1)
    if not player or not player.player_unit then
        return true
    end

    local ability_ext = ScriptUnit.has_extension(player.player_unit, "ability_system")
        and ScriptUnit.extension(player.player_unit, "ability_system")

    if not ability_ext then
        return true
    end

    local remaining_charges = ability_ext:remaining_ability_charges("combat_ability")
    return remaining_charges == nil or remaining_charges == 0
end

-- Subsecond throttling: only allow updates every 0.1s
local function _allow_subsecond_update(widget, t)
    local last = widget._ringhud_last_subsec_update_t or 0
    if (t - last) >= 0.1 then
        widget._ringhud_last_subsec_update_t = t
        return true
    end
    return false
end

-- Public wrapper so other features (e.g. stimm timers) can reuse the same cadence
function AbilityFeature.should_update_subsecond(widget, t)
    return _allow_subsecond_update(widget, t)
end

-- Sets text + style and **centrally toggles visibility** (visible when text ~= "")
local function _set_text(widget, style, text, font_size, color, font_type, drop_shadow)
    local changed = false

    -- Content
    if widget.content.ability_text ~= text then
        widget.content.ability_text = text
        changed = true
    end

    if style then
        -- Typography
        if font_type and style.font_type ~= font_type then
            style.font_type = font_type
            changed = true
        end

        if font_size and style.font_size ~= font_size then
            style.font_size = font_size
            changed = true
        end

        if drop_shadow ~= nil and style.drop_shadow ~= drop_shadow then
            style.drop_shadow = drop_shadow
            changed = true
        end

        -- Color via shared helper
        if color and U.set_style_text_color(style, color) then
            changed = true
        end

        -- Visibility via shared helper
        changed = U.set_style_visible(style, text ~= "", changed)
    end

    return changed
end

-- Core cooldown formatter (single value)
local function _format_single_cd(cd)
    if cd <= 1 then
        return string.format("%.1fs", math.max(0, cd))
    else
        return string.format("%ds", math.ceil(cd))
    end
end

-- Public helper: expose the same cooldown formatting to other features
AbilityFeature.format_single_cd = _format_single_cd

local function _prefix_pips(pips)
    if not pips or pips <= 0 then
        return ""
    end
    return string.rep(CHARGE_GLYPH, math.floor(pips))
end

----------------------------------------------------------------
-- Public helpers: font settings for buff / cooldown timers
----------------------------------------------------------------

-- Buff timers (ability buff + stimm buff) use machine_medium + drop shadow.
function AbilityFeature.get_buff_font_settings()
    -- font_type, drop_shadow
    return "machine_medium", true
end

-- Cooldown timers (ability CD + stimm CD) use hud_body font settings.
function AbilityFeature.get_cd_font_settings()
    local font_type   = UIFontSettings.hud_body and UIFontSettings.hud_body.font_type or nil
    local drop_shadow = UIFontSettings.hud_body and UIFontSettings.hud_body.drop_shadow or nil
    return font_type, drop_shadow
end

----------------------------------------------------------------
-- Public helper: buff timer text + color
--
-- Returns:
--   text  → "3", "2", "1.0", "0.9", ...
--   color → ARGB table using the standard ability buff ramp
----------------------------------------------------------------
function AbilityFeature.buff_timer_text_and_color(current, max_duration)
    local value = current or 0
    local max   = max_duration or 0

    if value <= 0 or max <= 0 then
        return "", nil
    end

    local clamped   = math.max(0, value)
    local intensity = U.calculate_opacity(clamped, max)

    local text
    if clamped <= 1 then
        -- Under 1s: show one decimal place
        text = string.format("%.1f", clamped)
    else
        -- ≥1s: show whole seconds (no suffix)
        text = string.format("%d", math.ceil(clamped))
    end

    local color = { intensity, intensity, 255 - intensity, 0 }
    return text, color
end

----------------------------------------------------------------
-- Main update
----------------------------------------------------------------
function AbilityFeature.update(widget, hud_state, _hotkey_override)
    if not widget or not widget.style then
        return
    end

    if not (widget.content and widget.style and widget.style.ability_text) then
        return
    end

    local style                = widget.style.ability_text
    local content              = widget.content
    local changed              = false

    local body_small_font_size = (UIFontSettings.body_small and UIFontSettings.body_small.font_size * mod.scalable_unit)
        or (18 * mod.scalable_unit)
    local buff_font_size       = 28 * mod.scalable_unit
    local ability_cd_font_size = body_small_font_size

    local t                    = hud_state.gameplay_t or 0

    local ability_data         = hud_state.ability_data or {}
    local remaining_charges    = ability_data.remaining_charges
    local no_charges

    if ability_data and ability_data.max_charges ~= nil then
        no_charges = (remaining_charges or 0) <= 0
    else
        no_charges = has_no_ability_charges_for_timer_fallback()
        remaining_charges = 0 -- best-effort default
    end

    local data = hud_state.timer_data or {}
    local mode = mod._settings.timer_cd_dropdown or "single"

    ----------------------------------------------------------------
    -- 1) Buff timer always has priority (when enabled)
    ----------------------------------------------------------------
    if mod._settings.timer_buff_enabled == true
        and (data.buff_timer_value or 0) > 0
        and (data.buff_max_duration or 0) > 0
    then
        if _allow_subsecond_update(widget, t) or content.ability_text == "" then
            -- Use shared helper for text + color
            local text, text_color =
                AbilityFeature.buff_timer_text_and_color(data.buff_timer_value, data.buff_max_duration)

            local buff_font_type, buff_drop_shadow = AbilityFeature.get_buff_font_settings()
            changed = _set_text(widget, style, text, buff_font_size, text_color, buff_font_type, buff_drop_shadow)
                or changed
        end

        if changed then
            widget.dirty = true
        end

        return
    end

    ----------------------------------------------------------------
    -- 2) Cooldown modes
    ----------------------------------------------------------------
    local cds                    = data.ability_cooldowns or {} -- ascending (lowest-first)
    local cd_remaining           = math.max(0, data.ability_cooldown_remaining or 0)
    local has_cd_flag            = ((#cds > 0) or (cd_remaining > 0 and data.is_ability_on_cooldown_for_timer == true))
    local white                  = table.clone(mod.PALETTE_ARGB255.GENERIC_WHITE)
    local font_type, drop_shadow = AbilityFeature.get_cd_font_settings()

    local function _set_cd_text(text, wants_subsec, color_override)
        local color = color_override or white

        if (wants_subsec and _allow_subsecond_update(widget, t))
            or content.ability_text == ""
            or not wants_subsec
        then
            changed = _set_text(widget, style, text, ability_cd_font_size, color, font_type, drop_shadow) or changed
        end
    end

    if mode == "disabled" then
        if content.ability_text ~= "" then
            changed = _set_text(widget, style, "", buff_font_size, nil, nil, nil) or changed
        else
            -- ensure hidden even if empty already
            changed = U.set_style_visible(style, false, changed)
        end
    elseif mode == "single" then
        -- Original behavior: only show when no charges remain.
        if data.is_ability_on_cooldown_for_timer == true and no_charges and cd_remaining > 0 then
            local wants_subsec = cd_remaining <= 1
            _set_cd_text(_format_single_cd(cd_remaining), wants_subsec)
        else
            if content.ability_text ~= "" then
                changed = _set_text(widget, style, "", buff_font_size, nil, nil, nil) or changed
            else
                changed = U.set_style_visible(style, false, changed)
            end
        end
    elseif mode == "single_colored" then
        if data.is_ability_on_cooldown_for_timer == true and cd_remaining > 0 then
            local wants_subsec = cd_remaining <= 1
            local color = nil

            if not no_charges then
                color = mod.PALETTE_ARGB255.SPEED_BLUE
            end

            _set_cd_text(_format_single_cd(cd_remaining), wants_subsec, color)
        else
            if content.ability_text ~= "" then
                changed = _set_text(widget, style, "", buff_font_size, nil, nil, nil) or changed
            else
                changed = U.set_style_visible(style, false, changed)
            end
        end
    elseif mode == "pips_single" then
        -- If any charge is cooling: show <pips><lowest ETA>; hide if none cooling.
        if has_cd_flag then
            local lowest       = (#cds > 0) and cds[1] or cd_remaining
            local text         = _prefix_pips(remaining_charges) .. _format_single_cd(lowest)
            local wants_subsec = lowest <= 1
            _set_cd_text(text, wants_subsec)
        else
            if content.ability_text ~= "" then
                changed = _set_text(widget, style, "", buff_font_size, nil, nil, nil) or changed
            else
                changed = U.set_style_visible(style, false, changed)
            end
        end
    elseif mode == "count_single" then
        -- "<remaining_charges><glyph><lowest ETA>" when any are cooling; hide otherwise.
        if has_cd_flag then
            local lowest       = (#cds > 0) and cds[1] or cd_remaining
            local count        = math.max(0, tonumber(remaining_charges) or 0)
            local text         = tostring(count) .. CHARGE_GLYPH .. _format_single_cd(lowest)
            local wants_subsec = lowest <= 1
            _set_cd_text(text, wants_subsec)
        else
            if content.ability_text ~= "" then
                changed = _set_text(widget, style, "", buff_font_size, nil, nil, nil) or changed
            else
                changed = U.set_style_visible(style, false, changed)
            end
        end
    else
        -- Unknown mode: hide defensively.
        if content.ability_text ~= "" then
            changed = _set_text(widget, style, "", buff_font_size, nil, nil, nil) or changed
        else
            changed = U.set_style_visible(style, false, changed)
        end
    end

    if changed then
        widget.dirty = true
    end
end

return AbilityFeature
