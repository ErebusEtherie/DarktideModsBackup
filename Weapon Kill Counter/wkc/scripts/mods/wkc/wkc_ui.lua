local mod = get_mod("wkc")

local Attack           = require("scripts/utilities/attack/attack")
local WeaponTemplate   = require("scripts/utilities/weapon/weapon_template")

local WKC_DEV_DEBUG              = mod._DEV_DEBUG
local HAVOC_MODIFIERS            = mod._HAVOC_MODIFIERS
local honorific_for_kills        = mod._honorific_for_kills
local PSYKER_STAFF_TEMPLATES     = mod._PSYKER_STAFF_TEMPLATES
local WEAPONS_WITH_MELEE_TRACKER = mod._WEAPONS_WITH_MELEE_TRACKER
local write_crash_journal        = mod._write_crash_journal

local UIWidget            = require("scripts/managers/ui/ui_widget")
local UIFontSettings      = require("scripts/managers/ui/ui_font_settings")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")
local Items               = require("scripts/utilities/items")

local PANEL_ROWS = 200
local ROW_HEIGHT = 28
local ROW_BASE_Y = -270

local PREVIEW_SETTLE  = 0.75
local PREVIEW_REF     = "wkc_weapon_preview"
local PREVIEW_PACKAGE = "packages/ui/views/inventory_weapon_details_view/inventory_weapon_details_view"
local PREVIEW_CLASS_PATH =
	"scripts/ui/view_elements/view_element_inventory_weapon_preview/view_element_inventory_weapon_preview"

mod._stats_panel_item    = {}
mod._preview_retry       = {}
mod._preview_settle      = {}
mod._scroll_fade         = {}
mod._stats_panel_visible = {}
mod._stats_panel_rows    = {}
mod._stats_panel_tree    = {}
mod._row_press           = {}
mod._row_press_all       = {}
mod._row_hovered         = {}
mod._stats_panel_scroll  = {}
mod._stats_panel_template = {}
mod._stats_panel_title  = {}
mod._stats_panel_gen     = {}

local function fmt_num(n)
	n = math.floor((n or 0) + 0.5)
	local str = tostring(n)
	local count = 1
	while count > 0 do
		str, count = str:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	end
	return str
end

local abbrev_num = mod._abbrev_num

local function fmt_damage(n)
	n = math.floor((n or 0) + 0.5)
	if math.abs(n) >= 1e10 then
		return abbrev_num(n)
	end
	return fmt_num(n)
end

local function template_name_for_item(item)
	if not item then return nil end
	local ok, template = pcall(WeaponTemplate.weapon_template_from_item, item)
	if not ok or not template then return nil end
	return template.name
end

local function display_title_for_item(item)
	if not item then return mod:localize("wkc_weapon_fallback") end
	local ok_f, family  = pcall(Items.weapon_lore_family_name, item)
	local ok_p, pattern = pcall(Items.weapon_lore_pattern_name, item)
	local ok_m, mark    = pcall(Items.weapon_lore_mark_name, item)
	family  = (ok_f and family  and family  ~= "n/a") and family  or nil
	pattern = (ok_p and pattern and pattern ~= "n/a") and pattern or nil
	mark    = (ok_m and mark    and mark    ~= "n/a") and mark    or nil
	if not family then
		local ok, full = pcall(Items.display_name, item)
		if ok and full and full ~= "n/a" and full ~= "-" then return full end
		return mod:localize("wkc_weapon_fallback")
	end
	if pattern and mark then return string.format("%s  -  %s %s", family, pattern, mark) end
	if pattern              then return string.format("%s  -  %s",    family, pattern)    end
	if mark                 then return string.format("%s  -  %s",    family, mark)       end
	return family
end

local function is_ranged_weapon(weapon_bucket)
	return weapon_bucket and (weapon_bucket.shots_fired or 0) > 0
end

local function format_accuracy(weapon_bucket, num_fmt)
	num_fmt = num_fmt or fmt_num
	local fired = weapon_bucket.shots_fired or 0
	local hit   = weapon_bucket.shots_hit or 0
	if fired == 0 then return mod:localize("wkc_na") end
	local pct = math.floor((hit / fired) * 100 + 0.5)
	return string.format("%d%%  (%s / %s)", pct, num_fmt(hit), num_fmt(fired))
end

local DOT_STATUS_STAT_ROWS = {
	{ label = mod:localize("wkc_dot_bleed"),         types = { "bleeding" } },
	{ label = mod:localize("wkc_dot_burn"),          types = { "burning" } },
	{ label = mod:localize("wkc_dot_electrocution"), types = { "electrocution" } },
	{ label = mod:localize("wkc_dot_phosphor"),      types = { "phosphor_dot" } },
	{ label = mod:localize("wkc_dot_soulblaze"),     types = { "warpfire" } },
	{ label = mod:localize("wkc_dot_toxin"),         types = { "toxin" } },
}

local SHELL_STAT_ROWS = {
	{ label = mod:localize("wkc_shell_incendiary"), types = { "pellet_incendiary" } },
	{ label = mod:localize("wkc_shell_shock"),      types = { "pellet_shock" } },
	{ label = mod:localize("wkc_shell_heavy"),      types = { "pellet_heavy" } },
}

local PER_TEMPLATE_SPECIAL_CONFIG = {
	shotgun_p1_m1 = { label = mod:localize("wkc_sp_spreadshot") },
	shotgun_p1_m2 = { label = mod:localize("wkc_sp_slug") },
	shotgun_p1_m3 = { skip_row = true },
	shotgun_p2_m1 = { label = mod:localize("wkc_sp_spreadshot") },
	shotgun_p4_m1 = {
		label = mod:localize("wkc_sp_shock_hits"),
		counts = "hits",
		suppress_universal_dt = { "pellet_shock", "pellet_incendiary", "pellet_heavy" },
	},
	shotgun_p4_m2 = {
		label = mod:localize("wkc_sp_brittle_hits"),
		counts = "hits",
		suppress_universal_dt = { "pellet_shock", "pellet_incendiary", "pellet_heavy" },
	},
	dual_shivs_p1_m1 = { skip_row = true },
	dual_shivs_p1_m2 = { skip_row = true },
	saw_p1_m1 = {
		label = mod:localize("wkc_sp_brittleness_mode"),
		complement_label = mod:localize("wkc_sp_toxin_mode"),
	},
	transonic_sword_transonic_knife_p1_m1 = {
		label = mod:localize("wkc_sp_duelist_mode"),
		complement_label = mod:localize("wkc_sp_slayer_mode"),
	},
}

local function special_active_config_for(template_name)
	local cfg = PER_TEMPLATE_SPECIAL_CONFIG[template_name]
	if cfg then return cfg end

	if template_name:find("^forcesword_2h") then
		return { label = mod:localize("wkc_row_warpshock"), skip_row = true }
	end
	if template_name:find("^chainsword") or template_name:find("^chainaxe") then
		return { label = mod:localize("wkc_sp_shredder") }
	end
	if template_name == "crowbar_p1_m1"
	   or template_name:find("^combataxe_p3")
	   or template_name:find("^ogryn_club_p1") then
		return { label = mod:localize("wkc_sp_flipped_mode") }
	end
	if template_name:find("^powermaul_p3") then
		return { label = mod:localize("wkc_sp_powered") }
	end
	if template_name:find("^powermaul")
	   or template_name:find("^ogryn_powermaul")
	   or template_name:find("^ogryn_rippergun")
	   or template_name:find("^dual_stubpistols") then
		return { label = mod:localize("wkc_sp_special") }
	end

	return { label = mod:localize("wkc_sp_powered") }
end

