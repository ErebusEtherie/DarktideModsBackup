-- Temporary patch for mouse keybinds. Replaces the two key name converters and
-- corrects the capture result, and stands down once DMF stores keys correctly.

local mod = get_mod("DMFKeybindFix")
local dmf = get_mod("DMF")

local InputUtils = require("scripts/managers/input/input_utils")

-- Kept in DMF's order so bare legacy names resolve as they always did.
local SUPPORTED_DEVICES = {
	"keyboard",
	"mouse",
}

local MODIFIER_ALIAS = {
	keyboard_ctrl  = "keyboard_left ctrl",
	keyboard_alt   = "keyboard_left alt",
	keyboard_shift = "keyboard_left shift",
}

-- Engine marker for a button one device reports on another device's behalf.
-- The keyboard carries five of these, and they are the mouse buttons.
local FOREIGN_SUFFIX = "**"

-- A button named as another button plus this suffix fires as a momentary pulse
-- and is not held, so it cannot serve as a modifier.
local PULSE_SUFFIX = "_double"

-- Positional button name, button_0 for the button at index 0. No device
-- answers to this form, so it has to be translated back by index.
local INDEXED_PREFIX = "button_"

local SETTING_STORAGE_FIXED = "framework_storage_fixed"
local SETTING_BINDS_SEEN = "mouse_binds_seen"
local SETTING_CORRECTIONS = "corrections_needed"
local SETTING_NOTICES_SHOWN = "redundant_notices_shown"
local BINDS_BEFORE_VERDICT = 3
local MAX_NOTICES = 3

local _pulse_names = {}
local _pulse_base = {}
local _device_scratch = {}
local _device_scratch_b = {}
local _storage_fixed = false
local _reported = false
local record_mouse_bind = nil
local _original_to_keywatch = nil
local _original_to_local = nil
local _installed = false

-- The device key_axis_locale reads labels and icons from.
local function canonical_raw_device(device_type)
	local devices = InputUtils.input_device_list[device_type]
	return devices and devices[1]
end

