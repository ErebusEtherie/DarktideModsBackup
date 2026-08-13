---@alias use_character_r {
---format_character_name: format_character_name}

---@alias use_character fun(): use_character_r
---@type use_character
local function use_character()
    ---@alias format_character_name fun(mod: dmf_mod, character_name: string): string
    ---@type format_character_name
    local format_character_name = function(mod, character_name)
        if not character_name then character_name = "" end

        local use_string = mod:get_module("use_string")()
        ---@cast use_string use_string_r

        local prefix = mod:get("select_character_name_prefix") or ""
        local suffix = mod:get("select_character_name_suffix") or ""

        return prefix .. use_string.apply_case(mod:get("select_character_name_case"), character_name) .. suffix
    end

    return {
        format_character_name = format_character_name,
    }
end

return use_character
