local mod = get_mod("DarkCache")

local LRU = mod:io_dofile("DarkCache/scripts/mods/DarkCache/DarkCache_lru")

local common = {}
mod.common = common
common.LRU = LRU

-- ---------------------------------------------------------------------------
-- Channels
--
-- The game builds one renderer per icon family in UIManager and keeps them in
-- Managers.ui._back_buffer_render_handlers under fixed keys:
--
--   portraits   PortraitUI    player portraits (social, lobby, HUD)
--   cosmetics   PortraitUI    every worn cosmetic, rendered on a mannequin
--   weapons     WeaponIconUI  melee / ranged / gadgets
--   weapon_skin WeaponIconUI  weapon skins and trinkets
--   companion   WeaponIconUI  companion gear
--
-- Those keys are the channel names used throughout: they say what an instance
-- renders, they decide whether caching applies, and they group the statistics.
-- An instance that is NOT in that table (ViewElementWeaponActions and
-- EndPlayerView each spin up their own short-lived WeaponIconUI) is left alone
-- -- it dies with the view it belongs to, so caching for it would only pin
-- atlas slots that are about to be thrown away.
-- ---------------------------------------------------------------------------

local CHANNEL_OPTIONS = {
	portraits   = {enabled = "opt_cache_portraits"},
	cosmetics   = {enabled = "opt_cache_cosmetics"},
	weapons     = {enabled = "opt_cache_weapons"},
	weapon_skin = {enabled = "opt_cache_weapons"},
	companion   = {enabled = "opt_cache_weapons"},
}

common.CHANNEL_OPTIONS = CHANNEL_OPTIONS
common.CHANNEL_ORDER = {"cosmetics", "weapons", "weapon_skin", "companion", "portraits"}

-- ---------------------------------------------------------------------------
-- What an entry really costs, and the size ceiling
--
-- An icon is not stored on its own: the engine allocates a texture atlas of
-- ATLAS_COLUMNS x ATLAS_ROWS slots at once and hands out one slot, and it only
-- destroys that atlas once every one of its slots is free. So the memory a
-- cached icon pins is a whole atlas sized five times its slot in each
-- direction, however few slots are actually used.
--
-- That is why the budget below is counted in bytes rather than in icons: the
-- slot size is not a constant. The grids this mod exists for are small, but a
-- few views ask for enormous single icons through the very same renderers:
--
--    128x128    cosmetics / companion / appearance grids   atlas   1.6 MB
--    256x128    weapon grids                               atlas   3.3 MB
--    128x192    character creation grid                    atlas   2.4 MB
--    1024x1024  win-track reward overlay                   atlas   104 MB
--    1400x1400  character options portrait                 atlas   196 MB
--
-- Those last two are refused outright. Not out of caution about memory, but
-- because they are worthless to cache and ruinous to the budget: they appear
-- one at a time in views opened once, and a single one of them would eat the
-- whole allowance and evict every icon that was actually earning its place.
-- ---------------------------------------------------------------------------

local ATLAS_COLUMNS = 5
local ATLAS_ROWS = 5
local ATLAS_SLOTS = ATLAS_COLUMNS * ATLAS_ROWS
local BYTES_PER_PIXEL = 4 -- R8G8B8A8

-- 256 is deliberate: exactly the widest grid format (weapons, 256x128).
local MAX_SLOT_EDGE = 256

common.MAX_SLOT_EDGE = MAX_SLOT_EDGE

function common.size_is_cacheable(size)
	if not size then
		return false
	end

	local width, height = size[1], size[2]

	if type(width) ~= "number" or type(height) ~= "number" then
		return false
	end

	return width <= MAX_SLOT_EDGE and height <= MAX_SLOT_EDGE
end

local function atlas_bytes(count, width, height)
	return math.ceil(count / ATLAS_SLOTS) * (width * ATLAS_COLUMNS) * (height * ATLAS_ROWS) * BYTES_PER_PIXEL
end

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------

local DEFAULT_BUDGET_MB = 256

local function get(setting_id, fallback)
	local value = mod:get(setting_id)
	if value == nil then
		return fallback
	end
	return value
end

function common.enabled()
	return get("opt_enabled", true) and true or false
end

function common.channel_enabled(channel)
	if not common.enabled() then
		return false
	end

	local options = CHANNEL_OPTIONS[channel]
	if not options then
		return false
	end

	return get(options.enabled, true) and true or false
end

function common.budget_bytes()
	local megabytes = tonumber(get("opt_memory_budget", DEFAULT_BUDGET_MB)) or DEFAULT_BUDGET_MB

	return math.max(0, math.floor(megabytes)) * 1024 * 1024
