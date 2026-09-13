return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`WarpHorror` encountered an error loading the Darktide Mod Framework.")

        new_mod("WarpHorror", {
            mod_script       = "WarpHorror/scripts/mods/WarpHorror/WarpHorror",
            mod_data         = "WarpHorror/scripts/mods/WarpHorror/WarpHorror_data",
            mod_localization = "WarpHorror/scripts/mods/WarpHorror/WarpHorror_localization",
        })
    end,
    packages = {},
}