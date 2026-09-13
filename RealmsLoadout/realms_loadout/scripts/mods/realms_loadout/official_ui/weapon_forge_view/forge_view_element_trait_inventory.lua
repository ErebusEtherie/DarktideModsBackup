local ui_owner = get_mod("realms_loadout")
if ui_owner._ui_class_RealmsForgeViewElementTraitInventory then
    return ui_owner._ui_class_RealmsForgeViewElementTraitInventory
end

-- chunkname: @scripts/ui/view_elements/view_element_trait_inventory/view_element_trait_inventory.lua

local ForgeViewElementTraitInventoryBlueprints = require("realms_loadout/scripts/mods/realms_loadout/official_ui/weapon_forge_view/forge_view_element_trait_inventory_blueprints")
local ForgeViewElementTraitInventoryDefinitions = require("realms_loadout/scripts/mods/realms_loadout/official_ui/weapon_forge_view/forge_view_element_trait_inventory_definitions")
local InputDevice = require("scripts/managers/input/input_device")
local Items = require("scripts/utilities/items")
local RankSettings = require("scripts/settings/item/rank_settings")
local UIAnimation = require("scripts/managers/ui/ui_animation")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local Text = require("scripts/utilities/ui/text")

local function _style_text_height(text, style, ui_renderer)
	local text_size = style.size
	local text_additional_size = style.size_addition
	local calculate_size = {
		text_size[1] or 0,
		text_size[2] or 0
	}

	if text_additional_size then
		calculate_size = {
			calculate_size[1] + text_additional_size[1],
			calculate_size[2] + text_additional_size[2]
		}
	end

	local text_height = Text.text_height(ui_renderer, text, style, calculate_size, true)

	return text_height
end

require("scripts/ui/view_elements/view_element_grid/view_element_grid")

local ForgeViewElementTraitInventory = class("RealmsForgeViewElementTraitInventory", "ViewElementGrid")

function ForgeViewElementTraitInventory:init(parent, draw_layer, start_scale, optional_menu_settings)
	self._reference_name = "ForgeViewElementTraitInventory_" .. tostring(self)

	local definitions = ForgeViewElementTraitInventoryDefinitions

	ForgeViewElementTraitInventory.super.init(self, parent, draw_layer, start_scale, definitions.menu_settings, definitions)
	self:present_grid_layout({}, ForgeViewElementTraitInventoryBlueprints)
	self:_setup_tabs()

	self._ui_animations = {}
	self._alpha_multiplier = optional_menu_settings and optional_menu_settings.do_animations and 0 or 1
	self._do_animations = optional_menu_settings and optional_menu_settings.do_animations
	self._active = not self._do_animations
end

function ForgeViewElementTraitInventory:destroy(ui_renderer)
	if self._weapon_stats then
		self._weapon_stats:destroy()

		self._weapon_stats = nil
	end

	ForgeViewElementTraitInventory.super.destroy(self, ui_renderer)
end

function ForgeViewElementTraitInventory:show_overlay(show)
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

function ForgeViewElementTraitInventory:clear_marks()
	local widgets = self:widgets()

	for i = 1, #widgets do
		local recipe_widget = widgets[i]
		local content = recipe_widget.content

		content.marked = false
	end

	self._marked_widget = nil
	self._marked_trait_item = nil

	local index = self._parent._ingredients.existing_trait_index

	self._parent._weapon_stats:preview_trait(index)
end

function ForgeViewElementTraitInventory:cb_on_grid_entry_left_pressed(widget, config)
	if not self._active then
		return
	end

	local trait_item = config.trait_item

	if self._marked_trait_item == trait_item or self:is_trait_selected(trait_item) then
		trait_item = nil
		widget = nil
	end

	self._marked_widget = widget
	self._marked_trait_item = trait_item

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

