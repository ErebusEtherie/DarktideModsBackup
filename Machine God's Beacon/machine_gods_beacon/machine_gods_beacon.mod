return {
    run = function()
        fassert(rawget(_G, "new_mod"), "machine_gods_beacon must be loaded with Darktide Mod Framework")
        new_mod("machine_gods_beacon", {
            mod_script = "machine_gods_beacon/scripts/mods/machine_gods_beacon/machine_gods_beacon",
            mod_data = "machine_gods_beacon/scripts/mods/machine_gods_beacon/machine_gods_beacon_data",
            mod_localization = "machine_gods_beacon/scripts/mods/machine_gods_beacon/machine_gods_beacon_localization",
        })
    end,
    packages = {},
}
