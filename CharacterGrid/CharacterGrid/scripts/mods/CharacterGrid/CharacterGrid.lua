local mod = get_mod("CharacterGrid")
local character_count_max = mod:get("character_count") > 8

mod:hook_require("scripts/ui/views/main_menu_view/main_menu_view_definitions", function(view_defs)
	local scenegraph = view_defs.scenegraph_definition

	local character_list_background = scenegraph.character_list_background
	character_list_background.size = {
		600,
		character_count_max and 420 or 350,
	}

	character_list_background.position = {
		100,
		-190,
		1,
	}

	local character_grid_background = scenegraph.character_grid_background
	character_grid_background.size = {
		300,
		character_count_max and 420 or 350,
	}
	character_grid_background.offset = {
		5,
		0,
		0,
	}

	scenegraph.character_info.size = {
		300,
		350,
	}

	local create_button = scenegraph.create_button
	create_button.size = {
		350,
		50,
	}
	create_button.position = {
		0,
		400,
		2,
	}

	local slots_count = scenegraph.slots_count
	slots_count.size = {
		300,
		50,
	}
	slots_count.position = {
		0,
		340,
		2,
	}

	local widgets = view_defs.widget_definitions

	local character_list_background_style = widgets.character_list_background.style
	character_list_background_style.size = {
		600,
		550,
	}
	character_list_background_style.background.size = {
		600,
		character_count_max and 560 or 480,
	}

	local style_id_3 = character_list_background_style.style_id_3
	style_id_3.size = {
		0,
		0,
	}
	style_id_3.offset = {
		0,
		114,
		30,
	}
end)

local get_pass_by_key = function(passes, id_key, id)
	for i = 1, #passes do
		local pass = passes[i]
		if pass[id_key] == id then
			return pass
		end
	end
	return nil
end

mod:hook_require("scripts/ui/pass_templates/character_select_pass_templates", function(CharacterSelectPassTemplates)
	local character_create_size = {
		280, -- def 280
		character_count_max and 98 or 100, -- def 100
	}
	CharacterSelectPassTemplates.character_create_size = character_create_size

	local portrait_size = {
		90 * 0.75, -- def 90*0.75
		100 * 0.75, -- def 100*0.75
	}
	local badge_size = {
		20,
		50,
	}
	local icon_size = {
		0,
		0,
	}
	local character_info_margin = {
		-15, -- def 5 -- -25
		10,
	}
	local character_text_margin = {
		2, -- def 20 -- 3
		0,
	}

	local text_margin = portrait_size[1] + badge_size[1] + character_info_margin[1] + character_text_margin[1]
	local text_width = character_create_size[1] - text_margin

	local character_select = CharacterSelectPassTemplates.character_select

	local character_insignia = get_pass_by_key(character_select, "value_id", "character_insignia")
	if character_insignia then
		local character_insignia_style = character_insignia.style
		character_insignia_style.size = {
			0,
			0
		}
		character_insignia_style.offset = {
			character_info_margin[1],
			0,
			62,
		}
	end

	local character_portrait = get_pass_by_key(character_select, "value_id", "character_portrait")
	if character_portrait then
		local character_portrait_style = character_portrait.style
		character_portrait_style.size = portrait_size
		character_portrait_style.offset = {
			badge_size[1] + character_info_margin[1],
			0,
			1,
		}
	end

	local character_name = get_pass_by_key(character_select, "value_id", "character_name")
	if character_name then
		local character_name_style = character_name.style
		character_name_style.font_size = 20
		character_name_style.size = {
			text_width,
			10,
		}
		character_name_style.offset = {
			text_margin + 2, -- def text_margin
			-30,
			1,
		}
	end

	local character_title = get_pass_by_key(character_select, "value_id", "character_title")
	if character_title then
		local character_title_style = character_title.style
		character_title_style.font_size = 14
		character_title_style.size = {
			text_width + 20, -- def text_width
			54,
		}
		character_title_style.offset = {
			text_margin,
			-16,
			1,
		}
	end

	local character_archetype_title = get_pass_by_key(character_select, "value_id", "character_archetype_title")
	if character_archetype_title then
		local character_archetype_title_style = character_archetype_title.style
		character_archetype_title_style.font_size = 14
		character_archetype_title_style.size = {
			text_width,
			54,
		}
		character_archetype_title_style.offset = {
			text_margin,
			12,
			1,
		}
	end

	local archetype_icon = get_pass_by_key(character_select, "value_id", "archetype_icon")
	if archetype_icon then
		local archetype_icon_style = archetype_icon.style
		archetype_icon_style.size = icon_size
	end
end)
