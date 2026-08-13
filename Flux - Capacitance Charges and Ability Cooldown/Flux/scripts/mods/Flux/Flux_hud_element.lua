-- File: Flux/scripts/mods/Flux/Flux_hud_element.lua
local mod = get_mod("Flux")
if not mod then return end

local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIFontSettings = mod:original_require("scripts/managers/ui/ui_font_settings")

local HudElementFlux = class("HudElementFlux", "HudElementBase")

local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_sin = math.sin
local math_pi = math.pi
local string_format = string.format
local tonumber = tonumber
local tostring = tostring

local SEGMENT_SPACING = 3
local CIRCULAR_SEGMENT_LIMIT = 32
local CIRCULAR_ARC_START = -1
local CIRCULAR_ARC_RANGE = 2
local CIRCULAR_SEGMENT_GAP_FRACTION = 0.12
local CIRCULAR_MATERIAL = "content/ui/materials/effects/forcesword_bar"
local CIRCULAR_FILL_TEXTURE = "content/ui/textures/masks/square"
local CIRCULAR_BACKGROUND_FILL_ALPHA = 0.35
local CIRCULAR_BACKGROUND_OUTLINE_ALPHA = 1
local CIRCULAR_FILLED_FILL_ALPHA = 1
local CIRCULAR_FILLED_OUTLINE_ALPHA = 1
local CIRCULAR_RADIUS = 0.6
local CIRCULAR_OUTLINE_RATIO = 0.3
local FLASH_DURATION = 0.25
local BASE_BACKGROUND_ALPHA = 90
local SHOW_ALPHA_SPEED = 8
local HIDE_ALPHA_SPEED = 3
local CHARGE_GAIN_SOUND_EVENTS = {
    zealot = "wwise/events/player/play_ability_zealot_bolstering_prayer",
    shield = "wwise/events/weapon/melee_hits_blunt_shield",
    item_tier3 = "wwise/events/ui/play_ui_item_result_ovelay_tier_3",
}

local function clamp01(value)
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end

    return value
end

local function colour_to_material(source, target, intensity)
    intensity = intensity or 1
    target[1] = math_min((source[2] or 255) / 255 * intensity, 2)
    target[2] = math_min((source[3] or 255) / 255 * intensity, 2)
    target[3] = math_min((source[4] or 255) / 255 * intensity, 2)
    target[4] = 1
end

local function format_cooldown(seconds)
    if seconds <= 0 then
        return ""
    elseif seconds <= 1 then
        return string_format("%.1fs", seconds)
    end

    return string_format("%ds", math_ceil(seconds))
end

local function selected_charge_gain_sound_event()
    local settings = mod._settings or {}

    return CHARGE_GAIN_SOUND_EVENTS[settings.timer_sound_enabled]
end

local function build_definitions()
    local text_style = table.clone(UIFontSettings.body_small)
    text_style.size = { 120, 28 }
    text_style.offset = { 0, 0, 5 }
    text_style.text_color = { 255, 255, 255, 255 }
    text_style.text_horizontal_alignment = "center"
    text_style.text_vertical_alignment = "center"
    text_style.horizontal_alignment = "center"
    text_style.vertical_alignment = "center"
    text_style.drop_shadow = true

    local cooldown_text_style = table.clone(text_style)

    return {
        scenegraph_definition = {
            screen = UIWorkspaceSettings.screen,
            area = {
                vertical_alignment = "center",
                parent = "screen",
                horizontal_alignment = "center",
                size = { 320, 120 },
                position = { 0, 180, 0 },
            },
            bar = {
                vertical_alignment = "center",
                parent = "area",
                horizontal_alignment = "center",
                size = { 220, 10 },
                position = { 0, 0, 1 },
            },
            segment = {
                vertical_alignment = "center",
                parent = "bar",
                horizontal_alignment = "center",
                size = { 220, 10 },
                position = { 0, 0, 2 },
            },
        },
        widget_definitions = {
            text = UIWidget.create_definition({
                {
                    value_id = "charge_text",
                    style_id = "charge_text",
                    pass_type = "text",
                    value = "",
                    style = text_style,
                },
                {
                    value_id = "cooldown_text",
                    style_id = "cooldown_text",
                    pass_type = "text",
                    value = "",
                    style = cooldown_text_style,
                },
            }, "bar"),
        },
    }
