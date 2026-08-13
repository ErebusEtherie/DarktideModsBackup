local mod = get_mod("HavocQuickplay")
local UIWidget = require("scripts/managers/ui/ui_widget")

local C = mod.C
local S = mod.S

local DEFINITIONS_PATH = "scripts/ui/views/mission_board_view/mission_board_view_definitions"

local ROW_HEIGHT = 44
local STEPPER_WIDTH = 158
local STEPPER_GAP = 10
local BUTTON_WIDTH = 195
local BUTTON_SPLIT = 99

mod:add_global_localize_strings({
	loc_hq_difficulty_havoc = { en = "Havoc" },
	loc_hq_button_host = { en = "HOST" },
	loc_hq_button_queue = { en = "QUEUE" },
	loc_hq_button_cancel = { en = "CANCEL" },
	loc_hq_warn_title = { en = "WARNING" },
	loc_hq_warn_body = {
		en = "WARNING! It appears that you have set your maximum acceptable havoc rank to a number "
			.. "below 40, even though you are simply hosting. This will auto-decline anyone whose "
			.. "current assignment rank is of that number or above, are you sure you would like to "
			.. "continue?"
			.. "\n\n"
			.. "Note: This mod is accounting for the players' TRUE Havoc Rank, and not the rank of "
			.. "their highest beaten Havoc mission (the number that's usually displayed next to "
			.. "their characters' name with a Havoc icon).",
	},
	loc_hq_warn_confirm = { en = "I am sure" },
	loc_hq_warn_cancel = { en = "Cancel" },
	loc_hqp_leave_blacklist = { en = "Leave and Blacklist Lobby" },
	loc_hqp_bl_title = { en = "Leave and Blacklist Lobby" },
	loc_hqp_bl_confirm = { en = "Leave and blacklist" },
	loc_hqp_bl_cancel = { en = "Cancel" },
})

local SYSTEM_BLUEPRINTS_PATH = "scripts/ui/views/system_view/system_view_content_blueprints"
local SYSTEM_LIST_PATH = "scripts/ui/views/system_view/system_view_content_list"
local BLACKLIST_TYPE = "hqp_leave_blacklist_button"
local BLACKLIST_LABEL = "loc_hqp_leave_blacklist"
local LEAVE_PARTY_LABEL = "loc_leave_party_display_name"
local LEAVE_PARTY_ICON = "content/ui/materials/icons/system/escape/leave_party"
local BLACKLIST_COLOR = { 255, 206, 70, 56 }

local function paint(color)
	if type(color) ~= "table" then
		return
	end

	color[1] = BLACKLIST_COLOR[1]
	color[2] = BLACKLIST_COLOR[2]
	color[3] = BLACKLIST_COLOR[3]
	color[4] = BLACKLIST_COLOR[4]
end

local function inject_blueprint(blueprints)
	if not blueprints or blueprints[BLACKLIST_TYPE] then
		return
	end

	local base = blueprints.button

	if not base or not base.init then
		return
	end

	blueprints[BLACKLIST_TYPE] = {
		size = { base.size[1], base.size[2] },
		pass_template = base.pass_template,
		init = function(parent, widget, element, callback_name, disabled)
			base.init(parent, widget, element, callback_name, disabled)

			local style = widget and widget.style
			local text = style and style.text
			local icon = style and style.icon

			if text then
				paint(text.default_color)
				paint(text.hover_color)
				paint(text.selected_color)
				paint(text.text_color)
			end

			if icon then
				paint(icon.default_color)
				paint(icon.hover_color)
				paint(icon.color)
			end
		end,
	}
end

mod:hook_require(SYSTEM_BLUEPRINTS_PATH, inject_blueprint)

local blueprint_ready = false

local function ensure_blueprint()
	if blueprint_ready then
		return true
	end

	local ok, blueprints = pcall(require, SYSTEM_BLUEPRINTS_PATH)

	if not ok or type(blueprints) ~= "table" then
		return false
	end

	inject_blueprint(blueprints)

	blueprint_ready = blueprints[BLACKLIST_TYPE] ~= nil

	return blueprint_ready
end

local function show_blacklist_popup()
	Managers.event:trigger("event_show_ui_popup", {
		title_text = "loc_hqp_bl_title",
		description_text_unlocalized = mod.loc("hq_bl_popup_body", mod.blacklist_minutes()),
		options = {
			{
				close_on_pressed = true,
				text = "loc_hqp_bl_confirm",
				callback = function()
					mod.leave_and_blacklist()
				end,
			},
			{
				close_on_pressed = true,
				hotkey = "back",
				template_type = "terminal_button_small",
				text = "loc_hqp_bl_cancel",
			},
		},
	})
end

