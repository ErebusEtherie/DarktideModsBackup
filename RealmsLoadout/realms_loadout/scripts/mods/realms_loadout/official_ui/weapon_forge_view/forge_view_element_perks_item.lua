local ui_owner = get_mod("realms_loadout")
if ui_owner._ui_class_RealmsForgeViewElementPerksItem then
    return ui_owner._ui_class_RealmsForgeViewElementPerksItem
end

-- chunkname: @scripts/ui/view_elements/view_element_perks_item/view_element_perks_item.lua

local ForgeViewElementPerksItemBlueprints = require("realms_loadout/scripts/mods/realms_loadout/official_ui/weapon_forge_view/forge_view_element_perks_item_blueprints")
local ForgeViewElementPerksItemDefinitions = require("realms_loadout/scripts/mods/realms_loadout/official_ui/weapon_forge_view/forge_view_element_perks_item_definitions")
local InputDevice = require("scripts/managers/input/input_device")
local Mastery = require("scripts/utilities/mastery")
local Promise = require("scripts/foundation/utilities/promise")
local RankSettings = require("scripts/settings/item/rank_settings")
local mod = get_mod("realms_loadout")
local UIAnimation = require("scripts/managers/ui/ui_animation")
local UIWidget = require("scripts/managers/ui/ui_widget")

require("scripts/ui/view_elements/view_element_grid/view_element_grid")

local ForgeViewElementPerksItem = class("RealmsForgeViewElementPerksItem", "ViewElementGrid")

function ForgeViewElementPerksItem:init(parent, draw_layer, start_scale, optional_menu_settings)
	self._reference_name = "ForgeViewElementPerksItem_" .. tostring(self)

	local definitions = ForgeViewElementPerksItemDefinitions

	ForgeViewElementPerksItem.super.init(self, parent, draw_layer, start_scale, definitions.menu_settings, definitions)
	self:present_grid_layout({}, ForgeViewElementPerksItemBlueprints)
	self:_setup_tabs()

	self._ui_animations = {}
	self._alpha_multiplier = optional_menu_settings and optional_menu_settings.do_animations and 0 or 1
	self._do_animations = optional_menu_settings and optional_menu_settings.do_animations
	self._active = not self._do_animations
end

function ForgeViewElementPerksItem:destroy(ui_renderer)
	local backend_promise = self._backend_promise

	if backend_promise and backend_promise:is_pending() then
		backend_promise:cancel()

		self._backend_promise = nil
	end

	if self._weapon_stats then
		self._weapon_stats:destroy()

		self._weapon_stats = nil
	end

	ForgeViewElementPerksItem.super.destroy(self, ui_renderer)
end

function ForgeViewElementPerksItem:show_overlay(show)
	local widget = self._widgets_by_name.overlay
	local style = widget.style
	local color = style.overlay.color
	local ui_scenegraph = self._ui_scenegraph
	local func = UIAnimation.function_by_time
	local target = color
	local target_index = 1
	local from = color[1]
	local to = show and 128 or 0
	local duration = 0.5
	local easing = math.easeOutCubic

	self._ui_animations.pivot = UIAnimation.init(func, target, target_index, from, to, duration, easing)
end

function ForgeViewElementPerksItem:clear_marks()
	local widgets = self:widgets()

	for i = 1, #widgets do
		local recipe_widget = widgets[i]
		local content = recipe_widget.content

		content.marked = false
	end

	self._marked_widget = nil
	self._marked_perk_item = nil

	local index = self._parent._ingredients.existing_perk_index

	self._parent._weapon_stats:preview_perk(index)
end

function ForgeViewElementPerksItem:cb_on_grid_entry_left_pressed(widget, config)
	if not self._active then
		return
	end

	local perk_item = config.perk_item

	if self._marked_perk_item == perk_item or self:is_perk_selected(perk_item) then
		perk_item = nil
		widget = nil
	end

	self._marked_widget = widget
	self._marked_perk_item = perk_item

	local external_left_click_callback = self._external_left_click_callback

	if external_left_click_callback then
		external_left_click_callback(widget, config)
	end

	local recipe_widgets = self:widgets()

	for i = 1, #recipe_widgets do
		local recipe_widget = recipe_widgets[i]
		local content = recipe_widget.content

		content.marked = widget and recipe_widget == widget or false
	end

	if widget or self._using_cursor_navigation then
		self:select_grid_widget(widget)
	end

	if self._ingredients and self._ingredients.item then
		self:refresh_selected_marks(self._ingredients.item)
	end
