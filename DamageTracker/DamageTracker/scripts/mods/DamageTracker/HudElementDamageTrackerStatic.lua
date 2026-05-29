local mod = get_mod("DamageTracker")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")

local sizeAnim = { 400, 100 }

local ICON_CONFIG = {
    none = { texture = "", size_multiplier = 0, padding = 0},
    weapons = { texture = "content/ui/materials/icons/item_types/weapons", size_multiplier = 1.0, padding = 4},
    objective_main = { texture = "content/ui/materials/hud/interactions/icons/objective_main", size_multiplier = 2.0, padding = 6},
    incapacitated = { texture = "content/ui/materials/icons/player_states/incapacitated", size_multiplier = 1.5, padding = 0},
    mission_type_01 = { texture = "content/ui/materials/icons/mission_types/mission_type_01", size_multiplier = 0.9, padding = 3},
    difficulty_skull_heresy = { texture = "content/ui/materials/icons/difficulty/flat/difficulty_skull_heresy", size_multiplier = 1.5, padding = 4},
    difficulty_skull_uprising = { texture = "content/ui/materials/icons/difficulty/flat/difficulty_skull_uprising", size_multiplier = 1.5, padding = 4},
    dead = { texture = "content/ui/materials/icons/player_states/dead", size_multiplier = 1.3, padding = 6},
    pocketable_syringe_power = { texture = "content/ui/materials/hud/interactions/icons/pocketable_syringe_power", size_multiplier = 1.3, padding = 6},
    scars = { texture = "content/ui/materials/icons/item_types/scars", size_multiplier = 1.3, padding = 4},
    preset_19 = { texture = "content/ui/materials/icons/presets/preset_19", size_multiplier = 1.0, padding = 6},
}

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
	topContainer = { parent = "screen", vertical_alignment = "center", horizontal_alignment = "center", size = sizeAnim, position = { 0, 0, 10 } },
	bottomContainer = { parent = "screen", vertical_alignment = "center", horizontal_alignment = "center", size = sizeAnim, position = { 0, 0, 10 } },
}

local base_style = { line_spacing = 1.2, drop_shadow = true, font_type = "machine_medium", size = sizeAnim, text_horizontal_alignment = "center", text_vertical_alignment = "center", offset = { 0, 0, 10 } }

local widget_definitions = {
	topDamageText = UIWidget.create_definition({
        { value = "", value_id = "text", style_id = "text", pass_type = "text", style = table.clone(base_style) },
        { value = "", value_id = "icon", style_id = "icon", pass_type = "texture", style = { vertical_alignment = "center", horizontal_alignment = "center", color = { 0, 255, 255, 255 }, size = { 40, 40 }, offset = { 0, 0, 10 } } }
    }, "topContainer"),
	bottomDamageText = UIWidget.create_definition({
        { value = "", value_id = "text", style_id = "text", pass_type = "text", style = table.clone(base_style) },
        { value = "", value_id = "icon", style_id = "icon", pass_type = "texture", style = { vertical_alignment = "center", horizontal_alignment = "center", color = { 0, 255, 255, 255 }, size = { 40, 40 }, offset = { 0, 0, 10 } } }
    }, "bottomContainer"),
}

local HudElementDamageTrackerStatic = class("HudElementDamageTrackerStatic", "HudElementBase")

HudElementDamageTrackerStatic.init = function(self, parent, draw_layer, start_scale)
	HudElementDamageTrackerStatic.super.init(self, parent, draw_layer, start_scale, {
		scenegraph_definition = scenegraph_definition,
		widget_definitions = widget_definitions,
	})
    
    self.display_duration = 2.0

    self.lines = {
        top = { active=false, timer=0, total=0, last=0, last_time=0, widget_name="topDamageText", style_type="combined", dirty=false, text_width=0 },
        bottom = { active=false, timer=0, total=0, last=0, last_time=0, widget_name="bottomDamageText", style_type="dot", dirty=false, text_width=0 }
    }

    Managers.event:register(self, "damage_tracker_on_damage", "_on_static_damage")
    Managers.event:register(self, "damage_tracker_settings_changed", "_apply_widget_settings")
    self:_apply_widget_settings()
end

HudElementDamageTrackerStatic.destroy = function(self)
    Managers.event:unregister(self, "damage_tracker_on_damage")
    Managers.event:unregister(self, "damage_tracker_settings_changed")
    HudElementDamageTrackerStatic.super.destroy(self)
end

local function get_color(color_name, fallback)
    local c = Color[color_name] and Color[color_name](255, true) or Color[fallback](255, true)
    return table.clone(c)
end

