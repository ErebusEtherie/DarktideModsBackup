local ui_owner = get_mod("realms_loadout")
if ui_owner._ui_class_RealmsWeaponForgeView then
    return ui_owner._ui_class_RealmsWeaponForgeView
end

-- chunkname: @scripts/ui/views/credits_goods_vendor_view/credits_goods_vendor_view.lua

require("scripts/ui/views/item_grid_view_base/item_grid_view_base")

local Definitions = require("scripts/ui/views/credits_goods_vendor_view/credits_goods_vendor_view_definitions")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local WeaponTraitTemplates = require("scripts/settings/equipment/weapon_traits/weapon_trait_templates")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local Text = require("scripts/utilities/ui/text")
local WeaponCatalog = require("realms_loadout/scripts/mods/realms_loadout/weapon_catalog")
local AttachmentCatalog = require("realms_loadout/scripts/mods/realms_loadout/attachment_catalog")
local WeaponUnlockSettings = require("scripts/settings/weapon_unlock/weapon_unlock_settings")
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local ForgeViewElementWeaponStats = require("realms_loadout/scripts/mods/realms_loadout/official_ui/weapon_forge_view/forge_view_element_weapon_stats")
local ForgeViewElementPerksItem = require("realms_loadout/scripts/mods/realms_loadout/official_ui/weapon_forge_view/forge_view_element_perks_item")
local ForgeViewElementTraitInventory = require("realms_loadout/scripts/mods/realms_loadout/official_ui/weapon_forge_view/forge_view_element_trait_inventory")
local mod = get_mod("realms_loadout")
local rebuild_forge_preview_slots

local function contains_unlocalized_text(text)
  return text and string.find(text, "unlocalized", 1, true) ~= nil
end

local function safe_weapon_display_name(item)
  local display_name = Items.weapon_card_display_name(item)

  if display_name and display_name ~= "n/a" and not contains_unlocalized_text(display_name) then
    return display_name
  end

  local family_ref = item and item.weapon_family_display_name

  if family_ref and family_ref.dev_text and family_ref.dev_text ~= "" then
    return family_ref.dev_text
  end

  return item and item.name or "n/a"
end

local function safe_weapon_sub_display_name(item)
  local sub_display_name = Items.weapon_card_sub_display_name(item)

  if sub_display_name and sub_display_name ~= "n/a" and not contains_unlocalized_text(sub_display_name) then
    return sub_display_name
  end

  local function reference_text(field_name)
    local ref = item and item[field_name]
    local loc_id = ref and ref.loc_id

    if loc_id and loc_id ~= "" then
      local localized = Localize(loc_id)

      if localized and localized ~= "" and not contains_unlocalized_text(localized) then
        return localized
      end
    end

    if ref and ref.dev_text and ref.dev_text ~= "" then
      return ref.dev_text
    end

    return nil
  end

  local pattern_name = reference_text("weapon_pattern_display_name")
  local mark_name = reference_text("weapon_mark_display_name")

  if pattern_name and mark_name then
    return pattern_name .. " • " .. mark_name
  end

  return pattern_name or mark_name or "n/a"
end

local RealmsWeaponForgeView = class("RealmsWeaponForgeView", "ItemGridViewBase")

function RealmsWeaponForgeView:init(settings, context)
	self._preview_player = context.player or Managers.player:local_player(1)
	self._is_own_player = self._preview_player == Managers.player:local_player(1)
	self._is_readonly = context.is_readonly
	self._parent = context.parent

	RealmsWeaponForgeView.super.init(self, Definitions, settings, context)
end

