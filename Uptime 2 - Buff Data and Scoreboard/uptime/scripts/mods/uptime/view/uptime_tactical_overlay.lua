-- File: uptime/scripts/mods/uptime/view/uptime_tactical_overlay.lua
local mod = get_mod("uptime"); if not mod then return end

if mod._uptime_tactical_overlay_loaded then
    return true
end

mod._uptime_tactical_overlay_loaded = true

local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")
local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local Text = mod:original_require("scripts/utilities/ui/text")
local WalletSettings = mod:original_require("scripts/settings/wallet_settings")

if type(mod.generate_live_scoreboard_display_values) ~= "function" then
    mod:io_dofile("uptime/scripts/mods/uptime/view/uptime_view_data_handler")
end

local player_slot_colors = UISettings and UISettings.player_slot_colors
local archetype_font_icon = UISettings and UISettings.archetype_font_icon

local CARD_WIDTH = 380
local CARD_HEIGHT = 350
local GRID_GAP_X = 24
local GRID_GAP_Y = 24
local CARD_PADDING = 12
local TITLE_HEIGHT = 34
local STAT_ROW_HEIGHT = 22
local TALENT_ICON_SIZE = 36
local TALENT_ICON_SPACING = 8
local WEAPON_WIDTH = 112
local WEAPON_HEIGHT = 38
local WEAPON_SPACING = 12
local MAX_TALENT_ICONS = 5
local MAX_WEAPON_ICONS = 2
local MAX_PLAYER_CARDS = 4

local PANEL_BACKGROUND_COLOR = Color.black(150, true)
local PANEL_BORDER_TOP_COLOR = Color.terminal_frame(220, true)
local PANEL_BORDER_BOTTOM_COLOR = Color.terminal_frame(180, true)
local STAT_ROW_BACKGROUND_COLOR = Color.black(100, true)
local STAT_ROW_EMPTY_BACKGROUND_COLOR = Color.black(90, true)
local STAT_ROW_HIGHLIGHT_BACKGROUND_COLOR = Color.ui_terminal(55, true)

local EXPEDITION_CURRENCY_ROWS = {
    {
        key = "expedition_loot",
        game_mode_function = "expedition_loot",
    },
    {
        key = "expedition_salvage",
        game_mode_function = "expedition_currency",
    },
}

local EXPEDITION_CURRENCY_ROW_COUNT = 2

local CATEGORY_METADATA = {
    Blitz = { frame = "square_frame", mask = "square_frame_mask" },
    Aura = { frame = "circular_frame", mask = "circular_frame_mask" },
    Ability = { frame = "hex_frame", mask = "hex_frame_mask" },
    Keystone = { frame = "circular_frame", mask = "circular_frame_mask" },
    Companion = { frame = "circular_frame", mask = "circular_frame_mask" },
}

local DEFAULT_SCREEN_SIZE = { 1920, 1080 }

local function scoreboard_stat_count()
    return mod.scoreboard_stat_definitions_n or 7
end

local function total_metric_row_count()
    return scoreboard_stat_count() + EXPEDITION_CURRENCY_ROW_COUNT
end

local function is_hub_game_mode(tactical_overlay)
    local tactical_overlay_game_mode_name = tactical_overlay and tactical_overlay._game_mode_name

    if tactical_overlay_game_mode_name == "hub" or tactical_overlay_game_mode_name == "prologue_hub" then
        return true
    end

    local game_mode_manager = Managers.state and Managers.state.game_mode

    if game_mode_manager and type(game_mode_manager.game_mode_name) == "function" then
        local game_mode_name = game_mode_manager:game_mode_name()

        return game_mode_name == "hub" or game_mode_name == "prologue_hub"
    end

    return false
end

local function tactical_scoreboard_enabled(tactical_overlay)
    if is_hub_game_mode(tactical_overlay) then
        return false
    end

    if type(mod.tactical_scoreboard_enabled) ~= "function" then
        return false
    end

    return mod.tactical_scoreboard_enabled()
