

---@type mod
local mod = get_mod("dopamine")

if mod.event_scoring then
	return mod.event_scoring
end

local Thresholds = mod:lib(mod.thresholds, "lib/thresholds")
local ScoringConstants = mod:core(mod.scoring_constants, "utils/scoring/constants")

---@param scoring_entry ScoringEntry | nil
---@return ScoringEntry
local function to_scoring_entry(scoring_entry)
	return scoring_entry and type(scoring_entry) == "table" and scoring_entry or { cashout = 0, trigger = 0 }
end

---@param event_id EventID | nil
---@return ScoringEntry
local function event_sp_values(event_id)
	if not event_id then
		return to_scoring_entry()
	end
	return to_scoring_entry(ScoringConstants.EVENTS[event_id])
end

---@param breed_taxonomy UseBreedsBreedTaxonomy | nil
---@return ScoringEntry
local function breed_sp_values(breed_taxonomy)
	if not breed_taxonomy then
		return to_scoring_entry()
	end
	---@type ScoringEntry
	local per_category = ScoringConstants.BREED_CATEGORY[breed_taxonomy.category]
		or ScoringConstants.BREED_CATEGORY.default
		or to_scoring_entry()
	---@type ScoringEntry
	local per_breed = ScoringConstants.BREED_GROUP[breed_taxonomy.group]
		or ScoringConstants.BREED_CATEGORY.default
		or to_scoring_entry()
	---@type ScoringEntry
	local total =
		{ cashout = per_category.cashout + per_breed.cashout, trigger = per_category.trigger + per_breed.trigger }
	return total
end

---@class EventScoring
local EventScoring = {}

---@param kill_count number|nil
---@return number multiplier
function EventScoring.finish_combo_mult(kill_count)
	return Thresholds.pick(kill_count, ScoringConstants.COMBO_FINISH_MULT, "kills", "mult", 1)
end

---@param fury number|nil
---@return number bonus
function EventScoring.fury_mult_bonus(fury)
	return Thresholds.pick(fury, ScoringConstants.FURY_MULT, "fury", "add", 0)
end

---@param event_id EventID
---@param count number -- current count (reserved for count-scaled triggers)
---@param context EventContext|nil
---@return number sp
function EventScoring.sp_trigger(event_id, count, context)
	local breed_sp = breed_sp_values(context and context.breed_taxonomy or nil)
	local event_sp = event_sp_values(event_id)

	return breed_sp.trigger + event_sp.trigger
end

---@param event_id EventID
---@param count number
---@param context EventContext|nil
---@return number sp
function EventScoring.sp_cashout(event_id, count, context)
	local breed_sp = breed_sp_values(context and context.breed_taxonomy or nil)
	local event_sp = event_sp_values(event_id)

	return (breed_sp.cashout + event_sp.cashout) * (count or 1)
end

---@param combo_sp_earned number|nil
---@param kill_count number|nil
---@return number sp_bonus
function EventScoring.sp_combo_finish(combo_sp_earned, kill_count)
	return math.floor((combo_sp_earned or 0) * EventScoring.finish_combo_mult(kill_count))
end

---@param kill_count number|nil
---@return number multiplier
function EventScoring.combo_finish_multiplier(kill_count)
	return EventScoring.finish_combo_mult(kill_count)
end

---@param amount number|nil
---@return string|nil
function EventScoring.format_marker_amount(amount)
	amount = math.floor(amount or 0)
	if amount <= 0 then
		return nil
	end

	return "+" .. tostring(amount)
end

---@param multiplier number|nil
---@return string|nil
function EventScoring.format_marker_multiplier(multiplier)
	multiplier = multiplier or 1
	if multiplier <= 1.001 then
		return nil
	end

	return "×" .. string.format("%.2f", multiplier)
end

mod.event_scoring = EventScoring

return EventScoring
