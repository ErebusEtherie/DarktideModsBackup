return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`ZipIt2` encountered an error loading the Darktide Mod Framework.")

        new_mod("ZipIt2", {
            mod_script       = "ZipIt2/scripts/mods/ZipIt2/ZipIt2",
            mod_data         = "ZipIt2/scripts/mods/ZipIt2/ZipIt2_data",
            mod_localization = "ZipIt2/scripts/mods/ZipIt2/ZipIt2_localization",
        })
    end,
    packages = {},
}
