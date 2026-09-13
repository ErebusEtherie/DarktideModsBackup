

---@param mod DL_Mod
return function(mod)
	---@class DL_Data
	local Data = {}

	---@type table<string, boolean|string|number>
	local _defaults = {}

	Data.set_defaults = function(defaults)
		_defaults = defaults

		mod.dl.settings.register_defaults(defaults)
	end

	---@param key? string

	Data.get_defaults = function(key)
		return _defaults
	end

	---@param key? string

	Data.get_default = function(key)
		return key and _defaults[key] or nil
	end

	Data.resolve_default = function(key, default)
		local default_key = key

		if default ~= nil then
			return default
		end

		if _defaults[default_key] ~= nil then
			return _defaults[default_key]
		end

		return nil
	end

	local function new_builder(key, methods, fields)
		return setmetatable(fields, { __index = methods, _key = key })
	end

	local function key_of(self)
		return getmetatable(self)._key
	end

	---@class DL_DataNumeric
	local Numeric = {}

	local function decimals_of(n)
		if type(n) ~= "number" or n % 1 == 0 then
			return 0
		end
		local frac = string.format("%.12f", n):gsub("0+$", ""):match("%.(%d+)$")
		return frac and #frac or 0
	end

	local function numeric_refresh_precision(self)
		local mt = getmetatable(self)
		if mt._explicit_decimals and mt._explicit_step then
			return
		end
		local range = rawget(self, "range")

		local decimals = 0
		if range then
			decimals = math.max(decimals_of(range[1]), decimals_of(range[2]))
		end
		if mt._explicit_step then
			decimals = math.max(decimals, decimals_of(self.step_size_value))
		end
		if mt._explicit_decimals then
			decimals = math.max(decimals, self.decimals_number)
		end

		if not mt._explicit_decimals then
			self.decimals_number = decimals
		end
		if not mt._explicit_step then
			self.step_size_value = 10 ^ -decimals
		end
	end

	local function numeric_refresh_default(self)
		local mt = getmetatable(self)
		if mt._explicit_default then
			return
		end
		local resolved = Data.resolve_default(mt._key, nil)
		local range = rawget(self, "range") 
		if resolved ~= nil then
			self.default_value = resolved
		elseif range then
			self.default_value = (range[2] - range[1]) / 2
		end
	end

	---@return DL_DataNumeric
	function Numeric:range(from, to)
		self.range = { from, to }
		numeric_refresh_precision(self)
		numeric_refresh_default(self)
		return self
	end

	---@return DL_DataNumeric
	function Numeric:decimals(decimals)
		self.decimals_number = decimals
		getmetatable(self)._explicit_decimals = true
		numeric_refresh_precision(self)
		return self
	end

	---@return DL_DataNumeric
	function Numeric:step(step)
		self.step_size_value = step
		getmetatable(self)._explicit_step = true
		numeric_refresh_precision(self)
		return self
	end

	---@return DL_DataNumeric
	function Numeric:default(default)
		self.default_value = default
		getmetatable(self)._explicit_default = true
		return self
	end

	---@return DL_DataNumeric
	Data.numeric = function(key, range, decimals, step, default)
		local self = new_builder(key, Numeric, {
			setting_id = key,
			type = "numeric",
			range = range,
		})

		if decimals ~= nil then
			self:decimals(decimals)
		end
		if step ~= nil then
			self:step(step)
		end
		numeric_refresh_precision(self)
		if default ~= nil then
			self:default(default)
		else
			numeric_refresh_default(self)
		end
		return self
	end

	---@class DL_DataCheckbox
	local Checkbox = {}

	---@class DL_DataCheckbox
	function Checkbox:default(default)
		self.default_value = default
		return self
	end

	---@class DL_DataCheckbox
	Data.checkbox = function(key, default)
		return new_builder(key, Checkbox, {
			setting_id = key,
			type = "checkbox",
			default_value = Data.resolve_default(key, default) or false,
		})
	end

	---@class DL_DataDropdown
	local Dropdown = {}

	---@return DL_DataDropdown
	function Dropdown:options(options)
		self.options = options
		return self
	end

	---@return DL_DataDropdown
	function Dropdown:default(default)
		self.default_value = default
		return self
	end

	---@return DL_DataDropdown
	Data.dropdown = function(key, options, default)
		return new_builder(key, Dropdown, {
			setting_id = key,
			type = "dropdown",
			options = options,
			default_value = Data.resolve_default(key, default) or nil,
		})
	end

	---@class DL_DataKeybind
	local Keybind = {}

	---@return DL_DataKeybind
	function Keybind:trigger(trigger)
		self.keybind_trigger = trigger
		return self
	end

	---@return DL_DataKeybind
	function Keybind:kind(keybind_type)
		self.keybind_type = keybind_type
		return self
	end

	---@return DL_DataKeybind
	function Keybind:call(function_name)
		self.function_name = function_name
		return self
	end

	---@return DL_DataKeybind
	function Keybind:default(default)
		self.default_value = default
		return self
	end

	---@return DL_DataKeybind
	Data.keybind = function(key, function_name)
		return new_builder(key, Keybind, {
			setting_id = key,
			type = "keybind",
			keybind_trigger = "pressed",
			keybind_type = "function_call",
			default_value = {},
			function_name = function_name,
		})
	end

	---@class DL_DataGroup
	local Group = {}

	---@return DL_DataGroup
	function Group:widgets(widgets)
		self.sub_widgets = widgets
		return self
	end

	---@return DL_DataGroup
	Data.group = function(key, widgets)
		return new_builder(key, Group, {
			setting_id = "settings_group_" .. key,
			type = "group",
			sub_widgets = widgets,
		})
	end

	---@return table
	Data.option = function(key, value)
		return { text = key, value = value }
	end

	---@return table
	Data.numeric_argb_group = function(group_key, ...)
		local widgets = {}
		local suffix = {
			"_A",
			"_R",
			"_G",
			"_B",
		}

		local widget_index = 1
		for i = 1, select("#", ...) do
			for n = 1, 4 do
				widgets[widget_index] = Data.numeric(select(i, ...) .. suffix[n]):range(0, 255)
				widget_index = widget_index + 1
			end
		end

		return Data.group(group_key, widgets)
	end

	local function color_option_label(loc_key)
		local dmf = get_mod("DMF")
		return dmf.quick_localize(mod, loc_key) or mod.dl.str.machine_to_human_text(loc_key)
	end

	Data.dropdown_rgb = function(key, color_table, default, label_loc_key)
		local options = {}
		local _exists = {}

		local sorted = mod.dl.colors.sort_colors(color_table)

		for i = 1, #sorted do
			local rgb = mod.dl.colors.to_rgb(sorted[i].value)
			local rgb_str = mod.dl.colors.to_rgb_string(rgb)

			if not _exists[rgb_str] then
				_exists[rgb_str] = true
				local label = color_option_label(label_loc_key or sorted[i].key)
				options[#options + 1] = { text = mod.dl.str.rich_text(label, { color = rgb }), value = rgb_str }
			end
		end

		options.localize = false

		return Data.dropdown(key, options, default)
	end

	Data.dropdown_color_options = function(color_table, default_color, label_loc_key)
		local options = {}
		local _exists = {}

		for i = 1, #color_table do
			local rgb = mod.dl.colors.to_rgb(color_table[i].value)
			local rgb_str = mod.dl.colors.to_rgb_string(rgb)

			if not _exists[rgb_str] then
				_exists[rgb_str] = true
				options[#options + 1] = {
					text = mod.dl.str.rich_text(
						color_option_label(label_loc_key or color_table[i].key),
						{ color = rgb }
					),
					value = rgb_str,
				}
			end
		end

		local default_str = default_color and mod.dl.colors.to_rgb_string(default_color) or nil

		if default_str and not _exists[default_str] then
			_exists[default_str] = true
			local default_rgb = mod.dl.colors.to_rgb(default_color)
			table.insert(options, 1, {
				text = mod.dl.str.rich_text(
					color_option_label(label_loc_key or "color_option_default"),
					{ color = default_rgb }
				),
				value = default_str,
			})
		end

		return options, default_str
	end

	Data.dropdown_color = function(key, color_table, default_color, label_loc_key)
		local options, default_str = Data.dropdown_color_options(color_table, default_color, label_loc_key)

		return Data.dropdown(key, options, default_str)
	end

	Data.dropdown_font_options = function(key)
		local font_types = mod.dl.fonts.font_types()
		local current_value = mod:get(key)
		local current_value_is_valid = false

		if not font_types or #font_types == 0 then
			return {}
		end

		local options = {}

		for i = 1, #font_types do

			if not current_value_is_valid and font_types[i].font_type == current_value then
				current_value_is_valid = true
			end
			options[i] = {
				text = font_types[i].font_type,
				value = font_types[i].font_type,
			}
		end

		if not current_value_is_valid then
			mod:set(key, mod.dl.fonts.fallback())
		end

		return options
	end

	Data.dropdown_font = function(key, default)
		return Data.dropdown(key, Data.dropdown_font_options(key), default)
	end

	return Data
end
