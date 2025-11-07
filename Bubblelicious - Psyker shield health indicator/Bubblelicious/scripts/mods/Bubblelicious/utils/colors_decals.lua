local mod = get_mod("Bubblelicious")

-----------------------------------------------------------------------------------------------------------------
-- Color definitions & functions --------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local lerp = math.lerp
local newColor = Color

mod.colors = {
	mango 	= { 255, 253, 190, 002 },
	tint4	= { 200, 060, 078, 057 },
	startc	= { 255, 000, 255, 000 },
	midc	= { 255, 255, 255, 000 },
	endc	= { 255, 255, 000, 000 },
	fstartc	= { 255, 000, 255, 000 },
	fmidc	= { 255, 255, 255, 000 },
	fendc	= { 255, 255, 000, 000 },
	noshift = { 255, 253, 190, 002 },
}

mod.colors.set_progress_colors = function()
	local colors = mod.colors
	local settings = mod.settings

	if settings.custom_colors_enabled then
		colors.fstartc, colors.fmidc, colors.fendc = settings.start_color, settings.mid_color, settings.end_color
		colors.noshift = colors.fstartc
	else
		colors.fstartc, colors.fmidc, colors.fendc = colors.startc, colors.midc, colors.endc
		colors.noshift = colors.mango
	end
end

mod.colors.lerp = function(color, origin, target, step)
	color[2] = lerp(origin[2], target[2], step)
	color[3] = lerp(origin[3], target[3], step)
	color[4] = lerp(origin[4], target[4], step)
end

mod.colors.manage_colors = function(bubble)
	local hp = 1 - bubble.current_hp --reverse direction
	local colors, step = mod.colors, 0

	if hp <= 0.5 then
		step = hp / 0.5
		colors.lerp(bubble.color, colors.fstartc, colors.fmidc, step)
	else
		step = (hp - 0.5) / 0.5
		colors.lerp(bubble.color, colors.fmidc, colors.fendc, step)
	end
end

-----------------------------------------------------------------------------------------------------------------
-- Shield Color & Decal functions -------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

mod.decal = {}
local diameter = 12.35 --bubble (decal) diameter
local package_name = "content/levels/training_grounds/missions/mission_tg_basic_combat_01"
local decal_unit_name = "content/levels/training_grounds/fx/decal_aoe_indicator"
local set_unit_local_scale = Unit.set_local_scale
local set_vec4_for_material = Unit.set_vector4_for_material
local set_vec4_for_materials = Unit.set_vector4_for_materials

mod.decal.destroy = function(bubble)
	local world = Unit.world(bubble.unit)
	local decal = bubble.decal

  	if decal then
		World.destroy_unit(world, decal)
		bubble.decal = nil
	end
end

mod.decal.destroy_all = function(bubble_table)
	for _, bubble in pairs(bubble_table) do
		mod.decal.destroy(bubble)
	end
end

mod.decal.set_color = function(bubble)
	local decal, color = bubble.decal, bubble.color
	if not decal and bubble.is_bubble then return end

	local normalized_color = newColor(color[2] / 255, color[3] / 255, color[4] / 255, color[1])

	if bubble.is_bubble then
		set_vec4_for_material(decal, "projector", "particle_color", normalized_color, false)
	else
		set_vec4_for_materials(bubble.unit, "particle_color", normalized_color, true)
	end
end

mod.decal.resize = function(bubble, decal, multiplier)
	local pulsed_size = diameter * multiplier

	bubble.decal_size:store(pulsed_size, pulsed_size, 1)
	set_unit_local_scale(decal, 1, bubble.decal_size:unbox())
end

mod.decal.create = function(bubble)
	local world = Unit.world(bubble.unit)
	local position = Unit.local_position(bubble.unit, 1)
	local decal = World.spawn_unit_ex(world, decal_unit_name, nil, position)

	bubble.decal_size = Vector3Box(Vector3(diameter, diameter, 1))
	set_unit_local_scale(decal, 1, bubble.decal_size:unbox())

	Unit.set_scalar_for_material(decal, "projector", "color_multiplier", 0.075)
	bubble.decal = decal
end

mod.decal.initialize = function(bubble, dont_load_package)
	if not Unit.is_valid(bubble.unit) then return end

	if not Managers.package:has_loaded(package_name) and not dont_load_package then
		Managers.package:load(package_name, "Bubblelicious", function()
			mod.decal.initialize(bubble, true)
		end)

		return
	end

	mod.decal.create(bubble)
end