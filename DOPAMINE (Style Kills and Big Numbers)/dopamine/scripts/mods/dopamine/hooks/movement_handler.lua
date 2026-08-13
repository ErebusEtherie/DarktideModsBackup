

---@type mod
local mod = get_mod("dopamine")

if mod.movement_handler then
	return mod.movement_handler
end

local EventManager = mod:core(mod.event_manager, "utils/event/manager")

mod.dl.movement.on_slide(function(active)
	if active then
		EventManager.on_slide_start()
	else
		EventManager.on_slide_end()
	end
end)

mod.dl.movement.on_effective_dodge(function(player_unit, is_slide)
	if is_slide then
		return
	end

	EventManager.on_successful_dodge()
end)

---@class MovementHandler
local MovementHandler = {}

function MovementHandler.tick(dt)
	mod.dl.movement.tick(dt)
	EventManager.set_sliding(mod.dl.movement.is_sliding(), dt)
end

function MovementHandler.reset()
	mod.dl.movement.reset()
end

mod.movement_handler = MovementHandler

return MovementHandler
