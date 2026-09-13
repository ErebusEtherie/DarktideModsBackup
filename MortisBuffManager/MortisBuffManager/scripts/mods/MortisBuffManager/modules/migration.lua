local mod = get_mod("MortisBuffManager")
-- Read the old namespace without loading any of its hooks or gameplay modules.
if mod:get("split_migration_v1") then return end
local all_settings = Application.user_setting("mods_settings") or {}
local old_settings = all_settings.TalentAndMortisManager or {}
local keys = {
	"enable_custom_mortis_buffs",
	"enable_local_mortis_buffs",
	"enable_realms_mortis_buffs",
	"mortis_buff_limit",
	"tamm_mortis_families_v1",
	"tamm_mortis_selections_v1",
}
for _, key in ipairs(keys) do
    local value = old_settings[key]
    if value ~= nil then
        mod:set(key, type(value) == "table" and table.clone_instance(value) or value)
    end
end
mod:set("split_migration_v1", true)
