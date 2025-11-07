local MAX_FILTERS_PER_PATTERN = 2
local mod = get_mod("DumpStatFinder")

require("scripts/foundation/utilities/color")
local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")
local UISettings = require("scripts/settings/ui/ui_settings")
--local DumpStatFinderSettings = mod:io_dofile("DumpStatFinder/scripts/mods/DumpStatFinder/DumpStatFinderSettings")
--local weapon_groups = DumpStatFinderSettings.weapon_groups
--limited selection of colors picked, add your own named colors, Web/CSS named color http://davidbau.com/colors/
--BUT needs underscore separating word like dark_color, see all the named colors in https://github.com/Aussiemon/Darktide-Source-Code/blob/master/scripts/foundation/utilities/color.lua

local default_filters = {
	forcestaff_p1_1 = "loc_stats_display_vent_speed",
	forcestaff_p1_2 = "loc_stats_display_warp_resist_stat",
	forcestaff_p2_1 = "loc_stats_display_vent_speed",
	forcestaff_p2_2 = "loc_stats_display_warp_resist_stat",
	forcestaff_p3_1 = "loc_stats_display_vent_speed",
	forcestaff_p3_2 = "loc_stats_display_warp_resist_stat",
	forcestaff_p4_1 = "loc_stats_display_vent_speed",
	forcestaff_p4_2 = "loc_stats_display_warp_resist_stat",
	forcesword_2h_p1_1 = "loc_stats_display_warp_resist_stat",
	lasgun_p2_1 = "loc_stats_display_stability_stat", --helbore
	lasgun_p3_1 = "loc_stats_display_control_stat_ranged", --recon
	ogryn_gauntlet_p1_1 = "loc_glossary_term_melee_damage",
	ogryn_heavystubber_p1_1 = "loc_stats_display_control_stat_ranged",
	ogryn_heavystubber_p2_1 = "loc_stats_display_control_stat_ranged",
	ogryn_heavystubber_p2_2 = "loc_stats_display_range_stat",
	ogryn_rippergun_p1_1 = "loc_stats_display_ammo_stat", --<= 66 ammo and collat and stabil dumps in special rule
	ogryn_rippergun_p1_2 = "loc_stats_display_stability_stat",

	plasmagun_p1_1 = "loc_stats_display_charge_speed", --There's a special rule for plasma charge/heat shared dump stat
	powersword_p1_1 = "loc_stats_display_cleave_targets_stat",
	powersword_p1_2 = "loc_stats_display_cleave_damage_stat",
}
local function get_default_value(setting_id)
	local default_value = default_filters[setting_id]

	return default_value or ""
end
local function build_weapons_list(pattern, mark)
	local options_list = {}
	local weapon_template = WeaponTemplates[mark]
	--debug_inspect("weapon_template", weapon_template)
	options_list[1] = { text = "none", value = "" } -- gets localized to space fir display, but value is empty string ""
	local j = 2
	for key, stat in pairs(weapon_template.base_stats) do
		if
			stat.display_name ~= "loc_stats_display_mobility_stat"
			and stat.display_name ~= "loc_stats_display_defense_stat"
		then
			options_list[j] = { text = Localize(stat.display_name), value = stat.display_name }
			j = j + 1
		end
	end
	return options_list
end
local function pairsByKeys(t, f)
	local a = {}
	for n in pairs(t) do
		table.insert(a, n)
	end
	table.sort(a, f)
	local i = 0 -- iterator variable
	local iter = function() -- iterator function
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	return iter
end
local function compare_weap_name(a, b)
	local name_a = Localize(UISettings.weapon_patterns[a].display_name)
	local name_b = Localize(UISettings.weapon_patterns[b].display_name)
	--print(name_a, name_b)

	return name_a < name_b
end

local function build_all_weapons_lists()
	local all_weapons_lists = {}
	--[[ 	{
		setting_id = "autogun_p1",
		type = "dropdown",
		default_value = " ",
		options = build_weapons_list("autogun_p1"),
	}, ]]
	local i = 1
	local max_filters = mod:get("setting_max_filters") or MAX_FILTERS_PER_PATTERN
	for pattern, data in pairsByKeys(UISettings.weapon_patterns, compare_weap_name) do
		for j = 1, max_filters, 1 do
			local setting_id = pattern .. "_" .. j
			all_weapons_lists[i] = {
				setting_id = setting_id,
				title = Localize(data.display_name) .. " " .. j,
				type = "dropdown",
				default_value = get_default_value(setting_id),
				options = build_weapons_list(pattern, data.marks[1].name),
				-- sub_widgets = {
				-- 	{
				-- 		setting_id = setting_id .. "_max_value",
				-- 		type = "numeric",
				-- 		default_value = 62,
				-- 		range = { 60, 79 },
				-- 	},
				-- },
			}
			i = i + 1
		end
	end
	return all_weapons_lists
end

local function c(color_name)
	local color = Color[color_name](255, true)
	local color_string = string.format("{#color(%d,%d,%d)}%s{#reset()}", color[2], color[3], color[4], color_name)
	return color_string
end

local colors_dark_options = {}

