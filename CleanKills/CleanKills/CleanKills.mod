return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`CleanKills` encountered an error loading the Darktide Mod Framework.")

        new_mod("CleanKills", {
            mod_script = "CleanKills/scripts/mods/CleanKills/CleanKills",
            mod_data = "CleanKills/scripts/mods/CleanKills/CleanKills_data",
            mod_localization = "CleanKills/scripts/mods/CleanKills/CleanKills_localization",
        })
    end,
    packages = {},
}
