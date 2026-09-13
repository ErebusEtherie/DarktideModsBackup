local mod = get_mod("realms_loadout")
if mod._inventory_talent_extension then return mod._inventory_talent_extension end
local BaseView = require("scripts/ui/views/base_view")
local Router = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/workspace_router")
local Presets = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/workspace_presets")
local Extension = {}
mod._inventory_talent_extension = Extension
local TREE = "realms_loadout_talent_view"
local STIMM = "realms_loadout_stimm_view"
local pages = setmetatable({}, { __mode = "k" })

local function enabled(view)
  local root = view._context and view._context.parent
  return mod:is_enabled() and not view.__deleted and root and not root.__deleted and not root._workspace_invalid
    and mod.talent_workspace_page.available(view._preview_player)
end

local function remember_native_nodes(view)
  view._tpm_native_nodes = table.clone_instance(view._current_profile_equipped_talents or {})
  view._tpm_native_valid_nodes = table.clone_instance(view._valid_profile_equipped_talents or {})
end

local function restore_native_nodes(view)
  view._current_profile_equipped_talents = table.clone_instance(view._tpm_native_nodes or {})
  view._valid_profile_equipped_talents = table.clone_instance(view._tpm_native_valid_nodes or {})
end

local function prepare_tree(view)
  Presets.observe(view)
  mod.workspace_prepare(view)
end

local function refresh_tree(view)
  prepare_tree(view)
  local tree = Managers.ui:view_instance(TREE)
  if tree and not tree.__deleted and tree._context.parent == view and tree.replace_selected_nodes then
    tree:replace_selected_nodes(view._current_profile_equipped_talents)
  end
end

local function editable_tree(view)
  if (view._active_view ~= TREE and view._active_view ~= STIMM) or not enabled(view) or view._is_readonly
    or view._context.parent._workspace_closing then return end
  local tree = Managers.ui:view_instance(view._active_view)
  if tree and not tree.__deleted and tree._context.parent == view
    and not tree._is_readonly and not tree._input_blocked and tree:can_exit() then return tree end
end

