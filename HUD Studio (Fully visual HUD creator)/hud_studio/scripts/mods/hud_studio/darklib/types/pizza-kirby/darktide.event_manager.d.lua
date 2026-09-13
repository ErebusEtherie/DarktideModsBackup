---@meta
---@class EventManager
EventManager = {}

Managers = Managers or {}
---@type EventManager
Managers.event = nil

---@param object table
---@vararg string #sets of event_name and callback_name (separate args)
function EventManager:register (object, ...) end
