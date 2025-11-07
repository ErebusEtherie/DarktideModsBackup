local mod = get_mod("DumpStatFinder")

local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local TextInputPassTemplates = require("scripts/ui/pass_templates/text_input_pass_templates")
local WeaponStats = require("scripts/utilities/weapon_stats")
local ItemUtils = require("scripts/utilities/items")
local RaritySettings = require("scripts/settings/item/rarity_settings")
--local ViewElementGrid = require("scripts/ui/view_elements/view_element_grid/view_element_grid")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local MasterItems = require("scripts/backend/master_items")
--local LocalizationManager = require("scripts/managers/localization/localization_manager")
local UISettings = require("scripts/settings/ui/ui_settings")
local screen = UIWorkspaceSettings.screen
local MAX_FILTERS_PER_PATTERN = 2 --fallback value if not defined in settings
mod.debug = false
local function debug_print(...)
	if mod.debug then
		print(debug.getinfo(2).name, ...)
	end
end

--this is the additional funtion called to process special filters for ripper and plasma
local function is_dump_stat_weapon_ex(pattern, item_max_stats, item)
	local has_dump_stat = false
	local has_dual_dump_stats = false
	local is_special = false

	if pattern == "ogryn_rippergun_p1" then
		--debug_print("ogryn_rippergun_p1 special filter")
		--debug_inspect("item", item)
		local ammo_stat = item_max_stats["loc_stats_display_ammo_stat"]
		local range_stat = item_max_stats["loc_stats_display_range_stat"]
		local damage_stat = item_max_stats["loc_stats_display_damage_stat"]
		--debug_print("ogryn_rippergun_p1 special filter", ammo_stat.value, range_stat.value, damage_stat.value)
		if
			ammo_stat
			and ammo_stat.value > 62
			and ammo_stat.value <= 66
			and range_stat
			and range_stat.value == 80 --max range and damage means rest is dumped into collateral and stability
			and damage_stat
			and damage_stat.value == 80
		then
			--debug_print("***** Ripper Special Filter", ammo_stat.value)
			--mod:echo("***** Ripper PERFECT")
			if ammo_stat.value == 66 then
				if item.gear_id and not ItemUtils.is_item_id_favorited(item.gear_id) then
					mod:echo(mod:localize("perfect_ripper"))
					mod:notify(mod:localize("perfect_ripper"))
					ItemUtils.set_item_id_as_favorite(item.gear_id, true)
				end
			end

			has_dual_dump_stats = true
			is_special = true
		end
	elseif pattern == "plasmagun_p1" then
		--debug_print("plasmagun_p1 special filter")
		local damage_stat = item_max_stats["loc_stats_display_damage_stat"]
		local ammo_stat = item_max_stats["loc_stats_display_ammo_stat"]
		local power_stat = item_max_stats["loc_stats_display_power_stat"]
		local heat_stat = item_max_stats["loc_stats_display_heat_management"]
		local charge_stat = item_max_stats["loc_stats_display_charge_speed"]
		if
			(damage_stat.value == 80 and power_stat.value == 80 and ammo_stat.value == 80)
			and (heat_stat.value > 62 and charge_stat.value > 62)
			and (heat_stat.value <= 72 and charge_stat.value <= 72)
			and (heat_stat.value + charge_stat.value <= 140)
		then
			if heat_stat and heat_stat.value == 69 and charge_stat and charge_stat.value == 71 then -- nice!
				if item.gear_id and not ItemUtils.is_item_id_favorited(item.gear_id) then
					mod:echo(mod:localize("perfect_plasma"))
					mod:notify(mod:localize("perfect_plasma"))
					ItemUtils.set_item_id_as_favorite(item.gear_id, true)
				end
			end
			--debug_print("***** Plasma Special Filter 2", heat_stat.value, charge_stat.value)
			--mod:echo("***** Plasma PERFECT")
			has_dual_dump_stats = true
			is_special = true
		end
	end
	return has_dump_stat, has_dual_dump_stats, is_special
end
local dump_stat_filters = {}
local function build_filter_list()
	debug_print("BUILDING filters")
	dump_stat_filters = nil
	dump_stat_filters = {}
	local max_filters = mod:get("setting_max_filters") or MAX_FILTERS_PER_PATTERN

	for pattern, _ in pairs(UISettings.weapon_patterns) do
		local idx = 1
		for i = 1, max_filters, 1 do
			local setting_id = pattern .. "_" .. i
			local filter_stat = mod:get(setting_id)
			--debug_print("CHECKING filter:", setting_id, filter_stat)
			if filter_stat ~= "" then
				local setting_id_inc = pattern .. "_" .. idx
				dump_stat_filters[setting_id_inc] = filter_stat
				if mod.debug then
					local display_name = Localize("loc_weapon_family_" .. pattern .. "_m1")
					debug_print("SETTING filter:", idx, i, display_name, pattern, Localize(filter_stat), filter_stat)
				end

				idx = idx + 1
			end
		end
	end
end
--local DumpStatFinderSettings = mod:io_dofile("DumpStatFinder/scripts/mods/DumpStatFinder/DumpStatFinderSettings")
--mod:io_dofile("DumpStatFinder/scripts/mods/DumpStatFinder/Utils")

--[[
local weapon_groups = DumpStatFinderSettings.weapon_groups
local stat_display_name_list = DumpStatFinderSettings.dump_stat_display_name_list
local dump_stat_filter_list = DumpStatFinderSettings.dump_stat_filter_list
local friendly_names = DumpStatFinderSettings.friendly_names
--local max_dump_stat_value = 62
--local num_buttons_to_show = 8
 ]]

local offset_x = 460
local offset_y = -60

local CreditsGoodsVendorView = "credits_goods_vendor_view"
--mod.setting_max_dump_stat_value = max_dump_stat_value
local max_expertise_level = ItemUtils.max_expertise_level()
--local weapon_patterns = UISettings.weapon_patterns
local button_labels = {}
local button_names = {
	"reset_button",
	"dumpstat_button",
	"favorites_button",
	"select_weapon_pattern_button",
	"favorite_set_button",
	"favorite_clear_button",
}
for i = 1, #button_names, 1 do --lazy, paral arr
	button_labels[i] = mod:localize(button_names[i])
end

--LocalizationManager.append_backend_localizations(button_table)
local function is_debug()
	return mod.debug
end

local function debug_inspect(name, obj)
	local mt = get_mod("modding_tools")
	if mt and mod.debug then
		mt:inspect(name, obj)
	end
end

