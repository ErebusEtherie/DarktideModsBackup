Inventory2D = Inventory2D or {}
Inventory2D.settings = Inventory2D.settings or {}
local inv2d = Inventory2D
local s = inv2d.settings

local mod_data = Mods.file.dofile(inv2d.mod_path .. "mod_data")
local ids = {}
local cache = {}

s.init = function()
	local names = s.get_setting_names(mod_data.options.widgets)

	for i = 1, #names do
		local id = names[i]
		table.insert(ids, id)
		cache[id] = inv2d.mod:get(id)
	end
end

s.get = function(id)
	if not cache[id] then
		cache[id] = inv2d.mod:get(id)
	end

	return cache[id]
end

s.set = function(id, value)
	inv2d.mod:set(id, value)
	cache[id] = value
end

inv2d.mod.on_setting_changed = function(id)
	cache[id] = inv2d.mod:get(id)

	-- If we don't do this all the icons will be too stretched or squished
	-- whenever these settings change.
	if id == "items_per_row" or id == "grid_spacing" then
		inv2d.icon_renderer = nil
		-- inv2d.destroy_icon_renderer()
	end
end

s.get_setting_names = function(widgets)
	local result = {}

	for i = 1, #widgets do

		-- If it's not a group, add its setting_id.
		if widgets[i].type ~= "group" and widgets[i].setting_id then
			table.insert(result, widgets[i].setting_id)
		end

		-- If it has any subwidgets, process them recursively.
		if widgets[i].sub_widgets then
			local sub_result = s.get_setting_names(widgets[i].sub_widgets)

			for j = 1, #sub_result do
				if sub_result[j] then
					table.insert(result, sub_result[j])
				end
			end
		end

	end

	return result
end

return s
