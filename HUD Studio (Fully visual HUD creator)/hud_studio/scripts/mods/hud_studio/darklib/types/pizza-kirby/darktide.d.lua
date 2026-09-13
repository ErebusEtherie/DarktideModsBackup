---@meta

---@class DarktideClass<T>
---@field new fun(...): T
---@field delete fun(): nil
---@field __class_name string
DarktideClass = {}

---@type Imgui
Imgui = nil

---@class ResolutionLookup
---@field width integer
---@field height integer
---@field scale number
---@field inverse_scale number
---@field fullscreen boolean
RESOLUTION_LOOKUP = nil

---@class Managers
---@field state table
---@field [string] DarktideClass
Managers = {}
function Managers:destroy() end
function Managers.state:destroy() end

---@type {[string]: DarktideClass}
CLASSES = nil
CLASS = CLASSES

---@class ManagersCreationOrder
---@field global table
---@field state table
ManagersCreationOrder = {}

---@class NetworkLookup
---@field mission_objective_names integer[]
NetworkLookup = {}

---@generic T
---@param class_name string
---@param super_name? string
---@return DarktideClass<T>
function class(class_name, super_name) end

---@param condition boolean
---@param message string
---@param ... any format args
function fassert(condition, message, ...) end

---@param message string
---@param ... any format args
function ferror(message, ...) end
