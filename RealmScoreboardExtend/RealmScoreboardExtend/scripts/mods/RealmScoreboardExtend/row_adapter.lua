-- Adapted from installed scoreboard's row renderer; see SOURCE_SHA256.txt.
-- Retains plugin grouping, children, icons, formatting and scoring semantics.
local ext = get_mod("RealmScoreboardExtend")
local mod = get_mod("scoreboard")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UISettings = require("scripts/settings/ui/ui_settings")
local TextUtilities = require("scripts/utilities/ui/text")
local base_z = 100
local average = function(data, players)
    local average = 0
    local num_player = 0
    for _, player in pairs(players) do
        if player then
            num_player = num_player + 1
            if num_player <= #players then
                local account_id = player:account_id() or player:name()
                local value = data[account_id] and data[account_id].score or 0
                average = average + value
            end
        end
    end
    local num = math.max(num_player, 1)
    local average = average or 0
    return average / num
end

local normalize_values = function(self, players, this_row)
	local target_average = 100
    if this_row.data then
        local data = ext.copy(this_row.data)
        local av = average(data, players)
        if av ~= 0 then
            if av > target_average then
                local start_av = av
                local safety = 10000
                while av > target_average and safety > 0 do
                    for account_id, values in pairs(data) do
                        values.score = values.score * 0.9
                    end
                    av = average(data, players)
                    safety = safety - 1
                end
            elseif av < target_average then
                local start_av = av
                local safety = 10000
                while av < target_average and safety > 0 do
                    for account_id, values in pairs(data) do
                        values.score = values.score * 1.1
                    end
                    av = average(data, players)
                    safety = safety - 1
                end
            end
        end
        return data
    end
    return this_row.data
