local mod = get_mod("LoadoutMonitor")

-- Your mod code goes here.
-- https://vmf-docs.verminti.de
local UIWidget = require("scripts/managers/ui/ui_widget")
local UISettings = require("scripts/settings/ui/ui_settings")
local MasterItems = require("scripts/backend/master_items")
local ItemUtils = require("scripts/utilities/items")
local lid = Managers and Managers.localization and Managers.localization:language() or Application.user_setting("language_id")
local function get_local_player()
	return Managers.player:local_player(1)
end
local scoreboard = get_mod("scoreboard")
local default_feats_order = {"Ability","Blitz","Aura","Keystone"}
local feats_symbol = {
	Ability = mod:localize("player_Feats_symbol_Ability"),
	Blitz = mod:localize("player_Feats_symbol_Blitz"),
	Aura = mod:localize("player_Feats_symbol_Aura"),
	Keystone = mod:localize("player_Feats_symbol_Keystone"),
}

local weapon_slot = {Melee = "slot_primary", Range = "slot_secondary"}
local talents_index = {
	veteran = {
		Ability = {"veteran_combat_ability_elite_and_special_outlines","veteran_combat_ability_stagger_nearby_enemies","veteran_invisibility_on_combat_ability"},
		Blitz = {"veteran_grenade_apply_bleed","veteran_krak_grenade","veteran_smoke_grenade"},
		Aura = {"veteran_aura_gain_ammo_on_elite_kill_improved","veteran_increased_damage_coherency","veteran_movement_speed_coherency"},
		Keystone = {"veteran_snipers_focus","veteran_improved_tag","veteran_weapon_switch_passive"},
	},
	zealot = {
		Ability = {"zealot_attack_speed_post_ability","zealot_bolstering_prayer","zealot_stealth"},
		Blitz = {"zealot_improved_stun_grenade","zealot_flame_grenade","zealot_throwing_knives"},
		Aura = {"zealot_toughness_damage_reduction_coherency_improved","zealot_corruption_healing_coherency_improved","zealot_stamina_cost_multiplier_aura"},
		Keystone = {"zealot_fanatic_rage","zealot_martyrdom","zealot_quickness_passive"},
	},
	psyker = {
		Ability = {"psyker_shout_vent_warp_charge","psyker_combat_ability_force_field","psyker_combat_ability_stance"},
		Blitz = {"psyker_brain_burst_improved","psyker_grenade_chain_lightning","psyker_grenade_throwing_knives"},
		Aura = {"psyker_aura_damage_vs_elites","psyker_cooldown_aura_improved","psyker_aura_crit_chance_aura"},
		Keystone = {"psyker_passive_souls_from_elite_kills","psyker_empowered_ability","psyker_new_mark_passive"},
	},
	ogryn = {
		Ability = {"ogryn_longer_charge","ogryn_taunt_shout","ogryn_special_ammo"},
		Blitz = {"ogryn_grenade_friend_rock","ogryn_grenade_frag","ogryn_box_explodes"},
		Aura = {"ogryn_melee_damage_coherency_improved","ogryn_toughness_regen_aura","ogryn_damage_vs_suppressed_coherency"},
		Keystone = {"ogryn_passive_heavy_hitter","ogryn_carapace_armor","ogryn_leadbelcher_no_ammo_chance"},
	},
	adamant = {
		Ability = {"adamant_stance","adamant_area_buff_drone_improved","adamant_charge"},
		Blitz = {"adamant_whistle","adamant_shock_mine","adamant_grenade_improved"},
		Aura = {"adamant_companion_coherency","adamant_reload_speed_aura","adamant_damage_vs_staggered_aura"},
		Keystone = {"adamant_execution_order","adamant_terminus_warrant","adamant_forceful"},
		Keystone_dog = {"adamant_companion_focus_elite","adamant_disable_companion","adamant_companion_focus_ranged"},
	},
	broker = {
		Ability = {"broker_ability_focus_improved","broker_ability_punk_rage","broker_ability_stimm_field"},
		Blitz = {"broker_blitz_flash_grenade_improved","broker_blitz_missile_launcher","broker_blitz_tox_grenade"},
		Aura = {"broker_aura_gunslinger_improved","broker_coherency_melee_damage","broker_coherency_anarchist"},
		Keystone = {"broker_keystone_vultures_mark_on_kill","broker_keystone_adrenaline_junkie","broker_keystone_chemical_dependency"},
	},
	cryptic = {
		Ability = {"cryptic_chordclaw","cryptic_discharge","cryptic_precision_stance"},
		Blitz = {"cryptic_servo_skull_improved","cryptic_grenade_ability_arc_grenade","cryptic_grenade_ability_force_field"},
		Aura = {"cryptic_coherency_regen_aura_improved","cryptic_aura_weapon_improved","cryptic_ammo_aura"},
		Keystone = {"cryptic_redline","cryptic_dissector","cryptic_overload_keystone"},
	},
}
local feats_abbreviations = {}
local teammates = {}
mod.user_custom_feats_abbreviation = mod:get("user_custom_feats_abbreviation") or {}

