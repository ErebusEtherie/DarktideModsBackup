-- File: RingHud/scripts/mods/RingHud/team/team_ability.lua
local mod = get_mod("RingHud"); if not mod then return end

-- Minimal deps: constants (for ABILITY_CD_TEXT_COLOR) + utils (for set_style_text_color)
local C               = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
local U               = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

-- Public API (cross-file access via mod.*)
mod.team_ability_text = mod.team_ability_text or {}
local TXT             = mod.team_ability_text

-- ─────────────────────────────────────────────────────────────────────────────
-- Internals
-- ─────────────────────────────────────────────────────────────────────────────

local function _hide_cd(widget)
    local style   = widget and widget.style and widget.style.ability_cd_text_style or
        widget and widget.style and widget.style.ability_cd_text_style
    local content = widget and widget.content
    if not (style and content) then return end

    local changed = false
    if style.visible then
        style.visible = false
        changed = true
    end
    if content.ability_cd_text ~= "" then
        content.ability_cd_text = ""
        changed = true
    end
    if changed then widget.dirty = true end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- API
-- ─────────────────────────────────────────────────────────────────────────────

-- seconds: integer seconds remaining
-- show_cd: boolean from RingHud_state_team.counters.show_cd
-- Only shows when show_cd is true AND seconds > 0
function TXT.update_ability_cd(widget, seconds, show_cd)
    local style   = widget and widget.style and widget.style.ability_cd_text_style
    local content = widget and widget.content
    if not (style and content) then return end

    local s = tonumber(seconds or 0) or 0
    if s <= 0 or not show_cd then
        _hide_cd(widget)
        return
    end

    local new_text  = tostring(s) .. "s"
    local new_color = C.ABILITY_CD_TEXT_COLOR or (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.GENERIC_WHITE)

    local changed   = false
    if content.ability_cd_text ~= new_text then
        content.ability_cd_text = new_text
        changed = true
    end

    if new_color and U.set_style_text_color(style, new_color) then
        changed = true
    end

    if not style.visible then
        style.visible = true
        changed = true
    end

    if changed then widget.dirty = true end
end

return TXT
