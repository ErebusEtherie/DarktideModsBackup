-- npclook_bridge.lua
--
-- v0.27.5 (Nexus 1.2): runtime compatibility bridge for NPC Look.
--
-- ===========================================================================
-- WHY THIS EXISTS
-- ===========================================================================
--
-- Pilgrimage dresses its bots with NPC Look states through five outfit API
-- functions (npclook_current_state, npclook_add_look_to_loadout,
-- npclook_profile_with_look, npclook_apply_active_look_to_player,
-- npclook_apply_active_look_to_bot_unit). On Kaizen's development
-- install these live as a hand-maintained block appended to the end of
-- NPCLook.lua. That is not distributable: public users install vanilla
-- NPC Look from Nexus, and asking them to paste 200 lines of Lua into
-- another mod's file is not a real option.
--
-- The five functions cannot simply be defined from outside, because
-- they close over nine of NPCLook.lua's FILE-LOCAL internals:
--
--   tables:     _look_state, live_visual, util, extra_slot_runtime
--   functions:  safe_player_unit, visual_extension, fixed_frame_values,
--               normalize_empty_equipment_slot, item_cache
--
-- Lua's debug library can recover them: every function value carries
-- its upvalues, and NPC Look's own public surface reaches all nine
-- (npclook_state_snapshot captures _look_state; on_unload captures
-- INTERNAL, whose functions capture the equip machinery; and so on).
-- This module walks the function/upvalue graph starting from the
-- NPC Look mod object, collects the nine internals BY UPVALUE NAME,
-- and installs functionally identical copies of the outfit API functions
-- onto the NPC Look mod object. In memory only; no files are touched.
--
-- PRECEDENCE, deliberately conservative:
--   1. Each capability is detected separately. Native NPC Look API and
--      visibility support always win over Pilgrimage's compatibility copy.
--   2. Missing public API, cinematic visibility, and safe mission teardown
--      can therefore be bridged independently.
--   3. If anything is missing (no NPC Look, no debug library, internals
--      renamed by an NPC Look update), the bridge reports why and
--      Pilgrimage degrades exactly as it always has without NPC Look:
--      bots spawn with base gear, everything else works.
--
-- The function bodies below are a 1:1 port of the appended patch block
-- (v0.22.23, reapplied v0.22.40), with the nine file-locals replaced by
-- entries in the harvested table H. Behaviour must stay identical; if
-- the patch block ever changes, change this port with it.
-- ===========================================================================

local M = {}

M.VERSION = "bridge-3"

-- What we need from NPCLook.lua's chunk locals, keyed by upvalue name,
-- valued by expected Lua type (a name match with the wrong type is
-- ignored rather than trusted).
local WANTED = {
	_look_state = "table",
	live_visual = "table",
	util = "table",
	extra_slot_runtime = "table",
	safe_player_unit = "function",
	visual_extension = "function",
	fixed_frame_values = "function",
	normalize_empty_equipment_slot = "function",
	item_cache = "function",
	-- Optional on older NPC Look builds. The voice resolver falls back to a
	-- direct cache lookup when this helper is not reachable.
	item_definition = "function",
}

local WANTED_ORDER = {
	"_look_state", "live_visual", "util", "extra_slot_runtime",
	"safe_player_unit", "visual_extension", "fixed_frame_values",
	"normalize_empty_equipment_slot", "item_cache",
}

-- Public NPC Look 2.1.1 exposes its extra-slot runtime, but two pieces of
-- lifecycle state are still file-local. They are optional here: failure to
-- find one safety field must not disable the five outfit API functions.
local SAFETY_WANTED = {
	contexts = "table",
	contexts_by_parent = "table",
	deferred_package_releases = "table",
	owned_visual_records = "table",
	set_record_perspective_visibility = "function",
	set_visual_hierarchy_visibility = "function",
}

-- Result of the last try_install, for the probe command.
local _status = { state = "not_run" }

