local mod = get_mod("wkc")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")

local WINDOW_WIDTH = 1000
local WINDOW_HEIGHT = 940
local SIDE_PAD = 44
local TOP_PAD = 18
local TITLE_HEIGHT = 46
local PANEL_TOP = TOP_PAD + TITLE_HEIGHT + 14
local PANEL_WIDTH = WINDOW_WIDTH - SIDE_PAD * 2
local PANEL_HEIGHT = 720
local PANEL_INSET = 28
local ROWS_PER_PAGE = 15
local ROW_HEIGHT = 40
local ROW_GAP = 5
local ROW_WIDTH = PANEL_WIDTH - PANEL_INSET * 2
local BUTTON_W = 180
local BUTTON_H = 46
local BUTTON_Y = PANEL_TOP + PANEL_HEIGHT + 16
local PAGE_TEXT_HEIGHT = 26
local DETAIL_LINES_MAX = 28

local TEXT_COLOR = { 255, 226, 226, 210 }
local NUMBER_COLOR = { 255, 255, 211, 64 }
local ROW_BG_COLOR = { 170, 16, 18, 16 }
local ROW_BG_HOVER = { 210, 34, 38, 34 }
local WINDOW_BG_COLOR = { 235, 4, 5, 4 }
local PANEL_BG_COLOR = { 235, 6, 8, 6 }
local FRAME_COLOR = { 255, 93, 101, 50 }

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
	canvas = {
		horizontal_alignment = "center",
		parent = "screen",
		vertical_alignment = "center",
		size = { 1920, 1080 },
		position = { 0, 0, 0 },
	},
	window = {
		horizontal_alignment = "center",
		parent = "canvas",
		vertical_alignment = "center",
		size = { WINDOW_WIDTH, WINDOW_HEIGHT },
		position = { 0, 0, 10 },
	},
	title = {
		horizontal_alignment = "center",
		parent = "window",
		vertical_alignment = "top",
		size = { PANEL_WIDTH, TITLE_HEIGHT },
		position = { 0, TOP_PAD, 20 },
	},
	panel = {
		horizontal_alignment = "center",
		parent = "window",
		vertical_alignment = "top",
		size = { PANEL_WIDTH, PANEL_HEIGHT },
		position = { 0, PANEL_TOP, 20 },
	},
	page_text = {
		horizontal_alignment = "center",
		parent = "panel",
		vertical_alignment = "top",
		size = { ROW_WIDTH, PAGE_TEXT_HEIGHT },
		position = { 0, PANEL_HEIGHT - PAGE_TEXT_HEIGHT - 8, 25 },
	},
	detail_area = {
		horizontal_alignment = "center",
		parent = "panel",
		vertical_alignment = "top",
		size = { ROW_WIDTH, PANEL_HEIGHT - 40 },
		position = { 0, 20, 25 },
	},
	prev_button = {
		horizontal_alignment = "left",
		parent = "window",
		vertical_alignment = "top",
		size = { BUTTON_W, BUTTON_H },
		position = { SIDE_PAD, BUTTON_Y, 25 },
	},
	next_button = {
		horizontal_alignment = "left",
		parent = "window",
		vertical_alignment = "top",
		size = { BUTTON_W, BUTTON_H },
		position = { SIDE_PAD + BUTTON_W + 14, BUTTON_Y, 25 },
	},
	back_button = {
		horizontal_alignment = "center",
		parent = "window",
		vertical_alignment = "top",
		size = { BUTTON_W, BUTTON_H },
		position = { 0, BUTTON_Y, 25 },
	},
	close_button = {
		horizontal_alignment = "right",
		parent = "window",
		vertical_alignment = "top",
		size = { BUTTON_W, BUTTON_H },
		position = { -SIDE_PAD, BUTTON_Y, 25 },
	},
}