end

local segment_background_definition = UIWidget.create_definition({
    {
        style_id = "background",
        pass_type = "rect",
        style = {
            color = { 90, 10, 20, 30 },
            offset = { 0, 0, 0 },
        },
    },
}, "segment")

local segment_fill_definition = UIWidget.create_definition({
    {
        style_id = "fill",
        pass_type = "rect",
        style = {
            color = { 255, 150, 220, 255 },
            size = { 1, 1 },
            offset = { 0, 0, 1 },
        },
    },
}, "segment")

local function create_circular_segment_passes()
    local passes = {}

    for i = 1, CIRCULAR_SEGMENT_LIMIT do
        passes[i] = {
            pass_type = "texture_uv",
            value = CIRCULAR_MATERIAL,
            style_id = "segment_" .. i,
            style = {
                horizontal_alignment = "center",
                vertical_alignment = "center",
                offset = { 0, 0, i },
                size = { 220, 220 },
                uvs = {
                    { 0, 0 },
                    { 1, 1 },
                },
                color = { 255, 255, 255, 255 },
                material_values = {
                    amount = 0,
                    glow_on_off = 0,
                    lightning_opacity = 0,
                    arc_top_bottom = { 0, 0 },
                    fill_outline_opacity = {
                        CIRCULAR_BACKGROUND_FILL_ALPHA,
                        CIRCULAR_BACKGROUND_OUTLINE_ALPHA,
                    },
                    outline_color = { 1, 1, 1, 1 },
                    fillcolor = { 1, 1, 1, 1 },
                    SizeThicknessOutline = {
                        CIRCULAR_RADIUS,
                        0.015,
                        0.005,
                    },
                    fillTex = CIRCULAR_FILL_TEXTURE,
                },
            },
        }
    end

    return passes
end

local circular_segments_definition = UIWidget.create_definition(create_circular_segment_passes(), "bar")

HudElementFlux.init = function(self, parent, draw_layer, start_scale)
    HudElementFlux.super.init(self, parent, draw_layer, start_scale, build_definitions())

    self._segment_background_widget = self:_create_widget("flux_segment_background", segment_background_definition)
    self._segment_fill_widget = self:_create_widget("flux_segment_fill", segment_fill_definition)
    self._circular_segments_widget = self:_create_widget("flux_circular_segments", circular_segments_definition)

    self._draw = false
    self._archetype_name = nil
    self._remaining_charges = 0
    self._max_charges = 1
    self._remaining_cooldown = 0
    self._max_cooldown = 0
    self._cooldown_progress = 0
    self._last_remaining_charges = nil
    self._flash_end_t = 0
    self._segment_length = 1
    self._bar_length = 220
    self._bar_thickness = 10
    self._horizontal = true
    self._bar_mode = "horizontal"
    self._reverse_fill = false
    self._draw_color = { 255, 150, 220, 255 }
    self._flash_color = { 255, 255, 255, 255 }
    self._layout_max_charges = nil
    self._layout_bar_mode = nil
    self._alpha_multiplier = 1

    self:_refresh_layout()
end

HudElementFlux.destroy = function(self, ui_renderer)
    if ui_renderer then
        if self._segment_background_widget then
            UIWidget.destroy(ui_renderer, self._segment_background_widget)
            self._segment_background_widget = nil
        end

        if self._segment_fill_widget then
            UIWidget.destroy(ui_renderer, self._segment_fill_widget)
            self._segment_fill_widget = nil
        end

        if self._circular_segments_widget then
            UIWidget.destroy(ui_renderer, self._circular_segments_widget)
            self._circular_segments_widget = nil
        end
    end

    HudElementFlux.super.destroy(self, ui_renderer)
