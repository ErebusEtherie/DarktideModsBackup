return {
	mod_name = {
		en = "Havoc Quickplay",
	},
	mod_description = {
		en = "",
	},

	hq_auto_accept = {
		en = "Auto-Accept Join Requests",
	},
	hq_auto_accept_mission = {
		en = "Auto-Accept Havoc Mission",
	},
	hq_auto_accept_mission_desc = {
		en = "Accepts when the lobby host puts up a havoc mission.",
	},
	hq_auto_accept_desc = {
		en = "Auto-Accepts based on your minimum/maximum havoc rank setting. Reads their TRUE havoc assignment rank, not their clearance one.",
	},
	hq_auto_decline = {
		en = "Auto-Decline Join Requests",
	},
	hq_auto_decline_desc = {
		en = "Auto-Declines based on your minimum/maximum havoc rank setting. Reads their TRUE havoc assignment rank, not their clearance one.",
	},
	hq_auto_start = {
		en = "Auto-Start on Full Lobby",
	},
	hq_auto_start_desc = {
		en = "Automatically puts up your current havoc mission when your lobby reaches 4 players. Will stop if someone declines.",
	},
	hq_join_keybind = {
		en = "Instant Join Keybind",
	},
	hq_cancel_keybind = {
		en = "Cancel Queue Keybind",
	},
	hq_countdown = {
		en = "Join Countdown (seconds)",
	},
	hq_countdown_desc = {
		en = "How many seconds you'll wait before the mod joins a havoc lobby that you got accepted to. "
			.. "NOTE: I recommend keeping this at default, as the mod works by prioritizing the lobby with "
			.. "the most players in it. Reducing this would give other lobbies less time to accept you, "
			.. "potentially making your wait times longer.",
	},
	hq_disable_bl_button = {
		en = "Disable Blacklist Button",
	},
	hq_disable_bl_button_desc = {
		en = "Disables the blacklist button in case it's incompatible with another mod of yours. You can use /hqp_bl instead",
	},
	hq_blacklist_minutes = {
		en = "Blacklist Duration (minutes)",
	},
	hq_rank_group = {
		en = "Havoc Rank Filter",
	},
	hq_min_rank = {
		en = "Minimum Assignment / Mission Rank",
	},
	hq_max_rank = {
		en = "Maximum Assignment / Mission Rank",
	},
	hq_rank_desc = {
		en = "Does the same thing as adjusting the setting inside the mission terminal. Just here as well in case you're in a mission or away from the terminal and just don't have an alternate way of accessing it (e.g. the Hub Shortcuts mod).",
	},
	hq_refresh_interval = {
		en = "Refresh interval",
	},
	hq_refresh_interval_desc = {
		en = "How often the queue refreshes the listings and sends a fresh round of join requests to every Havoc lobby in your rank range.",
	},
	hq_debug = {
		en = "Debug messages",
	},
	hq_debug_desc = {
		en = "Logs queue activity to the console",
	},

	hq_stepper_min = {
		en = "LOWEST RANK",
	},
	hq_stepper_max = {
		en = "HIGHEST RANK",
	},

	hq_search_title = {
		en = "Looking for Havoc Party...",
	},
	hq_search_range = {
		en = "Havoc - %d to %d",
	},
	hq_search_cancel = {
		en = "Press %s to cancel search.",
	},

	hq_found_title = {
		en = "Havoc lobby found!",
	},
	hq_found_joining = {
		en = "Joining in %d...",
	},
	hq_found_cancel = {
		en = "Press %s to cancel.",
	},
	hq_found_join_cancel = {
		en = "Press %s to join instantly, or %s to cancel.",
	},

	hq_notify_joined = {
		en = "Joining Havoc lobby",
	},
	hq_notify_cancelled = {
		en = "Havoc queue cancelled",
	},
	hq_notify_already_queued = {
		en = "Already in the Havoc queue",
	},
	hq_notify_blacklisted = {
		en = "Left the lobby. The queue will not ask to join it again for %d minutes.",
	},
	hq_bl_popup_body = {
		en = "Leave this lobby and stop the queue from asking to join it again for the next %d minutes. "
			.. "The block clears by itself, and it applies to this lobby only.",
	},
	hq_notify_not_in_lobby = {
		en = "Not in a lobby with anyone",
	},
	hq_notify_not_queued = {
		en = "Not queued or hosting",
	},
	hq_notify_host_started = {
		en = "Hosting a Havoc lobby",
	},
	hq_notify_host_stopped = {
		en = "Stopped hosting",
	},
	hq_notify_host_failed = {
		en = "Could not create the Havoc lobby",
	},
	hq_notify_auto_start = {
		en = "Lobby full, starting Havoc mission",
	},
	hq_notify_launch_failed = {
		en = "Could not start the Havoc mission",
	},

	hq_block_level = {
		en = "You must be level 30 to queue for this mode.",
	},
	hq_block_not_unlocked = {
		en = "Havoc is not unlocked on this account",
	},
	hq_block_off_cadence = {
		en = "Havoc is between cadences right now",
	},
	hq_block_in_havoc = {
		en = "Already in a Havoc mission",
	},
	hq_block_cancelled = {
		en = "Queue cancelled. Return to the Mourningstar to queue again.",
	},
	hq_block_host_in_mission = {
		en = "Cannot host while in a mission",
	},
	hq_block_no_order = {
		en = "No Havoc assignment to host",
	},

	hq_cmd_queue_desc = {
		en = "Queue for a Havoc match, works from inside a mission",
	},
	hq_cmd_blacklist_desc = {
		en = "Leave the lobby and block the queue from asking to rejoin it",
	},
	hq_cmd_cancel_desc = {
		en = "Cancel the Havoc queue or stop hosting",
	},
	hq_cmd_status_desc = {
		en = "Print the Havoc queue status",
	},
}
