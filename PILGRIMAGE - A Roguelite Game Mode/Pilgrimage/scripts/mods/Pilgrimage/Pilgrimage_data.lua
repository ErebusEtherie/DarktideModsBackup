-- Pilgrimage_data.lua
--
-- The mod options tree. UI structure only; no logic, no defaults of its own.
--
-- DEFAULTS is imported from settings.lua so every default value is written down in
-- exactly one place. That file must stay free of runtime state, because io_dofile
-- gives us a second independent copy of it here.

local mod = get_mod("Pilgrimage")

local Settings  = mod:io_dofile("Pilgrimage/scripts/mods/Pilgrimage/settings")
local LogLevels = mod:io_dofile("Pilgrimage/scripts/mods/Pilgrimage/log_levels")

local DEFAULTS = Settings.DEFAULTS

-- DMF FOOTGUN: DMF localizes option.text IN PLACE. If two dropdowns share the same
-- options array, the second one localizes an already-localized string, fails the
-- lookup, and wraps it in angle brackets. Every dropdown gets its own copy.
local function copy_options(source)
	local out = {}
	for i = 1, #source do
		out[i] = { text = source[i].text, value = source[i].value }
	end
	return out
end

local function checkbox(setting_id, sub_widgets)
	local widget = {
		setting_id    = setting_id,
		type          = "checkbox",
		default_value = DEFAULTS[setting_id],
		tooltip       = setting_id .. "_tooltip",
	}

	if sub_widgets then
		widget.sub_widgets = sub_widgets
	end

	return widget
end

local function numeric(setting_id, range, decimals)
	return {
		setting_id      = setting_id,
		type            = "numeric",
		default_value   = DEFAULTS[setting_id],
		range           = range,
		decimals_number = decimals or 0,
		tooltip         = setting_id .. "_tooltip",
	}
end

local function dropdown(setting_id, options)
	return {
		setting_id    = setting_id,
		type          = "dropdown",
		default_value = DEFAULTS[setting_id],
		options       = options,
		tooltip       = setting_id .. "_tooltip",
	}
end

