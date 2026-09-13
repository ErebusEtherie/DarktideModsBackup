local mod = get_mod("realms_loadout")

local ProfileUtils = require("scripts/utilities/profile_utils")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local WwiseGameSyncSettings = require("scripts/settings/wwise_game_sync/wwise_game_sync_settings")
local Promise = require("scripts/foundation/utilities/promise")
local UIManager = require("scripts/managers/ui/ui_manager")
local TalentsService = require("scripts/managers/data_service/services/talents_service")

local Storage = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/storage")
local WeaponCatalog = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/weapon_catalog")
local AttachmentCatalog = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/attachment_catalog")


-- Realms clients fetch the official backend profile before sending a profile
-- update. When realms_loadout applies a locally edited profile on a Realms
-- client, this hook substitutes that profile during Realms' update pipeline so
-- the host receives the local loadout instead of the untouched backend data.
-- The one-shot override must only be consumed by the Realms profile-update
-- pipeline. Unrelated callers can arrive while Realms is still fetching the
-- official backend profile; they must pass through untouched, otherwise they
-- would consume the override and the local loadout would never reach the host.
local function is_realms_profile_update_call()
  for level = 2, 12 do
    local info = debug.getinfo(level, "S")

    if not info then
      return false
    end

    local source = info.source

    if type(source) == "string" and source:find("Realms/scripts/mods/Realms/protocol/profile_update", 1, true) then
      return true
    end
  end

  return false
end

mod:hook(ProfileUtils, "backend_profile_data_to_profile", function (func, backend_profile_data)
  local override_request = mod._client_profile_override
  local override = override_request and (override_request.profile or override_request)
  local official_profile = func(backend_profile_data)

  -- Realms fetches this backend profile before every local profile update. It
  -- is the authoritative official snapshot even when the live player profile
  -- is currently the isolated Realms version.
  Storage.remember_official_profile(official_profile)

  local connection = Managers.connection and Managers.connection._connection_client
  local player = Managers.player and Managers.player:local_player_safe(1)
  local realms_profile_update = is_realms_profile_update_call()
  if override and (connection ~= mod._client_profile_override_connection or not player
    or player:character_id() ~= mod._client_profile_override_character or not mod:is_enabled()) then
    mod._client_profile_override = nil
    override = nil
  end
  if override and realms_profile_update then
    mod._client_profile_override = nil

    if override_request.exact == true then
      local marker = override.tamm_custom_talents

      if official_profile and marker and marker.source == "realms_loadout_official_ui" then
        local generation = override_request.generation

        if not generation or marker.generation ~= generation then
          mod:warning("Discarded a stale official profile override while opening the native inventory")

          return official_profile
        end

        local target_updated, target_error = Storage.update_official_transition_target(
          official_profile,
          generation,
          "client_backend",
          false
        )

        if not target_updated then
          mod:warning(
            "Could not bind the refreshed official profile to generation %s: %s",
            tostring(generation),
            tostring(target_error)
          )

          return official_profile
        end

        local refreshed = table.clone_instance(official_profile)

        refreshed.tamm_custom_talents = table.clone_instance(marker)

        return refreshed
      end

      return table.clone_instance(override)
    end

    return Storage.preserve_talents(override, player:profile()) or official_profile
  end

  if realms_profile_update then
    local protected_profile = Storage.realms_profile_for_backend_update(official_profile)

    if protected_profile then
      return protected_profile
    end
  end

  return official_profile
end)

local Workspace = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/workspace_router")
Workspace.install()

local OFFICIAL_UI = "realms_loadout/scripts/mods/realms_loadout/official_ui"

local function realms_session()
  local realms_mod = get_mod("Realms")

  return realms_mod and realms_mod._session or nil
end

local function is_realms_client()
  local session = realms_session()

  return session and type(session.is_active_client) == "function" and session:is_active_client() or false
end

local function is_realms_host()
  local session = realms_session()

  return session and type(session.is_active_host) == "function" and session:is_active_host() or false
end

local function realms_preparation()
  local realms_mod = get_mod("Realms")

  return realms_mod and realms_mod._preparation or nil
end

local function is_realms_preparation_waiting()
  local preparation = realms_preparation()

  return preparation and type(preparation.is_waiting) == "function" and preparation:is_waiting() or false
end

mod.on_setting_changed = function (setting_id)
  if setting_id == "allow_all_archetype_weapons" then
    WeaponCatalog.reset_cache()

    return
  end

end

