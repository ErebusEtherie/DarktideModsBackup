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
        en = "Disable briefings for faster Valkyrie",
    },
    briefing_mute_mode_lobby_only = {
        en = "Disable Mission Start Briefings",
    },
    briefing_mute_mode_rejoin_only = {
        en = "Disable Mid Mission Briefings",
    },

    major_npc_briefings_name = {
        en = "Briefings",
    },
    major_npc_chatter_name = {
        en = "Chatter",
    },
}
