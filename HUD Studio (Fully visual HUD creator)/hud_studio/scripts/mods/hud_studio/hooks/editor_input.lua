

---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_editor_input then
	return mod.hud_studio_editor_input
end

local function editor_owns_hotkeys()
	if not mod:is_enabled() then
		return false
	end
	if mod.hud_studio_editor_active ~= true then
		return false
	end
	local Gameplay = mod.dl.gameplay
	return Gameplay.is_in_gameplay() or Gameplay.is_in_hub()
end

local function editor_capturing_text()
	if not editor_owns_hotkeys() then
		return false
	end
	local tf = mod.hud_studio_text_field
	return tf ~= nil and tf.any_focused()
end

mod.dl.game_hooks.hook(CLASS.UIManager, "_update_view_hotkeys", function(func, self)
	if editor_owns_hotkeys() then
		return
	end
	return func(self)
end)

mod.dl.game_hooks.hook(CLASS.UIManager, "input_service", function(func, self, ...)
	local service, null_service, gamepad_active = func(self, ...)
	if editor_capturing_text() then
		return null_service, null_service, gamepad_active
	end
	return service, null_service, gamepad_active
end)

mod.dl.game_hooks.hook(CLASS.UIManager, "using_input", function(func, self, ...)
	if editor_capturing_text() and not mod.hud_studio_editor_self_query then
		return true
	end
	return func(self, ...)
end)

local dmf = get_mod("DMF")
if dmf then
	mod.dl.game_hooks.hook(dmf, "check_keybinds", function(next)
		if editor_capturing_text() then
			return
		end
		return next()
	end)
end

---@class EditorInput
local EditorInput = {}

mod.hud_studio_editor_input = EditorInput

return EditorInput
