-- File: RingHud/scripts/mods/RingHud/RingHud_state.lua

local mod = get_mod("RingHud")
if not mod then return {} end

local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")
local PlayerUnitStatus         = require("scripts/utilities/attack/player_unit_status")
local Ammo                     = require("scripts/utilities/ammo")

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
-- ####################################################################################################

local function _calculate_dodge_diminishing_return(dodge_comp, move_comp, slide_comp, wep_dodge_template, buff_ext, t)
    if not (dodge_comp and move_comp and slide_comp and buff_ext and t) then return 0, 1, 0, 1 end
    local stat_buffs               = buff_ext:stat_buffs()
    local extra_consecutive_dodges = math.round(stat_buffs and stat_buffs.extra_consecutive_dodges or 0)

    local default_settings         = PlayerCharacterConstants and PlayerCharacterConstants.default_dodge_settings
    local default_dr_start         = (default_settings and default_settings.diminishing_return_start) or 2
    local default_dr_limit         = (default_settings and default_settings.diminishing_return_limit) or 1
    local default_dr_modifier      = (default_settings and default_settings.diminishing_return_distance_modifier) or 1

    local dr_start_base            = (wep_dodge_template and wep_dodge_template.diminishing_return_start) or
        default_dr_start
    local dr_limit_base            = (wep_dodge_template and wep_dodge_template.diminishing_return_limit) or
        default_dr_limit
    local dr_start                 = dr_start_base + extra_consecutive_dodges

    if dr_start >= math.huge then
        return dodge_comp.consecutive_dodges or 0, math.huge, 0, 1
    end

    local consecutive_dodges = math.min(dodge_comp.consecutive_dodges or 0, dr_start + dr_limit_base)
    local is_cooled_down     = (dodge_comp.consecutive_dodges_cooldown or 0) < t

    if is_cooled_down and not move_comp.is_dodging then
        consecutive_dodges = 0
    end

    if is_cooled_down and not (slide_comp.was_in_dodge_cooldown) and move_comp.method == "sliding" then
        consecutive_dodges = 0
    end

    local dodges_into_diminishing = math.max(0, consecutive_dodges - dr_start)
    local dr_dist_mod_base        = (wep_dodge_template and wep_dodge_template.diminishing_return_distance_modifier) or
        default_dr_modifier
    local diminishing_factor      = (dr_limit_base > 0) and math.clamp(dodges_into_diminishing / dr_limit_base, 0, 1) or
        0
    local base                    = 1 - dr_dist_mod_base
    local diminishing_return      = base + dr_dist_mod_base * (1 - diminishing_factor)

    return consecutive_dodges, dr_start, dr_limit_base, diminishing_return
end