end

-- nil means "leave the engine's own settling delay alone".
function common.frame_delay()
	local value = tonumber(get("opt_capture_frame_delay", 5))
	if not value or value == 5 then
		return nil
	end

	return math.max(1, math.floor(value))
end

function common.debug_enabled()
	return get("opt_debug", false) and true or false
end

function common.debug(format, ...)
	if common.debug_enabled() then
		mod:info(format, ...)
	end
end

-- ---------------------------------------------------------------------------
-- Statistics
-- ---------------------------------------------------------------------------

local function new_stats()
	return {hits = 0, misses = 0, stored = 0, evicted = 0, invalidated = 0, oversized = 0}
end

common.stats = {}

for channel, _ in pairs(CHANNEL_OPTIONS) do
	common.stats[channel] = new_stats()
end

function common.bump(channel, field)
	local stats = common.stats[channel]
	if stats and stats[field] then
		stats[field] = stats[field] + 1
	end
end

function common.reset_stats()
	for channel, _ in pairs(common.stats) do
		common.stats[channel] = new_stats()
	end
end

-- ---------------------------------------------------------------------------
-- Per-instance identity
--
-- Weak-keyed, so a renderer the game throws away takes its bookkeeping with
-- it. `false` is memoised for instances we deliberately do not cache, so the
-- lookup stays a single table read after the first call.
-- ---------------------------------------------------------------------------

local states = setmetatable({}, {__mode = "k"})
common.states = states

local function channel_of(instance)
	local ui_manager = Managers.ui
	local handlers = ui_manager and ui_manager._back_buffer_render_handlers

	if not handlers then
		return nil, false -- UIManager not ready yet: no answer, do not memoise
	end

	for name, handler_instance in pairs(handlers) do
		if handler_instance == instance then
			return name, true
		end
	end

	return nil, true
end

function common.state_for(instance, release)
	local state = states[instance]

	if state ~= nil then
		if state == false then
			return nil
		end
		return state
	end

	local channel, conclusive = channel_of(instance)

	if not channel then
		if conclusive then
			states[instance] = false
		end
		return nil
	end

	state = {channel = channel, release = release}
	states[instance] = state

	return state
end

function common.forget(instance)
	states[instance] = nil
end

-- ---------------------------------------------------------------------------
-- The cache itself
--
-- One list for every renderer rather than one per channel, because the budget
-- is one number: whatever was looked at longest ago goes first, wherever it
-- came from. A cosmetic you stopped scrolling past two vendors ago should lose
-- its slot to the weapon you are looking at now.
--
-- Bytes are tracked per distinct slot size, since that is the granularity at
-- which atlases are allocated. Recomputing the total is a loop over the two or
-- three sizes in play, so it can happen on every insertion without thought.
-- ---------------------------------------------------------------------------

local cache = LRU.new()
local size_groups = {}

common.cache = cache

local function recount()
	local total = 0

	for _, group in pairs(size_groups) do
		if group.count > 0 then
			total = total + atlas_bytes(group.count, group.width, group.height)
		end
	end

	common.bytes = total
end

common.bytes = 0

local function add_to_group(size_key, width, height)
	local group = size_groups[size_key]

	if not group then
		group = {count = 0, width = width, height = height}
		size_groups[size_key] = group
	end

	group.count = group.count + 1
end

local function remove_from_group(size_key)
	local group = size_groups[size_key]

	if group then
		group.count = group.count - 1

		if group.count <= 0 then
			size_groups[size_key] = nil
		end
	end
end

function common.contains(request)
	return cache:contains(request)
end

-- Take an entry back out of the cache without releasing it: it is being used
-- again, or the game has told us it is stale and the caller will release it.
function common.detach(request)
	local entry = cache:remove(request)

	if entry then
		remove_from_group(entry.size_key)
		recount()
	end

	return entry
end

local function release_entry(request, entry)
	entry.release(entry.instance, request, entry.size_key)
end

function common.retain(instance, request, size_key, size, channel, release)
	cache:push(request, {
		instance = instance,
		size_key = size_key,
		width = size[1],
		height = size[2],
		channel = channel,
		release = release,
	})

	add_to_group(size_key, size[1], size[2])
	recount()

	common.bump(channel, "stored")
	common.enforce_budget()
end

-- Drop the oldest entries until the cache fits its memory allowance.
function common.enforce_budget()
	local budget = common.budget_bytes()

	while common.bytes > budget and cache.count > 0 do
		local request, entry = cache:pop_oldest()

		if not request then
			break
		end

		remove_from_group(entry.size_key)
		recount()
		release_entry(request, entry)
		common.bump(entry.channel, "evicted")
	end
