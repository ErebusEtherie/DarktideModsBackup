local mod = get_mod("LoadingBar")

local Progress = mod:io_dofile("LoadingBar/scripts/mods/LoadingBar/loading_bar_progress")
local Render = mod:io_dofile("LoadingBar/scripts/mods/LoadingBar/loading_bar_render")

local settings = {}

local function refresh_settings()
	settings.enabled = mod:get("lb_enabled") ~= false
	settings.style_id = mod:get("lb_style") or "heavy"

	settings.show_reason = mod:get("lb_show_reason") == true
	settings.show_percentage = mod:get("lb_show_percentage") == true
	settings.scale = mod:get("lb_scale") or 1.0
	settings.bottom_margin = mod:get("lb_bottom_margin") or 90
	settings.hide_spinner = mod:get("lb_hide_spinner") == true
	settings.hide_wait_text = mod:get("lb_hide_wait_text") == true
end

refresh_settings()

function mod.on_setting_changed()
	refresh_settings()
end

function mod.on_enabled()
	refresh_settings()
end

mod:hook_safe("StateLoading", "update", function(self)
	Progress.set_observed(true, self._state, self._loading_state, self._mission_name)
end)

mod:hook_safe("StateLoading", "on_enter", function(self)
	Progress.set_observed(true, self._state, self._loading_state, self._mission_name)
end)

mod:hook_safe("StateLoading", "on_exit", function()

	Progress.set_observed(false, nil, nil)
end)

mod:hook("LoadingReason", "_render_icon", function(func, ...)
	if mod:is_enabled() and settings.hide_spinner then
		return
	end

	return func(...)
end)

mod:hook("LoadingReason", "_render_text", function(func, ...)
	if mod:is_enabled() and settings.hide_wait_text then
		return
	end

	return func(...)
end)

mod:hook_safe("UIManager", "render_loading_info", function(self)
	if not settings.enabled or not mod:is_enabled() then
		return
	end

	local renderer = self._ui_loading_icon_renderer

	if not renderer or not renderer.gui then
		return
	end

	local progress, session_started = Progress.update()

	if session_started then
		Render.reset_material_failure()
	end

	local reason

	if settings.show_reason then
		local ok, wait_reason = pcall(self.current_wait_info, self)

		if ok then
			reason = wait_reason
		end
	end

	Render.draw(renderer.gui, progress, reason, {
		style_id = settings.style_id,
		show_reason = settings.show_reason,
		show_percentage = settings.show_percentage,
		scale = settings.scale,
		bottom_margin = settings.bottom_margin,
	})
end)

mod:command("loading_bar_recalibrate", mod:localize("cmd_recalibrate"), function()
	Progress.reset_calibration()
	Render.reset_material_failure()
	mod:notify(mod:localize("notify_recalibrated"))
end)
