

---@param Module DLH_ModMenu
---@param mod DL_Mod
return function(Module, mod)
	if Module.hud_definitions then
		return Module.hud_definitions
	end

	local build, make, passes, scene, insert, screen =
		mod.dl.defs.build,
		mod.dl.defs.make,
		mod.dl.defs.passes,
		mod.dl.defs.scene,
		mod.dl.defs.insert,
		mod.dl.defs.screen
	local text, texture, texture_rot, rect = passes.text, passes.texture, passes.rotated_texture, passes.rect

	local lines, join = mod.dl.loc_helpers.lines, mod.dl.str.join

	local uv = mod.dl.uv

	local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

	local C = Module.constants
	local Presentation = Module.presentation

	local SCREEN_SIZE = UIWorkspaceSettings.screen.size

	---@param c argb_table
	local function argb(c)
		return { c[1], c[2], c[3], c[4] }
	end

	local function nav_heading_text()
		local text = mod:localize("mod_menu_title")
		if not text or text == "<mod_menu_title>" then
			return string.upper(mod:get_name())
		end
		return text
	end

	local ModMenuHudDefinitions = {
		scenegraph_definition = {},
		widget_definitions = {},
	}

	insert(ModMenuHudDefinitions, screen())

	insert(
		ModMenuHudDefinitions,
		make(
			"backdrop",
			scene:align("center", "center"):sizes(SCREEN_SIZE[1], SCREEN_SIZE[2]):at(0, 0, C.Z.BACKDROP),

			rect:color(C.COLOR.BACKDROP),

			texture
				:material(C.MATERIAL.shadow)
				:anchor("center", "left")
				:at(-132, 0)
				:sizes(C.NAV_WIDTH * 1.5, SCREEN_SIZE[2] * 2)
				:color(Color.black(75, true)),

			texture
				:material(C.MATERIAL.shadow)
				:anchor("center", "right")
				:at(110, 0)
				:sizes(C.ASIDE_WIDTH * 1.5, SCREEN_SIZE[2] * 2)
				:color(Color.black(75, true))
		)
	)

	local cog_pass = function(side, pass)
		return make(
			"chain_cog_" .. side,
			scene:align("center", "center"):sizes(SCREEN_SIZE[1], SCREEN_SIZE[2]):at(0, 0, C.Z.BACKDROP_COG),
			pass
		)
	end

	insert(
		ModMenuHudDefinitions,
		cog_pass(
			"tl",
			texture
				:material(C.MATERIAL.chain_cog)
				:anchor("top", "left")
				:at(C.NAV_WIDTH, -75)
				:sizes(40, 180)
				:uvs(uv.flip_y_of(uv.clip_right(0.17)))
		)
	)

	insert(
		ModMenuHudDefinitions,
		cog_pass(
			"tr",
			texture
				:material(C.MATERIAL.chain_cog)
				:anchor("top", "right")
				:at(-C.ASIDE_WIDTH, -75)
				:sizes(40, 180)
				:uvs(uv.flip_xy_of(uv.clip_right(0.17)))
		)
	)

	insert(
		ModMenuHudDefinitions,
		cog_pass(
			"bl",
			texture
				:material(C.MATERIAL.chain_cog)
				:anchor("bottom", "left")
				:at(C.NAV_WIDTH, 75)
				:sizes(40, 180)
				:uvs(uv.clip_right(0.17))
		)
	)

	insert(
		ModMenuHudDefinitions,
		cog_pass(
			"br",
			texture
				:material(C.MATERIAL.chain_cog)
				:anchor("bottom", "right")
				:at(-C.ASIDE_WIDTH, 62)
				:sizes(40, 180)
				:uvs(uv.flip_xy_of(uv.clip_right(0.17)))
		)
	)

	---@param id string scenegraph id (must match a SLIDE_NODES entry)
	---@param z number render layer for the node
	---@param pass DL_DefsPass the single decoration pass, anchored as before within the node
	local function slide_node(id, z, pass)
		return make(id, scene:align("center", "center"):sizes(SCREEN_SIZE[1], SCREEN_SIZE[2]):at(0, 0, z), pass)
	end

	insert(
		ModMenuHudDefinitions,
		slide_node(
			"panel_chain_left",
			C.Z.BACKDROP_CHAIN,
			texture
				:id("panel_chain_left")
				:material(C.MATERIAL.double_chain)
				:anchor("center", "left")
				:at(-12, 0)
				:sizes(400, SCREEN_SIZE[2] * 3)
		)
	)
	insert(
		ModMenuHudDefinitions,
		slide_node(
			"panel_chain_right",
			C.Z.BACKDROP_CHAIN,
			texture
				:id("panel_chain_right")
				:material(C.MATERIAL.double_chain)
				:anchor("center", "right")
				:at(71, 0)
				:sizes(400, SCREEN_SIZE[2] * 3)
		)
	)

	insert(
		ModMenuHudDefinitions,
		slide_node(
			"chain_connector_frame_left",
			C.Z.BACKDROP_FRAME,
			texture
				:id("chain_connector_frame_left")
				:material(C.MATERIAL.divider_x)
				:anchor("center", "left")
				:at(C.NAV_WIDTH + 20, 0)
				:sizes(30, 54)
				:uvs(uv.flip_x_of(uv.clip_right(0.75)))
				:color({ 255, 255, 230, 230 })
		)
	)
	insert(
		ModMenuHudDefinitions,
		slide_node(
			"chain_connector_frame_right",
			C.Z.BACKDROP_FRAME,
			texture
				:id("chain_connector_frame_right")
				:material(C.MATERIAL.divider_x)
				:anchor("center", "right")
				:at(-C.NAV_WIDTH + 40, 0, 1)
				:sizes(30, 54)
				:uvs(uv.clip_right(0.75))
				:color({ 255, 255, 230, 230 })
		)
	)

	insert(
		ModMenuHudDefinitions,
		make(
			"panel",
			scene
				:align("center", "center")
				:sizes(C.PANEL_WIDTH, C.PANEL_HEIGHT)
				:at(C.PANEL_OFFSET_X, C.PANEL_OFFSET_Y, C.Z.PANEL),

			texture
				:material(C.MATERIAL.shadow)
				:anchor("center", "center")
				:at(14, 0)
				:size_addition(38, 70)
				:color(Color.black(100, true)),

			rect:anchor("center", "center")
				:sizes(C.PANEL_WIDTH - 20, C.PANEL_HEIGHT - 20)
				:color(argb(C.COLOR.CONTENT_PANEL_BG)),

			texture:material(C.MATERIAL.terminal_basic):anchor("center", "center"):color(argb(C.COLOR.CONTENT_PANEL)),

			texture
				:material(C.MATERIAL.headline_terminal)
				:anchor("top", "center")
				:at(0, 13)
				:sizes(C.PANEL_WIDTH - 28, 54)
				:color(Color.terminal_grid_background(120, true)),

			text:id("title")
				:align("center", "center")
				:font(C.FONTS.title)
				:size(C.FONT_SIZE.content_title)
				:sizes(C.PANEL_WIDTH, C.TITLE_HEIGHT)
				:at(0, 0)
				:color(argb(C.COLOR.CONTENT_TITLE))
		)
	)

	insert(
		ModMenuHudDefinitions,
		slide_node(
			"panel_frame_left",
			C.Z.PANEL_FRAME,
			texture_rot
				:id("panel_frame_left")
				:material(C.MATERIAL.divider)
				:anchor("center", "left")
				:at(-105, 0)
				:sizes(C.PANEL_HEIGHT - 10, 45)
				:angle(1.5711)
				:color({ 255, 200, 185, 185 })
		)
	)
	insert(
		ModMenuHudDefinitions,
		slide_node(
			"panel_frame_right",
			C.Z.PANEL_FRAME,
			texture_rot
				:id("panel_frame_right")
				:material(C.MATERIAL.divider)
				:anchor("center", "right")
				:at(165, 0)
				:sizes(C.PANEL_HEIGHT - 10, 45)
				:angle(-1.5711)
				:color({ 255, 200, 185, 185 })
		)
	)

	local function heading_bg_passes(base_width, base_height)
		return {

			texture
				:material(C.MATERIAL.shadow)
				:sizes(base_width + 28, base_height * 2.3)
				:anchor("top", "center")
				:at(0, 36)
				:color(Color.black(100, true)),

			texture
				:material(C.MATERIAL.terminal_wobbly)
				:sizes(base_width - 70, base_height)
				:anchor("top", "center")
				:at(0, 84)
				:color({ 75, 20, 24, 20 }),

			texture
				:material(C.MATERIAL.terminal_wobbly)
				:sizes(base_width - 70, base_height)
				:anchor("top", "center")
				:at(0, 84)
				:uvs(uv.flip_xy())
				:color({ 75, 20, 24, 20 }),
		}
	end

	local function side_passes(align)
		align = (align == "right" and "right") or "left"
		local width = align == "left" and C.NAV_WIDTH or C.ASIDE_WIDTH
		return {

			texture:material(C.MATERIAL.panel):color(align == "left" and C.COLOR.PANEL or C.COLOR.ASIDE_PANEL),

			texture
				:material(C.MATERIAL.frame_bottom_2)
				:sizes(410, 430)
				:at(0, 75)
				:anchor("bottom", align)
				:uvs(align == "right" and uv.flip_x() or uv.none())
				:color(Color.white(200, true)),

			texture
				:material(C.MATERIAL.gradient_to_t)
				:sizes(width, 20)
				:at(0, 45)
				:anchor("top", "center")
				:uvs(uv.flip_y())
				:color(Color.black(255, true)),

			texture
				:material(C.MATERIAL.frame_top_under)
				:sizes(800, 56)
				:at(0, -3)
				:anchor("top", align == "left" and "right" or "left")
				:color(Color.white(255, true)),

			texture
				:material(C.MATERIAL.gradient_to_t)
				:sizes(width, 150)
				:at(0, 25)
				:anchor("bottom", align)
				:color(Color.black(255, true)),

			texture
				:material(C.MATERIAL.gradient_to_r)
				:sizes(width / 3, SCREEN_SIZE[2])
				:at(align == "left" and -50 or 50, 0)
				:anchor("center", align)
				:uvs(align == "left" and uv.flip_xy() or uv.none())
				:color(Color.black(150, true)),

			texture
				:material(C.MATERIAL.mechanicus_star)
				:sizes(width * 1.9, width * 1.9)
				:anchor("center", align == "left" and "right" or "left")
				:at(0, 50)
				:uvs(uv.clip_left(0.675))
				:ignore_if(align == "right")
				:color(Color.white(150, true)),

			texture
				:material(C.MATERIAL.smoke_gradient_to_tl)
				:sizes(width, 600)
				:at(0, 0)
				:anchor("bottom", align)
				:uvs(align == "left" and uv.flip_x() or uv.none())
				:color({ 255, 150, 150, 150 }),

			texture
				:material(C.MATERIAL.frame_bottom)
				:sizes(175, 260)
				:anchor("bottom", align)
				:uvs(align == "right" and uv.flip_x() or uv.none()),

			texture
				:material(C.MATERIAL.frame_top)
				:sizes(width - 40, 200)
				:anchor("top", "left")
				:at(-30, -52)
				:uvs(uv.clip_top(0.4))
				:ignore_if(align == "right"),

			texture
				:material(C.MATERIAL.frame_top_curved)
				:sizes(width - 60, 260)
				:anchor("top", "right")
				:at(55, -10)
				:uvs(uv.flip_x_of(uv.clip_top(0.7)))
				:ignore_if(align == "left"),

			texture
				:material(C.MATERIAL.scrollbar)
				:sizes(6, SCREEN_SIZE[2] + 20)
				:anchor("center", align == "left" and "right" or "left")
				:at(3 * (align == "right" and -1 or 1), 0)
				:color({ 230, 110, 105, 105 }),
		}
	end

	insert(
		ModMenuHudDefinitions,
		make(
			"nav_panel",
			scene:align("center", "left"):at(0, 0, C.Z.SIDE):sizes(C.NAV_WIDTH, SCREEN_SIZE[2]),
			function()
				return side_passes("left")
			end,

			function()
				return heading_bg_passes(C.NAV_WIDTH, 74)
			end,

			texture
				:material(C.MATERIAL.frame_top_simple)
				:sizes(C.NAV_WIDTH - 60, 26)
				:anchor("top", "center")
				:at(0, 74)
				:color(Color.white(255, true)),

			texture
				:material(C.MATERIAL.divider_skull)
				:sizes(C.NAV_WIDTH - 50, 40)
				:anchor("top", "center")
				:at(0, 146)
				:color(Color.white(255, true)),

			text:id("nav_heading")
				:size(C.FONT_SIZE.nav_heading)
				:at(0, 104)
				:align("top", "center")
				:color(C.COLOR.NAV_HEADING)
				:val(nav_heading_text())
				:z(10)
				:font(C.FONTS.title),

			texture
				:id("secret_btn_icon")
				:material(C.MATERIAL.secret_icon)
				:sizes(60, 60)
				:at(0, 60)
				:anchor("center", "center")
				:color({ 255, 121, 118, 113 }),

			function()
				local passes = {}
				for i = 1, C.MAX_MODULE_BUTTONS do
					local br = Presentation.nav_button_local(i)

					passes[#passes + 1] = texture
						:id("module_btn_backdrop_" .. i)
						:material(C.MATERIAL.shadow)
						:sizes(br.w + 30, br.h + 45)
						:at(br.x - 16, br.y - 27)
						:color(Color.black(100, true))

					passes[#passes + 1] = texture
						:id("module_btn_selected_" .. i)
						:material(C.MATERIAL.button_selected_edge)
						:sizes(br.w / 1.5, br.h / 2.5)
						:at(br.x + (br.w / 5.5), br.y + (br.h / 4))
						:color({ 60, 200, 255, 200 })

					passes[#passes + 1] = texture
						:id("module_btn_frame_" .. i)
						:material(C.MATERIAL.button_idle)
						:sizes(br.w, br.h)
						:at(br.x, br.y)

					passes[#passes + 1] = text:id("module_btn_" .. i)
						:sizes(br.w, br.h - 6)
						:at(br.x, br.y - 2, 1)
						:color(C.COLOR.MODULE_BTN_TEXT)
						:align("center", "center")
						:size(C.FONT_SIZE.module_button)
						:font(C.FONTS.heading)
				end
				return passes
			end,

			text:size(C.FONT_SIZE.info)
				:font("mono_tide_medium")
				:align("bottom", "right")
				:at(-8, -4)
				:color(Color.gray(75, true))
				:z(10)
				:val(
					lines(
						join(" ", mod:localize("version"), mod:localize("mod_version")),
						join(": ", mod:localize("author"), "malevhf")
					)
				)
		)
	)

	insert(
		ModMenuHudDefinitions,
		make(
			"aside_panel",
			scene:align("center", "right"):at(0, 0, C.Z.SIDE):sizes(C.ASIDE_WIDTH, SCREEN_SIZE[2]),
			function()
				return side_passes("right")
			end,
			function()
				local passes = {}
				for i = 1, C.MAX_ASIDE_ROWS do
					local rr = Presentation.aside_row_local(i)

					passes[#passes + 1] = text:id("aside_label_" .. i)
						:at(rr.x, rr.y)
						:sizes(rr.w, rr.h)
						:font(C.FONTS.aside_label)
						:size(C.FONT_SIZE.aside_label)
						:align("center", "left")
						:color(C.COLOR.ASIDE_LABEL)
					passes[#passes + 1] = text:id("aside_value_" .. i)
						:at(rr.x, rr.y)
						:sizes(rr.w, rr.h)
						:font(C.FONTS.aside_value)
						:align("center", "right")
						:size(C.FONT_SIZE.aside_value)
						:color(C.COLOR.ASIDE_VALUE)

					passes[#passes + 1] = text:id("aside_heading_" .. i)
						:at(rr.x, rr.y)
						:sizes(rr.w, rr.h)
						:font(C.FONTS.aside_label)
						:size(C.FONT_SIZE.aside_heading)
						:align("center", "left")
						:color(C.COLOR.ASIDE_HEADING)

					passes[#passes + 1] = text:id("aside_heading_r_" .. i)
						:at(rr.x, rr.y)
						:sizes(rr.w, rr.h)
						:font(C.FONTS.aside_label)
						:size(C.FONT_SIZE.aside_heading)
						:align("center", "right")
						:color(C.COLOR.ASIDE_HEADING)
				end
				return passes
			end
		)
	)

	Module.hud_definitions = ModMenuHudDefinitions

	return ModMenuHudDefinitions
end
