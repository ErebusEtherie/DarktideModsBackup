---@meta

---@class ColorUtilities
ColorUtilities = {}

---@param source table | Vector4
---@param ignore_alpha? boolean
ColorUtilities.clone = function(source, ignore_alpha) end

---@param source table | Vector4
---@param target? table | Vector4
---@param ignore_alpha? boolean
ColorUtilities.color_copy = function(source, target, ignore_alpha) end

---@param source table | Vector4
---@param target table | Vector4
---@param factor number
---@param out table | Vector4 where to put the result
---@param ignore_alpha boolean
---@return table [1] is nil if `ignore_alpha` is truthy
ColorUtilities.color_lerp = function(source, target, factor, out, ignore_alpha) end

---@param source table | Vector4
ColorUtilities.format_color_to_material = function(source) end

---@param h number
---@param s number
---@param l number
---@return integer r
---@return integer g
---@return integer b
ColorUtilities.hsl2rgb = function (h, s, l) end