mod.on_setting_changed()

-- Register every copied official UI module as a local io-require path.
local require_paths = {
  "realms_loadout/scripts/mods/realms_loadout/storage",
  "realms_loadout/scripts/mods/realms_loadout/weapon_catalog",
  "realms_loadout/scripts/mods/realms_loadout/attachment_catalog",
  OFFICIAL_UI .. "/inventory_background_view/inventory_background_view",
  OFFICIAL_UI .. "/inventory_view/inventory_view",
  OFFICIAL_UI .. "/inventory_weapons_view/inventory_weapons_view",
  OFFICIAL_UI .. "/inventory_weapons_view/inventory_weapon_stats_view_element",
  OFFICIAL_UI .. "/inventory_weapons_view/inventory_item_stats_blueprints",
  OFFICIAL_UI .. "/inventory_weapon_details_view/inventory_weapon_details_view",
  OFFICIAL_UI .. "/inventory_weapon_marks_view/inventory_weapon_marks_view",
  OFFICIAL_UI .. "/weapon_forge_view/weapon_forge_view",
  OFFICIAL_UI .. "/weapon_forge_view/forge_view_element_weapon_stats",
  OFFICIAL_UI .. "/weapon_forge_view/forge_view_element_weapon_stats_definitions",
  OFFICIAL_UI .. "/weapon_forge_view/forge_item_stats_blueprints",
  OFFICIAL_UI .. "/weapon_forge_view/forge_view_element_perks_item",
  OFFICIAL_UI .. "/weapon_forge_view/forge_view_element_perks_item_blueprints",
  OFFICIAL_UI .. "/weapon_forge_view/forge_view_element_perks_item_definitions",
  OFFICIAL_UI .. "/weapon_forge_view/forge_view_element_trait_inventory",
  OFFICIAL_UI .. "/weapon_forge_view/forge_view_element_trait_inventory_blueprints",
  OFFICIAL_UI .. "/weapon_forge_view/forge_view_element_trait_inventory_definitions",
  OFFICIAL_UI .. "/masteries_overview_view/masteries_overview_view",
  OFFICIAL_UI .. "/view_element_profile_presets/view_element_profile_presets",
}

for i = 1, #require_paths do
  mod:add_require_path(require_paths[i])
end

local function view_data(view_name, class_name, path, package_name, extra)
  local data = {
    view_name = view_name,
    view_settings = {
      class = class_name,
      init_view_function = function ()
        return true
      end,
      path = path,
      package = package_name,
      state_bound = true,
      disable_game_world = true,
      enter_sound_events = {
        UISoundEvents.default_menu_enter
      },
      exit_sound_events = {
        UISoundEvents.default_menu_exit
      },
      wwise_states = {
        options = WwiseGameSyncSettings.state_groups.options.ingame_menu
      }
    },
    view_transitions = {}
  }

  for key, value in pairs(extra or {}) do
    data.view_settings[key] = value
  end

  return data
end

mod:register_view(view_data(
  "realms_inventory_background_view",
  "RealmsInventoryBackgroundView",
  OFFICIAL_UI .. "/inventory_background_view/inventory_background_view",
  "packages/ui/views/inventory_background_view/inventory_background_view",
  {
    display_name = "loc_inventory_background_view_display_name",
    preload_in_hub = "always",
    use_transition_ui = true,
    levels = {
      "content/levels/ui/inventory/inventory",
      "content/levels/ui/credits_vendor/credits_vendor"
    }
  }
))

mod:register_view(view_data(
  "realms_inventory_view",
  "RealmsInventoryView",
  OFFICIAL_UI .. "/inventory_view/inventory_view",
  "packages/ui/views/inventory_view/inventory_view",
  {
    display_name = "loc_inventory_view_display_name",
    parent_transition_view = "realms_inventory_background_view",
    preload_in_hub = "not_ps5"
  }
))

mod:register_view(view_data(
  "realms_inventory_weapons_view",
  "RealmsInventoryWeaponsView",
  OFFICIAL_UI .. "/inventory_weapons_view/inventory_weapons_view",
  "packages/ui/views/inventory_weapons_view/inventory_weapons_view",
  {
    display_name = "loc_inventory_weapons_view_display_name",
    preload_in_hub = "not_ps5",
    use_transition_ui = true,
    levels = {
      "content/levels/ui/inventory_weapon_view/inventory_weapon_view"
    }
  }
))

