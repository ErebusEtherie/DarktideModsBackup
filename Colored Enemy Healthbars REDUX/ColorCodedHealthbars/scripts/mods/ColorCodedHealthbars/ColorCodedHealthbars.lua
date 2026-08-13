-- Look whos snooping where they dont belong
local mod = get_mod("ColorCodedHealthbars")

-- Check if required modules are available
local Breeds = require("scripts/settings/breed/breeds")
local HudHealthBarLogic = require("scripts/ui/hud/elements/hud_health_bar_logic")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")

-- Resolved lazily (inside the hook callback below) instead of via require() at
-- mod load time, so we don't force health_extension.lua to load before the
-- engine has finished wiring up its class inheritance (self.super).
local function get_health_extension_class()
	local class_table = rawget(_G, "CLASS")
	return class_table and class_table.HealthExtension or rawget(_G, "HealthExtension")
end

-- ===== GLOBAL VARIABLES =====

-- Color definitions for different breed types
mod.breed_colors = {
	horde = { 150, 150, 150 },
	roamer = { 180, 180, 180 },
	elite = { 255, 165, 0 },
	special = { 255, 0, 255 },
	monster = { 255, 0, 0 },
	captain = { 128, 0, 128 },
	default = { 255, 255, 255 }
}

-- Initialize settings with defaults
local show = {
	enemy_name_color_r = 255,
	enemy_name_color_g = 255,
	enemy_name_color_b = 255,
	show_horde = false,
	show_roamer = false,
	show_elite = true,
	show_special = true,
	show_monster = true,
	show_captain = true,
	always_show_healthbars = false,
	show_enemy_names = false,
	show_damage_numbers = false,
	show_names_only = false,
	max_display_range = 50,
	healthbar_width = 71,
	healthbar_height = 3,
	text_size = 12,
	text_offset_y = -2,
	bar_offset_y = 10,
	-- Visual enhancement settings
	bar_border_enabled = true,
	bar_border_thickness = 2,
	background_opacity = 200,
	bar_corner_style = "industrial",
	text_shadow_enabled = true,
	name_background_enabled = true,
	text_outline_enabled = true,
	health_gradient = true,
	gradient_intensity = 75,
	smooth_animations = true,
	-- Priority system settings
	max_healthbars_shown = 8,
	hide_full_health = false,
	priority_system = true,
	show_tag_indicators = false,
	show_health_indicator = false,
	-- Visibility settings
	enable_visibility_check = true,
	visibility_fade_speed = 3.0,
	visibility_behind_walls = false,
	-- Damage number settings (NEW)
	damage_font_size = 17,
	damage_y_offset = 15,
	damage_combine_time = 0.2,
	damage_duration = 3,
	damage_fade_delay = 2,
	damage_expand_duration = 0.2,
	damage_shrink_duration = 1,
	damage_crit_scale = 1.5,
	-- Debuff stack settings (NEW)
	show_debuff_stacks = true,
	debuff_font_size = 12,
	debuff_offset_y = 8,
	show_debuff_bleed = true,
	show_debuff_burn = true,
	show_debuff_soulblaze = true,
	show_debuff_shock = true,
	show_debuff_toxin = true,
	show_debuff_brittle = true,
}

-- ===== DAMAGE NUMBER FUNCTIONS (NEW) =====

-- Color lookup for damage numbers
local damage_colors = {
	default = { 255, 255, 255, 255 },  -- White
	crit = { 255, 255, 165, 0 },       -- Orange
	weakspot = { 255, 255, 255, 0 },   -- Yellow
}

-- Readable stacked damage number rendering (like in your screenshot)
local function _render_stacked_damage_numbers(ui_content, ui_renderer, ui_style, damage_numbers, num_damage_numbers, position)
	if not show.show_damage_numbers then return end
	
	local settings = {
		default_font_size = show.damage_font_size,
		hundreds_font_size = show.damage_font_size * 0.85,
		y_offset = show.damage_y_offset,
		x_offset = 1,
		x_offset_between_numbers = 38,
		expand_bonus_scale = 30,
		expand_duration = show.damage_expand_duration,
		shrink_duration = show.damage_shrink_duration,
		crit_hit_size_scale = show.damage_crit_scale,
		first_hit_size_scale = 1.2,
	}
	
	local scale = RESOLUTION_LOOKUP.scale or 1
	local default_font_size = settings.default_font_size * scale
	local hundreds_font_size = settings.hundreds_font_size * scale
	local font_type = ui_style.font_type
	local size = ui_style.size
	
	local z_position = position[3]
	local y_position = position[2] + settings.y_offset
	local x_position = position[1] + settings.x_offset
	
	local text_color = { 255, 255, 255, 255 }
	
	-- Apply alpha multiplier if widget is fading
	if ui_content.alpha_multiplier then
		text_color[1] = text_color[1] * ui_content.alpha_multiplier
	end
	
	for i = num_damage_numbers, 1, -1 do
		local damage_number = damage_numbers[i]
		local duration = damage_number.duration
		local time = damage_number.time
		local progress = math.clamp(time / duration, 0, 1)
		
		if progress >= 1 then
			table.remove(damage_numbers, i)
		else
			damage_number.time = damage_number.time + ui_renderer.dt
		end
		
		-- Set color based on damage type
		if damage_number.was_critical then
			text_color[2] = damage_colors.crit[2]
			text_color[3] = damage_colors.crit[3]
			text_color[4] = damage_colors.crit[4]
		elseif damage_number.hit_weakspot then
			text_color[2] = damage_colors.weakspot[2]
			text_color[3] = damage_colors.weakspot[3]
			text_color[4] = damage_colors.weakspot[4]
		else
			text_color[2] = damage_colors.default[2]
			text_color[3] = damage_colors.default[3]
			text_color[4] = damage_colors.default[4]
		end
		
		local value = damage_number.value
		local font_size = value <= 99 and default_font_size or hundreds_font_size
		
		-- Expand animation
		local expand_duration = damage_number.expand_duration
		if expand_duration then
			local expand_time = damage_number.expand_time
			local expand_progress = math.clamp(expand_time / expand_duration, 0, 1)
			local anim_progress = 1 - expand_progress
			
			font_size = font_size + settings.expand_bonus_scale * anim_progress
			
			if expand_progress >= 1 then
				damage_number.expand_duration = nil
				damage_number.shrink_start_t = duration - settings.shrink_duration
			else
				damage_number.expand_time = expand_time + ui_renderer.dt
			end
		-- Shrink animation
		elseif damage_number.shrink_start_t and time > damage_number.shrink_start_t then
			local diff = time - damage_number.shrink_start_t
			local percentage = diff / settings.shrink_duration
			local scale = 1 - percentage
			
			font_size = font_size * scale
			text_color[1] = text_color[1] * scale
		end
		
		local text = tostring(value)
		local current_order = num_damage_numbers - i
		
		-- Scale first/newest number
		if current_order == 0 then
			local scale_size = damage_number.was_critical and settings.crit_hit_size_scale or settings.first_hit_size_scale
			font_size = font_size * scale_size
		end
		
		-- Stack numbers vertically with proper Z-order
		position[3] = z_position + current_order
		position[2] = y_position
		position[1] = x_position + current_order * settings.x_offset_between_numbers
		
		UIRenderer.draw_text(ui_renderer, text, font_size, font_type, position, size, text_color, {})
	end
	
	-- Restore position
	position[3] = z_position
	position[2] = y_position
	position[1] = x_position
end

-- Main damage number logic pass function
local function damage_number_logic_function(pass, ui_renderer, ui_style, ui_content, position, size)
	local damage_numbers = ui_content.damage_numbers
	if not damage_numbers then return end
	
	local num_damage_numbers = #damage_numbers
	if num_damage_numbers == 0 then return end
	
	_render_stacked_damage_numbers(ui_content, ui_renderer, ui_style, damage_numbers, num_damage_numbers, position)
end

-- ===== DEBUFF STACK TRACKING (NEW) =====

-- Categories of debuffs shown as icon + stack counters on the healthbar.
-- Order here is the display order of the slots (left to right). Icons are the
-- game's own buff HUD textures, rendered the same way the vanilla player buff
-- bar does it: the buff_container material with the icon texture plugged into
-- its talent_icon material slot.
local MAX_DEBUFF_SLOTS = 6
local DEBUFF_ICON_MATERIAL = "content/ui/materials/icons/buffs/hud/buff_container_with_background"
local DEBUFF_GRADIENT_MAP = "content/ui/textures/color_ramps/talent_default"

local debuff_categories = {
	{ key = "bleed",     icon = "content/ui/textures/icons/buffs/hud/zealot/zealot_crits_apply_bleed",    color = { 255, 70, 70 } },
	{ key = "burn",      icon = "content/ui/textures/icons/buffs/hud/states_fire_buff_hud",               color = { 255, 150, 30 } },
	{ key = "soulblaze", icon = "content/ui/textures/icons/buffs/hud/states_green_fire_buff_hud",         color = { 210, 90, 255 } },
	{ key = "shock",     icon = "content/ui/textures/icons/buffs/hud/states_electric_buff_hud",           color = { 90, 210, 255 } },
	{ key = "toxin",     icon = "content/ui/textures/icons/buffs/hud/states_toxic_cloud_buff_hud",        color = { 130, 255, 90 } },
	{ key = "brittle",   icon = "content/ui/textures/icons/buffs/hud/psyker/psyker_warp_attacks_rending", color = { 220, 220, 170 } },
}

