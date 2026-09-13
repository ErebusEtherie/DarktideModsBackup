local mod = get_mod("realms_loadout")
if mod._module_WeaponCatalog then return mod._module_WeaponCatalog end

local MasterItems = require("scripts/backend/master_items")
local WeaponTraitTemplates = require("scripts/settings/equipment/weapon_traits/weapon_trait_templates")
local WeaponUnlockSettings = require("scripts/settings/weapon_unlock/weapon_unlock_settings")

local _io = Mods.lua.io
local _os = Mods.lua.os

local WeaponCatalog = {}

local CATALOG_VERSION = 1

local WEAPON_SLOTS = {
  slot_primary = true,
  slot_secondary = true,
}

local HUMAN_BREED = "human"
local CRYPTIC_BREED = "cryptic"
local HUMAN_WEAPON_SOURCE_PREFIX = "realms_human_weapon_"

local function is_human_like_breed(breed)
  return breed == HUMAN_BREED or breed == CRYPTIC_BREED
end


local FORGE_OBTAIN_RARITY = 6
local FORGE_OBTAIN_ITEM_LEVEL = 700
local FORGE_OBTAIN_CHARACTER_LEVEL = 1
local FORGE_OBTAIN_SOURCE_PREFIX = "realms_"


local function base_dir()
  if not mod._local_weapon_catalog_base_dir then
    local appdata = _os and _os.getenv and _os.getenv("APPDATA") or ""
    mod._local_weapon_catalog_base_dir = appdata .. "/Fatshark/Darktide/realms_loadout"
  end

  return mod._local_weapon_catalog_base_dir
end

local function ensure_dir(path)
  local ok, run_error = pcall(_os.execute, 'mkdir "' .. path .. '" 2>nul')

  if not ok then
    mod:error("realms_loadout failed to create weapon catalog directory %s: %s", path, tostring(run_error))
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
    mod:warning("realms_loadout failed to parse weapon catalog %s: %s", file_path, tostring(decoded))

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

local function sanitize_value(value, seen, depth)
  local value_type = type(value)

  if value_type == "table" then
    if depth > 12 or seen[value] then
      return nil
    end

    seen[value] = true

    local result = {}

    for key, child in pairs(value) do
      local safe_key = sanitize_value(key, seen, depth + 1)
      local safe_child = sanitize_value(child, seen, depth + 1)

      if safe_key ~= nil and safe_child ~= nil then
        result[safe_key] = safe_child
      end
    end

    seen[value] = nil

    return result
  elseif value_type == "function" or value_type == "userdata" or value_type == "thread" or value_type == "cdata" then
    return nil
  end

  return value
end

