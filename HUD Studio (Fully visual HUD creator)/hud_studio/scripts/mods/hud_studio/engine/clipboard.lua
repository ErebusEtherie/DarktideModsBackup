---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_clipboard then
	return mod.hud_studio_clipboard
end

local Clipboard = rawget(_G, "Clipboard")

---@class Clipboard
local ClipboardService = {}

---@param text string
---@return boolean copied
function ClipboardService.copy(text)
	if not text or text == "" then
		return false
	end
	if not (Clipboard and Clipboard.put) then
		return false
	end
	Clipboard.put(text)
	return true
end

---@return string
function ClipboardService.paste()
	if Clipboard and Clipboard.get then
		return Clipboard.get() or ""
	end
	return ""
end

mod.hud_studio_clipboard = ClipboardService

return ClipboardService
