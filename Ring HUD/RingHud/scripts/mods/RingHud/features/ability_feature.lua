-- File: RingHud/scripts/mods/RingHud/features/ability_feature.lua
local mod = get_mod("RingHud"); if not mod then return end

local U              = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local Colors         = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")

local AbilityFeature = {}

-- local CHARGE_GLYPH   = ""
local CHARGE_GLYPH   = "•"

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

local function _timer_buff_dropdown()
    return mod._settings and mod._settings.timer_buff_dropdown or "disabled"
end

local function _timer_cd_dropdown()
    return mod._settings and mod._settings.timer_cd_dropdown or "single"
end

mod.ringhud_timer_buff_enabled_for_ability = function()
    local setting = _timer_buff_dropdown()
    return setting == "ability" or setting == "all"
end

mod.ringhud_timer_buff_enabled_for_broker_decay_alert = function()
    return _timer_buff_dropdown() == "all"
end

mod.ringhud_timer_cd_enabled = function()
    return _timer_cd_dropdown() ~= "disabled"
end

mod.ringhud_timer_cd_mode = function()
    return _timer_cd_dropdown()
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

local function _prefix_pips(pips)
    if not pips or pips <= 0 then
        return ""
    end
    return string.rep(CHARGE_GLYPH, math.floor(pips))
end

local function _effective_text_size(default_size)
    local user_size = tonumber(mod._settings and mod._settings.player_hud_text_size)
    local forced = mod._runtime_overrides and mod._runtime_overrides.ring_scale
    local s = (forced ~= nil) and tonumber(forced) or (tonumber(mod._settings and mod._settings.ring_scale) or 1)

    if user_size then
        return user_size * s
    end

    return default_size
end

----------------------------------------------------------------
-- Layout Application
----------------------------------------------------------------
function AbilityFeature.apply_layout(widget, ctx)
    if not widget or not widget.style or not widget.style.ability_text then return end

    local u = mod.scalable_unit or 1
    local base_x = u * 52.8 -- Equivalent to Definitions.text_offset
    local base_y = u * 13.2 -- Equivalent to Definitions.offset_correction

    if U.apply_shake_to_style_offset(widget.style.ability_text, base_x, base_y, 2, ctx.apply_shake, ctx.dx, ctx.dy, ctx.text_bias_comb, ctx.text_bias_comb) then
        widget.dirty = true
    end
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

    local base_font_size       = _effective_text_size(18 * (mod.scalable_unit or 1))

    local buff_font_size       = base_font_size * 1.5
    local ability_cd_font_size = base_font_size

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
    local mode = mod.ringhud_timer_cd_mode()

    ----------------------------------------------------------------
    -- 1) Buff timer always has priority (when enabled)
    ----------------------------------------------------------------
    local buff_enabled = mod.ringhud_timer_buff_enabled_for_ability()

    if buff_enabled == true
        and (data.buff_timer_value or 0) > 0
        and (data.buff_max_duration or 0) > 0
    then
        if _allow_subsecond_update(widget, t) or content.ability_text == "" then
            -- Use shared helper for text + color
            local text, text_color =
                U.buff_timer_text_and_color(data.buff_timer_value, data.buff_max_duration)

            local buff_font_type, buff_drop_shadow = U.get_buff_font_settings()
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
    local font_type, drop_shadow = U.get_cd_font_settings()

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
            _set_cd_text(U.format_single_cd(cd_remaining), wants_subsec)
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

            _set_cd_text(U.format_single_cd(cd_remaining), wants_subsec, color)
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
            local text         = _prefix_pips(remaining_charges) .. U.format_single_cd(lowest)
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
            local text         = tostring(count) .. CHARGE_GLYPH .. U.format_single_cd(lowest)
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
