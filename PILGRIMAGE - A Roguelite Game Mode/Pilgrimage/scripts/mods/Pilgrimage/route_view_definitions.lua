-- route_view_definitions.lua
--
-- The layout half of the route view. Kept separate from the behaviour half for the same
-- reason the game keeps its own views split this way: a definitions file is pure data
-- and can be read top to bottom to understand what is on screen, while the view file
-- holds only what happens when you press things.
--
-- HOW A DARKTIDE VIEW IS PUT TOGETHER, briefly, because it is not obvious
--
--   scenegraph  a tree of named boxes. Each node says how big it is, which node it
--               hangs off, and how it aligns inside that parent. Nothing is drawn by a
--               scenegraph node; it only decides where things are. Positions are
--               { x, y, z } where z is draw order.
--
--   widgets     the things actually drawn. Each widget is attached to one scenegraph
--               node and is built from a list of PASSES, where a pass is one drawn
--               element: a texture, a rectangle, a line of text, a button hotspot.
--
--   pass templates
--               prebuilt pass lists the game uses for its own UI. Using
--               ButtonPassTemplates.terminal_button means our buttons are the same
--               objects the game's menus use, with the same hover states, sounds and
--               controller navigation, instead of something we drew that merely looks
--               similar.

local mod = get_mod("Pilgrimage")

local UIWidget            = mod:original_require("scripts/managers/ui/ui_widget")
local UIFontSettings      = mod:original_require("scripts/managers/ui/ui_font_settings")
local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local ButtonPassTemplates = mod:original_require("scripts/ui/pass_templates/button_pass_templates")
local UISoundEvents       = mod:original_require("scripts/settings/ui/ui_sound_events")

-- Eight is the practical ceiling for a route, and drawing a fixed set of rows and hiding
-- the unused ones is far simpler and cheaper than creating and destroying widgets as the
-- route length changes. run_length is capped to match.
local MAX_LEG_ROWS = 8

-- v0.14.0: the terminal grew. Kaizen asked for real columns, images and a bigger
-- window, and the old 820px panel could not seat four columns without the text
-- fighting for space. 1180x820 sits comfortably inside a 1920x1080 workspace.
local PANEL_WIDTH  = 1180
local PANEL_HEIGHT = 820
-- 64, up from 52: tall enough for a 44px circumstance icon with breathing room.
local ROW_HEIGHT   = 64
local ROW_WIDTH    = PANEL_WIDTH - 60

-- The row's column plan, one place so the offsets cannot drift apart:
--   [20..190]    assignment number
--   [200..244]   circumstance icon, 44px, vertically centred
--   [260..710]   mission name
--   [720..1000]  condition name
--   [1010..1100] status, right aligned
local COL_INDEX_X, COL_INDEX_W = 20, 170
local COL_ICON_X,  COL_ICON_S  = 200, 44
local COL_NAME_X,  COL_NAME_W  = 260, 450
local COL_COND_X,  COL_COND_W  = 720, 280
local COL_STATUS_W             = 110

-- Taller than a leg row, because a boon needs a title AND a description and the
-- descriptions the game ships are full sentences.
local BOON_CARD_HEIGHT = 116

local M = {}

M.MAX_LEG_ROWS = MAX_LEG_ROWS

-- v0.22.76: the row hotspot's default sounds, exported so route_view
-- can silence a header row's hover/click sounds in the preset picker
-- and restore the originals when the widget is reused as a normal row.
M.ROW_ON_PRESSED_SOUND = UISoundEvents and UISoundEvents.default_click or nil
M.ROW_ON_HOVER_SOUND   = UISoundEvents and UISoundEvents.default_mouse_hover or nil

