-- TimerIconElement.lua
local mod                 = get_mod("ServoTempus")

-- Ensure HudElementBase is loaded; we reference it by string in `class()`
local _                   = require("scripts/ui/hud/elements/hud_element_base")
local UIWidget            = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local ICON_SIZE         = {115, 115}
local ICON_TEXTURE_PATH = "content/ui/vector_textures/symbols/cog_skull_01"

local scenegraph_definition = {
  screen = UIWorkspaceSettings.screen,
  timer_icon_pivot = {
    parent               = "screen",
    horizontal_alignment = "center",
    vertical_alignment   = "center",
    size                 = ICON_SIZE,
    position             = { 0, 0, 950 },
  },
}

local widget_definitions = {
  timer_icon = UIWidget.create_definition(
    {
      {
        pass_type = "slug_icon",
        style_id  = "timer_icon",
        value     = ICON_TEXTURE_PATH,
        style     = {
          horizontal_alignment = "center",
          vertical_alignment   = "center",
          size                 = ICON_SIZE,
          offset               = { 0, 0, 0 },
          color                = { 255, 255, 0, 0 },
        },
      },
    },
    "timer_icon_pivot",
    { visible = false }
  ),
}

local Definitions = {
  scenegraph_definition = scenegraph_definition,
  widget_definitions    = widget_definitions,
  legend_inputs         = {},
}

-- Use the base class name *string* so .super is assigned
local TimerIconElement = class("TimerIconElement", "HudElementBase")

function TimerIconElement:init(parent, draw_layer, start_scale)
  local offset_x   = mod:get("icon_offset_x") or 0
  local offset_y   = mod:get("icon_offset_y") or 0
  local icon_color = mod:get("icon_color")

  local color_map = {
    black  = {255,   0,   0,   0},
    blue   = {255,   0,   0, 255},
    green  = {255,   0, 255,   0},
    red    = {255, 255,   0,   0},
    white  = {255, 255, 255, 255},
    yellow = {255, 255, 255,   0},
  }
  local chosen_color = color_map[icon_color] or color_map.red

  -- apply only X/Y offset to the existing center pivot
  local pivot_def = Definitions.scenegraph_definition.timer_icon_pivot
  pivot_def.position = {
    pivot_def.position[1] + offset_x,
    pivot_def.position[2] + offset_y,
    pivot_def.position[3],
  }

  TimerIconElement.super.init(self, parent, draw_layer, start_scale, Definitions)

  self._visible_until = 0
  self:_register_event("servo_tempus_show_icon", "show_icon")

  self._widgets_by_name.timer_icon.style.timer_icon.color = chosen_color
end

function TimerIconElement:show_icon(duration)
  duration = duration or 3
  self._widgets_by_name.timer_icon.content.visible = true
  self._visible_until = Managers.time:time("ui") + duration
end

function TimerIconElement:update(dt, t, ui_renderer, render_settings, input_service)
  if self._visible_until > 0 and t >= self._visible_until then
    self._visible_until = 0
    self._widgets_by_name.timer_icon.content.visible = false
  end

  TimerIconElement.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

return TimerIconElement
