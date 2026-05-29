-- File: RingHud/scripts/mods/RingHud/core/RingHud_state_team.lua

local mod = get_mod("RingHud"); if not mod then return {} end

mod.team_marker_state    = mod.team_marker_state or {}
local RingHud_state_team = mod.team_marker_state

local C                  = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
local T                  = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_toughness")
local P                  = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_pocketables")
local Status             = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_icon")
local Name               = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_names")
local NameCache          = mod.name_cache or mod:io_dofile("RingHud/scripts/mods/RingHud/team/name_cache")
local U                  = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

mod:io_dofile("RingHud/scripts/mods/RingHud/team/visibility")
local V             = mod.team_visibility

local THV           = mod.toughness_hp_visibility or
    mod:io_dofile("RingHud/scripts/mods/RingHud/context/toughness_hp_visibility")

local PV            = mod:io_dofile("RingHud/scripts/mods/RingHud/context/pocketables_visibility")

local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UISettings    = require("scripts/settings/ui/ui_settings")
local Ammo          = require("scripts/utilities/ammo")

local Assist        = rawget(mod, "_assist_module")
if Assist == nil then
    local mod_or_err = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_assist")
    Assist = (mod_or_err and mod_or_err) or false
    mod._assist_module = Assist
end
if Assist == false then Assist = nil end

local SETTINGS                        = mod._settings
local GREEN_OUTLINE_FLOATS            = table.clone(mod.PALETTE_RGBA1.dodge_color_full_rgba)
local BROKEN_OUTLINE_FLOATS           = table.clone(mod.PALETTE_RGBA1.dodge_color_negative_rgba)

local math_clamp                      = math.clamp
local math_floor                      = math.floor
local math_ceil                       = math.ceil

local _prev_stimm_kind_by_pid         = {}
local _stimm_pickup_show_until_by_pid = {}
local _prev_crate_kind_by_pid         = {}
local _crate_pickup_show_until_by_pid = {}

local _prev_reserve_frac_by_pid       = {}

local _result_pool                    = {}
local _hp_pool                        = {}
local _counters_pool                  = {}
local _status_pool                    = {}
local _pockets_pool                   = {}
local _assist_pool                    = {}

local _stimm_color_pool               = { 0, 0, 0, 0 }
local _crate_color_pool               = { 0, 0, 0, 0 }

local _peer_ctx_pool                  = {}

local function _get_pooled_result()
    local result = _result_pool
    local hp = _hp_pool
    local counters = _counters_pool
    local status = _status_pool
    local pockets = _pockets_pool
    local assist = _assist_pool

    -- Clear previous values / Link tables
    result.hp = hp
    result.counters = counters
    result.status = status
    result.pockets = pockets
    result.assist = assist

    return result, hp, counters, status, pockets, assist
end

-- ---------- Small locals ----------

local function _now()
    local MT = Managers and Managers.time
    if MT and MT.time then
        return MT:time("ui") or MT:time("gameplay") or os.clock()
    end
    return os.clock()
end

local function _player_for_unit(unit)
    local pm = Managers.player
    return pm and pm:player_by_unit(unit) or nil
end

local function _safe_profile(player)
    if not player or player.__deleted then return nil end
    if type(player.profile) == "function" then
        return player:profile()
    end
    return rawget(player, "profile")
end

local function _health_ext(unit)
    return unit and ScriptUnit.has_extension(unit, "health_system") and ScriptUnit.extension(unit, "health_system")
end

local function _uds(unit)
    return unit and ScriptUnit.has_extension(unit, "unit_data_system") and ScriptUnit.extension(unit, "unit_data_system")
end

local function _is_human_from_player(player)
    if not player or player.__deleted then return false end
    if player.is_human_controlled then
        return player:is_human_controlled()
    end
    if player.is_bot_player then
        return not player:is_bot_player()
    end
    if player.is_bot then
        return not player:is_bot()
    end
    return true
end

local function _ability_max_cooldown(unit)
    local ability_ext = unit and ScriptUnit.has_extension(unit, "ability_system") and
        ScriptUnit.extension(unit, "ability_system")
    if not ability_ext then return 0 end

    if ability_ext.max_ability_cooldown then
        local v = ability_ext:max_ability_cooldown("combat_ability")
        if v and v > 0 then return v end
    end

    if ability_ext.ability_total_cooldown then
        local v = ability_ext:ability_total_cooldown("combat_ability")
        if v and v > 0 then return v end
    end

    if ability_ext.cooldown_duration then
        local v = ability_ext:cooldown_duration("combat_ability")
        if v and v > 0 then return v end
    end

    return 0
