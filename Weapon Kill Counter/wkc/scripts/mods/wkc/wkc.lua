local mod = get_mod("wkc")

local Attack = require("scripts/utilities/attack/attack")
local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
local Items = require("scripts/utilities/items")
local AttackSettings = require("scripts/settings/damage/attack_settings")
local attack_results = AttackSettings.attack_results
local attack_types   = AttackSettings.attack_types
local ATTACK_TYPE_COMPANION_DOG = rawget(attack_types, "companion_dog")
local ATTACK_TYPE_PUSH = rawget(attack_types, "push")

mod.version = "1.32.0"

mod._stats_dirty = false
mod._stats = mod:get("stats_data") or {
	totals = {
		kills = 0, elite_kills = 0, special_kills = 0,
		weakspot_kills = 0, crit_kills = 0, damage = 0,
	},
	weapons = {},
}

local _wkc_os = Mods and Mods.lua and Mods.lua.os

local WKC_SEED_JOURNAL   = "./../mods/wkc/wkc_stats.lua"
local WKC_LEGACY_JOURNAL = "./../mods/WeaponStats/weaponstats_crashsafe.lua"

local WKC_APPDATA_DIR
do
	local ok, appdata = pcall(function()
		return _wkc_os and _wkc_os.getenv and _wkc_os.getenv("APPDATA")
	end)
	if ok and type(appdata) == "string" and appdata ~= "" then
		WKC_APPDATA_DIR = appdata .. "/Fatshark/Darktide/wkc/"
	end
end

local function _wkc_isdir(path)
	if not _wkc_os then return false end
	local ok, _, code = _wkc_os.rename(path, path)
	if not ok and code == 13 then return true end
	return ok and true or false
end

local function _wkc_ensure_appdata_dir()
	if not (WKC_APPDATA_DIR and _wkc_os) then return false end
	if not _wkc_isdir(WKC_APPDATA_DIR) then
		pcall(_wkc_os.execute, 'mkdir "' .. WKC_APPDATA_DIR .. '"')
	end
	return true
end
_wkc_ensure_appdata_dir()

local WKC_JOURNAL_PATH = WKC_APPDATA_DIR
	and (WKC_APPDATA_DIR .. "wkc_stats.lua")
	or  WKC_SEED_JOURNAL
local WKC_JOURNAL_TMP = WKC_JOURNAL_PATH .. ".tmp"

local WKC_DEV_DEBUG = false
local wkc_dev_damage_log
do
	local path  = WKC_APPDATA_DIR and (WKC_APPDATA_DIR .. "wkc_dev_damage.txt")
	local dbgio = Mods and Mods.lua and Mods.lua.io
	if WKC_DEV_DEBUG and dbgio and path then
		pcall(function()
			local f = dbgio.open(path, "w")
			if f then f:close() end
		end)
	end
	wkc_dev_damage_log = function(line)
		if not (WKC_DEV_DEBUG and dbgio and path) then return end
		pcall(function()
			local f = dbgio.open(path, "a")
			if f then f:write(line .. "\n"); f:close() end
		end)
	end
end

mod._APPDATA_DIR = WKC_APPDATA_DIR
mod._DEV_DEBUG   = WKC_DEV_DEBUG
mod._debug_trace_remaining = 0

do
	local lua_io = Mods and Mods.lua and Mods.lua.io
	local lua_loadstring = Mods and Mods.lua and Mods.lua.loadstring
	if lua_io and lua_loadstring then
		local function try_read(path)
			local ok, result = pcall(function()
				local f = lua_io.open(path, "r")
				if not f then return nil end
				local content = f:read("*a")
				f:close()
				if not content or content == "" then return nil end
				local chunk = lua_loadstring(content)
				if not chunk then return nil end
				local data = chunk()
				if type(data) ~= "table" or type(data.weapons) ~= "table" then
					return nil
				end
				return data
			end)
			return ok and result or nil
		end
		local function _fresher(a, b)
			if not a then return b end
			if not b then return a end
			return ((a.save_counter or 0) >= (b.save_counter or 0)) and a or b
		end
		local appdata_journal = try_read(WKC_JOURNAL_PATH)
		appdata_journal = _fresher(appdata_journal, try_read(WKC_JOURNAL_TMP))
		local seed = try_read(WKC_SEED_JOURNAL)
		seed = _fresher(seed, try_read(WKC_SEED_JOURNAL .. ".tmp"))
		seed = _fresher(seed, try_read(WKC_LEGACY_JOURNAL))
		seed = _fresher(seed, try_read(WKC_LEGACY_JOURNAL .. ".tmp"))

		local journal = _fresher(appdata_journal, seed)
		if journal
			and (journal.save_counter or 0) > (mod._stats.save_counter or 0)
		then
			mod._stats = journal
			mod:set("stats_data", journal)
			if journal ~= appdata_journal then
				mod._seed_appdata_pending = true
			end
		end
	end
end

mod._PROP_BREEDS = {
	corruptor_body        = true,
	corruptor_pustule     = true,
	druglab_tank          = true,
	druglab_tank_shield   = true,
	electrical_fusebox_01 = true,
	filtration_tank       = true,
	hazard_prop           = true,
	hazard_sphere         = true,
	heresy_altar          = true,
	ice_chunk             = true,
	icicle                = true,
	nurgle_totem          = true,
	train_cogitator       = true,
}

mod._stats.weapons = mod._stats.weapons or {}
mod._stats.totals  = mod._stats.totals  or {}
for _, fld in ipairs({"kills", "elite_kills", "special_kills",
                       "weakspot_kills", "crit_kills", "damage"}) do
	mod._stats.totals[fld] = mod._stats.totals[fld] or 0
end
for k, w in pairs(mod._stats.weapons) do
	if (w.kills or 0) == 0
		and not w.display_family
		and not w.display_pattern
		and not w.display_mark then
		mod._stats.weapons[k] = nil
	end
end

mod._stats.instances = mod._stats.instances or {}
for k, w in pairs(mod._stats.instances) do
	if (w.kills or 0) == 0
		and (w.damage or 0) == 0
		and (w.shots_fired or 0) == 0
		and (w.missions_played or 0) == 0
		and not w.label
		and not w.rating
		and not w.template then
		mod._stats.instances[k] = nil
	end
end

mod._gear_for_template = {}
mod._label_seen = {}

function mod._per_instance()
	return mod:get("wkc_per_instance") and true or false
end

function mod._gear_id_for(template_name, item)
	if type(item) == "string" and item ~= "" then return item end
	local gid = type(item) == "table" and item.gear_id or nil
	if type(gid) == "string" and gid ~= "" then return gid end
	if template_name then return mod._gear_for_template[template_name] end
	return nil
end

function mod._bucket_for(template_name, item)
	local S = mod._stats
	if not S then return nil end
	if mod._per_instance() then
		local gid = mod._gear_id_for(template_name, item)
		if not gid then return nil end
		return S.instances and S.instances[gid]
	end
	return S.weapons and S.weapons[template_name]
end
local _mirror = setmetatable({}, { __mode = "k" })

local stats_target
local function bump_total(fld, n)
	local t = ((stats_target and stats_target()) or mod._stats).totals
	t[fld] = (t[fld] or 0) + (n or 1)
end

local HONORIFIC_DEFAULT = {
	threshold = 0,    name = mod:localize("wkc_rank_standard_issue"), color = { 255, 0x8B, 0x8B, 0x8B },
}

local HONORIFIC_TIERS = {
	{ threshold =    100, name = mod:localize("wkc_rank_blooded"),              color = { 255, 0xBB, 0xBB, 0xBB } },
	{ threshold =    250, name = mod:localize("wkc_rank_battle_tested"),        color = { 255, 0xFE, 0xFC, 0xE6 } },
	{ threshold =    450, name = mod:localize("wkc_rank_proven"),               color = { 255, 0xF6, 0xE9, 0x7B } },
	{ threshold =    700, name = mod:localize("wkc_rank_oath_bound"),           color = { 255, 0xFF, 0xEE, 0x58 } },
	{ threshold =   1000, name = mod:localize("wkc_rank_heretic_slain"),        color = { 255, 0xFF, 0xEB, 0x3B } },
	{ threshold =   1350, name = mod:localize("wkc_rank_relentless"),           color = { 255, 0xE4, 0xBB, 0x8F } },
	{ threshold =   1750, name = mod:localize("wkc_rank_skull_taking"),         color = { 255, 0xE6, 0xFF, 0x2D } },
	{ threshold =   2250, name = mod:localize("wkc_rank_fearsome"),             color = { 255, 0xB9, 0xA8, 0x6F } },
	{ threshold =   2750, name = mod:localize("wkc_rank_heretics_bane"),        color = { 255, 0xC7, 0x3B, 0x00 } },
	{ threshold =   3500, name = mod:localize("wkc_rank_gore_anointed"),        color = { 255, 0xEF, 0x9A, 0x9A } },
	{ threshold =   5000, name = mod:localize("wkc_rank_emperor_blessed"),      color = { 255, 0xEF, 0x53, 0x50 } },
	{ threshold =   7500, name = mod:localize("wkc_rank_merciless"),            color = { 255, 0xF4, 0x43, 0x36 } },
	{ threshold =   9999, name = mod:localize("wkc_rank_almost_ten_thousand"),  color = { 255, 0xE5, 0x39, 0x35 } },
	{ threshold =  10000, name = mod:localize("wkc_rank_sainted_armament"),     color = { 255, 0xD3, 0x2F, 0x2F } },
	{ threshold =  15000, name = mod:localize("wkc_rank_wrathful"),             color = { 255, 0xC6, 0x28, 0x28 } },
	{ threshold =  25000, name = mod:localize("wkc_rank_pox_breaking"),         color = { 255, 0x9C, 0xCC, 0x65 } },
	{ threshold =  50000, name = mod:localize("wkc_rank_exalted"),              color = { 255, 0x9C, 0x27, 0xB0 } },
	{ threshold =  75000, name = mod:localize("wkc_rank_legendary"),            color = { 255, 0xD8, 0x1B, 0x60 } },
	{ threshold =  76160, name = mod:localize("wkc_rank_throne_favored"),       color = { 255, 0x21, 0x96, 0xF3 } },
	{ threshold =  85000, name = mod:localize("wkc_rank_mourningstars_pride"),  color = { 255, 0x4B, 0xB5, 0x81 } },
	{ threshold = 100000, name = mod:localize("wkc_rank_god_emperors_own"),     color = { 255, 0xFF, 0xC2, 0x00 } },
}

mod._HONORIFIC_DEFAULT = HONORIFIC_DEFAULT
mod._HONORIFIC_TIERS   = HONORIFIC_TIERS

local _rank_rev, _rank_resolved = -1, {}

local function resolved_tier(index, tier)
	local rev = mod._layout_revision or -1
	if rev ~= _rank_rev then
		_rank_rev = rev
		_rank_resolved = {}
	end
	local cached = _rank_resolved[index]
	if cached then return cached end

	local out = tier
	local r = mod._layout and mod._layout.ranks and mod._layout.ranks[index]
	if type(r) == "table" then
		local name = (type(r.name) == "string" and r.name ~= "") and r.name or tier.name
		local c = type(r.color) == "table" and r.color or nil
		if name ~= tier.name or c then
			out = {
				threshold = tier.threshold,
				name      = name,
				color     = c and { c.a or 255, c.r or 255, c.g or 255, c.b or 255 }
				            or tier.color,
			}
		end
	end
	_rank_resolved[index] = out
	return out
end

local function honorific_for_kills(kills)
	kills = kills or 0
	for i = #HONORIFIC_TIERS, 1, -1 do
		if kills >= HONORIFIC_TIERS[i].threshold then
			return resolved_tier(i + 1, HONORIFIC_TIERS[i])
		end
	end
	return resolved_tier(1, HONORIFIC_DEFAULT)
end

local function fill_bucket(w)
	w.kills               = w.kills               or 0
	w.elite_kills         = w.elite_kills         or 0
	w.special_kills       = w.special_kills       or 0
	w.weakspot_kills      = w.weakspot_kills      or 0
	w.crit_kills          = w.crit_kills          or 0
	w.damage              = w.damage              or 0
	w.shots_fired         = w.shots_fired         or 0
	w.shots_hit           = w.shots_hit           or 0
	w._shots_pending      = nil
	w.breeds              = w.breeds              or {}
	w.damage_type_kills   = w.damage_type_kills   or {}
	w.special_active_kills = w.special_active_kills or 0
	w.special_active_hits  = w.special_active_hits  or 0
	w.parry_kills         = w.parry_kills         or 0
	w.melee_kills         = w.melee_kills         or 0
	w.missions_played     = w.missions_played     or 0
	w.missions_won        = w.missions_won        or 0
	return w
end

local function item_rating(item)
	if type(item) ~= "table" then return nil end
	local ok_t, tsv = pcall(Items.total_stats_value, item)
	if ok_t and type(tsv) == "number" and tsv > 0 then
		return math.floor(tsv + 0.5)
	end
	local bs = item.base_stats
	if type(bs) ~= "table" then return nil end
	local allowed
	local ok, tmpl = pcall(WeaponTemplate.weapon_template_from_item, item)
	if ok and type(tmpl) == "table" and type(tmpl.base_stats) == "table" then
		allowed = tmpl.base_stats
	end
	local sum, n = 0, 0
	for i = 1, #bs do
		local s = bs[i]
		if type(s) == "table" and s.name and type(s.value) == "number"
		   and (not allowed or allowed[s.name]) then
			sum = sum + s.value
			n = n + 1
		end
	end
	if n == 0 then return nil end
	return math.floor(sum * 100 + 0.5)
end
mod._item_rating = item_rating

local function note_gear(template_name, item)
	if type(template_name) ~= "string" or template_name == "" then return nil end
	local gid = type(item) == "table" and item.gear_id or nil
	if type(gid) == "string" and gid ~= "" then
		mod._gear_for_template[template_name] = gid
		return gid
	end
	return mod._gear_for_template[template_name]
end
mod._note_gear = note_gear

local function get_instance_bucket(template_name, item)
	local gid = note_gear(template_name, item)
	if not gid then return nil end
	local S = (stats_target and stats_target()) or mod._stats
	local inst = S.instances
	if not inst then
		inst = {}
		S.instances = inst
	end
	local w = inst[gid]
	if not w then
		w = fill_bucket({ last_honorific_threshold = 0 })
		inst[gid] = w
	else
		fill_bucket(w)
		if w.last_honorific_threshold == nil then
			w.last_honorific_threshold = honorific_for_kills(w.kills or 0).threshold
		end
	end
	w.template = template_name
	if item and w.rating == nil then
		w.rating = item_rating(item)
	end
	return w
end

local function get_weapon_bucket(template_name, item)
	local S = (stats_target and stats_target()) or mod._stats
	local w = S.weapons[template_name]
	if not w then
		w = fill_bucket({ last_honorific_threshold = 0 })
		S.weapons[template_name] = w
	else
		fill_bucket(w)
		if w.last_honorific_threshold == nil then
			w.last_honorific_threshold = honorific_for_kills(w.kills or 0).threshold
		end
	end
	_mirror[w] = get_instance_bucket(template_name, item)
	return w
end

