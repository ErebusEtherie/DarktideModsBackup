

---@param mod mod
return function(mod)

	local UV = {}

	---@return number[][]
	function UV.none()
		return { { 0, 0 }, { 1, 1 } }
	end

	---@return number[][]
	function UV.flip_x()
		return { { 1, 0 }, { 0, 1 } }
	end

	---@return number[][]
	function UV.flip_y()
		return { { 0, 1 }, { 1, 0 } }
	end

	---@return number[][]
	function UV.flip_xy()
		return { { 1, 1 }, { 0, 0 } }
	end

	---@return number[][]
	function UV.rotate_180()
		return { { 1, 1 }, { 0, 0 } }
	end

	---@param x number left edge (0 = material left)
	---@param y number top edge (0 = material top)
	---@param w number width
	---@param h number height
	---@return number[][]
	function UV.rect(x, y, w, h)
		return { { x, y }, { x + w, y + h } }
	end

	---@param frac number fraction of width to keep from the left
	---@return number[][]
	function UV.clip_left(frac)
		return { { 0, 0 }, { frac, 1 } }
	end

	---@param frac number fraction of width to keep from the right
	---@return number[][]
	function UV.clip_right(frac)
		return { { 1 - frac, 0 }, { 1, 1 } }
	end

	---@param frac number fraction of height to keep from the top
	---@return number[][]
	function UV.clip_top(frac)
		return { { 0, 0 }, { 1, frac } }
	end

	---@param frac number fraction of height to keep from the bottom
	---@return number[][]
	function UV.clip_bottom(frac)
		return { { 0, 1 - frac }, { 1, 1 } }
	end

	---@param w number width fraction to keep
	---@param h number height fraction to keep
	---@return number[][]
	function UV.clip_top_left(w, h)
		return { { 0, 0 }, { w, h } }
	end

	---@param w number width fraction to keep
	---@param h number height fraction to keep
	---@return number[][]
	function UV.clip_top_right(w, h)
		return { { 1 - w, 0 }, { 1, h } }
	end

	---@param w number width fraction to keep
	---@param h number height fraction to keep
	---@return number[][]
	function UV.clip_bottom_left(w, h)
		return { { 0, 1 - h }, { w, 1 } }
	end

	---@param w number width fraction to keep
	---@param h number height fraction to keep
	---@return number[][]
	function UV.clip_bottom_right(w, h)
		return { { 1 - w, 1 - h }, { 1, 1 } }
	end

	---@param w number width fraction to keep
	---@param h number height fraction to keep
	---@return number[][]
	function UV.clip_center(w, h)
		return { { (1 - w) * 0.5, (1 - h) * 0.5 }, { (1 + w) * 0.5, (1 + h) * 0.5 } }
	end

	---@param x number fraction to trim off the left and right edges
	---@param y? number fraction to trim off the top and bottom edges (defaults to x)
	---@return number[][]
	function UV.inset(x, y)
		y = y or x
		return { { x, y }, { 1 - x, 1 - y } }
	end

	---@param uvs number[][]
	---@return number[][]
	function UV.flip_x_of(uvs)
		return { { uvs[2][1], uvs[1][2] }, { uvs[1][1], uvs[2][2] } }
	end

	---@param uvs number[][]
	---@return number[][]
	function UV.flip_y_of(uvs)
		return { { uvs[1][1], uvs[2][2] }, { uvs[2][1], uvs[1][2] } }
	end

	---@param uvs number[][]
	---@return number[][]
	function UV.flip_xy_of(uvs)
		return { { uvs[2][1], uvs[2][2] }, { uvs[1][1], uvs[1][2] } }
	end

	return UV
end
