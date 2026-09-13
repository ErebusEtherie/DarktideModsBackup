---@class BetterEnemyTagMod:DMFMod
local mod                      = get_mod("BetterEnemyTag")
local UISettings               = require("scripts/settings/ui/ui_settings")
local UIFontSettings           = require("scripts/managers/ui/ui_font_settings")
local header_font_settings     = UIFontSettings["hud_body"]
local header_font_size         = header_font_settings.font_size

-- Global Cache
local CLASS                    = CLASS
local Managers                 = Managers
local ScriptUnit               = ScriptUnit

-- Settings
---@class BetterEnemyTagModSettings
local mod_settings             = {
    reduce_screen_margin                    = mod:get("reduce_screen_margin"),
    enhanced_distance_scale                 = mod:get("enhanced_distance_scale"),
    disable_aim_scale_up                    = mod:get("disable_aim_scale_up"),
    hide_distance_text                      = mod:get("hide_distance_text"),
    hide_off_screen_icon                    = mod:get("hide_off_screen_icon"),
    opacity_normal                          = mod:get("opacity_normal"),
    fade_when_aim                           = mod:get("fade_when_aim"),
    opacity_aim                             = mod:get("opacity_aim"),
    sync_outline_color                      = mod:get("sync_outline_color"),
    override_normal_tag_settings            = mod:get("override_normal_tag_settings"),
    normal_tag_opacity_normal               = mod:get("normal_tag_opacity_normal"),
    normal_tag_fade_when_aim                = mod:get("normal_tag_fade_when_aim"),
    normal_tag_opacity_aim                  = mod:get("normal_tag_opacity_aim"),
    normal_tag_sync_outline_color           = mod:get("normal_tag_sync_outline_color"),
    normal_tag_icon_path                    = mod:get("normal_tag_icon_path"),
    normal_tag_use_slot_color               = mod:get("normal_tag_use_slot_color"),
    override_normal_tag_color               = mod:get("override_normal_tag_color"),
    normal_tag_color                        = mod:get("normal_tag_color"),
    override_teammate_normal_tag_color      = mod:get("override_teammate_normal_tag_color"),
    teammate_normal_tag_color               = mod:get("teammate_normal_tag_color"),
    override_veteran_tag_settings           = mod:get("override_veteran_tag_settings"),
    veteran_tag_opacity_normal              = mod:get("veteran_tag_opacity_normal"),
    veteran_tag_fade_when_aim               = mod:get("veteran_tag_fade_when_aim"),
    veteran_tag_opacity_aim                 = mod:get("veteran_tag_opacity_aim"),
    veteran_tag_sync_outline_color          = mod:get("veteran_tag_sync_outline_color"),
    veteran_tag_icon_path                   = mod:get("veteran_tag_icon_path"),
    veteran_tag_use_slot_color              = mod:get("veteran_tag_use_slot_color"),
    override_veteran_tag_color              = mod:get("override_veteran_tag_color"),
    veteran_tag_color                       = mod:get("veteran_tag_color"),
    override_teammate_veteran_tag_color     = mod:get("override_teammate_veteran_tag_color"),
    teammate_veteran_tag_color              = mod:get("teammate_veteran_tag_color"),
    override_companion_tag_settings         = mod:get("override_companion_tag_settings"),
    companion_tag_opacity_normal            = mod:get("companion_tag_opacity_normal"),
    companion_tag_fade_when_aim             = mod:get("companion_tag_fade_when_aim"),
    companion_tag_opacity_aim               = mod:get("companion_tag_opacity_aim"),
    companion_tag_sync_outline_color        = mod:get("companion_tag_sync_outline_color"),
    companion_tag_icon_path                 = mod:get("companion_tag_icon_path"),
    companion_tag_use_slot_color            = mod:get("companion_tag_use_slot_color"),
    override_companion_tag_color            = mod:get("override_companion_tag_color"),
    companion_tag_color                     = mod:get("companion_tag_color"),
    override_teammate_companion_tag_color   = mod:get("override_teammate_companion_tag_color"),
    teammate_companion_tag_color            = mod:get("teammate_companion_tag_color"),
    override_servo_skull_tag_settings       = mod:get("override_servo_skull_tag_settings"),
    servo_skull_tag_opacity_normal          = mod:get("servo_skull_tag_opacity_normal"),
    servo_skull_tag_fade_when_aim           = mod:get("servo_skull_tag_fade_when_aim"),
    servo_skull_tag_opacity_aim             = mod:get("servo_skull_tag_opacity_aim"),
    servo_skull_tag_sync_outline_color      = mod:get("servo_skull_tag_sync_outline_color"),
    servo_skull_tag_icon_path               = mod:get("servo_skull_tag_icon_path"),
    servo_skull_tag_use_slot_color          = mod:get("servo_skull_tag_use_slot_color"),
    override_servo_skull_tag_color          = mod:get("override_servo_skull_tag_color"),
    servo_skull_tag_color                   = mod:get("servo_skull_tag_color"),
    override_teammate_servo_skull_tag_color = mod:get("override_teammate_servo_skull_tag_color"),
    teammate_servo_skull_tag_color          = mod:get("teammate_servo_skull_tag_color"),
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

local function get_player_archetype_name(player)
    local profile = player and player._profile
    return profile and profile.archetype.name
end

local function on_marker_update(widget, marker, tag_type)
    if not marker.draw then
        return
    end

    local data = marker.data
    local tagger_player = data.tagger_player
    if tag_type == "companion_tag" then
        local archetype_name = get_player_archetype_name(tagger_player)
        if archetype_name == "cryptic" then
            tag_type = "servo_skull_tag"
        end
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
    local opacity = 1
    if mod_settings["override_" .. tag_type .. "_settings"] then
        opacity = mod_settings[tag_type .. "_fade_when_aim"]
            and alternate_fire_component
            and alternate_fire_component.is_active
            and mod_settings[tag_type .. "_opacity_aim"]
            or mod_settings[tag_type .. "_opacity_normal"]
    else
        opacity = mod_settings.fade_when_aim
            and alternate_fire_component
            and alternate_fire_component.is_active
            and mod_settings.opacity_aim
            or mod_settings.opacity_normal
    end
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
    if not data.is_tag_inited and data.visual_type ~= "passive" then
        local icon_path = mod_settings[tag_type .. "_icon_path"]
        if icon_path and icon_path ~= "default" then
            widget.content.icon = icon_path
        end
        local use_slot_color = mod_settings[tag_type .. "_use_slot_color"]
        local player_slot = tagger_player._slot
        local player_slot_color = UISettings.player_slot_colors[player_slot]
        local tag_color
        if use_slot_color and player_slot_color then
            tag_color = player_slot_color
        else
            local player = Managers.player:local_player_safe(1)
            local is_teammate_tag = tagger_player and tagger_player ~= player
            local override_tag_color = mod_settings["override_" .. tag_type .. "_color"]
            local override_teammate_tag_color = mod_settings["override_teammate_" .. tag_type .. "_color"] and is_teammate_tag
            if override_teammate_tag_color then
                tag_color = mod_settings["teammate_" .. tag_type .. "_color"]
            elseif override_tag_color then
                tag_color = mod_settings[tag_type .. "_color"]
            end
        end
        if tag_color then
            for _, pass_style in pairs(widget.style) do
                local color = pass_style.color or pass_style.text_color
                color[2] = tag_color[2]
                color[3] = tag_color[3]
                color[4] = tag_color[4]
            end
        end
        data.is_tag_inited = true
    end
end

mod:hook_require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_unit_threat",
    function(instance)
        tag_templates.enemy_tag = instance
        change_template_settings(instance)
        mod:hook_safe(instance, "update_function",
            function(parent, ui_renderer, widget, marker, template, dt, t)
                on_marker_update(widget, marker, "normal_tag")
            end)
    end
)

