-- File: RingHud/scripts/mods/RingHud/features/grenades_feature.lua
local mod = get_mod("RingHud"); if not mod then return {} end

local Notch                       = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/notch_split")
local U                           = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local GrenadesFeature             = {}

-- Broker flash-grenade (blitz) settings – used for kill-based charge regen progress
local TalentSettings              = require("scripts/settings/talent/talent_settings")
local BrokerTalentSettings        = TalentSettings and TalentSettings.broker
local BROKER_BLITZ_KILLS_REQUIRED = 0

if BrokerTalentSettings then
    -- Prefer the explicit passive settings, fall back to blitz.flash_grenade if needed.
    local passive_cfg           = BrokerTalentSettings.broker_passive_blitz_charge_on_kill
    local blitz_cfg             = BrokerTalentSettings.blitz and BrokerTalentSettings.blitz.flash_grenade

    BROKER_BLITZ_KILLS_REQUIRED =
        (passive_cfg and passive_cfg.num_kills)
        or (blitz_cfg and blitz_cfg.num_kills)
        or 0
end

local GRENADE_OUTLINE_COLOR = mod.PALETTE_RGBA1.dodge_color_full_rgba -- visual “full” tint
local GRENADE_ARC_MIN       = -0.25
local GRENADE_ARC_MAX       = 0.25
local GRENADE_SEGMENT_GAP   = 0.025
local MAX                   = mod.MAX_GRENADE_SEGMENTS_DISPLAY or 6

