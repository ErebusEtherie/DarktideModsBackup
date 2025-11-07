local mod = get_mod("BackstabColor")
-- Your mod code goes here.
-- https://vmf-docs.verminti.de

local HudElementCrosshairSettings = require("scripts/ui/hud/elements/crosshair/hud_element_crosshair_settings")
local hit_indicator_colors = HudElementCrosshairSettings.hit_indicator_colors
--local AttackPositioning = require("scripts/utilities/attack/attack_positioning")
local AttackSettings = require("scripts/settings/damage/attack_settings")
local Breed = require("scripts/utilities/breed")
local attack_types = AttackSettings.attack_types
local backstab_or_flanking
local smart_toggle = {
	backstab = true,
	flanking = true,
}
local backstab_talents = {
	backstab = {
		"zealot_backstab_damage",
		"zealot_stealth",
		"zealot_backstab_kills_restore_cd",
	},
	flanking = {
		"zealot_increased_damage_when_flanking",
	},
}
local backstab_traits = {
	backstab = {
		"rending_on_backstabs",
	},
	flanking = {
		"allow_flanking_and_increased_damage_when_flanking",
	},
}
local dot_thresholds = {
	backstab = 0.5,
	flanking = 0,
}
local backstab_colors = {
	backstab = {
		damage_normal = {255,96,207,154},	--255,255,255
		damage_crit = {255,180,177,0},	--255,165,0
		death = {255,0,255,0},	--255,0,0
	},
	flanking = {
		damage_normal = {255,96,207,154},	--255,255,255
		damage_crit = {255,180,177,0},	--255,165,0
		death = {255,0,255,0},	--255,0,0
	},
}

mod:hook_safe(CLASS.AttackReportManager,"_process_attack_result",function (self, buffer_data)
	local attacking_unit = buffer_data.attacking_unit
	local attacked_unit = buffer_data.attacked_unit
	if attacking_unit ~= Managers.player:local_player(1).player_unit or not attacked_unit or not Unit.alive(attacked_unit) or not Unit.alive(attacking_unit) then
		return
	end
		
	local attack_type = buffer_data.attack_type
	if attack_type == attack_types.melee or attack_type == attack_types.ranged then
		local is_backstab = attack_type == attack_types.melee and mod.is_backstabing(attacking_unit,attacked_unit) and smart_toggle.backstab
		local is_flanking = attack_type == attack_types.ranged and mod.is_flanking(attacked_unit,buffer_data.attack_direction) and smart_toggle.flanking
		backstab_or_flanking = is_backstab and "backstab" or is_flanking and "flanking" or false
	end	
end)

mod:hook("HudElementCrosshair","hit_indicator",function(func,self)
	local anim_progress, color, hit_weakspot = func(self)
	
	if backstab_or_flanking and anim_progress and color then		
		if color ~= hit_indicator_colors.blocked then
			for result_type,color_table in pairs(backstab_colors[backstab_or_flanking]) do
				if color == hit_indicator_colors[result_type] then
					return anim_progress, color_table, hit_weakspot
				end
			end
		else
			backstab_or_flanking = false	
		end
	end
	
	return anim_progress, color, hit_weakspot
end)
mod.is_backstabing = function(attacking_unit,attacked_unit)
	local attacking_unit_position = POSITION_LOOKUP[attacking_unit]
	local attacker_unit_position = POSITION_LOOKUP[attacked_unit]
	if not attacking_unit_position or not attacker_unit_position then
		return false
	end
	local attack_direction = Vector3.flat(Vector3.normalize(attacker_unit_position - attacking_unit_position))
	if not Vector3.is_valid(attack_direction) then
		return false
	end
	return mod._is_outmanoeuvring(attacked_unit,attack_direction,dot_thresholds.backstab)
end
mod.is_flanking = function(attacked_unit,attack_direction)
	local unbox = attack_direction and attack_direction:unbox()
	if not unbox or not Vector3.is_valid(unbox) then
		return false
	end
	return mod._is_outmanoeuvring(attacked_unit,unbox,dot_thresholds.flanking)
