return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`ServoSkullTransparency` encountered an error loading the Darktide Mod Framework.")
        new_mod("ServoSkullTransparency", {
            mod_script       = "ServoSkullTransparency/scripts/mods/ServoSkullTransparency/ServoSkullTransparency",
            mod_data         = "ServoSkullTransparency/scripts/mods/ServoSkullTransparency/ServoSkullTransparency_data",
            mod_localization = "ServoSkullTransparency/scripts/mods/ServoSkullTransparency/ServoSkullTransparency_localization",
        })
    end,
    packages = {},
}
