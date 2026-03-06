-- File: RingHud/scripts/mods/RingHud/team/markers/apply.lua
local mod = get_mod("RingHud"); if not mod then return {} end

if mod.team_marker_apply then
    return mod.team_marker_apply
end

mod.team_marker_apply       = mod.team_marker_apply or {}
local Apply                 = mod.team_marker_apply

local C                     = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
local U                     = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local S                     = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_health")
local TH                    = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_grenades")
local TXT                   = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_ability")
local AM                    = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_ammo")
local TT                    = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_toughness")
local Notch                 = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")

local UIHudSettings         = require("scripts/settings/ui/ui_hud_settings")

local _hp_seg_visible_keys  = {}
local _cor_seg_visible_keys = {}
local _hp_seg_style_keys    = {}
local _cor_seg_style_keys   = {}

for seg = 1, C.MAX_HP_SEGMENTS do
    _hp_seg_visible_keys[seg] = string.format("hp_seg_%d_visible", seg)
    _hp_seg_style_keys[seg]   = string.format("hp_seg_%d", seg)
    if seg <= C.MAX_WOUNDS_CAP then
        _cor_seg_visible_keys[seg] = string.format("cor_seg_%d_visible", seg)
        _cor_seg_style_keys[seg]   = string.format("cor_seg_%d", seg)
    end
end

-- ========= Small helpers =========

local function _arch_name_from_profile(profile)
    return profile and profile.archetype and profile.archetype.name
end

-- RingHud status-icon overrides (e.g., pounced)
local STATUS_ICON_OVERRIDES = C.STATUS_ICON_MATERIALS or {}

local function _status_icon_for(kind)
    if not kind then return nil end
    local over = STATUS_ICON_OVERRIDES and STATUS_ICON_OVERRIDES[kind]
    if over ~= nil then
        return over
    end
    return (UIHudSettings.player_status_icons and UIHudSettings.player_status_icons[kind]) or nil
end

-- ========= Sections =========

-- Name + archetype glyph
-- IMPORTANT: name_text_value is fully markup-driven (RingHud_state_team.name_markup),
-- including slot tint and optional glyph prefix. This function must NOT recolour
-- the name text style; it only sets the string.
local function _apply_name_and_arch(widget, RingHud_state_team)
    local content, style = widget.content, widget.style
    local changed = false

    if content.arch_icon ~= RingHud_state_team.arch_glyph then
        content.arch_icon = RingHud_state_team.arch_glyph
        changed = true
    end

    if style.arch_icon and style.arch_icon.text_color then
        local tint = RingHud_state_team.tint_argb255
        local col =
            (type(tint) == "table" and tint) or
            (type(tint) == "string" and mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255[tint]) or
            mod.PALETTE_ARGB255.GENERIC_WHITE
        changed = U.set_style_text_color(style.arch_icon, col) or changed
    end

    local final_name = (RingHud_state_team and RingHud_state_team.name_markup) or ""

    if content.name_text_value ~= final_name then
        content.name_text_value = final_name
        changed = true
    end

    -- VISIBILITY CHECK FOR BIG ICON
    if style.arch_icon then
        local visible = (RingHud_state_team.status.show_icon == false)

        if RingHud_state_team.show_arch_icon_widget == false then
            visible = false
        end

        if style.arch_icon.visible ~= visible then
            style.arch_icon.visible = visible
            changed = true
        end
    end

    if changed then widget.dirty = true end
end

local function _apply_arch_only(widget, RingHud_state_team)
    local content, style = widget.content, widget.style
    local changed = false

    if content.arch_icon ~= RingHud_state_team.arch_glyph then
        content.arch_icon = RingHud_state_team.arch_glyph
        changed = true
    end

    if style.arch_icon and style.arch_icon.text_color then
        local tint = RingHud_state_team.tint_argb255
        local col =
            (type(tint) == "table" and tint) or
            (type(tint) == "string" and mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255[tint]) or
            mod.PALETTE_ARGB255.GENERIC_WHITE
        changed = U.set_style_text_color(style.arch_icon, col) or changed
    end

    if widget.content and widget.content.name_text_value ~= "" then
        widget.content.name_text_value = ""
        changed = true
    end

    if changed then widget.dirty = true end
