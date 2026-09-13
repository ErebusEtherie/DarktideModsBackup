local mod = get_mod("realms_loadout")
if mod._workspace_shell_class then return mod._workspace_shell_class end
local BaseView = require("scripts/ui/views/base_view")
local UIWidget = require("scripts/managers/ui/ui_widget")
local ViewElementMenuPanel = require("scripts/ui/view_elements/view_element_menu_panel/view_element_menu_panel")
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local MenuPanelSettings = require("scripts/ui/view_elements/view_element_menu_panel/view_element_menu_panel_settings")
local Router = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/workspace_router")
local Shell = class("realms_loadoutWorkspaceShell", "BaseView")
mod._workspace_shell_class = Shell
local function definition()
  local scene = { screen = { size = { 1920, 1080 }, scale = "fit" },
    empty = { parent = "screen", horizontal_alignment = "center", vertical_alignment = "center",
      size = { 1100, 180 }, position = { 0, 0, 0 } } }
  return { scenegraph_definition = scene, widget_definitions = {
    empty = UIWidget.create_definition({ { pass_type = "rect", style = { color = { 240, 12, 18, 20 } } },
      { pass_type = "text", value_id = "text", style = { font_type = "proxima_nova_bold", font_size = 24,
        text_color = { 255, 215, 215, 215 }, text_horizontal_alignment = "center", text_vertical_alignment = "center",
        offset = { 24, 0, 1 }, size = { 1052, 180 } } } }, "empty", { text = mod:localize("workspace_unavailable") }),
  } }
end

function Shell:init(settings, context)
  self._workspace_session_owned, self._workspace_invalid = true, false
  self._context, self._preview_player = context, context.player
  self._is_readonly = false
  self._character = context.player:character_id()
  self._connection = Managers.connection and (Managers.connection._connection_host or Managers.connection._connection_client)
  self._entries, self._page_events = {}, {}
  Shell.super.init(self, definition(), settings, context)
  self._pass_draw = false
end

function Shell:_refresh_navigation()
  local entries = Router.entries(self._preview_player)
  local changed = #entries ~= #self._entries
  for i, entry in ipairs(entries) do if entry ~= self._entries[i] then changed = true end end
  if not changed then return end
  -- Rebuild the real native element only when registrations change. Removed
  -- extensions leave no widget, callback or reserved slot in either UI list.
  if self._top_panel then self:_remove_element("top_panel") end
  self._entries = entries
  self._top_panel = self:_add_element(ViewElementMenuPanel, "top_panel", 900)
  for _, entry in ipairs(entries) do
    self._top_panel:add_entry(entry.label(), function() return self:select_page(entry.id) end)
  end
  self._top_panel:set_is_handling_navigation_input(true)
  self._navigation_widths, self._navigation_width = {}, nil
  for i, widget in ipairs(self._top_panel._content_widgets or {}) do
    self._navigation_widths[i] = widget.content.size[1]
  end
  self:_fit_navigation()
  self:_sync_navigation()
end

function Shell:_fit_navigation()
  local panel = self._top_panel
  local width = RESOLUTION_LOOKUP.width / self._render_scale
  if not panel or self._navigation_width == width then return end
  self._navigation_width = width
  local count = #self._entries
  if count == 0 then return end
  -- Keep native text-measured widths normally. Fit long labels on narrower
  -- aspect ratios without changing global templates or the native tab height.
  local spacing = MenuPanelSettings.grid_spacing[1]
  local total = spacing * (count - 1)
  for _, value in ipairs(self._navigation_widths) do total = total + value end
  local cap = total > width - 160 and (width - 160 - spacing * (count - 1)) / count or math.huge
  for i, widget in ipairs(panel._content_widgets or {}) do
    widget.content.size[1] = math.min(self._navigation_widths[i], cap)
  end
  panel._content_grid = panel:_setup_grid(panel._content_widgets, panel._alignment_list)
  panel._grid_length = nil
end

function Shell:_sync_navigation()
  local selected = self._requested_page or self._selected_page
  local selected_index = 1
  local current = self._child and Managers.ui:view_instance(self._child)
  local busy = current and current.can_exit and not current:can_exit()
  for i, entry in ipairs(self._entries) do
    local page = entry.page
    local hotspot = self._top_panel._content_widgets[i].content.hotspot
    hotspot.disabled = (page.available and not page.available(self._preview_player))
      or (busy and entry.id ~= self._selected_page) or false
    if current and self._child == page.view_name and page.can_select and not page.can_select(current, entry.id) then
      hotspot.disabled = true
    end
    if entry.id == selected then selected_index = i end
  end
  self._top_panel:set_selected_panel_index(selected_index)
end

function Shell:_request_close(force)
  if self._workspace_closing or (not force and not self:can_exit()) then return end
  self._workspace_closing = true
  Managers.ui:close_view(mod._workspace_window_name, force)
end