end
mod._is_outmanoeuvring = function(attacked_unit,attack_direction,dot_threshold)
	local attacked_unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
	
	if not attacked_unit_data_extension then
		return false
	end
	
	local attacked_unit_breed = attacked_unit_data_extension:breed()
	
	if not attacked_unit_breed or Breed.is_player(attacked_unit_breed) then
		return false
	end
	
	local attacked_unit_rotation = Unit.world_rotation(attacked_unit, 1)
	local attacked_unit_forward = Vector3.normalize(Vector3.flat(Quaternion.forward(attacked_unit_rotation)))
	
	if not Vector3.is_valid(attacked_unit_forward) then
		return false
	end
	
	local dot = Vector3.dot(attack_direction, attacked_unit_forward)
	local is_flanking = dot_threshold < dot
	return is_flanking
end
local load_color = function()
	local load_order = {"opacity","R","G","B"}
	for k,v in pairs{"backstab","flanking"} do
		for result_type,color_table in pairs(backstab_colors[v]) do
			if mod:get(string.format("%s_%s",v,result_type)) then
				for i =1,4 do
					color_table[i] = mod:get(string.format("%s_%s_%s",v,result_type,load_order[i]))
				end
			else
				backstab_colors[v][result_type] = table.clone(hit_indicator_colors[result_type],true)
			end
		end	
	end
end

local set_smart_toggle = function()
	local player = Managers.player:local_player(1)
	if not player or not player._profile then
		return
	end
	
	local profile = player._profile
	local loadout = profile.loadout
	local talents = profile.talents
	local slot_type = {backstab = "slot_primary", flanking = "slot_secondary",}
	smart_toggle = {
		backstab = true,
		flanking = true,
	}
	
	for attack_type,_ in pairs(smart_toggle) do
		if mod:get("smart_toggle_"..attack_type) then
			
			smart_toggle[attack_type] = false
			for _,talent_name in pairs(backstab_talents[attack_type]) do
				if talents[talent_name] then
					smart_toggle[attack_type] = true
					break
				end
			end
			
			local redirect = slot_type[attack_type]
			local weapon_traits = loadout[redirect].__master_item.traits
			if not table.is_empty(weapon_traits) then
				local trait
				for _,trait_slot in pairs(weapon_traits) do
					if smart_toggle[attack_type] then break end
					trait = trait_slot.id
					for _,trait_name in pairs(backstab_traits[attack_type]) do
						if string.find(trait,trait_name) then
							smart_toggle[attack_type] = true
							break
						end
					end
				end
			end
		
		end
	end
end

mod.on_setting_changed = function(id)
	load_color()
	set_smart_toggle()
end
mod.on_all_mods_loaded = function()
	load_color()
end
mod:command("backstabcolor",mod:localize("command_description"),function()
	local normal,backstab,flanking = {},{},{}
	local order = {"damage_normal","damage_crit","death"}
	local damage,critical,death = mod:localize("damage"),mod:localize("critical"),mod:localize("death")
	for i=1,3 do
		normal[i] = table.concat(hit_indicator_colors[order[i]],",",2)
		backstab[i] = table.concat(backstab_colors.backstab[order[i]],",",2)
		flanking[i] = table.concat(backstab_colors.flanking[order[i]],",",2)	
	end
	
	mod:echo(string.format("\n{#color(%s)}%s   {#color(%s)}%s   {#color(%s)}%s\n{#color(%s)}%s   {#color(%s)}%s   {#color(%s)}%s\n{#color(%s)}%s   {#color(%s)}%s   {#color(%s)}%s{#reset()}",
	normal[1],damage,normal[2],critical,normal[3],death,
	backstab[1],damage,backstab[2],critical,backstab[3],death,
	flanking[1],damage,flanking[2],critical,flanking[3],death))
end)

mod:hook_safe("PackageSynchronizerClient","player_profile_packages_changed",function(self, peer_id, local_player_id)
	if Network.peer_id() == peer_id then
		set_smart_toggle()		
	end
end)