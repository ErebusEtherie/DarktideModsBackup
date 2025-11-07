local mod = get_mod("LessAnnoyingLoading")

mod.time_enabled = false
local function init()
	print("LoadingReason.init()")
	mod.last_text = ""
	mod.last_time_text = ""
	mod.last_time = os.time()
end
local function set_hooks()
	if mod.time_enabled then
		local on_enter = "on_enter"
		mod:hook_safe(CLASS.LobbyView, on_enter, function(self)
			init()
		end)
		mod:hook_safe(CLASS.MissionIntroView, on_enter, function(self)
			init()
		end)
		mod:hook_safe(CLASS.EndView, on_enter, function(self)
			init()
		end)
	end
end
local function get_settings()
	mod.text_enabled = mod:get("setting_text_enable")
	mod.time_enabled = mod:get("setting_time_enable")
	--mod.last_text_enabled = mod:get("setting_last_text_enable")
	mod.text_opacity = mod:get("setting_text_opacity")
	mod.text_font_size = mod:get("setting_text_font_size")
	mod.text_font_type = mod:get("setting_text_font_type") --family
	mod.text_offset_x = mod:get("setting_text_offset_x")
	mod.text_offset_y = mod:get("setting_text_offset_y")
	mod.text_two_lines = mod:get("setting_text_two_lines")
	mod.text_align = mod:get("setting_text_align")
	if mod.text_two_lines then
		mod.separator = "\n"
	else
		mod.separator = "\t"
	end
	--mod.text_background_enabled = mod:get("setting_text_background_enable")
	set_hooks()
end

init()
get_settings()
mod.on_setting_changed = function()
	get_settings()
end

local font_options = {
	shadow = true,
}

mod:hook_origin(
	CLASS.LoadingReason,
	"_render_text",
	function(self, gui, anchor_x, anchor_y, resolution_scale, text, text_opacity)
		if not mod.text_enabled then
			return
		end

		if text ~= mod.last_text then
			mod.last_time = os.time()
			mod.last_time_text = os.date("%X")
			print("LoadingReason", mod.last_time_text, text)
			mod.last_text = text
		end

		if mod.time_enabled then
			local elapsed_time = os.difftime(os.time(), mod.last_time)
			text = string.format("%s + %2ds%s%s", mod.last_time_text, elapsed_time, mod.separator, tostring(text))
		end

		local font_data = Managers.font:data_by_type(mod.text_font_type)
		local font_type = font_data.path
		local font_size = mod.text_font_size * resolution_scale
		local text_min, text_max, _ = Gui2.slug_text_extents(gui, text, font_type, font_size, font_options)

		local text_width = math.round(text_max.x - text_min.x)
		local text_height = math.round(text_max.y - text_min.y)
		local offset_x = -75 * resolution_scale + mod.text_offset_x
		local offset_y = -60 * resolution_scale + mod.text_offset_y
		local position
		local text_x = 0
		local text_y = RESOLUTION_LOOKUP.height - text_height - 10 + mod.text_offset_y
		if mod.text_align > 0 and RESOLUTION_LOOKUP then
			if mod.text_align == 1 then
				text_x = 10 + mod.text_offset_x
			elseif mod.text_align == 2 then
				text_x = ((RESOLUTION_LOOKUP.width - text_width) / 2) + mod.text_offset_x
			elseif mod.text_align == 3 then
				text_x = RESOLUTION_LOOKUP.width - text_width - 10 + mod.text_offset_x
			elseif mod.text_align == 4 then
				local icon_width = 256 * resolution_scale
				local icon_center = anchor_x - (icon_width / 2)
				text_x = icon_center - (text_width / 2)
				text_y = anchor_y + offset_y - text_height
			end

			position = Vector3(text_x, text_y, 999)
		else
			position = Vector3(anchor_x + offset_x - text_width, anchor_y + offset_y - text_height, 999)
		end
		font_options.color = Color(mod.text_opacity, 255, 235, 150)
		-- if mod.text_background_enabled then
		-- 	Gui.rect(gui, position, Vector2(text_width + 0, text_height + 0), Color.black(mod.text_opacity)) --Gui2 draws white rect!? Immediate mode doesn't need destroy (?), leaving out for now cause meh
		-- end

		Gui2.slug_text(gui, text, font_type, font_size, position, Vector2(math.huge, math.huge), font_options)
	end
)
