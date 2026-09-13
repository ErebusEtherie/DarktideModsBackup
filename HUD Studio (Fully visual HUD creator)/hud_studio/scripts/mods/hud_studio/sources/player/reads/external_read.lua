---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_external_read then
	return mod.hud_studio_player_external_read
end

local LABEL_COLOR = { 255, 239, 202, 121 }

---@class ExternalHandle
---@field id string             the other mod's DMF id
---@field requires string[]     functions we call on it; a missing one means its API moved
---@field refresh_seconds number
---@field cache table<any, {stamp: any, text: string?, expires_at: number}>  owned here, one entry per key

---@class ExternalRead
local External = {}

---@param other DMFMod | string
---@param message string
---@return string
function External.notice(other, message)
	local name = type(other) == "string" and other

	if type(other) == "table" and other.localize and other.get_internal_data then
		name = other:get_internal_data("readable_name") or other:get_internal_data("name") or other:localize("mod_name")
	end

	return "! " .. mod.dl.str.rich_text(name, { color = LABEL_COLOR }) .. " " .. message .. " !"
end

local _error_not_installed = mod:localize("error_mod_is_not_installed")
local _error_mod_is_not_enabled = mod:localize("error_mod_is_not_enabled")
local _error_mod_api_has_changed = mod:localize("error_mod_api_has_changed")

---@param handle ExternalHandle
---@param build function
---@return string | nil
local function rebuild(handle, build, a, b, c)
	local other = get_mod(handle.id)

	if not other then
		return External.notice(handle.id, _error_not_installed)
	end

	if other.is_enabled and not other:is_enabled() then
		return External.notice(other, _error_mod_is_not_enabled)
	end

	local requires = handle.requires
	for i = 1, #requires do
		if type(other[requires[i]]) ~= "function" then
			return External.notice(other, _error_mod_api_has_changed)
		end
	end

	local ok, text = pcall(build, other, a, b, c)
	return (ok and type(text) == "string") and text or nil
end

---@param handle ExternalHandle
---@param key any        what the result is cached per, normally a character_id
---@param stamp any
---@param time_now number
---@param build fun(other_mod: table, a: any, b: any, c: any): string|nil
---@return string | nil
function External.read(handle, key, stamp, time_now, build, a, b, c)
	local cache = handle.cache
	local entry = cache[key]

	if not entry then
		entry = {
			stamp = stamp,
			text = rebuild(handle, build, a, b, c),
			expires_at = time_now + handle.refresh_seconds,
		}
		cache[key] = entry
	elseif entry.stamp ~= stamp or time_now >= entry.expires_at then
		entry.stamp = stamp
		entry.text = rebuild(handle, build, a, b, c)
		entry.expires_at = time_now + handle.refresh_seconds
	end

	return entry.text
end

mod.hud_studio_player_external_read = External
return External
