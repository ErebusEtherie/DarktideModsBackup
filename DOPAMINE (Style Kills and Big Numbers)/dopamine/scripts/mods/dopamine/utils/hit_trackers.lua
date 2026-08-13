---@type mod
local mod = get_mod("dopamine")

if mod.hit_trackers then
	return mod.hit_trackers
end

local UnitHitTracker = mod:lib(mod.unit_hit_tracker, "lib/unit_hit_tracker")
local EventEnums = mod:core(mod.event_enums, "utils/event/enums")

---@class HitTrackers
local HitTrackers = {
	Berserk = UnitHitTracker.shared(EventEnums.EVENT_ID.berserk, { threshold = 4 }),
	MagDump = UnitHitTracker.shared(EventEnums.EVENT_ID.mag_dump, { threshold = 4 }),
}

function HitTrackers.reset_all()
	HitTrackers.Berserk:reset()
	HitTrackers.MagDump:reset()
end

mod.hit_trackers = HitTrackers

return mod.hit_trackers
