local mod = get_mod("HavocConditionManager")
local base_mod = get_mod("SoloPlay")
local Promise = require("scripts/foundation/utilities/promise")
local Havoc = require("scripts/utilities/havoc")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIRenderer = require("scripts/managers/ui/ui_renderer")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local ScriptWorld = require("scripts/foundation/utilities/script_world")
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local ViewElementGrid = require("scripts/ui/view_elements/view_element_grid/view_element_grid")
local DropdownPassTemplates = require("scripts/ui/pass_templates/dropdown_pass_templates")
local SoloPlaySettings = base_mod:io_dofile("SoloPlay/scripts/mods/SoloPlay/SoloPlaySettings")
mod.extend_condition_settings(SoloPlaySettings)
local HavocConditions = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/havoc_conditions")
local SpawnMultipliers = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/spawn_scaling")
local make_options = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/condition_manager_view/make_options")
local Paging = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/condition_manager_view/paging")
local definitions = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/condition_manager_view/condition_manager_view_definitions")
local blueprints = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/condition_manager_view/condition_manager_view_blueprints")
local view_settings = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/condition_manager_view/condition_manager_view_settings")

local addon_setting_keys = {
	[HavocConditions.storage_key] = true,
	spawn_generation_mode = true,
	havoc_add_circumstance = true,
	havoc_remove_circumstance = true,
}

for _, setting_id in ipairs(SpawnMultipliers.ordered_setting_ids) do
	addon_setting_keys[setting_id] = true
end

local function get_setting(key)
	local owner = addon_setting_keys[key] and mod or base_mod

	return owner:get(key)
end

local function set_setting(key, value)
	local owner = addon_setting_keys[key] and mod or base_mod

	owner:set(key, value)
end

HavocConditionManagerView = class("HavocConditionManagerView", "BaseView")

HavocConditionManagerView.init = function (self, settings)
	self._selected_setting = nil
	self._close_selected_setting = false

	self._modifier_grid = nil
	self._dropdown_widgets = {}
	self._havoc_difficulty_slider_widget = nil
	self._havoc_difficulty_badge_widget = nil
	self._spawn_multiplier_widgets = {}
	self._spawn_multiplier_values = {}

	self._modifier_customizable = false
	self._current = {}
	self._current_modifier = {}
	self._current_havoc_difficulty = 1
	self._pending_condition_refresh = false
	self._options = {}
	for _, id in ipairs(view_settings.dropdown_all_ids) do
		self._options[id] = {}
	end
	for modifier_name in pairs(SoloPlaySettings.lookup.havoc_modifiers_max_level) do
		self._current_modifier[modifier_name] = 0
	end

	HavocConditionManagerView.super.init(self, definitions, settings)
end

HavocConditionManagerView._build_dropdown_definition = function (self, id)
	local related_ids = view_settings.dropdown_related_ids[id] or {}
	local is_add_condition = id == "havoc_add_circumstance"
	local is_remove_condition = id == "havoc_remove_circumstance"

	return {
		id = id,
		pivot = id,
		display_name = "",
		widget_type = "dropdown",
		on_activated = function (value, entry)
			if is_add_condition then
				self:_add_havoc_circumstance(value)
			elseif is_remove_condition then
				self:_remove_havoc_circumstance(value)
			else
				self._current[id] = value
				set_setting(view_settings.dropdown_setting_keys[id], value)
				for _, related_id in ipairs(related_ids) do
					self:_recreate_dropdown(related_id)
				end
				mod.refresh_condition_generators()
			end
		end,
		get_function = function (entry)
			return self._current[id]
		end,
		options_function = function (...)
			return self._options[id]
		end,
	}
end

HavocConditionManagerView.on_enter = function (self)
	HavocConditionManagerView.super.on_enter(self)

	self:_setup_input_legend()
	self:_setup_normal_difficulty()
	self:_setup_havoc_difficulty()

	self:_load_havoc_circumstances()

	for _, id in ipairs(view_settings.dropdown_all_ids) do
		self:_recreate_dropdown(id)
	end

	for modifier_name in pairs(SoloPlaySettings.lookup.havoc_modifiers_max_level) do
		self._current_modifier[modifier_name] = self:_load_modifier_selection(modifier_name)
	end
	self:_setup_modifier_grid()

	self._widgets_by_name.havoc_modifier_lock.content.hotspot.pressed_callback = callback(self, "cb_on_havoc_modifier_lock")
	self._widgets_by_name.normal_start.content.hotspot.pressed_callback = callback(self, "cb_on_normal_start")
	self._widgets_by_name.havoc_randomize.content.hotspot.pressed_callback = callback(self, "cb_on_havoc_randomize")
	self._widgets_by_name.havoc_start.content.hotspot.pressed_callback = callback(self, "cb_on_havoc_start")

	self._modifier_customizable = get_setting("havoc_modifiers_customizable") or false
	self:_update_modifiers_lock()
	self:_update_havoc_circumstance_summary()
	Paging.enter(self, SoloPlaySettings)
