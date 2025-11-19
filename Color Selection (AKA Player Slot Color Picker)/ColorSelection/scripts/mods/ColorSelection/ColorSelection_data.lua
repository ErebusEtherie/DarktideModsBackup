local mod = get_mod("ColorSelection")

return {
  name = mod:localize("mod_name"),
  description = mod:localize("mod_description"),
  is_togglable = true,
  options = {
    widgets = {
      {
        setting_id = "open_color_customizer_bind",
        type = "keybind",
        title = "open_color_customizer_bind",
        tooltip = "open_color_customizer_bind_tooltip",
        default_value = {},
        keybind_trigger = "pressed",
        keybind_type = "function_call",
        function_name = "open_color_customizer"
      },
      {
        type = "group",
        setting_id = "player_color_group",
        title = "player_color_header",
        tooltip = "slot1_color_tooltip",
        sub_widgets = {
          {
            type = "numeric",
            setting_id = "player_color_r",
            title = "label_red",
            default_value = 226,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player_color_g",
            title = "label_green",
            default_value = 210,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player_color_b",
            title = "label_blue",
            default_value = 117,
            range = { 0, 255 },
            decimals_number = 0,
          },
        },
      },
      {
        type = "group",
        setting_id = "player2_color_group",
        title = "player2_color_header",
        tooltip = "slot2_color_tooltip",
        sub_widgets = {
          {
            type = "numeric",
            setting_id = "player2_color_r",
            title = "label_red",
            default_value = 180,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player2_color_g",
            title = "label_green",
            default_value = 88,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player2_color_b",
            title = "label_blue",
            default_value = 197,
            range = { 0, 255 },
            decimals_number = 0,
          },
        },
      },
      {
        type = "group",
        setting_id = "player3_color_group",
        title = "player3_color_header",
        tooltip = "slot3_color_tooltip",
        sub_widgets = {
          {
            type = "numeric",
            setting_id = "player3_color_r",
            title = "label_red",
            default_value = 84,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player3_color_g",
            title = "label_green",
            default_value = 172,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player3_color_b",
            title = "label_blue",
            default_value = 80,
            range = { 0, 255 },
            decimals_number = 0,
          },
        },
      },
      {
        type = "group",
        setting_id = "player4_color_group",
        title = "player4_color_header",
        tooltip = "slot4_color_tooltip",
        sub_widgets = {
          {
            type = "numeric",
            setting_id = "player4_color_r",
            title = "label_red",
            default_value = 126,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player4_color_g",
            title = "label_green",
            default_value = 153,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player4_color_b",
            title = "label_blue",
            default_value = 200,
            range = { 0, 255 },
            decimals_number = 0,
          },
        },
      },

      -- HUD name color options
      {
        setting_id = "hudnames_group",
        type = "group",
        title = "hudnames_header",
        sub_widgets = {
          {
            type = "checkbox",
            setting_id = "color_hud_names",
            default_value = true,
            tooltip = "color_hud_names_tooltip",
          },
          {
            type = "checkbox",
            setting_id = "color_nameplate_names",
            default_value = false,
            tooltip = "color_nameplate_names_tooltip",
          },
        },
      },
      -- Bot color options
      {
        type = "group",
        setting_id = "bot_color_group",
        title = "bot_color_header",
        tooltip = "bot_color_tooltip",
        sub_widgets = {
          {
            type = "numeric",
            setting_id = "bot_color_r",
            title = "label_red",
            default_value = 128,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "bot_color_g",
            title = "label_green",
            default_value = 128,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "bot_color_b",
            title = "label_blue",
            default_value = 128,
            range = { 0, 255 },
            decimals_number = 0,
          },
        },
      },
      {
        setting_id = "debug_mode_group",
        type = "group",
        title = "debug_mode_group",
        sub_widgets = {
          {
            type = "checkbox",
            setting_id = "debug_mode",
            default_value = false,
            tooltip = "debug_mode_tooltip",
          },
        },
      },
    },
  },
}