local function get_breed_bucket(weapon_bucket, breed_name)
	local b = weapon_bucket.breeds[breed_name]
	if not b then
		b = { kills = 0, damage = 0 }
		weapon_bucket.breeds[breed_name] = b
	end
	local m = _mirror[weapon_bucket]
	if m then
		local mb = m.breeds[breed_name]
		if not mb then
			mb = { kills = 0, damage = 0 }
			m.breeds[breed_name] = mb
		end
		_mirror[b] = mb
	else
		_mirror[b] = nil
	end
	return b
end

local function bump(w, field, n)
	w[field] = (w[field] or 0) + n
	local m = _mirror[w]
	if m then m[field] = (m[field] or 0) + n end
end

local function bump_sub(w, tbl, key, n)
	local t = w[tbl]
	if not t then
		t = {}
		w[tbl] = t
	end
	t[key] = (t[key] or 0) + n
	local m = _mirror[w]
	if m then
		local mt = m[tbl]
		if not mt then
			mt = {}
			m[tbl] = mt
		end
		mt[key] = (mt[key] or 0) + n
	end
end

local function capture_display_names(weapon_bucket, item)
	if weapon_bucket.display_family == nil then
		local function safe(fn)
			local ok, val = pcall(fn, item)
			if ok and type(val) == "string" and val ~= "" and val ~= "-" and val ~= "n/a" then
				return val
			end
			return nil
		end

		weapon_bucket.display_family  = safe(Items.weapon_lore_family_name)  or ""
		weapon_bucket.display_pattern = safe(Items.weapon_lore_pattern_name) or ""
		weapon_bucket.display_mark    = safe(Items.weapon_lore_mark_name)    or ""
	end

	local m = _mirror[weapon_bucket]
	if m and m.display_family == nil then
		m.display_family  = weapon_bucket.display_family
		m.display_pattern = weapon_bucket.display_pattern
		m.display_mark    = weapon_bucket.display_mark
	end
end

local function extract_named_args(...)
	local out = {}
	local n = select("#", ...)
	for i = 1, n, 2 do
		local k = select(i, ...)
		local v = select(i + 1, ...)
		out[k] = v
	end
	return out
end

local function is_local_player_unit(unit)
	if not unit then return false end
	local player_manager = Managers.player
	if not (player_manager and player_manager.local_player_safe) then return false end
	local local_player = player_manager:local_player_safe(1)
	if not local_player then return false end
	return local_player.player_unit == unit
end

local function projectile_owner_if_ours(unit)
	local em = Managers and Managers.state and Managers.state.extension
	if not em then return nil end
	local ok, entities = pcall(em.get_entities, em, "ProjectileUnitLocomotionExtension")
	if not (ok and entities) then return nil end
	local ext = entities[unit]
	if not ext then return nil end
	local ok_o, owner = pcall(ext.owner_unit, ext)
	if ok_o and is_local_player_unit(owner) then
		return owner
	end
	return nil
end

local function breed_for_unit(unit)
	if not unit then return nil end
	local ude = ScriptUnit.has_extension(unit, "unit_data_system")
	if not ude then return nil end
	local ok, breed = pcall(ude.breed, ude)
	if not ok then return nil end
	return breed
end

local function classify_breed(breed)
	if not breed or type(breed) ~= "table" then return false, false end
	local tags = breed.tags
	local is_elite   = tags and tags.elite or false
	local is_special = tags and tags.special or false
	return is_elite and true or false, is_special and true or false
end

local function is_local_player_companion(unit)
	if not unit then return false end
	local breed = breed_for_unit(unit)
	if not (breed and breed.name == "companion_dog") then return false end
	if not (Managers and Managers.state and Managers.state.player_unit_spawn) then
		return false
	end
	local ok, owner = pcall(Managers.state.player_unit_spawn.owner,
	                         Managers.state.player_unit_spawn, unit)
	if not (ok and owner) then return false end
	return is_local_player_unit(owner.player_unit)
end

local function is_companion_damage_profile_name(dp_name)
	if type(dp_name) ~= "string" then return false end
	return dp_name:find("companion", 1, true) ~= nil
	    or dp_name:sub(1, 14) == "cyber_mastiff_"
end

local _mode_mgr, _mode_is_grinder

local function is_in_meat_grinder()
	local gm = Managers and Managers.state and Managers.state.game_mode
	if not gm then return false end
	if gm == _mode_mgr then return _mode_is_grinder end
	local ok, name = pcall(gm.game_mode_name, gm)
	if not ok then return false end
	_mode_mgr, _mode_is_grinder = gm, name == "shooting_range"
	return _mode_is_grinder
end

stats_target = function()
	if WKC_DEV_DEBUG and is_in_meat_grinder() then return mod._debug_stats end
	return mod._stats
end

local function is_local_player_weapon_special_active()
	if not (Managers and Managers.player and Managers.player.local_player_safe) then
		return false
	end
	local local_player = Managers.player:local_player_safe(1)
	if not local_player then return false end
	local player_unit = local_player.player_unit
	if not player_unit or not ALIVE[player_unit] then return false end

	local unit_data_ext = ScriptUnit.has_extension(player_unit, "unit_data_system")
	if not unit_data_ext then return false end

	local ok_inv, inv_component = pcall(unit_data_ext.read_component, unit_data_ext, "inventory")
	if not (ok_inv and inv_component) then return false end
	local wielded_slot = inv_component.wielded_slot
	if not wielded_slot or wielded_slot == "" then return false end

	local ok_slot, slot_component = pcall(unit_data_ext.read_component, unit_data_ext, wielded_slot)
	if not (ok_slot and slot_component) then return false end

	return slot_component.special_active and true or false
end

local function _game_time()
	local tm = Managers and Managers.time
	if not tm then return nil end
	local ok, t = pcall(tm.time, tm, "gameplay")
	if ok and type(t) == "number" then return t end
	return nil
end

local function local_player_archetype()
	local pm = Managers and Managers.player
	if not (pm and pm.local_player_safe) then return nil end
	local local_player = pm:local_player_safe(1)
	if not local_player then return nil end
	local ok, name = pcall(local_player.archetype_name, local_player)
	return ok and name or nil
end

local function is_local_player_stealthed()
	local pm = Managers and Managers.player
	if not (pm and pm.local_player_safe) then return false end
	local local_player = pm:local_player_safe(1)
	local player_unit = local_player and local_player.player_unit
	if not player_unit or not ALIVE[player_unit] then return false end
	local buff_ext = ScriptUnit.has_extension(player_unit, "buff_system")
	if not (buff_ext and buff_ext.has_keyword) then return false end
	local ok, has = pcall(buff_ext.has_keyword, buff_ext, "invisible")
	return ok and has == true
end

local function local_player_has_buff(buff_template_name)
	local pm = Managers and Managers.player
	if not (pm and pm.local_player_safe) then return false end
	local local_player = pm:local_player_safe(1)
	local player_unit = local_player and local_player.player_unit
	if not player_unit or not ALIVE[player_unit] then return false end
	local buff_ext = ScriptUnit.has_extension(player_unit, "buff_system")
	if not (buff_ext and buff_ext.has_buff_using_buff_template) then return false end
	local ok, has = pcall(buff_ext.has_buff_using_buff_template, buff_ext, buff_template_name)
	return ok and has == true
end

local function unit_is_undamaged(unit)
	if not unit then return false end
	local ext = ScriptUnit.has_extension(unit, "health_system")
	if not ext then return false end
	if ext.damage_taken then
		local ok, taken = pcall(ext.damage_taken, ext)
		if ok and type(taken) == "number" then return taken <= 0 end
	end
	if ext.current_health_percent then
		local ok, pct = pcall(ext.current_health_percent, ext)
		if ok and type(pct) == "number" then return pct >= 0.999 end
	end
	return false
end

mod._dot_source_by_unit = setmetatable({}, { __mode = "k" })

local DOT_SOURCE_TTL = 20

mod._companion_dot_units = setmetatable({}, { __mode = "k" })

mod._bomber_pin_pulled = setmetatable({}, { __mode = "k" })

local GRENADIER_PRIME_EFFECTS = {
	renegade_grenadier_grenade = true,
	cultist_grenadier_grenade  = true,
}

local BOMBER_PIN_FIELD = {
	renegade_grenadier = "scab_bomber_pin_denied",
	cultist_grenadier  = "tox_bomber_pin_denied",
}

local DAEMONHOST_BREEDS = {
	chaos_daemonhost         = true,
	chaos_mutator_daemonhost = true,
}

local HOUND_BREEDS = {
	chaos_hound         = true,
	chaos_hound_mutator = true,
	chaos_armored_hound = true,
}

local HOUND_LEAP_SPEED_THRESHOLD = 15

local function hound_is_leaping(unit)
	local behavior = ScriptUnit.has_extension(unit, "behavior_system")
	if behavior and behavior.running_action then
		local ok, action = pcall(behavior.running_action, behavior)
		if ok then return action == "leap" end
	end
	local loco = ScriptUnit.has_extension(unit, "locomotion_system")
	if loco and loco.current_velocity and Vector3 and Vector3.length then
		local ok, v = pcall(loco.current_velocity, loco)
		if ok and v then
			local ok_len, len = pcall(Vector3.length, v)
			return (ok_len and type(len) == "number"
				and len >= HOUND_LEAP_SPEED_THRESHOLD) or false
		end
	end
	return false
end

mod:hook_safe(CLASS.FxSystem, "start_template_effect",
function(self, template, optional_unit, optional_node, optional_position)
	if optional_unit and template and GRENADIER_PRIME_EFFECTS[template.name] then
		mod._bomber_pin_pulled[optional_unit] = true
	end
end)

mod:hook_safe(CLASS.FxSystem, "rpc_start_template_effect",
function(self, channel_id, buffer_index, template_id, optional_unit_id,
		optional_node, optional_position, optional_player_owner_unit_id)
	if not optional_unit_id then return end
	local lookup = NetworkLookup and NetworkLookup.effect_templates
	local template_name = lookup and lookup[template_id]
	if not (template_name and GRENADIER_PRIME_EFFECTS[template_name]) then return end
	local us = Managers and Managers.state and Managers.state.unit_spawner
	if not us then return end
	local ok, unit = pcall(us.unit, us, optional_unit_id)
	if ok and unit then
		mod._bomber_pin_pulled[unit] = true
	end
end)

mod._last_damaging_hit = setmetatable({}, { __mode = "k" })

local BURSTER_DAMAGE_WINDOW = 5

local BUFF_TEMPLATE_DAMAGE_TYPE = {
	neurotoxin_interval_buff       = "toxin",
	neurotoxin_interval_buff2      = "toxin",
	neurotoxin_interval_buff3      = "toxin",
	exploding_toxin_interval_buff  = "toxin",

	flamer_assault                 = "burning",
	phosphor_burn                  = "phosphor_dot",

	bleed                          = "bleeding",
	bleed_long                     = "bleeding",

	warp_fire                      = "warpfire",
}

local TICK_PROFILE_DAMAGE_TYPE = {
	toxin_variant_1  = "toxin",
	toxin_variant_2  = "toxin",
	toxin_variant_3  = "toxin",
	bleeding         = "bleeding",
	burning          = "burning",
	phosphor_burning = "phosphor_dot",
	warpfire         = "warpfire",
}

