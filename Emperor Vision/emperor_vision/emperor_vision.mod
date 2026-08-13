return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`emperor_vision` mod requires the Darktide Mod Framework!")
        new_mod("emperor_vision", {
            mod_script       = [[emperor_vision/scripts/mods/emperor_vision/emperor_vision]],
            mod_data         = [[emperor_vision/scripts/mods/emperor_vision/emperor_vision_data]],
            mod_localization = [[emperor_vision/scripts/mods/emperor_vision/emperor_vision_localization]],
        })
    end,
    packages = {},
}