end

HavocConditionManagerView._persist_havoc_circumstances = function (self)
	local selected = HavocConditions.sanitize(
		self._current.havoc_circumstances,
		SoloPlaySettings.lookup.havoc_circumstances,
		HavocConditions.max_primary
	)

	self._current.havoc_circumstances = selected
	set_setting(HavocConditions.storage_key, HavocConditions.encode(selected))
	mod.refresh_condition_generators()
	self._hcm_refresh = true
end

HavocConditionManagerView._load_havoc_circumstances = function (self)
	local serialized = get_setting(HavocConditions.storage_key)
	mod.condition_catalog.migrate_difficulty(HavocConditions.decode(serialized), base_mod)
	local selected = HavocConditions.sanitize(
		HavocConditions.decode(serialized),
		SoloPlaySettings.lookup.havoc_circumstances,
		HavocConditions.max_primary
	)

	if serialized == nil then
		local ordered = SoloPlaySettings.order.havoc_circumstances
		local first = ordered[1]
		local second = ordered[3] or ordered[2]

		if first then
			selected[#selected + 1] = first
		end
		if second and second ~= first then
			selected[#selected + 1] = second
		end
	end

	self._current.havoc_circumstances = selected
	self:_persist_havoc_circumstances()
end

HavocConditionManagerView._condition_display_name = function (self, circumstance_name)
	return SoloPlaySettings.loc.havoc_circumstances[circumstance_name]
		or SoloPlaySettings.loc.circumstances[circumstance_name]
		or circumstance_name
end

HavocConditionManagerView._queue_condition_refresh = function (self)
	self._current.havoc_add_circumstance = "default"
	self._current.havoc_remove_circumstance = "default"
	set_setting("havoc_add_circumstance", "default")
	set_setting("havoc_remove_circumstance", "default")
	self._pending_condition_refresh = true
end

HavocConditionManagerView._add_havoc_circumstance = function (self, circumstance_name)
	if circumstance_name == "default" then
		return
	end

	local selected, status = HavocConditions.add(
		self._current.havoc_circumstances,
		circumstance_name,
		SoloPlaySettings.lookup.havoc_circumstances,
		HavocConditions.max_primary
	)

	self._current.havoc_circumstances = selected
	if status == "added" then
		self:_persist_havoc_circumstances()
		mod:notify(mod:localize("message_havoc_condition_added", self:_condition_display_name(circumstance_name)))
	elseif status == "duplicate" then
		mod:notify(mod:localize("message_havoc_condition_duplicate"))
	elseif status == "full" then
		mod:notify(mod:localize("message_havoc_condition_limit", HavocConditions.max_primary))
	end

	self:_queue_condition_refresh()
end

HavocConditionManagerView._remove_havoc_circumstance = function (self, circumstance_name)
	if circumstance_name == "default" then
		return
	end

	local selected, status = HavocConditions.remove(self._current.havoc_circumstances, circumstance_name, 0)

	self._current.havoc_circumstances = selected
	if status == "removed" then
		self:_persist_havoc_circumstances()
		mod:notify(mod:localize("message_havoc_condition_removed", self:_condition_display_name(circumstance_name)))
	elseif status == "minimum" then
		mod:notify(mod:localize("message_havoc_condition_minimum"))
	end

	self:_queue_condition_refresh()
end

HavocConditionManagerView._update_havoc_circumstance_summary = function (self)
	local widget = self._widgets_by_name.havoc_conditions_summary

	if widget then
		local selected = self._current.havoc_circumstances or {}
		widget.content.havoc_conditions_summary = mod:localize(
			"label_selected_havoc_conditions",
			#selected,
			#SoloPlaySettings.order.havoc_circumstances
		)
	end
end

HavocConditionManagerView._refresh_condition_dropdowns = function (self)
	self:_set_exclusive_focus_on_setting(nil)
	self:_recreate_dropdown("havoc_add_circumstance")
	self:_recreate_dropdown("havoc_remove_circumstance")
	self:_update_havoc_circumstance_summary()
end

HavocConditionManagerView._recreate_dropdown = function (self, id)
	self._options[id] = make_options[id](self._current)
	self._current[id] = self:_load_dropdown_selection(
		view_settings.dropdown_setting_keys[id],
		self._options[id],
		view_settings.dropdown_setting_default[id]
	)
	set_setting(view_settings.dropdown_setting_keys[id], self._current[id])
	self._dropdown_widgets[id] = self:_setup_dropdown(self:_build_dropdown_definition(id))
end

HavocConditionManagerView._load_dropdown_selection = function (self, setting_name, lookup, default)
	local value = get_setting(setting_name)
	if not value then
		if type(default) == "number" then
			value = lookup[default].value
		else
			value = default
		end
	end
	local valid = false
	for _, option in ipairs(lookup) do
		if option.value == value then
			valid = true
			break
		end
	end
	if valid then
		return value
	end
	if #lookup >= 1 then
		return lookup[1].value
	end
	return nil
end

HavocConditionManagerView._load_modifier_selection = function (self, modifier_name)
	local key = "havoc_modifier_" .. modifier_name
	local value = get_setting(key) or 0
	local max = SoloPlaySettings.lookup.havoc_modifiers_max_level[modifier_name]
	if value > max then
		value = max
	end
	set_setting(key, value)
	return value
end

HavocConditionManagerView._setup_normal_difficulty = function (self)
	self._widgets_by_name.normal_difficulty.content.min_danger = 1
	self._widgets_by_name.normal_difficulty.content.max_danger = 5
	self._widgets_by_name.normal_difficulty.content.danger = get_setting("choose_difficulty") or 3
	self._widgets_by_name.normal_difficulty.content.on_changed_callback = callback(self, "cb_on_normal_difficulty_changed")
	set_setting("choose_difficulty", self._widgets_by_name.normal_difficulty.content.danger)
end

HavocConditionManagerView._setup_havoc_difficulty = function (self)
	local previous_havoc_diffculty = get_setting("havoc_difficulty")
	self._current_havoc_difficulty = previous_havoc_diffculty or 16
	set_setting("havoc_difficulty", self._current_havoc_difficulty)
	if not previous_havoc_diffculty then
		self:_apply_modifiers(Havoc.parse_data(Havoc.generate_havoc_data(self._current_havoc_difficulty)).modifiers)
	end

	local widget_definition = UIWidget.create_definition(blueprints.havoc_difficulty_slider.pass_template, "havoc_difficulty", nil, view_settings.difficulty_slider_size)
	local widget = self:_create_widget("havoc_difficulty_slider", widget_definition)
	local entry = {
		widget_type = "value_slider",
		display_name = "",
		step_size_value = 1,
		min_value = 1,
		max_value = view_settings.havoc_max_level,
		default_value = 1,
		explode_function = function (normalized_value)
			local step_size, min_value, max_value = 1, 1, view_settings.havoc_max_level
			local value_range = max_value - min_value
			local exploded_value = min_value + normalized_value * value_range
			exploded_value = math.round(exploded_value / step_size) * step_size
			return exploded_value
		end,
		format_value_function = function (value)
			return value
		end,
		on_drag_value = function (value, entry)
			self:_setup_havoc_badge(value)
		end,
		on_activated = function (value, entry)
			self._current_havoc_difficulty = value
			set_setting("havoc_difficulty", value)
			self:_setup_havoc_badge(value)
			self:_refresh_modifiers()
		end,
		get_function = function (entry)
			return self._current_havoc_difficulty
		end,
	}
	blueprints.havoc_difficulty_slider.init(self, widget, entry, "cb_on_slider_pressed")
	self._havoc_difficulty_slider_widget = widget
	self:_setup_havoc_badge()
end

HavocConditionManagerView._setup_havoc_badge = function (self, rank)
	local widget_definition = UIWidget.create_definition(blueprints.havoc_badge.pass_template_function(rank), "havoc_difficulty_badge", nil, view_settings.havoc_badge_size)
	local widget = self:_create_widget("havoc_difficulty_badge", widget_definition)
	self._havoc_difficulty_badge_widget = widget
end

HavocConditionManagerView._setup_spawn_multipliers = function (self)
	for _, setting_id in ipairs(view_settings.spawn_multiplier_ids) do
		local current_setting_id = setting_id
		local value = SpawnMultipliers.normalize(get_setting(setting_id))
		local widget_definition = UIWidget.create_definition(
			blueprints.spawn_multiplier_slider.pass_template,
			setting_id,
			nil,
			view_settings.spawn_multiplier_size
		)
		local widget = self:_create_widget(setting_id, widget_definition)
		local entry = {
			widget_type = "value_slider",
			display_name = mod:localize(view_settings.spawn_multiplier_label_loc_keys[setting_id]),
			step_size_value = 1,
			min_value = view_settings.spawn_multiplier_minimum,
			max_value = view_settings.spawn_multiplier_maximum,
			default_value = view_settings.spawn_multiplier_default,
			slider_size = view_settings.spawn_multiplier_size,
			slider_setting_width = view_settings.spawn_multiplier_setting_width,
			align_slider_to_setting = true,
			explode_function = function (normalized_value)
				local minimum = view_settings.spawn_multiplier_minimum
				local maximum = view_settings.spawn_multiplier_maximum
				local value_range = maximum - minimum
				local exploded_value = minimum + normalized_value * value_range

				return SpawnMultipliers.normalize(exploded_value)
			end,
			format_value_function = function (current_value)
				return string.format("%d×", SpawnMultipliers.normalize(current_value))
			end,
			on_activated = function (new_value)
				new_value = SpawnMultipliers.normalize(new_value)
				self._spawn_multiplier_values[current_setting_id] = new_value
				set_setting(current_setting_id, new_value)
			end,
			get_function = function ()
				return self._spawn_multiplier_values[current_setting_id]
			end,
		}

		self._spawn_multiplier_values[setting_id] = value
		set_setting(setting_id, value)
		blueprints.spawn_multiplier_slider.init(self, widget, entry, "cb_on_slider_pressed")
		self._spawn_multiplier_widgets[setting_id] = widget
	end
end

HavocConditionManagerView._setup_dropdown = function (self, entry)
	local size = view_settings.dropdown_size
	local options = entry.options or entry.options_function and entry.options_function()
	local num_options = #options
	local num_visible_options = math.min(num_options, view_settings.dropdown_max_visible_options)
	local pass_templates = DropdownPassTemplates.settings_dropdown(size[1], size[2], view_settings.dropdown_setting_width, num_visible_options, true)

	local widget_definition = UIWidget.create_definition(pass_templates, entry.pivot, nil, size)
	local widget = self:_create_widget(entry.id, widget_definition)
	local content = widget.content

	content.text = entry.display_name
	content.entry = entry
	content.num_visible_options = num_visible_options

	local optional_num_decimals = entry.optional_num_decimals
	local number_format = string.format("%%.%sf", optional_num_decimals or view_settings.dropdown_default_num_decimals)
	local options_by_id = {}

	for index, option in pairs(options) do
		options_by_id[option.id] = option
	end

	content.number_format = number_format
	content.options_by_id = options_by_id
	content.options = options
	content.hotspot.pressed_callback = callback(self, "cb_on_dropdown_pressed", widget, entry)

	content.area_length = size[2] * num_visible_options
	local scroll_length = math.max(size[2] * num_options - content.area_length, 0)
	content.scroll_length = scroll_length

	local spacing = 0
	local scroll_amount = scroll_length > 0 and (size[2] + spacing) / scroll_length or 0
	content.scroll_amount = scroll_amount

	return widget
end

HavocConditionManagerView._setup_modifier_grid = function (self)
	self._modifier_grid = self:_add_element(ViewElementGrid, "modifier_grid", 80, view_settings.grid_settings, "havoc_modifiers_grid")
	self._modifier_grid:set_visibility(true)
	self._modifier_grid:present_grid_layout({}, {})
	local layout = {}

	for _, modifier_name in ipairs(SoloPlaySettings.order.havoc_modifiers) do
		layout[#layout + 1] = {
			widget_type = "modifier_slider",
			modifier_name = modifier_name,
			display_name = "",
			step_size_value = 1,
			min_value = 0,
			max_value = SoloPlaySettings.lookup.havoc_modifiers_max_level[modifier_name] or 5,
			default_value = 1,
			explode_function = function (normalized_value)
				local step_size, min_value, max_value = 1, 0, SoloPlaySettings.lookup.havoc_modifiers_max_level[modifier_name] or 5
				local value_range = max_value - min_value
				local exploded_value = min_value + normalized_value * value_range
				exploded_value = math.round(exploded_value / step_size) * step_size
				return exploded_value
			end,
			format_value_function = function (value)
				return value
			end,
			on_activated = function (value, entry)
				self._current_modifier[modifier_name] = value
				set_setting("havoc_modifier_" .. modifier_name, value)
			end,
			get_function = function (entry)
				return self._current_modifier[modifier_name]
			end,
		}
	end

	local spacing_entry = {
		widget_type = "spacing_vertical"
	}

	table.insert(layout, 1, spacing_entry)
	table.insert(layout, #layout + 1, spacing_entry)

	local on_pressed_callback = callback(self, "cb_on_slider_pressed")
	self._modifier_grid:present_grid_layout(layout, blueprints, on_pressed_callback)
end

HavocConditionManagerView._setup_input_legend = function (self)
	self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 100)
	local legend_inputs = self._definitions.legend_inputs

	for i = 1, #legend_inputs do
		local legend_input = legend_inputs[i]
		local on_pressed_callback = legend_input.on_pressed_callback and callback(self, legend_input.on_pressed_callback)

		self._input_legend_element:add_entry(
			legend_input.display_name,
			legend_input.input_action,
			legend_input.visibility_function,
			on_pressed_callback,
			legend_input.alignment
		)
	end
end

HavocConditionManagerView._get_modifier_display_name = function (self, name, level)
	local level_loc = SoloPlaySettings.loc.havoc_modifiers[name] or {}
	return level_loc[level] or "n/a"
end

HavocConditionManagerView._set_exclusive_focus_on_setting = function (self, widget_name)
	local widgets = {}
	for name in pairs(self._dropdown_widgets) do
		widgets[#widgets+1] = self._dropdown_widgets[name]
	end
	for _, widget in pairs(self._spawn_multiplier_widgets) do
		widgets[#widgets+1] = widget
	end

	local selected_widget = nil
	for _, widget in ipairs(widgets) do
		local selected = widget.name == widget_name
		local content = widget.content
		content.exclusive_focus = selected
		local hotspot = content.hotspot or content.button_hotspot

		if hotspot then
			hotspot.is_selected = selected
			if selected then
				selected_widget = widget
			end
		end
	end
	self._selected_setting = selected_widget

	for _, widget in ipairs(widgets) do
		if widget.content.hotspot then
			if selected_widget then
				widget.content.hotspot.disabled = widget ~= selected_widget
			else
				widget.content.hotspot.disabled = false
			end
		end
	end

	local normal_difficulty = self._widgets_by_name.normal_difficulty
	local havoc_difficulty = self._havoc_difficulty_slider_widget
	local normal_difficulty_hotspot_names = {
		"hotspot_left", "hotspot_right",
		"hotspot_1", "hotspot_2", "hotspot_3", "hotspot_4", "hotspot_5",
	}

	if selected_widget then
		self._modifier_grid:disable_input(true)

		for _, widget in pairs(self._spawn_multiplier_widgets) do
			widget.content.entry.disabled = widget ~= selected_widget
		end

		for _, name in ipairs(normal_difficulty_hotspot_names) do
			normal_difficulty.content[name].disabled = true
		end
		normal_difficulty.content.disabled = true

		if havoc_difficulty.content.hotspot then
			havoc_difficulty.content.hotspot.disabled = true
		end

		self._widgets_by_name.havoc_modifier_lock.content.hotspot.disabled = true
		self._widgets_by_name.havoc_randomize.content.hotspot.disabled = true
		self._widgets_by_name.normal_start.focus_disabled = true
		self._widgets_by_name.havoc_start.focus_disabled = true

	else
		self._modifier_grid:disable_input(false)

		for _, widget in pairs(self._spawn_multiplier_widgets) do
			widget.content.entry.disabled = false
		end

		for _, name in ipairs(normal_difficulty_hotspot_names) do
			normal_difficulty.content[name].disabled = false
		end
		normal_difficulty.content.disabled = false
		normal_difficulty.content.enable_time = Managers.time:time("main")

		if havoc_difficulty.content.hotspot then
			havoc_difficulty.content.hotspot.disabled = false
		end

		self._widgets_by_name.havoc_modifier_lock.content.hotspot.disabled = false
		self._widgets_by_name.havoc_randomize.content.hotspot.disabled = false
		self._widgets_by_name.normal_start.focus_disabled = false
		self._widgets_by_name.havoc_start.focus_disabled = false
	end
end

HavocConditionManagerView._update_modifiers_lock = function (self)
	for _, widget in ipairs(self._modifier_grid._grid_widgets) do
		if widget.content.hotspot then
			widget.content.hotspot.disabled = not self._modifier_customizable
		end
	end

	local button_icon = " "
	if self._modifier_customizable then
		button_icon = " "
	end
	self._widgets_by_name.havoc_modifier_lock.content.original_text = base_mod:localize("button_modifier_customizable") .. button_icon
end

HavocConditionManagerView._refresh_modifiers = function (self)
	if not self._modifier_customizable then
		self:_apply_modifiers(Havoc.parse_data(Havoc.generate_havoc_data(self._current_havoc_difficulty)).modifiers)
	end
end

HavocConditionManagerView._apply_modifiers = function (self, modifier_data)
	modifier_data = modifier_data or {}
	local data_map = {}
	for _, data in ipairs(modifier_data) do
		data_map[data.name] = data.level
	end
	for modifier_name in pairs(SoloPlaySettings.lookup.havoc_modifiers_max_level) do
		local level = data_map[modifier_name] or 0
		self._current_modifier[modifier_name] = level
		set_setting("havoc_modifier_" .. modifier_name, level)
	end
end

HavocConditionManagerView._regen_havoc = function (self)
	local havoc = base_mod.gen_havoc_data(self._current_havoc_difficulty)
	self._current.havoc_circumstances = HavocConditions.sanitize({
		havoc.circumstance1,
		havoc.circumstance2,
	}, SoloPlaySettings.lookup.havoc_circumstances, HavocConditions.max_primary)
	self:_persist_havoc_circumstances()
	for _, setting in ipairs(view_settings.regen_havoc_settings) do
		self._current[setting.id] = havoc[setting.data]
		set_setting(view_settings.dropdown_setting_keys[setting.id], havoc[setting.data])
		self:_recreate_dropdown(setting.id)
	end
	self:_recreate_dropdown("havoc_mission_giver")
	self:_refresh_condition_dropdowns()
	self:_apply_modifiers(havoc.modifiers)
end

HavocConditionManagerView.cb_on_normal_difficulty_changed = function (self)
	set_setting("choose_difficulty", self._widgets_by_name.normal_difficulty.content.danger)
end

HavocConditionManagerView.cb_on_dropdown_pressed = function (self, widget, entry)
	local pressed_function = entry.pressed_function
	self:_set_exclusive_focus_on_setting(entry.id)
	if pressed_function then
		pressed_function(self, widget, entry)
	end
end

HavocConditionManagerView.cb_on_slider_pressed = function (self, widget, entry)
	local pressed_function = entry.pressed_function
	if pressed_function then
		pressed_function(self, widget, entry)
	end
end

HavocConditionManagerView.cb_on_havoc_modifier_lock = function (self, widget, entry)
	self._modifier_customizable = not self._modifier_customizable
	set_setting("havoc_modifiers_customizable", self._modifier_customizable)
	self:_refresh_modifiers()
	self:_update_modifiers_lock()
end

HavocConditionManagerView._start_game = function (self, mode)
	if not base_mod.can_start_game() then
		return
	end
	self:_play_sound(UISoundEvents.mission_board_start_mission)
	Managers.ui:close_view(self.view_name)

	Promise.until_true(function ()
		return not Managers.ui:view_active(self.view_name)
	end):next(function ()
		base_mod.start_game(mode)
	end)
end

HavocConditionManagerView.cb_on_normal_start = function (self, widget, entry)
	self:_start_game("normal")
end

HavocConditionManagerView.cb_on_havoc_randomize = function (self, widget, entry)
	self:_regen_havoc()
end

HavocConditionManagerView.cb_on_havoc_start = function (self, widget, entry)
	self:_start_game("havoc")
end

HavocConditionManagerView._on_back_pressed = function (self)
	if Paging.numeric.cancel(self) then return end
	if Paging.close_choice(self) then return end
	Managers.ui:close_view(self.view_name)
end

HavocConditionManagerView._handle_input = function (self, input_service, dt, t)
	if self._selected_setting then
		local content = self._selected_setting.content
		local scrollbar_hotspot = content.scrollbar_hotspot
		local scrollbar_active = content.drag_active or (scrollbar_hotspot and scrollbar_hotspot.is_hover)
		local close_pressed = (input_service:get("left_pressed") and not scrollbar_active) or input_service:get("confirm_pressed") or input_service:get("back")
		local close_selected_setting = false
		if close_pressed then
			close_selected_setting = true
		end
		self._close_selected_setting = close_selected_setting
	end
end

HavocConditionManagerView.ui_renderer = function (self)
	return self._ui_renderer
end

HavocConditionManagerView._destroy_renderer = function (self)
	if self._offscreen_renderer then
		self._offscreen_renderer = nil
	end

	local world_data = self._offscreen_world
	if world_data then
		Managers.ui:destroy_renderer(world_data.renderer_name)
		ScriptWorld.destroy_viewport(world_data.world, world_data.viewport_name)
		Managers.ui:destroy_world(world_data.world)

		world_data = nil
	end
end

HavocConditionManagerView.update = function (self, dt, t, input_service)
	Paging.update(self, input_service)
	if self._hcm_refresh then
		self._hcm_refresh = false
		Paging.refresh(self, SoloPlaySettings)
		self:_update_havoc_circumstance_summary()
	end
	for _, widget in pairs(self._dropdown_widgets) do
		if widget and widget.visible ~= false then
			blueprints.settings_dropdown.update(self, widget, input_service, dt, t)
		end
	end
	for _, widget in pairs(self._spawn_multiplier_widgets) do
		if widget and widget.visible ~= false then
			blueprints.spawn_multiplier_slider.update(self, widget, input_service, dt, t)
		end
	end
	if self._havoc_difficulty_slider_widget and self._havoc_difficulty_slider_widget.visible ~= false then
		blueprints.havoc_difficulty_slider.update(self, self._havoc_difficulty_slider_widget, input_service, dt, t)
	end
	if self._pending_condition_refresh then
		self._pending_condition_refresh = false
		self:_refresh_condition_dropdowns()
	end

	if self._selected_setting and self._close_selected_setting then
		self:_set_exclusive_focus_on_setting(nil)
		self._close_selected_setting = nil
	end

	local solo_unavailable = not base_mod.can_start_game()
	local normal_start = self._widgets_by_name.normal_start
	if normal_start then
		normal_start.content.hotspot.disabled = normal_start.visible == false or solo_unavailable or normal_start.focus_disabled or false
	end
	local havoc_start = self._widgets_by_name.havoc_start
	if havoc_start then
		havoc_start.content.hotspot.disabled = havoc_start.visible == false or solo_unavailable or havoc_start.focus_disabled or false
	end

	self:_handle_input(input_service, dt, t)
	return HavocConditionManagerView.super.update(self, dt, t, input_service)
end

HavocConditionManagerView.draw = function (self, dt, t, input_service, layer)
	HavocConditionManagerView.super.draw(self, dt, t, input_service, layer)

	local ui_renderer = self._modifier_grid._ui_grid_renderer
	UIRenderer.begin_pass(ui_renderer, self._ui_scenegraph, input_service, dt, self._render_settings)
	for _, widget in pairs(self._dropdown_widgets) do
		if widget and widget.visible ~= false then
			UIWidget.draw(widget, ui_renderer)
		end
	end
	UIRenderer.end_pass(ui_renderer)
end

HavocConditionManagerView._draw_widgets = function (self, dt, t, input_service, ui_renderer, render_settings)
	if self._havoc_difficulty_slider_widget and self._havoc_difficulty_slider_widget.visible ~= false then
		UIWidget.draw(self._havoc_difficulty_slider_widget, ui_renderer)
	end
	if self._havoc_difficulty_badge_widget and self._havoc_difficulty_badge_widget.visible ~= false then
		UIWidget.draw(self._havoc_difficulty_badge_widget, ui_renderer)
	end
	for _, widget in pairs(self._spawn_multiplier_widgets) do
		if widget and widget.visible ~= false then
			UIWidget.draw(widget, ui_renderer)
		end
	end
	HavocConditionManagerView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

HavocConditionManagerView.on_exit = function (self)
	Paging.numeric.cancel(self)
	HavocConditionManagerView.super.on_exit(self)
	self:_destroy_renderer()
end

return HavocConditionManagerView
