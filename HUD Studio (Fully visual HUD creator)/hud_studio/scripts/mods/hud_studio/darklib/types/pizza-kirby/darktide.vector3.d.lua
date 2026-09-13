---@meta

---@class Vector3
---@operator add(Vector3): Vector3
---@operator sub(Vector3): Vector3
---@operator unm(): Vector3
---@operator mul(Vector3): Vector3
---@operator div(Vector3): Vector3
---@field x number
---@field y number
---@field z number
Vector3 = {
    _name = "Vector3",
}

---@param vec_a Vector3
---@param vec_b Vector3
---@return Vector3
function Vector3.add(vec_a, vec_b) end

---@return Vector3
function Vector3.backward() end

---@param index

---@return Vector3
function Vector3.base(index) end

---@param vec_a Vector3
---@param vec_b Vector3
---@return Vector3
function Vector3.cross(vec_a, vec_b) end

---@param vec_a Vector3
---@param vec_b Vector3
---@return number
function Vector3.distance(vec_a, vec_b) end

---@param vec_a Vector3
---@param vec_b Vector3
---@return number
function Vector3.distance_squared(vec_a, vec_b) end

---@param vec Vector3
---@param factor number
---@return Vector3
function Vector3.divide(vec, factor) end

---@param vec_a Vector3
---@param vec_b Vector3
---@return Vector3
function Vector3.divide_elements(vec_a, vec_b) end

---@param vec_a Vector3
---@param vec_b Vector3
---@return number
function Vector3.dot(vec_a, vec_b) end

---@return Vector3
function Vector3.down() end

---@param vec Vector3
---@param index

---@return number
function Vector3.element(vec, index) end

---@param vec_a Vector3
---@param vec_b Vector3
---@return boolean
function Vector3.equal(vec_a, vec_b) end

---@return Vector3
function Vector3.forward() end

---@param vec Vector3
---@return boolean
function Vector3.is_valid(vec) end

---@return Vector3
function Vector3.left() end

---@param vec Vector3
---@return number
function Vector3.length(vec) end

---@param vec_a Vector3
---@param vec_b Vector3
---@param ratio number 0..=1, 0 being closer to vec_a, 1 to vec_b
---@return Vector3
function Vector3.lerp(vec_a, vec_b, ratio) end

---@param vec Vector3
---@return Vector3 y # y vector orthogonal to vec and the z vector
---@return Vector3 z # z vector orthogonal to vec and the y vector
function Vector3.make_axes(vec) end

---@param vec_a Vector3
---@param vec_b Vector3
---@return Vector3
function Vector3.max(vec_a, vec_b) end

---@param vec_a Vector3
---@param vec_b Vector3
---@return Vector3
function Vector3.min(vec_a, vec_b) end

---@param vec Vector3
---@param factor number
---@return Vector3
function Vector3.multiply(vec, factor) end

---@param vec_a Vector3
---@param vec_b Vector3
---@return Vector3
function Vector3.multiply_elements(vec_a, vec_b) end

---@param vec Vector3
---@return Vector3
function Vector3.normalize(vec) end

---@return Vector3
function Vector3.right() end

---@param vec Vector3
---@param index

---@param value number
---@return Vector3
function Vector3.set_element(vec, index, value) end

---@param vec Vector3
---@param value number
---@return Vector3
function Vector3.set_x(vec, value) end

---@param vec Vector3
---@param value number
---@return Vector3
function Vector3.set_y(vec, value) end

---@param vec Vector3
---@param value number
---@return Vector3
function Vector3.set_z(vec, value) end

---@param vec Vector3
---@param x number
---@param y number
---@param z number
---@return Vector3
function Vector3.set_xyz(vec, x, y, z) end

---@param vec_a Vector3
---@param vec_b Vector3
---@return Vector3
function Vector3.subtract(vec_a, vec_b) end

---@param vec Vector3
---@return number x
---@return number y
---@return number z
function Vector3.to_elements(vec) end

---@param vec Vector3
---@return string
function Vector3.to_string(vec) end

---@return Vector3
function Vector3.up() end

---@param vec Vector3
---@return number
function Vector3.x(vec) end

---@param vec Vector3
---@return number
function Vector3.y(vec) end

---@param vec Vector3
---@return number
function Vector3.z(vec) end

---@return Vector3
function Vector3.zero() end

function Vector3.angle(...) end

---@param vec Vector3
---@param min number
---@param max number
---@return Vector3
function Vector3.clamp(vec, min, max) end

---@param vec Vector3
---@return string
function Vector3.compact_string(vec) end

function Vector3.direction_length(...) end

---@param vec Vector3
---@return Vector3
function Vector3.flat(vec) end

---@param vec_a Vector3
---@param vec_b Vector3
---@return number
function Vector3.flat_angle(vec_a, vec_b) end

---@param array number[]
---@return Vector3
function Vector3.from_array(array) end

---@param array number[]
---@return Vector3
function Vector3.from_array_flat(array) end

function Vector3.from_array_table(...) end

---@param _string string
---@return Vector3
function Vector3.from_compact_string(_string) end

---@param _table { x: number, y:number, z:number }
---@return Vector3
function Vector3.from_table(_table) end

---@return Vector3
function Vector3.invalid_vector() end

---@param vec Vector3
---@return number
function Vector3.length_squared(vec) end

---@return Vector3
function Vector3.one() end

---@param vec Vector3
---@param plane_normal Vector3
---@return Vector3
function Vector3.project_on_normal(vec, plane_normal) end

---@param vec Vector3
---@param plane_normal Vector3
---@return Vector3
function Vector3.project_on_plane(vec, plane_normal) end

---@param start Vector3
---@param stop Vector3
---@param d number
---@return number
function Vector3.slerp(start, stop, d) end

---@param t any
---@param vec_a any
---@param vec_b any
---@return Vector3
function Vector3.smoothstep(t, vec_a, vec_b) end

---@param start any
---@param target any
---@param step any
---@return Vector3
---@return boolean
function Vector3.step(start, target, step) end

---@param vec Vector3
---@param array? table
---@return number[]
function Vector3.to_array(vec, array) end

function Vector3.x_axis(...) end

function Vector3.y_axis(...) end

function Vector3.z_axis(...) end
