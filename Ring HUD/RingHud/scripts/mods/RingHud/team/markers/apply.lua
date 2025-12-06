-- File: RingHud/scripts/mods/RingHud/team/markers/apply.lua
local mod = get_mod("RingHud"); if not mod then return {} end

-- Expose under mod.* for cross-file access (per your rule)
mod.team_marker_apply        = mod.team_marker_apply or {}
local Apply                  = mod.team_marker_apply

-- Read-only deps
local C                      = mod:io_dofile("RingHud/scripts/mods/RingHud/team/constants")
local U                      = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local S                      = mod:io_dofile("RingHud/scripts/mods/RingHud/team/segments")
local TH                     = mod:io_dofile("RingHud/scripts/mods/RingHud/team/throwables")
local TXT                    = mod:io_dofile("RingHud/scripts/mods/RingHud/team/text")
local Notch                  = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")

local UIHudSettings          = require("scripts/settings/ui/ui_hud_settings")

-- ========= Small helpers =========

local DEFAULT_TOUGHNESS_TEAL = mod.PALETTE_ARGB255.TOUGHNESS_TEAL

local function _arch_name_from_profile(profile)
    return profile and profile.archetype and profile.archetype.name
end

-- RingHud status-icon overrides (e.g., pounced)
local STATUS_ICON_OVERRIDES = C.STATUS_ICON_MATERIALS or {}

-- Resolve status icon path: prefer RingHud overrides, then game defaults
local function _status_icon_for(kind)
    if not kind then return nil end
    local over = STATUS_ICON_OVERRIDES and STATUS_ICON_OVERRIDES[kind]
    if over ~= nil then
        return over
    end
    return (UIHudSettings.player_status_icons and UIHudSettings.player_status_icons[kind]) or nil
end

-- Are we in an icon-only floating mode?
local function _is_icon_only_mode()
    local m = mod._settings and mod._settings.team_hud_mode
    return m == "team_hud_icons_vanilla" or m == "team_hud_icons_docked"
end

-- ========= Sections =========

local function _apply_name_and_arch(widget, vm)
    local content, style = widget.content, widget.style
    local changed = false

    if content.arch_icon ~= vm.arch_glyph then
        content.arch_icon = vm.arch_glyph
        changed = true
    end

    if style.arch_icon and style.arch_icon.text_color then
        -- Accept either a palette key or a direct ARGB-255 table in vm.tint_argb255
        local tint = vm.tint_argb255
        local col =
            (type(tint) == "table" and tint) or
            (type(tint) == "string" and mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255[tint]) or
            mod.PALETTE_ARGB255.GENERIC_WHITE
        style.arch_icon.text_color = table.clone(col)
        changed = true
    end

    -- Name from composed markup only (suppressed in icon-only modes)
    local final_name = (_is_icon_only_mode() and "") or ((vm and vm.name_markup) or "")

    if content.name_text_value ~= final_name then
        content.name_text_value = final_name
        changed = true
    end

    if changed then widget.dirty = true end
end

-- Archetype-only (never touches name text)
local function _apply_arch_only(widget, vm)
    local content, style = widget.content, widget.style
    local changed = false

    if content.arch_icon ~= vm.arch_glyph then
        content.arch_icon = vm.arch_glyph
        changed = true
    end

    if style.arch_icon and style.arch_icon.text_color then
        local tint = vm.tint_argb255
        local col =
            (type(tint) == "table" and tint) or
            (type(tint) == "string" and mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255[tint]) or
            mod.PALETTE_ARGB255.GENERIC_WHITE
        style.arch_icon.text_color = table.clone(col)
        changed = true
    end

    -- Ensure name text stays blank in icon-only mode
    if widget.content and widget.content.name_text_value ~= "" then
        widget.content.name_text_value = ""
        changed = true
    end

    if changed then widget.dirty = true end
end

