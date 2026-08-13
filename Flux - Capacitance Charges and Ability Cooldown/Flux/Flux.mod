-- File: Flux/Flux.mod
return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`Flux` encountered an error loading the Darktide Mod Framework.")

        new_mod("Flux", {
            mod_script       = "Flux/scripts/mods/Flux/Flux",
            mod_data         = "Flux/scripts/mods/Flux/Flux_data",
            mod_localization = "Flux/scripts/mods/Flux/Flux_localization",
        })
    end,
    packages = {},
	version = "7",
}
