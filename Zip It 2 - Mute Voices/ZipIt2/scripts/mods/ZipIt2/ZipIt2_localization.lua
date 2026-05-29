-- File: ZipIt2/scripts/mods/ZipIt2/ZipIt2_localization.lua
local mod = get_mod("ZipIt2"); if not mod then return end

return {
    mod_name = {
        en = "Zip It 2",
    },
    mod_description = {
        en = "Mute selected voice profiles. Includes mission briefing skipping for faster mission loading.",
    },

    briefing_mute_mode_name = {
        en = " Disable Briefings for Faster Valkyrie",
    },
    briefing_mute_mode_lobby_only = {
        en = "Disable Mission Start Briefings",
    },
    briefing_mute_mode_rejoin_only = {
        en = "Disable Backfill Mission Briefings",
    },

    mute_bots_name = {
        en = "Mute Bots",
    },

    other_players_com_wheel_throttle_seconds = {
        en = " Com Wheel Cooldown",
    },
    selected_wheel_option_hotkey_name = {
        en = " Com Wheel Hotkey",
    },
    selected_wheel_option_name = {
        en = "     Com Wheel Option",
    },

    male = {
        en = "male"
    },
    female = {
        en = "female"
    },

    major_npc_briefings_name = {
        en = "Briefings",
    },
    major_npc_chatter_name = {
        en = "Chatter",
    },

    label_unknown_voice = {
        en = "Unknown Voice",
    },
}
