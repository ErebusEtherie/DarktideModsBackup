local mod = get_mod("SkitariiUIFix")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local TalentSettings = require("scripts/settings/talent/talent_settings")
local HudElementPlayerAbilitySettings =
	require("scripts/ui/hud/elements/player_ability/hud_element_player_ability_settings")
local HudElementPlayerAbilityHandlerSettings =
	require("scripts/ui/hud/elements/player_ability_handler/hud_element_player_ability_handler_settings")

local ABILITY_SIZE = (HudElementPlayerAbilityHandlerSettings and HudElementPlayerAbilityHandlerSettings.ability_size)
	or HudElementPlayerAbilitySettings.ability_size
local COUNTER_OFFSET_Y = -(ABILITY_SIZE[1] * 0.5 + 15)

local COLORS = {
	red    = { 255, 70, 70 },
	pink   = { 255, 125, 200 },
	purple = { 178, 90, 255 },
	white  = { 240, 240, 240 },
	green  = { 95, 230, 130 },
	yellow = { 255, 230, 60 },
	orange = { 255, 150, 40 },
	cyan   = { 90, 200, 255 },
}

local function clamp01(v)
	if v < 0 then
		return 0
	end
	if v > 1 then
		return 1
	end
	return v
end

local _ui_color_cache = {}
local function ui_color(name)
	name = name or "white"
	local cached = _ui_color_cache[name]
	if cached then
		return cached
	end
	local c = COLORS[name] or COLORS.white
	cached = { 255, c[1], c[2], c[3] }
	_ui_color_cache[name] = cached
	return cached
end

-- Mirror setting ("none" / "horizontal" / "vertical" / "both") as two flags.
local function mirror_flags(value)
	return value == "horizontal" or value == "both", value == "vertical" or value == "both"
end

-- Write a (possibly mirrored) full-texture uv rect into an existing style.uvs table.
-- Flipping the u axis is what moves an arc material to the other side of the crosshair.
local function set_uvs(uvs, mirror_h, mirror_v)
	if not uvs or not uvs[1] or not uvs[2] then
		return
	end
	uvs[1][1] = mirror_h and 1 or 0
	uvs[2][1] = mirror_h and 0 or 1
	uvs[1][2] = mirror_v and 1 or 0
	uvs[2][2] = mirror_v and 0 or 1
end

-- The Skitarii / Adeptus Mechanicus archetype is internally named "cryptic".
local SKITARII_ARCHETYPE = "cryptic"

local function is_skitarii()
	local player_manager = Managers.player
	if not player_manager then
		return false
	end
	local player = player_manager:local_player_safe(1)
	if not player then
		return false
	end
	local ok, profile = pcall(player.profile, player)
	if not ok or type(profile) ~= "table" then
		return false
	end
	local archetype = profile.archetype
	return archetype ~= nil and archetype.name == SKITARII_ARCHETYPE
end

-- True when the percent overlay should take over the ability icon right now: the
-- feature is enabled and, unless the "Skitarii only" limit is on and we are on
-- another class, the current class should get it.
local function percent_active()
	if not mod:get("ability_enabled") then
		return false
	end
	if mod:get("ability_skitarii_only") and not is_skitarii() then
		return false
	end
	return true
end

local ABILITY_DEFS_PATH =
	"scripts/ui/hud/elements/player_ability/hud_element_player_ability_vertical_definitions"

local ability_text_style = table.clone(UIFontSettings.hud_body)
ability_text_style.text_horizontal_alignment = "center"
ability_text_style.text_vertical_alignment = "center"
ability_text_style.offset = { 0, 0, 12 }