for i = 1, ROWS_PER_PAGE do
	scenegraph_definition["row_" .. i] = {
		horizontal_alignment = "left",
		parent = "panel",
		vertical_alignment = "top",
		size = { ROW_WIDTH, ROW_HEIGHT },
		position = { PANEL_INSET, 16 + (i - 1) * (ROW_HEIGHT + ROW_GAP), 25 },
	}
end

local function row_definition(scenegraph_id)
	return UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
		},
		{
			pass_type = "rect",
			style_id = "background",
			style = {
				color = ROW_BG_COLOR,
				offset = { 0, 0, 1 },
				size = { ROW_WIDTH, ROW_HEIGHT },
			},
			change_function = function(content, style)
				local hotspot = content.hotspot
				if hotspot and hotspot.is_hover then
					style.color = ROW_BG_HOVER
				else
					style.color = ROW_BG_COLOR
				end
			end,
		},
		{
			pass_type = "text",
			style_id = "name",
			value = "",
			value_id = "name",
			style = {
				font_size = 18,
				font_type = "proxima_nova_bold",
				text_color = TEXT_COLOR,
				text_horizontal_alignment = "left",
				text_vertical_alignment = "center",
				offset = { 14, 0, 3 },
				size = { ROW_WIDTH - 220, ROW_HEIGHT },
			},
		},
		{
			pass_type = "text",
			style_id = "kills",
			value = "",
			value_id = "kills",
			style = {
				font_size = 18,
				font_type = "proxima_nova_bold",
				text_color = NUMBER_COLOR,
				text_horizontal_alignment = "right",
				text_vertical_alignment = "center",
				offset = { -14, 0, 3 },
				size = { ROW_WIDTH - 28, ROW_HEIGHT },
			},
		},
	}, scenegraph_id)
end

local widget_definitions = {
	window = UIWidget.create_definition({
		{
			pass_type = "rect",
			style_id = "background",
			style = { color = WINDOW_BG_COLOR },
		},
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = FRAME_COLOR,
				offset = { 0, 0, 1 },
			},
		},
	}, "window"),
	title = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "text",
			value = "",
			value_id = "text",
			style = {
				font_size = 30,
				font_type = "proxima_nova_bold",
				text_color = NUMBER_COLOR,
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
			},
		},
	}, "title"),
	panel = UIWidget.create_definition({
		{
			pass_type = "rect",
			style_id = "background",
			style = { color = PANEL_BG_COLOR },
		},
		{
			pass_type = "texture",
			style_id = "frame",
			value = "content/ui/materials/frames/frame_tile_2px",
			style = {
				color = FRAME_COLOR,
				offset = { 0, 0, 1 },
			},
		},
	}, "panel"),
	page_text = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "text",
			value = "",
			value_id = "text",
			style = {
				font_size = 15,
				font_type = "proxima_nova_medium",
				text_color = TEXT_COLOR,
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
			},
		},
	}, "page_text"),
	detail_area = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "labels",
			value = "",
			value_id = "labels",
			style = {
				font_size = 17,
				font_type = "proxima_nova_bold",
				line_spacing = 1.3,
				text_color = TEXT_COLOR,
				text_horizontal_alignment = "right",
				text_vertical_alignment = "top",
				offset = { 0, 4, 3 },
				size = { math.floor(ROW_WIDTH / 2) - 16, PANEL_HEIGHT - 48 },
			},
		},
		{
			pass_type = "text",
			style_id = "values",
			value = "",
			value_id = "values",
			style = {
				font_size = 17,
				font_type = "proxima_nova_bold",
				line_spacing = 1.3,
				text_color = NUMBER_COLOR,
				text_horizontal_alignment = "left",
				text_vertical_alignment = "top",
				offset = { math.floor(ROW_WIDTH / 2) + 16, 4, 3 },
				size = { math.floor(ROW_WIDTH / 2) - 16, PANEL_HEIGHT - 48 },
			},
		},
	}, "detail_area"),
	prev_button = UIWidget.create_definition(ButtonPassTemplates.terminal_button, "prev_button", {
		visible = true,
		original_text = mod:localize("wkc_all_prev"),
	}),
	next_button = UIWidget.create_definition(ButtonPassTemplates.terminal_button, "next_button", {
		visible = true,
		original_text = mod:localize("wkc_all_next"),
	}),
	back_button = UIWidget.create_definition(ButtonPassTemplates.terminal_button, "back_button", {
		visible = false,
		original_text = mod:localize("wkc_all_back"),
	}),
	close_button = UIWidget.create_definition(ButtonPassTemplates.terminal_button, "close_button", {
		visible = true,
		original_text = mod:localize("wkc_all_close"),
	}),
}