-- Buff template names are matched by keyword instead of an exact list so new
-- weapon/talent dots (e.g. patch additions) are picked up without a mod update.
-- Order matters: brittleness must be classified before burn because
-- "rending_burn_debuff" contains "burn", and soulblaze templates contain
-- "fire" ("warp_fire"), so they must be classified before the burn keywords.
local function classify_debuff(buff_name)
	if string.find(buff_name, "bleed") then
		return "bleed"
	end
	if string.find(buff_name, "rending") or string.find(buff_name, "brittleness") then
		return "brittle"
	end
	if string.find(buff_name, "warp_fire") or string.find(buff_name, "warpfire") or string.find(buff_name, "soulblaze") then
		return "soulblaze"
	end
	if string.find(buff_name, "burn") or string.find(buff_name, "flamer") or string.find(buff_name, "immolation") then
		return "burn"
	end
	if string.find(buff_name, "shock") or string.find(buff_name, "electrocut") then
		return "shock"
	end
	if string.find(buff_name, "toxic") then
		return "toxin"
	end

	return nil
end

local temp_dot_counts = {}

-- Sums stack counts of tracked debuffs currently on the unit, keyed by category.
local function scan_unit_debuffs(unit)
	table.clear(temp_dot_counts)

	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")
	if not buff_extension or not buff_extension.buffs then
		return temp_dot_counts
	end

	local ok, buffs = pcall(buff_extension.buffs, buff_extension)
	if not ok or not buffs then
		return temp_dot_counts
	end

	for i = 1, #buffs do
		local buff = buffs[i]

		if buff and buff.template_name then
			local ok_name, buff_name = pcall(buff.template_name, buff)

			if ok_name and type(buff_name) == "string" then
				local category = classify_debuff(buff_name)

				if category and show["show_debuff_" .. category] then
					-- Only count actual debuffs. Minions also carry utility buffs whose
					-- names contain our keywords (e.g. the flamer's own
					-- "renegade_flamer_liquid_immunity", the shocktrooper's
					-- "drop_shocktrooper_grenade_on_death") — every real enemy dot
					-- (bleed, flamer_assault, warp_fire, shock_grenade_interval, ...)
					-- is an interval_buff, so filter by template class. Brittleness
					-- stacks are not dots: they live in plain "buff" class templates
					-- (rending_debuff, rending_burn_debuff, saw_rending_debuff, ...).
					local is_dot = false

					if buff.template then
						local ok_template, buff_template = pcall(buff.template, buff)

						if ok_template and type(buff_template) == "table" then
							local class_name = buff_template.class_name

							if category == "brittle" then
								is_dot = class_name == "buff" or class_name == "stacking_buff"
							else
								is_dot = class_name == "interval_buff" or class_name == "dot_buff"
							end
						end
					end

					if is_dot then
						local stacks = 1

						if buff.stack_count then
							local ok_stacks, stack_count = pcall(buff.stack_count, buff)
							stacks = (ok_stacks and tonumber(stack_count)) or 1
						end

						temp_dot_counts[category] = (temp_dot_counts[category] or 0) + stacks
					end
				end
			end
		end
	end

	return temp_dot_counts
end

-- Writes active debuff icon + count pairs into the widget's slot passes
-- (packed left-to-right, centered as a row) and blanks the unused slots.
local function update_debuff_slots(style, content, unit, visible)
	local slot_index = 0

	if visible then
		local counts = scan_unit_debuffs(unit)
		local font_size = show.debuff_font_size or 12
		local icon_size = font_size + 8
		local text_width = font_size * 1.6
		local slot_width = icon_size + text_width + 3
		local row_y = -((show.healthbar_height or 3) + (show.debuff_offset_y or 8))

		local num_active = 0
		for i = 1, #debuff_categories do
			local count = counts[debuff_categories[i].key]
			if count and count > 0 then
				num_active = num_active + 1
			end
		end

		if num_active > 0 then
			local total_width = num_active * slot_width

			for i = 1, #debuff_categories do
				local category = debuff_categories[i]
				local count = counts[category.key]

				if count and count > 0 and slot_index < MAX_DEBUFF_SLOTS then
					slot_index = slot_index + 1

					local slot_left = -total_width * 0.5 + (slot_index - 1) * slot_width
					local icon_style = style["debuff_icon_" .. slot_index]
					local text_style = style["debuff_slot_" .. slot_index]

					if icon_style then
						if icon_style.color then
							icon_style.color[1] = 255
							icon_style.color[2] = category.color[1]
							icon_style.color[3] = category.color[2]
							icon_style.color[4] = category.color[3]
						end

						if icon_style.material_values then
							icon_style.material_values.talent_icon = category.icon
						end

						if icon_style.offset then
							icon_style.offset[1] = slot_left + icon_size * 0.5
							icon_style.offset[2] = row_y
						end
					end

					if text_style then
						content["debuff_slot_" .. slot_index] = tostring(count)

						local text_color = text_style.text_color or text_style.color
						if text_color then
							text_color[1] = 255
							text_color[2] = category.color[1]
							text_color[3] = category.color[2]
							text_color[4] = category.color[3]
						end

						if text_style.offset then
							text_style.offset[1] = slot_left + icon_size + 1 + text_width * 0.5
							text_style.offset[2] = row_y
						end
					end
				end
			end
		end
	end

	for i = slot_index + 1, MAX_DEBUFF_SLOTS do
		local icon_style = style["debuff_icon_" .. i]
		if icon_style and icon_style.color then
			icon_style.color[1] = 0
		end

		local slot_style = style["debuff_slot_" .. i]
		if slot_style then
			local slot_color = slot_style.text_color or slot_style.color
			if slot_color then
				slot_color[1] = 0
			end
			content["debuff_slot_" .. i] = ""
		end
	end
end

-- ===== HELPER FUNCTIONS =====

local function update_colors_from_settings()
	mod.breed_colors.horde = { 
		mod:get("horde_color_r") or 150, 
		mod:get("horde_color_g") or 150, 
		mod:get("horde_color_b") or 150 
	}
	mod.breed_colors.monster = { 
		mod:get("monster_color_r") or 255, 
		mod:get("monster_color_g") or 0, 
		mod:get("monster_color_b") or 0 
	}
	mod.breed_colors.roamer = { 
		math.min(255, (mod:get("horde_color_r") or 150) + 30), 
		math.min(255, (mod:get("horde_color_g") or 150) + 30), 
		math.min(255, (mod:get("horde_color_b") or 150) + 30) 
	}
	mod.breed_colors.captain = { 
		mod:get("captain_color_r") or math.floor((mod:get("monster_color_r") or 255) / 2), 
		mod:get("captain_color_g") or math.floor((mod:get("monster_color_g") or 0) / 2), 
		mod:get("captain_color_b") or math.floor((mod:get("monster_color_b") or 0) / 2) 
	}
	mod.breed_colors.elite_ranged = {
		mod:get("elite_ranged_color_r") or 255,
		mod:get("elite_ranged_color_g") or 100,
		mod:get("elite_ranged_color_b") or 0
	}
	mod.breed_colors.elite_melee = {
		mod:get("elite_melee_color_r") or 255,
		mod:get("elite_melee_color_g") or 165,
		mod:get("elite_melee_color_b") or 0
	}
	mod.breed_colors.elite_gunner = {
		mod:get("elite_gunner_color_r") or 255,
		mod:get("elite_gunner_color_g") or 140,
		mod:get("elite_gunner_color_b") or 0
	}
	mod.breed_colors.elite_shocktrooper = {
		mod:get("elite_shocktrooper_color_r") or 255,
		mod:get("elite_shocktrooper_color_g") or 210,
		mod:get("elite_shocktrooper_color_b") or 60
	}
	mod.breed_colors.elite_rager = {
		mod:get("elite_rager_color_r") or 255,
		mod:get("elite_rager_color_g") or 60,
		mod:get("elite_rager_color_b") or 90
	}
	mod.breed_colors.elite_mauler = {
		mod:get("elite_mauler_color_r") or 200,
		mod:get("elite_mauler_color_g") or 120,
		mod:get("elite_mauler_color_b") or 40
	}
	mod.breed_colors.elite_crusher = {
		mod:get("elite_crusher_color_r") or 130,
		mod:get("elite_crusher_color_g") or 160,
		mod:get("elite_crusher_color_b") or 255
	}
	mod.breed_colors.elite_bulwark = {
		mod:get("elite_bulwark_color_r") or 0,
		mod:get("elite_bulwark_color_g") or 200,
		mod:get("elite_bulwark_color_b") or 170
	}
	mod.breed_colors.elite_reaper = {
		mod:get("elite_reaper_color_r") or 235,
		mod:get("elite_reaper_color_g") or 70,
		mod:get("elite_reaper_color_b") or 20
	}
	mod.breed_colors.elite_radio_operator = {
		mod:get("elite_radio_operator_color_r") or 220,
		mod:get("elite_radio_operator_color_g") or 220,
		mod:get("elite_radio_operator_color_b") or 220
	}
	mod.breed_colors.special_sniper = {
		mod:get("special_sniper_color_r") or 255,
		mod:get("special_sniper_color_g") or 0,
		mod:get("special_sniper_color_b") or 200
	}
	mod.breed_colors.special_pox_hound = {
		mod:get("special_pox_hound_color_r") or 200,
		mod:get("special_pox_hound_color_g") or 0,
		mod:get("special_pox_hound_color_b") or 255
	}
	mod.breed_colors.special_trapper = {
		mod:get("special_trapper_color_r") or 180,
		mod:get("special_trapper_color_g") or 0,
		mod:get("special_trapper_color_b") or 255
	}
	mod.breed_colors.special_disabler = {
		mod:get("special_disabler_color_r") or 200,
		mod:get("special_disabler_color_g") or 0,
		mod:get("special_disabler_color_b") or 255
	}
	mod.breed_colors.special_mutant = {
		mod:get("special_mutant_color_r") or 0,
		mod:get("special_mutant_color_g") or 180,
		mod:get("special_mutant_color_b") or 255
	}
	mod.breed_colors.special_burster = {
		mod:get("special_burster_color_r") or 120,
		mod:get("special_burster_color_g") or 255,
		mod:get("special_burster_color_b") or 0
	}
	mod.breed_colors.special_flamer = {
		mod:get("special_flamer_color_r") or 255,
		mod:get("special_flamer_color_g") or 80,
		mod:get("special_flamer_color_b") or 0
	}
	mod.breed_colors.special_bomber = {
		mod:get("special_bomber_color_r") or 255,
		mod:get("special_bomber_color_g") or 220,
		mod:get("special_bomber_color_b") or 0
	}
	mod.breed_colors.special = {
		mod:get("special_color_r") or 255,
		mod:get("special_color_g") or 0,
		mod:get("special_color_b") or 255
	}
