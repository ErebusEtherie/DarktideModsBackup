local loc = {}

loc.mod_name = {
    en = "Thank You",
}
loc.mod_description = {
    en = "Automatically speaks a communication wheel line when something worth reacting to happens - thanks when a teammate cuts you out of a net, pulls you off a ledge or picks you up, my pleasure when you return the favour, a call for help when you go down. Uses your character's real wheel voice lines, so the rest of the strike team hears them exactly as if you had used the wheel yourself.",
}

-- Global settings

loc.delay = {
    en = "Response Delay",
}
loc.delay_tooltip = {
    en = "Extra pause before a callout is spoken, in seconds.\n\nSome delay is worth keeping. Speaking the instant you stand up talks over the grunt your character already makes getting to their feet.",
}
loc.cooldown = {
    en = "Callout Repeat Cooldown",
}
loc.cooldown_tooltip = {
    en = "Shortest gap before the same callout can repeat, in seconds. This is what stops a bad Trapper wave from turning you into a stuck vox bead.\n\nDifferent callouts do not block each other - being freed seconds after calling for help still gets its thank-you. Two callouts landing together are spaced about two seconds apart so they don't talk over each other.",
}
loc.send_chat = {
    en = "Also Send Chat Message",
}
loc.send_chat_tooltip = {
    en = "Post the matching text to mission chat as well, the way the wheel does.\n\nOnly Thanks, Need Health and Need Ammo have chat text in the base game; the other lines stay voice-only. Off by default - automatic chat is a lot more intrusive than automatic voice.",
}
loc.debug_echo = {
    en = "Log Callouts To Chat",
}
loc.debug_echo_tooltip = {
    en = "Print every automatic callout to your own chat feed as it fires, and every communication wheel line you hear a teammate use. Only you see it.\n\nUseful for confirming a trigger works without having to listen for it, and for checking what the game actually calls a wheel line.",
}
loc.file_log = {
    en = "Log Movement Changes Too",
}
loc.file_log_tooltip = {
    en = "The mod always writes a log of what it did - hooks bound, every callout queued, fired, spoken, skipped or dropped, and why - to:\n\n%%APPDATA%%\\Fatshark\\Darktide\\thank_you_log.txt\n\nFresh file each session. This setting only adds the noisy part: every walk/sprint/dodge/slide transition. Turn it off for a shorter log - the callout decisions are recorded either way."
}

loc.test_group = {
    en = "Test",
}
loc.test_line = {
    en = "Test Line",
}
loc.test_line_tooltip = {
    en = "Which line the test key speaks.",
}
loc.test_key = {
    en = "Test Key",
}
loc.test_key_tooltip = {
    en = "Speaks the test line immediately, ignoring delay and cooldown. Works in the Mourningstar too, so you can check a voice line without loading a mission.",
}
loc.report_key = {
    en = "Diagnostics Key",
}
loc.report_key_tooltip = {
    en = "Prints to your own chat feed whether each engine hook bound successfully, and what character state you are currently in.\n\nIf a trigger is not firing, press this first: it distinguishes a hook that never attached from a trigger that is attached but never reached.",
}

-- Line choices

loc.line_off = {
    en = "Say Nothing",
}
loc.line_thank_you = {
    en = "Thanks",
}
loc.line_thank_you_delayed = {
    en = "Thanks (Delayed)",
}
loc.line_my_pleasure = {
    en = "My Pleasure",
}
loc.line_for_the_emperor = {
    en = "For the Emperor!",
}
loc.line_yes = {
    en = "Yes",
}
loc.line_no = {
    en = "No",
}
loc.line_need_health = {
    en = "Need Health",
}
loc.line_need_ammo = {
    en = "Need Ammo",
}
loc.line_need_that = {
    en = "I Need That",
}
loc.line_take_this = {
    en = "Take This",
}
loc.line_following = {
    en = "Following You",
}
loc.line_over_here = {
    en = "Over Here",
}
loc.line_this_way = {
    en = "Let's Go This Way",
}
loc.line_enemy_there = {
    en = "Enemy Over There",
}

-- Triggers

loc.revived_group = {
    en = "When You Are Revived",
}
loc.revived_enabled = {
    en = "Call Out",
}
loc.revived_enabled_tooltip = {
    en = "Fires when a teammate finishes picking you up from knocked down.",
}
loc.revived_line = {
    en = "Line",
}

