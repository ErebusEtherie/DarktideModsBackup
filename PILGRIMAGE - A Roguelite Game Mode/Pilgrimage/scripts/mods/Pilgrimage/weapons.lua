-- weapons.lua
--
-- The shared weapon-patching core. Written to be liftable into a standalone mod
-- with no changes beyond swapping the deps it is handed, because that is the plan:
-- Pilgrimage uses it for run-scoped weapon boons, and a separate mod will use it
-- for permanent tweaks.
--
-- ===========================================================================
-- THE ONE THING TO UNDERSTAND BEFORE READING FURTHER
-- ===========================================================================
--
-- Damage profiles are SHARED TABLE REFERENCES. When a weapon action says
--
--     action.damage_profile = DamageProfileTemplates.default_light_smiter
--
-- that is not a copy. It is the same table object that a dozen other weapons, and
-- possibly some enemy attacks, are also pointing at. Writing into it to buff your
-- chainsword silently buffs everything else that shares it.
--
-- So we never write into a profile we do not own. Instead we do copy-on-write in
-- two steps, at the narrowest possible level:
--
--   1. Own the profile.  action.damage_profile = shallow_copy(original)
--                        Our weapon now has its own top-level table. Every nested
--                        table inside it is still shared, which is fine because we
--                        have not touched them.
--
--   2. Own the field.    our_profile.power_distribution = shallow_copy(original.power_distribution)
--                        Only now do we write numbers.
--
-- Everything we did not touch stays a shared reference, so the blast radius is
-- exactly the fields we changed and nothing else. A deep clone would be simpler to
-- write and much worse, because it would also break any code that compares nested
-- tables by identity.
--
-- Reverting is then trivial: put the original profile reference back on the action.
--
-- ===========================================================================
-- AUTHORITY
-- ===========================================================================
--
-- Darktide resolves damage on the host. When you host solo you are the host and
-- these changes apply fully. As a client in someone else's lobby only your copy of
-- the data changes, which desyncs at best. Will of The Emperor gates every one of
-- its effects behind exactly this check and strips them when it detects real coop,
-- and we do the same.
--
-- Note the network-lookup distinction: modifying the CONTENTS of an existing weapon
-- template adds nothing to the network lookup set and is safe. Adding a NEW template
-- name would change the set and is not.

local M = {}

local _mod
local _shared
local _event_log
local _debug_log

local WEAPON_TEMPLATES_PATH = "scripts/settings/equipment/weapon_templates/weapon_templates"

local _weapon_templates = nil

-- Registered patch definitions, keyed by id.
local _patches = {}

-- What we have changed and how to put it back.
-- _restore[template_name] = {
--     actions  = { [action_name] = original_damage_profile_reference },
--     keywords = original_keywords_array_reference or nil,
--     fields   = { [field_name] = original_value },
-- }
local _restore = {}

local _applied = {}

-- ---------------------------------------------------------------------------
-- Copy-on-write helpers
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- THE REAL DAMAGE PROFILE SHAPE, dumped from combatsword_p1_m2 on 2026-08-04
-- ===========================================================================
--
-- Will of The Emperor hand-writes a synthetic profile with flat scalars, and it is
-- misleading. Shipped profiles look like this:
--
--   damage_profile = {
--     name = "combatsword_light",
--     armor_damage_modifier = {
--       attack = { armored = {0.174, 0.426}, berserker = {...}, ... },
--       impact = { ... },
--     },
--     cleave_distribution = { attack = {4, 9}, impact = {4, 9} },
--     targets = {
--       [1]            = { armor_damage_modifier = {...},
--                          boost_curve_multiplier_finesse = {1.5, 3},
--                          power_distribution = { attack = {min,max}, impact = {min,max} },
--                          power_level_multiplier = {0.5, 1.5} },
--       [2]            = { power_distribution = {...} },
--       [3]            = { power_distribution = {...} },
--       default_target = { boost_curve = {0, 0.3, 0.6, 0.8, 1},
--                          power_distribution = {...} },
--     },
--   }
--
-- Two consequences that broke the first version of this file:
--
--   1. EVERY LEAF NUMBER IS A {min, max} PAIR, not a scalar. The game lerps between
--      them using the weapon's stat rating. Scaling means scaling both elements.
--
--   2. power_distribution IS NOT AT THE TOP LEVEL. Verified: zero occurrences at
--      profile root across the whole dump, 24 inside `targets`. The numbered target
--      entries are the 1st, 2nd and 3rd enemy hit by a cleaving swing;
--      default_target covers everything past that.
--
-- So ownership has to follow a PATH down an arbitrarily deep tree, not just one
-- level. own_path below does that: it shallow-copies every table from the profile
-- root down to whatever is being written, leaving every untouched branch as a
-- shared reference.
--
-- Revert stays a single assignment (put the original profile reference back on the
-- action) and stays correct, because nothing reachable from the original is ever
-- mutated.