function RealmsWeaponForgeView:on_enter()
	RealmsWeaponForgeView.super.on_enter(self)

	self._inventory_items = {}
	self._offer_items_layout = {}

	if self._item_grid then
		self._item_grid:update_dividers("content/ui/materials/frames/item_list_top_hollow", {
			652,
			118
		}, {
			0,
			-18,
			20
		})
	end

	self._offer_items_layout = self:_build_forge_weapon_layout()

	local attachment_layout = self:_build_forge_attachment_layout()

	for i = 1, #attachment_layout do
		self._offer_items_layout[#self._offer_items_layout + 1] = attachment_layout[i]
	end

	local tabs = Definitions.item_category_tabs_content and table.clone_instance(Definitions.item_category_tabs_content) or {}

	if #tabs > 0 then
		tabs[#tabs + 1] = {
			display_name = mod:localize("forge_attachment_tab"),
			hide_display_name = true,
			icon = "content/ui/materials/icons/categories/devices",
			slot_types = AttachmentCatalog.forge_attachment_slots()
		}

		self:_setup_menu_tabs(tabs)

		if self._tab_menu_element then
			self._tab_menu_element:set_selected_index(1)
		end

		self:_present_layout_by_slot_filter(tabs[1].slot_types, nil, nil)
	else
		self:present_grid_layout(self._offer_items_layout)
	end

	self:set_loading_state(false)

	self:_setup_forge_perks_item()
	self:_setup_input_legend()
	self:_register_button_callbacks()

	local purchase_button = self._widgets_by_name.purchase_button

	if purchase_button then
		purchase_button.content.hotspot.disabled = false
		purchase_button.content.original_text = Utf8.upper(mod:localize("forge_obtain_button"))
		purchase_button.content.text = Utf8.upper(mod:localize("forge_obtain_button"))
	end

	local _, purchase_y = self:_scenegraph_position("purchase_button")

	self:_set_scenegraph_position("purchase_button", nil, purchase_y + 110)
end

function RealmsWeaponForgeView:_build_forge_weapon_layout()
	local layout = {}
	local player = self._preview_player or Managers.player:local_player(1)
	local profile = player and player:profile()
	local allow_all_archetype_weapons = WeaponCatalog.allow_all_archetype_weapons_enabled()
	local use_all_human_weapons = allow_all_archetype_weapons and WeaponCatalog.is_human_profile(profile)
	local seen_patterns = {}

	local function add_official_master_item(master_item, weapon_level_requirement)
		if not master_item then
			return
		end

		local pattern = master_item.parent_pattern or master_item.name

		if not seen_patterns[pattern] then
			seen_patterns[pattern] = true
			layout[#layout + 1] = self:_make_forge_weapon_layout_entry(master_item, weapon_level_requirement or 1)
		end
	end

	if use_all_human_weapons then
		local human_entries = profile and WeaponCatalog.human_weapon_entries(profile) or {}

		for i = 1, #human_entries do
			local entry = human_entries[i]

			add_official_master_item(entry and (entry.__master_item or MasterItems.get_item(entry.id)), entry and entry.weapon_level_requirement)
		end
	else
		local archetype_name = profile and profile.archetype and profile.archetype.name
		local archetype_weapon_unlocks = archetype_name and WeaponUnlockSettings[archetype_name]
		local seen = {}

		if archetype_weapon_unlocks then
			for weapon_level, weapon_list in ipairs(archetype_weapon_unlocks) do
				if type(weapon_list) == "table" then
					for i = 1, #weapon_list do
						local weapon_name = weapon_list[i]

						if weapon_name and not seen[weapon_name] then
							seen[weapon_name] = true
							add_official_master_item(MasterItems.get_item(weapon_name), weapon_level)
						end
					end
				end
			end
		end
	end

	table.sort(layout, function (a, b)
		return a.weapon_level_requirement > b.weapon_level_requirement
	end)

	return layout
end

function RealmsWeaponForgeView:_make_forge_weapon_layout_entry(master_item, weapon_level_requirement)
	local slots = master_item.slots

	if type(slots) ~= "table" then
		slots = slots and {
			slots
		} or {}
	end

	local hud_icon = master_item.hud_icon

	hud_icon = hud_icon or "content/ui/materials/icons/weapons/hud/combat_blade_01"

	return {
		widget_type = "credits_goods_item",
		item = master_item,
		icon = hud_icon,
		display_name = safe_weapon_display_name(master_item),
		sub_display_name = safe_weapon_sub_display_name(master_item),
		weapon_level_requirement = weapon_level_requirement,
		filter_slots = slots
	}
end

function RealmsWeaponForgeView:_build_forge_attachment_layout()
	local layout = {}
	local templates = AttachmentCatalog.forge_attachment_templates()
	local filter_slots = AttachmentCatalog.forge_attachment_slots()

	for i = 1, #templates do
		local template = templates[i]

		layout[#layout + 1] = {
			widget_type = "credits_goods_item",
			item = template,
			icon = "content/ui/materials/icons/categories/devices",
			display_name = mod:localize(template.display_name_key),
			sub_display_name = mod:localize(template.effect_text_key),
			weapon_level_requirement = 1,
			filter_slots = filter_slots
		}
	end

	return layout
end


function RealmsWeaponForgeView:present_grid_layout(layout, on_present_callback)
	local show_info = layout and not (table.size(layout) > 0) or false
	local widgets_by_name = self._widgets_by_name

	widgets_by_name.title_text.content.visible = not show_info
	widgets_by_name.description_text.content.visible = not show_info
	widgets_by_name.divider.content.visible = not show_info

	RealmsWeaponForgeView.super.present_grid_layout(self, layout, on_present_callback)
end

function RealmsWeaponForgeView:_setup_item_grid()
	local total_height = 0
	local widgets_by_name = self._widgets_by_name
	local title_text_widget = widgets_by_name.title_text

	if title_text_widget then
		local ui_renderer = self._ui_renderer
		local content = title_text_widget.content
		local style = title_text_widget.style
		local text_style = style.text
		local height = Text.text_height(ui_renderer, content.text, text_style, text_style.size)

		height = height + 10

		self:_set_scenegraph_size("title_text", nil, height)

		local height_offset = 120

		self:_set_scenegraph_position("title_text", nil, height_offset)

		total_height = total_height + height + height_offset
	end

	local description_text_widget = widgets_by_name.description_text

	if description_text_widget then
		local ui_renderer = self._ui_renderer
		local content = description_text_widget.content
		local style = description_text_widget.style
		local text_style = style.text
		local height = Text.text_height(ui_renderer, content.text, text_style, text_style.size)

		height = height + 10

		local definitions = self._definitions
		local grid_settings = definitions.grid_settings

		grid_settings.top_padding = height

		self:_set_scenegraph_size("description_text", nil, height)

		local height_offset = 0

		self:_set_scenegraph_position("description_text", nil, height + height_offset)

		total_height = total_height + height + height_offset
	end

	total_height = total_height + 40

	local definitions = self._definitions
	local grid_settings = definitions.grid_settings

	grid_settings.top_padding = total_height

	-- Move the whole grid UI down by 60 pixels from the original y = 40.
	self:_set_scenegraph_position("item_grid_pivot", nil, 100)

	RealmsWeaponForgeView.super._setup_item_grid(self)
end

function RealmsWeaponForgeView:_setup_weapon_stats(reference_name, scenegraph_id)
	local layer = 1
	local context = self._definitions.weapon_stats_grid_settings
	local weapon_stats = self:_add_element(ForgeViewElementWeaponStats, reference_name, layer, context)

	self:_update_weapon_stats_position(scenegraph_id, weapon_stats)

	return weapon_stats
end

function RealmsWeaponForgeView:_setup_forge_perks_item()
	if self._forge_perks_item then
		return
	end

	self._forge_perks_item = self:_add_element(ForgeViewElementPerksItem, "forge_perks_item", 13, nil)
	self._forge_trait_inventory = self:_add_element(ForgeViewElementTraitInventory, "forge_trait_inventory", 13, nil)

	local position = self:_scenegraph_world_position("weapon_stats_pivot")
	local weapon_stats_grid_width = self._definitions.weapon_stats_grid_settings.grid_size[1]
	local perks_x = position[1] + weapon_stats_grid_width + 40
	local perks_y = position[2]
	local perks_height = self._forge_perks_item._menu_settings and self._forge_perks_item._menu_settings.grid_size[2] or 550

	self._forge_perks_x = perks_x
	self._forge_perks_y = perks_y
	self._forge_perks_height = perks_height

	self._forge_perks_item:set_pivot_offset(perks_x, perks_y)
	self._forge_trait_inventory:set_pivot_offset(perks_x, perks_y + perks_height + 20)
end

function RealmsWeaponForgeView:_set_forge_perks_grid_height(height)
	if self._forge_perks_item and self._forge_perks_item.update_grid_height then
		self._forge_perks_item:update_grid_height(height, height)
	end
end

function RealmsWeaponForgeView:_restore_forge_trait_inventory_position()
	if self._forge_trait_inventory and self._forge_perks_x and self._forge_perks_y and self._forge_perks_height then
		self._forge_trait_inventory:set_pivot_offset(self._forge_perks_x, self._forge_perks_y + self._forge_perks_height + 20)
	end
end

function RealmsWeaponForgeView:cb_on_forge_perk_selected(widget, config)
	local preview_item = self._forge_preview_item
	local perk_item = config and config.perk_item

	if not preview_item or not perk_item then
		return
	end

	if not widget or self:_forge_preview_has_perk(preview_item, perk_item) then
		self:cb_on_forge_perk_removed(nil, config)

		if self._forge_perks_item then
			if self._forge_perks_item.deselect_marked_perk then
				self._forge_perks_item:deselect_marked_perk()
			end

			if self._forge_perks_item.refresh_selected_marks then
				self._forge_perks_item:refresh_selected_marks(preview_item)
			end
		end

		return
	end

	local perks = preview_item.__forge_perk_slots or preview_item.perks or {}
	local slot

	for i = 1, #perks do
		local perk_slot = perks[i]

		if not perk_slot.id then
			slot = perk_slot

			break
		end
	end

	if not slot then
		mod:notify(mod:localize("forge_perk_slots_full"))

		if self._forge_perks_item then
			if self._forge_perks_item.deselect_marked_perk then
				self._forge_perks_item:deselect_marked_perk()
			end

			if self._forge_perks_item.refresh_selected_marks then
				self._forge_perks_item:refresh_selected_marks(preview_item)
			end
		end

		return
	end

	slot.id = perk_item.name
	slot.rarity = perk_item.rarity or 0
	slot.value = nil

	rebuild_forge_preview_slots(preview_item)

	if self._forge_perks_item and self._forge_perks_item.refresh_selected_marks then
		self._forge_perks_item:refresh_selected_marks(preview_item)
	end

	self:_refresh_forge_weapon_stats(preview_item)
end

function RealmsWeaponForgeView:_forge_preview_has_perk(preview_item, perk_item)
	local perks = preview_item and (preview_item.__forge_perk_slots or preview_item.perks)

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

function RealmsWeaponForgeView:cb_on_forge_perk_removed(widget, config)
	local preview_item = self._forge_preview_item
	local perk_item = config and config.perk_item

	if not preview_item or not perk_item then
		return
	end

	local perks = preview_item.__forge_perk_slots or preview_item.perks or {}
	local removed = false

	for i = 1, #perks do
		local slot = perks[i]

		if slot.id == perk_item.name then
			slot.id = nil
			slot.rarity = 0
			slot.value = nil
			removed = true

			break
		end
	end

	if removed then
		rebuild_forge_preview_slots(preview_item)

		if self._forge_perks_item then
			if self._forge_perks_item.deselect_marked_perk then
				self._forge_perks_item:deselect_marked_perk()
			end

			if self._forge_perks_item.refresh_selected_marks then
				self._forge_perks_item:refresh_selected_marks(preview_item)
			end
		end

		self:_refresh_forge_weapon_stats(preview_item)
	end
end

function RealmsWeaponForgeView:_refresh_forge_weapon_stats(preview_item)
	if self._weapon_stats and preview_item then
		local ok, err = xpcall(function ()
			self._weapon_stats:present_item(preview_item, {
				hide_source = true
			})
		end, function (error_message)
			return debug.traceback(tostring(error_message), 2)
		end)

		if not ok then
			mod:warning("realms_loadout failed to refresh forge weapon stats after perk change: %s", tostring(err))
		end
	end
end

function RealmsWeaponForgeView:_build_trait_sticker_book(preview_item)
	local sticker_book = {}
	local trait_category = preview_item and preview_item.trait_category

	if not trait_category then
		return sticker_book
	end

	local prefix = "content/items/traits/" .. trait_category .. "/"
	local master_items = MasterItems.get_cached()

	for item_name, _ in pairs(master_items) do
		if type(item_name) == "string" and string.sub(item_name, 1, #prefix) == prefix then
			local trait_item = MasterItems.get_item(item_name)
			local trait_name = trait_item and trait_item.trait

			if trait_name and WeaponTraitTemplates[trait_name] then
				sticker_book[item_name] = {
					[1] = "seen",
					[2] = "seen",
					[3] = "seen",
					[4] = "seen"
				}
			end
		end
	end



	return sticker_book
end

function RealmsWeaponForgeView:_present_forge_trait_inventory(preview_item)
	if not self._forge_trait_inventory or not preview_item then
		return
	end

	self._trait_ingredients = {
		item = preview_item,
		existing_trait_index = 1,
		trait_ids = {},
		trait_master_ids = {},
		tiers = {}
	}

	local sticker_book = self:_build_trait_sticker_book(preview_item)

	self._forge_trait_inventory:present_inventory(sticker_book, self._trait_ingredients, callback(self, "cb_on_forge_trait_selected"), nil, callback(self, "cb_on_forge_trait_removed"))
end

function RealmsWeaponForgeView:_forge_preview_has_trait(preview_item, trait_item)
	local traits = preview_item and (preview_item.__forge_trait_slots or preview_item.traits)

	if not traits then
		return false
	end

	for i = 1, #traits do
		if traits[i].id == trait_item.name then
			return true
		end
	end

	return false
end

function RealmsWeaponForgeView:cb_on_forge_trait_selected(widget, config)
	local preview_item = self._forge_preview_item
	local trait_item = config and config.trait_item

	if not preview_item or not trait_item then
		return
	end

	if not widget or self:_forge_preview_has_trait(preview_item, trait_item) then
		self:cb_on_forge_trait_removed(nil, config)

		return
	end

	local traits = preview_item.__forge_trait_slots or preview_item.traits or {}
	local slot

	for i = 1, #traits do
		if not traits[i].id then
			slot = traits[i]

			break
		end
	end

	if not slot then
		mod:notify(mod:localize("forge_trait_slots_full"))

		if self._forge_trait_inventory then
			if self._forge_trait_inventory.deselect_marked_trait then
				self._forge_trait_inventory:deselect_marked_trait()
			end

			if self._forge_trait_inventory.refresh_selected_marks then
				self._forge_trait_inventory:refresh_selected_marks(preview_item)
			end
		end

		return
	end

	slot.id = trait_item.name
	slot.rarity = trait_item.rarity or 0
	slot.value = nil

	rebuild_forge_preview_slots(preview_item)

	if self._forge_trait_inventory and self._forge_trait_inventory.refresh_selected_marks then
		self._forge_trait_inventory:refresh_selected_marks(preview_item)
	end

	self:_refresh_forge_weapon_stats(preview_item)
end

function RealmsWeaponForgeView:cb_on_forge_trait_removed(widget, config)
	local preview_item = self._forge_preview_item
	local trait_item = config and config.trait_item

	if not preview_item or not trait_item then
		return
	end

	local traits = preview_item.__forge_trait_slots or preview_item.traits or {}
	local removed = false

	for i = 1, #traits do
		local slot = traits[i]

		if slot.id == trait_item.name then
			slot.id = nil
			slot.rarity = 0
			slot.value = nil
			removed = true

			break
		end
	end

	if removed then
		rebuild_forge_preview_slots(preview_item)

		if self._forge_trait_inventory then
			if self._forge_trait_inventory.deselect_marked_trait then
				self._forge_trait_inventory:deselect_marked_trait()
			end

			if self._forge_trait_inventory.refresh_selected_marks then
				self._forge_trait_inventory:refresh_selected_marks(preview_item)
			end
		end

		self:_refresh_forge_weapon_stats(preview_item)
	end
end

function RealmsWeaponForgeView:_setup_sort_options()
	return
end

function RealmsWeaponForgeView:_preview_element(element)
	RealmsWeaponForgeView.super._preview_element(self, element)

	local visible = element ~= nil

	self:_set_preview_widgets_visibility(visible)
end

local FORGE_DEFAULT_STAT_VALUE = 0.6

-- Official weapons store their five base stats in the game's canonical order.
-- The forge used to invent an alphabetical one, which made forged weapons look
-- different from official weapons of the same mark. Copy the order from an
-- official item of the same master id, exactly like the vanilla weapon marks
-- view does.
local function forge_base_stat_order(profile, master_id, template_base_stats)
	if not master_id then
		return nil
	end

	local cached_order = WeaponCatalog.base_stat_order and WeaponCatalog.base_stat_order(master_id)

	if cached_order then
		return cached_order
	end

	if not profile then
		return nil
	end

	local catalog = WeaponCatalog.ensure_catalog(profile)
	local items = catalog and catalog.items

	if type(items) ~= "table" then
		return nil
	end

	for i = 1, #items do
		local entry = items[i]

		if entry and entry.origin == "official" and (entry.id == master_id or entry.name == master_id) then
			local stats = entry.overrides and entry.overrides.base_stats

			if type(stats) ~= "table" or #stats == 0 then
				stats = entry.__master_item and entry.__master_item.base_stats
			end

			if type(stats) == "table" and #stats > 0 then
				local order = {}

				for ii = 1, #stats do
					local stat = stats[ii]

					if type(stat) == "table" and type(stat.name) == "string" then
						order[stat.name] = order[stat.name] or ii

						local definition = template_base_stats[stat.name]

						if type(definition) == "table" and type(definition.display_name) == "string" then
							order[definition.display_name] = order[definition.display_name] or ii
						end
					end
				end

				return order
			end
		end
	end

	return nil
end

local function forge_base_stats_from_template(item, profile)
	local WeaponTemplate = require("scripts/utilities/weapon/weapon_template")
	local weapon_template = WeaponTemplate.weapon_template_from_item(item)
	local template_base_stats = weapon_template and weapon_template.base_stats

	if type(template_base_stats) ~= "table" then
		return nil
	end

	local stat_names = {}

	for stat_name in pairs(template_base_stats) do
		stat_names[#stat_names + 1] = stat_name
	end

	local stat_order = forge_base_stat_order(profile, item and (item.name or item.id), template_base_stats)

	local function order_key(stat_name)
		if not stat_order then
			return nil
		end

		local key = stat_order[stat_name]

		if key then
			return key
		end

		local definition = template_base_stats[stat_name]

		if type(definition) == "table" and definition.display_name then
			return stat_order[definition.display_name]
		end

		return nil
	end

	table.sort(stat_names, function (a, b)
		local a_order = order_key(a)
		local b_order = order_key(b)

		if a_order ~= b_order then
			if a_order == nil then
				return false
			elseif b_order == nil then
				return true
			end

			return a_order < b_order
		end

		return a < b
	end)

	local base_stats = {}

	for i = 1, #stat_names do
		base_stats[#base_stats + 1] = {
			name = stat_names[i],
			value = FORGE_DEFAULT_STAT_VALUE
		}
	end

	return base_stats
end

local function selected_forge_slots(slots)
	local selected = {}

	if type(slots) ~= "table" then
		return selected
	end

	for i = 1, #slots do
		local slot = slots[i]

		if type(slot) == "table" and slot.id ~= nil and slot.id ~= "" then
			local copied = {
				id = slot.id,
				rarity = slot.rarity or 0
			}

			if slot.value ~= nil then
				copied.value = slot.value
			end

			selected[#selected + 1] = copied
		end
	end

	return selected
end

rebuild_forge_preview_slots = function (preview_item)
	if type(preview_item) ~= "table" then
		return
	end

	preview_item.perks = selected_forge_slots(preview_item.__forge_perk_slots)

	if type(preview_item.__forge_trait_slots) == "table" then
		preview_item.traits = selected_forge_slots(preview_item.__forge_trait_slots)
	end
end


local function build_forge_preview_item(item, profile)
	if type(item) ~= "table" then
		return item
	end

	local preview_item = table.shallow_copy(item)

	if type(preview_item) ~= "table" then
		return item
	end

	local base_stats = forge_base_stats_from_template(preview_item, profile)
	local uncapped_weapon_stats = mod:get("allow_uncapped_weapon_stats")
	local perk_trait_slot_count = uncapped_weapon_stats and 99 or 2
	local perks = {}
	local traits = {}

	for i = 1, perk_trait_slot_count do
		perks[i] = {
			id = nil,
			rarity = 0
		}
		traits[i] = {
			id = nil,
			rarity = 0
		}
	end

	preview_item.__forge_perk_slots = perks
	preview_item.__forge_trait_slots = traits
	preview_item.perks = {}
	preview_item.traits = {}
	preview_item.base_stats = base_stats
	preview_item.rarity = 6
	preview_item.__forge_stat_cap = uncapped_weapon_stats and 1 or 0.8

	return preview_item
end

function RealmsWeaponForgeView:_present_forge_perks(preview_item)
	if not self._forge_perks_item then
		return
	end

	self._ingredients = {
		item = preview_item,
		existing_perk_index = self._selected_perk_slot_index or 1,
		perk_ids = {},
		perk_master_ids = {},
		tiers = {}
	}

	self._forge_perks_item:present_perks(preview_item, self._ingredients, callback(self, "cb_on_forge_perk_selected"), nil, callback(self, "cb_on_forge_perk_removed"))
end

function RealmsWeaponForgeView:_set_forge_weapon_stats_visible(visible)
	if not self._weapon_stats then
		return
	end

	self._weapon_stats:set_alpha_multiplier(visible and 1 or 0)
	self._weapon_stats:disable_input(not visible)
end

function RealmsWeaponForgeView:_preview_item(item)
	if self._weapon_stats then
		self._weapon_stats:stop_presenting()
	end

	self._previewed_item = item

	if not item then
		return
	end

	local is_attachment_template = item.__forge_attachment_template == true
	local preview_item

	if is_attachment_template then
		local build_ok, built_preview_item = pcall(function ()
			return AttachmentCatalog.build_forge_preview_item(item)
		end)

		if not build_ok or type(built_preview_item) ~= "table" then
			preview_item = item
		else
			preview_item = built_preview_item
		end

		self._forge_preview_item = preview_item
		self:_set_forge_perks_grid_height(970)

		if self._forge_trait_inventory and self._forge_trait_inventory.hide then
			self._forge_trait_inventory:hide()
		end

		local ok, err = pcall(function ()
			self._weapon_stats:present_item(preview_item, {
				hide_source = true
			})
		end)

		if not ok then
			mod:warning("realms_loadout failed to present forge attachment stats: %s", tostring(err))

			if self._weapon_stats then
				self._weapon_stats:stop_presenting()
			end
		end

		self:_present_forge_perks(preview_item)

		return
	end

	local player = self._preview_player or Managers.player:local_player(1)
	local profile = player and player:profile()
	local build_ok, built_preview_item = pcall(function ()
		return build_forge_preview_item(item, profile)
	end)

	if not build_ok or type(built_preview_item) ~= "table" then
		preview_item = item
	else
		preview_item = built_preview_item
	end

	self._forge_preview_item = preview_item
	self:_set_forge_weapon_stats_visible(true)
	self:_set_forge_perks_grid_height(self._forge_perks_height or 550)
	self:_restore_forge_trait_inventory_position()

	if self._forge_trait_inventory and self._forge_trait_inventory.show then
		self._forge_trait_inventory:show()
	end

	local ok, err = xpcall(function ()
		self._weapon_stats:present_item(preview_item, {
			hide_source = true
		})
	end, function (error_message)
		return debug.traceback(tostring(error_message), 2)
	end)

	if not ok then
		mod:warning("realms_loadout failed to present forge weapon stats: %s", tostring(err))

		if self._weapon_stats then
			self._weapon_stats:stop_presenting()
		end
	end

	self:_present_forge_perks(preview_item)
	self:_present_forge_trait_inventory(preview_item)
end

function RealmsWeaponForgeView:_set_preview_widgets_visibility(visible)
	local widgets_by_name = self._widgets_by_name

	if widgets_by_name.price_text then
		widgets_by_name.price_text.content.visible = false
	end

	if widgets_by_name.price_icon then
		widgets_by_name.price_icon.content.visible = false
	end

	if widgets_by_name.purchase_button then
		widgets_by_name.purchase_button.content.visible = visible
	end

	if widgets_by_name.info_box then
		widgets_by_name.info_box.content.visible = false
	end
end

function RealmsWeaponForgeView:_setup_input_legend()
	self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 40)

	local legend_inputs = self._definitions and self._definitions.legend_inputs

	if not legend_inputs then
		return
	end

	for i = 1, #legend_inputs do
		local legend_input = legend_inputs[i]

		self._input_legend_element:add_entry(
			legend_input.display_name,
			legend_input.input_action,
			legend_input.visibility_function,
			legend_input.on_pressed_callback and callback(self, legend_input.on_pressed_callback),
			legend_input.alignment
		)
	end
end

function RealmsWeaponForgeView:_register_button_callbacks()
	local purchase_button = self._widgets_by_name.purchase_button

	if purchase_button and purchase_button.content and purchase_button.content.hotspot then
		purchase_button.content.hotspot.pressed_callback = callback(self, "cb_on_obtain_pressed")
	end
end

function RealmsWeaponForgeView:cb_on_obtain_pressed()
	local preview_item = self._forge_preview_item

	if not preview_item then
		mod:notify(mod:localize("forge_obtain_error"))

		return
	end

	local player = self._preview_player or Managers.player:local_player(1)
	local profile = player and player:profile()

	if not profile then
		mod:notify(mod:localize("forge_obtain_error"))

		return
	end

	local is_attachment_template = preview_item.__forge_attachment_template == true

	local ok, obtained_item, obtain_error = pcall(function ()
		if is_attachment_template then
			return AttachmentCatalog.add_forge_attachment(profile, preview_item)
		end

		return WeaponCatalog.add_forge_weapon(profile, preview_item, nil)
	end)

	if ok and obtained_item then
		if is_attachment_template then
			mod:notify(mod:localize("forge_attachment_obtain_success"))
		else
			mod:notify(mod:localize("forge_obtain_success"))
		end
	else
		if obtain_error then
			if is_attachment_template then
				mod:warning("realms_loadout failed to obtain forge attachment: %s", tostring(obtain_error))
			else
				mod:warning("realms_loadout failed to obtain forge weapon: %s", tostring(obtain_error))
			end
		end

		if is_attachment_template then
			mod:notify(mod:localize("forge_attachment_obtain_error"))
		else
			mod:notify(mod:localize("forge_obtain_error"))
		end
	end
end

function RealmsWeaponForgeView:on_back_pressed()
	local parent = self._parent

	if parent and type(parent._force_select_panel_index) == "function" then
		parent:_force_select_panel_index(1)

		return
	end

	Managers.ui:close_view(self.view_name)
end

function RealmsWeaponForgeView:can_exit()
	return true
end

function RealmsWeaponForgeView:update(dt, t, input_service)
	return RealmsWeaponForgeView.super.update(self, dt, t, input_service)
end

function RealmsWeaponForgeView:draw(dt, t, input_service, layer)
	return RealmsWeaponForgeView.super.draw(self, dt, t, input_service, layer)
end

function RealmsWeaponForgeView:on_resolution_modified(scale)
	RealmsWeaponForgeView.super.on_resolution_modified(self, scale)
end

function RealmsWeaponForgeView:on_exit()
	RealmsWeaponForgeView.super.on_exit(self)
end

ui_owner._ui_class_RealmsWeaponForgeView = RealmsWeaponForgeView
return RealmsWeaponForgeView