end

local function _apply_segments(widget, RingHud_state_team)
    local content, style = widget.content, widget.style
    if not (content and style and RingHud_state_team and RingHud_state_team.hp) then return end

    local bars_enabled = RingHud_state_team.hp.bars_enabled == true
    local wounds       = RingHud_state_team.hp.wounds or 1
    local changed      = false

    for seg = 1, C.MAX_HP_SEGMENTS do
        local hp_key  = _hp_seg_visible_keys[seg]
        local cor_key = _cor_seg_visible_keys[seg]

        if seg <= C.MAX_WOUNDS_CAP then
            local want_hp = bars_enabled and (seg <= wounds)
            if content[hp_key] ~= want_hp then
                content[hp_key] = want_hp
                changed = true
            end
            if cor_key and content[cor_key] ~= false then
                content[cor_key] = false
                changed = true
            end
        else
            if content[hp_key] ~= false then
                content[hp_key] = false
                changed = true
            end
        end
    end

    if not bars_enabled then
        for seg = 1, C.MAX_HP_SEGMENTS do
            local hp_s = style[_hp_seg_style_keys[seg]]
            local co_s = style[_cor_seg_style_keys[seg]]
            if hp_s and U.set_style_visible(hp_s, false) then changed = true end
            if co_s and U.set_style_visible(co_s, false) then changed = true end
        end
        if changed then widget.dirty = true end
        return
    end

    S.update(
        style,
        RingHud_state_team.tint_argb255,
        wounds,
        RingHud_state_team.hp.hp_frac,
        RingHud_state_team.hp.cor_frac,
        RingHud_state_team.hp.tough_state
    )

    for seg = 1, wounds do
        local cs = style[_cor_seg_style_keys[seg]]
        if cs then
            local is_vis = cs.visible or false
            local cor_key = _cor_seg_visible_keys[seg]
            if cor_key and content[cor_key] ~= is_vis then
                content[cor_key] = is_vis
                changed = true
            end
        end
    end

    local ex_st = style[_hp_seg_style_keys[C.MAX_HP_SEGMENTS]]
    local ex_vis = ex_st and ex_st.visible or false
    local extra_vis_key = _hp_seg_visible_keys[C.MAX_HP_SEGMENTS]
    if content[extra_vis_key] ~= ex_vis then
        content[extra_vis_key] = ex_vis
        changed = true
    end

    if changed then widget.dirty = true end
end

local function _apply_counters(widget, RingHud_state_team, marker)
    local content, style = widget.content, widget.style
    local changed = false

    local peer_id = RingHud_state_team.peer_id
        or RingHud_state_team.peer
        or (marker and (marker.peer_id or marker.peer))
        or nil

    AM.update_ammo(widget, RingHud_state_team.counters.reserve_frac, peer_id)

    TXT.update_ability_cd(widget, RingHud_state_team.counters.ability_secs, RingHud_state_team.counters.show_cd)

    TT.update_text(
        widget,
        RingHud_state_team.counters.tough_int,
        RingHud_state_team.hp.tough_state,
        RingHud_state_team.force_show
    )

    local tstyle = style.toughness_text_style
    if tstyle and tstyle.visible ~= (RingHud_state_team.counters.show_tough_text == true) then
        tstyle.visible = (RingHud_state_team.counters.show_tough_text == true)
        changed = true
    end

    local hstyle = style.health_value_text_style
    if hstyle and hstyle.visible ~= (RingHud_state_team.hp.text_visible == true) then
        hstyle.visible = (RingHud_state_team.hp.text_visible == true)
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

