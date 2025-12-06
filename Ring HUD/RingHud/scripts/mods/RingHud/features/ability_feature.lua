-- File: RingHud/scripts/mods/RingHud/features/ability_feature.lua
local mod = get_mod("RingHud"); if not mod then return end

local RingHudUtils   = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local Colors         = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")

local AbilityFeature = {}

local function has_no_ability_charges_for_timer_fallback()
    local player = Managers.player:local_player_safe(1)
    if not player or not player.player_unit then return true end
    local ability_ext = ScriptUnit.has_extension(player.player_unit, "ability_system") and
        ScriptUnit.extension(player.player_unit, "ability_system")
    if not ability_ext then return true end
    local remaining_charges = ability_ext:remaining_ability_charges("combat_ability")
    return remaining_charges == nil or remaining_charges == 0
end

local function _allow_subsecond_update(widget, t)
    local last = widget._ringhud_last_subsec_update_t or 0
    if (t - last) >= 0.1 then
        widget._ringhud_last_subsec_update_t = t
        return true
    end
    return false
end

local function _set_text(widget, style, text, font_size, color, font_type, drop_shadow)
    local changed = false
    if widget.content.ability_text ~= text then
        widget.content.ability_text = text
        changed = true
    end
    if style then
        if font_type and style.font_type ~= font_type then
            style.font_type = font_type; changed = true
        end
        if font_size and style.font_size ~= font_size then
            style.font_size = font_size; changed = true
        end
        if drop_shadow ~= nil and style.drop_shadow ~= drop_shadow then
            style.drop_shadow = drop_shadow; changed = true
        end
        if color then
            local c = style.text_color or {}
            if c[1] ~= color[1] or c[2] ~= color[2] or c[3] ~= color[3] or c[4] ~= color[4] then
                style.text_color = table.clone(color)
                changed = true
            end
        end
    end
    return changed
end

function AbilityFeature.update(widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end
    if not (widget and widget.content and widget.style and widget.style.ability_text) then return end

    local style                = widget.style.ability_text
    local content              = widget.content
    local changed              = false

    local body_small_font_size = (UIFontSettings.body_small and UIFontSettings.body_small.font_size) or 18
    local buff_font_size       = 28
    local ability_cd_font_size = body_small_font_size

    local t                    = hud_state.gameplay_t or 0

    local ability_data         = hud_state.ability_data
    local no_charges
    if ability_data and ability_data.max_charges ~= nil then
        no_charges = (ability_data.remaining_charges or 0) <= 0
    else
        no_charges = has_no_ability_charges_for_timer_fallback()
    end

    local data = hud_state.timer_data or {}

    -- 1) Buff timer
    if mod._settings.timer_buff_enabled == true and (data.buff_timer_value or 0) > 0 and (data.buff_max_duration or 0) > 0 then
        -- Throttle to ~10 Hz for the sub-second animation
        if _allow_subsecond_update(widget, t) or content.ability_text == "" then
            local intensity = RingHudUtils.calculate_opacity(data.buff_timer_value, data.buff_max_duration)
            local text_color = { intensity, intensity, 255 - intensity, 0 }
            local text = string.format("%.1f", data.buff_timer_value)
            changed = _set_text(widget, style, text, buff_font_size, text_color, "machine_medium", true) or changed
        end

        -- 2) Cooldown timer (only when no charges remain)
    elseif mod._settings.timer_cd_enabled == true and (data.is_ability_on_cooldown_for_timer == true) and no_charges then
        local cd = math.max(0, data.ability_cooldown_remaining or 0)
        local text
        if cd <= 1 then
            if _allow_subsecond_update(widget, t) or content.ability_text == "" then
                text              = string.format("%.1fs", cd)
                local font_type   = (UIFontSettings.hud_body and UIFontSettings.hud_body.font_type) or "hell_shark"
                local drop_shadow = (UIFontSettings.hud_body and UIFontSettings.hud_body.drop_shadow)
                changed           = _set_text(widget, style, text, ability_cd_font_size,
                    table.clone(mod.PALETTE_ARGB255.GENERIC_WHITE),
                    font_type, drop_shadow) or changed
            end
        else
            -- Integer seconds: only changes once per second
            text              = string.format("%ds", math.ceil(cd))
            local font_type   = (UIFontSettings.hud_body and UIFontSettings.hud_body.font_type)
            local drop_shadow = (UIFontSettings.hud_body and UIFontSettings.hud_body.drop_shadow)
            changed           = _set_text(widget, style, text, ability_cd_font_size,
                table.clone(mod.PALETTE_ARGB255.GENERIC_WHITE),
                font_type, drop_shadow) or changed
        end

        -- 3) Otherwise, hide text -- hidden means ready!
    else
        if content.ability_text ~= "" then
            changed = _set_text(widget, style, "", buff_font_size, nil, nil, nil) or changed
        end
    end

    if changed then widget.dirty = true end
end

return AbilityFeature
