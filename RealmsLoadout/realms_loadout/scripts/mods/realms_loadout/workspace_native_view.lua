local mod = get_mod("realms_loadout")
if mod._workspace_native_class then return mod._workspace_native_class end
local Native = require("scripts/ui/views/inventory_background_view/inventory_background_view")
local ProfileUtils = require("scripts/utilities/profile_utils")
local Parser = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
local Router = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/workspace_router")
local Panel = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/workspace_panel")
local View = class("realms_loadoutWorkspaceNativeView", "InventoryBackgroundView")
mod._workspace_native_class = View

function View:init(settings, context)
  Native.init(self, settings, context)
  self._pass_input, self._pass_draw = true, true
end

function View:_add_element(element, name, ...)
  if name == "top_panel" then return Panel() end
  return Native._add_element(self, element, name, ...)
end

function View:_setup_top_panel()
  Native._setup_top_panel(self)
  self._workspace_native_indices = { equipment = 1, cosmetics = 2 }
  for index, setting in ipairs(self._views_settings) do
    if setting.view_name == "talent_builder_view" then self._workspace_native_indices.talents = index end
  end
end

function View:_setup_inventory()
  local profile = self._preview_player:profile()
  local id = ProfileUtils.get_active_profile_preset_id()
  local preset = id and ProfileUtils.get_profile_preset(id)
  local nodes = preset and preset.talents or Router.native_nodes(self._preview_player)
  self._current_profile_equipped_talents = Parser.filter_layout_talents(profile, "talent_layout_file_path", nodes)
  self._valid_profile_equipped_talents = table.clone(self._current_profile_equipped_talents)
  self._workspace_initial_selection = true
  self._workspace_initializing = true
  Native._setup_inventory(self)
  self._workspace_initializing = nil
end

function View:_force_select_panel_index(index)
  if self._workspace_initial_selection then
    self._workspace_initial_selection = nil
    index = self._workspace_native_indices[self._context.workspace_tab] or index
  end
  return Native._force_select_panel_index(self, index)
end

function View:can_select_workspace_page(tab)
  return self._workspace_native_indices and self._workspace_native_indices[tab]
    and self:is_inventory_synced() and self:can_exit() or false
end

function View:select_workspace_page(tab)
  if not self:can_select_workspace_page(tab) then return false end
  self:_force_select_panel_index(self._workspace_native_indices[tab])
  return true
end

function View:workspace_children()
  return self._active_view and { self._active_view } or {}
end

function View:_switch_active_view(view_name, additional_context_data)
  if not view_name then return end
  local active = self._active_view
  if active == view_name and additional_context_data and Managers.ui:view_active(active)
    and Managers.ui:view_instance(active):supports_changeable_context() then
    self._active_view_context.changeable_context = additional_context_data
    return
  end
  if active and Managers.ui:view_active(active) then
    Managers.ui:close_view(active)
    if active == "talent_builder_view" and self:_check_toggle_companion() then
      Managers.event:trigger("event_inventory_set_cosmetics_target_camera_offset", true)
    end
  end
  local context = {
    parent = self, player = self._preview_player, player_level = self._player_level,
    preview_profile_equipped_items = self._preview_profile_equipped_items,
    current_profile_equipped_items = self._current_profile_equipped_items,
    current_profile_equipped_talents = self._current_profile_equipped_talents,
    current_profile_equipped_specialization_talents = self._current_profile_equipped_specialization_talents,
    changeable_context = additional_context_data, is_readonly = self._is_readonly,
  }
  self._active_view, self._active_view_context = view_name, context
  if not Managers.ui:view_active(view_name) then
    -- The stock Inventory view otherwise waits for the unopened I-key parent
    -- and is never drawn. This override belongs only to this view instance.
    Managers.ui:open_view(view_name, nil, nil, nil, nil, context, { parent_transition_view = self.view_name })
  end
end

function View:_handle_back_pressed()
  local parent = self._context and self._context.parent
  if parent and not parent.__deleted and parent:can_exit() then Managers.ui:close_view(parent.view_name) end
end

function View:event_on_profile_preset_changed(preset, ...)
  local page = Router.page("talents", self._preview_player)
  if not self._workspace_initializing and page and page.native then self._workspace_native_edited = true end
  return Native.event_on_profile_preset_changed(self, preset, ...)
end

function View:event_player_talent_node_updated(nodes)
  local page = Router.page("talents", self._preview_player)
  if self._active_view ~= "talent_builder_view" or not page or not page.native then return end
  self._workspace_native_edited = true
  return Native.event_player_talent_node_updated(self, nodes)
end

function View:_save_current_talents_to_profile_preset()
  if self._workspace_native_edited then return Native._save_current_talents_to_profile_preset(self) end
end

function View:_apply_current_talents_to_profile()
  -- Only native tree edits may reach the original talent writer. Opening
  -- equipment/cosmetics must not re-save an extended runtime build.
  if self._workspace_native_edited then return Native._apply_current_talents_to_profile(self) end
end

function View:on_exit()
  local parent = self._context and self._context.parent
  if parent and parent._workspace_invalid then self._is_readonly = true end
  return Native.on_exit(self)
end

return View