end

function mod.get_breed_color(unit)
	if not unit then
		return mod.breed_colors.default
	end
	
	local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
	if not unit_data_extension then
		return mod.breed_colors.default
	end
	
	local breed = unit_data_extension:breed()
	if not breed or not breed.tags then
		return mod.breed_colors.default
	end
	
	local tags = breed.tags
	local breed_name = breed.name
	
	if tags.captain or tags.cultist_captain then
		return mod.breed_colors.captain
	elseif tags.elite then
		-- Ogryn elites first: their breed names also contain "gunner"/"executor",
		-- so they must not fall into the human Gunner/Mauler buckets.
		if string.find(breed_name, "ogryn_gunner") then
			return mod.breed_colors.elite_reaper
		elseif string.find(breed_name, "ogryn_executor") then
			return mod.breed_colors.elite_crusher
		elseif string.find(breed_name, "bulwark") then
			return mod.breed_colors.elite_bulwark
		elseif string.find(breed_name, "berzerker") then
			return mod.breed_colors.elite_rager
		elseif string.find(breed_name, "shocktrooper") then
			return mod.breed_colors.elite_shocktrooper
		elseif string.find(breed_name, "gunner") then
			-- Covers renegade_gunner, cultist_gunner and renegade_plasma_gunner
			return mod.breed_colors.elite_gunner
		elseif string.find(breed_name, "executor") then
			return mod.breed_colors.elite_mauler
		elseif string.find(breed_name, "radio_operator") then
			return mod.breed_colors.elite_radio_operator
		elseif string.find(breed_name, "rifleman") or string.find(breed_name, "assault") then
			-- Generic ranged/melee fallback for future elite breeds
			return mod.breed_colors.elite_ranged
		else
			return mod.breed_colors.elite_melee
		end
	elseif tags.special then
		if breed_name == "renegade_sniper" then
			return mod.breed_colors.special_sniper
		elseif string.find(breed_name, "hound") then
			-- Covers chaos_hound, chaos_armored_hound and chaos_hound_mutator
			return mod.breed_colors.special_pox_hound
		elseif breed_name == "renegade_netgunner" then
			return mod.breed_colors.special_trapper
		elseif string.find(breed_name, "mutant") then
			return mod.breed_colors.special_mutant
		elseif string.find(breed_name, "poxwalker_bomber") then
			return mod.breed_colors.special_burster
		elseif string.find(breed_name, "flamer") then
			return mod.breed_colors.special_flamer
		elseif string.find(breed_name, "grenadier") then
			return mod.breed_colors.special_bomber
		else
			return mod.breed_colors.special
		end
	elseif tags.monster then
		return mod.breed_colors.monster
	elseif tags.horde then
		return mod.breed_colors.horde
	elseif tags.roamer then
		return mod.breed_colors.roamer
	else
		return mod.breed_colors.default
	end
end

local function get_unit_tag_info(unit)
	if not unit then return nil, nil end
	
	local success, result = pcall(function()
		if not Managers.state or not Managers.state.extension then
			return nil, nil
		end
		
		local smart_tag_system = Managers.state.extension:system("smart_tag_system")
		if not smart_tag_system then return nil, nil end
		
		local tag_id = smart_tag_system:unit_tag_id(unit)
		if not tag_id then return nil, nil end
		
		local tag = smart_tag_system:tag_by_id(tag_id)
		if not tag then return nil, nil end
		
		local template = tag:template()
		if not template then return nil, nil end
		
		if template.companion_order then
			return "companion_order", tag
		end
		
		if template.name == "enemy_over_here_veteran" then
			return "veteran_tag", tag
		end
		
		if template.name == "enemy_over_here" then
			return "enemy_tag", tag
		end
		
		return nil, nil
	end)
	
	if success then
		return result
	else
		return nil, nil
	end
end

local function get_tag_border_color(tag_type)
	if tag_type == "companion_order" then
		return { 255, 128, 0, 255 }
	elseif tag_type == "veteran_tag" then
		return { 255, 255, 255, 0 }
	elseif tag_type == "enemy_tag" then
		return { 255, 255, 0, 0 }
	end
	return { 255, 0, 0, 0 }
end

local function get_health_gradient_color(health_percent, base_color, intensity)
	if not show.health_gradient then
		return base_color
	end
	
	if intensity <= 0 then
		return base_color
	end
	
	health_percent = math.max(0, math.min(1, health_percent))
	
	local full_health = { 0, 255, 0 }
	local mid_health = { 255, 255, 0 }
	local low_health = { 255, 0, 0 }
	
	local gradient_color
	
	if health_percent > 0.5 then
		local t = (health_percent - 0.5) * 2
		gradient_color = {
			math.floor(mid_health[1] * (1 - t) + full_health[1] * t),
			math.floor(mid_health[2] * (1 - t) + full_health[2] * t),
			math.floor(mid_health[3] * (1 - t) + full_health[3] * t)
		}
	else
		local t = health_percent * 2
		gradient_color = {
			math.floor(low_health[1] * (1 - t) + mid_health[1] * t),
			math.floor(low_health[2] * (1 - t) + mid_health[2] * t),
			math.floor(low_health[3] * (1 - t) + mid_health[3] * t)
		}
	end
	
	local blend_factor = intensity / 100
	local final_color = {
		math.floor(base_color[1] * (1 - blend_factor) + gradient_color[1] * blend_factor),
		math.floor(base_color[2] * (1 - blend_factor) + gradient_color[2] * blend_factor),
		math.floor(base_color[3] * (1 - blend_factor) + gradient_color[3] * blend_factor)
	}
	
	return final_color
end

local function get_enemy_display_name(unit)
	if not unit then return "Unknown" end
	
	local success, name = pcall(function()
		local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
		if not unit_data_extension then return "Unknown" end
		
		local breed = unit_data_extension:breed()
		if not breed then return "Unknown" end
		
		local function safe_localize(text)
			if not text or text == "" or text == "n/a" then
				return nil
			end
			
			local success, localized = pcall(Localize, text)
			if not success then
				return nil
			end
			
			if localized and 
			   type(localized) == "string" and 
			   localized ~= text and 
			   not string.find(localized, "^loc_") and
			   not string.find(string.lower(localized), "unlocalized") then
				return localized
			end
			
			return nil
		end
		
		local boss_extension = ScriptUnit.has_extension(unit, "boss_system")
		if boss_extension then
			local boss_name = boss_extension:display_name()
			local localized = safe_localize(boss_name)
			if localized then
				return localized
			end
		end
		
		local smart_tag_extension = ScriptUnit.has_extension(unit, "smart_tag_system")
		if smart_tag_extension then
			local smart_tag_name = smart_tag_extension:display_name()
			local localized = safe_localize(smart_tag_name)
			if localized then
				return localized
			end
		end
		
		if breed.display_name then
			local localized = safe_localize(breed.display_name)
			if localized then
				return localized
			end
		end
		
		local clean_name = breed.name or "Unknown"
		clean_name = string.gsub(clean_name, "_", " ")
		clean_name = string.gsub(clean_name, "(%a)([%w_']*)", function(first, rest) 
			return string.upper(first) .. string.lower(rest) 
		end)
		
		return clean_name
	end)
	
	if success and name then
		return name
	else
		return "Unknown"
	end