loc.rescued_group = {
    en = "When You Are Freed From A Disabler",
}
loc.rescued_enabled = {
    en = "Call Out",
}
loc.rescued_enabled_tooltip = {
    en = "Fires when you get out of a Trapper net, a Hound pounce, a Mutant grab, a Beast of Nurgle, a Sniper's warp grab, or a hogtie - whether a teammate cut you loose or killed the thing holding you.",
}
loc.rescued_line = {
    en = "Line",
}

loc.ledge_saved_group = {
    en = "When You Are Pulled Off A Ledge",
}
loc.ledge_saved_enabled = {
    en = "Call Out",
}
loc.ledge_saved_enabled_tooltip = {
    en = "Fires only on an actual pull-up. Losing your grip and falling does not count.",
}
loc.ledge_saved_line = {
    en = "Line",
}

loc.assisted_ally_group = {
    en = "When You Revive Or Free An Ally",
}
loc.assisted_ally_enabled = {
    en = "Call Out",
}
loc.assisted_ally_enabled_tooltip = {
    en = "Fires when you finish reviving, pulling up, rescuing or un-netting a teammate. Only on success - cancelling partway through says nothing.\n\nThis speaks whether or not they thank you. If you would rather only answer when someone actually thanks you, leave this off and use When Someone Thanks You instead. Running both mostly gets you the first one, since the shared cooldown swallows the reply.",
}
loc.assisted_ally_line = {
    en = "Line",
}

loc.thanked_group = {
    en = "When Someone Thanks You",
}
loc.thanked_enabled = {
    en = "Call Out",
}
loc.thanked_enabled_tooltip = {
    en = "Fires when a teammate uses the Thanks line on the communication wheel.\n\nThe reply is staggered by a random fraction of a second, so a squad all running this mod answers raggedly instead of in perfect chorus.",
}
loc.thanked_line = {
    en = "Line",
}
loc.thanked_scope = {
    en = "Answer",
}
loc.thanked_scope_tooltip = {
    en = "Whose thanks you respond to.\n\nOnly When You Helped Them is the sane default: you answer the person you just revived, pulled up, un-netted or rescued, within twenty seconds, once per rescue. Anyone answers every thanks in the squad - which means four players with this mod all reply to the same one.",
}
loc.thanked_scope_helped = {
    en = "Only When You Helped Them",
}
loc.thanked_scope_anyone = {
    en = "Anyone",
}

loc.went_down_group = {
    en = "When You Go Down",
}
loc.went_down_enabled = {
    en = "Call Out",
}
loc.went_down_enabled_tooltip = {
    en = "Fires the moment you are knocked down.\n\nAvoid setting this to Over Here: the game gives that line and Thanks the same five-second cooldown, so calling Over Here when you go down silently eats the thank-you when someone picks you up. Need Health is the default for exactly that reason.\n\nYour character also has some automatic distress lines here in the base game, so this can double up. Turn it off if it sounds busy.",
}
loc.went_down_line = {
    en = "Line",
}

loc.disabled_group = {
    en = "When You Are Disabled",
}
loc.disabled_enabled = {
    en = "Call Out",
}
loc.disabled_enabled_tooltip = {
    en = "Fires the moment a special takes you - netted, pounced, grabbed, swallowed, warp grabbed - or when you end up hanging from a ledge.\n\nAvoid setting this to Over Here: the game gives that line and Thanks the same five-second cooldown, so it silently eats the thank-you for the rescue seconds later. Enemy Over There is the default because it has its own cooldown and fits a special being on top of you.\n\nAs above, the base game already has some distress VO for this.",
}
loc.disabled_line = {
    en = "Line",
}

loc.low_health_group = {
    en = "When Your Health Drops Low",
}
loc.low_health_enabled = {
    en = "Call Out",
}
loc.low_health_enabled_tooltip = {
    en = "Fires once when your health crosses the threshold below. It re-arms only after you heal back clear of it, so sitting on the line does not make you repeat yourself.",
}
loc.low_health_line = {
    en = "Line",
}
loc.low_health_threshold = {
    en = "Health Threshold (%%)",
}
loc.low_health_threshold_tooltip = {
    en = "Health percentage that counts as low.",
}

loc.out_of_ammo_group = {
    en = "When You Run Out Of Ammo",
}
loc.out_of_ammo_enabled = {
    en = "Call Out",
}
loc.out_of_ammo_enabled_tooltip = {
    en = "Fires when you try to reload with an empty reserve.",
}
loc.out_of_ammo_line = {
    en = "Line",
}

return loc
