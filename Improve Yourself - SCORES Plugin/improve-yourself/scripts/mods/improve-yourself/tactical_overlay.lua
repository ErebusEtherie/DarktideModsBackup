local mod = get_mod("improve-yourself")

local CLASS = CLASS
local Managers = Managers
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIFontSettings = mod:original_require("scripts/managers/ui/ui_font_settings")
local ViewElementProfilePresetsSettings = mod:original_require("scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets_settings")
local VisualConstants = mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/views/shared/improve_yourself_visual_constants")

local CUSTOM_ICON_PATHS = {
    "content/ui/materials/icons/item_types/ranged_weapons",
    "content/ui/materials/icons/circumstances/assault_01",
    "content/ui/materials/icons/item_types/weapons",
    "content/ui/materials/icons/item_types/melee_weapons",
    "content/ui/materials/hud/interactions/icons/grenade",
    "content/ui/materials/icons/circumstances/hunting_grounds_01",
    "content/ui/materials/icons/circumstances/ventilation_purge_01",
    "content/ui/materials/icons/circumstances/nurgle_manifestation_01",
    "content/ui/materials/icons/pocketables/hud/scripture",
    "content/ui/materials/icons/pocketables/hud/corrupted_auspex_scanner",
    "content/ui/materials/hud/interactions/icons/barber",
    "content/ui/materials/hud/interactions/icons/forge",
    "content/ui/materials/hud/interactions/icons/mission_board",
    "content/ui/materials/icons/throwables/hud/missile_launcher",
    "content/ui/materials/icons/pocketables/hud/syringe_power",
    "content/ui/materials/hud/interactions/icons/expeditions",
    "content/ui/materials/hud/interactions/icons/valkyrie_payload",
    "content/ui/materials/hud/interactions/icons/artillery_strike",
    "content/ui/materials/hud/interactions/icons/big_fn_grenade",
    "content/ui/materials/hud/interactions/icons/valkyrie_hover",
    "content/ui/materials/hud/interactions/icons/landmine_fire",
    "content/ui/materials/hud/interactions/icons/landmine_shock",
    "content/ui/materials/hud/interactions/icons/time_syringe",
    "content/ui/materials/hud/interactions/icons/barrel_explosive",
    "content/ui/materials/backgrounds/scanner/scanner_decoration_skull",
    "content/ui/materials/hud/interactions/icons/expeditions_death",
    "content/ui/materials/hud/interactions/icons/help",
    "content/ui/materials/icons/weapons/actions/ads",
    "content/ui/materials/icons/weapons/actions/flashlight",
}

local UNICODE_ICON_CODES = {
    0xE053, 0xE000, 0xE001, 0xE002, 0xE003, 0xE004, 0xE005, 0xE006, 0xE007,
    0xE01F, 0xE021, 0xE026, 0xE029, 0xE02E, 0xE041, 0xE042, 0xE045, 0xE046,
    0xE049, 0xE04D, 0xE04F, 0xE051, 0xE107, 0xE108, 0xE109, 0xE10A, 0xE010,
    0xE011, 0xE012, 0xE013, 0xE014, 0xE015, 0xE016, 0xE017, 0xE018, 0xE019,
}

local function encode_utf8(decimal)
    if decimal < 128 then return string.char(decimal) end
    local charbytes = {}
    local markers = {{0x7FF, 192}, {0xFFFF, 224}, {0x1FFFFF, 240}}
    for bytes, vals in ipairs(markers) do
        if decimal <= vals[1] then
            for b = bytes + 1, 2, -1 do
                local rem = decimal % 64
                decimal = (decimal - rem) / 64
                charbytes[b] = string.char(128 + rem)
            end
            charbytes[1] = string.char(vals[2] + decimal)
            break
        end
    end
    return table.concat(charbytes)
end

