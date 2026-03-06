--[[
	File: lobby/talent_preview_lobby.lua
	Description: Label, icon logic file
	Overall Release Version: 1.1.5
	File Version: 1.1.5
    File Introduced in: 1.1.0
	Last Updated: 2026-01-21
	Author: LAUREHTE
]]
local mod = get_mod("TalentPreview")
local function _log_once(key, message)
    if not mod._tp_log_once then
        mod._tp_log_once = {}
    end

    if mod._tp_log_once[key] then
        return
    end

    mod._tp_log_once[key] = true
    if mod:get("debug_logging") and mod.echo then
        mod:echo(message)
    end
end
local UIWidget
do
    local ok, module = pcall(require, "scripts/managers/ui/ui_widget")
    if ok then
        UIWidget = module
    else
        _log_once("uiwidget_missing", "[TalentPreview] UIWidget unavailable; preview disabled.")
    end
end
local TalentBuilderViewSettings
do
    local ok, module = pcall(require, "scripts/ui/views/talent_builder_view/talent_builder_view_settings")
    if ok then
        TalentBuilderViewSettings = module
    else
        _log_once("talent_settings_missing", "[TalentPreview] TalentBuilderViewSettings unavailable; preview disabled.")
    end
end
local TalentLayoutParser
do
    local ok, module = pcall(require, "scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
    if ok then
        TalentLayoutParser = module
    else
        _log_once("talent_parser_missing", "[TalentPreview] TalentLayoutParser unavailable; tooltips disabled.")
    end
end
local ContentBlueprints
do
    local ok, module = pcall(require, "scripts/ui/views/lobby_view/lobby_view_content_blueprints")
    if ok then
        ContentBlueprints = module
    else
        _log_once("content_blueprints_missing", "[TalentPreview] Lobby content blueprints unavailable; preview disabled.")
    end
end
local TreePreview = mod:io_dofile("TalentPreview/scripts/mods/TalentPreview/lobby/talent_preview_tree")
local StandardPreview = mod:io_dofile("TalentPreview/scripts/mods/TalentPreview/lobby/talent_preview_standard")
local TALENT_VIEW_PACKAGE = "packages/ui/views/talent_builder_view/talent_builder_view"
local BROKER_STIMM_VIEW_PACKAGE = "packages/ui/views/broker_stimm_builder_view/broker_stimm_builder_view"
local MAIN_MENU_VIEW_PACKAGE = "packages/ui/views/main_menu_view/main_menu_view"
local ICON_LOAD_REFERENCE = "TalentPreview"
local loaded_archetypes = {}
local loading_archetypes = {}
local talent_packages_loaded = false
local loaded_packages = {}
local _get_background_style
local function _is_lobby_view_active()
    local ui_manager = Managers.ui

    if not ui_manager or not ui_manager.view_active then
        return false
    end
    return ui_manager:view_active("lobby_view")
end
local function _ensure_preview_packages(background_style)
    if not Managers or not Managers.package then
        _log_once("packages_missing", "[TalentPreview] Package manager unavailable; preview disabled.")
        return
    end
    local package_manager = Managers.package
    if not package_manager then
        return
    end

    if not loaded_packages[TALENT_VIEW_PACKAGE] then
        loaded_packages[TALENT_VIEW_PACKAGE] = package_manager:load(TALENT_VIEW_PACKAGE, ICON_LOAD_REFERENCE, nil, true) or true
    end

    if not loaded_packages[BROKER_STIMM_VIEW_PACKAGE] then
        loaded_packages[BROKER_STIMM_VIEW_PACKAGE] = package_manager:load(BROKER_STIMM_VIEW_PACKAGE, ICON_LOAD_REFERENCE, nil, true) or true
    end
    local active_style = background_style or _get_background_style()
    local use_themed_background = active_style == "themed" or active_style == "themed_glow"

    if use_themed_background and not loaded_packages[MAIN_MENU_VIEW_PACKAGE] then
        loaded_packages[MAIN_MENU_VIEW_PACKAGE] = package_manager:load(MAIN_MENU_VIEW_PACKAGE, ICON_LOAD_REFERENCE, nil, true) or true
    end
end
local function _on_archetype_icons_loaded(archetype_name)
    loaded_archetypes[archetype_name] = true
    loading_archetypes[archetype_name] = nil
    mod._pending_refresh = true
end
local function _ensure_talent_icon_packages(profile)
    if not UIWidget or not ContentBlueprints or not TalentBuilderViewSettings then
        return
    end
    local talents_service = Managers.data_service and Managers.data_service.talents
    if not talents_service then
        return
    end

    if not talent_packages_loaded then
        _ensure_preview_packages(_get_background_style())
        talent_packages_loaded = true
    end

    if not talents_service.load_icons_for_profile then
        return
    end
    local archetype = profile and profile.archetype
    local archetype_name = archetype and archetype.name

    if not archetype_name or loaded_archetypes[archetype_name] or loading_archetypes[archetype_name] then
        return
    end
    local on_loaded = callback(_on_archetype_icons_loaded, archetype_name)
    loading_archetypes[archetype_name] = talents_service:load_icons_for_profile(profile, ICON_LOAD_REFERENCE, on_loaded, true) or true
end
local function _safe_number(value, fallback)
    if type(value) ~= "number" or value ~= value then
        return fallback
    end
    return value
end
local function _get_icon_size()
    return math.floor(_safe_number(mod:get("icon_size"), 60))
end
local function _get_icons_per_row()
    local value = math.floor(_safe_number(mod:get("icons_per_row"), 4))

    if value < 1 then
        return 1
    end
    return value
end
local function _get_preview_offset_y()
    local value = math.floor(_safe_number(mod:get("preview_offset_y"), 170))

    if value < 0 then
        return 0
    end
    return value
end
local function _get_preview_offset_x()
    local value = math.floor(_safe_number(mod:get("preview_offset_x"), -10))
    return value
end
local function _get_tree_scale_percent()
    local value = math.floor(_safe_number(mod:get("tree_scale_percent"), 100))

    if value < 10 then
        value = 10
    elseif value > 300 then
        value = 300
    end
    return value
end
local function _get_tree_area_width()
    local value = math.floor(_safe_number(mod:get("tree_area_width"), 360))

    if value < 180 then
        value = 180
    end
    return value
end
local function _get_tree_area_height()
    local value = math.floor(_safe_number(mod:get("tree_area_height"), 320))

    if value < 180 then
        value = 180
    end
    return value
end
local function _get_tree_offset_y()
    local value = math.floor(_safe_number(mod:get("tree_offset_y"), 170))

    if value < 0 then
        return 0
    end
    return value
end
local function _get_tree_offset_x()
    local value = math.floor(_safe_number(mod:get("tree_offset_x"), -10))
    return value
end
local function _get_tree_node_size()
    local value = math.floor(_safe_number(mod:get("tree_node_size"), 25))

    if value < 16 then
        value = 16
    elseif value > 48 then
        value = 48
    end
    return value
end
local function _get_tree_stimm_gap()
    local value = math.floor(_safe_number(mod:get("tree_stimm_gap"), 80))

    if value < 0 then
        value = 0
    end
    return value
end
local function _get_tree_stimm_offset_x()
    return math.floor(_safe_number(mod:get("tree_stimm_offset_x"), 360))
end
local function _get_tree_stimm_offset_y()
    return math.floor(_safe_number(mod:get("tree_stimm_offset_y"), 0))
end
local function _get_tree_stimm_scale_percent()
    local value = math.floor(_safe_number(mod:get("tree_stimm_scale_percent"), 100))

    if value < 50 then
        value = 50
    elseif value > 200 then
        value = 200
    end
    return value
end
local function _get_tree_background_style()
    local style = mod:get("tree_background_style")

    if style == "off" or style == "black" or style == "themed" or style == "themed_glow" then
        return style
    end
    return "themed"
end
local function _get_tree_settings()
    return {
        scale_percent = _get_tree_scale_percent(),
        area_width = _get_tree_area_width(),
        area_height = _get_tree_area_height(),
        offset_x = _get_tree_offset_x(),
        offset_y = _get_tree_offset_y(),
        node_size = _get_tree_node_size(),
        stimm_gap = _get_tree_stimm_gap(),
        stimm_offset_x = _get_tree_stimm_offset_x(),
        stimm_offset_y = _get_tree_stimm_offset_y(),
        stimm_scale_percent = _get_tree_stimm_scale_percent(),
        background_style = _get_tree_background_style(),
        include_stimm_tree = mod:get("tree_show_stimm_tree") ~= false,
    }
end
local function _get_tree_settings_for_slot(profile, spawn_slot)
    local settings = _get_tree_settings()
    local archetype = profile and profile.archetype

    if archetype and archetype.name == "broker" then
        local index = spawn_slot and spawn_slot.index or 0
        local shift = math.abs(settings.stimm_offset_x or _get_tree_stimm_offset_x())

        if index <= 2 then
            settings.stimm_offset_x = shift
        else
            settings.stimm_offset_x = -shift
        end
    end
    return settings
end

_get_background_style = function()
    local style = mod:get("preview_background_style")

    if style == "off" or style == "black" or style == "themed" or style == "themed_glow" then
        return style
    end
    return "themed"
end
local function _get_standard_settings()
    return {
        icon_size = _get_icon_size(),
        icons_per_row = _get_icons_per_row(),
        offset_x = _get_preview_offset_x(),
        offset_y = _get_preview_offset_y(),
        background_style = _get_background_style(),
        show_keystone = mod:get("show_keystone") ~= false,
        show_stat = mod:get("show_stat") ~= false,
        show_default = mod:get("show_default") ~= false,
        show_blitz = mod:get("show_blitz") ~= false,
        show_modifiers = mod:get("show_modifiers") ~= false,
        show_aura = mod:get("show_aura") ~= false,
        show_ability_modifiers = mod:get("show_ability_modifiers") ~= false,
        show_broker_stimm = mod:get("show_broker_stimm") ~= false,
    }
end
local function _shrink_panel_hotspot(panel_widget)
    if not panel_widget or panel_widget._tp_hotspot_shrunk then
        return
    end
    local passes = panel_widget.passes
    if not passes then
        return
    end
    local background_style_ids = {
        background = true,
        background_gradient = true,
        button_gradient = true,
        frame = true,
        corner = true,
    }
    local function _apply_panel_style(style)
        style.size = { 260, 110 }
        style.horizontal_alignment = "center"
        style.vertical_alignment = "top"
        local offset = style.offset or { 0, 0, 0 }
        offset[1] = 0
        offset[2] = -5
        style.offset = offset
    end

    for i = 1, #passes do
        local pass = passes[i]
        local is_hotspot = pass.pass_type == "hotspot"
        local is_background = pass.style_id and background_style_ids[pass.style_id]
        if is_hotspot or is_background then
            local style
            if pass.style_id then
                style = panel_widget.style and panel_widget.style[pass.style_id]
                if not style then
                    style = {}
                    panel_widget.style = panel_widget.style or {}
                    panel_widget.style[pass.style_id] = style
                end
            else
                style = pass.style or {}
                pass.style = style
            end
            _apply_panel_style(style)
        end
    end

    panel_widget._tp_hotspot_shrunk = true
end
local function _clear_preview_widgets(self, spawn_slot, mode)
    if not spawn_slot then
        return
    end
    local clear_standard = not mode or mode == "standard"
    local clear_tree = not mode or mode == "tree"

    if clear_standard then
        if spawn_slot.talent_preview_background_standard then
            self:_unregister_widget_name(spawn_slot.talent_preview_background_standard.name)
            spawn_slot.talent_preview_background_standard = nil
        end
        local widgets = spawn_slot.talent_preview_widgets_standard
        if widgets then
            for i = 1, #widgets do
                self:_unregister_widget_name(widgets[i].name)
            end
        end

        spawn_slot.talent_preview_widgets_standard = {}
        spawn_slot.talent_preview_signature_standard = nil
        spawn_slot.talent_preview_alpha_standard = nil
    end

        if clear_tree then
            if spawn_slot.talent_preview_background_tree then
                self:_unregister_widget_name(spawn_slot.talent_preview_background_tree.name)
                spawn_slot.talent_preview_background_tree = nil
            end
            if spawn_slot.talent_preview_background_tree_stimm then
                self:_unregister_widget_name(spawn_slot.talent_preview_background_tree_stimm.name)
                spawn_slot.talent_preview_background_tree_stimm = nil
            end
        local link_widgets = spawn_slot.talent_preview_link_widgets_tree
        if link_widgets then
            for i = 1, #link_widgets do
                self:_unregister_widget_name(link_widgets[i].name)
            end
        end
        local widgets = spawn_slot.talent_preview_widgets_tree
        if widgets then
            for i = 1, #widgets do
                self:_unregister_widget_name(widgets[i].name)
            end
        end

        spawn_slot.talent_preview_link_widgets_tree = {}
        spawn_slot.talent_preview_widgets_tree = {}
        spawn_slot.talent_preview_signature_tree = nil
        spawn_slot.talent_preview_alpha_tree = nil
        spawn_slot.talent_preview_tree_widget_hovered = nil
    end
end
local function _update_slot_preview(self, spawn_slot)
    if not spawn_slot then
        return
    end

    if not spawn_slot.occupied or not spawn_slot.player then
        if mod._tp_tree_pins then
            mod._tp_tree_pins[spawn_slot.index] = nil
        end
        _clear_preview_widgets(self, spawn_slot)
        return
    end
    local profile = spawn_slot.player:profile()
    if not profile then
        if mod._tp_tree_pins then
            mod._tp_tree_pins[spawn_slot.index] = nil
        end
        _clear_preview_widgets(self, spawn_slot)
        return
    end
    local pins = mod._tp_tree_pins
    local is_tree_pinned = pins and pins[spawn_slot.index]
    local hover_slots = mod._tp_hover_slots
    local is_tree_hovered = hover_slots and hover_slots[spawn_slot.index]
    local tree_active = is_tree_pinned or is_tree_hovered
    local hide_standard = mod._tp_hide_standard

    _ensure_talent_icon_packages(profile)

    if tree_active then
        if not TreePreview or not TreePreview.collect or not TreePreview.build_widgets then
            _log_once("tree_module_missing", "[TalentPreview] Tree preview module unavailable; disabling tree.")
            if pins then
                pins[spawn_slot.index] = nil
            end
            _clear_preview_widgets(self, spawn_slot, "tree")
        else
            local tree_settings = _get_tree_settings_for_slot(profile, spawn_slot)
            _ensure_preview_packages(tree_settings.background_style)
            local tree, signature = TreePreview.collect(profile, tree_settings)
            if not tree then
                _clear_preview_widgets(self, spawn_slot, "tree")
            else
                if signature == "" then
                    signature = "tree_empty"
                end

        if signature ~= spawn_slot.talent_preview_signature_tree then
            _clear_preview_widgets(self, spawn_slot, "tree")
            TreePreview.build_widgets(self, spawn_slot, tree, tree_settings)
            spawn_slot.talent_preview_signature_tree = signature
            if tree_active and spawn_slot.talent_preview_alpha_tree == nil then
                spawn_slot.talent_preview_alpha_tree = 0
            end
        end
    end
        end
    end

    if hide_standard then
        return
    end

    if not StandardPreview or not StandardPreview.collect or not StandardPreview.build_widgets then
        _log_once("standard_module_missing", "[TalentPreview] Standard preview module unavailable; skipping.")
        _clear_preview_widgets(self, spawn_slot, "standard")
        return
    end
    local standard_settings = _get_standard_settings()
    local entries_by_category, signature = StandardPreview.collect(profile, standard_settings)

    if signature == spawn_slot.talent_preview_signature_standard then
        return
    end

    _clear_preview_widgets(self, spawn_slot, "standard")

    if not entries_by_category or signature == "" then
        return
    end

    _ensure_preview_packages(standard_settings.background_style)
    StandardPreview.build_widgets(self, spawn_slot, entries_by_category, standard_settings)
    spawn_slot.talent_preview_signature_standard = signature
    if spawn_slot.talent_preview_alpha_standard == nil then
        spawn_slot.talent_preview_alpha_standard = 0
    end
end
local function _update_all_slots(self)
    local spawn_slots = self._spawn_slots

    if not spawn_slots then
        return
    end
    local has_pin = mod._tp_tree_pins and next(mod._tp_tree_pins) ~= nil
    local has_hover = mod._tp_hover_slots and next(mod._tp_hover_slots) ~= nil
    mod._tp_hide_standard = has_pin or has_hover

    if mod._pending_clear then
        for i = 1, #spawn_slots do
            _clear_preview_widgets(self, spawn_slots[i])
        end

        mod._pending_clear = false
        return
    end

    if mod._pending_refresh then
        for i = 1, #spawn_slots do
            local slot = spawn_slots[i]
            if slot then
                slot.talent_preview_signature_standard = nil
                slot.talent_preview_signature_tree = nil
            end
        end

        mod._pending_refresh = false
    end

    for i = 1, #spawn_slots do
        _update_slot_preview(self, spawn_slots[i])
    end
end
function mod.on_setting_changed(setting_id)
    if setting_id == "enable_in_lobby" then
        if not mod:get("enable_in_lobby") then
            mod._pending_clear = true
            mod._tp_tree_pins = nil
        else
            mod._pending_refresh = true
        end
        return
    end

    if setting_id == "icon_size" or setting_id == "icons_per_row" then
        mod._pending_refresh = true
        return
    end

    if setting_id == "preview_offset_y" or setting_id == "preview_offset_x" then
        mod._pending_refresh = true
        return
    end

    if setting_id == "tree_scale_percent"
        or setting_id == "tree_area_width"
        or setting_id == "tree_area_height"
        or setting_id == "tree_offset_y"
        or setting_id == "tree_offset_x"
        or setting_id == "tree_node_size"
        or setting_id == "tree_stimm_gap"
        or setting_id == "tree_stimm_offset_x"
        or setting_id == "tree_stimm_offset_y"
        or setting_id == "tree_stimm_scale_percent"
        or setting_id == "tree_show_stimm_tree"
        or setting_id == "tree_background_style" then
        mod._pending_refresh = true
        return
    end

    if setting_id == "show_keystone"
        or setting_id == "show_stat"
        or setting_id == "show_default"
        or setting_id == "show_modifiers"
        or setting_id == "show_aura"
        or setting_id == "show_blitz"
        or setting_id == "show_ability_modifiers"
        or setting_id == "show_broker_stimm"
        or setting_id == "preview_background_style" then
        mod._pending_refresh = true
    end
end
function mod.on_unload(exit_game)
    if not exit_game then
        return
    end
    local package_manager = Managers.package
    if not package_manager or not package_manager.has_loaded_id then
        return
    end

    for _, load_id in pairs(loaded_packages) do
        if load_id and load_id ~= true and package_manager:has_loaded_id(load_id) then
            package_manager:release(load_id)
        end
    end
end
mod:hook_safe("LobbyView", "_setup_spawn_slots", function(self)
    if not mod:get("enable_in_lobby") then
        return
    end
    local spawn_slots = self._spawn_slots
    if not spawn_slots then
        return
    end

    for i = 1, #spawn_slots do
        local slot = spawn_slots[i]
        _shrink_panel_hotspot(slot.panel_widget)
        slot.talent_preview_widgets_standard = slot.talent_preview_widgets_standard or {}
        slot.talent_preview_widgets_tree = slot.talent_preview_widgets_tree or {}
        slot.talent_preview_link_widgets_tree = slot.talent_preview_link_widgets_tree or {}
        slot.talent_preview_signature_standard = nil
        slot.talent_preview_signature_tree = nil
        slot.talent_preview_alpha_standard = nil
        slot.talent_preview_alpha_tree = nil
        slot.talent_preview_tree_widget_hovered = nil
        slot.talent_preview_background_tree_stimm = nil
    end
end)
mod:hook_safe("LobbyView", "_assign_player_to_slot", function(self, player, slot)
    if not mod:get("enable_in_lobby") then
        return
    end

    _shrink_panel_hotspot(slot.panel_widget)

    if mod._tp_tree_pins then
        mod._tp_tree_pins[slot.index] = nil
    end
    _clear_preview_widgets(self, slot)
    _update_slot_preview(self, slot)
end)
mod:hook("LobbyView", "_check_loadout_changes", function(func, self)
    func(self)

    if not mod:get("enable_in_lobby") and not mod._pending_clear then
        return
    end

    if not _is_lobby_view_active() then
        return
    end

    _update_all_slots(self)
end)
mod:hook_safe("LobbyView", "_reset_spawn_slot", function(self, slot)
    if mod._tp_tree_pins then
        mod._tp_tree_pins[slot.index] = nil
    end
    _clear_preview_widgets(self, slot)
end)
mod:hook_safe("LobbyView", "_destroy_spawn_slots", function(self)
    local spawn_slots = self._spawn_slots

    if not spawn_slots then
        return
    end

    for i = 1, #spawn_slots do
        _clear_preview_widgets(self, spawn_slots[i])
    end

    mod._tp_tree_pins = nil
end)
mod:hook("LobbyView", "_draw_widgets", function(func, self, dt, t, input_service, ui_renderer)
    func(self, dt, t, input_service, ui_renderer)

    if not mod:get("enable_in_lobby") then
        return
    end

    if not _is_lobby_view_active() then
        return
    end

    if not self._world_initialized or self._show_weapons then
        return
    end
    local spawn_slots = self._spawn_slots
    local hovered_slot
    local hovered_data
    local hover_slots = {}
    local tree_hover_slots = {}
    local has_pin = mod._tp_tree_pins and next(mod._tp_tree_pins) ~= nil
    local hide_standard_all = has_pin
    if spawn_slots then
        for i = 1, #spawn_slots do
            local slot = spawn_slots[i]
            local panel_widget = slot.panel_widget
            local panel_hotspot = panel_widget and panel_widget.content and panel_widget.content.hotspot
            local allow_hotspot = slot.occupied and not self._is_animating_on_exit
            if panel_hotspot and allow_hotspot and (panel_hotspot.is_hover or panel_hotspot.is_selected) then
                hover_slots[slot.index] = true
                hide_standard_all = true
            end
            local tree_widgets = slot.talent_preview_widgets_tree
            if tree_widgets then
                for j = 1, #tree_widgets do
                    local hotspot = tree_widgets[j].content.hotspot
                    if hotspot and (hotspot.is_hover or hotspot.is_selected) then
                        tree_hover_slots[slot.index] = true
                        hide_standard_all = true
                        break
                    end
                end
            end
        end
    end
    local fade_speed = 10
    local function _step_alpha(current, target, dt)
        if current == nil then
            return target
        end

        if current == target then
            return current
        end
        local delta = target - current
        local step = math.min(math.abs(delta), fade_speed * dt)

        if delta > 0 then
            return current + step
        end
        return current - step
    end

    for i = 1, #spawn_slots do
        local slot = spawn_slots[i]
        local panel_widget = slot.panel_widget
        local panel_hotspot = panel_widget and panel_widget.content and panel_widget.content.hotspot

        if panel_hotspot then
            local allow_hotspot = slot.occupied and not self._is_animating_on_exit
            panel_hotspot.disabled = not allow_hotspot

            if allow_hotspot and panel_hotspot.on_pressed then
                mod._tp_tree_pins = mod._tp_tree_pins or {}
                if mod._tp_tree_pins[slot.index] then
                    mod._tp_tree_pins[slot.index] = nil
                else
                    mod._tp_tree_pins[slot.index] = true
                end

                has_pin = mod._tp_tree_pins and next(mod._tp_tree_pins) ~= nil
                hide_standard_all = has_pin or hide_standard_all
                panel_hotspot.on_pressed = nil
            end
            local is_hovered = allow_hotspot and (panel_hotspot.is_hover or panel_hotspot.is_selected)
            if is_hovered then
                hover_slots[slot.index] = true
                hide_standard_all = true
            end

            if slot.talent_preview_hovered ~= is_hovered then
                slot.talent_preview_hovered = is_hovered
            end
        end

        if slot.occupied and slot.profile_spawner and slot.profile_spawner:spawned() then
            local widget_offset_x = slot.panel_widget.offset[1] - 30
            local standard_widgets = slot.talent_preview_widgets_standard
            local tree_widgets = slot.talent_preview_widgets_tree
            local bg_standard = slot.talent_preview_background_standard
            local bg_tree = slot.talent_preview_background_tree
            local bg_tree_stimm = slot.talent_preview_background_tree_stimm
            local tree_links = slot.talent_preview_link_widgets_tree
            local is_tree_pinned = mod._tp_tree_pins and mod._tp_tree_pins[slot.index]
            local was_tree_widget_hovered = slot.talent_preview_tree_widget_hovered
            local tree_widget_hovered_now = tree_hover_slots[slot.index] or false
            local is_tree_hovered = hover_slots[slot.index] or was_tree_widget_hovered or tree_widget_hovered_now
            local tree_active = is_tree_pinned or is_tree_hovered
            local hide_standard = hide_standard_all
            local standard_active = not hide_standard and not tree_active
            local target_standard = standard_active and 1 or 0
            local target_tree = tree_active and 1 or 0
            local alpha_standard = _step_alpha(slot.talent_preview_alpha_standard, target_standard, dt)
            local alpha_tree = _step_alpha(slot.talent_preview_alpha_tree, target_tree, dt)

            slot.talent_preview_alpha_standard = alpha_standard
            slot.talent_preview_alpha_tree = alpha_tree
            local draw_standard = alpha_standard > 0 and not tree_active and not hide_standard
            if bg_standard and draw_standard then
                bg_standard.alpha_multiplier = alpha_standard
                bg_standard.offset[1] = bg_standard.original_offset[1] + widget_offset_x + 35
                bg_standard.offset[2] = bg_standard.original_offset[2]

                UIWidget.draw(bg_standard, ui_renderer)
            end

            if bg_tree and alpha_tree > 0 then
                bg_tree.alpha_multiplier = alpha_tree
                bg_tree.offset[1] = bg_tree.original_offset[1] + widget_offset_x + 35
                bg_tree.offset[2] = bg_tree.original_offset[2]

                UIWidget.draw(bg_tree, ui_renderer)
            end
            if bg_tree_stimm and alpha_tree > 0 then
                bg_tree_stimm.alpha_multiplier = alpha_tree
                bg_tree_stimm.offset[1] = bg_tree_stimm.original_offset[1] + widget_offset_x + 35
                bg_tree_stimm.offset[2] = bg_tree_stimm.original_offset[2]

                UIWidget.draw(bg_tree_stimm, ui_renderer)
            end

            if tree_links and alpha_tree > 0 then
                for j = 1, #tree_links do
                    local link_widget = tree_links[j]

                    link_widget.alpha_multiplier = alpha_tree
                    link_widget.offset[1] = link_widget.original_offset[1] + widget_offset_x + 35
                    link_widget.offset[2] = link_widget.original_offset[2]

                    UIWidget.draw(link_widget, ui_renderer)
                end
            end
            local tree_widget_hovered = false
            local function _draw_widgets(widgets, alpha, track_tree_hover)
                if not widgets or alpha <= 0 then
                    return
                end

                for j = 1, #widgets do
                    local talent_widget = widgets[j]
                    local preview_alpha = talent_widget.content and talent_widget.content.talent_preview_alpha

                    talent_widget.alpha_multiplier = alpha * (preview_alpha or 1)
                    talent_widget.offset[1] = talent_widget.original_offset[1] + widget_offset_x + 35
                    talent_widget.offset[2] = talent_widget.original_offset[2]

                    UIWidget.draw(talent_widget, ui_renderer)

                    if not hovered_slot then
                        local hotspot = talent_widget.content.hotspot
                        local is_hover = hotspot and (hotspot.is_hover or hotspot.is_selected)

                        if is_hover then
                            if track_tree_hover then
                                tree_widget_hovered = true
                            end
                            hovered_slot = slot
                            hovered_data = talent_widget.content.talent_preview_data
                            self._hovered_tooltip_panel_widget = talent_widget
                        end
                    elseif track_tree_hover then
                        local hotspot = talent_widget.content.hotspot
                        if hotspot and (hotspot.is_hover or hotspot.is_selected) then
                            tree_widget_hovered = true
                        end
                    end
                end
            end

            if alpha_tree > alpha_standard then
                _draw_widgets(tree_widgets, alpha_tree, true)
                if draw_standard and not hovered_slot then
                    _draw_widgets(standard_widgets, alpha_standard, false)
                end
            else
                if draw_standard then
                    _draw_widgets(standard_widgets, alpha_standard, false)
                end
                if not hovered_slot then
                    _draw_widgets(tree_widgets, alpha_tree, true)
                end
            end

            if tree_widget_hovered then
                hover_slots[slot.index] = true
                hide_standard_all = true
            end
            slot.talent_preview_tree_widget_hovered = tree_widget_hovered or tree_widget_hovered_now
        end
    end

    mod._tp_hover_slots = hover_slots
    mod._tp_hide_standard = hide_standard_all
    local current_hover = self._hovered_slot_talent_data
    local has_base_hover = current_hover and not current_hover.is_talent_preview

    if hovered_data then
        if not has_base_hover and (not current_hover or current_hover ~= hovered_data) then
            self:_on_tooltip_hover_stop()
            self:_on_tooltip_hover_start(hovered_slot, hovered_data)
        end

        if not has_base_hover then
            local tooltip = self._widgets_by_name and self._widgets_by_name.talent_tooltip
            if tooltip then
                tooltip.content.visible = true
                tooltip.alpha_multiplier = 1
                self._tooltip_alpha_multiplier = 1
                self._tooltip_draw_delay = 0
            end
        end
    elseif current_hover and current_hover.is_talent_preview then
        self._hovered_tooltip_panel_widget = nil
        self:_on_tooltip_hover_stop()
    end
end)
mod:hook("LobbyView", "_setup_tooltip_info", function(func, self, talent_hover_data)
    if not TalentLayoutParser or not TalentBuilderViewSettings then
        return func(self, talent_hover_data)
    end

    if not talent_hover_data or not talent_hover_data.is_talent_preview then
        return func(self, talent_hover_data)
    end
    local widgets_by_name = self._widgets_by_name
    local widget = widgets_by_name.talent_tooltip
    local content = widget.content
    local style = widget.style

    content.title = "title"
    content.description = "<<UNASSIGNED TALENT NODE>>"
    local talent = talent_hover_data.talent

    if talent then
        local text_vertical_offset = 14
        local node_type = talent_hover_data.node_type
        local node_settings = TalentBuilderViewSettings.settings_by_node_type[node_type] or TalentBuilderViewSettings.settings_by_node_type.default

        content.talent_type_title = node_settings and (Localize(node_settings.display_name) or "") or ""
        local talent_type_title_height = self:_get_text_height(content.talent_type_title, style.talent_type_title, {400, 20})

        style.talent_type_title.offset[2] = text_vertical_offset
        style.talent_type_title.size[2] = talent_type_title_height
        text_vertical_offset = text_vertical_offset + talent_type_title_height
        local points_spent = talent_hover_data.points_spent or 1
        local description = TalentLayoutParser.talent_description(talent, points_spent, Color.ui_terminal(255, true))
        local localized_title = TalentLayoutParser.talent_title(talent, points_spent, Color.ui_terminal(255, true))

        content.title = localized_title
        content.description = description
        local widget_width, _ = self:_scenegraph_size(widget.scenegraph_id, self._ui_scenegraph)
        local text_size_addition = style.title.size_addition
        local dummy_size = {
            widget_width + text_size_addition[1],
            20,
        }
        local title_height = self:_get_text_height(content.title, style.title, dummy_size)

        style.title.offset[2] = text_vertical_offset
        style.title.size[2] = title_height
        text_vertical_offset = text_vertical_offset + title_height + 10
        local description_height = self:_get_text_height(content.description, style.description, dummy_size)

        style.description.offset[2] = text_vertical_offset
        style.description.size[2] = description_height
        text_vertical_offset = text_vertical_offset + description_height + 20
        content.exculsive_group_description = ""

        self:_set_scenegraph_size(widget.scenegraph_id, nil, text_vertical_offset, self._ui_scenegraph)
    end
end)
mod:hook("LobbyView", "_update_talent_tooltip_position", function(func, self)
    local hovered_data = self._hovered_slot_talent_data
    local hovered_widget = self._hovered_tooltip_panel_widget

    if hovered_data and hovered_data.is_talent_preview and hovered_widget then
        local ui_scenegraph = self._ui_scenegraph
        local tooltip_widget = self._widgets_by_name and self._widgets_by_name.talent_tooltip

        if tooltip_widget then
            local parent_scenegraph_id = hovered_widget.scenegraph_id
            local parent_position = self:_scenegraph_world_position(parent_scenegraph_id)
            local widget_offset = hovered_widget.offset
            local tooltip_offset = tooltip_widget.offset
            local tooltip_width, tooltip_height = self:_scenegraph_size(tooltip_widget.scenegraph_id, ui_scenegraph)
            local icon_size = hovered_data.icon_size or _get_icon_size()
            local tooltip_offset_x = hovered_data.tooltip_offset_x or 0

            tooltip_offset[1] = parent_position[1] + widget_offset[1] + icon_size * 0.5 - tooltip_width * 0.5 + tooltip_offset_x
            tooltip_offset[2] = parent_position[2] + widget_offset[2] + icon_size + 8
        end
        return
    end
    return func(self)
end)