function ForgeViewElementTraitInventory:cb_on_grid_entry_right_pressed(widget, config)
	if not self._active then
		return
	end

	local external_right_click_callback = self._external_right_click_callback

	if external_right_click_callback then
		external_right_click_callback(widget, config)
	end
end

function ForgeViewElementTraitInventory:deselect_marked_trait()
	local widgets = self:widgets()

	for i = 1, #widgets do
		widgets[i].content.marked = false
	end

	self._marked_widget = nil
	self._marked_trait_item = nil
end

function ForgeViewElementTraitInventory:is_trait_selected(trait_item)
	if not trait_item then
		return false
	end

	local item = self._ingredients and self._ingredients.item
	local traits = item and item.traits

	if not traits then
		return false
	end

	for i = 1, #traits do
		local slot = traits[i]

		if slot.id == trait_item.name then
			return true
		end
	end

	return false
end

function ForgeViewElementTraitInventory:refresh_selected_marks(item)
	local selected = {}

	if item and item.traits then
		for i = 1, #item.traits do
			local slot = item.traits[i]

			if slot.id then
				selected[slot.id .. ":" .. tostring(slot.rarity or 0)] = true
			end
		end
	end

	local widgets = self:widgets()

	for i = 1, #widgets do
		local recipe_widget = widgets[i]
		local config = recipe_widget.content.config
		local trait_item = config and config.trait_item

		if trait_item then
			recipe_widget.content.marked = selected[trait_item.name .. ":" .. tostring(trait_item.rarity or 0)] or false
		end
	end
end

function ForgeViewElementTraitInventory:marked_trait_item()
	return self._marked_trait_item
end

function ForgeViewElementTraitInventory:marked_trait_cost()
	return self._marked_widget and self._marked_widget.content.cost
end

function ForgeViewElementTraitInventory:_on_trait_hover(config)
	self._hovered_trait_item = config.trait_item
end

function ForgeViewElementTraitInventory:start_animation()
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

function ForgeViewElementTraitInventory:disable()
	self._disabled = true

	self:select_grid_index(nil)
end

function ForgeViewElementTraitInventory:enable()
	self._disabled = false

	if not self._using_cursor_navigation then
		self:select_best_widget()
	end
end

function ForgeViewElementTraitInventory:hide()
	self._active = false
end

function ForgeViewElementTraitInventory:show()
	self._active = true
end

function ForgeViewElementTraitInventory:active()
	return self._active and not self._disabled
end

function ForgeViewElementTraitInventory:select_best_widget(allow_only_marked_widget)
	local marked_trait_item = self._marked_trait_item
	local marked_trait_item_id = marked_trait_item and marked_trait_item.gear.masterDataInstance.id
	local marked_trait_item_rarity = marked_trait_item and marked_trait_item.rarity
	local widget_to_select
	local recipe_widgets = self:widgets()

	for i = 1, #recipe_widgets do
		local recipe_widget = recipe_widgets[i]
		local content = recipe_widget.content
		local config = content.config
		local trait_item = config and config.trait_item

		if trait_item then
			local trait_item_id = trait_item.gear.masterDataInstance.id
			local trait_item_rarity = trait_item.rarity

			if not widget_to_select and not allow_only_marked_widget then
				widget_to_select = recipe_widget
			end

			local marked = trait_item_id == marked_trait_item_id and trait_item_rarity == marked_trait_item_rarity

			if marked then
				widget_to_select = recipe_widget
			end

			content.marked = marked
		end
	end

	self:select_grid_widget(widget_to_select)

	return widget_to_select
end

function ForgeViewElementTraitInventory:set_alpha_multiplier(alpha_multiplier)
	self._alpha_multiplier = alpha_multiplier or 0
end