end

HudElementFlux._read_ability_data = function(self)
    local player_manager = Managers.player
    local player = player_manager and player_manager:local_player_safe(1)
    local player_unit = player and player.player_unit

    if not (player_unit and ALIVE[player_unit]) then
        return false
    end

    local archetype_name = player.archetype_name and player:archetype_name() or nil
    self._archetype_name = archetype_name

    if mod.flux_is_archetype_enabled and not mod.flux_is_archetype_enabled(archetype_name) then
        return false
    end

    local ability_extension = ScriptUnit.has_extension(player_unit, "ability_system")

    if not ability_extension then
        return false
    end

    local ability_components = ability_extension._ability_components
    local combat_ability_component = ability_components and ability_components.combat_ability

    if not combat_ability_component then
        return false
    end

    if not (
            ability_extension.ability_is_equipped
            and ability_extension.max_ability_charges
            and ability_extension.remaining_ability_charges
            and ability_extension.remaining_ability_cooldown
            and ability_extension.max_ability_cooldown
        ) then
        return false
    end

    if not ability_extension:ability_is_equipped("combat_ability") then
        return false
    end

    local max_charges = ability_extension:max_ability_charges("combat_ability") or 0

    if max_charges <= 0 then
        return false
    end

    if mod.flux_is_archetype_enabled and not mod.flux_is_archetype_enabled(archetype_name, max_charges) then
        return false
    end

    local remaining_charges = ability_extension:remaining_ability_charges("combat_ability") or 0
    local remaining_cooldown = ability_extension:remaining_ability_cooldown("combat_ability") or 0
    local max_cooldown = ability_extension:max_ability_cooldown("combat_ability") or 0
    local paused = combat_ability_component.cooldown_paused == true

    remaining_charges = math_floor(remaining_charges + 0.0001)
    max_charges = math_max(1, math_floor(max_charges + 0.0001), remaining_charges)

    self._remaining_charges = math_min(remaining_charges, max_charges)
    self._max_charges = max_charges
    self._remaining_cooldown = remaining_cooldown
    self._max_cooldown = max_cooldown

    if paused then
        self._cooldown_progress = 0
    elseif remaining_charges >= max_charges then
        self._cooldown_progress = 0
    elseif max_cooldown > 0 then
        self._cooldown_progress = clamp01(1 - remaining_cooldown / max_cooldown)
    else
        self._cooldown_progress = 0
    end

    return true
end

HudElementFlux._apply_area_position = function(self, x_offset, y_offset)
    local scenegraph = self._ui_scenegraph
    local area = scenegraph and rawget(scenegraph, "area")

    if not area then
        return
    end

    if area.horizontal_alignment == "left" and area.vertical_alignment == "top" then
        return
    end

    local position = area.position or {}
    local target_z = position[3] or 0

    if area.horizontal_alignment ~= "center"
        or area.vertical_alignment ~= "center"
        or math_abs((position[1] or 0) - x_offset) > 0.001
        or math_abs((position[2] or 0) - y_offset) > 0.001
    then
        self:set_scenegraph_position("area", x_offset, y_offset, target_z, "center", "center")
    end
end

HudElementFlux._sync_area_position = function(self)
    local settings = mod._settings or {}
    local offset_x = tonumber(settings.offset_x) or 0
    local offset_y = tonumber(settings.offset_y) or 180

    self:_apply_area_position(offset_x, offset_y)
end

