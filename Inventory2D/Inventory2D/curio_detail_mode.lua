local ns = Inventory2D
local abbrevs = Mods.file.dofile(ns.mod_path .. "abbreviations")

ns.abbrev_curio_perk_descriptions = function(str)
	if not str or str == "" then
		return "nil"
	end

	for k, _ in pairs(abbrevs) do
		if not string.match(k, "_abbrev") then
			local original = ns.mod:localize(k)

			if string.match(str, original) then
				local abbreviated = ns.mod:localize(k .. "_abbrev")
				return string.gsub(str, original, abbreviated)
			end
		end
	end

	return str
end
