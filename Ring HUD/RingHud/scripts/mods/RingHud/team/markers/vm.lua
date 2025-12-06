-- File: RingHud/scripts/mods/RingHud/team/markers/vm.lua -- "view model"
local mod = get_mod("RingHud"); if not mod then return {} end

mod.team_marker_vm = mod.team_marker_vm or {}
local VM           = mod.team_marker_vm

-- Shared deps (read-only)
local C            = mod:io_dofile("RingHud/scripts/mods/RingHud/team/constants")
local U            = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local T            = mod:io_dofile("RingHud/scripts/mods/RingHud/team/toughness")
local P            = mod:io_dofile("RingHud/scripts/mods/RingHud/team/pocketables")
local Status       = mod:io_dofile("RingHud/scripts/mods/RingHud/team/status")
local Name         = mod:io_dofile("RingHud/scripts/mods/RingHud/team/name")

-- Centralised visibility gates
mod:io_dofile("RingHud/scripts/mods/RingHud/team/visibility")
local V             = mod.team_visibility

local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UISettings    = require("scripts/settings/ui/ui_settings")

-- Assist module (optional)
local Assist        = rawget(mod, "_assist_module")
if Assist == nil then
    local ok, mod_or_err = pcall(function() return mod:io_dofile("RingHud/scripts/mods/RingHud/team/assist") end)
    Assist = ok and type(mod_or_err) == "table" and mod_or_err or false
    mod._assist_module = Assist
end
if Assist == false then Assist = nil end

-- Outline colors for assist/ledge bars (material floats RGBA 0..1)
local GREEN_OUTLINE_FLOATS            = table.clone(mod.PALETTE_RGBA1.dodge_color_full_rgba)
local BROKEN_OUTLINE_FLOATS           = table.clone(mod.PALETTE_RGBA1.dodge_color_negative_rgba)

-- ========= Per-peer ammo latch state (existing) =========
local _prev_reserve_by_pid            = {}
local _reserve_show_until_by_pid      = {}

-- ========= Per-peer stimm pickup latch =========
local _prev_stimm_kind_by_pid         = {}
local _stimm_pickup_show_until_by_pid = {}

-- ========= Per-peer crate pickup latch =========
local _prev_crate_kind_by_pid         = {}
local _crate_pickup_show_until_by_pid = {}

-- ========= Per-peer HP change latch =========
local _prev_hp_frac_by_pid            = {}
local _hp_show_until_by_pid           = {}

-- ---------- Small locals ----------
local function _icon_only_mode()
    local m = mod._settings and mod._settings.team_hud_mode
    return m == "team_hud_icons_vanilla" or m == "team_hud_icons_docked"
end

local function _slot_tint_argb(player_or_index) -- TODO Color
    local idx = type(player_or_index) == "table" and (player_or_index.slot and player_or_index:slot()) or player_or_index
    local slot_colors = UISettings.player_slot_colors or UIHudSettings
    return (slot_colors and slot_colors[idx or 1]) or mod.PALETTE_ARGB255.GENERIC_WHITE
end

local function _archetype_glyph(profile)
    local arch = profile and profile.archetype and profile.archetype.name
    return (arch and UISettings.archetype_font_icon_simple and UISettings.archetype_font_icon_simple[arch]) or "?"
end

local function _player_for_unit(unit)
    local pm = Managers.player
    return pm and pm:player_by_unit(unit) or nil
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
        local ok, v = pcall(function() return player:is_human_controlled() end)
        if ok then return v end
    end
    if player.is_bot_player then
        local ok, v = pcall(function() return player:is_bot_player() end)
        if ok then return not v end
    end
    if player.is_bot then
        local ok, v = pcall(function() return player:is_bot() end)
        if ok then return not v end
    end
    return true
end

local function _ability_max_cooldown(unit)
    local ability_ext = unit and ScriptUnit.has_extension(unit, "ability_system") and
        ScriptUnit.extension(unit, "ability_system")
    if not ability_ext then return 0 end
    local max = 0
    local ok, v = pcall(function()
        return ability_ext.max_ability_cooldown and
            ability_ext:max_ability_cooldown("combat_ability")
    end)
    if ok and type(v) == "number" and v > 0 then return v end
    ok, v = pcall(function()
        return ability_ext.ability_total_cooldown and
            ability_ext:ability_total_cooldown("combat_ability")
    end)
    if ok and type(v) == "number" and v > 0 then return v end
    ok, v = pcall(function() return ability_ext.cooldown_duration and ability_ext:cooldown_duration("combat_ability") end)
    if ok and type(v) == "number" and v > 0 then return v end
    return 0
