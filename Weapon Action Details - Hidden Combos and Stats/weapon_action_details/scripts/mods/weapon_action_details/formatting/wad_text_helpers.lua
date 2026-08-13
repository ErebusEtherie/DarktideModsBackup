-- File: weapon_action_details/scripts/mods/weapon_action_details/formatting/wad_text_helpers.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Text = mod:original_require("scripts/utilities/ui/text")

function mod.has_text(text)
    return text ~= nil and text ~= ""
end

function mod.newline_count(text)
    local count = 0
    local start_index = 1

    while true do
        local index = string.find(text, "\n", start_index, true)

        if not index then
            return count
        end

        count = count + 1
        start_index = index + 1
    end
end

function mod.format_number(value)
    if type(value) ~= "number" then
        return nil
    end

    if value == math.huge then
        return "infinite"
        -- return "∞"
    end

    return string.format("%.2f", value)
end

function mod.format_lerp_value_text(value_text)
    if type(value_text) ~= "string" then
        return value_text
    end

    return Text.apply_color_to_text(value_text, Color.ui_terminal(255, true))
end

function mod.format_stamina_cost_text(value_text)
    if type(value_text) ~= "string" then
        return value_text
    end

    return "{#color(255,255,255)}" .. value_text .. "{#reset()}"
end

function mod.visible_text_length(text)
    if type(text) ~= "string" then
        return 0
    end

    local visible_text = string.gsub(text, "{#[^}]*}", "")

    return #visible_text
end

function mod.truncate_rich_text(text, max_visible_length)
    if type(text) ~= "string" or max_visible_length <= 0 then
        return ""
    end

    local output = {}
    local index = 1
    local visible_length = 0
    local color_is_open = false

    while index <= #text and visible_length < max_visible_length do
        local tag_start, tag_end = string.find(text, "{#[^}]*}", index)

        if tag_start == index then
            local tag = string.sub(text, tag_start, tag_end)

            output[#output + 1] = tag
            color_is_open = string.find(tag, "{#color", 1, true) == 1 or color_is_open
            color_is_open = tag == "{#reset()}" and false or color_is_open
            index = tag_end + 1
        else
            local chunk_end = tag_start and tag_start - 1 or #text
            local chunk = string.sub(text, index, chunk_end)
            local remaining_length = max_visible_length - visible_length

            if #chunk > remaining_length then
                output[#output + 1] = string.sub(chunk, 1, remaining_length)
                visible_length = max_visible_length
            else
                output[#output + 1] = chunk
                visible_length = visible_length + #chunk
                index = chunk_end + 1
            end
        end
    end

    if color_is_open then
        output[#output + 1] = "{#reset()}"
    end

    return table.concat(output)
end

function mod.format_time(value)
    if type(value) ~= "number" then
        return nil
    end

    if value == math.huge then
        return "infinite"
        -- return "∞"
    end

    if value < 60 then
        return string.format("%.2fs", value)
    end

    return Text.format_time_span_localized(value, true, true)
end
