-- Scum's specialization tree uses the native layout/costs, with its own cap.
local mod = get_mod("realms_loadout")
if mod._stimm_policy then return mod._stimm_policy end
local Parser = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
local Rules = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/talent_rules")
local policy = { rl_unlock_stimm = true }
local Stimm = {}
mod._stimm_policy = Stimm
function Stimm.layout(profile)
  local a = profile and profile.archetype
  return type(a) == "table" and a.name == "broker" and a.specialization_talent_layout_file_path
    and require(a.specialization_talent_layout_file_path) or nil
end
function Stimm.native_cap(profile)
  return math.max(0, tonumber(profile.rl_stimm_native_points) or tonumber(profile.expertise_points) or 0)
end
function Stimm.editor_layout(profile)
  local original = Stimm.layout(profile)
  return original and Rules.copy_layout(original, policy) or nil
end
function Stimm.cap(profile, configured)
  return type(configured) == "number" and configured >= 0 and math.clamp(math.floor(configured), 0, 103)
    or Stimm.native_cap(profile)
end
function Stimm.filter(profile, nodes)
  local result = {}
  for _, node in ipairs(Stimm.layout(profile) and Stimm.layout(profile).nodes or {}) do
    local value = (nodes or profile.selected_nodes or {})[node.widget_name]
    if node.type ~= "start" and type(value) == "number" and value > 0 then result[node.widget_name] = value end
  end
  return result
end
local function proxy(profile)
  return { character_id = profile.character_id, rl_specialization = true,
    archetype = { name = "broker", talent_layout_file_path = profile.archetype.specialization_talent_layout_file_path } }
end
function Stimm.install(validate, project)
  function Stimm.validate(profile, nodes, cap)
    if not Stimm.layout(profile) then return type(nodes) == "table" and next(nodes) == nil and {} or nil end
    return validate(proxy(profile), nodes, cap, policy)
  end
  function Stimm.project(profile, nodes, cap)
    if not Stimm.layout(profile) then return {} end
    return project(proxy(profile), nodes or {}, cap, profile.character_id, policy)
  end
end
function Stimm.apply(profile, desired, cap)
  local layout = Stimm.layout(profile)
  if not layout then return profile end
  local selected = Stimm.project(profile, desired or Stimm.filter(profile), cap)
  -- The caller already owns this profile clone.
  for _, node in ipairs(layout.nodes) do
    profile.selected_nodes[node.widget_name] = nil
    if node.talent then profile.talents[node.talent] = nil end
  end
  for name, tier in pairs(selected) do profile.selected_nodes[name] = tier end
  Parser.selected_talents_from_selected_nodes(layout, selected, profile.talents)
  profile.rl_stimm_native_points = Stimm.native_cap(profile)
  profile.expertise_points = cap
  return profile
end
return Stimm