function ForgeViewElementTraitInventory:draw(dt, t, ui_renderer, render_settings, input_service)
	self:_update_info_box(ui_renderer)

	if self._disabled then
		input_service = input_service:null_service()
	end

	local old_alpha_multiplier = render_settings.alpha_multiplier
	local alpha_multiplier = self._active and self._alpha_multiplier or 0

	render_settings.alpha_multiplier = (render_settings.alpha_multiplier or 1) * alpha_multiplier

	ForgeViewElementTraitInventory.super.draw(self, dt, t, ui_renderer, render_settings, input_service)

	render_settings.alpha_multiplier = old_alpha_multiplier
end

function ForgeViewElementTraitInventory:_update_animations(dt, t)
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

function ForgeViewElementTraitInventory:_update_info_box(ui_renderer)
	local trait_info_box = self._widgets_by_name.trait_info_box_contents
	local content = trait_info_box.content
	local style = trait_info_box.style
	local is_hover = self._hovered_trait_item ~= nil

	style.display_name.visible = is_hover
	style.description.visible = is_hover
	style.icon.visible = is_hover

	if is_hover and self._hovered_trait_item ~= self._old_hovered_trait_item then
		local trait_item = self._hovered_trait_item

		content.display_name = Localize(trait_item.display_name)
		content.description = Items.trait_description(trait_item, trait_item.rarity, trait_item.value)

		local icon_height = style.icon.size[2]
		local description_height = _style_text_height(content.description, style.description, ui_renderer)
		local trait_box_height = math.max(icon_height, style.description.offset[2] + description_height)

		self:_set_scenegraph_size("trait_info_box_contents", nil, trait_box_height)
		self:_force_update_scenegraph()

		local texture_icon, texture_frame = Items.trait_textures(trait_item, trait_item.rarity)
		local icon_material_values = style.icon.material_values

		icon_material_values.icon = texture_icon
		icon_material_values.frame = texture_frame
	end

	self._old_hovered_trait_item = self._hovered_trait_item
	self._hovered_trait_item = nil
end

function ForgeViewElementTraitInventory:present_inventory(sticker_book, ingredients, external_left_click_callback, do_animation, external_right_click_callback)
	self._sticker_book = sticker_book
	self._ingredients = ingredients
	self._external_left_click_callback = external_left_click_callback
	self._external_right_click_callback = external_right_click_callback

	self:_switch_to_rank_tab(RankSettings.max_trait_rank, true)
	self:_update_tab_counts()

	if self._do_animations then
		self:start_animation()
	end

	self._active = true
	self._disabled = false
end

local NUM_BLESSINGS = {}
local MAX_BLESSINGS = {}

function ForgeViewElementTraitInventory:_update_tab_counts()
	if not self._sticker_book then
		return
	end

	table.clear(NUM_BLESSINGS)
	table.clear(MAX_BLESSINGS)

	for trait_name, status in pairs(self._sticker_book) do
		if status ~= nil then
			for i = 1, RankSettings.max_trait_rank do
				local trait_status = status[i]
				local has_seen = trait_status == "seen"

				NUM_BLESSINGS[i] = (NUM_BLESSINGS[i] or 0) + (has_seen and 1 or 0)

				if trait_status ~= "invalid" then
					MAX_BLESSINGS[i] = (MAX_BLESSINGS[i] or 0) + 1
				end
			end
		end
	end

	local widgets_by_name = self._widgets_by_name

	for i = 1, RankSettings.max_trait_rank do
		local widget = widgets_by_name["rank_" .. i]
		local content = widget.content

		content.blessings = (NUM_BLESSINGS[i] or 0) .. "/" .. (MAX_BLESSINGS[i] or 0)
	end
end

function ForgeViewElementTraitInventory:_setup_tabs()
	local tab_settings = {
		num_tabs = RankSettings.max_trait_rank
	}
	local widget_definitions = ForgeViewElementTraitInventoryDefinitions.create_tab_widgets(tab_settings)
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

function ForgeViewElementTraitInventory:_switch_to_rank_tab(rank, initializing)
	self._rank = rank

	self:_update_tabs()
	self:_present(initializing)
end