function Shell:_needs_close_legend()
  local child = self._child and Managers.ui:view_instance(self._child)
  local legend = child and child._input_legend_element
  for _, entry in ipairs(legend and legend._entries or {}) do
    if entry.input_action == "back" and entry.is_visible then return false end
  end
  return true
end

function Shell:on_enter()
  Shell.super.on_enter(self)
  self:_refresh_navigation()
  self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 900)
  self._input_legend_element:add_entry("loc_settings_menu_close_menu", "back",
    function() return self:_needs_close_legend() end, function() self:_request_close() end, "left_alignment")
  local initial = mod._workspace_requested_tab or self._context.initial_page
  mod._workspace_requested_tab = nil
  if not self:select_page(initial) then
    for _, entry in ipairs(self._entries) do if self:select_page(entry.id) then break end end
  end
end

function Shell:event_workspace_nodes_updated(...)
  if self._page and self._page.nodes_updated then self._page.nodes_updated(self, ...) end
end

function Shell:_page_for_tab(tab)
  for _, entry in ipairs(self._entries) do if entry.id == tab then return entry.page end end
end

function Shell:select_page(tab)
  self:_refresh_navigation()
  local page = self:_page_for_tab(tab)
  if not page or (page.available and not page.available(self._preview_player)) then return false end
  if self._selected_page == tab and self._child and self._page == page then self._requested_page = nil; return true end
  if self._child then
    local current = Managers.ui:view_instance(self._child)
    if current and current.can_exit and not current:can_exit() then return false end
    if current and self._child == page.view_name and page.can_select and not page.can_select(current, tab) then return false end
  end
  self._requested_page = tab
  return true
end

function Shell:_close_page()
  if not self._child then return end
  local page, child = self._page, Managers.ui:view_instance(self._child)
  if not self._workspace_invalid and page and page.commit then page.commit(self) end
  if page and page.nodes_event and self._page_events[page.nodes_event] then
    self:_unregister_event(page.nodes_event)
    self._page_events[page.nodes_event] = nil
  end
  self._closing_views = child and child.workspace_children and child:workspace_children() or {}
  self._closing_views[#self._closing_views + 1] = self._child
  Managers.ui:close_view(self._child, true)
  self._child, self._page = nil, nil
end

function Shell:_finished_closing()
  for _, name in ipairs(self._closing_views or {}) do if Managers.ui:view_active(name) then return false end end
  self._closing_views = nil
  return true
end

function Shell:update(dt, t, input_service)
  local connection = Managers.connection and (Managers.connection._connection_host or Managers.connection._connection_client)
  local player = Managers.player and Managers.player:local_player_safe(1)
  local profile = player and not player.__deleted and player:profile()
  if not profile or not profile.archetype or not mod:is_enabled() or not self._preview_player or self._preview_player.__deleted
    or player ~= self._preview_player or player:character_id() ~= self._character or connection ~= self._connection then
    self._workspace_invalid = not profile or not profile.archetype or player ~= self._preview_player or not player or player.__deleted
      or player:character_id() ~= self._character or connection ~= self._connection
    self:_request_close(true); return false, true
  end
  self:_refresh_navigation()
  local current_page = self:_page_for_tab(self._selected_page)
  if self._child and self._page ~= current_page then
    local tab = self._selected_page
    self:_close_page()
    self._selected_page = nil
    self._requested_page = current_page and tab or "equipment"
  end
  self:_fit_navigation()
  self:_sync_navigation()
  if self._requested_page then
    local requested = self:_page_for_tab(self._requested_page)
    if requested and self._child == requested.view_name and requested.select then
      local current = Managers.ui:view_instance(self._child)
      if current and requested.select(current, self._requested_page) then
        self._selected_page, self._requested_page = self._requested_page, nil
      end
    else
      if self._child then self:_close_page() end
      if self:_finished_closing() then
        local tab, page = self._requested_page, requested
        self._requested_page = nil
        if page and (not page.available or page.available(player)) then
          self._selected_page, self._page, self._child = tab, page, page.view_name
          if page.nodes_event and not self._page_events[page.nodes_event] then
            self:_register_event(page.nodes_event, "event_workspace_nodes_updated")
            self._page_events[page.nodes_event] = true
          end
          if page.prepare then page.prepare(self) end
          Managers.ui:open_view(page.view_name, nil, nil, nil, nil, { parent = self,
            player = player, player_mode = true, can_exit = true, is_readonly = false,
            workspace = true, workspace_tab = tab, current_profile_equipped_talents = self._current_profile_equipped_talents })
        end
      end
    end
  end
  self._widgets_by_name.empty.visible = not self._child and self:_finished_closing()
  if input_service:get("back") then self:_request_close() end
  Shell.super.update(self, dt, t, input_service)
  self:_sync_navigation()
  return self._pass_input, self._pass_draw
end

function Shell:can_exit()
  local child = self._child and Managers.ui:view_instance(self._child)
  return not child or not child.can_exit or child:can_exit()
end

function Shell:on_exit()
  self:_close_page()
  Shell.super.on_exit(self)
end

return Shell
