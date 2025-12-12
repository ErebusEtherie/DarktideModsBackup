-- File: RingHud/scripts/mods/RingHud/features/crosshair_feature.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Public namespace (cross-file): attach to `mod.` per your rule.
mod.crosshair = mod.crosshair or {}
local Crosshair = mod.crosshair

-- Private state
Crosshair._installed = Crosshair._installed or false
Crosshair._dx = 0
Crosshair._dy = 0
Crosshair._override_color = nil

-- Public API ---------------------------------------------------------------

-- Returns latest crosshair deltas latched from the vanilla crosshair util.
function Crosshair.get_offset()
    return Crosshair._dx or 0, Crosshair._dy or 0
end

-- Set or clear the vanilla crosshair override color (expects ARGB255 table).
function Crosshair.set_override_color(color_argb255_or_nil)
    Crosshair._override_color = color_argb255_or_nil and table.clone(color_argb255_or_nil) or nil
end

function Crosshair.clear_override_color()
    Crosshair._override_color = nil
end

-- Optional convenience getter (for UI code that wants to branch quickly).
function Crosshair.has_override_color()
    return Crosshair._override_color ~= nil
end

-- Installation (hooks) -----------------------------------------------------

function Crosshair.init()
    if Crosshair._installed then
        return
    end
    Crosshair._installed = true

    local CrosshairUtil = require("scripts/ui/utilities/crosshair")

    -- 1) Latch vanilla crosshair deltas so HUD elements can “shake” with it.
    if CrosshairUtil and CrosshairUtil.position then
        mod:hook(CrosshairUtil, "position",
            function(func, dt, t, ui_hud, ui_renderer, current_x, current_y, pivot_position)
                local final_x, final_y = func(dt, t, ui_hud, ui_renderer, current_x, current_y, pivot_position)
                Crosshair._dx = final_x or 0
                Crosshair._dy = final_y or 0
                return final_x, final_y
            end)
    end

    -- 2) Vanilla crosshair recolor (safe, template-aware).
    mod:hook_safe(CLASS.HudElementCrosshair, "update", function(self)
        local color = Crosshair._override_color
        if not color then return end

        local widget = self._widget
        if not widget or not widget.style then return end

        local style = widget.style
        local r, g, b = color[2], color[3], color[4]

        -- Apply RGB tint to common crosshair parts while preserving their current Alpha.
        -- This ensures we support Dot (Force Swords), Projectiles, and standard crosses,
        -- without breaking vanilla fade/spread animations.
        local function _tint(style_id)
            local pass_style = style[style_id]
            if pass_style and pass_style.color then
                pass_style.color[2] = r
                pass_style.color[3] = g
                pass_style.color[4] = b
            end
        end

        _tint("charge_mask_left")
        _tint("charge_mask_right")
        _tint("left")
        _tint("right")
        _tint("top")
        _tint("bottom")
        _tint("dot")
        _tint("center")

        widget.dirty = true
    end)
end

return Crosshair
