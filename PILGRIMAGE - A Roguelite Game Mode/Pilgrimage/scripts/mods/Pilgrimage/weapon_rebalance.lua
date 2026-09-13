-- weapon_rebalance.lua
--
-- Direct weapon-transformation layer. This module deliberately owns
-- every table branch it changes. Darktide shares hitscan and damage-profile
-- tables between actions, and editing a shared table in place can change other
-- weapon marks that happen to point at it.
--
-- The prototype is prepared during StateLoading, before player and bot weapons
-- are constructed. That timing matters for ammunition, because Darktide copies
-- the ammo template into each weapon instance during construction.

local M = {}

local _mod
local _settings
local _run_state
local _shared
local _event_log
local _debug_log
local _hooks
local APPLY_DIAG = {
	last_error = nil,
	skipped_optional = {},
}

local HOTSHOT_TEMPLATE = "autogun_p3_m2"
local KICKBACK_TEMPLATE = "ogryn_thumper_p1_m1"
local SHREDDER_TEMPLATE = "autopistol_p1_m1"
local POWER_MAUL_TEMPLATE = "ogryn_powermaul_p1_m1"
local PLASMA_CANNON_TEMPLATE = "plasmagun_p1_m2"
local PLASMA_PISTOL_TEMPLATE = "boltpistol_p1_m2"
local VINDICATOR_TEMPLATE = "flamer_p1_m1"
local HUNTER_STUBBER_TEMPLATE = "ogryn_heavystubber_p2_m3"
local GRENADIER_GAUNTLET_TEMPLATE = "ogryn_gauntlet_p1_m1"
local THUNDER_HAMMER_SPECS = {
	{
		name = "thunderhammer_2h_p1_m1",
		role = "execution",
	},
	{
		name = "thunderhammer_2h_p1_m2",
		role = "line_breaker",
	},
}
local POWER_SWORD_TIMED_TEMPLATES = {
	"powersword_p1_m1",
	"powersword_p1_m2",
}
local CHAIN_TIMED_TEMPLATES = {
	"chainsword_p1_m1",
	"chainsword_p1_m2",
	"chainsword_2h_p1_m1",
	"chainsword_2h_p1_m2",
	"chainaxe_p1_m1",
	"chainaxe_p1_m2",
}
-- The rotary saw already has a persistent powered toggle. It participates in
-- the latched-stagger rule, but does not need its activation economy replaced.
local CHAIN_STAGGER_ONLY_TEMPLATES = {
	"saw_p1_m1",
}
local FOLDING_SHOVEL_TEMPLATES = {
	"combataxe_p3_m2",
	"combataxe_p3_m3",
}
local RIPPER_TEMPLATES = {
	{
		name = "ogryn_rippergun_p1_m1",
		near = {
			unarmored = 1.00, armored = 0.90, resistant = 0.65,
			player = 1.00, berserker = 0.90, super_armor = 0.15,
			disgustingly_resilient = 1.00, void_shield = 1.00,
		},
		far = {
			unarmored = 0.40, armored = 0.35, resistant = 0.35,
			player = 0.10, berserker = 0.40, super_armor = 0.05,
			disgustingly_resilient = 0.40, void_shield = 0.40,
		},
	},
	{
		name = "ogryn_rippergun_p1_m2",
		near = {
			unarmored = 1.00, armored = 0.90, resistant = 0.90,
			player = 1.00, berserker = 0.90, super_armor = 0.15,
			disgustingly_resilient = 1.00, void_shield = 1.00,
		},
		far = {
			unarmored = 0.65, armored = 0.55, resistant = 0.55,
			player = 0.10, berserker = 0.65, super_armor = 0.08,
			disgustingly_resilient = 0.65, void_shield = 0.50,
		},
	},
	{
		name = "ogryn_rippergun_p1_m3",
		near = {
			unarmored = 1.00, armored = 0.90, resistant = 0.85,
			player = 1.00, berserker = 1.00, super_armor = 0.20,
			disgustingly_resilient = 1.00, void_shield = 1.00,
		},
		far = {
			unarmored = 0.80, armored = 0.65, resistant = 0.60,
			player = 0.10, berserker = 0.75, super_armor = 0.10,
			disgustingly_resilient = 0.70, void_shield = 0.50,
		},
	},
}
local STUBBER_RELOAD_TEMPLATES = {
	"ogryn_heavystubber_p1_m1",
	"ogryn_heavystubber_p1_m2",
	"ogryn_heavystubber_p2_m1",
	"ogryn_heavystubber_p2_m2",
	"ogryn_heavystubber_p2_m3",
}
local RESERVE_AMMO_FACTORS = {
	-- Every live Ripper mark uses p1_m1's ammunition template.
	{ name = "ogryn_rippergun_p1_m1", factor = 1.25 },
	{ name = "ogryn_heavystubber_p1_m1", factor = 1.25 },
	{ name = "ogryn_heavystubber_p1_m2", factor = 1.25 },
	{ name = "ogryn_heavystubber_p2_m1", factor = 1.25 },
	{ name = "ogryn_heavystubber_p2_m2", factor = 1.25 },
	{ name = "ogryn_heavystubber_p2_m3", factor = 1.25 },
	{ name = "bolter_p1_m1", factor = 4 / 3 },
	{ name = "bolter_p1_m2", factor = 4 / 3 },
}
local HEAVY_SWORD_TEMPLATES = {
	"combatsword_p2_m1",
	"combatsword_p2_m2",
	"combatsword_p2_m3",
}
local AMMO_TEMPLATES_PATH =
	"scripts/settings/equipment/weapon_handling_templates/weapon_ammo_templates"
local DODGE_TEMPLATES_PATH = "scripts/settings/dodge/weapon_dodge_templates"
local TRAINING_GROUNDS_VIEW_PATH =
	"scripts/ui/views/training_grounds_options_view/training_grounds_options_view"
local SHOOT_HIT_SCAN_ACTION_PATH =
	"scripts/extension_systems/weapon/actions/action_shoot_hit_scan"
local MELEE_EXPLOSIVE_ACTION_PATH =
	"scripts/extension_systems/weapon/actions/action_melee_explosive"
local MEAT_GRINDER_MISSION = "tg_shooting_range"

local SHOT_CYCLE = 1.8
local HITSCAN_RANGE = 120
local HOTSHOT_CLIP_SIZE = 4
local HOTSHOT_MOVEMENT_PENALTY = -0.15
local HOTSHOT_DAMAGE = { 800, 1300 }
local HOTSHOT_FINESSE = 5
local HOTSHOT_DODGE_TEMPLATE = "pilgrimage_hotshot_single_dodge"
local HOTSHOT_WIELD_BUFF = "pilgrim_weapon_hotshot_wield_penalty"

local KICKBACK_CLIP_SIZE = 2
local KICKBACK_DAMAGE_FACTOR = 1.35
local KICKBACK_RELOAD_TIME = 1.6
local KICKBACK_NATIVE_RELOAD_TIME = 2.333
local KICKBACK_RELOAD_TIME_SCALE = KICKBACK_NATIVE_RELOAD_TIME
	/ KICKBACK_RELOAD_TIME
local KICKBACK_RELOAD_SPEED_BONUS = KICKBACK_RELOAD_TIME_SCALE - 1
local KICKBACK_WIELD_BUFF = "pilgrim_weapon_kickback_reload_speed"
local SHREDDER_CLEAVE = { 1.5, 3 }
local POWER_MAUL_COOLDOWN = 3
local PLASMA_CANNON_PRIMARY_AMMO = 5
local PLASMA_CANNON_CHARGED_AMMO_MIN = 4
local PLASMA_CANNON_CHARGED_AMMO_MAX = 16
local PLASMA_CANNON_CHARGED_DAMAGE = 2
local PLASMA_CANNON_EXPLOSION_DAMAGE = 1.5
local PLASMA_CANNON_IMPACT = 2
local PLASMA_CANNON_CARAPACE = 2
local PLASMA_CANNON_PENETRATION_DEPTH = 4
local PLASMA_CANNON_RADIUS = 7
local PLASMA_CANNON_CLOSE_RADIUS = 4.5
local PLASMA_CANNON_MIN_RADIUS = 5.5
local PLASMA_CANNON_MIN_CLOSE_RADIUS = 4
local PLASMA_CANNON_WIELD_PENALTY = -0.15
local PLASMA_CANNON_DODGE_TEMPLATE =
	"pilgrimage_plasma_cannon_single_dodge"
local PLASMA_CANNON_WIELD_BUFF = "pilgrim_weapon_plasma_cannon_wield_penalty"
local PLASMA_PISTOL_CLIP_SIZE = 15
local PLASMA_PISTOL_RESERVE = 60
local PLASMA_PISTOL_SHOT_CYCLE = 0.65
local PLASMA_PISTOL_HEAT_PER_SHOT = 0.145
local PLASMA_PISTOL_COOLING_DELAY = 2
local PLASMA_PISTOL_VENT_DURATION = 4
local PLASMA_PISTOL_RANGE = 80
local PLASMA_PISTOL_PENETRATION = 1.25
local PLASMA_PISTOL_DAMAGE = { 350, 700 }
local PLASMA_PISTOL_IMPACT = { 30, 60 }
local PLASMA_PISTOL_FINESSE = 0.5
local PLASMA_PISTOL_RADIUS = 2
local PLASMA_PISTOL_CLOSE_RADIUS = 0.75
local PLASMA_PISTOL_MIN_RADIUS = 1.5
local PLASMA_PISTOL_MIN_CLOSE_RADIUS = 0.5
local VINDICATOR_DAMAGE_FACTOR = 1.15
local VINDICATOR_IMPACT_FACTOR = 1.5
local VINDICATOR_ACCUMULATIVE_STAGGER = 1
local VINDICATOR_CLIP_FACTOR = 3
local VINDICATOR_RESERVE_FACTOR = 2
local VINDICATOR_SHOVE_DAMAGE_FACTOR = 4
local VINDICATOR_SHOVE_IMPACT_FACTOR = 2
local VINDICATOR_SHOVE_BLEED = 6
local VINDICATOR_BRITTLENESS_BUFF = "rending_burn_debuff"
local VINDICATOR_BURN_BUFF = "flamer_assault"
local VINDICATOR_FLAMER_ACTION_PATH =
	"scripts/extension_systems/weapon/actions/action_flamer_gas"
local VINDICATOR_FLAMER_BURST_ACTION_PATH =
	"scripts/extension_systems/weapon/actions/action_flamer_gas_burst"
local VINDICATOR_PUSH_ACTION_PATH =
	"scripts/extension_systems/weapon/actions/action_push"
local VINDICATOR_CHAIN_SWING_SOUND =
	"wwise/events/weapon/play_combat_weapon_chainsword_swing"
local HUNTER_STUBBER_DAMAGE_FACTOR = 1.18
local HUNTER_STUBBER_IMPACT_FACTOR = 1.5
local HUNTER_STUBBER_AIMED_SHOT_CYCLE = 0.4
local GRENADIER_GAUNTLET_DAMAGE_PER_SHELL = 2.25
local GRENADIER_GAUNTLET_CARAPACE_FACTOR = 2
local RIPPER_DAMAGE_FACTOR = 1.2
local RIPPER_CLEAVE_FACTOR = 1.5
local OGRYN_RANGED_RELOAD_SPEED_BONUS = 0.25
local OGRYN_RANGED_RELOAD_BUFF = "pilgrim_weapon_ogryn_ranged_reload_speed"
-- Keep the growing weapon catalogue inside one table. Lua 5.1 limits each
-- function, including a file's top-level chunk, to 200 active locals. One
-- table preserves readable names while consuming only one local slot.
local TUNING = {
	HEAVY_SWORD_LIGHT_DAMAGE = 1.25,
	HEAVY_SWORD_HEAVY_DAMAGE = 1.35,
	HEAVY_SWORD_SPECIAL_DAMAGE = 1.5,
	HEAVY_SWORD_LATER_TARGET_DAMAGE = 1.5,
	HEAVY_SWORD_CLEAVE = 1.25,
	HEAVY_SWORD_FLAK = 1.25,
	HEAVY_SWORD_LIGHT_CARAPACE = 1.5,
	HEAVY_SWORD_COMMITTED_CARAPACE = 2,
	THUNDER_HAMMER_EXECUTION_UNPOWERED_DAMAGE = 1.15,
	THUNDER_HAMMER_EXECUTION_UNPOWERED_IMPACT = 1.50,
	THUNDER_HAMMER_EXECUTION_UNPOWERED_IMPACT_CLEAVE = 1.50,
	THUNDER_HAMMER_EXECUTION_POWERED_DAMAGE = 1.20,
	THUNDER_HAMMER_LINE_ACTIVE_DURATION = 8,
	THUNDER_HAMMER_LINE_COOLDOWN = 6,
	THUNDER_HAMMER_LINE_SPECIAL_CLASS =
		"PilgrimageWeaponSpecialTimedCooldown",
	THUNDER_HAMMER_LINE_COUNTER_TYPE = "pilgrimage_timed_mode",
	POWER_SWORD_ACTIVE_DURATION = 5,
	POWER_SWORD_COOLDOWN = 8,
	POWER_SWORD_SECONDS_PER_EXTRA_ACTIVATION = 1.5,
	CHAIN_WEAPON_ACTIVE_DURATION = 8,
	CHAIN_WEAPON_COOLDOWN = 4.5,
	TIMED_SPECIAL_CLASS = "PilgrimageWeaponSpecialTimedCooldown",
	PERSISTENT_SHOVEL_SPECIAL_CLASS =
		"PilgrimageWeaponSpecialPersistentShovel",
	TIMED_MODE_COUNTER_TYPE = "pilgrimage_timed_mode",
	CHAIN_STAGGER_MARKER = "pilgrimage_chain_latched_stagger",
	STAGGER_CALCULATION_PATH =
		"scripts/utilities/attack/stagger_calculation",
}

-- WeaponTweakTemplates resolves this private source under the mark's existing
-- `base_killshot` component identifier. The source name itself is therefore
-- not serialized or added to a network component lookup.
local HOTSHOT_DODGE_SOURCE = {
	consecutive_dodges_reset = 0,
	distance_scale = {
		lerp_basic = 0.65,
		lerp_perfect = 0.85,
	},
	diminishing_return_distance_modifier = {
		lerp_basic = 0.25,
		lerp_perfect = 0.25,
	},
	diminishing_return_start = {
		lerp_basic = 1,
		lerp_perfect = 1,
	},
	diminishing_return_limit = {
		lerp_basic = 1,
		lerp_perfect = 1,
	},
	speed_modifier = {
		lerp_basic = 1.1,
		lerp_perfect = 1.15,
	},
}

-- The cannon is deliberately as committed as the Hotshot prototype. It keeps
-- one full-strength dodge, then immediately reaches its diminishing-return
-- floor until that dodge has recovered.
local PLASMA_CANNON_DODGE_SOURCE = {
	consecutive_dodges_reset = 0,
	distance_scale = {
		lerp_basic = 0.65,
		lerp_perfect = 0.85,
	},
	diminishing_return_distance_modifier = {
		lerp_basic = 0.25,
		lerp_perfect = 0.25,
	},
	diminishing_return_start = {
		lerp_basic = 1,
		lerp_perfect = 1,
	},
	diminishing_return_limit = {
		lerp_basic = 1,
		lerp_perfect = 1,
	},
	speed_modifier = {
		lerp_basic = 1.1,
		lerp_perfect = 1.15,
	},
}

local DOUBLE_BARREL = {
	name = "shotgun_p2_m1",
	reload_buff = "pilgrim_weapon_double_barrel_reload_speed",
	reload_speed_bonus = 2.8 / 1.8 - 1,
	kickback_gap = 0.45,
	spread_factor = 0.85,
	carapace_factor = 1.4,
}

local WEAPON_BUFF_TEMPLATES = {
	{
		id = "weapon_double_barrel_reload_speed",
		buff_template = DOUBLE_BARREL.reload_buff,
		custom = { stat_buffs = { reload_speed = DOUBLE_BARREL.reload_speed_bonus } },
	},
	{
		id = "weapon_hotshot_wield_penalty",
		buff_template = HOTSHOT_WIELD_BUFF,
		custom = {
			stat_buffs = {
				movement_speed = HOTSHOT_MOVEMENT_PENALTY,
			},
		},
	},
	{
		id = "weapon_kickback_reload_speed",
		buff_template = KICKBACK_WIELD_BUFF,
		custom = {
			stat_buffs = {
				reload_speed = KICKBACK_RELOAD_SPEED_BONUS,
			},
		},
	},
	{
		id = "weapon_plasma_cannon_wield_penalty",
		buff_template = PLASMA_CANNON_WIELD_BUFF,
		custom = {
			stat_buffs = {
				movement_speed = PLASMA_CANNON_WIELD_PENALTY,
			},
		},
	},
	{
		id = "weapon_ogryn_ranged_reload_speed",
		buff_template = OGRYN_RANGED_RELOAD_BUFF,
		custom = {
			stat_buffs = {
				reload_speed = OGRYN_RANGED_RELOAD_SPEED_BONUS,
			},
		},
	},
}

local _weapon_templates
local _ammo_templates
local _dodge_templates
local _pending = false
local _applied = false
local _restore
local _melta
local _scope
local _training_grounds_hook_installed = false
local _preserve_next_gameplay_exit = false
local _vindicator_brittleness_hooks_installed = false
local _vindicator_brittleness_stacks = 0
local _plasma_pistol_heat_hook_installed = false
local _plasma_pistol_heat_events = 0
local _grenadier_gauntlet_hook_installed = false
local _grenadier_gauntlet_mag_dumps = 0
local _chain_stagger_hook_installed = false

