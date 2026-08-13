local mod = get_mod("what_are_you")

mod.get_module = function(self, name)
    return self:io_dofile("what_are_you/scripts/mods/what_are_you/modules/" .. name)
end

local use_migrations = mod:get_module("use_migrations")()
---@cast use_migrations use_migrations_r

use_migrations.run_setting_migrations(mod)

local use_debug = mod:get_module("use_debug")(mod)
local use_game_state = mod:get_module("use_game_state")()
local use_color = mod:get_module("use_color")()
local use_class = mod:get_module("use_class")()
local use_character = mod:get_module("use_character")()

---@cast use_color use_color_r
---@cast use_debug use_debug_r
---@cast use_game_state use_game_state_r
---@cast use_class use_class_r
---@cast use_character use_character_r

local modified_name_cache = {}
local original_name_cache = {}

mod.on_game_state_changed = function(status, state_name)
    if status == "enter" then
        use_game_state.update_game_state(state_name)
    end
end

local in_table = function(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

local string_split = function(text, delimiter)
    local fields = {}

    local delimiter = delimiter or " "
    local pattern = string.format("([^%s]+)", delimiter)
    string.gsub(text, pattern, function(c) fields[#fields + 1] = c end)

    return fields
end

local make_modified_name = function(profile)
    if not use_game_state.is_in_game() or not mod:is_enabled() then
        return
    end

    if modified_name_cache[profile.character_id] ~= nil then
        return modified_name_cache[profile.character_id]
    end

    local modified_name = nil
    local display_mode = mod:get("select_display_mode")

    if profile and profile.archetype and profile.talents then
        local is_bot = (string.find(profile.character_id, "bot") and true) or false
        local class_id = use_class.get_class_id_from_archetype(profile.archetype)

        local character_name = ""

        if not is_bot and not in_table({ "option_class_talent", "option_talent_class", "option_class", "option_talent" }, display_mode) then
            character_name = use_character.format_character_name(mod, original_name_cache[profile.character_id])
        end

        local class_name = ""

        if not in_table({ "talent", "character_talent", "talent_character", }, display_mode) then
            local localised_class_name = use_class.get_localised_class_name_from_archetype(mod, profile.archetype)

            if localised_class_name ~= nil then
                class_name = use_class.format_class_name(mod, localised_class_name)
            end
        end

        local talent_name = ""

        if not in_table({ "class", "character_class", "class_character" }, display_mode) then
            local localised_primary_talent_name = use_class.get_localised_primary_talent_from_profile(mod,
                profile)

            if localised_primary_talent_name ~= nil then
                talent_name = use_class.format_class_talent_name(mod, localised_primary_talent_name)
            end
        end

        local parts = {
            character = character_name ~= "" and
                (mod:get("toggle_apply_color_to_character_name") and use_color.add_class_color_to_text(mod, class_id, class_name)) or
                use_color.add_character_color_to_text(mod, character_name),
            class = class_name ~= "" and use_color.add_class_color_to_text(mod, class_id, class_name) or class_name,
            talent = talent_name ~= "" and use_color.add_class_color_to_text(mod, class_id, talent_name) or talent_name,
        }

        local parts_concat = ""

        for idx, part in ipairs(string_split(display_mode, "_")) do
            parts_concat = parts_concat .. parts[part] .. " "
        end

        if is_bot then
            parts_concat = use_color.mute_text("[BOT] ") .. parts_concat
        end

        parts_concat = parts_concat:gsub("%s+$", "") -- trim whitespace at end

        if parts_concat and parts_concat ~= "" then
            modified_name_cache[profile.character_id] = parts_concat
            modified_name = modified_name_cache[profile.character_id]
        end
    end

    use_debug.dump_once(1, original_name_cache)

    return modified_name
end

local function player_panel_hook(self, dt, t, player)
    if not use_game_state.is_in_game() or not mod:is_enabled() then
        return
    end
    self.tl_modified = false -- lets true_level do its thing
    self.wru_modified = true -- overwriting who_are_you here

    local profile = player:profile()
    local character_name = player:name()

    local character_level = profile.current_level
    local string_symbol = self._player_name_prefix or ""

    if profile and profile.character_id and original_name_cache[profile.character_id] == nil then
        original_name_cache[profile.character_id] = profile.name
    end

    local modified_name = mod:is_enabled() and make_modified_name(profile) or nil

    self:_set_player_name(string_symbol .. (modified_name or character_name), character_level)
end

mod:hook_safe(CLASS.HudElementPersonalPlayerPanel, "_update_player_features", player_panel_hook)
mod:hook_safe(CLASS.HudElementTeamPlayerPanel, "_update_player_features", player_panel_hook)

mod:hook_require('scripts/ui/hud/elements/world_markers/hud_element_world_markers', function(HudElementWorldMarkers)
    HudElementWorldMarkers.event_add_world_marker_unit = function(self, marker_type, unit, callback, data)
        local parent = self._parent
        local my_player = parent:player()
        local marker = {
            scale = 1,
            type = marker_type,
            unit = unit,
            position = Vector3Box(),
            my_player = my_player,
        }

        local id = self:_register_marker(marker)
        local widget_name = "marker_widget_id_" .. id
        local clone_template = true
        local template = self:_template_by_type(marker_type, clone_template)
        local widget = self:_create_widget_by_type(widget_name, template)

        --- start mod code
        if mod:is_enabled() and mod:get("toggle_replace_name_in_markers") then
            if my_player and data and data._profile and data._profile.character_id and data._profile.name then
                if original_name_cache[data._profile.character_id] == nil then
                    original_name_cache[data._profile.character_id] = data._profile.name
                end

                local modified_name = make_modified_name(data._profile)

                data._profile.name = modified_name or data._profile.name
            end
        end
        --- end mod code

        marker.widget = widget
        marker.data = data
        marker.template = template

        local on_enter = template.on_enter

        if on_enter then
            on_enter(widget, marker, template)
        end

        if callback then
            callback(id)
        end
    end
end)

mod.on_setting_changed = function(setting_id)
    modified_name_cache = {}
    if setting_id == 'select_preset' then
        local preset_id = mod:get(setting_id)

        mod:set(setting_id, 'select')                  -- resets dropdown back to - select -
        mod:set('select_display_mode', 'class_talent') -- all presets have same display mode

        if preset_id == 1 then
            mod:set('select_class_name_prefix', '')
            mod:set('select_class_name_suffix', '')
            mod:set('select_class_name_case', 'title')
            mod:set('select_talent_name_prefix', '[')
            mod:set('select_talent_name_suffix', ']')
            mod:set('select_talent_name_case', 'title')
        elseif preset_id == 2 then
            mod:set('select_class_name_prefix', '')
            mod:set('select_class_name_suffix', '')
            mod:set('select_class_name_case', 'title')
            mod:set('select_talent_name_prefix', '(')
            mod:set('select_talent_name_suffix', ')')
            mod:set('select_talent_name_case', 'title')
        elseif preset_id == 3 then
            mod:set('select_class_name_prefix', '')
            mod:set('select_class_name_suffix', ' +')
            mod:set('select_class_name_case', 'title')
            mod:set('select_talent_name_prefix', '')
            mod:set('select_talent_name_suffix', '')
            mod:set('select_talent_name_case', 'title')
        elseif preset_id == 4 then
            mod:set('select_class_name_prefix', '')
            mod:set('select_class_name_suffix', ' -')
            mod:set('select_class_name_case', 'title')
            mod:set('select_talent_name_prefix', '')
            mod:set('select_talent_name_suffix', '')
            mod:set('select_talent_name_case', 'title')
        elseif preset_id == 5 then
            mod:set('select_class_name_prefix', '')
            mod:set('select_class_name_suffix', '')
            mod:set('select_class_name_case', 'upper')
            mod:set('select_talent_name_prefix', '(')
            mod:set('select_talent_name_suffix', ')')
            mod:set('select_talent_name_case', 'upper')
        elseif preset_id == 6 then
            mod:set('select_class_name_prefix', '')
            mod:set('select_class_name_suffix', ' x')
            mod:set('select_class_name_case', 'upper')
            mod:set('select_talent_name_prefix', '')
            mod:set('select_talent_name_suffix', '')
            mod:set('select_talent_name_case', 'upper')
        elseif preset_id == 7 then
            mod:set('select_class_name_prefix', '')
            mod:set('select_class_name_suffix', ' x')
            mod:set('select_class_name_case', 'patrick')
            mod:set('select_talent_name_prefix', '')
            mod:set('select_talent_name_suffix', '')
            mod:set('select_talent_name_case', 'patrick')
        end
    end
end
