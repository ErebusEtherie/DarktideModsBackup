local mod = get_mod("minimap")
local StrikemapCompatibility = mod:io_dofile("minimap/scripts/mods/minimap/compatibility/minimap_strikemap")

local Color = Color
local Gui = Gui
local Quaternion = Quaternion
local Vector2 = Vector2
local Vector3 = Vector3
local pairs = pairs
local pcall = pcall
local tonumber = tonumber
local tostring = tostring
local type = type
local math_floor = math.floor
local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt
local string_format = string.format
local string_gmatch = string.gmatch
local string_match = string.match

local Gui_triangle = Gui and Gui.triangle
local Quaternion_forward = Quaternion and Quaternion.forward
local Vector3_x = Vector3 and Vector3.x
local Vector3_y = Vector3 and Vector3.y

local TRIANGLE_STRIDE = 7
local CURRENT_FLOOR_HALF_HEIGHT = 2.6
local BAND_CURRENT_FALLBACK_COLOR = { 120, 101, 133, 96 }
local BAND_ABOVE_FALLBACK_COLOR = { 40, 120, 150, 185 }
local BAND_BELOW_FALLBACK_COLOR = { 60, 120, 98, 76 }
local DEFAULT_RANGE_ABOVE = 3
local DEFAULT_RANGE_BELOW = 7
local GRID_CELL_HASH_OFFSET = 4096
local GRID_CELL_HASH_STRIDE = 8192
local MAX_TRIANGLE_DRAWS_PER_FRAME = 3000
local CULL_RANGE_FACTOR = 1.4143

local _grid = {
    context = nil,
    triangles = nil,
    tri_count = 0,
    inverse_grid_cell = 1 / 16,
    cells = {},
    stamp = {},
    frame_id = 0,
    min_cx = 0,
    max_cx = -1,
    min_cy = 0,
    max_cy = -1,
    draw_cap_logged = false,
}

local _vector_grid = {
    context = nil,
    contours = nil,
    contour_count = 0,
    contours_cells = {},
    contours_stamp = {},
    stairs = nil,
    stair_count = 0,
    stairs_cells = {},
    stairs_stamp = {},
    slopes = nil,
    slope_count = 0,
    slopes_cells = {},
    slopes_stamp = {},
    frame_id = 0,
    inverse_grid_cell = 1 / 16,
    min_cx = 0,
    max_cx = -1,
    min_cy = 0,
    max_cy = -1,
}

local function _reset_grid()
    _grid.context = nil
    _grid.triangles = nil
    _grid.tri_count = 0
    _grid.inverse_grid_cell = 1 / 16
    _grid.cells = {}
    _grid.stamp = {}
    _grid.frame_id = 0
    _grid.min_cx = 0
    _grid.max_cx = -1
    _grid.min_cy = 0
    _grid.max_cy = -1
    _grid.draw_cap_logged = false

    _vector_grid.context = nil
    _vector_grid.contours = nil
    _vector_grid.contour_count = 0
    _vector_grid.contours_cells = {}
    _vector_grid.contours_stamp = {}
    _vector_grid.stairs = nil
    _vector_grid.stair_count = 0
    _vector_grid.stairs_cells = {}
    _vector_grid.stairs_stamp = {}
    _vector_grid.slopes = nil
    _vector_grid.slope_count = 0
    _vector_grid.slopes_cells = {}
    _vector_grid.slopes_stamp = {}
    _vector_grid.frame_id = 0
    _vector_grid.min_cx = 0
    _vector_grid.max_cx = -1
    _vector_grid.min_cy = 0
    _vector_grid.max_cy = -1
end

mod._strikemap_geometry_renderer_reset = _reset_grid

local function _forward_xy(rotation)
    if not rotation or not Quaternion_forward or not Vector3_x or not Vector3_y then
        return nil, nil
    end

    local ok, direction = pcall(Quaternion_forward, rotation)

    if not ok or not direction then
        return nil, nil
    end

    local ok_x, x = pcall(Vector3_x, direction)
    local ok_y, y = pcall(Vector3_y, direction)

    x = ok_x and tonumber(x) or nil
    y = ok_y and tonumber(y) or nil

    if not x or not y or x ~= x or y ~= y then
        return nil, nil
    end

    local length = math_sqrt(x * x + y * y)

    if length <= 0 or length == math_huge then
        return nil, nil
    end

    return x / length, y / length