HudElementFlux._refresh_layout = function(self)
    local settings = mod._settings or {}
    local bar_mode = mod.flux_normalize_bar_mode and mod.flux_normalize_bar_mode(settings.horizontal_bar) or "horizontal"
    local circular = string.find(bar_mode, "circular") ~= nil
    local horizontal = string.find(bar_mode, "horizontal") ~= nil
    local reverse_fill = string.find(bar_mode, "_rev") ~= nil
    local max_charges = math_max(1, self._max_charges or 1)
    local length = tonumber(settings.bar_length) or 220
    local thickness = tonumber(settings.bar_thickness) or 10
    local total_spacing = SEGMENT_SPACING * math_max(max_charges - 1, 0)
    local segment_length = circular and length or math_max(1, (length - total_spacing) / max_charges)
    local charge_text_distance = tonumber(settings.charge_text_distance) or 118
    local cooldown_text_distance = tonumber(settings.cooldown_text_distance) or 178
    local font_size = tonumber(settings.font_size) or 18
    local font_type = settings.font_type or mod.flux_safe_font_type or "proxima_nova_bold"
    local text_extent = math_max(charge_text_distance, cooldown_text_distance) + 80
    local area_width = (horizontal or circular) and (length + text_extent * 2) or (text_extent * 2)
    local area_height = circular and (length + text_extent * 2) or
        (horizontal and math_max(96, thickness + 80) or (length + text_extent * 2))

    self._bar_mode = bar_mode
    self._horizontal = horizontal
    self._bar_length = length
    self._bar_thickness = thickness
    self._segment_length = segment_length
    self._reverse_fill = reverse_fill
    self._layout_max_charges = max_charges
    self._layout_bar_mode = bar_mode

    self:_sync_area_position()
    self:_set_scenegraph_size("area", area_width, area_height)
    self:_set_scenegraph_size("bar", circular and length or (horizontal and length or thickness),
        circular and length or (horizontal and thickness or length))
    self:_set_scenegraph_size("segment", horizontal and segment_length or thickness,
        horizontal and thickness or segment_length)

    local text_widget = self._widgets_by_name.text
    if text_widget then
        local charge_style = text_widget.style.charge_text
        local cooldown_style = text_widget.style.cooldown_text
        local charge_offset = charge_style.offset
        local cooldown_offset = cooldown_style.offset
        local vertical_text_correction = horizontal and 0 or segment_length * 0.55

        charge_style.font_size = font_size
        charge_style.font_type = font_type
        charge_style.horizontal_alignment = "center"
        charge_style.vertical_alignment = "center"
        charge_style.text_horizontal_alignment = "center"
        charge_style.text_vertical_alignment = "center"

        cooldown_style.font_size = font_size
        cooldown_style.font_type = font_type
        cooldown_style.horizontal_alignment = "center"
        cooldown_style.vertical_alignment = "center"
        cooldown_style.text_horizontal_alignment = "center"
        cooldown_style.text_vertical_alignment = "center"

        if horizontal or circular then
            charge_offset[1] = charge_text_distance
            charge_offset[2] = 0
            cooldown_offset[1] = -cooldown_text_distance
            cooldown_offset[2] = 0
        else
            charge_offset[1] = 0
            charge_offset[2] = charge_text_distance + vertical_text_correction
            cooldown_offset[1] = 0
            cooldown_offset[2] = -cooldown_text_distance + vertical_text_correction
        end
    end

    local fill_style = self._segment_fill_widget and self._segment_fill_widget.style.fill
    if fill_style then
        if horizontal then
            fill_style.horizontal_alignment = reverse_fill and "right" or "left"
            fill_style.vertical_alignment = "center"
        else
            fill_style.horizontal_alignment = "center"
            fill_style.vertical_alignment = reverse_fill and "top" or "bottom"
        end
    end

    if self._segment_background_widget then
        self._segment_background_widget.visible = not circular
    end

    if self._segment_fill_widget then
        self._segment_fill_widget.visible = not circular
    end

    local circular_widget = self._circular_segments_widget
    if circular_widget then
        circular_widget.visible = circular

        local styles = circular_widget.style
        local segment_span = max_charges > 0 and CIRCULAR_ARC_RANGE / max_charges or CIRCULAR_ARC_RANGE
        local gap = segment_span * CIRCULAR_SEGMENT_GAP_FRACTION
        local thickness_ratio = math_max(0.001, math_min(0.5, thickness / math_max(length, 1)))
        local outline_ratio = math_max(0.001, thickness_ratio * CIRCULAR_OUTLINE_RATIO)

        for i = 1, CIRCULAR_SEGMENT_LIMIT do
            local style = styles["segment_" .. i]

            if style then
                local material_values = style.material_values

                style.size[1] = length
                style.size[2] = length
                style.uvs[1][1] = reverse_fill and 1 or 0
                style.uvs[1][2] = 0
                style.uvs[2][1] = reverse_fill and 0 or 1
                style.uvs[2][2] = 1

                if i <= max_charges then
                    local low = CIRCULAR_ARC_START + (i - 1) * segment_span
                    local high = CIRCULAR_ARC_START + i * segment_span

                    material_values.arc_top_bottom[1] = high - gap
                    material_values.arc_top_bottom[2] = low + gap
                    material_values.fill_outline_opacity[1] = CIRCULAR_BACKGROUND_FILL_ALPHA
                    material_values.fill_outline_opacity[2] = CIRCULAR_BACKGROUND_OUTLINE_ALPHA
                else
                    material_values.arc_top_bottom[1] = 0
                    material_values.arc_top_bottom[2] = 0
                    material_values.fill_outline_opacity[1] = 0
                    material_values.fill_outline_opacity[2] = 0
                end

                material_values.SizeThicknessOutline[1] = CIRCULAR_RADIUS
                material_values.SizeThicknessOutline[2] = thickness_ratio
                material_values.SizeThicknessOutline[3] = outline_ratio
            end
        end
    end

    mod.flux_layout_dirty = false