end

function ForgeViewElementPerksItem:cb_on_grid_entry_right_pressed(widget, config)
	if not self._active then
		return
	end

	local external_right_click_callback = self._external_right_click_callback

	if external_right_click_callback then
		external_right_click_callback(widget, config)
	end
end

function ForgeViewElementPerksItem:deselect_marked_perk()
	local widgets = self:widgets()

	for i = 1, #widgets do
		widgets[i].content.marked = false
	end

	self._marked_widget = nil
	self._marked_perk_item = nil
end

function ForgeViewElementPerksItem:refresh_selected_marks(item)
	local selected = {}

	if item and item.perks then
		for i = 1, #item.perks do
			local slot = item.perks[i]

			if slot.id then
				selected[slot.id .. ":" .. tostring(slot.rarity or 0)] = true
			end
		end
	end

	local widgets = self:widgets()

	for i = 1, #widgets do
		local recipe_widget = widgets[i]
		local config = recipe_widget.content.config
		local perk_item = config and config.perk_item

		if perk_item then
			recipe_widget.content.marked = selected[perk_item.name .. ":" .. tostring(perk_item.rarity or 0)] or false
		end
	end
end

function ForgeViewElementPerksItem:is_perk_selected(perk_item)
	if not perk_item then
		return false
	end

	local item = self._ingredients and self._ingredients.item
	local perks = item and item.perks

	if not perks then
		return false
	end

	for i = 1, #perks do
		local slot = perks[i]

		if slot.id == perk_item.name then
			return true
		end
	end

	return false
end

function ForgeViewElementPerksItem:marked_perk_item()
	return self._marked_perk_item
end

function ForgeViewElementPerksItem:marked_perk_cost()
	return self._marked_widget and self._marked_widget.content.cost
end

function ForgeViewElementPerksItem:_on_perk_hover(config)
	self._hovered_perk_item = config.perk_item
end

function ForgeViewElementPerksItem:start_animation()
	local ui_scenegraph = self._ui_scenegraph
	local func = UIAnimation.function_by_time
	local target = ui_scenegraph.pivot.local_position
	local target_index = 1
	local from = self._pivot_offset[1] - 500
	local to = self._pivot_offset[1]
	local duration = 0.5
	local easing = math.easeOutCubic

	self._ui_animations.pivot = UIAnimation.init(func, target, target_index, from, to, duration, easing)

	local func = UIAnimation.function_by_time
	local target = self
	local target_index = "_alpha_multiplier"
	local from = 0
	local to = 1
	local duration = 0.5
	local easing = math.easeInCubic

	self._ui_animations.alpha_multiplier = UIAnimation.init(func, target, target_index, from, to, duration, easing)
end

function ForgeViewElementPerksItem:disable()
	self._disabled = true

	self:select_grid_index(nil)
end

function ForgeViewElementPerksItem:enable()
	self._disabled = false

	if not self._using_cursor_navigation then
		self:select_best_widget()
	end
end

function ForgeViewElementPerksItem:hide()
	self._active = false
end

function ForgeViewElementPerksItem:show()
	self._active = true
end

function ForgeViewElementPerksItem:active()
	return self._active and not self._disabled
end

function ForgeViewElementPerksItem:select_best_widget(allow_only_marked_widget)
	local marked_perk_item = self._marked_perk_item
	local marked_perk_item_id = marked_perk_item and marked_perk_item.name
	local marked_perk_item_rarity = marked_perk_item and marked_perk_item.rarity
	local widget_to_select
	local recipe_widgets = self:widgets()

	for i = 1, #recipe_widgets do
		local recipe_widget = recipe_widgets[i]
		local content = recipe_widget.content
		local config = content.config
		local perk_item = config and config.perk_item

		if perk_item then
			local perk_item_id = perk_item.name
			local perk_item_rarity = perk_item.rarity

			if not widget_to_select and not allow_only_marked_widget then
				widget_to_select = recipe_widget
			end

			local marked = perk_item_id == marked_perk_item_id and perk_item_rarity == marked_perk_item_rarity

			if marked then
				widget_to_select = recipe_widget
			end

			content.marked = marked
		end
	end

	self:select_grid_widget(widget_to_select)

	return widget_to_select
