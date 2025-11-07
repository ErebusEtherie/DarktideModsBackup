return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`ReviveSuccessSound` encountered an error loading the Darktide Mod Framework.")

        new_mod("ReviveSuccessSound", {
            mod_script       = "ReviveSuccessSound/scripts/mods/ReviveSuccessSound/ReviveSuccessSound",
            mod_data         = "ReviveSuccessSound/scripts/mods/ReviveSuccessSound/ReviveSuccessSound_data",
            mod_localization = "ReviveSuccessSound/scripts/mods/ReviveSuccessSound/ReviveSuccessSound_localization",
        })
    end,
    packages = {},
}