-- ---------------------------------------------------------------------------
-- Scenegraph
-- ---------------------------------------------------------------------------

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,

	panel = {
		parent = "screen",
		horizontal_alignment = "center",
		vertical_alignment = "center",
		size = { PANEL_WIDTH, PANEL_HEIGHT },
		position = { 0, 0, 10 },
	},

	title = {
		parent = "panel",
		horizontal_alignment = "center",
		vertical_alignment = "top",
		size = { PANEL_WIDTH - 80, 60 },
		position = { 0, 40, 20 },
	},

	subtitle = {
		parent = "panel",
		horizontal_alignment = "center",
		vertical_alignment = "top",
		size = { PANEL_WIDTH - 80, 30 },
		position = { 0, 100, 20 },
	},

	-- v0.22.31: tab bar sits below the subtitle, above the rows. Route
	-- content dropped 40px to make room; the boons area matches so its
	-- three cards remain co-located with the leg rows for the same reason
	-- (draft and route are the same decision at different scales).
	tab_bar = {
		parent = "panel",
		horizontal_alignment = "center",
		vertical_alignment = "top",
		size = { PANEL_WIDTH - 80, 40 },
		position = { 0, 138, 20 },
	},

	-- Balance readout, shown in the Emporium tab (and hidden in the
	-- others). Right-aligned inside the tab bar strip so it doesn't
	-- crowd the tab buttons on the left.
	balance_label = {
		parent = "panel",
		horizontal_alignment = "right",
		vertical_alignment = "top",
		size = { 220, 40 },
		position = { -40, 138, 21 },
	},

	-- Anchor that every leg row hangs off. Moving this one node shifts the whole list.
	rows = {
		parent = "panel",
		horizontal_alignment = "center",
		vertical_alignment = "top",
		size = { ROW_WIDTH, ROW_HEIGHT * MAX_LEG_ROWS },
		position = { 0, 186, 20 },
	},

	-- Three boon cards, laid out where the leg rows go. The view swaps between the two
	-- lists rather than opening a second window, because a draft and a route are the same
	-- decision at different scales and moving to another screen for one of them would make
	-- the terminal feel like a menu tree.
	boons = {
		parent = "panel",
		horizontal_alignment = "center",
		vertical_alignment = "top",
		size = { ROW_WIDTH, 3 * BOON_CARD_HEIGHT },
		position = { 0, 186, 20 },
	},

	footer = {
		parent = "panel",
		horizontal_alignment = "center",
		vertical_alignment = "bottom",
		size = { PANEL_WIDTH - 80, 40 },
		position = { 0, -165, 20 },
	},

	reroll_button = {
		parent = "panel",
		horizontal_alignment = "center",
		vertical_alignment = "bottom",
		size = { 280, 56 },
		position = { -150, -40, 20 },
	},

	begin_button = {
		parent = "panel",
		horizontal_alignment = "center",
		vertical_alignment = "bottom",
		size = { 280, 56 },
		position = { 150, -40, 20 },
	},

	close_button = {
		parent = "panel",
		horizontal_alignment = "right",
		vertical_alignment = "top",
		size = { 56, 56 },
		position = { -20, 20, 30 },
	},

	-- v0.22.51 (Session H): "Change War Plan" button. Sits above the
	-- reroll/begin row, left-aligned so it visually anchors to the plan
	-- name in the title (which reads "PILGRIMAGE / <plan name>"). Only
	-- shown in Route mode when no run is in progress; hidden in every
	-- other mode.
	-- KAIZEN LOCAL EDIT: original position (y=-110) sat on top of the
	-- footer disclaimer band (y=-120, h=40, i.e. bottom y=[100,140])
	-- at the SAME z=20, so plan_button drew hidden behind the "Missions
	-- run back to back..." line and the "Change War Plan" button was
	-- invisible after a completed run. Footer is moved further up to
	-- y=-165 and plan_button raised to z=22 so it wins any residual
	-- draw-order ambiguity and the two now stack cleanly:
	--   reroll/begin   ~y=[12,68]
	--   plan_button    ~y=[89,131]
	--   footer         ~y=[145,185]
	plan_button = {
		parent = "panel",
		horizontal_alignment = "center",
		vertical_alignment = "bottom",
		-- v0.22.53: size bumped to match reroll/begin (280x56) and z left
		-- at 22 (from other-chat fix) so the button reads as a peer to
		-- the primary Route actions.
		size = { 280, 56 },
		position = { 0, -110, 22 },
	},
}

