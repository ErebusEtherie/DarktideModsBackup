-- File: RingHud/scripts/mods/RingHud/team/ping_suppress.lua
local mod = get_mod("RingHud")
if not mod then return end

-- Guard against double-loading
if mod._ping_suppress_loaded then
    return
end
mod._ping_suppress_loaded = true

----------------------------------------------------------------
-- Threat skull “mute” (unit threat markers)
-- Uses cached settings from RingHud.lua; no live mod:get.
-- We mute skulls whenever the team HUD is NOT explicitly disabled.
----------------------------------------------------------------

-- Apply “hide” tweaks to a template’s widget definition
local function _mute_skull_visuals(widget_def)
    if mod._settings.team_hud_mode == "team_hud_disabled" or type(widget_def) ~= "table" then
        return widget_def
    end

    local style = widget_def.style
    if not style then
        return widget_def
    end

    local function zero_icon(style_entry)
        if not style_entry then return end
        if style_entry.size then style_entry.size[1], style_entry.size[2] = 0, 0 end
        if style_entry.default_size then style_entry.default_size[1], style_entry.default_size[2] = 0, 0 end
        style_entry.visible = false
    end

    -- Known skull icon style keys in threat templates
    zero_icon(style.icon)
    zero_icon(style.entry_icon_1)
    zero_icon(style.entry_icon_2)

    -- Keep numbers/text aligned after removing the skull:
    local function reset_y(entry)
        if not entry then return end
        local off = entry.offset
        if type(off) == "table" then
            off[2] = 0
        end
        local doff = entry.default_offset
        if type(doff) == "table" then
            doff[2] = 0
        elseif off then
            -- create a default_offset mirroring current x/z to keep engine happy
            entry.default_offset = { off[1] or 0, 0, off[3] or 0 }
        end
    end

    -- Different templates sometimes use different text keys; try both.
    reset_y(style.text)
    reset_y(style.header_text)

    return widget_def
end

-- Wrap a given template module’s create function (for “mute” behavior)
local function wrap_template(module_path)
    mod:hook_require(module_path, function(template)
        local create = template and template.create_widget_defintion
        if type(create) ~= "function" then
            return
        end
        template.create_widget_defintion = function(tpl, scenegraph_id)
            local def = create(tpl, scenegraph_id)
            return _mute_skull_visuals(def)
        end
    end)
end

-- Vanilla threat markers we want to mute:
wrap_template("scripts/ui/hud/elements/world_markers/templates/world_marker_template_unit_threat")
wrap_template("scripts/ui/hud/elements/world_markers/templates/world_marker_template_unit_threat_veteran")
wrap_template("scripts/ui/hud/elements/world_markers/templates/world_marker_template_unit_threat_adamant")

-- (Intentionally no player-assistance suppression here.)
-- That hook now lives exclusively in:
--   RingHud/scripts/mods/RingHud/team/player_assistance_suppress.lua
