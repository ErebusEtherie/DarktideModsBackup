-- File: uptime/scripts/mods/uptime/view/uptime_scoreboard.lua
local mod = get_mod("uptime"); if not mod then return end

local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")

local ipairs = ipairs
local math_floor = math.floor
local math_max = math.max
local string_len = string.len
local string_sub = string.sub
local table_insert = table.insert
local table_remove = table.remove

local archetype_font_icon = UISettings and UISettings.archetype_font_icon or {}

local function create_header(view, id, text, width, color, font_type)
    local passes = {
        {
            pass_type = "rect",
            style = {
                color = Color.terminal_grid_background(180, true),
                offset = { 0, 0, 250 }
            }
        },
        {
            pass_type = "text",
            value_id = "text",
            style = {
                font_type = font_type or "machine_medium",
                font_size = 22,
                text_color = color or Color.ui_terminal(255, true),
                offset = { 0, 0, 260 },
                size = { width, 40 },
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                drop_shadow = true
            }
        }
    }
    local def = UIWidget.create_definition(passes, "scoreboard_grid_content", nil, { width, 40 })
    local widget = view:_create_widget(id, def)
    widget.content.text = text
    return widget
end

local function create_stat_row(view, id, label, value, width, val_color, is_highlighted)
    local bg_color = is_highlighted and Color.ui_terminal(40, true) or Color.terminal_grid_background(180, true)

    local passes = {
        {
            pass_type = "rect",
            style = {
                color = bg_color,
                offset = { 0, 0, 250 }
            }
        },
        {
            pass_type = "text",
            value_id = "label",
            style = {
                font_type = "machine_medium",
                font_size = 18,
                text_color = Color.terminal_text_header(255, true),
                offset = { 10, 0, 260 },
                size = { width / 2 - 10, 25 },
                text_horizontal_alignment = "left",
                text_vertical_alignment = "center",
                drop_shadow = true
            }
        },
        {
            pass_type = "text",
            value_id = "value",
            style = {
                font_type = "machine_medium",
                font_size = 18,
                text_color = val_color or Color.ui_grey_light(255, true),
                offset = { width / 2, 0, 260 },
                size = { width / 2 - 15, 25 },
                text_horizontal_alignment = "right",
                text_vertical_alignment = "center",
                drop_shadow = true
            }
        }
    }
    local def = UIWidget.create_definition(passes, "scoreboard_grid_content", nil, { width, 25 })
    local widget = view:_create_widget(id, def)
    widget.content.label = label
    widget.content.value = value
    return widget
end

local CATEGORY_METADATA = {
    Blitz = { frame = "square_frame", mask = "square_frame_mask" },
    Aura = { frame = "circular_frame", mask = "circular_frame_mask" },
    Ability = { frame = "hex_frame", mask = "hex_frame_mask" },
    Keystone = { frame = "circular_frame", mask = "circular_frame_mask" },
    Companion = { frame = "circular_frame", mask = "circular_frame_mask" },
}

