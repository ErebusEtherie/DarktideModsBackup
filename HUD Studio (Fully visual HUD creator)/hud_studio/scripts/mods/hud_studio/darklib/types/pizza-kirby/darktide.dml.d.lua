local ffi = require("ffi")
---@meta
---@class Mods
Mods = {}
Mods.debug = debug
Mods.io = io
Mods.ffi = ffi
Mods.os = os
Mods.loadstring = loadstring

---@type table
Mods.require_store = nil
Mods.original_require = require
Mods.original_class = class

---@class DMLHook
---@field name string
---@field func function
---@field enable boolean
---@field exec function

---@class DMLItem
---@field name string
---@field func function
---@field hooks table<DMLHook>

Mods.message = {}
---@param message string
---@return nil
function Mods.message.notify(message) end
---@param message string
---@param sender? string
function Mods.message.echo(message, sender) end

Mods.hook = {}

---@param mod_name string
---@param func_name string
---@param hook_func function
---@return nil
function Mods.hook.set(mod_name, func_name, hook_func) end

---@param mod_name string
---@param filepath string
---@param func_name string
---@param hook_func function
---@return nil
function Mods.hook.set_on_file(mod_name, filepath, func_name, hook_func) end

---@param value boolean
---@param mod_name string
---@param func_name string
---@return nil
function Mods.hook.enable(value, mod_name, func_name) end

---@param filepath string
---@param store_index integer
---@return nil
function Mods.hook.enable_by_file(filepath, store_index) end

---@param func_name string
---@param mod_name string
function Mods.hook.remove(func_name, mod_name) end

---@param mod_name string
---@param func_name string
---@return nil
function Mods.hook.front(mod_name, func_name) end

---@param func_name string
---@return unknown
function Mods.hook._get_func(func_name) end

---@param func_name string
---@return DMLItem
function Mods.hook._get_item(func_name) end

---@param item_name string
---@param mod_name string
---@return DMLHook
function Mods.hook._get_item_hook(item_name, mod_name) end

---@param mod_hook_item string
---@return nil
function Mods.hook._patch(mod_hook_item) end

Mods.file = {}
---@return boolean
function Mods.file.exec(local_path, file_name, file_extension, args) end
---@return boolean
function Mods.file.exec_unsafe(local_path, file_name, file_extension, args) end
---@return any
function Mods.file.exec_with_return(local_path, file_name, file_extension, args) end
---@return any
function Mods.file.exec_unsafe_with_return(local_path, file_name, file_extension, args) end
---@return any
function Mods.file.dofile(file_path, args) end
---@return string
function Mods.file.read_content(file_path, file_extension) end
---@return string[]
function Mods.file.read_content_to_table(file_path, file_extension) end
---@return boolean exists
function Mods.file.exists(name) end

---@type table<DMLItem>
MODS_HOOKS = nil
---@type table
MODS_HOOKS_BY_FILE = nil