for i = 1, 3 do
	scenegraph_definition["boon_" .. i] = {
		parent = "boons",
		horizontal_alignment = "center",
		vertical_alignment = "top",
		size = { ROW_WIDTH, BOON_CARD_HEIGHT - 10 },
		position = { 0, (i - 1) * BOON_CARD_HEIGHT, 21 },
	}
end

-- One scenegraph node per row, stacked downwards. Generated rather than written out
-- eight times, because eight copies of the same block is eight places to fix a typo.
for i = 1, MAX_LEG_ROWS do
	scenegraph_definition["row_" .. i] = {
		parent = "rows",
		horizontal_alignment = "center",
		vertical_alignment = "top",
		size = { ROW_WIDTH, ROW_HEIGHT },
		position = { 0, (i - 1) * ROW_HEIGHT, 21 },
	}
end

-- v0.22.31: tab buttons. Three at first: Route (the default), Party
-- (bot roster) and Emporium (shop). Left-aligned inside the tab bar so
-- the balance readout has room on the right when the shop is up.
-- Progression will slot in later as a fourth tab; the position formula
-- ((i - 1) * (TAB_BUTTON_WIDTH + 8)) already accounts for that without
-- needing per-tab tuning.
-- v0.28.74: six compact buttons fit the Realm tab between Loadout and the
-- bot Party tab without colliding with the right-aligned Ordos readout.
local TAB_BUTTON_WIDTH  = 145
local TAB_BUTTON_HEIGHT = 40
-- v0.22.77 (Session B phase 2): fourth tab, Penances. v0.22.81: fifth
-- tab, Loadout (Boon Loadout; Kaizen: own tab, room to grow). 5 tabs
-- occupy 932px of the 1100px tab bar; the balance readout keeps its
-- right-side room, and the Loadout tab shows it too since boons cost
-- Ordos.
local TAB_COUNT         = 6
for i = 1, TAB_COUNT do
	scenegraph_definition["tab_" .. i] = {
		parent = "tab_bar",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = { TAB_BUTTON_WIDTH, TAB_BUTTON_HEIGHT },
		position = { (i - 1) * (TAB_BUTTON_WIDTH + 8), 0, 21 },
	}
end

M.TAB_COUNT = TAB_COUNT
-- v0.22.82: Loadout moved LEFT of Party per Kaizen's field feedback
-- (build order reads route -> doctrines -> warband -> shop -> records).
M.TAB_LABELS = { "Route", "Loadout", "Realm", "Party", "Emporium", "Penances" }
-- Internal mode names, per index. "route" is a superset that includes
-- draft (a mid-route boon pick). party and shop are the new tabs;
-- penances landed with v0.22.77, loadout with v0.22.81.
M.TAB_MODES  = { "route", "loadout", "realm", "party", "shop", "penances" }

-- ---------------------------------------------------------------------------
-- Text styles
--
-- Cloned from the game's own settings so the view inherits the correct font, outline and
-- render scale. Cloned and not referenced: these tables are shared, and mutating one in
-- place would restyle unrelated menus.
-- ---------------------------------------------------------------------------

local function _text_style(base, size, colour, alignment)
	local style = table.clone(base)
	style.font_size = size
	style.text_color = colour
	style.text_horizontal_alignment = alignment or "center"
	style.text_vertical_alignment = "center"
	style.horizontal_alignment = alignment or "center"
	style.vertical_alignment = "center"
	style.offset = { 0, 0, 2 }
	return style
end

local COLOUR_TITLE    = { 255, 255, 226, 168 }
local COLOUR_BODY     = { 255, 219, 219, 219 }
local COLOUR_DIM      = { 255, 150, 150, 150 }

-- ---------------------------------------------------------------------------
-- Widgets
-- ---------------------------------------------------------------------------

