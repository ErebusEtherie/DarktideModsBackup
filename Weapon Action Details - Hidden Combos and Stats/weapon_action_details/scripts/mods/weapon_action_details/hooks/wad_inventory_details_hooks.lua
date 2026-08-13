-- File: weapon_action_details/scripts/mods/weapon_action_details/hooks/wad_inventory_details_hooks.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local InventoryWeaponDetailsView = mod:original_require(
    "scripts/ui/views/inventory_weapon_details_view/inventory_weapon_details_view")
local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local UIResolution = mod:original_require("scripts/managers/ui/ui_resolution")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local WeaponTemplate = mod:original_require("scripts/utilities/weapon/weapon_template")

-- Shared constants for UI toggles
mod.DAMAGE_HIT_ZONE_TOGGLE_DISPLAY_NAMES = {
    [mod.WAD_DAMAGE_HIT_ZONE_BODY] = "wad_dynamic_hit_zone_body",
    [mod.WAD_DAMAGE_HIT_ZONE_WEAKSPOT] = "wad_dynamic_hit_zone_weakspot",
    [mod.WAD_DAMAGE_HIT_ZONE_CRITICAL] = "wad_dynamic_hit_zone_critical",
    [mod.WAD_DAMAGE_HIT_ZONE_CRITICAL_WEAKSPOT] = "wad_dynamic_hit_zone_critical_weakspot",
}

mod.RANGE_MODE_TOGGLE_DISPLAY_NAMES = {
    [mod.WAD_RANGE_MODE_OPTIMAL] = "wad_dynamic_range_optimal",
    [mod.WAD_RANGE_MODE_FAR] = "wad_dynamic_range_far",
    [mod.WAD_RANGE_MODE_NEAR] = "wad_dynamic_range_near",
}

mod.CHARGE_LEVEL_TOGGLE_DISPLAY_NAMES = {
    [mod.WAD_CHARGE_LEVEL_100] = "wad_dynamic_charge_100",
    [mod.WAD_CHARGE_LEVEL_30] = "wad_dynamic_charge_30",
    [mod.WAD_CHARGE_LEVEL_1] = "wad_dynamic_charge_1",
}

function mod.wad_selected_tab_is_actions_list(tab_index)
    return tab_index == mod.TAB_ACTIONS or tab_index == mod.TAB_SPECIAL_ACTIONS
end

function mod.wad_selected_tab_is_custom_list(tab_index)
    return mod.wad_selected_tab_is_actions_list(tab_index) or tab_index == mod.TAB_TRAINING
end

function mod.active_wad_action_element(view)
    if not view then return nil end
    local element = view._attack_patterns

    if element and element._active and mod.wad_selected_tab_is_custom_list(element._wad_selected_tab) and element._wad_has_actions and element._wad_item then
        return element
    end

    return nil
end

local function cursor_is_over_grid_element(element, input_service)
    if not element or not element._active or element._input_disabled or not input_service then
        return false
    end

    local cursor = input_service:get("cursor")
    if not cursor then
        return false
    end

    local ui_scenegraph = element._ui_scenegraph
    local grid_background = ui_scenegraph and ui_scenegraph.grid_background
    if not grid_background then
        return false
    end

    local inverse_scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale
    local cursor_position = inverse_scale and UIResolution.inverse_scale_vector(cursor, inverse_scale) or cursor
    local position = grid_background.world_position
    local size = grid_background.size

    if not position or not size then
        return false
    end

    return math.point_is_inside_2d_box(cursor_position, position, size)
end

local function cursor_is_over_weapon_details_scroll_panel(view, input_service)
    return cursor_is_over_grid_element(view._attack_patterns, input_service) or
        cursor_is_over_grid_element(view._weapon_actions_extended, input_service)
end

