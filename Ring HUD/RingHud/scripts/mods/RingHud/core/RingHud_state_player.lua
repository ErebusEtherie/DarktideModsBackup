-- File: RingHud/scripts/mods/RingHud/core/RingHud_state_player.lua

local mod = get_mod("RingHud")
if not mod then return {} end

local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")
local PlayerUnitStatus         = require("scripts/utilities/attack/player_unit_status")

local Intensity                = mod:io_dofile("RingHud/scripts/mods/RingHud/context/intensity_context")

local RingHudState             = {}

local wep_slots_cache          = {}
if PlayerCharacterConstants and PlayerCharacterConstants.slot_configuration then
    for slot_id, config in pairs(PlayerCharacterConstants.slot_configuration) do
        if config and config.slot_type == "weapon" then
            wep_slots_cache[#wep_slots_cache + 1] = slot_id
        end
    end
end
local num_wep_slots_cache = #wep_slots_cache

-- ####################################################################################################
-- ## Private Helper Functions
--   (intentionally empty after moving dodge DR to mod.dodge_calculate_diminishing_return)
-- ####################################################################################################

-- Strict allow-list: only these 7 stance/stealth buffs should drive the timer.
local ALLOWED_BUFF_NAMES = {
    psyker_overcharge_stance_infinite_casting = true, -- Warp Unbound
    veteran_combat_ability_stance_master      = true, -- Volley Fire/Executioner Stance
    veteran_invisibility                      = true, -- Infiltrate
    zealot_invisibility                       = true, -- Shroudfield
    zealot_invisibility_increased_duration    = true, -- Longer Shroudfield
    ogryn_ranged_stance                       = true, -- Point Blank Barrage
}

-- Optional tiny efficiency gate: we only ever show timers for these archetypes.
local MONITORED_ARCHETYPES = {
    psyker  = true,
    veteran = true,
    zealot  = true,
    ogryn   = true,
}

-- ####################################################################################################
-- ## Public Module Functions
-- ####################################################################################################

function RingHudState.get_hud_data_state(ring_hud_instance)
    local hud_state = {
        gameplay_t = Managers.time and Managers.time:time("gameplay") or 0,
        player_extensions = nil,
        unit_data = nil,

        stimm_item_name = nil,
        stimm_icon_path = nil,
        crate_item_name = nil,
        crate_icon_path = nil,

        peril_fraction = 0,
        is_peril_driven_by_warp = false,

        stamina_fraction = 0,

        charge_fraction = 0,
        charge_system_type = nil,

        dodge_data = {
            current_dodges = 0,
            efficient_dodges_display = 0,
            max_efficient_dodges_actual = 1,
            has_infinite = false,
            remaining_efficient = 0
        },

        toughness_data = { raw_fraction = 0, display_fraction = 0, has_overshield = false },

        health_data = { current_fraction = 0.5, corruption_fraction = 0, current_health = 0, max_health = 0 },

        grenade_data = {
            current = 0,
            current_charges = 0,
            max = 0,
            max_charges = 0,
            live_max = 0,
            is_regenerating = false,
            replenish_buff_name = nil,
            max_cooldown = 0,
            regen_progress = 0
        },

        ammo_data = {
            current_clip = 0,
            max_clip = 0,
            uses_ammo = false,
            current_reserve = 0,
            max_reserve = 0,
            wielded_slot_name = nil,
            has_infinite_reserve = false
        },

        -- Simplified timer data:
        --  - buff_timer_value / buff_max_duration: stance/stealth buff timers (if any)
        --  - ability_cooldown_remaining: seconds until the NEXT charge is restored
        --  - is_ability_on_cooldown_for_timer: boolean flag for single-number cooldown visibility
        --  - max_combat_ability_cooldown: max cooldown (used for synthesis elsewhere if needed)
        timer_data = {
            buff_timer_value = 0,
            buff_max_duration = 0,
            ability_cooldown_remaining = 0,
            is_ability_on_cooldown_for_timer = false,
            max_combat_ability_cooldown = 0,
        },

        peril_data = {
            value = 0,
            source = "warp",
            other_overheat_fraction = 0,
            other_overheat_slot_name = nil,
        },

        ability_data = { remaining_charges = 0, max_charges = 0, remaining_cooldown = 0, max_cooldown = 0, paused = false },

        -- Published from Intensity system (single source of truth)
        is_music_high_intensity = false,
        is_high_intensity_timer_active = false,

        near_any_stimm_source = false,
        near_any_crate_source = false,

        pocketable_pickup_timer = 0,
        last_picked_up_pocketable_name = nil,

        team_average_health_fraction = 1.0,
        team_average_ammo_fraction = 1.0,
    }

    local parent_hud = ring_hud_instance and ring_hud_instance._parent
    hud_state.player_extensions = parent_hud and parent_hud:player_extensions()
    if not hud_state.player_extensions or not hud_state.gameplay_t then
        -- Even if extensions are missing, still publish the current intensity flags
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

    local player = Managers.player:local_player_safe(1)
    local player_unit = player and player.player_unit
    if player_unit then
        local visual_loadout_extension = ScriptUnit.has_extension(player_unit, "visual_loadout_system") and
            ScriptUnit.extension(player_unit, "visual_loadout_system")
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

    -- Proximity flags for pocketables (player-side):
    -- Prefer proximity_context helpers if present; otherwise fall back to raw flags.
    do
        local near_stimm = false
        if type(mod.near_stimm_source) == "function" then
            near_stimm = mod.near_stimm_source(mod) and true or false
        else
            near_stimm =
                (mod.near_syringe_corruption_pocketable == true)
                or (mod.near_syringe_power_boost_pocketable == true)
                or (mod.near_syringe_speed_boost_pocketable == true)
                or (mod.near_syringe_ability_boost_pocketable == true)
                or (mod.near_health_station == true)
        end

        local near_crate = false
        if type(mod.near_crate_source) == "function" then
            near_crate = mod.near_crate_source(mod) and true or false
        else
            near_crate =
                (mod.near_medical_crate_pocketable == true)
                or (mod.near_medical_crate_deployable == true)
                or (mod.near_ammo_cache_pocketable == true)
                or (mod.near_ammo_cache_deployable == true)
                or (mod.near_tome_pocketable == true)
                or (mod.near_grimoire_pocketable == true)
        end

        hud_state.near_any_stimm_source = near_stimm
        hud_state.near_any_crate_source = near_crate
    end

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

    hud_state.is_peril_driven_by_warp = warp_level > overheat_level
    hud_state.peril_fraction          = hud_state.is_peril_driven_by_warp and warp_level or overheat_level
    hud_state.peril_data.value        = hud_state.peril_fraction
    hud_state.peril_data.source       = hud_state.is_peril_driven_by_warp and "warp" or overheat_source

    do
        hud_state.peril_data.other_overheat_fraction  = 0
        hud_state.peril_data.other_overheat_slot_name = nil

        if not hud_state.is_peril_driven_by_warp then
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
                    hud_state.peril_data.other_overheat_fraction  = math.clamp(other_heat, 0, 1)
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
        local special_tweak        = current_wep_template and current_wep_template.weapon_special_tweak_data
        if special_tweak and special_tweak.max_charges then
            local wielded_wep_comp = unit_data_comp_access_point:read_component(wielded_slot_charge)

            if special_tweak.charge_remove_time and not special_tweak.passive_charge_add_interval then
                hud_state.charge_system_type = "kill_count"
            elseif special_tweak.passive_charge_add_interval then
                hud_state.charge_system_type = "block_passive"
            end

            if (hud_state.charge_system_type == "kill_count" or hud_state.charge_system_type == "block_passive")
                and wielded_wep_comp and special_tweak.max_charges > 0 then
                hud_state.charge_fraction = (wielded_wep_comp.num_special_charges or 0) / special_tweak.max_charges
            end
        end

        if not hud_state.charge_system_type then
            local action_module_charge_comp_data = unit_data_comp_access_point:read_component("action_module_charge")
            if action_module_charge_comp_data and action_module_charge_comp_data.charge_level and action_module_charge_comp_data.charge_level > 0 then
                hud_state.charge_system_type = "action_module"
                hud_state.charge_fraction    = action_module_charge_comp_data.charge_level
            end
        end
    end
    hud_state.charge_fraction = math.clamp(hud_state.charge_fraction, 0, 1)

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
                hud_state.gameplay_t
            )

        local ned_raw                                    = dr_start_val
        hud_state.dodge_data.current_dodges              = cd_raw
        hud_state.dodge_data.max_efficient_dodges_actual = ned_raw

        if ned_raw >= math.huge then
            hud_state.dodge_data.has_infinite             = true
            hud_state.dodge_data.efficient_dodges_display = mod.MAX_DODGE_SEGMENTS
            hud_state.dodge_data.remaining_efficient      = math.huge
        else
            local num_eff_actual                          = math.ceil(ned_raw or 0)
            hud_state.dodge_data.efficient_dodges_display = math.min(num_eff_actual, mod.MAX_DODGE_SEGMENTS)
            hud_state.dodge_data.remaining_efficient      = math.max(0, num_eff_actual - cd_raw)
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
        hud_state.health_data.corruption_fraction = math.clamp(health_ext:permanent_damage_taken_percent() or 0, 0, 1)
        hud_state.health_data.current_health      = health_ext:current_health() or 0
        hud_state.health_data.max_health          = health_ext:max_health() or 0
    end

    -- Grenades
    do
        local player = Managers.player:local_player_safe(1)
        local player_unit2 = player and player.player_unit
        mod.grenades_update_state(unit_data_comp_access_point, ability_ext, player_unit2, hud_state.grenade_data)
    end

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

    -- Ammo: clip via helper, reserve via helper (secondary-only by design)
    do
        mod.ammo_clip_update_state(unit_data_comp_access_point, weapon_ext, inv_comp, hud_state.ammo_data)
        mod.ammo_reserve_update_state(unit_data_comp_access_point, hud_state.ammo_data)
    end

    -- ADS stamina drain for Deadshot
    hud_state.is_veteran_deadshot_adsing = false
    if player and unit_data_comp_access_point then
        local archetype = player:archetype_name()
        local player_profile = player:profile()
        if archetype == "veteran" and player_profile and player_profile.talents and player_profile.talents.veteran_ads_drain_stamina then
            local alternate_fire_comp = unit_data_comp_access_point:read_component("alternate_fire")
            if alternate_fire_comp and alternate_fire_comp.is_active then
                hud_state.is_veteran_deadshot_adsing = true
            end
        end
    end

    -- Buff timers + ability timer (STRICT allow-list)
    if player and player.player_unit then
        local archetype                   = player:archetype_name()
        local player_unit_timer           = player.player_unit

        local longest_buff_time_remaining = 0
        local longest_buff_duration       = 0

        if MONITORED_ARCHETYPES[archetype] then
            local buff_ext_timer = ScriptUnit.has_extension(player_unit_timer, "buff_system") and
                ScriptUnit.extension(player_unit_timer, "buff_system")
            if buff_ext_timer and buff_ext_timer._buffs_by_index then
                for _, buff_instance in pairs(buff_ext_timer._buffs_by_index) do
                    local tmpl = buff_instance and buff_instance:template()
                    local name = (tmpl and tmpl.name) or
                        (buff_instance and buff_instance.template_name and buff_instance:template_name())
                    if name and ALLOWED_BUFF_NAMES[name] then
                        local has_duration = buff_instance.duration ~= nil and type(buff_instance.duration) == "function"
                        local has_progress = buff_instance.duration_progress ~= nil and
                            type(buff_instance.duration_progress) == "function"
                        if has_duration and has_progress then
                            local duration = buff_instance:duration()
                            if duration and duration > 0 then
                                local progress = buff_instance:duration_progress() or 0
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
        end

        hud_state.timer_data.buff_timer_value  = longest_buff_time_remaining
        hud_state.timer_data.buff_max_duration = longest_buff_duration

        local unit_data_system                 = ScriptUnit.has_extension(player_unit_timer, "unit_data_system") and
            ScriptUnit.extension(player_unit_timer, "unit_data_system")
        local ability_comp                     = unit_data_system and unit_data_system:read_component("combat_ability")
        local gameplay_t                       = hud_state.gameplay_t
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

        -- boolean used by UI (solo timer; buff can temporarily mask it)
        hud_state.timer_data.is_ability_on_cooldown_for_timer =
            (hud_state.timer_data.ability_cooldown_remaining or 0) > 0

        -- If a tracked buff is active, hide the cooldown timer (feature layer may still show buff timer)
        if (hud_state.timer_data.buff_timer_value or 0) > 0 and (hud_state.timer_data.buff_max_duration or 0) > 0 then
            hud_state.timer_data.is_ability_on_cooldown_for_timer = false
            hud_state.timer_data.ability_cooldown_remaining = 0
        end
    end

    hud_state.is_music_high_intensity        = Intensity.high_intensity_active()
    hud_state.is_high_intensity_timer_active = Intensity.is_timer_active()

    return hud_state
end

return RingHudState