local widget_definitions = {
	-- The backing plate. Two passes: a dark rectangle for readability, and the game's
	-- dropshadow frame so it reads as a panel sitting above the world rather than a
	-- rectangle painted on it.
	panel = UIWidget.create_definition({
		{
			pass_type = "rect",
			style = {
				color = { 235, 12, 12, 14 },
				offset = { 0, 0, 0 },
			},
		},
		{
			pass_type = "texture",
			value = "content/ui/materials/frames/dropshadow_medium",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				scale_to_material = true,
				color = { 255, 0, 0, 0 },
				size_addition = { 40, 40 },
				offset = { 0, 0, 1 },
			},
		},
		{
			pass_type = "texture",
			value = "content/ui/materials/frames/line_thin_detailed_01",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				scale_to_material = true,
				color = { 190, 140, 120, 90 },
				offset = { 0, 0, 2 },
			},
		},
	}, "panel"),

	title = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "text",
			value = "PILGRIMAGE",
			value_id = "text",
			style = _text_style(UIFontSettings.header_1 or UIFontSettings.hud_body, 42, COLOUR_TITLE),
		},
	}, "title"),

	subtitle = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "text",
			value = "",
			value_id = "text",
			style = _text_style(UIFontSettings.body or UIFontSettings.hud_body, 20, COLOUR_DIM),
		},
	}, "subtitle"),

	-- v0.22.31: Ordos balance readout for the Emporium tab. Hidden on
	-- Route and Party. Draws the current balance in gold so it reads
	-- like a price tag rather than a description; the number is what
	-- matters, not the label.
	balance_label = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "text",
			value = "",
			value_id = "text",
			style = (function()
				local style = _text_style(
					UIFontSettings.body or UIFontSettings.hud_body,
					22, COLOUR_TITLE, "right")
				style.horizontal_alignment = "right"
				style.text_horizontal_alignment = "right"
				return style
			end)(),
		},
	}, "balance_label"),

	footer = UIWidget.create_definition({
		{
			pass_type = "text",
			style_id = "text",
			value = "",
			value_id = "text",
			style = _text_style(UIFontSettings.body or UIFontSettings.hud_body, 18, COLOUR_DIM),
		},
	}, "footer"),

	reroll_button = UIWidget.create_definition(ButtonPassTemplates.terminal_button, "reroll_button", {
		visible = true,
		original_text = "Reroll route",
	}),

	begin_button = UIWidget.create_definition(ButtonPassTemplates.terminal_button, "begin_button", {
		visible = true,
		original_text = "Begin pilgrimage",
	}),

	close_button = UIWidget.create_definition(ButtonPassTemplates.terminal_button, "close_button", {
		visible = true,
		original_text = "X",
	}),

	-- v0.22.53: switched to terminal_button (from terminal_button_small)
	-- to match the reroll/begin templates. terminal_button_small's
	-- change_function reads original_text every frame and writes into
	-- content.text; my initial-visible=false plus explicit dirty pass
	-- in _refresh() should have flipped it on, but the small template
	-- has proven quirky in this file before (v0.22.33 text_color
	-- override went sideways for the tab strip). terminal_button
	-- writes content.text directly and has no change_function, so
	-- content.original_text is drawn straight from the widget's own
	-- content field. Also raised initial visible to true so the widget
	-- starts on-screen; _refresh() still gates it on run state.
	plan_button = UIWidget.create_definition(
		ButtonPassTemplates.terminal_button,
		"plan_button",
		{
			visible = true,
			original_text = "Change War Plan",
		}),
}

-- v0.22.31: tab buttons, generated to match the tab_ scenegraph nodes.
-- terminal_button_small is the same pass template the vanilla menus use
-- for their tab strips; borrowing it means our tabs get identical hover
-- glow, click sound and controller navigation for free. route_view.lua's
-- _refresh_tab_bar recolours the active tab so the user knows which
-- content is showing.
for i = 1, TAB_COUNT do
	local label = M.TAB_LABELS[i] or "Tab"
	widget_definitions["tab_" .. i] = UIWidget.create_definition(
		ButtonPassTemplates.terminal_button_small or ButtonPassTemplates.terminal_button,
		"tab_" .. i,
		{
			visible       = true,
			-- terminal_button_small's text pass runs a change_function
			-- that only lerps text_color and never writes content.text
			-- from original_text (unlike the bigger terminal_button
			-- template). So we must set content.text DIRECTLY, otherwise
			-- the widget renders its default placeholder "placeholder_text".
			text          = label,
			original_text = label,
		})
