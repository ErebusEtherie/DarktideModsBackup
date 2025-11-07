return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`BetterLoadouts` encountered an error loading the Darktide Mod Framework.")

        new_mod("BetterLoadouts", {
            mod_script       = "BetterLoadouts/scripts/mods/BetterLoadouts/BetterLoadouts",
            mod_data         = "BetterLoadouts/scripts/mods/BetterLoadouts/BetterLoadouts_data",
            mod_localization = "BetterLoadouts/scripts/mods/BetterLoadouts/BetterLoadouts_localization",
        })
    end,
    packages = {},
}