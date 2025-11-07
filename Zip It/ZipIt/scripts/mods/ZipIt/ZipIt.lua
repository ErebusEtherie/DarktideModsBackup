
--[[
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│ Mod Name: Zip It!                                                                         │
│ Mod Description: Disables dialogue from various sources.                                  │
│ Mod Author: Seph (Steam: Concoction of Constitution)                                      │
└───────────────────────────────────────────────────────────────────────────────────────────┘
--]]
local mod = get_mod("ZipIt")
toggles = {

    hub_radio = { '.*hub.*idle.*conversation.*', '.*radio_static.*' },
    hub_vox = { ".*hub.*announcement.*", "pa_notification", ".*vox_static.*", ".*mourningstar_announcement.*", ".*hub_rumours.*" },
    hub_soldier = { ".*hub.*soldier.*", ".*soldier.*hub.*", ".*initiate.*greeting.*" },
    hub_conversation = { ".*hub.*rumors.*", "hub_idle_2nd_phase_conversation" },
    hub_hallowette = { ".*purser.*interact.*", ".*purser.*goodbye.*" },
    hub_siremelk = { ".*hub_interact_contract_vendor.*", ".*contract_vendor.*" },
    hub_commissary = { ".*reject_npc.*" },
    hub_krall = { "mindwipe", ".*barber_hello.*", ".*barber.*distance.*", "barber_goodbye.*" },
    hub_armoury = { ".*credit_store_servitor.*" },
    hub_hadron = { ".*hub_idle_crafting.*", ".*tech_priest.*" },
    hub_sefoni = { ".*training_ground_psyker.*hub_interact.*" },
    hub_hestia = { "boon_vendor_a"},

    mission_brief = { "mission_.*_brief.*", "mission_.*_briefing.*", "mission_brief.*" },
    mission_info = {
        ".*mission_train.*",
        ".*info.*",
        ".*survive_almost_done.*",
        ".*mission_armoury.*",
        ".*mission_station_first.*",
        ".*mission_station_station_approach.*",
        ".*mission_station_interrogation_bay.*",
        ".*mission_armoury_amphitheatre.*",
        ".*mission_cooling.*",
        ".*mission.*propaganda.*",
        ".*wandering_skull.*",
        ".*all_targets_scanned.*",
        ".*scan_more_data.*",
        ".*scan_find.*",
        ".*luggable_mission_pickup.*",
        ".*event_fortification.*",
        ".*mission_resurgence.*",
        ".*power_circumstance.*",
        ".*mission_rails.*",
        ".*mission_core.*",
    },
    mission_conversation = {
        ".*start_banter.*",
        ".*generic_mission.*",
        '.*npc_vo.*',
        ".*zone_tank_foundry.*",
        ".*zone_transit.*",
        ".*region_hubculum.*",
        ".*region_mechanicus.*",
        ".*zone_throneside.*",
        ".*zone_watertown.*",
        ".*story_talk.*",
        ".*environmental_story.*",
        ".*conversation.*",
        ".*bonding_conversation.*",
        ".*shipmistress_a__mission.*",
        ".*enginseer_a__mission.*",
        ".*combat_pause.*",
        ".*sergeant.*mission*",
        ".*event_demolition.*",
        ".*cult.*",
        ".*mission_archives.*",
        ".*all_players_required.*",
        ".*activate_from_hibernation.*",
    },
    mission_lore = {
        ".*lore_the_warp.*",
        ".*lore_zola.*",
        ".*region_carnival.*",
        ".*lore_melk_one.*",
        ".*lore_era_indomitus.*",
        ".*lore_valkyrie.*",
        ".*lore_daemons.*",
        ".*lore_rannrick.*",
        ".*lore_brahms.*",
        ".*lore_xenos_.*",
        ".*lore_hive_cities.*",
        ".*lore_training_psyker.*",
        ".*lore_inquisition.*",
        ".*lore_imperium.*",
        ".*lore_the_emperor.*",
        ".*lore_servitors.*",
        ".*lore_abhumans.*",
        ".*lore_ecclesiarchy.*",
        ".*lore_space_marines.*",
    },

    enemy_demonhost = { "loc_enemy.*daemonhost_.*" },
    enemy_flamer = { "loc_enemy.*flamer_.*start" },
    enemy_flamer_spawned = { "loc_enemy.*flamer_.*spawned", "loc_enemy.*flamer_.*taunt" },
    enemy_fire_grenadier = { "loc_enemy_grenadier_.*skulking", "loc_enemy_grenadier_.*throwing" },
    enemy_fire_grenadier_spawn = { "loc_enemy_grenadier_.*spawned" },
    enemy_gas_grenadier = { "loc_enemy.*cultist_grenadier_.*skulking", "loc_enemy.*cultist_grenadier_.*throwing" },
    enemy_gas_grenadier_spawn = { "loc_enemy.*cultist_grenadier_.*spawned" },
    enemy_gunner = { "loc_enemy.*gunner_.*" },
    enemy_berzerker = { "loc_enemy.*berzerker_.*" },
    enemy_netgunner = { "loc_enemy.*netgunner_.*assault","loc_enemy.*netgunner_.*net" },
    enemy_netgunner_spawn = { "loc_enemy.*netgunner_.*spawn" },
    enemy_infantry = { "loc_enemy.*infected_.*", "loc_enemy.*cultist_melee_.*", "loc_enemy.*trenchfighter.*" },
    enemy_mauler = { "loc_enemy.*traitor_enforcer_executor.*" },
    enemy_shooter = { "loc_enemy.*traitor_guard.*", "loc_enemy.*cultist_rusher.*" },
    enemy_shotgunner = { "loc_enemy.*shocktrooper.*" },
    enemy_bulwark = { "loc_enemy.*ogryn_bulwark" },
    enemy_crusher = { "loc_enemy.*ogryn_armoured" },
    enemy_reaper = { "loc_enemy.*ogryn_heavy" },

    player_death = { ".*player_death.*" },
    player_ability = { ".*ability.*" },
    player_blitz = { "blitz" },
    player_kill = { ".*enemy.*_kill.*", ".*seen_killstreak.*", ".*enemy_kill_scab_flamer.*", ".*enemy_kill_grenadier.*", ".*enemy_kill_netgunner.*", ".*kill_spree.*" },
    player_headshot = { ".*head_shot.*", },
    player_horde = { ".*heard_horde.*", ".*heard_enemy.*" },
    player_tag_item = { ".*tag_item.*", ".*smart_tag_vo_pickup_ammo.*", ".*smart_tag.*default.*", ".*smart_tag_vo_small_grenade.*", ".*smart_tag_vo_pickup.*", ".*smart_tag_vo_station_health.*" },
    player_tag_enemy = { '.*tag_enemy.*', ".*player_enemy_alert.*", ".*on_demand_vo_tag_enemy.*", ".*smart_tag_vo_enemy.*", ".*smart_tag.*threat.*", ".*smart_tag_vo_enemy_traitor_grenadier.*" },
    player_look = { ".*found_ammo.*_low_on_ammo.*", ".*stairs_sighted.*", ".*look_at.*", '.*seen_.*', '.*guidance.*' },
    player_throw = { ".*throwing_item.*", ".*throwing_grenade.*" },
    player_wheel = { ".*on_demand_com_wheel.*", ".*com_wheel_vo.*" },
    player_info = { 
        "almost_there", 
        "reload", 
        "collapse", 
        "plasma", 
        "player_tip", 
        "enemy_daemonhost", 
        "luggable",
        "zone_dust",
        "event_scan",
        "heal_start",
        "lore_rannick",
        "region_habculum",
    },

    team_advice = { ".*away_from.*", ".*come_back.*" },
    team_help = { ".*cover_me.*", ".*response_for.*cover_me.*", ".*ledge_hanging.*", ".*calling_for_help.*", ".*surrounded.*" },
    team_warning = { ".*warning_exploding_barrel.*", ".*critical_health.*", ".*response_for_.*critical_health.*" },
    team_hacking = { ".*response_to_hacking_fix_decode.*" },
    team_revive = { ".*response_for_.*revive.*", ".*start_revive.*" },
    team_downed = { ".*disabled_by_enemy.*", ".*need_rescue.*", ".*response_for.*disabled_by_chaos_hound.*", ".*disabled_by_chaos_hound.*", ".*knocked_down.*", ".*pinned_by_enemies.*", ".*response_for_pinned_by_enemies.*" },
    team_monster = { ".*enemy_near_death_monster.*", ".*monster_fight_start_reaction.*" },

    misc_medicae = { ".*medicae_servitor_.*", "health_booster" }

}