end

local function make_widget(name, definition)
    local widget = UIWidget.init(name, definition)

    widget.alpha_multiplier = 1
    widget.dirty = true

    return widget
end

local function get_screen_size()
    local screen = UIWorkspaceSettings and UIWorkspaceSettings.screen
    local size = screen and screen.size

    return size or DEFAULT_SCREEN_SIZE
end

local function get_player_name(player)
    if not player then
        return nil
    end

    if type(player.name) == "function" then
        return player:name()
    end

    return player.name or player._name
end

local function get_sort_name(player)
    if not player then return "" end

    if type(player.account_id) == "function" then
        local account_id = player:account_id()
        if account_id and account_id ~= "" then
            return account_id
        end
    end

    return get_player_name(player) or ""
end

local function get_player_archetype_name(player)
    if not player then
        return nil
    end

    if type(player.archetype_name) == "function" then
        return player:archetype_name()
    end

    local profile = nil

    if type(player.profile) == "function" then
        profile = player:profile()
    else
        profile = player._profile
    end

    local archetype = profile and profile.archetype

    return archetype and (archetype.name or archetype.archetype_name)
end

local function get_is_human_controlled(player)
    if player and type(player.is_human_controlled) == "function" then
        return player:is_human_controlled()
    end

    return false
end

local function get_player_for_team_entry(team_entry)
    if not team_entry then
        return nil
    end

    local player_manager = Managers.player
    local players = player_manager and player_manager:players()

    if not players then
        return nil
    end

    for _, player in pairs(players) do
        if get_is_human_controlled(player) then
            local player_name = get_player_name(player)
            local archetype_name = get_player_archetype_name(player)

            if player_name == team_entry.name and (not team_entry.archetype or team_entry.archetype == archetype_name) then
                return player
            end
        end
    end

    return nil
end

local function get_peer_id(player)
    if not player then
        return nil
    end

    if type(player.peer_id) == "function" then
        return player:peer_id()
    end

    return player.peer_id
end

local function get_slot_color(team_entry)
    local player = get_player_for_team_entry(team_entry)
    local slot = player and type(player.slot) == "function" and player:slot()
    local slot_color = slot and player_slot_colors and player_slot_colors[slot]

    if slot_color then
        return { slot_color[1], slot_color[2], slot_color[3], slot_color[4] }
    end

    return Color.ui_grey_light(255, true)
end

local function truncated_name(name, max_length)
    name = name or "?"

    if string.len(name) > max_length then
        return string.sub(name, 1, max_length - 2) .. ".."
    end

    return name
end

local function set_text_style_color(widget, style_id, color)
    if widget and widget.style and widget.style[style_id] and color then
        widget.style[style_id].text_color = color
    end
end

local function set_rect_style_color(widget, style_id, color)
    if widget and widget.style and widget.style[style_id] and color then
        widget.style[style_id].color = color
    end
end

local function set_texture_alpha(widget, style_id, alpha)
    if widget and widget.style and widget.style[style_id] and widget.style[style_id].color then
        widget.style[style_id].color[1] = alpha
    end
end

local function hide_vanilla_expedition_currency_widget(tactical_overlay)
    local widgets_by_name = tactical_overlay and tactical_overlay._widgets_by_name
    local expedition_currency_widget = widgets_by_name and widgets_by_name.expedition_currency

    if expedition_currency_widget then
        expedition_currency_widget.visible = false
    end
end

local function is_expedition(tactical_overlay)
    if tactical_overlay and tactical_overlay._game_mode_name == "expedition" then
        return true
    end

    local game_mode_manager = Managers.state and Managers.state.game_mode

    if game_mode_manager and type(game_mode_manager.game_mode_name) == "function" then
        return game_mode_manager:game_mode_name() == "expedition"
    end

    return false
end

