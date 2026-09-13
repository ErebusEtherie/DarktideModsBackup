

---@param Module DLH_SettingsMenu
---@param mod DL_Mod
return function(Module, mod)
	if Module.passes then
		return Module.passes
	end

	local C = Module.constants
	local Layout = Module.layout_manager

	local Passes = {}

	local FONT = {
		title = mod.dl.fonts.validated("machine_medium", "proxima_nova_bold"),
		tab = mod.dl.fonts.validated("proxima_nova_bold"),
		label = mod.dl.fonts.validated("proxima_nova_bold"),
		value = mod.dl.fonts.validated("proxima_nova_bold", "proxima_nova_medium"),
		numeric_value = mod.dl.fonts.validated("mono_tide_medium", "proxima_nova_medium"),
		button = mod.dl.fonts.validated("mono_tide_bold", "proxima_nova_medium"),

		clear = mod.dl.fonts.validated("proxima_nova_medium", "proxima_nova_medium"),
	}
	Passes.font = FONT

	local function argb(c)
		return { c[1], c[2], c[3], c[4] }
	end

	local function placed(rect, z)
		return {
			horizontal_alignment = "left",
			vertical_alignment = "top",
			offset = { rect.x, rect.y, z },
			size = { rect.w, rect.h },
		}
	end

	---@param style_id string
	---@param rect DLH_SettingsMenuRect
	---@param color table argb
	---@param z number | nil defaults to the surface layer
	function Passes.rect(style_id, rect, color, z)
		local style = placed(rect, z or C.Z_CELL_SURFACE)
		style.color = argb(color)
		return { pass_type = "rect", style_id = style_id, style = style }
	end

	---@param style_id string
	---@param material string
	---@param rect DLH_SettingsMenuRect
	---@param color table argb
	---@param z number | nil defaults to the surface layer
	---@param scale_to_material boolean | nil keeps tiled/frame art crisp at render scale
	---@param uvs number[][] | nil mirror the material ({ {u0,v0}, {u1,v1} }, e.g. mod.dl.uv.flip_x()); switches the pass to texture_uv, which a plain texture pass ignores
	function Passes.texture(style_id, material, rect, color, z, scale_to_material, uvs)
		local style = placed(rect, z or C.Z_CELL_SURFACE)
		style.color = argb(color)
		style.scale_to_material = scale_to_material or false
		if uvs then
			style.uvs = uvs
			return { pass_type = "texture_uv", style_id = style_id, value = material, style = style }
		end
		return { pass_type = "texture", style_id = style_id, value = material, style = style }
	end

	---@class DLH_SettingsMenuTextOpts
	---@field font string | nil defaults to the label face
	---@field font_size number
	---@field color table argb
	---@field align_h "left" | "center" | "right" | nil defaults to left
	---@field align_v "top" | "center" | "bottom" | nil defaults to center
	---@field z number | nil defaults to the text layer
	---@field value_id string | nil wires the pass so the element can rewrite the text

	---@param style_id string
	---@param rect DLH_SettingsMenuRect
	---@param text string | nil
	---@param opts DLH_SettingsMenuTextOpts
	function Passes.text(style_id, rect, text, opts)
		local style = placed(rect, opts.z or C.Z_CELL_TEXT)
		style.font_type = opts.font or FONT.label
		style.font_size = opts.font_size
		style.text_horizontal_alignment = opts.align_h or "left"
		style.text_vertical_alignment = opts.align_v or "center"
		style.text_color = argb(opts.color)
		return {
			pass_type = "text",
			style_id = style_id,
			value = text or "",
			value_id = opts.value_id,
			style = style,
		}
	end

	---@class DLH_SettingsMenuNodePassOpts
	---@field pass_type string | nil defaults to texture
	---@field z number | nil
	---@field color table | nil
	---@field scale_to_material boolean | nil
	---@field align_h string | nil
	---@field align_v string | nil

	---@param style_id string
	---@param value string | nil material path (nil for a plain rect)
	---@param opts DLH_SettingsMenuNodePassOpts | nil
	function Passes.node_pass(style_id, value, opts)
		opts = opts or {}
		local style = { offset = { 0, 0, opts.z or 0 } }
		if opts.color then
			style.color = argb(opts.color)
		end
		if opts.scale_to_material then
			style.scale_to_material = true
		end
		style.horizontal_alignment = opts.align_h
		style.vertical_alignment = opts.align_v
		return {
			pass_type = opts.pass_type or "texture",
			style_id = style_id,
			value = value,
			style = style,
		}
	end

	local function chain(...)
		local out = {}
		for i = 1, select("#", ...) do
			local item = select(i, ...)
			if item then
				if item.pass_type then
					out[#out + 1] = item
				else
					for j = 1, #item do
						out[#out + 1] = item[j]
					end
				end
			end
		end
		return out
	end

	local function shadow(style_id, rect)
		local pad = C.SHADOW_PAD
		local grown = { x = rect.x - pad, y = rect.y - pad, w = rect.w + pad * 2, h = rect.h + pad * 2 }
		return Passes.texture(
			style_id .. "_shadow",
			"content/ui/materials/frames/dropshadow_medium",
			grown,
			C.COLOR.SHADOW,
			C.Z_CELL_SHADOW,
			true
		)
	end

	local function surface(style_id, rect)
		return { shadow(style_id, rect), Passes.rect(style_id, rect, C.COLOR.CONTROL) }
	end

	local function row_frame(row)
		return {
			Passes.texture(
				"terminal",
				"content/ui/materials/gradients/gradient_horizontal",
				row,
				Color.terminal_grid_background(100, true),
				C.Z_CELL_SHADOW
			),
			Passes.texture(
				"border",
				"content/ui/materials/frames/frame_tile_2px",
				row,
				Color.terminal_corner(50, true)
			),
			Passes.texture(
				"border_corner",
				"content/ui/materials/frames/frame_corner_2px",
				row,
				Color.terminal_corner(100, true)
			),
		}
	end

	local function label(rect, widget)
		return Passes.text("label", rect, mod:localize(widget.label_key), {
			font_size = C.LABEL_FONT_SIZE,
			color = C.COLOR.LABEL,
			z = C.Z_CELL_SURFACE,
		})
	end

	local function reset_icon(rect)
		return Passes.texture("reset", C.RESET_ICON_MATERIAL, rect, C.COLOR.RESET_ICON, C.Z_CELL_TEXT)
	end

	local function glyph(style_id, rect, text, font)
		return Passes.text(style_id, rect, text, {
			font = font or FONT.value,
			font_size = C.BUTTON_FONT_SIZE,
			color = C.COLOR.BUTTON_TEXT,
			align_h = "center",
		})
	end

	local function live_text(style_id, rect, font)
		return Passes.text(style_id, rect, "", {
			font = font or FONT.value,
			font_size = C.VALUE_FONT_SIZE,
			color = C.COLOR.VALUE,
			align_h = "center",
			value_id = style_id,
		})
	end

	---@param widget table schema entry
	---@param cell_w number
	function Passes.numeric(widget, cell_w)
		local parts = Layout.numeric_parts(cell_w)
		return chain(
			widget.label_key and label(parts.label, widget),
			reset_icon(parts.reset),
			surface("minus", parts.minus),
			row_frame(parts.row),
			glyph("minus_txt", parts.minus, "-"),
			surface("plus", parts.plus),
			glyph("plus_txt", parts.plus, "+"),
			surface("value_bg", parts.value),

			Passes.rect("value_fill", parts.value, C.COLOR.VALUE_FILL),
			live_text("value", parts.value, FONT.numeric_value)
		)
	end

	---@param widget table schema entry
	---@param cell_w number
	function Passes.checkbox(widget, cell_w)
		local parts = Layout.checkbox_parts(cell_w)
		return chain(
			widget.label_key and label(parts.label, widget),
			reset_icon(parts.reset),
			surface("box", parts.row),
			row_frame(parts.row),

			Passes.rect("fill", parts.fill, C.COLOR.CHECK_OFF, C.Z_CELL_TEXT),

			Passes.text("state", parts.state, "", {
				font = FONT.value,
				font_size = C.VALUE_FONT_SIZE,
				color = C.COLOR.VALUE,
				value_id = "state",
			})
		)
	end

	---@param widget table schema entry
	---@param cell_w number
	function Passes.keybind(widget, cell_w)
		local parts = Layout.keybind_parts(cell_w)
		return chain(
			widget.label_key and label(parts.label, widget),
			reset_icon(parts.reset),
			surface("box", parts.box),
			row_frame(parts.row),
			live_text("bind", parts.box),
			surface("clear", parts.clear),
			glyph("clear_txt", parts.clear, "X", FONT.clear)
		)
	end

	---@param widget table schema entry
	---@param cell_w number
	function Passes.dropdown(widget, cell_w)
		local parts = Layout.dropdown_parts(cell_w)
		return chain(
			widget.label_key and label(parts.label, widget),
			reset_icon(parts.reset),
			surface("box", parts.row),
			row_frame(parts.row),

			Passes.text("selected", parts.value, "", {
				font = FONT.value,
				font_size = C.VALUE_FONT_SIZE,
				color = C.COLOR.VALUE,
				value_id = "selected",
			}),
			surface("arrow", parts.arrow),
			glyph("arrow_txt", parts.arrow, "v", FONT.clear)
		)
	end

	---@param widget table schema entry
	---@param cell_w number
	function Passes.button(widget, cell_w)
		local parts = Layout.button_parts(cell_w, widget.label_key ~= nil)
		return chain(
			widget.label_key and label(parts.label, widget),
			surface("box", parts.row),
			row_frame(parts.row),
			Passes.text("caption", parts.caption, mod:localize(widget.text_key), {
				font = FONT.button,
				font_size = C.VALUE_FONT_SIZE,
				color = C.COLOR.BUTTON_TEXT,
				align_h = "center",
			})
		)
	end

	---@param rect DLH_SettingsMenuRect node-local ({ x = 0, y = 0, w, h })
	---@param caption string
	---@return table[]
	function Passes.reset_button(rect, caption)
		local icon = C.RESET_ICON_SIZE
		local pad = 12
		local icon_rect = { x = pad, y = (rect.h - icon) * 0.5, w = icon, h = icon }

		local text_x = pad + icon
		local text_rect = { x = text_x, y = 0, w = rect.w - text_x - pad, h = rect.h }
		return chain(
			surface("box", rect),
			row_frame(rect),
			Passes.texture("icon", C.RESET_ICON_MATERIAL, icon_rect, C.COLOR.BUTTON_TEXT, C.Z_CELL_TEXT),
			Passes.text("caption", text_rect, caption, {
				font = FONT.button,
				font_size = C.VALUE_FONT_SIZE,
				color = C.COLOR.BUTTON_TEXT,
				align_h = "center",
			})
		)
	end

	---@param rect DLH_SettingsMenuRect node-local, {0,0,w,h}
	---@param caption string
	function Passes.fancy_checkbox(rect, caption)
		local pad = 12
		local box = rect.h - 16
		local box_rect = { x = pad, y = (rect.h - box) * 0.5, w = box, h = box }
		local inset = C.CHECK_FILL_INSET
		local fill_rect = { x = box_rect.x + inset, y = box_rect.y + inset, w = box - inset * 2, h = box - inset * 2 }
		local text_x = pad + box
		local text_rect = { x = text_x, y = 0, w = rect.w - text_x - pad, h = rect.h }
		return chain(
			surface("box", rect),
			row_frame(rect),
			surface("check", box_rect),

			Passes.rect("fill", fill_rect, C.COLOR.CHECK_OFF, C.Z_CELL_TEXT),
			Passes.text("caption", text_rect, caption, {
				font = FONT.button,
				font_size = C.VALUE_FONT_SIZE,
				color = C.COLOR.BUTTON_TEXT,
				align_h = "center",
			})
		)
	end

	---@param widget table schema entry
	---@param cell_w number
	function Passes.heading(widget, cell_w)

		local has_description = widget.description_key ~= nil
		local parts = Layout.heading_parts(cell_w, has_description)
		return chain(
			Passes.text("heading", parts.heading, mod:localize(widget.label_key), {
				font_size = C.HEADING_FONT_SIZE,
				color = C.COLOR.TEXT,
				z = C.Z_CELL_SURFACE,
			}),

			Passes.rect("heading_rule", parts.rule, C.COLOR.HEADING_RULE, C.Z_CELL_SURFACE),
			has_description
				and Passes.text("description", parts.description, mod:localize(widget.description_key), {
					font_size = C.HEADING_DESCRIPTION_FONT_SIZE,
					color = C.COLOR.TEXT_MUTED,
					z = C.Z_CELL_SURFACE,
				})
		)
	end

	local BY_TYPE = {
		numeric = Passes.numeric,
		checkbox = Passes.checkbox,
		keybind = Passes.keybind,
		dropdown = Passes.dropdown,
		button = Passes.button,
		heading = Passes.heading,
	}

	---@param widget table schema entry
	---@return table[] | nil
	function Passes.for_control(widget)
		local builder = BY_TYPE[widget.type]
		if not builder then
			return nil
		end
		local cell = Layout.cell_rect(widget.col, widget.row, widget.col_span, widget.row_span)
		return builder(widget, cell.w)
	end

	---@param tab DLH_SettingsMenuTab
	---@return table[]

	function Passes.tab_header(tab)
		local parts = Layout.tab_header_parts(tab)
		return chain(tab.title_text and Passes.text("title", parts.title, tab.title_text, {
			font = FONT.tab,
			font_size = C.TAB_TITLE_FONT_SIZE,
			color = C.COLOR.TAB_TITLE,
			z = C.Z_CELL_SURFACE,
		}), tab.description_text and Passes.text("description", parts.description, tab.description_text, {
			font_size = C.TAB_DESC_FONT_SIZE,
			color = C.COLOR.TAB_DESC,
			align_v = "top",
			z = C.Z_CELL_SURFACE,
		}))
	end

	Passes.chrome = {
		tabs_bg = { Passes.node_pass("tabs_bg", nil, { pass_type = "rect", color = C.COLOR.TABS_BG }) },
	}

	---@return table[]
	function Passes.tooltip()
		return {
			{
				pass_type = "texture",
				style_id = "tooltip_shadow",
				value = "content/ui/materials/frames/dropshadow_large",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "center",
					scale_to_material = true,
					color = Color.black(150, true),
					size_addition = { 45, 45 },
					offset = { 0, 0, 1 },
				},
			},
			{
				pass_type = "rect",
				style_id = "tooltip_bg_color",
				style = {
					offset = { 10, 10, C.Z_TOOLTIP },
					size_addition = { -20, -20 },
					color = argb(C.COLOR.TOOLTIP_BG),
				},
			},
			Passes.node_pass("tooltip_terminal", "content/ui/materials/backgrounds/terminal_basic", {
				z = C.Z_TOOLTIP_BG,
				color = C.COLOR.PANEL,
				scale_to_material = true,
			}),
			{
				pass_type = "texture",
				value = "content/ui/materials/frames/item_purchase_upper",
				style = {
					scale_to_material = false,
					size = { C.TOOLTIP_WIDTH, 80 },
					vertical_alignment = "top",
					horizontal_alignment = "center",
					offset = { 0, -46, C.Z_TOOLTIP_FRAME },

					uvs = { { 0, 1 }, { 1, 1 }, { 0, 0 }, { 1, 0 } },
				},
			},
			{
				pass_type = "text",
				style_id = "title",
				value = "",
				value_id = "title",
				style = {
					font_type = FONT.label,
					font_size = C.TOOLTIP_TITLE_FONT_SIZE,
					text_horizontal_alignment = "center",
					text_vertical_alignment = "top",
					horizontal_alignment = "center",
					size = { C.TOOLTIP_WIDTH - 40, 60 },
					offset = { 0, C.TOOLTIP_TITLE_FONT_SIZE / 2 + 16, C.Z_TOOLTIP_CONTENT },
					text_color = argb(C.COLOR.TITLE),
				},
			},
			{
				pass_type = "text",
				style_id = "content",
				value = "",
				value_id = "content",
				style = {
					font_type = FONT.label,
					font_size = C.TOOLTIP_CONTENT_FONT_SIZE,
					text_horizontal_alignment = "left",
					text_vertical_alignment = "top",
					size = { C.TOOLTIP_WIDTH - 80, C.TOOLTIP_HEIGHT },
					offset = { 32, C.TOOLTIP_TITLE_FONT_SIZE * 2 + 26, C.Z_TOOLTIP_CONTENT },
					text_color = argb(C.COLOR.TITLE),
				},
			},
			{
				pass_type = "texture",
				style_id = "divider",
				value = "content/ui/materials/dividers/skull_center_02",
				style = {
					scale_to_material = false,
					size = { C.TOOLTIP_WIDTH - 22, 20 },
					vertical_alignment = "top",
					horizontal_alignment = "center",
					offset = { 0, C.TOOLTIP_CONTENT_FONT_SIZE * 2, C.Z_TOOLTIP_FRAME_BG },
				},
			},
			{
				pass_type = "texture",
				value = "content/ui/materials/frames/item_info_lower",
				style = {
					scale_to_material = false,
					size = { C.TOOLTIP_WIDTH, 26 },
					vertical_alignment = "bottom",
					horizontal_alignment = "center",
					offset = { 0, 0, C.Z_TOOLTIP_FRAME },
				},
			},
		}
	end

	---@return table[]
	function Passes.dropdown_popup()

		local ref_w = Layout.cell_rect(1, 1, 1, 1).w
		local pad = C.DROPDOWN_TEXT_PAD

		local passes = {
			{
				pass_type = "texture",
				style_id = "popup_shadow",
				value = "content/ui/materials/frames/dropshadow_medium",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "center",
					scale_to_material = true,
					color = argb(C.COLOR.SHADOW),
					size_addition = { C.SHADOW_PAD * 2, C.SHADOW_PAD * 2 },
					offset = { 0, 0, C.Z_CELL_SHADOW },
				},
			},
			Passes.node_pass("popup_bg", nil, {
				pass_type = "rect",
				z = C.Z_CELL_SHADOW,
				color = C.COLOR.DROPDOWN_BG,
			}),
			Passes.node_pass("popup_terminal", "content/ui/materials/backgrounds/terminal_basic", {
				z = C.Z_CELL_TERMINAL,
				scale_to_material = false,
				color = Color.terminal_background(255, true),
			}),
			Passes.node_pass("popup_gradient", "content/ui/materials/gradients/gradient_horizontal", {
				z = C.Z_CELL_SHADOW,
				color = Color.terminal_grid_background(100, true),
			}),
		}

		for slot = 1, C.DROPDOWN_MAX_VISIBLE do
			local rect = Layout.dropdown_option_rect(slot, ref_w)
			passes[#passes + 1] = Passes.rect("option_" .. slot, rect, C.COLOR.DROPDOWN_OPTION)
			passes[#passes + 1] = Passes.text(
				"option_text_" .. slot,
				{ x = pad, y = rect.y, w = rect.w - pad * 2, h = rect.h },
				"",
				{
					font = FONT.value,
					font_size = C.VALUE_FONT_SIZE,
					color = C.COLOR.VALUE,
					value_id = "option_" .. slot,
				}
			)
		end

		passes[#passes + 1] = Passes.node_pass("popup_border", "content/ui/materials/frames/frame_tile_2px", {
			z = C.Z_CELL_TEXT,
			color = Color.terminal_corner(50, true),
		})
		passes[#passes + 1] = Passes.node_pass("popup_border_corner", "content/ui/materials/frames/frame_corner_2px", {
			z = C.Z_CELL_TEXT,
			color = Color.terminal_corner(100, true),
		})

		passes[#passes + 1] = Passes.rect(
			"popup_thumb",
			{ x = ref_w - C.SCROLLBAR_WIDTH, y = 0, w = C.SCROLLBAR_WIDTH, h = 0 },
			C.COLOR.DROPDOWN_OPTION,
			C.Z_CELL_TEXT
		)

		return passes
	end

	---@return table[]
	function Passes.scrollbar()
		local track = Layout.scrollbar_rect()
		local width = C.SCROLLBAR_WIDTH
		return {
			Passes.rect("track", { x = 0, y = 0, w = width, h = track.h }, C.COLOR.SCROLLBAR_TRACK),
			Passes.rect("thumb", { x = 0, y = 0, w = width, h = 0 }, C.COLOR.SCROLLBAR_THUMB, C.Z_CELL_TEXT),
		}
	end

	Module.passes = Passes

	return Passes
end
