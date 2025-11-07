-- Color Coded Healthbars
-- Description: Show color-coded healthbars based on enemy breed type
-- Author: Custom Mod
local mod = get_mod("ColorCodedHealthbars")
local Breeds = require("scripts/settings/breed/breeds")
local HealthExtension = require("scripts/extension_systems/health/health_extension")

-- Color definitions for different breed types
mod.breed_colors = {
	horde = { 150, 150, 150 },      -- Gray for horde enemies
	roamer = { 180, 180, 180 },     -- Light gray for roamers
	elite = { 255, 165, 0 },        -- Orange for elites
	special = { 255, 0, 255 },      -- Magenta for specials
	monster = { 255, 0, 0 },        -- Red for monsters
	captain = { 128, 0, 128 },      -- Purple for captains
	default = { 255, 255, 255 }     -- White for unknown types
}

-- Function to update colors from settings
local function update_colors_from_settings()
	mod.breed_colors.horde = { 
		mod:get("horde_color_r") or 150, 
		mod:get("horde_color_g") or 150, 
		mod:get("horde_color_b") or 150 
	}
	mod.breed_colors.elite = { 
		mod:get("elite_color_r") or 255, 
		mod:get("elite_color_g") or 165, 
		mod:get("elite_color_b") or 0 
	}
	mod.breed_colors.special = { 
		mod:get("special_color_r") or 255, 
		mod:get("special_color_g") or 0, 
		mod:get("special_color_b") or 255 
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
		math.floor((mod:get("monster_color_r") or 255) / 2), 
		0, 
		math.floor((mod:get("monster_color_r") or 255) / 2) 
	}
end

local show = {}

local function get_toggles()
	for breed_name in pairs(Breeds) do
		show[breed_name] = mod:get(breed_name)
	end
	
	-- Get general breed type toggles
	show.show_horde = mod:get("show_horde")
	show.show_roamer = mod:get("show_roamer")
	show.show_elite = mod:get("show_elite")
	show.show_special = mod:get("show_special")
	show.show_monster = mod:get("show_monster")
	show.show_captain = mod:get("show_captain")
	
	-- Update colors from settings
	update_colors_from_settings()
end

get_toggles()

mod.on_setting_changed = function()
	get_toggles()
end

-- Function to determine breed type and get appropriate color
local function get_breed_type_and_color(breed)
	if not breed or not breed.tags then
		return "default", mod.breed_colors.default
	end
	
	local tags = breed.tags
	
	if tags.monster then
		return "monster", mod.breed_colors.monster
	elseif tags.captain then
		return "captain", mod.breed_colors.captain
	elseif tags.elite then
		return "elite", mod.breed_colors.elite
	elseif tags.special then
		return "special", mod.breed_colors.special
	elseif tags.horde then
		return "horde", mod.breed_colors.horde
	elseif tags.roamer then
		return "roamer", mod.breed_colors.roamer
	else
		return "default", mod.breed_colors.default
	end
end

local function should_enable_healthbar(unit)
	local game_mode_name = Managers.state.game_mode:game_mode_name()
	if game_mode_name == "shooting_range" and not get_mod("creature_spawner") then
		return false
	end

	local unit_data_extension = ScriptUnit.extension(unit, "unit_data_system")
	local breed = unit_data_extension:breed()

	-- Check if this specific breed is enabled
	if show[breed.name] then
		return true
	end
	
	-- Check if the breed type category is enabled
	local breed_type, _ = get_breed_type_and_color(breed)
	if show["show_" .. breed_type] then
		return true
	end

	return false
end

-- Function to get the healthbar color for a unit
function mod.get_healthbar_color(unit)
	if not unit or not HEALTH_ALIVE[unit] then
		return mod.breed_colors.default
	end
	
	local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
	if not unit_data_extension then
		return mod.breed_colors.default
	end
	
	local breed = unit_data_extension:breed()
	local _, color = get_breed_type_and_color(breed)
	return color
end

-- Hook to enable healthbars for units that should have them
mod:hook_safe("HealthExtension", "init", function(_self, _extension_init_context, unit, _extension_init_data, _game_object_data)
	if should_enable_healthbar(unit) then
		-- Use the existing healthbar marker from the base game instead of custom one
		Managers.event:trigger("add_world_marker_unit", "enemy_health", unit)
	end
end)

mod:hook_safe("HuskHealthExtension", "init", function(self, _extension_init_context, unit, _extension_init_data, _game_session, _game_object_id, _owner_id)
	-- Make sure husks have the methods needed
	self.set_last_damaging_unit = HealthExtension.set_last_damaging_unit
	self.last_damaging_unit = HealthExtension.last_damaging_unit
	self.last_hit_zone_name = HealthExtension.last_hit_zone_name
	self.last_hit_was_critical = HealthExtension.last_hit_was_critical
	self.was_hit_by_critical_hit_this_render_frame = HealthExtension.was_hit_by_critical_hit_this_render_frame

	if should_enable_healthbar(unit) then
		Managers.event:trigger("add_world_marker_unit", "enemy_health", unit)
	end
end)

-- Hook to modify existing healthbar colors
mod:hook("HudElementWorldMarkers", "_update_marker_widget", function(func, self, marker, dt, t, ui_renderer)
	local result = func(self, marker, dt, t, ui_renderer)
	
	-- Apply our custom colors to enemy health markers
	if marker.template and marker.template.name == "enemy_health" then
		local unit = marker.unit
		if unit and HEALTH_ALIVE[unit] then
			local color = mod.get_healthbar_color(unit)
			if color and marker.widget and marker.widget.style then
				-- Try to find and modify the health bar color
				for style_name, style in pairs(marker.widget.style) do
					if style_name == "health" or style_name == "health_bar" then
						if style.color then
							style.color[2] = color[1] / 255 -- R (normalized)
							style.color[3] = color[2] / 255 -- G (normalized)
							style.color[4] = color[3] / 255 -- B (normalized)
						end
					end
				end
			end
		end
	end
	
	return result
end)

-- Debug function to check if mod is working
mod:command("cc_healthbars_test", "Test color coded healthbars", function()
	mod:echo("Color Coded Healthbars mod is loaded!")
	mod:echo("Current colors:")
	for breed_type, color in pairs(mod.breed_colors) do
		mod:echo(breed_type .. ": " .. table.concat(color, ", "))
	end
end)