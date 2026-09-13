return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`enemy_outlines` encountered an error loading the Darktide Mod Framework.")

        new_mod("enemy_outlines", {
            mod_script       = "enemy_outlines/scripts/mods/enemy_outlines/enemy_outlines",
            mod_data         = "enemy_outlines/scripts/mods/enemy_outlines/enemy_outlines_data",
            mod_localization = "enemy_outlines/scripts/mods/enemy_outlines/enemy_outlines_localization",
        })
    end,
    packages = {}
}
