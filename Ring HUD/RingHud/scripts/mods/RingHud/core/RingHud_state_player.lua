-- File: RingHud/scripts/mods/RingHud/core/RingHud_state_player.lua

local mod = get_mod("RingHud")
if not mod then return {} end

mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
mod:io_dofile("RingHud/scripts/mods/RingHud/systems/buff_handler")

local Intensity           = mod:io_dofile("RingHud/scripts/mods/RingHud/context/intensity_context")
local RingHudState        = {}

local math_clamp          = math.clamp
local math_max            = math.max
local math_ceil           = math.ceil

-- Broker Chemical Dependency Cache
local _broker_chem_next_t = 0
local _broker_chem_cache  = { stacks = 0, end_time = 0 }

local _ogryn_maul_cache   = { cooldown_end = 0 }

-- Reusable state table to reduce GC pressure
local _cached_hud_state   = {
    gameplay_t                         = 0,
    player_extensions                  = nil,
    unit_data                          = nil,

    stimm_item_name                    = nil,
    stimm_icon_path                    = nil,
    crate_item_name                    = nil,
    crate_icon_path                    = nil,

    peril_fraction                     = 0,
    is_peril_driven_by_warp            = false,

    stamina_fraction                   = 0,

    charge_fraction                    = 0,
    charge_system_type                 = nil,
    charge_max_charges                 = 0,
    charge_current_charges             = 0,
    charge_weapon_template_name        = nil,
    charge_weapon_slot                 = nil,
    charge_is_dual_shivs               = false,

    -- Thrust (heavy windup) segmented charge (primary weapon only)
    charge_has_thrust                  = false,
    charge_thrust_stacks               = 0, -- 0..3
    charge_thrust_progress             = 0, -- 0..1 fill of next segment
    charge_thrust_max_stacks           = 3, -- constant for now
    charge_thrust_charge_level         = 0, -- raw 0..1 action_module_charge.charge_level

    latched_dual_shiv_max              = 0,
    latched_dual_shiv_current          = 0,

    dodge_data                         = {
        current_dodges              = 0,
        efficient_dodges_display    = 0,
        max_efficient_dodges_actual = 1,
        has_infinite                = false,
        remaining_efficient         = 0
    },

    toughness_data                     = { raw_fraction = 0, display_fraction = 0, has_overshield = false },

    health_data                        = { current_fraction = 0.5, corruption_fraction = 0, current_health = 0, max_health = 0 },

    grenade_data                       = {
        current             = 0,
        current_charges     = 0,
        max                 = 0,
        max_charges         = 0,
        live_max            = 0,
        is_regenerating     = false,
        replenish_buff_name = nil,
        max_cooldown        = 0,
        regen_progress      = 0
    },

    ammo_data                          = {
        current_clip         = 0,
        max_clip             = 0,
        uses_ammo            = false,
        current_reserve      = 0,
        max_reserve          = 0,
        wielded_slot_name    = nil,
        has_infinite_reserve = false
    },

    most_recent_shot_cost_this_mission = 0,

    timer_data                         = {
        buff_timer_value                 = 0,
        buff_max_duration                = 0,
        ability_cooldown_remaining       = 0,
        is_ability_on_cooldown_for_timer = false,
        max_combat_ability_cooldown      = 0,
    },

    peril_data                         = {
        value                    = 0,
        source                   = "warp",
        other_overheat_fraction  = 0,
        other_overheat_slot_name = nil,
    },

    ability_data                       = {
        remaining_charges  = 0,
        max_charges        = 0,
        remaining_cooldown = 0,
        max_cooldown       = 0,
        paused             = false
    },

    broker_stimm_data                  = {
        is_broker            = false,
        buff_remaining       = 0,
        buff_duration        = 0,
        cooldown_remaining   = 0,
        cooldown_max         = 0,
        chem_stacks          = 0,
        chem_decay_remaining = 0,
    },

    talent_data                        = {
        cooldown_fraction        = 0,
        is_active                = false,
        is_available             = false,
        stacks                   = 0,
        segment_max              = nil, -- nil unless a segmented talent mode is active (psyker / adamant)
        mode                     = nil, -- "zealot_resist_death" | "psyker_empowered_grenades" | "broker_toughness_broken_cd" | "adamant_terminus_warrant"

        -- Adamant: Terminus Warrant stacks (explicit, so nothing can stick)
        adamant_tw_melee_stacks  = 0,
        adamant_tw_ranged_stacks = 0,
    },

    -- Veteran: Deadshot ADS stamina drain (used by draw/visibility logic elsewhere)
    is_veteran_deadshot_adsing         = false,

    is_music_high_intensity            = false,
    is_high_intensity_timer_active     = false,

    prox_ammo                          = 0,
    prox_healing                       = 0,
    prox_stimm                         = false,
    prox_crate                         = false,

    pocketable_pickup_timer            = 0,
    last_picked_up_pocketable_name     = nil,

    team_average_health_fraction       = 1.0,
    team_average_ammo_fraction         = 1.0,
}

