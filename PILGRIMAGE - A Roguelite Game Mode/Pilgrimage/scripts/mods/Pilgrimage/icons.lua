-- icons.lua
--
-- Makes the Mortis Trials buff icons actually draw.
--
-- ---------------------------------------------------------------------------
-- The problem
-- ---------------------------------------------------------------------------
--
-- Every boon we hand out already knows its own icon. HordesBuffsData carries a real
-- path per buff, for example
--
--     content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_zealot_...
--
-- and the game's own tactical overlay reads exactly that field
-- (hud_element_tactical_overlay.lua:366-380). So the data is correct, the lookup is
-- correct, and the icon still comes out as a hexagon with a question mark in it.
--
-- The question mark is not our fallback and it is not the game's Lua fallback either.
-- It is the ENGINE's substitute for a texture resource that is not currently resident.
-- Nothing in the whole UI layer ever checks whether a texture is loaded before binding
-- it: ui_passes.lua:44-49 goes straight to Material.set_texture with whatever string it
-- was given, and an unresident name silently becomes the placeholder. No Lua error, no
-- warning, nothing to catch.
--
-- Why are they not resident? Because Darktide streams UI art in packages, and the
-- per-buff horde icons ship in a package that only loads when the Mortis Trials UI is
-- open. The frame around the icon (hex_frame_horde) IS resident, which is why we get a
-- correctly drawn hexagon with nothing inside it. That is the exact signature of "frame
-- loaded, icon not loaded".
--
-- ---------------------------------------------------------------------------
-- The fix
-- ---------------------------------------------------------------------------
--
-- Ask the package manager to load the package ourselves, and keep it loaded.
--
-- This is much better than shipping our own PNGs through an asset-loader mod. The art
-- is already on the player's disk, it is the real Fatshark icon for that exact buff, it
-- costs no download, it needs no second mod installed, and it cannot drift out of sync
-- when Fatshark adds or renames a buff.
--
-- We do not know which package holds them with certainty, because the decompiled source
-- has no package manifests, only the names that Lua passes to the package manager. So
-- this module takes the three candidates that could plausibly contain horde buff art and
-- loads whichever ones actually exist. Loading a package that turns out not to contain
-- them is harmless, and loading one that is already loaded is a refcount bump.
--
-- Every step is guarded, because a package name that does not exist on this install is
-- an engine-level assert, not a Lua error, and would take the game down.
-- ---------------------------------------------------------------------------

local M = {}

local _mod
local _shared

-- Ordered by how likely each is to hold the per-buff icons.
--
--   horde_play_view      the Mortis Trials front end, which draws these icons at full
--                        size on its own cards. Best candidate by far.
--   mission_buffs        the boon draft overlay, a constant element, so probably already
--                        resident. Cheap to confirm.
--   tactical_overlay     the Tab screen itself. It draws the icons but very likely does
--                        not own them, or they would already work.
--   player_buffs         the small buff strip. Named in hud_elements_player.lua and it is
--                        the other place buff art is drawn.
local CANDIDATES = {
	"packages/ui/views/horde_play_view/horde_play_view",
	"packages/ui/constant_elements/mission_buffs/mission_buffs",
	"packages/ui/hud/tactical_overlay/tactical_overlay",
	"packages/ui/hud/player_buffs/player_buffs",
}

-- Textures we know are already on screen and therefore certainly resident. If the probe
-- says these are missing too, the probe itself is lying and its answers about the buff
-- icons mean nothing. A diagnostic without a control is just a second guess.
M.CONTROL_TEXTURES = {
	"content/ui/textures/frames/horde/hex_frame_horde",
	"content/ui/textures/placeholder_texture",
}

local REFERENCE_NAME = "Pilgrimage"

-- package name -> load id, or the string "already" when it was resident before we
-- touched it. We only release ids we created ourselves.
local _loaded = {}
local _state = {}
local _attempted = false

function M.init(deps)
	_mod = deps.mod
	_shared = deps.shared
end

