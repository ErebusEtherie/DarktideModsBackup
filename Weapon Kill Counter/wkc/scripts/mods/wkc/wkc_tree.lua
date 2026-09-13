local mod = get_mod("wkc")

local LOC_PREFIX = "loc_breed_display_name_"

mod._tree_state = {}

local _name_cache = {}

function mod._game_loc(key, fallback)
	if type(key) ~= "string" or key == "" then return fallback end
	local cached = _name_cache[key]
	if cached then return cached end
	local name = fallback
	local ok, val = pcall(Localize, key)
	if ok and type(val) == "string" and val ~= "" and val ~= key
	   and string.sub(val, 1, 1) ~= "<" then
		name = val
	end
	_name_cache[key] = name
	return name
end

function mod._breed_row_name(row)
	if not row.loc then return row.name end
	return mod._game_loc(LOC_PREFIX .. row.loc, row.name)
end

mod._BREED_GROUPS = {
	{
		id = "elites", label = mod:localize("wkc_group_elites"), stored = "elite_kills",
		rows = {
			{ loc = "renegade_gunner",         name = "Scab Gunner",         breeds = { "renegade_gunner" } },
			{ loc = "cultist_gunner",          name = "Dreg Gunner",         breeds = { "cultist_gunner" } },
			{ loc = "renegade_shocktrooper",   name = "Scab Shotgunner",     breeds = { "renegade_shocktrooper" } },
			{ loc = "cultist_shocktrooper",    name = "Dreg Shotgunner",     breeds = { "cultist_shocktrooper" } },
			{ loc = "renegade_plasma_gunner",  name = "Scab Plasma Gunner",  breeds = { "renegade_plasma_gunner" } },
			{ loc = "renegade_radio_operator", name = "Scab Radio Operator", breeds = { "renegade_radio_operator" } },
			{ loc = "renegade_executor",       name = "Scab Mauler",         breeds = { "renegade_executor" } },
			{ loc = "chaos_ogryn_executor",    name = "Crusher",             breeds = { "chaos_ogryn_executor" } },
			{ loc = "chaos_ogryn_bulwark",     name = "Bulwark",             breeds = { "chaos_ogryn_bulwark" } },
			{ loc = "chaos_ogryn_gunner",      name = "Reaper",              breeds = { "chaos_ogryn_gunner" } },
			{ loc = "renegade_berzerker",      name = "Scab Rager",          breeds = { "renegade_berzerker" } },
			{ loc = "cultist_berzerker",       name = "Dreg Rager",          breeds = { "cultist_berzerker" } },
		},
	},
	{
		id = "specialists", label = mod:localize("wkc_group_specialists"), stored = "special_kills",
		rows = {
			{ loc = "renegade_flamer",       name = "Scab Flamer",     breeds = { "renegade_flamer", "renegade_flamer_mutator" } },
			{ loc = "cultist_flamer",        name = "Dreg Tox Flamer", breeds = { "cultist_flamer" } },
			{ loc = "renegade_grenadier",    name = "Scab Bomber",     breeds = { "renegade_grenadier" },
				sub = { stat = "scab_bomber_pin_denied", name = mod:localize("wkc_row_pin_pull") } },
			{ loc = "cultist_grenadier",     name = "Dreg Tox Bomber", breeds = { "cultist_grenadier" },
				sub = { stat = "tox_bomber_pin_denied", name = mod:localize("wkc_row_pin_pull") } },
			{ loc = "cultist_mutant",        name = "Mutant",          breeds = { "cultist_mutant", "cultist_mutant_mutator" } },
			{ loc = "chaos_hound",           name = "Pox Hound",       breeds = { "chaos_hound", "chaos_hound_mutator" },
				sub = { stat = "hound_leap_kills", name = mod:localize("wkc_row_mid_pounce") } },
			{ loc = "chaos_armored_hound",   name = "Armoured Pox Hound", breeds = { "chaos_armored_hound" },
				sub = { stat = "armored_hound_leap_kills", name = mod:localize("wkc_row_mid_pounce") } },
			{ loc = "renegade_netgunner",    name = "Trapper",         breeds = { "renegade_netgunner" } },
			{ loc = "renegade_sniper",       name = "Sniper",          breeds = { "renegade_sniper" } },
			{ loc = "chaos_poxwalker_bomber", name = "Poxburster",     breeds = { "chaos_poxwalker_bomber" } },
		},
	},
	{
		id = "bosses", label = mod:localize("wkc_group_bosses"),
		rows = {
			{ loc = "chaos_plage_ogryn",       name = "Plague Ogryn",      breeds = { "chaos_plague_ogryn" } },
			{ loc = "chaos_spawn",             name = "Chaos Spawn",       breeds = { "chaos_spawn" } },
			{ loc = "chaos_beast_of_nurgle",   name = "Beast of Nurgle",   breeds = { "chaos_beast_of_nurgle" } },
			{ loc = "chaos_daemonhost",        name = "Daemonhost",        breeds = { "chaos_daemonhost", "chaos_mutator_daemonhost" },
				sub = { stat = "crowns", name = mod:localize("wkc_row_crowns") } },
			{ loc = "chaos_ogryn_houndmaster", name = "Ogryn Pack Master", breeds = { "chaos_ogryn_houndmaster" } },
			{ loc = "renegade_captain",        name = "Scab Captain",      breeds = { "renegade_captain" } },
			{ loc = "cultist_captain",         name = "Dreg Captain",      breeds = { "cultist_captain" } },
			{ loc = "renegade_twin_captain",     name = "Rodin Karnak",    breeds = { "renegade_twin_captain" } },
			{ loc = "renegade_twin_captain_two", name = "Rinda Karnak",    breeds = { "renegade_twin_captain_two" } },
		},
	},
	{
		id = "lessers", label = mod:localize("wkc_group_lessers"),
		rows = {
			{ loc = "chaos_newly_infected", name = "Groaner",         breeds = { "chaos_newly_infected" } },
			{ loc = nil,                    name = mod:localize("wkc_breed_armored_groaner"), breeds = { "chaos_armored_infected" } },
			{ loc = "chaos_poxwalker",      name = "Poxwalker",
				breeds = { "chaos_poxwalker", "chaos_mutated_poxwalker", "chaos_lesser_mutated_poxwalker" } },
			{ loc = "cultist_ritualist",    name = "Ritualist",       breeds = { "cultist_ritualist", "chaos_mutator_ritualist" } },
			{ loc = "renegade_melee",       name = "Scab Bruiser",    breeds = { "renegade_melee" } },
			{ loc = "cultist_melee",        name = "Dreg Bruiser",    breeds = { "cultist_melee" } },
			{ loc = "renegade_vanguard",    name = "Scab Vanguard",   breeds = { "renegade_vanguard" } },
			{ loc = "cultist_vanguard",     name = "Dreg Vanguard",   breeds = { "cultist_vanguard" } },
			{ loc = "renegade_rifleman",    name = "Scab Shooter",    breeds = { "renegade_rifleman" } },
			{ loc = "renegade_assault",     name = "Scab Stalker",    breeds = { "renegade_assault" } },
			{ loc = "cultist_assault",      name = "Dreg Stalker",    breeds = { "cultist_assault" } },
		},
	},
}