local function damage_hit_zone_toggle_display_name()
    return mod.DAMAGE_HIT_ZONE_TOGGLE_DISPLAY_NAMES[mod.wad_damage_hit_zone] or
        mod.DAMAGE_HIT_ZONE_TOGGLE_DISPLAY_NAMES[mod.WAD_DAMAGE_HIT_ZONE_BODY]
end

local function damage_hit_zone_toggle_visible(parent, id)
    local element = mod.active_wad_action_element(parent)
    if not element then
        return false
    end

    local input_legend = parent._input_legend_element
    if input_legend then
        input_legend:set_display_name(id, damage_hit_zone_toggle_display_name())
    end

    return true
end

local function range_mode_toggle_display_name()
    return mod.RANGE_MODE_TOGGLE_DISPLAY_NAMES[mod.wad_range_mode] or
        mod.RANGE_MODE_TOGGLE_DISPLAY_NAMES[mod.WAD_RANGE_MODE_OPTIMAL]
end

local function range_mode_toggle_visible(parent, id)
    local element = mod.active_wad_action_element(parent)

    if not element or not mod.wad_selected_tab_is_actions_list(element._wad_selected_tab) or
        element._wad_is_ranged ~= true or element._wad_range_affects_performance ~= true then
        return false
    end

    local input_legend = parent._input_legend_element
    if input_legend then
        input_legend:set_display_name(id, range_mode_toggle_display_name())
    end

    return true
end

local function charge_level_toggle_display_name()
    return mod.CHARGE_LEVEL_TOGGLE_DISPLAY_NAMES[mod.wad_charge_level] or
        mod.CHARGE_LEVEL_TOGGLE_DISPLAY_NAMES[mod.WAD_CHARGE_LEVEL_100]
end

local function charge_level_toggle_visible(parent, id)
    local element = mod.active_wad_action_element(parent)

    if not element or not mod.wad_selected_tab_is_actions_list(element._wad_selected_tab) then
        return false
    end

    local weapon_template = WeaponTemplate.weapon_template_from_item(element._wad_item)
    local actions = weapon_template and weapon_template.actions
    local context = actions and mod.ACTIONS_WEAPON_CONTEXTS and mod.ACTIONS_WEAPON_CONTEXTS[actions]

    if not context or not context.has_charge_actions then
        return false
    end

    local input_legend = parent._input_legend_element
    if input_legend then
        input_legend:set_display_name(id, charge_level_toggle_display_name())
    end

    return true
end

local function restore_wad_actions_scroll_position(element, scrolled_length, scrollbar_progress)
    if not element then return end
    local scroll_length = element:scroll_length()
    local restored_progress = scrollbar_progress or 0

    if scrolled_length and scroll_length and scroll_length > 0 then
        restored_progress = math.clamp(scrolled_length / scroll_length, 0, 1)
    end

    element:set_scrollbar_progress(restored_progress, true)
end

local function update_wad_action_tooltip_active(parent, input_service)
    local attack_patterns = parent and parent._attack_patterns
    local action_tab_selected = attack_patterns and
        mod.wad_selected_tab_is_actions_list(attack_patterns._wad_selected_tab)

    if not attack_patterns or not attack_patterns._active or not attack_patterns._wad_item or not action_tab_selected then
        local tooltip_widget = attack_patterns and attack_patterns._wad_action_tooltip_widget

        if tooltip_widget and tooltip_widget.content then
            tooltip_widget.content.visible = false
        end

        if parent then
            parent._wad_action_tooltip_active = false
        end

        return false, attack_patterns
    end

    -- Trigger widget generation/updating locally
    mod.update_action_tooltip_widget(attack_patterns, input_service)

    local tooltip_widget = attack_patterns._wad_action_tooltip_widget
    local active = tooltip_widget and tooltip_widget.content and tooltip_widget.content.visible == true or false

    if parent then
        parent._wad_action_tooltip_active = active
    end

    return active, attack_patterns
end