local function shallow_copy(source)
	if type(source) ~= "table" then return source end
	local out = {}
	for k, v in pairs(source) do out[k] = v end
	return out
end

-- Walk from an already-owned root down a key path, shallow-copying each table on
-- the way so the caller can safely write at the end. Returns nil if the path does
-- not exist, which is normal: not every profile has every field.
local function own_path(root, ...)
	local node = root
	local keys = { ... }
	for i = 1, #keys do
		local key = keys[i]
		local child = node[key]
		if type(child) ~= "table" then return nil end
		local copy = shallow_copy(child)
		node[key] = copy
		node = copy
	end
	return node
end

-- Recursively own and multiply every leaf number under parent[key].
--
-- Handles all three shapes we actually see: a bare number, a {min, max} pair, and a
-- table of named sub-tables. Because it copies each table before descending, every
-- table it touches ends up owned by us and the originals stay pristine.
--
-- Returns how many numbers it changed, which is what the apply report counts.
local function scale_subtree(parent, key, factor)
	local value = parent[key]

	if type(value) == "number" then
		parent[key] = value * factor
		return 1
	end

	if type(value) ~= "table" then return 0 end

	local copy = shallow_copy(value)
	parent[key] = copy

	local changed = 0
	for child_key in pairs(copy) do
		changed = changed + scale_subtree(copy, child_key, factor)
	end
	return changed
end

local function _restore_entry(template_name)
	local entry = _restore[template_name]
	if not entry then
		entry = { actions = {}, fields = {}, keywords = nil }
		_restore[template_name] = entry
	end
	return entry
end

-- Step 1: give this action its own top-level damage profile table.
-- Records the original reference so revert is a single assignment.
local function own_profile(template_name, action_name, action)
	local original = action.damage_profile
	if type(original) ~= "table" then return nil end

	local entry = _restore_entry(template_name)
	if entry.actions[action_name] == nil then
		entry.actions[action_name] = original
		action.damage_profile = shallow_copy(original)
	end

	return action.damage_profile
end

M.shallow_copy = shallow_copy
M.own_path = own_path
M.scale_subtree = scale_subtree

-- ---------------------------------------------------------------------------
-- Field operations, written against the real structure
-- ---------------------------------------------------------------------------

-- power_distribution lives ONLY under targets, one entry per enemy hit in a cleave
-- plus default_target. Scale all of them so a damage boon applies to the whole
-- swing rather than only the first victim.
local function scale_power(profile, factor)
	local targets = own_path(profile, "targets")
	if not targets then
		-- Defensive: if a future patch moves it to the root, still handle it.
		if profile.power_distribution then
			return scale_subtree(profile, "power_distribution", factor)
		end
		return 0
	end

	local changed = 0
	for target_key in pairs(targets) do
		local target = own_path(targets, target_key)
		if target and target.power_distribution then
			changed = changed + scale_subtree(target, "power_distribution", factor)
		end
	end
	return changed
end

