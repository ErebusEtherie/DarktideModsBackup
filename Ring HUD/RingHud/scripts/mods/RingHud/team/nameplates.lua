-- File: RingHud/scripts/mods/RingHud/team/nameplates.lua
local mod = get_mod("RingHud"); if not mod then return end

-- Avoid duplicate installations across reloads.
if mod._nameplate_hooks_installed then
    return
end

local UIHudSettings        = require("scripts/settings/ui/ui_hud_settings")
local UISettings           = require("scripts/settings/ui/ui_settings")

-- Pull the exact font/size used by RingHud's team tile archetype icon,
-- so nameplates match it 1:1 in "docked" mode.
local W                    = mod:io_dofile("RingHud/scripts/mods/RingHud/team/widgets")
local _TEAM_ARCH_FONT_TYPE = "machine_medium"
local _TEAM_ARCH_FONT_SIZE = nil
do
    -- Fallback to the same constant used in widgets.lua (C.TILE_SIZE / 5.5)
    local C = mod:io_dofile("RingHud/scripts/mods/RingHud/team/constants")
    _TEAM_ARCH_FONT_SIZE = math.floor((C and C.TILE_SIZE or 180) / 5.5 + 0.5)
end

-- Hook both party & combat nameplate templates.
local TEMPLATES = {
    "scripts/ui/hud/elements/world_markers/templates/world_marker_template_nameplate_party",
    "scripts/ui/hud/elements/world_markers/templates/world_marker_template_nameplate_combat",
}

local function _glyph_for_profile(profile)
    if not profile then return "?" end
    local arch = profile.archetype and profile.archetype.name
    -- Prefer simple icons (good visual match with RingHUD tiles), fallback to full icons.
    local glyph = (arch and UISettings.archetype_font_icon_simple and UISettings.archetype_font_icon_simple[arch])
        or (arch and UISettings.archetype_font_icon and UISettings.archetype_font_icon[arch])
        or "?"
    return glyph
end

local function _slot_tint(player_or_slot_index)
    local slot_index = type(player_or_slot_index) == "table" and
        (player_or_slot_index.slot and player_or_slot_index:slot()) or player_or_slot_index
    local slot_colors = UISettings.player_slot_colors or UIHudSettings
    local tint = (slot_colors and slot_colors[slot_index or 1]) or mod.PALETTE_ARGB255.GENERIC_WHITE
    return tint
end

-- ########################
-- Bot / unit helpers
-- ########################
local function _unit_from_marker(marker)
    if not marker then return nil end
    if marker.unit then return marker.unit end
    local player = marker.data
    if player and player.player_unit then return player.player_unit end
    if player and Managers.player and player.profile and player:profile() then
        local u = player.player_unit
        if u then return u end
    end
    return nil
end

local function _is_bot_player_by_unit(unit)
    local player = Managers.player and Managers.player:player_by_unit(unit)
    if not player then return false end

    if player.is_human_controlled then
        local ok, human = pcall(function() return player:is_human_controlled() end)
        if ok then return not human end
    end
    if player.is_bot_player then
        local ok, is_bot = pcall(function() return player:is_bot_player() end)
        if ok then return is_bot end
    end
    if player.is_bot then
        local ok, is_bot = pcall(function() return player:is_bot() end)
        if ok then return is_bot end
    end

    return false
end

-- ########################
-- Looks
-- ########################
local function _apply_docked(widget, marker)
    -- Icon-only (archetype glyph) tinted by slot color, and with the SAME font size/type
    -- RingHud uses for the team tile's archetype icon.
    local content = widget and widget.content
    local style   = widget and widget.style
    if not (content and style and marker and marker.data) then return end

    local player  = marker.data
    local profile = player.profile and player:profile() or nil
    local glyph   = _glyph_for_profile(profile)
    local tint    = _slot_tint(player)

    -- Ensure visible if previously blanked
    if widget.alpha_multiplier == 0 then widget.alpha_multiplier = 1 end

    -- Set both header_text and icon_text (different templates use different fields)
    if content.header_text ~= glyph then content.header_text = glyph end
    if content.icon_text ~= glyph then content.icon_text = glyph end

    -- Apply RingHud team-arch font to whichever text style exists
    if style.header_text then
        if _TEAM_ARCH_FONT_TYPE then style.header_text.font_type = _TEAM_ARCH_FONT_TYPE end
        if _TEAM_ARCH_FONT_SIZE then style.header_text.font_size = _TEAM_ARCH_FONT_SIZE end
        if style.header_text.text_color then style.header_text.text_color = tint end
    end
    if style.icon_text then
        if _TEAM_ARCH_FONT_TYPE then style.icon_text.font_type = _TEAM_ARCH_FONT_TYPE end
        if _TEAM_ARCH_FONT_SIZE then style.icon_text.font_size = _TEAM_ARCH_FONT_SIZE end
        if style.icon_text.text_color then style.icon_text.text_color = tint end
    end

    -- If template exposes a generic "icon" style with 'color' (rare), tint that too.
    if style.icon and style.icon.color then style.icon.color = tint end

    -- Kill any secondary/subtitle strings some templates add.
    if content.description_text and content.description_text ~= "" then
        content.description_text = ""
    end

    widget.dirty = true
end

