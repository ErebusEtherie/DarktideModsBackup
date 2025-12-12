-- File: RingHud/scripts/mods/RingHud/team/team_ammo.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Utils (for set_style_text_color, etc.)
local U                          = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

-- Expose under mod.* for cross-file access
mod.team_ammo_text               = mod.team_ammo_text or {}
local AM                         = mod.team_ammo_text

-- Per-peer cache so we can detect reserve changes and bump the team
-- recent-change window (purely presentational).
mod._team_ammo_prev_frac_by_peer = mod._team_ammo_prev_frac_by_peer or {}

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
--       in turn consults team_munitions_* modes.
function AM.update_ammo(widget, reserve_frac, peer_id)
    local style   = widget and widget.style and widget.style.reserve_text_style
    local content = widget and widget.content
    if not (style and content) then return end

    -- If the tile itself is disabled, don't show (and don't bother with bumps).
    if widget.visible == false or content._tile_disabled == true then
        _hide_reserve(widget)
        return
    end

    ----------------------------------------------------------------
    -- Recent-change bump per peer (symmetry with player path).
    -- Uses the scalar reserve_frac that the team state builder
    -- precomputed; we only care about meaningful numeric changes.
    ----------------------------------------------------------------
    do
        if peer_id ~= nil and reserve_frac ~= nil then
            local f = tonumber(reserve_frac)
            if f then
                local cache = mod._team_ammo_prev_frac_by_peer
                local prev  = cache[peer_id]

                -- Small epsilon to avoid noise from float jitter.
                if prev ~= nil and math.abs(f - prev) > 0.001 then
                    if mod.ammo_vis_team_recent_change_bump then
                        mod.ammo_vis_team_recent_change_bump(peer_id)
                    end
                end

                cache[peer_id] = f
            end
        end
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

    ----------------------------------------------------------------
    -- Normalise reserve_frac defensively.
    -- If it isn't a sensible number, treat it as "cannot display" and hide.
    ----------------------------------------------------------------
    local f = reserve_frac
    if f ~= nil then
        f = tonumber(f)
    end

    if not f then
        -- Policy said "show", but we got nonsense data: fail closed.
        _hide_reserve(widget)
        return
    end

    f               = math.clamp(f, 0, 1)

    -- Text value (percent)
    local new_text  = string.format("%.0f%%", f * 100)

    -- Colour tiers (central palette expected on mod.PALETTE_ARGB255)
    local palette   = mod.PALETTE_ARGB255 or {}
    local new_color =
        (f >= 0.85 and palette.AMMO_TEXT_COLOR_HIGH)
        or (f >= 0.65 and palette.AMMO_TEXT_COLOR_MEDIUM_H)
        or (f >= 0.45 and palette.AMMO_TEXT_COLOR_MEDIUM_L)
        or (f >= 0.25 and palette.AMMO_TEXT_COLOR_LOW)
        or palette.AMMO_TEXT_COLOR_CRITICAL

    -- If palette is missing/partial, just bail out gracefully.
    if not new_color then
        _hide_reserve(widget)
        return
    end

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
