

---@type mod
local mod = get_mod("dopamine")

if mod.mission_speaker then
	return mod.mission_speaker
end

local Layout = mod:core(mod.layout, "hud/layout")

local SPEAKER_SCENEGRAPH = "background"

local function push_offset()
	if not mod:is_enabled() then
		return 0
	end

	if not mod.dl.gameplay.in_gameplay() then
		return 0
	end

	if mod.dl.settings.mission_speaker_reposition ~= "on" then
		return 0
	end

	return Layout.native_mission_speaker_push_y()
end

local function restore_speaker_position(self)
	if not self._dopamine_speaker_base_y then
		return
	end

	local node = self._ui_scenegraph[SPEAKER_SCENEGRAPH]
	if not node then
		self._dopamine_speaker_base_y = nil
		return
	end

	self:set_scenegraph_position(
		SPEAKER_SCENEGRAPH,
		node.position[1],
		self._dopamine_speaker_base_y,
		node.position[3],
		node.horizontal_alignment,
		node.vertical_alignment
	)
	self._dopamine_speaker_base_y = nil
end

mod.dl.game_hooks.hook_safe(
	CLASS.HudElementMissionSpeakerPopup,
	"update",
	function(self, dt, t, ui_renderer, render_settings, input_service)
		local push = push_offset()
		if push == 0 then
			restore_speaker_position(self)
			return
		end

		local node = self._ui_scenegraph[SPEAKER_SCENEGRAPH]
		if not node then
			return
		end

		if not self._dopamine_speaker_base_y then
			self._dopamine_speaker_base_y = node.position[2]
		end

		local target_y = self._dopamine_speaker_base_y + push
		if math.abs(node.position[2] - target_y) > 0.01 then
			self:set_scenegraph_position(
				SPEAKER_SCENEGRAPH,
				node.position[1],
				target_y,
				node.position[3],
				node.horizontal_alignment,
				node.vertical_alignment
			)
		end
	end
)

mod.__debug__toggle_mission_speaker = function(is_pressed)
	if not is_pressed then
		return
	end

	mod.dl_hud.mission_speaker.toggle_native()
end

local MissionSpeaker = {}

mod.mission_speaker = MissionSpeaker

return MissionSpeaker
