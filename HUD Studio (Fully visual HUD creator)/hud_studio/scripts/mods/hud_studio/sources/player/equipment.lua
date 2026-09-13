---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local Player = mod.dl.player
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")
local LoadoutCache = mod:core(mod.hud_studio_player_loadout_cache, "sources/player/cache/loadout_cache")

local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
local ReloadStates = require("scripts/extension_systems/weapon/utilities/reload_states")
local RELOAD_KINDS = ReloadStates.reload_kinds

local WEAPON_SLOTS = { "slot_primary", "slot_secondary" }
local MELEE_SLOT = "slot_primary"
local RANGED_SLOT = "slot_secondary"

local ammo_util = nil
local overheat_util = nil
local function ammo_utility()
	if ammo_util == nil then
		local ok, mod_or_err = pcall(require, "scripts/utilities/ammo")
		ammo_util = (ok and mod_or_err) or false
	end
	return ammo_util or nil
end

local function overheat_utility()
	if overheat_util == nil then
		local ok, mod_or_err = pcall(require, "scripts/utilities/overheat")
		overheat_util = (ok and mod_or_err) or false
	end
	return overheat_util or nil
end

local function read_wielded_slot(unit_data_extension)
	if not unit_data_extension then
		return false, false, "none"
	end
	local inventory_comp = unit_data_extension:read_component("inventory")
	local wielded_slot = inventory_comp.wielded_slot

	if wielded_slot == "none" then
		return false, false, "none"
	end

	return wielded_slot == WEAPON_SLOTS[1], wielded_slot == WEAPON_SLOTS[2], wielded_slot
end

---@param slot string
---@param component table
---@param visual_loadout_extension table | nil
local function read_overheat(slot, component, visual_loadout_extension)
	local Overheat = overheat_utility()

	if not component or not visual_loadout_extension then
		return 0, false, false
	end

	local special_active = component.special_active
	local overheat_configuration = Overheat and Overheat.configuration(visual_loadout_extension, slot)

	if overheat_configuration then
		return (component.overheat_current_percentage or 0) * 100, component.overheat_state == "lockout", special_active
	end

	return 0, false, false
end

local RELOAD_ACTION_RANK = {
	action_start_reload = 1,
	action_reload = 2,
}
local reload_action_by_template = {}

---@param weapon_template table
---@return table | nil
local function reload_action_settings(weapon_template)
	local cached = reload_action_by_template[weapon_template]

	if cached == nil then
		cached = false

		local best_rank, best_name

		for action_name, action_settings in pairs(weapon_template.actions or {}) do
			if RELOAD_KINDS[action_settings.kind] then
				local rank = RELOAD_ACTION_RANK[action_name] or (string.find(action_name, "loop", 1, true) and 4 or 3)

				if not best_rank or rank < best_rank or (rank == best_rank and action_name < best_name) then
					best_rank, best_name, cached = rank, action_name, action_settings
				end
			end
		end

		reload_action_by_template[weapon_template] = cached
	end

	return cached or nil
end

---@param action_settings table
---@param weapon_extension table | nil
---@param buff_extension table | nil
---@return number
local function action_time_scale(action_settings, weapon_extension, buff_extension)
	local time_scale = 1
	local handling_name = action_settings.weapon_handling_template

	if handling_name and weapon_extension and weapon_extension._weapon_tweak_template then

		local ok, handling_template =
			pcall(weapon_extension._weapon_tweak_template, weapon_extension, "weapon_handling", handling_name)

		if ok and handling_template and handling_template.time_scale then
			time_scale = handling_template.time_scale
		end
	end

	local stat_buff_names = action_settings.time_scale_stat_buffs
	local stat_buffs = stat_buff_names and buff_extension and buff_extension.stat_buffs and buff_extension:stat_buffs()

	if stat_buffs then
		local applied_count, total_modifier = 0, 0

		for index = 1, #stat_buff_names do
			local stat_buff_value = stat_buffs[stat_buff_names[index]]

			if stat_buff_value then
				total_modifier = total_modifier + stat_buff_value
				applied_count = applied_count + 1
			end
		end

		if applied_count > 0 then
			time_scale = time_scale * (total_modifier - (applied_count - 1))
		end
	end

	return time_scale > 0 and time_scale or 1
end

