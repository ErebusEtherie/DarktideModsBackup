local mod = get_mod("DarkCache")
local common = mod.common

-- ---------------------------------------------------------------------------
-- Keeping the Mourningstar and the Psykhanium in memory
--
-- What the engine does: every level transition runs LocalLoadersState.init,
-- which calls cleanup() then start_loading() on each loader. LevelLoader
-- .cleanup releases the level package and every item and theme dependency it
-- pulled in, BreedLoader does the same for breeds. Nothing is kept, so coming
-- back to the Mourningstar reads the identical set off the disk again.
--
-- What changes here: nothing stops the engine cleaning up. This takes a
-- reference of its own on those packages and never lets go.
--
-- That distinction is the design. Managers.package is reference counted and
-- PackageManager.load on an already-resident package just queues the callback
-- and returns, so one extra reference makes the engine's next load resolve out
-- of memory instead of off the disk -- while the loaders keep running their
-- normal cycle with their bookkeeping intact. Suppressing cleanup() instead
-- would edit the engine's accounting from underneath it, and a mistake there
-- breaks loading; adding references cannot, since the worst case is memory
-- held that should have been released.
--
-- Level units are still despawned and respawned normally. Only the disk read
-- is skipped, which is the part you wait for.
-- ---------------------------------------------------------------------------

local hub_cache = {}
mod.hub_cache = hub_cache

local Missions = mod:original_require("scripts/settings/mission/mission_templates")

local REFERENCE_NAME = "DarkCache"

-- Level names come from the mission templates: hub_mission_templates.lua and
-- horde_mission_templates.lua.
hub_cache.HUB = "content/levels/hub/hub_ship/missions/hub_ship"

-- The Psykhanium is the `tg_shooting_range` mission in
-- onboarding_mission_templates.lua, not the `psykhanium` one in
-- horde_mission_templates.lua -- that second name belongs to Horde mode, which
-- is a full mission and none of our business.
hub_cache.PSYKHANIUM = "content/levels/training_grounds/missions/mission_tg_basic_combat_01"

local PINNABLE_LEVELS = {
	[hub_cache.HUB] = {
		option = "opt_cache_hub",
		label = "Mourningstar",
		key = "hub",
	},
	[hub_cache.PSYKHANIUM] = {
		option = "opt_cache_psykhanium",
		label = "Psykhanium",
		key = "psykhanium",
	},
}

-- pairs() over the table above has no order; reports read better in one.
local LEVEL_ORDER = {hub_cache.HUB, hub_cache.PSYKHANIUM}

-- level_name -> {label = ..., option = ..., ids = {...}, packages = n}
local pinned = {}

-- How much a level costs to hold
--
-- Nothing in the engine reports the size of a loaded package, so the only
-- honest number available is the memory the game actually gained while the
-- level was loading: Memory.usage("B").used_memory read when LevelLoader
-- starts, and again the frame it reports itself done. The game's own views use
-- exactly this pair of readings to report their load cost (see base_view.lua).
--
-- It is an upper bound, not an exact figure: other loaders are running in the
-- same window, so the reading includes work that is not ours. It is measured
-- once per level per session and remembered between sessions, which is what
-- puts a real number in the options menu instead of a guess.
-- ---------------------------------------------------------------------------
-- Measuring what a level costs, and what holding it saves
--
-- Two windows are timed, because they answer different questions.
--
--   package phase   LocalLoadersState, from init to the frame it reports
--                   "load_done". Every loader runs in there -- level, breeds,
--                   views, game mode -- and it is the only part this mod can
--                   possibly affect. Timing LevelLoader alone, as an earlier
--                   version did, measured a fraction of it and made the mod
--                   look useless.
--
--   loading screen  StateLoading, from on_enter to on_exit: what the player
--                   actually sits through. Reported next to the package phase
--                   so the saving can be read as a share of the whole rather
--                   than in isolation.
--
-- Memory is sampled every frame of the package phase and the cost taken as
-- (final - lowest seen), not (final - first seen). A transition tears the
-- previous level down before building the new one up, so a plain start-to-end
-- delta can come out negative and was silently discarded -- which is why the
-- Psykhanium reported no size at all.
--
-- The two memory readings come from different allocators. Neither contains the
-- other, so they are always reported side by side.
-- ---------------------------------------------------------------------------

local function megabytes(bytes)
	return bytes and bytes / (1024 * 1024) or nil
end

local function now_seconds()
	local ok, value = pcall(function ()
		return Application.time_since_launch()
	end)

	return ok and type(value) == "number" and value or nil
end

local function ram_now()
	local ok, usage = pcall(function ()
		return Memory.usage("B")
	end)

	return ok and usage and usage.used_memory or nil