end

-------------------------------------------------------------------------------
-- Ammo helpers (handle scalar or array-style reserves safely)
-------------------------------------------------------------------------------

local function _secondary_total_ammo_frac_for_unit(unit)
    local uds = _uds(unit)
    if not uds then return nil end

    local comp = uds:read_component("slot_secondary")
    if not comp then return nil end

    local cur_res = U.sum_ammo_field(comp.current_ammunition_reserve)
    local max_res = U.sum_ammo_field(comp.max_ammunition_reserve)

    local cur_clip = 0
    local max_clip = 0
    if comp.current_ammunition_clip and comp.max_ammunition_clip then
        cur_clip = Ammo.current_ammo_in_clips(comp) or 0
        max_clip = Ammo.max_ammo_in_clips(comp) or 0
    end

    local total_cur = cur_res + cur_clip
    local total_max = max_res + max_clip

    if total_max and total_max > 0 then
        return math_clamp(total_cur / total_max, 0, 1)
    end

    return nil
end

local function _team_hp_average_frac()
    if mod.team_hp_average_frac then
        local v = mod.team_hp_average_frac(mod)
        if v then return math_clamp(v, 0, 1) end
    end

    local pm = Managers.player
    local sum, n = 0, 0

    if pm and pm.players then
        local players = pm:players()
        if players then
            for _, p in pairs(players) do
                local u = p and p.player_unit
                if u and Unit.alive(u) then
                    local he = _health_ext(u)
                    if he and he.current_health_percent and he.permanent_damage_taken_percent then
                        local hp  = math_clamp(he:current_health_percent() or 0, 0, 1)
                        local cor = math_clamp(he:permanent_damage_taken_percent() or 0, 0, 1)
                        sum       = sum + hp + cor
                        n         = n + 1
                    end
                end
            end
        end
    end

    if n == 0 then return 1 end
    local avg = sum / n
    return math_clamp(avg, 0, 1)
end

local function _team_ammo_need()
    if mod.team_ammo_need then
        local v = mod.team_ammo_need(mod)
        if v then return math_clamp(v, 0, 1) end
    end

    local pm  = Managers.player
    local sum = 0
    local n   = 0

    if pm and pm.players then
        local players = pm:players()
        if players then
            for _, p in pairs(players) do
                local u = p and not p.__deleted and p.player_unit
                if u and Unit.alive(u) then
                    local frac = _secondary_total_ammo_frac_for_unit(u)
                    if frac ~= nil then
                        sum = sum + frac
                        n   = n + 1
                    end
                end
            end
        end
    end

    if n == 0 then return 0 end
    local avg = math_clamp(sum / n, 0, 1)
    return math_clamp(1 - avg, 0, 1)
end

-- ---------- Public: build(unit, marker, opts) ----------

