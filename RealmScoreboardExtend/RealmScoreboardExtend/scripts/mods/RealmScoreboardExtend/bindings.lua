-- scoreboard_view.lua assigns methods again every time DMF loads the view.
-- DMF's regular hook registry caches the first original, so re-registering a
-- hook on a subsequently assigned raw function does not reinstall its dispatcher.
-- These narrowly scoped bindings wrap the CURRENT function after each view load.
local M = {}
local records = setmetatable({}, {__mode = "k"})
function M.wrap(owner, key, handler)
    if type(owner) ~= "table" or type(owner[key]) ~= "function" then return false end
    local methods = records[owner] or {}
    records[owner] = methods
    local record = methods[key]
    if record and owner[key] == record.wrapper then return false end
    local original = owner[key]
    local wrapper = function(...) return handler(original, ...) end
    methods[key] = {wrapper = wrapper}
    owner[key] = wrapper
    return true
end
function M.active(owner, key)
    local record = records[owner] and records[owner][key]
    return record ~= nil and owner[key] == record.wrapper
end
return M