---@param weapon_template table
---@param action_settings table
---@param slot_component table | nil
---@return number seconds
local function reload_leg_seconds(weapon_template, action_settings, slot_component)
	local reload_template = weapon_template.reload_template

	if reload_template and slot_component and ReloadStates.uses_reload_states(slot_component) then
		local reload_state = ReloadStates.reload_state(reload_template, slot_component)

		if reload_state and reload_state.time then
			return reload_state.time
		end
	end

	return action_settings.total_time or 0
end

---@param weapon_template table
---@param action_settings table
---@param slot_component table | nil
---@param leg_seconds number
---@return number seconds
local function reload_refill_seconds(weapon_template, action_settings, slot_component, leg_seconds)
	local reload_template = weapon_template.reload_template

	if reload_template and slot_component and ReloadStates.uses_reload_states(slot_component) then
		local reload_state = ReloadStates.reload_state(reload_template, slot_component)
		local functionality = reload_state and reload_state.functionality

		return functionality and functionality.refill_ammunition or 0
	end

	local reload_settings = action_settings.reload_settings

	return reload_settings and reload_settings.refill_at_time or leg_seconds
end

---@param equipment_values table       the equipment leaves, written in place
---@param unit_data_extension table | nil
---@param wielded_slot string
---@param slot_component table | nil
---@param weapon_extension table | nil
---@param buff_extension table | nil
local function read_reload(
	equipment_values,
	unit_data_extension,
	wielded_slot,
	slot_component,
	weapon_extension,
	buff_extension
)
	local e = equipment_values

	e.is_reloading = false
	e.reload_total_time = 0
	e.reload_time_remaining_seconds = 0
	e.progress_percent_to_reload_finish = 0
	e.reload_animation_total_time = 0
	e.reload_animation_time_remaining_seconds = 0
	e.progress_percent_to_reload_animation_finish = 0

	if not unit_data_extension or wielded_slot == "none" then
		return
	end

	local action_component = unit_data_extension:read_component("weapon_action")
	local weapon_template = action_component and WeaponTemplate.current_weapon_template(action_component)
	local opening_action = weapon_template and reload_action_settings(weapon_template)

	if not opening_action then
		return
	end

	local action_name = action_component.current_action_name
	local running_action = action_name and weapon_template.actions[action_name]
	local is_reloading = running_action ~= nil and RELOAD_KINDS[running_action.kind] ~= nil
	local action_settings = is_reloading and running_action or opening_action

	local time_scale = is_reloading and action_component.time_scale
		or action_time_scale(opening_action, weapon_extension, buff_extension)

	if not time_scale or time_scale <= 0 then
		time_scale = 1
	end

	local leg_seconds = reload_leg_seconds(weapon_template, action_settings, slot_component)
	local animation_seconds = leg_seconds / time_scale
	local refill_seconds = reload_refill_seconds(weapon_template, action_settings, slot_component, leg_seconds)
		/ time_scale

	e.is_reloading = is_reloading
	e.reload_total_time = refill_seconds
	e.reload_animation_total_time = animation_seconds

	if not is_reloading then
		return
	end

	local gameplay_time = Managers.time and Managers.time:time("gameplay")
	local start_t = action_component.start_t
	local elapsed_seconds = gameplay_time and start_t and math.max(gameplay_time - start_t, 0) or 0

	e.reload_time_remaining_seconds = math.max(refill_seconds - elapsed_seconds, 0)
	e.progress_percent_to_reload_finish = refill_seconds > 0
			and math.clamp(elapsed_seconds / refill_seconds, 0, 1) * 100
		or 100
	e.reload_animation_time_remaining_seconds = math.max(animation_seconds - elapsed_seconds, 0)
	e.progress_percent_to_reload_animation_finish = animation_seconds > 0
			and math.clamp(elapsed_seconds / animation_seconds, 0, 1) * 100
		or 100
end

