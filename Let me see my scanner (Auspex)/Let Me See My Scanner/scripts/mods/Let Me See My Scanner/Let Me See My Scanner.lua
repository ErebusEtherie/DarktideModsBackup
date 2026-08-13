local mod = get_mod("Let Me See My Scanner")

local _ALWAYS_HIDE_ELEMENTS = {
    HudElementCrosshair = true,
    HudElementCrosshairHud = true,
    HudElementDodgeCounter = true,
    HudElementDodgeCount = true,
    HudElementStamina = true,
}

local _EXCLUDED_ELEMENTS = {
    ConstantElementChat = true,
}

local function _track_ability_icon(icon)
    if not icon then return end
    mod._ability_icons[icon] = true
end

local function _untrack_ability_icon(icon)
    if not icon then return end
    mod._ability_icons[icon] = nil
end

mod:hook_require("scripts/ui/hud/elements/player_ability/hud_element_player_ability", function(HudElementPlayerAbility)
    mod:hook_safe(HudElementPlayerAbility, "init", function(self, ...)
        _track_ability_icon(self)
    end)

    mod:hook_safe(HudElementPlayerAbility, "destroy", function(self, ...)
        _untrack_ability_icon(self)
    end)
end)

mod:hook_require("scripts/ui/hud/elements/player_ability/hud_element_player_slot_item_ability", function(HudElementPlayerSlotItemAbility)
    mod:hook_safe(HudElementPlayerSlotItemAbility, "init", function(self, ...)
        _track_ability_icon(self)
    end)

    mod:hook_safe(HudElementPlayerSlotItemAbility, "destroy", function(self, ...)
        _untrack_ability_icon(self)
    end)
end)

local function is_buff_bar(class_name)
    if type(class_name) ~= "string" then return false end
    return string.find(class_name, "^HudElementBuffBar") ~= nil or class_name == "HudElementPlayerBuffs"
end

local function is_ability_icon(class_name)
    return type(class_name) == "string" and (
        string.find(class_name, "^HudElementPlayerAbility") ~= nil or
        string.find(class_name, "^HudElementPlayerSlotItemAbility") ~= nil
    )
end

local function should_hide_element(class_name)
    if _EXCLUDED_ELEMENTS[class_name] then
        return false
    end

    -- Check individual element toggles
    if _ALWAYS_HIDE_ELEMENTS[class_name] then
        local setting_id = "hide_" .. string.lower(class_name)
        local should = mod:get(setting_id)
        -- If setting exists, use it; otherwise default to true (backwards compatibility)
        if should == nil then
            return true
        end
        return should == true
    end

    if is_ability_icon(class_name) then
        local should = mod:get("hide_ability_icons")
        if should == nil then
            return true
        end
        return should == true
    end

    if is_buff_bar(class_name) then
        local should = mod:get("hide_buff_bars")
        if should == nil then
            return true
        end
        return should == true
    end

    -- Element not in any category, don't hide it
    return false
end

mod._scan_active = false
mod._current_alpha = 1
mod._fade_target = nil
mod._fade_speed = 0
mod._ability_icons = {}

if not math.clamp then
    function math.clamp(x, a, b)
        return (x < a and a) or (x > b and b) or x
    end
end

local function _apply_alpha_to_widget(widget, alpha)
    if not widget then return end
    
    -- Get the faded alpha threshold
    local faded_alpha = math.clamp(mod:get("transparency_amount") or 0, 0, 1)
    -- Only completely hide if transparency_amount is 0 (or very close to 0)
    -- If transparency_amount > 0, keep text visible but faded
    local should_hide_completely = faded_alpha <= 0.001 and alpha <= 0.001
    
    -- Completely hide widget only if transparency is set to 0
    if widget.content then
        if should_hide_completely then
            widget.content.visible = false
        else
            -- Restore visibility when alpha goes back up or if transparency > 0
            widget.content.visible = true
        end
    end
    
    widget.alpha_multiplier = alpha
    if widget.style then
        for _, style in pairs(widget.style) do
            if type(style) == "table" and style.color then
                if not style.__orig_a then
                    style.__orig_a = style.color[1]
                end
                -- Set alpha to 0 only if completely hiding, otherwise use the calculated alpha
                style.color[1] = should_hide_completely and 0 or math.floor(style.__orig_a * alpha)
            end
        end
    end
    widget.dirty = true
end