mod:register_view(view_data(
  "realms_inventory_weapon_details_view",
  "RealmsInventoryWeaponDetailsView",
  OFFICIAL_UI .. "/inventory_weapon_details_view/inventory_weapon_details_view",
  "packages/ui/views/inventory_weapon_details_view/inventory_weapon_details_view",
  {
    display_name = "loc_inventory_weapon_details_view_display_name",
    preload_in_hub = "not_ps5_nor_lockhart",
    use_transition_ui = false
  }
))

mod:register_view(view_data(
  "realms_inventory_weapon_marks_view",
  "RealmsInventoryWeaponMarksView",
  OFFICIAL_UI .. "/inventory_weapon_marks_view/inventory_weapon_marks_view",
  "packages/ui/views/inventory_weapon_marks_view/inventory_weapon_marks_view",
  {
    display_name = "loc_inventory_weapon_marks_view_display_name",
    preload_in_hub = "not_ps5",
    use_transition_ui = true
  }
))

mod:register_view(view_data(
  "realms_weapon_forge_view",
  "RealmsWeaponForgeView",
  OFFICIAL_UI .. "/weapon_forge_view/weapon_forge_view",
  "packages/ui/views/credits_goods_vendor_view/credits_goods_vendor_view",
  {
    display_name = "weapon_forge_view_display_name",

    preload_in_hub = "not_ps5",
    use_transition_ui = true
  }
))

mod:register_view(view_data(
  "realms_masteries_overview_view",
  "RealmsMasteriesOverviewView",
  OFFICIAL_UI .. "/masteries_overview_view/masteries_overview_view",
  "packages/ui/views/masteries_overview_view/masteries_overview_view",
  {
    display_name = "loc_masteries_view_display_name",
    parent_transition_view = "realms_inventory_background_view",
    preload_in_hub = "not_ps5"
  }
))



local VIEW_NAME = "realms_inventory_background_view"

local function realms_client_mission_in_progress()
  local realms_mod = get_mod("Realms")
  local session = realms_mod and realms_mod._session
  local preparation = realms_mod and realms_mod._preparation

  if not session or type(session.is_active_client) ~= "function" or not session:is_active_client() then
    return false
  end

  if preparation and type(preparation.is_started) == "function" and preparation:is_started() then
    return true
  end

  return Managers.state and Managers.state.game_session ~= nil or false
end

mod.workspace_page = { view_name = VIEW_NAME,
  -- Optional equipment-preset protocol. Providers retain ownership of their
  -- own data and selection UI; extensions only attach data to a stable slot.
  presets = { namespace = "local_equipment", list = Storage.get_profile_presets,
    active = Storage.get_active_profile_preset_id },
  available = function() return not realms_client_mission_in_progress() end,
  prepare = function() Storage.refresh_loadouts_cache() end,
  can_select = function(view, tab) return view:can_select_workspace_page(tab) end,
  select = function(view, tab) return view:select_workspace_page(tab) end }
mod.workspace_pages = {
  { id = "equipment", order = 10, label = function() return mod:localize("workspace_equipment") end, page = mod.workspace_page },
  { id = "cosmetics", order = 20, label = function() return mod:localize("workspace_cosmetics") end, page = mod.workspace_page },
  { id = "forge", order = 30, label = function() return mod:localize("workspace_forge") end, page = mod.workspace_page },
}
mod.open_view = function() return Workspace.open("equipment") end
mod:command("realms_loadout", mod:localize("command_open_view"), mod.open_view)

-- The local view is opt-in: it opens with the player's own keybind
-- (open_view_bind) or the explicit chat commands below. It no longer replaces
-- Realms' inventory button or input legend, and it does not touch other keys.

-- The saved loadout is the source of truth for Realms preparation. Whenever
-- the local player enters the preparation page, validate and re-apply the
-- active local loadout: on a Realms host this overrides the host synchronizer;
-- on a Realms client it sends the saved profile through Realms' client update
-- channel. Talent and Stimm limits are outside this equipment-only pipeline.
mod:hook("RealmsPreparationView", "on_enter", function (func, self, ...)
  Storage.remember_official_profile()
  func(self, ...)

  Storage.apply_active_on_host({ source = "preparation_enter" })
end)

local OFFICIAL_INVENTORY_VIEW_NAME = "inventory_background_view"

