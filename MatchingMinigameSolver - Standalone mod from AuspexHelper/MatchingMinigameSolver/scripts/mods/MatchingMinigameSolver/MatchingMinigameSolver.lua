local mod = get_mod("MatchingMinigameSolver")
local MinigameSettings = require("scripts/settings/minigame/minigame_settings")
local ScannerDisplayViewDecodeSearchSettings = require("scripts/ui/views/scanner_display_view/scanner_display_view_decode_search_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local EXPEDITION_TYPE = rawget(MinigameSettings.types, "decode_search") or rawget(MinigameSettings.types, "expedition")
local HIGHLIGHT_COLOR = {
	110,
	255,
	165,
	0,
}

local function _board_width()
	return MinigameSettings.decode_search_board_width or 5
end

local function _board_height()
	return MinigameSettings.decode_search_board_height or 5
end

local function _cursor_width()
	return MinigameSettings.decode_search_cursor_width or 1
end

local function _cursor_height()
	return MinigameSettings.decode_search_cursor_height or 1
end

local function _normalize_symbol_id(symbol, fallback)
	if type(symbol) == "number" then
		return math.floor(symbol + 0.5)
	end

	if type(symbol) == "string" then
		local numeric = tonumber(symbol)

		if numeric ~= nil then
			return math.floor(numeric + 0.5)
		end
	end

	if type(symbol) ~= "table" then
		return fallback
	end

	local direct = symbol.symbol or symbol.symbol_id or symbol.id or symbol.value

	if direct ~= nil and direct ~= symbol then
		local normalized = _normalize_symbol_id(direct, fallback)

		if normalized ~= nil then
			return normalized
		end
	end

	for index = 1, #symbol do
		local normalized = _normalize_symbol_id(symbol[index], fallback)

		if normalized ~= nil then
			return normalized
		end
	end

	for key, value in pairs(symbol) do
		if key ~= "symbol" and key ~= "symbol_id" and key ~= "id" and key ~= "value" then
			local normalized = _normalize_symbol_id(value, fallback)

			if normalized ~= nil then
				return normalized
			end
		end
	end

	return fallback
end

local function _default_symbol_id()
	local symbols = MinigameSettings.decode_search_symbols

	if type(symbols) == "table" then
		for index = 1, #symbols do
			local normalized = _normalize_symbol_id(symbols[index], nil)

			if normalized ~= nil then
				return normalized
			end
		end
	end

	return 1
end

local function _normalize_grid(grid)
	if type(grid) ~= "table" then
		return nil
	end

	local default_symbol = _default_symbol_id()

	if type(grid[1]) ~= "table" then
		local width = _cursor_width()
		local normalized = {}

		for index = 1, #grid do
			local y = math.floor((index - 1) / width) + 1
			local x = ((index - 1) % width) + 1

			normalized[y] = normalized[y] or {}
			normalized[y][x] = _normalize_symbol_id(grid[index], default_symbol) or default_symbol
		end

		return normalized
	end

	local normalized = {}

	for y = 1, #grid do
		local row = grid[y]

		if type(row) ~= "table" then
			return nil
		end

		normalized[y] = {}

		for x = 1, #row do
			normalized[y][x] = _normalize_symbol_id(row[x], default_symbol) or default_symbol
		end
	end

	return normalized
end

local function _normalize_target_position(target)
	if type(target) ~= "table" then
		return nil
	end

	local target_x = nil
	local target_y = nil

	if target.x ~= nil or target.y ~= nil or target.target_x ~= nil or target.target_y ~= nil then
		target_x = target.x or target.target_x
		target_y = target.y or target.target_y
	elseif #target == 2 and type(target[1]) == "number" and type(target[2]) == "number" then
		target_x = target[1]
		target_y = target[2]
	end

	if type(target_x) ~= "number" or type(target_y) ~= "number" then
		return nil
	end

	local max_x = math.max(_board_width() - _cursor_width() + 1, 1)
	local max_y = math.max(_board_height() - _cursor_height() + 1, 1)

	if target_x >= 0 and target_x <= max_x - 1 then
		target_x = target_x + 1
	end

	if target_y >= 0 and target_y <= max_y - 1 then
		target_y = target_y + 1
	end

	return {
		x = math.clamp(math.floor(target_x + 0.5), 1, max_x),
		y = math.clamp(math.floor(target_y + 0.5), 1, max_y),
	}
end

local function _board_grid_at(symbols, target_x, target_y)
	if type(symbols) ~= "table" then
		return nil
	end

	local board_width = _board_width()
	local board_height = _board_height()
	local cursor_width = _cursor_width()
	local cursor_height = _cursor_height()
	local max_x = math.max(board_width - cursor_width + 1, 1)
	local max_y = math.max(board_height - cursor_height + 1, 1)
	local x = math.clamp(math.floor((target_x or 1) + 0.5), 1, max_x)
	local y = math.clamp(math.floor((target_y or 1) + 0.5), 1, max_y)
	local default_symbol = _default_symbol_id()
	local grid = {}

	for grid_y = 0, cursor_height - 1 do
		grid[grid_y + 1] = {}

		for grid_x = 0, cursor_width - 1 do
			local index = (y + grid_y - 1) * board_width + (x + grid_x)
			grid[grid_y + 1][grid_x + 1] = _normalize_symbol_id(symbols[index], default_symbol) or default_symbol
		end
	end

	return grid
end

local function _grids_equal(left, right)
	left = _normalize_grid(left)
	right = _normalize_grid(right)

	if not left or not right or #left ~= #right then
		return false
	end

	for y = 1, #left do
		local left_row = left[y]
		local right_row = right[y]

		if not left_row or not right_row or #left_row ~= #right_row then
			return false
		end

		for x = 1, #left_row do
			if left_row[x] ~= right_row[x] then
				return false
			end
		end
	end

	return true
end

local function _resolve_minigame(view)
	local extension = view and view._minigame_extension

	if not extension or not extension.minigame then
		return nil
	end

	local minigame = EXPEDITION_TYPE and extension:minigame(EXPEDITION_TYPE) or nil

	if minigame then
		return minigame
	end

	return extension:minigame()
end

local function _cursor_position(minigame)
	if not minigame or not minigame.cursor_position then
		return nil
	end

	local max_x = math.max(_board_width() - _cursor_width() + 1, 1)
	local max_y = math.max(_board_height() - _cursor_height() + 1, 1)
	local raw_cursor = rawget(minigame, "_cursor_position")

	if type(raw_cursor) == "table" then
		local raw_x = raw_cursor.x or raw_cursor[1]
		local raw_y = raw_cursor.y or raw_cursor[2]

		if raw_x ~= nil and raw_y ~= nil then
			return {
				x = math.clamp(math.floor(raw_x + 0.5) + 1, 1, max_x),
				y = math.clamp(math.floor(raw_y + 0.5) + 1, 1, max_y),
			}
		end
	end

	local first, second = minigame:cursor_position()
	local cursor_x = nil
	local cursor_y = nil

	if second ~= nil then
		cursor_x = first
		cursor_y = second
	elseif type(first) == "table" then
		cursor_x = first.x or first[1]
		cursor_y = first.y or first[2]
	else
		local width = _board_width()
		local index = math.floor((first or 1) + 0.5)

		if index >= 0 and index < width * _board_height() then
			index = index + 1
		end

		cursor_x = ((index - 1) % width) + 1
		cursor_y = math.floor((index - 1) / width) + 1
	end

	if cursor_x == nil or cursor_y == nil then
		return nil
	end

	if cursor_x >= 1 and cursor_x <= max_x and cursor_y >= 1 and cursor_y <= max_y then
		return {
			x = math.clamp(math.floor(cursor_x + 0.5), 1, max_x),
			y = math.clamp(math.floor(cursor_y + 0.5), 1, max_y),
		}
	end

	if cursor_x >= 0 and cursor_x <= max_x - 1 then
		cursor_x = cursor_x + 1
	end

	if cursor_y >= 0 and cursor_y <= max_y - 1 then
		cursor_y = cursor_y + 1
	end

	return {
		x = math.clamp(math.floor(cursor_x + 0.5), 1, max_x),
		y = math.clamp(math.floor(cursor_y + 0.5), 1, max_y),
	}
end

local function _grid_for_cell(minigame, target_x, target_y)
	if not minigame then
		return nil
	end

	local getter = minigame.get_symbols_for_target

	if getter then
		local coord_offset = rawget(minigame, "_matching_minigame_solver_coord_offset")

		if coord_offset == nil then
			local cursor = _cursor_position(minigame)
			local current_grid = nil
			local symbols = minigame.symbols and minigame:symbols() or nil

			if cursor and symbols then
				current_grid = _board_grid_at(symbols, cursor.x, cursor.y)
			end

			coord_offset = {
				x = 0,
				y = 0,
			}

			if cursor and current_grid then
				local offset_candidates = {
					{ x = -1, y = -1 },
					{ x = 0, y = 0 },
					{ x = -1, y = 0 },
					{ x = 0, y = -1 },
				}

				for index = 1, #offset_candidates do
					local candidate = offset_candidates[index]
					local ok, grid = pcall(getter, minigame, cursor.x + candidate.x, cursor.y + candidate.y)

					grid = ok and _normalize_grid(grid) or nil

					if _grids_equal(grid, current_grid) then
						coord_offset = candidate
						break
					end
				end
			end

			minigame._matching_minigame_solver_coord_offset = coord_offset
		end

		local offset_x = type(coord_offset) == "table" and (coord_offset.x or 0) or coord_offset or 0
		local offset_y = type(coord_offset) == "table" and (coord_offset.y or 0) or coord_offset or 0
		local ok, grid = pcall(getter, minigame, (target_x or 1) + offset_x, (target_y or 1) + offset_y)

		grid = ok and _normalize_grid(grid) or nil

		if grid then
			return grid
		end
	end

	local symbols = minigame.symbols and minigame:symbols() or nil

	return _board_grid_at(symbols, target_x, target_y)
end

local function _decode_targets(minigame)
	local targets = minigame and minigame._decode_targets or nil

	if targets == nil and minigame and minigame.decode_targets then
		local ok, resolved_targets = pcall(minigame.decode_targets, minigame)

		targets = ok and resolved_targets or nil
	end

	return targets
end

local function _raw_target(minigame)
	local stage = minigame and (minigame.current_stage and minigame:current_stage() or minigame._current_stage) or nil
	local target_positions = minigame and rawget(minigame, "_decode_target_positions") or nil
	local targets = _decode_targets(minigame)

	if not stage then
		return nil
	end

	if type(target_positions) == "table" and target_positions[stage] ~= nil then
		return target_positions[stage]
	end

	return targets and targets[stage] or nil
end

local function _target_grid(minigame)
	if not minigame then
		return nil
	end

	local target = _raw_target(minigame)
	local target_position = _normalize_target_position(target)

	if target_position then
		return _grid_for_cell(minigame, target_position.x, target_position.y)
	end

	return _normalize_grid(target)
end

local function _matching_target_position(minigame)
	local direct_target = _normalize_target_position(_raw_target(minigame))

	if direct_target then
		return direct_target
	end

	local target = _target_grid(minigame)

	if not target or not minigame then
		return nil
	end

	local cursor = _cursor_position(minigame)
	local max_x = math.max(_board_width() - _cursor_width() + 1, 1)
	local max_y = math.max(_board_height() - _cursor_height() + 1, 1)
	local symbols = minigame.symbols and minigame:symbols() or nil
	local default_symbol = _default_symbol_id()
	local best = nil
	local best_distance = math.huge

	for y = 1, max_y do
		for x = 1, max_x do
			local candidate = _grid_for_cell(minigame, x, y)

			if _grids_equal(candidate, target) then
				local distance = cursor and (math.abs(x - cursor.x) + math.abs(y - cursor.y)) or 0

				if distance < best_distance then
					best = { x = x, y = y }
					best_distance = distance
				end
			end
		end
	end

	return best
end

local function _ensure_widgets(view, widget_count)
	if widget_count <= 0 then
		view._matching_minigame_solver_widgets = nil
		return nil
	end

	local widgets = view._matching_minigame_solver_widgets

	if widgets and #widgets == widget_count then
		return widgets
	end

	widgets = {}

	for index = 1, widget_count do
		local widget_definition = UIWidget.create_definition({
			{
				pass_type = "texture",
				style_id = "highlight",
				value = "content/ui/materials/backgrounds/scanner/scanner_decode_symbol_highlight",
				style = {
					hdr = true,
					color = HIGHLIGHT_COLOR,
				},
			},
		}, "center_pivot", nil, ScannerDisplayViewDecodeSearchSettings.symbol_widget_size)

		widgets[index] = UIWidget.init("matching_minigame_solver_" .. tostring(index), widget_definition)
	end

	view._matching_minigame_solver_widgets = widgets

	return widgets
end

mod:hook_require("scripts/ui/views/scanner_display_view/minigame_decode_search_view", function(MinigameDecodeSearchView)
	mod:hook_safe(MinigameDecodeSearchView, "draw_widgets", function(self, dt, t, input_service, ui_renderer)
		if not ui_renderer then
			return
		end

		local minigame = _resolve_minigame(self)
		local current_stage = minigame and minigame.current_stage and minigame:current_stage() or minigame and minigame._current_stage or nil

		if self._matching_minigame_solver_minigame ~= minigame then
			self._matching_minigame_solver_minigame = minigame
			self._matching_minigame_solver_widgets = nil

			if minigame then
				minigame._matching_minigame_solver_coord_offset = nil
			end
		end

		if self._matching_minigame_solver_stage ~= current_stage then
			self._matching_minigame_solver_stage = current_stage

			if minigame then
				minigame._matching_minigame_solver_coord_offset = nil
			end
		end

		if not minigame or not minigame.symbols or not minigame.current_stage then
			return
		end

		local target_position = _matching_target_position(minigame)

		if not target_position then
			return
		end

		local matches = {}
		local board_width = _board_width()
		local cursor_width = _cursor_width()
		local cursor_height = _cursor_height()

		for y = 0, cursor_height - 1 do
			for x = 0, cursor_width - 1 do
				matches[#matches + 1] = (target_position.y + y - 1) * board_width + (target_position.x + x)
			end
		end

		local widgets = _ensure_widgets(self, #matches)

		if not widgets then
			return
		end

		local widget_size = ScannerDisplayViewDecodeSearchSettings.symbol_widget_size
		local spacing = ScannerDisplayViewDecodeSearchSettings.symbol_spacing or 0
		local starting_offset_x = ScannerDisplayViewDecodeSearchSettings.symbol_starting_offset_x or 0
		local starting_offset_y = ScannerDisplayViewDecodeSearchSettings.symbol_starting_offset_y or 0

		for match_index = 1, #matches do
			local symbol_index = matches[match_index]
			local widget = widgets[match_index]
			local x = ((symbol_index - 1) % board_width) + 1
			local y = math.floor((symbol_index - 1) / board_width) + 1

			widget.style.highlight.color = HIGHLIGHT_COLOR
			widget.offset[1] = starting_offset_x + (widget_size[1] + spacing) * (x - 1)
			widget.offset[2] = starting_offset_y + (widget_size[2] + spacing) * (y - 1)
			widget.offset[3] = 6

			UIWidget.draw(widget, ui_renderer)
		end
	end)
end)
