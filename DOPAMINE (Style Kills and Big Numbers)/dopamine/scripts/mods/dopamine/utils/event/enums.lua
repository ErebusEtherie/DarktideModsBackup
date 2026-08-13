---@type mod
local mod = get_mod("dopamine")

if mod.event_enums then
	return mod.event_enums
end

---@enum EventID
local EVENT_ID = {
	generic_headshot = "generic_headshot",
	headshot = "headshot",
	close_headshot = "close_headshot",
	far_headshot = "far_headshot",
	ranged_in_melee = "ranged_in_melee",
	flow = "flow",
	berserk = "berserk",
	mag_dump = "mag_dump",
	multi_kill = "multi_kill",
	generic_kill = "generic_kill",
	kill = "kill",
	melee_kill = "melee_kill",
	ranged_kill = "ranged_kill",
	elite_kill = "elite_kill",
	boss_kill = "boss_kill",
	slide_kill = "slide_kill",
	dodge = "dodge",

	parry = "parry",

	perfect_block = "perfect_block",
	combo_finish = "combo_finish",
	disabler_kill = "disabler_kill",
	objective_time = "objective_time",

	crusher_kill_flavor = "crusher_kill_flavor",
	pox_burster_kill_flavor = "pox_burster_kill_flavor",

	horde_kill = "horde_kill",
	pox_burster_kill = "pox_burster_kill",
	bulwark_kill = "bulwark_kill",
	crusher_kill = "crusher_kill",
	mauler_kill = "mauler_kill",
	rager_kill = "rager_kill",
	flamer_kill = "flamer_kill",
	bomber_kill = "bomber_kill",
	shotgunner_kill = "shotgunner_kill",
	sniper_kill = "sniper_kill",
	gunner_kill = "gunner_kill",
	hound_kill = "hound_kill",
	trapper_kill = "trapper_kill",
	mutant_kill = "mutant_kill",
}

---@enum SignalID
local SIGNAL_ID = {
	kill = "kill",
	dodge = "dodge",
	parry = "parry",
	perfect_block = "perfect_block",
	berserk = "berserk",
	mag_dump = "mag_dump",
}

---@enum SpPhase
local SP_PHASE = {
	rise = "rise",
	hold = "hold",
	wait = "wait",
	out = "out",
	recap = "recap",
}
---@enum SpComboPhase
local SP_COMBO_PHASE = {
	rise = "rise",
	combo = "combo",
	recap = "recap",
	wait = "wait",
	out = "out",
}

---@enum EventPhase
local EVENT_PHASE = {
	exit_evict = "exit_evict",
	active = "active",
	exit_expire = "exit_expire",
}

---@class EventEnums
local EventEnums = {
	EVENT_ID = EVENT_ID,
	SIGNAL_ID = SIGNAL_ID,
	SP_PHASE = SP_PHASE,
	EVENT_PHASE = EVENT_PHASE,
	SP_COMBO_PHASE = SP_COMBO_PHASE,
}

mod.event_enums = EventEnums

return mod.event_enums