end

-- Each row is four columns and an icon over a faint background bar: assignment
-- number, the circumstance's own icon, the mission name, the condition name, and a
-- right-aligned status. The condition used to ride in brackets inside the name
-- column, which wrapped as soon as a long name met a long condition; giving each
-- its own column is what fixed it.
-- v0.22.31: rows are now clickable so Party (cycle preset) and Emporium
-- (buy SKU) can reuse the same widget without needing a parallel row
-- family. The Route mode ignores the click; the mode dispatches in
-- route_view.lua's _on_row_pressed. Hotspot pass has to be first so
-- rows behind it don't eat the mouse events (hotspot returns hover
-- from the topmost pass in the hit test order the game uses).
local function _row_hover_change(content, style)
	-- v0.22.76: section-header rows in the preset picker are labels,
	-- not options. They render with NO bar at all and never light up,
	-- so they cannot be mistaken for something clickable (Kaizen's
	-- field-test feedback 2026-08-10: headers looked like regular
	-- hoverable options). content.pilg_header is set by
	-- _refresh_preset_pick and cleared centrally in _set_list_visible,
	-- so a reused widget always reverts to normal in other modes.
	if content.pilg_header then
		style.color[1] = 0
		style.color[2] = 0
		style.color[3] = 0
		style.color[4] = 0
		return
	end

	local hotspot = content.hotspot
	local hovered = hotspot and (hotspot.is_hover or hotspot.is_focused)
	-- Slightly brighter background on hover so the eye finds the row it
	-- is about to click, matching the game's own list-row idiom.
	if hovered then
		style.color[1] = 140
		style.color[2] = 60
		style.color[3] = 56
		style.color[4] = 44
	else
		style.color[1] = 60
		style.color[2] = 40
		style.color[3] = 38
		style.color[4] = 34
	end
end

for i = 1, MAX_LEG_ROWS do
	widget_definitions["row_" .. i] = UIWidget.create_definition({
		{
			content_id = "hotspot",
			pass_type = "hotspot",
			style_id = "hotspot",
			content = {
				on_pressed_sound = UISoundEvents and UISoundEvents.default_click or nil,
				on_hover_sound = UISoundEvents and UISoundEvents.default_mouse_hover or nil,
			},
		},
		{
			pass_type = "rect",
			style_id = "bar",
			style = {
				color = { 60, 40, 38, 34 },
				offset = { 0, 0, 0 },
			},
			change_function = _row_hover_change,
		},
		{
			pass_type = "text",
			style_id = "index",
			value = "",
			value_id = "index",
			style = (function()
				local style = _text_style(UIFontSettings.body or UIFontSettings.hud_body, 24, COLOUR_TITLE, "left")
				style.offset = { COL_INDEX_X, 0, 2 }
				-- Sized for "Assignment 12" on one line. The column was 90px when the
				-- label was "Leg 1", and "Assignment" wrapped mid-word inside it.
				style.size = { COL_INDEX_W, ROW_HEIGHT }
				return style
			end)(),
		},
		-- The circumstance icon, the same material the mission board draws for this
		-- condition, in the exact pass shape the board uses
		-- (mission_board_view_blueprints.lua:1740-1752: texture pass, material path
		-- as value, style.visible toggled at runtime). The view only makes it
		-- visible when the residency probe confirms the material is loaded, because
		-- an unloaded material is an engine assert rather than a placeholder.
		{
			pass_type = "texture",
			style_id = "curse_icon",
			value = "content/ui/materials/icons/circumstances/assault_01",
			value_id = "curse_icon",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "center",
				visible = false,
				offset = { COL_ICON_X, 0, 2 },
				size = { COL_ICON_S, COL_ICON_S },
				color = { 255, 255, 255, 255 },
			},
		},
		{
			pass_type = "text",
			style_id = "name",
			value = "",
			value_id = "name",
			style = (function()
				local style = _text_style(UIFontSettings.body or UIFontSettings.hud_body, 22, COLOUR_BODY, "left")
				style.offset = { COL_NAME_X, 0, 2 }
				style.size = { COL_NAME_W, ROW_HEIGHT }
				return style
			end)(),
		},
		-- The condition, in its own column at last. The view recolours it by
		-- severity, so the eye can find the assignment that will hurt.
		{
			pass_type = "text",
			style_id = "condition",
			value = "",
			value_id = "condition",
			style = (function()
				local style = _text_style(UIFontSettings.body or UIFontSettings.hud_body, 20, COLOUR_DIM, "left")
				style.offset = { COL_COND_X, 0, 2 }
				style.size = { COL_COND_W, ROW_HEIGHT }
				return style
			end)(),
		},
		-- Status lives in its own right-aligned column. The first version appended it to
		-- the leg number, which wrapped "Leg 1 done" onto two lines inside a 52px row and
		-- looked like a mistake, because it was one.
		{
			pass_type = "text",
			style_id = "status",
			value = "",
			value_id = "status",
			style = (function()
				local style = _text_style(UIFontSettings.body_small or UIFontSettings.hud_body, 18, COLOUR_DIM, "right")
				style.horizontal_alignment = "right"
				style.text_horizontal_alignment = "right"
				style.offset = { -20, 0, 2 }
				style.size = { COL_STATUS_W, ROW_HEIGHT }
				return style
			end)(),
		},
	}, "row_" .. i)
