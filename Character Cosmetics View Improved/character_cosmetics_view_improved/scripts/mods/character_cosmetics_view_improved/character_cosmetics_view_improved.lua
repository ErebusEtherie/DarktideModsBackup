--[[
    Name: View Premium Character Cosmetics
    Author: Alfthebigheaded
]]
local mod = get_mod("character_cosmetics_view_improved")
local MasterItems = require("scripts/backend/master_items")

local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UISettings = require("scripts/settings/ui/ui_settings")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local InventoryCosmeticsView = require("scripts/ui/views/inventory_cosmetics_view/inventory_cosmetics_view")
local InventoryBackgroundView = require("scripts/ui/views/inventory_background_view/inventory_background_view")
local ProfileUtils = require("scripts/utilities/profile_utils")
local ViewElementProfilePresets =
	require("scripts/ui/view_elements/view_element_profile_presets/view_element_profile_presets")

local StoreView = require("scripts/ui/views/store_view/store_view")
local CCVIData = mod:io_dofile(
	"character_cosmetics_view_improved/scripts/mods/character_cosmetics_view_improved/character_cosmetics_view_improved_data"
)
local ItemUtils = require("scripts/utilities/items")

local previewed_items = {}
Selected_purchase_offer = {}
current_commodores_offers = {}

mod.on_all_mods_loaded = function()
	mod.get_wishlist()
end

local DataServiceBackendCache = require("scripts/managers/data_service/data_service_backend_cache")

mod:hook_safe(CLASS.InventoryCosmeticsView, "_start_show_layout", function(self, element)
	mod.get_wishlist()

	mod.list_premium_cosmetics(self)
	mod.focus_on_item(self, previewed_items)
	self._commodores_toggle = mod:get("show_commodores") or "loc_VPCC_show_all_commodores"
end)

mod:hook_safe(CLASS.InventoryCosmeticsView, "on_exit", function(self, element)
	mod.set_wishlist()
end)

mod:hook_safe(CLASS.InventoryView, "on_exit", function(self, element)
	previewed_items = {}
	Selected_purchase_offer = {}
	current_commodores_offers = {}
end)

mod.get_wishlist = function()
	local CCVI = get_mod("character_cosmetics_view_improved")
	if CCVI then
		wishlisted_items = CCVI:get("wishlisted_items")
	else
		wishlisted_items = mod:get("wishlisted_items")
	end

	if wishlisted_items == nil then
		wishlisted_items = {}
	end
end

mod.set_wishlist = function()
	local CCVI = get_mod("character_cosmetics_view_improved")
	if CCVI then
		mod:set("wishlisted_items", wishlisted_items)
		CCVI:set("wishlisted_items", wishlisted_items)
	else
		mod:set("wishlisted_items", wishlisted_items)
	end
end

mod.focus_on_item = function(self, items)
	if not items then
		return
	end

	local item_grid = self._item_grid
	local widgets = item_grid:widgets()

	for slot, item in pairs(items) do
		for i = 1, #widgets do
			local widget = widgets[i]
			local content = widget.content
			local element_item = content.item

			if element_item and element_item.__master_item and item.__master_item then
				if element_item and element_item.__master_item.name == item.__master_item.name then
					local widget_index = item_grid:widget_index(widget) or 1
					local scrollbar_animation_progress = item_grid:get_scrollbar_percentage_by_index(widget_index) or 0
					local instant_scroll = true

					item_grid:focus_grid_index(widget_index, scrollbar_animation_progress + 0.05, instant_scroll)

					if not Managers.ui:using_cursor_navigation() then
						item_grid:select_grid_index(widget_index)
					end

					break
				end
			end
		end
	end
end

InventoryCosmeticsView.cb_on_preview_pressed = function(self)
	local previewed_item = self._previewed_item
	local presentation_profile = self._presentation_profile
	local presentation_loadout = presentation_profile.loadout
	local preview_profile_equipped = self._preview_profile_equipped_items

	if previewed_item and presentation_loadout then
		local item_type = previewed_item.item_type
		local ITEM_TYPES = UISettings.ITEM_TYPES

		if item_type == ITEM_TYPES.GEAR_LOWERBODY or item_type == ITEM_TYPES.GEAR_UPPERBODY then
			self:_play_sound(UISoundEvents.apparel_equip)
		elseif
			item_type == ITEM_TYPES.GEAR_HEAD
			or item_type == ITEM_TYPES.EMOTE
			or item_type == ITEM_TYPES.END_OF_ROUND
			or item_type == ITEM_TYPES.GEAR_EXTRA_COSMETIC
		then
			self:_play_sound(UISoundEvents.apparel_equip_small)
		elseif item_type == ITEM_TYPES.PORTRAIT_FRAME or item_type == ITEM_TYPES.CHARACTER_INSIGNIA then
			self:_play_sound(UISoundEvents.apparel_equip_frame)
		elseif item_type == ITEM_TYPES.CHARACTER_TITLE then
			self:_play_sound(UISoundEvents.title_equip)
		else
			self:_play_sound(UISoundEvents.apparel_equip)
		end

		presentation_loadout[previewed_item.slots[1]] = previewed_item
		preview_profile_equipped[previewed_item.slots[1]] = previewed_item
		previewed_items[previewed_item.slots[1]] = previewed_item
		local widgets_by_name = self._widgets_by_name
		widgets_by_name.preview_button.content.hotspot.disabled = true
	end
end

