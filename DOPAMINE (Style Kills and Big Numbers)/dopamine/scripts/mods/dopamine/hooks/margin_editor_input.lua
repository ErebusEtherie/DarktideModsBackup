

---@type mod
local mod = get_mod("dopamine")

if mod.margin_editor_input then
	return mod.margin_editor_input
end

local function editor_owns_hotkeys()
	if not mod:is_enabled() then
		return false
	end

	return mod.margin_editor_active == true and mod.dl.gameplay.in_gameplay()
end

mod.dl.game_hooks.hook(CLASS.UIManager, "_update_view_hotkeys", function(func, self)
	if editor_owns_hotkeys() then
		return
	end

	return func(self)
end)

local MarginEditorInput = {}

mod.margin_editor_input = MarginEditorInput

return MarginEditorInput
