-- File: Flux/scripts/mods/Flux/Flux.lua
local mod = get_mod("Flux")
if not mod then return end

local UIViewHandler = mod:original_require("scripts/managers/ui/ui_view_handler")
local FontDefinitions = mod:original_require("scripts/managers/ui/ui_fonts_definitions")

mod.flux_hud_class_name = "HudElementFlux"
mod.flux_hud_filename = "Flux/scripts/mods/Flux/Flux_hud_element"
mod.flux_default_color = { 255, 150, 220, 255 }
mod.flux_cached_colours = {}
mod.flux_enabled_by_archetype = {}
mod.flux_opacity_by_archetype = {}
mod.flux_current_archetype_group_titles = {}
mod.flux_layout_dirty = true
mod._settings = {}

local SAFE_FONT_TYPE = mod.flux_safe_font_type or "proxima_nova_bold"
local math_floor = math.floor
local string_gsub = string.gsub
local tonumber = tonumber

local function clamp_channel(value, fallback)
    value = tonumber(value) or fallback

    if value < 0 then
        value = 0
    elseif value > 255 then
        value = 255
    end

    return math_floor(value + 0.5)
end

local function safe_font_lookup()
    local fonts = FontDefinitions and FontDefinitions.fonts

    if type(fonts) ~= "table" or not next(fonts) then
        return nil
    end

    return fonts
end

local function set_group_title_in_widget_data(widgets, target_setting_id, new_title)
    if type(widgets) ~= "table" then
        return false
    end

    for i = 1, #widgets do
        local widget_data = widgets[i]

        if type(widget_data) == "table" then
            if widget_data.setting_id == target_setting_id then
                widget_data.title = new_title
                widget_data.display_name = new_title
                return true
            end

            if set_group_title_in_widget_data(widget_data.sub_widgets, target_setting_id, new_title) then
                return true
            end
        end
    end

    return false
end

local function clean_title(title)
    return type(title) == "string" and string_gsub(title, "{#.-}", "") or nil
end

local function update_open_options_group_title(target_setting_id, old_title, new_title)
    local ui_manager = (managers and managers.ui) or Managers.ui
    local view = ui_manager and ui_manager:view_instance("dmf_options_view")

    if not view or not view._settings_category_widgets then
        return
    end

    local old_clean_title = clean_title(old_title)
    local new_clean_title = clean_title(new_title)
    local settings_category_widgets = view._settings_category_widgets
    local mod_category_widgets = settings_category_widgets[mod:localize("mod_name")]
    local category_widgets = mod_category_widgets or settings_category_widgets

    local function update_category_widgets(widgets)
        for i = 1, #widgets do
            local data = widgets[i]
            local widget = data and data.widget
            local content = widget and widget.content

            if content then
                local entry = content.entry
                local widget_setting_id = entry and entry.setting_id or content.setting_id
                local widget_text = content.text
                local widget_clean_text = clean_title(widget_text)

                if widget_setting_id == target_setting_id
                    or widget_clean_text == old_clean_title
                    or widget_clean_text == new_clean_title
                then
                    if entry then
                        entry.display_name = new_title
                        entry.title = new_title
                    end

                    content.text = new_title
                    widget.dirty = true
                    return true
                end
            end
        end

        return false
    end

    if mod_category_widgets and update_category_widgets(category_widgets) then
        return
    end

    for _, widgets in pairs(settings_category_widgets) do
        if update_category_widgets(widgets) then
            return
        end
    end
end

local function update_archetype_group_title_in_dmf(archetype_name)
    if not (mod.flux_get_archetype_group_setting_id and mod.flux_get_archetype_group_title) then
        return
    end

    local target_setting_id = mod.flux_get_archetype_group_setting_id(archetype_name)

    if not target_setting_id then
        return
    end

    local new_title = mod.flux_get_archetype_group_title(archetype_name, mod._settings)
    local old_title = mod.flux_current_archetype_group_titles[archetype_name]
    local dmf = get_mod("DMF")

    if dmf and dmf.options_widgets_data then
        local mod_name = mod:get_name()

        for i = 1, #dmf.options_widgets_data do
            local mod_data = dmf.options_widgets_data[i]

            if mod_data[1] and mod_data[1].mod_name == mod_name then
                set_group_title_in_widget_data(mod_data, target_setting_id, new_title)
                break
            end
        end
    end

    update_open_options_group_title(target_setting_id, old_title, new_title)
    mod.flux_current_archetype_group_titles[archetype_name] = new_title
