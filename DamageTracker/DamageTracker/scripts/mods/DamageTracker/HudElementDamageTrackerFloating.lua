local mod = get_mod("DamageTracker")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")

local sizeAnim = { 400, 100 }
local POOL_SIZE = 20

local ICON_CONFIG = {
    none = { texture = "", size_multiplier = 0, padding = 0 },
    weapons = { texture = "content/ui/materials/icons/item_types/weapons", size_multiplier = 1.0, padding = 4 },
    objective_main = { texture = "content/ui/materials/hud/interactions/icons/objective_main", size_multiplier = 2.0, padding = 6 },
    incapacitated = { texture = "content/ui/materials/icons/player_states/incapacitated", size_multiplier = 1.5, padding = 0 },
    mission_type_01 = { texture = "content/ui/materials/icons/mission_types/mission_type_01", size_multiplier = 0.9, padding = 3 },
    difficulty_skull_heresy = { texture = "content/ui/materials/icons/difficulty/flat/difficulty_skull_heresy", size_multiplier = 1.5, padding = 4 },
    difficulty_skull_uprising = { texture = "content/ui/materials/icons/difficulty/flat/difficulty_skull_uprising", size_multiplier = 1.5, padding = 4 },
    dead = { texture = "content/ui/materials/icons/player_states/dead", size_multiplier = 1.3, padding = 6 },
    pocketable_syringe_power = { texture = "content/ui/materials/hud/interactions/icons/pocketable_syringe_power", size_multiplier = 1.3, padding = 6 },
    scars = { texture = "content/ui/materials/icons/item_types/scars", size_multiplier = 1.3, padding = 4 },
    preset_19 = { texture = "content/ui/materials/icons/presets/preset_19", size_multiplier = 1.0, padding = 6 },
}

local FCT_ANIMATION_PROFILES = {
    normal = { dur = 1, pop_str = 0.2, pop_dur = 0.15, grav = 80, dx_range = { -30, 30 }, dy_range = { -60, -90 } },
    dot = { dur = 0.8, pop_str = 0.0, pop_dur = 0.10, grav = 20, dx_range = { -10, 10 }, dy_range = { 10, 40 } },
    pure_weakspot = { dur = 1.2, pop_str = 0.3, pop_dur = 0.17, grav = 120, dx_range = { 20, 60 }, dy_range = { -100, -130 } },
    pure_crit = { dur = 1.2, pop_str = 0.4, pop_dur = 0.15, grav = 120, dx_range = { -60, -20 }, dy_range = { -100, -130 } },
    weakspot_crit = { dur = 1.4, pop_str = 0.5, pop_dur = 0.20, grav = 80, dx_range = { -15, 15 }, dy_range = { -140, -180 } }
}

local HIT_TYPE_PRIORITY = {
    weakspot_crit = 5,
    pure_crit = 4,
    pure_weakspot = 3,
    normal = 2,
    dot = 1
}

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
}
local base_style = { line_spacing = 1.2, drop_shadow = true, font_type = "machine_medium", size = sizeAnim, text_horizontal_alignment =
"center", text_vertical_alignment = "center", offset = { 0, 0, 10 } }
local widget_definitions = {}

for i = 1, POOL_SIZE do
    local s_name = "fct_container_" .. i
    local w_name = "fct_widget_" .. i
    scenegraph_definition[s_name] = { parent = "screen", vertical_alignment = "center", horizontal_alignment = "center", size =
    sizeAnim, position = { 0, 0, 20 + i } }

    widget_definitions[w_name] = UIWidget.create_definition({
        { value = "", value_id = "text", style_id = "text", pass_type = "text",    style = table.clone(base_style) },
        { value = "", value_id = "icon", style_id = "icon", pass_type = "texture", style = { vertical_alignment = "center", horizontal_alignment = "center", color = { 0, 255, 255, 255 }, size = { 45, 45 }, offset = { 0, 0, 10 } } }
    }, s_name)
end

local HudElementDamageTrackerFloating = class("HudElementDamageTrackerFloating", "HudElementBase")