local function _apply_segments(widget, vm)
    local content, style = widget.content, widget.style

    -- Base show/hide (per wounds) + clear all corruption visibility (style overlay decides)
    for seg = 1, C.MAX_HP_SEGMENTS do
        local hp_key = string.format("hp_seg_%d_visible", seg)
        if seg <= C.MAX_WOUNDS_CAP then
            content[hp_key] = seg <= vm.hp.wounds
            content[string.format("cor_seg_%d_visible", seg)] = false
        else
            content[hp_key] = false -- extra (+1) starts hidden; S.update may set its style.visible
        end
    end

    -- Drive style via the shared segment updater (health + corruption overlay + outlines)
    S.update(style, vm.tint_argb255, vm.hp.wounds, vm.hp.hp_frac, vm.hp.cor_frac, vm.hp.tough_state)

    -- Mirror corruption overlay style visibility back to content flags
    for seg = 1, vm.hp.wounds do
        local cs = style[string.format("cor_seg_%d", seg)]
        if cs then content[string.format("cor_seg_%d_visible", seg)] = cs.visible or false end
    end

    -- Extra (+1) HP pass visible only if bars enabled AND S.update marked it visible
    do
        local ex_st = style[string.format("hp_seg_%d", C.MAX_HP_SEGMENTS)]
        content[string.format("hp_seg_%d_visible", C.MAX_HP_SEGMENTS)] = (vm.hp.bars_enabled and ex_st and ex_st.visible) or
            false
    end

    -- If bars are globally disabled, force-hide everything (assist bar may still show later)
    if not vm.hp.bars_enabled then
        for seg = 1, C.MAX_HP_SEGMENTS do
            content[string.format("hp_seg_%d_visible", seg)] = false
            if seg <= C.MAX_WOUNDS_CAP then
                content[string.format("cor_seg_%d_visible", seg)] = false
            end
        end
    end
end

local function _apply_counters(widget, vm)
    local content, style = widget.content, widget.style
    local changed = false

    -- ► Expose per-peer ammo “show until” latch to the widget so text.lua can read it
    local show_until = vm.counters.reserve_show_until
    if content._reserve_show_until ~= show_until then
        content._reserve_show_until = show_until
        changed = true
    end

    TXT.update_ammo(widget, vm.counters.reserve_frac, vm.force_show)
    TXT.update_ability_cd(widget, vm.counters.ability_secs)

    local cd_style = style.ability_cd_text_style
    if cd_style and cd_style.visible ~= (vm.counters.show_cd == true) then
        cd_style.visible = (vm.counters.show_cd == true)
        changed = true
    end

    local tstyle = style.toughness_text_style
    if tstyle then
        local s = tostring(vm.counters.tough_int or 0)
        if content.toughness_text_value ~= s then
            content.toughness_text_value = s
            changed = true
        end

        local col = DEFAULT_TOUGHNESS_TEAL
        if vm.hp.tough_state == "broken" then
            col = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.TOUGHNESS_BROKEN) or col
        elseif vm.hp.tough_state == "overshield" then
            col = (mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255.TOUGHNESS_OVERSHIELD) or col
        end
        if tstyle.text_color then
            tstyle.text_color = table.clone(col)
            changed = true
        end

        local show_tough = (vm.counters.show_tough_text == true)
        if vm.force_show and mod._settings.team_counters ~= "team_counters_disabled" then
            show_tough = true
        end
        if tstyle.visible ~= show_tough then
            tstyle.visible = show_tough
            changed = true
        end
    end

    local hstyle = style.health_value_text_style
    if hstyle and hstyle.visible ~= (vm.hp.text_visible == true) then
        hstyle.visible = (vm.hp.text_visible == true)
        changed = true
    end

    if changed then widget.dirty = true end
end

local function _apply_health_integer(widget, unit)
    local content = widget.content
    local he = unit and ScriptUnit.has_extension(unit, "health_system") and ScriptUnit.extension(unit, "health_system")
    local cur = 0
    if he and he.current_health then
        cur = math.floor((he:current_health() or 0) + 0.5)
    end
    local s = tostring(cur or 0)
    if content.health_value_text ~= s then
        content.health_value_text = s
        widget.dirty = true
    end
end

local function _apply_status(widget, vm)
    local content, style = widget.content, widget.style
    local changed = false

    local kind = vm.status and vm.status.kind
    local icon = _status_icon_for(kind)
    local tint = vm.status and vm.status.icon_color_argb

    if content.status_icon ~= icon then
        content.status_icon = icon
        changed = true
    end

    local sstyle = style.status_icon
    if sstyle then
        sstyle.visible = icon ~= nil
        if tint and sstyle.color then
            -- Accept a palette key or a direct ARGB-255 table
            local col =
                (type(tint) == "table" and tint) or
                (type(tint) == "string" and mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255[tint]) or
                tint
            if col then
                sstyle.color = table.clone(col)
                changed = true
            end
        end
        if tint and content.status_icon_tint ~= tint then
            content.status_icon_tint = tint
            changed = true
        end
    end

    if changed then widget.dirty = true end
