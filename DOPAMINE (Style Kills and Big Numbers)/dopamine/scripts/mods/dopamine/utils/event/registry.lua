

---@type mod
local mod = get_mod("dopamine")

if mod.event_registry then
	return mod.event_registry
end

local Constants = mod:core(mod.style_meter_constants, "hud/style_meter/constants").LOGIC
local EventEnums = mod:core(mod.event_enums, "utils/event/enums")
local HitTrackers = mod:core(mod.hit_trackers, "utils/hit_trackers")

local LABELS = {
	COMBO = mod.dl.icons.icons.flame .. " COMBO",
}

---@param lifetime number|nil
---@return number
local function event_lifetime(lifetime)
	return lifetime or Constants.EVENTS_LIFETIME.DEFAULT
end

local distance = {
	very_close = 2,
	close = 5,
	mid = 10,
	far = 18,
	very_far = 999,
}

---@param context EventContext
---@return boolean
local function ranged(context)
	return context and context.attack_type == "ranged"
end

---@param context EventContext
---@return boolean
local function melee(context)
	return context and context.attack_type == "melee"
end

---@param context EventContext
---@return boolean
local function headshot(context)
	return context and context.hit_weakspot and true or false
end

---@class Event
---@field id EventID
---@field signals SignalID[] | nil -- trigger signals this event listens to; nil = manual-only
---@field label_key string | nil -- localization key for the row label
---@field label string | nil -- literal rich-text label (mutually exclusive with label_key)
---@field lifetime number | nil
---@field exclusive_group string | nil -- only the highest-priority member of a group survives
---@field priority number | nil
---@field color rgb_table | nil
---@field show_in_meter boolean | nil -- false = score-only, never occupies a visible slot (default true)
---@field always_coexist boolean | nil -- true = stacks with every other resolved event
---@field can_coexist EventID[] | nil -- explicit allow-list of otherwise-conflicting events
---@field matches fun(context: EventContext): boolean