mod.get_settings = function()
	--mod._is_enabled = mod:is_enabled()
	mod.debug = mod:get("setting_debug")
	mod.max_dump_stat_value = mod:get("setting_max_dump_stat_value") or 62
	mod.vertical_alignment = mod:get("setting_vertical_alignment")
	--mod.setting_tabbed_filters_in_vendor = mod:get("setting_tabbed_filters_in_vendor")
	mod.inventory_use_panel = false

	local valign = mod.vertical_alignment

	if valign == "bottom" then
		offset_y = -60
	elseif valign == "top" then
		offset_y = 10
	end
	mod.sainted_quality = mod:get("setting_sainted_quality")
	mod.sainted_only_max = mod:get("setting_sainted_only_max")
	mod.recolor_dump = mod:get("setting_recolor_dump")
	mod.recolor_dump = mod:get("setting_recolor_dump")
	mod.recolor_dump_text = mod:get("setting_recolor_dump_text")
	mod.recolor_only_max = mod:get("setting_recolor_only_max")
	mod.special_filters = mod:get("setting_special_filters")

	local color_name = mod:get("setting_dump_color")
	mod.dump_color = Color[color_name](255, true)
	color_name = mod:get("setting_dump_color_dark")
	mod.dump_color_dark = Color[color_name](255, true)
	color_name = mod:get("setting_dump_color_text")
	mod.dump_color_text = Color[color_name](255, true)
	build_filter_list()
end

mod.get_settings()

local function has_value(t, v)
	for index, value in ipairs(t) do
		if value == v then
			return true
		end
	end

	return false
end
local function _sort_grid(self)
	local sort_options = self._sort_options

	if sort_options then
		local sort_index = self._selected_sort_option_index or 1
		local selected_sort_option = sort_options[sort_index]
		local selected_sort_function = selected_sort_option.sort_function

		self:_sort_grid_layout(selected_sort_function)
	else
		self:_sort_grid_layout()
	end
end
local function _reset_properties(self)
	mod.select_weapon_pattern(nil)
	mod.item_filter_text = nil
	self._filter_options = nil
	mod.slot_filter = nil
	mod.negate_filter = nil
end