local function _apply_alpha_to_element(element, alpha)
    if not element then return end

    if element.__class_name and _EXCLUDED_ELEMENTS[element.__class_name] then
        return
    end

    if element._widgets then
        for _, w in pairs(element._widgets) do
            _apply_alpha_to_widget(w, alpha)
        end
        if element.set_dirty then element:set_dirty() end
    end

    if element._widgets_by_name then
        for _, w in pairs(element._widgets_by_name) do
            _apply_alpha_to_widget(w, alpha)
        end
    end

    if element._stamina_nodge_widget then
        _apply_alpha_to_widget(element._stamina_nodge_widget, alpha)
    end

    if element.__class_name == "HudElementStamina" and element._widgets_by_name then
        local stamina_widgets = {
            gauge = true,
            stamina_bar = true,
            stamina_depleted_bar = true,
        }
        for widget_name, w in pairs(element._widgets_by_name) do
            if stamina_widgets[widget_name] then
                _apply_alpha_to_widget(w, alpha)
            end
        end
    end

    if element._instance_data_tables then
        for _, data in pairs(element._instance_data_tables) do
            if data.instance then
                _apply_alpha_to_element(data.instance, alpha)
            end
        end
    end

    if element._player_weapons then
        for _, weapon_data in pairs(element._player_weapons) do
            if weapon_data.hud_element_player_weapon then
                _apply_alpha_to_element(weapon_data.hud_element_player_weapon, alpha)
            end
        end
    end

    if element._player_weapons_array then
        for _, weapon_data in ipairs(element._player_weapons_array) do
            if weapon_data.hud_element_player_weapon then
                _apply_alpha_to_element(weapon_data.hud_element_player_weapon, alpha)
            end
        end
    end

    if element._player_panel_by_unique_id then
        for _, panel_data in pairs(element._player_panel_by_unique_id) do
            if panel_data.panel then
                _apply_alpha_to_element(panel_data.panel, alpha)
            end
        end
    end

    if element._player_panels_array then
        for _, panel_data in ipairs(element._player_panels_array) do
            if panel_data.panel then
                _apply_alpha_to_element(panel_data.panel, alpha)
            end
        end
    end
end

local function _set_crosshair_visible(show)
    local ui_manager = rawget(_G, "Managers") and Managers.ui
    if not ui_manager then return end

    local hud = ui_manager:get_hud()
    if not hud then return end

    local smooth_fade = mod:get("smooth_fade")
    local faded_alpha = math.clamp(mod:get("transparency_amount") or 0, 0, 1)
    local currently_visible = hud._currently_visible_elements
    local processed = {}

    local function affect_element(class_name)
        if processed[class_name] then return end
        processed[class_name] = true

        -- Check if this specific element should be hidden
        local should = should_hide_element(class_name)
        if not should then 
            -- If we shouldn't hide it, make sure it's fully visible
            local element = hud:element(class_name)
            if element then
                _apply_alpha_to_element(element, 1)
            end
            return 
        end

        local element = hud:element(class_name)
        if currently_visible then currently_visible[class_name] = true end
        if element then
            local target_alpha = show and 1 or faded_alpha
            if smooth_fade then
                if math.abs(mod._current_alpha - target_alpha) > 0.001 then
                    mod._fade_target = target_alpha
                    local diff = math.abs(mod._current_alpha - target_alpha)
                    local duration = math.clamp(mod:get("fade_duration") or 0.3, 0.05, 10)
                    mod._fade_speed = diff / duration
                end
            else
                mod._current_alpha = target_alpha
                _apply_alpha_to_element(element, target_alpha)
            end
        end
    end

    for class_name, _ in pairs(_ALWAYS_HIDE_ELEMENTS) do
        affect_element(class_name)
    end

    for class_name, _ in pairs(hud._elements or {}) do
        if is_buff_bar(class_name) or is_ability_icon(class_name) then
            affect_element(class_name)
        end
    end

    local ce = Managers.ui and Managers.ui:ui_constant_elements()
    if ce then
        for class_name, _ in pairs(ce._elements or {}) do
            if is_buff_bar(class_name) or is_ability_icon(class_name) then
                affect_element(class_name)
            end
        end
    end

    local function process_icon(icon)
        if not icon then return end

        local should = should_hide_element(icon.__class_name)
        if not should then return end

        local target_alpha = show and 1 or faded_alpha
        if smooth_fade then
            if math.abs(mod._current_alpha - target_alpha) > 0.001 then
                mod._fade_target = target_alpha
                local diff = math.abs(mod._current_alpha - target_alpha)
                local duration = math.clamp(mod:get("fade_duration") or 0.3, 0.05, 10)
                mod._fade_speed = diff / duration
            end
        else
            _apply_alpha_to_element(icon, target_alpha)
        end
    end

    for icon, _ in pairs(mod._ability_icons) do
        process_icon(icon)
    end
end

mod:hook_safe(CLASS.AuspexScanningEffects, "_run_searching_sfx_loop", function(self)
    -- Only hide HUD if this is the local player's auspex (not a husk)
    if self._is_husk then return end
    
    mod._scan_active = true
    _set_crosshair_visible(false)
end)