local function _apply_status(widget, RingHud_state_team)
    local content, style = widget.content, widget.style
    local changed        = false

    local status         = RingHud_state_team.status or {}
    local kind           = status.kind
    local tint           = status.icon_color_argb

    local show_icon      = (status.show_icon ~= false) and (kind ~= nil)
    local icon           = nil
    if show_icon then
        icon = _status_icon_for(kind)
    end

    if content.status_icon ~= icon then
        content.status_icon = icon
        changed = true
    end

    local sstyle = style.status_icon
    if sstyle then
        sstyle.visible = (icon ~= nil)
        if tint and sstyle.color then
            local col =
                (type(tint) == "table" and tint) or
                (type(tint) == "string" and mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255[tint]) or
                tint
            if col then
                changed = U.set_style_color(sstyle, col) or changed
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
local function _apply_assist_or_respawn(widget, RingHud_state_team)
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

    if RingHud_state_team.assist.show then
        for seg = 1, C.MAX_HP_SEGMENTS do
            content[_hp_seg_visible_keys[seg]] = false
            if seg <= C.MAX_WOUNDS_CAP then
                content[_cor_seg_visible_keys[seg]] = false
            end
        end

        if not content.ledge_bar_visible then
            content.ledge_bar_visible = true
            widget.dirty = true
        end

        local full_ab                   = U.seg_arc_range(1, 1)
        local parent_top, parent_bottom = full_ab[1], full_ab[2]

        local frac                      = math.clamp(RingHud_state_team.assist.amount or 0, 0, 1)
        local gap                       = RingHud_state_team.assist.gap
        local eps                       = RingHud_state_team.assist.eps
        local res                       = Notch.notch_apply(
            widget,
            "ledge_bar_base", "ledge_bar_edge",
            frac, parent_top, parent_bottom,
            gap, eps,
            { base = "ledge_bar_base_visible", edge = "ledge_bar_edge_visible" }
        )

        base_style.visible              = res.base.show
        edge_style.visible              = res.edge.show

        local src                       = RingHud_state_team.assist.outline_rgba01 or { 1, 0, 0, 1 }
        U.mv_set_outline(base_style.material_values, src)
        U.mv_set_outline(edge_style.material_values, src)

        if RingHud_state_team.assist.respawn_digits then
            if content.status_icon ~= nil then
                content.status_icon = nil
                widget.dirty = true
            end
            if content.arch_icon ~= RingHud_state_team.assist.respawn_digits then
                content.arch_icon = RingHud_state_team.assist.respawn_digits
                widget.dirty = true
            end

            if style.arch_icon and style.arch_icon.visible ~= true then
                style.arch_icon.visible = true
                widget.dirty = true
            end
        end
    else
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

local function _apply_pockets(widget, RingHud_state_team)
    local content, style = widget.content, widget.style
    local changed = false

    local cstyle = style.crate_icon
    if cstyle then
        if RingHud_state_team.pockets.crate_enabled and RingHud_state_team.pockets.crate_icon then
            content.crate_icon = RingHud_state_team.pockets.crate_icon
            if cstyle.color and RingHud_state_team.pockets.crate_color_argb then
                local tint = RingHud_state_team.pockets.crate_color_argb
                local col =
                    (type(tint) == "table" and tint) or
                    (type(tint) == "string" and mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255[tint]) or
                    tint
                if col then
                    changed = U.set_style_color(cstyle, col) or changed
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

    local sstyle = style.stimm_icon
    if sstyle then
        if RingHud_state_team.pockets.stimm_enabled and RingHud_state_team.pockets.stimm_icon then
            content.stimm_icon = RingHud_state_team.pockets.stimm_icon
            if sstyle.color and RingHud_state_team.pockets.stimm_color_argb then
                local tint = RingHud_state_team.pockets.stimm_color_argb
                local col =
                    (type(tint) == "table" and tint) or
                    (type(tint) == "string" and mod.PALETTE_ARGB255 and mod.PALETTE_ARGB255[tint]) or
                    tint
                if col then
                    changed = U.set_style_color(sstyle, col) or changed
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