local function get_expedition_game_mode()
    local game_mode_manager = Managers.state and Managers.state.game_mode

    if game_mode_manager and type(game_mode_manager.game_mode) == "function" then
        return game_mode_manager:game_mode()
    end

    return nil
end

local function get_expedition_currency_value(game_mode, function_name, peer_id)
    local func = game_mode and game_mode[function_name]

    if type(func) == "function" and peer_id then
        return func(game_mode, peer_id) or 0
    end

    return 0
end

local function format_currency(value)
    if Text and type(Text.format_currency) == "function" then
        return Text.format_currency(value or 0)
    end

    return tostring(value or 0)
end

local function get_currency_label(currency_key)
    local wallet_setting = WalletSettings and WalletSettings[currency_key]
    local symbol = wallet_setting and wallet_setting.string_symbol or ""
    local display_name = wallet_setting and wallet_setting.display_name
    local label = display_name and Localize(display_name) or currency_key

    if symbol ~= "" then
        return symbol .. " " .. label
    end

    return label
end

local function build_expedition_currency_snapshot(tactical_overlay, team)
    if not is_expedition(tactical_overlay) then
        return nil
    end

    local game_mode = get_expedition_game_mode()

    if not game_mode then
        return nil
    end

    local values_by_index = {}
    local ranking_values = {}

    for i = 1, MAX_PLAYER_CARDS do
        local team_entry = team and team[i]
        local player = get_player_for_team_entry(team_entry)
        local peer_id = get_peer_id(player)
        local values = {}

        for j = 1, EXPEDITION_CURRENCY_ROW_COUNT do
            local row_definition = EXPEDITION_CURRENCY_ROWS[j]
            local value = get_expedition_currency_value(game_mode, row_definition.game_mode_function, peer_id)

            values[row_definition.key] = value

            local current_best = ranking_values[row_definition.key]

            if current_best == nil or current_best < value then
                ranking_values[row_definition.key] = value
            end
        end

        values_by_index[i] = values
    end

    return {
        values_by_index = values_by_index,
        ranking_values = ranking_values,
    }
end

local function capture_team_loadouts_once(tactical_overlay)
    if not tactical_overlay or tactical_overlay._uptime_tactical_scoreboard_loadouts_captured then
        return
    end

    if type(mod.capture_team_loadouts) == "function" then
        mod:capture_team_loadouts()
    end

    tactical_overlay._uptime_tactical_scoreboard_loadouts_captured = true
end