local function blacklist_entry(leave_party_validation)
	return {
		icon = LEAVE_PARTY_ICON,
		text = BLACKLIST_LABEL,
		type = BLACKLIST_TYPE,
		validation_function = function()
			if not mod:is_enabled() or mod.setting("hq_disable_bl_button") then
				return false
			end

			if not ensure_blueprint() then
				return false
			end

			if not leave_party_validation then
				return true
			end

			return leave_party_validation()
		end,
		trigger_function = show_blacklist_popup,
	}
end

local function inject_entry(list)
	if type(list) ~= "table" then
		return
	end

	for i = 1, #list do
		if list[i].text == BLACKLIST_LABEL then
			return
		end
	end

	for i = 1, #list do
		if list[i].text == LEAVE_PARTY_LABEL then
			table.insert(list, i + 1, blacklist_entry(list[i].validation_function))

			return
		end
	end
end

mod.inject_system_entry = inject_entry

mod:hook_require(SYSTEM_LIST_PATH, function(content_list)
	if type(content_list) ~= "table" then
		return
	end

	inject_entry(content_list.StateMainMenu)
	inject_entry(content_list.default)
end)

local function wants_step(content, side, hotspot)
	local now = mod.now()
	local held_key = "hq_held_" .. side
	local next_key = "hq_next_" .. side

	if hotspot.on_released then
		content[held_key] = nil
		content[next_key] = nil

		return true
	end

	if not hotspot.is_held then
		content[held_key] = nil
		content[next_key] = nil

		return false
	end

	if not content[held_key] then
		content[held_key] = now
		content[next_key] = now + C.HOLD_REPEAT_DELAY

		return false
	end

	if now >= (content[next_key] or 0) then
		content[next_key] = now + C.HOLD_REPEAT_RATE

		return true
	end

	return false
end

local function stepper_logic(pass, ui_renderer, logic_style, content, position, size)
	if content.disabled then
		return
	end

	local is_max = content.hq_kind == "max"
	local minimum = is_max and mod.min_rank() or C.MIN_HAVOC_RANK
	local maximum = is_max and C.MAX_HAVOC_RANK or mod.max_rank()
	local level = is_max and mod.max_rank() or mod.min_rank()
	local wanted = level

	if wants_step(content, "left", content.hotspot_left) and minimum < level then
		wanted = level - 1
	elseif wants_step(content, "right", content.hotspot_right) and level < maximum then
		wanted = level + 1
	end

	if wanted ~= level or content.hq_last ~= level then
		if is_max then
			mod.set_max_rank(wanted)
			level = mod.max_rank()
		else
			mod.set_min_rank(wanted)
			level = mod.min_rank()
		end

		content.hq_last = level
	end

	content.value_text = tostring(level)
	content.stepper_left = minimum < level and "<" or " "
	content.stepper_right = level < maximum and ">" or " "
end

local function build_stepper_passes()
	local body_color = Color.terminal_text_body(255, true)
	local header_color = Color.terminal_text_header(255, true)
	local accent = { C.PAGE_COLOR[1], C.PAGE_COLOR[2], C.PAGE_COLOR[3], C.PAGE_COLOR[4] }

	local function arrow_style(x)
		return {
			font_size = 22,
			font_type = "proxima_nova_bold",
			horizontal_alignment = "center",
			text_horizontal_alignment = "center",
			text_vertical_alignment = "center",
			vertical_alignment = "center",
			text_color = header_color,
			size = { 30, 30 },
			offset = { x, 9, 3 },
		}
	end

	local function hotspot_style(x)
		return {
			horizontal_alignment = "center",
			vertical_alignment = "center",
			size = { 32, 32 },
			offset = { x, 9, 2 },
		}
	end

	return {
		{ pass_type = "logic", value = stepper_logic },
		{
			pass_type = "text",
			value = "RANK",
			value_id = "label",
			style = {
				font_size = 13,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				horizontal_alignment = "center",
				vertical_alignment = "top",
				text_color = body_color,
				size = { STEPPER_WIDTH, 16 },
				offset = { 0, 0, 3 },
			},
		},
		{
			pass_type = "text",
			value = "1",
			value_id = "value_text",
			style = {
				font_size = 24,
				font_type = "proxima_nova_bold",
				text_horizontal_alignment = "center",
				text_vertical_alignment = "center",
				horizontal_alignment = "center",
				vertical_alignment = "center",
				text_color = accent,
				size = { 56, 30 },
				offset = { 0, 9, 3 },
			},
		},
		{ pass_type = "text", value = "<", value_id = "stepper_left", style = arrow_style(-50) },
		{ pass_type = "text", value = ">", value_id = "stepper_right", style = arrow_style(50) },
		{ content_id = "hotspot_left", pass_type = "hotspot", style = hotspot_style(-50) },
		{ content_id = "hotspot_right", pass_type = "hotspot", style = hotspot_style(50) },
	}