local function new_forge_source_gear_id()
  local ok, generated = pcall(math.uuid)
  local uuid

  if ok and generated then
    uuid = tostring(generated)
  else
    uuid = tostring(os.time() or 0)

    local sequence = tonumber(mod._forge_obtain_sequence) or 0

    sequence = sequence + 1
    mod._forge_obtain_sequence = sequence

    uuid = uuid .. "_" .. tostring(sequence)
  end

  if string.sub(uuid, 1, #FORGE_OBTAIN_SOURCE_PREFIX) ~= FORGE_OBTAIN_SOURCE_PREFIX then
    uuid = FORGE_OBTAIN_SOURCE_PREFIX .. uuid
  end

  return uuid
end

local function copy_selected_forge_slots(slots)
  local selected = {}

  if type(slots) ~= "table" then
    return selected
  end

  for i = 1, #slots do
    local slot = slots[i]

    if type(slot) == "table" and slot.id ~= nil and slot.id ~= "" then
      local copied_slot = {
        id = slot.id,
        rarity = slot.rarity or 0
      }

      if slot.value ~= nil then
        copied_slot.value = slot.value
      end

      selected[#selected + 1] = copied_slot
    end
  end

  return selected
end

local function valid_forge_traits(slots)
  local valid = {}

  if type(slots) ~= "table" then
    return valid
  end

  for i = 1, #slots do
    local slot = slots[i]

    if type(slot) == "table" and slot.id ~= nil and slot.id ~= "" then
      local trait_item = MasterItems.get_item(slot.id)
      local trait_name = trait_item and trait_item.trait

      if trait_name and WeaponTraitTemplates[trait_name] then
        valid[#valid + 1] = {
          id = slot.id,
          rarity = slot.rarity or 0
        }

        if slot.value ~= nil then
          valid[#valid].value = slot.value
        end
      end
    end
  end

  return valid
end


local function copy_forge_base_stats(base_stats, stat_cap)
  local copied_stats = {}

  if type(base_stats) ~= "table" then
    return copied_stats
  end

  stat_cap = tonumber(stat_cap) or 1
  stat_cap = math.min(1, math.max(0, stat_cap))

  for i = 1, #base_stats do
    local stat = base_stats[i]

    if type(stat) == "table" and stat.name ~= nil and stat.name ~= "" then
      local value = tonumber(stat.value) or 0

      value = math.floor(math.min(stat_cap, math.max(0, value)) * 100 + 0.5) / 100

      copied_stats[#copied_stats + 1] = {
        name = stat.name,
        value = value
      }
    end
  end

  return copied_stats
end

local function forge_base_item_level(base_stats)
  local total = 0

  for i = 1, #base_stats do
    total = total + base_stats[i].value
  end

  return math.floor(total * 100 + 0.5)
end

local function first_forge_slot_name(slots)
  local slot_list = slots

  if type(slot_list) ~= "table" then
    slot_list = slot_list and { slot_list } or {}
  end

  for i = 1, #slot_list do
    local slot_name = slot_list[i]

    if WEAPON_SLOTS[slot_name] then
      return slot_name
    end
  end

  return nil
end

local function character_id(profile)
  local archetype = profile and profile.archetype

  return profile and profile.character_id
    or type(archetype) == "table" and archetype.name
    or archetype
    or "unknown"
end

local function catalog_path(profile)
  return base_dir() .. "/weapon_catalog_" .. character_id(profile) .. ".json"
end

local function attach_by_source(catalog)
  if not catalog then
    return catalog
  end

  catalog.items = catalog.items or {}
  catalog.by_source = {}

  for i = 1, #catalog.items do
    local item = catalog.items[i]

    if item and item.source_gear_id then
      if item.origin ~= "official" and item.origin ~= "local" then
        if tostring(item.source_gear_id):match("^realms_") then
          item.origin = "local"
        else
          item.origin = "official"
        end
      end

      catalog.by_source[item.source_gear_id] = item
    end
  end

  return catalog
end

local function normalize_list(value)
  if type(value) ~= "table" then
    return value and { value } or {}
  end

  return value
end

local function human_archetype_names()
  local Archetypes = require("scripts/settings/archetype/archetypes")
  local names = {}

  if type(Archetypes) == "table" then
    for archetype_name, archetype in pairs(Archetypes) do
      if type(archetype) == "table" and is_human_like_breed(archetype.breed) then
        names[#names + 1] = archetype_name
      end
    end
  end

  table.sort(names)

  return names
end

local function human_weapon_levels_by_name()
  local human_archetypes = human_archetype_names()
  local archetype_names = {}

  for i = 1, #human_archetypes do
    archetype_names[human_archetypes[i]] = true
  end

  local levels = {}

  for archetype_name, level_unlocks in pairs(WeaponUnlockSettings or {}) do
    if archetype_names[archetype_name] and type(level_unlocks) == "table" then
      for weapon_level, weapon_list in ipairs(level_unlocks) do
        if type(weapon_list) == "table" then
          for i = 1, #weapon_list do
            local weapon_name = weapon_list[i]
            local previous_level = levels[weapon_name]

            if not previous_level or weapon_level < previous_level then
              levels[weapon_name] = weapon_level
            end
          end
        end
      end
    end
  end

  return levels
end

local function is_human_weapon_master_item(master_item)
  if type(master_item) ~= "table" then
    return false
  end

  local slots = normalize_list(master_item.slots)

  for i = 1, #slots do
    if WEAPON_SLOTS[slots[i]] then
      local breeds = normalize_list(master_item.breeds)

      for i = 1, #breeds do
        if is_human_like_breed(breeds[i]) then
          return true
        end
      end

      return false
    end
  end

  return false
end

local function build_human_weapon_entries()
  local human_archetypes = human_archetype_names()
  local levels_by_name = human_weapon_levels_by_name()
  local entries = {}

  for item_name, weapon_level in pairs(levels_by_name) do
    local master_item = MasterItems.get_item(item_name)

    if master_item and is_human_weapon_master_item(master_item) then
      local entry = sanitize_value(master_item, {}, 0) or {}

      entry.source_gear_id = HUMAN_WEAPON_SOURCE_PREFIX .. item_name
      entry.id = master_item.name or item_name
      entry.name = master_item.name or item_name
      entry.slots = normalize_list(master_item.slots)
      entry.origin = "official"
      entry.unrestricted_human = true
      entry.weapon_level_requirement = weapon_level or 1
      entry.__master_item = table.clone_instance(entry)
      entry.__master_item.archetypes = table.clone_instance(human_archetypes)
      entry.__master_item.breeds = { HUMAN_BREED, CRYPTIC_BREED }
      entry.archetypes = table.clone_instance(human_archetypes)
      entry.breeds = { HUMAN_BREED, CRYPTIC_BREED }

      entries[#entries + 1] = entry
    end
  end

  table.sort(entries, function (a, b)
    return (a.name or "") < (b.name or "")
  end)

  return entries
end

local function entry_from_official_item(item)
  if type(item) ~= "table" then
    return nil
  end

  local source_gear_id = item.gear_id

  if not source_gear_id then
    return nil
  end

  local slots = item.slots

  if type(slots) ~= "table" then
    slots = slots and { slots } or {}
  end

  local is_weapon = false

  for i = 1, #slots do
    if WEAPON_SLOTS[slots[i]] then
      is_weapon = true

      break
    end
  end

  if not is_weapon then
    return nil
  end

  local gear_data = item.gear or item.__gear
  local master_data = gear_data and gear_data.masterDataInstance
  local master_id = item.name or master_data and master_data.id

  if not master_id then
    return nil
  end

  local entry = sanitize_value(item, {}, 0) or {}

  entry.source_gear_id = source_gear_id
  entry.id = master_id
  entry.name = master_id
  entry.slots = sanitize_value(slots, {}, 0) or {}
  entry.overrides = master_data and master_data.overrides and sanitize_value(master_data.overrides, {}, 0) or item.overrides and sanitize_value(item.overrides, {}, 0) or nil
  entry.origin = "official"

  return entry
end

local function save_catalog(profile, catalog)

  local path = catalog_path(profile)
  local disk_items = {}

  if type(catalog.items) == "table" then
    for i = 1, #catalog.items do
      local item = catalog.items[i]

      if type(item) == "table" and item.origin ~= "external" then
        disk_items[#disk_items + 1] = item
      end
    end
  end

  local disk_data = {
    version = catalog.version,
    generated_at = catalog.generated_at,
    initialized = catalog.initialized == true,
    items = disk_items,
  }

  return write_json(path, disk_data)
end

-- Canonical stat orders are cached in a small side file so weapons this
-- character no longer owns (but another character still does) keep their order.
local BASE_STAT_ORDER_CACHE_FILE = "base_stat_orders.json"

local function base_stat_order_cache_path()
  return base_dir() .. "/" .. BASE_STAT_ORDER_CACHE_FILE
end

local function load_base_stat_orders()
  if type(mod._base_stat_orders) == "table" then
    return mod._base_stat_orders
  end

  local orders = read_json(base_stat_order_cache_path())

  if type(orders) ~= "table" then
    orders = {}
  end

  mod._base_stat_orders = orders

  return orders
end

local function save_base_stat_orders()
  local orders = mod._base_stat_orders

  if type(orders) ~= "table" then
    return false
  end

  return write_json(base_stat_order_cache_path(), orders)
end

local function remember_base_stat_order(master_id, stats)
  if type(master_id) ~= "string" or type(stats) ~= "table" or #stats == 0 then
    return false
  end

  local names = {}

  for i = 1, #stats do
    local stat = stats[i]

    if type(stat) == "table" and type(stat.name) == "string" then
      names[#names + 1] = stat.name
    end
  end

  if #names == 0 then
    return false
  end

  local orders = load_base_stat_orders()
  local existing = orders[master_id]

  if type(existing) == "table" and #existing == #names then
    local same = true

    for i = 1, #names do
      if existing[i] ~= names[i] then
        same = false

        break
      end
    end

    if same then
      return false
    end
  end

  orders[master_id] = names

  return true
end

-- The five base stats of a weapon are stored as an array and displayed in array
-- order. Official items carry them in the game's canonical order, while the
-- forge used to invent an alphabetical one. Copy the order from an official item
-- of the same master id, exactly like the vanilla weapon marks view does.
local function base_stat_order_from_entry(entry)
  local stats = entry and entry.overrides and entry.overrides.base_stats

  if type(stats) ~= "table" or #stats == 0 then
    stats = entry and entry.__master_item and entry.__master_item.base_stats
  end

  if type(stats) ~= "table" or #stats == 0 then
    return nil
  end

  local order = {}

  for i = 1, #stats do
    local stat = stats[i]

    if type(stat) == "table" and type(stat.name) == "string" then
      order[stat.name] = order[stat.name] or i
    end
  end

  return order
end

local function reorder_base_stats(base_stats, order)
  if type(base_stats) ~= "table" or type(order) ~= "table" or #base_stats < 2 then
    return false
  end

  local sorted = {}

  for i = 1, #base_stats do
    sorted[i] = base_stats[i]
  end

  table.sort(sorted, function (a, b)
    local a_name = type(a) == "table" and a.name or nil
    local b_name = type(b) == "table" and b.name or nil
    local a_order = a_name and order[a_name] or nil
    local b_order = b_name and order[b_name] or nil

    if a_order ~= b_order then
      if a_order == nil then
        return false
      elseif b_order == nil then
        return true
      end

      return a_order < b_order
    end

    return tostring(a_name) < tostring(b_name)
  end)

  local changed = false

  for i = 1, #base_stats do
    if base_stats[i] ~= sorted[i] then
      base_stats[i] = sorted[i]
      changed = true
    end
  end

  return changed
end

-- Reorders the local entries of a catalog so their base stats follow the order
-- of an official item of the same master id. Returns true when something moved.
local function migrate_base_stat_order(catalog)
  if type(catalog) ~= "table" or type(catalog.items) ~= "table" then
    return false
  end

  local orders = {}
  local cache_changed = false

  for i = 1, #catalog.items do
    local entry = catalog.items[i]

    if entry and entry.origin == "official" and type(entry.id) == "string" then
      local stats = entry.overrides and entry.overrides.base_stats

      if type(stats) ~= "table" or #stats == 0 then
        stats = entry.__master_item and entry.__master_item.base_stats
      end

      if remember_base_stat_order(entry.id, stats) then
        cache_changed = true
      end

      if not orders[entry.id] then
        orders[entry.id] = base_stat_order_from_entry(entry)
      end
    end
  end

  -- The persisted cache also covers master ids this catalog no longer holds.
  local cached = load_base_stat_orders()

  for master_id, names in pairs(cached) do
    if not orders[master_id] and type(names) == "table" and #names > 0 then
      local order = {}

      for i = 1, #names do
        order[names[i]] = i
      end

      orders[master_id] = order
    end
  end

  local changed = false

  for i = 1, #catalog.items do
    local entry = catalog.items[i]

    if entry and entry.origin == "local" and type(entry.id) == "string" then
      local order = orders[entry.id]

      if order then
        if entry.overrides and reorder_base_stats(entry.overrides.base_stats, order) then
          changed = true
        end

        if entry.__master_item and reorder_base_stats(entry.__master_item.base_stats, order) then
          changed = true
        end
      end
    end
  end

  if cache_changed then
    save_base_stat_orders()
  end

  return changed
end

-- Returns { [stat_name] = index } for the given master id, or nil when the
-- canonical order is not known yet.
function WeaponCatalog.base_stat_order(master_id)
  if type(master_id) ~= "string" then
    return nil
  end

  local orders = load_base_stat_orders()
  local names = orders[master_id]

  if type(names) ~= "table" or #names == 0 then
    return nil
  end

  local order = {}

  for i = 1, #names do
    order[names[i]] = i
  end

  return order
end

function WeaponCatalog.local_mode_enabled()
  -- Base weapon slots are always backed by the local weapon catalog.
  return true
end

function WeaponCatalog.reset_cache()
  mod._weapon_catalog_cache = nil
  mod._weapon_catalog_character_id = nil
end

function WeaponCatalog.allow_all_archetype_weapons_enabled()
  return mod:get("allow_all_archetype_weapons") == true
end

function WeaponCatalog.is_human_profile(profile)
  local archetype = profile and profile.archetype

  return archetype and is_human_like_breed(archetype.breed) or false
end

function WeaponCatalog.is_human_like_weapon(item)
  local breeds = normalize_list(item and item.breeds)

  if #breeds == 0 then
    return true
  end

  for i = 1, #breeds do
    if is_human_like_breed(breeds[i]) then
      return true
    end
  end

  return false
end

function WeaponCatalog.human_weapon_entries(profile)
  if not WeaponCatalog.is_human_profile(profile) then
    return {}
  end

  local catalog = WeaponCatalog.ensure_catalog(profile)

  if not catalog then
    return {}
  end

  catalog.by_source = catalog.by_source or {}
  attach_by_source(catalog)

  local merged = false
  local human_entries = build_human_weapon_entries()

  for i = 1, #human_entries do
    local entry = human_entries[i]
    local source_gear_id = entry and entry.source_gear_id

    if source_gear_id and not catalog.by_source[source_gear_id] then
      catalog.items[#catalog.items + 1] = entry
      catalog.by_source[source_gear_id] = entry
      merged = true
    end
  end

  if merged then
    save_catalog(profile, catalog)
    mod._weapon_catalog_cache = catalog
    mod._weapon_catalog_character_id = character_id(profile)
  end

  local entries = {}

  for i = 1, #catalog.items do
    local entry = catalog.items[i]

    if entry and entry.unrestricted_human and entry.removed ~= true then
      entries[#entries + 1] = entry
    end
  end

  return entries
end

-- Historical data migration. Local weapon entries used to get their master
-- snapshot's appearance fields overwritten from the overrides layer, which
-- cleared the official attachment tree when only an appearance slot changed.
-- Restore the missing base fields from the official master data once so the
-- saved entry becomes consistent with the current schema.
local function migrate_local_master_snapshots(profile, catalog)
  if not catalog or type(catalog) ~= "table" then
    return catalog
  end

  catalog.items = catalog.items or {}

  local changed = false

  for i = 1, #catalog.items do
    local entry = catalog.items[i]

    if entry and entry.origin == "local" and entry.id and type(entry.__master_item) == "table" then
      local master_item = MasterItems.get_item(entry.id)

      if type(master_item) == "table" then
        local repaired = false

        if type(entry.__master_item.attachments) ~= "table" and type(master_item.attachments) == "table" then
          entry.__master_item.attachments = table.clone_instance(master_item.attachments)
          repaired = true
        end

        if type(entry.__master_item.resource_dependencies) ~= "table" and type(master_item.resource_dependencies) == "table" then
          entry.__master_item.resource_dependencies = table.clone_instance(master_item.resource_dependencies)
          repaired = true
        end

        if repaired then
          changed = true
        end
      end
    end
  end

  if changed then
    save_catalog(profile, catalog)
  end

  return catalog
end

function WeaponCatalog.load_catalog(profile)
  local catalog = read_json(catalog_path(profile))

  if catalog and type(catalog) == "table" then
    catalog.synced = true
  end

  catalog = migrate_local_master_snapshots(profile, catalog)
  catalog = attach_by_source(catalog)

  if migrate_base_stat_order(catalog) then
    save_catalog(profile, catalog)
  end

  return catalog
end

function WeaponCatalog.sync_from_official(profile, inventory_items)
  if not inventory_items then
    return WeaponCatalog.load_catalog(profile)
  end

  local previous = WeaponCatalog.load_catalog(profile) or {
    version = CATALOG_VERSION,
    generated_at = 0,
    initialized = false,
    items = {},
    by_source = {},
    synced = false,
  }

  previous.by_source = previous.by_source or {}
  attach_by_source(previous)

  local seen = {}
  local items = {}

  local changed = false

  for _, item in pairs(inventory_items) do
    local entry = entry_from_official_item(item)

    if entry then
      local previous_entry = previous.by_source[entry.source_gear_id]

      seen[entry.source_gear_id] = true

      if type(previous_entry) == "table" and previous_entry.source_gear_id then
        -- This official weapon already has a local copy. Keep the local copy
        -- untouched so local-only edits survive across sessions.
        items[#items + 1] = previous_entry
      else
        -- First time this official weapon appears locally. Copy it once.
        items[#items + 1] = entry
        changed = true
      end
    end
  end

  -- Human unrestricted entries only belong in human catalogs. Non-human
  -- catalogs skip this merge and stale unrestricted entries are dropped
  -- by the cleanup loop below.
  if WeaponCatalog.is_human_profile(profile) then
    local human_entries = build_human_weapon_entries()

    for i = 1, #human_entries do
      local entry = human_entries[i]
      local previous_entry = previous.by_source[entry.source_gear_id]

      seen[entry.source_gear_id] = true

      if type(previous_entry) == "table" and previous_entry.source_gear_id then
        previous_entry.unrestricted_human = true
        previous_entry.weapon_level_requirement = previous_entry.weapon_level_requirement or entry.weapon_level_requirement
        items[#items + 1] = previous_entry
      else
        items[#items + 1] = entry
        changed = true
      end
    end
  end

  local initialized = previous.initialized == true

  -- Keep entries whose official weapon disappeared. Loadouts may still
  -- reference these local copies, and dropping them would break those slots.
  for source_gear_id, entry in pairs(previous.by_source) do
    if not seen[source_gear_id] and type(entry) == "table" and entry.source_gear_id then
      if entry.unrestricted_human then
        -- Drop stale all-human catalog entries whose weapon is no longer in
        -- any human weapon unlock list.
        changed = true
      else
        items[#items + 1] = entry
      end
    end
  end

  table.sort(items, function (a, b)
    return (a.name or "") < (b.name or "")
  end)

  local catalog = {
    version = CATALOG_VERSION,
    generated_at = changed and os.time() or previous.generated_at or os.time(),
    initialized = initialized,
    items = items,
    synced = true,
  }

  attach_by_source(catalog)

  if migrate_base_stat_order(catalog) then
    changed = true
  end

  if changed then
    save_catalog(profile, catalog)
  end

  mod._weapon_catalog_cache = catalog
  mod._weapon_catalog_character_id = character_id(profile)

  return catalog
end

function WeaponCatalog.ensure_catalog(profile)
  local profile_character_id = character_id(profile)

  if mod._weapon_catalog_cache and mod._weapon_catalog_character_id == profile_character_id and mod._weapon_catalog_cache.synced == true then
    return mod._weapon_catalog_cache
  end

  local cached_inventory = mod._realms_loadout_inventory_items and mod._realms_loadout_inventory_items[profile_character_id]

  if cached_inventory then
    return WeaponCatalog.sync_from_official(profile, cached_inventory)
  end

  local previous = WeaponCatalog.load_catalog(profile)

  if previous and type(previous) == "table" and previous.items then
    mod._weapon_catalog_cache = previous
    mod._weapon_catalog_character_id = profile_character_id

    return previous
  end

  local empty = {
    version = CATALOG_VERSION,
    generated_at = 0,
    items = {},
    by_source = {},
    synced = false,
  }

  mod._weapon_catalog_cache = empty
  mod._weapon_catalog_character_id = profile_character_id

  return empty
end


local function merge_attachment_overrides(base_attachments, override_attachments)
  if type(base_attachments) ~= "table" or type(override_attachments) ~= "table" then
    return
  end

  if override_attachments.item ~= nil then
    base_attachments.item = override_attachments.item
  end

  local base_children = base_attachments.children

  if type(base_children) ~= "table" then
    base_children = {}
    base_attachments.children = base_children
  end

  local override_children = override_attachments.children

  if type(override_children) == "table" then
    for key, override_child in pairs(override_children) do
      if type(override_child) == "table" then
        local base_child = base_children[key]

        if type(base_child) ~= "table" then
          base_child = {}
          base_children[key] = base_child
        end

        merge_attachment_overrides(base_child, override_child)
      end
    end
  end
end
local function make_local_weapon_instance(entry, slot_name)
  if not entry or not entry.id then
    return nil
  end

  local overrides = entry.overrides and table.clone_instance(entry.overrides) or {}

  -- Trimmed wire entries and older local entries keep the instance level on the
  -- entry instead of in the override layer; feed those values into the
  -- overrides so the game's instance pipeline sees a complete item.
  local inherited_keys = { "rarity", "itemLevel", "baseItemLevel", "characterLevel" }

  for i = 1, #inherited_keys do
    local key = inherited_keys[i]

    if overrides[key] == nil and entry[key] ~= nil then
      overrides[key] = entry[key]
    end
  end

  if type(overrides.traits) == "table" then
    overrides.traits = valid_forge_traits(overrides.traits)
  end

  if type(overrides.perks) == "table" then
    overrides.perks = copy_selected_forge_slots(overrides.perks)
  end

  local local_gear_id = "realms_local_weapon_" .. tostring(slot_name) .. "_" .. tostring(entry.source_gear_id or entry.id)

  -- Build the item through the game's own instance pipeline. It clones the
  -- master definition and merges the override layer (base_stats, perks,
  -- traits, levels, appearance...), so no field has to be copied by hand.
  -- The previous hand-built instance only reproduced a fixed set of fields and
  -- lost every other override value - base_stats above all - as soon as the
  -- __master_item snapshot was trimmed from the wire payload.
  -- create_preview_item_instance() only reads __gear/__gear_id and returns a
  -- writable copy, which is what a Realms-local item needs.
  local instance = MasterItems.create_preview_item_instance({
    __gear = {
      slots = { slot_name },
      masterDataInstance = {
        id = entry.id,
        overrides = overrides,
      },
    },
    __gear_id = local_gear_id,
  })

  if not instance then
    return nil
  end

  -- create_preview_item_instance() assigns a fresh preview id and keeps the
  -- caller's id in __original_gear_id; Realms keys its slots on its own id.
  instance.__gear_id = local_gear_id
  instance.gear_id = local_gear_id
  instance.__is_preview_item = false
  instance.overrides = instance.__gear.masterDataInstance.overrides
  instance.gear = instance.__gear
  instance.__local_item = true
  instance.__local_weapon = true
  instance.__weapon_catalog_entry = entry

  -- Keep the catalog entry's own fields (name, slots, origin, source id,
  -- level requirement...) visible exactly like the old instance did. Fields
  -- the instance already owns are left untouched.
  for key, value in pairs(entry) do
    if key ~= "overrides" and key ~= "__master_item" and key ~= "__gear" and key ~= "gear" and key ~= "gear_id" and key ~= "__gear_id" and rawget(instance, key) == nil then
      rawset(instance, key, type(value) == "table" and table.clone_instance(value) or value)
    end
  end

  return instance
end

function WeaponCatalog.make_local_weapon_instance(entry, slot_name)
  return make_local_weapon_instance(entry, slot_name)
end

function WeaponCatalog.local_item_instance_from_data(profile, item_data, slot_name)
  local catalog = WeaponCatalog.ensure_catalog(profile)
  local source_gear_id = item_data and item_data.source_gear_id
  local entry = catalog and catalog.by_source and source_gear_id and catalog.by_source[source_gear_id]

  if not entry then
    entry = {
      source_gear_id = source_gear_id or "saved_" .. tostring(slot_name) .. "_" .. tostring(item_data and item_data.id),
      id = item_data and item_data.id,
      name = item_data and item_data.id,
      slots = { slot_name },
      overrides = item_data and item_data.overrides,
    }
  end

  if not entry.id then
    mod:warning("realms_loadout could not rebuild local weapon for slot %s", tostring(slot_name))

    return nil
  end

  if item_data and item_data.overrides then
    entry.overrides = item_data.overrides
  end

  return make_local_weapon_instance(entry, slot_name)
end

function WeaponCatalog.local_instances(profile, slot_name)
  local catalog = WeaponCatalog.ensure_catalog(profile)

  if not catalog then
    return {}
  end

  local items = {}

  for i = 1, #catalog.items do
    local entry = catalog.items[i]

    -- Forge template entries are never selectable equipment.
    if entry and entry.slots and entry.removed ~= true and entry.unrestricted_human ~= true then
      for ii = 1, #entry.slots do
        if entry.slots[ii] == slot_name then
          local instance = make_local_weapon_instance(entry, slot_name)

          if instance then
            items[#items + 1] = instance
          end

          break
        end
      end
    end
  end

  return items
end

function WeaponCatalog.add_forge_weapon(profile, preview_item, slot_name)
  if not profile or type(preview_item) ~= "table" then
    return nil, "invalid arguments"
  end

  local catalog = WeaponCatalog.ensure_catalog(profile)

  if not catalog then
    return nil, "weapon catalog unavailable"
  end

  local master_id = preview_item.name or preview_item.id

  if not master_id then
    return nil, "missing master id"
  end

  local master_item = MasterItems.get_item(master_id) or preview_item
  local master_copy = sanitize_value(master_item, {}, 0)

  if type(master_copy) ~= "table" then
    master_copy = sanitize_value(preview_item, {}, 0) or {}
  end

  local stat_cap = tonumber(preview_item.__forge_stat_cap) or 1
  local base_stats = copy_forge_base_stats(preview_item.base_stats, stat_cap)

  if #base_stats == 0 then
    base_stats = copy_forge_base_stats(master_copy.base_stats, stat_cap)
  end

  local base_item_level = forge_base_item_level(base_stats)
  local perks = copy_selected_forge_slots(preview_item.perks)
  local traits = valid_forge_traits(preview_item.traits)
  local source_gear_id = new_forge_source_gear_id()

  slot_name = slot_name or first_forge_slot_name(preview_item.slots)

  if not slot_name then
    return nil, "unsupported weapon slot"
  end

  local overrides = {
    ver = 2,
    rarity = FORGE_OBTAIN_RARITY,
    characterLevel = FORGE_OBTAIN_CHARACTER_LEVEL,
    itemLevel = FORGE_OBTAIN_ITEM_LEVEL,
    baseItemLevel = base_item_level,
    base_stats = base_stats,
    perks = perks,
    traits = traits,
  }

  local entry = {
    source_gear_id = source_gear_id,
    id = master_id,
    name = master_id,
    slots = { slot_name },
    origin = "local",
    rarity = FORGE_OBTAIN_RARITY,
    itemLevel = FORGE_OBTAIN_ITEM_LEVEL,
    characterLevel = FORGE_OBTAIN_CHARACTER_LEVEL,
    baseItemLevel = base_item_level,
    overrides = overrides,
    __is_preview_item = false,
  }

  if not master_copy.weapon_template and preview_item.weapon_template then
    master_copy.weapon_template = preview_item.weapon_template
  end

  if not master_copy.item_type and preview_item.item_type then
    master_copy.item_type = preview_item.item_type
  end

  if master_copy.item_type then
    entry.item_type = master_copy.item_type
  end

  if master_copy.weapon_template then
    entry.weapon_template = master_copy.weapon_template
  end

  if master_copy.breeds then
    entry.breeds = table.clone_instance(master_copy.breeds)
  end

  if master_copy.archetypes then
    entry.archetypes = table.clone_instance(master_copy.archetypes)
  end

  master_copy.__forge_stat_cap = nil
  master_copy.rarity = FORGE_OBTAIN_RARITY
  master_copy.characterLevel = FORGE_OBTAIN_CHARACTER_LEVEL
  master_copy.itemLevel = FORGE_OBTAIN_ITEM_LEVEL
  master_copy.baseItemLevel = base_item_level
  master_copy.base_stats = base_stats
  master_copy.perks = perks
  master_copy.traits = traits

  entry.__master_item = master_copy

  local instance = make_local_weapon_instance(entry, slot_name)

  if not instance then
    return nil, "failed to create weapon instance"
  end

  catalog.items = catalog.items or {}
  catalog.by_source = catalog.by_source or {}

  catalog.items[#catalog.items + 1] = entry
  catalog.by_source[source_gear_id] = entry
  catalog.generated_at = os.time()

  local saved = save_catalog(profile, catalog)

  if not saved then
    return nil, "failed to save weapon catalog"
  end

  mod._weapon_catalog_cache = catalog
  mod._weapon_catalog_character_id = character_id(profile)

  return instance
end

function WeaponCatalog.apply_local_weapon_mark(profile, original_item, mark_item)
  if not profile or type(original_item) ~= "table" or type(mark_item) ~= "table" then
    return nil, "invalid arguments"
  end

  local catalog = WeaponCatalog.ensure_catalog(profile)

  if not catalog then
    return nil, "weapon catalog unavailable"
  end

  local entry = original_item.__weapon_catalog_entry

  if not entry and original_item.source_gear_id then
    catalog.by_source = catalog.by_source or {}
    entry = catalog.by_source[original_item.source_gear_id]
  end

  if not entry or not entry.id then
    return nil, "local catalog entry unavailable"
  end

  local mark_id = mark_item.name or mark_item.id

  if not mark_id then
    return nil, "missing weapon mark id"
  end

  local master_item = MasterItems.get_item(mark_id)

  if type(master_item) ~= "table" then
    return nil, "weapon mark master unavailable"
  end

  local master_copy = sanitize_value(master_item, {}, 0) or {}
  local stat_cap = tonumber(mark_item.__forge_stat_cap) or 1
  local base_stats = copy_forge_base_stats(mark_item.base_stats, stat_cap)

  if #base_stats == 0 then
    base_stats = copy_forge_base_stats(master_copy.base_stats, stat_cap)
  end

  local base_item_level = forge_base_item_level(base_stats)
  local slot_name = first_forge_slot_name(entry.slots)

  if not slot_name then
    return nil, "unsupported weapon slot"
  end

  local mark_gear = mark_item.__gear or mark_item.gear
  local mark_master_data = mark_gear and mark_gear.masterDataInstance
  local mark_overrides = mark_item.overrides or mark_master_data and mark_master_data.overrides
  local overrides = sanitize_value(mark_overrides, {}, 0) or {}

  overrides.ver = overrides.ver or 2
  overrides.rarity = overrides.rarity or FORGE_OBTAIN_RARITY
  overrides.characterLevel = overrides.characterLevel or FORGE_OBTAIN_CHARACTER_LEVEL
  overrides.itemLevel = overrides.itemLevel or FORGE_OBTAIN_ITEM_LEVEL
  overrides.baseItemLevel = base_item_level
  overrides.base_stats = base_stats

  local perks

  if type(original_item.perks) == "table" then
    perks = copy_selected_forge_slots(original_item.perks)
  else
    perks = copy_selected_forge_slots(mark_item.perks)

    if #perks == 0 then
      perks = copy_selected_forge_slots(overrides.perks)
    end
  end

  local traits

  if type(original_item.traits) == "table" then
    traits = copy_selected_forge_slots(original_item.traits)
  else
    traits = valid_forge_traits(mark_item.traits)

    if #traits == 0 then
      traits = valid_forge_traits(overrides.traits)
    end
  end

  overrides.perks = perks
  overrides.traits = traits

  entry.id = mark_id
  entry.name = mark_id
  entry.rarity = overrides.rarity
  entry.itemLevel = overrides.itemLevel
  entry.characterLevel = overrides.characterLevel
  entry.baseItemLevel = base_item_level
  entry.overrides = overrides

  if master_copy.item_type then
    entry.item_type = master_copy.item_type
  end

  if master_copy.weapon_template then
    entry.weapon_template = master_copy.weapon_template
  end

  if master_copy.breeds then
    entry.breeds = table.clone_instance(master_copy.breeds)
  end

  if master_copy.archetypes then
    entry.archetypes = table.clone_instance(master_copy.archetypes)
  end

  master_copy.__forge_stat_cap = nil
  master_copy.rarity = overrides.rarity
  master_copy.characterLevel = overrides.characterLevel
  master_copy.itemLevel = overrides.itemLevel
  master_copy.baseItemLevel = base_item_level
  master_copy.base_stats = base_stats
  master_copy.perks = perks
  master_copy.traits = traits

  entry.__master_item = master_copy

  local instance = make_local_weapon_instance(entry, slot_name)

  if not instance then
    return nil, "failed to create weapon instance"
  end

  catalog.generated_at = os.time()

  local saved = save_catalog(profile, catalog)

  if not saved then
    return nil, "failed to save weapon catalog"
  end

  mod._weapon_catalog_cache = catalog
  mod._weapon_catalog_character_id = character_id(profile)

  return instance
end

function WeaponCatalog.apply_local_weapon_cosmetics(profile, weapon_item)
  if not profile or type(weapon_item) ~= "table" then
    return nil, "invalid arguments"
  end

  local catalog = WeaponCatalog.ensure_catalog(profile)

  if not catalog then
    return nil, "weapon catalog unavailable"
  end

  local entry = weapon_item.__weapon_catalog_entry

  if not entry and weapon_item.source_gear_id then
    catalog.by_source = catalog.by_source or {}
    entry = catalog.by_source[weapon_item.source_gear_id]
  end

  if not entry or not entry.id then
    return nil, "local catalog entry unavailable"
  end

  local slot_name = first_forge_slot_name(entry.slots)

  if not slot_name then
    return nil, "unsupported weapon slot"
  end

  local gear = weapon_item.__gear or weapon_item.gear
  local master_data = gear and gear.masterDataInstance
  local overrides = master_data and master_data.overrides

  if not overrides then
    return nil, "weapon overrides unavailable"
  end

  local copied_overrides = sanitize_value(overrides, {}, 0) or {}

  -- The overrides table is the only layer written for appearance changes.
  -- make_local_weapon_instance applies these values onto the untouched master
  -- snapshot when the instance is rebuilt, so the base attachment tree is
  -- never mutated or cleared here.
  entry.overrides = copied_overrides

  catalog.generated_at = os.time()

  local saved = save_catalog(profile, catalog)

  if not saved then
    return nil, "failed to save weapon catalog"
  end

  mod._weapon_catalog_cache = catalog
  mod._weapon_catalog_character_id = character_id(profile)

  return make_local_weapon_instance(entry, slot_name)
end

function WeaponCatalog.mark_local_weapons_removed(profile, source_gear_ids)
  if not source_gear_ids or #source_gear_ids == 0 then
    return false
  end

  local catalog = WeaponCatalog.ensure_catalog(profile)

  if not catalog or not catalog.by_source then
    return false
  end

  local changed = false

  for i = 1, #source_gear_ids do
    local source_gear_id = source_gear_ids[i]
    local entry = catalog.by_source[source_gear_id]

    if entry then
      if entry.origin == "local" then
        catalog.by_source[source_gear_id] = nil

        for ii = #catalog.items, 1, -1 do
          if catalog.items[ii] == entry then
            table.remove(catalog.items, ii)

            break
          end
        end

        changed = true
      elseif entry.removed ~= true then
        entry.removed = true
        changed = true
      end
    end
  end

  if changed then
    catalog.generated_at = os.time()
    save_catalog(profile, catalog)

    mod._weapon_catalog_cache = catalog
    mod._weapon_catalog_character_id = character_id(profile)
  end

  return true
end

function WeaponCatalog.sync_weapon_from_official(profile, source_gear_id, official_item)
  if not profile or not source_gear_id or type(official_item) ~= "table" then
    return nil
  end

  local entry = entry_from_official_item(official_item)

  if not entry or entry.source_gear_id ~= source_gear_id then
    return nil
  end

  local catalog = WeaponCatalog.ensure_catalog(profile)

  if not catalog then
    return nil
  end

  entry.origin = "official"
  entry.removed = nil

  local replaced = false

  for i = #catalog.items, 1, -1 do
    local item = catalog.items[i]

    if item and item.source_gear_id == source_gear_id then
      catalog.items[i] = entry
      replaced = true

      break
    end
  end

  if not replaced then
    catalog.items[#catalog.items + 1] = entry
  end

  catalog.by_source[source_gear_id] = entry
  catalog.generated_at = os.time()

  attach_by_source(catalog)

  save_catalog(profile, catalog)

  mod._weapon_catalog_cache = catalog
  mod._weapon_catalog_character_id = character_id(profile)

  return entry
end

function WeaponCatalog.is_local_weapon(item)
  return type(item) == "table" and item.__local_weapon == true or false
end

mod._module_WeaponCatalog = WeaponCatalog
return WeaponCatalog

