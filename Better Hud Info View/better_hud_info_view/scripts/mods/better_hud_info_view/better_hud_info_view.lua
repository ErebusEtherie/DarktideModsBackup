-- better_hud_info_view.lua
local mod = get_mod("better_hud_info_view")

-- default value, left buff
local left_buff_offset_y = mod:get("left_buff_offset_y")
if left_buff_offset_y == nil then left_buff_offset_y = 1000 end

-- default value, mission
local circ_x_offset = mod:get("circumstance_offset_x")
if circ_x_offset == nil then circ_x_offset = -435 end

local circ_y_offset = mod:get("circumstance_offset_y")
if circ_y_offset == nil then circ_y_offset = 0 end

local danger_x_offset = mod:get("danger_offset_x")
if danger_x_offset == nil then danger_x_offset = 0 end

local danger_y_offset = mod:get("danger_offset_y")
if danger_y_offset == nil then danger_y_offset = 0 end

-- default value, havoc
local havoc_x_offset = mod:get("havoc_offset_x")
if havoc_x_offset == nil then havoc_x_offset = -435 end

local havoc_y_offset = mod:get("havoc_offset_y")
if havoc_y_offset == nil then havoc_y_offset = 0 end

local havoc_rank_x_offset = mod:get("havoc_rank_offset_x")
if havoc_rank_x_offset == nil then havoc_rank_x_offset = 0 end

local havoc_rank_y_offset = mod:get("havoc_rank_offset_y")
if havoc_rank_y_offset == nil then havoc_rank_y_offset = 0 end

-- default value, map
local mission_x_offset = mod:get("mission_offset_x")
if mission_x_offset == nil then mission_x_offset = 0 end

local mission_y_offset = mod:get("mission_offset_y")
if mission_y_offset == nil then mission_y_offset = 0 end

-- default value, materials
local plasteel_x_offset = mod:get("plasteel_offset_x")
if plasteel_x_offset == nil then plasteel_x_offset = 0 end

local plasteel_y_offset = mod:get("plasteel_offset_y")
if plasteel_y_offset == nil then plasteel_y_offset = 0 end

local diamantine_x_offset = mod:get("diamantine_offset_x")
if diamantine_x_offset == nil then diamantine_x_offset = 0 end

local diamantine_y_offset = mod:get("diamantine_offset_y")
if diamantine_y_offset == nil then diamantine_y_offset = 0 end

-- default value, scoreboard
local scoreboard_x_offset = mod:get("scoreboard_offset_x")
if scoreboard_x_offset == nil then scoreboard_x_offset = -260 end

local scoreboard_y_offset = mod:get("scoreboard_offset_y")
if scoreboard_y_offset == nil then scoreboard_y_offset = -100 end

-- default value, right board
-- local right_board_offsets = {
  -- achievements_1 = {x = 0, y = 0},
  -- achievements_2 = {x = 0, y = 105},
  -- achievements_3 = {x = 0, y = 210},
  -- achievements_4 = {x = 0, y = 316},
  -- achievements_5 = {x = 0, y = 422},

  -- contracts_1 = {x = 0, y = 0},
  -- contracts_2 = {x = 0, y = 77},
  -- contracts_3 = {x = 0, y = 154},
  -- contracts_4 = {x = 0, y = 227},
  -- contracts_5 = {x = 0, y = 304},

  -- right_grid_background = {x = 0, y = 0},
  -- right_grid_stick      = {x = 0, y = 0},
  -- right_header_background = {x = 0, y = 0},
  -- right_header_stick    = {x = 0, y = 0},
  -- right_header_title    = {x = 0, y = 0},
  -- right_input_hint      = {x = 0, y = 0},
  -- right_timer           = {x = 0, y = 0},

  -- tab_1 = {x = 318, y = 0},
  -- tab_2 = {x = 360, y = 0},
  -- tab_3 = {x = 402, y = 0},
  -- tab_4 = {x = -40, y = 0},

  -- event_1 = {x = 0, y = 0},
  -- event_2 = {x = 0, y = 34},
  -- event_3 = {x = 0, y = 63},
  -- event_4 = {x = 0, y = 161},
  -- event_5 = {x = 0, y = 190},
  -- event_6 = {x = 0, y = 261},
  -- event_7 = {x = 0, y = 332},
  -- event_8 = {x = 0, y = 403},
  -- event_9 = {x = 0, y = 474},
  -- event_10 = {x = 0, y = 541},
  -- event_11 = {x = 0, y = 608},
-- }

local right_board_default_positions = {}
local right_board_x_offset = mod:get("right_board_offset_x") or 0
local right_board_y_offset = mod:get("right_board_offset_y") or 0

