local mod = get_mod("DarkCache")

mod.version = "2.0.0"

-- ---------------------------------------------------------------------------
-- DarkCache
--
-- Darktide rebuilds the same pictures over and over. This mod keeps them for
-- as long as they are worth keeping, in two unrelated places:
--
--   DarkCache_render_cache  the item icons the game renders one at a time in
--                           a hidden world -- cosmetics, weapons, skins,
--                           trinkets, companion gear, player portraits. Kept
--                           for the length of a stay in the Mourningstar.
--
--   DarkCache_hub_cache     the Mourningstar's own level and its dependency
--                           packages, which the engine releases in full every
--                           time you leave and re-reads from disk every time
--                           you come back.
--
-- Each file explains, at its top, what the engine does and what is changed
-- about it.
-- ---------------------------------------------------------------------------

local common = mod:io_dofile("DarkCache/scripts/mods/DarkCache/DarkCache_common")
local render_cache = mod:io_dofile("DarkCache/scripts/mods/DarkCache/DarkCache_render_cache")
local hub_cache = mod:io_dofile("DarkCache/scripts/mods/DarkCache/DarkCache_hub_cache")
local menu = mod:io_dofile("DarkCache/scripts/mods/DarkCache/DarkCache_menu")

-- ---------------------------------------------------------------------------
-- Settings migration
--
-- DMF persists an option's value the first time it initialises the mod, so
-- changing a default in DarkCache_data.lua does nothing at all for someone who
-- already has the old value saved. Every change to what is held by default
-- gets a version here and is pushed to existing installs.
--
--   2  first memory pass: smaller budgets, cache emptied on mission start.
--   3  smaller budgets again, resource-package cache off by default.
--   4  budgets counted in icons replaced by a single memory allowance, the
--      resource-package cache dropped entirely, and the cache now emptied on
--      every level transition rather than only on mission start.
--   5  clears the stored level sizes: they were being overwritten on every
--      later visit, when the level was already held and so cost nothing to
--      "load". They are measured again, once, on a real load.
--   6  the Psykhanium was pointing at the Horde mode level rather than the
--      training grounds, so it was never cached; sizes cleared again, and
--      video memory is now measured alongside system memory.
--   7  system and video memory were being reported as a whole and its part
--      when they are two independent totals; measurements are re-keyed and
--      load times are recorded alongside them.
--   8  load times were only covering LevelLoader, a fraction of the work; they
--      now cover the whole package phase and the whole loading screen, and the
--      memory cost is taken from the lowest reading of the phase rather than
--      its first, which a teardown could put above the end.
--   9  the Psykhanium loads through HostLoadersState rather than
--      LocalLoadersState, so nothing about it was ever measured. Measurements
--      are no longer wiped by a version bump either -- they take a session to
--      gather and the menu is built from them.
-- ---------------------------------------------------------------------------

local SETTINGS_VERSION = 9

-- Deliberately NOT listed here: anything the mod measured. Those figures are
-- what the options menu and the reports are built from, they take a session to
-- gather, and a version bump is no reason to throw them away. They are only
-- ever cleared when what they mean actually changes, and then explicitly.
local MIGRATED_DEFAULTS = {
	opt_enabled = true,
	opt_memory_budget = 256,
	opt_cache_cosmetics = true,
	opt_cache_weapons = true,
	opt_cache_portraits = true,
}

local stored_version = mod:get("opt_settings_version") or 1

if stored_version < SETTINGS_VERSION then
	for setting_id, value in pairs(MIGRATED_DEFAULTS) do
		mod:set(setting_id, value)
	end

	mod:set("opt_settings_version", SETTINGS_VERSION)
end

render_cache.init()
hub_cache.init()
menu.refresh()

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

-- Named on the mod table so the keybind option can call it by name. DMF hands
-- such a keybind its pressed state as the first argument, so this takes none.
mod.clear_cache = function ()
	local released = common.flush()

	mod:echo(mod:localize("i18n_cache_cleared", released))

	return released
end

-- DMF runs every echo through string.format, so a line carrying a literal '%'
-- -- which every hit-rate line does -- has to go through as an argument rather
-- than as the format string itself.
local function echo_lines(lines)
	for i = 1, #lines do
		mod:echo("%s", lines[i])
	end
end

mod.print_stats = function ()
	mod:echo(mod:localize("i18n_stats_header"))
	echo_lines(common.report())
	echo_lines(hub_cache.summary_lines())
end

mod.print_debug_stats = function ()
	mod:echo(mod:localize("i18n_debug_header"))
	echo_lines(common.debug_report())
	echo_lines(hub_cache.debug_lines())
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

mod.on_disabled = function (initial_call)
	-- Once the hooks stop running nothing would ever hand the retained atlas
	-- slots and packages back, so let go of everything now.
	if not initial_call then
		common.flush()
		hub_cache.release_all()
	end
end

mod.on_unload = function ()
	common.flush()
	hub_cache.release_all()
end

-- Every level transition empties the icon cache.
--
-- An icon cache is worth something for exactly as long as you stay in one
-- place: opening the same vendor three times in a visit to the Mourningstar,
-- switching tabs, scrolling back up. Crossing a loading screen ends that --
-- and a reload of the Mourningstar itself, after changing character, may well
-- mean different icons entirely. So the cache lives for one stay, and is
-- handed back whole at the door.
--
-- The Mourningstar package cache is the opposite and is deliberately NOT
-- touched here: its whole point is to survive the transition.
mod.on_game_state_changed = function (status, state_name)
	if status ~= "enter" or state_name ~= "GameplayStateRun" then
		return
	end

	local released = common.flush()

	if released > 0 then
		common.debug("released %d cached icons on entering a level", released)
	end
end

-- ---------------------------------------------------------------------------
-- Chat commands
-- ---------------------------------------------------------------------------

mod:command("darkcache", mod:localize("i18n_command_stats"), function ()
	mod.print_stats()
end)

mod:command("darkcache_clear", mod:localize("i18n_command_clear"), function ()
	mod.clear_cache()
end)

mod:command("debugdarkcache", mod:localize("i18n_command_debug"), function ()
	mod.print_debug_stats()
end)

-- The developer option owns this command: with it off the command is not
-- offered at all rather than merely printing nothing.
local function update_debug_command()
	if mod:get("opt_debug") then
		mod:command_enable("debugdarkcache")
	else
		mod:command_disable("debugdarkcache")
	end
end

update_debug_command()

mod.on_setting_changed = function (setting_id)
	common.apply_settings()
	hub_cache.apply_settings()
	update_debug_command()
	menu.refresh()
end
