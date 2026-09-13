local mod = get_mod("realms_loadout")
if mod._module_Storage then return mod._module_Storage end

local _io = Mods.lua.io
local _os = Mods.lua.os

local ProfileUtils = require("scripts/utilities/profile_utils")
local WeaponCatalog = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/weapon_catalog")
local AttachmentCatalog = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/attachment_catalog")

local Storage = {}

local BASE_DIR

function Storage.base_dir()
  if not BASE_DIR then
    local appdata = _os and _os.getenv and _os.getenv("APPDATA") or ""

    BASE_DIR = appdata .. "/Fatshark/Darktide/realms_loadout"
  end

  return BASE_DIR
end

local function ensure_dir(path)
  local ok, run_error = pcall(_os.execute, 'mkdir "' .. path .. '" 2>nul')

  if not ok then
    mod:error("realms_loadout failed to create directory %s: %s", path, tostring(run_error))
  end
end

local function read_json(file_path)
  local file = _io.open(file_path, "rb")

  if not file then
    return nil
  end

  local content = file:read("*all")

  file:close()

  if not content or content == "" then
    return nil
  end

  local ok, decoded = pcall(cjson.decode, content)

  if not ok then
    mod:error("realms_loadout failed to parse %s: %s", file_path, tostring(decoded))

    return nil
  end

  return decoded
end

local function write_json(file_path, data)
  local ok, encoded = pcall(cjson.encode, data)

  if not ok then
    return false, tostring(encoded)
  end

  mod._persisted_json = mod._persisted_json or {}
  if mod._persisted_json[file_path] == encoded then return true end
  local file = _io.open(file_path, "wb")
  if not file then
    -- Existing installations need no blocking directory subprocess at all.
    ensure_dir(file_path:match("^(.*)/[^/]+$"))
    file = _io.open(file_path, "wb")
  end

  if not file then
    return false, "unable to open file for writing"
  end

  local written, write_error = file:write(encoded)
  local closed, close_error = file:close()
  if not written or not closed then return false, tostring(write_error or close_error) end
  mod._persisted_json[file_path] = encoded
  return true
end

local function table_count(value)
  local count = 0

  if value then
    for _ in pairs(value) do
      count = count + 1
    end
  end

  return count
end

local function clone_table(value)
  if type(value) ~= "table" then return value end
  return table.clone_instance(value)
end

local WEAPON_SLOTS = {
  slot_primary = true,
  slot_secondary = true,
}

local function is_weapon_slot(slot_name)
  return slot_name and WEAPON_SLOTS[slot_name] == true
end

local function reapply_local_item_markers(source, target)
  if not source or not target then
    return target
  end

  target.loadout_item_data = target.loadout_item_data or {}

  for slot_name, item_data in pairs(source.loadout_item_data or {}) do
    if type(item_data) == "table" and item_data.local_item then
      local is_attachment = item_data.local_attachment == true
      local is_weapon = item_data.local_weapon == true or is_weapon_slot(slot_name)

      if is_attachment or is_weapon then
        local target_item_data = target.loadout_item_data[slot_name]

        if not target_item_data then
          target_item_data = {}
          target.loadout_item_data[slot_name] = target_item_data
        end

        target_item_data.local_item = true

        if not target_item_data.id and item_data.id then
          target_item_data.id = item_data.id
        end

        if is_attachment then
          target_item_data.local_attachment = true

          if item_data.source_gear_id then
            target_item_data.source_gear_id = item_data.source_gear_id
          end

          if item_data.overrides then
            target_item_data.overrides = clone_table(item_data.overrides)
          end
        elseif is_weapon then
          target_item_data.local_weapon = true

          if item_data.source_gear_id then
            target_item_data.source_gear_id = item_data.source_gear_id
          end

          if item_data.overrides then
            target_item_data.overrides = clone_table(item_data.overrides)
          end
        end
      end
    end
  end

  return target
end

local function rebuild_local_item_instances(source, target)
  reapply_local_item_markers(source, target)

  if not target then
    return target
  end

  target.loadout = target.loadout or {}
  target.visual_loadout = target.visual_loadout or {}

  for slot_name, item_data in pairs(target.loadout_item_data or {}) do
    if type(item_data) == "table" and item_data.local_item then
      if item_data.local_attachment == true then
        local local_item = AttachmentCatalog.local_item_instance_from_data(target, item_data, slot_name)

        if local_item then
          target.loadout[slot_name] = local_item
          target.visual_loadout[slot_name] = local_item
        end
      elseif item_data.local_weapon == true or is_weapon_slot(slot_name) then
        local local_item = WeaponCatalog.local_item_instance_from_data(target, item_data, slot_name)

        if local_item then
          target.loadout[slot_name] = local_item
          target.visual_loadout[slot_name] = local_item
        end
      end
    end
  end

  return target
end

local function character_id(profile)
  local archetype = profile and profile.archetype

  return profile and profile.character_id
    or type(archetype) == "table" and archetype.name
    or archetype
    or "unknown"
end

local function loadouts_file_path(profile)
  return Storage.base_dir() .. "/loadouts_" .. character_id(profile) .. ".json"
end

local function archetype_name(profile)
  local archetype = profile and profile.archetype

  return type(archetype) == "table" and archetype.name or archetype
end

local function compact_profile(profile)
  return {
    content_requirements = clone_table(profile.content_requirements),
    loadout_item_ids = clone_table(profile.loadout_item_ids),
    loadout_item_data = clone_table(profile.loadout_item_data)

  }
end

function Storage.rebuild_profile(profile)
  local selected_nodes = clone_table(profile.selected_nodes)
  local talents = clone_table(profile.talents)
  local ok, rebuilt = pcall(function ()
    return ProfileUtils.unpack_profile(ProfileUtils.pack_profile(profile))
  end)

  if not ok or not rebuilt then
    return profile
  end

  -- ProfileUtils.unpack_profile may not rebuild the local selected_nodes
  -- / talents tables. They are opaque character data and
  -- must survive the pack/unpack roundtrip, otherwise switching a preset
  -- or applying equipment can clear the character’s equipped talents.
  rebuilt.selected_nodes = selected_nodes
  rebuilt.talents = talents

  return rebuilt
end

local function canonicalize_profile_for_transport(profile)
  if not profile then
    return nil, "profile is unavailable"
  end

  local ok, canonical = pcall(function ()
    return ProfileUtils.unpack_profile(ProfileUtils.pack_profile(table.clone_instance(profile)))
  end)

  if not ok or not canonical then
    return nil, tostring(canonical or "profile transport conversion failed")
  end

  return canonical
end

