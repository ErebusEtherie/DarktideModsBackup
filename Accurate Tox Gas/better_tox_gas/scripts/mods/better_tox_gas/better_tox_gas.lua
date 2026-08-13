local mod = get_mod("better_tox_gas")

local LIQUID_TEMPLATE = "cultist_grenadier_gas"
local BUFF_TEMPLATE = "in_cultist_grenadier_gas"
local END_FIELD = "_tsf_end_t"
local SMOKE_EFFECT = "content/fx/particles/weapons/grenades/gas_grenade_gas"
local STOP_LEAD = 3.5
local GAS_LIFE = 16

local function setup_cloud(self)
	if not mod:is_enabled() then
		return
	end

	if self._area_template_name ~= LIQUID_TEMPLATE or self._drawer then
		return
	end

	if self[END_FIELD] then
		return
	end

	if self._time_to_remove then
		self[END_FIELD] = self._time_to_remove
	else
		self[END_FIELD] = Managers.time:time("gameplay") + GAS_LIFE
	end

	local world = self._world
	local position = (POSITION_LOOKUP and POSITION_LOOKUP[self._unit]) or Vector3(0, 0, 0)
	local ok, test_id = pcall(World.create_particles, world, SMOKE_EFFECT, position)

	if ok and test_id then
		pcall(World.destroy_particles, world, test_id)
		self._vfx_name_filled = SMOKE_EFFECT
	end
end

local function trigger_stop(self, t)
	if not mod:is_enabled() then
		return
	end

	if self._area_template_name ~= LIQUID_TEMPLATE or self._drawer then
		return
	end

	if not self[END_FIELD] or self._tsf_triggered then
		return
	end

	if not t or t < self[END_FIELD] - STOP_LEAD then
		return
	end

	self._tsf_triggered = true

	local world = self._world

	if self._flow then
		for _, liquid in pairs(self._flow) do
			local id = liquid.particle_id or liquid.filled_particle_id
			if id then
				pcall(World.stop_spawning_particles, world, id)
			end
		end
	end
end

mod:hook_safe(CLASS.LiquidAreaExtension, "init", function (self)
	setup_cloud(self)
end)

mod:hook_safe(CLASS.LiquidAreaExtension, "update", function (self, unit, dt, t)
	trigger_stop(self, t)
end)

if CLASS.HuskLiquidAreaExtension then
	mod:hook_safe(CLASS.HuskLiquidAreaExtension, "init", function (self)
		setup_cloud(self)
	end)

	mod:hook_safe(CLASS.HuskLiquidAreaExtension, "update", function (self, unit, dt, t)
		trigger_stop(self, t)
	end)
end

local function local_player_unit()
	local pm = Managers.player
	local player = pm and pm:local_player(1)
	return player and player.player_unit
end

local function position_inside(extension, position)
	if extension.is_position_inside then
		local ok, res = pcall(extension.is_position_inside, extension, position)
		return ok and res
	end

	local center_box = extension._liquid_center
	if center_box then
		local radius = extension._liquid_radius or 0
		return radius > 0 and Vector3.distance(center_box:unbox(), position) <= radius
	end

	return false
end

local function gas_remaining_seconds()
	local unit = local_player_unit()
	if not unit or not Unit.alive(unit) then
		return nil
	end

	local extension_manager = Managers.state and Managers.state.extension
	local system = extension_manager and extension_manager:system("liquid_area_system")
	if not system then
		return nil
	end

	local map = system._unit_to_extension_map
	if not map then
		return nil
	end

	local position = POSITION_LOOKUP and POSITION_LOOKUP[unit]
	if not position then
		return nil
	end

	local now = Managers.time:time("gameplay")
	local best_remaining

	for _, extension in pairs(map) do
		if extension._area_template_name == LIQUID_TEMPLATE and position_inside(extension, position) then
			local end_t = extension[END_FIELD] or extension._time_to_remove

			if end_t then
				local remaining = end_t - now

				if remaining > 0 and (not best_remaining or remaining > best_remaining) then
					best_remaining = remaining
				end
			end
		end
	end

	return best_remaining
end

local function gas_duration_func(template_data, template_context)
	if not mod:is_enabled() or not mod:get("icon_timer") then
		return 1
	end

	local remaining = gas_remaining_seconds()
	if not remaining then
		return 1
	end

	local fraction = remaining / GAS_LIFE
	if fraction < 0 then
		fraction = 0
	elseif fraction > 1 then
		fraction = 1
	end

	return fraction
end

local function seconds_enabled()
	return mod:is_enabled() and mod:get("icon_seconds")
end

local function gas_visual_stack_count(template_data, template_context)
	if not seconds_enabled() then
		return 1
	end

	local remaining = gas_remaining_seconds()
	if not remaining then
		return 1
	end

	local seconds = math.ceil(remaining)
	if seconds < 1 then
		seconds = 1
	end

	return seconds
end

local function gas_stack_formatter(buff_data, stack_count, buff_template, text_style)
	if not seconds_enabled() or not gas_remaining_seconds() then
		return nil
	end

	return tostring(stack_count)
end

mod.on_all_mods_loaded = function ()
	local ok, liquid_templates = pcall(require, "scripts/settings/liquid_area/liquid_area_templates")
	if ok and liquid_templates and liquid_templates[LIQUID_TEMPLATE] and liquid_templates[LIQUID_TEMPLATE].life_time then
		GAS_LIFE = liquid_templates[LIQUID_TEMPLATE].life_time
	end

	local ok2, buff_templates = pcall(require, "scripts/settings/buff/liquid_area_buff_templates")
	if ok2 and buff_templates and buff_templates[BUFF_TEMPLATE] then
		local template = buff_templates[BUFF_TEMPLATE]

		template.duration_func = gas_duration_func
		template.visual_stack_count = gas_visual_stack_count
		template.stack_hud_data_formatter = gas_stack_formatter
		template.hud_always_show_stacks = true
	else
		mod:error("could not find buff template '%s' to add icon timer", BUFF_TEMPLATE)
	end
end