local function create_player_card_definition(card_index)
    local passes = {
        {
            pass_type = "rect",
            style_id = "card_background",
            style = {
                color = PANEL_BACKGROUND_COLOR,
                offset = { 0, 0, 10 },
            },
        },
        {
            pass_type = "rect",
            style_id = "card_border_top",
            style = {
                color = PANEL_BORDER_TOP_COLOR,
                size = { CARD_WIDTH, 2 },
                offset = { 0, 0, 20 },
            },
        },
        {
            pass_type = "rect",
            style_id = "card_border_bottom",
            style = {
                color = PANEL_BORDER_BOTTOM_COLOR,
                size = { CARD_WIDTH, 2 },
                offset = { 0, CARD_HEIGHT - 2, 20 },
            },
        },
        {
            pass_type = "text",
            value_id = "player_name",
            style_id = "player_name",
            value = "",
            style = {
                font_type = "proxima_nova_bold",
                font_size = 21,
                text_color = Color.ui_grey_light(255, true),
                offset = { CARD_PADDING, 2, 30 },
                size = { CARD_WIDTH - CARD_PADDING * 2, TITLE_HEIGHT },
                text_horizontal_alignment = "center",
                text_vertical_alignment = "center",
                drop_shadow = true,
            },
        },
    }

    local row_start_y = TITLE_HEIGHT + 6
    local label_width = 146
    local value_width = CARD_WIDTH - CARD_PADDING * 2 - label_width
    local row_count = total_metric_row_count()

    for i = 1, row_count do
        local y = row_start_y + (i - 1) * STAT_ROW_HEIGHT
        local bg_id = "stat_bg_" .. i
        local label_id = "stat_label_" .. i
        local value_id = "stat_value_" .. i

        passes[#passes + 1] = {
            pass_type = "rect",
            style_id = bg_id,
            style = {
                color = STAT_ROW_BACKGROUND_COLOR,
                size = { CARD_WIDTH - CARD_PADDING * 2, STAT_ROW_HEIGHT },
                offset = { CARD_PADDING, y, 15 },
            },
        }
        passes[#passes + 1] = {
            pass_type = "text",
            value_id = label_id,
            style_id = label_id,
            value = "",
            style = {
                font_type = "machine_medium",
                font_size = 16,
                text_color = Color.terminal_text_header(255, true),
                offset = { CARD_PADDING + 8, y, 30 },
                size = { label_width - 8, STAT_ROW_HEIGHT },
                text_horizontal_alignment = "left",
                text_vertical_alignment = "center",
                drop_shadow = true,
            },
        }
        passes[#passes + 1] = {
            pass_type = "text",
            value_id = value_id,
            style_id = value_id,
            value = "",
            style = {
                font_type = "machine_medium",
                font_size = 16,
                text_color = Color.ui_grey_light(255, true),
                offset = { CARD_PADDING + label_width, y, 30 },
                size = { value_width - 8, STAT_ROW_HEIGHT },
                text_horizontal_alignment = "right",
                text_vertical_alignment = "center",
                drop_shadow = true,
            },
        }
    end

    local talent_y = row_start_y + (row_count * STAT_ROW_HEIGHT) + 10
    local talent_total_width = MAX_TALENT_ICONS * TALENT_ICON_SIZE + (MAX_TALENT_ICONS - 1) * TALENT_ICON_SPACING
    local talent_start_x = (CARD_WIDTH - talent_total_width) * 0.5

    for i = 1, MAX_TALENT_ICONS do
        local icon_id = "talent_icon_" .. i
        local x = talent_start_x + (i - 1) * (TALENT_ICON_SIZE + TALENT_ICON_SPACING)

        passes[#passes + 1] = {
            pass_type = "texture",
            value_id = icon_id,
            style_id = icon_id,
            value = "content/ui/materials/frames/talents/talent_icon_container",
            style = {
                size = { TALENT_ICON_SIZE, TALENT_ICON_SIZE },
                offset = { x, talent_y, 30 },
                color = Color.white(0, true),
                material_values = {
                    frame = "content/ui/textures/frames/talents/circular_frame",
                    icon_mask = "content/ui/textures/frames/talents/circular_frame_mask",
                    icon = "",
                    gradient_map = "content/ui/textures/color_ramps/talent_default",
                    intensity = 0,
                    saturation = 1,
                },
            },
        }
    end

    local weapon_y = talent_y + TALENT_ICON_SIZE + 10
    local weapon_total_width = MAX_WEAPON_ICONS * WEAPON_WIDTH + (MAX_WEAPON_ICONS - 1) * WEAPON_SPACING
    local weapon_start_x = (CARD_WIDTH - weapon_total_width) * 0.5

    for i = 1, MAX_WEAPON_ICONS do
        local weapon_id = "weapon_icon_" .. i
        local x = weapon_start_x + (i - 1) * (WEAPON_WIDTH + WEAPON_SPACING)

        passes[#passes + 1] = {
            pass_type = "texture",
            value_id = weapon_id,
            style_id = weapon_id,
            value = "",
            style = {
                size = { WEAPON_WIDTH, WEAPON_HEIGHT },
                offset = { x, weapon_y, 30 },
                color = Color.white(0, true),
            },
        }
    end

    return UIWidget.create_definition(passes, "screen", nil, { CARD_WIDTH, CARD_HEIGHT })
end

