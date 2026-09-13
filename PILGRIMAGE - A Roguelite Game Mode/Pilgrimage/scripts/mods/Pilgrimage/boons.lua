-- boons.lua
--
-- Run-scoped buffs, drafted between legs and applied on every mission start.
--
-- ===========================================================================
-- WE DO NOT INVENT BUFFS. WE REUSE THE ONES THE GAME ALREADY SHIPS.
-- ===========================================================================
--
-- Mortis Trials introduced 138 "Mission Buffs": burning on melee hit, two extra wounds,
-- infinite ammo during stance, and so on. They are exactly the shape a Chaos Wastes boon
-- wants, they are already balanced, already localised, and already have icons.
--
-- Crucially they are also merged into the GLOBAL BuffTemplates table, not kept somewhere
-- only the Hordes manager can see. buff_templates.lua:32-48 pulls every hordes file in
-- through _create_entry, so BuffTemplates["hordes_buff_two_extra_wounds"] resolves and
-- add_externally_controlled_buff can find it by name. That single fact is what makes this
-- module twenty lines of application code instead of a custom buff system.
--
-- ===========================================================================
-- THE THREE TRAPS
-- ===========================================================================
--
-- 1. THE RETURN VALUES ARE NOT WHAT YOU EXPECT.
--
--        player_unit_buff_extension.lua:226
--        return client_tried_adding_rpc_buff, index, component_index
--
--    The FIRST value is an error flag, not the handle. An earlier draft of this mod had
--    this wrong and assigned the flag to the index, which would have leaked every buff it
--    ever applied. Success is `index ~= nil`, and that is also how the game's own
--    mission_buffs_handler.lua:121 tests it. Note it does not test the flag: a "muted"
--    buff returns a real index with nothing applied, so index is the only honest signal.
--
-- 2. APPLYING TWICE DOUBLE-STACKS, EVEN ON max_stacks = 1.
--
--    add_externally_controlled_buff skips _can_add_internally_controlled_buff, which is
--    the thing that enforces the stack cap. It lands in _add_buff, which calls
--    Buff.add_stack, and set_stack_count does NOT clamp (buff.lua:479). It merely skips
--    the on_add_stack callback. So a second grant of a single-stack boon silently doubles
--    its stat_buffs.
--
--    The game avoids this at SELECTION time, not application time: it checks
--    does_player_have_buff_saved and destructively removes each pick from the pool. We do
--    the same, and additionally keep _applied as a per-unit guard so a double tick or a
--    double hook can never grant the same name twice to the same body.
--
-- 3. THE DESCRIPTION IS NOT A PLAIN LOCALISATION KEY.
--
--    Localizing it directly gives you literal "{time}" and "{dammage}" in the text. The
--    numbers live in a separate buff_stats table and are substituted by
--    MissionBuffsParser.get_formated_buff_description, which also colours them. We use the
--    game's parser rather than reimplementing the formatting.
--
-- ===========================================================================
-- SERVER ONLY, WHICH IS FINE HERE
-- ===========================================================================
--
-- Every hordes template is `predicted = false`, and a non-predicted external buff bails
-- out on a client (`elseif not is_server then client_tried_adding_rpc_buff = true`).
-- In a Pilgrimage leg we ARE the server, so this works. It also means the mod cannot
-- accidentally do anything in a public game, which is the behaviour we want anyway.

local M = {}

local _mod
local _shared
local _run_state
local _event_log
local _hooks
local _debug_log
-- Declared with the other injected deps, at the TOP, and the position is load-bearing.
-- v0.14.1 declared these two below M.info, and a Lua function only captures locals
-- that exist ABOVE its definition; M.info silently read a nil global instead, the icon
-- override never ran, and the draft cards kept the placeholder while every probe in
-- the debug report said the stand-ins were ready. Position is behaviour.
local _icons
local _missions -- injected, only for its seeded generator
-- v0.22.81: loadout deps (wallet purchases, shop slot expansions)
local _wallet
local _shop

local SENTINEL = "__pilgrimage_boons_installed"

local ALLOWED_BUFFS_PATH = "scripts/managers/mission_buffs/mission_buffs_allowed_buffs"
local PARSER_PATH = "scripts/ui/constant_elements/elements/mission_buffs/utilities/mission_buffs_parser"
local BUFFS_DATA_PATH = "scripts/settings/buff/hordes_buffs/hordes_buffs_data"

M.GAME_MODE_MANAGER_PATH = "scripts/managers/game_mode/game_mode_manager"

-- ---------------------------------------------------------------------------
-- Source tables
--
-- Fetched lazily and cached. All three are pure data, so caching is safe, and none of
-- them exist before the game has loaded its settings.
-- ---------------------------------------------------------------------------

local _allowed = nil
local _pool = nil
-- The valid Mortis Legendary set depends on the live operative, blitz,
-- combat ability and selected talents. A single cache for the whole leg can
-- therefore become stale after changing character or loadout in the hub.
local _pool_loadout_signature = nil
-- v0.24.0: pool partitions, rebuilt alongside _pool by build_pool.
-- _family_of maps a family buff name to its family key; _legendary_set
-- marks names that came from the legendary catalogue rather than a
-- family. The draft filter and the legendary leak both key on these.
local _family_of = nil
-- A boon can belong to more than one useful draft theme. Fatshark's own
-- catalogue repeats several templates across Fire, Electric and Elementalist,
-- but the older single `_family_of` value discarded that information. These
-- tags are the gameplay-facing compatibility layer used by Archetypes.
local _draft_tags_of = nil
local _legendary_set = nil
-- v0.26.5: Legendary is now a role, not merely "anything Fatshark put
-- under legendary_buffs". The loadout accepts only buffs tied to one
-- combat ability, blitz, or talent. Strong generic buffs remain rare
-- in-mission drops, while explicitly reclassified ordinary buffs join
-- a family draft pool.
local _loadout_legendary_set = nil
local _rare_legendary_set = nil
local _reclassified_family_of = nil
local _loadout_legendary_archetype = nil
-- Pilgrimage-side family/legendary entries carry their own presentation
-- metadata; Fatshark's HordesBuffsData only knows about shipped buffs.
local _pilgrim_family_by_template = {}
local _pilgrim_legendary_by_template = {}
-- v0.24.0: forward declaration; filled next to M.ARCHETYPES below.
-- M.draft runs before that section in file order, so without this the
-- reference inside draft would silently resolve to a global nil.
local _archetype_by_id = {}
local _parser = nil

-- Explicit design demotions from Fatshark's root Generic Legendary
-- list. These effects are useful but belong to an Archetype's ordinary
-- majoris/minoris progression, not to a build-defining pre-run slot.
-- Unknown future Generic entries default to rare-draft, which is the
-- conservative choice until their strength and theme are reviewed.
local GENERIC_FAMILY_OVERRIDES = {
	hordes_buff_uninterruptible_more_damage_taken = "unstoppable",
	hordes_buff_combat_ability_cooldown_on_kills = "unstoppable",
	hordes_buff_auto_clip_fill_while_melee = "cowboy",
	hordes_buff_weakspot_ranged_hit_always_stagger = "critical",
	hordes_buff_explode_enemies_on_ranged_kill = "cowboy",
	hordes_buff_aoe_shock_closest_enemy_on_interval = "electric",
	hordes_buff_staggering_pulse = "unstoppable",
	hordes_buff_random_damage_immunity = "unkillable",
	hordes_buff_bleeding_and_burning_on_melee_hit = "elementalist",
	hordes_buff_explosion_on_toughness_broken = "unkillable",
	hordes_buff_reflect_melee_damage = "unkillable",
}

-- Extra theme memberships which cannot be inferred from Fatshark's broad
-- family tables alone. `debuff` means the boon creates, rewards or develops an
-- enemy debuff. Fire/Electric additions mark mixed boons which remain useful
-- when only that one element is available. A boon which requires two elements
-- at once deliberately receives neither single-element compatibility tag.
local EXTRA_DRAFT_TAGS = {
	-- Executioner can use these Critical and Unstoppable cards entirely with
	-- its melee weapon. Pure ranged cards and cross-slot setup/payoff cards are
	-- deliberately absent because the Archetype locks slot_secondary.
	hordes_buff_explode_enemies_on_critical_kill = { "executioner" },
	hordes_buff_weakspot_damage_increase = { "executioner" },
	hordes_buff_melee_damage_on_melee_critical_hit = { "executioner" },
	hordes_buff_critical_chance_on_dodge = { "executioner" },
	hordes_buff_critical_melee_hit_infinite_cleave = { "executioner" },
	hordes_buff_increase_super_armor_impact_on_crit = { "executioner" },
	hordes_buff_stacking_crit_damage_on_critical_hit = { "executioner" },
	hordes_buff_melee_critical_damage_increase = { "executioner" },
	hordes_buff_damage_reduction_on_critical_hit = { "executioner" },
	hordes_buff_critical_damage_from_consecutive_critical_hits = { "executioner" },
	hordes_buff_crit_chance_per_missing_stamina_bar = { "executioner" },
	hordes_buff_sprinting_staggers = { "executioner" },
	hordes_buff_dodge_staggers = { "executioner" },
	hordes_buff_replenish_stamina_from_ranged_or_melee_hit = { "executioner" },
	hordes_buff_movement_bonuses_on_toughness_broken = { "executioner" },
	hordes_buff_suppression_immunity = { "executioner" },
	hordes_buff_toughness_on_melee_kills = { "executioner" },
	hordes_buff_windup_is_uninterruptible = { "executioner" },
	hordes_buff_no_movement_speed_reduction_on_aim_and_windup = { "executioner" },
	hordes_buff_increase_impact_on_push_attacks = { "executioner" },
	hordes_buff_dodge_incapacitating_attacks = { "executioner" },
	hordes_buff_damage_per_full_stamina_bar = { "executioner" },
	hordes_buff_uninterruptible_more_damage_taken = { "executioner" },
	hordes_buff_combat_ability_cooldown_on_kills = { "executioner" },
	hordes_buff_staggering_pulse = { "executioner" },

	-- Fire and soulfire development.
	hordes_buff_burning_on_melee_hit = { "debuff" },
	hordes_buff_burning_on_ranged_hit = { "debuff" },
	hordes_buff_burning_on_melee_hit_taken = { "debuff" },
	hordes_buff_damage_vs_burning = { "debuff" },
	hordes_buff_fire_pulse = { "debuff" },
	hordes_buff_toughness_on_fire_damage_dealt = { "debuff" },
	hordes_buff_burning_damage_per_burning_enemy = { "debuff" },
	hordes_buff_coherency_damage_vs_burning = { "debuff" },
	hordes_buff_coherency_burning_duration = { "debuff" },

	-- Shock development. Improved Dodge is intentionally absent: being stored
	-- in Electric/Elementalist does not make a generic movement boon a debuff.
	hordes_buff_shock_on_ranged_hit = { "debuff" },
	hordes_buff_shock_on_melee_hit = { "debuff" },
	hordes_buff_damage_vs_electrocuted = { "debuff" },
	hordes_buff_shock_pulse_on_toughness_broken = { "debuff" },
	hordes_buff_instakill_melee_hit_on_electrocuted_enemy = { "debuff" },
	hordes_buff_shock_on_hit_after_dodge = { "debuff" },
	hordes_buff_shock_closest_enemy_on_interval = { "debuff" },
	hordes_buff_damage_taken_close_to_electrocuted_enemy = { "debuff" },
	hordes_buff_coherency_damage_taken_close_to_electrocuted_enemy = { "debuff" },
	hordes_buff_aoe_shock_closest_enemy_on_interval = { "debuff" },

	-- Genuine mixed cards. The first works from either element independently;
	-- the second creates fire and bleed itself, so Pyromancer can use it without
	-- first finding a separate bleed source.
	hordes_buff_extra_toughness_near_burning_shocked_enemies = {
		"fire", "electric", "debuff",
	},
	hordes_buff_bleeding_and_burning_on_melee_hit = { "fire", "debuff" },
	hordes_buff_shock_on_blocking_melee_attack = { "electric", "debuff" },
}

-- Declared HERE, above every function that touches it, and not next to the applying code
-- where it is mostly used. Lua resolves a local by its lexical position, so a local
-- declared below build_pool is a nil GLOBAL as far as build_pool is concerned, and
-- `_stats.pool_from = x` would throw. This mod has already been bitten by exactly that
-- once, in event_log.lua.
local _stats = {
	applied = 0,
	failed = 0,
	spawns = 0,
	pool_from = "not built",
	last_error = nil,
}

local function _allowed_buffs()
	if _allowed then return _allowed end
	local ok, value = pcall(require, ALLOWED_BUFFS_PATH)
	if ok and type(value) == "table" then _allowed = value end
	return _allowed
end

-- The PRESENTATION table: title, description, icon, gradient, buff_stats. Not the
-- BuffTemplate; the BuffTemplate's own `icon` is a useless default that
-- buff_templates.lua:120 assigns to everything.
--
-- I ASSUMED THIS WAS A GLOBAL AND IT IS NOT. hordes_buffs_data.lua ends with
-- `return settings("HordesBuffsData", hordes_buffs_data)`, and settings() simply returns
-- its argument (scripts/foundation/utilities/settings.lua:7). Nothing publishes a global.
-- So rawget(_G, "HordesBuffsData") was nil, info() fell through to its "just show the raw
-- name" fallback, and every card showed hordes_buff_something with no description.
--
-- Requiring it is also what makes it EXIST: nothing in a normal mission pulls this file
-- in, since its only consumers are the Hordes UI elements.
local _data = nil

local function _buffs_data()
	if _data ~= nil then return _data or nil end

	local ok, value = pcall(require, BUFFS_DATA_PATH)
	if ok and type(value) == "table" then
		_data = value
	else
		_data = rawget(_G, "HordesBuffsData") or false
	end

	return _data or nil
end

local function _mission_buffs_parser()
	if _parser ~= nil then return _parser end
	local ok, value = pcall(require, PARSER_PATH)
	_parser = (ok and value) or false
	return _parser
end

M.allowed_buffs = _allowed_buffs
M.buffs_data = _buffs_data

-- ---------------------------------------------------------------------------
-- Building the pool
--
-- The catalogue is not a list. mission_buffs_allowed_buffs.lua is three nested trees:
--
--   legendary_buffs.generic              flat array, 14 names, everyone gets these
--   legendary_buffs.<archetype>          a map keyed by LOADOUT SLOT, not a list:
--                                          .generic
--                                          .grenade_ability.<grenade_name> = { names }
--                                          .combat_ability.<ability_name>  = { names }
--                                          .talent_specific.<talent>       (cryptic only)
--   buff_families.<family>.buffs         and .priority_buffs, flat arrays
--
-- and there are SEVEN archetypes, not four: veteran, zealot, psyker, ogryn, adamant,
-- broker, cryptic. Any per-class logic has to be driven off this table rather than a
-- hardcoded assumption, which is why the walk below is generic and recursive rather than
-- a list of known keys.
--
-- For a first pass we take everything. Filtering to the player's own archetype and
-- equipped abilities is a refinement, and doing it wrong would silently shrink the pool,
-- so it is better added once there is something to compare against.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- WHO IS ALLOWED WHAT
--
-- The first version took the entire catalogue, on the reasoning that filtering it wrongly
-- would silently shrink the pool. That was the wrong trade: it offered Kaizen a cryptic
-- buff for an ability his character does not have, which is worse than a smaller pool
-- because it is a boon that would do nothing if taken.
--
-- This now mirrors mission_buffs_selector.lua:145-195 exactly, because the game has
-- already answered the question and any answer of mine would be a guess at its intent:
--
--     legendary_buffs.generic                                everyone
--     legendary_buffs[archetype].generic                     your class
--     legendary_buffs[archetype].grenade_ability[<name>]     your equipped grenade
--     legendary_buffs[archetype].combat_ability[<group>]     your equipped combat ability
--     legendary_buffs[archetype].talent_specific[<talent>]   only if you have that talent
--     buff_families[*].buffs and .priority_buffs             everyone, these are generic
--
-- Note the asymmetry the game itself has and which is easy to get wrong: the grenade is
-- keyed by `equipped_abilities.grenade_ability.NAME` while the combat ability is keyed by
-- `equipped_abilities.combat_ability.ABILITY_GROUP`. Not the same field.
--
-- WITHOUT A PLAYER UNIT we fall back to generic plus families only. That is the honest
-- answer: it is better to offer a smaller correct pool than to offer buffs for a class
-- that is not yours. /pil_boons reports which of the two happened.
-- ---------------------------------------------------------------------------

local function _append(out, seen, list)
	if type(list) ~= "table" then return end
	for i = 1, #list do
		local name = list[i]
		if type(name) == "string" and name:sub(1, 12) == "hordes_buff_" and not seen[name] then
			seen[name] = true
			out[#out + 1] = name
		end
	end
end

local function _add_draft_tag(buff_name, tag)
	if type(buff_name) ~= "string" or type(tag) ~= "string" or tag == "" then return end
	_draft_tags_of[buff_name] = _draft_tags_of[buff_name] or {}
	_draft_tags_of[buff_name][tag] = true
end

local function _add_extra_draft_tags(buff_name, tags)
	if type(tags) ~= "table" then return end
	for i = 1, #tags do _add_draft_tag(buff_name, tags[i]) end
end

local function _has_wanted_draft_tag(buff_name, wanted)
	local tags = _draft_tags_of and _draft_tags_of[buff_name]
	if type(tags) ~= "table" then return false end
	for tag in pairs(tags) do
		if wanted[tag] then return true end
	end
	return false
end

-- `pairs()` order is intentionally undefined. Use Fatshark's published family
-- order first, then append any future families alphabetically. This makes the
-- single presentation family stable while `_draft_tags_of` retains every
-- membership for gameplay filtering.
local function _ordered_family_keys(allowed, families)
	local out, seen = {}, {}
	for i = 1, #(allowed.available_family_builds or {}) do
		local key = allowed.available_family_builds[i]
		if families[key] and not seen[key] then
			seen[key] = true
			out[#out + 1] = key
		end
	end
	local extras = {}
	for key in pairs(families) do
		if not seen[key] then extras[#extras + 1] = key end
	end
	table.sort(extras)
	for i = 1, #extras do out[#out + 1] = extras[i] end
	return out
end

local function _walk_buff_names(value, fn)
	if type(value) == "string" then
		if value:sub(1, 12) == "hordes_buff_" then fn(value) end
	elseif type(value) == "table" then
		for _, child in pairs(value) do _walk_buff_names(child, fn) end
	end
end

-- This shipped boon is an ordinary Cowboy effect, despite living in
-- Fatshark's Legendary catalogue. Its internal id and localization key
-- can change between game builds, so the check uses both raw metadata
-- and the localized English presentation available on the current
-- install. The raw-key checks keep it working for non-English clients
-- when Fatshark's semantic key names are present.
local function _family_override(name)
	local explicit = GENERIC_FAMILY_OVERRIDES[name]
	if explicit then return explicit end
	local data = _buffs_data()
	local entry = data and data[name]
	local raw = string.lower(table.concat({
		tostring(name or ""),
		tostring(entry and entry.title or ""),
		tostring(entry and entry.description or ""),
	}, " "))
	if string.find(raw, "coulda", 1, true) and string.find(raw, "empty", 1, true) then
		return "cowboy"
	end
	if string.find(raw, "auto_reload", 1, true)
		and (string.find(raw, "melee", 1, true) or string.find(raw, "holster", 1, true)) then
		return "cowboy"
	end
	local ok, info = pcall(M.info, name)
	if ok and info then
		local title = string.lower(tostring(info.title or ""))
		local desc = string.lower(tostring(info.description or ""))
		local matched = string.find(title, "coulda swore", 1, true) ~= nil
			or (string.find(desc, "ranged weapon", 1, true) ~= nil
				and string.find(desc, "magazine", 1, true) ~= nil
				and string.find(desc, "7%", 1, true) ~= nil)
		return matched and "cowboy" or nil
	end
	return nil
end

-- Rebuilds a patch-resilient catalogue from Fatshark's nested data:
--
-- * root/class generic entries are rare mission Legendaries;
-- * combat-ability and talent-specific entries are loadout Legendaries;
-- * blitz entries are loadout Legendaries unless the same buff is
--   reused across several classes, which makes it a generic grenade
--   modifier and therefore a rare mission Legendary;
-- * named low-impact exceptions can become normal family boons.
--
-- Counting reuse is more durable than hardcoding DLC-era buff ids. It
-- automatically catches effects such as duplicate grenade chance,
-- blanket brittleness, and grenade regeneration across new classes.
local function _rebuild_legendary_roles(legendary)
	_loadout_legendary_set = {}
	_rare_legendary_set = {}
	_reclassified_family_of = {}
	_loadout_legendary_archetype = {}
	if type(legendary) ~= "table" then return end

	local grenade_uses = {}
	for class_key, class_buffs in pairs(legendary) do
		if class_key ~= "generic" and type(class_buffs) == "table"
			and type(class_buffs.grenade_ability) == "table" then
			local in_this_class = {}
			for _, buffs in pairs(class_buffs.grenade_ability) do
				_walk_buff_names(buffs, function(name) in_this_class[name] = true end)
			end
			for name in pairs(in_this_class) do
				grenade_uses[name] = (grenade_uses[name] or 0) + 1
			end
		end
	end

	local function mark_rare(name)
		local family = _family_override(name)
		if family then
			_reclassified_family_of[name] = family
			_rare_legendary_set[name] = nil
			_loadout_legendary_set[name] = nil
		else
			_rare_legendary_set[name] = true
		end
	end

	_walk_buff_names(legendary.generic, mark_rare)
	for class_key, class_buffs in pairs(legendary) do
		if class_key ~= "generic" and type(class_buffs) == "table" then
			_walk_buff_names(class_buffs.generic, mark_rare)
			_walk_buff_names(class_buffs.combat_ability, function(name)
				if not _reclassified_family_of[name] and not _rare_legendary_set[name] then
					_loadout_legendary_set[name] = true
					_loadout_legendary_archetype[name] = class_key
				end
			end)
			_walk_buff_names(class_buffs.talent_specific, function(name)
				if not _reclassified_family_of[name] and not _rare_legendary_set[name] then
					_loadout_legendary_set[name] = true
					_loadout_legendary_archetype[name] = class_key
				end
			end)
			_walk_buff_names(class_buffs.grenade_ability, function(name)
				if _reclassified_family_of[name] then return end
				-- Reuse across several classes means the effect is a generic
				-- grenade jackpot. Reuse by variants inside one class still
				-- targets that class's named blitz and remains loadout-worthy.
				if (grenade_uses[name] or 0) > 1 then
					_rare_legendary_set[name] = true
					_loadout_legendary_set[name] = nil
					_loadout_legendary_archetype[name] = nil
				elseif not _rare_legendary_set[name] then
					_loadout_legendary_set[name] = true
					_loadout_legendary_archetype[name] = class_key
				end
			end)
		end
	end

	for i = 1, #(M.LEGENDARIES or {}) do
		local boon = M.LEGENDARIES[i]
		local name = boon and boon.buff_template
		if name then
			_loadout_legendary_set[name] = true
			_loadout_legendary_archetype[name] = boon.archetype
		end
	end
end

local function _ensure_legendary_roles()
	if _loadout_legendary_set then return end
	local allowed = _allowed_buffs()
	_rebuild_legendary_roles(allowed and allowed.legendary_buffs)
end

local function _requirement_matches(actual, wanted)
	if wanted == nil then return true end
	if type(wanted) == "string" then return actual == wanted end
	if type(wanted) == "table" then
		for i = 1, #wanted do
			if actual == wanted[i] then return true end
		end
	end
	return false
end

-- Returns archetype_name, grenade_name, combat_ability_group, talents,
-- combat_ability_name, or nils. The concrete combat name distinguishes
-- variants which share one group, notably Psyker's flat and dome shields.
local function _player_loadout()
	local player = _shared.local_player()
	local player_unit = _shared.local_player_unit()
	if not player or not player_unit then return nil end

	local archetype
	if type(player.archetype_name) == "function" then
		local ok, name = pcall(player.archetype_name, player)
		if ok then archetype = name end
	end
	if not archetype then return nil end

	local ability_extension = _shared.extension(player_unit, "ability_system")
	if not ability_extension then return archetype end

	local ok_abilities, equipped = pcall(ability_extension.equipped_abilities, ability_extension)
	if not ok_abilities or type(equipped) ~= "table" then return archetype end

	local grenade, combat, combat_name

	local ok_has, has_grenade = pcall(ability_extension.has_ability_type, ability_extension, "grenade_ability")
	if ok_has and has_grenade and equipped.grenade_ability then
		grenade = equipped.grenade_ability.name
	end

	local ok_has_combat, has_combat = pcall(ability_extension.has_ability_type, ability_extension, "combat_ability")
	if ok_has_combat and has_combat and equipped.combat_ability then
		-- ability_group, NOT name. The catalogue keys combat abilities differently to
		-- grenades and mixing them up yields an empty table lookup and a silently
		-- smaller pool.
		combat = equipped.combat_ability.ability_group
		combat_name = equipped.combat_ability.name
	end

	local talents
	if type(player.profile) == "function" then
		local ok_profile, profile = pcall(player.profile, player)
		if ok_profile and type(profile) == "table" then talents = profile.talents end
	end

	return archetype, grenade, combat, talents, combat_name
end

-- Stable fingerprint for every part of the loadout used by Fatshark's Mortis
-- Legendary catalogue. pool() compares this on every access, so changing from
-- one character or ability setup to another cannot leave the terminal showing
-- the previous setup's valid entries.
local function _player_loadout_signature()
	local archetype, grenade, combat, talents, combat_name = _player_loadout()
	local selected_talents = {}
	if type(talents) == "table" then
		for name, value in pairs(talents) do
			if value ~= nil and value ~= false and value ~= 0 then
				selected_talents[#selected_talents + 1] = tostring(name)
			end
		end
		table.sort(selected_talents)
	end
	return table.concat({
		tostring(archetype or ""),
		tostring(grenade or ""),
		tostring(combat or ""),
		tostring(combat_name or ""),
		table.concat(selected_talents, ","),
	}, "|")
end

local OPERATIVE_LABELS = {
	veteran = "Veteran",
	zealot = "Zealot",
	psyker = "Psyker",
	ogryn = "Ogryn",
	adamant = "Arbites",
	broker = "Hive Scum",
	cryptic = "Skitarii",
}

-- Explains why an unlocked Pilgrimage Legendary is greyed out in the
-- between-run loadout. The pool already makes the correct yes/no decision;
-- this translates that decision into the exact player-facing requirement so
-- a Skitarii running Voltaic Emitter and Arc Grenades is not mistaken for an
-- undetected operative.
function M.legendary_inert_reason(buff_name)
	local boon = _pilgrim_legendary_by_template[buff_name]
	if not boon then return nil end

	local archetype, grenade, combat, _, combat_name = _player_loadout()
	if not archetype then return "Current operative loadout is not ready." end

	if boon.archetype and archetype ~= boon.archetype then
		return "Requires a " .. (OPERATIVE_LABELS[boon.archetype] or boon.archetype)
			.. " operative."
	end

	if boon.requires_blitz and not _requirement_matches(grenade, boon.requires_blitz) then
		return "Requires " .. (boon.requires_blitz_label or "a different blitz") .. "."
	end

	if boon.requires_combat_ability
		and not _requirement_matches(combat, boon.requires_combat_ability) then
		return "Requires " .. (boon.requires_combat_ability_label
			or "a different combat ability") .. "."
	end
	if boon.requires_combat_ability_name
		and not _requirement_matches(combat_name,
			boon.requires_combat_ability_name) then
		return "Requires the flat Telekine Shield, not the dome."
	end

	return nil
end

function M.build_pool()
	local allowed = _allowed_buffs()
	if not allowed then
		_stats.pool_from = "no catalogue"
		_family_of, _draft_tags_of, _legendary_set = {}, {}, {}
		return {}
	end

	local out, seen = {}, {}
	-- v0.24.0: partitions rebuilt with the pool. Everything appended
	-- BEFORE the legendary section belongs to a family; everything
	-- after is a legendary.
	_family_of, _draft_tags_of, _legendary_set = {}, {}, {}
	_rebuild_legendary_roles(allowed.legendary_buffs)

	-- Families are build archetypes of their own (fire, unkillable and so on) and are not
	-- class restricted, so everyone can be offered all of them.
	local families = allowed.buff_families
	if type(families) == "table" then
		local family_keys = _ordered_family_keys(allowed, families)
		for fi = 1, #family_keys do
			local family_key = family_keys[fi]
			local family = families[family_key]
			if type(family) == "table" then
				local function add_family_list(list)
					for i = 1, #(list or {}) do
						local name = list[i]
						if type(name) == "string" and name:sub(1, 12) == "hordes_buff_" then
							_add_draft_tag(name, family_key)
							_add_extra_draft_tags(name, EXTRA_DRAFT_TAGS[name])
							if not seen[name] then
								seen[name] = true
								out[#out + 1] = name
								_family_of[name] = family_key
							end
						end
					end
				end
				add_family_list(family.priority_buffs)
				add_family_list(family.buffs)
			end
		end
	end

	-- v0.26.0: our family expansions are real drafted boons, not
	-- permanent Doctrines. They use Pilgrimage templates but join the
	-- same family partition and archetype filter as Fatshark's entries.
	for i = 1, #(M.FAMILY_BOONS or {}) do
		local boon = M.FAMILY_BOONS[i]
		local name = boon and boon.buff_template
		if type(name) == "string" and name ~= "" and not seen[name] then
			seen[name] = true
			out[#out + 1] = name
			_family_of[name] = boon.family
		end
		if type(name) == "string" and name ~= "" then
			_add_draft_tag(name, boon.family)
			_add_extra_draft_tags(name, boon.draft_tags)
			_add_extra_draft_tags(name, EXTRA_DRAFT_TAGS[name])
		end
	end

	-- v0.26.5: shipped entries explicitly demoted from Legendary status
	-- become genuine family boons before the Legendary boundary is set.
	-- This means Archetype filtering and family icon styling treat them
	-- exactly like the rest of that family.
	for name, family in pairs(_reclassified_family_of or {}) do
		if not seen[name] then
			seen[name] = true
			out[#out + 1] = name
			_family_of[name] = family
		end
		_add_draft_tag(name, family)
		_add_extra_draft_tags(name, EXTRA_DRAFT_TAGS[name])
	end

	local legendary = allowed.legendary_buffs
	if type(legendary) == "table" then
		-- v0.24.0: everything from here down is a legendary; record the
		-- boundary so the loop after this block can mark them.
		local legendary_start = #out + 1
		_append(out, seen, legendary.generic)

		local archetype, grenade, combat, talents = _player_loadout()

		if archetype and legendary[archetype] then
			local class_buffs = legendary[archetype]
			_stats.pool_from = "archetype " .. tostring(archetype)

			_append(out, seen, class_buffs.generic)

			if grenade and type(class_buffs.grenade_ability) == "table" then
				_append(out, seen, class_buffs.grenade_ability[grenade])
			end

			if combat and type(class_buffs.combat_ability) == "table" then
				_append(out, seen, class_buffs.combat_ability[combat])
			end

			if type(class_buffs.talent_specific) == "table" and type(talents) == "table" then
				for talent_name, talent_buffs in pairs(class_buffs.talent_specific) do
					if talents[talent_name] then _append(out, seen, talent_buffs) end
				end
			end
		else
			-- No player yet, or an archetype the catalogue does not list. Generic and
			-- families only, which is correct but smaller.
			_stats.pool_from = archetype and ("unknown archetype " .. tostring(archetype))
				or "generic only, no player"
		end

		for i = legendary_start, #out do
			_legendary_set[out[i]] = true
		end
	end

	-- Pilgrimage legendaries are filtered with the same relevance rule:
	-- class first, then the equipped blitz when the entry claims one.
	-- No player/loadout means no class-specific custom legendary.
	local player_archetype, player_grenade, player_combat, _, player_combat_name =
		_player_loadout()
	for i = 1, #(M.LEGENDARIES or {}) do
		local boon = M.LEGENDARIES[i]
		local relevant = player_archetype ~= nil
			and (not boon.archetype or boon.archetype == player_archetype)
		if relevant and boon.requires_blitz then
			relevant = _requirement_matches(player_grenade, boon.requires_blitz)
			if not relevant and type(boon.requires_blitz) == "string"
				and M.blitz_template_name and _shared then
				local unit = _shared.local_player_unit and _shared.local_player_unit()
				relevant = M.blitz_template_name(unit) == boon.requires_blitz
			end
		end
		if relevant and boon.requires_combat_ability then
			relevant = _requirement_matches(player_combat, boon.requires_combat_ability)
		end
		if relevant and boon.requires_combat_ability_name then
			relevant = _requirement_matches(player_combat_name,
				boon.requires_combat_ability_name)
		end
		local name = boon and boon.buff_template
		if relevant and type(name) == "string" and name ~= "" and not seen[name] then
			seen[name] = true
			out[#out + 1] = name
			_legendary_set[name] = true
		end
	end

	-- Sorted so the pool order is identical on every machine and every launch. A seeded
	-- draft is only reproducible if the thing it indexes into is stable, and pairs()
	-- iteration order in Lua is not.
	table.sort(out)
	return out
end

-- v0.24.0: partition accessors. Both are only meaningful after pool()
-- has been called for the current leg; pool() rebuilds them.
function M.family_of(buff_name)
	return _family_of and _family_of[buff_name] or nil
end

-- Public debug/audit accessor. The returned list is sorted so console probes
-- and test snapshots remain stable across machines.
function M.draft_tags_of(buff_name)
	local out = {}
	for tag in pairs((_draft_tags_of and _draft_tags_of[buff_name]) or {}) do
		out[#out + 1] = tag
	end
	table.sort(out)
	return out
end

function M.is_draft_compatible(buff_name, archetype_id)
	-- Ensure the native and Pilgrimage tag indices exist before answering a UI,
	-- console or test query made outside the normal draft path.
	M.pool()
	local archetype = _archetype_by_id[archetype_id]
	if not archetype then return false end
	local wanted = {}
	local draft_tags = archetype.draft_tags or archetype.families or {}
	for i = 1, #draft_tags do wanted[draft_tags[i]] = true end
	return _has_wanted_draft_tag(buff_name, wanted)
end

function M.is_legendary(buff_name)
	return _legendary_set ~= nil and _legendary_set[buff_name] == true
end

function M.is_loadout_legendary(buff_name)
	_ensure_legendary_roles()
	return _loadout_legendary_set[buff_name] == true
end

function M.is_rare_legendary(buff_name)
	_ensure_legendary_roles()
	return _rare_legendary_set[buff_name] == true
end

-- The operative class whose combat ability or blitz owns this
-- loadout Legendary. The UI uses this as presentation metadata only;
-- applicability is still enforced independently by the live pool.
function M.legendary_archetype(buff_name)
	_ensure_legendary_roles()
	return _loadout_legendary_archetype[buff_name]
end

-- Cached per leg, not forever. The pool depends on the player's equipped abilities, and
-- those are not known until the player unit exists, so a pool built during the loading
-- screen would be the generic-only fallback and would then be wrong for the rest of the
-- run. reset_leg drops it.
function M.pool()
	local signature = _player_loadout_signature()
	if _pool and _pool_loadout_signature == signature then return _pool end
	_pool = M.build_pool()
	_pool_loadout_signature = signature
	return _pool
end

function M.pool_size()
	return #M.pool()
end

-- Drops the cache so a /reload picks up any change. Also used by tests.
function M.reset_pool()
	_pool = nil
	_pool_loadout_signature = nil
	_allowed = nil
end

-- ---------------------------------------------------------------------------
-- Presentation
-- ---------------------------------------------------------------------------

-- Fatshark's Hordes data still exposes several development names. Keep the
-- correction at Pilgrimage's presentation boundary so the underlying template
-- ids remain untouched and save/network compatibility is not disturbed.
local function _player_facing_ability_names(text)
	if type(text) ~= "string" then return text end
	return text
		:gsub("Focus Stance", "Desperado")
		:gsub("Punk Rage", "Rampage")
		:gsub("Volley Fire", "Executioner's Stance")
		:gsub("Precision Stance", "Advanced Combat Doctrines")
end

-- Returns a table the view can render: name, title, description, icon.
-- Never returns nil and never returns an empty title, because a boon you cannot read is
-- worse than one you cannot have.
function M.info(buff_name)
	local info = {
		name = buff_name,
		title = tostring(buff_name),
		description = "",
		icon = nil,
		custom_icon = nil,
		-- The colour ramp the icon is tinted through. The game supplies one per buff and
		-- falls back to the talent ability ramp when it is missing
		-- (hud_element_tactical_overlay.lua:28, 380). Without it the icon draws flat
		-- grey, so it is worth carrying even though it is only cosmetic.
		gradient = nil,
		is_family = false,
	}

	local pilgrim = _pilgrim_family_by_template[buff_name]
		or _pilgrim_legendary_by_template[buff_name]
	if pilgrim then
		info.title = pilgrim.name or info.title
		info.description = _player_facing_ability_names(pilgrim.description or "")
		info.icon = pilgrim.icon or (pilgrim.custom and pilgrim.custom.hud_icon) or nil
		info.gradient = pilgrim.gradient
		local family_boon = _pilgrim_family_by_template[buff_name]
		info.is_family = family_boon ~= nil
		-- v0.28.5: custom family boons use the small set of Hordes-card
		-- textures already proven to render in ordinary missions. Wave B
		-- originally named several plausible Mortis assets directly; the
		-- engine accepted the strings but drew its question-mark placeholder
		-- because those resources were not resident. Long Burn's family art
		-- is the known-good style and now wins for every family entry.
		if family_boon and _icons and _icons.family_styled_icon then
			info.icon = _icons.family_styled_icon(family_boon.family) or info.icon
			if _icons.custom_icon_for then
				info.custom_icon = _icons.custom_icon_for(buff_name,
					family_boon.family)
			end
		elseif _icons and info.icon then
			local resident = _icons.texture_resident and _icons.texture_resident(info.icon)
			if resident == false and _icons.icon_override then
				info.icon = _icons.icon_override(buff_name) or info.icon
			end
		end
		return info
	end

	local data = _buffs_data()
	local entry = data and data[buff_name]
	if not entry then return info end

	-- Both are stored as "" rather than nil for a couple of shipped entries, and an
	-- empty string binds as "clear the texture" rather than "use the default", so it has
	-- to become nil here.
	if entry.icon and entry.icon ~= "" then info.icon = entry.icon end
	if entry.gradient and entry.gradient ~= "" then info.gradient = entry.gradient end

	-- The shipped art is unreachable on this install (it lives in the Mortis Trials
	-- level bundle, which no package name reaches), so when the engine cannot resolve
	-- the real texture, swap in a category stand-in. icon_override prefers a RESIDENT
	-- GAME TEXTURE PATH (status and stimm icons from the base HUD, probe-verified,
	-- these provably draw) and only falls back to the SimpleAssets texture object,
	-- which in practice the buff materials refused to render. Strictly a fallback
	-- either way: if a future patch makes the real art resident, it wins.
	if _icons then
		local family = _family_of and _family_of[buff_name]
		if family and _icons.family_styled_icon then
			-- Shipped family icons are tied to the Mortis bundle and often draw
			-- as an empty white hex here. Replace them with the proven Wave A
			-- Hordes artwork for that family, not with an old generic HUD icon.
			info.icon = _icons.family_styled_icon(family) or info.icon
			if _icons.custom_icon_for then
				info.custom_icon = _icons.custom_icon_for(buff_name, family)
			end
		else
			local resident = _icons.texture_resident and _icons.texture_resident(info.icon)
			if resident == false and _icons.icon_override then
				local override = _icons.icon_override(buff_name)
				if override then info.icon = override end
			end
		end
	end

	info.is_family = (_family_of and _family_of[buff_name] ~= nil)
		or entry.is_family_buff == true

	-- Two shipped entries carry title = "" deliberately and are meant to fall back to the
	-- raw name. The game's own UI does the same check
	-- (constant_element_mission_buffs.lua:144).
	local Localize = rawget(_G, "Localize")
	if entry.title and entry.title ~= "" and type(Localize) == "function" then
		local ok, text = pcall(Localize, entry.title)
		if ok and type(text) == "string" and text ~= "" and text:sub(1, 1) ~= "<" then
			info.title = text
		end
	end

	-- The description carries format parameters that live in entry.buff_stats. Localizing
	-- it directly leaves "{time}" and friends in the text, so it goes through the game's
	-- own parser.
	local parser = _mission_buffs_parser()
	if parser and parser.get_formated_buff_description then
		local Color = rawget(_G, "Color")
		local colour = Color and Color.ui_terminal and Color.ui_terminal(255, true) or nil
		local ok, text = pcall(parser.get_formated_buff_description, entry, colour)
			if ok and type(text) == "string" then
				info.description = _player_facing_ability_names(text)
			end
	end

	return info
end

-- ---------------------------------------------------------------------------
-- Drafting
--
-- Seeded off the run seed and the leg number, so the same run always offers the same
-- choices. That keeps a shared seed genuinely reproducible, which is the whole point of
-- showing the seed on screen, and it means a crash mid-draft cannot be used to reroll
-- into a better offer.
-- ---------------------------------------------------------------------------

-- Returns a list of `count` distinct boon names the player does not already own.
-- v0.24.0: chance (in percent) that a draft smuggles one legendary in.
-- v0.28.7 makes the value run-scoped: 15% initially, then +15 percentage
-- points for each mission draft that did not contain a Legendary. The
-- run-state module persists and caps the pity curve; this local value remains
-- the compatibility default for tests and external callers using three args.
local LEGENDARY_LEAK_PCT = 15

function M.draft(count, seed, owned, legendary_leak_pct)
	count = math.max(1, math.min(count or 3, 6))
	owned = owned or {}
	legendary_leak_pct = math.max(0, math.min(100,
		math.floor(legendary_leak_pct or LEGENDARY_LEAK_PCT)))

	local pool = M.pool()
	if #pool == 0 then return {} end

	-- v0.24.0 (Boons v2): the draft is family-first. Legendaries are
	-- pulled OUT of the base candidates and only re-enter through the
	-- seeded leak below, so the Archetype hard filter has a clean
	-- family list to work on and legendaries keep their own moment.
	local family_candidates = {}
	local legendary_candidates = {}
	local active_legendary = M.active_legendary()
	local active_temporary_legendary = M.active_temporary_legendary
		and M.active_temporary_legendary() or nil
	for i = 1, #pool do
		local name = pool[i]
		if not owned[name] then
			if M.is_legendary(name) then
				-- The run stamp is not part of `owned`, so explicitly remove
				-- the preselected Legendary from the rare offer pool.
				if name ~= active_legendary and name ~= active_temporary_legendary then
					legendary_candidates[#legendary_candidates + 1] = name
				end
			else
				family_candidates[#family_candidates + 1] = name
			end
		end
	end

	-- ARCHETYPE HARD FILTER. v0.28.12 filters by explicit compatibility
	-- tags rather than one broad family label. This permits mixed cards that
	-- function from the Archetype's own element, while rejecting a pure shock
	-- card for Pyromancer and a two-element requirement such as Thermal Shock.
	-- The old off-theme backfill is intentionally gone: a shorter late-run draft
	-- is preferable to presenting a boon the selected Archetype cannot support.
	local archetype_id = M.active_archetype_id()
	local archetype = archetype_id and _archetype_by_id[archetype_id] or nil
	local candidates = family_candidates
	if archetype then
		local wanted = {}
		local draft_tags = archetype.draft_tags or archetype.families or {}
		for i = 1, #draft_tags do wanted[draft_tags[i]] = true end
		local on_theme = {}
		for i = 1, #family_candidates do
			local name = family_candidates[i]
			if _has_wanted_draft_tag(name, wanted) then
				on_theme[#on_theme + 1] = name
			end
		end
		candidates = on_theme
		if #on_theme < count then
			_debug_log("boons", 0, "archetype draft near exhaustion: "
				.. tostring(#on_theme) .. " compatible candidates left for "
				.. tostring(archetype_id), 0, "info")
		end
	end

	if #candidates == 0 and #legendary_candidates == 0 then return {} end

	local state = _missions.mix_seed(seed or 0)
	local out = {}

	for _ = 1, math.min(count, #candidates) do
		local value
		state, value = _missions.next_random(state, 1, #candidates)
		out[#out + 1] = candidates[value]
		table.remove(candidates, value)
	end

	-- LEGENDARY LEAK: one seeded roll per draft; on a hit the LAST
	-- option is replaced with a seeded-random legendary. Replacing
	-- rather than appending keeps the draft size the player paid for
	-- (Zero Waste and the count cap stay honest).
	-- v0.28.2: a run may gain additional distinct Legendaries. Pool
	-- construction already restricts these to the current class,
	-- equipped combat ability, equipped blitz and relevant talents;
	-- the split above removes the active pick and `owned` removes every
	-- Legendary previously drafted.
	if #legendary_candidates > 0 and #out > 0 then
		local roll
		state, roll = _missions.next_random(state, 1, 100)
		if roll <= legendary_leak_pct then
			local pick
			state, pick = _missions.next_random(state, 1, #legendary_candidates)
			out[#out] = legendary_candidates[pick]
		end
	end

	-- Degenerate escape hatch: nothing but legendaries left (deep run,
	-- tiny families). Offer legendaries straight rather than an empty
	-- draft.
	if #out == 0 and #legendary_candidates > 0 then
		for _ = 1, math.min(count, #legendary_candidates) do
			local value
			state, value = _missions.next_random(state, 1, #legendary_candidates)
			out[#out + 1] = legendary_candidates[value]
			table.remove(legendary_candidates, value)
		end
	end

	return out
end

-- The seed for the draft offered at the start of a given leg. Derived rather than stored,
-- so it survives a level change without needing a settings key of its own.
function M.draft_seed(run_seed, leg)
	return _missions.mix_seed((run_seed or 0) + (leg or 0) * 7919)
end

-- ---------------------------------------------------------------------------
-- Applying
-- ---------------------------------------------------------------------------

-- name -> index returned by the buff extension. Per player unit, and therefore cleared on
-- every spawn: the indexes belong to the body that has just been destroyed.
local _applied = {}
local _applied_components = {}
local KEY_UNBROKEN_READY = "_doctrine_unbroken_ready"

function M.unbroken_ready()
	return _mod and _mod:get(KEY_UNBROKEN_READY) == true
end

function M.set_unbroken_ready(value)
	if not _mod then return end
	_mod:set(KEY_UNBROKEN_READY, value == true, false)
end

function M.on_mission_completed(was_downed)
	if M.custom_boon_active("pilgrim_doctrine_unbroken_record")
		and was_downed ~= true then
		M.set_unbroken_ready(true)
	end
end

function M.on_local_player_downed(player_unit)
	if not M.unbroken_ready() then return end
	M.set_unbroken_ready(false)
	M.remove_granted(player_unit, "pilgrim_doctrine_unbroken_record")
end

function M.remove_granted(player_unit, buff_name)
	local index = _applied[buff_name]
	if not index then return false end
	local extension = _shared.extension(player_unit, "buff_system")
	if not extension
		or type(extension.remove_externally_controlled_buff) ~= "function" then
		return false
	end
	local ok = pcall(extension.remove_externally_controlled_buff,
		extension, index, _applied_components[buff_name])
	if ok then
		_applied[buff_name] = nil
		_applied_components[buff_name] = nil
	end
	return ok
end

-- Mid-mission test grants are deliberately session-only. They are not written
-- into run_state, the Legendary slot or the permanent Doctrine library. The
-- request table lets a test boon follow the local player across a rescue or
-- respawn, while reset_leg clears everything at the next level transition.
local _test_requests = {}
local _test_active_ids = {}

local function _fixed_time()
	local FixedFrame = rawget(_G, "FixedFrame")
	if FixedFrame and FixedFrame.get_latest_fixed_time then
		local ok, t = pcall(FixedFrame.get_latest_fixed_time)
		if ok and t then return t end
	end
	return _shared.fixed_time()
end

-- Grants one boon to a unit. Returns true when the buff actually landed.
function M.grant(player_unit, buff_name)
	if not player_unit or not buff_name then return false, "no unit" end

	-- The dedupe that stops the double-stack described at the top of this file.
	if _applied[buff_name] then return false, "already applied" end

	local buff_extension = _shared.extension(player_unit, "buff_system")
	if not buff_extension then return false, "no buff extension" end
	if type(buff_extension.add_externally_controlled_buff) ~= "function" then
		return false, "extension cannot add external buffs"
	end

	local ok, _flag, index, component_index = pcall(buff_extension.add_externally_controlled_buff,
		buff_extension, buff_name, _fixed_time())

	if not ok then
		_stats.failed = _stats.failed + 1
		_stats.last_error = tostring(_flag)
		return false, tostring(_flag)
	end

	-- index, not the first value. The first value is an error flag, and a muted buff
	-- returns a real index anyway, so index is the only signal worth testing. This is the
	-- same test mission_buffs_handler.lua:121 makes.
	if index == nil then
		_stats.failed = _stats.failed + 1
		_stats.last_error = "buff refused, likely not server"
		return false, "buff refused"
	end

	_applied[buff_name] = index
	_applied_components[buff_name] = component_index
	_stats.applied = _stats.applied + 1
	return true
end

-- Applies every boon the run owns. Called on player spawn, including respawns.
function M.apply_all(player_unit)
	-- Handles belong to the old player unit. Test requests survive the respawn,
	-- but whether they own the new handle must be decided again below.
	for _, request in pairs(_test_requests) do request.owns_handle = false end
	-- Clear IN PLACE. Other code may hold a reference to this exact table, and
	-- reassigning would orphan it.
	for name in pairs(_applied) do _applied[name] = nil end
	for name in pairs(_applied_components) do _applied_components[name] = nil end

	if not player_unit then return 0 end
	if not _run_state.is_active() then return 0 end

	local state = _run_state.get()
	local granted = 0

	-- Sorted, so the order boons are applied is deterministic. It should not matter, but
	-- when two buffs interact it is much easier to debug a fixed order than a random one.
	local names = {}
	for name in pairs(state.boons) do names[#names + 1] = name end
	table.sort(names)

	for i = 1, #names do
		local ok = M.grant(player_unit, names[i])
		if ok then granted = granted + 1 end
	end

	-- v0.22.81: slotted loadout boons ride the same spawn moment,
	-- after the drafted boons. M.apply_loadout is defined further down
	-- the file; calling through M resolves it at runtime.
	if type(M.apply_loadout) == "function" then
		granted = granted + (M.apply_loadout(player_unit) or 0)
	end
	if type(M.reapply_test_boons) == "function" then
		granted = granted + (M.reapply_test_boons(player_unit) or 0)
	end

	if granted > 0 then
		_event_log.emit({
			t = _shared.fixed_time(),
			event = "boons_applied",
			id = _event_log.next_id(),
			count = granted,
			of = #names,
		})
	end

	return granted
end

function M.applied()
	return _applied
end

-- ---------------------------------------------------------------------------
-- Hook
--
-- on_player_unit_spawn is the moment the game itself uses to restore mission buffs
-- (game_mode_survival.lua:879, game_mode_coop_complete_objective.lua:286). It runs after
-- extension init, so buff_system exists, and it fires on respawn as well as first spawn,
-- which is exactly what we need: the previous unit's buff indexes died with it.
--
-- hook_safe, so a fault of ours can never stop a player spawning.
-- ---------------------------------------------------------------------------

function M.install(GameModeManager)
	if not GameModeManager then return end
	if _hooks.claim(GameModeManager, SENTINEL) then return end

	_mod:hook_safe(GameModeManager, "on_player_unit_spawn",
		function(self, player, player_unit, is_respawn)
			M.on_player_unit_spawn(player, player_unit, is_respawn)
		end)
end

function M.on_player_unit_spawn(player, player_unit, is_respawn)
	_stats.spawns = _stats.spawns + 1

	if not _run_state.is_active() then return end

	-- Bots spawn through the same path. Boons are the player's, and granting them to a bot
	-- would be a silent balance change nobody asked for.
	if player and type(player.is_human_controlled) == "function" then
		local ok, human = pcall(player.is_human_controlled, player)
		if not ok or not human then return end
	end

	-- Only ours. In a solo leg there is one human, but this costs nothing and stops the
	-- hook doing anything at all in a session we do not own.
	if not _shared.is_solo_host() then return end

	local granted = M.apply_all(player_unit)

	_debug_log("boons:spawn", _shared.fixed_time(),
		"applied " .. tostring(granted) .. " boons on "
			.. (is_respawn and "respawn" or "spawn"), 0, "info")
end

-- ---------------------------------------------------------------------------
-- Offering the draft at the start of a leg
--
-- WHY HERE AND NOT AT THE TERMINAL
--
-- The terminal was the first home for this, and it works, but Kaizen's read after playing
-- it is better and it is worth writing down why. A boon chosen in the Mourningstar is a
-- menu decision made minutes before it matters, sandwiched between the route list and a
-- loading screen. A boon chosen standing in the drop zone with the mission about to start
-- is the same decision made where it applies, and it is much closer to walking up to a
-- shrine in Chaos Wastes, which is the thing we are actually trying to build.
--
-- It also means one draft per leg naturally, without the run state having to reason about
-- whether you happen to have visited the terminal.
--
-- The terminal still offers it as a fallback, for the case where a leg is somehow started
-- and finished without the offer being taken.
--
-- TIMING: a few seconds after the player unit exists, not immediately. The first moments
-- of a level are still settling, the mission intro may be playing, and a view that opens
-- during that is a view that opens behind something. The drop zone is also the safest
-- place in the level, so the seconds spent reading three cards cost nothing.
-- ---------------------------------------------------------------------------

local DRAFT_OPEN_DELAY_S = 4

local _leg_start_t = nil
local _draft_offered_this_leg = false

function M.reset_leg()
	_leg_start_t = nil
	_draft_offered_this_leg = false

	-- Drop the cached pool. It is built from the player's equipped abilities, and on the
	-- previous leg it may have been built before the player unit existed, in which case it
	-- is the generic-only fallback and wrong for everything after.
	_pool = nil
	_pool_loadout_signature = nil
	for key in pairs(_test_requests) do _test_requests[key] = nil end
	for key in pairs(_test_active_ids) do _test_active_ids[key] = nil end
end

function M.draft_tick(t)
	-- Missions only. In the hub the terminal owns this.
	if _shared.is_in_hub() then return end
	if not _shared.game_mode_name() then return end

	-- The Psykhanium is neither. It has a player unit and it is not a hub, which is
	-- exactly the shape this gate used to test for, so walking in there with a draft
	-- owed produced the offer mid-training-dummy. The debt survives being ignored here;
	-- the terminal or the next real leg collects it.
	if _shared.is_in_psykhanium() then return end

	if _draft_offered_this_leg then return end
	if not _run_state.is_active() then return end
	if not _run_state.draft_pending() then return end

	local player_unit = _shared.local_player_unit()
	if not player_unit then
		-- Not spawned yet. Do not start the clock until there is someone to spawn it for,
		-- or the delay burns down during the loading screen and the view opens instantly.
		_leg_start_t = nil
		return
	end

	if not _leg_start_t then
		_leg_start_t = t
		return
	end

	if t - _leg_start_t < DRAFT_OPEN_DELAY_S then return end

	local ui = Managers.ui
	if not ui or not ui.open_view then return end

	-- Never stack on top of something else, including the escape menu.
	if ui.using_input then
		local ok, claimed = pcall(ui.using_input, ui, true, false, true)
		if ok and claimed then return end
	end

	-- Offered once per leg. If it is closed without a pick the draft stays owed, so the
	-- terminal will offer it back in the Mourningstar rather than nagging mid-fight.
	_draft_offered_this_leg = true

	local ok, err = pcall(ui.open_view, ui, "pilgrimage_route_view", nil, nil, nil, nil,
		{ draft_only = true })
	if not ok then
		_stats.last_error = tostring(err)
		return
	end

	_event_log.emit({
		t = t,
		event = "boon_draft_offered",
		id = _event_log.next_id(),
		leg = _run_state.get().index,
	})
end

-- ---------------------------------------------------------------------------
-- Taking one
--
-- Grants IMMEDIATELY when there is a live player unit, rather than waiting for the next
-- spawn. Choosing a boon at the start of a leg and then not having it for that leg would
-- make the choice feel like paperwork.
-- ---------------------------------------------------------------------------

function M.choose(name)
	if not name then return false end

	-- v0.25.0: a drafted legendary starts its unlock clock. Promotion
	-- happens only when the NEXT leg completes (chain calls
	-- promote_pending_legendaries), on Penitent or higher. is_legendary
	-- needs the pool partitions; build them if this VM has not yet.
	if _legendary_set == nil then pcall(M.pool) end
	if M.is_legendary(name) and M.record_pending_legendary then
		pcall(M.record_pending_legendary, name)
	end

	_run_state.add_boon(name, 1)
	_run_state.clear_draft()

	local player_unit = _shared.local_player_unit()
	if player_unit and _run_state.is_active() then
		M.grant(player_unit, name)
	end

	_event_log.emit({
		t = _shared.fixed_time(),
		event = "boon_chosen",
		id = _event_log.next_id(),
		boon = name,
		leg = _run_state.get().index,
	})

	return true
end

-- ---------------------------------------------------------------------------

function M.status()
	local owned = {}
	if _run_state then
		for name, stacks in pairs(_run_state.get().boons) do
			owned[#owned + 1] = name .. " x" .. tostring(stacks)
		end
		table.sort(owned)
	end

	local applied_count = 0
	for _ in pairs(_applied) do applied_count = applied_count + 1 end

	return {
		pool_size    = M.pool_size(),
		pool_from    = _stats.pool_from,
		draft_pending = _run_state and _run_state.draft_pending() or false,
		offered_this_leg = _draft_offered_this_leg,
		data_table   = _buffs_data() ~= nil,
		parser       = _mission_buffs_parser() ~= false,
		owned        = owned,
		applied_now  = applied_count,
		applied_total = _stats.applied,
		failed       = _stats.failed,
		spawns       = _stats.spawns,
		last_error   = _stats.last_error,
	}
end

-- ===========================================================================
-- v0.22.81 (Session F foothold / Boons v2): the Boon Loadout.
-- ===========================================================================
--
-- Custom Pilgrimage boons, purchasable as PERMANENT unlocks with Ordos
-- and slotted into a loadout that is active from run start, every run,
-- while slotted. They can NEVER appear in the between-legs draft (the
-- draft rolls from Fatshark's hordes pool; these ids aren't in it), per
-- the Section 3f pool partition.
--
-- Storage (DMF settings):
--   _boon_library_owned    csv of purchased custom boon ids
--   _boon_loadout_slotted  csv of currently slotted ids
-- Slot count: 1 base + boon_slot_2/boon_slot_3 Emporium purchases
-- (slot 4 reserved for a future penance per the locked Section 9
-- decision: at least one expansion Ordos-purchasable, rest penances).
--
-- Templates register through Passives.register_template_source so one
-- hook_require owns the buff_templates path. Prices flagged for the
-- Ordos economy audit.

local KEY_BOON_OWNED   = "_boon_library_owned"
local KEY_BOON_SLOTTED = "_boon_loadout_slotted"

-- Ability-state Legendary helpers. These controller buffs stay on the
-- operative for the mission, but expose their stats/keywords only while the
-- matching native ability keyword is present. This is the same lifecycle
-- shape Fatshark uses for its own Hordes stance boons, so death, respawn and
-- an ordinary ability end cannot leave a second Pilgrimage timer running.
local function _ability_state_template(active_keyword, stat_values, keyword_names)
	return function(BS)
		local stats, keywords = {}, {}
		for stat_name, value in pairs(stat_values or {}) do
			local token = BS.stat_buffs[stat_name]
			if token then stats[token] = value end
		end
		for i = 1, #(keyword_names or {}) do
			local token = BS.keywords[keyword_names[i]]
			if token then keywords[#keywords + 1] = token end
		end
		local active_token = BS.keywords[active_keyword]
		return {
			class_name = "buff",
			max_stacks = 1,
			max_stacks_cap = 1,
			predicted = false,
			conditional_stat_buffs = stats,
			conditional_keywords = keywords,
			start_func = function(template_data)
				template_data.ability_active = false
			end,
			conditional_stat_buffs_func = function(template_data)
				return template_data.ability_active
			end,
			conditional_keywords_func = function(template_data)
				return template_data.ability_active
			end,
			update_func = function(template_data, template_context)
				local ext = template_context.buff_extension
				template_data.ability_active = active_token ~= nil
					and ext ~= nil and ext:has_keyword(active_token) or false
			end,
		}
	end
end

-- Returns the live native ability buff instance. BuffExtension deliberately
-- exposes presence checks but no public instance getter; duration extension
-- therefore uses the extension's own active-buff array, then calls Buff's
-- public add_duration method. Keeping this seam in one helper makes source
-- drift easy to audit after a game update.
local function _active_buff_instance(buff_extension, template_names)
	local buffs = buff_extension and buff_extension._buffs
	if type(buffs) ~= "table" then return nil end
	for i = 1, #buffs do
		local buff = buffs[i]
		local ok, template = pcall(buff.template, buff)
		local name = ok and template and template.name
		for j = 1, #template_names do
			if name == template_names[j] then return buff end
		end
	end
	return nil
end

local function _duration_refund_template(active_templates, critical_only, per_kill, cap)
	return function(BS)
		return {
			class_name = "server_only_proc_buff",
			max_stacks = 1,
			max_stacks_cap = 1,
			predicted = false,
			proc_events = { [BS.proc_events.on_kill] = 1 },
			check_proc_func = function(params, template_data, template_context)
				if critical_only and not params.is_critical_strike then return false end
				return _active_buff_instance(template_context.buff_extension, active_templates) ~= nil
			end,
			proc_func = function(params, template_data, template_context)
				if not template_context.is_server then return end
				local buff = _active_buff_instance(template_context.buff_extension, active_templates)
				if not buff then return end
				local amount = per_kill
				if cap then
					local ok, already = pcall(buff.extra_duration, buff)
					already = ok and already or 0
					amount = math.min(amount, math.max(0, cap - (already or 0)))
				end
				if amount > 0 then pcall(buff.add_duration, buff, amount) end
			end,
		}
	end
end

-- Declared before the custom template factories so their callbacks capture the
-- local helpers rather than looking for globals. The implementations live in
-- the runtime section, after the full catalogue has been built.
local _deal_secondary_damage
-- Every damage profile name can be serialized by Darktide's attack report and
-- death systems. Borrow a shipped reflection profile name so secondary damage
-- always has a valid network lookup on hosts and clients. A custom local name
-- caused crash 60fc7451-f711-44ff-9049-227c17dc04e4 when an arc was reported.
local SECONDARY_DAMAGE_PROFILE_NAME = "hordes_buff_damage_reflection_hit"
local _nearest_enemy_in_radius
local _nearest_enemy_at_position
local _for_each_enemy_in_radius
local _for_each_enemy_at_position

local function _cold_wake_template(BS)
	local stance_keyword = BS.keywords.veteran_combat_ability_stance
	local dodge_keyword = BS.keywords.count_as_dodge_vs_ranged
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		conditional_keywords = dodge_keyword and { dodge_keyword } or {},
		proc_events = { [BS.proc_events.on_ranged_dodge] = 1 },
		start_func = function(template_data)
			template_data.ability_active = false
		end,
		conditional_keywords_func = function(template_data)
			return template_data.ability_active
		end,
		update_func = function(template_data, template_context)
			local extension = template_context.buff_extension
			template_data.ability_active = stance_keyword ~= nil
				and extension ~= nil and extension:has_keyword(stance_keyword) or false
		end,
		check_proc_func = function(params, template_data)
			return template_data.ability_active
		end,
		proc_func = function(params, template_data, template_context)
			if not template_context.is_server then return end
			local buff = _active_buff_instance(template_context.buff_extension, {
				"veteran_combat_ability_stance_master",
				"veteran_combat_ability_stance_master_increased_duration",
			})
			if not buff then return end
			local ok, already = pcall(buff.extra_duration, buff)
			already = ok and already or 0
			local amount = math.min(0.5, math.max(0, 10 - (already or 0)))
			if amount > 0 then pcall(buff.add_duration, buff, amount) end
		end,
	}
end

local function _house_edge_template(BS)
	local stance_keyword = BS.keywords.broker_combat_ability_focus
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		check_proc_func = function(params, template_data, template_context)
			return params.is_critical_strike == true
				and (params.actual_damage_dealt or 0) > 0
				and stance_keyword ~= nil
				and template_context.buff_extension:has_keyword(stance_keyword)
		end,
		proc_func = function(params, template_data, template_context)
			if not template_context.is_server then return end
			local target = _nearest_enemy_in_radius(template_context.unit,
				params.attacked_unit, 8, params.attacked_unit)
			if target then
				_deal_secondary_damage(target, template_context.unit,
					(params.actual_damage_dealt or 0) * 0.50, "buff")
			end
		end,
	}
end

local function _gutter_rage_template(BS)
	local stance_keyword = BS.keywords.broker_combat_ability_punk_rage
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		start_func = function(template_data)
			template_data.hit_count = 0
			template_data.was_active = false
		end,
		update_func = function(template_data, template_context)
			local active = stance_keyword ~= nil
				and template_context.buff_extension:has_keyword(stance_keyword) or false
			if not active and template_data.was_active then template_data.hit_count = 0 end
			template_data.was_active = active
		end,
		check_proc_func = function(params, template_data, template_context)
			return params.attack_type == "melee"
				and (params.actual_damage_dealt or 0) > 0
				and stance_keyword ~= nil
				and template_context.buff_extension:has_keyword(stance_keyword)
		end,
		proc_func = function(params, template_data, template_context)
			if not template_context.is_server then return end
			template_data.hit_count = (template_data.hit_count or 0) + 1
			if template_data.hit_count % 10 ~= 0 then return end
			local damage = (params.actual_damage_dealt or 0) * 0.50
			_for_each_enemy_in_radius(template_context.unit, params.attacked_unit, 5,
				nil, function(target)
					_deal_secondary_damage(target, template_context.unit, damage, "buff")
				end)
		end,
	}
end

-- Pilgrim's Momentum keys off Fury of the Faithful's native empowerment
-- buff. That buff starts with the dash and ends on the first accepted melee
-- hit, so a kill proc while it is present is the ability's empowered strike,
-- not an unrelated kill later in the fight. The corpse supplies the damage
-- scale and origin; only nearby living enemies receive the eruption.
function M._pilgrims_momentum_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_minion_death] = 1 },
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and params.attacking_unit == template_context.unit
				and template_context.buff_extension:has_buff_using_buff_template(
					"zealot_dash_buff")
		end,
		proc_func = function(params, template_data, template_context)
			local corpse = params.dying_unit or params.attacked_unit
			local origin = params.position or (corpse and POSITION_LOOKUP[corpse])
			local health = corpse and ScriptUnit.has_extension(corpse, "health_system")
			local ok_max, max_health = health and pcall(health.max_health, health)
			max_health = ok_max and tonumber(max_health) or 0
			local damage = 150 + 0.30 * max_health
			_for_each_enemy_at_position(template_context.unit, origin, 2.5, corpse,
				function(target)
					_deal_secondary_damage(target, template_context.unit, damage, "buff")
				end)
		end,
	}
end

M._fly_trap_targets = setmetatable({}, { __mode = "k" })

-- Touching a flat shield applies Darktide's native electrocution ailment and
-- extends that one stack to the wall's remaining lifetime. We also remember
-- which wall pinned the enemy so the wall-health hook can reject only that
-- enemy's attacks, without making the shield globally invulnerable.
function M._fly_trap_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_unit_touch_force_field] = 1 },
		check_proc_func = function(params, template_data, template_context)
			if not template_context.is_server or params.is_player_unit then return false end
			local field = params.force_field_unit
			local extension = field and ScriptUnit.has_extension(field,
				"force_field_system")
			return extension ~= nil and extension.owner_unit == template_context.unit
				and not extension:is_sphere_shield()
		end,
		proc_func = function(params, template_data, template_context, t)
			local enemy = params.passing_unit
			local field = params.force_field_unit
			local extension = field and ScriptUnit.has_extension(field,
				"force_field_system")
			local remaining = extension and extension:remaining_duration() or 0
			if remaining <= 0 or not HEALTH_ALIVE[enemy] then return end
			local enemy_buffs = ScriptUnit.has_extension(enemy, "buff_system")
			if not enemy_buffs then return end
			local had_shock = false
			if type(enemy_buffs.current_stacks) == "function" then
				local ok_stacks, stacks = pcall(enemy_buffs.current_stacks,
					enemy_buffs, "hordes_ailment_shock")
				had_shock = ok_stacks and (tonumber(stacks) or 0) > 0
			end
			if type(enemy_buffs.add_internally_controlled_buff_with_stacks)
				== "function" then
				pcall(enemy_buffs.add_internally_controlled_buff_with_stacks,
					enemy_buffs, "hordes_ailment_shock", 1, t,
					"owner_unit", template_context.unit)
			else
				pcall(enemy_buffs.add_internally_controlled_buff, enemy_buffs,
					"hordes_ailment_shock", t, "owner_unit", template_context.unit)
			end
			local shock = enemy_buffs._stacking_buffs
				and enemy_buffs._stacking_buffs.hordes_ailment_shock
			if shock and type(shock.extra_duration) == "function"
				and type(shock.set_extra_duration) == "function" then
				local ok_extra, extra = pcall(shock.extra_duration, shock)
				extra = ok_extra and tonumber(extra) or 0
				local wanted = remaining - 2
				pcall(shock.set_extra_duration, shock,
					had_shock and math.max(extra, wanted) or wanted)
			end
			M._fly_trap_targets[enemy] = {
				field = field,
				expires = t + remaining,
			}
		end,
	}
end

-- Wave B health/toughness helpers. These stay inside the buff system so the
-- server remains authoritative and the effects disappear with the owning
-- player unit. Toughness is loaded lazily because boons.lua also runs in UI
-- contexts where gameplay utilities may not be ready yet.
local _toughness_utility

local function _replenish_toughness(unit, percentage, reason)
	if _toughness_utility == nil then
		local ok, utility = pcall(require, "scripts/utilities/toughness/toughness")
		_toughness_utility = ok and type(utility) == "table" and utility or false
	end
	if not _toughness_utility
		or type(_toughness_utility.replenish_percentage) ~= "function" then
		return false
	end
	return pcall(_toughness_utility.replenish_percentage,
		unit, percentage, false, reason)
end

-- Conduit's pulse is a fixed 20% restore, so it deliberately bypasses
-- toughness-replenishment modifiers. This lets its overflow calculation use
-- the same exact amount the toughness system receives.
local function _replenish_toughness_exact(unit, percentage, reason)
	if _toughness_utility == nil then
		local ok, utility = pcall(require, "scripts/utilities/toughness/toughness")
		_toughness_utility = ok and type(utility) == "table" and utility or false
	end
	if not _toughness_utility
		or type(_toughness_utility.replenish_percentage) ~= "function" then
		return false, 0
	end
	local ok, recovered = pcall(_toughness_utility.replenish_percentage,
		unit, percentage, true, reason)
	return ok, ok and (tonumber(recovered) or 0) or 0
end

-- Conditional player stats must stay on the controller buff itself. Adding or
-- removing a hidden child from update_func changes the same array Darktide is
-- currently traversing, which can leave a nil entry at BuffExtensionBase:206.
-- Updating this boolean changes no collection and is safe on the next stat read.
local function _health_threshold_template(stat_name, amount)
	return function(BS)
		return {
			class_name = "buff",
			max_stacks = 1,
			max_stacks_cap = 1,
			predicted = false,
			start_func = function(template_data, template_context)
				template_data.active = false
				template_data.next_check_t = 0
				template_data.health_extension = ScriptUnit.has_extension(
					template_context.unit, "health_system")
			end,
			update_func = function(template_data, template_context, dt, t)
				if t < (template_data.next_check_t or 0) then return end
				template_data.next_check_t = t + 0.20
				local health = template_data.health_extension
				template_data.active = health ~= nil
					and type(health.current_health_percent) == "function"
					and health:current_health_percent() < (1 / 3)
			end,
			conditional_stat_buffs = {
				[BS.stat_buffs[stat_name]] = amount,
			},
			conditional_stat_buffs_func = function(template_data)
				return template_data.active == true
			end,
			check_active_func = function(template_data)
				return template_data.active == true
			end,
		}
	end
end

local function _brace_for_it_template(BS)
	return {
		class_name = "proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		cooldown_duration = 3,
		proc_events = { [BS.proc_events.on_block] = 1 },
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
		end,
		proc_func = function(params, template_data, template_context)
			_replenish_toughness(template_context.unit, 0.10,
				"pilgrimage_brace_for_it")
		end,
	}
end

local function _refusal_response_template(BS)
	return {
		class_name = "proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		cooldown_duration = 12,
		proc_events = { [BS.proc_events.on_damage_taken] = 1 },
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and params.attacked_unit == template_context.unit
				and (params.damage_amount or 0) > 0
		end,
		proc_func = function(params, template_data, template_context, t)
			_replenish_toughness(template_context.unit, 0.30,
				"pilgrimage_refusal_response")
			local buff_extension = template_context.buff_extension
			if buff_extension
				and type(buff_extension.add_internally_controlled_buff) == "function" then
				buff_extension:add_internally_controlled_buff(
					"pilgrim_refusal_response_guard", t)
			end
		end,
	}
end

-- Wave B timed-trigger helpers. A visible family boon listens for the combat
-- event, then adds a hidden child buff containing only the temporary stats.
-- This mirrors Fatshark's own kill-buff pattern and lets the buff system own
-- duration refreshes and stack caps instead of maintaining parallel timers.
local _electrocution_keyword_names = {
	"electrocuted",
	"electrocuted_chain_lightning",
	"electrocuted_arc",
	"electrocuted_arc_grenade",
	"electrocuted_arc_ability",
	"electrocuted_shock_mine",
}

local function _resolve_ailment_tokens(BS, ailment_names)
	local tokens = {}
	local damage_types = {}
	local seen = {}
	local function add_keyword(name)
		local token = BS.keywords and BS.keywords[name]
		if token ~= nil and not seen[token] then
			seen[token] = true
			tokens[#tokens + 1] = token
		end
	end
	for i = 1, #ailment_names do
		local name = ailment_names[i]
		if name == "electrocuted" then
			for j = 1, #_electrocution_keyword_names do
				add_keyword(_electrocution_keyword_names[j])
			end
			damage_types.electrocution = true
		else
			add_keyword(name)
			if name == "warpfire_burning" then
				damage_types.warpfire = true
			elseif name == "burning" then
				damage_types.burning = true
			elseif name == "bleeding" then
				damage_types.bleeding = true
			end
		end
	end
	return tokens, damage_types
end

local function _extension_has_any_keyword(extension, tokens)
	if not extension then return false end
	for i = 1, #tokens do
		local token = tokens[i]
		if type(extension.has_keyword) == "function" then
			local ok, has = pcall(extension.has_keyword, extension, token)
			if ok and has then return true end
		end
		if type(extension.had_keyword) == "function" then
			local ok, had = pcall(extension.had_keyword, extension, token)
			if ok and had then return true end
		end
	end
	return false
end

-- Nearby-state boons care about what is on the enemy now. Unlike the death
-- fallback above, they must not use had_keyword, because that briefly remembers
-- an ailment after it has ended and would leave the bonus active too long.
local function _extension_has_current_keyword(extension, tokens)
	if not extension or type(extension.has_keyword) ~= "function" then return false end
	for i = 1, #tokens do
		local ok, has = pcall(extension.has_keyword, extension, tokens[i])
		if ok and has then return true end
	end
	return false
end

local function _count_nearby_ailing_enemies(player_unit, radius, tokens)
	local count = 0
	_for_each_enemy_in_radius(player_unit, player_unit, radius, nil, function(enemy)
		local extension = ScriptUnit and type(ScriptUnit.has_extension) == "function"
			and ScriptUnit.has_extension(enemy, "buff_system") or nil
		if _extension_has_current_keyword(extension, tokens) then
			count = count + 1
		end
	end)
	return count
end

local function _nearby_ailment_template(stat_name, amount, ailment_names,
		minimum_count)
	return function(BS)
		local tokens = _resolve_ailment_tokens(BS, ailment_names)
		return {
			class_name = "buff",
			max_stacks = 1,
			max_stacks_cap = 1,
			predicted = false,
			start_func = function(template_data)
				template_data.next_check_t = 0
				template_data.active = false
			end,
			update_func = function(template_data, template_context, dt, t)
				if not template_context.is_server
					or t < (template_data.next_check_t or 0) then return end
				template_data.next_check_t = t + 0.50

				local count = _count_nearby_ailing_enemies(
					template_context.unit, 8, tokens)
				template_data.active = count >= minimum_count
			end,
			conditional_stat_buffs = {
				[BS.stat_buffs[stat_name]] = amount,
			},
			conditional_stat_buffs_func = function(template_data)
				return template_data.active == true
			end,
			check_active_func = function(template_data)
				return template_data.active == true
			end,
		}
	end
end

-- Entropy Feast used to add and remove one child buff per nearby enemy from
-- inside its own update_func. BuffExtensionBase iterates a fixed upper bound,
-- so shrinking that same buff array mid-iteration can leave a later slot nil
-- and crash the engine. Keep one buff instance instead and let Darktide's
-- native dynamic stat multiplier turn the observed enemy count into attack
-- speed. The count can change every half second without mutating the array.
local function _entropy_feast_template(BS)
	local tokens = _resolve_ailment_tokens(BS,
		{ "burning", "warpfire_burning", "bleeding", "electrocuted" })
	return {
		class_name = "buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		stat_buffs = {
			[BS.stat_buffs.attack_speed] = 0.10,
		},
		stat_buff_multiplier = function(template_data)
			return math.min(255, math.max(0,
				math.floor(template_data.nearby_ailing_count or 0)))
		end,
		visual_stack_count = function(template_data)
			return template_data.nearby_ailing_count or 0
		end,
		start_func = function(template_data)
			template_data.next_check_t = 0
			template_data.nearby_ailing_count = 0
		end,
		update_func = function(template_data, template_context, dt, t)
			if not template_context.is_server
				or t < (template_data.next_check_t or 0) then return end
			template_data.next_check_t = t + 0.50
			template_data.nearby_ailing_count = _count_nearby_ailing_enemies(
				template_context.unit, 8, tokens)
		end,
	}
end

-- Movement boons use the authoritative character-state component instead of
-- input guesses. That cleanly separates ordinary walking from dodge, slide and
-- sprint actions. The small velocity check prevents Moving Target from staying
-- active when the walking state is idle.
--
-- IMPORTANT: the parent owns its conditional stat directly. The first build
-- added and removed a hidden child buff from update_func. Darktide was already
-- iterating that same buff array, so removing the child could shorten the array
-- underneath the engine and crash buff_extension_base.lua:206. Updating one
-- boolean is safe because it does not change the array being traversed.
local function _velocity_length_squared(velocity)
	if velocity == nil then return 0 end
	if Vector3 and type(Vector3.length_squared) == "function" then
		local ok, value = pcall(Vector3.length_squared, velocity)
		if ok and type(value) == "number" then return value end
	end
	if type(velocity) == "table" then
		local x = velocity.x or velocity[1] or 0
		local y = velocity.y or velocity[2] or 0
		local z = velocity.z or velocity[3] or 0
		return x * x + y * y + z * z
	end
	return 0
end

local function _movement_state_template(predicate, ranged_damage)
	return function(BS)
		return {
			class_name = "buff",
			max_stacks = 1,
			max_stacks_cap = 1,
			predicted = false,
			start_func = function(template_data, template_context)
				template_data.next_check_t = 0
				template_data.active = false
				local unit_data = ScriptUnit.has_extension(
					template_context.unit, "unit_data_system")
				if unit_data then
					template_data.character_state = unit_data:read_component("character_state")
					template_data.locomotion = unit_data:read_component("locomotion")
				end
			end,
			update_func = function(template_data, template_context, dt, t)
				if not template_context.is_server
					or t < (template_data.next_check_t or 0) then return end
				template_data.next_check_t = t + 0.05
				local state = template_data.character_state
				local locomotion = template_data.locomotion
				local active = state ~= nil
					and predicate(state.state_name, locomotion,
						_velocity_length_squared)
				template_data.active = active == true
			end,
			conditional_stat_buffs = {
				[BS.stat_buffs.ranged_damage] = ranged_damage,
			},
			conditional_stat_buffs_func = function(template_data)
				return template_data.active == true
			end,
			check_active_func = function(template_data)
				return template_data.active == true
			end,
		}
	end
end

local function _is_moving_normally(state_name, locomotion, length_squared)
	return state_name == "walking" and locomotion ~= nil
		and length_squared(locomotion.velocity_current) > 0.01
end

local function _is_dodging_or_sliding(state_name)
	return state_name == "dodging" or state_name == "sliding"
end

local function _death_has_ailment(params, tokens, damage_types)
	local death_keywords = params.keywords_on_death_or_nil
	if death_keywords then
		for i = 1, #tokens do
			if death_keywords[tokens[i]] then return true end
		end
	end

	local dying_unit = params.dying_unit or params.attacked_unit
	local extension = ScriptUnit and dying_unit
		and type(ScriptUnit.has_extension) == "function"
		and ScriptUnit.has_extension(dying_unit, "buff_system") or nil
	if _extension_has_any_keyword(extension, tokens) then return true end

	return damage_types[params.damage_type] == true
end

local function _timed_trigger_template(child_template_name, proc_event_name,
		predicate)
	return function(BS)
		local proc_event = assert(BS.proc_events[proc_event_name],
			"missing proc event: " .. proc_event_name)
		return {
			class_name = "server_only_proc_buff",
			max_stacks = 1,
			max_stacks_cap = 1,
			predicted = false,
			proc_events = { [proc_event] = 1 },
			check_proc_func = function(params, template_data, template_context)
				return template_context.is_server
					and predicate(params, template_context, BS)
			end,
			proc_func = function(params, template_data, template_context, t)
				local extension = template_context.buff_extension
				if extension and type(extension.add_internally_controlled_buff) == "function" then
					extension:add_internally_controlled_buff(child_template_name, t)
				end
			end,
		}
	end
end

local function _ailment_kill_timed_template(child_template_name, ailment_names)
	return function(BS)
		local tokens, damage_types = _resolve_ailment_tokens(BS, ailment_names)
		return _timed_trigger_template(child_template_name, "on_minion_death",
			function(params, template_context)
				return params.attacking_unit == template_context.unit
					and _death_has_ailment(params, tokens, damage_types)
			end)(BS)
	end
end

local function _pyre_tithe_template(BS)
	local tokens, damage_types = _resolve_ailment_tokens(BS,
		{ "burning", "warpfire_burning" })
	local proc_event = assert(BS.proc_events.on_minion_death,
		"missing proc event: on_minion_death")
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [proc_event] = 1 },
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and params.attacking_unit == template_context.unit
				and _death_has_ailment(params, tokens, damage_types)
		end,
		proc_func = function(params, template_data, template_context)
			_replenish_toughness(template_context.unit, 0.02,
				"pilgrimage_pyre_tithe")
		end,
	}
end

-- v0.28.8: LOUDER! follows the Taunt's real pulse event. The initial shout
-- and both repeats all emit on_ogryn_shout, so one proc covers all three
-- waves without maintaining a second timer that could drift from the ability.
-- Each pulse borrows Voice of Command's native 50-point bonus-Toughness buff,
-- then restores the affected unit to its new maximum. Using the shipped buff
-- preserves the yellow Toughness presentation and its normal ten-second life.
local LOUDER_GOLDEN_TOUGHNESS_BUFF =
	"veteran_combat_ability_increase_toughness_to_coherency"

local function _apply_louder_toughness(unit, owner_unit, t)
	if not unit or not HEALTH_ALIVE[unit] then return end
	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")
	if not buff_extension
		or type(buff_extension.add_internally_controlled_buff) ~= "function" then return end

	local ok = pcall(buff_extension.add_internally_controlled_buff,
		buff_extension, LOUDER_GOLDEN_TOUGHNESS_BUFF, t,
		"owner_unit", owner_unit)
	if ok then
		_replenish_toughness(unit, 1, "pilgrimage_louder")
	end
end

local function _pulse_louder_toughness(player_unit, t)
	local affected = {}
	local function apply(unit)
		if not unit or affected[unit] then return end
		affected[unit] = true
		_apply_louder_toughness(unit, player_unit, t)
	end

	apply(player_unit)
	local coherency_extension = ScriptUnit.has_extension(player_unit, "coherency_system")
	if not coherency_extension
		or type(coherency_extension.in_coherence_units) ~= "function" then return end
	local ok, units = pcall(coherency_extension.in_coherence_units,
		coherency_extension)
	if not ok or type(units) ~= "table" then return end
	for unit in pairs(units) do apply(unit) end
end

local function _louder_template(BS)
	local proc_event = assert(BS.proc_events.on_ogryn_shout,
		"missing proc event: on_ogryn_shout")
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [proc_event] = 1 },
		proc_func = function(params, template_data, template_context, t)
			_pulse_louder_toughness(template_context.unit, t)
		end,
	}
end

local function _timed_stat_template(duration, max_stacks, stat_values)
	return function(BS)
		local resolved = {}
		for stat_name, value in pairs(stat_values) do
			local token = assert(BS.stat_buffs[stat_name],
				"missing stat buff: " .. stat_name)
			resolved[token] = value
		end
		return {
			class_name = "buff",
			duration = duration,
			max_stacks = max_stacks,
			max_stacks_cap = max_stacks,
			predicted = false,
			refresh_duration_on_stack = true,
			stat_buffs = resolved,
		}
	end
end

local function _stacking_stat_template(max_stacks, stat_values)
	return function(BS)
		local resolved = {}
		for stat_name, value in pairs(stat_values) do
			local token = assert(BS.stat_buffs[stat_name],
				"missing stat buff: " .. stat_name)
			resolved[token] = value
		end
		return {
			class_name = "buff",
			max_stacks = max_stacks,
			max_stacks_cap = max_stacks,
			predicted = false,
			stat_buffs = resolved,
		}
	end
end

-- Wave B hit/application helpers. Ailments are placed on the victim through
-- the same target-side buff API used by Fatshark's Hordes boons. Keeping this
-- in one helper preserves source ownership, stack counts and server authority
-- for Cinder Touch, Ion Wake, Livewire and Prism of Ruin.
local function _apply_ailment_stacks(target_unit, buff_name, stacks, t,
		owner_unit)
	if not target_unit or (HEALTH_ALIVE and not HEALTH_ALIVE[target_unit])
		or not ScriptUnit or type(ScriptUnit.has_extension) ~= "function" then
		return false
	end
	local extension = ScriptUnit.has_extension(target_unit, "buff_system")
	if not extension then return false end
	stacks = math.max(1, math.floor(stacks or 1))
	if type(extension.add_internally_controlled_buff_with_stacks) == "function" then
		local ok = pcall(extension.add_internally_controlled_buff_with_stacks,
			extension, buff_name, stacks, t, "owner_unit", owner_unit)
		return ok
	end
	if type(extension.add_internally_controlled_buff) ~= "function" then
		return false
	end
	for i = 1, stacks do
		local ok = pcall(extension.add_internally_controlled_buff,
			extension, buff_name, t, "owner_unit", owner_unit)
		if not ok then return false end
	end
	return true
end

local function _cinder_touch_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		start_func = function(template_data)
			template_data.target_ready_at = setmetatable({}, { __mode = "k" })
		end,
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and params.attack_type == "melee"
				and params.hit_weakspot == true
				and (params.actual_damage_dealt or 0) > 0
		end,
		proc_func = function(params, template_data, template_context, t)
			local target = params.attacked_unit
			local ready_at = template_data.target_ready_at
			if not target or t < (ready_at[target] or 0) then return end
			if _apply_ailment_stacks(target, "flamer_assault", 1, t,
					template_context.unit) then
				ready_at[target] = t + 1
			end
		end,
	}
end

local function _ion_wake_template(BS)
	return {
		class_name = "server_only_proc_buff",
		cooldown_duration = 3,
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_successful_dodge] = 1 },
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and params.attack_type == "melee"
				and params.attacking_unit ~= nil
		end,
		proc_func = function(params, template_data, template_context, t)
			_apply_ailment_stacks(params.attacking_unit, "hordes_ailment_shock",
				1, t, template_context.unit)
		end,
	}
end

local function _livewire_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and params.attack_type == "melee"
				and params.is_critical_strike == true
				and (params.actual_damage_dealt or 0) > 0
		end,
		proc_func = function(params, template_data, template_context, t)
			_apply_ailment_stacks(params.attacked_unit, "hordes_ailment_shock",
				1, t, template_context.unit)
		end,
	}
end

local CONDUIT_BONUS_TOUGHNESS_BUFF = "pilgrim_conduit_bonus_toughness"
local CONDUIT_CHARGES_PER_PULSE = 10
local CONDUIT_BONUS_TOUGHNESS_CAP = 50

local function _conduit_bonus_stacks(buff_extension)
	if not buff_extension or type(buff_extension.current_stacks) ~= "function" then
		return 0
	end
	local ok, stacks = pcall(buff_extension.current_stacks, buff_extension,
		CONDUIT_BONUS_TOUGHNESS_BUFF)
	return ok and math.max(0, tonumber(stacks) or 0) or 0
end

local function _add_conduit_bonus_toughness(unit, buff_extension, t, amount)
	local current = _conduit_bonus_stacks(buff_extension)
	local available = math.max(0, CONDUIT_BONUS_TOUGHNESS_CAP - current)
	local stacks = math.min(available, math.max(0, math.floor(amount + 0.5)))
	if stacks <= 0 then return 0 end
	if type(buff_extension.add_internally_controlled_buff_with_stacks) == "function" then
		local ok = pcall(buff_extension.add_internally_controlled_buff_with_stacks,
			buff_extension, CONDUIT_BONUS_TOUGHNESS_BUFF, stacks, t,
			"owner_unit", unit)
		return ok and stacks or 0
	end
	if type(buff_extension.add_internally_controlled_buff) ~= "function" then return 0 end
	local added = 0
	for i = 1, stacks do
		local ok = pcall(buff_extension.add_internally_controlled_buff,
			buff_extension, CONDUIT_BONUS_TOUGHNESS_BUFF, t,
			"owner_unit", unit)
		if not ok then break end
		added = added + 1
	end
	return added
end

local function _conduit_restore_owner(unit, t)
	local toughness_extension = ScriptUnit.has_extension(unit, "toughness_system")
	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")
	if not toughness_extension or not buff_extension
		or type(toughness_extension.max_toughness) ~= "function"
		or type(toughness_extension.remaining_toughness) ~= "function" then
		_replenish_toughness_exact(unit, 0.20, "pilgrimage_conduit")
		return
	end

	local ok_max, max_toughness = pcall(toughness_extension.max_toughness,
		toughness_extension)
	local ok_remaining, remaining = pcall(toughness_extension.remaining_toughness,
		toughness_extension)
	max_toughness = ok_max and tonumber(max_toughness) or 0
	remaining = ok_remaining and tonumber(remaining) or 0
	local intended = math.max(0, max_toughness * 0.20)
	local missing = math.max(0, max_toughness - remaining)

	_replenish_toughness_exact(unit, 0.20, "pilgrimage_conduit")
	-- Increasing max Toughness also raises current Toughness by the same amount.
	-- One-point, ten-second stacks therefore represent only the part of the
	-- pulse which could not fit under the owner's current maximum.
	_add_conduit_bonus_toughness(unit, buff_extension, t,
		math.max(0, intended - missing))
end

local function _pulse_conduit_toughness(unit, t)
	_conduit_restore_owner(unit, t)
	local coherency = ScriptUnit.has_extension(unit, "coherency_system")
	if not coherency or type(coherency.in_coherence_units) ~= "function" then return end
	local ok, units = pcall(coherency.in_coherence_units, coherency)
	if not ok or type(units) ~= "table" then return end
	for ally in pairs(units) do
		if ally ~= unit and (not HEALTH_ALIVE or HEALTH_ALIVE[ally]) then
			_replenish_toughness_exact(ally, 0.20, "pilgrimage_conduit")
		end
	end
end

-- Conduit rewards keeping enemies electrified. Deliberate hits against a
-- currently shocked target build one shared charge at most every half-second;
-- ten charges discharge a team Toughness pulse. The damage cost is applied in
-- install_family_damage_calculation, where the actual target is available.
local function _conduit_template(BS)
	local shock_tokens = _resolve_ailment_tokens(BS, { "electrocuted" })
	local direct_attack_types = {
		arc = true,
		melee = true,
		ranged = true,
		explosion = true,
		shout = true,
		push = true,
		companion_dog = true,
	}
	return {
		class_name = "server_only_proc_buff",
		cooldown_duration = 0.5,
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		start_func = function(template_data)
			template_data.charge = 0
		end,
		check_proc_func = function(params, template_data, template_context)
			if not template_context.is_server
				or not direct_attack_types[params.attack_type]
				or (params.actual_damage_dealt or 0) <= 0 then return false end
			local target_extension = params.attacked_unit
				and ScriptUnit.has_extension(params.attacked_unit, "buff_system")
			return _extension_has_current_keyword(target_extension, shock_tokens)
		end,
		proc_func = function(params, template_data, template_context, t)
			template_data.charge = (template_data.charge or 0) + 1
			if template_data.charge < CONDUIT_CHARGES_PER_PULSE then return end
			template_data.charge = 0
			_pulse_conduit_toughness(template_context.unit, t)
		end,
	}
end

-- Closed Circuit repeats a quarter of a direct hit's final damage against one
-- other shocked enemy. `buff` attacks are damage-over-time ticks and secondary
-- effects, so excluding that attack type keeps the boon on deliberate hits.
-- The borrowed secondary profile also has skip_on_hit_proc, giving the arc a
-- second recursion barrier inside Darktide's native proc dispatcher.
local function _closed_circuit_template(BS)
	local shock_tokens = _resolve_ailment_tokens(BS, { "electrocuted" })
	local direct_attack_types = {
		arc = true,
		melee = true,
		ranged = true,
		explosion = true,
		shout = true,
		push = true,
		companion_dog = true,
	}
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		check_proc_func = function(params, template_data, template_context)
			if not template_context.is_server
				or not direct_attack_types[params.attack_type]
				or (params.actual_damage_dealt or 0) <= 0
				or params.attacked_unit == nil then return false end
			local target_extension = ScriptUnit.has_extension(
				params.attacked_unit, "buff_system")
			return _extension_has_current_keyword(target_extension, shock_tokens)
		end,
		proc_func = function(params, template_data, template_context)
			local other = _nearest_enemy_in_radius(template_context.unit,
				params.attacked_unit, 8, params.attacked_unit, function(target)
					local extension = ScriptUnit.has_extension(target, "buff_system")
					return _extension_has_current_keyword(extension, shock_tokens)
				end)
			if other then
				_deal_secondary_damage(other, template_context.unit,
					(params.actual_damage_dealt or 0) * 0.25, "electrocution")
			end
		end,
	}
end

-- Backdraft searches from the corpse position because a dead unit can leave
-- POSITION_LOOKUP before its death proc is dispatched. The 32 metre ceiling
-- keeps the broadphase query bounded while still covering an ordinary combat
-- space. One owned burn stack is enough to make the new target "ignited" and
-- lets every normal burn-duration and burn-damage modifier interact with it.
local function _backdraft_template(BS)
	local tokens, damage_types = _resolve_ailment_tokens(BS,
		{ "burning", "warpfire_burning" })
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_minion_death] = 1 },
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and params.attacking_unit == template_context.unit
				and _death_has_ailment(params, tokens, damage_types)
				and math.random() <= 0.25
		end,
		proc_func = function(params, template_data, template_context, t)
			local origin = params.position
				or (params.dying_unit and POSITION_LOOKUP[params.dying_unit])
			local target = _nearest_enemy_at_position(template_context.unit,
				origin, 32, params.dying_unit)
			if target then
				_apply_ailment_stacks(target, "flamer_assault", 1, t,
					template_context.unit)
			end
		end,
	}
end

local function _is_fire_liquid_area(extension)
	if not extension or type(extension.area_template_name) ~= "function" then
		return false
	end
	local ok, name = pcall(extension.area_template_name, extension)
	if not ok or type(name) ~= "string" then return false end
	name = string.lower(name)
	-- Fatshark's player and enemy fire pools use fire, flamer, flame or
	-- burning in their template names. Matching the semantic stem also keeps
	-- this compatible with new enemy variants without knowing their side.
	return string.find(name, "fire", 1, true) ~= nil
		or string.find(name, "flamer", 1, true) ~= nil
		or string.find(name, "flame", 1, true) ~= nil
		or string.find(name, "burn", 1, true) ~= nil
end

local function _fireproofed_template(BS)
	local fire_tokens = _resolve_ailment_tokens(BS,
		{ "burning", "warpfire_burning", "damage_volume_burning" })
	return {
		class_name = "buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		start_func = function(template_data, template_context)
			template_data.active = false
			template_data.next_area_check = 0
			template_data.in_fire_area = false
			template_data.liquid_areas = {}
			local manager = Managers.state.extension
			template_data.liquid_area_system = manager
				and manager:system("liquid_area_system") or nil
		end,
		update_func = function(template_data, template_context, dt, t)
			local extension = template_context.buff_extension
			local afflicted = _extension_has_current_keyword(extension, fire_tokens)
			if t >= (template_data.next_area_check or 0) then
				template_data.next_area_check = t + 0.20
				template_data.in_fire_area = false
				local areas = template_data.liquid_areas
				for key in pairs(areas) do areas[key] = nil end
				local unit_position = POSITION_LOOKUP[template_context.unit]
				local system = template_data.liquid_area_system
				if system and unit_position
					and type(system.find_liquid_areas_in_position) == "function" then
					local ok = pcall(system.find_liquid_areas_in_position,
						system, unit_position, areas)
					if ok then
						for _, area in pairs(areas) do
							if _is_fire_liquid_area(area) then
								template_data.in_fire_area = true
								break
							end
						end
					end
				end
			end
			template_data.active = afflicted or template_data.in_fire_area
		end,
		conditional_stat_buffs = {
			[BS.stat_buffs.damage_taken_multiplier] = 0.50,
		},
		conditional_stat_buffs_func = function(template_data)
			return template_data.active == true
		end,
		check_active_func = function(template_data)
			return template_data.active == true
		end,
	}
end

local function _capacitance_feedback_template(BS)
	local shock_tokens, damage_types = _resolve_ailment_tokens(BS,
		{ "electrocuted" })
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_minion_death] = 1 },
		start_func = function(template_data, template_context)
			template_data.ability_extension = ScriptUnit.extension(
				template_context.unit, "ability_system")
			local manager = Managers.state.extension
			local side_system = manager and manager:system("side_system")
			local side = side_system and side_system.side_by_unit[template_context.unit]
			template_data.enemy_side_names = {}
			if side and type(side.relation_side_names) == "function" then
				local names = side:relation_side_names("enemy")
				for i = 1, #names do
					template_data.enemy_side_names[names[i]] = true
				end
			end
		end,
		check_proc_func = function(params, template_data, template_context)
			if not template_context.is_server
				or not template_data.enemy_side_names[params.side_name]
				or not _death_has_ailment(params, shock_tokens, damage_types) then
				return false
			end
			local owner_position = POSITION_LOOKUP[template_context.unit]
			local death_position = params.position
				or (params.dying_unit and POSITION_LOOKUP[params.dying_unit])
			return owner_position ~= nil and death_position ~= nil
				and Vector3.distance_squared(owner_position, death_position) <= 64
		end,
		proc_func = function(params, template_data)
			template_data.ability_extension:reduce_ability_cooldown_percentage(
				"combat_ability", 0.03)
		end,
	}
end

local function _first_to_draw_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_wield_ranged] = 1 },
		start_func = function(template_data)
			template_data.ready_at = 0
		end,
		check_proc_func = function(params, template_data, template_context, t)
			return template_context.is_server and t >= (template_data.ready_at or 0)
		end,
		proc_func = function(params, template_data, template_context, t)
			template_context.buff_extension:add_internally_controlled_buff(
				"pilgrim_first_to_draw_effect", t)
			template_data.ready_at = t + 5
		end,
	}
end

-- Dead Man's Chamber accepts both of Darktide's real firing orders. Hitscan
-- weapons resolve damage and queue a death BEFORE ActionShoot spends ammo;
-- projectiles spend ammo before their later impact. The controller therefore
-- correlates either death->ammo in one proc update or ammo->death across later
-- updates. A small shared state also lets the damage hook empower every pellet
-- of the replacement shot without leaking into the rest of a reload.
local _dead_mans_states = setmetatable({}, { __mode = "k" })
local _ammo_utility

local function _dead_mans_load_round(template_data, t)
	template_data.final_shot_armed = false
	template_data.final_shot_expires_at = nil
	if t < (template_data.ready_at or 0) then return false end

	local component = template_data.inventory_slot_component
	local clip = _ammo_utility.current_ammo_in_clips(component)
	local reserve = tonumber(component.current_ammunition_reserve) or 0
	if clip ~= 0 or reserve < 1 then return false end

	_ammo_utility.transfer_from_reserve_to_clip(component, 1)
	if _ammo_utility.current_ammo_in_clips(component) ~= 1 then return false end

	template_data.state.replacement_armed = true
	template_data.ready_at = t + 2
	return true
end

local function _dead_mans_chamber_template(BS)
	local ammo_event = assert(BS.proc_events.on_ammo_consumed,
		"missing proc event: on_ammo_consumed")
	local death_event = assert(BS.proc_events.on_minion_death,
		"missing proc event: on_minion_death")
	local proc_events = { [ammo_event] = 1, [death_event] = 1 }
	local specific = {}
	local reload_event = BS.proc_events.on_reload
	if reload_event then proc_events[reload_event] = 1 end

	specific[ammo_event] = function(params, template_data, template_context, t)
		local state = template_data.state
		local pre_spend_kill = template_data.pre_spend_ranged_kill_t == t
		template_data.pre_spend_ranged_kill_t = nil
		-- A second shot closes the previous projectile window before it can
		-- inherit the replacement round's damage.
		state.empowered_until = nil
		if state.replacement_armed then
			state.replacement_armed = false
			state.empowered_until = t + 5
		end

		template_data.final_shot_armed = false
		template_data.final_shot_expires_at = nil
		local ammo_used = tonumber(params.ammo_usage) or 0
		if ammo_used ~= 1 or t < (template_data.ready_at or 0) then return end
		local clip = _ammo_utility.current_ammo_in_clips(
			template_data.inventory_slot_component)
		if clip ~= 0 then return end

		if pre_spend_kill then
			-- Hitscan: its kill event was queued by _shoot before this ammo
			-- event was added by _spend_ammunition.
			_dead_mans_load_round(template_data, t)
		else
			-- Projectile: remember the emptying shot until its later impact.
			template_data.final_shot_armed = true
			template_data.final_shot_expires_at = t + 5
		end
	end

	specific[death_event] = function(params, template_data, template_context, t)
		if params.attacking_unit ~= template_context.unit
			or params.attack_type ~= "ranged" then return end

		if template_data.final_shot_armed
			and t <= (template_data.final_shot_expires_at or -1) then
			-- Projectile order. The first death consumes the token, so one
			-- explosion or pellet group cannot manufacture several rounds.
			_dead_mans_load_round(template_data, t)
		else
			-- Hitscan order. The matching on_ammo_consumed event has the same
			-- fixed-update timestamp and will validate that the shot used one
			-- round and actually left the clip empty.
			template_data.pre_spend_ranged_kill_t = t
		end
	end

	if reload_event then
		specific[reload_event] = function(params, template_data)
			template_data.final_shot_armed = false
			template_data.final_shot_expires_at = nil
			template_data.pre_spend_ranged_kill_t = nil
			template_data.state.replacement_armed = false
			template_data.state.empowered_until = nil
		end
	end

	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = proc_events,
		start_func = function(template_data, template_context)
			if not _ammo_utility then
				_ammo_utility = require("scripts/utilities/ammo")
			end
			local unit_data_extension = ScriptUnit.extension(
				template_context.unit, "unit_data_system")
			template_data.inventory_slot_component =
				unit_data_extension:write_component("slot_secondary")
			template_data.final_shot_armed = false
			template_data.final_shot_expires_at = nil
			template_data.pre_spend_ranged_kill_t = nil
			template_data.ready_at = 0
			template_data.state = {
				replacement_armed = false,
				empowered_until = nil,
			}
			_dead_mans_states[template_context.unit] = template_data.state
		end,
		stop_func = function(template_data, template_context)
			_dead_mans_states[template_context.unit] = nil
		end,
		specific_proc_func = specific,
	}
end

-- Belt-Fed Believer stays tied to Point-Blank Barrage's real native buff.
-- Kills neither create a parallel stance timer nor manufacture ammunition:
-- rounds move from the weapon's existing reserve into its current clip, while
-- Buff:add_duration extends the same ability instance the HUD is already
-- tracking. Per-activation counters enforce the two independent caps.
local _unstoppable_family = {
	belt_fed_active_templates = { "ogryn_ranged_stance" },
	attack_windows = setmetatable({}, { __mode = "k" }),
}

function _unstoppable_family.belt_fed_template(BS)
	local stance_keyword = BS.keywords.ogryn_combat_ability_stance
	local function active_instance(template_context)
		return _active_buff_instance(template_context.buff_extension,
			_unstoppable_family.belt_fed_active_templates)
	end
	local function stance_active(template_context)
		local extension = template_context.buff_extension
		if stance_keyword ~= nil and extension
			and extension:has_keyword(stance_keyword) then return true end
		return active_instance(template_context) ~= nil
	end

	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_kill] = 1 },
		start_func = function(template_data, template_context)
			if not _ammo_utility then
				_ammo_utility = require("scripts/utilities/ammo")
			end
			local unit_data = ScriptUnit.extension(
				template_context.unit, "unit_data_system")
			template_data.inventory_slot_component =
				unit_data:write_component("slot_secondary")
			template_data.was_active = false
			template_data.loaded_this_stance = 0
			template_data.duration_added = 0
		end,
		update_func = function(template_data, template_context)
			local active = stance_active(template_context)
			if active and not template_data.was_active then
				template_data.loaded_this_stance = 0
				template_data.duration_added = 0
			elseif not active and template_data.was_active then
				template_data.loaded_this_stance = 0
				template_data.duration_added = 0
			end
			template_data.was_active = active
		end,
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and params.attacking_unit == template_context.unit
				and stance_active(template_context)
		end,
		proc_func = function(params, template_data, template_context)
			local component = template_data.inventory_slot_component
			local max_reserve = tonumber(component.max_ammunition_reserve) or 0
			if max_reserve > 0 then
				local per_kill = math.max(1, math.ceil(max_reserve * 0.02))
				local cap = math.max(1, math.ceil(max_reserve * 0.30))
				local remaining = math.max(0,
					cap - (template_data.loaded_this_stance or 0))
				local wanted = math.min(per_kill, remaining)
				if wanted > 0 then
					local before = _ammo_utility.current_ammo_in_clips(component)
					_ammo_utility.transfer_from_reserve_to_clip(component, wanted)
					local after = _ammo_utility.current_ammo_in_clips(component)
					template_data.loaded_this_stance =
						(template_data.loaded_this_stance or 0)
						+ math.max(0, after - before)
				end
			end

			local remaining_duration = math.max(0,
				7 - (template_data.duration_added or 0))
			local duration = math.min(0.5, remaining_duration)
			local buff = active_instance(template_context)
			if buff and duration > 0
				and pcall(buff.add_duration, buff, duration) then
				template_data.duration_added =
					(template_data.duration_added or 0) + duration
			end
		end,
	}
end

-- Crushing Tempo listens to the same sweep events Darktide uses to identify a
-- heavy attack. Only the first damaging hit from each heavy sweep grants a
-- stack, so a wide-cleaving weapon cannot gain all three stacks at once.
function _unstoppable_family.crushing_tempo_template(BS)
	local sweep_start = assert(BS.proc_events.on_sweep_start,
		"missing proc event: on_sweep_start")
	local sweep_finish = assert(BS.proc_events.on_sweep_finish,
		"missing proc event: on_sweep_finish")
	local on_hit = assert(BS.proc_events.on_hit, "missing proc event: on_hit")
	local specific = {}
	specific[sweep_start] = function(params, template_data)
		template_data.heavy_sweep = params.is_heavy == true
		template_data.stack_granted = false
	end
	specific[on_hit] = function(params, template_data, template_context, t)
		if not template_context.is_server or not template_data.heavy_sweep
			or template_data.stack_granted or params.attack_type ~= "melee"
			or (tonumber(params.actual_damage_dealt) or 0) <= 0 then return end
		template_data.stack_granted = true
		template_context.buff_extension:add_internally_controlled_buff(
			"pilgrim_crushing_tempo_effect", t)
	end
	specific[sweep_finish] = function(params, template_data)
		template_data.heavy_sweep = false
		template_data.stack_granted = false
	end
	return {
		class_name = "proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = {
			[sweep_start] = 1,
			[sweep_finish] = 1,
			[on_hit] = 1,
		},
		start_func = function(template_data)
			template_data.heavy_sweep = false
			template_data.stack_granted = false
		end,
		specific_proc_func = specific,
	}
end

function _unstoppable_family.moving_toward_enemy(unit, velocity, radius)
	local origin = unit and POSITION_LOOKUP[unit]
	if not origin or _velocity_length_squared(velocity) <= 0.01 then return false end
	local ok_direction, direction = pcall(Vector3.normalize, velocity)
	if not ok_direction or not direction then return false end
	return _nearest_enemy_in_radius(unit, unit, radius, nil, function(target)
		local target_position = POSITION_LOOKUP[target]
		if not target_position then return false end
		local offset = target_position - origin
		if Vector3.length_squared(offset) <= 0.001 then return true end
		return Vector3.dot(direction, Vector3.normalize(offset)) > 0.5
	end) ~= nil
end

-- Forward Only changes two native sprint statistics directly. Its active flag
-- is just a boolean, so the buff array is never modified from update_func.
function _unstoppable_family.forward_only_template(BS)
	return {
		class_name = "buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		start_func = function(template_data, template_context)
			template_data.next_check_t = 0
			template_data.active = false
			local unit_data = ScriptUnit.has_extension(
				template_context.unit, "unit_data_system")
			template_data.sprint_character_state = unit_data
				and unit_data:read_component("sprint_character_state") or nil
			template_data.locomotion = unit_data
				and unit_data:read_component("locomotion") or nil
		end,
		update_func = function(template_data, template_context, dt, t)
			if t < (template_data.next_check_t or 0) then return end
			template_data.next_check_t = t + 0.10
			local sprinting = _unstoppable_family.is_sprinting(template_data)
			local velocity = template_data.locomotion
				and template_data.locomotion.velocity_current
			template_data.active = sprinting
				and _unstoppable_family.moving_toward_enemy(
					template_context.unit, velocity, 15) or false
		end,
		conditional_stat_buffs = {
			[BS.stat_buffs.sprint_movement_speed] = 0.25,
			[BS.stat_buffs.sprinting_cost_multiplier] = 0.75,
		},
		conditional_stat_buffs_func = function(template_data)
			return template_data.active == true
		end,
		check_active_func = function(template_data)
			return template_data.active == true
		end,
	}
end

-- No Grip Strong Enough reuses the game's own dodge gates. It does not delete
-- projectiles or pounces after contact; the Trapper and hound systems see the
-- same keywords they already honor for native sprint-dodge effects.
function _unstoppable_family.no_grip_template(BS)
	local keywords = {}
	if BS.keywords.count_as_dodge_vs_netgunner then
		keywords[#keywords + 1] = BS.keywords.count_as_dodge_vs_netgunner
	end
	if BS.keywords.count_as_dodge_vs_chaos_hound_pounce then
		keywords[#keywords + 1] = BS.keywords.count_as_dodge_vs_chaos_hound_pounce
	end
	return {
		class_name = "buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		start_func = function(template_data, template_context)
			local unit_data = ScriptUnit.has_extension(
				template_context.unit, "unit_data_system")
			template_data.sprint_character_state = unit_data
				and unit_data:read_component("sprint_character_state") or nil
			template_data.active = false
		end,
		update_func = function(template_data)
			template_data.active = _unstoppable_family.is_sprinting(template_data)
		end,
		conditional_keywords = keywords,
		conditional_keywords_func = function(template_data)
			return template_data.active == true
		end,
		check_active_func = function(template_data)
			return template_data.active == true
		end,
	}
end

local function _prism_of_ruin_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		start_func = function(template_data)
			template_data.armed = false
			template_data.ready_at = nil
		end,
		update_func = function(template_data, template_context, dt, t)
			if template_data.ready_at == nil then
				template_data.ready_at = t + 15
				return
			end
			if template_context.is_server and not template_data.armed
				and t >= template_data.ready_at then
				template_data.armed = true
			end
		end,
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server and template_data.armed
				and (params.actual_damage_dealt or 0) > 0
		end,
		proc_func = function(params, template_data, template_context, t)
			local target = params.attacked_unit
			_apply_ailment_stacks(target, "flamer_assault", 3, t,
				template_context.unit)
			_apply_ailment_stacks(target, "bleed", 3, t,
				template_context.unit)
			_apply_ailment_stacks(target, "hordes_ailment_shock", 2, t,
				template_context.unit)
			template_data.armed = false
			template_data.ready_at = t + 15
		end,
	}
end

local function _remove_all_internal_stacks(extension, template_name)
	if not extension
		or type(extension.has_buff_using_buff_template) ~= "function"
		or type(extension.remove_internally_controlled_buff_stack) ~= "function" then
		return
	end
	-- Current callers cap at six. The guard prevents a malformed
	-- extension double or another mod from turning cleanup into an endless loop.
	local guard = 0
	while extension:has_buff_using_buff_template(template_name) and guard < 16 do
		extension:remove_internally_controlled_buff_stack(template_name)
		guard = guard + 1
	end
end

local function _measured_violence_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and (params.actual_damage_dealt or 0) > 0
		end,
		proc_func = function(params, template_data, template_context, t)
			local extension = template_context.buff_extension
			if params.hit_weakspot == true then
				if extension
					and type(extension.add_internally_controlled_buff) == "function" then
					extension:add_internally_controlled_buff(
						"pilgrim_measured_violence_effect", t)
				end
			else
				_remove_all_internal_stacks(extension,
					"pilgrim_measured_violence_effect")
			end
		end,
	}
end

-- Opening Cut is target-relative, so a plain stat buff cannot express it: the
-- game rolls ordinary critical chance before the hit proc knows which enemy
-- was struck. The Attack.execute integration below promotes only the first
-- direct attack against each target and remembers the result for the current
-- fixed frame, keeping shotgun pellets and melee cleave parts together.
local _critical_family = {
	opening_states = setmetatable({}, { __mode = "k" }),
	direct_opening_attack_types = {
		arc = true,
		companion_dog = true,
		explosion = true,
		melee = true,
		push = true,
		ranged = true,
		shout = true,
	},
	opening_cut_bonus_chance = 0.25,
}

function _critical_family.opening_cut_template(BS)
	return {
		class_name = "buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		start_func = function(template_data, template_context)
			local state = {
				seen = setmetatable({}, { __mode = "k" }),
			}
			template_data.opening_cut_state = state
			_critical_family.opening_states[template_context.unit] = state
		end,
		stop_func = function(template_data, template_context)
			if _critical_family.opening_states[template_context.unit]
				== template_data.opening_cut_state then
				_critical_family.opening_states[template_context.unit] = nil
			end
		end,
	}
end

function _critical_family.weakpoint_cartography_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and params.hit_weakspot == true
				and (params.actual_damage_dealt or 0) > 0
		end,
		proc_func = function(params, template_data, template_context, t)
			local extension = template_context.buff_extension
			if extension
				and type(extension.add_internally_controlled_buff) == "function" then
				extension:add_internally_controlled_buff(
					"pilgrim_weakpoint_cartography_effect", t)
			end
		end,
	}
end

function _critical_family.failure_analysis_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		start_func = function(template_data)
			template_data.clear_stacks_after = nil
			template_data.stack_count = 0
		end,
		update_func = function(template_data, template_context, dt, t)
			-- Damage is calculated before on_hit. Delaying the clear until the
			-- next fixed update lets every pellet or cleave target belonging to
			-- the consuming critical attack receive the same damage bonus.
			local clear_after = template_data.clear_stacks_after
			if clear_after ~= nil and t > clear_after then
				template_data.stack_count = 0
				template_data.clear_stacks_after = nil
			end
		end,
		stat_buffs = {
			[BS.stat_buffs.critical_strike_chance] = 0.05,
			[BS.stat_buffs.critical_strike_damage] = 0.10,
		},
		stat_buff_multiplier = function(template_data)
			return template_data.stack_count or 0
		end,
		visual_stack_count = function(template_data)
			return template_data.stack_count or 0
		end,
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and (params.actual_damage_dealt or 0) > 0
				and (params.is_critical_strike == true
					or params.hit_weakspot == true)
		end,
		proc_func = function(params, template_data, template_context, t)
			if params.is_critical_strike == true then
				template_data.clear_stacks_after = t
			elseif params.hit_weakspot == true
				and template_data.clear_stacks_after == nil then
				template_data.stack_count = math.min(6,
					(template_data.stack_count or 0) + 1)
			end
		end,
	}
end

local function _wrecking_rhythm_template(BS)
	local sweep_start = assert(BS.proc_events.on_sweep_start,
		"missing proc event: on_sweep_start")
	local sweep_finish = assert(BS.proc_events.on_sweep_finish,
		"missing proc event: on_sweep_finish")
	local proc_events = { [sweep_start] = 1, [sweep_finish] = 1 }
	local specific = {}
	specific[sweep_start] = function(params, template_data)
		if params.is_heavy then
			template_data.heavy_count = (template_data.heavy_count or 0) + 1
			template_data.empowered = template_data.heavy_count % 3 == 0
		else
			template_data.heavy_count = 0
			template_data.empowered = false
		end
	end
	specific[sweep_finish] = function(params, template_data)
		template_data.empowered = false
	end
	local wield_melee = BS.proc_events.on_wield_melee
	if wield_melee then
		proc_events[wield_melee] = 1
		specific[wield_melee] = function(params, template_data)
			template_data.heavy_count = 0
			template_data.empowered = false
		end
	end
	return {
		class_name = "proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = proc_events,
		conditional_stat_buffs = {
			[BS.stat_buffs.max_hit_mass_attack_modifier] = 0.40,
			[BS.stat_buffs.melee_impact_modifier] = 0.40,
		},
		conditional_stat_buffs_func = function(template_data)
			return template_data.empowered == true
		end,
		check_active_func = function(template_data)
			return template_data.empowered == true
		end,
		specific_proc_func = specific,
	}
end

-- Goliath's offensive package is deliberately action-scoped. Darktide emits a
-- sweep event for melee swings, including melee actions performed while a
-- ranged weapon is wielded. Push attacks need one extra piece of state: the
-- game's own Zealot talent identifies them as the sweep which immediately
-- interrupts a completed push, so this template mirrors that native sequence.
local function _goliath_template(BS)
	local sweep_start = assert(BS.proc_events.on_sweep_start,
		"missing proc event: on_sweep_start")
	local sweep_finish = assert(BS.proc_events.on_sweep_finish,
		"missing proc event: on_sweep_finish")
	local push_finish = assert(BS.proc_events.on_push_finish,
		"missing proc event: on_push_finish")
	local action_finish = assert(BS.proc_events.on_action_finish,
		"missing proc event: on_action_finish")
	local proc_events = {
		[sweep_start] = 1,
		[sweep_finish] = 1,
		[push_finish] = 1,
		[action_finish] = 1,
	}
	local specific = {}

	specific[push_finish] = function(params, template_data)
		template_data.push_completed = true
	end
	specific[action_finish] = function(params, template_data)
		if template_data.push_completed then
			template_data.push_attack_ready = params.reason == "new_interrupting_action"
		else
			template_data.push_attack_ready = false
		end
		template_data.push_completed = false
	end
	specific[sweep_start] = function(params, template_data)
		local inventory = template_data.inventory_component
		local ranged_weapon_melee = inventory ~= nil
			and inventory.wielded_slot == "slot_secondary"
		template_data.empowered = params.is_heavy == true
			or template_data.push_attack_ready == true
			or ranged_weapon_melee
		template_data.push_attack_ready = false
	end
	specific[sweep_finish] = function(params, template_data)
		template_data.empowered = false
	end

	return {
		class_name = "proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = true,
		proc_events = proc_events,
		start_func = function(template_data, template_context)
			template_data.empowered = false
			template_data.push_completed = false
			template_data.push_attack_ready = false
			local unit_data_extension = ScriptUnit.extension(
				template_context.unit, "unit_data_system")
			template_data.inventory_component =
				unit_data_extension:read_component("inventory")
		end,
		stat_buffs = {
			[BS.stat_buffs.melee_attack_speed] = -0.10,
			[BS.stat_buffs.ranged_damage] = -0.50,
		},
		conditional_stat_buffs = {
			-- Generic action buckets are intentional. The short active window
			-- means ordinary gunfire cannot inherit them, while secondary effects
			-- belonging to a weapon melee action, such as the Gauntlet punch's
			-- explosion, can inherit the complete Goliath package.
			[BS.stat_buffs.damage] = 0.30,
			[BS.stat_buffs.impact_modifier] = 0.50,
			[BS.stat_buffs.max_hit_mass_attack_modifier] = 0.35,
		},
		conditional_stat_buffs_func = function(template_data)
			return template_data.empowered == true
		end,
		specific_proc_func = specific,
	}
end

-- Sprint attacks begin as ordinary melee sweeps, then spend their stamina and
-- leave the sprint state before the hit is resolved. These weak-key markers
-- preserve only the active sweep, without keeping player units alive after a
-- mission. The Attack.execute hook below reads Juggernaut's marker early enough
-- to turn the original melee hit into an execute, rather than dealing a second
-- synthetic hit after the fact.
local _juggernaut_sprint_sweeps = setmetatable({}, { __mode = "k" })

function _unstoppable_family.is_sprinting(template_data)
	local state = template_data.sprint_character_state
	return state ~= nil
		and (state.is_sprinting == true or state.is_sprint_jumping == true)
end

local function _reset_sprint_charge(template_data)
	template_data.sprint_time = 0
	template_data.charged = false
	template_data.empowered = false
	template_data.attack_committed = false
end

local function _sprint_boon_template(BS, boon_kind)
	local sweep_start = assert(BS.proc_events.on_sweep_start,
		"missing proc event: on_sweep_start")
	local sweep_finish = assert(BS.proc_events.on_sweep_finish,
		"missing proc event: on_sweep_finish")
	local proc_events = { [sweep_start] = 1, [sweep_finish] = 1 }
	local specific = {}

	specific[sweep_start] = function(params, template_data, template_context)
		local sprinting = _unstoppable_family.is_sprinting(template_data)
		if boon_kind == "terminal_velocity" then
			template_data.empowered = params.is_heavy == true
				and sprinting and template_data.charged == true
			template_data.attack_committed = sprinting
		elseif boon_kind == "juggernauts_wake" then
			template_data.empowered = sprinting
			template_data.attack_committed = sprinting
			if sprinting then
				_juggernaut_sprint_sweeps[template_context.unit] = true
			end
		end
	end

	specific[sweep_finish] = function(params, template_data, template_context)
		if boon_kind == "juggernauts_wake" then
			_juggernaut_sprint_sweeps[template_context.unit] = nil
		end
		_reset_sprint_charge(template_data)
	end

	local stat_buffs
	if boon_kind == "terminal_velocity" then
		stat_buffs = {
			[BS.stat_buffs.melee_power_level_modifier] = 0.60,
			[BS.stat_buffs.melee_impact_modifier] = 1.00,
			[BS.stat_buffs.max_hit_mass_attack_modifier] = 0.75,
		}
	else
		-- Cleave and impact are calculated once for the whole sweep, before an
		-- individual target is known. Applying this fallback to the sprint sweep
		-- is harmless for allowlisted enemies because the same hit executes them.
		stat_buffs = {
			[BS.stat_buffs.melee_power_level_modifier] = 0.40,
			[BS.stat_buffs.melee_impact_modifier] = 0.40,
			[BS.stat_buffs.max_hit_mass_attack_modifier] = 0.40,
		}
	end

	return {
		class_name = "proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = proc_events,
		start_func = function(template_data, template_context)
			local unit_data = ScriptUnit.has_extension(
				template_context.unit, "unit_data_system")
			template_data.sprint_character_state = unit_data
				and unit_data:read_component("sprint_character_state") or nil
			template_data.was_sprinting = false
			_reset_sprint_charge(template_data)
		end,
		stop_func = function(template_data, template_context)
			if boon_kind == "juggernauts_wake" then
				_juggernaut_sprint_sweeps[template_context.unit] = nil
			end
			_reset_sprint_charge(template_data)
		end,
		update_func = function(template_data, template_context, dt)
			local sprinting = _unstoppable_family.is_sprinting(template_data)
			if sprinting then
				if not template_data.was_sprinting then
					template_data.sprint_time = 0
				end
				template_data.sprint_time = (template_data.sprint_time or 0) + dt
				if boon_kind == "terminal_velocity"
					and template_data.sprint_time >= 2 then
					template_data.charged = true
				end
			elseif not template_data.attack_committed then
				_reset_sprint_charge(template_data)
				if boon_kind == "juggernauts_wake" then
					_juggernaut_sprint_sweeps[template_context.unit] = nil
				end
			end
			template_data.was_sprinting = sprinting
		end,
		conditional_stat_buffs = stat_buffs,
		conditional_stat_buffs_func = function(template_data)
			return template_data.empowered == true
		end,
		check_active_func = function(template_data)
			return template_data.empowered == true
		end,
		specific_proc_func = specific,
	}
end

-- Afflictor needs ways to begin and then develop its less common status lanes.
-- These controllers deliberately reuse Darktide's native Bleed, Toxin,
-- Brittleness and Taunt templates. Per-target state lives in weak Lua tables on
-- the owning boon, so no synchronized target buff is added merely as a
-- cooldown marker and dead enemies clean themselves out of the table.
local _afflictor_family = {}

function _afflictor_family.direct_damage(params)
	return params.attacked_unit ~= nil
		and params.attack_type ~= "buff"
		and (tonumber(params.actual_damage_dealt) or 0) > 0
end

function _afflictor_family.open_vein_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		start_func = function(template_data)
			template_data.opened = setmetatable({}, { __mode = "k" })
		end,
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and _afflictor_family.direct_damage(params)
				and not template_data.opened[params.attacked_unit]
		end,
		proc_func = function(params, template_data, template_context, t)
			local target = params.attacked_unit
			-- Mark only after the native Bleed application succeeds. A temporary
			-- missing target extension can therefore be retried by the next hit.
			if _apply_ailment_stacks(target, "bleed", 3, t,
					template_context.unit) then
				template_data.opened[target] = true
			end
		end,
	}
end

function _afflictor_family.toxic_primer_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		start_func = function(template_data)
			template_data.ready_at = 0
		end,
		check_proc_func = function(params, template_data, template_context, t)
			return template_context.is_server
				and t >= (template_data.ready_at or 0)
				and _afflictor_family.direct_damage(params)
		end,
		proc_func = function(params, template_data, template_context, t)
			if _apply_ailment_stacks(params.attacked_unit,
					"neurotoxin_interval_buff3", 4, t,
					template_context.unit) then
				template_data.ready_at = t + 10
			end
		end,
	}
end

function _afflictor_family.hairline_fracture_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_push_hit] = 1 },
		proc_func = function(params, template_data, template_context, t)
			if not template_context.is_server then return end
			-- Native rending_debuff is 2.5% Brittleness per stack for 5s.
			_apply_ailment_stacks(params.pushed_unit, "rending_debuff", 4, t,
				template_context.unit)
		end,
	}
end

function _afflictor_family.fighting_words_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_push_hit] = 1 },
		proc_func = function(params, template_data, template_context, t)
			if not template_context.is_server then return end
			local target = params.pushed_unit
			if not target or not HEALTH_ALIVE[target] then return end
			local unit_data = ScriptUnit.has_extension(target, "unit_data_system")
			local breed = unit_data and unit_data:breed()
			if breed and breed.tags and breed.tags.monster then return end
			local extension = ScriptUnit.has_extension(target, "buff_system")
			if extension and not extension:has_keyword(BS.keywords.taunted) then
				extension:add_internally_controlled_buff("taunted_short", t,
					"owner_unit", template_context.unit)
			end
		end,
	}
end

function _afflictor_family.blood_trail_template(BS)
	local bleed_tokens, bleed_damage = _resolve_ailment_tokens(BS,
		{ "bleeding" })
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_minion_death] = 1 },
		check_proc_func = function(params, template_data, template_context)
			return template_context.is_server
				and params.attacking_unit == template_context.unit
				and _death_has_ailment(params, bleed_tokens, bleed_damage)
		end,
		proc_func = function(params, template_data, template_context, t)
			local corpse = params.dying_unit or params.attacked_unit
			local origin = params.position or (corpse and POSITION_LOOKUP[corpse])
			local spread = 0
			_for_each_enemy_at_position(template_context.unit, origin, 5, corpse,
				function(target)
					if spread >= 5 then return end
					if _apply_ailment_stacks(target, "bleed", 4, t,
							template_context.unit) then
						spread = spread + 1
					end
				end)
		end,
	}
end

function _afflictor_family.corrosive_compound_template(BS)
	local toxin = BS.keywords.toxin
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		start_func = function(template_data)
			template_data.ready_at = setmetatable({}, { __mode = "k" })
		end,
		check_proc_func = function(params, template_data, template_context, t)
			if not template_context.is_server
				or not _afflictor_family.direct_damage(params)
				or t < (template_data.ready_at[params.attacked_unit] or 0) then
				return false
			end
			local extension = ScriptUnit.has_extension(params.attacked_unit,
				"buff_system")
			return extension ~= nil and toxin ~= nil
				and extension:has_keyword(toxin)
		end,
		proc_func = function(params, template_data, template_context, t)
			local target = params.attacked_unit
			-- Eight native stacks equal 20% Brittleness for five seconds.
			if _apply_ailment_stacks(target, "rending_debuff", 8, t,
					template_context.unit) then
				template_data.ready_at[target] = t + 5
			end
		end,
	}
end

function _afflictor_family.salt_the_wound_template(BS)
	local bleed_tokens = _resolve_ailment_tokens(BS, { "bleeding" })
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		start_func = function(template_data)
			template_data.ready_at = setmetatable({}, { __mode = "k" })
		end,
		check_proc_func = function(params, template_data, template_context, t)
			if not template_context.is_server
				or not _afflictor_family.direct_damage(params)
				or t < (template_data.ready_at[params.attacked_unit] or 0) then
				return false
			end
			local extension = ScriptUnit.has_extension(params.attacked_unit,
				"buff_system")
			return _extension_has_any_keyword(extension, bleed_tokens)
		end,
		proc_func = function(params, template_data, template_context, t)
			local target = params.attacked_unit
			local extension = ScriptUnit.has_extension(target, "buff_system")
			if extension and pcall(extension.add_internally_controlled_buff,
					extension, "pilgrim_afflictor_exposed", t,
					"owner_unit", template_context.unit) then
				template_data.ready_at[target] = t + 5
			end
		end,
	}
end

function _afflictor_family.insult_to_injury_template(BS)
	local affliction_tokens = _resolve_ailment_tokens(BS, {
		"burning", "warpfire_burning", "electrocuted", "bleeding",
		"toxin", "taunted",
	})
	local function already_afflicted(extension)
		if _extension_has_any_keyword(extension, affliction_tokens) then
			return true
		end
		if not extension or type(extension.stat_buffs) ~= "function" then
			return false
		end
		local ok, stat_buffs = pcall(extension.stat_buffs, extension)
		if not ok or type(stat_buffs) ~= "table" then return false end
		return (tonumber(stat_buffs.rending_multiplier) or 1) > 1
			or (tonumber(stat_buffs.damage_taken_modifier) or 1) > 1
			or (tonumber(stat_buffs.damage_taken_multiplier) or 1) > 1
	end
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_push_hit] = 1 },
		start_func = function(template_data)
			template_data.ready_at = setmetatable({}, { __mode = "k" })
		end,
		proc_func = function(params, template_data, template_context, t)
			if not template_context.is_server then return end
			local target = params.pushed_unit
			if not target or t < (template_data.ready_at[target] or 0) then return end
			local extension = ScriptUnit.has_extension(target, "buff_system")
			if not extension then return end
			-- Read the target before adding Bleed. A clean target receives the
			-- self-starting Bleed package; any existing Afflictor category also
			-- earns Toxin from the same push.
			local add_toxin = already_afflicted(extension)
			local bleed = _apply_ailment_stacks(target, "bleed", 4, t,
				template_context.unit)
			local toxin = add_toxin and _apply_ailment_stacks(target,
				"neurotoxin_interval_buff3", 4, t, template_context.unit) or false
			if bleed or toxin then template_data.ready_at[target] = t + 5 end
		end,
	}
end

-- ===========================================================================
-- v0.26.0 (Boons v2 Wave A): PILGRIMAGE FAMILY BOONS.
-- ===========================================================================
--
-- These are drafted during a run. They are deliberately separate from
-- M.CUSTOM, whose entries are permanent Ordos-purchased Doctrines. The
-- descriptions are menu copy, not design notes: one quick sentence each.

M.FAMILY_BOONS = {
	{
		id = "pilgrim_family_kindling",
		buff_template = "pilgrim_family_kindling",
		family = "fire",
		draft_tags = { "debuff" },
		tier = "minoris",
		name = "Kindling",
		description = "Burn and soulfire deal 10% more damage.",
		short = "+10% fire damage",
		custom = {
			stat_buffs = { burning_damage = 0.10 },
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_burning_on_melee_hit",
		},
	},
	{
		id = "pilgrim_family_long_burn",
		buff_template = "pilgrim_family_long_burn",
		family = "fire",
		draft_tags = { "debuff" },
		tier = "minoris",
		name = "Long Burn",
		description = "Burn and soulfire last 30% longer.",
		short = "+30% fire duration",
		custom = {
			stat_buffs = { burning_duration = 0.30 },
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_burning_on_melee_hit",
		},
	},
	{
		id = "pilgrim_family_hot_blood",
		buff_template = "pilgrim_family_hot_blood",
		family = "fire",
		draft_tags = { "debuff" },
		tier = "minoris",
		name = "Hot Blood",
		description = "Burning enemy kills grant +5% move speed for 3s. Stacks 3 times.",
		short = "fire kill: move speed",
		custom = {
			template = _ailment_kill_timed_template("pilgrim_hot_blood_effect",
				{ "burning", "warpfire_burning" }),
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_burning_damage_per_burning_enemy",
		},
	},
	{
		id = "pilgrim_family_cinder_touch",
		buff_template = "pilgrim_family_cinder_touch",
		family = "fire",
		draft_tags = { "debuff" },
		tier = "minoris",
		name = "Cinder Touch",
		description = "Melee weakspot hits apply 1 burn stack per target each second.",
		short = "weakspot hit: burn",
		custom = {
			template = _cinder_touch_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_burning_on_melee_hit",
		},
	},
	{
		id = "pilgrim_family_pyre_tithe",
		buff_template = "pilgrim_family_pyre_tithe",
		family = "fire",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Pyre Tithe",
		description = "Burning enemy kills replenish 2% toughness.",
		short = "fire kill: +2% toughness",
		custom = {
			template = _pyre_tithe_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_toughness_on_fire_damage_dealt",
		},
	},
	{
		id = "pilgrim_family_flashover",
		buff_template = "pilgrim_family_flashover",
		family = "fire",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Flashover",
		description = "20 combined fire stacks erupt for 10% max health and spread both fires.",
		short = "20 fire stacks: eruption",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_burning_damage_per_burning_enemy",
		},
	},
	{
		id = "pilgrim_family_backdraft",
		buff_template = "pilgrim_family_backdraft",
		family = "fire",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Backdraft",
		description = "Burning enemy kills have a 25% chance to ignite the nearest enemy.",
		short = "fire kill: spread ignition",
		custom = {
			template = _backdraft_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_burning_on_melee_hit",
		},
	},
	{
		id = "pilgrim_family_fireproofed",
		buff_template = "pilgrim_family_fireproofed",
		family = "fire",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Fireproofed",
		description = "Take 50% less damage while burning, soulfired, or standing in fire.",
		short = "in fire: halve damage",
		custom = {
			template = _fireproofed_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_damage_taken_by_flamers_and_grenadier_reduced",
		},
	},
	{
		id = "pilgrim_family_grounded",
		buff_template = "pilgrim_family_grounded",
		family = "electric",
		draft_tags = { "debuff" },
		tier = "minoris",
		name = "Grounded",
		description = "Gain 20% rending against electrocuted enemies.",
		short = "+20% shock rending",
		custom = {
			stat_buffs = { rending_vs_electrocuted_multiplier = 0.20 },
				hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_extra_ability_charge",
		},
	},
	{
		id = "pilgrim_family_ion_wake",
		buff_template = "pilgrim_family_ion_wake",
		family = "electric",
		draft_tags = { "debuff" },
		tier = "minoris",
		name = "Ion Wake",
		description = "Dodging a melee attack shocks the attacker. 3s cooldown.",
		short = "melee dodge: shock",
		custom = {
			template = _ion_wake_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_extra_ability_charge",
		},
	},
	{
		id = "pilgrim_family_residual_charge",
		buff_template = "pilgrim_family_residual_charge",
		family = "electric",
		draft_tags = { "debuff" },
		tier = "minoris",
		name = "Residual Charge",
		description = "Electrocution you apply lasts 25% longer.",
		short = "+25% shock duration",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_damage_vs_electrocuted",
		},
	},
	{
		id = "pilgrim_family_copper_nerves",
		buff_template = "pilgrim_family_copper_nerves",
		family = "electric",
		draft_tags = { "debuff" },
		tier = "minoris",
		name = "Copper Nerves",
		description = "Within 8m of an electrocuted enemy, gain +10% toughness replenishment.",
		short = "near shock: toughness recovery",
		custom = {
			template = _nearby_ailment_template("toughness_replenish_modifier",
				0.10, { "electrocuted" }, 1),
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_extra_toughness_near_burning_shocked_enemies",
		},
	},
	{
		id = "pilgrim_family_faraday_soul",
		buff_template = "pilgrim_family_faraday_soul",
		family = "electric",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Faraday Soul",
		description = "Within 8m of 3 electrocuted enemies, take 20% less damage.",
		short = "3 nearby shocks: -20% damage",
		custom = {
			template = _nearby_ailment_template("damage_taken_modifier",
				-0.20, { "electrocuted" }, 3),
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_damage_taken_close_to_electrocuted_enemy",
		},
	},
	{
		id = "pilgrim_family_livewire",
		buff_template = "pilgrim_family_livewire",
		family = "electric",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Livewire",
		description = "Critical melee hits shock the target.",
		short = "melee crit: shock",
		custom = {
			template = _livewire_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_extra_ability_charge",
		},
	},
	{
		id = "pilgrim_family_closed_circuit",
		buff_template = "pilgrim_family_closed_circuit",
		family = "electric",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Closed Circuit",
		description = "Direct hits arc 25% damage to another shocked enemy within 8m.",
		short = "shocked hits arc 25%",
		custom = {
			template = _closed_circuit_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_extra_ability_charge",
		},
	},
	{
		id = "pilgrim_family_capacitance_feedback",
		buff_template = "pilgrim_family_capacitance_feedback",
		family = "electric",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Capacitance Feedback",
		description = "Nearby electrocuted enemy deaths refund 3% combat ability cooldown.",
		short = "near shock death: ability refund",
		custom = {
			template = _capacitance_feedback_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_extra_ability_charge",
		},
	},
	{
		id = "pilgrim_family_elemental_affinity",
		buff_template = "pilgrim_family_elemental_affinity",
		family = "elementalist",
		draft_tags = { "fire", "electric", "debuff" },
		tier = "minoris",
		name = "Elemental Affinity",
		description = "Deal 10% more damage to burning, soulfired, or electrocuted targets.",
		short = "+10% vs elemental ailments",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_burning_on_melee_hit",
		},
	},
	{
		id = "pilgrim_family_mixed_medium",
		buff_template = "pilgrim_family_mixed_medium",
		family = "elementalist",
		draft_tags = { "fire", "electric", "debuff" },
		tier = "minoris",
		name = "Mixed Medium",
		description = "Your burn, soulfire, bleed and electrocution last 10% longer.",
		short = "+10% ailment duration",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/buff_families/hordes_buff_family_elementalist",
		},
	},
	{
		id = "pilgrim_family_catalyst",
		buff_template = "pilgrim_family_catalyst",
		family = "elementalist",
		-- Both elements must already be available, so single-element
		-- Archetypes cannot draft this card.
		draft_tags = { "debuff" },
		tier = "minoris",
		name = "Catalyst",
		description = "Mixing fire and shock applies the new ailment twice more. 2s cooldown.",
		short = "mix elements: 2 more applications",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_shock_on_melee_hit",
		},
	},
	{
		id = "pilgrim_family_reactive_chemistry",
		buff_template = "pilgrim_family_reactive_chemistry",
		family = "elementalist",
		draft_tags = { "fire", "electric", "debuff" },
		tier = "minoris",
		name = "Reactive Chemistry",
		description = "Ailment kills grant +10% reload and melee attack speed for 3s.",
		short = "ailment kill: combat speed",
		custom = {
			template = _ailment_kill_timed_template(
				"pilgrim_reactive_chemistry_effect",
				{ "burning", "warpfire_burning", "bleeding", "electrocuted" }),
				hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_improved_weapon_reload_on_melee_kill",
		},
	},
	{
		id = "pilgrim_family_entropy_feast",
		buff_template = "pilgrim_family_entropy_feast",
		family = "elementalist",
		draft_tags = { "fire", "electric", "debuff" },
		tier = "majoris",
		name = "Entropy Feast",
		description = "Gain +10% attack speed per enemy within 8m suffering damage over time.",
		short = "nearby ailments: attack speed",
		custom = {
			template = _entropy_feast_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_burning_damage_per_burning_enemy",
		},
	},
	{
		id = "pilgrim_family_prism_of_ruin",
		buff_template = "pilgrim_family_prism_of_ruin",
		family = "elementalist",
		draft_tags = { "fire", "electric", "debuff" },
		tier = "majoris",
		name = "Prism of Ruin",
		description = "Every 15s, your next damaging hit applies 3 burn, 3 bleed, and 2 shock.",
		short = "timed hit: three ailments",
		custom = {
			template = _prism_of_ruin_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_burning_on_melee_hit",
		},
	},
	{
		id = "pilgrim_family_thermal_shock",
		buff_template = "pilgrim_family_thermal_shock",
		family = "elementalist",
		-- Requires both fire and shock to be present, so it belongs to the
		-- debuff specialist but neither single-element Archetype.
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Thermal Shock",
		description = "Mix fire and shock: heavy stagger and 20% brittleness for 6s. 12s cooldown.",
		short = "mix elements: stagger, brittle",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_burning_on_melee_hit",
		},
	},
	{
		id = "pilgrim_family_conduction",
		buff_template = "pilgrim_family_conduction",
		family = "elementalist",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Conduction",
		description = "Mixing fire and shock deals 10% max health damage. 15s cooldown.",
		short = "mix elements: 10% health",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_grenade_explosion_applies_elemental_weakness",
		},
	},
	{
		id = "pilgrim_family_open_vein",
		buff_template = "pilgrim_family_open_vein",
		family = "elementalist",
		draft_tags = { "debuff" },
		tier = "minoris",
		name = "Open Vein",
		description = "Your first damaging hit on each enemy applies 3 Bleed.",
		short = "first hit: 3 bleed",
		custom = {
			template = _afflictor_family.open_vein_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_bleeding_and_burning_on_melee_hit",
		},
	},
	{
		id = "pilgrim_family_toxic_primer",
		buff_template = "pilgrim_family_toxic_primer",
		family = "elementalist",
		draft_tags = { "debuff" },
		tier = "minoris",
		name = "Toxic Primer",
		description = "Every 10s, your next damaging hit applies 4 Toxin.",
		short = "timed hit: 4 toxin",
		custom = {
			template = _afflictor_family.toxic_primer_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_broker_tox_grenade_applies_self_propagating_toxin",
		},
	},
	{
		id = "pilgrim_family_hairline_fracture",
		buff_template = "pilgrim_family_hairline_fracture",
		family = "elementalist",
		draft_tags = { "debuff" },
		tier = "minoris",
		name = "Fault Line",
		description = "Pushes apply 10% Brittleness for 5s.",
		short = "push: 10% brittleness",
		custom = {
			template = _afflictor_family.hairline_fracture_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_grenade_explosion_applies_rending_debuff",
		},
	},
	{
		id = "pilgrim_family_fighting_words",
		buff_template = "pilgrim_family_fighting_words",
		family = "unkillable",
		draft_tags = { "bulwark" },
		tier = "minoris",
		name = "Fighting Words",
		description = "Pushes Taunt non-Monstrosity enemies for 8s.",
		short = "push: 8s taunt",
		custom = {
			template = _afflictor_family.fighting_words_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_ogryn_taunt_on_lunge",
		},
	},
	{
		id = "pilgrim_family_blood_trail",
		buff_template = "pilgrim_family_blood_trail",
		family = "elementalist",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Blood Trail",
		description = "Bleeding kills spread 4 Bleed to up to 5 enemies within 5m.",
		short = "bleed kill: spread bleed",
		custom = {
			template = _afflictor_family.blood_trail_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_veteran_apply_infinite_bleed_on_shout",
		},
	},
	{
		id = "pilgrim_family_corrosive_compound",
		buff_template = "pilgrim_family_corrosive_compound",
		family = "elementalist",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Corrosive Compound",
		description = "Hitting a Toxined enemy applies 20% Brittleness for 5s. 5s cooldown.",
		short = "toxin hit: 20% brittle",
		custom = {
			template = _afflictor_family.corrosive_compound_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_grenade_explosion_applies_rending_debuff",
		},
	},
	{
		id = "pilgrim_family_salt_the_wound",
		buff_template = "pilgrim_family_salt_the_wound",
		family = "elementalist",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Salt the Wound",
		description = "Hitting a Bleeding enemy Exposes it to +15% damage for 5s. 5s cooldown.",
		short = "bleed hit: +15% exposed",
		custom = {
			template = _afflictor_family.salt_the_wound_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_grenade_explosion_applies_elemental_weakness",
		},
	},
	{
		id = "pilgrim_family_insult_to_injury",
		buff_template = "pilgrim_family_insult_to_injury",
		family = "elementalist",
		draft_tags = { "debuff" },
		tier = "majoris",
		name = "Insult to Injury",
		description = "Pushes apply 4 Bleed; afflicted enemies also gain 4 Toxin. 5s cooldown.",
		short = "push: bleed, then toxin",
		custom = {
			template = _afflictor_family.insult_to_injury_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_ogryn_taunt_on_lunge",
		},
	},
	{
		id = "pilgrim_family_thick_hide",
		buff_template = "pilgrim_family_thick_hide",
		family = "unkillable",
		tier = "minoris",
		name = "Thick Hide",
		description = "Take 10% less toughness damage.",
		short = "-10% toughness damage",
		custom = {
			stat_buffs = { toughness_damage_taken_modifier = -0.10 },
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_toughness_increase",
		},
	},
	{
		id = "pilgrim_family_second_wind",
		buff_template = "pilgrim_family_second_wind",
		family = "unkillable",
		tier = "minoris",
		name = "Second Wind",
		description = "Toughness regeneration starts 30% sooner.",
		short = "-30% regen delay",
		custom = {
			stat_buffs = { toughness_regen_delay_modifier = -0.30 },
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_toughness_increase",
		},
	},
	{
		id = "pilgrim_family_hard_to_finish",
		buff_template = "pilgrim_family_hard_to_finish",
		family = "unkillable",
		tier = "minoris",
		name = "Hard to Finish",
		description = "Below 33% health, receive 20% more healing.",
		short = "+20% low-health healing",
		custom = {
			template = _health_threshold_template("healing_recieved_modifier", 0.20),
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_health_regen",
		},
	},
	{
		id = "pilgrim_family_last_reserve",
		buff_template = "pilgrim_family_last_reserve",
		family = "unkillable",
		tier = "minoris",
		name = "Last Reserve",
		description = "Below 33% health, replenish 20% more toughness.",
		short = "+20% low-health toughness",
		custom = {
			template = _health_threshold_template("toughness_replenish_modifier", 0.20),
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_toughness_coherency_regen_increase",
		},
	},
	{
		id = "pilgrim_family_brace_for_it",
		buff_template = "pilgrim_family_brace_for_it",
		family = "unkillable",
		tier = "minoris",
		name = "Brace for It",
		description = "Blocking restores 10% toughness. 3s cooldown.",
		short = "block: +10% toughness",
		custom = {
			template = _brace_for_it_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_shock_on_blocking_melee_attack",
		},
	},
	{
		id = "pilgrim_family_grave_refusal",
		buff_template = "pilgrim_family_grave_refusal",
		family = "unkillable",
		tier = "majoris",
		name = "Grave Refusal",
		description = "Gain 50% more health while downed.",
		short = "+50% downed health",
		custom = {
			stat_buffs = { knocked_down_health_modifier = 0.50 },
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_toughness_increase",
		},
	},
	{
		id = "pilgrim_family_stone_covenant",
		buff_template = "pilgrim_family_stone_covenant",
		family = "unkillable",
		tier = "majoris",
		name = "Stone Covenant",
		description = "+40% max health, but 30% less healing received.",
		short = "+40% health, -30% healing",
		custom = {
			stat_buffs = {
				max_health_multiplier = 1.40,
				-- Fatshark's published stat key is misspelled "recieved".
				healing_recieved_modifier = -0.30,
			},
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_toughness_increase",
		},
	},
	{
		id = "pilgrim_family_refusal_response",
		buff_template = "pilgrim_family_refusal_response",
		family = "unkillable",
		tier = "majoris",
		name = "Refusal Response",
		description = "Health damage restores 30% toughness and halves toughness damage for 3s. CD 12s.",
		short = "health hit: toughness guard",
		custom = {
			template = _refusal_response_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_toughness_increase",
		},
	},
	{
		id = "pilgrim_family_quick_hands",
		buff_template = "pilgrim_family_quick_hands",
		family = "cowboy",
		tier = "minoris",
		name = "Quick Hands",
		description = "Reload 15% faster.",
		short = "+15% reload speed",
		custom = {
			stat_buffs = { reload_speed = 0.15 },
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_damage_taken_by_flamers_and_grenadier_reduced",
		},
	},
	{
		id = "pilgrim_family_deep_pockets",
		buff_template = "pilgrim_family_deep_pockets",
		family = "cowboy",
		tier = "minoris",
		name = "Deep Pockets",
		description = "Carry 20% more ammunition.",
		short = "+20% ammo reserve",
		custom = {
			stat_buffs = { ammo_reserve_capacity = 0.20 },
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_damage_taken_by_flamers_and_grenadier_reduced",
		},
	},
	{
		id = "pilgrim_family_clean_holster",
		buff_template = "pilgrim_family_clean_holster",
		family = "cowboy",
		tier = "minoris",
		name = "Clean Holster",
		description = "Ranged weakspot kills grant +20% weapon-swap speed for 4s.",
		short = "headshot kill: faster swap",
		custom = {
			template = _timed_trigger_template("pilgrim_clean_holster_effect",
				"on_kill", function(params, template_context)
					return params.attacking_unit == template_context.unit
						and params.attack_type == "ranged"
						and params.hit_weakspot == true
				end),
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_reduce_swap_time",
		},
	},
	{
		id = "pilgrim_family_moving_target",
		buff_template = "pilgrim_family_moving_target",
		family = "cowboy",
		tier = "minoris",
		name = "Moving Target",
		description = "Deal 10% more ranged damage while moving normally.",
		short = "+10% ranged while moving",
		custom = {
			template = _movement_state_template(_is_moving_normally, 0.10),
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_no_movement_speed_reduction_on_aim_and_windup",
		},
	},
	{
		id = "pilgrim_family_first_to_draw",
		buff_template = "pilgrim_family_first_to_draw",
		family = "cowboy",
		tier = "minoris",
		name = "First to Draw",
		description = "Drawing your ranged weapon grants +15% attack speed for 2s. Cooldown: 5s.",
		short = "draw: faster fire",
		custom = {
			template = _first_to_draw_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_reduce_swap_time",
		},
	},
	{
		id = "pilgrim_family_deadeye_drift",
		buff_template = "pilgrim_family_deadeye_drift",
		family = "cowboy",
		tier = "majoris",
		name = "Deadeye Drift",
		description = "Deal 25% more ranged damage while dodging or sliding.",
		short = "+25% ranged while dodging",
		custom = {
			template = _movement_state_template(_is_dodging_or_sliding, 0.25),
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_no_movement_speed_reduction_on_aim_and_windup",
		},
	},
	{
		id = "pilgrim_family_fan_the_hammer",
		buff_template = "pilgrim_family_fan_the_hammer",
		family = "cowboy",
		tier = "majoris",
		name = "Fan the Hammer",
		description = "Ranged kills grant +20% ranged attack speed for 3s.",
		short = "ranged kill: faster fire",
		custom = {
			template = _timed_trigger_template("pilgrim_fan_the_hammer_effect",
				"on_kill", function(params, template_context)
					return params.attacking_unit == template_context.unit
						and params.attack_type == "ranged"
				end),
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_no_movement_speed_reduction_on_aim_and_windup",
		},
	},
	{
		id = "pilgrim_family_dead_mans_chamber",
		buff_template = "pilgrim_family_dead_mans_chamber",
		family = "cowboy",
		tier = "majoris",
		name = "Dead Man's Chamber",
		description = "Final-round kills load one +50% damage round. Cooldown: 2s.",
		short = "last-round kill: empowered round",
		custom = {
			template = _dead_mans_chamber_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_no_movement_speed_reduction_on_aim_and_windup",
		},
	},
	{
		id = "pilgrim_family_honed_edge",
		buff_template = "pilgrim_family_honed_edge",
		family = "critical",
		draft_tags = { "executioner" },
		tier = "minoris",
		name = "Honed Edge",
		description = "Melee critical hits deal 20% more damage.",
		short = "+20% melee crit damage",
		custom = {
			stat_buffs = { melee_critical_strike_damage = 0.20 },
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_weakspot_damage_increase",
		},
	},
	{
		id = "pilgrim_family_true_sight",
		buff_template = "pilgrim_family_true_sight",
		family = "critical",
		tier = "minoris",
		name = "True Sight",
		description = "+5% ranged critical chance.",
		short = "+5% ranged crit",
		custom = {
			stat_buffs = { ranged_critical_strike_chance = 0.05 },
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_weakspot_damage_increase",
		},
	},
	{
		id = "pilgrim_family_measured_violence",
		buff_template = "pilgrim_family_measured_violence",
		family = "critical",
		draft_tags = { "executioner" },
		tier = "minoris",
		name = "Measured Violence",
		description = "Weakspot hits grant +4% weakspot power for 3s. Stacks 5 times; other hits reset.",
		short = "chain weakspots: more power",
		custom = {
			template = _measured_violence_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_weakspot_damage_increase",
		},
	},
	{
		id = "pilgrim_family_opening_cut",
		buff_template = "pilgrim_family_opening_cut",
		family = "critical",
		draft_tags = { "executioner" },
		tier = "minoris",
		name = "Opening Cut",
		description = "First attack against each enemy gains +25% critical chance.",
		short = "first attack: +25% crit",
		custom = {
			template = _critical_family.opening_cut_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_stacking_crit_damage_on_critical_hit",
		},
	},
	{
		id = "pilgrim_family_afterimage",
		buff_template = "pilgrim_family_afterimage",
		family = "critical",
		draft_tags = { "executioner" },
		tier = "minoris",
		name = "Afterimage",
		description = "Critical kills grant +10% dodge distance for 4s.",
		short = "crit kill: longer dodge",
		custom = {
			template = _timed_trigger_template("pilgrim_afterimage_effect",
				"on_kill", function(params, template_context)
					return params.attacking_unit == template_context.unit
						and params.is_critical_strike == true
				end),
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_improved_dodge_speed_and_distance",
		},
	},
	{
		id = "pilgrim_family_weakpoint_cartography",
		buff_template = "pilgrim_family_weakpoint_cartography",
		family = "critical",
		draft_tags = { "executioner" },
		tier = "majoris",
		name = "Weakpoint Cartography",
		description = "Weakspots grant 5% rending for 4s, up to 25%. Critical weakspots stagger.",
		short = "weakspots: rending and stagger",
		custom = {
			template = _critical_family.weakpoint_cartography_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_weakspot_damage_increase",
		},
	},
	{
		id = "pilgrim_family_coup_de_grace",
		buff_template = "pilgrim_family_coup_de_grace",
		family = "critical",
		draft_tags = { "executioner" },
		tier = "majoris",
		name = "Coup de Grace",
		description = "Critical hits execute staggered enemies below 20% health. Excludes bosses.",
		short = "crits execute staggered enemies",
		custom = {
			stat_buffs = {},
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_weakspot_damage_increase",
		},
	},
	{
		id = "pilgrim_family_failure_analysis",
		buff_template = "pilgrim_family_failure_analysis",
		family = "critical",
		draft_tags = { "executioner" },
		tier = "majoris",
		name = "Failure Analysis",
		description = "Non-crit weakspots build +5% crit, up to 30%. Next crit: +10% damage/stack.",
		short = "weakspots build the next crit",
		custom = {
			template = _critical_family.failure_analysis_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_stacking_crit_damage_on_critical_hit",
		},
	},
	{
		id = "pilgrim_family_executioners_rhythm",
		buff_template = "pilgrim_family_executioners_rhythm",
		family = "critical",
		draft_tags = { "executioner" },
		tier = "majoris",
		name = "Executioner's Rhythm",
		description = "Damaging critical hits grant +10% attack speed for 4s. Stacks twice.",
		short = "crits: stacking attack speed",
		custom = {
			template = _timed_trigger_template("pilgrim_executioners_rhythm_effect",
				"on_hit", function(params, template_context)
					return params.attacking_unit == template_context.unit
						and params.is_critical_strike == true
						and (params.actual_damage_dealt or 0) > 0
				end),
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_stacking_crit_damage_on_critical_hit",
		},
	},
	{
		id = "pilgrim_family_iron_cadence",
		buff_template = "pilgrim_family_iron_cadence",
		family = "unstoppable",
		draft_tags = { "executioner" },
		tier = "minoris",
		name = "Iron Cadence",
		description = "Heavy melee attacks gain 15% power.",
		short = "+15% heavy power",
		custom = {
			stat_buffs = { melee_heavy_power_level_modifier = 0.15 },
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_weakspot_damage_increase",
		},
	},
	{
		id = "pilgrim_family_wrecking_rhythm",
		buff_template = "pilgrim_family_wrecking_rhythm",
		family = "unstoppable",
		draft_tags = { "executioner" },
		tier = "majoris",
		name = "Wrecking Rhythm",
		description = "Every third consecutive heavy attack gains +40% cleave and stagger.",
		short = "third heavy: cleave and stagger",
		custom = {
			template = _wrecking_rhythm_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_weakspot_damage_increase",
		},
	},
	{
		id = "pilgrim_family_terminal_velocity",
		buff_template = "pilgrim_family_terminal_velocity",
		family = "unstoppable",
		draft_tags = { "executioner" },
		tier = "majoris",
		name = "Terminal Velocity",
		description = "Sprint 2s: next heavy gains +60% power, +100% impact and +75% cleave.",
		short = "sprint 2s: empowered heavy",
		custom = {
			template = function(BS)
				return _sprint_boon_template(BS, "terminal_velocity")
			end,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_sprinting_staggers",
		},
	},
	{
		id = "pilgrim_family_juggernauts_wake",
		buff_template = "pilgrim_family_juggernauts_wake",
		family = "unstoppable",
		draft_tags = { "executioner" },
		tier = "majoris",
		name = "Juggernaut's Wake",
		description = "Sprint attacks execute ordinary foes; kills restore stamina. +40% vs others.",
		short = "sprint attack: execute or +40%",
		custom = {
			template = function(BS)
				return _sprint_boon_template(BS, "juggernauts_wake")
			end,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_replenish_stamina_from_ranged_or_melee_hit",
		},
	},
	{
		id = "pilgrim_family_force_returned",
		buff_template = "pilgrim_family_force_returned",
		family = "unstoppable",
		draft_tags = { "executioner" },
		tier = "minoris",
		name = "Force Returned",
		description = "Stagger 3 enemies with one melee attack or push: restore 10% Toughness. 3s CD.",
		short = "multi-stagger: toughness",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_toughness_on_melee_kills",
		},
	},
	{
		id = "pilgrim_family_crushing_tempo",
		buff_template = "pilgrim_family_crushing_tempo",
		family = "unstoppable",
		draft_tags = { "executioner" },
		tier = "minoris",
		name = "Crushing Tempo",
		description = "Heavy melee hits grant +5% attack speed for 3s. Stacks 3 times.",
		short = "heavy hits: attack speed",
		custom = {
			template = _unstoppable_family.crushing_tempo_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_windup_is_uninterruptible",
		},
	},
	{
		id = "pilgrim_family_forward_only",
		buff_template = "pilgrim_family_forward_only",
		family = "unstoppable",
		draft_tags = { "executioner" },
		tier = "minoris",
		name = "Forward Only",
		description = "Sprint toward an enemy within 15m: +25% speed, -25% stamina cost.",
		short = "forward sprint: faster, cheaper",
		custom = {
			template = _unstoppable_family.forward_only_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_sprinting_staggers",
		},
	},
	{
		id = "pilgrim_family_follow_through",
		buff_template = "pilgrim_family_follow_through",
		family = "unstoppable",
		draft_tags = { "executioner" },
		tier = "minoris",
		name = "Follow Through",
		description = "Kill 2 enemies with one melee attack to restore 1 stamina.",
		short = "multi-kill: stamina",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_replenish_stamina_from_ranged_or_melee_hit",
		},
	},
	{
		id = "pilgrim_family_no_grip_strong_enough",
		buff_template = "pilgrim_family_no_grip_strong_enough",
		family = "unstoppable",
		draft_tags = { "executioner" },
		tier = "majoris",
		name = "No Grip Strong Enough",
		description = "You count as dodging against Trapper nets and hounds while sprinting.",
		short = "sprint dodges nets and hounds",
		custom = {
			template = _unstoppable_family.no_grip_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_dodge_incapacitating_attacks",
		},
	},
	{
		id = "pilgrim_family_grudge_engine",
		buff_template = "pilgrim_family_grudge_engine",
		family = "unstoppable",
		draft_tags = { "executioner" },
		tier = "majoris",
		name = "Grudge Engine",
		description = "Staggered: +25% melee power; melee is uninterruptible for 5s. 10s cooldown.",
		short = "staggered: melee retaliation",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_windup_is_uninterruptible",
		},
	},
}

for i = 1, #M.FAMILY_BOONS do
	local boon = M.FAMILY_BOONS[i]
	_pilgrim_family_by_template[boon.buff_template] = boon
end

function M.family_all()
	return M.FAMILY_BOONS
end

-- Arbites Legendary factories live on M instead of becoming more top-level
-- locals. boons.lua is close to LuaJIT's local-variable ceiling, while table
-- members have no such limit.
function M._dog_and_thunder_template(BS)
	local shock_tokens = _resolve_ailment_tokens(BS, { "electrocuted" })
	local ok_checks, CheckProcFunctions = pcall(require,
		"scripts/settings/buff/helper_functions/check_proc_functions")
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_hit] = 1 },
		check_proc_func = function(params, template_data, template_context, t)
			local profile_name = params.damage_profile and params.damage_profile.name
			return template_context.is_server
				and ok_checks
				and CheckProcFunctions.attacker_is_my_companion(
					params, template_data, template_context, t)
				and profile_name ~= SECONDARY_DAMAGE_PROFILE_NAME
				and params.attacked_unit ~= nil
				and (params.actual_damage_dealt or 0) > 0
		end,
		proc_func = function(params, template_data, template_context)
			local origin = params.attacked_unit
			local candidates = {}
			_for_each_enemy_in_radius(template_context.unit, origin, 8, origin,
				function(target)
					local extension = ScriptUnit.has_extension(target, "buff_system")
					if not _extension_has_current_keyword(extension, shock_tokens) then
						return
					end
					local origin_position = POSITION_LOOKUP[origin]
					local target_position = POSITION_LOOKUP[target]
					candidates[#candidates + 1] = {
						unit = target,
						distance = origin_position and target_position
							and Vector3.distance_squared(origin_position, target_position)
							or math.huge,
					}
				end)
			table.sort(candidates, function(a, b) return a.distance < b.distance end)
			for i = 1, math.min(3, #candidates) do
				_deal_secondary_damage(candidates[i].unit, template_context.unit,
					params.actual_damage_dealt, "electrocution")
			end
		end,
	}
end

function M._weight_of_lex_template(BS)
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = { [BS.proc_events.on_lunge_end] = 1 },
		proc_func = function(params, template_data, template_context, t)
			if not template_context.is_server then return end
			local position = POSITION_LOOKUP[template_context.unit]
			if not position then return end
			local ok_liquid, LiquidArea = pcall(require,
				"scripts/extension_systems/liquid_area/utilities/liquid_area")
			local ok_templates, LiquidAreaTemplates = pcall(require,
				"scripts/settings/liquid_area/liquid_area_templates")
			local nav_manager = Managers.state.nav_mesh
			local nav_world = nav_manager and nav_manager:nav_world()
			local shock_template = ok_templates and LiquidAreaTemplates.shock_trap
			if not (ok_liquid and nav_world and shock_template) then return end
			local side_system = Managers.state.extension:system("side_system")
			local side = side_system and side_system.side_by_unit[template_context.unit]
			local side_name = side and type(side.name) == "function"
				and side:name() or nil
			local liquid_unit = LiquidArea.try_create(position, Vector3.down(),
				nav_world, shock_template, template_context.unit, 100, false, nil,
				side_name)
			local liquid_system = Managers.state.extension:system("liquid_area_system")
			local extension_map = liquid_system and liquid_system:unit_to_extension_map()
			local extension = liquid_unit and extension_map and extension_map[liquid_unit]
			if extension then extension._time_to_remove = t + 6 end
		end,
	}
end

-- Bull Rush already emits one start event, one hit event per struck enemy and
-- one end event. Keeping the counter inside the always-present Legendary buff
-- makes each charge an isolated transaction and avoids adding or removing
-- helper buffs while Darktide is iterating the player's buff array.
function M._end_of_line_template(BS)
	local ok_damage, DamageSettings = pcall(require,
		"scripts/settings/damage/damage_settings")
	local lunge_damage = ok_damage and DamageSettings.damage_types
		and DamageSettings.damage_types.ogryn_lunge or "ogryn_lunge"
	return {
		class_name = "server_only_proc_buff",
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		proc_events = {
			[BS.proc_events.on_lunge_start] = 1,
			[BS.proc_events.on_hit] = 1,
			[BS.proc_events.on_lunge_end] = 1,
		},
		start_func = function(template_data)
			template_data.hit_units = {}
			template_data.hit_count = 0
		end,
		specific_check_proc_funcs = {
			[BS.proc_events.on_hit] = function(params, template_data)
				local target = params.attacked_unit
				return params.damage_type == lunge_damage and target ~= nil
					and not template_data.hit_units[target]
			end,
		},
		specific_proc_func = {
			[BS.proc_events.on_lunge_start] = function(params, template_data)
				table.clear(template_data.hit_units)
				template_data.hit_count = 0
			end,
			[BS.proc_events.on_hit] = function(params, template_data)
				local target = params.attacked_unit
				template_data.hit_units[target] = true
				template_data.hit_count = template_data.hit_count + 1
			end,
			[BS.proc_events.on_lunge_end] = function(params, template_data,
					template_context, t)
				if template_context.is_server then
					M._trigger_end_of_line(template_context.unit,
						template_data.hit_count, t)
				end
			end,
		},
	}
end

-- Flak Cannon uses the existing grenade-charge extension. Its interval starts
-- at ninety seconds, so equipping the Legendary never grants a free missile
-- immediately and each later tick restores at most one charge through the
-- engine's own clamped restore path.
function M._flak_cannon_template(BS)
	return {
		class_name = "interval_buff",
		interval = 90,
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		interval_func = function(template_data, template_context)
			if not template_context.is_server then return end
			local extension = ScriptUnit.has_extension(
				template_context.unit, "ability_system")
			if extension and type(extension.restore_ability_charge) == "function" then
				pcall(extension.restore_ability_charge, extension,
					"grenade_ability", 1)
			end
		end,
	}
end

-- Cleansing Flame checks the liquid-area system four times per second. The
-- area extension retains the exact source operative, so another Zealot's fire
-- cannot activate the Legendary. Damage reduction lives in a short child buff
-- refreshed only while the owner remains in their own grenade fire.
function M._cleansing_flame_template(BS)
	return {
		class_name = "interval_buff",
		interval = 0.25,
		max_stacks = 1,
		max_stacks_cap = 1,
		predicted = false,
		start_func = function(template_data, template_context)
			if not template_context.is_server then return end
			local manager = Managers.state.extension
			template_data.liquid_area_system = manager
				and manager:system("liquid_area_system") or nil
			template_data.areas = {}
			template_data.next_cleanse_t = nil
		end,
		interval_func = function(template_data, template_context, template,
				time_since_start, t)
			if not template_context.is_server then return end
			local unit = template_context.unit
			local position = POSITION_LOOKUP[unit]
			local system = template_data.liquid_area_system
			if not position or not system
				or type(system.find_liquid_areas_in_position) ~= "function" then
				return
			end

			local areas = template_data.areas
			for key in pairs(areas) do areas[key] = nil end
			system:find_liquid_areas_in_position(position, areas)
			local in_own_fire = false
			for _, extension in pairs(areas) do
				if type(extension.area_template_name) == "function"
					and extension:area_template_name() == "fire_grenade"
					and extension._source_unit == unit then
					in_own_fire = true
					break
				end
			end
			if not in_own_fire then
				template_data.next_cleanse_t = nil
				return
			end

			local buff_extension = template_context.buff_extension
			if buff_extension
				and type(buff_extension.add_internally_controlled_buff) == "function" then
				pcall(buff_extension.add_internally_controlled_buff, buff_extension,
					"pilgrim_cleansing_flame_guard", t,
					"owner_unit", unit)
			end

			if not template_data.next_cleanse_t then
				template_data.next_cleanse_t = t + 1
			elseif t >= template_data.next_cleanse_t then
				template_data.next_cleanse_t = t + 1
				local health = ScriptUnit.has_extension(unit, "health_system")
				if health and type(health.max_health) == "function"
					and type(health.reduce_permanent_damage) == "function" then
					local ok, maximum = pcall(health.max_health, health)
					if ok and tonumber(maximum) then
						pcall(health.reduce_permanent_damage, health,
							maximum * 0.01)
					end
				end
			end
		end,
	}
end

-- Positive allowlist for Flak Cannon's human-sized execute. New breeds remain
-- bleed-only until reviewed, preventing a future captain or large mutator
-- enemy from becoming executable merely because it lacks a boss tag.
M.FLAK_CANNON_EXECUTE_BREEDS = {
	chaos_newly_infected = true,
	chaos_poxwalker = true,
	cultist_assault = true,
	cultist_berzerker = true,
	cultist_flamer = true,
	cultist_grenadier = true,
	cultist_gunner = true,
	cultist_melee = true,
	cultist_ritualist = true,
	cultist_shocktrooper = true,
	cultist_vanguard = true,
	renegade_assault = true,
	renegade_berzerker = true,
	renegade_executor = true,
	renegade_flamer = true,
	renegade_grenadier = true,
	renegade_gunner = true,
	renegade_melee = true,
	renegade_netgunner = true,
	renegade_plasma_gunner = true,
	renegade_radio_operator = true,
	renegade_rifleman = true,
	renegade_shocktrooper = true,
	renegade_sniper = true,
	renegade_vanguard = true,
}

M.FLAK_CANNON_BLAST_PROFILES = {
	broker_missile_launcher_explosion_close = true,
	broker_missile_launcher_explosion = true,
}

M.SHRAPNEL_DOCTRINE_EXECUTE_BREEDS = {
	chaos_newly_infected = true,
	chaos_poxwalker = true,
}

M.SHRAPNEL_DOCTRINE_BLAST_PROFILES = {
	frag_grenade = true,
	close_frag_grenade = true,
}

M.BIGGER_BOOM_PROFILES = {
	ogryn_grenade = true,
	close_ogryn_grenade = true,
}

M.BIGGER_BOOM_TWIN_BREEDS = {
	renegade_twin_captain = true,
	renegade_twin_captain_two = true,
}

M.CHAIN_OF_CUSTODY_PROFILES = {
	adamant_grenade = true,
	close_adamant_grenade = true,
}

M.LIGHTS_OUT_FOREVER_PROFILES = {
	broker_flash_grenade = true,
	broker_flash_grenade_close = true,
}

-- Weak keys let dead minions disappear naturally. A grenade writes the mark
-- only after its own stagger has resolved, so the explosion cannot consume its
-- own guaranteed critical hit.
M._chain_of_custody_marks = setmetatable({}, { __mode = "k" })

M.CUSTOM = {
	{
		-- Kaizen's own design (2026-08-10), third implementation and
		-- this one is HIS mechanism: "since Smite is technically a
		-- weapon you hold under the hood, make the [damage buff]
		-- active only when smite is the equipped weapon."
		--
		-- History: v0.22.81 used smite_damage_multiplier, which never
		-- fired because Smite's CHANNEL is warp-typed (only the
		-- finisher is smite-typed). v0.22.82's Attack.execute relabel
		-- hook also failed in the field (the attack utility loads
		-- before mods and is never re-required, so the fanout can't
		-- reach it). v0.22.83: conditional stat buff on the WIELD
		-- state, pure buff-system machinery, the same machinery whose
		-- malus provably works. Base -0.9 always; +9.9 more while the
		-- wielded slot is slot_grenade_ability AND its weapon template
		-- is psyker_smite (so Assail/Brain Burst don't qualify), which
		-- sums the additive bucket to exactly 10x while channeling
		-- Smite. While Smite is wielded you cannot attack with
		-- anything else, so "Smite does 10x" and "wielding Smite means
		-- 10x" are the same statement, modulo DoTs from earlier hits
		-- ticking during the channel, which also enjoy the bonus
		-- (noted, acceptable).
		-- FOURTH implementation (Kaizen 2026-08-10): "We just bump the
		-- damage 10x, straight up, but block inputs that switch to
		-- other weapons, so only Smite (or just the blitz) is allowed
		-- to be wielded." History of the three failures lives in the
		-- roadmap; short version: smite_damage_multiplier (channel is
		-- warp-typed), Attack.execute relabel (utility unreachable by
		-- fanout), conditional_stat_buffs (never evaluated in the
		-- field). This shape needs NOTHING exotic: a flat additive
		-- damage stat, proven working by the malus in every prior
		-- attempt, and the balance lives in the Smite lockdown
		-- (InputService hook in Pilgrimage.lua, TEP's proven seam):
		-- weapon wield inputs blocked, and an auto-snap that re-raises
		-- Smite whenever the game auto-returns you to a weapon after a
		-- cast (gated below 85% Peril so it can never force an
		-- overload death; while venting above that you hold your
		-- weapon, at 10x, the one documented soft spot).
		id           = "pilgrim_boon_unlimited_power",
		name         = "Unlimited Power",
		description  = "Smite deals 50x damage. All other damage is reduced to 10%.",
		short        = "Smite x50, rest 10%",
		-- v0.26.0: promoted out of the Ordos Doctrine library and into
		-- the Psyker Smite legendary pool. The old cost remains only as
		-- save-history metadata; buy_custom rejects promoted entries.
		cost         = 2500,
		legendary    = true,
		archetype    = "psyker",  -- apply-time gate; the lockdown also keys on this
		-- v0.22.85 (Kaizen): "100x damage modifier across the board,
		-- active only if smite is in the talent tree." The blitz gate
		-- below is checked at apply time AND by the lockdown, so a
		-- psyker running Assail or Brain Burst gets neither the buff
		-- nor the input lock.
		--
		-- v0.22.86 NAMING TRAP (Kaizen caught it): the blitz players
		-- call Smite is internally `psyker_chain_lightning`; the
		-- template named `psyker_smite` is BRAIN BURST (charge-and-
		-- pop, kill_charge on the head hitzone). v0.22.85 shipped the
		-- wrong name for one evening and would have gated UP onto
		-- Brain Burst instead of Smite.
		requires_blitz = "psyker_chain_lightning",
		buff_template = "pilgrim_boon_unlimited_power",
		custom = {
			stat_buffs = {
				-- additive: 1 + 99.0 = x100 on everything, and the
				-- lockdown makes "everything" mean Smite.
				--
				-- v0.22.87, Kaizen's ORIGINAL design, now buildable
				-- because the field test proved the buff machinery
				-- works ("it works now and it ridiculously strong"):
				-- Smite x50, everything else x0.1, weapons stay
				-- equippable for utility (poxburster shoves,
				-- corruptor clearing), the lockdown retired to a
				-- dormant generic system in Pilgrimage.lua.
				--
				-- Bucket math (damage_calculation.lua): `damage`,
				-- `smite_damage` and `chain_lightning_damage` all
				-- accumulate into ONE additive bucket, each
				-- contributing (aggregated - 1). Non-Smite damage:
				-- 1 + (-0.9) = x0.1. Smite components additionally
				-- carry +49.9 from one of the two targeted stats:
				-- 1 - 0.9 + 49.9 = exactly x50.
				--   * chain_lightning_damage (line 510, gated by the
				--     profile's chain_lightning flag) covers the
				--     electrocuted DoT ticks natively, and covers the
				--     channel ticks through the profile-flag patch in
				--     Pilgrimage.lua (the channel profile ships
				--     WITHOUT the flag; we set it while UP is live).
				--   * smite_damage (line 501, damage_type smite only)
				--     is the safety net for any smite-typed hit.
				-- Known leaks, accepted for now: Empowered Psionics
				-- adds its own +2 to the same bucket (x52.1, fine);
				-- force-weapon shock blessings whose DoTs reuse
				-- flagged chain-lightning profiles would enjoy the
				-- x50 (thematically coherent; revisit in the economy
				-- pass).
				damage = -0.9,
				chain_lightning_damage = 49.9,
				smite_damage = 49.9,
			},
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_psyker_smite_always_max_damage",
		},
	},
	{
		id = "pilgrim_legendary_cold_wake",
		name = "Cold Wake",
		description = "Executioner's Stance dodges ranged fire. Ranged dodges add 0.5s, up to 10s.",
		short = "ranged dodges extend stance",
		legendary = true,
		archetype = "veteran",
		requires_combat_ability = "volley_fire_stance",
		buff_template = "pilgrim_legendary_cold_wake",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/veteran/veteran_ability_volley_fire",
			template = _cold_wake_template,
		},
	},
	{
		id = "pilgrim_legendary_shadow_emperor",
		name = "Shadow of the Emperor",
		description = "The attack that ends Shroudfield strikes again after 1s.",
		short = "Shroudfield attack repeats",
		legendary = true,
		archetype = "zealot",
		requires_combat_ability = "zealot_invisibility",
		buff_template = "pilgrim_legendary_shadow_emperor",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/zealot/zealot_ability_stealth",
		},
	},
	{
		id = "pilgrim_legendary_pilgrims_momentum",
		name = "Pilgrim's Momentum",
		description = "Dash kills erupt for 150 plus 30% victim health in 2.5m.",
		short = "dash kills erupt",
		legendary = true,
		archetype = "zealot",
		requires_combat_ability = "zealot_dash",
		buff_template = "pilgrim_legendary_pilgrims_momentum",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/zealot/zealot_dash_increased_duration",
			template = M._pilgrims_momentum_template,
		},
	},
	{
		id = "pilgrim_legendary_chorus_everlasting",
		name = "Chorus Everlasting",
		description = "Each Chorus pulse applies 5 burn and 5 soulfire, up to 20 each.",
		short = "pulses burn and soulfire",
		legendary = true,
		archetype = "zealot",
		requires_combat_ability = "bolstering_prayer",
		buff_template = "pilgrim_legendary_chorus_everlasting",
		custom = {
			hud_icon = "content/ui/textures/icons/abilities/hud/zealot/zealot_ability_bolstering_prayer",
		},
	},
	{
		-- Current source has no timed "Warrant stance": Terminus Warrant
		-- is a permanent keystone. The timed Arbites combat stance is
		-- Castigator's Stance (adamant_stance), which is the intended fit.
		id = "pilgrim_legendary_lex_never_rests",
		name = "The Lex Never Rests",
		description = "Castigator's Stance kills extend it by 1s, up to 25s per use.",
		short = "stance kills add 1s, max 25s",
		legendary = true,
		archetype = "adamant",
		requires_combat_ability = "adamant_stance",
		buff_template = "pilgrim_legendary_lex_never_rests",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/adamant/adamant_stance",
			template = _duration_refund_template({ "adamant_hunt_stance" }, false, 1, 25),
		},
	},
	{
		id = "pilgrim_legendary_house_edge",
		name = "House Edge",
		description = "Critical hits during Desperado ricochet to a nearby enemy for 50% damage.",
		short = "Desperado crits ricochet",
		legendary = true,
		archetype = "broker",
		requires_combat_ability = "broker_focus_stance",
		buff_template = "pilgrim_legendary_house_edge",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/broker/broker_broker_gunslinger_focus",
			template = _house_edge_template,
		},
	},
	{
		id = "pilgrim_legendary_gutter_rage",
		name = "Gutter Rage",
		description = "Every 10th Rampage melee hit deals 50% of its damage in a 5m shockwave.",
		short = "10th hit: 50% shockwave",
		legendary = true,
		archetype = "broker",
		requires_combat_ability = "broker_punk_rage_stance",
		buff_template = "pilgrim_legendary_gutter_rage",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/broker/broker_broker_punk_rage",
			template = _gutter_rage_template,
		},
	},
	{
		id = "pilgrim_legendary_doctrina_override",
		name = "Doctrina Override",
		description = "Marked targets arc 25% of damage taken to a nearby enemy.",
		short = "marks arc 25% damage",
		legendary = true,
		archetype = "cryptic",
		requires_blitz = {
			"cryptic_servo_skull_order",
			"cryptic_servo_skull_order_base",
		},
		requires_blitz_label = "the Servo-skull Order blitz",
		buff_template = "pilgrim_legendary_doctrina_override",
		custom = {
			hud_icon = "content/ui/textures/icons/throwables/hud/cryptic_servo_skull_order_shooting",
			template = function(BS)
				return {
					class_name = "server_only_proc_buff",
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					proc_events = { [BS.proc_events.on_hit] = 1 },
					start_func = function(template_data, template_context)
						local unit = template_context.unit
						template_data.spawner = ScriptUnit.has_extension(unit, "companion_spawner_system")
						local ok, settings = pcall(require, "scripts/settings/ability/special_rules_settings")
						template_data.servo_rule = ok and settings.special_rules
							and settings.special_rules.cryptic_servo_skull_hack
							or "cryptic_servo_skull_hack"
					end,
					check_proc_func = function(params, template_data, template_context)
						if not template_context.buff_extension:has_buff_using_buff_template(
							"cryptic_servo_skull_order") then return false end
						local servo = template_data.spawner and template_data.spawner:spawned_unit_lookup(
							template_data.servo_rule)
						return servo ~= nil and params.attack_instigator_unit == servo
							and params.attacked_unit ~= nil and HEALTH_ALIVE[params.attacked_unit]
					end,
					proc_func = function(params, template_data, template_context, t)
						if not template_context.is_server then return end
						local target_ext = ScriptUnit.has_extension(params.attacked_unit, "buff_system")
						if target_ext then
							target_ext:add_internally_controlled_buff(
								"pilgrim_doctrina_override_mark", t,
								"owner_unit", template_context.unit)
						end
					end,
				}
			end,
		},
	},
	{
		-- Save-compatible replacement for Target Marked. Keeping the old
		-- id and template means an already unlocked or slotted copy becomes
		-- Omnissian Certainty instead of turning into a dead save entry.
		id = "pilgrim_legendary_target_marked",
		name = "Omnissian Certainty",
		description = "ACD drains 7% Capacitance per second, unaffected by firing or refunds.",
		short = "ACD: fixed 7% drain",
		legendary = true,
		archetype = "cryptic",
		requires_combat_ability = "cryptic_precision_stance",
		requires_combat_ability_label = "Advanced Combat Doctrines",
		buff_template = "pilgrim_legendary_target_marked",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_cryptic_precision_stance_duration_extension_on_kill",
		},
	},
	{
		id = "pilgrim_legendary_word_carries",
		name = "The Word Carries",
		description = "+50% shout radius. Allies are freed and take 50% less Toughness damage for 5s.",
		short = "larger shout, rescue and guard",
		legendary = true,
		archetype = "veteran",
		requires_combat_ability = "voice_of_command",
		buff_template = "pilgrim_legendary_word_carries",
		custom = {
			stat_buffs = { shout_radius_modifier = 0.50 },
				hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_veteran_apply_infinite_bleed_on_shout",
		},
	},
	{
		id = "pilgrim_legendary_shrapnel_doctrine",
		name = "Red Hail",
		description = "Frag Grenades: +30% radius, 20 Bleed, and execute Poxwalkers and Groaners.",
		short = "larger frags execute and bleed",
		legendary = true,
		archetype = "veteran",
		requires_blitz = "veteran_frag_grenade",
		requires_blitz_label = "Frag Grenade",
		buff_template = "pilgrim_legendary_shrapnel_doctrine",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_grenade_explosion_kill_replenish_grenades",
		},
	},
	{
		id = "pilgrim_legendary_toxic_fog",
		name = "Toxic Fog",
		description = "Smoke poisons every 0.5s: -20% enemy attack speed, -15% speed, +15% damage.",
		short = "smoke poisons and weakens enemies",
		legendary = true,
		archetype = "veteran",
		requires_blitz = "veteran_smoke_grenade",
		requires_blitz_label = "Smoke Grenade",
		buff_template = "pilgrim_legendary_toxic_fog",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_veteran_shock_units_in_smoke_grenade",
		},
	},
	{
		id = "pilgrim_legendary_armourbane_rite",
		name = "Armourbane Rite",
		description = "Krak Grenade survivors gain +40% Rending vulnerability for 8s.",
		short = "krak survivors become vulnerable",
		legendary = true,
		archetype = "veteran",
		requires_blitz = "veteran_krak_grenade",
		requires_blitz_label = "Krak Grenade",
		buff_template = "pilgrim_legendary_armourbane_rite",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_grenade_explosion_applies_rending_debuff",
		},
	},
	{
		id = "pilgrim_legendary_sacred_current",
		name = "Sacred Current",
		description = "Stun Grenades launch 3 chains, each striking up to 4 enemies within 6m.",
		short = "stun grenades launch lightning chains",
		legendary = true,
		archetype = "zealot",
		requires_blitz = "zealot_shock_grenade",
		requires_blitz_label = "Stun Grenade",
		buff_template = "pilgrim_legendary_sacred_current",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_zealot_shock_grenade_increase_next_hit_damage",
		},
	},
	{
		id = "pilgrim_legendary_cleansing_flame",
		name = "Cleansing Flame",
		description = "Your fire grants 25% damage reduction and cleanses 1% wound Corruption/s.",
		short = "your fire cleanses and protects",
		legendary = true,
		archetype = "zealot",
		requires_blitz = "zealot_fire_grenade",
		requires_blitz_label = "Flame Grenade",
		buff_template = "pilgrim_legendary_cleansing_flame",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_zealot_regen_toughness_inside_fire_grenade",
			template = M._cleansing_flame_template,
		},
	},
	{
		id = "pilgrim_legendary_overwhelming_mind",
		name = "Overwhelming Mind",
		description = "Scrier's Gaze: 3x warp damage, 10% other damage, then two upgraded Shrieks.",
		short = "Gaze: warp x3, two Shrieks",
		legendary = true,
		archetype = "psyker",
		requires_combat_ability = "psyker_overcharge_stance",
		buff_template = "pilgrim_legendary_overwhelming_mind",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_psyker_overcharge_reduced_damage_taken",
			template = _ability_state_template("psyker_overcharge", {
				-- The game's damage bucket is additive. While Gaze is active,
				-- ordinary damage becomes 1 - 0.9 = x0.1, while attacks the
				-- engine classifies as warp also receive +2.9, for x3 total.
				damage = -0.90,
				warp_damage = 2.90,
			}),
		},
	},
	{
		id = "pilgrim_legendary_unwarded_minds",
		name = "Unwarded Minds",
		description = "Brain Rupture executes non-bosses, but cannot target Captains or Monstrosities.",
		short = "Brain Rupture executes non-bosses",
		legendary = true,
		archetype = "psyker",
		requires_blitz = {
			"psyker_smite",
			"psyker_biomancer_smite",
		},
		buff_template = "pilgrim_legendary_unwarded_minds",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_psyker_brain_burst_hits_nearby_enemies",
		},
	},
	{
		id = "pilgrim_legendary_harrowing_rebuke",
		name = "Harrowing Rebuke",
		description = "Carapace counts as Flak. Follow-up shards gain +50% vs heavy targets for 2s.",
		short = "Assail hunts heavy targets",
		legendary = true,
		archetype = "psyker",
		requires_blitz = "psyker_throwing_knives",
		requires_blitz_label = "Assail",
		buff_template = "pilgrim_legendary_harrowing_rebuke",
		custom = {
			hud_icon = "content/ui/textures/icons/talents/psyker/psyker_throwing_knives_piercing",
		},
	},
	{
		id = "pilgrim_legendary_fly_trap",
		name = "Fly Trap",
		description = "Flat shields pin and shock enemies; pinned enemies cannot damage them.",
		short = "flat shields pin enemies",
		legendary = true,
		archetype = "psyker",
		requires_combat_ability = "psyker_shield",
		requires_combat_ability_name = {
			"psyker_force_field",
			"psyker_force_field_improved",
		},
		requires_combat_ability_label = "Telekine Shield",
		buff_template = "pilgrim_legendary_fly_trap",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_psyker_shock_on_touch_force_field",
			template = M._fly_trap_template,
		},
	},
	{
		id = "pilgrim_legendary_louder",
		name = "LOUDER!",
		description = "Each Taunt wave fully restores allies' Toughness and grants 50 bonus Toughness.",
		short = "Taunt waves fortify allies",
		legendary = true,
		archetype = "ogryn",
		requires_combat_ability = "ogryn_taunt_shout",
		buff_template = "pilgrim_legendary_louder",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_ogryn_apply_fire_on_shout",
			template = _louder_template,
		},
	},
	{
		id = "pilgrim_legendary_belt_fed_believer",
		name = "Belt-Fed Believer",
		description = "Stance kills load 2% reserve capacity and add 0.5s, up to 30% and 7s.",
		short = "stance kills feed ammo and time",
		legendary = true,
		archetype = "ogryn",
		requires_combat_ability = "ogryn_gunlugger_stance",
		requires_combat_ability_label = "Point-Blank Barrage",
		buff_template = "pilgrim_legendary_belt_fed_believer",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/ogryn/ogryn_ability_speshul_ammo",
			template = _unstoppable_family.belt_fed_template,
		},
	},
	{
		id = "pilgrim_legendary_special_delivery",
		name = "Special Delivery",
		description = "Big Box releases 6 seeking bomblets, each dealing 70% impact damage.",
		short = "6 seeking impact bomblets",
		legendary = true,
		archetype = "ogryn",
		requires_blitz = "ogryn_grenade_box_cluster",
		buff_template = "pilgrim_legendary_special_delivery",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_ogryn_box_of_surprises",
		},
	},
	{
		id = "pilgrim_legendary_bigger_boom_doctrine",
		name = "Rubert Ogrynheimer",
		description = "Frag Bombs execute all enemies except shielded Captains and the Twins.",
		short = "Frag Bombs execute almost everything",
		legendary = true,
		archetype = "ogryn",
		requires_blitz = "ogryn_grenade_frag",
		requires_blitz_label = "Frag Bomb",
		buff_template = "pilgrim_legendary_bigger_boom_doctrine",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_ogryn_biggest_boom_grenade",
		},
	},
	{
		id = "pilgrim_legendary_voltaic_web",
		name = "Voltaic Web",
		description = "Shock Mines arm instantly, gain +40% radius and +6s life, then arc 4 times.",
		short = "larger mines chain lightning",
		legendary = true,
		archetype = "adamant",
		requires_blitz = "adamant_shock_mine",
		requires_blitz_label = "Shock Mines",
		buff_template = "pilgrim_legendary_voltaic_web",
		custom = {
			stat_buffs = { explosion_radius_modifier_shock = 0.40 },
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_adamant_mine_explosion",
		},
	},
	{
		id = "pilgrim_legendary_chain_of_custody",
		name = "Chain of Custody",
		description = "Grenade-staggered enemies are marked. Your warband's first hit is a critical.",
		short = "grenade staggers mark guaranteed crits",
		legendary = true,
		archetype = "adamant",
		requires_blitz = {
			"adamant_grenade",
			"adamant_grenade_improved",
		},
		requires_blitz_label = "Arbites Grenade",
		buff_template = "pilgrim_legendary_chain_of_custody",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_adamant_grenade_multi",
		},
	},
	{
		id = "pilgrim_legendary_dog_and_thunder",
		name = "Dog and Thunder",
		description = "Mastiff hits arc full damage to 3 electrocuted enemies within 8m.",
		short = "mastiff hits arc full damage",
		legendary = true,
		archetype = "adamant",
		buff_template = "pilgrim_legendary_dog_and_thunder",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_adamant_auto_detonate",
			template = M._dog_and_thunder_template,
		},
	},
	{
		id = "pilgrim_legendary_standing_order",
		name = "Standing Order",
		description = "Nuncio-Aquila prevents allied stuns, pounces and nets.",
		short = "drone blocks disables",
		legendary = true,
		archetype = "adamant",
		requires_combat_ability = "adamant_area_buff_drone",
		requires_combat_ability_label = "Nuncio-Aquila",
		buff_template = "pilgrim_legendary_standing_order",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_adamant_drone_stun",
		},
	},
	{
		id = "pilgrim_legendary_weight_of_lex",
		name = "Weight of the Lex",
		description = "Charge leaves a 4m shock field for 6s.",
		short = "charge leaves shock field",
		legendary = true,
		archetype = "adamant",
		requires_combat_ability = "adamant_charge",
		buff_template = "pilgrim_legendary_weight_of_lex",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_adamant_random_bash",
			template = M._weight_of_lex_template,
		},
	},
	{
		id = "pilgrim_legendary_flak_cannon",
		name = "Flak Cannon",
		description = "Missile blasts ignore cover; human-sized foes die; survivors bleed 15. +1/90s.",
		short = "missile blasts pierce cover, execute and bleed",
		legendary = true,
		archetype = "broker",
		requires_blitz = "broker_missile_launcher",
		requires_blitz_label = "Missile Launcher",
		buff_template = "pilgrim_legendary_flak_cannon",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_broker_missile_launcher_special_kill_restores_grenade",
			template = M._flak_cannon_template,
		},
	},
	{
		id = "pilgrim_legendary_overdose",
		name = "Overdose",
		description = "Stimm Supply grants cartel, speed, cooldown and power stimms.",
		short = "Stimm Supply grants every stimm",
		legendary = true,
		archetype = "broker",
		-- Loadout relevance compares Fatshark's combat-ability group, not the
		-- talent/item name. Stimm Supply's item is broker_ability_stimm_field,
		-- but its group and Mortis Legendary catalogue key are broker_stimm_field.
		requires_combat_ability = "broker_stimm_field",
		requires_combat_ability_label = "Stimm Supply",
		buff_template = "pilgrim_legendary_overdose",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_broker_stimm_field_shock_on_interval",
		},
	},
	{
		id = "pilgrim_legendary_lights_out_forever",
		name = "Lights Out Forever",
		description = "Flashed enemies use melee and attack 50% slower for 10s.",
		short = "flash forces slow melee",
		legendary = true,
		archetype = "broker",
		requires_blitz = {
			"broker_flash_grenade",
			"broker_flash_grenade_improved",
		},
		requires_blitz_label = "Flash Grenade",
		buff_template = "pilgrim_legendary_lights_out_forever",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_broker_flash_grenade_increase_damage_taken",
		},
	},
	{
		id = "pilgrim_legendary_voltaic_ripples",
		name = "Voltaic Ripples",
		description = "Ranged deflections shock foes within 2m for 30 damage. 0.25s per target.",
		short = "ranged deflections shock nearby foes",
		legendary = true,
		archetype = "cryptic",
		requires_blitz = "cryptic_force_field",
		requires_blitz_label = "Force Field",
		buff_template = "pilgrim_legendary_voltaic_ripples",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_cryptic_force_field_leaves_fire_liquid_area",
		},
	},
	{
		id = "pilgrim_legendary_red_harvest",
		name = "Red Harvest",
		description = "Chordclaw single stab deals +10% max health; triple stabs +8% each.",
		short = "Chordclaw stabs deal max-health damage",
		legendary = true,
		archetype = "cryptic",
		requires_combat_ability = "cryptic_chordclaw",
		requires_combat_ability_label = "Chordclaw",
		buff_template = "pilgrim_legendary_red_harvest",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_cryptic_chordclaw_kills_replenish_charge",
		},
	},
	{
		id = "pilgrim_legendary_tesla_doctrine",
		name = "Tesla Doctrine",
		description = "Arc Grenades leave a 4m shock field for 5s, striking every 0.5s.",
		short = "Arc Grenades leave shock fields",
		legendary = true,
		archetype = "cryptic",
		requires_blitz = "arc_grenade",
		requires_blitz_label = "Arc Grenade",
		buff_template = "pilgrim_legendary_tesla_doctrine",
		custom = {
				hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_cryptic_arc_grenade_extra_arcs",
		},
	},
	{
		id = "pilgrim_legendary_no_witnesses",
		name = "No Witnesses",
		description = "Pass within 3m to mark foes. On exit: trash dies; others lose 20% (bosses 5%).",
		short = "Infiltrate marks foes for execution",
		legendary = true,
		archetype = "veteran",
		requires_combat_ability = "veteran_stealth",
		requires_combat_ability_label = "Infiltrate",
		buff_template = "pilgrim_legendary_no_witnesses",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_veteran_grouped_upgraded_stealth",
		},
	},
	{
		id = "pilgrim_legendary_warp_resonance",
		name = "Warp Resonance",
		description = "Venting Shriek echoes after 1s and 2s, repeating enemy effects.",
		short = "Venting Shriek echoes twice",
		legendary = true,
		archetype = "psyker",
		requires_combat_ability = "psyker_shout",
		requires_combat_ability_label = "Venting Shriek",
		buff_template = "pilgrim_legendary_warp_resonance",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_psyker_shout_always_stagger",
		},
	},
	{
		id = "pilgrim_legendary_end_of_line",
		name = "End of the Line",
		description = "Bull Rush grows an end shockwave. Trash dies; others lose 20% (bosses 5%).",
		short = "Bull Rush ends in a growing shockwave",
		legendary = true,
		archetype = "ogryn",
		requires_combat_ability = "ogryn_charge",
		requires_combat_ability_label = "Bull Rush",
		buff_template = "pilgrim_legendary_end_of_line",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_ogryn_taunt_on_lunge",
			template = M._end_of_line_template,
		},
	},
	{
		-- v0.28.45: migration keeps the old internal id. The visible
		-- doctrine and its owner/ally mark transaction live in
		-- doctrine_runtime.lua.
		id           = "pilgrim_boon_sanctioned_discord",
		name         = "Crossfire Catechism",
		description  = "Hits mark enemies. Ally hits stagger them and restore 10% Toughness to you both.",
		short        = "ally hits consume your marks",
		cost         = 1400,
		icon         = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_coherency_damage_vs_burning",
		no_buff      = true,
	},
	{
		id           = "pilgrim_boon_krieg_doctrine",
		name         = "Duty Unto Death",
		description  = "Damage cannot interrupt interactions or drop carried objectives. No carry slowdown.",
		short        = "unstoppable interactions and carrying",
		cost         = 1200,
		buff_template = "pilgrim_boon_krieg_doctrine",
		custom = {
			template = function(BS)
				return {
					class_name = "buff",
					predicted = false,
					conditional_keywords = {
						BS.keywords.uninterruptible,
						BS.keywords.stun_immune,
					},
					conditional_keywords_func = function(template_data, template_context)
						local ext = ScriptUnit.has_extension(template_context.unit,
							"interactor_system")
						return ext and ext.is_interacting and ext:is_interacting() or false
					end,
					conditional_stat_buffs = {
						[BS.stat_buffs.movement_speed] = 0.25,
					},
					conditional_stat_buffs_func = function(template_data, template_context)
						local unit_data = ScriptUnit.has_extension(template_context.unit,
							"unit_data_system")
						local inv = unit_data and unit_data:read_component("inventory")
						local slot = inv and inv.wielded_slot
						return type(slot) == "string"
							and string.find(slot, "luggable", 1, true) ~= nil
					end,
				}
			end,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_damage_taken_by_flamers_and_grenadier_reduced",
		},
	},
	{
		-- Kaizen's tuning note (2026-08-10): "the healing from blood
		-- debt must be small per kill, or trigger once every x kills
		-- ... Otherwise a player would be genuinely immortal." Chosen
		-- shape: 1% max HP per melee kill with a 3 second internal
		-- cooldown (the proc system's native cooldown_duration), so
		-- sustained ceiling is ~20% HP per minute. The halved-other-
		-- healing side lives in a Pilgrimage hook on the player health
		-- extension's add_heal (Pilgrimage.lua), marker-guarded so our
		-- own proc heal is exempt from its own tax.
		id           = "pilgrim_boon_blood_debt",
		name         = "Blood Debt",
		description  = "Melee kills heal 1% health (3s cooldown). Other healing is halved.",
		short        = "melee kills heal, other healing halved",
		cost         = 1500,
		buff_template = "pilgrim_boon_blood_debt",
		custom = {
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_health_regen",
			template = function(BS)
				return {
					class_name        = "server_only_proc_buff",
					max_stacks        = 1,
					max_stacks_cap    = 1,
					predicted         = false,
					cooldown_duration = 3,
					buff_category     = BS.buff_categories.hordes_buff or BS.buff_categories.generic,
					proc_events       = {
						[BS.proc_events.on_kill] = 1,
					},
					check_proc_func = function(params, template_data, template_context, t)
						return params.attack_type == "melee"
					end,
					proc_func = function(params, template_data, template_context, t)
						local unit = template_context.unit
						pcall(function()
							local ext = ScriptUnit.extension(unit, "health_system")
							local max_health = ext:max_health()
							local Pilgrimage = rawget(_G, "get_mod") and get_mod("Pilgrimage")
							local Boons = Pilgrimage and Pilgrimage._modules and Pilgrimage._modules.Boons
							-- Marker so the heal-halving hook exempts us.
							if Boons then Boons._blood_debt_self_heal = true end
							local ok_hs, DamageSettings = pcall(require, "scripts/settings/damage/damage_settings")
							local heal_type = ok_hs and DamageSettings
								and DamageSettings.heal_types and DamageSettings.heal_types.buff
							pcall(ext.add_heal, ext, max_health * 0.01, heal_type)
							if Boons then Boons._blood_debt_self_heal = false end
						end)
					end,
				}
			end,
		},
	},
	{
		-- v0.28.45: migration keeps the Redline internal id. The attack
		-- transaction logic lives in doctrine_runtime.lua.
		id           = "pilgrim_boon_redline_cogitator",
		name         = "Ablative Overdrive",
		description  = "Above 75% Toughness, attacks spend 5% max Toughness for +25% damage.",
		short        = "spend Toughness for damage",
		cost         = 1200,
		icon         = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_damage_increase_on_toughness_broken",
		no_buff      = true,
	},
	{
		-- Both effects live Pilgrimage-side: wallet.earn_pickup doubles
		-- while this is active (wallet.lua), Emporium prices go x1.5
		-- (shop.effective_cost). No buff template at all; the id is
		-- state, not a buff. `no_buff = true` tells apply_all to skip
		-- the grant path.
		id           = "pilgrim_boon_house_wins",
		name         = "The House Always Wins",
		description  = "Material pickups grant double Ordos. Emporium prices rise 50%.",
		short        = "x2 Ordos, pricier shop",
		cost         = 1000,
		icon         = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_bonus_crit_chance_on_ammo",
		no_buff      = true,
	},
	{
		-- v0.28.45: doctrine_runtime owns the target identity and split.
		id           = "pilgrim_boon_bigger_they_are",
		name         = "The Bigger They Are",
		description  = "Your first boss hit marks a Quarry: +75% to it, -25% to other enemies.",
		short        = "mark one boss as your Quarry",
		cost         = 1200,
		icon         = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_weakspot_damage_increase",
		no_buff      = true,
	},
	{
		id = "pilgrim_doctrine_second_reading",
		name = "Second Reading",
		description = "Once per mission, discard and reroll a complete boon draft.",
		short = "reroll one complete draft",
		cost = 1400,
		icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_random_damage_immunity",
		no_buff = true,
	},
	{
		id = "pilgrim_doctrine_munitorum_dispensation",
		name = "Munitorum Dispensation",
		description = "Small ammo counts as large; large ammo fills reserve. Ammo Crates refill grenades.",
		short = "better ammo and grenade refills",
		cost = 1400,
		icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_no_ammo_consumption_on_crits",
		no_buff = true,
	},
	{
		id = "pilgrim_doctrine_overkill_dividend",
		name = "Overkill Dividend",
		description = "Bank half lethal overkill. Your next attack can spend it for up to +50% damage.",
		short = "bank overkill for the next attack",
		cost = 1600,
		icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_damage_increase",
		no_buff = true,
	},
	{
		id = "pilgrim_doctrine_shared_dosage",
		name = "Shared Dosage",
		description = "Stimms grant a nearby ally half their duration or healing.",
		short = "share half a stimm",
		cost = 1300,
		icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_broker_stimm_field_shock_on_interval",
		no_buff = true,
	},
	{
		id = "pilgrim_doctrine_pilgrims_wager",
		name = "Pilgrim's Wager",
		description = "Stake 25% mission Ordos. Complete the pilgrimage to double it; failure loses it.",
		short = "stake mission earnings",
		cost = 1000,
		icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_random_damage_immunity",
		no_buff = true,
	},
	{
		id = "pilgrim_doctrine_unbroken_record",
		name = "Unbroken Record",
		description = "A no-down mission unlocks 50 refillable golden Toughness until your next down.",
		short = "earn persistent golden Toughness",
		cost = 1700,
		buff_template = "pilgrim_doctrine_unbroken_record",
		custom = {
			stat_buffs = { toughness_bonus_flat = 50 },
			hud_icon = "content/ui/textures/icons/buffs/hud/states_plasma_reduced_toughness",
		},
	},
}

local _custom_by_id = {}
for i = 1, #M.CUSTOM do _custom_by_id[M.CUSTOM[i].id] = M.CUSTOM[i] end

function M.custom_get(id) return _custom_by_id[id] end
function M.custom_all()
	local out = {}
	for i = 1, #M.CUSTOM do
		if not M.CUSTOM[i].legendary then out[#out + 1] = M.CUSTOM[i] end
	end
	return out
end

-- Custom legendary catalogue. It is derived from the one source table so a
-- new entry cannot be registered as a template but accidentally omitted from
-- the picker. Keeping UP's id/template stable preserves old saves.
M.LEGENDARIES = {}
for i = 1, #M.CUSTOM do
	if M.CUSTOM[i].legendary then
		M.LEGENDARIES[#M.LEGENDARIES + 1] = M.CUSTOM[i]
	end
end
for i = 1, #M.LEGENDARIES do
	local boon = M.LEGENDARIES[i]
	_pilgrim_legendary_by_template[boon.buff_template] = boon
end

-- ---------------------------------------------------------------------------
-- Session-only boon testing
-- ---------------------------------------------------------------------------

local function _test_normalize(value)
	return string.lower(tostring(value or "")):gsub("[^%w]+", "")
end

local function _test_catalogue_entries()
	local out, by_key = {}, {}
	local function add(template, id, title, no_buff)
		local key = template or (id and ("@" .. id))
		if not key or by_key[key] then return end
		local entry = {
			key = key,
			template = template,
			id = id or template,
			title = title or (template and M.info(template).title) or id,
			no_buff = no_buff == true,
		}
		by_key[key] = entry
		out[#out + 1] = entry
	end

	-- Fatshark's full nested Hordes catalogue, not merely the current
	-- operative's filtered pool. This makes the command useful for validating
	-- relevance gates and class-specific boons without rebuilding a run.
	local allowed = _allowed_buffs()
	if allowed then
		_walk_buff_names(allowed, function(name)
			add(name, name, M.info(name).title, false)
		end)
	end
	for i = 1, #(M.FAMILY_BOONS or {}) do
		local boon = M.FAMILY_BOONS[i]
		add(boon.buff_template, boon.id, boon.name, false)
	end
	for i = 1, #(M.CUSTOM or {}) do
		local boon = M.CUSTOM[i]
		add(boon.buff_template, boon.id, boon.name, boon.no_buff)
	end
	table.sort(out, function(a, b)
		local at = string.lower(tostring(a.title or a.id))
		local bt = string.lower(tostring(b.title or b.id))
		return at == bt and tostring(a.id) < tostring(b.id) or at < bt
	end)
	return out
end

function M.test_catalogue(filter)
	local entries = _test_catalogue_entries()
	local needle = _test_normalize(filter)
	if needle == "" then return entries end
	local out = {}
	for i = 1, #entries do
		local entry = entries[i]
		if string.find(_test_normalize(entry.id), needle, 1, true)
			or string.find(_test_normalize(entry.template), needle, 1, true)
			or string.find(_test_normalize(entry.title), needle, 1, true) then
			out[#out + 1] = entry
		end
	end
	return out
end

local function _resolve_test_boon(query)
	local raw = tostring(query or "")
	local needle = _test_normalize(raw)
	if needle == "" then return nil, "no boon specified" end
	local entries = _test_catalogue_entries()
	local partial = {}
	for i = 1, #entries do
		local entry = entries[i]
		if raw == entry.id or raw == entry.template then return entry end
		local exact = needle == _test_normalize(entry.id)
			or needle == _test_normalize(entry.template)
			or needle == _test_normalize(entry.title)
		if exact then return entry end
		if string.find(_test_normalize(entry.id), needle, 1, true)
			or string.find(_test_normalize(entry.template), needle, 1, true)
			or string.find(_test_normalize(entry.title), needle, 1, true) then
			partial[#partial + 1] = entry
		end
	end
	if #partial == 1 then return partial[1] end
	if #partial > 1 then
		local names = {}
		for i = 1, math.min(6, #partial) do names[#names + 1] = partial[i].id end
		return nil, "ambiguous: " .. table.concat(names, ", ")
	end
	return nil, "unknown boon"
end

local function _remove_test_handle(player_unit, template, request)
	if not request or not request.owns_handle or not template then return true end
	local buff_extension = _shared.extension(player_unit, "buff_system")
	local index = _applied[template]
	if not buff_extension or index == nil
		or type(buff_extension.remove_externally_controlled_buff) ~= "function" then
		return false, "buff removal unavailable"
	end
	local ok, err = pcall(buff_extension.remove_externally_controlled_buff,
		buff_extension, index, _applied_components[template])
	if not ok then return false, tostring(err) end
	_applied[template] = nil
	_applied_components[template] = nil
	return true
end

function M.test_grant(player_unit, query)
	if not player_unit then return false, "no local player unit" end
	local entry, err = _resolve_test_boon(query)
	if not entry then return false, err end
	if _test_requests[entry.key] then return false, "already test-active", entry end

	local request = { entry = entry, owns_handle = false }
	if entry.template then
		local already = _applied[entry.template] ~= nil
		if not already then
			local ok, grant_err = M.grant(player_unit, entry.template)
			if not ok then return false, grant_err, entry end
			request.owns_handle = true
		end
	end
	_test_requests[entry.key] = request
	_test_active_ids[entry.id] = true
	if entry.template then _test_active_ids[entry.template] = true end
	return true, nil, entry
end

function M.reapply_test_boons(player_unit)
	if not player_unit then return 0 end
	local keys = {}
	for key in pairs(_test_requests) do keys[#keys + 1] = key end
	table.sort(keys)
	local granted = 0
	for i = 1, #keys do
		local request = _test_requests[keys[i]]
		local template = request and request.entry and request.entry.template
		if template and not _applied[template] then
			local ok = M.grant(player_unit, template)
			if ok then
				request.owns_handle = true
				granted = granted + 1
			end
		end
	end
	return granted
end

function M.test_remove(player_unit, query)
	local entry, err = _resolve_test_boon(query)
	if not entry then return false, err end
	local request = _test_requests[entry.key]
	if not request then return false, "not test-active", entry end
	local ok, remove_err = _remove_test_handle(player_unit, entry.template, request)
	if not ok then return false, remove_err, entry end
	_test_requests[entry.key] = nil
	_test_active_ids[entry.id] = nil
	if entry.template then _test_active_ids[entry.template] = nil end
	return true, nil, entry
end

function M.test_clear(player_unit)
	local removed, failures = 0, {}
	local keys = {}
	for key in pairs(_test_requests) do keys[#keys + 1] = key end
	for i = 1, #keys do
		local request = _test_requests[keys[i]]
		local entry = request.entry
		local ok, err = _remove_test_handle(player_unit, entry.template, request)
		if ok then
			removed = removed + 1
		else
			failures[#failures + 1] = tostring(entry.id) .. ": " .. tostring(err)
		end
		_test_requests[keys[i]] = nil
	end
	for key in pairs(_test_active_ids) do _test_active_ids[key] = nil end
	return #failures == 0, removed, failures
end

function M.test_active_ids()
	local out = {}
	for _, request in pairs(_test_requests) do
		out[#out + 1] = request.entry.id
	end
	table.sort(out)
	return out
end

-- Hidden child effects for family boons. The visible boon owns the trigger or
-- threshold check; these templates hold the temporary stat change.
-- Keeping them separate prevents support effects from entering any draft pool.
M.FAMILY_SUPPORT_TEMPLATES = {
	{
		id = "pilgrim_afflictor_exposed_support",
		buff_template = "pilgrim_afflictor_exposed",
		custom = {
			template = function(BS)
				return {
					class_name = "buff",
					duration = 5,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					refresh_duration_on_stack = true,
					stat_buffs = {
						[BS.stat_buffs.damage_taken_modifier] = 0.15,
					},
				}
			end,
		},
	},
	{
		id = "pilgrim_conduit_bonus_toughness_support",
		buff_template = "pilgrim_conduit_bonus_toughness",
		custom = {
			template = function(BS)
				return {
					class_name = "buff",
					duration = 10,
					max_stacks = 50,
					max_stacks_cap = 50,
					predicted = false,
					refresh_duration_on_stack = true,
					stat_buffs = {
						[BS.stat_buffs.toughness_bonus_flat] = 1,
					},
				}
			end,
		},
	},
	{
		id = "pilgrim_flashover_spent_support",
		buff_template = "pilgrim_flashover_spent",
		custom = {
			template = function()
				return {
					class_name = "buff",
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
				}
			end,
		},
	},
	{
		id = "pilgrim_thermal_shock_cooldown_support",
		buff_template = "pilgrim_thermal_shock_cooldown",
		custom = {
			template = function()
				return {
					class_name = "buff",
					duration = 12,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
				}
			end,
		},
	},
	{
		id = "pilgrim_catalyst_cooldown_support",
		buff_template = "pilgrim_catalyst_cooldown",
		custom = {
			template = function()
				return {
					class_name = "buff",
					duration = 2,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
				}
			end,
		},
	},
	{
		id = "pilgrim_conduction_cooldown_support",
		buff_template = "pilgrim_conduction_cooldown",
		custom = {
			template = function()
				return {
					class_name = "buff",
					duration = 15,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
				}
			end,
		},
	},
	{
		id = "pilgrim_thermal_shock_brittleness_support",
		buff_template = "pilgrim_thermal_shock_brittleness",
		custom = {
			template = function(BS)
				return {
					class_name = "buff",
					duration = 6,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					refresh_duration_on_stack = true,
					stat_buffs = {
						[BS.stat_buffs.rending_multiplier] = 0.20,
					},
				}
			end,
		},
	},
	{
		id = "pilgrim_hot_blood_effect_support",
		buff_template = "pilgrim_hot_blood_effect",
		custom = {
			template = _timed_stat_template(3, 3, { movement_speed = 0.05 }),
		},
	},
	{
		id = "pilgrim_reactive_chemistry_effect_support",
		buff_template = "pilgrim_reactive_chemistry_effect",
		custom = {
			template = _timed_stat_template(3, 1, {
				reload_speed = 0.10,
				melee_attack_speed = 0.10,
			}),
		},
	},
	{
		id = "pilgrim_copper_nerves_effect_support",
		buff_template = "pilgrim_copper_nerves_effect",
		custom = {
			template = _stacking_stat_template(1,
				{ toughness_replenish_modifier = 0.10 }),
		},
	},
	{
		id = "pilgrim_faraday_soul_effect_support",
		buff_template = "pilgrim_faraday_soul_effect",
		custom = {
			template = _stacking_stat_template(1,
				{ damage_taken_modifier = -0.20 }),
		},
	},
	{
		id = "pilgrim_entropy_feast_effect_support",
		buff_template = "pilgrim_entropy_feast_effect",
		custom = {
			-- No gameplay cap is intended. 255 is only a defensive engine
			-- ceiling, far above the number of enemies broadphase can return
			-- inside an 8 metre sphere during ordinary play.
			template = _stacking_stat_template(255, { attack_speed = 0.10 }),
		},
	},
	{
		id = "pilgrim_clean_holster_effect_support",
		buff_template = "pilgrim_clean_holster_effect",
		custom = {
			template = _timed_stat_template(4, 1, { wield_speed = 0.20 }),
		},
	},
	{
		id = "pilgrim_first_to_draw_effect_support",
		buff_template = "pilgrim_first_to_draw_effect",
		custom = {
			template = _timed_stat_template(2, 1,
				{ ranged_attack_speed = 0.15 }),
		},
	},
	{
		id = "pilgrim_moving_target_effect_support",
		buff_template = "pilgrim_moving_target_effect",
		custom = {
			template = _stacking_stat_template(1, { ranged_damage = 0.10 }),
		},
	},
	{
		id = "pilgrim_deadeye_drift_effect_support",
		buff_template = "pilgrim_deadeye_drift_effect",
		custom = {
			template = _stacking_stat_template(1, { ranged_damage = 0.25 }),
		},
	},
	{
		id = "pilgrim_fan_the_hammer_effect_support",
		buff_template = "pilgrim_fan_the_hammer_effect",
		custom = {
			template = _timed_stat_template(3, 1, { ranged_attack_speed = 0.20 }),
		},
	},
	{
		id = "pilgrim_afterimage_effect_support",
		buff_template = "pilgrim_afterimage_effect",
		custom = {
			template = _timed_stat_template(4, 1,
				{ dodge_distance_modifier = 0.10 }),
		},
	},
	{
		id = "pilgrim_executioners_rhythm_effect_support",
		buff_template = "pilgrim_executioners_rhythm_effect",
		custom = {
			template = _timed_stat_template(4, 2, { attack_speed = 0.10 }),
		},
	},
	{
		id = "pilgrim_measured_violence_effect_support",
		buff_template = "pilgrim_measured_violence_effect",
		custom = {
			template = _timed_stat_template(3, 5,
				{ weakspot_power_level_modifier = 0.04 }),
		},
	},
	{
		id = "pilgrim_weakpoint_cartography_effect_support",
		buff_template = "pilgrim_weakpoint_cartography_effect",
		custom = {
			template = _timed_stat_template(4, 5,
				{ rending_multiplier = 0.05 }),
		},
	},
	{
		id = "pilgrim_failure_analysis_effect_support",
		buff_template = "pilgrim_failure_analysis_effect",
		custom = {
			-- A stack contributes to the roll and to the critical damage
			-- calculation. The controller removes all six stacks immediately
			-- after the consuming attack has finished resolving.
			template = _stacking_stat_template(6, {
				critical_strike_chance = 0.05,
				critical_strike_damage = 0.10,
			}),
		},
	},
	{
		id = "pilgrim_hard_to_finish_effect_support",
		buff_template = "pilgrim_hard_to_finish_effect",
		custom = {
			template = function(BS)
				return {
					class_name = "buff",
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					stat_buffs = {
						[BS.stat_buffs.healing_recieved_modifier] = 0.20,
					},
				}
			end,
		},
	},
	{
		id = "pilgrim_last_reserve_effect_support",
		buff_template = "pilgrim_last_reserve_effect",
		custom = {
			template = function(BS)
				return {
					class_name = "buff",
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					stat_buffs = {
						[BS.stat_buffs.toughness_replenish_modifier] = 0.20,
					},
				}
			end,
		},
	},
	{
		id = "pilgrim_refusal_response_guard_support",
		buff_template = "pilgrim_refusal_response_guard",
		custom = {
			template = function(BS)
				return {
					class_name = "buff",
					duration = 3,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					refresh_duration_on_stack = true,
					stat_buffs = {
						[BS.stat_buffs.toughness_damage_taken_multiplier] = 0.50,
					},
				}
			end,
		},
	},
	{
		id = "pilgrim_crushing_tempo_effect_support",
		buff_template = "pilgrim_crushing_tempo_effect",
		custom = {
			template = _timed_stat_template(3, 3, {
				melee_attack_speed = 0.05,
			}),
		},
	},
	{
		id = "pilgrim_grudge_engine_effect_support",
		buff_template = "pilgrim_grudge_engine_effect",
		custom = {
			template = function(BS)
				return {
					class_name = "buff",
					duration = 5,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					refresh_duration_on_stack = true,
					stat_buffs = {
						[BS.stat_buffs.melee_power_level_modifier] = 0.25,
					},
					conditional_keywords = {
						BS.keywords.uninterruptible,
					},
					start_func = function(template_data, template_context)
						local unit_data = ScriptUnit.has_extension(
							template_context.unit, "unit_data_system")
						template_data.inventory = unit_data
							and unit_data:read_component("inventory") or nil
					end,
					conditional_keywords_func = function(template_data)
						return template_data.inventory ~= nil
							and template_data.inventory.wielded_slot == "slot_primary"
					end,
				}
			end,
		},
	},
	{
		id = "pilgrim_grudge_engine_cooldown_support",
		buff_template = "pilgrim_grudge_engine_cooldown",
		custom = {
			template = function()
				return {
					class_name = "buff",
					duration = 10,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
				}
			end,
		},
	},
}

	-- Hidden support template used on enemies marked by Doctrina Override. It is
-- registered for networking, but never enters a shop, draft or loadout list.
M.LEGENDARY_SUPPORT_TEMPLATES = {
	{
		id = "pilgrim_shrapnel_bleed_support",
		buff_template = "pilgrim_shrapnel_bleed",
		custom = {
			template = function()
				local ok, templates = pcall(require,
					"scripts/settings/buff/weapon_buff_templates")
				local base = ok and templates and templates.bleed
				assert(type(base) == "table", "native Bleed template unavailable")
				local clone = {}
				for key, value in pairs(base) do clone[key] = value end
				clone.max_stacks = 30
				clone.max_stacks_cap = 30
				return clone
			end,
		},
	},
	{
		id = "pilgrim_toxic_fog_debuff_support",
		buff_template = "pilgrim_toxic_fog_debuff",
		custom = {
			template = function(BS)
				return {
					class_name = "interval_buff",
					interval = 0.5,
					start_interval_on_apply = true,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					keywords = { BS.keywords.toxin },
					stat_buffs = {
						[BS.stat_buffs.attack_speed] = -0.20,
						[BS.stat_buffs.movement_speed] = -0.15,
						[BS.stat_buffs.damage_taken_modifier] = 0.15,
					},
					interval_func = function(template_data, template_context,
							template, time_since_start, t)
						if not template_context.is_server then return end
						_apply_ailment_stacks(template_context.unit,
							"neurotoxin_interval_buff", 1, t,
							template_context.owner_unit)
					end,
				}
			end,
		},
	},
	{
		id = "pilgrim_armourbane_vulnerability_support",
		buff_template = "pilgrim_armourbane_vulnerability",
		custom = {
			template = function(BS)
				return {
					class_name = "buff",
					duration = 8,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					refresh_duration_on_stack = true,
					stat_buffs = {
						[BS.stat_buffs.rending_multiplier] = 0.40,
					},
				}
			end,
		},
	},
	{
		id = "pilgrim_cleansing_flame_guard_support",
		buff_template = "pilgrim_cleansing_flame_guard",
		custom = {
			template = function(BS)
				return {
					class_name = "buff",
					duration = 0.5,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					refresh_duration_on_stack = true,
					stat_buffs = {
						[BS.stat_buffs.damage_taken_modifier] = -0.25,
					},
				}
			end,
		},
	},
	{
		id = "pilgrim_doctrina_override_mark_support",
		buff_template = "pilgrim_doctrina_override_mark",
		custom = {
			template = function(BS)
				return {
					class_name = "server_only_proc_buff",
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					refresh_duration_on_stack = true,
					duration = 5,
					proc_events = { [BS.proc_events.on_minion_damage_taken] = 1 },
					check_proc_func = function(params, template_data, template_context)
						return template_context.is_server
							and params.damage_profile_name ~= SECONDARY_DAMAGE_PROFILE_NAME
							and (params.damage_amount or 0) > 0
					end,
					proc_func = function(params, template_data, template_context)
						local owner = params.attacking_unit_owner_unit
							or params.attacking_unit or template_context.owner_unit
						local side_source = owner or template_context.owner_unit
						local target = _nearest_enemy_in_radius(side_source,
							template_context.unit, 8, template_context.unit)
						if target and owner then
							_deal_secondary_damage(target, owner,
								(params.damage_amount or 0) * 0.25, "electrocution")
						end
					end,
				}
			end,
		},
	},
	{
		id = "pilgrim_word_carries_guard_support",
		buff_template = "pilgrim_word_carries_guard",
		custom = {
			template = function(BS)
				return {
					class_name = "buff",
					duration = 5,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					refresh_duration_on_stack = true,
					stat_buffs = {
						[BS.stat_buffs.toughness_damage_taken_multiplier] = 0.50,
					},
				}
			end,
		},
	},
	{
		id = "pilgrim_lights_out_forever_debuff_support",
		buff_template = "pilgrim_lights_out_forever_debuff",
		custom = {
			template = function(BS)
				return {
					class_name = "buff",
					duration = 10,
					max_stacks = 1,
					max_stacks_cap = 1,
					predicted = false,
					refresh_duration_on_stack = true,
					-- Darktide's combat-range extension treats this keyword as
					-- a hard melee order. This support buff deliberately omits
					-- the native Taunt start function, so it changes weapon choice
					-- without stealing aggro from the operative who was targeted.
					keywords = { BS.keywords.taunted },
					stat_buffs = {
						[BS.stat_buffs.melee_attack_speed] = -0.50,
					},
				}
			end,
		},
	},
	{
		id = "pilgrim_tesla_doctrine_shock_support",
		buff_template = "pilgrim_tesla_doctrine_shock",
		custom = {
			template = function()
				local ok, templates = pcall(require,
					"scripts/settings/buff/liquid_area_buff_templates")
				local base = ok and templates and templates.shock_trap_liquid_area
				assert(type(base) == "table", "native Shock Trap liquid buff unavailable")
				local clone = {}
				for key, value in pairs(base) do clone[key] = value end
				clone.interval = 0.5
				clone.start_with_frame_offset = false
				return clone
			end,
		},
	},
}

-- ===========================================================================
-- v0.27.0: custom Legendary runtime integrations.
-- ===========================================================================

local function _unit_has_buff(unit, template_name)
	if not unit or not ALIVE[unit] then return false end
	local extension = ScriptUnit.has_extension(unit, "buff_system")
	if not extension then return false end
	local ok, has = pcall(extension.has_buff_using_buff_template,
		extension, template_name)
	return ok and has == true
end

-- Projectile attacks often expose the projectile as `attacking_unit` and omit
-- the optional owner argument. Resolve it through Darktide's native utility so
-- missile and Chordclaw effects always consult the operative who owns the hit.
function M._resolve_attacking_owner(attacking_unit, explicit_owner)
	if explicit_owner and ALIVE[explicit_owner] then return explicit_owner end
	if not attacking_unit then return nil end
	if M._attacking_unit_resolver == nil then
		local ok, resolver = pcall(require,
			"scripts/utilities/attack/attacking_unit_resolver")
		M._attacking_unit_resolver = ok and resolver or false
	end
	local resolver = M._attacking_unit_resolver
	if resolver and type(resolver.resolve) == "function" then
		local ok, owner = pcall(resolver.resolve, attacking_unit)
		if ok and owner then return owner end
	end
	return attacking_unit
end

function M._scale_explosion_value(value, multiplier)
	if type(value) == "number" then return value * multiplier end
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, item in pairs(value) do
		copy[key] = type(item) == "number" and item * multiplier or item
	end
	return copy
end

-- Shrapnel's radius is changed on a per-explosion clone. A global stat buff
-- would also enlarge unrelated scalable blasts, so it still requires both its
-- exact native explosion template and its owner marker. Flak Cannon no longer
-- changes radius; its cover bypass is injected into the native explosion call.
function M._flak_cannon_explosion_template(attacking_unit, template)
	if type(template) ~= "table" then return template end
	local owner = M._resolve_attacking_owner(attacking_unit)
	local multiplier
	if template.name == "frag_grenade"
		and _unit_has_buff(owner, "pilgrim_legendary_shrapnel_doctrine") then
		multiplier = 1.30
	end
	if not multiplier then return template end
	local copy = {}
	for key, value in pairs(template) do copy[key] = value end
	for _, key in ipairs({ "radius", "min_radius", "close_radius",
		"min_close_radius" }) do
		copy[key] = M._scale_explosion_value(template[key], multiplier)
	end
	return copy
end

-- Darktide normally raycasts from each explosion target back to the blast and
-- rejects targets behind static cover. The native ignore_cover argument skips
-- that one raycast while preserving the missile's normal collision point,
-- damage falloff, target filtering and networked explosion presentation.
function M._flak_cannon_ignore_cover(attacking_unit, template, ignore_cover)
	if ignore_cover == true or type(template) ~= "table"
		or template.name ~= "broker_missile_launcher" then
		return ignore_cover
	end
	local owner = M._resolve_attacking_owner(attacking_unit)
	if _unit_has_buff(owner, "pilgrim_legendary_flak_cannon") then
		return true
	end
	return ignore_cover
end

-- Tesla Doctrine deliberately reuses the native Shock Trap liquid template.
-- That keeps its replicated floor coverage, lightning presentation and enemy
-- filtering. The instance cap of 100 hex cells is approximately a four-metre
-- circle; only this spawned instance receives the five-second lifetime.
function M._spawn_tesla_doctrine_field(position, owner, t)
	if not position or not owner or not ALIVE[owner] then return nil end
	local ok_liquid, LiquidArea = pcall(require,
		"scripts/extension_systems/liquid_area/utilities/liquid_area")
	local ok_templates, LiquidAreaTemplates = pcall(require,
		"scripts/settings/liquid_area/liquid_area_templates")
	local nav_manager = Managers.state.nav_mesh
	local nav_world = nav_manager and nav_manager:nav_world()
	local shock_template = ok_templates and LiquidAreaTemplates.shock_trap
	if not (ok_liquid and nav_world and shock_template) then return nil end
	local side_system = Managers.state.extension:system("side_system")
	local side = side_system and side_system.side_by_unit[owner]
	local side_name = side and type(side.name) == "function" and side:name() or nil
	local liquid_unit = LiquidArea.try_create(position, Vector3.down(), nav_world,
		shock_template, owner, 100, false, nil, side_name)
	local liquid_system = Managers.state.extension:system("liquid_area_system")
	local extension_map = liquid_system and liquid_system:unit_to_extension_map()
	local extension = liquid_unit and extension_map and extension_map[liquid_unit]
	if extension then extension._time_to_remove = t + 5 end
	return liquid_unit
end

function M.install_flak_cannon_explosion(Explosion)
	if not _mod or not Explosion or Explosion._pilgrimage_flak_cannon then return end
	Explosion._pilgrimage_flak_cannon = true
	for _, method in ipairs({ "create_explosion", "predict_explosion" }) do
		if type(Explosion[method]) == "function" then
			local hook_method = method
			_mod:hook(Explosion, method,
				function(func, world, physics_world, source_position, rotation,
					attacking_unit, explosion_template, power_level, charge_level,
					attack_type, is_critical_strike, ignore_cover, ...)
					local adjusted = M._flak_cannon_explosion_template(
						attacking_unit, explosion_template)
					local adjusted_ignore_cover = M._flak_cannon_ignore_cover(
						attacking_unit, explosion_template, ignore_cover)
					if hook_method == "create_explosion"
						and explosion_template and explosion_template.name == "shock_grenade"
						and _shared and _shared.is_server and _shared.is_server() then
						local owner = M._resolve_attacking_owner(attacking_unit)
						if _unit_has_buff(owner, "pilgrim_legendary_sacred_current") then
							M._trigger_sacred_current(source_position, owner,
								_fixed_time())
						end
					end
					if hook_method == "create_explosion"
						and explosion_template and explosion_template.name == "arc_grenade"
						and _shared and _shared.is_server and _shared.is_server() then
						local owner = M._resolve_attacking_owner(attacking_unit)
						if _unit_has_buff(owner, "pilgrim_legendary_tesla_doctrine") then
							M._spawn_tesla_doctrine_field(source_position, owner,
								_fixed_time())
						end
					end
					return func(world, physics_world, source_position, rotation,
						attacking_unit, adjusted, power_level, charge_level,
						attack_type, is_critical_strike, adjusted_ignore_cover, ...)
				end)
		end
	end
end

-- HitReaction drops a luggable by asking its weapon template whether it should
-- be retained on damage. Returning a private shallow clone here changes that
-- answer only for the operative carrying Duty Unto Death. Disabled states such
-- as nets, pounces, ledge hangs and knockdowns call drop_luggable directly, so
-- those necessary failure states remain intact.
function M._duty_unto_death_luggable_template(unit, slot_name, template)
	if slot_name ~= "slot_luggable" or type(template) ~= "table"
		or not _unit_has_buff(unit, "pilgrim_boon_krieg_doctrine") then
		return template
	end
	local copy = {}
	for key, value in pairs(template) do copy[key] = value end
	copy.retain_luggable_when_damaged = true
	return copy
end

function M.install_duty_unto_death_luggable(PlayerUnitVisualLoadoutExtension)
	if not _mod or not PlayerUnitVisualLoadoutExtension
		or PlayerUnitVisualLoadoutExtension._pilgrimage_duty_unto_death then return end
	PlayerUnitVisualLoadoutExtension._pilgrimage_duty_unto_death = true
	_mod:hook(PlayerUnitVisualLoadoutExtension, "weapon_template_from_slot",
		function(func, self, slot_name, ...)
			local template, slot = func(self, slot_name, ...)
			return M._duty_unto_death_luggable_template(
				self._unit, slot_name, template), slot
		end)
end

-- A native Shock Trap varies its pulse between 0.3 and 0.8 seconds. For the
-- field spawned by Tesla Doctrine alone, route entrants to a registered clone
-- with an exact 0.5-second interval. Restoring the member immediately after
-- the native collision pass leaves expedition Shock Traps unchanged.
function M.install_tesla_liquid_area_extension(LiquidAreaExtension)
	if not _mod or not LiquidAreaExtension
		or LiquidAreaExtension._pilgrimage_tesla_doctrine then return end
	LiquidAreaExtension._pilgrimage_tesla_doctrine = true
	_mod:hook(LiquidAreaExtension, "_update_collision_detection",
		function(func, self, t, ...)
			local native_name = self._in_liquid_buff_template_name
			local tesla = self._area_template_name == "shock_trap"
				and _unit_has_buff(self._source_unit,
					"pilgrim_legendary_tesla_doctrine")
			if tesla then
				self._in_liquid_buff_template_name =
					"pilgrim_tesla_doctrine_shock"
			end
			local result = func(self, t, ...)
			self._in_liquid_buff_template_name = native_name
			return result
		end)
end

-- SmokeFogExtension owns entry, exit and destruction cleanup for each fog
-- instance. Attaching one externally-controlled debuff per instance preserves
-- overlapping smoke correctly and removes only this mod's contribution.
function M.install_toxic_fog_smoke(SmokeFogExtension)
	if not _mod or not SmokeFogExtension
		or SmokeFogExtension._pilgrimage_toxic_fog then return end
	SmokeFogExtension._pilgrimage_toxic_fog = true
	_mod:hook(SmokeFogExtension, "on_unit_enter", function(func, self, unit, t)
		local result = func(self, unit, t)
		local owner = self.owner_unit
		if not _unit_has_buff(owner, "pilgrim_legendary_toxic_fog")
			or not HEALTH_ALIVE[unit] then return result end
		local side_system = Managers.state.extension:system("side_system")
		local owner_side = side_system and side_system.side_by_unit[owner]
		local target_side = side_system and side_system.side_by_unit[unit]
		if not owner_side or not target_side
			or not side_system:is_enemy_by_side(owner_side, target_side) then
			return result
		end
		local extension = ScriptUnit.has_extension(unit, "buff_system")
		if not extension
			or type(extension.add_externally_controlled_buff) ~= "function" then
			return result
		end
		local ok, _, local_index, component_index = pcall(
			extension.add_externally_controlled_buff, extension,
			"pilgrim_toxic_fog_debuff", t, "owner_unit", owner)
		if ok then
			self._pilgrimage_toxic_fog_units = self._pilgrimage_toxic_fog_units or {}
			self._pilgrimage_toxic_fog_units[unit] = {
				local_index = local_index,
				component_index = component_index,
			}
		end
		return result
	end)
	_mod:hook(SmokeFogExtension, "on_unit_exit", function(func, self, unit, t)
		local affected = self._pilgrimage_toxic_fog_units
		local indices = affected and affected[unit]
		if indices then
			local extension = ScriptUnit.has_extension(unit, "buff_system")
			if extension
				and type(extension.remove_externally_controlled_buff) == "function" then
				pcall(extension.remove_externally_controlled_buff, extension,
					indices.local_index, indices.component_index)
			end
			affected[unit] = nil
		end
		return func(self, unit, t)
	end)
end

-- Fatshark already builds durationless, non-exclusive field variants for all
-- three standard combat stimms. Adding those variants to this one field keeps
-- their native stats, particles, duration handling and cleanup behavior.
function M.install_overdose_stimm_field(ProximityBrokerStimmField)
	if not _mod or not ProximityBrokerStimmField
		or ProximityBrokerStimmField._pilgrimage_overdose then return end
	ProximityBrokerStimmField._pilgrimage_overdose = true
	_mod:hook(ProximityBrokerStimmField, "init",
		function(func, self, logic_context, init_data, owner_unit, ...)
			local result = func(self, logic_context, init_data, owner_unit, ...)
			local has_overdose = _unit_has_buff(owner_unit,
				"pilgrim_legendary_overdose")
			local has_medicae_mandate = _unit_has_buff(owner_unit,
				"pilgrim_epione_medicae_mandate")
			if not has_overdose and not has_medicae_mandate then
				return result
			end
			self._buffs_to_add = self._buffs_to_add or {}
			local present = {}
			for i = 1, #(self._buffs_to_add or {}) do
				present[self._buffs_to_add[i]] = true
			end
			if has_overdose then
				for _, name in ipairs({
					"syringe_speed_boost_buff_stimm_field",
					"syringe_ability_boost_buff_stimm_field",
					"syringe_power_boost_buff_stimm_field",
				}) do
					if not present[name] then
						self._buffs_to_add[#self._buffs_to_add + 1] = name
						present[name] = true
					end
				end
			end
			if has_medicae_mandate
				and not present.pilgrim_epione_medicae_field_heal then
				self._buffs_to_add[#self._buffs_to_add + 1] =
					"pilgrim_epione_medicae_field_heal"
			end
			return result
		end)
end

-- Standing Order extends the two native Nuncio-Aquila recipient buffs rather
-- than running a second proximity scan. Each buff already carries the drone
-- owner's unit in template_context, so overlapping Arbites fields retain the
-- correct ownership and the protection disappears with the field naturally.
function M.install_adamant_legendary_templates(templates)
	if type(templates) ~= "table" then return end
	local ok_bs, BS = pcall(require, "scripts/settings/buff/buff_settings")
	if not ok_bs then return end
	for _, name in ipairs({ "adamant_drone_base_buff", "adamant_drone_improved_buff" }) do
		local template = templates[name]
		if template and not template._pilgrimage_standing_order then
			template._pilgrimage_standing_order = true
			local conditional = template.conditional_keywords or {}
			local wanted = {
				BS.keywords.stun_immune,
				BS.keywords.count_as_dodge_vs_chaos_hound_pounce,
				BS.keywords.count_as_dodge_vs_netgunner,
			}
			for i = 1, #wanted do
				local token = wanted[i]
				local present = token == nil
				for j = 1, #conditional do
					if conditional[j] == token then present = true break end
				end
				local constants = template.keywords or {}
				for j = 1, #constants do
					if constants[j] == token then present = true break end
				end
				if not present then conditional[#conditional + 1] = token end
			end
			template.conditional_keywords = conditional
			local old_condition = template.conditional_keywords_func
			template.conditional_keywords_func = function(data, context, ...)
				local native = old_condition and old_condition(data, context, ...) or false
				return native or _unit_has_buff(context.owner_unit,
					"pilgrim_legendary_standing_order")
			end
		end
	end
end

function M._deal_voltaic_web_arc(target, owner, t)
	if not M._voltaic_arc_dependencies then
		local ok_attack, Attack = pcall(require, "scripts/utilities/attack/attack")
		local ok_profiles, Profiles = pcall(require,
			"scripts/settings/damage/damage_profile_templates")
		local ok_attack_settings, AttackSettings = pcall(require,
			"scripts/settings/damage/attack_settings")
		local ok_damage_settings, DamageSettings = pcall(require,
			"scripts/settings/damage/damage_settings")
		if not (ok_attack and ok_profiles and ok_attack_settings
			and ok_damage_settings and Profiles.discharge_chain_jump_damage) then
			return false
		end
		M._voltaic_arc_dependencies = {
			attack = Attack,
			profile = Profiles.discharge_chain_jump_damage,
			attack_type = AttackSettings.attack_types.arc,
			damage_type = DamageSettings.damage_types.arc_chain,
		}
	end
	if not HEALTH_ALIVE[target] or not ALIVE[owner] then return false end
	local deps = M._voltaic_arc_dependencies
	local target_position = POSITION_LOOKUP[target]
	local owner_position = POSITION_LOOKUP[owner]
	local direction = Vector3.up()
	if target_position and owner_position
		and Vector3.distance_squared(target_position, owner_position) > 0.001 then
		direction = Vector3.normalize(target_position - owner_position)
	end
	local ok = pcall(deps.attack.execute, target, deps.profile,
		"power_level", 500,
		"damage_type", deps.damage_type,
		"attack_type", deps.attack_type,
		"attacking_unit", owner,
		"attack_direction", direction)
	local extension = ScriptUnit.has_extension(target, "buff_system")
	if extension and type(extension.add_internally_controlled_buff) == "function" then
		pcall(extension.add_internally_controlled_buff, extension,
			"discharge_arc_electrocution", t, "owner_unit", owner)
		pcall(extension.add_internally_controlled_buff, extension,
			"arc_ability_spread_target", t, "owner_unit", owner)
	end
	return ok
end

function M._voltaic_web_chain(mine, t)
	local owner = mine and mine._owner_unit_or_nil
	local origin = mine and mine._unit and POSITION_LOOKUP[mine._unit]
	local broadphase = mine and mine._broadphase
	if not owner or not ALIVE[owner] or not origin or not broadphase then return end
	local ok_state, MinionState = pcall(require, "scripts/utilities/minion_state")
	local ok_bs, BS = pcall(require, "scripts/settings/buff/buff_settings")
	if not (ok_state and ok_bs) then return end
	local results = {}
	local count = broadphase.query(broadphase, origin, 4.2, results,
		mine._enemy_side_names)
	local candidates = {}
	for i = 1, count do
		local target = results[i]
		local extension = HEALTH_ALIVE[target]
			and ScriptUnit.has_extension(target, "buff_system")
		if extension and MinionState.is_electrocuted(extension,
			BS.group_keywords.electrocuted) then
			candidates[#candidates + 1] = target
		end
	end
	if #candidates < 2 then return end
	table.sort(candidates, function(a, b)
		return Vector3.distance_squared(origin, POSITION_LOOKUP[a])
			< Vector3.distance_squared(origin, POSITION_LOOKUP[b])
	end)
	local visited = { [candidates[1]] = true }
	local current = candidates[1]
	for _ = 1, 4 do
		local current_position = POSITION_LOOKUP[current]
		local nearest, nearest_distance
		for i = 1, #candidates do
			local target = candidates[i]
			local position = not visited[target] and POSITION_LOOKUP[target]
			if position then
				local distance = Vector3.distance_squared(current_position, position)
				if distance <= 144 and (not nearest_distance or distance < nearest_distance) then
					nearest, nearest_distance = target, distance
				end
			end
		end
		if not nearest then break end
		visited[nearest] = true
		M._deal_voltaic_web_arc(nearest, owner, t)
		current = nearest
	end
end

-- ProximityShockMine owns the real arming, radius and lifetime rules. The
-- wrapper changes only an instance whose owner carries Voltaic Web. The game
-- resets lifetime when a mine first finds a target, so both initialization and
-- that transition receive the promised extra six seconds.
function M.install_voltaic_web_mine(ProximityShockMine)
	if not _mod or not ProximityShockMine
		or ProximityShockMine._pilgrimage_voltaic_web then return end
	ProximityShockMine._pilgrimage_voltaic_web = true
	_mod:hook(ProximityShockMine, "init",
		function(func, self, logic_context, init_data, owner_unit, ...)
			local result = func(self, logic_context, init_data, owner_unit, ...)
			if _unit_has_buff(owner_unit, "pilgrim_legendary_voltaic_web") then
				self._pilgrimage_voltaic_owner = true
				local arming_time = tonumber(self._arming_time) or 0
				self._arming_time = 0
				self._life_time = math.max(0,
					(tonumber(self._life_time) or 0) - arming_time) + 6
			end
			return result
		end)
	_mod:hook(ProximityShockMine, "_apply_buffs", function(func, self, t)
		if not self._pilgrimage_voltaic_owner then return func(self, t) end
		local due = self._started and t >= (self._buff_trigger_t or math.huge)
		local was_dealing = self._started_dealing_damage
		local broadphase = self._broadphase
		local proxy = setmetatable({
			query = function(_, position, radius, results, side_names, ...)
				return broadphase.query(broadphase, position, radius * 1.40,
					results, side_names, ...)
			end,
		}, { __index = function(_, key) return broadphase[key] end })
		self._broadphase = proxy
		local ok, result = pcall(func, self, t)
		self._broadphase = broadphase
		if not ok then error(result) end
		if not was_dealing and self._started_dealing_damage then
			self._life_time = (tonumber(self._life_time) or 0) + 6
		end
		if due then M._voltaic_web_chain(self, t) end
		return result
	end)
end

-- PlayerCharacterStateStunned calls this whenever the engine accepts a real
-- player stagger. The cooldown is another hidden buff, which means death and
-- rescue naturally clear both the retaliation window and its local timer.
function M.trigger_grudge_engine(unit)
	if not unit or not ALIVE[unit]
		or not (_shared and _shared.is_server and _shared.is_server())
		or not _unit_has_buff(unit, "pilgrim_family_grudge_engine")
		or _unit_has_buff(unit, "pilgrim_grudge_engine_cooldown") then
		return false
	end
	local extension = ScriptUnit.has_extension(unit, "buff_system")
	if not extension
		or type(extension.add_internally_controlled_buff) ~= "function" then
		return false
	end
	local t = _fixed_time()
	local ok_effect = pcall(extension.add_internally_controlled_buff,
		extension, "pilgrim_grudge_engine_effect", t)
	local ok_cooldown = pcall(extension.add_internally_controlled_buff,
		extension, "pilgrim_grudge_engine_cooldown", t)
	return ok_effect and ok_cooldown
end

local function _unit_is_boss(unit)
	local unit_data = unit and ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = unit_data and unit_data:breed()
	local tags = breed and breed.tags or {}
	return tags.monster == true or tags.captain == true
		or tags.cultist_captain == true
end

-- Exact runtime names for the ordinary enemies approved for Juggernaut's Wake.
-- Keeping this as an allowlist is deliberate: new enemies and mutator variants
-- default to the +40% fallback until their safety and role are reviewed.
local JUGGERNAUT_EXECUTE_BREEDS = {
	chaos_newly_infected = true,
	chaos_poxwalker = true,
	cultist_assault = true,
	cultist_melee = true,
	renegade_assault = true,
	renegade_melee = true,
	renegade_rifleman = true,
	renegade_sniper = true,
	renegade_netgunner = true,
}

local function _juggernaut_can_execute(unit)
	local unit_data = unit and ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = unit_data and unit_data:breed()
	return breed ~= nil and JUGGERNAUT_EXECUTE_BREEDS[breed.name] == true
end

local _stamina_utility
function _unstoppable_family.load_stamina_utility()
	if _stamina_utility == nil then
		local ok, Stamina = pcall(require, "scripts/utilities/attack/stamina")
		_stamina_utility = ok and Stamina or false
	end
	return _stamina_utility
end

local function _restore_all_stamina(unit)
	local Stamina = _unstoppable_family.load_stamina_utility()
	if Stamina and type(Stamina.add_stamina_percent) == "function" then
		pcall(Stamina.add_stamina_percent, unit, 1)
	end
end

function _unstoppable_family.restore_one_stamina(unit)
	local Stamina = _unstoppable_family.load_stamina_utility()
	if Stamina and type(Stamina.add_stamina) == "function" then
		pcall(Stamina.add_stamina, unit, 1)
	end
end

-- Native melee sweeps and pushes number their targets from one for each action.
-- These weak-key windows follow that sequence across adjacent fixed frames, so
-- slow wide sweeps still count as one attack. A same-frame fallback covers any
-- custom melee source that omits Darktide's target index metadata.
function _unstoppable_family.attack_window(owner, t, attack_type, sequence)
	local state = _unstoppable_family.attack_windows[owner]
	if not state then
		state = { force_ready_at = 0 }
		_unstoppable_family.attack_windows[owner] = state
	end
	local starts_new_attack = sequence ~= nil
		and (sequence <= 1 or state.attack_type ~= attack_type
			or state.last_sequence == nil or sequence <= state.last_sequence)
	local fallback_new_frame = sequence == nil and state.frame_t ~= t
	if starts_new_attack or fallback_new_frame then
		state.frame_t = t
		state.attack_type = attack_type
		state.staggered = {}
		state.killed = {}
		state.force_triggered = false
		state.follow_triggered = false
	end
	state.last_sequence = sequence
	return state
end

function _unstoppable_family.record_attack_result(owner, target, attack_type,
		attack_result, stagger_result, target_index, target_number)
	if not owner or not target then return end
	local is_melee = attack_type == "melee"
	local is_melee_or_push = is_melee or attack_type == "push"
	if not is_melee_or_push then return end
	local t = _fixed_time()
	local sequence = attack_type == "melee" and target_index or target_number
	local state = _unstoppable_family.attack_window(owner, t, attack_type,
		tonumber(sequence))

	if stagger_result == "stagger"
		and _unit_has_buff(owner, "pilgrim_family_force_returned")
		and not state.staggered[target] then
		state.staggered[target] = true
		local count = 0
		for _ in pairs(state.staggered) do count = count + 1 end
		if count >= 3 and not state.force_triggered
			and t >= (state.force_ready_at or 0) then
			state.force_triggered = true
			state.force_ready_at = t + 3
			_replenish_toughness(owner, 0.10, "pilgrim_force_returned")
		end
	end

	if is_melee and attack_result == "died"
		and _unit_has_buff(owner, "pilgrim_family_follow_through")
		and not state.killed[target] then
		state.killed[target] = true
		local count = 0
		for _ in pairs(state.killed) do count = count + 1 end
		if count >= 2 and not state.follow_triggered then
			state.follow_triggered = true
			_unstoppable_family.restore_one_stamina(owner)
		end
	end
end

-- Secondary Legendary damage is applied after the triggering hit has already
-- passed through armour and difficulty scaling. Dealing that exact number here
-- prevents a ricochet or arc from being reduced by armour a second time. The
-- local clone keeps the required behavior, but retains a shipped network-safe
-- name. Doctrina excludes that reflection name to prevent recursive arcs.
local _secondary_damage_profile
local _damage_utility
local _breed_utility
local _attack_settings
local _damage_settings

local function _legendary_runtime_dependencies()
	if _damage_utility then return true end
	local ok_damage, Damage = pcall(require, "scripts/utilities/attack/damage")
	local ok_breed, Breed = pcall(require, "scripts/utilities/breed")
	local ok_attack, AttackSettings = pcall(require,
		"scripts/settings/damage/attack_settings")
	local ok_types, DamageSettings = pcall(require,
		"scripts/settings/damage/damage_settings")
	local ok_profiles, DamageProfiles = pcall(require,
		"scripts/settings/damage/damage_profile_templates")
	if not (ok_damage and ok_breed and ok_attack and ok_types and ok_profiles) then
		return false
	end
	local base_profile = DamageProfiles[SECONDARY_DAMAGE_PROFILE_NAME]
	if type(base_profile) ~= "table" then return false end
	_secondary_damage_profile = {}
	for key, value in pairs(base_profile) do
		_secondary_damage_profile[key] = value
	end
	_secondary_damage_profile.name = SECONDARY_DAMAGE_PROFILE_NAME
	_secondary_damage_profile.skip_on_hit_proc = true
	_secondary_damage_profile.ignore_toughness = true
	_secondary_damage_profile.unblockable = true
	_damage_utility = Damage
	_breed_utility = Breed
	_attack_settings = AttackSettings
	_damage_settings = DamageSettings
	return true
end

_for_each_enemy_at_position = function(side_source, origin, radius, excluded_unit,
		callback)
	if not side_source or not origin or type(callback) ~= "function" then return end
	local extension_manager = Managers.state.extension
	local side_system = extension_manager and extension_manager:system("side_system")
	local side = side_system and side_system.side_by_unit[side_source]
	local broadphase_system = extension_manager and extension_manager:system("broadphase_system")
	local broadphase = broadphase_system and broadphase_system.broadphase
	if not side or not broadphase or not origin then return end

	local results = {}
	local enemy_side_names = side:relation_side_names("enemy")
	local count = broadphase.query(broadphase, origin, radius, results, enemy_side_names)
	for i = 1, count do
		local target = results[i]
		if target ~= excluded_unit and HEALTH_ALIVE[target] then callback(target) end
	end
end

_for_each_enemy_in_radius = function(side_source, origin_unit, radius,
		excluded_unit, callback)
	local origin = origin_unit and POSITION_LOOKUP[origin_unit]
	return _for_each_enemy_at_position(side_source, origin, radius, excluded_unit,
		callback)
end

_nearest_enemy_at_position = function(side_source, origin, radius, excluded_unit,
		predicate)
	if not origin then return nil end
	local nearest, nearest_distance
	_for_each_enemy_at_position(side_source, origin, radius, excluded_unit,
		function(target)
			if predicate and not predicate(target) then return end
			local position = POSITION_LOOKUP[target]
			if not position then return end
			local distance = Vector3.distance_squared(origin, position)
			if not nearest_distance or distance < nearest_distance then
				nearest = target
				nearest_distance = distance
			end
		end)
	return nearest
end

_nearest_enemy_in_radius = function(side_source, origin_unit, radius, excluded_unit,
		predicate)
	local origin = origin_unit and POSITION_LOOKUP[origin_unit]
	return _nearest_enemy_at_position(side_source, origin, radius, excluded_unit,
		predicate)
end

-- Sacred Current launches three independent branches from the detonation. A
-- shared visited set prevents one dense target from being struck repeatedly by
-- the same grenade, while each hop is selected from a fresh six-metre sphere.
function M._trigger_sacred_current(origin, owner, t)
	if not origin or not owner or not ALIVE[owner] then return 0 end
	local visited = {}
	local hits = 0
	for _ = 1, 3 do
		local current_position = origin
		for _ = 1, 4 do
			local target = _nearest_enemy_at_position(owner, current_position, 6,
				nil, function(candidate) return not visited[candidate] end)
			if not target then break end
			visited[target] = true
			if M._deal_voltaic_web_arc(target, owner, t) then hits = hits + 1 end
			current_position = POSITION_LOOKUP[target]
			if not current_position then break end
		end
	end
	return hits
end

_deal_secondary_damage = function(target, source, amount, damage_kind)
	amount = tonumber(amount) or 0
	if amount <= 0 or not target or not source
		or not HEALTH_ALIVE[target] or not ALIVE[source]
		or not _legendary_runtime_dependencies() then return false end

	local breed = _breed_utility.unit_breed_or_nil(target)
	if not breed then return false end
	local target_position = POSITION_LOOKUP[target]
	local source_position = POSITION_LOOKUP[source]
	local direction = Vector3.up()
	if target_position and source_position
		and Vector3.distance_squared(target_position, source_position) > 0.001 then
		direction = Vector3.normalize(target_position - source_position)
	end
	local damage_type = _damage_settings.damage_types[damage_kind or "buff"]
		or _damage_settings.damage_types.buff
	local result = _attack_settings.attack_results.damaged
	local ok = pcall(_damage_utility.deal_damage,
		target, breed, source, source, result, _attack_settings.attack_types.buff,
		_secondary_damage_profile, amount, amount, 0, nil, direction, "torso", nil,
		false, damage_type, target_position, nil, false, 0)
	return ok
end

-- Family reactions care about the moment an ailment is actually
-- accepted by the target, not merely about the hit that attempted to apply it.
-- Several weapons and talents add their ailment after on_hit has already run,
-- so observing MinionBuffExtension is the one ordering-safe seam. The hook's
-- first operation is a three-name lookup; every unrelated buff addition exits
-- immediately without inspecting stacks, units or player state.
local OBSERVED_AILMENTS = {
	flamer_assault = "fire",
	warp_fire = "fire",
	hordes_ailment_shock = "shock",
	bleed = "bleed",
	bleed_long = "bleed",
	hordes_ailment_minion_bleed = "bleed",
}
local FLASHOVER_RADIUS = 5
local _flashover_spreading = false
local _stagger_utility
local _ailment_duration_contributions = setmetatable({}, { __mode = "k" })

local function _named_vararg(wanted, ...)
	local count = select("#", ...)
	for i = 1, count - 1, 2 do
		if select(i, ...) == wanted then return select(i + 1, ...) end
	end
	return nil
end

local function _current_stacks(extension, template_name)
	if not extension or type(extension.current_stacks) ~= "function" then return 0 end
	local ok, stacks = pcall(extension.current_stacks, extension, template_name)
	return ok and tonumber(stacks) or 0
end

local function _extension_has_template(extension, template_name)
	if not extension
		or type(extension.has_buff_using_buff_template) ~= "function" then return false end
	local ok, has = pcall(extension.has_buff_using_buff_template,
		extension, template_name)
	return ok and has == true
end

local function _add_target_buff(extension, template_name, t, owner)
	if not extension
		or type(extension.add_internally_controlled_buff) ~= "function" then return false end
	return pcall(extension.add_internally_controlled_buff, extension,
		template_name, t, "owner_unit", owner)
end

local function _target_max_health(target)
	local extension = ScriptUnit.has_extension(target, "health_system")
	if not extension or type(extension.max_health) ~= "function" then return 0 end
	local ok, value = pcall(extension.max_health, extension)
	return ok and tonumber(value) or 0
end

function M._legendary_percent_or_execute(target, owner, non_boss_fraction,
		boss_fraction)
	local maximum = _target_max_health(target)
	if maximum <= 0 then return false end
	local amount
	if _juggernaut_can_execute(target) then
		-- The reflection profile ignores armour and Toughness. Ten times the
		-- target's real maximum health also clears ordinary difficulty and
		-- mutator damage reductions without teaching this effect about every
		-- possible trash-breed health modifier.
		amount = maximum * 10
	else
		amount = maximum * (_unit_is_boss(target) and boss_fraction
			or non_boss_fraction)
	end
	return _deal_secondary_damage(target, owner, amount, "physical")
end

function M._resolve_no_witnesses(owner, marked)
	if not owner or not ALIVE[owner] or type(marked) ~= "table" then return 0 end
	local resolved = 0
	for target in pairs(marked) do
		if HEALTH_ALIVE[target]
			and M._legendary_percent_or_execute(target, owner, 0.20, 0.05) then
			resolved = resolved + 1
		end
	end
	return resolved
end

-- Infiltrate's own buff owns the authoritative stealth lifetime. We extend its
-- existing start/update/stop callbacks: nearby enemies are remembered in a
-- plain Lua set while invisible, then resolved once after the native stop work.
-- No buff is added to a marked enemy, so merely passing it cannot trigger procs
-- or mutate an enemy's synchronized buff array.
function M.install_no_witnesses_templates(templates)
	if type(templates) ~= "table" or templates._pilgrimage_no_witnesses then return end
	templates._pilgrimage_no_witnesses = true
	local invisibility = templates.veteran_invisibility
	if not invisibility then return end

	local old_start = invisibility.start_func
	local old_update = invisibility.update_func
	local old_stop = invisibility.stop_func
	invisibility.start_func = function(template_data, template_context, ...)
		local result = old_start and old_start(template_data, template_context, ...)
		template_data._pilgrimage_no_witnesses_marks = nil
		template_data._pilgrimage_no_witnesses_scan_t = 0
		if template_context.is_server and _unit_has_buff(template_context.unit,
				"pilgrim_legendary_no_witnesses") then
			template_data._pilgrimage_no_witnesses_marks = {}
		end
		return result
	end
	invisibility.update_func = function(template_data, template_context, dt, t, ...)
		local result = old_update
			and old_update(template_data, template_context, dt, t, ...)
		if not template_context.is_server then return result end
		local owner = template_context.unit
		if not _unit_has_buff(owner, "pilgrim_legendary_no_witnesses") then
			return result
		end
		local now = tonumber(t) or _fixed_time()
		if now < (template_data._pilgrimage_no_witnesses_scan_t or 0) then
			return result
		end
		template_data._pilgrimage_no_witnesses_scan_t = now + 0.10
		local broadphase = template_data.broadphase
		local position = POSITION_LOOKUP[owner]
		local side_names = template_data.enemy_side_names
		if not broadphase or not position or not side_names then return result end
		local marks = template_data._pilgrimage_no_witnesses_marks or {}
		template_data._pilgrimage_no_witnesses_marks = marks
		local nearby = {}
		local count = broadphase.query(broadphase, position, 3, nearby, side_names)
		for i = 1, count do
			local target = nearby[i]
			if HEALTH_ALIVE[target] then marks[target] = true end
		end
		return result
	end
	invisibility.stop_func = function(template_data, template_context,
			extension_destroyed, ...)
		local result = old_stop and old_stop(template_data, template_context,
			extension_destroyed, ...)
		if template_context.is_server and not extension_destroyed
			and _unit_has_buff(template_context.unit,
				"pilgrim_legendary_no_witnesses") then
			M._resolve_no_witnesses(template_context.unit,
				template_data._pilgrimage_no_witnesses_marks)
		end
		template_data._pilgrimage_no_witnesses_marks = nil
		return result
	end
end

function M._trigger_end_of_line(owner, distinct_hits, t)
	if not owner or not ALIVE[owner] then return 0, 0 end
	local origin = POSITION_LOOKUP[owner]
	if not origin then return 0, 0 end
	local radius = math.min(10, 3 + math.max(0,
		tonumber(distinct_hits) or 0) * 0.35)
	if not _stagger_utility then
		local ok, Stagger = pcall(require, "scripts/utilities/attack/stagger")
		_stagger_utility = ok and Stagger or false
	end
	local affected = 0
	_for_each_enemy_at_position(owner, origin, radius, nil, function(target)
		local target_position = POSITION_LOOKUP[target]
		local direction = Vector3.up()
		if target_position
			and Vector3.distance_squared(origin, target_position) > 0.001 then
			direction = Vector3.normalize(target_position - origin)
		end
		if _stagger_utility and type(_stagger_utility.force_stagger) == "function" then
			pcall(_stagger_utility.force_stagger, target, "explosion", direction,
				4, 1, 4, owner)
		end
		if M._legendary_percent_or_execute(target, owner, 0.20, 0.05) then
			affected = affected + 1
		end
	end)

	-- Hordes' resident stagger pulse communicates the endpoint blast without
	-- introducing a custom network effect or depending on a mission package.
	local manager = Managers.state.extension
	local fx = manager and manager:system("fx_system")
	if fx then
		pcall(fx.trigger_wwise_event, fx,
			"wwise/events/player/play_horde_mode_buff_stagger_pulse", origin)
		pcall(fx.trigger_vfx, fx,
			"content/fx/particles/player_buffs/buff_staggering_pulse", origin)
	end
	return affected, radius
end

-- A shield instance owns its own target cooldown table. Two Skitarii can
-- therefore protect the same lane without one player's Legendary suppressing
-- the other's, while rapid fire against one shield is capped at four pulses
-- per second against any individual enemy.
function M._trigger_voltaic_ripple(field, t)
	local owner = field and field._owner_unit
	if not owner or not ALIVE[owner]
		or not _unit_has_buff(owner, "pilgrim_legendary_voltaic_ripples") then
		return 0
	end
	local origin = field._unit and POSITION_LOOKUP[field._unit]
		or POSITION_LOOKUP[owner]
	if not origin then return 0 end
	field._pilgrimage_voltaic_ready = field._pilgrimage_voltaic_ready or {}
	local ready = field._pilgrimage_voltaic_ready
	local hits = 0
	_for_each_enemy_at_position(owner, origin, 2, nil, function(target)
		if t < (ready[target] or 0) then return end
		ready[target] = t + 0.25
		hits = hits + 1
		_deal_secondary_damage(target, owner, 30, "electrocution")
		if HEALTH_ALIVE[target] then
			_apply_ailment_stacks(target, "hordes_ailment_shock", 1, t, owner)
		end
	end)

	-- Reuse the game's own electric shock presentation. The calls are cosmetic
	-- and protected, so a missing effect can never interrupt shield damage.
	local manager = Managers.state.extension
	local fx = manager and manager:system("fx_system")
	if fx then
		pcall(fx.trigger_wwise_event, fx,
			"wwise/events/player/play_horde_mode_buff_electric_shock", origin)
		pcall(fx.trigger_vfx, fx,
			"content/fx/particles/player_buffs/buff_electricity_grenade_01", origin)
	end
	return hits
end

function M.install_voltaic_ripples_force_field(ForceFieldHealthExtension)
	if not _mod or not ForceFieldHealthExtension
		or ForceFieldHealthExtension._pilgrimage_voltaic_ripples then return end
	ForceFieldHealthExtension._pilgrimage_voltaic_ripples = true
	_mod:hook(ForceFieldHealthExtension, "send_stat_data",
		function(func, self, damage_amount, damage_profile, attack_type, ...)
			local result = func(self, damage_amount, damage_profile, attack_type, ...)
			local ranged = attack_type == "ranged"
				or damage_profile and damage_profile.count_as_ranged_attack
			if self._is_server and ranged then
				local t = Managers.time:time("gameplay")
				M._trigger_voltaic_ripple(self, t)
			end
			return result
		end)
end

-- Duration bonuses belong to the player who applied the latest stack. Buff's
-- public extra-duration field can also be used by other systems, so remember
-- only Pilgrimage's contribution and replace that slice instead of clearing the
-- whole field. IntervalBuff multiplies extra duration by its native burning
-- multiplier, hence dividing by that multiplier keeps our 10/25 percentage
-- additive with effects such as Long Burn.
local function _adjust_ailment_duration(extension, template_name, kind, owner)
	local buff = extension and extension._stacking_buffs
		and extension._stacking_buffs[template_name]
	if not buff or type(buff.template) ~= "function"
		or type(buff.extra_duration) ~= "function"
		or type(buff.set_extra_duration) ~= "function" then return end

	local bonus = 0
	if owner and _unit_has_buff(owner, "pilgrim_family_mixed_medium") then
		bonus = bonus + 0.10
	end
	if kind == "shock" and owner
		and _unit_has_buff(owner, "pilgrim_family_residual_charge") then
		bonus = bonus + 0.25
	end
	local ok_template, template = pcall(buff.template, buff)
	local base_duration = ok_template and template and tonumber(template.duration) or 0
	if base_duration <= 0 then return end
	local native_multiplier = math.max(0.01,
		tonumber(buff._duration_bonus_multiplier) or 1)
	local wanted = base_duration * bonus / native_multiplier
	local previous = _ailment_duration_contributions[buff] or 0
	local ok_extra, existing = pcall(buff.extra_duration, buff)
	existing = ok_extra and tonumber(existing) or 0
	if pcall(buff.set_extra_duration, buff,
		math.max(0, existing - previous + wanted)) then
		_ailment_duration_contributions[buff] = wanted
	end
end

local function _trigger_flashover(target, target_extension, owner, t)
	if _flashover_spreading
		or not _unit_has_buff(owner, "pilgrim_family_flashover")
		or _extension_has_template(target_extension, "pilgrim_flashover_spent") then
		return
	end
	local combined = _current_stacks(target_extension, "flamer_assault")
		+ _current_stacks(target_extension, "warp_fire")
	if combined < 20 then return end

	-- Mark before dealing damage. Even a lethal eruption can therefore never
	-- re-enter through another mod's damage callback during the same frame.
	if not _add_target_buff(target_extension, "pilgrim_flashover_spent", t, owner) then
		return
	end
	local damage = _target_max_health(target) * 0.10
	if damage <= 0 then return end
	local nearby = {}
	_for_each_enemy_in_radius(owner, target, FLASHOVER_RADIUS, target,
		function(enemy) nearby[#nearby + 1] = enemy end)

	_deal_secondary_damage(target, owner, damage, "buff")
	_flashover_spreading = true
	local spread_ok, spread_error = pcall(function()
		for i = 1, #nearby do
			local enemy = nearby[i]
			_deal_secondary_damage(enemy, owner, damage, "buff")
			if HEALTH_ALIVE[enemy] then
				_apply_ailment_stacks(enemy, "flamer_assault", 5, t, owner)
				_apply_ailment_stacks(enemy, "warp_fire", 5, t, owner)
			end
		end
	end)
	_flashover_spreading = false
	if not spread_ok then error(spread_error) end
end

local function _trigger_thermal_shock(target, target_extension, owner, t)
	if not _unit_has_buff(owner, "pilgrim_family_thermal_shock")
		or _extension_has_template(target_extension,
			"pilgrim_thermal_shock_cooldown") then return end
	if not _add_target_buff(target_extension,
		"pilgrim_thermal_shock_cooldown", t, owner) then return end
	_add_target_buff(target_extension,
		"pilgrim_thermal_shock_brittleness", t, owner)

	if not _stagger_utility then
		local ok, Stagger = pcall(require, "scripts/utilities/attack/stagger")
		_stagger_utility = ok and Stagger or false
	end
	if not _stagger_utility or type(_stagger_utility.force_stagger) ~= "function" then
		return
	end
	local target_position = POSITION_LOOKUP[target]
	local owner_position = POSITION_LOOKUP[owner]
	local direction = Vector3.up()
	if target_position and owner_position
		and Vector3.distance_squared(target_position, owner_position) > 0.001 then
		direction = Vector3.normalize(target_position - owner_position)
	end
	pcall(_stagger_utility.force_stagger, target, "heavy", direction,
		2, 1, 1, owner)
end

local function _trigger_catalyst(target, target_extension, owner,
		template_name, t)
	if not _unit_has_buff(owner, "pilgrim_family_catalyst")
		or _extension_has_template(target_extension,
			"pilgrim_catalyst_cooldown") then return end
	-- Mark before adding stacks. Those additions pass through this observer too,
	-- but cannot recursively catalyse themselves while the marker is present.
	if not _add_target_buff(target_extension,
		"pilgrim_catalyst_cooldown", t, owner) then return end
	_apply_ailment_stacks(target, template_name, 2, t, owner)
end

local function _trigger_conduction(target, target_extension, owner, t)
	if not _unit_has_buff(owner, "pilgrim_family_conduction")
		or _extension_has_template(target_extension,
			"pilgrim_conduction_cooldown") then return end
	if not _add_target_buff(target_extension,
		"pilgrim_conduction_cooldown", t, owner) then return end
	_deal_secondary_damage(target, owner,
		_target_max_health(target) * 0.10, "physical")
end

local function _after_ailment_added(kind, template_name, target, extension, owner,
		had_fire, had_shock, t)
	if not owner or not ALIVE[owner] or not HEALTH_ALIVE[target] then return end
	if kind == "fire" then _trigger_flashover(target, extension, owner, t) end
	local cross_applied = kind == "fire" and had_shock
		or kind == "shock" and had_fire
	if cross_applied then
		_trigger_thermal_shock(target, extension, owner, t)
		_trigger_conduction(target, extension, owner, t)
		_trigger_catalyst(target, extension, owner, template_name, t)
	end
end

function M.install_family_ailment_observer(MinionBuffExtension)
	if not _mod or MinionBuffExtension._pilgrimage_family_ailments then return end
	MinionBuffExtension._pilgrimage_family_ailments = true
	_mod:hook(MinionBuffExtension, "add_internally_controlled_buff",
		function(func, self, template_name, t, ...)
			local kind = OBSERVED_AILMENTS[template_name]
			if not kind or not self._is_server then
				return func(self, template_name, t, ...)
			end

			local before = _current_stacks(self, template_name)
			local had_fire = _current_stacks(self, "flamer_assault") > 0
				or _current_stacks(self, "warp_fire") > 0
			local had_shock = _current_stacks(self, "hordes_ailment_shock") > 0
			local owner = _named_vararg("owner_unit", ...)
			local result = func(self, template_name, t, ...)
			_adjust_ailment_duration(self, template_name, kind, owner)
			if _current_stacks(self, template_name) > before then
				local ok, err = pcall(_after_ailment_added, kind, template_name, self._unit,
					self, owner, had_fire, had_shock, t)
				if not ok and _debug_log then
					_debug_log("boons", 0,
						"family ailment observer failed: " .. tostring(err), 0, "warn")
				end
			end
			return result
		end)
end

local _shadow_replays = {}
M._warp_resonance_echoes = {}

local function _shadow_attack_should_repeat(attacking_unit, damage_type)
	if not attacking_unit or not _unit_has_buff(attacking_unit,
		"pilgrim_legendary_shadow_emperor") then return false end
	local extension = ScriptUnit.has_extension(attacking_unit, "buff_system")
	if not extension or not extension:has_unique_buff_id("zealot_invisibility") then
		return false
	end
	local ok, BS = pcall(require, "scripts/settings/buff/buff_settings")
	local can_keep_stealth = ok and BS.keywords
		and BS.keywords.can_attack_during_invisibility
		and extension:has_keyword(BS.keywords.can_attack_during_invisibility)
	if can_keep_stealth then return false end
	return damage_type ~= "bleeding" and damage_type ~= "burning"
		and damage_type ~= "grenade_frag" and damage_type ~= "plasma"
		and damage_type ~= "electrocution"
end

function M.update(t)
	if #_shadow_replays > 0 then
		for i = #_shadow_replays, 1, -1 do
			local replay = _shadow_replays[i]
			if not ALIVE[replay.target] or not ALIVE[replay.source] then
				table.remove(_shadow_replays, i)
			elseif t >= replay.at then
				table.remove(_shadow_replays, i)
				if HEALTH_ALIVE[replay.target] then
					_deal_secondary_damage(replay.target, replay.source,
						replay.damage, "buff")
				end
			end
		end
	end

	if #M._warp_resonance_echoes > 0 then
		for i = #M._warp_resonance_echoes, 1, -1 do
			local echo = M._warp_resonance_echoes[i]
			if not ALIVE[echo.player_unit] then
				table.remove(M._warp_resonance_echoes, i)
			elseif t >= echo.at then
				table.remove(M._warp_resonance_echoes, i)
				local ok, err = pcall(M._execute_warp_resonance_echo, echo, t)
				if not ok and _debug_log then
					_debug_log("boons", 0,
						"Warp Resonance echo failed: " .. tostring(err), 0, "warn")
				end

				-- The native player action owns the first Shriek's audiovisuals,
				-- but these delayed enemy-only calls bypass that action. Reuse the
				-- same resident sound alias and particle used by Overwhelming Mind.
				local fx_extension = ScriptUnit.has_extension(echo.player_unit,
					"fx_system")
				if fx_extension then
					pcall(fx_extension.trigger_gear_wwise_event_with_source,
						fx_extension, "ability_shout",
						{ ability_template = "psyker_shout" }, "head", true, true)
					pcall(fx_extension.spawn_particles, fx_extension,
						"content/fx/particles/abilities/psyker_warp_charge_shout",
						echo.position + Vector3.up(), echo.rotation)
				end
			end
		end
	end
end

local function _omnissian_active(unit)
	if not _unit_has_buff(unit, "pilgrim_legendary_target_marked") then return false end
	local extension = ScriptUnit.has_extension(unit, "buff_system")
	local ok, BS = pcall(require, "scripts/settings/buff/buff_settings")
	local keyword = ok and BS.keywords and BS.keywords.cryptic_precision_stance
	return keyword ~= nil and extension:has_keyword(keyword)
end

-- ACD normally spends 1% per shot, drains 10% per second, pauses that drain
-- while reloading, and can receive several refunds. The template wrapper
-- suppresses the shot path, while the ability-extension wrapper allows only
-- the marked 7%-per-second drain through for the lifetime of the stance.
function M.install_omnissian_ability_extension(PlayerUnitAbilityExtension)
	if not _mod or PlayerUnitAbilityExtension._pilgrimage_omnissian then return end
	PlayerUnitAbilityExtension._pilgrimage_omnissian = true

	_mod:hook(PlayerUnitAbilityExtension, "increase_ability_cooldown_percentage",
		function(func, self, ability_type, amount, ...)
			if ability_type == "combat_ability" and _omnissian_active(self._unit) then
				if M._omnissian_native_drain then
					return func(self, ability_type, amount * 0.70, ...)
				elseif M._omnissian_manual_drain then
					return func(self, ability_type, amount, ...)
				end

				-- Return the same shape as the native method without changing
				-- Capacitance. Callers therefore see the real current value.
				local capacitance = self:remaining_ability_capacitance(ability_type)
				local charges = math.floor(capacitance + 0.001)
				local partial = capacitance - charges
				return charges, partial > 0 and 1 - partial or (charges > 0 and 0 or 1)
			end
			return func(self, ability_type, amount, ...)
		end)

	_mod:hook(PlayerUnitAbilityExtension, "reduce_ability_cooldown_percentage",
		function(func, self, ability_type, amount, ...)
			if ability_type == "combat_ability" and _omnissian_active(self._unit) then
				return
			end
			return func(self, ability_type, amount, ...)
		end)
end

function M.install_omnissian_templates(templates)
	if type(templates) ~= "table" then return end
	local ok_cf, ConditionalFunctions = pcall(require,
		"scripts/settings/buff/helper_functions/conditional_functions")
	if not ok_cf then return end
	local ok_bs, BS = pcall(require, "scripts/settings/buff/buff_settings")
	local on_shoot = ok_bs and BS.proc_events and BS.proc_events.on_shoot

	for _, name in ipairs({
		"cryptic_precision_stance_one_charge",
		"cryptic_precision_stance_two_charges",
		"cryptic_precision_stance_three_charges",
	}) do
		local template = templates[name]
		if template and not template._pilgrimage_omnissian then
			template._pilgrimage_omnissian = true
			local old_shoot = on_shoot and template.specific_proc_func
				and template.specific_proc_func[on_shoot]
			if old_shoot then
				template.specific_proc_func[on_shoot] = function(params, data, context, t)
					if _unit_has_buff(context.unit, "pilgrim_legendary_target_marked") then
						return
					end
					return old_shoot(params, data, context, t)
				end
			end

			local old_update = template.update_func
			template.update_func = function(data, context, dt, t)
				if not _unit_has_buff(context.unit, "pilgrim_legendary_target_marked") then
					return old_update(data, context, dt, t)
				end

				local reloading = ConditionalFunctions.is_reloading(data, context)
				if reloading and data.ability_extension then
					local amount = 0.07 * dt
					data.cooldown_percent_used = (data.cooldown_percent_used or 0) + amount
					M._omnissian_manual_drain = true
					local ok, charges, partial = pcall(
						data.ability_extension.increase_ability_cooldown_percentage,
						data.ability_extension, "combat_ability", amount)
					M._omnissian_manual_drain = false
					if ok and charges == 0 and partial >= 1 then data.stop_ability = true end
				end

				M._omnissian_native_drain = not reloading
				local ok, result = pcall(old_update, data, context, dt, t)
				M._omnissian_native_drain = false
				if not ok then error(result) end
				return result
			end
		end
	end
end

local function _for_each_player_in_radius(player_unit, radius, callback)
	local side_system = Managers.state.extension and Managers.state.extension:system("side_system")
	local side = side_system and side_system.side_by_unit[player_unit]
	local origin = POSITION_LOOKUP[player_unit]
	if not side or not origin then return end
	local radius_sq = radius * radius
	local seen = {}

	local function visit(unit)
		if not unit or seen[unit] or not ALIVE[unit] then return end
		seen[unit] = true
		local position = POSITION_LOOKUP[unit]
		if position and Vector3.distance_squared(origin, position) <= radius_sq then
			callback(unit)
		end
	end

	visit(player_unit)
	for i = 1, #(side.player_units or {}) do visit(side.player_units[i]) end
end

local ASSISTABLE_STATES = {
	hogtied = true,
	knocked_down = true,
	ledge_hanging = true,
	netted = true,
}

local DISABLING_STATES = {
	consumed = true,
	grabbed = true,
	mutant_charged = true,
	pounced = true,
	vortex_grabbed = true,
	warp_grabbed = true,
}

local function _word_carries(player_unit, radius, t)
	_for_each_player_in_radius(player_unit, radius, function(unit)
		local buff_extension = ScriptUnit.has_extension(unit, "buff_system")
		if buff_extension then
			buff_extension:add_internally_controlled_buff(
				"pilgrim_word_carries_guard", t, "owner_unit", player_unit)
		end

		local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
		local character_state = unit_data and unit_data:read_component("character_state")
		local state_name = character_state and character_state.state_name
		if ASSISTABLE_STATES[state_name] then
			local assisted = unit_data:write_component("assisted_state_input")
			assisted.force_assist = true
		elseif DISABLING_STATES[state_name] then
			local disabled = unit_data:write_component("disabled_state_input")
			disabled.disabling_unit = nil
		end
	end)
end

function M.install_shout_ability(ShoutAbility)
	if not _mod or ShoutAbility._pilgrimage_legendary_shouts then return end
	ShoutAbility._pilgrimage_legendary_shouts = true
	_mod:hook(ShoutAbility, "execute", function(func, radius, template_name,
		player_unit, t, locomotion_component, shout_direction, ...)
		local optional_position = select(1, ...)
		local optional_rotation = select(2, ...)
		local power_modifier = select(3, ...)
		local result = func(radius, template_name, player_unit, t,
			locomotion_component, shout_direction, ...)
		local buff_extension = ScriptUnit.has_extension(player_unit, "buff_system")
		local stats = buff_extension and buff_extension:stat_buffs() or {}
		local effective_radius = radius * (stats.shout_radius_modifier or 1)

		if template_name == "veteran_shout"
			and _unit_has_buff(player_unit, "pilgrim_legendary_word_carries") then
			_word_carries(player_unit, effective_radius, t)
		end

		-- The exact Psyker target-template name has changed across releases,
		-- while every version retains both words. The narrow name check keeps
		-- Ogryn, Veteran, Zealot, Arbites and companion shouts out.
		local lower_name = string.lower(tostring(template_name or ""))
		local is_psyker_shriek = string.find(lower_name, "psyker", 1, true)
			and string.find(lower_name, "shout", 1, true)
		if is_psyker_shriek
			and _shared and _shared.is_server and _shared.is_server()
			and _unit_has_buff(player_unit,
				"pilgrim_legendary_warp_resonance") then
			local position = optional_position or POSITION_LOOKUP[player_unit]
			local rotation = optional_rotation
			if not rotation then
				local unit_data = ScriptUnit.has_extension(player_unit,
					"unit_data_system")
				local first_person = unit_data
					and unit_data:read_component("first_person")
				rotation = first_person and first_person.rotation
			end
			if position and rotation then
				local cast_t = tonumber(t) or _fixed_time()
				for delay = 1, 2 do
					M._warp_resonance_echoes[#M._warp_resonance_echoes + 1] = {
						at = cast_t + delay,
						radius = effective_radius,
						template_name = template_name,
						player_unit = player_unit,
						direction = shout_direction,
						position = position,
						rotation = rotation,
						power_modifier = power_modifier,
					}
				end
			end
		end
		return result
	end)
end

local function _psyker_shriek(player_unit, kind, t)
	local ok_attack, Attack = pcall(require, "scripts/utilities/attack/attack")
	local ok_profiles, DamageProfiles = pcall(require,
		"scripts/settings/damage/damage_profile_templates")
	local ok_attack_settings, AttackSettings = pcall(require,
		"scripts/settings/damage/attack_settings")
	local ok_damage_settings, DamageSettings = pcall(require,
		"scripts/settings/damage/damage_settings")
	local ok_warp, WarpCharge = pcall(require, "scripts/utilities/warp_charge")
	if not (ok_attack and ok_profiles and ok_attack_settings and ok_damage_settings and ok_warp) then
		return
	end

	local unit_data = ScriptUnit.has_extension(player_unit, "unit_data_system")
	local warp_charge = unit_data and unit_data:write_component("warp_charge")
	local first_person = unit_data and unit_data:read_component("first_person")
	local origin = POSITION_LOOKUP[player_unit]
	if not warp_charge or not origin then return end
	local rotation = first_person and first_person.rotation or Unit.local_rotation(player_unit, 1)
	local forward = Vector3.normalize(Vector3.flat(Quaternion.forward(rotation)))

	local side_system = Managers.state.extension and Managers.state.extension:system("side_system")
	local side = side_system and side_system.side_by_unit[player_unit]
	local broadphase_system = Managers.state.extension and Managers.state.extension:system("broadphase_system")
	local broadphase = broadphase_system and broadphase_system.broadphase
	local num_hits = 0
	if side and broadphase then
		local results = {}
		local enemies = side:relation_side_names("enemy")
		local count = broadphase.query(broadphase, origin, 30, results, enemies)
		for i = 1, count do
			local target = results[i]
			local target_position = POSITION_LOOKUP[target]
			if HEALTH_ALIVE[target] and target_position then
				local offset = Vector3.flat(target_position - origin)
				local distance_sq = Vector3.length_squared(offset)
				local direction = distance_sq > 0 and Vector3.normalize(offset) or forward
				if distance_sq <= 81 or Vector3.dot(forward, direction) > 0.9 then
					num_hits = num_hits + 1
					Attack.execute(target, DamageProfiles.psyker_biomancer_shout,
						"attack_direction", direction,
						"power_level", 1000,
						"hit_zone_name", "torso",
						"damage_type", DamageSettings.damage_types.psyker_biomancer_discharge,
						"attack_type", AttackSettings.attack_types.shout,
						"attacking_unit", player_unit)

					if kind == "soulblaze" then
						local target_buffs = ScriptUnit.has_extension(target, "buff_system")
						if target_buffs then
							target_buffs:add_internally_controlled_buff_with_stacks(
								"warp_fire", 6, t, "owner_unit", player_unit)
						end
					end
				end
			end
		end
	end

	if kind == "soulblaze" then
		WarpCharge.decrease_immediate(0.10, warp_charge, player_unit)
	else
		WarpCharge.decrease_immediate(0.50, warp_charge, player_unit)
		local player_buffs = ScriptUnit.has_extension(player_unit, "buff_system")
		if player_buffs and num_hits > 0 then
			player_buffs:add_internally_controlled_buff_with_stacks(
				"psyker_shout_warp_generation_reduction", math.min(num_hits, 25), t,
				"parent_buff_template", "pilgrim_legendary_overwhelming_mind")
		end
	end

	local fx_extension = ScriptUnit.has_extension(player_unit, "fx_system")
	if fx_extension then
		-- The synthetic Overwhelming Mind casts do not pass through the
		-- predicted player action that normally plays the Shriek sound. Fire
		-- the same gear alias used by action_psyker_shout.lua and include the
		-- owning client because this helper itself only runs on the server.
		pcall(fx_extension.trigger_gear_wwise_event_with_source, fx_extension,
			"ability_shout", { ability_template = "psyker_shout" },
			"head", true, true)
		pcall(fx_extension.spawn_particles, fx_extension,
			"content/fx/particles/abilities/psyker_warp_charge_shout",
			origin + Vector3.up(), rotation)
	end
end

-- A Resonance echo deliberately bypasses ShoutAbility itself. That utility can
-- also announce allied contacts, which would repeat team buffs from other
-- Legendaries. Replaying the native Psyker damage profile directly preserves
-- enemy stagger and on-hit Soulblaze talents while leaving Peril, allies and
-- every player-side ability proc untouched.
function M._execute_warp_resonance_echo(echo, t)
	local player_unit = echo and echo.player_unit
	local origin = echo and echo.position
	local forward = echo and echo.direction
	if not player_unit or not ALIVE[player_unit] or not origin or not forward then
		return 0
	end
	local ok_attack, Attack = pcall(require, "scripts/utilities/attack/attack")
	local ok_profiles, DamageProfiles = pcall(require,
		"scripts/settings/damage/damage_profile_templates")
	local ok_attack_settings, AttackSettings = pcall(require,
		"scripts/settings/damage/attack_settings")
	local ok_damage_settings, DamageSettings = pcall(require,
		"scripts/settings/damage/damage_settings")
	local profile = ok_profiles and DamageProfiles.psyker_biomancer_shout
	if not (ok_attack and ok_attack_settings and ok_damage_settings and profile) then
		return 0
	end

	local side_system = Managers.state.extension:system("side_system")
	local side = side_system and side_system.side_by_unit[player_unit]
	local broadphase_system = Managers.state.extension:system("broadphase_system")
	local broadphase = broadphase_system and broadphase_system.broadphase
	if not side or not broadphase then return 0 end
	local results = {}
	local enemies = side:relation_side_names("enemy")
	local radius = tonumber(echo.radius) or 30
	local count = broadphase.query(broadphase, origin, radius, results, enemies)
	local num_hits = 0
	for i = 1, count do
		local target = results[i]
		local target_position = POSITION_LOOKUP[target]
		if HEALTH_ALIVE[target] and target_position then
			local offset = Vector3.flat(target_position - origin)
			local distance_sq = Vector3.length_squared(offset)
			local direction = distance_sq > 0 and Vector3.normalize(offset) or forward
			if distance_sq <= 81 or Vector3.dot(forward, direction) > 0.9 then
				num_hits = num_hits + 1
				Attack.execute(target, profile,
					"attack_direction", direction,
					"power_level", 1000 * (tonumber(echo.power_modifier) or 1),
					"hit_zone_name", "torso",
					"damage_type",
					DamageSettings.damage_types.psyker_biomancer_discharge,
					"attack_type", AttackSettings.attack_types.shout,
					"attacking_unit", player_unit)
			end
		end
	end
	return num_hits
end

function M.install_overwhelming_mind_templates(templates)
	if type(templates) ~= "table" or templates._pilgrimage_overwhelming_mind then return end
	templates._pilgrimage_overwhelming_mind = true

	local stance = templates.psyker_overcharge_stance
	if stance and stance.stop_func then
		local old_stop = stance.stop_func
		stance.stop_func = function(data, context)
			local at_max = data.warp_charge_component
				and data.warp_charge_component.current_percentage >= 1
			local result = old_stop(data, context)
			if context.is_server and at_max
				and _unit_has_buff(context.unit, "pilgrim_legendary_overwhelming_mind") then
				local ok_fixed, FixedFrame = pcall(require, "scripts/utilities/fixed_frame")
				_psyker_shriek(context.unit, "soulblaze",
					ok_fixed and FixedFrame.get_latest_fixed_time() or 0)
			end
			return result
		end
	end

	local warp_unbound = templates.psyker_overcharge_stance_infinite_casting
	if warp_unbound then
		local old_stop = warp_unbound.stop_func
		warp_unbound.stop_func = function(data, context)
			local result = old_stop and old_stop(data, context)
			if context.is_server
				and _unit_has_buff(context.unit, "pilgrim_legendary_overwhelming_mind") then
				local ok_fixed, FixedFrame = pcall(require, "scripts/utilities/fixed_frame")
				_psyker_shriek(context.unit, "vent",
					ok_fixed and FixedFrame.get_latest_fixed_time() or 0)
			end
			return result
		end
	end
end

function M.install_brain_rupture_targeting(TargetingModule)
	if not _mod or TargetingModule._pilgrimage_unwarded_minds then return end
	TargetingModule._pilgrimage_unwarded_minds = true
	_mod:hook(TargetingModule, "fixed_update", function(func, self, ...)
		local result = func(self, ...)
		if _unit_has_buff(self._player_unit, "pilgrim_legendary_unwarded_minds") then
			local target = self._component and self._component.target_unit_1
			if target and _unit_is_boss(target) then
				self._component.target_unit_1 = nil
				self._component.target_unit_2 = nil
				self._component.target_unit_3 = nil
			end
		end
		return result
	end)
end

local function _attack_arg(name, ...)
	local count = select("#", ...)
	for i = 1, count, 2 do
		if select(i, ...) == name then return select(i + 1, ...) end
	end
	return nil
end

local function _replace_or_append_attack_arg(args, count, name, value)
	for i = 1, count, 2 do
		if args[i] == name then
			args[i + 1] = value
			return count
		end
	end
	args[count + 1] = name
	args[count + 2] = value
	return count + 2
end

function _critical_family.is_enemy(attacker, target)
	local extension_manager = Managers and Managers.state
		and Managers.state.extension
	local side_system = extension_manager
		and extension_manager:system("side_system")
	if not side_system or type(side_system.is_enemy) ~= "function" then
		return true
	end
	local ok, result = pcall(side_system.is_enemy, side_system,
		attacker, target)
	return not ok or result == true
end

function _critical_family.current_critical_chance(unit, attack_type, damage_profile)
	if _critical_family.critical_strike_utility == nil then
		local ok, utility = pcall(require,
			"scripts/utilities/attack/critical_strike")
		_critical_family.critical_strike_utility = ok and utility or false
	end
	if not _critical_family.critical_strike_utility
		or type(_critical_family.critical_strike_utility.chance) ~= "function" then
		return 0
	end
	local spawn_manager = Managers and Managers.state
		and Managers.state.player_unit_spawn
	if not spawn_manager or type(spawn_manager.owner) ~= "function" then
		return 0
	end
	local ok_player, player = pcall(spawn_manager.owner, spawn_manager, unit)
	if not ok_player or not player then return 0 end
	local weapon_extension = ScriptUnit.has_extension(unit, "weapon_system")
	local handling = {}
	if weapon_extension
		and type(weapon_extension.weapon_handling_template) == "function" then
		local ok_handling, value = pcall(
			weapon_extension.weapon_handling_template, weapon_extension)
		if ok_handling and value then handling = value end
	end
	local is_ranged = attack_type == "ranged"
		or (damage_profile and damage_profile.count_as_ranged_attack == true)
	local is_melee = attack_type == "melee"
	local ok_chance, chance = pcall(_critical_family.critical_strike_utility.chance,
		player, handling, is_ranged, is_melee, false)
	return ok_chance and math.clamp(tonumber(chance) or 0, 0, 1) or 0
end

function _critical_family.opening_cut_promotes(attacker, target, attack_type,
		damage_profile, already_critical)
	if not _critical_family.direct_opening_attack_types[attack_type]
		or not _critical_family.is_enemy(attacker, target) then return false end
	local state = _critical_family.opening_states[attacker]
	if not state then return false end
	local now = _shared and _shared.fixed_time
		and _shared.fixed_time() or 0
	local contact = state.seen[target]
	if contact then
		return contact.promoted == true and contact.at == now
	end
	if already_critical then
		state.seen[target] = { promoted = false, at = now }
		return false
	end

	-- The ordinary critical roll has already failed. Re-roll only the
	-- conditional slice needed to make the final probability exactly current
	-- chance + 25 percentage points, capped at 100%.
	local current = _critical_family.current_critical_chance(attacker, attack_type,
		damage_profile)
	local desired = math.min(1,
		current + _critical_family.opening_cut_bonus_chance)
	local conditional = current < 1
		and math.clamp((desired - current) / (1 - current), 0, 1) or 0
	local promoted = math.random() <= conditional
	state.seen[target] = { promoted = promoted, at = now }
	return promoted
end

function _critical_family.coup_de_grace_can_execute(unit)
	if _unit_is_boss(unit) then return false end
	local unit_data = unit and ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = unit_data and unit_data:breed()
	local name = breed and tostring(breed.name) or ""
	if string.find(name, "twin", 1, true) then return false end

	local health = unit and ScriptUnit.has_extension(unit, "health_system")
	if not health or type(health.current_health_percent) ~= "function" then
		return false
	end
	local ok_health, percent = pcall(health.current_health_percent, health)
	if not ok_health or (tonumber(percent) or 1) >= 0.20 then return false end

	local blackboard = BLACKBOARDS and BLACKBOARDS[unit]
	local stagger = blackboard and blackboard.stagger
	return stagger ~= nil and (tonumber(stagger.num_triggered_staggers) or 0) > 0
end

function _critical_family.force_cartography_stagger(target, attacker,
		attack_direction)
	if not attack_direction then return end
	if _critical_family.stagger_utility == nil then
		local ok, utility = pcall(require, "scripts/utilities/attack/stagger")
		_critical_family.stagger_utility = ok and utility or false
	end
	if _critical_family.stagger_settings == nil then
		local ok, settings = pcall(require,
			"scripts/settings/damage/stagger_settings")
		_critical_family.stagger_settings = ok and settings or false
	end
	local types = _critical_family.stagger_settings
		and _critical_family.stagger_settings.stagger_types
	local medium = types and types.medium
	if not _critical_family.stagger_utility or not medium
		or type(_critical_family.stagger_utility.force_stagger) ~= "function" then
		return
	end
	pcall(_critical_family.stagger_utility.force_stagger, target, medium,
		attack_direction, 0.75, 1, 0.5, attacker)
end

-- Chorus Everlasting follows the action's real pulse callback, so every
-- native pulse and only a native pulse applies the ailments. The cap is read
-- from the enemy before each addition, preventing other stack sources from
-- being pushed past twenty by this Legendary.
function M.install_zealot_channel(ActionZealotChannel)
	if not _mod or ActionZealotChannel._pilgrimage_chorus_everlasting then return end
	ActionZealotChannel._pilgrimage_chorus_everlasting = true
	_mod:hook_safe(ActionZealotChannel, "_on_channel_tick",
		function(self, dt, in_coherence_units, t, time_in_action)
			local owner = self._player_unit
			if not owner or not _unit_has_buff(owner,
				"pilgrim_legendary_chorus_everlasting") then return end
			local settings = self._action_settings or {}
			local elapsed = math.min(tonumber(time_in_action) or 0, 5)
			local radius = (tonumber(settings.radius) or 0)
				+ elapsed * (tonumber(settings.radius_time_in_action_multiplier) or 0)
			_for_each_enemy_in_radius(owner, owner, radius, nil, function(enemy)
				local extension = ScriptUnit.has_extension(enemy, "buff_system")
				if not extension then return end
				local burn = math.min(5,
					math.max(0, 20 - _current_stacks(extension, "flamer_assault")))
				local soulfire = math.min(5,
					math.max(0, 20 - _current_stacks(extension, "warp_fire")))
				if burn > 0 then
					_apply_ailment_stacks(enemy, "flamer_assault", burn, t, owner)
				end
				if soulfire > 0 then
					_apply_ailment_stacks(enemy, "warp_fire", soulfire, t, owner)
				end
			end)
		end)
end

function M._fly_trap_blocks(field_health, attacking_unit)
	if not field_health or not attacking_unit then return false end
	local state = M._fly_trap_targets[attacking_unit]
	if not state or state.field ~= field_health._unit then return false end
	local now = _shared and _shared.fixed_time and _shared.fixed_time() or 0
	if now > (state.expires or 0) or not HEALTH_ALIVE[attacking_unit] then
		M._fly_trap_targets[attacking_unit] = nil
		return false
	end
	return true
end

-- The force-field health extension normally converts any accepted hit into
-- one point of wall health. Returning before that conversion protects only
-- against enemies currently pinned by this exact wall. Every other attacker
-- and the wall's normal duration remain untouched.
function M.install_fly_trap_health(PsykerForceFieldUnitHealthExtension)
	if not _mod or PsykerForceFieldUnitHealthExtension._pilgrimage_fly_trap then return end
	PsykerForceFieldUnitHealthExtension._pilgrimage_fly_trap = true
	for _, method in ipairs({ "add_damage", "tried_adding_damage" }) do
		_mod:hook(PsykerForceFieldUnitHealthExtension, method,
			function(func, self, damage_amount, permanent_damage, hit_actor,
				damage_profile, attack_type, attack_direction, attacking_unit, ...)
				if M._fly_trap_blocks(self, attacking_unit) then return end
				return func(self, damage_amount, permanent_damage, hit_actor,
					damage_profile, attack_type, attack_direction, attacking_unit, ...)
			end)
	end
end

function M._bigger_boom_can_execute(unit, hit_zone_name)
	local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = unit_data and unit_data:breed()
	local breed_name = breed and breed.name
	if M.BIGGER_BOOM_TWIN_BREEDS[breed_name] then return false end
	if (breed_name == "renegade_captain" or breed_name == "cultist_captain")
		and hit_zone_name == "captain_void_shield" then
		return false
	end
	return breed_name ~= nil
end

function M._chain_of_custody_promotes(target, profile_name, t)
	if profile_name == SECONDARY_DAMAGE_PROFILE_NAME then return false end
	local expires = M._chain_of_custody_marks[target]
	if not expires then return false end
	M._chain_of_custody_marks[target] = nil
	return t <= expires
end

function M._is_player_attack_owner(unit)
	local manager = Managers and Managers.state
		and Managers.state.player_unit_spawn
	if not manager or type(manager.is_player_unit) ~= "function" then
		return false
	end
	local ok, result = pcall(manager.is_player_unit, manager, unit)
	return ok and result == true
end

function M._mark_chain_of_custody_target(target, t)
	if HEALTH_ALIVE[target] then
		M._chain_of_custody_marks[target] = t + 10
	end
end

function M.install_legendary_attack(Attack)
	if not _mod or Attack._pilgrimage_legendary_attack then return end
	Attack._pilgrimage_legendary_attack = true
	_mod:hook(Attack, "execute", function(func, attacked_unit, damage_profile, ...)
		local damage_type = _attack_arg("damage_type", ...)
		local attacking_unit = _attack_arg("attacking_unit", ...)
		if damage_type == "smite"
			and _unit_has_buff(attacking_unit, "pilgrim_legendary_unwarded_minds") then
			if _unit_is_boss(attacked_unit) then
				return 0, "blocked", "negated", "no_stagger", false
			end
			local count = select("#", ...)
			local args = { ... }
			args[count + 1] = "instakill"
			args[count + 2] = true
				return func(attacked_unit, damage_profile, unpack(args, 1, count + 2))
			end

		local attack_type = _attack_arg("attack_type", ...)
		local boon_owner = M._resolve_attacking_owner(attacking_unit,
			_attack_arg("attacking_unit_owner_unit", ...))
		local family_server = _shared and _shared.is_server
			and _shared.is_server()
		local effective_critical = _attack_arg("is_critical_strike", ...) == true
		local profile_name = damage_profile and damage_profile.name
		local flak_blast = M.FLAK_CANNON_BLAST_PROFILES[profile_name] == true
		local flak_active = family_server and flak_blast and boon_owner
			and _unit_has_buff(boon_owner, "pilgrim_legendary_flak_cannon")
		local shrapnel_blast = M.SHRAPNEL_DOCTRINE_BLAST_PROFILES[profile_name] == true
		local shrapnel_active = family_server and shrapnel_blast and boon_owner
			and _unit_has_buff(boon_owner,
				"pilgrim_legendary_shrapnel_doctrine")
		local bigger_boom_active = family_server and boon_owner
			and M.BIGGER_BOOM_PROFILES[profile_name] == true
			and _unit_has_buff(boon_owner,
				"pilgrim_legendary_bigger_boom_doctrine")
		local chain_grenade_active = family_server and boon_owner
			and M.CHAIN_OF_CUSTODY_PROFILES[profile_name] == true
			and _unit_has_buff(boon_owner,
				"pilgrim_legendary_chain_of_custody")
		local lights_out_active = family_server and boon_owner
			and M.LIGHTS_OUT_FOREVER_PROFILES[profile_name] == true
			and _unit_has_buff(boon_owner,
				"pilgrim_legendary_lights_out_forever")
		local armourbane_active = family_server and profile_name == "krak_grenade"
			and boon_owner and _unit_has_buff(boon_owner,
				"pilgrim_legendary_armourbane_rite")
		local red_harvest_fraction
		if family_server and boon_owner
			and _unit_has_buff(boon_owner, "pilgrim_legendary_red_harvest") then
			if profile_name == "chordclaw_main" then
				-- The native sticky strike already deals an 800-power insertion
				-- followed by a separate 1500-power extraction. Red Harvest only
				-- keys off the insertion, but 20% on top of both native phases
				-- killed a Plague Ogryn in three casts during field testing.
				red_harvest_fraction = 0.10
			elseif profile_name == "chordclaw_stab_bleed" then
				-- Probing Strikes has no sticky extraction phase, but its three
				-- individual hits still total a substantial 24% maximum health.
				red_harvest_fraction = 0.08
			end
		end
		local juggernaut_sweep = attack_type == "melee"
			and _juggernaut_sprint_sweeps[boon_owner] == true
		local call_args
		local call_count = select("#", ...)
		if family_server and boon_owner and M._is_player_attack_owner(boon_owner)
			and M._chain_of_custody_promotes(attacked_unit,
				profile_name, _fixed_time()) then
			call_args = { ... }
			call_count = _replace_or_append_attack_arg(
				call_args, call_count, "is_critical_strike", true)
			effective_critical = true
		end
		if family_server and boon_owner
			and _unit_has_buff(boon_owner, "pilgrim_family_opening_cut")
			and _critical_family.opening_cut_promotes(boon_owner, attacked_unit,
				attack_type,
				damage_profile, effective_critical) then
			call_args = { ... }
			call_count = _replace_or_append_attack_arg(
				call_args, call_count, "is_critical_strike", true)
			effective_critical = true
		end
		if family_server and effective_critical and boon_owner
			and _unit_has_buff(boon_owner, "pilgrim_family_coup_de_grace")
			and _critical_family.coup_de_grace_can_execute(attacked_unit) then
			call_args = call_args or { ... }
			call_count = _replace_or_append_attack_arg(
				call_args, call_count, "instakill", true)
		end
		if juggernaut_sweep and _juggernaut_can_execute(attacked_unit) then
			call_args = call_args or { ... }
			call_count = _replace_or_append_attack_arg(
				call_args, call_count, "instakill", true)
		end
		if flak_active then
			local unit_data = ScriptUnit.has_extension(attacked_unit,
				"unit_data_system")
			local breed = unit_data and unit_data:breed()
			if breed and M.FLAK_CANNON_EXECUTE_BREEDS[breed.name] then
				call_args = call_args or { ... }
				call_count = _replace_or_append_attack_arg(
					call_args, call_count, "instakill", true)
			end
		end
		if shrapnel_active then
			local unit_data = ScriptUnit.has_extension(attacked_unit,
				"unit_data_system")
			local breed = unit_data and unit_data:breed()
			if breed and M.SHRAPNEL_DOCTRINE_EXECUTE_BREEDS[breed.name] then
				call_args = call_args or { ... }
				call_count = _replace_or_append_attack_arg(
					call_args, call_count, "instakill", true)
			end
		end
		if bigger_boom_active and M._bigger_boom_can_execute(attacked_unit,
			_attack_arg("hit_zone_name", ...)) then
			call_args = call_args or { ... }
			call_count = _replace_or_append_attack_arg(
				call_args, call_count, "instakill", true)
		end

		local repeat_shadow = _shared and _shared.is_server
			and _shared.is_server()
			and _shadow_attack_should_repeat(boon_owner, damage_type)
		local damage, attack_result, efficiency, stagger_result, weakspot
		if call_args then
			damage, attack_result, efficiency, stagger_result, weakspot =
				func(attacked_unit, damage_profile,
					unpack(call_args, 1, call_count))
		else
			damage, attack_result, efficiency, stagger_result, weakspot =
				func(attacked_unit, damage_profile, ...)
		end
		if juggernaut_sweep and attack_result == "died" then
			_restore_all_stamina(boon_owner)
		end
		if flak_active and attack_result ~= "died" and HEALTH_ALIVE[attacked_unit] then
			_apply_ailment_stacks(attacked_unit, "bleed", 15,
				_fixed_time(), boon_owner)
		end
		if shrapnel_active and attack_result ~= "died"
			and HEALTH_ALIVE[attacked_unit] then
			local extension = ScriptUnit.has_extension(attacked_unit, "buff_system")
			local remaining = math.max(0,
				30 - _current_stacks(extension, "pilgrim_shrapnel_bleed"))
			local stacks = math.min(20, remaining)
			if stacks > 0 then
				_apply_ailment_stacks(attacked_unit, "pilgrim_shrapnel_bleed", stacks,
					_fixed_time(), boon_owner)
			end
		end
		if armourbane_active and attack_result ~= "died"
			and HEALTH_ALIVE[attacked_unit] then
			local extension = ScriptUnit.has_extension(attacked_unit, "buff_system")
			_add_target_buff(extension, "pilgrim_armourbane_vulnerability",
				_fixed_time(), boon_owner)
		end
		if chain_grenade_active and stagger_result == "stagger"
			and attack_result ~= "died" then
			M._mark_chain_of_custody_target(attacked_unit, _fixed_time())
		end
		if lights_out_active and stagger_result == "stagger"
			and attack_result ~= "died" and HEALTH_ALIVE[attacked_unit] then
			local extension = ScriptUnit.has_extension(attacked_unit, "buff_system")
			_add_target_buff(extension, "pilgrim_lights_out_forever_debuff",
				_fixed_time(), boon_owner)
		end
		if red_harvest_fraction and type(damage) == "number" and damage > 0
			and HEALTH_ALIVE[attacked_unit] then
			_deal_secondary_damage(attacked_unit, boon_owner,
				_target_max_health(attacked_unit) * red_harvest_fraction, "physical")
		end
		if family_server and boon_owner then
			_unstoppable_family.record_attack_result(boon_owner, attacked_unit,
				attack_type, attack_result, stagger_result,
				_attack_arg("target_index", ...),
				_attack_arg("target_number", ...))
		end
		if family_server and effective_critical and weakspot == true
			and stagger_result ~= "stagger" and attack_result ~= "died"
			and boon_owner
			and _unit_has_buff(boon_owner,
				"pilgrim_family_weakpoint_cartography") then
			_critical_family.force_cartography_stagger(attacked_unit, boon_owner,
				_attack_arg("attack_direction", ...))
		end
		if repeat_shadow and type(damage) == "number" and damage > 0 then
			local now = _shared.fixed_time and _shared.fixed_time() or 0
			_shadow_replays[#_shadow_replays + 1] = {
				at = now + 1,
				target = attacked_unit,
				source = boon_owner,
				damage = damage,
			}
		end
		return damage, attack_result, efficiency, stagger_result, weakspot
	end)
end

-- Harrowing is target-specific and owner-specific. The weak outer keys let a
-- dead enemy disappear without cleanup; weak inner keys do the same for a
-- disconnected player. Keeping the projectile unit in each record prevents a
-- piercing shard from counting its later contact as a new follow-up throw.
M._harrowing_rebuke_states = setmetatable({}, { __mode = "k" })

-- Elemental Affinity and Afflictor both need the actual target at damage time.
-- Elemental Affinity preserves its OR rule, while Afflictor counts distinct
-- current debuff categories rather than stacks. Applying the modifier after
-- Darktide's calculation gives the exact advertised 80/95/110/125/140% curve.
function M.install_family_damage_calculation(DamageCalculation)
	if not _mod or DamageCalculation._pilgrimage_family_damage then return end
	DamageCalculation._pilgrimage_family_damage = true
	local ok_settings, BuffSettings = pcall(require,
		"scripts/settings/buff/buff_settings")
	local keywords = ok_settings and BuffSettings and BuffSettings.keywords or {}
	local compact_tokens = {}
	local shock_tokens = {}
	local keyword_names = {
		"burning", "warpfire_burning", "electrocuted",
		"electrocuted_chain_lightning", "electrocuted_arc",
		"electrocuted_arc_grenade", "electrocuted_arc_ability",
		"electrocuted_shock_mine",
	}
	for i = 1, #keyword_names do
		local token = keywords[keyword_names[i]]
		if token ~= nil then
			compact_tokens[#compact_tokens + 1] = token
			if string.find(keyword_names[i], "electrocuted", 1, true) then
				shock_tokens[#shock_tokens + 1] = token
			end
		end
	end
	local afflictor_keyword_names = {
		{ "burning" },
		{ "warpfire_burning" },
		_electrocution_keyword_names,
		{ "bleeding" },
		{ "toxin" },
		{ "taunted" },
	}
	local afflictor_keyword_groups = {}
	for gi = 1, #afflictor_keyword_names do
		local group = {}
		for ni = 1, #afflictor_keyword_names[gi] do
			local token = keywords[afflictor_keyword_names[gi][ni]]
			if token ~= nil then group[#group + 1] = token end
		end
		if #group > 0 then afflictor_keyword_groups[#afflictor_keyword_groups + 1] = group end
	end

	local function attacker_has(extension, buff_name)
		if not extension
			or type(extension.has_buff_using_buff_template) ~= "function" then return false end
		local ok, has = pcall(extension.has_buff_using_buff_template,
			extension, buff_name)
		return ok and has == true
	end

	local function afflictor_count(target_extension, target_stat_buffs)
		local count = 0
		for i = 1, #afflictor_keyword_groups do
			if _extension_has_current_keyword(target_extension,
				afflictor_keyword_groups[i]) then
				count = count + 1
				if count >= 4 then return 4 end
			end
		end
		target_stat_buffs = target_stat_buffs or {}
		-- Brittleness is a target-side rending stat rather than a keyword.
		if (tonumber(target_stat_buffs.rending_multiplier) or 1) > 1 then
			count = count + 1
			if count >= 4 then return 4 end
		end
		-- Direct vulnerability effects share the damage-taken buckets. Treat
		-- them as one Exposed category even if several effects supply it.
		if (tonumber(target_stat_buffs.damage_taken_modifier) or 1) > 1
			or (tonumber(target_stat_buffs.damage_taken_multiplier) or 1) > 1 then
			count = count + 1
		end
		return math.min(count, 4)
	end

	_mod:hook(DamageCalculation, "calculate", function(func, ...)
		local call_count = select("#", ...)
		local call_args
		local damage_type = select(2, ...)
		local attacking_unit = select(35, ...)
		local attacking_owner = select(36, ...) or attacking_unit
		local assail = damage_type == "throwing_knife" and attacking_owner
			and _unit_has_buff(attacking_owner,
				"pilgrim_legendary_harrowing_rebuke")
		local now = _shared and _shared.fixed_time and _shared.fixed_time() or 0
		local armor_type = select(25, ...)
		local target_unit = select(30, ...)
		local target_states = assail and target_unit
			and M._harrowing_rebuke_states[target_unit]
		local rebuke_state = target_states and target_states[attacking_owner]
		local heavy_target = armor_type == "super_armor"
			or armor_type == "disgustingly_resilient"
		local follow_up = heavy_target and rebuke_state
			and now <= rebuke_state.expires
			and (attacking_unit == nil or attacking_unit ~= rebuke_state.source)
		-- Darktide's native armor-penetrating flag converts Carapace to Flak
		-- for the damage-profile lookup. This applies from the opening shard;
		-- the separate +50% below belongs only to later shards on this target.
		if assail and armor_type == "super_armor" then
			call_args = { ... }
			call_args[22] = true
		end

		local damage, efficiency, base_damage, base_buff_damage, rending_damage,
			finesse_damage, backstab_damage, flanking_damage, armor_modifier,
			hit_zone_multiplier
		if call_args then
			damage, efficiency, base_damage, base_buff_damage, rending_damage,
				finesse_damage, backstab_damage, flanking_damage, armor_modifier,
				hit_zone_multiplier = func(unpack(call_args, 1, call_count))
		else
			damage, efficiency, base_damage, base_buff_damage, rending_damage,
				finesse_damage, backstab_damage, flanking_damage, armor_modifier,
				hit_zone_multiplier = func(...)
		end
		local attacker_extension = select(20, ...)
		local target_extension = select(21, ...)
		if attacker_has(attacker_extension, "pilgrim_family_elemental_affinity")
			and type(damage) == "number" and damage > 0
			and _extension_has_current_keyword(target_extension, compact_tokens) then
			damage = damage * 1.10
		end
		if attacker_has(attacker_extension, "pilgrim_arch_afflictor")
			and type(damage) == "number" and damage > 0 then
			local target_stat_buffs = select(19, ...)
			local categories = afflictor_count(target_extension, target_stat_buffs)
			damage = damage * (0.80 + 0.15 * categories)
		end
		if attacker_has(attacker_extension, "pilgrim_arch_conduit")
			and type(damage) == "number" and damage > 0
			and not _extension_has_current_keyword(target_extension, shock_tokens) then
			damage = damage * 0.75
		end
		local attack_type = select(17, ...)
		local chamber_state = attacking_owner and _dead_mans_states[attacking_owner]
		if chamber_state and attack_type == "ranged"
			and type(damage) == "number" and damage > 0 then
			local now = _shared and _shared.fixed_time
				and _shared.fixed_time() or 0
			-- Hitscan damage is calculated before its ammo event. Arm the
			-- replacement window on the first hit so every later pellet from
			-- that same shot inherits it. Projectile shots are armed by their
			-- earlier ammo event and arrive here with the window already open.
			if chamber_state.replacement_armed then
				chamber_state.replacement_armed = false
				chamber_state.empowered_until = now + 5
			end
			if chamber_state.empowered_until ~= nil
				and now > chamber_state.empowered_until then
				chamber_state.empowered_until = nil
			elseif chamber_state.empowered_until ~= nil then
				damage = damage * 1.50
			end
		end
		if assail and target_unit and heavy_target
			and type(damage) == "number" and damage > 0 then
			if follow_up then
				damage = damage * 1.50
			end
			if not target_states then
				target_states = setmetatable({}, { __mode = "k" })
				M._harrowing_rebuke_states[target_unit] = target_states
			end
			target_states[attacking_owner] = {
				expires = now + 2,
				source = attacking_unit,
			}
		end
		return damage, efficiency, base_damage, base_buff_damage, rending_damage,
			finesse_damage, backstab_damage, flanking_damage, armor_modifier,
			hit_zone_multiplier
	end)
end

-- Compatibility name for older entry files during a hot reload. A full restart
-- uses install_legendary_attack directly.
M.install_brain_rupture_attack = M.install_legendary_attack

local SPECIAL_DELIVERY_PROJECTILE = "pilgrim_special_delivery_bomblet"
local _special_delivery_projectile

local function _append_network_lookup(lookup, name)
	-- NetworkLookup's metatable deliberately errors on a missing string key,
	-- so existence checks must bypass it with rawget.
	if type(lookup) ~= "table" or rawget(lookup, name) ~= nil then return end
	local id = #lookup + 1
	lookup[id] = name
	lookup[name] = id
end

-- Builds one networked projectile that borrows the game's own true-flight
-- steering, grenade model and Big Box impact profile. Only the profile's
-- attack power is scaled, so every armour modifier and breed override from
-- the original impact remains intact at exactly 70% raw damage.
function M.prepare_special_delivery()
	if _special_delivery_projectile then return true end
	local ok_dp, DamageProfiles = pcall(require,
		"scripts/settings/damage/damage_profile_templates")
	local ok_tf, TrueFlight = pcall(require,
		"scripts/settings/projectile/true_flight_templates")
	local ok_loco, Locomotion = pcall(require,
		"scripts/settings/projectile_locomotion/projectile_locomotion_templates")
	local ok_projectiles, Projectiles = pcall(require,
		"scripts/settings/projectile/projectile_templates")
	local ok_lookup, NetworkLookupTable = pcall(require,
		"scripts/network_lookup/network_lookup")
	if not (ok_dp and ok_tf and ok_loco and ok_projectiles and ok_lookup) then
		return false
	end

	local damage_name = "pilgrim_special_delivery_impact"
	local damage_profile = DamageProfiles[damage_name]
	if not damage_profile then
		damage_profile = table.clone(DamageProfiles.ogryn_grenade_box_cluster_impact)
		damage_profile.name = damage_name
		damage_profile.power_distribution = table.clone(damage_profile.power_distribution)
		damage_profile.power_distribution.attack =
			damage_profile.power_distribution.attack * 0.70
		DamageProfiles[damage_name] = damage_profile
	end
	_append_network_lookup(NetworkLookupTable.damage_profile_templates, damage_name)

	local true_flight_name = "pilgrim_special_delivery"
	local true_flight = TrueFlight[true_flight_name]
	if not true_flight then
		true_flight = table.clone(TrueFlight.throwing_knives_aimed)
		true_flight.broadphase_radius = 20
		true_flight.allowed_bounces = 0
		true_flight.true_flight_shard_impact_behaviour = false
		true_flight.on_impact_function = nil
		TrueFlight[true_flight_name] = true_flight
	end

	local locomotion_name = "pilgrim_special_delivery"
	local locomotion = Locomotion[locomotion_name]
	if not locomotion then
		locomotion = table.clone(Locomotion.psyker_throwing_knife_projectile_aimed)
		locomotion.name = locomotion_name
		locomotion.integrator_parameters = table.clone(locomotion.integrator_parameters)
		locomotion.integrator_parameters.true_flight_template = true_flight
		locomotion.integrator_parameters.collision_filter =
			"filter_player_character_shooting_projectile"
		Locomotion[locomotion_name] = locomotion
	end

	local source = Projectiles.ogryn_grenade_box_cluster_grenade
	if not source then return false end
	local projectile = Projectiles[SPECIAL_DELIVERY_PROJECTILE]
	if not projectile then
		projectile = table.clone(source)
		projectile.name = SPECIAL_DELIVERY_PROJECTILE
		projectile.locomotion_template = locomotion
		projectile.damage = table.clone(projectile.damage)
		projectile.damage.impact = {
			delete_on_impact = true,
			delete_on_hit_mass = true,
			damage_profile = damage_profile,
			damage_type = "ogryn_grenade_box",
		}
		Projectiles[SPECIAL_DELIVERY_PROJECTILE] = projectile
	end
	_append_network_lookup(NetworkLookupTable.projectile_template_names,
		SPECIAL_DELIVERY_PROJECTILE)
	_special_delivery_projectile = projectile
	return true
end

local function _spawn_special_delivery_cluster(extension, direction)
	local source_name = extension._projectile_template
		and extension._projectile_template.name
	if source_name ~= "ogryn_grenade_box_cluster" then return false end
	if not M.prepare_special_delivery() then return false end
	local ok_master, MasterItems = pcall(require, "scripts/backend/master_items")
	local ok_loco_settings, LocomotionSettings = pcall(require,
		"scripts/settings/projectile_locomotion/projectile_locomotion_settings")
	if not (ok_master and ok_loco_settings) then return false end

	local owner_unit = extension._owner_unit
	if not _unit_has_buff(owner_unit, "pilgrim_legendary_special_delivery") then
		return false
	end

	local _, position = extension._locomotion_extension:previous_and_current_positions()
	local item = MasterItems.get_cached()[_special_delivery_projectile.item_name]
	if not position or not item then return false end
	local check_vector = Vector3.dot(direction, Vector3.right()) < 1
		and Vector3.right() or Vector3.forward()
	local start_axis = Vector3.cross(direction, check_vector)
	local random_start_rotation = math.pi * 2 * math.random()
	local angle_distribution = math.pi * 2 / 6
	local starting_state = LocomotionSettings.states.true_flight

	for i = 1, 6 do
		local angle = angle_distribution * i + random_start_rotation
		local rotation = Quaternion.axis_angle(direction, angle)
		local flat_direction = Quaternion.rotate(rotation, start_axis)
		local launch_direction = Vector3.normalize(Vector3.lerp(flat_direction, direction, 0.35))
		Managers.state.unit_spawner:spawn_network_unit(nil, "item_projectile",
			position, rotation, nil, item, _special_delivery_projectile,
			starting_state, launch_direction, 24, Vector3.zero(), owner_unit,
			false, extension._origin_item_slot, nil, nil, nil,
			extension._weapon_item_or_nil, 5, extension._owner_side_or_nil)
	end

	if extension._fx_extension then extension._fx_extension:on_cluster() end
	return true
end

function M.install_special_delivery_projectiles(ProjectileDamageExtension)
	if not _mod or ProjectileDamageExtension._pilgrimage_special_delivery then return end
	ProjectileDamageExtension._pilgrimage_special_delivery = true
	_mod:hook(ProjectileDamageExtension, "_spawn_cluster",
		function(func, self, cluster_settings, direction)
			if _spawn_special_delivery_cluster(self, direction) then return end
			return func(self, cluster_settings, direction)
		end)
end

-- ===========================================================================
-- v0.24.0 (Boons v2 phase 1): ARCHETYPES.
-- ===========================================================================
--
-- Design session with Kaizen, 2026-08-11 night. An Archetype is a run
-- identity: one big on-style effect, one off-style cost, and a HARD
-- draft filter. v0.28.12 maps explicit functional compatibility tags
-- over the game's family groupings, and never backfills an incompatible
-- boon when the on-theme pool runs low. There is still a small
-- seeded chance for a legendary to leak into any draft (phase 2 gates
-- the leak on the Legendary slot being empty).
--
-- Slot model (Kaizen): a DEDICATED Archetype slot in the Boon Loadout,
-- unlocked by the archetype_slot Emporium purchase, chosen between
-- runs, LOCKED AT RUN START like Blitz mode and the War Plan (the
-- run's identity cannot switch underfoot; the draft filter and the
-- stat package must agree for the whole road).
--
-- Effects use the exact custom-boon template machinery the Doctrines
-- field-proved. Every stat verified against buff_settings.lua:
--   toughness_bonus (additive), toughness_damage_taken_modifier
--   (additive), melee/ranged_damage (additive bucket),
--   melee_damage_taken_modifier (additive), critical_strike_chance
--   (value, +0.10 = +10pp), damage_vs_burning (additive),
--   toughness_replenish_modifier (additive, ALL replenish sources),
--   combat_ability_cooldown_modifier (additive, Redline-proven),
--   grenade_ability_cooldown_modifier (additive; ability extension
--   line 786 scales BLITZ CHARGE REGENERATION with it, and a blitz
--   with no natural regen has no cooldown running, so it is
--   inherently "if applicable", exactly Kaizen's ask; Psyker's own
--   talent tree uses -0.3 on this stat).
-- All numbers flagged for the economy/tuning pass.

M.ARCHETYPES = {
	{
		id          = "pilgrim_arch_goliath",
		name        = "Goliath",
		description = "Heavy, push and weapon melee attacks gain +30% damage, +50% impact and +35% cleave. -10% speed; -50% ranged.",
		short       = "committed blows, weak shot",
		families    = { "unstoppable" },
		buff_template = "pilgrim_arch_goliath",
		custom = {
			template = _goliath_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_toughness_increase",
		},
	},
	{
		id          = "pilgrim_arch_gunslinger",
		name        = "Gunslinger",
		description = "+20% ranged damage; +10% crit. -25% melee damage; +20% melee damage taken.",
		short       = "deadeye, soft up close",
		families    = { "cowboy", "critical" },
		buff_template = "pilgrim_arch_gunslinger",
		custom = {
			stat_buffs = {
				ranged_damage = 0.2,
				critical_strike_chance = 0.10,
				melee_damage = -0.25,
				melee_damage_taken_modifier = 0.2,
			},
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_big_weakspot_damage_increase",
		},
	},
	{
		id          = "pilgrim_arch_pyromancer",
		name        = "Pyromancer",
		description = "+40% damage vs burning enemies; -25% toughness replenishment.",
		short       = "burn them all",
		-- v0.28.11: Fire now has a healthy standalone pool. Keeping the
		-- entire Fatshark Elementalist family here could offer pure shock
		-- cards such as shock-on-melee-hit, contradicting Pyromancer's
		-- identity. Independently usable cross-element cards are admitted by
		-- explicit tags; two-element requirements belong to Afflictor.
		families    = { "fire" },
		buff_template = "pilgrim_arch_pyromancer",
		custom = {
			stat_buffs = {
				damage_vs_burning = 0.4,
				toughness_replenish_modifier = -0.25,
			},
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_burning_on_melee_hit",
		},
	},
	{
		id          = "pilgrim_arch_stormcaller",
		-- v0.24.1 (Kaizen): renamed from Stormcaller; the name should
		-- carry BOTH the electricity and the cooldown identity. Dynamo:
		-- a machine that never stops generating. Internal id kept so
		-- any stored selection survives the rename.
		name        = "Dynamo",
		description = "-25% ability and blitz cooldowns; -15% damage.",
		short       = "ability spam, lower damage",
		-- Matching Pyromancer's purity pass: Dynamo owns Electric, while
		-- compatible mixed cards are shared explicitly with Afflictor.
		families    = { "electric" },
		buff_template = "pilgrim_arch_stormcaller",
		custom = {
			stat_buffs = {
				combat_ability_cooldown_modifier = -0.25,
				grenade_ability_cooldown_modifier = -0.25,
				damage = -0.15,
			},
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_extra_ability_charge",
		},
	},
	{
		id          = "pilgrim_arch_afflictor",
		name        = "Afflictor",
		description = "-20% damage to clean targets; +15% per different debuff (max 4).",
		short       = "layer debuffs for damage",
		-- Afflictor is assembled from explicit compatibility tags across
		-- several families. `families` remains presentation metadata; the
		-- draft filter uses `draft_tags` when it exists.
		families    = { "elementalist" },
		draft_tags  = { "debuff" },
		buff_template = "pilgrim_arch_afflictor",
		custom = {
			-- The target-dependent damage curve is applied by the narrow
			-- DamageCalculation hook. This empty template is the synchronized
			-- marker which tells that hook the Archetype is active.
			stat_buffs = {},
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_burning_damage_per_burning_enemy",
		},
	},
	{
		id          = "pilgrim_arch_conduit",
		name        = "Conduit",
		description = "Shock hits grant Charge. At 10, restore 20% Toughness nearby; your overflow becomes up to 50 bonus. -25% damage vs unshocked.",
		short       = "shock hits fuel team Toughness",
		families    = { "electric", "unkillable" },
		unlock_penance = "pilgrim_arch_conduit_proof",
		buff_template = "pilgrim_arch_conduit",
		custom = {
			template = _conduit_template,
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_aoe_shock_closest_enemy_on_interval",
		},
	},
	{
		id          = "pilgrim_arch_bulwark",
		name        = "Bulwark",
		description = "+3 stamina, -40% block cost, +50% push impact, +20% toughness. -15% attack speed",
		short       = "block, push, endure",
		families    = { "unkillable" },
		draft_tags  = { "unkillable", "bulwark" },
		unlock_penance = "pilgrim_arch_bulwark_proof",
		buff_template = "pilgrim_arch_bulwark",
		custom = {
			stat_buffs = {
				stamina_modifier = 3,
				block_cost_multiplier = 0.6,
				push_impact_modifier = 0.50,
				toughness_bonus = 0.20,
				attack_speed = -0.15,
			},
			hud_icon = "content/ui/textures/icons/buffs/hud/states_grace_time_hud",
		},
	},
	{
		id          = "pilgrim_arch_executioner",
		name        = "Executioner",
		description = "+18% melee crit chance and +40% crit damage. No ranged weapon; -10 toughness.",
		short       = "melee crits, no ranged",
		-- Critical + Unstoppable remain the identity shown to the player.
		-- Drafting uses a narrower compatibility tag so a melee-only run
		-- never receives ranged-critical or cross-slot cards it cannot use.
		families    = { "critical", "unstoppable" },
		draft_tags  = { "executioner" },
		buff_template = "pilgrim_arch_executioner",
		custom = {
			stat_buffs = {
				melee_critical_strike_chance = 0.18,
				melee_critical_strike_damage = 0.40,
				toughness_bonus_flat = -10,
			},
			hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_stacking_crit_damage_on_critical_hit",
		},
	},
	{
		id          = "pilgrim_arch_skirmisher",
		name        = "Skirmisher",
		description = "+10% move speed; longer dodge window; +1 dodge; reload while sprinting. -35% toughness recovery; -10% health.",
		short       = "mobile gunfighter, fragile recovery",
		families    = { "cowboy", "unstoppable" },
		unlock_penance = "pilgrim_arch_skirmisher_proof",
		buff_template = "pilgrim_arch_skirmisher",
		custom = {
			stat_buffs = {
				movement_speed = 0.10,
				dodge_linger_time_modifier = 0.30,
				extra_consecutive_dodges = 1,
				reload_decrease_movement_reduction = 0,
				toughness_replenish_modifier = -0.35,
				max_health_multiplier = 0.90,
			},
			hud_icon = "content/ui/textures/icons/buffs/hud/states_sprint_buff_hud",
		},
	},
}

-- _archetype_by_id is forward-declared next to the pool caches (M.draft
-- closes over it); filled here where the catalogue exists.
local _selectable_archetypes = {}
for i = 1, #M.ARCHETYPES do
	local archetype = M.ARCHETYPES[i]
	_archetype_by_id[archetype.id] = archetype
	if not archetype.redesign_pending then
		_selectable_archetypes[#_selectable_archetypes + 1] = archetype
	end
end

function M.archetype_get(id) return _archetype_by_id[id] end
function M.archetype_all() return _selectable_archetypes end

-- Storage. Selection is the between-runs choice; the run stamp is what
-- the active run locked in (set by bootstrap's begin, survives game
-- restarts mid-run because it lives in settings like the run itself).
local KEY_ARCHETYPE_SELECTED = "_archetype_selected"
local KEY_ARCHETYPE_RUN      = "_archetype_run"
local KEY_TEST_UNLOCKS       = "_test_unlocks"

function M.test_unlocks_enabled()
	return _mod ~= nil and _mod:get(KEY_TEST_UNLOCKS) == true
end

-- A read-time override, deliberately separate from real ownership and earned
-- unlock storage. Switching it off restores the exact progression state that
-- existed before testing.
function M.set_test_unlocks(enabled)
	if not _mod then return false, "mod unavailable" end
	if _run_state and _run_state.is_active and _run_state.is_active() then
		return false, "finish or abandon the pilgrimage first"
	end
	_mod:set(KEY_TEST_UNLOCKS, enabled == true, false)
	M.reset_pool()
	return true
end

function M.archetype_is_unlocked(id)
	local archetype = _archetype_by_id[id]
	if not archetype or archetype.redesign_pending then return false end
	return archetype.unlock_penance == nil or M.test_unlocks_enabled()
end

function M.selected_archetype_id()
	local v = _mod and _mod:get(KEY_ARCHETYPE_SELECTED)
	if type(v) ~= "string" or v == "" then return nil end
	return M.archetype_is_unlocked(v) and v or nil
end

function M.set_selected_archetype(id)
	if not _mod then return false end
	-- v0.24.1: same mid-run lock as Doctrine slotting. The run's own
	-- archetype was never switchable (the stamp is what applies), but
	-- editing the next run's pick mid-run reads as a loophole next to
	-- the loadout lock, so the whole tab freezes together.
	if _run_state and _run_state.is_active and _run_state.is_active() then
		return false, "loadout locked during a pilgrimage"
	end
	if id ~= nil and not _archetype_by_id[id] then return false, "unknown archetype" end
	if id ~= nil and _archetype_by_id[id].redesign_pending then
		return false, "archetype is under redesign"
	end
	if id ~= nil and not M.archetype_is_unlocked(id) then
		return false, "archetype not unlocked"
	end
	_mod:set(KEY_ARCHETYPE_SELECTED, id or "", false)
	return true
end

-- The Emporium unlock that opens the Archetype slot at all.
function M.archetype_slot_unlocked()
	if M.test_unlocks_enabled() then return true end
	return _shop ~= nil and _shop.is_unlocked ~= nil
		and _shop.is_unlocked("archetype_slot") == true
end

-- Called by bootstrap's begin() for NEW runs only: locks the current
-- selection in for the whole run. An empty stamp means "no archetype",
-- deliberately distinct from "stale stamp from an older run" because
-- reads are gated on run activity.
function M.stamp_archetype_for_run()
	if not _mod then return end
	local id = M.archetype_slot_unlocked() and M.selected_archetype_id() or nil
	_mod:set(KEY_ARCHETYPE_RUN, id or "", false)
end

-- The archetype governing the CURRENT run, or nil. Gated on run
-- activity so a leftover stamp from a finished run never filters a
-- preview draft or applies a stat package in the hub.
function M.active_archetype_id()
	if not (_run_state and _run_state.is_active and _run_state.is_active()) then
		return nil
	end
	local v = _mod and _mod:get(KEY_ARCHETYPE_RUN)
	if type(v) ~= "string" or v == "" then return nil end
	return _archetype_by_id[v] and v or nil
end

-- Marker read by the Blood Debt heal-halving hook in Pilgrimage.lua.
M._blood_debt_self_heal = false

local function _load_csv(key)
	local raw = _mod and _mod:get(key)
	local out = {}
	if type(raw) ~= "string" or raw == "" then return out end
	for id in string.gmatch(raw, "([^,]+)") do
		if _custom_by_id[id] then out[#out + 1] = id end
	end
	return out
end

local function _store_csv(key, list)
	if not _mod then return end
	_mod:set(key, table.concat(list, ","), false)
end

local function _contains(list, id)
	for i = 1, #list do if list[i] == id then return i end end
	return nil
end

function M.owned_ids() return _load_csv(KEY_BOON_OWNED) end
function M.is_owned(id)
	local boon = _custom_by_id[id]
	if M.test_unlocks_enabled() and boon and not boon.legendary then return true end
	return _contains(M.owned_ids(), id) ~= nil
end

-- ---------------------------------------------------------------------------
-- v0.22.82: slot-map model (Kaizen's field feedback: "it should mimick
-- the slot system that party has"). Bindings are per-slot ("1:id,2:id"
-- encoding, same shape as the party preset slots), replacing the
-- v0.22.81 order-less csv list. One boon per slot, one slot per boon.
-- ---------------------------------------------------------------------------

local KEY_BOON_SLOTMAP = "_boon_loadout_slotmap"
local BOON_MAX_SLOTS = 4

local function _load_slot_map()
	local out = {}
	local raw = _mod and _mod:get(KEY_BOON_SLOTMAP)
	if type(raw) == "string" and raw ~= "" then
		for entry in string.gmatch(raw, "([^,]+)") do
			local slot_str, id = string.match(entry, "^(%d+):(.+)$")
			if slot_str and id and _custom_by_id[id] and not _custom_by_id[id].legendary then
				out[tonumber(slot_str)] = id
			end
		end
		return out
	end
	-- One-time migration from the v0.22.81 order-less list: assign the
	-- old slotted boons to slots in order, persist the map, clear the
	-- old key so this branch never runs again.
	local old = _load_csv(KEY_BOON_SLOTTED)
	if #old > 0 and _mod then
		local slot = 1
		for i = 1, #old do
			local boon = _custom_by_id[old[i]]
			if boon and not boon.legendary and slot <= BOON_MAX_SLOTS then
				out[slot] = old[i]
				slot = slot + 1
			end
		end
		local parts = {}
		for slot, id in pairs(out) do parts[#parts + 1] = tostring(slot) .. ":" .. id end
		table.sort(parts)
		_mod:set(KEY_BOON_SLOTMAP, table.concat(parts, ","), false)
		_mod:set(KEY_BOON_SLOTTED, "", false)
	end
	return out
end

local function _store_slot_map(map)
	if not _mod then return end
	local parts = {}
	for slot, id in pairs(map) do
		parts[#parts + 1] = tostring(slot) .. ":" .. id
	end
	table.sort(parts)
	_mod:set(KEY_BOON_SLOTMAP, table.concat(parts, ","), false)
end

function M.slot_map() return _load_slot_map() end
function M.binding_for_boon_slot(slot) return _load_slot_map()[tonumber(slot)] end

-- Which slot (if any) a boon currently occupies.
function M.slot_of(id)
	for slot, bound in pairs(_load_slot_map()) do
		if bound == id then return slot end
	end
	return nil
end

-- Bind a boon to a specific loadout slot, or clear it (id = nil).
-- Validation: the slot must be unlocked, the boon owned, and not
-- already bound to a DIFFERENT slot (re-binding to its own slot is a
-- no-op success, matching the party picker's semantics).
function M.bind_boon_slot(slot, id)
	-- v0.24.1 (Kaizen exploit report): the LOADOUT IS LOCKED while a
	-- pilgrimage is under way. Field-found exploit: de-slot The House
	-- Always Wins between legs, buy at normal prices, re-slot before
	-- the next mission and keep the doubled pickups. Slotting is a
	-- pre-run decision, exactly like the Archetype and the War Plan.
	if _run_state and _run_state.is_active and _run_state.is_active() then
		return false, "loadout locked during a pilgrimage"
	end
	slot = tonumber(slot)
	if not slot or slot < 1 or slot > BOON_MAX_SLOTS then return false, "invalid slot" end
	local map = _load_slot_map()
	if id == nil then
		map[slot] = nil
		_store_slot_map(map)
		return true, "cleared"
	end
	if not _custom_by_id[id] or _custom_by_id[id].legendary then
		return false, "not a Doctrine"
	end
	if slot > M.loadout_slots() then return false, "slot locked" end
	if not M.is_owned(id) then return false, "not owned" end
	local at = M.slot_of(id)
	if at and at ~= slot then
		return false, string.format("already in slot %d", at)
	end
	map[slot] = id
	_store_slot_map(map)
	return true, "slotted"
end

-- Flat list of slotted boon ids (active-slot range only), for the
-- apply path and state checks.
function M.slotted_ids()
	local out = {}
	local limit = M.loadout_slots()
	local map = _load_slot_map()
	for slot = 1, limit do
		if map[slot] then out[#out + 1] = map[slot] end
	end
	return out
end

function M.is_slotted(id) return _contains(M.slotted_ids(), id) ~= nil end

-- 1 base + Emporium expansions (boon_slot_2/3). Slot 4 reserved for a
-- future penance. Cap 4 per the locked decision.
function M.loadout_slots()
	if M.test_unlocks_enabled() then return BOON_MAX_SLOTS end
	local slots = 1
	if _shop and _shop.is_unlocked then
		if _shop.is_unlocked("boon_slot_2") then slots = slots + 1 end
		if _shop.is_unlocked("boon_slot_3") then slots = slots + 1 end
	end
	if slots > 4 then slots = 4 end
	return slots
end

-- Purchase a custom boon into the permanent library.
function M.buy_custom(id)
	local boon = _custom_by_id[id]
	if not boon then return false, "unknown boon" end
	if boon.legendary then return false, "earned as a Legendary" end
	if M.is_owned(id) then return false, "already owned" end
	if not _wallet or not _wallet.spend then return false, "wallet unavailable" end
	if not _wallet.spend(boon.cost or 0, "boon:" .. id) then
		return false, "not enough Ordos"
	end
	local owned = M.owned_ids()
	owned[#owned + 1] = id
	_store_csv(KEY_BOON_OWNED, owned)
	if _event_log and _event_log.emit then
		_event_log.emit({
			t = _shared.fixed_time(), event = "boon_purchased",
			id = _event_log.next_id(), boon = id, cost = boon.cost or 0,
		})
	end
	return true
end

-- v0.22.82: toggle_slot (v0.22.81's order-less API) removed; the
-- slot-map model above (bind_boon_slot / binding_for_boon_slot) is the
-- only mutation surface, matching the party preset slots.

-- True when a no-buff state boon (House Always Wins) is in force:
-- owned, slotted, and a run is active. wallet.lua and shop.lua read
-- this for their respective effects.
function M.custom_boon_active(id)
	-- Debug grants are mission-local overlays. Checking them first lets
	-- hook-driven Doctrines such as Blood Debt and Unlimited Power behave like
	-- their normally slotted versions without changing the player's save.
	if _test_active_ids[id] then return true end
	-- Promoted entries keep this compatibility surface so older feature
	-- hooks (notably Unlimited Power's channel flag) follow the legendary
	-- run stamp without pretending the boon is still a Doctrine.
	if _pilgrim_legendary_by_template[id] then
		return (M.active_legendary and M.active_legendary() == id)
			or (M.active_temporary_legendary
				and M.active_temporary_legendary() == id) or false
	end
	if not M.is_slotted(id) or not M.is_owned(id) then return false end
	return _run_state and _run_state.is_active() or false
end

-- v0.22.85: the equipped blitz, read off the unit's visual loadout.
-- weapon_template_from_slot returns the weapon template whose .name is
-- the template key ("psyker_smite" / "psyker_biomancer_smite" etc,
-- weapon_templates.lua line 19: template_data.name = template_name).
-- nil when the extension or slot isn't readable yet; callers treat nil
-- as "not the required blitz" and rely on the reconciler tick to retry
-- once the loadout has finished resolving.
function M.blitz_template_name(player_unit)
	if not player_unit then return nil end
	local ok, ext = pcall(ScriptUnit.extension, player_unit, "visual_loadout_system")
	if not ok or not ext or type(ext.weapon_template_from_slot) ~= "function" then
		return nil
	end
	local ok2, template = pcall(ext.weapon_template_from_slot, ext, "slot_grenade_ability")
	if not ok2 or type(template) ~= "table" then return nil end
	return template.name
end

-- Called from apply_all (via the M table, so definition order doesn't
-- matter): grant every slotted, owned, buff-backed custom boon at
-- spawn, after the drafted run boons. Class-gated boons (Unlimited
-- Power) skip silently when the player's archetype doesn't match, so a
-- Veteran with it slotted isn't handed a pure -90% curse. v0.22.85:
-- boons with requires_blitz additionally need that weapon template in
-- the blitz slot (Kaizen: "active only if smite is in the talent
-- tree"); grant() dedupes, so re-running this from the reconciler is
-- free for boons already applied.
-- ===========================================================================
-- v0.25.0 (Boons v2 phase 2): THE LEGENDARY SLOT.
-- ===========================================================================
--
-- Kaizen's design, locked 2026-08-11/12: a dedicated Legendary slot in
-- the Boon Loadout, filled PRE-RUN from legendaries the player has
-- UNLOCKED. Unlocking is earned on the road: drafting a legendary
-- through the leak, then FINISHING THAT LEG successfully, on a plan of
-- Penitent or higher (Novitiate runs never unlock; too cheap). The
-- leak itself only fires while no legendary is active, so the slot and
-- the leak never double up.
--
-- Storage:
--   _legendary_unlocked  csv of permanently unlocked buff names
--   _legendary_pending   csv of names drafted this run, awaiting the
--                        leg-completion promotion (cleared at run start)
--   _legendary_slot      the between-runs selection
--   _legendary_run       the stamp locked in at run start
local KEY_LEGENDARY_UNLOCKED = "_legendary_unlocked"
local KEY_LEGENDARY_PENDING  = "_legendary_pending"
local KEY_LEGENDARY_SLOT     = "_legendary_slot"
local KEY_LEGENDARY_RUN      = "_legendary_run"

-- The shared _load_csv validates against _custom_by_id (Doctrine ids),
-- which would silently drop every legendary name on load (found by the
-- harness: pending stored fine, promotion read back an empty list).
-- Legendaries are GAME buff names, so validation here is the hordes
-- prefix, the same rule build_pool's _append applies.
local function _legendary_csv_load(key)
	local raw = _mod and _mod:get(key)
	local out = {}
	if type(raw) ~= "string" or raw == "" then return out end
	for id in string.gmatch(raw, "([^,]+)") do
		if id:sub(1, 12) == "hordes_buff_" or _pilgrim_legendary_by_template[id] then
			out[#out + 1] = id
		end
	end
	return out
end

function M.all_legendary_names()
	local out, seen = {}, {}
	local function walk(value)
		if type(value) == "string" then
			if value:sub(1, 12) == "hordes_buff_" and not seen[value] then
				seen[value] = true
				out[#out + 1] = value
			end
		elseif type(value) == "table" then
			for _, child in pairs(value) do walk(child) end
		end
	end
	local allowed = _allowed_buffs()
	if allowed then walk(allowed.legendary_buffs) end
	for i = 1, #(M.LEGENDARIES or {}) do
		local name = M.LEGENDARIES[i].buff_template
		if name and not seen[name] then
			seen[name] = true
			out[#out + 1] = name
		end
	end
	table.sort(out)
	return out
end

-- Only combat-ability, blitz-specific, talent-specific, and Pilgrimage
-- custom Legendaries belong in the pre-run slot picker. Generic jackpot
-- buffs deliberately stay out even though they remain rare draft drops.
function M.loadout_legendary_names()
	_ensure_legendary_roles()
	local out = {}
	for name in pairs(_loadout_legendary_set) do out[#out + 1] = name end
	table.sort(out)
	return out
end

function M.legendary_unlocked_ids()
	local persisted = _legendary_csv_load(KEY_LEGENDARY_UNLOCKED)
	local out, seen = {}, {}
	for i = 1, #persisted do
		local name = persisted[i]
		if M.is_loadout_legendary(name) and not seen[name] then
			seen[name] = true
			out[#out + 1] = name
		end
	end
	if not M.test_unlocks_enabled() then return out end
	local all = M.loadout_legendary_names()
	for i = 1, #all do
		if not seen[all[i]] then out[#out + 1] = all[i] end
	end
	return out
end

function M.is_legendary_unlocked(name)
	local ids = M.legendary_unlocked_ids()
	for i = 1, #ids do if ids[i] == name then return true end end
	return false
end

function M.legendary_slot()
	local v = _mod and _mod:get(KEY_LEGENDARY_SLOT)
	if type(v) ~= "string" or v == "" then return nil end
	return M.is_loadout_legendary(v) and M.is_legendary_unlocked(v) and v or nil
end

function M.temporary_legendary_slot_unlocked()
	return _shop ~= nil and _shop.is_active ~= nil
		and _shop.is_active("temp_slot") == true
end

function M.temporary_legendary_slot()
	if not M.temporary_legendary_slot_unlocked() then return nil end
	local v = _mod and _mod:get("_legendary_slot_temp")
	if type(v) ~= "string" or v == "" then return nil end
	if v == M.legendary_slot() then return nil end
	return M.is_loadout_legendary(v) and M.is_legendary_unlocked(v) and v or nil
end

function M.set_legendary_slot(name)
	if not _mod then return false end
	-- Same mid-run lock as the rest of the loadout.
	if _run_state and _run_state.is_active and _run_state.is_active() then
		return false, "loadout locked during a pilgrimage"
	end
	if name ~= nil and not M.is_legendary_unlocked(name) then
		return false, "not unlocked"
	end
	if name ~= nil and not M.is_loadout_legendary(name) then
		return false, "not eligible for the Legendary loadout"
	end
	if name ~= nil and name == M.temporary_legendary_slot() then
		return false, "already equipped in Temporary Legendary slot"
	end
	_mod:set(KEY_LEGENDARY_SLOT, name or "", false)
	return true
end

function M.set_temporary_legendary_slot(name)
	if not _mod then return false end
	if _run_state and _run_state.is_active and _run_state.is_active() then
		return false, "loadout locked during a pilgrimage"
	end
	if not M.temporary_legendary_slot_unlocked() then
		return false, "buy the Temporary Legendary Slot at the Emporium"
	end
	if name ~= nil and not M.is_legendary_unlocked(name) then
		return false, "not unlocked"
	end
	if name ~= nil and not M.is_loadout_legendary(name) then
		return false, "not eligible for the Legendary loadout"
	end
	if name ~= nil and name == M.legendary_slot() then
		return false, "already equipped in primary Legendary slot"
	end
	_mod:set("_legendary_slot_temp", name or "", false)
	return true
end

-- The legendary locked into the CURRENT run, or nil. Same gating shape
-- as active_archetype_id.
function M.active_legendary()
	if not (_run_state and _run_state.is_active and _run_state.is_active()) then
		return nil
	end
	local v = _mod and _mod:get(KEY_LEGENDARY_RUN)
	if type(v) ~= "string" or v == "" then return nil end
	-- A save made by an older build may have stamped a now-retired
	-- generic Legendary. Keep the string for rollback compatibility,
	-- but never apply it through the loadout under the new rules.
	return M.is_loadout_legendary(v) and v or nil
end


function M.active_temporary_legendary()
	if not (_run_state and _run_state.is_active and _run_state.is_active()) then
		return nil
	end
	local v = _mod and _mod:get("_legendary_run_temp")
	if type(v) ~= "string" or v == "" or v == M.active_legendary() then return nil end
	return M.is_loadout_legendary(v) and v or nil
end

-- Run-start bookkeeping, called by bootstrap's begin for NEW runs:
-- stamp the archetype AND the legendary, and clear any pending unlocks
-- left by an abandoned or failed earlier run (pending may only promote
-- inside the run that earned it).
function M.on_run_begin()
	M.stamp_archetype_for_run()
	if _mod then
		local slot = M.legendary_slot()
		local temporary = M.temporary_legendary_slot()
		_mod:set(KEY_LEGENDARY_RUN, slot or "", false)
		_mod:set("_legendary_run_temp", temporary or "", false)
		_mod:set(KEY_LEGENDARY_PENDING, "", false)
	end
end

-- Called by chain when a leg completes SUCCESSFULLY. Promotes every
-- pending legendary to the permanent collection, gated on the run's
-- plan being Penitent or higher (Kaizen: Novitiate is too cheap a road
-- to earn a legendary on). On Novitiate the pending list survives
-- untouched; it simply never promotes and dies at the next run start.
-- Records a drafted legendary as pending-unlock. Defined HERE, after
-- the csv helpers, and called from M.choose through the module table
-- (choose sits earlier in the file, where the helpers are not yet in
-- scope; a direct reference there would compile as a nil global).
function M.record_pending_legendary(name)
	if not _mod or type(name) ~= "string" then return false end
	-- Rare generic Legendaries are rewards for this run, not permanent
	-- loadout unlocks. Only slot-eligible effects start an unlock clock.
	if not M.is_loadout_legendary(name) then return false end
	local pending = _legendary_csv_load(KEY_LEGENDARY_PENDING)
	for i = 1, #pending do if pending[i] == name then return true end end
	pending[#pending + 1] = name
	_store_csv(KEY_LEGENDARY_PENDING, pending)
	return true
end

function M.promote_pending_legendaries()
	if not _mod then return 0 end
	local pending = _legendary_csv_load(KEY_LEGENDARY_PENDING)
	if #pending == 0 then return 0 end
	local plan_id
	if _run_state and _run_state.get then
		local ok, state = pcall(_run_state.get)
		plan_id = ok and state and state.plan_id or nil
	end
	if plan_id == nil or plan_id == "novitiate" then return 0 end
	local unlocked = _legendary_csv_load(KEY_LEGENDARY_UNLOCKED)
	local have = {}
	for i = 1, #unlocked do have[unlocked[i]] = true end
	local promoted = 0
	for i = 1, #pending do
		local name = pending[i]
		if M.is_loadout_legendary(name) and not have[name] then
			unlocked[#unlocked + 1] = name
			have[name] = true
			promoted = promoted + 1
			local pretty = name
			local ok_i, info = pcall(M.info, name)
			if ok_i and info and info.title and info.title ~= "" then pretty = info.title end
			if _shared and _shared.notify then
				pcall(_shared.notify, "Legendary unlocked for your loadout: " .. tostring(pretty))
			end
		end
	end
	if promoted > 0 then _store_csv(KEY_LEGENDARY_UNLOCKED, unlocked) end
	_store_csv(KEY_LEGENDARY_PENDING, {})
	return promoted
end

-- One-way-in-new-code, rollback-safe save migration for Unlimited Power's
-- Doctrine -> Legendary promotion. We leave the legacy ownership/slot text
-- untouched so an older build can still read it, but the new UI filters it.
-- A previous owner receives the Legendary unlock; if UP was actually slotted
-- and the Legendary slot is empty, the selection follows it automatically.
local function _raw_csv_has(key, wanted)
	local raw = _mod and _mod:get(key)
	if type(raw) ~= "string" or raw == "" then return false end
	for id in string.gmatch(raw, "([^,]+)") do
		if id == wanted then return true end
	end
	return false
end

local function _legacy_up_was_slotted(id)
	if _raw_csv_has(KEY_BOON_SLOTTED, id) then return true end
	local raw = _mod and _mod:get(KEY_BOON_SLOTMAP)
	if type(raw) ~= "string" or raw == "" then return false end
	for entry in string.gmatch(raw, "([^,]+)") do
		local _, bound = string.match(entry, "^(%d+):(.+)$")
		if bound == id then return true end
	end
	return false
end

local function _migrate_unlimited_power()
	local id = "pilgrim_boon_unlimited_power"
	if not _raw_csv_has(KEY_BOON_OWNED, id) then return false end

	local unlocked = _legendary_csv_load(KEY_LEGENDARY_UNLOCKED)
	local have = false
	for i = 1, #unlocked do
		if unlocked[i] == id then have = true break end
	end
	if not have then
		unlocked[#unlocked + 1] = id
		_store_csv(KEY_LEGENDARY_UNLOCKED, unlocked)
	end

	if _legacy_up_was_slotted(id) then
		local selected = _mod:get(KEY_LEGENDARY_SLOT)
		if type(selected) ~= "string" or selected == "" then
			_mod:set(KEY_LEGENDARY_SLOT, id, false)
		end
	end
	return not have
end

function M.apply_loadout(player_unit)
	local granted = 0
	local archetype = nil
	if _run_state and _run_state.get then
		archetype = _run_state.get().stat_archetype
	end

	-- v0.24.0: the run's Archetype stat package applies first, exactly
	-- like a slotted Doctrine. active_archetype_id is already gated on
	-- run activity and the slot unlock happened at stamp time, so this
	-- needs no further checks; grant()'s dedupe makes repeats free.
	local arch_id = M.active_archetype_id()
	if arch_id then
		local arch = _archetype_by_id[arch_id]
		if arch and arch.buff_template then
			local ok = M.grant(player_unit, arch.buff_template)
			if ok then granted = granted + 1 end
		end
	end

	-- v0.25.0: the run's slotted Legendary applies like a Doctrine,
	-- with a RELEVANCE guard (Kaizen: only offer/apply what the
	-- character can actually use): the buff must be in the CURRENT
	-- pool, which build_pool already filters by class, equipped blitz,
	-- combat ability and talents. A slotted psyker legendary on a
	-- Veteran run skips quietly instead of misbehaving.
	local function grant_legendary(legendary, slot_label)
		if not legendary then return end
		local in_pool = false
		local pool = M.pool()
		for i = 1, #pool do
			if pool[i] == legendary then in_pool = true break end
		end
		if in_pool then
			local ok = M.grant(player_unit, legendary)
			if ok then granted = granted + 1 end
		else
			_debug_log("boons", 0, tostring(slot_label) .. " legendary "
				.. tostring(legendary)
				.. " not applicable to this operative/loadout; inert this mission", 0, "info")
		end
	end
	grant_legendary(M.active_legendary(), "primary")
	grant_legendary(M.active_temporary_legendary(), "temporary")

	local slotted = M.slotted_ids()
	for i = 1, #slotted do
		local boon = _custom_by_id[slotted[i]]
		if boon and not boon.legendary and not boon.no_buff and M.is_owned(boon.id)
			and (boon.id ~= "pilgrim_doctrine_unbroken_record"
				or M.unbroken_ready()) then
			if boon.archetype and archetype and boon.archetype ~= archetype then
				_debug_log("boons", 0, "loadout boon " .. boon.id ..
					" skipped (archetype gate)", 0, "info")
			elseif boon.requires_blitz
				and M.blitz_template_name(player_unit) ~= boon.requires_blitz then
				_debug_log("boons", 0, "loadout boon " .. boon.id ..
					" skipped (blitz gate: wants " .. boon.requires_blitz ..
					", have " .. tostring(M.blitz_template_name(player_unit)) .. ")",
					0, "info")
			else
				local ok = M.grant(player_unit, boon.buff_template)
				if ok then granted = granted + 1 end
			end
		end
	end
	return granted
end

-- v0.22.85: reconciler entry point, called from a Pilgrimage.lua tick
-- while a run is active. Re-offers every boon the run should have;
-- grant()'s _applied dedupe makes repeats free, so this heals ordering
-- problems (run activated after spawn, loadout extension late, boon
-- bought mid-run) without ever double-stacking. Reads only; never
-- writes run_state (the 2-second-freeze lesson).
function M.ensure_applied(player_unit)
	if not player_unit then return 0 end
	if not _run_state.is_active() then return 0 end
	local granted = 0
	local state = _run_state.get()
	for name in pairs(state.boons or {}) do
		if not _applied[name] then
			if M.grant(player_unit, name) then granted = granted + 1 end
		end
	end
	granted = granted + (M.apply_loadout(player_unit) or 0)
	return granted
end

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_run_state = deps.run_state
	_event_log = deps.event_log
	_hooks = deps.hooks
	_icons = deps.icons
	_missions = deps.missions
	-- v0.22.81: loadout deps. wallet for purchases, shop for slot
	-- expansions, passives for template registration.
	_wallet = deps.wallet
	_shop = deps.shop
	_debug_log = deps.debug_log or function() end
	if _migrate_unlimited_power() then
		_debug_log("boons", 0,
			"migrated owned Unlimited Power from Doctrine to Legendary", 0, "info")
	end
	if deps.passives and deps.passives.register_template_source then
		deps.passives.register_template_source(M.CUSTOM)
		-- Target-side child buffs are network templates too, but are not
		-- selectable content of their own.
		deps.passives.register_template_source(M.LEGENDARY_SUPPORT_TEMPLATES)
		deps.passives.register_template_source(M.FAMILY_SUPPORT_TEMPLATES)
		-- v0.26.0: drafted family expansions register through the same
		-- network-safe custom-template path as Doctrines and archetypes.
		deps.passives.register_template_source(M.FAMILY_BOONS)
		-- v0.24.0: archetype stat packages ride the same registration
		-- path; the entries share the CUSTOM shape (buff_template +
		-- custom.stat_buffs), so passives builds them identically.
		deps.passives.register_template_source(M.ARCHETYPES)
	end
end

return M