-- The native inventory reads its player profile during init/on_enter, before a
-- queued ProfileSynchronizerHost update becomes visible. Hold the open request
-- until Storage confirms that the exact official profile is the live profile.
mod:hook(UIManager, "open_view", function (func, self, view_name, transition_time, close_previous,
    close_all, close_transition_time, context, settings_override)
  if view_name ~= OFFICIAL_INVENTORY_VIEW_NAME or mod._realms_official_open_bypass then
    return func(self, view_name, transition_time, close_previous, close_all,
      close_transition_time, context, settings_override)
  end

  local player = Managers.player and Managers.player:local_player_safe(1)
  local preview_player = context and context.player or player
  local read_only = context and context.is_readonly == true

  if not player or preview_player ~= player or read_only then
    return func(self, view_name, transition_time, close_previous, close_all,
      close_transition_time, context, settings_override)
  end

  local handled, accepted, request_error = Storage.request_official_ui_open({
    close_all = close_all,
    close_previous = close_previous,
    close_transition_time = close_transition_time,
    context = context,
    settings_override = settings_override,
    transition_time = transition_time,
    view_name = view_name,
  })

  if handled then
    if not accepted then
      mod:warning("realms_loadout blocked the official inventory because profile isolation failed: %s",
        tostring(request_error))
    end

    return accepted
  end

  return func(self, view_name, transition_time, close_previous, close_all,
    close_transition_time, context, settings_override)
end)

mod:hook("InventoryBackgroundView", "on_enter", function (func, self, ...)
  local player = Managers.player and Managers.player:local_player_safe(1)

  if player and self._preview_player == player then
    Storage.mark_official_ui_entered()
  end

  return func(self, ...)
end)

mod:hook("InventoryBackgroundView", "on_exit", function (func, self, ...)
  func(self, ...)

  local player = Managers.player and Managers.player:local_player_safe(1)

  if player and self._preview_player == player then
    Storage.end_official_ui()
  end
end)

-- Native talent saving does not participate in UIManager's loadout-waiting
-- counter. Track its backend promise separately, then wait for the subsequent
-- synchronized profile event before preserving the edited official snapshot.
mod:hook(TalentsService, "set_talents_v2", function (func, self, player, ...)
  local promise = func(self, player, ...)
  local generation = Storage.official_profile_write_started(player)

  if generation and promise and type(promise.next) == "function" then
    promise:next(function (value)
      Storage.official_profile_write_finished(generation, true)

      return value
    end, function (reason)
      Storage.official_profile_write_finished(generation, false)

      return reason
    end)
  elseif generation then
    Storage.official_profile_write_finished(generation, false)
  end

  return promise
end)

mod:hook_safe(UIManager, "event_player_profile_updated", function (self, peer_id, local_player_id)
  Storage.note_profile_updated(peer_id, local_player_id)
end)

-- Official weapon appearance view hook: for local Realm weapons the official
-- view's final equip action must not call the backend. Selected appearance
-- entries are written into the local weapon catalog instead.
local OFFICIAL_TRINKET_SLOT_ORDER = {
  "slot_trinket_1",
  "slot_trinket_2"
}

local function find_link_attachment_item_slot_path(start_table, slot_id, trinket_item, link_item)
  local find_all_slot_paths

  function find_all_slot_paths(path_target_table, path_slot_id, path_item, path_link_item, found_path, found_item_name)
    if not path_target_table then
      return
    end

    local unused_trinket_name = "content/items/weapons/player/trinkets/unused_trinket"

    for k, t in pairs(path_target_table) do
      if type(t) == "table" then
        if k == path_slot_id then
          if not t.item or t.item ~= unused_trinket_name then
            found_path = true

            if path_link_item then
              t.item = path_item
            end

            found_item_name = found_item_name ~= nil and found_item_name or t.item
          end
        elseif not ItemSlotSettings[k] then
          found_path, found_item_name = find_all_slot_paths(t, path_slot_id, path_item, path_link_item, found_path, found_item_name)
        end
      end
    end

    return found_path, found_item_name
  end

  return find_all_slot_paths(start_table, slot_id, trinket_item, link_item)
end

