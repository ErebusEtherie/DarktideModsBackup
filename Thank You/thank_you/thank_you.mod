return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`thank_you` requires the Darktide Mod Framework.")

        new_mod("thank_you", {
            mod_script       = "thank_you/scripts/mods/thank_you/thank_you",
            mod_data         = "thank_you/scripts/mods/thank_you/thank_you_data",
            mod_localization = "thank_you/scripts/mods/thank_you/thank_you_localization",
        })
    end,
    packages = {},
}
