return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`simplecolorselector` requires the Darktide Mod Framework.")

        new_mod("simplecolorselector", {
            mod_script       = "simplecolorselector/scripts/mods/simplecolorselector/simplecolorselector",
            mod_data         = "simplecolorselector/scripts/mods/simplecolorselector/simplecolorselector_data",
            mod_localization = "simplecolorselector/scripts/mods/simplecolorselector/simplecolorselector_localization",
        })
    end,
    packages = {},
}