end

function ForgeViewElementPerksItem:set_alpha_multiplier(alpha_multiplier)
	self._alpha_multiplier = alpha_multiplier or 0
end

function ForgeViewElementPerksItem:draw(dt, t, ui_renderer, render_settings, input_service)
	if self._disabled or self._backend_promise ~= nil then
		input_service = input_service:null_service()
	end

	local old_alpha_multiplier = render_settings.alpha_multiplier
	local alpha_multiplier = self._active and self._alpha_multiplier or 0

	render_settings.alpha_multiplier = (render_settings.alpha_multiplier or 1) * alpha_multiplier

	ForgeViewElementPerksItem.super.draw(self, dt, t, ui_renderer, render_settings, input_service)

	render_settings.alpha_multiplier = old_alpha_multiplier
end

function ForgeViewElementPerksItem:_update_animations(dt, t)
	local ui_animations = self._ui_animations

	for key, ui_animation in pairs(ui_animations) do
		UIAnimation.update(ui_animation, dt)

		if UIAnimation.completed(ui_animation) then
			ui_animations[key] = nil
		end
	end

	if self._ui_animations.pivot then
		self._update_scenegraph = true
	end
end

function ForgeViewElementPerksItem:present_perks(item, ingredients, external_left_click_callback, do_animation, external_right_click_callback)
	if not item then
		self._active = true
		self._disabled = false
		self._max_unlocked = nil
		self._presented_masterid = nil

		return Promise:resolved()
	end

	local item_masterid = item.name
	local item_pattern = item.parent_pattern

	self._ingredients = ingredients
	self._external_left_click_callback = external_left_click_callback
	self._external_right_click_callback = external_right_click_callback

	if self._presented_masterid == item_masterid and self._perks_by_rank then
  self._backend_promise = nil
  self:set_loading_state(false)
  self._max_unlocked = self._max_unlocked or RankSettings.max_perk_rank

  self:_switch_to_rank_tab(self._max_unlocked, true)

  return Promise:resolved()
end

self._presented_masterid = item_masterid
self._backend_promise = Managers.data_service.crafting:get_item_crafting_metadata(item_masterid)

	self:set_loading_state(false)

	return self._backend_promise:next(function(data)
		self._perks_by_rank = data.perks
		self._backend_promise = Managers.data_service.mastery:get_mastery_by_pattern(item_pattern)

		return self._backend_promise
	end):next(function(mastery_data)
		local max_unlocked

		if not table.is_empty(mastery_data) then
			max_unlocked = Mastery.get_max_perk_rarity_unlocked_level(mastery_data)
		else
			max_unlocked = RankSettings.max_perk_rank
		end

		self._max_unlocked = max_unlocked

		local widgets_by_name = self._widgets_by_name

		for i = 1, RankSettings.max_perk_rank do
			local name = "rank_" .. i

			widgets_by_name[name].content.locked = max_unlocked < i
		end

		self:_switch_to_rank_tab(max_unlocked, true)

		if self._do_animations then
			self:start_animation()
		end

		self._active = true
		self._disabled = false
		self._backend_promise = nil

		self:set_loading_state(false)

		return max_unlocked
	end):catch(function()
		self._backend_promise = nil

		self:set_loading_state(false)

		local max_unlocked = RankSettings.max_perk_rank

		self._max_unlocked = max_unlocked

		local widgets_by_name = self._widgets_by_name

		for i = 1, RankSettings.max_perk_rank do
			local name = "rank_" .. i

			widgets_by_name[name].content.locked = max_unlocked < i
		end

		self:_switch_to_rank_tab(1, true)
	end)
end