end

-- ---------------------------------------------------------------------------
-- Boon cards
--
-- BUILT FROM SCRATCH, NOT FROM ButtonPassTemplates, and that is deliberate.
--
-- The first version cloned terminal_button_small and appended two text passes to it. In
-- game the cards did not draw AT ALL, not even the button's own background, so the fault
-- was the widget rather than the text. Rather than guess at which of that template's six
-- passes and two change_functions was unhappy about being cloned and extended, the cards
-- are now assembled from the exact pass types the leg rows already use in this same view
-- and which are therefore known to render here: a rect and two texts.
--
-- The only new pass type is "hotspot", which is what makes a card clickable. That leaves
-- exactly one unknown instead of a whole template's worth.
--
-- The cost is that hover has to be drawn by hand, which is the change_function below.
-- ---------------------------------------------------------------------------

local BOON_IDLE  = { 70, 40, 38, 34 }
local BOON_HOVER = { 200, 74, 66, 52 }

-- ---------------------------------------------------------------------------
-- The icon
--
-- Drawn exactly the way the game's own tactical overlay draws these same buffs
-- (hud_element_tactical_overlay.lua:371-380), because matching it means the boon looks
-- like a real indulgence rather than a mod's approximation of one.
--
-- The shape is: one MATERIAL, which is a shader, plus a set of named TEXTURES fed into
-- it. talent_icon_container composites a hexagonal frame, a mask, the icon itself and a
-- colour ramp. Only "icon" and "gradient_map" change per boon; the frame and mask are
-- the same every time and are always resident, which is why an unloaded icon shows up
-- as an empty hexagon rather than as nothing at all.
--
-- The values below are the neutral defaults. route_view.lua overwrites icon and
-- gradient_map per card and then sets widget.dirty, which is required: material_values
-- are pushed to the GPU when the widget is rebuilt, not when the table is written
-- (hud_element_player_buffs_polling.lua:483-487 does the same dance).
-- ---------------------------------------------------------------------------

local ICON_SIZE = 64

M.BOON_ICON_MATERIAL = "content/ui/materials/frames/talents/talent_icon_container"
M.BOON_ICON_FRAME    = "content/ui/textures/frames/horde/hex_frame_horde"
M.BOON_ICON_MASK     = "content/ui/textures/frames/horde/hex_frame_horde_mask"
M.BOON_ICON_DEFAULT  = "content/ui/textures/placeholder_texture"
M.BOON_GRADIENT_DEFAULT = "content/ui/textures/color_ramps/talent_ability"

-- Runs every frame for the card. content.hotspot is populated by the hotspot pass, and
-- is_hover is set by the renderer when the cursor is over the widget's scenegraph node.
-- Mutating style.color IN PLACE rather than assigning a new table, because the renderer
-- holds a reference to this exact one.
local function boon_hover_change_function(content, style)
	local hotspot = content.hotspot
	local hovered = hotspot and (hotspot.is_hover or hotspot.is_focused)
	local target = hovered and BOON_HOVER or BOON_IDLE

	for i = 1, 4 do style.color[i] = target[i] end
