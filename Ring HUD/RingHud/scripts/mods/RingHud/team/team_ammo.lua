-- File: RingHud/scripts/mods/RingHud/team/team_ammo.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Utils (for set_style_text_color, etc.)
local U            = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

-- Expose under mod.* for cross-file access
mod.team_ammo_text = mod.team_ammo_text or {}
local AM           = mod.team_ammo_text

local function _hide_reserve(widget)
    local style   = widget and widget.style and widget.style.reserve_text_style
    local content = widget and widget.content
    if not (style and content) then return end

    local changed = false
    if style.visible then
        style.visible = false
        changed = true
    end
    if content.reserve_text_value ~= "" then
        content.reserve_text_value = ""
        changed = true
    end
    if changed then widget.dirty = true end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- API
-- ─────────────────────────────────────────────────────────────────────────────
-- reserve_frac: [0..1] or nil (nil means "not applicable" / infinite reserve)
-- peer_id: teammate identifier (string/number). Only forwarded to the central policy.
-- NOTE: All visibility is decided by mod.ammo_vis_team_for_peer(...), which
--       in turn consults V.munitions(...) / team_munitions_* modes.
function AM.update_ammo(widget, reserve_frac, peer_id)
    local style   = widget and widget.style and widget.style.reserve_text_style
    local content = widget and widget.content
    if not (style and content) then return end

    -- If the tile itself is disabled, don't show.
    if widget.visible == false or content._tile_disabled == true then
        _hide_reserve(widget)
        return
    end

    -- Ask the centralized visibility policy (context/ammo_visibility.lua).
    local show = false
    if mod.ammo_vis_team_for_peer then
        show = mod.ammo_vis_team_for_peer(peer_id, reserve_frac)
    end

    if not show then
        _hide_reserve(widget)
        return
    end

    -- If visible, we must have a finite reserve (policy guarantees this).
    local f = math.clamp(reserve_frac or 0, 0, 1)

    -- Text value (percent)
    local new_text = string.format("%.0f%%", f * 100)

    -- Colour tiers (central palette expected on mod.PALETTE_ARGB255)
    local new_color =
        (f >= 0.85 and mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_HIGH)
        or (f >= 0.65 and mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_H)
        or (f >= 0.45 and mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_L)
        or (f >= 0.25 and mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_LOW)
        or mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_CRITICAL

    local changed = false

    if content.reserve_text_value ~= new_text then
        content.reserve_text_value = new_text
        changed = true
    end

    if U.set_style_text_color(style, new_color) then
        changed = true
    end

    if not style.visible then
        style.visible = true
        changed = true
    end

    if changed then widget.dirty = true end
end

return AM
