local mod = get_mod("PlayerDeathfeed")

local AttackSettings = require("scripts/settings/damage/attack_settings")
local attack_results = AttackSettings.attack_results

local CombatFeed = require("scripts/ui/hud/elements/combat_feed/hud_element_combat_feed")
local NotificationFeed = require("scripts/ui/constant_elements/elements/notification_feed/constant_element_notification_feed")
local HudElementCombatFeedSettings = require("scripts/ui/hud/elements/combat_feed/hud_element_combat_feed_settings")
local Breed = require("scripts/utilities/breed")
local Breeds = require("scripts/settings/breed/breeds")
local UISettings = require("scripts/settings/ui/ui_settings")
local TextUtilities = require("scripts/utilities/ui/text")

local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")

local LocalizationManager = require("scripts/managers/localization/localization_manager")
local loc_manager = Managers.localization

local my_enemy_default_color = Color.pink(255, true)
local enemy_default_color = Color.red(255, true)
local NoteFeed

local PlayerUnitHealthExtension
local already_reported = {}
local damage_history = {}

local dmg_hist_count = 0

local breed_prefixes = {}
for breed_name, _ in pairs(Breeds) do
	breed_prefixes[#breed_prefixes + 1] = breed_name .. "_"
end
table.sort(breed_prefixes, function(a, b) return #a > #b end)

local function readable(text)
	for i = 1, #breed_prefixes do
		if string.find(text, "^" .. breed_prefixes[i]) then
			text = string.gsub(text, "^" .. breed_prefixes[i], "")
			break
		end
	end

    local readable_string = ""
    local tokens = string.split(text, "_")
    for i, token in ipairs(tokens) do
        local first_letter = string.sub(token, 1, 1)
        token = string.format("%s%s", string.upper(first_letter), string.sub(token, 2))
        readable_string = string.trim(string.format("%s %s", readable_string, token))
    end
    return readable_string
end

mod:hook_safe(CLASS.PlayerCharacterStateDead, "on_exit", function(self, unit, dt, t, previous_state, params)
	local the_unit = Managers.player:player_by_unit(unit)
	if the_unit then
		already_reported[the_unit:name()] = nil
	end
end)

mod:hook_safe(CLASS.PlayerCharacterStateKnockedDown, "on_exit", function(self, unit, t, next_state)
	local the_unit = Managers.player:player_by_unit(unit)
	if the_unit then
		already_reported[the_unit:name()] = nil
	end
end)

mod:hook_require("scripts/ui/hud/elements/combat_feed/hud_element_combat_feed_settings", function(settings)
	settings.colors_by_enemy_type.horde = {
		255,
		255,
		192,
		203,
    }
	settings.colors_by_enemy_type.roamer = {
		255,
		255,
		192,
		203,
    }
	settings.colors_by_enemy_type.captain = {
		255,
		213,
		94,
		0,
    }
	settings.colors_by_enemy_type.cultist_captain = {
		255,
		213,
		94,
		0,
    }
	settings.colors_by_enemy_type.witch = {
		255,
		213,
		94,
		0,
    }
end)

local function make_text_packet(text, killed_unit, dead_or_down, damage_profile, damage, killed_is_disabled)
	local packet = {
		player = killed_unit,
		line_1 = text,
		show_shine = true,
	}
	if dead_or_down then packet.color = Color[mod:get("dead_color")](100,true) else packet.color = Color[mod:get("knock_color")](100,true) end
	if mod:get("show_disabled_note") and killed_is_disabled then 
		local clean_state = string.gsub(killed_is_disabled, "_", " ")
		clean_state = string.gsub(clean_state, "(%a)([%w_']*)", function(first, rest) return string.upper(first) .. rest end)
		packet.line_2 = "Disabled: " .. clean_state 
	end
	return packet
end

mod:hook_safe("ConstantElementNotificationFeed", "_event_player_authenticated", function(self) 
	self._notification_templates.custom.total_time = mod:get("note_time")
	NoteFeed = self
end)	

function mod.on_setting_changed(setting_id)
	if not setting_id:match("note_time") then
        return
    end   
	NoteFeed._notification_templates.custom.total_time = mod:get("note_time")
end

function parse_damage_history(damage_hist, player)
	local text = ""
	local dense_text = {}
	local total_damage = 0
	
	if not mod:get("detailed_notification") then return text end
	
	for event in pairs(damage_hist) do
		if damage_hist[event].attacked_unit == player then
			local attacking_unit = damage_hist[event].attacking_unit
			local killer_unit_data_extension = ScriptUnit.has_extension(attacking_unit, "unit_data_system")
			local killer_breed_or_nil = killer_unit_data_extension and killer_unit_data_extension:breed()
			local killer_name
			
			local damage_profile_name = damage_hist[event].damage_profile.name
			local damage = damage_hist[event].damage
			local damage_profile = mod:localize(damage_profile_name)
			
			if type(damage_profile) == "string" and string.find(damage_profile, "^<") then
				damage_profile = readable(damage_profile_name)
			end
			
			if damage > 0 then
				if killer_breed_or_nil then 
					local display_name = killer_breed_or_nil.display_name
					if display_name == "loc_breed_display_name_undefined" or loc_manager:exists(display_name) then
						killer_name = HudElementCombatFeed._get_unit_presentation_name(CombatFeed, attacking_unit)
					else
						killer_name = TextUtilities.apply_color_to_text(mod:localize(display_name), my_enemy_default_color)
					end
					if not dense_text[killer_name] then
						dense_text[killer_name] = {}
						dense_text[killer_name].id = {}
						dense_text[killer_name].id[attacking_unit] = true
						dense_text[killer_name].count = 1
						dense_text[killer_name].attack = {}	
					elseif not dense_text[killer_name].id[attacking_unit] then
						dense_text[killer_name].id[attacking_unit] = true
						dense_text[killer_name].count = dense_text[killer_name].count + 1
					end
					if not dense_text[killer_name].attack[damage_profile] then
						dense_text[killer_name].attack[damage_profile] = {}
						dense_text[killer_name].attack[damage_profile].count = 1
						total_damage = total_damage + damage
					else
						dense_text[killer_name].attack[damage_profile].count = dense_text[killer_name].attack[damage_profile].count + 1
						total_damage = total_damage + damage
					end
				else
					if not dense_text["Misc"] then
						dense_text["Misc"] = {}
						dense_text["Misc"].count = 1
						dense_text["Misc"].attack = {}	
					else
						dense_text["Misc"].count = dense_text["Misc"].count + 1
					end

					if not dense_text["Misc"].attack[damage_profile] then
						dense_text["Misc"].attack[damage_profile] = {}
						dense_text["Misc"].attack[damage_profile].count = 1
						total_damage = total_damage + damage
					else
						dense_text["Misc"].attack[damage_profile].count = dense_text["Misc"].attack[damage_profile].count + 1
						total_damage = total_damage + damage
					end
				end
			end
		end
	end
	
	for killer in pairs(dense_text) do
		local new_line
		local killer_cnt = ""
		if dense_text[killer].count > 1 then
			killer_cnt = " (" .. tostring(dense_text[killer].count) .. ")"
		end
		
		if killer == "Misc" then
			new_line =  "\n" .. TextUtilities.apply_color_to_text("Misc", Color.green(255, true))
		else
			new_line =  "\n" .. killer .. killer_cnt
		end
		if mod:get("show_type_note") then
			for atk in pairs (dense_text[killer].attack) do
				local attack_cnt = tostring(dense_text[killer].attack[atk].count)
				new_line = new_line .. "\n" .. attack_cnt .. "x " .. atk
			end
		end
		text = new_line .. "\n" .. text
	end
	
	if mod:get("show_damage_note") then
		local dmg = string.format("%.0f", total_damage)
		text = text .. "\n Total Damage: " .. dmg .. "\n"
	end
	
	return text
end

mod:hook_safe("AttackReportManager", "_process_attack_result", function (self, buffer_data)
	local attacked_unit = buffer_data.attacked_unit
	local attacking_unit = buffer_data.attacking_unit
	local attack_result = buffer_data.attack_result

	local killed_unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
	local killed_breed_or_nil = killed_unit_data_extension and killed_unit_data_extension:breed()
	local killed_is_player = Breed.is_player(killed_breed_or_nil)
	
	if killed_is_player then
		local health_extension = ScriptUnit.extension(attacked_unit, "health_system")
		local killed_health_1 = health_extension:current_health()
		
		local player_unit_spawn_manager = Managers.state.player_unit_spawn
		local attacked_player = player_unit_spawn_manager:owner(attacked_unit)
		if not attacked_player then return end
		local player_name = attacked_player:name()
		
		if mod:get("detailed_notification") then
			dmg_hist_count = dmg_hist_count + 1
			if dmg_hist_count > 1000 then dmg_hist_count = 0 end
			local store_count = tostring(dmg_hist_count)
			damage_history[store_count] = {
				attacked_unit = buffer_data.attacked_unit,
				attacking_unit = buffer_data.attacking_unit,
				damage = buffer_data.damage,
				damage_profile = { name = buffer_data.damage_profile.name }
			}
			Promise.delay(mod:get("damage_window")):next(function()
				damage_history[store_count] = nil
			end)
		end
				
		if (killed_health_1 == 0 or killed_health_1 > 600) and (attack_result == attack_results.knock_down or attack_result == attack_results.died or attack_result == attack_results.toughness_broken or attack_result == attack_results.blocked or attack_result == attack_results.toughness_absorbed_melee) then		
			local killed_character_state_component = killed_unit_data_extension:read_component("character_state")
			local killed_is_dead = PlayerUnitStatus.is_dead(killed_character_state_component)								
			if already_reported[player_name] == killed_is_dead then return end
			already_reported[player_name] = killed_is_dead
			
			local current_dmg_hist = damage_history
			
			local killed_name
			killed_name = HudElementCombatFeed._get_unit_presentation_name(CombatFeed, attacked_unit)
			
			local killer_name
			local killer_unit_data_extension = ScriptUnit.has_extension(attacking_unit, "unit_data_system")
			local killer_breed_or_nil = killer_unit_data_extension and killer_unit_data_extension:breed()
			if killer_breed_or_nil then 
				local display_name = killer_breed_or_nil.display_name
				if display_name == "loc_breed_display_name_undefined" or loc_manager:exists(display_name) then
					killer_name = HudElementCombatFeed._get_unit_presentation_name(CombatFeed, attacking_unit)
				else
					killer_name = TextUtilities.apply_color_to_text(mod:localize(display_name), my_enemy_default_color)
				end
			end
			
			local killed_is_disabled
			if PlayerUnitStatus.is_disabled(killed_character_state_component) then killed_is_disabled = killed_character_state_component.state_name end
			if killed_is_disabled == "dead" then killed_is_disabled = nil end
			
			local damage_amount = string.format("%.0f", buffer_data.damage)
			local damage_profile_name = buffer_data.damage_profile.name
			
			Promise.delay(0.1):next(function()
				local text
				local text_note
				local dead_or_down
				local damage = damage_amount
				local damage_profile = mod:localize(damage_profile_name)
				
				if type(damage_profile) == "string" and string.find(damage_profile, "^<") then
					damage_profile = readable(damage_profile_name)
				end
				
				local killers_text
				if mod:get("detailed_notification") then
					killers_text = parse_damage_history(current_dmg_hist, attacked_unit)
				end
				
				killed_is_dead = PlayerUnitStatus.is_dead(killed_character_state_component)		
				if not killed_is_dead and killed_is_disabled == "knocked_down" then killed_is_disabled = nil end
				
				if not killer_breed_or_nil then
					if killed_is_dead then dead_or_down = " has Died" else dead_or_down = " was Knocked Down" end
					text = killed_name .. dead_or_down
				else
					if killed_is_dead then dead_or_down = " was Killed by: " else dead_or_down = " was Knocked Down by: " end
					text =  killed_name .. dead_or_down .. killer_name
				end	
				
				if mod:get("detailed_notification") then
					text_note = killed_name .. dead_or_down .. "\n" .. killers_text
				else
					text_note = text
					if mod:get("show_type_note") then text_note = text_note .. " [" .. damage_profile .. "]" end
					if mod:get("show_damage_note") then text_note = text_note .. " dealing " .. damage .. " damage." end
				end
				
				if mod:get("show_type_feed") then text = text .. " [" .. damage_profile .. "]" end
				if mod:get("show_damage_feed") then text = text .. " dealing " .. damage .. " damage." end
				
				local text_packet = make_text_packet(text_note, attacked_player, killed_is_dead, damage_profile, damage, killed_is_disabled)
				
				if mod:get("show_killfeed") then Managers.event:trigger("event_add_combat_feed_message", text) end
				if mod:get("show_notification") then
					Managers.event:trigger("event_add_notification_message", "custom", text_packet)
				end
				
				if mod:get("echo_feed") then mod:echo(text) end
				
				Promise.delay(5):next(function()
					already_reported[player_name] = nil
				end)
			end)
		end
	end
end)