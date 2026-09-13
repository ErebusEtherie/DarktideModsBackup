-- Realms Inspect: core read-only player inspection, merged from the standalone
-- RealmsInspect mod. The button itself is drawn inside the existing Realms
-- control row by realms_player_controls.lua; this module only owns the
-- "find player -> open read-only inventory" flow and the button geometry.
local mod = get_mod("realms_loadout")
if mod._realms_inspect then return mod._realms_inspect end

local UIRenderer = require("scripts/managers/ui/ui_renderer")

local Inspect = {}
mod._realms_inspect = Inspect

local INVENTORY_VIEW_NAME = "inventory_background_view"
local REALMS_PREPARATION_VIEW_NAME = "realms_preparation_view"
-- U+E04A: the vanilla weapon "inspect" magnifier glyph used by the official
-- weapon options button (see official_ui/inventory_weapons_view).
local INSPECT_ICON = "\238\129\138"
local STATUS_FONT = "proxima_nova_bold"
local STATUS_FONT_SIZE = 16
local GAP = 10

local pending_inspect_player = nil
local last_trigger_t = -math.huge

local function normalize_peer_id(peer_id)
	return string.lower(tostring(peer_id))
end

local function local_peer_id()
	local peer_id = Network.peer_id()

	return peer_id and normalize_peer_id(peer_id) or nil
end

local function show_error(localization_key)
	mod:error("%s", mod:localize(localization_key))
	pcall(mod.notify, mod, mod:localize(localization_key))
end

local function find_human_player(peer_id)
	if type(peer_id) ~= "string" then
		return nil
	end

	local player_manager = Managers.player

	if not player_manager then
		return nil
	end

	local players = player_manager:human_players()

	if not players then
		return nil
	end

	for _, player in pairs(players) do
		if player and not player.__deleted and normalize_peer_id(player:peer_id()) == peer_id then
			return player
		end
	end

	return nil
end

local function open_readonly_inventory(player)
	local ui_manager = Managers.ui

	if not ui_manager then
		return false
	end

	local parent = ui_manager:view_instance(REALMS_PREPARATION_VIEW_NAME)

	local opened, open_result = pcall(function ()
		return ui_manager:open_view(INVENTORY_VIEW_NAME, nil, nil, nil, nil, {
			is_readonly = true,
			parent = parent,
			player = player,
		})
	end)

	if not opened or not open_result then
		mod:error("Failed opening the readonly inventory view: %s", tostring(open_result))
		show_error("inspect_open_failed")

		return false
	end

	return true
end

local function queue_inspect(player)
	local ui_manager = Managers.ui

	if not ui_manager then
		show_error("inspect_open_failed")

		return false
	end

	if ui_manager:view_active(INVENTORY_VIEW_NAME) then
		pending_inspect_player = player

		local closed, close_error = pcall(function ()
			ui_manager:close_view(INVENTORY_VIEW_NAME)
		end)

		if not closed then
			pending_inspect_player = nil
			mod:error("Failed closing the active inventory view: %s", tostring(close_error))
			show_error("inspect_open_failed")

			return false
		end

		return true
	end
	if ui_manager:is_view_closing(INVENTORY_VIEW_NAME) then
		pending_inspect_player = player

		return true
	end

	pending_inspect_player = nil

	return open_readonly_inventory(player)
end

function Inspect.inspect_peer(peer_id)
	if not mod:is_enabled() or type(peer_id) ~= "string" then
		return
	end

	local player = find_human_player(peer_id)

	if not player then
		show_error("inspect_player_unavailable")

		return
	end

	local profile_ok, profile = pcall(function ()
		return player:profile()
	end)

	if not profile_ok or not profile then
		mod:error("Realms Inspect: profile is unavailable for player %s", peer_id)
		show_error("inspect_profile_unavailable")

		return
	end

	queue_inspect(player)
end

local function trigger_peer(peer_id)
	local now = Managers.time and Managers.time:time("main") or 0

	if now == last_trigger_t then
		return
	end

	last_trigger_t = now

	Inspect.inspect_peer(peer_id)
end

function Inspect.visible(content)
	if not (content and content.tpm_visible) then
		return false
	end
	if content._inspect_hidden or content._inspect_eye_overflow then
		return false
	end

	return mod.realms_talent_controls_active()