for i = 1, ROWS_PER_PAGE do
	widget_definitions["row_" .. i] = row_definition("row_" .. i)
end

local definitions = {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
}

local WeaponKillCounterAllView = class("WeaponKillCounterAllView", "BaseView")

WeaponKillCounterAllView.init = function(self, settings, context)
	self._ws_context = context or {}
	WeaponKillCounterAllView.super.init(self, definitions, settings, context)
	self._allow_close_hotkey = true
	self._mode = "list"
	self._page = 1
end

WeaponKillCounterAllView.on_enter = function(self)
	WeaponKillCounterAllView.super.on_enter(self)
	local widgets = self._widgets_by_name
	widgets.close_button.content.hotspot.pressed_callback = callback(self, "_close_view")
	widgets.prev_button.content.hotspot.pressed_callback = callback(self, "_prev_page")
	widgets.next_button.content.hotspot.pressed_callback = callback(self, "_next_page")
	widgets.back_button.content.hotspot.pressed_callback = callback(self, "_back_to_list")
	self:_render_list()
end

WeaponKillCounterAllView._page_count = function(self)
	local entries = self._ws_context.entries or {}
	return math.max(math.ceil(#entries / ROWS_PER_PAGE), 1)
end

WeaponKillCounterAllView._render_list = function(self)
	self._mode = "list"
	local widgets = self._widgets_by_name
	local entries = self._ws_context.entries or {}
	local page_count = self:_page_count()
	if self._page > page_count then self._page = page_count end
	if self._page < 1 then self._page = 1 end

	widgets.title.content.text = mod:localize("wkc_all_title")
	widgets.detail_area.visible = false
	widgets.back_button.content.visible = false
	widgets.page_text.visible = true
	widgets.prev_button.content.visible = page_count > 1
	widgets.next_button.content.visible = page_count > 1
	widgets.page_text.content.text = mod:localize("wkc_all_page",
		self._page, page_count, #entries,
		self._ws_context.total_kills_text or tostring(self._ws_context.total_kills or 0))

	local base = (self._page - 1) * ROWS_PER_PAGE
	for i = 1, ROWS_PER_PAGE do
		local widget = widgets["row_" .. i]
		local entry = entries[base + i]
		if entry then
			widget.visible = true
			widget.content.name = entry.label
			widget.content.kills = entry.kills_text or tostring(entry.kills)
			widget.content._entry = entry
		else
			widget.visible = false
			widget.content._entry = nil
		end
	end
end

local HEADER_MARKUP_OPEN  = "{#color(255,211,64)}"
local HEADER_MARKUP_RESET = "{#reset()}"
local function section_header(text)
	return HEADER_MARKUP_OPEN .. "---- " .. text .. " ----" .. HEADER_MARKUP_RESET
end

WeaponKillCounterAllView._build_detail_lines = function(self, entry)
	local ctx = self._ws_context or {}
	local lines = {}

	local rows = (ctx.get_rows and ctx.get_rows(entry)) or {}
	lines[#lines + 1] = { label = section_header(mod:localize("wkc_all_general")), value = "" }
	for i = 1, #rows do
		lines[#lines + 1] = { label = tostring(rows[i].label or ""), value = tostring(rows[i].value or "") }
	end

	if ctx.has_havoc and ctx.has_havoc(entry) and ctx.get_havoc_rows then
		local hrows = ctx.get_havoc_rows(entry) or {}
		if #hrows > 0 then
			lines[#lines + 1] = { label = "", value = "" }
			lines[#lines + 1] = { label = section_header(mod:localize("wkc_all_havoc")), value = "" }
			for i = 1, #hrows do
				lines[#lines + 1] = { label = tostring(hrows[i].label or ""), value = tostring(hrows[i].value or "") }
			end
		end
	end
	return lines
end

WeaponKillCounterAllView._draw_detail = function(self)
	local widgets = self._widgets_by_name
	local lines = self._detail_lines or {}
	local max_scroll = math.max(0, #lines - DETAIL_LINES_MAX)
	local scroll = math.max(0, math.min(self._detail_scroll or 0, max_scroll))
	self._detail_scroll = scroll

	local labels, values = {}, {}
	for i = scroll + 1, math.min(#lines, scroll + DETAIL_LINES_MAX) do
		labels[#labels + 1] = lines[i].label
		values[#values + 1] = lines[i].value
	end
	widgets.detail_area.content.labels = table.concat(labels, "\n")
	widgets.detail_area.content.values = table.concat(values, "\n")
end

WeaponKillCounterAllView._render_detail = function(self, entry)
	self._mode = "detail"
	local widgets = self._widgets_by_name

	widgets.title.content.text = entry.label
	widgets.page_text.visible = false
	widgets.prev_button.content.visible = false
	widgets.next_button.content.visible = false
	widgets.back_button.content.visible = true

	for i = 1, ROWS_PER_PAGE do
		widgets["row_" .. i].visible = false
		widgets["row_" .. i].content._entry = nil
	end

	self._detail_entry  = entry
	self._detail_lines  = self:_build_detail_lines(entry)
	self._detail_scroll = 0
	widgets.detail_area.visible = true
	self:_draw_detail()
end

WeaponKillCounterAllView._prev_page = function(self)
	if self._mode ~= "list" then return end
	self._page = self._page - 1
	if self._page < 1 then self._page = self:_page_count() end
	self:_render_list()
end

WeaponKillCounterAllView._next_page = function(self)
	if self._mode ~= "list" then return end
	self._page = self._page + 1
	if self._page > self:_page_count() then self._page = 1 end
	self:_render_list()
end

WeaponKillCounterAllView._back_to_list = function(self)
	self:_render_list()
end

WeaponKillCounterAllView._close_view = function(self)
	Managers.ui:close_view(self.view_name)
end

WeaponKillCounterAllView.update = function(self, dt, t, input_service)
	if self._mode == "list" then
		local widgets = self._widgets_by_name
		for i = 1, ROWS_PER_PAGE do
			local widget = widgets["row_" .. i]
			if widget.visible and widget.content._entry then
				local hotspot = widget.content.hotspot
				if hotspot and hotspot.on_pressed then
					hotspot.on_pressed = nil
					self:_render_detail(widget.content._entry)
					break
				end
			end
		end
	end
	if self._mode == "detail" and input_service and input_service.get then
		local axis = input_service:get("scroll_axis")
		local dy = axis and axis[2] or 0
		if dy ~= 0 then
			local lines = self._detail_lines or {}
			local max_scroll = math.max(0, #lines - DETAIL_LINES_MAX)
			if max_scroll > 0 then
				local step = 3
				local cur = self._detail_scroll or 0
				cur = (dy > 0) and (cur - step) or (cur + step)
				self._detail_scroll = math.max(0, math.min(cur, max_scroll))
				self:_draw_detail()
			end
		end
	end

	return WeaponKillCounterAllView.super.update(self, dt, t, input_service)
end

WeaponKillCounterAllView._handle_input = function(self, input_service)
	if input_service and input_service:get("back") then
		if self._mode == "detail" then
			self:_back_to_list()
		else
			self:_close_view()
		end
	end
end

return WeaponKillCounterAllView