-- armor_damage_modifier appears at the profile root AND inside targets[1].
-- `factors` is keyed by armour type: { armored = 1.5, super_armor = 2.0 }.
-- Armour type keys seen on this build: armored, berserker, disgustingly_resilient,
-- player, resistant, super_armor, unarmored, void_shield.
local function scale_armour(profile, factors)
	local changed = 0

	local function apply_to(container)
		local modifiers = own_path(container, "armor_damage_modifier")
		if not modifiers then return end
		for _, side in ipairs({ "attack", "impact" }) do
			local side_table = own_path(modifiers, side)
			if side_table then
				for armour_type, factor in pairs(factors) do
					if side_table[armour_type] ~= nil then
						changed = changed + scale_subtree(side_table, armour_type, factor)
					end
				end
			end
		end
	end

	apply_to(profile)

	local targets = own_path(profile, "targets")
	if targets then
		for target_key in pairs(targets) do
			local target = own_path(targets, target_key)
			if target and target.armor_damage_modifier then
				apply_to(target)
			end
		end
	end

	return changed
end

-- boost_curve_multiplier_finesse controls the weakspot and critical damage bonus.
local function scale_finesse(profile, factor)
	local targets = own_path(profile, "targets")
	if not targets then return 0 end

	local changed = 0
	for target_key in pairs(targets) do
		local target = own_path(targets, target_key)
		if target and target.boost_curve_multiplier_finesse then
			changed = changed + scale_subtree(target, "boost_curve_multiplier_finesse", factor)
		end
	end
	return changed
end

-- ---------------------------------------------------------------------------
-- Templates
-- ---------------------------------------------------------------------------

function M.templates()
	if _weapon_templates then return _weapon_templates end
	local ok, templates = pcall(require, WEAPON_TEMPLATES_PATH)
	if ok and type(templates) == "table" then
		_weapon_templates = templates
	end
	return _weapon_templates
end

-- Called from the entry file's consolidated hook_require, so the table is captured
-- the moment the game loads it rather than whenever we first happen to ask.
function M.receive_templates(templates)
	if type(templates) == "table" then
		_weapon_templates = templates
	end
end

function M.template(name)
	local templates = M.templates()
	return templates and templates[name] or nil
end

