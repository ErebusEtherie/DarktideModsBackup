

local mod = get_mod("dopamine")

---@class ScoringEntry
---@field trigger number
---@field cashout number

---@class FuryMultEntry
---@field fury number
---@field add number

---@class ComboFinishMultEntry
---@field kills number
---@field mult number

---@class ScoringConstants
---@field BREED_CATEGORY table<UseBreedsBreedCategory | "default", ScoringEntry>
---@field BREED_GROUP table<UseBreedsBreedGroup | "default", ScoringEntry>
---@field EVENTS table<EventID, ScoringEntry>
---@field FURY_MULT FuryMultEntry[]
---@field COMBO_FINISH_MULT ComboFinishMultEntry[]
---@field BOSS_KILL_MULT { add: number, duration: number }
---@field BOSS_KILL_CONTRIBUTION number
local ScoringConstants = {

	BREED_CATEGORY = {
		boss = { trigger = 125, cashout = 0 },
		disabler = { trigger = 500, cashout = 100 },
	},

	BREED_GROUP = {

		default = { trigger = 0, cashout = 0 },
		melee_horde = { trigger = 0, cashout = 0 },

		melee_bruiser = { trigger = 15, cashout = 15 },
		shooters = { trigger = 20, cashout = 0 },

		shotgunners = { trigger = 150, cashout = 20 },
		gunners = { trigger = 200, cashout = 20 },
		ragers = { trigger = 250, cashout = 20 },
		flamers = { trigger = 250, cashout = 20 },

		melee_shield = { trigger = 250, cashout = 50 },

		bombers = { trigger = 500, cashout = 100 },
		snipers = { trigger = 500, cashout = 100 },
		melee_carapace = { trigger = 750, cashout = 100 },
	},

	EVENTS = {

		close_headshot = { trigger = 15, cashout = 0 },
		far_headshot = { trigger = 25, cashout = 5 },
		ranged_in_melee = { trigger = 5, cashout = 5 },
		flow = { trigger = 150, cashout = 10 },
		berserk = { trigger = 5, cashout = 1 },
		mag_dump = { trigger = 5, cashout = 1 },
		multi_kill = { trigger = 5, cashout = 0 },
		kill = { trigger = 25, cashout = 0 }, 
		melee_kill = { trigger = 10, cashout = 0 },
		ranged_kill = { trigger = 25, cashout = 1 },
		slide_kill = { trigger = 100, cashout = 15 },
		dodge = { trigger = 75, cashout = 10 },

		parry = { trigger = 100, cashout = 100 },
		perfect_block = { trigger = 15, cashout = 0 },
		combo_finish = { trigger = 0, cashout = 0 },

		objective_time = { trigger = 25, cashout = 25 },
	},

	FURY_MULT = {
		{ fury = 20, add = 0.05 },
		{ fury = 40, add = 0.1 },
		{ fury = 60, add = 0.15 },
		{ fury = 80, add = 0.25 },
		{ fury = 100, add = 0.5 },
		{ fury = 133, add = 0.75 },
		{ fury = 166, add = 1 },
		{ fury = 200, add = 1.25 },
	},

	OBJECTIVE_COMPLETE_MULT = {
		add = 1.5,
		duration = 30,
	},

	BOSS_KILL_MULT = {
		add = 2.5,
		duration = 15,
	},

	BOSS_KILL_CONTRIBUTION = 0.2,

	OBJECTIVE_INTERACTION_REWARD = {
		default = { kind = "mult" },
		scanning = { kind = "sp", sp = 50000 },
		setup_decoding = { kind = "sp", sp = 25000 },
		setup_breach_charge = { kind = "sp", sp = 25000 },
	},

	OBJECTIVE_DESTRUCTIBLE_REWARD = { kind = "sp", sp = 15000 },

	TEAMMATE_RESCUE_REWARD = {
		revive = { kind = "mult", add = 1, duration = 15 },
		rescue = { kind = "sp", sp = 50000 },
		remove_net = { kind = "mult", add = 0.5, duration = 7.5 },
	},

	COMBO_FINISH_MULT = {
		{ kills = 10, mult = 1 },
		{ kills = 30, mult = 1 },
		{ kills = 50, mult = 1.25 },
		{ kills = 75, mult = 1.5 },
		{ kills = 125, mult = 1.75 },
		{ kills = 200, mult = 2 },
	},
}

mod.scoring_constants = ScoringConstants

return mod.scoring_constants