local function draw_wad_tab_header(parent, element, dt, input_service, layer)
    if not element or not element._active or not element._wad_item or not element._ui_scenegraph then
        return
    end

    mod.update_tab_widgets(element)

    local tab_background_widget = element._wad_tab_background_widget
    local tab_widgets = element._wad_tab_widgets

    if not tab_background_widget and not tab_widgets then
        return
    end

    local render_settings = parent and parent._render_settings
    local ui_renderer = element._ui_grid_renderer

    if not ui_renderer and parent then
        ui_renderer = parent._ui_default_renderer or parent._ui_renderer
    end

    if not render_settings or not ui_renderer then
        return
    end

    local previous_layer = render_settings.start_layer
    local previous_alpha_multiplier = render_settings.alpha_multiplier

    render_settings.start_layer = (layer or previous_layer or 0) + 1
    render_settings.alpha_multiplier = 1

    UIRenderer.begin_pass(
        ui_renderer,
        element._ui_scenegraph,
        input_service,
        dt,
        render_settings
    )

    if tab_background_widget and tab_background_widget.content and tab_background_widget.content.visible then
        UIWidget.draw(tab_background_widget, ui_renderer)
    end

    if tab_widgets then
        for i = 1, #tab_widgets do
            local widget = tab_widgets[i]
            if widget and widget.content and widget.content.visible then
                UIWidget.draw(widget, ui_renderer)
            end
        end
    end

    UIRenderer.end_pass(ui_renderer)

    render_settings.alpha_multiplier = previous_alpha_multiplier
    render_settings.start_layer = previous_layer
end

-- ============================================================================
-- CLASS INJECTIONS
-- ============================================================================

function InventoryWeaponDetailsView:wad_cb_on_damage_hit_zone_toggle_pressed()
    local element = mod.active_wad_action_element(self)
    if not element then return end

    local scrolled_length = element:length_scrolled()
    local scrollbar_progress = element:scrollbar_progress()

    mod.wad_damage_hit_zone = mod.WAD_DAMAGE_HIT_ZONE_NEXT[mod.wad_damage_hit_zone] or mod.WAD_DAMAGE_HIT_ZONE_BODY

    element:wad_present_selected_tab(function()
        restore_wad_actions_scroll_position(element, scrolled_length, scrollbar_progress)
    end)
end

function InventoryWeaponDetailsView:wad_cb_on_range_mode_toggle_pressed()
    local element = mod.active_wad_action_element(self)

    if not element or not mod.wad_selected_tab_is_actions_list(element._wad_selected_tab) or
        element._wad_is_ranged ~= true or element._wad_range_affects_performance ~= true then
        return
    end

    local scrolled_length = element:length_scrolled()
    local scrollbar_progress = element:scrollbar_progress()

    mod.wad_range_mode = mod.WAD_RANGE_MODE_NEXT[mod.wad_range_mode] or mod.WAD_RANGE_MODE_OPTIMAL

    element:wad_present_selected_tab(function()
        restore_wad_actions_scroll_position(element, scrolled_length, scrollbar_progress)
    end)
end

function InventoryWeaponDetailsView:wad_cb_on_charge_level_toggle_pressed()
    local element = mod.active_wad_action_element(self)

    if not element or not mod.wad_selected_tab_is_actions_list(element._wad_selected_tab) then
        return
    end

    local weapon_template = WeaponTemplate.weapon_template_from_item(element._wad_item)
    local actions = weapon_template and weapon_template.actions
    local context = actions and mod.ACTIONS_WEAPON_CONTEXTS and mod.ACTIONS_WEAPON_CONTEXTS[actions]

    if not context or not context.has_charge_actions then
        return
    end

    local scrolled_length = element:length_scrolled()
    local scrollbar_progress = element:scrollbar_progress()

    mod.wad_charge_level = mod.WAD_CHARGE_LEVEL_NEXT[mod.wad_charge_level] or mod.WAD_CHARGE_LEVEL_100

    element:wad_present_selected_tab(function()
        restore_wad_actions_scroll_position(element, scrolled_length, scrollbar_progress)
    end)