end

HudElementFlux._update_text_opacity = function(self, widget, opacity)
    local style = widget and widget.style
    local charge_style = style and style.charge_text
    local cooldown_style = style and style.cooldown_text

    if charge_style and charge_style.text_color then
        charge_style.text_color[1] = opacity
    end

    if cooldown_style and cooldown_style.text_color then
        cooldown_style.text_color[1] = opacity
    end
end

HudElementFlux._effective_opacity = function(self)
    local opacity = mod.flux_get_archetype_opacity and mod.flux_get_archetype_opacity(self._archetype_name) or 255

    return math_floor(opacity * (self._alpha_multiplier or 1) + 0.5)
end

HudElementFlux._update_alpha_multiplier = function(self, dt)
    local settings = mod._settings or {}
    local should_draw = settings.hide_when_full ~= true or self._remaining_charges < self._max_charges
    local alpha_speed = should_draw and SHOW_ALPHA_SPEED or HIDE_ALPHA_SPEED
    local alpha_multiplier = self._alpha_multiplier or 0

    if should_draw then
        alpha_multiplier = math_min(alpha_multiplier + dt * alpha_speed, 1)
    else
        alpha_multiplier = math_max(alpha_multiplier - dt * alpha_speed, 0)
    end

    self._alpha_multiplier = alpha_multiplier
end

HudElementFlux._update_text = function(self)
    local widget = self._widgets_by_name.text
    if not widget then
        return
    end

    local settings = mod._settings or {}
    local mode = settings.text_mode or "both"
    local show_charges = string.find(mode, "charges") ~= nil or string.find(mode, "both") ~= nil
    local show_cooldown = string.find(mode, "cooldown") ~= nil or string.find(mode, "both") ~= nil
    local show_pct = string.find(mode, "_pct") ~= nil
    local not_at_max_charges = self._remaining_charges < self._max_charges
    local recharge_active = not_at_max_charges and self._remaining_cooldown > 0
    local charge_text = ""
    local opacity = self:_effective_opacity()

    if show_charges then
        charge_text = tostring(self._remaining_charges)

        if show_pct and not_at_max_charges then
            charge_text = charge_text .. " • " .. tostring(math_floor(self._cooldown_progress * 100 + 0.5)) .. "%"
        end
    end

    widget.content.charge_text = charge_text
    widget.content.cooldown_text = (show_cooldown and recharge_active) and format_cooldown(self._remaining_cooldown) or
        ""
    widget.content.visible = self._draw

    self:_update_text_opacity(widget, opacity)
