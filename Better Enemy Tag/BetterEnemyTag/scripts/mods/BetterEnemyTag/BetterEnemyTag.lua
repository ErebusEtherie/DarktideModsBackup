local mod                      = get_mod("BetterEnemyTag")
local UIFontSettings           = require("scripts/managers/ui/ui_font_settings")
local header_font_settings     = UIFontSettings["hud_body"]
local header_font_size         = header_font_settings.font_size

-- Global Cache
local CLASS                    = CLASS
local Managers                 = Managers
local ScriptUnit               = ScriptUnit

-- Settings
local mod_settings             = {
    reduce_screen_margin         = mod:get("reduce_screen_margin"),
    enhanced_distance_scale      = mod:get("enhanced_distance_scale"),
    disable_aim_scale_up         = mod:get("disable_aim_scale_up"),
    hide_distance_text           = mod:get("hide_distance_text"),
    hide_off_screen_icon         = mod:get("hide_off_screen_icon"),
    opacity_normal               = mod:get("opacity_normal"),
    fade_when_aim                = mod:get("fade_when_aim"),
    opacity_aim                  = mod:get("opacity_aim"),
    override_normal_tag_color    = mod:get("override_normal_tag_color"),
    normal_tag_color_red         = mod:get("normal_tag_color_red"),
    normal_tag_color_green       = mod:get("normal_tag_color_green"),
    normal_tag_color_blue        = mod:get("normal_tag_color_blue"),
    override_veteran_tag_color   = mod:get("override_veteran_tag_color"),
    veteran_tag_color_red        = mod:get("veteran_tag_color_red"),
    veteran_tag_color_green      = mod:get("veteran_tag_color_green"),
    veteran_tag_color_blue       = mod:get("veteran_tag_color_blue"),
    override_companion_tag_color = mod:get("override_companion_tag_color"),
    companion_tag_color_red      = mod:get("companion_tag_color_red"),
    companion_tag_color_green    = mod:get("companion_tag_color_green"),
    companion_tag_color_blue     = mod:get("companion_tag_color_blue"),
}

-- Params
local DEFAULT_SCREEN_MARGINS   = {
    down  = 0.23148148148148148,
    left  = 0.234375,
    right = 0.234375,
    up    = 0.23148148148148148,
}

local DEFAULT_SCALE_SETTINGS   = {
    distance_max = 50,
    distance_min = 5,
    scale_from   = 0.5,
    scale_to     = 1,
}

local screen_margins           = {
    down  = 0.09,
    left  = 0.05,
    right = 0.05,
    up    = 0.09,
}

local scale_settings           = {
    distance_max = 30,
    distance_min = 0,
    scale_from   = 0.4,
    scale_to     = 1,
}

local tag_templates            = {}
local alternate_fire_component = nil

local function change_template_settings(template)
    template.screen_margins = mod_settings.reduce_screen_margin and screen_margins or DEFAULT_SCREEN_MARGINS
    template.scale_settings = mod_settings.enhanced_distance_scale and scale_settings or DEFAULT_SCALE_SETTINGS
end

local function change_all_templates_settings()
    for _, template in pairs(tag_templates) do
        change_template_settings(template)
    end
end

local function on_marker_update(widget, marker)
    if not marker.draw then
        return
    end

    local style = widget.style
    local content = widget.content
    if mod_settings.disable_aim_scale_up then
        marker.ignore_scale = false
        style.text.font_size = header_font_size * marker.scale
    end
    if mod_settings.hide_distance_text then
        content.text = ""
    end
    local opacity = mod_settings.fade_when_aim
        and alternate_fire_component
        and alternate_fire_component.is_active
        and mod_settings.opacity_aim
        or mod_settings.opacity_normal
    local icon_color = style.icon.color
    local entry_icon_1_color = style.entry_icon_1.color
    local entry_icon_2_color = style.entry_icon_2.color
    local arrow_color = style.arrow.color
    local text_color = style.text.text_color
    if content.spawn_progress_timer then
        icon_color[1] = icon_color[1] * opacity
        entry_icon_1_color[1] = entry_icon_1_color[1] * opacity
        entry_icon_2_color[1] = entry_icon_2_color[1] * opacity
        arrow_color[1] = arrow_color[1] * opacity
        text_color[1] = text_color[1] * opacity
    else
        icon_color[1] = 255 * opacity
        arrow_color[1] = 255 * opacity
        text_color[1] = 255 * opacity
    end
    if mod_settings.hide_off_screen_icon and content.is_clamped then
        icon_color[1] = 0
        entry_icon_1_color[1] = 0
        entry_icon_2_color[1] = 0
        arrow_color[1] = 0
        text_color[1] = 0
    end
end