end

-- Optional fallbacks (in case V.* isn’t wired yet)
local function _near_stimm_source_fallback()
    if rawget(mod, "near_stimm_source") == true then return true end
    if rawget(mod, "near_stimm_pickup") == true then return true end
    if rawget(mod, "near_any_stimm") == true then return true end
    if rawget(mod, "near_med_station") == true then return true end
    if rawget(mod, "near_stimm_interactable") == true then return true end
    return false
end

-- ===== Team metrics (fallbacks; use mod-provided funcs if present) =====
local function _team_hp_average_frac()
    if type(mod.team_hp_average_frac) == "function" then
        local ok, v = pcall(mod.team_hp_average_frac, mod)
        if ok and type(v) == "number" then return math.clamp(v, 0, 1) end
    end
    local pm = Managers.player
    local sum, n = 0, 0
    if pm and pm.players then
        local ok, players = pcall(function() return pm:players() end)
        if ok and type(players) == "table" then
            for _, p in pairs(players) do
                local u = p and p.player_unit
                if u and Unit.alive(u) then
                    local he = _health_ext(u)
                    if he and he.current_health_percent then
                        sum = sum + math.clamp(he:current_health_percent() or 0, 0, 1)
                        n = n + 1
                    end
                end
            end
        end
    end
    if n == 0 then return 1 end
    return math.clamp(sum / n, 0, 1)
end

local function _team_ammo_need()
    if type(mod.team_ammo_need) == "function" then
        local ok, v = pcall(mod.team_ammo_need, mod)
        if ok and type(v) == "number" then return math.clamp(v, 0, 1) end
    end
    local pm = Managers.player
    local sum, n = 0, 0
    if pm and pm.players then
        local ok, players = pcall(function() return pm:players() end)
        if ok and type(players) == "table" then
            for _, p in pairs(players) do
                local u = p and p.player_unit
                if u and Unit.alive(u) then
                    local uds = _uds(u)
                    if uds then
                        local comp = uds:read_component("slot_secondary")
                        if comp and comp.max_ammunition_reserve and comp.max_ammunition_reserve > 0 then
                            local frac = math.clamp((comp.current_ammunition_reserve or 0) / comp.max_ammunition_reserve,
                                0,
                                1)
                            sum = sum + frac
                            n = n + 1
                        end
                    end
                end
            end
        end
    end
    if n == 0 then return 0 end
    local avg = math.clamp(sum / n, 0, 1)
    return math.clamp(1 - avg, 0, 1) -- need = inverse of reserve level
end