local function damage_source_layout(values, category_order, total_height, minimum_height)
    local layout = {}
    local total_value = 0

    for order, category in ipairs(category_order) do
        local value = math.max(0, tonumber(values[category]) or 0)
        if value > 0 then
            layout[#layout + 1] = {category = category, value = value, order = order}
            total_value = total_value + value
        end
    end

    table.sort(layout, function(a, b)
        if a.value == b.value then
            return a.order < b.order
        end
        return a.value > b.value
    end)

    local count = #layout
    if count == 0 then
        return layout
    end

    local effective_minimum = math.min(minimum_height, total_height / count)
    local unresolved = {}
    for i = 1, count do
        unresolved[i] = layout[i]
    end

    local remaining_height = total_height
    local remaining_value = total_value
    while #unresolved > 0 do
        local fixed_one = false
        for i = #unresolved, 1, -1 do
            local item = unresolved[i]
            local proportional_height = remaining_value > 0 and item.value / remaining_value * remaining_height or remaining_height / #unresolved
            if proportional_height < effective_minimum then
                item.height = effective_minimum
                remaining_height = remaining_height - effective_minimum
                remaining_value = remaining_value - item.value
                table.remove(unresolved, i)
                fixed_one = true
                break
            end
        end
        if not fixed_one then
            break
        end
    end

    for _, item in ipairs(unresolved) do
        item.height = remaining_value > 0 and item.value / remaining_value * remaining_height or remaining_height / #unresolved
    end

    return layout
end

-- Resolve production icons from the shared catalogue and custom fallbacks.
-- Used by Tactical player/class and Teamplay metric icons; not part of the removed icon test screen.
local function resolve_catalogue_icon(index)
    index = tonumber(index)
    if not index then return {kind = "none"} end
    local settings = ViewElementProfilePresetsSettings or {}
    local refs = settings.optional_preset_icon_reference_keys or {}
    local lookup = settings.optional_preset_icons_lookup or {}
    local vanilla_count = #refs
    if index >= 1 and index <= vanilla_count then
        local key = refs[index]
        local material = key and lookup[key]
        if material then return {kind = "material", value = material} end
        return {kind = "none"}
    end
    local custom_index = index - vanilla_count
    if custom_index >= 1 and custom_index <= #CUSTOM_ICON_PATHS then
        return {kind = "material", value = CUSTOM_ICON_PATHS[custom_index]}
    end
    local unicode_index = custom_index - #CUSTOM_ICON_PATHS
    local code = UNICODE_ICON_CODES[unicode_index]
    if code then return {kind = "unicode", value = encode_utf8(code)} end
    return {kind = "none"}
end


local base_z = VisualConstants.tactical.base_z
local ids = {
    root = "iy_tac_root",
    panel = "iy_tac_panel",
    title = "iy_tac_title",
    subtitle = "iy_tac_subtitle",
    players = "iy_tac_players",
    defense = "iy_tac_def",
    offense = "iy_tac_off",
    team = "iy_tac_team",
    footer = "iy_tac_footer",
}

local metric_icon_indices = {
    damage_taken=14,
    times_downed=60,
    times_disabled=32,
    deaths=15,
    damage_dealt=11,
    weakspot_hits=19,
    melee_kills=29,
    ranged_kills=26,
    lesser_enemies=33,
    melee_ranged_threats=65,
    special_threats=25,
    boss_damage_dealt=70,
    coherency_efficiency=62,
    revived_operative=13,
    team_saves=17,
    ammo_score=21,
}

local categories = {
    defense = {
        label = "DEFENSE",
        direction = "lower",
        metrics = {"damage_taken", "times_downed", "times_disabled", "deaths"},
    },
    offense = {
        label = "OFFENSE",
        direction = "higher",
        metrics = {"damage_dealt", "weakspot_hits", "melee_kills", "ranged_kills", "lesser_enemies", "melee_ranged_threats", "special_threats", "boss_damage_dealt"},
    },
    team = {
        label = "TEAM CONTRIBUTION",
        direction = "higher",
        metrics = {"coherency_efficiency", "revived_operative", "team_saves", "ammo_score"},
    },
}

local role_labels = {
    generalist = "GENERALIST",
    frontline = "MELEE ANCHOR",
    horde_control = "HORDE CONTROL",
    ranged_specialist = "RANGED SPECIALIST",
    elite_boss = "ELITE & BOSS",
    support_control = "SUPPORT & CONTROL",
}

local fallback_targets = {
    damage_taken=25, times_downed=25, times_disabled=25, deaths=25,
    damage_dealt=25, weakspot_hits=25, melee_kills=25, ranged_kills=25,
    lesser_enemies=25, melee_ranged_threats=25, special_threats=25, boss_damage_dealt=25,
    coherency_efficiency=25, revived_operative=25, team_saves=25, ammo_score=25,
}

local green = {255,35,190,110}
local close = {255,126,148,126}

local function game_mode_name()
    local gm = Managers.state and Managers.state.game_mode
    return gm and gm:game_mode_name()
end

-- Prevent Tactical Overlay injection in unsupported states such as Mourningstar.
local function allowed_here()
    local mode = game_mode_name()
    return mode and mode ~= "hub" and mode ~= "prologue_hub"
end

local function target(metric)
    local role = tostring(mod:get("default_role") or "generalist")
    return tonumber(mod:get("goal_" .. role .. "_" .. metric)) or fallback_targets[metric] or 25
end

local function active_metrics(section)
    local result={}
    for _,metric in ipairs(section.metrics or {}) do
        local tier=metric=="lesser_enemies" or metric=="melee_ranged_threats" or metric=="special_threats"
        if (not tier and mod:is_metric_enabled(metric)) or (tier and mod:detailed_kill_split_enabled()) then
            result[#result+1]=metric
        end
    end
    return result
end

-- Resolve the local live player with account and name fallbacks.
local function local_player(match)
    for _, player in ipairs(match and match.players or {}) do
        if player.is_local then return player end
    end
    local account_id, player_name = mod:local_identity()
    for _, player in ipairs(match and match.players or {}) do
        if (account_id ~= nil and player.account_id == account_id)
            or (player_name ~= nil and player.name == player_name) then
            player.is_local = true
            return player
        end
    end
end

local live_metric_rows = {
    damage_taken={"damage_taken"},
    times_downed={"times_downed"},
    times_disabled={"times_disabled"},
    deaths={"deaths"},
    damage_dealt={"damage_dealt","actual_damage_dealt"},
    weakspot_hits={"weakspot_hits"},
    melee_kills={"melee_kills"},
    ranged_kills={"ranged_kills"},
    lesser_enemies={"lesser_enemies"},
    melee_ranged_threats={"melee_ranged_threats"},
    special_threats={"special_threats"},
    boss_damage_dealt={"boss_damage_dealt"},
    coherency_efficiency={"coherency_efficiency"},
    revived_operative={"revived_operative"},
    team_saves={"team_saves"},
    ammo_score={"ammo_collected"},
    weakspot_hit_percent={"weakspot_hit_percent"},
    critical_hits={"critical_hits"},
    accuracy={"accuracy"},
    damaging_hits={"damaging_hits"},
    ranged_shots_fired={"ranged_shots_fired"},
    heal_station_used={"heal_station_used"},
    operated={"operated"},
    resources_collected={"resources_collected"},
}

local function live_score(entry)
    if type(entry)=="number" then return entry end
    if type(entry)~="table" then return nil end
    return tonumber(entry.score or entry.value or entry.total)
end

-- Read Scores live data when the normalized collector is unavailable.
-- Required for complete Tactical metrics when the selected adapter is temporarily unavailable.
local function scores_live_match()
    local source=get_mod("scores")
    if not source then return nil end

    if not source.registered_scoreboard_rows or #source.registered_scoreboard_rows==0 then
        pcall(source.collect_scoreboard_rows,source)
    end

    local rows={}
    local account_ids={}
    for _,row in pairs(source.registered_scoreboard_rows or {}) do
        if row and row.name then
            rows[row.name]=row
            for account_id in pairs(row.data or {}) do
                account_ids[account_id]=true
            end
        end
    end

    local player_manager=(Managers and Managers.player) or source.player_manager
    local player_objects={}
    if player_manager and type(player_manager.players)=="function" then
        local ok,players=pcall(player_manager.players,player_manager)
        if ok then
            for _,player in pairs(players or {}) do
                local id
                if source.account_id_from_player then
                    local id_ok,value=pcall(source.account_id_from_player,source,player)
                    id=id_ok and value or nil
                end
                if id then
                    account_ids[id]=true
                    player_objects[id]=player
                end
            end
        end
    end

    local local_id
    if source.me then
        local ok,value=pcall(source.me,source)
        local_id=ok and value or nil
    end
    if not local_id and player_manager and type(player_manager.local_player)=="function" then
        local ok,player=pcall(player_manager.local_player,player_manager,1)
        if ok and player and source.account_id_from_player then
            local id_ok,value=pcall(source.account_id_from_player,source,player)
            local_id=id_ok and value or nil
        end
    end

    -- Scores can retain row data for players who have left and for old
    -- bot slots after replacements join. When the live player manager is
    -- available, treat its current roster as authoritative and ignore orphaned
    -- scoreboard row IDs. This prevents stale GUIDs, duplicate bots, and their
    -- old values from leaking into the tactical board.
    local has_live_roster=next(player_objects)~=nil

    local players={}
    for account_id in pairs(account_ids) do
        local is_current_player=not has_live_roster or player_objects[account_id]~=nil or account_id==local_id
        local metrics={}
        local has_metric=false
        for metric,row_names in pairs(live_metric_rows) do
            local value
            for _,row_name in ipairs(row_names) do
                local row=rows[row_name]
                value=row and live_score(row.data and row.data[account_id]) or nil
                if value~=nil then break end
            end
            metrics[metric]=value
            if value~=nil then has_metric=true end
        end
        if is_current_player and (has_metric or account_id==local_id) then
            local player=player_objects[account_id]
            local name=tostring(account_id)
            if player then
                local ok,value=pcall(function()
                    if type(player.name)=="function" then return player:name() end
                    return player.name
                end)
                if ok and value then name=tostring(value) end
            end
            players[#players+1]={
                account_id=account_id,
                name=name,
                is_local=account_id==local_id,
                metrics=metrics,
                shares={},
            }
        end
    end

    table.sort(players,function(a,b)
        if a.is_local~=b.is_local then return a.is_local end
        return tostring(a.name)<tostring(b.name)
    end)

    local totals={}
    for metric in pairs(live_metric_rows) do
        local total=0
        local available=false
        for _,player in ipairs(players) do
            local value=tonumber(player.metrics[metric])
            if value~=nil then
                total=total+value
                available=true
            end
        end
        totals[metric]=available and total or nil
    end

    for _,player in ipairs(players) do
        for metric in pairs(live_metric_rows) do
            local value=tonumber(player.metrics[metric])
            local total=tonumber(totals[metric])
            player.shares[metric]=value and total and total~=0 and value/total*100 or nil
        end
    end

    local duration
    if tonumber(source.timer) then
        duration=math.max(0,os.time()-tonumber(source.timer))
    end

    return {
        source="scores_direct",
        mission={
            name=source.mission_name,
            difficulty=source.mission_challenge,
            duration_seconds=duration,
        },
        players=players,
        team_totals=totals,
        local_account_id=local_id,
    }
end

-- Resolve the authoritative live match for the Tactical Overlay.
-- Uses the selected collector first and filters stale/disconnected roster entries.
local function current_live_match()
    -- Use the selected collector adapter first. The Scores adapter resolves
    -- summary rows through row_display_model; those rows do not necessarily keep
    -- their live values directly in row.data. This is required for Swarmers,
    -- Elites, Specials, and Boss damage to update during the mission.
    local collected=mod.collector_manager and mod.collector_manager:get_current_match() or nil
    if collected and local_player(collected) then
        if mod.damage_source_tracker then
            mod.damage_source_tracker:augment_match(collected)
        end
        return collected
    end

    -- Retain the older direct reader only as a defensive fallback if the selected
    -- adapter cannot produce a usable live match.
    local fallback=scores_live_match()
    if fallback and mod.damage_source_tracker then
        mod.damage_source_tracker:augment_match(fallback)
    end
    return fallback
end


local VictoryDefinitions = mod:io_dofile("improve-yourself/scripts/mods/improve-yourself/views/meta/improve_yourself_view_definitions")
local VictoryWidgets = VictoryDefinitions and VictoryDefinitions.widget_definitions or {}
local gold = {255,232,191,96}
local gold_highlight = {180,255,238,170}
local grey = {255,126,148,126}
local transparent = {0,0,0,0}

local function safe_number(value)
    value=tonumber(value)
    if value~=value or value==math.huge or value==-math.huge then return nil end
    return value
end

-- Extract Tactical metric values without assuming every row exists.
-- Protects live widgets from missing, invalid, or partially initialized values.
local function metric_data(match, player, metric)
    if not match or not player then return nil,nil,nil end
    local raw=safe_number(player.metrics and player.metrics[metric])
    local total=safe_number(match.team_totals and match.team_totals[metric])
    local share=safe_number(player.shares and player.shares[metric])
    if raw==nil or total==nil or total<=0 or share==nil then return raw,total,nil end
    return raw,total,math.max(0,share)
end

local function team_comparison_enabled()
    return mod:get("color_scheme") == "team_comparison"
end

local function rank_color(rank, rank_count)
    rank=tonumber(rank); rank_count=math.max(1,tonumber(rank_count) or 1)
    if not rank then return nil end
    local palette=rank_count<=1 and {gold} or (rank_count==2 and {gold,close} or (rank_count==3 and {gold,green,close} or {gold,green,close,close}))
    return palette[math.max(1,math.min(#palette,rank))]
end

local function player_rank(match,metric,player,direction)
    if not match or not player then return nil,0 end
    local values={}
    local mine=nil
    for _,candidate in ipairs(match.players or {}) do
        local raw,total=metric_data(match,candidate,metric)
        if total and total>0 and raw~=nil then
            values[raw]=true
            if candidate.account_id==player.account_id then mine=raw end
        end
    end
    local ordered={}; for value in pairs(values) do ordered[#ordered+1]=value end
    table.sort(ordered,function(a,b)
        if direction=="higher" then return a>b end
        return a<b
    end)
    for i,value in ipairs(ordered) do if value==mine then return i,#ordered end end
    return nil,#ordered
end

local function state_color(direction, share, goal, total, is_best, rank, rank_count)
    if team_comparison_enabled() and total and total>0 then return rank_color(rank,rank_count) or grey end
    if is_best and total and total>0 then return gold end
    if share==nil or total==nil then return grey end
    if total<=0 then return direction=="lower" and green or grey end
    local favorable=direction=="higher" and (share-goal) or (goal-share)
    return favorable>=0 and green or close
end

local function is_best_player(match, metric, player, direction)
    local mine=safe_number(player and player.metrics and player.metrics[metric])
    local total=safe_number(match and match.team_totals and match.team_totals[metric])
    if mine==nil or total==nil or total<=0 then return false end
    local best=nil
    for _,p in ipairs(match.players or {}) do
        local v=safe_number(p.metrics and p.metrics[metric])
        if v~=nil then best=best==nil and v or (direction=="lower" and math.min(best,v) or math.max(best,v)) end
    end
    return best~=nil and math.abs(mine-best)<0.001
end

-- Assign Tactical material or glyph icons.
-- Keep IDs synchronized with row_icon_N and row_glyph_N in shared Teamplay definitions.
local function set_icon(widget,prefix,index)
    if not widget or not widget.content then return end
    local icon=resolve_catalogue_icon(index) or {kind="none"}
    widget.content[prefix.."_icon"]=icon.kind=="material" and icon.value or "content/ui/materials/base/ui_default_base"
    widget.content[prefix.."_glyph"]=icon.kind=="unicode" and icon.value or ""
    widget.content[prefix.."_icon_visible"]=icon.kind=="material"
    widget.content[prefix.."_glyph_visible"]=icon.kind=="unicode"
end

local function raw_text(value)
    value=safe_number(value)
    if value==nil then return "—" end
    local rounded=math.floor(value+0.5)
    return tostring(rounded)
end

local function pct_text(share)
    share=safe_number(share)
    return share~=nil and string.format("%.1f%%",share) or "—"
end

local function single_line_player_name(value, max_characters)
    local name=tostring(value or "Unknown"):gsub("[%c]"," "):gsub("%s+"," ")
    max_characters=math.max(2,tonumber(max_characters) or 14)
    local offsets={}
    local byte_index=1
    while byte_index<=#name do
        offsets[#offsets+1]=byte_index
        local lead=string.byte(name,byte_index)
        local width=lead and (lead<0x80 and 1 or lead<0xE0 and 2 or lead<0xF0 and 3 or 4) or 1
        byte_index=byte_index+width
    end
    if #offsets<=max_characters then return name end
    return string.sub(name,1,offsets[max_characters]-1).."…"
end

local function damage_source_detail(value,segment_height,detail_width)
    local detail=tostring(value or ""):gsub("[%c]"," "):gsub("%s+"," ")
    if detail=="" then return "" end
    local line_limit=math.max(8,math.floor((tonumber(detail_width) or 79)/4.2))
    if (tonumber(segment_height) or 0)<34 then return single_line_player_name(detail,line_limit) end
    local parts={}
    for part in string.gmatch(detail,"[^,]+") do
        part=part:gsub("^%s+",""):gsub("%s+$","")
        if part~="" then parts[#parts+1]=part end
    end
    if #parts<2 then return single_line_player_name(detail,line_limit) end
    local first_line=parts[1]
    local next_part=2
    while next_part<=#parts do
        local candidate=first_line..", "..parts[next_part]
        if #candidate>line_limit then break end
        first_line=candidate
        next_part=next_part+1
    end
    if next_part>#parts then return single_line_player_name(first_line,line_limit) end
    local second_parts={}
    for i=next_part,#parts do second_parts[#second_parts+1]=parts[i] end
    return single_line_player_name(first_line,line_limit).."\n"..single_line_player_name(table.concat(second_parts,", "),line_limit)
end

local function summary_for(match, section)
    local me=local_player(match)
    local met,total=0,0
    for _,metric in ipairs(active_metrics(section)) do
        local _,team_total,share=metric_data(match,me,metric)
        if team_total~=nil then
            if team_total<=0 and section.direction=="lower" then
                met=met+1; total=total+1
            elseif share~=nil then
                total=total+1
                local goal=target(metric)
                local favorable=section.direction=="higher" and share-goal or goal-share
                if favorable>=0 then met=met+1 end
            end
        end
    end
    local praise=total>0 and met==total and "OUTSTANDING!" or (total>0 and met>=total-1 and "IMPRESSIVE!" or "")
    return praise,(total>0 and string.format("%d/%d goals",met,total) or "—")
end

-- Reused every Tactical frame; keep this outside populate_offense so dynamic
-- centering does not allocate a fresh lookup table during live play.
local offense_pie_base_x={
    damage_total_icon=154,damage_total_glyph=154,damage_total_title=178,
    damage_total_pct_shadow_1=161,damage_total_pct_shadow_2=163,
    damage_total_pct_shadow_3=161,damage_total_pct_shadow_4=163,damage_total_pct=162,
    damage_total_raw_shadow_1=145,damage_total_raw_shadow_2=147,
    damage_total_raw_shadow_3=145,damage_total_raw_shadow_4=147,damage_total_raw=146,
    damage_pie_outer_glow=146,damage_pie_outer_rim=148,damage_pie_background=149,
}

-- Populate the production Tactical Defense widget.
-- Includes low-allocation Best/Own/Worst counter geometry and invalid-percentage safeguards.
-- Do not alter style IDs or center coordinates without checking shared Victory widget definitions.
local function populate_defense(widget,match)
    if not widget or not widget.style or not widget.content then return end
    local me=local_player(match)
    local players={}
    local teammate_slot=1
    for _,p in ipairs(match and match.players or {}) do
        if p~=me and teammate_slot<=3 then
            players[teammate_slot]=p
            teammate_slot=teammate_slot+1
        end
    end
    -- Slot 4 is reserved for the local player even in solo play. Do not append
    -- via #players: sparse/short rosters must not move the local bar left.
    players[4]=me
    local praise,score=summary_for(match,categories.defense)
    widget.content.defense_praise=praise; widget.content.defense_score=score
    set_icon(widget,"damage",metric_icon_indices.damage_taken)
    local counter_metrics={}
    for _,metric in ipairs({"times_downed","times_disabled","deaths"}) do
        if mod:is_metric_enabled(metric) then counter_metrics[#counter_metrics+1]=metric end
    end
    local counter_x,counter_w,counter_gap=617,108,7
    local counters_w=#counter_metrics>0 and (#counter_metrics*counter_w+(#counter_metrics-1)*counter_gap) or 0
    local first_counter_x
    local mandatory_shift=0
    if #counter_metrics<3 then
        local content_left,content_right=125,970
        local mandatory_left,mandatory_w=116,499
        local complete_w=mandatory_w+(#counter_metrics>0 and (10+counters_w) or 0)
        local complete_x=content_left+(content_right-content_left-complete_w)/2
        mandatory_shift=complete_x-mandatory_left
        first_counter_x=complete_x+mandatory_w+10
    else
        local region_w=970-counter_x
        first_counter_x=counter_x+(region_w-counters_w)/2
    end
    local chart_x,chart_y,chart_w,chart_h,cap=154+mandatory_shift,62,320,82,50
    local bar_w,bar_gap=42,34
    local bars_w=bar_w*4+bar_gap*3
    local first_bar_x=chart_x+(chart_w-bars_w)/2
    local source_x,source_w=494+mandatory_shift,38
    local source_detail_x=source_x+source_w+4
    local source_detail_right=#counter_metrics>0 and first_counter_x-4 or 960
    local source_detail_w=math.max(79,math.floor(source_detail_right-source_detail_x))
    local source_y,source_h=30,chart_y+chart_h-30
    local goal=target("damage_taken")
    local goal_h=math.min(cap,math.max(0,goal))/cap*chart_h
    widget.style.damage_icon.offset[1]=chart_x
    widget.style.damage_glyph.offset[1]=chart_x
    widget.style.damage_title.offset[1]=chart_x+24
    for _,id in ipairs({"grid_50","grid_25","grid_0"}) do widget.style[id].offset[1]=chart_x end
    widget.style.grid_50_text.offset[1]=chart_x-38
    widget.style.grid_25_text.offset[1]=chart_x-38
    for i=1,4 do
        local p=players[i]
        local raw,total,share=metric_data(match,p,"damage_taken")
        local local_flag=p and p.is_local
        local best=p and is_best_player(match,"damage_taken",p,"lower") or false
        local color=local_flag and state_color("lower",share,goal,total,best,player_rank(match,"damage_taken",p,"lower")) or grey
        local h=share and math.min(cap,share)/cap*chart_h or 0
        local bx=first_bar_x+(i-1)*(bar_w+bar_gap); local cx=bx+bar_w/2
        local result_y=chart_y+chart_h-h; local goal_y=chart_y+chart_h-goal_h
        local show_goal=local_flag and share~=nil and h<=goal_h
        for _,id in ipairs({"goal_stripes_","goal_l_","goal_r_","goal_t_"}) do
            local s=widget.style[id..i]; if s then s.color=best and gold or grey end
        end
        local s=widget.style["goal_stripes_"..i]; if s then s.offset={bx,goal_y,7}; s.size={0,0}; s.color={0,0,0,0} end
        s=widget.style["goal_l_"..i]; if s then s.offset={bx,goal_y,8}; s.size={show_goal and 1 or 0,show_goal and goal_h or 0} end
        s=widget.style["goal_r_"..i]; if s then s.offset={bx+bar_w-1,goal_y,8}; s.size={show_goal and 1 or 0,show_goal and goal_h or 0} end
        s=widget.style["goal_t_"..i]; if s then s.offset={bx,goal_y,8}; s.size={show_goal and bar_w or 0,show_goal and 1 or 0} end
        s=widget.style["result_"..i]; if s then s.offset={bx+1,result_y,9}; s.size={bar_w-2,h}; s.color=color end
        s=widget.style["result_highlight_"..i]; if s then s.offset={bx+1,result_y,10}; s.size={bar_w-2,h>0 and 2 or 0} end
        local overflow=share and share>cap
        s=widget.style["overflow_"..i]; if s then s.offset={bx+1,chart_y-11,11}; s.size={bar_w-2,overflow and 8 or 0}; s.color=color end
        widget.content["raw_"..i]=(total and total>0) and raw_text(raw) or "--"
        widget.content["name_"..i]=p and single_line_player_name(p.name,11) or "—"
        widget.content["pct_"..i]=(total and total>0) and pct_text(share) or "--"
        for _,id in ipairs({"raw_","name_","pct_"}) do local st=widget.style[id..i]; if st then st.text_color=color end end
        local st=widget.style["raw_"..i]; if st then st.offset={cx-42,overflow and chart_y-31 or math.max(chart_y-27,result_y-20),12} end
        widget.style["name_"..i].offset[1]=cx-36
        widget.style["pct_"..i].offset[1]=cx-34
    end

    local source_order={"area","melee","ranged","other"}
    local sources=me and me.damage_taken_sources
    local has_source_data=match and match.damage_taken_sources_available==true and type(sources)=="table"
    local source_values={}
    local source_total=0
    if has_source_data then
        for _,category in ipairs(source_order) do
            local value=math.max(0,safe_number(sources[category]) or 0)
            source_values[category]=value
            source_total=source_total+value
        end
    end
    local show_source_breakdown=has_source_data and source_total>0
    local source_layout=damage_source_layout(source_values,source_order,source_h,23)
    widget.content.source_area_label="Area of Effect"
    widget.content.source_melee_label="Melee Damage"
    widget.content.source_ranged_label="Ranged Damage"
    widget.content.source_other_label="Other Damage"
    local source_details=me and me.damage_taken_source_labels or {}
    for _,category in ipairs(source_order) do
        widget.content["source_"..category.."_detail"]=""
    end
    local running_bottom=chart_y+chart_h
    for _,category in ipairs(source_order) do
        local segment=widget.style["source_"..category]
        if segment then segment.offset={source_x,chart_y+chart_h,10}; segment.size={0,0} end
        widget.content["source_"..category.."_value"]=""
        local value_style=widget.style["source_"..category.."_value"]
        local label_style=widget.style["source_"..category.."_label"]
        if value_style then value_style.text_color=transparent end
        if label_style then label_style.text_color=transparent end
        local detail_style=widget.style["source_"..category.."_detail"]
        if detail_style then detail_style.text_color=transparent end
    end
    local source_alpha_by_rank={255,205,155,105}
    for rank,item in ipairs(source_layout) do
        running_bottom=running_bottom-item.height
        local category=item.category
        local segment=widget.style["source_"..category]
        if segment then
            segment.offset={source_x,running_bottom,10}
            segment.size={source_w,item.height}
            segment.color={source_alpha_by_rank[rank] or 105,177,189,181}
        end
        widget.content["source_"..category.."_value"]=raw_text(item.value)
        local value_y=running_bottom+item.height/2-7
        local allow_two_lines=item.height>=34
        local label_y=running_bottom+item.height/2-(allow_two_lines and 16 or 10)
        local value_style=widget.style["source_"..category.."_value"]
        local label_style=widget.style["source_"..category.."_label"]
        local detail_style=widget.style["source_"..category.."_detail"]
        local source_alpha=source_alpha_by_rank[rank] or 105
        local label_color=Color.terminal_text_body(source_alpha,true)
        if value_style then value_style.offset={source_x,value_y,14}; value_style.text_color={255,28,36,31} end
        if label_style then
            label_style.offset={source_detail_x,label_y,14}
            label_style.size={source_detail_w,11}
            label_style.text_color=label_color
        end
        if detail_style then
            detail_style.offset={source_detail_x,label_y+11,14}
            detail_style.size={source_detail_w,allow_two_lines and 20 or 9}
            detail_style.text_color=label_color
        end
        widget.content["source_"..category.."_detail"]=damage_source_detail(source_details[category],item.height,source_detail_w)
    end
    local local_bar_x=first_bar_x+3*(bar_w+bar_gap)
    local connector_start_x=local_bar_x+bar_w
    local bracket_x=source_x-7
    local connector_y=chart_y+chart_h-goal_h/2-1
    local connector_w=math.max(0,bracket_x-connector_start_x)
    local connector=widget.style.source_connector
    local bracket_top=widget.style.source_bracket_top
    local bracket_right=widget.style.source_bracket_right
    local bracket_bottom=widget.style.source_bracket_bottom
    if connector then connector.offset={connector_start_x,connector_y,12}; connector.size={show_source_breakdown and connector_w or 0,2} end
    if bracket_top then bracket_top.offset={bracket_x,source_y,12}; bracket_top.size={show_source_breakdown and 5 or 0,2} end
    if bracket_right then bracket_right.offset={bracket_x,source_y,12}; bracket_right.size={2,show_source_breakdown and source_h or 0} end
    if bracket_bottom then bracket_bottom.offset={bracket_x,chart_y+chart_h-2,12}; bracket_bottom.size={show_source_breakdown and 5 or 0,2} end
    local blocked_enabled=mod:is_metric_enabled("attacks_blocked")
    local blocked=blocked_enabled and me and me.metrics and safe_number(me.metrics.attacks_blocked)
    widget.content.source_summary=show_source_breakdown and blocked_enabled and (blocked and blocked>0 and raw_text(blocked) or "--") or ""
    local blocked_best=blocked~=nil and is_best_player(match,"attacks_blocked",me,"higher")
    local blocked_color=blocked~=nil and (blocked_best and gold or green) or grey
    widget.style.source_summary_title.offset[1]=source_x-2
    widget.style.source_summary.offset[1]=source_x-2
    if widget.style.source_summary_title then widget.style.source_summary_title.text_color=show_source_breakdown and blocked_enabled and blocked_color or transparent end
    if widget.style.source_summary then widget.style.source_summary.text_color=show_source_breakdown and blocked_enabled and blocked_color or transparent end

    -- Counter geometry must match the shared Victory/History widget definition.
    -- Update existing offset/size arrays in place: assigning new tables here every
    -- frame creates avoidable Lua garbage while the tactical overlay is open.
    local comparison_bar_w, own_bar_w, mini_gap = 10, 38, 4
    local chart_y, chart_h, base_y = 62, 82, 144
    local group_w = comparison_bar_w * 2 + own_bar_w + mini_gap * 2
    for i=1,3 do
        local metric=counter_metrics[i]
        if metric then
        set_icon(widget,"counter_"..i,metric_icon_indices[metric])
        widget.content["counter_title_"..i]=metric=="times_downed" and "Downed" or (metric=="times_disabled" and "Disabled" or "Deaths")
        local raw,total,share=metric_data(match,me,metric)
        local best=is_best_player(match,metric,me,"lower")
        local goal=target(metric)
        local color=state_color("lower",share,goal,total,best,player_rank(match,metric,me,"lower"))

        -- Find the comparison range without building and sorting a temporary table.
        local best_raw, worst_raw
        for _,p in ipairs(match and match.players or {}) do
            local v=safe_number(p.metrics and p.metrics[metric])
            if v~=nil then
                best_raw = best_raw==nil and v or math.min(best_raw,v)
                worst_raw = worst_raw==nil and v or math.max(worst_raw,v)
            end
        end

        local has_local_data=share~=nil
        local own=raw or 0
        local best_value=best_raw or 0
        local worst_value=worst_raw or 0
        local maxv=math.max(4,worst_value,own)
        local has_events=has_local_data and total and total>0
        local best_h=has_events and math.max(3,best_value/maxv*chart_h) or 0
        local own_h=has_events and math.max(3,own/maxv*chart_h) or 0
        local worst_h=has_events and math.max(3,worst_value/maxv*chart_h) or 0

        local x=first_counter_x+(i-1)*(counter_w+counter_gap)
        local group_x=x+(counter_w-group_w)/2
        local best_x=group_x
        local own_x=best_x+comparison_bar_w+mini_gap
        local worst_x=own_x+own_bar_w+mini_gap
        local own_center_x=own_x+own_bar_w/2
        local title_w=metric=="times_disabled" and 64 or (metric=="times_downed" and 58 or 50)
        local heading_x=own_center_x-(17+5+title_w)/2
        widget.style["counter_icon_"..i].offset[1]=heading_x
        widget.style["counter_glyph_"..i].offset[1]=heading_x
        widget.style["counter_title_"..i].offset[1]=heading_x+22
        widget.style["counter_title_"..i].offset[2]=6
        widget.style["counter_title_"..i].size[1]=title_w
        widget.style["counter_best_label_"..i].offset[1]=best_x-12
        widget.style["counter_worst_label_"..i].offset[1]=worst_x-14
        widget.style["counter_best_label_"..i].text_color={190,126,148,126}
        widget.style["counter_worst_label_"..i].text_color={190,126,148,126}
        widget.style["counter_baseline_"..i].offset={group_x-3,base_y,5}
        widget.style["counter_baseline_"..i].size={group_w+6,1}
        widget.style["counter_pct_"..i].offset[1]=x

        local function set_geometry(style,x_pos,y_pos,width,height,z)
            if not style then return end
            local offset=style.offset
            local size=style.size
            offset[1]=x_pos; offset[2]=y_pos; if z then offset[3]=z end
            size[1]=width; size[2]=height
        end

        local best_bar=widget.style["counter_best_bar_"..i]
        local own_bar=widget.style["counter_own_bar_"..i]
        local worst_bar=widget.style["counter_worst_bar_"..i]
        set_geometry(best_bar,best_x,base_y-best_h,comparison_bar_w,best_h,7)
        set_geometry(own_bar,own_x+1,base_y-own_h,own_bar_w-2,own_h,9)
        set_geometry(worst_bar,worst_x,base_y-worst_h,comparison_bar_w,worst_h,7)
        if best_bar then best_bar.color=grey end
        if own_bar then own_bar.color=color end
        if worst_bar then worst_bar.color=grey end

        local highlight=widget.style["counter_own_highlight_"..i]
        set_geometry(highlight,own_x+1,base_y-own_h,own_bar_w-2,own_h>0 and 2 or 0,10)
        if highlight then highlight.color=best and gold_highlight or {150,235,245,235} end

        local goal_h=math.min(50,math.max(0,goal))/50*chart_h
        local goal_y=base_y-goal_h
        local show_goal=has_local_data and own_h<=goal_h
        local frame_color=best and gold or grey
        local stripes=widget.style["counter_goal_stripes_"..i]
        local goal_l=widget.style["counter_goal_l_"..i]
        local goal_r=widget.style["counter_goal_r_"..i]
        local goal_t=widget.style["counter_goal_t_"..i]
        set_geometry(stripes,own_x,goal_y,show_goal and own_bar_w or 0,show_goal and goal_h or 0,8)
        set_geometry(goal_l,own_x,goal_y,show_goal and 1 or 0,show_goal and goal_h or 0,11)
        set_geometry(goal_r,own_x+own_bar_w-1,goal_y,show_goal and 1 or 0,show_goal and goal_h or 0,11)
        set_geometry(goal_t,own_x,goal_y,show_goal and own_bar_w or 0,show_goal and 1 or 0,11)
        if stripes then stripes.color=best and {120,gold[2],gold[3],gold[4]} or {95,90,112,92} end
        if goal_l then goal_l.color=frame_color end
        if goal_r then goal_r.color=frame_color end
        if goal_t then goal_t.color=frame_color end

        widget.content["counter_best_raw_"..i]=has_events and raw_text(best_value) or ""
        widget.content["counter_own_raw_"..i]=has_events and raw_text(raw) or "--"
        widget.content["counter_worst_raw_"..i]=has_events and raw_text(worst_value) or ""
        widget.content["counter_pct_"..i]=has_events and pct_text(share) or "--"

        -- Dynamic counter compaction moves the bars horizontally, so keep each
        -- raw-value text box centered over its current bar as well. Update the
        -- existing offset arrays in place to avoid per-frame Lua allocations.
        local best_raw_style=widget.style["counter_best_raw_"..i]
        local own_raw_style=widget.style["counter_own_raw_"..i]
        local worst_raw_style=widget.style["counter_worst_raw_"..i]
        if best_raw_style then best_raw_style.offset[1]=best_x-6; best_raw_style.offset[2]=math.max(chart_y-16,base_y-best_h-15) end
        local own_top=show_goal and math.min(base_y-own_h,goal_y) or base_y-own_h
        if own_raw_style then own_raw_style.offset[1]=own_x-6; own_raw_style.offset[2]=math.max(chart_y-16,own_top-15); own_raw_style.text_color=color end
        if worst_raw_style then worst_raw_style.offset[1]=worst_x-6; worst_raw_style.offset[2]=math.max(chart_y-16,base_y-worst_h-15) end

        local pct_style=widget.style["counter_pct_"..i]
        local title_style=widget.style["counter_title_"..i]
        if pct_style then pct_style.text_color=color end
        if title_style then title_style.text_color=color end
        local icon_style=widget.style["counter_icon_"..i]
        local glyph_style=widget.style["counter_glyph_"..i]
        if icon_style then icon_style.color=color end
        if glyph_style then glyph_style.text_color=color end
        else
            widget.content["counter_"..i.."_icon_visible"]=false
            widget.content["counter_"..i.."_glyph_visible"]=false
            widget.content["counter_title_"..i]=""
            widget.content["counter_best_raw_"..i]=""
            widget.content["counter_own_raw_"..i]=""
            widget.content["counter_worst_raw_"..i]=""
            widget.content["counter_pct_"..i]=""
            widget.style["counter_title_"..i].text_color=transparent
            widget.style["counter_best_label_"..i].text_color=transparent
            widget.style["counter_worst_label_"..i].text_color=transparent
            widget.style["counter_baseline_"..i].size={0,0}
            for _,id in ipairs({"counter_best_bar_","counter_own_bar_","counter_own_highlight_","counter_worst_bar_","counter_goal_stripes_","counter_goal_l_","counter_goal_r_","counter_goal_t_"}) do widget.style[id..i].size={0,0} end
        end
    end
end

-- Populate the production Tactical Offense widget.
-- Uses Scores summary-row support for Swarmers, Elites, Specials, and Boss.
local function populate_offense(widget,match)
    if not widget or not widget.style or not widget.content then return end
    local me=local_player(match); local praise,score=summary_for(match,categories.offense)
    widget.content.offense_praise=praise; widget.content.offense_score=score
    set_icon(widget,"damage_total",metric_icon_indices.damage_dealt)
    local quality_specs={
        {metric="weakspot_hit_percent",denominator="damaging_hits",title="Weakspot hit %"},
        {metric="critical_hits",denominator="damaging_hits",title="Critical hits %"},
        {metric="accuracy",denominator="ranged_shots_fired",title="Ranged accuracy"},
    }
    local quality={}
    for _,spec in ipairs(quality_specs) do if mod:is_metric_enabled(spec.metric) then quality[#quality+1]=spec end end
    local quality_visible=#quality>0
    local list={}
    for _,metric in ipairs(active_metrics(categories.offense)) do if metric~="damage_dealt" then list[#list+1]=metric end end
    local slot_w,bar_w=55,36
    local graph_w=#list*slot_w
    local content_left=125
    local content_right=quality_visible and 715 or 970
    local pie_w,pie_gap=146,35
    local complete_w=pie_w+(#list>0 and (pie_gap+graph_w) or 0)
    local complete_x=content_left+math.max(0,(content_right-content_left-complete_w)/2)
    local pie_shift=complete_x-149
    local offense_w=quality_visible and 735 or 970
    widget.style.background.size[1]=offense_w
    widget.style.bottom_divider.size[1]=offense_w
    for id,x in pairs(offense_pie_base_x) do widget.style[id].offset[1]=x+pie_shift end
    local raw,total,share=metric_data(match,me,"damage_dealt")
    local best=is_best_player(match,"damage_dealt",me,"higher"); local color=state_color("higher",share,target("damage_dealt"),total,best,player_rank(match,"damage_dealt",me,"higher"))
    widget.content.damage_total_pct=(total and total>0) and pct_text(share) or "--"; widget.content.damage_total_raw=(total and total>0) and raw_text(raw) or "--"
    for _,id in ipairs({"damage_total_pct","damage_total_raw","damage_total_title"}) do local st=widget.style[id]; if st then st.text_color=color end end
    for _,id in ipairs({"damage_total_icon","damage_total_glyph"}) do local st=widget.style[id]; if st then if st.color then st.color=color else st.text_color=color end end end

    -- The shared Offense widget now uses the same native triangle-fan pie as
    -- Victory and History. Build its four live slices from Tactical's current
    -- Scores match instead of writing to the removed legacy arc styles.
    local pie_segments_per_player=32
    local pie_size=146
    local pie_radius=pie_size/2
    local pie_slice_radius=pie_radius-2.5
    local pie_center=pie_radius
    local local_pie_player
    local teammate_pie_players={}

    for _,player in ipairs(match and match.players or {}) do
        local value=safe_number(player.metrics and player.metrics.damage_dealt) or 0
        local item={value=math.max(0,value),is_local=player==me or player.is_local==true,name=player.name}
        if item.is_local then
            local_pie_player=item
        else
            teammate_pie_players[#teammate_pie_players+1]=item
        end
    end

    table.sort(teammate_pie_players,function(a,b)
        if a.value~=b.value then return a.value<b.value end
        return tostring(a.name or "")<tostring(b.name or "")
    end)

    local pie_players={}
    if local_pie_player then pie_players[#pie_players+1]=local_pie_player end
    for _,teammate in ipairs(teammate_pie_players) do
        if #pie_players>=4 then break end
        pie_players[#pie_players+1]=teammate
    end

    local pie_total=safe_number(total) or 0
    if pie_total<=0 then
        for _,player in ipairs(pie_players) do pie_total=pie_total+player.value end
    end

    local teammate_colours={{110,44,58,55},{100,38,50,47},{90,32,42,40}}
    local teammate_index=1
    local local_fraction=pie_players[1] and pie_players[1].is_local and pie_total>0 and pie_players[1].value/pie_total or 0
    local start_angle=-math.pi*3/4-local_fraction*math.pi

    for player_index=1,4 do
        local pie_player=pie_players[player_index]
        local fraction=pie_player and pie_total>0 and pie_player.value/pie_total or 0
        local end_angle=start_angle+fraction*math.pi*2
        local slice_colour

        if pie_player and pie_player.is_local then
            slice_colour=color
        else
            slice_colour=teammate_colours[teammate_index] or close
            if pie_player then teammate_index=teammate_index+1 end
        end

        for segment_index=1,pie_segments_per_player do
            local style=widget.style["damage_pie_"..player_index.."_"..segment_index]
            if style then
                style.offset[1]=149+pie_shift
                local corners=style.triangle_corners
                if fraction>0 then
                    local t0=(segment_index-1)/pie_segments_per_player
                    local t1=segment_index/pie_segments_per_player
                    local angle0=start_angle+(end_angle-start_angle)*t0
                    local angle1=start_angle+(end_angle-start_angle)*t1
                    corners[1][1],corners[1][2]=pie_center,pie_center
                    corners[2][1]=pie_center+math.cos(angle0)*pie_slice_radius
                    corners[2][2]=pie_center+math.sin(angle0)*pie_slice_radius
                    corners[3][1]=pie_center+math.cos(angle1)*pie_slice_radius
                    corners[3][2]=pie_center+math.sin(angle1)*pie_slice_radius
                    style.color[1],style.color[2],style.color[3],style.color[4]=slice_colour[1],slice_colour[2],slice_colour[3],slice_colour[4]
                else
                    corners[1][1],corners[1][2]=pie_center,pie_center
                    corners[2][1],corners[2][2]=pie_center,pie_center
                    corners[3][1],corners[3][2]=pie_center,pie_center
                    style.color[1]=0
                end
            end
        end

        local name_id="damage_pie_name_"..player_index
        local name_style=widget.style[name_id]
        if name_style then
            if pie_player and pie_player.value>0 then
                local mid_angle=start_angle+(end_angle-start_angle)*0.5
                local label_w,label_h=60,15
                local label_radius=pie_radius-22
                local px=pie_center+math.cos(mid_angle)*label_radius
                local py=pie_center+math.sin(mid_angle)*label_radius
                if math.sin(mid_angle)<-0.55 then py=py-1 elseif math.sin(mid_angle)>0.55 then py=py+1 end
                name_style.offset[1],name_style.offset[2],name_style.offset[3]=149+pie_shift+px-label_w/2,41+py-label_h/2,28
                name_style.text_color[1],name_style.text_color[2],name_style.text_color[3],name_style.text_color[4]=160,92,108,95
                widget.content[name_id]=pie_player.is_local and "" or tostring(pie_player.name or "—")
            else
                name_style.offset[1],name_style.offset[2],name_style.offset[3]=149+pie_shift,41,28
                name_style.text_color[1]=0
                widget.content[name_id]=""
            end
        end

        start_angle=end_angle
    end
    widget.style.quality_background.size={quality_visible and 225 or 0,quality_visible and 200 or 0}
    widget.style.quality_header_background.size={quality_visible and 225 or 0,quality_visible and 22 or 0}
    widget.style.quality_bottom_divider.size={quality_visible and 225 or 0,quality_visible and 2 or 0}
    widget.style.quality_heading.text_color=quality_visible and Color.white(255,true) or transparent

    local chart_y,chart_h,cap=62,82,50
    local chart_x=complete_x+pie_w+(#list>0 and pie_gap or 0)
    local kill_graph_visible=#list>0
    for _,id in ipairs({"grid_50","grid_25","grid_0"}) do widget.style[id].offset[1]=chart_x; widget.style[id].size[1]=kill_graph_visible and graph_w or 0 end
    widget.style.grid_50.color=kill_graph_visible and {150,110,130,118} or {0,110,130,118}
    widget.style.grid_25.color=kill_graph_visible and {150,110,130,118} or {0,110,130,118}
    widget.style.grid_0.color=kill_graph_visible and {200,82,112,92} or {0,82,112,92}
    widget.style.grid_50_text.offset[1]=chart_x-36; widget.style.grid_25_text.offset[1]=chart_x-36
    widget.style.grid_50_text.text_color=kill_graph_visible and {180,126,148,126} or {0,126,148,126}
    widget.style.grid_25_text.text_color=kill_graph_visible and {180,126,148,126} or {0,126,148,126}
    local labels={weakspot_hits="Weakspot",melee_kills="Melee",ranged_kills="Ranged",lesser_enemies="Swarmers",melee_ranged_threats="Elites",special_threats="Specials",boss_damage_dealt="Boss"}
    for i=1,7 do
        local metric=list[i]
        if metric then
        set_icon(widget,"metric_"..i,metric_icon_indices[metric])
        widget.content["name_"..i]=labels[metric] or metric
        local r,t,s=metric_data(match,me,metric); local b=is_best_player(match,metric,me,"higher"); local c=state_color("higher",s,target(metric),t,b,player_rank(match,metric,me,"higher"))
        local has_events=t and t>0
        local h=has_events and s and math.min(cap,s)/cap*chart_h or 0; local gh=math.min(cap,target(metric))/cap*chart_h
        local cx=chart_x+slot_w*(i-0.5); local bx=cx-bar_w/2; local base=chart_y+chart_h; local ry=base-h; local gy=base-gh; local show=s~=nil and h<=gh
        local st=widget.style["goal_stripes_"..i]; if st then st.offset={bx,gy,7}; st.size={0,0}; st.color={0,0,0,0} end
        for _,spec in ipairs({{"goal_l_",bx,1,gh},{"goal_r_",bx+bar_w-1,1,gh},{"goal_t_",bx,bar_w,1}}) do local x=widget.style[spec[1]..i]; if x then x.offset={spec[2],gy,8}; x.size={show and spec[3] or 0,show and spec[4] or 0}; x.color=b and gold or grey end end
        st=widget.style["result_"..i]; if st then st.offset={bx+1,ry,9}; st.size={bar_w-2,h}; st.color=c end
        st=widget.style["result_highlight_"..i]; if st then st.offset={bx+1,ry,10}; st.size={bar_w-2,h>0 and 2 or 0}; st.color=b and gold_highlight or {150,235,245,235} end
        local overflow=s and s>cap; st=widget.style["overflow_"..i]; if st then st.offset={bx+1,chart_y-11,11}; st.size={bar_w-2,overflow and 8 or 0}; st.color=c end
        widget.content["raw_"..i]=has_events and raw_text(r) or "--"; widget.content["pct_"..i]=has_events and pct_text(s) or "--"
        for _,id in ipairs({"raw_","pct_","name_"}) do local x=widget.style[id..i]; if x then x.text_color=c end end
        for _,id in ipairs({"metric_icon_","metric_glyph_"}) do local x=widget.style[id..i]; if x then if x.color then x.color=c else x.text_color=c end end end
        st=widget.style["raw_"..i]; if st then st.offset={cx-38,overflow and chart_y-31 or math.max(chart_y-27,ry-20),12} end
        widget.style["metric_icon_"..i].offset={cx-9,8,20}; widget.style["metric_glyph_"..i].offset={cx-9,6,20}
        widget.style["name_"..i].offset={cx-slot_w/2,chart_y+chart_h+5,12}; widget.style["pct_"..i].offset={cx-slot_w/2,chart_y+chart_h+24,12}
        else
            widget.content["metric_"..i.."_icon_visible"]=false; widget.content["metric_"..i.."_glyph_visible"]=false
            widget.content["name_"..i]=""; widget.content["raw_"..i]=""; widget.content["pct_"..i]=""
            for _,id in ipairs({"goal_stripes_","goal_l_","goal_r_","goal_t_","result_","result_highlight_","overflow_"}) do widget.style[id..i].size={0,0} end
        end
    end

    local quality_bar_w=91
    local quality_layouts={
        [1]={{top=22,height=176,y=92.5}},
        [2]={{top=22,height=88,y=48.5},{top=110,height=88,y=136.5}},
        [3]={{top=22,height=59,y=29},{top=81,height=58,y=88},{top=139,height=59,y=146}},
    }
    local quality_layout=quality_layouts[#quality] or {}
    widget.style.quality_critical_background.size={0,0}
    for i=1,3 do
        local spec=quality[i]
        if spec then
        local layout=quality_layout[i]
        local section_top,section_height,y=layout.top,layout.height,layout.y
        widget.content["quality_title_"..i]=spec.title
        widget.style["quality_title_"..i].offset[2]=y-7
        widget.style["quality_best_label_"..i].offset[2]=y+8; widget.style["quality_best_label_"..i].text_color={180,126,148,126}
        widget.style["quality_worst_label_"..i].offset[2]=y+35; widget.style["quality_worst_label_"..i].text_color={180,126,148,126}
        widget.style["quality_zero_line_"..i].offset[2]=y+8; widget.style["quality_zero_line_"..i].size={1,36}
        local geometry={best={y+11,3},own={y+21,11},worst={y+39,3}}
        for name,g in pairs(geometry) do
            widget.style["quality_"..name.."_bar_"..i].offset[2]=g[1]; widget.style["quality_"..name.."_bar_"..i].size[2]=g[2]
            widget.style["quality_"..name.."_value_"..i].offset[2]=g[1]+g[2]/2-6.5
        end
        if spec.metric=="critical_hits" then widget.style.quality_critical_background.offset[2]=section_top; widget.style.quality_critical_background.size={225,section_height} end
        local valid={}
        for _,player in ipairs(match and match.players or {}) do
            local denominator=safe_number(player.metrics and player.metrics[spec.denominator])
            local value=safe_number(player.metrics and player.metrics[spec.metric])
            if denominator and denominator>0 and value~=nil then valid[#valid+1]={player=player,value=value} end
        end
        table.sort(valid,function(a,b) return a.value>b.value end)
        local best=valid[1] and valid[1].value or nil
        local worst=valid[#valid] and valid[#valid].value or nil
        local own,own_rank,previous=nil,nil,nil
        local rank=0
        for _,item in ipairs(valid) do
            if previous==nil or math.abs(item.value-previous)>0.0001 then rank=rank+1; previous=item.value end
            if item.player==me or item.player.is_local==true then own=item.value; own_rank=rank end
        end
        local own_color=own_rank==1 and gold or (own_rank==2 and green or close)
        local scale=best and best>0 and best or 1
        local values={best=best,own=own,worst=worst}
        for _,name in ipairs({"best","own","worst"}) do
            local value=values[name]
            local bar=widget.style["quality_"..name.."_bar_"..i]
            if bar then bar.size[1]=value~=nil and math.max(0,math.min(quality_bar_w,value/scale*quality_bar_w)) or 0; bar.color=name=="own" and own_color or grey end
            widget.content["quality_"..name.."_value_"..i]=value~=nil and value>0 and string.format("%.1f%%",value) or "--"
            local value_style=widget.style["quality_"..name.."_value_"..i]
            if value_style then
                value_style.offset[1]=(bar and bar.offset[1] or 0)+(bar and bar.size[1] or 0)+5
                value_style.text_color=name=="own" and own_color or grey
            end
        end
        local own_bar=widget.style["quality_own_bar_"..i]
        local own_highlight=widget.style["quality_own_highlight_"..i]
        if own_bar and own_highlight then
            local own_width=own_bar.size[1] or 0
            local highlight_width=own_width>0 and math.min(2,own_width) or 0
            own_highlight.offset={own_bar.offset[1]+math.max(0,own_width-highlight_width),own_bar.offset[2]+1,9}
            own_highlight.size={highlight_width,own_width>0 and math.max(0,own_bar.size[2]-2) or 0}
            own_highlight.color=own_rank==1 and gold_highlight or {150,235,245,235}
        end
        local title_style=widget.style["quality_title_"..i]
        if title_style then title_style.text_color=own_color end
        else
            widget.content["quality_title_"..i]=""; widget.content["quality_best_value_"..i]=""; widget.content["quality_own_value_"..i]=""; widget.content["quality_worst_value_"..i]=""
            widget.style["quality_title_"..i].text_color=transparent; widget.style["quality_best_label_"..i].text_color=transparent; widget.style["quality_worst_label_"..i].text_color=transparent
            widget.style["quality_zero_line_"..i].size={0,0}
            for _,name in ipairs({"best","own","worst"}) do widget.style["quality_"..name.."_bar_"..i].size={0,0} end
            widget.style["quality_own_highlight_"..i].size={0,0}
        end
    end
end

-- Populate the production Tactical Teamplay widget.
-- Maintains the restored row_icon_N / row_glyph_N icon path.
local function populate_team(widget,match)
    if not widget or not widget.style or not widget.content then return end
    local me=local_player(match); local praise,score=summary_for(match,categories.team)
    widget.content.praise=praise; widget.content.score=score
    -- Keep the three-line praised state fixed, but vertically center the
    -- headline and goal count as a two-line stack when the praise line is empty.
    widget.style.section_label.offset[2]=praise~="" and 33 or 20
    widget.style.score.offset[2]=praise~="" and 60 or 47
    local all={
        {metric="coherency_efficiency",icon=metric_icon_indices.coherency_efficiency,label="Coherency"},
        {metric="team_saves",icon=metric_icon_indices.team_saves,label="Saves"},
        {metric="revived_operative",icon=metric_icon_indices.revived_operative,label="Revives"},
        {metric="ammo_score",icon=metric_icon_indices.ammo_score,label="Ammo"},
        {metric="heal_station_used",icon=22,context=true,label="Healthstations"},
        {metric="operated",icon=48,context=true,label="Objectives"},
        {metric="resources_collected",icon=50,context=true,label="Currency"},
    }
    local list={}
    for _,item in ipairs(all) do if mod:is_metric_enabled(item.metric) then list[#list+1]=item end end
    local slot_w=825/7
    local first_x=135+(825-#list*slot_w)/2
    for i=1,7 do
        local item=list[i]
        if item then
        local metric=item.metric
        local x=first_x+(i-1)*slot_w
        -- Teamplay widget IDs are row_icon_N / row_glyph_N, not row_N_icon.
        -- Populate the exact IDs used by the shared Teamplay definition.
        local icon=resolve_catalogue_icon(item.icon) or {kind="none"}
        local material_visible=icon.kind=="material"
        local glyph_visible=icon.kind=="unicode"
        local icon_id="row_icon_"..i
        local glyph_id="row_glyph_"..i
        widget.content[icon_id]=material_visible and icon.value or "content/ui/materials/base/ui_default_base"
        widget.content[glyph_id]=glyph_visible and icon.value or ""
        widget.content[icon_id.."_visible"]=material_visible
        widget.content[glyph_id.."_visible"]=glyph_visible
        widget.content["row_name_"..i]=item.label
        local icon_style=widget.style[icon_id]
        if icon_style then icon_style.size=material_visible and {18,18} or {0,0}; icon_style.offset[1]=x+slot_w/2-9 end
        local glyph_style=widget.style[glyph_id]
        if glyph_style then glyph_style.size=glyph_visible and {18,22} or {0,0}; glyph_style.offset[1]=x+slot_w/2-9 end
        widget.style["row_name_"..i].offset[1]=x; widget.style["row_name_"..i].size[1]=slot_w
        widget.style["row_raw_"..i].offset[1]=x; widget.style["row_raw_"..i].size[1]=slot_w
        local raw,total,share=metric_data(match,me,metric); local best=is_best_player(match,metric,me,"higher"); local c=state_color("higher",share,target(metric),total,best,player_rank(match,metric,me,"higher"))
        if metric=="coherency_efficiency" and share~=nil then raw=math.floor(share*4+0.5) end
        if item.context then c=close end
        widget.content["row_raw_"..i]=(total and total>0) and raw_text(raw) or "--"
        for _,id in ipairs({"row_raw_","row_name_"}) do local st=widget.style[id..i]; if st then st.text_color=c end end
        for _,id in ipairs({"row_icon_","row_glyph_"}) do local st=widget.style[id..i]; if st then if st.color then st.color=c else st.text_color=c end end end
        else
            widget.content["row_icon_"..i.."_visible"]=false; widget.content["row_glyph_"..i.."_visible"]=false
            widget.content["row_name_"..i]=""; widget.content["row_raw_"..i]=""
            widget.style["row_name_"..i].text_color=transparent; widget.style["row_raw_"..i].text_color=transparent
        end
    end
end

local function panel_definition()
    return UIWidget.create_definition({
        {pass_type="rect",style={vertical_alignment="center",horizontal_alignment="center",offset={0,0,-2},size={1054,766},color={235,8,28,22}}},
        {pass_type="rect",style={vertical_alignment="center",horizontal_alignment="center",offset={0,0,-1},size={1052,764},color=Color.black(255,true)}},
        {pass_type="texture",value="content/ui/materials/backgrounds/terminal_basic",style={vertical_alignment="center",horizontal_alignment="center",scale_to_material=true,offset={0,0,0},size={1070,800},color=Color.terminal_grid_background(255,true)}},
        {pass_type="texture",value="content/ui/materials/frames/dropshadow_heavy",style={vertical_alignment="center",horizontal_alignment="center",scale_to_material=true,offset={0,0,2},size={1080,797},color=Color.black(255,true)}},
        {pass_type="texture",value="content/ui/materials/frames/inner_shadow_medium",style={vertical_alignment="center",horizontal_alignment="center",scale_to_material=true,offset={0,0,1},size={1060,772},color=Color.terminal_grid_background(255,true)}},
    },ids.panel)
end

local function text_definition(scenegraph_id,value,font_size,color,font_settings)
    local style=table.clone(font_settings or UIFontSettings.header_1)
    style.font_size=font_size
    style.text_horizontal_alignment="center"
    style.text_vertical_alignment="center"
    if color then style.text_color=color end
    return UIWidget.create_definition({{pass_type="text",value_id="text",style_id="text",value=value,style=style}},scenegraph_id)
end

-- Tactical player row using the exact font family used by the Victory Board
-- player-name style, without creating additional scenegraph/widget keys.
local function tactical_players_definition(scenegraph_id)
    return UIWidget.create_definition({{
        pass_type="text", value_id="text", style_id="text", value="", style={
            offset={0,0,0}, size={970,54},
            text_horizontal_alignment="center", text_vertical_alignment="center",
            font_type=UIFontSettings.body.font_type, font_size=18,
            text_color=Color.white(255,true),
        },
    }},scenegraph_id)
end

-- Inject the shared Improve Yourself widgets into Darktide's Tactical Overlay.
-- Must remain idempotent across view creation and mod reloads.
local function install(definitions)
    if not definitions or not definitions.scenegraph_definition or not definitions.widget_definitions then return end
    local sg,wd=definitions.scenegraph_definition,definitions.widget_definitions
    -- Darktide wraps these definition tables in a strict metatable. Adding new
    -- keys through normal assignment throws "field_name not defined", so every
    -- injected scenegraph/widget definition must bypass __newindex with rawset.
    rawset(sg,ids.root,{parent="screen",vertical_alignment="center",horizontal_alignment="center",size={1070,800},position={0,0,base_z}})
    rawset(sg,ids.panel,{parent=ids.root,size={1070,800},position={0,0,base_z}})
    rawset(sg,ids.title,{parent=ids.panel,size={1020,62},position={25,20,base_z+2}})
    rawset(sg,ids.subtitle,{parent=ids.panel,size={970,24},position={50,80,base_z+2}})
    rawset(sg,ids.players,{parent=ids.panel,size={970,54},position={50,108,base_z+2}})
    -- The legacy "prototype" IDs are the production shared Victory widgets
    -- hosted inside the Tactical Overlay.
    -- Their IDs must remain synchronized with the shared definitions and updater.
    rawset(sg,"compact_defense_prototype",{parent=ids.panel,size={970,200},position={50,168,base_z+2}})
    rawset(sg,"compact_offense_prototype",{parent=ids.panel,size={970,200},position={50,380,base_z+2}})
    rawset(sg,"compact_team",{parent=ids.panel,size={970,90},position={50,592,base_z+2}})
    rawset(sg,ids.footer,{parent=ids.panel,size={970,24},position={50,714,base_z+2}})
    rawset(wd,"iy_tac_panel",panel_definition())
    rawset(wd,"iy_tac_title",text_definition(ids.title,"CURRENT PERFORMANCE",46,nil))
    rawset(wd,"iy_tac_subtitle",text_definition(ids.subtitle,"LIVE MISSION PROGRESS",16,Color.terminal_text_body(255,true)))
    rawset(wd,"iy_tac_players",tactical_players_definition(ids.players))
    rawset(wd,"compact_defense_prototype",VictoryWidgets.compact_defense_prototype)
    rawset(wd,"compact_offense_prototype",VictoryWidgets.compact_offense_prototype)
    rawset(wd,"compact_team",VictoryWidgets.compact_team)
    rawset(wd,"iy_tac_footer",text_definition(ids.footer,"Live values update while the tactical overlay is open.",13,Color.terminal_text_body(205,true)))
end

-- Tactical widgets are installed once through the HUD definition hook above.
-- Do not recreate them at runtime: Darktide's strict widget tables reject
-- runtime registration of custom names such as iy_tac_players.
local widget_names={"iy_tac_panel","iy_tac_title","iy_tac_subtitle","iy_tac_players","compact_defense_prototype","compact_offense_prototype","compact_team","iy_tac_footer"}
-- Position Tactical widgets relative to the live overlay scenegraph.
local function geometry(overlay)
    local sg=overlay._ui_scenegraph; if not sg then return end
    local g={
      [ids.root]={{1070,800},{0,0,base_z}},[ids.panel]={{1070,800},{0,0,base_z}},[ids.title]={{1020,62},{25,20,base_z+2}},[ids.subtitle]={{970,24},{50,80,base_z+2}},[ids.players]={{970,54},{50,108,base_z+2}},
      compact_defense_prototype={{970,200},{50,168,base_z+2}},compact_offense_prototype={{970,200},{50,380,base_z+2}},compact_team={{970,90},{50,592,base_z+2}},[ids.footer]={{970,24},{50,714,base_z+2}},
    }
    for id,d in pairs(g) do if sg[id] then sg[id].size=table.clone(d[1]); sg[id].position=table.clone(d[2]) end end
end
local function custom_widget(overlay, name)
    local by_name = overlay and overlay._widgets_by_name
    return by_name and rawget(by_name, name) or nil
end

local function widgets(overlay)
    local result = {}
    for _, name in ipairs(widget_names) do
        local widget = custom_widget(overlay, name)
        if widget then
            result[#result + 1] = widget
        end
    end
    return result
end

local function set_visible(overlay, visible)
    for _, widget in ipairs(widgets(overlay)) do
        widget.visible = visible
    end
end
-- Refresh Tactical content at the configured throttle interval.
-- Reuses existing widget/style tables to reduce Lua garbage and heap pressure.
local function refresh(overlay)
    local match=current_live_match(); local title=custom_widget(overlay,"iy_tac_title"); if title then title.content.text="CURRENT PERFORMANCE" end
    local subtitle=custom_widget(overlay,"iy_tac_subtitle"); if subtitle then local mission=match and match.mission or {}; local sec=safe_number(mission.duration_seconds) or 0; local role=tostring(mod:get("default_role") or "generalist"); subtitle.content.text=string.format("%s  |  %s  |  %02d:%02d  |  %s",tostring(mission.name or "CURRENT MISSION"),tostring(mission.difficulty or ""),math.floor(sec/60),math.floor(sec%60),role_labels[role] or string.upper(role)) end
    local pw=custom_widget(overlay,"iy_tac_players")
    if pw then
        if pw.style and pw.style.text then
            pw.style.text.font_type=UIFontSettings.body.font_type
            pw.style.text.font_size=18
        end
        local names={}
        for _,p in ipairs(match and match.players or {}) do names[#names+1]=tostring(p.name or "Unknown") end
        pw.content.text=#names>0 and table.concat(names,"     •     ") or "WAITING FOR LIVE SCOREBOARD DATA"
    end
    populate_defense(custom_widget(overlay,"compact_defense_prototype"),match)
    populate_offense(custom_widget(overlay,"compact_offense_prototype"),match)
    populate_team(custom_widget(overlay,"compact_team"),match)
end

mod:hook_require("scripts/ui/hud/elements/tactical_overlay/hud_element_tactical_overlay_definitions",install)
local suppressed_scores,suppressed_scores_value=nil,nil
-- Temporarily suppress Scores' Tactical board while this overlay is active.
-- Restores the previous value when Improve Yourself is hidden or destroyed.
local function suppress(v) local s=get_mod("scores"); if v then if not s then return end; if suppressed_scores~=s then if suppressed_scores then suppressed_scores.tactical_overview=suppressed_scores_value end; suppressed_scores=s; suppressed_scores_value=s.tactical_overview end; s.tactical_overview=false elseif suppressed_scores then suppressed_scores.tactical_overview=suppressed_scores_value; suppressed_scores=nil; suppressed_scores_value=nil end end
local function improve_yourself_selected()
    return mod:get("tactical_overlay_preference") ~= "scores"
end
mod:hook_safe(CLASS.HudElementTacticalOverlay,"update",function(self,dt,t,ui_renderer,render_settings,input_service,...)
    geometry(self); local mission=allowed_here(); local selected=improve_yourself_selected(); local visible=self._active==true and mission and selected; suppress(mission and selected)
    self._iy_refresh=(self._iy_refresh or 0)-(safe_number(dt) or 0); if visible and (not self._iy_was_active or self._iy_refresh<=0) then self._iy_refresh=0.35; local ok,err=pcall(refresh,self); if not ok then mod:error("Improve Yourself tactical refresh failed: %s",tostring(err)) end end
    set_visible(self,visible); self._iy_was_active=visible
end)
mod:hook(CLASS.HudElementTacticalOverlay,"_draw_widgets",function(func,self,dt,t,input_service,ui_renderer,render_settings,...)
    local visible=self._active==true and allowed_here() and improve_yourself_selected(); local hidden={}
    if visible then for _,name in ipairs({"scoreboard","circumstance_info","expedition_currency"}) do local w=self._widgets_by_name and self._widgets_by_name[name]; if w then hidden[#hidden+1]={w=w,v=w.visible,a=w.alpha_multiplier}; w.visible=false; w.alpha_multiplier=0 end end; for _,w in ipairs(self.row_widgets or {}) do hidden[#hidden+1]={w=w,v=w.visible,a=w.alpha_multiplier}; w.visible=false; w.alpha_multiplier=0 end end
    if func then func(self,dt,t,input_service,ui_renderer,render_settings,...) end
    if visible then for _,s in ipairs(hidden) do s.w.visible=s.v; s.w.alpha_multiplier=s.a end; for _,w in ipairs(widgets(self)) do w.alpha_multiplier=1; UIWidget.draw(w,ui_renderer) end end
end)
return mod