function M.status()
	return _status
end

local function _debug_lib()
	local Mods = rawget(_G, "Mods")
	local d = Mods and Mods.lua and Mods.lua.debug
	if d and type(d.getupvalue) == "function" then return d end
	d = rawget(_G, "debug")
	if type(d) == "table" and type(d.getupvalue) == "function" then return d end
	return nil
end

-- ---------------------------------------------------------------------------
-- Harvest: breadth-first walk of the function/upvalue graph.
--
-- Seeds: every function directly on the NPC Look mod object (and its
-- metatable index, where DMF keeps the mod class methods; those capture
-- DMF internals, harmless noise). Each visited function contributes its
-- upvalues: matching names are collected, function upvalues join the
-- queue, table upvalues are scanned for MORE functions one level deep
-- (that is how INTERNAL and live_visual open up their whole clusters).
-- Node caps keep a pathological graph from stalling a frame; the real
-- NPC Look graph is a few hundred nodes.
-- ---------------------------------------------------------------------------
function M.harvest(npclook, dbg)
	local found = {}
	local visited_fn = {}
	local visited_tbl = {}
	local queue, head, tail = {}, 1, 0
	local scanned = 0
	local FN_CAP = 4000
	local TBL_VALUE_CAP = 500
	local UPVALUE_CAP = 60

	local function want(name, value)
		if found[name] == nil and WANTED[name] == type(value) then
			found[name] = value
		end
	end

	local function push_fn(fn)
		if type(fn) == "function" and not visited_fn[fn] and tail - head < FN_CAP then
			visited_fn[fn] = true
			tail = tail + 1
			queue[tail] = fn
		end
	end

	local function scan_tbl(t)
		if type(t) ~= "table" or visited_tbl[t] then return end
		if t == _G then return end
		visited_tbl[t] = true
		local count = 0
		for _, v in pairs(t) do
			count = count + 1
			if count > TBL_VALUE_CAP then break end
			if type(v) == "function" then
				push_fn(v)
			end
		end
	end

	-- Seeds
	scan_tbl(npclook)
	local mt = getmetatable(npclook)
	if type(mt) == "table" then
		scan_tbl(mt.__index ~= npclook and mt.__index or nil)
	end

	while head <= tail and scanned < FN_CAP do
		local fn = queue[head]
		head = head + 1
		scanned = scanned + 1
		for i = 1, UPVALUE_CAP do
			local ok, name, value = pcall(dbg.getupvalue, fn, i)
			if not ok or name == nil then break end
			want(name, value)
			if type(value) == "function" then
				push_fn(value)
			elseif type(value) == "table" then
				scan_tbl(value)
			end
		end
	end

	local missing = {}
	for i = 1, #WANTED_ORDER do
		if found[WANTED_ORDER[i]] == nil then
			missing[#missing + 1] = WANTED_ORDER[i]
		end
	end
	return found, missing, scanned
end

-- ---------------------------------------------------------------------------
-- The five API functions, ported verbatim from the appended patch block.
-- H is the harvested internals table.
-- ---------------------------------------------------------------------------
local function _install_api(npclook, H)

	npclook.npclook_current_state = function()
		return H._look_state
	end

	npclook.npclook_add_look_to_loadout = function(source_loadout, state)
		state = state or H._look_state
		if type(source_loadout) ~= "table" then source_loadout = {} end
		return H.live_visual.add_look_to_loadout(source_loadout, state)
	end

	npclook.npclook_profile_with_look = function(profile, state)
		if type(profile) ~= "table" then return profile end
		state = state or H._look_state
		return H.live_visual.profile_with_look(profile, state)
	end

	npclook.npclook_apply_active_look_to_player = function(target_player)
		if not target_player then
			return false, "no target_player"
		end
		local target_unit = H.safe_player_unit(target_player)
		if not target_unit then
			return false, "target has no player_unit"
		end
		if not H.util.safe_unit_alive(target_unit) then
			return false, "target unit not alive"
		end
		if not H.visual_extension(target_unit) then
			return false, "target unit has no visual_loadout_system extension"
		end
		local ok, equipped, failed, err, packages_loading = H.live_visual.equip_all(target_player)
		if packages_loading and (failed or 0) == 0 then
			return true, nil, true
		end
		return ok, err, false, equipped, failed
	end

	npclook.npclook_apply_active_look_to_bot_unit = function(target_player, override_state)
		if not target_player then
			return false, "no target_player"
		end
		local target_unit = H.safe_player_unit(target_player)
		if not target_unit or not H.util.safe_unit_alive(target_unit) then
			return false, "target unit not alive"
		end
		local ext = H.visual_extension(target_unit)
		if not ext then
			return false, "target unit has no visual_loadout_system extension"
		end

		local _look_state = H._look_state
		local live_visual = H.live_visual

		local saved_look_state
		if type(override_state) == "table" then
			saved_look_state = {}
			for k, v in pairs(_look_state) do saved_look_state[k] = v end
			for k in pairs(_look_state) do _look_state[k] = nil end
			for k, v in pairs(override_state) do _look_state[k] = v end
		end

		local saved_plan = live_visual.plan
		local saved_plan_signature = live_visual.plan_signature
		live_visual.plan = nil
		live_visual.plan_signature = nil

		local plan, plan_error = live_visual.build_plan(target_player)

		live_visual.plan = saved_plan
		live_visual.plan_signature = saved_plan_signature

		local state = _look_state
		if saved_look_state then
			for k in pairs(_look_state) do _look_state[k] = nil end
			for k, v in pairs(saved_look_state) do _look_state[k] = v end
			state = override_state
		end

		if not plan then
			return false, plan_error or "build_plan returned nil"
		end

		local fixed_frame, fixed_t = H.fixed_frame_values(ext)
		local equipped_count = 0
		local failed_count = 0
		local packages_loading = false
		local first_error

		local equip_order = live_visual.ordered_slots(false)
		for i = 1, #equip_order do
			local slot_name = equip_order[i]
			if plan.affected and plan.affected[slot_name] then
				local desired_item = plan.desired[slot_name]
				if desired_item then
					local target_signature = plan.desired_signatures[slot_name]
					H.normalize_empty_equipment_slot(ext, slot_name)
					local ok, changed, err, slot_packages_loading = live_visual.swap_slot(
						ext, slot_name, desired_item, target_signature, fixed_frame, fixed_t)
					if ok then
						if changed then equipped_count = equipped_count + 1 end
					elseif slot_packages_loading then
						packages_loading = true
						first_error = first_error or (tostring(slot_name) .. ": " .. tostring(err))
					else
						failed_count = failed_count + 1
						first_error = first_error or (tostring(slot_name) .. ": " .. tostring(err))
					end
				end
			end
		end

		local ok_world, world = pcall(Unit.world, target_unit)
		local target_world = ok_world and world or nil

		local breed_name, driver_base_unit
		if ext._unit_data_extension then
			local ok_breed, breed = pcall(ext._unit_data_extension.breed, ext._unit_data_extension)
			if ok_breed and type(breed) == "table" then
				breed_name = breed.name
				driver_base_unit = breed.base_unit
			end
		end

		local settings = {
			world = target_world,
			unit_spawner = (ext._equipment_component and ext._equipment_component._unit_spawner)
				or (Managers and Managers.state and Managers.state.unit_spawner),
			item_definitions = ext._item_definitions or H.item_cache(),
			mission = ext._mission,
			breed_name = breed_name,
			driver_base_unit = driver_base_unit,
			from_ui_profile_spawner = false,
			force_highest_lod_step = false,
			first_person_unit = ext._first_person_unit,
			first_person_extension = ext._first_person_extension,
			context_label = "PilgrimageBot",
		}

		local entries
		local ok_entries, entries_or_err = pcall(
			H.extra_slot_runtime.preview_items,
			state.applied,
			state.suppressed,
			state.empty,
			state.extra_anchors,
			state.extra_transforms,
			breed_name,
			plan.desired,
			state.variants,
			state.opacity)
		if ok_entries then
			entries = entries_or_err
		else
			first_error = first_error or ("preview_items threw: " .. tostring(entries_or_err))
		end

		if type(entries) == "table" then
			local ok_sc, sc_ok, sc_spawned, sc_failed, sc_error, sc_loading = pcall(
				H.extra_slot_runtime.sync_context,
				target_player,
				target_unit,
				settings,
				entries)
			if ok_sc then
				equipped_count = equipped_count + (sc_spawned or 0)
				failed_count = failed_count + (sc_failed or 0)
				if sc_loading then packages_loading = true end
				if sc_error and not first_error then first_error = tostring(sc_error) end
				local _ = sc_ok
			else
				first_error = first_error or ("sync_context threw: " .. tostring(sc_ok))
				failed_count = failed_count + 1
			end
		end

		if failed_count == 0 and not packages_loading then
			local force_visibility = ext.force_update_item_visibility
			if type(force_visibility) == "function" then
				pcall(force_visibility, ext)
			end
		end

		return true, first_error, packages_loading, equipped_count, failed_count
	end
end

-- Resolve the voice preset from the ORIGINAL cosmetic definition. NPC Look's
-- generated visual-only items intentionally strip voice_fx_preset so portrait
-- and preview clones cannot change dialogue. Vox Filter and Pilgrimage bot
-- capture still need the authored helmet or mask value, so this read-only API
-- inspects the original item and its attachment tree without mutating gear.
local function _install_voice_api(npclook, H)
	local voice_fx_settings = nil
	local voice_fx_settings_loaded = false

	local function settings()
		if not voice_fx_settings_loaded then
			voice_fx_settings_loaded = true
			local ok, value = pcall(
				require,
				"scripts/settings/dialogue/voice_fx_preset_settings"
			)
			voice_fx_settings = ok and value or nil
		end
		return voice_fx_settings
	end

	local function preset_number(value)
		if type(value) == "number" then return value end
		if type(value) ~= "string" or value == "" then return nil end
		local lookup = settings()
		local number = lookup and lookup[value]
		return type(number) == "number" and number or nil
	end

	local function definition(item_name)
		if type(item_name) ~= "string" or item_name == "" then return nil end
		if type(H.item_definition) == "function" then
			local ok, item = pcall(H.item_definition, item_name)
			if ok and type(item) == "table" then return item end
		end
		local ok, cache = pcall(H.item_cache)
		return ok and type(cache) == "table" and rawget(cache, item_name) or nil
	end

	local inspect_item
	inspect_item = function(reference, seen, depth)
		if depth > 24 then return nil end
		local item = type(reference) == "string" and definition(reference) or reference
		if type(item) ~= "table" or seen[item] then return nil end
		seen[item] = true

		local direct = preset_number(item.voice_fx_preset)
		if direct ~= nil then return direct, item.voice_fx_preset end

		local function inspect_tree(tree)
			if type(tree) ~= "table" then return nil end
			local keys = {}
			for key in pairs(tree) do keys[#keys + 1] = key end
			table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
			for i = 1, #keys do
				local entry = tree[keys[i]]
				if type(entry) == "table" then
					local number, name = inspect_item(entry.item or entry, seen, depth + 1)
					if number ~= nil then return number, name end
					number, name = inspect_tree(entry.children)
					if number ~= nil then return number, name end
				end
			end
			return nil
		end

		local number, name = inspect_tree(item.attachments)
		if number ~= nil then return number, name end
		return inspect_tree(item.children)
	end

	npclook.npclook_voice_fx_preset_for_state = function(state)
		state = type(state) == "table" and state or H._look_state
		local applied = type(state.applied) == "table" and state.applied or {}
		local suppressed = type(state.suppressed) == "table" and state.suppressed or {}
		local empty = type(state.empty) == "table" and state.empty or {}
		local anchors = type(state.extra_anchors) == "table" and state.extra_anchors or {}
		local candidates, added = {}, {}

		local function add(slot_name)
			local item_name = applied[slot_name]
			if type(item_name) == "string" and item_name ~= ""
				and not suppressed[slot_name] and not empty[slot_name]
				and not added[slot_name] then
				added[slot_name] = true
				candidates[#candidates + 1] = item_name
			end
		end

		add("slot_gear_head")
		local head_extras = {}
		for slot_name, anchor in pairs(anchors) do
			if anchor == "slot_gear_head" then head_extras[#head_extras + 1] = slot_name end
		end
		table.sort(head_extras)
		for i = 1, #head_extras do add(head_extras[i]) end
		add("slot_gear_extra_cosmetic")

		local remaining = {}
		for slot_name in pairs(applied) do
			if not added[slot_name] then remaining[#remaining + 1] = slot_name end
		end
		table.sort(remaining)
		for i = 1, #remaining do add(remaining[i]) end

		for i = 1, #candidates do
			local number, name = inspect_item(candidates[i], {}, 0)
			if number ~= nil then return number, name, candidates[i] end
		end
		return nil
	end

	npclook.npclook_active_voice_fx_preset = function()
		return npclook.npclook_voice_fx_preset_for_state(H._look_state)
	end
end

-- ---------------------------------------------------------------------------
-- NPC Look 2.1.1 safety compatibility.
--
-- The public extra-slot runtime already keeps a package ledger and context
-- registry. Pilgrimage does not duplicate either system. It recovers those
-- tables from the runtime's own closures, then adds two narrowly scoped
-- behaviours:
--
--   * Extra cosmetic units follow PlayerVisibilityExtension hide/show calls.
--     This prevents a hidden gameplay bot's armour from floating at its real
--     off-camera position while a cinematic surrogate walks into frame.
--
--   * Package records are marked persistent before release_all tears down a
--     mission. Stingray can otherwise unload an attachment package while
--     queued cosmetic child units still reference it, crashing on completion.
--
-- Both changes are in-memory only. A future NPC Look implementation of
-- set_parent_visibility is treated as native and is left untouched.
-- ---------------------------------------------------------------------------

local function _harvest_safety(runtime, dbg)
	local found = {}
	local visited_fn = {}
	local visited_tbl = {}
	local queue, head, tail = {}, 1, 0
	local scanned = 0
	local FN_CAP = 3000
	local TBL_VALUE_CAP = 500
	local UPVALUE_CAP = 60

	local function want(name, value)
		if found[name] == nil and SAFETY_WANTED[name] == type(value) then
			found[name] = value
		end
	end

	local function push_fn(fn)
		if type(fn) == "function" and not visited_fn[fn] and tail - head < FN_CAP then
			visited_fn[fn] = true
			tail = tail + 1
			queue[tail] = fn
		end
	end

	local function scan_tbl(tbl)
		if type(tbl) ~= "table" or visited_tbl[tbl] or tbl == _G then return end
		visited_tbl[tbl] = true
		local count = 0
		for _, value in pairs(tbl) do
			count = count + 1
			if count > TBL_VALUE_CAP then break end
			if type(value) == "function" then push_fn(value) end
		end
	end

	scan_tbl(runtime)

	while head <= tail and scanned < FN_CAP do
		local fn = queue[head]
		head = head + 1
		scanned = scanned + 1
		for i = 1, UPVALUE_CAP do
			local ok, name, value = pcall(dbg.getupvalue, fn, i)
			if not ok or name == nil then break end
			want(name, value)
			if type(value) == "function" then
				push_fn(value)
			elseif type(value) == "table" then
				scan_tbl(value)
			end
		end
	end

	return found, scanned
end

-- Replace every reachable reference to one named local function. NPC Look's
-- closures normally share the same upvalue cell, but walking all references
-- also covers Lua builds that split that cell during compilation.
local function _replace_named_upvalue(runtime, dbg, wanted_name, original, replacement)
	if type(dbg.setupvalue) ~= "function" then
		return 0, "debug.setupvalue unavailable"
	end

	local visited_fn = {}
	local visited_tbl = {}
	local queue, head, tail = {}, 1, 0
	local replaced = 0
	local FN_CAP = 3000
	local TBL_VALUE_CAP = 500
	local UPVALUE_CAP = 60

	local function push_fn(fn)
		if type(fn) == "function" and not visited_fn[fn] and tail - head < FN_CAP then
			visited_fn[fn] = true
			tail = tail + 1
			queue[tail] = fn
		end
	end

	local function scan_tbl(tbl)
		if type(tbl) ~= "table" or visited_tbl[tbl] or tbl == _G then return end
		visited_tbl[tbl] = true
		local count = 0
		for _, value in pairs(tbl) do
			count = count + 1
			if count > TBL_VALUE_CAP then break end
			if type(value) == "function" then push_fn(value) end
		end
	end

	scan_tbl(runtime)

	while head <= tail and head <= FN_CAP do
		local fn = queue[head]
		head = head + 1
		for i = 1, UPVALUE_CAP do
			local ok, name, value = pcall(dbg.getupvalue, fn, i)
			if not ok or name == nil then break end
			if type(value) == "function" then push_fn(value) end
			if type(value) == "table" then scan_tbl(value) end
			if name == wanted_name and value == original then
				local set_ok, set_name = pcall(dbg.setupvalue, fn, i, replacement)
				if set_ok and set_name ~= nil then
					replaced = replaced + 1
				end
			end
		end
	end

	return replaced, replaced > 0 and nil or (wanted_name .. " upvalue not reachable")
end

local function _install_visibility_compat(npclook, runtime, H, dbg, pilgrimage)
	if type(runtime.set_parent_visibility) == "function" then
		return true, "native"
	end

	local original_set_record = H.set_record_perspective_visibility
	local set_hierarchy_visibility = H.set_visual_hierarchy_visibility
	if type(original_set_record) ~= "function"
		or type(set_hierarchy_visibility) ~= "function"
		or type(H.contexts) ~= "table"
		or type(H.contexts_by_parent) ~= "table" then
		return false, "NPC Look visibility internals unavailable"
	end

	local parent_visibility = setmetatable({}, { __mode = "k" })
	local unpack_results = rawget(_G, "unpack") or table.unpack

	local function force_record_hidden(record)
		if type(record) ~= "table" then return end
		set_hierarchy_visibility(record.root_unit, record.attachment_map, false)
		set_hierarchy_visibility(
			record.animated_first_person_root_unit,
			record.animated_first_person_attachment_map,
			false)
		set_hierarchy_visibility(
			record.first_person_root_unit,
			record.first_person_attachment_map,
			false)
	end

	local function bridge_set_record(record, first_person_mode, force, ...)
		local results = { original_set_record(record, first_person_mode, force, ...) }
		if type(record) == "table" and parent_visibility[record.parent_unit] == false then
			force_record_hidden(record)
		end
		return unpack_results(results)
	end

	local replaced, replace_error = _replace_named_upvalue(
		runtime,
		dbg,
		"set_record_perspective_visibility",
		original_set_record,
		bridge_set_record)
	if replaced == 0 then
		return false, replace_error
	end

	function runtime.set_parent_visibility(parent_unit, visible)
		if not parent_unit then return end
		if visible == false then
			parent_visibility[parent_unit] = false
		else
			parent_visibility[parent_unit] = nil
		end

		local owner_set = H.contexts_by_parent[parent_unit]
		for owner in pairs(owner_set or {}) do
			local context = H.contexts[owner]
			for _, record in pairs(context and context.records or {}) do
				bridge_set_record(record, context.first_person_mode, true)
			end
		end
	end

	if not pilgrimage or type(pilgrimage.hook) ~= "function" then
		return false, "Pilgrimage hook API unavailable"
	end

	local path = "scripts/extension_systems/player_visibility/player_visibility_extension"
	local register = pilgrimage.hook_require_now or pilgrimage.hook_require
	if type(register) ~= "function" then
		return false, "Pilgrimage hook_require API unavailable"
	end

	register(pilgrimage, path, function(target)
		if type(target) ~= "table" or rawget(target, "_pilgrimage_npclook_visibility_bridge") then
			return
		end
		rawset(target, "_pilgrimage_npclook_visibility_bridge", M.VERSION)

		if type(target.hide) == "function" then
			pilgrimage:hook(target, "hide", function(func, self, ...)
				local results = { func(self, ...) }
				runtime.set_parent_visibility(self and self._unit, false)
				return unpack_results(results)
			end)
		end

		if type(target.show) == "function" then
			pilgrimage:hook(target, "show", function(func, self, ...)
				local results = { func(self, ...) }
				runtime.set_parent_visibility(self and self._unit, true)
				return unpack_results(results)
			end)
		end
	end)

	npclook._pilgrimage_npclook_visibility_bridge = M.VERSION
	return true, "bridged (" .. tostring(replaced) .. " references)"
end

local function _retain_package_records(H)
	for i = 1, #(H.deferred_package_releases or {}) do
		local deferred = H.deferred_package_releases[i]
		if type(deferred) == "table" and type(deferred.record) == "table" then
			deferred.record.retain_packages = true
		end
	end

	for _, context in pairs(H.contexts or {}) do
		for _, record in pairs(type(context) == "table" and context.records or {}) do
			if type(record) == "table" and type(record.package_record) == "table" then
				record.package_record.retain_packages = true
			end
		end
		for _, record in pairs(type(context) == "table" and context.pending or {}) do
			if type(record) == "table" then record.retain_packages = true end
		end
	end

	for _, owner_record in pairs(H.owned_visual_records or {}) do
		if type(owner_record) == "table" and type(owner_record.package_record) == "table" then
			owner_record.package_record.retain_packages = true
		end
	end
end

local function _install_teardown_compat(runtime, H)
	if runtime._pilgrimage_safe_release == M.VERSION then
		return true, "already"
	end
	if type(runtime.release_all) ~= "function"
		or type(H.contexts) ~= "table"
		or type(H.deferred_package_releases) ~= "table"
		or type(H.owned_visual_records) ~= "table" then
		return false, "NPC Look package ledger unavailable"
	end

	local original_release_all = runtime.release_all
	runtime.release_all = function(_retain_packages, ...)
		-- The public 2.1.1 implementation already honours retain_packages on
		-- each package record. Mark every active or deferred record before its
		-- own release path runs, then pass true for patched/future versions.
		_retain_package_records(H)
		return original_release_all(true, ...)
	end
	runtime._pilgrimage_safe_release = M.VERSION
	return true, "bridged"
end

-- ---------------------------------------------------------------------------
-- Entry point. Call from on_all_mods_loaded (every mod's file scope has
-- run by then, so NPC Look's functions exist to be walked). Idempotent.
-- Returns ok, detail. The detail summarizes API, cinematic visibility, and
-- teardown coverage independently so /pil_npclook_bridge can diagnose partial
-- compatibility after an NPC Look update.
-- ---------------------------------------------------------------------------
function M.try_install()
	local get_mod = rawget(_G, "get_mod")
	if not get_mod then
		_status = { state = "failed", reason = "get_mod unavailable" }
		return false, _status.reason
	end
	local npclook = get_mod("NPCLook")
	if not npclook then
		_status = { state = "absent", reason = "NPC Look not installed" }
		return false, _status.reason
	end
	if npclook._pilgrimage_npclook_bridge == M.VERSION then
		_status = { state = "already", version = npclook._pilgrimage_npclook_bridge }
		return true, "already"
	end

	local api_native = type(npclook.npclook_profile_with_look) == "function"
		and type(npclook.npclook_apply_active_look_to_bot_unit) == "function"
	local voice_native = type(npclook.npclook_voice_fx_preset_for_state) == "function"
		and type(npclook.npclook_active_voice_fx_preset) == "function"
	local dbg = _debug_lib()
	if not dbg and not api_native then
		_status = { state = "failed", reason = "debug library unavailable (Mods.lua.debug missing)" }
		return false, _status.reason
	end

	local api_mode = "native"
	local voice_mode = voice_native and "native" or "unavailable"
	local api_scanned = 0
	local H = nil
	if dbg and (not api_native or not voice_native) then
		local missing, scanned
		H, missing, scanned = M.harvest(npclook, dbg)
		api_scanned = scanned
		if #missing > 0 and not api_native then
			_status = { state = "failed", scanned = scanned,
				reason = "NPC Look internals not found: " .. table.concat(missing, ", ")
					.. " (NPC Look update may have renamed them; bots will wear base gear)" }
			return false, _status.reason
		end
	end

	if not api_native then
		_install_api(npclook, H)
		api_mode = "bridged"
	end

	if not voice_native and H and type(H._look_state) == "table"
		and type(H.item_cache) == "function" then
		_install_voice_api(npclook, H)
		voice_mode = "bridged"
	end

	local visibility_mode = "unavailable"
	local teardown_mode = "unavailable"
	local safety_scanned = 0
	local safety_reason
	local runtime = rawget(npclook, "npclook_extra_slot_runtime")

	if type(runtime) ~= "table" then
		safety_reason = "NPC Look extra-slot runtime unavailable"
	elseif not dbg then
		-- A native NPC Look can still supply the API without Lua debug access.
		-- Leave its safety behaviour untouched and report the reduced coverage.
		visibility_mode = type(runtime.set_parent_visibility) == "function" and "native" or "unavailable"
		safety_reason = "debug library unavailable for safety bridge"
	else
		local safety_H
		safety_H, safety_scanned = _harvest_safety(runtime, dbg)

		local pilgrimage = get_mod("Pilgrimage")
		local visibility_ok, visibility_detail = _install_visibility_compat(
			npclook, runtime, safety_H, dbg, pilgrimage)
		visibility_mode = visibility_ok and visibility_detail or "unavailable"

		local teardown_ok, teardown_detail = _install_teardown_compat(runtime, safety_H)
		teardown_mode = teardown_ok and teardown_detail or "unavailable"

		if not visibility_ok or not teardown_ok then
			local reasons = {}
			if not visibility_ok then reasons[#reasons + 1] = "visibility: " .. tostring(visibility_detail) end
			if not teardown_ok then reasons[#reasons + 1] = "teardown: " .. tostring(teardown_detail) end
			safety_reason = table.concat(reasons, "; ")
		end
	end

	npclook._pilgrimage_npclook_bridge = M.VERSION
	local state = api_mode == "bridged" and "bridged" or "native"
	_status = {
		state = state,
		version = M.VERSION,
		api = api_mode,
		voice = voice_mode,
		visibility = visibility_mode,
		teardown = teardown_mode,
		scanned = api_scanned + safety_scanned,
		reason = safety_reason,
	}
	local detail = string.format(
		"api=%s, voice=%s, visibility=%s, teardown=%s",
		api_mode,
		voice_mode,
		visibility_mode,
		teardown_mode)
	return true, detail
end

return M
