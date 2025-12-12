-- File: RingHud/scripts/mods/RingHud/systems/player_assistance_suppress.lua
local mod = get_mod("RingHud"); if not mod then return end

-- Guard against double-loading
if mod._player_assist_suppress_loaded then return end
mod._player_assist_suppress_loaded = true

-- Helper: does the current team_name_icon layout enable status icons?
-- Matches the semantics used in RingHud.lua:_refresh_assistance_markers_visibility:
-- these four presets all mean "status icons on".
local function _icons_setting_has_status()
    local s = mod._settings
    if not s then
        return false
    end

    local icon_setting = s.team_name_icon
    if type(icon_setting) ~= "string" then
        return false
    end

    return icon_setting == "name0_icon1_status1"
        or icon_setting == "name0_icon0_status1"
        or icon_setting == "name1_icon1_status1"
        or icon_setting == "name1_icon0_status1"
end

-- Helper: is the current layout using floating RingHud tiles?
-- (We prefer the central helper if present, and do NOT tie this to any HP/munitions/pockets policy.)
local function _layout_allows_suppression()
    if type(mod.is_floating_team_tiles_enabled) == "function" then
        return mod.is_floating_team_tiles_enabled()
    end

    -- Fallback: infer from raw settings if the helper isn't defined yet.
    local s = mod._settings
    if not s then return false end

    local m = s.team_hud_mode
    return m == "team_hud_floating"
        or m == "team_hud_floating_docked"
        or m == "team_hud_floating_thin"
    -- NOTE: we deliberately do NOT treat "team_hud_floating_vanilla" as a RingHud-floating mode here,
    -- so the vanilla assistance markers remain when using vanilla nameplates.
end

local function _should_suppress()
    -- Suppression is active ONLY if:
    --   • RingHud floating teammate tiles are in use (layout), AND
    --   • The team_name_icon preset provides status icons (policy).
    if not _layout_allows_suppression() then
        return false
    end

    if not _icons_setting_has_status() then
        return false
    end

    return true
end

-- Suppress the template by gating every pass's visibility_function,
-- and short-circuiting update work while suppressed.
mod:hook_require(
    "scripts/ui/hud/elements/world_markers/templates/world_marker_template_player_assistance",
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
    end
)
