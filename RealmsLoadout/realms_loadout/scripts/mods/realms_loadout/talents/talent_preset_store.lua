local Store = {}
local function copy(value) return type(value) == "table" and table.clone_instance(value) or nil end

function Store.resolve(mod, setting, character, snapshot, legacy, fallback, inherited)
  local key = setting .. "_presets_v1"
  local data = mod:get(key)
  data = type(data) == "table" and data or {}
  local record = data[character]
  local changed = false
  if not record then
    record = { slots = {}, active_key = snapshot.key,
      revision = math.max(tonumber(legacy and legacy.revision) or 0, inherited and inherited.revision or 0) }
    data[character], changed = record, true
    -- Seed the pre-existing loadouts with the previous single custom build.
    -- Subsequent edits belong only to their own loadout.
    for _, entry in ipairs(snapshot.entries) do
      record.slots[entry.key] = copy(inherited and inherited.slots[entry.key] or legacy or fallback(entry))
    end
  end
  local active = snapshot.key
  for _, entry in ipairs(snapshot.entries) do
    if not record.slots[entry.key] then
      -- Migrate standalone native-slot builds by source id once. Imported slots
      -- otherwise retain their own official tree rather than the active tree.
      local native = entry.source_id and record.slots["native:" .. tostring(entry.source_id)]
      record.slots[entry.key] = copy(inherited and inherited.slots[entry.key] or native
        or (entry.source_id and fallback(entry)) or record.slots[record.active_key] or legacy or fallback(entry))
      changed = true
    end
  end
  if not record.slots[active] then
    record.slots[active] = copy(inherited and inherited.slots[active]
      or record.slots[record.active_key] or legacy or fallback())
    changed = true
  end
  if record.active_key ~= active then
    record.active_key = active
    record.revision = record.revision + 1
    changed = true
  end
  -- Remove trees belonging to deleted slots in this provider only. Temporarily
  -- disabling an equipment extension must preserve that provider's other data.
  if snapshot.namespace and (snapshot.authoritative or #snapshot.entries > 0) then
    local present = { [active] = true }
    for _, entry in ipairs(snapshot.entries) do present[entry.key] = true end
    local prefix = snapshot.namespace .. ":"
    for slot in pairs(record.slots) do
      if slot:sub(1, #prefix) == prefix and not present[slot] then
        record.slots[slot], changed = nil, true
      end
    end
  end
  if changed then mod:set(key, data) end
  return record, data, key
end

function Store.read(record)
  local saved = record.slots[record.active_key]
  local build
  if saved then
    build = {}
    for key, value in pairs(saved) do build[key] = value end
  end
  if build then build.revision = record.revision end
  return build
end

function Store.write(mod, data, key, record, build, preset_key)
  local target = preset_key or record.active_key
  -- A delayed save from the outgoing editor cannot recreate a deleted slot.
  if not record.slots[target] then return nil end
  record.revision = record.revision + 1
  build.revision = record.revision
  record.slots[target] = copy(build)
  mod:set(key, data)
  return build
end

return Store
