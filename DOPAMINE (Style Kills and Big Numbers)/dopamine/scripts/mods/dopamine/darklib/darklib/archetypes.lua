

---@class DarkLib
---@field archetypes DL_Archetypes

---@param mod mod
return function(mod)

	---@alias DL_ArchetypeId "veteran" | "zealot" | "psyker" | "ogryn" | "adamant" | "cryptic" | "broker"

	---@alias DL_ArchetypeSuffix "veteran" | "zealot" | "psyker" | "ogryn" | "arbites" | "skitarii" | "broker"

	---@class DL_ArchetypeRecord
	---@field id DL_ArchetypeId
	---@field suffix DL_ArchetypeSuffix
	---@field aliases? string[] Alternate names that also resolve to this archetype.

	---@type DL_ArchetypeRecord[]
	local ARCHETYPES = {
		{ id = "veteran", suffix = "veteran" },
		{ id = "zealot", suffix = "zealot" },
		{ id = "psyker", suffix = "psyker" },
		{ id = "ogryn", suffix = "ogryn" },
		{ id = "adamant", suffix = "arbites", aliases = { "arbites" } },
		{ id = "cryptic", suffix = "skitarii", aliases = { "mechanicus", "adeptus_mechanicus" } },
		{ id = "broker", suffix = "broker", aliases = { "hive_scum" } },
	}

	---@type table<string, DL_ArchetypeRecord>
	local by_name = {}
	for _, record in ipairs(ARCHETYPES) do
		by_name[record.id] = record
		if record.aliases then
			for _, alias in ipairs(record.aliases) do
				by_name[alias] = record
			end
		end
	end

	---@class DL_Archetypes
	local Archetypes = {}

	---@param name string | nil
	---@return DL_ArchetypeId | nil
	function Archetypes.resolve(name)
		local record = name and by_name[name]
		return record and record.id or nil
	end

	---@param name string | nil
	---@return DL_ArchetypeSuffix | nil
	function Archetypes.suffix(name)
		local record = name and by_name[name]
		return record and record.suffix or nil
	end

	---@param name string | nil
	---@param id DL_ArchetypeId
	---@return boolean
	function Archetypes.matches(name, id)
		return Archetypes.resolve(name) == id
	end

	---@param name string | nil
	---@return boolean
	function Archetypes.is_known(name)
		return Archetypes.resolve(name) ~= nil
	end

	for _, record in ipairs(ARCHETYPES) do
		local id = record.id
		Archetypes["is_" .. id] = function(name)
			return Archetypes.matches(name, id)
		end
	end

	return Archetypes
end
