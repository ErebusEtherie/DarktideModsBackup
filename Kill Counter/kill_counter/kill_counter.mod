return {
    run = function()
        fassert(rawget(_G, "new_mod"), "`kill_counter` encountered an error loading the Darktide Mod Framework.")

        new_mod("kill_counter", {
            mod_script       = "kill_counter/scripts/mods/kill_counter/kill_counter",
            mod_data         = "kill_counter/scripts/mods/kill_counter/kill_counter_data",
            mod_localization = "kill_counter/scripts/mods/kill_counter/kill_counter_localization",
        })
    end,
    packages = {},
}
