local mod = get_mod("LessAnnoyingArbites")
local dmf = get_mod("DMF")

local vfx_options = {
	{ text = "setting_impact_unchanged", value = "" },
	{ text = "setting_impact_shock_stuck", value = "content/fx/particles/weapons/shock_maul/shock_stuck" },
	{ text = "setting_impact_lasgun", value = "content/fx/particles/impacts/weapons/lasgun/lasgun_impact_player" },
	{ text = "setting_impact_lasgun_big", value = "content/fx/particles/impacts/weapons/lasgun/lasgun_impact_big" },
	{ text = "setting_impact_dust", value = "content/fx/particles/impacts/generic_dust_unarmored" },
	{ text = "setting_impact_metal", value = "content/fx/particles/impacts/surfaces/impact_metal" },
	{ text = "setting_impact_ice", value = "content/fx/particles/impacts/surfaces/impact_ice_01" },
	{
		text = "setting_impact_shield",
		value = "content/fx/particles/impacts/enemies/renegade_captain/renegade_captain_shield_impact",
	},
}
mod.localize = function(self, text_id)
	if string.find(text_id, "loc_") == 1 then
		local str = Localize(tostring(text_id))
		--print("localize", text_id, str)
		return str
	end
	local l_text = dmf.localize(self, text_id):gsub("^<", ""):gsub(">$", "")

	return l_text
end

local function color_to_mat(source_color)
	return { source_color[2] / 255, source_color[3] / 255, source_color[4] / 255 }
end

local function rgb_to_mat(r, g, b)
	return { r / 255, g / 255, b / 255 }
end

local function c(color_name)
	local color = Color[color_name](255, true)
	local color_string = string.format("{#color(%d,%d,%d)}%s{#reset()}", color[2], color[3], color[4], color_name)
	return color_string
end

local colors_options = {}

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
	local colors_light = {
		"crimson",
		"magenta",
		"red",
		"violet",
		"deep_pink",
		"light_green",
		"lime_green",
		"green",
		"dark_green",
		"cyan",
		"turquoise",
		"salmon",
		"orchid",
		"orange_red",
		"golden_rod",
		"gold",

		"blue",
		"dodger_blue",
	}
	local colors_dark = {
		"firebrick",
		"dark_magenta",
		"dark_red",
		"dark_violet",
		"dark_cyan",
		"dark_turquoise",
		"dark_salmon",
		"dark_orchid",
		"dark_orange",
		"dark_golden_rod",
		"dark_blue",
		"dark_slate_blue",
		"royal_blue",
	}
	build_color_list(colors_options, colors_light, colors_dark)
end
build_color_options()
return {
	name = "LessAnnoyingArbites",
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "setting_group_mines",
				type = "group",
				sub_widgets = {

					{
						setting_id = "setting_replace_mine_vfx",
						type = "checkbox",
						default_value = true,
						require_restart = true,
					},
					{
						setting_id = "setting_enable_mine_vfx",
						type = "checkbox",
						default_value = false,
						require_restart = true,
					},
				},
			},
			{
				setting_id = "setting_group_nuncio",
				type = "group",
				sub_widgets = {
					{
						setting_id = "setting_nuncio_visible",
						type = "checkbox",
						default_value = true,
						--require_restart = true,
					},
					{
						setting_id = "setting_nuncio_enable_scan_vfx",
						type = "checkbox",
						default_value = true,
						require_restart = true,
					},

					{
						setting_id = "setting_nuncio_override",
						type = "checkbox",
						default_value = true,
						require_restart = true,
					},

					{
						setting_id = "setting_nuncio_offset",
						type = "numeric",
						decimals_number = 1,
						default_value = 2.1,
						range = { -1, 3 },
					},
				},
			},
			{
				setting_id = "setting_group_dog",
				type = "group",
				sub_widgets = {
					{
						setting_id = "setting_enable_tag_double_tap",
						type = "checkbox",
						default_value = true,
						--require_restart = true,
					},
					{
						setting_id = "setting_tag_double_tap_delay",
						type = "numeric",
						decimals_number = 2,
						default_value = 0.3,
						range = { 0.1, 0.5 },
					},

					{
						setting_id = "setting_enable_attack",
						type = "checkbox",
						default_value = true,
						require_restart = true,
					},
					{
						setting_id = "setting_func_attack",
						type = "keybind",
						default_value = { --[[...]]
						},
						keybind_global = true, -- optional
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "dog_attack",
					},
					{
						setting_id = "setting_func_attack_single_press",
						type = "keybind",
						default_value = { --[[...]]
						},
						keybind_global = true, -- optional
						keybind_trigger = "pressed",
						keybind_type = "function_call",
						function_name = "dog_attack_single_press",
					},
				},
			},
			{
				setting_id = "setting_group_outlines",
				type = "group",
				sub_widgets = {

					{
						setting_id = "setting_enable_outline_colors",
						type = "checkbox",
						default_value = true,
						--require_restart = true,
					},
					{
						setting_id = "setting_dog_target_outline_color",
						type = "dropdown",
						default_value = "crimson",
						options = table.clone(colors_options),
					},
					{
						setting_id = "setting_adamant_mark_outline_color",
						type = "dropdown",
						default_value = "deep_pink",
						options = table.clone(colors_options),
					},
					{
						setting_id = "setting_dog_outline_color",
						type = "dropdown",
						default_value = "dodger_blue",
						options = table.clone(colors_options),
						--require_restart = true,
					},
					{
						setting_id = "setting_dog_other_outline_color",
						type = "dropdown",
						default_value = "dark_blue",
						options = table.clone(colors_options),
						--require_restart = true,
					},
					{
						setting_id = "setting_enable_dog_outline",
						type = "checkbox",
						default_value = true,
						--require_restart = true,
					},
					{
						setting_id = "setting_enable_dog_others_outline",
						type = "checkbox",
						default_value = true,
						--require_restart = true,
					},
					{
						setting_id = "setting_horde_remaining_outline_color",
						type = "dropdown",
						default_value = "dark_salmon",
						options = table.clone(colors_options),
						--require_restart = true,
					},
				},
			},
			{
				setting_id = "setting_group_impact",
				type = "group",
				sub_widgets = {
					{
						setting_id = "setting_enable_impact_vfx",
						type = "checkbox",
						default_value = true,
						require_restart = true,
					},

					{
						setting_id = "setting_impact_maul_special",
						type = "dropdown",
						default_value = "content/fx/particles/impacts/enemies/renegade_captain/renegade_captain_shield_impact",
						options = table.clone(vfx_options),
					},
					{
						setting_id = "setting_impact_shield_special",
						type = "dropdown",
						default_value = "content/fx/particles/impacts/enemies/renegade_captain/renegade_captain_shield_impact",
						options = table.clone(vfx_options),
					},
					{
						setting_id = "setting_impact_shock",
						type = "dropdown",
						default_value = "content/fx/particles/weapons/shock_maul/shock_stuck",
						options = table.clone(vfx_options),
					},
					{
						setting_id = "setting_enable_screenspace_vfx",
						type = "checkbox",
						default_value = true,
						require_restart = false,
					},
				},
			},
			{
				setting_id = "setting_enable_debug_mode",
				type = "checkbox",
				default_value = false,
			},
		},
	},
}