end

-- ===== UNIT CHECKING =====

local function should_enable_healthbar(unit)
	if not unit then return false end
	
	local game_mode_name = Managers.state.game_mode:game_mode_name()
	if game_mode_name == "shooting_range" and not get_mod("creature_spawner") then
		return false
	end

	local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
	if not unit_data_extension then return false end
	
	local breed = unit_data_extension:breed()
	if not breed or not breed.tags or not breed.tags.minion then return false end
	
	local tags = breed.tags
	
	if (tags.captain or tags.cultist_captain) and show.show_captain then return true end
	if tags.monster and show.show_monster then return true end
	if tags.elite and show.show_elite then return true end
	if tags.special and show.show_special then return true end
	if tags.horde and show.show_horde then return true end
	if tags.roamer and show.show_roamer then return true end
	
	return false
end

-- ===== HEALTHBAR PRIORITY/CAP SYSTEM =====

-- Lower number = higher priority. Matches the "Monsters > Specials > Elites > Others" order from the tooltip.
local function get_priority_tier(unit)
	if not unit then return 7 end

	local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
	if not unit_data_extension then return 7 end

	local breed = unit_data_extension:breed()
	if not breed or not breed.tags then return 7 end

	local tags = breed.tags

	if tags.monster then return 1 end
	if tags.special then return 2 end
	if tags.captain or tags.cultist_captain then return 3 end
	if tags.elite then return 4 end
	if tags.roamer then return 5 end
	if tags.horde then return 6 end

	return 7
end

local temp_marker_priority_list = {}

local function priority_sort_func(a, b)
	if a.tier ~= b.tier then
		return a.tier < b.tier
	end

	return (a.marker.distance or math.huge) < (b.marker.distance or math.huge)
end

-- ===== TEMPLATE SETUP =====

local template = {}
local function get_current_size()
	return { 
		mod:get("healthbar_width") or 71,
		mod:get("healthbar_height") or 3
	}
end

template.size = get_current_size()
template.name = "color_coded_healthbar"
template.unit_node = "j_head"
template.position_offset = { 0, 0, 0.35 }
template.check_line_of_sight = true
template.max_distance = 100
template.screen_clamp = false
template.disable_distance_scaling = true

template.bar_settings = {
	alpha_fade_delay = 2.6,
	alpha_fade_duration = 0.6,
	alpha_fade_min_value = 50,
	animate_on_health_increase = true,
	bar_spacing = 2,
	duration_health = 1,
	duration_health_ghost = 7,
	health_animation_threshold = 0.1,
}

template.fade_settings = {
	default_fade = 0,
	fade_from = 0,
	fade_to = 1,
	distance_max = 100,
	distance_min = 50,
	easing_function = math.ease_exp,
}

local function get_toggles()
	local function get_setting_bool(setting_name, default_value)
		local value = mod:get(setting_name)
		if value == nil then
			return default_value
		end
		return value
	end
	
	local function get_setting_num(setting_name, default_value)
		local value = mod:get(setting_name)
		if value == nil then
			return default_value
		end
		return value
	end
	
	local function get_setting_str(setting_name, default_value)
		local value = mod:get(setting_name)
		if value == nil then
			return default_value
		end
		return value
	end
	
	show.show_horde = get_setting_bool("show_horde", false)
	show.show_roamer = get_setting_bool("show_roamer", false)
	show.show_elite = get_setting_bool("show_elite", true)
	show.show_special = get_setting_bool("show_special", true)
	show.show_monster = get_setting_bool("show_monster", true)
	show.show_captain = get_setting_bool("show_captain", true)
	show.always_show_healthbars = get_setting_bool("always_show_healthbars", false)
	show.show_enemy_names = get_setting_bool("show_enemy_names", false)
	show.show_damage_numbers = get_setting_bool("show_damage_numbers", false)
	show.show_names_only = get_setting_bool("show_names_only", false)
	
	show.max_healthbars_shown = get_setting_num("max_healthbars_shown", 8)
	show.hide_full_health = get_setting_bool("hide_full_health", false)
	show.priority_system = get_setting_bool("priority_system", true)
	show.show_tag_indicators = get_setting_bool("show_tag_indicators", false)
	show.show_health_indicator = get_setting_bool("show_health_indicator", false)
	
	show.enable_visibility_check = get_setting_bool("enable_visibility_check", true)
	show.visibility_fade_speed = get_setting_num("visibility_fade_speed", 3.0)
	show.visibility_behind_walls = get_setting_bool("visibility_behind_walls", false)
	
	show.enemy_name_color_r = get_setting_num("enemy_name_color_r", 255)
	show.enemy_name_color_g = get_setting_num("enemy_name_color_g", 255)
	show.enemy_name_color_b = get_setting_num("enemy_name_color_b", 255)
	show.max_display_range = get_setting_num("max_display_range", 50)
	show.healthbar_width = get_setting_num("healthbar_width", 71)
	show.healthbar_height = get_setting_num("healthbar_height", 3)
	show.text_size = get_setting_num("text_size", 12)
	show.text_offset_y = get_setting_num("text_offset_y", -2)
	show.bar_offset_y = get_setting_num("bar_offset_y", 10)
	show.bar_border_thickness = get_setting_num("bar_border_thickness", 2)
	show.background_opacity = get_setting_num("background_opacity", 200)
	show.gradient_intensity = get_setting_num("gradient_intensity", 75)
	
	show.bar_border_enabled = get_setting_bool("bar_border_enabled", true)
	show.text_shadow_enabled = get_setting_bool("text_shadow_enabled", true)
	show.name_background_enabled = get_setting_bool("name_background_enabled", true)
	show.text_outline_enabled = get_setting_bool("text_outline_enabled", true)
	show.health_gradient = get_setting_bool("health_gradient", true)
	show.smooth_animations = get_setting_bool("smooth_animations", true)
	
	show.bar_corner_style = get_setting_str("bar_corner_style", "industrial")
	
	-- Damage number settings (NEW)
	show.damage_font_size = get_setting_num("damage_font_size", 17)
	show.damage_y_offset = get_setting_num("damage_y_offset", 15)
	show.damage_combine_time = get_setting_num("damage_combine_time", 0.2)
	show.damage_duration = get_setting_num("damage_duration", 3)
	show.damage_fade_delay = get_setting_num("damage_fade_delay", 2)
	show.damage_expand_duration = get_setting_num("damage_expand_duration", 0.2)
	show.damage_shrink_duration = get_setting_num("damage_shrink_duration", 1)
	show.damage_crit_scale = get_setting_num("damage_crit_scale", 1.5)

	-- Debuff stack settings (NEW)
	show.show_debuff_stacks = get_setting_bool("show_debuff_stacks", true)
	show.debuff_font_size = get_setting_num("debuff_font_size", 12)
	show.debuff_offset_y = get_setting_num("debuff_offset_y", 8)
	show.show_debuff_bleed = get_setting_bool("show_debuff_bleed", true)
	show.show_debuff_burn = get_setting_bool("show_debuff_burn", true)
	show.show_debuff_soulblaze = get_setting_bool("show_debuff_soulblaze", true)
	show.show_debuff_shock = get_setting_bool("show_debuff_shock", true)
	show.show_debuff_toxin = get_setting_bool("show_debuff_toxin", true)
	show.show_debuff_brittle = get_setting_bool("show_debuff_brittle", true)

	template.size = { show.healthbar_width, show.healthbar_height }
	template.position_offset = { 0, 0, 0.35 + (show.bar_offset_y / 100) }
	
	template.check_line_of_sight = show.enable_visibility_check
	
	local max_distance = show.always_show_healthbars and math.max(show.max_display_range, 100) or show.max_display_range
	
	template.max_distance = max_distance
	template.fade_settings.distance_max = max_distance
	template.fade_settings.distance_min = max_distance * 0.5
	
	if show.smooth_animations then
		template.bar_settings.alpha_fade_delay = show.always_show_healthbars and 10.0 or 2.6
		template.bar_settings.alpha_fade_duration = 0.6
		template.bar_settings.alpha_fade_min_value = show.always_show_healthbars and 200 or 50
		template.fade_settings.default_fade = show.always_show_healthbars and 1 or 0
	else
		template.bar_settings.alpha_fade_delay = 0.1
		template.bar_settings.alpha_fade_duration = 0.1
		template.bar_settings.alpha_fade_min_value = show.always_show_healthbars and 255 or 100
		template.fade_settings.default_fade = show.always_show_healthbars and 1 or 0
	end
	
	update_colors_from_settings()
end

