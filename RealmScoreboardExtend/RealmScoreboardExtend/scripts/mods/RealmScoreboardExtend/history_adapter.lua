-- Adapter for scoreboard's existing history format. No four-player truncation.
local ext = get_mod("RealmScoreboardExtend")
local mod = get_mod("scoreboard")
local DMF = get_mod("DMF")
local UISettings = require("scripts/settings/ui/ui_settings")
local _io = DMF:persistent_table("_io")
if not _io.initialized then _io = DMF.deepcopy(Mods.lua.io) end
local _os = DMF:persistent_table("_os")
if not _os.initialized then _os = DMF.deepcopy(Mods.lua.os) end
local clean = ext.text.history_field
local save = function(self, sorted_rows)
	
	self:create_scoreboard_history_directory()


	local path, file_name = self:create_scoreboard_history_entry_path()

	local file = assert(_io.open(path, "w+"))
    file:write(ext.text.history_marker .. "\n")

	local players = ext.all_players()
    ext.trace("history_save", "players=%d file=%s", #players, tostring(file_name))
	if self.debug_value then
		players = {
			{
				account_id = function()
					return mod:me()
				end,
				name = function()
					return "Rudge"
				end,
			},
			{
				account_id = function()
					return "lol"
				end,
				name = function()
					return "lol"
				end,
			},
			{
				account_id = function()
					return "rofl"
				end,
				name = function()
					return "rofl"
				end,
			},
			{
				account_id = function()
					return "omg"
				end,
				name = function()
					return "omg"
				end,
			},
		}
	end

	local timer = (_os.time() or 0) - (self.timer or 0)
	file:write("#mission;"..tostring(self.mission_name)..";"..tostring(self.mission_resistance)..";"..tostring(self.mission_circumstance)..";"..tostring(self.victory_defeat)..";"..tostring(timer).."\n")

	local count = 0
	for _, player in ipairs(players) do count = count + 1 end
	file:write("#players;"..tostring(count).."\n")
	local num_players = 0
	for _, player in ipairs(players) do
		num_players = num_players + 1
		if num_players <= #players then
			local account_id = player:account_id() or player:name()
			local profile = player:profile()
			local archetype_name = profile and profile.archetype and profile.archetype.name
			local symbol = player.string_symbol or (archetype_name and UISettings.archetype_font_icon[archetype_name]) or ""
			file:write(num_players..";"..clean(account_id)..";"..clean(player:name())..";"..clean(symbol).."\n")
		end
	end

	local index = 1
	for g = 1, #sorted_rows, 1 do
        local rows = sorted_rows[g]
        for i = 1, #rows, 1 do
            local this_row = rows[i]
			if this_row.name ~= "header" and not this_row.score then

				local val_count = 0
				if this_row.data and type(this_row.data) == "table" then
					for k,v in pairs(this_row.data) do
						val_count = val_count + 1
					end
				end
				local name = this_row.name
				local text = ext.text.label(this_row)
				local validation = this_row.validation_type
				local iteration = tostring(this_row.iteration_type)
				local visible = tostring(this_row.visible) --this_row.visible == true and "1" or "0"
				local group = tostring(this_row.group) --~= "" and this_row.group or "none"
				local setting = tostring(this_row.setting) --~= "" and this_row.setting or "none"
				local parent = tostring(this_row.parent) --~= "" and this_row.parent or "none"
				local is_time = tostring(this_row.is_time) --== true and "1" or "0"
				local summary = this_row.summary and clean(table.concat(this_row.summary, ":")) or "nil"
				local normalize = tostring(this_row.normalize)
				local icon = tostring(this_row.icon)
				local icon_package = tostring(this_row.icon_package)
				local icon_width = tostring(this_row.icon_width)
				file:write("#row;"..clean(name)..";"..index..";"..val_count..";"..clean(text)..";"..validation..";"..iteration..";"..visible..";"..clean(group)..";"..clean(setting)..";"..clean(parent)..";"..is_time..";"..summary..";"..normalize..";"..clean(icon)..";"..clean(icon_package)..";"..icon_width.."\n")
				if this_row.data and type(this_row.data) == "table" then
					for account_id, data in pairs(this_row.data) do
						file:write(clean(account_id)..";"..(data.score or 0)..";"..(data.is_best and "1" or "0")..";"..(data.is_worst and "1" or "0")..((data.text or data.text_data) and ";"..(this_row.name == "sr_equipment_snapshot_v1" and (data.text or data.text_data) or clean((data.text or data.text_data))) or "").."\n")
					end
				end
				index = index + 1
			elseif this_row.score then
				local text = ext.text.label(this_row)
				file:write("#group;"..clean(this_row.text)..";"..clean(text).."\n")
			end
		end
	end

	file:close()

	local cache = mod:get_scoreboard_history_entries_cache()
	if not cache or type(cache) ~= "table" then cache = {} end
	local found = false
    for _, cached in ipairs(cache) do if cached == file_name then found = true; break end end
    if not found then cache[#cache+1] = file_name end
	mod:set_scoreboard_history_entries_cache(cache)
    mod.checked_history_files = nil
    ext.trace("history_saved", "file=%s players=%d rows=%d cache=%d", tostring(file_name), #players, index - 1, #cache)
end
ext.text.install_history_reader(ext, mod, _io)
ext:hook(mod, "save_scoreboard_history_entry", function(func, self, sorted_rows)
    sorted_rows = ext.loadouts.append(sorted_rows, ext.all_players(), false, true)
    local copied = {}
    for i, group in ipairs(sorted_rows) do copied[i] = ext.model.project_rows(ext.roster, group, ext.copy) end
    return save(self, copied)
end)