function Storage.profile_from_loadout(base_profile, saved)
  if not saved or not saved.profile then
    return nil
  end

  local compact = saved.profile
  local profile = table.clone_instance(base_profile)

  -- Start from the current character profile so character-level slots
  -- (slot_body_*, appearance, etc.) are always present, then overlay the
  -- saved loadout slots. Official preset copies only store equipment and
  -- appearance slots, and replacing the whole table made the player model
  -- disappear when such a preset was active.
  profile.loadout_item_ids = clone_table(base_profile.loadout_item_ids) or {}

  local saved_item_ids = clone_table(compact.loadout_item_ids)

  if saved_item_ids then
    for slot_name, gear_id in pairs(saved_item_ids) do
      if gear_id == nil then
        profile.loadout_item_ids[slot_name] = nil
      else
        profile.loadout_item_ids[slot_name] = gear_id
      end
    end
  end

  profile.loadout_item_data = clone_table(base_profile.loadout_item_data) or {}

  local saved_item_data = clone_table(compact.loadout_item_data)

  if saved_item_data and next(saved_item_data) ~= nil then
    for slot_name, item_data in pairs(saved_item_data) do
      if item_data == nil then
        profile.loadout_item_data[slot_name] = nil
      else
        profile.loadout_item_data[slot_name] = item_data
      end
    end
  end

  profile.loadout = profile.loadout or {}
  profile.visual_loadout = profile.visual_loadout or {}

  for slot_name, item_data in pairs(profile.loadout_item_data or {}) do
    if type(item_data) == "table" and item_data.local_item then
      if item_data.local_attachment == true then
        local local_item = AttachmentCatalog.local_item_instance_from_data(profile, item_data, slot_name)

        if local_item then
          profile.loadout[slot_name] = local_item
          profile.visual_loadout[slot_name] = local_item
        end
      elseif item_data.local_weapon == true or is_weapon_slot(slot_name) then
        local local_item = WeaponCatalog.local_item_instance_from_data(profile, item_data, slot_name)

        if local_item then
          profile.loadout[slot_name] = local_item
          profile.visual_loadout[slot_name] = local_item
        end
      end
    end
  end

  -- Legacy talent/Stimm fields are ignored. Equipment presets never own
  -- either tree and therefore cannot restore an old talent selection.
  local rebuilt = Storage.rebuild_profile(profile)
  if rebuilt then rebuild_local_item_instances(profile, rebuilt) end

  return rebuilt
end

