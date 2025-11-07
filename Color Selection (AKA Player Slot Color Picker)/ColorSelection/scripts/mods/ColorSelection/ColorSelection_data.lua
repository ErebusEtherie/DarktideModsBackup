local mod = get_mod("ColorSelection")

return {
  name = mod:localize("mod_name"),
  description = mod:localize("mod_description"),
  is_togglable = true,
  options = {
    widgets = {
      {
        type = "group",
        setting_id = "player_color_group",
        title = "player_color_header",
        sub_widgets = {
          {
            type = "numeric",
            setting_id = "player_color_r",
            title = "label_red",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player_color_g",
            title = "label_green",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player_color_b",
            title = "label_blue",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player_color_a",
            title = "label_alpha",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
        },
      },
      {
        type = "group",
        setting_id = "player2_color_group",
        title = "player2_color_header",
        sub_widgets = {
          {
            type = "numeric",
            setting_id = "player2_color_r",
            title = "label_red",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player2_color_g",
            title = "label_green",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player2_color_b",
            title = "label_blue",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player2_color_a",
            title = "label_alpha",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
        },
      },
      {
        type = "group",
        setting_id = "player3_color_group",
        title = "player3_color_header",
        sub_widgets = {
          {
            type = "numeric",
            setting_id = "player3_color_r",
            title = "label_red",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player3_color_g",
            title = "label_green",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player3_color_b",
            title = "label_blue",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player3_color_a",
            title = "label_alpha",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
        },
      },
      {
        type = "group",
        setting_id = "player4_color_group",
        title = "player4_color_header",
        sub_widgets = {
          {
            type = "numeric",
            setting_id = "player4_color_r",
            title = "label_red",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player4_color_g",
            title = "label_green",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player4_color_b",
            title = "label_blue",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
          {
            type = "numeric",
            setting_id = "player4_color_a",
            title = "label_alpha",
            default_value = 255,
            range = { 0, 255 },
            decimals_number = 0,
          },
        },
      },

      -- Nameplate options
      {
        setting_id = "nameplate_group",
        type = "group",
        title = "nameplate_header",
        sub_widgets = {
          {
            type = "checkbox",
            setting_id = "color_nameplate",
            default_value = false,
            tooltip = "color_nameplate_tooltip",
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
        },
      },
    },
  },
}