local function shallow_copy(source)
	if type(source) ~= "table" then return source end
	local out = {}
	for key, value in pairs(source) do out[key] = value end
	return out
end

local function fixed_pair(value)
	return { value, value }
end

-- Copy only a branch that is about to change. This is deliberately not a full
-- profile clone: untouched sub-tables retain their original identity, while no
-- changed number remains reachable from another weapon mark.
local function scaled_branch(value, factor)
	if type(value) == "number" then return value * factor end
	if type(value) ~= "table" then return value end

	local out = {}
	for key, child in pairs(value) do
		out[key] = scaled_branch(child, factor)
	end
	return out
end

local function owned_power_distribution(original, factor, impact_factor)
	if type(original) ~= "table" then return original end
	local owned = shallow_copy(original)
	if owned.attack ~= nil then
		owned.attack = scaled_branch(original.attack, factor)
	end
	if impact_factor and owned.impact ~= nil then
		owned.impact = scaled_branch(original.impact, impact_factor)
	end
	return owned
end

local function owned_cleave_distribution(original, factor,
		impact_factor)
	if type(original) ~= "table" then return original end
	local owned = shallow_copy(original)
	if factor and original.attack ~= nil then
		owned.attack = scaled_branch(original.attack, factor)
	end
	if impact_factor and original.impact ~= nil then
		owned.impact = scaled_branch(original.impact, impact_factor)
	end
	return owned
end

local function owned_armour_modifier(original, flak_factor, carapace_factor)
	if type(original) ~= "table" then return original end
	local owned = shallow_copy(original)
	if type(original.attack) == "table" then
		owned.attack = shallow_copy(original.attack)
		if original.attack.armored ~= nil then
			owned.attack.armored = scaled_branch(original.attack.armored, flak_factor)
		end
		if original.attack.super_armor ~= nil then
			owned.attack.super_armor = scaled_branch(
				original.attack.super_armor, carapace_factor)
		end
	end
	return owned
end

local function build_attack_profile(original, damage_factor, options)
	if type(original) ~= "table" then return nil end
	options = options or {}
	local profile = shallow_copy(original)

	if type(original.power_distribution) == "table" then
		profile.power_distribution = owned_power_distribution(
			original.power_distribution, damage_factor,
			options.impact_factor)
	end

	local original_targets = original.targets
	if type(original_targets) == "table" then
		profile.targets = shallow_copy(original_targets)
		local has_numbered_targets = type(original_targets[1]) == "table"
		for target_key, original_target in pairs(original_targets) do
			if type(original_target) == "table" then
				local target = shallow_copy(original_target)
				profile.targets[target_key] = target
				local target_factor = damage_factor
				if has_numbered_targets and target_key ~= 1 then
					target_factor = target_factor
						* (options.later_target_factor or 1)
				end
				if type(original_target.power_distribution) == "table" then
					target.power_distribution = owned_power_distribution(
						original_target.power_distribution, target_factor,
						options.impact_factor)
				end
				if type(original_target.armor_damage_modifier) == "table" then
					target.armor_damage_modifier = owned_armour_modifier(
						original_target.armor_damage_modifier,
						options.flak_factor or 1,
						options.carapace_factor or 1)
				end
			end
		end
	end

	if type(original.armor_damage_modifier) == "table" then
		profile.armor_damage_modifier = owned_armour_modifier(
			original.armor_damage_modifier,
			options.flak_factor or 1,
			options.carapace_factor or 1)
	end

	if type(original.cleave_distribution) == "table"
		and (options.cleave_factor or options.impact_cleave_factor) then
		profile.cleave_distribution = owned_cleave_distribution(
			original.cleave_distribution, options.cleave_factor,
			options.impact_cleave_factor or options.cleave_factor)
	end

	return profile
end

