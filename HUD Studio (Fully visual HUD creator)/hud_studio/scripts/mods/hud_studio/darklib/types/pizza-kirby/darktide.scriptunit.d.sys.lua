---@meta

---@class ScriptUnit
ScriptUnit = {}

---@param arg0 unknown
---@param arg1 unknown
---@return any
function ScriptUnit.extension(arg0, arg1) end

---@param arg0 unknown
---@return any
function ScriptUnit.optimize(arg0) end

---@param arg0 unknown
---@return any
function ScriptUnit.extensions(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function ScriptUnit.move_extensions(arg0, arg1) end

---@param arg0 unknown
---@return any
function ScriptUnit.extension_definitions(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function ScriptUnit.remove_extension(arg0, arg1) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@param arg3 unknown
---@param arg4 unknown
---@param ... unknown
---@return any
function ScriptUnit.add_extension(arg0, arg1, arg2, arg3, arg4, ...) end

---@param arg0 unknown
---@param arg1 unknown
---@param arg2 unknown
---@return any
function ScriptUnit.set_extension(arg0, arg1, arg2) end

---@param object unknown
---@param extension string
---@return unknown extension
function ScriptUnit.has_extension(object, extension) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function ScriptUnit.extension_input(arg0, arg1) end

---@param arg0 unknown
---@return any
function ScriptUnit.unit_in_cinematic_level(arg0) end

---@param arg0 unknown
---@param arg1 unknown
---@return any
function ScriptUnit.fetch_component_extension(arg0, arg1) end

---@param arg0 unknown
---@return any
function ScriptUnit.remove_unit(arg0) end