end

-- Empty the cache, or only the part of it belonging to one renderer.
function common.flush(optional_instance)
	local released = 0

	if optional_instance then
		local keys = cache:keys()

		for i = 1, #keys do
			local request = keys[i]
			local entry = cache:remove(request)

			if entry then
				if entry.instance == optional_instance then
					remove_from_group(entry.size_key)
					release_entry(request, entry)
					released = released + 1
				else
					cache:push(request, entry) -- not ours: put it back
				end
			end
		end

		recount()

		return released
	end

	while cache.count > 0 do
		local request, entry = cache:pop_oldest()

		if not request then
			break
		end

		remove_from_group(entry.size_key)
		release_entry(request, entry)
		released = released + 1
	end

	recount()

	return released
end

-- Re-apply the settings: a family switched off loses its entries, and the
-- budget is enforced in case it came down.
function common.apply_settings()
	local keys = cache:keys()

	for i = 1, #keys do
		local request = keys[i]
		local entry = cache:remove(request)

		if entry then
			if common.channel_enabled(entry.channel) then
				cache:push(request, entry)
			else
				remove_from_group(entry.size_key)
				release_entry(request, entry)
			end
		end
	end

	recount()
	common.enforce_budget()
end

-- ---------------------------------------------------------------------------
-- Report
-- ---------------------------------------------------------------------------

-- The channels are an engine detail; nobody reading a chat line cares that
-- weapon skins render through a different instance than weapons. So the report
-- groups them the way a player thinks about them.
local REPORT_GROUPS = {
	{label = "cosmetics", channels = {"cosmetics"}},
	{label = "weapons", channels = {"weapons", "weapon_skin"}},
	{label = "portraits and companion", channels = {"portraits", "companion"}},
}

-- Bytes currently held, per channel, atlas granularity included.
local function bytes_by_channel()
	local groups_by_channel = {}
	local keys = cache:keys()

	for i = 1, #keys do
		local entry = cache:value(keys[i])

		if entry then
			local groups = groups_by_channel[entry.channel] or {}
			groups_by_channel[entry.channel] = groups

			local group = groups[entry.size_key]

			if not group then
				group = {count = 0, width = entry.width, height = entry.height}
				groups[entry.size_key] = group
			end

			group.count = group.count + 1
		end
	end

	local bytes = {}

	for channel, groups in pairs(groups_by_channel) do
		local total = 0

		for _, group in pairs(groups) do
			total = total + atlas_bytes(group.count, group.width, group.height)
		end

		bytes[channel] = total
	end

	return bytes
end

-- Short form for /darkcache: what each thing is costing, and nothing else.
function common.report()
	local bytes = bytes_by_channel()
	local lines = {}

	for _, group in ipairs(REPORT_GROUPS) do
		local total = 0
		local enabled = false

		for _, channel in ipairs(group.channels) do
			total = total + (bytes[channel] or 0)

			if common.channel_enabled(channel) then
				enabled = true
			end
		end

		lines[#lines + 1] = enabled
			and string.format("%s: %.1f MB", group.label, total / (1024 * 1024))
			or string.format("%s: off", group.label)
	end

	return lines
end

-- Long form for the developer command: per channel, with the hit rates that
-- say whether the allowance is doing any good.
function common.debug_report()
	local bytes = bytes_by_channel()
	local lines = {}

	for _, channel in ipairs(common.CHANNEL_ORDER) do
		local stats = common.stats[channel]
		local lookups = stats.hits + stats.misses
		local hit_rate = lookups > 0 and stats.hits / lookups * 100 or 0
		local count = 0

		local keys = cache:keys()

		for i = 1, #keys do
			local entry = cache:value(keys[i])

			if entry and entry.channel == channel then
				count = count + 1
			end
		end

		local suffix = ""

		if not common.channel_enabled(channel) then
			suffix = " [off]"
		elseif stats.oversized > 0 then
			suffix = string.format(" [%d refused as too large]", stats.oversized)
		end

		lines[#lines + 1] = string.format(
			"  %-12s %4d icons %6.1f MB  hit %3d%% (%d of %d)  evicted %d  invalidated %d%s",
			channel, count, (bytes[channel] or 0) / (1024 * 1024),
			hit_rate, stats.hits, lookups, stats.evicted, stats.invalidated, suffix
		)
	end

	lines[#lines + 1] = string.format(
		"  total %.1f MB of %d MB allowed, %d icons cached",
		common.bytes / (1024 * 1024), common.budget_bytes() / (1024 * 1024), cache.count
	)

	return lines
end

return common