end

-- ======== assist / ledge / respawn bar (split base+edge with notch) ========
local function _apply_assist_or_respawn(widget, vm)
    local content, style = widget.content, widget.style

    local base_style = style.ledge_bar_base
    local edge_style = style.ledge_bar_edge
    if not (base_style and base_style.material_values and edge_style and edge_style.material_values) then
        if content.ledge_bar_visible or content.ledge_bar_base_visible or content.ledge_bar_edge_visible then
            content.ledge_bar_visible      = false
            content.ledge_bar_base_visible = false
            content.ledge_bar_edge_visible = false
            if base_style then base_style.visible = false end
            if edge_style then edge_style.visible = false end
            widget.dirty = true
        end
        return
    end

    if vm.assist.show then
        -- Hide ALL hp/cor segments while the assist bar is visible
        for seg = 1, C.MAX_HP_SEGMENTS do
            content[string.format("hp_seg_%d_visible", seg)] = false
            if seg <= C.MAX_WOUNDS_CAP then
                content[string.format("cor_seg_%d_visible", seg)] = false
            end
        end

        -- Root visibility flag
        if not content.ledge_bar_visible then
            content.ledge_bar_visible = true
            widget.dirty = true
        end

        -- Full parent arc envelope (don’t trust seeded state)
        local full_ab                   = U.seg_arc_range(1, 1)
        local parent_top, parent_bottom = full_ab[1], full_ab[2]

        -- Use shared helper to split base(1) + edge(0) with a centered gap.
        -- Optional overrides: vm.assist.gap / vm.assist.eps
        local frac                      = math.clamp(vm.assist.amount or 0, 0, 1)
        local gap                       = vm.assist.gap
        local eps                       = vm.assist.eps
        local res                       = Notch.notch_apply(
            widget,
            "ledge_bar_base", "ledge_bar_edge",
            frac, parent_top, parent_bottom,
            gap, eps,
            { base = "ledge_bar_base_visible", edge = "ledge_bar_edge_visible" }
        )

        -- Mirror to style.visible for renderers that check style + content
        base_style.visible              = res.base.show
        edge_style.visible              = res.edge.show

        -- Outline color (apply to both passes, RGBA 0..1)
        local src                       = vm.assist.outline_rgba01 or { 1, 0, 0, 1 }
        local function _set_outline(mv)
            local oc = mv.outline_color
            if (not oc) or oc[1] ~= src[1] or oc[2] ~= src[2] or oc[3] ~= src[3] or oc[4] ~= src[4] then
                mv.outline_color = { src[1], src[2], src[3], src[4] }
                widget.dirty = true
            end
        end
        _set_outline(base_style.material_values)
        _set_outline(edge_style.material_values)

        -- Respawn digits replace archetype glyph while active
        if vm.assist.respawn_digits then
            if content.status_icon ~= nil then
                content.status_icon = nil
                widget.dirty = true
            end
            if content.arch_icon ~= vm.assist.respawn_digits then
                content.arch_icon = vm.assist.respawn_digits
                widget.dirty = true
            end
        end
    else
        -- Turn everything off
        local changed = false
        if content.ledge_bar_visible then
            content.ledge_bar_visible = false; changed = true
        end
        if content.ledge_bar_base_visible then
            content.ledge_bar_base_visible = false; changed = true
        end
        if content.ledge_bar_edge_visible then
            content.ledge_bar_edge_visible = false; changed = true
        end
        if base_style and base_style.visible then
            base_style.visible = false; changed = true
        end
        if edge_style and edge_style.visible then
            edge_style.visible = false; changed = true
        end
        if changed then widget.dirty = true end
    end
end

