-- File: Flux/scripts/mods/Flux/Flux_data.lua
local mod = get_mod("Flux")
if not mod then
    return {
        name = "Flux",
        description = "Missing mod instance",
        is_togglable = true,
        options = { widgets = {} },
    }
end

local UISettings = mod:original_require("scripts/settings/ui/ui_settings")
local Archetypes = mod:original_require("scripts/settings/archetype/archetypes")
local FontDefinitions = mod:original_require("scripts/managers/ui/ui_fonts_definitions")

local SAFE_FONT_TYPE = "proxima_nova_bold"
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local tonumber = tonumber

mod.flux_safe_font_type = SAFE_FONT_TYPE

mod.flux_text_modes = {
    off         = "off",
    charges     = "charges",
    charges_pct = "charges_pct",
    cooldown    = "cooldown",
    both        = "both",
    both_pct    = "both_pct",
}

mod.flux_bar_modes = {
    horizontal     = "horizontal",
    horizontal_rev = "horizontal_rev",
    vertical       = "vertical",
    vertical_rev   = "vertical_rev",
    circular       = "circular",
    circular_rev   = "circular_rev",
}

mod.flux_default_rgb = {
    red   = 150,
    green = 220,
    blue  = 255,
}

mod.flux_setting_keys = {}
mod.flux_setting_key_lookup = {}
mod.flux_archetypes = {}

