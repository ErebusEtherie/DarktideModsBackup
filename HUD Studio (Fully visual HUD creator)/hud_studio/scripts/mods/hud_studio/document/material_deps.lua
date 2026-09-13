---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_material_deps then
	return mod.hud_studio_material_deps
end

local DATA = mod:io_dofile("hud_studio/scripts/mods/hud_studio/assets/material_packages")
local PACKAGES = DATA.packages 
local MATERIALS = DATA.materials

local TEXTURE_PREFIX = "/textures/"
local textures_merged = false

local function merge_textures()
	textures_merged = true
	local data = mod:io_dofile("hud_studio/scripts/mods/hud_studio/assets/texture_packages")
	local offset = #PACKAGES
	local texture_packages = data.packages
	for i = 1, #texture_packages do
		PACKAGES[offset + i] = texture_packages[i]
	end

	local shifted_by_list = {}
	for path, ids in pairs(data.textures) do

		if not MATERIALS[path] then
			local shifted = shifted_by_list[ids]
			if not shifted then
				shifted = {}
				for i = 1, #ids do
					shifted[i] = ids[i] + offset
				end
				shifted_by_list[ids] = shifted
			end
			MATERIALS[path] = shifted
		end
	end
end

---@param material any
---@return integer[]|nil
local function ids_for(material)
	local ids = MATERIALS[material]
	if ids then
		return ids
	end
	if not textures_merged and type(material) == "string" and material:find(TEXTURE_PREFIX, 1, true) then
		merge_textures()
		return MATERIALS[material]
	end
	return nil
end

local REFERENCE = "hud_studio/material_deps"

local SETTLE_SECONDS = 0.25

local function now()
	return os.clock()
end

---@class MaterialDeps
local MaterialDeps = {}

local pkg_state = {}

local package_manager_ref = nil

local needed = {}

local covered = {}

local unmapped = {}

local function pkg_has(path, material)
	local ids = ids_for(material)
	if not ids then
		return false
	end
	for i = 1, #ids do
		if PACKAGES[ids[i]] == path then
			return true
		end
	end
	return false
end

local function load_package(path)
	if not path or path == "" or pkg_state[path] then
		return
	end
	local pm = Managers.package
	if not pm then
		return
	end

	local already = false
	pcall(function()
		already = pm:has_loaded(path)
	end)

	package_manager_ref = pm

	local state = { ready = already, ready_at = already and now() or nil }
	pkg_state[path] = state
	local ok, id = pcall(pm.load, pm, path, REFERENCE, function()
		state.ready = true
		state.ready_at = now()
	end, true)
	if ok then
		state.id = id
	else

		state.failed = true
		mod.dl.log.error("material_deps: could not load package '%s'", tostring(path))
	end
end

---@param material string
---@return "ready"|"loading"|"unmapped"|"unknown"
function MaterialDeps.require(material)

	if type(material) ~= "string" or material == "" then
		return "unknown"
	end
	needed[material] = true
	if covered[material] or unmapped[material] then
		return MaterialDeps.status(material)
	end

	local ids = ids_for(material)
	if not ids or #ids == 0 then
		unmapped[material] = true
		return "unmapped"
	end

	local best, best_score = nil, -1
	for i = 1, #ids do
		local path = PACKAGES[ids[i]]
		local score
		if pkg_state[path] then
			score = math.huge 
		else
			score = 0
			for m in pairs(needed) do
				if not covered[m] and pkg_has(path, m) then
					score = score + 1
				end
			end
		end
		if score > best_score then
			best_score = score
			best = path
		end
	end

	for m in pairs(needed) do
		if not covered[m] and pkg_has(best, m) then
			covered[m] = best
		end
	end
	load_package(best)

	return MaterialDeps.status(material)
end