end

local function update_all_archetype_group_titles_in_dmf()
    local archetypes = mod.flux_archetypes or {}

    for i = 1, #archetypes do
        update_archetype_group_title_in_dmf(archetypes[i].name)
    end
end

function mod.flux_is_in_hub()
    local game_mode_manager = Managers.state and Managers.state.game_mode
    local game_mode_name = game_mode_manager and game_mode_manager.game_mode_name and game_mode_manager:game_mode_name()

    return game_mode_name == "hub" or game_mode_name == "prologue_hub"
end

function mod.flux_check_font_validity()
    local fonts = safe_font_lookup()
    local settings = mod._settings
    local font_type = settings and settings.font_type

    if not fonts then
        return
    end

    if type(font_type) ~= "string" or font_type == "" or fonts[font_type] == nil then
        settings.font_type = SAFE_FONT_TYPE
        mod:set("font_type", SAFE_FONT_TYPE, true)
    end
end

function mod.flux_normalize_bar_mode(value)
    local bar_modes = mod.flux_bar_modes or {}

    if value == true then
        return bar_modes.horizontal or "horizontal"
    elseif value == false then
        return bar_modes.vertical or "vertical"
    end

    for _, mode in pairs(bar_modes) do
        if value == mode then
            return value
        end
    end

    return bar_modes.horizontal or "horizontal"
end

function mod.flux_cache_settings()
    local settings = mod._settings
    local setting_keys = mod.flux_setting_keys or {}

    for i = 1, #setting_keys do
        local setting_id = setting_keys[i]
        settings[setting_id] = mod:get(setting_id)
    end

    -- Legacy settings migration
    local legacy_reverse = mod:get("reverse_bar_fill")
    if legacy_reverse ~= nil then
        if legacy_reverse == true then
            local current_bar = settings.horizontal_bar or "horizontal"
            if type(current_bar) == "string" and not string.find(current_bar, "_rev") then
                settings.horizontal_bar = current_bar .. "_rev"
                mod:set("horizontal_bar", settings.horizontal_bar)
            end
        end
        mod:set("reverse_bar_fill", nil)
    end

    local legacy_show_pct = mod:get("show_charge_cooldown_percentage")
    if legacy_show_pct ~= nil then
        if legacy_show_pct == true then
            local current_text = settings.text_mode or "both"
            if current_text == "charges" or current_text == "both" then
                settings.text_mode = current_text .. "_pct"
                mod:set("text_mode", settings.text_mode)
            end
        end
        mod:set("show_charge_cooldown_percentage", nil)
    end

    if mod:get("flash_on_charge_gain") ~= nil then
        mod:set("flash_on_charge_gain", nil)
    end

    local normalized_bar_mode = mod.flux_normalize_bar_mode(settings.horizontal_bar)
    if settings.horizontal_bar ~= normalized_bar_mode then
        settings.horizontal_bar = normalized_bar_mode
        mod:set("horizontal_bar", normalized_bar_mode, true)
    end

    local valid_text_mode = false
    local text_modes = mod.flux_text_modes or {}
    for _, mode in pairs(text_modes) do
        if settings.text_mode == mode then
            valid_text_mode = true
            break
        end
    end
    if not valid_text_mode then
        settings.text_mode = text_modes.both or "both"
        mod:set("text_mode", settings.text_mode, true)
    end

    mod.flux_check_font_validity()

    local archetypes = mod.flux_archetypes or {}
    local colours = mod.flux_cached_colours
    local enabled_by_archetype = mod.flux_enabled_by_archetype
    local opacity_by_archetype = mod.flux_opacity_by_archetype

    for i = 1, #archetypes do
        local archetype_name = archetypes[i].name
        local colour = colours[archetype_name]

        if not colour then
            colour = { 255, 150, 220, 255 }
            colours[archetype_name] = colour
        end

        local enabled_setting_id = archetype_name .. "_enabled"
        local enabled_val = settings[enabled_setting_id]

        if type(enabled_val) == "boolean" then
            enabled_val = enabled_val and 1 or -1
            settings[enabled_setting_id] = enabled_val
            mod:set(enabled_setting_id, enabled_val, true)
        elseif type(enabled_val) ~= "number" then
            enabled_val = 1
        end

        enabled_by_archetype[archetype_name] = enabled_val
        opacity_by_archetype[archetype_name] = clamp_channel(settings[archetype_name .. "_opacity"], 255)
        colour[1] = 255
        colour[2] = clamp_channel(settings[archetype_name .. "_bar_red"], mod.flux_default_color[2])
        colour[3] = clamp_channel(settings[archetype_name .. "_bar_green"], mod.flux_default_color[3])
        colour[4] = clamp_channel(settings[archetype_name .. "_bar_blue"], mod.flux_default_color[4])
    end
