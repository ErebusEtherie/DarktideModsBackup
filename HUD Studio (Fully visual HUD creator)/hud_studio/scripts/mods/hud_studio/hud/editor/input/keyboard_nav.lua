

---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_keyboard_nav then
	return mod.hud_studio_keyboard_nav
end

local Session = mod:core(mod.hud_studio_session, "document/session")

local Keyboard = rawget(_G, "Keyboard")

local ARROW_HOLD_DELAY = 0.75
local ARROW_REPEAT_INTERVAL = 0.02

---@class KeyNavCtx
---@field now number                                       self._t
---@field sel { canvas: boolean, darktide: boolean, block: number|nil, node: number|nil }
---@field commit_edit fun()                                write the pending edit to disk

---@class KeyboardNav
local KeyboardNav = {}

local held = nil

local _key_idx = {}
local _key_idx_ready = false
local function ensure_key_indices()
	if _key_idx_ready then
		return
	end
	_key_idx_ready = true
	if Keyboard and Keyboard.button_index then
		for _, name in ipairs({
			"left",
			"right",
			"up",
			"down",
			"left ctrl",
			"right ctrl",
			"z",
			"y",
			"left shift",
			"right shift",
		}) do
			_key_idx[name] = Keyboard.button_index(name)
		end
	end
end

local function key_held(name)
	local i = _key_idx[name]
	return i ~= nil and Keyboard.button and Keyboard.button(i) > 0.5
end

---@return boolean
KeyboardNav.ctrl_held = function()
	ensure_key_indices()
	return key_held("left ctrl") or key_held("right ctrl")
end

local function key_pressed(name)
	local i = _key_idx[name]
	return i ~= nil and Keyboard.pressed and Keyboard.pressed(i) and true or false
end

---@return "undo"|"redo"|nil
KeyboardNav.history_key = function()
	ensure_key_indices()
	if not KeyboardNav.ctrl_held() then
		return nil
	end
	if key_pressed("y") then
		return "redo"
	end
	if key_pressed("z") then
		return (key_held("left shift") or key_held("right shift")) and "redo" or "undo"
	end
	return nil
end

---@param ctx KeyNavCtx
---@return number[]|nil
local function target_offset(ctx)
	local sel = ctx.sel
	if sel.canvas or sel.darktide then
		return nil
	end
	local block = sel.block and Session.block_at(sel.block)
	if not block then
		return nil
	end
	if sel.node then
		local node = block.nodes[sel.node]
		if not node then
			return nil
		end
		node.offset = node.offset or { 0, 0 }
		return node.offset
	end
	block.offset = block.offset or { 0, 0 }
	return block.offset
end

---@param ctx KeyNavCtx
KeyboardNav.release = function(ctx)
	if held and held.dirty then
		ctx.commit_edit()
	end
	held = nil
end

---@param ctx KeyNavCtx
KeyboardNav.update = function(ctx)
	ensure_key_indices()

	local dx, dy = 0, 0
	if key_held("left") then
		dx = dx - 1
	end
	if key_held("right") then
		dx = dx + 1
	end
	if key_held("up") then
		dy = dy - 1
	end
	if key_held("down") then
		dy = dy + 1
	end

	if dx == 0 and dy == 0 then
		KeyboardNav.release(ctx)
		return
	end

	local off = target_offset(ctx)
	if not off then
		held = nil
		return
	end

	local t = ctx.now
	if not held or held.dx ~= dx or held.dy ~= dy then

		KeyboardNav.release(ctx)
		off[1] = (off[1] or 0) + dx
		off[2] = (off[2] or 0) + dy
		held = { dx = dx, dy = dy, next_at = t + ARROW_HOLD_DELAY, dirty = false }
		ctx.commit_edit()
	elseif t >= held.next_at then

		repeat
			off[1] = (off[1] or 0) + dx
			off[2] = (off[2] or 0) + dy
			held.next_at = held.next_at + ARROW_REPEAT_INTERVAL
		until t < held.next_at
		held.dirty = true
	end
end

mod.hud_studio_keyboard_nav = KeyboardNav

return KeyboardNav