mod.left_panel_lift = 0 - mod:get("left_panel_lift")
mod.text_color = {255,239,238,238}


local function clean_teammates()
	if not table.is_empty(teammates) then
		table.clear(teammates)
	end
end

mod.init = function(self)
	mod.display = {
		player_Feats = mod:get("display_player_feats"),
		player_Feats_display_type = mod:get("player_feats_display_type"),
		player_Feats_order = {},
		player_Feats_default_order = true,
		notable_talents = mod:get("display_notable_talents"),
		player_name = mod:get("display_player_name"),
		companion_name = mod:get("display_companion_name"),
		main_class = mod:get("display_main_class"),
	}
	mod.offsets = {
		lobby = {mod:get("lobby_weapon_offset"),mod:get("lobby_weapon_gap"),mod:get("lobby_talent_offset"),mod:get("lobby_talent_offset_y")},
		notable_talents = {mod:get("notable_talents_offset_x"),mod:get("notable_talents_offset_y"),mod:get("notable_talents_separation")},
		PlayerName = { mod:get("player_name_offset_x"), mod:get("player_name_offset_y"),},
		companion_name = { mod:get("companion_name_offset_x"), mod:get("companion_name_offset_y"),},
		Feats = { mod:get("player_feats_offset_x"), mod:get("player_feats_offset_y"),},
		Class = { mod:get("player_class_offset_x"), mod:get("player_class_offset_y"),},
	}
	mod.font_size = {
		lobby = {mod:get("lobby_weapon_font_size"),mod:get("lobby_Keystone_font_size")},
		feats = mod:get("player_feats_font_size"),
		notable_talents = mod:get("notable_talents_icon_size"),
		PlayerName = mod:get("player_name_font_size"),
		companion_name = mod:get("companion_name_font_size"),
		Feats = mod:get("player_feats_font_size"),
		Class = mod:get("player_class_font_size"),
	}
	
	mod.weapon_enable = mod:get("display_player_weapon")
	mod.weapon_name_lenghth = mod:get("user_weapon_name_lenghth")
	mod.weapon_name_size = mod:get("user_weapon_name_size")
	mod.weapon_name_multiplier = mod:get("user_weapon_name_multiplier") / 100
	
	mod.trait_display_by = {
		bless = mod:get("blessing_level_rule"),
		bless_offset = mod:get("user_bless_offset"),
		perk = mod:get("perk_level_rule"),
		perk_offset = mod:get("user_perk_offset"),
		font_size = mod:get("user_bless_perk_font_size")
	}
	scoreboard = get_mod("scoreboard")
	mod.left_panel_lift = 0 - mod:get("left_panel_lift")
	mod.lobby_exhibition = { weapon = mod:get("lobby_exhibition_weapons"), keystone = mod:get("lobby_exhibition_Keystone")}
	mod.endview_scoreboard_length = mod:get("endview_scoreboard_length")
	for i =1,#default_feats_order do
		mod.display.player_Feats_order[i] = mod:get(string.format("player_Feats_order_%s",i))
		mod.display.player_Feats_default_order = mod.display.player_Feats_order[i] == default_feats_order[i] and mod.display.player_Feats_default_order ~= false
	end
	mod.set_feat_abbreviation()
	clean_teammates()
end

local function check_player_class(archetype,target_class)
	local archetypes = {adamant = "adamant"}
	return archetype and archetypes[archetype] == target_class
end
local function player_career(profile)
	local archetype = profile.archetype
	local archetypename = archetype.archetype_name
	local name = archetype.name or "404"
	local symbol = name and UISettings.archetype_font_icon[name] or ""
	return Localize(archetypename),symbol
end

local function check_talent(player_talents,list,none)
	local selected_feat = none or "X" 
	for i = 1,#list do
		if player_talents[list[i]] then
			if mod.display.player_Feats_display_type == "character" then
				selected_feat = feats_abbreviations[list[i]]
			elseif mod.display.player_Feats_display_type == "number" then
				selected_feat = tostring(i)
			end
			break
		end
	end
	return selected_feat
