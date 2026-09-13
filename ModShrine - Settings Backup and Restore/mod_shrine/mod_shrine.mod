return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`ModShrine` encountered an error loading the Darktide Mod Framework.")

        new_mod("mod_shrine", {
            mod_script       = "mod_shrine/scripts/mods/mod_shrine/mod_shrine",
            mod_data         = "mod_shrine/scripts/mods/mod_shrine/mod_shrine_data",
            mod_localization = "mod_shrine/scripts/mods/mod_shrine/mod_shrine_localization",
        })
    end,
    packages = {},
}