---@param materials string[]
function MaterialDeps.require_all(materials)
	local pending = {}
	for i = 1, #materials do
		local m = materials[i]
		if type(m) == "string" and m ~= "" then
			needed[m] = true
			if not covered[m] and not unmapped[m] then
				local ids = ids_for(m)
				if not ids or #ids == 0 then
					unmapped[m] = true
				else
					pending[m] = true
				end
			end
		end
	end

	while next(pending) do
		local best, best_score, seen = nil, 0, {}
		for m in pairs(pending) do
			local ids = ids_for(m)
			for i = 1, #ids do
				local path = PACKAGES[ids[i]]
				if not seen[path] then
					seen[path] = true
					local score = 0
					for mm in pairs(pending) do
						if pkg_has(path, mm) then
							score = score + 1
						end
					end
					if score > best_score then
						best_score = score
						best = path
					end
				end
			end
		end
		if not best then
			break
		end
		for m in pairs(pending) do
			if pkg_has(best, m) then
				covered[m] = best
				pending[m] = nil
			end
		end
		load_package(best)
	end
end

---@return integer forgotten
function MaterialDeps.revalidate()
	local pm = Managers and Managers.package or nil
	local manager_changed = pm ~= package_manager_ref
	package_manager_ref = pm

	local forgotten = 0
	for path in pairs(pkg_state) do
		local resident = false
		if pm and not manager_changed then
			pcall(function()
				resident = pm:has_loaded(path)
			end)
		end
		if not resident then
			pkg_state[path] = nil
			forgotten = forgotten + 1
		end
	end

	if forgotten > 0 then

		for material, path in pairs(covered) do
			if not pkg_state[path] then
				covered[material] = nil
			end
		end
	end

	return forgotten
end

local function settled(st)
	return st ~= nil and st.ready == true and st.ready_at ~= nil and (now() - st.ready_at) >= SETTLE_SECONDS
end

---@param material string
---@return boolean
function MaterialDeps.is_ready(material)
	local path = covered[material]
	if not path then
		return false
	end
	return settled(pkg_state[path])
end

---@param material string
---@return "ready"|"loading"|"unmapped"|"unknown"
function MaterialDeps.status(material)
	if unmapped[material] then
		return "unmapped"
	end
	local path = covered[material]
	if not path then
		return "unknown"
	end
	local st = pkg_state[path]
	if settled(st) then
		return "ready"
	end
	if st and st.failed then
		return "unmapped"
	end
	return "loading"
end

---@param material string
---@return boolean
function MaterialDeps.ready_to_draw(material)
	if MaterialDeps.is_ready(material) then
		return true
	end
	return MaterialDeps.require(material) == "ready"
end

---@param materials string[]
---@return string[] package_paths
function MaterialDeps.covering_packages(materials)
	local pending = {}
	for i = 1, #materials do
		local m = materials[i]
		if type(m) == "string" then
			local ids = ids_for(m)
			if ids and #ids > 0 then
				pending[m] = true
			end
		end
	end

	local chosen = {}
	while next(pending) do
		local best, best_score, seen = nil, 0, {}
		for m in pairs(pending) do
			local ids = ids_for(m)
			for i = 1, #ids do
				local path = PACKAGES[ids[i]]
				if not seen[path] then
					seen[path] = true
					local score = 0
					for mm in pairs(pending) do
						if pkg_has(path, mm) then
							score = score + 1
						end
					end
					if score > best_score then
						best_score = score
						best = path
					end
				end
			end
		end
		if not best then
			break
		end
		chosen[#chosen + 1] = best
		for m in pairs(pending) do
			if pkg_has(best, m) then
				pending[m] = nil
			end
		end
	end
	return chosen
end

---@param path string a package path
---@return boolean
function MaterialDeps.is_self_package(path)
	return type(path) == "string" and MATERIALS[path] ~= nil
end

---@param material string
---@return string[]|nil
function MaterialDeps.packages_for(material)
	local ids = ids_for(material)
	if not ids then
		return nil
	end
	local out = {}
	for i = 1, #ids do
		out[i] = PACKAGES[ids[i]]
	end
	return out
end

mod.hud_studio_material_deps = MaterialDeps

return MaterialDeps