end
mod.check_selected_feat = function(player_talents,archetype,feat_type,none)
	if not player_talents then return "??" end
	local empty_symbol = none or "X"
	local talent = empty_symbol
	local feat_types = talents_index[archetype]
	local feat_list = feat_types and feat_types[feat_type]
	if feat_list then
		talent = check_talent(player_talents,feat_list,empty_symbol)
		if check_player_class(archetype,"adamant") and feat_type == "Keystone" then
			local feat_dog = check_talent(player_talents,feat_types.Keystone_dog,empty_symbol)
			if feat_dog ~= empty_symbol then
				talent = talent .. "-" .. feat_dog
			end
		end		
	end
	return talent
end

mod.get_player_feats = function(profile)	
	local archetype = profile.archetype.name
	local talents = profile.talents
	
    if mod.display.player_Feats then
		local slots = 0
		local feats = {}
		if talents_index[archetype] then
			for i = 1,#default_feats_order do
				local feat_slot = mod.display.player_Feats_order[i]
				if feat_slot ~= "Disable" then
					slots = slots + 1
					feats[slots] = mod.check_selected_feat(talents,archetype,feat_slot)
					if not mod.display.player_Feats_default_order then
						feats[slots] = feats[slots]..feats_symbol[feat_slot]
					end					
				end
			end
		end
		return table.concat(feats,"-")
	end
    return ""
end
local noteworthy_talents = {
	veteran = {
		{
			"veteran_better_deployables",
			{255,0,206,209}
		},
		{
			"veteran_combat_ability_revive_nearby_allies",
			{255,255,215,0}
		},
		
	},
	cryptic = {
		{
			"cryptic_servo_skull_inject_ally",
			{255,77,255,46},
		},
	
	},
}
local function notable_talents(profile,widget)
	if not mod.display.notable_talents then
		return
	end	
	local archetype = profile.archetype.name
	local talents = profile.talents	
	local display = noteworthy_talents[archetype]
	if display then
		local style, content = widget.style, widget.content
		for i = 1, 3 do
			local slot = "loadout_intel_notable_"..tostring(i)
			if i <= #display then
				local setting = display[i]
				local check = setting[1]
				if talents[check] then
					content[slot] = setting[3] and mod:localize(setting[3]) or mod:localize("highlight_"..check) or "?"
					style[slot].text_color = setting[2] or {255,255,255,255}
					style[slot].font_size = mod.font_size.notable_talents
					style[slot].offset[1] = mod.offsets.notable_talents[1] + mod.offsets.notable_talents[3] * (i - 1)
					style[slot].offset[2] = mod.offsets.notable_talents[2]
				end				
			else
				content[slot] = ""
			end		
		end
	end
end

mod.get_weapon_perk_blessing = function(profile,weapon_type,trait_type)
	local item = profile.loadout[weapon_slot[weapon_type]]
	local traits = item[trait_type]
	local subjects = {" "," "," "," ",}
	if traits then
		for i = 1, 2 do
			if traits[i] then
				local id = traits[i].id
				local MasterItem = MasterItems.get_item(id)
				if trait_type == "traits" then
					subjects[i] = ItemUtils.display_name(MasterItem)
				elseif trait_type == "perks" then
					local perk = mod:localize(string.format("trait_%s",MasterItem.trait))
					if string.find(perk,"<") then perk = "????" end
					subjects[i] = perk
				end
				subjects[i+2] = traits[i].rarity
			end
		end
	end
	return subjects
end

local function weapon_display_name(profile,slot)
	local loadout = profile.loadout
	local weapon = loadout[weapon_slot[slot]]
	local name = " "
	local status
	if not slot or not weapon_slot[slot] then
		return name
	else		
		status,name = pcall(ItemUtils.display_name,weapon)
		if not status then name = " " end
	end
	return name ~= " " and string.trim(name) or " "
end

local trait_offsets = {
	bless = {280,},
	perk = {370,},
}
mod.get_companion_name = function(profile)
	return profile.talents and not profile.talents.adamant_disable_companion and profile.companion and profile.companion.name or ""
end

