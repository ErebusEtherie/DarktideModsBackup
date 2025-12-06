-- File: RingHud/scripts/mods/RingHud/features/pocketable_feature.lua
local mod = get_mod("RingHud")
if not mod then return {} end

local RingHudColors     = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")
local RSBridge          = mod:io_dofile("RingHud/scripts/mods/RingHud/compat/recolor_stimms_bridge")

local PocketableFeature = {}

-- Default tints for known pocketables (ARGB 0..255)
local pocketable_colors = {
    syringe_corruption_pocketable    = { color = mod.PALETTE_ARGB255.HEALTH_GREEN },
    syringe_power_boost_pocketable   = { color = mod.PALETTE_ARGB255.POWER_RED },
    syringe_speed_boost_pocketable   = { color = mod.PALETTE_ARGB255.SPEED_BLUE },
    syringe_ability_boost_pocketable = { color = mod.PALETTE_ARGB255.COOLDOWN_YELLOW },
    medical_crate_pocketable         = { color = mod.PALETTE_ARGB255.HEALTH_GREEN },
    ammo_cache_pocketable            = { color = mod.PALETTE_ARGB255.SPEED_BLUE },
    tome_pocketable                  = { color = mod.PALETTE_ARGB255.TOME_BLUE },
    grimoire_pocketable              = { color = mod.PALETTE_ARGB255.GRIMOIRE_PURPLE },
}

local ALL_COLORS        = {} -- TODO Color? Figure out where this is used
do
    local C  = RingHudColors or {}
    local PA = C.PALETTE or mod.PALETTE_ARGB255

    -- A) entries with .color
    for k, v in pairs(C) do
        if type(v) == "table" and v.color then
            ALL_COLORS[k] = v.color
        end
    end
    -- Also include our local item -> color map so names resolve directly.
    for k, v in pairs(pocketable_colors) do
        if type(v) == "table" and v.color then
            ALL_COLORS[k] = v.color
        end
    end

    -- B) palette keys
    if type(PA) == "table" then
        for name, rgba in pairs(PA) do
            if type(rgba) == "table" and rgba[1] then
                ALL_COLORS[name] = rgba
            end
        end
    end
end

-- Helpers ----------------------------------------------------------

-- Clamp to [0,1] using Darktide's math.lua semantics
local function _clamp01(x)
    return math.clamp(tonumber(x) or 0, 0, 1)
end

-- Map x in [hi .. lo] to [0 .. 255] (0 at >=hi, 255 at <=lo), clamped
local function _opacity_from_interval(x, hi, lo)
    local denom = (hi - lo)
    if denom == 0 then return 0 end
    local t = (hi - (x or 0)) / denom
    t = _clamp01(t)
    return math.floor(255 * t)
end

-- Resolve the *actual* local player's stimm id (matches RS ids) from visual loadout.
local function _current_local_stimm_rs_id()
    local player = Managers.player and Managers.player:local_player_safe(1)
    local unit   = player and player.player_unit
    if not (unit and Unit.alive(unit)) then return nil end

    local vload = ScriptUnit.has_extension(unit, "visual_loadout_system")
        and ScriptUnit.extension(unit, "visual_loadout_system")
    if not vload or not vload.weapon_template_from_slot then return nil end

    local tmpl = vload:weapon_template_from_slot("slot_pocketable_small")
    return tmpl and tmpl.name or nil -- e.g. "syringe_power_boost_pocketable"
end

-- Prefer RecolorStimms color; fallback to RingHud palette
local function _stimm_base_color_argb255(preferred_name)
    local rs_id    = _current_local_stimm_rs_id() or preferred_name
    local entry    = pocketable_colors[rs_id] or pocketable_colors[preferred_name]
    local fallback = (entry and entry.color)
        or ALL_COLORS[rs_id]
        or ALL_COLORS[preferred_name]
        or ALL_COLORS.GENERIC_WHITE
        or { 255, 255, 255, 255 }

    if RSBridge and RSBridge.stimm_argb255 then
        local c = RSBridge.stimm_argb255(rs_id, fallback)
        return c or fallback
    end
    return fallback
end

