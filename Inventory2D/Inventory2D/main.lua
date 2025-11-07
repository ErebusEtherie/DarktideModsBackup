local InventoryWeaponsView = require("scripts/ui/views/inventory_weapons_view/inventory_weapons_view")
local CraftingModifyView = require("scripts/ui/views/crafting_modify_view/crafting_modify_view")
local WeaponIconUI = require("scripts/ui/weapon_icon_ui")
local MasterItems = require("scripts/backend/master_items")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local ItemUtils = require("scripts/utilities/items")

Inventory2D = Inventory2D or {}
local s = Inventory2D
s.mod = s.mod or get_mod("Inventory2D")
s.mod_path = "Inventory2D/"
s.icon_renderer = nil

local item_init_func = nil
local item_load_icon_func = nil
local update_item_icon_priority_func = nil
local update_func = nil
local base_item_size = { 586, 110 } -- w/ 3: { 190, 110 }

Mods.file.dofile(s.mod_path .. "ui_manager_hooks")
Mods.file.dofile(s.mod_path .. "utils")
Mods.file.dofile(s.mod_path .. "curio_detail_mode")

local settings = Mods.file.dofile(s.mod_path .. "settings_manager")

local save_original_funcs = function(item)
	if not item_init_func then
		item_init_func = item.init
	end

	if not item_load_icon_func then
		item_load_icon_func = item.load_icon
	end

	if not update_item_icon_priority_func then
		update_item_icon_priority_func = item.update_item_icon_priority
	end

	if not update_func then
		update_func = item.update
	end
end

s.mod.on_disabled = function()
	InventoryWeaponsView.present_grid_layout = function(...)
		InventoryWeaponsView.super.present_grid_layout(...)
	end

	CraftingModifyView.present_grid_layout = function(...)
		CraftingModifyView.super.present_grid_layout(...)
	end
end

s.init = function()
	settings.init()
	InventoryWeaponsView.present_grid_layout = s.repl__present_grid_layout
	CraftingModifyView.present_grid_layout = s.repl__present_grid_layout
end

s.get_icon_renderer = function()
	if not s.icon_renderer then
		local size = s.get_adjusted_item_size()

		s.icon_renderer = WeaponIconUI:new({
			width = size[1],
			height = size[2]
		})
	end

	return s.icon_renderer
end

s.mod.on_enabled = s.init
s.mod.on_all_mods_loaded = s.init

