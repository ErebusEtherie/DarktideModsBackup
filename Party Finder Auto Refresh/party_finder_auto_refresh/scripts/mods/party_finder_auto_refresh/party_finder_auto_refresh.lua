local mod = get_mod("party_finder_auto_refresh")

local next_refresh_time = 0
local auto_refresh_enabled = true

function mod.toggle_auto_refresh()
	auto_refresh_enabled = not auto_refresh_enabled
	local state = auto_refresh_enabled and "enabled" or "disabled"
	mod:notify(string.format("Auto refresh %s.", state))
end

mod.on_enabled = function()
	next_refresh_time = Managers.time:time("main") + mod:get("refresh_interval")
	auto_refresh_enabled = true
end

mod.on_disabled = function()
	auto_refresh_enabled = false
end

mod.on_setting_changed = function(setting_id)
	if setting_id == "refresh_interval" then
		next_refresh_time = Managers.time:time("main") + mod:get("refresh_interval")
	end
end

mod.update = function(dt)
	if not auto_refresh_enabled then
		return
	end

	local t = Managers.time:time("main")
	local interval = mod:get("refresh_interval") or 10

	local view = Managers.ui:view_instance("group_finder_view")
	if not view then
		next_refresh_time = t + interval
		return
	end

	if view._state ~= "browsing" then
		next_refresh_time = t + interval
		return
	end

	if t >= next_refresh_time then
		if not view._refresh_promise then
			view:_cb_on_refresh_button_pressed()

			if mod:get("enable_refresh_notify") then
				mod:notify("Party Finder refreshed.")
			end
		end

		next_refresh_time = t + interval
	end
end