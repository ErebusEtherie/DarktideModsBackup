return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`WarpGod` encountered an error loading the Darktide Mod Framework.")

        new_mod("WarpGod", {
            mod_script       = "WarpGod/scripts/mods/WarpGod/WarpGod",
            mod_data         = "WarpGod/scripts/mods/WarpGod/WarpGod_data",
            mod_localization = "WarpGod/scripts/mods/WarpGod/WarpGod_localization",
        })
    end,
    packages = {},
}
