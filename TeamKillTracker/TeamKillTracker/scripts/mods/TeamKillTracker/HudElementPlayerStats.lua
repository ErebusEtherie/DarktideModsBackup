local mod = get_mod("TeamKillTracker")

local Text = require("scripts/utilities/ui/text")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local font_size = 16
local size = {400, 200}

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
	teamKillContainer = {
		parent = "screen",
		scale = "fit",
		vertical_alignment = "bottom",
		horizontal_alignment = "left",
		size = size,
		position = {550, -30, 10},
	},
}

local teamKillStyle = {
	line_spacing = 1.2,
	font_size = font_size,
	drop_shadow = true,
	font_type = "machine_medium",
	text_color = {255, 255, 255, 255},
	size = size,
	text_horizontal_alignment = "left",
	text_vertical_alignment = "top",
}

local widget_definitions = {
	teamKillCounter = UIWidget.create_definition(
		{ {
			value_id = "text",
			style_id = "text",
			pass_type = "text",
			style = teamKillStyle,
		} },
		"teamKillContainer"
	),
}

local HudElementPlayerStats = class("HudElementPlayerStats", "HudElementBase")

HudElementPlayerStats.init = function(self, parent, draw_layer, start_scale)
	HudElementPlayerStats.super.init(self, parent, draw_layer, start_scale, {
		scenegraph_definition = scenegraph_definition,
		widget_definitions = widget_definitions,
	})
	self.is_in_hub = mod._is_in_hub()
end

HudElementPlayerStats.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudElementPlayerStats.super.update(self, dt, t, ui_renderer, render_settings, input_service)
	
	if self.is_in_hub then
		self._widgets_by_name.teamKillCounter.content.text = ""
		return
	end
	
    -- Сдвиг по стилю текста, если скрыты строки пользователей, но показывается строка Team Kills
    do
        local style = self._widgets_by_name.teamKillCounter.style.text
        style.offset = style.offset or {0, 0, 0}
        self._base_offset_y = self._base_offset_y or style.offset[2] or 0

        local line_height = math.floor(font_size * teamKillStyle.line_spacing)
        local extra_offset_y = 0
        if not mod.hide_team_kills and mod.hide_user_kills then
            -- опускаем на 4 строки вниз
            extra_offset_y = line_height * 4
        end
        style.offset[2] = self._base_offset_y + extra_offset_y
    end

    -- Обновление текста
    local total_kills = 0
    local total_damage = 0
    local players_with_kills = {}
	
	-- Получаем список текущих игроков в команде
	local current_players = {}
    if Managers.player then
        local players = Managers.player:players()
        for _, player in pairs(players) do
            if player then
                local account_id = player:account_id() or player:name()
                if account_id then
                    current_players[account_id] = player:name() or account_id
                end
            end
        end
    end
	
	-- Собираем убийства только текущих игроков с убийствами > 0
    for account_id, kills in pairs(mod.player_kills or {}) do
        local display_name = current_players[account_id]
        if kills > 0 and display_name then
            total_kills = total_kills + kills
            local damage = (mod.player_damage and mod.player_damage[account_id]) or 0
            total_damage = total_damage + math.floor(damage)
            table.insert(players_with_kills, {name = display_name, kills = kills, damage = damage})
        end
    end
	
	-- Сортируем по убийствам (больше сверху)
    table.sort(players_with_kills, function(a, b)
        if a.kills == b.kills then
            return (a.damage or 0) > (b.damage or 0)
        end
        return a.kills > b.kills
    end)
	
    -- Формируем текст с учетом настроек
    local lines = {}
    local mode = mod.hud_counter_mode or mod:get("hud_counter_mode") or 1
    if not mod.hide_team_kills then
        if mode == 1 then
            table.insert(lines, "TEAM KILLS: " .. total_kills .. " / " .. total_damage)
        elseif mode == 2 then
            table.insert(lines, "TEAM KILLS: " .. total_kills)
        elseif mode == 3 then
            table.insert(lines, "TEAM DAMAGE: " .. total_damage)
        end
    end

    if not mod.hide_user_kills and #players_with_kills > 0 then
        for _, player in ipairs(players_with_kills) do
            local dmg = math.floor(player.damage or 0)
            if mode == 1 then
                table.insert(lines, player.name .. ": " .. player.kills .. " / " .. dmg)
            elseif mode == 2 then
                table.insert(lines, player.name .. ": " .. player.kills)
            elseif mode == 3 then
                table.insert(lines, player.name .. ": " .. dmg)
            end
        end
    end

    local display_text = table.concat(lines, "\n")
    self._widgets_by_name.teamKillCounter.content.text = display_text
end

return HudElementPlayerStats