-- Mortis Trials toggle function, should_adjust_buff()
local cached_mortis_toggle = mod:get("mortis_toggle")
local cached_mode = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()

local function update_cached_mode()
    cached_mode = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
end

local function should_adjust_buff()
    update_cached_mode()
    return not (cached_mortis_toggle and cached_mode == "survival")
end

-- 变更监听
mod.on_setting_changed = function(id)
	-- left buff
	if id == "left_buff_offset_y" then
        left_buff_offset_y = mod:get(id)
	elseif id == "mortis_toggle" then
        cached_mortis_toggle = mod:get(id)
	-- mission	
    elseif id == "circumstance_offset_x" then
        circ_x_offset = mod:get(id)
    elseif id == "circumstance_offset_y" then
		circ_y_offset = mod:get(id)
    elseif id == "danger_offset_x" then
      	danger_x_offset = mod:get(id)
    elseif id == "danger_offset_y" then
      	danger_y_offset = mod:get(id)
	-- havoc
    elseif id == "havoc_offset_x" then
        havoc_x_offset = mod:get(id)
    elseif id == "havoc_offset_y" then
        havoc_y_offset = mod:get(id)
    elseif id == "havoc_rank_offset_x" then
        havoc_rank_x_offset = mod:get(id)
    elseif id == "havoc_rank_offset_y" then
        havoc_rank_y_offset = mod:get(id)
	-- map
    elseif id == "mission_offset_x" then
        mission_x_offset = mod:get(id)
    elseif id == "mission_offset_y" then
        mission_y_offset = mod:get(id)
	-- materials
	elseif id == "diamantine_offset_x" then
    diamantine_x_offset = mod:get(id)
	elseif id == "diamantine_offset_y" then
		diamantine_y_offset = mod:get(id)
	elseif id == "plasteel_offset_x" then
		plasteel_x_offset = mod:get(id)
	elseif id == "plasteel_offset_y" then
		plasteel_y_offset = mod:get(id)
	-- right board
	elseif id == "right_board_offset_x" then
		right_board_x_offset = mod:get(id)
	elseif id == "right_board_offset_y" then
		right_board_y_offset = mod:get(id)
	-- scoreboard
	elseif id == "scoreboard_offset_x" then
		scoreboard_x_offset = mod:get(id)
	elseif id == "scoreboard_offset_y" then
		scoreboard_y_offset = mod:get(id)
    end
end

-- 防止重复 hook
local hooked_overlay = false

local function apply_offset(widgets, name, x, y)
  local widget = widgets[name]
  if widget and widget.offset then
    widget.offset[1] = x
    widget.offset[2] = y
  end
end

local function apply_font_size(widgets, widget_name, style_key, size)
  local widget = widgets[widget_name]
  if widget and widget.style and widget.style[style_key] then
    widget.style[style_key].font_size = size
  end
end

-- main
mod:hook_safe("UIHud", "init", function(self)
    if hooked_overlay then return end
    hooked_overlay = true

    mod:hook_safe("HudElementTacticalOverlay", "_update_left_panel_elements", function(self, ui_renderer)
		-- pos buff panel
		if not should_adjust_buff() then return end
		self:set_scenegraph_position("left_panel", 0, mod:get("left_buff_offset_y") or 0)
		-- pos right board			
		local x_offset = mod:get("right_board_offset_x") or 0
		local y_offset = mod:get("right_board_offset_y") or 0
		local right_panel_nodes = {
			"right_panel",
			-- "right_panel_header",
			"right_panel_content"
		}
		for _, node_name in ipairs(right_panel_nodes) do
			local scenegraph = self._ui_scenegraph and self._ui_scenegraph[node_name]
			if scenegraph and scenegraph.position then
				if not right_board_default_positions[node_name] then
					right_board_default_positions[node_name] = {
						x = scenegraph.position[1],
						y = scenegraph.position[2]
					}
				end
				local base_pos = right_board_default_positions[node_name]
				self:set_scenegraph_position(
					node_name,
					base_pos.x + x_offset,
					base_pos.y + y_offset
				)
			end
		end
	end)
	
    mod:hook_safe("HudElementTacticalOverlay", "update", function(self)
        local widgets = self._widgets_by_name

        if widgets then
			-- pos mission
            apply_offset(widgets, "circumstance_info", circ_x_offset, circ_y_offset - left_buff_offset_y)
            apply_offset(widgets, "danger_info", danger_x_offset,
				should_adjust_buff() and (danger_y_offset - left_buff_offset_y) or danger_y_offset)
			-- pos havoc
            apply_offset(widgets, "havoc_circumstance_info", havoc_x_offset, havoc_y_offset - left_buff_offset_y)
            apply_offset(widgets, "havoc_rank_info", havoc_rank_x_offset, havoc_rank_y_offset - left_buff_offset_y)
			-- pos map
            apply_offset(widgets, "mission_info", mission_x_offset,
				should_adjust_buff() and (mission_y_offset - left_buff_offset_y) or mission_y_offset)
			-- pos materials
			apply_offset(widgets, "diamantine_info", diamantine_x_offset + 130, diamantine_y_offset)
			apply_offset(widgets, "plasteel_info", plasteel_x_offset, plasteel_y_offset)
			-- size mission
            apply_font_size(widgets, "circumstance_info", "circumstance_name", mod:get("circumstance_name_font_size") or 24)
            apply_font_size(widgets, "circumstance_info", "circumstance_description", mod:get("circumstance_description_font_size") or 20)
			-- size havoc
            for i = 1, 4 do
				apply_font_size(widgets, "havoc_circumstance_info", "circumstance_name_0" .. i, mod:get("havoc_name_font_size") or 20)
				apply_font_size(widgets, "havoc_circumstance_info", "circumstance_description_0" .. i, mod:get("havoc_description_font_size") or 17)
            end
			-- pos right board	
			-- for name, pos in pairs(right_board_offsets) do
				-- apply_offset(widgets, name, pos.x + right_board_x_offset, pos.y + right_board_y_offset)
			-- end

			-- pos scoreboard
			local scoreboard_graph = self._ui_scenegraph and rawget(self._ui_scenegraph, "scoreboard")
			if scoreboard_graph and type(scoreboard_graph.position) == "table" then
				local base_x = 135 -- scoreboard default value
				scoreboard_graph.position[1] = base_x + (scoreboard_x_offset or 0)
				scoreboard_graph.position[2] = (scoreboard_y_offset or 0)
			end
        end
    end)
end)