mod.get_playerloadout_intel = function(profile,widget)
	local player_name = profile.name
	local companion_name = mod.get_companion_name(profile)
	local Melee, Range = profile.loadout["slot_primary"], profile.loadout["slot_secondary"]
	local content = widget.content
	local style = widget.style
	
	local class,symbol = player_career(profile)
	local main_class_method = {hide = "",name = class, symbol = symbol, both = symbol..class}
	local weapons = {
		Melee = {
			name = weapon_display_name(profile,"Melee"),
			bless = mod.get_weapon_perk_blessing(profile,"Melee","traits"),
			perk = mod.get_weapon_perk_blessing(profile,"Melee","perks"),
			name_offset = 29.5,
			--template = Melee.weapon_template,
		},
		Range = {
			name = weapon_display_name(profile,"Range"),
			bless = mod.get_weapon_perk_blessing(profile,"Range","traits"),
			perk = mod.get_weapon_perk_blessing(profile,"Range","perks"),
			name_offset = 59.5
			--template = Range.weapon_template,
		},
	}
	-- feats class name
	content.loadout_intel_Feats = mod.get_player_feats(profile)
	content.loadout_intel_Class = main_class_method[mod.display.main_class] or main_class_method.symbol
	content.loadout_intel_PlayerName = mod.display.player_name and player_name or " "
	content.loadout_intel_companion_name = mod.display.companion_name and companion_name or ""
	notable_talents(profile,widget)
	for k,part in pairs({"Feats","Class","PlayerName","companion_name"}) do
		table.merge(style["loadout_intel_"..part].offset,mod.offsets[part])
		style["loadout_intel_"..part].font_size = mod.font_size[part]
	end
	if mod.weapon_enable then
		-- weapon perk blessing
		for weapon_type,value in pairs(weapons) do

			-- display name
			content["loadout_intel_"..weapon_type] = value.name

			local weapon_style = style["loadout_intel_"..weapon_type]
			weapon_style.offset[2] = value.name_offset
			weapon_style.font_size = mod.weapon_name_size * (string.len(value.name) >= mod.weapon_name_lenghth and mod.weapon_name_multiplier or 1)
			
			
			for _,trait_type in pairs({"perk","bless"}) do
				for i = 1,2 do
					local id = string.format("loadout_intel_%s_%s_%s",weapon_type,trait_type,i)
					local text = value[trait_type][i]
					if text == " " or not value[trait_type][i + 2] or mod.trait_display_by[trait_type] == "hide" then
						style[id].text_color = Color["item_rarity_1"](255,true)
						text = ""
					else
						if mod.trait_display_by[trait_type] == "number" or mod.trait_display_by[trait_type] == "both" then
							text = string.format("%s(%s)",text,value[trait_type][i+2])
						end
						if mod.trait_display_by[trait_type] == "color" or mod.trait_display_by[trait_type] == "both" then
							style[id].text_color = Color["item_rarity_"..tostring(value[trait_type][i+2])](255,true)
						else
							style[id].text_color = mod.text_color
						end
					end
					content[id] = text
					style[id].offset[1] = trait_offsets[trait_type][1] + (mod.trait_display_by[trait_type.."_offset"] or 0)
					style[id].font_size = mod.trait_display_by.font_size
				end
			end
		end
	end
end
mod:hook("LobbyView","_destroy_spawn_slots",function(func,self)
	if self._spawn_slots then
		for i = 1,#self._spawn_slots do
			local slot = self._spawn_slots[i]
			local panel_widget = slot and slot.panel_widget
			if panel_widget then
				for ii = #panel_widget.passes + 1,1,-1 do
					local pass = panel_widget.passes[ii]
					if pass then
						if pass.value_id == "loadout_intel_Melee" or pass.value_id == "loadout_intel_Range" or pass.value_id == "loadout_intel_Keystone" then
							pass.pass_type = nil
							pass.value_id = nil
							pass.style_id = nil
							table.clear(pass.data)
							panel_widget.passes[ii] = nil
						end
					end
				end
				panel_widget.content.loadout_intel_Melee = nil
				panel_widget.content.loadout_intel_Range = nil
				panel_widget.content.loadout_intel_Keystone = nil
				table.clear(panel_widget.style.loadout_intel_Melee)
				table.clear(panel_widget.style.loadout_intel_Range)
				table.clear(panel_widget.style.loadout_intel_Keystone)
				panel_widget.style.loadout_intel_Melee = nil
				panel_widget.style.loadout_intel_Range = nil
				panel_widget.style.loadout_intel_Keystone = nil
			end
		end
	end
	return func(self)
end)
mod.lobby_loadout = function (self)
	local spawn_slots = self._spawn_slots
	if not spawn_slots then
		return
	end
	for i = 1, #spawn_slots do
		local slot = spawn_slots[i]
		if slot then
			local panel_widget = slot.panel_widget
			local slot_player = slot.player
			local profile_spawner = slot.profile_spawner
			if panel_widget then
				local panel_content = panel_widget.content
				local panel_style = panel_widget.style
				panel_content.loadout_intel_Melee = ""
				panel_content.loadout_intel_Range = ""
				panel_content.loadout_intel_Keystone = ""
				if slot.occupied and slot_player and profile_spawner:spawned() then
					local profile = slot_player:profile()
					if profile and profile_spawner:spawned_character_unit() then
						
						if mod.lobby_exhibition.weapon then
							local offset_M = mod.offsets.lobby[1] or 165
							local offset_gap = mod.offsets.lobby[2] or 35
							panel_content.loadout_intel_Melee = weapon_display_name(profile,"Melee")
							panel_content.loadout_intel_Range = weapon_display_name(profile,"Range")
							panel_style.loadout_intel_Melee.offset[2] = offset_M
							panel_style.loadout_intel_Range.offset[2] = offset_M + offset_gap
							panel_style.loadout_intel_Melee.font_size = mod.font_size.lobby[1] or 17
							panel_style.loadout_intel_Range.font_size = mod.font_size.lobby[1] or 17
						end
						
						if mod.lobby_exhibition.keystone then
							local offset_x,offset_y = mod.offsets.lobby[3] or 200,mod.offsets.lobby[4] or 235
							local archetype = profile.archetype and profile.archetype.name
							local talents = profile.talents
							if archetype and talents then
								local Keystone = mod.check_selected_feat(talents,archetype,"Keystone","X")
								panel_content.loadout_intel_Keystone = Keystone
								panel_style.loadout_intel_Keystone.offset[1] = offset_x
								panel_style.loadout_intel_Keystone.offset[2] = offset_y
								panel_style.loadout_intel_Keystone.font_size = mod.font_size.lobby[2] or 17
							end
						end
					end
				end
			end
		end
	end
