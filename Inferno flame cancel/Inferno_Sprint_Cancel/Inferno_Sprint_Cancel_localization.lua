return {
    mod_name = {
        en = "Inferno Sprint Cancel",
    },
    mod_description = {
        en = "Automatically injects a sprint press after each inferno staff primary fire, cancelling the recovery animation when moving and allowing faster follow-up shots.",
    },
    sprint_delay = {
        en = "Sprint Delay (s)",
    },
    sprint_delay_description = {
        en = "How long to wait after the shoot action ends before injecting the sprint press. Increase if the cancel is being ignored by the server.",
    },
    sprint_delay = {
        en = "Sprint Delay (s)",
    },
    sprint_delay_description = {
        en = "How long after the shoot animation starts before the sprint is injected. Increase if the cancel fires too early.",
    },
    sprint_duration = {
        en = "Sprint Hold Duration (s)",
    },
    sprint_duration_description = {
        en = "How long the injected sprint input is held. Longer is more reliable but commits you to sprint briefly before your next action.",
    },
    loop_end_delay = {
        en = "Loop End Delay (s)",
    },
    loop_end_delay_description = {
        en = "Pause between the end of one sprint cancel and the start of the next when M1 is held. Increase if cycles overlap or the game can't keep up.",
    },
    debug_enabled = {
        en = "Debug Mode",
    },
    debug_enabled_description = {
        en = "Prints state machine transitions and inject events to chat. Use this to diagnose timing issues — look for 'armed → sprinting' and 'inject sprint press' messages.",
    },
}