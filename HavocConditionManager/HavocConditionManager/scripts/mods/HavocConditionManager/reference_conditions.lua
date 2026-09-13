-- Adapted from the user-provided SoloPlayMoreHavoc (9.4-2). See THIRD_PARTY.md.
local mod = get_mod("HavocConditionManager")
local slp_mod = get_mod("SoloPlay")

local MutatorTemplates = require("scripts/settings/mutator/mutator_templates")
local BuffTemplates = require("scripts/settings/buff/buff_templates")
local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")
local NetworkLookup = require("scripts/network_lookup/network_lookup")
local Breeds = require("scripts/settings/breed/breeds")
local RoamerPacing = require("scripts/managers/pacing/roamer_pacing/roamer_pacing")
local RoamerPacks = require("scripts/settings/roamer/roamer_packs")
local LoadedDice = require("scripts/utilities/loaded_dice")
local HordePacing = require("scripts/managers/pacing/horde_pacing/horde_pacing")
local HordeCompositions = require("scripts/managers/pacing/horde_pacing/horde_compositions")
local MinionSpawnManager = require("scripts/managers/minion/minion_spawn_manager")
local MissionOverrides = require("scripts/settings/circumstance/mission_overrides")
local HazardPropSystem = require("scripts/extension_systems/hazard_prop/hazard_prop_system")

local MAX_EXTRA_CIRCUMSTANCES = 10
local MAX_MORE_HAVOC_PAGES = 2

-- The vanilla tactical overlay HUD only defines four havoc circumstance rows.
-- Keep the vanilla display and only truncate extra circumstances while the
-- overlay updates, preventing the nil-style crash.
local MAX_TACTICAL_OVERLAY_HAVOC_CIRCUMSTANCES = 4

local EXTRA_CIRCUMSTANCE_IDS = {
	"havoc_circumstance3",
	"havoc_circumstance4",
	"havoc_circumstance5",
	"havoc_circumstance6",
	"havoc_circumstance7",
	"havoc_circumstance8",
	"havoc_circumstance9",
	"havoc_circumstance10",
	"havoc_circumstance11",
	"havoc_circumstance12",
}

-- The selectable "Nurgle's Blessing" is built from a copy of the game's Auric
-- Maelstrom mutator and registered as a real CircumstanceTemplate. It is written
-- into havoc_data.circumstances like any other Havoc word, loaded by the game's
-- own MutatorManager, and displayed by the vanilla Tab tactical panel.
local GAME_NURGLE_BLESSING_MUTATOR = "mutator_minion_nurgle_blessing"
local NURGLE_BLESSING_MUTATOR = "more_havoc_nurgle_blessing"
local NURGLE_BLESSING_BUFF = "mutator_minion_nurgle_blessing_tougher"
local NURGLE_BLESSING_CHANCE_PER_RANK = 0.005

local MONSTER_SPECIALS_MUTATOR = "more_havoc_monster_specials"
local MONSTER_SPECIALS_TWIN_CAPTAIN_MELEE = "renegade_twin_captain_two"
local MONSTER_SPECIALS_TWIN_CAPTAIN_RANGED = "renegade_twin_captain"
local MONSTER_SPECIALS_HOUNDMASTER = "chaos_ogryn_houndmaster"

local ASSAULT_FORCE_MUTATOR = "more_havoc_assault_force"

local FACTION_SWITCH = "switch"
local FACTION_SWITCH_MUTATOR = "more_faction_switch"

local FACTION_COMBINED = "combined"
local FACTION_COMBINED_MUTATOR = "more_faction_combined"

local OLD_ROTTEN_ARMOR_CIRCUMSTANCE = "more_old_rotten_armor"
local OLD_ROTTEN_ARMOR_TRICKLE_MUTATOR = "more_old_rotten_armor_trickle"
local VANILLA_ROTTEN_ARMOR_CIRCUMSTANCE = "mutator_havoc_rotten_armor"

local ABHUMAN_CIRCUMSTANCE = "more_havoc_abhuman"
local ABHUMAN_TRICKLE_MUTATOR = "more_havoc_abhuman_trickle"
local ABHUMAN_REPLACEMENT_MUTATOR = "more_havoc_abhuman_replacement"

local ELITE_ARMY_CIRCUMSTANCE = "more_havoc_elite_army"
local ENDLESS_HORDES_CIRCUMSTANCE = "more_havoc_endless_hordes"
local BARREL_GROUNDS_CIRCUMSTANCE = "more_havoc_barrel_grounds"

local MONSTER_SPECIALS_CONFIG = {
	chance_to_spawn_monster = 0.2,
	max_monsters = 2,
	health_modifiers = {
		chaos_beast_of_nurgle = 0.4,
		chaos_plague_ogryn = 0.4,
		chaos_spawn = 0.4,
		chaos_ogryn_houndmaster = 0.4,
	},
	max_monster_duration = {
		90,
		180,
	},
	breeds = {
		"chaos_plague_ogryn",
		"chaos_beast_of_nurgle",
		"chaos_spawn",
	},
}