local ALLOWED_BUFF_NAMES  = {
    psyker_overcharge_stance_infinite_casting = true, -- Warp Unbound
    veteran_combat_ability_stance_master      = true, -- Volley Fire/Executioner Stance
    veteran_invisibility                      = true, -- Infiltrate
    zealot_invisibility                       = true, -- Shroudfield
    zealot_invisibility_increased_duration    = true, -- Longer Shroudfield
    ogryn_ranged_stance                       = true, -- Point Blank Barrage
    broker_focus_stance                       = true, -- Desperado
    broker_focus_stance_improved              = true, -- Improved Desperado
    broker_punk_rage_stance                   = true, -- Rampage
}

local function _now()
    local MT = Managers and Managers.time
    if MT and MT.time then
        return MT:time("gameplay") or MT:time("ui") or os.clock()
    end
    return os.clock()
end

-- ####################################################################################################
-- ## Public Module Functions
-- ####################################################################################################

function RingHudState.get_hud_data_state(ring_hud_instance)
    local hud_state                               = _cached_hud_state

    local gameplay_t                              = (Managers.time and Managers.time:time("gameplay")) or 0
    hud_state.gameplay_t                          = gameplay_t

    -- Reset transient fields
    hud_state.player_extensions                   = nil
    hud_state.unit_data                           = nil
    hud_state.stimm_item_name                     = nil
    hud_state.stimm_icon_path                     = nil
    hud_state.crate_item_name                     = nil
    hud_state.crate_icon_path                     = nil
    hud_state.charge_system_type                  = nil
    hud_state.charge_weapon_template_name         = nil
    hud_state.charge_weapon_slot                  = nil
    hud_state.charge_is_dual_shivs                = false
    hud_state.peril_data.other_overheat_slot_name = nil

    -- Reset thrust fields
    hud_state.charge_has_thrust                   = false
    hud_state.charge_thrust_stacks                = 0
    hud_state.charge_thrust_progress              = 0
    hud_state.charge_thrust_max_stacks            = mod.THRUST_MAX_STACKS or 3
    hud_state.charge_thrust_charge_level          = 0

    hud_state.most_recent_shot_cost_this_mission  = 0

    -- Default values (including nested tables, so we never render stale state on early returns)
    hud_state.peril_fraction                      = 0
    hud_state.is_peril_driven_by_warp             = false
    hud_state.stamina_fraction                    = 0
    hud_state.charge_fraction                     = 0
    hud_state.charge_max_charges                  = 0
    hud_state.charge_current_charges              = 0

    do
        local dd                       = hud_state.dodge_data
        dd.current_dodges              = 0
        dd.efficient_dodges_display    = 0
        dd.max_efficient_dodges_actual = 1
        dd.has_infinite                = false
        dd.remaining_efficient         = 0
    end

    do
        local td            = hud_state.toughness_data
        td.raw_fraction     = 0
        td.display_fraction = 0
        td.has_overshield   = false
    end

    do
        local hd               = hud_state.health_data
        hd.current_fraction    = 0
        hd.corruption_fraction = 0
        hd.current_health      = 0
        hd.max_health          = 0
    end

    do
        local gd               = hud_state.grenade_data
        gd.current             = 0
        gd.current_charges     = 0
        gd.max                 = 0
        gd.max_charges         = 0
        gd.live_max            = 0
        gd.is_regenerating     = false
        gd.replenish_buff_name = nil
        gd.max_cooldown        = 0
        gd.regen_progress      = 0
    end

    do
        local ad                = hud_state.ammo_data
        ad.current_clip         = 0
        ad.max_clip             = 0
        ad.uses_ammo            = false
        ad.current_reserve      = 0
        ad.max_reserve          = 0
        ad.wielded_slot_name    = nil
        ad.has_infinite_reserve = false
    end

    do
        local td                            = hud_state.timer_data
        td.buff_timer_value                 = 0
        td.buff_max_duration                = 0
        td.ability_cooldown_remaining       = 0
        td.is_ability_on_cooldown_for_timer = false
        td.max_combat_ability_cooldown      = 0
    end

    do
        local bd                = hud_state.broker_stimm_data
        bd.is_broker            = false
        bd.buff_remaining       = 0
        bd.buff_duration        = 0
        bd.cooldown_remaining   = 0
        bd.cooldown_max         = 0
        bd.chem_stacks          = 0
        bd.chem_decay_remaining = 0
    end

    do
        local tl                    = hud_state.talent_data
        tl.cooldown_fraction        = 0
        tl.is_active                = false
        tl.is_available             = false
        tl.stacks                   = 0
        tl.segment_max              = nil
        tl.mode                     = nil

        -- Adamant: Terminus Warrant stacks (explicit, so nothing can stick)
        tl.adamant_tw_melee_stacks  = 0
        tl.adamant_tw_ranged_stacks = 0
    end

    hud_state.peril_data.value                    = 0
    hud_state.peril_data.source                   = "warp"
    hud_state.peril_data.other_overheat_fraction  = 0
    hud_state.peril_data.other_overheat_slot_name = nil

    hud_state.ability_data.remaining_charges      = 0
    hud_state.ability_data.max_charges            = 0
    hud_state.ability_data.remaining_cooldown     = 0
    hud_state.ability_data.max_cooldown           = 0
    hud_state.ability_data.paused                 = false

    -- Ensure this is always reset in the state template (it’s written later in this function)
    hud_state.is_veteran_deadshot_adsing          = false

    -- Retrieve archetype once at start (cached/hot path)
    local archetype_name                          = mod.get_local_archetype()

    -- Talent data should update every frame if possible, even if other RingHud subsystems early-return.
    local player                                  = (Managers.player and Managers.player.local_player_safe and Managers.player:local_player_safe(1)) or
        nil
    local player_unit                             = player and player.player_unit
    if player_unit and type(mod.talent_update_state) == "function" then
        mod.talent_update_state(player, player_unit, hud_state)
    end

    local parent_hud = ring_hud_instance and ring_hud_instance._parent
    hud_state.player_extensions = parent_hud and parent_hud:player_extensions()
    if not hud_state.player_extensions or not gameplay_t then
        hud_state.is_music_high_intensity        = Intensity.high_intensity_active()
        hud_state.is_high_intensity_timer_active = Intensity.is_timer_active()
        return hud_state
    end

    hud_state.unit_data = hud_state.player_extensions.unit_data
    local unit_data_comp_access_point
    local weapon_ext, buff_ext, health_ext, toughness_ext, ability_ext, inv_comp
    if hud_state.unit_data then
        unit_data_comp_access_point = hud_state.unit_data
        weapon_ext                  = hud_state.player_extensions.weapon
        buff_ext                    = hud_state.player_extensions.buff
        health_ext                  = hud_state.player_extensions.health
        toughness_ext               = hud_state.player_extensions.toughness
        ability_ext                 = hud_state.player_extensions.ability
        inv_comp                    = unit_data_comp_access_point:read_component("inventory")
    else
        hud_state.is_music_high_intensity        = Intensity.high_intensity_active()
        hud_state.is_high_intensity_timer_active = Intensity.is_timer_active()
        return hud_state
    end
    if not (weapon_ext and buff_ext and health_ext and toughness_ext and ability_ext and inv_comp) then
        hud_state.is_music_high_intensity        = Intensity.high_intensity_active()
        hud_state.is_high_intensity_timer_active = Intensity.is_timer_active()
        return hud_state
    end

    if player_unit then
        local visual_loadout_extension = ScriptUnit.has_extension(player_unit, "visual_loadout_system")
            and ScriptUnit.extension(player_unit, "visual_loadout_system")
        if visual_loadout_extension and visual_loadout_extension.weapon_template_from_slot then
            local stimm_template = visual_loadout_extension:weapon_template_from_slot("slot_pocketable_small")
            if stimm_template and stimm_template.name then
                hud_state.stimm_item_name = stimm_template.name
                hud_state.stimm_icon_path = stimm_template.hud_icon_small
            end

            local crate_template = visual_loadout_extension:weapon_template_from_slot("slot_pocketable")
            if crate_template and crate_template.name then
                hud_state.crate_item_name = crate_template.name
                hud_state.crate_icon_path = crate_template.hud_icon_small
            end
        end
    end

    -- Proximity flags
    hud_state.prox_ammo                    = mod.prox_ammo or 0
    hud_state.prox_healing                 = mod.prox_healing or 0
    hud_state.prox_stimm                   = mod.prox_stimm or false
    hud_state.prox_crate                   = mod.prox_crate or false

    hud_state.team_average_health_fraction = mod.team_average_health_fraction
    hud_state.team_average_ammo_fraction   = mod.team_average_ammo_fraction

    if ring_hud_instance then
        hud_state.pocketable_pickup_timer        = ring_hud_instance._pocketable_pickup_visibility_timer or 0
        hud_state.last_picked_up_pocketable_name = ring_hud_instance._last_picked_up_pocketable_name
    end

    -- Peril (warp vs overheat)
    local warp_charge_comp = unit_data_comp_access_point:read_component("warp_charge")
    local warp_level       = warp_charge_comp and warp_charge_comp.current_percentage or 0

    local wielded_slot     = inv_comp and inv_comp.wielded_slot
    local current_template = weapon_ext and weapon_ext:weapon_template()

    local overheat_source  = "overheat:none"
    local overheat_level   = 0

    local has_peril_funcs  = mod.peril_slot_is_weapon and mod.peril_template_generates_overheat
        and mod.peril_read_slot_overheat

    if has_peril_funcs then
        if mod.peril_slot_is_weapon(wielded_slot) and mod.peril_template_generates_overheat(current_template) then
            overheat_level  = mod.peril_read_slot_overheat(unit_data_comp_access_point, wielded_slot)
            overheat_source = "overheat:wielded"
        else
            local p = mod.peril_read_slot_overheat(unit_data_comp_access_point, "slot_primary")
            local s = mod.peril_read_slot_overheat(unit_data_comp_access_point, "slot_secondary")
            if p >= s then
                overheat_level  = p
                overheat_source = "overheat:slot_primary"
            else
                overheat_level  = s
                overheat_source = "overheat:slot_secondary"
            end
        end
    end

    hud_state.is_peril_driven_by_warp = warp_level > overheat_level
    hud_state.peril_fraction          = hud_state.is_peril_driven_by_warp and warp_level or overheat_level
    hud_state.peril_data.value        = hud_state.peril_fraction
    hud_state.peril_data.source       = hud_state.is_peril_driven_by_warp and "warp" or overheat_source

    do
        hud_state.peril_data.other_overheat_fraction  = 0
        hud_state.peril_data.other_overheat_slot_name = nil

        if has_peril_funcs and not hud_state.is_peril_driven_by_warp then
            local current_slot_name = nil
            if overheat_source == "overheat:slot_primary" then
                current_slot_name = "slot_primary"
            elseif overheat_source == "overheat:slot_secondary" then
                current_slot_name = "slot_secondary"
            elseif overheat_source == "overheat:wielded" and mod.peril_slot_is_weapon(wielded_slot) then
                if wielded_slot == "slot_primary" or wielded_slot == "slot_secondary" then
                    current_slot_name = wielded_slot
                end
            end

            if current_slot_name == "slot_primary" or current_slot_name == "slot_secondary" then
                local other_slot = (current_slot_name == "slot_primary") and "slot_secondary" or "slot_primary"
                local other_heat = mod.peril_read_slot_overheat(unit_data_comp_access_point, other_slot)

                if (other_heat or 0) > 0 then
                    hud_state.peril_data.other_overheat_fraction  = math_clamp(other_heat, 0, 1)
                    hud_state.peril_data.other_overheat_slot_name = other_slot
                end
            end
        end
    end

    -- Stamina
    local stamina_comp_data    = unit_data_comp_access_point:read_component("stamina")
    hud_state.stamina_fraction = stamina_comp_data and stamina_comp_data.current_fraction or 0

    -- Charge mechanics
    local wielded_slot_charge  = inv_comp.wielded_slot
    if weapon_ext and wielded_slot_charge and wielded_slot_charge ~= "none" then
        local current_wep_template = weapon_ext:weapon_template()

        hud_state.charge_weapon_slot = wielded_slot_charge
        if current_wep_template and current_wep_template.name then
            hud_state.charge_weapon_template_name = current_wep_template.name
        end

        local is_missile_launcher = (hud_state.charge_weapon_template_name == "missile_launcher")

        if not is_missile_launcher then
            if archetype_name == "ogryn"
                and hud_state.charge_weapon_template_name
                and string.find(hud_state.charge_weapon_template_name, "powermaul")
            then
                local inv_comp_slot = unit_data_comp_access_point:read_component(wielded_slot_charge)
                local charges = inv_comp_slot and inv_comp_slot.num_special_charges or 0
                local t = gameplay_t

                if charges > 0 then
                    -- Reset: we have charges, so not in cooldown.
                    hud_state.charge_fraction = 1.0
                    _ogryn_maul_cache.cooldown_end = 0
                else
                    -- We are empty (0 charges). Are we currently tracking a cooldown?
                    if _ogryn_maul_cache.cooldown_end == 0 then
                        -- Start the timer now (12s hardcoded)
                        _ogryn_maul_cache.cooldown_end = t + 12.0
                    end

                    local rem = _ogryn_maul_cache.cooldown_end - t
                    if rem <= 0 then
                        hud_state.charge_fraction = 1.0
                    else
                        hud_state.charge_fraction = math_clamp(1.0 - (rem / 12.0), 0, 1)
                    end
                end

                hud_state.charge_system_type = "ogryn_powermaul"
            end

            local special_tweak = current_wep_template and current_wep_template.weapon_special_tweak_data
            if special_tweak and special_tweak.max_charges then
                local wielded_wep_comp           = unit_data_comp_access_point:read_component(wielded_slot_charge)
                local max_charges                = special_tweak.max_charges or 0
                local current_charges            = (wielded_wep_comp and wielded_wep_comp.num_special_charges) or 0

                hud_state.charge_max_charges     = max_charges
                hud_state.charge_current_charges = current_charges

                if special_tweak.charge_remove_time and not special_tweak.passive_charge_add_interval then
                    hud_state.charge_system_type = "kill_count"
                elseif special_tweak.passive_charge_add_interval then
                    hud_state.charge_system_type = "block_passive"
                end

                if (hud_state.charge_system_type == "kill_count" or hud_state.charge_system_type == "block_passive")
                    and max_charges > 0
                then
                    hud_state.charge_fraction = current_charges / max_charges
                end

                local tmpl_name = hud_state.charge_weapon_template_name
                if wielded_slot_charge == "slot_primary"
                    and tmpl_name
                    and string.sub(tmpl_name, 1, 13) == "dual_shivs_p1"
                then
                    hud_state.charge_is_dual_shivs = true

                    mod._latched_dual_shiv_max = hud_state.charge_max_charges
                    mod._latched_dual_shiv_current = hud_state.charge_current_charges
                end
            end

            if not hud_state.charge_system_type then
                local action_module_charge_comp_data = unit_data_comp_access_point:read_component("action_module_charge")
                local charge_level = action_module_charge_comp_data and action_module_charge_comp_data.charge_level or 0

                if charge_level > 0 then
                    hud_state.charge_system_type = "action_module"
                    hud_state.charge_fraction    = charge_level
                end

                -- Thrust (heavy windup) segmented display: only relevant for wielded primary.
                if wielded_slot_charge == "slot_primary"
                    and hud_state.charge_weapon_template_name
                    and player_unit
                    and mod.update_thrust_state
                then
                    mod.update_thrust_state(
                        player_unit,
                        hud_state.charge_weapon_template_name,
                        charge_level,
                        hud_state
                    )

                    -- If Thrust was detected, ensure system type is set so the feature renders
                    if hud_state.charge_has_thrust then
                        hud_state.charge_system_type = "action_module"
                    end
                elseif wielded_slot_charge == "slot_secondary" and player_unit and mod.update_ranged_windup_state then
                    mod.update_ranged_windup_state(player_unit, hud_state)

                    if hud_state.charge_has_thrust then
                        hud_state.charge_system_type = "action_module"
                    end
                end
            end
        end
    end
    hud_state.charge_fraction = math_clamp(hud_state.charge_fraction, 0, 1)

    -- Dodge DR
    local dodge_state_comp    = unit_data_comp_access_point:read_component("dodge_character_state")
    local move_state_comp     = unit_data_comp_access_point:read_component("movement_state")
    local slide_state_comp    = unit_data_comp_access_point:read_component("slide_character_state")
    local wep_dodge_template  = weapon_ext:dodge_template()
    if dodge_state_comp and move_state_comp and slide_state_comp then
        local cd_raw, dr_start_val, dr_limit_base_val    =
            mod.dodge_calculate_diminishing_return(
                dodge_state_comp,
                move_state_comp,
                slide_state_comp,
                wep_dodge_template,
                buff_ext,
                gameplay_t
            )

        local ned_raw                                    = dr_start_val
        hud_state.dodge_data.current_dodges              = cd_raw
        hud_state.dodge_data.max_efficient_dodges_actual = ned_raw

        if ned_raw >= math.huge then
            hud_state.dodge_data.has_infinite             = true
            hud_state.dodge_data.efficient_dodges_display = mod.MAX_DODGE_SEGMENTS
            hud_state.dodge_data.remaining_efficient      = math.huge
        else
            local num_eff_actual                          = math_ceil(ned_raw or 0)
            hud_state.dodge_data.efficient_dodges_display = math.min(num_eff_actual, mod.MAX_DODGE_SEGMENTS)
            hud_state.dodge_data.remaining_efficient      = math_max(0, num_eff_actual - cd_raw)
        end
    end

    -- Toughness & Health
    if toughness_ext then
        hud_state.toughness_data.raw_fraction     = toughness_ext:current_toughness_percent() or 0
        hud_state.toughness_data.display_fraction = toughness_ext:current_toughness_percent_visual() or 0

        local current_toughness_val               = hud_state.toughness_data.raw_fraction *
            (toughness_ext:max_toughness() or 0)
        local visual_max_val                      = toughness_ext:max_toughness_visual() or 0
        if visual_max_val and visual_max_val > 0 then
            hud_state.toughness_data.has_overshield = current_toughness_val > (visual_max_val + 5)
        end
    end

    if health_ext then
        hud_state.health_data.current_fraction    = health_ext:current_health_percent() or 0
        hud_state.health_data.corruption_fraction = math_clamp(health_ext:permanent_damage_taken_percent() or 0, 0, 1)
        hud_state.health_data.current_health      = health_ext:current_health() or 0
        hud_state.health_data.max_health          = health_ext:max_health() or 0
    end

    -- Grenades (pass the same player_unit we already fetched)
    mod.grenades_update_state(unit_data_comp_access_point, ability_ext, player_unit, hud_state.grenade_data)

    -- Ability info
    if ability_ext and ability_ext:ability_is_equipped("combat_ability") then
        local rem_cd                              = ability_ext:remaining_ability_cooldown("combat_ability") or 0
        local max_cd                              = ability_ext:max_ability_cooldown("combat_ability") or 0
        local paused                              = ability_ext:is_cooldown_paused("combat_ability") or false
        local rem_ch                              = ability_ext:remaining_ability_charges("combat_ability") or 0
        local max_ch                              = ability_ext:max_ability_charges("combat_ability") or 0

        hud_state.ability_data.remaining_charges  = rem_ch
        hud_state.ability_data.max_charges        = max_ch
        hud_state.ability_data.remaining_cooldown = rem_cd
        hud_state.ability_data.max_cooldown       = max_cd
        hud_state.ability_data.paused             = paused
    end

    -- Ammo
    do
        local ammo_data = hud_state.ammo_data
        -- Use cached archetype
        if mod.ammo_clip_update_state then
            mod.ammo_clip_update_state(unit_data_comp_access_point, weapon_ext, inv_comp, ammo_data, archetype_name)
        end

        if mod.ammo_reserve_update_state then
            mod.ammo_reserve_update_state(unit_data_comp_access_point, ammo_data)
        end

        if ammo_data.wielded_slot_name == "slot_secondary" and ammo_data.uses_ammo then
            local current_clip = ammo_data.current_clip
            local max_clip     = ammo_data.max_clip
            local prev_clip    = mod._prev_secondary_clip_ammo

            if prev_clip ~= nil and current_clip < prev_clip then
                local diff = prev_clip - current_clip

                if diff > 0 then
                    -- Ignore shots that empty the clip (likely partial shots) unless the weapon
                    -- only holds 1 shot to begin with (e.g. Kickback/Rumbler).
                    if current_clip > 0 or max_clip == 1 then
                        mod._most_recent_shot_cost_this_mission = diff
                    end
                end
            end
            mod._prev_secondary_clip_ammo = current_clip
        else
            mod._prev_secondary_clip_ammo = nil
        end
    end

    hud_state.most_recent_shot_cost_this_mission = mod._most_recent_shot_cost_this_mission

    -- ADS stamina drain for Deadshot
    hud_state.is_veteran_deadshot_adsing = false
    if player and unit_data_comp_access_point then
        -- Use cached archetype
        local player_profile = player:profile()
        if archetype_name == "veteran"
            and player_profile
            and player_profile.talents
            and player_profile.talents.veteran_ads_drain_stamina
        then
            local alternate_fire_comp = unit_data_comp_access_point:read_component("alternate_fire")
            if alternate_fire_comp and alternate_fire_comp.is_active then
                hud_state.is_veteran_deadshot_adsing = true
            end
        end
    end

    -- Buff timers + ability timer (STRICT allow-list)
    if player_unit then
        -- Use cached archetype
        local player_unit_timer = player_unit
        local broker_data       = hud_state.broker_stimm_data

        -- Broker stimm: buff + cooldown for the stimm ability
        if archetype_name == "broker" then
            broker_data.is_broker            = true
            broker_data.buff_remaining       = 0
            broker_data.buff_duration        = 0
            broker_data.cooldown_remaining   = 0
            broker_data.cooldown_max         = 0
            broker_data.chem_stacks          = 0
            broker_data.chem_decay_remaining = 0

            local buff_ext_broker            = ScriptUnit.has_extension(player_unit_timer, "buff_system")
                and ScriptUnit.extension(player_unit_timer, "buff_system")

            if buff_ext_broker then
                -- 1. Check for Active Stimm Buff
                if buff_ext_broker._buffs_by_index then
                    for _, buff_instance in pairs(buff_ext_broker._buffs_by_index) do
                        local name = mod.buff_template_name(buff_instance)
                        if name == "syringe_broker_buff" then
                            local duration = buff_instance:duration()
                            local progress = buff_instance:duration_progress() or 0
                            if duration and duration > 0 then
                                local remaining = duration * progress
                                if remaining > 0 then
                                    broker_data.buff_duration  = duration
                                    broker_data.buff_remaining = remaining
                                end
                            end
                            break
                        end
                    end
                end

                -- 2. Check for Chemical Dependency Stacks (Throttled)
                local t_game = gameplay_t

                -- Check throttle (handle wrap-around/reset by checking if next_t is far in future)
                if t_game >= _broker_chem_next_t or t_game < (_broker_chem_next_t - 5.0) then
                    _broker_chem_next_t = t_game + 0.5

                    local chem_buff = buff_ext_broker._stacking_buffs and
                        buff_ext_broker._stacking_buffs["broker_keystone_chemical_dependency_stack"]
                    if chem_buff then
                        _broker_chem_cache.stacks = chem_buff:stack_count() or 0
                        local duration = chem_buff:duration()
                        local start_time = chem_buff:start_time()
                        if duration and start_time then
                            _broker_chem_cache.end_time = start_time + duration
                        else
                            _broker_chem_cache.end_time = 0
                        end
                    else
                        _broker_chem_cache.stacks = 0
                        _broker_chem_cache.end_time = 0
                    end
                end

                broker_data.chem_stacks = _broker_chem_cache.stacks
                if _broker_chem_cache.end_time > 0 then
                    broker_data.chem_decay_remaining = math_max(0, _broker_chem_cache.end_time - t_game)
                else
                    broker_data.chem_decay_remaining = 0
                end
            end

            -- Stimm Cooldown
            local ability_ext_broker = ScriptUnit.has_extension(player_unit_timer, "ability_system")
                and ScriptUnit.extension(player_unit_timer, "ability_system")
            local STIMM_ABILITY_TYPE = "pocketable_ability"

            if ability_ext_broker and ability_ext_broker:ability_is_equipped(STIMM_ABILITY_TYPE) then
                local equipped = ability_ext_broker:equipped_abilities()
                local pa       = equipped and equipped[STIMM_ABILITY_TYPE]

                if pa and pa.ability_group == "broker_syringe" then
                    local rem = ability_ext_broker:remaining_ability_cooldown(STIMM_ABILITY_TYPE)

                    if rem and rem > 0 then
                        broker_data.cooldown_remaining = rem
                        broker_data.cooldown_max       = ability_ext_broker:max_ability_cooldown(STIMM_ABILITY_TYPE) or 0
                    else
                        broker_data.cooldown_remaining = 0
                        broker_data.cooldown_max       = broker_data.cooldown_max or 0
                    end
                end
            end
        end

        local longest_buff_time_remaining = 0
        local longest_buff_duration       = 0

        local buff_ext_timer              = ScriptUnit.has_extension(player_unit_timer, "buff_system")
            and ScriptUnit.extension(player_unit_timer, "buff_system")
        if buff_ext_timer and buff_ext_timer._buffs_by_index then
            for _, buff_instance in pairs(buff_ext_timer._buffs_by_index) do
                local name = mod.buff_template_name(buff_instance)
                if name and ALLOWED_BUFF_NAMES[name] then
                    local has_duration = buff_instance.duration ~= nil and type(buff_instance.duration) == "function"
                    local has_progress = buff_instance.duration_progress ~= nil and
                        type(buff_instance.duration_progress) == "function"
                    if has_duration and has_progress then
                        local duration = buff_instance:duration()
                        if duration and duration > 0 then
                            local progress       = buff_instance:duration_progress() or 0
                            local time_remaining = duration * progress
                            if time_remaining > longest_buff_time_remaining then
                                longest_buff_time_remaining = time_remaining
                                longest_buff_duration       = duration
                            end
                        end
                    end
                end
            end
        end

        hud_state.timer_data.buff_timer_value  = longest_buff_time_remaining
        hud_state.timer_data.buff_max_duration = longest_buff_duration

        local unit_data_system                 = ScriptUnit.has_extension(player_unit_timer, "unit_data_system")
            and ScriptUnit.extension(player_unit_timer, "unit_data_system")
        local ability_comp                     = unit_data_system and unit_data_system:read_component("combat_ability")
        local absolute_next_charge_at          = ability_comp and ability_comp.cooldown

        if gameplay_t and absolute_next_charge_at and absolute_next_charge_at > gameplay_t then
            hud_state.timer_data.ability_cooldown_remaining = absolute_next_charge_at - gameplay_t
        else
            hud_state.timer_data.ability_cooldown_remaining = 0
        end

        local ability_ext_for_cd = hud_state.player_extensions.ability
        if ability_ext_for_cd then
            hud_state.timer_data.max_combat_ability_cooldown =
                ability_ext_for_cd:max_ability_cooldown("combat_ability") or 0
        end

        hud_state.timer_data.is_ability_on_cooldown_for_timer =
            (hud_state.timer_data.ability_cooldown_remaining or 0) > 0

        if (hud_state.timer_data.buff_timer_value or 0) > 0 and (hud_state.timer_data.buff_max_duration or 0) > 0 then
            hud_state.timer_data.is_ability_on_cooldown_for_timer = false
            hud_state.timer_data.ability_cooldown_remaining       = 0
        end
    end

    hud_state.is_music_high_intensity        = Intensity.high_intensity_active()
    hud_state.is_high_intensity_timer_active = Intensity.is_timer_active()

    hud_state.latched_dual_shiv_max          = mod._latched_dual_shiv_max or 0
    hud_state.latched_dual_shiv_current      = mod._latched_dual_shiv_current or 0

    return hud_state
end

return RingHudState