function ForgeViewElementTraitInventory:update(dt, t, input_service)
	if not self._active then
		return
	end

	if self._disabled then
		input_service = input_service:null_service()
	end

	self:_handle_input(dt, t, input_service)
	self:_update_animations(dt, t)
	ForgeViewElementTraitInventory.super.update(self, dt, t, input_service)
end

function ForgeViewElementTraitInventory:_update_tabs()
	local current_rank = self._rank
	local widgets_by_name = self._widgets_by_name

	for i = 1, RankSettings.max_trait_rank do
		local widget_name = "rank_" .. i
		local widget = widgets_by_name[widget_name]
		local content = widget.content

		content.selected = current_rank == i
	end
end

function ForgeViewElementTraitInventory:_handle_input(dt, t, input_service)
	if InputDevice.gamepad_active then
		local old_rank = self._rank or 1
		local new_rank = old_rank

		if input_service:get("navigate_primary_left_pressed") then
			new_rank = math.clamp(old_rank - 1, 1, RankSettings.max_trait_rank)
		elseif input_service:get("navigate_primary_right_pressed") then
			new_rank = math.clamp(old_rank + 1, 1, RankSettings.max_trait_rank)
		elseif input_service:get("next") and type(self._parent.remove_next_ingredient) == "function" then
			self._parent:remove_next_ingredient()
		end

		if new_rank ~= old_rank then
			self:_switch_to_rank_tab(new_rank)
		end
	else
		local widgets_by_name = self._widgets_by_name

		for i = 1, RankSettings.max_trait_rank do
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

function ForgeViewElementTraitInventory:ingredients()
	return self._ingredients
end

function ForgeViewElementTraitInventory:_present(first_presentation)
	if not self._sticker_book then
		return
	end

	local rank = self._rank
	local layout = {}

	layout[#layout + 1] = {
		widget_type = "spacing_vertical_small"
	}

	for trait_name, seen_status in pairs(self._sticker_book) do
		local status = seen_status[rank]

		if status ~= "invalid" then
			local fake_trait = {
				count = 1,
				characterId = character_id,
				masterDataInstance = {
					id = trait_name,
					overrides = {
						rarity = rank
					}
				},
				trait_name = trait_name,
				uuid = math.uuid(),
				weapon = string.match(trait_name, "^content/items/traits/([%w_]+)/")
			}
			local MasterItems = require("scripts/backend/master_items")
			local trait_stack_item = MasterItems.get_item_instance(fake_trait, fake_trait.uuid)

			if trait_stack_item then
				layout[#layout + 1] = {
					trait_amount = 1,
					widget_type = "trait",
					trait_item = trait_stack_item,
					trait_rarity = rank,
					status = status
				}
			end
		end
	end

	layout[#layout + 1] = {
		widget_type = "spacing_vertical"
	}

	local left_click_callback = callback(self, "cb_on_grid_entry_left_pressed")
	local on_present_callback = not first_presentation and callback(self, "_cb_present_grid_layout")

	self:present_grid_layout(layout, ForgeViewElementTraitInventoryBlueprints, left_click_callback, callback(self, "cb_on_grid_entry_right_pressed"), nil, nil, on_present_callback)
end

function ForgeViewElementTraitInventory:_cb_present_grid_layout()
	if self._marked_trait_item or not self._using_cursor_navigation then
		local allow_only_marked_widget = self._using_cursor_navigation

		self:select_best_widget(allow_only_marked_widget)
	end

	self:refresh_selected_marks(self._ingredients and self._ingredients.item)
end

function ForgeViewElementTraitInventory:_on_navigation_input_changed()
	ForgeViewElementTraitInventory.super._on_navigation_input_changed(self)

	if not self._using_cursor_navigation and not self._disabled then
		self:select_best_widget()
	end
end

ui_owner._ui_class_RealmsForgeViewElementTraitInventory = ForgeViewElementTraitInventory
return ForgeViewElementTraitInventory