local function create_player_card(card_index, x, y)
    local widget = make_widget(
        "uptime_tactical_scoreboard_card_" .. card_index,
        create_player_card_definition(card_index)
    )

    widget.offset = { x, y, 20 }

    return widget
end

local function build_overlay_panel(view, is_end_view)
    capture_team_loadouts_once(view)

    local screen_size = get_screen_size()
    local cards = {}

    if is_end_view then
        local total_width = MAX_PLAYER_CARDS * CARD_WIDTH + (MAX_PLAYER_CARDS - 1) * GRID_GAP_X
        local start_x = (screen_size[1] - total_width) * 0.5
        local start_y = mod.end_view_scoreboard_position == "up" and 50 or screen_size[2] - CARD_HEIGHT - 50

        for i = 1, MAX_PLAYER_CARDS do
            local x = start_x + (i - 1) * (CARD_WIDTH + GRID_GAP_X)
            local y = start_y
            cards[i] = create_player_card(i, x, y)
        end
        view._uptime_end_view_panel = cards
    else
        local grid_width = CARD_WIDTH * 2 + GRID_GAP_X
        local grid_height = CARD_HEIGHT * 2 + GRID_GAP_Y
        local start_x = (screen_size[1] - grid_width) * 0.5
        local start_y = (screen_size[2] - grid_height) * 0.5

        for i = 1, MAX_PLAYER_CARDS do
            local column = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local x = start_x + column * (CARD_WIDTH + GRID_GAP_X)
            local y = start_y + row * (CARD_HEIGHT + GRID_GAP_Y)

            cards[i] = create_player_card(i, x, y)
        end
        view._uptime_tactical_scoreboard_panel = cards
    end
end

local function clear_card(widget)
    if not widget then
        return
    end

    widget.content.player_name = ""

    for i = 1, total_metric_row_count() do
        widget.content["stat_label_" .. i] = ""
        widget.content["stat_value_" .. i] = ""
        set_rect_style_color(widget, "stat_bg_" .. i, STAT_ROW_EMPTY_BACKGROUND_COLOR)
    end

    for i = 1, MAX_TALENT_ICONS do
        local style = widget.style["talent_icon_" .. i]

        if style then
            style.color = Color.white(0, true)

            if style.material_values then
                style.material_values.icon = ""
            end
        end
    end

    for i = 1, MAX_WEAPON_ICONS do
        widget.content["weapon_icon_" .. i] = ""
        set_texture_alpha(widget, "weapon_icon_" .. i, 0)
    end

    widget.dirty = true
end

local function update_talent_icons(widget, icons)
    for i = 1, MAX_TALENT_ICONS do
        local icon_data = icons and icons[i]
        local style = widget.style["talent_icon_" .. i]
        local material_values = style and style.material_values

        if style then
            if icon_data and icon_data.icon and icon_data.icon ~= "" and material_values then
                local category = icon_data.category or "Ability"
                local metadata = CATEGORY_METADATA[category] or CATEGORY_METADATA.Ability

                style.color = Color.white(255, true)
                material_values.icon = icon_data.icon
                material_values.gradient_map = icon_data.gradient_map or "content/ui/textures/color_ramps/talent_default"
                material_values.frame = "content/ui/textures/frames/talents/" .. metadata.frame
                material_values.icon_mask = "content/ui/textures/frames/talents/" .. metadata.mask
            else
                style.color = Color.white(0, true)

                if material_values then
                    material_values.icon = ""
                end
            end
        end
    end
end

local function update_weapon_icons(widget, weapons)
    for i = 1, MAX_WEAPON_ICONS do
        local weapon_data = weapons and weapons[i]
        local icon = weapon_data and weapon_data.icon or ""

        widget.content["weapon_icon_" .. i] = icon or ""
        set_texture_alpha(widget, "weapon_icon_" .. i, icon ~= "" and 255 or 0)
    end
end

