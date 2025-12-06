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

        local template = self._crosshair_templates and self._crosshair_templates[self._crosshair_type]
        if not template or not template.name then return end

        local style = widget.style
        local c = table.clone(color)

        local name = template.name
        -- Charge-up styles (e.g. plasma, helbore charge rings)
        if name == "charge_up" or name == "charge_up_ads" then
            if style.charge_mask_right then style.charge_mask_right.color = c end
            if style.charge_mask_left then style.charge_mask_left.color = c end

            -- Common 4-tick crosshair variants
        elseif name == "flamer" or name == "shotgun_wide" or name == "spray_n_pray"
            or name == "assault" or name == "cross" or name == "shotgun"
        then
            if style.left then style.left.color = c end
            if style.right then style.right.color = c end
            if style.top then style.top.color = c end
            if style.bottom then style.bottom.color = c end
        end

        widget.dirty = true
    end)
end

return Crosshair
