

---@param Module DLH_ModMenu
return function(Module)
	if Module.presentation then
		return Module.presentation
	end

	local C = Module.constants

	local Presentation = {}

	---@param i integer
	---@return { x: number, y: number, w: number, h: number }
	function Presentation.nav_button_local(i)
		return {
			x = 0,
			y = C.NAV_LIST_TOP + (i - 1) * (C.NAV_BTN_H + C.NAV_BTN_GAP),
			w = C.NAV_WIDTH,
			h = C.NAV_BTN_H,
		}
	end

	---@return { x: number, y: number, w: number, h: number }
	function Presentation.secret_button_local()
		local b = C.SECRET_BTN
		local cx = C.NAV_WIDTH / 2 + b.offset_x
		local cy = C.NAV_HEIGHT / 2 + b.offset_y
		return { x = cx - b.w / 2, y = cy - b.h / 2, w = b.w, h = b.h }
	end

	---@return { x: number, y: number, w: number, h: number }
	function Presentation.secret_proximity_local()
		local r = Presentation.secret_button_local()
		local pad = C.SECRET_BTN_PROXIMITY
		local left = math.max(r.x - pad, 0)
		local right = math.min(r.x + r.w + pad, C.NAV_WIDTH)
		return { x = left, y = r.y - pad, w = right - left, h = r.h + pad * 2 }
	end

	---@param i integer
	---@return { x: number, y: number, w: number, h: number }
	function Presentation.aside_row_local(i)
		return {
			x = C.ASIDE_PAD_X,
			y = C.ASIDE_LIST_TOP + (i - 1) * C.ASIDE_ROW_H,
			w = C.ASIDE_WIDTH - C.ASIDE_PAD_X * 2,
			h = C.ASIDE_ROW_H,
		}
	end

	Module.presentation = Presentation

	return Presentation
end