-- COMMAND 1: /mode
-- hub
-- coop_complete_objective
-- survival
-- shooting_range
-- unknown
-- mod:command("mode", "当前游戏模式", function()
    -- local mode = Managers.state.game_mode and Managers.state.game_mode:game_mode_name() or "unknown"
    -- mod:echo("当前游戏模式: " .. tostring(mode))
-- end)


-- COMMAND 2: /right_board_offsets
-- local right_board_widgets = {
  -- "achievements_1", "achievements_2", "achievements_3", "achievements_4", "achievements_5",
  -- "contracts_1", "contracts_2", "contracts_3", "contracts_4", "contracts_5",
  -- "right_grid_background", "right_grid_stick",
  -- "right_header_background", "right_header_stick", "right_header_title",
  -- "right_input_hint", "right_timer",
  -- "tab_1", "tab_2", "tab_3", "tab_4",
  -- "event_1", "event_2", "event_3", "event_4", "event_5", "event_6",
  -- "event_7", "event_8", "event_9", "event_10", "event_11",
-- }

-- mod:command("right_board_offsets", "列出右侧任务面板所有 widget 的 offset 值", function()
  -- local ui = Managers.ui
  -- local hud = ui and ui._hud
  -- local overlay = hud and hud._elements and hud._elements["HudElementTacticalOverlay"]

  -- if not overlay then
    -- mod:echo("找不到 HudElementTacticalOverlay，可能未在战斗中")
    -- return
  -- end

  -- local widgets = overlay._widgets_by_name

  -- for _, name in ipairs(right_board_widgets) do
    -- local widget = widgets and widgets[name]
    -- local offset = widget and widget.offset
    -- if offset then
      -- mod:echo(string.format("%s: x = %d, y = %d", name, offset[1], offset[2]))
    -- else
      -- mod:echo("未找到 widget: " .. name)
    -- end
  -- end
-- end)


-- COMMAND 3: /list_scenegraph_nodes
-- "right_panel",
-- "right_panel_header",
-- "right_panel_content"
-- mod:command("list_scenegraph_nodes", "列出当前 HudElementTacticalOverlay 的所有 scenegraph 节点名", function()
  -- local ui = Managers.ui
  -- local hud = ui and ui._hud
  -- local overlay = hud and hud._elements and hud._elements["HudElementTacticalOverlay"]

  -- if not overlay then
    -- mod:echo("找不到 HudElementTacticalOverlay，可能未在战斗中")
    -- return
  -- end

  -- local scenegraph = overlay._ui_scenegraph

  -- if not scenegraph then
    -- mod:echo("未找到 scenegraph")
    -- return
  -- end

  -- mod:echo("当前 HudElementTacticalOverlay 的所有 scenegraph 节点：")

  -- for node_name, _ in pairs(scenegraph) do
    -- mod:echo(node_name)
  -- end
-- end)