end

local function deep_copy(value, seen)
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}

	if seen[value] then
		return seen[value]
	end

	local copy = {}

	seen[value] = copy

	for k, v in pairs(value) do
		copy[deep_copy(k, seen)] = deep_copy(v, seen)
	end

	return copy
end

local function clone_play_button(source, scenegraph_id, text_key)
	local def = deep_copy(source)

	def.scenegraph_id = scenegraph_id

	local style = def.style or {}

	for _, id in ipairs({ "hotspot", "disabled_text", "default_text", "selected_text" }) do
		local entry = style[id]

		if entry and entry.size then
			entry.size[1] = entry.size[1] * 0.5
		end
	end

	def.content = def.content or {}
	def.content.default_text_key = text_key

	return def
end

local function inject_definitions(definitions)
	local scenegraph = definitions.scenegraph_definition
	local widgets = definitions.widget_definitions

	if not scenegraph or not widgets or scenegraph.hq_rank_row then
		return
	end

	local half = (STEPPER_WIDTH + STEPPER_GAP) * 0.5

	scenegraph.hq_rank_row = {
		horizontal_alignment = "center",
		parent = "difficulty_stepper",
		vertical_alignment = "top",
		size = { STEPPER_WIDTH * 2 + STEPPER_GAP, ROW_HEIGHT },
		position = { 0, 94, 10 },
	}
	scenegraph.hq_rank_min = {
		horizontal_alignment = "center",
		parent = "hq_rank_row",
		vertical_alignment = "top",
		size = { STEPPER_WIDTH, ROW_HEIGHT },
		position = { -half, 0, 1 },
	}
	scenegraph.hq_rank_max = {
		horizontal_alignment = "center",
		parent = "hq_rank_row",
		vertical_alignment = "top",
		size = { STEPPER_WIDTH, ROW_HEIGHT },
		position = { half, 0, 1 },
	}
	scenegraph.hq_host_button = {
		horizontal_alignment = "center",
		parent = "play_button",
		vertical_alignment = "center",
		size = { BUTTON_WIDTH, 110 },
		position = { -BUTTON_SPLIT, 0, 1 },
	}
	scenegraph.hq_queue_button = {
		horizontal_alignment = "center",
		parent = "play_button",
		vertical_alignment = "center",
		size = { BUTTON_WIDTH, 110 },
		position = { BUTTON_SPLIT, 0, 1 },
	}

	widgets.hq_rank_min = UIWidget.create_definition(build_stepper_passes(), "hq_rank_min", {
		hq_kind = "min",
		label = mod.loc("hq_stepper_min"),
	})
	widgets.hq_rank_max = UIWidget.create_definition(build_stepper_passes(), "hq_rank_max", {
		hq_kind = "max",
		label = mod.loc("hq_stepper_max"),
	})

	local play = widgets.play_button

	if play then
		widgets.hq_host_button = clone_play_button(play, "hq_host_button", "loc_hq_button_host")
		widgets.hq_queue_button = clone_play_button(play, "hq_queue_button", "loc_hq_button_queue")
	end
end

mod:hook_require(DEFINITIONS_PATH, inject_definitions)

local function havoc_page_index(page_settings)
	if not page_settings then
		return nil
	end

	for i = 1, #page_settings do
		if page_settings[i].name == C.PAGE_NAME then
			return i
		end
	end

	return nil
end

mod.havoc_page_index = havoc_page_index

local function check_unlocked()
	return mod.havoc_unlocked()
end

local function build_page()
	return {
		name = C.PAGE_NAME,
		loc_name = "loc_hq_difficulty_havoc",
		display_name = "loc_hq_difficulty_havoc",
		ui_theme = "default",
		icon = C.PAGE_ICON,
		digital_icon = C.PAGE_ICON,
		color = C.PAGE_COLOR,
		challenge = 5,
		resistance = 5,
		is_unlocked = false,
		check_unlocked = check_unlocked,
		filter = { category_whitelist = {} },
	}
end