end

local function spectating_hud_tactical_overlay()
	local me = get_local_player()
	local camera = me.camera_handler
	if camera and (camera._is_hogtied or camera._mode == "dead" or camera._mode == "observer") then
		if Managers.input and Managers.input:get_input_service("Ingame") and Managers.input:get_input_service("Ingame"):get("tactical_overlay_hold") then
			return true
		end
	end
	return false
end

local player_loaded = function(account)
	return teammates and teammates[account]
end

mod.update_loadout = function(self, dt, t, player, ui_renderer)
	if not player:is_human_controlled() then
		return
	end
	
	local tactical_active = Managers.ui and Managers.ui._hud and Managers.ui._hud:tactical_overlay_active() or spectating_hud_tactical_overlay()
	local widget = self._widgets_by_name.playerloadout_intel
	local account = player._account_id	
	if tactical_active and not player_loaded(account) then
		local profile = player._profile
		mod.get_playerloadout_intel(profile,widget)
		teammates[account] = true
	end
	self:_set_widget_visible(widget,tactical_active,ui_renderer)
end
mod:hook_safe("HudElementPersonalPlayerPanel", "_update_player_features", mod.update_loadout)
mod:hook_safe("HudElementTeamPlayerPanel", "_update_player_features", mod.update_loadout)


-- overlap with P1/P2
mod:hook_safe("HudElementTacticalOverlay","_update_left_panel_elements",function(self, ui_renderer)
	self:set_scenegraph_position("left_panel",nil,mod.left_panel_lift)
end)


mod:hook_safe("CameraHandler","_switch_follow_target",clean_teammates)
mod:hook_safe(CLASS.InventoryView,"on_exit",clean_teammates)
mod:hook_safe("PackageSynchronizerClient","add_bot",clean_teammates)
mod:hook_safe("PackageSynchronizerClient","remove_bot",clean_teammates)
mod:hook_safe("StateGameplay","on_enter",clean_teammates)

mod.on_all_mods_loaded = function()
	mod:init()
end

