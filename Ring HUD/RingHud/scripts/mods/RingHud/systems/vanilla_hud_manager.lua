-- File: RingHud/scripts/mods/RingHud/systems/vanilla_hud_manager.lua
local mod = get_mod("RingHud")
if not mod then
    return
end

local UIWidget                         = require("scripts/managers/ui/ui_widget")
local UIFontSettings                   = require("scripts/managers/ui/ui_font_settings")

mod.vanilla_hud_manager                = mod.vanilla_hud_manager or {}
local VanillaHudManager                = mod.vanilla_hud_manager

local Status                           = mod.team_status
    or mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_icon")
local C                                = mod:io_dofile("RingHud/scripts/mods/RingHud/systems/constants")
local TeamPockets                      = mod.team_pocketables
    or mod:io_dofile("RingHud/scripts/mods/RingHud/team/team_pocketables")

local Streamliner                      = mod.objective_feed_streamliner
    or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/objective_feed_streamliner")

-- Shared HUD helpers (centralised)
local HudUtils                         = mod.utils
    or mod:io_dofile("RingHud/scripts/mods/RingHud/systems/utils")
local get_current_hud_instances        = HudUtils.get_current_hud_instances
local resolve_element_instance         = HudUtils.resolve_element_instance

-- ─────────────────────────────────────────────────────────────────────────────
-- RingHud visibility logic
-- ─────────────────────────────────────────────────────────────────────────────

-- Shared cross-file state (weak keys to avoid leaks)
mod._ringhud_hooked_elements           = mod._ringhud_hooked_elements
    or setmetatable({}, { __mode = "k" })
mod._ringhud_visibility_applied_to_hud = mod._ringhud_visibility_applied_to_hud
    or setmetatable({}, { __mode = "k" })

