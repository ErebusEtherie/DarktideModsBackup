return {
    run = function()
        new_mod("mission_progress", {
            mod_script       = "mission_progress/scripts/mission_progress",
            mod_data         = "mission_progress/scripts/mission_progress_data",
            mod_localization = "mission_progress/scripts/mission_progress_localization"
        })
    end,
    packages = {},
}
