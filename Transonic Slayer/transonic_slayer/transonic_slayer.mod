return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`transonic_slayer` mod must be lower than Vermintide Mod Framework in your launcher's load order.")
        new_mod("transonic_slayer", {
            mod_script       = "transonic_slayer/scripts/mods/transonic_slayer/transonic_slayer",
            mod_data         = "transonic_slayer/scripts/mods/transonic_slayer/transonic_slayer_data",
            mod_localization = "transonic_slayer/scripts/mods/transonic_slayer/transonic_slayer_localization",
        })
    end,
    packages = {},
}