mod:hook_safe(CLASS.MissionBoardViewLogic, "_on_missions_data_fetch_success", function(self)
	local page_settings = self._page_settings

	if not page_settings or havoc_page_index(page_settings) then
		return
	end

	page_settings[#page_settings + 1] = build_page()

	self:_annotate_pages()

	local index = #page_settings
	local save_data = self._save_data

	if save_data and save_data.page_index == index and self:page_is_unlocked(index) then
		self._page_index = index
	end
end)

local function on_havoc_page(view)
	local logic = view and view._mission_board_logic

	if not logic then
		return false
	end

	local page = logic:get_current_page()

	return page ~= nil and page.name == C.PAGE_NAME
end

mod.on_havoc_page = on_havoc_page

local HAVOC_ONLY = { "hq_rank_min", "hq_rank_max", "hq_host_button", "hq_queue_button" }
local VANILLA_ONLY = { "play_button", "play_button_legend" }

local function set_page_widgets(view, is_havoc, blocked_text)
	local widgets_by_name = view._widgets_by_name

	if not widgets_by_name then
		return
	end

	local show_havoc = is_havoc and not blocked_text
	local show_vanilla = not show_havoc

	for i = 1, #HAVOC_ONLY do
		local widget = widgets_by_name[HAVOC_ONLY[i]]

		if widget then
			widget.visible = show_havoc
		end
	end

	for i = 1, #VANILLA_ONLY do
		local widget = widgets_by_name[VANILLA_ONLY[i]]

		if widget then
			widget.visible = show_vanilla

			if widget.content.visible ~= nil or show_vanilla then
				widget.content.visible = show_vanilla
			end
		end
	end

	if not blocked_text then
		return
	end

	local play = widgets_by_name.play_button

	if play then
		play.content.disabled_text = blocked_text
		play.content.hotspot.disabled = true
	end
end

local function reset_stepper_values(view)
	local widgets_by_name = view._widgets_by_name

	if not widgets_by_name then
		return
	end

	for _, name in ipairs({ "hq_rank_min", "hq_rank_max" }) do
		local widget = widgets_by_name[name]

		if widget then
			widget.content.hq_last = nil
		end
	end
end

local function bind_buttons(view)
	local widgets_by_name = view._widgets_by_name
	local host = widgets_by_name and widgets_by_name.hq_host_button
	local queue = widgets_by_name and widgets_by_name.hq_queue_button

	if host then
		host.content.hotspot.pressed_callback = function()
			mod.on_host_pressed(view)
		end
	end

	if queue then
		queue.content.hotspot.pressed_callback = function()
			mod.on_queue_pressed(view)
		end
	end
end

mod:hook_safe(CLASS.MissionBoardView, "on_enter", function(self)
	bind_buttons(self)
	set_page_widgets(self, false)
	mod.refresh_order(false)
end)

local function page_block_text(is_havoc)
	if not is_havoc then
		return nil
	end

	return mod.havoc_block_reason()
end

mod:hook_safe(CLASS.MissionBoardView, "_open_current_page", function(self)
	local is_havoc = on_havoc_page(self)

	set_page_widgets(self, is_havoc, page_block_text(is_havoc))
	reset_stepper_values(self)
	mod.refresh_order(false)
end)

local function refresh_host_button(view)
	local widgets_by_name = view._widgets_by_name
	local host = widgets_by_name and widgets_by_name.hq_host_button

	if not host then
		return
	end

	local key = S.hosting and "loc_hq_button_cancel" or "loc_hq_button_host"

	if host.content.default_text_key ~= key then
		host.content.default_text_key = key
	end
end

mod:hook_safe(CLASS.MissionBoardView, "update", function(self)
	local is_havoc = on_havoc_page(self)
	local blocked_text = page_block_text(is_havoc)

	set_page_widgets(self, is_havoc, blocked_text)

	if is_havoc and not blocked_text then
		refresh_host_button(self)
	end
end)

mod:hook(CLASS.MissionBoardView, "_callback_start_selected_mission", function(func, self, ...)
	if mod:is_enabled() and on_havoc_page(self) then
		return
	end

	return func(self, ...)
end)

mod.on_queue_pressed = function(view)
	if mod.is_queued() then
		mod.cancel_queue(mod.loc("hq_notify_cancelled"))

		return
	end

	if mod.start_queue() then
		Managers.ui:close_view(view.view_name)
	end
end

local function do_host(view)
	if mod.start_host() then
		Managers.ui:close_view(view.view_name)
	end
end

local function show_max_rank_warning(view)
	local context = {
		title_text = "loc_hq_warn_title",
		description_text = "loc_hq_warn_body",
		options = {
			{
				close_on_pressed = true,
				template_type = "terminal_button_hold_small",
				text = "loc_hq_warn_confirm",
				text_color = C.WARN_COLOR,
				callback = function()
					mod:set("hq_max_warning_seen", true)
					do_host(view)
				end,
			},
			{
				close_on_pressed = true,
				hotkey = "back",
				text = "loc_hq_warn_cancel",
				callback = function()
					return
				end,
			},
		},
	}

	Managers.event:trigger("event_show_ui_popup", context)
end

mod.on_host_pressed = function(view)
	if S.hosting then
		mod.stop_host()
		mod.say(mod.loc("hq_notify_host_stopped"))

		return
	end

	if mod.max_rank() < C.MAX_HAVOC_RANK and not mod.setting("hq_max_warning_seen") then
		show_max_rank_warning(view)

		return
	end

	do_host(view)
end