end

for i = 1, 3 do
	widget_definitions["boon_" .. i] = UIWidget.create_definition({
		{
			-- content_id is what puts the hotspot table at content.hotspot, which is
			-- where the pressed_callback gets attached and where is_hover is read from.
			content_id = "hotspot",
			pass_type = "hotspot",
			style_id = "hotspot",
			content = {
				on_pressed_sound = UISoundEvents and UISoundEvents.default_click or nil,
				on_hover_sound = UISoundEvents and UISoundEvents.default_mouse_hover or nil,
			},
		},
		{
			pass_type = "rect",
			style_id = "card",
			style = {
				color = { BOON_IDLE[1], BOON_IDLE[2], BOON_IDLE[3], BOON_IDLE[4] },
				offset = { 0, 0, 0 },
			},
			change_function = boon_hover_change_function,
		},
		{
			-- scale_to_material is what tells the renderer to instantiate the material
			-- rather than blit the value string as a plain texture. Without it the
			-- material_values below are ignored entirely (ui_passes.lua:118).
			pass_type = "texture",
			style_id = "boon_icon",
			value = M.BOON_ICON_MATERIAL,
			value_id = "boon_icon",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "top",
				scale_to_material = true,
				offset = { 18, 16, 2 },
				size = { ICON_SIZE, ICON_SIZE },
				color = { 255, 255, 255, 255 },
				material_values = {
					frame = M.BOON_ICON_FRAME,
					icon_mask = M.BOON_ICON_MASK,
					intensity = 0,
					saturation = 1,
					texture_map = "",
					icon = M.BOON_ICON_DEFAULT,
					gradient_map = M.BOON_GRADIENT_DEFAULT,
				},
			},
		},
		{
			-- v0.28.7: direct SimpleAssets glyph layer. Hordes icon paths are
			-- bundled with Mortis and can disappear after a restart even though
			-- the surrounding hex material remains. A url-loaded texture object is
			-- supported in `texture_map`, so draw the bundled category glyph over a
			-- solid gradient-filled hex instead of accepting the warning symbol.
			pass_type = "texture",
			texture = nil,
			style_id = "boon_custom_icon",
			style = {
				horizontal_alignment = "left",
				vertical_alignment = "top",
				offset = { 30, 28, 3 },
				size = { 40, 40 },
				color = { 255, 255, 255, 255 },
				material_values = {
					texture_map = nil,
				},
			},
			visibility_function = function(content, style)
				return style.material_values.texture_map ~= nil
			end,
		},
		{
			pass_type = "text",
			style_id = "boon_title",
			value = "",
			value_id = "boon_title",
			style = (function()
				local style = _text_style(UIFontSettings.body or UIFontSettings.hud_body, 24, COLOUR_TITLE, "left")
				style.vertical_alignment = "top"
				style.text_vertical_alignment = "top"
				-- Indented past the icon. The right edge stays where it was, so the text
				-- box is narrower rather than wider.
				style.offset = { 24 + ICON_SIZE + 16, 14, 2 }
				style.size = { ROW_WIDTH - 48 - ICON_SIZE - 16, 30 }
				return style
			end)(),
		},
		{
			pass_type = "text",
			style_id = "boon_body",
			value = "",
			value_id = "boon_body",
			style = (function()
				local style = _text_style(UIFontSettings.body_small or UIFontSettings.hud_body, 18, COLOUR_BODY, "left")
				style.vertical_alignment = "top"
				style.text_vertical_alignment = "top"
				style.offset = { 24 + ICON_SIZE + 16, 48, 2 }
				style.size = { ROW_WIDTH - 48 - ICON_SIZE - 16, BOON_CARD_HEIGHT - 62 }
				return style
			end)(),
		},
	}, "boon_" .. i)
end

M.scenegraph_definition = scenegraph_definition
M.widget_definitions = widget_definitions

return M
