-- debug.lua
--
-- Chat commands. Rewritten for v0.3.0.
--
-- THE RULE, learned the hard way: every command writes its full output to a FILE.
-- Chat is intentionally not a diagnostic channel. Pilgrimage.lua mutes the mod
-- object's DMF chat methods, while on-screen confirmation goes through
-- Shared.notify and diagnostic detail goes to files.
--
-- Every report lands in mods/Pilgrimage/ with a predictable name, so it can be read
-- without the player having to copy anything out of the game.

local M = {}

local _mod
local _shared
local _perf
local _event_log
local _run_state
local _settings
local _tick
local _probe
local _weapons
local _weapon_rebalance
local _fileio
local _missions
local _launcher
local _escape
local _chain
local _hitprobe
local _terminal
local _boons
local _icons
local _curses
local _mutator_guard
local _fx_guard
local _difficulty
local _wallet
local _scaling_hook
local _war_plans
local _penances
local _shop
local _bots
local _preset
local _passives
local _voices

-- Write a report and confirm on screen. Returns the path so callers can mention it.
local function report(name, lines)
	lines[#lines + 1] = ""
	lines[#lines + 1] = "written " .. _fileio.timestamp()

	local ok, path_or_err = _fileio.write(name, lines)

	if ok then
		_shared.notify("Pilgrimage: wrote mods/Pilgrimage/" .. name)
	else
		_shared.notify("Pilgrimage: FAILED to write " .. name .. " (" ..
			tostring(path_or_err) .. ")", "alert")
	end

	-- Harmless if DMF logging is off, useful if it is ever turned back on.
	_mod:echo("Pilgrimage: " .. name .. (ok and " written" or " FAILED"))

	return ok, path_or_err
end

M.report = report

-- ---------------------------------------------------------------------------

local function status_lines()
	local lines = {}
	local function add(text) lines[#lines + 1] = text end

	add("Pilgrimage status")
	add("mod version:  " .. tostring(_mod.version))
	add("wall clock:   " .. _fileio.timestamp())
	add("")

	add("[session]")
	add("  game mode:  " .. tostring(_shared.game_mode_name()))
	add("  in hub:     " .. tostring(_shared.is_in_hub()))
	add("  psykhanium: " .. tostring(_shared.is_in_psykhanium()))
	add("  solo host:  " .. tostring(_shared.is_solo_host()))
	add("  is server:  " .. tostring(_shared.is_server()))
	add("  fixed time: " .. string.format("%.2f", _shared.fixed_time()))
	add("  player unit:" .. tostring(_shared.local_player_unit() ~= nil))
	add("")

	add("[run]")
	add("  " .. _run_state.summary())
	local state = _run_state.get()
	add("  active:     " .. tostring(state.active))
	add("  index:      " .. tostring(state.index) .. " of " .. tostring(#state.queue))
	add("  seed:       " .. tostring(state.seed))
	add("  legs done:  " .. (#state.legs_done > 0
		and table.concat(state.legs_done, ", ") or "none"))
	add("")

	-- Whether the run is actually reaching disk under our own control. "resolver" is the
	-- important line: anything other than get_mod means we could not find DMF's save
	-- entry point.
	--
	-- Note what that does and does not cost, because I got this wrong once. DMF saves on
	-- its own on every game state change AND on unload, so even with our flush dead a
	-- clean quit still writes the run correctly. What is lost is only the case where
	-- neither of those fires: a crash, an alt-F4, a power cut. That is the whole
	-- exposure, and it is worth covering, but it is not "the run does not save".
	add("[run persistence]")
	local flush = _run_state.flush_status()
	for _, key in ipairs({ "resolver", "attempts", "verified", "unverified",
	                       "errors", "pending", "last_error" }) do
		add("  " .. key .. ": " .. tostring(flush[key]))
	end
	add("")

	-- Everything about whether the terminal is findable and reachable. "found_by" is the
	-- line that matters: id_string means we matched the authored prop, fallback_position
	-- means the scan failed and we are using hardcoded coordinates, which still works but
	-- means a game update moved or renamed it.
	add("[terminal]")
	local terminal = _terminal.status()
	for _, key in ipairs({ "enabled", "in_hub", "found_by", "has_unit", "has_position",
	                       "anchor_from", "anchor_x", "anchor_y", "anchor_z",
	                       "marker_id", "marker_pending", "marker_requests", "marker_timeouts",
	                       "scans", "markers_added",
	                       "markers_removed", "opens", "prompt_visible", "distance",
	                       "facing_dot", "range", "input_claimed", "last_error" }) do
		local value = terminal[key]
		if type(value) == "number" and value ~= math.floor(value) then
			value = string.format("%.2f", value)
		end
		add("  " .. key .. ": " .. tostring(value))
	end
	add("")

	add("[boons]")
	local boons = _boons.status()
	for _, key in ipairs({ "pool_size", "data_table", "parser", "applied_now",
	                       "applied_total", "failed", "spawns", "last_error" }) do
		add("  " .. key .. ": " .. tostring(boons[key]))
	end
	add("  owned: " .. (#boons.owned > 0 and table.concat(boons.owned, ", ") or "none"))
	add("")

	add("[boon icons]")
	local icon_status = _icons.status()
	add("  attempted: " .. tostring(icon_status.attempted))
	local entries = icon_status.entries or {}
	if entries.error then add("  error: " .. tostring(entries.error)) end
	for i = 1, #entries do
		local e = entries[i]
		add(string.format("  %-12s %s", tostring(e.result), tostring(e.name)))
		if e.error then add("               " .. tostring(e.error)) end
	end
	if #entries == 0 and not entries.error then add("  not run yet") end
	add("")

	add("[file io]")
	add("  available:  " .. tostring(_fileio.available()))
	add("  mod dir:    " .. _fileio.MOD_DIR)
	add("")

	add("[event log]")
	local stats = _event_log.stats()
	for _, key in ipairs({ "available", "enabled", "file", "buffered",
	                       "sequence", "write_failures" }) do
		add("  " .. key .. ": " .. tostring(stats[key]))
	end
	add("")

	add("[perf]")
	add("  enabled:    " .. tostring(_perf.is_enabled()))
	add("")

	add("[settings as read]")
	add("  log_level:            " .. tostring(_settings.log_level_raw()) ..
		" (level " .. tostring(_settings.log_level()) .. ")")
	add("  event log enabled:    " .. tostring(_settings.event_log_enabled()))
	add("  perf enabled:         " .. tostring(_settings.perf_enabled()))
	add("  run length:           " .. tostring(_settings.run_length()))
	add("  boons per leg:        " .. tostring(_settings.boons_per_leg()))
	add("  terminal prompt dist: " .. tostring(_settings.terminal_prompt_distance()))
	add("")

	add("[tick tasks]")
	local tasks = _tick.tasks()
	if #tasks == 0 then
		add("  none registered")
	end
	for i = 1, #tasks do
		local task = tasks[i]
		add(string.format("  %-24s every %.2fs  runs %d  errors %d%s",
			task.name, task.interval, task.runs, task.errors,
			task.last_error and ("  last: " .. task.last_error) or ""))
	end
	add("")

	add("[chain]")
	local chain_status = _chain.status()
	for _, key in ipairs({ "auto_chain", "pending", "pending_result", "in_hub" }) do
		add("  " .. key .. ": " .. tostring(chain_status[key]))
	end
	add("")

	add("[hit probe]")
	add("  installed: " .. tostring(_hitprobe.is_installed()))
	add("  recording: " .. tostring(_hitprobe.is_enabled()))
	add("  rows:      " .. tostring(_hitprobe.row_count()))
	add("")

	add("[escape menu]")
	add("  leave-mission entries patched: " .. tostring(_escape.patched_count()))
	add("")

	add("[weapon patches]")
	add("  templates loaded: " .. tostring(_weapons.templates() ~= nil))
	add("  can patch here:   " .. tostring(_weapons.can_apply()))
	local patch_count = 0
	for id in pairs(_weapons.patches()) do
		patch_count = patch_count + 1
		add("  " .. id .. (_weapons.is_applied(id) and " [applied]" or " [inactive]"))
	end
	if patch_count == 0 then add("  no patches defined yet") end
	add("")

	add("[custom weapon rebalance]")
	local rebalance = _weapon_rebalance.status()
	add("  enabled:          " ..
		tostring(_settings.custom_weapon_balancing_enabled()))
	add("  Meat Grinder:     " ..
		tostring(_settings.custom_weapon_balancing_meat_grinder_enabled()))
	for _, key in ipairs({ "applied", "pending", "scope", "prepared_transition",
		"last_apply_error", "skipped_optional" }) do
		add("  " .. key .. ": " .. tostring(rebalance[key]))
	end
	add("")

	add("[environment survey]")
	local Mods = rawget(_G, "Mods")
	add("  Mods.lua.io:   " .. tostring(Mods and Mods.lua and Mods.lua.io ~= nil))
	add("  Mods.lua.os:   " .. tostring(Mods and Mods.lua and Mods.lua.os ~= nil))
	add("  cjson:         " .. tostring(rawget(_G, "cjson") ~= nil))
	for _, name in ipairs({ "Unit", "World", "Level", "Vector3", "Quaternion",
	                        "ScriptUnit", "Camera", "Managers", "Localize",
	                        "PhysicsWorld", "LineObject", "Color" }) do
		add("  " .. string.format("%-14s %s", name .. ":", tostring(rawget(_G, name) ~= nil)))
	end

	-- DMF's logging settings, the reason nothing has ever printed to chat.
	local dmf = rawget(_G, "get_mod") and get_mod("DMF")
	if type(dmf) == "table" and type(dmf.get) == "function" then
		add("")
		add("[DMF logging settings]  0 = disabled, 4 = log+chat, 7 = everything")
		add("  logging_mode: " .. tostring(dmf:get("logging_mode")))
		for _, key in ipairs({ "output_mode_echo", "output_mode_info",
		                       "output_mode_warning", "output_mode_error",
		                       "output_mode_notification", "output_mode_debug" }) do
			add("  " .. key .. ": " .. tostring(dmf:get(key)))
		end
	end

	return lines
end

M.status_lines = status_lines

-- ---------------------------------------------------------------------------

function M.register_commands()
	-- Everything about the mod's current state, in one file.
	_mod:command("pil_status", "Pilgrimage: write a full status report to file", function()
		report("status.txt", status_lines())
	end)

	-- The terminal, end to end: what the scan found, where it thinks you are standing,
	-- and whether the prompt would be showing right now. Run it standing at the prop and
	-- again from across the room, and the difference in distance and facing_dot tells us
	-- whether the gating is behaving.
	_mod:command("pil_terminal", "Pilgrimage: open the terminal anywhere in the Mourningstar or Meat Grinder", function()
		local ok, err = _terminal.request_open()
		if not ok then _shared.notify("Pilgrimage: " .. tostring(err), "alert") end
	end)

	_mod:command("pil_terminal_status", "Pilgrimage: report on the terminal prop and prompt", function()
		local lines = { "Pilgrimage terminal report", "" }
		local function add(text) lines[#lines + 1] = text end

		local status = _terminal.status()
		for _, key in ipairs({ "enabled", "in_hub", "found_by", "has_unit", "has_position",
		                       "anchor_from", "anchor_x", "anchor_y", "anchor_z",
		                       "marker_id", "marker_pending", "marker_requests", "marker_timeouts",
	                       "scans", "markers_added",
		                       "markers_removed", "opens", "prompt_visible", "distance",
		                       "facing_dot", "range", "input_claimed", "last_error" }) do
			add(string.format("  %-16s %s", key .. ":", tostring(status[key])))
		end

		add("")
		add("expected id_string: " .. _terminal.TERMINAL_ID_STRING)
		add("fallback position:  " .. table.concat({
			tostring(_terminal.FALLBACK_POSITION[1]),
			tostring(_terminal.FALLBACK_POSITION[2]),
			tostring(_terminal.FALLBACK_POSITION[3]),
		}, ", "))

		report("terminal.txt", lines)

		-- Also on screen, because the whole point of this one is to be run while walking
		-- around, and alt-tabbing to read a file defeats that.
		_shared.notify(string.format("Terminal: %s, dist %s, prompt %s",
			tostring(status.found_by),
			status.distance and string.format("%.1fm", status.distance) or "?",
			tostring(status.prompt_visible)))
	end)

	-- Aim at the terminal, run this, done. Ends the guessing about where the prompt sits:
	-- the anchor becomes the exact point the ray strikes, stored as an offset from the
	-- prop so it still follows the prop if a patch moves it.
	_mod:command("pil_terminal_set", "Pilgrimage: put the prompt where you are aiming", function(distance)
		local ok, result = _terminal.set_anchor_from_aim(tonumber(distance) or 8)

		if not ok then
			_shared.notify("Pilgrimage: " .. tostring(result), "alert")
			return
		end

		_shared.notify(string.format("Terminal anchor set, %.2fm away", result.distance or 0))
		report("terminal.txt", {
			"Pilgrimage terminal anchor set by aim",
			"",
			string.format("  offset from prop origin: %.4f, %.4f, %.4f",
				result.dx, result.dy, result.dz),
			string.format("  ray distance:            %.3f", result.distance or 0),
			"",
			"Stored in settings, so it survives a restart. /pil_terminal_reset undoes it.",
		})
	end)

	_mod:command("pil_terminal_reset", "Pilgrimage: forget the hand-placed prompt position", function()
		_terminal.clear_anchor_offset()
		_shared.notify("Pilgrimage: terminal anchor reset to the automatic guess")
	end)

	-- Opens the route view without walking to the prop. Purely so the UI can be iterated
	-- on without a round trip to the alcove every time.
	_mod:command("pil_route", "Pilgrimage: open the route view from here", function()
		local ok, err = _terminal.open()
		if ok then
			_shared.notify("Pilgrimage: opening the route view")
		else
			_shared.notify("Pilgrimage: could not open route view, " .. tostring(err), "alert")
		end
	end)

	-- The boon catalogue and what the current run owns. Also dumps a sample draft, which
	-- is the quickest way to see whether titles and descriptions are resolving before
	-- walking to the terminal.
	_mod:command("pil_boons", "Pilgrimage: report on the boon pool and the run's boons", function()
		local lines = { "Pilgrimage boons", "" }
		local function add(text) lines[#lines + 1] = text end

		local status = _boons.status()
		for _, key in ipairs({ "pool_size", "data_table", "parser", "applied_now",
		                       "applied_total", "failed", "spawns", "last_error" }) do
			add(string.format("  %-14s %s", key .. ":", tostring(status[key])))
		end
		add("  owned: " .. (#status.owned > 0 and table.concat(status.owned, ", ") or "none"))
		add("")

		add("sample draft at seed 1, leg 1:")
		local sample = _boons.draft(3, _boons.draft_seed(1, 1), {})
		for i = 1, #sample do
			local info = _boons.info(sample[i])
			add(string.format("  [%d] %s", i, info.title))
			add("      " .. tostring(info.name))
			add("      " .. (info.description ~= "" and info.description or "(no description resolved)"))
			add("      icon: " .. tostring(info.icon))
		end
		if #sample == 0 then add("  pool is empty, catalogue did not load") end
		add("")

		add("first 40 of the pool:")
		local pool = _boons.pool()
		for i = 1, math.min(40, #pool) do add("  " .. pool[i]) end

		report("boons.txt", lines)
	end)

	-- v0.28.22: mission-local boon laboratory. These commands apply buffs to
	-- the current player unit without altering run_state, unlocks or loadout
	-- slots. IDs are the reliable form, but a unique title fragment also works.
	_mod:command("pil_boon_list", "Pilgrimage: list boon IDs for mid-mission testing", function(...)
		local filter = table.concat({ ... }, " ")
		local entries = _boons.test_catalogue(filter)
		local lines = {
			"Pilgrimage boon test catalogue",
			"filter: " .. (filter ~= "" and filter or "<none>"),
			"matches: " .. tostring(#entries),
			"",
			"Use /pil_boon_grant <id>, /pil_boon_remove <id>, or /pil_boon_clear.",
			"Test grants last for this mission only and do not change progression.",
			"",
		}
		for i = 1, #entries do
			local entry = entries[i]
			lines[#lines + 1] = string.format("%-46s %s",
				tostring(entry.id), tostring(entry.title))
			if entry.template and entry.template ~= entry.id then
				lines[#lines + 1] = "    template: " .. tostring(entry.template)
			end
		end
		report("boon_test_catalogue.txt", lines)
	end)

	_mod:command("pil_boon_grant", "Pilgrimage: grant yourself a boon for this mission", function(...)
		local query = table.concat({ ... }, " ")
		if query == "" then
			_shared.notify("usage: /pil_boon_grant <id or title>. See /pil_boon_list.", "alert")
			return
		end
		local unit = _shared.local_player_unit()
		local ok, err, entry = _boons.test_grant(unit, query)
		if ok then
			_shared.notify("Test boon granted: " .. tostring(entry.title)
				.. " (" .. tostring(entry.id) .. ")")
		else
			_shared.notify("Boon grant failed: " .. tostring(err), "alert")
		end
	end)

	_mod:command("pil_boon_remove", "Pilgrimage: remove one mission-only test boon", function(...)
		local query = table.concat({ ... }, " ")
		if query == "" then
			_shared.notify("usage: /pil_boon_remove <id or title>", "alert")
			return
		end
		local ok, err, entry = _boons.test_remove(_shared.local_player_unit(), query)
		if ok then
			_shared.notify("Test boon removed: " .. tostring(entry.title))
		else
			_shared.notify("Boon removal failed: " .. tostring(err), "alert")
		end
	end)

	_mod:command("pil_boon_clear", "Pilgrimage: remove every mission-only test boon", function()
		local ok, removed, failures = _boons.test_clear(_shared.local_player_unit())
		if ok then
			_shared.notify("Cleared " .. tostring(removed) .. " test boon(s).")
		else
			_shared.notify("Cleared with " .. tostring(#failures) .. " removal failure(s).", "alert")
		end
	end)

	_mod:command("pil_ff", "Pilgrimage: show the effective friendly-fire policy", function()
		local getter = _mod._friendly_fire_status
		local status = type(getter) == "function" and getter() or nil
		if not status then
			_shared.notify("Friendly-fire status is unavailable.", "alert")
			return
		end
		local summary = string.format(
			"FF mode: %s | Hazard purchase: %s | traitor: %s",
			tostring(status.mode), tostring(status.hazard_purchased), tostring(status.traitor))
		_shared.notify(summary)
		report("friendly_fire.txt", {
			"Pilgrimage friendly-fire status",
			"",
			"effective mode:    " .. tostring(status.mode),
			"Hazard latched:    " .. tostring(status.hazard),
			"Hazard purchased:  " .. tostring(status.hazard_purchased),
			"Discord present:   " .. tostring(status.discord),
			"Serpent present:   " .. tostring(status.serpent),
			"Serpent traitor:   " .. tostring(status.traitor),
			"mission latch set: " .. tostring(status.was_in_mission),
		})
	end)

	-- v0.26.5: writes the exact runtime classification after Fatshark's
	-- packed catalogue and localization tables have loaded. This makes
	-- patch or DLC drift visible without putting diagnostic noise in chat.
	_mod:command("pil_legendary_audit", "Pilgrimage: classify every shipped Legendary", function()
		local lines = { "Pilgrimage Legendary role audit", "" }
		local counts = { loadout = 0, rare = 0, family = 0, unknown = 0 }
		local all = _boons.all_legendary_names()
		_boons.pool()
		for i = 1, #all do
			local id = all[i]
			local family = _boons.family_of(id)
			local role
			if family then
				role = "family:" .. tostring(family)
				counts.family = counts.family + 1
			elseif _boons.is_loadout_legendary(id) then
				role = "loadout"
				counts.loadout = counts.loadout + 1
			elseif _boons.is_rare_legendary(id) then
				role = "rare-draft"
				counts.rare = counts.rare + 1
			else
				role = "unknown"
				counts.unknown = counts.unknown + 1
			end
			local info = _boons.info(id)
			lines[#lines + 1] = string.format("[%s] %s", role, tostring(info.title))
			lines[#lines + 1] = "  " .. tostring(id)
			lines[#lines + 1] = "  " .. tostring(info.description or "")
		end
		table.insert(lines, 2, string.format(
			"loadout=%d rare-draft=%d family=%d unknown=%d total=%d",
			counts.loadout, counts.rare, counts.family, counts.unknown, #all))
		report("legendary_audit.txt", lines)
	end)

	-- Answers "why is my boon icon a question mark". Reports which packages we asked
	-- for, and then probes the actual icon texture of every boon in the pool, which is
	-- the only test that matters: a resident texture draws, a non-resident one becomes
	-- the placeholder hexagon with no error anywhere.
	_mod:command("pil_icons", "Pilgrimage: report on boon icon textures and packages", function(arg)
		local lines = { "Pilgrimage boon icons", "" }
		local function add(text) lines[#lines + 1] = text end

		if arg == "reload" then
			local released = _icons.release()
			add("released " .. tostring(released) .. " package reference(s), reloading")
			add("")
		end

		local state = _icons.ensure(arg == "reload")

		add("packages:")
		if state.error then add("  error: " .. tostring(state.error)) end
		for i = 1, #state do
			local e = state[i]
			add(string.format("  %-14s exists=%-5s %s",
				tostring(e.result), tostring(e.exists), tostring(e.name)))
			if e.error then add("                  " .. tostring(e.error)) end
		end
		add("")

		-- Resident means the engine can hand the texture over right now. Anything that
		-- is not resident will render as the placeholder.
		local pool = _boons.pool()
		local resident, missing, unknown, no_icon = 0, 0, 0, 0
		local missing_names = {}

		for i = 1, #pool do
			local info = _boons.info(pool[i])
			if not info.icon then
				no_icon = no_icon + 1
			else
				local is_resident = _icons.texture_resident(info.icon)
				if is_resident == true then
					resident = resident + 1
				elseif is_resident == false then
					missing = missing + 1
					if #missing_names < 12 then
						missing_names[#missing_names + 1] = info.icon
					end
				else
					unknown = unknown + 1
				end
			end
		end

		add("icon textures across the current pool of " .. tostring(#pool) .. ":")
		add("  resident:  " .. tostring(resident))
		add("  missing:   " .. tostring(missing))
		add("  unknown:   " .. tostring(unknown) .. "  (no probe available)")
		add("  no icon:   " .. tostring(no_icon))
		add("")

		if #missing_names > 0 then
			add("first missing textures:")
			for i = 1, #missing_names do add("  " .. missing_names[i]) end
			add("")
		end

		-- Control textures first. If these read as missing, the probe is not answering
		-- the question we think it is and everything below is noise.
		add("control textures (these are on screen, so they ARE loaded):")
		for i = 1, #_icons.CONTROL_TEXTURES do
			local path = _icons.CONTROL_TEXTURES[i]
			local probe = _icons.probe_resource(path)
			local parts = {}
			for k = 1, #_icons.RESOURCE_KINDS do
				local kind = _icons.RESOURCE_KINDS[k]
				parts[#parts + 1] = kind .. "=" .. tostring(probe[kind])
			end
			add("  " .. path)
			add("    " .. table.concat(parts, "  "))
			if probe.error then add("    error: " .. tostring(probe.error)) end
		end
		add("")

		-- Now the buffs the run actually holds, end to end: is there a data entry, what
		-- icon does it name, and can the engine reach it. One of those three is the
		-- failure and this says which.
		local run = _run_state.get()
		local owned = {}
		for name in pairs(run.boons or {}) do owned[#owned + 1] = name end
		table.sort(owned)

		if #owned == 0 then
			add("no boons held right now, showing a sample draft instead:")
			owned = _boons.draft(3, _boons.draft_seed(run.seed ~= 0 and run.seed or 1,
				run.index > 0 and run.index or 1), {})
		else
			add("boons currently held:")
		end

		for i = 1, #owned do
			local info = _boons.info(owned[i])
			add("  " .. tostring(owned[i]))
			add("    data entry:  " .. (info.title ~= owned[i] and "yes" or "NO or unlocalized"))
			add("    title:       " .. tostring(info.title))
			add("    icon:        " .. tostring(info.icon))
			add("    gradient:    " .. tostring(info.gradient))

			if info.icon then
				local probe = _icons.probe_resource(info.icon)
				local parts = {}
				for k = 1, #_icons.RESOURCE_KINDS do
					local kind = _icons.RESOURCE_KINDS[k]
					parts[#parts + 1] = kind .. "=" .. tostring(probe[kind])
				end
				add("    reachable:   " .. table.concat(parts, "  "))
			end
		end
		add("")

		local custom = _icons.custom_status()
		add(string.format("custom icon set (SimpleAssets): %s, %d of %d loaded",
			tostring(custom.status), custom.loaded, custom.total))
		-- How many of the game's own buff templates now carry a replacement icon.
		-- 84 is the full hordes pool; 0 with the set loaded means patch_templates
		-- has not run or the residency probe went missing.
		add(string.format("buff templates patched with replacement icons: %d",
			custom.patched or 0))
		-- The per-category stand-ins resolved from the game's own resident art.
		-- This is what actually draws; SimpleAssets is only the fallback when a
		-- category resolves to nothing. "none" rows are the ones to improve.
		add(string.format("categories resolved to resident game textures: %d of %d",
			custom.resolved or 0, custom.total))
		if _icons.CATEGORIES and _icons.resolve_category_texture then
			for i = 1, #_icons.CATEGORIES do
				local category = _icons.CATEGORIES[i]
				local texture = _icons.resolve_category_texture(category)
				add(string.format("  %-10s %s", category, texture or "none"))
			end
		end
		add("")

		add("run /pil_icons reload to drop and retake the package references")

		report("icons.txt", lines)
	end)

	-- The curse pool as this build sees it, and the gauntlet the current run carries.
	_mod:command("pil_curses", "Pilgrimage: report the curse pool and this run's curses", function()
		local lines = { "Pilgrimage curses", "" }
		local function add(text) lines[#lines + 1] = text end

		local status = _curses.status()
		add("templates loaded: " .. tostring(status.templates_loaded))
		add(string.format("pool by severity: %d / %d / %d  (catalogue %d, havoc pool %s)",
			status.pool_1, status.pool_2, status.pool_3,
			status.catalogue, tostring(status.havoc_allowed)))
		add("")

		add("catalogue on this build:")
		for i = 1, #_curses.CATALOGUE do
			local entry = _curses.CATALOGUE[i]
			local exists = _curses.exists(entry.name)
			add(string.format("  sev %d  %-12s %-45s %s",
				entry.severity,
				exists == true and "present" or exists == false and "MISSING" or "unknown",
				entry.name,
				_curses.display_name(entry.name)))
		end
		add("")

		local run = _run_state.get()
		if run.active then
			add("current run:")
			for i = 1, #run.queue do
				local curse = run.curse_queue[i] or "default"
				local marker = i == run.index and " <- current" or ""
				add(string.format("  leg %d  %-35s %s%s",
					i, _missions.display_name(run.queue[i]),
					curse == "default" and "(no curse)" or _curses.display_name(curse),
					marker))
			end
		else
			add("no active run. A sample assignment at seed 5, six legs:")
			local sample = _curses.assign(6, 5)
			for i = 1, #sample do
				add(string.format("  leg %d  sev %d  %s", i,
					_curses.severity_of(sample[i]), _curses.display_name(sample[i])))
			end
		end

		report("curses.txt", lines)
	end)

	-- The difficulty ramp for the current run. Shows what danger each leg
	-- will launch at and what enemy scaling (HP + attack speed buffs) piles
	-- on above Damnation. Reads from run state so it is honest about what
	-- WILL launch, not what the mod option would produce for a fresh run.
	_mod:command("pil_difficulty", "Pilgrimage: report the current run's difficulty ramp", function()
		local lines = { "Pilgrimage difficulty ramp", "" }
		local function add(text) lines[#lines + 1] = text end

		local state = _run_state.get()
		local starting = state.starting_difficulty
		if not starting or starting == 0 then
			starting = _difficulty.starting_difficulty()
			add("no active run; showing the ramp for a fresh run at option-default")
		else
			add(string.format("active run started at %s (%d)",
				_difficulty.NAME_BY_DANGER[starting] or "?", starting))
		end
		add("mod option: " .. tostring(_mod:get("starting_difficulty")))
		add("")

		local total = math.max(state.active and #state.queue or 0, 8)
		add(string.format("%-4s %-12s %-11s %-6s %s", "leg", "danger", "scale_tier",
			"hp%", "attack speed"))
		for i = 1, total do
			local diff = _difficulty.for_leg(i, starting)
			local melee, ranged = _difficulty.spawn_buffs_for(diff.scale_tier)
			local health = _difficulty.minion_health_modifier_for(diff.scale_tier)
			local hp_pct = health and health[5] or 0
			add(string.format("%-4d %-12s %-11d +%-5d %s / %s",
				i, diff.danger_name, diff.scale_tier,
				math.floor(hp_pct * 100),
				tostring(melee or "-"),
				tostring(ranged or "-")))
		end

		add("")
		if _scaling_hook then
			local s = _scaling_hook.stats()
			add(string.format("scaling hook: registered=%s, last_scale=%d, melee_buffed=%d, ranged_buffed=%d",
				tostring(s.registered), s.last_scale, s.melee_buffed, s.ranged_buffed))
		end
		report("difficulty.txt", lines)
	end)

	-- The wallet: current balance, recent history, per-source totals.
	_mod:command("pil_wallet", "Pilgrimage: report the Ordos balance and history", function()
		local lines = { "Pilgrimage wallet", "" }
		local function add(text) lines[#lines + 1] = text end

		add("balance: " .. tostring(_wallet.balance()) .. " Ordos")
		add("")

		local summary = _wallet.summary()
		add("earnings by source (this session's known history):")
		local sources = {}
		for name in pairs(summary.by_source) do sources[#sources + 1] = name end
		table.sort(sources)
		for i = 1, #sources do
			add(string.format("  %-24s %d", sources[i], summary.by_source[sources[i]]))
		end
		add("")

		local hist = _wallet.history()
		add(string.format("history (%d entries, newest first):", #hist))
		for i = #hist, math.max(1, #hist - 30), -1 do
			local e = hist[i]
			add(string.format("  +%-6d %-32s t=%d", e.amount, e.source, e.t))
		end

		report("wallet.txt", lines)
	end)

	-- List all War Plans, showing which are unlocked and which is selected.
	_mod:command("pil_plans", "Pilgrimage: list all War Plans and their unlock status", function()
		local lines = { "Pilgrimage War Plans", "" }
		local function add(text) lines[#lines + 1] = text end

		local plans = _war_plans.all()
		local selected = _war_plans.selected_id()
		for i = 1, #plans do
			local p = plans[i]
			local unlocked = _war_plans.is_unlocked(p.id)
			local reason = _war_plans.locked_reason(p.id)
			local flag = (p.id == selected) and "* " or "  "
			add(string.format("%s%-12s  %s  [%d legs, start %s]",
				flag, p.id,
				unlocked and "UNLOCKED" or "locked  ",
				p.leg_count, p.starting_difficulty_name))
			add("     " .. p.name)
			add("     " .. p.description)
			if not unlocked then add("     " .. tostring(reason)) end
			add("")
		end
		add("Change with /pil_plan <id>")
		report("plans.txt", lines)
	end)

	-- Switch the selected plan. Errors on unknown or locked.
	_mod:command("pil_plan", "Pilgrimage: select a War Plan by id (see /pil_plans)", function(id)
		if type(id) ~= "string" or id == "" then
			_shared.notify("usage: /pil_plan <plan_id>. Try /pil_plans first.", "alert")
			return
		end
		local ok, err = _war_plans.select(id)
		if ok then
			local plan = _war_plans.get(id)
			_shared.notify("War Plan selected: " .. plan.name)
		else
			_shared.notify("Cannot select: " .. tostring(err), "alert")
		end
	end)

	-- Full penance list with earned status.
	_mod:command("pil_penances", "Pilgrimage: list all penances and their earned status", function()
		local lines = { "Pilgrimage penances", "" }
		local function add(text) lines[#lines + 1] = text end

		local pens = _penances.all()
		local earned_set = {}
		for _, id in ipairs(_penances.earned_ids()) do earned_set[id] = true end

		local earned_count = 0
		for i = 1, #pens do if earned_set[pens[i].id] then earned_count = earned_count + 1 end end
		add(string.format("earned: %d of %d", earned_count, #pens))
		add("")

		for i = 1, #pens do
			local p = pens[i]
			local flag = earned_set[p.id] and "EARNED" or "  ..  "
			add(string.format("[%s]  %s  (%s)", flag, p.name, p.id))
			add("        " .. p.description)
			add("        Trigger: " .. tostring(p.trigger or "parent cascade"))
			if p.unlocks_label then
				add("        Reward: " .. tostring(p.unlocks_label))
			elseif p.unlocks then
				add("        Reward id: " .. tostring(p.unlocks))
			end
			add("")
		end
		report("penances.txt", lines)
	end)

	-- v0.28.50: catalogue-to-consumer audit. A Penance definition may say
	-- that it unlocks something while the preset or War Plan catalogue never
	-- actually names that Penance as its gate. This report makes those silent
	-- progression gaps visible without granting, revoking or changing progress.
	_mod:command("pil_penance_audit", "Pilgrimage: audit Penance reward wiring and counters", function()
		local lines = { "Pilgrimage Penance wiring audit", "" }
		local function add(text) lines[#lines + 1] = text end
		local pens = _penances.all()
		local by_id = {}
		for i = 1, #pens do by_id[pens[i].id] = pens[i] end

		local plan_by_id = {}
		local plan_gate_count = 0
		for _, plan in ipairs(_war_plans.all()) do
			plan_by_id[plan.id] = plan
			if plan.unlock_penance then plan_gate_count = plan_gate_count + 1 end
		end

		local preset_by_id = {}
		local preset_gate_count = 0
		for _, preset in ipairs(_preset.all()) do
			preset_by_id[preset.id] = preset
			if preset.unlock_penance then preset_gate_count = preset_gate_count + 1 end
		end

		add(string.format("catalogue: %d Penances", #pens))
		add(string.format("active gates: %d War Plans, %d presets", plan_gate_count, preset_gate_count))
		add("")
		add("DECLARED UNLOCKS")
		for i = 1, #pens do
			local penance = pens[i]
			if penance.unlocks then
				local target = plan_by_id[penance.unlocks]
				local kind = "War Plan"
				if not target then
					target = preset_by_id[penance.unlocks]
					kind = "preset"
				end
				local state
				if not target then
					state = "target absent or future"
				elseif target.unlock_penance == penance.id then
					state = "WIRED"
				elseif target.unlock_penance == nil then
					state = "NOT ENFORCED, target is always unlocked"
				else
					state = "MISMATCH, target uses " .. tostring(target.unlock_penance)
				end
				add(string.format("  %-36s -> %-10s %-28s %s",
					penance.id, kind, penance.unlocks, state))
			end
		end

		add("")
		add("ACTIVE GATES")
		for _, plan in ipairs(_war_plans.all()) do
			if plan.unlock_penance then
				add(string.format("  War Plan %-18s <- %-36s %s", plan.id,
					plan.unlock_penance, by_id[plan.unlock_penance] and "OK" or "UNKNOWN PENANCE"))
			end
		end
		for _, preset in ipairs(_preset.all()) do
			if preset.unlock_penance then
				add(string.format("  Preset   %-18s <- %-36s %s", preset.id,
					preset.unlock_penance, by_id[preset.unlock_penance] and "OK" or "UNKNOWN PENANCE"))
			end
		end

		add("")
		add("KNOWN DIRECT CONSUMERS")
		local direct = {
			{ "pilgrim_flush", "wallet.lua, +5% permanent Ordos multiplier" },
			{ "pilgrim_coffers_bursting", "wallet.lua, +10% permanent Ordos multiplier" },
			{ "pilgrim_first_recruit", "bots.lua, second Warband slot" },
			{ "pilgrim_second_recruit", "bots.lua, third Warband slot" },
			{ "pilgrim_sanctioned", "bots.lua, fourth Warband slot" },
			{ "pilgrim_full_muster", "bots.lua, fifth Warband slot" },
			{ "pilgrim_emperors_six", "bots.lua, sixth Warband slot" },
			{ "pilgrim_zero_waste", "bootstrap.lua, +1 draft option" },
			{ "pilgrim_the_devoted", "mission counter wired; Curse Reveal remains future" },
			{ "pilgrim_orthus_vindicated", "wallet.lua multiplier; Saint plan remains future" },
		}
		for i = 1, #direct do
			add(string.format("  %-36s %s", direct[i][1], direct[i][2]))
		end

		add("")
		add("CURRENT RUN SNAPSHOT")
		local snap = _run_state.stat_snapshot and _run_state.stat_snapshot() or {}
		for _, key in ipairs({ "archetype", "ever_downed", "downs", "boons_taken",
			"hp_damage_taken", "ranged_hp_damage", "shop_purchases", "bots_slotted",
			"curses_stacked", "martyrdom_time_pct", "companion_kills",
			"electricity_damage_dealt", "total_damage_dealt" }) do
			add(string.format("  %-28s %s", key .. ":", tostring(snap[key])))
		end

		add("")
		add("PERSISTENT COUNTERS")
		for _, key in ipairs({ "total_runs_completed", "total_missions_completed", "total_interrogators_hacked",
			"total_voltaic_disables" }) do
			local value = _run_state.persist_get and _run_state.persist_get(key) or 0
			add(string.format("  %-28s %s", key .. ":", tostring(value)))
		end

		report("penance_audit.txt", lines)
	end)

	-- Manual grant for testing the unlock chain without playing the runs.
	_mod:command("pil_grant_penance", "Pilgrimage: grant a penance by id (for testing)", function(id)
		if type(id) ~= "string" or id == "" then
			_shared.notify("usage: /pil_grant_penance <penance_id>", "alert")
			return
		end
		local ok, err = _penances.grant(id, "manual")
		if not ok then _shared.notify("grant failed: " .. tostring(err), "alert") end
	end)

	_mod:command("pil_reset_penance", "Pilgrimage: revoke a penance by id (for testing)", function(id)
		if type(id) ~= "string" or id == "" then
			_shared.notify("usage: /pil_reset_penance <penance_id>", "alert")
			return
		end
		local ok, err = _penances.revoke(id)
		if ok then _shared.notify("revoked: " .. id) else _shared.notify(tostring(err), "alert") end
	end)

	-- v0.19.2: batch grants/resets. Walk the catalogue and try each.
	-- Idempotent by design: grant on an already-earned id and revoke on an
	-- unearned id both return false with a reason, which we tally rather
	-- than surfacing individually. Kaizen wants this to test the whole
	-- unlock chain without typing five commands.
	--
	-- Force a flush at the end so the change survives a hard kill. The
	-- individual grant/revoke calls only raise DMF's dirty flag; without
	-- the flush a crash after this command loses everything back to the
	-- last game-state change.
	_mod:command("pil_grant_all_penances", "Pilgrimage: grant every penance in the catalogue", function()
		local granted, skipped = 0, 0
		local pens = _penances.all()
		for i = 1, #pens do
			local ok = _penances.grant(pens[i].id, "batch_grant")
			if ok then granted = granted + 1 else skipped = skipped + 1 end
		end
		if _run_state and _run_state.flush then _run_state.flush(true) end
		_shared.notify(string.format(
			"Pilgrimage: granted %d penance(s), %d already earned", granted, skipped))
	end)

	-- v0.20.0: Emporium commands. These stand in for the Emporium tab UI
	-- (planned for v0.20.1), and stay after the UI ships as scriptable
	-- shortcuts.
	--
	--   /pil_shop            list every SKU with price, kind, and current
	--                        state (active / unlocked / locked / affordable).
	--   /pil_buy <id>        run the shop's own buy() path, so every gate
	--                        (penance, balance, already-active) applies
	--                        identically to whatever a UI would enforce.
	--   /pil_grant_ordos <n> add n Ordos to the wallet. For test setup only.
	--   /pil_wipe_shop       clear consumables AND unlocks. Aggressive; used
	--                        when rehearsing the fresh-install experience.
	_mod:command("pil_shop", "Pilgrimage: list every Emporium SKU with state", function()
		local lines = { "Pilgrimage Emporium", "", "Balance: " .. tostring(_shop.balance()) .. " Ordos", "" }
		local skus = _shop.all()
		for i = 1, #skus do
			local sku = skus[i]
			local cost = sku.cost and (tostring(sku.cost) .. " O") or "-"
			local status
			if sku.kind == "consumable" then
				if sku.stackable then
					-- v0.20.1: show the stack count for stackables. Zero
					-- reads as "available", any positive is "ACTIVE xN".
					local n = _shop.stack_count(sku.id)
					status = n > 0 and ("ACTIVE x" .. tostring(n)) or "available"
				else
					status = _shop.is_active(sku.id) and "ACTIVE" or "available"
				end
			else
				status = _shop.is_unlocked(sku.id) and "UNLOCKED" or "available"
			end
			local can, why = _shop.can_buy(sku.id)
			if not can then status = status .. " (" .. tostring(why) .. ")" end
			if sku.pending then status = status .. " [pending: hook not yet wired]" end
			lines[#lines + 1] = string.format("  %-16s %-10s %-24s %s",
				sku.id, cost, sku.name, status)
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "usage: /pil_buy <id>"
		report("shop.txt", lines)
		_shared.notify(string.format("Emporium: %d SKUs, %d Ordos", #skus, _shop.balance()))
	end)

	_mod:command("pil_buy", "Pilgrimage: buy an Emporium SKU by id", function(id)
		if type(id) ~= "string" or id == "" then
			_shared.notify("usage: /pil_buy <sku_id>", "alert")
			return
		end
		local ok, reason = _shop.buy(id)
		if not ok then
			_shared.notify("buy failed: " .. tostring(reason), "alert")
		end
	end)

	_mod:command("pil_grant_ordos", "Pilgrimage: grant Ordos to the wallet (testing)", function(amount)
		amount = tonumber(amount) or 100
		if amount <= 0 then
			_shared.notify("usage: /pil_grant_ordos <positive number>", "alert")
			return
		end
		local balance = _wallet.add(amount, "debug_grant")
		_shared.notify(string.format("Granted %d Ordos. Balance: %d", amount, balance or 0))
	end)

	-- v0.21.2: snapshot the current character's loadout so we can bake it
	-- into a bot preset. Meant to be run in the Mourningstar with the
	-- character speccced exactly how you want the bot to play. Writes
	-- bot_preset_<id>.txt with archetype, gender, level, voice, every
	-- talent id, and every loadout slot's item_id, so Kaizen can send
	-- the file back and we bake it into the preset catalogue.
	--
	-- The dump also includes a bounded recursive walk of the profile
	-- table itself, at depth 3, so any field we don't know we need yet
	-- gets captured too (bot_gestalts, visual_loadout, etc.).
	_mod:command("pil_capture_bot_preset", "Pilgrimage: snapshot current character loadout as a bot preset draft", function(preset_id)
		if type(preset_id) ~= "string" or preset_id == "" then
			_shared.notify("usage: /pil_capture_bot_preset <preset_id>", "alert")
			return
		end

		local player = _shared.local_player and _shared.local_player() or nil
		if not player then
			_shared.notify("no local player", "alert")
			return
		end

		-- Profile getter shape varies by build; try the standard method.
		local profile
		if type(player.profile) == "function" then
			local ok, p = pcall(player.profile, player)
			if ok then profile = p end
		end
		profile = profile or player._profile or player.profile
		if type(profile) ~= "table" then
			_shared.notify("no profile on local player", "alert")
			return
		end

		local lines = { "Pilgrimage bot preset capture: " .. preset_id, "" }

		-- Named fields we know matter for the resolve path (from BB's
		-- bot_profiles.lua). If any are absent on this build, they show
		-- as "<absent>" so the miss is visible rather than silent.
		local function field(name)
			local v = profile[name]
			if v == nil then return "<absent>" end
			if type(v) == "table" then
				local n = v.name or v.id
				return n and (tostring(n) .. " (table)") or "<table>"
			end
			return tostring(v)
		end

		lines[#lines + 1] = "-- Headline fields --"
		lines[#lines + 1] = "archetype       = " .. field("archetype")
		lines[#lines + 1] = "gender          = " .. field("gender")
		lines[#lines + 1] = "current_level   = " .. field("current_level")
		lines[#lines + 1] = "selected_voice  = " .. field("selected_voice")
		lines[#lines + 1] = "character_id    = " .. field("character_id")
		lines[#lines + 1] = "character_name  = " .. field("name")
		lines[#lines + 1] = ""

		-- Talents. Fatshark's shape is a flat map of talent-node names
		-- to allocated counts (or true/false), keyed by node id.
		lines[#lines + 1] = "-- Talents (profile.talents) --"
		if type(profile.talents) == "table" then
			local keys = {}
			for k in pairs(profile.talents) do keys[#keys + 1] = tostring(k) end
			table.sort(keys)
			for i = 1, #keys do
				local k = keys[i]
				local v = profile.talents[k]
				if type(v) == "table" then
					lines[#lines + 1] = "  " .. k .. " = <table>"
				else
					lines[#lines + 1] = "  " .. k .. " = " .. tostring(v)
				end
			end
			if #keys == 0 then lines[#lines + 1] = "  <empty>" end
		else
			lines[#lines + 1] = "  <profile.talents absent>"
		end
		lines[#lines + 1] = ""

		-- Loadout: each slot points at an item table. loadout_item_ids
		-- separately holds the item instance ids that let a bot
		-- re-resolve the same weapon at spawn.
		lines[#lines + 1] = "-- Loadout (profile.loadout) --"
		if type(profile.loadout) == "table" then
			local slots = {}
			for k in pairs(profile.loadout) do slots[#slots + 1] = tostring(k) end
			table.sort(slots)
			for i = 1, #slots do
				local slot = slots[i]
				local item = profile.loadout[slot]
				local item_name = type(item) == "table" and (item.name or item.__master_item and item.__master_item.name) or nil
				local item_id = profile.loadout_item_ids and profile.loadout_item_ids[slot] or nil
				lines[#lines + 1] = string.format("  %-30s name=%s  id=%s",
					slot, tostring(item_name or "?"), tostring(item_id or "?"))
			end
			if #slots == 0 then lines[#lines + 1] = "  <empty>" end
		else
			lines[#lines + 1] = "  <profile.loadout absent>"
		end
		lines[#lines + 1] = ""

		-- v0.21.3: full EWC override dump.
		--
		-- EWC (Extended Weapon Customization) stores its edits in
		-- profile.loadout_item_data[slot].overrides. The generic recursive
		-- walk below truncates at depth 3, which cuts EWC data off right
		-- as it gets useful. Extract each slot's overrides tree with NO
		-- depth cap so we can bake weapon customization into the preset.
		--
		-- v0.21.4 walker fix: the earlier pass collected keys with
		-- tostring() then re-looked them up as strings. For tables with
		-- NUMERIC keys (perks[1], perks[2], base_stats[N]) that lookup
		-- misses and every value reads as nil. Fix: iterate with pairs
		-- and preserve the value in-band via a table so we sort by
		-- display name but hand the ORIGINAL key back to the value read.
		lines[#lines + 1] = "-- EWC overrides (loadout_item_data[slot].overrides, full depth) --"
		if type(profile.loadout_item_data) == "table" then
			local function _walk_full(t, prefix, seen)
				seen = seen or {}
				if seen[t] then
					lines[#lines + 1] = prefix .. "<cycle>"
					return
				end
				seen[t] = true
				-- Collect (display, original_key, value) triples. Sorting
				-- happens on display, but the value is captured up front
				-- so we never need to look it back up with a coerced key.
				local entries = {}
				for k, v in pairs(t) do
					entries[#entries + 1] = { display = tostring(k), key = k, value = v }
				end
				table.sort(entries, function(a, b) return a.display < b.display end)
				for i = 1, #entries do
					local e = entries[i]
					local v = e.value
					local tv = type(v)
					if tv == "table" then
						lines[#lines + 1] = prefix .. e.display .. " = {"
						_walk_full(v, prefix .. "  ", seen)
						lines[#lines + 1] = prefix .. "}"
					elseif tv ~= "function" and tv ~= "userdata" then
						lines[#lines + 1] = prefix .. e.display .. " = " .. tostring(v)
					end
				end
				seen[t] = nil
			end

			local slot_names = {}
			for slot in pairs(profile.loadout_item_data) do
				slot_names[#slot_names + 1] = tostring(slot)
			end
			table.sort(slot_names)
			local any = false
			for i = 1, #slot_names do
				local slot = slot_names[i]
				local data = profile.loadout_item_data[slot]
				if type(data) == "table" and type(data.overrides) == "table" then
					any = true
					lines[#lines + 1] = "  " .. slot .. ".overrides = {"
					_walk_full(data.overrides, "    ", nil)
					lines[#lines + 1] = "  }"
				end
			end
			if not any then lines[#lines + 1] = "  <no slot has an overrides table>" end
		else
			lines[#lines + 1] = "  <profile.loadout_item_data absent>"
		end
		lines[#lines + 1] = ""

		-- bot_gestalts (BB uses these; capture in case they're needed).
		lines[#lines + 1] = "-- bot_gestalts --"
		if type(profile.bot_gestalts) == "table" then
			for k, v in pairs(profile.bot_gestalts) do
				lines[#lines + 1] = "  " .. tostring(k) .. " = " .. tostring(v)
			end
		else
			lines[#lines + 1] = "  <absent>"
		end
		lines[#lines + 1] = ""

		-- Bounded recursive walk of the whole profile, so anything we
		-- didn't extract explicitly still shows up. Depth 3 keeps the
		-- file readable while still capturing the substantive shape.
		-- v0.21.4: same walker fix as the EWC dump above (preserve the
		-- original key type when reading values, so numeric-keyed tables
		-- like arrays don't silently read as nil).
		lines[#lines + 1] = "-- Full profile dump (depth <= 3) --"
		local function _walk(t, prefix, depth)
			if depth > 3 then
				lines[#lines + 1] = prefix .. "<truncated>"
				return
			end
			local entries = {}
			for k, v in pairs(t) do
				entries[#entries + 1] = { display = tostring(k), value = v }
			end
			table.sort(entries, function(a, b) return a.display < b.display end)
			for i = 1, #entries do
				local e = entries[i]
				local v = e.value
				local tv = type(v)
				if tv == "table" then
					lines[#lines + 1] = prefix .. e.display .. " = {"
					_walk(v, prefix .. "  ", depth + 1)
					lines[#lines + 1] = prefix .. "}"
				elseif tv ~= "function" and tv ~= "userdata" then
					-- skip functions and userdata; anything else, dump.
					lines[#lines + 1] = prefix .. e.display .. " = " .. tostring(v)
				end
			end
		end
		_walk(profile, "  ", 1)

		report("bot_preset_" .. preset_id .. ".txt", lines)
		_shared.notify("Preset draft written: bot_preset_" .. preset_id .. ".txt")
	end)

	-- v0.22.0: bot preset commands.
	--
	--   /pil_preset_list           write preset catalogue + unlock states
	--   /pil_preset_default <id>   force this preset onto every bot slot
	--                              (Kaizen's "make her the default temporarily")
	--                              pass "none" to clear.
	--   /pil_preset_bind <s> <id>  bind a preset to specific bot slot
	--   /pil_preset_unbind <s>     clear a slot binding
	--   /pil_preset_status         current bindings + spawn counter
	--   /pil_preset_reset          wipe every binding (test cleanup)
	_mod:command("pil_preset_list", "Pilgrimage: list bot presets", function()
		local lines = { "Pilgrimage bot presets", "" }
		local presets = _preset.all()
		for i = 1, #presets do
			local p = presets[i]
			local unlocked = _preset.is_unlocked(p.id)
			local status = unlocked and "UNLOCKED" or ("locked (" .. tostring(p.unlock_penance) .. ")")
			lines[#lines + 1] = string.format("  %-20s %-20s %s",
				p.id, p.display_name, status)
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "commands: /pil_preset_default <id> | /pil_preset_bind <slot> <id>"
		lines[#lines + 1] = "restore: /pil_preset_restore <id> | /pil_preset_restore_all"
		report("presets.txt", lines)
		_shared.notify(string.format("Presets: %d", #presets))
	end)

	_mod:command("pil_preset_default", "Pilgrimage: force a preset onto every bot slot", function(id)
		if not id or id == "" then
			_shared.notify("usage: /pil_preset_default <preset_id | none>", "alert")
			return
		end
		local ok, why = _preset.set_default(id)
		if not ok then
			_shared.notify("default set failed: " .. tostring(why), "alert")
		else
			if id == "none" or id == "" then
				_shared.notify("Preset default cleared.")
			else
				local p = _preset.get(id)
				_shared.notify("Preset default: " .. (p and p.display_name or id) ..
					". Every bot in the next mission will spawn as this preset.")
			end
		end
	end)

	_mod:command("pil_preset_bind", "Pilgrimage: bind a preset to a bot slot", function(slot, id)
		if not slot or not id then
			_shared.notify("usage: /pil_preset_bind <slot 1-6> <preset_id>", "alert")
			return
		end
		local ok, why = _preset.bind_slot(slot, id)
		if not ok then
			_shared.notify("bind failed: " .. tostring(why), "alert")
		else
			_shared.notify(string.format("Bound slot %s to %s", tostring(slot), tostring(id)))
		end
	end)

	_mod:command("pil_preset_unbind", "Pilgrimage: clear a bot slot binding", function(slot)
		if not slot then
			_shared.notify("usage: /pil_preset_unbind <slot>", "alert")
			return
		end
		local ok, why = _preset.unbind_slot(slot)
		if not ok then
			_shared.notify("unbind failed: " .. tostring(why), "alert")
		else
			_shared.notify("Slot " .. tostring(slot) .. " unbound")
		end
	end)

	_mod:command("pil_preset_status", "Pilgrimage: show current preset bindings", function()
		local s = _preset.status()
		local lines = { "Pilgrimage preset status", "" }
		lines[#lines + 1] = "Default: " .. tostring(s.default or "<none>")
		lines[#lines + 1] = "Slot bindings:"
		if #s.bindings == 0 then
			lines[#lines + 1] = "  <none>"
		else
			for i = 1, #s.bindings do
				local b = s.bindings[i]
				lines[#lines + 1] = "  slot " .. tostring(b.slot) .. " = " .. b.id
			end
		end
		lines[#lines + 1] = "Captured compatibility data:"
		for i = 1, #(s.sources or {}) do
			local source = s.sources[i]
			if source.captured_personality or source.captured_ewc then
				lines[#lines + 1] = string.format("  %s: voice=%s, EWC=%s",
					source.id, tostring(source.captured_personality or "<none>"),
					tostring(source.captured_ewc))
			end
		end
		lines[#lines + 1] = "Catalogue size: " .. tostring(s.catalogue_size)
		lines[#lines + 1] = "Spawn counter (this session): " .. tostring(s.spawn_counter)
		report("presets_status.txt", lines)
		_shared.notify(string.format("Presets: default=%s, %d slots bound",
			tostring(s.default or "none"), #s.bindings))
	end)

	_mod:command("pil_preset_reset", "Pilgrimage: clear default + all slot bindings", function()
		_preset.clear_all_bindings()
		_shared.notify("All preset bindings cleared.")
	end)

	-- v0.22.8: source-character binding commands.
	--
	-- The v0.22.8 pivot uses one of your saved characters as the
	-- "template" for each preset. The bot clones the real backend
	-- profile of that character and only overrides name + voice. These
	-- commands manage which character is pinned to which preset.
	--
	--   /pil_preset_source_list          list your cached characters
	--                                    with an index number
	--   /pil_preset_source <preset> <n>  bind character at index <n>
	--                                    to preset
	--   /pil_preset_source <preset> none clear the binding
	--   /pil_preset_capture_char <preset>
	--                                    convenience: bind whichever
	--                                    character is currently selected
	--                                    (in-game or on the char select
	--                                    screen)
	--   /pil_preset_restore <preset>     clear one personal capture and
	--                                    use the shipped version
	--   /pil_preset_restore_all          clear every personal capture
	--   /pil_preset_fetch                manually re-fetch profiles
	--                                    (the game auto-fetches on the
	--                                    character screen; use this if
	--                                    the cache count reads 0)
	_mod:command("pil_preset_source_list", "Pilgrimage: list cached character profiles", function()
		local list = _preset.list_cached_profiles()
		local lines = { "Pilgrimage cached profiles", "" }
		if #list == 0 then
			lines[#lines + 1] = "  <empty>. Open the Character Select screen once, then run this."
			lines[#lines + 1] = "  Or run /pil_preset_fetch to force a fetch now."
		else
			for i = 1, #list do
				local p = list[i]
				lines[#lines + 1] = string.format(
					"  [%d] %-24s %-10s %-6s  %s",
					i, p.name, p.archetype, p.gender, p.character_id)
			end
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "usage: /pil_preset_source <preset_id> <index>"
		lines[#lines + 1] = "       /pil_preset_capture_char <preset_id> (uses currently-active char)"
		report("preset_sources.txt", lines)
		_shared.notify(string.format("Cached profiles: %d", #list))
	end)

	_mod:command("pil_preset_source", "Pilgrimage: bind preset to cached character by index", function(preset_id, index)
		if not preset_id or preset_id == "" then
			_shared.notify("usage: /pil_preset_source <preset_id> <index | none>", "alert")
			return
		end
		if not _preset.get(preset_id) then
			_shared.notify("unknown preset: " .. preset_id, "alert")
			return
		end
		if not index or index == "none" or index == "" then
			_preset.set_source_character(preset_id, nil)
			_shared.notify("Source character cleared for " .. preset_id)
			return
		end
		local list = _preset.list_cached_profiles()
		local n = tonumber(index)
		if not n or n < 1 or n > #list then
			_shared.notify("index out of range. Run /pil_preset_source_list first.", "alert")
			return
		end
		local target = list[n]
		local ok, why = _preset.set_source_character(preset_id, target.character_id)
		if not ok then
			_shared.notify("bind failed: " .. tostring(why), "alert")
			return
		end
		_shared.notify(string.format(
			"Bound %s to '%s' (%s %s). Bot will spawn as a clone of this character.",
			preset_id, target.name, target.gender, target.archetype))
	end)

	-- v0.22.25: convenience combo. Captures BOTH the currently-active
	-- character AND the current NPC Look state onto a preset in one
	-- command. Removes the "I forgot to re-capture the look after
	-- rebinding the char" (or vice-versa) failure mode.
	_mod:command("pil_preset_capture_all", "Pilgrimage: capture current character AND NPC Look onto a preset (combo)", function(preset_id)
		if not preset_id or preset_id == "" then
			_shared.notify("usage: /pil_preset_capture_all <preset_id>", "alert")
			return
		end
		if not _preset.get(preset_id) then
			_shared.notify("unknown preset: " .. preset_id, "alert")
			return
		end

		local char_id = _preset.selected_character_id()
		if not char_id then
			_shared.notify("Could not read currently-selected character. Select a character first.", "alert")
			return
		end
		local ok_char, err_char = _preset.set_source_character(preset_id, char_id)
		if not ok_char then
			_shared.notify("char bind failed: " .. tostring(err_char), "alert")
			return
		end
		_preset.request_profile_fetch()

		-- v0.22.27: snapshot the ENTIRE profile at capture time via
		-- ProfileUtils.pack_profile. Fatshark refetches profiles on every
		-- StateLoading and overwrites _profile_cache with the CURRENTLY-
		-- ACTIVE loadout preset. Without a frozen snapshot, bots would
		-- always mirror whatever loadout Kaizen is currently running on
		-- that character, not the one that was active at capture time.
		local ok_prof, err_prof = _preset.capture_profile_for(preset_id, char_id)
		if not ok_prof then
			_shared.notify(string.format(
				"Character bound to %s, but profile snapshot failed: %s. Bots will fall back to live loadout.",
				preset_id, tostring(err_prof)), "alert")
			-- keep going, the char binding + look are still useful
		end

		-- v0.26.3: optional client-side metadata. Missing mods are normal
		-- and leave any existing sidecar untouched. Installed EWC with no
		-- customized weapons deliberately records an empty snapshot.
		local extras = _preset.capture_optional_for(preset_id, char_id)

		local ok_look, err_look = _preset.capture_current_look_for(preset_id)
		if not ok_look then
			_shared.notify(string.format(
				"Character bound to %s, but NPC Look capture failed: %s. Try /pil_preset_capture_look separately later.",
				preset_id, tostring(err_look)), "alert")
			return
		end

		local voice_text = extras.personality.ok
			and ("voice " .. tostring(extras.personality.value)) or "no PP voice"
		local ewc_text = extras.ewc.ok
			and (tostring(extras.ewc.count or 0) .. " EWC weapons") or "no EWC"
		local filter_value = extras.voice_filter and extras.voice_filter.value
		local filter_text = extras.voice_filter and extras.voice_filter.ok
			and ("Vox " .. tostring(filter_value and filter_value.key or "default"))
			or "Vox default"
		_shared.notify(string.format(
			"Captured %s: character, loadout, NPC Look, %s, %s, %s.",
			preset_id, voice_text, ewc_text, filter_text))
	end)

	_mod:command("pil_preset_capture_char", "Pilgrimage: bind the currently-active character as preset source", function(preset_id)
		if not preset_id or preset_id == "" then
			_shared.notify("usage: /pil_preset_capture_char <preset_id>", "alert")
			return
		end
		if not _preset.get(preset_id) then
			_shared.notify("unknown preset: " .. preset_id, "alert")
			return
		end
		local char_id = _preset.selected_character_id()
		if not char_id then
			_shared.notify("Could not read the currently-selected character. Run this from the hub or select a character first.", "alert")
			return
		end
		local ok, why = _preset.set_source_character(preset_id, char_id)
		if not ok then
			_shared.notify("bind failed: " .. tostring(why), "alert")
			return
		end
		-- Also refresh the cache so the source is definitely present.
		_preset.request_profile_fetch()

		-- v0.22.27: also snapshot the profile at capture time (frozen JSON
		-- via ProfileUtils.pack_profile) so future loadout swaps on this
		-- character do not drift into the bot's loadout.
		local ok_prof, err_prof = _preset.capture_profile_for(preset_id, char_id)
		if not ok_prof then
			_shared.notify(string.format(
				"Character bound to %s, but profile snapshot failed: %s. Bots will fall back to live loadout on that character.",
				preset_id, tostring(err_prof)), "alert")
			return
		end

		local extras = _preset.capture_optional_for(preset_id, char_id)
		local voice_text = extras.personality.ok
			and ("voice " .. tostring(extras.personality.value)) or "no PP voice"
		local ewc_text = extras.ewc.ok
			and (tostring(extras.ewc.count or 0) .. " EWC weapons") or "no EWC"
		local filter_value = extras.voice_filter and extras.voice_filter.value
		local filter_text = extras.voice_filter and extras.voice_filter.ok
			and ("Vox " .. tostring(filter_value and filter_value.key or "default"))
			or "Vox default"

		_shared.notify(string.format(
			"Captured %s from character %s: frozen loadout, %s, %s, %s.",
			preset_id, tostring(char_id):sub(1, 8) .. "...", voice_text, ewc_text, filter_text))
	end)

	_mod:command("pil_preset_capture_extras", "Pilgrimage: recapture Vox Filter, Personality Picker and EWC for a preset", function(preset_id)
		if not preset_id or preset_id == "" or not _preset.get(preset_id) then
			_shared.notify("usage: /pil_preset_capture_extras <preset_id>", "alert")
			return
		end
		local char_id = _preset.selected_character_id()
		if not char_id then
			_shared.notify("Capture extras from the hub after your character spawns.", "alert")
			return
		end
		local extras = _preset.capture_optional_for(preset_id, char_id)
		local voice_text = extras.personality.ok
			and tostring(extras.personality.value) or tostring(extras.personality.reason)
		local ewc_text = extras.ewc.ok
			and (tostring(extras.ewc.count or 0) .. " weapons") or tostring(extras.ewc.reason)
		local filter_value = extras.voice_filter and extras.voice_filter.value
		local filter_text = extras.voice_filter and extras.voice_filter.ok
			and tostring(filter_value and filter_value.key or "default")
			or tostring(extras.voice_filter and extras.voice_filter.reason or "default")
		_shared.notify("Preset extras for " .. preset_id .. ": voice="
			.. voice_text .. ", EWC=" .. ewc_text .. ", Vox=" .. filter_text)
	end)

	_mod:command("pil_preset_clear_extras", "Pilgrimage: clear captured Vox Filter, Personality Picker and EWC data", function(preset_id)
		if not preset_id or preset_id == "" or not _preset.get(preset_id) then
			_shared.notify("usage: /pil_preset_clear_extras <preset_id>", "alert")
			return
		end
		_preset.set_stored_personality(preset_id, nil)
		_preset.set_stored_ewc(preset_id, nil)
		_preset.set_stored_voice_filter(preset_id, "default", nil)
		_shared.notify("Cleared captured personality, EWC and Vox data for " .. preset_id .. ".")
	end)

	_mod:command("pil_preset_restore", "Pilgrimage: restore one bot preset to the version shipped with the mod", function(preset_id)
		if not preset_id or preset_id == "" or not _preset.get(preset_id) then
			_shared.notify("usage: /pil_preset_restore <preset_id>", "alert")
			return
		end

		local ok, count_or_err = _preset.restore_bundled_capture(preset_id)
		if not ok then
			_shared.notify("restore failed: " .. tostring(count_or_err), "alert")
			return
		end

		-- Personality Picker values are session-local. Refreshing here makes its
		-- bundled personality visible immediately; all other layers apply when
		-- the bot next spawns.
		if _voices and type(_voices.sync_pp) == "function" then
			pcall(_voices.sync_pp)
		end

		local preset = _preset.get(preset_id)
		_shared.notify(string.format(
			"Restored shipped preset for %s. Cleared %d personal capture field(s); it applies on the next bot spawn.",
			preset and preset.display_name or preset_id, count_or_err))
	end)

	_mod:command("pil_preset_restore_all", "Pilgrimage: restore every bot preset to the versions shipped with the mod", function()
		local ok, info_or_err = _preset.restore_all_bundled_captures()
		if not ok then
			_shared.notify("restore all failed: " .. tostring(info_or_err), "alert")
			return
		end

		if _voices and type(_voices.sync_pp) == "function" then
			pcall(_voices.sync_pp)
		end

		_shared.notify(string.format(
			"Restored all shipped bot presets. Cleared %d personal field(s) across %d preset(s); they apply on the next bot spawn.",
			info_or_err.fields or 0, info_or_err.presets or 0))
	end)

	-- v0.22.22: capture the CURRENT NPC Look state and store it against
	-- a preset, so bots for that preset always spawn wearing THAT look
	-- regardless of what Kaizen has pinned live at spawn time. Fixes the
	-- "bots inherited my current outfit instead of Sister Argenta's" bug.
	--
	--   /pil_preset_capture_look <preset_id>   snapshot & store
	--   /pil_preset_clear_look   <preset_id>   remove stored snapshot
	--                                          (bots revert to live look)
	_mod:command("pil_preset_capture_look", "Pilgrimage: snapshot current NPC Look and pin it to a preset", function(preset_id)
		if not preset_id or preset_id == "" then
			_shared.notify("usage: /pil_preset_capture_look <preset_id>", "alert")
			return
		end
		if not _preset.get(preset_id) then
			_shared.notify("unknown preset: " .. preset_id, "alert")
			return
		end
		local ok, err = _preset.capture_current_look_for(preset_id)
		if not ok then
			_shared.notify("capture failed: " .. tostring(err), "alert")
			return
		end
		_shared.notify("Captured current NPC Look for " .. preset_id ..
			". Bots for this preset will now use this exact look, not your live pin.")
	end)

	_mod:command("pil_preset_clear_look", "Pilgrimage: remove the stored NPC Look for a preset (revert to live)", function(preset_id)
		if not preset_id or preset_id == "" then
			_shared.notify("usage: /pil_preset_clear_look <preset_id>", "alert")
			return
		end
		if not _preset.get(preset_id) then
			_shared.notify("unknown preset: " .. preset_id, "alert")
			return
		end
		local ok, err = _preset.set_stored_look_state(preset_id, nil)
		if not ok then
			_shared.notify("clear failed: " .. tostring(err), "alert")
			return
		end
		_shared.notify("Cleared stored look for " .. preset_id ..
			". Bots for this preset will now mirror your live NPC Look pin.")
	end)

	_mod:command("pil_preset_fetch", "Pilgrimage: manually refresh the character profile cache", function()
		local ok, why = _preset.request_profile_fetch()
		if not ok then
			_shared.notify("fetch failed: " .. tostring(why), "alert")
			return
		end
		_shared.notify("Profile fetch requested. Run /pil_preset_source_list in a moment to see cached characters.")
	end)

	-- v0.22.16: manually trigger NPC Look reapply on every bot with a
	-- pilgrimage_preset sentinel. This calls the patched-in
	-- npclook_apply_active_look_to_player function once per bot unit,
	-- swapping NPC Look's active target to that bot for the duration of
	-- one apply. Requires our NPC Look patch. Best run in-mission once
	-- bots are visible with base gear; check afterwards whether they
	-- gained the extra slots, raw units, and material overrides.
	--
	-- NPC Look's next update tick will re-bind to the local player and
	-- reapply. The local player may briefly appear in default gear
	-- during that swap; this is a known limitation of running through
	-- NPC Look's single-unit binding model.
	_mod:command("pil_bot_reapply_npclook", "Pilgrimage: manually apply NPC Look's active look to every Pilgrimage bot", function()
		_shared.notify("Pilgrimage: reapply starting...")

		-- Wrap the WHOLE body in pcall so we ALWAYS surface an error
		-- notification if something throws, rather than silently dying
		-- between the "starting" and "done" toasts. Previous debug pass
		-- died somewhere in the loop without writing the log or firing
		-- the final notify; this belt-and-suspenders makes any future
		-- failure loud.
		local lines = {
			"NPC Look bot reapply attempt",
			"started at Lua VM time",
			"",
		}
		local function stage(msg)
			lines[#lines + 1] = "STAGE: " .. tostring(msg)
			_mod:echo("Pilgrimage/reapply: " .. tostring(msg))
		end

		local body_ok, body_err = pcall(function()
			stage("entering body")

			local Managers = rawget(_G, "Managers")
			local get_mod = rawget(_G, "get_mod")
			local npc_look = get_mod and get_mod("NPCLook")

			stage("checked globals; npc_look present=" .. tostring(npc_look ~= nil))

			if not npc_look then
				lines[#lines + 1] = "ABORT: NPC Look mod not detected."
				_shared.notify("NPC Look mod not detected.", "alert")
				return
			end
			-- v0.22.18: prefer the new per-unit function that doesn't
			-- clobber NPC Look's globals; fall back to the older
			-- per-player function (which does mutate globals) if only
			-- that one is present.
			local apply_fn = npc_look.npclook_apply_active_look_to_bot_unit
				or npc_look.npclook_apply_active_look_to_player
			if type(apply_fn) ~= "function" then
				lines[#lines + 1] = "ABORT: patched NPCLook.lua is not the loaded version. Neither entry point is available."
				_shared.notify("NPC Look patch not installed. Reinstall the patched NPCLook.lua and restart the game.", "alert")
				return
			end
			if not Managers or not Managers.player then
				lines[#lines + 1] = "ABORT: player manager not available."
				_shared.notify("player manager not available (are you in a mission?)", "alert")
				return
			end
			stage("player manager present")

			-- PlayerManager exposes players(), bot_players(),
			-- human_players() (see Fatshark's foundation/managers/player/
			-- player_manager.lua). Try players() first for the full list
			-- with a bot_players() fallback.
			local players
			if type(Managers.player.players) == "function" then
				local ok, res = pcall(Managers.player.players, Managers.player)
				if ok then
					players = res
				else
					lines[#lines + 1] = "players() threw: " .. tostring(res)
				end
			end
			if not players and type(Managers.player.bot_players) == "function" then
				local ok, res = pcall(Managers.player.bot_players, Managers.player)
				if ok then
					players = res
				else
					lines[#lines + 1] = "bot_players() threw: " .. tostring(res)
				end
			end
			if not players then
				lines[#lines + 1] = "ABORT: could not fetch player list from PlayerManager."
				_shared.notify("could not fetch player list", "alert")
				return
			end
			stage("got player list")

			-- Snapshot NPC Look state.
			local snap
			if type(npc_look.npclook_state_snapshot) == "function" then
				local ok, s = pcall(npc_look.npclook_state_snapshot)
				if ok then snap = s end
			end
			local applied_count = 0
			if snap and type(snap.applied) == "table" then
				for _ in pairs(snap.applied) do applied_count = applied_count + 1 end
			end
			lines[#lines + 1] = ""
			lines[#lines + 1] = "NPC Look state.applied slot count: " .. tostring(applied_count)
			if applied_count == 0 then
				lines[#lines + 1] = "  (no cosmetics pinned; NPC Look has nothing to apply)"
			elseif snap and snap.applied then
				for slot, item in pairs(snap.applied) do
					lines[#lines + 1] = "  applied[" .. tostring(slot) .. "] = " .. tostring(item)
				end
			end
			stage("snapshot logged")

			local applied, failed, skipped = 0, 0, 0
			local total_players = 0
			lines[#lines + 1] = ""

			for _, player in pairs(players) do
				total_players = total_players + 1
				local per_player_ok, per_player_err = pcall(function()
					local name = "?"
					if type(player.name) == "function" then
						local ok_n, res_n = pcall(player.name, player)
						if ok_n then name = tostring(res_n) end
					end

					local profile
					if type(player.profile) == "function" then
						local ok_p, res_p = pcall(player.profile, player)
						if ok_p then profile = res_p end
					end
					profile = profile or player._profile

					local sentinel = type(profile) == "table" and profile._pilgrimage_preset or nil
					local is_pilgrimage_bot = sentinel ~= nil

					lines[#lines + 1] = "player: " .. name .. " sentinel=" .. tostring(sentinel)

					if is_pilgrimage_bot then
						local call_ok, apply_ok, err, loading, equipped_c, failed_c = pcall(
							apply_fn, player)
						if call_ok then
							lines[#lines + 1] = "  ok=" .. tostring(apply_ok) ..
								" err=" .. tostring(err) ..
								" packages_loading=" .. tostring(loading) ..
								" equipped=" .. tostring(equipped_c) ..
								" failed_slots=" .. tostring(failed_c)
							if apply_ok then
								applied = applied + 1
							else
								failed = failed + 1
							end
						else
							lines[#lines + 1] = "  PCALL FAILURE: " .. tostring(apply_ok)
							failed = failed + 1
						end
					else
						skipped = skipped + 1
					end
				end)
				if not per_player_ok then
					lines[#lines + 1] = "  PER-PLAYER LOOP THREW: " .. tostring(per_player_err)
					failed = failed + 1
				end
			end
			stage("finished iterating players (total=" .. tostring(total_players) .. ")")

			-- Stash the counters as string tail so we can find them on
			-- disk if the notify never lands on screen.
			lines[#lines + 1] = ""
			lines[#lines + 1] = string.format(
				"RESULT: %d bots applied, %d failed, %d skipped, %d players total, %d slots pinned.",
				applied, failed, skipped, total_players, applied_count)

			_shared.notify(string.format(
				"Bot reapply done. %d bots applied, %d failed, %d skipped, %d players total, %d slots pinned. Log: bot_reapply_npclook.txt",
				applied, failed, skipped, total_players, applied_count))
		end)

		if not body_ok then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "OUTER PCALL CAUGHT: " .. tostring(body_err)
			_shared.notify("Pilgrimage reapply command crashed: " .. tostring(body_err), "alert")
			_mod:echo("Pilgrimage bot reapply crashed: " .. tostring(body_err))
		end

		-- ALWAYS write the log, even if the body threw.
		report("bot_reapply_npclook.txt", lines)
	end)

	-- v0.22.7 archetype probe. Kept for backward compatibility; in
	-- v0.22.8 the archetype comes from the source profile so this
	-- returns benign defaults.
	_mod:command("pil_preset_probe", "Pilgrimage: probe archetype lookup for Sister Argenta's target", function(name)
		local probe = _preset.probe_archetype(name or "zealot")
		local status
		if probe.resolved then
			status = string.format(
				"OK: %s resolved via %s. name=%s, health=%s, base_talents=%d",
				probe.name,
				probe.global_has_name and "global.Archetypes" or "require",
				tostring(probe.resolved_name),
				tostring(probe.resolved_health),
				probe.resolved_base_talents_count or 0)
		else
			status = string.format(
				"FAILED: %s not resolvable. global_present=%s, global_has=%s, require_ok=%s, require_has=%s",
				probe.name,
				tostring(probe.Archetypes_global),
				tostring(probe.global_has_name),
				tostring(probe.require_ok),
				tostring(probe.require_has_name))
		end
		_shared.notify(status, probe.resolved and "" or "alert")
	end)

	-- v0.22.4: live diagnostic. Writes preset_diag.txt with:
	--   - class-presence check (are BotSynchronizerHost, BotPlayer
	--     actually loaded as globals?)
	--   - hook fire counters (are our hooks running at all?)
	--   - EVERY current bot's live profile: archetype, character_id,
	--     name, selected_voice, is_local_profile, our sentinel, BB's
	--     sentinel, talent count, whether Chorus is present, weapon
	--     ids in loadout_item_data.
	--
	-- Run this AFTER a mission has loaded and bots are visible in the
	-- world. What we're looking for is whether our sentinel survives
	-- on the live bot's profile. Three possible states:
	--   sentinel present, talents match = we succeeded but visual
	--     rendering is a separate issue (unit spawn uses a different
	--     data source)
	--   sentinel present, talents WRONG = something is mutating the
	--     profile in place after us
	--   sentinel absent = the whole profile got replaced downstream
	--     of our hook (different data flow than add_bot/set_profile)
	_mod:command("pil_preset_diag", "Pilgrimage: dump preset diagnostic and live bot profiles", function()
		local lines = { "Pilgrimage preset diagnostic", "" }

		-- Class presence check
		local bsh = rawget(_G, "BotSynchronizerHost")
		local bp = rawget(_G, "BotPlayer")
		lines[#lines + 1] = "== Class presence =="
		lines[#lines + 1] = "  BotSynchronizerHost: " .. tostring(bsh ~= nil)
		lines[#lines + 1] = "  BotPlayer:           " .. tostring(bp ~= nil)
		if bsh then
			lines[#lines + 1] = "  BotSynchronizerHost.add_bot: " ..
				(type(bsh.add_bot) == "function" and "function" or "MISSING")
		end
		if bp then
			lines[#lines + 1] = "  BotPlayer.set_profile: " ..
				(type(bp.set_profile) == "function" and "function" or "MISSING")
		end
		lines[#lines + 1] = ""

		-- Hook fire counters (v0.22.8 vocabulary: "substituted" replaces
		-- "mutated" since we now hand orig() a different profile instead
		-- of editing the incoming one)
		lines[#lines + 1] = "== Hook stats =="
		local st = _preset.stats and _preset.stats() or {}
		lines[#lines + 1] = "  add_bot fired:            " .. tostring(st.add_bot_fires or 0)
		lines[#lines + 1] = "  add_bot substituted:      " .. tostring(st.add_bot_substituted or 0)
		lines[#lines + 1] = "  add_bot fell through:     " .. tostring(st.add_bot_fallthrough or 0)
		lines[#lines + 1] = "  set_profile calls:        " .. tostring(st.set_profile_calls or 0)
		lines[#lines + 1] = "  set_profile blocked:      " .. tostring(st.set_profile_blocked or 0)
		lines[#lines + 1] = "  set_profile passed:       " .. tostring(st.set_profile_passed or 0)
		lines[#lines + 1] = "  fetch_all_profiles hits:  " .. tostring(st.fetch_all_hits or 0)
		lines[#lines + 1] = "  generate_random_name hits: " .. tostring(st.generate_name_hits or 0)
		lines[#lines + 1] = ""

		-- Bindings + source characters (v0.22.8)
		lines[#lines + 1] = "== Bindings =="
		local status = _preset.status()
		lines[#lines + 1] = "  default preset:      " .. tostring(status.default or "<none>")
		lines[#lines + 1] = "  spawn counter:       " .. tostring(status.spawn_counter or 0)
		lines[#lines + 1] = "  cached profiles:     " .. tostring(status.profile_cache_count or 0)
		if status.sources then
			for i = 1, #status.sources do
				local s = status.sources[i]
				lines[#lines + 1] = "  " .. s.id .. " source_character_id: " ..
					tostring(s.source_character_id or "<unset>")
			end
		end
		lines[#lines + 1] = ""

		-- v0.22.25: per-preset source-character detail. Dumps the
		-- cached profile for each preset's bound source: name, voice,
		-- personality, key gear ids. Lets Kaizen tell at a glance
		-- whether a stale binding is the reason bots are wearing the
		-- wrong loadout / speaking no lines.
		lines[#lines + 1] = "== Preset source profiles =="
		local presets = _preset.all()
		for i = 1, #presets do
			local p = presets[i]
			local source_id = _preset.source_character_id(p.id)
			lines[#lines + 1] = "  " .. p.id .. ":"
			if not source_id then
				lines[#lines + 1] = "    <no source character bound> (run /pil_preset_capture_char " .. p.id .. ")"
			else
				lines[#lines + 1] = "    source_character_id: " .. tostring(source_id)
				local src = _preset.get_cached_profile(source_id)
				if not src then
					lines[#lines + 1] = "    <profile not in cache. Cache warms when you open Character Select or run /pil_preset_fetch.>"
				else
					local arch_name = "?"
					if type(src.archetype) == "table" then
						arch_name = tostring(src.archetype.name or src.archetype.archetype_name)
					end
					lines[#lines + 1] = "    name:                 " .. tostring(src.name)
					lines[#lines + 1] = "    original_name:        " .. tostring(src.original_name)
					lines[#lines + 1] = "    archetype:            " .. arch_name
					lines[#lines + 1] = "    gender:               " .. tostring(src.gender)
					lines[#lines + 1] = "    selected_voice:       " .. tostring(src.selected_voice)
					lines[#lines + 1] = "    voice_effects:        " .. tostring(src.voice_effects)
					local personality = src.lore and src.lore.backstory and src.lore.backstory.personality
					lines[#lines + 1] = "    lore.backstory.personality: " .. tostring(personality)
					lines[#lines + 1] = "    lore present:         " .. tostring(src.lore ~= nil)
					lines[#lines + 1] = "    personal present:     " .. tostring(src.personal ~= nil)
					lines[#lines + 1] = "    narrative present:    " .. tostring(src.narrative ~= nil)
					lines[#lines + 1] = "    has stored look:      " ..
						tostring(_preset.has_stored_look_state(p.id))
					lines[#lines + 1] = "    has packed profile:   " ..
						tostring(_preset.has_stored_packed_profile(p.id))
						.. " (frozen snapshot survives loadout swaps)"
					if src.loadout_item_data then
						local prim = src.loadout_item_data.slot_primary
						local sec  = src.loadout_item_data.slot_secondary
						lines[#lines + 1] = "    slot_primary.id:      " ..
							(prim and tostring(prim.id) or "<nil>")
						lines[#lines + 1] = "    slot_secondary.id:    " ..
							(sec and tostring(sec.id) or "<nil>")
					end
				end
			end
		end
		lines[#lines + 1] = ""

		-- Recent set_profile call details (v0.22.5)
		lines[#lines + 1] = "== Recent set_profile events =="
		local recent = _preset.recent_set_profile and _preset.recent_set_profile() or {}
		if #recent == 0 then
			lines[#lines + 1] = "  <none recorded>"
		else
			for i = 1, #recent do
				local e = recent[i]
				lines[#lines + 1] = string.format(
					"  #%d  time_since_apply=%.2fs existing_sentinel=%s incoming_sentinel=%s existing_name=%s incoming_name=%s",
					i,
					e.time_since_apply or -1,
					tostring(e.existing_sentinel),
					tostring(e.incoming_sentinel),
					tostring(e.existing_name),
					tostring(e.incoming_name))
			end
		end
		lines[#lines + 1] = ""

		-- Live bot profiles: dump EVERY player regardless of bot detection,
		-- try multiple bot-detection accessors, print the profile even if
		-- we can't classify. The name string already contains "[BOT]" for
		-- bots so we string-match as a fallback.
		lines[#lines + 1] = "== Live player profiles (every player, bot or not) =="
		local Managers = rawget(_G, "Managers")
		local player_manager = Managers and Managers.player
		if not player_manager then
			lines[#lines + 1] = "  <no player manager>"
		else
			local players
			if type(player_manager.human_and_bot_players) == "function" then
				local ok, result = pcall(player_manager.human_and_bot_players, player_manager)
				if ok then players = result end
			end
			if not players and type(player_manager.players) == "function" then
				local ok, result = pcall(player_manager.players, player_manager)
				if ok then players = result end
			end

			if not players then
				lines[#lines + 1] = "  <could not fetch player list>"
			else
				local count = 0
				for _, player in pairs(players) do
					count = count + 1

					local name = "?"
					if type(player.name) == "function" then
						local ok, res = pcall(player.name, player)
						if ok then name = tostring(res) end
					end

					-- Try every bot-detection accessor we know about.
					local checks = {}
					if type(player.bot_player) == "function" then
						local ok, res = pcall(player.bot_player, player)
						checks.bot_player = ok and tostring(res) or "err"
					end
					if type(player.is_human_controlled) == "function" then
						local ok, res = pcall(player.is_human_controlled, player)
						checks.is_human_controlled = ok and tostring(res) or "err"
					end
					if type(player.remote) == "function" then
						local ok, res = pcall(player.remote, player)
						checks.remote = ok and tostring(res) or "err"
					end
					checks.name_has_BOT = tostring(name:find("%[BOT%]") ~= nil)
					checks.class_name = tostring(player.__class_name or "?")

					lines[#lines + 1] = "  Player " .. tostring(count) .. ": name=" .. name
					lines[#lines + 1] = "    bot detection:      " ..
						"bot_player=" .. tostring(checks.bot_player) ..
						" is_human_controlled=" .. tostring(checks.is_human_controlled) ..
						" remote=" .. tostring(checks.remote) ..
						" name_has_BOT=" .. tostring(checks.name_has_BOT) ..
						" class=" .. checks.class_name

					local profile
					if type(player.profile) == "function" then
						local ok, res = pcall(player.profile, player)
						if ok then profile = res end
					end
					profile = profile or player._profile or player.profile

					if type(profile) ~= "table" then
						lines[#lines + 1] = "    <no profile>"
					else
						local arch = profile.archetype
						local arch_name = "?"
						if type(arch) == "table" then arch_name = tostring(arch.name)
						elseif arch then arch_name = tostring(arch) end
						lines[#lines + 1] = "    archetype:          " .. arch_name
						lines[#lines + 1] = "    character_id:       " .. tostring(profile.character_id)
						lines[#lines + 1] = "    profile.name:       " .. tostring(profile.name)
						lines[#lines + 1] = "    selected_voice:     " .. tostring(profile.selected_voice)
						lines[#lines + 1] = "    is_local_profile:   " .. tostring(profile.is_local_profile)
						lines[#lines + 1] = "    _pilgrimage_preset: " .. tostring(profile._pilgrimage_preset)
						lines[#lines + 1] = "    _bb_resolved:       " .. tostring(profile._bb_resolved)

						local talent_count = 0
						local has_chorus = false
						local has_dash = false
						if type(profile.talents) == "table" then
							for k in pairs(profile.talents) do
								talent_count = talent_count + 1
								if k == "zealot_bolstering_prayer" then has_chorus = true end
								if k == "zealot_dash" then has_dash = true end
							end
						end
						lines[#lines + 1] = "    talents count:      " .. tostring(talent_count)
						lines[#lines + 1] = "    has Chorus node:    " .. tostring(has_chorus)
						lines[#lines + 1] = "    has Dash node:      " .. tostring(has_dash)

						if profile.loadout_item_data then
							local primary = profile.loadout_item_data.slot_primary
							local secondary = profile.loadout_item_data.slot_secondary
							lines[#lines + 1] = "    slot_primary.id:    " ..
								(primary and tostring(primary.id) or "<nil>")
							lines[#lines + 1] = "    slot_secondary.id:  " ..
								(secondary and tostring(secondary.id) or "<nil>")
						else
							lines[#lines + 1] = "    loadout_item_data:  <absent>"
						end
					end
				end
				lines[#lines + 1] = ""
				lines[#lines + 1] = "  total players seen: " .. tostring(count)
			end
		end

		report("preset_diag.txt", lines)
		_shared.notify("Preset diagnostic written to preset_diag.txt")
	end)

	-- v0.21.0: bot progression diagnostic. Writes bots.txt with the
	-- current slot count, each contribution source, and whether Better
	-- Bots + Custom Character Bots are detected. Kaizen's main use is
	-- verifying that unlocking a penance or buying a slot actually
	-- moves the slot count. v0.22.79: sources updated for the slots
	-- redesign (3-4 Emporium, 5-6 penances).
	_mod:command("pil_bots", "Pilgrimage: bot slot progression + Better Bots detection", function()
		local s = _bots.status()
		local lines = { "Pilgrimage bot status", "" }
		lines[#lines + 1] = "Current slot count: " .. tostring(s.slot_count) ..
			" (base " .. tostring(s.base_slots) .. ", cap " .. tostring(s.max_slots) ..
			", spawn target " .. tostring(s.spawn_target) .. ")"
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Contributions:"
		lines[#lines + 1] = "  Slot 3 (bot_slot_3 purchase):      " .. tostring(s.slot_from_shop_3)
		lines[#lines + 1] = "  Slot 4 (bot_slot_4 purchase):      " .. tostring(s.slot_from_shop_4)
		lines[#lines + 1] = "  Slot 5 (pilgrim_full_muster):      " .. tostring(s.slot_from_full_muster)
		lines[#lines + 1] = "  Slot 6 (pilgrim_emperors_six):     " .. tostring(s.slot_from_emperors_six)
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Companion mods:"
		lines[#lines + 1] = "  Better Bots detected:            " ..
			tostring(s.better_bots_present) .. "  (recommended for high tiers)"
		lines[#lines + 1] = "  Vox Filter detected:             " ..
			tostring(s.vox_filter_present) .. "  (fixes bot voice attenuation-behind-you)"
		local get_mod = rawget(_G, "get_mod")
		lines[#lines + 1] = "  Personality Picker detected:     " ..
			tostring(get_mod and get_mod("PersonalityPicker") ~= nil) ..
			"  (captured bot personalities)"
		lines[#lines + 1] = "  EWC detected:                    " ..
			tostring(get_mod and get_mod("extended_weapon_customization") ~= nil) ..
			"  (captured bot weapon visuals)"
		lines[#lines + 1] = "  Custom Character Bots detected:  " ..
			tostring(s.ccb_present) .. "  (incompatible with Pilgrimage presets)"
		report("bots.txt", lines)
		_shared.notify(string.format("Bots: %d slots. Better Bots: %s. CCB: %s.",
			s.slot_count,
			s.better_bots_present and "yes" or "MISSING",
			s.ccb_present and "installed (conflict)" or "clean"))
	end)

	_mod:command("pil_wipe_shop", "Pilgrimage: clear all shop consumables AND unlocks", function()
		_shop.clear_run_consumables()
		local skus = _shop.all()
		local revoked = 0
		for i = 1, #skus do
			if _shop.is_unlocked(skus[i].id) then
				_shop.revoke_unlock(skus[i].id)
				revoked = revoked + 1
			end
		end
		_shared.notify(string.format("Emporium wiped. Cleared consumables and %d permanent unlocks.", revoked))
	end)

	_mod:command("pil_reset_all_penances", "Pilgrimage: revoke every earned penance", function()
		local revoked, skipped = 0, 0
		local pens = _penances.all()
		for i = 1, #pens do
			local ok = _penances.revoke(pens[i].id)
			if ok then revoked = revoked + 1 else skipped = skipped + 1 end
		end
		if _run_state and _run_state.flush then _run_state.flush(true) end
		_shared.notify(string.format(
			"Pilgrimage: revoked %d penance(s), %d were already locked", revoked, skipped))
	end)

	-- The catalogue truth-check. For every curse I claim exists, walks the
	-- game's own circumstance template table and reports its ACTUAL mutator
	-- list. If the label I chose doesn't match what those mutators do, this
	-- says so directly. Reads live sources; no guessing, no cache.
	_mod:command("pil_verify_curses", "Pilgrimage: check every catalogue label against what the source actually loads", function()
		local lines = { "Pilgrimage curse catalogue verification", "" }
		local function add(text) lines[#lines + 1] = text end

		local ok, templates = pcall(require, "scripts/settings/circumstance/circumstance_templates")
		if not ok or type(templates) ~= "table" then
			add("could not require circumstance_templates: " .. tostring(templates))
			report("verify_curses.txt", lines)
			return
		end

		add("Each row: our label -> internal name -> mutators the engine loads")
		add("")
		for i = 1, #_curses.CATALOGUE do
			local entry = _curses.CATALOGUE[i]
			local tpl = templates[entry.name]
			if not tpl then
				add(string.format("MISSING  sev%d  %-30s = %s  (no template on this build)",
					entry.severity, entry.label, entry.name))
			else
				local muts = tpl.mutators or {}
				local list = #muts == 0 and "(no mutators!)" or table.concat(muts, ", ")
				add(string.format("ok       sev%d  %-30s = %s",
					entry.severity, entry.label, entry.name))
				add(string.format("                                          -> %s", list))
			end
		end

		report("verify_curses.txt", lines)
	end)

	-- What curse stacking would launch RIGHT NOW: the synthetic circumstance, the
	-- curses feeding it, and the deduped mutator union. Run before launching a leg
	-- to see exactly what the mission will carry.
	_mod:command("pil_stack", "Pilgrimage: report the stacked curse the next launch would carry", function()
		local lines = { "Pilgrimage curse stacking", "" }
		local function add(text) lines[#lines + 1] = text end

		add("stacking enabled: " .. tostring(_curses.stacking_enabled()))

		local run = _run_state.get()
		if not run.active then
			add("no active run, nothing to stack")
			report("stack.txt", lines)
			return
		end

		local prefix = _run_state.curse_prefix() or {}
		add(string.format("assignment %d of %d, curses so far:", run.index, #run.queue))
		for i = 1, #prefix do
			local curse = prefix[i]
			add(string.format("  %d  %-40s %s", i, tostring(curse),
				curse == "default" and "(no curse)" or _curses.display_name(curse)))
		end
		add("")

		local name = _curses.stacked_for(prefix)
		local stack = _curses.last_stack()
		if not name or not stack then
			add("stacked_for declined: the next launch uses the plain single-curse path")
			add("(that is correct for assignment 1, an all-default prefix, or stacking off)")
		else
			add("the next launch would run circumstance '" .. name .. "' carrying:")
			for i = 1, #stack.curses do
				add("  " .. _curses.display_name(stack.curses[i]) .. "  (" .. stack.curses[i] .. ")")
			end
			add("")
			add(tostring(#stack.mutators) .. " mutators, deduped, newest curse first:")
			for i = 1, #stack.mutators do
				add("  " .. tostring(stack.mutators[i]))
			end
		end

		report("stack.txt", lines)
	end)

	-- GROUND TRUTH for "is the curse actually applying". Run this INSIDE a
	-- mission. It reads the live managers, not our own records: the
	-- circumstance the engine is running, every mutator it loaded and whether
	-- each is active, and the monster pacing spawn list (which is where
	-- daemonhosts from Heinous Rituals would appear, each at a travel
	-- distance). If the mutator is loaded but the spawn list has no witches,
	-- the level had no witch spawn points; different problem, different fix.
	_mod:command("pil_mutators", "Pilgrimage: report the mission's live circumstance, mutators and monster spawns", function()
		local lines = { "Pilgrimage live mutator report", "" }
		local function add(text) lines[#lines + 1] = text end

		local state = Managers and Managers.state

		-- What the engine believes the circumstance is.
		local circumstance_manager = state and state.circumstance
		if circumstance_manager and circumstance_manager.circumstance_name then
			local ok, name = pcall(circumstance_manager.circumstance_name, circumstance_manager)
			add("engine circumstance: " .. tostring(ok and name or "unreadable"))
		else
			add("engine circumstance: no circumstance manager (not in a mission?)")
		end

		-- What the launcher asked for, and what the guard saw and did.
		local record = _run_state.launch_record and _run_state.launch_record()
		if record then
			add(string.format("launch record:       %s on %s",
				tostring(record.circumstance), tostring(record.mission)))
		else
			add("launch record:       none")
		end

		local guard = _mutator_guard and _mutator_guard.last_report()
		if guard then
			add(string.format("guard saw:           incoming '%s', used '%s'%s",
				tostring(guard.incoming), tostring(guard.used),
				guard.note and (" (" .. guard.note .. ")") or ""))
		else
			add("guard saw:           nothing this session (no mission load since boot)")
		end
		add("")

		-- The mutators the engine actually holds, the fact that settles it.
		local mutator_manager = state and state.mutator
		local mutators = mutator_manager and mutator_manager._mutators
		if type(mutators) == "table" then
			local names = {}
			for name in pairs(mutators) do names[#names + 1] = name end
			table.sort(names)
			add(#names .. " mutators loaded:")
			for i = 1, #names do
				local mutator = mutators[names[i]]
				local active = false
				if mutator and type(mutator.is_active) == "function" then
					local ok, value = pcall(mutator.is_active, mutator)
					active = ok and value == true
				end
				add(string.format("  %-50s %s", names[i], active and "ACTIVE" or "inactive"))
			end
		else
			add("no mutator manager (not in a mission?)")
		end
		add("")

		-- Monster pacing: the scheduled monster/witch spawns by travel distance.
		local pacing = state and state.pacing
		local monster_pacing = pacing and pacing._monster_pacing
		local monsters = monster_pacing and monster_pacing._monsters
		if type(monsters) == "table" then
			add(#monsters .. " scheduled monster spawns (travel distance, type, breed):")
			for i = 1, #monsters do
				local entry = monsters[i]
				add(string.format("  %7.1f  %-10s %s",
					tonumber(entry.travel_distance) or -1,
					tostring(entry.spawn_type),
					tostring(entry.breed_name)))
			end
		else
			add("no monster pacing spawn list (not the host, or too early in the load)")
		end

		local main_path = state and state.main_path
		if main_path and main_path.furthest_travel_distance then
			local ok, distance = pcall(main_path.furthest_travel_distance, main_path, 1)
			if ok and distance then
				add("")
				add(string.format("players' furthest travel distance: %.1f", distance))
			end
		end

		-- Boon effects the fx guard had to suppress because this mission's
		-- packages do not carry their particles. Informational: the boons
		-- still work, the flash is what is missing.
		if _fx_guard and _fx_guard.status then
			local fx = _fx_guard.status()
			add("")
			if fx.total == 0 then
				add("fx guard: nothing suppressed this session")
			else
				add(string.format("fx guard: %d spawn%s suppressed (missing from this mission's packages):",
					fx.total, fx.total == 1 and "" or "s"))
				for i = 1, #fx.names do
					local name = fx.names[i]
					add(string.format("  %4dx  %s", fx.counts[name] or 0, name))
				end
			end
		end

		report("mutators.txt", lines)
	end)

	-- Stand where the terminal should go, face the right way, run this.
	_mod:command("pil_here", "Pilgrimage: write this spot and nearby props to file", function(radius)
		report("probe.txt", _probe.here(radius))
	end)

	-- Aim at a prop and run this to identify exactly what is under the crosshair.
	-- Uses the same raycast the game's own interaction system uses.
	_mod:command("pil_look", "Pilgrimage: identify the object you are aiming at", function(distance)
		local hits_by_filter, err, origin, forward = _probe.look_at(distance)

		local lines = { "Pilgrimage look-at probe", "" }
		local function add(text) lines[#lines + 1] = text end

		if not hits_by_filter then
			add("unavailable: " .. tostring(err))
			report("look.txt", lines)
			return
		end

		add("camera origin:  " .. tostring(_probe.fmt_vec(origin)))
		add("camera forward: " .. tostring(_probe.fmt_vec(forward)))
		add("max distance:   " .. tostring(tonumber(distance) or 8))
		add("")

		local total = 0
		for i = 1, #hits_by_filter do
			local entry = hits_by_filter[i]
			add("[" .. entry.filter .. "]  " .. #entry.hits .. " hit(s)")
			for h = 1, #entry.hits do
				total = total + 1
				local hit = entry.hits[h]
				add(string.format("  %5.2fm  node=%s%s  pos %s",
					hit.distance or -1, tostring(hit.node),
					hit.ignored and "  IGNORED_BY_INTERACTION" or "",
					tostring(_probe.fmt_vec(hit.position))))
				add("         " .. tostring(_probe.identity(hit.unit)))
				add("         has ui_interaction_marker node: " ..
					tostring(_probe.has_node(hit.unit, "ui_interaction_marker")))
			end
			add("")
		end

		if total == 0 then
			add("Nothing hit. Move closer or aim directly at the prop.")
		end

		report("look.txt", lines)
		_shared.notify("Pilgrimage: " .. total .. " object(s) under the crosshair")
	end)

	-- Dump a weapon template and its real damage profiles.
	_mod:command("pil_weapon", "Pilgrimage: write a weapon template to file", function(name, depth)
		local lines, resolved = _weapons.dump(name, depth)
		report("weapon.txt", lines)
		if resolved then
			_shared.notify("Pilgrimage: dumped " .. tostring(resolved))
		end
	end)

	_mod:command("pil_weapon_list", "Pilgrimage: write all weapon template names to file", function(needle)
		local names = _weapons.find(needle or "")
		local lines = { "Pilgrimage weapon template names",
		                "filter: '" .. tostring(needle or "") .. "'",
		                "count: " .. #names, "" }
		for i = 1, #names do lines[#lines + 1] = "  " .. names[i] end
		report("weapon_list.txt", lines)
	end)

	_mod:command("pil_weapon_revert", "Pilgrimage: undo all weapon patches", function()
		local n = _weapons.revert_all()
		_shared.notify("Pilgrimage: reverted " .. n .. " weapon actions")
	end)

	-- Live proof that patching works: sample the wielded weapon's numbers, apply a
	-- multiplier, sample again, and write both sides to a file. Then go hit a
	-- dummy and see whether it matches, and /pil_weapon_revert when done.
	--   /pil_weapon_test         doubles the wielded weapon
	--   /pil_weapon_test 3       triples it
	--   /pil_weapon_test 2 lasgun_p1_m1
	_mod:command("pil_weapon_test", "Pilgrimage: apply a test multiplier to a weapon", function(factor, name)
		factor = tonumber(factor) or 2

		local target = name
		if not target or target == "" then
			target = _weapons.wielded_template_name()
		end

		local lines = { "Pilgrimage weapon patch test", "" }
		local function add(text) lines[#lines + 1] = text end

		if not target then
			add("No weapon resolved. Hold a weapon, or pass a template name.")
			add("Use /pil_weapon_list to see the names.")
			report("weapon_test.txt", lines)
			return
		end

		add("template:   " .. tostring(target))
		add("multiplier: " .. tostring(factor))
		add("can patch:  " .. tostring(_weapons.can_apply()))
		add("")

		if not _weapons.can_apply() then
			add("REFUSED. Patching is gated to a solo session or the Psykhanium,")
			add("because damage is resolved by the host and editing it as a client")
			add("in someone else's lobby only desyncs your own view.")
			report("weapon_test.txt", lines)
			return
		end

		local before = _weapons.sample(target)

		-- A fresh id each time so repeated runs do not collide.
		local id = "live_test_" .. tostring(_weapons.test_counter())
		_weapons.define({
			id = id,
			templates = { target },
			power = factor,
			cleave = factor,
			armour = { armored = factor, super_armor = factor,
			           unarmored = factor, resistant = factor,
			           berserker = factor, disgustingly_resilient = factor },
		})

		local ok, result = _weapons.apply(id)
		add("applied: " .. tostring(ok))
		if type(result) == "table" then
			add(string.format("  templates %d  actions %d  numbers scaled %d",
				result.templates, result.actions, result.numbers))
			if result.numbers == 0 then
				add("  WARNING: zero numbers changed. The profile shape is not what")
				add("  the patcher expects. Send this file back.")
			end
		else
			add("  " .. tostring(result))
		end
		add("")

		local after = _weapons.sample(target)
		local after_by_action = {}
		for i = 1, #after do after_by_action[after[i].action] = after[i] end

		add(string.format("%-34s %-22s %-22s", "action", "before", "after"))
		for i = 1, #before do
			local b = before[i]
			local a = after_by_action[b.action] or {}
			local function pair(row, lo, hi)
				if row[lo] == nil then return "-" end
				return string.format("%.4g / %.4g", row[lo], row[hi] or 0)
			end
			add(string.format("%-34s %-22s %-22s", b.action .. "  power",
				pair(b, "power_attack_min", "power_attack_max"),
				pair(a, "power_attack_min", "power_attack_max")))
			add(string.format("%-34s %-22s %-22s", "   armored",
				pair(b, "armored_min", "armored_max"),
				pair(a, "armored_min", "armored_max")))
		end

		add("")
		add("Go hit a dummy, then run /pil_weapon_revert to undo.")
		add("Patches also revert automatically when you leave the mission.")

		report("weapon_test.txt", lines)
		_shared.notify("Pilgrimage: patched " .. tostring(target) .. " x" .. tostring(factor))
	end)


	-- ---------------------------------------------------------------------
	-- Mission catalogue and launching
	-- ---------------------------------------------------------------------

	_mod:command("pil_missions", "Pilgrimage: write the mission catalogue to file", function()
		local playable = _missions.playable()
		local by_zone = _missions.by_zone()

		local lines = { "Pilgrimage mission catalogue", "" }
		local function add(t) lines[#lines + 1] = t end

		add("playable missions: " .. #playable)
		add("")
		add("Playable = mechanism_name 'adventure', game_mode 'coop_complete_objective',")
		add("mission_type not 'operations'. This is the same filter the mission board uses.")
		add("")

		local zones = {}
		for zone in pairs(by_zone) do zones[#zones + 1] = zone end
		table.sort(zones)

		for i = 1, #zones do
			local zone = zones[i]
			add("[" .. zone .. "]  " .. #by_zone[zone] .. " mission(s)")
			for j = 1, #by_zone[zone] do
				local info = _missions.info(by_zone[zone][j])
				add(string.format("  %-24s type=%-16s intro=%s outro=%s",
					info.name, tostring(info.mission_type),
					tostring(info.has_intro), tostring(info.has_outro)))
			end
			add("")
		end

		add("=== ALL TEMPLATES (including non-playable) ===")
		local all = _missions.templates()
		local names = {}
		if all then for name in pairs(all) do names[#names + 1] = name end end
		table.sort(names)
		for i = 1, #names do
			local info = _missions.info(names[i])
			add(string.format("  %-26s mech=%-12s mode=%-26s zone=%s",
				names[i], tostring(info.mechanism_name),
				tostring(info.game_mode_name), tostring(info.zone_id)))
		end

		report("missions.txt", lines)
	end)

	-- Generate a run queue WITHOUT launching anything, so the generator can be
	-- checked before it is trusted.
	_mod:command("pil_gen", "Pilgrimage: preview a generated run (does not launch)", function(count, seed)
		count = tonumber(count) or _settings.run_length()
		seed = tonumber(seed) or 12345

		local queue = _missions.generate_queue(count, seed)

		local lines = { "Pilgrimage run generation preview", "" ,
		                "count: " .. count, "seed:  " .. seed, "" }
		for i = 1, #queue do
			local info = _missions.info(queue[i])
			lines[#lines + 1] = string.format("  leg %d  %-24s zone=%s",
				i, queue[i], tostring(info and info.zone_id))
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Same seed always gives the same run. Nothing was launched."
		report("gen.txt", lines)
	end)

	-- Launch a single mission. The riskiest command in the mod, so it reports its
	-- refusal reason rather than failing quietly.
	--   /pil_launch km_enforcer
	--   /pil_launch km_enforcer 4
	--   /pil_launch km_enforcer 4 mutator_ventilation_purge_1
	_mod:command("pil_launch", "Pilgrimage: launch one mission solo", function(mission, danger, circumstance)
		if not mission or mission == "" then
			_shared.notify("Pilgrimage: /pil_launch <mission> [danger 1-5] [circumstance]", "alert")
			return
		end

		local allowed, why = _launcher.can_launch()
		if not allowed then
			_shared.notify("Pilgrimage: cannot launch, " .. tostring(why), "alert")
			report("launch.txt", { "Pilgrimage launch refused", "", "reason: " .. tostring(why) })
			return
		end

        local ok, err = _launcher.launch(mission, tonumber(danger) or 3, circumstance)
		if ok then
			_shared.notify("Pilgrimage: launching " .. _missions.display_name(mission))
		else
			_shared.notify("Pilgrimage: launch failed, " .. tostring(err), "alert")
			report("launch.txt", { "Pilgrimage launch failed", "", "mission: " .. tostring(mission),
			                       "error: " .. tostring(err) })
		end
	end)

	-- Start a generated run and launch its first leg.
	_mod:command("pil_run_start", "Pilgrimage: generate a run and launch leg 1", function(count, seed)
		count = tonumber(count) or _settings.run_length()
		seed = tonumber(seed) or (_settings.run_seeded() and _settings.configured_seed() or nil)

		if not seed or seed == 0 then
			-- No fixed seed configured. Derive one from wall clock, which is the only
			-- entropy available: math.random is not seeded per session here and
			-- fixed-frame time restarts every mission.
			seed = (_fileio.epoch() % 2147483646) + 1
		end

		local queue = _missions.generate_queue(count, seed)
		if #queue == 0 then
			_shared.notify("Pilgrimage: could not generate a run", "alert")
			return
		end

		local starting_diff = _difficulty and _difficulty.starting_difficulty() or 0
		local curse_queue = _curses and _curses.assign and _curses.assign(#queue, seed) or nil
		local plan_id = _war_plans and _war_plans.selected_id() or ""
		_run_state.start(queue, seed, curse_queue, starting_diff, plan_id)

		local lines = { "Pilgrimage run started", "", "seed: " .. seed, "" }
		local readable = {}
		for i = 1, #queue do
			lines[#lines + 1] = "  leg " .. i .. "  " .. _missions.label(queue[i])
			readable[#readable + 1] = _missions.display_name(queue[i])
		end
		report("run.txt", lines)

		_shared.notify("Pilgrimage run: " .. table.concat(readable, " then "))

		local ok, err = _launcher.launch_current_leg()
		if not ok then
			_shared.notify("Pilgrimage: run created but launch failed, " .. tostring(err), "alert")
		end
	end)

	-- NOTE: /pil_next used to live here and did the same thing as /pil_skip, which
	-- made it impossible to tell which one you had just used. One command now.

	-- Escape hatch. A Pilgrimage-launched mission hides both vanilla exits, so this
	-- is the guaranteed way out even if the menu patch fails.
	-- Finish the current leg without playing it and launch the next one. Exists so a
	-- change can be tested without sitting through a fifteen minute mission.
	-- Where am I in the run? Answers on screen, no file, no round trip through me.
	_mod:command("pil_run", "Pilgrimage: show the current run on screen", function()
		local state = _run_state.get()

		if not state.active then
			_shared.notify("Pilgrimage: no active run. /pil_run_start to begin one.")
			return
		end

		_shared.notify(string.format("Pilgrimage, leg %d of %d: %s",
			state.index, #state.queue,
			_missions.display_name(_run_state.current_mission())))

		-- The rest of the route, so you can see what is coming.
		local upcoming = {}
		for i = state.index + 1, #state.queue do
			upcoming[#upcoming + 1] = _missions.display_name(state.queue[i])
		end
		if #upcoming > 0 then
			_shared.notify("Next: " .. table.concat(upcoming, " then "))
		else
			_shared.notify("This is the final leg.")
		end

		-- And a file with the full detail including internal ids.
		local lines = { "Pilgrimage run", "", "seed: " .. tostring(state.seed),
		                "leg:  " .. state.index .. " of " .. #state.queue, "" }
		for i = 1, #state.queue do
			local marker = (i < state.index and "done") or (i == state.index and ">>>>") or "    "
			lines[#lines + 1] = string.format("  %s leg %d  %s",
				marker, i, _missions.label(state.queue[i]))
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "results so far:"
		for i = 1, #state.legs_done do
			lines[#lines + 1] = "  " .. state.legs_done[i]
		end
		report("run.txt", lines)
	end)

	_mod:command("pil_skip", "Pilgrimage: skip to the next leg of the run", function()
		-- chain.skip already announces the new leg with its real name, so only
		-- report failures here rather than notifying twice.
		local ok, err = _chain.skip("skipped")
		if not ok then
			_shared.notify("Pilgrimage: " .. tostring(err), "alert")
		end
	end)

	-- Toggle recording of attack reports, then write what was seen.
	_mod:command("pil_hits", "Pilgrimage: record attack reports to diagnose bot hit markers", function()
		if _hitprobe.is_enabled() then
			_hitprobe.set_enabled(false)
			report("hits.txt", _hitprobe.report_lines())
		else
			_hitprobe.set_enabled(true)
			_shared.notify("Pilgrimage: recording attacks, let a bot shoot then run /pil_hits again")
		end
	end)

	_mod:command("pil_leave", "Pilgrimage: leave the current mission", function()
		local ok, err = _escape.leave("leave_mission")
		if ok then
			_shared.notify("Pilgrimage: leaving mission")
		else
			_shared.notify("Pilgrimage: could not leave, " .. tostring(err), "alert")
		end
	end)

	_mod:command("pil_perf", "Pilgrimage: write the performance report to file", function()
		local lines = _perf.is_enabled()
			and _perf.format_report("Pilgrimage perf:")
			or { "Pilgrimage perf: profiling is OFF.",
			     "Enable it in mod options, play for a bit, then run this again." }
		report("perf.txt", lines)
	end)

	_mod:command("pil_tick", "Pilgrimage: write the tick task table to file", function()
		local tasks = _tick.tasks()
		local lines = { "Pilgrimage tick tasks", "count: " .. #tasks, "" }
		for i = 1, #tasks do
			local task = tasks[i]
			lines[#lines + 1] = string.format(
				"%-24s interval %.2fs  next %.2f  runs %d  errors %d",
				task.name, task.interval, task.next_t, task.runs, task.errors)
			if task.last_error then
				lines[#lines + 1] = "    last error: " .. task.last_error
			end
		end
		report("tick.txt", lines)
	end)

	-- Round-trip the run state through settings encoding and read it back, to
	-- prove the save format survives a real DMF write.
	_mod:command("pil_run_test", "Pilgrimage: write a fake run and read it back", function()
		_run_state.start({ "km_enforcer", "dm_stockpile", "cm_habs" }, 1234567)
		_run_state.add_boon("hordes_buff_example_a", 2)
		_run_state.add_boon("hordes_buff_example_b", 1)
		_run_state.add_curse("ammo_pickup_modifier", 3)

		-- Drop the in-memory copy so the read below comes purely from settings,
		-- which is what a level change does to us.
		_run_state.load()
		local state = _run_state.get()

		local lines = {
			"Pilgrimage run-state round trip",
			"",
			"summary: " .. _run_state.summary(),
			"",
			"raw settings values as stored by DMF:",
			"  _run_active:  " .. tostring(_mod:get(_run_state.KEY.active)),
			"  _run_queue:   " .. tostring(_mod:get(_run_state.KEY.queue)),
			"  _run_index:   " .. tostring(_mod:get(_run_state.KEY.index)),
			"  _run_boons:   " .. tostring(_mod:get(_run_state.KEY.boons)),
			"  _run_curses:  " .. tostring(_mod:get(_run_state.KEY.curses)),
			"  _run_seed:    " .. tostring(_mod:get(_run_state.KEY.seed)),
			"",
			"decoded back:",
			"  queue length: " .. tostring(#state.queue),
			"  current leg:  " .. tostring(_run_state.current_mission()),
			"  boon a:       " .. tostring(state.boons.hordes_buff_example_a),
			"  boon b:       " .. tostring(state.boons.hordes_buff_example_b),
			"  curse tier:   " .. tostring(state.curses.ammo_pickup_modifier),
			"",
			"Run /pil_run_clear when finished so this fake run does not sit in your config.",
		}
		report("run_test.txt", lines)
	end)

	_mod:command("pil_run_next", "Pilgrimage: advance the run one leg", function()
		local next_mission = _run_state.advance("complete")
		_shared.notify("Pilgrimage: " .. (next_mission
			and ("next leg is " .. tostring(next_mission))
			or "run finished"))
	end)

	_mod:command("pil_run_clear", "Pilgrimage: abandon the current run", function()
		_run_state.abandon("command")
		-- v0.23.5 (Kaizen field report): consumables die with the run on
		-- THIS path too. The terminal's abandon and both chain endings
		-- (complete, fail) already wiped them; this command called
		-- run_state.abandon directly and skipped the wipe, so bans and
		-- scout-aheads survived a /pil_run_clear into the next run.
		if _shop and _shop.clear_run_consumables then
			pcall(_shop.clear_run_consumables)
		end
		_shared.notify("Pilgrimage: run cleared")
	end)

	_mod:command("pil_reset", "Pilgrimage: reset all settings to defaults", function()
		local failures = _settings.reset_all()
		local dmf = rawget(_G, "dmf")
		if dmf and dmf.save_unsaved_settings_to_file then
			pcall(dmf.save_unsaved_settings_to_file)
		end
		_shared.notify("Pilgrimage: settings reset" ..
			(#failures > 0 and (", " .. #failures .. " failed") or ""))
	end)

	-- v0.22.21: bot passives.
	--
	--   /pil_passives_list             write catalogue + tier assignments
	--   /pil_passives_test <id>        apply a passive to Kaizen's own
	--                                  unit, for testing custom buff
	--                                  templates in isolation
	--   /pil_passives_reapply          force a fresh pass over every bot
	--                                  (mirror of the auto-apply pump,
	--                                  useful if you tweaked a passive
	--                                  and want it re-landed)
	_mod:command("pil_passives_list", "Pilgrimage: list bot passives and tier assignments", function()
		local lines = { "Pilgrimage bot passives", "" }
		local all = _passives.all()
		for i = 1, #all do
			local p = all[i]
			lines[#lines + 1] = string.format("  %-32s %s",
				p.id, p.display_name)
			lines[#lines + 1] = string.format("    %s", p.description)
			if p.custom and p.custom.stat_buffs then
				for stat_name, value in pairs(p.custom.stat_buffs) do
					lines[#lines + 1] = string.format("      %s = %s", stat_name, tostring(value))
				end
			end
		end
		lines[#lines + 1] = ""
		local status = _passives.status()
		lines[#lines + 1] = "Universal passives (every bot):"
		if status.universal and #status.universal > 0 then
			lines[#lines + 1] = "  " .. table.concat(status.universal, ", ")
		else
			lines[#lines + 1] = "  <none>"
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Tier baseline passives:"
		for tier, ids in pairs(status.tiers) do
			lines[#lines + 1] = string.format("  tier %d: %s",
				tier, #ids > 0 and table.concat(ids, ", ") or "<none>")
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Currently applied on live bots: " .. tostring(status.applied_count)
		report("passives.txt", lines)
		_shared.notify(string.format("Passives: %d in catalogue", #all))
	end)

	_mod:command("pil_passives_test", "Pilgrimage: apply a passive to your own unit for testing", function(id)
		if not id or id == "" then
			_shared.notify("usage: /pil_passives_test <passive_id>. See /pil_passives_list.", "alert")
			return
		end
		if not _passives.get(id) then
			_shared.notify("unknown passive: " .. tostring(id), "alert")
			return
		end
		local Managers = rawget(_G, "Managers")
		local local_player = Managers and Managers.player
			and Managers.player.local_player_safe
			and Managers.player:local_player_safe(1)
		local unit = local_player and local_player.player_unit
		if not unit then
			_shared.notify("no local player unit (are you in a mission?)", "alert")
			return
		end
		local ok, err = _passives.apply_to_unit(unit, id)
		if ok then
			_shared.notify("Applied " .. id .. " to your unit.")
		else
			_shared.notify("Passive apply failed: " .. tostring(err), "alert")
		end
	end)

	_mod:command("pil_passives_reapply", "Pilgrimage: clear applied-set and re-pump every bot's passives", function()
		if type(_passives.reset_pump_state) == "function" then
			_passives.reset_pump_state()
			_shared.notify("Passives applied-set cleared; next tick will re-apply.")
		end
	end)

	_mod:command("pil_idira_overload_test",
		"Pilgrimage: force Idira's native Perils action for audiovisual testing",
		function()
			if not _passives or type(_passives.force_idira_overload) ~= "function" then
				_shared.notify("Idira overload diagnostic is unavailable.", "alert")
				return
			end
			local ok, reason = _passives.force_idira_overload()
			if ok then
				_shared.notify("Idira overload armed. Watch and listen to her.")
			else
				_shared.notify("Idira overload test failed: " .. tostring(reason), "alert")
			end
		end)

	-- v0.22.28: manually push preset voices into Personality Picker's
	-- per-slot bot voice settings. Normally fires automatically on
	-- StateLoading, but useful when iterating on preset voice keys or
	-- verifying that PP is picking up our writes.
	_mod:command("pil_voices_sync", "Pilgrimage: sync preset bot voices into Personality Picker", function()
		if not _voices then
			_shared.notify("voices module not loaded", "alert")
			return
		end
		if not _voices.pp_available() then
			_shared.notify("Personality Picker not installed; nothing to sync.", "alert")
			return
		end
		local ok, info = _voices.sync_pp()
		if not ok then
			_shared.notify("voices sync failed: " .. tostring(info), "alert")
			return
		end
		_shared.notify(string.format(
			"Voices synced to PP: %d written, %d cleared.",
			info.written or 0, info.cleared or 0))
	end)

	_mod:command("pil_voices_diag", "Pilgrimage: dump per-slot bot voice state", function()
		if not _voices then
			_shared.notify("voices module not loaded", "alert")
			return
		end
		report("voices.txt", _voices.diagnose())
	end)

	-- Writes every report at once. One command to run when something is wrong.
	_mod:command("pil_all", "Pilgrimage: write every diagnostic report", function()
		report("status.txt", status_lines())
		report("probe.txt", _probe.here())
		report("weapon.txt", (_weapons.dump()))
		local tasks = _tick.tasks()
		local tick_lines = { "Pilgrimage tick tasks", "" }
		for i = 1, #tasks do
			tick_lines[#tick_lines + 1] = string.format("%-24s runs %d errors %d",
				tasks[i].name, tasks[i].runs, tasks[i].errors)
		end
		report("tick.txt", tick_lines)
		_shared.notify("Pilgrimage: wrote all reports to mods/Pilgrimage/")
	end)
end

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
	_perf = deps.perf
	_event_log = deps.event_log
	_run_state = deps.run_state
	_settings = deps.settings
	_tick = deps.tick
	_probe = deps.probe
	_weapons = deps.weapons
	_weapon_rebalance = deps.weapon_rebalance
	_fileio = deps.fileio
	_missions = deps.missions
	_launcher = deps.launcher
	_escape = deps.escape
	_chain = deps.chain
	_hitprobe = deps.hitprobe
	_terminal = deps.terminal
	_boons = deps.boons
	_icons = deps.icons
	_curses = deps.curses
	_mutator_guard = deps.mutator_guard
	_fx_guard = deps.fx_guard
	_difficulty = deps.difficulty
	_wallet = deps.wallet
	_scaling_hook = deps.scaling_hook
	_war_plans = deps.war_plans
	_penances = deps.penances
	_shop = deps.shop
	_bots = deps.bots
	_preset = deps.preset
	_passives = deps.passives
	_voices = deps.voices
end

return M