local function update_expedition_currency_rows(widget, first_row_index, expedition_snapshot, player_index)
    local values = expedition_snapshot and expedition_snapshot.values_by_index and
        expedition_snapshot.values_by_index[player_index]
    local ranking_values = expedition_snapshot and expedition_snapshot.ranking_values

    for i = 1, EXPEDITION_CURRENCY_ROW_COUNT do
        local row_index = first_row_index + i - 1
        local row_definition = EXPEDITION_CURRENCY_ROWS[i]
        local value = values and values[row_definition.key]

        if value ~= nil then
            local ranked_value = ranking_values and ranking_values[row_definition.key]
            local is_ranked = ranked_value ~= nil and ranked_value > 0 and value == ranked_value

            widget.content["stat_label_" .. row_index] = get_currency_label(row_definition.key)
            widget.content["stat_value_" .. row_index] = format_currency(value)

            set_rect_style_color(
                widget,
                "stat_bg_" .. row_index,
                is_ranked and STAT_ROW_HIGHLIGHT_BACKGROUND_COLOR or STAT_ROW_BACKGROUND_COLOR
            )
            set_text_style_color(widget, "stat_value_" .. row_index, Color.ui_grey_light(255, true))
        else
            widget.content["stat_label_" .. row_index] = ""
            widget.content["stat_value_" .. row_index] = ""
            set_rect_style_color(widget, "stat_bg_" .. row_index, STAT_ROW_EMPTY_BACKGROUND_COLOR)
        end
    end
end

local function update_card(widget, team_entry, expedition_snapshot, player_index)
    if not widget then
        return
    end

    if not team_entry then
        clear_card(widget)

        return
    end

    local slot_color = get_slot_color(team_entry)
    local name = truncated_name(team_entry.name, 24)
    local archetype_icon = team_entry.archetype and archetype_font_icon and
        archetype_font_icon[team_entry.archetype]

    if archetype_icon then
        name = archetype_icon .. " " .. name
    end

    widget.content.player_name = name
    set_text_style_color(widget, "player_name", slot_color)

    local stat_rows = team_entry.stat_rows or {}
    local stat_rows_n = team_entry.stat_rows_n or #stat_rows
    local stat_count = scoreboard_stat_count()

    for i = 1, stat_count do
        local row = i <= stat_rows_n and stat_rows[i] or nil

        if row then
            widget.content["stat_label_" .. i] = row.label or row.key or ""
            widget.content["stat_value_" .. i] = row.value_str or "0"

            set_rect_style_color(
                widget,
                "stat_bg_" .. i,
                row.is_ranked and STAT_ROW_HIGHLIGHT_BACKGROUND_COLOR or STAT_ROW_BACKGROUND_COLOR
            )

            set_text_style_color(widget, "stat_value_" .. i,
                row.is_total and Color.ui_orange_light(255, true) or Color.ui_grey_light(255, true))
        else
            widget.content["stat_label_" .. i] = ""
            widget.content["stat_value_" .. i] = ""
            set_rect_style_color(widget, "stat_bg_" .. i, STAT_ROW_EMPTY_BACKGROUND_COLOR)
        end
    end

    update_expedition_currency_rows(widget, stat_count + 1, expedition_snapshot, player_index)
    update_talent_icons(widget, team_entry.loadout_icons)
    update_weapon_icons(widget, team_entry.loadout_weapons)

    widget.dirty = true
end

local function refresh_overlay_panel(view, is_end_view)
    local panel = is_end_view and view._uptime_end_view_panel or view._uptime_tactical_scoreboard_panel

    if not panel then
        return
    end

    if type(mod.generate_live_scoreboard_display_values) ~= "function" then
        return
    end

    local display_values = mod:generate_live_scoreboard_display_values()
    local team = display_values and display_values.team or {}

    table.sort(team, function(a, b)
        local dmg_a = a.raw_total or 0
        local dmg_b = b.raw_total or 0

        if dmg_a == dmg_b then
            local name_a = a.name or ""
            local name_b = b.name or ""
            return name_a < name_b
        end
        return dmg_a > dmg_b
    end)

    local expedition_snapshot = build_expedition_currency_snapshot(view, team)

    for i = 1, MAX_PLAYER_CARDS do
        update_card(panel[i], team[i], expedition_snapshot, i)
    end