end

local function vram_now()
	local ok, value = pcall(function ()
		return Memory.vram_usage()
	end)

	return ok and type(value) == "number" and value or nil
end

function hub_cache.vram_status()
	local used = vram_now()

	local budget_ok, budget = pcall(function ()
		return Memory.vram_budget()
	end)

	if used then
		return used, budget_ok and type(budget) == "number" and budget or nil
	end
end

local function setting_id(level_name, suffix)
	local settings = PINNABLE_LEVELS[level_name]

	return settings and ("measured_" .. settings.key .. "_" .. suffix)
end

local function stored(level_name, suffix)
	local id = setting_id(level_name, suffix)
	local value = id and mod:get(id)

	return type(value) == "number" and value or nil
end

local function record(level_name, suffix, value)
	local id = setting_id(level_name, suffix)

	if id and value then
		mod:set(id, value)

		-- A figure measured this session should reach the menu this session.
		if mod.menu then
			mod.menu.refresh()
		end
	end
end

function hub_cache.measurements(level_name)
	local figures = {
		ram_mb = stored(level_name, "ram_mb"),
		vram_mb = stored(level_name, "vram_mb"),
		cold_ms = stored(level_name, "cold_ms"),
		warm_ms = stored(level_name, "warm_ms"),
		screen_cold_ms = stored(level_name, "screen_cold_ms"),
		screen_warm_ms = stored(level_name, "screen_warm_ms"),
	}

	if figures.cold_ms and figures.warm_ms and figures.cold_ms > figures.warm_ms then
		figures.saved_ms = figures.cold_ms - figures.warm_ms
	end

	if figures.screen_cold_ms and figures.screen_warm_ms and figures.screen_cold_ms > figures.screen_warm_ms then
		figures.screen_saved_ms = figures.screen_cold_ms - figures.screen_warm_ms
	end

	return figures
end

-- The package phase currently being timed, if any.
local phase = nil

-- The loading screen currently being timed, and the level it turned out to be.
local screen = nil

-- Called before the transition does anything at all: nothing has been torn
-- down, and our own pin state still describes what we were holding when the
-- player pressed the button. That is what decides cold from warm -- asking the
-- package manager here would answer about the level we are leaving, and asking
-- it after the teardown would be confused by deferred unloads.
function hub_cache.begin_phase(level_name)
	if not PINNABLE_LEVELS[level_name] then
		phase = nil

		return
	end

	local entry = pinned[level_name]

	phase = {
		level_name = level_name,
		warm = (entry and entry.level_held) and true or false,
		time = now_seconds(),
	}

	if screen then
		screen.level_name = level_name
		screen.warm = phase.warm
	end
end

-- Called once the transition has released the outgoing level and queued the
-- incoming one, but before any of it has arrived. That trough is the floor the
-- new level is built on, and the only baseline a memory delta can honestly be
-- taken from.
function hub_cache.baseline_after_cleanup()
	if not phase then
		return
	end

	phase.min_ram = ram_now()
	phase.min_vram = vram_now()
end

function hub_cache.sample_phase()
	if not phase then
		return
	end

	local ram, vram = ram_now(), vram_now()

	if ram and (not phase.min_ram or ram < phase.min_ram) then
		phase.min_ram = ram
	end

	if vram and (not phase.min_vram or vram < phase.min_vram) then
		phase.min_vram = vram
	end
end

function hub_cache.end_phase()
	local current = phase

	phase = nil

	if not current then
		return
	end

	local level_name = current.level_name
	local finish = now_seconds()

	if current.time and finish then
		local elapsed_ms = math.floor((finish - current.time) * 1000 + 0.5)

		if elapsed_ms >= 0 then
			record(level_name, current.warm and "warm_ms" or "cold_ms", elapsed_ms)
		end
	end

	-- A warm load reads nothing, so its memory delta describes the transition
	-- and not the level. Only a cold one says what holding this costs.
	if current.warm then
		common.debug("%s package phase served from memory", level_name)

		return
	end

	local ram = ram_now()
	local vram = vram_now()
	local ram_mb = ram and current.min_ram and megabytes(ram - current.min_ram)
	local vram_mb = vram and current.min_vram and (vram - current.min_vram)

	if ram_mb and ram_mb > 0 then
		record(level_name, "ram_mb", math.floor(ram_mb + 0.5))
	end

	if vram_mb and vram_mb > 0 then
		record(level_name, "vram_mb", math.floor(vram_mb + 0.5))
	end

	common.debug("%s loaded cold: %s MB system, %s MB video",
		level_name,
		tostring(ram_mb and math.floor(ram_mb + 0.5)),
		tostring(vram_mb and math.floor(vram_mb + 0.5)))
end