local function create_loadout_talents_row(view, id, icons, width)
    local icon_count = icons and #icons or 0
    local icon_size = 46
    local icon_spacing = icon_count > 4 and 5 or 10
    local horizontal_padding = 12
    local total_talent_width = icon_count * icon_size + math_max(0, icon_count - 1) * icon_spacing

    if icon_count > 0 and total_talent_width > width - horizontal_padding then
        icon_spacing = 4
        icon_size = math_floor((width - horizontal_padding - math_max(0, icon_count - 1) * icon_spacing) / icon_count)
        total_talent_width = icon_count * icon_size + math_max(0, icon_count - 1) * icon_spacing
    end

    local row_height = icon_size + 16
    local start_talent_x = (width - total_talent_width) * 0.5
    local talent_y = (row_height - icon_size) * 0.5

    local passes = {
        {
            pass_type = "rect",
            style = {
                color = Color.terminal_grid_background(180, true),
                offset = { 0, 0, 250 }
            }
        }
    }

    local loadout_tooltips = {}
    local loadout_hotspot_ids = {}
    local hotspot_count = 0

    for i = 1, icon_count do
        local icon_data = icons and icons[i]
        local icon_texture = icon_data and icon_data.icon or ""

        if icon_texture ~= "" then
            local gradient_map = icon_data and icon_data.gradient_map or "content/ui/textures/color_ramps/talent_default"
            local category = icon_data and icon_data.category or "Ability"
            local meta = CATEGORY_METADATA[category] or CATEGORY_METADATA.Ability

            hotspot_count = hotspot_count + 1

            local icon_style_id = "loadout_icon_" .. i
            local hotspot_id = "loadout_icon_hotspot_" .. i
            local icon_offset = { start_talent_x + (i - 1) * (icon_size + icon_spacing), talent_y, 260 }

            loadout_tooltips[hotspot_count] = icon_data and icon_data.tooltip or nil
            loadout_hotspot_ids[hotspot_count] = hotspot_id

            passes[#passes + 1] = {
                pass_type = "hotspot",
                content_id = hotspot_id,
                style_id = hotspot_id,
                style = { size = { icon_size, icon_size }, offset = { icon_offset[1], icon_offset[2], 280 } }
            }
            passes[#passes + 1] = {
                pass_type = "texture",
                value_id = icon_style_id,
                style_id = icon_style_id,
                value = "content/ui/materials/frames/talents/talent_icon_container",
                style = {
                    size = { icon_size, icon_size },
                    offset = icon_offset,
                    color = Color.white(255, true),
                    material_values = {
                        frame = "content/ui/textures/frames/talents/" .. meta.frame,
                        icon_mask = "content/ui/textures/frames/talents/" .. meta.mask,
                        icon = icon_texture,
                        gradient_map = gradient_map,
                        intensity = 0,
                        saturation = 1,
                    }
                }
            }
        end
    end

    local def = UIWidget.create_definition(passes, "scoreboard_grid_content", nil, { width, row_height })
    local widget = view:_create_widget(id, def)

    widget.loadout_tooltips = loadout_tooltips
    widget.loadout_hotspot_ids = loadout_hotspot_ids

    return widget
end

