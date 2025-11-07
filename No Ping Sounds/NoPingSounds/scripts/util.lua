return function(mod)
	local util = {}

	-- ╔═╗┌─┐┌┬┐┬ ┬┌─┐
	-- ╚═╗├┤  │ │ │├─┘
	-- ╚═╝└─┘ ┴ └─┘┴
	function util.get_settings()
		local settings = mod:persistent_table("SETTINGS")
		local data = mod:io_dofile(mod:get_name() .. "/scripts/Mod_data")

		local function _copy_settings(container)
			for _, v in pairs(container) do
				settings[v.setting_id] = mod:get(v.setting_id)
				if v.sub_widgets then
					_copy_settings(v.sub_widgets)
				end
			end
		end
		_copy_settings(data.options.widgets)

		return settings
	end

	local function increment_wrap(limit, i, inc)
		i = i + (inc or 1)
		i = (i - 1) % limit + 1
		return i
	end
	util.increment_wrap = increment_wrap

	-- ╔═╗┌┬┐┌─┐┬─┐┌─┐
	-- ╚═╗ │ │ │├┬┘├┤
	-- ╚═╝ ┴ └─┘┴└─└─┘

	local Store = {}
	Store.__index = Store

	util.Store = Store

	function Store:new(name)
		return setmetatable(mod:persistent_table(name), self)
	end

	function Store:get(key, callback)
		local value = rawget(self, key)
		if value and callback then
			return callback(value)
		end
		return value
	end

	function Store:set(key, value, cmp)
		local oldvalue = rawget(self, key)
		if cmp and cmp(value, oldvalue) or value == oldvalue then
			return false
		end
		rawset(self, key, value)
		return true
	end

	local _map = { [true] = 1, [false] = 0 }

	function Store:cycle(key, list, increment)
		local list_index = rawget(self, key) or 1
		if increment then
			list_index = increment_wrap(#list, list_index, _map[increment] or increment) --(list_index + increment - 1) % #list + 1
			rawset(self, key, list_index)
		end
		local value = list[list_index]
		return value
	end

	local _vars = Store:new("VARIABLES")
	util.vars = _vars

	function util.get(key, callback)
		return _vars:get(key, callback)
	end

	function util.set(key, value)
		return _vars:set(key, value)
	end

	-- ╔═╗┬ ┬┌┐┌┌─┐┌┬┐┬┌─┐┌┐┌┌─┐
	-- ╠╣ │ │││││   │ ││ ││││└─┐
	-- ╚  └─┘┘└┘└─┘ ┴ ┴└─┘┘└┘└─┘

	function util.print(fmt, ...)
		local msg
		if type(fmt) == "string" then
			msg = string.format(fmt, ...)
		else
			local t = {}
			for _, v in ipairs({ fmt, ... }) do
				t[#t + 1] = tostring(v)
			end
			msg = table.concat(t, "\t")
		end
		mod:echo(msg)
		print(msg)
	end

	function util.smart_tag(template_name, tagger_unit, target_unit, target_location)
		if target_unit and not (Unit.is_valid(target_unit) and SmartTag.validate_target_unit(target_unit)) then
			return
		end

		local smart_tag_system = Managers.state.extension:system("smart_tag_system")
		if target_unit then
			-- Arbitrator ping needs a special parameter
			local alternate = (template_name == "enemy_companion_target") and "companion_order"
			smart_tag_system:set_contextual_unit_tag(tagger_unit, target_unit, alternate)
		else
			smart_tag_system:set_tag(template_name, tagger_unit, nil, target_location)
		end
	end

	local function iall(table, predicate)
		for k, v in ipairs(table) do
			if not predicate(v) then
				return false
			end
		end
		return true
	end
	util.iall = iall

	local function iany(table, predicate)
		for k, v in ipairs(table) do
			if predicate(v) then
				return true
			end
		end
		return false
	end
	util.iany = iany

	local function fn_or(...)
		local fns = { ... }
		return function(...)
			for _, fn in ipairs(fns) do
				if fn(...) then
					return true
				end
			end
			return false
		end
	end
	util.fn_or = fn_or

	local function fn_and(...)
		local fns = { ... }
		return function(...)
			for _, fn in ipairs(fns) do
				if not fn(...) then
					return false
				end
			end
			return true
		end
	end
	util.fn_and = fn_and

	-- ╦╔═┌─┐┬ ┬┌┐ ┬┌┐┌┌┬┐┌─┐
	-- ╠╩╗├┤ └┬┘├┴┐││││ ││└─┐
	-- ╩ ╩└─┘ ┴ └─┘┴┘└┘─┴┘└─┘

	local InputUtils = require("scripts/managers/input/input_utils")

	local function get_button(button_name)
		local device
		local device_type = InputUtils.key_device_type(button_name)

		if device_type then -- global button
			device = Managers.input:_find_active_device(device_type)
			local i = device:button_index(button_name)
			return device, i, true
		else -- local button
			for _, used_device in ipairs(Managers.input._used_input_devices) do
				local i = used_device._raw_device.button_index(button_name)
				if i then
					return used_device, i, false
				end
			end
		end
	end

	local function key_held(button_name)
		local device, btn = get_button(button_name)
		local b = device and device._raw_device.button(btn)
		return b and b > 0
	end
	local function key_pressed(button_name)
		local device, btn = get_button(button_name)
		return device and device._raw_device.pressed(btn)
	end
	local function key_released(button_name)
		local device, btn = get_button(button_name)
		return device and device._raw_device.released(btn)
	end

	local _cache = {}

	local function split_keys(inputstr)
		local key_info = _cache[inputstr]
		if not key_info then
			local m, e, d = InputUtils.split_key(inputstr)
			key_info = { main = m, enablers = e, disablers = d }
			_cache[inputstr] = key_info
		end
		return key_info
	end

	local Keybind = { callbacks = {} }
	util.keybind = Keybind

	function Keybind:register(trigger, inputstr, callback)
		self.callbacks[#self.callbacks + 1] = function(...)
			if self[trigger](self, inputstr) then
				callback(...)
			end
		end
	end

	function Keybind:check(...)
		for _, cb in ipairs(self.callbacks) do
			cb(...)
		end
	end

	function Keybind:press(inputstr, callback)
		if callback then
			return self:register("press", inputstr, callback)
		end
		local key_info = split_keys(inputstr)
		return key_pressed(key_info.main) and iall(key_info.enablers, key_held)
	end

	function Keybind:hold(inputstr, callback)
		if callback then
			return self:register("hold", inputstr, callback)
		end
		local key_info = split_keys(inputstr)
		return key_held(key_info.main) and iall(key_info.enablers, key_held)
	end

	function Keybind:release(inputstr, callback)
		if callback then
			return self:register("release", inputstr, callback)
		end
		local key_info = split_keys(inputstr)
		return key_released(key_info.main) and iall(key_info.enablers, fn_or(key_held, key_released))
			or key_held(key_info.main) and iany(key_info.enablers, key_released)
	end

	-- ╔╦╗┌─┐┌┐ ┬ ┬┌─┐
	--  ║║├┤ ├┴┐│ ││ ┬
	-- ═╩╝└─┘└─┘└─┘└─┘

	local Debug = {
		store = Store:new("DEBUG"),
		radii = { 0.1, 0.2, 0.5, 1, 2.0 },
	}
	util.debug = Debug

	Debug.store.line = Debug.store.line or {}

	function Debug:_line_obj(name, world)
		-- Line object management
		local obj = self.store.line[name]
		if not obj then
			obj = world:create_line_object()
			self.store.line[name] = obj
		end
		return obj
	end

	function Debug:draw_sphere(name, pos, color, radius)
		local player = Managers.player:local_player_safe(1)
		if not player then
			return
		end

		local world = Unit.world(player.player_unit)
		local line = self:_line_obj(name, world)
		radius = radius or self.store:cycle(name .. "radius", self.radii, not self.store:set(name .. "pos", pos))

		if pos.unbox then
			pos = pos:unbox()
		end

		LineObject.reset(line)
		LineObject.add_sphere(line, color, pos, radius, 20, 20)
		LineObject.dispatch(world, line)
	end

	function Debug:draw_input(UIRenderer, self, ui_scenegraph)
		if rawget(ui_scenegraph, "software_cursor") then
			local overlay = ""
			for _, device in ipairs(Managers.input._used_input_devices) do
				local held = device:buttons_held()
				if #held > 0 then
					local text = table.concat(held, "\n")
					overlay = overlay .. text .. "\n"
				end
			end

			if overlay ~= "" then
				local text = overlay
				local font_size = 16
				local font_type = "proxima_nova_bold"
				local position = { 100, 100, 0 }
				local size = ui_scenegraph.screen.size
				local color = Color.white(255, true)
				local text_options = {
					shadow = true,
				}
				UIRenderer.draw_text(self, text, font_size, font_type, position, size, color, text_options)
			end
		end
	end

	return util
end
