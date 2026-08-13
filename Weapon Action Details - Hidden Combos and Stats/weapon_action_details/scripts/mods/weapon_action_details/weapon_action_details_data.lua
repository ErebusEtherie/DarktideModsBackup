-- File: weapon_action_details/scripts/mods/weapon_action_details/weapon_action_details_data.lua
local mod = get_mod("weapon_action_details"); if not mod then return end

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {},
    },
}