function RingHud_state_team.build(unit, marker, opts)
    local t               = (opts and opts.t) or _now()
    local force_show      = (opts and opts.force_show == true) or false

    local player          = (opts and opts.player) or _player_for_unit(unit)

    local is_human_player = _is_human_from_player(player)
    local is_human_unit   = (unit and Unit.alive(unit)) and
        (Status.is_human_player_unit and Status.is_human_player_unit(unit) or false) or false
    local is_human        = is_human_unit or is_human_player

    if not is_human then
        local result = _get_pooled_result()
        result.ok = false
        return result
    end

    local icon_only   = false
    local profile     = _safe_profile(player)
    local glyph       = mod.get_archetype_glyph(profile)
    local tint        = mod.team_slot_tint_argb(player, marker)

    -- Peer id (for cloned name + vis/pocket latches)
    local pid         = (opts and opts.peer_id)
        or (marker and (marker.peer_id or marker.peer))
        or nil

    local tni_setting = SETTINGS.team_name_icon or "name1_icon1_status1"

    if tni_setting ~= RingHud_state_team._cached_tni_setting then
        RingHud_state_team._cached_tni_setting = tni_setting
        RingHud_state_team._tni_status_enabled = string.find(tni_setting, "status1") ~= nil
        RingHud_state_team._tni_arch_is_small  = string.find(tni_setting, "icon0") ~= nil
        RingHud_state_team._tni_name0          = string.find(tni_setting, "name0") ~= nil
        RingHud_state_team._tni_name1          = string.find(tni_setting, "name1") ~= nil
    end

    local status_enabled = RingHud_state_team._tni_status_enabled
    local arch_is_small  = RingHud_state_team._tni_arch_is_small

    local is_floating    = marker ~= nil -- Presence of marker implies floating tile logic

    -- Check for "name0" (No Name). If present AND we are floating, we force the name to blank.
    -- (Docked HUD always shows names even if "name0" is selected, as that setting applies to floating tiles.)
    local is_name_hidden = is_floating and RingHud_state_team._tni_name0

    -- Floating HUDs with "name1" setting: Only show Primary Name (slot colored).
    -- Docked HUDs: Always show Full Name (Primary + Account + TL/WRU).
    local name_mode      = "full"

    if is_floating and RingHud_state_team._tni_name1 then
        name_mode = "primary_only"
    end

    ----------------------------------------------------------------
    -- Name markup:
    ----------------------------------------------------------------
    local name_full

    if is_name_hidden then
        name_full = ""
    else
        local context = is_floating and "floating" or "docked"

        if NameCache and NameCache.compose_team_name then
            name_full = NameCache:compose_team_name(player, tint, nil, context)
        else
            name_full = Name.compose(player, profile, tint, nil, nil, context)
        end
    end

    local name = name_full

    if not is_name_hidden and name_mode == "primary_only" then
        local white_tag_start = string.find(name_full, "{#color%(255,255,255%)}")
        if white_tag_start then
            name = string.sub(name_full, 1, white_tag_start - 1) .. "{#reset()}"
        end
    end

    -- Health / corruption / toughness
    local he       = _health_ext(unit)
    local wounds   = 1
    local hp_frac  = 0
    local cor_frac = 0
    if he then
        wounds   = math_clamp(
            (he.num_wounds and he:num_wounds()) or (he.max_wounds and he:max_wounds()) or 1,
            1, C.MAX_WOUNDS_CAP
        )
        hp_frac  = math_clamp((he.current_health_percent and he:current_health_percent()) or 0, 0, 1)
        cor_frac = math_clamp((he.permanent_damage_taken_percent and he:permanent_damage_taken_percent()) or 0, 0, 1)
    end
    local tough_state  = T.state(unit)

    ----------------------------------------------------------------
    -- Counters (ammo reserve %, ability cooldown seconds).
    ----------------------------------------------------------------
    local reserve_frac = _secondary_total_ammo_frac_for_unit(unit)

    if pid then
        local prev = _prev_reserve_frac_by_pid[pid]
        if reserve_frac ~= nil and prev ~= nil and math.abs(reserve_frac - prev) > 0.001 then
            if mod.ammo_vis_team_recent_change_bump then
                mod.ammo_vis_team_recent_change_bump(pid)
            end
        end
        _prev_reserve_frac_by_pid[pid] = reserve_frac
    end

    local ability_secs = 0
    local ability_max  = 0
    do
        local ability_ext = unit and ScriptUnit.has_extension(unit, "ability_system") and
            ScriptUnit.extension(unit, "ability_system")
        if ability_ext and ability_ext:ability_is_equipped("combat_ability") then
            local rem    = ability_ext:remaining_ability_cooldown("combat_ability") or 0
            ability_secs = (rem > 0) and math_ceil(rem) or 0
            ability_max  = _ability_max_cooldown(unit) or 0
        end
    end

    ----------------------------------------------------------------
    -- Ability CD / toughness counter visibility
    ----------------------------------------------------------------
    local show_cd = false
    if V and V.counters then
        show_cd = V.counters(force_show)
    else
        local mode = SETTINGS.team_munitions or "team_munitions_ammo_context_cd_enabled"
        if mode == "team_munitions_ammo_context_cd_enabled"
            or mode == "team_munitions_ammo_always_cd_always"
        then
            show_cd = true
        end
    end

    ----------------------------------------------------------------
    -- Status (logic vs icon)
    ----------------------------------------------------------------
    local raw_status_kind = Status.for_unit(unit) or nil

    local status_kind     = raw_status_kind
    if not status_enabled then
        status_kind = nil
    end

    local status_icon_color = status_kind and UIHudSettings.player_status_colors and
        UIHudSettings.player_status_colors[status_kind] or nil

    if status_kind == "auspex" then
        status_icon_color = { 255, 216, 237, 190, } -- ui_hud_green_super_light used by DT for luggable status icon
    end

    ----------------------------------------------------------------
    -- Assist / ledge / respawn view
    ----------------------------------------------------------------
    local assist = _assist_pool
    assist.show = false
    assist.amount = 0
    assist.outline_rgba01 = BROKEN_OUTLINE_FLOATS
    assist.respawn_digits = nil

    do
        local has_assist, assist_progress, is_pull_up = false, 0, false
        if unit and Unit.alive(unit) and Assist and Assist.progress_for_victim then
            has_assist, assist_progress, is_pull_up = Assist.progress_for_victim(unit)
            assist_progress                         = assist_progress or 0
            is_pull_up                              = is_pull_up or false
        end

        if raw_status_kind == "ledge_hanging" then
            if has_assist and is_pull_up then
                assist.show           = true
                assist.amount         = assist_progress or 0
                assist.outline_rgba01 = GREEN_OUTLINE_FLOATS
            else
                local frac            = Status.ledge_time_remaining_fraction and
                    Status.ledge_time_remaining_fraction(unit, C.LEDGE_TOTAL_WINDOW) or 0
                assist.show           = true
                assist.amount         = frac
                assist.outline_rgba01 = BROKEN_OUTLINE_FLOATS
            end
        elseif has_assist and (raw_status_kind == "netted" or raw_status_kind == "hogtied" or raw_status_kind == "knocked_down") then
            assist.show           = true
            assist.amount         = assist_progress or 0
            assist.outline_rgba01 = GREEN_OUTLINE_FLOATS
        elseif raw_status_kind == "dead" then
            local secs_left = Status.respawn_secs_remaining and Status.respawn_secs_remaining(player) or nil
            if secs_left and secs_left > 0.01 then
                assist.show           = true
                assist.outline_rgba01 = BROKEN_OUTLINE_FLOATS
                local total           = C.RESPAWN_TOTAL_WINDOW or 30
                assist.amount         = 1 - math_clamp(secs_left / (total > 0 and total or 30), 0, 1)
                assist.respawn_digits = tostring(math_ceil(secs_left))
            end
        end
    end

    assist.amount = math_clamp(assist.amount or 0, 0, 1)

    -- ===========================
    -- Pockets (crate + stimm)
    -- ===========================
    local c_icon, c_tint, c_kind, c_map_known = P.crate_icon_and_color(unit)
    local s_icon, s_tint, s_kind, s_map_known = P.stimm_icon_and_color(unit)

    local stimm_show_until = nil
    local crate_show_until = nil

    if pid then
        local prev_sk = _prev_stimm_kind_by_pid[pid]
        if s_kind ~= nil and s_kind ~= prev_sk then
            _stimm_pickup_show_until_by_pid[pid] = (t or 0) + (C.STIMM_PICKUP_LATCH_SEC or 10)
        end
        _prev_stimm_kind_by_pid[pid] = s_kind
        stimm_show_until             = _stimm_pickup_show_until_by_pid[pid]

        local prev_ck                = _prev_crate_kind_by_pid[pid]
        if c_kind ~= nil and c_kind ~= prev_ck then
            _crate_pickup_show_until_by_pid[pid] = (t or 0) + (C.CRATE_PICKUP_LATCH_SEC or 10)
        end
        _prev_crate_kind_by_pid[pid] = c_kind
        crate_show_until             = _crate_pickup_show_until_by_pid[pid]
    end

    local group_hp_avg               = _team_hp_average_frac()
    local group_ammo_need            = _team_ammo_need()

    local stimm_cd_rem, stimm_cd_max = 0, 0
    if s_kind == "broker" then
        stimm_cd_rem, stimm_cd_max = P.stimm_cooldown_state(unit)
    end

    local flags            = PV and PV.team_flags_for_peer and PV.team_flags_for_peer(pid or "unknown", {
        t                    = t,
        hp_frac              = hp_frac,
        ability_cd_remaining = ability_secs,
        ability_cd_max       = ability_max,
        stimm_cd_remaining   = stimm_cd_rem,
        stimm_cd_max         = stimm_cd_max,
        reserve_frac         = reserve_frac,
        group_hp_avg         = group_hp_avg,
        group_ammo_need      = group_ammo_need,
        stimm_icon           = s_icon,
        crate_icon           = c_icon,
        stimm_kind           = s_kind,
        stimm_mapping_known  = s_map_known,
        crate_kind           = c_kind,
        crate_mapping_known  = c_map_known,
        stimm_show_until     = stimm_show_until,
        crate_show_until     = crate_show_until,
        force_show           = force_show,
    }) or nil

    local stimm_flags      = flags and flags.stimm or nil
    local crate_flags      = flags and flags.crate or nil

    local stimm_enabled    = stimm_flags and stimm_flags.enabled or false
    local stimm_alpha      = stimm_flags and stimm_flags.alpha or 0
    local stimm_full       = stimm_flags and stimm_flags.full or false

    local crate_enabled    = crate_flags and crate_flags.enabled or false
    local crate_alpha      = crate_flags and crate_flags.alpha or 0
    local crate_full       = crate_flags and crate_flags.full or false

    local stimm_color_argb = nil
    if s_icon and s_tint and stimm_enabled then
        _stimm_color_pool[1] = math_clamp(stimm_alpha or s_tint[1] or 0, 0, 255)
        _stimm_color_pool[2] = s_tint[2] or 0
        _stimm_color_pool[3] = s_tint[3] or 0
        _stimm_color_pool[4] = s_tint[4] or 0
        stimm_color_argb = _stimm_color_pool
    end

    local crate_color_argb = nil
    if c_icon and c_tint and crate_enabled then
        _crate_color_pool[1] = math_clamp(crate_alpha or c_tint[1] or 0, 0, 255)
        _crate_color_pool[2] = c_tint[2] or 0
        _crate_color_pool[3] = c_tint[3] or 0
        _crate_color_pool[4] = c_tint[4] or 0
        crate_color_argb = _crate_color_pool
    end

    local peer_ctx               = _peer_ctx_pool
    peer_ctx.hp_fraction         = hp_frac
    peer_ctx.corruption_fraction = cor_frac
    peer_ctx.max_wounds_segments = wounds
    peer_ctx.tough_overshield    = (tough_state == "overshield")
    peer_ctx.tough_broken        = (tough_state == "broken")
    peer_ctx.prox_healing        = mod.prox_healing
    peer_ctx.near_health_station = (mod.prox_healing >= 2)
    peer_ctx.near_med_crate      = (mod.prox_healing >= 1)

    local vis                    = (THV and mod.thv_team_for_peer and mod.thv_team_for_peer(pid or "unknown", peer_ctx)) or
        { show_bar = false, show_text = false }
    local hp_bars_enabled        = vis.show_bar == true
    local hp_text_visible        = vis.show_text == true

    local tough_int              = 0
    do
        local t_ext = unit and ScriptUnit.has_extension(unit, "toughness_system") and
            ScriptUnit.extension(unit, "toughness_system")
        if t_ext and t_ext.remaining_toughness then
            tough_int = math_floor((t_ext:remaining_toughness() or 0) + 0.5)
        elseif t_ext and t_ext.current_toughness_percent and t_ext.max_toughness_visual then
            tough_int = math_floor(
                (t_ext:current_toughness_percent() or 0) * (t_ext:max_toughness_visual() or 0) + 0.5
            )
        end
    end

    local show_tough_text                                   = hp_text_visible

    local ok_flag                                           = is_human and ((unit ~= nil) or (raw_status_kind == "dead"))

    local result, hp, counters, status, pockets, assist_ref = _get_pooled_result()

    result.ok                                               = ok_flag
    result.t                                                = t
    result.force_show                                       = force_show

    result.player                                           = player
    result.profile                                          = profile

    result.peer_id                                          = pid

    result.icon_only                                        = icon_only

    result.name_markup                                      = name
    result.arch_glyph                                       = glyph
    result.tint_argb255                                     = tint

    result.show_arch_icon_widget                            = not arch_is_small

    hp.wounds                                               = wounds
    hp.hp_frac                                              = hp_frac
    hp.cor_frac                                             = cor_frac
    hp.tough_state                                          = tough_state
    hp.bars_enabled                                         = hp_bars_enabled
    hp.text_visible                                         = hp_text_visible

    counters.reserve_frac                                   = reserve_frac
    counters.ability_secs                                   = ability_secs
    counters.show_cd                                        = show_cd
    counters.show_tough_text                                = show_tough_text
    counters.tough_int                                      = tough_int

    status.kind                                             = status_kind
    status.show_icon                                        = status_kind ~= nil
    status.icon_color_argb                                  = status_icon_color

    pockets.crate_enabled                                   = crate_enabled
    pockets.crate_full_opacity                              = crate_full
    pockets.crate_icon                                      = c_icon
    pockets.crate_color_argb                                = crate_color_argb

    pockets.stimm_enabled                                   = stimm_enabled
    pockets.stimm_full_opacity                              = stimm_full
    pockets.stimm_icon                                      = s_icon
    pockets.stimm_color_argb                                = stimm_color_argb

    return result
end

return RingHud_state_team
