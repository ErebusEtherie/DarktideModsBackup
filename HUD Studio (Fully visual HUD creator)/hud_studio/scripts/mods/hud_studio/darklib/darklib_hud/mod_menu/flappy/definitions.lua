

---@param Module DLH_ModMenu
return function(Module)
	if Module.flappy_definitions then
		return Module.flappy_definitions
	end

	local UIWidget = require("scripts/managers/ui/ui_widget")
	local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

	local C = Module.flappy_constants

	local Z = {
		BG = 0,
		PIPE = 4,
		BIRD = 8,
		BIRD_EYE = 9,
		GROUND = 12,
		TEXT = 20,
	}

	---@param c argb_table
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

	local function rect_pass(style_id, rect, color, z)
		local style = placed(rect, z)
		style.color = argb(color)
		return { pass_type = "rect", style_id = style_id, style = style }
	end

	---@param opts table
	local function text_pass(style_id, value_id, rect, opts)
		local style = placed(rect, opts.z or Z.TEXT)
		style.font_type = opts.font or C.FONTS.prompt
		style.font_size = opts.font_size or C.FONT_SIZE.prompt
		style.text_horizontal_alignment = opts.align_h or "center"
		style.text_vertical_alignment = opts.align_v or "center"
		style.text_color = argb(opts.color or C.COLOR.PROMPT)
		return { pass_type = "text", style_id = style_id, value_id = value_id, value = "", style = style }
	end

	local scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,

		field = {
			parent = "screen",
			horizontal_alignment = "center",
			vertical_alignment = "center",
			size = { C.FIELD_W, C.FIELD_H },
			position = { C.FIELD_OFFSET_X, C.FIELD_OFFSET_Y, 0 },
		},
	}

	local function field_passes()
		local play_h = C.FIELD_H - C.GROUND_H
		local passes = {

			rect_pass("bg", { x = 0, y = 0, w = C.FIELD_W, h = C.FIELD_H }, C.COLOR.FIELD_BG, Z.BG),
		}

		for i = 1, C.PIPE_POOL do
			passes[#passes + 1] =
				rect_pass("pipe_top_" .. i, { x = 0, y = 0, w = C.PIPE_W, h = 1 }, C.COLOR.PIPE, Z.PIPE)
			passes[#passes + 1] =
				rect_pass("pipe_bot_" .. i, { x = 0, y = 0, w = C.PIPE_W, h = 1 }, C.COLOR.PIPE, Z.PIPE)
		end

		passes[#passes + 1] =
			rect_pass("ground", { x = 0, y = play_h, w = C.FIELD_W, h = C.GROUND_H }, C.COLOR.GROUND, Z.GROUND)

		passes[#passes + 1] = rect_pass(
			"bird",
			{ x = C.BIRD_X, y = play_h * C.BIRD_START_FRAC, w = C.BIRD_SIZE, h = C.BIRD_SIZE },
			C.COLOR.BIRD,
			Z.BIRD
		)
		passes[#passes + 1] = rect_pass("bird_eye", { x = 0, y = 0, w = 10, h = 10 }, C.COLOR.BIRD_EYE, Z.BIRD_EYE)

		passes[#passes + 1] = text_pass("score", "score", { x = 0, y = 40, w = C.FIELD_W, h = 90 }, {
			font = C.FONTS.score,
			font_size = C.FONT_SIZE.score,
			color = C.COLOR.SCORE,
		})

		passes[#passes + 1] = text_pass("prompt", "prompt", { x = 0, y = play_h * 0.62, w = C.FIELD_W, h = 60 }, {
			color = C.COLOR.PROMPT,
		})

		passes[#passes + 1] = text_pass("gameover", "gameover", { x = 0, y = play_h * 0.40, w = C.FIELD_W, h = 70 }, {
			font_size = C.FONT_SIZE.gameover,
			color = C.COLOR.GAMEOVER,
		})
		passes[#passes + 1] = text_pass("hint", "hint", { x = 0, y = play_h * 0.40 + 70, w = C.FIELD_W, h = 40 }, {
			font_size = C.FONT_SIZE.hint,
			color = C.COLOR.HINT,
		})

		return passes
	end

	local widget_definitions = {
		field = UIWidget.create_definition(field_passes(), "field"),
	}

	local Definitions = {
		scenegraph_definition = scenegraph_definition,
		widget_definitions = widget_definitions,
	}

	Module.flappy_definitions = Definitions

	return Definitions
end
