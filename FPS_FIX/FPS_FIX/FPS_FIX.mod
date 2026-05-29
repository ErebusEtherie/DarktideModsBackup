return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`FPS_FIX` encountered an error loading the Darktide Mod Framework.")

        new_mod("FPS_FIX", {
            mod_script       = "FPS_FIX/scripts/mods/FPS_FIX/FPS_FIX",
            mod_data         = "FPS_FIX/scripts/mods/FPS_FIX/FPS_FIX_data",
            mod_localization = "FPS_FIX/scripts/mods/FPS_FIX/FPS_FIX_localization",
        })
    end,
    packages = {},
}