template.create_widget_defintion = function(template, scenegraph_id)
	local bar_width = show.healthbar_width
	local bar_height = show.healthbar_height
	local font_size = show.text_size
	local text_offset = show.text_offset_y
	
	local border_enabled = show.bar_border_enabled
	local border_thickness = show.bar_border_thickness
	local bg_opacity = show.background_opacity
	local text_shadow = show.text_shadow_enabled
	local text_outline = show.text_outline_enabled
	local bar_style = show.bar_corner_style
	
	local size = { bar_width, bar_height }
	local bar_size = { size[1], size[2] }
	local bar_offset = { -size[1] * 0.5, 0, 0 }
	
	local border_thickness_val = border_thickness or 1
	local border_size = { size[1] + border_thickness_val * 2, size[2] + border_thickness_val * 2 }
	local border_pos = { bar_offset[1] - border_thickness_val, bar_offset[2] - border_thickness_val, 0 }
	
	local show_names = show.show_enemy_names
	
	local font_settings = UIFontSettings.nameplates or UIFontSettings.hud_body
	local name_text_style = {
		font_size = font_size,
		font_type = font_settings.font_type or "proxima_nova_bold",
		horizontal_alignment = "center",
		vertical_alignment = "center",
		text_horizontal_alignment = "center",
		text_vertical_alignment = "bottom",
		text_color = {
			show_names and 255 or 0, 
			show.enemy_name_color_r, 
			show.enemy_name_color_g, 
			show.enemy_name_color_b 
		},
		offset = { 0, size[2] + text_offset, 6 },
		size = { size[1] + 40, math.max(25, font_size + 5) },
		drop_shadow = text_shadow,
	}
	
	if text_outline then
		name_text_style.drop_shadow = true
	end

	local widget_passes = {}
	
	-- NEW: Damage number logic pass (renders stacked damage numbers like MoarDots)
	if show.show_damage_numbers then
		table.insert(widget_passes, {
			pass_type = "logic",
			value = damage_number_logic_function,
			style = {
				font_size = show.damage_font_size,
				horizontal_alignment = "left",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "bottom",
				vertical_alignment = "center",
				offset = {
					-size[1] * 0.5,
					-size[2],
					2,
				},
				font_type = font_settings.font_type or "proxima_nova_bold",
				text_color = { 255, 255, 255, 255 },
				size = {
					600,
					size[2],
				},
			},
		})
	end
	
	table.insert(widget_passes, {
		pass_type = "rect",
		style_id = "border",
		value = "content/ui/materials/backgrounds/default_square",
		style = {
			vertical_alignment = "center",
			offset = { border_pos[1], border_pos[2], 0 },
			size = border_size,
			color = { 0, 0, 0, 0 },
		},
	})
	
	table.insert(widget_passes, {
		pass_type = "rect",
		style_id = "tag_border",
		value = "content/ui/materials/backgrounds/default_square",
		style = {
			vertical_alignment = "center",
			offset = { border_pos[1] - 1, border_pos[2] - 1, -1 },
			size = { border_size[1] + 2, border_size[2] + 2 },
			color = { 0, 255, 0, 0 },
		},
	})
	
	table.insert(widget_passes, {
		pass_type = "rect",
		style_id = "background",
		value = "content/ui/materials/backgrounds/default_square",
		style = {
			vertical_alignment = "center",
			offset = { bar_offset[1], bar_offset[2], 1 },
			size = bar_size,
			color = { bg_opacity, 60, 60, 60 },
		},
	})
	
	local bar_pass_type = "rect"
	local bar_material = "content/ui/materials/backgrounds/default_square"
	if bar_style == "capped" then
		bar_material = "content/ui/materials/bars/simple/fill"
	elseif bar_style == "industrial" then
		-- Reuses the vanilla boss/monster health bar texture (segmented, brutalist
		-- 40k plating already baked into the art) instead of a flat rect.
		bar_pass_type = "texture_uv"
		bar_material = "content/ui/materials/hud/backgrounds/boss_health_fill"
	end

	table.insert(widget_passes, {
		pass_type = bar_pass_type,
		style_id = "bar",
		value = bar_material,
		style = {
			vertical_alignment = "center",
			offset = { bar_offset[1], bar_offset[2], 3 },
			size = bar_size,
			color = { 255, 255, 255, 255 },
		},
	})

	if bar_style == "capped" then
		table.insert(widget_passes, {
			pass_type = "texture",
			style_id = "bar_end_left",
			value = "content/ui/materials/bars/simple/end",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1] - 6, bar_offset[2], 4 },
				size = { 12, bar_size[2] + 4 },
				color = { 255, 255, 255, 255 },
			},
		})

		table.insert(widget_passes, {
			pass_type = "texture",
			style_id = "bar_end_right",
			value = "content/ui/materials/bars/simple/end",
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "center",
				offset = { bar_offset[1] + bar_size[1] - 6, bar_offset[2], 4 },
				size = { 12, bar_size[2] + 4 },
				color = { 255, 255, 255, 255 },
			},
		})
	end

	if bar_style == "industrial" then
		-- Metal end-cap plates flanking the bar. Uses the same flush-against-the-bar
		-- formula as the "capped" style's bar ends (proven to sit correctly) instead
		-- of a standalone icon, since icon textures carry their own internal padding
		-- that throws off alignment at this small a size.
		table.insert(widget_passes, {
			pass_type = "texture",
			style_id = "icon_left",
			value = "content/ui/materials/bars/simple/end",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				offset = { bar_offset[1] - 6, bar_offset[2], 4 },
				size = { 12, bar_size[2] + 4 },
				color = { 255, 210, 200, 180 },
			},
		})

		table.insert(widget_passes, {
			pass_type = "texture",
			style_id = "icon_right",
			value = "content/ui/materials/bars/simple/end",
			style = {
				horizontal_alignment = "right",
				vertical_alignment = "center",
				offset = { bar_offset[1] + bar_size[1] - 6, bar_offset[2], 4 },
				size = { 12, bar_size[2] + 4 },
				color = { 255, 210, 200, 180 },
			},
		})

		-- Threshold tick marks at 75% / 50% / 25% health, like the reference design.
		local threshold_ids = { "threshold_75", "threshold_50", "threshold_25" }
		local threshold_fractions = { 0.75, 0.5, 0.25 }

		for i = 1, #threshold_fractions do
			table.insert(widget_passes, {
				pass_type = "rect",
				style_id = threshold_ids[i],
				value = "content/ui/materials/backgrounds/default_square",
				style = {
					vertical_alignment = "center",
					offset = { bar_offset[1] + bar_size[1] * threshold_fractions[i], bar_offset[2], 3.5 },
					size = { 2, bar_size[2] + 2 },
					color = { 200, 10, 10, 10 },
				},
			})
		end

		-- Explicit segment dividers. The vanilla boss texture's plating detail is
		-- too fine to read at this bar's small scale, so segments are drawn directly
		-- as thin dark gaps instead of relying on the source art.
		local num_segments = 8
		local segment_ids = {}

		for i = 1, num_segments - 1 do
			local segment_id = "segment_" .. i
			segment_ids[i] = segment_id

			table.insert(widget_passes, {
				pass_type = "rect",
				style_id = segment_id,
				value = "content/ui/materials/backgrounds/default_square",
				style = {
					vertical_alignment = "center",
					offset = { bar_offset[1] + bar_size[1] * (i / num_segments), bar_offset[2], 3.6 },
					size = { 1, bar_size[2] },
					color = { 160, 0, 0, 0 },
				},
			})
		end
	end
	
	-- Backdrop plate behind the name so it stays readable over bright backgrounds
	-- (skies, fire, snow) instead of floating as bare colored text. Kept slim and
	-- trimmed with thin accent lines rather than a single flat block, so it reads
	-- as a small plaque instead of a big dark slab.
	local name_plate_size = { size[1] + 20, math.max(18, font_size + 2) }
	local name_plate_offset_y = size[2] + text_offset

	table.insert(widget_passes, {
		pass_type = "rect",
		style_id = "name_background",
		value = "content/ui/materials/backgrounds/default_square",
		style = {
			horizontal_alignment = "center",
			vertical_alignment = "center",
			offset = { 0, name_plate_offset_y, 5 },
			size = name_plate_size,
			color = { 0, 0, 0, 0 },
		},
	})

	table.insert(widget_passes, {
		pass_type = "rect",
		style_id = "name_plate_top",
		value = "content/ui/materials/backgrounds/default_square",
		style = {
			horizontal_alignment = "center",
			vertical_alignment = "center",
			offset = { 0, name_plate_offset_y - name_plate_size[2] * 0.5, 5.5 },
			size = { name_plate_size[1] * 0.6, 1 },
			color = { 0, 0, 0, 0 },
		},
	})

	table.insert(widget_passes, {
		pass_type = "rect",
		style_id = "name_plate_bottom",
		value = "content/ui/materials/backgrounds/default_square",
		style = {
			horizontal_alignment = "center",
			vertical_alignment = "center",
			offset = { 0, name_plate_offset_y + name_plate_size[2] * 0.5, 5.5 },
			size = { name_plate_size[1] * 0.6, 1 },
			color = { 0, 0, 0, 0 },
		},
	})

	table.insert(widget_passes, {
		pass_type = "text",
		style_id = "name_text",
		value = "Enemy",
		value_id = "name_text",
		style = name_text_style,
	})
	
	table.insert(widget_passes, {
		pass_type = "text",
		style_id = "tag_indicator",
		value = "",
		value_id = "tag_indicator",
		style = {
			font_size = math.max(12, font_size - 4),
			font_type = font_settings.font_type or "proxima_nova_bold",
			horizontal_alignment = "center",
			text_horizontal_alignment = "center",
			text_vertical_alignment = "top",
			vertical_alignment = "center",
			text_color = { 0, 255, 255, 0 },
			offset = { 0, -(size[2] + text_offset + 4), 7 },
			size = { size[1] + 40, math.max(20, font_size) },
			drop_shadow = text_shadow,
		},
	})
	
	-- Debuff stack slots (NEW): a row of game buff icons with stack counts above
	-- the bar. Slots are generic; the update function assigns whichever debuff
	-- categories are active to slots left-to-right and hides the rest. Icons use
	-- the vanilla player-buff-bar rendering: buff_container material with the
	-- category's icon texture in its talent_icon slot.
	local debuff_font_size = show.debuff_font_size or 12
	local debuff_icon_size = debuff_font_size + 8
	local debuff_row_y = -(size[2] + (show.debuff_offset_y or 8))

	for i = 1, MAX_DEBUFF_SLOTS do
		table.insert(widget_passes, {
			pass_type = "texture",
			style_id = "debuff_icon_" .. i,
			value = DEBUFF_ICON_MATERIAL,
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				offset = { 0, debuff_row_y, 7 },
				size = { debuff_icon_size, debuff_icon_size },
				color = { 0, 255, 255, 255 },
				material_values = {
					talent_icon = (debuff_categories[i] or debuff_categories[1]).icon,
					gradient_map = DEBUFF_GRADIENT_MAP,
					progress = 1,
					opacity = 1,
				},
			},
		})

		table.insert(widget_passes, {
			pass_type = "text",
			style_id = "debuff_slot_" .. i,
			value = "",
			value_id = "debuff_slot_" .. i,
			style = {
				font_size = debuff_font_size,
				font_type = font_settings.font_type or "proxima_nova_bold",
				horizontal_alignment = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				vertical_alignment = "center",
				text_color = { 0, 255, 255, 255 },
				offset = { 0, debuff_row_y, 7.5 },
				size = { math.floor(debuff_font_size * 1.6), math.max(14, debuff_font_size + 2) },
				drop_shadow = true,
			},
		})
	end

	table.insert(widget_passes, {
		pass_type = "rect",
		style_id = "health_indicator",
		value = "content/ui/materials/backgrounds/default_square",
		style = {
			vertical_alignment = "center",
			offset = { bar_offset[1], bar_offset[2], 4 },
			size = { 2, bar_size[2] + 2 },
			color = { 0, 255, 255, 255 },
		},
	})

	return UIWidget.create_definition(widget_passes, scenegraph_id)
