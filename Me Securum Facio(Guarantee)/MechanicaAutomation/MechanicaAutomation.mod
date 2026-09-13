return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`MechanicaAutomation` could not find the Darktide Mod Framework.")

        new_mod("MechanicaAutomation", {
            mod_script       = "MechanicaAutomation/scripts/mods/MechanicaAutomation/MechanicaAutomation",
            mod_data         = "MechanicaAutomation/scripts/mods/MechanicaAutomation/MechanicaAutomation_data",
            mod_localization = "MechanicaAutomation/scripts/mods/MechanicaAutomation/MechanicaAutomation_localization",
        })
    end,
    packages = {},
}
