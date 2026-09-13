---@class mod : DMFMod
local mod = get_mod("hud_studio")

local _io = Mods.lua.io
local _os = Mods.lua.os
local _loadstring = Mods.lua.loadstring

local REFERENCE = "hud_studio"

---@class UserLoc
local UserLoc = {}

---@return string
local function blocks_dir()
	return _os.getenv("APPDATA") .. "/Fatshark/Darktide/" .. REFERENCE .. "/blocks/"
end

---@param path string
---@param chunk_name string
---@return table?
local function read_table(path, chunk_name)
	local f = _io.open(path, "r")
	if not f then
		return nil
	end
	local text = f:read("*all")
	f:close()

	local chunk = text and _loadstring(text, chunk_name)
	if not chunk then
		return nil
	end
	local ok, value = pcall(chunk)
	if ok and type(value) == "table" then
		return value
	end
	return nil
end

---@return table? strings   namespaced loc-key -> { en = "...", ... }
function UserLoc.read()
	local index = read_table(blocks_dir() .. "index.lua", "hud_studio_index")
	if not index or type(index.blocks) ~= "table" then
		return nil
	end

	local out = {}
	local any = false
	for i = 1, #index.blocks do
		local name = index.blocks[i]
		if type(name) == "string" then
			local block = read_table(blocks_dir() .. name .. ".lua", "hud_studio_block:" .. name)
			local loc = block and block.localizations
			if type(loc) == "table" then
				for key, entry in pairs(loc) do
					out[name .. "." .. key] = entry
					any = true
				end
			end
		end
	end

	if not any then
		return nil
	end
	return out
end

---@param block_name string
---@param key string
---@return string
function UserLoc.key(block_name, key)
	return block_name .. "." .. key
end

mod.hud_studio_user_loc = UserLoc

return UserLoc