end

HudElementFlux.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    HudElementFlux.super.update(self, dt, t, ui_renderer, render_settings, input_service)

    if not mod:is_enabled() or mod.flux_is_in_hub and mod.flux_is_in_hub() then
        self._draw = false
        self._last_remaining_charges = nil
        self._alpha_multiplier = 0
        return
    end

    self._draw = self:_read_ability_data()

    if not self._draw then
        self._last_remaining_charges = nil
        self._alpha_multiplier = 0
        return
    end

    local first_update = self._last_remaining_charges == nil
    local settings = mod._settings or {}

    if first_update and settings.hide_when_full == true and self._remaining_charges >= self._max_charges then
        self._alpha_multiplier = 0
    else
        self:_update_alpha_multiplier(dt)
    end

    local gained_charge = self._last_remaining_charges and self._remaining_charges > self._last_remaining_charges

    if gained_charge then
        if settings.timer_sound_enabled and settings.timer_sound_enabled ~= "default" then
            self._flash_end_t = t + FLASH_DURATION
        end

        local sound_event = selected_charge_gain_sound_event()
        if sound_event then
            self:_play_sound(sound_event)
        end
    end

    self._last_remaining_charges = self._remaining_charges

    local current_bar_mode = mod.flux_normalize_bar_mode and mod.flux_normalize_bar_mode(settings.horizontal_bar) or
    "horizontal"

    if mod.flux_layout_dirty or self._layout_max_charges ~= self._max_charges or
        self._layout_bar_mode ~= current_bar_mode then
        self:_refresh_layout()
    else
        self:_sync_area_position()
    end

    self:_update_text()
end

HudElementFlux._segment_fill_fraction = function(self, index)
    local remaining_charges = self._remaining_charges

    if index <= remaining_charges then
        return 1
    elseif index == remaining_charges + 1 and remaining_charges < self._max_charges then
        return self._cooldown_progress
    end

    return 0
end

HudElementFlux._set_draw_colour = function(self, t)
    local base_colour = mod.flux_get_archetype_color(self._archetype_name)
    local opacity = self:_effective_opacity()
    local colour = self._draw_color
    local flash_end_t = self._flash_end_t or 0

    if t < flash_end_t then
        local progress = clamp01((FLASH_DURATION - (flash_end_t - t)) / FLASH_DURATION)
        local flash = math_sin(progress * math_pi)

        colour[1] = opacity
        colour[2] = math_min(255, base_colour[2] + (255 - base_colour[2]) * flash)
        colour[3] = math_min(255, base_colour[3] + (255 - base_colour[3]) * flash)
        colour[4] = math_min(255, base_colour[4] + (255 - base_colour[4]) * flash)
    else
        colour[1] = opacity
        colour[2] = base_colour[2]
        colour[3] = base_colour[3]
        colour[4] = base_colour[4]
    end

    local background_style = self._segment_background_widget and self._segment_background_widget.style.background
    if background_style and background_style.color then
        background_style.color[1] = math_floor(BASE_BACKGROUND_ALPHA * opacity / 255 + 0.5)
    end

    local fill_style = self._segment_fill_widget and self._segment_fill_widget.style.fill
    if fill_style then
        local target = fill_style.color
        target[1] = colour[1]
        target[2] = colour[2]
        target[3] = colour[3]
        target[4] = colour[4]
    end

    local circular_widget = self._circular_segments_widget
    if circular_widget then
        local styles = circular_widget.style

        for i = 1, CIRCULAR_SEGMENT_LIMIT do
            local style = styles["segment_" .. i]

            if style then
                style.color[1] = 255
                style.color[2] = 255
                style.color[3] = 255
                style.color[4] = 255

                local material_values = style.material_values
                colour_to_material(colour, material_values.fillcolor)
                colour_to_material(colour, material_values.outline_color)
            end
        end
    end
