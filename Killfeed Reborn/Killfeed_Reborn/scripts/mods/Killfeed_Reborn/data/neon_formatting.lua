local neon_formatting = {}

function neon_formatting.colorize(text, color)
    return string.format("{#color(%d,%d,%d)}%s{#reset()}", color[1], color[2], color[3], text)
end

function neon_formatting.gradient(text, colors)
    local output = {}
    local char_count = 0
    local char_index = 0

    for i = 1, #text do
        if string.sub(text, i, i) ~= " " then
            char_count = char_count + 1
        end
    end

    for i = 1, #text do
        local char = string.sub(text, i, i)

        if char == " " then
            output[#output + 1] = char
        else
            char_index = char_index + 1
            local t = char_count <= 1 and 0 or (char_index - 1) / (char_count - 1)
            local scaled = t * (#colors - 1)
            local start_index = math.floor(scaled) + 1
            local end_index = math.min(start_index + 1, #colors)
            local local_t = scaled - math.floor(scaled)
            local start_color = colors[start_index]
            local end_color = colors[end_index]
            local r = math.floor(start_color[1] + (end_color[1] - start_color[1]) * local_t + 0.5)
            local g = math.floor(start_color[2] + (end_color[2] - start_color[2]) * local_t + 0.5)
            local b = math.floor(start_color[3] + (end_color[3] - start_color[3]) * local_t + 0.5)

            output[#output + 1] = string.format("{#color(%d,%d,%d)}%s", r, g, b, char)
        end
    end

    output[#output + 1] = "{#reset()}"

    return table.concat(output)
end

return neon_formatting
