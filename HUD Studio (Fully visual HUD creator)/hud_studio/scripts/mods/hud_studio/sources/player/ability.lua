---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_player_ability then
	return mod.hud_studio_player_ability
end

local Ability = mod:core(mod.hud_studio_player_ability_read, "sources/player/reads/ability_read")
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")
local Localize = mod:core(mod.hud_studio_source_localize, "sources/localize")

local ABILITY_ID = "combat_ability"

local ICON_MATERIAL = "content/ui/materials/icons/talents/hud/combat_container"
local ICON_TEXTURE_SLOT = "talent_icon"
local ICON_MASK_SLOT = "mask"
local ICON_RAMP_SLOT = "ramp"

local ICON_PROGRESS_SLOT = "progress"

local FRAME_MATERIAL = "content/ui/materials/icons/talents/hud/combat_frame_inner"
local FRAME_TEXTURE_SLOT = "texture_map"
local GLOW_MATERIAL = "content/ui/materials/effects/hud/combat_talent_glow"
local GLOW_SHAPE_SLOT = "glow_shape"
local GLOW_SPIN_SLOT = "glow_spin"

local function is_material_path(path)
	return type(path) == "string" and path:find("content/ui/materials/", 1, true) == 1
end

---@param values table   the per-slot source state
---@param texture string|nil  the ability's hud_icon_frame override, if it has one
---@return table
local function frame_descriptor(values, texture)
	local cache = values.frame_descriptors
	if not cache then
		cache = {}
		values.frame_descriptors = cache
	end
	local key = texture or "default"
	local descriptor = cache[key]
	if not descriptor then
		descriptor = { material = FRAME_MATERIAL, values = {} }

		descriptor.values[FRAME_TEXTURE_SLOT] = texture
		cache[key] = descriptor
	end
	return descriptor
end

---@param values table
---@param shape string|nil
---@param spin string|nil
---@return table
local function glow_descriptor(values, shape, spin)
	local cache = values.glow_descriptors
	if not cache then
		cache = {}
		values.glow_descriptors = cache
	end
	local key = shape or "default"
	local descriptor = cache[key]
	if not descriptor then
		descriptor = { material = GLOW_MATERIAL, values = {} }
		descriptor.values[GLOW_SHAPE_SLOT] = shape
		descriptor.values[GLOW_SPIN_SLOT] = spin
		cache[key] = descriptor
	end
	return descriptor
end

local function icon_to_descriptor(icon, icon_mask, icon_ramp, state, state_descriptor_key, progress)

	if icon and not is_material_path(icon) then

		local descriptor = state[state_descriptor_key]
		if not descriptor then
			descriptor = { material = ICON_MATERIAL, values = {} }
			state[state_descriptor_key] = descriptor
		end
		descriptor.values[ICON_TEXTURE_SLOT] = icon

		descriptor.values[ICON_MASK_SLOT] = icon_mask
		descriptor.values[ICON_RAMP_SLOT] = icon_ramp

		descriptor.values[ICON_PROGRESS_SLOT] = progress or 1
		return descriptor
	end
	return icon
end

local simple_name_by_group = {

	zealot_dash = mod:localize("talent_zealot_dash_simple"),
	bolstering_prayer = mod:localize("talent_zealot_chorus_simple"),
	zealot_invisibility = mod:localize("talent_zealot_stealth_simple"),

	volley_fire_stance = mod:localize("talent_veteran_outline_simple"),
	voice_of_command = mod:localize("talent_veteran_voc_simple"),
	veteran_stealth = mod:localize("talent_veteran_stealth_simple"),

	psyker_shield = mod:localize("talent_psyker_shield_simple"),
	psyker_shout = mod:localize("talent_psyker_vent_shout_simple"),
	psyker_overcharge_stance = mod:localize("talent_psyker_scrier_simple"),

	ogryn_taunt_shout = mod:localize("talent_ogryn_taunt_simple"),
	ogryn_charge = mod:localize("talent_ogryn_charge_simple"),
	ogryn_gunlugger_stance = mod:localize("talent_ogryn_barrage_simple"),

	adamant_stance = mod:localize("talent_arbitrator_castigator_simple"),
	adamant_charge = mod:localize("talent_arbitrator_bash_simple"),
	adamant_area_buff_drone = mod:localize("talent_arbitrator_nuncio_aquila_simple"),

	broker_punk_rage_stance = mod:localize("talent_hive_scum_rage_simple"),
	broker_focus_stance = mod:localize("talent_hive_scum_desperado_simple"),
	broker_stimm_field = mod:localize("talent_hive_scum_stimm_field_simple"),

	cryptic_chordclaw = mod:localize("talent_cryptic_chordclaw_simple"),
	cryptic_discharge = mod:localize("talent_cryptic_discharge_simple"),
	cryptic_precision_stance = mod:localize("talent_cryptic_precision_stance_simple"),
}