local function _package_manager()
	local managers = rawget(_G, "Managers")
	local pm = managers and managers.package
	if type(pm) ~= "table" then return nil end
	if type(pm.load) ~= "function" then return nil end
	return pm
end

-- Application.can_get_resource is the same existence probe the game uses before touching
-- weapon packages (weapon_template_resource_dependencies.lua:102). Without it, a name
-- that is not on this install asserts inside the engine.
local function _package_exists(name)
	local app = rawget(_G, "Application")
	if not (app and type(app.can_get_resource) == "function") then
		-- No probe available. Treat as "do not touch", because guessing wrong here is
		-- a crash rather than a missing icon.
		return nil
	end

	local ok, result = pcall(app.can_get_resource, "package", name)
	if not ok then return nil end
	return result == true
end

local function _has_loaded(pm, name)
	if type(pm.has_loaded) ~= "function" then return nil end
	local ok, result = pcall(pm.has_loaded, pm, name)
	if not ok then return nil end
	return result == true
end

-- ---------------------------------------------------------------------------
-- Loading
-- ---------------------------------------------------------------------------

-- Idempotent. Safe to call every time we enter the hub or a mission; after the first
-- successful pass it does nothing.
--
-- force re-runs the whole thing, which is what the debug command uses.
function M.ensure(force)
	if _attempted and not force then return _state end

	_state = {}

	local pm = _package_manager()
	if not pm then
		-- Deliberately NOT marking this as attempted. The package manager does not
		-- exist yet at mod load, so the first few calls are expected to land here and
		-- the retry has to stay open.
		_state.error = "no package manager"
		return _state
	end

	_attempted = true

	for i = 1, #CANDIDATES do
		local name = CANDIDATES[i]
		local entry = { name = name }

		local exists = _package_exists(name)
		entry.exists = exists

		if exists == false then
			entry.result = "absent"
		elseif exists == nil then
			entry.result = "unprobeable"
		elseif _loaded[name] then
			entry.result = "ours"
		elseif _has_loaded(pm, name) then
			-- Someone else already holds it. Record that, and specifically do NOT take
			-- our own reference: we would then be holding a package the game may want
			-- to unload, for no benefit.
			_loaded[name] = "already"
			entry.result = "already loaded"
		else
			-- The third argument is a completion callback and the fourth prioritises the
			-- load. We pass no callback because we do not need to know when it finishes:
			-- the icons simply start drawing on the frame the package lands, and a widget
			-- that drew a placeholder for two seconds is not worth the bookkeeping.
			local ok, id = pcall(pm.load, pm, name, REFERENCE_NAME, nil, true)

			if ok and id then
				_loaded[name] = id
				entry.result = "loaded"
				entry.id = tostring(id)
			else
				entry.result = "load failed"
				entry.error = tostring(id)
			end
		end

		_state[#_state + 1] = entry
	end

	return _state
end

-- Only releases references we created. A package that was already resident when we
-- looked is left alone.
function M.release()
	local pm = _package_manager()
	if not pm or type(pm.release) ~= "function" then
		_loaded = {}
		return 0
	end

	local count = 0
	for name, id in pairs(_loaded) do
		if id ~= "already" then
			pcall(pm.release, pm, id)
			count = count + 1
		end
		_loaded[name] = nil
	end

	_attempted = false
	return count
end

-- ---------------------------------------------------------------------------
-- Reporting
-- ---------------------------------------------------------------------------

function M.status()
	return {
		attempted = _attempted,
		entries   = _state,
	}
end

-- ---------------------------------------------------------------------------
-- Custom icons through SimpleAssets
--
-- The diagnostic run on 2026-08-05 settled the question: the probe works (the control
-- textures read resident), all four candidate packages were loaded, and every one of
-- the 84 buff icon textures still read missing. The art lives in a bundle no Lua ever
-- names, almost certainly the Mortis Trials level bundle itself, and a mod cannot
-- request a bundle it cannot name. The shipped icons are unreachable, full stop.
--
-- So we bring our own. Twelve category icons drawn for this mod, shipped as PNGs in
-- Pilgrimage/assets/icons, loaded through Kaizen's installed SimpleAssets mod, which
-- registers each file under a url the engine's resource system can resolve. That url
-- goes into the same material_values.icon slot the real path would have used, so the
-- draft cards need no changes at all.
--
-- Category art rather than 138 exact icons, because 138 hand-drawn icons is a project
-- and 12 recognisable glyphs is an afternoon. The buff name tells us the theme.
-- ---------------------------------------------------------------------------

-- Keyword -> category, FIRST match wins, so order carries meaning. grenade before
-- fire, because gas grenade buffs mention both and the grenade is the subject.
local CATEGORY_RULES = {
	{ "grenade",   "grenade" },
	{ "fire",      "fire" }, { "burn", "fire" }, { "flame", "fire" },
	{ "shock",     "electric" }, { "electr", "electric" }, { "lightning", "electric" },
	{ "crit",      "crit" },
	{ "toughness", "shield" }, { "block", "shield" },
	{ "health",    "health" }, { "heal", "health" }, { "corruption", "health" }, { "wound", "health" },
	{ "coherency", "coherency" },
	{ "ammo",      "ranged" }, { "clip", "ranged" }, { "reload", "ranged" },
	{ "ranged",    "ranged" }, { "shot", "ranged" },
	{ "melee",     "melee" }, { "cleave", "melee" }, { "bash", "melee" },
	{ "ability",   "ability" }, { "cooldown", "ability" }, { "channel", "ability" },
	{ "movement",  "speed" }, { "speed", "speed" }, { "dodge", "speed" },
	{ "stamina",   "speed" }, { "sprint", "speed" },
}

-- The family buffs name a theme rather than containing keywords.
local FAMILY_CATEGORY = {
	hordes_family_fire         = "fire",
	hordes_family_electric     = "electric",
	hordes_family_elementalist = "fire",
	hordes_family_cowboy       = "ranged",
	hordes_family_critical     = "crit",
}

-- Family ids used by mission_buffs_allowed_buffs.lua and Pilgrimage's own
-- family catalogue. These select the bundled glyph drawn directly by the
-- draft UI when Mortis texture packages are absent after a restart.
local FAMILY_CUSTOM_CATEGORY = {
	fire = "fire",
	electric = "electric",
	elementalist = "fire",
	unkillable = "shield",
	cowboy = "ranged",
	critical = "crit",
	unstoppable = "melee",
}

-- Hordes-card artwork that has already rendered successfully in ordinary
-- Pilgrimage missions. These are the same visual set used by the Wave A boons,
-- including Long Burn. Unlike CATEGORY_TEXTURES below, these are proper
-- Hordes-style boon glyphs rather than generic status-effect symbols.
local HORDES_ICON_BASE = "content/ui/textures/icons/buffs/hud/horde_buffs/"
local FAMILY_STYLED_TEXTURES = {
	fire = HORDES_ICON_BASE .. "small_buffs/hordes_buff_burning_on_melee_hit",
	electric = HORDES_ICON_BASE .. "big_buffs/hordes_buff_extra_ability_charge",
	elementalist = HORDES_ICON_BASE .. "small_buffs/hordes_buff_burning_on_melee_hit",
	unkillable = HORDES_ICON_BASE .. "big_buffs/hordes_buff_big_toughness_increase",
	cowboy = HORDES_ICON_BASE .. "small_buffs/hordes_buff_damage_taken_by_flamers_and_grenadier_reduced",
	critical = HORDES_ICON_BASE .. "big_buffs/hordes_buff_big_weakspot_damage_increase",
	unstoppable = HORDES_ICON_BASE .. "big_buffs/hordes_buff_big_weakspot_damage_increase",
}

M.CATEGORIES = { "ability", "coherency", "crit", "electric", "fire", "generic",
	"grenade", "health", "melee", "ranged", "shield", "speed" }

function M.category_for(buff_name)
	if type(buff_name) ~= "string" then return "generic" end

	local family = FAMILY_CATEGORY[buff_name]
	if family then return family end

	for i = 1, #CATEGORY_RULES do
		if buff_name:find(CATEGORY_RULES[i][1], 1, true) then
			return CATEGORY_RULES[i][2]
		end
	end

	return "generic"
end

-- category -> { url, texture }, filled in as SimpleAssets loads each file.
--
-- The TEXTURE is the part that matters, and v0.13.1 got this wrong. SimpleAssets
-- rides Managers.url_loader (the same machinery that fetches player portraits and
-- news images), and what comes back is a texture OBJECT plus a url string that only
-- the url loader itself understands. Render passes bind bundle textures by NAME;
-- handing them the url string draws nothing, silently. The game's own pattern for
-- url-loaded art is to assign the object into a material slot (news_view.lua:371,
-- "style.texture.material_values.texture = data.texture"), so that is what we do.
local _custom = {}
local _custom_requested = false
local _custom_status = "not requested"

local function _simple_assets()
	local ok, sa = pcall(get_mod, "SimpleAssets")
	if not ok or type(sa) ~= "table" then return nil end
	if type(sa.load_texture) ~= "function" then return nil end
	return sa
end

-- Called from the icons tick, which starts well after all mods are loaded, so
-- get_mod("SimpleAssets") is meaningful by the time we ask.
function M.ensure_custom()
	if _custom_requested then return end

	local sa = _simple_assets()
	if not sa then
		_custom_status = "SimpleAssets not installed"
		return
	end

	_custom_requested = true
	_custom_status = "loading"

	for i = 1, #M.CATEGORIES do
		local category = M.CATEGORIES[i]
		-- The mods/ prefix resolves from Darktide's mods directory, which sidesteps
		-- any question of which mod SimpleAssets thinks is calling.
		local path = "mods/Pilgrimage/assets/icons/" .. category .. ".png"

		local ok, promise = pcall(sa.load_texture, path)
		if ok and promise and promise.next then
			promise:next(function(data)
				if data and data.is_ok and data.texture then
					_custom[category] = { url = data.url, texture = data.texture }
					_custom_status = "loaded"
				end
			end)
		end
	end
end

-- Declared here because custom_status reports on it; filled by patch_templates below.
local _patched = {}          -- template name -> original hud_icon string

-- ---------------------------------------------------------------------------
-- Category stand-ins from the game's own art
--
-- The v0.14.0 lesson: the terminal's circumstance icons draw perfectly, and the
-- SimpleAssets textures never did, because the render pipeline binds art BY NAME
-- from resident resources. The circumstance icons are resident names; a
-- url-loaded texture object has no name and, evidently, the buff materials do
-- not accept the object either. So the icons that CAN draw are the game's own.
--
-- These are class-independent status and stimm icon textures: they draw on every
-- player's HUD when someone burns, dodges or slams a stimm, so they ship with
-- the base HUD package rather than with any archetype. Per category, a chain of
-- candidates; the first one whose residency probes TRUE wins. Not thematically
-- perfect, but the user's words: "they need to be there as a preview only".
-- ---------------------------------------------------------------------------

local HUD_ICON_BASE = "content/ui/textures/icons/buffs/hud/"

local CATEGORY_TEXTURES = {
	ability   = { HUD_ICON_BASE .. "syringe_ability_buff_hud",
	              HUD_ICON_BASE .. "states_grace_time_hud" },
	coherency = { HUD_ICON_BASE .. "states_coherence_buff_hud",
	              HUD_ICON_BASE .. "states_grace_time_hud" },
	crit      = { HUD_ICON_BASE .. "syringe_power_buff_hud",
	              HUD_ICON_BASE .. "states_electric_buff_hud" },
	electric  = { HUD_ICON_BASE .. "states_electric_buff_hud",
	              HUD_ICON_BASE .. "states_green_fire_buff_hud" },
	fire      = { HUD_ICON_BASE .. "states_fire_buff_hud",
	              HUD_ICON_BASE .. "states_green_fire_buff_hud" },
	generic   = { HUD_ICON_BASE .. "live_event_buffs",
	              HUD_ICON_BASE .. "states_dodge_buff_hud",
	              HUD_ICON_BASE .. "states_grace_time_hud" },
	-- Grenade art only exists as class talent icons; the krak grenade is tried
	-- first because the Veteran package is the most commonly loaded, then a
	-- generic explosion-adjacent fallback.
	grenade   = { "content/ui/textures/icons/talents/veteran/veteran_blitz_krak_grenade",
	              HUD_ICON_BASE .. "states_fire_buff_hud" },
	health    = { HUD_ICON_BASE .. "syringe_corruption_buff_hud",
	              HUD_ICON_BASE .. "states_nurgle_eaten_buff_hud" },
	melee     = { HUD_ICON_BASE .. "syringe_power_buff_hud",
	              HUD_ICON_BASE .. "states_dodge_buff_hud" },
	ranged    = { HUD_ICON_BASE .. "syringe_speed_buff_hud",
	              HUD_ICON_BASE .. "states_plasma_reduced_toughness" },
	shield    = { HUD_ICON_BASE .. "states_grace_time_hud",
	              HUD_ICON_BASE .. "states_coherence_buff_hud" },
	speed     = { HUD_ICON_BASE .. "states_sprint_buff_hud",
	              HUD_ICON_BASE .. "syringe_speed_buff_hud" },
}

-- category -> resolved resident texture path. Positive results are cached; a
-- category that resolved to nothing is re-probed on the next ask, because
-- residency changes as packages load (hub vs mission).
local _resolved = {}

function M.resolve_category_texture(category)
	local cached = _resolved[category]
	if cached then return cached end

	local candidates = CATEGORY_TEXTURES[category]
	if not candidates then return nil end

	for i = 1, #candidates do
		if M.texture_resident(candidates[i]) == true then
			_resolved[category] = candidates[i]
			return candidates[i]
		end
	end

	return nil
end

function M.family_styled_icon(family_key)
	return FAMILY_STYLED_TEXTURES[family_key]
end

-- Returns a SimpleAssets texture object rather than a resource-path string.
-- The route view feeds it to a plain `texture_map` pass, which is the same
-- supported path used by SimpleAssets' own demo and avoids the Hordes icon
-- material silently substituting its warning glyph.
function M.custom_icon_for(buff_name, family_key)
	local category = FAMILY_CUSTOM_CATEGORY[family_key] or M.category_for(buff_name)
	local entry = _custom[category]
	return entry and entry.texture or nil
end

-- What a view should draw for this buff: a resident game texture PATH when one
-- resolves (this is the path that provably draws), otherwise the SimpleAssets
-- texture object as a long shot, otherwise nil.
function M.icon_override(buff_name)
	local category = M.category_for(buff_name)

	local resolved = M.resolve_category_texture(category)
	if resolved then return resolved end

	local entry = _custom[category]
	return entry and entry.texture or nil
end

function M.custom_status()
	local count = 0
	for _ in pairs(_custom) do count = count + 1 end
	local patched = 0
	for _ in pairs(_patched) do patched = patched + 1 end
	local resolved = 0
	for i = 1, #M.CATEGORIES do
		if M.resolve_category_texture(M.CATEGORIES[i]) then resolved = resolved + 1 end
	end
	return {
		status = _custom_status,
		loaded = count,
		total = #M.CATEGORIES,
		patched = patched,
		resolved = resolved,
	}
end

-- ---------------------------------------------------------------------------
-- Patching the game's own buff templates
--
-- Our draft cards go through boons.info, so they can be fixed in our own code. But
-- the in-mission buff stack and the tactical overlay are the GAME's elements: they
-- read template.hud_icon straight off the BuffTemplate (buff.lua:969, get_hud_data)
-- and assign whatever they find into a material slot
-- (hud_element_player_buffs_polling.lua:484 "material_values.talent_icon = icon",
-- hud_element_tactical_overlay.lua:328 same slot). Assignment is ALL they do, which
-- means a texture object works there exactly as well as a resident name string.
--
-- So: every hordes buff template whose hud_icon names a texture that is provably
-- not resident gets the category texture object written over it. The original
-- string is kept, which makes the pass idempotent, lets the debug command report
-- what was touched, and means a future game update that ships the real art simply
-- never gets patched (the residency probe would start answering true).
-- ---------------------------------------------------------------------------

local BUFF_TEMPLATES_PATH = "scripts/settings/buff/buff_templates"

local _templates_cache = nil -- require result, cached ONLY on success
local _patch_ran_with = -1   -- how many custom textures existed on the last pass

-- v0.17.3 fix: previous version cached `false` on a failed require, which
-- meant one bad load at mod boot permanently disabled icon patching for the
-- entire session. Kaizen's "boons icons don't persist through quit outs" was
-- exactly this: a fresh session where the first require happened to lose,
-- and patch_templates then early-returned forever. Only successes cache; a
-- failure returns nil and the next tick re-tries.
local function _buff_templates()
	if type(_templates_cache) == "table" then return _templates_cache end
	local ok, value = pcall(require, BUFF_TEMPLATES_PATH)
	if ok and type(value) == "table" then
		_templates_cache = value
		return value
	end
	return nil
end

-- The gradient every talent-style icon composes with. Base UI package, always
-- resident; used when a template needs a gradient and its data entry has none.
local DEFAULT_GRADIENT = "content/ui/textures/color_ramps/talent_ability"

-- The same presentation table boons.lua reads. It is the authoritative list of
-- every hordes buff name, which matters because MOST hordes buff templates carry
-- no hud_icon field at all: v0.13.2 walked BuffTemplates looking for dead icon
-- strings and found only 11, while the other 73 buffs had nothing to find. The
-- HUD then read nil and drew the placeholder hexagon.
local HORDES_DATA_PATH = "scripts/settings/buff/hordes_buffs/hordes_buffs_data"
local _hordes_data_cache = nil

-- Same v0.17.3 retry pattern as _buff_templates. Previously "cached the
-- failure", turning a transient load-order miss into a session-long dead
-- icon system.
local function _hordes_data()
	if type(_hordes_data_cache) == "table" then return _hordes_data_cache end
	local ok, value = pcall(require, HORDES_DATA_PATH)
	if ok and type(value) == "table" then
		_hordes_data_cache = value
		return value
	end
	local global_data = rawget(_G, "HordesBuffsData")
	if type(global_data) == "table" then
		_hordes_data_cache = global_data
		return global_data
	end
	return nil
end

-- Runs from the icons tick. Driven by the hordes DATA table (the full list of
-- names), not by which templates happen to have icon fields, because most hordes
-- templates have none. For each name the replacement is icon_override's choice:
-- a RESIDENT GAME TEXTURE PATH when one resolves (strings are what this pipeline
-- was built for, so they provably draw), the SimpleAssets object as a long shot
-- otherwise. A template whose own hud_icon probes resident is never touched, so
-- a future game update that ships the real art wins automatically.
--
-- TWO SEPARATE PATCHES, and v0.17.4 is the version that learned this:
--
--   1. templates[name].hud_icon  --  used by the small buff strip at the
--      bottom of the HUD (hud_element_player_buffs_polling.lua:405 reads
--      buff:get_hud_data().hud_icon, which returns template.hud_icon).
--
--   2. data[name].icon           --  used by the "Sefoni's Indulgences"
--      panel on the tactical overlay (hud_element_tactical_overlay.lua:378
--      reads buff_data.icon straight off HordesBuffsData). This is why
--      Kaizen's overlay screenshot showed the boons as empty hexagons
--      while the same boons drew fine on the small buff strip: the two
--      HUD elements read DIFFERENT fields, and I was only patching one.
--
-- Re-walks when anything changed since the last walk: a new custom texture
-- loaded, or a category resolved to a resident path that had not resolved
-- before (packages load over time, so resolution improves). A template patched
-- with the object earlier is upgraded to the string when one appears.
function M.patch_templates()
	local loaded = 0
	for _ in pairs(_custom) do loaded = loaded + 1 end
	local resolved = 0
	for i = 1, #M.CATEGORIES do
		if M.resolve_category_texture(M.CATEGORIES[i]) then resolved = resolved + 1 end
	end

	local signature = loaded + resolved * 100
	if signature == 0 or signature == _patch_ran_with then return end

	local templates = _buff_templates()
	if not templates then return end

	local data = _hordes_data()
	if not data then return end

	_patch_ran_with = signature

	for name in pairs(data) do
		local template = templates[name]
		if type(template) == "table" then
			local replacement = M.icon_override(name)
			if replacement ~= nil then
				local icon = template.hud_icon
				if _patched[name] ~= nil then
					-- Already ours. Upgrade an object to a string when a resident
					-- path has since resolved; never downgrade.
					if type(icon) ~= "string" and type(replacement) == "string" then
						template.hud_icon = replacement
					end
				elseif icon == nil then
					-- Absent: record a sentinel (false, not a string) so the pass
					-- stays idempotent and the report can count it.
					_patched[name] = false
					template.hud_icon = replacement
					if template.hud_icon_gradient_map == nil then
						local data_entry = data[name]
						local gradient = type(data_entry) == "table" and data_entry.gradient or nil
						template.hud_icon_gradient_map = gradient or DEFAULT_GRADIENT
					end
				elseif type(icon) == "string"
					and M.texture_resident(icon) == false then
					_patched[name] = icon
					template.hud_icon = replacement
				end
			end
		end

		-- Patch #2: the presentation data table that the tactical overlay
		-- reads. Same rules: only overwrite when the shipped icon is empty
		-- ("") or provably unresident, prefer a resident PATH over the
		-- SimpleAssets object, never downgrade a previous upgrade.
		local data_entry = data[name]
		if type(data_entry) == "table" then
			local replacement = M.icon_override(name)
			if replacement ~= nil then
				local current = data_entry.icon
				local prev = _patched[name .. "\1data"]
				if prev ~= nil then
					if type(current) ~= "string" and type(replacement) == "string" then
						data_entry.icon = replacement
					end
				elseif current == nil or current == ""
					or (type(current) == "string" and M.texture_resident(current) == false) then
					_patched[name .. "\1data"] = current or ""
					data_entry.icon = replacement
					if (data_entry.gradient == nil or data_entry.gradient == "") then
						data_entry.gradient = DEFAULT_GRADIENT
					end
				end
			end
		end
	end
end

-- Checks whether one specific texture path can be resolved right now. Used by the debug
-- command to answer "did it actually work" without needing the player to open a menu.
--
-- can_get_resource on a texture is the same probe used for packages. If it returns
-- false the icon will draw as the question mark hexagon.
-- Same probe, kind "material". The route view asks this before drawing a
-- circumstance icon: unlike a missing TEXTURE (placeholder hexagon), a missing
-- MATERIAL is an engine assert, so only a confirmed true is good enough.
function M.material_resident(path)
	if type(path) ~= "string" or path == "" then return nil end

	local app = rawget(_G, "Application")
	if not (app and type(app.can_get_resource) == "function") then return nil end

	local ok, result = pcall(app.can_get_resource, "material", path)
	if not ok then return nil end
	if result == true then return true end
	if result == false then return false end
	return nil
end

function M.texture_resident(path)
	if type(path) ~= "string" or path == "" then return nil end

	local app = rawget(_G, "Application")
	if not (app and type(app.can_get_resource) == "function") then return nil end

	local ok, result = pcall(app.can_get_resource, "texture", path)
	if not ok then return nil end
	return result == true
end

-- The engine indexes resources by type and we are guessing which type a UI texture is
-- filed under. Ask about all the plausible ones and report what each says, so a "missing"
-- answer can be told apart from "wrong question".
M.RESOURCE_KINDS = { "texture", "material", "texture_atlas", "package" }

function M.probe_resource(path)
	local out = {}
	local app = rawget(_G, "Application")
	if not (app and type(app.can_get_resource) == "function") then
		out.error = "no can_get_resource"
		return out
	end

	for i = 1, #M.RESOURCE_KINDS do
		local kind = M.RESOURCE_KINDS[i]
		local ok, result = pcall(app.can_get_resource, kind, path)
		out[kind] = ok and tostring(result) or "threw"
	end

	return out
end

return M
