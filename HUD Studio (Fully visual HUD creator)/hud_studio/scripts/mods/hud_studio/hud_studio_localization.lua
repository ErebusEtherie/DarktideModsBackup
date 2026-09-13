---@class mod : DL_Mod
local mod = get_mod("hud_studio")

mod:io_dofile("hud_studio/scripts/mods/hud_studio/bootstrap")

local files = {
	"mod",
	"settings",
	"editor",
	"material_categories",
	"source_fields",
	"abilities_simple",
}

local localization = {}

for i = 1, #files do
	local lang_table = mod:io_dofile("hud_studio/scripts/mods/hud_studio/lang/" .. files[i])
	mod.dl.loc_helpers.merge_tables(localization, lang_table)
end

local user_loc = mod:io_dofile("hud_studio/scripts/mods/hud_studio/document/user_loc")
if user_loc then
	local ok, strings = pcall(user_loc.read)
	if ok and strings then
		mod.dl.loc_helpers.merge_tables(localization, strings)
	end
end

return localization
