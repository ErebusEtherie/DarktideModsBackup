---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local ViewElementGrid = require("scripts/ui/view_elements/view_element_grid/view_element_grid")
local definitions = mod:io_dofile("hud_studio/scripts/mods/hud_studio/hud/news/news_definitions")

local style = definitions.text_style

local STYLES = {
	title_major = style(40, "mono_tide_bold", Color.terminal_text_header(255, true), nil, "center"),
	title = style(28, "mono_tide_bold", Color.terminal_text_header(255, true)),
	meta = style(18, "mono_tide_medium", Color.terminal_text_body_sub_header(255, true)),
	meta_major = style(18, "mono_tide_medium", Color.terminal_text_body_sub_header(255, true), nil, "center"),
	section = style(28, "proxima_nova_bold", Color.terminal_text_header(255, true)),
	section_warning = style(28, "proxima_nova_bold", Color.ui_red_light(255, true)),
	feature = style(22, "proxima_nova_bold", Color.terminal_text_header(255, true), 20),
	line = style(20, "proxima_nova_medium", Color.terminal_text_body(255, true), 48),
	bullet = style(20, "proxima_nova_medium", Color.terminal_text_body(255, true), 20),
}

local function styled(name)
	local source = STYLES[name]
	local copy = {}

	for key, value in pairs(source) do
		copy[key] = value
	end

	copy.size = { source.size[1], source.size[2] }
	copy.offset = { source.offset[1], source.offset[2], source.offset[3] }

	return copy
end

local function add_text(layout, text, style_name)
	if type(text) ~= "string" or text == "" then
		return
	end

	layout[#layout + 1] = {
		widget_type = "text",
		text = text,
		style = styled(style_name),
	}
end

local function add_spacing(layout, height)
	layout[#layout + 1] = {
		widget_type = "spacing",
		height = height,
	}
end

---@param lines string[]|nil
local function add_section(layout, header, lines, style_name)
	if not lines or #lines == 0 then
		return
	end

	add_spacing(layout, 18)
	add_text(layout, header, style_name or "section")
	add_spacing(layout, 18)

	for i = 1, #lines do
		add_text(layout, "- " .. lines[i], "bullet")
	end
	add_spacing(layout, 18)
end

---@param page NewsPageDataShape
local function add_page(layout, page, page_count)
	add_text(layout, page.title, page.major and "title_major" or "title")
	add_text(
		layout,
		string.format("v%s   %s", page.version_label, page.date or ""),
		page.major and "meta_major" or "meta"
	)
	add_spacing(layout, 18)

	add_section(
		layout,
		" " .. mod:localize("news_section_breaking_changes"),
		page.breaking_changes,
		"section_warning"
	)

	local features = page.features

	if features and #features > 0 then
		add_spacing(layout, 18)
		add_text(layout, " " .. mod:localize("news_section_features"), "section")
		add_spacing(layout, 18)

		for i = 1, #features do
			local feature = features[i]

			add_text(layout, (feature.name or ""), "feature")
			add_spacing(layout, 4)

			local lines = feature.lines

			for j = 1, lines and #lines or 0 do
				add_text(layout, "- " .. lines[j], "line")
				add_spacing(layout, 4)
			end
			add_spacing(layout, 18)
		end
	end

	local loose_lines = page.lines

	if loose_lines and #loose_lines > 0 then
		for i = 1, #loose_lines do
			add_text(layout, "- " .. loose_lines[i], "bullet")
		end
	end

	add_section(layout, " " .. mod:localize("news_section_bug_fixes"), page.bug_fixes)
	add_section(layout, " " .. mod:localize("news_section_hotfixes"), page.hotfixes)

	if page_count and page_count > 1 then
		add_spacing(layout, 40)
		layout[#layout + 1] = { widget_type = "divider" }
		add_spacing(layout, 40)
	end
end

HudStudioNewsView = class("HudStudioNewsView", "BaseView")

HudStudioNewsView.init = function(self, settings, context)
	HudStudioNewsView.super.init(self, definitions, settings, context)

	self._pass_input = true
	self._pass_draw = true
end

HudStudioNewsView.on_enter = function(self)
	HudStudioNewsView.super.on_enter(self)

	local News = mod:core(mod.hud_studio_news, "hud/news/news")
	local pages = News.pages()
	local layout = {}

	add_spacing(layout, definitions.content_padding_y)

	for i = 1, #pages do
		add_page(layout, pages[i], #pages)
	end

	add_spacing(layout, definitions.content_padding_y)

	self._grid = self:_add_element(ViewElementGrid, "news_grid", 103, definitions.grid_settings, "grid_pivot")
	self._grid:set_visibility(true)
	self._grid:present_grid_layout(layout, definitions.blueprints)
end

local _close_hint_font_size_origin = nil

HudStudioNewsView.update = function(self, dt, t, input_service)

	self._opened_at = self._opened_at or t

	if t - self._opened_at > 1 then
		local dismissed = input_service:get("left_pressed")
			or input_service:get("right_pressed")
			or input_service:get("confirm_pressed")

		if dismissed then
			Managers.ui:close_view(self.view_name)
		end
	end

	local widgets = self._widgets_by_name

	local dismiss = widgets.close_hint

	local style = dismiss and dismiss.style and dismiss.style.style_id_1

	if not _close_hint_font_size_origin and style.font_size then
		_close_hint_font_size_origin = style.font_size
	end

	if _close_hint_font_size_origin then
		local amplitude = 2
		local frequency = 1.5

		local pulse = math.sin(t * frequency) * amplitude

		style.font_size = _close_hint_font_size_origin + pulse
	end

	return HudStudioNewsView.super.update(self, dt, t, input_service)
end

HudStudioNewsView.on_exit = function(self)
	HudStudioNewsView.super.on_exit(self)

	mod:core(mod.hud_studio_news, "hud/news/news").on_view_closed()
end

return HudStudioNewsView
