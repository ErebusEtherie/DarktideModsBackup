local mod = get_mod("NoPingSounds")
local stuff = {}

stuff.mod_name = {
	en = "No Ping Sounds",
}
stuff.mod_description = {
	en = "Removes the ping sound",
}

stuff.ping_mute_enemy = {
	en = "Mute ALL enemy pings",
}

stuff.ping_mute_enemy_in_front = {
	en = "only if in view",
}
stuff.ping_mute_enemy_in_front_description = {
	en = "This will only mute pings that happen WITHIN your view",
}

stuff.ping_mute_enemy_doubletag = {
	en = "Mute ALL enemy pings (double-tag)",
}
stuff.ping_mute_enemy_doubletag_description = {
	en = "e.g. Arbitrator Dog Ping",
}

stuff.ping_mute_enemy_doubletag_in_front = stuff.ping_mute_enemy_in_front
stuff.ping_mute_enemy_doubletag_in_front_description = stuff.ping_mute_enemy_in_front_description

stuff.ping_mute_item = {
	en = "Mute ALL item pings",
}

stuff.ping_mute_location_ping = {
	en = 'Mute "Let\'s go here" marker',
}
stuff.ping_mute_location_attention = {
	en = 'Mute "Scout that area" marker',
}
stuff.ping_mute_location_threat = {
	en = 'Mute "Enemy over there" marker',
}

stuff.ping_duration = {
	en = "Override ping duration",
}
stuff.ping_duration_seconds = {
	en = "Seconds",
}

stuff.debug = {
	en = "Debug mode",
}

stuff.debug_repeat_ping = {
	en = "Repeat your last enemy/item/location ping",
}
stuff.debug_repeat_ping_description = {
	en = "This way you can test the settings",
}

return stuff
