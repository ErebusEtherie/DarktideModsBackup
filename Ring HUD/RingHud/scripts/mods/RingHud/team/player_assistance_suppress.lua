-- File: RingHud/scripts/mods/RingHud/team/player_assistance_suppress.lua
local mod = get_mod("RingHud"); if not mod then return end

-- Guard against double-loading
if mod._player_assist_suppress_loaded then return end
mod._player_assist_suppress_loaded = true

-- Modes in which we want the assistance marker hidden
local SUPPRESS_MODES = {
    team_hud_floating         = true,
    team_hud_floating_docked  = true,
    team_hud_floating_vanilla = true,
}

local function _should_suppress()
    local s = mod._settings
    local mode = s and s.team_hud_mode
    return SUPPRESS_MODES[mode] == true
end

-- Suppress the template by gating every pass's visibility_function,
-- and short-circuiting update work while suppressed.
mod:hook_require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_player_assistance",
    function(template)
        -- Wrap widget definition: make every pass respect our suppression gate
        local orig_create = template.create_widget_defintion
        if type(orig_create) == "function" then
            template.create_widget_defintion = function(tpl, scenegraph_id)
                local def = orig_create(tpl, scenegraph_id)
                local passes = def and def.element and def.element.passes
                if passes then
                    for _, pass in ipairs(passes) do
                        local prev_vis = pass.visibility_function
                        pass.visibility_function = function(content, style, ...)
                            if _should_suppress() then
                                return false
                            end
                            return prev_vis and prev_vis(content, style, ...) or true
                        end
                    end
                end
                return def
            end
        end

        -- Optional: skip per-frame work when suppressed (cheap safety net)
        local orig_update = template.update_function
        if type(orig_update) == "function" then
            template.update_function = function(parent, ui_renderer, widget, marker, tpl, dt, t)
                if _should_suppress() then
                    widget.alpha_multiplier = 0 -- ensure nothing leaks through
                    return false
                end
                return orig_update(parent, ui_renderer, widget, marker, tpl, dt, t)
            end
        end
    end)