return {
	name        = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,

	options = {
		widgets = {
			-- -------------------------------------------------------------
			{
				setting_id  = "group_run",
				type        = "group",
					sub_widgets = {
					checkbox("enable_blitz_mode"),
					-- v0.23.4 (Kaizen settings audit): run_length and
					-- run_boons_per_leg removed, both superseded (leg
					-- count comes from the War Plan, draft size is fixed
					-- plus the Zero Waste bonus). run_seeded/run_seed
					-- removed too: a 10-digit SLIDER was, in Kaizen's
					-- words, sadistic; seeding now lives in /pil_seed,
					-- which takes a typed number. starting_difficulty
					-- dropdown removed, governed by War Plans since H.
					checkbox("curses_havoc_pool"),
					checkbox("curses_live_event_pool"),
					checkbox("curses_stacking"),
					checkbox("curses_guard"),
					checkbox("enable_overlay_panel"),
					checkbox("fx_guard"),
					-- v0.25.1: full boon visuals via the Mortis package.
					checkbox("fx_full_visuals"),
				},
			},

			-- -------------------------------------------------------------
			{
				setting_id  = "group_terminal",
				type        = "group",
				sub_widgets = {
					checkbox("enable_terminal_prompt"),
					numeric("terminal_prompt_distance", { 1, 20 }),
					checkbox("enable_bot_hack_orders"),
					-- v0.23.3 (FB-3): open the Pilgrimage terminal from
					-- anywhere. Unbound by default per the player spec.
					{
						setting_id      = "terminal_keybind",
						type            = "keybind",
						default_value   = {},
						keybind_global  = false,
						keybind_trigger = "pressed",
						keybind_type    = "function_call",
						function_name   = "pilgrimage_terminal_hotkey",
					},
				},
			},

			-- -------------------------------------------------------------
			{
				setting_id  = "group_diagnostics",
				type        = "group",
				sub_widgets = {
					{
						setting_id    = "log_level",
						type          = "dropdown",
						default_value = DEFAULTS.log_level,
						options       = copy_options(LogLevels.OPTIONS),
						tooltip       = "log_level_tooltip",
					},
					checkbox("enable_event_log"),
					checkbox("enable_perf"),
					-- v0.23.0: gates ff_diag.txt / bot_spawn_diag.txt writes.
					checkbox("diagnostics_enabled"),
					checkbox("betterbots_navigation_guard"),
				},
			},

			-- v0.23.3 (FB-2, player suggestion): testing / cheat mode.
			-- Master switch suspends penance earning while on (nothing
			-- earned is ever revoked); sub-toggles pick the effects.
			{
				setting_id  = "group_testing",
				type        = "group",
					sub_widgets = {
						checkbox("cheat_mode"),
						checkbox("cheat_invulnerable"),
						checkbox("cheat_one_shot"),
					},
			},

			{
				setting_id  = "group_weapon_balancing",
				type        = "group",
				sub_widgets = {
					checkbox("custom_weapon_balancing", {
						checkbox("custom_weapon_balancing_meat_grinder"),
						checkbox("custom_weapon_visuals"),
						checkbox("custom_weapon_sounds"),
					}),
				},
			},

			-- v0.22.31: debug utilities. Currently just the capture-all
			-- keybind + its target-preset picker, so Kaizen can capture
			-- a bot preset's character/loadout/look/voice without opening
			-- chat from the character-select screen. Separate group so
			-- the surface here is clearly "shortcuts for iteration",
			-- not core gameplay settings.
			{
				setting_id  = "group_debug",
				type        = "group",
				sub_widgets = {
					{
						setting_id = "capture_target_preset",
						type       = "dropdown",
						default_value = DEFAULTS.capture_target_preset,
						-- Options are the preset ids the mod ships. Kept
						-- here as literals rather than pulled from the
						-- Preset module because DMF reads this list at
						-- data-file load, which runs before bootstrap.
						-- Add a new preset to this list when adding one
						-- to preset.lua's catalogue.
						--
						-- v0.22.32: DMF validates dropdowns and REQUIRES at
						-- least two options (options.lua line 202); a
						-- single-option dropdown throws
						-- "options table must have at least 2 elements"
						-- at data-init and DISABLES THE WHOLE MOD (no
						-- commands, no terminal, no boot.log entry). "None"
						-- covers that until we ship a second preset, and
						-- doubles as a way to disable the keybind at
						-- runtime.
						options    = {
							-- v0.22.94 (Kaizen: "I can't just be scrolling an
							-- arbitrarily sorted list of endless bot names"):
							-- full catalogue, tier-prefixed labels (see the
							-- localization file), sorted tier 3 -> 1 and
							-- alphabetically inside each tier. STILL a hand-
							-- kept list (DMF reads it before bootstrap); the
							-- boot-time audit in Pilgrimage.lua now yells if
							-- it drifts from the catalogue again.
							{ text = "capture_target_none", value = "none" },
							-- Tier 3 Heroes
							{ text = "capture_target_seneschal_abelard", value = "seneschal_abelard" },
							{ text = "capture_target_ogryn_gunlugger", value = "ogryn_gunlugger" },
							{ text = "capture_target_spyer", value = "spyer" },
							{ text = "capture_target_mechanicus_warhound_alpha", value = "mechanicus_warhound_alpha" },
							{ text = "capture_target_cassia_orsellio", value = "cassia_orsellio" },
							{ text = "capture_target_rogue_trader", value = "rogue_trader" },
							{ text = "capture_target_interrogator_heinrix", value = "interrogator_heinrix" },
							{ text = "capture_target_idira_tlass", value = "idira_tlass" },
							{ text = "capture_target_princess_jae", value = "princess_jae" },
							{ text = "capture_target_jocasta_sauerback", value = "jocasta_sauerback" },
							{ text = "capture_target_spinner_kibellah", value = "spinner_kibellah" },
							{ text = "capture_target_lady_steel", value = "lady_steel" },
							{ text = "capture_target_lord_magleviathan", value = "lord_magleviathan" },
							{ text = "capture_target_sicarian_ruststalker_princeps", value = "sicarian_ruststalker_princeps" },
							{ text = "capture_target_magos_haneumann", value = "magos_haneumann" },
							{ text = "capture_target_arbites_marshal", value = "arbites_marshal" },
							{ text = "capture_target_tempestor_prime", value = "tempestor_prime" },
							{ text = "capture_target_sister_argenta", value = "sister_argenta" },
							{ text = "capture_target_solomorne", value = "solomorne" },
							{ text = "capture_target_theodora_von_valancius", value = "theodora_von_valancius" },
							{ text = "capture_target_your_host", value = "your_host" },
							{ text = "capture_target_heavy_weapons_servitor", value = "heavy_weapons_servitor" },
							{ text = "capture_target_augmented_ogryn_heavy_gunner", value = "augmented_ogryn_heavy_gunner" },
							-- Tier 2 Champions
							{ text = "capture_target_krieg_guardsman", value = "krieg_guardsman" },
							{ text = "capture_target_arbites_enforcer", value = "arbites_enforcer" },
							{ text = "capture_target_heavy_skitarius", value = "heavy_skitarius" },
							{ text = "capture_target_mechanicus_warhound", value = "mechanicus_warhound" },
							{ text = "capture_target_sister_repentia", value = "sister_repentia" },
							{ text = "capture_target_commissar", value = "commissar" },
							{ text = "capture_target_undercover_arbitrator", value = "undercover_arbitrator" },
							{ text = "capture_target_kasrkin_marksman", value = "kasrkin_marksman" },
							{ text = "capture_target_hive_exterminator", value = "hive_exterminator" },
							{ text = "capture_target_crusader", value = "crusader" },
							{ text = "capture_target_electropriest", value = "electropriest" },
							{ text = "capture_target_heavy_combat_servitor", value = "heavy_combat_servitor" },
							{ text = "capture_target_scholastica_pyrokinetic", value = "scholastica_pyrokinetic" },
							{ text = "capture_target_tempestus_scion", value = "tempestus_scion" },
							{ text = "capture_target_underhive_wyrd", value = "underhive_wyrd" },
							{ text = "capture_target_tech_priest", value = "tech_priest" },
							{ text = "capture_target_household_navigator", value = "household_navigator" },
							{ text = "capture_target_ministorum_flamer", value = "ministorum_flamer" },
							{ text = "capture_target_astropath", value = "astropath" },
							{ text = "capture_target_voidship_breacher", value = "voidship_breacher" },
							{ text = "capture_target_sicarian_ruststalker", value = "sicarian_ruststalker" },
							{ text = "capture_target_ogryn_hunter", value = "ogryn_hunter" },
							{ text = "capture_target_ogryn_demolition_specialist", value = "ogryn_demolition_specialist" },
							{ text = "capture_target_sanctioned_psychic_enforcer", value = "sanctioned_psychic_enforcer" },
							{ text = "capture_target_voidsman_at_arms", value = "voidsman_at_arms" },
							{ text = "capture_target_recon_drone", value = "recon_drone" },
							{ text = "capture_target_heavy_gunner", value = "heavy_gunner" },
							{ text = "capture_target_rejuvenat_adept", value = "rejuvenat_adept" },
							{ text = "capture_target_arbites_proctor", value = "arbites_proctor" },
							{ text = "capture_target_sister_of_battle", value = "sister_of_battle" },
							{ text = "capture_target_hive_chemist", value = "hive_chemist" },
							{ text = "capture_target_deck_cleaner", value = "deck_cleaner" },
							-- Tier 1 Living Tithe
							{ text = "capture_target_black_ship_fodder", value = "black_ship_fodder" },
							{ text = "capture_target_cartel_recruit", value = "cartel_recruit" },
							{ text = "capture_target_grog", value = "grog" },
							{ text = "capture_target_militarum_preacher", value = "militarum_preacher" },
							{ text = "capture_target_moebian_conscript", value = "moebian_conscript" },
							{ text = "capture_target_moebian_deputy", value = "moebian_deputy" },
							{ text = "capture_target_skitarius_2137", value = "skitarius_2137" },
						},
						tooltip    = "capture_target_preset_tooltip",
					},
					{
						setting_id     = "capture_all_keybind",
						type           = "keybind",
						default_value  = {},
						keybind_global = false,
						keybind_trigger = "pressed",
						keybind_type   = "function_call",
						-- Names the function on `mod` that DMF invokes on
						-- key press. Defined in Pilgrimage.lua so it can
						-- reach the Preset module through mod._modules.
						function_name  = "pilgrimage_capture_all_hotkey",
					},
				},
			},
		},
	},
}
