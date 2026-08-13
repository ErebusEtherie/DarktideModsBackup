---@alias case_map_entry { nominal: integer, option_loc_id: string, option_value: string }
---@alias case_map { title: case_map_entry, upper: case_map_entry, lower: case_map_entry, patrick: case_map_entry }

---@alias prefix_map_entry { nominal: integer, option_loc_id: string, option_value: string }
---@alias prefix_map table<string, prefix_map_entry>

---@alias suffix_map_entry { nominal: integer, option_loc_id: string, option_value: string }
---@alias suffix_map table<string, suffix_map_entry>

---@type case_map
local case_map = {
    title   = { nominal = 1, option_loc_id = 'option_case_title_case', option_value = 'title' },
    upper   = { nominal = 2, option_loc_id = 'option_case_upper_case', option_value = 'upper' },
    lower   = { nominal = 3, option_loc_id = 'option_case_lower_case', option_value = 'lower' },
    patrick = { nominal = 4, option_loc_id = 'option_case_patrick_case', option_value = 'patrick' },
}

---@type prefix_map
local prefix_map = {
    empty                  = { nominal = 1, option_loc_id = 'option_prefix_suffix_nil', option_value = '' },
    square_open            = { nominal = 2, option_loc_id = 'option_square_parenthesis_open', option_value = '[' },
    square_open_space      = { nominal = 3, option_loc_id = 'option_square_parenthesis_open_space', option_value = '[ ' },
    parenthesis_open       = { nominal = 4, option_loc_id = 'option_parenthesis_open', option_value = '(' },
    parenthesis_open_space = { nominal = 5, option_loc_id = 'option_parenthesis_open_space', option_value = '( ' },
    plus                   = { nominal = 6, option_loc_id = 'option_plus_prefix', option_value = '+' },
    plus_space             = { nominal = 7, option_loc_id = 'option_plus_space', option_value = '+ ' },
    x                      = { nominal = 8, option_loc_id = 'option_x_prefix', option_value = 'x' },
    x_space                = { nominal = 9, option_loc_id = 'option_x_space', option_value = 'x ' },
    minus                  = { nominal = 10, option_loc_id = 'option_minus_prefix', option_value = '-' },
    minus_space            = { nominal = 11, option_loc_id = 'option_minus_space', option_value = '- ' },
}

---@type suffix_map
local suffix_map = {
    empty                   = { nominal = 1, option_loc_id = 'option_prefix_suffix_nil', option_value = '' },
    square_close            = { nominal = 2, option_loc_id = 'option_square_parenthesis_close', option_value = ']' },
    space_square_close      = { nominal = 3, option_loc_id = 'option_space_square_parenthesis_close', option_value = ' ]' },
    parenthesis_close       = { nominal = 4, option_loc_id = 'option_parenthesis_close', option_value = ')' },
    space_parenthesis_close = { nominal = 5, option_loc_id = 'option_space_parenthesis_close', option_value = ' )' },
    plus                    = { nominal = 6, option_loc_id = 'option_plus_suffix', option_value = '+' },
    space_plus              = { nominal = 7, option_loc_id = 'option_space_plus', option_value = ' +' },
    x                       = { nominal = 8, option_loc_id = 'option_x_suffix', option_value = 'x' },
    space_x                 = { nominal = 9, option_loc_id = 'option_space_x', option_value = ' x' },
    minus                   = { nominal = 10, option_loc_id = 'option_minus_suffix', option_value = '-' },
    space_minus             = { nominal = 11, option_loc_id = 'option_space_minus', option_value = ' -' },
}

---@alias use_string_r { title_case: title_case, upper_case: upper_case, lower_case: lower_case, patrick_case: patrick_case, apply_case: apply_case, get_case_map: get_case_map, get_prefix_map: get_prefix_map, get_suffix_map: get_suffix_map }
---@alias use_string fun(mod: dmf_mod) : use_string_r

---@type use_string
local function use_string()
    ---@alias get_case_map fun() : case_map
    ---@type get_case_map
    local function get_case_map()
        return case_map
    end

    ---@alias get_prefix_map fun() : prefix_map
    ---@type get_prefix_map
    local function get_prefix_map()
        return prefix_map
    end

    ---@alias get_suffix_map fun() : suffix_map
    ---@type get_suffix_map
    local function get_suffix_map()
        return suffix_map
    end

    local function words(text)
        -- normalize separators
        text = text:gsub("[-_]", " ")
        -- split camelCase boundaries
        text = text:gsub("(%l)(%u)", "%1 %2")

        local result = {}
        for w in text:gmatch("%S+") do
            table.insert(result, w)
        end
        return result
    end

    ---@alias title_case fun(text: string): string
    ---@type title_case
    local function title_case(text)
        local out = {}
        for _, w in ipairs(words(text)) do
            w = w:lower()
            w = w:gsub("^%l", string.upper)
            table.insert(out, w)
        end
        return table.concat(out, " ")
    end

    ---@alias upper_case fun(text: string): string
    ---@type upper_case
    local function upper_case(text)
        return text:upper()
    end

    ---@alias lower_case fun(text: string): string
    ---@type lower_case
    local function lower_case(text)
        return text:lower()
    end

    ---@alias patrick_case fun(text: string): string
    ---@type patrick_case
    local function patrick_case(text)
        local result = {}
        local upper = false

        for i = 1, #text do
            local c = text:sub(i, i)
            if c:match("%a") then
                if upper then
                    result[#result + 1] = c:upper()
                else
                    result[#result + 1] = c:lower()
                end
                upper = not upper
            else
                result[#result + 1] = c
            end
        end

        return table.concat(result)
    end

    ---@alias apply_case fun(case_name: "title" | "upper" | "lower" | "patrick", text: string): string
    ---@type apply_case
    local function apply_case(case_name, text)
        return (case_name == "title" and title_case(text))
            or (case_name == "upper" and upper_case(text))
            or (case_name == "lower" and lower_case(text))
            or (case_name == "patrick" and patrick_case(text))
            or title_case(text)
    end

    return {
        title_case = title_case,
        upper_case = upper_case,
        lower_case = lower_case,
        patrick_case = patrick_case,
        apply_case = apply_case,
        get_case_map = get_case_map,
        get_prefix_map = get_prefix_map,
        get_suffix_map = get_suffix_map,
    }
end

return use_string