InventoryCosmeticsView.cb_on_wishlist_pressed = function(self)
	if self._previewed_item and self._previewed_item.__master_item then
		local previewed_item = self._previewed_item
		local previewed_item_name = previewed_item.__master_item.name
		local previewed_item_dev_name = previewed_item.__master_item.dev_name
		local previewed_item_display_name = previewed_item.__master_item.display_name

		local previewed_item_gearid = previewed_item.__gear_id
		local widgets_by_name = self._widgets_by_name

		local already_on_wishlist = false

		if wishlisted_items ~= nil and not table.is_empty(wishlisted_items) then
			for i, item in pairs(wishlisted_items) do
				if item.dev_name == previewed_item_dev_name then
					-- already in wishlist, remove
					already_on_wishlist = true
					table.remove(wishlisted_items, i)
					self:_play_sound(UISoundEvents.notification_default_exit)
					widgets_by_name.wishlist_button.style.background_gradient.default_color =
						Color.terminal_background_gradient(nil, true)
					local text = Localize(item.display_name) .. Localize("loc_VPCC_wishlist_removed")
					Managers.event:trigger("event_add_notification_message", "default", text)
				end
			end
		end

		if not already_on_wishlist then
			-- add
			local temp = {}
			temp.name = previewed_item_name
			temp.dev_name = previewed_item_dev_name
			temp.gearid = previewed_item_gearid
			temp.display_name = previewed_item_display_name
			if wishlisted_items == nil then
				wishlisted_items = {}
			end
			if wishlisted_items ~= nil then
				wishlisted_items[#wishlisted_items + 1] = temp
			end
			self:_play_sound(UISoundEvents.notification_default_enter)
			widgets_by_name.wishlist_button.style.background_gradient.default_color =
				Color.terminal_text_warning_light(nil, true)
			local text = Localize(previewed_item_display_name) .. Localize("loc_VPCC_wishlist_added")
			Managers.event:trigger("event_add_notification_message", "default", text)
		end

		mod.set_wishlist()
		mod.update_wishlist_icons(self)
	end
end

mod:hook_safe(CLASS.InventoryCosmeticsView, "_update_equip_button_status", function(self)
	-- If the equip button is enabled, do not show the preview button.
	if self._equip_button_status == "disabled" then
		self._preview_button_disabled = false
	else
		self._preview_button_disabled = true
	end

	local widgets_by_name = self._widgets_by_name
	widgets_by_name.preview_button.content.visible = not self._preview_button_disabled
end)

mod:hook_safe(CLASS.InventoryCosmeticsView, "_register_button_callbacks", function(self)
	local widgets_by_name = self._widgets_by_name

	widgets_by_name.preview_button.content.hotspot.pressed_callback = callback(self, "cb_on_preview_pressed")
	widgets_by_name.store_button.content.hotspot.pressed_callback = callback(self, "cb_on_store_pressed")
	widgets_by_name.wishlist_button.content.hotspot.pressed_callback = callback(self, "cb_on_wishlist_pressed")
end)

mod:hook_safe(
	CLASS.InventoryCosmeticsView,
	"_set_preview_widgets_visibility",
	function(self, visible, allow_equip_button)
		local widgets_by_name = self._widgets_by_name

		if
			self._previewed_item
			and self._previewed_item.__locked
			and self._previewed_item.__locked == true
			and self._previewed_item.__master_item.source == 3
		then
			widgets_by_name.wishlist_button.content.visible = true
		else
			widgets_by_name.wishlist_button.content.visible = false
		end

		if
			self._selected_slot.name == "slot_gear_head"
			or self._selected_slot.name == "slot_gear_upperbody"
			or self._selected_slot.name == "slot_gear_lowerbody"
			or self._selected_slot.name == "slot_gear_extra_cosmetic"
		then
			widgets_by_name.preview_button.content.visible = allow_equip_button and false or not visible
		else
			widgets_by_name.preview_button.content.visible = false
		end
	end
)

mod.update_wishlist_icons = function(self)
	local item_grid = self._item_grid
	local widgets = item_grid:widgets()

	for _, widget in pairs(widgets) do
		local item_on_wishlist = false

		if widget.content and widget.content.entry and widget.content.entry.item then
			if widget.content.entry.item.__master_item then
				if self._previewed_item and self._previewed_item.__master_item then
					local previewed_item_name = widget.content.entry.item.__master_item.dev_name
					if wishlisted_items ~= nil and not table.is_empty(wishlisted_items) then
						for i, item in pairs(wishlisted_items) do
							if item.dev_name == previewed_item_name then
								item_on_wishlist = true
							end
						end
					end
				end
			end
		end

		if item_on_wishlist then
			widget.content.entry.item_on_wishlist = true
		else
			widget.content.entry.item_on_wishlist = false
		end
	end
end

mod.wishlist_store_check = function(self, archetype)
	if wishlisted_items ~= nil and not table.is_empty(wishlisted_items) then
		local _store_promise = mod.grab_current_commodores_items(self, archetype)
		return _store_promise
	end
end

mod.display_wishlist_notification = function(self)
	local _store_promise_ogryn = mod.wishlist_store_check(self, "ogryn")

	if _store_promise_ogryn then
		_store_promise_ogryn:next(function(data)
			local _store_promise_zealot = mod.wishlist_store_check(self, "zealot")

			_store_promise_zealot:next(function(data)
				local _store_promise_veteran = mod.wishlist_store_check(self, "veteran")

				_store_promise_veteran:next(function(data)
					local _store_promise_psyker = mod.wishlist_store_check(self, "psyker")

					_store_promise_psyker:next(function(data)
						local _store_promise = mod.wishlist_store_check(self)

						_store_promise:next(function(data)
							local available_items = {}
							for i, item in pairs(wishlisted_items) do
								local item_name = item.name
								local gearid = item.gearid
								local purchase_offer = nil
								purchase_offer = mod.get_item_in_current_commodores(self, gearid, item.name)

								if purchase_offer ~= nil then
									local item_text = Localize(item.display_name)
									if item.parent_item then
										item_text = item_text .. " (" .. item.parent_item .. ")"
									end
									available_items[#available_items + 1] = item_text
								end
							end

							if #available_items > 0 then
								local text = "{#color(255, 170, 30)}"
									.. Localize("loc_VPCC_wishlist_notification")
									.. "\n"
								for _, available_item in pairs(available_items) do
									text = text
										.. "{#color(125, 108, 56)} {#color(169, 191, 153)}"
										.. available_item
										.. "\n"
								end
								Managers.event:trigger("event_add_notification_message", "default", text)
							end
						end)
					end)
				end)
			end)
		end)
	end
end

mod:hook_safe(CLASS.StateMainMenu, "on_enter", function(self)
	mod.display_wishlist_notification(self)
end)

mod.remove_item_from_wishlist = function(item)
	if item then
		local item_name = item.name
		local item_dev_name = item.dev_name
		local item_display_name = item.display_name
		local item_gearid = item.__gear_id

		if wishlisted_items ~= nil and not table.is_empty(wishlisted_items) then
			for i, item1 in pairs(wishlisted_items) do
				if item1.name == item_name then
					table.remove(wishlisted_items, i)
				end
			end
		end
	end
end

mod:hook_safe(CLASS.InventoryCosmeticsView, "_preview_element", function(self, element)
	local is_locked = element.locked
	if is_locked then
		self._item_name_widget.offset[2] = self._item_name_widget.offset[2] - 80
	end

	-- find if item is on wishlist
	local item_on_wishlist = false
	local widgets_by_name = self._widgets_by_name

	if self._previewed_item and self._previewed_item.__master_item then
		local previewed_item = self._previewed_item
		local previewed_item_name = previewed_item.__master_item.dev_name
		if wishlisted_items ~= nil and not table.is_empty(wishlisted_items) then
			for i, item in pairs(wishlisted_items) do
				if item and item.dev_name == previewed_item_name then
					item_on_wishlist = true
				end
			end
		end
	end

	if item_on_wishlist == true then
		widgets_by_name.wishlist_button.style.background_gradient.default_color =
			Color.terminal_text_warning_light(nil, true)
	else
		widgets_by_name.wishlist_button.style.background_gradient.default_color =
			Color.terminal_background_gradient(nil, true)
	end

	mod.update_wishlist_icons(self)

	local is_item_previewed = false
	for slot, previewed_item in pairs(previewed_items) do
		if self._previewed_item and self._previewed_item.__master_item and previewed_item.__master_item then
			if self._previewed_item.__master_item.name == previewed_item.__master_item.name then
				is_item_previewed = true
			end
		end
	end
	local widgets_by_name = self._widgets_by_name
	if element.purchase_offer then
		widgets_by_name.store_button.content.visible = true
	else
		widgets_by_name.store_button.content.visible = false
	end

	Selected_purchase_offer = element.purchase_offer

	widgets_by_name.preview_button.content.hotspot.disabled = is_item_previewed
end)

local add_definitions = function(definitions)
	if not definitions then
		return
	end

	definitions.scenegraph_definition = definitions.scenegraph_definition or {}
	definitions.widget_definitions = definitions.widget_definitions or {}
	local equip_button_size = {
		374,
		76,
	}
	local store_button_size = {
		374,
		76,
	}

	definitions.scenegraph_definition.preview_button = {
		horizontal_alignment = "right",
		parent = "info_box",
		vertical_alignment = "bottom",
		size = equip_button_size,
		position = {
			0,
			-8,
			1,
		},
	}

	definitions.widget_definitions.preview_button =
		UIWidget.create_definition(ButtonPassTemplates.default_button, "preview_button", {
			gamepad_action = "confirm_pressed",
			visible = false,
			original_text = Utf8.upper(Localize("loc_VPCC_preview")),
			hotspot = {},
		})
	local wishlist_button_size = {
		48,
		48,
	}

	definitions.scenegraph_definition.wishlist_button = {
		horizontal_alignment = "right",
		parent = "info_box",
		vertical_alignment = "bottom",
		size = wishlist_button_size,
		position = {
			50,
			-20,
			2,
		},
	}

	definitions.widget_definitions.wishlist_button =
		UIWidget.create_definition(ButtonPassTemplates.terminal_button, "wishlist_button", {
			gamepad_action = "confirm_pressed",
			visible = false,
			original_text = Utf8.upper(Localize("loc_VPCC_wishlist")),
			hotspot = {},
		})

	definitions.scenegraph_definition.store_button = {
		horizontal_alignment = "right",
		parent = "info_box",
		vertical_alignment = "bottom",
		size = store_button_size,
		position = {
			0,
			65,
			1,
		},
	}

	definitions.widget_definitions.store_button =
		UIWidget.create_definition(ButtonPassTemplates.default_button, "store_button", {
			gamepad_action = "confirm_pressed",
			visible = false,
			original_text = Utf8.upper(Localize("loc_VPCC_store")),
			hotspot = {},
		})
end

mod:hook_require("scripts/ui/views/inventory_cosmetics_view/inventory_cosmetics_view_definitions", function(definitions)
	add_definitions(definitions)
end)

local function _item_plus_overrides(item, gear, gear_id, is_preview_item)
	local gearid = math.uuid() or gear_id

	local masterDataInstance = {
		id = item.name,
	}

	local slots = {
		item.slots,
	}

	local __gear = {
		uuid = gearid,
		masterDataInstance = masterDataInstance,
		slots = slots,
	}

	local item_instance = {
		__master_item = item,
		__gear = __gear,
		__gear_id = gearid,
		__original_gear_id = is_preview_item and gear_id,
		__is_preview_item = is_preview_item and true or false,
		__locked = true,
	}

	setmetatable(item_instance, {
		__index = function(t, field_name)
			local master_ver = rawget(item_instance, "__master_ver")

			if master_ver ~= MasterItems.get_cached_version() then
				local success = MasterItems.update_master_data(item_instance)

				if not success then
					Log.error(
						"MasterItems",
						"[_item_plus_overrides][1] could not update master data with %s",
						gear.masterDataInstance.id
					)

					return nil
				end
			end

			if field_name == "gear_id" then
				return rawget(item_instance, "__gear_id")
			end

			if field_name == "gear" then
				return rawget(item_instance, "__gear")
			end

			local master_item = rawget(item_instance, "__master_item")

			if not master_item then
				Log.warning(
					"MasterItemCache",
					string.format("No master data for item with id %s", gear.masterDataInstance.id)
				)

				return nil
			end

			local field_value = master_item[field_name]

			if field_name == "rarity" and field_value == -1 then
				return nil
			end

			return field_value
		end,
		__newindex = function(t, field_name, value)
			rawset(t, field_name, value)
		end,
		__tostring = function(t)
			local master_item = rawget(item_instance, "__master_item")

			return string.format(
				"master_item: [%s] gear_id: [%s]",
				tostring(master_item and master_item.name),
				tostring(rawget(item_instance, "__gear_id"))
			)
		end,
	})

	local success = MasterItems.update_master_data(item_instance)

	if not success then
		Log.error(
			"MasterItems",
			"[_item_plus_overrides][2] could not update master data with %s",
			gear.masterDataInstance.id
		)

		return nil
	end

	return item_instance
end

local add_wishlist_icon = function(ItemPassTemplates)
	if not ItemPassTemplates then
		return
	end

	local ColorUtilities = require("scripts/utilities/ui/colors")
	local UIFontSettings = require("scripts/managers/ui/ui_font_settings")

	ItemPassTemplates.gear_item = ItemPassTemplates.gear_item or {}

	local function _symbol_text_change_function(content, style)
		local hotspot = content.hotspot
		local is_selected = hotspot.is_selected
		local is_focused = hotspot.is_focused
		local is_hover = hotspot.is_hover
		local default_text_color = style.default_color
		local hover_color = style.hover_color
		local text_color = style.text_color
		local selected_color = style.selected_color
		local color

		if is_selected or is_focused then
			color = selected_color
		elseif is_hover then
			color = hover_color
		else
			color = default_text_color
		end

		local progress = math.max(
			math.max(hotspot.anim_hover_progress or 0, hotspot.anim_select_progress or 0),
			hotspot.anim_focus_progress or 0
		)

		ColorUtilities.color_lerp(text_color, color, progress, text_color)
	end

	local wishlist_icon_text_style = table.clone(UIFontSettings.header_3)

	wishlist_icon_text_style.text_color = Color.terminal_corner_selected(255, true)
	wishlist_icon_text_style.default_color = Color.terminal_corner_selected(255, true)
	wishlist_icon_text_style.hover_color = Color.terminal_corner_selected(255, true)
	wishlist_icon_text_style.selected_color = Color.terminal_corner_selected(255, true)
	wishlist_icon_text_style.font_size = 18
	wishlist_icon_text_style.drop_shadow = false
	wishlist_icon_text_style.text_horizontal_alignment = "right"
	wishlist_icon_text_style.text_vertical_alignment = "top"
	wishlist_icon_text_style.offset = {
		-10,
		5,
		7,
	}

	ItemPassTemplates.gear_item[#ItemPassTemplates.gear_item + 1] = {
		pass_type = "text",
		value = Utf8.upper(Localize("loc_VPCC_wishlist")),
		style = wishlist_icon_text_style,
		visibility_function = function(content, style)
			if content.entry and content.entry.item_on_wishlist then
				return true
			else
				return false
			end
		end,
		change_function = _symbol_text_change_function,
	}
end

local ColorUtilities = require("scripts/utilities/ui/colors")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local add_store_item_icon = function(ItemPassTemplates)
	if not ItemPassTemplates then
		return
	end

	ItemPassTemplates.gear_item = ItemPassTemplates.gear_item or {}

	local function _symbol_text_change_function(content, style)
		local hotspot = content.hotspot
		local is_selected = hotspot.is_selected
		local is_focused = hotspot.is_focused
		local is_hover = hotspot.is_hover
		local default_text_color = style.default_color
		local hover_color = style.hover_color
		local text_color = style.text_color
		local selected_color = style.selected_color
		local color

		if is_selected or is_focused then
			color = selected_color
		elseif is_hover then
			color = hover_color
		else
			color = default_text_color
		end

		local progress = math.max(
			math.max(hotspot.anim_hover_progress or 0, hotspot.anim_select_progress or 0),
			hotspot.anim_focus_progress or 0
		)

		ColorUtilities.color_lerp(text_color, color, progress, text_color)
	end

	local item_store_icon_text_style = table.clone(UIFontSettings.header_3)

	item_store_icon_text_style.text_color = Color.terminal_corner_selected(255, true)
	item_store_icon_text_style.default_color = Color.terminal_corner_selected(255, true)
	item_store_icon_text_style.hover_color = Color.terminal_corner_selected(255, true)
	item_store_icon_text_style.selected_color = Color.terminal_corner_selected(255, true)
	item_store_icon_text_style.font_size = 24
	item_store_icon_text_style.drop_shadow = false
	item_store_icon_text_style.text_horizontal_alignment = "left"
	item_store_icon_text_style.text_vertical_alignment = "bottom"
	item_store_icon_text_style.offset = {
		10,
		-5,
		7,
	}

	ItemPassTemplates.gear_item[#ItemPassTemplates.gear_item + 1] = {
		pass_type = "text",
		value = Utf8.upper(Localize("loc_VPCC_in_store")),
		style = item_store_icon_text_style,
		visibility_function = function(content, style)
			if
				content.entry
				and content.entry.purchase_offer
				and mod:get("display_commodores_price_in_inventory") == false
			then
				return true
			else
				return false
			end
		end,
		change_function = _symbol_text_change_function,
	}
end

local adjust_display_store_price = function(ItemPassTemplates)
	if not ItemPassTemplates then
		return
	end

	if ItemPassTemplates.gear_item then
		local item_price_style = table.clone(UIFontSettings.body)

		item_price_style.text_horizontal_alignment = "left"
		item_price_style.text_vertical_alignment = "bottom"
		item_price_style.horizontal_alignment = "left"
		item_price_style.vertical_alignment = "center"
		item_price_style.offset = {
			35,
			-8,
			12,
		}
		item_price_style.font_size = 20
		item_price_style.text_color = Color.white(255, true)
		item_price_style.default_color = Color.white(255, true)
		item_price_style.hover_color = Color.white(255, true)
		local gear_item_price_style = table.clone(item_price_style)

		gear_item_price_style.offset = {
			35,
			-3,
			12,
		}

		local price_text = {
			pass_type = "text",
			style_id = "price_text",
			value = "n/a",
			value_id = "price_text",
			style = gear_item_price_style,
			visibility_function = function(content, style)
				return content.has_price_tag
					and not content.sold
					and mod:get("display_commodores_price_in_inventory") == true
			end,
		}

		local wallet_icon = {
			pass_type = "texture",
			style_id = "wallet_icon",
			value = "content/ui/materials/base/ui_default_base",
			value_id = "wallet_icon",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "bottom",
				size = {
					28,
					20,
				},
				offset = {
					5,
					-5,
					12,
				},
				color = {
					255,
					255,
					255,
					255,
				},
			},
			visibility_function = function(content, style)
				return content.has_price_tag
					and not content.sold
					and mod:get("display_commodores_price_in_inventory") == true
			end,
		}

		for _, template in pairs(ItemPassTemplates.gear_item) do
			if template.style_id and template.style_id == "price_text" then
				ItemPassTemplates.gear_item[_] = price_text
			end

			if template.style_id and template.style_id == "wallet_icon" then
				ItemPassTemplates.gear_item[_] = wallet_icon
			end
		end
	end
end

mod:hook_require("scripts/ui/pass_templates/item_pass_templates", function(ItemPassTemplates)
	add_wishlist_icon(ItemPassTemplates)
	add_store_item_icon(ItemPassTemplates)
	adjust_display_store_price(ItemPassTemplates)
end)

Category_index = 1
InventoryCosmeticsView.cb_on_store_pressed = function(self)
	local previewed_item = self._previewed_item
	local presentation_profile = self._presentation_profile
	local presentation_loadout = presentation_profile.loadout
	local preview_profile_equipped = self._preview_profile_equipped_items

	local offer = Selected_purchase_offer
	if offer then
		local player = Managers.player:local_player(1)
		local character_id = player:character_id()
		local archetype_name = player:archetype_name()

		local page_index = 1

		if archetype_name == "veteran" then
			Category_index = 2
		elseif archetype_name == "zealot" then
			Category_index = 3
		elseif archetype_name == "psyker" then
			Category_index = 4
		elseif archetype_name == "ogryn" then
			Category_index = 5
		elseif archetype_name == "adamant" then
			Category_index = 6
		elseif archetype_name == "broker" then
			Category_index = 7
		end

		local ui_manager = Managers.ui

		if ui_manager then
			local context = {
				hub_interaction = true,
			}

			ui_manager:open_view("store_view", nil, nil, nil, nil, context)
		end
	end
end

local Archetypes = require("scripts/settings/archetype/archetypes")

local STORE_LAYOUT = {
	{
		display_name = "loc_premium_store_category_title_featured",
		storefront = "premium_store_featured",
		telemetry_name = "featured",
		template = nil,
		template = ButtonPassTemplates.terminal_tab_menu_with_divider_button,
	},
	{
		display_name = "loc_premium_store_category_skins_title_veteran",
		storefront = "premium_store_skins_veteran",
		telemetry_name = "veteran",
		template = nil,
		template = ButtonPassTemplates.terminal_tab_menu_with_divider_button,
	},
	{
		display_name = "loc_premium_store_category_skins_title_zealot",
		storefront = "premium_store_skins_zealot",
		telemetry_name = "zealot",
		template = nil,
		template = ButtonPassTemplates.terminal_tab_menu_with_divider_button,
	},
	{
		display_name = "loc_premium_store_category_skins_title_psyker",
		storefront = "premium_store_skins_psyker",
		telemetry_name = "psyker",
		template = nil,
		template = ButtonPassTemplates.terminal_tab_menu_with_divider_button,
	},
	{
		display_name = "loc_premium_store_category_skins_title_ogryn",
		storefront = "premium_store_skins_ogryn",
		telemetry_name = "ogryn",
		template = nil,
		template = ButtonPassTemplates.terminal_tab_menu_with_divider_button,
	},
	{
		display_name = "loc_premium_store_category_skins_title_adamant",
		require_archetype_ownership = nil,
		storefront = "premium_store_skins_adamant",
		telemetry_name = "adamant",
		template = nil,
		template = ButtonPassTemplates.terminal_tab_menu_with_divider_button,
		require_archetype_ownership = Archetypes.adamant,
	},
	{
		display_name = "loc_premium_store_category_skins_title_broker",
		require_archetype_ownership = nil,
		storefront = "premium_store_skins_broker",
		telemetry_name = "broker",
		template = nil,
		template = ButtonPassTemplates.terminal_tab_menu_button,
		require_archetype_ownership = Archetypes.broker,
	},
}

local opened_store = false
StoreView._on_page_index_selected = function(self, page_index)
	local category_index = self._selected_category_index
	local category_layout = STORE_LAYOUT[category_index]
	local category_name = category_layout.telemetry_name

	self:_set_telemetry_name(category_name, page_index)

	local category_pages_layout_data = self._category_pages_layout_data

	if not category_pages_layout_data then
		return
	end

	local page_layout = category_pages_layout_data[page_index]

	if not page_layout then
		return
	end

	local previous_page_index = self._selected_page_index

	self._selected_page_index = page_index

	if self._page_panel then
		self._page_panel:set_selected_index(page_index)
	end

	local grid_settings = page_layout.grid_settings
	local elements = page_layout.elements
	local sequence_promise

	if self:_is_animation_active(self._grid_exit_animation_id) then
		sequence_promise = Promise.until_value_is_true(function()
			return self._grid_widgets == nil
		end)
	else
		sequence_promise = Promise.resolved():next(function()
			self:_destroy_current_grid()
		end)
	end

	sequence_promise:next(function()
		self:_setup_grid(elements, grid_settings)

		local image_promises = {}

		for i = 1, #self._grid_widgets do
			self._grid_widgets[i].alpha_multiplier = 0

			local image_promise = self._grid_widgets[i].config._texture_load_promise

			if image_promise then
				table.insert(image_promises, image_promise)
			end
		end

		local promise

		if #image_promises > 0 then
			promise = Promise.race(Promise.delay(0.5), Promise.all(unpack(image_promises)))
		else
			promise = Promise.resolved()
		end

		promise:next(callback(self, "_show_grid_entries", page_index, previous_page_index), function()
			return
		end)
	end)

	if Selected_purchase_offer and not opened_store then
		opened_store = true
		for i = 1, #self._category_pages_layout_data do
			local page_elements = self._category_pages_layout_data[i].elements
			for j = 1, #page_elements do
				local page_element = page_elements[j]
				if page_element.offer and page_element.offer.offerId == Selected_purchase_offer.offerId then
					self:_on_page_index_selected(i)
					self:_set_selected_grid_index(page_element.index)
					StoreView.cb_on_grid_entry_left_pressed(self, nil, page_element)
				end
			end
		end
	end
end

StoreView.on_exit = function(self)
	self:_clear_telemetry_name()

	if self._world_spawner then
		self._world_spawner:release_listener()
		self._world_spawner:destroy()

		self._world_spawner = nil
	end

	if self._input_legend_element then
		self._input_legend_element = nil

		self:_remove_element("input_legend")
	end

	if self._store_promise then
		self._store_promise:cancel()
	end

	if self._purchase_promise then
		self._purchase_promise:cancel()
	end

	if self._wallet_promise then
		self._wallet_promise:cancel()
	end

	self:_destroy_offscreen_gui()
	self:_unload_url_textures()
	StoreView.super.on_exit(self)

	if self._hub_interaction then
		local level = Managers.state.mission and Managers.state.mission:mission_level()

		if level then
			Level.trigger_event(level, "lua_premium_store_closed")
		end
	end

	opened_store = false
	Selected_purchase_offer = {}
end

StoreView._initialize_opening_page = function(self)
	local store_category_index = 1

	-- Go to selected item's category
	if Selected_purchase_offer then
		store_category_index = Category_index
	end

	local path = {
		category_index = store_category_index,
		page_index = 1,
	}

	if self._context.target_storefront then
		for i = 1, #STORE_LAYOUT do
			if STORE_LAYOUT[i].storefront == self._context.target_storefront then
				path.category_index = i
			end
		end
	end

	self:_open_navigation_path(path)
end

mod.grab_current_commodores_items = function(self, archetype)
	local player = Managers.player:local_player(1)
	local archetype_name = player and player:archetype_name() or nil

	-- Resolve archetype storefront
	local storefront = "premium_store_featured"
	if archetype == "veteran" or (archetype == nil and archetype_name == "veteran") then
		storefront = "premium_store_skins_veteran"
	elseif archetype == "zealot" or (archetype == nil and archetype_name == "zealot") then
		storefront = "premium_store_skins_zealot"
	elseif archetype == "psyker" or (archetype == nil and archetype_name == "psyker") then
		storefront = "premium_store_skins_psyker"
	elseif archetype == "ogryn" or (archetype == nil and archetype_name == "ogryn") then
		storefront = "premium_store_skins_ogryn"
	elseif archetype == "adamant" or (archetype == nil and archetype_name == "adamant") then
		storefront = "premium_store_skins_adamant"
	elseif archetype == "broker" or (archetype == nil and archetype_name == "broker") then
		storefront = "premium_store_skins_broker"
	end

	local store_service = Managers.data_service.store

	-- Always include featured storefront as well
	local promises = {}

	local archetype_promise = store_service:get_premium_store(storefront)
	if archetype_promise then
		table.insert(promises, archetype_promise)
	end

	local featured_promise = store_service:get_premium_store("premium_store_featured")
	if featured_promise then
		table.insert(promises, featured_promise)
	end

	if #promises == 0 then
		return Promise:resolved()
	end

	return Promise.all(unpack(promises)):next(function(results)
		-- Merge offers from all results, avoid duplicates by offerId
		local seen = {}
		for r = 1, #results do
			local data = results[r]
			if data and data.offers then
				for i = 1, #data.offers do
					local offer = data.offers[i]
					local offer_id = offer and offer.offerId
					if offer_id and not seen[offer_id] then
						seen[offer_id] = true
						-- Attach layout_config reference if present on this result
						offer["layout_config"] = data.layout_config
						table.insert(current_commodores_offers, offer)
					end
				end
			end
		end
	end)
end

mod.get_item_in_current_commodores = function(self, gearid, item_name)
	if not current_commodores_offers then
		return
	end

	dbg_cco = current_commodores_offers
	for i = 1, #current_commodores_offers do
		if current_commodores_offers[i].bundleInfo then
			-- For bundles
			for j = 1, #current_commodores_offers[i].bundleInfo do
				local bundle_item = current_commodores_offers[i].bundleInfo[j]

				if bundle_item.description.id == item_name or bundle_item.description.gearid == gearid then
					return current_commodores_offers[i]
				end
			end
		else
			-- for single items
			if
				current_commodores_offers[i].description.id == item_name
				or current_commodores_offers[i].description.gearid == gearid
			then
				return current_commodores_offers[i]
			end
		end
	end
end

local WIDGET_TYPE_BY_SLOT = {
	slot_animation_emote_1 = "ui_item",
	slot_animation_emote_2 = "ui_item",
	slot_animation_emote_3 = "ui_item",
	slot_animation_emote_4 = "ui_item",
	slot_animation_emote_5 = "ui_item",
	slot_animation_end_of_round = "gear_item",
	slot_character_title = "character_title_item",
	slot_companion_gear_full = "gear_item",
	slot_gear_extra_cosmetic = "gear_item",
	slot_gear_head = "gear_item",
	slot_gear_lowerbody = "gear_item",
	slot_gear_upperbody = "gear_item",
	slot_insignia = "ui_item",
	slot_portrait_frame = "ui_item",
}

-- Fill out the UI cosmetics grid with all unlocked, then locked cosmetics.
mod.list_premium_cosmetics = function(self)
	local selected_item_slot = self._selected_slot

	if selected_item_slot then
		local _store_promise = mod.grab_current_commodores_items(self)
		_store_promise:next(function()
			local current_cosmetics = mod.get_cosmetic_items(self, selected_item_slot.name)

			if
				selected_item_slot.name == "slot_gear_head"
				or selected_item_slot.name == "slot_gear_lowerbody"
				or selected_item_slot.name == "slot_gear_upperbody"
				or selected_item_slot.name == "slot_gear_extra_cosmetic"
			then
				local layout = {}

				local unlocked_items = {}
				-- Add unlocked cosmetics
				local player = self._preview_player
				local profile = player:profile()
				local currentarchetype = profile.archetype
				local currentbreed = currentarchetype.breed

				for i = 1, #self._inventory_items do
					local item = self._inventory_items[i]
					if item then
						local forcurrentbreed = false

						if item.breeds then
							for x, breed in pairs(item.breeds) do
								if breed == currentbreed then
									if item.archetypes then
										for y, archetypename in pairs(item.archetypes) do
											if archetypename == currentarchetype.name then
												forcurrentbreed = true
											end
										end
									else
										forcurrentbreed = true
									end
								end
							end
							local valid = true

							if forcurrentbreed then
								-- Remove incorrect background prisoner garbs
								if string.find(item.__master_item.display_name, "prisoner") then
									if
										item.__master_item.crimes
										and #item.__master_item.crimes > 0
										and profile.lore
										and profile.lore.backstory
										and profile.lore.backstory.crime
									then
										valid = false
										for i, crime in pairs(item.__master_item.crimes) do
											if profile.lore.backstory.crime == crime then
												valid = true
											end
										end
									end
								end

								if valid then
									local gear_id = item.gear_id
									local is_new = self._context
										and self._context.new_items_gear_ids
										and self._context.new_items_gear_ids[gear_id]
									local remove_new_marker_callback

									-- find if item is on wishlist
									local item_on_wishlist = false
									local previewed_item_name = item.__master_item.dev_name
									if wishlisted_items ~= nil and not table.is_empty(wishlisted_items) then
										for i, item1 in pairs(wishlisted_items) do
											if item1 and item1.dev_name == previewed_item_name then
												item_on_wishlist = true
											end
										end
									end

									-- remove purchased items from wishlist
									if item_on_wishlist then
										mod.remove_item_from_wishlist(item.__master_item)
									end

									if is_new then
										remove_new_marker_callback = self._parent
											and callback(self._parent, "remove_new_item_mark")
									end

									unlocked_items[#unlocked_items + 1] = item.__master_item.name
									layout[#layout + 1] = {
										widget_type = "gear_item",
										sort_data = item,
										item = item,
										locked = false,
										slot = selected_item_slot,
										new_item_marker = is_new,
										remove_new_marker_callback = remove_new_marker_callback,
										profile = profile,
										sort_group = 1,
									}
								end
							end
						end
					end
				end

				local locked_items = {}

				-- Add locked cosmetics
				for i = 1, #current_cosmetics do
					local item = _item_plus_overrides(
						current_cosmetics[i],
						current_cosmetics[i].__gear,
						current_cosmetics[i].__gear_id,
						false
					)
					if item then
						local continue = true

						local gear_id = item.gear_id
						local is_new = self._context
							and self._context.new_items_gear_ids
							and self._context.new_items_gear_ids[gear_id]
						local remove_new_marker_callback

						if is_new then
							remove_new_marker_callback = self._parent and callback(self._parent, "remove_new_item_mark")
						end

						-- filter out unlocked items
						for x, unlocked_item_name in pairs(unlocked_items) do
							if item.name == unlocked_item_name then
								continue = false
							end
						end

						-- Filter out unknown sources
						if not mod:get("show_unobtainable") then
							if item.source == nil or item.source < 1 then
								continue = false
							end
						end

						-- Filter out "NONE" commodore filter
						if self._commodores_toggle == "loc_VPCC_show_no_commodores" and item.source == 3 then
							continue = false
						end

						-- Get purchase offer if item is in store.
						local purchase_offer = nil
						purchase_offer = mod.get_item_in_current_commodores(self, gear_id, item.name)
						-- if the source isn't "commodores vestures" yet the item is available in store - set the correct source...
						if purchase_offer and item.source ~= 3 then
							item.source = 3
						end

						if purchase_offer then
							local skin_name = item.name
							local selected_item_cost = 0
							local bundle = purchase_offer.bundleInfo or nil

							if bundle then
								for _, bundleitem in pairs(bundle) do
									if bundleitem.description.id == skin_name then
										selected_item_cost = bundleitem.price.amount.amount
									end
								end
							else
								selected_item_cost = purchase_offer.price.amount.amount or 0
							end

							purchase_offer.price.amount.amount = selected_item_cost
							item.offer = purchase_offer
						end

						if
							self._commodores_toggle == "loc_VPCC_show_available_commodores"
							and item.source == 3
							and not purchase_offer
						then
							continue = false
						end

						-- find if item is on wishlist
						local item_on_wishlist = false
						local widgets_by_name = self._widgets_by_name

						local previewed_item_name = item.__master_item.dev_name
						if wishlisted_items ~= nil and not table.is_empty(wishlisted_items) then
							for i, item1 in pairs(wishlisted_items) do
								if item1 and item1.dev_name == previewed_item_name then
									item_on_wishlist = true
								end
							end
						end

						-- remove purchased items from wishlist
						if item_on_wishlist and item.__locked and item.__locked == false then
							mod.remove_item_from_wishlist(item.__master_item)
						end

						-- categorise locked items by their source
						if continue then
							locked_items[item.source] = locked_items[item.source] or {}
							table.insert(locked_items[item.source], item)
						end
					end
				end

				-- Add divider
				layout[#layout + 1] = {
					widget_type = "divider",
					sort_group = 2,
				}

				-- Add locked items to layout, grouped by source
				for source, items in pairs(locked_items) do
					-- 1 = Penance, 2 = Commisary, 3 = Commodore's Vestures, 4 = Hestia's Blessings
					local item_sort_group = 5

					if source == 1 then
						item_sort_group = 3
					elseif source == 2 then
						item_sort_group = 3
					elseif source == 3 then
						item_sort_group = 5
						-- Add divider
						layout[#layout + 1] = {
							widget_type = "divider",
							sort_group = 4,
						}
					elseif source == 4 then
						item_sort_group = 3
					end

					for _, item in ipairs(items) do
						layout[#layout + 1] = {
							widget_type = "gear_item",
							sort_data = item,
							item = item,
							slot = selected_item_slot,
							new_item_marker = item.is_new,
							remove_new_marker_callback = item.remove_new_marker_callback,
							locked = true,
							profile = profile,
							purchase_offer = item.offer,
							item_on_wishlist = item.item_on_wishlist,
							offer = item.offer,
							sort_group = item_sort_group,
						}
					end
				end
				dbg_layout = layout

				if layout ~= nil then
					self._offer_items_layout = table.clone_instance(layout)
					self:_present_layout_by_slot_filter(nil, nil, selected_item_slot.display_name)
				end
			else
				-- anything other than hats, torso, legs, back
				local selected_slot_name = selected_item_slot.name
				local layout = {}

				local unlocked_items = {}

				-- Add unlocked cosmetics
				local player = self._preview_player
				local profile = player:profile()
				local currentarchetype = profile.archetype
				local currentbreed = currentarchetype.breed

				for i = 1, #self._inventory_items do
					local item = self._inventory_items[i]
					if item then
						local forcurrentbreed = false

						if item.breeds then
							for x, breed in pairs(item.breeds) do
								if breed == currentbreed then
									if item.archetypes then
										for y, archetypename in pairs(item.archetypes) do
											if archetypename == currentarchetype.name then
												forcurrentbreed = true
											end
										end
									else
										forcurrentbreed = true
									end
								end
							end
							local valid = true

							if forcurrentbreed then
								local gear_id = item.gear_id
								local is_new = self._context
									and self._context.new_items_gear_ids
									and self._context.new_items_gear_ids[gear_id]
								local remove_new_marker_callback
								if is_new then
									remove_new_marker_callback = self._parent
										and callback(self._parent, "remove_new_item_mark")
								end

								if valid then
									unlocked_items[#unlocked_items + 1] = item.__master_item.name
									layout[#layout + 1] = {
										widget_type = WIDGET_TYPE_BY_SLOT[selected_slot_name],
										sort_data = item,
										item = item,
										locked = false,
										slot = selected_item_slot,
										new_item_marker = is_new,
										remove_new_marker_callback = remove_new_marker_callback,
										profile = profile,
										sort_group = 1,
									}
								end
							end
						end
					end
				end

				-- Add divider
				layout[#layout + 1] = {
					widget_type = "divider",
					sort_group = 2,
				}

				-- add locked items
				for i = 1, #current_cosmetics do
					local item = _item_plus_overrides(
						current_cosmetics[i],
						current_cosmetics[i].__gear,
						current_cosmetics[i].__gear_id,
						false
					)

					local continue = true

					if item then
						local forcurrentbreed = false

						if item.breeds then
							for x, breed in pairs(item.breeds) do
								if breed == currentbreed then
									if item.archetypes then
										for y, archetypename in pairs(item.archetypes) do
											if archetypename == currentarchetype.name then
												forcurrentbreed = true
											end
										end
									else
										forcurrentbreed = true
									end
								end
							end
							local valid = true

							if forcurrentbreed then
								for x, unlocked_item_name in pairs(unlocked_items) do
									if item.name == unlocked_item_name then
										continue = false
									end
								end

								-- Filter out unknown sources
								if not mod:get("show_unobtainable") then
									if item.source == nil or item.source < 1 then
										continue = false
									end
								end

								if continue == true then
									local gear_id = item.gear_id
									local is_new = self._context
										and self._context.new_items_gear_ids
										and self._context.new_items_gear_ids[gear_id]
									local remove_new_marker_callback
									if is_new then
										remove_new_marker_callback = self._parent
											and callback(self._parent, "remove_new_item_mark")
									end

									layout[#layout + 1] = {
										widget_type = WIDGET_TYPE_BY_SLOT[selected_slot_name],
										sort_data = item,
										item = item,
										slot = selected_item_slot,
										new_item_marker = is_new,
										remove_new_marker_callback = remove_new_marker_callback,
										locked = true,
										profile = profile,
										purchase_offer = nil,
										item_on_wishlist = false,
										sort_group = 3,
									}
								end
							end
						end
					end
				end

				if layout ~= nil then
					self._offer_items_layout = table.clone_instance(layout)
					self:_present_layout_by_slot_filter(nil, nil, selected_item_slot.display_name)
				end
			end
		end)
	end
end

-- Get all cosmetics items available, from the MasterItems cache.
mod.get_cosmetic_items = function(self, selectedslot)
	local item_definitions = MasterItems.get_cached()
	local cosmetic_items = {}
	local player = self._preview_player
	local profile = player:profile()
	local currentarchetype = profile.archetype
	local currentbreed = currentarchetype.breed

	for item_name, item in pairs(item_definitions) do
		repeat
			local slots = item.slots
			local slot = slots and slots[1]

			if item.__gear_id then
				local gearid = item.__gear_id
				if gearid then
					gearid[#gearid + 1] = gearid
				end
			end

			local forcurrentbreed = false
			if slot and slot == selectedslot and item.breeds then
				for x, breed in pairs(item.breeds) do
					if breed == currentbreed then
						if item.archetypes then
							for y, archetypename in pairs(item.archetypes) do
								if archetypename == currentarchetype.name then
									forcurrentbreed = true
								end
							end
						else
							forcurrentbreed = true
						end
					end
				end
				if forcurrentbreed then
					if item.display_name ~= "" and item.display_name ~= nil and item.display_name ~= " " then
						cosmetic_items[#cosmetic_items + 1] = item
					end
				end
			end
		until true
	end

	return cosmetic_items
end

-- SETUP COMMODORES ITEM TOGGLES
InventoryCosmeticsView.cb_on_commodores_toggle_pressed = function(self)
	if self._commodores_toggle == "loc_VPCC_show_all_commodores" then
		self._commodores_toggle = "loc_VPCC_show_available_commodores"
	elseif self._commodores_toggle == "loc_VPCC_show_available_commodores" then
		self._commodores_toggle = "loc_VPCC_show_no_commodores"
	elseif self._commodores_toggle == "loc_VPCC_show_no_commodores" then
		self._commodores_toggle = "loc_VPCC_show_all_commodores"
	end

	mod:set("show_commodores", self._commodores_toggle)
	mod.list_premium_cosmetics(self)
	mod.focus_on_item(self, previewed_items)
end

local Definitions = mod:io_dofile(
	"character_cosmetics_view_improved/scripts/mods/character_cosmetics_view_improved/character_cosmetics_view_improved_definitions"
)
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
InventoryCosmeticsView._setup_input_legend = function(self)
	self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 10)

	local legend_inputs = Definitions.legend_inputs

	for i = 1, #legend_inputs do
		local legend_input = legend_inputs[i]
		local on_pressed_callback = legend_input.on_pressed_callback
			and callback(self, legend_input.on_pressed_callback)

		self._input_legend_element:add_entry(
			legend_input.display_name,
			legend_input.input_action,
			legend_input.visibility_function,
			on_pressed_callback,
			legend_input.alignment
		)
	end
end

--[[
InventoryCosmeticsView._setup_sort_options = function(self)
    if self._inventory_items then
        self._sort_options = {
            {
                display_name = Localize(
                    "loc_inventory_item_grid_sort_title_format_high_low", true, {
                        sort_name = Localize("loc_inventory_item_grid_sort_title_rarity")
                    }
                ),
                sort_function = function(a, b)
                    return ItemUtils.sort_comparator(
                        {
                            ">",
                            ItemUtils.compare_item_rarity,
                            ">",
                            ItemUtils.compare_item_level,
                            "<",
                            ItemUtils.compare_item_name
                        }
                    )(a, b)
                end


            },
            {
                display_name = Localize(
                    "loc_inventory_item_grid_sort_title_format_low_high", true, {
                        sort_name = Localize("loc_inventory_item_grid_sort_title_rarity")
                    }
                ),
                sort_function = function(a, b)
                   
                    return ItemUtils.sort_comparator(
                        {
                            "<",
                            ItemUtils.compare_item_rarity,
                            ">",
                            ItemUtils.compare_item_level,
                            "<",
                            ItemUtils.compare_item_name
                        }
                    )(a, b)
                end


            },
            {
                display_name = Localize(
                    "loc_inventory_item_grid_sort_title_format_increasing_letters", true, {
                        sort_name = Localize("loc_inventory_item_grid_sort_title_name")
                    }
                ),
                sort_function = function(a, b)
                    
                    return ItemUtils.sort_comparator(
                        {
                            "<",
                            ItemUtils.compare_item_name,
                            "<",
                            ItemUtils.compare_item_level,
                            "<",
                            ItemUtils.compare_item_rarity
                        }
                    )(a, b)
                end


            },
            {
                display_name = Localize(
                    "loc_inventory_item_grid_sort_title_format_decreasing_letters", true, {
                        sort_name = Localize("loc_inventory_item_grid_sort_title_name")
                    }
                ),
                sort_function = function(a, b)
                   
                    return ItemUtils.sort_comparator(
                        {
                            ">",
                            ItemUtils.compare_item_name,
                            "<",
                            ItemUtils.compare_item_level,
                            "<",
                            ItemUtils.compare_item_rarity
                        }
                    )(a, b)
                end


            }
        }
    end
    if self._sort_options and #self._sort_options > 0 then
        local sort_callback = callback(self, "cb_on_sort_button_pressed")

        self._item_grid:setup_sort_button(self._sort_options, sort_callback)
    end

end
]]
