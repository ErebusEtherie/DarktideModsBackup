return {
    run = function()
    fassert(rawget(_G, "new_mod"), "`Killfeed Details` encountered an error loading the Darktide Mod Framework.")

        new_mod("Killfeed Details", {
            mod_script       = "Killfeed Details/scripts/mods/Killfeed Details/Killfeed Details",
            mod_data         = "Killfeed Details/scripts/mods/Killfeed Details/Killfeed Details_data",
            mod_localization = "Killfeed Details/scripts/mods/Killfeed Details/Killfeed Details_localization",
        })
    end,
    packages = {},
}