end
local update_row_values = function(self, this_row, sorted_rows, loaded_players)
    local header = this_row.name == "header"
    local player_manager = Managers.player
    local players = loaded_players or ext.all_players()
    local validation = this_row.validation
    if not header then
        local player_num = 1
        for _, player in pairs(players) do
            if player_num <= #players then
                local account_id = player:account_id() or player:name()
                local rows = {}
                if this_row.summary then
                    for _, group in pairs(sorted_rows) do
                        for _, row in pairs(group) do
                            if table.contains(this_row.summary, row.name) then
                                rows[#rows+1] = row
                            end
                        end
                    end
                else
                    rows[#rows+1] = this_row
                end

                local score = 0
                for _, row in pairs(rows) do
                    local add_score = 0
                    if row.data then
                        local normalized_data = row.data
                        if this_row.score then
                            normalized_data = mod:normalize_values(players, row)
                        end
                        if this_row.score then
                            local validation = row.validation
                            add_score = validation:score(normalized_data, account_id)
                        else
                            local row_data = normalized_data[account_id]
                            add_score = row_data and row_data.score or 0
                        end
                    end
                    score = score + add_score
                end

                this_row.data = this_row.data or {}
                this_row.data[account_id] = this_row.data[account_id] or {}
                this_row.data[account_id].score = score --/ #rows
            end
            player_num = player_num + 1
        end
    end

    if this_row.score or this_row.normalize then
        this_row.data = mod:normalize_values(players, this_row)
    end

    local validation = this_row.validation
    if this_row.data and validation then
        for account_id, row_data in pairs(this_row.data) do
            row_data.is_best = validation.is_best(this_row.data, account_id)
            row_data.is_worst = validation.is_worst(this_row.data, account_id)
        end
    end
end
local create_row_widget = function(self, index, current_offset, visible_rows, this_row, sorted_rows, groups, widgets_by_name, loaded_players, is_history, end_view, _obj, _create_widget_callback, ui_renderer)
    local _definitions = mod:io_dofile("scoreboard/scripts/mods/scoreboard/scoreboard/scoreboard_view_definitions")
    local _blueprints = mod:io_dofile("scoreboard/scripts/mods/scoreboard/scoreboard/scoreboard_view_blueprints")
    local _settings = mod:io_dofile("scoreboard/scripts/mods/scoreboard/scoreboard/scoreboard_view_settings")
    local scoreboard_widget = widgets_by_name["scoreboard"]
    local player_manager = Managers.player

    local generate_scores = mod:get("generate_scores")
    local widget = nil
    local ctx = ext.context
    local template, player_pass_map, icon_pass_map, background_pass_map = ext.blueprint(_blueprints["scoreboard_row"], ctx)
    local size = template.size
    local pass_template = template.pass_template
    local name = "scoreboard_row_"..this_row.name
    local header = this_row.name == "header"
    local header_height = _settings.scoreboard_row_header_height
    local row_height = (this_row.name == "score" or this_row.big) and 35
        or header and header_height
        or this_row.score and _settings.scoreboard_row_big_height
        or 18
    local font_size = this_row.big and 30
        or header and 20
        or this_row.score and 24
        or 16
    local height = scoreboard_widget.style.style_id_3.size[2]
    row_height = math.ceil(row_height * (ext:get("font_percent") or 100) / 100)
    
    if this_row.parent then
        local parent = widgets_by_name["scoreboard_row_"..this_row.parent]
        if parent then
            current_offset = parent.offset[2]
            row_height = parent.style.style_id_1.size[2]
        end
    end

    local players = ctx.players

    local player_num = 1
    for _, player in ipairs(players) do
        if player_num <= #players then
            local account_id = player:account_id() or player:name()
            for _, group in pairs(sorted_rows) do
                for _, row in pairs(group) do
                    if row.data then
                        if not row.data[account_id] then
                            row.data[account_id] = {
                                score = 0
                            }
                        end
                    end
                end
            end
        end
    end

    if header then
        pass_template[1].value = ""
        pass_template[1].style.font_size = font_size
        local num_players = 0
        for i = 1, ctx.layout.columns do
            pass_template[player_pass_map[i]].value = ""
        end
        for _, player in ipairs(players) do
            num_players = num_players + 1
            if num_players <= #players then
                if player.name then
                    local name = ext.text.player_name(player, ext.model, ext, is_history)
                    local account_id = player:account_id() or player:name()
                    if mod:is_me(account_id) then
                        name = TextUtilities.apply_color_to_text(name, Color.ui_orange_light(255, true))
                    end
                    local symbol = player.string_symbol --or player._profile and player._profile.archetype.string_symbol
                    local profile = player.profile and player:profile()
			        local archetype_name = profile and profile.archetype and profile.archetype.name
			        symbol = symbol or (archetype_name and UISettings.archetype_font_icon[archetype_name])
                    if symbol then
                        name = symbol.." "..name
                    end
                    pass_template[player_pass_map[num_players]].value = name
                end
            end
        end
    end

    local this_text = ext.text.label(this_row, groups, is_history)

    pass_template[1].style.font_size = (header or this_row.big or this_row.score) and font_size or 14
    pass_template[1].style.size[2] = row_height
    for _, i in pairs(player_pass_map) do
        pass_template[i].style.font_size = font_size
        pass_template[i].style.size[2] = row_height
    end

    local children = mod:get_row_children(this_row.name, nil, sorted_rows)
    if #children > 0 then
        for _, i in pairs(player_pass_map) do
            pass_template[i].value = ""
        end
    end

    if this_row.icon then
        for _, i in pairs(icon_pass_map) do
            local width = tonumber(this_row.icon_width) or pass_template[i].style.size[1]
            pass_template[i].style.size[1] = width
            pass_template[i].style.size[2] = row_height
        end
    end

    if this_row.parent then

        local children, val_index = mod:get_row_children(this_row.parent, this_row.name, sorted_rows)
        if #children > 1 then
            for _, i in pairs(player_pass_map) do
                local this_size = {_settings.scoreboard_column_width / #children, pass_template[i].style.size[2]}
                local offset = this_size[1] * (val_index - 1)
                pass_template[i].style.offset[1] = pass_template[i].style.offset[1] + offset
                pass_template[i].style.size[1] = this_size[1]
                local background = background_pass_map[tostring(i)]
                if background then
                    pass_template[background].style.visible = false
                end
                local icon = icon_pass_map[tostring(i)]
                if icon and this_row.icon then
                    pass_template[i].style.size[1] = this_size[1] / 2
                    pass_template[i].style.offset[1] = pass_template[i].style.offset[1] + this_size[1] / 2
                    pass_template[i].style.text_horizontal_alignment = "left"
                    pass_template[icon].style.offset[1] = pass_template[icon].style.offset[1] + offset + (this_size[1] / 2 - pass_template[icon].style.size[1])
                end

            end
        end

        pass_template[1].value = ""
    elseif index > 1 then

        if this_row.icon then
            for _, i in pairs(player_pass_map) do
                local icon = icon_pass_map[tostring(i)]
                if icon then
                    pass_template[i].style.text_horizontal_alignment = "left"
                    pass_template[i].style.offset[1] = pass_template[i].style.offset[1] + pass_template[icon].style.size[1]
                end
            end
        end

        pass_template[1].value = this_text
        if this_row.score and generate_scores > 1 then
            pass_template[1].value = ""
        end
    end

    if not is_history then
        mod:update_row_values(this_row, sorted_rows, ctx.all)
    else
        ext.mark_history_values(this_row, ctx.all)
    end
    local zero_setting = mod:get("zero_values")
    local worst_setting = mod:get("worst_values")
    local has_mytext = false
    if not header and #children == 0 then
        local player_num = 1
        for i = 1, ctx.layout.columns do
            local pass_index = player_pass_map[i]
            pass_template[pass_index].value = ""
            pass_template[icon_pass_map[tostring(pass_index)]].style.visible = false
        end
        for _, player in ipairs(players) do
            if player_num <= #players then
                local account_id = player:account_id() or player:name()
                local pass_index = player_pass_map[player_num]

                local row_data = this_row.data and this_row.data[account_id]
                local score = row_data and row_data.score or 0
                local mytext = row_data and row_data.text_data or nil
                if this_row.is_text then
                    score = ext.text.literal(row_data and (row_data.text or row_data.text_data))
                elseif mytext then
                    score = ext.text.literal(mytext)
                    has_mytext = true
                elseif not this_row.is_text then
                    local decimals = this_row.decimals or 0
                    decimals = this_row.is_time and 1 or decimals
                    score = this_row.is_time and mod:shorten_time(score, decimals) or mod:shorten_value(score, decimals)

                    local color = nil
                    local num_score = score
                    num_score = string.gsub(num_score, "s", "")
                    num_score = tonumber(num_score)
                    if num_score and num_score == 0 and zero_setting > 1 then
                        if zero_setting == 2 then
                            pass_template[pass_index].style.visible = false
                        elseif zero_setting == 3 then
                            color = Color.ui_grey_light(255, true)
                            pass_template[icon_pass_map[tostring(pass_index)]].style.visible = true
                        end
                    else
                        if this_row.icon then
                            pass_template[icon_pass_map[tostring(pass_index)]].style.visible = true
                        end
                        if row_data and row_data.is_best then
                            color = Color.ui_orange_light(255, true)
                        elseif row_data and row_data.is_worst then
                            if worst_setting == 2 then
                                color = Color.ui_grey_light(255, true)      -- Grey (original)
                            elseif worst_setting == 3 then
                                color = Color.ui_red_light(255, true)       -- Red
                            elseif worst_setting == 4 then
                                color = Color.ui_blue_light(255, true)      -- Blue
                            elseif worst_setting == 5 then
                                color = Color.ui_purple_light(255, true)    -- Purple
                            elseif worst_setting == 6 then
                                color = Color.ui_yellow_light(255, true)    -- Yellow
                            elseif worst_setting == 7 then
                                color = Color.ui_pink_light(255, true)      -- Pink                            end
                            end
                        end
                    end

                    if color then
                        score = TextUtilities.apply_color_to_text(tostring(score), color)
                        if mod:is_me(account_id) and this_row.parent then
                            local parent = widgets_by_name["scoreboard_row_"..this_row.parent]
                            if parent then
                                local parent_text = parent.content.text
                                local s, e = string.find(parent_text, this_text, 1, true)
                                if s then
                                    local colored = TextUtilities.apply_color_to_text(this_text, color)
                                    parent.content.text = ext.text.replace_literal(parent_text, this_text, colored)
                                end
                            end
                        elseif mod:is_me(account_id) then
                            pass_template[1].value = TextUtilities.apply_color_to_text(tostring(pass_template[1].value), color)
                        end
                    end
                end

                if this_row.score and generate_scores > 1 then
                    score = ""
                end

                if this_row.icon then
                    pass_template[icon_pass_map[tostring(pass_index)]].value = this_row.icon
                else
                    pass_template[icon_pass_map[tostring(pass_index)]].style.visible = false
                end


                pass_template[pass_index].value = score
            end
            player_num = player_num + 1
        end
    end

    local alternate_row = visible_rows % 2 == 0
    if alternate_row and not this_row.parent then
        for _, i in pairs(background_pass_map) do
            pass_template[i].style.visible = false
        end
        pass_template[#pass_template].style.size[2] = row_height
    elseif not this_row.parent then
        for _, i in pairs(background_pass_map) do
            pass_template[i].style.size[2] = row_height
        end
        pass_template[#pass_template].style.visible = false
    else
        pass_template[#pass_template].style.visible = false
    end

    local widget_definition = UIWidget.create_definition(pass_template, "scoreboard_rows", nil, size)

    if widget_definition then
        widget = _obj[_create_widget_callback](_obj, name, widget_definition)

        widget.alpha_multiplier = 0
        
        if is_history then
            widget.offset = {0, current_offset, base_z + 1}
        elseif not end_view then
            widget.offset = {0, current_offset, base_z + 1}
        else
            local offset_y = current_offset - 100
            if this_row.parent then
                local parent = widgets_by_name["scoreboard_row_"..this_row.parent]
                if parent then offset_y = parent.offset[2] end
            end
            widget.offset = {0, offset_y, base_z + 1}
        end

        if header then
            if header then widget.content.text = "" end
            widget.style.style_id_1.font_size = font_size
            local num_players = 0
            for _, player in ipairs(players) do
                num_players = num_players + 1
                if num_players <= #players and ui_renderer then
                    local player_name = ext.text.player_name(player, ext.model, ext, is_history)
                    local symbol = player.string_symbol --or player._profile and player._profile.archetype.string_symbol
                    local profile = player.profile and player:profile()
			        local archetype_name = profile and profile.archetype and profile.archetype.name
			        symbol = symbol or (archetype_name and UISettings.archetype_font_icon[archetype_name])
                    if symbol then
                        player_name = symbol.." "..player_name
                    end
                    ext.fit_text(player_name, widget.style["style_id_"..player_pass_map[num_players]], _settings.scoreboard_column_width, ui_renderer)
                end
            end
        elseif this_row.is_text then
            local num_players = 0
            for _, player in ipairs(players) do
                num_players = num_players + 1
                if num_players <= #players and ui_renderer then
                    local account_id = player:account_id() or player:name()
                    local score = this_row.data[account_id].text
                    score = ext.text.literal(score)
                    if score then
                        ext.fit_text(score, widget.style["style_id_"..player_pass_map[num_players]], _settings.scoreboard_column_width, ui_renderer)
                    end
                end
            end
        elseif has_mytext then
            local num_players = 0
            for _, player in ipairs(players) do
                num_players = num_players + 1
                if num_players <= #players and ui_renderer then
                    local account_id = player:account_id() or player:name()
                    local score = this_row.data[account_id].text_data
                    score = ext.text.literal(score)
                    if score then
                        ext.fit_text(score, widget.style["style_id_"..player_pass_map[num_players]], _settings.scoreboard_column_width, ui_renderer)
                    end
                end
            end
        end

        self._widget_times[widget.name] = current_offset / 1000

        ext.decorate(widget, player_pass_map, header, ctx, ui_renderer)
    return widget, row_height
    end
end
return {
    create_row_widget = create_row_widget,
    update_row_values = update_row_values,
    normalize_values = normalize_values,
}