local RING_HUD_VISIBILITY_RULES        = {
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
    if not panel_instance or not panel_instance.__class_name then
        return
    end

    local panel_class_name = panel_instance.__class_name
    local should_hide_panel = false

    if mod:is_enabled()
        and (panel_class_name == "HudElementPersonalPlayerPanel"
            or panel_class_name == "HudElementPersonalPlayerPanelHub")
    then
        if mod._settings.hide_default_player == true then
            should_hide_panel = true
        end
    end

    panel_instance._is_hidden_by_ringhud = should_hide_panel

    if should_hide_panel and not mod._ringhud_hooked_elements[panel_instance] then
        local original_draw_func = panel_instance.draw

        if type(original_draw_func) == "function" then
            mod:hook(panel_instance, "draw", function(func_ref, self_element, ...)
                if self_element._is_hidden_by_ringhud then
                    return
                end

                return func_ref(self_element, ...)
            end)

            mod._ringhud_hooked_elements[panel_instance] = true
        end
    end
end

local function update_element_visibility()
    local hud, const = get_current_hud_instances()
    if not hud and not const then
        return
    end

    for _, rule in ipairs(RING_HUD_VISIBILITY_RULES) do
        if rule.id == "PersonalPlayerPanel" or rule.id == "PersonalPlayerPanelHub" then
            goto continue_rule_loop
        end

        local element_instance = resolve_element_instance(hud, const, rule.class_name)
        if element_instance then
            element_instance._is_hidden_by_ringhud =
                (mod:is_enabled() and rule.condition_func()) or false

            if not mod._ringhud_hooked_elements[element_instance] then
                if type(element_instance.draw) == "function" then
                    mod:hook(element_instance, "draw", function(func_ref, self_element, ...)
                        if self_element._is_hidden_by_ringhud then
                            return
                        end

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
    if not hud and not const then
        return
    end

    for _, rule in ipairs(RING_HUD_VISIBILITY_RULES) do
        local inst = resolve_element_instance(hud, const, rule.class_name)
        if inst then
            inst._is_hidden_by_ringhud = false
        end
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

-- Thin vanilla team panel helper
function VanillaHudManager.apply_team_panel_thin_styles(element_instance)
    if not (element_instance and mod._settings) then
        return
    end

    local mode = mod._settings.team_hud_mode

    -- Only the remaining explicit "thin" mode matters now.
    if mode ~= "team_hud_floating_thin" then
        return
    end

    local widgets_by_name = element_instance._widgets_by_name
    if not widgets_by_name then
        return
    end

    local function _hide(widget_name, style_id)
        local widget = widgets_by_name[widget_name]

        if widget and widget.style then
            local style = widget.style[style_id]

            if style and style.visible ~= false then
                style.visible = false
                widget.dirty = true
            end
        end
    end

    _hide("coherency_indicator", "texture")
    _hide("panel_background", "background")
    _hide("player_icon", "texture")

    -- Enforce slot coloring on player name
    if mod.team_slot_tint_argb then
        local player = element_instance._player
            or (element_instance._data and element_instance._data.player)

        if player then
            local name_widget = widgets_by_name["player_name"]

            if name_widget and name_widget.style and name_widget.style.text then
                local tint = mod.team_slot_tint_argb(player, nil)
                local tc = name_widget.style.text.text_color

                if tc and tint then
                    if tc[1] ~= tint[1]
                        or tc[2] ~= tint[2]
                        or tc[3] ~= tint[3]
                        or tc[4] ~= tint[4]
                    then
                        tc[1] = tint[1]
                        tc[2] = tint[2]
                        tc[3] = tint[3]
                        tc[4] = tint[4]
                        name_widget.dirty = true
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Hooks
-------------------------------------------------------------------------------

function VanillaHudManager.init()
    -- [NEW] Inject ammo text widget into vanilla team panel definitions
    mod:hook_require("scripts/ui/hud/elements/team_player_panel/hud_element_team_player_panel_definitions",
        function(definitions)
            local UIWidget = require("scripts/managers/ui/ui_widget")

            if definitions and definitions.widget_definitions then
                definitions.widget_definitions.ringhud_ammo_text = UIWidget.create_definition({
                    {
                        value_id = "text",
                        style_id = "text",
                        pass_type = "text",
                        value = "",
                        style = {
                            vertical_alignment = "center",
                            horizontal_alignment = "left",
                            text_vertical_alignment = "center",
                            text_horizontal_alignment = "left",
                            size = { 100, 20 },
                            offset = { 80, -16, 3 },
                            font_type = "proxima_nova_bold",
                            font_size = 16,
                            text_color = mod.PALETTE_ARGB255.GENERIC_WHITE,
                            drop_shadow = true,
                            visible = false
                        },
                    },
                }, "toughness_bar")
            end
        end)

    -- Hook team panel creation once so we can hide the vanilla panel when requested
    if CLASS and CLASS.HudElementTeamPanelHandler then
        mod:hook(CLASS.HudElementTeamPanelHandler, "_add_panel",
            function(func, self_team_panel_handler, unique_id, ui_renderer, fixed_scenegraph_id)
                func(self_team_panel_handler, unique_id, ui_renderer, fixed_scenegraph_id)

                local panel_data_entry = self_team_panel_handler._player_panel_by_unique_id
                    and self_team_panel_handler._player_panel_by_unique_id[unique_id]

                if panel_data_entry and panel_data_entry.panel then
                    apply_visibility_to_player_panel(panel_data_entry.panel)
                end
            end
        )
    end

    -- Hook vanilla team panel status icon update to inject RingHud icons
    if CLASS and CLASS.HudElementTeamPlayerPanel then
        mod:hook(CLASS.HudElementTeamPlayerPanel, "_set_status_icon",
            function(func, self, status_icon, status_color, ui_renderer)
                local s = mod._settings

                if s then
                    local icon_mode = s.team_name_icon
                    local hud_mode = s.team_hud_mode

                    -- Updated logic: check for 'status1'
                    local special_icon = icon_mode
                        and string.find(icon_mode, "status1")

                    -- Only care about modes where vanilla panels are actually visible.
                    local target_hud_mode =
                        (hud_mode == "team_hud_disabled")
                        or (hud_mode == "team_hud_floating_vanilla")
                        or (hud_mode == "team_hud_floating_thin")

                    if special_icon and target_hud_mode then
                        local player = self._player
                            or (self._data and self._data.player)
                        local unit = player and player.player_unit

                        if unit then
                            local kind = Status.for_unit(unit)

                            if kind then
                                local mat = C.STATUS_ICON_MATERIALS
                                    and C.STATUS_ICON_MATERIALS[kind]

                                if mat then
                                    status_icon = mat
                                end
                            end
                        end
                    end
                end

                return func(self, status_icon, status_color, ui_renderer)
            end
        )

        mod:hook(CLASS.HudElementTeamPlayerPanel, "update",
            function(func, self, ...)
                local ret = func(self, ...)

                -- 1. Existing Pocketable Tinting
                if TeamPockets and TeamPockets.apply_vanilla_tints then
                    TeamPockets.apply_vanilla_tints(self)
                end

                local s = mod._settings

                if s and s.team_hud_mode == "team_hud_floating_thin" then
                    local widgets = self._widgets_by_name
                    local player = self._player or (self._data and self._data.player)

                    -- 2. Ammo Logic
                    if s.team_munitions ~= "team_munitions_disabled" then
                        -- A. Disable Vanilla Icon
                        if widgets.ammo_status then
                            widgets.ammo_status.visible = false
                            widgets.ammo_status.dirty = true
                        end

                        -- B. Update Custom Text
                        -- TODO How much of this is duplication of team_ammo.lua or some other file?
                        local ammo_text_widget = widgets.ringhud_ammo_text
                        if ammo_text_widget then
                            local content = ammo_text_widget.content
                            local style = ammo_text_widget.style.text
                            local unit = player and player.player_unit

                            local text_to_show = ""
                            local color_to_use = mod.PALETTE_ARGB255.GENERIC_WHITE

                            if unit and Unit.alive(unit) then
                                local unit_data = ScriptUnit.has_extension(unit, "unit_data_system") and
                                    ScriptUnit.extension(unit, "unit_data_system")
                                if unit_data then
                                    local comp = unit_data:read_component("slot_secondary")
                                    if comp then
                                        local cur = HudUtils.sum_ammo_field(comp.current_ammunition_reserve)
                                        local max = HudUtils.sum_ammo_field(comp.max_ammunition_reserve)

                                        if max > 0 then
                                            local f = math.clamp(cur / max, 0, 1)
                                            text_to_show = string.format("%.0f%%", f * 100)

                                            if f >= 0.85 then
                                                color_to_use = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_HIGH
                                            elseif f >= 0.65 then
                                                color_to_use = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_H
                                            elseif f >= 0.45 then
                                                color_to_use = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_MEDIUM_L
                                            elseif f >= 0.25 then
                                                color_to_use = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_LOW
                                            else
                                                color_to_use = mod.PALETTE_ARGB255.AMMO_TEXT_COLOR_CRITICAL
                                            end
                                        end
                                    end
                                end
                            end

                            if content.text ~= text_to_show then
                                content.text = text_to_show
                                ammo_text_widget.dirty = true
                            end

                            if HudUtils.set_style_text_color(style, color_to_use) then
                                ammo_text_widget.dirty = true
                            end

                            if style.visible ~= (text_to_show ~= "") then
                                style.visible = (text_to_show ~= "")
                                ammo_text_widget.dirty = true
                            end
                        end
                    end

                    -- 3. Throwable Hiding Logic
                    local throwable_widget = widgets.throwable
                    -- Only check if currently visible (don't force visible if vanilla hid it)
                    if throwable_widget and throwable_widget.visible then
                        local should_hide = false

                        -- Condition A: Psyker Archetype
                        if player and player.archetype_name and player:archetype_name() == "psyker" then
                            should_hide = true
                        end

                        -- Condition B: Specific Icon
                        if not should_hide then
                            local tex = throwable_widget.content.texture
                            if tex == "content/ui/materials/icons/throwables/hud/small/party_non_grenade" then
                                should_hide = true
                            end
                        end

                        if should_hide then
                            throwable_widget.visible = false
                            throwable_widget.dirty = true
                        end
                    end
                end

                return ret
            end
        )
    end

    -- Apply static visibility (weapons, overcharge, etc.) once per UIHud instance
    mod:hook(CLASS.UIHud, "update",
        function(func, self_ui_hud_instance, dt, t, input_service)
            if not mod._ringhud_visibility_applied_to_hud[self_ui_hud_instance] then
                update_element_visibility()
                mod._ringhud_visibility_applied_to_hud[self_ui_hud_instance] = true
            end

            return func(self_ui_hud_instance, dt, t, input_service)
        end
    )

    -- Delegate to the objective feed streamliner for minimal objective / declutter logic
    if Streamliner and Streamliner.init then
        Streamliner.init()
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
        if (setting_id == "charge_kills_enabled" and rule.id == "WeaponCounter")
            or (setting_id == "stamina_viz_threshold" and rule.id == "Blocking")
            or (setting_id == "peril_label_enabled" and rule.id == "Overcharge")
            or (setting_id == "hide_default_ability" and rule.id == "PlayerAbility")
            or (setting_id == "hide_default_weapons" and rule.id == "PlayerWeapons")
            or (is_player_panel_setting
                and (rule.id == "PersonalPlayerPanel"
                    or rule.id == "PersonalPlayerPanelHub"))
        then
            relevant_to_hiding = true
            break
        end
    end

    if relevant_to_hiding then
        update_element_visibility()

        if is_player_panel_setting then
            local hud = Managers.ui and Managers.ui._hud
            local team_panel_handler_instance = hud
                and hud:element("HudElementTeamPanelHandler")

            if team_panel_handler_instance
                and team_panel_handler_instance._player_panels_array
            then
                for _, panel_data in ipairs(team_panel_handler_instance._player_panels_array) do
                    if panel_data and panel_data.panel then
                        apply_visibility_to_player_panel(panel_data.panel)
                    end
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
