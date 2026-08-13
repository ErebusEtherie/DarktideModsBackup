---@alias color_map_entry { nominal: integer, rgb: table, option_loc_id: string, option_value: string }
---@alias color_map {
---    default: color_map_entry,
---    jokaero_orange: color_map_entry,
---    muted: color_map_entry,
---    averland_sunset: color_map_entry,
---    gauss_blaster_green: color_map_entry,
---    evil_sunz_scarlet: color_map_entry,
---    fire_dragon_bright: color_map_entry,
---    flash_gitz_yellow: color_map_entry,
---    moot_green: color_map_entry,
---    baharroth_blue: color_map_entry,
---    lothern_blue: color_map_entry,
---    emperors_children: color_map_entry,
---    genestealer_purple: color_map_entry }

---@type color_map
local color_map = {
    default             = {
        nominal = 1,
        rgb = { 167, 190, 151 },
        option_loc_id = 'option_color_default',
        option_value = 'default',
    },
    jokaero_orange      = {
        nominal = 2,
        rgb = { 235, 96, 26 },
        option_loc_id = 'option_color_jokaero_orange',
        option_value = 'jokaero_orange',
    },
    averland_sunset     = {
        nominal = 3,
        rgb = { 255, 186, 0 },
        option_loc_id = 'option_color_averland_sunset',
        option_value = 'averland_sunset',
    },
    gauss_blaster_green = {
        nominal = 4,
        rgb = { 132, 255, 168 },
        option_loc_id = 'option_color_gauss_blaster_green',
        option_value = 'gauss_blaster_green',
    },
    evil_sunz_scarlet   = {
        nominal = 5,
        rgb = { 213, 41, 28 },
        option_loc_id = 'option_color_evil_sunz_scarlet',
        option_value = 'evil_sunz_scarlet',
    },
    fire_dragon_bright  = {
        nominal = 6,
        rgb = { 255, 110, 40 },
        option_loc_id = 'option_color_fire_dragon_bright',
        option_value = 'fire_dragon_bright',
    },
    flash_gitz_yellow   = {
        nominal = 7,
        rgb = { 255, 230, 40 },
        option_loc_id = 'option_color_flash_gitz_yellow',
        option_value = 'flash_gitz_yellow',
    },
    moot_green          = {
        nominal = 8,
        rgb = { 110, 255, 0 },
        option_loc_id = 'option_color_moot_green',
        option_value = 'moot_green',
    },
    baharroth_blue      = {
        nominal = 9,
        rgb = { 120, 210, 255 },
        option_loc_id = 'option_color_baharroth_blue',
        option_value = 'baharroth_blue',
    },
    lothern_blue        = {
        nominal = 10,
        rgb = { 70, 170, 255 },
        option_loc_id = 'option_color_lothern_blue',
        option_value = 'lothern_blue',
    },
    emperors_children   = {
        nominal = 11,
        rgb = { 255, 120, 200 },
        option_loc_id = 'option_color_emperors_children',
        option_value = 'emperors_children',
    },
    genestealer_purple  = {
        nominal = 12,
        rgb = { 180, 90, 255 },
        option_loc_id = 'option_color_genestealer_purple',
        option_value = 'genestealer_purple',
    },
     continued_chartreuse  = {
        nominal = 13,
        rgb = { 204, 255, 0 },
        option_loc_id = 'option_color_continued_chartreuse',
        option_value = 'continued_chartreuse',
    },
}

---@alias use_color_r {
---add_class_color_to_text: add_class_color_to_text,
---add_character_color_to_text: add_character_color_to_text,
---get_color_map: get_color_map,
---add_color_to_text: add_color_to_text,
---mute_text: mute_text }
---@alias use_color fun() : use_color_r

---@type use_color
local function use_color()
    ---@alias add_color_to_text fun(rgb_table: table, text: string|integer) : string
    ---@type add_color_to_text
    local function add_color_to_text(rgb_table, text)
        text = tostring(text)
        return rgb_table and rgb_table[1] and rgb_table[2] and rgb_table[3] and
            "{#color(" ..
            rgb_table[1] ..
            "," ..
            rgb_table[2] ..
            "," .. rgb_table[3] .. "," .. (rgb_table[4] or '255') .. ")}" .. tostring(text) .. "{#reset()}" or
            tostring(text)
    end

    ---@alias mute_text fun(text: string|integer) : string
    ---@type mute_text
    local function mute_text(text)
        return add_color_to_text({ 100, 100, 100 }, text)
    end

    ---@alias add_class_color_to_text fun(mod: dmf_mod, class_name_id:string|nil, text: string|integer) : string
    ---@type add_class_color_to_text
    local function add_class_color_to_text(mod, class_name_id, text)
        local use_class = mod:get_module("use_class")()
        ---@cast use_class use_class_r

        local color_id = use_class.get_class_color_id(mod, class_name_id)

        return add_color_to_text(color_map[color_id].rgb, text)
    end

    ---@alias add_character_color_to_text fun(mod: dmf_mod, character_name: string) : string
    ---@type add_character_color_to_text
    local function add_character_color_to_text(mod, character_name)
        local color_id = mod:get("select_character_name_color")

        return add_color_to_text(color_map[color_id].rgb, character_name)
    end

    ---@alias get_color_map fun() : color_map
    ---@type get_color_map
    local function get_color_map()
        return color_map
    end

    return {
        add_color_to_text = add_color_to_text,
        get_color_map = get_color_map,
        add_class_color_to_text = add_class_color_to_text,
        add_character_color_to_text = add_character_color_to_text,
        mute_text = mute_text,
    }
end

return use_color
