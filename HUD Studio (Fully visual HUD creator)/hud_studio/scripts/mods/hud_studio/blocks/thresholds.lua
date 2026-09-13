---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_thresholds then
	return mod.hud_studio_thresholds
end

local Thresholds = {}

Thresholds.DEFAULT_COLOR = { 255, 120, 220, 255 }

Thresholds.BOOL_ROWS = {
	{ text = "True" },
	{ text = "False" },
	{ text = "Unset" },
}

function Thresholds.pct(current, max)
	local c = tonumber(current) or 0
	local m = tonumber(max) or 0
	if m <= 0 then
		return 0
	end
	return c / m * 100
end

function Thresholds.value(current)
	return tonumber(current) or 0
end

---@param v any
---@return integer index
function Thresholds.bool_index(v)
	if v == nil then
		return 3
	end
	return v and 1 or 2
end

---@param list table[]|nil
---@param v any
---@return table|nil entry
function Thresholds.bool_at(list, v)
	if not list then
		return nil
	end
	local e = list[Thresholds.bool_index(v)]
	return (type(e) == "table") and e or nil
end

---@param list table[]|nil
---@param v any
---@param default table?
---@return table color { a, r, g, b }
function Thresholds.bool_color_at(list, v, default)
	local entry = Thresholds.bool_at(list, v)
	return (entry and entry.color) or default or Thresholds.DEFAULT_COLOR
end

function Thresholds.at(list, pct)
	if not list or #list == 0 then
		return nil
	end
	local best, lowest = nil, nil
	for i = 1, #list do
		local e = list[i]
		if type(e) == "table" and type(e.pct) == "number" then
			if e.pct <= pct and (not best or e.pct > best.pct) then
				best = e
			end
			if not lowest or e.pct < lowest.pct then
				lowest = e
			end
		end
	end
	return best or lowest
end

function Thresholds.color_at(list, pct, default)
	local entry = Thresholds.at(list, pct)
	return (entry and entry.color) or default or Thresholds.DEFAULT_COLOR
end

function Thresholds.bands(list, default, scale)
	local color = default or Thresholds.DEFAULT_COLOR

	if scale == "boolean" then
		local bands = {}
		local n = #Thresholds.BOOL_ROWS
		for i = 1, n do
			local e = list and list[i]
			bands[i] = {
				lo = (i - 1) / n * 100,
				hi = i / n * 100,
				color = (type(e) == "table" and e.color) or color,
			}
		end
		return bands
	end

	if not list or #list == 0 then
		return { { lo = 0, hi = 100, color = color } }
	end

	local equal_widths = scale == "number"

	local sorted = {}
	for i = 1, #list do
		local e = list[i]
		if type(e) == "table" and type(e.pct) == "number" then
			sorted[#sorted + 1] = e
		end
	end
	if #sorted == 0 then
		return { { lo = 0, hi = 100, color = color } }
	end
	table.sort(sorted, function(a, b)
		return a.pct < b.pct
	end)
	local bands = {}
	local n = #sorted
	local bottom = math.min(0, sorted[1].pct)
	local top = math.max(100, sorted[n].pct)
	local span = top - bottom
	for i = 1, n do
		local lo, hi
		if equal_widths then
			lo = (i - 1) / n * 100
			hi = i / n * 100
		else
			local lo_value = (i == 1) and bottom or sorted[i].pct
			local hi_value = (i < n) and sorted[i + 1].pct or top
			lo = (lo_value - bottom) / span * 100
			hi = (hi_value - bottom) / span * 100
		end
		bands[#bands + 1] = { lo = lo, hi = hi, color = sorted[i].color or color }
	end
	return bands
end

mod.hud_studio_thresholds = Thresholds

return Thresholds