mod:hook_require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_unit_threat_veteran",
    function(instance)
        tag_templates.veteran_tag = instance
        change_template_settings(instance)
        mod:hook_safe(instance, "update_function",
            function(parent, ui_renderer, widget, marker, template, dt, t)
                on_marker_update(widget, marker, "veteran_tag")
            end)
    end
)

mod:hook_require("scripts/ui/hud/elements/world_markers/templates/world_marker_template_unit_threat_companion",
    function(instance)
        tag_templates.companion_tag = instance
        change_template_settings(instance)
        mod:hook_safe(instance, "update_function",
            function(parent, ui_renderer, widget, marker, template, dt, t)
                on_marker_update(widget, marker, "companion_tag")
            end)
    end
)

local function get_tag_type(outline_name, archetype_name)
    if outline_name == "smart_tagged_enemy" then
        return "normal_tag"
    elseif outline_name == "veteran_smart_tag" then
        return "veteran_tag"
    elseif outline_name == "adamant_smart_tag" then
        if archetype_name == "adamant" then
            return "companion_tag"
        elseif archetype_name == "cryptic" then
            return "servo_skull_tag"
        end
    end
end

local normal_tag_default_color = { 246 / 255, 69 / 255, 69 / 255 }
local veteran_tag_default_color = { 255 / 255, 204 / 255, 100 / 255 }
local companion_tag_default_color = { 184 / 255, 20 / 255, 96 / 255 }
local function get_default_tag_color(tag_type)
    if tag_type == "normal_tag" then
        return normal_tag_default_color
    elseif tag_type == "veteran_tag" then
        return veteran_tag_default_color
    elseif tag_type == "companion_tag" or tag_type == "servo_skull_tag" then
        return companion_tag_default_color
    end