mod.playerloadout_definition = function(instance)
	instance.scenegraph_definition.player_loadout = {
		parent = "background",
		vertical_alignment = "top",
		horizontal_alignment = "left",
		size = {500,100},
		position = {33,	-12,2}
	}
	
	instance.widget_definitions.playerloadout_intel = UIWidget.create_definition(
		{
			{
				pass_type = "text",
				value_id = "loadout_intel_Feats",
				style_id = "loadout_intel_Feats",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {0, 11.5, 150},
					size = {500, 100},
					text_color = Color.golden_rod(255, true),
					font_size = 18,
				},	
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_notable_1",
				style_id = "loadout_intel_notable_1",
				value = "",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {200, 0, 150},
					size = {50, 50},
					text_color = Color.golden_rod(255, true),
					font_size = 18,
				},	
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_notable_2",
				style_id = "loadout_intel_notable_2",
				value = "",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {200, 0, 150},
					size = {50, 50},
					text_color = Color.golden_rod(255, true),
					font_size = 18,
				},	
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_notable_3",
				style_id = "loadout_intel_notable_3",
				value = "",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {200, 0, 150},
					size = {50, 50},
					text_color = Color.golden_rod(255, true),
					font_size = 18,
				},	
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Class",
				style_id = "loadout_intel_Class",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {105, 6.5, 150},
					size = {500, 100},
					text_color = Color.golden_rod(255, true),
					font_size = 18,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_PlayerName",
				style_id = "loadout_intel_PlayerName",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {300, 6.5, 150},
					size = {500, 100},
					text_color = Color.golden_rod(255, true),
					font_size = 18,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_companion_name",
				style_id = "loadout_intel_companion_name",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {300, 6.5, 150},
					size = {500, 100},
					text_color = Color.golden_rod(255, true),
					font_size = 18,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Melee",
				style_id = "loadout_intel_Melee",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {0, 29.5, 200},
					size = {275, 100},
					text_color = mod.text_color,
					font_size = 20,
					line_spacing = 0.8,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Melee_bless_1",
				style_id = "loadout_intel_Melee_bless_1",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {trait_offsets.bless[1], 22.5, 200},
					size = {500, 100},
					text_color = mod.text_color,
					font_size = 14,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Melee_bless_2",
				style_id = "loadout_intel_Melee_bless_2",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {trait_offsets.bless[1], 38.5, 200},
					size = {500, 100},
					text_color = mod.text_color,
					font_size = 14,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Melee_perk_1",
				style_id = "loadout_intel_Melee_perk_1",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {370, 23, 200},
					size = {275, 100},
					text_color = mod.text_color,
					font_size = 14,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Melee_perk_2",
				style_id = "loadout_intel_Melee_perk_2",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {370, 39, 200},
					size = {500, 100},
					text_color = mod.text_color,
					font_size = 14,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Range",
				style_id = "loadout_intel_Range",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {0, 59.5, 200},
					size = {275, 100},
					text_color = mod.text_color,
					font_size = 20,
					line_spacing = 0.8,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Range_bless_1",
				style_id = "loadout_intel_Range_bless_1",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {trait_offsets.bless[1], 57, 200},
					size = {500, 100},
					text_color = mod.text_color,
					font_size = 14,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Range_bless_2",
				style_id = "loadout_intel_Range_bless_2",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {trait_offsets.bless[1], 72, 200},
					size = {500, 100},
					text_color = mod.text_color,
					font_size = 14,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Range_perk_1",
				style_id = "loadout_intel_Range_perk_1",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {370, 57, 200},
					size = {500, 100},
					text_color = mod.text_color,
					font_size = 14,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Range_perk_2",
				style_id = "loadout_intel_Range_perk_2",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "left",
					text_horizontal_alignment = "left",
					offset = {370, 72, 200},
					size = {500, 100},
					text_color = mod.text_color,
					font_size = 14,
				},
				
			},
		},"player_loadout")
		--},"player_icon")
end


local personal_player_panel_definition_path = "scripts/ui/hud/elements/personal_player_panel/hud_element_personal_player_panel_definitions"
local team_player_panel_definition_path = "scripts/ui/hud/elements/team_player_panel/hud_element_team_player_panel_definitions"
mod:hook_require(personal_player_panel_definition_path,mod.playerloadout_definition)
mod:hook_require(team_player_panel_definition_path,mod.playerloadout_definition)

mod:hook_safe("LobbyView","_check_loadout_changes",mod.lobby_loadout)


local lobby_view_definition_path = "scripts/ui/views/lobby_view/lobby_view_definitions"
mod:hook_require(lobby_view_definition_path,function(instance)
	local extra = {
			{
				pass_type = "text",
				value_id = "loadout_intel_Melee",
				style_id = "loadout_intel_Melee",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "center",
					text_horizontal_alignment = "center",
					offset = {0, 165, 1},
					size = {250, 100},
					text_color = mod.text_color,
					font_size = 17,
					--line_spacing = 0.95,
				},
				
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Range",
				style_id = "loadout_intel_Range",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "center",
					text_horizontal_alignment = "center",
					offset = {0, 200, 1},
					size = {250, 100},
					text_color = mod.text_color,
					font_size = 17,
					--line_spacing = 0.95,
				},
			},
			{
				pass_type = "text",
				value_id = "loadout_intel_Keystone",
				style_id = "loadout_intel_Keystone",
				value = " ",
				style = {
					vertical_alignment = "top",
					text_vertical_alignment = "top",
					horizontal_alignment = "center",
					text_horizontal_alignment = "center",
					offset = {200, 235, 1},
					size = {250, 100},
					text_color = mod.text_color,
					font_size = 17,
					--line_spacing = 0.95,
				},
			},
	}
	for i = 1,#extra do
		UIWidget.add_definition_pass(instance.panel_definition,extra[i])
	end
