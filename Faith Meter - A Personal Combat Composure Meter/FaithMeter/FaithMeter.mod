return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`FaithMeter` encountered an error loading the Darktide Mod Framework.")

        new_mod("FaithMeter", {
            mod_script = "FaithMeter/scripts/mods/FaithMeter/FaithMeter",
            mod_data = "FaithMeter/scripts/mods/FaithMeter/FaithMeter_data",
            mod_localization = "FaithMeter/scripts/mods/FaithMeter/FaithMeter_localization",
        })
    end,
    packages = {},
}