function ForgeViewElementPerksItem:_setup_tabs()
	local tab_settings = {
		num_tabs = RankSettings.max_perk_rank
	}
	local widget_definitions = ForgeViewElementPerksItemDefinitions.create_tab_widgets(tab_settings)
	local widgets_by_name = self._widgets_by_name
	local widgets = self._widgets

	for i = 1, #widget_definitions do
		local name = "rank_" .. i
		local definition = widget_definitions[i]
		local widget = UIWidget.init(name, definition)

		widgets_by_name[name] = widget
		widgets[#widgets + 1] = widget
	end
end

function ForgeViewElementPerksItem:_switch_to_rank_tab(rank, initializing)
	self._rank = rank

	self:_update_tabs()
	self:_present(initializing)
end

function ForgeViewElementPerksItem:update(dt, t, input_service)
	if not self._active then
		return
	end

	if self._disabled or self._backend_promise ~= nil then
		input_service = input_service:null_service()
	end

	self:_handle_input(dt, t, input_service)
	self:_update_animations(dt, t)
	ForgeViewElementPerksItem.super.update(self, dt, t, input_service)
end

function ForgeViewElementPerksItem:_update_tabs()
	local current_rank = self._rank
	local widgets_by_name = self._widgets_by_name

	for i = 1, RankSettings.max_perk_rank do
		local widget_name = "rank_" .. i
		local widget = widgets_by_name[widget_name]
		local content = widget.content

		content.selected = current_rank == i
	end
end

function ForgeViewElementPerksItem:_handle_input(dt, t, input_service)
	if InputDevice.gamepad_active then
		local old_rank = self._rank
		local new_rank = old_rank

		if input_service:get("navigate_primary_left_pressed") then
			new_rank = math.clamp(self._rank - 1, 1, RankSettings.max_perk_rank)
		elseif input_service:get("navigate_primary_right_pressed") then
			new_rank = math.clamp(self._rank + 1, 1, RankSettings.max_perk_rank)
		elseif input_service:get("next") and type(self._parent.remove_next_ingredient) == "function" then
			self._parent:remove_next_ingredient()
		end

		if new_rank ~= old_rank then
			self:_switch_to_rank_tab(new_rank)
		end
	else
		local widgets_by_name = self._widgets_by_name

		for i = 1, RankSettings.max_perk_rank do
			local widget_name = "rank_" .. i
			local widget = widgets_by_name[widget_name]

			if widget then
				local content = widget.content
				local hotspot = content.hotspot

				if hotspot.on_pressed then
					self:_switch_to_rank_tab(i)

					return
				end
			end
		end
	end
end

function ForgeViewElementPerksItem:ingredients()
	return self._ingredients
end

function ForgeViewElementPerksItem:_present(first_presentation)
	if not self._perks_by_rank then
		return
	end

	local rank = self._rank
	local perks_data = self._perks_by_rank[self._rank].perks
	local layout = {}

	layout[#layout + 1] = {
		widget_type = "spacing_vertical_small"
	}

	for i = 1, #perks_data do
		local perk_name = perks_data[i]
		local MasterItems = require("scripts/backend/master_items")
		local perk_item = table.clone_instance(MasterItems.get_item(perk_name))

		perk_item.rarity = rank
		layout[#layout + 1] = {
			widget_type = "perk",
			perk_item = perk_item,
			perk_rarity = rank
		}
	end

	layout[#layout + 1] = {
		widget_type = "spacing_vertical"
	}

	local left_click_callback = callback(self, "cb_on_grid_entry_left_pressed")
	local on_present_callback = not first_presentation and callback(self, "_cb_present_grid_layout")

	self:present_grid_layout(layout, ForgeViewElementPerksItemBlueprints, left_click_callback, callback(self, "cb_on_grid_entry_right_pressed"), nil, nil, on_present_callback)
end

function ForgeViewElementPerksItem:_cb_present_grid_layout()
	if self._marked_perk_item or not self._using_cursor_navigation then
		local allow_only_marked_widget = self._using_cursor_navigation

		self:select_best_widget(allow_only_marked_widget)
	end

	self:refresh_selected_marks(self._ingredients and self._ingredients.item)
end

function ForgeViewElementPerksItem:_on_navigation_input_changed()
	ForgeViewElementPerksItem.super._on_navigation_input_changed(self)

	if not self._using_cursor_navigation and not self._disabled then
		self:select_best_widget()
	end
end

ui_owner._ui_class_RealmsForgeViewElementPerksItem = ForgeViewElementPerksItem
return ForgeViewElementPerksItem
