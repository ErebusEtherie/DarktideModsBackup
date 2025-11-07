-- Look whos snooping where they dont belong
local mod = get_mod("ColorCodedHealthbars")

-- Check if required modules are available
local Breeds = require("scripts/settings/breed/breeds")
local HealthExtension = require("scripts/extension_systems/health/health_extension")
local HuskHealthExtension = require("scripts/extension_systems/health/husk_health_extension")
local HudHealthBarLogic = require("scripts/ui/hud/elements/hud_health_bar_logic")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")

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
	healthbar_width = 120,
	healthbar_height = 6,
	text_size = 20,
	text_offset_y = 8,
	bar_offset_y = 0,
	-- Visual enhancement settings
	bar_border_enabled = true,
	bar_border_thickness = 1,
	background_opacity = 180,
	bar_corner_style = "standard",
	text_shadow_enabled = true,
	text_outline_enabled = false,
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
		if breed_name == "renegade_gunner" or breed_name == "renegade_shocktrooper" or 
		   breed_name == "cultist_gunner" or breed_name == "chaos_ogryn_gunner" or
		   breed_name == "cultist_shocktrooper" then
			return mod.breed_colors.elite_ranged
		else
			return mod.breed_colors.elite_melee
		end
	elseif tags.special then
		if breed_name == "renegade_sniper" then
			return mod.breed_colors.special_sniper
		elseif breed_name == "chaos_hound" then
			return mod.breed_colors.special_pox_hound
		elseif breed_name == "renegade_netgunner" then
			return mod.breed_colors.special_trapper
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

-- ===== TEMPLATE SETUP =====

local template = {}
local function get_current_size()
	return { 
		mod:get("healthbar_width") or 120, 
		mod:get("healthbar_height") or 6 
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
	show.healthbar_width = get_setting_num("healthbar_width", 120)
	show.healthbar_height = get_setting_num("healthbar_height", 6)
	show.text_size = get_setting_num("text_size", 20)
	show.text_offset_y = get_setting_num("text_offset_y", 8)
	show.bar_offset_y = get_setting_num("bar_offset_y", 0)
	show.bar_border_thickness = get_setting_num("bar_border_thickness", 1)
	show.background_opacity = get_setting_num("background_opacity", 180)
	show.gradient_intensity = get_setting_num("gradient_intensity", 75)
	
	show.bar_border_enabled = get_setting_bool("bar_border_enabled", true)
	show.text_shadow_enabled = get_setting_bool("text_shadow_enabled", true)
	show.text_outline_enabled = get_setting_bool("text_outline_enabled", false)
	show.health_gradient = get_setting_bool("health_gradient", true)
	show.smooth_animations = get_setting_bool("smooth_animations", true)
	
	show.bar_corner_style = get_setting_str("bar_corner_style", "standard")
	
	-- Damage number settings (NEW)
	show.damage_font_size = get_setting_num("damage_font_size", 17)
	show.damage_y_offset = get_setting_num("damage_y_offset", 15)
	show.damage_combine_time = get_setting_num("damage_combine_time", 0.2)
	show.damage_duration = get_setting_num("damage_duration", 3)
	show.damage_fade_delay = get_setting_num("damage_fade_delay", 2)
	show.damage_expand_duration = get_setting_num("damage_expand_duration", 0.2)
	show.damage_shrink_duration = get_setting_num("damage_shrink_duration", 1)
	show.damage_crit_scale = get_setting_num("damage_crit_scale", 1.5)
	
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
		text_horizontal_alignment = "center",
		text_vertical_alignment = "bottom",
		vertical_alignment = "center",
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
	
	local bar_material = "content/ui/materials/backgrounds/default_square"
	if bar_style == "capped" then
		bar_material = "content/ui/materials/bars/simple/fill"
	end
	
	table.insert(widget_passes, {
		pass_type = "rect",
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
end

template.update_function = function(parent, ui_renderer, widget, marker, template, dt, t)
	local content = widget.content
	local style = widget.style
	local unit = marker.unit
	local health_extension = ScriptUnit.has_extension(unit, "health_system")
	local health_percent = health_extension and health_extension:current_health_percent() or 0
	local bar_logic = marker.bar_logic
	
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

		if style.background then
			style.background.size[1] = base_size
			style.background.offset[1] = default_width_offset
			style.background.color[1] = 180
		end

		if marker.unit then
			local success, base_color = pcall(mod.get_breed_color, marker.unit)
			if success and base_color then
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
			style.border.color[1] = 255
			style.border.color[2] = 0
			style.border.color[3] = 0
			style.border.color[4] = 0
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

mod:hook_safe("HealthExtension", "init", function(_self, _extension_init_context, unit, _extension_init_data, _game_object_data)
	if should_enable_healthbar(unit) then
		Managers.event:trigger("add_world_marker_unit", template.name, unit)
	end
end)

mod:hook_safe("HuskHealthExtension", "init", function(self, _extension_init_context, unit, _extension_init_data, _game_session, _game_object_id, _owner_id)
	self.set_last_damaging_unit = HealthExtension.set_last_damaging_unit
	self.last_damaging_unit = HealthExtension.last_damaging_unit
	self.last_hit_zone_name = HealthExtension.last_hit_zone_name
	self.last_hit_was_critical = HealthExtension.last_hit_was_critical
	self.was_hit_by_critical_hit_this_render_frame = HealthExtension.was_hit_by_critical_hit_this_render_frame

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