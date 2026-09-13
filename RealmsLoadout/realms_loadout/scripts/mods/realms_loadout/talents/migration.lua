local mod = get_mod("realms_loadout")
if mod:get("unified_talents_migration_v1") then return end
-- Copy saved settings only. Never instantiate the old mod or remove its data.
local settings = Application.user_setting("mods_settings") or {}
local old = settings.TalentPointManager or {}
local keys = {
  "enable_custom_talent_points", "enable_local_custom_talents", "local_talent_points",
  "unlock_all_auras", "unlock_all_keystones", "enable_bot_custom_talents", "bot_talent_points", "bot_talent_autofill",
  "tamm_custom_talent_builds_v1", "tamm_custom_talent_builds_v1_presets_v1",
  "tamm_realms_talent_builds_v2", "tamm_realms_talent_builds_v2_presets_v1", "tamm_wote_migration_v1",
}
for _, key in ipairs(keys) do
  local value = old[key]
  if value ~= nil then mod:set(key, type(value) == "table" and table.clone_instance(value) or value) end
end
mod:set("unified_talents_migration_v1", true)
mod:set("debug_talent_effects", false)