local function add_network_lookup_key(lookup, key)
	if type(lookup) ~= "table" then
		return
	end

	if rawget(lookup, key) == nil then
		lookup[#lookup + 1] = key
		lookup[key] = #lookup
	end
end

local NURGLE_BLESSING_AVAILABLE = false
local NURGLE_BLESSING_BASE_BREED_CHANCES = nil

local function register_nurgle_blessing()
	local source_mutator = MutatorTemplates and MutatorTemplates[GAME_NURGLE_BLESSING_MUTATOR]
	local source_buff = BuffTemplates and BuffTemplates[NURGLE_BLESSING_BUFF]

	if not source_mutator or not source_buff then
		mod:error("SoloPlayMoreHavoc could not register Nurgle's Blessing: source mutator or buff template is missing.")
		return false
	end

	-- Reuse the native buff and its network ID. Only the circumstance's spawn
	-- chances need a separate copy; an extra buff would offset later mod IDs.
	local source_breed_chances = source_mutator.random_spawn_buff_templates
		and source_mutator.random_spawn_buff_templates.breed_chances
	local copied_breed_chances = source_breed_chances and table.clone(source_breed_chances) or {}

	NURGLE_BLESSING_BASE_BREED_CHANCES = table.clone(copied_breed_chances)

	if not MutatorTemplates[NURGLE_BLESSING_MUTATOR] then
		MutatorTemplates[NURGLE_BLESSING_MUTATOR] = {
			name = NURGLE_BLESSING_MUTATOR,
			class = source_mutator.class or "scripts/managers/mutator/mutators/mutator_minion_nurgle_blessing",
			random_spawn_buff_templates = {
				buffs = {
					NURGLE_BLESSING_BUFF,
				},
				breed_chances = copied_breed_chances,
			},
		}
	else
		local existing_mutator_template = MutatorTemplates[NURGLE_BLESSING_MUTATOR]
		local existing_random_spawn_buff_templates = existing_mutator_template
			and existing_mutator_template.random_spawn_buff_templates

		if existing_random_spawn_buff_templates then
			existing_random_spawn_buff_templates.buffs = { NURGLE_BLESSING_BUFF }
			existing_random_spawn_buff_templates.breed_chances = copied_breed_chances
		end
	end

	if not CircumstanceTemplates[NURGLE_BLESSING_MUTATOR] then
		CircumstanceTemplates[NURGLE_BLESSING_MUTATOR] = {
			theme_tag = "default",
			mutators = {
				NURGLE_BLESSING_MUTATOR,
			},
			ui = {
				description = "more_havoc_nurgle_blessing_description",
				display_name = "more_havoc_nurgle_blessing_title",
				happening_display_name = "more_havoc_nurgle_blessing_title",
				icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
				mission_board_icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
			},
		}
	end

	add_network_lookup_key(NetworkLookup.circumstance_templates, NURGLE_BLESSING_MUTATOR)

	NURGLE_BLESSING_AVAILABLE = true

	if type(mod.info) == "function" then
		mod:info("SoloPlayMoreHavoc registered Nurgle's Blessing: %s", NURGLE_BLESSING_MUTATOR)
	end

	return true
end

local function reset_nurgle_blessing_chances()
	local mutator_template = MutatorTemplates[NURGLE_BLESSING_MUTATOR]
	local random_spawn_buff_templates = mutator_template and mutator_template.random_spawn_buff_templates
	local breed_chances = random_spawn_buff_templates and random_spawn_buff_templates.breed_chances

	if not breed_chances or not NURGLE_BLESSING_BASE_BREED_CHANCES then
		return
	end

	for breed_name, base_chance in pairs(NURGLE_BLESSING_BASE_BREED_CHANCES) do
		breed_chances[breed_name] = base_chance
	end
end

local function nurgle_blessing_rank_scaling_enabled()
	local enabled = mod:get("nurgle_blessing_rank_scaling")

	return enabled == true or enabled == 1
end

local function update_nurgle_blessing_chances_for_rank(context)
	if not NURGLE_BLESSING_AVAILABLE or not NURGLE_BLESSING_BASE_BREED_CHANCES then
		return context
	end

	-- Always start from the vanilla base chances. This makes turning the option
	-- off (or starting a mission without this circumstance) restore the base
	-- values instead of leaking the previous mission's rank-scaled chances.
	reset_nurgle_blessing_chances()

	if not nurgle_blessing_rank_scaling_enabled() then
		return context
	end

	if type(context) ~= "table" or type(context.havoc_data) ~= "string" then
		return context
	end

	local parts = string.split(context.havoc_data, ";")

	if not parts or #parts < 5 then
		return context
	end

	local circumstance_data = parts[5]
	local circumstances = circumstance_data and circumstance_data ~= "" and string.split(circumstance_data, ":") or {}
	local has_nurgle_blessing = false

	for _, circumstance_name in ipairs(circumstances) do
		if circumstance_name == NURGLE_BLESSING_MUTATOR then
			has_nurgle_blessing = true
			break
		end
	end

	if not has_nurgle_blessing then
		return context
	end

	local havoc_rank = tonumber(parts[2])

	if not havoc_rank or havoc_rank <= 0 then
		return context
	end

	local mutator_template = MutatorTemplates[NURGLE_BLESSING_MUTATOR]
	local random_spawn_buff_templates = mutator_template and mutator_template.random_spawn_buff_templates
	local breed_chances = random_spawn_buff_templates and random_spawn_buff_templates.breed_chances

	if not breed_chances then
		return context
	end

	for breed_name, base_chance in pairs(NURGLE_BLESSING_BASE_BREED_CHANCES) do
		if type(base_chance) == "number" and base_chance > 0 then
			breed_chances[breed_name] = math.clamp(
				base_chance + NURGLE_BLESSING_CHANCE_PER_RANK * havoc_rank,
				0,
				1
			)
		else
			breed_chances[breed_name] = base_chance
		end
	end

	return context
end

local MONSTER_SPECIALS_AVAILABLE = false

local function register_monster_specials()
	if not MutatorTemplates[MONSTER_SPECIALS_MUTATOR] then
		MutatorTemplates[MONSTER_SPECIALS_MUTATOR] = {
			name = MONSTER_SPECIALS_MUTATOR,
			class = "scripts/managers/mutator/mutators/mutator_base",
		}
	end

	if not CircumstanceTemplates[MONSTER_SPECIALS_MUTATOR] then
		CircumstanceTemplates[MONSTER_SPECIALS_MUTATOR] = {
			theme_tag = "default",
			mutators = {
				MONSTER_SPECIALS_MUTATOR,
			},
			ui = {
				description = "more_havoc_monster_specials_description",
				display_name = "more_havoc_monster_specials_title",
				happening_display_name = "more_havoc_monster_specials_title",
				icon = "content/ui/materials/icons/circumstances/maelstrom_01",
				mission_board_icon = "content/ui/materials/mission_board/circumstances/maelstrom_01",
			},
		}
	end

	add_network_lookup_key(NetworkLookup.circumstance_templates, MONSTER_SPECIALS_MUTATOR)

	MONSTER_SPECIALS_AVAILABLE = true

	if type(mod.info) == "function" then
		mod:info("SoloPlayMoreHavoc registered Monster Specialists: %s", MONSTER_SPECIALS_MUTATOR)
	end

	return true
end

local ASSAULT_FORCE_AVAILABLE = false
local OLD_ROTTEN_ARMOR_AVAILABLE = false
local ABHUMAN_AVAILABLE = false
local ELITE_ARMY_AVAILABLE = false
local ENDLESS_HORDES_AVAILABLE = false
local BARREL_GROUNDS_AVAILABLE = false

local function register_assault_force()
	if not MutatorTemplates[ASSAULT_FORCE_MUTATOR] then
		MutatorTemplates[ASSAULT_FORCE_MUTATOR] = {
			name = ASSAULT_FORCE_MUTATOR,
			class = "scripts/managers/mutator/mutators/mutator_modify_pacing",
			init_modify_pacing = {
				chance_of_coordinated_strike = 1,
				max_alive_specials_multiplier = 1.6,
				specials_timer_modifier = 0.75,
				specials_move_timer_when_challenge_rating_above = 12,
				max_of_same_override = {
					chaos_hound = 4,
					chaos_poxwalker_bomber = 4,
					flamer = 3,
					cultist_flamer = 3,
					cultist_mutant = 6,
					renegade_flamer = 3,
					renegade_grenadier = 4,
					grenadier = 4,
					renegade_netgunner = 3,
					renegade_sniper = 5,
					cultist_grenadier = 4,
				},
			},
		}
	end

	if not CircumstanceTemplates[ASSAULT_FORCE_MUTATOR] then
		CircumstanceTemplates[ASSAULT_FORCE_MUTATOR] = {
			theme_tag = "default",
			mutators = {
				ASSAULT_FORCE_MUTATOR,
			},
			ui = {
				description = "more_havoc_assault_force_description",
				display_name = "more_havoc_assault_force_title",
				happening_display_name = "more_havoc_assault_force_title",
				icon = "content/ui/materials/icons/circumstances/maelstrom_01",
				mission_board_icon = "content/ui/materials/mission_board/circumstances/maelstrom_01",
			},
		}
	end

	add_network_lookup_key(NetworkLookup.circumstance_templates, ASSAULT_FORCE_MUTATOR)

	ASSAULT_FORCE_AVAILABLE = true

	if type(mod.info) == "function" then
		mod:info("SoloPlayMoreHavoc registered Assault Force: %s", ASSAULT_FORCE_MUTATOR)
	end

	return true
end

local function register_faction_switch()
	if not MutatorTemplates[FACTION_SWITCH_MUTATOR] then
		MutatorTemplates[FACTION_SWITCH_MUTATOR] = {
			name = FACTION_SWITCH_MUTATOR,
			class = "scripts/managers/mutator/mutators/mutator_base",
		}
	end

	if not CircumstanceTemplates[FACTION_SWITCH_MUTATOR] then
		CircumstanceTemplates[FACTION_SWITCH_MUTATOR] = {
			theme_tag = "default",
			mutators = {
				FACTION_SWITCH_MUTATOR,
			},
			ui = {
				description = "more_havoc_faction_switch_description",
				display_name = "more_havoc_faction_switch_title",
				happening_display_name = "more_havoc_faction_switch_title",
				icon = "content/ui/materials/icons/circumstances/maelstrom_01",
				mission_board_icon = "content/ui/materials/mission_board/circumstances/maelstrom_01",
			},
		}
	end

	add_network_lookup_key(NetworkLookup.circumstance_templates, FACTION_SWITCH_MUTATOR)

	if type(mod.info) == "function" then
		mod:info("SoloPlayMoreHavoc registered Faction Switch: %s", FACTION_SWITCH_MUTATOR)
	end

	return true
end

local function register_faction_combined()
	if not MutatorTemplates[FACTION_COMBINED_MUTATOR] then
		MutatorTemplates[FACTION_COMBINED_MUTATOR] = {
			name = FACTION_COMBINED_MUTATOR,
			class = "scripts/managers/mutator/mutators/mutator_base",
		}
	end

	if not CircumstanceTemplates[FACTION_COMBINED_MUTATOR] then
		CircumstanceTemplates[FACTION_COMBINED_MUTATOR] = {
			theme_tag = "default",
			mutators = {
				FACTION_COMBINED_MUTATOR,
			},
			ui = {
				description = "more_havoc_faction_combined_description",
				display_name = "more_havoc_faction_combined_title",
				happening_display_name = "more_havoc_faction_combined_title",
				icon = "content/ui/materials/icons/circumstances/maelstrom_01",
				mission_board_icon = "content/ui/materials/mission_board/circumstances/maelstrom_01",
			},
		}
	end

	add_network_lookup_key(NetworkLookup.circumstance_templates, FACTION_COMBINED_MUTATOR)

	if type(mod.info) == "function" then
		mod:info("SoloPlayMoreHavoc registered Faction Combined: %s", FACTION_COMBINED_MUTATOR)
	end

	return true
end

local function register_old_rotten_armor()
	local old_rotten_armor_composition = {}

	for i = 1, 5 do
		old_rotten_armor_composition[i] = {
			breeds = {
				{
					name = "chaos_ogryn_executor",
					amount = { 2, 8 },
				},
				{
					name = "renegade_executor",
					amount = { 2, 8 },
				},
				{
					name = "renegade_berzerker",
					amount = { 2, 8 },
				},
			},
		}
	end

	if not MutatorTemplates[OLD_ROTTEN_ARMOR_TRICKLE_MUTATOR] then
		MutatorTemplates[OLD_ROTTEN_ARMOR_TRICKLE_MUTATOR] = {
			name = OLD_ROTTEN_ARMOR_TRICKLE_MUTATOR,
			class = "scripts/managers/mutator/mutators/mutator_extra_trickle_hordes",
			trickle_horde_templates = {
				{
					cant_be_ramped = true,
					disallow_spawning_too_close_to_other_spawn = true,
					ignore_disallowance = true,
					min_players_alive = 2,
					not_during_terror_events = false,
					num_trickle_hordes_active_for_cooldown = 2,
					optional_num_tries = 6,
					stinger = "wwise/events/minions/play_mutator_abhuman_spawn_stinger",
					stinger_duration = 8,
					horde_compositions = {
						trickle_horde = {
							renegade = {
								none = { old_rotten_armor_composition },
								low = { old_rotten_armor_composition },
								high = { old_rotten_armor_composition },
								poxwalkers = { old_rotten_armor_composition },
							},
							cultist = {
								none = { old_rotten_armor_composition },
								low = { old_rotten_armor_composition },
								high = { old_rotten_armor_composition },
								poxwalkers = { old_rotten_armor_composition },
							},
						},
					},
					trickle_horde_travel_distance_range = { 110, 230 },
					trickle_horde_cooldown = { 40, 45 },
					optional_main_path_offset = { 30, 70 },
					pause_pacing_on_spawn = {
						{
							hordes = 40,
							roamers = 20,
							specials = 50,
							trickle_hordes = 40,
						},
						{
							hordes = 40,
							specials = 50,
							trickle_hordes = 40,
						},
						{
							trickle_hordes = 20,
						},
						{
							trickle_hordes = 10,
						},
					},
					num_trickle_waves = {
						{ 4, 4 },
						{ 4, 4 },
						{ 4, 4 },
						{ 4, 4 },
						{ 4, 4 },
					},
					time_between_waves = { 15, 25 },
				},
			},
		}
	end

	if not CircumstanceTemplates[OLD_ROTTEN_ARMOR_CIRCUMSTANCE] then
		CircumstanceTemplates[OLD_ROTTEN_ARMOR_CIRCUMSTANCE] = {
			theme_tag = "default",
			mutators = {
				"mutator_rotten_armor",
				OLD_ROTTEN_ARMOR_TRICKLE_MUTATOR,
				"mutator_only_traitor_guard_faction",
			},
			ui = {
				description = "more_old_rotten_armor_description",
				display_name = "more_old_rotten_armor_title",
				happening_display_name = "more_old_rotten_armor_title",
				icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
				mission_board_icon = "content/ui/materials/icons/circumstances/havoc/havoc_mutator_nurgle",
			},
		}
	end

	add_network_lookup_key(NetworkLookup.circumstance_templates, OLD_ROTTEN_ARMOR_CIRCUMSTANCE)

	if type(mod.info) == "function" then
		mod:info("SoloPlayMoreHavoc registered Old Rotten Armor: %s", OLD_ROTTEN_ARMOR_CIRCUMSTANCE)
	end
	OLD_ROTTEN_ARMOR_AVAILABLE = true

	return true
end

local function register_abhuman()
	if not MutatorTemplates[ABHUMAN_REPLACEMENT_MUTATOR] then
		MutatorTemplates[ABHUMAN_REPLACEMENT_MUTATOR] = {
			name = ABHUMAN_REPLACEMENT_MUTATOR,
			class = "scripts/managers/mutator/mutators/mutator_replace_breed",
			init_replacement_breed = {
				breed_replacement = {
					renegade_berzerker = "chaos_ogryn_bulwark",
					renegade_executor = "chaos_ogryn_executor",
					renegade_gunner = "chaos_ogryn_gunner",
				},
			},
		}
	end

	if not MutatorTemplates[ABHUMAN_TRICKLE_MUTATOR] then
		MutatorTemplates[ABHUMAN_TRICKLE_MUTATOR] = {
			name = ABHUMAN_TRICKLE_MUTATOR,
			class = "scripts/managers/mutator/mutators/mutator_extra_trickle_hordes",
			trickle_horde_templates = {
				{
					cant_be_ramped = true,
					disallow_spawning_too_close_to_other_spawn = true,
					ignore_disallowance = true,
					min_players_alive = 2,
					not_during_terror_events = true,
					num_trickle_hordes_active_for_cooldown = 20,
					optional_num_tries = 6,
					stinger = "wwise/events/minions/play_mutator_abhuman_spawn_stinger",
					stinger_duration = 8,
					horde_compositions = {
						trickle_horde = {
							renegade = {
								none = { HordeCompositions.mutator_live_abhuman },
								low = { HordeCompositions.mutator_live_abhuman },
								high = { HordeCompositions.mutator_live_abhuman },
								poxwalkers = { HordeCompositions.mutator_live_abhuman },
							},
							cultist = {
								none = { HordeCompositions.mutator_live_abhuman },
								low = { HordeCompositions.mutator_live_abhuman },
								high = { HordeCompositions.mutator_live_abhuman },
								poxwalkers = { HordeCompositions.mutator_live_abhuman },
							},
						},
					},
					trickle_horde_travel_distance_range = { 110, 230 },
					trickle_horde_cooldown = { 40, 45 },
					optional_main_path_offset = { 30, 70 },
					pause_pacing_on_spawn = {
						{
							hordes = 40,
							roamers = 20,
							specials = 50,
							trickle_hordes = 40,
						},
						{
							hordes = 40,
							roamers = 20,
							specials = 50,
							trickle_hordes = 40,
						},
						{
							hordes = 40,
							specials = 50,
							trickle_hordes = 40,
						},
						{
							trickle_hordes = 20,
						},
						{
							trickle_hordes = 10,
						},
					},
					num_trickle_waves = {
						{ 1, 1 },
						{ 1, 1 },
						{ 1, 2 },
						{ 2, 3 },
						{ 3, 4 },
					},
					time_between_waves = { 15, 25 },
				},
			},
		}
	end

	if not CircumstanceTemplates[ABHUMAN_CIRCUMSTANCE] then
		CircumstanceTemplates[ABHUMAN_CIRCUMSTANCE] = {
			theme_tag = "default",
			mutators = {
				"mutator_only_traitor_guard_faction",
				ABHUMAN_REPLACEMENT_MUTATOR,
				ABHUMAN_TRICKLE_MUTATOR,
			},
			ui = {
				description = "more_havoc_abhuman_description",
				display_name = "more_havoc_abhuman_title",
				happening_display_name = "more_havoc_abhuman_title",
				icon = "content/ui/materials/icons/circumstances/live_event_01",
				mission_board_icon = "content/ui/materials/mission_board/circumstances/live_event_01",
			},
		}
	end

	add_network_lookup_key(NetworkLookup.circumstance_templates, ABHUMAN_CIRCUMSTANCE)

	if type(mod.info) == "function" then
		mod:info("SoloPlayMoreHavoc registered Abhuman: %s", ABHUMAN_CIRCUMSTANCE)
	end
	ABHUMAN_AVAILABLE = true

	return true
end

local function register_elite_army()
	if not CircumstanceTemplates[ELITE_ARMY_CIRCUMSTANCE] then
		CircumstanceTemplates[ELITE_ARMY_CIRCUMSTANCE] = {
			theme_tag = "default",
			mutators = {
				"mutator_no_hordes",
				"mutator_ignore_roamer_limits",
				"mutator_live_elite_army_less_roamers",
				"mutator_only_elite_terror_events",
				"mutator_live_elite_army_replacement",
			},
			ui = {
				description = "more_havoc_elite_army_description",
				display_name = "more_havoc_elite_army_title",
				happening_display_name = "more_havoc_elite_army_title",
				icon = "content/ui/materials/icons/circumstances/live_event_01",
				mission_board_icon = "content/ui/materials/mission_board/circumstances/live_event_01",
			},
		}
	end

	add_network_lookup_key(NetworkLookup.circumstance_templates, ELITE_ARMY_CIRCUMSTANCE)

	if type(mod.info) == "function" then
		mod:info("SoloPlayMoreHavoc registered Elite Army: %s", ELITE_ARMY_CIRCUMSTANCE)
	end
	ELITE_ARMY_AVAILABLE = true

	return true
end

local function register_endless_hordes()
	if not CircumstanceTemplates[ENDLESS_HORDES_CIRCUMSTANCE] then
		CircumstanceTemplates[ENDLESS_HORDES_CIRCUMSTANCE] = {
			theme_tag = "default",
			mutators = {
				"mutator_no_hordes",
				"mutator_live_event_endless_hordes",
			},
			ui = {
				description = "more_havoc_endless_hordes_description",
				display_name = "more_havoc_endless_hordes_title",
				happening_display_name = "more_havoc_endless_hordes_title",
				icon = "content/ui/materials/icons/circumstances/live_event_01",
				mission_board_icon = "content/ui/materials/mission_board/circumstances/live_event_01",
			},
		}
	end

	add_network_lookup_key(NetworkLookup.circumstance_templates, ENDLESS_HORDES_CIRCUMSTANCE)

	if type(mod.info) == "function" then
		mod:info("SoloPlayMoreHavoc registered Endless Hordes: %s", ENDLESS_HORDES_CIRCUMSTANCE)
	end
	ENDLESS_HORDES_AVAILABLE = true

	return true
end

local function register_barrel_grounds()
	if not MutatorTemplates[BARREL_GROUNDS_CIRCUMSTANCE] then
		MutatorTemplates[BARREL_GROUNDS_CIRCUMSTANCE] = {
			name = BARREL_GROUNDS_CIRCUMSTANCE,
			class = "scripts/managers/mutator/mutators/mutator_base",
		}
	end

	if not CircumstanceTemplates[BARREL_GROUNDS_CIRCUMSTANCE] then
		CircumstanceTemplates[BARREL_GROUNDS_CIRCUMSTANCE] = {
			theme_tag = "default",
			mutators = {
				"mutator_extra_shocktrooper",
				"mutator_extra_grenadiers",
				"mutator_poxwalker_bombers",
				"mutator_drop_shocktrooper_grenade_on_death",
				BARREL_GROUNDS_CIRCUMSTANCE,
			},
			mission_overrides = MissionOverrides.all_explosive_barrels,
			ui = {
				description = "more_havoc_barrel_grounds_description",
				display_name = "more_havoc_barrel_grounds_title",
				happening_display_name = "more_havoc_barrel_grounds_title",
				icon = "content/ui/materials/icons/circumstances/live_event_01",
				mission_board_icon = "content/ui/materials/mission_board/circumstances/live_event_01",
			},
		}
	end

	add_network_lookup_key(NetworkLookup.circumstance_templates, BARREL_GROUNDS_CIRCUMSTANCE)

	if type(mod.info) == "function" then
		mod:info("SoloPlayMoreHavoc registered Barrel Grounds: %s", BARREL_GROUNDS_CIRCUMSTANCE)
	end
	BARREL_GROUNDS_AVAILABLE = true

	return true
end

local function inject_faction_switch(context)
	if type(context) ~= "table" or type(context.havoc_data) ~= "string" then
		return context
	end

	if slp_mod:get("havoc_faction") ~= FACTION_SWITCH then
		return context
	end

	local parts = string.split(context.havoc_data, ";")
	if #parts < 8 then
		return context
	end

	parts[4] = "mixed"

	local circumstances = {}
	if parts[5] and parts[5] ~= "" then
		circumstances = string.split(parts[5], ":")
	end

	local has_faction_switch = false
	for _, circumstance_name in ipairs(circumstances) do
		if circumstance_name == FACTION_SWITCH_MUTATOR then
			has_faction_switch = true
			break
		end
	end

	if not has_faction_switch then
		circumstances[#circumstances + 1] = FACTION_SWITCH_MUTATOR
	end

	parts[5] = table.concat(circumstances, ":")
	context.havoc_data = table.concat(parts, ";")

	return context
end

local function inject_faction_combined(context)
	if type(context) ~= "table" or type(context.havoc_data) ~= "string" then
		return context
	end

	if slp_mod:get("havoc_faction") ~= FACTION_COMBINED then
		return context
	end

	local parts = string.split(context.havoc_data, ";")
	if #parts < 8 then
		return context
	end

	parts[4] = "mixed"

	local circumstances = {}
	if parts[5] and parts[5] ~= "" then
		circumstances = string.split(parts[5], ":")
	end

	local has_faction_combined = false
	for _, circumstance_name in ipairs(circumstances) do
		if circumstance_name == FACTION_COMBINED_MUTATOR then
			has_faction_combined = true
			break
		end
	end

	if not has_faction_combined then
		circumstances[#circumstances + 1] = FACTION_COMBINED_MUTATOR
	end

	parts[5] = table.concat(circumstances, ":")
	context.havoc_data = table.concat(parts, ";")

	return context
end

local OLD_ROTTEN_ARMOR_VANILLA_MELEE_DR = {
	0.25,
	0.5,
	0.75,
	1,
	1.25,
}

local OLD_ROTTEN_ARMOR_VANILLA_RANGED_DR = {
	0.25,
	0.5,
	0.75,
	1,
	1.25,
}

local function _set_old_rotten_armor_dr(active)
	for i = 1, 5 do
		local buff = BuffTemplates["havoc_rotten_armor_dr_0" .. i]

		if buff and buff.stat_buffs then
			if active then
				if i <= 2 then
					buff.stat_buffs.ranged_damage_taken_multiplier = 0.25
				else
					buff.stat_buffs.ranged_damage_taken_multiplier = 0.5
				end
				buff.stat_buffs.melee_damage_taken_multiplier = 1
			else
				buff.stat_buffs.ranged_damage_taken_multiplier = OLD_ROTTEN_ARMOR_VANILLA_RANGED_DR[i]
				buff.stat_buffs.melee_damage_taken_multiplier = OLD_ROTTEN_ARMOR_VANILLA_MELEE_DR[i]
			end
		end
	end
end

local function _circumstances_contain_old_rotten_armor(context)
	if type(context) ~= "table" or type(context.havoc_data) ~= "string" then
		return false
	end

	local parts = string.split(context.havoc_data, ";")
	if #parts < 5 then
		return false
	end

	local circumstances = parts[5] and parts[5] ~= "" and string.split(parts[5], ":") or {}

	for _, circumstance_name in ipairs(circumstances) do
		if circumstance_name == OLD_ROTTEN_ARMOR_CIRCUMSTANCE then
			return true
		end
	end

	return false
end

local function unused_legacy_armor_context(context)
	if type(context) ~= "table" or type(context.havoc_data) ~= "string" then
		return context
	end

	if not _circumstances_contain_old_rotten_armor(context) then
		_set_old_rotten_armor_dr(false)
		return context
	end

	local parts = string.split(context.havoc_data, ";")
	local circumstances = parts[5] and parts[5] ~= "" and string.split(parts[5], ":") or {}
	local filtered_circumstances = {}

	for _, circumstance_name in ipairs(circumstances) do
		if circumstance_name ~= VANILLA_ROTTEN_ARMOR_CIRCUMSTANCE then
			filtered_circumstances[#filtered_circumstances + 1] = circumstance_name
		end
	end

	parts[5] = table.concat(filtered_circumstances, ":")
	context.havoc_data = table.concat(parts, ";")

	_set_old_rotten_armor_dr(true)

	return context
end

local function hook_roamer_faction_switch()
	mod:hook(RoamerPacing, "generate_roamers", function (func, self)
		if slp_mod:get("havoc_faction") == FACTION_SWITCH or (Managers.state.mutator and Managers.state.mutator:mutator(FACTION_SWITCH_MUTATOR)) then
			if not self._more_faction_switch_patched then
				local template = table.clone(self._roamer_template)
				template.density_types = table.clone(self._roamer_template.density_types)

				if not table.array_contains(template.density_types, "none") then
					template.density_types[#template.density_types + 1] = "none"
				end

				template.density_order = table.clone(self._roamer_template.density_order)
				template.density_order.high = "none"
				template.density_order.none = template.density_order.none or "low"

				self._roamer_template = template
				self._more_faction_switch_patched = true
			end
		end

		return func(self)
	end)

	mod:hook(RoamerPacing, "update", function (func, self, dt, t, side_id, target_side_id)
		local results = {
			func(self, dt, t, side_id, target_side_id),
		}

		if mod:get("faction_switch_guaranteed") and slp_mod:get("havoc_faction") == FACTION_SWITCH and not self._override_faction then
			local main_path_manager = Managers.state.main_path
			local _, ahead_travel_distance = main_path_manager:ahead_unit(target_side_id)

			if ahead_travel_distance then
				local next_distance = self._more_faction_switch_next_guaranteed_distance

				if not next_distance then
					next_distance = ahead_travel_distance + math.random_range(120, 180)
					self._more_faction_switch_next_guaranteed_distance = next_distance
				end

				if ahead_travel_distance >= next_distance then
					self._current_faction = self._current_faction == "renegade" and "cultist" or "renegade"
					self._more_faction_switch_next_guaranteed_distance = ahead_travel_distance + math.random_range(120, 180)
				end
			end
		end

		return unpack(results, 1, #results)
	end)
end

local function _other_faction_pack_name(pack_name)
	if string.find(pack_name, "renegade_", 1, true) == 1 then
		return "cultist_" .. string.sub(pack_name, 10)
	elseif string.find(pack_name, "cultist_", 1, true) == 1 then
		return "renegade_" .. string.sub(pack_name, 9)
	end

	return nil
end

local function _make_combined_roamer_pack(self, zone)
	local roamer_packs = zone.roamer_packs

	if not roamer_packs or type(roamer_packs) ~= "table" or not roamer_packs.name then
		return
	end

	local other_pack_name = _other_faction_pack_name(roamer_packs.name)
	local other_pack = other_pack_name and RoamerPacks[other_pack_name]

	if not other_pack then
		return
	end

	local combined_name = "more_combined_" .. roamer_packs.name
	self._more_faction_combined_packs = self._more_faction_combined_packs or {}
	local combined_packs = self._more_faction_combined_packs[combined_name]

	if not combined_packs then
		combined_packs = {}

		for _, entry in ipairs(roamer_packs) do
			combined_packs[#combined_packs + 1] = entry
		end

		for _, entry in ipairs(other_pack) do
			combined_packs[#combined_packs + 1] = entry
		end

		combined_packs.name = combined_name

		local weights = {}
		for i = 1, #combined_packs do
			weights[i] = combined_packs[i].weight
		end

		local prob, alias = LoadedDice.create(weights, false)
		self._roamer_pack_probabilities[combined_name] = {
			prob = prob,
			alias = alias,
		}
		self._more_faction_combined_packs[combined_name] = combined_packs
	end

	zone.roamer_packs = combined_packs
end

local function _randomize_zone_faction(self, zone)
	local roamer_packs = zone.roamer_packs

	if not roamer_packs or not roamer_packs.name then
		return
	end

	local other_pack_name = _other_faction_pack_name(roamer_packs.name)
	local other_pack = other_pack_name and RoamerPacks[other_pack_name]

	if not other_pack then
		return
	end

	if math.random() < 0.5 then
		zone.faction = "renegade"

		if string.find(roamer_packs.name, "cultist_", 1, true) == 1 then
			zone.roamer_packs = other_pack
		end
	else
		zone.faction = "cultist"

		if string.find(roamer_packs.name, "renegade_", 1, true) == 1 then
			zone.roamer_packs = other_pack
		end
	end
end

local function _is_faction_combined_active()
	local pacing = Managers.state and Managers.state.pacing
	local roamer = pacing and pacing._roamer_pacing
	if roamer and roamer._override_faction then return false end
	return slp_mod:get("havoc_faction") == FACTION_COMBINED or (Managers.state.mutator and Managers.state.mutator:mutator(FACTION_COMBINED_MUTATOR))
end
local function _is_faction_within_wave_mixed()
	return _is_faction_combined_active() and mod:get("faction_combined_within_wave") == true
end
local function hook_roamer_faction_combined()
	mod:hook(RoamerPacing, "_create_zones", function (func, self, spawn_point_positions)
		local zones = func(self, spawn_point_positions)

		if not self._override_faction and _is_faction_combined_active() then
			if zones then
				for i = 1, #zones do
					local zone = zones[i]

					if zone and zone.roamer_packs then
						if _is_faction_within_wave_mixed() then
							_make_combined_roamer_pack(self, zone)
						else
							_randomize_zone_faction(self, zone)
						end
					end
				end
			end
		end

		return zones
	end)

	mod:hook(RoamerPacing, "current_faction", function (func, self)
		if self._override_faction then return self._override_faction end
		if _is_faction_combined_active() then
			if _is_faction_within_wave_mixed() then
				return math.random() < 0.5 and "renegade" or "cultist"
			end

			local t = Managers.time:time("gameplay")

			if not self._more_faction_combined_wave_until_t or t > self._more_faction_combined_wave_until_t then
				self._more_faction_combined_wave_faction = math.random() < 0.5 and "renegade" or "cultist"
				self._more_faction_combined_wave_until_t = t + math.random_range(1.5, 3)
			end

			return self._more_faction_combined_wave_faction
		end

		return func(self)
	end)
end



local function _merge_horde_compositions(comp_a, comp_b)
	local merged = {}
	local num_entries = math.max(#comp_a, #comp_b)

	for i = 1, num_entries do
		local variant_a = comp_a[i]
		local variant_b = comp_b[i]

		if variant_a and variant_b then
			local merged_variant = {
				breeds = {},
			}

			for _, breed in ipairs(variant_a.breeds) do
				merged_variant.breeds[#merged_variant.breeds + 1] = breed
			end

			for _, breed in ipairs(variant_b.breeds) do
				merged_variant.breeds[#merged_variant.breeds + 1] = breed
			end

			merged[i] = merged_variant
		elseif variant_a then
			merged[i] = variant_a
		else
			merged[i] = variant_b
		end
	end

	merged.name = "more_combined_horde_" .. tostring(comp_a.name or "a") .. "_" .. tostring(comp_b.name or "b")

	return merged
end

local function hook_horde_faction_combined()
	mod:hook(HordePacing, "_setup_next_horde", function (func, self, template, optional_timer_modifier)
		local results = {
			func(self, template, optional_timer_modifier),
		}

		if _is_faction_within_wave_mixed() then
			local current = self._current_compositions

			if current and current.name and string.find(current.name, "more_combined_horde_", 1, true) == nil then
				self._current_compositions = _merge_horde_compositions(current, HordeCompositions.cultist_melee_terror_trickle)
			end
		end

		if mod.scale_native_horde then mod.scale_native_horde(self) end
		return unpack(results, 1, #results)
	end)

	mod:hook(HordePacing, "_spawn_horde_wave", function (func, self, ...)
		local args = {
			...,
		}
		local compositions = args[7]

		if _is_faction_within_wave_mixed() and type(compositions) == "table" and compositions.name and string.find(compositions.name, "more_combined_horde_", 1, true) == nil then
			local other_composition

			if string.find(compositions.name, "renegade_", 1, true) == 1 then
				other_composition = HordeCompositions.cultist_melee_terror_trickle
			elseif string.find(compositions.name, "cultist_", 1, true) == 1 then
				other_composition = HordeCompositions.renegade_medium
			end

			if other_composition then
				args[7] = _merge_horde_compositions(compositions, other_composition)
			end
		end

		return func(self, unpack(args, 1, #args))
	end)

	mod:hook(HordePacing, "_spawn_horde", function (func, self, horde_type, horde_template, composition, ...)
		if _is_faction_within_wave_mixed() and type(composition) == "table" and composition.name and string.find(composition.name, "more_combined_horde_", 1, true) == nil then
			local other_composition

			if string.find(composition.name, "renegade_", 1, true) == 1 then
				other_composition = HordeCompositions.cultist_melee_terror_trickle
			elseif string.find(composition.name, "cultist_", 1, true) == 1 then
				other_composition = HordeCompositions.renegade_medium
			end

			if other_composition then
				composition = _merge_horde_compositions(composition, other_composition)
			end
		end

		return func(self, horde_type, horde_template, composition, ...)
	end)
end

local MONSTER_SPECIALS_SLOT_FLAG = "__more_havoc_monster_specials"
local monster_specialists_units = setmetatable({}, {
	__mode = "k",
})

local function monster_specials_option_enabled(setting_id)
	local enabled = mod:get(setting_id)

	return enabled == true or enabled == 1
end

local function monster_specials_logging_enabled()
	return monster_specials_option_enabled("monster_specials_logging")
end

local function monster_specials_melee_twin_captain_enabled()
	return monster_specials_option_enabled("monster_specials_melee_twin_captain")
end

local function monster_specials_ranged_twin_captain_enabled()
	return monster_specials_option_enabled("monster_specials_ranged_twin_captain")
end

local function monster_specials_houndmaster_enabled()
	return monster_specials_option_enabled("monster_specials_houndmaster")
end

local function get_monster_specials_breed_pool()
	local breeds = {}

	for i = 1, #MONSTER_SPECIALS_CONFIG.breeds do
		breeds[#breeds + 1] = MONSTER_SPECIALS_CONFIG.breeds[i]
	end

	if monster_specials_melee_twin_captain_enabled()
		and Breeds and Breeds[MONSTER_SPECIALS_TWIN_CAPTAIN_MELEE] then
		breeds[#breeds + 1] = MONSTER_SPECIALS_TWIN_CAPTAIN_MELEE
	end

	if monster_specials_ranged_twin_captain_enabled()
		and Breeds and Breeds[MONSTER_SPECIALS_TWIN_CAPTAIN_RANGED] then
		breeds[#breeds + 1] = MONSTER_SPECIALS_TWIN_CAPTAIN_RANGED
	end

	if monster_specials_houndmaster_enabled()
		and Breeds and Breeds[MONSTER_SPECIALS_HOUNDMASTER] then
		breeds[#breeds + 1] = MONSTER_SPECIALS_HOUNDMASTER
	end

	return breeds
end

-- Share the reference preset with the advanced director, including user options.
mod.get_director_monster_specials_config = function ()
	local config = table.clone_instance(MONSTER_SPECIALS_CONFIG)
	config.breeds = get_monster_specials_breed_pool()
	return config
end

mod.is_monster_specialists_unit = function (unit)
	return monster_specialists_units[unit] == true
end

mod.monster_specialists_spawned_callbacks = {}

mod.register_monster_specialists_spawned_callback = function (callback)
	if type(callback) == "function" then
		mod.monster_specialists_spawned_callbacks[#mod.monster_specialists_spawned_callbacks + 1] = callback
	end
end

local function get_monster_specials_state(self)
	local state = self._more_havoc_monster_specials_state

	if not state then
		state = {
			cooldown_until = nil,
			pending_monster = nil,
		}
		self._more_havoc_monster_specials_state = state
	end

	return state
end

local function is_monster_specials_active()
	local mutator_manager = Managers.state and Managers.state.mutator

	if not mutator_manager or type(mutator_manager.mutator) ~= "function" then
		return false
	end

	return mutator_manager:mutator(MONSTER_SPECIALS_MUTATOR) ~= nil
end

local function count_monster_specials_slots(self)
	local specials_slots = self._specials_slots

	if not specials_slots then
		return 0
	end

	local count = 0

	for i = 1, #specials_slots do
		local specials_slot = specials_slots[i]

		if specials_slot and specials_slot[MONSTER_SPECIALS_SLOT_FLAG] then
			count = count + 1
		end
	end

	return count
end

local function check_more_havoc_monster_override(self, template)
	local state = get_monster_specials_state(self)
	local t = Managers.time:time("gameplay")

	if state.cooldown_until then
		if t > state.cooldown_until then
			state.cooldown_until = nil
		else
			return nil
		end
	end

	local specials_slots = self._specials_slots

	if not specials_slots then
		return nil
	end

	local num_monsters = count_monster_specials_slots(self)

	if MONSTER_SPECIALS_CONFIG.max_monsters <= num_monsters then
		if not state.cooldown_until then
			state.cooldown_until = t + math.random_range(
				MONSTER_SPECIALS_CONFIG.max_monster_duration[1],
				MONSTER_SPECIALS_CONFIG.max_monster_duration[2]
			)
		end

		return nil
	end

	local terror_event_active = false

	if Managers.state.terror_event and Managers.state.terror_event.num_active_events
		and Managers.state.terror_event:num_active_events() > 0 then
		terror_event_active = true
	end

	local chance_to_spawn_monster = MONSTER_SPECIALS_CONFIG.chance_to_spawn_monster

	if MONSTER_SPECIALS_CONFIG.chance_to_spawn_monster_event and terror_event_active then
		chance_to_spawn_monster = MONSTER_SPECIALS_CONFIG.chance_to_spawn_monster_event
	end

	if chance_to_spawn_monster < math.random() then
		return nil
	end

	local breeds = get_monster_specials_breed_pool()
	local monster_breed_name = breeds[math.random(1, #breeds)]
	local optional_health_modifier = MONSTER_SPECIALS_CONFIG.health_modifiers
		and MONSTER_SPECIALS_CONFIG.health_modifiers[monster_breed_name]

	if type(mod.info) == "function" and monster_specials_logging_enabled() then
		mod:info("SoloPlayMoreHavoc Monster Specialists replaced a special with %s", monster_breed_name)
	end

	return monster_breed_name, optional_health_modifier
end

local function hide_custom_monster_slots(self)
	local specials_slots = self._specials_slots

	if not specials_slots then
		return nil
	end

	local hidden_breed_names = {}

	for i = 1, #specials_slots do
		local specials_slot = specials_slots[i]

		if specials_slot and specials_slot[MONSTER_SPECIALS_SLOT_FLAG] then
			hidden_breed_names[i] = specials_slot.breed_name
			specials_slot.breed_name = nil
		end
	end

	return hidden_breed_names
end

local function restore_custom_monster_slots(self, hidden_breed_names)
	if not hidden_breed_names then
		return
	end

	local specials_slots = self._specials_slots

	if not specials_slots then
		return
	end

	for i, breed_name in pairs(hidden_breed_names) do
		local specials_slot = specials_slots[i]

		if specials_slot then
			specials_slot.breed_name = breed_name
		end
	end
end

local function hook_monster_specials_override()
	mod:hook("SpecialsPacing", "_check_monster_override", function (func, self, template)
		local state = get_monster_specials_state(self)

		state.pending_monster = nil

		-- The vanilla check counts every monster-tagged special slot. Temporarily
		-- hide our own monster slots so the original Havoc word keeps its own
		-- independent boss cap instead of consuming ours.
		local hidden_breed_names = hide_custom_monster_slots(self)
		local ok, official_breed_name, official_health_modifier = pcall(func, self, template)

		restore_custom_monster_slots(self, hidden_breed_names)

		if not ok then
			error(official_breed_name, 0)
		end

		if official_breed_name then
			return official_breed_name, official_health_modifier
		end

		if not mod.has_local_gameplay_authority() or not is_monster_specials_active() then
			return nil
		end

		local monster_breed_name, optional_health_modifier = check_more_havoc_monster_override(self, template)

		if monster_breed_name then
			state.pending_monster = monster_breed_name

			return monster_breed_name, optional_health_modifier
		end
	end)
end

local function hook_monster_specials_slot_marking()
	mod:hook("SpecialsPacing", "_setup_specials_slot", function (func, self, ...)
		local args = {
			...,
		}
		local specials_slot = args[2]

		if specials_slot then
			specials_slot[MONSTER_SPECIALS_SLOT_FLAG] = nil
		end

		func(self, ...)
		if mod.scale_native_special_slot then mod.scale_native_special_slot(self, args[1], specials_slot) end

		if not mod.has_local_gameplay_authority() or not is_monster_specials_active() then
			return
		end

		local state = get_monster_specials_state(self)

		if state.pending_monster and specials_slot and specials_slot.monster_breed_override then
			-- Mark anything our own override produced. The optional twin captain
			-- breeds are bosses but do not carry the vanilla `monster` tag, so
			-- checking the tag here would break their independent cap/cooldown.
			specials_slot[MONSTER_SPECIALS_SLOT_FLAG] = true
		end

		state.pending_monster = nil
	end)
end

local function hook_monster_specials_unit_tagging()
	mod:hook("SpecialsPacing", "_on_special_spawned", function (func, self, specials_slot, spawned_unit)
		local results = {
			func(self, specials_slot, spawned_unit),
		}

		if specials_slot and specials_slot[MONSTER_SPECIALS_SLOT_FLAG] and spawned_unit then
			monster_specialists_units[spawned_unit] = true

			if type(mod.info) == "function" and monster_specials_logging_enabled() then
				mod:info("SoloPlayMoreHavoc Monster Specialists spawned unit for breed %s", tostring(specials_slot.breed_name))
			end

			for _, callback in ipairs(mod.monster_specialists_spawned_callbacks) do
				pcall(callback, spawned_unit, specials_slot)
			end
		end

		return unpack(results, 1, #results)
	end)
end

local function hook_monster_specials_houndmaster_weakened_name()
	mod:hook(CLASS.HudElementBossHealth, "event_boss_encounter_start", function (func, self, unit, boss_extension)
		local results = {
			func(self, unit, boss_extension),
		}

		if not unit or not monster_specialists_units[unit] or not boss_extension then
			return unpack(results, 1, #results)
		end

		local breed = boss_extension._breed

		if not breed or breed.name ~= MONSTER_SPECIALS_HOUNDMASTER then
			return unpack(results, 1, #results)
		end

		local ok, err = pcall(function ()
			local target = self._active_targets_by_unit and self._active_targets_by_unit[unit]

			if not target then
				return
			end

			local display_name_key = boss_extension:display_name()
			local localized_display_name = display_name_key and Localize(display_name_key)

			if not localized_display_name or localized_display_name == display_name_key then
				localized_display_name = mod:localize("monster_specials_houndmaster") or display_name_key or "Houndmaster"
			end

			local suffix = Localize("more_havoc_monster_specials_weakened_suffix")

			if not suffix or suffix == "more_havoc_monster_specials_weakened_suffix" then
				suffix = mod:localize("ui_027")
			end

			target.localized_display_name = " " .. localized_display_name .. suffix
		end)

		if not ok and type(mod.error) == "function" then
			mod:error("SoloPlayMoreHavoc failed to set the weakened Houndmaster display name: %s", tostring(err))
		end

		return unpack(results, 1, #results)
	end)
end



local function install_barrels()
    mod:hook(HazardPropSystem, "_populate_hazard_props", function(func, self)
        if mod.has_local_gameplay_authority() and Managers.state.mutator:mutator(BARREL_GROUNDS_CIRCUMSTANCE) then
            self._hazard_prop_settings = { explosion = 1, fire = 0, none = 0 }
        elseif mod.get_havoc_hazard_settings then
            local settings = mod.get_havoc_hazard_settings()
            if settings then self._hazard_prop_settings = settings end
        end
        return func(self)
    end)
end
register_nurgle_blessing()
register_monster_specials()
register_assault_force()
register_faction_switch()
register_faction_combined()
register_old_rotten_armor()
register_abhuman()
register_elite_army()
register_endless_hordes()
register_barrel_grounds()
hook_roamer_faction_switch()
hook_roamer_faction_combined()
hook_horde_faction_combined()
hook_monster_specials_override()
hook_monster_specials_slot_marking()
hook_monster_specials_unit_tagging()
hook_monster_specials_houndmaster_weakened_name()
install_barrels()
mod.prepare_reference_conditions = function(context)
    update_nurgle_blessing_chances_for_rank(context)
    _set_old_rotten_armor_dr(_circumstances_contain_old_rotten_armor(context))
    return context
end