local function _get_grid_item_counts(self)
	return (self._filtered_offer_items_layout and #self._filtered_offer_items_layout),
		(self._offer_items_layout and #self._offer_items_layout)
end
local function _get_scenegraph_size(self, scenegraph_id)
	local definitions = self._definitions
	local scenegraph_definition = definitions.scenegraph_definition
	local grid_scenegraph = scenegraph_definition[scenegraph_id]

	return grid_scenegraph.size
end

local function _update_filter_counts(self)
	local filtered_count, total_count = _get_grid_item_counts(self)
	debug_print("_update_filter_counts", filtered_count, total_count)
	if filtered_count and total_count then
		local text = string.format("%s (%d/%d)", button_labels[1], filtered_count, total_count)
		if self._widgets_by_name.reset_button then
			self._widgets_by_name.reset_button.content.text = text
		end
		-- if mod.setting_inventory_use_panel then
		-- 	if self._weapon_options_element then
		-- 		self._weapon_options_element._widgets_by_name.widget_entry_4.content.text = text
		-- 	end
		-- end
	end
end
local function _refresh_grid(self, optional_display_name)
	local display_name = mod.optional_display_name
	--display_name = "loc_inventory_menu_zoom_in"
	display_name = "loc_inventory_view_display_name"
	if mod.weapon_pattern_filter then
		display_name = "loc_weapon_family_" .. mod.weapon_pattern_filter .. "_m1"
		mod.optional_display_name = display_name
	end
	-- if optional_display_name then
	-- 	display_name = optional_display_name
	-- end
	local tabs_content = self._tabs_content
	if tabs_content and self._tab_menu_element and self.view_name ~= "credits_vendor_view" then
		local index = self._tab_menu_element._selected_index
		local tab_content = tabs_content[index]
		local slot_types = tab_content.slot_types
		display_name = tab_content.display_name
		mod.slot_filter = slot_types
	end
	self:_present_layout_by_slot_filter(mod.slot_filter, mod.item_type_filter, display_name)
end

local function get_weapon_name_id(weapon_full_path)
	local last_slash_pos = string.match(weapon_full_path, "^.*()/")
	if not last_slash_pos then
		return weapon_full_path
	end
	--local start_pos,end_pos = string.find(item.name, "/")
	local weapon_name = string.sub(weapon_full_path, last_slash_pos + 1)
	--print(weapon_name)
	return weapon_name
end

local function get_weapon_pattern_id(weapon_name)
	local pos = string.find(weapon_name, "_common")
	local weapon_pattern = nil
	if pos then
		weapon_name = string.sub(weapon_name, 0, pos - 1)
	end
	pos = string.find(weapon_name, "_p%d_m%d")
	--local start_pos,end_pos = string.find(item.name, "/")
	if pos then
		weapon_pattern = string.sub(weapon_name, 0, pos + 2)
		--debug_print(weapon_name)
	end
	return weapon_pattern
end

-- local function get_weapon_group_name(weapon_name)
-- 	local pos = string.find(weapon_name, "_common")
-- 	if pos then
-- 		weapon_name = string.sub(weapon_name, 0, pos - 1)
-- 	end

-- 	for weapon_group, weapon_names_list in pairs(weapon_groups) do
-- 		for i = 1, #weapon_names_list, 1 do
-- 			if weapon_names_list[i] == weapon_name then
-- 				return weapon_group
-- 			end
-- 		end
-- 	end
-- end

mod.do_dump_stat_filter = false
mod.do_weapon_pattern_filter = false
mod.do_favorites_filter = false

mod.favorite_filter_function = function(entry)
	if entry == nil or entry.item == nil then
		debug_print("NIL Item")
		return false
	end

	local item = entry.item
	local is_fav = ItemUtils.is_item_id_favorited(item.gear_id)

	if mod.weapon_pattern_filter then
		is_fav = is_fav and mod.weapon_pattern_filter_function(entry)
	end
	if mod.negate_filter then
		is_fav = not is_fav
	end
	return is_fav
end

mod.not_favorite_filter_function = function(entry)
	if entry == nil or entry.item == nil then
		debug_print("NIL Item")
		return false
	end
	local item = entry.item
	return ItemUtils.is_item_id_favorited(item.gear_id)
end
mod.weapon_pattern_filter_function = function(entry)
	if entry == nil or entry.item == nil then
		debug_print("NIL Item")
		return false
	end
	local item = entry.item
	if not ItemUtils.is_weapon(item.item_type) then
		return false
	end
	local weapon_pattern_filter = mod.weapon_pattern_filter
	if weapon_pattern_filter then
		local weapon_name = get_weapon_name_id(item.name)
		local weapon_pattern = get_weapon_pattern_id(weapon_name)
		-- local lore_family_name = ItemUtils.weapon_lore_family_name(item)
		-- local lore_pattern_name = ItemUtils.weapon_lore_pattern_name(item)
		-- local lore_mark_name = ItemUtils.weapon_lore_mark_name(item)
		--local display_name = ItemUtils.display_name(item)
		--debug_print("weapon_pattern_filter_function", weapon_name, display_name)
		if weapon_pattern == weapon_pattern_filter then
			return true
		end
	end
	return false
end

local function get_trait_name(trait)
	local item = MasterItems.get_item(trait.id)
	local trait_name = ItemUtils.display_name(item)

	return trait_name
end

local function get_item_blessings(item, is_curio)
	-- if not ItemUtils.is_weapon(item.item_type) then
	-- 	return ""
	-- end

	local item_traits = item.traits
	local item_properties = " "
	if not item_traits then
		return ""
	end

	for i = 1, #item_traits, 1 do
		if item_traits[i] then
			item_properties = item_properties .. "  b:" .. get_trait_name(item_traits[i]) .. " "
		end
	end
	return item_properties
end

local function nocase(str)
	str = string.gsub(str, "%a", function(c)
		return string.format("[%s%s]", string.lower(c), string.upper(c))
	end)
	return str
end

local function split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

local function trim(s)
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

mod.item_text_filter_function = function(entry)
	if entry == nil or entry.item == nil then
		debug_print("NIL Item")
		return false
	end

	local item = entry.item

	if not ItemUtils.is_weapon(item.item_type) then
		return false
	end

	local item_filter_text = mod.item_filter_text
	if not item_filter_text then
		return false
	end

	local name = get_weapon_name_id(item.name)
	--local pattern = ItemUtils.weapon_lore_pattern_name(item)
	local blessings = get_item_blessings(item)

	local display_name = ItemUtils.display_name(item)
	local full_display_name = display_name .. " " .. blessings
	local search_string = string.lower(full_display_name)
	--debug_print("item_text_filter_function", item_filter_text, search_string)
	local search_term_list = split(item_filter_text, "&") --TODO: caching b4 call
	local search_term
	if search_term_list and #search_term_list < 2 then
		if string.find(search_string, item_filter_text) then
			return true
		end
	else
		local found = true
		for j = 1, #search_term_list do
			search_term = trim(search_term_list[j])
			found = found and (string.find(search_string, search_term) ~= nil)
		end

		return found
	end
end

local function value_lerp_2dp(min, max, lerp_t)
	local value = math.lerp(min, max, lerp_t)
	value = math.round_with_precision(value, 2)
	return value
end

--see scripts\settings\buff\gadget_buff_templates.lua
local function is_dump_stat_curio(item)
	if item == nil then
		debug_print("NIL Item")
		return false, false
	end
	if item.item_type == nil or (item.item_type and item.item_type ~= "GADGET") then
		return false, false
	end

	local item_trait = item.traits[1]
	--debug_print(string.format("is_dump_stat_curio() %s %f", item_trait.id, item_trait.value))
	--content/items/traits/gadget_inate_trait/trait_inate_gadget_health
	if string.find(item_trait.id, "health_segment", 59) then
		return false, false
	end
	if string.find(item_trait.id, "health", 59) then
		local value = value_lerp_2dp(0.05, 0.25, item_trait.value)
		--debug_print(string.format("\tvalue lerp %f", value))
		return value >= 0.21, false
	end
	if string.find(item_trait.id, "toughness", 59) then
		local value = value_lerp_2dp(0.05, 0.2, item_trait.value)
		--debug_print(string.format("\tvalue lerp %f", value))
		return value >= 0.17, false
	end
	if string.find(item_trait.id, "stamina", 59) then
		--print("stamina", item_trait.value)
		return item_trait.value >= 0.75, false
	end

	return false, false
end

--[[ local function is_dump_stat_weapon(item)
	if not ItemUtils.is_weapon(item.item_type) then
		return is_dump_stat_curio(item)
		--return false, false
	end

	local weapon_stats = WeaponStats:new(item)
	local comparing_stats = weapon_stats:get_comparing_stats()
	local has_dump_stat = false
	local item_max_stats = ItemUtils.preview_stats_change(item, max_expertise_level, comparing_stats)
	local has_dual_dump_stats = item_max_stats["loc_stats_display_mobility_stat"]
		and item_max_stats["loc_stats_display_defense_stat"]

	if has_dual_dump_stats then
		local value_dual = item_max_stats["loc_stats_display_mobility_stat"].value
			+ item_max_stats["loc_stats_display_defense_stat"].value
		has_dual_dump_stats = value_dual < 140
		if has_dual_dump_stats then
			--debug_print("dump_stat_filter_function has_dual_dump_stats <140", item.name)
			return has_dump_stat, has_dual_dump_stats
		end
	end

	for dump_stat_i = 1, #stat_display_name_list, 1 do
		local dump_stat_name = stat_display_name_list[dump_stat_i]
		if dump_stat_name == nil then
			mod:warning(string.format("Cannot find dump stat named %s , not filtering this item", dump_stat_name))
			return true, false
		end
		local has_slash = string.find(dump_stat_name, "/")
		local weapon_group_name = nil
		local stat
		if has_slash then
			weapon_group_name = string.sub(dump_stat_name, 1, has_slash - 1)
			dump_stat_name = string.sub(dump_stat_name, has_slash + 1)
			if weapon_group_name then
				local weapon_group = weapon_groups[weapon_group_name]
				local weapon_name = get_weapon_name_id(item.name)

				if has_value(weapon_group, weapon_name) then
					stat = item_max_stats[dump_stat_name]
					--debug_print("dump_stat_filter_function", dump_stat_name, weapon_group_name, weapon_name, stat.value)
				end
			end
		else
			stat = item_max_stats[dump_stat_name]
		end
		if stat then
			has_dump_stat = stat.value <= mod.max_dump_stat_value
			if has_dump_stat then
				return has_dump_stat, has_dual_dump_stats
			end
		end
	end
	return has_dump_stat, has_dual_dump_stats
end ]]
local function is_dump_stat_dummy(item)
	return true, true
end

local function is_dump_stat_weapon3(item)
	if item == nil then
		debug_print("NIL Item")
		return false, false
	end
	if not ItemUtils.is_weapon(item.item_type) then
		return is_dump_stat_curio(item)
	end
	local item_base_stats = item.base_stats

	if item_base_stats == nil or table.is_empty(item_base_stats) or item.__master_item == nil then --NO stats. Brunt's Armory likely, just exit
		--debug_print("NO item_base_stats")
		return false, false
	end

	local weapon_stats = WeaponStats:new(item)
	local comparing_stats = weapon_stats:get_comparing_stats()

	local has_dump_stat = false
	local is_special = false
	local has_dual_dump_stats = false

	local item_max_stats = ItemUtils.preview_stats_change(item, max_expertise_level, comparing_stats)

	local mobility_stat = item_max_stats["loc_stats_display_mobility_stat"]
	if mobility_stat and mobility_stat.value <= mod.max_dump_stat_value then
		return true, false
	end
	local defense_stat = item_max_stats["loc_stats_display_defense_stat"]
	if defense_stat and defense_stat.value <= mod.max_dump_stat_value then
		return true, false
	end

	has_dual_dump_stats = mobility_stat and defense_stat
	if has_dual_dump_stats then
		local sum_dual_stats = mobility_stat.value + defense_stat.value
		has_dual_dump_stats = sum_dual_stats <= 140
		if has_dual_dump_stats then
			--			debug_print("DUMP mobility_stat AND defense_stat")
			return has_dump_stat, has_dual_dump_stats
		end
	end
	local pattern = item.parent_pattern
	if mod.special_filters then
		has_dump_stat, has_dual_dump_stats, is_special = is_dump_stat_weapon_ex(pattern, item_max_stats, item)
	end

	if has_dump_stat or has_dual_dump_stats then
		return has_dump_stat, has_dual_dump_stats, is_special
	end
	has_dump_stat, has_dual_dump_stats, is_special = false, false, false
	local max_filters = mod:get("setting_max_filters")

	--we didn't find a dump stat in special filters, check the filters
	for i = 1, max_filters, 1 do
		local id = pattern .. "_" .. i
		local dump_stat_name = dump_stat_filters[id]
		if not dump_stat_name then --no additional matching filter rule after mobil, defense and special filters
			--debug_print("NO FILTER", pattern, i, #dump_stat_filters)
			return false
		end
		if dump_stat_name == "" then --no stat for this item, no rule, shouldn't be here but better safe
			--mod:warning(string.format("Cannot find dump stat named %s , not filtering this item", dump_stat_name))
			debug_print("'NONE' FILTER !", id)
			return false
		end
		local stat = item_max_stats[dump_stat_name]
		if stat then
			--debug_print(id, dump_stat_name, stat.value)
			has_dump_stat = stat.value <= mod.max_dump_stat_value
			if has_dump_stat then
				--debug_print("DUMP ", dump_stat_name, has_dump_stat, has_dual_dump_stats)
				return has_dump_stat, has_dual_dump_stats
			end
		end
	end

	--debug_print("DUMP default end return", has_dump_stat, has_dual_dump_stats)
	return has_dump_stat, has_dual_dump_stats
end
--[[ 
local function is_dump_stat_weapon2(item)
	if not ItemUtils.is_weapon(item.item_type) then
		return is_dump_stat_curio(item)
		--return false, false
	end
	local dump_stat_name
	local loc_stat_name
	local min = 60
	local max = mod.max_dump_stat_value
	local weapon_stats = WeaponStats:new(item)
	local comparing_stats = weapon_stats:get_comparing_stats()
	local has_dump_stat = false
	local item_max_stats = ItemUtils.preview_stats_change(item, max_expertise_level, comparing_stats)
	local has_dual_dump_stats = item_max_stats["loc_stats_display_mobility_stat"]
		and item_max_stats["loc_stats_display_defense_stat"]

	if has_dual_dump_stats then
		local value_dual = item_max_stats["loc_stats_display_mobility_stat"].value
			+ item_max_stats["loc_stats_display_defense_stat"].value
		has_dual_dump_stats = value_dual < 140
		if has_dual_dump_stats then
			--debug_print("dump_stat_filter_function has_dual_dump_stats <140", item.name)
			return has_dump_stat, has_dual_dump_stats
		end
	end

	for i = 1, #is_dump_stat_weapon2, 1 do
		local filter = is_dump_stat_weapon2[i]
		dump_stat_name = filter.stat
		if dump_stat_name == nil then
			mod:warning(string.format("Cannot find dump stat named %s , not filtering this item", dump_stat_name))
			return true, false
		end
		min = filter.min or 60
		max = filter.max or mod.max_dump_stat_value
		loc_stat_name = friendly_names[dump_stat_name]
		local weapon_group_name = nil
		local stat
		stat = item_max_stats[loc_stat_name]
		if stat then
			has_dump_stat = stat.value >= min and stat.value <= max
			if has_dump_stat then
				return has_dump_stat, has_dual_dump_stats
			end
		end
	end
	return has_dump_stat, has_dual_dump_stats
end ]]

local function is_max_rating(item)
	if item == nil then
		debug_print("NIL Item")
		return false
	end
	local rating_value = 0
	local has_rating = false
	if not ItemUtils.is_weapon(item.item_type) then
		return false
	end

	rating_value, has_rating = ItemUtils.expertise_level(item, true)
	if has_rating then
		rating_value = tonumber(rating_value) or 0
	end
	local is_max = rating_value == max_expertise_level
	return is_max
end

local function hook_dump_color()
	mod:hook_require("scripts/utilities/items", function(Items)
		if mod.sainted_quality then
			Items.rarity_display_name = function(item)
				if item == nil then
					debug_print("NIL Item")
					return "NIL"
				end
				local has_dump_stat, has_dual_dump, is_special = is_dump_stat_weapon3(item)
				local is_dump = has_dump_stat or has_dual_dump
				local rarity_settings = RaritySettings[item.rarity]
				local loc_key = rarity_settings and rarity_settings.display_name
				local rarity_display_name_localized = loc_key and Localize(loc_key) or ""
				if
					(is_dump and mod.sainted_quality and not mod.sainted_only_max)
					or (is_dump and mod.sainted_quality and mod.sainted_only_max and is_max_rating(item))
				then
					rarity_display_name_localized = Localize("loc_item_weapon_rarity_6")
				end

				return rarity_display_name_localized
			end
		end
		if mod.recolor_dump or mod.sainted_quality then
			Items.rarity_color = function(item)
				if item == nil then
					debug_print("NIL Item")
					return "NIL"
				end

				local rarity_settings = RaritySettings[item and item.rarity] or RaritySettings[0]
				local has_dump_stat, has_dual_dump, is_special = is_dump_stat_weapon3(item)
				local is_dump = has_dump_stat or has_dual_dump
				if
					(is_dump and mod.sainted_quality and not mod.sainted_only_max)
					or (is_dump and mod.sainted_quality and mod.sainted_only_max and is_max_rating(item))
				then
					return Color.item_rarity_6(255, true), Color.item_rarity_dark_6(255, true)
				end
				if
					(is_dump and mod.recolor_dump and not mod.recolor_only_max and not mod.sainted_quality)
					or (
						is_dump
						and mod.recolor_dump
						and mod.recolor_only_max
						and is_max_rating(item)
						and not mod.sainted_quality
					)
				then
					return mod.dump_color, mod.dump_color_dark
				end
				return rarity_settings.color, rarity_settings.color_dark
			end
		end

		if mod.recolor_dump_text or mod.sainted_quality then
			Items.weapon_card_display_name = function(item)
				if mod.recolor_dump_text or mod.sainted_quality then
					local has_dump_stat, has_dual_dump, is_special = is_dump_stat_weapon3(item)
					--local has_dump_stat = false
					--local has_dual_dump = false
					if has_dump_stat or has_dual_dump then
						local c = mod.dump_color_text
						local str = string.format(
							"{#color(%d,%d,%d)}%s{#reset()}",
							c[2],
							c[3],
							c[4],
							Items.weapon_lore_family_name(item)
						)
						if is_special then
							str = str .. " *"
						end

						return str
					end
				end
				local str = Items.weapon_lore_family_name(item)
				return str
			end
		end
	end)
end

if mod.recolor_dump or mod.recolor_dump_text or mod.sainted_quality then
	hook_dump_color()
end

mod.dump_stat_filter_function = function(entry)
	if entry == nil or entry.item == nil then
		debug_print("NIL Item")
		return false
	end
	--debug_print("dump_stat_filter_function")
	local item = entry.item
	-- if not ItemUtils.is_weapon(item.item_type) then
	-- 	return false
	-- end

	-- local base_stats = item.base_stats
	-- local stat_value, dump_stat
	local has_dump_stat, has_dual_dump_stats, is_special = is_dump_stat_weapon3(item)

	local is_match = (not has_dual_dump_stats and has_dump_stat) or has_dual_dump_stats
	if is_match then
		if mod.item_filter_text then
			is_match = is_match and mod.item_text_filter_function(entry)
		end
		if mod.weapon_pattern_filter then
			is_match = is_match and mod.weapon_pattern_filter_function(entry)
		end
		if mod.negate_filter then
			is_match = not is_match
		end
		return is_match
	end
	if mod.negate_filter then
		return true
	end

	return false
end

mod.item_filter_function = function(entry) --aggregate filter
	if entry == nil or entry.item == nil then
		debug_print("NIL Item")
		return false
	end
	local add_entry = false
	if mod.do_dump_stat_filter then
		add_entry = add_entry or mod.dump_stat_filter_function(entry)
	end
	if mod.do_favorites_filter then
		add_entry = add_entry or mod.favorite_filter_function(entry)(entry)
	end
	if mod.do_weapon_pattern_filter then
		add_entry = add_entry or mod.weapon_pattern_filter(entry)
	end
end
local function update_item_filter_text(self)
	local item_filter_text = self._widgets_by_name.item_filter_text_input.content.input_text
	debug_print("item_filter_text", item_filter_text)
	if item_filter_text == "" then
		mod.item_filter_text = nil
	elseif item_filter_text then
		mod.item_filter_text = string.lower(item_filter_text)
	end
end

local function filter_dump_stat(self, negate_filter)
	--local self = mod._view
	if not self._filter_options then
		self._filter_options = {}
	end
	update_item_filter_text(self)
	mod.negate_filter = negate_filter
	self._filter_options.filter_function = mod.dump_stat_filter_function

	_refresh_grid(self)
	mod.negate_filter = false
end
local function filter_item_text(self)
	update_item_filter_text(self)
	if not mod.item_filter_text then
		return
	end
	--local self = mod._view
	if not self._filter_options then
		self._filter_options = {}
	end
	self._filter_options.filter_function = mod.item_text_filter_function

	_refresh_grid(self)
end

local function filter_favorites(self, negate_filter)
	--local view = mod._view
	if not self._filter_options then
		self._filter_options = {}
	end
	mod.negate_filter = negate_filter
	self._filter_options.filter_function = mod.favorite_filter_function
	_refresh_grid(self)
	mod.negate_filter = false
end

local function filter_not_favorites(self)
	--local self = mod._view
	if not self._filter_options then
		self._filter_options = {}
	end
	self._filter_options.filter_function = mod.not_favorite_filter_function
	_refresh_grid(self)
end

local function dump_selected_item(self)
	local item_grid = self._item_grid
	local widget_index = item_grid:selected_grid_index()
	local selected_element = widget_index and item_grid:element_by_index(widget_index)
	local selected_item = selected_element and selected_element.item

	debug_inspect("selected_item", selected_item)
end

local function select_weapon_pattern(self)
	Managers.ui:open_view(CreditsGoodsVendorView, nil, nil, nil, nil, {
		parent = nil,
		fetch_store_items_on_enter = true,
		select_weapon_pattern = true,
		--hub_interaction = true,
		use_item_categories = true,
		fetch_account_items = true,
		use_title = true,
		hide_price = true,
		debug = true,
	})
end

local set_favorites = function(self, favorite)
	--if do_filter then
	--end
	local offer_layout = self._offer_items_layout
	local filtered_layout = self._filtered_offer_items_layout
	local filtered_items_count = #filtered_layout
	local total_item_count = #offer_layout

	if filtered_layout == nil then
		return
	end
	if filtered_layout == total_item_count then
		mod:warning("Item List is not filtered, not settign any favorites")
		return
	end
	for i = 1, filtered_items_count do
		if
			filtered_layout[i]
			and filtered_layout[i].item
			and filtered_layout[i].item.__master_item
			and filtered_layout[i].item.__master_item.display_name
		then
			local item = filtered_layout[i].item
			if item then
				ItemUtils.set_item_id_as_favorite(item.gear_id, favorite)
			end
		end
	end
end

local function close_goods_view()
	if Managers.ui:view_active(CreditsGoodsVendorView) then
		debug_print("close_goods_view()")
		local force_close = false
		Managers.ui:close_view(CreditsGoodsVendorView, force_close)
	end
end

local function _reset_grid(self, optional_display_name)
	_reset_properties(self)
	_refresh_grid(self)
end

local function reset_grid(self)
	_reset_grid(self)
	close_goods_view()
end

local function view_definition_add(view_definition)
	if not view_definition then
		return
	end
	if view_definition.widget_definitions == nil then
		view_definition.widget_definitions = {}
		debug_print("widget_definitions nil")
	end
	if view_definition.scenegraph_definition == nil then
		view_definition.scenegraph_definition = {}
		debug_print("scenegraph_definition nil")
	end
	local button_size = ButtonPassTemplates.terminal_button_small.size
	local parent = button_names[1]

	view_definition.widget_definitions.reset_button =
		UIWidget.create_definition(table.clone(ButtonPassTemplates.terminal_button_small), button_names[1], {
			text = button_labels[1],
			hotspot = {},
			--tooltip_text = "ToolTip goes here",
		})

	view_definition.scenegraph_definition.reset_button = {
		parent = "screen",
		vertical_alignment = mod.vertical_alignment,
		size = { button_size[1], 30 },
		position = { offset_x + (button_size[1] + 10), offset_y, 696 }, --nice Z index
	}

	view_definition.widget_definitions.item_filter_text_input = UIWidget.create_definition(
		table.clone(TextInputPassTemplates.simple_input_box_field_text),
		"item_filter_text_input",
		{
			value_id = "item_filter_text",
			vertical_alignment = mod.vertical_alignment,
			--parent = parent,
			horizontal_alignment = "left",
			size = { 500, 30 },
			placeholder_text = mod:localize("placeholder_text"),
			--text = "Filter Text Here",
		}
	)

	view_definition.widget_definitions.item_filter_button =
		UIWidget.create_definition(table.clone(ButtonPassTemplates.terminal_button_small), "item_filter_button", {
			icon = "",
			text = "Filter",
			hotspot = {},
			pass_type = "text",
		})
	view_definition.widget_definitions.item_filter_clear_button =
		UIWidget.create_definition(table.clone(ButtonPassTemplates.terminal_button_small), "item_filter_clear_button", {
			icon = "",
			text = "clr",
			hotspot = {},
			pass_type = "text",
		})

	for i = 2, #button_labels, 1 do
		local name = button_names[i]
		view_definition.widget_definitions[name] =
			UIWidget.create_definition(table.clone(ButtonPassTemplates.terminal_button_small), name, {
				text = button_labels[i],
				hotspot = {},
			})

		view_definition.scenegraph_definition[name] = {
			parent = parent,
			horizontal_alignment = "left",
			vertical_alignment = mod.vertical_alignment,
			size = { button_size[1], 30 },
			offset = { (button_size[1] + 10) * (i - 1), 0 },
		}
	end

	local input_width = 440
	view_definition.scenegraph_definition.item_filter_text_input = {
		parent = parent,
		vertical_alignment = "bottom",
		horizontal_alignment = "left",
		size = { input_width, 30 },
		offset = { 0, -60 },
		--		position = { 0, 0, 9999 },
	}
	view_definition.scenegraph_definition.item_filter_clear_button = {

		parent = "item_filter_text_input",
		vertical_alignment = "bottom",
		horizontal_alignment = "left",
		size = { 30, 30 },
		offset = { input_width + 20, 0 },
		--position = { offset_x + 440 + 20, offset_y - 60, 10 },
	}

	view_definition.scenegraph_definition.item_filter_button = {
		display_name = Localize("loc_inventory_weapon_button_inspect"),
		parent = "item_filter_text_input",
		vertical_alignment = "bottom",
		horizontal_alignment = "left",
		size = { 90, 30 },
		offset = { input_width + 20 + 30 + 10, 0 },
		--position = { offset_x + 440 + 20, offset_y - 60, 10 },
	}
end

local function view_definition_add2(view_definition)
	if not view_definition then
		return
	end
	if view_definition.widget_definitions == nil then
		view_definition.widget_definitions = {}
		debug_print("widget_definitions nil")
	end
	if view_definition.scenegraph_definition == nil then
		view_definition.scenegraph_definition = {}
		debug_print("scenegraph_definition nil")
	end
	local button_size = ButtonPassTemplates.terminal_button_small.size
	view_definition.widget_definitions.close_button =
		UIWidget.create_definition(table.clone(ButtonPassTemplates.terminal_button_small), "close_button", {
			text = "Close",
			hotspot = {},
			--visible = false,
			--tooltip_text = "ToolTip goes here",
		})

	view_definition.scenegraph_definition.close_button = {
		parent = "item_grid_pivot",
		vertical_alignment = "bottom",
		horizontal_alignment = "left",
		size = { button_size[1], button_size[2] },
		offset = { 14, -24 },
		hotkey = "back",

		--position = { offset_x + (button_size[1] + 10), offset_y, 696 }, --nice Z index
	}
	view_definition.widget_definitions.select_button =
		UIWidget.create_definition(table.clone(ButtonPassTemplates.terminal_button_small), "select_button", {
			text = "Select",
			hotspot = {},
			--visible = false,
			--tooltip_text = "ToolTip goes here",
		})

	view_definition.scenegraph_definition.select_button = {
		parent = "item_grid_pivot",
		vertical_alignment = "bottom",
		horizontal_alignment = "right",
		size = { button_size[1], button_size[2] },
		offset = { -14, -24 },
		--position = { offset_x + (button_size[1] + 10), offset_y, 696 }, --nice Z index
	}
end
--mod:hook_require("scripts/ui/views/credits_vendor_view/credits_vendor_view_definitions", view_def_add)
mod:hook_require("scripts/ui/views/inventory_weapons_view/inventory_weapons_view_definitions", view_definition_add)
mod:hook_require("scripts/ui/views/credits_vendor_view/credits_vendor_view_definitions", view_definition_add)
mod:hook_require("scripts/ui/views/marks_vendor_view/marks_vendor_view_definitions", view_definition_add)
mod:hook_require(
	"scripts/ui/views/crafting_mechanicus_modify_view/crafting_mechanicus_modify_view_definitions",
	view_definition_add
)
mod:hook_require(
	"scripts/ui/views/credits_goods_vendor_view/credits_goods_vendor_view_definitions",
	view_definition_add2
)

mod.select_weapon_pattern = function(weapon_name)
	if weapon_name == nil or weapon_name == "" then
		mod.weapon_pattern_filter = nil
		mod._view._widgets_by_name.select_weapon_pattern_button.content.text = button_labels[4]

		return
	end
	debug_print("weapon_name", weapon_name)
	mod.weapon_pattern_filter = get_weapon_pattern_id(weapon_name)

	debug_print("mod.weapon_pattern_filter", mod.weapon_pattern_filter)
	if mod.weapon_pattern_filter then
		local display_name = "+ " .. Localize("loc_weapon_family_" .. mod.weapon_pattern_filter .. "_m1")
		debug_print("Localize", mod.weapon_pattern_filter, display_name)
		mod._view._widgets_by_name.select_weapon_pattern_button.content.text = display_name
	end
end

local function _set_buttons_visibility(self, visibility)
	local widgets_by_name = self._widgets_by_name

	for i = 1, #button_names, 1 do
		local button_name = button_names[i]
		local widget = widgets_by_name[button_name]
		widget.visible = visibility
	end
	--widgets_by_name.select_button.visible = true
end

local function cb_item_text_filter(self)
	update_item_filter_text(self)
	debug_print(mod.item_filter_text)
	filter_item_text(self)
end
local function is_writing(self)
	local content = self._widgets_by_name.item_filter_text_input.content
	local hotspot = content.hotspot
	--local is_focused = hotspot.use_is_focused and hotspot.is_focused or hotspot.is_selected
	local is_focused = hotspot._is_focused
	--debug_print("is_writing", content.is_writing, is_focused)

	return content.is_writing or is_focused
end
local function disable_writing(self, should_clear)
	if self._widgets_by_name.item_filter_text_input then
		if should_clear then
			self._widgets_by_name.item_filter_text_input.content.text = ""
			self._widgets_by_name.item_filter_text_input.content.input_text = ""
			mod.item_filter_text = ""
		end
		self._widgets_by_name.item_filter_text_input.content.is_writing = false
	end
end

local function _set_button_callbacks(self)
	local widgets_by_name = self._widgets_by_name
	widgets_by_name.item_filter_button.content.hotspot.pressed_callback = function()
		cb_item_text_filter(self)
		disable_writing(self)
	end

	widgets_by_name.item_filter_clear_button.content.hotspot.pressed_callback = function()
		disable_writing(self, true)
	end

	widgets_by_name.reset_button.content.hotspot.pressed_callback = function()
		reset_grid(self)
		disable_writing(self, true)
	end
	widgets_by_name.reset_button.content.hotspot.right_pressed_callback = function()
		dump_selected_item(self)
	end

	widgets_by_name.dumpstat_button.content.hotspot.pressed_callback = function()
		filter_dump_stat(self)
		disable_writing(self)
	end
	widgets_by_name.dumpstat_button.content.hotspot.right_pressed_callback = function()
		filter_dump_stat(self, true)
		disable_writing(self)
	end

	widgets_by_name.favorites_button.content.hotspot.pressed_callback = function()
		filter_favorites(self)
		disable_writing(self)
	end

	widgets_by_name.favorites_button.content.hotspot.right_pressed_callback = function()
		filter_favorites(self, true)
		disable_writing(self)
	end

	widgets_by_name.favorite_set_button.content.hotspot.pressed_callback = function()
		set_favorites(self, true)
		disable_writing(self)
	end

	widgets_by_name.favorite_clear_button.content.hotspot.pressed_callback = function()
		set_favorites(self, false)
		disable_writing(self)
	end

	widgets_by_name.select_weapon_pattern_button.content.hotspot.pressed_callback = function()
		select_weapon_pattern(self)
		disable_writing(self)
	end
	widgets_by_name.select_weapon_pattern_button.content.hotspot.right_pressed_callback = function()
		mod.select_weapon_pattern(nil)
		disable_writing(self)
	end
end
local function _update_buttons(self)
	debug_print("_update_buttons view.view_name", self.view_name, mod._view.view_name)
	self:_scenegraph_world_position(button_names[1], nil, nil, 999)
	local view_name = self.view_name
	local widgets_by_name = self._widgets_by_name
	--local vendor = goods_view
	if view_name == CreditsGoodsVendorView then
		_set_buttons_visibility(self, false)
	else
	end

	if widgets_by_name.equip_button then
		widgets_by_name.equip_button.offset = { 0, -20, 0 }
	elseif widgets_by_name.purchase_button then
		widgets_by_name.purchase_button.offset = { 0, -20, 0 }
	end

	local button_size = ButtonPassTemplates.terminal_button_small.size

	local grid_scenegraph_id = "item_grid_pivot"
	if view_name == "crafting_mechanicus_modify_view" then
		self:_set_scenegraph_position(grid_scenegraph_id, nil, -180)
		if self._parent._widgets_by_name.corner_bottom_left then
			self._parent._widgets_by_name.corner_bottom_left.visible = false
		end
	end

	local item_grid_pos = self:_scenegraph_world_position(grid_scenegraph_id)
	offset_x = item_grid_pos[1]

	--	local grid_size = self._ui_scenegraph[grid_scenegraph_id].size
	if self._item_grid then
		mod._item_grid = self._item_grid
		--		grid_size = self._item_grid._grid._area_size
	end

	local grid_size2 = _get_scenegraph_size(self, grid_scenegraph_id)

	--[[ 
	self:_set_scenegraph_position(
		"item_filter_text_input",
		offset_x,
		offset_y - 60,
		50,
		"left",
		mod.setting_vertical_alignment
	)
	--self:_set_scenegraph_size("item_filter_text_input", 440, 0)
	self:_set_scenegraph_position(
		"item_filter_button",
		offset_x + 440 + 20,
		offset_y - 60,
		50,
		"left",
		mod.setting_vertical_alignment
	) ]]

	for i = 1, 1, 1 do
		local button_name = button_names[i]
		local widget = widgets_by_name[button_name]
		local scenegraph_id = widget.scenegraph_id
		local x = offset_x + (button_size[1] + 10) * (i - 1)
		item_grid_pos = self:_scenegraph_world_position(scenegraph_id)
		--debug_print(scenegraph_id, item_grid_pos[1], item_grid_pos[2], item_grid_pos[3])
		self:_set_scenegraph_position(scenegraph_id, x, offset_y, 50, "left", mod.vertical_alignment)
	end

	local scenegraph_id = "item_filter_text_input"
	local item_filter_text_input = self._ui_scenegraph[scenegraph_id]
	if item_filter_text_input and mod.vertical_alignment == "top" then
		item_filter_text_input.offset = { 0, 920 }
		self:_scenegraph_world_position(scenegraph_id, nil, nil, 999)
	elseif item_filter_text_input and mod.vertical_alignment == "bottom" then
		item_filter_text_input.offset = { 0, -60 }
		self:_scenegraph_world_position(scenegraph_id, nil, nil, 999)
	end

	_set_button_callbacks(self)

	if string.find(view_name, "vendor") then
		widgets_by_name.favorite_set_button.visible = false
		widgets_by_name.favorite_clear_button.visible = false
		widgets_by_name.favorites_button.visible = false
		widgets_by_name.select_weapon_pattern_button.visible = false
	elseif string.find(view_name, "crafting") then
		widgets_by_name.favorite_set_button.visible = false
		widgets_by_name.favorite_clear_button.visible = false
		widgets_by_name.favorites_button.visible = true
	else
	end

	self._update_scenegraph = true
end

--[[ 
local function view_init(self)
	debug_print("HOOK view_init", self.view_name, self)
end

mod:hook_safe(CLASS.InventoryWeaponsView, "init", function(self)
	view_init(self)
end)
mod:hook_safe(CLASS.CreditsVendorView, "init", function(self)
	view_init(self)
end)
mod:hook_safe(CLASS.CraftingMechanicusModifyView, "init", function(self)
	view_init(self)
end)
mod:hook_safe(CLASS.MarksVendorView, "init", function(self)
	view_init(self)
end) ]]

---ItemGridViewBase._present_layout_by_slot_filter = function (self, slot_filter, item_type_filter, optional_display_name)
local function _present_layout_by_slot_filter(self, slot_filter, item_type_filter, optional_display_name)
	debug_print("._present_layout_by_slot_filter", slot_filter, item_type_filter, optional_display_name)
	_update_filter_counts(self)
end

mod:hook_safe(CLASS.InventoryWeaponsView, "_present_layout_by_slot_filter", _present_layout_by_slot_filter)
mod:hook_safe(CLASS.CraftingMechanicusModifyView, "_present_layout_by_slot_filter", _present_layout_by_slot_filter)
mod:hook_safe(CLASS.CreditsVendorView, "_present_layout_by_slot_filter", _present_layout_by_slot_filter)

local function view_on_enter(self)
	print("HOOK view_on_enter", self.view_name, self._parent.view_name)
	if not self._item_grid then
		debug_print("***** NO _item_grid *****")
	end
	mod._view = self
	mod._item_grid = self._item_grid

	_reset_properties(self)
	_update_buttons(self)
	local input_legend = self._input_legend_element or self._parent._input_legend_element
	if input_legend then
		for i = 2, #input_legend._entries, 1 do
			if input_legend._entries[i] then
				debug_print(i, input_legend._entries[i].input_action)
				local orig_callback_func = input_legend._entries[i].on_pressed_callback
				input_legend._entries[i].on_pressed_callback = function(self2)
					local is_text_writing = is_writing(self)
					if is_text_writing then
						return
					end
					disable_writing(self)
					if orig_callback_func then
						orig_callback_func(self2)
					end
				end
			end
		end
	end

	if self._item_grid._sort_button_input and self._item_grid._sort_button_input == "hotkey_item_sort" then
		self._item_grid._sort_button_input = "notification_option_a"
	end
end

mod:hook_safe(CLASS.InventoryWeaponsView, "on_enter", function(self)
	view_on_enter(self)
end)

mod:hook_safe(CLASS.CreditsVendorView, "on_enter", function(self)
	view_on_enter(self)
end)
mod:hook_safe(CLASS.CraftingMechanicusModifyView, "on_enter", function(self)
	view_on_enter(self)
end)

mod:hook_safe(CLASS.CraftingMechanicusModifyView, "_setup_menu_tabs", function(self, content)
	if self._tab_menu_element then
		self._tab_menu_element:set_input_actions(nil, nil)
	end
end)
mod:hook_safe(CLASS.CraftingMechanicusModifyView, "cb_switch_tab", function(self, tab_index)
	debug_print("HOOK CLASS.CraftingMechanicusModifyView.cb_switch_tab", tab_index)
end)
mod:hook_safe(CLASS.CreditsVendorView, "cb_switch_tab", function(self, tab_index)
	debug_print("HOOK CreditsVendorView.cb_switch_tab", tab_index)
end)

mod:hook_safe(CLASS.MarksVendorView, "on_enter", function(self)
	view_on_enter(self)
end)

local function view_on_exit(self)
	debug_print("HOOK view_on_exit", self.view_name)
	if self.view_name ~= CreditsGoodsVendorView then
		close_goods_view()
	end
	--debug_close()
	mod._item_grid = nil
	mod._view = nil
	--	self._filter_options.filter_function = nil
end

mod:hook_safe(CLASS.InventoryWeaponsView, "on_exit", function(self)
	view_on_exit(self)
end)

mod:hook_safe(CLASS.CreditsVendorView, "on_exit", function(self)
	view_on_exit(self)
end)
mod:hook_safe(CLASS.CraftingMechanicusModifyView, "on_exit", function(self)
	view_on_exit(self)
end)
mod:hook_safe(CLASS.MarksVendorView, "on_exit", function(self)
	view_on_exit(self)
end)

mod:hook_safe(CLASS.CreditsGoodsVendorView, "init", function(self, settings, context)
	debug_print("HOOK CLASS.CreditsGoodsVendorView.init", context.select_weapon_pattern)
	if not context.select_weapon_pattern then
		return
	end
	self._pass_input = false
	self.select_weapon_pattern = context.select_weapon_pattern
	if self.select_weapon_pattern then
		self._register_button_callbacks = function(self)
			debug_print("_register_button_callbacks")
			local widgets_by_name = self._widgets_by_name
			widgets_by_name.select_button.content.hotspot.pressed_callback = callback(self, "_cb_on_select_pressed")
			widgets_by_name.close_button.content.hotspot.pressed_callback = callback(self, "_cb_on_close_pressed")
			widgets_by_name.close_button.content.hotspot.right_pressed_callback =
				callback(self, "_cb_on_close_right_pressed")
		end

		self._cb_on_select_pressed = function(self)
			if self._previewed_offer and self._previewed_offer.sku then
				local weapon_name = self._previewed_offer.sku.description
				debug_print("_cb_on_select_pressed", weapon_name)
				self._releases_to_close = 1
				mod.select_weapon_pattern(weapon_name)
				close_goods_view()
			end
		end
		self._cb_on_close_pressed = function(self)
			self._releases_to_close = 1
			close_goods_view()
		end
		self._cb_on_close_right_pressed = function(self)
			debug_inspect("self", self)
		end
	else
		debug_inspect("self._widgets_by_name", self._widgets_by_name)
	end
end)

mod:hook_safe(CLASS.CreditsGoodsVendorView, "on_enter", function(self)
	debug_print("CreditsGoodsVendorView on_enter", self.select_weapon_pattern)
	if self.select_weapon_pattern then
		local widgets_by_name = self._widgets_by_name
		widgets_by_name.purchase_button.visible = false

		--widgets_by_name.purchase_button.content.original_text = "Select Weapon Family"
		widgets_by_name.title_text.content.text = mod:localize("select_pattern_title")
		widgets_by_name.description_text.content.text = mod:localize("select_pattern")
		widgets_by_name.price_text.visible = false
		widgets_by_name.price_icon.visible = false
		--widgets_by_name.grid_divider_bottom.visible = false

		local grid_scenegraph_id = "item_grid_pivot"
		local pos = self:_scenegraph_world_position(grid_scenegraph_id)
		local grid_size = self._ui_scenegraph[grid_scenegraph_id].size
		local button_size = self._ui_scenegraph["purchase_button"].size
		--debug_print(grid_scenegraph_id, pos[1], pos[2], pos[3])
		local x = (screen.size[1] - grid_size[1]) / 2
		local x2 = (screen.size[1] - button_size[1]) / 2
		self:_set_scenegraph_position(grid_scenegraph_id, x + 80, 40, 99, "left", "top")
		self._widgets_by_name.select_button.visible = true
		self._widgets_by_name.close_button.visible = true
		self._close_view_input_action = "back"
		--self:_set_scenegraph_position("purchase_button", x2 + 60, grid_size[2] - 80, 50, "left", "top")
	else
		self._widgets_by_name.select_button.visible = false
		self._widgets_by_name.close_button.visible = false
	end
end)

mod.on_setting_changed = function()
	mod.get_settings()

	hook_dump_color()
end

mod.on_unload = function()
	close_goods_view()
end
