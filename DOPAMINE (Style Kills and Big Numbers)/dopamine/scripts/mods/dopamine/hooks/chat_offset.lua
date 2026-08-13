

---@type mod
local mod = get_mod("dopamine")

if mod.chat_offset then
	return mod.chat_offset
end

local Layout = mod:core(mod.layout, "hud/layout")

local CHAT_SCENEGRAPH = "chat_window"

local function should_offset_chat()
	if not mod:is_enabled() then
		return false
	end

	if not mod.dl.gameplay.in_gameplay() then
		return false
	end

	if mod.dl.settings.chat_reposition ~= "on" then
		return false
	end

	return Layout.left_column_occupied()
end

local function restore_chat_position(self)
	if not self._chat_base_y then
		return
	end

	local node = self._ui_scenegraph[CHAT_SCENEGRAPH]
	if not node then
		self._chat_base_y = nil
		return
	end

	self:set_scenegraph_position(
		CHAT_SCENEGRAPH,
		node.position[1],
		self._chat_base_y,
		node.position[3],
		node.horizontal_alignment,
		node.vertical_alignment
	)
	self._chat_base_y = nil
end

mod.dl.game_hooks.hook(CLASS.ConstantElementChat, "update", function(func, self, dt, t, ui_renderer, render_settings, input_service)
	func(self, dt, t, ui_renderer, render_settings, input_service)

	if not should_offset_chat() then
		restore_chat_position(self)
		return
	end

	local node = self._ui_scenegraph[CHAT_SCENEGRAPH]
	if not node then
		return
	end

	local offset = Layout.native_chat_push_y()

	if not self._chat_base_y then
		self._chat_base_y = node.position[2]
	end

	local target_y = self._chat_base_y + offset
	if math.abs(node.position[2] - target_y) > 0.01 then
		self:set_scenegraph_position(
			CHAT_SCENEGRAPH,
			node.position[1],
			target_y,
			node.position[3],
			node.horizontal_alignment,
			node.vertical_alignment
		)
	end
end)

local ChatOffset = {}

mod.chat_offset = ChatOffset

return ChatOffset