end

HudElementFlux._draw_segments = function(self, t, ui_renderer)
    local background_widget = self._segment_background_widget
    local fill_widget = self._segment_fill_widget

    if (self._bar_mode and string.find(self._bar_mode, "circular")) or
        not (background_widget and fill_widget and ui_renderer) then
        return
    end

    self:_set_draw_colour(t)

    local horizontal = self._horizontal
    local max_charges = self._max_charges
    local segment_length = self._segment_length
    local thickness = self._bar_thickness
    local reverse_fill = self._reverse_fill == true
    local step = segment_length + SEGMENT_SPACING
    local total_length = (step * max_charges) - SEGMENT_SPACING
    local start = -(total_length - segment_length) * 0.5
    local background_offset = background_widget.offset
    local fill_offset = fill_widget.offset
    local fill_size = fill_widget.style.fill.size

    for i = 1, max_charges do
        local fill_fraction = self:_segment_fill_fraction(i)
        local visual_index = reverse_fill and (max_charges - i + 1) or i
        local offset_along_bar = start + (visual_index - 1) * step

        if horizontal then
            background_offset[1] = offset_along_bar
            background_offset[2] = 0
            fill_offset[1] = offset_along_bar
            fill_offset[2] = 0
            fill_size[1] = segment_length * fill_fraction
            fill_size[2] = thickness
        else
            background_offset[1] = 0
            background_offset[2] = -offset_along_bar
            fill_offset[1] = 0
            fill_offset[2] = -offset_along_bar
            fill_size[1] = thickness
            fill_size[2] = segment_length * fill_fraction
        end

        UIWidget.draw(background_widget, ui_renderer)

        if fill_fraction > 0 then
            UIWidget.draw(fill_widget, ui_renderer)
        end
    end
end

HudElementFlux._draw_circular_segments = function(self, t, ui_renderer)
    local widget = self._circular_segments_widget

    if not (widget and ui_renderer) then
        return
    end

    if not (self._bar_mode and string.find(self._bar_mode, "circular")) then
        return
    end

    self:_set_draw_colour(t)

    local styles = widget.style
    local max_charges = math_min(self._max_charges or 0, CIRCULAR_SEGMENT_LIMIT)
    local opacity_fraction = self:_effective_opacity() / 255
    local background_fill_opacity = CIRCULAR_BACKGROUND_FILL_ALPHA * opacity_fraction
    local background_outline_opacity = CIRCULAR_BACKGROUND_OUTLINE_ALPHA * opacity_fraction
    local filled_fill_opacity = CIRCULAR_FILLED_FILL_ALPHA * opacity_fraction
    local filled_outline_opacity = CIRCULAR_FILLED_OUTLINE_ALPHA * opacity_fraction

    for i = 1, CIRCULAR_SEGMENT_LIMIT do
        local style = styles["segment_" .. i]

        if style then
            local material_values = style.material_values
            local fill_fraction = i <= max_charges and self:_segment_fill_fraction(i) or 0

            material_values.amount = fill_fraction

            if i <= max_charges then
                if fill_fraction > 0 then
                    material_values.fill_outline_opacity[1] = filled_fill_opacity
                    material_values.fill_outline_opacity[2] = filled_outline_opacity
                else
                    material_values.fill_outline_opacity[1] = background_fill_opacity
                    material_values.fill_outline_opacity[2] = background_outline_opacity
                end
            else
                material_values.fill_outline_opacity[1] = 0
                material_values.fill_outline_opacity[2] = 0
            end
        end
    end

    UIWidget.draw(widget, ui_renderer)
end

HudElementFlux._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)
    if not self._draw or self._alpha_multiplier <= 0 then
        return
    end

    if self._bar_mode and string.find(self._bar_mode, "circular") then
        self:_draw_circular_segments(t, ui_renderer)
    else
        self:_draw_segments(t, ui_renderer)
    end

    HudElementFlux.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

return HudElementFlux