end

local function _build_grid(context)
    local triangles = context.triangles
    local spatial_index = context.spatial_index
    local grid_cell = tonumber(context.grid_cell)
    local tri_count = tonumber(context.tri_count)
        or (type(triangles) == "table" and math_floor(#triangles / TRIANGLE_STRIDE))
        or 0

    if type(triangles) ~= "table" or type(spatial_index) ~= "table"
        or not grid_cell or grid_cell <= 0 or tri_count <= 0 then
        error("the Strikemap map context is missing usable geometry data")
    end

    if type(triangles[1]) ~= "number" or type(triangles[tri_count * TRIANGLE_STRIDE]) ~= "number" then
        error("the Strikemap map context uses an unsupported triangle format")
    end

    local cells = {}
    local stamp = {}
    local cell_count = 0
    local grid_min_cx = math_huge
    local grid_max_cx = -math_huge
    local grid_min_cy = math_huge
    local grid_max_cy = -math_huge

    for i = 1, tri_count do
        stamp[i] = 0
    end

    for key, packed in pairs(spatial_index) do
        local gx, gy = string_match(tostring(key), "^(-?%d+):(-?%d+)$")

        gx = tonumber(gx)
        gy = tonumber(gy)

        if gx and gy and type(packed) == "string" then
            local bucket = nil

            for token in string_gmatch(packed, "[^,]+") do
                local index = tonumber(token)

                if index and index >= 1 and index <= tri_count then
                    if not bucket then
                        bucket = {}
                    end

                    bucket[#bucket + 1] = index
                end
            end

            if bucket then
                cells[(gx + GRID_CELL_HASH_OFFSET) * GRID_CELL_HASH_STRIDE + gy + GRID_CELL_HASH_OFFSET] = bucket
                cell_count = cell_count + 1

                if gx < grid_min_cx then
                    grid_min_cx = gx
                end

                if gx > grid_max_cx then
                    grid_max_cx = gx
                end

                if gy < grid_min_cy then
                    grid_min_cy = gy
                end

                if gy > grid_max_cy then
                    grid_max_cy = gy
                end
            end
        end
    end

    if cell_count == 0 then
        error("the Strikemap spatial index is empty or malformed")
    end

    _grid.context = context
    _grid.triangles = triangles
    _grid.tri_count = tri_count
    _grid.inverse_grid_cell = 1 / grid_cell
    _grid.cells = cells
    _grid.stamp = stamp
    _grid.frame_id = 0
    _grid.min_cx = grid_min_cx
    _grid.max_cx = grid_max_cx
    _grid.min_cy = grid_min_cy
    _grid.max_cy = grid_max_cy
    _grid.draw_cap_logged = false

    if mod:get("debug_mode") == true then
        mod:info(string_format("[minimap] Strikemap geometry grid parsed | map=%s triangles=%d cells=%d",
            tostring(context.map_id or context.mission_name), tri_count, cell_count))
    end
end

local function _ensure_grid(context)
    if _grid.context ~= context then
        _build_grid(context)
    end
end

local function _hash_segments(segments, stride, count, grid_cell, cells, stamp, grid_extents)
    if count == 0 or not segments then return end
    local inv_cell = 1 / grid_cell
    for i = 1, count do
        stamp[i] = 0
        local base = (i - 1) * stride
        local x1 = segments[base + 1]
        local y1 = segments[base + 2]
        local x2 = segments[base + 3]
        local y2 = segments[base + 4]

        local cx1 = math_floor(math_min(x1, x2) * inv_cell)
        local cx2 = math_floor(math_max(x1, x2) * inv_cell)
        local cy1 = math_floor(math_min(y1, y2) * inv_cell)
        local cy2 = math_floor(math_max(y1, y2) * inv_cell)

        for cx = cx1, cx2 do
            for cy = cy1, cy2 do
                local row_key = (cx + GRID_CELL_HASH_OFFSET) * GRID_CELL_HASH_STRIDE
                local key = row_key + cy + GRID_CELL_HASH_OFFSET
                local bucket = cells[key]
                if not bucket then
                    bucket = {}
                    cells[key] = bucket
                end
                bucket[#bucket + 1] = i
                
                if cx < grid_extents[1] then grid_extents[1] = cx end
                if cx > grid_extents[2] then grid_extents[2] = cx end
                if cy < grid_extents[3] then grid_extents[3] = cy end
                if cy > grid_extents[4] then grid_extents[4] = cy end
            end
        end
    end
end

local function _build_vector_grid(vector_context, grid_cell)
    local cells_c, stamp_c = {}, {}
    local cells_st, stamp_st = {}, {}
    local cells_sl, stamp_sl = {}, {}
    local extents = { math_huge, -math_huge, math_huge, -math_huge }

    local contours = vector_context.contours
    local contour_count = vector_context.contour_count or 0
    local contour_stride = vector_context.contour_stride or 5
    _hash_segments(contours, contour_stride, contour_count, grid_cell, cells_c, stamp_c, extents)

    local stairs = vector_context.stairs
    local stair_count = vector_context.stair_count or 0
    local stair_stride = vector_context.stair_stride or 6
    _hash_segments(stairs, stair_stride, stair_count, grid_cell, cells_st, stamp_st, extents)

    local slopes = vector_context.slopes
    local slope_count = vector_context.slope_count or 0
    local slope_stride = vector_context.slope_stride or 5
    _hash_segments(slopes, slope_stride, slope_count, grid_cell, cells_sl, stamp_sl, extents)

    _vector_grid.context = vector_context
    _vector_grid.contours = contours
    _vector_grid.contour_count = contour_count
    _vector_grid.contour_stride = contour_stride
    _vector_grid.contours_cells = cells_c
    _vector_grid.contours_stamp = stamp_c

    _vector_grid.stairs = stairs
    _vector_grid.stair_count = stair_count
    _vector_grid.stair_stride = stair_stride
    _vector_grid.stairs_cells = cells_st
    _vector_grid.stairs_stamp = stamp_st

    _vector_grid.slopes = slopes
    _vector_grid.slope_count = slope_count
    _vector_grid.slope_stride = slope_stride
    _vector_grid.slopes_cells = cells_sl
    _vector_grid.slopes_stamp = stamp_sl
    
    _vector_grid.frame_id = 0
    _vector_grid.inverse_grid_cell = 1 / grid_cell
    
    if extents[1] ~= math_huge then
        _vector_grid.min_cx = extents[1]
        _vector_grid.max_cx = extents[2]
        _vector_grid.min_cy = extents[3]
        _vector_grid.max_cy = extents[4]
    else
        _vector_grid.min_cx = 0
        _vector_grid.max_cx = -1
        _vector_grid.min_cy = 0
        _vector_grid.max_cy = -1
    end
end

local function _ensure_vector_grid(vector_context, grid_cell)
    if _vector_grid.context ~= vector_context then
        _build_vector_grid(vector_context, grid_cell)
    end
end

local _poly_ax, _poly_ay = {}, {}
local _poly_bx, _poly_by = {}, {}

local function _clip_halfplane(src_x, src_y, src_count, dst_x, dst_y, nx, ny, limit)
    local count = 0
    if src_count == 0 then return 0 end

    local prev_x = src_x[src_count]
    local prev_y = src_y[src_count]
    local prev_inside = (nx * prev_x + ny * prev_y) <= limit

    for i = 1, src_count do
        local x = src_x[i]
        local y = src_y[i]
        local inside = (nx * x + ny * y) <= limit

        if inside ~= prev_inside then
            local denom = (x - prev_x) * nx + (y - prev_y) * ny
            if denom ~= 0 then
                local t = (limit - (prev_x * nx + prev_y * ny)) / denom
                count = count + 1
                dst_x[count] = prev_x + (x - prev_x) * t
                dst_y[count] = prev_y + (y - prev_y) * t
            end
        end

        if inside then
            count = count + 1
            dst_x[count] = x
            dst_y[count] = y
        end

        prev_x = x
        prev_y = y
        prev_inside = inside
    end

    return count
end

local _square_nx = {1, -1, 0, 0}
local _square_ny = {0, 0, 1, -1}

local function _clip_triangle_to_square(px1, py1, px2, py2, px3, py3, limit)
    local ax, ay = _poly_ax, _poly_ay
    local bx, by = _poly_bx, _poly_by

    ax[1], ay[1] = px1, py1
    ax[2], ay[2] = px2, py2
    ax[3], ay[3] = px3, py3

    local count = 3

    for i = 1, 4 do
        count = _clip_halfplane(ax, ay, count, bx, by, _square_nx[i], _square_ny[i], limit)
        if count < 3 then return 0, ax, ay end
        local tmp_x, tmp_y = ax, ay
        ax, ay = bx, by
        bx, by = tmp_x, tmp_y
    end

    return count, ax, ay
end

local _circle_nx = {}
local _circle_ny = {}
for i = 1, 16 do
    local angle = (i - 1) * math.pi / 8
    _circle_nx[i] = math.cos(angle)
    _circle_ny[i] = math.sin(angle)
end

local function _clip_triangle_to_circle(px1, py1, px2, py2, px3, py3, limit)
    local ax, ay = _poly_ax, _poly_ay
    local bx, by = _poly_bx, _poly_by

    ax[1], ay[1] = px1, py1
    ax[2], ay[2] = px2, py2
    ax[3], ay[3] = px3, py3

    local count = 3

    for i = 1, 16 do
        count = _clip_halfplane(ax, ay, count, bx, by, _circle_nx[i], _circle_ny[i], limit)
        if count < 3 then return 0, ax, ay end
        local tmp_x, tmp_y = ax, ay
        ax, ay = bx, by
        bx, by = tmp_x, tmp_y
    end

    return count, ax, ay
end

local _triangle_supported = nil

local function _probe_triangle(gui)
    if not Gui_triangle or not Vector3 then
        return false
    end

    local ok = pcall(Gui_triangle, gui,
        Vector3(-40, 0, -40), Vector3(-39, 0, -40), Vector3(-40, 0, -39), 0, Color(0, 0, 0, 0))

    return ok == true
end

local function _submit_triangle(gui, sx1, sy1, sx2, sy2, sx3, sy3, layer, color)
    Gui_triangle(
        gui,
        Vector3(sx1, 0, sy1),
        Vector3(sx2, 0, sy2),
        Vector3(sx3, 0, sy3),
        layer,
        color
    )
end

local function _draw_triangle_clipped(gui, scale, screen_center_x, screen_center_y, px1, py1, px2, py2, px3, py3, limit, limit_sq, is_circle, layer, color)
    local draws = 0
    if not ((px1 > limit and px2 > limit and px3 > limit)
            or (px1 < -limit and px2 < -limit and px3 < -limit)
            or (py1 > limit and py2 > limit and py3 > limit)
            or (py1 < -limit and py2 < -limit and py3 < -limit)) then
        if is_circle then
            if px1 * px1 + py1 * py1 <= limit_sq
                and px2 * px2 + py2 * py2 <= limit_sq
                and px3 * px3 + py3 * py3 <= limit_sq then
                _submit_triangle(gui,
                    screen_center_x + px1 * scale, screen_center_y + py1 * scale,
                    screen_center_x + px2 * scale, screen_center_y + py2 * scale,
                    screen_center_x + px3 * scale, screen_center_y + py3 * scale,
                    layer, color)
                draws = draws + 1
            else
                local clip_count, res_x, res_y = _clip_triangle_to_circle(px1, py1, px2, py2, px3, py3, limit * 0.99)
                if clip_count >= 3 then
                    local fx = screen_center_x + res_x[1] * scale
                    local fy = screen_center_y + res_y[1] * scale
                    for k = 2, clip_count - 1 do
                        _submit_triangle(gui, fx, fy,
                            screen_center_x + res_x[k] * scale, screen_center_y + res_y[k] * scale,
                            screen_center_x + res_x[k + 1] * scale, screen_center_y + res_y[k + 1] * scale,
                            layer, color)
                        draws = draws + 1
                    end
                end
            end
        elseif px1 >= -limit and px1 <= limit and py1 >= -limit and py1 <= limit
            and px2 >= -limit and px2 <= limit and py2 >= -limit and py2 <= limit
            and px3 >= -limit and px3 <= limit and py3 >= -limit and py3 <= limit then
            _submit_triangle(gui,
                screen_center_x + px1 * scale, screen_center_y + py1 * scale,
                screen_center_x + px2 * scale, screen_center_y + py2 * scale,
                screen_center_x + px3 * scale, screen_center_y + py3 * scale,
                layer, color)
            draws = draws + 1
        else
            local clip_count, res_x, res_y = _clip_triangle_to_square(px1, py1, px2, py2, px3, py3, limit)
            if clip_count >= 3 then
                local fx = screen_center_x + res_x[1] * scale
                local fy = screen_center_y + res_y[1] * scale
                for k = 2, clip_count - 1 do
                    _submit_triangle(gui, fx, fy,
                        screen_center_x + res_x[k] * scale, screen_center_y + res_y[k] * scale,
                        screen_center_x + res_x[k + 1] * scale,
                        screen_center_y + res_y[k + 1] * scale,
                        layer, color)
                    draws = draws + 1
                end
            end
        end
    end
    return draws
end

local function _draw_line(gui, scale, screen_center_x, screen_center_y, px1, py1, px2, py2, limit, limit_sq, is_circle, thickness, layer, color)
    local dx, dy = px2 - px1, py2 - py1
    local len = math_sqrt(dx * dx + dy * dy)
    if len <= 0.001 then return 0 end
    local nx = -dy / len * thickness * 0.5
    local ny = dx / len * thickness * 0.5
    local draws = 0
    draws = draws + _draw_triangle_clipped(gui, scale, screen_center_x, screen_center_y, px1 + nx, py1 + ny, px2 + nx, py2 + ny, px2 - nx, py2 - ny, limit, limit_sq, is_circle, layer, color)
    draws = draws + _draw_triangle_clipped(gui, scale, screen_center_x, screen_center_y, px1 + nx, py1 + ny, px2 - nx, py2 - ny, px1 - nx, py1 - ny, limit, limit_sq, is_circle, layer, color)
    return draws
end

local function _band_color(prefix, fallback)
    local r = mod:get(prefix .. "_r") or fallback[2]
    local g = mod:get(prefix .. "_g") or fallback[3]
    local b = mod:get(prefix .. "_b") or fallback[4]
    local alpha = mod:get(prefix .. "_opacity") or fallback[1]

    if alpha <= 0 then
        return nil
    end

    return Color(alpha, r, g, b)
end

local function _clamp_band_range(value, default_value)
    value = tonumber(value) or default_value

    if value < 1 then
        value = 1
    elseif value > 30 then
        value = 30
    end

    return value
end

local function _draw_geometry(ui_renderer, context, player_pos, rotation, center_x, center_y, z, projection_radius,
                              range, radar_style)
    local current_color = _band_color("color_strike_map_floor_current", BAND_CURRENT_FALLBACK_COLOR)
    local above_color = _band_color("color_strike_map_floor_above", BAND_ABOVE_FALLBACK_COLOR)
    local below_color = _band_color("color_strike_map_floor_below", BAND_BELOW_FALLBACK_COLOR)

    if not current_color and not above_color and not below_color then
        return
    end

    local range_above = mod:get("strike_map_height") or DEFAULT_RANGE_ABOVE
    local range_below = mod:get("strike_map_depth") or DEFAULT_RANGE_BELOW
    local current_floor_half_height = mod:get("strike_map_half_height") or CURRENT_FLOOR_HALF_HEIGHT

    _ensure_grid(context)

    if _grid.tri_count == 0 then
        return
    end

    local gui = ui_renderer.gui
    local scale = ui_renderer.scale or 1
    local render_settings = ui_renderer.render_settings
    local layer = (render_settings and render_settings.start_layer or 0) + z

    local ppx = player_pos.x
    local ppy = player_pos.y
    local ppz = player_pos.z or 0

    local forward_x, forward_y = _forward_xy(rotation)
    local right_x, right_y

    if forward_x and forward_y then
        right_x = forward_y
        right_y = -forward_x
    end

    local limit = projection_radius
    local limit_sq = limit * limit
    local radar_scale = limit / range
    local is_circle = radar_style == "circle"

    local triangles = _grid.triangles
    local cells = _grid.cells
    local stamp = _grid.stamp
    local frame_id = _grid.frame_id + 1
    _grid.frame_id = frame_id

    local cull_range = range * CULL_RANGE_FACTOR
    local inverse_grid_cell = _grid.inverse_grid_cell
    local min_cx = math_max(math_floor((ppx - cull_range) * inverse_grid_cell), _grid.min_cx)
    local max_cx = math_min(math_floor((ppx + cull_range) * inverse_grid_cell), _grid.max_cx)
    local min_cy = math_max(math_floor((ppy - cull_range) * inverse_grid_cell), _grid.min_cy)
    local max_cy = math_min(math_floor((ppy + cull_range) * inverse_grid_cell), _grid.max_cy)

    local screen_center_x = center_x
    local screen_center_y = center_y
    local draws = 0

    for cx = min_cx, max_cx do
        local row_key = (cx + GRID_CELL_HASH_OFFSET) * GRID_CELL_HASH_STRIDE

        for cy = min_cy, max_cy do
            local bucket = cells[row_key + cy + GRID_CELL_HASH_OFFSET]

            if bucket then
                for bucket_index = 1, #bucket do
                    local i = bucket[bucket_index]

                    if stamp[i] ~= frame_id then
                        stamp[i] = frame_id

                        local base = (i - 1) * TRIANGLE_STRIDE
                        local px1, py1, px2, py2, px3, py3
                        local dx = triangles[base + 1] - ppx
                        local dy = triangles[base + 2] - ppy

                        if right_x then
                            px1 = (dx * right_x + dy * right_y) * radar_scale
                            py1 = -(dx * forward_x + dy * forward_y) * radar_scale
                            dx = triangles[base + 3] - ppx
                            dy = triangles[base + 4] - ppy
                            px2 = (dx * right_x + dy * right_y) * radar_scale
                            py2 = -(dx * forward_x + dy * forward_y) * radar_scale
                            dx = triangles[base + 5] - ppx
                            dy = triangles[base + 6] - ppy
                            px3 = (dx * right_x + dy * right_y) * radar_scale
                            py3 = -(dx * forward_x + dy * forward_y) * radar_scale
                        else
                            px1 = dx * radar_scale
                            py1 = -dy * radar_scale
                            dx = triangles[base + 3] - ppx
                            dy = triangles[base + 4] - ppy
                            px2 = dx * radar_scale
                            py2 = -dy * radar_scale
                            dx = triangles[base + 5] - ppx
                            dy = triangles[base + 6] - ppy
                            px3 = dx * radar_scale
                            py3 = -dy * radar_scale
                        end

                        local dz = triangles[base + 7] - ppz
                        local color = nil

                        if dz <= range_above and dz >= -range_below then
                            if dz > current_floor_half_height then
                                color = above_color
                            elseif dz < -current_floor_half_height then
                                color = below_color
                            else
                                color = current_color
                            end
                        end

                        if color then
                            draws = draws + _draw_triangle_clipped(gui, scale, screen_center_x, screen_center_y, px1, py1, px2, py2, px3, py3, limit, limit_sq, is_circle, layer, color)

                            if draws >= MAX_TRIANGLE_DRAWS_PER_FRAME then
                                if not _grid.draw_cap_logged and mod:get("debug_mode") == true then
                                    _grid.draw_cap_logged = true
                                    mod:info(string_format(
                                        "[minimap] Strikemap geometry draw cap reached | cap=%d",
                                        MAX_TRIANGLE_DRAWS_PER_FRAME))
                                end

                                return
                            end
                        end
                    end
                end
            end
        end
    end

    local vector_context = StrikemapCompatibility:get_vector_context()
    if vector_context then
        _ensure_vector_grid(vector_context, context.grid_cell)
        local frame_id_v = _vector_grid.frame_id + 1
        _vector_grid.frame_id = frame_id_v

        local min_cx_v = math_max(math_floor((ppx - cull_range) * _vector_grid.inverse_grid_cell), _vector_grid.min_cx)
        local max_cx_v = math_min(math_floor((ppx + cull_range) * _vector_grid.inverse_grid_cell), _vector_grid.max_cx)
        local min_cy_v = math_max(math_floor((ppy - cull_range) * _vector_grid.inverse_grid_cell), _vector_grid.min_cy)
        local max_cy_v = math_min(math_floor((ppy + cull_range) * _vector_grid.inverse_grid_cell), _vector_grid.max_cy)

        local line_layer = layer + 1

        local thickness_contours = mod:get("strike_map_line_thickness_contours") or 2.5
        local thickness_stairs = mod:get("strike_map_line_thickness_stairs") or 1.5
        local thickness_slopes = mod:get("strike_map_line_thickness_slopes") or 1.5

        local function draw_vector_layer(segments, stride, cells, stamp, thickness)
            for cx = min_cx_v, max_cx_v do
                local row_key = (cx + GRID_CELL_HASH_OFFSET) * GRID_CELL_HASH_STRIDE
                for cy = min_cy_v, max_cy_v do
                    local bucket = cells[row_key + cy + GRID_CELL_HASH_OFFSET]
                    if bucket then
                        for bucket_index = 1, #bucket do
                            local i = bucket[bucket_index]
                            if stamp[i] ~= frame_id_v then
                                stamp[i] = frame_id_v
                                local base = (i - 1) * stride
                                local dx1 = segments[base + 1] - ppx
                                local dy1 = segments[base + 2] - ppy
                                local dx2 = segments[base + 3] - ppx
                                local dy2 = segments[base + 4] - ppy

                                local px1, py1, px2, py2
                                if right_x then
                                    px1 = (dx1 * right_x + dy1 * right_y) * radar_scale
                                    py1 = -(dx1 * forward_x + dy1 * forward_y) * radar_scale
                                    px2 = (dx2 * right_x + dy2 * right_y) * radar_scale
                                    py2 = -(dx2 * forward_x + dy2 * forward_y) * radar_scale
                                else
                                    px1 = dx1 * radar_scale
                                    py1 = -dy1 * radar_scale
                                    px2 = dx2 * radar_scale
                                    py2 = -dy2 * radar_scale
                                end

                                local dz = segments[base + 5] - ppz
                                local color = nil
                                
                                if dz <= range_above and dz >= -range_below then
                                    if dz > current_floor_half_height then
                                        color = above_color
                                    elseif dz < -current_floor_half_height then
                                        color = below_color
                                    else
                                        color = current_color
                                    end
                                end

                                if color then
                                    draws = draws + _draw_line(gui, scale, screen_center_x, screen_center_y, px1, py1, px2, py2, limit, limit_sq, is_circle, thickness, line_layer, color)
                                    if draws >= MAX_TRIANGLE_DRAWS_PER_FRAME then
                                        return true
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return false
        end

        if _vector_grid.contours then
            if draw_vector_layer(_vector_grid.contours, _vector_grid.contour_stride, _vector_grid.contours_cells, _vector_grid.contours_stamp, thickness_contours) then return end
        end
        if _vector_grid.stairs then
            if draw_vector_layer(_vector_grid.stairs, _vector_grid.stair_stride, _vector_grid.stairs_cells, _vector_grid.stairs_stamp, thickness_stairs) then return end
        end
        if _vector_grid.slopes then
            if draw_vector_layer(_vector_grid.slopes, _vector_grid.slope_stride, _vector_grid.slopes_cells, _vector_grid.slopes_stamp, thickness_slopes) then return end
        end
    end
end

local MinimapStrikemapGeometry = {}

MinimapStrikemapGeometry.is_active = function(t)
    if _triangle_supported == false then
        return false
    end

    return StrikemapCompatibility:get_map_context(t) ~= nil
end

MinimapStrikemapGeometry.draw = function(ui_renderer, snapshot, center_x, center_y, z, projection_radius, range,
                                       rotation, radar_style, t)
    local player_pos = snapshot and snapshot.player_position or nil

    if not player_pos then
        return
    end

    local context = StrikemapCompatibility:get_map_context(t)

    if not context then
        return
    end

    local gui = ui_renderer and ui_renderer.gui

    if not gui then
        return
    end

    if _triangle_supported == nil then
        _triangle_supported = _probe_triangle(gui)

        if not _triangle_supported then
            StrikemapCompatibility:mark_unsupported("triangle rendering is unavailable in this game build")
        end
    end

    if not _triangle_supported then
        return
    end

    range = tonumber(range)
    projection_radius = tonumber(projection_radius)

    if not range or range <= 0 or not projection_radius or projection_radius <= 0 then
        return
    end

    local ok, err = pcall(_draw_geometry, ui_renderer, context, player_pos, rotation, center_x, center_y, z,
        projection_radius, range, radar_style)

    if not ok then
        StrikemapCompatibility:mark_error(err)
    end
end

return MinimapStrikemapGeometry