HudElementDamageTrackerFloating.init = function(self, parent, draw_layer, start_scale)
    HudElementDamageTrackerFloating.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition,
        widget_definitions = widget_definitions,
    })

    self.base_damage_reference = 2100

    self.fct_pool = {}
    for i = 1, POOL_SIZE do
        self.fct_pool[i] = {
            active = false,
            timer = 0,
            duration = 1.0,
            widget_name = "fct_widget_" .. i,
            x = 0,
            y = 0,
            dx = 0,
            dy = 0,
            gravity = 0,
            pop_strength = 0,
            pop_duration = 0.2,
            base_size = 40,
            damage = 0,
            hit_type = "normal",
            text_width = 0,
            dirty_width = false,
            style_data = nil,
            world_pos_box = nil,
            spread_x = 0,
            spread_y = 0,
            fade_penalty = 1.0,
            last_update_time = 0,
            is_dot = false
        }
    end

    Managers.event:register(self, "damage_tracker_on_floating_damage", "_on_floating_damage")
    Managers.event:register(self, "damage_tracker_settings_changed", "_apply_widget_settings")
    self:_apply_widget_settings()
end

HudElementDamageTrackerFloating.destroy = function(self)
    Managers.event:unregister(self, "damage_tracker_on_floating_damage")
    Managers.event:unregister(self, "damage_tracker_settings_changed")
    HudElementDamageTrackerFloating.super.destroy(self)
end

local function get_color(color_name, fallback)
    local c = Color[color_name] and Color[color_name](255, true) or Color[fallback](255, true)
    return table.clone(c)
end

local function preload_style(prefix, default_color, default_icon_key)
    local icon_key = mod:get(prefix .. "_icon") or default_icon_key
    local icon_cfg = ICON_CONFIG[icon_key] or ICON_CONFIG.none
    return { color = get_color(mod:get(prefix .. "_color"), default_color), icon_cfg = icon_cfg, icon_key = icon_key, size =
    mod:get(prefix .. "_size") or 40 }
end

HudElementDamageTrackerFloating._apply_widget_settings = function(self)
    self._cached_ui_settings = self._cached_ui_settings or {}
    local s = self._cached_ui_settings

    s.floating_mode = mod:get("floating_mode") or "all"
    s.floating_style = mod:get("floating_style") or "fixed"
    s.fct_x = mod:get("floating_x") or -15
    s.fct_y = mod:get("floating_y") or -240
    s.offset_head = mod:get("fct_offset_head") or -80
    s.offset_body = mod:get("fct_offset_body") or 0
    s.distance_scaling_enabled = mod:get("fct_distance_scaling")
    s.distance_reference = mod:get("fct_distance_reference") or 10
    s.los_check_enabled = mod:get("fct_los_check")

    s.fct_styles = {
        normal = preload_style("normal", "ui_hud_green_super_light", "none"),
        dot = preload_style("fct_dot", "medium_turquoise", "none"),
        pure_crit = preload_style("pure_crit", "ui_hud_red_light", "objective_main"),
        pure_weakspot = preload_style("pure_weakspot", "ui_orange_light", "scars"),
        weakspot_crit = preload_style("weakspot_crit", "citadel_wrack_white", "pocketable_syringe_power")
    }

    for i = 1, POOL_SIZE do
        self.fct_pool[i].active = false
        self._widgets_by_name[self.fct_pool[i].widget_name].style.icon.color[1] = 0
    end
end

