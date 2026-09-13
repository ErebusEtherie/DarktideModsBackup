local mod = get_mod("realms_loadout")
if mod._module_AttachmentCatalog then return mod._module_AttachmentCatalog end

local MasterItems = require("scripts/backend/master_items")

local _io = Mods.lua.io
local _os = Mods.lua.os

local AttachmentCatalog = {}

local CATALOG_VERSION = 1

local ATTACHMENT_SLOTS = {
  "slot_attachment_1",
  "slot_attachment_2",
  "slot_attachment_3",
}

local FORGE_ATTACHMENT_MASTER_ID = "content/items/gadgets/defensive_gadget_1"
local FORGE_ATTACHMENT_RARITY = 6
local FORGE_ATTACHMENT_ITEM_LEVEL = 90
local FORGE_ATTACHMENT_BASE_ITEM_LEVEL = 100
local FORGE_ATTACHMENT_CHARACTER_LEVEL = 1
local FORGE_ATTACHMENT_SOURCE_PREFIX = "realms_"
local FORGE_ATTACHMENT_TRAIT_RARITY = 3

local FORGE_ATTACHMENT_TEMPLATES = {
  {
    template_id = "wound",
    display_name_key = "forge_attachment_wound",
    effect_text_key = "forge_attachment_wound_effect",
    trait_id = "content/items/traits/gadget_inate_trait/trait_inate_gadget_health_segment",
    trait_value = 1,
  },
  {
    template_id = "stamina",
    display_name_key = "forge_attachment_stamina",
    effect_text_key = "forge_attachment_stamina_effect",
    trait_id = "content/items/traits/gadget_inate_trait/trait_inate_gadget_stamina",
    trait_value = 0.8,
  },
  {
    template_id = "health",
    display_name_key = "forge_attachment_health",
    effect_text_key = "forge_attachment_health_effect",
    trait_id = "content/items/traits/gadget_inate_trait/trait_inate_gadget_health",
    trait_value = 0.8,
  },
  {
    template_id = "toughness",
    display_name_key = "forge_attachment_toughness",
    effect_text_key = "forge_attachment_toughness_effect",
    trait_id = "content/items/traits/gadget_inate_trait/trait_inate_gadget_toughness",
    trait_value = 0.8,
  },
}

local FORGE_ATTACHMENT_UNCAPPED_TEMPLATES = {
  {
    template_id = "health_uncapped",
    display_name_key = "forge_attachment_health",
    effect_text_key = "forge_attachment_health_uncapped_effect",
    trait_id = "content/items/traits/gadget_inate_trait/trait_inate_gadget_health",
    trait_value = 1,
  },
  {
    template_id = "toughness_uncapped",
    display_name_key = "forge_attachment_toughness",
    effect_text_key = "forge_attachment_toughness_uncapped_effect",
    trait_id = "content/items/traits/gadget_inate_trait/trait_inate_gadget_toughness",
    trait_value = 1,
  },
}