function PocketableFeature.update(widgets, hud_state, hotkey_override)
    if not (widgets and widgets.stimm_indicator_widget and widgets.crate_indicator_widget) then return end

    local stimm_widget = widgets.stimm_indicator_widget
    local crate_widget = widgets.crate_indicator_widget
    local pocketable_visibility_dropdown = mod._settings.pocketable_visibility_dropdown
    local changed = false

    -- Disabled: hide + clear icons
    if pocketable_visibility_dropdown == "pocketable_disabled" then
        if stimm_widget.style.stimm_icon and stimm_widget.style.stimm_icon.visible then
            stimm_widget.style.stimm_icon.visible = false; changed = true
        end
        if stimm_widget.content.stimm_icon ~= nil then
            stimm_widget.content.stimm_icon = nil; changed = true
        end
        if crate_widget.style.crate_icon and crate_widget.style.crate_icon.visible then
            crate_widget.style.crate_icon.visible = false; changed = true
        end
        if crate_widget.content.crate_icon ~= nil then
            crate_widget.content.crate_icon = nil; changed = true
        end
        if changed then
            stimm_widget.dirty = true; crate_widget.dirty = true
        end
        return
    end

    local stimm_exists = (hud_state.stimm_item_name ~= nil) and (hud_state.stimm_icon_path ~= nil)
    local crate_exists = (hud_state.crate_item_name ~= nil) and (hud_state.crate_icon_path ~= nil)

    local stimm_is_visible, crate_is_visible = false, false
    local stimm_color_override, crate_color_override = nil, nil

    if pocketable_visibility_dropdown == "pocketable_always" then
        -- Always: visible if present
        stimm_is_visible = stimm_exists
        crate_is_visible = crate_exists
    else
        -- Force-show when hotkey override (only if item actually exists)
        if hotkey_override then
            if stimm_exists then stimm_is_visible = true end
            if crate_exists then crate_is_visible = true end
        end

        -- Grimoire: always visible
        if hud_state.crate_item_name == "grimoire_pocketable" then crate_is_visible = true end

        -- Unknown/seasonal items: safest to show when carried
        if stimm_exists and not ALL_COLORS[hud_state.stimm_item_name] then stimm_is_visible = true end
        if crate_exists and not ALL_COLORS[hud_state.crate_item_name] then crate_is_visible = true end

        -- High intensity: highlight power/speed stimms & med/ammo crates
        if hud_state.is_high_intensity_timer_active then
            local stimm_name = hud_state.stimm_item_name
            if stimm_name == "syringe_power_boost_pocketable" or stimm_name == "syringe_speed_boost_pocketable" then
                stimm_is_visible = true
            end
            if hud_state.crate_item_name == "medical_crate_pocketable" or hud_state.crate_item_name == "ammo_cache_pocketable" then
                crate_is_visible = true
            end
        end

        -- Near a source: show the carried item
        if stimm_exists and hud_state.near_any_stimm_source then stimm_is_visible = true end
        if crate_exists and hud_state.near_any_crate_source then crate_is_visible = true end

        -- Recently picked up: burst visible
        if (hud_state.pocketable_pickup_timer or 0) > 0 then
            if hud_state.last_picked_up_pocketable_name == hud_state.stimm_item_name then
                stimm_is_visible = true
            elseif hud_state.last_picked_up_pocketable_name == hud_state.crate_item_name then
                crate_is_visible = true
            end
        end

        -- Corruption stimm: emerge as health is lost (clamped)
        if not stimm_is_visible
            and hud_state.stimm_item_name == "syringe_corruption_pocketable"
            and (hud_state.health_data.current_fraction or 1) <= 0.75
        then
            stimm_is_visible = true
            local base_color = _stimm_base_color_argb255(hud_state.stimm_item_name)
            if base_color then
                local hf = _clamp01(hud_state.health_data.current_fraction or 0)
                local opacity = math.floor(255 * (1.0 - hf))
                if opacity < 0 then opacity = 0 elseif opacity > 255 then opacity = 255 end
                stimm_color_override = { opacity, base_color[2], base_color[3], base_color[4] }
            end
        end

        -- Ability stimm: visible while ability on cooldown; opacity ∝ remaining fraction
        if not stimm_is_visible and hud_state.stimm_item_name == "syringe_ability_boost_pocketable" then
            local timer_data = hud_state.timer_data or {}
            local max_cd = timer_data.max_combat_ability_cooldown or 0
            local rem = timer_data.ability_cooldown_remaining or 0
            if rem > 0 and max_cd > 0 then
                stimm_is_visible = true
                local base_color = _stimm_base_color_argb255(hud_state.stimm_item_name)
                if base_color then
                    local frac = _clamp01(rem / max_cd)
                    local opacity = math.floor(255 * frac)
                    if opacity < 0 then opacity = 0 elseif opacity > 255 then opacity = 255 end
                    stimm_color_override = { opacity, base_color[2], base_color[3], base_color[4] }
                end
            end
        end

        -- Medical crate: more opaque as team health shrinks
        if not crate_is_visible and hud_state.crate_item_name == "medical_crate_pocketable" then
            crate_is_visible = true
            local color_key = mod._settings.medical_crate_color
            local base_color = mod.PALETTE_ARGB255[color_key]
            if base_color then
                local health_fraction = hud_state.team_average_health_fraction or 1
                local opacity = _opacity_from_interval(health_fraction, 0.8, 0.2)
                crate_color_override = { opacity, base_color[2], base_color[3], base_color[4] }
            end
        end

        -- Ammo cache: more opaque as team ammo shrinks
        if not crate_is_visible and hud_state.crate_item_name == "ammo_cache_pocketable" then
            crate_is_visible = true
            local color_key = mod._settings.ammo_cache_color
            local base_color = mod.PALETTE_ARGB255[color_key]
            if base_color then
                local ammo_fraction = hud_state.team_average_ammo_fraction or 1
                local opacity = _opacity_from_interval(ammo_fraction, 0.8, 0.2)
                crate_color_override = { opacity, base_color[2], base_color[3], base_color[4] }
            end
        end
    end

    -- STIMM RENDER
    local stimm_style   = stimm_widget.style.stimm_icon
    local stimm_content = stimm_widget.content
    if stimm_style and stimm_style.visible ~= stimm_is_visible then
        stimm_style.visible = stimm_is_visible; changed = true
    end
    if stimm_is_visible then
        if stimm_content.stimm_icon ~= hud_state.stimm_icon_path then
            stimm_content.stimm_icon = hud_state.stimm_icon_path; changed = true
        end

        -- Use *actual* RS id from local loadout if available
        local rs_id    = _current_local_stimm_rs_id() or hud_state.stimm_item_name
        local fallback = (pocketable_colors[rs_id] and pocketable_colors[rs_id].color)
            or ALL_COLORS[rs_id]
            or ALL_COLORS[hud_state.stimm_item_name]
            or ALL_COLORS.GENERIC_WHITE
            or { 255, 255, 255, 255 }

        local color    = stimm_color_override
            or (RSBridge and RSBridge.stimm_argb255 and RSBridge.stimm_argb255(rs_id, fallback))
            or fallback

        local sc       = stimm_style.color
        if not sc
            or sc[1] ~= color[1]
            or sc[2] ~= color[2]
            or sc[3] ~= color[3]
            or sc[4] ~= color[4]
        then
            stimm_style.color = color; changed = true
        end
    else
        if stimm_content.stimm_icon ~= nil then
            stimm_content.stimm_icon = nil; changed = true
        end
    end

    -- CRATE RENDER (unchanged)
    local crate_style   = crate_widget.style.crate_icon
    local crate_content = crate_widget.content
    if crate_style and crate_style.visible ~= crate_is_visible then
        crate_style.visible = crate_is_visible; changed = true
    end
    if crate_is_visible then
        if crate_content.crate_icon ~= hud_state.crate_icon_path then
            crate_content.crate_icon = hud_state.crate_icon_path; changed = true
        end

        local crate_name = hud_state.crate_item_name
        local color_key  = crate_name
        if crate_name == "medical_crate_pocketable" then
            color_key = mod._settings.medical_crate_color
        elseif crate_name == "ammo_cache_pocketable" then
            color_key = mod._settings.ammo_cache_color
        end

        local color = crate_color_override or (mod.PALETTE_ARGB255[color_key]) or { 255, 255, 255, 255 }
        local cc = crate_style.color
        if not cc
            or cc[1] ~= color[1]
            or cc[2] ~= color[2]
            or cc[3] ~= color[3]
            or cc[4] ~= color[4]
        then
            crate_style.color = color; changed = true
        end
    else
        if crate_content.crate_icon ~= nil then
            crate_content.crate_icon = nil; changed = true
        end
    end

    if changed then
        stimm_widget.dirty = true; crate_widget.dirty = true
    end
end

return PocketableFeature