end

-- ============================================================================
-- HOOKS
-- ============================================================================

mod:hook_safe(InventoryWeaponDetailsView, "on_enter", function(self)
    mod.wad_damage_hit_zone = mod.WAD_DAMAGE_HIT_ZONE_WEAKSPOT
    mod.wad_range_mode = mod.WAD_RANGE_MODE_OPTIMAL
    mod.wad_charge_level = mod.WAD_CHARGE_LEVEL_100
end)

mod:hook_safe(InventoryWeaponDetailsView, "_setup_input_legend", function(self)
    local input_legend = self._input_legend_element
    if not input_legend then return end

    input_legend:add_entry(
        damage_hit_zone_toggle_display_name(),
        "hotkey_toggle_item_tooltip",
        damage_hit_zone_toggle_visible,
        callback(self, "wad_cb_on_damage_hit_zone_toggle_pressed"),
        "right_alignment"
    )
    input_legend:add_entry(
        range_mode_toggle_display_name(),
        "hotkey_item_inspect",
        range_mode_toggle_visible,
        callback(self, "wad_cb_on_range_mode_toggle_pressed"),
        "right_alignment"
    )
    input_legend:add_entry(
        charge_level_toggle_display_name(),
        "hotkey_item_compare",
        charge_level_toggle_visible,
        callback(self, "wad_cb_on_charge_level_toggle_pressed"),
        "right_alignment"
    )
end)

mod:hook(InventoryWeaponDetailsView, "_handle_input", function(func, self, input_service, dt, t)
    local scroll_axis = input_service and input_service:get("scroll_axis")
    local scroll = scroll_axis and scroll_axis[2] or 0

    if scroll ~= 0 and cursor_is_over_weapon_details_scroll_panel(self, input_service) then
        return
    end

    return func(self, input_service, dt, t)
end)

mod:hook(InventoryWeaponDetailsView, "draw", function(func, self, dt, t, input_service, layer)
    -- Update tooltip state prior to original draw to establish visibility flags
    update_wad_action_tooltip_active(self, input_service)

    local result = func(self, dt, t, input_service, layer)

    -- Re-evaluate tooltip state after original draw to ensure accuracy for overlay pass
    local tooltip_active, attack_patterns = update_wad_action_tooltip_active(self, input_service)

    draw_wad_tab_header(self, attack_patterns, dt, input_service, layer)

    if not tooltip_active then
        return result
    end

    local tooltip_widget = attack_patterns and attack_patterns._wad_action_tooltip_widget
    if not tooltip_widget or not tooltip_widget.content or not tooltip_widget.content.visible then
        return result
    end

    local weapon_info = self._weapon_info
    local render_settings = self._render_settings
    local ui_renderer = weapon_info and weapon_info._ui_grid_renderer or self._ui_default_renderer or self._ui_renderer

    if not render_settings or not ui_renderer or not attack_patterns._ui_scenegraph then
        return result
    end

    local previous_layer = render_settings.start_layer
    local previous_alpha_multiplier = render_settings.alpha_multiplier
    local previous_tooltip_z = tooltip_widget.offset and tooltip_widget.offset[3] or 0

    render_settings.start_layer = (layer or previous_layer or 0) + 200000
    render_settings.alpha_multiplier = 1
    if tooltip_widget.offset then
        tooltip_widget.offset[3] = 200000
    end

    UIRenderer.begin_pass(
        ui_renderer,
        attack_patterns._ui_scenegraph,
        input_service,
        dt,
        render_settings
    )
    mod.draw_action_tooltip_widget(attack_patterns, ui_renderer)
    UIRenderer.end_pass(ui_renderer)

    if tooltip_widget.offset then
        tooltip_widget.offset[3] = previous_tooltip_z
    end
    render_settings.alpha_multiplier = previous_alpha_multiplier
    render_settings.start_layer = previous_layer

    return result
end)
