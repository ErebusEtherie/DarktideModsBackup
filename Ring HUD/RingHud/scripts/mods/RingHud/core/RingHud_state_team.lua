-- File: RingHud/scripts/mods/RingHud/core/RingHud_state_team.lua

local mod = get_mod("RingHud"); if not mod then return {} end

mod.team_marker_state    = mod.team_marker_state or {}
local RingHud_state_team = mod.team_marker_state

-- Shared deps (read-only)
local C                  = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
local T                  = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_toughness")
local P                  = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_pocketables")
local Status             = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_icon")
local Name               = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_names")
local NameCache          = mod.name_cache or mod:io_dofile("RingHud/scripts/mods/RingHud/team/name_cache")
local U                  = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")

-- Centralised visibility gates
mod:io_dofile("RingHud/scripts/mods/RingHud/team/visibility")
local V             = mod.team_visibility

-- Centralized Toughness/HP visibility (context)
local THV           = mod.toughness_hp_visibility or
    mod:io_dofile("RingHud/scripts/mods/RingHud/context/toughness_hp_visibility")

-- Centralized pocketable visibility
local PV            = mod:io_dofile("RingHud/scripts/mods/RingHud/context/pocketables_visibility")

local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UISettings    = require("scripts/settings/ui/ui_settings")

-- Assist module (optional)
local Assist        = rawget(mod, "_assist_module")
if Assist == nil then
    local mod_or_err = mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_assist")
    Assist = (mod_or_err and mod_or_err) or false
    mod._assist_module = Assist
end
if Assist == false then Assist = nil end

-- Outline colors for assist/ledge bars (material floats RGBA 0..1)
local GREEN_OUTLINE_FLOATS            = table.clone(mod.PALETTE_RGBA1.dodge_color_full_rgba)
local BROKEN_OUTLINE_FLOATS           = table.clone(mod.PALETTE_RGBA1.dodge_color_negative_rgba)

-- ========= Per-peer stimm/ crate latches (kept here; used by PV) =========
local _prev_stimm_kind_by_pid         = {}
local _stimm_pickup_show_until_by_pid = {}
local _prev_crate_kind_by_pid         = {}
local _crate_pickup_show_until_by_pid = {}

-- Per-peer reserve fraction history (for recent-change ammo vis bumps)
local _prev_reserve_frac_by_pid       = {}

-- ---------- Small locals ----------

local function _archetype_glyph(profile)
    local arch = profile and profile.archetype and profile.archetype.name
    return (arch and UISettings.archetype_font_icon_simple and UISettings.archetype_font_icon_simple[arch]) or "?"
end

local function _player_for_unit(unit)
    local pm = Managers.player
    return pm and pm:player_by_unit(unit) or nil
end

-- nil-safe profile getter (method-or-field)
local function _safe_profile(player)
    if not player then return nil end
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

-- Is this a human-controlled teammate? Works with or without a unit.
local function _is_human_from_player(player)
    if not player then return false end
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

local function _secondary_reserve_frac_for_unit(unit)
    local uds = _uds(unit)
    if not uds then return nil end

    local comp = uds:read_component("slot_secondary")
    if not comp then return nil end

    -- Use centralized helper from utils
    local cur = U.sum_ammo_field(comp.current_ammunition_reserve)
    local max = U.sum_ammo_field(comp.max_ammunition_reserve)

    if max and max > 0 then
        return math.clamp(cur / max, 0, 1)
    end

    -- max <= 0 ⇒ treat as infinite/unknown reserve (nil)
    return nil
end

-- ===== Team metrics (fallbacks; use mod-provided funcs if present) =====
local function _team_hp_average_frac()
    if mod.team_hp_average_frac then
        local v = mod.team_hp_average_frac(mod)
        if v then return math.clamp(v, 0, 1) end
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
                        local hp  = math.clamp(he:current_health_percent() or 0, 0, 1)
                        local cor = math.clamp(he:permanent_damage_taken_percent() or 0, 0, 1)
                        sum       = sum + hp + cor
                        n         = n + 1
                    end
                end
            end
        end
    end

    if n == 0 then return 1 end
    local avg = sum / n
    return math.clamp(avg, 0, 1)
end

local function _team_ammo_need()
    if mod.team_ammo_need then
        local v = mod.team_ammo_need(mod)
        if v then return math.clamp(v, 0, 1) end
    end

    local pm  = Managers.player
    local sum = 0
    local n   = 0

    if pm and pm.players then
        local players = pm:players()
        if players then
            for _, p in pairs(players) do
                local u = p and p.player_unit
                if u and Unit.alive(u) then
                    local frac = _secondary_reserve_frac_for_unit(u)
                    if frac ~= nil then
                        sum = sum + frac
                        n   = n + 1
                    end
                end
            end
        end
    end

    if n == 0 then return 0 end
    local avg = math.clamp(sum / n, 0, 1)
    -- Need is inverse of average reserve level (0 = topped up, 1 = starving)
    return math.clamp(1 - avg, 0, 1)