s.repl__present_grid_layout = function(self, layout, optional_on_present_cb)
	local left_click_cb = callback(self, "cb_on_grid_entry_left_pressed")
	local left_double_click_callback = callback(self,
		"cb_on_grid_entry_left_double_click")
	local right_click_cb = callback(self, "cb_on_grid_entry_right_pressed")
	local gen_blueprints_func = require("scripts/ui/view_content_blueprints/item_blueprints")
	local grid_settings = self._definitions.grid_settings
	local grid_size = grid_settings.grid_size
	local blueprints = table.clone(gen_blueprints_func(grid_size))

	-- Check whether the current grid is displaying a slot that is disabled
	-- in our settings, and skip setup if it is.
	local slot_name = self._selected_slot and self._selected_slot.name
	local skip_setup = false

	-- Checking tabs e.g. @ Hadron.
	if self._tab_menu_element and self._tabs_content then
		local index = self._tab_menu_element:selected_index()
		local content = self._tabs_content[index]
		local slot_types = content.slot_types

		if #slot_types > 0 then
			local slot = slot_types[1]

			if (slot == "slot_primary" and
						not settings.get("enable_for_primary_weapons")) or
					(slot == "slot_secondary" and
						not settings.get("enable_for_secondary_weapons")) or
					(string.match(slot, "slot_attachment_") and
						not settings.get("enable_for_curios")) then
				skip_setup = true
			end
		end

	-- Checking via item slots e.g. in inventory.
	elseif not slot_name or (slot_name == "slot_primary" and
			not settings.get("enable_for_primary_weapons")) or
			(slot_name == "slot_secondary" and
				not settings.get("enable_for_secondary_weapons")) or
			(string.match(slot_name, "slot_attachment_") and
				not settings.get("enable_for_curios")) then
		skip_setup = true
	end

	if skip_setup then
		local spacing_default = {
			widget_type = "spacing_vertical"
		}

		table.insert(layout, 1, spacing_default)
		table.insert(layout, #layout + 1, spacing_default)

		return self._item_grid:present_grid_layout(
			layout,
			blueprints,
			left_click_cb,
			right_click_cb,
			self._grid_display_name,
			"down",
			optional_on_present_cb,
			left_double_click_callback)
	end

	local spacing_entry = { widget_type = "spacing_vertical" }
	local show_curio_blessing_text = settings.get("show_curio_blessing_text")
	local curio_detail_mode = settings.get("curio_detail_mode")
	local item = blueprints.item
	local pass_template = item.pass_template
	local item_size = s.get_adjusted_item_size()
	local spacing = settings.get("grid_spacing")
	item.size = item_size
	save_original_funcs(item)
	self._item_grid._menu_settings.grid_spacing = { spacing, spacing }

	item.init = function(parent, widget, ...)
		item_init_func(parent, widget, ...)

		local style = widget.style
		local content = widget.content
		local local_item = content.element.item

		if style.item_level then
			content.item_level = tostring(local_item.itemLevel or 0)
		end
	end

	local vis_func_not_detail_mode = function(content, style)
		return content.element.item.item_type ~= "GADGET" or
			not settings.get("curio_detail_mode")
	end

	local display_name_bp = table.find_predicate(pass_template, function(k, v)
		return type(v) == "table" and v.style_id == "display_name"
	end)

	local item_level_bp = table.find_predicate(pass_template, function(k, v)
		return type(v) == "table" and v.style_id == "item_level"
	end)

	local equipped_icon_bp = table.find_predicate(pass_template, function(k, v)
		return type(v) == "table" and v.style_id == "equipped_icon"
	end)

	if display_name_bp then
		display_name_bp.visibility_function = vis_func_not_detail_mode
	end

	if item_level_bp then
		item_level_bp.visibility_function = vis_func_not_detail_mode
	end

	if equipped_icon_bp then
		equipped_icon_bp.change_function = function(content, style)
			if content.element.item.item_type == "GADGET" then
				style.vertical_alignment = "top"
				style.offset[2] = 0
			end
		end
	end

	item.load_icon = s.load_icon
	item.update_item_icon_priority = s.update_item_icon_priority

	local left_offsets = {
		display_name = { 15, 5, 5},
		trait_1 = { 15, -5, 5 },
		trait_2 = { 52, -5, 5 },
		trait_3 = { 89, -5, 5 },
		icon = { 6, 0, 4 },
		show_rarity_tag = { 6 }
	}

	local show_rarity_tag = settings.get("show_rarity_tag")

	-- If we're not to show the rarity tag, shift everything left by its width.
	if not show_rarity_tag then
		for _, v in pairs(left_offsets) do
			v[1] = v[1] - 6
		end
	end

	-- Prepare darken item icons setting's colour value.
	local darken_setting_value = settings.get("darken_item_icons")
	local darken_byte = 255 - ((darken_setting_value / 100) * 255)
	local darken_colour = { 255, darken_byte, darken_byte, darken_byte }

	for i = 1, #pass_template do
		local template_item = pass_template[i]
		local style = pass_template[i].style

		if template_item.style_id == "display_name" then
			style.font_size = settings.get("item_name_font_size")
			style.offset = left_offsets.display_name
			style.size = { item_size[1] - 20, 40 }
			style.horizontal_alignment = "left"
		elseif template_item.style_id == "sub_display_name" then
			-- Probs not needed by people savvy enough to use mods.
			style.font_size = 0
		elseif template_item.style_id == "trait_1" then
			style.vertical_alignment = "bottom"
			style.offset = left_offsets.trait_1
			style.visible = settings.get("show_traits")
		elseif template_item.style_id == "trait_2" then
			style.vertical_alignment = "bottom"
			style.offset = left_offsets.trait_2
			style.visible = settings.get("show_traits")
		elseif template_item.style_id == "trait_3" then
			style.vertical_alignment = "bottom"
			style.offset = left_offsets.trait_3
			style.visible = settings.get("show_traits")
		elseif template_item.style_id == "salvage_icon" then
			style.offset = { 73, 0, 14 }
		elseif template_item.style_id == "salvage_circle" then
			style.offset = { 50, 0, 15 }
		elseif template_item.style_id == "item_level" then
			style.font_size = settings.get("item_level_font_size")
			style.offset = { -10, -5, 5 }
		elseif template_item.style_id == "icon" then
			style.offset = left_offsets.icon
			style.size = item_size
			style.uvs = {
				{ 0, 0 },
				{ 1, 1 }
			}
			style.color = darken_colour
		elseif template_item.style_id == "rarity_tag" then
			style.size = { show_rarity_tag and 6 or 0 }
		elseif template_item.style_id == "equipped_icon" then
			style.vertical_alignment = "bottom"
			style.offset[2] = -24
		elseif template_item.style_id == "loading" then
			style.vertical_alignment = "center"
			style.horizontal_alignment = "center"
			style.offset = { 0, 0, 4 }
		end
	end

	local additional_style = table.clone(UIFontSettings.header_3)
	local colour = Color.terminal_text_header(255, true)
	local detail_mode_blessing_style = table.clone(additional_style)
	local detail_mode_perks_style = table.clone(additional_style)

	additional_style.text_vertical_alignment = "bottom"
	additional_style.vertical_alignment = "bottom"
	additional_style.offset = { show_rarity_tag and 13 or 5, -5, 5 }
	additional_style.text_horizontal_alignment = "left"
	additional_style.horizontal_alignment = "left"
	additional_style.font_size = settings.get("curio_blessing_font_size")
	additional_style.size = { item_size[1] - 20, 40 }
	additional_style.text_color = colour
	additional_style.default_color = colour
	additional_style.hover_color = colour

	detail_mode_blessing_style.text_vertical_alignment = "top"
	detail_mode_blessing_style.vertical_alignment = "top"
	detail_mode_blessing_style.offset = { show_rarity_tag and 13 or 5, 5, 5 }
	detail_mode_blessing_style.font_size =
		settings.get("curio_detail_mode_blessing_font_size")

	detail_mode_perks_style.text_vertical_alignment = "top"
	detail_mode_perks_style.vertical_alignment = "top"
	detail_mode_perks_style.offset = { show_rarity_tag and 13 or 5, 25, 5 }
	detail_mode_perks_style.font_size =
		settings.get("curio_detail_mode_perks_font_size")

	if curio_detail_mode then
		local blessing_text = {
			style_id = "curio_blessing",
			pass_type = "text",
			value = "blessing",
			value_id = "curio_blessing",
			style = detail_mode_blessing_style,
			change_function = function(content, style)
				local real_item = content.element.item
				local traits = real_item.traits
				local item_type = real_item.item_type

				if item_type ~= "GADGET" or not curio_detail_mode then
					style.visible = false
					return
				end

				style.visible = true
				local trait = traits[1]
				local trait_item = MasterItems.get_item(trait.id)
				content.curio_blessing = ItemUtils.trait_description(
					trait_item, trait.rarity, trait.value)
			end
		}

		local perks_text = {
			style_id = "curio_perks",
			pass_type = "text",
			value = "",
			value_id = "curio_perks",
			style = detail_mode_perks_style,
			change_function = function(content, style)
				local real_item = content.element.item
				local perks = real_item.perks
				local item_type = real_item.item_type

				if item_type ~= "GADGET" or not curio_detail_mode or #perks == 0 then
					style.visible = false
					return
				end

				style.visible = true
				local str = ""

				for i = 1, #perks do
					local perk_item = MasterItems.get_item(perks[i].id)
					local perk_desc = ItemUtils.perk_description(
						perk_item, perks[i].rarity, 0)
					str = str .. (s.abbrev_curio_perk_descriptions(perk_desc) or "") .. "\n"
				end

				content.curio_perks = str
			end
		}

		table.insert(pass_template, blessing_text)
		table.insert(pass_template, perks_text)
	elseif show_curio_blessing_text then
		local blessing_text = {
			style_id = "curio_blessing",
			pass_type = "text",
			value = "",
			value_id = "curio_blessing",
			style = additional_style,
			change_function = function(content, style)
				local real_item = content.element.item
				local traits = real_item.traits
				local item_type = real_item.item_type

				if item_type ~= "GADGET" or curio_detail_mode then
					return
				end

				local trait = traits[1]
				local trait_item = MasterItems.get_item(trait.id)

				content.curio_blessing = ItemUtils.trait_description(
					trait_item, trait.rarity, trait.value)
			end,
			visibility_function = function(content, style)
				return show_curio_blessing_text and
					content.element.item.item_type == "GADGET"
			end
		}

		table.insert(pass_template, blessing_text)
	end

	local mod_rating_text_style = table.clone(UIFontSettings.body_small)
	mod_rating_text_style.horizontal_alignment = "right"
	mod_rating_text_style.vertical_alignment = "bottom"
	mod_rating_text_style.text_horizontal_alignment = "right"
	mod_rating_text_style.text_vertical_alignment = "bottom"
	mod_rating_text_style.font_size = settings.get("item_base_level_font_size")
	mod_rating_text_style.offset = { -52, -5, 5 }
	mod_rating_text_style.size = { item_size[1] - 10, 110 }
	local temp_colour = Color.gray(255, true)
	mod_rating_text_style.text_color = temp_colour
	mod_rating_text_style.default_color = temp_colour
	mod_rating_text_style.hover_color = temp_colour

	if settings.get("show_item_base_level") then
		local mod_rating_text = {
			style_id = "mod_rating_text",
			pass_type = "text",
			value = "",
			value_id = "mod_rating_text",
			style = mod_rating_text_style,
			change_function = function(content, style)
				content.mod_rating_text = content.element.item.baseItemLevel or ""
			end,
			visibility_function = function(content, style)
				return content.element.item.item_type ~= "GADGET"
			end
		}

		table.insert(pass_template, mod_rating_text)
	end

	local equipped_overlay = {
		pass_type = "texture",
		style_id = "equipped_overlay",
		value = "content/ui/materials/frames/dropshadow_medium",
		style = {
			size = item_size,
			vertical_alignment = "center",
			horizontal_alignment = "center",
			color = Color.white(255, true),
			size_addition = { 20, 20 },
			offset = {
				0,
				0,
				1
			}
		},
		visibility_function = function(content, style)
			return settings.get("show_equipped_glow") and content.equipped
		end
	}

	table.insert(pass_template, equipped_overlay)

	table.insert(layout, 1, spacing_entry)
	table.insert(layout, #layout + 1, spacing_entry)

	local grow_direction = "down"

	self._item_grid:present_grid_layout(
		layout,
		blueprints,
		left_click_cb,
		right_click_cb,
		self._grid_display_name,
		grow_direction,
		optional_on_present_cb,
		left_double_click_callback)
end

s.apply_live_item_icon_cb = function(widget, grid_index, rows, columns, render_target)
	local mat_values = widget.style.icon.material_values
	mat_values.use_placeholder_texture = 0
	mat_values.use_render_target = 1
	mat_values.rows = rows
	mat_values.columns = columns
	mat_values.grid_index = grid_index - 1
	mat_values.render_target = render_target
	widget.content.use_placeholder_texture = mat_values.use_placeholder_texture
end

s.load_icon = function(parent, widget, element, renderer, profile, prioritise)
	local content = widget.content

	if not content.icon_load_id then
		local item
		local real_item = element.item
		local cb = callback(s.apply_live_item_icon_cb, widget)

		if real_item.gear then
			item = MasterItems.create_preview_item_instance(real_item)
		else
			item = table.clone_instance(real_item)
		end

		item.gear_id = real_item.gear_id or real_item.name

		content.icon_load_id = s.get_icon_renderer():load_weapon_icon(
			item, cb, nil, prioritise)
	end
end

s.update_item_icon_priority = function(parent, widget, element,
		ui_renderer, dummy_profile)
	local content = widget.content

	if content.icon_load_id then
		Managers.ui:update_item_icon_priority(content.icon_load_id)
	end
end

s.get_adjusted_item_size = function()
	local ipr = s.mod:get("items_per_row")
	local spacing = s.mod:get("grid_spacing")

	return {
		((base_item_size[1] + spacing) / ipr) - spacing,
		base_item_size[2]
	}
end