mod:hook_require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_unit_threat",
    function(instance)
        tag_templates.enemy_tag = instance
        change_template_settings(instance)
        mod:hook_safe(instance, "update_function",
            function(parent, ui_renderer, widget, marker, template, dt, t)
                on_marker_update(widget, marker)
                local data = marker.data
                if mod_settings.override_normal_tag_color and not data.is_color_inited and data.visual_type ~= "passive" then
                    for _, pass_style in pairs(widget.style) do
                        local color = pass_style.color or pass_style.text_color
                        color[2] = mod_settings.normal_tag_color_red
                        color[3] = mod_settings.normal_tag_color_green
                        color[4] = mod_settings.normal_tag_color_blue
                    end
                    data.is_color_inited = true
                end
            end)
    end
)

mod:hook_require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_unit_threat_veteran",
    function(instance)
        tag_templates.veteran_tag = instance
        change_template_settings(instance)
        mod:hook_safe(instance, "update_function",
            function(parent, ui_renderer, widget, marker, template, dt, t)
                on_marker_update(widget, marker)
                local data = marker.data
                if mod_settings.override_veteran_tag_color and not data.is_color_inited and data.visual_type ~= "passive" then
                    for _, pass_style in pairs(widget.style) do
                        local color = pass_style.color or pass_style.text_color
                        color[2] = mod_settings.veteran_tag_color_red
                        color[3] = mod_settings.veteran_tag_color_green
                        color[4] = mod_settings.veteran_tag_color_blue
                    end
                    data.is_color_inited = true
                end
            end)
    end
)

mod:hook_require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_unit_threat_adamant",
    function(instance)
        tag_templates.companion_tag = instance
        change_template_settings(instance)
        mod:hook_safe(instance, "update_function",
            function(parent, ui_renderer, widget, marker, template, dt, t)
                on_marker_update(widget, marker)
                local data = marker.data
                if mod_settings.override_companion_tag_color and not data.is_color_inited and data.visual_type ~= "passive" then
                    for _, pass_style in pairs(widget.style) do
                        local color = pass_style.color or pass_style.text_color
                        color[2] = mod_settings.companion_tag_color_red
                        color[3] = mod_settings.companion_tag_color_green
                        color[4] = mod_settings.companion_tag_color_blue
                    end
                    data.is_color_inited = true
                end
            end)
    end
)

mod.on_setting_changed = function(setting_id)
    local result = mod:get(setting_id)
    mod_settings[setting_id] = result
    if setting_id == "reduce_screen_margin" or setting_id == "enhanced_distance_scale" then
        change_all_templates_settings()
    elseif string.find(setting_id, "_red")
        or string.find(setting_id, "_green")
        or string.find(setting_id, "_blue")
    then
        local title_key = setting_id:gsub("_red$", ""):gsub("_green$", ""):gsub("_blue$", "")
        local localization = mod:get_localization()
        local translations = localization[title_key]
        local lang = Managers.localization:language()
        local new_title = translations[lang] or translations.en
        if not new_title then
            return
        end

        local red               = mod:get(title_key .. "_red")
        local green             = mod:get(title_key .. "_green")
        local blue              = mod:get(title_key .. "_blue")
        local new_title_colored = mod:make_text_colorful(new_title, red, green, blue)
        local dmf               = get_mod("DMF")
        local mod_name          = mod:get_name()
        for _, mod_data in ipairs(dmf.options_widgets_data) do
            if mod_data[1] and mod_data[1].mod_name == mod_name then
                for j = 1, #mod_data do
                    if mod_data[j].setting_id == title_key then
                        mod_data[j].title = new_title_colored
                        break
                    end
                end
            end
        end

        local view = Managers.ui:view_instance("dmf_options_view")
        local settings_category_widgets = view and view._settings_category_widgets
        local mod_widgets = settings_category_widgets and settings_category_widgets[mod:localize("mod_name")]
        if mod_widgets then
            for _, data in ipairs(mod_widgets) do
                local widget = data.widget
                local content = widget and widget.content
                if not content then
                    break
                end

                if new_title == string.gsub(content.text, "{#.-}", "") then
                    if content.entry then
                        content.entry.display_name = new_title_colored
                    end
                    content.text = new_title_colored
                    break
                end
            end
        end
    end
end

local function get_player_data_extension()
    local player = Managers.player:local_player_safe(1)
    return player and ScriptUnit.extension(player.player_unit, "unit_data_system")
end

local function init_components(player_data_extension)
    player_data_extension = player_data_extension or get_player_data_extension()
    if not player_data_extension then
        return
    end

    alternate_fire_component = player_data_extension:read_component("alternate_fire")
end

local function reset_components()
    alternate_fire_component = nil
end

mod.on_enabled  = function()
    init_components()
end

mod.on_disabled = function()
    reset_components()
end

mod:hook_safe(CLASS.PlayerUnitDataExtension, "init",
    function(self)
        if self._player.viewport_name == "player1" then
            init_components(self)
        end
    end)

mod:hook_safe(CLASS.PlayerUnitDataExtension, "destroy",
    function(self)
        if self._player.viewport_name == "player1" then
            reset_components()
        end
    end)