---@type Event[]
local EVENTS = {
	{
		id = EventEnums.EVENT_ID.generic_headshot,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_generic_headshot",
		show_in_meter = false,
		always_coexist = true,
		matches = function(ctx)
			return headshot(ctx)
		end,
	},
	{
		id = EventEnums.EVENT_ID.headshot,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_headshot",
		show_in_meter = true,
		always_coexist = true,
		exclusive_group = "headshots",
		priority = 0,
		matches = function(ctx)
			return headshot(ctx) and ctx.kill_distance.between(distance.close, distance.mid)
		end,
	},
	{
		id = EventEnums.EVENT_ID.close_headshot,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_executioner",
		show_in_meter = true,
		always_coexist = true,
		exclusive_group = "headshots",
		priority = 10,
		matches = function(ctx)
			return headshot(ctx) and melee(ctx)
		end,
	},
	{
		id = EventEnums.EVENT_ID.far_headshot,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_marksman",
		show_in_meter = true,
		always_coexist = true,
		exclusive_group = "headshots",
		priority = 10,
		matches = function(ctx)
			return headshot(ctx) and ctx.kill_distance.between(distance.mid, distance.very_far)
		end,
	},
	{
		id = EventEnums.EVENT_ID.ranged_in_melee,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_ranged_in_melee",
		show_in_meter = true,
		always_coexist = true,
		matches = function(ctx)
			return ranged(ctx) and ctx.kill_distance.between(distance.very_close, distance.close)
		end,
	},
	{
		id = EventEnums.EVENT_ID.flow,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_adaptive",
		show_in_meter = true,
		always_coexist = true,
		matches = function(ctx)
			return ctx.event_is_active(EventEnums.EVENT_ID.close_headshot)
				and ranged(ctx)
				and ctx.kill_distance.between(distance.close, distance.very_far)
		end,
	},
	{
		id = EventEnums.EVENT_ID.berserk,
		signals = { EventEnums.SIGNAL_ID.berserk },
		label_key = "event_berserker",

		always_coexist = true,
		matches = function(ctx)
			return ctx.hit_count ~= nil and HitTrackers.Berserk:qualifies(ctx.hit_count)
		end,
	},
	{
		id = EventEnums.EVENT_ID.mag_dump,
		signals = { EventEnums.SIGNAL_ID.mag_dump },
		label_key = "event_mag_dump",
		always_coexist = true,
		matches = function(ctx)

			return ctx.hit_count ~= nil and HitTrackers.MagDump:qualifies(ctx.hit_count)
		end,
	},
	{
		id = EventEnums.EVENT_ID.multi_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_multi_kill",
		always_coexist = true,
		matches = function(context)
			return context.kills_in_burst and context.kills_in_burst >= 2
		end,
	},
	{
		id = EventEnums.EVENT_ID.generic_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_generic_kill",
		show_in_meter = false,
		always_coexist = true,
		matches = function(context)

			return true
		end,
	},
	{
		id = EventEnums.EVENT_ID.kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_kill",
		show_in_meter = false,
		exclusive_group = "kill",
		priority = 10,
		matches = function(context)

			return true
		end,
	},
	{
		id = EventEnums.EVENT_ID.melee_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_melee_kill",
		show_in_meter = false,
		always_coexist = true,
		exclusive_group = "kill",
		priority = 20,
		matches = function(context)

			return context.attack_type == "melee"
		end,
	},
	{
		id = EventEnums.EVENT_ID.ranged_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_ranged_kill",
		show_in_meter = false,

		always_coexist = true,
		exclusive_group = "kill",
		priority = 30,
		matches = function(context)

			return context.attack_type == "ranged"
		end,
	},
	{
		id = EventEnums.EVENT_ID.slide_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_slide_kill",
		show_in_meter = true,
		always_coexist = true,
		matches = function(context)
			return context.is_sliding
		end,
	},
	{
		id = EventEnums.EVENT_ID.dodge,
		signals = { EventEnums.SIGNAL_ID.dodge },
		label_key = "event_dodge",
		color = mod.dl.colors.reg.ui.toughness_default,
		lifetime = event_lifetime(2.5),
		always_coexist = false,
		priority = 1,
		exclusive_group = EventEnums.SIGNAL_ID.dodge,

		matches = function()
			return true
		end,
	},
	{
		id = EventEnums.EVENT_ID.parry,
		signals = { EventEnums.SIGNAL_ID.parry },
		label_key = "event_parry",
		color = mod.constants.COLOR.NUMBERS.ORANGE,
		show_in_meter = true,

		always_coexist = true,

		matches = function()
			return true
		end,
	},
	{
		id = EventEnums.EVENT_ID.perfect_block,
		signals = { EventEnums.SIGNAL_ID.perfect_block },
		label_key = "event_perfect_block",

		show_in_meter = false,
		always_coexist = true,

		matches = function()
			return true
		end,
	},
	{
		id = EventEnums.EVENT_ID.combo_finish,
		label = LABELS.COMBO,
		color = mod.constants.COLOR.NUMBERS.GREEN,

		matches = function()
			return false
		end,
	},
	{
		id = EventEnums.EVENT_ID.objective_time,
		label_key = "event_objective_time",
		color = mod.constants.COLOR.NUMBERS.ORANGE,

		lifetime = 2,

		always_coexist = true,
		matches = function()
			return false
		end,
	},

	{
		id = EventEnums.EVENT_ID.elite_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_elite_kill",
		show_in_meter = false,
		always_coexist = true,
		matches = function(context)
			return mod.dl.breeds.is(context.breed_data, "category.elite")
		end,
	},
	{
		id = EventEnums.EVENT_ID.boss_kill,
		label_key = "event_boss_kill",
		color = mod.dl.colors.reg.ui.health_critical,
		show_in_meter = true,
		always_coexist = true,

		matches = function()
			return false
		end,
	},
	{
		id = EventEnums.EVENT_ID.disabler_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_priority_target",
		show_in_meter = mod.dl.settings.enable_breed_kill_events ~= true,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "combat_style.disabler")
		end,
	},
	{
		id = EventEnums.EVENT_ID.crusher_kill_flavor,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_can_opener",
		show_in_meter = mod.dl.settings.enable_breed_kill_events ~= true,
		matches = function(ctx)
			return mod.dl.breeds.is_any(ctx.breed_data, "Crusher", "Mauler")
		end,
	},
	{
		id = EventEnums.EVENT_ID.pox_burster_kill_flavor,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_fireworks",
		show_in_meter = mod.dl.settings.enable_breed_kill_events ~= true,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "Poxburster")
		end,
	},

	{
		id = EventEnums.EVENT_ID.horde_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_horde_kill",
		show_in_meter = false,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "group.melee_horde")
		end,
	},
	{
		id = EventEnums.EVENT_ID.pox_burster_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_pox_burster_kill",
		show_in_meter = mod.dl.settings.enable_breed_kill_events,
		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.vibrant_yellow or nil,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "Poxburster")
		end,
	},
	{
		id = EventEnums.EVENT_ID.bulwark_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_bulwark_kill",
		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.clay_orange or nil,
		show_in_meter = mod.dl.settings.enable_breed_kill_events,

		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "Bulwark")
		end,
	},
	{
		id = EventEnums.EVENT_ID.crusher_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_crusher_kill",
		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.blue_lighter or nil,
		show_in_meter = mod.dl.settings.enable_breed_kill_events,

		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "Crusher")
		end,
	},
	{
		id = EventEnums.EVENT_ID.mauler_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_mauler_kill",
		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.blue_lighter or nil,
		show_in_meter = mod.dl.settings.enable_breed_kill_events,

		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "Mauler")
		end,
	},
	{
		id = EventEnums.EVENT_ID.rager_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_rager_kill",
		show_in_meter = mod.dl.settings.enable_breed_kill_events,

		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.teal_green or nil,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "group.ragers")
		end,
	},
	{
		id = EventEnums.EVENT_ID.flamer_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_flamer_kill",
		show_in_meter = mod.dl.settings.enable_breed_kill_events,
		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.orange or nil,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "group.flamers")
		end,
	},
	{
		id = EventEnums.EVENT_ID.bomber_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_bomber_kill",
		show_in_meter = mod.dl.settings.enable_breed_kill_events,
		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.red or nil,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "group.bombers")
		end,
	},
	{
		id = EventEnums.EVENT_ID.shotgunner_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_shotgunner_kill",
		show_in_meter = mod.dl.settings.enable_breed_kill_events,
		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.green or nil,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "group.shotgunners")
		end,
	},
	{
		id = EventEnums.EVENT_ID.sniper_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_sniper_kill",
		show_in_meter = mod.dl.settings.enable_breed_kill_events,
		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.purple or nil,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "group.snipers")
		end,
	},
	{
		id = EventEnums.EVENT_ID.gunner_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_gunner_kill",
		show_in_meter = mod.dl.settings.enable_breed_kill_events,
		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.mint_green_lighter
			or nil,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "group.gunners")
		end,
	},
	{
		id = EventEnums.EVENT_ID.hound_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_hound_kill",
		show_in_meter = mod.dl.settings.enable_breed_kill_events,
		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.yellow or nil,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "group.hounds")
		end,
	},
	{
		id = EventEnums.EVENT_ID.trapper_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_trapper_kill",
		show_in_meter = mod.dl.settings.enable_breed_kill_events,
		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.yellow or nil,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "Trapper")
		end,
	},
	{
		id = EventEnums.EVENT_ID.mutant_kill,
		signals = { EventEnums.SIGNAL_ID.kill },
		label_key = "event_mutant_kill",
		show_in_meter = mod.dl.settings.enable_breed_kill_events,
		color = mod.dl.settings.enable_colored_breed_kills and mod.constants.COLOR.named_colors.yellow or nil,
		matches = function(ctx)
			return mod.dl.breeds.is(ctx.breed_data, "group.mutants")
		end,
	},
}

---@class EventRegistry
local EventRegistry = {}

---@return Event[]
function EventRegistry.all()
	return EVENTS
end

---@param definition Event
---@param signal_name SignalID
---@return boolean
function EventRegistry.listens_to(definition, signal_name)
	local signals = definition.signals
	if not signals then
		return false
	end

	for i = 1, #signals do
		if signals[i] == signal_name then
			return true
		end
	end

	return false
end

---@param event_id EventID
---@return Event | nil
function EventRegistry.by_id(event_id)
	for i = 1, #EVENTS do
		local definition = EVENTS[i]
		if definition.id == event_id then
			return definition
		end
	end

	return nil
end

mod.event_registry = EventRegistry

return EventRegistry
