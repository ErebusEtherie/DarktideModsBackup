
---@class ColorEntity
---@field color_name string
---@field color_array integer[]
local ColorEntity = {}

local Colors = {}

local color_dict = {} ---@type { string: integer[] }
local color_entities = {} ---@type ColorEntity[]

---@param color_name string
---@return integer[]?
Colors.get_color = function(color_name)
    return color_dict[color_name]
end

---@return ColorEntity[]
Colors.get_entities = function()
    return color_entities
end 

---@return ColorEntity[]
Colors.clone_entities = function()
    return table.clone(color_entities)
end 

for _, color_name in ipairs(Color.list) do
    local color_array = Color[color_name](255, true)
    color_dict[color_name] = color_array
    table.insert(color_entities, {
        color_name = color_name,
        color_array = color_array,
    })
end

local function calculate_brightness(color_entity)
    local color = color_entity.color_array
    local r, g, b = color[2], color[3], color[4]
    return 0.299 * r + 0.587 * g + 0.114 * b
end

local function calculate_hue(color_entity)
    local color = color_entity.color_array
    local r, g, b = color[2] / 255, color[3] / 255, color[4] / 255
    local max_val = math.max(r, g, b)
    local min_val = math.min(r, g, b)
    local delta = max_val - min_val

    if delta == 0 then
        return 0 -- Gray, no hue
    elseif max_val == r then
        return ((g - b) / delta) % 6
    elseif max_val == g then
        return ((b - r) / delta) + 2
    else
        return ((r - g) / delta) + 4
    end
end

local hue_groups = {}
local hue_threshold = 0.2
for _, entity in ipairs(color_entities) do
    local color_hue = calculate_hue(entity)
    local placed = false

    for _, group in ipairs(hue_groups) do
        local group_hue = calculate_hue(group[1])
        if math.abs(color_hue - group_hue) <= hue_threshold then
            table.insert(group, entity)
            placed = true
            break
        end
    end

    if not placed then
        table.insert(hue_groups, {entity})
    end
end

for _, group in ipairs(hue_groups) do
    table.sort(group, function(c1, c2)
        return calculate_brightness(c1) > calculate_brightness(c2)
    end)
end

table.sort(hue_groups, function(group1, group2)
    return calculate_hue(group1[1]) < calculate_hue(group2[1])
end)

color_entities = {}
for _, group in ipairs(hue_groups) do
    for _, color_entry in ipairs(group) do
        table.insert(color_entities, color_entry)
    end
end

return Colors