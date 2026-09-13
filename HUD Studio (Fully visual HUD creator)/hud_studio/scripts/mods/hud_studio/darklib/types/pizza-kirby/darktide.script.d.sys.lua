---@meta

---@class Script
Script = {

    MAXIMUM_COLLECT_TIME_MS = "4",

    ACCEPTABLE_GARBAGE = "0",

    MAXIMUM_GARBAGE = "1",

    FORCE_FULL_COLLECT_GARBAGE_LEVEL = "2",

    MINIMUM_COLLECT_TIME_MS = "3",

    _name = "Script",
}

---@param ... unknown
---@return any
function Script.set_index_offset(...) end

---@param ... unknown
---@return any
function Script.index_offset(...) end

---@param ... unknown
---@return any
function Script.disable_low_memory_lua_state_dumps(...) end

---@param ... unknown
---@return any
function Script.do_error_break(...) end

---@param ... unknown
---@return any
function Script.do_break(...) end

---@param ... unknown
---@return any
function Script.deserialize(...) end

---@param ... unknown
---@return any
function Script.xpcall(...) end

---@param ... unknown
---@return any
function Script.pcall(...) end

---@param ... unknown
---@return any
function Script.temp_count(...) end

---@param ... unknown
---@return any
function Script.set_temp_count(...) end

---@param ... unknown
---@return any
function Script.temp_byte_count(...) end

---@param ... unknown
---@return any
function Script.set_temp_byte_count(...) end

---@param ... unknown
---@return any
function Script.type_name(...) end

---@param ... unknown
---@return any
function Script.callstack(...) end

---@param ... unknown
---@return any
function Script.new_table(...) end

---@param arg0 unknown
---@return any
function Script.new_array(arg0) end

---@param arg0 unknown
---@return any
function Script.new_map(arg0) end

---@param ... unknown
---@return any
function Script.id_string_32(...) end

---@param ... unknown
---@return any
function Script.configure_garbage_collection(...) end

---@param ... unknown
---@return any
function Script.serialize(...) end
