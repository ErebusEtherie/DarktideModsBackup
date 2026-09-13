local mod = get_mod("realms_loadout")
if mod._workspace_presets then return mod._workspace_presets end
local Storage = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/storage")
local Presets = {}
mod._workspace_presets = Presets
function Presets.observe() end -- Storage owns selection even after the UI closes.
function Presets.snapshot(profile)
  local player = Managers.player and Managers.player:local_player_safe(1)
  if not player or player.__deleted or not profile or player:character_id() ~= profile.character_id then
    return { key = "unassigned", entries = {} }
  end
  local data = Storage.loadouts_data(profile)
  local snapshot = { namespace = "local_equipment", key = "local_equipment:unassigned", entries = {}, authoritative = data.presets_initialized }
  for _, slot in ipairs(data.loadouts) do
    local key = "local_equipment:" .. tostring(slot.id)
    snapshot.entries[#snapshot.entries + 1] = { key = key, id = slot.id, source_id = slot.source_preset_id, seed_nodes = slot.seed_nodes }
    if slot.id == data.active_id then snapshot.key = key end
  end
  return snapshot
end
return Presets