end

mod:hook_safe(CLASS.OutlineSystem, "_event_smart_tag_created",
    function(self, tag_instance, is_hotjoin_synced)
        local unit, outline_name = self:_smart_tag_unit_outline(tag_instance)
        local tagger_player = tag_instance:tagger_player()
        if not tagger_player then
            return
        end

        local archetype_name = get_player_archetype_name(tagger_player)
        local tag_type = get_tag_type(outline_name, archetype_name)
        if not tag_type then
            return
        end

        if mod_settings["override_" .. tag_type .. "_settings"] then
            if not mod_settings[tag_type .. "_sync_outline_color"] then
                return
            end
        else
            if not mod_settings.sync_outline_color then
                return
            end
        end

        local use_slot_color = mod_settings[tag_type .. "_use_slot_color"]
        local player_slot = tagger_player._slot
        local player_slot_color = UISettings.player_slot_colors[player_slot]
        local outline_color
        if use_slot_color and player_slot_color then
            outline_color = { player_slot_color[2] / 255, player_slot_color[3] / 255, player_slot_color[4] / 255 }
        else
            local player = Managers.player:local_player_safe(1)
            local is_teammate_tag = tagger_player ~= player
            local override_tag_color = mod_settings["override_" .. tag_type .. "_color"]
            local override_teammate_tag_color = mod_settings["override_teammate_" .. tag_type .. "_color"] and is_teammate_tag
            if override_teammate_tag_color then
                local color = mod_settings["teammate_" .. tag_type .. "_color"]
                outline_color = { color[2] / 255, color[3] / 255, color[4] / 255 }
            elseif override_tag_color then
                local color = mod_settings[tag_type .. "_color"]
                outline_color = { color[2] / 255, color[3] / 255, color[4] / 255 }
            else
                outline_color = get_default_tag_color(tag_type)
            end
        end

        local extension = self._unit_extension_data[unit]
        local outlines = extension.outlines
        for i = 1, #outlines do
            local outline = outlines[i]
            if outline.name == outline_name then
                outline.color = outline_color
                Unit.set_vector3_for_materials(unit, "outline_color", Vector3(outline_color[1], outline_color[2], outline_color[3]), true)
                break
            end
        end
    end
)

mod.on_setting_changed = function(setting_id)
    local result = mod:get(setting_id)
    mod_settings[setting_id] = result
    if setting_id == "reduce_screen_margin" or setting_id == "enhanced_distance_scale" then
        change_all_templates_settings()
    elseif string.find(setting_id, "_use_slot_color$") then
        if result then
            local tag_type = setting_id:gsub("_use_slot_color$", "")
            mod:set("override_" .. tag_type .. "_color", false, true)
            mod:set("override_teammate_" .. tag_type .. "_color", false, true)
        end
    elseif string.find(setting_id, "^override_.*_color$") or string.find(setting_id, "^override_teammate_.*_color$") then
        if result then
            local tag_type = setting_id:gsub("^override_", ""):gsub("^teammate_", ""):gsub("_color$", "")
            mod:set(tag_type .. "_use_slot_color", false, true)
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