end)

-- Make tactical overlay available in meat grinder
--[[
mod:hook_require("scripts/ui/hud/hud_elements_player_onboarding", function(instance)
    local found = false
    -- Check if another mod already added tactical overlay
    for _, entry in pairs(instance) do
        if entry.class_name == "HudElementTacticalOverlay" then
			found = true
			break
		end
    end
    if not found then
        -- Add tactical overlay
        instance[#instance+1] = {
            package = "packages/ui/hud/tactical_overlay/tactical_overlay",
            use_hud_scale = false,
            class_name = "HudElementTacticalOverlay",
            filename = "scripts/ui/hud/elements/tactical_overlay/hud_element_tactical_overlay",
            visibility_groups = {
                "tactical_overlay",
                "alive",
            }
        }
    end
end)
--]]
mod.on_setting_changed = function(setting_name)
	mod:init()
end

mod:command("UCTA",mod:localize("user_custom_feats_abbreviation_description"),function(a,b,...)
	if a == "lid" then
		mod:set("user_lid",b)
		mod:notify("Language set to %s",b)
		return
	end
	if a and b then
		
		local order = {tonumber(a),tonumber(b)}
		local player = get_local_player()
		local archetype = player._profile.archetype.name
		
		if order[1] and order[2] and ((order[1] >= 1 and order[1] <= 4) and ((order[2] >= 1 and order[2] <= 3) or (check_player_class(archetype,"adamant") and order[2] >= 4 and order[2] <= 6))) then
			local category
			if order[2] >= 4 then
				category = "Keystone_dog"
				order[2] = order[2] - 3
			else
				category = default_feats_order[order[1]]
			end			
			local feat = talents_index[archetype][category][order[2]]
			local custom = {...}
			local new_abb = nil
			if not table.is_empty(custom) then
				new_abb = table.concat(custom," ")
			end
			feats_abbreviations[feat] = new_abb
			mod.user_custom_feats_abbreviation[feat] = new_abb
			mod:set("user_custom_feats_abbreviation",mod.user_custom_feats_abbreviation)
			clean_teammates()
		end
	end
end)

mod.set_feat_abbreviation = function()
	local feat
	for _,archetype in pairs(talents_index) do
		for __,feat_type in pairs(archetype) do
			for i = 1, #feat_type do
				feat = feat_type[i]
				feats_abbreviations[feat] = mod.user_custom_feats_abbreviation[feat] or mod:localize("def_"..feat) or "?"
			end
		end
	end
end

-- Define rows
mod.scoreboard_rows = {
	{name = "row_scoreboard_weapon_Melee_1",
		text = "row_scoreboard_weapon_melee",
		group = "offense",
		setting = "Loadout_weapons",
		is_text = true,
		validation = "ASC",
	},
	{name = "row_scoreboard_weapon_Melee_2",
		text = "row_scoreboard_blank",
		group = "offense",
		setting = "Loadout_weapons",
		is_text = true,
		validation = "ASC",
	},
	{name = "row_scoreboard_weapon_Melee_perk",
		text = "row_scoreboard_perk",
		group = "offense",
		setting = "Loadout_weapons_perk",
		is_text = true,
		validation = "ASC",
	},
	{name = "row_scoreboard_weapon_Melee_blessing_1",
		text = "row_scoreboard_blessing",
		group = "offense",
		setting = "Loadout_weapons_blessing",
		is_text = true,
		validation = "ASC",
	},
	{name = "row_scoreboard_weapon_Melee_blessing_2",
		text = "row_scoreboard_blank",
		group = "offense",
		setting = "Loadout_weapons_blessing",
		is_text = true,
		validation = "ASC",
	},
	{name = "row_scoreboard_weapon_Range_1",
		text = "row_scoreboard_weapon_range",
		group = "offense",
		setting = "Loadout_weapons",
		is_text = true,
		validation = "ASC",
	},
	{name = "row_scoreboard_weapon_Range_2",
		text = "row_scoreboard_blank",
		group = "offense",
		setting = "Loadout_weapons",
		is_text = true,
		validation = "ASC",
	},
	{name = "row_scoreboard_weapon_Range_perk",
		text = "row_scoreboard_perk",
		group = "offense",
		setting = "Loadout_weapons_perk",
		is_text = true,
		validation = "ASC",
	},
	{name = "row_scoreboard_weapon_Range_blessing_1",
		text = "row_scoreboard_blessing",
		group = "offense",
		setting = "Loadout_weapons_blessing",
		is_text = true,
		validation = "ASC",
	},
	{name = "row_scoreboard_weapon_Range_blessing_2",
		text = "row_scoreboard_blank",
		group = "offense",
		setting = "Loadout_weapons_blessing",
		is_text = true,
		validation = "ASC",
	},
	{name = "row_scoreboard_player_feat",
		text = "row_scoreboard_player_feat",
		group = "offense",
		setting = "Loadout_feat",
		is_text = true,
		validation = "ASC",
	},
	{name = "row_scoreboard_blank_1",
		text = "row_scoreboard_blank",
		group = "offense",
		setting = "Loadout_scoreboard_blank",
		is_text = true,
		big = true,
		validation = "ASC",
	},
}