local MERGE_PAIRS = {
	renegade_assault = { partners = { "cultist_assault" },
		name = mod:localize("wkc_breed_stalker") },
	renegade_captain = { partners = { "cultist_captain", "renegade_twin_captain", "renegade_twin_captain_two" },
		name = mod:localize("wkc_breed_captains") },
	renegade_berzerker = { partners = { "cultist_berzerker" },
		name = mod:localize("wkc_breed_rager") },
	renegade_flamer = { partners = { "cultist_flamer" },
		name = mod:localize("wkc_breed_flamer") },
	renegade_grenadier = { partners = { "cultist_grenadier" },
		name = mod:localize("wkc_breed_bomber") },
	renegade_gunner = { partners = { "cultist_gunner" },
		name = mod:localize("wkc_breed_gunner") },
	renegade_melee = { partners = { "cultist_melee" },
		name = mod:localize("wkc_breed_bruiser") },
	renegade_shocktrooper = { partners = { "cultist_shocktrooper" },
		name = mod:localize("wkc_breed_shotgunner") },
	renegade_vanguard = { partners = { "cultist_vanguard" },
		name = mod:localize("wkc_breed_vanguard") },
}

local _merged_groups
local function merged_groups()
	if _merged_groups then return _merged_groups end
	local out = {}
	for _, grp in ipairs(mod._BREED_GROUPS) do
		local g = { id = grp.id, label = grp.label, stored = grp.stored, rows = {} }
		local absorbed = {}
		for _, r in ipairs(grp.rows) do
			local m = r.loc and MERGE_PAIRS[r.loc]
			if m then
				for _, p in ipairs(m.partners) do absorbed[p] = true end
			end
		end
		for _, r in ipairs(grp.rows) do
			local m = r.loc and MERGE_PAIRS[r.loc]
			if m then
				local breeds, stats = {}, {}
				for _, b in ipairs(r.breeds) do breeds[#breeds + 1] = b end
				if r.sub then stats[#stats + 1] = r.sub.stat end
				local sub_name = r.sub and r.sub.name
				for _, p in ipairs(m.partners) do
					for _, o in ipairs(grp.rows) do
						if o.loc == p then
							for _, b in ipairs(o.breeds) do breeds[#breeds + 1] = b end
							if o.sub then
								stats[#stats + 1] = o.sub.stat
								sub_name = sub_name or o.sub.name
							end
							break
						end
					end
				end
				local sub
				if #stats == 1 then
					sub = { name = sub_name, stat = stats[1] }
				elseif #stats > 1 then
					sub = { name = sub_name, stat = stats }
				end
				g.rows[#g.rows + 1] = {
					name = m.name, breeds = breeds, sub = sub,
				}
			elseif not absorbed[r.loc] then
				g.rows[#g.rows + 1] = r
			end
		end
		out[#out + 1] = g
	end
	_merged_groups = out
	return out
end

function mod._breed_groups()
	if mod:get("wkc_merge_factions") then return merged_groups() end
	return mod._BREED_GROUPS
end

function mod._group_rows(s, grp, fmt, depth)
	depth = depth or 2
	local kills_for = s.breeds or {}
	local children, sum = {}, 0

	for _, r in ipairs(grp.rows) do
		if r.stat then
			local n = s[r.stat] or 0
			if n > 0 then
				children[#children + 1] = { label = r.name, value = fmt(n), depth = depth }
			end
		else
			local total = 0
			for _, breed_name in ipairs(r.breeds) do
				local bd = kills_for[breed_name]
				if bd then total = total + (bd.kills or 0) end
			end
			if total > 0 then
				sum = sum + total
				children[#children + 1] =
					{ label = mod._breed_row_name(r), value = fmt(total), depth = depth }
				if r.sub then
					local n = 0
					if type(r.sub.stat) == "table" then
						for i = 1, #r.sub.stat do n = n + (s[r.sub.stat[i]] or 0) end
					else
						n = s[r.sub.stat] or 0
					end
					if n > 0 then
						children[#children + 1] =
							{ label = r.sub.name, value = fmt(n), depth = depth + 1 }
					end
				end
			end
		end
	end

	if sum <= 0 then return nil, 0 end

	return children, sum
end

do
	local sets = { elites = {}, specialists = {} }
	for _, grp in ipairs(mod._BREED_GROUPS) do
		local set = sets[grp.id]
		if set then
			for _, r in ipairs(grp.rows) do
				if r.breeds then
					for _, breed_name in ipairs(r.breeds) do set[breed_name] = true end
				end
			end
		end
	end
	mod._ELITE_BREEDS   = sets.elites
	mod._SPECIAL_BREEDS = sets.specialists
end

function mod._tree_collapsed(row, state)
	local st = state[row.id]
	if st == nil then return row.default_collapsed and true or false end
	return st and true or false
end

function mod._tree_flatten(rows, state)
	local out, hide = {}, nil
	for i = 1, #rows do
		local row = rows[i]
		local depth = row.depth or 0
		if not (hide and depth > hide) then
			hide = nil
			out[#out + 1] = row
			if row.id and mod._tree_collapsed(row, state) then hide = depth end
		end
	end
	return out
end

function mod._tree_toggle(rows, state, id)
	for i = 1, #rows do
		local row = rows[i]
		if row.id == id then
			state[id] = not mod._tree_collapsed(row, state)
			return true
		end
	end
	return false
end

function mod._tree_toggle_all(rows, state)
	local any_open = false
	for i = 1, #rows do
		local row = rows[i]
		if row.id and not mod._tree_collapsed(row, state) then
			any_open = true
			break
		end
	end
	for i = 1, #rows do
		local row = rows[i]
		if row.id then state[row.id] = any_open end
	end
	return not any_open
end

function mod._tree_indent_labels(rows)
	local out = {}
	for i = 1, #rows do
		local row = rows[i]
		if row.spacer or row.section then
			out[#out + 1] = row
		else
			out[#out + 1] = {
				label = string.rep("    ", row.depth or 0) .. (row.label or ""),
				value = row.value,
			}
		end
	end
	return out
end