local function _apply_floating(widget, marker)
    -- Blank the plate so it doesn't interfere with our floating tiles (for HUMANS).
    local content = widget and widget.content
    local style   = widget and widget.style
    if not (content and style) then return end

    content.header_text = ""
    content.icon_text   = ""
    if content.description_text then content.description_text = "" end

    -- Alpha 0 for good measure.
    if style.header_text and style.header_text.text_color then style.header_text.text_color[1] = 0 end
    if style.icon_text and style.icon_text.text_color then style.icon_text.text_color[1] = 0 end
    if style.icon and style.icon.color then style.icon.color[1] = 0 end

    widget.alpha_multiplier = 0
    widget.dirty = true
end

-- For BOTS in any enabled mode: show the vanilla default icon only (no archetype glyph) and tint it.
local function _apply_bot_icon_only(widget, marker)
    local content = widget and widget.content
    local style   = widget and widget.style
    if not (content and style) then return end

    local unit   = _unit_from_marker(marker)
    local player = unit and Managers.player and Managers.player:player_by_unit(unit) or nil
    local tint   = _slot_tint(player and player:slot() or 1)
    local dirty  = false

    -- Hide/clear any text-driven glyphs
    if content.header_text and content.header_text ~= "" then
        content.header_text = ""; dirty = true
    end
    if content.icon_text and content.icon_text ~= "" then
        content.icon_text = ""; dirty = true
    end
    if style.header_text and style.header_text.text_color and style.header_text.text_color[1] ~= 0 then
        style.header_text.text_color[1] = 0; dirty = true
    end
    if style.icon_text and style.icon_text.text_color and style.icon_text.text_color[1] ~= 0 then
        style.icon_text.text_color[1] = 0; dirty = true
    end

    -- Ensure a non-text "icon" is visible and tinted (this is the template's default icon)
    local icon_style_key = nil
    for _, k in ipairs({ "icon", "icon_frame", "player_icon", "nameplate_icon" }) do
        if style[k] then
            icon_style_key = k; break
        end
    end
    if icon_style_key then
        local st = style[icon_style_key]
        if st.visible == false then
            st.visible = true; dirty = true
        end
        if st.color then
            st.color = tint; dirty = true
        elseif st.text_color then
            st.text_color = tint; dirty = true
        end
    end

    if widget.alpha_multiplier == 0 then
        widget.alpha_multiplier = 1; dirty = true
    end

    if dirty then widget.dirty = true end
end

-- Install per-template hooks (once).
for _, path in ipairs(TEMPLATES) do
    mod:hook_require(path, function(template)
        -- Only one hook per method per template → no rehook warnings.
        if template and template.on_enter and not template._ringhud_wrapped_on_enter then
            template._ringhud_wrapped_on_enter = true

            mod:hook(template, "on_enter", function(func, widget, marker, ...)
                -- Call original first to let the template populate content/style.
                func(widget, marker, ...)

                local mode   = mod._settings.team_hud_mode
                local unit   = _unit_from_marker(marker)
                local is_bot = unit and _is_bot_player_by_unit(unit) or false

                if mode ~= "team_hud_disabled" and is_bot then
                    -- Bots: always icon-only tinted default icon (both docked & floating)
                    _apply_bot_icon_only(widget, marker)
                else
                    -- Humans: follow RingHud mode
                    if mode == "team_hud_docked" then
                        _apply_docked(widget, marker)
                    elseif mode == "team_hud_floating"
                        or mode == "team_hud_floating_docked"
                        or mode == "team_hud_icons_vanilla" -- NEW
                        or mode == "team_hud_icons_docked"  -- NEW
                    then
                        _apply_floating(widget, marker)
                    else
                        -- disabled / floating_vanilla → vanilla
                    end
                end
            end)
        end

        -- Also react in update so mid-mission setting flips are reflected immediately.
        if template and template.update_function and not template._ringhud_wrapped_update then
            template._ringhud_wrapped_update = true

            mod:hook(template, "update_function", function(func, parent, ui_renderer, widget, marker, cached, dt, t, ...)
                -- Run original first, then enforce our styling so we win last-write.
                local ret    = func(parent, ui_renderer, widget, marker, cached, dt, t, ...)

                local mode   = mod._settings.team_hud_mode
                local unit   = _unit_from_marker(marker)
                local is_bot = unit and _is_bot_player_by_unit(unit) or false

                if mode ~= "team_hud_disabled" and is_bot then
                    _apply_bot_icon_only(widget, marker)
                else
                    if mode == "team_hud_floating"
                        or mode == "team_hud_floating_docked"
                        or mode == "team_hud_icons_vanilla" -- NEW
                        or mode == "team_hud_icons_docked"  -- NEW
                    then
                        _apply_floating(widget, marker)
                    elseif mode == "team_hud_docked" then
                        _apply_docked(widget, marker)
                    end
                end

                return ret
            end)
        end
    end)
end

-- Called by RingHud.lua's central on_setting_changed(...).
-- We keep it lightweight: update logic re-applies every frame, so no cache pull here.
function mod._nameplates_apply_settings(setting_id)
    -- Intentionally empty: presence is enough for the central dispatcher.
    -- If we later add per-frame perf optimizations, we can toggle local flags here.
end

mod._nameplate_hooks_installed = true