-- Strict allow-list: only these 7 stance/stealth buffs should drive the timer.
local ALLOWED_BUFF_NAMES = {
    psyker_overcharge_stance_infinite_casting = true, -- Psyker stance
    veteran_combat_ability_stance_master      = true, -- Veteran stance
    veteran_invisibility                      = true, -- Veteran stealth
    zealot_invisibility                       = true, -- Zealot stealth (base)
    zealot_invisibility_increased_duration    = true, -- Zealot stealth (long)
    ogryn_ranged_stance                       = true, -- Ogryn stance
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

        timer_data = { buff_timer_value = 0, buff_max_duration = 0, ability_cooldown_remaining = 0, is_ability_on_cooldown_for_timer = 0 > 0, max_combat_ability_cooldown = 0 },

        peril_data = { value = 0, source = "warp" },

        ability_data = { remaining_charges = 0, max_charges = 0, remaining_cooldown = 0, max_cooldown = 0, paused = false },

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
        return hud_state
    end
    if not (weapon_ext and buff_ext and health_ext and toughness_ext and ability_ext and inv_comp) then
        return hud_state
    end

    local player = Managers.player:local_player_safe(1)
    local player_unit = player and player.player_unit
    if player_unit then
        local music_param_ext = ScriptUnit.has_extension(player_unit, "music_parameter_system") and
            ScriptUnit.extension(player_unit, "music_parameter_system")

        local game_mode_manager = Managers.state.game_mode
        local gamemode_name = game_mode_manager and game_mode_manager:game_mode_name() or "unknown"

        if gamemode_name == "coop_complete_objective" then
            if music_param_ext then
                if music_param_ext:vector_horde_near()
                    or music_param_ext:ambush_horde_near()
                    or music_param_ext:last_man_standing()
                    or music_param_ext:boss_near() then
                    hud_state.is_music_high_intensity = true
                end
            end

            local is_objective_high_intensity = false
            local mission_objective_system = Managers.state.extension:system("mission_objective_system")
            if mission_objective_system then
                local active_objectives = mission_objective_system:active_objectives()
                if type(active_objectives) == "table" then
                    -- NEW: iterate keys (objective objects) and guard access
                    for objective, _ in pairs(active_objectives) do
                        if type(objective) == "table" then
                            local event_type =
                                (type(objective.event_type) == "function" and objective:event_type()) or
                                rawget(objective, "event_type")
                            local objective_type =
                                (type(objective.objective_type) == "function" and objective:objective_type()) or
                                rawget(objective, "objective_type")

                            if event_type == "mid_event" or event_type == "end_event" or objective_type == "kill" then
                                is_objective_high_intensity = true
                                break
                            end
                        end
                    end
                end
            end

            local is_last_player_standing = false
            local players = Managers.player:players()
            if players then
                local alive_player_count = 0
                for _, player_in_session in pairs(players) do
                    local player_unit_in_session = player_in_session.player_unit
                    if player_unit_in_session and Unit.alive(player_unit_in_session) then
                        local unit_data_ext = ScriptUnit.extension(player_unit_in_session, "unit_data_system")
                        local health_ext2   = ScriptUnit.extension(player_unit_in_session, "health_system")
                        if unit_data_ext and health_ext2 and not PlayerUnitStatus.is_dead(unit_data_ext:read_component("character_state"), health_ext2) then
                            alive_player_count = alive_player_count + 1
                        end
                    end
                end
                if alive_player_count == 1 then
                    is_last_player_standing = true
                end
            end

            hud_state.is_high_intensity_timer_active =
                (ring_hud_instance and ring_hud_instance._is_music_intense_latched)
                or is_objective_high_intensity
                or is_last_player_standing
        end

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

    hud_state.near_any_stimm_source        = mod.near_syringe_corruption_pocketable or
        mod.near_syringe_power_boost_pocketable or
        mod.near_syringe_speed_boost_pocketable or mod.near_syringe_ability_boost_pocketable
    hud_state.near_any_crate_source        = mod.near_medical_crate_pocketable or mod.near_ammo_cache_pocketable or
        mod.near_tome_pocketable or mod.near_grimoire_pocketable

    hud_state.team_average_health_fraction = mod.team_average_health_fraction
    hud_state.team_average_ammo_fraction   = mod.team_average_ammo_fraction

    if ring_hud_instance then
        hud_state.pocketable_pickup_timer        = ring_hud_instance._pocketable_pickup_visibility_timer or 0
        hud_state.last_picked_up_pocketable_name = ring_hud_instance._last_picked_up_pocketable_name
    end

    -- Peril (warp vs overheat)
    local warp_charge_comp = unit_data_comp_access_point:read_component("warp_charge")
    local warp_level       = warp_charge_comp and warp_charge_comp.current_percentage or 0
    local overheat_level   = 0

    local wep_template     = weapon_ext:weapon_template()
    if wep_template and wep_template.uses_overheat then
        local wielded_slot      = inv_comp.wielded_slot
        local slot_config_entry = PlayerCharacterConstants.slot_configuration and
            PlayerCharacterConstants.slot_configuration[wielded_slot]
        if wielded_slot and wielded_slot ~= "none" and slot_config_entry and slot_config_entry.slot_type == "weapon" then
            local wielded_comp_data = unit_data_comp_access_point:read_component(wielded_slot)
            overheat_level = wielded_comp_data and wielded_comp_data.overheat_current_percentage or 0
        end
    else
        for i = 1, num_wep_slots_cache do
            local slot_id = wep_slots_cache[i]
            if slot_id then
                local slot_comp_data = unit_data_comp_access_point:read_component(slot_id)
                overheat_level = math.max(overheat_level,
                    slot_comp_data and slot_comp_data.overheat_current_percentage or 0)
            end
        end
    end

    hud_state.is_peril_driven_by_warp = warp_level > overheat_level
    hud_state.peril_fraction          = hud_state.is_peril_driven_by_warp and warp_level or overheat_level
    hud_state.peril_data.value        = hud_state.peril_fraction
    hud_state.peril_data.source       = hud_state.is_peril_driven_by_warp and "warp" or "overheat"

    -- Stamina
    local stamina_comp_data           = unit_data_comp_access_point:read_component("stamina")
    hud_state.stamina_fraction        = stamina_comp_data and stamina_comp_data.current_fraction or 0

    -- Charge mechanics
    local wielded_slot_charge         = inv_comp.wielded_slot
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
            _calculate_dodge_diminishing_return(dodge_state_comp, move_state_comp, slide_state_comp, wep_dodge_template,
                buff_ext, hud_state.gameplay_t)

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

    -- Grenades: robust, latched max that never decreases mid-mission
    do
        local ability_key  = "grenade_ability"
        local base_max     = 0
        local observed_cur = 0

        if ability_ext and ability_ext:ability_is_equipped(ability_key) then
            local remaining                        = ability_ext:remaining_ability_charges(ability_key) or 0
            local max_c                            = ability_ext:max_ability_charges(ability_key) or 0
            observed_cur                           = math.max(observed_cur, remaining)
            base_max                               = math.max(base_max, max_c)

            hud_state.grenade_data.current         = remaining
            hud_state.grenade_data.current_charges = remaining
            -- Keep 'max' as the game's reported value; UI should prefer live_max.
            hud_state.grenade_data.max             = max_c
            hud_state.grenade_data.max_charges     = max_c
        end

        -- Component sometimes reflects current charges more reliably than ability_ext.
        local grenade_comp = unit_data_comp_access_point and
            unit_data_comp_access_point:read_component("grenade_ability")
        if grenade_comp then
            local comp_cur = grenade_comp.num_charges or 0
            observed_cur   = math.max(observed_cur, comp_cur)

            -- Backfill if ability_ext path didn't run
            if (hud_state.grenade_data.current or 0) < comp_cur then
                hud_state.grenade_data.current         = comp_cur
                hud_state.grenade_data.current_charges = comp_cur
            end

            if (hud_state.grenade_data.max or 0) == 0 then
                hud_state.grenade_data.max         = base_max
                hud_state.grenade_data.max_charges = base_max
            end
        end

        -- Latch: never reduce within a mission; only clear on game-mode change in RingHud.lua.
        local latched = mod._grenade_max_override or 0
        local candidate = math.max(base_max, observed_cur)
        if candidate > latched then
            mod._grenade_max_override = candidate
            latched = candidate
        end

        -- Publish the effective max for consumers (UI & logic should use this).
        hud_state.grenade_data.live_max = math.max(base_max, latched, observed_cur)
    end

    -- Grenade regen progress (use live_max, not base)
    do
        local key             = "grenade_ability"

        local cur             = hud_state.grenade_data.current or 0
        local live_max        = hud_state.grenade_data.live_max or 0

        local used_any_source = false

        -- (1) Ability-cooldown path
        if ability_ext and ability_ext:ability_is_equipped(key) then
            local rem_cd = ability_ext:remaining_ability_cooldown(key) or 0
            local max_cd = ability_ext:max_ability_cooldown(key) or 0
            local paused = ability_ext.is_cooldown_paused and ability_ext:is_cooldown_paused(key)

            if max_cd > 0 and rem_cd > 0 and cur < live_max and not paused then
                hud_state.grenade_data.is_regenerating = true
                hud_state.grenade_data.max_cooldown    = max_cd
                hud_state.grenade_data.regen_progress  = math.clamp(1 - (rem_cd / max_cd), 0, 1)
                used_any_source                        = true
            end
        end

        -- (2) Buff-driven path
        if (not used_any_source) and player_unit then
            local buff_ext_local = ScriptUnit.has_extension(player_unit, "buff_system") and
                ScriptUnit.extension(player_unit, "buff_system")
            local buffs = buff_ext_local and buff_ext_local._buffs_by_index
            if buffs then
                local names = {
                    veteran_grenade_replenishment      = true,
                    adamant_grenade_replenishment      = true,
                    adamant_whistle_replenishment      = true,
                    adamant_whistle_replenisment       = true,
                    ogryn_friend_grenade_replenishment = true,
                    psyker_knife_replenishment         = true,
                }
                for _, b in pairs(buffs) do
                    local tmpl = b and b:template()
                    local name = (tmpl and tmpl.name) or (b and b.template_name and b:template_name())
                    if name and names[name] then
                        local has_duration_method = b.duration ~= nil and type(b.duration) == "function"
                        local has_progress_method = b.duration_progress ~= nil and
                            type(b.duration_progress) == "function"
                        local dur                 = has_duration_method and b:duration() or nil
                        local prog                = has_progress_method and b:duration_progress() or nil
                        if cur < live_max and prog and prog > 0 then
                            local fill
                            if name == "veteran_grenade_replenishment" or name == "adamant_grenade_replenishment" then
                                fill = math.clamp(prog, 0, 1)     -- already 0→1 elapsed
                            else
                                fill = math.clamp(1 - prog, 0, 1) -- invert remaining 1→0
                            end

                            hud_state.grenade_data.is_regenerating     = true
                            hud_state.grenade_data.replenish_buff_name = name
                            if dur and dur > 0 then hud_state.grenade_data.max_cooldown = dur end
                            hud_state.grenade_data.regen_progress = fill
                            used_any_source = true
                            break
                        end
                    end
                end
            end
        end

        if not used_any_source then
            hud_state.grenade_data.is_regenerating = false
            hud_state.grenade_data.regen_progress  = 0
        end
    end

    -- Ability info (for stimm logic, etc.)
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

    -- Ammo: secondary-only by design (multi-clip aware)
    hud_state.ammo_data.wielded_slot_name = inv_comp.wielded_slot
    do
        local secondary_comp               = unit_data_comp_access_point:read_component("slot_secondary")
        local weapon_uses_ammo             = false
        local current_clip, max_clip       = 0, 0
        local current_reserve, max_reserve = 0, 0
        local has_infinite_reserve         = false

        -- Reserve is always taken from slot_secondary (if finite)
        if secondary_comp then
            current_reserve      = secondary_comp.current_ammunition_reserve or 0
            max_reserve          = secondary_comp.max_ammunition_reserve or 0
            has_infinite_reserve = (max_reserve == 0)
        end

        -- Clip info only when the wielded slot IS the secondary and that template uses ammo
        if hud_state.ammo_data.wielded_slot_name == "slot_secondary" then
            local wielded_template = weapon_ext and weapon_ext:weapon_template()
            if wielded_template
                and wielded_template.hud_configuration
                and wielded_template.hud_configuration.uses_ammunition
            then
                weapon_uses_ammo = true

                if secondary_comp then
                    -- New 1.10 multi-clip ammo layout: aggregate all clips in use
                    local max_num_clips = (NetworkConstants
                        and NetworkConstants.ammunition_clip_array
                        and NetworkConstants.ammunition_clip_array.max_size) or 0

                    for i = 1, max_num_clips do
                        if Ammo.clip_in_use(secondary_comp, i) then
                            max_clip     = max_clip + (secondary_comp.max_ammunition_clip[i] or 0)
                            current_clip = current_clip + (secondary_comp.current_ammunition_clip[i] or 0)
                        end
                    end
                end
            end
        end

        hud_state.ammo_data.uses_ammo            = weapon_uses_ammo
        hud_state.ammo_data.current_clip         = current_clip
        hud_state.ammo_data.max_clip             = max_clip
        hud_state.ammo_data.current_reserve      = current_reserve
        hud_state.ammo_data.max_reserve          = max_reserve
        hud_state.ammo_data.has_infinite_reserve = has_infinite_reserve
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
                                -- For these tracked buffs we treat progress as remaining (≈1→0).
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
        local ability_state_comp_timer         = unit_data_system and unit_data_system:read_component("combat_ability")
        local gameplay_time_for_cd             = hud_state.gameplay_t
        local ability_cooldown_time            = ability_state_comp_timer and ability_state_comp_timer.cooldown
        if gameplay_time_for_cd and ability_cooldown_time and ability_cooldown_time > gameplay_time_for_cd then
            hud_state.timer_data.ability_cooldown_remaining = ability_cooldown_time - gameplay_time_for_cd
        else
            hud_state.timer_data.ability_cooldown_remaining = 0
        end

        local combat_ability_ext = hud_state.player_extensions.ability
        if combat_ability_ext then
            hud_state.timer_data.max_combat_ability_cooldown =
                combat_ability_ext:max_ability_cooldown("combat_ability") or 0
        end

        -- boolean used by UI
        hud_state.timer_data.is_ability_on_cooldown_for_timer =
            (hud_state.timer_data.ability_cooldown_remaining or 0) > 0

        -- If a tracked buff is active, override cooldown timer
        if (hud_state.timer_data.buff_timer_value or 0) > 0 and (hud_state.timer_data.buff_max_duration or 0) > 0 then
            hud_state.timer_data.is_ability_on_cooldown_for_timer = false
            hud_state.timer_data.ability_cooldown_remaining = 0
        end
    end

    return hud_state
end

return RingHudState
