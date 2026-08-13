-- File: weapon_action_details/scripts/mods/weapon_action_details/hooks/wad_weapon_patterns_hooks.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

local Items = mod:original_require("scripts/utilities/items")
local WeaponTemplate = mod:original_require("scripts/utilities/weapon/weapon_template")
local generate_item_stats_blueprints = mod:original_require("scripts/ui/view_content_blueprints/item_stats_blueprints")
local ViewElementWeaponPatterns = mod:original_require(
    "scripts/ui/view_elements/view_element_weapon_patterns/view_element_weapon_patterns")
local ViewElementWeaponInfo = mod:original_require(
    "scripts/ui/view_elements/view_element_weapon_info/view_element_weapon_info")

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function wad_item_is_ranged(item, weapon_template)
    if item and Items.is_weapon_template_ranged and Items.is_weapon_template_ranged(item) then
        return true
    end

    local keywords = weapon_template and weapon_template.keywords
    return type(keywords) == "table" and table.contains(keywords, "force_staff") or false
end

local function wad_tab_header_height(element)
    local widget = element and element._wad_tab_background_widget
    local size = widget and widget.content and widget.content.size
    local height = size and size[2]

    return type(height) == "number" and height or 0
end

local function weapon_info_scrollbar_widget(element)
    local grid = element and element._grid
    if grid and grid._scrollbar_widget then
        return grid._scrollbar_widget
    end

    if element and type(element.grid_scrollbar) == "function" then
        local scrollbar_widget = element:grid_scrollbar()
        if scrollbar_widget then
            return scrollbar_widget
        end
    end

    local widgets_by_name = element and element._widgets_by_name
    return widgets_by_name and widgets_by_name.grid_scrollbar or nil
end

-- ============================================================================
-- CLASS INJECTIONS
-- ============================================================================

function ViewElementWeaponPatterns:wad_present_selected_tab(optional_on_present_callback)
    local item = self._wad_item
    if not item then return end

    local layout = {}

    -- Inject dynamic spacing for the tab headers
    mod.add_tab_spacing_to_layout(layout, self)

    -- Failsafe: Validate selected tab against available actions
    if self._wad_selected_tab == mod.TAB_SPECIAL_ACTIONS and not self._wad_has_special_actions then
        self._wad_selected_tab = mod.TAB_ACTIONS
    elseif self._wad_selected_tab == mod.TAB_TRAINING and not self._wad_has_training then
        self._wad_selected_tab = mod.TAB_ATTACK_PATTERNS
    end

    mod.ensure_tab_widgets(self)

    local menu_settings = self._menu_settings
    if menu_settings then
        menu_settings.top_padding = wad_tab_header_height(self)
    end

    local legend_text
    self._wad_range_affects_performance = false

    -- Populate layout based on active tab
    if mod.wad_selected_tab_is_actions_list(self._wad_selected_tab) and self._wad_has_actions then
        local action_filter = mod.action_filter_for_tab(self._wad_selected_tab)
        legend_text, self._wad_range_affects_performance = mod.add_actions_layout(layout, item, action_filter)
    elseif self._wad_selected_tab == mod.TAB_TRAINING and self._wad_has_actions and self._wad_has_training then
        mod.add_training_layout(layout, item)
    else
        self._wad_selected_tab = mod.TAB_ATTACK_PATTERNS
        mod.add_current_attack_patterns_layout(layout, self, item)
    end

    self._wad_tab_legend_text = legend_text

    self:wad_present_grid_layout(layout, item, optional_on_present_callback)
end

function ViewElementWeaponPatterns:wad_present_grid_layout(layout, item, optional_on_present_callback)
    local menu_settings = self._menu_settings
    if not menu_settings or not menu_settings.grid_size then return end

    local grid_display_name = self._grid_display_name
    local left_click_callback = callback(self, "cb_on_grid_entry_left_pressed")
    local right_click_callback = callback(self, "cb_on_grid_entry_right_pressed")
    local grid_size = menu_settings.grid_size
    local content_blueprints = generate_item_stats_blueprints(grid_size, item)
    local grow_direction = self._grow_direction or "down"

    -- Inject WAD custom blueprints into the pool before calling the original layout builder
    mod.add_weapon_action_details_blueprints(content_blueprints, grid_size)

    -- Call the superclass method to actually render the grid
    ViewElementWeaponPatterns.super.present_grid_layout(
        self,
        layout,
        content_blueprints,
        left_click_callback,
        right_click_callback,
        grid_display_name,
        grow_direction,
        optional_on_present_callback
    )
