return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`better_downed_indicators` requires the Darktide Mod Framework.")

        new_mod("better_downed_indicators", {
            mod_script       = "better_downed_indicators/scripts/mods/better_downed_indicators/better_downed_indicators",
            mod_data         = "better_downed_indicators/scripts/mods/better_downed_indicators/better_downed_indicators_data",
            mod_localization = "better_downed_indicators/scripts/mods/better_downed_indicators/better_downed_indicators_localization",
        })
    end,
    packages = {},
}