local function apply_local_weapon_cosmetics(view)
  local selected_item = view._selected_item

  if not selected_item then
    return
  end

  local skin_changed = view._equipped_weapon_skin_name ~= view._starting_weapon_skin_name
  local trinket_changed = view._equipped_weapon_trinket_name ~= view._starting_weapon_trinket_name

  if not skin_changed and not trinket_changed then
    return
  end

  local gear = selected_item.__gear or selected_item.gear
  local master_data = gear and gear.masterDataInstance
  local overrides = master_data and master_data.overrides

  if not overrides then
    overrides = {}
  end

  if skin_changed then
    local skin_name = view._equipped_weapon_skin_name
    local skin_item = view._equipped_weapon_skin

    selected_item.slot_weapon_skin = skin_item
    overrides.slot_weapon_skin = skin_name

    if selected_item.__master_item then
      selected_item.__master_item.slot_weapon_skin = skin_name
    end
  end

  if trinket_changed then
    local trinket_name = view._equipped_weapon_trinket_name
    local master_attachments = selected_item.__master_item and selected_item.__master_item.attachments

    if not overrides.attachments and master_attachments then
      overrides.attachments = table.clone_instance(master_attachments)
    else
      overrides.attachments = overrides.attachments or {}
    end

    if not selected_item.attachments and master_attachments then
      selected_item.attachments = table.clone_instance(master_attachments)
    end

    if selected_item.attachments then
      for i = 1, #OFFICIAL_TRINKET_SLOT_ORDER do
        find_link_attachment_item_slot_path(selected_item.attachments, OFFICIAL_TRINKET_SLOT_ORDER[i], trinket_name, true)
      end
    end

    for i = 1, #OFFICIAL_TRINKET_SLOT_ORDER do
      find_link_attachment_item_slot_path(overrides.attachments, OFFICIAL_TRINKET_SLOT_ORDER[i], trinket_name, true)
    end

    if selected_item.__master_item and selected_item.__master_item.attachments then
      for i = 1, #OFFICIAL_TRINKET_SLOT_ORDER do
        find_link_attachment_item_slot_path(selected_item.__master_item.attachments, OFFICIAL_TRINKET_SLOT_ORDER[i], trinket_name, true)
      end
    end
  end

  if master_data then
    master_data.overrides = overrides
  end

  local profile = view._preview_player and view._preview_player:profile()

  if profile then
    local ok, updated = pcall(WeaponCatalog.apply_local_weapon_cosmetics, profile, selected_item)

    if ok and updated then
      selected_item = updated
    end
  end

  local slot_name = view._selected_slot and view._selected_slot.name

  if not slot_name then
    local slots = selected_item.slots

    if slots then
      for i = 1, #slots do
        if slots[i] == "slot_primary" or slots[i] == "slot_secondary" then
          slot_name = slots[i]

          break
        end
      end
    end
  end

  local parent = view._parent
  local update_equipped_slot = false

  if slot_name and parent then
    local equipped = parent._preview_profile_equipped_items and parent._preview_profile_equipped_items[slot_name]

    if equipped and equipped.gear_id == selected_item.gear_id then
      update_equipped_slot = true
    end
  end

  -- Defer the icon and view refresh until after the official view has fully
  -- exited. Doing it synchronously inside _equip_items_on_server makes
  -- WeaponIconUI start a new icon request while the view is still tearing
  -- down, which can leave its weapon package references unbalanced when the
  -- next mission unload starts.
  Promise:resolved():next(function ()
    if update_equipped_slot then
      Managers.event:trigger("event_inventory_view_equip_item", slot_name, selected_item, true)
    end

    Managers.ui:item_icon_updated(selected_item)
    Managers.event:trigger("event_weapon_cosmetic_updated", selected_item)
  end)
end

mod:hook("InventoryWeaponCosmeticsView", "_equip_items_on_server", function (func, self)
  if WeaponCatalog.is_local_weapon(self._selected_item) then
    apply_local_weapon_cosmetics(self)

    return
  end

  return func(self)
end)

local function update_realms_countdown_validation()
  local preparation = realms_preparation()

  if not is_realms_preparation_waiting()
    or not preparation
    or type(preparation.countdown_remaining) ~= "function"
  then
    mod._realms_countdown_active = false
    mod._realms_pre_start_validation_sent = false

    return
  end

  local remaining = preparation:countdown_remaining()

  if remaining then
    if not mod._realms_countdown_active then
      mod._realms_countdown_active = true
      mod._realms_pre_start_validation_sent = false
    end

    if Storage.official_ui_blocks_realms_apply() then
      local ui_manager = Managers.ui

      if ui_manager and ui_manager:view_active(OFFICIAL_INVENTORY_VIEW_NAME) then
        if not ui_manager:is_view_closing(OFFICIAL_INVENTORY_VIEW_NAME) then
          ui_manager:close_view(OFFICIAL_INVENTORY_VIEW_NAME, true)
        end
      else
        Storage.cancel_official_ui_open()
      end

      return
    end

    -- Retry until the saved Realms profile is accepted. A profile switch in
    -- progress must never be treated as successful countdown validation.
    if not mod._realms_pre_start_validation_sent then
      local applied = Storage.apply_active_on_host({ source = "preparation_countdown" })

      mod._realms_pre_start_validation_sent = applied == true
    end
  else
    mod._realms_countdown_active = false
  end