local function collect_live_dot_sources(unit, dtype)
	local by_type = mod._dot_source_by_unit[unit]
	if not by_type then return nil end
	local now = _game_time()
	local out
	local function scan(sources)
		for tn, e in pairs(sources) do
			if now and e.t and (now - e.t) > DOT_SOURCE_TTL then
				sources[tn] = nil
			else
				out = out or {}
				out[#out + 1] = e
			end
		end
	end
	if dtype then
		local sources = by_type[dtype]
		if sources then scan(sources) end
	else
		for _, sources in pairs(by_type) do
			scan(sources)
		end
	end
	return out
end

local DOT_LATE_ATTRIBUTE_WINDOW = 0.5

local function upgrade_pending_dots_to_weapon(unit, template_name, item, now)
	if not (unit and template_name) then return end
	local by_type = mod._dot_source_by_unit[unit]
	if not by_type then return end
	for dtype, sources in pairs(by_type) do
		local nw = sources["__nonweapon"]
		if nw and (nw.count or 0) > 0 and now and nw.t
		   and (now - nw.t) <= DOT_LATE_ATTRIBUTE_WINDOW then
			local e = sources[template_name]
			if e then
				e.count = (e.count or 0) + nw.count
				e.t = now
				e.item = item or e.item
			else
				sources[template_name] = {
					template_name = template_name,
					item          = item,
					count         = nw.count,
					t             = now,
					dtype         = dtype,
				}
			end
			sources["__nonweapon"] = nil
		end
	end
end

mod._last_melee_elite_kill = nil

local function upgrade_pending_splash_toxin(template_name, item, now)
	if not (template_name and now) then return end
	for _, by_type in pairs(mod._dot_source_by_unit) do
		local sources = by_type.toxin
		local nw = sources and sources["__nonweapon"]
		if nw and (nw.count or 0) > 0 and nw.t
		   and (now - nw.t) <= DOT_LATE_ATTRIBUTE_WINDOW then
			local e = sources[template_name]
			if e then
				e.count = (e.count or 0) + nw.count
				e.t = now
				e.item = item or e.item
			else
				sources[template_name] = {
					template_name = template_name,
					item          = item,
					count         = nw.count,
					t             = now,
					dtype         = "toxin",
				}
			end
			sources["__nonweapon"] = nil
		end
	end
end

local function best_dot_source(entries)
	if not entries then return nil end
	local best
	for i = 1, #entries do
		local e = entries[i]
		if not best
		   or (e.count or 0) > (best.count or 0)
		   or ((e.count or 0) == (best.count or 0) and (e.t or 0) > (best.t or 0)) then
			best = e
		end
	end
	return best
end

local function best_weapon_dot_source(entries)
	if not entries then return nil end
	local weapon_entries
	for i = 1, #entries do
		if entries[i].template_name then
			weapon_entries = weapon_entries or {}
			weapon_entries[#weapon_entries + 1] = entries[i]
		end
	end
	return best_dot_source(weapon_entries)
end

local function snapshot_local_wielded()
	if not (Managers and Managers.player and Managers.player.local_player_safe) then
		return nil, nil
	end
	local local_player = Managers.player:local_player_safe(1)
	if not local_player then return nil, nil end
	local player_unit = local_player.player_unit
	if not player_unit or not ALIVE[player_unit] then return nil, nil end

	local unit_data_ext = ScriptUnit.has_extension(player_unit, "unit_data_system")
	if not unit_data_ext then return nil, nil end
	local ok_inv, inv = pcall(unit_data_ext.read_component, unit_data_ext, "inventory")
	if not (ok_inv and inv) then return nil, nil end
	local wielded_slot = inv.wielded_slot
	if not wielded_slot or wielded_slot == "" then return nil, nil end

	local visual_loadout = ScriptUnit.has_extension(player_unit, "visual_loadout_system")
	if not visual_loadout or not visual_loadout.item_in_slot then return nil, nil end
	local ok_item, item = pcall(visual_loadout.item_in_slot, visual_loadout, wielded_slot)
	if not (ok_item and item) then return nil, nil end

	local ok_t, template = pcall(WeaponTemplate.weapon_template_from_item, item)
	if not (ok_t and template) then return nil, nil end
	if template.name == "unarmed" then return nil, nil end
	note_gear(template.name, item)
	return item, template.name
end

local function equipped_slot_template(slot_name)
	if not slot_name then return nil, nil end
	if not (Managers and Managers.player and Managers.player.local_player_safe) then
		return nil, nil
	end
	local local_player = Managers.player:local_player_safe(1)
	if not local_player then return nil, nil end
	local player_unit = local_player.player_unit
	if not player_unit or not ALIVE[player_unit] then return nil, nil end

	local visual_loadout = ScriptUnit.has_extension(player_unit, "visual_loadout_system")
	if not visual_loadout or not visual_loadout.item_in_slot then return nil, nil end
	local ok_item, item = pcall(visual_loadout.item_in_slot, visual_loadout, slot_name)
	if not (ok_item and item) then return nil, nil end

	local ok_t, template = pcall(WeaponTemplate.weapon_template_from_item, item)
	if not (ok_t and template) then return nil, nil end
	if template.name == "unarmed" then return nil, nil end
	note_gear(template.name, item)
	return item, template.name
end

local function local_wielded_slot()
	if not (Managers and Managers.player and Managers.player.local_player_safe) then return nil end
	local local_player = Managers.player:local_player_safe(1)
	if not local_player then return nil end
	local player_unit = local_player.player_unit
	if not player_unit or not ALIVE[player_unit] then return nil end
	local unit_data_ext = ScriptUnit.has_extension(player_unit, "unit_data_system")
	if not unit_data_ext then return nil end
	local ok_inv, inv = pcall(unit_data_ext.read_component, unit_data_ext, "inventory")
	if not (ok_inv and inv) then return nil end
	local s = inv.wielded_slot
	if not s or s == "" then return nil end
	return s
end

mod._sb_tally     = setmetatable({}, { __mode = "k" })
mod._sb_apply_ctx = setmetatable({}, { __mode = "k" })

mod._wield_time = { slot_primary = 0, slot_secondary = 0 }
mod._mission_loadout = {}
mod._mission_time = 0

local function sb_tally_add_soulblaze(unit, dmg)
	if not (unit and dmg and dmg > 0) then return end
	local t = mod._sb_tally[unit]
	if not t then t = { sb = 0, nw = 0, w = {} } mod._sb_tally[unit] = t end
	t.sb = t.sb + dmg
end

local function sb_tally_add_weapon(unit, template_name, item, dmg)
	if not (unit and template_name and dmg and dmg > 0) then return end
	local t = mod._sb_tally[unit]
	if not t then t = { sb = 0, nw = 0, w = {} } mod._sb_tally[unit] = t end
	local e = t.w[template_name]
	if not e then e = { dmg = 0, item = item } t.w[template_name] = e end
	e.dmg = e.dmg + dmg
	if item then e.item = item end
end

local function sb_tally_add_nonweapon(unit, dmg)
	if not (unit and dmg and dmg > 0) then return end
	local t = mod._sb_tally[unit]
	if not t then t = { sb = 0, nw = 0, w = {} } mod._sb_tally[unit] = t end
	t.nw = (t.nw or 0) + dmg
end

local function top_weapon_in_tally(unit)
	local t = mod._sb_tally[unit]
	if not t then return nil, nil, 0, 0, 0 end
	local top_dmg, top_tmpl, top_item = 0, nil, nil
	for tmpl, e in pairs(t.w) do
		if (e.dmg or 0) > top_dmg then
			top_dmg, top_tmpl, top_item = e.dmg, tmpl, e.item
		end
	end
	return top_tmpl, top_item, top_dmg, (t.nw or 0), (t.sb or 0)
end

local DOT_APPLY_HIT_WINDOW = 1.0

local GAS_WIELDED_DOT_APPLIER = {
	burning = "flamer_p1_m1",
}

local function recent_weapon_hit(target_unit)
	local hit = mod._last_damaging_hit[target_unit]
	if not (hit and hit.template_name) then return nil, nil, nil end
	local now = _game_time()
	if now and hit.t and (now - hit.t) > DOT_APPLY_HIT_WINDOW then return nil, nil, nil end
	return hit.item, hit.template_name, hit.melee
end

local GRENADE_LIQUID_BUFFS = {
	broker_tox_grenade_in_liquid_buff = "toxin",
	flame_grenade_liquid_area         = "burning",
	fire_burninating                  = "burning",
}

local GRENADE_LIQUID_TTL = 12

mod._grenade_liquid = setmetatable({}, { __mode = "k" })

local PSYKER_STAFF_TEMPLATES = {
	forcestaff_p1_m1 = true,
	forcestaff_p2_m1 = true,
	forcestaff_p3_m1 = true,
	forcestaff_p4_m1 = true,
}

local function capture_soulblaze_apply_ctx(target_unit, n)
	if not target_unit then return end
	local a = mod._sb_apply_ctx[target_unit]
	if not a then
		a = { staff_stacks = 0, nonstaff_stacks = 0, unknown_stacks = 0 }
		mod._sb_apply_ctx[target_unit] = a
	end
	if local_player_archetype() == "psyker" then a.is_psyker = true end
	n = tonumber(n) or 1
	if n < 1 then n = 1 end

	local st_item, st_tn = equipped_slot_template("slot_secondary")
	if st_tn and PSYKER_STAFF_TEMPLATES[st_tn] then
		a.staff_equipped_item     = st_item
		a.staff_equipped_template = st_tn
	end
	local me_item, me_tn = equipped_slot_template("slot_primary")
	if me_tn then
		a.melee_equipped_item     = me_item
		a.melee_equipped_template = me_tn
	end

	local now = _game_time()
	local imp = mod._last_weapon_impact
	local recent = imp and imp.template_name and now and imp.t
		and (now - imp.t) <= DOT_APPLY_HIT_WINDOW
	if recent and PSYKER_STAFF_TEMPLATES[imp.template_name] then
		a.staff_stacks = a.staff_stacks + n
		a.staff_item, a.staff_template = imp.item, imp.template_name
	elseif recent then
		a.nonstaff_stacks = a.nonstaff_stacks + n
		a.nonstaff_item, a.nonstaff_template = imp.item, imp.template_name
	else
		a.unknown_stacks = a.unknown_stacks + n
	end
end

local function decide_soulblaze_kill(attacked_unit)
	local tally = mod._sb_tally[attacked_unit]
	if not (tally and tally.sb and tally.sb > 0) then return nil end

	local top_tmpl, top_item, top_dmg, nw_dmg = top_weapon_in_tally(attacked_unit)

	if top_tmpl and top_dmg >= tally.sb and top_dmg >= nw_dmg then
		return { mode = "weapon_kill", template = top_tmpl, item = top_item }
	end

	local a = mod._sb_apply_ctx[attacked_unit]
	local staff_stacks    = a and a.staff_stacks    or 0
	local nonstaff_stacks = a and a.nonstaff_stacks or 0
	if staff_stacks > nonstaff_stacks and a.staff_template then
		return { mode = "staff_kill", template = a.staff_template, item = a.staff_item }
	elseif nonstaff_stacks > staff_stacks and a.nonstaff_template then
		return { mode = "melee_soulblaze", template = a.nonstaff_template, item = a.nonstaff_item }
	end

	local staff_item, staff_tn = equipped_slot_template("slot_secondary")
	local is_staff = staff_tn and PSYKER_STAFF_TEMPLATES[staff_tn]
	if not (staff_item and staff_tn) and a and a.staff_equipped_template then
		staff_tn, staff_item = a.staff_equipped_template, a.staff_equipped_item
		is_staff = true
	end
	local wt = mod._wield_time or {}
	if staff_tn and (wt.slot_secondary or 0) > (wt.slot_primary or 0) then
		if is_staff then
			return { mode = "staff_kill", template = staff_tn, item = staff_item }
		end
		return { mode = "melee_soulblaze", template = staff_tn, item = staff_item }
	end
	local melee_item, melee_tn = equipped_slot_template("slot_primary")
	if not (melee_item and melee_tn) and a and a.melee_equipped_template then
		melee_tn, melee_item = a.melee_equipped_template, a.melee_equipped_item
	end
	if melee_tn then
		return { mode = "melee_soulblaze", template = melee_tn, item = melee_item }
	end
	if is_staff then
		return { mode = "staff_kill", template = staff_tn, item = staff_item }
	end
	if staff_tn then
		return { mode = "melee_soulblaze", template = staff_tn, item = staff_item }
	end
	return nil
end

local function soulblaze_damage_applier()
	local now = _game_time()
	local imp = mod._last_weapon_impact
	if imp and imp.template_name and now and imp.t
	   and (now - imp.t) <= DOT_APPLY_HIT_WINDOW then
		return imp.item, imp.template_name
	end
	local staff_item, staff_tn = equipped_slot_template("slot_secondary")
	local wt = mod._wield_time or {}
	if staff_tn and (wt.slot_secondary or 0) > (wt.slot_primary or 0) then
		return staff_item, staff_tn
	end
	local melee_item, melee_tn = equipped_slot_template("slot_primary")
	if melee_tn then return melee_item, melee_tn end
	if staff_tn then return staff_item, staff_tn end
	return nil, nil
end

local function record_dot_source_resolved(target_unit, buff_template_name, owner_unit, count)
	if not target_unit then return end

	if not is_local_player_unit(owner_unit) then
		if is_local_player_companion(owner_unit) then
			mod._companion_dot_units[target_unit] = true
		end
		return
	end

	local liquid_dtype = buff_template_name and GRENADE_LIQUID_BUFFS[buff_template_name]
	if liquid_dtype then
		local marks = mod._grenade_liquid[target_unit]
		if not marks then marks = {} mod._grenade_liquid[target_unit] = marks end
		marks[liquid_dtype] = _game_time() or 0
		return
	end

	local dtype = buff_template_name and BUFF_TEMPLATE_DAMAGE_TYPE[buff_template_name]
	if not dtype then return end

	local from_grenade = false
	do
		local marks = mod._grenade_liquid[target_unit]
		local marked = marks and marks[dtype]
		if marked then
			local t = _game_time()
			from_grenade = (not t) or (t - marked) <= GRENADE_LIQUID_TTL
		end
	end

	local item, template_name, via_melee

	if from_grenade then
		item, template_name, via_melee = nil, nil, nil
	elseif buff_template_name == "warp_fire" then
		capture_soulblaze_apply_ctx(target_unit, count)
		item, template_name = soulblaze_damage_applier()
	else
		item, template_name, via_melee = recent_weapon_hit(target_unit)
		if not template_name then
			local wielded_item, wielded_tn = snapshot_local_wielded()
			if wielded_tn and GAS_WIELDED_DOT_APPLIER[dtype] == wielded_tn then
				item, template_name = wielded_item, wielded_tn
			end
		end
		if not template_name and dtype == "toxin" then
			local k = mod._last_melee_elite_kill
			local now = _game_time()
			if k and k.template_name and now and k.t
			   and (now - k.t) <= DOT_APPLY_HIT_WINDOW
			   and local_player_has_buff("broker_passive_toxin_spread_on_kills") then
				item, template_name = k.item, k.template_name
			end
		end
	end

	local by_type = mod._dot_source_by_unit[target_unit]
	if not by_type then
		by_type = {}
		mod._dot_source_by_unit[target_unit] = by_type
	end
	local sources = by_type[dtype]
	if not sources then
		sources = {}
		by_type[dtype] = sources
	end

	local now = _game_time()
	local n = tonumber(count) or 1
	if n < 1 then n = 1 end
	local key = template_name or "__nonweapon"
	local e = sources[key]
	if e then
		if now and e.t and (now - e.t) > DOT_SOURCE_TTL then
			e.count = 0
		end
		e.count = (e.count or 0) + n
		e.t = now
		e.item = item or e.item
		e.via_melee = via_melee or nil
		e.grenade = e.grenade or (from_grenade or nil)
	else
		sources[key] = {
			template_name = template_name,
			item          = item,
			count         = n,
			t             = now,
			dtype         = dtype,
			via_melee     = via_melee or nil,
			nonweapon     = not template_name or nil,
			grenade       = from_grenade or nil,
		}
	end
end

local function record_dot_source(self_buff_ext, buff_template_id, owner_unit_id, count)
	if not (Managers and Managers.state and Managers.state.unit_spawner) then return end
	local target_unit = self_buff_ext and self_buff_ext._unit
	if not target_unit then return end

	local ok_owner, owner_unit = pcall(Managers.state.unit_spawner.unit,
	                                    Managers.state.unit_spawner, owner_unit_id)
	if not ok_owner then return end

	local buff_template_name
	if NetworkLookup and NetworkLookup.buff_templates and buff_template_id then
		buff_template_name = NetworkLookup.buff_templates[buff_template_id]
	end

	record_dot_source_resolved(target_unit, buff_template_name, owner_unit, count)
end

mod:hook_safe(CLASS.BuffExtensionBase, "rpc_add_buff",
function(self, channel_id, game_object_id, buff_template_id, server_index,
		owner_unit_id, optional_lerp_value, optional_item_slot_id,
		optional_parent_buff_template_id, from_talent)
	if WKC_DEV_DEBUG and mod._debug_trace_remaining > 0 then
		local tn = NetworkLookup and NetworkLookup.buff_templates
		           and NetworkLookup.buff_templates[buff_template_id]
		local owner = Managers and Managers.state and Managers.state.unit_spawner
		              and Managers.state.unit_spawner:unit(owner_unit_id)
		mod:echo(string.format("[rpc_add_buff] tmpl=%s owner_is_us=%s target=%s",
			tostring(tn), tostring(is_local_player_unit(owner)),
			tostring(self and self._unit ~= nil)))
	end
	record_dot_source(self, buff_template_id, owner_unit_id, 1)
end)

mod:hook_safe(CLASS.BuffExtensionBase, "rpc_add_buff_with_stacks",
function(self, channel_id, game_object_id, buff_template_id, server_index_array,
		owner_unit_id, optional_lerp_value, optional_item_slot_id,
		optional_parent_buff_template_id)
	if WKC_DEV_DEBUG and mod._debug_trace_remaining > 0 then
		local tn = NetworkLookup and NetworkLookup.buff_templates
		           and NetworkLookup.buff_templates[buff_template_id]
		local owner = Managers and Managers.state and Managers.state.unit_spawner
		              and Managers.state.unit_spawner:unit(owner_unit_id)
		mod:echo(string.format("[rpc_add_buff_with_stacks] tmpl=%s owner_is_us=%s",
			tostring(tn), tostring(is_local_player_unit(owner))))
	end
	local stacks = type(server_index_array) == "table" and #server_index_array or 1
	record_dot_source(self, buff_template_id, owner_unit_id, stacks)
end)

local function _named_owner_unit(...)
	local n = select("#", ...)
	for i = 1, n, 2 do
		if select(i, ...) == "owner_unit" then
			return select(i + 1, ...)
		end
	end
	return nil
end

mod:hook_safe(CLASS.BuffExtensionBase, "add_internally_controlled_buff",
function(self, template_name, t, ...)
	if BUFF_TEMPLATE_DAMAGE_TYPE[template_name] then
		record_dot_source_resolved(self and self._unit, template_name, _named_owner_unit(...), 1)
	end
end)

mod:hook_safe(CLASS.BuffExtensionBase, "add_internally_controlled_buff_with_stacks",
function(self, template_name, stack_count, t, ...)
	if BUFF_TEMPLATE_DAMAGE_TYPE[template_name] then
		record_dot_source_resolved(self and self._unit, template_name, _named_owner_unit(...), stack_count)
	end
end)

local SPECIAL_ACTIVE_DAMAGE_PROFILES = {
	powermaul_explosion             = true,
	powermaul_explosion_outer       = true,
	ogryn_powermaul_explosion       = true,
	ogryn_powermaul_explosion_outer = true,
}

local WEAPON_AOE_FALLBACK = {
	close_light_plasma_demolition_p1_m2           = "plasmagun_p1_m2",
	far_light_plasma_demolition_p1_m2             = "plasmagun_p1_m2",
	close_charged_plasma_demolition_p1_m2         = "plasmagun_p1_m2",
	far_charged_plasma_demolition_p1_m2           = "plasmagun_p1_m2",
	arc_rifle_arc_chain_lightning_link_damage     = "arc_rifle_p1_m1",
	arc_rifle_arc_chain_lightning_link_damage_brace = "arc_rifle_p1_m1",
	powermaul_p3_arc_chain_lightning_link_damage  = "powermaul_p3_m1",
	chain_lightning_killing_blow                  = "powermaul_p3_m1",
	bolter_kill_explosion             = "bolter_p1_m1",
	bolter_stop_explosion             = "bolter_p1_m1",
	bolter_m2_kill_explosion          = "bolter_p1_m2",
	bolter_m2_stop_explosion          = "bolter_p1_m2",
	boltpistol_kill_explosion         = "boltpistol_p1_m1",
	boltpistol_stop_explosion         = "boltpistol_p1_m1",
	boltpistol_m2_kill_explosion      = "boltpistol_p1_m2",
	boltpistol_m2_stop_explosion      = "boltpistol_p1_m2",
	powermaul_explosion               = "powermaul_2h_p1_m1",
	powermaul_explosion_outer         = "powermaul_2h_p1_m1",
	ogryn_powermaul_explosion         = { "ogryn_powermaul_p1_m1", "ogryn_powermaul_p1_m2", "ogryn_powermaul_p1_m3" },
	ogryn_powermaul_explosion_outer   = { "ogryn_powermaul_p1_m1", "ogryn_powermaul_p1_m2", "ogryn_powermaul_p1_m3" },
	phosphor_pistol_backblast_explosion = "phosphor_pistol_p1_m1",
	needlepistol_explosion_1      = { "needlepistol_p1_m1", "needlepistol_p1_m2", "needlepistol_p1_m3" },
	needlepistol_explosion_parent = { "needlepistol_p1_m1", "needlepistol_p1_m2", "needlepistol_p1_m3" },
	close_special_gauntlet_demolitions = "ogryn_gauntlet_p1_m1",
	close_gauntlet_demolitions         = "ogryn_gauntlet_p1_m1",
	default_gauntlet_demolitions       = "ogryn_gauntlet_p1_m1",
	thumper_grenade_impact             = { "ogryn_thumper_p1_m1", "ogryn_thumper_p1_m2" },
	ogryn_thumper_p1_m2_close          = "ogryn_thumper_p1_m2",
	ogryn_thumper_p1_m2_close_instant  = "ogryn_thumper_p1_m2",
	ogryn_thumper_p1_m2_default        = "ogryn_thumper_p1_m2",
	ogryn_thumper_p1_m2_default_instant = "ogryn_thumper_p1_m2",
	default_warpfire_assault_burst    = "forcestaff_p2_m1",
	default_warpfire_assault          = "forcestaff_p2_m1",
	default_flamer_assault_burst      = "flamer_p1_m1",
	default_flamer_assault            = "flamer_p1_m1",
	force_staff_ball = {
		"forcestaff_p1_m1", "forcestaff_p3_m1", "forcestaff_p4_m1",
	},
	default_force_staff_demolition   = "forcestaff_p1_m1",
	close_force_staff_demolition     = "forcestaff_p1_m1",
	default_chain_lighting_attack    = "forcestaff_p3_m1",
	default_chain_lighting_interval  = "forcestaff_p3_m1",
	default_force_staff_bfg          = "forcestaff_p4_m1",
	force_staff_p4_demolition        = "forcestaff_p4_m1",
	close_force_staff_p4_demolition  = "forcestaff_p4_m1",
	forcesword_force_slash_low    = { "forcesword_2h_p1_m1", "forcesword_2h_p1_m2" },
	forcesword_force_slash_middle = { "forcesword_2h_p1_m1", "forcesword_2h_p1_m2" },
	forcesword_force_slash_high   = { "forcesword_2h_p1_m1", "forcesword_2h_p1_m2" },
}

local WARPSHOCK_SLASH_PROFILES = {
	forcesword_force_slash_low    = true,
	forcesword_force_slash_middle = true,
	forcesword_force_slash_high   = true,
}

local CHAIN_SHREDDER_DAMAGE_TYPES = {
	sawing_stuck = true,
}

local function resolve_aoe_fallback(dp_name)
	local fb = dp_name and WEAPON_AOE_FALLBACK[dp_name]
	if not fb then return nil, nil end
	local wielded_item, wielded_template_name = snapshot_local_wielded()
	if type(fb) == "table" then
		for i = 1, #fb do
			if wielded_template_name == fb[i] then
				return wielded_item, wielded_template_name
			end
		end
		return nil, nil
	end
	if wielded_template_name == fb and wielded_item then
		return wielded_item, fb
	end
	return nil, fb
end

local ARC_CHAIN_LINK_PROFILES = {
	arc_rifle_arc_chain_lightning_link_damage       = true,
	arc_rifle_arc_chain_lightning_link_damage_brace = true,
	powermaul_p3_arc_chain_lightning_link_damage    = true,
}

local ELECTROCUTION_PROFILES = {
	default_chain_lighting_interval                        = true,
	shockmaul_stun_interval_damage                        = true,
	powermaul_p2_stun_interval                            = true,
	powermaul_p2_stun_interval_basic                      = true,
	psyker_protectorate_spread_chain_lightning_interval   = true,
	psyker_protectorate_channel_chain_lightning_activated = true,
	psyker_heavy_swings_shock                             = true,
	shock_grenade_interval                                = true,
}

mod._NON_WEAPON_PROFILES = {}
mod._NON_WEAPON_SHARED = {
	default_grenade = {
		flamer_p1_m1          = true,
		forcestaff_p2_m1      = true,
		phosphor_pistol_p1_m1 = true,
	},
}

do
	local function nw(list)
		for i = 1, #list do mod._NON_WEAPON_PROFILES[list[i]] = true end
	end

	nw({
		"default_grenade", "close_grenade",
		"frag_grenade", "close_frag_grenade",
		"krak_grenade", "close_krak_grenade",
		"ogryn_grenade", "close_ogryn_grenade",
		"ogryn_box_cluster_frag_grenade", "ogryn_box_cluster_close_frag_grenade",
		"adamant_grenade", "close_adamant_grenade",
		"shock_grenade", "shock_grenade_stun_interval", "shock_mine_self_destruct",
		"smoke_grenade", "arc_grenade",
		"whistle_explosion", "close_whistle_explosion",
		"broker_tox_grenade",
		"broker_flash_grenade", "broker_flash_grenade_close",
		"broker_missile_launcher_explosion", "broker_missile_launcher_explosion_close",
		"missile_launcher_knockback",
	})

	nw({
		"frag_grenade_impact", "krak_grenade_impact", "fire_grenade_impact",
		"adamant_grenade_impact", "ogryn_grenade_impact",
		"ogryn_grenade_box_impact", "ogryn_grenade_box_cluster_impact",
		"ogryn_friendly_rock_impact",
		"broker_flash_grenade_impact", "broker_missile_launcher_impact",
	})

	nw({
		"adamant_shout", "adamant_shout_damage",
		"adamant_charge_impact", "adamant_charge_damage",
		"ogryn_charge_impact", "ogryn_charge_impact_damage",
		"ogryn_charge_finish", "ogryn_charge_finish_damage",
		"shout_stagger_ogryn_taunt", "shout_stagger_veteran",
		"zealot_dash_impact", "zealot_dash_health_to_damage_transfer",
		"zealot_preacher_ability_close", "zealot_preacher_ability_far",
		"zealot_channel_stagger", "zealot_throwing_knives",
		"psyker_smite_kill", "psyker_smite_light", "psyker_smite_heavy",
		"psyker_smite_stagger", "psyker_stun", "psyker_shield_stagger",
		"psyker_biomancer_shout", "psyker_biomancer_shout_damage",
		"psyker_biomancer_soul",
		"psyker_throwing_knives", "psyker_throwing_knives_psychic_fortress",
		"force_field_explosion_damage",
		"broker_punk_rage_shout", "broker_vultures_mark_aoe_stagger",
		"broker_stimm_field", "broker_stimm_field_close",
		"cryptic_discharge_explosion", "cryptic_overload_keystone_debuff_explosion",
		"expedition_artillery_strike", "expedition_artillery_strike_close",
		"expedition_artillery_strike_grenade_impact",
		"luggable_battery",
	})

	nw({
		"flame_grenade_liquid_area_fire_burning",
	})
end

function mod._non_weapon_kill_owner(top_template, top_damage, blitz_damage, soulblaze_damage)
	if not top_template then return nil end
	if (top_damage or 0) < (blitz_damage or 0) then return nil end
	if (top_damage or 0) < (soulblaze_damage or 0) then return nil end
	return top_template
end

local function is_non_weapon_profile(dp_name)
	if not (dp_name and mod._NON_WEAPON_PROFILES[dp_name]) then return false end
	local shared = mod._NON_WEAPON_SHARED[dp_name]
	if shared then
		local _, primary = equipped_slot_template("slot_primary")
		if primary and shared[primary] then return false end
		local _, secondary = equipped_slot_template("slot_secondary")
		if secondary and shared[secondary] then return false end
	end
	return true
end

local HIT_CREDIT_DENIED_ATTACK_TYPES = {}
do
	local denied = {
		"buff", "melee", "push", "shout", "door_smash",
		"companion_dog", "incapacitating_pounce", "incapacitating_net",
	}
	for i = 1, #denied do
		local v = rawget(attack_types, denied[i])
		if v ~= nil then HIT_CREDIT_DENIED_ATTACK_TYPES[v] = true end
	end
end
mod._HIT_CREDIT_DENIED_ATTACK_TYPES = HIT_CREDIT_DENIED_ATTACK_TYPES

local function hit_credit_allowed(attack_type, dp_name)
	if attack_type ~= nil and HIT_CREDIT_DENIED_ATTACK_TYPES[attack_type] then return false end
	if is_companion_damage_profile_name(dp_name) then return false end
	if is_non_weapon_profile(dp_name) then return false end
	return true
end

mod._DOT_ALLOW_PROFILES = {
	psyker_heavy_swings_shock = "electrocution",
}

mod._MELEE_ONLY_BLEED = {}
mod._BROKER_WEAPONS = {}
mod._BLESSING_INSTAKILL_WEAPONS = {}
mod._DOT_DENY = {}

do
	local function mark(set, list)
		for i = 1, #list do set[list[i]] = true end
	end

	mark(mod._BLESSING_INSTAKILL_WEAPONS, {
		"combatknife_p1_m1", "combatknife_p1_m2",
		"dual_shivs_p1_m1", "dual_shivs_p1_m2",
		"ogryn_club_p2_m1", "ogryn_club_p2_m2", "ogryn_club_p2_m3",
		"powermaul_p3_m1",
	})

	mark(mod._MELEE_ONLY_BLEED, {
		"ogryn_rippergun_p1_m1", "ogryn_rippergun_p1_m2", "ogryn_rippergun_p1_m3",
		"ogryn_thumper_p1_m1", "ogryn_thumper_p1_m2",
		"lasgun_p2_m1", "lasgun_p2_m2", "lasgun_p2_m3",
	})

	mark(mod._BROKER_WEAPONS, {
		"autogun_p1_m1", "autogun_p1_m2", "autogun_p1_m3",
		"autogun_p2_m1", "autogun_p2_m2", "autogun_p2_m3",
		"autogun_p3_m1", "autogun_p3_m2", "autogun_p3_m3",
		"autopistol_p1_m1", "boltpistol_p1_m1", "boltpistol_p1_m2",
		"chainaxe_p1_m1", "chainaxe_p1_m2",
		"chainsword_p1_m1", "chainsword_p1_m2",
		"combataxe_p1_m1", "combataxe_p1_m2", "combataxe_p1_m3",
		"combataxe_p2_m1", "combataxe_p2_m2", "combataxe_p2_m3",
		"combatknife_p1_m1", "combatknife_p1_m2",
		"combatsword_p1_m1", "combatsword_p1_m2", "combatsword_p1_m3",
		"combatsword_p2_m1", "combatsword_p2_m2", "combatsword_p2_m3",
		"crowbar_p1_m1", "dual_autopistols_p1_m1",
		"dual_shivs_p1_m1", "dual_shivs_p1_m2", "dual_stubpistols_p1_m1",
		"needlepistol_p1_m1", "needlepistol_p1_m2", "needlepistol_p1_m3",
		"saw_p1_m1",
		"shotgun_p1_m1", "shotgun_p1_m2", "shotgun_p1_m3", "shotgun_p2_m1",
		"stubrevolver_p1_m1", "stubrevolver_p1_m2",
	})

	local function deny(list, ...)
		local statuses = { ... }
		for i = 1, #list do
			local e = mod._DOT_DENY[list[i]]
			if not e then e = {}; mod._DOT_DENY[list[i]] = e end
			for j = 1, #statuses do e[statuses[j]] = true end
		end
	end

	deny({ "ogryn_club_p2_m1", "ogryn_club_p2_m2", "ogryn_club_p2_m3" },
		"burning", "electrocution")
	deny({ "laspistol_p1_m1", "laspistol_p1_m3" },
		"bleeding", "electrocution")
	deny({ "shotgun_p1_m3" }, "electrocution")
	deny({ "lasgun_p3_m1", "lasgun_p3_m2", "lasgun_p3_m3" },
		"bleeding", "electrocution")
	deny({ "ogryn_powermaul_p1_m1" }, "electrocution")
	deny({ "ogryn_heavystubber_p1_m1", "ogryn_heavystubber_p1_m2", "ogryn_heavystubber_p1_m3",
	       "ogryn_heavystubber_p2_m1", "ogryn_heavystubber_p2_m2", "ogryn_heavystubber_p2_m3" },
		"bleeding", "electrocution")
	deny({ "combataxe_p1_m1", "combataxe_p1_m2", "combataxe_p1_m3" },
		"burning", "electrocution")
	deny({ "autogun_p1_m1", "autogun_p1_m2", "autogun_p1_m3",
	       "autogun_p2_m1", "autogun_p2_m2", "autogun_p2_m3",
	       "autogun_p3_m1", "autogun_p3_m2", "autogun_p3_m3" },
		"bleeding", "burning", "electrocution")
	deny({ "shotgun_p1_m2" }, "burning", "electrocution")
	deny({ "stubrevolver_p1_m1", "stubrevolver_p1_m2" },
		"bleeding", "burning", "electrocution")
	deny({ "powersword_p1_m1", "powersword_p1_m2",
	       "powersword_p2_m1", "powersword_p2_m2" }, "burning")
	deny({ "flamer_p1_m1", "forcestaff_p1_m1", "forcestaff_p2_m1", "forcestaff_p4_m1" },
		"bleeding", "electrocution")
	deny({ "forcestaff_p3_m1" }, "bleeding")
	deny({ "combataxe_p2_m1", "combataxe_p2_m2", "combataxe_p2_m3" },
		"burning", "electrocution")
	deny({ "ogryn_gauntlet_p1_m1" }, "electrocution")
	deny({ "ogryn_pickaxe_2h_p1_m1", "ogryn_pickaxe_2h_p1_m2", "ogryn_pickaxe_2h_p1_m3" },
		"burning", "electrocution")
	deny({ "galvanic_rifle_p1_m1" }, "bleeding", "burning", "electrocution")
	deny({ "powermaul_p2_m1" }, "bleeding", "burning")
	deny({ "arc_rifle_p1_m1" }, "bleeding", "burning", "electrocution")
	deny({ "powersword_p3_m1" }, "bleeding", "burning")
	deny({ "powermaul_shield_p1_m1", "powermaul_shield_p1_m2" }, "bleeding", "burning")
	deny({ "transonic_sword_transonic_knife_p1_m1" }, "bleeding", "burning")
	deny({ "phosphor_pistol_p1_m1" }, "bleeding", "electrocution")
	deny({ "needlepistol_p1_m1", "needlepistol_p1_m2", "needlepistol_p1_m3" },
		"bleeding", "electrocution")
	deny({ "dual_autopistols_p1_m1", "dual_stubpistols_p1_m1" },
		"bleeding", "burning", "electrocution", "toxin")
	deny({ "ogryn_club_p1_m1", "ogryn_club_p1_m2", "ogryn_club_p1_m3" },
		"burning", "electrocution")
	deny({ "ogryn_combatblade_p1_m1", "ogryn_combatblade_p1_m2", "ogryn_combatblade_p1_m3" },
		"burning", "electrocution")
	deny({ "chainsword_p1_m1", "chainsword_p1_m2" }, "burning")
	deny({ "combatsword_p1_m1", "combatsword_p1_m2", "combatsword_p1_m3" },
		"burning", "electrocution")
	deny({ "combatknife_p1_m1", "combatknife_p1_m2" }, "burning")
	deny({ "saw_p1_m1" }, "bleeding", "burning", "electrocution")
	deny({ "forcesword_p1_m1", "forcesword_p1_m2", "forcesword_p1_m3",
	       "forcesword_2h_p1_m1", "forcesword_2h_p1_m2" },
		"bleeding", "burning", "electrocution")
	deny({ "thunderhammer_2h_p1_m1", "thunderhammer_2h_p1_m2" },
		"burning", "electrocution")
	deny({ "shotgun_p2_m1" }, "burning", "electrocution")
	deny({ "crowbar_p1_m1" }, "bleeding", "burning", "electrocution")
	deny({ "shotgun_p4_m1", "shotgun_p4_m2" }, "bleeding", "burning", "electrocution")
	deny({ "ogryn_rippergun_p1_m1", "ogryn_rippergun_p1_m2", "ogryn_rippergun_p1_m3" },
		"electrocution")
	deny({ "bolter_p1_m1", "bolter_p1_m2", "boltpistol_p1_m1", "boltpistol_p1_m2" },
		"burning", "electrocution")
	deny({ "dual_shivs_p1_m1", "dual_shivs_p1_m2" }, "burning", "electrocution")
	deny({ "powermaul_2h_p1_m1" }, "burning", "electrocution")
	deny({ "autopistol_p1_m1" }, "bleeding", "burning", "electrocution")
	deny({ "shotpistol_shield_p1_m1" }, "bleeding", "burning", "electrocution")
	deny({ "lasgun_p1_m1", "lasgun_p1_m2", "lasgun_p1_m3" },
		"bleeding", "electrocution")
	deny({ "ogryn_thumper_p1_m1", "ogryn_thumper_p1_m2" }, "electrocution")
	deny({ "lasgun_p2_m1", "lasgun_p2_m2", "lasgun_p2_m3" }, "electrocution")
	deny({ "plasmagun_p1_m1", "plasmagun_p1_m2" },
		"bleeding", "burning", "electrocution")
	deny({ "combatsword_p3_m1", "combatsword_p3_m2", "combatsword_p3_m3" },
		"burning", "electrocution")
	deny({ "combataxe_p3_m1", "combataxe_p3_m2", "combataxe_p3_m3" },
		"burning", "electrocution")
	deny({ "powersword_2h_p1_m1", "powersword_2h_p1_m2" }, "burning", "electrocution")
	deny({ "powermaul_p1_m1", "powermaul_p1_m2" }, "burning")
	deny({ "chainaxe_p1_m1", "chainaxe_p1_m2" }, "burning", "electrocution")
	deny({ "ogryn_powermaul_slabshield_p1_m1" }, "burning", "electrocution")
	deny({ "chainsword_2h_p1_m1", "chainsword_2h_p1_m2" }, "burning", "electrocution")
	deny({ "combatsword_p2_m1", "combatsword_p2_m2", "combatsword_p2_m3" },
		"burning", "electrocution")
	deny({ "shotgun_p1_m1" }, "burning", "electrocution")
end

function mod._dot_status_denied(template_name, dtype, kill_dp_name,
		used_dot_source, via_melee)
	if not (template_name and dtype) then return false end
	if kill_dp_name and mod._DOT_ALLOW_PROFILES[kill_dp_name] == dtype then
		return false
	end
	if dtype == "bleeding" and mod._MELEE_ONLY_BLEED[template_name] then
		return not (used_dot_source and via_melee)
	end
	if dtype == "toxin" and not mod._BROKER_WEAPONS[template_name] then
		return true
	end
	if dtype == "phosphor_dot" and not template_name:find("^phosphor_pistol") then
		return true
	end
	local deny = mod._DOT_DENY[template_name]
	return (deny and deny[dtype]) and true or false
end

local WEAPONS_WITH_MELEE_TRACKER = {
	ogryn_gauntlet_p1_m1 = true,
	ogryn_rippergun_p1_m1 = true,
	ogryn_rippergun_p1_m2 = true,
	ogryn_rippergun_p1_m3 = true,
	lasgun_p2_m1 = true,
	lasgun_p2_m2 = true,
	lasgun_p2_m3 = true,
}

local GAUNTLET_MELEE_PROFILES = {
	special_grenadier_gauntlet_smiter   = true,
	close_special_gauntlet_demolitions  = true,
}

local function classify_melee_kill(attack_type, dp_name)
	if attack_type == attack_types.melee then
		return true
	end
	if dp_name and GAUNTLET_MELEE_PROFILES[dp_name] then
		return true
	end
	return false
end

local TEMPLATE_PARRY_PROFILES = {
	combatsword_p1_m1 = { "combatsword_parry_special" },
	combatsword_p1_m2 = { "combatsword_parry_special" },
	combatsword_p1_m3 = { "combatsword_parry_special" },
	combatsword_p3_m1 = { "combatsword_p3_parry_special" },
	combatsword_p3_m2 = { "combatsword_p3_parry_special" },
	combatsword_p3_m3 = { "combatsword_p3_m3_parry_special" },
}

local function dispatch_honorific_notification(weapon_family, tier)
	if not (Managers and Managers.event) then return end

	Managers.event:trigger("event_add_notification_message", "custom", {
		line_1       = weapon_family,
		line_1_color = { 255, 240, 240, 240 },
		line_2       = mod:localize("wkc_honorific_unlocked"),
		line_2_color = { 255, 200, 200, 200 },
		line_3       = tier.name,
		line_3_color = table.clone(tier.color),
		color      = { 191, 30, 30, 30 },
		line_color = table.clone(tier.color),
	})
end

local function advance_honorific(w, template_name, notify)
	local prev_threshold = w.last_honorific_threshold or 0
	for _, tier in ipairs(HONORIFIC_TIERS) do
		if tier.threshold > prev_threshold and (w.kills or 0) >= tier.threshold then
			w.last_honorific_threshold = tier.threshold
			if notify and mod:get("wkc_honorific_notify")
			   and not (WKC_DEV_DEBUG and is_in_meat_grinder()) then
				local family = (w.display_family ~= "" and w.display_family)
				                or template_name
				dispatch_honorific_notification(family, tier)
			end
			break
		end
	end
end

function mod._note_instance_label(item, template_name)
	local S = mod._stats
	if not (S and S.instances) then return end
	local gid = mod._gear_id_for(template_name, item)
	if not gid then return end
	local w = S.instances[gid]
	if not w then return end
	local ok, val = pcall(Items.display_name, item)
	if ok and type(val) == "string" and val ~= "" and val ~= "-" and val ~= "n/a"
	   and w.label ~= val then
		w.label = val
		mod._stats_dirty = true
	end
	local r = item_rating(item)
	if r and w.rating ~= r then
		w.rating = r
		mod._stats_dirty = true
	end
end

mod._last_attack_context = setmetatable({}, { __mode = "k" })

mod._instakill_pending = setmetatable({}, { __mode = "k" })

mod._global_shot_seq = 0
mod._pending_shot = {}
mod._projectile_shots = {}
mod._projectile_credited = setmetatable({}, { __mode = "k" })
mod._special_hit_seq = setmetatable({}, { __mode = "k" })

local _item_weapon_slot_cache = setmetatable({}, { __mode = "k" })
local function item_is_weapon_slot(item)
	local cached = _item_weapon_slot_cache[item]
	if cached ~= nil then return cached end
	local is_weapon = false
	local ok, slots = pcall(function() return item.slots end)
	if ok and type(slots) == "table" then
		for i = 1, #slots do
			local s = slots[i]
			if s == "slot_primary" or s == "slot_secondary" then
				is_weapon = true
				break
			end
		end
	elseif not ok or slots == nil then
		is_weapon = true
	end
	_item_weapon_slot_cache[item] = is_weapon
	return is_weapon
end

local function stash_kill_context(attacked_unit, named, damage_profile)
	if is_in_meat_grinder() and not WKC_DEV_DEBUG then return end

	if ATTACK_TYPE_PUSH and named.attack_type == ATTACK_TYPE_PUSH then
		return
	end

	local attacking_unit = named.attacking_unit
	local owner_unit     = named.attacking_unit_owner_unit
	if not (is_local_player_unit(attacking_unit) or is_local_player_unit(owner_unit)) then
		return
	end

	local item = named.item
	if not item then return end
	if not item_is_weapon_slot(item) then return end
	local template = WeaponTemplate.weapon_template_from_item(item)
	local template_name = template and template.name
	if not template_name then return end

	local dp_name = mod._current_sweep_damage_profile_name
	                or (damage_profile and damage_profile.name)
	                or nil

	local was_special_active
	if dp_name and SPECIAL_ACTIVE_DAMAGE_PROFILES[dp_name] then
		was_special_active = true
	elseif mod._current_sweep_is_special_active ~= nil then
		was_special_active = mod._current_sweep_is_special_active
	else
		was_special_active = is_local_player_weapon_special_active()
	end

	local was_stealth_kill = false
	if local_player_archetype() == "zealot" then
		was_stealth_kill = is_local_player_stealthed()
	end

	local target_undamaged = nil
	if template_name:sub(1, 13) == "thunderhammer" then
		target_undamaged = unit_is_undamaged(attacked_unit)
	end

	local was_hound_leaping = nil
	local hit_breed = breed_for_unit(attacked_unit)
	if hit_breed and HOUND_BREEDS[hit_breed.name] then
		was_hound_leaping = hound_is_leaping(attacked_unit)
	end

	mod._last_attack_context[attacked_unit] = {
		template_name      = template_name,
		item               = item,
		damage_type        = named.damage_type,
		dp_name            = dp_name,
		was_special_active = was_special_active,
		was_stealth_kill   = was_stealth_kill,
		target_undamaged   = target_undamaged,
		was_hound_leaping  = was_hound_leaping,
		is_critical_strike = named.is_critical_strike and true or false,
	}
end

local function record_damage_and_hits(attacked_unit, damage_dealt, named, damage_profile)
	if not (damage_dealt and damage_dealt > 0) then return end
	if is_in_meat_grinder() and not WKC_DEV_DEBUG then return end

	if ATTACK_TYPE_PUSH and named.attack_type == ATTACK_TYPE_PUSH then
		return
	end

	if (ATTACK_TYPE_COMPANION_DOG and named.attack_type == ATTACK_TYPE_COMPANION_DOG)
	   or is_companion_damage_profile_name(damage_profile and damage_profile.name) then
		return
	end

	local attacking_unit = named.attacking_unit
	local owner_unit     = named.attacking_unit_owner_unit
	if not (is_local_player_unit(attacking_unit) or is_local_player_unit(owner_unit)) then
		return
	end

	local item = named.item
	if not item then return end
	if not item_is_weapon_slot(item) then return end
	local template = WeaponTemplate.weapon_template_from_item(item)
	local template_name = template and template.name
	if not template_name then return end

	local stamp = {
		template_name = template_name,
		item          = item,
		t             = _game_time(),
		melee         = (named.attack_type == attack_types.melee) or nil,
	}
	mod._last_damaging_hit[attacked_unit] = stamp
	mod._last_weapon_impact = stamp

	local w = get_weapon_bucket(template_name, item)
	capture_display_names(w, item)

	if mod._pending_shot[template_name]
	   and hit_credit_allowed(named.attack_type, damage_profile and damage_profile.name) then
		mod._pending_shot[template_name] = nil
		bump(w, "shots_hit", 1)
	end

	local ctx = mod._last_attack_context[attacked_unit]
	if ctx and ctx.was_special_active then
		local seq = mod._global_shot_seq or 0
		if mod._special_hit_seq[attacked_unit] ~= seq then
			mod._special_hit_seq[attacked_unit] = seq
			bump(w, "special_active_hits", 1)
		end
	end

	mod._stats_dirty = true
end

local HAVOC_MODIFIERS = {
	{ key = "rotten_armor",        display = "Rotten Armour",          loc = "loc_havoc_rotten_armor_name",             buffs = { "mutator_rotten_armor" } },
	{ key = "blight_spreads",      display = "Blight Spreads",         loc = "loc_havoc_enemies_corrupted_name",        buffs = { "havoc_corrupted_enemies" } },
	{ key = "cranial_corruption",  display = "Cranial Corruption",     loc = "loc_havoc_enemies_parasite_headshot_name", buffs = { "headshot_parasite_enemies" } },
	{ key = "pus_hardened",        display = "Pus-Hardened Skin",      loc = "loc_havoc_tougher_skin_name",             buffs = { "havoc_toughened_skin" } },
	{ key = "encroaching_garden",  display = "The Encroaching Garden", loc = "loc_havoc_encroaching_garden_name",       buffs = { "havoc_encroaching_garden" } },
	{ key = "final_toll",          display = "The Final Toll",         loc = "loc_havoc_mutator_enraged_name",          buffs = { "havoc_enraged_enemies_trigger", "havoc_enraged_enemies" } },
	{ key = "rampaging",           display = "Rampaging Enemies",      loc = "loc_havoc_bolstering_enemies_name",       buffs = { "havoc_bolstering" } },
	{ key = "contaminated_stimms", display = "Contaminated Stimms",    loc = "loc_havoc_stimmed_minions_name",          keyword = "stimmed" },
}
mod._HAVOC_MODIFIERS = HAVOC_MODIFIERS

local function _mutator_active(name)
	local mm = Managers and Managers.state and Managers.state.mutator
	if not mm then return false end
	local ok, mut = pcall(mm.mutator, mm, name)
	return ok and mut ~= nil
end

local function _unit_buff_extension(unit)
	if not (ScriptUnit and unit) then return nil end
	local ok, ext = pcall(ScriptUnit.has_extension, unit, "buff_system")
	return ok and ext or nil
end

local function _unit_has_havoc_modifier(buff_ext, hm)
	if not buff_ext then return false end
	if hm.keyword and buff_ext.has_keyword then
		local ok, has = pcall(buff_ext.has_keyword, buff_ext, hm.keyword)
		if ok and has then return true end
	end
	if hm.buffs and buff_ext.has_buff_using_buff_template then
		for i = 1, #hm.buffs do
			local ok, has = pcall(buff_ext.has_buff_using_buff_template, buff_ext, hm.buffs[i])
			if ok and has then return true end
		end
	end
	return false
end

local HAVOC_MISSION_INDICATORS = {
	"havoc_higher_stagger_thresholds",
	"mutator_havoc_more_points_allowed_terror_event",
}
local function _is_havoc_mission()
	local dm = Managers and Managers.state and Managers.state.difficulty
	if dm and dm.get_parsed_havoc_data then
		local ok, data = pcall(dm.get_parsed_havoc_data, dm)
		if ok and data ~= nil then return true end
	end
	for i = 1, #HAVOC_MISSION_INDICATORS do
		if _mutator_active(HAVOC_MISSION_INDICATORS[i]) then return true end
	end
	return false
end

local function record_havoc(w, attacked_unit, breed_name)
	if not _is_havoc_mission() then return end

	bump(w, "havoc_kills", 1)
	local th = mod._stats.totals
	th.havoc_kills = (th.havoc_kills or 0) + 1

	local buff_ext = _unit_buff_extension(attacked_unit)
	if not buff_ext then return end

	for i = 1, #HAVOC_MODIFIERS do
		local hm = HAVOC_MODIFIERS[i]
		if _unit_has_havoc_modifier(buff_ext, hm) then
			bump_sub(w, "havoc", hm.key, 1)
			th.havoc = th.havoc or {}
			th.havoc[hm.key] = (th.havoc[hm.key] or 0) + 1
		end
	end
end

local function record_kill(attacked_unit, attacking_unit, attack_result, hit_weakspot, is_critical_strike, attack_type, damage_profile)
	if attack_result ~= attack_results.died then return end
	if not attacked_unit then return end
	if is_in_meat_grinder() and not WKC_DEV_DEBUG then return end
	local is_us = is_local_player_unit(attacking_unit)

	if WKC_DEV_DEBUG and mod._debug_trace_remaining > 0 then
		mod._debug_trace_remaining = mod._debug_trace_remaining - 1
		local ctx_dbg = mod._last_attack_context[attacked_unit]
		local ds_dbg  = mod._dot_source_by_unit[attacked_unit]
		local ledger_dbg = ""
		if ds_dbg then
			for dtype, sources in pairs(ds_dbg) do
				for tn, e in pairs(sources) do
					ledger_dbg = ledger_dbg .. string.format(" %s:%s=%d", dtype, tn, e.count or 0)
				end
			end
		end
		mod:echo(string.format("[KILL] is_us=%s atk_type=%s dp=%s ctx=%s%s dot_ledger=%s%s companion_dot=%s",
			tostring(is_us), tostring(attack_type),
			tostring(damage_profile and damage_profile.name),
			tostring(ctx_dbg ~= nil),
			ctx_dbg and (" tmpl="..tostring(ctx_dbg.template_name)) or "",
			tostring(ds_dbg ~= nil), ledger_dbg,
			tostring(mod._companion_dot_units[attacked_unit] ~= nil)))
	end

	if not is_us then return end

	if ATTACK_TYPE_PUSH and attack_type == ATTACK_TYPE_PUSH then
		return
	end

	local instakill_info = mod._instakill_pending[attacked_unit]
	mod._instakill_pending[attacked_unit] = nil

	if (ATTACK_TYPE_COMPANION_DOG and attack_type == ATTACK_TYPE_COMPANION_DOG)
	   or is_companion_damage_profile_name(damage_profile and damage_profile.name) then
		mod._last_attack_context[attacked_unit] = nil
		mod._dot_source_by_unit[attacked_unit]  = nil
		mod._companion_dot_units[attacked_unit] = nil
		return
	end

	do
		local prop_breed = breed_for_unit(attacked_unit)
		if prop_breed and mod._PROP_BREEDS[prop_breed.name] then
			mod._last_attack_context[attacked_unit] = nil
			mod._dot_source_by_unit[attacked_unit]  = nil
			mod._companion_dot_units[attacked_unit] = nil
			return
		end
	end

	local ctx = mod._last_attack_context[attacked_unit]
	mod._last_attack_context[attacked_unit] = nil

	local dot_src, dot_from_grenade
	if attack_type == attack_types.buff then
		local kill_dtype = damage_profile and damage_profile.name
		                   and TICK_PROFILE_DAMAGE_TYPE[damage_profile.name] or nil
		local entries = collect_live_dot_sources(attacked_unit, kill_dtype)
		if not entries and kill_dtype then
			entries = collect_live_dot_sources(attacked_unit, nil)
		end
		dot_src = best_weapon_dot_source(entries)
		if not dot_src and entries then
			for i = 1, #entries do
				if entries[i].grenade then dot_from_grenade = true break end
			end
		end
	else
		dot_src = best_weapon_dot_source(collect_live_dot_sources(attacked_unit, nil))
	end
	mod._dot_source_by_unit[attacked_unit] = nil

	local was_companion_dot = mod._companion_dot_units[attacked_unit]
	mod._companion_dot_units[attacked_unit] = nil

	if attack_type == attack_types.buff
	   and was_companion_dot
	   and not (dot_src and dot_src.template_name) then
		return
	end

	local kill_dp_name = damage_profile and damage_profile.name
	local forced_template_name, forced_item, forced_sb_dtype

	if kill_dp_name == "poxwalker_bomber_instakill" then
		local dmg = mod._last_damaging_hit[attacked_unit]
		mod._last_damaging_hit[attacked_unit] = nil
		local now = _game_time()
		local damaged_recently = dmg and dmg.template_name
			and (not now or not dmg.t or (now - dmg.t) <= BURSTER_DAMAGE_WINDOW)
		if not damaged_recently then
			mod._sb_tally[attacked_unit]     = nil
			mod._sb_apply_ctx[attacked_unit] = nil
			return
		end
		forced_template_name = dmg.template_name
		forced_item          = dmg.item
	end

	local nonweapon_kill = (dot_from_grenade or is_non_weapon_profile(kill_dp_name))
	                       and not forced_template_name or false
	local nonweapon_dropped = false
	if nonweapon_kill then
		ctx = nil
		local top_tmpl, top_item, top_dmg, nw_dmg, sb_dmg = top_weapon_in_tally(attacked_unit)
		local owner = mod._non_weapon_kill_owner(top_tmpl, top_dmg, nw_dmg, sb_dmg)
		if owner then
			forced_template_name = owner
			forced_item          = top_item
		else
			nonweapon_dropped = true
		end
	end

	local sb_decision = not nonweapon_kill and decide_soulblaze_kill(attacked_unit) or nil
	mod._sb_tally[attacked_unit]     = nil
	mod._sb_apply_ctx[attacked_unit] = nil
	if sb_decision and not forced_template_name then
		if sb_decision.mode == "melee_soulblaze" then
			if sb_decision.template then
				local sw = get_weapon_bucket(sb_decision.template, sb_decision.item)
				if sb_decision.item then capture_display_names(sw, sb_decision.item) end
				bump(sw, "soulblaze_kills", 1)
				mod._stats_dirty = true
				if (WKC_DEV_DEBUG and is_in_meat_grinder()) then
					wkc_dev_damage_log("KILL soulblaze -> wpn=" .. tostring(sb_decision.template)
						.. " Soulblaze Kills (Talents)+1 (NOT Total Kills)")
				end
			end
			return
		else
			forced_template_name = sb_decision.template
			forced_item          = sb_decision.item
			forced_sb_dtype      = (sb_decision.mode == "staff_kill") or nil
		end
	end

	bump_total("kills")

	if nonweapon_dropped then
		if (WKC_DEV_DEBUG and is_in_meat_grinder()) then
			wkc_dev_damage_log(string.format(
				"KILL DROPPED (blitz/ability kill, no weapon out-damaged it) dp=%s",
				tostring(kill_dp_name)))
		end
		mod._stats_dirty = true
		return
	end

	local template_name, fallback_item, used_dot_source, dot_source_damage_type
	local dot_source_via_melee

	if forced_template_name then
		template_name = forced_template_name
		fallback_item = forced_item
		if forced_sb_dtype then dot_source_damage_type = "warpfire" end
	elseif attack_type == attack_types.buff then
		if dot_src and dot_src.template_name then
			template_name = dot_src.template_name
			fallback_item = dot_src.item
			used_dot_source = true
			dot_source_damage_type = dot_src.dtype
			dot_source_via_melee = dot_src.via_melee
		end
		if not template_name and ctx then
			template_name = ctx.template_name
		end
		if not template_name then
			local hit = mod._last_damaging_hit[attacked_unit]
			local now = _game_time()
			if hit and hit.template_name
			   and (not now or not hit.t or (now - hit.t) <= DOT_SOURCE_TTL) then
				template_name = hit.template_name
				fallback_item = hit.item
			end
		end
	else
		if ctx then
			template_name = ctx.template_name
		else
			if dot_src and dot_src.template_name then
				template_name = dot_src.template_name
				fallback_item = dot_src.item
				used_dot_source = true
				dot_source_via_melee = dot_src.via_melee
			end
		end
	end

	if not template_name and damage_profile and damage_profile.name then
		local fb_item, fb_template = resolve_aoe_fallback(damage_profile.name)
		if fb_template then
			template_name = fb_template
			fallback_item = fb_item
		end
	end

	if not template_name then return end

	local damage_type_key
	if attack_type == attack_types.buff then
		damage_type_key = (kill_dp_name and TICK_PROFILE_DAMAGE_TYPE[kill_dp_name])
			or dot_source_damage_type or (ctx and ctx.damage_type)
	else
		damage_type_key = (ctx and ctx.damage_type) or dot_source_damage_type
	end
	local forced_electro = (kill_dp_name and ELECTROCUTION_PROFILES[kill_dp_name]) or false
	if forced_electro then
		damage_type_key = "electrocution"
	elseif not damage_type_key and damage_profile and damage_profile.name
	   and ARC_CHAIN_LINK_PROFILES[damage_profile.name] then
		damage_type_key = "arc_chain"
	end

	if damage_type_key
	   and (attack_type == attack_types.buff or forced_electro
	        or not (ctx and ctx.damage_type == damage_type_key))
	   and mod._dot_status_denied(template_name, damage_type_key, kill_dp_name,
	                             used_dot_source, dot_source_via_melee) then
		if (WKC_DEV_DEBUG and is_in_meat_grinder()) then
			wkc_dev_damage_log(string.format(
				"KILL DROPPED (%s cannot inflict %s) dp=%s",
				tostring(template_name), tostring(damage_type_key),
				tostring(kill_dp_name)))
		end
		mod._stats_dirty = true
		return
	end

	local is_blessing_instakill = (instakill_info and instakill_info.blessing)
		or kill_dp_name == "killing_blow"
		or kill_dp_name == "chain_lightning_killing_blow"
		or false
	if is_blessing_instakill and not mod._BLESSING_INSTAKILL_WEAPONS[template_name] then
		if (WKC_DEV_DEBUG and is_in_meat_grinder()) then
			wkc_dev_damage_log(string.format(
				"KILL DROPPED (%s has no killing-blow blessing) dp=%s",
				tostring(template_name), tostring(kill_dp_name)))
		end
		mod._stats_dirty = true
		return
	end

	local w = get_weapon_bucket(template_name,
		((ctx and not used_dot_source) and ctx.item) or fallback_item)
	if ctx and ctx.item and not used_dot_source then
		capture_display_names(w, ctx.item)
	elseif fallback_item then
		capture_display_names(w, fallback_item)
	end
	local breed = breed_for_unit(attacked_unit)
	local breed_name = breed and breed.name or "unknown"
	local b = get_breed_bucket(w, breed_name)

	bump(w, "kills", 1)
	bump(b, "kills", 1)

	if WEAPONS_WITH_MELEE_TRACKER[template_name] then
		local dp_for_class = (damage_profile and damage_profile.name)
		                     or (ctx and ctx.dp_name)
		if classify_melee_kill(attack_type, dp_for_class) then
			bump(w, "melee_kills", 1)
		end
	end

	if hit_weakspot then
		bump(w, "weakspot_kills", 1)
		bump_total("weakspot_kills")
	end
	local counts_as_crit = is_critical_strike
	                    or (instakill_info and instakill_info.was_crit)
	                    or false
	if counts_as_crit then
		bump(w, "crit_kills", 1)
		bump_total("crit_kills")
	end

	local is_elite, is_special = classify_breed(breed)
	if is_elite then
		bump(w, "elite_kills", 1)
		bump_total("elite_kills")
	end
	if is_special then
		bump(w, "special_kills", 1)
		bump_total("special_kills")
	end

	if is_elite and attack_type == attack_types.melee
	   and local_player_has_buff("broker_passive_toxin_spread_on_kills") then
		local kill_item = (ctx and not used_dot_source and ctx.item) or fallback_item
		local now = _game_time()
		mod._last_melee_elite_kill = {
			template_name = template_name,
			item          = kill_item,
			t             = now,
		}
		if now then
			upgrade_pending_splash_toxin(template_name, kill_item, now)
		end
	end

	if is_blessing_instakill then
		bump(w, "blessing_instakills", 1)
	end

	local pin_field = BOMBER_PIN_FIELD[breed_name]
	if pin_field and not mod._bomber_pin_pulled[attacked_unit] then
		w[pin_field] = (w[pin_field] or 0) + 1
	end

	if ctx and ctx.was_stealth_kill then
		bump(w, "backstab_kills", 1)
	end

	if HOUND_BREEDS[breed_name] then
		local leaping = ctx and ctx.was_hound_leaping
		if leaping == nil then
			leaping = hound_is_leaping(attacked_unit)
		end
		if leaping then
			local field = breed_name == "chaos_armored_hound"
				and "armored_hound_leap_kills" or "hound_leap_kills"
			w[field] = (w[field] or 0) + 1
		end
	end

	if DAEMONHOST_BREEDS[breed_name]
	   and ctx and ctx.target_undamaged
	   and attack_type ~= attack_types.buff
	   and template_name:sub(1, 13) == "thunderhammer" then
		bump(w, "crowns", 1)
	end

	record_havoc(w, attacked_unit, breed_name)

	if damage_type_key and not nonweapon_kill then
		local key = tostring(damage_type_key)
		bump_sub(w, "damage_type_kills", key, 1)
	end

	if not nonweapon_kill
	   and (attack_type == attack_types.buff or damage_type_key == "electrocution") then
		bump(w, "dot_kills", 1)
	end

	local counts_special_active = (ctx and ctx.was_special_active)
		or (kill_dp_name and SPECIAL_ACTIVE_DAMAGE_PROFILES[kill_dp_name])
		or false
	if not counts_special_active and ctx and ctx.damage_type
	   and CHAIN_SHREDDER_DAMAGE_TYPES[ctx.damage_type]
	   and (template_name:find("^chainsword") or template_name:find("^chainaxe")) then
		counts_special_active = true
	end
	if not counts_special_active and template_name:find("^combataxe_p3") then
		local dpn = kill_dp_name or (ctx and ctx.dp_name)
		if dpn and (dpn:find("shovel_special") or dpn:find("shovel_sticky")) then
			counts_special_active = true
		end
	end
	if counts_special_active then
		bump(w, "special_active_kills", 1)
	end

	if kill_dp_name and WARPSHOCK_SLASH_PROFILES[kill_dp_name] then
		bump(w, "warpshock_slash_kills", 1)
	end

	if ctx and ctx.dp_name then
		local parry_profiles = TEMPLATE_PARRY_PROFILES[template_name]
		if parry_profiles then
			for _, p in ipairs(parry_profiles) do
				if ctx.dp_name == p then
					bump(w, "parry_kills", 1)
					break
				end
			end
		end
	end

	local per_instance = mod._per_instance()
	advance_honorific(w, template_name, not per_instance)
	local mirror_bucket = _mirror[w]
	if mirror_bucket then
		advance_honorific(mirror_bucket, template_name, per_instance)
	end

	if (WKC_DEV_DEBUG and is_in_meat_grinder()) then
		wkc_dev_damage_log(string.format("KILL breed=%s -> wpn=%s TotalKills+1%s%s%s%s",
			tostring(breed_name), tostring(template_name),
			damage_type_key and (" DoT:" .. tostring(damage_type_key)) or "",
			counts_special_active and " special-active" or "",
			hit_weakspot and " weakspot" or "",
			counts_as_crit and " crit" or ""))
	end

	mod._stats_dirty = true
end

mod._unit_tracked_health = setmetatable({}, { __mode = "k" })

local function track_unit_health(attacked_unit, attack_result)
	if not attacked_unit then return end
	if attack_result == attack_results.died then
		mod._unit_tracked_health[attacked_unit] = nil
		return
	end
	local ok, ext = pcall(ScriptUnit.has_extension, attacked_unit, "health_system")
	if ok and ext and ext.current_health then
		local ok_h, ch = pcall(ext.current_health, ext)
		if ok_h and type(ch) == "number" then
			mod._unit_tracked_health[attacked_unit] = ch
		end
	end
end

local function clamp_overkill(attacked_unit, damage, attack_result)
	if attack_result ~= attack_results.died then return damage end
	local pre = mod._unit_tracked_health[attacked_unit]
	if pre == nil then
		local ok, ext = pcall(ScriptUnit.has_extension, attacked_unit, "health_system")
		if ok and ext and ext.max_health then
			local ok_m, mh = pcall(ext.max_health, ext)
			if ok_m and type(mh) == "number" then pre = mh end
		end
	end
	if type(pre) == "number" and pre > 0 and pre < damage then
		return pre
	end
	return damage
end

local function record_damage_from_report(attacked_unit, attacking_unit, damage, attack_type, damage_profile, attack_result)
	if not attacked_unit then return end
	if not (damage and damage > 0) then return end

	local dp_name = damage_profile and damage_profile.name
	if WKC_DEV_DEBUG and is_local_player_unit(attacking_unit) and is_in_meat_grinder() then
		local slot = local_wielded_slot()
		local _, wtn = equipped_slot_template(slot or "slot_secondary")
		local br = breed_for_unit(attacked_unit)
		wkc_dev_damage_log(string.format("dp=%s atk=%s dmg=%d breed=%s wielded=%s:%s",
			tostring(dp_name), tostring(attack_type), math.floor(damage or 0),
			tostring(br and br.name), tostring(slot), tostring(wtn)))
	end

	if is_in_meat_grinder() and not WKC_DEV_DEBUG then return end
	if not is_local_player_unit(attacking_unit) then return end

	if ATTACK_TYPE_PUSH and attack_type == ATTACK_TYPE_PUSH then return end

	if dp_name == "poxwalker_bomber_instakill" then return end

	if (ATTACK_TYPE_COMPANION_DOG and attack_type == ATTACK_TYPE_COMPANION_DOG)
	   or is_companion_damage_profile_name(dp_name) then
		return
	end

	damage = clamp_overkill(attacked_unit, damage, attack_result)

	if is_non_weapon_profile(dp_name) then
		sb_tally_add_nonweapon(attacked_unit, damage)
		bump_total("damage", damage)
		mod._stats_dirty = true
		if (WKC_DEV_DEBUG and is_in_meat_grinder()) then
			wkc_dev_damage_log("  -> blitz/ability damage, credited to no weapon")
		end
		return
	end

	local is_sb_tick = (attack_type == attack_types.buff) and dp_name
		and TICK_PROFILE_DAMAGE_TYPE[dp_name] == "warpfire" or false
	if is_sb_tick then
		sb_tally_add_soulblaze(attacked_unit, damage)
	end

	local ctx = mod._last_attack_context[attacked_unit]

	local template_name, item
	if attack_type == attack_types.buff then
		local dtype = dp_name and TICK_PROFILE_DAMAGE_TYPE[dp_name] or nil
		local entries = collect_live_dot_sources(attacked_unit, dtype)
		if not entries and dtype then
			entries = collect_live_dot_sources(attacked_unit, nil)
		end
		if entries then
			local total = 0
			for i = 1, #entries do
				total = total + (entries[i].count or 1)
			end
			if total > 0 then
				local breed = breed_for_unit(attacked_unit)
				local breed_name = breed and breed.name or "unknown"
				local paid = 0
				for i = 1, #entries do
					local e = entries[i]
					if e.template_name then
						local share = damage * (e.count or 1) / total
						local ew = get_weapon_bucket(e.template_name, e.item)
						if e.item then
							capture_display_names(ew, e.item)
						end
						bump(ew, "damage", share)
						local eb = get_breed_bucket(ew, breed_name)
						bump(eb, "damage", share)
						paid = paid + share
						if not is_sb_tick then
							sb_tally_add_weapon(attacked_unit, e.template_name, e.item, share)
						end
					end
				end
				if paid > 0 then
					bump_total("damage", paid)
					mod._stats_dirty = true
				end
				if (WKC_DEV_DEBUG and is_in_meat_grinder()) then
					local parts = {}
					for i = 1, #entries do
						local e = entries[i]
						parts[#parts + 1] = tostring(e.template_name or "__nonweapon(dropped)")
							.. ":" .. string.format("%.0f", damage * (e.count or 1) / total)
					end
					wkc_dev_damage_log("  -> DoT-split(" .. tostring(dp_name) .. ") "
						.. table.concat(parts, ", "))
				end
			end
			return
		elseif ctx then
			template_name, item = ctx.template_name, ctx.item
		end
	else
		if ctx then
			template_name, item = ctx.template_name, ctx.item
		else
			local entries = collect_live_dot_sources(attacked_unit, nil)
			if entries then
				local best
				for i = 1, #entries do
					local e = entries[i]
					if e.template_name and (not best or (e.count or 0) > (best.count or 0)) then
						best = e
					end
				end
				if best then
					template_name, item = best.template_name, best.item
				end
			end
		end
	end

	if not template_name and dp_name then
		local fb_item, fb_template = resolve_aoe_fallback(dp_name)
		if fb_template then
			template_name, item = fb_template, fb_item
		end
	end

	if not template_name then return end

	local w = get_weapon_bucket(template_name, item)
	if item then
		capture_display_names(w, item)
	end

	bump(w, "damage", damage)
	bump_total("damage", damage)
	if (WKC_DEV_DEBUG and is_in_meat_grinder()) then
		wkc_dev_damage_log("  -> credits wpn=" .. tostring(template_name)
			.. " TotalDamage +" .. tostring(math.floor(damage)))
	end

	if not is_sb_tick then
		sb_tally_add_weapon(attacked_unit, template_name, item, damage)
	end

	local breed = breed_for_unit(attacked_unit)
	local breed_name = breed and breed.name or "unknown"
	local b = get_breed_bucket(w, breed_name)
	bump(b, "damage", damage)

	if attack_type ~= attack_types.buff then
		if mod._pending_shot[template_name] and hit_credit_allowed(attack_type, dp_name) then
			mod._pending_shot[template_name] = nil
			bump(w, "shots_hit", 1)
		end

		local stamp = {
			template_name = template_name,
			item          = item,
			t             = _game_time(),
			melee         = (attack_type == attack_types.melee) or nil,
		}
		mod._last_damaging_hit[attacked_unit] = stamp
		mod._last_weapon_impact = stamp
		if attack_type == attack_types.explosion
		   or attack_type == attack_types.ranged then
			upgrade_pending_dots_to_weapon(attacked_unit, template_name, item, stamp.t)
		end
	end

	mod._stats_dirty = true
end

mod:hook_safe(CLASS.AttackReportManager, "add_attack_result",
function(self, damage_profile, attacked_unit, attacking_unit, attack_direction,
		hit_world_position, hit_weakspot, damage, attack_result, attack_type,
		damage_efficiency, is_critical_strike)
	local ok_d, err_d = xpcall(record_damage_from_report, debug.traceback,
		attacked_unit, attacking_unit, damage, attack_type, damage_profile, attack_result)
	if not ok_d then
		mod:echo("[Weapon Kill Counter] record_damage_from_report threw: " .. tostring(err_d))
	end

	local ok, err = xpcall(record_kill, debug.traceback,
		attacked_unit, attacking_unit, attack_result,
		hit_weakspot, is_critical_strike, attack_type, damage_profile)
	if not ok then
		mod:echo("[Weapon Kill Counter] record_kill threw: " .. tostring(err))
	end

	pcall(track_unit_health, attacked_unit, attack_result)
end)

mod._current_sweep_is_special_active = nil
mod._current_sweep_damage_profile_name = nil

mod:hook(CLASS.ActionSweep, "_do_damage_to_unit", function(func, self,
		damage_profile, hit_unit, hit_actor, hit_position, hit_normal,
		attack_direction, target_index, num_hit_enemies, hit_zone_name_or_nil,
		abort_attack, amount_of_mass_hit, damage_type, is_special_active, ...)
	mod._current_sweep_is_special_active = is_special_active and true or false
	mod._current_sweep_damage_profile_name = damage_profile and damage_profile.name or nil

	local r1, r2, r3, r4, r5 = func(self, damage_profile, hit_unit, hit_actor,
		hit_position, hit_normal, attack_direction, target_index,
		num_hit_enemies, hit_zone_name_or_nil, abort_attack, amount_of_mass_hit,
		damage_type, is_special_active, ...)

	mod._current_sweep_is_special_active = nil
	mod._current_sweep_damage_profile_name = nil
	return r1, r2, r3, r4, r5
end)

mod:hook(Attack, "execute", function(func, attacked_unit, damage_profile, ...)
	local found_us = false
	local attacking_unit_arg, item_arg
	local n = select("#", ...)
	for i = 1, n, 2 do
		local k = select(i, ...)
		if k == "attacking_unit" or k == "attacking_unit_owner_unit" then
			local v = select(i + 1, ...)
			if k == "attacking_unit" then
				attacking_unit_arg = v
			end
			if is_local_player_unit(v) then
				found_us = true
				break
			end
		elseif k == "item" then
			item_arg = select(i + 1, ...)
		end
	end

	local named
	if found_us then
		named = extract_named_args(...)
	elseif attacking_unit_arg ~= nil and item_arg ~= nil then
		local owner = projectile_owner_if_ours(attacking_unit_arg)
		if owner then
			named = extract_named_args(...)
			if named.attacking_unit_owner_unit == nil then
				named.attacking_unit_owner_unit = owner
			end
		end
	end

	if named and WKC_DEV_DEBUG and mod._debug_trace_remaining > 0 then
		mod._debug_trace_remaining = mod._debug_trace_remaining - 1
		local parts = {}
		local keys = {}
		for k in pairs(named) do keys[#keys+1] = k end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local v = named[k]
			local vs
			if type(v) == "table" then
				vs = "table"
			elseif type(v) == "userdata" then
				vs = "userdata"
			else
				vs = tostring(v)
			end
			parts[#parts+1] = tostring(k) .. "=" .. vs
		end
		parts[#parts+1] = "[damage_profile.name=" ..
			tostring(damage_profile and damage_profile.name or "nil") .. "]"
		parts[#parts+1] = "[sweep_is_special_active=" ..
			tostring(mod._current_sweep_is_special_active) .. "]"
		parts[#parts+1] = "[slot.special_active=" ..
			tostring(is_local_player_weapon_special_active()) .. "]"
		mod:echo("[Attack.execute] " .. table.concat(parts, ", "))
	end

	if named and named.instakill == true and attacked_unit ~= nil then
		local prof = damage_profile and damage_profile.name
		local prev_ctx = mod._last_attack_context[attacked_unit]
		mod._instakill_pending[attacked_unit] = {
			blessing = (prof == "killing_blow"
			         or prof == "chain_lightning_killing_blow"),
			was_crit = (prev_ctx and prev_ctx.is_critical_strike) or false,
		}
	end

	if named then
		pcall(stash_kill_context, attacked_unit, named, damage_profile)
	end

	local damage_dealt, attack_result, damage_efficiency, stagger_result, hit_weakspot =
		func(attacked_unit, damage_profile, ...)

	if named then
		pcall(record_damage_and_hits, attacked_unit, damage_dealt, named, damage_profile)
	end

	return damage_dealt, attack_result, damage_efficiency, stagger_result, hit_weakspot
end)

local function action_is_ours(self)
	if is_in_meat_grinder() and not WKC_DEV_DEBUG then return false end
	return is_local_player_unit(self._player_unit)
end

local function begin_shot(self)
	if not action_is_ours(self) then return end
	mod._global_shot_seq = (mod._global_shot_seq or 0) + 1
end

local function begin_counted_shot(self)
	if not action_is_ours(self) then return end
	local wt = self._weapon_template
	local template_name = wt and wt.name
	if not template_name then return end

	local w = get_weapon_bucket(template_name)
	bump(w, "shots_fired", 1)
	mod._global_shot_seq = (mod._global_shot_seq or 0) + 1
	mod._pending_shot[template_name] = mod._global_shot_seq
	mod._stats_dirty = true
end

local PROJECTILE_HIT_STAT = "hook_projectile_hit"
local PROJECTILE_QUEUE_MAX = 8

local function begin_projectile_shot(self, fire_config)
	if not action_is_ours(self) then return end
	local wt = self._weapon_template
	local template_name = wt and wt.name
	if not template_name then return end

	local w = get_weapon_bucket(template_name)
	bump(w, "shots_fired", 1)
	mod._global_shot_seq = (mod._global_shot_seq or 0) + 1

	local projectile = fire_config and fire_config.projectile
	local key = projectile and projectile.name
	if key then
		local queue = mod._projectile_shots[key]
		if not queue then
			queue = {}
			mod._projectile_shots[key] = queue
		end
		queue[#queue + 1] = template_name
		while #queue > PROJECTILE_QUEUE_MAX do
			table.remove(queue, 1)
		end
	end

	mod._stats_dirty = true
end

function mod._claim_projectile_shot(queues, projectile_name)
	local queue = projectile_name and queues[projectile_name]
	if not (queue and #queue > 0) then
		queue = nil
		for _, list in pairs(queues) do
			if #list > 0 then
				if queue then return nil end
				queue = list
			end
		end
	end
	if not (queue and #queue > 0) then return nil end
	return table.remove(queue, 1)
end

local function on_projectile_concluded(player, impact_hit, _weakspot, _kill, _elite,
		_special, projectile_name, explosion_hits, minion_hits)
	if not (player and is_local_player_unit(player.player_unit)) then return end

	local projectile_unit = mod._concluding_projectile
	if projectile_unit ~= nil then
		if mod._projectile_credited[projectile_unit] then return end
		mod._projectile_credited[projectile_unit] = true
	end

	local template_name = mod._claim_projectile_shot(mod._projectile_shots, projectile_name)
	if not template_name then return end

	if not (impact_hit == true
	        or (tonumber(explosion_hits) or 0) > 0
	        or (tonumber(minion_hits) or 0) > 0) then
		return
	end

	local w = get_weapon_bucket(template_name)
	bump(w, "shots_hit", 1)
	mod._stats_dirty = true
end

local function begin_staff_cast(self)
	local wt = self._weapon_template
	if not (wt and PSYKER_STAFF_TEMPLATES[wt.name]) then return end
	begin_counted_shot(self)
end

mod._concluded_shot = setmetatable({}, { __mode = "k" })

local function forget_concluded_shot(self)
	mod._concluded_shot[self] = nil
end

local function on_shot_concluded(self)
	if not action_is_ours(self) then return end
	local result = self._shot_result
	if not (result and result.data_valid) then return end
	local wt = self._weapon_template
	local template_name = wt and wt.name
	if not template_name then return end

	local component = self._action_component
	local shot_index = component and component.num_shots_fired
	if shot_index == nil then shot_index = mod._global_shot_seq or 0 end
	if mod._concluded_shot[self] == shot_index then return end
	mod._concluded_shot[self] = shot_index

	local w = get_weapon_bucket(template_name)
	bump(w, "shots_fired", 1)
	if result.hit_minion then
		bump(w, "shots_hit", 1)
	end
	mod._stats_dirty = true
end

local function before(handler)
	return function(func, self, ...)
		pcall(handler, self)
		return func(self, ...)
	end
end

mod:hook(CLASS.ActionShoot,           "_handle_shot_concluded_stats", before(on_shot_concluded))
mod:hook(CLASS.ActionShootHitScan,    "_handle_shot_concluded_stats", before(on_shot_concluded))
mod:hook(CLASS.ActionShootPellets,    "_handle_shot_concluded_stats", before(on_shot_concluded))
mod:hook(CLASS.ActionShootProjectile, "_handle_shot_concluded_stats", before(on_shot_concluded))
mod:hook(CLASS.ActionFlamerGas,       "_handle_shot_concluded_stats", before(on_shot_concluded))
mod:hook(CLASS.ActionFlamerGasBurst,  "_handle_shot_concluded_stats", before(on_shot_concluded))

mod:hook(CLASS.ActionShoot,           "start", before(forget_concluded_shot))
mod:hook(CLASS.ActionShootHitScan,    "start", before(forget_concluded_shot))
mod:hook(CLASS.ActionShootPellets,    "start", before(forget_concluded_shot))
mod:hook(CLASS.ActionShootProjectile, "start", before(forget_concluded_shot))
mod:hook(CLASS.ActionFlamerGas,       "start", before(forget_concluded_shot))
mod:hook(CLASS.ActionFlamerGasBurst,  "start", before(forget_concluded_shot))

mod:hook(CLASS.ActionShoot,        "_shoot", before(begin_shot))
mod:hook(CLASS.ActionShootHitScan, "_shoot", before(begin_shot))
mod:hook(CLASS.ActionShootPellets, "_prepare_shooting", before(begin_shot))
mod:hook(CLASS.ActionShootProjectile, "_shoot",
	function(func, self, position, rotation, power_level, charge_level, t, fire_config, ...)
		pcall(begin_projectile_shot, self, fire_config)
		return func(self, position, rotation, power_level, charge_level, t, fire_config, ...)
	end)

mod:hook(CLASS.ProjectileDamageExtension, "_record_impact_concluded_stats",
	function(func, self, ...)
		local previous = mod._concluding_projectile
		mod._concluding_projectile = self._projectile_unit
		local ok, err = pcall(func, self, ...)
		mod._concluding_projectile = previous
		if not ok then error(err) end
	end)

mod:hook(CLASS.StatsManager, "record_private", function(func, self, stat_name, player, ...)
	if stat_name == PROJECTILE_HIT_STAT then
		pcall(on_projectile_concluded, player, ...)
	end
	return func(self, stat_name, player, ...)
end)

for _, class_name in ipairs({
	"ActionSpawnProjectile",
	"ActionExplosion",
	"ActionChainLightning",
}) do
	local c = CLASS[class_name]
	if c then
		mod:hook(c, "start", before(begin_staff_cast))
	else
		mod:error("wkc: missing action class " .. class_name)
	end
end

for _, class_name in ipairs({ "ActionFlamerGasBurst", "ActionFlamerGas" }) do
	local c = CLASS[class_name]
	if c then
		mod:hook(c, "_shoot", before(begin_shot))
	else
		mod:error("wkc: missing action class " .. class_name)
	end
end

local _last_flush_t = 0
local _last_journal_t = 0
local _journal_dirty = false
local JOURNAL_INTERVAL = 15
local JOURNAL_PATH = WKC_JOURNAL_PATH
local JOURNAL_TMP  = WKC_JOURNAL_TMP

local function _serialize(v, out)
	local tv = type(v)
	if tv == "number" then
		out[#out + 1] = string.format("%.17g", v)
	elseif tv == "string" then
		out[#out + 1] = string.format("%q", v)
	elseif tv == "boolean" then
		out[#out + 1] = v and "true" or "false"
	elseif tv == "table" then
		out[#out + 1] = "{"
		for k, val in pairs(v) do
			local tk = type(k)
			if tk == "string" then
				out[#out + 1] = "[" .. string.format("%q", k) .. "]="
			elseif tk == "number" then
				out[#out + 1] = "[" .. string.format("%.17g", k) .. "]="
			else
				k = nil
			end
			if k ~= nil then
				_serialize(val, out)
				out[#out + 1] = ","
			end
		end
		out[#out + 1] = "}"
	end
end

local function write_crash_journal()
	local lua_io = Mods and Mods.lua and Mods.lua.io
	local lua_os = Mods and Mods.lua and Mods.lua.os
	if not lua_io then return end

	mod._stats.save_counter = (mod._stats.save_counter or 0) + 1

	local out = { "return " }
	local ok = pcall(_serialize, mod._stats, out)
	if not ok then return end
	local payload = table.concat(out)

	local f = lua_io.open(JOURNAL_TMP, "w+")
	if not f then
		if not mod._journal_write_failed then
			mod._journal_write_failed = true
			mod:error("wkc: cannot write the crash journal at " .. tostring(JOURNAL_TMP)
				.. " - stats still persist through the game settings, but an unclean exit will lose recent progress")
		end
		return
	end
	mod._journal_write_failed = nil
	f:write(payload)
	f:close()

	if lua_os then
		pcall(lua_os.remove, JOURNAL_PATH)
		pcall(lua_os.rename, JOURNAL_TMP, JOURNAL_PATH)
	end
end
mod._write_crash_journal = write_crash_journal

if mod._seed_appdata_pending then
	mod._seed_appdata_pending = nil
	pcall(write_crash_journal)
end

mod:hook_safe("UIHud", "update", function(self, dt, t)
	if not t then return end

	if dt and dt > 0 then
		local wt = mod._wield_time
		if wt then
			local slot = local_wielded_slot()
			if slot == "slot_primary" or slot == "slot_secondary" then
				wt[slot] = (wt[slot] or 0) + dt
			end
		end
		mod._mission_time = (mod._mission_time or 0) + dt
	end

	if t - (mod._loadout_snapshot_t or -99) >= 2 then
		mod._loadout_snapshot_t = t
		local ml = mod._mission_loadout
		if ml then
			local pit, ptn = equipped_slot_template("slot_primary")
			if ptn then ml.slot_primary = { template_name = ptn, item = pit } end
			local sit, stn = equipped_slot_template("slot_secondary")
			if stn then ml.slot_secondary = { template_name = stn, item = sit } end
		end
	end

	if t - (mod._mission_poll_t or -99) >= 1 then
		mod._mission_poll_t = t
		if mod._poll_mission_end then mod._poll_mission_end() end
	end

	if mod._stats_dirty and (t < _last_flush_t or t - _last_flush_t >= 5) then
		_last_flush_t = t
		mod._stats_dirty = false
		mod._stats.save_counter = (mod._stats.save_counter or 0) + 1
		mod:set("stats_data", mod._stats)
		_journal_dirty = true
	end

	if _journal_dirty and (t < _last_journal_t or t - _last_journal_t >= JOURNAL_INTERVAL) then
		_last_journal_t = t
		_journal_dirty = false
		write_crash_journal()
	end
end)

local function reset_all_stats()
	local prev_counter = (mod._stats and mod._stats.save_counter) or 0
	mod._stats = {
		totals = {
			kills = 0, elite_kills = 0, special_kills = 0,
			weakspot_kills = 0, crit_kills = 0, damage = 0,
		},
		weapons = {},
		instances = {},
		save_counter = prev_counter,
	}
	mod._gear_for_template = {}
	mod._label_seen = {}
	mod._stats_dirty = false
	mod:set("stats_data", mod._stats)
	write_crash_journal()
end

function mod.on_setting_changed(setting_id)
	if setting_id == "wkc_merge_factions" then
		if mod._layout_invalidate then mod._layout_invalidate() end
	end
	if setting_id == "wkc_per_instance" then
		if mod._layout_invalidate then mod._layout_invalidate() end
		if mod._share_refresh then pcall(mod._share_refresh) end
	end
	if setting_id == "wkc_reset_trigger" then
		if mod:get("wkc_reset_trigger") == 1 then
			mod:set("wkc_reset_trigger", 0)
			reset_all_stats()
			mod:notify(mod:localize("wkc_msg_reset_all"))
		end
	end
end

local MISSION_GAME_MODES = {
	coop_complete_objective = true,
	survival                = true,
}

local _mission_result_recorded = false

mod._MISSION_MIN_TIME = 120

local function record_mission_result(outcome)
	if outcome ~= "won" and outcome ~= "lost" then return end
	if _mission_result_recorded then return end

	local gm = Managers.state and Managers.state.game_mode
	local ok_name, mode_name = pcall(function() return gm:game_mode_name() end)
	if not ok_name or not MISSION_GAME_MODES[mode_name] then return end

	if (mod._mission_time or 0) < mod._MISSION_MIN_TIME then return end

	local slots = {}
	local pm = Managers.player
	local player = pm and pm.local_player_safe and pm:local_player_safe(1)
	local player_unit = player and player.player_unit
	local visual_loadout = player_unit
		and ScriptUnit.has_extension(player_unit, "visual_loadout_system")
	for _, slot in ipairs({ "slot_primary", "slot_secondary" }) do
		local item, template_name
		if visual_loadout then
			local ok_item, live_item = pcall(visual_loadout.item_in_slot, visual_loadout, slot)
			if ok_item and live_item then
				item = live_item
				template_name = live_item.weapon_template
			end
		end
		if not template_name then
			local snap = mod._mission_loadout and mod._mission_loadout[slot]
			if snap then
				item = snap.item
				template_name = snap.template_name
			end
		end
		if template_name then
			slots[#slots + 1] = { item = item, template_name = template_name }
		end
	end
	if #slots == 0 then return end

	_mission_result_recorded = true
	local won = outcome == "won"
	local is_havoc = false
	pcall(function() is_havoc = _is_havoc_mission() end)

	for i = 1, #slots do
		local w = get_weapon_bucket(slots[i].template_name, slots[i].item)
		bump(w, "missions_played", 1)
		if won then
			bump(w, "missions_won", 1)
		end
		if is_havoc then
			bump(w, "havoc_missions_played", 1)
			if won then
				bump(w, "havoc_missions_won", 1)
			end
		end
		if slots[i].item then
			capture_display_names(w, slots[i].item)
		end
	end

	mod._stats_dirty = false
	mod._stats.save_counter = (mod._stats.save_counter or 0) + 1
	mod:set("stats_data", mod._stats)
	if mod._write_crash_journal then
		mod._write_crash_journal()
	end
	if mod._share_refresh then
		pcall(mod._share_refresh)
	end
end

mod:hook_safe(CLASS.GameModeManager, "_set_end_conditions_met", function(self, outcome)
	local ok, err = pcall(record_mission_result, outcome)
	if not ok then
		mod:print_debug("record_mission_result failed: " .. tostring(err))
	end
end)

function mod._poll_mission_end()
	if _mission_result_recorded then return end
	if (mod._mission_time or 0) < mod._MISSION_MIN_TIME then return end
	local gm = Managers and Managers.state and Managers.state.game_mode
	if not (gm and gm.has_met_end_conditions and gm.end_conditions_met_outcome) then
		return
	end
	local ok_met, met = pcall(gm.has_met_end_conditions, gm)
	if not (ok_met and met) then return end
	local ok_out, outcome = pcall(gm.end_conditions_met_outcome, gm)
	if not ok_out then return end
	pcall(record_mission_result, outcome)
end

function mod.on_game_state_changed(status, state_name)
	_mode_mgr, _mode_is_grinder = nil, nil
	if status == "enter" then
		_mission_result_recorded = false
		if state_name == "GameplayStateRun" then
			mod._wield_time = { slot_primary = 0, slot_secondary = 0 }
			mod._mission_time = 0
			mod._mission_loadout = {}
			mod._loadout_snapshot_t = nil
			mod._mission_poll_t = nil
			mod._projectile_shots = {}
			mod._pending_shot = {}
			if WKC_DEV_DEBUG then
				mod._debug_stats = { weapons = {}, totals = {
					kills = 0, elite_kills = 0, special_kills = 0,
					weakspot_kills = 0, crit_kills = 0, damage = 0 } }
			end
		end
	end
end

mod._honorific_for_kills = honorific_for_kills
mod._MISSION_GAME_MODES = MISSION_GAME_MODES
mod._PSYKER_STAFF_TEMPLATES = PSYKER_STAFF_TEMPLATES
mod._WEAPONS_WITH_MELEE_TRACKER = WEAPONS_WITH_MELEE_TRACKER

for _, module_name in ipairs({ "wkc_layout", "wkc_tree", "wkc_ui", "wkc_overlay", "wkc_share" }) do
	if mod:io_dofile("wkc/scripts/mods/wkc/" .. module_name) == false then
		mod:error("wkc: " .. module_name
			.. " failed to load - the mod is running incomplete, see the error above")
	end
end
