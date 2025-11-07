-- barrels_data.lua
local mod = get_mod("barrels")

return {
  name = mod:localize("mod_name"),
  description = mod:localize("mod_description"),
  is_togglable = true,
  options = {
    widgets = {
      {
        setting_id = "report_mode",
        type = "dropdown",
        title = "report_mode",
        default_value = "default",
        options = {
          { value = "default", text = "report_mode_option_default" },
          { value = "chat",   text = "report_mode_option_chat"    },
          { value = "kill_feed", text = "report_mode_option_kill_feed" },
        },
      },
      {
        setting_id = "show_skulls",
        type = "checkbox",
        title = "show_skulls",
        default_value = true,
        tooltip = "show_skulls_tooltip",
      },
      {
        setting_id = "show_damage",
        type = "checkbox",
        title = "show_damage",
        default_value = true,
        tooltip = "show_damage_tooltip",
      },
    },
  },
}
