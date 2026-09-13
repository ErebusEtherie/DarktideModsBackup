---@meta

---@class Crashify
Crashify = {}

---@return nil
function Crashify.apply_backend_game_settings() end

---@param system table see `scripts\extension_systems[\extension_system_configuration.lua]` for available systems
---@param message string message to add for context
---@param print_func fun(...) function to use to print
---@return nil
function Crashify.print_exception(system, message, print_func) end

---@param crumb unknown
---@param print_func fun(...)
---@return nil
function Crashify.print_breadcrumb(crumb, print_func) end

---@param key unknown key of the property to remove
---@param print_func fun(...)
---@return nil
function Crashify.remove_print_property(key, print_func) end

---@param key unknown name of the property to print
---@param value unknown value of the property to print
---@param print_func fun(...) function to use to print
---@return nil
function Crashify.print_property(key, value, print_func) end

---@param optional_key? unknown
---@return table
function Crashify.get_print_properties(optional_key) end
