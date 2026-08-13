

local function decimals_of(n)
	if type(n) ~= "number" or n % 1 == 0 then
		return 0
	end
	local frac = string.format("%.12f", n):gsub("0+$", ""):match("%.(%d+)$")
	return frac and #frac or 0
end

---@param Module DLH_SettingsMenu
return function(Module)
	---@class DLH_SettingsMenuSchemaBuilder
	local SchemaBuilder = {}

	local _defaults = {}

	SchemaBuilder.register_defaults = function(defaults)
		if defaults and type(defaults) == "table" then
			_defaults = defaults
		end
	end

	local function add_placement(methods)
		function methods:at(col, row)
			self.col = col or self.col
			self.row = row or self.row
			return self
		end

		function methods:span(col_span)
			self.col_span = col_span or self.col_span

			return self
		end

		---@param col integer 1-based grid column
		function methods:from_col(col)
			self.start_col = col
			return self
		end

		function methods:label(loc_key)
			self.label_key = loc_key
			return self
		end

		function methods:no_label()
			self.label_key = nil
			return self
		end

		---@param handler string | fun(value: any)
		function methods:on_change(handler)
			self.on_change_fn = handler
			return self
		end

		---@param loc_key string?
		function methods:description(loc_key)
			self.description_key = loc_key or (self.key .. "_description")
			return self
		end

		---@param predicate boolean | string | fun(): boolean
		function methods:hidden(predicate)
			self.hidden_fn = predicate
			return self
		end

		---@param predicate boolean | string | fun(): boolean
		function methods:disabled(predicate)
			self.disabled_fn = predicate
			return self
		end

		return methods
	end

	---@class DLH_SettingsMenuNumeric : DLH_SettingsMenuControlWidget<DLH_SettingsMenuNumeric>
	local Numeric = add_placement({})
	Numeric.__index = Numeric

	---@return DLH_SettingsMenuNumeric
	function Numeric:range(from, to)
		self.min = from
		self.max = to
		if not self._explicit_decimals then
			self.decimals_count = math.max(decimals_of(from), decimals_of(to), self.decimals_count)
		end
		return self
	end

	---@return DLH_SettingsMenuNumeric
	function Numeric:step(step)
		self.step_size = step
		if not self._explicit_decimals then
			self.decimals_count = math.max(self.decimals_count, decimals_of(step))
		end
		return self
	end

	---@return DLH_SettingsMenuNumeric
	function Numeric:decimals(decimals)
		self.decimals_count = decimals
		self._explicit_decimals = true
		return self
	end

	---@return DLH_SettingsMenuNumeric
	function Numeric:default(default)
		self.default_value = default
		return self
	end

	---@return DLH_SettingsMenuNumeric
	function Numeric:unit(unit)
		self.unit_suffix = unit
		return self
	end

	---@param key string
	---@return DLH_SettingsMenuNumeric
	SchemaBuilder.numeric = function(key)
		return setmetatable({
			type = "numeric",
			key = key,
			label_key = key,
			col = 1,
			row = 1,
			col_span = 1,

			row_span = Module.constants.ROW_UNITS,
			min = 0,
			max = 100,
			unit_suffix = "",
			step_size = 1,
			decimals_count = 0,
			default_value = (type(_defaults[key]) == "number" and _defaults[key]) or 0,
		}, Numeric)
	end

	---@class DLH_SettingsMenuCheckbox : DLH_SettingsMenuControlWidget<DLH_SettingsMenuCheckbox>
	local Checkbox = add_placement({})
	Checkbox.__index = Checkbox

	---@param default boolean
	---@return DLH_SettingsMenuCheckbox
	function Checkbox:default(default)
		self.default_value = default
		return self
	end

	---@param key string
	---@return DLH_SettingsMenuCheckbox
	SchemaBuilder.checkbox = function(key)
		return setmetatable({
			type = "checkbox",
			key = key,
			label_key = key,
			col = 1,
			row = 1,
			col_span = 1,

			row_span = Module.constants.ROW_UNITS,
			default_value = (type(_defaults[key]) == "boolean" and _defaults[key]) or false,
		}, Checkbox)
	end

	---@class DLH_SettingsMenuKeybind : DLH_SettingsMenuControlWidget<DLH_SettingsMenuKeybind>
	local Keybind = add_placement({})
	Keybind.__index = Keybind

	---@return DLH_SettingsMenuKeybind
	function Keybind:call(function_name)
		self.function_name = function_name
		return self
	end

	---@return DLH_SettingsMenuKeybind
	function Keybind:default(default)
		self.default_value = default
		return self
	end

	---@param key string
	---@return DLH_SettingsMenuKeybind
	SchemaBuilder.keybind = function(key)
		return setmetatable({
			type = "keybind",
			key = key,
			label_key = key,
			col = 1,
			row = 1,
			col_span = 1,

			row_span = Module.constants.ROW_UNITS,
			function_name = nil,

			default_value = nil,
		}, Keybind)
	end

	---@class DLH_SettingsMenuDropdown : DLH_SettingsMenuControlWidget<DLH_SettingsMenuDropdown>
	local Dropdown = add_placement({})
	Dropdown.__index = Dropdown

	---@param options table[] | string[] | number[]
	---@return DLH_SettingsMenuDropdown
	function Dropdown:options(options)
		local list = {}
		for i = 1, #options do
			local option = options[i]
			if type(option) ~= "table" then
				list[i] = { value = option, label_key = tostring(option) }
			else
				local value = option.value
				if value == nil then
					value = option[1]
				end
				list[i] = {
					value = value,
					label_key = option.label or option.label_key or option[2] or tostring(value),
					text = option.text,
					font_type = option.font_type,
					color = option.color,
				}
			end
		end
		self.option_list = list
		return self
	end

	---@return DLH_SettingsMenuDropdown
	function Dropdown:default(default)
		self.default_value = default
		return self
	end

	---@param key string
	---@return DLH_SettingsMenuDropdown
	SchemaBuilder.dropdown = function(key)
		return setmetatable({
			type = "dropdown",
			key = key,
			label_key = key,
			col = 1,
			row = 1,
			col_span = 1,

			row_span = Module.constants.ROW_UNITS,

			option_list = {},
			default_value = _defaults[key],
		}, Dropdown)
	end

	---@class DLH_SettingsMenuButton : DLH_SettingsMenuControlWidget<DLH_SettingsMenuButton>
	local Button = add_placement({})
	Button.__index = Button

	---@param handler string | fun(event: DLH_SettingsMenuClickEvent)
	---@return DLH_SettingsMenuButton
	function Button:on_click(handler)
		self.on_click_fn = handler
		return self
	end

	---@param loc_key string
	---@return DLH_SettingsMenuButton
	function Button:text(loc_key)
		self.text_key = loc_key
		return self
	end

	---@param key string
	---@return DLH_SettingsMenuButton
	SchemaBuilder.button = function(key)
		return setmetatable({
			type = "button",
			key = key,

			label_key = nil,
			text_key = key,
			col = 1,
			row = 1,
			col_span = 1,

			row_span = Module.constants.ROW_UNITS,
		}, Button)
	end

	---@class DLH_SettingsMenuHeading : DLH_SettingsMenuWidget<DLH_SettingsMenuHeading>
	local Heading = add_placement({})
	Heading.__index = Heading

	---@return table<number, DLH_SettingsMenuHeading>
	function Heading:as_row()
		return { self }
	end

	---@return DLH_SettingsMenuHeading
	SchemaBuilder.heading = function(key, label)
		return setmetatable({
			type = "heading",
			key = key,
			label_key = label or key,
			col = 1,
			row = 1,
			col_span = Module.constants.GRID_COLS,

			row_span = Module.constants.ROW_UNITS,
		}, Heading)
	end

	---@class DLH_SettingsMenuTab
	---@field title_text string | nil resolved from title_key by build_menu; nil when untranslated
	---@field description_text string | nil ditto for description_key -- nil shrinks the header band
	local Tab = {}
	Tab.__index = Tab

	---@param row DLH_SettingsMenuTabElement[]
	---@return number
	local function row_units(row)
		local C = Module.constants
		if #row == 0 then
			return C.ROW_UNITS
		end

		local all_headings, all_bare_buttons = true, true
		for i = 1, #row do
			local control = row[i]
			if control.type ~= "heading" or control.description_key ~= nil then
				all_headings = false
			end
			if control.type ~= "button" or control.label_key ~= nil then
				all_bare_buttons = false
			end
			if not (all_headings or all_bare_buttons) then
				return C.ROW_UNITS
			end
		end

		if all_headings then
			return C.HEADING_ROW_UNITS
		end
		return Module.layout_manager.button_row_units()
	end

	---@param row DLH_SettingsMenuTabElement[]
	---@return boolean
	local function is_heading_row(row)
		for i = 1, #row do
			if row[i].type == "heading" then
				return true
			end
		end
		return false
	end

	function Tab:rows(rows)
		local controls = {}

		local unit_row = 1

		for _, row in ipairs(rows) do
			local col_offset = 0
			local units = row_units(row)

			if is_heading_row(row) then
				unit_row = unit_row + Module.constants.HEADING_SPACER_UNITS
			end

			for col_index, control in ipairs(row) do
				if control.type == "heading" then
					control:span(Module.constants.GRID_COLS)
				end

				col_offset = col_offset + ((control.col or 1) - 1)

				local col = col_index + col_offset

				control:at(col_index + col_offset, unit_row)
				control.row_span = units

				col_offset = col_offset + (control.col_span - 1)

				controls[#controls + 1] = control
			end

			unit_row = unit_row + units
		end

		self.controls = controls
		return self
	end

	function Tab:button(key)
		self.label_key = key
		return self
	end

	function Tab:header(key)
		self.title_key = key
		return self
	end

	---@param key string? defaults to "<id>_description"
	function Tab:description(key)
		self.description_key = key or (self.id .. "_description")
		return self
	end

	---@param id string stable id, persisted as the active-tab setting
	---@return DLH_SettingsMenuTab
	SchemaBuilder.tab = function(id)
		return setmetatable({
			is_tab = true,
			id = id,
			label_key = id,
			title_key = id,

			description_key = nil,
		}, Tab)
	end

	---@param schema table[]
	---@return table[]
	SchemaBuilder.all_controls = function(schema)
		local out = {}
		for i = 1, #schema do
			local entry = schema[i]
			if entry.is_tab then
				for j = 1, #entry.controls do
					out[#out + 1] = entry.controls[j]
				end
			else
				out[#out + 1] = entry
			end
		end
		return out
	end

	---@param schema table[]
	---@return table<string, any>
	SchemaBuilder.defaults = function(schema)
		local defaults = {}
		local controls = SchemaBuilder.all_controls(schema)
		for i = 1, #controls do
			local control = controls[i]
			if control.default_value ~= nil then
				defaults[control.key] = control.default_value
			end
		end
		return defaults
	end

	---@param schema table[]
	---@return table<string, table>
	SchemaBuilder.by_key = function(schema)
		local by_key = {}
		local controls = SchemaBuilder.all_controls(schema)
		for i = 1, #controls do
			by_key[controls[i].key] = controls[i]
		end
		return by_key
	end

	Module.schema_builder = SchemaBuilder

	return SchemaBuilder
end
