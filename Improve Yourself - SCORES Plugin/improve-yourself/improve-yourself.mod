return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`Improve Yourself` encountered an error loading the Darktide Mod Framework.")

        new_mod("improve-yourself", {
            mod_script       = "improve-yourself/scripts/mods/improve-yourself/improve_yourself",
            mod_data         = "improve-yourself/scripts/mods/improve-yourself/improve_yourself_data",
            mod_localization = "improve-yourself/scripts/mods/improve-yourself/improve_yourself_localization",
        })
    end,
    packages = {},
}