HudElementDamageTrackerFloating._on_floating_damage = function(self, damage, hit_type, world_pos_box, attacked_unit)
    local s = self._cached_ui_settings
    if s.floating_mode == "disabled" then return end
    if s.floating_mode == "finesse_only" and (hit_type == "normal" or hit_type == "dot") then return end
    if s.floating_mode == "all_direct" and hit_type == "dot" then return end

    local t = Managers.time:time("ui")
    local is_dot = (hit_type == "dot")
    local window = is_dot and 0.2 or 0.055

    if s.floating_style == "follow" and world_pos_box then
        local player = Managers.player:local_player(1)
        local camera = nil
        if player and player.viewport_name then
            camera = Managers.state.camera:camera(player.viewport_name)
        end

        if camera then
            local world_pos = world_pos_box:unbox()

            if Camera.inside_frustum(camera, world_pos) <= 0 then
                return
            end

            if s.los_check_enabled then
                local world = Managers.world:world("level_world")
                local physics_world = World.get_data(world, "physics_world")

                if physics_world then
                    local camera_pos = Camera.world_position(camera)
                    local to_target = world_pos - camera_pos
                    local distance = Vector3.length(to_target)

                    if distance > 0 then
                        local direction = Vector3.normalize(to_target)
                        local hit = PhysicsWorld.raycast(
                            physics_world, camera_pos, direction, distance,
                            "closest", "collision_filter", "filter_minion_line_of_sight_check"
                        )

                        if hit then
                            if type(hit) == "boolean" then
                                return
                            elseif type(hit) == "table" then
                                local hit_actor = hit[4]
                                local hit_unit = hit_actor and Actor.unit(hit_actor)
                                if not attacked_unit or hit_unit ~= attacked_unit then
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local target_node = nil

    if s.floating_style == "fixed" then
        local latest_time = -1
        for i = 1, POOL_SIZE do
            local node = self.fct_pool[i]
            if node.active and node.is_dot == is_dot and (t - node.last_update_time) <= window then
                if node.last_update_time > latest_time then
                    latest_time = node.last_update_time
                    target_node = node
                end
            end
        end
    end

    if target_node then
        target_node.damage = target_node.damage + damage
        target_node.last_update_time = t

        if HIT_TYPE_PRIORITY[hit_type] > (HIT_TYPE_PRIORITY[target_node.hit_type] or 0) then
            target_node.hit_type = hit_type
        end

        local style = s.fct_styles[target_node.hit_type]
        target_node.style_data = style
        target_node.base_size = style.size *
        math.max(0.8, math.min(1.5, (target_node.damage / self.base_damage_reference) + 0.6))
        target_node.dirty_width = true

        local w = self._widgets_by_name[target_node.widget_name]
        w.content.text = mod.format_damage_number(target_node.damage)
        w.style.text.text_color = style.color
        w.style.icon.color = table.clone(style.color)
        w.content.icon = style.icon_cfg.texture
        return
    end

    local target_idx, oldest_idx, max_timer = 1, 1, -1
    for i = 1, POOL_SIZE do
        if not self.fct_pool[i].active then
            target_idx = i; break
        end
        if self.fct_pool[i].timer > max_timer then
            max_timer = self.fct_pool[i].timer; oldest_idx = i
        end
    end
    if self.fct_pool[target_idx].active then target_idx = oldest_idx end

    local node = self.fct_pool[target_idx]
    local prof = FCT_ANIMATION_PROFILES[hit_type]
    local style = s.fct_styles[hit_type]
    local damage_scale_factor = math.max(0.8, math.min(1.5, (damage / self.base_damage_reference) + 0.6))

    node.active = true
    node.timer = 0
    node.last_update_time = t
    node.is_dot = is_dot
    node.damage = damage
    node.hit_type = hit_type
    node.style_data = style
    node.world_pos_box = world_pos_box

    node.base_size = style.size * damage_scale_factor
    node.pop_strength = prof.pop_str
    node.pop_duration = prof.pop_dur
    node.duration = (s.floating_style == "follow") and 1.0 or (prof.dur + (damage_scale_factor * 0.2))

    node.dx = (s.floating_style == "follow") and 0 or math.random(prof.dx_range[1], prof.dx_range[2])
    node.dy = (s.floating_style == "follow") and 0 or math.random(prof.dy_range[1], prof.dy_range[2])
    node.gravity = (s.floating_style == "follow") and 0 or prof.grav
    node.x = (s.floating_style == "follow") and 0 or (s.fct_x + math.random(-15, 15))
    node.y = (s.floating_style == "follow") and 0 or (s.fct_y + math.random(-15, 15))
    node.spread_x = (s.floating_style == "follow") and math.random(-15, 15) or 0
    node.spread_y = (s.floating_style == "follow") and math.random(-5, 15) or 0

    local w = self._widgets_by_name[node.widget_name]
    w.content.text = mod.format_damage_number(damage)
    w.style.text.text_color = style.color
    w.style.icon.color = table.clone(style.color)
    w.content.icon = style.icon_cfg.texture
    w.alpha_multiplier = 1
    node.dirty_width = true

    if s.floating_style == "follow" then
        node.fade_penalty = 1.0
        for i = 1, POOL_SIZE do
            local other = self.fct_pool[i]
            if other ~= node and other.active and other.world_pos_box then
                other.fade_penalty = math.max(0.15, other.fade_penalty * 0.6)
            end
        end
    end
end