local function raw_devices_of(device_type, out)
	table.clear(out)

	local canonical = canonical_raw_device(device_type)
	if canonical then
		out[#out + 1] = canonical
	end

	local input_manager = Managers and Managers.input
	local known = input_manager and input_manager._all_input_devices
	if known then
		for _, device in pairs(known) do
			if device.device_type == device_type then
				local raw_device = device:raw_device()
				if raw_device and raw_device ~= canonical then
					out[#out + 1] = raw_device
				end
			end
		end
	end

	return out
end

local function build_pulse_names()
	table.clear(_pulse_names)
	table.clear(_pulse_base)
	for _, device_type in ipairs(SUPPORTED_DEVICES) do
		local raw_device = canonical_raw_device(device_type)
		if raw_device then
			local present = {}
			local num_buttons = raw_device.num_buttons()
			for i = 0, num_buttons - 1 do
				local name = raw_device.button_name(i)
				if name then
					present[name] = true
				end
			end
			for name in pairs(present) do
				local base = string.match(name, "^(.+)" .. PULSE_SUFFIX .. "$")
				if base and present[base] then
					local global_pulse = InputUtils.local_to_global_name(name, device_type)
					_pulse_names[global_pulse] = true
					_pulse_base[global_pulse] = InputUtils.local_to_global_name(base, device_type)
				end
			end
		end
	end
end

local function find_device_for_global(global_name)
	if type(global_name) ~= "string" then
		return nil
	end
	for _, device_type in ipairs(SUPPORTED_DEVICES) do
		local devices = raw_devices_of(device_type, _device_scratch)
		for i = 1, #devices do
			local raw_device = devices[i]
			if InputUtils.button_index(global_name, raw_device, device_type)
			or InputUtils.axis_index(global_name, raw_device, device_type) then
				return device_type
			end
		end
	end
	return nil
end

-- Rewrites a name into the canonical device's form by resolving it to a button
-- index, through any device that knows the name or through the positional form.
local function canonical_name_of(global_name)
	if type(global_name) ~= "string" then
		return global_name
	end

	local device_type = InputUtils.key_device_type(global_name)
	local local_name = device_type and InputUtils.local_key_name(global_name, device_type)
	if not local_name then
		return global_name
	end

	local canonical = canonical_raw_device(device_type)
	if not canonical or canonical.button_index(local_name) then
		return global_name
	end

	local index = nil

	local devices = raw_devices_of(device_type, _device_scratch_b)
	for i = 1, #devices do
		index = devices[i].button_index(local_name)
		if index then
			break
		end
	end

	if not index then
		index = tonumber(string.match(local_name, "^" .. INDEXED_PREFIX .. "(%d+)$"))
	end

	local canonical_local = index and canonical.button_name(index)
	if not canonical_local then
		return global_name
	end

	return InputUtils.local_to_global_name(canonical_local, device_type)
end

local function local_name_of(global_name)
	local device_type = find_device_for_global(global_name)
	return device_type and InputUtils.local_key_name(global_name, device_type)
end

local function resolve_legacy_local(local_name)
	if type(local_name) ~= "string" then
		return nil
	end
	for _, device_type in ipairs(SUPPORTED_DEVICES) do
		local global_name = InputUtils.local_to_global_name(local_name, device_type)
		if find_device_for_global(global_name) then
			return global_name
		end
	end
	return nil
end

local function stored_key_to_global(stored_name)
	local global_name
	if find_device_for_global(stored_name) then
		global_name = stored_name
	else
		global_name = resolve_legacy_local(stored_name)
	end
	if global_name then
		global_name = canonical_name_of(global_name)
	end
	if global_name and MODIFIER_ALIAS[global_name] then
		global_name = MODIFIER_ALIAS[global_name]
	end
	return global_name
end

-- Bare when the bare name resolves back to the same button, byte identical to
-- DMF's existing format. Device qualified only when another device shadows it.
local function global_to_stored_key(global_name)
	local local_name = local_name_of(global_name)
	if not local_name then
		return global_name
	end
	if resolve_legacy_local(local_name) == global_name then
		return local_name
	end
	return global_name
end

local function resolve_pulse(global_name)
	return _pulse_base[global_name] or global_name
end

local function is_unusable_enabler(global_name)
	if _pulse_names[global_name] then
		return true
	end
	local local_name = local_name_of(global_name)
	return local_name ~= nil and string.sub(local_name, -#FOREIGN_SUFFIX) == FOREIGN_SUFFIX
end

-- Falls back to the original whenever this pass finds nothing.
local function fixed_local_keys_to_keywatch_result(keys)
	local keywatch_result = {
		enablers = {},
		disablers = {},
	}

	if type(keys) ~= "table" or #keys == 0 then
		return nil
	end

	if keys[1] then
		local global_name = stored_key_to_global(keys[1])
		if not global_name then
			return _original_to_keywatch and _original_to_keywatch(keys)
		end
		keywatch_result.main = resolve_pulse(global_name)
	end

	for i = 2, #keys do
		local global_name = stored_key_to_global(keys[i])
		if global_name
		and global_name ~= keywatch_result.main
		and not is_unusable_enabler(global_name) then
			keywatch_result.enablers[#keywatch_result.enablers + 1] = global_name
		end
	end

	return keywatch_result
end

-- Falls back to the original whenever this pass produces nothing.
local function fixed_keywatch_result_to_local_keys(keywatch_result)
	local keys = {}
	local main_name = keywatch_result.main
		and resolve_pulse(canonical_name_of(keywatch_result.main))

	if keywatch_result.main then
		local global_name = main_name
		local local_name = local_name_of(global_name)
		if local_name and dmf.can_bind_as_primary_key(local_name) then
			keys[1] = global_to_stored_key(global_name)
		end
	end

	if keys[1] and keywatch_result.enablers then
		for _, enabler_name in ipairs(keywatch_result.enablers) do
			local global_name = canonical_name_of(enabler_name)
			if global_name ~= main_name
			and local_name_of(global_name)
			and not is_unusable_enabler(global_name) then
				keys[#keys + 1] = global_to_stored_key(global_name)
			end
		end
	end

	if #keys == 0 and keywatch_result.main then
		local fallback = _original_to_local and _original_to_local(keywatch_result)
		if fallback and #fallback > 0 then
			keys = fallback
		end
	end

	return keys
end

local function released_mouse_button()
	local raw_device = canonical_raw_device("mouse")
	if not raw_device then
		return nil
	end
	for i = 0, raw_device.num_buttons() - 1 do
		if raw_device.released(i) then
			local name = raw_device.button_name(i)
			local global_name = name and InputUtils.local_to_global_name(name, "mouse")
			if global_name and not _pulse_names[global_name] then
				return global_name
			end
		end
	end
	return nil
end

local function correct_capture(result)
	local corrected = false

	local canonical_main = canonical_name_of(result.main)
	if canonical_main ~= result.main then
		corrected = true
		result.main = canonical_main
	end

	local base_name = _pulse_base[result.main]
	if base_name then
		result.main = base_name
		corrected = true
	end

	local main_local = local_name_of(result.main)
	if main_local and string.sub(main_local, -#FOREIGN_SUFFIX) == FOREIGN_SUFFIX then
		local replacement = released_mouse_button()
		if replacement then
			result.main = replacement
			corrected = true
		end
	end

	local enablers = result.enablers
	if enablers then
		for i = #enablers, 1, -1 do
			enablers[i] = canonical_name_of(enablers[i])
			local global_name = enablers[i]
			if global_name == result.main
			or not local_name_of(global_name)
			or is_unusable_enabler(global_name) then
				table.remove(enablers, i)
				corrected = true
			end
		end
	end

	return corrected
end

-- Scoped to the mod options rebind popup, so the game's own screen is untouched.
mod:hook(CLASS.InputManager, "key_watch_result", function(func, self)
	local result = func(self)

	if result and Managers.ui and Managers.ui:view_active("dmf_options_view") then
		local corrected = correct_capture(result)
		if InputUtils.key_device_type(result.main or "") == "mouse" then
			record_mouse_bind(corrected)
		end
	end

	return result
end)

-- Re-registers every mod keybind so mods that loaded earlier are corrected too.
local function resweep_keybinds()
	if not dmf or type(dmf.options_widgets_data) ~= "table" then
		return
	end

	for _, widgets_data in ipairs(dmf.options_widgets_data) do
		for i = 2, #widgets_data do
			local data = widgets_data[i]
			if data.type == "keybind" then
				local owner = get_mod(data.mod_name)
				if owner then
					local keywatch_result = dmf.local_keys_to_keywatch_result(owner:get(data.setting_id))
					dmf.add_mod_keybind(owner, data.setting_id, {
						global        = data.keybind_global,
						trigger       = data.keybind_trigger,
						type          = data.keybind_type,
						main          = keywatch_result and keywatch_result.main,
						enablers      = keywatch_result and keywatch_result.enablers,
						disablers     = keywatch_result and keywatch_result.disablers,
						function_name = data.function_name,
						view_name     = data.view_name,
					})
				end
			end
		end
	end

	dmf.generate_keybinds()
end


local function survives_framework_round_trip(global_name)
	local stored = _original_to_local({
		main = global_name,
		enablers = {},
		disablers = {},
	})
	if type(stored) ~= "table" or #stored == 0 then
		return false
	end
	local restored = _original_to_keywatch(stored)
	return restored ~= nil and restored.main == global_name
end

-- Round trips every real button through the original converter pair.
local function framework_storage_is_fixed()
	if not _original_to_local or not _original_to_keywatch then
		return false
	end

	for _, device_type in ipairs(SUPPORTED_DEVICES) do
		local raw_device = canonical_raw_device(device_type)
		if raw_device then
			for i = 0, raw_device.num_buttons() - 1 do
				local name = raw_device.button_name(i)
				local global_name = name and InputUtils.local_to_global_name(name, device_type)
				if global_name
				and not _pulse_names[global_name]
				and string.sub(name, -#FOREIGN_SUFFIX) ~= FOREIGN_SUFFIX
				and not survives_framework_round_trip(global_name) then
					mod:info("Self test: %s does not survive framework storage", global_name)
					return false
				end
			end
		end
	end

	return true
end

record_mouse_bind = function(needed_correction)
	mod:set(SETTING_BINDS_SEEN, (mod:get(SETTING_BINDS_SEEN) or 0) + 1)
	if needed_correction then
		mod:set(SETTING_CORRECTIONS, (mod:get(SETTING_CORRECTIONS) or 0) + 1)
	end
end

local function reset_verdict_counters()
	mod:set(SETTING_BINDS_SEEN, 0)
	mod:set(SETTING_CORRECTIONS, 0)
	mod:set(SETTING_NOTICES_SHOWN, 0)
end

local function report_framework_state()
	if _reported or not _storage_fixed then
		return
	end
	_reported = true

	local binds_seen = mod:get(SETTING_BINDS_SEEN) or 0
	local corrections = mod:get(SETTING_CORRECTIONS) or 0

	if binds_seen >= BINDS_BEFORE_VERDICT and corrections == 0 then
		local shown = mod:get(SETTING_NOTICES_SHOWN) or 0
		mod:info("Self test: framework handles mouse keybinds unaided, this mod is redundant.")
		if shown < MAX_NOTICES then
			mod:set(SETTING_NOTICES_SHOWN, shown + 1)
			mod:echo(mod:localize("notice_redundant"))
		end
	else
		mod:info("Self test: framework storage is correct, capture corrections still active.")
		mod:echo(mod:localize("notice_storage_fixed"))
	end
end

local function framework_shape_ok()
	return dmf
		and type(dmf.local_keys_to_keywatch_result) == "function"
		and type(dmf.keywatch_result_to_local_keys) == "function"
		and type(dmf.add_mod_keybind) == "function"
		and type(dmf.generate_keybinds) == "function"
end

local function install()
	if _installed then
		return
	end
	if not framework_shape_ok() then
		mod:warning("Framework keybind functions not found, the fix is inactive.")
		return
	end

	build_pulse_names()
	_original_to_keywatch = dmf.local_keys_to_keywatch_result
	_original_to_local = dmf.keywatch_result_to_local_keys

	local was_fixed = mod:get(SETTING_STORAGE_FIXED)
	_storage_fixed = framework_storage_is_fixed()
	mod:set(SETTING_STORAGE_FIXED, _storage_fixed)

	if _storage_fixed and not was_fixed then
		reset_verdict_counters()
	end

	if not _storage_fixed then
		dmf.local_keys_to_keywatch_result = fixed_local_keys_to_keywatch_result
		dmf.keywatch_result_to_local_keys = fixed_keywatch_result_to_local_keys
	end

	_installed = true
end

local function uninstall()
	if not _installed then
		return
	end
	dmf.local_keys_to_keywatch_result = _original_to_keywatch
	dmf.keywatch_result_to_local_keys = _original_to_local
	_installed = false
end

mod.on_enabled = function()
	install()
	if dmf and dmf.all_mods_were_loaded then
		resweep_keybinds()
	end
end

mod.on_disabled = function()
	uninstall()
	if dmf and dmf.all_mods_were_loaded then
		resweep_keybinds()
	end
end

mod.on_all_mods_loaded = function()
	if not mod:is_enabled() then
		return
	end
	install()
	resweep_keybinds()
end

mod.on_game_state_changed = function(status, state_name)
	if status == "enter" and state_name == "StateGameplay" then
		report_framework_state()
	end
end
