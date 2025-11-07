local mod = get_mod("FXlimiter")
local max_impact_fx_per_frame = mod:get("max_impact_fx_per_frame") or 5
local impacts_played_this_frame = 0

--feature modules!
mod:io_dofile("FXlimiter/scripts/mods/FXlimiter/modules/simpler_blood_decals")
mod:io_dofile("FXlimiter/scripts/mods/FXlimiter/modules/cheaper_fire")

mod.on_setting_changed = function(id)
	if id == "max_impact_fx_per_frame" then
		max_impact_fx_per_frame = mod:get(id)
	end
end

mod:hook(CLASS.FxSystem, "play_surface_impact_fx", function(func, self, ...)
	if impacts_played_this_frame >= max_impact_fx_per_frame then
		return
	end
	
	impacts_played_this_frame = impacts_played_this_frame + 1
	
	return func(self, ...)
end)

mod:hook(CLASS.FxSystem, "play_impact_fx", function(func, self, ...)
	if impacts_played_this_frame >= max_impact_fx_per_frame then
		return
	end
	
	impacts_played_this_frame = impacts_played_this_frame + 1
	
	return func(self, ...)
end)

mod:hook_safe(CLASS.FxSystem, "update", function(self, ...)
	impacts_played_this_frame = 0
end)