HudElementDamageTrackerFloating.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    HudElementDamageTrackerFloating.super.update(self, dt, t, ui_renderer, render_settings, input_service)

    local s = self._cached_ui_settings
    local is_follow = (s.floating_style == "follow")

    local camera = nil
    local inverse_scale = RESOLUTION_LOOKUP.inverse_scale
    local logical_w = RESOLUTION_LOOKUP.width * inverse_scale
    local logical_h = RESOLUTION_LOOKUP.height * inverse_scale

    if is_follow then
        local player = Managers.player:local_player(1)
        if player and player.viewport_name then
            camera = Managers.state.camera:camera(player.viewport_name)
        end
    end

    for i = 1, POOL_SIZE do
        local node = self.fct_pool[i]
        local w = self._widgets_by_name[node.widget_name]

        if node.active then
            node.timer = node.timer + dt
            local p = node.timer / node.duration
            local current_size = node.base_size

            if node.timer < node.pop_duration and node.pop_strength > 0 then
                local pop_p = node.timer / node.pop_duration
                current_size = current_size * (1.0 + (math.sin(pop_p * math.pi) * node.pop_strength))
            end

            node.fade_penalty = math.min(1.0, node.fade_penalty + dt * 1.5)

            local alpha = 1.0
            if p > 0.6 then alpha = math.max(0, 1 - ((p - 0.6) * 2.5)) end
            alpha = alpha * node.fade_penalty

            local render_x, render_y = 0, 0
            local should_render = true

            if is_follow and camera and node.world_pos_box then
                local world_pos = node.world_pos_box:unbox()

                if Camera.inside_frustum(camera, world_pos) <= 0 then
                    node.active = false
                    w.content.text = ""
                    w.style.icon.color[1] = 0
                    node.world_pos_box = nil
                    should_render = false
                else
                    local screen_pos = Camera.world_to_screen(camera, world_pos)

                    local is_headshot = (node.hit_type == "pure_weakspot" or node.hit_type == "weakspot_crit")
                    local vertical_offset = is_headshot and s.offset_head or s.offset_body

                    render_x = (screen_pos.x * inverse_scale) - (logical_w / 2) + node.spread_x
                    render_y = (screen_pos.y * inverse_scale) - (logical_h / 2) + vertical_offset + node.spread_y

                    local margin = 80
                    if render_x < -(logical_w + margin) or render_x > (logical_w + margin)
                        or render_y < -(logical_h + margin) or render_y > (logical_h + margin) then
                        node.active = false
                        w.content.text = ""
                        w.style.icon.color[1] = 0
                        node.world_pos_box = nil
                        should_render = false
                    end

                    if should_render and s.distance_scaling_enabled then
                        local camera_pos = Camera.world_position(camera)
                        local real_distance = Vector3.length(world_pos - camera_pos)
                        local dist_scale = (s.distance_reference or 10) / real_distance
                        dist_scale = math.max(0.7, math.min(1.0, dist_scale))
                        current_size = current_size * dist_scale
                    end
                end
            else
                node.dy = node.dy + (node.gravity * dt)
                node.x = node.x + (node.dx * dt)
                node.y = node.y + (node.dy * dt)
                render_x, render_y = node.x, node.y
            end

            if should_render then
                w.style.text.offset[1] = render_x
                w.style.text.offset[2] = render_y
                w.style.text.font_size = current_size
                w.alpha_multiplier = alpha

                local cfg = node.style_data.icon_cfg
                if node.style_data.icon_key ~= "none" then
                    w.style.icon.color[1] = 255
                    local icon_size = current_size * cfg.size_multiplier
                    w.style.icon.size[1], w.style.icon.size[2] = icon_size, icon_size

                    if node.dirty_width then
                        node.text_width = UIRenderer.text_size(ui_renderer, w.content.text, w.style.text.font_type,
                            node.base_size)
                        node.dirty_width = false
                    end

                    local current_text_width = node.text_width * (current_size / node.base_size)
                    w.style.icon.offset[1] = render_x + (current_text_width / 2) +
                    (icon_size / (2 * cfg.size_multiplier)) + cfg.padding
                    w.style.icon.offset[2] = render_y
                else
                    w.style.icon.color[1] = 0
                end
            else
                w.alpha_multiplier = 0
            end

            if node.timer >= node.duration then
                node.active = false
                w.content.text = ""
                w.style.icon.color[1] = 0
                node.world_pos_box = nil
            end
        else
            w.style.icon.color[1] = 0
        end
    end
end

return HudElementDamageTrackerFloating