local function inventory_fingerprint(inventory_items)
  local gear_ids = {}

  for gear_id in pairs(inventory_items) do
    gear_ids[#gear_ids + 1] = tostring(gear_id)
  end

  table.sort(gear_ids)

  return table.concat(gear_ids, "|")
end

function Storage.cache_inventory_items(profile, inventory_items)
  if not inventory_items then
    return
  end

  local profile_character_id = character_id(profile)
  local cache = mod._realms_loadout_inventory_items or {}
  local fingerprints = mod._realms_loadout_inventory_fingerprints or {}
  local fingerprint = inventory_fingerprint(inventory_items)
  local previous_fingerprint = fingerprints[profile_character_id]

  -- Official inventory changed since the previous snapshot. Drop the cached
  -- catalogs so the next sync performs the usual add-only refresh: existing
  -- local copies are kept, newly acquired official weapons are appended.
  if fingerprint and previous_fingerprint and fingerprint ~= previous_fingerprint then
    mod:info("realms_loadout official inventory changed, resetting local catalogs")

    WeaponCatalog.reset_cache()
    AttachmentCatalog.reset_cache()
  end

  if fingerprint then
    fingerprints[profile_character_id] = fingerprint
  end

  cache[profile_character_id] = inventory_items
  mod._realms_loadout_inventory_items = cache
  mod._realms_loadout_inventory_fingerprints = fingerprints

  if not (mod._weapon_catalog_cache and mod._weapon_catalog_character_id == profile_character_id and mod._weapon_catalog_cache.synced == true) then
    local ok, weapon_catalog_error = pcall(WeaponCatalog.sync_from_official, profile, inventory_items)

    if not ok then
      mod:warning("realms_loadout failed to rebuild local weapon catalog: %s", tostring(weapon_catalog_error))
    end
  end
end

function Storage.reset_inventory_catalogs()
  WeaponCatalog.reset_cache()
  AttachmentCatalog.reset_cache()
end

function Storage.cached_inventory_items(profile)
  local cache = mod._realms_loadout_inventory_items

  return cache and profile and cache[character_id(profile)] or nil
end

function Storage.first_official_preset_profile(base_profile, inventory_items)
  local presets = ProfileUtils.get_profile_presets and ProfileUtils.get_profile_presets() or {}
  local preset = presets and presets[1]

  if not preset then
    return Storage.rebuild_profile(base_profile)
  end

  local profile = table.clone_instance(base_profile)

  profile.loadout_item_ids = clone_table(base_profile.loadout_item_ids) or {}
  profile.loadout_item_data = clone_table(base_profile.loadout_item_data) or {}

  local preset_loadout = preset.loadout or {}

  for slot_name, gear_id in pairs(preset_loadout) do
    profile.loadout_item_ids[slot_name] = gear_id

    local gear = inventory_items and inventory_items[gear_id]
    local gear_data = gear and (gear.gear or gear.__gear or gear)
    local master_data = gear_data and gear_data.masterDataInstance

    if master_data and master_data.id then
      profile.loadout_item_data[slot_name] = {
        id = master_data.id,
        overrides = master_data.overrides and clone_table(master_data.overrides) or nil
      }
    else
      profile.loadout_item_data[slot_name] = nil
    end
  end

  return Storage.rebuild_profile(profile)
end

function Storage.realms_preparation_waiting()
  local realms_mod = get_mod("Realms")
  local preparation = realms_mod and realms_mod._preparation

  return preparation and type(preparation.is_waiting) == "function" and preparation:is_waiting() or false
end

function Storage.apply_first_official_preset(base_profile, inventory_items)
  local fallback = Storage.first_official_preset_profile(base_profile, inventory_items)

  return Storage.apply_profile_to_game(fallback)
end

function Storage.apply_first_official_preset_async(base_profile)
  local inventory_items = Storage.cached_inventory_items(base_profile)

  if inventory_items then
    return Storage.apply_first_official_preset(base_profile, inventory_items)
  end

  if mod._official_fallback_pending then
    return false, "official fallback is already pending"
  end

  local gear = Managers.data_service and Managers.data_service.gear
  local profile_character_id = base_profile and base_profile.character_id

  if not gear or type(gear.fetch_inventory) ~= "function" or not profile_character_id then
    return false, "official fallback inventory is unavailable"
  end

  mod._official_fallback_pending = true

  local ok, promise = pcall(function ()
    return gear:fetch_inventory(profile_character_id)
  end)

  if not ok or not promise or type(promise.next) ~= "function" then
    mod._official_fallback_pending = false

    return false, "official fallback inventory fetch failed"
  end

  promise:next(function (fetched_items)
    mod._official_fallback_pending = false

    if not Storage.realms_preparation_waiting() then
      return
    end

    Storage.cache_inventory_items(base_profile, fetched_items)
    Storage.apply_active_on_host()
  end):catch(function ()
    mod._official_fallback_pending = false
  end)

  return true, "official fallback is pending"
end

-- Refresh only on an explicit equipment-page open, including external edits.
function Storage.refresh_loadouts_cache()
  mod._loadouts_cache = nil
  mod._persisted_json = nil
end

function Storage.loadouts_data(profile)
  local path = loadouts_file_path(profile)
  mod._loadouts_cache = mod._loadouts_cache or {}
  local data = mod._loadouts_cache[path]
  if not data then
    data = read_json(path)
    -- An existing file is authoritative, even when every slot was deleted.
    -- Older files had no import marker; do not repopulate or prune them.
    if type(data) == "table" and data.presets_initialized == nil then data.presets_initialized = true end
  end

  if not data or type(data) ~= "table" then
    data = {
      version = 2,
      presets_initialized = false,
      active_id = nil,
      applied = false,
      loadouts = {}
    }
  end

  data.loadouts = data.loadouts or {}
  data.applied = data.applied == true

  mod._loadouts_cache[path] = data
  return data, path
end

local CHARACTER_SLOT_PREFIX = "slot_body_"

local function merge_character_slots(loadouts, profile)
  -- Character appearance/body slots are not part of official loadout presets,
  -- so older saved presets may lack them. Always fill them from the current
  -- character profile, otherwise UiProfileSpawner has no body to present.
  local base_item_ids = profile and profile.loadout_item_ids
  local base_item_data = profile and profile.loadout_item_data

  for i = 1, #loadouts do
    local loadout = loadouts[i]
    local compact = loadout and loadout.profile

    if compact then
      local saved_item_ids = compact.loadout_item_ids

      if not saved_item_ids then
        saved_item_ids = {}
        compact.loadout_item_ids = saved_item_ids
      end

      local saved_item_data = compact.loadout_item_data

      if not saved_item_data then
        saved_item_data = {}
        compact.loadout_item_data = saved_item_data
      end

      for slot_name, gear_id in pairs(base_item_ids or {}) do
        if string.sub(slot_name, 1, #CHARACTER_SLOT_PREFIX) == CHARACTER_SLOT_PREFIX and saved_item_ids[slot_name] == nil then
          saved_item_ids[slot_name] = gear_id
        end
      end

      for slot_name, item_data in pairs(base_item_data or {}) do
        if string.sub(slot_name, 1, #CHARACTER_SLOT_PREFIX) == CHARACTER_SLOT_PREFIX and saved_item_data[slot_name] == nil then
          saved_item_data[slot_name] = item_data
        end
      end
    end
  end
end

function Storage.ensure_initialized(profile)

  local data, path = Storage.loadouts_data(profile)
  local loadouts = data.loadouts

  merge_character_slots(loadouts, profile)

  if #loadouts == 0 and not data.presets_initialized then
    local id = "local-" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))

    loadouts[1] = {
      id = id,
      name = mod:localize("loadout_default_name"),
      seed_nodes = clone_table(profile.selected_nodes) or {},
      profile = compact_profile(profile)
    }

    data.active_id = id
    data.applied = false
  end

  data.active_id = data.active_id or loadouts[1] and loadouts[1].id or nil
  data.presets_initialized = true

  return write_json(path, data)
end

function Storage.get_active_loadout(profile)
  local data = Storage.loadouts_data(profile)
  local active_id = data.active_id

  for i = 1, #data.loadouts do
    if data.loadouts[i].id == active_id then
      return data.loadouts[i]
    end
  end

  return data.loadouts[1]
end

local function current_local_profile()
  local player = Managers.player and Managers.player:local_player_safe(1)

  return player and player:profile()
end

function Storage.get_profile_presets()
  local profile = current_local_profile()

  if not profile then
    return {}
  end

  return Storage.loadouts_data(profile).loadouts
end

function Storage.get_active_profile_preset_id()
  local profile = current_local_profile()

  if not profile then
    return nil
  end

  return Storage.loadouts_data(profile).active_id
end

function Storage.get_profile_preset(profile_preset_id)
  local loadouts = Storage.get_profile_presets()

  for i = 1, #loadouts do
    if loadouts[i].id == profile_preset_id then
      return loadouts[i]
    end
  end

  return nil
end

function Storage.save_active_profile_preset_id(profile_preset_id)
  local profile = current_local_profile()

  if not profile then
    return false, "no local player"
  end

  local data, path = Storage.loadouts_data(profile)

  data.active_id = profile_preset_id

  return write_json(path, data)
end

function Storage.add_profile_preset(profile, name)
  if not profile then
    profile = current_local_profile()
  end

  if not profile then
    return nil
  end

  Storage.ensure_initialized(profile)

  local data, path = Storage.loadouts_data(profile)
  local id = "local-" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))

  if not name then
    name = mod:localize("loadout_default_name") .. " " .. tostring(#data.loadouts + 1)
  end

  data.loadouts[#data.loadouts + 1] = {
    id = id,
    name = name,
    seed_nodes = clone_table(profile.selected_nodes) or {},
    profile = compact_profile(profile)
  }

  write_json(path, data)

  return id
end

function Storage.set_profile_preset_profile(profile_preset_id, profile)
  local player_profile = current_local_profile()

  if not player_profile then
    return false
  end

  local data, path = Storage.loadouts_data(player_profile)

  for i = 1, #data.loadouts do
    if data.loadouts[i].id == profile_preset_id then
      data.loadouts[i].profile = compact_profile(profile)

      write_json(path, data)

      return true
    end
  end

  return false
end

function Storage.remove_profile_preset(profile_preset_id)
  local profile = current_local_profile()

  if not profile then
    return false
  end

  local data, path = Storage.loadouts_data(profile)

  for i = 1, #data.loadouts do
    if data.loadouts[i].id == profile_preset_id then
      table.remove(data.loadouts, i)

      if data.active_id == profile_preset_id then
        data.active_id = data.loadouts[1] and data.loadouts[1].id or nil
      end

      write_json(path, data)

      return true
    end
  end

  return false
end

function Storage.persist_current_loadouts()
  local profile = current_local_profile()

  if not profile then
    return false
  end

  local data, path = Storage.loadouts_data(profile)

  return write_json(path, data)
end
function Storage.move_active_loadout(forward)
  local profile = current_local_profile()

  if not profile then
    return false
  end

  local data, path = Storage.loadouts_data(profile)
  local active_id = data.active_id
  local loadouts = data.loadouts

  if #loadouts < 2 or not active_id then
    return false
  end

  local active_index

  for i = 1, #loadouts do
    if loadouts[i].id == active_id then
      active_index = i

      break
    end
  end

  if not active_index then
    return false
  end

  local target_index = active_index + (forward and 1 or -1)

  if target_index < 1 or target_index > #loadouts then
    return false
  end

  local temp = loadouts[active_index]
  loadouts[active_index] = loadouts[target_index]
  loadouts[target_index] = temp

  write_json(path, data)

  return true
end
function Storage.seed_profile_presets(profile, inventory_items)
  Storage.cache_inventory_items(profile, inventory_items)
  local data, path = Storage.loadouts_data(profile)
  if data.presets_initialized then return true end
  -- Only a character with no saved local profile imports official slots.
  local presets = ProfileUtils.get_profile_presets() or {}
  local changed = false

  for preset_index = 1, #presets do
    local preset = presets[preset_index]

    if preset and preset.id then
      local already_copied = false

      for loadout_index = 1, #data.loadouts do
        if data.loadouts[loadout_index].source_preset_id == preset.id then
          already_copied = true

          break
        end
      end

      if not already_copied then
        local saved_profile = table.clone_instance(profile)

        -- Keep the current character's body/appearance slots. Official presets
        -- only describe equipment and appearance slots; clearing the whole table
        -- here produced saved profiles without slot_body_* entries, which made
        -- the preview model disappear when those presets were loaded.
        local preset_loadout = preset.loadout or {}

        for slot_name, gear_id in pairs(preset_loadout) do
          saved_profile.loadout_item_ids[slot_name] = gear_id

          local gear = inventory_items and inventory_items[gear_id]
          local gear_data = gear and (gear.gear or gear.__gear or gear)
          local master_data = gear_data and gear_data.masterDataInstance

          if master_data and master_data.id then
            saved_profile.loadout_item_data[slot_name] = {
              id = master_data.id,
              overrides = master_data.overrides and clone_table(master_data.overrides) or nil
            }
          else
            saved_profile.loadout_item_data[slot_name] = nil
          end
        end

        data.loadouts[#data.loadouts + 1] = {
          id = "preset-" .. tostring(preset.id),
          name = (get_mod("LoadoutNames") and get_mod("LoadoutNames"):get(preset.id)) or preset.name or string.format("%s %d", mod:localize("loadout_preset_name"), preset_index),
          custom_icon_key = preset.custom_icon_key,
          source_preset_id = preset.id,
          seed_nodes = clone_table(preset.talents) or {},
          profile = compact_profile(saved_profile)
        }

        changed = true
      end
    end
  end

  if changed then
    local active = ProfileUtils.get_active_profile_preset_id and ProfileUtils.get_active_profile_preset_id()
    for _, loadout in ipairs(data.loadouts) do
      if loadout.source_preset_id == active then data.active_id = loadout.id end
    end
    data.active_id = data.active_id or data.loadouts[1] and data.loadouts[1].id or nil
    data.presets_initialized = true
    return write_json(path, data)
  end

  if #data.loadouts == 0 then
    return Storage.ensure_initialized(profile)
  end

  return true
end
function Storage.load_working_profile(base_profile)
  local saved = Storage.get_active_loadout(base_profile)

  if not saved then
    return table.clone_instance(base_profile)
  end

  return Storage.profile_from_loadout(base_profile, saved) or table.clone_instance(base_profile)
end

function Storage.save_active_loadout(profile)
  local data, path = Storage.loadouts_data(profile)
  local active_id = data.active_id or data.loadouts[1] and data.loadouts[1].id or nil

  if not active_id then
    return false, "no active loadout"
  end

  local compact = compact_profile(profile)
  local saved = false

  for i = 1, #data.loadouts do
    if data.loadouts[i].id == active_id then
      data.loadouts[i].profile = compact
      saved = true

      break
    end
  end

  if not saved then
    return false, "active loadout not found"
  end

  data.active_id = active_id
  data.applied = true

  return write_json(path, data)
end

function Storage.prepare_inventory_view_profile(view)
  local profile = view and view._presentation_profile

  if not profile then
    return nil, "inventory profile is unavailable"
  end

  local snapshot = table.clone_instance(profile)

  return Storage.build_profile_from_loadout_items(snapshot)
end

function Storage.save_inventory_view(view)
  local snapshot, prepare_error = Storage.prepare_inventory_view_profile(view)

  if not snapshot then
    mod:warning("realms_loadout auto-save failed: %s", tostring(prepare_error or "inventory profile is unavailable"))

    return false, prepare_error or "inventory profile is unavailable"
  end

  local saved, save_error = Storage.save_active_loadout(snapshot)

  if not saved then
    mod:warning("realms_loadout auto-save failed: %s", tostring(save_error or "unknown save error"))
  end

  return saved, save_error
end

function Storage.build_profile_from_loadout_items(profile)
  local loadout = profile.loadout or {}

  profile.loadout_item_ids = {}
  profile.loadout_item_data = {}

  for slot_name, item in pairs(loadout) do
    if item then
      local gear_id = item.gear_id or item.__gear_id or slot_name
      local master_item = item.__master_item
      local master_id = item.name or master_item and master_item.name or nil
      local is_local_weapon = WeaponCatalog.is_local_weapon(item)
      local is_local_attachment = AttachmentCatalog.is_local_attachment(item)
      local is_local_item = is_local_weapon or is_local_attachment
      local source_gear_id
      local overrides

      if item.gear and item.gear.masterDataInstance and item.gear.masterDataInstance.overrides then
        overrides = table.clone_instance(item.gear.masterDataInstance.overrides)
      elseif item.overrides then
        overrides = table.clone_instance(item.overrides)
      end

      if is_local_weapon then
        local catalog_entry = item.__weapon_catalog_entry

        source_gear_id = catalog_entry and catalog_entry.source_gear_id or item.source_gear_id
      elseif is_local_attachment then
        local catalog_entry = item.__attachment_catalog_entry

        source_gear_id = catalog_entry and catalog_entry.source_gear_id or item.source_gear_id
      end

      if not master_id then
        profile.loadout_item_ids[slot_name] = nil
        profile.loadout_item_data[slot_name] = nil
      else
        local item_data = {
          id = master_id,
          overrides = overrides
        }

        profile.loadout_item_ids[slot_name] = gear_id
        profile.loadout_item_data[slot_name] = item_data

        if is_local_item then
          item_data.local_item = true
        end

        if is_local_weapon then
          item_data.local_weapon = true
          item_data.source_gear_id = source_gear_id
        end

        if is_local_attachment then
          item_data.local_attachment = true
          item_data.source_gear_id = source_gear_id
        end
      end
    end
  end

  profile.loadout_item_data.custom = true

  local selected_nodes = clone_table(profile.selected_nodes)
  local talents = clone_table(profile.talents)
  local rebuilt = Storage.rebuild_profile(profile)

  if rebuilt then
    rebuilt.selected_nodes = selected_nodes
    rebuilt.talents = talents
    reapply_local_item_markers(profile, rebuilt)
  end

  return rebuilt
end

local function realms_session()
  local realms_mod = get_mod and get_mod("Realms")

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

local function call_override_singleplay_profile(synchronizer_host, peer_id, local_player_id, profile, context)
	local apply_context = {}

	for key, value in pairs(context or {}) do
		apply_context[key] = value
	end

	apply_context.owner = "realms_loadout"
	apply_context.source = apply_context.source or "storage_apply"

	if mod._realms_profile_writes_suspended and apply_context.allow_while_suspended ~= true then
		return false, "Realms profile writes are suspended"
	end

	local player_manager = Managers.player
	local player = player_manager and player_manager:player(peer_id, local_player_id)

	if not player or player.__deleted then
		return false, "profile player is unavailable"
	end

  local previous_context = mod._realms_profile_apply_context
  mod._realms_profile_apply_context = apply_context

  local ok, err = pcall(function ()
    synchronizer_host:override_singleplay_profile(peer_id, local_player_id, profile)
  end)

  mod._realms_profile_apply_context = previous_context

  if not ok then
    return false, tostring(err)
  end

  return true
end

function Storage.exit_and_apply_inventory_view(view)
  local profile = Storage.prepare_inventory_view_profile(view)

  if not profile then
    return false, "inventory profile is unavailable"
  end

  -- Keep the currently edited loadout saved even when it is illegal. The
  -- illegal edit stays archived under its own loadout entry; it is only the
  -- profile applied to the game that is replaced below.
  local saved, save_error = Storage.save_active_loadout(profile)

  if not saved then
    return false, save_error or "failed to save local loadout"
  end

  -- Local edits must never leak into the official profile while the player is
  -- just browsing in the hub. Only an active Realms session is allowed to
  -- receive the edited loadout; otherwise restore the untouched official
  -- snapshot that was captured when the local view opened.
  if not is_realms_client() and not is_realms_host() then
    local official_profile = view._original_profile_snapshot or view._preview_player and view._preview_player:profile() or profile

    return Storage.restore_official_profile(
      official_profile,
      {
        source = "inventory_exit",
        suppress_talent_transform = true,
      }
    )
  end

  return Storage.apply_profile_to_game(profile)
end

local function realms_client_connection()
  local connection_manager = Managers.connection
  local client = connection_manager and connection_manager._connection_client

  if client and client._realms_protocol ~= nil then
    return client
  end

  return nil
end

local CLIENT_MODE_OFFICIAL = "realms_loadout_official_ui"
local CLIENT_MODE_REALMS = "realms_loadout_resume"

local function apply_profile_to_realms_client(profile, player, context)
  local client = realms_client_connection()
  local realms_mod = get_mod and get_mod("Realms")

  if not realms_mod or not client then
    return false, "Realms client connection unavailable"
  end

  local mechanism = Managers.mechanism

  if mechanism and mechanism.profile_changes_are_allowed and not mechanism:profile_changes_are_allowed() then
    return false, "profile changes are not allowed in the current Realms state"
  end

  local ok, rebuilt = pcall(function ()
    return Storage.rebuild_profile(profile)
  end)

  if not ok then
    return false, tostring(rebuilt)
  end

  rebuild_local_item_instances(profile, rebuilt)

  local outbound = rebuilt
  local client_profile_mode = context and context.client_profile_mode

  if client_profile_mode then
    outbound = table.clone_instance(rebuilt)
    outbound.tamm_custom_talents = {
      generation = context.generation,
      source = client_profile_mode == "official" and CLIENT_MODE_OFFICIAL or CLIENT_MODE_REALMS,
    }
  end

  -- Realms intercepts rpc_notify_profile_changed on clients and rebuilds the
  -- outgoing profile from backend_profile_data_to_profile(). The realms_loadout
  -- hook on ProfileUtils returns this override instead, so the edited local
  -- profile is what gets sent to the host.
  mod._client_profile_override = {
    exact = context and context.exact_profile == true,
    generation = context and context.generation,
    profile = outbound,
  }
  mod._client_profile_override_connection = client
  mod._client_profile_override_character = player:character_id()

  local sent_ok, sent_error = pcall(function ()
    Managers.connection:send_rpc_server("rpc_notify_profile_changed", player:local_player_id())
  end)

  if not sent_ok then
    mod._client_profile_override = nil

    return false, tostring(sent_error)
  end

  mod:info("Queued local Realms profile update for client player %d", player:local_player_id())

  -- extension hooks run after this point

  return true
end

local function queued_profile_for_player(synchronizer, player, peer_id)
  local updates = synchronizer and synchronizer._profile_updates
  peer_id = peer_id or player and player:peer_id()
  local by_player = updates and (updates[peer_id] or updates[tostring(peer_id):lower()])

  return by_player and by_player[player:local_player_id()] or nil
end

local function apply_profile_to_singleplay(profile, player, context)
  if not profile or profile.character_id ~= player:character_id() then
    return false, "character changed while applying profile"
  end

  local profile_synchronization = Managers.profile_synchronization
  local synchronizer_host = profile_synchronization and profile_synchronization:synchronizer_host()

  if not synchronizer_host then
    return false, "host profile synchronizer unavailable"
  end

  local ok, rebuilt = pcall(function ()
    return Storage.rebuild_profile(profile)
  end)

  if not ok then
    return false, tostring(rebuilt)
  end

  rebuild_local_item_instances(profile, rebuilt)

  local sync_ok, sync_error = call_override_singleplay_profile(
    synchronizer_host,
    Network.peer_id(),
    player:local_player_id(),
    rebuilt,
    context
  )

  if not sync_ok then
    return false, sync_error
  end

  if context and context.source == "official_ui" and context.generation then
    local queued = queued_profile_for_player(synchronizer_host, player, Network.peer_id())
    local expected = queued or rebuilt
    local target_source = queued and "host_queue" or "host_fallback"
    local target_updated, target_error = Storage.update_official_transition_target(
      expected,
      context.generation,
      target_source,
      queued ~= nil
    )

    if not target_updated then
      mod:warning(
        "realms_loadout could not bind official profile generation %s to %s: %s",
        tostring(context.generation),
        target_source,
        tostring(target_error)
      )
    end
  end

  -- extension hooks run after this point

  return true
end

local function preserve_talents(profile, current)
  if not profile or not current or profile.character_id ~= current.character_id then return nil end
  local result = table.clone_instance(profile)
  for _, key in ipairs({ "selected_nodes", "talents", "talent_points", "expertise_points",
    "rl_stimm_native_points", "tamm_custom_talents", "talent_layout_selection" }) do
    result[key] = clone_table(current[key])
  end
  return result
end
Storage.preserve_talents = preserve_talents

local LOCAL_ITEM_ID_PREFIX = "realms_local_"

local function is_local_item_id(value)
  if type(value) ~= "string" then
    return false
  end

  value = string.lower(value)

  return string.find(value, LOCAL_ITEM_ID_PREFIX, 1, true) == 1
end

local function item_has_local_marker(item)
  return type(item) == "table" and (item.local_item == true
    or item.local_weapon == true or item.local_attachment == true
    or item.__local_item == true or item.__local_weapon == true or item.__local_attachment == true
    or is_local_item_id(item.gear_id) or is_local_item_id(item.__gear_id)
    or is_local_item_id(item.id))
end

local function profile_has_local_items(profile)
  if profile and profile.loadout_item_data and profile.loadout_item_data.custom == true then
    return true
  end

  for _, item_id in pairs(profile and profile.loadout_item_ids or {}) do
    if is_local_item_id(item_id) then
      return true
    end
  end

  for _, item_data in pairs(profile and profile.loadout_item_data or {}) do
    if item_has_local_marker(item_data) then
      return true
    end
  end

  for _, item in pairs(profile and profile.loadout or {}) do
    if item_has_local_marker(item) then
      return true
    end
  end

  for _, item in pairs(profile and profile.visual_loadout or {}) do
    if item_has_local_marker(item) then
      return true
    end
  end

  return false
end

local function profile_has_local_talent_state(profile)
  return profile and (profile.tamm_custom_talents ~= nil or profile.rl_stimm_native_points ~= nil) or false
end

local function official_profile_for_player(player)
  local current = player and player:profile()

  if not current then
    return nil
  end

  if current.tamm_custom_talents and type(mod.realms_loadout_official_profile) == "function" then
    local ok, restored = pcall(mod.realms_loadout_official_profile, player)

    if ok and restored then
      current = restored
    end
  end

  if profile_has_local_talent_state(current) or profile_has_local_items(current) then
    return nil
  end

  return table.clone_instance(current)
end

local function capture_official_profile(player)
  local snapshot = mod._realms_official_profile_snapshot

  if snapshot and snapshot.character_id == player:character_id()
    and not profile_has_local_talent_state(snapshot) and not profile_has_local_items(snapshot)
  then
    return snapshot
  end

  mod._realms_official_profile_snapshot = nil

  snapshot = official_profile_for_player(player)

  if snapshot then
    mod._realms_official_profile_snapshot = snapshot
  end

  return snapshot
end

function Storage.remember_official_profile(profile)
  local player = Managers.player and Managers.player:local_player_safe(1)

  if not player then
    return false
  end

  if profile then
    if profile.character_id ~= player:character_id()
      or profile_has_local_talent_state(profile) or profile_has_local_items(profile)
    then
      return false
    end

    local snapshot = table.clone_instance(profile)

    -- This cache is the source for future switches. The in-flight verification
    -- target is bound separately to the generation and payload actually sent.
    mod._realms_official_profile_snapshot = snapshot

    return true
  end

  return capture_official_profile(player) ~= nil
end

function Storage.official_profile_write_started(player)
  local local_player = Managers.player and Managers.player:local_player_safe(1)
  local generation = mod._realms_official_ui_generation

  if mod._realms_profile_mode ~= "official" or not generation or not player or player ~= local_player then
    return nil
  end

  mod._realms_official_profile_writes = (mod._realms_official_profile_writes or 0) + 1

  return generation
end

function Storage.official_profile_write_finished(generation, succeeded)
  if generation ~= mod._realms_official_ui_generation then
    return
  end

  local writes = mod._realms_official_profile_writes or 0

  mod._realms_official_profile_writes = math.max(0, writes - 1)

  if succeeded then
    -- The backend write completing only starts native/Realms profile refresh.
    -- Do not snapshot the official profile until a later profile-updated event
    -- proves that refresh has reached the local player object.
    mod._realms_official_required_update_serial = mod._realms_official_profile_update_serial or 0
  end
end

function Storage.note_profile_updated(peer_id, local_player_id)
  local player = Managers.player and Managers.player:local_player_safe(1)

  if not player
    or string.lower(tostring(player:peer_id())) ~= string.lower(tostring(peer_id))
    or player:local_player_id() ~= local_player_id
  then
    return
  end

  mod._realms_official_profile_update_serial = (mod._realms_official_profile_update_serial or 0) + 1
end


function Storage.realms_profile_writes_allowed(context)
  local mode = mod._realms_profile_mode

  if mode ~= "switching_to_official" and mode ~= "official"
    and mode ~= "closing_official" and mode ~= "switching_to_realms"
  then
    return true
  end

  return context and context.allow_during_official == true
end

function Storage.apply_profile_to_game(profile, context)
  local player = Managers.player and Managers.player:local_player_safe(1)

  if not player then
    return false, "local player unavailable"
  end

  local manager = Managers.connection
  local connection = manager and (manager._connection_host or manager._connection_client)
  if mod._loadout_connection ~= connection then
    Storage.clear_realms_profile_state()
    mod._loadout_connection = connection
  end

  if not Storage.realms_profile_writes_allowed(context) then
    return false, "Realms profile writes are paused for the official inventory"
  end

  if not mod._realms_local_profile_applied and not capture_official_profile(player) then
    return false, "official profile snapshot unavailable"
  end

  profile = preserve_talents(profile, player:profile())
  if not profile then return false, "character changed while applying loadout" end
  local client = realms_client_connection()
  local applied, apply_error

  if is_realms_client() and client then
    local client_context = clone_table(context) or {}
    client_context.client_profile_mode = client_context.client_profile_mode or "realms"
    client_context.exact_profile = true

    applied, apply_error = apply_profile_to_realms_client(profile, player, client_context)
  elseif is_realms_host() then
    applied, apply_error = apply_profile_to_singleplay(profile, player, context)
  else
    return false, "profile application is only available in an active Realms session"
  end

  if applied then
    mod._realms_local_profile_snapshot = table.clone_instance(profile)
    mod._realms_local_profile_applied = true
    mod._realms_profile_mode = mod._realms_profile_mode == "switching_to_realms"
      and "switching_to_realms" or "realms"
  end

  return applied, apply_error
end

function Storage.restore_official_profile(profile, context)
  local player = Managers.player and Managers.player:local_player_safe(1)

  if not player then
    return false, "local player unavailable"
  end

  if not profile then
    return false, "official profile snapshot unavailable"
  end

  context = clone_table(context) or {}
  context.exact_profile = true
  context.suppress_talent_transform = true

  if is_realms_client() and realms_client_connection() then
    context.client_profile_mode = "official"

    return apply_profile_to_realms_client(profile, player, context)
  end

  return apply_profile_to_singleplay(profile, player, context)
end

local PROFILE_SWITCH_TIMEOUT = 8
local OFFICIAL_OPEN_STABLE_FRAMES = 2
local OFFICIAL_CLOSE_STABLE_FRAMES = 2

local function tables_equal(left, right, seen)
  if left == right then
    return true
  end
  if type(left) ~= type(right) then
    return false
  end
  if type(left) ~= "table" then
    return false
  end

  seen = seen or {}
  if seen[left] == right then
    return true
  end
  seen[left] = right

  for key, value in pairs(left) do
    if not tables_equal(value, right[key], seen) then
      return false
    end
  end
  for key in pairs(right) do
    if left[key] == nil then
      return false
    end
  end

  return true
end

local function profiles_match(current, target, exact)
  if not current or not target or current.character_id ~= target.character_id then
    return false
  end
  if not tables_equal(current.loadout_item_ids or {}, target.loadout_item_ids or {})
    or not tables_equal(current.loadout_item_data or {}, target.loadout_item_data or {}) then
    return false
  end
  if not exact then
    return true
  end
  if not tables_equal(current.selected_nodes or {}, target.selected_nodes or {})
    or not tables_equal(current.talents or {}, target.talents or {})
    or not tables_equal(current.talent_layout_selection or {}, target.talent_layout_selection or {})
    or current.talent_points ~= target.talent_points
    or current.expertise_points ~= target.expertise_points then
    return false
  end

  return current.tamm_custom_talents == nil and target.tamm_custom_talents == nil
end

local function pending_profile(player)
  local manager = Managers.profile_synchronization
  local synchronizer = manager and manager:synchronizer_host()

  return queued_profile_for_player(synchronizer, player)
end

local function next_profile_generation()
  mod._realms_profile_generation = (mod._realms_profile_generation or 0) + 1

  return mod._realms_profile_generation
end

local function set_transition(kind, target, request, expect_custom_talents)
  local generation = next_profile_generation()

  mod._realms_profile_transition = {
    elapsed = 0,
    expect_custom_talents = expect_custom_talents == true,
    generation = generation,
    kind = kind,
    request = request,
    stable_frames = 0,
    target = target and table.clone_instance(target) or nil,
    target_ready = kind ~= "official",
    target_source = kind ~= "official" and "initial" or nil,
  }

  return generation
end

function Storage.update_official_transition_target(profile, generation, source, already_transported)
  local transition = mod._realms_profile_transition

  if not transition or transition.kind ~= "official" or transition.generation ~= generation then
    return false, "official profile transition is stale"
  end
  local target_character_id = transition.target and transition.target.character_id

  if not profile or not target_character_id or profile.character_id ~= target_character_id then
    return false, "official profile target character changed"
  end

  local target = table.clone_instance(profile)
  local marker = target.tamm_custom_talents

  if marker ~= nil then
    if type(marker) ~= "table" or marker.source ~= CLIENT_MODE_OFFICIAL
      or marker.generation ~= generation
    then
      return false, "official profile target contains an invalid talent marker"
    end

    target.tamm_custom_talents = nil
  end

  if profile_has_local_items(target) or target.rl_stimm_native_points ~= nil then
    return false, "official profile target contains Realms loadout state"
  end

  if not already_transported then
    local canonical, canonical_error = canonicalize_profile_for_transport(target)

    if not canonical then
      return false, canonical_error
    end

    target = canonical
  end

  if profile_has_local_items(target) or profile_has_local_talent_state(target) then
    return false, "canonical official profile target contains Realms loadout state"
  end

  transition.target = target
  transition.target_ready = true
  transition.target_source = source or "unknown"
  transition.stable_frames = 0
  transition.mismatch_field = nil
  transition.mismatch_actual = nil
  transition.mismatch_expected = nil

  return true
end

local function current_profile_is_official(profile)
  return profile and not profile_has_local_talent_state(profile) and not profile_has_local_items(profile)
end

local function active_realms_profile(base_profile)
  local data = Storage.loadouts_data(base_profile)
  local saved = data.applied and Storage.get_active_loadout(base_profile) or nil

  if saved then
    return Storage.profile_from_loadout(base_profile, saved)
  end

  return Storage.rebuild_profile(table.clone_instance(base_profile))
end

function Storage.realms_profile_for_backend_update(official_profile)
  local mode = mod._realms_profile_mode

  if not mod._realms_local_profile_applied
    or mode ~= "realms" and mode ~= "switching_to_realms"
    or not is_realms_host() and not is_realms_client()
  then
    return nil
  end

  local player = Managers.player and Managers.player:local_player_safe(1)

  if not player or not official_profile or official_profile.character_id ~= player:character_id() then
    return nil
  end

  local ok, realm_profile = pcall(active_realms_profile, official_profile)

  if not ok or not realm_profile then
    return nil
  end

  realm_profile = preserve_talents(realm_profile, player:profile()) or realm_profile

  if is_realms_client() then
    realm_profile.tamm_custom_talents = {
      source = CLIENT_MODE_REALMS,
    }
  end

  return realm_profile
end

local function return_to_realms(player)
  local official_profile = mod._realms_official_profile_snapshot

  mod._pending_official_view = nil
  mod._official_ui_active = false
  mod._realms_official_ui_generation = nil
  mod._realms_official_profile_writes = 0
  mod._realms_official_required_update_serial = nil

  if not is_realms_host() and not is_realms_client() then
    mod._realms_profile_transition = nil
    mod._realms_profile_mode = nil
    mod._realms_local_profile_applied = false

    return true
  end
  if not player or not official_profile or official_profile.character_id ~= player:character_id() then
    return false, "official profile snapshot unavailable"
  end

  local previous_local = mod._realms_local_profile_snapshot
  local expect_custom_talents = previous_local and previous_local.tamm_custom_talents ~= nil
  local realm_profile = active_realms_profile(official_profile)

  if not realm_profile then
    return false, "saved Realms profile is invalid"
  end

  mod._realms_profile_mode = "switching_to_realms"
  local generation = set_transition("realms", realm_profile, nil, expect_custom_talents)
  local ok, apply_error = Storage.apply_profile_to_game(realm_profile, {
    allow_during_official = true,
    client_profile_mode = "realms",
    generation = generation,
    source = "official_ui_exit",
  })

  if not ok then
    mod._realms_profile_transition = nil
    mod._realms_profile_mode = "official"

    return false, apply_error
  end

  return true
end

function Storage.request_official_ui_open(request)
  if not is_realms_host() and not is_realms_client() then
    return false, true
  end

  local player = Managers.player and Managers.player:local_player_safe(1)

  if not player then
    return true, false, "local player unavailable"
  end

  local current = player:profile()
  local has_realms_profile = mod._realms_local_profile_applied == true
    or current and (profile_has_local_talent_state(current) or profile_has_local_items(current))

  if not has_realms_profile then
    return false, true
  end
  if mod._realms_profile_mode == "official" then
    mod._official_ui_active = true

    return false, true
  end
  if mod._realms_profile_mode == "switching_to_official" then
    mod._pending_official_view = request

    return true, true
  end
  if mod._realms_profile_mode == "switching_to_realms" or mod._realms_profile_mode == "closing_official" then
    return true, false, "profile switch is already in progress"
  end

  local official_profile = capture_official_profile(player)

  if not official_profile then
    return true, false, "official profile snapshot unavailable"
  end

  mod._realms_local_profile_snapshot = current and table.clone_instance(current) or mod._realms_local_profile_snapshot
  mod._realms_local_profile_applied = true
  mod._realms_profile_mode = "switching_to_official"
  mod._pending_official_view = request
  mod._realms_official_profile_writes = 0
  mod._realms_official_required_update_serial = nil

  local generation = set_transition("official", official_profile, request, false)
  mod._realms_official_ui_generation = generation
  local ok, apply_error = Storage.restore_official_profile(official_profile, {
    generation = generation,
    source = "official_ui",
    suppress_talent_transform = true,
  })

  if not ok then
    mod._realms_profile_transition = nil
    mod._pending_official_view = nil
    mod._realms_profile_mode = "realms"
    mod._realms_official_ui_generation = nil

    return true, false, apply_error
  end

  return true, true
end

function Storage.begin_official_ui()
  local handled, ok, request_error = Storage.request_official_ui_open(nil)

  return not handled or ok, request_error
end

function Storage.mark_official_ui_entered()
  if mod._realms_profile_mode == "official" then
    mod._official_ui_active = true
  end
end

function Storage.end_official_ui()
  if mod._realms_profile_mode ~= "official" and not mod._official_ui_active then
    return true
  end

  mod._official_ui_active = false
  mod._realms_profile_mode = "closing_official"
  set_transition("close_official", mod._realms_official_profile_snapshot, nil, false)

  return true
end

function Storage.cancel_official_ui_open()
  local mode = mod._realms_profile_mode

  if mode ~= "switching_to_official" and mode ~= "official" and mode ~= "closing_official" then
    return false
  end

  local player = Managers.player and Managers.player:local_player_safe(1)

  return return_to_realms(player)
end

function Storage.official_ui_blocks_realms_apply()
  local mode = mod._realms_profile_mode

  return mode == "switching_to_official" or mode == "official"
    or mode == "closing_official" or mode == "switching_to_realms"
end

function Storage.clear_realms_profile_state()
  mod._realms_profile_apply_context = nil
  mod._client_profile_override = nil
  mod._client_profile_override_connection = nil
  mod._client_profile_override_character = nil
  mod._realms_official_profile_snapshot = nil
  mod._realms_local_profile_snapshot = nil
  mod._realms_local_profile_applied = false
  mod._official_ui_active = false
  mod._pending_official_view = nil
  mod._realms_profile_mode = nil
  mod._realms_profile_transition = nil
  mod._realms_official_ui_generation = nil
  mod._realms_official_profile_writes = 0
  mod._realms_official_required_update_serial = nil

  return true
end

function Storage.apply_active_on_host(context)
  local player = Managers.player and Managers.player:local_player_safe(1)

  if not player then
    return false, "local player unavailable"
  end

  local profile_synchronization = Managers.profile_synchronization
  local synchronizer_host = profile_synchronization and profile_synchronization:synchronizer_host()

  if not synchronizer_host and not realms_client_connection() then
    return false, "not in a Realms session"
  end

  if not Storage.realms_profile_writes_allowed(context) then
    return false, "Realms profile writes are paused for the official inventory"
  end

  local profile = mod._realms_official_profile_snapshot or player:profile()
  local loadouts_data = Storage.loadouts_data(profile)

  if not loadouts_data.applied then
    return false, "saved Realms loadout has not been applied yet"
  end

  local saved = Storage.get_active_loadout(profile)

  if not saved then
    return false, "no saved Realms loadout"
  end

  local realm_profile = Storage.profile_from_loadout(profile, saved)

  if not realm_profile then
    return false, "saved loadout profile is invalid"
  end

  local applied, apply_error = Storage.apply_profile_to_game(realm_profile, context)

  return applied, apply_error, realm_profile
end

-- ProfileUtils.pack_profile drops loadout/visual_loadout and regenerates them
-- during unpack, so only compare the serialized source fields here.
local OFFICIAL_TRANSITION_PROFILE_FIELDS = {
  "loadout_item_ids",
  "loadout_item_data",
  "selected_nodes",
  "talents",
  "talent_layout_selection",
  "talent_points",
  "expertise_points",
  "rl_stimm_native_points",
}
local PROFILE_NUMBER_EPSILON = 1e-9

local function empty_profile_table(value)
  return type(value) == "table" and next(value) == nil
end

local function profile_table_value(value, key)
  local child = value[key]

  if child ~= nil then
    return child, true
  end

  if type(key) == "number" then
    child = value[tostring(key)]
  elseif type(key) == "string" then
    local numeric_key = tonumber(key)

    if numeric_key then
      child = value[numeric_key]
    end
  end

  return child, child ~= nil
end

local function profile_value_path(path, key)
  local key_string = tostring(key)

  if string.match(key_string, "^[%a_][%w_]*$") then
    return path .. "." .. key_string
  end

  return path .. "[" .. key_string .. "]"
end

local function stable_profile_value_matches(current_value, target_value, seen, path)
  path = path or "profile"

  if current_value == target_value then
    return true
  end

  if current_value == nil and empty_profile_table(target_value)
    or target_value == nil and empty_profile_table(current_value)
  then
    return true
  end

  local current_type = type(current_value)
  local target_type = type(target_value)

  if current_type == "number" and target_type == "number" then
    -- CJSON can change the final binary digits of an otherwise identical item
    -- override. Keep the tolerance far below any meaningful profile value.
    local difference = math.abs(current_value - target_value)
    local scale = math.max(1, math.abs(current_value), math.abs(target_value))

    if difference <= PROFILE_NUMBER_EPSILON * scale then
      return true
    end

    return false, path, current_value, target_value
  end

  if current_type ~= target_type or current_type ~= "table" then
    return false, path, current_value, target_value
  end

  seen = seen or {}

  local seen_target = seen[current_value]

  if seen_target then
    if seen_target == target_value then
      return true
    end

    return false, path, current_value, target_value
  end

  seen[current_value] = target_value

  for key, current_child in pairs(current_value) do
    local child_type = type(current_child)

    if child_type ~= "function" and child_type ~= "thread" and child_type ~= "userdata" then
      local target_child, target_has_key = profile_table_value(target_value, key)
      local child_path = profile_value_path(path, key)

      if not target_has_key then
        return false, child_path, current_child, nil
      end

      local matches, mismatch_path, actual, expected = stable_profile_value_matches(
        current_child,
        target_child,
        seen,
        child_path
      )

      if not matches then
        return false, mismatch_path, actual, expected
      end
    end
  end

  for key, target_child in pairs(target_value) do
    local child_type = type(target_child)

    if child_type ~= "function" and child_type ~= "thread" and child_type ~= "userdata" then
      local _, current_has_key = profile_table_value(current_value, key)

      if not current_has_key then
        return false, profile_value_path(path, key), nil, target_child
      end
    end
  end

  return true
end

local function official_transition_profiles_match(current_profile, target_profile, generation)
  if not current_profile or not target_profile
    or current_profile.character_id ~= target_profile.character_id
  then
    return false, "profile.character_id",
      current_profile and current_profile.character_id,
      target_profile and target_profile.character_id
  end

  if profile_has_local_items(current_profile) then
    return false, "local_items"
  end

  if profile_has_local_items(target_profile) or profile_has_local_talent_state(target_profile) then
    return false, "target_local_state"
  end

  if current_profile.rl_stimm_native_points ~= nil then
    return false, "profile.rl_stimm_native_points", current_profile.rl_stimm_native_points, nil
  end

  local talent_marker = current_profile.tamm_custom_talents

  if talent_marker ~= nil and (type(talent_marker) ~= "table"
    or talent_marker.source ~= CLIENT_MODE_OFFICIAL
    or talent_marker.generation ~= generation)
  then
    return false, "profile.tamm_custom_talents", talent_marker, nil
  end

  if profiles_match(current_profile, target_profile, true) then
    return true, nil
  end

  for i = 1, #OFFICIAL_TRANSITION_PROFILE_FIELDS do
    local field = OFFICIAL_TRANSITION_PROFILE_FIELDS[i]
    local matches, mismatch_path, actual, expected = stable_profile_value_matches(
      current_profile[field],
      target_profile[field],
      nil,
      "profile." .. field
    )

    if not matches then
      return false, mismatch_path, actual, expected
    end
  end

  return true, nil
end

local function profile_mismatch_value(value)
  if value == nil then
    return "nil"
  end
  if type(value) == "table" then
    return "<table>"
  end

  local result = tostring(value)

  if #result > 120 then
    return string.sub(result, 1, 117) .. "..."
  end

  return result
end

function Storage.update_profile_transition(dt)
  local transition = mod._realms_profile_transition

  if not transition then
    return nil
  end

  local player = Managers.player and Managers.player:local_player_safe(1)

  if not player or (transition.target and player:character_id() ~= transition.target.character_id) then
    Storage.clear_realms_profile_state()

    return nil, "local player changed during profile switch"
  end

  transition.elapsed = transition.elapsed + (dt or 0)

  if transition.kind == "official" then
    local profile_matches = false
    local mismatch_field = "target_unavailable"
    local mismatch_actual
    local mismatch_expected = transition.target_source

    if transition.target_ready then
      profile_matches, mismatch_field, mismatch_actual, mismatch_expected = official_transition_profiles_match(
        player:profile(),
        transition.target,
        transition.generation
      )
    end

    local pending = pending_profile(player)

    if profile_matches and pending then
      profile_matches = false
      mismatch_field = "pending_profile"
      mismatch_actual = true
      mismatch_expected = false
    end

    transition.mismatch_field = mismatch_field
    transition.mismatch_actual = mismatch_actual
    transition.mismatch_expected = mismatch_expected
    transition.pending_profile = pending ~= nil

    if profile_matches then
      transition.stable_frames = transition.stable_frames + 1
    else
      transition.stable_frames = 0
    end

    if transition.stable_frames >= OFFICIAL_OPEN_STABLE_FRAMES then
      local request = mod._pending_official_view or transition.request

      mod._realms_profile_transition = nil
      mod._pending_official_view = nil
      mod._realms_profile_mode = "official"
      mod._official_ui_active = true

      return request
    end
  elseif transition.kind == "close_official" then
    local ui_waiting = Managers.ui and type(Managers.ui.get_client_loadout_waiting_state) == "function"
      and Managers.ui:get_client_loadout_waiting_state()
    local pending = pending_profile(player)
    local writes_pending = (mod._realms_official_profile_writes or 0) > 0
    local required_serial = mod._realms_official_required_update_serial
    local profile_updated = required_serial == nil
      or (mod._realms_official_profile_update_serial or 0) > required_serial

    if not ui_waiting and not pending and not writes_pending and profile_updated then
      transition.stable_frames = transition.stable_frames + 1
    else
      transition.stable_frames = 0
    end

    if transition.stable_frames >= OFFICIAL_CLOSE_STABLE_FRAMES or transition.elapsed >= PROFILE_SWITCH_TIMEOUT then
      local current = player:profile()

      if current_profile_is_official(current) then
        mod._realms_official_profile_snapshot = table.clone_instance(current)
      else
        mod:warning("realms_loadout kept the previous official profile because the closing view still exposed a Realms profile")
      end

      local returned, return_error = return_to_realms(player)

      if not returned then
        return nil, return_error
      end

      return nil
    end
  elseif transition.kind == "realms" then
    local current = player:profile()
    local matches = profiles_match(current, transition.target, false)

    if matches and (not transition.expect_custom_talents or current.tamm_custom_talents ~= nil) then
      mod._realms_profile_transition = nil
      mod._realms_profile_mode = "realms"
      mod._realms_local_profile_snapshot = table.clone_instance(current)

      return nil
    end
  end

  local official_is_stabilizing = transition.kind == "official" and transition.stable_frames > 0

  if transition.elapsed >= PROFILE_SWITCH_TIMEOUT and transition.kind ~= "close_official"
    and not official_is_stabilizing
  then
    local kind = transition.kind
    local mismatch_field = transition.mismatch_field
    local mismatch_actual = transition.mismatch_actual
    local mismatch_expected = transition.mismatch_expected
    local generation = transition.generation
    local target_source = transition.target_source
    local pending = transition.pending_profile == true
    local stable_frames = transition.stable_frames or 0
    local current = player:profile()
    local marker = current and current.tamm_custom_talents
    local marker_source = type(marker) == "table" and marker.source or marker

    mod._realms_profile_transition = nil
    mod._pending_official_view = nil

    if kind == "official" then
      local returned, return_error = return_to_realms(player)

      if not returned then
        mod._realms_profile_mode = "profile_error"

        return nil, return_error
      end
    else
      mod._realms_profile_mode = "profile_error"
    end

    if kind == "official" then
      return nil, string.format(
        "%s profile switch timed out (generation: %s, target: %s, mismatch: %s, expected: %s, actual: %s, pending: %s, marker: %s, stable_frames: %d)",
        kind,
        tostring(generation),
        tostring(target_source or "unbound"),
        tostring(mismatch_field or "unknown"),
        profile_mismatch_value(mismatch_expected),
        profile_mismatch_value(mismatch_actual),
        tostring(pending),
        tostring(marker_source or "nil"),
        stable_frames
      )
    end

    return nil, kind .. " profile switch timed out"
  end

  return nil
end

mod._module_Storage = Storage
return Storage

