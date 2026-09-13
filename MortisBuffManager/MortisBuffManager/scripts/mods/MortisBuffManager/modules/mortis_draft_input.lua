-- Capture selection chords before HumanInputHandler caches gameplay input.
-- Only claimed physical number keys are filtered; no input service is replaced.
local mod = get_mod("MortisBuffManager")
local InputManager = require("scripts/managers/input/input_manager")
local InputService = require("scripts/managers/input/input_service")
local InputUtils = require("scripts/managers/input/input_utils")
local Input = { now = 0, claimed = {}, owned = {}, latched = {} }
local keys, device, controls
local function indices()
    if device == Keyboard and keys then return end
    device, keys, controls = Keyboard, {}, {}
    local seen = {}
    for i = 1, 3 do
        for _, name in ipairs({ tostring(i), "num " .. i, "numpad " .. i }) do
            local ok, index = pcall(Keyboard.button_index, name)
            if ok and index then
                local key = seen[index]
                if not key then
                    key = { index = index, choice = i, aliases = {} }; keys[#keys + 1] = key; seen[index] = key
                end
                key.aliases[#key.aliases + 1] = "keyboard_" .. name
            end
        end
    end
    for _, name in ipairs({ "left ctrl", "right ctrl" }) do
        local ok, index = pcall(Keyboard.button_index, name)
        if ok and index then controls[#controls + 1] = index end
    end
end
function Input.cleanup()
    Input.pending, Input.context, Input.claimed, Input.owned, Input.latched = nil, nil, {}, {}, {}
end
function Input.sample(dt)
    Input.now = Input.now + dt
    for key in pairs(Input.claimed) do Input.claimed[key] = nil end
    if not mod:is_enabled() or not Keyboard or not Keyboard.button_index then
        Input.pending = nil
        for key in pairs(Input.owned) do Input.owned[key] = nil end
        for key in pairs(Input.latched) do Input.latched[key] = nil end
        return
    end
    indices()
    local id, selectable
    if Input.context then id, selectable = Input.context() end
    if not id and next(Input.owned) == nil then
        Input.pending = nil
        for key in pairs(Input.latched) do Input.latched[key] = nil end
        return
    end
    local ui = Managers.ui
    local in_ui = not ui or ui:using_input()
    local snapshot, _, pending = mod.mortis_draft_snapshot()
    local active = snapshot and snapshot.active
    local ctrl = false
    for _, index in ipairs(controls) do
        if Keyboard.button(index) > 0 or Keyboard.pressed(index) then ctrl = true; break end
    end
    if in_ui or not active or not Input.pending or Input.pending.id ~= active.id or Input.now > Input.pending.expires then
        Input.pending = nil
    end
    for _, key in ipairs(keys) do
        local pressed, down = Keyboard.pressed(key.index), Keyboard.button(key.index) > 0
        if not pressed and not down then Input.latched[key.index], Input.owned[key.index] = nil, nil end
        local chord = snapshot and id and not in_ui and ctrl and (pressed or down)
        if chord then Input.owned[key.index] = true end
        if Input.owned[key.index] and (pressed or down) then
            for _, alias in ipairs(key.aliases) do Input.claimed[alias] = true end
        end
        if pressed and not Input.latched[key.index] then
            Input.latched[key.index] = true
            if chord and selectable and active and id == active.id and not pending and active.choices[key.choice]
                and not Input.pending then
                Input.pending = { id = id, index = key.choice, expires = Input.now + 0.35 }
            end
        end
    end
end
function Input.take(id)
    local choice = Input.pending
    if not choice or choice.id ~= id then return end
    Input.pending = nil
    if Input.now <= choice.expires then return choice.index end
end
function Input.filtered(service, action)
    if not mod:is_enabled() or service.type ~= "Ingame" or next(Input.claimed) == nil then return false end
    local rule = service._actions[action]
    local aliases = rule and rule.key_alias and service._aliases[rule.key_alias]
    for _, alias in ipairs(aliases or {}) do
        local main = InputUtils.split_key(alias)
        if Input.claimed[main] then return true end
    end
    return false
end
mod:hook_safe(InputManager, "_update_services", function(_, dt) Input.sample(dt) end)
mod:hook(InputService, "get_with_filters", function(func, service, action, locked)
    local filtered = Input.filtered(service, action)
    local value
    if filtered then value = service:get_default(action) else value = func(service, action, locked) end
    return value
end)
return Input