end

mod:hook_safe(CLASS.HudElementTacticalOverlay, "_update_materials_collected", function(self, ui_renderer)
    if tactical_scoreboard_enabled(self) then
        hide_vanilla_expedition_currency_widget(self)
    end
end)

mod:hook(CLASS.HudElementTacticalOverlay, "_draw_widgets",
    function(func, self, dt, t, input_service, ui_renderer, render_settings, ...)
        local active = self._active
        local enabled = tactical_scoreboard_enabled(self)
        local panel = self._uptime_tactical_scoreboard_panel

        if enabled and active then
            hide_vanilla_expedition_currency_widget(self)
        end

        if enabled and active and not panel then
            build_overlay_panel(self, false)
            panel = self._uptime_tactical_scoreboard_panel
        end

        if enabled and active and panel then
            refresh_overlay_panel(self, false)
        end

        if (not enabled or not active) and panel then
            self._uptime_tactical_scoreboard_panel = nil
            self._uptime_tactical_scoreboard_loadouts_captured = nil
        end

        func(self, dt, t, input_service, ui_renderer, render_settings, ...)

        if enabled and active and self._uptime_tactical_scoreboard_panel then
            local alpha_multiplier = self._alpha_multiplier or 0

            for i = 1, MAX_PLAYER_CARDS do
                local widget = self._uptime_tactical_scoreboard_panel[i]

                if widget then
                    widget.alpha_multiplier = alpha_multiplier
                    UIWidget.draw(widget, ui_renderer)
                end
            end
        end
    end)

mod:hook(CLASS.EndView, "_draw_widgets",
    function(func, self, dt, t, input_service, ui_renderer, render_settings, ...)
        local enabled = type(mod.end_view_scoreboard_enabled) == "function" and mod.end_view_scoreboard_enabled()
        local panel = self._uptime_end_view_panel

        if enabled and not panel then
            build_overlay_panel(self, true)
            panel = self._uptime_end_view_panel
        end

        if enabled and panel then
            refresh_overlay_panel(self, true)
        end

        if not enabled and panel then
            self._uptime_end_view_panel = nil
            self._uptime_tactical_scoreboard_loadouts_captured = nil
        end

        func(self, dt, t, input_service, ui_renderer, render_settings, ...)

        if enabled and self._uptime_end_view_panel then
            for i = 1, MAX_PLAYER_CARDS do
                local widget = self._uptime_end_view_panel[i]

                if widget then
                    widget.alpha_multiplier = 1
                    UIWidget.draw(widget, ui_renderer)
                end
            end
        end
    end)

mod:hook(CLASS.EndView, "_setup_spawn_slots", function(func, self, players, ...)
    local enabled = type(mod.end_view_scoreboard_enabled) == "function" and mod.end_view_scoreboard_enabled()
    if not enabled then
        return func(self, players, ...)
    end

    local damage_data = type(mod.get_current_damage_tracking) == "function" and mod:get_current_damage_tracking() or {}

    local sorted_players = {}
    for _, player in pairs(players) do
        table.insert(sorted_players, player)
    end

    table.sort(sorted_players, function(a, b)
        local id_a = get_sort_name(a)
        local id_b = get_sort_name(b)

        local dmg_a = damage_data[id_a] and damage_data[id_a].total or 0
        local dmg_b = damage_data[id_b] and damage_data[id_b].total or 0

        if dmg_a == dmg_b then
            return id_a < id_b
        end
        return dmg_a > dmg_b
    end)

    return func(self, sorted_players, ...)
end)

return true
