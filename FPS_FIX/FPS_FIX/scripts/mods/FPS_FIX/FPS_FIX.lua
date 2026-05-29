local mod = get_mod("FPS_FIX")
local frame_rate = require("scripts/managers/frame_rate/frame_rate_manager")

mod:hook(CLASS.FrameRateManager, "_set_target_fps", function(func, self, is_throttled)
	if mod:get("fps_check") then
		Application.set_time_step_policy("throttle", 0)
	else
		Application.set_time_step_policy("throttle", mod:get("fps_scale"))
	end
end)