local function add_setting_key(setting_id)
    if not mod.flux_setting_key_lookup[setting_id] then
        mod.flux_setting_key_lookup[setting_id] = true
        mod.flux_setting_keys[#mod.flux_setting_keys + 1] = setting_id
    end
end

local function clamp_colour_channel(value, fallback)
    value = tonumber(value) or fallback
    value = math_max(0, math_min(255, value))

    return math_floor(value + 0.5)
end

local function text_mode_options()
    return {
        { text = "text_mode_off",         value = mod.flux_text_modes.off },
        { text = "text_mode_charges",     value = mod.flux_text_modes.charges },
        { text = "text_mode_charges_pct", value = mod.flux_text_modes.charges_pct },
        { text = "text_mode_cooldown",    value = mod.flux_text_modes.cooldown },
        { text = "text_mode_both",        value = mod.flux_text_modes.both },
        { text = "text_mode_both_pct",    value = mod.flux_text_modes.both_pct },
    }
end

local function bar_mode_options()
    return {
        { text = "bar_mode_horizontal",     value = mod.flux_bar_modes.horizontal },
        { text = "bar_mode_horizontal_rev", value = mod.flux_bar_modes.horizontal_rev },
        { text = "bar_mode_vertical",       value = mod.flux_bar_modes.vertical },
        { text = "bar_mode_vertical_rev",   value = mod.flux_bar_modes.vertical_rev },
        { text = "bar_mode_circular",       value = mod.flux_bar_modes.circular },
        { text = "bar_mode_circular_rev",   value = mod.flux_bar_modes.circular_rev },
    }
end

local function timer_sound_options()
    return {
        { text = "glossary_default",         value = "default" },
        { text = "timer_sound_zealot",       value = "zealot" },
        { text = "timer_sound_blunt_shield", value = "shield" },
        { text = "timer_sound_item_tier3",   value = "item_tier3" },
    }
end

local function font_type_options()
    local fonts = FontDefinitions and FontDefinitions.fonts or {}
    local options = {}
    local i = 1

    for font_name, _ in pairs(fonts) do
        local readable = font_name:gsub("_", " "):gsub("(%a)([%w]*)", function(first, rest)
            return first:upper() .. rest
        end)

        options[i] = {
            text = string.format("{#font(%s)}%s{#reset()}", font_name, readable),
            value = font_name,
        }
        i = i + 1
    end

    if i == 1 then
        options[1] = {
            text = SAFE_FONT_TYPE,
            value = SAFE_FONT_TYPE,
        }
    end

    table.sort(options, function(a, b)
        return a.value < b.value
    end)

    return options
end

local function archetype_display_name(archetype_name)
    local archetype = Archetypes and Archetypes[archetype_name]

    return archetype and archetype.archetype_name and Localize(archetype.archetype_name) or archetype_name
end

function mod.flux_get_archetype_group_setting_id(archetype_name)
    return archetype_name and (archetype_name .. "_settings_group") or nil
end

function mod.flux_get_archetype_group_title(archetype_name, settings)
    if not archetype_name then
        return ""
    end

    local icons = UISettings and (UISettings.archetype_font_icon or UISettings.archetype_font_icon_simple) or {}
    local glyph = icons[archetype_name] or ""
    local display_name = archetype_display_name(archetype_name)
    local plain_title = glyph ~= "" and (glyph .. " " .. display_name) or display_name
    local source_settings = settings or {}
    local red = clamp_colour_channel(source_settings[archetype_name .. "_bar_red"], mod.flux_default_rgb.red)
    local green = clamp_colour_channel(source_settings[archetype_name .. "_bar_green"], mod.flux_default_rgb.green)
    local blue = clamp_colour_channel(source_settings[archetype_name .. "_bar_blue"], mod.flux_default_rgb.blue)

    if mod.flux_format_coloured_title then
        return mod.flux_format_coloured_title(plain_title, red, green, blue)
    end

    return plain_title
end

function mod.flux_get_archetype_name_from_colour_setting_id(setting_id)
    if not setting_id then
        return nil
    end

    local archetypes = mod.flux_archetypes or {}

    for i = 1, #archetypes do
        local archetype_name = archetypes[i].name

        if setting_id == archetype_name .. "_bar_red"
            or setting_id == archetype_name .. "_bar_green"
            or setting_id == archetype_name .. "_bar_blue"
        then
            return archetype_name
        end
    end

    return nil
end

local function collect_archetypes()
    local archetypes = {}
    local icons = UISettings and (UISettings.archetype_font_icon or UISettings.archetype_font_icon_simple) or nil

    if icons then
        for archetype_name, glyph in pairs(icons) do
            archetypes[#archetypes + 1] = {
                name = archetype_name,
                glyph = glyph,
                order = Archetypes and Archetypes[archetype_name] and Archetypes[archetype_name].ui_selection_order or
                    999,
            }
        end
    end

    if #archetypes == 0 and Archetypes then
        for archetype_name, archetype in pairs(Archetypes) do
            local glyph = UISettings and UISettings.archetype_font_icon and
                UISettings.archetype_font_icon[archetype_name] or ""
            archetypes[#archetypes + 1] = {
                name = archetype_name,
                glyph = glyph,
                order = archetype.ui_selection_order or 999,
            }
        end
    end

    table.sort(archetypes, function(a, b)
        if a.name == b.name then
            return false
        elseif a.name == "cryptic" then
            return true
        elseif b.name == "cryptic" then
            return false
        elseif a.order == b.order then
            return a.name < b.name
        end

        return a.order < b.order
    end)

    return archetypes
end

local function archetype_widgets()
    local widgets = {}
    local archetypes = collect_archetypes()

    mod.flux_archetypes = archetypes

    for i = 1, #archetypes do
        local archetype = archetypes[i]
        local archetype_name = archetype.name
        local enabled_id = archetype_name .. "_enabled"
        local opacity_id = archetype_name .. "_opacity"
        local red_id = archetype_name .. "_bar_red"
        local green_id = archetype_name .. "_bar_green"
        local blue_id = archetype_name .. "_bar_blue"

        add_setting_key(enabled_id)
        add_setting_key(opacity_id)
        add_setting_key(red_id)
        add_setting_key(green_id)
        add_setting_key(blue_id)

        widgets[#widgets + 1] = {
            setting_id = mod.flux_get_archetype_group_setting_id(archetype_name),
            type = "group",
            title = mod.flux_get_archetype_group_title(archetype_name),
            localize = false,
            sub_widgets = {
                {
                    setting_id = enabled_id,
                    type = "numeric",
                    title = "archetype_enabled",
                    tooltip = "archetype_enabled_tooltip",
                    default_value = 1,
                    range = { -1, 6 },
                    decimals_number = 0,
                },
                {
                    setting_id = opacity_id,
                    type = "numeric",
                    title = "archetype_opacity",
                    default_value = 255,
                    range = { 0, 255 },
                    decimals_number = 0,
                },
                {
                    setting_id = red_id,
                    type = "numeric",
                    title = "colour_red",
                    default_value = mod.flux_default_rgb.red,
                    range = { 0, 255 },
                    decimals_number = 0,
                },
                {
                    setting_id = green_id,
                    type = "numeric",
                    title = "colour_green",
                    default_value = mod.flux_default_rgb.green,
                    range = { 0, 255 },
                    decimals_number = 0,
                },
                {
                    setting_id = blue_id,
                    type = "numeric",
                    title = "colour_blue",
                    default_value = mod.flux_default_rgb.blue,
                    range = { 0, 255 },
                    decimals_number = 0,
                },
            },
        }
    end

    return widgets
end

add_setting_key("horizontal_bar")
add_setting_key("offset_x")
add_setting_key("offset_y")
add_setting_key("bar_thickness")
add_setting_key("bar_length")
add_setting_key("text_mode")
add_setting_key("hide_when_full")
add_setting_key("font_size")
add_setting_key("font_type")
add_setting_key("charge_text_distance")
add_setting_key("cooldown_text_distance")
add_setting_key("timer_sound_enabled")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "horizontal_bar",
                tooltip = "horizontal_bar_description",
                type = "dropdown",
                default_value = mod.flux_bar_modes.horizontal,
                options = bar_mode_options(),
            },
            {
                setting_id = "offset_x",
                type = "numeric",
                default_value = 0,
                range = { -1000, 1000 },
                decimals_number = 0,
            },
            {
                setting_id = "offset_y",
                type = "numeric",
                default_value = 180,
                range = { -1000, 1000 },
                decimals_number = 0,
            },
            {
                setting_id = "bar_thickness",
                type = "numeric",
                default_value = 10,
                range = { 2, 80 },
                decimals_number = 0,
            },
            {
                setting_id = "bar_length",
                type = "numeric",
                default_value = 220,
                range = { 20, 1000 },
                decimals_number = 0,
            },
            {
                setting_id = "text_mode",
                type = "dropdown",
                default_value = mod.flux_text_modes.both,
                options = text_mode_options(),
            },
            {
                setting_id = "hide_when_full",
                tooltip = "hide_when_full_description",
                type = "checkbox",
                default_value = false,
            },
            {
                setting_id = "font_size",
                type = "numeric",
                default_value = 18,
                range = { 6, 72 },
                decimals_number = 0,
            },
            {
                setting_id = "font_type",
                type = "dropdown",
                title = mod:localize("font_type"),
                default_value = SAFE_FONT_TYPE,
                options = font_type_options(),
                localize = false,
            },
            {
                setting_id = "charge_text_distance",
                type = "numeric",
                default_value = 118,
                range = { 0, 1000 },
                decimals_number = 0,
            },
            {
                setting_id = "cooldown_text_distance",
                type = "numeric",
                default_value = 178,
                range = { 0, 1000 },
                decimals_number = 0,
            },
            {
                setting_id = "timer_sound_enabled",
                type = "dropdown",
                default_value = "default",
                tooltip = "timer_sound_tooltip",
                options = timer_sound_options(),
            },
            {
                setting_id = "archetype_colours",
                type = "group",
                sub_widgets = archetype_widgets(),
            },
        },
    },
}
