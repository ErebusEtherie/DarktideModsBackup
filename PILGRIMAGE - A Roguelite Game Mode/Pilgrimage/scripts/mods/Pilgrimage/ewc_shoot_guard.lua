-- Compatibility bridge, not a damage multiplier. Known EWC shoot wrappers
-- resolve hits, procs and lightning before calling native shooting again.
-- On an authoritative host, bypass ONLY that verified redundant wrapper.
-- EWC's other hooks (magazine visuals, sounds, attachments) remain intact.
local M = {}
local mod
local enabled = true
local bypassed = 0
local state = "not_checked"
local protected = {}
local function diagnostic()
	-- Independent of DMF chat echo and the user's chosen logging verbosity.
	local libs = rawget(_G, "Mods")
	local io_lib = libs and libs.lua and libs.lua.io
	if not io_lib then return end
	pcall(function()
		local f = io_lib.open("./../mods/Pilgrimage/ewc_guard_status.txt", "w")
		if f then
			f:write(string.format("EWC guard: %s; enabled=%s; handlers=%d; prevented=%d\n",
				state, tostring(enabled), #protected, bypassed))
			f:close()
		end
	end)
end
local SOURCE = "extended_weapon_customization/scripts/mods/ewc/patches/action_shoot"
local KNOWN = {
	["3940:29932088:724457437"] = "cached-hitscan duplicate wrapper",
	["3928:403260106:720676837"] = "table-hitscan duplicate wrapper",
}

local function debug_library()
	local mods = rawget(_G, "Mods")
	return mods and mods.lua and mods.lua.debug or rawget(_G, "debug")
end

local function upvalue(dbg, fn, wanted)
	if type(fn) ~= "function" then return nil end
	for i = 1, 64 do
		local name, value = dbg.getupvalue(fn, i)
		if not name then break end
		if name == wanted then return value end
	end
end

function M.fingerprint(body)
	-- Whitespace/comments may differ between packaging tools. Any actual
	-- code change rejects the match. Two bounded hashes plus length; no EWC
	-- version-number assumptions and no third-party code shipped here.
	local canonical = body:gsub("%-%-[^\r\n]*", ""):gsub("%s", "")
	local a, b = 0, 0
	for i = 1, #canonical do
		local c = canonical:byte(i)
		a = (a * 131 + c) % 2147483647
		b = (b * 65599 + c) % 2147483647
	end
	return string.format("%d:%d:%d", #canonical, a, b)
end

local function verified_handler(dbg, handler, lines)
	local info = dbg.getinfo(handler, "S")
	if not info or not info.source or not info.source:gsub("\\", "/"):find(
		"/scripts/mods/ewc/patches/action_shoot.lua", 1, true) then return false end
	local first, last = info.linedefined, info.lastlinedefined
	if not first or not last or first < 1 or last < first or last > #lines then return false end
	return KNOWN[M.fingerprint(table.concat(lines, "\n", first, last))] ~= nil
end

function M.restore()
	for _, entry in ipairs(protected) do
		-- Do not overwrite a later author/mod replacement.
		if entry.record.handler == entry.wrapper then entry.record.handler = entry.original end
	end
	protected = {}
	if mod then mod._pilgrimage_ewc_guard_restorations = protected end
	state = "restored"
end

local function install_record(record)
	local original = record.handler
	local wrapper = function(next_hook, self, position, rotation, power, charge, t, config, ...)
		if enabled and mod:is_enabled() and self._is_server == true
			and config and config.hit_scan_template then
			bypassed = bypassed + 1
			if bypassed <= 4 then diagnostic() end
			-- Run the rest of DMF's chain, not a private cached native method.
			-- This preserves Pilgrimage balance/boons and every other mod hook.
			return next_hook(self, position, rotation, power, charge, t, config, ...)
		end
		return original(next_hook, self, position, rotation, power, charge, t, config, ...)
	end
	record.handler = wrapper
	protected[#protected + 1] = { record = record, original = original, wrapper = wrapper }
end

function M.try_install()
	M.restore()
	local ewc = get_mod("extended_weapon_customization")
	if not ewc then state = "EWC absent"; return false, state end
	local dbg = debug_library()
	if not dbg or not dbg.getupvalue or not dbg.getinfo then
		state = "unsupported debug API"; return false, state
	end
	-- DMF has no public API to inspect an already-registered handler. Inspect
	-- only its named toggle -> registry seam, never walk arbitrary closures.
	-- If DMF changes that seam, fail open rather than guessing/replacing it.
	local toggle = upvalue(dbg, ewc.hook_disable, "generic_hook_toggle")
	local registry = upvalue(dbg, toggle, "_registry")
	local entries = type(registry) == "table" and rawget(registry, ewc)
	if type(entries) ~= "table" then state = "DMF hook registry unavailable"; return false, state end
	local ok, content = pcall(mod.io_read_content, mod, SOURCE)
	if not ok or type(content) ~= "string" then state = "EWC source unavailable"; return false, state end
	local lines = {}
	for line in (content .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line:gsub("\r$", "") end
	local classes = rawget(_G, "CLASS") or {}
	local allowed = {}
	for _, name in ipairs({ "ActionShoot", "ActionShootHitScan", "ActionShootPellets", "ActionShootProjectile" }) do
		if classes[name] then allowed[classes[name]] = true end
	end
	local checked = {}
	for _, record in pairs(entries) do
		local class_name = type(record) == "table" and type(record.obj) == "table" and record.obj.__class_name
		local named_shoot_class = class_name == "ActionShoot" or class_name == "ActionShootHitScan"
			or class_name == "ActionShootPellets" or class_name == "ActionShootProjectile"
		if type(record) == "table" and record.hook_type == 1 and (allowed[record.obj] or named_shoot_class)
			and type(record.handler) == "function" then
			local handler = record.handler
			if checked[handler] == nil then checked[handler] = verified_handler(dbg, handler, lines) end
			if checked[handler] then install_record(record) end
		end
	end
	state = #protected > 0 and "known duplicate wrapper guarded" or "unrecognized or updated EWC, untouched"
	diagnostic()
	return #protected > 0, state
end

function M.refresh()
	local ok, result, detail = pcall(M.try_install)
	if not ok then state = "initialization error: " .. tostring(result) end
	diagnostic()
	return ok and result, detail or state
end

function M.status()
	return { state = state, enabled = enabled, handlers = #protected, bypassed_shots = bypassed }
end

function M.init(deps)
	mod = deps.mod
	-- Restore an earlier module instance first when DMF hot-reloads us.
	protected = mod._pilgrimage_ewc_guard_restorations or {}
	M.restore()
	mod:command("pil_ewc_guard", "EWC duplicate-shot safeguard: status, on, off (session only).", function(option)
		option = tostring(option or "status"):lower()
		if option == "off" then enabled = false
		elseif option == "on" then enabled = true; M.refresh()
		elseif option ~= "status" then mod:notify("Use /pil_ewc_guard status, on or off."); return end
		diagnostic()
		mod:notify(string.format("EWC guard: %s; %s; %d handlers; %d redundant shot passes prevented.",
			enabled and "on" or "off", state, #protected, bypassed))
	end)
end

return M
