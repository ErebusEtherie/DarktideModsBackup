local color_map = {
	default              = { 167, 190, 151 },
	muted                = { 100, 100, 100 },
	jokaero_orange       = { 235, 96, 26 },
	averland_sunset      = { 255, 186, 0 },
	gauss_blaster_green  = { 132, 255, 168 },
	evil_sunz_scarlet    = { 213, 41, 28 },
	fire_dragon_bright   = { 255, 110, 40 },
	flash_gitz_yellow    = { 255, 230, 40 },
	moot_green           = { 110, 255, 0 },
	baharroth_blue       = { 120, 210, 255 },
	lothern_blue         = { 70, 170, 255 },
	emperors_children    = { 255, 120, 200 },
	genestealer_purple   = { 180, 90, 255 },
	continued_chartreuse = { 204, 255, 0 }
}

local function add_color_to_text(rgb, text)
	text = tostring(text)
	if rgb and rgb[1] and rgb[2] and rgb[3] then
		return "{#color(" ..
			rgb[1] .. "," .. rgb[2] .. "," .. rgb[3] .. "," .. (rgb[4] or "255") .. ")}" .. text .. "{#reset()}"
	end
	return text
end

local function emphasise_text(text)
	return add_color_to_text(color_map.fire_dragon_bright, text)
end

local function mute_text(text)
	return add_color_to_text(color_map.muted, text)
end

local function display_mode_words(...)
	local parts = {}

	for i = 1, select("#", ...) do
		local v = select(i, ...)
		parts[i] = mute_text("[") .. tostring(v) .. mute_text("]")
	end

	return table.concat(parts, " ")
end

