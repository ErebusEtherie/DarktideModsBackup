local mod = get_mod("better_hud_info_view")

return {
  name = mod:localize("mod_name"),
  description = mod:localize("mod_description"),
  is_togglable = true,
  options = {
    widgets = {
      -- 左侧 Buff 面板
      {
        setting_id = "left_buff_panel",
        type = "group",
        sub_widgets = {
          {
            setting_id = "mortis_toggle",
            type = "checkbox",
            default_value = true,
            unit_text = "仅在死灵试炼中显示 Buff"
          },
          {
            setting_id = "left_buff_offset_y",
            type = "numeric",
            default_value = 1000,
            range = { -1200, 1000 },
            step_size = 10,
            unit_text = "左侧 Buff Y 偏移"
          },
        }
      },

      -- 地图标题
      {
        setting_id = "map_info",
        type = "group",
        sub_widgets = {
          {
            setting_id = "mission_offset_x",
            type = "numeric",
            default_value = 0,
            range = { -200, 1000 },
            step_size = 10,
            unit_text = "地图标题 X 偏移"
          },
          {
            setting_id = "mission_offset_y",
            type = "numeric",
            default_value = 0,
            range = { -200, 1000 },
            step_size = 10,
            unit_text = "地图标题 Y 偏移"
          },
        }
      },

      -- 任务
      {
        setting_id = "mission_info",
        type = "group",
        sub_widgets = {
          {
            setting_id = "circumstance_offset_x",
            type = "numeric",
            default_value = -435,
            range = { -500, 1000 },
            step_size = 10,
            unit_text = "任务 X 偏移"
          },
          {
            setting_id = "circumstance_offset_y",
            type = "numeric",
            default_value = 0,
            range = { -200, 1000 },
            step_size = 10,
            unit_text = "任务 Y 偏移"
          },
          {
            setting_id = "circumstance_name_font_size",
            type = "numeric",
            default_value = 24,
            range = { 8, 64 },
            step_size = 1,
            unit_text = "任务标题字体大小"
          },
          {
            setting_id = "circumstance_description_font_size",
            type = "numeric",
            default_value = 20,
            range = { 8, 64 },
            step_size = 1,
            unit_text = "任务描述字体大小"
          },
          {
            setting_id = "danger_offset_x",
            type = "numeric",
            default_value = 0,
            range = { -200, 1000 },
            step_size = 10,
            unit_text = "danger X 偏移"
          },
          {
            setting_id = "danger_offset_y",
            type = "numeric",
            default_value = 0,
            range = { -200, 1000 },
            step_size = 10,
            unit_text = "danger Y 偏移"
          },
        }
      },

      -- 浩劫
      {
        setting_id = "havoc_info",
        type = "group",
        sub_widgets = {
          {
            setting_id = "havoc_offset_x",
            type = "numeric",
            default_value = -435,
            range = { -500, 1000 },
            step_size = 10,
            unit_text = "浩劫 X 偏移"
          },
          {
            setting_id = "havoc_offset_y",
            type = "numeric",
            default_value = 0,
            range = { -200, 1000 },
            step_size = 10,
            unit_text = "浩劫 Y 偏移"
          },
          {
            setting_id = "havoc_name_font_size",
            type = "numeric",
            default_value = 20,
            range = { 8, 64 },
            step_size = 1,
            unit_text = "浩劫标题字体大小"
          },
          {
            setting_id = "havoc_description_font_size",
            type = "numeric",
            default_value = 17,
            range = { 8, 64 },
            step_size = 1,
            unit_text = "浩劫描述字体大小"
          },
          {
            setting_id = "havoc_rank_offset_x",
            type = "numeric",
            default_value = 0,
            range = { -200, 1000 },
            step_size = 10,
            unit_text = "浩劫等级 X 偏移"
          },
          {
            setting_id = "havoc_rank_offset_y",
            type = "numeric",
            default_value = 0,
            range = { -200, 1000 },
            step_size = 10,
            unit_text = "浩劫等级 Y 偏移"
          },
        }
      },
      -- 材料
      {
        setting_id = "material_info",
        type = "group",
        sub_widgets = {
          {
            setting_id = "plasteel_offset_x",
            type = "numeric",
            default_value = 0,
            range = { -1000, 1000 },
            step_size = 10,
            unit_text = "plasteel X 偏移"
          },
          {
            setting_id = "plasteel_offset_y",
            type = "numeric",
            default_value = 0,
            range = { -100, 1000 },
            step_size = 10,
            unit_text = "plasteel Y 偏移"
          },
          {
            setting_id = "diamantine_offset_x",
            type = "numeric",
            default_value = 0,
            range = { -1000, 1000 },
            step_size = 10,
            unit_text = "Diamantine X 偏移"
          },
          {
            setting_id = "diamantine_offset_y",
            type = "numeric",
            default_value = 0,
            range = { -100, 1000 },
            step_size = 10,
            unit_text = "Diamantine Y 偏移"
          },
        }
      },
      -- 右侧任务板
      {
        setting_id = "right_board",
        type = "group",
        sub_widgets = {
          {
            setting_id = "right_board_offset_x",
            type = "numeric",
            default_value = 0,
            range = { -1500, 500 },
            step_size = 10,
            unit_text = "右侧任务板 X 偏移"
          },
          {
            setting_id = "right_board_offset_y",
            type = "numeric",
            default_value = 0,
            range = { -500, 500 },
            step_size = 10,
            unit_text = "右侧任务板 Y 偏移"
          },
        }
      },
      -- 计分板
      {
        setting_id = "scoreboard",
        type = "group",
        sub_widgets = {
          {
            setting_id = "scoreboard_offset_x",
            type = "numeric",
            default_value = -260,
            range = { -1000, 1000 },
            step_size = 10,
            unit_text = "计分板 X 偏移"
          },
          {
            setting_id = "scoreboard_offset_y",
            type = "numeric",
            default_value = -100,
            range = { -1000, 1000 },
            step_size = 10,
            unit_text = "计分板 Y 偏移"
          },
        }
      }
	}
  }
}