---@return number charges
---@return number max_charges
---@return number seconds_until_next_charge
---@return number progress_percent_to_next_charge
---@return number progress_percent_to_max_charges
local function read_special_charges(slot, component, visual_loadout_extension, weapon_extension)
	if not visual_loadout_extension then
		return 0, 0, 0, 0, 0
	end

	local vl_weapon_template = visual_loadout_extension:weapon_template_from_slot(slot)
	local tweak = vl_weapon_template and vl_weapon_template.weapon_special_tweak_data
	local charges = component.num_special_charges or 0
	local max_charges = tweak and (tweak.max_charges or tweak.max_num_charges) or component.max_num_special_charges or 0

	if not tweak or max_charges <= 0 or charges >= max_charges then
		local full_percent = max_charges > 0 and 100 or 0

		return charges, max_charges, 0, full_percent, full_percent
	end

	local recharge_seconds = tweak.passive_charge_add_interval
	local charge_ready_time = component.special_charge_remove_at_t

	if not recharge_seconds then
		recharge_seconds = tweak.cooldown

		local weapon = weapon_extension and weapon_extension._weapons and weapon_extension._weapons[slot]
		local special_implementation = weapon and weapon.weapon_special_implementation

		charge_ready_time = special_implementation and special_implementation._next_charge_recovery_time
	end

	local gameplay_time = Managers.time and Managers.time:time("gameplay")

	if not charge_ready_time or not gameplay_time or not recharge_seconds or recharge_seconds <= 0 then
		return charges, max_charges, 0, 0, charges / max_charges * 100
	end

	local seconds_until_next_charge = math.max(charge_ready_time - gameplay_time, 0)

	local recharge_window_seconds = math.max(recharge_seconds, seconds_until_next_charge)

	local progress_to_next_charge = 1 - seconds_until_next_charge / recharge_window_seconds

	local charges_including_in_flight = charges + progress_to_next_charge

	return charges,
		max_charges,
		seconds_until_next_charge,
		progress_to_next_charge * 100,
		charges_including_in_flight / max_charges * 100
end

local function read_ammo(component)
	local Ammo = ammo_utility()

	if Ammo then
		return Ammo.max_ammo_in_clips(component) or 0,
			Ammo.current_ammo_in_clips(component) or 0,
			Ammo.current_ammo_in_reserve(component) or 0,
			Ammo.max_ammo_in_reserve(component) or 0
	end

	return 0, 0, 0
end

---@param unit_data_extension table | nil
---@return number level      0-1 charge fraction
---@return number max_charge 0-1 level counted as fully charged
local function read_charge(unit_data_extension)
	if not unit_data_extension then
		return 0, 1
	end

	local charge_component = unit_data_extension:read_component("action_module_charge")

	if not charge_component then
		return 0, 1
	end

	local max_charge = charge_component.max_charge

	if not max_charge or max_charge <= 0 then
		max_charge = 1
	end

	return charge_component.charge_level or 0, max_charge
end

---@class VisualLoadoutExtension : EditorDoc
---@field weapon_template_from_slot fun(self: VisualLoadoutExtension, slot: string): table | nil

