local mod = get_mod("DefaultSprint")

return {
  name = mod:localize("mod_name"),
  description = mod:localize("mod_description"),
  is_togglable = true,
  options = {
    widgets = {
      {
        setting_id = "disable_when_charge",
        type = "checkbox",
        default_value = true,
      },
      {
        setting_id = "disable_for_range",
        type = "checkbox",
        default_value = false,
      },
      {
        setting_id = "disable_for_staff",
        type = "checkbox",
        default_value = false,
      },
      {
        setting_id = "hold_to_walk",
        type = "keybind",
        default_value = {},
        keybind_trigger = "held",
        keybind_type = "function_call",
        function_name = "hold_to_walk",
      },
      {
        setting_id = "walk_speed",
        type = "numeric",
        default_value = 0.5,
        range = {0.1, 1.0},
        decimals_number = 2,
      },
      {
        setting_id = "toggle_sprint",
        type = "keybind",
        default_value = {},
        keybind_trigger = "pressed",
        keybind_type = "function_call",
        function_name = "toggle_sprint",
      },
    }
  }
}