local function create_loadout_weapons_row(view, id, weapons, width)
    local weapon_width = 110
    local weapon_height = 40
    local weapon_spacing = 10
    local weapon_count = 2

    local row_height = 58
    local total_weapon_width = weapon_count * weapon_width + (weapon_count - 1) * weapon_spacing
    local start_weapon_x = (width - total_weapon_width) * 0.5
    local weapon_y = 8

    local passes = {
        {
            pass_type = "rect",
            style = {
                color = Color.terminal_grid_background(180, true),
                offset = { 0, 0, 250 }
            }
        }
    }

    local loadout_tooltips = {}
    local loadout_hotspot_ids = {}

    -- Weapons
    if weapons then
        for i = 1, weapon_count do
            local w_data = weapons[i]
            if w_data and w_data.icon and w_data.icon ~= "" then
                local w_icon_style_id = "weapon_icon_" .. i
                local w_hotspot_id = "weapon_icon_hotspot_" .. i
                local w_offset = { start_weapon_x + (i - 1) * (weapon_width + weapon_spacing), weapon_y, 260 }

                local display_name = w_data.display_name or "Weapon"
                local description = w_data.description or ""
                loadout_tooltips[#loadout_tooltips + 1] = { title = display_name, description = description }
                loadout_hotspot_ids[#loadout_hotspot_ids + 1] = w_hotspot_id

                passes[#passes + 1] = {
                    pass_type = "hotspot",
                    content_id = w_hotspot_id,
                    style_id = w_hotspot_id,
                    style = { size = { weapon_width, weapon_height }, offset = { w_offset[1], w_offset[2], 280 } }
                }
                passes[#passes + 1] = {
                    pass_type = "texture",
                    value_id = w_icon_style_id,
                    style_id = w_icon_style_id,
                    value = w_data.icon,
                    style = { size = { weapon_width, weapon_height }, offset = w_offset, color = Color.white(255, true) }
                }
            end
        end
    end

    local def = UIWidget.create_definition(passes, "scoreboard_grid_content", nil, { width, row_height })
    local widget = view:_create_widget(id, def)

    widget.loadout_tooltips = loadout_tooltips
    widget.loadout_hotspot_ids = loadout_hotspot_ids

    return widget
end

local function create_divider(view, id, width)
    local passes = {
        {
            pass_type = "rect",
            style = {
                color = Color.terminal_grid_background(180, true),
                offset = { 0, 0, 250 }
            }
        },
        {
            pass_type = "rect",
            style = {
                color = Color.terminal_frame(150, true),
                size = { width - 40, 2 },
                offset = { 20, 9, 260 }
            }
        }
    }
    local def = UIWidget.create_definition(passes, "scoreboard_grid_content", nil, { width, 20 })
    return view:_create_widget(id, def)
end

local function create_spacer(view, id, width, height)
    local passes = {
        {
            pass_type = "rect",
            style = {
                color = { 0, 0, 0, 0 },
                offset = { 0, 0, 250 }
            }
        }
    }
    local def = UIWidget.create_definition(passes, "scoreboard_grid_content", nil, { width, height })
    return view:_create_widget(id, def)
end

local function get_scoreboard_widgets(uptime_view, damage_data, width)
    local widgets = {}
    local widget_count = 0
    local function next_id(prefix)
        widget_count = widget_count + 1
        return prefix .. "_" .. widget_count
    end

    if not damage_data then
        return widgets
    end

    table_insert(widgets,
        create_header(uptime_view, next_id("sb_header"), mod:localize("loc_scoreboard_local_player"), width))

    if damage_data.local_player then
        local lp = damage_data.local_player
        table_insert(widgets,
            create_stat_row(uptime_view, next_id("sb_stat"), mod:localize("loc_damage_melee"), lp.melee_str, width))
        table_insert(widgets,
            create_stat_row(uptime_view, next_id("sb_stat"), mod:localize("loc_damage_ranged"), lp.ranged_str, width))
        table_insert(widgets,
            create_stat_row(uptime_view, next_id("sb_stat"), mod:localize("loc_damage_blitz"), lp.blitz_str, width))
        table_insert(widgets,
            create_stat_row(uptime_view, next_id("sb_stat"), mod:localize("loc_damage_dot"), lp.dot_str, width))
        table_insert(widgets,
            create_stat_row(uptime_view, next_id("sb_stat"), mod:localize("loc_damage_total"), lp.total_str, width,
                Color.ui_orange_light(255, true)))
    end

    table_insert(widgets, create_divider(uptime_view, next_id("sb_div"), width))
    table_insert(widgets, create_header(uptime_view, next_id("sb_header"), mod:localize("loc_scoreboard_team"), width))

    local team = damage_data.team or {}

    for _, p in ipairs(team) do
        if p then
            local name = p.name or "?"
            if string_len(name) > 18 then name = string_sub(name, 1, 16) .. ".." end

            local archetype_icon = p.archetype and archetype_font_icon[p.archetype]
            if archetype_icon then
                name = archetype_icon .. " " .. name
            end

            table_insert(widgets,
                create_header(
                    uptime_view,
                    next_id("sb_player"),
                    name,
                    width,
                    Color.ui_grey_light(255, true),
                    "proxima_nova_bold"
                ))

            local stat_rows = p.stat_rows or {}
            local stat_rows_n = p.stat_rows_n or #stat_rows

            for i = 1, stat_rows_n do
                local row = stat_rows[i]

                if row then
                    table_insert(widgets,
                        create_stat_row(
                            uptime_view,
                            next_id("sb_stat"),
                            row.label or row.key or "",
                            row.value_str or "0",
                            width,
                            row.is_total and Color.ui_orange_light(255, true) or nil,
                            row.is_ranked
                        )
                    )
                end
            end

            if p.loadout_icons or p.loadout_weapons then
                if p.loadout_icons and #p.loadout_icons > 0 then
                    table_insert(widgets,
                        create_loadout_talents_row(uptime_view, next_id("sb_loadout_talents"), p.loadout_icons, width))
                end
                if p.loadout_weapons and #p.loadout_weapons > 0 then
                    table_insert(widgets,
                        create_loadout_weapons_row(uptime_view, next_id("sb_loadout_weapons"), p.loadout_weapons, width))
                end
            end

            table_insert(widgets, create_divider(uptime_view, next_id("sb_div"), width))
        end
    end

    if #team > 0 then
        table_remove(widgets, #widgets)
        table_insert(widgets, create_spacer(uptime_view, next_id("sb_spacer"), width, 25))
    end

    return widgets
end

return get_scoreboard_widgets
