---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_registration then
	return mod.hud_studio_registration
end

local CanvasConstants = mod:core(mod.canvas_constants, "hud/canvas/constants")
local EditorConstants = mod:core(mod.editor_constants, "hud/editor/constants")

mod:register_hud_element({
	class_name = CanvasConstants.CLASS_NAME,
	filename = "hud_studio/scripts/mods/hud_studio/hud/canvas/HudCanvas",
	use_hud_scale = false,
	visibility_groups = CanvasConstants.VISIBILITY_GROUPS,
})

mod:register_hud_element({
	class_name = EditorConstants.CLASS_NAME,
	filename = "hud_studio/scripts/mods/hud_studio/hud/editor/HudEditor",
	use_hud_scale = false,
	visibility_groups = EditorConstants.VISIBILITY_GROUPS,
})

---@param is_pressed boolean
function mod.toggle_editor(self, is_pressed)
	if is_pressed == false then
		return
	end

	local Gameplay = mod.dl.gameplay
	if not (Gameplay.is_in_gameplay() or Gameplay.is_in_hub()) then
		return
	end

	if not mod.hud_studio_editor_active and mod:core(mod.hud_studio_news, "hud/news/news").maybe_intercept_editor() then
		return
	end

	mod.hud_studio_editor_active = not mod.hud_studio_editor_active
	if mod.hud_studio_editor_active then

		mod:core(mod.hud_studio_history, "document/history").reset()
	end
end

---@class HudRegistration
local Registration = {}

mod.hud_studio_registration = Registration

return Registration
