local LoadingBarStyles = {}

local WHITE = { 255, 255, 255, 255 }

LoadingBarStyles.heavy = {
	id = "heavy",
	bar_width = 560,
	bar_height = 16,
	text_gap = 34,
	layers = {
		{
			kind = "texture",
			material = "content/ui/materials/bars/heavy/frame_back",
			pad = { 48, 30 },
			layer = 0,
			color = WHITE,
		},
		{
			kind = "fill",
			material = "content/ui/materials/bars/heavy/fill_electric",
			layer = 1,
			progression = true,
			color = WHITE,
		},
		{
			kind = "texture",
			material = "content/ui/materials/bars/heavy/frame_top",
			pad = { 48, 30 },
			layer = 2,
			color = WHITE,
		},

		{
			kind = "texture",
			material = "content/ui/materials/bars/heavy/frame_effect_electric",
			pad = { 122, 110 },
			layer = 4,
			progression = true,
			color = WHITE,
		},
		{
			kind = "endcap",
			material = "content/ui/materials/bars/heavy/fill_end",
			width = 96,
			pad_y = 30,
			offset_x = -49,
			layer = 6,
			fade_in = 0.2,
			color = WHITE,
		},
	},
}

LoadingBarStyles.simple = {
	id = "simple",
	bar_width = 520,
	bar_height = 12,
	text_gap = 26,
	layers = {
		{
			kind = "rect",
			pad = { 4, 4 },
			layer = 0,
			color = { 170, 8, 8, 8 },
		},
		{
			kind = "fill",
			material = "content/ui/materials/bars/simple/fill",
			layer = 1,
			progression = true,
			color = WHITE,
		},
		{
			kind = "texture",
			material = "content/ui/materials/bars/simple/frame",
			pad = { 8, 8 },
			layer = 2,
			color = WHITE,
		},
		{
			kind = "endcap",
			material = "content/ui/materials/bars/simple/end",
			width = 32,
			pad_y = 8,
			offset_x = -16,
			layer = 3,
			fade_in = 0.15,
			color = WHITE,
		},
	},
}

LoadingBarStyles.fallback = {
	id = "fallback",
	bar_width = 520,
	bar_height = 12,
	text_gap = 26,
	layers = {
		{
			kind = "rect",
			pad = { 4, 4 },
			layer = 0,
			color = { 200, 10, 10, 10 },
		},
		{
			kind = "fill",
			layer = 1,
			color = { 255, 255, 200, 90 },
		},
	},
}

function LoadingBarStyles.get(id)
	return LoadingBarStyles[id] or LoadingBarStyles.heavy
end

return LoadingBarStyles