function hub_cache.begin_screen()
	screen = {time = now_seconds()}
end

function hub_cache.end_screen()
	local current = screen

	screen = nil

	if not current or not current.time or not current.level_name then
		return
	end

	local finish = now_seconds()

	if not finish then
		return
	end

	local elapsed_ms = math.floor((finish - current.time) * 1000 + 0.5)

	if elapsed_ms >= 0 then
		record(current.level_name, current.warm and "screen_warm_ms" or "screen_cold_ms", elapsed_ms)
	end
end

local function option_enabled(option)
	if not common.enabled() then
		return false
	end

	local value = mod:get(option)

	return value == nil and false or value and true or false
end

local function take_reference(package_name, ids)
	local package_manager = Managers.package

	if not package_manager then
		return false
	end

	-- Nothing to hold on to if the game does not have this package at all;
	-- asking for one that does not exist is how you get a hard error.
	if Application and Application.can_get_resource and not Application.can_get_resource("package", package_name) then
		return false
	end

	local ok, id = pcall(function ()
		return package_manager:load(package_name, REFERENCE_NAME)
	end)

	if ok and id then
		ids[#ids + 1] = id

		return true
	end

	return false
end

-- Both loaders report in independently and in no fixed order -- BreedLoader
-- runs synchronously from LocalLoadersState.init while LevelLoader only gets
-- here once its package has finished loading -- so whichever arrives first
-- opens the entry, and each part is guarded on its own.
local function ensure_entry(level_name)
	local settings = level_name and PINNABLE_LEVELS[level_name]

	if not settings or not option_enabled(settings.option) then
		return nil
	end

	local entry = pinned[level_name]

	if not entry then
		entry = {label = settings.label, option = settings.option, level_name = level_name, ids = {}}
		pinned[level_name] = entry
	end

	return entry
end

-- Called once the level's own package is in and its dependency list is known.
function hub_cache.pin_level(level_name, packages_to_load)
	local entry = ensure_entry(level_name)

	if not entry or entry.level_held then
		return
	end

	entry.level_held = true

	local ids = entry.ids

	take_reference(level_name, ids)

	local count = 0

	for package_name, _ in pairs(packages_to_load or {}) do
		if take_reference(package_name, ids) then
			count = count + 1
		end
	end

	entry.packages = count

	common.debug("holding %s: level package plus %d dependencies", entry.label, count)
end

-- The breed packages a level pulls in are loaded by a different loader, so
-- they are pinned separately and filed under the same level.
function hub_cache.pin_breeds(level_name, packages_to_load)
	local entry = ensure_entry(level_name)

	if not entry or entry.breeds_held then
		return
	end

	entry.breeds_held = true

	local ids = entry.ids
	local count = 0

	for package_name, _ in pairs(packages_to_load or {}) do
		if take_reference(package_name, ids) then
			count = count + 1
		end
	end

	entry.breeds = count

	common.debug("holding %s: %d breed packages", entry.label, count)
end

local function release(level_name)
	local entry = pinned[level_name]

	if not entry then
		return
	end

	local package_manager = Managers.package
	local ids = entry.ids

	if package_manager then
		for i = 1, #ids do
			pcall(function ()
				package_manager:release(ids[i])
			end)
		end
	end

	pinned[level_name] = nil

	common.debug("released %s from memory", entry.label)
end

function hub_cache.release_all()
	for level_name, _ in pairs(pinned) do
		release(level_name)
	end
end

-- A level whose option was switched off is let go of at once; one whose option
-- was switched on is picked up the next time it loads.
function hub_cache.apply_settings()
	for level_name, entry in pairs(pinned) do
		if not option_enabled(entry.option) then
			release(level_name)
		end
	end
end

local function held_state(level_name)
	local settings = PINNABLE_LEVELS[level_name]
	local entry = pinned[level_name]

	if entry then
		return string.format("holding %d packages", #entry.ids)
	elseif not option_enabled(settings.option) then
		return "off"
	end

	return "not visited yet"
end

local function seconds(milliseconds)
	return milliseconds and string.format("%.1f s", milliseconds / 1000) or "?"
end

-- The short form, one line per level: the two memory totals side by side,
-- since neither contains the other.
function hub_cache.summary_lines()
	local lines = {}

	for _, level_name in ipairs(LEVEL_ORDER) do
		local settings = PINNABLE_LEVELS[level_name]
		local figures = hub_cache.measurements(level_name)
		local size

		if figures.vram_mb and figures.ram_mb then
			size = string.format("%d MB video, %d MB system", figures.vram_mb, figures.ram_mb)
		elseif figures.vram_mb then
			size = string.format("%d MB video", figures.vram_mb)
		elseif figures.ram_mb then
			size = string.format("%d MB system", figures.ram_mb)
		else
			size = "not measured yet"
		end

		lines[#lines + 1] = string.format("%s: %s (%s)", settings.label, size, held_state(level_name))
	end

	return lines
end

-- The long form, behind the developer option: everything measured about each
-- level, including what holding it actually saves.
function hub_cache.debug_lines()
	local lines = {}

	for _, level_name in ipairs(LEVEL_ORDER) do
		local settings = PINNABLE_LEVELS[level_name]
		local figures = hub_cache.measurements(level_name)
		local entry = pinned[level_name]

		lines[#lines + 1] = string.format("%s -- %s", settings.label, held_state(level_name))
		lines[#lines + 1] = string.format("  packages held: %d", entry and #entry.ids or 0)
		lines[#lines + 1] = string.format("  system memory: %s",
			figures.ram_mb and (figures.ram_mb .. " MB") or "not measured yet")
		lines[#lines + 1] = string.format("  video memory: %s",
			figures.vram_mb and (figures.vram_mb .. " MB") or "not measured yet")
		lines[#lines + 1] = string.format("  package loading: %s cold, %s cached%s",
			seconds(figures.cold_ms), seconds(figures.warm_ms),
			figures.saved_ms and string.format(" -- %s saved", seconds(figures.saved_ms)) or "")
		lines[#lines + 1] = string.format("  whole loading screen: %s cold, %s cached%s",
			seconds(figures.screen_cold_ms), seconds(figures.screen_warm_ms),
			figures.screen_saved_ms and string.format(" -- %s saved", seconds(figures.screen_saved_ms)) or "")
	end

	local used, budget = hub_cache.vram_status()

	if used then
		lines[#lines + 1] = budget
			and string.format("video memory in use: %d of %d MB", used, budget)
			or string.format("video memory in use: %d MB", used)
	end

	return lines
end

local function level_of(context)
	if not context then
		return nil
	end

	local mission = context.mission_name and Missions[context.mission_name]

	return mission and mission.level or context.level_name
end

function hub_cache.init()
	local CLASS_TABLE = rawget(_G, "CLASS")

	local level_loader = CLASS_TABLE and CLASS_TABLE.LevelLoader
	local breed_loader = CLASS_TABLE and CLASS_TABLE.BreedLoader
	local loaders_state = CLASS_TABLE and CLASS_TABLE.LocalLoadersState
	local loading_state = CLASS_TABLE and CLASS_TABLE.StateLoading

	if not level_loader then
		mod:error("class LevelLoader was not found, level caching is disabled")
		return
	end

	-- Runs once the level package is in and _packages_to_load has been filled
	-- with its item and theme dependencies.
	mod:hook_safe(level_loader, "_level_load_done_callback", function (self)
		hub_cache.pin_level(self._level_name, self._packages_to_load)
	end)

	if breed_loader then
		-- BreedLoader works off the mission rather than the level, so the
		-- mission's level name is what files these under the right entry.
		mod:hook_safe(breed_loader, "start_loading", function (self, context)
			hub_cache.pin_breeds(level_of(context), self._packages_to_load)
		end)
	end

	-- There are two of these, and which one runs depends on the session. Going
	-- to the Mourningstar you are a client of a hub server and the transition
	-- runs through LocalLoadersState; the Psykhanium is yours alone, so it runs
	-- through HostLoadersState. Hooking only the first measured the Mourningstar
	-- and left the Psykhanium reporting nothing at all, even while its packages
	-- were being held perfectly well.
	local function hook_loaders_state(class_table, name)
		if not class_table then
			mod:error("class %s was not found, some load times will not be measured", name)

			return
		end

		-- init() releases the outgoing level and starts the incoming one, so
		-- the two readings this needs sit either side of the original call.
		mod:hook(class_table, "init", function (func, self, state_machine, shared_state)
			hub_cache.begin_phase(level_of(shared_state))

			local result = func(self, state_machine, shared_state)

			hub_cache.baseline_after_cleanup()

			return result
		end)

		mod:hook(class_table, "update", function (func, self, dt)
			hub_cache.sample_phase()

			local result = func(self, dt)

			if result == "load_done" then
				hub_cache.end_phase()
			end

			return result
		end)
	end

	hook_loaders_state(loaders_state, "LocalLoadersState")
	hook_loaders_state(CLASS_TABLE and CLASS_TABLE.HostLoadersState, "HostLoadersState")

	if loading_state then
		mod:hook_safe(loading_state, "on_enter", function ()
			hub_cache.begin_screen()
		end)

		mod:hook_safe(loading_state, "on_exit", function ()
			hub_cache.end_screen()
		end)
	end
end

return hub_cache