local isEnabled = function(event)
    if mod:get("disableAll") then return false end
    for key, patterns in pairs(toggles) do
        for index, value in ipairs(patterns) do
            if event ~= nil then
                if string.find(event, value) then
                    return mod:get(key)
                end
            end
        end
    end
    return 0
end

mod:hook("DialogueExtension", "play_event", function(f, s, event)
    -- mod:dtf(event, "dump", 6)
    local check = isEnabled(event.sound_event)
    if check == true then
        return f(s, event)
    elseif check == 0 then
        if mod:get("debug") then
            mod:echo("Unhandled dialog: Pls report <3")
            mod:echo(event.sound_event)
        end
        return f(s, event)
    end
end)

mod:hook("DialogueSystemSubtitle", "add_playing_localized_dialogue", function(f, s, speaker_name, dialogue)
    -- mod:dtf(event, "dump", 6)
    local check = isEnabled(dialogue.currently_playing_subtitle)
    if check == true or check == 0 or mod:get("subtitles") then
        --mod:echo("Subtitle Event!")
        --mod:echo(dialogue.currently_playing_subtitle)
        return f(s, speaker_name, dialogue)
    end
end)



-- Needed so that mission briefing doesn't cause indefinite load
mod:hook("LocalWaitForMissionBriefingDoneState", "update", function(f, s, dt)
    if not (isEnabled("mission_.*_brief.*") or isEnabled("mission_.*_briefing.*") or isEnabled("mission_brief.*")) then
        return "mission_briefing_done"
    else
        return f(s, dt)
    end
end)