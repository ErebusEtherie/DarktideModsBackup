
local math_clamp = math.clamp
local floor = math.floor
local max = math.max
local min = math.min

local function round_byte(v)
	v = floor(v * 255 + 0.5)
	if v < 0 then
		return 0
	elseif v > 255 then
		return 255
	end
	return v
end

local function clamp01(v)
	if v < 0 then
		return 0
	elseif v > 1 then
		return 1
	end
	return v
end

---@param mod mod
return function(mod)
	---@class DL_Colors
	local Colors = {}

	Colors.reg = {

		web = {
			maroon = { 255, 128, 0, 0 },
			dark_red = { 255, 139, 0, 0 },
			brown = { 255, 127, 51, 0 },
			firebrick = { 255, 178, 34, 34 },
			crimson = { 255, 220, 20, 60 },
			red = { 255, 255, 0, 0 },
			tomato = { 255, 255, 99, 71 },
			coral = { 255, 255, 127, 80 },
			indian_red = { 255, 205, 92, 92 },
			light_coral = { 255, 240, 128, 128 },
			dark_salmon = { 255, 233, 150, 122 },
			salmon = { 255, 250, 128, 114 },
			light_salmon = { 255, 255, 160, 122 },
			cheeseburger = { 255, 255, 168, 0 },
			orange_red = { 255, 255, 69, 0 },
			dark_orange = { 255, 255, 140, 0 },
			orange = { 255, 255, 165, 0 },
			gold = { 255, 255, 215, 0 },
			dark_golden_rod = { 255, 184, 134, 11 },
			golden_rod = { 255, 218, 165, 32 },
			pale_golden_rod = { 255, 238, 232, 170 },
			dark_khaki = { 255, 189, 183, 107 },
			khaki = { 255, 240, 230, 140 },
			olive = { 255, 128, 128, 0 },
			yellow = { 255, 255, 255, 0 },
			yellow_green = { 255, 154, 205, 50 },
			online_green = { 255, 145, 226, 42 },
			dark_olive_green = { 255, 85, 107, 47 },
			olive_drab = { 255, 107, 142, 35 },
			lawn_green = { 255, 124, 252, 0 },
			chart_reuse = { 255, 127, 255, 0 },
			green_yellow = { 255, 173, 255, 47 },
			dark_green = { 255, 0, 100, 0 },
			green = { 255, 0, 128, 0 },
			forest_green = { 255, 34, 139, 34 },
			lime = { 255, 0, 255, 0 },
			lime_green = { 255, 50, 205, 50 },
			light_green = { 255, 144, 238, 144 },
			pale_green = { 255, 152, 251, 152 },
			dark_sea_green = { 255, 143, 188, 143 },
			medium_spring_green = { 255, 0, 250, 154 },
			spring_green = { 255, 0, 255, 127 },
			sea_green = { 255, 46, 139, 87 },
			medium_aqua_marine = { 255, 102, 205, 170 },
			medium_sea_green = { 255, 60, 179, 113 },
			light_sea_green = { 255, 32, 178, 170 },
			dark_slate_gray = { 255, 47, 79, 79 },
			teal = { 255, 0, 128, 128 },
			dark_cyan = { 255, 0, 139, 139 },
			aqua = { 255, 0, 255, 255 },
			cyan = { 255, 0, 255, 255 },
			light_cyan = { 255, 224, 255, 255 },
			dark_turquoise = { 255, 0, 206, 209 },
			turquoise = { 255, 64, 224, 208 },
			medium_turquoise = { 255, 72, 209, 204 },
			pale_turquoise = { 255, 175, 238, 238 },
			aqua_marine = { 255, 127, 255, 212 },
			powder_blue = { 255, 176, 224, 230 },
			cadet_blue = { 255, 95, 158, 160 },
			steel_blue = { 255, 70, 130, 180 },
			corn_flower_blue = { 255, 100, 149, 237 },
			deep_sky_blue = { 255, 0, 191, 255 },
			dodger_blue = { 255, 30, 144, 255 },
			light_blue = { 255, 173, 216, 230 },
			sky_blue = { 255, 135, 206, 235 },
			light_sky_blue = { 255, 135, 206, 250 },
			midnight_blue = { 255, 25, 25, 112 },
			navy = { 255, 0, 0, 128 },
			dark_blue = { 255, 0, 0, 139 },
			medium_blue = { 255, 0, 0, 205 },
			blue = { 255, 0, 0, 255 },
			royal_blue = { 255, 65, 105, 225 },
			blue_violet = { 255, 138, 43, 226 },
			indigo = { 255, 75, 0, 130 },
			dark_slate_blue = { 255, 72, 61, 139 },
			slate_blue = { 255, 106, 90, 205 },
			medium_slate_blue = { 255, 123, 104, 238 },
			medium_purple = { 255, 147, 112, 219 },
			dark_magenta = { 255, 139, 0, 139 },
			dark_violet = { 255, 148, 0, 211 },
			dark_orchid = { 255, 153, 50, 204 },
			medium_orchid = { 255, 186, 85, 211 },
			purple = { 255, 128, 0, 128 },
			thistle = { 255, 216, 191, 216 },
			plum = { 255, 221, 160, 221 },
			violet = { 255, 238, 130, 238 },
			magenta = { 255, 255, 0, 255 },
			orchid = { 255, 218, 112, 214 },
			medium_violet_red = { 255, 199, 21, 133 },
			pale_violet_red = { 255, 219, 112, 147 },
			deep_pink = { 255, 255, 20, 147 },
			hot_pink = { 255, 255, 105, 180 },
			light_pink = { 255, 255, 182, 193 },
			pink = { 255, 255, 192, 203 },
			antique_white = { 255, 250, 235, 215 },
			beige = { 255, 245, 245, 220 },
			bisque = { 255, 255, 228, 196 },
			blanched_almond = { 255, 255, 235, 205 },
			wheat = { 255, 245, 222, 179 },
			corn_silk = { 255, 255, 248, 220 },
			lemon_chiffon = { 255, 255, 250, 205 },
			light_golden_rod_yellow = { 255, 250, 250, 210 },
			light_yellow = { 255, 255, 255, 224 },
			saddle_brown = { 255, 139, 69, 19 },
			sienna = { 255, 160, 82, 45 },
			chocolate = { 255, 210, 105, 30 },
			peru = { 255, 205, 133, 63 },
			sandy_brown = { 255, 244, 164, 96 },
			burly_wood = { 255, 222, 184, 135 },
			tan = { 255, 210, 180, 140 },
			rosy_brown = { 255, 188, 143, 143 },
			moccasin = { 255, 255, 228, 181 },
			navajo_white = { 255, 255, 222, 173 },
			peach_puff = { 255, 255, 218, 185 },
			misty_rose = { 255, 255, 228, 225 },
			lavender_blush = { 255, 255, 240, 245 },
			linen = { 255, 250, 240, 230 },
			old_lace = { 255, 253, 245, 230 },
			papaya_whip = { 255, 255, 239, 213 },
			sea_shell = { 255, 255, 245, 238 },
			mint_cream = { 255, 245, 255, 250 },
			slate_gray = { 255, 112, 128, 144 },
			light_slate_gray = { 255, 119, 136, 153 },
			light_steel_blue = { 255, 176, 196, 222 },
			lavender = { 255, 230, 230, 250 },
			floral_white = { 255, 255, 250, 240 },
			alice_blue = { 255, 240, 248, 255 },
			ghost_white = { 255, 248, 248, 255 },
			honeydew = { 255, 240, 255, 240 },
			ivory = { 255, 255, 255, 240 },
			azure = { 255, 240, 255, 255 },
			snow = { 255, 255, 250, 250 },
			black = { 255, 0, 0, 0 },
			dim_gray = { 255, 105, 105, 105 },
			gray = { 255, 128, 128, 128 },
			dark_gray = { 255, 169, 169, 169 },
			silver = { 255, 192, 192, 192 },
			light_gray = { 255, 211, 211, 211 },
			gainsboro = { 255, 220, 220, 220 },
			white_smoke = { 255, 245, 245, 245 },
			white = { 255, 255, 255, 255 },
		},

		gw = {
			abaddon_black = { 255, 35, 31, 32 },
			averland_sunset = { 255, 253, 184, 37 },
			balthasar_gold = { 255, 164, 117, 82 },
			bugmans_glow = { 255, 131, 79, 68 },
			caledor_sky = { 255, 57, 110, 158 },
			caliban_green = { 255, 0, 64, 31 },
			castellan_green = { 255, 49, 72, 33 },
			celestra_grey = { 255, 144, 168, 168 },
			ceramite_white = { 255, 255, 255, 255 },
			daemonette_hide = { 255, 105, 102, 132 },
			death_guard_green = { 255, 132, 138, 102 },
			deathworld_forest = { 255, 92, 103, 48 },
			dryad_bark = { 255, 51, 49, 45 },
			incubi_darkness = { 255, 11, 71, 74 },
			jokaero_orange = { 255, 238, 56, 35 },
			kantor_blue = { 255, 0, 33, 81 },
			khorne_red = { 255, 106, 0, 1 },
			leadbelcher = { 255, 136, 141, 143 },
			macragge_blue = { 255, 13, 64, 127 },
			mechanicus_standard_grey = { 255, 61, 75, 77 },
			mephiston_red = { 255, 154, 17, 21 },
			mournfang_brown = { 255, 100, 9, 9 },
			naggaroth_night = { 255, 61, 51, 84 },
			rakarth_flesh = { 255, 162, 158, 145 },
			ratskin_flesh = { 255, 173, 107, 76 },
			retributor_armour = { 255, 195, 158, 129 },
			rhinox_hide = { 255, 73, 52, 53 },
			screamer_pink = { 255, 124, 22, 69 },
			screaming_bell = { 255, 193, 111, 69 },
			steel_legion_drab = { 255, 94, 81, 52 },
			stegadon_scale_green = { 255, 7, 72, 99 },
			the_fang_grey = { 255, 67, 97, 116 },
			thousand_sons_blue = { 255, 24, 171, 204 },
			waaagh_flesh = { 255, 31, 84, 41 },
			warplock_bronze = { 255, 146, 125, 123 },
			xv88 = { 255, 114, 73, 30 },
			zandri_dust = { 255, 158, 145, 92 },
			administratum_grey = { 255, 148, 155, 149 },
			ahriman_blue = { 255, 31, 140, 156 },
			alaitoc_blue = { 255, 41, 87, 136 },
			altdorf_guard_blue = { 255, 31, 86, 167 },
			auric_armour_gold = { 255, 232, 188, 109 },
			balor_brown = { 255, 139, 89, 16 },
			baneblade_brown = { 255, 147, 127, 109 },
			bestigor_flesh = { 255, 211, 138, 87 },
			brass_scorpion = { 255, 183, 136, 95 },
			cadian_fleshtone = { 255, 199, 121, 88 },
			calgar_blue = { 255, 66, 114, 184 },
			dark_reaper = { 255, 59, 81, 80 },
			dawnstone = { 255, 112, 117, 110 },
			deathclaw_brown = { 255, 179, 104, 83 },
			doombull_brown = { 255, 93, 0, 9 },
			elysian_green = { 255, 116, 143, 57 },
			emperors_children = { 255, 185, 66, 120 },
			eshin_grey = { 255, 74, 79, 82 },
			evil_sunz_scarlet = { 255, 194, 25, 31 },
			fenrisian_grey = { 255, 113, 155, 183 },
			fire_dragon_bright = { 255, 245, 134, 82 },
			flash_gitz_yellow = { 255, 255, 242, 0 },
			flayed_one_flesh = { 255, 240, 217, 184 },
			fulgurite_copper = { 255, 252, 252, 222 },
			gehennas_gold = { 255, 219, 166, 116 },
			genestealer_purple = { 255, 119, 97, 171 },
			gorthor_brown = { 255, 101, 71, 65 },
			hashut_copper = { 255, 183, 118, 71 },
			hoeth_blue = { 255, 76, 127, 180 },
			ironbreaker = { 255, 161, 166, 169 },
			kabalite_green = { 255, 3, 140, 103 },
			karak_stone = { 255, 187, 150, 98 },
			kislev_flesh = { 255, 214, 168, 117 },
			liberator_gold = { 255, 211, 181, 135 },
			loren_forest = { 255, 80, 112, 45 },
			lothern_blue = { 255, 52, 162, 207 },
			moot_green = { 255, 82, 178, 68 },
			nurgling_green = { 255, 132, 156, 99 },
			ogryn_camo = { 255, 157, 169, 75 },
			pallid_wych_flesh = { 255, 205, 206, 190 },
			pink_horror = { 255, 144, 48, 93 },
			runefang_steel = { 255, 195, 202, 206 },
			runelord_brass = { 255, 182, 168, 154 },
			russ_grey = { 255, 84, 117, 136 },
			screaming_skull = { 255, 210, 212, 162 },
			skarsnik_green = { 255, 95, 147, 112 },
			skavenblight_dinge = { 255, 71, 65, 59 },
			skrag_brown = { 255, 144, 73, 15 },
			skullcrusher_brass = { 255, 241, 199, 142 },
			slaanesh_grey = { 255, 142, 140, 151 },
			sotek_green = { 255, 11, 105, 116 },
			squig_orange = { 255, 170, 79, 68 },
			stormhost_silver = { 255, 187, 198, 201 },
			stormvermin_fur = { 255, 115, 107, 101 },
			straken_green = { 255, 98, 129, 38 },
			sybarite_green = { 255, 48, 165, 108 },
			sycorax_bronze = { 255, 203, 179, 148 },
			tallarn_sand = { 255, 166, 118, 16 },
			tau_light_ochre = { 255, 191, 110, 29 },
			teclis_blue = { 255, 49, 126, 193 },
			temple_guard_blue = { 255, 51, 154, 141 },
			thunderhawk_blue = { 255, 65, 112, 116 },
			troll_slayer_orange = { 255, 243, 109, 45 },
			tuskgor_fur = { 255, 136, 54, 54 },
			ulthuan_grey = { 255, 199, 224, 217 },
			ungor_flesh = { 255, 214, 167, 102 },
			ushabti_bone = { 255, 187, 187, 127 },
			warboss_green = { 255, 62, 128, 93 },
			warpfiend_grey = { 255, 107, 106, 116 },
			warpstone_glow = { 255, 30, 115, 49 },
			wazdakka_red = { 255, 140, 10, 12 },
			wild_rider_red = { 255, 234, 47, 40 },
			xereus_purple = { 255, 71, 31, 95 },
			yriel_yellow = { 255, 255, 218, 0 },
			zamesi_desert = { 255, 221, 160, 38 },
			agrax_earthshade = { 255, 90, 87, 63 },
			athonian_camoshade = { 255, 109, 142, 68 },
			bieltan_green = { 255, 27, 161, 105 },
			carroburg_crimson = { 255, 168, 42, 112 },
			casandora_yellow = { 255, 254, 206, 90 },
			coelia_greenshade = { 255, 14, 127, 120 },
			drakenhof_nightshade = { 255, 18, 88, 153 },
			druchii_violet = { 255, 122, 70, 140 },
			fuegan_orange = { 255, 199, 126, 77 },
			nuln_oil = { 255, 20, 16, 14 },
			reikland_fleshshade = { 255, 202, 108, 77 },
			seraphim_sepia = { 255, 215, 130, 75 },
			astorath_red = { 255, 221, 72, 43 },
			changeling_pink = { 255, 244, 175, 205 },
			chronus_blue = { 255, 114, 168, 209 },
			eldar_flesh = { 255, 236, 192, 131 },
			etherium_blue = { 255, 162, 186, 210 },
			golden_griffon = { 255, 169, 144, 88 },
			golgfag_brown = { 255, 194, 128, 79 },
			hellion_green = { 255, 132, 195, 170 },
			imrik_blue = { 255, 103, 174, 208 },
			kindleflame = { 255, 247, 158, 134 },
			longbeard_grey = { 255, 206, 206, 175 },
			lucius_lilac = { 255, 182, 159, 204 },
			necron_compound = { 255, 130, 139, 142 },
			niblet_green = { 255, 125, 199, 52 },
			ryza_rust = { 255, 236, 99, 26 },
			sigmarite = { 255, 202, 173, 118 },
			skink_blue = { 255, 88, 193, 205 },
			stormfang = { 255, 128, 167, 193 },
			sylvaneth_bark = { 255, 172, 130, 98 },
			terminatus_stone = { 255, 189, 177, 146 },
			tyrant_skull = { 255, 205, 197, 134 },
			underhive_ash = { 255, 192, 189, 129 },
			verminlord_hide = { 255, 161, 105, 84 },
			wrack_white = { 255, 252, 251, 25 },
			lugganath_orange = { 255, 247, 158, 13 },
			bloodletter = { 255, 243, 115, 85 },
			guilliman_blue = { 255, 47, 154, 214 },
			lamenters_yellow = { 255, 255, 245, 107 },
			waywatcher_green = { 255, 109, 192, 10 },
		},

		ui = {
			brown_light = { 255, 194, 154, 116 },
			brown_super_light = { 255, 255, 242, 230 },
			brown_medium = { 255, 156, 87, 22 },
			brown_dark = { 255, 93, 58, 27 },
			green_light = { 255, 74, 199, 60 },
			green_super_light = { 255, 249, 255, 152 },
			green_medium = { 255, 61, 112, 55 },
			grey_light = { 255, 152, 152, 152 },
			grey_medium = { 255, 102, 102, 102 },
			orange_light = { 255, 255, 183, 44 },
			orange_medium = { 255, 245, 121, 21 },
			orange_dark = { 255, 148, 46, 14 },
			red_light = { 255, 255, 54, 36 },
			red_super_light = { 255, 242, 122, 99 },
			red_medium = { 255, 158, 28, 16 },
			blue_light = { 255, 107, 209, 241 },
			chalk_grey = { 255, 102, 102, 102 },
			interaction_default = { 255, 91, 121, 82 },
			interaction_mission = { 255, 216, 237, 190 },
			interaction_pickup = { 255, 91, 121, 82 },
			interaction_critical = { 255, 246, 69, 69 },
			interaction_point_of_interest = { 255, 176, 150, 99 },
			input_color = { 255, 226, 199, 126 },
			health_default = { 255, 245, 121, 21 },
			health_critical = { 255, 245, 121, 21 },
			health_ghost = { 255, 251, 195, 86 },
			ability_purple = { 255, 102, 38, 98 },
			toughness_default = { 255, 108, 187, 196 },
			toughness_medium = { 255, 62, 143, 155 },
			toughness_buffed = { 255, 196, 195, 108 },
			highlight_color = { 255, 245, 121, 21 },
			corruption_default = { 255, 166, 93, 172 },
			corruption_medium = { 255, 130, 66, 170 },
			disabled_text_color = { 255, 60, 60, 60 },
			terminal = { 255, 226, 199, 126 },
			terminal_dark = { 255, 192, 169, 106 },
			terminal_highlight = { 255, 226, 216, 0 },
			difficulty_1 = { 255, 0, 255, 204 },
			difficulty_2 = { 255, 192, 255, 0 },
			difficulty_3 = { 255, 255, 234, 0 },
			difficulty_4 = { 255, 255, 84, 0 },
			difficulty_5 = { 255, 255, 0, 0 },
			hud_green_super_light = { 255, 216, 237, 190 },
			hud_green_light = { 255, 91, 121, 82 },
			hud_green_medium = { 255, 43, 58, 43 },
			hud_green_dark = { 255, 18, 20, 18 },
			hud_red_super_light = { 255, 240, 201, 201 },
			hud_red_light = { 255, 246, 69, 69 },
			hud_red_medium = { 255, 81, 46, 46 },
			hud_red_dark = { 255, 35, 16, 21 },
			hud_warp_charge_low = { 255, 251, 195, 86 },
			hud_warp_charge_medium = { 255, 245, 121, 21 },
			hud_warp_charge_high = { 255, 246, 69, 69 },
			hud_yellow_super_light = { 255, 218, 186, 126 },
			hud_yellow_light = { 255, 121, 106, 77 },
			hud_yellow_medium = { 255, 63, 56, 43 },
			achievement_icon = { 255, 143, 106, 106 },
			achievement_icon_hover = { 255, 160, 120, 120 },
			achievement_icon_completed = { 255, 242, 228, 157 },
			achievement_icon_completed_hover = { 255, 255, 245, 163 },
			veteran = { 255, 100, 172, 28 },
			zealot = { 255, 204, 26, 28 },
			psyker = { 255, 59, 102, 150 },
			ogryn = { 255, 188, 138, 67 },
			veteran_text = { 255, 117, 129, 93 },
			zealot_text = { 255, 142, 78, 74 },
			psyker_text = { 255, 115, 129, 144 },
			ogryn_text = { 255, 137, 118, 87 },
		},

		rarity = {
			rarity_1 = { 255, 152, 152, 152 },
			rarity_2 = { 255, 74, 177, 85 },
			rarity_3 = { 255, 76, 132, 196 },
			rarity_4 = { 255, 143, 94, 196 },
			rarity_5 = { 255, 208, 136, 48 },
			rarity_6 = { 255, 198, 52, 53 },
			rarity_dark_1 = { 255, 95, 95, 95 },
			rarity_dark_2 = { 255, 42, 99, 48 },
			rarity_dark_3 = { 255, 49, 86, 129 },
			rarity_dark_4 = { 255, 83, 55, 114 },
			rarity_dark_5 = { 255, 128, 84, 30 },
			rarity_dark_6 = { 255, 119, 31, 31 },
			rarity_desaturated_1 = { 255, 152, 152, 152 },
			rarity_desaturated_2 = { 255, 127, 177, 132 },
			rarity_desaturated_3 = { 255, 109, 148, 194 },
			rarity_desaturated_4 = { 255, 150, 109, 194 },
			rarity_desaturated_5 = { 255, 208, 164, 110 },
			rarity_desaturated_6 = { 255, 198, 52, 53 },
		},

		player = {
			slot_1 = { 255, 226, 210, 117 },
			slot_2 = { 255, 180, 88, 162 },
			slot_3 = { 255, 209, 136, 88 },
			slot_4 = { 255, 126, 153, 230 },
			slot_1_bright = { 255, 255, 227, 64 },
			slot_2_bright = { 255, 255, 125, 230 },
			slot_3_bright = { 255, 255, 147, 76 },
			slot_4_bright = { 255, 83, 128, 255 },
		},

		terminal = {
			text_default = { 255, 204, 204, 204 },
			text_cant_afford = { 255, 227, 56, 56 },
			background = { 100, 49, 56, 49 },
			background_dark = { 100, 0, 0, 0 },
			background_selected = { 100, 167, 129, 64 },
			background_gradient = { 255, 101, 133, 96 },
			background_gradient_selected = { 255, 167, 129, 64 },
			grid_background = { 255, 90, 115, 83 },
			grid_background_gradient = { 100, 67, 75, 64 },
			grid_background_icon = { 30, 67, 75, 64 },
			frame = { 255, 60, 78, 57 },
			frame_hover = { 255, 113, 126, 103 },
			frame_selected = { 150, 167, 129, 64 },
			corner = { 255, 121, 136, 109 },
			corner_hover = { 255, 169, 191, 153 },
			corner_hover_bright = { 255, 230, 255, 212 },
			corner_selected = { 255, 250, 189, 73 },
			icon = { 255, 216, 229, 207 },
			icon_dark = { 255, 161, 174, 155 },
			icon_selected = { 255, 255, 242, 230 },
			stat_bar_background = { 255, 125, 108, 56 },
			stat_bar_foreground = { 255, 250, 189, 73 },
			text_key_value = { 255, 239, 193, 82 },
			text_header = { 255, 216, 229, 207 },
			text_header_disabled = { 255, 64, 64, 64 },
			text_header_selected = { 255, 255, 242, 230 },
			text_body = { 255, 169, 191, 153 },
			text_body_dark = { 255, 88, 99, 80 },
			text_body_sub_header = { 255, 113, 126, 103 },
			text_warning_dark = { 255, 200, 140, 20 },
			text_warning_light = { 255, 255, 170, 30 },
			legend_button_text = { 255, 204, 204, 204 },
			legend_button_text_hover = { 255, 255, 242, 230 },
			completed = { 255, 246, 223, 182 },
			mb_base = { 255, 79, 255, 123 },
		},
	}

	function Colors.to_argb(alpha, color)

		if not color or type(color) ~= "table" then

			return { 255, 255, 255, 255 }
		end

		if #color == 4 then
			return { alpha, color[2], color[3], color[4] }
		end

		return { alpha, color[1], color[2], color[3] }
	end

	function Colors.to_rgb(color)

		if not color or type(color) ~= "table" then

			return { 255, 255, 255 }
		end

		if #color == 3 then
			return color
		end

		return {
			color[2],
			color[3],
			color[4],
		}
	end

	function Colors.to_argb_string(alpha, color)

		if not color or type(color) ~= "table" then
			return "255,255,255,255"
		end
		if #color == 4 then
			return string.format("%d,%d,%d,%d", alpha, color[2], color[3], color[4])
		end
		return string.format("%d,%d,%d,%d", alpha, color[1], color[2], color[3])
	end

	function Colors.to_rgb_string(color)

		if not color or type(color) ~= "table" then
			return "255,255,255"
		end
		if #color == 3 then
			return string.format("%d,%d,%d", color[1], color[2], color[3])
		end
		return string.format("%d,%d,%d", color[2], color[3], color[4])
	end

	function Colors.from_string(str)
		if type(str) ~= "string" then
			return nil
		end

		local channels = {}
		for token in str:gmatch("%d+") do
			channels[#channels + 1] = math.min(tonumber(token), 255)
		end

		if #channels == 3 then
			return { 255, channels[1], channels[2], channels[3] }
		end

		if #channels == 4 then
			return channels
		end

		return nil
	end

	function Colors.to_hue(color)
		local rgb = Colors.to_rgb(color)

		local r, g, b = rgb[1] / 255, rgb[2] / 255, rgb[3] / 255

		local max = math.max(r, g, b)
		local min = math.min(r, g, b)
		local d = max - min

		if d == 0 then
			return 0
		elseif max == r then
			return (60 * ((g - b) / d) + 360) % 360
		elseif max == g then
			return 60 * ((b - r) / d + 2)
		else
			return 60 * ((r - g) / d + 4)
		end
	end

	function Colors.to_saturation(color)
		local rgb = Colors.to_rgb(color)

		local r, g, b = rgb[1] / 255, rgb[2] / 255, rgb[3] / 255
		local max = math.max(r, g, b)
		local min = math.min(r, g, b)

		if max == 0 then
			return 0
		end

		return (max - min) / max
	end

	local function hue_to_channel(p, q, t)
		if t < 0 then
			t = t + 1
		elseif t > 1 then
			t = t - 1
		end
		if t < 1 / 6 then
			return p + (q - p) * 6 * t
		elseif t < 1 / 2 then
			return q
		elseif t < 2 / 3 then
			return p + (q - p) * (2 / 3 - t) * 6
		end
		return p
	end

	---@return number r, number g, number b
	function Colors.hsl_to_rgb(h, s, l)
		if s <= 0 then
			return l, l, l
		end
		local q = l < 0.5 and l * (1 + s) or l + s - l * s
		local p = 2 * l - q
		return hue_to_channel(p, q, h + 1 / 3), hue_to_channel(p, q, h), hue_to_channel(p, q, h - 1 / 3)
	end

	---@return number h, number s, number l
	function Colors.rgb_to_hsl(r, g, b)
		local mx, mn = max(r, g, b), min(r, g, b)
		local l = (mx + mn) * 0.5
		if mx == mn then
			return 0, 0, l 
		end
		local d = mx - mn
		local s = l > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
		local h
		if mx == r then
			h = (g - b) / d + (g < b and 6 or 0)
		elseif mx == g then
			h = (b - r) / d + 2
		else
			h = (r - g) / d + 4
		end
		return h / 6, s, l
	end

	---@param color number[]|nil
	---@return number h, number s, number l, number a
	function Colors.argb_to_hsla(color)
		color = color or {}
		local a = (color[1] or 255) / 255
		local r = (color[2] or 0) / 255
		local g = (color[3] or 0) / 255
		local b = (color[4] or 0) / 255
		local h, s, l = Colors.rgb_to_hsl(r, g, b)
		return h, s, l, a
	end

	---@return number[]
	function Colors.hsla_to_argb(h, s, l, a)
		local r, g, b = Colors.hsl_to_rgb(clamp01(h), clamp01(s), clamp01(l))
		return { round_byte(a), round_byte(r), round_byte(g), round_byte(b) }
	end

	---@param colors table<string, rgb_table | argb_table>
	---@return { key: string, value: rgb_table }[]
	function Colors.sort_colors(colors)
		local array = {}

		for k, v in pairs(colors) do
			array[#array + 1] = {
				key = k,
				value = v,
			}
		end

		local function hsv(color)
			local rgb = Colors.to_rgb(color)

			local r, g, b = rgb[1] / 255, rgb[2] / 255, rgb[3] / 255
			local max = math.max(r, g, b)
			local min = math.min(r, g, b)
			local d = max - min

			local s = max == 0 and 0 or d / max
			local v = max

			local h = 0
			if d ~= 0 then
				if max == r then
					h = (60 * ((g - b) / d) + 360) % 360
				elseif max == g then
					h = 60 * ((b - r) / d + 2)
				else
					h = 60 * ((r - g) / d + 4)
				end
			end

			return h, s, v
		end

		table.sort(array, function(a, b)
			local ah, as, av = hsv(a.value)
			local bh, bs, bv = hsv(b.value)

			local agray = as < 0.25
			local bgray = bs < 0.25

			if agray ~= bgray then
				return not agray
			end

			if agray and bgray then
				return av < bv
			end

			return ah < bh
		end)

		return array
	end

	function Colors.lerp_color(from_color, to_color, blend, out)
		out = out or {}
		blend = math_clamp(blend or 0, 0, 1)

		out[1] = (from_color[1] or 255) + ((to_color[1] or 255) - (from_color[1] or 255)) * blend
		out[2] = (from_color[2] or 0) + ((to_color[2] or 0) - (from_color[2] or 0)) * blend
		out[3] = (from_color[3] or 0) + ((to_color[3] or 0) - (from_color[3] or 0)) * blend
		out[4] = (from_color[4] or 0) + ((to_color[4] or 0) - (from_color[4] or 0)) * blend

		return out
	end

	local function hold_blend(blend, hold)
		if not hold or hold <= 0 then
			return blend
		end

		if hold >= 1 then
			return blend >= 1 and 1 or 0
		end

		if blend <= hold then
			return 0
		end

		local t = (blend - hold) / (1 - hold)

		return t * t * (3 - 2 * t)
	end

	function Colors.palette_color(heat, palette, out, hold)
		out = out or {}
		palette = palette or {}
		local stop_count = #palette

		if stop_count == 0 then
			out[1], out[2], out[3], out[4] = 255, 255, 210, 90
			return out
		end

		if heat <= 0 or stop_count == 1 then
			local stop = palette[1]
			out[1] = stop[1] or 255
			out[2] = stop[2] or 255
			out[3] = stop[3] or 255
			out[4] = stop[4] or 255
			return out
		end

		if heat >= 1 then
			local stop = palette[stop_count]
			out[1] = stop[1] or 255
			out[2] = stop[2] or 255
			out[3] = stop[3] or 255
			out[4] = stop[4] or 255
			return out
		end

		local segment_count = stop_count - 1
		local palette_position = heat * segment_count
		local segment_index = math.floor(palette_position) + 1

		if segment_index >= stop_count then
			segment_index = stop_count - 1
		end

		local segment_blend = hold_blend(palette_position - math.floor(palette_position), hold)

		return Colors.lerp_color(palette[segment_index], palette[segment_index + 1], segment_blend, out)
	end

	function Colors.gradient_color(heat, stops, out, hold)
		out = out or {}
		stops = stops or {}
		local stop_count = #stops

		if stop_count == 0 then
			out[1], out[2], out[3], out[4] = 255, 255, 210, 90
			return out
		end

		local function write(color)
			out[1] = color[1] or 255
			out[2] = color[2] or 255
			out[3] = color[3] or 255
			out[4] = color[4] or 255
			return out
		end

		if stop_count == 1 or heat <= stops[1].position then
			return write(stops[1].color)
		end

		if heat >= stops[stop_count].position then
			return write(stops[stop_count].color)
		end

		for i = 1, stop_count - 1 do
			local low, high = stops[i], stops[i + 1]

			if heat < high.position then
				local span = high.position - low.position

				if span <= 0 then
					return write(high.color)
				end

				return Colors.lerp_color(low.color, high.color, hold_blend((heat - low.position) / span, hold), out)
			end
		end

		return write(stops[stop_count].color)
	end

	return Colors
end
