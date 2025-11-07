local mod = get_mod("uptime")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")

function get_widget(uptime_view, scene_graph_id, width, height, percentage_per_stack)
    local template = {
        {
            pass_type = "rect",
            style = {
                color = Color.ui_grey_medium(120, true),
                size = { width, height }
            },
        } }

    local offset = 0
    local max_stacks = #percentage_per_stack
    local show_text = max_stacks > 1
    for stack, percentage in pairs(percentage_per_stack) do
        local section_width = (percentage / 100) * width
        template[#template + 1] = {
            pass_type = "rect",
            style = {
                size = { section_width, height },
                offset = { offset, 0 },
                color = Color.steel_blue(stack % 2 == 1 and 255 or 180, true),
            },
        }

        local num_of_char = math.log(stack, 10) + 1
        local width_per_char = 15 -- just a rough estimate
        local text_width = num_of_char * width_per_char

        if show_text and text_width < section_width then
            template[#template + 1] = {
                pass_type = "text",
                value = stack,
                style = {
                    text_horizontal_alignment = "center",
                    size = { section_width, height },
                    offset = { offset, 0 },
                    text_color = Color.black(190, true),
                    drop_shadow = false,
                },
            }
        end

        offset = offset + section_width
    end

    local widget_def = UIWidget.create_definition(template, scene_graph_id)
    local widget = uptime_view:_create_widget("bar", widget_def)
    return widget
end

return get_widget