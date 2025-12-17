local mod = get_mod("StimmSupplyRings")
local decals = mod:persistent_table("stimm_supply_decals")
local stimm_supply_config = require("scripts/settings/deployables/templates/broker_stimm_field_crate")
local decal_unit_name = "content/levels/training_grounds/fx/decal_aoe_indicator"
local package_name = "content/levels/training_grounds/missions/mission_tg_basic_combat_01"

local MAX_W = 0.5
local MAX_INVESTMENT = 5

local function maybe_echo(...)
    if mod:get("enable_logging") then
       mod:echo_localized(...)
    end
end

local function is_stimm_ready(player)
	if not player or not player:unit_is_alive() then
		maybe_echo("owner_not_alive")
		return false
	end


	local player_unit = player.player_unit
	local player_name = player:name()
	if not player_unit then
		maybe_echo("missing_player_unit", player_name)
		return false
	end

	local ability_extension = ScriptUnit.has_extension(player_unit, "ability_system")
	if not ability_extension then
		maybe_echo("missing_ability_system", player_name)
		return false
	end

	local equipped_abilities = ability_extension:equipped_abilities()
	local pocketable_ability = equipped_abilities and equipped_abilities["pocketable_ability"]
	local has_broker_syringe = pocketable_ability and pocketable_ability.ability_group == "broker_syringe"

	if not has_broker_syringe then
		maybe_echo("missing_cartel_stimm", player_name)
		return false
	end

	local remaining_cooldown = ability_extension:remaining_ability_cooldown("pocketable_ability")
	local has_cooldown = remaining_cooldown and remaining_cooldown >= 0.05

	if has_cooldown then
		maybe_echo("stimm_on_cooldown", player_name, remaining_cooldown)
		return false
	end

	local buff_extension = ScriptUnit.has_extension(player_unit, "buff_system")
	if not buff_extension then
		maybe_echo("missing_buff_extension", player_name)
		return false
	end

	local function get_remaining_buff_time(buff_ext, template_name)
		local buffs = buff_ext._buffs_by_index
		if not buffs then
			return 0
		end

		local max_remaining = 0

		for _, buff in pairs(buffs) do
			local template = buff:template()
			if template and template.name == template_name then
				local remaining = buff:duration_progress() or 1
				local duration = buff:duration() or 15
				max_remaining = math.max(max_remaining, duration * remaining)
			end
		end

		return max_remaining
	end

	local active_buff_time = get_remaining_buff_time(buff_extension, "syringe_broker_buff")
	local has_active_buff = active_buff_time >= 0.05

	if has_active_buff then
		maybe_echo("personal_stimm_active", player_name, active_buff_time)
		return false
	end

	return true
end