end

local function measure_status_width(grid, status)
	if not status or status == "" then
		return 0
	end

	local ui_renderer = grid and grid._parent and grid._parent._ui_renderer

	if not ui_renderer then
		local ui = Managers.ui
		local constant = ui and ui:ui_constant_elements()
		ui_renderer = constant and constant:ui_renderer()
	end

	if not ui_renderer then
		return 0
	end

	local max_width = 0

	for line in string.gmatch(status, "[^\n]+") do
		local width = UIRenderer.text_size(ui_renderer, line, STATUS_FONT, STATUS_FONT_SIZE)

		if width and width > max_width then
			max_width = width
		end
	end

	return max_width
end

-- Called from Controls.blueprint(): appends the inspect button passes to the
-- existing control row pass list. The horizontal offset is updated at runtime
-- by Inspect.update_row() so it follows the measured status text width.
function Inspect.add_passes(passes, width, geometry)
	local size = geometry.h
	local x = geometry.status[1]

	passes[#passes + 1] = {
		pass_type = "rect",
		style_id = "inspect_bg",
		style = { color = { 255, 45, 66, 80 }, size = { size, size }, offset = { x, geometry.y, 1 } },
		visibility_function = Inspect.visible,
	}
	passes[#passes + 1] = {
		pass_type = "texture",
		value = "content/ui/materials/frames/frame_tile_2px",
		style_id = "inspect_frame",
		style = { color = { 255, 117, 144, 159 }, size = { size, size }, offset = { x, geometry.y, 2 } },
		visibility_function = Inspect.visible,
	}
	passes[#passes + 1] = {
		pass_type = "text",
		value = INSPECT_ICON,
		style_id = "inspect_icon",
		style = { font_type = STATUS_FONT, font_size = 24, text_color = { 255, 230, 223, 191 },
			text_horizontal_alignment = "center", text_vertical_alignment = "center",
			size = { size, size }, offset = { x, geometry.y, 4 } },
		visibility_function = Inspect.visible,
	}
	passes[#passes + 1] = {
		pass_type = "hotspot",
		content_id = "inspect_hotspot",
		content = {},
		style_id = "inspect_hotspot",
		style = { size = { size, size }, offset = { x, geometry.y, 5 } },
		visibility_function = function(content) return Inspect.visible(content.parent) end,
	}
end

local function set_pass_offset(widget, style_id, x)
	local style = widget and widget.style and widget.style[style_id]

	if style and style.offset then
		style.offset[1] = x
	end
end

function Inspect.update_row(grid, widget, content, geometry, dt)
	if not content or not widget or not geometry then
		return
	end

	local status = content.tpm_status

	if status ~= content._inspect_status_text then
		content._inspect_status_text = status
		content._inspect_status_width = measure_status_width(grid, status)
	end

	local x = geometry.status[1] + (content._inspect_status_width or 0) + GAP
	local row_width = content._inspect_row_width or 1240
	local size = geometry.h

	content._inspect_eye_overflow = (x + size) > row_width
	content._inspect_hidden = grid._tpm_edit ~= nil and grid._tpm_edit.widget == widget

	for _, style_id in ipairs({ "inspect_bg", "inspect_frame", "inspect_icon", "inspect_hotspot" }) do
		set_pass_offset(widget, style_id, x)
	end

	local hotspot = content.inspect_hotspot

	if hotspot then
		hotspot.disabled = not Inspect.visible(content)

		if not hotspot.disabled and hotspot.on_pressed then
			hotspot.on_pressed = nil
			trigger_peer(content.element and content.element.tpm_peer_id)
		end
	end
end

function Inspect.update(dt)
	local player = pending_inspect_player

	if not player then
		return
	end

	local ui_manager = Managers.ui

	if not ui_manager then
		return
	end
	if ui_manager:view_active(INVENTORY_VIEW_NAME) or ui_manager:is_view_closing(INVENTORY_VIEW_NAME) then
		return
	end

	pending_inspect_player = nil

	if not ui_manager:view_instance(REALMS_PREPARATION_VIEW_NAME) then
		return
	end
	if player.__deleted then
		return
	end

	open_readonly_inventory(player)
end

mod._realms_inspect_update = Inspect.update

return Inspect