local function append_unique(array, value)
	for i = 1, #array do
		if array[i] == value then return end
	end
	array[#array + 1] = value
end

local function build_wield_buff_bundle(template_name, template, buff_template)
	if type(template) ~= "table" then
		return nil, "missing " .. template_name .. " weapon template"
	end

	local original_buffs = template.buffs
	local owned_buffs = shallow_copy(original_buffs or {})
	owned_buffs.on_wield = shallow_copy(owned_buffs.on_wield or {})
	if #owned_buffs.on_wield >= 3 then
		return nil, template_name .. " has no free on-wield buff slot"
	end
	append_unique(owned_buffs.on_wield, buff_template)

	return {
		name = template_name,
		template = template,
		buffs = original_buffs,
		owned_buffs = owned_buffs,
	}
end

local function rounded_scaled(value, factor)
	return math.floor(value * factor + 0.5)
end

local function build_reserve_ammo_bundle(template_name, original, factor)
	local reserve = type(original) == "table" and original.ammunition_reserve
	if type(reserve) ~= "table"
		or type(reserve.lerp_basic) ~= "number"
		or type(reserve.lerp_perfect) ~= "number" then
		return nil, "unexpected " .. template_name .. " reserve ammunition shape"
	end

	local owned = shallow_copy(original)
	owned.ammunition_reserve = shallow_copy(reserve)
	owned.ammunition_reserve.lerp_basic =
		rounded_scaled(reserve.lerp_basic, factor)
	owned.ammunition_reserve.lerp_perfect =
		rounded_scaled(reserve.lerp_perfect, factor)

	return {
		name = template_name,
		ammo = original,
		owned_ammo = owned,
	}
end

local function set_armour_side(side, values)
	if type(side) ~= "table" then return end
	for armour_type, value in pairs(values) do
		if side[armour_type] ~= nil then
			side[armour_type] = fixed_pair(value)
		end
	end
end

local function own_ranged_armour(profile)
	local original = profile.armor_damage_modifier_ranged
	if type(original) ~= "table" then return nil end

	local owned = shallow_copy(original)
	profile.armor_damage_modifier_ranged = owned

	for _, distance in ipairs({ "near", "far" }) do
		local original_distance = owned[distance]
		if type(original_distance) == "table" then
			local owned_distance = shallow_copy(original_distance)
			owned[distance] = owned_distance
			if type(owned_distance.attack) == "table" then
				owned_distance.attack = shallow_copy(owned_distance.attack)
			end
			if type(owned_distance.impact) == "table" then
				owned_distance.impact = shallow_copy(owned_distance.impact)
			end
		end
	end

	return owned
end

local function build_hotshot_profile(original)
	local profile = shallow_copy(original)

	-- Keep ordinary hits below the delete-everything threshold. The Kasrkin
	-- capture has a 77% Damage roll, which Darktide resolves to a 0.635 lerp
	-- point and roughly 1,118 raw attack power with this range.
	profile.power_distribution = shallow_copy(original.power_distribution or {})
	profile.power_distribution.attack = HOTSHOT_DAMAGE
	profile.power_distribution.impact = { 80, 160 }

	profile.ranges = shallow_copy(original.ranges or {})
	profile.ranges.min = fixed_pair(30)
	profile.ranges.max = fixed_pair(70)

	local armour = own_ranged_armour(profile)
	if armour then
		set_armour_side(armour.near and armour.near.attack, {
			unarmored = 1.00,
			armored = 1.00,
			resistant = 0.60,
			player = 1.00,
			berserker = 1.00,
			super_armor = 0.75,
			disgustingly_resilient = 0.60,
			void_shield = 0.90,
		})
		set_armour_side(armour.far and armour.far.attack, {
			unarmored = 0.90,
			armored = 0.90,
			resistant = 0.55,
			player = 1.00,
			berserker = 0.90,
			super_armor = 0.70,
			disgustingly_resilient = 0.55,
			void_shield = 0.80,
		})
	end

	profile.targets = shallow_copy(original.targets or {})
	local original_default = profile.targets.default_target
	if type(original_default) == "table" then
		local default_target = shallow_copy(original_default)
		profile.targets.default_target = default_target
		default_target.boost_curve_multiplier_finesse =
			fixed_pair(HOTSHOT_FINESSE)
		-- Surgical supplies the certainty. The deliberately large finesse value
		-- moves the rifle's real payoff from body shots to aimed weakspot hits.
		default_target.crit_boost = 0.15
	end

	return profile
end

local function clone_shoot_action(original, repeat_input, owned_hitscan)
	local action = shallow_copy(original)
	action.total_time = SHOT_CYCLE

	action.allowed_chain_actions = shallow_copy(original.allowed_chain_actions or {})
	local original_chain = action.allowed_chain_actions[repeat_input]
	if type(original_chain) == "table" then
		local chained_action = shallow_copy(original_chain)
		chained_action.chain_time = SHOT_CYCLE
		action.allowed_chain_actions[repeat_input] = chained_action
	end

	action.fire_configuration = shallow_copy(original.fire_configuration or {})
	action.fire_configuration.hit_scan_template = owned_hitscan

	return action
end

local function build_hotshot_hitscan(original)
	local hitscan = shallow_copy(original)
	hitscan.range = HITSCAN_RANGE
	hitscan.damage = shallow_copy(original.damage or {})
	hitscan.damage.impact = shallow_copy(hitscan.damage.impact or {})
	local original_profile = hitscan.damage.impact.damage_profile
	if type(original_profile) ~= "table" then return nil end
	hitscan.damage.impact.damage_profile = build_hotshot_profile(original_profile)
	return hitscan
end

local function build_hunter_stubber_profile(original)
	local profile = build_attack_profile(
		original, HUNTER_STUBBER_DAMAGE_FACTOR)
	if not profile then return nil end

	-- The Achlys Mk II already owns a generous large-cleave bullet and three strong
	-- target entries. Keep that identity, but make the heavy round feel like it
	-- came from an Ogryn-scale marksman's weapon rather than a weak rifle shot.
	for target_key, original_target in pairs(original.targets or {}) do
		local target = profile.targets and profile.targets[target_key]
		local original_power = original_target
			and original_target.power_distribution
		if type(target) == "table" and type(original_power) == "table"
			and original_power.impact ~= nil then
			target.power_distribution = shallow_copy(
				target.power_distribution or original_power)
			target.power_distribution.impact = scaled_branch(
				original_power.impact, HUNTER_STUBBER_IMPACT_FACTOR)
		end
	end

	local armour = own_ranged_armour(profile)
	if armour then
		set_armour_side(armour.near and armour.near.attack, {
			unarmored = 1.00,
			armored = 1.00,
			resistant = 1.00,
			player = 1.00,
			berserker = 1.00,
			super_armor = 0.55,
			disgustingly_resilient = 0.90,
			void_shield = 0.90,
		})
		set_armour_side(armour.far and armour.far.attack, {
			unarmored = 0.90,
			armored = 0.90,
			resistant = 0.85,
			player = 1.00,
			berserker = 0.90,
			super_armor = 0.40,
			disgustingly_resilient = 0.80,
			void_shield = 0.80,
		})
	end

	return profile
end

local function build_hunter_stubber_hitscan(original)
	if type(original) ~= "table" then return nil end
	local hitscan = shallow_copy(original)
	hitscan.damage = shallow_copy(original.damage or {})
	hitscan.damage.impact = shallow_copy(hitscan.damage.impact or {})
	local original_profile = hitscan.damage.impact.damage_profile
	if type(original_profile) ~= "table" then return nil end
	hitscan.damage.impact.damage_profile =
		build_hunter_stubber_profile(original_profile)
	return hitscan.damage.impact.damage_profile and hitscan or nil
end

local function build_hunter_stubber_bundle(template)
	local actions = template and template.actions
	local hip = actions and actions.action_shoot_hip
	local aimed = actions and actions.action_shoot_zoomed
	local hip_hitscan = hip and hip.fire_configuration
		and hip.fire_configuration.hit_scan_template
	local aimed_hitscan = aimed and aimed.fire_configuration
		and aimed.fire_configuration.hit_scan_template
	if type(template) ~= "table" or type(hip) ~= "table"
		or type(aimed) ~= "table" or type(hip_hitscan) ~= "table"
		or type(aimed_hitscan) ~= "table" then
		return nil, "unexpected ogryn_heavystubber_p2_m3 shape"
	end

	local owned_hip_hitscan = build_hunter_stubber_hitscan(hip_hitscan)
	local owned_aimed_hitscan = hip_hitscan == aimed_hitscan
		and owned_hip_hitscan or build_hunter_stubber_hitscan(aimed_hitscan)
	if not owned_hip_hitscan or not owned_aimed_hitscan then
		return nil, "unexpected ogryn_heavystubber_p2_m3 damage profile"
	end

	local owned_hip = shallow_copy(hip)
	owned_hip.fire_configuration = shallow_copy(hip.fire_configuration or {})
	owned_hip.fire_configuration.hit_scan_template = owned_hip_hitscan

	local owned_aimed = shallow_copy(aimed)
	owned_aimed.total_time = HUNTER_STUBBER_AIMED_SHOT_CYCLE
	owned_aimed.allowed_chain_actions = shallow_copy(
		aimed.allowed_chain_actions or {})
	local repeat_shot = owned_aimed.allowed_chain_actions.zoom_shoot
	if type(repeat_shot) ~= "table" then
		return nil, "unexpected ogryn_heavystubber_p2_m3 aimed chain"
	end
	repeat_shot = shallow_copy(repeat_shot)
	repeat_shot.chain_time = HUNTER_STUBBER_AIMED_SHOT_CYCLE
	owned_aimed.allowed_chain_actions.zoom_shoot = repeat_shot
	owned_aimed.fire_configuration = shallow_copy(
		aimed.fire_configuration or {})
	owned_aimed.fire_configuration.hit_scan_template = owned_aimed_hitscan

	return {
		template = template,
		hip = hip,
		aimed = aimed,
		owned_hip = owned_hip,
		owned_aimed = owned_aimed,
	}
end

local clone_shotshell_action

local function build_ripper_profile(original, spec)
	local profile = build_attack_profile(original, RIPPER_DAMAGE_FACTOR, {
		cleave_factor = RIPPER_CLEAVE_FACTOR,
	})
	if not profile then return nil end

	local armour = own_ranged_armour(profile)
	if armour then
		set_armour_side(armour.near and armour.near.attack, spec.near)
		set_armour_side(armour.far and armour.far.attack, spec.far)
	end

	return profile
end

local function build_ripper_shotshell(original, spec)
	if type(original) ~= "table" then return nil end
	local owned = shallow_copy(original)
	owned.damage = shallow_copy(original.damage or {})
	owned.damage.impact = shallow_copy(owned.damage.impact or {})
	local original_profile = owned.damage.impact.damage_profile
	if type(original_profile) ~= "table" then return nil end
	owned.damage.impact.damage_profile = build_ripper_profile(
		original_profile, spec)
	return owned.damage.impact.damage_profile and owned or nil
end

local function build_ripper_bundle(spec, template)
	local actions = template and template.actions
	local hip = actions and actions.action_shoot_hip
	local zoom = actions and actions.action_shoot_zoomed
	local hip_shell = hip and hip.fire_configuration
		and hip.fire_configuration.shotshell
	local zoom_shell = zoom and zoom.fire_configuration
		and zoom.fire_configuration.shotshell
	if type(template) ~= "table" or type(hip) ~= "table"
		or type(zoom) ~= "table" or type(hip_shell) ~= "table"
		or type(zoom_shell) ~= "table" then
		return nil, "unexpected " .. spec.name .. " shotshell shape"
	end

	local owned_hip_shell = build_ripper_shotshell(hip_shell, spec)
	local owned_zoom_shell = hip_shell == zoom_shell and owned_hip_shell
		or build_ripper_shotshell(zoom_shell, spec)
	if not owned_hip_shell or not owned_zoom_shell then
		return nil, "unexpected " .. spec.name .. " damage profile"
	end

	local wield, wield_error = build_wield_buff_bundle(
		spec.name, template, OGRYN_RANGED_RELOAD_BUFF)
	if not wield then return nil, wield_error end

	return {
		name = spec.name,
		template = template,
		hip = hip,
		zoom = zoom,
		buffs = wield.buffs,
		owned_hip = clone_shotshell_action(hip, owned_hip_shell),
		owned_zoom = clone_shotshell_action(zoom, owned_zoom_shell),
		owned_buffs = wield.owned_buffs,
	}
end

clone_shotshell_action = function(original, owned_shotshell)
	local action = shallow_copy(original)
	action.fire_configuration = shallow_copy(original.fire_configuration or {})
	action.fire_configuration.shotshell = owned_shotshell
	return action
end

local function build_kickback_shotshell(original)
	if type(original) ~= "table" then return nil end
	local shotshell = shallow_copy(original)
	shotshell.damage = shallow_copy(original.damage or {})
	shotshell.damage.impact = shallow_copy(shotshell.damage.impact or {})
	local original_profile = shotshell.damage.impact.damage_profile
	if type(original_profile) ~= "table" then return nil end
	shotshell.damage.impact.damage_profile = build_attack_profile(
		original_profile, KICKBACK_DAMAGE_FACTOR)
	return shotshell
end

function DOUBLE_BARREL.kickback_cadence(action)
	action.total_time = math.max(action.total_time or 0, DOUBLE_BARREL.kickback_gap)
	action.allowed_chain_actions = shallow_copy(action.allowed_chain_actions or {})
	for key, chain in pairs(action.allowed_chain_actions) do
		if key == "shoot_pressed" or key == "zoom_shoot" then
			local owned = shallow_copy(chain)
			owned.chain_time = DOUBLE_BARREL.kickback_gap
			action.allowed_chain_actions[key] = owned
		end
	end
	local original_condition = action.action_condition_func
	action.action_condition_func = function(settings, params, used_input, t, time_in_action)
		-- Native ActionShoot updates this replicated timestamp while emitting
		-- pellets. A new action, aim toggle or fast reload must not erase it.
		local shooting = params and params.action_shoot_component
		local last = shooting and shooting.fire_last_t
		if type(last) == "number" and last > 0 and type(t) == "number"
			and t - last < DOUBLE_BARREL.kickback_gap then return false end
		if original_condition then
			return original_condition(settings, params, used_input, t, time_in_action)
		end
		return true
	end
	return action
end

local function build_kickback_bundle(template, original_ammo)
	local actions = template and template.actions
	local hip = actions and actions.action_shoot_hip
	local zoom = actions and actions.action_shoot_zoomed
	local reload = actions and actions.action_reload
	local hip_shell = hip and hip.fire_configuration
		and hip.fire_configuration.shotshell
	local zoom_shell = zoom and zoom.fire_configuration
		and zoom.fire_configuration.shotshell
	local original_buffs = template and template.buffs

	if type(template) ~= "table" or type(hip) ~= "table"
		or type(zoom) ~= "table" or type(reload) ~= "table"
		or type(hip_shell) ~= "table" or type(zoom_shell) ~= "table"
		or type(original_ammo) ~= "table" then
		return nil, "unexpected ogryn_thumper_p1_m1 shape"
	end

	local owned_hip_shell = build_kickback_shotshell(hip_shell)
	local owned_zoom_shell = hip_shell == zoom_shell
		and owned_hip_shell or build_kickback_shotshell(zoom_shell)
	if not owned_hip_shell or not owned_zoom_shell then
		return nil, "unexpected Kickback shotshell profile"
	end

	local ammo = shallow_copy(original_ammo)
	ammo.ammunition_clips = shallow_copy(original_ammo.ammunition_clips or {})
	local original_clip = ammo.ammunition_clips[1]
	if type(original_clip) ~= "table" then
		return nil, "unexpected Kickback ammo shape"
	end
	ammo.ammunition_clips[1] = shallow_copy(original_clip)
	ammo.ammunition_clips[1].lerp_basic = KICKBACK_CLIP_SIZE
	ammo.ammunition_clips[1].lerp_perfect = KICKBACK_CLIP_SIZE

	local buffs = shallow_copy(original_buffs or {})
	buffs.on_wield = shallow_copy(buffs.on_wield or {})
	if #buffs.on_wield >= 3 then
		return nil, "ogryn_thumper_p1_m1 has no free on-wield buff slot"
	end
	append_unique(buffs.on_wield, KICKBACK_WIELD_BUFF)

	return {
		template = template,
		hip = hip,
		zoom = zoom,
		reload = reload,
		ammo = original_ammo,
		buffs = original_buffs,
		owned_hip = DOUBLE_BARREL.kickback_cadence(clone_shotshell_action(hip, owned_hip_shell)),
		owned_zoom = DOUBLE_BARREL.kickback_cadence(clone_shotshell_action(zoom, owned_zoom_shell)),
		owned_ammo = ammo,
		owned_buffs = buffs,
	}
end

function DOUBLE_BARREL.shell(original, factor)
	if type(original) ~= "table" then return nil end
	local shell = shallow_copy(original)
	for _, key in ipairs({"spread_pitch", "spread_yaw", "scatter_range"}) do
		if type(original[key]) == "number" then shell[key] = original[key] * DOUBLE_BARREL.spread_factor end
	end
	shell.damage = shallow_copy(original.damage or {})
	shell.damage.impact = shallow_copy(shell.damage.impact or {})
	local impact = shell.damage.impact
	local function profile(value)
		local p = build_attack_profile(value, factor, {
			impact_factor = 1.25, cleave_factor = 1.5,
		})
		if not p then return nil end
		p.pilgrimage_double_barrel_execute = true
		local armour = value.armor_damage_modifier_ranged
		if armour and armour.near and armour.near.attack then
			p.armor_damage_modifier_ranged = shallow_copy(armour)
			p.armor_damage_modifier_ranged.near = shallow_copy(armour.near)
			p.armor_damage_modifier_ranged.near.attack = shallow_copy(armour.near.attack)
			p.armor_damage_modifier_ranged.near.attack.super_armor = scaled_branch(
				armour.near.attack.super_armor, DOUBLE_BARREL.carapace_factor)
		end
		return p
	end
	impact.damage_profile = profile(impact.damage_profile)
	if not impact.damage_profile then return nil end
	-- The high-pellet-contact gore variant is a separate damage route.
	for i, entry in ipairs(impact) do
		impact[i] = shallow_copy(entry)
		impact[i].damage_profile = profile(entry.damage_profile)
		if not impact[i].damage_profile then return nil end
	end
	return shell
end

function DOUBLE_BARREL.movement(original)
	local curve = shallow_copy(original or {})
	curve.start_modifier = math.max(curve.start_modifier or 1, 0.85)
	for i, point in ipairs(curve) do
		curve[i] = shallow_copy(point)
		curve[i].modifier = math.max(point.modifier or 1, 0.85)
	end
	return curve
end

function DOUBLE_BARREL.build(template, ammo)
	local actions = template and template.actions
	if not actions or not actions.action_shoot_hip or not actions.action_shoot_zoomed
		or not actions.action_reload or not template.reload_template then
		return nil, "unexpected Double Barrel action/reload shape"
	end
	local bundle, err = build_wield_buff_bundle(DOUBLE_BARREL.name, template, DOUBLE_BARREL.reload_buff)
	if not bundle then return nil, err end
	local reserves, ammo_err = build_reserve_ammo_bundle(DOUBLE_BARREL.name, ammo, 1.2)
	if not reserves then return nil, ammo_err end
	bundle.ammo, bundle.owned_ammo = ammo, reserves.owned_ammo
	bundle.actions, bundle.owned_actions = actions, shallow_copy(actions)
	local function crosshair(original)
		if type(original) ~= "table" or original.crosshair_type ~= "shotgun" then return original end
		local owned = shallow_copy(original)
		owned.pilgrimage_double_barrel_spread = DOUBLE_BARREL.spread_factor
		return owned
	end
	bundle.crosshair = template.crosshair
	bundle.owned_crosshair = crosshair(template.crosshair)
	bundle.alternate = template.alternate_fire_settings
	if bundle.alternate then
		bundle.owned_alternate = shallow_copy(bundle.alternate)
		bundle.owned_alternate.crosshair = crosshair(bundle.alternate.crosshair)
	end
	for name, original in pairs(actions) do
		if original.crosshair and original.crosshair.crosshair_type == "shotgun" then
			bundle.owned_actions[name] = shallow_copy(original)
			bundle.owned_actions[name].crosshair = crosshair(original.crosshair)
		end
	end
	for _, name in ipairs({ "action_shoot_hip", "action_shoot_zoomed", "action_reload" }) do
		local original = actions[name]
		local action = shallow_copy(bundle.owned_actions[name])
		bundle.owned_actions[name] = action
		action.action_movement_curve = DOUBLE_BARREL.movement(original.action_movement_curve)
		action.allowed_chain_actions = shallow_copy(original.allowed_chain_actions or {})
		if name ~= "action_reload" then
			local config = original.fire_configuration
			if not config then return nil, "missing Double Barrel firing configuration" end
			action.fire_configuration = shallow_copy(config)
			action.fire_configuration.shotshell = DOUBLE_BARREL.shell(config.shotshell, 1.25)
			if not action.fire_configuration.shotshell then return nil, "missing Double Barrel single profile" end
			if name == "action_shoot_zoomed" then
				action.fire_configuration.shotshell_special = DOUBLE_BARREL.shell(config.shotshell_special, 1.15)
				if not action.fire_configuration.shotshell_special then return nil, "missing Double Barrel dual profile" end
			end
			local function chain(key, time)
				local entry = action.allowed_chain_actions[key]
				if type(entry) ~= "table" then return false end
				entry = shallow_copy(entry)
				entry.chain_time = time
				action.allowed_chain_actions[key] = entry
				return true
			end
			if not chain("reload", name == "action_shoot_hip" and 0.25 or 0.35) then
				return nil, "missing Double Barrel reload chain"
			end
			if name == "action_shoot_hip" and not chain("shoot_pressed", 0.30) then
				return nil, "missing Double Barrel single-shot chain"
			end
		end
	end
	-- Retain native reload actions/states and animation events. The on-wield
	-- reload stat scales their shared clock; do not truncate total_time.
	return bundle
end

local function build_shredder_hitscan(original)
	if type(original) ~= "table" then return nil end
	local hitscan = shallow_copy(original)
	hitscan.damage = shallow_copy(original.damage or {})
	hitscan.damage.impact = shallow_copy(hitscan.damage.impact or {})
	local original_profile = hitscan.damage.impact.damage_profile
	if type(original_profile) ~= "table" then return nil end

	local profile = shallow_copy(original_profile)
	profile.cleave_distribution = {
		attack = shallow_copy(SHREDDER_CLEAVE),
		impact = shallow_copy(SHREDDER_CLEAVE),
	}
	hitscan.damage.impact.damage_profile = profile
	return hitscan
end

local function clone_hitscan_action(original, owned_hitscan)
	local action = shallow_copy(original)
	action.fire_configuration = shallow_copy(original.fire_configuration or {})
	action.fire_configuration.hit_scan_template = owned_hitscan
	return action
end

local function build_shredder_bundle(template)
	local actions = template and template.actions
	local hip = actions and actions.action_shoot_hip
	local zoom = actions and actions.action_shoot_zoomed
	local hip_hitscan = hip and hip.fire_configuration
		and hip.fire_configuration.hit_scan_template
	local zoom_hitscan = zoom and zoom.fire_configuration
		and zoom.fire_configuration.hit_scan_template

	if type(template) ~= "table" or type(hip) ~= "table"
		or type(zoom) ~= "table" or type(hip_hitscan) ~= "table"
		or type(zoom_hitscan) ~= "table" then
		return nil, "unexpected autopistol_p1_m1 shape"
	end

	local owned_hip_hitscan = build_shredder_hitscan(hip_hitscan)
	local owned_zoom_hitscan = hip_hitscan == zoom_hitscan
		and owned_hip_hitscan or build_shredder_hitscan(zoom_hitscan)
	if not owned_hip_hitscan or not owned_zoom_hitscan then
		return nil, "unexpected Shredder hitscan profile"
	end

	return {
		template = template,
		hip = hip,
		zoom = zoom,
		owned_hip = clone_hitscan_action(hip, owned_hip_hitscan),
		owned_zoom = clone_hitscan_action(zoom, owned_zoom_hitscan),
	}
end

local function owned_armour_attack(original, factors)
	if type(original) ~= "table" then return original end
	local owned = shallow_copy(original)

	if type(original.attack) == "table" then
		owned.attack = shallow_copy(original.attack)
		for armour_type, factor in pairs(factors or {}) do
			if original.attack[armour_type] ~= nil then
				owned.attack[armour_type] = scaled_branch(
					original.attack[armour_type], factor)
			end
		end
	end

	for _, distance in ipairs({ "near", "far" }) do
		if type(original[distance]) == "table" then
			owned[distance] = owned_armour_attack(original[distance], factors)
		end
	end

	return owned
end

local function build_plasma_cannon_profile(original, attack_factor,
		impact_factor, carapace_factor)
	if type(original) ~= "table" then return nil end
	local profile = shallow_copy(original)

	for _, field in ipairs({ "power_distribution", "power_distribution_ranged" }) do
		local distribution = original[field]
		if type(distribution) == "table" then
			local owned = shallow_copy(distribution)
			if distribution.attack ~= nil then
				owned.attack = scaled_branch(distribution.attack, attack_factor)
			end
			if distribution.impact ~= nil then
				owned.impact = scaled_branch(distribution.impact, impact_factor)
			end
			profile[field] = owned
		end
	end

	for _, field in ipairs({ "armor_damage_modifier", "armor_damage_modifier_ranged" }) do
		if type(original[field]) == "table" then
			profile[field] = owned_armour_attack(original[field], {
				super_armor = carapace_factor,
			})
		end
	end

	profile.ragdoll_push_force = math.max(original.ragdoll_push_force or 0, 1000)
	profile.damage_type = "plasma"
	return profile
end

local function build_plasma_cannon_explosion(original)
	if type(original) ~= "table"
		or type(original.close_damage_profile) ~= "table"
		or type(original.damage_profile) ~= "table" then
		return nil
	end

	local explosion = shallow_copy(original)
	explosion.close_radius = PLASMA_CANNON_CLOSE_RADIUS
	explosion.min_close_radius = PLASMA_CANNON_MIN_CLOSE_RADIUS
	explosion.min_radius = PLASMA_CANNON_MIN_RADIUS
	explosion.radius = PLASMA_CANNON_RADIUS
	explosion.close_damage_profile = build_plasma_cannon_profile(
		original.close_damage_profile,
		PLASMA_CANNON_EXPLOSION_DAMAGE,
		PLASMA_CANNON_IMPACT,
		1)
	explosion.damage_profile = build_plasma_cannon_profile(
		original.damage_profile,
		PLASMA_CANNON_EXPLOSION_DAMAGE,
		PLASMA_CANNON_IMPACT,
		1)
	explosion.close_damage_type = "plasma"
	explosion.damage_type = "plasma_heavy"
	return explosion
end

local function build_plasma_cannon_hitscan(original)
	local impact = original and original.damage and original.damage.impact
	local penetration = original and original.damage and original.damage.penetration
	local armour_explosions = impact and impact.armor_explosion
	local original_explosion = type(armour_explosions) == "table"
		and select(2, next(armour_explosions))
	local original_profile = impact and impact.damage_profile

	if type(original) ~= "table" or type(impact) ~= "table"
		or type(penetration) ~= "table"
		or type(original_profile) ~= "table"
		or type(original_explosion) ~= "table" then
		return nil
	end

	local owned_explosion = build_plasma_cannon_explosion(original_explosion)
	if not owned_explosion then return nil end

	local hitscan = shallow_copy(original)
	hitscan.damage = shallow_copy(original.damage)
	hitscan.damage.impact = shallow_copy(impact)
	hitscan.damage.impact.damage_profile = build_plasma_cannon_profile(
		original_profile,
		PLASMA_CANNON_CHARGED_DAMAGE,
		PLASMA_CANNON_IMPACT,
		PLASMA_CANNON_CARAPACE)
	hitscan.damage.impact.armor_explosion = {}
	for armour_type in pairs(armour_explosions) do
		hitscan.damage.impact.armor_explosion[armour_type] = owned_explosion
	end
	hitscan.damage.penetration = shallow_copy(penetration)
	hitscan.damage.penetration.depth = PLASMA_CANNON_PENETRATION_DEPTH
	return hitscan
end

local function plasma_cannon_movement_curve(recovery_time)
	return {
		{ modifier = 0.1, t = 0.15 },
		{ modifier = 0.1, t = recovery_time - 0.15 },
		{ modifier = 1, t = recovery_time },
		start_modifier = 0.15,
	}
end

local function build_plasma_cannon_bundle(template)
	local actions = template and template.actions
	local direct_charge = actions and actions.action_charge_direct
	local primary = actions and actions.action_shoot
	local charge = actions and actions.action_charge
	local charged = actions and actions.action_shoot_charged
	local charged_hitscan = charged and charged.fire_configuration
		and charged.fire_configuration.hit_scan_template
	local original_buffs = template and template.buffs
	local original_lookup = template and template.__base_template_lookup
	local original_charge_lookup = type(original_lookup) == "table"
		and original_lookup.charge
	local original_direct_charge_entry = type(original_charge_lookup) == "table"
		and original_charge_lookup.action_charge_direct
	local original_heavy_charge_entry = type(original_charge_lookup) == "table"
		and original_charge_lookup.action_charge
	local original_dodge_lookup = type(original_lookup) == "table"
		and original_lookup.dodge
	local original_dodge_base = type(original_dodge_lookup) == "table"
		and original_dodge_lookup.base

	if type(template) ~= "table" or type(direct_charge) ~= "table"
		or type(primary) ~= "table" or type(charge) ~= "table"
		or type(charged) ~= "table" or type(charged_hitscan) ~= "table"
		or type(original_direct_charge_entry) ~= "table"
		or type(original_direct_charge_entry.new_identifier) ~= "string"
		or type(original_heavy_charge_entry) ~= "table"
		or type(original_heavy_charge_entry.new_identifier) ~= "string"
		or type(original_dodge_base) ~= "table"
		or type(original_dodge_base.new_identifier) ~= "string" then
		return nil, "unexpected plasmagun_p1_m2 shape"
	end

	local owned_hitscan = build_plasma_cannon_hitscan(charged_hitscan)
	if not owned_hitscan then
		return nil, "unexpected plasmagun_p1_m2 charged damage shape"
	end

	local owned_direct_charge = shallow_copy(direct_charge)

	local owned_primary = shallow_copy(primary)
	owned_primary.ammunition_usage_min = PLASMA_CANNON_PRIMARY_AMMO
	owned_primary.ammunition_usage_max = PLASMA_CANNON_PRIMARY_AMMO
	owned_primary.total_time = 0.75
	owned_primary.action_movement_curve = plasma_cannon_movement_curve(0.75)

	local owned_charge = shallow_copy(charge)
	owned_charge.action_movement_curve = {
		{ modifier = 0.15, t = 0.15 },
		{ modifier = 0.1, t = 0.5 },
		{ modifier = 0.1, t = 1.5 },
		start_modifier = 0.2,
	}
	owned_charge.allowed_chain_actions = shallow_copy(
		charge.allowed_chain_actions or {})
	if type(charge.allowed_chain_actions
		and charge.allowed_chain_actions.shoot_braced) == "table" then
		owned_charge.allowed_chain_actions.shoot_braced = shallow_copy(
			charge.allowed_chain_actions.shoot_braced)
		owned_charge.allowed_chain_actions.shoot_braced.chain_time = 0.9
	end

	local owned_charged = shallow_copy(charged)
	owned_charged.allowed_during_sprint = false
	owned_charged.ammunition_usage_min = PLASMA_CANNON_CHARGED_AMMO_MIN
	owned_charged.ammunition_usage_max = PLASMA_CANNON_CHARGED_AMMO_MAX
	owned_charged.total_time = 0.9
	owned_charged.sprint_ready_up_time = 0.6
	owned_charged.action_movement_curve = plasma_cannon_movement_curve(0.9)
	owned_charged.fire_configuration = shallow_copy(
		charged.fire_configuration or {})
	owned_charged.fire_configuration.hit_scan_template = owned_hitscan

	local buffs = shallow_copy(original_buffs or {})
	buffs.on_wield = shallow_copy(buffs.on_wield or {})
	if #buffs.on_wield >= 3 then
		return nil, "plasmagun_p1_m2 has no free on-wield buff slot"
	end
	append_unique(buffs.on_wield, PLASMA_CANNON_WIELD_BUFF)

	-- Keep the game's resolved component identifiers and redirect only this
	-- mark's private source lookups. Replacing an action's charge-template name
	-- after preprocessing can point at a key that an equipped weapon instance
	-- never constructed, especially after an in-level loadout swap.
	local owned_lookup = shallow_copy(original_lookup)
	local owned_charge_lookup = shallow_copy(original_charge_lookup)
	local owned_direct_charge_entry = shallow_copy(original_direct_charge_entry)
	local owned_heavy_charge_entry = shallow_copy(original_heavy_charge_entry)
	owned_direct_charge_entry.base_identifier =
		"plasmagun_p1_m2_charge_direct"
	owned_heavy_charge_entry.base_identifier = "plasmagun_p1_m2_charge"
	owned_charge_lookup.action_charge_direct = owned_direct_charge_entry
	owned_charge_lookup.action_charge = owned_heavy_charge_entry
	owned_lookup.charge = owned_charge_lookup

	-- The dodge redirect follows the same private-lookup rule and avoids
	-- changing the shared Plasma Rifle dodge template used by Mk I.
	local owned_dodge_lookup = shallow_copy(original_dodge_lookup)
	local owned_dodge_base = shallow_copy(original_dodge_base)
	owned_dodge_base.base_identifier = PLASMA_CANNON_DODGE_TEMPLATE
	owned_dodge_lookup.base = owned_dodge_base
	owned_lookup.dodge = owned_dodge_lookup

	return {
		template = template,
		direct_charge = direct_charge,
		primary = primary,
		charge = charge,
		charged = charged,
		buffs = original_buffs,
		base_template_lookup = original_lookup,
		dodge_source = _dodge_templates[PLASMA_CANNON_DODGE_TEMPLATE],
		owned_direct_charge = owned_direct_charge,
		owned_primary = owned_primary,
		owned_charge = owned_charge,
		owned_charged = owned_charged,
		owned_buffs = buffs,
		owned_lookup = owned_lookup,
	}
end

local function build_plasma_pistol_profile(original)
	if type(original) ~= "table" then return nil end
	local profile = shallow_copy(original)
	profile.power_distribution = shallow_copy(original.power_distribution or {})
	profile.power_distribution.attack = shallow_copy(PLASMA_PISTOL_DAMAGE)
	profile.power_distribution.impact = shallow_copy(PLASMA_PISTOL_IMPACT)
	profile.ranges = shallow_copy(original.ranges or {})
	profile.ranges.min = fixed_pair(15)
	profile.ranges.max = fixed_pair(40)

	local armour = own_ranged_armour(profile)
	if armour then
		set_armour_side(armour.near and armour.near.attack, {
			unarmored = 1,
			armored = 1,
			resistant = 1.5,
			player = 1,
			berserker = 1.25,
			super_armor = 0.75,
			disgustingly_resilient = 1,
			void_shield = 1,
		})
		set_armour_side(armour.far and armour.far.attack, {
			unarmored = 0.9,
			armored = 0.9,
			resistant = 1.35,
			player = 1,
			berserker = 1.1,
			super_armor = 0.6,
			disgustingly_resilient = 0.9,
			void_shield = 0.9,
		})
	end

	profile.targets = shallow_copy(original.targets or {})
	local original_default = profile.targets.default_target
	if type(original_default) == "table" then
		local default_target = shallow_copy(original_default)
		profile.targets.default_target = default_target
		default_target.boost_curve_multiplier_finesse =
			fixed_pair(PLASMA_PISTOL_FINESSE)
	end
	profile.ignore_shield = true
	profile.damage_type = "plasma"
	return profile
end

local function build_plasma_pistol_explosion_profile(original, close)
	if type(original) ~= "table" then return nil end
	local profile = shallow_copy(original)
	local distribution = original.power_distribution_ranged
	if type(distribution) == "table" then
		profile.power_distribution_ranged = shallow_copy(distribution)
		profile.power_distribution_ranged.attack = close
			and { far = 120, near = 180 }
			or { far = 40, near = 90 }
		profile.power_distribution_ranged.impact = close
			and { far = 20, near = 30 }
			or { far = 8, near = 16 }
	elseif type(original.power_distribution) == "table" then
		profile.power_distribution = shallow_copy(original.power_distribution)
		profile.power_distribution.attack = close and fixed_pair(180)
			or fixed_pair(70)
		profile.power_distribution.impact = close and fixed_pair(30)
			or fixed_pair(12)
	else
		return nil
	end

	if type(original.armor_damage_modifier) == "table" then
		profile.armor_damage_modifier = shallow_copy(
			original.armor_damage_modifier)
		profile.armor_damage_modifier.attack = shallow_copy(
			original.armor_damage_modifier.attack or {})
		set_armour_side(profile.armor_damage_modifier.attack, close and {
			unarmored = 1,
			armored = 1,
			resistant = 1,
			player = 0,
			berserker = 1,
			super_armor = 0.6,
			disgustingly_resilient = 0.8,
			void_shield = 1,
		} or {
			unarmored = 0.8,
			armored = 0.8,
			resistant = 0.9,
			player = 0,
			berserker = 0.8,
			super_armor = 0.4,
			disgustingly_resilient = 0.65,
			void_shield = 0.8,
		})
	end

	profile.damage_type = "plasma"
	return profile
end

local function build_plasma_pistol_explosion(original)
	if type(original) ~= "table"
		or type(original.close_damage_profile) ~= "table"
		or type(original.damage_profile) ~= "table" then
		return nil
	end

	local explosion = shallow_copy(original)
	explosion.close_radius = PLASMA_PISTOL_CLOSE_RADIUS
	explosion.min_close_radius = PLASMA_PISTOL_MIN_CLOSE_RADIUS
	explosion.min_radius = PLASMA_PISTOL_MIN_RADIUS
	explosion.radius = PLASMA_PISTOL_RADIUS
	explosion.close_damage_profile = build_plasma_pistol_explosion_profile(
		original.close_damage_profile, true)
	explosion.damage_profile = build_plasma_pistol_explosion_profile(
		original.damage_profile, false)
	if not explosion.close_damage_profile or not explosion.damage_profile then
		return nil
	end
	explosion.close_damage_type = "plasma"
	explosion.damage_type = "plasma"
	return explosion
end

local function build_plasma_pistol_hitscan(original)
	local impact = original and original.damage and original.damage.impact
	local penetration = original and original.damage and original.damage.penetration
	local armour_explosions = impact and impact.armor_explosion
	local original_explosion = type(armour_explosions) == "table"
		and select(2, next(armour_explosions))
	local original_profile = impact and impact.damage_profile

	if type(original) ~= "table" or type(impact) ~= "table"
		or type(penetration) ~= "table"
		or type(original_profile) ~= "table"
		or type(original_explosion) ~= "table" then
		return nil
	end

	local owned_explosion = build_plasma_pistol_explosion(original_explosion)
	local owned_profile = build_plasma_pistol_profile(original_profile)
	if not owned_explosion or not owned_profile then return nil end

	local hitscan = shallow_copy(original)
	hitscan.range = PLASMA_PISTOL_RANGE
	hitscan.damage = shallow_copy(original.damage)
	hitscan.damage.impact = shallow_copy(impact)
	hitscan.damage.impact.damage_profile = owned_profile
	hitscan.damage.impact.armor_explosion = {}
	for armour_type in pairs(armour_explosions) do
		hitscan.damage.impact.armor_explosion[armour_type] = owned_explosion
	end
	hitscan.damage.penetration = shallow_copy(penetration)
	hitscan.damage.penetration.depth = PLASMA_PISTOL_PENETRATION
	-- The compact blast belongs to each direct impact. The Plasma Gun's exit
	-- blast would add a second explosion after penetration and double-dip the
	-- pistol's damage against the same clustered targets.
	hitscan.damage.penetration.exit_explosion_template = nil
	return hitscan
end

local function plasma_pistol_can_shoot(original_condition)
	return function(action_settings, condition_func_params, ...)
		local component = condition_func_params
			and condition_func_params.inventory_slot_component
		local state = component and component.overheat_state
		if state == "lockout" or state == "soft_lockout" then
			return false
		end
		if type(original_condition) == "function" then
			return original_condition(action_settings, condition_func_params, ...)
		end
		return true
	end
end

local function clone_plasma_pistol_action(original, repeat_input,
		owned_hitscan, plasma_fx)
	local action = shallow_copy(original)
	action.total_time = PLASMA_PISTOL_SHOT_CYCLE
	action.allowed_chain_actions = shallow_copy(
		original.allowed_chain_actions or {})
	local original_chain = action.allowed_chain_actions[repeat_input]
	if type(original_chain) == "table" then
		action.allowed_chain_actions[repeat_input] = shallow_copy(original_chain)
		action.allowed_chain_actions[repeat_input].chain_time =
			PLASMA_PISTOL_SHOT_CYCLE
	end
	action.fire_configuration = shallow_copy(original.fire_configuration or {})
	action.fire_configuration.hit_scan_template = owned_hitscan
	action.fire_configuration.damage_type = "plasma_heavy"
	action.fire_configuration.damage_type_explode = "plasma"
	action.fx = shallow_copy(original.fx or {})
	for key, value in pairs(plasma_fx or {}) do
		action.fx[key] = value
	end
	-- Keep the Bolt Pistol's empty-weapon cues, but a plasma cell should not
	-- eject a physical boltshell casing after each shot.
	action.fx.shell_casing_effect = nil
	action.fx.muzzle_flash_effect_secondary = nil
	action.action_condition_func = plasma_pistol_can_shoot(
		original.action_condition_func)
	action.pilgrimage_plasma_pistol_shot = true
	return action
end

local function build_plasma_pistol_bundle(template, original_ammo,
		plasma_source_template)
	local actions = template and template.actions
	local hip = actions and actions.action_shoot_hip
	local zoom = actions and actions.action_shoot_zoomed
	local source_action = plasma_source_template
		and plasma_source_template.actions
		and plasma_source_template.actions.action_shoot
	local source_hitscan = source_action and source_action.fire_configuration
		and source_action.fire_configuration.hit_scan_template
	if type(template) ~= "table" or type(hip) ~= "table"
		or type(zoom) ~= "table" or type(original_ammo) ~= "table"
		or type(source_action) ~= "table"
		or type(source_hitscan) ~= "table" then
		return nil, "unexpected boltpistol_p1_m2 or plasma source shape"
	end

	local owned_hitscan = build_plasma_pistol_hitscan(source_hitscan)
	if not owned_hitscan then
		return nil, "unexpected Plasma Pistol damage source shape"
	end

	local ammo = shallow_copy(original_ammo)
	ammo.ammunition_clips = shallow_copy(original_ammo.ammunition_clips or {})
	local original_clip = ammo.ammunition_clips[1]
	if type(original_clip) ~= "table" then
		return nil, "unexpected boltpistol_p1_m2 ammo shape"
	end
	ammo.ammunition_clips[1] = shallow_copy(original_clip)
	ammo.ammunition_clips[1].lerp_basic = PLASMA_PISTOL_CLIP_SIZE
	ammo.ammunition_clips[1].lerp_perfect = PLASMA_PISTOL_CLIP_SIZE
	ammo.ammunition_reserve = shallow_copy(
		original_ammo.ammunition_reserve or {})
	ammo.ammunition_reserve.lerp_basic = PLASMA_PISTOL_RESERVE
	ammo.ammunition_reserve.lerp_perfect = PLASMA_PISTOL_RESERVE

	local hud = shallow_copy(template.hud_configuration or {})
	hud.uses_ammunition = true
	hud.uses_overheat = true
	local overheat = {
		auto_vent_delay = PLASMA_PISTOL_COOLING_DELAY,
		auto_vent_duration = PLASMA_PISTOL_VENT_DURATION,
		-- Attachment heat displays read this legacy top-level value, while
		-- the weapon heat utility reads thresholds.critical below.
		critical_threshold = 0.9,
		critical_threshold_decay_rate_modifier = 1,
		high_threshold_decay_rate_modifier = 1,
		low_threshold_decay_rate_modifier = 1,
		lockout_enabled = true,
		overheat_icon_text = "",
		thresholds = {
			critical = 0.9,
			high = 0.6,
			low = 0.3,
		},
		reload_state_overrides = {},
	}
	local keywords = shallow_copy(template.keywords or {})
	append_unique(keywords, "plasma_rifle")

	return {
		template = template,
		hip = hip,
		zoom = zoom,
		ammo = original_ammo,
		hud = template.hud_configuration,
		overheat = template.overheat_configuration,
		keywords = template.keywords,
		owned_hip = clone_plasma_pistol_action(
			hip, "shoot_pressed", owned_hitscan, source_action.fx),
		owned_zoom = clone_plasma_pistol_action(
			zoom, "zoom_shoot", owned_hitscan, source_action.fx),
		owned_ammo = ammo,
		owned_hud = hud,
		owned_overheat = overheat,
		owned_keywords = keywords,
	}
end

local function install_plasma_pistol_heat_hook()
	if _plasma_pistol_heat_hook_installed then return true end
	if not _hooks or type(_hooks.require_now) ~= "function"
		or not _mod or type(_mod.hook) ~= "function" then return false end

	_hooks.require_now(SHOOT_HIT_SCAN_ACTION_PATH, function(action_class)
		if type(action_class) ~= "table"
			or type(action_class._shoot) ~= "function" then return end
		if _hooks.claim and _hooks.claim(action_class, "__pilgrimage_shared_hitscan_hook") then return end
		_melta.install_hitscan_fx(action_class)
		_mod:hook(action_class, "_shoot",
			function(func, self, position, rotation, power_level,
					charge_level, t, fire_config, ...)
			_melta.before_shoot(self, t)
			if M.heavy then M.heavy.before_shoot(self, t) end
			local result = func(self, position, rotation, power_level,
				charge_level, t, fire_config, ...)
			local settings = self and self._action_settings
			local weapon = self and self._weapon
			local item = weapon and weapon.item
			local component = self and self._inventory_slot_component
			if not _applied or not settings
				or not settings.pilgrimage_plasma_pistol_shot
				or not item or item.weapon_template ~= PLASMA_PISTOL_TEMPLATE
				or not component then return result end

			local state = component.overheat_state
			if state == "lockout" or state == "soft_lockout" then
				return result
			end
			t = tonumber(t) or 0
			local next_heat = math.min(1,
				(tonumber(component.overheat_current_percentage) or 0)
					+ PLASMA_PISTOL_HEAT_PER_SHOT)
			component.overheat_current_percentage = next_heat
			component.overheat_last_charge_at_t = t
			component.overheat_state = "idle"
			if next_heat >= 1 then
				component.overheat_state = "lockout"
				-- Normal cooling waits 0.75 seconds. Backdating only the
				-- overheat shot starts its forced vent immediately, keeping the
				-- complete lockout at the approved 2.5 seconds.
				component.overheat_last_charge_at_t =
					t - PLASMA_PISTOL_COOLING_DELAY
			end
			_plasma_pistol_heat_events = _plasma_pistol_heat_events + 1
			return result
		end)
	end)

	_plasma_pistol_heat_hook_installed = true
	return true
end

local function heavy_sword_action_settings(action_name)
	if action_name == "action_attack_special"
		or action_name == "action_attack_special_2" then
		return TUNING.HEAVY_SWORD_SPECIAL_DAMAGE,
			TUNING.HEAVY_SWORD_COMMITTED_CARAPACE
	end
	if action_name:find("_heavy", 1, true) then
		return TUNING.HEAVY_SWORD_HEAVY_DAMAGE,
			TUNING.HEAVY_SWORD_COMMITTED_CARAPACE
	end
	if action_name:find("_light", 1, true) then
		return TUNING.HEAVY_SWORD_LIGHT_DAMAGE,
			TUNING.HEAVY_SWORD_LIGHT_CARAPACE
	end
	return nil
end

local function build_heavy_sword_bundle(template_name, template)
	local actions = template and template.actions
	if type(template) ~= "table" or type(actions) ~= "table" then
		return nil, "unexpected " .. template_name .. " shape"
	end

	local originals = {}
	local owned = {}
	for action_name, action in pairs(actions) do
		local damage_factor, carapace_factor =
			heavy_sword_action_settings(action_name)
		if damage_factor and type(action) == "table"
			and type(action.damage_profile) == "table" then
			local cloned_action = shallow_copy(action)
			cloned_action.damage_profile = build_attack_profile(
				action.damage_profile, damage_factor, {
					later_target_factor = TUNING.HEAVY_SWORD_LATER_TARGET_DAMAGE,
					cleave_factor = TUNING.HEAVY_SWORD_CLEAVE,
					flak_factor = TUNING.HEAVY_SWORD_FLAK,
					carapace_factor = carapace_factor,
				})
			originals[action_name] = action
			owned[action_name] = cloned_action
		end
	end

	if next(owned) == nil then
		return nil, template_name .. " has no Heavy Sword attack profiles"
	end

	return {
		name = template_name,
		template = template,
		originals = originals,
		owned = owned,
	}
end

local function thunder_hammer_execution_profile(original, powered)
	local factor = powered and TUNING.THUNDER_HAMMER_EXECUTION_POWERED_DAMAGE
		or TUNING.THUNDER_HAMMER_EXECUTION_UNPOWERED_DAMAGE
	return build_attack_profile(original, factor, {
		-- The execution mark gains first-contact damage, not extra horde
		-- damage. Cancel the main factor after the first numbered target.
		later_target_factor = 1 / factor,
		impact_factor = not powered
			and TUNING.THUNDER_HAMMER_EXECUTION_UNPOWERED_IMPACT or nil,
		impact_cleave_factor = not powered
			and TUNING.THUNDER_HAMMER_EXECUTION_UNPOWERED_IMPACT_CLEAVE or nil,
	})
end

local function thunder_hammer_mode_can_activate(original_condition)
	return function(action_settings, condition_func_params, ...)
		if type(original_condition) == "function"
			and not original_condition(
				action_settings, condition_func_params, ...) then
			return false
		end

		local component = condition_func_params
			and condition_func_params.inventory_slot_component
		return component ~= nil
			and not component.special_active
			and (component.num_special_charges or 0) >= 1
	end
end

local function build_thunder_hammer_bundle(spec, template)
	local actions = template and template.actions
	if type(template) ~= "table" or type(actions) ~= "table" then
		return nil, "unexpected " .. spec.name .. " shape"
	end

	local originals = {}
	local owned = {}
	for action_name, action in pairs(actions) do
		if type(action) == "table" then
			local has_profile = type(action.damage_profile) == "table"
			local has_powered =
				type(action.damage_profile_special_active) == "table"
			local has_aborted =
				type(action.damage_profile_special_active_on_abort) == "table"
			if spec.role == "execution"
				and (has_profile or has_powered or has_aborted) then
				local cloned_action = shallow_copy(action)
				if has_profile then
					cloned_action.damage_profile =
						thunder_hammer_execution_profile(
							action.damage_profile, false)
				end
				if has_powered then
					cloned_action.damage_profile_special_active =
						thunder_hammer_execution_profile(
							action.damage_profile_special_active,
							true)
				end
				if has_aborted then
					cloned_action.damage_profile_special_active_on_abort =
						thunder_hammer_execution_profile(
							action.damage_profile_special_active_on_abort,
							true)
				end

				if (has_profile and not cloned_action.damage_profile)
					or (has_powered
						and not cloned_action.damage_profile_special_active)
					or (has_aborted and not
						cloned_action.damage_profile_special_active_on_abort) then
					return nil, "unexpected " .. spec.name
						.. " damage profile on " .. action_name
				end

				originals[action_name] = action
				owned[action_name] = cloned_action
			end

			if spec.role == "line_breaker"
				and action_name:find("action_activate_special_", 1, true) == 1 then
				local cloned_action = owned[action_name] or shallow_copy(action)
				cloned_action.action_condition_func =
					thunder_hammer_mode_can_activate(
						action.action_condition_func)
				originals[action_name] = action
				owned[action_name] = cloned_action
			end
		end
	end

	if next(owned) == nil then
		return nil, spec.name .. " has no Thunder Hammer attack profiles"
	end

	local original_special_class = template.weapon_special_class
	local original_tweak_data = template.weapon_special_tweak_data
	local original_counter = template.weapon_counter
	local owned_tweak_data
	local owned_counter
	if spec.role == "line_breaker" then
		owned_tweak_data = shallow_copy(original_tweak_data or {})
		owned_tweak_data.active_duration =
			TUNING.THUNDER_HAMMER_LINE_ACTIVE_DURATION
		owned_tweak_data.cooldown = TUNING.THUNDER_HAMMER_LINE_COOLDOWN
		owned_tweak_data.allow_reactivation_while_active = false
		owned_tweak_data.keep_active_on_sprint = true
		owned_tweak_data.keep_active_on_stun = true
		owned_tweak_data.keep_active_on_vault = true
		owned_tweak_data.max_charges = 1
		owned_tweak_data.max_num_charges = 1
		owned_tweak_data.num_charges_to_consume_on_activation = 1
		owned_tweak_data.thresholds = {
			{ name = "empty", threshold = 0 },
			{ name = "one", threshold = 1 },
		}
		owned_tweak_data.only_deactive_on_abort = nil
		owned_tweak_data.special_active_hit_extra_time = nil
		owned_tweak_data.push_template = nil
		owned_counter = {
			show_when_unwielded = false,
			weapon_counter_type = TUNING.THUNDER_HAMMER_LINE_COUNTER_TYPE,
		}
	end

	return {
		name = spec.name,
		role = spec.role,
		template = template,
		originals = originals,
		owned = owned,
		special_class = original_special_class,
		tweak_data = original_tweak_data,
		counter = original_counter,
		owned_tweak_data = owned_tweak_data,
		owned_counter = owned_counter,
	}
end

local function mark_latched_profile(profile, force)
	if type(profile) ~= "table" or profile.sticky_attack ~= true
		or (not force and profile.weapon_special ~= true) then
		return profile, false
	end

	local owned = shallow_copy(profile)
	owned[TUNING.CHAIN_STAGGER_MARKER] = true
	return owned, true
end

local function mark_latched_damage(damage, force)
	if type(damage) ~= "table" then return damage, false end

	local owned
	for _, key in ipairs({ "damage_profile", "last_damage_profile" }) do
		local profile, changed = mark_latched_profile(damage[key], force)
		if changed then
			owned = owned or shallow_copy(damage)
			owned[key] = profile
		end
	end
	return owned or damage, owned ~= nil
end

local function mark_latched_settings(settings, force)
	if type(settings) ~= "table" then return settings, false end
	local damage, changed = mark_latched_damage(settings.damage, force)
	if not changed then return settings, false end
	local owned = shallow_copy(settings)
	owned.damage = damage
	return owned, true
end

-- Only the damage delivered while the weapon is physically latched receives
-- this marker. The opening swing and every unpowered attack keep their native
-- behavior; both the repeating saw ticks and terminal rip belong to the latch.
local function chain_action_with_latched_stagger(action)
	if type(action) ~= "table" then return action, false end

	local owned
	local normal, normal_changed = mark_latched_settings(
		action.hit_stickyness_settings, false)
	if normal_changed then
		owned = shallow_copy(action)
		owned.hit_stickyness_settings = normal
	end

	local powered, powered_changed = mark_latched_settings(
		action.hit_stickyness_settings_special_active, true)
	if powered_changed then
		owned = owned or shallow_copy(action)
		owned.hit_stickyness_settings_special_active = powered
	end

	return owned or action, owned ~= nil
end


local function is_special_activation_action(action_name, action)
	if type(action) ~= "table" then return false end
	-- The one-handed chain weapons call this action "action_toggle_special",
	-- while both Heavy Eviscerators call the same operation
	-- "action_start_special". Identify the action by its engine contract rather
	-- than a cosmetic table key so both families receive the timed mode.
	local kind = action.kind
	return action.start_input == "special_action"
		and (kind == "toggle_special" or kind == "activate_special")
end

local function build_timed_mode_bundle(template_name, template,
		active_duration, cooldown, seconds_per_extra_activation,
		mark_chain_stagger)
	local actions = template and template.actions
	if type(template) ~= "table" or type(actions) ~= "table"
		or type(template.weapon_special_tweak_data) ~= "table" then
		return nil, "unexpected " .. template_name .. " timed-special shape"
	end

	local originals = {}
	local owned = {}
	local activation_actions = 0
	local marked_profiles = 0
	for action_name, action in pairs(actions) do
		if type(action) == "table" then
			local cloned_action = action
			local changed = false

			if mark_chain_stagger then
				cloned_action, changed =
					chain_action_with_latched_stagger(action)
				if changed then marked_profiles = marked_profiles + 1 end
			end

			if is_special_activation_action(action_name, action) then
				if not changed then cloned_action = shallow_copy(action) end
				cloned_action.action_condition_func =
					thunder_hammer_mode_can_activate(
						action.action_condition_func)
				changed = true
				activation_actions = activation_actions + 1
			end

			if changed then
				originals[action_name] = action
				owned[action_name] = cloned_action
			end
		end
	end

	if activation_actions == 0 then
		return nil, template_name .. " has no special activation action"
	end
	if mark_chain_stagger and marked_profiles == 0 then
		return nil, template_name .. " has no powered latched profile"
	end

	local tweak_data = template.weapon_special_tweak_data
	local owned_tweak_data = shallow_copy(tweak_data)
	owned_tweak_data.active_duration = active_duration
	owned_tweak_data.cooldown = cooldown
	owned_tweak_data.active_duration_per_extra_activation =
		seconds_per_extra_activation
	owned_tweak_data.allow_reactivation_while_active = false
	owned_tweak_data.keep_active_on_sprint = true
	owned_tweak_data.keep_active_on_stun = true
	owned_tweak_data.keep_active_on_vault = true
	owned_tweak_data.max_charges = 1
	owned_tweak_data.max_num_charges = 1
	owned_tweak_data.num_charges_to_consume_on_activation = 1
	owned_tweak_data.num_activations = nil
	owned_tweak_data.thresholds = {
		{ name = "empty", threshold = 0 },
		{ name = "one", threshold = 1 },
	}

	return {
		name = template_name,
		template = template,
		originals = originals,
		owned = owned,
		special_class = template.weapon_special_class,
		tweak_data = tweak_data,
		counter = template.weapon_counter,
		owned_tweak_data = owned_tweak_data,
		owned_counter = {
			show_when_unwielded = false,
			weapon_counter_type = TUNING.TIMED_MODE_COUNTER_TYPE,
		},
	}
end

local function build_chain_stagger_bundle(template_name, template)
	local actions = template and template.actions
	if type(template) ~= "table" or type(actions) ~= "table" then
		return nil, "unexpected " .. template_name .. " chain-stagger shape"
	end

	local originals = {}
	local owned = {}
	for action_name, action in pairs(actions) do
		local cloned_action, changed =
			chain_action_with_latched_stagger(action)
		if changed then
			originals[action_name] = action
			owned[action_name] = cloned_action
		end
	end

	if next(owned) == nil then
		return nil, template_name .. " has no powered latched profile"
	end
	return {
		name = template_name,
		template = template,
		originals = originals,
		owned = owned,
	}
end

local function build_persistent_shovel_bundle(template_name, template)
	if type(template) ~= "table"
		or template.weapon_special_class ~= "WeaponSpecialShovels" then
		return nil, "unexpected " .. template_name .. " folding-shovel shape"
	end
	return {
		name = template_name,
		template = template,
		special_class = template.weapon_special_class,
	}
end

local function should_force_chain_stagger(damage_profile, breed)
	local tags = type(breed) == "table" and breed.tags or nil
	return type(damage_profile) == "table"
		and damage_profile[TUNING.CHAIN_STAGGER_MARKER] == true
		and not (type(tags) == "table" and tags.monster == true)
end

function M.install_stagger_calculation(StaggerCalculation)
	if _chain_stagger_hook_installed then return true end
	if not _mod or type(_mod.hook) ~= "function"
		or type(StaggerCalculation) ~= "table"
		or type(StaggerCalculation.calculate) ~= "function" then
		return false
	end
	if _hooks and _hooks.claim
		and _hooks.claim(StaggerCalculation,
			"__pilgrimage_chain_latched_stagger") then
		return false
	end

	_mod:hook(StaggerCalculation, "calculate",
		function(func, damage_profile, target_settings, lerp_values,
				power_level, charge_level, breed, ...)
			local stagger_type, duration_scale, length_scale,
				stagger_strength, current_hit_stagger_strength = func(
					damage_profile, target_settings, lerp_values,
					power_level, charge_level, breed, ...)

			if should_force_chain_stagger(damage_profile, breed) then
				-- "sticky" is the game's latched-chain stagger. Replacing only
				-- the result type bypasses breed stagger thresholds without
				-- changing damage, target selection or area impact.
				stagger_type = "sticky"
				duration_scale = duration_scale or 1
				length_scale = length_scale or 1
				stagger_strength = stagger_strength or 1
				current_hit_stagger_strength =
					current_hit_stagger_strength or stagger_strength
			end

			return stagger_type, duration_scale, length_scale,
				stagger_strength, current_hit_stagger_strength
		end)

	_chain_stagger_hook_installed = true
	return true
end

local function build_grenadier_gauntlet_explosion(original, factor)
	if type(original) ~= "table"
		or type(original.close_damage_profile) ~= "table"
		or type(original.damage_profile) ~= "table" then return nil end
	local explosion = shallow_copy(original)
	explosion.close_damage_profile = build_attack_profile(
		original.close_damage_profile, factor, {
			carapace_factor = GRENADIER_GAUNTLET_CARAPACE_FACTOR,
		})
	-- Only the close internal blast receives magazine-scaled damage. Targets
	-- outside that close zone retain the native outer blast, preventing this
	-- committed anti-armour finisher from becoming a wide-area nuke.
	explosion.damage_profile = shallow_copy(original.damage_profile)
	return explosion
end

local function build_grenadier_gauntlet_bundle(template)
	local actions = template and template.actions
	local special = actions and actions.action_execute_special
	local explosion = special and special.explosion_template
	if type(template) ~= "table" or type(actions) ~= "table"
		or type(special) ~= "table" or type(explosion) ~= "table"
		or type(special.ammunition_usage) ~= "number" then
		return nil, "unexpected ogryn_gauntlet_p1_m1 special shape"
	end

	-- The action and explosion template are privately owned. The runtime hook
	-- can therefore select a stronger attack profile for this one blast without
	-- touching impact, ordinary shots or another shared weapon template.
	local owned_explosion = build_grenadier_gauntlet_explosion(
		explosion, GRENADIER_GAUNTLET_DAMAGE_PER_SHELL)
	if not owned_explosion then
		return nil, "unexpected special_gauntlet_grenade damage profiles"
	end
	local owned_special = shallow_copy(special)
	owned_special.explosion_template = owned_explosion
	owned_special.pilgrimage_mag_dump = true
	owned_special.pilgrimage_mag_dump_source_explosion = explosion
	owned_special.pilgrimage_mag_dump_explosions = {
		[1] = owned_explosion,
	}

	return {
		template = template,
		special = special,
		owned_special = owned_special,
	}
end

local function install_grenadier_gauntlet_hook()
	if _grenadier_gauntlet_hook_installed then return true end
	if not _hooks or type(_hooks.require_now) ~= "function"
		or not _mod or type(_mod.hook) ~= "function" then return false end

	_hooks.require_now(MELEE_EXPLOSIVE_ACTION_PATH, function(action_class)
		if type(action_class) ~= "table"
			or type(action_class._explode) ~= "function" then return end
		_mod:hook(action_class, "_explode", function(func, self, t)
			local settings = self and self._action_settings
			local component = self and self._inventory_slot_component
			local clips = component and component.current_ammunition_clip
			local loaded = clips and tonumber(clips[1]) or 0
			if not _applied or not settings
				or not settings.pilgrimage_mag_dump or loaded <= 0 then
				return func(self, t)
			end

			loaded = math.max(1, math.floor(loaded))
			local original_usage = settings.ammunition_usage
			local factor = loaded * GRENADIER_GAUNTLET_DAMAGE_PER_SHELL
			local explosions = settings.pilgrimage_mag_dump_explosions
			local explosion = type(explosions) == "table"
				and explosions[loaded]
			if not explosion and type(explosions) == "table" then
				local source_explosion =
					settings.pilgrimage_mag_dump_source_explosion
				explosion = build_grenadier_gauntlet_explosion(
					source_explosion, factor)
				explosions[loaded] = explosion
			end
			if type(explosion) ~= "table" then return func(self, t) end
			local original_explosion = settings.explosion_template

			-- ActionMeleeExplosive deducts ammunition only after the delayed blast.
			-- Temporarily presenting every loaded shell as the action's cost empties
			-- the magazine only on a confirmed hit. The queued explosion retains its
			-- selected owned profile until native explosion creation has completed.
			settings.ammunition_usage = loaded
			settings.explosion_template = explosion
			local ok, result = pcall(func, self, t)
			settings.ammunition_usage = original_usage
			settings.explosion_template = original_explosion
			if not ok then error(result, 0) end

			_grenadier_gauntlet_mag_dumps =
				_grenadier_gauntlet_mag_dumps + 1
			return result
		end)
	end)

	_grenadier_gauntlet_hook_installed = true
	return true
end

local function build_vindicator_damage_profile(original)
	if type(original) ~= "table" then return nil end
	local profile = shallow_copy(original)

	local function own_distribution(distribution)
		if type(distribution) ~= "table" then return distribution end
		local owned = shallow_copy(distribution)
		if distribution.attack ~= nil then
			owned.attack = scaled_branch(distribution.attack,
				VINDICATOR_DAMAGE_FACTOR)
		end
		if distribution.impact ~= nil then
			owned.impact = scaled_branch(distribution.impact,
				VINDICATOR_IMPACT_FACTOR)
		end
		return owned
	end

	if type(original.power_distribution) == "table" then
		profile.power_distribution = own_distribution(original.power_distribution)
	end
	if type(original.power_distribution_ranged) == "table" then
		profile.power_distribution_ranged =
			own_distribution(original.power_distribution_ranged)
	end
	if type(original.targets) == "table" then
		profile.targets = shallow_copy(original.targets)
		for key, target in pairs(original.targets) do
			if type(target) == "table" then
				local owned_target = shallow_copy(target)
				if type(target.power_distribution) == "table" then
					owned_target.power_distribution =
						own_distribution(target.power_distribution)
				end
				if type(target.power_distribution_ranged) == "table" then
					owned_target.power_distribution_ranged =
						own_distribution(target.power_distribution_ranged)
				end
				profile.targets[key] = owned_target
			end
		end
	end
	if original.accumulative_stagger_strength_multiplier ~= nil then
		profile.accumulative_stagger_strength_multiplier =
			VINDICATOR_ACCUMULATIVE_STAGGER
	end
	return profile
end

local function build_vindicator_gas(original)
	if type(original) ~= "table" or type(original.damage) ~= "table"
		or type(original.damage.impact) ~= "table"
		or type(original.damage.impact.damage_profile) ~= "table" then
		return nil
	end
	local gas = shallow_copy(original)
	gas.damage = shallow_copy(original.damage)
	gas.damage.impact = shallow_copy(original.damage.impact)
	gas.damage.impact.damage_profile = build_vindicator_damage_profile(
		original.damage.impact.damage_profile)
	return gas
end

local function clone_flamer_action(original, owned_gas)
	local action = shallow_copy(original)
	action.fire_configuration = shallow_copy(original.fire_configuration or {})
	action.fire_configuration.flamer_gas_template = owned_gas
	return action
end

local function build_vindicator_shove_profile(original)
	if type(original) ~= "table" then return nil end
	local profile = shallow_copy(original)
	profile.power_distribution = shallow_copy(original.power_distribution or {})
	profile.power_distribution.attack = scaled_branch(
		original.power_distribution and original.power_distribution.attack or 30,
		VINDICATOR_SHOVE_DAMAGE_FACTOR)
	profile.power_distribution.impact = scaled_branch(
		original.power_distribution and original.power_distribution.impact or 15,
		VINDICATOR_SHOVE_IMPACT_FACTOR)

	-- The Vindicator model carries a real chain blade. Retain the push action's
	-- crowd-control semantics, but give the narrow inner cone a chain-like armour
	-- curve and Fatshark's native long Bleed payload.
	profile.armor_damage_modifier = shallow_copy(
		original.armor_damage_modifier or {})
	profile.armor_damage_modifier.attack = shallow_copy(
		profile.armor_damage_modifier.attack or {})
	local attack = profile.armor_damage_modifier.attack
	attack.unarmored = 1
	attack.armored = 0.75
	attack.resistant = 0.9
	attack.berserker = 1
	attack.super_armor = 0.35
	attack.disgustingly_resilient = 1

	profile.buffs = shallow_copy(original.buffs or {})
	profile.buffs.on_damage_dealt = shallow_copy(
		profile.buffs.on_damage_dealt or {})
	profile.buffs.on_damage_dealt.bleed_long = VINDICATOR_SHOVE_BLEED
	profile.gibbing_type = "sawing"
	return profile
end

local function install_vindicator_shove_sound()
	if not _hooks or type(_hooks.require_now) ~= "function" then return false end
	_hooks.require_now(VINDICATOR_PUSH_ACTION_PATH, function(action_class)
		if type(action_class) ~= "table" or type(action_class.start) ~= "function" then
			return
		end
		_mod:hook(action_class, "start", function(func, self, ...)
			local result = func(self, ...)
			local settings = self and self._action_settings
			local fx = self and self._fx_extension
			if _applied and settings
				and settings.pilgrimage_vindicator_chain_shove
				and fx and type(fx.trigger_wwise_event) == "function" then
				-- Direct local playback is intentional. This is a presentation cue,
				-- not synchronized gameplay state, so it needs no network lookup.
				pcall(fx.trigger_wwise_event, fx,
					VINDICATOR_CHAIN_SWING_SOUND, false)
			end
			return result
		end)
	end)
	return true
end

-- Flamer gas has no hit-zone actor. Darktide therefore resolves its armour
-- against breed.armor_type, the target's overall class rather than a guessed
-- body part. "armored" is Flak and "super_armor" is Carapace.
local function vindicator_armour_qualifies(target_unit)
	if not target_unit or not ScriptUnit then return false end
	local unit_data = ScriptUnit.has_extension(target_unit, "unit_data_system")
	local breed = unit_data and unit_data:breed()
	local armour = breed and breed.armor_type
	return armour == "armored" or armour == "super_armor"
end

local function vindicator_action_active(action)
	if not _applied or not action or action._is_server ~= true then return false end
	local weapon = action._weapon
	local item = weapon and weapon.item
	return item and item.weapon_template == VINDICATOR_TEMPLATE
end

local function burn_stacks(target_unit)
	if not target_unit or not ScriptUnit then return 0, nil end
	local extension = ScriptUnit.has_extension(target_unit, "buff_system")
	if not extension or type(extension.current_stacks) ~= "function" then
		return 0, extension
	end
	return tonumber(extension:current_stacks(VINDICATOR_BURN_BUFF)) or 0,
		extension
end

local function add_vindicator_brittleness(action, target_unit, before, t)
	if not vindicator_armour_qualifies(target_unit) then return 0 end
	local after, extension = burn_stacks(target_unit)
	local added = math.max(0, math.min(2, after - (tonumber(before) or 0)))
	if added <= 0 or not extension
		or type(extension.add_internally_controlled_buff_with_stacks)
			~= "function" then return 0 end

	extension:add_internally_controlled_buff_with_stacks(
		VINDICATOR_BRITTLENESS_BUFF, added, t,
		"owner_unit", action._player_unit,
		"source_item", action._weapon and action._weapon.item)
	_vindicator_brittleness_stacks = _vindicator_brittleness_stacks + added
	return added
end

local function install_vindicator_brittleness_hooks()
	if _vindicator_brittleness_hooks_installed then return true end
	if not _hooks or type(_hooks.require_now) ~= "function"
		or not _mod or type(_mod.hook) ~= "function" then return false end

	_hooks.require_now(VINDICATOR_FLAMER_ACTION_PATH, function(action_class)
		_mod:hook(action_class, "_burn_targets",
			function(func, self, dt, t, force_burn, ...)
				if not vindicator_action_active(self) then
					return func(self, dt, t, force_burn, ...)
				end
				local before = {}
				for target_unit in pairs(self._dot_targets or {}) do
					before[target_unit] = burn_stacks(target_unit)
				end
				local result = func(self, dt, t, force_burn, ...)
				for target_unit, stacks in pairs(before) do
					add_vindicator_brittleness(self, target_unit, stacks, t)
				end
				return result
			end)
	end)

	_hooks.require_now(VINDICATOR_FLAMER_BURST_ACTION_PATH,
		function(action_class)
			_mod:hook(action_class, "_burn_target",
				function(func, self, t, target_unit, ...)
					if not vindicator_action_active(self) then
						return func(self, t, target_unit, ...)
					end
					local before = burn_stacks(target_unit)
					local result = func(self, t, target_unit, ...)
					add_vindicator_brittleness(self, target_unit, before, t)
					return result
				end)
		end)

	_vindicator_brittleness_hooks_installed = true
	return true
end

local function build_vindicator_bundle(template, original_ammo)
	local actions = template and template.actions
	local burst = actions and actions.action_shoot
	local auto = actions and actions.action_shoot_braced
	local push = actions and actions.push
	local burst_gas = burst and burst.fire_configuration
		and burst.fire_configuration.flamer_gas_template
	local auto_gas = auto and auto.fire_configuration
		and auto.fire_configuration.flamer_gas_template
	local inner_push = push and push.inner_damage_profile

	if type(template) ~= "table" or type(burst) ~= "table"
		or type(auto) ~= "table" or type(push) ~= "table"
		or type(burst_gas) ~= "table" or type(auto_gas) ~= "table"
		or type(inner_push) ~= "table" or type(original_ammo) ~= "table" then
		return nil, "unexpected flamer_p1_m1 shape"
	end

	local owned_burst_gas = build_vindicator_gas(burst_gas)
	local owned_auto_gas = burst_gas == auto_gas and owned_burst_gas
		or build_vindicator_gas(auto_gas)
	local owned_push_profile = build_vindicator_shove_profile(inner_push)
	if not owned_burst_gas or not owned_auto_gas or not owned_push_profile then
		return nil, "unexpected Vindicator damage profile"
	end

	local owned_push = shallow_copy(push)
	owned_push.inner_damage_profile = owned_push_profile
	owned_push.inner_damage_type = "saw_light"
	owned_push.pilgrimage_vindicator_chain_shove = true

	local ammo = shallow_copy(original_ammo)
	ammo.ammunition_clips = shallow_copy(original_ammo.ammunition_clips or {})
	local clip = ammo.ammunition_clips[1]
	if type(clip) ~= "table" or type(original_ammo.ammunition_reserve) ~= "table" then
		return nil, "unexpected Vindicator ammunition shape"
	end
	ammo.ammunition_clips[1] = shallow_copy(clip)
	ammo.ammunition_clips[1].lerp_basic =
		(clip.lerp_basic or 0) * VINDICATOR_CLIP_FACTOR
	ammo.ammunition_clips[1].lerp_perfect =
		(clip.lerp_perfect or 0) * VINDICATOR_CLIP_FACTOR
	ammo.ammunition_reserve = shallow_copy(original_ammo.ammunition_reserve)
	ammo.ammunition_reserve.lerp_basic =
		(original_ammo.ammunition_reserve.lerp_basic or 0)
		* VINDICATOR_RESERVE_FACTOR
	ammo.ammunition_reserve.lerp_perfect =
		(original_ammo.ammunition_reserve.lerp_perfect or 0)
		* VINDICATOR_RESERVE_FACTOR

	return {
		template = template,
		burst = burst,
		auto = auto,
		push = push,
		ammo = original_ammo,
		owned_burst = clone_flamer_action(burst, owned_burst_gas),
		owned_auto = clone_flamer_action(auto, owned_auto_gas),
		owned_push = owned_push,
		owned_ammo = ammo,
	}
end

local function eligible_pilgrimage_launch()
	if not _settings.custom_weapon_balancing_enabled() then
		return false, "setting off"
	end
	if not _run_state.is_active() then
		return false, "no active run"
	end

	local record = _run_state.launch_record()
	local expected = _run_state.current_mission()
	if not record or not expected or record.mission ~= expected then
		return false, "not a recorded Pilgrimage launch"
	end

	return true
end

local function try_apply()
	if _applied then return true end
	if not _pending then return false, "not pending" end
	APPLY_DIAG.skipped_optional = {}
	if type(_weapon_templates) ~= "table" or type(_ammo_templates) ~= "table" then
		return false, "templates unavailable"
	end
	if type(_dodge_templates) ~= "table" then
		return false, "dodge templates unavailable"
	end

	local template = _weapon_templates[HOTSHOT_TEMPLATE]
	local actions = template and template.actions
	local hip = actions and actions.action_shoot_hip
	local zoom = actions and actions.action_shoot_zoomed
	local hip_hitscan = hip and hip.fire_configuration
		and hip.fire_configuration.hit_scan_template
	local zoom_hitscan = zoom and zoom.fire_configuration
		and zoom.fire_configuration.hit_scan_template
	local original_ammo = _ammo_templates[HOTSHOT_TEMPLATE]

	if type(template) ~= "table" or type(hip) ~= "table"
		or type(zoom) ~= "table" or type(hip_hitscan) ~= "table"
		or type(zoom_hitscan) ~= "table" or type(original_ammo) ~= "table" then
		return false, "unexpected autogun_p3_m2 shape"
	end

	-- Preserve any EWC action-specific hitscan work. The shipped weapon shares
	-- one table between hip and ADS, so retain that identity when it is still
	-- shared; if another mod split them, clone and preserve each branch instead.
	local hip_owned_hitscan = build_hotshot_hitscan(hip_hitscan)
	local zoom_owned_hitscan = hip_hitscan == zoom_hitscan
		and hip_owned_hitscan or build_hotshot_hitscan(zoom_hitscan)
	if not hip_owned_hitscan or not zoom_owned_hitscan then
		return false, "unexpected autogun_p3_m2 damage profile"
	end

	-- Only the next shot is cadence-locked. The first field test proved that
	-- delaying zoom and zoom_release made the rifle feel stuck after firing,
	-- while ADS transitions did not bypass the actual shooting action's timer.
	local owned_hip = clone_shoot_action(hip, "shoot", hip_owned_hitscan)
	local owned_zoom = clone_shoot_action(zoom, "zoom_shoot", zoom_owned_hitscan)

	local ammo = shallow_copy(original_ammo)
	ammo.ammunition_clips = shallow_copy(original_ammo.ammunition_clips or {})
	local original_clip = ammo.ammunition_clips[1]
	if type(original_clip) ~= "table" then
		return false, "unexpected autogun_p3_m2 ammo shape"
	end
	ammo.ammunition_clips[1] = shallow_copy(original_clip)
	ammo.ammunition_clips[1].lerp_basic = HOTSHOT_CLIP_SIZE
	ammo.ammunition_clips[1].lerp_perfect = HOTSHOT_CLIP_SIZE
	ammo.ammunition_reserve = shallow_copy(original_ammo.ammunition_reserve or {})
	ammo.ammunition_reserve.lerp_basic = 42
	ammo.ammunition_reserve.lerp_perfect = 80

	local original_lookup = template.__base_template_lookup
	local original_dodge_lookup = type(original_lookup) == "table"
		and original_lookup.dodge
	local original_dodge_base = type(original_dodge_lookup) == "table"
		and original_dodge_lookup.base
	if type(original_dodge_base) ~= "table"
		or type(original_dodge_base.new_identifier) ~= "string" then
		return false, "unexpected autogun_p3_m2 dodge lookup"
	end

	-- Preserve the existing component identifier and replace only the private
	-- source from which the weapon instance resolves its dodge values.
	local owned_lookup = shallow_copy(original_lookup)
	local owned_dodge_lookup = shallow_copy(original_dodge_lookup)
	local owned_dodge_base = shallow_copy(original_dodge_base)
	owned_dodge_base.base_identifier = HOTSHOT_DODGE_TEMPLATE
	owned_dodge_lookup.base = owned_dodge_base
	owned_lookup.dodge = owned_dodge_lookup

	local original_buffs = template.buffs
	local owned_buffs = shallow_copy(original_buffs or {})
	owned_buffs.on_wield = shallow_copy(owned_buffs.on_wield or {})
	if #owned_buffs.on_wield >= 3 then
		return false, "autogun_p3_m2 has no free on-wield buff slot"
	end
	append_unique(owned_buffs.on_wield, HOTSHOT_WIELD_BUFF)

	-- Build every additional weapon change before committing any of them. A
	-- game update that changes one expected table shape therefore leaves the
	-- entire batch untouched instead of producing a half-applied ruleset.
	local kickback, kickback_error = build_kickback_bundle(
		_weapon_templates[KICKBACK_TEMPLATE],
		_ammo_templates[KICKBACK_TEMPLATE])
	if not kickback then return false, kickback_error end
	local double_barrel, double_barrel_error = DOUBLE_BARREL.build(
		_weapon_templates[DOUBLE_BARREL.name], _ammo_templates[DOUBLE_BARREL.name])
	if not double_barrel then return false, double_barrel_error end
	local rumbler
	if M.rumbler then
		local why
		rumbler, why = M.rumbler.build(_weapon_templates[M.rumbler.name])
		if not rumbler then return false, why end
	end

	local shredder, shredder_error = build_shredder_bundle(
		_weapon_templates[SHREDDER_TEMPLATE])
	if not shredder then return false, shredder_error end

	local power_maul = _weapon_templates[POWER_MAUL_TEMPLATE]
	local original_power_maul_tweak = power_maul
		and power_maul.weapon_special_tweak_data
	if type(power_maul) ~= "table"
		or type(original_power_maul_tweak) ~= "table"
		or type(original_power_maul_tweak.cooldown) ~= "number" then
		return false, "unexpected ogryn_powermaul_p1_m1 special shape"
	end
	local owned_power_maul_tweak = shallow_copy(original_power_maul_tweak)
	owned_power_maul_tweak.cooldown = POWER_MAUL_COOLDOWN

	local plasma_cannon, plasma_cannon_error = build_plasma_cannon_bundle(
		_weapon_templates[PLASMA_CANNON_TEMPLATE])
	if not plasma_cannon then return false, plasma_cannon_error end

	local plasma_pistol, plasma_pistol_error = build_plasma_pistol_bundle(
		_weapon_templates[PLASMA_PISTOL_TEMPLATE],
		_ammo_templates[PLASMA_PISTOL_TEMPLATE],
		_weapon_templates[PLASMA_CANNON_TEMPLATE])
	if not plasma_pistol then return false, plasma_pistol_error end

	local vindicator, vindicator_error = build_vindicator_bundle(
		_weapon_templates[VINDICATOR_TEMPLATE],
		_ammo_templates[VINDICATOR_TEMPLATE])
	if not vindicator then return false, vindicator_error end

	local hunter_stubber, hunter_stubber_error =
		build_hunter_stubber_bundle(
			_weapon_templates[HUNTER_STUBBER_TEMPLATE])
	if not hunter_stubber then return false, hunter_stubber_error end

	local grenadier_gauntlet, grenadier_gauntlet_error =
		build_grenadier_gauntlet_bundle(
			_weapon_templates[GRENADIER_GAUNTLET_TEMPLATE])
	if not grenadier_gauntlet then
		return false, grenadier_gauntlet_error
	end

	local rippers = {}
	for _, spec in ipairs(RIPPER_TEMPLATES) do
		local bundle, bundle_error = build_ripper_bundle(
			spec, _weapon_templates[spec.name])
		if not bundle then return false, bundle_error end
		rippers[#rippers + 1] = bundle
	end

	local stubber_reload_buffs = {}
	for _, template_name in ipairs(STUBBER_RELOAD_TEMPLATES) do
		local bundle, bundle_error = build_wield_buff_bundle(
			template_name, _weapon_templates[template_name],
			OGRYN_RANGED_RELOAD_BUFF)
		if not bundle then return false, bundle_error end
		stubber_reload_buffs[#stubber_reload_buffs + 1] = bundle
	end

	local reserve_ammo = {}
	for _, spec in ipairs(RESERVE_AMMO_FACTORS) do
		local bundle, bundle_error = build_reserve_ammo_bundle(
			spec.name, _ammo_templates[spec.name], spec.factor)
		if not bundle then return false, bundle_error end
		reserve_ammo[#reserve_ammo + 1] = bundle
	end

	local heavy_swords = {}
	for _, template_name in ipairs(HEAVY_SWORD_TEMPLATES) do
		local bundle, bundle_error = build_heavy_sword_bundle(
			template_name, _weapon_templates[template_name])
		if not bundle then return false, bundle_error end
		heavy_swords[#heavy_swords + 1] = bundle
	end

	local thunder_hammers = {}
	for _, spec in ipairs(THUNDER_HAMMER_SPECS) do
		local bundle, bundle_error = build_thunder_hammer_bundle(
			spec, _weapon_templates[spec.name])
		if not bundle then return false, bundle_error end
		thunder_hammers[#thunder_hammers + 1] = bundle
	end

	local power_swords = {}
	for _, template_name in ipairs(POWER_SWORD_TIMED_TEMPLATES) do
		local bundle, bundle_error = build_timed_mode_bundle(
			template_name, _weapon_templates[template_name],
			TUNING.POWER_SWORD_ACTIVE_DURATION, TUNING.POWER_SWORD_COOLDOWN,
			TUNING.POWER_SWORD_SECONDS_PER_EXTRA_ACTIVATION, false)
		if not bundle then return false, bundle_error end
		power_swords[#power_swords + 1] = bundle
	end

	local chain_weapons = {}
	for _, template_name in ipairs(CHAIN_TIMED_TEMPLATES) do
		local bundle, bundle_error = build_timed_mode_bundle(
			template_name, _weapon_templates[template_name],
			TUNING.CHAIN_WEAPON_ACTIVE_DURATION, TUNING.CHAIN_WEAPON_COOLDOWN,
			0, true)
		if not bundle then return false, bundle_error end
		chain_weapons[#chain_weapons + 1] = bundle
	end

	local chain_stagger_only = {}
	for _, template_name in ipairs(CHAIN_STAGGER_ONLY_TEMPLATES) do
		local bundle, bundle_error = build_chain_stagger_bundle(
			template_name, _weapon_templates[template_name])
		if not bundle then return false, bundle_error end
		chain_stagger_only[#chain_stagger_only + 1] = bundle
	end

	local folding_shovels = {}
	for _, template_name in ipairs(FOLDING_SHOVEL_TEMPLATES) do
		local bundle, bundle_error = build_persistent_shovel_bundle(
			template_name, _weapon_templates[template_name])
		if not bundle then return false, bundle_error end
		folding_shovels[#folding_shovels + 1] = bundle
	end

	local melta, melta_error = _melta.build(_weapon_templates, _ammo_templates)
	if not melta then return false, melta_error end
	local heavy, heavy_error
	if M.heavy then
		heavy, heavy_error = M.heavy.build(_weapon_templates, _ammo_templates, _dodge_templates)
		if not heavy then return false, heavy_error end
	end

	_restore = {
		melta = melta,
		heavy = heavy,
		template = template,
		hip = hip,
		zoom = zoom,
		ammo = original_ammo,
		keywords = template.keywords,
		buffs = original_buffs,
		base_template_lookup = original_lookup,
		dodge_source = _dodge_templates[HOTSHOT_DODGE_TEMPLATE],
		kickback = kickback,
		rumbler = rumbler,
		double_barrel = double_barrel,
		shredder = shredder,
		power_maul = {
			template = power_maul,
			tweak_data = original_power_maul_tweak,
		},
		plasma_cannon = plasma_cannon,
		plasma_pistol = plasma_pistol,
		vindicator = vindicator,
		hunter_stubber = hunter_stubber,
		grenadier_gauntlet = grenadier_gauntlet,
		rippers = rippers,
		stubber_reload_buffs = stubber_reload_buffs,
		reserve_ammo = reserve_ammo,
		heavy_swords = heavy_swords,
		thunder_hammers = thunder_hammers,
		power_swords = power_swords,
		chain_weapons = chain_weapons,
		chain_stagger_only = chain_stagger_only,
		folding_shovels = folding_shovels,
	}

	-- Commit only after every required branch has been built successfully.
	if M.rumbler then M.rumbler.apply(rumbler) end
	_melta.apply(melta, _ammo_templates)
	actions.action_shoot_hip = owned_hip
	actions.action_shoot_zoomed = owned_zoom
	_ammo_templates[HOTSHOT_TEMPLATE] = ammo
	_dodge_templates[HOTSHOT_DODGE_TEMPLATE] = HOTSHOT_DODGE_SOURCE
	template.__base_template_lookup = owned_lookup
	template.buffs = owned_buffs
	-- The Vraks Headhunter remains a ballistic autogun. In particular, do not
	-- add the shipped lasweapon keyword: Shock Trooper and similar las-only
	-- effects must not turn its deliberately tiny magazine into free shots.
	template.keywords = shallow_copy(template.keywords or {})

	local kickback_actions = kickback.template.actions
	kickback_actions.action_shoot_hip = kickback.owned_hip
	kickback_actions.action_shoot_zoomed = kickback.owned_zoom
	kickback.template.buffs = kickback.owned_buffs
	_ammo_templates[KICKBACK_TEMPLATE] = kickback.owned_ammo
	double_barrel.template.actions = double_barrel.owned_actions
	double_barrel.template.buffs = double_barrel.owned_buffs
	double_barrel.template.crosshair = double_barrel.owned_crosshair
	double_barrel.template.alternate_fire_settings = double_barrel.owned_alternate
	_ammo_templates[DOUBLE_BARREL.name] = double_barrel.owned_ammo

	local shredder_actions = shredder.template.actions
	shredder_actions.action_shoot_hip = shredder.owned_hip
	shredder_actions.action_shoot_zoomed = shredder.owned_zoom

	power_maul.weapon_special_tweak_data = owned_power_maul_tweak

	local plasma_actions = plasma_cannon.template.actions
	plasma_actions.action_charge_direct = plasma_cannon.owned_direct_charge
	plasma_actions.action_shoot = plasma_cannon.owned_primary
	plasma_actions.action_charge = plasma_cannon.owned_charge
	plasma_actions.action_shoot_charged = plasma_cannon.owned_charged
	plasma_cannon.template.buffs = plasma_cannon.owned_buffs
	_dodge_templates[PLASMA_CANNON_DODGE_TEMPLATE] =
		PLASMA_CANNON_DODGE_SOURCE
	plasma_cannon.template.__base_template_lookup = plasma_cannon.owned_lookup

	local plasma_pistol_actions = plasma_pistol.template.actions
	plasma_pistol_actions.action_shoot_hip = plasma_pistol.owned_hip
	plasma_pistol_actions.action_shoot_zoomed = plasma_pistol.owned_zoom
	plasma_pistol.template.hud_configuration = plasma_pistol.owned_hud
	plasma_pistol.template.overheat_configuration =
		plasma_pistol.owned_overheat
	plasma_pistol.template.keywords = plasma_pistol.owned_keywords
	_ammo_templates[PLASMA_PISTOL_TEMPLATE] = plasma_pistol.owned_ammo

	local vindicator_actions = vindicator.template.actions
	vindicator_actions.action_shoot = vindicator.owned_burst
	vindicator_actions.action_shoot_braced = vindicator.owned_auto
	vindicator_actions.push = vindicator.owned_push
	_ammo_templates[VINDICATOR_TEMPLATE] = vindicator.owned_ammo

	local hunter_stubber_actions = hunter_stubber.template.actions
	hunter_stubber_actions.action_shoot_hip = hunter_stubber.owned_hip
	hunter_stubber_actions.action_shoot_zoomed = hunter_stubber.owned_aimed

	grenadier_gauntlet.template.actions.action_execute_special =
		grenadier_gauntlet.owned_special

	for _, bundle in ipairs(rippers) do
		bundle.template.actions.action_shoot_hip = bundle.owned_hip
		bundle.template.actions.action_shoot_zoomed = bundle.owned_zoom
		bundle.template.buffs = bundle.owned_buffs
	end

	for _, bundle in ipairs(stubber_reload_buffs) do
		bundle.template.buffs = bundle.owned_buffs
	end

	for _, bundle in ipairs(reserve_ammo) do
		_ammo_templates[bundle.name] = bundle.owned_ammo
	end

	for _, bundle in ipairs(heavy_swords) do
		for action_name, owned_action in pairs(bundle.owned) do
			bundle.template.actions[action_name] = owned_action
		end
	end

	for _, bundle in ipairs(thunder_hammers) do
		for action_name, owned_action in pairs(bundle.owned) do
			bundle.template.actions[action_name] = owned_action
		end
		if bundle.role == "line_breaker" then
			bundle.template.weapon_special_class =
				TUNING.THUNDER_HAMMER_LINE_SPECIAL_CLASS
			bundle.template.weapon_special_tweak_data =
				bundle.owned_tweak_data
			bundle.template.weapon_counter = bundle.owned_counter
		end
	end

	for _, bundle in ipairs(power_swords) do
		for action_name, owned_action in pairs(bundle.owned) do
			bundle.template.actions[action_name] = owned_action
		end
		bundle.template.weapon_special_class = TUNING.TIMED_SPECIAL_CLASS
		bundle.template.weapon_special_tweak_data = bundle.owned_tweak_data
		bundle.template.weapon_counter = bundle.owned_counter
	end

	for _, bundle in ipairs(chain_weapons) do
		for action_name, owned_action in pairs(bundle.owned) do
			bundle.template.actions[action_name] = owned_action
		end
		bundle.template.weapon_special_class = TUNING.TIMED_SPECIAL_CLASS
		bundle.template.weapon_special_tweak_data = bundle.owned_tweak_data
		bundle.template.weapon_counter = bundle.owned_counter
	end

	for _, bundle in ipairs(chain_stagger_only) do
		for action_name, owned_action in pairs(bundle.owned) do
			bundle.template.actions[action_name] = owned_action
		end
	end

	for _, bundle in ipairs(folding_shovels) do
		bundle.template.weapon_special_class =
			TUNING.PERSISTENT_SHOVEL_SPECIAL_CLASS
	end

	if M.heavy then M.heavy.apply(heavy, _ammo_templates, _dodge_templates) end
	_applied = true
	_pending = false
	APPLY_DIAG.last_error = nil

	if _event_log then
		_event_log.emit({
			t = _shared.fixed_time(),
			event = "weapon_rebalance_applied",
			id = _event_log.next_id(),
			weapon = "focused_batch",
			prototype = "v0.28.94",
		})
		for i = 1, #APPLY_DIAG.skipped_optional do
			_event_log.emit({
				t = _shared.fixed_time(),
				event = "weapon_rebalance_optional_skipped",
				id = _event_log.next_id(),
				reason = APPLY_DIAG.skipped_optional[i],
			})
		end
	end
	_debug_log("weapon_rebalance:batch", _shared.fixed_time(),
		"applied weapon batch with powered-mode conversions", 0, "info")

	return true
end

-- Applying can be attempted before all three template registries arrive, then
-- retried by their require hooks. Treat a false return as a real diagnostic,
-- not only a thrown Lua error, and preserve the latest distinct reason.
local function attempt_apply(scope)
	local applied, reason = try_apply()
	if applied then return true end

	local message = tostring(reason)
	local changed = APPLY_DIAG.last_error ~= message
	APPLY_DIAG.last_error = message
	if changed and _event_log then
		_event_log.emit({
			t = _shared.fixed_time(),
			event = "weapon_rebalance_apply_failed",
			id = _event_log.next_id(),
			scope = scope or _scope or "unknown",
			reason = message,
		})
	end
	if changed then
		_debug_log("weapon_rebalance:apply_failed", _shared.fixed_time(),
			(scope or _scope or "unknown") .. ": " .. message, 0, "info")
	end
	return false, reason
end

function M.prepare_for_loading()
	-- The exact Meat Grinder launch button arms this before StateLoading. Keep
	-- that early patch alive so the weapon instance copies the custom ammo.
	if _scope == "meat_grinder" then
		if _settings.custom_weapon_balancing_meat_grinder_enabled() then
			_pending = not _applied
			return _applied or attempt_apply("meat_grinder")
		end
		M.revert()
	end

	M.revert()

	local eligible, reason = eligible_pilgrimage_launch()
	if not eligible then
		_pending = false
		return false, reason
	end

	_scope = "pilgrimage"
	_pending = true
	return attempt_apply("pilgrimage")
end

function M.ensure_applied()
	if _scope == "meat_grinder" then
		if not _settings.custom_weapon_balancing_meat_grinder_enabled()
			or not _shared.is_in_psykhanium() then
			M.revert()
			return false
		end
	elseif _scope == "pilgrimage" then
		local eligible = eligible_pilgrimage_launch()
		if not eligible or _shared.is_in_psykhanium() then
			M.revert()
			return false
		end
	else
		local eligible = eligible_pilgrimage_launch()
		if not eligible or _shared.is_in_psykhanium() then return false end
		_scope = "pilgrimage"
	end

	if _applied then return true end
	if not _pending then
		_pending = true
	end
	return attempt_apply(_scope)
end

function M.prepare_for_meat_grinder_loading()
	M.revert()
	if not _settings.custom_weapon_balancing_meat_grinder_enabled() then
		return false, "Meat Grinder setting off"
	end

	_scope = "meat_grinder"
	-- Clicking Launch happens while the Mourningstar's GameplayStateRun is still
	-- active. Its exit cleanup must spare this patch exactly once so StateLoading
	-- can construct the Meat Grinder weapon with the custom ammunition.
	_preserve_next_gameplay_exit = true
	_pending = true
	return attempt_apply("meat_grinder")
end

function M.revert()
	_pending = false
	_scope = nil
	_preserve_next_gameplay_exit = false
	if not _applied or not _restore then return 0 end
	if M.rumbler then M.rumbler.revert(_restore.rumbler) end
	_melta.revert(_restore.melta, _ammo_templates)
	if M.heavy then M.heavy.revert(_restore.heavy, _ammo_templates, _dodge_templates) end

	local actions = _restore.template and _restore.template.actions
	if actions then
		actions.action_shoot_hip = _restore.hip
		actions.action_shoot_zoomed = _restore.zoom
	end
	if _restore.template then
		_restore.template.keywords = _restore.keywords
		_restore.template.buffs = _restore.buffs
		_restore.template.__base_template_lookup = _restore.base_template_lookup
	end
	if _ammo_templates then
		_ammo_templates[HOTSHOT_TEMPLATE] = _restore.ammo
	end
	if _dodge_templates then
		_dodge_templates[HOTSHOT_DODGE_TEMPLATE] = _restore.dodge_source
	end

	local kickback = _restore.kickback
	local double_barrel = _restore.double_barrel
	if double_barrel then
		double_barrel.template.actions = double_barrel.actions
		double_barrel.template.buffs = double_barrel.buffs
		double_barrel.template.crosshair = double_barrel.crosshair
		double_barrel.template.alternate_fire_settings = double_barrel.alternate
		if _ammo_templates then _ammo_templates[DOUBLE_BARREL.name] = double_barrel.ammo end
	end
	if kickback and kickback.template then
		local kickback_actions = kickback.template.actions
		if kickback_actions then
			kickback_actions.action_shoot_hip = kickback.hip
			kickback_actions.action_shoot_zoomed = kickback.zoom
		end
		kickback.template.buffs = kickback.buffs
		if _ammo_templates then
			_ammo_templates[KICKBACK_TEMPLATE] = kickback.ammo
		end
	end

	local shredder = _restore.shredder
	if shredder and shredder.template and shredder.template.actions then
		shredder.template.actions.action_shoot_hip = shredder.hip
		shredder.template.actions.action_shoot_zoomed = shredder.zoom
	end

	local power_maul = _restore.power_maul
	if power_maul and power_maul.template then
		power_maul.template.weapon_special_tweak_data = power_maul.tweak_data
	end

	local plasma_cannon = _restore.plasma_cannon
	if plasma_cannon and plasma_cannon.template then
		local plasma_actions = plasma_cannon.template.actions
		if plasma_actions then
			plasma_actions.action_charge_direct = plasma_cannon.direct_charge
			plasma_actions.action_shoot = plasma_cannon.primary
			plasma_actions.action_charge = plasma_cannon.charge
			plasma_actions.action_shoot_charged = plasma_cannon.charged
		end
		plasma_cannon.template.buffs = plasma_cannon.buffs
		plasma_cannon.template.__base_template_lookup =
			plasma_cannon.base_template_lookup
		if _dodge_templates then
			_dodge_templates[PLASMA_CANNON_DODGE_TEMPLATE] =
				plasma_cannon.dodge_source
		end
	end

	local plasma_pistol = _restore.plasma_pistol
	if plasma_pistol and plasma_pistol.template then
		local pistol_actions = plasma_pistol.template.actions
		if pistol_actions then
			pistol_actions.action_shoot_hip = plasma_pistol.hip
			pistol_actions.action_shoot_zoomed = plasma_pistol.zoom
		end
		plasma_pistol.template.hud_configuration = plasma_pistol.hud
		plasma_pistol.template.overheat_configuration = plasma_pistol.overheat
		plasma_pistol.template.keywords = plasma_pistol.keywords
		if _ammo_templates then
			_ammo_templates[PLASMA_PISTOL_TEMPLATE] = plasma_pistol.ammo
		end
	end

	local vindicator = _restore.vindicator
	if vindicator and vindicator.template then
		local vindicator_actions = vindicator.template.actions
		if vindicator_actions then
			vindicator_actions.action_shoot = vindicator.burst
			vindicator_actions.action_shoot_braced = vindicator.auto
			vindicator_actions.push = vindicator.push
		end
		if _ammo_templates then
			_ammo_templates[VINDICATOR_TEMPLATE] = vindicator.ammo
		end
	end

	local hunter_stubber = _restore.hunter_stubber
	if hunter_stubber and hunter_stubber.template
		and hunter_stubber.template.actions then
		hunter_stubber.template.actions.action_shoot_hip =
			hunter_stubber.hip
		hunter_stubber.template.actions.action_shoot_zoomed =
			hunter_stubber.aimed
	end

	local grenadier_gauntlet = _restore.grenadier_gauntlet
	if grenadier_gauntlet and grenadier_gauntlet.template
		and grenadier_gauntlet.template.actions then
		grenadier_gauntlet.template.actions.action_execute_special =
			grenadier_gauntlet.special
	end

	for _, bundle in ipairs(_restore.rippers or {}) do
		if bundle.template and bundle.template.actions then
			bundle.template.actions.action_shoot_hip = bundle.hip
			bundle.template.actions.action_shoot_zoomed = bundle.zoom
			bundle.template.buffs = bundle.buffs
		end
	end

	for _, bundle in ipairs(_restore.stubber_reload_buffs or {}) do
		if bundle.template then
			bundle.template.buffs = bundle.buffs
		end
	end

	for _, bundle in ipairs(_restore.reserve_ammo or {}) do
		if _ammo_templates then
			_ammo_templates[bundle.name] = bundle.ammo
		end
	end

	for _, bundle in ipairs(_restore.heavy_swords or {}) do
		if bundle.template and bundle.template.actions then
			for action_name, original_action in pairs(bundle.originals or {}) do
				bundle.template.actions[action_name] = original_action
			end
		end
	end

	for _, bundle in ipairs(_restore.thunder_hammers or {}) do
		if bundle.template and bundle.template.actions then
			for action_name, original_action in pairs(bundle.originals or {}) do
				bundle.template.actions[action_name] = original_action
			end
			bundle.template.weapon_special_class = bundle.special_class
			bundle.template.weapon_special_tweak_data = bundle.tweak_data
			bundle.template.weapon_counter = bundle.counter
		end
	end

	for _, bundle in ipairs(_restore.power_swords or {}) do
		if bundle.template and bundle.template.actions then
			for action_name, original_action in pairs(bundle.originals or {}) do
				bundle.template.actions[action_name] = original_action
			end
			bundle.template.weapon_special_class = bundle.special_class
			bundle.template.weapon_special_tweak_data = bundle.tweak_data
			bundle.template.weapon_counter = bundle.counter
		end
	end

	for _, bundle in ipairs(_restore.chain_weapons or {}) do
		if bundle.template and bundle.template.actions then
			for action_name, original_action in pairs(bundle.originals or {}) do
				bundle.template.actions[action_name] = original_action
			end
			bundle.template.weapon_special_class = bundle.special_class
			bundle.template.weapon_special_tweak_data = bundle.tweak_data
			bundle.template.weapon_counter = bundle.counter
		end
	end

	for _, bundle in ipairs(_restore.chain_stagger_only or {}) do
		if bundle.template and bundle.template.actions then
			for action_name, original_action in pairs(bundle.originals or {}) do
				bundle.template.actions[action_name] = original_action
			end
		end
	end

	for _, bundle in ipairs(_restore.folding_shovels or {}) do
		if bundle.template then
			bundle.template.weapon_special_class = bundle.special_class
		end
	end

	_restore = nil
	_applied = false
	_debug_log("weapon_rebalance:revert", _shared.fixed_time(),
		"reverted custom weapon balance batch", 0, "info")
	return 1
end

function M.receive_weapon_templates(templates)
	if type(templates) == "table" then
		_weapon_templates = templates
		if _pending then attempt_apply(_scope) end
	end
end

function M.receive_ammo_templates(templates)
	if type(templates) == "table" then
		_ammo_templates = templates
		if _pending then attempt_apply(_scope) end
	end
end

function M.receive_dodge_templates(templates)
	if type(templates) == "table" then
		_dodge_templates = templates
		if _pending then attempt_apply(_scope) end
	end
end

function M.is_applied()
	return _applied
end

function M.consume_prepared_transition()
	if not _preserve_next_gameplay_exit then return false end
	_preserve_next_gameplay_exit = false
	return true
end

function M.install_training_grounds_view(TrainingGroundsOptionsView)
	if _training_grounds_hook_installed or not _mod
		or type(TrainingGroundsOptionsView) ~= "table"
		or type(TrainingGroundsOptionsView._start_training_grounds) ~= "function" then
		return false
	end

	_training_grounds_hook_installed = true
	_mod:hook(TrainingGroundsOptionsView, "_start_training_grounds",
		function(func, self, mechanism_context, ...)
			local mission_name = mechanism_context and mechanism_context.mission_name
			local is_meat_grinder = self
				and self.training_grounds_settings == "shooting_range"
				and mission_name == MEAT_GRINDER_MISSION

			if is_meat_grinder then
				local ok, err = pcall(M.prepare_for_meat_grinder_loading)
				if not ok then
					M.revert()
					_debug_log("weapon_rebalance:meat_grinder_arm", 0,
						"could not arm Meat Grinder balance: " .. tostring(err), 0, "info")
				end
			else
				M.revert()
			end

			return func(self, mechanism_context, ...)
		end)

	return true
end

local function core_status()
	return {
		applied = _applied,
		pending = _pending,
		scope = _scope,
		prepared_transition = _preserve_next_gameplay_exit,
		template = HOTSHOT_TEMPLATE,
		shot_cycle = SHOT_CYCLE,
		clip_size = HOTSHOT_CLIP_SIZE,
		movement_penalty = HOTSHOT_MOVEMENT_PENALTY,
		damage = HOTSHOT_DAMAGE,
		finesse = HOTSHOT_FINESSE,
		dodge_template = HOTSHOT_DODGE_TEMPLATE,
		kickback_clip_size = KICKBACK_CLIP_SIZE,
		kickback_shot_gap = DOUBLE_BARREL.kickback_gap,
		double_barrel_reload_time = 1.8,
		kickback_damage_factor = KICKBACK_DAMAGE_FACTOR,
		kickback_reload_time = KICKBACK_RELOAD_TIME,
		kickback_reload_time_scale = KICKBACK_RELOAD_TIME_SCALE,
		shredder_cleave = SHREDDER_CLEAVE[2],
		power_maul_cooldown = POWER_MAUL_COOLDOWN,
		plasma_cannon_template = PLASMA_CANNON_TEMPLATE,
		plasma_cannon_primary_ammo = PLASMA_CANNON_PRIMARY_AMMO,
		plasma_cannon_charged_ammo = PLASMA_CANNON_CHARGED_AMMO_MAX,
		plasma_cannon_damage_factor = PLASMA_CANNON_CHARGED_DAMAGE,
		plasma_cannon_radius = PLASMA_CANNON_RADIUS,
		plasma_cannon_penetration = PLASMA_CANNON_PENETRATION_DEPTH,
		plasma_cannon_movement_penalty = PLASMA_CANNON_WIELD_PENALTY,
		plasma_cannon_dodge_template = PLASMA_CANNON_DODGE_TEMPLATE,
		plasma_pistol_template = PLASMA_PISTOL_TEMPLATE,
		plasma_pistol_clip_size = PLASMA_PISTOL_CLIP_SIZE,
		plasma_pistol_reserve = PLASMA_PISTOL_RESERVE,
		plasma_pistol_shot_cycle = PLASMA_PISTOL_SHOT_CYCLE,
		plasma_pistol_heat_per_shot = PLASMA_PISTOL_HEAT_PER_SHOT,
		plasma_pistol_cooling_delay = PLASMA_PISTOL_COOLING_DELAY,
		plasma_pistol_vent_duration = PLASMA_PISTOL_VENT_DURATION,
		plasma_pistol_heat_hook = _plasma_pistol_heat_hook_installed,
		plasma_pistol_heat_events = _plasma_pistol_heat_events,
	}
end

local function extended_status()
	return {
		last_apply_error = APPLY_DIAG.last_error,
		skipped_optional = table.concat(APPLY_DIAG.skipped_optional, " | "),
		vindicator_template = VINDICATOR_TEMPLATE,
		vindicator_damage_factor = VINDICATOR_DAMAGE_FACTOR,
		vindicator_impact_factor = VINDICATOR_IMPACT_FACTOR,
		vindicator_clip_factor = VINDICATOR_CLIP_FACTOR,
		vindicator_reserve_factor = VINDICATOR_RESERVE_FACTOR,
		vindicator_shove_bleed = VINDICATOR_SHOVE_BLEED,
		vindicator_brittleness_hooks = _vindicator_brittleness_hooks_installed,
		vindicator_brittleness_stacks = _vindicator_brittleness_stacks,
		hunter_stubber_template = HUNTER_STUBBER_TEMPLATE,
		hunter_stubber_damage_factor = HUNTER_STUBBER_DAMAGE_FACTOR,
		hunter_stubber_impact_factor = HUNTER_STUBBER_IMPACT_FACTOR,
		hunter_stubber_aimed_shot_cycle = HUNTER_STUBBER_AIMED_SHOT_CYCLE,
		grenadier_gauntlet_template = GRENADIER_GAUNTLET_TEMPLATE,
		grenadier_gauntlet_damage_per_shell =
			GRENADIER_GAUNTLET_DAMAGE_PER_SHELL,
		grenadier_gauntlet_carapace_factor =
			GRENADIER_GAUNTLET_CARAPACE_FACTOR,
		grenadier_gauntlet_hook = _grenadier_gauntlet_hook_installed,
		grenadier_gauntlet_mag_dumps = _grenadier_gauntlet_mag_dumps,
		ripper_marks = #RIPPER_TEMPLATES,
		ripper_damage_factor = RIPPER_DAMAGE_FACTOR,
		ripper_cleave_factor = RIPPER_CLEAVE_FACTOR,
		ogryn_ranged_reload_speed_bonus = OGRYN_RANGED_RELOAD_SPEED_BONUS,
		reserve_ammo_marks = #RESERVE_AMMO_FACTORS,
		heavy_sword_marks = #HEAVY_SWORD_TEMPLATES,
		power_sword_marks = #POWER_SWORD_TIMED_TEMPLATES,
		power_sword_active_duration = TUNING.POWER_SWORD_ACTIVE_DURATION,
		power_sword_cooldown = TUNING.POWER_SWORD_COOLDOWN,
		chain_weapon_marks = #CHAIN_TIMED_TEMPLATES
			+ #CHAIN_STAGGER_ONLY_TEMPLATES,
		chain_weapon_active_duration = TUNING.CHAIN_WEAPON_ACTIVE_DURATION,
		chain_weapon_cooldown = TUNING.CHAIN_WEAPON_COOLDOWN,
		chain_latched_stagger_hook = _chain_stagger_hook_installed,
		folding_shovel_marks = #FOLDING_SHOVEL_TEMPLATES,
	}
end

function M.status()
	local status = core_status()
	status.melta = _melta and _melta.status()
	for key, value in pairs(extended_status()) do
		status[key] = value
	end
	return status
end

function M.owned_ironhelm_tweak(template_name)
	if not _applied or template_name ~= "thunderhammer_2h_p1_m2" then return nil end
	for _, bundle in ipairs(_restore and _restore.thunder_hammers or {}) do
		if bundle.name == template_name and bundle.role == "line_breaker" then
			return bundle.owned_tweak_data
		end
	end
end

function M.install_double_barrel_hit_result(calculation)
	if calculation.__pilgrimage_double_barrel then return end
	calculation.__pilgrimage_double_barrel = true
	_mod:hook(calculation, "calculate_attack_result", function(func, damage, profile, attack_type, direction, instakill, ...)
		-- Called by native Attack only after block/assisted/hogtied checks.
		-- Retain the original attack, damage permission and invulnerability rules.
		if _applied and profile and profile.pilgrimage_double_barrel_execute
			and attack_type == "ranged" and type(damage) == "number" and damage > 0
			and _shared and _shared.is_server and _shared.is_server()
			and not select(1, ...) and select(2, ...) then
			local unit = select(15, ...)
			local data = unit and ScriptUnit.has_extension(unit, "unit_data_system")
			local breed = data and data:breed()
			if breed and (breed.name == "chaos_poxwalker" or breed.name == "chaos_newly_infected") then
				-- Native minion health calculation ignores the instakill flag;
				-- Attack normally converts it to lethal damage earlier. Raise this
				-- already legal hit instead, keeping shield/invulnerability handling.
				local max_health = select(6, ...)
				if type(max_health) == "number" and max_health > 0 then
					damage = math.max(damage, max_health)
				end
			end
		end
		return func(damage, profile, attack_type, direction, instakill, ...)
	end)
end

function M.install_double_barrel_crosshair(template)
	if template.__pilgrimage_double_barrel then return end
	template.__pilgrimage_double_barrel = true
	_mod:hook(template, "update_function", function(func, parent, renderer, widget, definition, settings, ...)
		func(parent, renderer, widget, definition, settings, ...)
		local scale = settings and settings.pilgrimage_double_barrel_spread
		if not _applied or not scale then return end
		local yaw, pitch = parent:_spread_yaw_pitch()
		if not yaw or not pitch then return end
		-- Native update rewrites segment positions each frame. Scale afterwards
		-- so even its minimum spacing reflects the tighter cone, without shrinking
		-- the artwork, hit markers or accumulating a scale from previous frames.
		for _, name in ipairs({"left", "right", "top", "bottom"}) do
			local style = widget.style[name]
			if style and style.offset then
				style.offset[1] = style.offset[1] * scale
				style.offset[2] = style.offset[2] * scale
			end
		end
	end)
end

function M.init(deps)
	M.rumbler = deps.rumbler
	_melta = assert(deps.melta, "weapon_melta must be loaded once by bootstrap")
	M.heavy = deps.heavy
	_mod = deps.mod
	_settings = deps.settings
	_run_state = deps.run_state
	_shared = deps.shared
	_event_log = deps.event_log
	_debug_log = deps.debug_log or function() end
	_hooks = deps.hooks
	if deps.passives and type(deps.passives.register_template_source) == "function" then
		deps.passives.register_template_source(WEAPON_BUFF_TEMPLATES)
	end
	install_vindicator_brittleness_hooks()
	install_vindicator_shove_sound()
	install_plasma_pistol_heat_hook()
	install_grenadier_gauntlet_hook()
end

M.AMMO_TEMPLATES_PATH = AMMO_TEMPLATES_PATH
M.DODGE_TEMPLATES_PATH = DODGE_TEMPLATES_PATH
M.TRAINING_GROUNDS_VIEW_PATH = TRAINING_GROUNDS_VIEW_PATH
M.STAGGER_CALCULATION_PATH = TUNING.STAGGER_CALCULATION_PATH
M.CHAIN_STAGGER_MARKER = TUNING.CHAIN_STAGGER_MARKER
M.should_force_chain_stagger = should_force_chain_stagger

return M