-- Find template names by substring. Weapon template names look like
-- "chainsword_p1_m1", "lasgun_p1_m1", "ogryn_powermaul_p1_m1".
function M.find(needle)
	local templates = M.templates()
	local out = {}
	if not templates then return out end
	needle = tostring(needle or ""):lower()
	for name in pairs(templates) do
		if needle == "" or tostring(name):lower():find(needle, 1, true) then
			out[#out + 1] = name
		end
	end
	table.sort(out)
	return out
end

-- ---------------------------------------------------------------------------
-- Patch definitions
--
-- Patches are DATA, not code, so they can later be generated, serialised into a
-- run, or shown in a UI without anything having to execute.
--
--   {
--     id        = "bite_deeper",
--     templates = { "chainsword_p1_m1" },      -- exact names
--     match     = function(name, template) end, -- or a predicate
--     actions   = "*",                          -- or { "action_left_light", ... }
--
--     power     = 1.25,                         -- scales every targets.*.power_distribution
--     armour    = { armored = 1.5 },            -- scales armor_damage_modifier by armour type
--     cleave    = 1.2,                          -- scales cleave_distribution
--     finesse   = 1.2,                          -- scales boost_curve_multiplier_finesse
--                                               --   (weakspot and crit bonus)
--     profile_fields  = { gibbing_power = 200 },-- absolute writes on the damage profile
--     template_fields = { ... },                -- absolute writes on the weapon template
--     keywords_add    = { "..." },
--   }
-- ---------------------------------------------------------------------------

function M.define(patch)
	assert(type(patch) == "table", "weapons.define: patch must be a table")
	assert(type(patch.id) == "string", "weapons.define: patch needs a string id")
	assert(_patches[patch.id] == nil,
		"weapons.define: duplicate patch id '" .. tostring(patch.id) .. "'")
	_patches[patch.id] = patch
	return patch
end

function M.patches()
	return _patches
end

function M.is_applied(id)
	return _applied[id] == true
end

-- ---------------------------------------------------------------------------
-- Gating
-- ---------------------------------------------------------------------------

-- Only ever patch when we are the authority. Solo host, or the Psykhanium, which is
-- always local. Overridable so the standalone mod can supply its own policy.
local _gate = nil

function M.set_gate(fn)
	_gate = fn
end

function M.can_apply()
	if _gate then return _gate() == true end
	return _shared.is_solo_host() or _shared.is_in_psykhanium()
end

-- ---------------------------------------------------------------------------
-- Apply
-- ---------------------------------------------------------------------------

local function _matching_names(patch)
	local out = {}

	if type(patch.templates) == "table" then
		for i = 1, #patch.templates do out[#out + 1] = patch.templates[i] end
	end

	if type(patch.match) == "function" then
		local templates = M.templates()
		if templates then
			for name, template in pairs(templates) do
				local ok, matched = pcall(patch.match, name, template)
				if ok and matched then out[#out + 1] = name end
			end
		end
	end

	return out
end

local function _action_names(template, patch)
	local out = {}
	if type(template.actions) ~= "table" then return out end

	if patch.actions == nil or patch.actions == "*" then
		for name in pairs(template.actions) do out[#out + 1] = name end
	elseif type(patch.actions) == "table" then
		for i = 1, #patch.actions do
			if template.actions[patch.actions[i]] then out[#out + 1] = patch.actions[i] end
		end
	end

	return out
end

local function _apply_to_template(patch, name, template, report)
	-- Absolute writes on the weapon template itself.
	if type(patch.template_fields) == "table" then
		local entry = _restore_entry(name)
		for key, value in pairs(patch.template_fields) do
			if entry.fields[key] == nil then entry.fields[key] = { template[key] } end
			template[key] = value
			report.template_fields = report.template_fields + 1
		end
	end

	-- Keywords are an array of strings on the template. Own it before appending.
	if type(patch.keywords_add) == "table" and type(template.keywords) == "table" then
		local entry = _restore_entry(name)
		if entry.keywords == nil then
			entry.keywords = template.keywords
			template.keywords = shallow_copy(template.keywords)
		end
		for i = 1, #patch.keywords_add do
			local keyword = patch.keywords_add[i]
			local present = false
			for k = 1, #template.keywords do
				if template.keywords[k] == keyword then present = true break end
			end
			if not present then
				template.keywords[#template.keywords + 1] = keyword
				report.keywords = report.keywords + 1
			end
		end
	end

	-- Everything below touches damage profiles, so skip if nothing asks for it.
	local wants_profile = patch.power or patch.armour or patch.cleave
		or patch.finesse or patch.profile_fields
	if not wants_profile then return end

	local action_names = _action_names(template, patch)
	for i = 1, #action_names do
		local action_name = action_names[i]
		local action = template.actions[action_name]
		local profile = action and own_profile(name, action_name, action)

		if profile then
			report.actions = report.actions + 1

			if patch.power then
				report.numbers = report.numbers + scale_power(profile, patch.power)
			end

			if patch.cleave then
				report.numbers = report.numbers + scale_subtree(profile, "cleave_distribution", patch.cleave)
			end

			if patch.armour then
				report.numbers = report.numbers + scale_armour(profile, patch.armour)
			end

			if patch.finesse then
				report.numbers = report.numbers + scale_finesse(profile, patch.finesse)
			end

			if type(patch.profile_fields) == "table" then
				for key, value in pairs(patch.profile_fields) do
					profile[key] = value
					report.profile_fields = report.profile_fields + 1
				end
			end
		end
	end
end

function M.apply(id)
	local patch = _patches[id]
	if not patch then
		_mod:warning("Pilgrimage: no weapon patch with id '" .. tostring(id) .. "'")
		return false, "unknown patch"
	end
	if _applied[id] then return false, "already applied" end

	if not M.can_apply() then
		_debug_log("weapon_patch_gated:" .. id, _shared.fixed_time(),
			"refused to apply weapon patch '" .. id .. "' outside a solo session", 10, "info")
		return false, "not authoritative"
	end

	local templates = M.templates()
	if not templates then
		_mod:warning("Pilgrimage: weapon templates unavailable, cannot apply '" .. id .. "'")
		return false, "no templates"
	end

	local report = {
		templates = 0, actions = 0, numbers = 0,
		keywords = 0, profile_fields = 0, template_fields = 0,
	}

	local names = _matching_names(patch)
	for i = 1, #names do
		local template = templates[names[i]]
		if template then
			report.templates = report.templates + 1
			local ok, err = pcall(_apply_to_template, patch, names[i], template, report)
			if not ok then
				_mod:error("Pilgrimage: weapon patch '" .. id .. "' failed on '" ..
					tostring(names[i]) .. "': " .. tostring(err))
			end
		end
	end

	_applied[id] = true

	_event_log.emit({
		t = _shared.fixed_time(),
		event = "weapon_patch_applied",
		id = _event_log.next_id(),
		patch = id,
		templates = report.templates,
		actions = report.actions,
		numbers = report.numbers,
	})

	_debug_log("weapon_patch:" .. id, _shared.fixed_time(), string.format(
		"applied '%s' to %d templates, %d actions, %d numbers scaled",
		id, report.templates, report.actions, report.numbers), 0, "info")

	return true, report
end

function M.apply_all()
	local applied = 0
	for id in pairs(_patches) do
		if M.apply(id) then applied = applied + 1 end
	end
	return applied
end

-- ---------------------------------------------------------------------------
-- Revert
--
-- This is why every write above recorded the original. A run-scoped weapon boon
-- has to disappear when the run ends, and a mod that cannot undo itself is a mod
-- that forces a game restart.
-- ---------------------------------------------------------------------------

function M.revert_all()
	local templates = M.templates()
	if not templates then return 0 end

	local reverted = 0

	for template_name, entry in pairs(_restore) do
		local template = templates[template_name]
		if template then
			-- Put the original shared damage profile references back.
			for action_name, original_profile in pairs(entry.actions) do
				local action = template.actions and template.actions[action_name]
				if action then
					action.damage_profile = original_profile
					reverted = reverted + 1
				end
			end

			if entry.keywords ~= nil then
				template.keywords = entry.keywords
			end

			for key, boxed in pairs(entry.fields) do
				-- Boxed in a table so that restoring a genuine nil works.
				template[key] = boxed[1]
			end
		end
	end

	_restore = {}
	_applied = {}

	_debug_log("weapon_revert", _shared.fixed_time(),
		"reverted " .. reverted .. " weapon actions", 0, "info")

	return reverted
end

-- ---------------------------------------------------------------------------
-- Inspection
--
-- We do not yet know the exact shape of a real weapon's damage profile on this
-- build. Will of The Emperor hand-writes a synthetic one, which tells us the
-- vocabulary but not what the shipped weapons actually use. Rather than guess, this
-- dumps the real thing to a file so patches can be written against fact.
-- ---------------------------------------------------------------------------

local function _describe(value, depth, max_depth, lines, indent)
	if depth > max_depth then
		lines[#lines + 1] = indent .. "..."
		return
	end

	local keys = {}
	for k in pairs(value) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

	for i = 1, #keys do
		local key = keys[i]
		local v = value[key]
		local kind = type(v)
		if kind == "table" then
			local count = 0
			for _ in pairs(v) do count = count + 1 end
			lines[#lines + 1] = string.format("%s%s = {  (%d entries)", indent, tostring(key), count)
			_describe(v, depth + 1, max_depth, lines, indent .. "  ")
			lines[#lines + 1] = indent .. "}"
		elseif kind == "function" then
			lines[#lines + 1] = string.format("%s%s = <function>", indent, tostring(key))
		else
			lines[#lines + 1] = string.format("%s%s = %s", indent, tostring(key), tostring(v))
		end
	end
end

-- Build a reverse index: damage profile table -> every "template.action" using it.
--
-- This is the single most useful thing the inspector can tell us. A profile used by
-- twenty weapons is one where naive in-place editing would buff all twenty, and it
-- also tells us whether a weapon is genuinely distinctive or just points at a
-- generic shared profile like every other sword.
function M.profile_users()
	local templates = M.templates()
	local users = {}
	if not templates then return users end

	for template_name, template in pairs(templates) do
		if type(template) == "table" and type(template.actions) == "table" then
			for action_name, action in pairs(template.actions) do
				if type(action) == "table" and type(action.damage_profile) == "table" then
					local list = users[action.damage_profile]
					if not list then
						list = {}
						users[action.damage_profile] = list
					end
					list[#list + 1] = tostring(template_name) .. "." .. tostring(action_name)
				end
			end
		end
	end

	for _, list in pairs(users) do table.sort(list) end
	return users
end

-- Best-effort discovery of what the player is currently holding. Several candidate
-- APIs are tried and the report says which one worked, so this doubles as an API
-- survey the same way the placement probe does.
function M.wielded_template_name()
	local unit = _shared.local_player_unit()
	if not unit then return nil, "no player unit" end

	local visual_loadout = _shared.extension(unit, "visual_loadout_system")
	local unit_data = _shared.extension(unit, "unit_data_system")

	local attempts = {}

	if visual_loadout and visual_loadout.wielded_weapon_template then
		local ok, template = pcall(visual_loadout.wielded_weapon_template, visual_loadout)
		attempts[#attempts + 1] = "visual_loadout:wielded_weapon_template -> " ..
			(ok and type(template) or "error")
		if ok and type(template) == "table" and template.name then
			return template.name, table.concat(attempts, " | ")
		end
	end

	local wielded_slot
	if unit_data and unit_data.read_component then
		local ok, inventory = pcall(unit_data.read_component, unit_data, "inventory")
		if ok and inventory then
			wielded_slot = inventory.wielded_slot
			attempts[#attempts + 1] = "unit_data inventory.wielded_slot = " .. tostring(wielded_slot)
		end
	end

	if wielded_slot and visual_loadout and visual_loadout.weapon_template_from_slot then
		local ok, template = pcall(visual_loadout.weapon_template_from_slot, visual_loadout, wielded_slot)
		attempts[#attempts + 1] = "weapon_template_from_slot -> " .. (ok and type(template) or "error")
		if ok and type(template) == "table" and template.name then
			return template.name, table.concat(attempts, " | ")
		end
	end

	return nil, table.concat(attempts, " | ")
end

function M.dump(name_or_nil, max_depth)
	max_depth = tonumber(max_depth) or 6

	local lines = {}
	local function add(text) lines[#lines + 1] = text end

	add("Pilgrimage weapon dump")
	add("mod version: " .. tostring(_mod.version))
	add("game mode:   " .. tostring(_shared.game_mode_name()))
	add("solo host:   " .. tostring(_shared.is_solo_host()))
	add("can patch:   " .. tostring(M.can_apply()))
	add("")

	local templates = M.templates()
	if not templates then
		add("WEAPON TEMPLATES UNAVAILABLE at " .. WEAPON_TEMPLATES_PATH)
		return lines, nil
	end

	local total = 0
	for _ in pairs(templates) do total = total + 1 end
	add("template table loaded, " .. total .. " entries")

	local target = name_or_nil
	if not target or target == "" then
		local wielded, how = M.wielded_template_name()
		add("wielded discovery: " .. tostring(how))
		target = wielded
	end

	if not target then
		add("")
		add("No target. Pass a name or a substring, for example /pil_weapon chainsword")
		add("First 60 template names:")
		local names = M.find("")
		for i = 1, math.min(#names, 60) do add("  " .. names[i]) end
		return lines, nil
	end

	-- Allow a substring so you do not have to know the exact internal name.
	local template = templates[target]
	if not template then
		local matches = M.find(target)
		add("")
		add("no exact match for '" .. tostring(target) .. "', " .. #matches .. " partial matches:")
		for i = 1, math.min(#matches, 40) do add("  " .. matches[i]) end
		if #matches == 1 then
			target = matches[1]
			template = templates[target]
			add("")
			add("using the only match: " .. target)
		else
			return lines, nil
		end
	end

	add("")
	add("=== TEMPLATE: " .. tostring(target) .. " ===")

	if type(template.keywords) == "table" then
		add("keywords: " .. table.concat(template.keywords, ", "))
	end

	local action_names = {}
	if type(template.actions) == "table" then
		for action_name in pairs(template.actions) do action_names[#action_names + 1] = action_name end
	end
	table.sort(action_names)
	add("actions (" .. #action_names .. "): " .. table.concat(action_names, ", "))
	add("")

	add("=== TOP LEVEL FIELDS ===")
	_describe(template, 1, 1, lines, "  ")
	add("")

	add("=== ACTIONS WITH DAMAGE PROFILES ===")
	add("")
	add("Read the SHARED lines carefully. A damage profile is a shared table")
	add("reference, so a profile used by other weapons is one where editing it in")
	add("place would change all of them. This mod's copy-on-write handles that, but")
	add("the count tells you how generic or how distinctive a weapon actually is.")

	-- Index across EVERY template, not just this one. Sharing within a single
	-- weapon is the rare case; sharing across weapons is the norm and the hazard.
	local all_users = M.profile_users()
	local described = {}

	for i = 1, #action_names do
		local action_name = action_names[i]
		local action = template.actions[action_name]
		if type(action) == "table" and type(action.damage_profile) == "table" then
			local profile = action.damage_profile
			add("")
			add("--- " .. action_name .. " (kind=" .. tostring(action.kind) ..
				", start_input=" .. tostring(action.start_input) .. ")")

			local users = all_users[profile] or {}
			local others = {}
			for u = 1, #users do
				if users[u] ~= (tostring(target) .. "." .. action_name) then
					others[#others + 1] = users[u]
				end
			end

			if #others > 0 then
				add(string.format("    damage_profile SHARED with %d other action(s):", #others))
				for u = 1, math.min(#others, 12) do add("      " .. others[u]) end
				if #others > 12 then add("      ... and " .. (#others - 12) .. " more") end
			else
				add("    damage_profile is used only by this action")
			end

			local described_at = described[profile]
			if described_at then
				add("    (structure already printed above under '" .. described_at .. "')")
			else
				described[profile] = action_name
				_describe(profile, 1, max_depth, lines, "    ")
			end
		end
	end

	return lines, target
end

-- ---------------------------------------------------------------------------

-- Pull a handful of representative numbers out of a template so a patch can be
-- shown as before and after. Used by the live test command.
function M.sample(template_name)
	local template = M.template(template_name)
	if not template or type(template.actions) ~= "table" then return {} end

	local out = {}
	local action_names = {}
	for action_name in pairs(template.actions) do action_names[#action_names + 1] = action_name end
	table.sort(action_names)

	for i = 1, #action_names do
		local action_name = action_names[i]
		local profile = template.actions[action_name].damage_profile
		if type(profile) == "table" then
			local row = { action = action_name }

			local targets = profile.targets
			local first = targets and (targets[1] or targets.default_target)
			local power = first and first.power_distribution
			if power and power.attack then
				row.power_attack_min = power.attack[1]
				row.power_attack_max = power.attack[2]
			end

			local armour = profile.armor_damage_modifier
			local armoured = armour and armour.attack and armour.attack.armored
			if armoured then
				row.armored_min = armoured[1]
				row.armored_max = armoured[2]
			end

			local cleave = profile.cleave_distribution
			if cleave and cleave.attack then row.cleave_min = cleave.attack[1] end

			out[#out + 1] = row
		end
	end

	return out
end

-- Monotonic counter so repeated live tests get unique patch ids rather than
-- colliding on a duplicate-id assert.
local _test_counter = 0
function M.test_counter()
	_test_counter = _test_counter + 1
	return _test_counter
end

function M.reset()
	_patches = {}
	_restore = {}
	_applied = {}
end

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_event_log = deps.event_log
	_debug_log = deps.debug_log or function() end
end

M.WEAPON_TEMPLATES_PATH = WEAPON_TEMPLATES_PATH

return M