end

template.on_enter = function(widget, marker, template)
	local content = widget.content
	content.spawn_progress_timer = 0
	local bar_settings = template.bar_settings
	marker.bar_logic = HudHealthBarLogic:new(bar_settings)
	
	-- NEW: Initialize damage tracking
	content.damage_taken = 0
	content.damage_numbers = {}
	
	if marker.unit then
		local success, color = pcall(mod.get_breed_color, marker.unit)
		if success and color and widget.style and widget.style.bar then
			widget.style.bar.color[1] = 255
			widget.style.bar.color[2] = color[1]
			widget.style.bar.color[3] = color[2]
			widget.style.bar.color[4] = color[3]
		end
		
		-- Store breed info for damage tracking
		local unit_data_extension = ScriptUnit.has_extension(marker.unit, "unit_data_system")
		if unit_data_extension then
			local breed = unit_data_extension:breed()
			content.breed = breed
			content.unit_data_extension = unit_data_extension
		end
	end
	
	if widget.content and marker.unit then
		local enemy_name = get_enemy_display_name(marker.unit)
		widget.content.name_text = enemy_name
	end
	
	if widget.style and widget.style.name_text and widget.style.name_text.color then
		widget.style.name_text.color[1] = show.show_enemy_names and 255 or 0
	end

	if widget.style and widget.style.name_background and widget.style.name_background.color then
		widget.style.name_background.color[1] = (show.name_background_enabled and (show.show_enemy_names or show.show_names_only)) and 110 or 0
	end

	local trim_visible = (show.name_background_enabled and (show.show_enemy_names or show.show_names_only)) and 255 or 0

	if widget.style and widget.style.name_plate_top then
		local trim_color = widget.style.name_plate_top.color
		trim_color[1] = trim_visible
	end

	if widget.style and widget.style.name_plate_bottom then
		local trim_color = widget.style.name_plate_bottom.color
		trim_color[1] = trim_visible
	end
	
	if widget.style and widget.style.tag_indicator and widget.style.tag_indicator.color then
		widget.style.tag_indicator.color[1] = 0
		widget.content.tag_indicator = ""
	end
	
	if widget.style and widget.style.tag_border then
		widget.style.tag_border.color[1] = 0
	end
	
	if widget.style and widget.style.border then
		widget.style.border.color[1] = 0
	end
	
	if widget.style and widget.style.health_indicator then
		widget.style.health_indicator.color[1] = 0
	end

	for i = 1, MAX_DEBUFF_SLOTS do
		local icon_style = widget.style and widget.style["debuff_icon_" .. i]
		if icon_style and icon_style.color then
			icon_style.color[1] = 0
		end

		local slot_style = widget.style and widget.style["debuff_slot_" .. i]
		if slot_style then
			local slot_color = slot_style.text_color or slot_style.color
			if slot_color then
				slot_color[1] = 0
			end
			widget.content["debuff_slot_" .. i] = ""
		end
	end