local function update_talent_category_counts(talent_name, talent_category_counts)
	for prefix, current_count in pairs(talent_category_counts) do
		if string.sub(talent_name, 1, #prefix) == prefix then
			talent_category_counts[prefix] = current_count + 1
			return
		end
	end
end

local function unit_spawned(unit, dont_load_package)
	if not Managers.package:has_loaded(package_name) and not dont_load_package then
		Managers.package:load(package_name, "StimmSupplyRings", function()
			unit_spawned(unit, true)
		end)
		return
	end

	if not unit then
		return
	end

	local player = Managers.state.player_unit_spawn:owner(unit)
	if not player or not is_stimm_ready(player) then
		return
	end

	local profile = player:profile()
	if not profile or not profile.talents then
		return
	end

	-- Count Stimm Lab investment in these three lines
	local talent_category_counts = {}
	if mod:get("show_cooldown") then
		talent_category_counts["broker_stimm_concentration"] = 0
	end
	if mod:get("show_attack_speed") then
		talent_category_counts["broker_stimm_celerity"] = 0
	end
	if mod:get("show_strength") then
		talent_category_counts["broker_stimm_combat"] = 0
	end
	if mod:get("show_toughness") then
		talent_category_counts["broker_stimm_durability"] = 0
	end


	for talent, active in pairs(profile.talents) do
		if active then
			update_talent_category_counts(talent, talent_category_counts)
		end
	end

	-- Create colors for each investment meeting minimum threshold with w scaled based on investment
	local color_map = {
		["broker_stimm_concentration"] = {1, 1, 0},
		["broker_stimm_celerity"] = {0, 0, 1},
		["broker_stimm_combat"] = {1,0,0},
		["broker_stimm_durability"] = {200/255, 0, 1},
	}
	local ring_colors = {}
	for talent_category, talent_count in pairs(talent_category_counts) do
		if talent_count >= mod:get("min_investment") then
			local material_value = Quaternion.identity()
			local rgb = color_map[talent_category]
			local r, g, b = unpack(rgb)
			local w = math.pow(talent_count / MAX_INVESTMENT, mod:get("opacity_scaling_power")) * MAX_W
			Quaternion.set_xyzw(material_value, r, g, b, w)
			ring_colors[#ring_colors + 1] = material_value
		end
	end

	-- Sort rings in descending order by w value (brightness)
	table.sort(ring_colors, function(a, b)
		local _, _, _, w_a = Quaternion.to_elements(a)
		local _, _, _, w_b = Quaternion.to_elements(b)
		return w_a > w_b
	end)

	-- Place ring decals around/within stimm supply deployable unit
	local world = Unit.world(unit)
	local position = Unit.local_position(unit, 1)

	local unit_decals = {}
	for idx, material_value in pairs(ring_colors) do
		-- Create decal unit
		local decal_unit = World.spawn_unit_ex(world, decal_unit_name, nil, position + Vector3(0, 0, 0.1))

		-- Set size of unit
		local diameter = stimm_supply_config.proximity_radius * 2 + 1.5 - 1 * (idx - 1)
		Unit.set_local_scale(decal_unit, 1, Vector3(diameter, diameter, 1))

		-- Set color of unit
		Unit.set_vector4_for_material(decal_unit, "projector", "particle_color", material_value, true)

		-- Set opacity based on W
		local _, _, _, w = Quaternion.to_elements(material_value)
		local opacity = math.lerp(mod:get("min_opacity") / 100, mod:get("max_opacity") / 100, w / MAX_W)
		Unit.set_scalar_for_material(decal_unit, "projector", "color_multiplier", opacity)

		unit_decals[#unit_decals + 1] = decal_unit
	end

	decals[unit] = unit_decals
end

local function pre_unit_destroyed(unit)
	local world = Unit.world(unit)
	local decal_units = decals[unit]
	if decal_units then
		for _, decal_unit in ipairs(decal_units) do
			World.destroy_unit(world, decal_unit)
		end
		decals[unit] = nil
	end
end


mod.on_all_mods_loaded = function()
	local is_mod_loading = true
	mod:hook_require("scripts/extension_systems/unit_templates", function(instance)
		if is_mod_loading then
			-- As a client
			mod:hook_safe(instance.broker_stimm_field_crate_deployable, "husk_init", function(unit)
				unit_spawned(unit, false)
			end)

			-- As a server
			mod:hook_safe(instance.broker_stimm_field_crate_deployable, "local_init", function(unit, _config, template_context)
				local is_server = template_context.is_server
				if is_server then
					unit_spawned(unit, false)
				end
			end)

			if instance.broker_stimm_field_crate_deployable.pre_unit_destroyed then
				mod:hook_safe(instance.broker_stimm_field_crate_deployable, "pre_unit_destroyed", pre_unit_destroyed)
			else
				instance.broker_stimm_field_crate_deployable.pre_unit_destroyed = pre_unit_destroyed
			end

			-- Preload assets
			Managers.package:load(package_name, "StimmSupplyRings")
		end
		is_mod_loading = false
	end)
end