mod.scoreboard_weaponname = function(profile,weapon_type)
	local disname = weapon_display_name(profile,weapon_type)
	local length = string.len(disname)
	local line = {" "," "}
	local all_remainders = {
			["zh-cn"] = 3,
			ja = 3,
		}
	local function get_charas(str)
		local count = 0
		if str then
			for chara in string.gmatch(str,"[%.%w ]") do
				count = count + 1
			end
		end
		return count
	end
	
	if length >= (mod.endview_scoreboard_length or 30) then
		length = math.floor(length / 2)
		if all_remainders[lid] then
			local charas = get_charas(string.sub(disname,1,length))
			local remainder = (length - charas) % all_remainders[lid]
			if remainder > 0 then
				length = length + all_remainders[lid] - remainder
			end
		end
		line[1] = string.sub(disname,1,length)
		line[2] = string.sub(disname,length + 1, -1)
	else
		line[1] = disname
	end
	return line
end

mod.update_scoreboard = function(trigger)
	if not scoreboard then return end
	if trigger == "on" then
		local players = Managers.player and Managers.player:players()
		if players then
			local update_weapon = mod:get("endview_scoreboard_weapons")
			mod:set("Loadout_weapons",update_weapon)
			mod:set("Loadout_weapons_perk",update_weapon and mod:get("endview_scoreboard_weapons_perk"))
			mod:set("Loadout_weapons_blessing",update_weapon and mod:get("endview_scoreboard_weapons_blessing"))
			mod:set("Loadout_feat",mod:get("endview_scoreboard_feat"))
			mod:set("Loadout_scoreboard_blank",mod:get("endview_scoreboard_blank"))
			for k,player in pairs(players) do
				local profile = player._profile
				local account_id = player:account_id() or player:name()
				local human = player:is_human_controlled()
				for k,weapon_type in pairs({"Melee","Range"}) do
					local line = {"",""}
					local traits_text = {perk = {"",""},blessing = {"",""}}
					if human then
						local traits = {perk = mod.get_weapon_perk_blessing(profile,weapon_type,"perks"),blessing = mod.get_weapon_perk_blessing(profile,weapon_type,"traits")}
						line = mod.scoreboard_weaponname(profile,weapon_type)
						for i = 1,2 do
							for k,v in pairs(traits) do
								if v[i] ~= " " then
									traits_text[k][i] = string.format("%s(%s)",v[i],v[i + 2])
								end
							end
						end
					end
					traits_text.perk = traits_text.perk[1]..(traits_text.perk[2] ~= "" and " "..traits_text.perk[2] or "")
					scoreboard:update_stat("row_scoreboard_weapon_"..weapon_type.."_perk",account_id,traits_text.perk)
					for i =1,2 do
						scoreboard:update_stat(string.format("row_scoreboard_weapon_%s_%s",weapon_type,i), account_id, line[i])
						scoreboard:update_stat(string.format("row_scoreboard_weapon_%s_blessing_%s",weapon_type,i), account_id, traits_text.blessing[i])
					end
				end
				local feats = human and mod.get_player_feats(profile) or " "
				scoreboard:update_stat("row_scoreboard_player_feat", account_id, feats)
				scoreboard:update_stat("row_scoreboard_blank_1", account_id, " ")
			end
		end
	elseif trigger == "off" then
		mod:set("Loadout_weapons",false)
		mod:set("Loadout_weapons_perk",false)
		mod:set("Loadout_weapons_blessing",false)
		mod:set("Loadout_feat",false)
		mod:set("Loadout_scoreboard_blank",false)
	end
end
mod:hook_safe(CLASS.EndView, "on_enter", function(...)
	mod.update_scoreboard("on")
	clean_teammates()
end)
mod:hook_safe(CLASS.EndView, "on_exit", function(...)
	mod.update_scoreboard("off")
end)