return {
	mod_description = {
		en = "Show class and/or talent names " ..
			emphasise_text("while in-game") .. ", with optional prefix and suffixes.",
	},
	mod_name = {
		en = add_color_to_text(color_map.averland_sunset, "  What Are You  "),
	},
	toggle_debug = {
		en = "Debug"
	},
	toggle_replace_name_in_markers = {
		en = "Show Class/Talent on Markers"
	},
	toggle_replace_name_in_markers_tooltip = {
		en = "This will replace the text floating above player's names in-game with the configured class/talent format"
	},

	select_preset = {
		en = "Presets"
	},
	select_preset_tooltip = {
		en = emphasise_text("Will overwrite most of the settings below!")
	},
	select_display_mode = {
		en = "Display Mode",
	},
	select_character_name_prefix = {
		en = "Character Name Prefix",
	},
	select_character_name_case = {
		en = "Character Name Case",
	},
	select_character_name_suffix = {
		en = "Character Name Suffix",
	},
	select_class_name_prefix = {
		en = "Class Prefix",
	},
	select_class_name_case = {
		en = "Class Case",
	},
	select_class_name_suffix = {
		en = "Class Suffix",
	},
	select_talent_name_color = {
		en = "Talent Color",
	},
	select_talent_name_prefix = {
		en = "Talent Prefix",
	},
	select_talent_name_case = {
		en = "Talent Case",
	},
	select_talent_name_suffix = {
		en = "Talent Suffix",
	},
	select_character_name_color = {
		en = "Character Name Color",
	},
	select_class_color_zealot = {
		en = "Zealot Color",
	},
	select_class_color_veteran = {
		en = "Veteran Color",
	},
	select_class_color_psyker = {
		en = "Psyker Color",
	},
	select_class_color_ogryn = {
		en = "Ogryn Color",
	},
	select_class_color_hive_scum = {
		en = "Hive Scum Color",
	},
	select_class_color_arbitrator = {
		en = "Arbitrator Color",
	},
	select_class_color_skitarii = {
		en = "Skitarii Color",
	},
	-- three parts
	option_character_class_talent = {
		en = display_mode_words("Character", "Class", "Talent")
	},
	option_character_talent_class = {
		en = display_mode_words("Character", "Talent", "Class")
	},
	option_class_character_talent = {
		en = display_mode_words("Class", "Character", "Talent")
	},
	option_class_talent_character = {
		en = display_mode_words("Class", "Talent", "Character")
	},
	option_talent_character_class = {
		en = display_mode_words("Talent", "Character", "Class")
	},
	option_talent_class_character = {
		en = display_mode_words("Talent", "Class", "Character")
	},
	-- two parts
	option_character_class = {
		en = display_mode_words("Character", "Class")
	},
	option_character_talent = {
		en = display_mode_words("Character", "Talent")
	},
	option_class_character = {
		en = display_mode_words("Class", "Character")
	},
	option_class_talent = {
		en = display_mode_words("Class", "Talent")
	},
	option_talent_character = {
		en = display_mode_words("Talent", "Character")
	},
	option_talent_class = {
		en = display_mode_words("Talent", "Class")
	},
	-- one part (character-alone excluded)
	option_class = {
		en = display_mode_words("Class")
	},
	option_talent = {
		en = display_mode_words("Talent")
	},

	option_preset_select = {
		en = mute_text("- Select -")
	},
	option_preset_1 = {
		en = 'Zealot' .. emphasise_text(' [') .. "Dash" .. emphasise_text(']')
	},
	option_preset_2 = {
		en = 'Zealot' .. emphasise_text(' (') .. "Dash" .. emphasise_text(')')
	},
	option_preset_3 = {
		en = 'Zealot' .. emphasise_text(' + ') .. "Dash"
	},
	option_preset_4 = {
		en = 'Zealot' .. emphasise_text(' - ') .. "Dash"
	},
	option_preset_5 = {
		en = 'ZEALOT' .. emphasise_text(' (') .. "CHARGE" .. emphasise_text(')')
	},
	option_preset_6 = {
		en = 'ZEALOT' .. emphasise_text(' x ') .. "DASH"
	},
	option_preset_7 = {
		en = 'zEaLoT' .. emphasise_text(' x') .. ' dAsH'
	},

	option_case_title_case = {
		en = 'Title Case'
	},
	option_case_upper_case = {
		en = 'UPPER CASE'
	},
	option_case_lower_case = {
		en = 'lower case'
	},
	option_case_patrick_case = {
		en = 'pAtRiCk cAsE'
	},
	zealot_loc = {
		en = 'Zealot'
	},
	veteran_loc = {
		en = 'Veteran'
	},
	psyker_loc = {
		en = 'Psyker'
	},
	ogryn_loc = {
		en = 'Ogryn'
	},
	hive_scum_loc = {
		en = 'Hive Scum'
	},
	arbitrator_loc = {
		en = 'Arbitrator'
	},
	skitarii_loc = {
		en = 'Skitarii'
	},
	option_prefix_suffix_nil = {
		en = mute_text("- None -")
	},
	option_square_parenthesis_open = {
		en = emphasise_text('[') .. mute_text("Class/Talent...")
	},
	option_square_parenthesis_open_space = {
		en = emphasise_text('[ ') .. mute_text("Class/Talent...")
	},
	option_parenthesis_open = {
		en = emphasise_text('(') .. mute_text("Class/Talent...")
	},
	option_parenthesis_open_space = {
		en = emphasise_text('( ') .. mute_text("Class/Talent...")
	},
	option_plus_prefix = {
		en = emphasise_text('+') .. mute_text("Class/Talent...")
	},
	option_plus_suffix = {
		en = mute_text("...Class/Talent") .. emphasise_text('+')
	},
	option_minus_prefix = {
		en = emphasise_text('-') .. mute_text("Class/Talent...")
	},
	option_minus_suffix = {
		en = mute_text("...Class/Talent") .. emphasise_text('-')
	},
	option_x_prefix = {
		en = emphasise_text('x') .. mute_text("Class/Talent...")
	},
	option_x_suffix = {
		en = mute_text("...Class/Talent") .. emphasise_text('x')
	},
	option_plus_space = {
		en = emphasise_text('+ ') .. mute_text("Class/Talent...")
	},
	option_minus = {
		en = emphasise_text('-') .. mute_text("Class/Talent...")
	},
	option_minus_space = {
		en = emphasise_text('- ') .. mute_text("Class/Talent...")
	},
	option_x_space = {
		en = emphasise_text('x ') .. mute_text("Class/Talent...")
	},
	option_square_parenthesis_close = {
		en = mute_text("...Class/Talent") .. emphasise_text(']')
	},
	option_space_square_parenthesis_close = {
		en = mute_text("...Class/Talent") .. emphasise_text(' ]')
	},
	option_parenthesis_close = {
		en = mute_text("...Class/Talent") .. emphasise_text(')')
	},
	option_space_parenthesis_close = {
		en = mute_text("...Class/Talent") .. emphasise_text(' )')
	},
	option_space_plus = {
		en = mute_text("...Class/Talent") .. emphasise_text(' +')
	},
	option_space_minus = {
		en = mute_text("...Class/Talent") .. emphasise_text(' -')
	},
	option_space_x = {
		en = mute_text("Class/Talent...") .. emphasise_text(' x')
	},
	option_color_default = {
		en = add_color_to_text(nil, "- Default -")
	},
	option_color_jokaero_orange = {
		en = add_color_to_text(color_map.jokaero_orange, "Jokaero Orange")
	},
	option_color_averland_sunset = {
		en = add_color_to_text(color_map.averland_sunset, "Averland Sunset")
	},
	option_color_gauss_blaster_green = {
		en = add_color_to_text(color_map.gauss_blaster_green, "Gauss Blaster Green")
	},
	option_color_evil_sunz_scarlet = {
		en = add_color_to_text(color_map.evil_sunz_scarlet, "Evil Sunz Scarlet")
	},
	option_color_fire_dragon_bright = {
		en = add_color_to_text(color_map.fire_dragon_bright, "Fire Dragon Bright")
	},
	option_color_flash_gitz_yellow = {
		en = add_color_to_text(color_map.flash_gitz_yellow, "Flash Gitz Yellow")
	},
	option_color_moot_green = {
		en = add_color_to_text(color_map.moot_green, "Moot Green")
	},
	option_color_baharroth_blue = {
		en = add_color_to_text(color_map.baharroth_blue, "Baharroth Blue")
	},
	option_color_lothern_blue = {
		en = add_color_to_text(color_map.lothern_blue, "Lothern Blue")
	},
	option_color_emperors_children = {
		en = add_color_to_text(color_map.emperors_children, "Emperors Children")
	},
	option_color_genestealer_purple = {
		en = add_color_to_text(color_map.genestealer_purple, "Genestealer Purple")
	},
	option_color_continued_chartreuse = {
		en = add_color_to_text(color_map.continued_chartreuse, "Continued Chartreuse")
	},

	talent_zealot_dash = {
		en = "Dash"
	},
	talent_zealot_chorus = {
		en = "Chorus"
	},
	talent_zealot_stealth = {
		en = "Stealth"
	},

	talent_veteran_outline = {
		en = "Outline"
	},
	talent_veteran_voc = {
		en = "VOC"
	},
	talent_veteran_stealth = {
		en = "Stealth"
	},

	talent_psyker_shield = {
		en = "Shield"
	},
	talent_psyker_vent_shout = {
		en = "Shriek"
	},
	talent_psyker_scrier = {
		en = "Scrier's Gaze"
	},

	talent_ogryn_taunt = {
		en = "Taunt"
	},
	talent_ogryn_charge = {
		en = "Charge"
	},
	talent_ogryn_barrage = {
		en = "Barrage"
	},

	talent_arbitrator_castigator = {
		en = "Castigator"
	},
	talent_arbitrator_bash = {
		en = "Bash"
	},
	talent_arbitrator_nuncio_aquila = {
		en = "Nuncio Aquila"
	},

	talent_hive_scum_rage = {
		en = "Rage"
	},
	talent_hive_scum_desperado = {
		en = "Desperado"
	},
	talent_hive_scum_stimm_field = {
		en = "Stimm Field"
	},

	talent_cryptic_chordclaw = {
		en = "Chordclaw"
	},
	talent_cryptic_discharge = {
		en = "Discharge"
	},
	talent_cryptic_precision_stance = {
		en = "Precision Stance"
	},

	group_general = {
		en = "General"
	},
	group_character = {
		en = "Character Name Configuration"
	},
	group_talent = {
		en = "Talent Configuration"
	},
	group_class = {
		en = "Class Configuration"
	},
	group_class_colors = {
		en = "Class Colors"
	},
}
