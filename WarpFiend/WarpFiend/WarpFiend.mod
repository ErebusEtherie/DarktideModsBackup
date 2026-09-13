return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`WarpFiend` encountered an error loading the Darktide Mod Framework.")

        new_mod("WarpFiend", {
            mod_script       = "WarpFiend/scripts/mods/WarpFiend/WarpFiend",
            mod_data         = "WarpFiend/scripts/mods/WarpFiend/WarpFiend_data",
            mod_localization = "WarpFiend/scripts/mods/WarpFiend/WarpFiend_localization",
        })
    end,
    packages = {},
}