function Extension.attach(view, context)
  -- Scope the override to the existing inventory instance inside the custom
  -- workspace. The I-key inventory and all other BaseView users are untouched.
  if view._tpm_inventory_attached or not context or not context.workspace or not context.parent
    or type(view._switch_active_view) ~= "function" or type(view._setup_profile_presets) ~= "function" then return end
  view._tpm_inventory_attached = true
  local root = context.parent
  view._tpm_preset_namespace = root._page and root._page.native and "native" or "local_equipment"
  view._workspace_session_owned, view._character, view._connection = true, root._character, root._connection

  local function wrap(name, callback)
    local original = view[name]
    if type(original) == "function" then view[name] = function(self, ...) return callback(original, self, ...) end end
  end
  local original_switch = view._switch_active_view
  local function requested_tab(self)
    local owner = self._context.parent
    return owner._requested_page or owner._selected_page or self._context.workspace_tab
  end

  wrap("_setup_input_legend", function(original, self, ...)
    local result = original(self, ...)
    local legend = self._input_legend_element
    if legend and legend ~= self._tpm_reset_legend then
      self._tpm_reset_legend = legend
      -- Extend the existing native legend: its input action supplies both the
      -- remappable reset key and the clickable, right-aligned button.
      legend:add_entry("loc_talent_menu_action_clear_all_points", "hotkey_menu_special_1",
        function() return editable_tree(self) ~= nil end,
        function()
          local tree = editable_tree(self)
          if tree then tree:cb_on_clear_all_talents_pressed() end
        end, "right_alignment")
    end
    return result
  end)

  wrap("_switch_active_view", function(original, self, name, ...)
    if not enabled(self) then return original(self, name, ...) end
    -- Finish inventory/preset setup before opening the requested talent child.
    -- Opening equipment first makes can_exit false while its resources load.
    if self._tpm_initial_talent_setup then return end
    if name == "talent_builder_view" or name == TREE then
      if self._active_view == TREE then return end
      remember_native_nodes(self)
      prepare_tree(self)
      return original(self, TREE, ...)
    end
    if self._active_view == TREE then
      mod.workspace_commit(self)
      restore_native_nodes(self)
    end
    return original(self, name, ...)
  end)

  wrap("can_select_workspace_page", function(original, self, tab)
    if (tab == "talents" or tab == "stimms") and enabled(self) then return self:is_inventory_synced() and self:can_exit() end
    return original(self, tab)
  end)
  wrap("select_workspace_page", function(original, self, tab)
    if (tab ~= "talents" and tab ~= "stimms") or not enabled(self) then return original(self, tab) end
    if not self:can_select_workspace_page(tab) then return false end
    -- The existing inventory retains its equipment/cosmetics/forge state and
    -- preset controls. Only its talent child is replaced.
    self._top_panel:set_selected_panel_index(nil)
    self:_switch_active_view(tab == "stimms" and STIMM or TREE, { player_mode = true, can_exit = true })
    return true
  end)
  wrap("_can_swap_weapon", function(original, self, ...)
    if enabled(self) and (self._active_view == TREE or self._active_view == STIMM) then return false end
    return original(self, ...)
  end)
  wrap("update", function(original, self, ...)
    local owner = self._context and self._context.parent
    if self._tpm_pending_initial_talents then
      if not enabled(self) or owner._workspace_closing or requested_tab(self) ~= "talents" then
        self._tpm_pending_initial_talents = nil
      elseif self:select_workspace_page("talents") then
        self._tpm_pending_initial_talents = nil
      end
    end
    if self._tpm_preset_namespace == "native" and owner and not owner.__deleted
      and not owner._workspace_invalid and not owner._workspace_closing then
      if self._active_view == TREE and not enabled(self) then
        restore_native_nodes(self)
        original_switch(self, "talent_builder_view", { player_mode = true, can_exit = true })
      elseif self._active_view == "talent_builder_view" and enabled(self) then
        self:_switch_active_view("talent_builder_view", { player_mode = true, can_exit = true })
      end
    end
    return original(self, ...)
  end)

  wrap("_setup_profile_presets", function(original, self, ...)
    local result = original(self, ...)
    local element = self._profile_presets_element
    if element and not element._tpm_save_before_select then
      element._tpm_save_before_select = true
      local select = element.on_profile_preset_index_change
      element.on_profile_preset_index_change = function(control, ...)
        if enabled(self) and self._active_view == TREE then mod.workspace_commit(self) end
        return select(control, ...)
      end
    end
    if enabled(self) then
      if self._active_view == TREE then refresh_tree(self) else Presets.observe(self) end
    end
    return result
  end)
  wrap("_setup_inventory", function(original, self, ...)
    self._tpm_initial_talent_setup = not self._active_view and enabled(self) and requested_tab(self) == "talents"
    local result = original(self, ...)
    self._tpm_initial_talent_setup = nil
    if enabled(self) and requested_tab(self) == "talents" then
      self._tpm_pending_initial_talents = not self:select_workspace_page("talents") or nil
    end
    return result
  end)

  wrap("event_on_profile_preset_changed", function(original, self, ...)
    if not enabled(self) then return original(self, ...) end
    local editing = self._active_view == TREE
    if editing then mod.workspace_commit(self); restore_native_nodes(self) end
    local result = original(self, ...)
    Presets.observe(self)
    if editing then remember_native_nodes(self); refresh_tree(self) end
    return result
  end)
  wrap("event_on_player_preset_created", function(original, self, ...)
    if not enabled(self) or self._active_view ~= TREE then return original(self, ...) end
    mod.workspace_commit(self)
    restore_native_nodes(self)
    local result = original(self, ...)
    prepare_tree(self)
    return result
  end)
  wrap("_save_current_talents_to_profile_preset", function(original, self, ...)
    if not enabled(self) then return original(self, ...) end
    -- Original equipment saves must never receive the extended talent nodes.
  end)
  wrap("_apply_current_talents_to_profile", function(original, self, ...)
    if enabled(self) then return mod.workspace_commit(self) end
    return original(self, ...)
  end)
  wrap("on_exit", function(original, self, ...)
    if enabled(self) then mod.workspace_commit(self) end
    return original(self, ...)
  end)

  view.tpm_workspace_nodes_updated = function(self, nodes)
    if enabled(self) and self._active_view == TREE then mod.workspace_nodes_updated(self, nodes) end
  end
  view:_register_event("tpm_workspace_nodes_updated", "tpm_workspace_nodes_updated")
end

function Extension.entries()
  local page = Router.equipment_page()
  if not pages[page] then
    pages[page] = { { id = "talents", order = 40, page = page,
      label = function() return mod:localize("workspace_talents") end, applies = mod.talent_workspace_page.available },
      { id = "stimms", order = 45, page = page, label = function() return Localize("loc_broker_stimm_builder_view_display_name") end,
        applies = function(player)
          local profile = player and player:profile()
          return mod.talent_workspace_page.available(player) and profile and profile.archetype.name == "broker"
        end } }
  end
  return pages[page]
end

function Extension.install()
  if mod._inventory_talent_extension_installed then return end
  mod._inventory_talent_extension_installed = true
  mod.talent_workspace_entries = Extension.entries
  mod:hook_safe(BaseView, "init", function(self, definitions, settings, context) Extension.attach(self, context) end)
end

return Extension