local function build_stat_rows(template_name, source, ns, item)
	local rows = {}
	local stats
	if source then
		stats = source.weapons and source.weapons[template_name]
	else
		stats = mod._bucket_for(template_name, item)
	end
	local s = stats or {}
	ns = ns or ""

	local dt_kills = s.damage_type_kills or {}
	local cfg = special_active_config_for(template_name)

	do
		local mp = s.missions_played or 0
		if mp > 0 then
			local mw = s.missions_won or 0
			rows[#rows + 1] = { label = mod:localize("wkc_row_winrate"),
				value = string.format("%d%% (%s/%s)",
					math.floor(mw / mp * 100 + 0.5), fmt_num(mw), fmt_num(mp)) }
		end
	end
	rows[#rows + 1] = { label = mod:localize("wkc_row_total_damage"), value = fmt_damage(s.damage) }
	if is_ranged_weapon(s) then
		rows[#rows + 1] = { label = mod:localize("wkc_row_accuracy"), value = format_accuracy(s) }
	end

	if not cfg.skip_row and cfg.counts == "hits"
	   and (s.special_active_hits or 0) > 0 then
		rows[#rows + 1] = { label = cfg.label, value = fmt_num(s.special_active_hits) }
	end

	local sbk = s.soulblaze_kills or 0
	if sbk > 0 and not PSYKER_STAFF_TEMPLATES[template_name] then
		rows[#rows + 1] = { label = mod:localize("wkc_row_soulblaze_talents"), value = fmt_num(sbk) }
	end

	rows[#rows + 1] = { label = mod:localize("wkc_row_total_kills"), value = fmt_num(s.kills),
		depth = 0, id = ns .. "total", default_collapsed = false }

	if template_name and template_name:find("^forcesword_2h")
	   and (s.warpshock_slash_kills or 0) > 0 then
		rows[#rows + 1] = { label = mod:localize("wkc_row_warpshock"), depth = 1,
			value = fmt_num(s.warpshock_slash_kills) }
	end

	if not cfg.skip_row and cfg.counts ~= "hits" then
		local count
		if cfg.from_damage_type then
			count = dt_kills[cfg.from_damage_type] or 0
		else
			count = s.special_active_kills or 0
		end
		if cfg.complement_label then
			local other = (s.kills or 0) - count
			if other > 0 then
				rows[#rows + 1] = { label = cfg.complement_label, value = fmt_num(other), depth = 1 }
			end
		end
		if count > 0 then
			rows[#rows + 1] = { label = cfg.label, value = fmt_num(count), depth = 1 }
		end
	end

	local suppressed_dts = nil
	if cfg.suppress_universal_dt then
		suppressed_dts = {}
		for _, dt in ipairs(cfg.suppress_universal_dt) do
			suppressed_dts[dt] = true
		end
	end

	do
		local dot_rows, attributed = {}, 0
		for _, row_spec in ipairs(DOT_STATUS_STAT_ROWS) do
			local total = 0
			local all_suppressed = suppressed_dts ~= nil
			for _, dt in ipairs(row_spec.types) do
				if not (suppressed_dts and suppressed_dts[dt]) then
					all_suppressed = false
				end
				total = total + (dt_kills[dt] or 0)
			end
			if total > 0 and not all_suppressed then
				attributed = attributed + total
				dot_rows[#dot_rows + 1] =
					{ label = row_spec.label, value = fmt_num(total), depth = 2 }
			end
		end

		if attributed > 0 then
			rows[#rows + 1] = { label = mod:localize("wkc_row_dot"), value = fmt_num(attributed),
				depth = 1, id = ns .. "dot", default_collapsed = true }
			for i = 1, #dot_rows do rows[#rows + 1] = dot_rows[i] end
		end
	end

	for _, row_spec in ipairs(SHELL_STAT_ROWS) do
		local total = 0
		local all_suppressed = suppressed_dts ~= nil
		for _, dt in ipairs(row_spec.types) do
			if not (suppressed_dts and suppressed_dts[dt]) then
				all_suppressed = false
			end
			total = total + (dt_kills[dt] or 0)
		end
		if total > 0 and not all_suppressed then
			rows[#rows + 1] = { label = row_spec.label, value = fmt_num(total), depth = 1 }
		end
	end

	if template_name
	   and (string.find(template_name, "^arc_rifle")
	     or string.find(template_name, "^powermaul_p3")) then
		local arc_kills = dt_kills["arc_chain"] or 0
		if arc_kills > 0 then
			rows[#rows + 1] = { label = mod:localize("wkc_row_arc"), value = fmt_num(arc_kills), depth = 1 }
		end
	end

	if (s.parry_kills or 0) > 0 then
		rows[#rows + 1] = { label = mod:localize("wkc_row_parry"), value = fmt_num(s.parry_kills), depth = 1 }
	end

	if (s.blessing_instakills or 0) > 0 then
		rows[#rows + 1] = { label = mod:localize("wkc_row_blessing_instakills"),
			value = fmt_num(s.blessing_instakills), depth = 1 }
	end

	if (s.backstab_kills or 0) > 0 then
		rows[#rows + 1] = { label = mod:localize("wkc_row_backstab"),
			value = fmt_num(s.backstab_kills), depth = 1 }
	end

	if WEAPONS_WITH_MELEE_TRACKER[template_name] then
		rows[#rows + 1] = { label = mod:localize("wkc_row_melee_kills"),
			value = fmt_num(s.melee_kills or 0), depth = 1 }
	end

	if (s.weakspot_kills or 0) > 0 then
		rows[#rows + 1] = { label = mod:localize("wkc_row_weakspot_kills"), value = fmt_num(s.weakspot_kills), depth = 1 }
	end
	if (s.crit_kills or 0) > 0 then
		rows[#rows + 1] = { label = mod:localize("wkc_row_crit_kills"), value = fmt_num(s.crit_kills), depth = 1 }
	end

	for _, grp in ipairs(mod._breed_groups()) do
		local children, parent = mod._group_rows(s, grp, fmt_num)
		if children then
			rows[#rows + 1] = { label = grp.label, value = fmt_num(parent),
				depth = 1, id = ns .. grp.id, default_collapsed = true }
			for i = 1, #children do rows[#rows + 1] = children[i] end
		end
	end

	return rows
end

local function weapon_has_havoc(template_name, item)
	if mod:get("wkc_hide_havoc") then return false end
	local s = mod._bucket_for(template_name, item)
	if not s then return false end
	if (s.havoc_missions_played or 0) > 0 then return true end
	if (s.havoc_kills or 0) > 0 then return true end
	if type(s.havoc) == "table" then
		for _, v in pairs(s.havoc) do
			if (v or 0) > 0 then return true end
		end
	end
	return false
end

local function build_havoc_rows(template_name, item)
	local rows = {}
	local s = mod._bucket_for(template_name, item) or {}

	local hmp = s.havoc_missions_played or 0
	if hmp > 0 then
		local hmw = s.havoc_missions_won or 0
		rows[#rows + 1] = { label = mod:localize("wkc_havoc_winrate"),
			value = string.format("%d%% (%s/%s)",
				math.floor(hmw / hmp * 100 + 0.5), fmt_num(hmw), fmt_num(hmp)) }
	end

	local hk = s.havoc_kills or 0
	if hk > 0 then
		rows[#rows + 1] = { label = mod:localize("wkc_havoc_total_kills"), value = fmt_num(hk) }
	end

	local hv = type(s.havoc) == "table" and s.havoc or {}
	for i = 1, #HAVOC_MODIFIERS do
		local hm = HAVOC_MODIFIERS[i]
		local n = hv[hm.key] or 0
		if n > 0 then
			rows[#rows + 1] = { label = mod._game_loc(hm.loc, hm.display), value = fmt_num(n) }
		end
	end

	if #rows == 0 then
		rows[1] = { label = mod:localize("wkc_havoc_none"), value = "" }
	end
	return rows
end

local function make_label_style(row_index)
	local style = table.clone(UIFontSettings.body)
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment   = "center"
	style.horizontal_alignment      = "center"
	style.vertical_alignment        = "center"
	style.font_size                 = 20
	style.font_type                 = "proxima_nova_bold"
	style.drop_shadow               = true
	style.size                      = { 800, ROW_HEIGHT }
	style.offset                    = { 0, ROW_BASE_Y + (row_index - 1) * ROW_HEIGHT, 53 }
	style.text_color                = Color.terminal_text_body(255, true)
	return style
end

local function make_marker_style(row_index)
	local style = table.clone(UIFontSettings.body)
	style.text_horizontal_alignment = "left"
	style.text_vertical_alignment   = "center"
	style.horizontal_alignment      = "center"
	style.vertical_alignment        = "center"
	style.font_size                 = 20
	style.font_type                 = "proxima_nova_bold"
	style.drop_shadow               = true
	style.size                      = { 20, ROW_HEIGHT }
	style.offset                    = { 0, ROW_BASE_Y + (row_index - 1) * ROW_HEIGHT, 53 }
	style.text_color                = Color.terminal_text_body(255, true)
	return style
end

local function make_value_style(row_index)
	local style = table.clone(UIFontSettings.body)
	style.text_horizontal_alignment = "right"
	style.text_vertical_alignment   = "center"
	style.horizontal_alignment      = "center"
	style.vertical_alignment        = "center"
	style.font_size                 = 20
	style.font_type                 = "proxima_nova_bold"
	style.drop_shadow               = true
	style.size                      = { 800, ROW_HEIGHT }
	style.offset                    = { 0, ROW_BASE_Y + (row_index - 1) * ROW_HEIGHT, 53 }
	style.text_color                = Color.terminal_text_header(255, true)
	return style
end

local function make_title_style()
	local style = table.clone(UIFontSettings.header_1)
	style.text_horizontal_alignment = "center"
	style.text_vertical_alignment   = "center"
	style.horizontal_alignment      = "center"
	style.vertical_alignment        = "center"
	style.font_size                 = 30
	style.font_type                 = "proxima_nova_bold"
	style.drop_shadow               = true
	style.size                      = { 640, 50 }
	style.offset                    = { 0, -390, 56 }
	style.text_color                = { 255, 216, 229, 207 }
	return style
end

local function inject_panel_widget_definitions(definitions)
	if not definitions or not definitions.widget_definitions then return end

	definitions.widget_definitions.wkc_panel = UIWidget.create_definition({
		{
			pass_type = "rect",
			style_id  = "panel",
			style = {
				vertical_alignment   = "center",
				horizontal_alignment = "center",
				size                 = { 900, 750 },
				offset               = { 0, 0, 51 },
				color                = Color.terminal_grid_background(220, true),
			},
		},
	}, "canvas")

	definitions.widget_definitions.wkc_frame = UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id  = "frame",
			value_id  = "texture",
			value     = "content/ui/materials/frames/frame_tile_2px",
			style = {
				vertical_alignment   = "center",
				horizontal_alignment = "center",
				scale_to_material    = true,
				size                 = { 900, 750 },
				offset               = { 0, 0, 52 },
				color                = Color.terminal_frame(255, true),
			},
		},
	}, "canvas")

	definitions.widget_definitions.wkc_shadow = UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id  = "shadow",
			value_id  = "texture",
			value     = "content/ui/materials/frames/dropshadow_medium",
			style = {
				vertical_alignment   = "center",
				horizontal_alignment = "center",
				scale_to_material    = true,
				size                 = { 980, 830 },
				offset               = { 0, 0, 50 },
				color                = { 200, 0, 0, 0 },
			},
		},
	}, "canvas")

	local function ornate(style_id, value_id, material, layer)
		return {
			pass_type = "texture",
			style_id  = style_id,
			value_id  = value_id,
			value     = material,
			style = {
				vertical_alignment   = "center",
				horizontal_alignment = "center",
				scale_to_material    = false,
				size                 = { 1020, 190 },
				offset               = { 0, -375, layer },
				color                = { 255, 255, 255, 255 },
			},
		}
	end

	definitions.widget_definitions.wkc_body = UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id  = "body",
			value_id  = "texture",
			value     = "content/ui/materials/backgrounds/terminal_basic",
			style = {
				vertical_alignment   = "center",
				horizontal_alignment = "center",
				scale_to_material    = false,
				size                 = { 900, 750 },
				offset               = { 0, 0, 51 },
				color                = { 255, 255, 255, 255 },
			},
		},
	}, "canvas")

	definitions.widget_definitions.wkc_header = UIWidget.create_definition({
		ornate("header_frame", "header_tex",
			"content/ui/materials/frames/masteries/panel_main_top_frame", 57),
		ornate("header_candles", "header_candles_tex",
			"content/ui/materials/effects/masteries/panel_main_top_frame_candles", 58),
	}, "canvas")

	definitions.widget_definitions.wkc_footer = UIWidget.create_definition({
		ornate("footer_frame", "footer_tex",
			"content/ui/materials/frames/masteries/panel_main_lower_frame", 57),
		ornate("footer_candles", "footer_candles_tex",
			"content/ui/materials/effects/masteries/panel_main_lower_frame_candles", 58),
	}, "canvas")

	local function divider(style_id, value_id, material)
		return UIWidget.create_definition({
			{
				pass_type = "texture",
				style_id  = style_id,
				value_id  = value_id,
				value     = material,
				style = {
					vertical_alignment   = "center",
					horizontal_alignment = "center",
					scale_to_material    = true,
					size                 = { 700, 36 },
					offset               = { 0, 0, 53 },
					color                = { 255, 255, 255, 255 },
				},
			},
		}, "canvas")
	end

	definitions.widget_definitions.wkc_divider_top = divider("divider", "texture",
		"content/ui/materials/dividers/horizontal_frame_big_upper")
	definitions.widget_definitions.wkc_divider_title = divider("divider", "texture",
		"content/ui/materials/dividers/horizontal_frame_big_middle")
	definitions.widget_definitions.wkc_divider_bottom = divider("divider", "texture",
		"content/ui/materials/dividers/horizontal_frame_big_lower")

	definitions.widget_definitions.wkc_scrollbar = UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id  = "track",
			value_id  = "track_texture",
			value     = "content/ui/materials/scrollbars/scrollbar_thumb_default",
			style = {
				vertical_alignment   = "center",
				horizontal_alignment = "center",
				size                 = { 7, 600 },
				offset               = { 0, 0, 58 },
				color                = { 0, 0, 0, 0 },
			},
		},
		{
			pass_type = "texture",
			style_id  = "frame",
			value_id  = "frame_texture",
			value     = "content/ui/materials/scrollbars/scrollbar_frame_default",
			style = {
				vertical_alignment   = "center",
				horizontal_alignment = "center",
				size                 = { 7, 600 },
				offset               = { 0, 0, 59 },
				color                = { 0, 60, 78, 57 },
			},
		},
		{
			pass_type = "texture",
			style_id  = "thumb",
			value_id  = "thumb_texture",
			value     = "content/ui/materials/scrollbars/scrollbar_thumb_default",
			style = {
				vertical_alignment   = "center",
				horizontal_alignment = "center",
				size                 = { 7, 60 },
				offset               = { 0, 0, 60 },
				color                = { 0, 169, 191, 153 },
			},
		},
	}, "canvas")

	definitions.widget_definitions.wkc_title_plate = UIWidget.create_definition({
		{
			pass_type = "rect",
			style_id  = "plate",
			style = {
				vertical_alignment   = "center",
				horizontal_alignment = "center",
				size                 = { 696, 58 },
				offset               = { 0, 0, 53 },
				color                = { 100, 49, 56, 49 },
			},
		},
		{
			pass_type = "texture",
			style_id  = "headline",
			value_id  = "texture",
			value     = "content/ui/materials/backgrounds/headline_terminal",
			style = {
				vertical_alignment   = "center",
				horizontal_alignment = "center",
				scale_to_material    = true,
				size                 = { 696, 58 },
				offset               = { 0, 0, 54 },
				color                = { 100, 90, 115, 83 },
			},
		},
	}, "canvas")

	definitions.widget_definitions.wkc_title = UIWidget.create_definition({
		{
			pass_type = "text",
			value_id  = "text",
			style_id  = "title",
			value     = "",
			style     = make_title_style(),
		},
	}, "canvas")

	definitions.widget_definitions.wkc_reset = UIWidget.create_definition(
		table.clone(ButtonPassTemplates.default_button),
		"canvas",
		{ original_text = mod:localize("wkc_btn_reset"), text = mod:localize("wkc_btn_reset") },
		{ 360, 70 }
	)

	for i = 1, mod._LAYOUT_EXTRA_SLOTS do
		definitions.widget_definitions["wkc_extra_" .. i] = UIWidget.create_definition({
			{
				pass_type = "texture",
				value_id  = "texture",
				style_id  = "extra",
				value     = "content/ui/materials/backgrounds/default_square",
				style = {
					vertical_alignment   = "center",
					horizontal_alignment = "center",
					scale_to_material    = true,
					size                 = { 100, 100 },
					offset               = { 0, 0, 54 },
					color                = { 255, 255, 255, 255 },
				},
			},
		}, "canvas")
	end

	local marker_material = mod._safe_material(
		(mod._layout or mod._layout_defaults).tree.material)

	for i = 1, PANEL_ROWS do
		local name = "wkc_row_" .. i
		local passes = {
			{
				pass_type  = "hotspot",
				content_id = "hotspot",
				style_id   = "hotspot",
				content    = { use_is_focused = false },
				style = {
					vertical_alignment   = "center",
					horizontal_alignment = "center",
					size                 = { 0, ROW_HEIGHT },
					offset               = { 0, ROW_BASE_Y + (i - 1) * ROW_HEIGHT, 52 },
				},
			},
		}

		if marker_material then
			passes[#passes + 1] = {
				pass_type = "rotated_texture",
				value_id  = "marker_icon",
				style_id  = "marker_icon",
				value     = marker_material,
				style = {
					vertical_alignment   = "center",
					horizontal_alignment = "center",
					angle                = 0,
					size                 = { 12, 12 },
					offset               = { 0, ROW_BASE_Y + (i - 1) * ROW_HEIGHT, 53 },
					color                = { 0, 255, 255, 255 },
				},
			}
		end

		passes[#passes + 1] = {
			pass_type = "text",
			value_id  = "marker",
			style_id  = "marker",
			value     = "",
			style     = make_marker_style(i),
		}
		passes[#passes + 1] = {
			pass_type = "text",
			value_id  = "label",
			style_id  = "label",
			value     = "",
			style     = make_label_style(i),
		}
		passes[#passes + 1] = {
			pass_type = "text",
			value_id  = "value",
			style_id  = "value",
			value     = "",
			style     = make_value_style(i),
		}

		definitions.widget_definitions[name] = UIWidget.create_definition(passes, "canvas")
	end
end

mod:hook(CLASS.InventoryWeaponsView, "_create_widgets", function(func, self, definitions, ...)
	inject_panel_widget_definitions(definitions)
	return func(self, definitions, ...)
end)

local function is_my_widget_name(name)
	return name and (name == "wkc_panel" or name == "wkc_frame"
		or name == "wkc_shadow" or name == "wkc_header"
		or name == "wkc_footer" or name == "wkc_body"
		or name == "wkc_divider_top" or name == "wkc_divider_title"
		or name == "wkc_divider_bottom" or name == "wkc_title_plate"
		or name == "wkc_scrollbar"
		or name == "wkc_title"
		or name == "wkc_reset"
		or name:find("^wkc_row_") ~= nil
		or name:find("^wkc_extra_") ~= nil)
end

local _preview_class

local function preview_class()
	if _preview_class == nil then
		local ok, cls = pcall(require, PREVIEW_CLASS_PATH)
		_preview_class = (ok and cls) or false
	end
	return _preview_class or nil
end

local function preview_package_ready()
	local pm = Managers and Managers.package
	if not pm then return false end

	local ok, loaded = pcall(pm.has_loaded, pm, PREVIEW_PACKAGE)
	if ok and loaded then return true end

	if not mod._preview_package_id then
		local known_ok, known = pcall(pm.package_is_known, pm, PREVIEW_PACKAGE)
		if known_ok and known then
			local load_ok, id = pcall(pm.load, pm, PREVIEW_PACKAGE, "wkc", nil, true)
			if load_ok then mod._preview_package_id = id end
		end
	end
	return false
end

local function preview_element(view)
	return view and view._elements and view._elements[PREVIEW_REF] or nil
end

local function apply_preview_layout(view)
	local element = preview_element(view)
	if not element then return end
	local P = mod._layout_geom().preview

	pcall(element.set_viewport_position_normalized, element, P.vx, P.vy)
	pcall(element.set_viewport_size_normalized, element, P.vw, P.vh)
	pcall(element.set_weapon_position_normalized, element, P.wx, P.wy)
	pcall(element.set_weapon_zoom, element, P.zoom, true, "p_zoom", nil,
		mod._PREVIEW_ZOOM_MIN, mod._PREVIEW_ZOOM_MAX)
	pcall(element.set_force_allow_rotation, element, P.rotate)
end

local function show_preview(view, item)
	local P = mod._layout_geom().preview
	if not (P.on and item) then return end
	if not preview_package_ready() then return end

	local element = preview_element(view)
	if not element then
		local cls = preview_class()
		if not cls or type(view._add_element) ~= "function" then return end
		local ok, created = pcall(view._add_element, view, cls, PREVIEW_REF, P.layer,
			{ draw_background = false, ignore_blur = false })
		if not (ok and created) then return end
		element = created
	end

	pcall(element.set_visibility, element, true)
	if type(element.show) == "function" then pcall(element.show, element) end
	pcall(element.present_item, element, item)
	apply_preview_layout(view)
	mod._preview_settle[view] = PREVIEW_SETTLE
end

local function hide_preview(view)
	local element = preview_element(view)
	if not element then return end
	pcall(element.stop_presenting, element)
	if type(element.hide) == "function" then pcall(element.hide, element) end
	pcall(element.set_visibility, element, false)
end


local function hide_view_chrome(view)
	if view._widgets_by_name then
		for name, widget in pairs(view._widgets_by_name) do
			if not is_my_widget_name(name) then
				widget.visible = false
			end
		end
	end

	if view._elements then
		for ref_name, element in pairs(view._elements) do
			if ref_name ~= PREVIEW_REF
			   and element and type(element.set_visibility) == "function" then
				pcall(element.set_visibility, element, false)
			end
		end
	end
end

local function row_cfg()
	return mod._layout_geom().rows
end

local function apply_color(style_color, c)
	if not (style_color and c) then return end
	style_color[1] = c.a or 255
	style_color[2] = c.r or 255
	style_color[3] = c.g or 255
	style_color[4] = c.b or 255
end

local function relayout_rows(view)
	local widgets = view._widgets_by_name
	if not widgets then return end
	local rows = mod._stats_panel_rows[view] or {}
	local scroll = mod._stats_panel_scroll[view] or 0
	local r = row_cfg()

	local G = mod._layout_geom()
	local sec = G.section
	local tr  = G.tree
	local mw  = tr.marker_w
	local press     = mod._row_press[view]
	local press_all = mod._row_press_all[view]
	mod._row_hovered[view] = nil

	local cursor = r.base_y - r.height * 0.5 - scroll

	for i = 1, PANEL_ROWS do
		local widget = widgets["wkc_row_" .. i]
		local row = rows[i]
		local row_h = mod._row_height(G, row)
		local y = cursor + row_h * 0.5
		if row then cursor = cursor + row_h end
		if widget then
			local hs = widget.content and widget.content.hotspot
			if row and not row.spacer then
				local ms = widget.style and widget.style.marker
				local ls = widget.style and widget.style.label
				local vs = widget.style and widget.style.value
				local within = y >= r.top and y <= r.bottom

				local mi = widget.style and widget.style.marker_icon
				if row.section then
					widget.content.marker = ""
					if mi then mi.color[1] = 0 end
					widget.content.label = row.section
					widget.content.value = ""
					if within then
						if ls then
							ls.font_size = sec.font_size
							ls.font_type = sec.font_type or ls.font_type
							ls.text_horizontal_alignment = "center"
							ls.size[1]   = r.avail
							ls.size[2]   = row_h
							ls.offset[1] = r.centre
							ls.offset[2] = y
							ls.offset[3] = sec.layer
							apply_color(ls.text_color, sec.color)
						end
						if vs then vs.size[1] = 0 end
					end
					if hs then hs.pressed_callback = nil; hs.right_pressed_callback = nil end
					widget.visible = within
				else
					local depth = row.depth or 0
					local lv = mod._level_cfg(G, depth)

					local shut = row.id and mod._tree_collapsed(row, mod._tree_state)
					local icon = row.id and mi ~= nil

					widget.content.label = row.label or ""
					widget.content.value = row.value or ""
					widget.content.marker = (row.id and not icon)
						and (shut and tr.closed or tr.open) or ""

					if within then
						local shift = depth * lv.indent
						if shift > r.avail - mw - 40 then shift = r.avail - mw - 40 end
						if shift < 0 then shift = 0 end

						local marker_x = r.centre + (shift + mw - r.avail) * 0.5
						if ms then
							ms.font_size = lv.font_size * tr.scale
							ms.size[1]   = mw
							ms.size[2]   = row_h
							ms.offset[1] = marker_x
							ms.offset[2] = y
							ms.offset[3] = r.layer
							apply_color(ms.text_color, tr.color)
						end
						if mi then
							local d = lv.font_size * tr.scale
							mi.size[1]   = d
							mi.size[2]   = d
							mi.offset[1] = marker_x - mw * 0.5 + d * 0.5
							mi.offset[2] = y
							mi.offset[3] = r.layer
							mi.angle     = shut and tr.closed_angle or tr.open_angle
							apply_color(mi.color, tr.color)
							if not row.id then mi.color[1] = 0 end
						end
						if ls then
							ls.font_size = lv.font_size
							ls.font_type = "proxima_nova_bold"
							ls.text_horizontal_alignment = "left"
							ls.size[1]   = r.avail - shift - mw
							ls.size[2]   = row_h
							ls.offset[1] = r.centre + (shift + mw) * 0.5
							ls.offset[2] = y
							ls.offset[3] = r.layer
							apply_color(ls.text_color, lv.label_color)
						end
						if vs then
							vs.font_size = lv.font_size
							vs.size[1]   = r.avail - r.value_pad
							vs.size[2]   = row_h
							vs.offset[1] = r.centre - r.value_pad * 0.5
							vs.offset[2] = y
							vs.offset[3] = r.layer
							apply_color(vs.text_color, lv.value_color)
						end
						local hstyle = widget.style and widget.style.hotspot
						if hstyle then
							hstyle.size[1]   = r.avail
							hstyle.size[2]   = row_h
							hstyle.offset[1] = r.centre
							hstyle.offset[2] = y
						end
					end
					if hs then
						if row.id and within and press then
							hs.pressed_callback       = press[i]
							hs.right_pressed_callback = press_all[i]
						else
							hs.pressed_callback       = nil
							hs.right_pressed_callback = nil
						end
					end
					widget.visible = within
				end
			else
				local mi = widget.style and widget.style.marker_icon
				if mi then mi.color[1] = 0 end
				widget.content.marker = ""
				widget.content.label = ""
				widget.content.value = ""
				widget.visible       = false
				if hs then hs.pressed_callback = nil; hs.right_pressed_callback = nil end
			end
		end
	end
end

local function reflow_tree(view)
	local tree = mod._stats_panel_tree[view]
	if not tree then return end
	mod._stats_panel_rows[view] = mod._tree_flatten(tree, mod._tree_state)
	local max_scroll = mod._scroll_max(view)
	if (mod._stats_panel_scroll[view] or 0) > max_scroll then
		mod._stats_panel_scroll[view] = max_scroll
	end
	relayout_rows(view)
	mod._bump_scrollbar(view)
end

local function toggle_row(view, index, all)
	local flat = mod._stats_panel_rows[view]
	local row = flat and flat[index]
	local tree = mod._stats_panel_tree[view]
	if not (row and row.id and tree) then return end
	if all then
		mod._tree_toggle_all(tree, mod._tree_state)
	else
		mod._tree_toggle(tree, mod._tree_state, row.id)
	end
	reflow_tree(view)
end

local function bind_row_callbacks(view)
	if mod._row_press[view] then return end
	local press, press_all = {}, {}
	for i = 1, PANEL_ROWS do
		press[i]     = function() toggle_row(view, i, false) end
		press_all[i] = function() toggle_row(view, i, true) end
	end
	mod._row_press[view]     = press
	mod._row_press_all[view] = press_all
end

local function set_panel_rows(view, tree)
	mod._stats_panel_tree[view] = tree
	mod._stats_panel_rows[view] = mod._tree_flatten(tree, mod._tree_state)
end
mod._set_panel_rows = set_panel_rows

local function apply_chrome_layout(view)
	local widgets = view and view._widgets_by_name
	if not widgets then return end
	local L = mod._layout or mod._layout_defaults
	local G = mod._layout_geom()

	local function place(widget, style_id, rect, cfg)
		if not (widget and rect) then return end
		local s = widget.style and widget.style[style_id]
		if not s then return end
		if s.size then s.size[1] = rect.w; s.size[2] = rect.h end
		if s.offset then
			s.offset[1] = rect.x
			s.offset[2] = rect.y
			s.offset[3] = cfg.layer
		end
		apply_color(s.color, cfg.color)
		if mod._material_ok(cfg.material) then
			widget.content.texture = cfg.material
		end
	end

	place(widgets.wkc_panel, "panel", G.panel, L.panel)

	place(widgets.wkc_frame, "frame", G.frame, L.frame)
	if widgets.wkc_frame and (L.frame.enabled or 0) == 0 then
		widgets.wkc_frame.visible = false
	end

	place(widgets.wkc_divider_top,    "divider", G.divider_top,    L.divider_top)
	place(widgets.wkc_divider_title,  "divider", G.divider_title,  L.divider_title)
	place(widgets.wkc_divider_bottom, "divider", G.divider_bottom, L.divider_bottom)

	local plate = widgets.wkc_title_plate
	if plate then
		local rect = G.title_plate
		local rs = plate.style and plate.style.plate
		if rs then
			rs.size[1]   = rect.w
			rs.size[2]   = rect.h
			rs.offset[1] = rect.x
			rs.offset[2] = rect.y
			rs.offset[3] = L.title_plate.layer
			apply_color(rs.color, L.title_plate.plate_color)
		end
		local hs = plate.style and plate.style.headline
		if hs then
			hs.size[1]   = rect.w
			hs.size[2]   = rect.h
			hs.offset[1] = rect.x
			hs.offset[2] = rect.y
			hs.offset[3] = L.title_plate.layer + 1
			apply_color(hs.color, L.title_plate.color)
		end
		if mod._material_ok(L.title_plate.material) then
			plate.content.texture = L.title_plate.material
		end
	end

	local shadow = widgets.wkc_shadow
	if shadow then
		local on = (L.shadow.enabled or 0) ~= 0 and mod._material_ok(L.shadow.material)
		shadow.visible = on and (mod._stats_panel_visible[view] and true or false)
		local s = shadow.style and shadow.style.shadow
		if s and on then
			shadow.content.texture = L.shadow.material
			s.size[1]   = G.shadow.w
			s.size[2]   = G.shadow.h
			s.offset[1] = G.shadow.x
			s.offset[2] = G.shadow.y
			s.offset[3] = L.shadow.layer
			apply_color(s.color, L.shadow.color)
		end
	end

	local body = widgets.wkc_body
	if body then
		local s = body.style and body.style.body
		local on = mod._material_ok(L.body.material)
		if s and on then
			body.content.texture = L.body.material
			s.size[1]   = G.body.w
			s.size[2]   = G.body.h
			s.offset[1] = G.body.x
			s.offset[2] = G.body.y
			s.offset[3] = L.body.layer
			apply_color(s.color, L.body.color)
		end
		body.visible = on and (mod._stats_panel_visible[view] and true or false)
	end

	local function ornate_pair(widget, frame_rect, candle_rect, cfg,
	                           frame_id, frame_val, candle_id, candle_val)
		if not widget then return end
		local any = false
		local parts = {
			{ id = frame_id,  content = frame_val,  material = cfg.material,
			  color = cfg.color,         layer = cfg.layer,     rect = frame_rect },
			{ id = candle_id, content = candle_val, material = cfg.candles,
			  color = cfg.candles_color, layer = cfg.layer + 1, rect = candle_rect },
		}
		for _, part in ipairs(parts) do
			local s = widget.style and widget.style[part.id]
			if s then
				local ok = mod._material_ok(part.material)
				if ok then
					widget.content[part.content] = part.material
					any = true
				end
				s.size[1]   = part.rect.w
				s.size[2]   = part.rect.h
				s.offset[1] = part.rect.x
				s.offset[2] = part.rect.y
				s.offset[3] = part.layer
				apply_color(s.color, part.color)
				if not ok then s.color[1] = 0 end
			end
		end
		widget.visible = any and (mod._stats_panel_visible[view] and true or false)
	end

	ornate_pair(widgets.wkc_header, G.header, G.header_candles, L.header,
		"header_frame", "header_tex", "header_candles", "header_candles_tex")
	ornate_pair(widgets.wkc_footer, G.footer, G.footer_candles, L.footer,
		"footer_frame", "footer_tex", "footer_candles", "footer_candles_tex")

	local title = widgets.wkc_title
	if title and title.style and title.style.title then
		local s = title.style.title
		s.font_size = L.title.font_size
		s.font_type = L.title.font_type or s.font_type
		s.material  = mod._safe_material(L.title.material)
		s.size[1]   = G.title.w
		s.size[2]   = G.title.h
		s.offset[1] = G.title.x
		s.offset[2] = G.title.y
		s.offset[3] = L.title.layer
		apply_color(s.text_color, L.title.color)
	end

	local p = G.panel
	for i = 1, mod._LAYOUT_EXTRA_SLOTS do
		local widget = widgets["wkc_extra_" .. i]
		if widget then
			local cfg = L.extras and L.extras[i]
			if cfg and mod._material_ok(cfg.material) then
				widget.content.texture = cfg.material
				local s = widget.style and widget.style.extra
				if s then
					s.size[1]   = cfg.w or 100
					s.size[2]   = cfg.h or 100
					s.offset[1] = p.x + (cfg.x or 0)
					s.offset[2] = p.y + (cfg.y or 0)
					s.offset[3] = cfg.layer or 54
					apply_color(s.color, cfg.color)
				end
				widget.visible = mod._stats_panel_visible[view] and true or false
			else
				widget.visible = false
			end
		end
	end
end

function mod._scroll_max(view)
	local G = mod._layout_geom()
	local rows = mod._stats_panel_rows[view] or {}
	local r = G.rows
	local content_h = mod._rows_content_height(G, rows)
	return math.max(0, content_h - (r.bottom - r.top - r.height)),
	       content_h, r.bottom - r.top, r
end

function mod._scrollbar_alpha(left, fade)
	if not (left and fade) or fade <= 0 then return 0 end
	local a = left / fade
	if a < 0 then return 0 end
	if a > 1 then return 1 end
	return a
end

function mod._scrollbar_thumb(track_top, track_h, min_thumb,
                              view_h, content_h, scroll, max_scroll)
	if track_h <= 0 then return 0, track_top end

	local frac = 1
	if content_h and content_h > 0 then frac = view_h / content_h end
	if frac < 0 then frac = 0 end
	if frac > 1 then frac = 1 end

	local thumb_h = track_h * frac
	if thumb_h < min_thumb then thumb_h = min_thumb end
	if thumb_h > track_h then thumb_h = track_h end

	local progress = 0
	if max_scroll and max_scroll > 0 then progress = scroll / max_scroll end
	if progress < 0 then progress = 0 end
	if progress > 1 then progress = 1 end

	return thumb_h, track_top + thumb_h * 0.5 + (track_h - thumb_h) * progress
end

function mod._bump_scrollbar(view)
	local S = mod._layout_geom().scrollbar
	mod._scroll_fade[view] = S.hold + S.fade
end

local function update_scrollbar(view, dt)
	local widgets = view and view._widgets_by_name
	local widget = widgets and widgets.wkc_scrollbar
	if not widget then return end

	local L = mod._layout or mod._layout_defaults
	local S = mod._layout_geom().scrollbar
	local left = mod._scroll_fade[view] or 0

	if not (S.on and mod._stats_panel_visible[view]) or left <= 0 then
		widget.visible = false
		return
	end

	left = left - (dt or 0)
	mod._scroll_fade[view] = left
	if left <= 0 then
		widget.visible = false
		return
	end

	local max_scroll, content_h, view_h = mod._scroll_max(view)
	if max_scroll <= 0 or content_h <= 0 then
		widget.visible = false
		return
	end

	local fade = mod._scrollbar_alpha(left, S.fade)
	local track_h = S.h
	local thumb_h, thumb_y = mod._scrollbar_thumb(S.top, track_h, S.min_thumb,
		view_h, content_h, mod._stats_panel_scroll[view] or 0, max_scroll)
	local any = false

	local function part(style_id, value_key, material, colour, h, y, layer)
		local s = widget.style and widget.style[style_id]
		if not s then return end
		local ok = mod._material_ok(material)
		if ok then
			widget.content[value_key] = material
			any = true
		end
		s.size[1]   = S.w
		s.size[2]   = h
		s.offset[1] = S.x
		s.offset[2] = y
		s.offset[3] = layer
		apply_color(s.color, colour)
		s.color[1] = ok and math.floor((colour.a or 255) * fade + 0.5) or 0
	end

	part("track", "track_texture", L.scrollbar.thumb_material,
		S.track_color, track_h, S.y, S.layer)
	part("frame", "frame_texture", L.scrollbar.material,
		S.color, track_h, S.y, S.layer + 1)
	part("thumb", "thumb_texture", L.scrollbar.thumb_material,
		S.thumb_color, thumb_h, thumb_y, S.layer + 2)

	widget.visible = any
end

local function update_row_hover(view)
	local widgets = view._widgets_by_name
	local rows = mod._stats_panel_rows[view]
	if not (widgets and rows) then return end

	local hovered = 0
	for i = 1, PANEL_ROWS do
		local row = rows[i]
		if not row then break end
		if row.id then
			local widget = widgets["wkc_row_" .. i]
			local hs = widget and widget.visible and widget.content
				and widget.content.hotspot
			if hs and hs.is_hover then
				hovered = i
				break
			end
		end
	end

	if mod._row_hovered[view] == hovered then return end
	mod._row_hovered[view] = hovered

	local tr = mod._layout_geom().tree
	for i = 1, PANEL_ROWS do
		local row = rows[i]
		if not row then break end
		if row.id then
			local st = widgets["wkc_row_" .. i]
			st = st and st.style
			local c = i == hovered and tr.hover_color or tr.color
			if st and st.marker then apply_color(st.marker.text_color, c) end
			if st and st.marker_icon then apply_color(st.marker_icon.color, c) end
		end
	end
end

local function set_my_widget_visibility(view, visible)
	local widgets = view._widgets_by_name
	if not widgets then return end
	for _, n in ipairs({ "wkc_shadow", "wkc_panel", "wkc_body", "wkc_header",
	                    "wkc_footer", "wkc_frame", "wkc_divider_top",
	                    "wkc_divider_title", "wkc_divider_bottom",
	                    "wkc_title_plate", "wkc_title", "wkc_reset" }) do
		local w = widgets[n]
		if w then w.visible = visible end
	end
	if not visible then
		local bar = widgets.wkc_scrollbar
		if bar then bar.visible = false end
		for i = 1, PANEL_ROWS do
			local w = widgets["wkc_row_" .. i]
			if w then w.visible = false end
		end
		for i = 1, mod._LAYOUT_EXTRA_SLOTS do
			local w = widgets["wkc_extra_" .. i]
			if w then w.visible = false end
		end
	end
end

local function apply_button_layout(view)
	local widgets = view and view._widgets_by_name
	if not widgets then return end
	local L = mod._layout or mod._layout_defaults

	local widget = widgets.wkc_reset
	if not widget then return end
	widget.offset = widget.offset or { 0, 0, 0 }
	widget.offset[1] = L.reset.x
	widget.offset[2] = L.reset.y
	widget.offset[3] = L.reset.layer
	local sz = widget.content and widget.content.size
	if sz then sz[1] = L.reset.w; sz[2] = L.reset.h end
end

local SUBTRACT_SKIP = {
	display_family = true, display_pattern = true, display_mark = true,
	label = true, rating = true, template = true,
	last_honorific_threshold = true,
}

local function subtract_existing(dst, src)
	for k, v in pairs(src) do
		if not SUBTRACT_SKIP[k] and dst[k] ~= nil then
			if type(v) == "number" and type(dst[k]) == "number" then
				local left = dst[k] - v
				dst[k] = left > 0 and left or 0
			elseif type(v) == "table" and type(dst[k]) == "table" then
				subtract_existing(dst[k], v)
			end
		end
	end
end

local function blank_bucket(w, template_name)
	return {
		kills = 0, elite_kills = 0, special_kills = 0,
		weakspot_kills = 0, crit_kills = 0, damage = 0,
		shots_fired = 0, shots_hit = 0,
		breeds = {},
		damage_type_kills = {},
		special_active_kills = 0,
		special_active_hits  = 0,
		parry_kills = 0,
		last_honorific_threshold = 0,
		display_family  = w.display_family,
		display_pattern = w.display_pattern,
		display_mark    = w.display_mark,
		label    = w.label,
		rating   = w.rating,
		template = w.template,
	}
end

local function reset_bucket_to_zero(template_name, item)
	local stats = mod._stats
	if not stats then return end
	local per_instance = mod._per_instance()
	local store, key
	if per_instance then
		store = stats.instances
		key = mod._gear_id_for(template_name, item)
	else
		store = stats.weapons
		key = template_name
	end
	if not (store and key and store[key]) then return end
	local w = store[key]

	mod._pending_shot[template_name] = nil
	store[key] = blank_bucket(w, template_name)

	if per_instance then
		local merged = stats.weapons[w.template or template_name]
		if merged then
			subtract_existing(merged, w)
			merged.last_honorific_threshold =
				honorific_for_kills(merged.kills or 0).threshold
		end
		if type(stats.totals) == "table" then
			subtract_existing(stats.totals, w)
		end
		mod._stats_dirty = false
		mod:set("stats_data", mod._stats)
		write_crash_journal()
		return
	end

	local inst = stats.instances
	if type(inst) == "table" then
		for gid, iw in pairs(inst) do
			if type(iw) == "table" and iw.template == template_name then
				inst[gid] = blank_bucket(iw, template_name)
			end
		end
	end

	local t = stats.totals or {}
	stats.totals = t
	local function take(field)
		local left = (t[field] or 0) - (w[field] or 0)
		t[field] = left > 0 and left or 0
	end
	take("kills")
	take("elite_kills")
	take("special_kills")
	take("weakspot_kills")
	take("crit_kills")
	take("damage")
	take("havoc_kills")
	if type(t.havoc) == "table" and type(w.havoc) == "table" then
		for key, n in pairs(w.havoc) do
			local left = (t.havoc[key] or 0) - (n or 0)
			t.havoc[key] = left > 0 and left or 0
		end
	end

	mod._stats_dirty = false
	mod:set("stats_data", mod._stats)
	write_crash_journal()
end

local function request_reset_for_current_template(view)
	if not (Managers and Managers.event) then return end
	local template_name = mod._stats_panel_template[view]
	if not template_name then return end

	local popup_context = {
		title_text       = "loc_wkc_reset_title",
		description_text = mod._per_instance()
			and "loc_wkc_reset_description_instance"
			or "loc_wkc_reset_description",
		options = {
			{
				close_on_pressed = true,
				template_type    = "terminal_button_hold_small",
				template_options = { timer = 2 },
				text             = "loc_wkc_reset_hold",
				callback         = function()
					reset_bucket_to_zero(template_name, mod._stats_panel_item[view])
					mod._set_panel_rows(view, mod._build_panel_rows(template_name,
						mod._stats_panel_item[view]))
					mod._stats_panel_scroll[view] = 0
					mod._apply_title(view, template_name, mod._stats_panel_title[view])
					relayout_rows(view)
				end,
			},
			{
				close_on_pressed = true,
				text             = "loc_wkc_reset_cancel",
				callback         = function() end,
			},
		},
	}

	Managers.event:trigger("event_show_ui_popup", popup_context, function(id) end)
end

local function append_section(rows, heading, extra_rows)
	if not extra_rows or #extra_rows == 0 then return end
	local sec = mod._layout_geom().section
	for _ = 1, sec.gap_before do rows[#rows + 1] = { spacer = true } end
	rows[#rows + 1] = { section = heading }
	for _ = 1, sec.gap_after do rows[#rows + 1] = { spacer = true } end
	for i = 1, #extra_rows do rows[#rows + 1] = extra_rows[i] end
end

local function build_panel_rows(template_name, item)
	local rows = build_stat_rows(template_name, nil, nil, item)

	if weapon_has_havoc(template_name, item) then
		append_section(rows, mod:localize("wkc_section_havoc"),
			build_havoc_rows(template_name, item))
	end

	if WKC_DEV_DEBUG then
		append_section(rows, "DEBUG", build_stat_rows(template_name, mod._debug_stats, "dbg:"))
	end

	return rows
end
mod._build_panel_rows = build_panel_rows

local function text_width_fn(view, font_type, font_size)
	local scale = 1
	pcall(function()
		local r = view._ui_renderer
		local s = (r and r.scale) or (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.scale)
		if type(s) == "number" and s > 0 then scale = s end
	end)

	return function(s)
		local ok, w = pcall(view._text_size, view, s, font_type, font_size)
		if ok and type(w) == "number" then return w / scale end
		return nil
	end
end

local function fit_title_text(view, text, max_w, font_type, font_size)
	if type(text) ~= "string" or text == "" then return text end

	local width_of = text_width_fn(view, font_type, font_size)

	local full = width_of(text)
	if not full then
		local budget = math.max(math.floor(max_w / (font_size * 0.52)), 8)
		if #text <= budget then return text end
		return text:sub(1, budget - 3) .. "..."
	end
	if full <= max_w then return text end

	local lo, hi = 0, #text
	while lo < hi do
		local mid = math.floor((lo + hi + 1) * 0.5)
		local w = width_of(text:sub(1, mid) .. "...")
		if w and w <= max_w then lo = mid else hi = mid - 1 end
	end

	while lo > 0 and text:byte(lo + 1)
	      and text:byte(lo + 1) >= 0x80 and text:byte(lo + 1) < 0xC0 do
		lo = lo - 1
	end

	if lo <= 0 then return "..." end
	return text:sub(1, lo) .. "..."
end
mod._fit_title_text = fit_title_text

local function apply_title(view, template_name, title)
	local widgets = view._widgets_by_name
	local widget = widgets and widgets.wkc_title
	if not widget then return end

	local L = mod._layout or mod._layout_defaults
	local G = mod._layout_geom()
	local final_title = title or template_name
	local title_color = nil

	if mod:get("wkc_honorific_title") then
		local bucket = mod._bucket_for(template_name, mod._stats_panel_item[view])
		local tier = honorific_for_kills(bucket and bucket.kills or 0)
		final_title = string.format("%s  %s", tier.name, final_title)
		title_color = tier.color
	end

	local s = widget.style and widget.style.title
	if s then
		local font_type = L.title.font_type or s.font_type
		local font_size = L.title.font_size or s.font_size
		local max_w = math.max(G.panel.w - 16, 40)

		final_title = fit_title_text(view, final_title, max_w, font_type, font_size)

		if s.size then s.size[1] = math.max(G.title.w, math.min(max_w, G.panel.w)) end
		if title_color then
			apply_color(s.text_color, { a = title_color[1], r = title_color[2],
				g = title_color[3], b = title_color[4] })
		else
			apply_color(s.text_color, L.title.color)
		end
	end

	widget.content.text = final_title
end

local function open_panel_for_template_with_title(view, template_name, title)
	if not view or not template_name then return end

	bind_row_callbacks(view)
	set_panel_rows(view, build_panel_rows(template_name))
	mod._stats_panel_scroll[view]   = 0
	mod._stats_panel_template[view] = template_name
	mod._stats_panel_title[view]    = title

	hide_view_chrome(view)
	mod._stats_panel_visible[view] = true
	set_my_widget_visibility(view, true)
	apply_chrome_layout(view)
	apply_title(view, template_name, title)
	apply_button_layout(view)
	relayout_rows(view)
	mod._preview_retry[view] = 0
	show_preview(view, mod._stats_panel_item[view])
end
mod._apply_title = apply_title

local function open_panel_for_item(view, item)
	local template_name = template_name_for_item(item)
	if not template_name then
		mod:notify(mod:localize("wkc_msg_no_template"))
		return
	end
	mod._stats_panel_item[view] = item
	open_panel_for_template_with_title(view, template_name, display_title_for_item(item))
end

mod:hook_safe(CLASS.InventoryWeaponsView, "on_enter", function(self)
	mod._label_seen = {}
	local widgets = self._widgets_by_name
	if not widgets then return end

	local reset_btn = widgets.wkc_reset
	if reset_btn then
		if reset_btn.content and reset_btn.content.hotspot then
			reset_btn.content.hotspot.pressed_callback = function()
				request_reset_for_current_template(self)
			end
		end
	end

	set_my_widget_visibility(self, false)
	mod._stats_panel_visible[self] = false
end)

mod:hook_safe(CLASS.InventoryWeaponsView, "on_exit", function(self)
	hide_preview(self)
	mod._stats_panel_visible[self]   = nil
	mod._stats_panel_rows[self]      = nil
	mod._stats_panel_tree[self]      = nil
	mod._row_press[self]             = nil
	mod._row_press_all[self]         = nil
	mod._row_hovered[self]           = nil
	mod._stats_panel_scroll[self]    = nil
	mod._stats_panel_template[self]  = nil
	mod._stats_panel_title[self]     = nil
	mod._stats_panel_item[self]      = nil
	mod._preview_retry[self]         = nil
	mod._preview_settle[self]        = nil
	mod._scroll_fade[self]           = nil
	mod._stats_panel_gen[self]       = nil
end)

mod:hook_safe(CLASS.InventoryWeaponsView, "update", function(self, dt, t, input_service)
	local gen = mod._layout_gen or 0
	local layout_changed = mod._stats_panel_gen[self] ~= gen
	mod._stats_panel_gen[self] = gen

	if not mod._stats_panel_visible[self] then
		return
	end

	if layout_changed then
		apply_chrome_layout(self)
		local template_name = mod._stats_panel_template[self]
		if template_name then
			mod._set_panel_rows(self, mod._build_panel_rows(template_name))
			mod._apply_title(self, template_name, mod._stats_panel_title[self])
		end
		apply_button_layout(self)
		relayout_rows(self)
		if mod._layout_geom().preview.on then
			if preview_element(self) then
				apply_preview_layout(self)
			else
				show_preview(self, mod._stats_panel_item[self])
			end
		else
			hide_preview(self)
		end
	end

	update_scrollbar(self, dt)
	update_row_hover(self)

	local settle = mod._preview_settle[self]
	if settle then
		settle = settle - dt
		if settle <= 0 then
			mod._preview_settle[self] = nil
		else
			mod._preview_settle[self] = settle
			apply_preview_layout(self)
		end
	end

	local retry = mod._preview_retry[self]
	if retry and not preview_element(self) then
		retry = retry - dt
		if retry <= 0 then
			retry = 0.25
			show_preview(self, mod._stats_panel_item[self])
		end
		mod._preview_retry[self] = retry
	end

	if not input_service or not input_service.get then return end

	local scroll_axis = input_service:get("scroll_axis")
	if not scroll_axis then return end
	local dy = scroll_axis[2] or 0
	if dy == 0 then return end

	local rows = mod._stats_panel_rows[self] or {}
	if #rows == 0 then return end

	local r = row_cfg()
	local cur = mod._stats_panel_scroll[self] or 0
	local max_scroll = mod._scroll_max(self)

	if dy > 0 then
		cur = math.max(0, cur - r.height * 3)
	else
		cur = math.min(max_scroll, cur + r.height * 3)
	end

	mod._stats_panel_scroll[self] = cur
	mod._bump_scrollbar(self)
	relayout_rows(self)
	update_scrollbar(self, 0)
end)

local STATS_ICON_CODEPOINT = 0xE053

local function utf8_from_cp(cp)
	if cp < 0x80 then
		return string.char(cp)
	elseif cp < 0x800 then
		return string.char(0xC0 + math.floor(cp / 0x40),
		                   0x80 + (cp % 0x40))
	elseif cp < 0x10000 then
		return string.char(0xE0 + math.floor(cp / 0x1000),
		                   0x80 + math.floor(cp / 0x40) % 0x40,
		                   0x80 + (cp % 0x40))
	end
	return ""
end

local STATS_ICON = utf8_from_cp(STATS_ICON_CODEPOINT)

mod:hook_safe(CLASS.InventoryWeaponsView, "_setup_weapon_options", function(self)
	local grid = self._weapon_options_element
	if not grid then return end

	local layout = grid._visible_grid_layout
	if not layout then return end

	for _, entry in ipairs(layout) do
		if entry._wkc_button then return end
	end

	layout[#layout + 1] = {
		display_icon = STATS_ICON,
		widget_type  = "button",
		display_name = mod:localize("wkc_btn_stats"),
		_wkc_button = true,
		callback = function()
			local item = self._previewed_item
			if not item then
				mod:notify(mod:localize("wkc_msg_no_weapon"))
				return
			end
			open_panel_for_item(self, item)
		end,
	}

	grid:present_grid_layout(layout, self._definitions.blueprints)
end)

mod._viewing_other_player_inventory = false
mod._inspected_player = nil

mod:hook_safe(CLASS.InventoryBackgroundView, "on_enter", function(self)
	local other = self._is_own_player == false
	mod._viewing_other_player_inventory = other
	mod._inspected_player = nil
	if other and mod._share_inspected_from_view then
		mod._inspected_player = mod._share_inspected_from_view(self)
	end
	if mod._share_bump then mod._share_bump() end
	if other and mod._share_note_inspect then mod._share_note_inspect() end
end)

mod:hook_safe(CLASS.InventoryBackgroundView, "on_exit", function(self)
	mod._viewing_other_player_inventory = false
	mod._inspected_player = nil
	if mod._share_bump then mod._share_bump() end
end)

local function honorific_prefix_for_item(item)
	if not mod:is_enabled() then return nil end
	if not mod:get("wkc_inventory_prefix") then return nil end
	if not item or not item.item_type then return nil end

	local ok_w, is_weapon = pcall(Items.is_weapon, item.item_type)
	if not (ok_w and is_weapon) then return nil end

	local template_name = template_name_for_item(item)
	if not template_name then return nil end

	local kills
	if mod._share_kills_for_item then
		local peer, foreign = mod._share_kills_for_item(item, template_name)
		if foreign then
			if not peer then return nil end
			kills = peer
		end
	end
	if not kills then
		local bucket = mod._bucket_for(template_name, item)
		kills = bucket and bucket.kills or 0
	end

	local tier = honorific_for_kills(kills)

	return tier.name
end

function mod.on_all_mods_loaded()
	local current = Items.weapon_card_display_name
	if current ~= Items._wkc_wrapper then
		Items._wkc_orig_weapon_card_display_name = current
	end
	local orig = Items._wkc_orig_weapon_card_display_name

	local wrapper = function(item)
		local base = orig(item)
		if type(base) ~= "string" or base == "" then return base end

		local ok, prefix = pcall(honorific_prefix_for_item, item)
		if not (ok and prefix) then return base end

		return prefix .. " " .. base
	end

	Items._wkc_wrapper = wrapper
	Items.weapon_card_display_name = wrapper

	if mod._share_init then
		mod._share_init()
	end
end

local function scrub_name_it_prefill(item)
	if not mod:get("wkc_inventory_prefix") then return end
	local ni = get_mod("name_it")
	if not (ni and type(ni._current_name) == "string") then return end

	local ok, prefix = pcall(honorific_prefix_for_item, item)
	if not (ok and prefix) then return end

	local p = prefix .. " "
	if ni._current_name:sub(1, #p) == p then
		ni._current_name = ni._current_name:sub(#p + 1)
	end
end

mod:hook_safe(CLASS.InventoryWeaponsView, "_preview_item", function(self, item)
	scrub_name_it_prefill(item)
end)

mod:hook_safe(CLASS.CraftingMechanicusModifyView, "_preview_item", function(self, item)
	scrub_name_it_prefill(item)
end)

local _all_view_registered = false

local function register_all_view()
	if _all_view_registered then return true end
	local ok = pcall(function()
		mod:add_require_path("wkc/scripts/mods/wkc/wkc_allview")
		mod:register_view({
			view_name = "wkc_all_view",
			view_settings = {
				init_view_function = function() return true end,
				class = "WeaponKillCounterAllView",
				disable_game_world = false,
				display_name = "wkc",
				game_world_blur = 1.1,
				load_always = true,
				load_in_hub = true,
				package = "packages/ui/views/options_view/options_view",
				path = "wkc/scripts/mods/wkc/wkc_allview",
				state_bound = true,
				use_transition_ui = false,
				wwise_states = { options = "ingame_menu" },
			},
			view_transitions = {},
			view_options = {
				close_all = false,
				close_previous = false,
				close_transition_time = nil,
				transition_time = nil,
			},
		})
	end)
	_all_view_registered = ok
	return ok
end

local function weapon_list_label(w, template_name)
	local family = w.display_family or ""
	local mark   = w.display_mark or ""
	local label = family
	if mark ~= "" then
		label = (label ~= "" and (label .. " ") or "") .. mark
	end
	if label == "" then
		label = template_name
	end
	return label
end

local function instance_list_label(w)
	local label = w.label
	if type(label) ~= "string" or label == "" then
		label = weapon_list_label(w, w.template or "")
	end
	if type(w.rating) == "number" then
		label = label .. " (" .. tostring(w.rating) .. ")"
	end
	return label
end

local function open_all_weapons_view()
	if not register_all_view() then
		mod:echo(mod:localize("wkc_msg_view_unavailable"))
		return
	end
	local entries = {}
	local per_instance = mod._per_instance()
	if per_instance then
		for gear_id, w in pairs(mod._stats.instances or {}) do
			entries[#entries + 1] = {
				template_name = w.template,
				gear_id = gear_id,
				label = instance_list_label(w),
				kills = w.kills or 0,
				kills_text = fmt_num(w.kills or 0),
			}
		end
	else
		for template_name, w in pairs(mod._stats.weapons or {}) do
			entries[#entries + 1] = {
				template_name = template_name,
				label = weapon_list_label(w, template_name),
				kills = w.kills or 0,
				kills_text = fmt_num(w.kills or 0),
			}
		end
	end
	if per_instance then
		table.sort(entries, function(a, b)
			return (a.gear_id or "") < (b.gear_id or "")
		end)
		local collisions = {}
		for i = 1, #entries do
			local l = entries[i].label
			collisions[l] = (collisions[l] or 0) + 1
		end
		local nth = {}
		for i = 1, #entries do
			local l = entries[i].label
			if collisions[l] > 1 then
				nth[l] = (nth[l] or 0) + 1
				entries[i].label = l .. " #" .. tostring(nth[l])
			end
		end
	end
	table.sort(entries, function(a, b)
		if a.kills == b.kills then return a.label < b.label end
		return a.kills > b.kills
	end)
	local total = (mod._stats.totals and mod._stats.totals.kills) or 0
	if per_instance then
		total = 0
		for i = 1, #entries do total = total + entries[i].kills end
	end
	local context = {
		entries = entries,
		total_kills = total,
		total_kills_text = fmt_num(total),
		get_rows = function(entry)
			return mod._tree_indent_labels(
				build_stat_rows(entry.template_name, nil, nil, entry.gear_id))
		end,
		get_havoc_rows = function(entry)
			return build_havoc_rows(entry.template_name, entry.gear_id)
		end,
		has_havoc = function(entry)
			return weapon_has_havoc(entry.template_name, entry.gear_id)
		end,
	}
	local ui = Managers.ui
	if not ui then return end
	if ui.view_active and ui:view_active("wkc_all_view") then
		ui:close_view("wkc_all_view", true)
	end
	ui:open_view("wkc_all_view", nil, false, false, nil, context, {
		use_transition_ui = false,
	})
end

register_all_view()

mod:command("wkc_all", mod:localize("wkc_cmd_all_desc"), function()
	open_all_weapons_view()
end)

mod:command("wkc", mod:localize("wkc_cmd_wkc_desc"), function()
	mod:echo(mod:localize("wkc_cmd_overview"))
end)

