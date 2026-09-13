---@meta

---@class ModManager
ModManager = {}

Managers = Managers or {}

---@type ModManager
Managers.mod = nil

---@return boolean enabled
function ModManager:developer_mode_enabled() end

function ModManager:_draw_state_to_gui() end

function ModManager:remove_gui() end

---@return true
function ModManager:_has_enabled_mods() end

---@return boolean
function ModManager:_check_reload() end

function ModManager:update() end
