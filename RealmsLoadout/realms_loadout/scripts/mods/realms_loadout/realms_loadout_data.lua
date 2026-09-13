local mod = get_mod("realms_loadout")

local data = {
  name = mod:localize("mod_name"),
  description = mod:localize("mod_description"),
  is_togglable = true,
  options = {
    widgets = {
      {
        setting_id = "open_view_bind",
        type = "keybind",
        default_value = {},
        keybind_trigger = "pressed",
        keybind_type = "function_call",
        function_name = "open_view",
        title = "open_view_bind", tooltip = "open_view_bind_description"
      },
      {
        setting_id = "allow_all_archetype_weapons",
        type = "checkbox",
        default_value = false
      },
      {
        setting_id = "allow_uncapped_weapon_stats",
        type = "checkbox",
        default_value = false
      }
    }
  }
}

local talents = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/settings")
for _, widget in ipairs(talents.options.widgets) do data.options.widgets[#data.options.widgets + 1] = widget end
return data
