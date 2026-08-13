local mod = get_mod("what_are_you")

mod.get_module = function(self, name)
	return self:io_dofile("what_are_you/scripts/mods/what_are_you/modules/" .. name)
end

local use_color = mod:get_module("use_color")()
local use_string = mod:get_module("use_string")()
---@cast use_color use_color_r
---@cast use_string use_string_r

local case_options = function()
	local options = {}
	for _, entry in pairs(use_string.get_case_map()) do
		options[#options + 1] = { text = entry.option_loc_id, value = entry.option_value, nominal = entry.nominal }
	end
	table.sort(options, function(a, b) return a.nominal < b.nominal end)
	return options
end

local prefix_options = function()
	local options = {}
	for _, entry in pairs(use_string.get_prefix_map()) do
		options[#options + 1] = { text = entry.option_loc_id, value = entry.option_value, nominal = entry.nominal }
	end
	table.sort(options, function(a, b) return a.nominal < b.nominal end)
	return options
end

local suffix_options = function()
	local options = {}
	for _, entry in pairs(use_string.get_suffix_map()) do
		options[#options + 1] = { text = entry.option_loc_id, value = entry.option_value, nominal = entry.nominal }
	end
	table.sort(options, function(a, b) return a.nominal < b.nominal end)
	return options
end

local color_options = function()
	local options = {}
	for _, entry in pairs(use_color.get_color_map()) do
		options[#options + 1] = { text = entry.option_loc_id, value = entry.option_value, nominal = entry.nominal }
	end
	table.sort(options, function(a, b) return a.nominal < b.nominal end)
	return options
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "group_general",
				type = "group",
				sub_widgets = {
					{
						setting_id    = "select_display_mode",
						type          = "dropdown",
						default_value = "class_talent",
						options       = {
							-- three parts: character, class, talent (all 6 permutations)
							{ text = "option_character_class_talent", value = 'character_class_talent' },
							{ text = "option_character_talent_class", value = 'character_talent_class' },
							{ text = "option_class_character_talent", value = 'class_character_talent' },
							{ text = "option_class_talent_character", value = 'class_talent_character' },
							{ text = "option_talent_character_class", value = 'talent_character_class' },
							{ text = "option_talent_class_character", value = 'talent_class_character' },
							-- two parts (6 combinations; no character-alone)
							{ text = "option_character_class",        value = 'character_class' },
							{ text = "option_character_talent",       value = 'character_talent' },
							{ text = "option_class_character",        value = 'class_character' },
							{ text = "option_class_talent",           value = 'class_talent' },
							{ text = "option_talent_character",       value = 'talent_character' },
							{ text = "option_talent_class",           value = 'talent_class' },
							-- one part (class or talent only; character-alone excluded)
							{ text = "option_class",                  value = 'class' },
							{ text = "option_talent",                 value = 'talent' },
						},
					},
					{
						setting_id    = "toggle_replace_name_in_markers",
						type          = "checkbox",
						tooltip       = "toggle_replace_name_in_markers_tooltip",
						default_value = true,
					},
					{
						setting_id    = "select_preset",
						type          = "dropdown",
						tooltip       = "select_preset_tooltip",
						default_value = "select",
						options       = {
							{ text = "option_preset_select", value = "select" },
							{ text = "option_preset_1",      value = 1 },
							{ text = "option_preset_2",      value = 2 },
							{ text = "option_preset_3",      value = 3 },
							{ text = "option_preset_4",      value = 4 },
							{ text = "option_preset_5",      value = 5 },
							{ text = "option_preset_6",      value = 6 },
						},
					},
				}
			},
			{
				setting_id = "group_character",
				type = "group",
				sub_widgets = {
					{
						setting_id    = "select_character_name_color",
						type          = "dropdown",
						default_value = "default",
						options       = color_options(),
					},
					{
						setting_id    = "select_character_name_prefix",
						type          = "dropdown",
						default_value = "",
						options       = prefix_options(),
					},
					{
						setting_id    = "select_character_name_case",
						type          = "dropdown",
						default_value = "title",
						options       = case_options(),
					},
					{
						setting_id    = "select_character_name_suffix",
						type          = "dropdown",
						default_value = "",
						options       = suffix_options(),
					},
				}
			},
			{
				setting_id = "group_class",
				type = "group",
				sub_widgets = {
					{
						setting_id    = "select_class_name_prefix",
						type          = "dropdown",
						default_value = "",
						options       = prefix_options(),
					},
					{
						setting_id    = "select_class_name_case",
						type          = "dropdown",
						default_value = "title",
						options       = case_options(),
					},
					{
						setting_id    = "select_class_name_suffix",
						type          = "dropdown",
						default_value = "",
						options       = suffix_options(),
					},
				}
			},
			{
				setting_id = "group_talent",
				type = "group",
				sub_widgets = {
					{
						setting_id    = "select_talent_name_prefix",
						type          = "dropdown",
						default_value = "(",
						options       = prefix_options(),
					},
					{
						setting_id    = "select_talent_name_case",
						type          = "dropdown",
						default_value = "title",
						options       = case_options(),
					},
					{
						setting_id    = "select_talent_name_suffix",
						type          = "dropdown",
						default_value = ")",
						options       = suffix_options(),
					},
				}
			},
			{
				setting_id = "group_class_colors",
				type = "group",
				sub_widgets = {
					{
						setting_id    = "select_class_color_zealot",
						type          = "dropdown",
						default_value = "default",
						options       = color_options(),
					},
					{
						setting_id    = "select_class_color_veteran",
						type          = "dropdown",
						default_value = "default",
						options       = color_options(),
					},
					{
						setting_id    = "select_class_color_psyker",
						type          = "dropdown",
						default_value = "default",
						options       = color_options(),
					},
					{
						setting_id    = "select_class_color_ogryn",
						type          = "dropdown",
						default_value = "default",
						options       = color_options(),
					},
					{
						setting_id    = "select_class_color_hive_scum",
						type          = "dropdown",
						default_value = "default",
						options       = color_options(),
					},
					{
						setting_id    = "select_class_color_arbitrator",
						type          = "dropdown",
						default_value = "default",
						options       = color_options(),
					},
					{
						setting_id    = "select_class_color_skitarii",
						type          = "dropdown",
						default_value = "default",
						options       = color_options(),
					},
				}
			},
			{
				setting_id    = "toggle_debug",
				type          = "checkbox",
				default_value = false,
			},
		}
	}
}
