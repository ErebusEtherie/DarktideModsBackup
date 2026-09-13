---@meta

---@class Vector3Box
---@field x number
---@field y number
---@field z number
---@operator len(): number
---@operator call(number): Vector3Box
---@overload fun(x: number, y: number, z:number): Vector3Box
---@overload fun(vec: Vector3): Vector3Box
---@overload fun(): Vector3Box
Vector3Box = {}

---@param vec Vector3
---@return nil
function Vector3Box:store(vec) end

---@param x number
---@param y number
---@param z number
---@return nil
function Vector3Box:store(x, y, z) end

---@return Vector3
function Vector3Box:unbox() end
