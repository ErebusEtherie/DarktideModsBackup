---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_source_localize then
	return mod.hud_studio_source_localize
end

local Localize = {}

---@type table<string, string|false>
local cache = {}

local cache_language = nil

local language_checked_at = -math.huge
local LANGUAGE_RECHECK_SECONDS = 1

---@return string | nil
local function current_language()
	local managers = rawget(_G, "Managers")
	local localization = managers and managers.localization or nil
	if not localization or not localization.language then
		return nil
	end
	local ok, language = pcall(localization.language, localization)
	return ok and language or nil
end

---@param id string | nil
---@return string | nil
function Localize.game(id)
	if type(id) ~= "string" or id == "" then
		return nil
	end

	local time = os.clock()
	if time - language_checked_at >= LANGUAGE_RECHECK_SECONDS then
		language_checked_at = time
		local language = current_language()
		if language ~= cache_language then
			cache_language = language
			cache = {}
		end
	end

	local cached = cache[id]
	if cached ~= nil then
		return cached or nil
	end

	local _G = _G
	local value = nil
	local managers = rawget(_G, "Managers")

	if _G.Localize then
		value = _G.Localize(id)
	elseif managers and managers.localization then
		value = managers.localization:localize(id)
	end

	if type(value) ~= "string" or value == "" then
		cache[id] = false
		return nil
	end

	if string.byte(value) == 60 and (value == ("<" .. id .. ">") or string.find(value, '<unlocalized "', 1, true) == 1) then
		cache[id] = false
		return nil
	end

	cache[id] = value
	return value
end

mod.hud_studio_source_localize = Localize
return Localize