---@type PlayerField
local Field = {
	fields = {
		equipment = {

			melee_is_equipped = DataTypes.field(
				"boolean",
				"[true/false] whether the melee weapon is currently in hand"
			),
			ranged_is_equipped = DataTypes.field(
				"boolean",
				"[true/false] whether the ranged weapon is currently in hand"
			),

			melee_icon = DataTypes.field("material", "[string|nil] path of material to melee weapon icon"),
			melee_special_active = DataTypes.field(
				"boolean",
				"[true/false] whether melee weapon special is currently active"
			),
			melee_overheat_lockout = DataTypes.field(
				"boolean",
				"[true/false] whether melee weapon is currently in lockout state"
			),
			melee_overheat_percent = DataTypes.field("number", "[0..100] % melee weapon overheat"),
			melee_special_charges = DataTypes.field(
				"integer",
				"[0..n] number of currently available melee special charges"
			),
			melee_uses_special_charges = DataTypes.field(
				"boolean",
				"[true/false] does the melee weapon have special charges?"
			),
			melee_special_charges_max = DataTypes.field("integer", "[0..n] maximum number of melee special charges"),
			melee_special_charge_time_remaining_seconds = DataTypes.field(
				"number",
				"[0..n] seconds until the melee weapon regains its next special charge"
			),
			progress_percent_to_melee_special_charge = DataTypes.field(
				"number",
				"[0..100] % of the way to the melee weapon's next special charge"
			),
			progress_percent_to_melee_special_charges = DataTypes.field(
				"number",
				"[0..100] % of the way to the melee weapon's full bank of special charges, counting the one recharging as a fraction so the bar fills smoothly rather than a segment at a time"
			),

			ranged_icon = DataTypes.field("material", "[string|nil] path of material to ranged weapon icon"),

			ranged_special_active = DataTypes.field(
				"boolean",
				"[true/false] whether ranged weapon special is currently active"
			),
			ranged_overheat_lockout = DataTypes.field(
				"boolean",
				"[true/false] whether ranged weapon is currently in lockout state"
			),
			ranged_overheat_percent = DataTypes.field("number", "[0..100] % ranged weapon overheat"),
			ranged_special_charges = DataTypes.field(
				"integer",
				"[0..n] number of currently available ranged special charges"
			),
			ranged_special_charges_max = DataTypes.field("integer", "[0..n] maximum number of ranged special charges"),
			ranged_special_charge_time_remaining_seconds = DataTypes.field(
				"number",
				"[0..n] seconds until the ranged weapon regains its next special charge"
			),
			progress_percent_to_ranged_special_charge = DataTypes.field(
				"number",
				"[0..100] % of the way to the ranged weapon's next special charge"
			),
			progress_percent_to_ranged_special_charges = DataTypes.field(
				"number",
				"[0..100] % of the way to the ranged weapon's full bank of special charges, counting the one recharging as a fraction so the bar fills smoothly rather than a segment at a time"
			),
			ranged_uses_special_charges = DataTypes.field(
				"boolean",
				"[true/false] does the ranged weapon have special charges?"
			),

			ammo_rounds_remaining = DataTypes.field("integer", "[0..n] number of rounds left in total"),
			ammo_rounds_remaining_percent = DataTypes.field("number", "[0..100] % of total rounds remaining"),
			ammo_reserve_mags = DataTypes.field("number", "[0..n] number of reserve magazines remaining as a fraction"),
			ammo_mags_capacity = DataTypes.field("integer", "[0..n] maximum number of full magazines you can carry"),
			ammo_mag_remaining = DataTypes.field("integer", "[0..n] number of rounds remaining in magazine"),
			ammo_mag_remaining_percent = DataTypes.field("number", "[0..100] % of magazine rounds remaining"),
			ammo_mag_max = DataTypes.field("integer", "[0..n] maximum number of rounds in magazine"),
			ammo_reserve = DataTypes.field("integer", "[0..n] number of rounds remaining in reserve"),
			ammo_reserve_percent = DataTypes.field("number", "[0..100] % of reserve rounds remaining"),
			ammo_reserve_max = DataTypes.field("integer", "[0..n] maximum number of rounds held in reserve"),
			ranged_uses_ammo = DataTypes.field("boolean", "[true/false] does the ranged weapon use ammo?"),

			charge_percent = DataTypes.field(
				"number",
				"[0..100] % charge of the action being held (force staff right-click, charged melee, smite)"
			),
			charge_max_percent = DataTypes.field("number", "[0..100] % charge that counts as fully charged"),
			charge_is_active = DataTypes.field("boolean", "[true/false] whether an action is charging up right now"),
			charge_is_full = DataTypes.field("boolean", "[true/false] whether the charge-up has reached full"),

			is_reloading = DataTypes.field("boolean", "[true/false] whether the wielded weapon is reloading right now"),
			reload_total_time = DataTypes.field(
				"number",
				"[0..n] seconds from the start of a reload until the ammo is in the magazine -- usually earlier than the animation ends, so a shot can be taken sooner; talent/blessing reload speed included; 0 when the weapon cannot reload"
			),
			reload_time_remaining_seconds = DataTypes.field(
				"number",
				"[0..n] seconds until the ammo is in the magazine; 0 when not reloading"
			),
			progress_percent_to_reload_finish = DataTypes.field(
				"number",
				"[0..100] % of the way to the ammo being in the magazine; 0 when not reloading"
			),
			reload_animation_total_time = DataTypes.field(
				"number",
				"[0..n] seconds the whole reload animation takes start to finish, talent/blessing reload speed included; 0 when the weapon cannot reload"
			),
			reload_animation_time_remaining_seconds = DataTypes.field(
				"number",
				"[0..n] seconds left on the reload animation in progress; 0 when not reloading"
			),
			progress_percent_to_reload_animation_finish = DataTypes.field(
				"number",
				"[0..100] % of the reload animation in progress completed; 0 when not reloading"
			),
		},
	},
	sections = {
		{ id = "current", label = "Currently Equipped" },
		{ id = "charge", label = "Charge" },
		{ id = "special", label = "Special" },
		{ id = "overheat", label = "Overheat" },
		{ id = "icons", label = "Icons" },
		{ id = "ammo", label = "Reserve Ammo" },
		{ id = "mag", label = "Magazine" },
		{ id = "reload", label = "Reload" },
	},
	field_meta = {
		["equipment.melee_is_equipped"] = { section = "current" },
		["equipment.ranged_is_equipped"] = { section = "current" },
		["equipment.melee_icon"] = { section = "icons" },
		["equipment.ranged_icon"] = { section = "icons" },
		["equipment.melee_overheat_lockout"] = { section = "overheat" },
		["equipment.melee_overheat_percent"] = { section = "overheat" },
		["equipment.ranged_overheat_lockout"] = { section = "overheat" },
		["equipment.ranged_overheat_percent"] = { section = "overheat" },
		["equipment.melee_special_active"] = { section = "special" },
		["equipment.melee_special_charges"] = { section = "special" },
		["equipment.melee_uses_special_charges"] = { section = "special" },
		["equipment.melee_special_charges_max"] = { section = "special" },
		["equipment.melee_special_charge_time_remaining_seconds"] = { section = "special" },
		["equipment.progress_percent_to_melee_special_charge"] = { section = "special" },
		["equipment.progress_percent_to_melee_special_charges"] = { section = "special" },
		["equipment.ranged_special_charge_time_remaining_seconds"] = { section = "special" },
		["equipment.progress_percent_to_ranged_special_charge"] = { section = "special" },
		["equipment.progress_percent_to_ranged_special_charges"] = { section = "special" },
		["equipment.ranged_special_active"] = { section = "special" },
		["equipment.ranged_special_charges"] = { section = "special" },
		["equipment.ranged_special_charges_max"] = { section = "special" },
		["equipment.ranged_uses_special_charges"] = { section = "special" },
		["equipment.ammo_rounds_remaining"] = { section = "ammo" },
		["equipment.ammo_rounds_remaining_percent"] = { section = "ammo" },
		["equipment.ammo_reserve_mags"] = { section = "ammo" },
		["equipment.ammo_reserve"] = { section = "ammo" },
		["equipment.ammo_reserve_percent"] = { section = "ammo" },
		["equipment.ammo_reserve_max"] = { section = "ammo" },
		["equipment.ranged_uses_ammo"] = { section = "ammo" },
		["equipment.charge_percent"] = { section = "charge" },
		["equipment.charge_max_percent"] = { section = "charge" },
		["equipment.charge_is_active"] = { section = "charge" },
		["equipment.charge_is_full"] = { section = "charge" },
		["equipment.is_reloading"] = { section = "reload" },
		["equipment.reload_total_time"] = { section = "reload" },
		["equipment.reload_time_remaining_seconds"] = { section = "reload" },
		["equipment.progress_percent_to_reload_finish"] = { section = "reload" },
		["equipment.reload_animation_total_time"] = { section = "reload" },
		["equipment.reload_animation_time_remaining_seconds"] = { section = "reload" },
		["equipment.progress_percent_to_reload_animation_finish"] = { section = "reload" },
		["equipment.ammo_mags_capacity"] = { section = "mag" },
		["equipment.ammo_mag_remaining"] = { section = "mag" },
		["equipment.ammo_mag_remaining_percent"] = { section = "mag" },
		["equipment.ammo_mag_max"] = { section = "mag" },
	},
	write = function(values, player, unit)
		values.equipment = values.equipment or {}
		local e = values.equipment

		local unit_data, visual_loadout = Player.extensions(unit, "unit_data_system", "visual_loadout_system")

		local item_melee = LoadoutCache.item(player, visual_loadout, MELEE_SLOT)
		local item_ranged = LoadoutCache.item(player, visual_loadout, RANGED_SLOT)

		e.melee_icon = item_melee and (item_melee.hud_icon or item_melee.icon)
		e.ranged_icon = item_ranged and (item_ranged.hud_icon or item_ranged.icon)

		if not unit or not unit_data then
			e.melee_special_active = false
			e.melee_overheat_lockout = false
			e.melee_is_equipped = false
			e.melee_overheat_percent = 0
			e.melee_special_charges = 0
			e.melee_special_charges_max = 0
			e.melee_special_charge_time_remaining_seconds = 0
			e.progress_percent_to_melee_special_charge = 0
			e.progress_percent_to_melee_special_charges = 0
			e.ranged_special_charge_time_remaining_seconds = 0
			e.progress_percent_to_ranged_special_charge = 0
			e.progress_percent_to_ranged_special_charges = 0
			e.ranged_is_equipped = false
			e.ranged_special_active = false
			e.ranged_overheat_lockout = false
			e.melee_uses_special_charges = false
			e.ranged_uses_special_charges = false
			e.ranged_uses_ammo = false
			e.ranged_overheat_percent = 0
			e.ranged_special_charges = 0
			e.ranged_special_charges_max = 0
			e.ammo_mag_max = 0
			e.ammo_mag_remaining = 0
			e.ammo_reserve = 0
			e.ammo_reserve_max = 0
			e.ammo_reserve_percent = 0
			e.ammo_mags_capacity = 0
			e.charge_percent = 0
			e.charge_max_percent = 100
			e.charge_is_active = false
			e.charge_is_full = false
			e.is_reloading = false
			e.reload_total_time = 0
			e.reload_time_remaining_seconds = 0
			e.progress_percent_to_reload_finish = 0
			e.reload_animation_total_time = 0
			e.reload_animation_time_remaining_seconds = 0
			e.progress_percent_to_reload_animation_finish = 0
		end

		local wielded_slot
		e.melee_is_equipped, e.ranged_is_equipped, wielded_slot = read_wielded_slot(unit_data)

		local weapon_extension, buff_extension = Player.extensions(unit, "weapon_system", "buff_system")

		local component_melee = unit_data and unit_data:read_component(MELEE_SLOT)

		if component_melee then

			e.melee_overheat_percent, e.melee_overheat_lockout, e.melee_special_active =
				read_overheat(MELEE_SLOT, component_melee, visual_loadout)

			e.melee_special_charges,
				e.melee_special_charges_max,
				e.melee_special_charge_time_remaining_seconds,
				e.progress_percent_to_melee_special_charge,
				e.progress_percent_to_melee_special_charges =
				read_special_charges(MELEE_SLOT, component_melee, visual_loadout, weapon_extension)
			e.melee_uses_special_charges = (e.melee_special_charges_max or 0) > 0
		end

		local component_ranged = unit_data and unit_data:read_component(RANGED_SLOT)

		if component_ranged then

			e.ranged_overheat_percent, e.ranged_overheat_lockout, e.ranged_special_active =
				read_overheat(RANGED_SLOT, component_ranged, visual_loadout)

			e.ranged_special_charges,
				e.ranged_special_charges_max,
				e.ranged_special_charge_time_remaining_seconds,
				e.progress_percent_to_ranged_special_charge,
				e.progress_percent_to_ranged_special_charges =
				read_special_charges(RANGED_SLOT, component_ranged, visual_loadout, weapon_extension)

			e.ranged_uses_special_charges = (e.ranged_special_charges_max or 0) > 0

			e.ammo_mag_max, e.ammo_mag_remaining, e.ammo_reserve, e.ammo_reserve_max = read_ammo(component_ranged)

			e.ammo_reserve_percent = (e.ammo_reserve / e.ammo_reserve_max) * 100

			e.ammo_mags_capacity = 1 + (e.ammo_reserve_max / e.ammo_mag_max)

			e.ammo_rounds_remaining = e.ammo_mag_remaining + e.ammo_reserve

			e.ammo_rounds_remaining_percent = (e.ammo_rounds_remaining / (e.ammo_mag_max + e.ammo_reserve_max)) * 100

			e.ammo_mag_remaining_percent = (e.ammo_mag_remaining / e.ammo_mag_max) * 100

			e.ammo_reserve_mags = math.floor(e.ammo_reserve / e.ammo_mag_max)

			e.ammo_reserve_mag_remaining = e.ammo_reserve % e.ammo_mag_max

			e.ammo_reserve_mag_remaining_percent = (e.ammo_reserve_mag_remaining / e.ammo_mag_max) * 100

			e.ammo_mags_remaining = (e.ammo_mag_remaining / e.ammo_mag_max) + (e.ammo_reserve / e.ammo_mag_max)

			e.ammo_mags_remaining_percent = (e.ammo_mags_remaining / e.ammo_mags_capacity) * 100

			e.ranged_uses_ammo = e.ammo_reserve_max >= 1
		end

		local charge_level, charge_max = read_charge(unit_data)

		e.charge_percent = charge_level * 100
		e.charge_max_percent = charge_max * 100
		e.charge_is_active = charge_level > 0

		e.charge_is_full = e.charge_is_active and charge_level >= math.min(charge_max, 1)

		local wielded_component = wielded_slot == RANGED_SLOT and component_ranged
			or wielded_slot == MELEE_SLOT and component_melee
			or nil

		read_reload(e, unit_data, wielded_slot, wielded_component, weapon_extension, buff_extension)

	end,
}

mod.hud_studio_player_equipment = Field
return Field