end

function mod.flux_get_archetype_color(archetype_name)
    local colours = mod.flux_cached_colours

    return colours and colours[archetype_name] or mod.flux_default_color
end

function mod.flux_get_archetype_opacity(archetype_name)
    local opacity_by_archetype = mod.flux_opacity_by_archetype

    return opacity_by_archetype and opacity_by_archetype[archetype_name] or 255
end

function mod.flux_is_archetype_enabled(archetype_name, max_charges)
    local enabled_by_archetype = mod.flux_enabled_by_archetype

    if not archetype_name or not enabled_by_archetype then
        return true
    end

    local val = enabled_by_archetype[archetype_name]

    if val == false or val == -1 then
        return false
    end

    if max_charges and type(val) == "number" and max_charges < val then
        return false
    end

    return true
end

mod.flux_cache_settings()
update_all_archetype_group_titles_in_dmf()

function mod.on_setting_changed(setting_id)
    if not setting_id or not mod.flux_setting_key_lookup or mod.flux_setting_key_lookup[setting_id] then
        mod.flux_cache_settings()
        mod.flux_layout_dirty = true

        if not setting_id then
            update_all_archetype_group_titles_in_dmf()
        elseif mod.flux_get_archetype_name_from_colour_setting_id then
            local archetype_name = mod.flux_get_archetype_name_from_colour_setting_id(setting_id)

            if archetype_name then
                update_archetype_group_title_in_dmf(archetype_name)
            end
        end
    end
end

mod:add_require_path(mod.flux_hud_filename)

local function ui_hud_init_hook(func, self, elements, visibility_groups, params)
    if not table.find_by_key(elements, "class_name", mod.flux_hud_class_name) then
        elements[#elements + 1] = {
            class_name = mod.flux_hud_class_name,
            filename = mod.flux_hud_filename,
            use_hud_scale = true,
            visibility_groups = {
                "alive",
            },
        }
    end

    return func(self, elements, visibility_groups, params)
end

mod:hook("UIHud", "init", ui_hud_init_hook)

function mod.flux_recreate_hud()
    local ui_manager = Managers.ui
    local player_manager = Managers.player
    local player = player_manager and player_manager:local_player_safe(1)
    local hud = ui_manager and ui_manager._hud

    if not (hud and player) then
        return
    end

    local peer_id = player:peer_id()
    local local_player_id = player:local_player_id()
    local elements = hud._element_definitions
    local visibility_groups = hud._visibility_groups

    if not (peer_id and local_player_id and elements and visibility_groups) then
        return
    end

    hud:destroy()
    ui_manager:create_player_hud(peer_id, local_player_id, elements, visibility_groups)
end

function mod.on_all_mods_loaded()
    mod.flux_check_font_validity()
    update_all_archetype_group_titles_in_dmf()
    mod.flux_recreate_hud()
end

function mod.on_enabled(initial_call)
    if not initial_call then
        mod.flux_recreate_hud()
    end
end

function mod.on_disabled()
    mod.flux_layout_dirty = true
end

mod:hook_safe(UIViewHandler, "close_view", function(self, view_name, force_close)
    if view_name == "dmf_options_view" or view_name == "talent_builder_view" then
        mod.flux_layout_dirty = true
    end
end)