end

-- ---------- Public: build(unit, marker, opts) ----------

function RingHud_state_team.build(unit, marker, opts)
    local t               = (opts and opts.t) or ((Managers.time and Managers.time:time("ui")) or os.clock())
    local force_show      = (opts and opts.force_show == true) or false

    -- Layout-only flag: with icon-only presets removed, this is currently
    -- always false. If you later add a dedicated "icon-only" layout option,
    -- wire it here from the new setting instead of team_hud_mode.
    local icon_only       = false

    local player          = (opts and opts.player) or _player_for_unit(unit)
    local profile         = _safe_profile(player)
    local glyph           = _archetype_glyph(profile)
    local tint            = mod.team_slot_tint_argb(player, marker)

    -- Peer id (for cloned name + vis/pocket latches)
    local pid             = (opts and opts.peer_id)
        or (marker and (marker.peer_id or marker.peer))
        or nil

    -- Guard: only show humans (bots hidden in both floating and docked)
    local is_human_unit   = (unit and Unit.alive(unit)) and
        (Status.is_human_player_unit and Status.is_human_player_unit(unit) or false) or false
    local is_human_player = _is_human_from_player(player)
    local is_human        = is_human_unit or is_human_player

    -- Name (seeded by RingHud’s own precomposed value when present; otherwise compose now)
    local seeded_text     = marker and marker.data and marker.data.rh_name_composed or nil

    -- Parse the setting string (format: nameX_iconX_statusX)
    local tni_setting     = (mod._settings and mod._settings.team_name_icon) or "name1_icon1_status1"

    -- 1. Status Icons: Check for "status1" (enabled)
    local status_enabled  = string.find(tni_setting, "status1") ~= nil

    -- 2. Archetype Icon: Check for "icon0" (Small/Text ⇒ icon lives in name, big glyph hidden)
    local arch_is_small   = string.find(tni_setting, "icon0") ~= nil

    -- 3. Determine Name Composition Mode
    local is_floating     = marker ~= nil -- Presence of marker implies floating tile logic

    -- Check for "name0" (No Name). If present AND we are floating, we force the name to blank.
    -- (Docked HUD always shows names even if "name0" is selected, as that setting applies to floating tiles.)
    local is_name_hidden  = is_floating and string.find(tni_setting, "name0") ~= nil

    -- Floating HUDs with "name1" setting: Only show Primary Name (slot colored).
    -- Docked HUDs: Always show Full Name (Primary + Account + TL/WRU).
    local name_mode       = "full"

    if is_floating and string.find(tni_setting, "name1") then
        name_mode = "primary_only"
    end

    ----------------------------------------------------------------
    -- Name markup:
    ----------------------------------------------------------------
    local name_full

    if is_name_hidden then
        name_full = ""
    elseif seeded_text and seeded_text ~= "" then
        -- Floating / nameplate path: respect the precomposed, WRU-free string.
        name_full = seeded_text
    else
        -- Docked (marker == nil) or fallback path
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
        wounds   = math.clamp(
            (he.num_wounds and he:num_wounds()) or (he.max_wounds and he:max_wounds()) or 1,
            1, C.MAX_WOUNDS_CAP
        )
        hp_frac  = math.clamp((he.current_health_percent and he:current_health_percent()) or 0, 0, 1)
        cor_frac = math.clamp((he.permanent_damage_taken_percent and he:permanent_damage_taken_percent()) or 0, 0, 1)
    end
    local tough_state  = T.state(unit)

    ----------------------------------------------------------------
    -- Counters (ammo reserve %, ability cooldown seconds).
    -- reserve_frac is computed from secondary slot ammo; supports
    -- both scalar and array-style reserve layouts.
    ----------------------------------------------------------------
    local reserve_frac = _secondary_reserve_frac_for_unit(unit)

    -- Recent-change bump for team ammo visibility (per peer)
    if pid then
        local prev = _prev_reserve_frac_by_pid[pid]
        if reserve_frac ~= nil and prev ~= nil and math.abs(reserve_frac - prev) > 0.001 then
            if mod.ammo_vis_team_recent_change_bump then
                mod.ammo_vis_team_recent_change_bump(pid)
            end
        end
        _prev_reserve_frac_by_pid[pid] = reserve_frac
    end

    -- Ability cooldowns (remaining + max if known)
    local ability_secs = 0
    local ability_max  = 0
    do
        local ability_ext = unit and ScriptUnit.has_extension(unit, "ability_system") and
            ScriptUnit.extension(unit, "ability_system")
        if ability_ext and ability_ext:ability_is_equipped("combat_ability") then
            local rem    = ability_ext:remaining_ability_cooldown("combat_ability") or 0
            ability_secs = (rem > 0) and math.ceil(rem) or 0
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
        local mode = mod._settings and mod._settings.team_munitions or "team_munitions_disabled"
        if mode == "team_munitions_ammo_context_cd_enabled"
            or mode == "team_munitions_ammo_always_cd_always"
        then
            show_cd = true
        end
    end

    ----------------------------------------------------------------
    -- Status (logic vs icon)
    ----------------------------------------------------------------
    local raw_status_kind = Status.for_unit and Status.for_unit(unit) or nil

    local status_kind     = raw_status_kind
    if not status_enabled then
        status_kind = nil
    end

    local status_icon_color = status_kind and UIHudSettings.player_status_colors and
        UIHudSettings.player_status_colors[status_kind] or nil

    ----------------------------------------------------------------
    -- Assist / ledge / respawn view
    ----------------------------------------------------------------
    local assist            = { show = false, amount = 0, outline_rgba01 = BROKEN_OUTLINE_FLOATS, respawn_digits = nil }
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
                assist.amount         = 1 - math.clamp(secs_left / (total > 0 and total or 30), 0, 1)
                assist.respawn_digits = tostring(math.ceil(secs_left))
            end
        end
    end

    assist.amount = math.clamp(assist.amount or 0, 0, 1)

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

    -- Group metrics (HP + ammo need) for variable-opacity crate rules
    local group_hp_avg               = _team_hp_average_frac()
    local group_ammo_need            = _team_ammo_need()

    local stimm_cd_rem, stimm_cd_max = 0, 0
    if s_kind == "broker" then
        stimm_cd_rem, stimm_cd_max = P.stimm_cooldown_state(unit)
    end

    -- Ask centralized pocketables visibility policy for this peer
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
        stimm_color_argb = table.clone(s_tint)
        if stimm_color_argb[1] then
            stimm_color_argb[1] = math.clamp(stimm_alpha or stimm_color_argb[1], 0, 255)
        end
    end

    local crate_color_argb = nil
    if c_icon and c_tint and crate_enabled then
        crate_color_argb = table.clone(c_tint)
        if crate_color_argb[1] then
            crate_color_argb[1] = math.clamp(crate_alpha or crate_color_argb[1], 0, 255)
        end
    end

    -- Build teammate peer context for centralized HP/Toughness visibility
    local peer_ctx = {
        hp_fraction         = hp_frac,
        corruption_fraction = cor_frac,
        max_wounds_segments = wounds,
        tough_overshield    = (tough_state == "overshield"),
        tough_broken        = (tough_state == "broken"),
    }

    -- Central visibility (context/toughness_hp_visibility.lua)
    local vis = (THV and mod.thv_team_for_peer and mod.thv_team_for_peer(pid or "unknown", peer_ctx)) or
        { show_bar = false, show_text = false }
    local hp_bars_enabled = vis.show_bar == true
    local hp_text_visible = vis.show_text == true

    local tough_int = 0
    do
        local t_ext = unit and ScriptUnit.has_extension(unit, "toughness_system") and
            ScriptUnit.extension(unit, "toughness_system")
        if t_ext and t_ext.remaining_toughness then
            tough_int = math.floor((t_ext:remaining_toughness() or 0) + 0.5)
        elseif t_ext and t_ext.current_toughness_percent and t_ext.max_toughness_visual then
            tough_int = math.floor(
                (t_ext:current_toughness_percent() or 0) * (t_ext:max_toughness_visual() or 0) + 0.5
            )
        end
    end

    local show_tough_text = hp_text_visible

    local ok_flag = is_human and ((unit ~= nil) or (raw_status_kind == "dead"))

    return {
        ok                    = ok_flag,
        t                     = t,
        force_show            = force_show,

        player                = player,
        profile               = profile,

        peer_id               = pid,

        icon_only             = icon_only,

        name_markup           = name,
        arch_glyph            = glyph,
        tint_argb255          = tint,

        show_arch_icon_widget = not arch_is_small,

        hp                    = {
            wounds       = wounds,
            hp_frac      = hp_frac,
            cor_frac     = cor_frac,
            tough_state  = tough_state,
            bars_enabled = hp_bars_enabled,
            text_visible = hp_text_visible,
        },

        counters              = {
            reserve_frac    = reserve_frac,
            ability_secs    = ability_secs,
            show_cd         = show_cd,
            show_tough_text = show_tough_text,
            tough_int       = tough_int,
        },

        status                = {
            kind            = status_kind,
            show_icon       = status_kind ~= nil,
            icon_color_argb = status_icon_color,
        },

        assist                = assist,

        pockets               = {
            crate_enabled      = crate_enabled,
            crate_full_opacity = crate_full,
            crate_icon         = c_icon,
            crate_color_argb   = crate_color_argb,

            stimm_enabled      = stimm_enabled,
            stimm_full_opacity = stimm_full,
            stimm_icon         = s_icon,
            stimm_color_argb   = stimm_color_argb,
        },
    }
end

return RingHud_state_team
