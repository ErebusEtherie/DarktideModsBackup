---@class mod : DMFMod
local mod = get_mod("hud_studio")

if mod.hud_studio_context then
	return mod.hud_studio_context
end

---@class EditorDoc

---@class Context : EditorDoc
---@field t number                  game time this frame
---@field dt number                 delta time this frame
---@field player any?               the local player
---@field player_unit any?          the local player's unit, if alive
---@field gamemode string?          this frame's gamemode key ("mission"|"mourningstar"|"meatgrinder"); set by the canvas
---@field archetype string?         the local player's canonical archetype id, or nil; set by the canvas
---@field extensions table          per-frame extension handle cache (lazy, by source)
---@field frame_id number?           monotonic frame counter; stamped by Registry.begin_frame

---@class ContextBuilder
local Context = {}

---@type Context
local ctx = {
	t = 0,
	dt = 0,
	player = nil,
	player_unit = nil,

	gamemode = nil,
	archetype = nil,
	extensions = {},

	frame_id = nil,
}

---@param dt number
---@param t number
---@return Context
function Context.build(dt, t)
	ctx.t = t
	ctx.dt = dt

	local player = mod.dl.player and mod.dl.player.local_player and mod.dl.player.local_player()
	ctx.player = player
	ctx.player_unit = player and player.player_unit or nil

	for k in pairs(ctx.extensions) do
		ctx.extensions[k] = nil
	end

	return ctx
end

mod.hud_studio_context = Context

return Context