function Apply.apply_name(name_widget, RingHud_state_team)
    if not (name_widget and name_widget.content) then return end
    local s = (RingHud_state_team and RingHud_state_team.name_markup) or ""

    if name_widget.content.name_text_value ~= s then
        name_widget.content.name_text_value = s
        name_widget.dirty = true
    end
end

function Apply.apply_all(widget, marker, RingHud_state_team, opts)
    if not (widget and RingHud_state_team and RingHud_state_team.ok) then
        widget.visible = false
        return
    end
    widget.visible       = true

    local icon_only      = RingHud_state_team.icon_only == true

    local respawn_active = RingHud_state_team.assist
        and RingHud_state_team.assist.show
        and (RingHud_state_team.assist.respawn_digits ~= nil)

    if icon_only then
        if respawn_active then
            _apply_arch_only(widget, RingHud_state_team)
            _apply_status(widget, RingHud_state_team)
            _apply_assist_or_respawn(widget, RingHud_state_team)

            local content, style = widget.content, widget.style
            if content then
                if content.toughness_text_value ~= nil then content.toughness_text_value = nil end
                if content.health_value_text ~= nil then content.health_value_text = nil end
                for seg = 1, C.MAX_HP_SEGMENTS do
                    content[_hp_seg_visible_keys[seg]] = false
                    if seg <= C.MAX_WOUNDS_CAP then
                        content[_cor_seg_visible_keys[seg]] = false
                    end
                end
                if content.crate_icon ~= nil then content.crate_icon = nil end
                if content.stimm_icon ~= nil then content.stimm_icon = nil end
                if content.throwable_icon ~= nil then content.throwable_icon = nil end
            end
            if style then
                if style.toughness_text_style then style.toughness_text_style.visible = false end
                if style.health_value_text_style then style.health_value_text_style.visible = false end
                if style.crate_icon then style.crate_icon.visible = false end
                if style.stimm_icon then style.stimm_icon.visible = false end
                if style.throwable_icon then style.throwable_icon.visible = false end
            end

            widget.dirty = true
            return
        end

        _apply_arch_only(widget, RingHud_state_team)
        _apply_status(widget, RingHud_state_team)

        local content, style = widget.content, widget.style
        if content then
            if content.toughness_text_value ~= nil then content.toughness_text_value = nil end
            if content.health_value_text ~= nil then content.health_value_text = nil end
            for seg = 1, C.MAX_HP_SEGMENTS do
                content[_hp_seg_visible_keys[seg]] = false
                if seg <= C.MAX_WOUNDS_CAP then
                    content[_cor_seg_visible_keys[seg]] = false
                end
            end
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
            if style.throwable_icon then style.throwable_icon.visible = false end
        end

        widget.dirty = true
        return
    end

    _apply_name_and_arch(widget, RingHud_state_team)
    _apply_segments(widget, RingHud_state_team)
    _apply_counters(widget, RingHud_state_team, marker)

    if opts and opts.unit then
        _apply_health_integer(widget, opts.unit)
    end

    _apply_status(widget, RingHud_state_team)
    _apply_assist_or_respawn(widget, RingHud_state_team)

    local arch_name = _arch_name_from_profile(RingHud_state_team.profile)
    if widget.style and widget.style.throwable_icon then
        TH.update(widget.style.throwable_icon, arch_name, opts and opts.unit)
        local override = TH.icon_override_for(opts and opts.unit, arch_name)

        if not override then
            widget.style.throwable_icon.visible = false
        end

        if widget.content and widget.content.throwable_icon ~= override then
            widget.content.throwable_icon = override
            widget.dirty = true
        end
    end

    _apply_pockets(widget, RingHud_state_team)

    widget.dirty = true
end

return Apply
