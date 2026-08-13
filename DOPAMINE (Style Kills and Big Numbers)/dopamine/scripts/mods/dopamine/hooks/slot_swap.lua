

---@type mod
local mod = get_mod("dopamine")

if mod.slot_swap then
	return mod.slot_swap
end

local SLOT_DEFAULTS = {
	slot_left = "fury",
	slot_left_2 = "score",
	slot_left_3 = "none",
	slot_left_4 = "none",
	slot_center = "none",
	slot_right_1 = "stats",
	slot_right_2 = "objective",
	slot_right_3 = "none",
	slot_right_4 = "none",
}
local SLOTS = {
	"slot_left",
	"slot_left_2",
	"slot_left_3",
	"slot_left_4",
	"slot_center",
	"slot_right_1",
	"slot_right_2",
	"slot_right_3",
	"slot_right_4",
}

local function is_slot(setting_id)
	return SLOT_DEFAULTS[setting_id] ~= nil
end

local function slot_value(setting_id)
	local value = mod:get(setting_id)
	if value == nil or value == "" then
		return SLOT_DEFAULTS[setting_id]
	end
	return value
end

local cache = nil

local function ensure_cache()
	if cache then
		return
	end
	cache = {}
	for i = 1, #SLOTS do
		cache[SLOTS[i]] = slot_value(SLOTS[i])
	end
end

local swapping = false

local function on_setting_changed(setting_id)
	if swapping or not is_slot(setting_id) then
		return
	end

	ensure_cache()

	local new_value = slot_value(setting_id)
	local prev_value = cache[setting_id]
	cache[setting_id] = new_value

	if new_value == prev_value or new_value == "none" then
		return
	end

	for i = 1, #SLOTS do
		local other = SLOTS[i]
		if other ~= setting_id and cache[other] == new_value then
			local displaced = prev_value

			if other == "slot_center" and displaced ~= "fury" then
				displaced = "none"
			end
			swapping = true
			mod:set(other, displaced, true)
			cache[other] = displaced
			swapping = false
			break
		end
	end
end

mod.dl.settings.hook_settings_changed(on_setting_changed)

ensure_cache()

local SlotSwap = {}

mod.slot_swap = SlotSwap

return SlotSwap
