

---@type mod
local mod = get_mod("dopamine")

if mod.breed_fatigue_relief then
	return mod.breed_fatigue_relief
end

local ComboState = mod:core(mod.combo_state, "utils/combo_state")

local BREED_OVERRIDES = {}

---@type table<UseBreedsBreedCategory, table<"fatigue" | "ramp", string>>
local CATEGORY_SETTING_KEYS = {
	elite = { fatigue = "breed_relief_elite_fatigue", ramp = "breed_relief_elite_ramp" },
	special = { fatigue = "breed_relief_special_fatigue", ramp = "breed_relief_special_ramp" },
}

---@class BreedFatigueRelief
local BreedFatigueRelief = {}

---@param category UseBreedsBreedCategory | nil
local function category_relief(category)
	local relief = {
		fatigue = 0,
		ramp_seconds = 0,
	}

	if not category then
		return relief
	end

	local keys = CATEGORY_SETTING_KEYS[category]

	if not keys then
		return nil
	end

	relief.fatigue = mod.dl.settings[keys.fatigue]
	relief.ramp = mod.dl.settings[keys.ramp]

	if (not relief.fatigue or relief.fatigue <= 0) and (not relief.ramp or relief.ramp <= 0) then
		return nil
	end

	return relief
end

---@param breed_data FatsharkBreedData
function BreedFatigueRelief.lookup(breed_data)
	if not breed_data then
		return nil
	end

	local id = mod.dl.breeds.id(breed_data)
	if id and BREED_OVERRIDES[id] then
		return BREED_OVERRIDES[id]
	end

	return category_relief(mod.dl.breeds.breed_category(breed_data))
end

---@param breed_data FatsharkBreedData
function BreedFatigueRelief.apply(breed_data)
	local relief = BreedFatigueRelief.lookup(breed_data)

	if not relief then
		return
	end

	ComboState.apply_fatigue_relief(relief.fatigue, relief.ramp_seconds)
end

mod.breed_fatigue_relief = BreedFatigueRelief

return BreedFatigueRelief
