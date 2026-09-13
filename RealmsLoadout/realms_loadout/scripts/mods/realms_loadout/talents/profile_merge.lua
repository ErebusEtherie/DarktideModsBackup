-- Talent restoration must never restore cached weapons, cosmetics or Stimm.
local Merge = {}

function Merge.restore_main(current, original)
  if not current or not original or current.character_id ~= original.character_id then return nil end
  local archetype = original.archetype
  local path = type(archetype) == "table" and archetype.talent_layout_file_path
  if not path then return nil end
  local result = table.clone_instance(current)
  result.selected_nodes = table.clone_instance(current.selected_nodes or {})
  result.talents = table.clone_instance(current.talents or {})
  for _, node in ipairs(require(path).nodes) do
    result.selected_nodes[node.widget_name] = (original.selected_nodes or {})[node.widget_name]
    if node.talent then result.talents[node.talent] = (original.talents or {})[node.talent] end
  end
  local specialization = type(archetype) == "table" and archetype.specialization_talent_layout_file_path
  if specialization and current.rl_stimm_native_points ~= nil then
    for _, node in ipairs(require(specialization).nodes) do
      result.selected_nodes[node.widget_name] = (original.selected_nodes or {})[node.widget_name]
      if node.talent then result.talents[node.talent] = (original.talents or {})[node.talent] end
    end
    result.expertise_points = original.expertise_points
    result.rl_stimm_native_points = original.rl_stimm_native_points
  end
  result.talent_points = original.talent_points
  -- Official profiles deliberately have no custom marker. Native cloning
  -- rejects nil; an empty table would incorrectly mark the restored tree custom.
  local marker = original.tamm_custom_talents
  result.tamm_custom_talents = type(marker) == "table" and table.clone_instance(marker) or nil
  return result
end

return Merge