end

local function open_confirmed_official_view(request)
  if not request or not Managers.ui then
    return
  end

  mod._realms_official_open_bypass = true
  local ok, opened = pcall(function ()
    return Managers.ui:open_view(
      request.view_name,
      request.transition_time,
      request.close_previous,
      request.close_all,
      request.close_transition_time,
      request.context,
      request.settings_override
    )
  end)
  mod._realms_official_open_bypass = nil

  if not ok or not opened then
    mod:warning("realms_loadout could not open the isolated official inventory: %s", tostring(opened))
    Storage.end_official_ui()
  end
end

local function close_official_ui_if_profile_changes_disallowed()
  if not Storage.official_ui_blocks_realms_apply() then
    return
  end

  local mechanism = Managers.mechanism

  if not mechanism or type(mechanism.profile_changes_are_allowed) ~= "function"
    or mechanism:profile_changes_are_allowed()
  then
    return
  end

  local ui_manager = Managers.ui

  if ui_manager and ui_manager:view_active(OFFICIAL_INVENTORY_VIEW_NAME) then
    if not ui_manager:is_view_closing(OFFICIAL_INVENTORY_VIEW_NAME) then
      ui_manager:close_view(OFFICIAL_INVENTORY_VIEW_NAME, true)
    end
  else
    Storage.cancel_official_ui_open()
  end
end

function mod.update(dt)
  if not mod:is_enabled() then return end
  local connection = Managers.connection and (Managers.connection._connection_host or Managers.connection._connection_client)
  if connection ~= mod._loadout_connection then
    Storage.clear_realms_profile_state()
    mod._loadout_connection = connection
  end
  local realms_session_active = is_realms_client() or is_realms_host()

  if mod._realms_session_active and not realms_session_active then
    Storage.clear_realms_profile_state()
  end

  mod._realms_session_active = realms_session_active

  if realms_session_active and not mod._realms_local_profile_applied then
    Storage.remember_official_profile()
  end

  close_official_ui_if_profile_changes_disallowed()

  local official_request, transition_error = Storage.update_profile_transition(dt)

  if transition_error then
    mod:warning("realms_loadout profile isolation failed: %s", tostring(transition_error))
  end
  if official_request then
    open_confirmed_official_view(official_request)
  end

  if is_realms_preparation_waiting() then
    update_realms_countdown_validation()
  else
    mod._realms_countdown_active = false
    mod._realms_pre_start_validation_sent = false
  end
end


function mod.on_all_mods_loaded()
  -- UI assets are declared in .mod. DMF owns one reference per package and
  -- releases it after custom views are destroyed on reload or game shutdown.

  local better = get_mod("BetterLoadouts")
  local loadout_names = get_mod("LoadoutNames")

  if (better and better.BL) or loadout_names then
    -- Discover optional integrations after mod initialization. Warm requires
    -- reuse the private class and do not register its hooks again.
    require("realms_loadout/scripts/mods/realms_loadout/official_ui/view_element_profile_presets/view_element_profile_presets")
    if mod._ensure_background_compat then mod._ensure_background_compat() end
  end
end







function mod.on_disabled()
  Workspace.cleanup()
  mod._client_profile_override = nil
  if Managers.ui and Managers.ui:view_instance(VIEW_NAME) then Managers.ui:close_view(VIEW_NAME, true) end
  Storage.clear_realms_profile_state()
end

function mod.on_enabled()
  Workspace.enable()
end
mod.on_unload = mod.on_disabled

-- Talent functionality is owned by this mod. Compose callbacks so equipment
-- cleanup, talent restoration and Realms transport share the same lifetime.
local Talents = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/component")
for _, name in ipairs({ "update", "on_all_mods_loaded", "on_setting_changed", "on_game_state_changed", "on_disabled", "on_unload", "on_enabled" }) do
  local equipment_callback, talent_callback = mod[name], Talents[name]
  mod[name] = function(...)
    if equipment_callback then equipment_callback(...) end
    if talent_callback then talent_callback(...) end
  end
end