end

function ViewElementWeaponPatterns:wad_switch_tab(index)
    if mod.wad_selected_tab_is_actions_list(index) and not self._wad_has_actions then
        return
    end

    if index == mod.TAB_SPECIAL_ACTIONS and not self._wad_has_special_actions then
        return
    end

    if index == mod.TAB_TRAINING and (not self._wad_has_actions or not self._wad_has_training) then
        return
    end

    if self._wad_selected_tab == index then
        return
    end

    self._wad_selected_tab = index
    self:wad_present_selected_tab()
end

-- ============================================================================
-- HOOKS
-- ============================================================================

mod:hook(ViewElementWeaponPatterns, "present_item", function(func, self, item)
    -- Call the original function to ensure base UI/Data is populated properly
    local result = func(self, item)

    local weapon_template = WeaponTemplate.weapon_template_from_item(item)
    local actions = weapon_template and weapon_template.actions

    self._wad_item = item
    self._wad_is_ranged = wad_item_is_ranged(item, weapon_template)
    self._wad_has_actions = actions ~= nil
    self._wad_has_special_actions = self._wad_has_actions and mod.weapon_has_special_state_actions(actions) or false

    -- Training tab temporarily disabled as per original script
    self._wad_has_training = false

    self._wad_selected_tab = mod.TAB_ATTACK_PATTERNS
    self._wad_range_affects_performance = false

    self._current_attack_index = 1
    self._chain_index = 1

    mod.ensure_tab_widgets(self)
    mod.update_tab_widgets(self)

    -- Override the grid layout with our tab logic
    self:wad_present_selected_tab()

    return result
end)

mod:hook(ViewElementWeaponPatterns, "_update_grid_size", function(func, self)
    if not mod.wad_selected_tab_is_custom_list(self._wad_selected_tab) then
        return func(self)
    end

    self:force_update_list_size()

    local grid_length = self:grid_length() + 40
    local menu_settings = self._menu_settings
    if not menu_settings or not menu_settings.grid_size or not menu_settings.mask_size then
        return func(self)
    end

    local grid_size = menu_settings.grid_size
    local mask_size = menu_settings.mask_size
    local max_height = self._default_grid_size and self._default_grid_size[2] or mod.ACTIONS_TAB_MAX_HEIGHT
    local new_grid_height = math.clamp(grid_length, 0, max_height)

    grid_size[2] = new_grid_height
    mask_size[2] = new_grid_height

    self:_update_window_size()
end)

mod:hook(ViewElementWeaponInfo, "draw", function(func, self, dt, t, ui_renderer, render_settings, input_service)
    local scrollbar_widget = weapon_info_scrollbar_widget(self)
    local hide_scrollbar = scrollbar_widget and self._parent and self._parent._wad_action_tooltip_active == true

    local previous_alpha_multiplier, previous_disabled, previous_visible

    if hide_scrollbar then
        previous_alpha_multiplier = scrollbar_widget.alpha_multiplier
        scrollbar_widget.alpha_multiplier = 0

        if scrollbar_widget.content then
            previous_visible = scrollbar_widget.content.visible
            previous_disabled = scrollbar_widget.content.disabled

            scrollbar_widget.content.disabled = true
            scrollbar_widget.content.visible = false
        end
    end

    -- Perform actual UI draw
    local result = func(self, dt, t, ui_renderer, render_settings, input_service)

    -- Restore scrollbar state
    if hide_scrollbar then
        scrollbar_widget.alpha_multiplier = previous_alpha_multiplier

        if scrollbar_widget.content then
            scrollbar_widget.content.disabled = previous_disabled
            scrollbar_widget.content.visible = previous_visible
        end
    end

    return result
end)