local colors_light_options = {}
local colors_text_options = {}

local function build_color_list(options_list, color_names_list, color_names_list2)
	for i = 1, #color_names_list, 1 do
		options_list[i] = { text = c(color_names_list[i]), value = color_names_list[i] }
	end
	local num_colors = #options_list
	for i = 1, #color_names_list2, 1 do
		options_list[num_colors + i] = { text = c(color_names_list2[i]), value = color_names_list2[i] }
	end
end

local function build_color_options()
	local colors_text = {
		"hot_pink",
		"pale_golden_rod",
		"white",
		"white_smoke",
		"yellow",
		"pale_turquoise",
		"light_coral",
		"light_cyan",
		"light_pink",
		"light_sky_blue",
		"light_green",
		"peach_puff",
		"plum",
	}
	local colors_light = {
		"item_rarity_6",
		"crimson",
		"magenta",
		"red",
		"violet",
		"deep_pink",
		"cyan",
		"turquoise",
		"salmon",
		"orchid",
		"orange_red",
		"golden_rod",
	}
	local colors_dark = {
		"item_rarity_dark_6",
		"firebrick",
		"dark_magenta",
		"dark_red",
		"dark_violet",
		"dark_cyan",
		"dark_turquoise",
		"dark_salmon",
		"dark_orchid",
		"dark_orange",
		"gold",
	}
	build_color_list(colors_light_options, colors_light, colors_dark)
	build_color_list(colors_dark_options, colors_dark, colors_light)
	build_color_list(colors_text_options, colors_text, colors_light)
	--[[ 
	for i = 1, #colors_light, 1 do
		colors_light_options[i] = { text = c(colors_light[i]), value = colors_light[i] }
	end
	local num_colors = #colors_light
	for i = 1, #colors_dark, 1 do
		colors_light_options[num_colors + i] = { text = c(colors_dark[i]), value = colors_dark[i] }
	end

	for i = 1, #colors_dark, 1 do
		colors_dark_options[i] = { text = c(colors_dark[i]), value = colors_dark[i] }
	end
	num_colors = #colors_dark
	for i = 1, #colors_light, 1 do
		colors_dark_options[num_colors + i] = { text = c(colors_light[i]), value = colors_light[i] }
	end

	for i = 1, #colors_text, 1 do
		colors_text_options[i] = { text = c(colors_text[i]), value = colors_text[i] }
	end
	num_colors = #colors_text
	for i = 1, #colors_light, 1 do
		colors_text_options[num_colors + i] = { text = c(colors_light[i]), value = colors_light[i] }
	end ]]
end

build_color_options()
return {
	name = "DumpStatFinder",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "setting_max_filters",
				require_restart = true,
				type = "numeric",
				tooltip = "reload_tt",
				default_value = 2,
				range = { 2, 5 },
			},
			{
				setting_id = "setting_max_dump_stat_value",
				type = "numeric",
				default_value = 62,
				range = { 60, 79 },
			},

			--[[ 			{
				setting_id = "setting_inventory_use_panel",
				type = "checkbox",
				default_value = true,
			},
 			]]
			--[[ 
			{
				setting_id = "setting_tabbed_filters_in_vendor",
				type = "checkbox",
				default_value = true,
			}, ]]
			{
				setting_id = "setting_sainted_quality",
				type = "checkbox",
				tooltip = "reload_tt",
				require_restart = true,
				default_value = false,
				sub_widgets = {
					{
						setting_id = "setting_sainted_only_max",
						type = "checkbox",
						default_value = false,
					},
				},
			},

			{
				setting_id = "setting_recolor_dump",
				type = "checkbox",
				default_value = true,
				sub_widgets = {
					{
						setting_id = "setting_recolor_only_max",
						type = "checkbox",
						default_value = false,
					},

					{

						setting_id = "setting_dump_color",
						type = "dropdown",
						default_value = "crimson",
						options = colors_light_options,
					},
					{

						setting_id = "setting_dump_color_dark",
						type = "dropdown",
						default_value = "firebrick",
						options = colors_dark_options,
					},
				},
			},
			{
				setting_id = "setting_recolor_dump_text",
				type = "checkbox",
				default_value = true,
				sub_widgets = {
					{

						setting_id = "setting_dump_color_text",
						type = "dropdown",
						default_value = "golden_rod",
						options = colors_text_options,
					},
				},
			},

			{
				setting_id = "setting_vertical_alignment",
				type = "dropdown",
				default_value = "bottom",
				options = {
					{ text = "setting_vertical_alignment_bottom", value = "bottom" },
					{ text = "setting_vertical_alignment_top", value = "top" },
				},
			},
			{
				setting_id = "setting_special_filters",
				type = "checkbox",
				tooltip = "setting_special_filters_tt",
				default_value = true,
			},
			{
				setting_id = "weapon_filters_group",
				tooltip = "weapon_filters_group_tt",
				type = "group",
				default_value = true,
				sub_widgets = build_all_weapons_lists(),
			},

			{
				setting_id = "setting_debug",
				type = "checkbox",
				default_value = false,
			},
		},
	},
}
