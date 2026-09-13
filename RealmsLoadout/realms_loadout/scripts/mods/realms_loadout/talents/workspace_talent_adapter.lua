local mod = get_mod("realms_loadout")
if mod._workspace_talent_adapter then return mod._workspace_talent_adapter end
-- The existing save/validation policy hooks this private adapter instead of
-- InventoryBackgroundView. No ordinary inventory methods are replaced.
local Adapter = {
  _switch_active_view = function() end,
  on_exit = function() end,
  _save_current_talents_to_profile_preset = function() end,
  _apply_current_talents_to_profile = function() end,
}
mod._workspace_talent_adapter = Adapter
return Adapter
