
local mod = get_mod("hud_studio")

if mod.ide_panel_component then
	return mod.ide_panel_component
end

local PanelHeader = mod:core(mod.panel_header_component, "hud/editor/elements/panel/panel_header")
local PanelBody = mod:core(mod.panel_body_component, "hud/editor/elements/panel/panel_body")
local TextInput = mod:core(mod.hud_studio_text_input_component, "hud/editor/elements/field/text_input")
local C = mod:core(mod.editor_constants, "hud/editor/constants")
local CodeRichText = mod:core(mod.ide_code_rich_text, "hud/editor/editors/code_editor/code_rich_text")

local WARNING_FONT = mod.dl.fonts.validated("proxima_nova_bold")
local FLUFF_FONT_SIZE = 12
local SIG_FONT_SIZE = 14 
local SIG_LINE_H = 18

local COLOR = {
	FLUFF_TEXT = { 125, 255, 255, 255 }, 
	SIG_TEXT = { 255, 130, 175, 140 }, 
	LINE_HOVER = { 40, 130, 150, 190 }, 
	LINE_ACTIVE = { 70, 120, 140, 180 }, 
	ERROR_TEXT = { 255, 235, 70, 60 }, 
}

local IdePanel = {}

function IdePanel.draw(d, panel, z, lay, dragging, ctx)
	PanelBody.draw(d, panel, lay.frame.h, z, { color = CodeRichText.colors.IDE_BG })
	PanelHeader.draw(d, panel, z, dragging, {
		title = ctx.title,
		close = { hover = ctx.close_hover },
	})

	local body_z = z + 1
	local f = lay.frame

	if lay.error then
		for i = 1, #lay.error.lines do
			d:text_left(
				lay.error.lines[i],
				SIG_FONT_SIZE,
				lay.error.x,
				lay.error.y + (i - 1) * SIG_LINE_H,
				body_z + 1,
				lay.error.w,
				SIG_LINE_H,
				COLOR.ERROR_TEXT
			)
		end
	end

	d:text_left(
		CodeRichText.format_string(lay.sig_text),
		SIG_FONT_SIZE,
		lay.sig.x,
		lay.sig.y,
		body_z + 1,
		f.w,
		SIG_LINE_H,
		COLOR.SIG_TEXT
	)

	d:text_left(
		CodeRichText.format_string(lay.declare_text),
		SIG_FONT_SIZE,
		lay.ret.x + 4,
		lay.sig.y + SIG_LINE_H,
		body_z + 1,
		f.w,
		SIG_LINE_H,
		COLOR.SIG_TEXT
	)

	if ctx.ctrl then
		TextInput.draw_multiline(d, ctx.ctrl, lay.body, ctx.focused, body_z, {
			bg = CodeRichText.colors.IDE_BG,
			format = CodeRichText.format_string, 
			hover_bg = COLOR.LINE_HOVER, 
			active_bg = COLOR.LINE_ACTIVE, 
			hover_caret = true, 
		})
	else
		d:rect(lay.body.x, lay.body.y, body_z, lay.body.w, lay.body.h, CodeRichText.colors.IDE_BG)
	end

	d:text_left(
		CodeRichText.format_string(lay.ret_text),
		SIG_FONT_SIZE,
		lay.ret.x + 4,
		lay.ret.y,
		body_z + 1,
		f.w,
		SIG_LINE_H,
		COLOR.SIG_TEXT
	)
	d:text_left(
		CodeRichText.format_string("end"),
		SIG_FONT_SIZE,
		lay.end_line.x,
		lay.end_line.y,
		body_z + 1,
		f.w,
		SIG_LINE_H,
		COLOR.SIG_TEXT
	)

	d:text_left(
		mod:localize("ide_end_undo_redo_warning"),
		FLUFF_FONT_SIZE + 2,
		lay.end_undo_redo_warning.x,
		lay.end_undo_redo_warning.y,
		body_z + 1,
		f.w,
		FLUFF_FONT_SIZE,
		COLOR.FLUFF_TEXT,
		WARNING_FONT
	)

	d:text_left(
		mod:localize("ide_end_fluff"),
		FLUFF_FONT_SIZE,
		lay.end_fluff.x,
		lay.end_fluff.y,
		body_z + 1,
		f.w,
		FLUFF_FONT_SIZE,
		COLOR.FLUFF_TEXT
	)

	d:text_left(
		mod:localize("ide_end_warning"),
		FLUFF_FONT_SIZE,
		lay.end_warning.x,
		lay.end_warning.y,
		body_z + 1,
		f.w,
		FLUFF_FONT_SIZE,
		COLOR.FLUFF_TEXT,
		WARNING_FONT
	)
end

mod.ide_panel_component = IdePanel

return IdePanel