end

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	local content = widget.content
	local style = widget.style
	local unit = marker.unit
	local health_extension = ScriptUnit.has_extension(unit, "health_system")
	local health_percent = health_extension and health_extension:current_health_percent() or 0
	local bar_logic = marker.bar_logic
	local _, base_color = pcall(mod.get_breed_color, unit)
	if type(base_color) ~= "table" then
		base_color = nil
	end
	
	if show.hide_full_health and health_percent >= 1 then
		widget.alpha_multiplier = 0
		return
	end
	
	local names_only_mode = show.show_names_only
	if names_only_mode then
		if style.name_text and style.name_text.color then
			style.name_text.color[1] = 255
			if content and not content.name_text then
				content.name_text = get_enemy_display_name(unit)
			end
		end
		
		if style.bar then style.bar.color[1] = 0 end
		if style.background then style.background.color[1] = 0 end
		if style.border then style.border.color[1] = 0 end
		if style.health_indicator then style.health_indicator.color[1] = 0 end
		if style.bar_end_left then style.bar_end_left.color[1] = 0 end
		if style.bar_end_right then style.bar_end_right.color[1] = 0 end
		if style.icon_left then style.icon_left.color[1] = 0 end
		if style.icon_right then style.icon_right.color[1] = 0 end
		if style.threshold_75 then style.threshold_75.color[1] = 0 end
		if style.threshold_50 then style.threshold_50.color[1] = 0 end
		if style.threshold_25 then style.threshold_25.color[1] = 0 end
		for i = 1, 7 do
			local segment_style = style["segment_" .. i]
			if segment_style then segment_style.color[1] = 0 end
		end
		local names_only_plate_alpha = show.name_background_enabled and 110 or 0
		local names_only_trim_alpha = show.name_background_enabled and 200 or 0
		if style.name_background then style.name_background.color[1] = names_only_plate_alpha end
		if style.name_plate_top then
			style.name_plate_top.color[1] = names_only_trim_alpha
			style.name_plate_top.color[2] = 255
			style.name_plate_top.color[3] = 255
			style.name_plate_top.color[4] = 255
		end
		if style.name_plate_bottom then
			style.name_plate_bottom.color[1] = names_only_trim_alpha
			style.name_plate_bottom.color[2] = 255
			style.name_plate_bottom.color[3] = 255
			style.name_plate_bottom.color[4] = 255
		end
		
		local tag_type, tag_obj = get_unit_tag_info(unit)
		if style.tag_border then
			if show.show_tag_indicators and tag_type then
				local border_color = get_tag_border_color(tag_type)
				style.tag_border.color[1] = 255
				style.tag_border.color[2] = border_color[2]
				style.tag_border.color[3] = border_color[3]
				style.tag_border.color[4] = border_color[4]
			else
				style.tag_border.color[1] = 0
			end
		end
		
		if style.tag_indicator and style.tag_indicator.color and content then
			if show.show_tag_indicators and tag_type then
				if tag_type == "companion_order" then
					content.tag_indicator = "[DOG]"
					style.tag_indicator.color[1] = 255
					style.tag_indicator.color[2] = 255
					style.tag_indicator.color[3] = 255
					style.tag_indicator.color[4] = 0
				elseif tag_type == "veteran_tag" then
					content.tag_indicator = "[VET]"
					style.tag_indicator.color[1] = 255
					style.tag_indicator.color[2] = 255
					style.tag_indicator.color[3] = 255
					style.tag_indicator.color[4] = 0
				elseif tag_type == "enemy_tag" then
					content.tag_indicator = "[TAGGED]"
					style.tag_indicator.color[1] = 255
					style.tag_indicator.color[2] = 0
					style.tag_indicator.color[3] = 255
					style.tag_indicator.color[4] = 255
				end
			else
				content.tag_indicator = ""
				style.tag_indicator.color[1] = 0
			end
		end

		update_debuff_slots(style, content, unit, show.show_debuff_stacks)

		return
	end
	
	if not health_extension or not health_extension:is_alive() then
		marker.remove = true
		return
	end
	
	-- NEW: Damage tracking for stacked numbers
	if show.show_damage_numbers and health_extension then
		local breed = content.breed
		if breed then
			local max_health = Managers.state.difficulty:get_minion_max_health(breed.name)
			local damage_taken = health_extension:total_damage_taken()
			local old_damage_taken = content.damage_taken or 0
			
			if damage_taken and damage_taken ~= old_damage_taken and old_damage_taken < damage_taken then
				content.damage_taken = damage_taken
				
				local damage_diff = math.ceil(damage_taken - old_damage_taken)
				local damage_numbers = content.damage_numbers
				local latest_damage_number = damage_numbers[#damage_numbers]
				local should_add = true
				local was_critical = health_extension:was_hit_by_critical_hit_this_render_frame()
				
				-- Check if we should combine with latest number or create new one
				if latest_damage_number then
					local combine_time = show.damage_combine_time
					if combine_time > t - latest_damage_number.start_time then
						should_add = false
					end
				end
				
				if was_critical or should_add then
					-- Create new damage number
					local damage_number = {
						expand_time = 0,
						time = 0,
						start_time = t,
						duration = show.damage_duration,
						value = damage_diff,
						expand_duration = show.damage_expand_duration,
						was_critical = was_critical,
						hit_weakspot = false,
					}
					
					-- Check for weakspot hit
					local last_hit_zone = health_extension:last_hit_zone_name()
					if last_hit_zone and breed.hit_zone_weakspot_types then
						if breed.hit_zone_weakspot_types[last_hit_zone] then
							damage_number.hit_weakspot = true
						end
					end
					
					damage_numbers[#damage_numbers + 1] = damage_number
				else
					-- Combine with existing number
					latest_damage_number.value = latest_damage_number.value + damage_diff
					latest_damage_number.time = 0
					latest_damage_number.start_time = t
					
					if was_critical then
						latest_damage_number.was_critical = true
					end
				end
			end
		end
	end

	bar_logic:update(dt, t, health_percent)
	local health_fraction, health_ghost_fraction, health_max_fraction = bar_logic:animated_health_fractions()

	if health_fraction and style.bar then
		local base_size = show.healthbar_width
		local default_width_offset = -base_size * 0.5
		
		health_fraction = math.max(0, math.min(1, health_fraction or 0))
		
		local health_width = health_fraction * base_size
		health_width = math.max(0, math.min(base_size, health_width))

		style.bar.size[1] = health_width
		style.bar.offset[1] = default_width_offset

		if show.bar_corner_style == "industrial" and style.bar.uvs then
			-- Crop the segmented texture instead of stretching it, matching the
			-- vanilla boss bar's own uvs[2][1]-as-fraction convention.
			style.bar.uvs[2][1] = health_fraction
		end

		if style.background then
			style.background.size[1] = base_size
			style.background.offset[1] = default_width_offset
			style.background.color[1] = 180
		end

		if marker.unit then
			if base_color then
				local gradient_intensity = show.gradient_intensity
				local final_color = get_health_gradient_color(health_percent, base_color, gradient_intensity)
				
				style.bar.color[1] = 255
				style.bar.color[2] = final_color[1]
				style.bar.color[3] = final_color[2]
				style.bar.color[4] = final_color[3]
				
				if style.bar_end_left then
					style.bar_end_left.color[1] = 255
					style.bar_end_left.color[2] = final_color[1]
					style.bar_end_left.color[3] = final_color[2]
					style.bar_end_left.color[4] = final_color[3]
				end
				
				if style.bar_end_right then
					style.bar_end_right.color[1] = 255
					style.bar_end_right.color[2] = final_color[1]
					style.bar_end_right.color[3] = final_color[2]
					style.bar_end_right.color[4] = final_color[3]
				end

				-- Subtle pulsing red overlay when critically low, per the mockup's
				-- "Critical: Pulsing Red (subtle)" health state.
				if health_percent < 0.25 then
					local pulse = 0.6 + 0.4 * math.sin(t * 6)
					style.bar.color[2] = math.floor(final_color[1] + (255 - final_color[1]) * pulse * 0.5)
					style.bar.color[3] = math.floor(final_color[2] * (1 - pulse * 0.3))
					style.bar.color[4] = math.floor(final_color[3] * (1 - pulse * 0.3))
				end
			end
		end
	end
	
	-- Visibility check implementation
	local line_of_sight_progress = content.line_of_sight_progress or 0
	
	if show.enable_visibility_check then
		if marker.raycast_initialized then
			local raycast_result = marker.raycast_result
			local visibility_speed = show.visibility_fade_speed
			
			if raycast_result then
				line_of_sight_progress = math.max(line_of_sight_progress - dt * visibility_speed, 0)
			else
				line_of_sight_progress = math.min(line_of_sight_progress + dt * visibility_speed, 1)
			end
		end
		
		content.line_of_sight_progress = line_of_sight_progress
		
		if not show.visibility_behind_walls then
			widget.alpha_multiplier = line_of_sight_progress
		else
			widget.alpha_multiplier = math.max(line_of_sight_progress, 0.1)
		end
	else
		widget.alpha_multiplier = 1.0
		content.line_of_sight_progress = 1.0
	end
	
	if style.border then
		if show.bar_border_enabled then
			-- Tinted rim (a dim, darkened version of the breed color) instead of a flat
			-- black outline, so the frame reads as "this enemy's color" at a glance.
			local rim_r, rim_g, rim_b = 0, 0, 0
			if base_color then
				rim_r = math.floor((base_color[1] or 0) * 0.3)
				rim_g = math.floor((base_color[2] or 0) * 0.3)
				rim_b = math.floor((base_color[3] or 0) * 0.3)
			end

			style.border.color[1] = 255
			style.border.color[2] = rim_r
			style.border.color[3] = rim_g
			style.border.color[4] = rim_b
		else
			style.border.color[1] = 0
		end
	end
	
	if style.name_text and style.name_text.color then
		if show.show_enemy_names or show.show_names_only then
			style.name_text.color[1] = 255
			style.name_text.color[2] = show.enemy_name_color_r
			style.name_text.color[3] = show.enemy_name_color_g
			style.name_text.color[4] = show.enemy_name_color_b
			if content and not content.name_text then
				content.name_text = get_enemy_display_name(unit)
			end
		else
			style.name_text.color[1] = 0
		end
	end

	if style.name_background then
		style.name_background.color[1] = (show.name_background_enabled and (show.show_enemy_names or show.show_names_only)) and 110 or 0
	end

	if style.name_plate_top or style.name_plate_bottom then
		local names_visible = show.name_background_enabled and (show.show_enemy_names or show.show_names_only)
		local trim_r, trim_g, trim_b = 255, 255, 255

		if base_color then
			trim_r = base_color[1] or 255
			trim_g = base_color[2] or 255
			trim_b = base_color[3] or 255
		end

		if style.name_plate_top then
			style.name_plate_top.color[1] = names_visible and 200 or 0
			style.name_plate_top.color[2] = trim_r
			style.name_plate_top.color[3] = trim_g
			style.name_plate_top.color[4] = trim_b
		end

		if style.name_plate_bottom then
			style.name_plate_bottom.color[1] = names_visible and 200 or 0
			style.name_plate_bottom.color[2] = trim_r
			style.name_plate_bottom.color[3] = trim_g
			style.name_plate_bottom.color[4] = trim_b
		end
	end
	
	local tag_type, tag_obj = get_unit_tag_info(unit)
	
	if style.tag_border then
		if show.show_tag_indicators and tag_type then
			local border_color = get_tag_border_color(tag_type)
			style.tag_border.color[1] = 255
			style.tag_border.color[2] = border_color[2]
			style.tag_border.color[3] = border_color[3]
			style.tag_border.color[4] = border_color[4]
		else
			style.tag_border.color[1] = 0
		end
	end
	
	if style.tag_indicator and style.tag_indicator.color and content then
		if show.show_tag_indicators then
			if tag_type then
				if tag_type == "companion_order" then
					content.tag_indicator = "[DOG]"
					style.tag_indicator.color[1] = 255
					style.tag_indicator.color[2] = 255
					style.tag_indicator.color[3] = 255
					style.tag_indicator.color[4] = 0
				elseif tag_type == "veteran_tag" then
					content.tag_indicator = "[VET]"
					style.tag_indicator.color[1] = 255
					style.tag_indicator.color[2] = 255
					style.tag_indicator.color[3] = 255
					style.tag_indicator.color[4] = 0
				elseif tag_type == "enemy_tag" then
					content.tag_indicator = "[TAGGED]"
					style.tag_indicator.color[1] = 255
					style.tag_indicator.color[2] = 0
					style.tag_indicator.color[3] = 255
					style.tag_indicator.color[4] = 255
				end
			else
				content.tag_indicator = ""
				style.tag_indicator.color[1] = 0
			end
		else
			content.tag_indicator = ""
			style.tag_indicator.color[1] = 0
		end
	end
	
	if style.health_indicator and health_fraction then
		if show.show_health_indicator then
			local base_size = show.healthbar_width
			local default_width_offset = -base_size * 0.5
			local health_width = health_fraction * base_size
			local indicator_x_pos = default_width_offset + health_width - 1
			
			style.health_indicator.color[1] = 255
			style.health_indicator.color[2] = 255
			style.health_indicator.color[3] = 255
			style.health_indicator.color[4] = 255
			style.health_indicator.offset[1] = indicator_x_pos
		else
			style.health_indicator.color[1] = 0
		end
	end

	update_debuff_slots(style, content, unit, show.show_debuff_stacks)
end

-- ===== INITIALIZE =====
get_toggles()

-- ===== SETTINGS HANDLER =====

mod.on_setting_changed = function()
	get_toggles()
	
	template.size = { show.healthbar_width, show.healthbar_height }
	template.position_offset = { 0, 0, 0.35 + (show.bar_offset_y / 100) }
	
	template.check_line_of_sight = show.enable_visibility_check
	
	local max_distance = show.always_show_healthbars and math.max(show.max_display_range, 100) or show.max_display_range
	template.max_distance = max_distance
	template.fade_settings.distance_max = max_distance
	template.fade_settings.distance_min = max_distance * 0.5
	
	if show.smooth_animations then
		template.bar_settings.alpha_fade_delay = show.always_show_healthbars and 10.0 or 2.6
		template.bar_settings.alpha_fade_duration = 0.6
		template.bar_settings.alpha_fade_min_value = show.always_show_healthbars and 200 or 50
		template.fade_settings.default_fade = show.always_show_healthbars and 1 or 0
	else
		template.bar_settings.alpha_fade_delay = 0.1
		template.bar_settings.alpha_fade_duration = 0.1
		template.bar_settings.alpha_fade_min_value = show.always_show_healthbars and 255 or 100
		template.fade_settings.default_fade = show.always_show_healthbars and 1 or 0
	end
end

mod:hook_safe("HudElementWorldMarkers", "init", function(self)
	self._marker_templates[template.name] = template
end)

-- Enforce "max_healthbars_shown": after the engine has computed visibility/distance for
-- this frame's markers, hide the lowest-priority/farthest ones beyond the configured cap.
mod:hook_safe("HudElementWorldMarkers", "_calculate_markers", function(self)
	local markers_by_type = self._markers_by_type
	local our_markers = markers_by_type and markers_by_type[template.name]

	if not our_markers then return end

	table.clear(temp_marker_priority_list)

	for i = 1, #our_markers do
		local marker = our_markers[i]

		if marker.update and marker.draw then
			temp_marker_priority_list[#temp_marker_priority_list + 1] = {
				marker = marker,
				tier = show.priority_system and get_priority_tier(marker.unit) or 0,
			}
		end
	end

	local max_shown = show.max_healthbars_shown or 8
	local num_visible = #temp_marker_priority_list

	if num_visible <= max_shown then return end

	table.sort(temp_marker_priority_list, priority_sort_func)

	for i = max_shown + 1, num_visible do
		temp_marker_priority_list[i].marker.draw = false
	end
end)

mod:hook_safe("HealthExtension", "init", function(_self, _extension_init_context, unit, _extension_init_data, _game_object_data)
	if should_enable_healthbar(unit) then
		Managers.event:trigger("add_world_marker_unit", template.name, unit)
	end
end)

mod:hook_safe("HuskHealthExtension", "init", function(self, _extension_init_context, unit, _extension_init_data, _game_session, _game_object_id, _owner_id)
	local HealthExtension = get_health_extension_class()

	if HealthExtension then
		self.set_last_damaging_unit = HealthExtension.set_last_damaging_unit
		self.last_damaging_unit = HealthExtension.last_damaging_unit
		self.last_hit_zone_name = HealthExtension.last_hit_zone_name
		self.last_hit_was_critical = HealthExtension.last_hit_was_critical
		self.was_hit_by_critical_hit_this_render_frame = HealthExtension.was_hit_by_critical_hit_this_render_frame
	end

	if should_enable_healthbar(unit) then
		Managers.event:trigger("add_world_marker_unit", template.name, unit)
	end
end)

-- ===== SCAN FOR EXISTING UNITS ON JOIN =====

local scan_timer = 0
local scan_interval = 1.0
local initial_scan_done = false
local max_initial_scans = 10

local function scan_existing_units()
	local added_count = 0
	
	if not Managers.state or not Managers.state.minion_spawn then
		return 0
	end
	
	local spawned_minions = Managers.state.minion_spawn:spawned_minions()
	if not spawned_minions then
		return 0
	end
	
	for i = 1, #spawned_minions do
		local unit = spawned_minions[i]
		if unit and HEALTH_ALIVE[unit] then
			if should_enable_healthbar(unit) then
				local success = pcall(function()
					Managers.event:trigger("add_world_marker_unit", template.name, unit)
				end)
				
				if success then
					added_count = added_count + 1
				end
			end
		end
	end
	
	return added_count
end

-- ===== COMMANDS =====

mod:command("cc_test", "Test color coded healthbars", function()
	mod:echo("Color Coded Healthbars (with Stacked Damage Numbers) loaded!")
	mod:echo("Show enemy names: " .. tostring(show.show_enemy_names))
	mod:echo("Show damage numbers: " .. tostring(show.show_damage_numbers))
	mod:echo("Show tag indicators: " .. tostring(show.show_tag_indicators))
	mod:echo("Show health indicator: " .. tostring(show.show_health_indicator))
	
	mod:echo("Visibility Settings:")
	mod:echo("  Enable visibility check: " .. tostring(show.enable_visibility_check))
	mod:echo("  Visibility fade speed: " .. show.visibility_fade_speed)
	mod:echo("  Show behind walls: " .. tostring(show.visibility_behind_walls))
	
	mod:echo("Visual Settings:")
	mod:echo("  Bar size: " .. show.healthbar_width .. "x" .. show.healthbar_height .. " pixels")
	mod:echo("  Text size: " .. show.text_size .. " pixels")
	mod:echo("  Text offset: " .. show.text_offset_y .. " pixels")
	mod:echo("  Bar Y offset: " .. show.bar_offset_y .. " pixels")
	
	mod:echo("Damage Number Settings:")
	mod:echo("  Font size: " .. show.damage_font_size)
	mod:echo("  Y offset: " .. show.damage_y_offset)
	mod:echo("  Combine time: " .. show.damage_combine_time)
end)

mod:command("cc_scan", "Scan for existing units and add healthbars", function()
	mod:echo("=== Manual Scan Starting ===")
	local added = scan_existing_units()
	mod:echo("=== Manual Scan Complete ===")
	if added > 0 then
		mod:echo("Added healthbars to " .. added .. " existing enemies")
	else
		mod:echo("No new enemies found or all enemies already have healthbars")
	end
end)

local keybind_pressed_last_frame = false

mod:hook_safe("HudElementWorldMarkers", "update", function(self, dt, t, ui_renderer, render_settings, input_service)
	if not initial_scan_done then
		scan_timer = scan_timer + dt
		
		if scan_timer >= scan_interval then
			scan_timer = 0
			
			local added = scan_existing_units()
			
			max_initial_scans = max_initial_scans - 1
			
			if added > 0 then
				initial_scan_done = true
				if added > 0 then
					mod:echo("Found " .. added .. " existing enemies and added healthbars")
				end
			elseif max_initial_scans <= 0 then
				initial_scan_done = true
			end
		end
	end
	
	if input_service then
		local keybind_setting = mod:get("refresh_keybind")
		if keybind_setting and keybind_setting.key then
			local key_pressed = input_service:get(keybind_setting.key)
			
			if key_pressed and not keybind_pressed_last_frame then
				local success = pcall(function()
					mod:echo("=== Manual Refresh (Keybind) ===")
					local added = scan_existing_units()
					if added > 0 then
						mod:echo("Refreshed " .. added .. " healthbars")
					else
						mod:echo("All healthbars up to date")
					end
				end)
				if not success then
					mod:echo("Error during manual refresh")
				end
			end
			
			keybind_pressed_last_frame = key_pressed
		end
	end
end)

if mod:get("show_startup_messages") then
	mod:echo("Color Coded Healthbars (with Stacked Damage Numbers) loaded!")
	mod:echo("NEW: Stacked damage numbers like MoarDots - enable in settings!")
	mod:echo("Type /cc_test to check mod status")
end