mod:hook(_G, "dofile", function(func, path)
	local instance = func(path)

	if path == ABILITY_DEFS_PATH
		and type(instance) == "table"
		and instance.scenegraph_definition
		and instance.widget_definitions
	then
		instance.scenegraph_definition.skitarii_cooldown = {
			parent = "slot",
			vertical_alignment = "center",
			horizontal_alignment = "center",
			size = HudElementPlayerAbilitySettings.ability_size,
			position = { 0, 0, 12 },
		}

		instance.widget_definitions.skitarii_cooldown_pct = UIWidget.create_definition({
			{
				value = " ",
				value_id = "text",
				style_id = "text",
				pass_type = "text",
				style = ability_text_style,
				visibility_function = function(content, pass_style)
					if not percent_active() then
						return false
					end
					local t = content.text
					return t ~= nil and t ~= " " and t ~= ""
				end,
			},
		}, "skitarii_cooldown")

		local nui_timer_def = instance.widget_definitions.cooldown_timer
		if nui_timer_def and nui_timer_def.passes then
			-- NumericUI builds this widget without an explicit value, so its content
			-- defaults to the literal "placeholder_text". Clear it so the placeholder can
			-- never leak onto the ability icon (e.g. the Skitarii charge ability, whose
			-- progress NumericUI can't read, so it never overwrites the default).
			if nui_timer_def.content then
				nui_timer_def.content.text = " "
			end
			for _, pass in ipairs(nui_timer_def.passes) do
				local prev_vis = pass.visibility_function
				pass.visibility_function = function(content, pass_style)
					-- Our percent replaces the NumericUI timer while it is active.
					if percent_active() then
						return false
					end
					if prev_vis then
						return prev_vis(content, pass_style)
					end
					-- Otherwise defer to NumericUI, but never draw an empty or
					-- placeholder value (that is what left "placeholder_text" on screen).
					local t = content and content.text
					return t ~= nil and t ~= " " and t ~= "" and t ~= "placeholder_text"
				end
			end
		end
	end

	return instance
end)

mod:hook_safe("HudElementPlayerAbility", "update", function(self)
	if not percent_active() then
		return
	end

	local widgets_by_name = self._widgets_by_name
	local text_widget = widgets_by_name and widgets_by_name.skitarii_cooldown_pct
	if not text_widget then
		return
	end

	local progress = self._ability_progress or 1
	local on_cooldown = self._on_cooldown
	local position = mod:get("ability_percent_position") or "icon"

	local style = text_widget.style and text_widget.style.text
	if style then
		style.font_size = mod:get("ability_font_size") or 28
		style.text_color = ui_color(mod:get("ability_color"))

		local offset = style.offset
		if offset then
			local ox = mod:get("ability_percent_offset_x") or 0
			local oy = mod:get("ability_percent_offset_y") or 0
			if position == "charges" then
				offset[1] = 40 + ox
				offset[2] = COUNTER_OFFSET_Y + oy
			else
				offset[1] = ox
				offset[2] = oy
			end
		end
	end

	if not on_cooldown or progress >= 1 then
		text_widget.content.text = " "
	else
		local percent = math.floor(progress * 100)
		if percent < 1 then
			percent = 1
		end
		if position == "charges" then
			text_widget.content.text = string.format("(%d%%)", percent)
		else
			text_widget.content.text = string.format("%d%%", percent)
		end
	end

	text_widget.dirty = true
end)

local WC_TEMPLATE_PATH =
	"scripts/ui/hud/elements/weapon_counter/templates/weapon_counter_template_cooldown_charges"
local MAX_NUM_BARS = 8
local WC_BAR_STYLE_IDS = {}
-- The passes this mod moves around, so a pass another mod added is left as it built it.
local WC_TRANSFORM_STYLE_IDS = { lightning_and_glow = true }
for ii = 1, MAX_NUM_BARS do
	WC_BAR_STYLE_IDS[ii] = string.format("charge_bar_%d", ii)
	WC_TRANSFORM_STYLE_IDS[WC_BAR_STYLE_IDS[ii]] = true
end

-- The template's own base opacities, needed to rebuild them without the fade the game
-- applies once the charges are full (weapon_counter_template_cooldown_charges).
local WC_FILLED_FILL_OPACITY = 0.6
local WC_UNFILLED_FILL_OPACITY = 0.7
local WC_OUTLINE_OPACITY = 0.8
local WC_OUTLINE_OPACITY_SPECIAL_ACTIVE = 1

local wc_text_style = table.clone(UIFontSettings.hud_body)
wc_text_style.text_horizontal_alignment = "center"
wc_text_style.text_vertical_alignment = "center"
wc_text_style.font_size = 48
wc_text_style.size = { 400, 400 }
wc_text_style.offset = { 0, 0, 30 }

local function usable_charges(state)
	if not state then
		return 0
	end
	local num = state.num or 0
	local thresholds = state.thresholds
	if not thresholds or #thresholds < 2 then
		return math.floor(num + 0.0001)
	end
	local count = 0
	for ii = 2, #thresholds do
		local t = thresholds[ii] and thresholds[ii].threshold
		if t and num >= t then
			count = count + 1
		end
	end
	return count
end

-- The pips are plain "texture" passes: those ignore style.uvs and have no angle, so the
-- gauge can only ever sit exactly where the game puts it. "rotated_texture" draws the
-- same material with the same material_values (see UIPasses), plus angle/pivot/uvs -
-- swapping the pass type is what makes moving, turning and mirroring possible. Done on
-- the live widget (not the shared definition) so it also works on a HUD that already
-- existed when the mod loaded.
local function make_wc_transformable(widget)
	if widget._skitarii_transformable then
		return
	end
	widget._skitarii_transformable = true

	local passes = widget.passes
	local style = widget.style
	if not passes or not style then
		return
	end
	for ii = 1, #passes do
		local pass = passes[ii]
		local pass_style = pass.style_id and WC_TRANSFORM_STYLE_IDS[pass.style_id] and style[pass.style_id]
		if pass.pass_type == "texture" and pass_style then
			pass.pass_type = "rotated_texture"
			pass_style.angle = pass_style.angle or 0
			-- An empty pivot makes the pass rotate around the middle of its own rect.
			pass_style.pivot = pass_style.pivot or {}
			pass_style.uvs = pass_style.uvs or { { 0, 0 }, { 1, 1 } }
		end
	end
end

-- Position / rotation / mirroring of the whole gauge. Every pass of the widget sits at
-- offset {0, 0, layer} in the definition and nothing else writes these, so the values
-- are absolute: passing zeros restores the game's own layout.
local function apply_wc_transform(style, ox, oy, angle, mirror_h, mirror_v)
	for ii = 1, MAX_NUM_BARS do
		local seg = style[WC_BAR_STYLE_IDS[ii]]
		if seg then
			seg.angle = angle
			set_uvs(seg.uvs, mirror_h, mirror_v)
			local offset = seg.offset
			if offset then
				offset[1] = ox
				offset[2] = oy
			end
		end
	end

	local glow = style.lightning_and_glow
	if glow then
		glow.angle = angle
		set_uvs(glow.uvs, mirror_h, mirror_v)
		local offset = glow.offset
		if offset then
			offset[1] = ox
			offset[2] = oy
		end
	end

	local text_style = style.skitarii_charge_text
	local text_offset = text_style and text_style.offset
	if text_offset then
		text_offset[1] = ox
		text_offset[2] = oy
	end
end

-- How many charge bars the template is actually driving this frame. The template clears
-- content.last_weapon_template whenever it can't read the weapon (mid weapon swap) and
-- zeroes every bar in that case - we must not put opacity back into bars it considers
-- unused, or empty arcs would show up.
local function wc_used_bars(widget, tmpl)
	local content = widget.content
	if not content or content.last_weapon_template == nil then
		return 0
	end
	local state = tmpl and tmpl.data and tmpl.data.state
	local thresholds = state and state.thresholds
	if not thresholds then
		return 0
	end
	return math.max(0, math.min(MAX_NUM_BARS, #thresholds - 1))
end

local function post_process_wc(widget, tmpl)
	if not widget or not widget.style then
		return
	end

	local content = widget.content
	local style = widget.style
	local text_style = style.skitarii_charge_text

	if not mod:get("wc_enabled") then
		if content then
			content.skitarii_charge_text = " "
		end
		if text_style then
			text_style.visible = false
		end
		-- Put the game's own layout back if we moved the gauge before being switched off.
		if widget._skitarii_transformable then
			apply_wc_transform(style, 0, 0, 0, false, false)
		end
		return
	end

	make_wc_transformable(widget)

	local mirror_h, mirror_v = mirror_flags(mod:get("wc_mirror"))
	apply_wc_transform(
		style,
		mod:get("wc_offset_x") or 0,
		mod:get("wc_offset_y") or 0,
		math.rad(mod:get("wc_rotation") or 0),
		mirror_h,
		mirror_v
	)

	local mode = mod:get("wc_mode") or "recolor"

	if mode == "vanilla" then
		-- Moved / turned / mirrored, but drawn exactly as the game colours it.
		if content then
			content.skitarii_charge_text = " "
		end
		if text_style then
			text_style.visible = false
		end
		return
	end

	if mode == "numbers" then
		local state = tmpl and tmpl.data and tmpl.data.state

		if content then
			content.skitarii_charge_text = tostring(usable_charges(state))
		end
		if text_style then
			text_style.font_size = mod:get("wc_font_size") or 48

			local c = COLORS[mod:get("wc_color")] or COLORS.white
			local op = (mod:get("wc_number_opacity") or 75) / 75
			local tc = text_style.text_color
			if type(tc) ~= "table" then
				tc = { 255, 255, 255, 255 }
				text_style.text_color = tc
			end
			tc[1] = math.floor(clamp01(op) * 255 + 0.5)
			tc[2] = c[1]
			tc[3] = c[2]
			tc[4] = c[3]

			text_style.visible = true
		end

		for ii = 1, MAX_NUM_BARS do
			local seg = style[WC_BAR_STYLE_IDS[ii]]
			local mv = seg and seg.material_values
			if mv then
				mv.amount = 0
				if mv.fill_outline_opacity then
					mv.fill_outline_opacity[1] = 0
					mv.fill_outline_opacity[2] = 0
				end
			end
		end
		local glow = style.lightning_and_glow
		if glow and glow.material_values and glow.material_values.fill_outline_opacity then
			glow.material_values.fill_outline_opacity[1] = 0
			glow.material_values.fill_outline_opacity[2] = 0
		end
	else
		if content then
			content.skitarii_charge_text = " "
		end
		if text_style then
			text_style.visible = false
		end

		local main = COLORS[mod:get("wc_color")] or COLORS.white
		local mr, mg, mb = main[1] / 255, main[2] / 255, main[3] / 255

		local contrast_on = mod:get("wc_fill_contrast")
		local fill_c = contrast_on and (COLORS[mod:get("wc_fill_color")] or COLORS.white) or main
		local fr, fg, fb = fill_c[1] / 255, fill_c[2] / 255, fill_c[3] / 255

		local op = (mod:get("wc_number_opacity") or 75) / 75

		-- Two seconds after the charges top up the game fades the whole gauge out
		-- (content.idle_alpha runs 1 -> 0 and multiplies every opacity). We rebuild the
		-- opacities from the template's base values instead of scaling what it wrote, so
		-- the inner fill and the outline can each opt out of that fade on their own.
		local idle_alpha = clamp01((content and content.idle_alpha) or 1)
		local fill_alpha = mod:get("wc_no_fade_fill") and 1 or idle_alpha
		local outline_alpha = mod:get("wc_no_fade_outline") and 1 or idle_alpha
		local special = clamp01((content and content.special_active_progress) or 0)
		local base_outline = WC_OUTLINE_OPACITY
			+ (WC_OUTLINE_OPACITY_SPECIAL_ACTIVE - WC_OUTLINE_OPACITY) * special
		local used_bars = wc_used_bars(widget, tmpl)
		local previous_filled = content and content.previous_filled
		local delay_timer = content and content.delay_timer

		for ii = 1, MAX_NUM_BARS do
			local seg = style[WC_BAR_STYLE_IDS[ii]]
			local mv = seg and seg.material_values
			if mv then
				local fill = mv.fillcolor
				if fill then
					fill[1] = fr
					fill[2] = fg
					fill[3] = fb
				end
				local outline = mv.outline_color
				if outline then
					outline[1] = mr
					outline[2] = mg
					outline[3] = mb
				end
				local opacity = mv.fill_outline_opacity
				if opacity then
					if ii <= used_bars then
						local filled = (delay_timer and (delay_timer[ii] or 0) > 0)
							or (previous_filled and previous_filled[ii] == true)
						-- A contrasting fill is drawn solid, brighter than either game state.
						local base_fill = contrast_on and 1
							or (filled and WC_FILLED_FILL_OPACITY or WC_UNFILLED_FILL_OPACITY)
						opacity[1] = clamp01(base_fill * fill_alpha * op)
						opacity[2] = clamp01(base_outline * outline_alpha * op)
					else
						opacity[1] = 0
						opacity[2] = 0
					end
				end
			end
		end

		-- The glow ring follows the same fade; leave it alone on frames the template
		-- skips it (no weapon state), otherwise it would drift.
		local glow = style.lightning_and_glow
		local glow_opacity = glow and glow.material_values and glow.material_values.fill_outline_opacity
		if glow_opacity and used_bars > 0 then
			glow_opacity[1] = clamp01(WC_FILLED_FILL_OPACITY * fill_alpha * op)
			glow_opacity[2] = clamp01(outline_alpha * op)
		end
	end
end

mod:hook_require(WC_TEMPLATE_PATH, function(template)
	if type(template) ~= "table" or template._skitarii_wrapped then
		return
	end
	template._skitarii_wrapped = true

	local orig_create = template.create_widget_defintion
	if orig_create then
		template.create_widget_defintion = function(scenegraph_id)
			local definition = orig_create(scenegraph_id)
			if definition then
				UIWidget.add_definition_pass(definition, {
					pass_type = "text",
					value = " ",
					value_id = "skitarii_charge_text",
					style_id = "skitarii_charge_text",
					style = table.clone(wc_text_style),
				})
			end
			return definition
		end
	end

	local orig_update = template.update_function
	if orig_update then
		template.update_function =
			function(element, ui_renderer, widget, is_wielded, settings, tmpl, dt, t)
				orig_update(element, ui_renderer, widget, is_wielded, settings, tmpl, dt, t)
				post_process_wc(widget, tmpl)
			end
	end
end)

-- Noospheric Command (servo-skull order) duration indicator, drawn as a mirrored
-- copy of the weapon charge arc on the opposite (left) side of the crosshair, or as
-- a seconds countdown. Two detection paths, because the game implements the order
-- differently depending on talents:
--   1. Untalented base order: the game puts the
--      "cryptic_servo_skull_temporary_buff_player_dummy" buff on the player itself,
--      readable client-side every frame.
--   2. Improved tagging talent (the 2s fire-rate order): the buff lives on the
--      servo-skull unit server-side only, so it is invisible to the client. The
--      order, however, always creates the "servo_skull_enemy_companion_target"
--      smart tag, which IS replicated to every client - we arm a local timer of the
--      talent's duration from it, refreshed by each new tag.
local ORDER_BUFF_NAME = "cryptic_servo_skull_temporary_buff_player_dummy"
local ORDER_TAG_TEMPLATE = "servo_skull_enemy_companion_target"
-- Same arc span, radius and thickness the weapon charge pips use, so the two sides match.
local SKULL_ARC_TOP = 0.675
local SKULL_ARC_BOTTOM = 0.325
local SKULL_SIZE = { 400, 400 }
local SKULL_THICKNESS = { 0.6, 0.015, 0.011 }
-- The pips sit at 0.6 of the half-width (120 px) from the crosshair; put the text there too.
local SKULL_TEXT_RADIUS = 120

local function local_player_unit()
	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player_safe(1)
	return player and player.player_unit
end

local function gameplay_time()
	local time_manager = Managers.time
	if not time_manager then
		return nil
	end
	local ok, t = pcall(time_manager.time, time_manager, "gameplay")
	return ok and t or nil
end

local function order_buff_remaining()
	local unit = local_player_unit()
	if not unit then
		return nil
	end
	local buff_extension = ScriptUnit.has_extension(unit, "buff_system")
	if not buff_extension then
		return nil
	end
	local buffs = buff_extension:buffs()
	for ii = 1, #buffs do
		local buff = buffs[ii]
		if buff:template_name() == ORDER_BUFF_NAME then
			local progress = buff:duration_progress() or 0
			local duration = buff:duration() or 0
			if progress > 0 and duration > 0 then
				return progress, duration * progress
			end
			return nil
		end
	end
	return nil
end

local function tagging_order_duration()
	local cryptic = TalentSettings and TalentSettings.cryptic
	local tagging = cryptic and cryptic.servo_skull_shooting_tagging
	return tagging and tagging.duration or 2
end

mod:hook_safe("SmartTagSystem", "_create_tag_locally", function(self, tag_id, template_name, tagger_unit)
	if template_name ~= ORDER_TAG_TEMPLATE then
		return
	end
	if not tagger_unit or tagger_unit ~= local_player_unit() then
		return
	end
	local now = gameplay_time()
	if not now then
		return
	end
	local duration = tagging_order_duration()
	mod._skull_order_duration = duration
	mod._skull_order_end_t = now + duration
end)

-- Remaining order time from whichever source is active: the player buff (base
-- order) or the tag-armed local timer (improved tagging talent).
local function order_state()
	local progress, remaining = order_buff_remaining()
	if progress then
		return progress, remaining
	end

	local end_t = mod._skull_order_end_t
	if end_t then
		local now = gameplay_time()
		local duration = mod._skull_order_duration or 0
		local left = now and end_t - now or 0
		-- left can never exceed duration within a single mission; when it does, the
		-- gameplay clock has restarted (new mission) and this end-time is a stale
		-- carry-over from the previous one - the same cross-mission staleness that
		-- otherwise stalls the order keybind. Discard it instead of showing a false timer.
		if left > 0 and duration > 0 and left <= duration then
			return clamp01(left / duration), left
		end
		mod._skull_order_end_t = nil
	end

	return nil
end

local skull_text_style = table.clone(UIFontSettings.hud_body)
skull_text_style.text_horizontal_alignment = "center"
skull_text_style.text_vertical_alignment = "center"
skull_text_style.horizontal_alignment = "center"
skull_text_style.vertical_alignment = "center"
skull_text_style.font_size = 26
skull_text_style.size = { SKULL_SIZE[1], SKULL_SIZE[2] }
skull_text_style.offset = { -SKULL_TEXT_RADIUS, 0, 3 }

local function create_skull_widget_definition()
	return UIWidget.create_definition({
		{
			-- rotated_texture honours style.uvs AND style.angle while handling
			-- material_values exactly like a plain texture pass, so the arc can be
			-- mirrored to either side of the crosshair and turned to any angle.
			pass_type = "rotated_texture",
			value = "content/ui/materials/effects/forcesword_bar",
			style_id = "skull_bar",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				angle = 0,
				-- An empty pivot makes the pass rotate around the middle of its own rect.
				pivot = {},
				uvs = { { 1, 0 }, { 0, 1 } },
				offset = { 0, 0, 2 },
				size = { SKULL_SIZE[1], SKULL_SIZE[2] },
				color = { 255, 255, 255, 255 },
				material_values = {
					amount = 0,
					glow_on_off = 0,
					lightning_opacity = 0,
					arc_top_bottom = { SKULL_ARC_TOP, SKULL_ARC_BOTTOM },
					fill_outline_opacity = { 0, 0 },
					outline_color = { 1, 1, 1, 1 },
					fillcolor = { 1, 1, 1, 1 },
					SizeThicknessOutline = {
						SKULL_THICKNESS[1],
						SKULL_THICKNESS[2],
						SKULL_THICKNESS[3],
					},
					fillTex = "content/ui/textures/masks/square",
				},
			},
		},
		{
			pass_type = "text",
			value = " ",
			value_id = "skull_seconds",
			style_id = "skull_seconds",
			style = table.clone(skull_text_style),
		},
	}, "pivot")
end

mod:hook_safe("HudElementWeaponCounter", "_draw_widgets", function(self, dt, t, input_service, ui_renderer)
	if not mod:get("skull_enabled") then
		return
	end

	-- Skitarii-only: never draw the order indicator (not even "always visible")
	-- while playing any other class.
	if not is_skitarii() then
		return
	end

	-- Created lazily so it also appears on an element that already existed when the
	-- mod (re)loaded, not only on freshly built HUDs.
	local widget = self._skitarii_skull_widget
	if not widget then
		widget = UIWidget.init("skitarii_skull_order", create_skull_widget_definition())
		self._skitarii_skull_widget = widget
	end

	local progress, remaining = order_state()
	if not progress and not mod:get("skull_always_show") then
		return
	end
	progress = progress or 0
	remaining = remaining or 0

	-- The original _draw_widgets has already resolved the crosshair position this frame;
	-- the widget offset moves the whole indicator away from it.
	local offset = widget.offset
	offset[1] = (self._crosshair_position_x or 0) + (mod:get("skull_offset_x") or 0)
	offset[2] = (self._crosshair_position_y or 0) + (mod:get("skull_offset_y") or 0)

	local content = widget.content
	local bar_style = widget.style.skull_bar
	local mv = bar_style and bar_style.material_values
	local text_style = widget.style.skull_seconds
	local main_c = COLORS[mod:get("skull_color")] or COLORS.cyan
	local fill_c = COLORS[mod:get("skull_fill_color")] or COLORS.cyan
	local outline_op = clamp01((mod:get("skull_outline_opacity") or 100) / 100)
	local fill_op = clamp01((mod:get("skull_fill_opacity") or 90) / 100)
	local mirror_h, mirror_v = mirror_flags(mod:get("skull_mirror") or "horizontal")

	if bar_style then
		bar_style.angle = math.rad(mod:get("skull_rotation") or 0)
		set_uvs(bar_style.uvs, mirror_h, mirror_v)
	end
	-- Keep the seconds readout on the same side of the crosshair as the arc.
	local text_offset = text_style and text_style.offset
	if text_offset then
		text_offset[1] = mirror_h and -SKULL_TEXT_RADIUS or SKULL_TEXT_RADIUS
	end

	if mod:get("skull_seconds_mode") then
		if mv then
			mv.amount = 0
			mv.fill_outline_opacity[1] = 0
			mv.fill_outline_opacity[2] = 0
		end
		content.skull_seconds = string.format("%.1f", remaining)
		if text_style then
			text_style.font_size = mod:get("skull_font_size") or 26
			local tc = text_style.text_color
			if type(tc) ~= "table" then
				tc = { 255, 255, 255, 255 }
				text_style.text_color = tc
			end
			tc[1] = math.floor(outline_op * 255 + 0.5)
			tc[2] = main_c[1]
			tc[3] = main_c[2]
			tc[4] = main_c[3]
		end
	else
		content.skull_seconds = " "
		if mv then
			mv.amount = progress
			mv.fill_outline_opacity[1] = fill_op
			mv.fill_outline_opacity[2] = outline_op
			local fill = mv.fillcolor
			fill[1] = fill_c[1] / 255
			fill[2] = fill_c[2] / 255
			fill[3] = fill_c[3] / 255
			fill[4] = 1
			local outline = mv.outline_color
			outline[1] = main_c[1] / 255
			outline[2] = main_c[2] / 255
			outline[3] = main_c[3] / 255
			outline[4] = 1
		end
	end

	widget.dirty = true
	UIWidget.draw(widget, ui_renderer)
end)

-- Standalone "order servo-skull to attack the aimed enemy" keybind. This is the
-- game's own companion-tag ("companion_order") action, re-implemented on a private
-- key so it works regardless of the vanilla "Companion Command" tag setting and of
-- any other mod. The normal tag key keeps its usual behaviour, and this bind issues
-- the order directly through the smart-tag system. The branch logic mirrors
-- HudElementSmartTagging._on_tag_stop_callback's companion path.
--
-- We deliberately do NOT route through the HUD element's methods: doing so ran the
-- order through other mods' tag hooks (e.g. ServoSkullCommander's block), which made
-- the order silently do nothing (near a dome, or while the skull was "busy"). The
-- keybind is instead fully self-contained, including its own psyker-shield guard.
local function order_debug(fmt, ...)
	if mod:get("order_debug") then
		mod:echo("[Skitarii order] " .. string.format(fmt, ...))
	end
end

local function aimed_tag_target(player_unit)
	local targeting_extension = ScriptUnit.has_extension(player_unit, "smart_targeting_system")
	if not targeting_extension then
		return nil
	end
	-- Refresh the tag-aim target for this exact moment (the same call the game makes
	-- every 0.2s); pcall'd because we are outside the normal update flow. Then read
	-- the maintained tag-target data either way.
	pcall(targeting_extension.force_update_smart_tag_targets, targeting_extension)
	local data = targeting_extension:smart_tag_targeting_data()
	local unit = data and data.unit
	return (unit and ALIVE[unit]) and unit or nil
end

-- Self-contained psyker force-field guard. The servo-skull can't shoot through a psyker
-- force field, and the game's shooting validator never checks for one, so we refuse the
-- order ourselves when the skull->target line crosses a field. Reads the live
-- force_field_system, so it works with or without ServoSkullCommander.
--
-- The Protectorate shield is one extension with two shapes
-- (psyker_force_field_unit_extension):
--   * sphere ("dome"): a 6 m sphere around the shield unit, which also blocks an order
--     given from inside it.
--   * flat wall: 11 m wide and 3.5 m tall, standing on the shield unit and facing its
--     forward axis. The extension models it as 7 points spread along the width, the
--     outermost at 0.9 of the half width, each hit-tested against a radius.
-- We no longer ask the extension whether sampled points along the line collide: that
-- needs a ~1 m probe radius to catch the wall at all (its points sit ~1.65 m apart, so a
-- small probe slips between them), and the same radius inflates every shield by a metre -
-- which is what made the safe gap around a wall or dome far too wide, refusing orders at
-- targets the skull could have shot past the edge. Instead we intersect the skull->target
-- segment with the real shapes, so a block starts at the shield surface itself.
local FF_SPHERE_RADIUS = 6
local FF_WALL_HEIGHT = 3.5
-- The outermost wall points sit at 0.9 of the 5.5 m half width, so the surface reaches
-- 0.55 m further out on each side.
local FF_WALL_END_EXTENSION = 0.55
-- Wall collision points, ordered along the width instead of by index.
local FF_WALL_POINT_ORDER = { 4, 3, 2, 1, 5, 6, 7 }
-- Probe radii for the fallbacks: a force field whose shape we don't know, and a game
-- update that took the extension map away.
local FF_UNKNOWN_PROBE_RADIUS = 0.5
local FF_SYSTEM_PROBE_RADIUS = 1

-- Vector3 components as plain numbers. All the geometry below is done on numbers: the
-- mod sandbox can hand back boxed userdata that Vector3 arithmetic refuses, and building
-- vectors per probe was also needed because is_unit_colliding rewrites their z.
local function vector_xyz(v)
	if not v then
		return nil
	end
	local ok, x, y, z = pcall(function()
		return v.x, v.y, v.z
	end)
	if ok and type(x) == "number" and type(y) == "number" and type(z) == "number" then
		return x, y, z
	end
	return nil
end

local function boxed_xyz(box)
	if not box or not box.unbox then
		return nil
	end
	local ok, v = pcall(box.unbox, box)
	if not ok then
		return nil
	end
	return vector_xyz(v)
end

local function force_field_xyz(extension)
	local x, y, z = boxed_xyz(extension._position)
	if x then
		return x, y, z
	end
	local ok, unit = pcall(extension.force_field_unit, extension)
	if ok and unit and ALIVE[unit] then
		return vector_xyz(Unit.world_position(unit, 1))
	end
	return nil
end

local function point_inside_sphere(px, py, pz, cx, cy, cz, radius_sq)
	local dx, dy, dz = px - cx, py - cy, pz - cz
	return dx * dx + dy * dy + dz * dz < radius_sq
end

-- True when the dome touches the line at all: either end standing inside it counts, on top
-- of the line crossing its surface. An order given from inside a dome is refused even when
-- the target is inside it too - the skull will not deliver that shot, and the order costs
-- ability charge either way. (Treating the inside of a dome as clear was what let an order
-- from within one burn a charge for nothing; the point-sampling check this replaced never
-- allowed it, because the game's own sphere test reports every interior point as colliding.)
local function sphere_blocks_segment(ax, ay, az, bx, by, bz, cx, cy, cz, radius)
	local radius_sq = radius * radius

	if point_inside_sphere(ax, ay, az, cx, cy, cz, radius_sq)
		or point_inside_sphere(bx, by, bz, cx, cy, cz, radius_sq)
	then
		return true
	end

	-- Both ends outside: blocked only where the segment actually reaches the sphere.
	local dx, dy, dz = bx - ax, by - ay, bz - az
	local length_sq = dx * dx + dy * dy + dz * dz
	if length_sq < 0.000001 then
		return false
	end
	local adx, ady, adz = ax - cx, ay - cy, az - cz
	local t = -(adx * dx + ady * dy + adz * dz) / length_sq
	if t <= 0 or t >= 1 then
		return false
	end
	local px, py, pz = adx + dx * t, ady + dy * t, adz + dz * t
	return px * px + py * py + pz * pz < radius_sq
end

-- Move an outer footprint point further out (or, with a negative distance, pull it in)
-- along the line to its neighbour.
local function stretch_footprint_end(point, neighbour, distance)
	local dx, dy = point[1] - neighbour[1], point[2] - neighbour[2]
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 0.000001 then
		return
	end
	point[1] = point[1] + dx / length * distance
	point[2] = point[2] + dy / length * distance
end

-- The wall's footprint as a top-down polyline, widened to the real edges of the wall
-- less the tolerance the player allows for shooting past that edge.
local function force_field_wall_footprint(extension, tolerance)
	local points = extension._points
	if not points then
		return nil
	end

	local footprint = {}
	for ii = 1, #FF_WALL_POINT_ORDER do
		local x, y = boxed_xyz(points[FF_WALL_POINT_ORDER[ii]])
		if not x then
			return nil
		end
		footprint[ii] = { x, y }
	end

	local count = #footprint
	if count < 2 then
		return nil
	end

	local reach = FF_WALL_END_EXTENSION - tolerance
	stretch_footprint_end(footprint[1], footprint[2], reach)
	stretch_footprint_end(footprint[count], footprint[count - 1], reach)

	return footprint
end

-- True when the segment crosses the wall: a top-down crossing of its footprint, at a
-- height the wall covers. The wall stands on its unit, so a line that passes below its
-- base or over its top is clear - same as the game's own height handling.
local function segment_crosses_wall(ax, ay, az, bx, by, bz, footprint, z_bottom, z_top)
	local rx, ry = bx - ax, by - ay

	for ii = 1, #footprint - 1 do
		local p = footprint[ii]
		local q = footprint[ii + 1]
		local sx, sy = q[1] - p[1], q[2] - p[2]
		local denominator = rx * sy - ry * sx

		if denominator < -0.000001 or denominator > 0.000001 then
			local dx, dy = p[1] - ax, p[2] - ay
			local t = (dx * sy - dy * sx) / denominator
			local u = (dx * ry - dy * rx) / denominator

			if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
				local z = az + (bz - az) * t
				if z_bottom < z and z < z_top then
					return true
				end
			end
		end
	end

	return false
end

-- Fallback for anything we have no geometry for: its own collision test, sampled along
-- the segment. Each probe gets a fresh Vector3 because the test rewrites the vector's z.
local function probe_blocks_line(collision_fn, owner, radius, ax, ay, az, bx, by, bz)
	if not collision_fn then
		return false
	end

	local dx, dy, dz = bx - ax, by - ay, bz - az
	local length = math.sqrt(dx * dx + dy * dy + dz * dz)
	local steps = math.min(120, math.max(4, math.ceil(length / 0.5)))

	for ii = 0, steps do
		local t = ii / steps
		if collision_fn(owner, Vector3(ax + dx * t, ay + dy * t, az + dz * t), radius, true) then
			return true
		end
	end

	return false
end

-- Name of the shape that blocks the line, or nil when this force field is clear.
local function force_field_blocks_line(extension, tolerance, ax, ay, az, bx, by, bz)
	-- Recognised by its own fields: the Skitarii personal shield shares this system but
	-- collides with nothing at all, and must never block an order.
	if not extension._points or not extension._position then
		if probe_blocks_line(
			extension.is_unit_colliding, extension, FF_UNKNOWN_PROBE_RADIUS, ax, ay, az, bx, by, bz
		) then
			return "force field"
		end
		return nil
	end

	local ok, is_sphere = pcall(extension.is_sphere_shield, extension)
	if ok and is_sphere then
		local cx, cy, cz = force_field_xyz(extension)
		if not cx then
			return nil
		end
		local radius = math.max(0.1, FF_SPHERE_RADIUS - tolerance)
		if sphere_blocks_segment(ax, ay, az, bx, by, bz, cx, cy, cz, radius) then
			return "psyker dome"
		end
		return nil
	end

	local footprint = force_field_wall_footprint(extension, tolerance)
	if not footprint then
		return nil
	end
	local _, _, wall_z = force_field_xyz(extension)
	if not wall_z then
		return nil
	end
	local height = math.max(0.1, FF_WALL_HEIGHT - tolerance)
	if segment_crosses_wall(ax, ay, az, bx, by, bz, footprint, wall_z, wall_z + height) then
		return "psyker wall"
	end
	return nil
end

local function ff_blocks_line(ax, ay, az, bx, by, bz)
	local extension_manager = Managers.state and Managers.state.extension
	local force_field_system = extension_manager and extension_manager:system("force_field_system")
	if not force_field_system then
		return nil
	end

	local tolerance = mod:get("order_edge_tolerance") or 0
	local extensions = force_field_system._unit_to_extension_map

	if not extensions then
		-- No extension map to walk: fall back to the system's own point test, which needs
		-- the coarse probe radius (and brings back its over-wide safe gap).
		if probe_blocks_line(
			force_field_system.is_object_inside_force_field,
			force_field_system,
			FF_SYSTEM_PROBE_RADIUS,
			ax, ay, az, bx, by, bz
		) then
			return "force field"
		end
		return nil
	end

	for _, extension in pairs(extensions) do
		-- A popped shield lingers as an extension for a couple of seconds with its
		-- collision actor already destroyed; it must not keep blocking orders.
		if not extension.is_expired then
			local blocked_by = force_field_blocks_line(extension, tolerance, ax, ay, az, bx, by, bz)
			if blocked_by then
				return blocked_by
			end
		end
	end

	return nil
end

-- Veteran smoke guard. smoke_fog_system:check_fog_los reports whether the skull->target
-- line crosses a smoke cloud (or the skull itself stands in one - count_standing_in_smoke).
-- Caveat: only the session host holds the full SmokeFogExtension; a remote client gets a
-- husk with no line-of-sight data, so there this quietly reports "clear" (fail-open). This
-- mirrors ServoSkullCommander's own smoke check.
local function smoke_blocks_line(from, to, skull)
	local extension_manager = Managers.state and Managers.state.extension
	local sfs = extension_manager and extension_manager:system("smoke_fog_system")
	if not sfs or not sfs.check_fog_los then
		return false
	end
	local ok, blocked = pcall(sfs.check_fog_los, sfs, from, to, skull, true)
	return ok and blocked or false
end

-- Reason the order is refused, or nil when the line is clear:
--   "psyker dome" / "psyker wall" - a psyker force field of either shape
--   "smoke"                      - a veteran smoke cloud
-- Each guard honours its own toggle; with both off this is always nil.
local function order_block_reason(player_unit, companion_spawner_extension, target_unit)
	if not (target_unit and ALIVE[target_unit]) then
		return nil
	end

	local check_shield = mod:get("order_block_dome")
	local check_smoke = mod:get("order_block_smoke")
	if not check_shield and not check_smoke then
		return nil
	end

	-- Positions via Unit.world_position: it returns a genuine Vector3. POSITION_LOOKUP
	-- can hand back a boxed userdata in the mod sandbox that Vector3 arithmetic rejects
	-- (that also makes ServoSkullCommander's own checks silently fail inside their pcall).
	-- The shot comes from the skull, so trace from the skull; fall back to the player.
	local from
	local skull = companion_spawner_extension and companion_spawner_extension:companion_units()[1]
	if skull and ALIVE[skull] then
		from = Unit.world_position(skull, 1)
	elseif ALIVE[player_unit] then
		from = Unit.world_position(player_unit, 1)
	end
	if not from then
		return nil
	end

	local target_position = Unit.world_position(target_unit, 1)
	if not target_position then
		return nil
	end

	-- Wrap the whole thing so a guard error can never crash the keybind - at worst the
	-- obstacle is not detected this press.
	local ok, reason = pcall(function()
		local fx, fy, fz = vector_xyz(from)
		local tx, ty, tz = vector_xyz(target_position)
		if not fx or not tx then
			return nil
		end
		-- Aim at the chest rather than the feet, like the skull does.
		local aim_z = tz + 1.3

		if check_shield then
			local blocked_by = ff_blocks_line(fx, fy, fz, tx, ty, aim_z)
			if blocked_by then
				return blocked_by
			end
		end
		if check_smoke
			and smoke_blocks_line(Vector3(fx, fy, fz), Vector3(tx, ty, aim_z), skull)
		then
			return "smoke"
		end
		return nil
	end)
	return ok and reason or nil
end

local function send_contextual_order(player_unit, smart_tag_system, target_unit)
	smart_tag_system:set_contextual_unit_tag(player_unit, target_unit, "companion_order")
end

local function send_interaction_order(player_unit, smart_tag_system, tag_id, target_unit)
	smart_tag_system:trigger_tag_interaction(tag_id, player_unit, target_unit, "companion_order")
end

mod.order_skull_target = function()
	-- Skitarii-only, same as the rest of the mod.
	if not is_skitarii() then
		order_debug("skipped: not playing the Skitarii class")
		return
	end

	local player = Managers.player and Managers.player:local_player_safe(1)
	local player_unit = player and player.player_unit
	if not player_unit or not ALIVE[player_unit] then
		order_debug("skipped: no living player unit")
		return
	end

	-- Re-press cooldown so holding/mashing the key can't fire orders every frame.
	-- The timer is stamped only once we actually issue an order (a press with no
	-- valid target below returns before that), so a wasted press never blocks.
	local now = gameplay_time()
	local cooldown = mod:get("order_cooldown") or 0.3
	if now and mod._last_order_send_t then
		local since_last = now - mod._last_order_send_t
		-- since_last < 0 means the "gameplay" clock ran backwards: Managers.time rebuilds
		-- that timer for every mission (it restarts near 0), but mod._last_order_send_t
		-- lives on the persistent mod table and carries over from the previous mission.
		-- Left unhandled, the stale (large) stamp made every press read as on-cooldown for
		-- the rest of the session, so the order key worked only in the first mission after a
		-- game launch. A backwards clock is a new mission, not a cooldown: drop the stamp.
		if since_last < 0 then
			mod._last_order_send_t = nil
		elseif since_last < cooldown then
			order_debug("skipped: on cooldown (%.1fs)", cooldown)
			return
		end
	end

	-- The game's own gate: companion present and its breed accepts tag orders.
	local companion_spawner_extension = ScriptUnit.has_extension(player_unit, "companion_spawner_system")
	local can_tag_order = companion_spawner_extension and companion_spawner_extension:companion_can_tag_order()
	if not can_tag_order then
		order_debug("skipped: no servo-skull that can take orders")
		return
	end

	local target_unit = aimed_tag_target(player_unit)
	if not target_unit then
		order_debug("skipped: no enemy under the crosshair")
		return
	end

	local extension_manager = Managers.state and Managers.state.extension
	local smart_tag_system = extension_manager and extension_manager:system("smart_tag_system")
	if not smart_tag_system then
		order_debug("skipped: no smart_tag_system")
		return
	end

	local tag_id = smart_tag_system:unit_tag_id(target_unit)
	local tag = smart_tag_system:unit_tag(target_unit)
	local tag_template = tag and tag:template()
	local companion_tag = tag_template and tag_template.companion_order
	local we_already_tagged = tag and tag:tagger_player() == player
	local other_already_tagged = tag and not we_already_tagged

	-- Obstacle guard. The skull can't shoot through a psyker force field (sphere dome or
	-- flat wall) or a veteran smoke cloud, so refuse the order. If an obstacle now blocks
	-- a target we ourselves already ordered, cancel that order: the game keeps re-validating
	-- an existing companion tag for up to 25s WITHOUT any of these checks, so just declining
	-- to re-issue wouldn't stop a prior order.
	local block_reason = order_block_reason(player_unit, companion_spawner_extension, target_unit)
	if block_reason then
		if we_already_tagged then
			smart_tag_system:cancel_tag(tag_id, player_unit)
			order_debug("blocked by %s; cancelled your existing order", block_reason)
		else
			order_debug("blocked by %s", block_reason)
		end
		return
	end

	if we_already_tagged then
		send_interaction_order(player_unit, smart_tag_system, tag_id, target_unit)
	elseif other_already_tagged then
		if companion_tag then
			send_contextual_order(player_unit, smart_tag_system, target_unit)
		else
			send_interaction_order(player_unit, smart_tag_system, tag_id, target_unit)
		end
	else
		send_contextual_order(player_unit, smart_tag_system, target_unit)
	end

	order_debug("order sent")

	if now then
		mod._last_order_send_t = now
	end
end
