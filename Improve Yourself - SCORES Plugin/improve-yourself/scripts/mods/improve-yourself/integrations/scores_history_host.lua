local mod = get_mod("improve-yourself")
local scoreboard = get_mod("scores")
if not scoreboard or mod._scores_history_host_installed then
    return mod
end
mod._scores_history_host_installed = true

local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local SCORES_HISTORY_DEFINITIONS = "scores/scripts/mods/scores/views/history/history_view_definitions"
local SCORES_VIEW_SETTINGS = "scores/scripts/mods/scores/views/scoreboard/scoreboard_view_settings"
local IY_DEFINITIONS = "improve-yourself/scripts/mods/improve-yourself/views/meta/improve_yourself_view_definitions"

-- Scores keeps ownership of the History view, selected entry, player
-- header, numeric rows, deletion, scrolling, and navigation. Improve Yourself
-- contributes only the fixed visual widgets that replace the numeric rows.
local history_draw_widgets = {
    "compact_defense_prototype",
    "compact_offense_prototype",
    "compact_team",
}

local history_role_widgets = {
    "compact_player_1",
    "compact_player_2",
    "compact_player_3",
    "compact_player_4",
}

local scores_view_settings = scoreboard:io_dofile(SCORES_VIEW_SETTINGS)
local scores_player_header_width = tonumber(scores_view_settings and scores_view_settings.scoreboard_column_header_width) or 282
local scores_player_column_width = tonumber(scores_view_settings and scores_view_settings.scoreboard_column_width) or 172
-- The role pass is centered at x=90 inside its 180 px widget (4 px inset plus
-- half of its 172 px text area). Scores centers each native name at half of
-- its 172 px player column. Subtract the difference so both centers coincide.
local history_role_center_inset = 4

-- History uses Scores' own panel and player header. The Victory Board
-- definitions deliberately live at very high Z depths to beat mission-reward
-- UI, but inheriting those depths here puts the native player tooltip behind
-- the visual bands. Rebase only the three History bands into the gap between
-- Scores' panel background and its player-header/tooltip passes.
local history_band_z = 60
-- The expanded Teamplay band ends 626 px below scoreboard_rows. Leave
-- room for Scores' 20 px row inset and its lower frame instead of allowing a
-- short default row selection to collapse the frame through our widgets.
local history_bars_min_frame_height = 682

-- Darktide wraps widget/scenegraph lookup tables in a strict metatable. A
-- normal lookup for a custom widget that has not been merged yet raises an
-- error instead of returning nil, so every optional hosted lookup must bypass
-- that wrapper while Scores is constructing the History view.
local function optional_field(container, name)
    return type(container) == "table" and rawget(container, name) or nil
end

local function hosted_widget(view, name)
    return optional_field(view and view._widgets_by_name, name)
end

local function initial_history_mode()
    return mod:get("history_start_view") == "numbers" and "numbers" or "bars"
end

local function merge_definitions(definitions)
    if type(definitions) ~= "table" then
        return definitions
    end

    local iy = mod:io_dofile(IY_DEFINITIONS)
    if type(iy) ~= "table" then
        return definitions
    end

    definitions.scenegraph_definition = definitions.scenegraph_definition or {}
    definitions.widget_definitions = definitions.widget_definitions or {}

    -- render_victory_host uses the hidden compact widgets as calculation
    -- helpers, so host the complete fixed set but draw only the three bands.
    for name, node in pairs(iy.scenegraph_definition or {}) do
        if string.sub(name, 1, 8) == "compact_" then
            definitions.scenegraph_definition[name] = table.clone(node)
        end
    end
    for _, name in ipairs(mod.victory_host_compact_widgets or {}) do
        local widget = iy.widget_definitions and iy.widget_definitions[name]
        if widget then
            definitions.widget_definitions[name] = table.clone(widget)
        end
    end

    -- Fit the established 970 px Victory layout inside Scores'
    -- 1000 px table. The native player header occupies the first 98 px.
    local scenegraph = definitions.scenegraph_definition
    local compact_panel = optional_field(scenegraph, "compact_panel")
    local compact_defense = optional_field(scenegraph, "compact_defense_prototype")
    local compact_offense = optional_field(scenegraph, "compact_offense_prototype")
    local compact_team = optional_field(scenegraph, "compact_team")
    if not compact_panel or not compact_defense or not compact_offense or not compact_team then
        mod:error("Improve Yourself History host could not merge its compact scenegraph nodes.")
        return definitions
    end

    compact_panel.parent = "scoreboard_rows"
    compact_panel.vertical_alignment = "top"
    compact_panel.horizontal_alignment = "center"
    compact_panel.position = {0, 0, 0}
    compact_panel.size = {1000, 725}
    compact_defense.position = {15, 112, history_band_z}
    compact_offense.position = {15, 324, history_band_z}
    compact_team.position = {15, 536, history_band_z}
    for index, name in ipairs(history_role_widgets) do
        local node = optional_field(scenegraph, name)
        if node and node.position then
            node.position[1] = scores_player_header_width
                + scores_player_column_width * (index - 1)
                - history_role_center_inset
            node.position[3] = history_band_z
        end
    end

    definitions._iy_history_host_merged = true
    return definitions
