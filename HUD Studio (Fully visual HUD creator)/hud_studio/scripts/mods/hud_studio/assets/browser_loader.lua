---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_browser_loader then
	return mod.hud_studio_browser_loader
end

local MaterialDeps = mod:core(mod.hud_studio_material_deps, "document/material_deps")

---@class BrowserLoader
local BrowserLoader = {}

local REFERENCE = "hud_studio/material_browser"

local SETTLE_SECONDS = 0.1

local RETRY_TIMEOUT_SECONDS = 0.25
local MAX_RETRIES = 20

local function now()
	return os.clock()
end

local held = {}

local pinned = {}

local function do_release(pm, entry)
	if entry.id ~= nil and type(entry.id) ~= "boolean" then
		pcall(pm.release, pm, entry.id)
	end
end

function BrowserLoader.release_all()
	local pm = Managers.package
	for path, entry in pairs(held) do
		if MaterialDeps.is_self_package(path) or pinned[path] then

		elseif not pm then
			held[path] = nil
		elseif entry.loaded then
			do_release(pm, entry)
			held[path] = nil
		else
			entry.want_release = true
		end
	end
end

local function start_load(pm, path, retries)
	local entry = { loaded = false, want_release = false, started_at = now(), retries = retries or 0 }
	held[path] = entry
	local ok, id = pcall(pm.load, pm, path, REFERENCE, function()
		entry.loaded = true
		entry.loaded_at = now()
		if entry.want_release then
			local pm2 = Managers.package
			if pm2 then
				do_release(pm2, entry)
			end

			if held[path] == entry then
				held[path] = nil
			end
		end
	end)
	if ok then
		entry.id = id

		local hok, has = pcall(pm.has_loaded, pm, path)
		if hok and has then
			entry.loaded = true
			entry.loaded_at = now()
		end
	else
		held[path] = nil
	end
end

---@param materials string[]
function BrowserLoader.load_set(materials)
	local pm = Managers.package
	if not pm then
		BrowserLoader.release_all()
		return
	end

	local paths = MaterialDeps.covering_packages(materials or {})
	local want = {}
	for i = 1, #paths do
		want[paths[i]] = true
	end

	for path, entry in pairs(held) do
		if want[path] or MaterialDeps.is_self_package(path) or pinned[path] then
			entry.want_release = false
		elseif entry.loaded then
			do_release(pm, entry)
			held[path] = nil
		else
			entry.want_release = true
		end
	end

	for i = 1, #paths do
		local path = paths[i]
		if not held[path] then
			start_load(pm, path)
		end
	end
end

function BrowserLoader.pump()
	local pm = Managers.package
	if not pm then
		return
	end
	local t = now()
	for path, entry in pairs(held) do
		if
			not entry.loaded
			and not entry.want_release
			and entry.retries < MAX_RETRIES
			and (t - entry.started_at) >= RETRY_TIMEOUT_SECONDS
		then

			entry.want_release = true
			start_load(pm, path, entry.retries + 1)
		end
	end
end

---@param material string
---@return boolean
function BrowserLoader.is_available(material)
	if type(material) ~= "string" or material == "" then
		return false
	end
	local paths = MaterialDeps.packages_for(material)
	if not paths then
		return false
	end
	local t = now()

	for i = 1, #paths do
		local entry = held[paths[i]]
		if entry and entry.loaded and entry.loaded_at and (t - entry.loaded_at) >= SETTLE_SECONDS then
			return true
		end
	end
	return false
end

---@param material string
function BrowserLoader.pin_material(material)
	if type(material) ~= "string" or material == "" then
		return
	end
	local paths = MaterialDeps.packages_for(material)
	if not paths then
		return
	end
	for i = 1, #paths do
		local path = paths[i]
		local entry = held[path]
		if entry then
			pinned[path] = true

			entry.want_release = false
		end
	end
end

mod.hud_studio_browser_loader = BrowserLoader

return BrowserLoader
