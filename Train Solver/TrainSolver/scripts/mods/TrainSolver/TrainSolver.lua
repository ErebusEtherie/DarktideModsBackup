--[[
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│ Mod Name: Train Solver                                                                    │
│ Mod Description: Automatically plays the train minigame for you.                          |
│ Mod Author: Seph (Steam: Concoction of Constitution)                                      │
└───────────────────────────────────────────────────────────────────────────────────────────┘
--]]

local mod = get_mod("TrainSolver")

local MinigameSettings = require("scripts/settings/minigame/minigame_settings")
local posX = 0
local posY = 0

local oposX = 0
local oposY = 0
local dist = 0

local timer = 0


local enabled = true
mod.on_enabled = function() enabled = true end
mod.on_disabled = function() enabled = false end

-- local gaming = false
-- Get cursor position
mod:hook_safe("MinigameBalanceView", "_update_cursor", function(s, widgets_by_name)
    local minigame_extension = s._minigame_extension
	local minigame = minigame_extension:minigame(MinigameSettings.types.balance)
    local position = minigame:position()
    -- Get position and distance from center
    posX = position.x
    posY = position.y
    dist = math.sqrt(posX * posX + posY * posY)
    timer = 0.05
end)


local pushStrength = 0.66 -- Higher value means less strength in moving dot, more precision but slower and harder to get to center

mod.on_setting_changed = function()
    pushStrength = mod:get("strength")
end

-- Check when you start and stop the minigame, to know when to auto press buttons
mod:hook_safe("MinigameBalance", "start", function(s)
    pushStrength = mod:get("strength")
end)

mod:hook_safe("MinigameBalance", "stop", function(s)
    timer = 0
end)


-- Get the speed of x and y values
local delta = 0
local dX = 0
local dY = 0
mod.update = function(dt)
    if timer > 0 then timer = timer - dt end
    delta = dt
    -- Normalize by multiplying by 10k
    dX = (posX - oposX)*dt*10000
    dY = (posY - oposY)*dt*10000
    oposX = posX
    oposY = posY
end
 
mod:hook("InputService", "_get", function(f, s, action_name)
    local x = f(s, action_name)
    if timer > 0 and enabled then
        if dist > 0.2 and posX and posY then
            -- Tell the game to 'push left/right/up/down' based on cursor position, distance, and speed
            -- E.g. if cursor is on the right and far enough away, push left until speedX says the cursor is moving left
            if posX > 0 and action_name == "move_left" and dX > -0.5 then return math.abs(posX)*pushStrength end
            if posX < 0 and action_name == "move_right" and dX < 0.5 then return math.abs(posX)*pushStrength end
            if posY > 0 and action_name == "move_forward" and dY > -0.5 then return math.abs(posY)*pushStrength end
            if posY < 0 and action_name == "move_backward" and dY < 0.5 then return math.abs(posY)*pushStrength end
        end
    end
    return x
end)