mod:hook_safe(CLASS.AuspexScanningEffects, "_stop_scan_units_effects", function(self)
    -- Only restore HUD if this is the local player's auspex (not a husk)
    if self._is_husk then return end
    
    mod._scan_active = false
    _set_crosshair_visible(true)
end)

mod:hook_safe(CLASS.AuspexEffects, "wield", function(self)
    -- Only hide HUD if this is the local player's auspex (not a husk)
    if self._is_husk then return end
    
    mod._scan_active = true
    _set_crosshair_visible(false)
end)

mod:hook_safe(CLASS.AuspexEffects, "unwield", function(self)
    -- Only restore HUD if this is the local player's auspex (not a husk)
    if self._is_husk then return end
    
    mod._scan_active = false
    _set_crosshair_visible(true)
end)

local HudElementBase = rawget(_G, "HudElementBase")
if HudElementBase then
    mod:hook_safe(HudElementBase, "init", function(self)
        if not mod._scan_active then return end
        local class_name = self.__class_name

        local should = should_hide_element(class_name)
        if not should then return end
        local alpha = mod:get("smooth_fade") and mod._current_alpha or math.clamp(mod:get("transparency_amount") or 0, 0, 1)
        _apply_alpha_to_element(self, alpha)
    end)
end

local stamina_hook_applied = false
mod:hook_require("scripts/ui/hud/elements/blocking/hud_element_stamina", function(HudElementStamina)
    if stamina_hook_applied then
        return
    end
    stamina_hook_applied = true
    mod:hook(HudElementStamina, "_draw_stamina_chunks", function(func, self, dt, t, ui_renderer)
        return func(self, dt, t, ui_renderer)
    end)
end)

local subtitle_hook_applied = false

mod:hook_require("scripts/ui/constant_elements/elements/subtitles/constant_element_subtitles", function(Subtitles)
    if subtitle_hook_applied then
        return
    end
    subtitle_hook_applied = true

    mod:hook_safe(Subtitles, "update", function(self)
        if not mod._scan_active then
            if self.__scanner_captions_restored then
                return
            end
            if self._setup_text_opacity then
                self:_setup_text_opacity()
            end
            if self._setup_letterbox then
                self:_setup_letterbox()
            end
            self.__scanner_captions_restored = true
            return
        end

        local alpha = math.clamp((mod:get("caption_opacity") or 0) * 255, 0, 255)
        if self._set_text_opacity then
            self:_set_text_opacity(alpha)
        end
        if self._set_letterbox_opacity then
            self:_set_letterbox_opacity(alpha)
        end
        self.__scanner_captions_restored = false
    end)
end)

local function _apply_current_alpha()
    local ui_manager = rawget(_G, "Managers") and Managers.ui
    if not ui_manager then return end
    local hud = ui_manager:get_hud()
    if not hud then return end

    local function set_alpha(el, class_name)
        if not el then return end
        -- Check if this element should be hidden
        local should = should_hide_element(class_name)
        if not should then
            -- If we shouldn't hide it, make it fully visible
            _apply_alpha_to_element(el, 1)
            return
        end
        _apply_alpha_to_element(el, mod._current_alpha)
    end

    for class_name, _ in pairs(_ALWAYS_HIDE_ELEMENTS) do
        local element = hud:element(class_name)
        if element then
            set_alpha(element, class_name)
        end
    end

    for class_name, _ in pairs(hud._elements or {}) do
        if (is_buff_bar(class_name) or is_ability_icon(class_name)) then
            local element = hud:element(class_name)
            if element then
                set_alpha(element, class_name)
            end
        end
    end

    local ce = Managers.ui and Managers.ui:ui_constant_elements()
    if ce and ce._elements then
        for class_name, element in pairs(ce._elements) do
            if (is_buff_bar(class_name) or is_ability_icon(class_name)) and element then
                set_alpha(element, class_name)
            end
        end
    end

    for icon, _ in pairs(mod._ability_icons) do
        if icon.__class_name then
            set_alpha(icon, icon.__class_name)
        end
    end
end

local function _fade_update(dt)
    if not mod._fade_target then return end
    dt = dt or 0
    if dt == 0 then
        local now = Application.time_since_launch()
        dt = mod.__lt and (now - mod.__lt) or 0
        mod.__lt = now
    end
    local dir = (mod._fade_target > mod._current_alpha) and 1 or -1
    local step = mod._fade_speed * dt * dir
    mod._current_alpha = mod._current_alpha + step
    if (dir > 0 and mod._current_alpha >= mod._fade_target) or (dir < 0 and mod._current_alpha <= mod._fade_target) then
        mod._current_alpha = mod._fade_target
        mod._fade_target = nil
    end
    _apply_current_alpha()
end

mod.on_update = _fade_update
mod.update = _fade_update