-- ---------- Public: build(unit, marker, opts) ----------
function VM.build(unit, marker, opts)
    local t               = (opts and opts.t) or ((Managers.time and Managers.time:time("ui")) or os.clock())
    local force_show      = (opts and opts.force_show == true) or false

    -- Evaluate once and pass through
    local icon_only       = _icon_only_mode()

    local player          = (opts and opts.player) or _player_for_unit(unit)
    local profile         = player and player:profile()
    local glyph           = _archetype_glyph(profile)
    local tint            = _slot_tint_argb(player and player:slot() or 1)

    -- Peer id (for cloned name lookup) — use template-provided value
    local pid             = (opts and opts.peer_id) or nil

    -- Guard: only show humans (bots hidden in both floating and docked)
    local is_human_unit   = Status.is_human_player_unit and Status.is_human_player_unit(unit) or false
    local is_human_player = _is_human_from_player(player)
    local is_human        = is_human_unit or is_human_player

    -- Name (seeded by RingHud’s own precomposed value when present; otherwise WRU→TL)
    local seeded_text     = marker and marker.data and marker.data.rh_name_composed or nil
    local name            = Name.compose(player, profile, tint, seeded_text)

    -- Health / corruption / toughness
    local he              = _health_ext(unit)
    local wounds          = 1
    local hp_frac         = 0
    local cor_frac        = 0
    if he then
        wounds   = math.clamp((he.num_wounds and he:num_wounds()) or (he.max_wounds and he:max_wounds()) or 1, 1,
            C.MAX_WOUNDS_CAP)
        hp_frac  = math.clamp((he.current_health_percent and he:current_health_percent()) or 0, 0, 1)
        cor_frac = math.clamp((he.permanent_damage_taken_percent and he:permanent_damage_taken_percent()) or 0, 0, 1)
    end
    local tough_state   = T.state(unit)

    -- ► Per-peer HP “recent change” latch (default 5s)
    local hp_show_until = nil
    if pid then
        local prev = _prev_hp_frac_by_pid[pid]
        local eps  = 0.005 -- 0.5% noise guard
        if prev == nil or math.abs((hp_frac or 0) - (prev or 0)) > eps then
            _hp_show_until_by_pid[pid] = (t or 0) + (C.RECENT_HP_CHANGE_LATCH_SEC or 5.0)
        end
        _prev_hp_frac_by_pid[pid] = hp_frac
        hp_show_until = _hp_show_until_by_pid[pid]
    end

    -- Counters (ammo reserve %, ability cooldown seconds) + visibility gates
    local reserve_frac = nil
    do
        local uds = _uds(unit)
        if uds then
            local comp = uds:read_component("slot_secondary")
            if comp and comp.max_ammunition_reserve and comp.max_ammunition_reserve > 0 then
                reserve_frac = math.clamp((comp.current_ammunition_reserve or 0) / comp.max_ammunition_reserve, 0, 1)
            end
        end
    end

    -- ► Per-peer ammo “show until” latch (10s after any change)
    local reserve_show_until = nil
    if pid then
        if reserve_frac ~= nil then
            local prev = _prev_reserve_by_pid[pid]
            if prev == nil or prev ~= reserve_frac then
                _reserve_show_until_by_pid[pid] = (t or 0) + 10.0
            end
            _prev_reserve_by_pid[pid] = reserve_frac
            reserve_show_until = _reserve_show_until_by_pid[pid]
        else
            _prev_reserve_by_pid[pid] = nil
            _reserve_show_until_by_pid[pid] = nil
        end
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

    local show_cd, show_tough = false, false
    if V and V.counters then
        show_cd, show_tough = V.counters(force_show)
    else
        show_cd    = (mod._settings.team_counters == "team_counters_cd" or mod._settings.team_counters == "team_counters_cd_toughness")
        show_tough = (mod._settings.team_counters == "team_counters_toughness" or mod._settings.team_counters == "team_counters_cd_toughness")
        if force_show and mod._settings.team_counters ~= "team_counters_disabled" then
            show_tough = true
        end
    end

    -- Status + icon color
    local status_kind = Status.for_unit and Status.for_unit(unit) or nil
    local status_icon_color = status_kind and UIHudSettings.player_status_colors and
        UIHudSettings.player_status_colors[status_kind] or nil

    -- Assist / ledge / respawn view
    local assist = { show = false, amount = 0, outline_rgba01 = BROKEN_OUTLINE_FLOATS, respawn_digits = nil }
    do
        local has_assist, assist_progress, is_pull_up = false, 0, false
        if HEALTH_ALIVE[unit] and Assist and Assist.progress_for_victim then
            local ok, a, p, pull = pcall(Assist.progress_for_victim, unit)
            if ok then has_assist, assist_progress, is_pull_up = a, (p or 0), (pull or false) end
        end

        if status_kind == "ledge_hanging" then
            if has_assist and is_pull_up then
                assist.show = true; assist.amount = assist_progress or 0; assist.outline_rgba01 = GREEN_OUTLINE_FLOATS
            else
                local frac = Status.ledge_time_remaining_fraction and
                    Status.ledge_time_remaining_fraction(unit, C.LEDGE_TOTAL_WINDOW) or 0
                assist.show = true; assist.amount = frac; assist.outline_rgba01 = BROKEN_OUTLINE_FLOATS
            end
        elseif has_assist and (status_kind == "netted" or status_kind == "hogtied" or status_kind == "knocked_down") then
            assist.show = true; assist.amount = assist_progress or 0; assist.outline_rgba01 = GREEN_OUTLINE_FLOATS
        elseif status_kind == "dead" then
            local secs_left = Status.respawn_secs_remaining and Status.respawn_secs_remaining(player) or nil
            if secs_left and secs_left > 0.01 then
                assist.show = true
                assist.outline_rgba01 = BROKEN_OUTLINE_FLOATS
                local total = C.RESPAWN_TOTAL_WINDOW or 30
                assist.amount = 1 - math.clamp(secs_left / (total > 0 and total or 30), 0, 1)
                assist.respawn_digits = tostring(math.ceil(secs_left))
            end
        end
    end

    assist.amount = math.clamp(assist.amount or 0, 0, 1)

    -- ===========================
    -- Pockets (crate + stimm)
    -- ===========================
    local team_pockets_opt = (mod._settings and mod._settings.team_pockets) or "team_pockets_context"

    local c_icon, c_tint, c_kind, c_map_known = P.crate_icon_and_color(unit)
    local s_icon, s_tint, s_kind, s_map_known = P.stimm_icon_and_color(unit)

    local stimm_show_until = nil
    local crate_show_until = nil

    if pid then
        -- Teammate pickup/change latches (10s)
        local prev_sk = _prev_stimm_kind_by_pid[pid]
        if s_kind ~= nil and s_kind ~= prev_sk then
            _stimm_pickup_show_until_by_pid[pid] = (t or 0) + (C.STIMM_PICKUP_LATCH_SEC or 10)
        end
        _prev_stimm_kind_by_pid[pid] = s_kind
        stimm_show_until = _stimm_pickup_show_until_by_pid[pid]

        local prev_ck = _prev_crate_kind_by_pid[pid]
        if c_kind ~= nil and c_kind ~= prev_ck then
            _crate_pickup_show_until_by_pid[pid] = (t or 0) + (C.CRATE_PICKUP_LATCH_SEC or 10)
        end
        _prev_crate_kind_by_pid[pid] = c_kind
        crate_show_until = _crate_pickup_show_until_by_pid[pid]
    end

    -- Centralized wield latches from visibility module (10s after local wields)
    local latched_stimm = V and V.any_stimm_wield_latched and V.any_stimm_wield_latched() or false
    local latched_crate = V and V.any_crate_wield_latched and V.any_crate_wield_latched() or false

    -- ---------- STIMM ----------
    local stimm_enabled = false
    local stimm_alpha   = 0
    local stimm_full    = false

    if team_pockets_opt == "team_pockets_disabled" then
        stimm_enabled = false
    elseif team_pockets_opt == "team_pockets_always" then
        stimm_enabled = (s_icon ~= nil); stimm_alpha = stimm_enabled and 255 or 0; stimm_full = stimm_enabled
    else
        -- Context mode (your 8 rules)
        local local_dead = (V and V.local_player_is_dead and V.local_player_is_dead()) or false
        local force_all  = force_show or (V and V.force_show_requested and V.force_show_requested()) or false
        local near_src   = (V and V.near_stimm_source and V.near_stimm_source()) or _near_stimm_source_fallback()
        local hi_intense = (V and V.high_intensity_active and V.high_intensity_active()) or
            (rawget(mod, "high_intensity") == true)
        local picked_up  = (stimm_show_until or 0) > (t or 0)

        -- FULL OPACITY triggers (carry stimm only needed where relevant)
        local full       =
            local_dead or                               -- dead → show team fully
            force_all or                                -- force-show hotkey/ADS
            latched_stimm or                            -- 10s after local wields any syringe
            (s_icon ~= nil and s_map_known == false) or -- unknown stimm → always full
            (s_icon ~= nil and hi_intense and           -- high intensity + (power|speed)
                (s_kind == "power" or s_kind == "speed")) or
            near_src or                                 -- local near any stimm source
            picked_up                                   -- 10s after teammate picks/changes stimm

        if full and s_icon ~= nil then
            stimm_enabled = true
            stimm_alpha   = 255
            stimm_full    = true
        else
            -- Contextual opacity (only if carrying the relevant stimm)
            if s_icon ~= nil and s_kind == "corruption" then
                stimm_alpha = math.max(stimm_alpha, P.opacity_for_corruption(hp_frac))
            end
            if s_icon ~= nil and s_kind == "ability" and ability_max > 0 and ability_secs > 0 then
                stimm_alpha = math.max(stimm_alpha, P.opacity_for_ability(ability_secs, ability_max))
            end
            stimm_enabled = (stimm_alpha > 0)
        end
    end

    local stimm_color_argb = nil
    if s_icon and s_tint and (stimm_enabled or team_pockets_opt == "team_pockets_always") then
        stimm_color_argb = table.clone(s_tint)
        if type(stimm_color_argb[1]) == "number" then
            stimm_color_argb[1] = (stimm_alpha and math.clamp(stimm_alpha, 0, 255)) or stimm_color_argb[1]
        end
    end

    -- ---------- CRATE ----------
    local crate_enabled = false
    local crate_alpha   = 0
    local crate_full    = false

    if team_pockets_opt == "team_pockets_disabled" then
        crate_enabled = false
    elseif team_pockets_opt == "team_pockets_always" then
        crate_enabled = (c_icon ~= nil); crate_alpha = crate_enabled and 255 or 0; crate_full = crate_enabled
    else
        local force_all   = force_show or (V and V.force_show_requested and V.force_show_requested()) or false
        local is_grim     = (c_kind == "grimoire")
        local unknown     = (c_map_known == false)
        local hi_intense  = (V and V.high_intensity_active and V.high_intensity_active()) or
            (rawget(mod, "high_intensity") == true)
        local near_src    = (V and V.near_crate_source and V.near_crate_source()) or
            (rawget(mod, "near_crate_source") == true)
        local picked_up_c = (crate_show_until or 0) > (t or 0)
        local wield_any_c = latched_crate
        local dead_or_hog = (V and V.local_player_dead_or_hogtied and V.local_player_dead_or_hogtied()) or false

        local full        =
            force_all or
            is_grim or
            unknown or
            (hi_intense and (c_kind == "medical" or c_kind == "ammo")) or
            near_src or
            picked_up_c or
            wield_any_c or
            dead_or_hog

        if full and c_icon ~= nil then
            crate_enabled = true
            crate_alpha   = 255
            crate_full    = true
        else
            if c_icon ~= nil and c_kind == "medical" then
                crate_alpha = math.max(crate_alpha, P.opacity_for_medical_crate(_team_hp_average_frac()))
            end
            if c_icon ~= nil and c_kind == "ammo" then
                crate_alpha = math.max(crate_alpha, P.opacity_for_ammo_cache(_team_ammo_need()))
            end
            crate_enabled = (crate_alpha > 0)
        end
    end

    local crate_color_argb = nil
    if c_icon and c_tint and (crate_enabled or team_pockets_opt == "team_pockets_always") then
        crate_color_argb = table.clone(c_tint)
        if type(crate_color_argb[1]) == "number" then
            crate_color_argb[1] = (crate_alpha and math.clamp(crate_alpha, 0, 255)) or crate_color_argb[1]
        end
    end

    -- Build teammate peer context for visibility rules
    local peer_ctx        = {
        hp_fraction         = hp_frac,
        corruption_fraction = cor_frac,
        max_wounds_segments = wounds,
        hp_show_until       = hp_show_until,
        tough_overshield    = (tough_state == "overshield"),
        tough_broken        = (tough_state == "broken"),
        unit                = unit,
    }

    -- Apply central visibility (contextual rules come from team/visibility.lua)
    local hp_bars_enabled = (V and V.hp_bar and V.hp_bar(peer_ctx, force_show)) or false
    local hp_text_visible = (V and V.hp_text and V.hp_text(peer_ctx, force_show)) or false

    local tough_int       = 0
    do
        local t_ext = unit and ScriptUnit.has_extension(unit, "toughness_system") and
            ScriptUnit.extension(unit, "toughness_system")
        if t_ext and t_ext.remaining_toughness then
            tough_int = math.floor((t_ext:remaining_toughness() or 0) + 0.5)
        elseif t_ext and t_ext.current_toughness_percent and t_ext.max_toughness_visual then
            tough_int = math.floor((t_ext:current_toughness_percent() or 0) * (t_ext:max_toughness_visual() or 0) + 0.5)
        end
    end

    local ok_flag = is_human and ((unit ~= nil) or (status_kind == "dead"))

    return {
        ok           = ok_flag,
        t            = t,
        force_show   = force_show,

        player       = player,
        profile      = profile,

        -- carry peer id from template
        peer_id      = pid,

        -- Advertise to Apply whether we’re in icon-only mode
        icon_only    = icon_only,

        name_markup  = name,
        arch_glyph   = glyph,
        tint_argb255 = tint, -- {A,R,G,B}

        hp           = {
            wounds       = wounds,
            hp_frac      = hp_frac,
            cor_frac     = cor_frac,
            tough_state  = tough_state,
            bars_enabled = hp_bars_enabled,
            text_visible = hp_text_visible,
        },

        counters     = {
            reserve_frac       = reserve_frac,
            ability_secs       = ability_secs,
            show_cd            = show_cd,
            show_tough_text    = show_tough,
            tough_int          = tough_int,
            -- Per-peer ammo latch timestamp (seconds)
            reserve_show_until = reserve_show_until,
        },

        status       = {
            kind            = status_kind,
            show_icon       = status_kind ~= nil,
            icon_color_argb = status_icon_color,
        },

        assist       = assist,

        pockets      = {
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

return VM