end

if type(mod.register_scores_definition_merger) == "function" then
    mod.register_scores_definition_merger(
        SCORES_HISTORY_DEFINITIONS,
        "history_host",
        merge_definitions
    )
else
    mod:error("Improve Yourself History host could not register its Scores definition merger.")
end

local function set_compact_visibility(view, visible)
    for _, name in ipairs(mod.victory_host_compact_widgets or {}) do
        local widget = hosted_widget(view, name)
        if widget then
            widget.visible = visible == true
        end
    end
end

local function compact_widgets_exist(view)
    for _, name in ipairs(mod.victory_host_compact_widgets or {}) do
        if not hosted_widget(view, name) then
            return false
        end
    end
    return true
end

local function current_frame_height(view)
    local scoreboard_node = view and view._ui_scenegraph and view._ui_scenegraph.scoreboard
    return scoreboard_node and scoreboard_node.size and tonumber(scoreboard_node.size[2]) or nil
end

-- Scores owns dynamic History sizing. Cache its native height for the selected
-- entry, impose only our bars-view minimum, and restore the native height when
-- the user switches back to numerical rows.
local function set_history_frame_mode(view, bars)
    if not view or type(scoreboard.adjust_size) ~= "function" then return end
    local native_height = tonumber(view._iy_history_native_frame_height) or current_frame_height(view)
    if not native_height then return end

    local target_height = bars and math.max(native_height, history_bars_min_frame_height) or native_height
    scoreboard:adjust_size(
        math.max(0, target_height - 55),
        view.scoreboard_widget,
        view._ui_scenegraph,
        view.row_widgets
    )
end

local function render_selected_entry(view)
    if type(view.entry) ~= "table" or not compact_widgets_exist(view) then
        view._iy_history_bars_ready = false
        return false
    end

    -- The host can attach after Scores has already opened an entry. Capture
    -- that native height here as well as in the open-entry wrapper so the
    -- first Numbers toggle always has the correct value to restore.
    view._iy_history_native_frame_height = view._iy_history_native_frame_height
        or current_frame_height(view)

    view._iy_history_bars_ready = mod.render_victory_host
        and mod.render_victory_host(view, view.entry)
        or false
    if view._iy_history_bars_ready then
        -- populate_compact_players applies Victory's adaptive player spacing
        -- through widget offsets. History uses Scores' fixed native columns,
        -- whose scenegraph positions were aligned above, so discard only the
        -- inherited horizontal offset after each population pass.
        for _, name in ipairs(history_role_widgets) do
            local widget = hosted_widget(view, name)
            if widget and widget.offset then
                widget.offset[1] = 0
            end
        end
        set_history_frame_mode(view, true)
    end
    set_compact_visibility(view, false)
    return view._iy_history_bars_ready
end

local function draw_bars(view, dt, input_service)
    if not view._iy_history_bars_ready then
        return
    end

    local renderer = view._ui_renderer
    if not renderer or not view._ui_scenegraph then
        return
    end

    UIRenderer.begin_pass(renderer, view._ui_scenegraph, input_service, dt, view._render_settings)
    for _, name in ipairs(history_draw_widgets) do
        local widget = hosted_widget(view, name)
        if widget then
            widget.visible = true
            UIWidget.draw(widget, renderer)
            widget.visible = false
        end
    end

    -- Scores owns the History player icons, names, hover regions, and
    -- tooltips. Draw only the role text from our populated player widgets so
    -- the established "Acted As" recommendation returns beneath each native
    -- name without duplicating or intercepting the header.
    for _, name in ipairs(history_role_widgets) do
        local widget = hosted_widget(view, name)
        if widget then
            local icon = widget.content.icon
            local player_name = widget.content.name
            widget.content.icon = ""
            widget.content.name = ""
            widget.visible = true
            UIWidget.draw(widget, renderer)
            widget.visible = false
            widget.content.icon = icon
            widget.content.name = player_name
        end
    end
    UIRenderer.end_pass(renderer)