local function new_forge_source_gear_id()
  local ok, generated = pcall(math.uuid)
  local uuid

  if ok and generated then
    uuid = tostring(generated)
  else
    uuid = tostring(os.time() or 0)

    local sequence = tonumber(mod._forge_attachment_sequence) or 0

    sequence = sequence + 1
    mod._forge_attachment_sequence = sequence

    uuid = uuid .. "_" .. tostring(sequence)
  end

  if string.sub(uuid, 1, #FORGE_ATTACHMENT_SOURCE_PREFIX) ~= FORGE_ATTACHMENT_SOURCE_PREFIX then
    uuid = FORGE_ATTACHMENT_SOURCE_PREFIX .. uuid
  end

  return uuid
end

local function base_dir()
  if not mod._local_attachment_catalog_base_dir then
    local appdata = _os and _os.getenv and _os.getenv("APPDATA") or ""
    mod._local_attachment_catalog_base_dir = appdata .. "/Fatshark/Darktide/realms_loadout"
  end

  return mod._local_attachment_catalog_base_dir
end

local function ensure_dir(path)
  local ok, run_error = pcall(_os.execute, 'mkdir "' .. path .. '" 2>nul')

  if not ok then
    mod:error("realms_loadout failed to create attachment catalog directory %s: %s", path, tostring(run_error))
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
    mod:warning("realms_loadout failed to parse attachment catalog %s: %s", file_path, tostring(decoded))

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

local function character_id(profile)
  local archetype = profile and profile.archetype

  return profile and profile.character_id
    or type(archetype) == "table" and archetype.name
    or archetype
    or "unknown"
end

local function catalog_path(profile)
  return base_dir() .. "/attachment_catalog_" .. character_id(profile) .. ".json"
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
      catalog.by_source[item.source_gear_id] = item
    end
  end

  return catalog
end

local function normalize_slots(slots)
  if type(slots) ~= "table" then
    return slots and { slots } or {}
  end

  return slots
end

local function entry_from_official_item(item)
  if type(item) ~= "table" then
    return nil
  end

  local source_gear_id = item.gear_id

  if not source_gear_id then
    return nil
  end

  local slots = normalize_slots(item.slots)
  local is_attachment = false

  for i = 1, #slots do
    if table.contains(ATTACHMENT_SLOTS, slots[i]) then
      is_attachment = true

      break
    end
  end

  if not is_attachment then
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

local function save_catalog(profile, catalog)

  local path = catalog_path(profile)
  local disk_data = {
    version = catalog.version,
    generated_at = catalog.generated_at,
    items = catalog.items,
  }

  return write_json(path, disk_data)
end

local function make_local_attachment_instance(entry)
  if not entry or not entry.id then
    return nil
  end

  local saved_master_item = entry.__master_item
  local master_item = saved_master_item and table.clone_instance(saved_master_item) or MasterItems.get_item(entry.id)
  local overrides = entry.overrides and table.clone_instance(entry.overrides) or {}

  if master_item then
    master_item.rarity = overrides.rarity or entry.rarity
    master_item.itemLevel = overrides.itemLevel or entry.itemLevel
    master_item.baseItemLevel = overrides.baseItemLevel or entry.baseItemLevel
    master_item.characterLevel = overrides.characterLevel or entry.characterLevel
    master_item.perks = overrides.perks and table.clone_instance(overrides.perks) or master_item.perks
    master_item.traits = overrides.traits and table.clone_instance(overrides.traits) or master_item.traits
    master_item.resource_dependencies = master_item.resource_dependencies or entry.resource_dependencies or {}
  end

  local resource_dependencies = master_item and master_item.resource_dependencies or entry.resource_dependencies

  local local_gear_id = "realms_local_attachment_" .. tostring(entry.source_gear_id or entry.id)
  local slots = entry.slots and table.clone_instance(entry.slots) or table.clone_instance(ATTACHMENT_SLOTS)
  local instance = {
    __local_item = true,
    __local_attachment = true,
    __attachment_catalog_entry = entry,
    __master_item = master_item or entry,
    __gear_id = local_gear_id,
    gear_id = local_gear_id,
    name = entry.name or entry.id,
    id = entry.id,
    slots = slots,
    item_type = entry.item_type or "GADGET",
    rarity = entry.rarity,
    itemLevel = entry.itemLevel,
    baseItemLevel = entry.baseItemLevel,
    characterLevel = entry.characterLevel,
    source_gear_id = entry.source_gear_id,
    origin = entry.origin,
    overrides = overrides,
    resource_dependencies = resource_dependencies and table.clone_instance(resource_dependencies) or {},
    base_unit = master_item and master_item.base_unit or entry.base_unit,
    attach_node = master_item and master_item.attach_node or entry.attach_node,
    attachments = master_item and master_item.attachments and table.clone_instance(master_item.attachments) or entry.attachments and table.clone_instance(entry.attachments) or nil,
    hud_icon = master_item and master_item.hud_icon or entry.hud_icon,
    icon_render_camera_position_offset = master_item and master_item.icon_render_camera_position_offset and table.clone_instance(master_item.icon_render_camera_position_offset) or entry.icon_render_camera_position_offset and table.clone_instance(entry.icon_render_camera_position_offset) or nil,
    ui_alignment_tag = master_item and master_item.ui_alignment_tag or entry.ui_alignment_tag,
  }

  instance.__gear = {
    slots = table.clone_instance(slots),
    masterDataInstance = {
      id = entry.id,
      overrides = overrides,
    },
  }

  instance.gear = instance.__gear

  for key, value in pairs(entry) do
    if rawget(instance, key) == nil then
      if type(value) == "table" then
        value = table.clone_instance(value)
      end

      rawset(instance, key, value)
    end
  end

  if not instance.perks and overrides.perks then
    instance.perks = table.clone_instance(overrides.perks)
  end

  if not instance.traits and overrides.traits then
    instance.traits = table.clone_instance(overrides.traits)
  end

  setmetatable(instance, {
    __index = function (target, key)
      if key == "gear_id" then
        return rawget(target, "__gear_id")
      elseif key == "gear" then
        return rawget(target, "__gear")
      elseif key == "overrides" then
        local gear = rawget(target, "__gear")

        return gear and gear.masterDataInstance and gear.masterDataInstance.overrides
      end

      local catalog_entry = rawget(target, "__attachment_catalog_entry")

      if catalog_entry and rawget(catalog_entry, key) ~= nil then
        return rawget(catalog_entry, key)
      end

      local master_entry = rawget(target, "__master_item")

      return master_entry and master_entry[key]
    end,
    __newindex = function (target, key, value)
      rawset(target, key, value)
    end,
  })

  return instance
end

function AttachmentCatalog.base_dir()
  return base_dir()
end

function AttachmentCatalog.reset_cache()
  mod._attachment_catalog_cache = nil
  mod._attachment_catalog_character_id = nil
end

function AttachmentCatalog.load_catalog(profile)
  local catalog = read_json(catalog_path(profile))

  if catalog and type(catalog) == "table" then
    catalog.synced = true
  end

  return attach_by_source(catalog)
end

function AttachmentCatalog.sync_from_official(profile, inventory_items)
  if not inventory_items then
    return AttachmentCatalog.load_catalog(profile)
  end

  local previous = AttachmentCatalog.load_catalog(profile) or {
    version = CATALOG_VERSION,
    generated_at = 0,
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
        -- Keep the previous local copy so locally forged edits survive syncs.
        items[#items + 1] = previous_entry
      else
        items[#items + 1] = entry
        changed = true
      end
    end
  end

  -- Keep locally forged entries whose official item is not present. This
  -- mirrors WeaponCatalog.sync_from_official and keeps equipped loadouts valid.
  for source_gear_id, entry in pairs(previous.by_source) do
    if not seen[source_gear_id] and type(entry) == "table" and entry.source_gear_id then
      items[#items + 1] = entry
    end
  end

  table.sort(items, function (a, b)
    return (a.name or "") < (b.name or "")
  end)

  local catalog = {
    version = CATALOG_VERSION,
    generated_at = changed and os.time() or previous.generated_at or os.time(),
    items = items,
    synced = true,
  }

  attach_by_source(catalog)

  if changed then
    save_catalog(profile, catalog)
  end

  mod._attachment_catalog_cache = catalog
  mod._attachment_catalog_character_id = character_id(profile)

  return catalog
end

function AttachmentCatalog.ensure_catalog(profile)
  local profile_character_id = character_id(profile)

  if mod._attachment_catalog_cache and mod._attachment_catalog_character_id == profile_character_id and mod._attachment_catalog_cache.synced == true then
    return mod._attachment_catalog_cache
  end

  local cached_inventory = mod._realms_loadout_inventory_items and mod._realms_loadout_inventory_items[profile_character_id]

  if cached_inventory then
    return AttachmentCatalog.sync_from_official(profile, cached_inventory)
  end

  local previous = AttachmentCatalog.load_catalog(profile)

  if previous and type(previous) == "table" and previous.items then
    mod._attachment_catalog_cache = previous
    mod._attachment_catalog_character_id = profile_character_id

    return previous
  end

  local empty = {
    version = CATALOG_VERSION,
    generated_at = 0,
    items = {},
    by_source = {},
    synced = false,
  }

  mod._attachment_catalog_cache = empty
  mod._attachment_catalog_character_id = profile_character_id

  return empty
end

function AttachmentCatalog.forge_attachment_slots()
  return table.clone_instance(ATTACHMENT_SLOTS)
end

local function append_forge_attachment_templates(templates, template_source)
  for i = 1, #template_source do
    local template = table.clone_instance(template_source[i])

    template.__forge_attachment_template = true
    templates[#templates + 1] = template
  end
end

function AttachmentCatalog.forge_attachment_templates()
  local templates = {}

  append_forge_attachment_templates(templates, FORGE_ATTACHMENT_TEMPLATES)

  if mod:get("allow_uncapped_weapon_stats") == true then
    append_forge_attachment_templates(templates, FORGE_ATTACHMENT_UNCAPPED_TEMPLATES)
  end

  return templates
end

function AttachmentCatalog.build_forge_preview_item(template)
  if type(template) ~= "table" then
    return nil
  end

  local master_item = MasterItems.get_item(FORGE_ATTACHMENT_MASTER_ID)
  local preview_item = master_item and table.shallow_copy(master_item) or table.shallow_copy(template)

  preview_item.template_id = template.template_id
  preview_item.display_name_key = template.display_name_key
  preview_item.effect_text_key = template.effect_text_key
  preview_item.trait_id = template.trait_id
  preview_item.trait_value = template.trait_value
  preview_item.name = FORGE_ATTACHMENT_MASTER_ID
  preview_item.id = FORGE_ATTACHMENT_MASTER_ID
  preview_item.slots = table.clone_instance(ATTACHMENT_SLOTS)
  preview_item.item_type = "GADGET"
  preview_item.rarity = FORGE_ATTACHMENT_RARITY
  preview_item.itemLevel = FORGE_ATTACHMENT_ITEM_LEVEL
  preview_item.baseItemLevel = FORGE_ATTACHMENT_BASE_ITEM_LEVEL
  preview_item.characterLevel = FORGE_ATTACHMENT_CHARACTER_LEVEL
  preview_item.__forge_attachment_template = true
  preview_item.resource_dependencies = {}

  local perk_slot_count = mod:get("allow_uncapped_weapon_stats") and 99 or 3
  local perks = {}

  for i = 1, perk_slot_count do
    perks[i] = {
      id = nil,
      rarity = 0
    }
  end

  preview_item.__forge_perk_slots = perks
  preview_item.perks = {}

  local traits = {}

  if template.trait_id then
    traits[1] = {
      id = template.trait_id,
      rarity = FORGE_ATTACHMENT_TRAIT_RARITY,
      value = template.trait_value
    }
  end

  preview_item.traits = traits

  return preview_item
end

function AttachmentCatalog.local_instances(profile, slot_name)
  local catalog = AttachmentCatalog.ensure_catalog(profile)
  local items = {}

  if not catalog or not catalog.items then
    return items
  end

  for i = 1, #catalog.items do
    local entry = catalog.items[i]

    if entry and entry.slots and entry.removed ~= true then
      if not slot_name or table.contains(entry.slots, slot_name) then
        local instance = make_local_attachment_instance(entry)

        if instance then
          items[#items + 1] = instance
        end
      end
    end
  end

  return items
end

function AttachmentCatalog.make_local_attachment_instance(entry)
  return make_local_attachment_instance(entry)
end

function AttachmentCatalog.local_item_instance_from_data(profile, item_data, slot_name)
  local catalog = AttachmentCatalog.ensure_catalog(profile)
  local source_gear_id = item_data and item_data.source_gear_id
  local entry = catalog and catalog.by_source and source_gear_id and catalog.by_source[source_gear_id]

  if not entry then
    entry = {
      source_gear_id = source_gear_id or "saved_attachment_" .. tostring(item_data and item_data.id),
      id = item_data and item_data.id,
      name = item_data and item_data.id,
      slots = table.clone_instance(ATTACHMENT_SLOTS),
      origin = "local",
      overrides = item_data and item_data.overrides and table.clone_instance(item_data.overrides) or nil,
    }
  end

  if not entry.id then
    mod:warning("realms_loadout could not rebuild local attachment %s", tostring(source_gear_id))

    return nil
  end

  if item_data and item_data.overrides then
    entry.overrides = table.clone_instance(item_data.overrides)
  end

  return make_local_attachment_instance(entry)
end

function AttachmentCatalog.add_forge_attachment(profile, preview_item)
  if not profile or type(preview_item) ~= "table" then
    return nil, "invalid arguments"
  end

  if not preview_item.__forge_attachment_template then
    return nil, "not a forge attachment preview"
  end

  local catalog = AttachmentCatalog.ensure_catalog(profile)

  if not catalog then
    return nil, "attachment catalog unavailable"
  end

  local master_id = "content/items/gadgets/defensive_gadget_" .. math.random(1, 22)
  local master_item = MasterItems.get_item(master_id) or preview_item
  local master_copy = sanitize_value(master_item, {}, 0)

  if type(master_copy) ~= "table" then
    master_copy = sanitize_value(preview_item, {}, 0) or {}
  end

  master_copy.name = master_id
  master_copy.id = master_id
  master_copy.slots = table.clone_instance(ATTACHMENT_SLOTS)
  master_copy.item_type = master_copy.item_type or "GADGET"
  master_copy.__forge_attachment_template = nil
  master_copy.resource_dependencies = master_copy.resource_dependencies or {}
  master_copy.rarity = FORGE_ATTACHMENT_RARITY
  master_copy.characterLevel = FORGE_ATTACHMENT_CHARACTER_LEVEL
  master_copy.itemLevel = FORGE_ATTACHMENT_ITEM_LEVEL
  master_copy.baseItemLevel = FORGE_ATTACHMENT_BASE_ITEM_LEVEL

  local perks = copy_selected_forge_slots(preview_item.perks)
  local traits = {}

  if type(preview_item.traits) == "table" then
    for i = 1, #preview_item.traits do
      local trait = preview_item.traits[i]

      if type(trait) == "table" and trait.id ~= nil and trait.id ~= "" then
        traits[#traits + 1] = {
          id = trait.id,
          rarity = trait.rarity or FORGE_ATTACHMENT_TRAIT_RARITY,
          value = trait.value
        }
      end
    end
  end

  master_copy.perks = table.clone_instance(perks)
  master_copy.traits = table.clone_instance(traits)

  local source_gear_id = new_forge_source_gear_id()
  local overrides = {
    ver = 2,
    rarity = FORGE_ATTACHMENT_RARITY,
    characterLevel = FORGE_ATTACHMENT_CHARACTER_LEVEL,
    itemLevel = FORGE_ATTACHMENT_ITEM_LEVEL,
    baseItemLevel = FORGE_ATTACHMENT_BASE_ITEM_LEVEL,
    perks = perks,
    traits = traits,
  }

  local entry = {
    source_gear_id = source_gear_id,
    id = master_id,
    name = master_id,
    slots = table.clone_instance(ATTACHMENT_SLOTS),
    origin = "local",
    rarity = FORGE_ATTACHMENT_RARITY,
    itemLevel = FORGE_ATTACHMENT_ITEM_LEVEL,
    characterLevel = FORGE_ATTACHMENT_CHARACTER_LEVEL,
    baseItemLevel = FORGE_ATTACHMENT_BASE_ITEM_LEVEL,
    overrides = overrides,
    __is_preview_item = false,
    __master_item = master_copy,
  }

  if master_copy.item_type then
    entry.item_type = master_copy.item_type
  end

  local instance = make_local_attachment_instance(entry)

  if not instance then
    return nil, "failed to create attachment instance"
  end

  catalog.items = catalog.items or {}
  catalog.by_source = catalog.by_source or {}

  catalog.items[#catalog.items + 1] = entry
  catalog.by_source[source_gear_id] = entry
  catalog.generated_at = os.time()

  local saved = save_catalog(profile, catalog)

  if not saved then
    return nil, "failed to save attachment catalog"
  end

  mod._attachment_catalog_cache = catalog
  mod._attachment_catalog_character_id = character_id(profile)

  return instance
end

function AttachmentCatalog.is_local_attachment(item)
  return type(item) == "table" and item.__local_attachment == true or false
end

function AttachmentCatalog.local_mode_enabled()
  -- Realm forge attachments are always backed by the local attachment catalog.
  return true
end

mod._module_AttachmentCatalog = AttachmentCatalog
return AttachmentCatalog