local function _apply_pockets(widget, vm)
    local content, style = widget.content, widget.style
    local changed = false

    -- Crates
    local cstyle = style.crate_icon
    if cstyle then
        if vm.pockets.crate_enabled and vm.pockets.crate_icon then
            content.crate_icon = vm.pockets.crate_icon
            if cstyle.color and vm.pockets.crate_color_argb then
                local tint = vm.pockets.crate_color_argb
                local col =
                    (type(tint) == "table" and tint) or
                    (type(tint) == "string" and mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255[tint]) or
                    tint
                if col then
                    cstyle.color = table.clone(col)
                    changed = true
                end
            end
            if not cstyle.visible then
                cstyle.visible = true; changed = true
            end
        else
            if cstyle.visible then
                cstyle.visible = false; changed = true
            end
            if content.crate_icon ~= nil then
                content.crate_icon = nil; changed = true
            end
        end
    end

    -- Stimms
    local sstyle = style.stimm_icon
    if sstyle then
        if vm.pockets.stimm_enabled and vm.pockets.stimm_icon then
            content.stimm_icon = vm.pockets.stimm_icon
            if sstyle.color and vm.pockets.stimm_color_argb then
                local tint = vm.pockets.stimm_color_argb
                local col =
                    (type(tint) == "table" and tint) or
                    (type(tint) == "string" and mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255[tint]) or
                    tint
                if col then
                    sstyle.color = table.clone(col)
                    changed = true
                end
            end
            if not sstyle.visible then
                sstyle.visible = true; changed = true
            end
        else
            if sstyle.visible then
                sstyle.visible = false; changed = true
            end
            if content.stimm_icon ~= nil then
                content.stimm_icon = nil; changed = true
            end
        end
    end

    if changed then widget.dirty = true end
end

-- ========= Public helpers =========

function Apply.apply_name(name_widget, vm)
    if not (name_widget and name_widget.content) then return end
    -- Name from composed markup only
    local s = (vm and vm.name_markup) or ""

    if name_widget.content.name_text_value ~= s then
        name_widget.content.name_text_value = s
        name_widget.dirty = true
    end
end

-- ========= Public: one-stop apply =========

function Apply.apply_all(widget, marker, vm, opts)
    if not (widget and vm and vm.ok) then
        widget.visible = false
        return
    end
    widget.visible = true

    local icon_only = _is_icon_only_mode()

    if icon_only then
        -- Minimal: archetype icon + status icon. Suppress everything else.
        _apply_arch_only(widget, vm)
        _apply_status(widget, vm)

        -- Make sure prominent non-icon fields remain blank/hidden if they were ever set
        local content, style = widget.content, widget.style
        if content then
            if content.toughness_text_value ~= nil then content.toughness_text_value = nil end
            if content.health_value_text ~= nil then content.health_value_text = nil end
            -- Hide any stray HP/corruption flags
            for seg = 1, C.MAX_HP_SEGMENTS do
                content[string.format("hp_seg_%d_visible", seg)] = false
                if seg <= C.MAX_WOUNDS_CAP then
                    content[string.format("cor_seg_%d_visible", seg)] = false
                end
            end
            -- Clear pockets/throwable seeds if present
            if content.crate_icon ~= nil then content.crate_icon = nil end
            if content.stimm_icon ~= nil then content.stimm_icon = nil end
            if content.throwable_icon ~= nil then content.throwable_icon = nil end
        end
        if style then
            if style.toughness_text_style then style.toughness_text_style.visible = false end
            if style.health_value_text_style then style.health_value_text_style.visible = false end
            if style.crate_icon then style.crate_icon.visible = false end
            if style.stimm_icon then style.stimm_icon.visible = false end
            if style.ledge_bar_base then style.ledge_bar_base.visible = false end
            if style.ledge_bar_edge then style.ledge_bar_edge.visible = false end
            -- HP segment styles are managed by template/S.update; letting content flags be false is enough
        end

        widget.dirty = true
        return
    end

    -- Full tile path
    _apply_name_and_arch(widget, vm)
    _apply_segments(widget, vm)
    _apply_counters(widget, vm)

    if opts and opts.unit then
        _apply_health_integer(widget, opts.unit)
    end

    _apply_status(widget, vm)
    _apply_assist_or_respawn(widget, vm)

    local arch_name = _arch_name_from_profile(vm.profile)
    if widget.style and widget.style.throwable_icon then
        TH.update(widget.style.throwable_icon, arch_name, opts and opts.unit)
        local override = TH.icon_override_for(opts and opts.unit, arch_name)
        if widget.content and widget.content.throwable_icon ~= override then
            widget.content.throwable_icon = override
            widget.dirty = true
        end
    end

    _apply_pockets(widget, vm)

    widget.dirty = true
end

return Apply