end

local function add_toggle_entries(view)
    local legend = view._input_legend_element
    if not legend or view._iy_history_legend_element == legend then
        return
    end

    view._iy_history_legend_element = legend
    legend:add_entry(
        "loc_improve_yourself_show_numbers",
        "hotkey_menu_special_1",
        function()
            return type(view.entry) == "table" and view._iy_history_mode == "bars"
        end,
        function()
            view._iy_history_mode = "numbers"
            set_history_frame_mode(view, false)
        end,
        "left_alignment"
    )
    legend:add_entry(
        "loc_improve_yourself_show_bars",
        "hotkey_menu_special_1",
        function()
            return type(view.entry) == "table" and view._iy_history_mode == "numbers"
        end,
        function()
            view._iy_history_mode = "bars"
            render_selected_entry(view)
        end,
        "left_alignment"
    )
end

local function attach_view(view)
    if not view or view._iy_history_host_attached or not compact_widgets_exist(view) then
        return false
    end

    view._iy_history_host_attached = true
    view._iy_history_mode = initial_history_mode()
    set_compact_visibility(view, false)

    local original_open_entry_preview = view._open_entry_preview
    view._open_entry_preview = function(history_view, widget)
        local previous_entry = history_view.entry
        local result = original_open_entry_preview(history_view, widget)
        if history_view.entry ~= previous_entry or not history_view._iy_history_native_frame_height then
            history_view._iy_history_native_frame_height = current_frame_height(history_view)
        end
        history_view._iy_history_mode = initial_history_mode()
        if history_view._iy_history_mode == "bars" then
            render_selected_entry(history_view)
        else
            history_view._iy_history_bars_ready = false
            set_compact_visibility(history_view, false)
        end
        return result
    end

    local original_clear_preview_widgets = view._clear_preview_widgets
    view._clear_preview_widgets = function(history_view, ...)
        set_history_frame_mode(history_view, false)
        history_view._iy_history_native_frame_height = nil
        history_view._iy_history_bars_ready = false
        set_compact_visibility(history_view, false)
        return original_clear_preview_widgets(history_view, ...)
    end

    local original_draw_preview_rows = view._draw_preview_rows
    view._draw_preview_rows = function(history_view, dt, input_service)
        if history_view._iy_history_mode ~= "bars" then
            return original_draw_preview_rows(history_view, dt, input_service)
        end

        -- Let Scores draw and handle only its native player header.
        -- All numeric/section rows retain their original visibility afterward.
        local visibility = {}
        for index, widget in ipairs(history_view.row_widgets or {}) do
            visibility[index] = widget.visible
            widget.visible = widget.name == "scoreboard_row_player_header"
        end
        -- Draw the visual bands without an input service, so their hosted pass
        -- cannot consume or disturb the player's mouseover. Scores then
        -- draws its untouched header once, last, with the real input service;
        -- its native tooltip therefore remains interactive and above the bars.
        draw_bars(history_view, dt, nil)
        original_draw_preview_rows(history_view, dt, input_service)
        for index, widget in ipairs(history_view.row_widgets or {}) do
            widget.visible = visibility[index]
        end
    end

    add_toggle_entries(view)
    if type(view.entry) == "table" and view._iy_history_mode == "bars" then
        render_selected_entry(view)
    end
    return true
end

function mod.poll_scores_history_host()
    local ui = scoreboard.ui_manager or mod.ui_manager or (Managers and Managers.ui)
    if not ui or type(ui.view_instance) ~= "function" then
        return
    end

    local active = type(ui.view_active) == "function" and ui:view_active("scores_history_view")
    local view = active and ui:view_instance("scores_history_view") or nil
    if not view then
        return
    end

    attach_view(view)
    add_toggle_entries(view)
    set_compact_visibility(view, false)
end

return mod
