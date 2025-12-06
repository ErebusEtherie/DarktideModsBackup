-- File: RingHud/scripts/mods/RingHud/systems/vanilla_hud_manager.lua
local mod = get_mod("RingHud")
if not mod then return end

-- Expose this module for cross-file calls
mod.vanilla_hud_manager = mod.vanilla_hud_manager or {}
local VanillaHudManager = mod.vanilla_hud_manager

-- ─────────────────────────────────────────────────────────────────────────────
-- Existing RingHud visibility & objective feed logic (unchanged)
-- ─────────────────────────────────────────────────────────────────────────────

-- Shared cross-file state (weak keys to avoid leaks)
mod._ringhud_hooked_elements = mod._ringhud_hooked_elements or setmetatable({}, { __mode = "k" })
mod._ringhud_visibility_applied_to_hud = mod._ringhud_visibility_applied_to_hud or setmetatable({}, { __mode = "k" })

local RING_HUD_VISIBILITY_RULES = {
    {
        id = "WeaponCounter",
        class_name = "HudElementWeaponCounter",
        condition_func = function()
            return mod._settings.charge_kills_enabled == true
        end,
    },
    {
        id = "Blocking",
        class_name = "HudElementBlocking",
        condition_func = function()
            return mod._settings.stamina_viz_threshold >= 0
        end,
    },
    {
        id = "Overcharge",
        class_name = "HudElementOvercharge",
        condition_func = function()
            return mod._settings.peril_label_enabled == true
        end,
    },
    {
        id = "PlayerAbility",
        class_name = "HudElementPlayerAbilityHandler",
        condition_func = function()
            return mod._settings.hide_default_ability == true
        end,
        target_scenegraph_for_condition = "slot_combat_ability",
    },
    {
        id = "PlayerWeapons",
        class_name = "HudElementPlayerWeaponHandler",
        condition_func = function()
            return mod._settings.hide_default_weapons == true
        end,
        target_scenegraphs_for_condition = { "weapon_pivot", "weapon_slot_5", "weapon_slot_6" },
    },
    {
        id = "PersonalPlayerPanel",
        class_name = "HudElementPersonalPlayerPanel",
        condition_func = function()
            return mod._settings.hide_default_player == true
        end,
    },
    {
        id = "PersonalPlayerPanelHub",
        class_name = "HudElementPersonalPlayerPanelHub",
        condition_func = function()
            return mod._settings.hide_default_player == true
        end,
    },
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function apply_visibility_to_player_panel(panel_instance)
    if not panel_instance or not panel_instance.__class_name then return end
    local panel_class_name = panel_instance.__class_name

    local should_hide_panel = false
    if mod:is_enabled() and (panel_class_name == "HudElementPersonalPlayerPanel" or panel_class_name == "HudElementPersonalPlayerPanelHub") then
        if mod._settings.hide_default_player == true then should_hide_panel = true end
    end

    panel_instance._is_hidden_by_ringhud = should_hide_panel

    if should_hide_panel and not mod._ringhud_hooked_elements[panel_instance] then
        local original_draw_func = panel_instance.draw
        if type(original_draw_func) == "function" then
            mod:hook(panel_instance, "draw", function(func_ref, self_element, ...)
                if self_element._is_hidden_by_ringhud then return end
                return func_ref(self_element, ...)
            end)
            mod._ringhud_hooked_elements[panel_instance] = true
        end
    end
end

local function get_current_hud_instances()
    local ui_manager = Managers.ui
    if not ui_manager then return nil, nil end
    return ui_manager._hud, ui_manager:ui_constant_elements()
end

local function resolve_element_instance(hud, const, class_name)
    local inst
    if hud and hud.element then inst = hud:element(class_name) end
    if (not inst) and const and const.element then inst = const:element(class_name) end
    return inst
end

local function update_element_visibility()
    local hud, const = get_current_hud_instances()
    if not hud and not const then return end

    for _, rule in ipairs(RING_HUD_VISIBILITY_RULES) do
        if rule.id == "PersonalPlayerPanel" or rule.id == "PersonalPlayerPanelHub" then goto continue_rule_loop end

        local element_instance = resolve_element_instance(hud, const, rule.class_name)
        if element_instance then
            element_instance._is_hidden_by_ringhud = (mod:is_enabled() and rule.condition_func()) or false

            if not mod._ringhud_hooked_elements[element_instance] then
                if type(element_instance.draw) == "function" then
                    mod:hook(element_instance, "draw", function(func_ref, self_element, ...)
                        if self_element._is_hidden_by_ringhud then return end
                        return func_ref(self_element, ...)
                    end)
                    mod._ringhud_hooked_elements[element_instance] = true
                end
            end
        end
        ::continue_rule_loop::
    end
end

local function reset_all_visibility_flags()
    local hud, const = get_current_hud_instances()
    if not hud and not const then return end

    for _, rule in ipairs(RING_HUD_VISIBILITY_RULES) do
        local inst = resolve_element_instance(hud, const, rule.class_name)
        if inst then inst._is_hidden_by_ringhud = false end
    end

    local team_panel_handler = hud and hud:element("HudElementTeamPanelHandler")
    if team_panel_handler and team_panel_handler._player_panels_array then
        for _, panel_data in ipairs(team_panel_handler._player_panels_array) do
            if panel_data and panel_data.panel then
                panel_data.panel._is_hidden_by_ringhud = false
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Mission Objective Feed gating (dynamic per-frame)
-------------------------------------------------------------------------------

local function _objective_matches_rules(obj)
    if not obj then return false end

    local function _try(method_name)
        local ok, val = pcall(function()
            local m = obj[method_name]
            return m and m(obj)
        end)
        return ok and val or nil
    end

    local event_type     = _try("event_type") or rawget(obj, "event_type")
    local objective_type = _try("objective_type") or rawget(obj, "objective_type")

    local progress_bar   =
        _try("show_progress_bar") == true or
        _try("show_progression") == true or
        _try("can_hold_progression_bar") == true or
        (function()
            local mp = _try("max_progression") or rawget(obj, "max_progression")
            if type(mp) == "number" then return mp > 0 end
            return false
        end)()

    if progress_bar then return true end
    if objective_type == "luggable" or objective_type == "collect" or objective_type == "side" then return true end
    if event_type == "mid_event" or event_type == "end_event" then return true end

    return false
end

local function _mission_objective_feed_should_hide()
    if not (mod:is_enabled() and mod._settings and mod._settings.minimal_objective_feed_enabled) then
        return false
    end

    local mos = Managers.state and Managers.state.extension and
        Managers.state.extension:system("mission_objective_system")
    if not mos or not mos.active_objectives then
        return true
    end

    local ok, active = pcall(function() return mos:active_objectives() end)
    if not ok or type(active) ~= "table" then
        return true
    end

    for objective, _ in pairs(active) do
        if type(objective) == "table" and _objective_matches_rules(objective) then
            return false
        end
    end

    return true
end

local function _has_active_event_objective()
    local mos = Managers.state and Managers.state.extension and
        Managers.state.extension:system("mission_objective_system")
    if not mos or not mos.active_objectives then
        return false
    end

    local ok, active = pcall(function() return mos:active_objectives() end)
    if not ok or type(active) ~= "table" then
        return false
    end

    local function _event_type_of(obj)
        if type(obj) ~= "table" then return nil end
        local ok2, val = pcall(function()
            local m = obj.event_type
            return type(m) == "function" and m(obj) or nil
        end)
        if ok2 and val ~= nil then return val end
        return rawget(obj, "event_type")
    end

    for objective, _ in pairs(active) do
        local et = _event_type_of(objective)
        if et == "mid_event" or et == "end_event" then
            return true
        end
    end
    return false
end

local function _hud_row_is_interesting(hud_row)
    if not hud_row then return false end

    local function _try_row(method_name)
        local f = hud_row[method_name]
        if type(f) ~= "function" then return nil end
        local ok, val = pcall(f, hud_row)
        return ok and val or nil
    end

    if _try_row("progress_bar") == true then return true end
    if _try_row("progress_timer") == true then return true end
    if _try_row("use_counter") == true then return true end
    if _try_row("has_second_progression") == true then return true end

    local cat = _try_row("objective_category") or rawget(hud_row, "_category") or rawget(hud_row, "category")
    return cat == "luggable" or cat == "collect" or cat == "side"
end

-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function VanillaHudManager.init()
    -- Hook team panel creation once so we can hide the vanilla panel when requested
    if CLASS and CLASS.HudElementTeamPanelHandler then
        mod:hook(CLASS.HudElementTeamPanelHandler, "_add_panel",
            function(func, self_team_panel_handler, unique_id, ui_renderer, fixed_scenegraph_id)
                func(self_team_panel_handler, unique_id, ui_renderer, fixed_scenegraph_id)
                local panel_data_entry = self_team_panel_handler._player_panel_by_unique_id[unique_id]
                if panel_data_entry and panel_data_entry.panel then
                    apply_visibility_to_player_panel(panel_data_entry.panel)
                end
            end)
    end

    -- Apply static visibility (weapons, overcharge, etc.) once per UIHud instance
    mod:hook(CLASS.UIHud, "update", function(func, self_ui_hud_instance, dt, t, input_service)
        if not mod._ringhud_visibility_applied_to_hud[self_ui_hud_instance] then
            update_element_visibility()
            mod._ringhud_visibility_applied_to_hud[self_ui_hud_instance] = true
        end
        return func(self_ui_hud_instance, dt, t, input_service)
    end)

    -- Dynamic gating for Mission Objective Feed: evaluate EVERY draw
    if CLASS and CLASS.HudElementMissionObjectiveFeed then
        mod:hook(CLASS.HudElementMissionObjectiveFeed, "draw",
            function(func, self_element, dt, t, ui_renderer, render_settings, input_service)
                if _mission_objective_feed_should_hide() then
                    return -- suppress drawing entirely this frame
                end
                return func(self_element, dt, t, ui_renderer, render_settings, input_service)
            end)

        -- Belt-and-braces: prune stale names before vanilla sorts/aligns to prevent nil lookups.
        mod:hook(CLASS.HudElementMissionObjectiveFeed, "_align_objective_widgets",
            function(func, self_element, ...)
                local names = self_element._hud_objectives_names_array
                local map   = self_element._hud_objectives
                if names and map then
                    for i = #names, 1, -1 do
                        if map[names[i]] == nil then
                            table.remove(names, i)
                        end
                    end
                end
                return func(self_element, ...)
            end)

        -- Filter non-interesting rows when the feed is visible due to at least one interesting objective.
        mod:hook(CLASS.HudElementMissionObjectiveFeed, "update",
            function(func, self_element, dt, t, ui_renderer, render_settings, input_service)
                local do_filter = false
                if mod:is_enabled()
                    and mod._settings
                    and mod._settings.minimal_objective_feed_enabled
                    and not _mission_objective_feed_should_hide()
                    and not _has_active_event_objective()
                then
                    do_filter = true
                end

                local original_names = self_element._hud_objectives_names_array
                local filtered_names = nil
                local keep_set = nil

                if do_filter and original_names and self_element._hud_objectives then
                    local filtered = {}
                    local any = false
                    for i = 1, #original_names do
                        local name = original_names[i]
                        local row  = self_element._hud_objectives[name]
                        if _hud_row_is_interesting(row) then
                            any = true
                            filtered[#filtered + 1] = name
                        end
                    end

                    if any and #filtered < #original_names then
                        self_element._hud_objectives_names_array = filtered
                        filtered_names = filtered
                        keep_set = {}
                        for i = 1, #filtered do keep_set[filtered[i]] = true end
                    end
                end

                local ret = func(self_element, dt, t, ui_renderer, render_settings, input_service)

                if keep_set and self_element._objective_widgets_by_name then
                    for name, widget in pairs(self_element._objective_widgets_by_name) do
                        widget.visible = keep_set[name] == true
                    end
                    if self_element._hud_objectives_names_array == filtered_names then
                        self_element._hud_objectives_names_array = original_names
                    end
                    self_element._ringhud_forced_visibility = true
                else
                    if self_element._ringhud_forced_visibility and self_element._objective_widgets_by_name then
                        for _, widget in pairs(self_element._objective_widgets_by_name) do
                            widget.visible = true
                        end
                        self_element._ringhud_forced_visibility = false
                    end
                end

                return ret
            end)
    end
end

-- Called by RingHud.lua's single central on_setting_changed(...)
function VanillaHudManager.apply_settings(setting_id)
    -- Re-apply chat alignment live when either alignment key changes
    if setting_id == "chat_align_h" or setting_id == "chat_align_v" then
        local ce_mgr = Managers.ui and Managers.ui._constant_elements
        return
    end

    -- Existing visibility rules below
    local relevant_to_hiding = false
    local is_player_panel_setting = (setting_id == "hide_default_player")

    for _, rule in ipairs(RING_HUD_VISIBILITY_RULES) do
        if (setting_id == "charge_kills_enabled" and rule.id == "WeaponCounter") or
            (setting_id == "stamina_viz_threshold" and rule.id == "Blocking") or
            (setting_id == "peril_label_enabled" and rule.id == "Overcharge") or
            (setting_id == "hide_default_ability" and rule.id == "PlayerAbility") or
            (setting_id == "hide_default_weapons" and rule.id == "PlayerWeapons") or
            (is_player_panel_setting and (rule.id == "PersonalPlayerPanel" or rule.id == "PersonalPlayerPanelHub")) then
            relevant_to_hiding = true
            break
        end
    end

    if relevant_to_hiding then
        update_element_visibility()

        if is_player_panel_setting then
            local hud = Managers.ui and Managers.ui._hud
            local team_panel_handler_instance = hud and hud:element("HudElementTeamPanelHandler")
            if team_panel_handler_instance and team_panel_handler_instance._player_panels_array then
                for _, panel_data in ipairs(team_panel_handler_instance._player_panels_array) do
                    if panel_data and panel_data.panel then apply_visibility_to_player_panel(panel_data.panel) end
                end
            end
        end

        local current_hud_instance = Managers.ui and Managers.ui._hud
        if current_hud_instance then
            mod._ringhud_visibility_applied_to_hud[current_hud_instance] = nil
        end
    end
end

function VanillaHudManager.on_mod_disabled()
    reset_all_visibility_flags()

    local current_hud_instance = Managers.ui and Managers.ui._hud
    if current_hud_instance then
        mod._ringhud_visibility_applied_to_hud[current_hud_instance] = nil
    end
end

function VanillaHudManager.on_game_state_changed(status, state_name)
    if state_name == "StateLoading" and status == "enter" then
        local current_hud_instance = Managers.ui and Managers.ui._hud
        if current_hud_instance then
            mod._ringhud_visibility_applied_to_hud[current_hud_instance] = nil
        end
    end
end

function VanillaHudManager.on_all_mods_loaded() end

return VanillaHudManager