-- ─────────────────────────────────────────────────────────────────────────────
-- Widget factory
-- ─────────────────────────────────────────────────────────────────────────────
function GrenadesFeature.add_widgets(widget_defs, _, layout, palettes)
    if not widget_defs then return end
    local UIWidget          = require("scripts/managers/ui/ui_widget")

    local size              = (layout and layout.size) or { 240, 240 }
    local inner_size_factor = (layout and layout.inner_size_factor) or 0.8
    local ARGB              = (palettes and palettes.ARGB) or (mod.PALETTE_ARGB255 or {})
    local RGBA1             = (palettes and palettes.RGBA1) or (mod.PALETTE_RGBA1 or {})

    local passes            = {}
    for i = 1, MAX do
        -- Base segment
        passes[#passes + 1] = {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "grenade_segment_" .. i,
            style     = {
                uvs                  = { { 0, 0 }, { 1, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { 0, 0, 1 },
                size                 = { size[1] * inner_size_factor, size[2] * inner_size_factor },
                color                = ARGB.GENERIC_WHITE,
                visible              = false,
                pivot                = { 0, 0 },
                angle                = 0,
                material_values      = {
                    amount               = 0,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { 0, 0 },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = table.clone(RGBA1.default_damage_color_rgba),
                },
            },
        }
        -- Edge sliver (partial notch)
        passes[#passes + 1] = {
            pass_type = "rotated_texture",
            value     = "content/ui/materials/effects/forcesword_bar",
            style_id  = "grenade_segment_edge_" .. i,
            style     = {
                uvs                  = { { 0, 0 }, { 1, 1 } },
                horizontal_alignment = "center",
                vertical_alignment   = "center",
                offset               = { 0, 0, 2 },
                size                 = { size[1] * inner_size_factor, size[2] * inner_size_factor },
                color                = ARGB.GENERIC_WHITE,
                visible              = false,
                pivot                = { 0, 0 },
                angle                = 0,
                material_values      = {
                    amount               = 0,
                    glow_on_off          = 0,
                    lightning_opacity    = 0,
                    arc_top_bottom       = { 0, 0 },
                    fill_outline_opacity = { 1.3, 1.3 },
                    outline_color        = table.clone(RGBA1.default_damage_color_rgba),
                },
            },
        }
    end

    widget_defs.grenade_bar = UIWidget.create_definition(passes, "grenade_bar")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Renderer
-- ─────────────────────────────────────────────────────────────────────────────
function GrenadesFeature.update(hud_element, widget, hud_state, hotkey_override)
    if not widget or not widget.style then return end

    local grenade_bar_dropdown = mod._settings.grenade_bar_dropdown
    local style                = widget.style
    local data                 = hud_state.grenade_data or {}
    local changed              = false

    local current              = data.current or data.current_charges or 0
    local live_max             = data.live_max or data.max or data.max_charges or 0

    -- If the blitz isn’t charge-based, hide everything.
    local charge_based         = (live_max or 0) > 0
    if not charge_based then
        for i = 1, MAX do
            local seg = style["grenade_segment_" .. i]
            local edg = style["grenade_segment_edge_" .. i]
            if seg then
                changed = U.set_style_visible(seg, false, changed)
                local mv = seg.material_values
                if mv then
                    if mv.amount ~= 0 then
                        mv.amount = 0; changed = true
                    end
                    changed = U.mv_set_arc(mv, 0, 0, changed)
                end
            end
            if edg then
                changed = U.set_style_visible(edg, false, changed)
                local emv = edg.material_values
                if emv and emv.amount ~= 0 then
                    emv.amount = 0; changed = true
                end
            end
        end
        if changed then widget.dirty = true end
        return
    end

    -- Visibility policy
    local overall_visible_normally = false
    if live_max and live_max > 0 then
        if grenade_bar_dropdown == "grenade_hide_empty_compact"
            or grenade_bar_dropdown == "grenade_hide_empty" then
            if (current or 0) > 0 then
                overall_visible_normally = true
            elseif current == 0 and data.is_regenerating and (data.regen_progress or 0) > 0.001 then
                overall_visible_normally = true
            end
        else
            if current < live_max then
                overall_visible_normally = true
            elseif current >= live_max then
                if data.is_regenerating and (data.regen_progress or 0) > 0.001 and (data.regen_progress or 1) < 0.999 then
                    overall_visible_normally = true
                end
            end
        end
    end

    local should_render_bar_at_all = (hotkey_override or overall_visible_normally)
        and grenade_bar_dropdown ~= "grenade_disabled"

    local num_seg_calc = math.min(live_max or 0, MAX)

    -- Precompute arcs
    local arcs = {}
    if num_seg_calc > 0 then
        local total_arc      = GRENADE_ARC_MAX - GRENADE_ARC_MIN
        local num_gaps       = math.max(0, num_seg_calc - 1)
        local gap_space      = num_gaps * GRENADE_SEGMENT_GAP
        local visual_space   = math.max(0, total_arc - gap_space)
        local seg_arc        = (num_seg_calc > 0) and (visual_space / num_seg_calc) or 0
        local current_bottom = GRENADE_ARC_MIN
        for i = 1, num_seg_calc do
            local top = math.min(GRENADE_ARC_MAX, current_bottom + seg_arc)
            if i == num_seg_calc then top = GRENADE_ARC_MAX end
            arcs[i] = { top, current_bottom }
            current_bottom = top + GRENADE_SEGMENT_GAP
        end
    end

    for i = 1, MAX do
        local seg_style  = style["grenade_segment_" .. i]
        local edge_style = style["grenade_segment_edge_" .. i]
        if seg_style and seg_style.material_values then
            local seg_mv = seg_style.material_values

            local vis_final, amt_final, clr_final, arc_final = false, 0, mod.PALETTE_RGBA1.default_damage_color_rgba,
                { 0, 0 }

            if should_render_bar_at_all then
                local vis_norm, amt_norm, clr_norm = false, 0, mod.PALETTE_RGBA1.default_damage_color_rgba
                if overall_visible_normally and i <= num_seg_calc then
                    if i <= current then
                        vis_norm = true; amt_norm = 1; clr_norm = GRENADE_OUTLINE_COLOR
                    else
                        local compact = (grenade_bar_dropdown == "grenade_hide_full_compact"
                            or grenade_bar_dropdown == "grenade_hide_empty_compact")
                        if compact then
                            if i == current + 1 then
                                vis_norm = true
                                if data.is_regenerating and (data.regen_progress or 0) > 0.001 then
                                    amt_norm = data.regen_progress
                                end
                            end
                        else
                            vis_norm = true
                            if i == current + 1 and data.is_regenerating and (data.regen_progress or 0) > 0.001 then
                                amt_norm = data.regen_progress
                            end
                        end
                    end
                end

                if hotkey_override then
                    vis_final = i <= num_seg_calc
                    if vis_final then
                        if i <= current then
                            amt_final = 1; clr_final = GRENADE_OUTLINE_COLOR
                        elseif i == current + 1 and data.is_regenerating then
                            amt_final = data.regen_progress or 0
                        end
                    end
                else
                    vis_final, amt_final, clr_final = vis_norm, amt_norm, clr_norm
                end

                if vis_final and arcs[i] then
                    arc_final = arcs[i]
                end
            end

            local arc_top, arc_bottom = arc_final[1], arc_final[2]
            local want_partial = vis_final and arcs[i] and (amt_final > 0 and amt_final < 1)

            if want_partial and edge_style and edge_style.material_values then
                local res = Notch.notch_split(arc_top, arc_bottom, amt_final)

                -- base
                changed = U.mv_set_arc(seg_mv, res.base.top, res.base.bottom, changed)
                if seg_mv.amount ~= 1 then
                    seg_mv.amount = 1; changed = true
                end
                changed = U.mv_set_outline(seg_mv, clr_final, changed)

                -- edge
                local emv = edge_style.material_values
                changed = U.mv_set_arc(emv, res.edge.top, res.edge.bottom, changed)
                if emv.amount ~= 0 then
                    emv.amount = 0; changed = true
                end
                changed = U.mv_set_outline(emv, clr_final, changed)

                local base_vis = (vis_final and res.base.show)
                local edge_vis = (vis_final and res.edge.show)
                changed = U.set_style_visible(seg_style, base_vis, changed)
                changed = U.set_style_visible(edge_style, edge_vis, changed)
            else
                changed = U.set_style_visible(seg_style, vis_final, changed)
                if vis_final then
                    if seg_mv.amount ~= amt_final then
                        seg_mv.amount = amt_final; changed = true
                    end
                    changed = U.mv_set_outline(seg_mv, clr_final, changed)
                    changed = U.mv_set_arc(seg_mv, arc_top, arc_bottom, changed)
                else
                    if seg_mv.amount ~= 0 then
                        seg_mv.amount = 0; changed = true
                    end
                    changed = U.mv_set_arc(seg_mv, 0, 0, changed)
                end
                if edge_style then
                    changed = U.set_style_visible(edge_style, false, changed)
                    if edge_style.material_values and edge_style.material_values.amount ~= 0 then
                        edge_style.material_values.amount = 0; changed = true
                    end
                end
            end
        end
    end

    if changed then widget.dirty = true end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- State helper (used by RingHud_state_player.lua)
-- Populates/updates grenade_data in-place:
--   current, current_charges, max, max_charges, live_max,
--   is_regenerating, max_cooldown, regen_progress, replenish_buff_name
-- ─────────────────────────────────────────────────────────────────────────────
function mod.grenades_update_state(unit_data_comp, ability_ext, player_unit, grenade_data)
    if not grenade_data then return end

    local ability_key  = "grenade_ability"
    local base_max     = 0
    local observed_cur = 0

    if ability_ext and ability_ext.ability_is_equipped and ability_ext:ability_is_equipped(ability_key) then
        local remaining              = ability_ext:remaining_ability_charges(ability_key) or 0
        local max_c                  = ability_ext:max_ability_charges(ability_key) or 0
        observed_cur                 = math.max(observed_cur, remaining)
        base_max                     = math.max(base_max, max_c)

        grenade_data.current         = remaining
        grenade_data.current_charges = remaining
        grenade_data.max             = max_c
        grenade_data.max_charges     = max_c
    end

    local grenade_comp = unit_data_comp and unit_data_comp:read_component("grenade_ability")
    if grenade_comp then
        local comp_cur = grenade_comp.num_charges or 0
        observed_cur   = math.max(observed_cur, comp_cur)

        if (grenade_data.current or 0) < comp_cur then
            grenade_data.current         = comp_cur
            grenade_data.current_charges = comp_cur
        end
        if (grenade_data.max or 0) == 0 then
            grenade_data.max         = base_max
            grenade_data.max_charges = base_max
        end
    end

    -- Latch max within mission
    local latched   = mod._grenade_max_override or 0
    local candidate = math.max(base_max, observed_cur)
    if candidate > latched then
        mod._grenade_max_override = candidate
        latched = candidate
    end
    grenade_data.live_max            = math.max(base_max, latched, observed_cur)

    -- Regen progress (cooldown or buff-driven)
    grenade_data.is_regenerating     = false
    grenade_data.replenish_buff_name = nil
    grenade_data.max_cooldown        = 0
    grenade_data.regen_progress      = 0

    local cur                        = grenade_data.current or 0
    local live_max_val               = grenade_data.live_max or 0
    local used_any                   = false

    -- Cooldown-based regeneration (e.g. Ogryn box, some talents)
    if ability_ext and ability_ext.ability_is_equipped and ability_ext:ability_is_equipped(ability_key) then
        local rem_cd = ability_ext:remaining_ability_cooldown(ability_key) or 0
        local max_cd = ability_ext:max_ability_cooldown(ability_key) or 0
        local paused = ability_ext.is_cooldown_paused and ability_ext:is_cooldown_paused(ability_key)

        if max_cd > 0 and rem_cd > 0 and cur < live_max_val and not paused then
            grenade_data.is_regenerating = true
            grenade_data.max_cooldown    = max_cd
            grenade_data.regen_progress  = math.clamp(1 - (rem_cd / max_cd), 0, 1)
            used_any                     = true
        end
    end

    -- Buff-based regeneration (Veteran/Zealot/Ogryn/Psyker) + Broker blitz-on-kill
    if (not used_any) and player_unit then
        local buff_ext = ScriptUnit.has_extension(player_unit, "buff_system") and
            ScriptUnit.extension(player_unit, "buff_system")
        local buffs = buff_ext and buff_ext._buffs_by_index
        if buffs and cur < live_max_val then
            local names = {
                veteran_grenade_replenishment      = true,
                adamant_grenade_replenishment      = true,
                adamant_whistle_replenishment      = true,
                ogryn_friend_grenade_replenishment = true,
                psyker_knife_replenishment         = true,
            }

            local broker_kill_buff = nil

            for _, b in pairs(buffs) do
                local tmpl = b and b:template()
                local name = (tmpl and tmpl.name) or (b and b.template_name and b:template_name())

                if name and names[name] then
                    local dur  = (b.duration and type(b.duration) == "function") and b:duration() or nil
                    local prog = (b.duration_progress and type(b.duration_progress) == "function") and
                        b:duration_progress() or nil
                    if prog and prog > 0 then
                        local fill                       = (name == "veteran_grenade_replenishment"
                                or name == "adamant_grenade_replenishment")
                            and math.clamp(prog, 0, 1)    -- 0→1 elapsed
                            or math.clamp(1 - prog, 0, 1) -- 1→0 remaining
                        grenade_data.is_regenerating     = true
                        grenade_data.replenish_buff_name = name
                        if dur and dur > 0 then grenade_data.max_cooldown = dur end
                        grenade_data.regen_progress = fill
                        break
                    end
                elseif name == "broker_passive_blitz_charge_on_kill" then
                    broker_kill_buff = b
                    -- don’t break; there might also be one of the classic regen buffs present.
                end
            end

            -- Broker kill-based blitz charge: show kills-to-next-charge as a partial segment.
            if (not grenade_data.is_regenerating)
                and broker_kill_buff
                and BROKER_BLITZ_KILLS_REQUIRED > 0
            then
                local kills = 0

                if broker_kill_buff.visual_stack_count and type(broker_kill_buff.visual_stack_count) == "function" then
                    kills = broker_kill_buff:visual_stack_count() or 0
                elseif broker_kill_buff.stack_count and type(broker_kill_buff.stack_count) == "function" then
                    -- Fallback: if visual_stack_count isn’t exposed for some reason.
                    kills = broker_kill_buff:stack_count() or 0
                end

                kills = math.max(kills or 0, 0)

                if kills > 0 then
                    local prog = math.clamp(kills / BROKER_BLITZ_KILLS_REQUIRED, 0, 1)

                    if prog > 0 then
                        grenade_data.is_regenerating     = true
                        grenade_data.replenish_buff_name = "broker_passive_blitz_charge_on_kill"
                        grenade_data.regen_progress      = prog
                        -- max_cooldown remains 0 here: this is kill-based, not time-based.
                    end
                end
            end
        end
    end
end

return GrenadesFeature
