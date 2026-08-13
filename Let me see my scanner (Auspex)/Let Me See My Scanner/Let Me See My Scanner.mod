return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`Let Me See My Scanner` requires the Darktide Mod Framework.")

        new_mod("Let Me See My Scanner", {
            mod_script       = "Let Me See My Scanner/scripts/mods/Let Me See My Scanner/Let Me See My Scanner",
            mod_data         = "Let Me See My Scanner/scripts/mods/Let Me See My Scanner/Let Me See My Scanner_data",
            mod_localization = "Let Me See My Scanner/scripts/mods/Let Me See My Scanner/Let Me See My Scanner_localization",
        })
    end,
    packages = {},
}
