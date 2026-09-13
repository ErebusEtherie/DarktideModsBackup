return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`aggro_indicator` requires the Darktide Mod Framework.")

        new_mod("aggro_indicator", {
            mod_script       = "aggro_indicator/scripts/mods/aggro_indicator/aggro_indicator",
            mod_data         = "aggro_indicator/scripts/mods/aggro_indicator/aggro_indicator_data",
            mod_localization = "aggro_indicator/scripts/mods/aggro_indicator/aggro_indicator_localization",
        })
    end,
    packages = {
        "packages/ui/hud/crosshair/crosshair",
        "packages/ui/views/system_view/system_view"
    },
}
