---@meta

---@class Quaternion
Quaternion = {
    _name = "Quaternion",
}

---@param quat Quaternion
---@return Vector3 facing_direction
---@return number rotation_angle
function Quaternion.decompose(quat) end

---@param quat_a Quaternion
---@param quat_b Quaternion
---@return Quaternion
function Quaternion.multiply(quat_a,quat_b) end

---@param quat Quaternion
---@param x number
---@param y number
---@param z number
---@param w number
---@return Quaternion
function Quaternion.set_xyzw(quat,x ,y ,z ,w) end

---@param quat_a Quaternion
---@param quat_b Quaternion
---@return boolean equal
function Quaternion.equal(quat_a, quat_b) end

---@param quat Quaternion
---@return string
function Quaternion.to_string(quat) end

---@param quat Quaternion
---@return Vector3
function Quaternion.right(quat) end

---@param quat Quaternion
---@return Vector3
function Quaternion.forward(quat) end

---@param quat Quaternion
---@return Vector3
function Quaternion.up(quat) end

---@param quat Quaternion
---@return Quaternion normalized
function Quaternion.normalize(quat) end

---@param quat_a Quaternion
---@param quat_b Quaternion
---@return number dot_product
function Quaternion.dot(quat_a, quat_b) end

---@param quat_a Quaternion
---@return number rotation_angle
function Quaternion.angle(quat_a) end

---@param quat_a Quaternion
---@param quat_b Quaternion
---@param ratio number 0..=1, 0 creates rotation closer to quat, 1 to quat_b
---@return Quaternion
function Quaternion.lerp(quat_a, quat_b, ratio) end

---@param quat Quaternion
---@return boolean
function Quaternion.is_valid(quat) end

---@param quat Quaternion
---@return number x
---@return number y
---@return number z
---@return number w
function Quaternion.to_elements(quat) end

---@param quat Quaternion
---@return Quaternion
function Quaternion.flat_no_roll(quat) end

---@param quat Quaternion
---@param vector Vector3
---@return Quaternion
function Quaternion.rotate(quat, vector) end

---@param quat Quaternion
---@return Matrix4x4
function Quaternion.matrix4x4(quat) end

---@param x number
---@param y number
---@param z number
---@param w number
---@return Quaternion
function Quaternion.from_elements(x,y,z,w) end

---@return Quaternion
function Quaternion.identity() end

---@param axis Vector3
---@param angle number in radians
---@return Quaternion
function Quaternion.axis_angle(axis, angle) end

---@param matrix Matrix4x4
---@return Quaternion
function Quaternion.from_matrix4x4(matrix) end

---@param dir Vector3
---@param up? Vector3 default: (0,0,1) positive z direction is used
---@return Quaternion
function Quaternion.look(dir, up) end

---@param x number
---@param y number
---@param z number
---@return Quaternion
function Quaternion.from_euler_angles_xyz(x,y,z) end

---@param quat Quaternion
---@return number x
---@return number y
---@return number z
function Quaternion.to_euler_angles_xyz(quat) end

---@param yaw number
---@param pitch number
---@param roll number
---@return Quaternion
function Quaternion.from_yaw_pitch_roll(yaw, pitch, roll) end

---@param quat Quaternion
---@return number yaw
---@return number pitch
---@return number roll
function Quaternion.to_yaw_pitch_roll(quat) end

---@param quat_a Quaternion
---@param quat_b Quaternion
---@param scalar number
---@return Quaternion
function Quaternion.multiply_scalar(quat_a, quat_b, scalar) end

---@param quat_a Quaternion
---@param quat_b Quaternion
---@return Quaternion
function Quaternion.add_elements(quat_a, quat_b) end

---@param quat Quaternion
---@return number yaw
function Quaternion.yaw(quat) end

---@param quat Quaternion
---@return number pitch
function Quaternion.pitch(quat) end

---@param quat Quaternion
---@return number roll
function Quaternion.roll(quat) end

---@param quat Quaternion
---@return Quaternion
function Quaternion.inverse(quat) end

---@param quat Quaternion
---@return Quaternion conjugate
function Quaternion.conjugate(quat) end

---@param quat Quaternion
---@return number norm
function Quaternion.norm(quat) end
