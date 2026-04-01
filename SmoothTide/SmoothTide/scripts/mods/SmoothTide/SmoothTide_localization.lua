return {
	mod_name = {
		en = "{#color(255,0,0)}SmoothTide Pro{#reset()}",
	},
	mod_description = {
		en = "{#color(255,0,0)}Adaptive performance and cinematic control for smoother hordes, smarter scaling, and cleaner combat visuals.{#reset()}",
	},

	debug_enabled = {
		en = "{#color(0,255,255)}Debug Enabled{#reset()}",
	},
	debug_enabled_description = {
		en = "{#color(0,255,255)}Shows debug echoes for settings and dynamic resolution changes.{#reset()}",
	},

	combat_echo = {
		en = "{#color(0,255,255)}Combat Echo{#reset()}",
	},
	combat_echo_description = {
		en = "{#color(0,255,255)}Displays mode change messages such as Combat, Panic, Ultra Panic, Cinematic, and Performance.{#reset()}",
	},

	combat_timeout = {
		en = "{#color(0,255,255)}Combat Timeout{#reset()}",
	},
	combat_timeout_description = {
		en = "{#color(0,255,255)}How long combat stays active after recent attack activity, in seconds.{#reset()}",
	},

	combat_range = {
		en = "{#color(0,255,255)}Combat Range{#reset()}",
	},
	combat_range_description = {
		en = "{#color(0,255,255)}Nearby enemy scan radius used for combat and horde detection.{#reset()}",
	},

	suppress_hit_indicators = {
		en = "{#color(0,255,255)}Suppress Hit Indicators{#reset()}",
	},
	suppress_hit_indicators_description = {
		en = "{#color(0,255,255)}Hides hit indicators during combat when allowed by current mode rules.{#reset()}",
	},

	suppress_damage_overlay = {
		en = "{#color(0,255,255)}Suppress Damage Overlay{#reset()}",
	},
	suppress_damage_overlay_description = {
		en = "{#color(0,255,255)}Hides the player damage overlay during combat when allowed by current mode rules.{#reset()}",
	},

	particle_thinning = {
		en = "{#color(0,255,255)}Particle Thinning{#reset()}",
	},
	particle_thinning_description = {
		en = "{#color(0,255,255)}Reduces spawned particles dynamically to lower visual load in heavier scenes.{#reset()}",
	},

	particle_keep_chance = {
		en = "{#color(0,255,255)}Particle Keep Chance{#reset()}",
	},
	particle_keep_chance_description = {
		en = "{#color(0,255,255)}Base percentage chance for a particle to be kept when thinning is active.{#reset()}",
	},

	enable_panic_mode = {
		en = "{#color(0,255,255)}Enable Panic Mode{#reset()}",
	},
	enable_panic_mode_description = {
		en = "{#color(0,255,255)}Turns on Panic Mode when nearby enemy count becomes heavy.{#reset()}",
	},

	panic_enemy_count = {
		en = "{#color(0,255,255)}Panic Enemy Count{#reset()}",
	},
	panic_enemy_count_description = {
		en = "{#color(0,255,255)}Nearby enemy count needed to trigger Panic Mode.{#reset()}",
	},

	panic_particle_keep_chance = {
		en = "{#color(0,255,255)}Panic Particle Keep Chance{#reset()}",
	},
	panic_particle_keep_chance_description = {
		en = "{#color(0,255,255)}Particle keep percentage used while Panic Mode is active.{#reset()}",
	},

	panic_hide_hit_indicators = {
		en = "{#color(0,255,255)}Panic Hide Hit Indicators{#reset()}",
	},
	panic_hide_hit_indicators_description = {
		en = "{#color(0,255,255)}Forces hit indicators off while Panic Mode is active.{#reset()}",
	},

	panic_hide_damage_overlay = {
		en = "{#color(0,255,255)}Panic Hide Damage Overlay{#reset()}",
	},
	panic_hide_damage_overlay_description = {
		en = "{#color(0,255,255)}Forces damage overlay off while Panic Mode is active.{#reset()}",
	},

	enable_ultra_panic_mode = {
		en = "{#color(0,255,255)}Enable Ultra Panic Mode{#reset()}",
	},
	enable_ultra_panic_mode_description = {
		en = "{#color(0,255,255)}Turns on Ultra Panic Mode for extreme nearby enemy counts.{#reset()}",
	},

	ultra_panic_enemy_count = {
		en = "{#color(0,255,255)}Ultra Panic Enemy Count{#reset()}",
	},
	ultra_panic_enemy_count_description = {
		en = "{#color(0,255,255)}Nearby enemy count needed to trigger Ultra Panic Mode.{#reset()}",
	},

	ultra_panic_particle_keep_chance = {
		en = "{#color(0,255,255)}Ultra Panic Particle Keep Chance{#reset()}",
	},
	ultra_panic_particle_keep_chance_description = {
		en = "{#color(0,255,255)}Particle keep percentage used while Ultra Panic Mode is active.{#reset()}",
	},

	ultra_panic_force_performance = {
		en = "{#color(0,255,255)}Ultra Panic Force Performance{#reset()}",
	},
	ultra_panic_force_performance_description = {
		en = "{#color(0,255,255)}Forces performance mode during Ultra Panic unless cinematic is manually forced.{#reset()}",
	},

	boss_safe_mode = {
		en = "{#color(0,255,255)}Boss Safe Mode{#reset()}",
	},
	boss_safe_mode_description = {
		en = "{#color(0,255,255)}Avoids treating boss encounters like normal horde panic situations.{#reset()}",
	},

	mode_hotkey_enabled = {
		en = "{#color(0,255,255)}Enable Mode Hotkeys{#reset()}",
	},
	mode_hotkey_enabled_description = {
		en = "{#color(0,255,255)}Allows the manual mode hotkeys to work in-game.{#reset()}",
	},

	default_mode = {
		en = "{#color(0,255,255)}Default Mode{#reset()}",
	},
	default_mode_description = {
		en = "{#color(0,255,255)}Sets the starting preference when no manual force is active.{#reset()}",
	},
	default_mode_cinematic = {
		en = "{#color(0,255,255)}Cinematic{#reset()}",
	},
	default_mode_performance = {
		en = "{#color(0,255,255)}Performance{#reset()}",
	},

	force_cinematic_mode = {
		en = "{#color(0,255,255)}Force Cinematic Mode{#reset()}",
	},
	force_cinematic_mode_description = {
		en = "{#color(0,255,255)}Locks the mod into cinematic mode until turned off.{#reset()}",
	},

	force_performance_mode = {
		en = "{#color(0,255,255)}Force Performance Mode{#reset()}",
	},
	force_performance_mode_description = {
		en = "{#color(0,255,255)}Locks the mod into performance mode until turned off.{#reset()}",
	},

	enable_smart_mode = {
		en = "{#color(0,255,255)}Enable Smart Mode{#reset()}",
	},
	enable_smart_mode_description = {
		en = "{#color(0,255,255)}Automatically switches between cinematic and performance based on average FPS.{#reset()}",
	},

	smart_mode_fps_threshold = {
		en = "{#color(0,255,255)}Smart Mode FPS Threshold{#reset()}",
	},
	smart_mode_fps_threshold_description = {
		en = "{#color(0,255,255)}When average FPS falls below this, performance mode is favored.{#reset()}",
	},

	smart_mode_restore_fps = {
		en = "{#color(0,255,255)}Smart Mode Restore FPS{#reset()}",
	},
	smart_mode_restore_fps_description = {
		en = "{#color(0,255,255)}When average FPS rises above this, the default preferred mode can return.{#reset()}",
	},

	auto_cinematic_when_calm = {
		en = "{#color(0,255,255)}Auto Cinematic When Calm{#reset()}",
	},
	auto_cinematic_when_calm_description = {
		en = "{#color(0,255,255)}Automatically returns to cinematic mode after the fight settles down.{#reset()}",
	},

	calm_enemy_threshold = {
		en = "{#color(0,255,255)}Calm Enemy Threshold{#reset()}",
	},
	calm_enemy_threshold_description = {
		en = "{#color(0,255,255)}Maximum nearby enemies allowed before the area is no longer considered calm.{#reset()}",
	},

	calm_restore_delay = {
		en = "{#color(0,255,255)}Calm Restore Delay{#reset()}",
	},
	calm_restore_delay_description = {
		en = "{#color(0,255,255)}How long calm conditions must last before cinematic mode returns.{#reset()}",
	},

	auto_performance_in_hordes = {
		en = "{#color(0,255,255)}Auto Performance In Hordes{#reset()}",
	},
	auto_performance_in_hordes_description = {
		en = "{#color(0,255,255)}Automatically favors performance mode when nearby enemy count gets heavy.{#reset()}",
	},

	horde_enemy_threshold = {
		en = "{#color(0,255,255)}Horde Enemy Threshold{#reset()}",
	},
	horde_enemy_threshold_description = {
		en = "{#color(0,255,255)}Nearby enemy count needed to force performance during heavy fights.{#reset()}",
	},

	enable_dynamic_resolution = {
		en = "{#color(0,255,255)}Enable Dynamic Resolution{#reset()}",
	},
	enable_dynamic_resolution_description = {
		en = "{#color(0,255,255)}Dynamically lowers or restores render scale based on FPS pressure.{#reset()}",
	},

	dynamic_resolution_min_scale = {
		en = "{#color(0,255,255)}Dynamic Resolution Min Scale{#reset()}",
	},
	dynamic_resolution_min_scale_description = {
		en = "{#color(0,255,255)}Lowest render scale percentage allowed when performance is under stress.{#reset()}",
	},

	dynamic_resolution_max_scale = {
		en = "{#color(0,255,255)}Dynamic Resolution Max Scale{#reset()}",
	},
	dynamic_resolution_max_scale_description = {
		en = "{#color(0,255,255)}Highest render scale percentage the mod can restore to.{#reset()}",
	},

	dynamic_resolution_fps_floor = {
		en = "{#color(0,255,255)}Dynamic Resolution FPS Floor{#reset()}",
	},
	dynamic_resolution_fps_floor_description = {
		en = "{#color(0,255,255)}When average FPS drops below this, render scale begins stepping down.{#reset()}",
	},

	dynamic_resolution_fps_target = {
		en = "{#color(0,255,255)}Dynamic Resolution FPS Target{#reset()}",
	},
	dynamic_resolution_fps_target_description = {
		en = "{#color(0,255,255)}When average FPS rises above this, render scale begins stepping back up.{#reset()}",
	},

	toggle_smoothtide_mode_hotkey = {
		en = "{#color(0,255,255)}Toggle Smart Mode Preference{#reset()}",
	},
	toggle_smoothtide_mode_hotkey_description = {
		en = "{#color(0,255,255)}Manually flips between cinematic and performance preference when no force mode is active.{#reset()}",
	},

	toggle_performance_mode_hotkey = {
		en = "{#color(0,255,255)}Toggle Performance Mode Hotkey{#reset()}",
	},
	toggle_performance_mode_hotkey_description = {
		en = "{#color(0,255,255)}Hotkey that forces performance mode on or off instantly.{#reset()}",
	},

	toggle_cinematic_mode_hotkey = {
		en = "{#color(0,255,255)}Toggle Cinematic Mode Hotkey{#reset()}",
	},
	toggle_cinematic_mode_hotkey_description = {
		en = "{#color(0,255,255)}Hotkey that forces cinematic mode on or off instantly.{#reset()}",
	},
}