local name_by_loc_id = {}

---@type PlayerField
local Field = {
	fields = {
		ability = {
			id = DataTypes.field("string", "[string|nil] raw ability key, e.g. veteran_combat_ability_stealth"),
			group = DataTypes.field(
				"string",
				"[string|nil] raw ability group key -- same for a talent's base and improved variants"
			),
			icon = DataTypes.field("material", "[string|nil] composite material for ability icon"),
			icon_gray_til_charge = DataTypes.field(
				"material",
				"[string|nil] composite material for ability icon, remaining gray until a charge is ready"
			),
			icon_frame = DataTypes.field("material", "[material] the hexagon frame drawn around the ability icon"),
			icon_frame_glow = DataTypes.field("material", "[material] the glow drawn over the ability frame"),
			is_ready = DataTypes.field("boolean", "[true/false] ability is ready?"),
			name = DataTypes.field("string", "[string|nil] localized name of ability, e.g. Shroudfield"),
			name_simple = DataTypes.field("string", "[string|nil] short label for the ability, e.g. Stealth"),
			progress_percent_to_next_charge = DataTypes.field(
				"number",
				"[0..100] % progress to next ability charge being ready, "
			),
			progress_percent_to_max_charges = DataTypes.field(
				"number",
				"[0..100] % progress to all ability charges being ready, "
			),
			cooldown_seconds_to_next_charge = DataTypes.field(
				"number",
				"[0..n] [seconds] seconds left until next ability charge is ready"
			),
			charges = DataTypes.field("integer", "[0..n] number of currently ready ability charges"),
			max_charges = DataTypes.field("integer", "[0..n] number of maximum ability charges"),
		},
	},
	sections = {
		{ id = "icon", label = "Icon" },
		{ id = "status", label = "Status" },
		{ id = "charges", label = "Charges" },
		{ id = "name", label = "Name" },
		{ id = "id", label = "ID" },
	},
	field_meta = {
		["ability.name"] = { section = "name" },
		["ability.name_simple"] = { section = "name" },
		["ability.icon"] = { section = "icon" },
		["ability.icon_gray_til_charge"] = { section = "icon" },
		["ability.icon_frame"] = { section = "icon" },
		["ability.icon_frame_glow"] = { section = "icon" },
		["ability.charges"] = { section = "charges" },
		["ability.max_charges"] = { section = "charges" },
		["ability.is_ready"] = { section = "status" },
		["ability.progress_percent_to_next_charge"] = { section = "status" },
		["ability.progress_percent_to_max_charges"] = { section = "status" },
		["ability.cooldown_seconds_to_next_charge"] = { section = "status" },
		["ability.id"] = { section = "id" },
		["ability.group"] = { section = "id" },
	},
	write = function(values, player, unit)

		local ability = Ability.read(unit, ABILITY_ID, values.ability, player)
		values.ability = ability

		local template_icon = ability.icon

		ability.icon = icon_to_descriptor(
			template_icon,
			ability.icon_mask,
			ability.icon_ramp,
			values,
			"icon_descriptor",
			ability.progress_percent_to_next_charge and ability.progress_percent_to_next_charge / 100
		)
		ability.icon_gray_til_charge = icon_to_descriptor(
			template_icon,
			ability.icon_mask,
			ability.icon_ramp,
			values,
			"icon_gray_til_charge_descriptor",
			ability.progress_percent_to_next_charge >= 100 and 1 or 0
		)

		if ability.id then
			ability.icon_frame = frame_descriptor(values, ability.icon_frame)
			ability.icon_frame_glow = glow_descriptor(values, ability.icon_frame_glow, ability.icon_frame_glow_spin)
		else
			ability.icon_frame, ability.icon_frame_glow = nil, nil
		end

		local name_loc = ability.name_loc
		local name = nil
		if name_loc then
			name = name_by_loc_id[name_loc]
			if name == nil then
				name = Localize.game(name_loc) or false
				name_by_loc_id[name_loc] = name
			end
		end
		ability.name = name or nil

		ability.name_simple = ability.group and simple_name_by_group[ability.group] or nil
	end,
}

mod.hud_studio_player_ability = Field
return Field