local function preload_style(prefix, default_color, default_icon_key)
    local icon_key = mod:get(prefix .. "_icon") or default_icon_key
    local icon_cfg = ICON_CONFIG[icon_key] or ICON_CONFIG.none
    return { color = get_color(mod:get(prefix .. "_color"), default_color), icon_cfg = icon_cfg, icon_key = icon_key, size = mod:get(prefix .. "_size") or 40 }
end

HudElementDamageTrackerStatic._apply_widget_settings = function(self)
    self._cached_ui_settings = self._cached_ui_settings or {}
    local s = self._cached_ui_settings

    s.tracking_mode = mod:get("tracking_mode") or "combined"
    s.display_format = mod:get("display_format") or "both"
    s.main_x = mod:get("main_x") or 350
    s.main_y = mod:get("main_y") or 150
    s.main_text_size = mod:get("main_text_size") or 40

    s.styles = {
        combined = preload_style("combined", "terminal_text_header", "preset_19"),
        direct = preload_style("direct", "ui_hud_green_super_light", "weapons"),
        dot = preload_style("dot", "medium_turquoise", "dead")
    }

    self.lines.top.dirty = true
    self.lines.bottom.dirty = true
end

HudElementDamageTrackerStatic._on_static_damage = function(self, damage, damage_category, last_damage)
    local t = Managers.time:time("ui")
    local s = self._cached_ui_settings
    local mode = s.tracking_mode
    if mode == "disabled" then return end

    local is_dot = (damage_category == "main_dot")
    local target_line, style_type = nil, nil

    if mode == "combined" then target_line, style_type = self.lines.top, "combined"
    elseif mode == "separated" then target_line, style_type = is_dot and self.lines.bottom or self.lines.top, is_dot and "dot" or "direct"
    elseif mode == "direct_only" and not is_dot then target_line, style_type = self.lines.top, "direct"
    elseif mode == "dot_only" and is_dot then target_line, style_type = self.lines.top, "dot"
    end

    if target_line then
        local window = is_dot and 0.2 or 0.056
        target_line.total = target_line.total + damage
        if t - target_line.last_time < window then target_line.last = target_line.last + last_damage else target_line.last = last_damage end
        target_line.last_time = t
        target_line.timer = 0
        target_line.active = true
        target_line.style_type = style_type
        target_line.dirty = true
        self._widgets_by_name[target_line.widget_name].alpha_multiplier = 1
    end
end

HudElementDamageTrackerStatic.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudElementDamageTrackerStatic.super.update(self, dt, t, ui_renderer, render_settings, input_service)
    local s = self._cached_ui_settings

    local function format_text(total, single, mode)
        local tot, sin = mod.format_damage_number(total), mod.format_damage_number(single)
        if mode == "total_only" then return tot elseif mode == "single_only" then return sin else return string.format("%s[+%s]", tot, sin) end
    end

    for idx, line in pairs({top=self.lines.top, bottom=self.lines.bottom}) do
        local w = self._widgets_by_name[line.widget_name]
        if line.active then
            line.timer = line.timer + dt
            local p = line.timer / self.display_duration
            if line.dirty then
                w.content.text = format_text(line.total, line.last, s.display_format)
                local cfg = s.styles[line.style_type]
                w.style.text.text_color, w.style.text.font_size = cfg.color, s.main_text_size
                w.style.icon.color, w.content.icon = table.clone(cfg.color), cfg.icon_cfg.texture
                w.style.icon.size = { s.main_text_size * cfg.icon_cfg.size_multiplier, s.main_text_size * cfg.icon_cfg.size_multiplier }
                line.text_width = UIRenderer.text_size(ui_renderer, w.content.text, w.style.text.font_type, w.style.text.font_size)
                line.current_cfg = cfg
                w.style.icon.color[1] = cfg.icon_key ~= "none" and 255 or 0
                line.dirty = false
            end
            local base_y = idx == "bottom" and s.main_y + (s.main_text_size * 1.2) or s.main_y
            local anim_offset = (line.style_type == "dot" and 1 or -1) * (math.pow(p, 2) * 50)
            w.style.text.offset[1], w.style.text.offset[2] = s.main_x, base_y + anim_offset
            if line.current_cfg.icon_key ~= "none" then
                w.style.icon.offset[1] = s.main_x + (line.text_width / 2) + (w.style.icon.size[1] / (2 * line.current_cfg.icon_cfg.size_multiplier)) + line.current_cfg.icon_cfg.padding
                w.style.icon.offset[2] = w.style.text.offset[2]
            end
            w.alpha_multiplier = p > 0.6 and math.max(0, 1 - ((p - 0.6) * 2.5)) or 1
            if line.timer >= self.display_duration then line.active, line.total, w.content.text, w.style.icon.color[1] = false, 0, "", 0 end
        else
            w.style.icon.color[1] = 0
        end
    end
end

return HudElementDamageTrackerStatic