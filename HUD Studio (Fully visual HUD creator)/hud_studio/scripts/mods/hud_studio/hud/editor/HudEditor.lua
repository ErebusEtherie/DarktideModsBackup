

---@class mod : DL_Mod
local mod = get_mod("hud_studio")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local Session = mod:core(mod.hud_studio_session, "document/session")
local History = mod:core(mod.hud_studio_history, "document/history")
local NodeTypes = mod:core(mod.hud_studio_node_registry, "blocks/registry")
local NodeForm = mod:core(mod.hud_studio_node_form, "hud/editor/forms/node_form")
local BlockForm = mod:core(mod.hud_studio_block_form, "hud/editor/forms/block_form")
local CanvasForm = mod:core(mod.hud_studio_canvas_form, "hud/editor/forms/canvas_form")
local DarktideCanvasForm = mod:core(mod.hud_studio_darktide_canvas_form, "hud/editor/forms/darktide_canvas_form")
local FolderForm = mod:core(mod.hud_studio_folder_form, "hud/editor/forms/folder_form")
local Visibility = mod:core(mod.hud_studio_visibility, "blocks/visibility")
local Rebind = mod:core(mod.hud_studio_rebind, "document/rebind")
local Row = mod:core(mod.row_component, "hud/editor/elements/row/row")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")
local TextMetrics = mod:core(mod.hud_studio_text_metrics, "hud/editor/text_metrics")

local ColorPickerController =
	mod:core(mod.hud_studio_color_picker_controller, "hud/editor/elements/color_picker/color_picker_controller")
local BrowserLoader = mod:core(mod.hud_studio_browser_loader, "assets/browser_loader")
local BlockLibraryLayout =
	mod:core(mod.hud_studio_block_library_layout, "hud/editor/elements/block_library/block_library_layout")
local LibraryController =
	mod:core(mod.hud_studio_block_library_controller, "hud/editor/elements/block_library/block_library_controller")

local BlockLibrary = mod:core(mod.hud_studio_block_library, "document/block_library")
local BrowserData = mod:core(mod.hud_studio_material_categories, "assets/material_categories")
local Constants = mod:core(mod.editor_constants, "hud/editor/constants")
local RectNode = mod:core(mod.nodes_rect, "blocks/node_types/rect")
local ProgressBarNode = mod:core(mod.nodes_progress_bar, "blocks/node_types/progress_bar")
local DrawCalls = mod:core(mod.draw_calls, "hud/editor/elements/draw_calls")
local Outlines = mod:core(mod.outlines_component, "hud/editor/elements/outlines/outlines")
local Grid = mod:core(mod.grid_component, "hud/editor/elements/grid/grid")

local PanelHeader = mod:core(mod.panel_header_component, "hud/editor/elements/panel/panel_header")
local PanelBody = mod:core(mod.panel_body_component, "hud/editor/elements/panel/panel_body")
local BlocksPanel = mod:core(mod.blocks_panel_component, "hud/editor/elements/blocks_panel/blocks_panel")
local BrowserController =
	mod:core(mod.hud_studio_browser_controller, "hud/editor/elements/material_browser/material_browser_controller")

local TdController =
	mod:core(mod.hud_studio_td_controller, "hud/editor/elements/threshold_designer/threshold_designer_controller")
local CbController =
	mod:core(mod.hud_studio_cb_controller, "hud/editor/elements/condition_builder/condition_builder_controller")
local ConditionBuilderPanel =
	mod:core(mod.condition_builder_panel_component, "hud/editor/elements/condition_builder/condition_builder_panel")
local ThresholdDesignerPanel =
	mod:core(mod.threshold_designer_panel_component, "hud/editor/elements/threshold_designer/threshold_designer_panel")
local ThresholdBar =
	mod:core(mod.hud_studio_threshold_bar_component, "hud/editor/elements/threshold_designer/threshold_bar")

local Conditions = mod:core(mod.hud_studio_conditions, "blocks/conditions")

local CodeEditor = mod:core(mod.editor_code_editor, "hud/editor/editors/code_editor/code_editor")
local IdeController = mod:core(mod.hud_studio_ide_controller, "hud/editor/elements/ide/ide_controller")

local Button = mod:core(mod.hud_studio_button_component, "hud/editor/elements/button/button")
local EditorIcons = mod:core(mod.editor_icons, "hud/editor/elements/icon/editor_icons")
local Label = mod:core(mod.hud_studio_label_component, "hud/editor/elements/field/label")
local TextInput = mod:core(mod.hud_studio_text_input_component, "hud/editor/elements/field/text_input")
local Numeric = mod:core(mod.hud_studio_numeric_component, "hud/editor/elements/field/numeric")
local Dropdown = mod:core(mod.hud_studio_dropdown_component, "hud/editor/elements/field/dropdown")

local DropdownController = mod:core(mod.hud_studio_dropdown_controller, "hud/editor/elements/field/dropdown_controller")

local ContextMenu = mod:core(mod.hud_studio_context_menu, "hud/editor/elements/context_menu/context_menu_panel")
local ContextMenuController =
	mod:core(mod.hud_studio_context_menu_controller, "hud/editor/elements/context_menu/context_menu_controller")
local Checkbox = mod:core(mod.hud_studio_checkbox_component, "hud/editor/elements/field/checkbox")
local Checklist = mod:core(mod.hud_studio_checklist_component, "hud/editor/elements/field/checklist")
local Tooltip = mod:core(mod.tooltip_component, "hud/editor/elements/tooltip/tooltip")
local Rgba = mod:core(mod.hud_studio_rgba_component, "hud/editor/elements/field/rgba")

local BlocksTree = mod:core(mod.hud_studio_blocks_tree, "hud/editor/models/blocks_tree")

local DragController = mod:core(mod.hud_studio_drag_controller, "hud/editor/input/drag_controller")

local KeyboardNav = mod:core(mod.hud_studio_keyboard_nav, "hud/editor/input/keyboard_nav")

local clamp = math.clamp

local RESOLUTION_LOOKUP = rawget(_G, "RESOLUTION_LOOKUP")

local C = Constants
local PANEL = Constants.PANEL
local COLOR = Constants.COLOR
local Z = Constants.Z

local ROW_FONT_SIZE = 16

local function panel_pos_key(id, axis)
	return "__hs_panel_pos_" .. id .. "_" .. axis
end

---@return table
local function new_pos(id, default_x, default_y)
	local x = mod:get(panel_pos_key(id, "x"))
	local y = mod:get(panel_pos_key(id, "y"))
	return {
		x = type(x) == "number" and x or default_x,
		y = type(y) == "number" and y or default_y,
	}
end

local ACC_CLOSED_KEY = "__hs_closed_sections"

local ACC_CLOSED_SEED = { "script", "tools", "transitions", "visibility" }

---@return table<string, boolean>
local function load_acc_open()
	local open = {}
	local stored = mod:get(ACC_CLOSED_KEY)
	if type(stored) ~= "string" then
		for i = 1, #ACC_CLOSED_SEED do
			open[ACC_CLOSED_SEED[i]] = false
		end
		return open
	end
	for key in stored:gmatch("[^,]+") do
		open[key] = false
	end
	return open
end

---@param open table<string, boolean>
local function store_acc_open(open)
	local keys = {}
	for key, is_open in pairs(open) do
		if not is_open then
			keys[#keys + 1] = key
		end
	end

	table.sort(keys)
	mod:set(ACC_CLOSED_KEY, table.concat(keys, ","))
end

local LABEL_COLUMN_KEY = "__hs_label_column"

local RENAME_TOKEN = "row_rename"
local ROW_DOUBLE_CLICK_S = 0.35

local Geometry = mod:core(mod.editor_geometry, "hud/editor/layout/geometry")
local Format = mod:core(mod.editor_format, "hud/editor/format")

local HudScale = mod:core(mod.hud_studio_scale, "blocks/hud_scale")
local node_bounds = Geometry.node_bounds
local node_resizable = Geometry.node_resizable
local resize_handle_bounds = Geometry.resize_handle_bounds
local node_rotatable = Geometry.node_rotatable
local rotate_handle_bounds = Geometry.rotate_handle_bounds
local block_bounds = Geometry.block_bounds
local block_scalable = Geometry.block_scalable
local block_scale_handle_bounds = Geometry.block_scale_handle_bounds
local point_in = Geometry.point_in
local in_rect = Geometry.in_rect

---@param v number       cursor coordinate (design px, one axis)
---@param center number  design-space screen centre on that axis (dcx / dcy)
---@param scale number   HUD-scale zoom (must be > 0)
---@return number
local function to_canvas(v, center, scale)
	return center + (v - center) / scale
end

---@class HudEditor
---@field _d Draw                 -- floating tool panels (mutable design-px pos)
---@field _panels table[]                 -- floating tool panels (mutable design-px pos)
---@field _tree BlocksTree                  -- the Blocks-tree model: rows + fold / scroll / hover state
---@field _sel_block integer | nil         -- selected block (index into session blocks)
---@field _sel_node integer | nil          -- selected node within that block; nil = block-level
---@field _sel_canvas boolean | nil        -- the Mod Canvas row is selected (document-level settings)
---@field _sel_darktide boolean | nil      -- the Darktide Canvas row is selected (vanilla-HUD toggles)
---@field _sel_folder table | nil         -- { name } of the selected folder row (folder_form owns the Property panel)
---@field _edit_block integer | nil        -- block in node-editing mode (canvas node grab + exit button)
---@field _deselect_armed boolean | nil    -- a node is active and one away-click already landed; the next away-click deselects it (or switches to the block under it)
---@field _hover_block integer | nil       -- canvas block under the cursor
---@field _hover_node integer | nil        -- canvas node (ni within _edit_block) under the cursor
---@field _hover_row_eye boolean | nil     -- cursor is over the hovered tree row's eye toggle (_tree.hover_row)
---@field _drag table | nil               -- { kind="panel"|"block"|"node"|"reorder"|"textsel", ... }
---@field _arrow table | nil               -- held arrow-key nudge { dx, dy, next_at, dirty }
---@field _cursor_pushed boolean | nil
---@field _panel_pos table | nil           -- persistent { blocks={x,y}, property={x,y} }, survives reloads
---@field _ui_renderer table | nil         -- this frame's renderer, cached for text measuring in input
---@field _acc_open table<string, boolean> -- accordion section key -> expanded
---@field _acc_hover table | nil           -- hovered form item (header/field), for tint
---@field _dropdown table | nil            -- open dropdown popup { ctrl, scroll, scroll_accum }
---@field _dropdown_hover integer | nil    -- hovered option index in the open popup
---@field _colorpicker table | nil         -- open colour picker { ctrl, h, s, l, a, saved_index } (live HSL state)
---@field _node_form table | nil           -- this frame's laid-out form { items, height }
---@field _form_sections table | nil       -- cached sections, rebuilt on selection change
---@field _form_node table | nil           -- node the cached sections were built for
---@field _label_column boolean          -- Property panel: group names in their own left column
local HudEditor = class("HudEditor", "HudElementBase")

HudEditor.init = function(self, parent, draw_layer, start_scale)
	HudEditor.super.init(self, parent, draw_layer, start_scale, {

		scenegraph_definition = {
			screen = UIWorkspaceSettings.screen,
		},

		widget_definitions = {
			editor = UIWidget.create_definition({
				{
					pass_type = "logic",
					style_id = "editor",
					value = function(...)
						self:_draw(...)
					end,
					style = {
						horizontal_alignment = "left",
						vertical_alignment = "top",
						offset = { 0, 0, 1 },
					},
				},
			}, "screen"),
		},
	})

	local pos = mod:persistent_table("editor_panel_pos")
	pos.blocks = pos.blocks or new_pos("blocks", 40, 140)
	pos.property = pos.property or new_pos("property", 40, 440)
	pos.ide = pos.ide or new_pos("ide", 470, 200)
	pos.browser = pos.browser or new_pos("browser", 500, 150)
	pos.threshold = pos.threshold or new_pos("threshold", 470, 200)
	pos.condition = pos.condition or new_pos("condition", 400, 200)
	pos.library = pos.library or new_pos("library", 420, 160)
	self._panel_pos = pos
	self._panels = {
		{
			id = "blocks",
			title = mod:localize("panel_blocks_title"),
			x = pos.blocks.x,
			y = pos.blocks.y,
			w = PANEL.BLOCKS_WIDTH,
			z = Z.PANEL_BLOCKS,
		},
		{
			id = "property",
			title = mod:localize("panel_properties_title"),
			x = pos.property.x,
			y = pos.property.y,
			w = PANEL.DESIGNER_WIDTH,
			z = Z.PANEL_PROPERTIES,
		},
	}

	self._ide_panel =
		{ id = "ide", title = mod:localize("panel_ide_title"), x = pos.ide.x, y = pos.ide.y, w = PANEL.IDE_WIDTH }

	self._browser_panel = {
		id = "browser",
		title = mod:localize("panel_texture_browser_title"),
		x = pos.browser.x,
		y = pos.browser.y,
		w = PANEL.BROWSER_WIDTH,
	}

	self._td_panel = {
		id = "threshold",
		title = mod:localize("panel_threshold_title"),
		x = pos.threshold.x,
		y = pos.threshold.y,
		w = PANEL.THRESHOLD_WIDTH,
	}

	self._cb_panel = {
		id = "condition",
		title = mod:localize("panel_condition_title"),
		x = pos.condition.x,
		y = pos.condition.y,
		w = PANEL.CONDITION_WIDTH,
	}

	self._library_panel = {
		id = "library",
		title = mod:localize("panel_library_title"),
		x = pos.library.x,
		y = pos.library.y,
		w = BlockLibraryLayout.WIDTH,
	}

	---@type MaterialBrowserCategory[]
	self._browser_cats = {}
	local cat_ids = BrowserData.categories or {}
	for i = 1, #cat_ids do
		local id = cat_ids[i]
		self._browser_cats[i] =
			{ id = id, label = mod:localize(id), mats = BrowserData.categorised_materials[id] or {} }
	end

	self._tree = BlocksTree.new(function()
		return self:_blocks_panel()
	end)
	self._sel_block = nil
	self._sel_node = nil

	self._rename = nil
	self._last_row_click = nil

	self._sel_canvas = nil

	self._sel_darktide = nil
	self._sel_folder = nil
	self._edit_block = nil
	self._deselect_armed = nil
	self._hover_block = nil
	self._hover_node = nil
	self._hover_row_eye = nil

	self._delblock_hover = nil
	self._ui_renderer = nil
	self._drag = nil

	self._acc_open = load_acc_open()

	local stored_label_column = mod:get(LABEL_COLUMN_KEY)
	self._label_column = stored_label_column == nil or stored_label_column == true
	self._acc_hover = nil
	self._dropdown = nil
	self._dropdown_hover = nil
	self._colorpicker = nil
	self._node_form = nil
	self._form_sections = nil
	self._form_node = nil

	self._ide = nil
	self._ide_lay = nil

	self._ide_hover = {}

	self._ide_docs_path = {}

	self._ide_commit = function(recompile)
		return self:_commit_edit(recompile)
	end

	self._ide_baseline = nil
	self._ide_reset = function()
		return self:_reset_ide_changes()
	end

	self._ide_set_baseline = function(text)
		self._ide_baseline = text
	end

	self._ide_begin_drag = function(cx, cy)
		self._drag = DragController.panel(self._ide_panel, cx, cy)
	end
	self._ide_press_textbox = function(ctrl, box, cx, cy, is_numeric)
		return self:_press_textbox(ctrl, box, cx, cy, is_numeric)
	end

	self._field_commit = function(recompile)
		return self:_commit_edit(recompile)
	end

	self._field_edit = function(ctrl, value)
		return self:_edit_field(ctrl, value)
	end

	self._dropdown_close = function()
		self._dropdown = nil
	end
	self._dropdown_set_hover = function(i)
		self._dropdown_hover = i
	end

	---@type MaterialBrowserState?
	self._browser = nil
	---@type BrowserLayout?
	self._browser_lay = nil

	---@type MaterialBrowserHover
	self._browser_hover = {}

	self._browser_close = function()
		self:_close_browser()
	end
	self._browser_do_assign = function(material)
		self:_browser_assign(material)
	end
	self._browser_begin_drag = function(cx, cy)
		self._drag = DragController.panel(self._browser_panel, cx, cy)
	end

	self._td = nil
	self._td_lay = nil
	self._td_close_hover = nil

	self._td_ctrls = { node = nil, field = nil, pct = {}, value = {} }

	self._td_draw_field = function(item, z)
		self:_draw_field(item, z)
	end

	self._cb = nil
	self._cb_lay = nil
	self._cb_close_hover = nil

	self._cb_ctrls = {}
	self._cb_draw_field = function(item, z)
		self:_draw_field(item, z)
	end

	---@type BlockLibraryState?
	self._library = nil
	---@type LibraryLayout?
	self._library_lay = nil
	---@type BlockLibraryHover
	self._library_hover = {}

	self._library_close = function()
		self:_close_library()
	end
	self._library_reveal = function(index)
		self:_library_added(index)
	end
	self._library_begin_drag = function(cx, cy)
		self._drag = DragController.panel(self._library_panel, cx, cy)
	end
end

HudEditor.destroy = function(self, ui_renderer)

	BrowserLoader.release_all()
	Session.set_force_visible(nil, nil)
	self:_pop_cursor()
	HudEditor.super.destroy(self, ui_renderer)
end

---@return boolean
function HudEditor.edit_mode()
	return mod.hud_studio_editor_active == true
end

---@return boolean
HudEditor.using_input = function(self)
	return self.edit_mode()
end

HudEditor._push_cursor = function(self)
	if self._cursor_pushed then
		return
	end
	Managers.input:push_cursor(self.__class_name)
	self._cursor_pushed = true
end

HudEditor._pop_cursor = function(self)
	if not self._cursor_pushed then
		return
	end
	Managers.input:pop_cursor(self.__class_name)
	self._cursor_pushed = nil
end

HudEditor._dismiss_popups = function(self)
	TextField.commit()
	self._dropdown = nil
	self._colorpicker = nil
end

HudEditor._save = function(self, bi, what)

	local ok, reason
	if bi then
		ok, reason = Session.save(bi)
	else
		reason = "not in the document"
	end
	if not ok then
		mod.dl.log.error("failed to save %s: %s", what or "block", tostring(reason))
	end
end

HudEditor._save_canvas = function(self, what)
	local ok, reason = Session.save_canvas()
	if not ok then
		mod.dl.log.error("failed to save %s: %s", what or "canvas", tostring(reason))
	end
end

HudEditor._clear_hover = function(self)
	self._hover_block = nil
	self._hover_node = nil
	self._tree.hover_row = nil
	self._hover_row_eye = nil
	self._delblock_hover = nil
	self._acc_hover = nil
end

HudEditor._clear_frame_hover = function(self)
	self._hover_block = nil
	self._hover_node = nil
	self._tree.hover_row = nil
	self._hover_row_eye = nil
	self._acc_hover = nil
	self._rgba_copy_hover = nil
	self._rgba_paste_hover = nil
end

HudEditor._new_folder = function(self)
	local name = "New Folder"
	local n = 2
	while Session.folder_exists(name) do
		name = "New Folder " .. n
		n = n + 1
	end
	local ok, reason = Session.folder_create(name)
	if not ok then
		mod.dl.log.error("failed to create folder: %s", tostring(reason))
		return
	end

	self:_select_folder(name)
	self:_begin_folder_rename(name)
end

---@return table blocks_panel
HudEditor._blocks_panel = function(self)
	local panels = self._panels
	for i = 1, #panels do
		if panels[i].id == "blocks" then
			return panels[i]
		end
	end
	return panels[1]
end

---@return table property_panel
HudEditor._property_panel = function(self)
	local panels = self._panels
	for i = 1, #panels do
		if panels[i].id == "property" then

			panels[i].w = self._label_column and PANEL.DESIGNER_WIDTH_LABELLED or PANEL.DESIGNER_WIDTH
			return panels[i]
		end
	end
	return panels[#panels]
end

---@return boolean
HudEditor._toggle_label_column = function(self)
	self._label_column = not self._label_column
	mod:set(LABEL_COLUMN_KEY, self._label_column)
	return self._label_column
end

HudEditor._store_panel_pos = function(self, panel)
	mod:set(panel_pos_key(panel.id, "x"), panel.x)
	mod:set(panel_pos_key(panel.id, "y"), panel.y)
end

---@param on boolean
HudEditor._set_hide_hidden = function(self, on)
	Session.canvas().hide_hidden_in_editor = on or nil
	self:_save_canvas("hide hidden blocks")
end

HudEditor._save_panel_pos = function(self, panel)
	local slot = self._panel_pos and self._panel_pos[panel.id]
	if slot then
		slot.x = panel.x
		slot.y = panel.y
	end
end

---@param ui_renderer UIRenderer
---@param text string
---@param max_w number
---@return string[]
local function wrap_note(ui_renderer, text, max_w)
	local lines = {}
	local line = nil
	for word in tostring(text):gmatch("%S+") do
		local candidate = line and (line .. " " .. word) or word
		if line and TextMetrics.measure(ui_renderer, candidate) > max_w then
			lines[#lines + 1] = line
			line = word
		else
			line = candidate
		end
	end
	lines[#lines + 1] = line or ""
	return lines
end

HudEditor._rebuild_node_form = function(self)

	local canvas = (self._sel_canvas or self._sel_darktide) and Session.canvas() or nil

	local folder = self._sel_folder
	if folder and not Session.folder_exists(folder.name) then
		folder = nil
		self._sel_folder = nil
	end
	local block = not canvas and not folder and self._sel_block and Session.block_at(self._sel_block) or nil

	local mod_block = Session.is_mod_block(block)
	local node = not mod_block and block and self._sel_node and block.nodes[self._sel_node] or nil
	local owner = canvas or folder or node or (block and (mod_block or self._sel_node == nil) and block) or nil
	if not owner then
		self._node_form = nil
		self._form_sections = nil
		self._form_node = nil
		self._form_mode = nil
		return
	end

	local mode = self._sel_darktide and "darktide"
		or (self._sel_canvas and "canvas")
		or (folder and ("folder:" .. tostring(folder.name)))
		or nil
	if self._form_node ~= owner or self._form_mode ~= mode then
		if self._sel_darktide then
			self._form_sections = DarktideCanvasForm.build(canvas)
		elseif folder then
			self._form_sections = FolderForm.build(folder)
		elseif canvas then
			self._form_sections = CanvasForm.build(canvas)
		elseif node then
			local node_type = NodeTypes.get(node.type)
			local prefix = tostring(self._sel_block) .. ":" .. tostring(self._sel_node)
			self._form_sections = NodeForm.build(node, node_type, prefix, block)
		else
			self._form_sections = BlockForm.build(block)
		end
		self._form_node = owner
		self._form_mode = mode
	end

	local panel = self:_property_panel()
	local body_x = panel.x
	local body_y = panel.y + PANEL.TITLE_H + PANEL.PAD

	self._node_form = NodeForm.layout(self._form_sections, self._acc_open, body_x, body_y, panel.w, {
		text_rows = function(ctrl, content_w)
			if not self._ui_renderer then
				return 1
			end
			local rows = TextMetrics.multiline_rows(self._ui_renderer, ctrl, content_w)
			return #rows
		end,

		note_lines = function(ctrl, content_w)
			if not self._ui_renderer then
				return nil
			end
			return wrap_note(self._ui_renderer, ctrl.value() or "", content_w)
		end,

		label_column = self._label_column,
	})
end

---@param panel table
---@return number height
HudEditor._panel_height = function(self, panel)
	if panel.id == "blocks" then
		local rows = self._tree:current_rows()
		return BlocksPanel.height(#rows)
	end

	local content = PANEL.DESIGNER_MIN_H
	if self._node_form then
		content = math.max(content, self._node_form.height)
	end
	return PANEL.TITLE_H + PANEL.PAD + content + PANEL.PAD
end

---@return table|nil panel, string|nil region, integer|nil row
HudEditor._panel_at = function(self, px, py)
	local panels = self._panels
	for i = #panels, 1, -1 do
		local p = panels[i]
		local h = self:_panel_height(p)
		if point_in(px, py, p.x, p.y, p.x + p.w, p.y + h) then
			if py <= p.y + PANEL.TITLE_H then
				return p, "title", nil
			end
			if p.id == "blocks" then

				local rows = self._tree:current_rows()
				local region, row = BlocksPanel.body_region(p, #rows, py, self._tree.scroll)
				return p, region, row
			end
			return p, "body", nil
		end
	end
	return nil, nil, nil
end

local function round_dec(v, decimals)
	return tonumber(string.format("%." .. (decimals or 0) .. "f", v)) or v
end

local function copy_value(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, val in pairs(v) do
		out[k] = val
	end
	return out
end

HudEditor._commit_edit = function(self, recompile)

	if self._sel_canvas or self._sel_darktide then
		self:_save_canvas()
		return
	end

	if self._sel_folder then
		self:_save_canvas()
		return
	end
	if not self._sel_block then
		return
	end
	if recompile then
		local block = Session.block_at(self._sel_block)
		if block then
			block:recompile()
		end
	end
	self:_save(self._sel_block)
end

---@param ctrl table
---@param before any
---@param after any
HudEditor._record_field = function(self, ctrl, before, after)

	if ctrl.no_undo then
		return
	end
	local rebinds = ctrl.rebinds and true or false
	local owner = not (self._sel_canvas or self._sel_darktide or self._sel_folder)
		and self._sel_block
		and Session.block_at(self._sel_block)
		or nil
	History.record(
		History.call("field", ctrl, copy_value(before), rebinds, owner),
		History.call("field", ctrl, copy_value(after), rebinds, owner)
	)
end

---@param ctrl table
---@param value any
HudEditor._edit_field = function(self, ctrl, value)
	local before = ctrl.get and ctrl.get()
	if before == value then
		return
	end
	self:_record_field(ctrl, before, value)
	ctrl.set(value)
	self:_commit_edit(ctrl.rebinds and true or false)
end

---@param ctrl table
---@param value any  the option being flipped
HudEditor._toggle_field = function(self, ctrl, value)
	if ctrl.no_undo then
		ctrl.toggle(value)
		self:_commit_edit(false)
		return
	end
	local owner = self._sel_block and Session.block_at(self._sel_block) or nil
	local call = History.call("checklist", ctrl, value, owner)
	History.record(call, call)
	ctrl.toggle(value)
	self:_commit_edit(false)
end

---@param mutate fun(spec: table): boolean|nil
HudEditor._cb_edit_rows = function(self, mutate)
	local _, block = self:_selected_node()
	local spec = block and self._cb and CbController.spec(block, self._cb.node, Visibility.FIELD)
	if spec and CbController.edit_rows(block, spec, mutate) then
		self:_commit_edit(true)
	end
end

HudEditor._after_history = function(self)
	self:_dismiss_popups()
	self:_end_drag()
	self._ctxmenu = nil
	self._form_node = nil
	self._node_form = nil
	self._form_sections = nil

	local count = Session.count()
	if self._sel_block and self._sel_block > count then
		self:_set_selection(count > 0 and count or nil, nil)
	end
end

---@param bi integer
---@param ni integer|nil
---@param next_on boolean
HudEditor._toggle_visibility = function(self, bi, ni, next_on)
	local block = Session.block_at(bi)
	if not block then
		return
	end
	local node = ni and block.nodes[ni]
	if ni and not node then
		return
	end
	local was
	if node then
		was = Visibility.node_shown(node)
	else
		was = Visibility.block_shown(block)
	end
	History.record(
		History.call("set_shown", block, node, was and true or false),
		History.call("set_shown", block, node, next_on and true or false)
	)
	if node then
		Visibility.set_node_shown(node, next_on and true or false)
	else
		Visibility.set_block_shown(block, next_on and true or false)
	end
	self:_save(bi)
end

---@param state "auto"|"on"|"off"
HudEditor._set_visibility_state = function(self, bi, ni, state)
	local block = Session.block_at(bi)
	if not block then
		return
	end
	local node = ni and block.nodes[ni]
	if ni and not node then
		return
	end
	local was
	if node then
		was = Visibility.node_eye_state(node)
	else
		was = Visibility.block_eye_state(block)
	end
	History.record(History.call("set_eye", block, node, was), History.call("set_eye", block, node, state))
	if node then
		Visibility.set_node_eye_state(node, state)
	else
		Visibility.set_block_eye_state(block, state)
	end
	self:_save(bi)
end

---@param bi integer
---@param ni integer|nil
HudEditor._open_visibility_code = function(self, bi, ni)
	if ni then
		self:_set_selection(bi, ni)
		self:_enter_edit_block(bi)
		self:_open_ide({ ide_field = Visibility.FIELD })
	else
		self._edit_block = nil
		self:_set_selection(bi, nil)
		self:_open_ide({ ide_block_visible = true })
	end
end

---@param bi integer
---@param ni integer|nil
HudEditor._begin_rename = function(self, bi, ni)
	self:_dismiss_popups()
	local block = Session.block_at(bi)
	if not block then
		return
	end

	if ni then
		local node = block.nodes[ni]
		if not node then
			return
		end
		self._rename = {
			bi = bi,
			ni = ni,
			ctrl = {
				token = RENAME_TOKEN,
				get = function()
					return node.label or ""
				end,
				set = function(v)
					node.label = (v ~= "" and v) or nil
				end,
			},
		}
		TextField.focus(RENAME_TOKEN, node.label or "", function(text)
			local was = node.label
			node.label = (text ~= "" and text) or nil

			History.record(
				History.call("set_key", block, node, "label", was),
				History.call("set_key", block, node, "label", node.label)
			)
			self:_save(bi)
			self._rename = nil
		end, nil)
	else
		local function label_of()
			return (block.label and block.label ~= "" and block.label) or block.name or ""
		end
		self._rename = {
			bi = bi,
			ni = nil,
			ctrl = { token = RENAME_TOKEN, get = label_of, set = function() end },
		}
		TextField.focus(RENAME_TOKEN, label_of(), function(text)
			local ok, reason = Session.set_block_label(block, text)
			if not ok then
				mod.dl.log.error("failed to rename block: %s", tostring(reason))
			end

			self._tree:store_collapsed()
			self._rename = nil
		end, nil)
	end
end

---@param name string
HudEditor._begin_folder_rename = function(self, name)
	self:_dismiss_popups()

	self._rename = {
		folder = name,
		ctrl = {
			token = RENAME_TOKEN,
			get = function()
				return name
			end,
			set = function() end,
		},
	}
	TextField.focus(RENAME_TOKEN, name, function(text)
		local trimmed = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if trimmed ~= "" and trimmed ~= name then
			local ok, reason = Session.folder_rename(name, trimmed)
			if ok then
				if self._tree.collapsed_folders[name] then
					self._tree.collapsed_folders[name] = nil
					self._tree.collapsed_folders[trimmed] = true
					self._tree:store_collapsed_folders()
				end
			else
				mod.dl.log.error("failed to rename folder: %s", tostring(reason))
			end
		end
		self._rename = nil
	end, nil)
end

---@return integer|nil
HudEditor._rename_flat_row = function(self)
	local r = self._rename
	local rows = r and self._tree.rows
	if not rows then
		return nil
	end
	for i = 1, #rows do
		local row = rows[i]
		if r.folder then
			if row.kind == "folder" and row.folder == r.folder then
				return i
			end
		elseif (row.kind == "block" or row.kind == "node") and row.bi == r.bi and row.ni == r.ni then
			return i
		end
	end
	return nil
end

---@param panel table  the Blocks panel
---@return table|nil
HudEditor._rename_box = function(self, panel)
	local flat = self:_rename_flat_row()
	if not (flat and panel) then
		return nil
	end
	local vis_idx = flat - (self._tree.scroll or 0)
	local visible = BlocksPanel.visible_rows(#self._tree.rows)
	if vis_idx < 1 or vis_idx > visible then
		return nil
	end
	local row_y = self._tree:row_y(panel, flat)
	local indent = self._tree:row_indent(flat)

	local has_chip = self._rename.folder == nil and self._rename.ni == nil and Session.hides_hidden_blocks()
	return Row.label_rect(panel.x, row_y, panel.w, indent, true, has_chip)
end

HudEditor._draw_rename_input = function(self, panel, z)
	local box = self:_rename_box(panel)
	if not box then
		return
	end
	TextInput.draw(self._d, self._rename.ctrl, box, TextField.is_focused(RENAME_TOKEN), true, z)
end

---@param cx number
---@param cy number
---@param pressed boolean
---@return boolean consumed
HudEditor._rename_press = function(self, cx, cy, pressed)
	local box = self:_rename_box(self:_blocks_panel())
	if box and in_rect(cx, cy, box) then
		if pressed then
			self:_press_textbox(self._rename.ctrl, box, cx, cy, false)
		end
		return true
	end
	if pressed then
		TextField.commit()
	end
	return false
end

---@param row integer  the flat row index
---@return boolean is_double
HudEditor._note_row_click = function(self, row)
	local now = self._t or 0
	local lc = self._last_row_click
	local is_double = lc ~= nil and lc.row == row and (now - lc.t) <= ROW_DOUBLE_CLICK_S
	self._last_row_click = { row = row, t = now }
	return is_double
end

HudEditor._rename_update = function(self)
	if self._rename and not TextField.is_focused(RENAME_TOKEN) then
		self._rename = nil
	end
end

HudEditor._reveal_selection = function(self)
	local bi = self._sel_block
	local rows = bi and self._tree.rows
	if not rows then
		return
	end

	local dirty = false
	local sel_block = Session.block_at(bi)
	local folder = Session.folder_of(sel_block)
	if folder and self._tree.collapsed_folders[folder] then
		self._tree.collapsed_folders[folder] = nil
		self._tree:store_collapsed_folders()
		dirty = true
	end

	local block = self._sel_node and sel_block or nil
	if block and self._tree.collapsed[block] then
		self._tree.collapsed[block] = nil
		self._tree:store_collapsed()
		dirty = true
	end

	if dirty then
		rows = self._tree:rebuild()
	end
	local flat
	for i = 1, #rows do
		local row = rows[i]
		if row.bi == bi and (row.kind == "block" or row.kind == "node") then
			if row.ni == self._sel_node then
				flat = i
				break
			elseif row.kind == "block" then
				flat = i
			end
		end
	end
	if not flat then
		return
	end
	local visible = BlocksPanel.visible_rows(#rows)
	local scroll = self._tree.scroll or 0
	if flat <= scroll then
		scroll = flat - 1
	elseif flat > scroll + visible then
		scroll = flat - visible
	end
	local max_scroll = BlocksPanel.max_scroll(#rows)
	if scroll < 0 then
		scroll = 0
	elseif scroll > max_scroll then
		scroll = max_scroll
	end
	self._tree.scroll = scroll
	self._tree.scroll_accum = 0
end

HudEditor._set_selection = function(self, bi, ni)
	if self._sel_block ~= bi or self._sel_node ~= ni then
		self:_dismiss_popups()

		self:_dismiss_ide()

		if self._browser then
			self:_close_browser()
		end

		if self._cb then
			self:_close_cb()
		end
	end

	self._sel_canvas = nil
	self._sel_darktide = nil
	self._sel_folder = nil
	self._sel_block = bi
	self._sel_node = ni

	self._deselect_armed = nil

	if self._td and not TdController.spec(self:_selected_node(), self._td.field) then
		self:_close_td()
	else
		self._td_lay = nil
	end

	self:_reveal_selection()
end

HudEditor._select_canvas = function(self)
	self._edit_block = nil
	self:_set_selection(nil, nil)
	self._sel_canvas = true
end

HudEditor._select_darktide = function(self)
	self._edit_block = nil
	self:_set_selection(nil, nil)
	self._sel_darktide = true
end

---@param name string
HudEditor._select_folder = function(self, name)
	self._edit_block = nil
	self:_set_selection(nil, nil)
	self._sel_folder = { name = name }
end

HudEditor._enter_edit_block = function(self, bi)
	self._edit_block = bi
end

HudEditor._exit_edit_block = function(self)
	self._edit_block = nil
	self:_set_selection(nil, nil)
end

---@param block Block?
---@return boolean
HudEditor._block_on_canvas = function(self, block)

	if Session.is_trashed(block) then
		return false
	end
	return not (Session.hides_hidden_blocks() and Session.is_hidden(block))
end

---@return integer | nil bi
HudEditor._block_under = function(self, cx, cy, dcx, dcy)
	local blocks = Session.blocks()
	for i = #blocks, 1, -1 do
		local x0, y0, x1, y1 = block_bounds(blocks[i], dcx, dcy)
		if point_in(cx, cy, x0, y0, x1, y1) and self:_block_on_canvas(blocks[i]) then
			return i
		end
	end
	return nil
end

HudEditor._delete_selected_node = function(self)
	local bi, ni = self._sel_block, self._sel_node
	if not bi or not ni then
		return
	end
	local block = Session.block_at(bi)
	if not block or not block.nodes or not block.nodes[ni] then
		return
	end

	self:_dismiss_popups()
	self:_dismiss_ide()

	local ok, reason = Session.delete_node(bi, ni)
	if not ok then
		mod.dl.log.error("failed to delete node: %s", tostring(reason))
		return
	end

	self._sel_node = nil
	self._form_node = nil
	self._node_form = nil
end

---@return table rect
HudEditor._delete_block_button_rect = function(self, panel)
	local pad = PANEL.PAD
	local lh = ROW_FONT_SIZE + 4
	return {
		x = panel.x + pad,
		y = panel.y + PANEL.TITLE_H + PANEL.PAD + lh * 2 + 8,
		w = panel.w - pad * 2,
		h = PANEL.FIELD_H,
	}
end

---@param place_x number|nil
---@param place_y number|nil
---@param folder string|nil
HudEditor._add_block = function(self, place_x, place_y, folder)
	folder = folder or (self._sel_folder and self._sel_folder.name)
	self:_dismiss_popups()
	local idx, reason = Session.add_block()
	if not idx then
		mod.dl.log.error("failed to add block: %s", tostring(reason))
		return
	end
	if folder and not Session.is_trash_folder(folder) and Session.folder_exists(folder) then

		local moved, move_reason = Session.set_block_folder(idx, folder)
		if moved then
			idx = moved
		else
			mod.dl.log.error("failed to file new block into '%s': %s", tostring(folder), tostring(move_reason))
		end
	end
	if place_x and place_y then
		local block = Session.block_at(idx)
		if block and block.offset then
			block.offset[1], block.offset[2] = place_x, place_y
			self:_save(idx)
		end
	end
	self._edit_block = nil
	self:_set_selection(idx, nil)
end

HudEditor._add_node = function(self, bi, ntype, place_x, place_y)
	local block = Session.block_at(bi)
	if not block then
		return
	end

	if Session.is_mod_block(block) then
		return
	end
	self:_dismiss_popups()

	block.nodes = block.nodes or {}

	local n = 1
	local id
	repeat
		id = ntype .. "_" .. n
		n = n + 1
		local dup = false
		for i = 1, #block.nodes do
			if block.nodes[i].id == id then
				dup = true
				break
			end
		end
	until not dup

	local target_x = place_x or 0
	local target_y = place_y or 0
	local block_scale = Session.scale_of(block)
	local x0 = (target_x - block.offset[1]) / block_scale
	local y0 = (target_y - block.offset[2]) / block_scale

	local node = {
		id = id,
		type = ntype,
		offset = { x0, y0 },
		style = {},
		values = {},
	}

	if ntype == "text" then
		node.values.text = "Text"

		node.style.shadow = true
	elseif ntype == "progress_bar" then
		node.values.current, node.values.max = 60, 100
		node.style.color = ProgressBarNode.default_color()
	elseif ntype == "rect" then
		node.style.color = RectNode.default_color()
		node.style.size = RectNode.default_size()
	end

	block.nodes[#block.nodes + 1] = node
	block:recompile()

	local ni = #block.nodes
	History.record(History.call("remove_node", block, node), History.call("insert_node", block, node, ni))
	self:_set_selection(bi, ni)
	self:_enter_edit_block(bi)

	self._form_node = nil
	self._node_form = nil

	self:_save(bi)
end

HudEditor._delete_block = function(self)
	local bi = self._sel_block
	if not bi or self._sel_node then
		return
	end

	local block = Session.block_at(bi)
	if not block then
		return
	end
	self:_dismiss_popups()
	self._edit_block = nil
	self._form_node = nil
	self._node_form = nil

	if not Session.is_trashed(block) then
		self:_set_selection(nil, nil)
		local ok, reason = Session.trash_block(bi)
		if not ok then
			mod.dl.log.error("failed to delete block: %s", tostring(reason))
		end
		return
	end

	self:_set_selection(nil, nil)
	local ok, reason = Session.remove_block(bi)
	if not ok then
		mod.dl.log.error("failed to delete block: %s", tostring(reason))
	end
end

---@param bi integer
HudEditor._restore_block = function(self, bi)
	local block = bi and Session.block_at(bi)
	if not block or not Session.is_trashed(block) then
		return
	end
	TextField.commit()
	local new_i, reason = Session.restore_block(bi)
	if not new_i then
		mod.dl.log.error("failed to restore block: %s", tostring(reason))
		return
	end
	self._edit_block = nil
	self:_set_selection(new_i, nil)
end

HudEditor._rebind_sources = function(self)
	local block, from, to, code = BlockForm.pending_rebind()
	if not (block and self._sel_block) or Session.block_at(self._sel_block) ~= block then
		return
	end

	local reversible = true
	local used = Rebind.sources_used(block)
	for i = 1, #used do
		reversible = reversible and used[i] ~= to
	end

	local changed, skipped, bodies = Rebind.run(block, from, to, code)
	if changed == 0 and bodies == 0 then
		return
	end
	if reversible then
		History.record(History.call("rebind", block, to, from, code), History.call("rebind", block, from, to, code))
	end

	self:_commit_edit(true)
	BlockForm.clear_rebind()

	self._form_node = nil

	mod.dl.log.echo(
		string.format(
			"hud_studio: %s -> %s: %d binding(s), %d code body(s) rebound, %d skipped",
			tostring(from),
			tostring(to),
			changed,
			bodies,
			skipped
		)
	)
end

HudEditor._save_to_library = function(self)
	local block, name = BlockForm.pending_library_save()
	if not (block and self._sel_block) or Session.block_at(self._sel_block) ~= block or name == "" then
		return
	end

	self:_save_block_to_library(self._sel_block, name)
end

HudEditor._export_to_mod = function(self)
	local block, mod_name, name = BlockForm.pending_export()
	if not (block and self._sel_block) or Session.block_at(self._sel_block) ~= block then
		return
	end
	if mod_name == "" or name == "" then
		return
	end

	Session.save(self._sel_block)

	local data = Session.block_data(self._sel_block)
	if not data then
		return
	end

	local ok, result = BlockLibrary.export_to_mod(data, name, mod_name)
	if not ok then
		mod.dl.log.error("hud_studio: could not export to '%s': %s", tostring(mod_name), tostring(result))
		return
	end

	local saved, why = BlockLibrary.save(data, name)
	if not saved then
		mod.dl.log.echo("hud_studio: exported, but could not save to the library: %s", tostring(why))
	end

	mod.dl.log.echo("hud_studio: exported '%s' to %s -- add \"%s\" to your register_blocks list", tostring(name), tostring(mod_name), tostring(result))
end

---@param bi integer
---@param name string?
HudEditor._save_block_to_library = function(self, bi, name)
	local data = Session.block_data(bi)
	if not data then
		return
	end

	local ok, result = BlockLibrary.save(data, name or BlockLibrary.default_save_name(data))
	if not ok then
		mod.dl.log.echo("hud_studio: could not save to the library: %s", tostring(result))
		return
	end

	self:_open_library("user:" .. result)
	mod.dl.log.echo("hud_studio: saved '%s' to the block library", tostring(result))
end

HudEditor._save_folder_to_library_form = function(self)
	local folder, name = FolderForm.pending_library_save()
	if not folder or name == "" or folder ~= (self._sel_folder and self._sel_folder.name) then
		return
	end

	self:_save_folder_to_library(folder, name)
end

---@param folder string
---@param name string?   on-disk name (default: the folder's own name)
HudEditor._save_folder_to_library = function(self, folder, name)
	local first, last = Session.folder_bounds(folder)
	if not first then
		mod.dl.log.echo("hud_studio: '%s' has no blocks to save", tostring(folder))
		return
	end

	local blocks = {}
	for i = first, last do
		local data = Session.block_data(i)

		if data and Session.folder_of(Session.block_at(i)) == folder then
			blocks[#blocks + 1] = data
		end
	end

	local ok, result = BlockLibrary.save_folder(blocks, name or folder, folder)
	if not ok then
		mod.dl.log.echo("hud_studio: could not save folder '%s': %s", tostring(folder), tostring(result))
		return
	end

	self:_open_library("user:" .. result)
	mod.dl.log.echo("hud_studio: saved folder '%s' (%d block(s)) to the library", tostring(result), #blocks)
end

HudEditor._delete_selection = function(self)
	if self._sel_node then
		self:_delete_selected_node()
		local bi = self._sel_block
		self:_set_selection(bi, nil)
		self:_enter_edit_block(bi)
	elseif self._sel_block then
		self:_delete_block()
	end
end

HudEditor._copy_selection = function(self)
	local bi, ni = self._sel_block, self._sel_node
	if not bi then
		return
	end
	self:_dismiss_popups()
	if ni then
		self:_duplicate_node(bi, ni)
	else
		self:_duplicate_block(bi)
	end
end

HudEditor._duplicate_block = function(self, bi)
	self._edit_block = nil
	local idx, reason = Session.duplicate_block(bi)
	if not idx then
		mod.dl.log.error("failed to duplicate block: %s", tostring(reason))
		return
	end
	self._form_node = nil
	self._node_form = nil
	self:_set_selection(idx, nil)
end

HudEditor._duplicate_to_edit = function(self)
	self:_duplicate_block(self._sel_block)
end

HudEditor._duplicate_node = function(self, bi, ni)
	local new_ni, reason = Session.duplicate_node(bi, ni)
	if not new_ni then
		mod.dl.log.error("failed to duplicate node: %s", tostring(reason))
		return
	end
	self:_set_selection(bi, new_ni)
	self:_enter_edit_block(bi)

	self._form_node = nil
	self._node_form = nil
end

HudEditor._move_selection = function(self, where)
	self:_dismiss_popups()

	if self._sel_node then
		local bi, ni = self._sel_block, self._sel_node
		local block = Session.block_at(bi)
		if not block or not block.nodes or not block.nodes[ni] then
			return
		end
		local nodes = block.nodes
		local count = #nodes
		local target
		if where == "front" then
			target = count
		elseif where == "back" then
			target = 1
		elseif where == "forward" then
			target = math.min(count, ni + 1)
		else
			target = math.max(1, ni - 1)
		end
		if target == ni then
			return
		end
		local node = nodes[ni]
		table.remove(nodes, ni)
		table.insert(nodes, target, node)
		block:recompile()
		self._sel_node = target
		self._form_node = nil
		self._node_form = nil
		self:_save(bi)
	elseif self._sel_block then
		local bi = self._sel_block
		local count = Session.count()
		local target
		if where == "front" then
			target = count
		elseif where == "back" then
			target = 1
		elseif where == "forward" then
			target = math.min(count, bi + 1)
		else
			target = math.max(1, bi - 1)
		end
		local new_i, reason = Session.move_block(bi, target)
		if not new_i then
			mod.dl.log.error("failed to move block: %s", tostring(reason))
			return
		end
		self._sel_block = new_i
	end
end

HudEditor._context_target = function(self, cx, cy, ccx, ccy, dcx, dcy)
	local panel, _, row = self:_panel_at(cx, cy)
	if panel then
		if panel.id == "blocks" and row then
			local r = self._tree.rows[row]

			if r and r.kind == "block" then
				return { scope = "block", bi = r.bi, in_panel = true }
			elseif r and r.kind == "node" then
				return { scope = "node", bi = r.bi, ni = r.ni, in_panel = true }
			elseif r and r.kind == "folder" then

				if Session.is_trash_folder(r.folder) then
					return { scope = "trash", folder = r.folder, in_panel = true }
				end
				return { scope = "folder", folder = r.folder, in_panel = true }
			elseif r and r.kind == "delnode" then

				return { scope = "delnode", bi = r.bi, di = r.di, in_panel = true }
			end
		end
		return nil
	end

	if self._edit_block then
		local block = Session.block_at(self._edit_block)
		local nodes = (block and self:_block_on_canvas(block)) and block.nodes or {}
		for ni = #nodes, 1, -1 do
			local x0, y0, x1, y1 = node_bounds(block, nodes[ni], dcx, dcy)
			if point_in(ccx, ccy, x0, y0, x1, y1) then
				return { scope = "node", bi = self._edit_block, ni = ni }
			end
		end
	end

	local blocks = Session.blocks()
	for i = #blocks, 1, -1 do
		local x0, y0, x1, y1 = block_bounds(blocks[i], dcx, dcy)
		if point_in(ccx, ccy, x0, y0, x1, y1) and self:_block_on_canvas(blocks[i]) then
			return { scope = "block", bi = i }
		end
	end
	return { scope = "canvas" }
end

HudEditor._open_context_menu = function(self, cx, cy)
	local inv = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale) or 1
	local sw = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width) or 1920
	local sh = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height) or 1080
	local dcx, dcy = sw * inv * 0.5, sh * inv * 0.5

	local hud_scale = HudScale.pct()
	local ccx = to_canvas(cx, dcx, hud_scale)
	local ccy = to_canvas(cy, dcy, hud_scale)

	local target = self:_context_target(cx, cy, ccx, ccy, dcx, dcy)
	if not target then
		self._ctxmenu = nil
		return
	end

	if target.scope == "canvas" then

	elseif target.scope == "trash" or target.scope == "delnode" then

	elseif target.scope == "folder" then

		self:_select_folder(target.folder)
	elseif target.scope == "node" then
		self:_set_selection(target.bi, target.ni)
		self:_enter_edit_block(target.bi)
	elseif target.in_panel then

		self._edit_block = nil
		self:_set_selection(target.bi, nil)
	else

		self:_set_selection(target.bi, nil)
		self:_enter_edit_block(target.bi)
	end

	local block = target.bi and Session.block_at(target.bi)
	local vis_mode, vis_on, vis_dynamic
	if target.scope == "canvas" or target.scope == "trash" or target.scope == "delnode" then

		vis_mode, vis_on, vis_dynamic = nil, true, false
	elseif target.scope == "folder" then

		vis_mode, vis_on, vis_dynamic = nil, Session.folder_shown(target.folder), false
	elseif target.scope == "node" then
		local node = block and block.nodes[target.ni]
		vis_mode = node and Visibility.node_mode(node) or nil
		vis_on = node ~= nil and Visibility.node_shown(node)
		vis_dynamic = node ~= nil and Visibility.node_is_dynamic(node)
	else
		vis_mode = Visibility.block_mode(block)
		vis_on = Visibility.block_shown(block)
		vis_dynamic = Visibility.block_is_dynamic(block)
	end

	local items = ContextMenu.items(
		target.scope,
		vis_mode,
		vis_on,
		vis_dynamic,

		target.scope == "block" and Session.is_mod_block(block) or false,

		target.scope == "block" and Session.is_trashed(block) or false
	)
	local rect = ContextMenu.rect(cx, cy, items)

	local menu_x = math.max(0, math.min(cx, sw * inv - rect.w))
	local menu_y = math.max(0, math.min(cy, sh * inv - rect.h))

	self._ctxmenu = {
		x = menu_x,
		y = menu_y,

		place_x = (not target.in_panel) and (ccx - dcx) or nil,
		place_y = (not target.in_panel) and (ccy - dcy) or nil,
		scope = target.scope,
		folder = target.folder,
		bi = target.bi,
		ni = target.ni,
		di = target.di,
		vis_mode = vis_mode,
		vis_on = vis_on,
		vis_dynamic = vis_dynamic,
		items = items,
	}
end

HudEditor._ctxmenu_invoke = function(self, id)
	local menu = self._ctxmenu
	if not menu then
		return
	end

	if id == "add_block" then

		self:_add_block(menu.place_x, menu.place_y, menu.folder)
	elseif id:sub(1, 9) == "add_node_" then
		self:_add_node(menu.bi, id:sub(10), menu.place_x, menu.place_y)
	elseif id == "rename_folder" then
		self:_begin_folder_rename(menu.folder)
	elseif id == "save_folder_to_library" then
		self:_save_folder_to_library(menu.folder)
	elseif id == "delete_folder" then

		local ok, reason = Session.folder_remove(menu.folder)
		if not ok then
			mod.dl.log.error("failed to delete folder: %s", tostring(reason))
		end
	elseif id == "empty_trash" then
		local removed = Session.empty_trash()
		if removed > 0 then
			mod.dl.log.echo("hud_studio: deleted %d block(s) permanently", removed)
		end
	elseif id == "restore_block" then
		self:_restore_block(menu.bi)
	elseif id == "restore_node" then
		local ni = Session.restore_node(menu.bi, menu.di)
		if ni then

			self:_set_selection(menu.bi, ni)
			self:_enter_edit_block(menu.bi)
			self._form_node = nil
			self._node_form = nil
		end
	elseif id == "purge_node" then
		local ok, reason = Session.purge_node(menu.bi, menu.di)
		if not ok then
			mod.dl.log.error("failed to delete node: %s", tostring(reason))
		end
	elseif id == "visibility" then
		if menu.scope == "folder" then
			self._tree:toggle_folder_visible(menu.folder, not menu.vis_on)
		elseif menu.vis_mode == "code" then
			self:_open_visibility_code(menu.bi, menu.scope == "node" and menu.ni or nil)
		elseif menu.vis_dynamic then

		else
			self:_toggle_visibility(menu.bi, menu.scope == "node" and menu.ni or nil, not menu.vis_on)
		end
	elseif id == "delete" then
		self:_delete_selection()
	elseif id == "duplicate" then
		self:_copy_selection()
	elseif id == "save_to_library" then

		self:_save_block_to_library(menu.bi)
	elseif id == "move_forward" then
		self:_move_selection("forward")
	elseif id == "move_backward" then
		self:_move_selection("backward")
	elseif id == "move_back" then
		self:_move_selection("back")
	elseif id == "move_front" then
		self:_move_selection("front")
	end

	self._ctxmenu = nil
end

HudEditor._ctxmenu_ctx = function(self)
	self._ctxmenu_close = self._ctxmenu_close or function()
		self._ctxmenu = nil
	end
	self._ctxmenu_invoke_cb = self._ctxmenu_invoke_cb or function(id)
		self:_ctxmenu_invoke(id)
	end
	return { state = self._ctxmenu, close = self._ctxmenu_close, invoke = self._ctxmenu_invoke_cb }
end

HudEditor._ctxmenu_interact = function(self, cx, cy, pressed)
	return ContextMenuController.interact(self:_ctxmenu_ctx(), cx, cy, pressed)
end

HudEditor._focus_text = function(self, ctrl)
	if TextField.is_focused(ctrl.token) then
		return
	end
	TextField.commit()

	local opts = ctrl.multiline and { multiline = true } or nil
	TextField.focus(ctrl.token, tostring(ctrl.get() or ""), function(text)
		self:_edit_field(ctrl, text)
	end, opts)
end

HudEditor._focus_numeric = function(self, ctrl)
	if TextField.is_focused(ctrl.token) then
		return
	end
	TextField.commit()
	local current = tonumber(ctrl.get()) or 0

	TextField.focus(ctrl.token, Format.number(current), function(text)
		local n = tonumber(text)
		if n then
			self:_edit_field(ctrl, round_dec(clamp(n, ctrl.min, ctrl.max), ctrl.decimals))
		end
	end)
end

HudEditor._sync_multiline_wrap = function(self)
	if not (self._ui_renderer and TextField.any_focused() and TextField.is_multiline()) then
		return
	end
	local tok = TextField.token()

	if self._ide_lay and self._ide_lay.body_token == tok and self._ide_lay.body then
		TextField.set_wrap(TextMetrics.wrap_width(self._ui_renderer, self._ide_lay.body.w - 8))
		return
	end
	local form = self._node_form
	if not form then
		return
	end
	for i = 1, #form.items do
		local it = form.items[i]
		if it.t == "field" and it.ctrl and it.ctrl.token == tok and it.parts and it.parts.box then
			TextField.set_wrap(TextMetrics.wrap_width(self._ui_renderer, it.parts.box.w - 8))
			return
		end
	end
end

---@return table|nil node, table|nil block
HudEditor._selected_node = function(self)
	local block = self._sel_block and Session.block_at(self._sel_block)
	local node = block and self._sel_node and block.nodes[self._sel_node]
	return node, block
end

---@return table
HudEditor._ide_ctx = function(self)
	return {
		ide = self._ide,
		panel = self._ide_panel,
		docs_path = self._ide_docs_path,
		sel_block = self._sel_block,
		sel_node = self._sel_node,
		ui_renderer = self._ui_renderer,
		commit = self._ide_commit,
		lay = self._ide_lay,
		hover = self._ide_hover,
		begin_drag = self._ide_begin_drag,
		press_textbox = self._ide_press_textbox,
		baseline = self._ide_baseline,
		set_baseline = self._ide_set_baseline,
		on_reset = self._ide_reset,
	}
end

HudEditor._reset_ide_changes = function(self)
	if IdeController.reset(self:_ide_ctx()) then
		self._ide_lay = nil
	end
end

HudEditor._open_ide = function(self, ctrl)
	self:_dismiss_popups()
	self._ide = IdeController.open(self:_ide_ctx(), ctrl)
	self._ide_lay = nil
end

HudEditor._dismiss_ide = function(self)
	self._ide = nil
	self._ide_lay = nil
	self._ide_hover.close = nil
	self._ide_baseline = nil
end

HudEditor._close_ide = function(self)
	TextField.commit()
	self:_dismiss_ide()
end

---@return boolean consumed
HudEditor._ide_interact = function(self, cx, cy, pressed)
	local consumed, close_pressed = IdeController.interact(self:_ide_ctx(), cx, cy, pressed)
	if close_pressed then
		self:_close_ide()
	end
	return consumed
end

---@return MaterialBrowserCtx
HudEditor._browser_ctx = function(self)
	return {
		state = self._browser,
		cats = self._browser_cats,
		panel = self._browser_panel,
		lay = self._browser_lay,
		hover = self._browser_hover,
		node = self:_selected_node(),
		drag = self._drag,
		close = self._browser_close,
		assign = self._browser_do_assign,
		begin_drag = self._browser_begin_drag,
	}
end

---@param ctrl table  the material field's control item that requested the browser
HudEditor._open_browser = function(self, ctrl)
	local node = self:_selected_node()
	if not node then
		return
	end
	self:_dismiss_popups()

	self._browser_field = (ctrl and ctrl.field) or "material"
	self._browser = BrowserController.open(self:_browser_ctx(), node.values and node.values[self._browser_field])
	self._browser_lay = nil
end

HudEditor._close_browser = function(self)
	BrowserController.close(self:_browser_ctx())
	self._browser = nil
	self._browser_lay = nil
end

---@param material string
HudEditor._browser_assign = function(self, material)
	local node = self:_selected_node()
	if not node then
		return
	end
	BrowserController.assign(node, material, self._browser_field)
	self:_commit_edit(false)
end

---@return BlockLibraryCtx
HudEditor._library_ctx = function(self)
	return {
		state = self._library,
		panel = self._library_panel,
		lay = self._library_lay,
		hover = self._library_hover,
		drag = self._drag,
		close = self._library_close,
		reveal = self._library_reveal,
		begin_drag = self._library_begin_drag,
	}
end

---@param focus string?
HudEditor._open_library = function(self, focus)
	self:_dismiss_popups()
	self._library = LibraryController.open(type(focus) == "string" and focus or nil)
	self._library_lay = nil
end

HudEditor._close_library = function(self)
	LibraryController.close(self:_library_ctx())
	self._library = nil
	self._library_lay = nil
end

---@param index integer
HudEditor._library_added = function(self, index)
	self._sel_block = index
	self._sel_node = nil
	self._tree:rebuild()
	self:_reveal_selection()
end

HudEditor._dropdown_handle_scroll = function(self, view_input)
	DropdownController.handle_scroll(self:_dropdown_ctx(), view_input)
end

HudEditor._blocks_handle_scroll = function(self, view_input, over_body)
	local rows = self._tree:current_rows()
	local max_scroll = BlocksPanel.max_scroll(#rows)
	if max_scroll <= 0 then
		self._tree.scroll = 0
		self._tree.scroll_accum = 0
		return
	end
	if over_body then
		local axis = view_input and view_input:get("scroll_axis")
		local delta = axis and axis[2] or 0
		if delta ~= 0 then
			self._tree.scroll_accum = (self._tree.scroll_accum or 0) + delta
		end
		while self._tree.scroll_accum >= 1 do
			self._tree.scroll = self._tree.scroll - 1
			self._tree.scroll_accum = self._tree.scroll_accum - 1
		end
		while self._tree.scroll_accum <= -1 do
			self._tree.scroll = self._tree.scroll + 1
			self._tree.scroll_accum = self._tree.scroll_accum + 1
		end
	end
	if self._tree.scroll < 0 then
		self._tree.scroll = 0
	elseif self._tree.scroll > max_scroll then
		self._tree.scroll = max_scroll
	end
end

HudEditor._open_cb = function(self, node)
	TextField.commit()

	local _, cb_block = self:_selected_node()
	if node then
		Visibility.ensure_node_conditions(node)
	elseif cb_block then
		Visibility.ensure_block_conditions(cb_block)
	end
	self._dropdown = nil
	self._colorpicker = nil
	self._cb = { node = node }
	self._cb_lay = nil
end

HudEditor._close_cb = function(self)
	TextField.commit()
	if self._cb then
		local _, block = self:_selected_node()
		Conditions.unwatch(block and CbController.spec(block, self._cb.node, Visibility.FIELD))
	end
	self._cb = nil
	self._cb_lay = nil
	self._cb_close_hover = nil
end

---@return table|nil
HudEditor._cb_layout = function(self)
	if not self._cb then
		return nil
	end
	local _, block = self:_selected_node()
	if not block then
		return nil
	end

	local spec = CbController.spec(block, self._cb.node, Visibility.FIELD)
	Conditions.watch(spec)
	return CbController.layout(self._cb_panel, block, self._cb.node, Visibility.FIELD, self._cb_ctrls, function(i)
		return Conditions.row_truth(spec, i, self._t)
	end)
end

HudEditor._cb_interact = function(self, cx, cy, pressed)
	local lay = self._cb_lay
	if not lay then
		return false
	end
	self._cb_close_hover = nil

	if in_rect(cx, cy, PanelHeader.close_rect(self._cb_panel)) then
		self._cb_close_hover = true
		if pressed then
			self:_close_cb()
		end
		return true
	end
	if in_rect(cx, cy, lay.title) then
		if pressed then
			self._drag = DragController.panel(self._cb_panel, cx, cy)
		end
		return true
	end

	local items = lay.items
	for i = 1, #items do
		local it = items[i]
		local ctrl = it.ctrl

		if
			(ctrl.cb_expand or ctrl.cb_remove or ctrl.cb_negate or ctrl.cb_add)
			and it.parts
			and in_rect(cx, cy, it.parts.box)
		then
			self._acc_hover = it
			if pressed then
				TextField.commit()
				if ctrl.cb_expand then
					CbController.toggle(self._cb_ctrls, ctrl.cb_expand.row)
				elseif ctrl.cb_add then
					self:_cb_edit_rows(function(spec)
						if not CbController.can_add(spec) then
							return false
						end
						CbController.ensure_row(spec, #spec.rows + 1)
					end)
				elseif ctrl.cb_negate then
					self:_cb_edit_rows(function(spec)
						CbController.toggle_negate(spec, ctrl.cb_negate)
					end)
				else
					self:_cb_edit_rows(function(spec)
						CbController.remove_row(spec, ctrl.cb_remove)
					end)
				end
			end
			return true
		end
		if self:_field_interact(it, cx, cy, pressed) then
			return true
		end
	end

	if in_rect(cx, cy, lay.frame) then
		if pressed then
			TextField.commit()
		end
		return true
	end
	return false
end

HudEditor._open_td = function(self, ctrl)
	local node = self:_selected_node()
	if not node or not ctrl.field then
		return
	end
	self:_dismiss_popups()
	self._td = { field = ctrl.field }
	self._td_lay = nil
end

HudEditor._close_td = function(self)
	TextField.commit()
	self._td = nil
	self._td_lay = nil
	self._td_close_hover = nil
end

---@return table|nil
HudEditor._td_layout = function(self)
	if not self._td then
		return nil
	end
	return TdController.layout(self._td_panel, self:_selected_node(), self._td.field, self._td_ctrls)
end

HudEditor._td_interact = function(self, cx, cy, pressed)
	local lay = self._td_lay
	if not lay then
		return false
	end
	self._td_close_hover = nil

	if in_rect(cx, cy, PanelHeader.close_rect(self._td_panel)) then
		self._td_close_hover = true
		if pressed then
			self:_close_td()
		end
		return true
	end
	if in_rect(cx, cy, lay.title) then
		if pressed then
			self._drag = DragController.panel(self._td_panel, cx, cy)
		end
		return true
	end

	local items = lay.items
	for i = 1, #items do
		if self:_field_interact(items[i], cx, cy, pressed) then
			return true
		end
	end

	if in_rect(cx, cy, lay.frame) then
		if pressed then
			TextField.commit()
		end
		return true
	end
	return false
end

HudEditor._press_multiline = function(self, box, cx, cy)
	local row, col = self:_multiline_rc_at(box, cx, cy)
	TextField.set_caret_rc(row, col, TextField.shift_down())

	self._drag = DragController.textsel(box, true)
end

local DOUBLE_CLICK_TIME = 0.35
local DOUBLE_CLICK_DIST = 6

HudEditor._press_textbox = function(self, ctrl, box, cx, cy, is_numeric)
	local was_focused = TextField.is_focused(ctrl.token)
	if is_numeric then
		self:_focus_numeric(ctrl)
	else
		self:_focus_text(ctrl)
	end

	if is_numeric and not was_focused then
		TextField.select_all()
		self._last_click_token = ctrl.token
		self._last_click_t = self._t or 0
		self._last_click_x = cx
		self._last_click_y = cy
		self._drag = nil
		return
	end

	local now = self._t or 0
	local is_double = self._last_click_token == ctrl.token
		and (now - (self._last_click_t or -math.huge)) <= DOUBLE_CLICK_TIME
		and math.abs(cx - (self._last_click_x or 0)) <= DOUBLE_CLICK_DIST
		and math.abs(cy - (self._last_click_y or 0)) <= DOUBLE_CLICK_DIST
	self._last_click_token = ctrl.token
	self._last_click_t = now
	self._last_click_x = cx
	self._last_click_y = cy

	if ctrl.multiline then

		if self._ui_renderer then
			TextField.set_wrap(TextMetrics.wrap_width(self._ui_renderer, box.w - 8))
		end
		self:_press_multiline(box, cx, cy)
	else

		local left_x = box.x + 4 - TextField.scroll_x()
		if self._ui_renderer then
			local idx = TextMetrics.caret_index_at_x(self._ui_renderer, left_x, cx)
			TextField.set_caret(idx, TextField.shift_down())
		end
		self._drag = DragController.textsel(box)
	end

	if is_double then

		local lo, hi = TextField.word_range_at()
		if lo then
			TextField.select_word_at()

			self._drag.word = { lo = lo, hi = hi }
		else
			self._drag = nil 
		end
	end
end

HudEditor._extend_textsel = function(self, drag, index)
	local word = drag.word
	if not word then
		TextField.set_caret(index, true)
		return
	end
	local lo, hi = TextField.word_range_at(index)
	if not lo then
		return
	end
	if lo >= word.hi then

		TextField.set_selection(word.lo, hi)
	elseif hi <= word.lo then

		TextField.set_selection(word.hi, lo)
	else
		TextField.set_selection(word.lo, word.hi) 
	end
end

HudEditor._numeric_apply = function(self, ctrl, dir)
	local v = tonumber(ctrl.get()) or 0
	local stepped = round_dec(clamp(v + dir * (ctrl.step or 1), ctrl.min, ctrl.max), ctrl.decimals)

	self:_record_field(ctrl, v, stepped)
	ctrl.set(stepped)
end

HudEditor._numeric_step = function(self, ctrl, dir)
	TextField.commit()
	self:_numeric_apply(ctrl, dir)
	self:_commit_edit()
end

HudEditor._arm_numstep = function(self, ctrl, dir)
	self:_numeric_step(ctrl, dir)
	self._drag = DragController.numstep(ctrl, dir, self._t or 0)
end

---@return table form { items }
HudEditor._popup_form = function(self)
	local form = self._node_form
	if not self._td_lay and not self._cb_lay then
		return form or { items = {} }
	end
	local items = {}
	local base = form and form.items or {}
	for i = 1, #base do
		items[#items + 1] = base[i]
	end
	if self._td_lay then
		local td_items = self._td_lay.items
		for i = 1, #td_items do
			items[#items + 1] = td_items[i]
		end
	end
	if self._cb_lay then
		local cb_items = self._cb_lay.items
		for i = 1, #cb_items do
			items[#items + 1] = cb_items[i]
		end
	end
	return { items = items }
end

---@return table
HudEditor._dropdown_ctx = function(self)
	return {
		state = self._dropdown,
		hover = self._dropdown_hover,
		form = self:_popup_form(),
		close = self._dropdown_close,
		set_hover = self._dropdown_set_hover,
		commit = self._field_commit,
		edit = self._field_edit,
	}
end

---@return table|nil
HudEditor._dropdown_item = function(self)
	return DropdownController.item(self:_dropdown_ctx())
end

HudEditor._toggle_dropdown = function(self, item)
	if self._dropdown and self._dropdown.ctrl == item.ctrl then
		self._dropdown = nil
		return
	end
	TextField.commit()
	self._colorpicker = nil
	self._dropdown = DropdownController.open_state(item.ctrl)
end

---@return table
HudEditor._colorpicker_ctx = function(self)
	return {
		state = self._colorpicker,
		form = self:_popup_form(),
		commit = self._field_commit,
		edit = self._field_edit,
	}
end

HudEditor._toggle_colorpicker = function(self, ctrl)
	if self._colorpicker and self._colorpicker.ctrl == ctrl then
		self._colorpicker = nil
		return
	end
	TextField.commit()
	self._dropdown = nil
	self._colorpicker = ColorPickerController.seed(ctrl)
end

HudEditor._copy_color = function(self, ctrl)
	ColorPickerController.copy(ctrl)
end

HudEditor._paste_color = function(self, ctrl)
	ColorPickerController.paste(self:_colorpicker_ctx(), ctrl)
end

---@return table|nil
HudEditor._colorpicker_item = function(self)
	return ColorPickerController.item(self:_colorpicker_ctx())
end

HudEditor._apply_colorpick = function(self, drag, cx, cy)
	ColorPickerController.apply(self._colorpicker, drag, cx, cy)
end

HudEditor._colorpick_press = function(self, ctrl, box, cx, cy)
	local state = self._colorpicker
	local region, index = ColorPickerController.press_region(box, cx, cy)
	if not region then
		return
	end
	if region == "saved" then
		local color = ColorPickerController.pick_saved(state, index)
		if color then
			self:_edit_field(ctrl, color)
		end
		return
	end
	if region == "button" then
		if state.saved_index then
			ColorPickerController.delete_color(state)
		else
			ColorPickerController.save_color(state, box)
		end
		return
	end
	self._drag = DragController.colorpick(ctrl, region, box)
	self:_apply_colorpick(self._drag, cx, cy)
end

---@return boolean consumed
HudEditor._colorpicker_interact = function(self, cx, cy, pressed)
	local item = self:_colorpicker_item()
	if not item then
		self._colorpicker = nil
		return false
	end
	local box = ColorPickerController.box(item)
	if in_rect(cx, cy, box) then
		if pressed then
			self:_colorpick_press(self._colorpicker.ctrl, box, cx, cy)
		end
		return true
	end
	if pressed and not in_rect(cx, cy, item.parts.swatch) then
		self._colorpicker = nil
		return true
	end
	return false
end

local BUTTON_ACTIONS = {
	delete_node = "_delete_selected_node",
	open_ide = "_open_ide",
	delete_block = "_delete_block",
	open_texture_browser = "_open_browser",
	open_block_library = "_open_library",
	new_folder = "_new_folder",
	rebind_sources = "_rebind_sources",
	save_to_library = "_save_to_library",
	export_to_mod = "_export_to_mod",
	save_folder_to_library_form = "_save_folder_to_library_form",
	duplicate_to_edit = "_duplicate_to_edit",
}

HudEditor._field_interact = function(self, it, cx, cy, pressed)
	local ctrl = it.ctrl
	local kind = ctrl.kind
	local parts = it.parts

	if ctrl.disabled and type(ctrl.disabled) ~= "function" then
		return false
	end

	if pressed and type(ctrl.disabled) == "function" and ctrl.disabled() then
		pressed = false
	end

	if kind == "numeric" then
		if in_rect(cx, cy, parts.minus) then
			self._acc_hover = it
			if pressed then
				self:_arm_numstep(ctrl, -1)
			end
			return true
		elseif in_rect(cx, cy, parts.plus) then
			self._acc_hover = it
			if pressed then
				self:_arm_numstep(ctrl, 1)
			end
			return true
		elseif in_rect(cx, cy, parts.value) then
			self._acc_hover = it
			if pressed then
				self:_press_textbox(ctrl, parts.value, cx, cy, true)
			end
			return true
		end
	elseif kind == "dropdown" then
		if in_rect(cx, cy, parts.box) then
			self._acc_hover = it
			if pressed then
				self:_toggle_dropdown(it)
			end
			return true
		end
	elseif kind == "text" then
		if in_rect(cx, cy, parts.box) then
			self._acc_hover = it
			if pressed then
				self:_press_textbox(ctrl, parts.box, cx, cy, false)
			end
			return true
		end
	elseif kind == "checkbox" then
		if in_rect(cx, cy, parts.box) then
			self._acc_hover = it
			if pressed then

				self:_edit_field(ctrl, not (ctrl.get() and true or false))
			end
			return true
		end
	elseif kind == "checklist" then

		local items = parts.items
		for i = 1, #items do
			if in_rect(cx, cy, items[i].box) then
				self._acc_hover = it
				if pressed then
					self:_toggle_field(ctrl, items[i].value)
				end
				return true
			end
		end
	elseif kind == "rgba" then
		if in_rect(cx, cy, parts.swatch) then
			self._acc_hover = it
			if pressed then
				self:_toggle_colorpicker(ctrl)
			end
			return true
		elseif parts.text and in_rect(cx, cy, parts.text) then

			self._acc_hover = it
			self._rgba_copy_hover = ctrl
			if pressed then
				self:_copy_color(ctrl)
			end
			return true
		elseif parts.paste and in_rect(cx, cy, parts.paste) then

			self._acc_hover = it
			self._rgba_paste_hover = ctrl
			if pressed then
				self:_paste_color(ctrl)
			end
			return true
		end
	elseif kind == "button" then
		if in_rect(cx, cy, parts.box) then
			self._acc_hover = it

			if pressed and not (type(ctrl.disabled) == "function" and ctrl.disabled()) then
				local handler = BUTTON_ACTIONS[ctrl.action]
				if handler then
					self[handler](self, ctrl)
				end
			end

			return true
		end
	elseif kind == "thresholds" then
		if in_rect(cx, cy, parts.box) then
			self._acc_hover = it
			if pressed then
				self:_open_td(ctrl)
			end
			return true
		end
	elseif kind == "conditions" then
		if in_rect(cx, cy, parts.box) then
			self._acc_hover = it
			if pressed then
				self:_open_cb(ctrl.cb_node)
			end
			return true
		end
	end

	return false
end

---@return boolean consumed
HudEditor._dropdown_interact = function(self, cx, cy, pressed)
	return DropdownController.interact(self:_dropdown_ctx(), cx, cy, pressed)
end

HudEditor._property_panel_interact = function(self, cx, cy, pressed)
	self._acc_hover = nil
	self._rgba_copy_hover = nil
	self._rgba_paste_hover = nil
	local form = self._node_form
	if not form then

		if self._sel_block and not self._sel_node then
			local panel = self:_property_panel()
			if in_rect(cx, cy, self:_delete_block_button_rect(panel)) then
				self._delblock_hover = true
				if pressed then
					self:_delete_block()
				end
				return
			end
		end
		if pressed then
			TextField.commit()
		end
		return
	end

	for i = 1, #form.items do
		local it = form.items[i]
		if it.t == "header" then
			if in_rect(cx, cy, it) then
				self._acc_hover = it
				if pressed then
					self:_dismiss_popups()
					local open = self._acc_open[it.key]
					if open == nil then
						open = true
					end
					self._acc_open[it.key] = not open
					store_acc_open(self._acc_open)
				end
				return
			end
		elseif it.t == "field" then
			if self:_field_interact(it, cx, cy, pressed) then
				return
			end
		end
	end

	if pressed then
		self:_dismiss_popups()
	end
end

HudEditor._end_drag = function(self)
	local drag = self._drag
	if not drag then
		return
	end
	DragController.release(self:_drag_ctx(), drag)
	self._drag = nil
	self._tree.autoscroll_at = nil 
end

---@return boolean cancelled  true when a move was cancelled (so Escape is consumed here)
HudEditor._cancel_drag = function(self)
	local drag = self._drag
	if not drag or not DragController.cancel(self:_drag_ctx(), drag) then
		return false
	end
	self._drag = nil
	self._tree.autoscroll_at = nil
	return true
end

---@param pass fun(tree: BlocksTree, ctx: ReorderCtx, drag: ReorderDrag, cy: number)
---@param drag ReorderDrag
---@param cy number
HudEditor._run_reorder = function(self, pass, drag, cy)
	local ctx = { sel_block = self._sel_block, sel_node = self._sel_node, edit_block = self._edit_block }
	pass(self._tree, ctx, drag, cy)
	self._sel_block = ctx.sel_block
	self._sel_node = ctx.sel_node
	self._edit_block = ctx.edit_block
end

---@return KeyNavCtx
HudEditor._keynav_ctx = function(self)
	return {
		now = self._t or 0,
		sel = {
			canvas = self._sel_canvas,
			darktide = self._sel_darktide,
			block = self._sel_block,
			node = self._sel_node,
		},
		commit_edit = function()
			self:_commit_edit()
		end,
	}
end

---@return DragCtx
HudEditor._drag_ctx = function(self)
	local ctx = self._drag_ctx_cache
	if not ctx then
		ctx = {
			tree = self._tree,
			ctrl_held = KeyboardNav.ctrl_held,

			save = function(bi, what)
				self:_save(bi, what)
			end,
			save_canvas = function()
				self:_save_canvas("folder position")
			end,
			commit_edit = function()
				self:_commit_edit()
			end,
			record_field = function(ctrl, before, after)
				self:_record_field(ctrl, before, after)
			end,
			store_panel_pos = function(panel)
				self:_store_panel_pos(panel)
			end,
			enter_edit_block = function(bi)
				self:_enter_edit_block(bi)
			end,
			save_panel_pos = function(panel)
				self:_save_panel_pos(panel)
			end,
			run_reorder = function(pass, drag, cy)
				self:_run_reorder(pass, drag, cy)
			end,
			extend_textsel = function(drag, index)
				self:_extend_textsel(drag, index)
			end,
			apply_colorpick = function(drag, cx, cy)
				self:_apply_colorpick(drag, cx, cy)
			end,
			numeric_apply = function(ctrl, dir)
				self:_numeric_apply(ctrl, dir)
			end,
			multiline_rc_at = function(box, cx, cy)
				return self:_multiline_rc_at(box, cx, cy)
			end,
		}
		self._drag_ctx_cache = ctx
	end
	ctx.now = self._t or 0
	ctx.ui_renderer = self._ui_renderer
	return ctx
end

HudEditor._update_interaction = function(self, input_service)
	self._tree:rebuild()
	self:_rebuild_node_form()

	local cursor = input_service and input_service:get("cursor")
	if not cursor then
		self:_end_drag()
		self:_clear_hover()
		return
	end

	local inv = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale) or 1
	local sw = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width) or 1920
	local sh = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height) or 1080

	local dcx = sw * inv * 0.5
	local dcy = sh * inv * 0.5
	local cx = cursor[1] * inv
	local cy = cursor[2] * inv

	local hud_scale = HudScale.pct()
	local ccx = to_canvas(cx, dcx, hud_scale)
	local ccy = to_canvas(cy, dcy, hud_scale)

	if self._drag then
		self:_clear_hover()
		if input_service:get("left_hold") then
			DragController.update(self:_drag_ctx(), self._drag, cx, cy, ccx, ccy, dcx, dcy)
		else
			self:_end_drag()
		end
		return
	end

	self:_clear_frame_hover()
	local pressed = input_service:get("left_pressed")
	local right_pressed = input_service:get("right_pressed")

	if self._ide and self:_ide_interact(cx, cy, pressed) then
		return
	end

	if self._browser and BrowserController.interact(self:_browser_ctx(), cx, cy, pressed) then
		return
	end

	if self._library and LibraryController.interact(self:_library_ctx(), cx, cy, pressed) then
		return
	end

	if self._dropdown and self:_dropdown_interact(cx, cy, pressed) then
		return
	end

	if self._colorpicker and self:_colorpicker_interact(cx, cy, pressed) then
		return
	end

	if self._td and self:_td_interact(cx, cy, pressed) then
		return
	end

	if self._cb and self:_cb_interact(cx, cy, pressed) then
		return
	end

	if self._rename and self:_rename_press(cx, cy, pressed) then
		return
	end

	if right_pressed then
		self:_open_context_menu(cx, cy)
		return
	end

	if self._ctxmenu then
		self:_ctxmenu_interact(cx, cy, pressed)
		return
	end

	local panel, region, row = self:_panel_at(cx, cy)
	if panel then
		if region == "title" then
			if pressed then
				self._drag = DragController.panel(panel, cx, cy)
			end
			return
		end

		if region == "toolbar" then
			return
		end

		if panel.id == "property" then
			self:_property_panel_interact(cx, cy, pressed)
			return
		end

		if row then
			local r = self._tree.rows[row]
			self._tree.hover_row = row

			if r.kind == "slot" then
				return
			end

			if r.kind == "bin" then
				if pressed then
					self._tree:toggle_bin_open(Session.block_at(r.bi))
				end
				return
			end
			if r.kind == "delnode" then
				return
			end

			local has_eye = r.kind ~= "canvas"
				and r.kind ~= "darktide"
				and not (r.kind == "folder" and Session.is_trash_folder(r.folder))
			local over_eye = has_eye and in_rect(cx, cy, self._tree:row_eye_rect(panel, row))

			self._hover_row_eye = over_eye or nil
			if over_eye then

				if BlocksTree.DEBUG_FOLDER_EYE and pressed and r.kind == "folder" then
					mod.dl.log.echo("[folder eye] press swallowed on folder row '" .. tostring(r.folder) .. "'")
				end
				return
			end
			if pressed then

				local is_double = self:_note_row_click(row)

				if r.kind == "darktide" then
					self:_select_darktide()
				elseif r.kind == "canvas" then
					self:_select_canvas()
				elseif r.kind == "folder" then

					if in_rect(cx, cy, self._tree:row_caret_rect(panel, row)) then
						self._tree:toggle_folder_collapsed(r.folder)
					elseif is_double and not Session.is_trash_folder(r.folder) then
						self:_begin_folder_rename(r.folder)
					else
						self:_select_folder(r.folder)

						self._drag = DragController.reorder_folder(r.folder, Session.is_trash_folder(r.folder))
					end
				elseif r.kind == "block" then
					local block = Session.block_at(r.bi)

					if block and in_rect(cx, cy, self._tree:row_caret_rect(panel, row)) then
						self._tree.collapsed[block] = (not self._tree.collapsed[block]) or nil
						self._tree:store_collapsed()
					elseif is_double and not Session.is_mod_block(block) then
						self:_begin_rename(r.bi, nil)
					else

						self._edit_block = nil
						self:_set_selection(r.bi, nil)

						if block then
							self._drag = DragController.reorder_block(block)
						end
					end
				elseif is_double then
					self:_begin_rename(r.bi, r.ni)
				else

					self:_set_selection(r.bi, r.ni)
					self:_enter_edit_block(r.bi)
					local block = Session.block_at(r.bi)
					local node = block and block.nodes[r.ni]

					if node and not Session.is_mod_block(block) then
						self._drag = DragController.reorder_node(r.bi, node)
					end
				end
			end
		end
		return
	end

	if self._edit_block then
		local block = Session.block_at(self._edit_block)
		if block then

			local nodes = self:_block_on_canvas(block) and block.nodes or {}
			for ni = #nodes, 1, -1 do
				local node = nodes[ni]
				local x0, y0, x1, y1 = node_bounds(block, node, dcx, dcy)
				if point_in(ccx, ccy, x0, y0, x1, y1) then
					self._hover_node = ni
					if pressed then
						self:_set_selection(self._edit_block, ni)

						if Session.is_mod_block(block) then
							return
						end

						local tx0, ty0, tx1, ty1 = rotate_handle_bounds(block, node, dcx, dcy)
						local rx0, ry0, rx1, ry1 = resize_handle_bounds(block, node, dcx, dcy)
						if node_rotatable(node) and point_in(ccx, ccy, tx0, ty0, tx1, ty1) then
							self._drag = DragController.rotate(block, node, self._edit_block, cy)
						elseif node_resizable(node) and point_in(ccx, ccy, rx0, ry0, rx1, ry1) then
							self._drag = DragController.resize(block, node, self._edit_block, ccx, ccy, dcx, dcy)
						else
							self._drag = DragController.node(block, node, self._edit_block, ccx, ccy, dcx, dcy)
						end
					end
					return
				end
			end

			if pressed then
				self:_dismiss_popups()
				local hit_bi = self:_block_under(ccx, ccy, dcx, dcy)
				local confirmed = not self._sel_node or self._deselect_armed
				if not confirmed then
					self._deselect_armed = true
				elseif hit_bi == self._edit_block then
					self:_set_selection(self._edit_block, nil)
				elseif not hit_bi then
					self:_select_canvas()
				else
					self:_set_selection(hit_bi, nil)
					self:_enter_edit_block(hit_bi)
				end
			end
			return
		end

		self._edit_block = nil
	end

	local blocks = Session.blocks()

	for i = #blocks, 1, -1 do
		local block = blocks[i]
		if block_scalable(block) and self:_block_on_canvas(block) then
			local hx0, hy0, hx1, hy1 = block_scale_handle_bounds(block, dcx, dcy)
			if point_in(ccx, ccy, hx0, hy0, hx1, hy1) then
				self._hover_block = i
				if pressed then
					self:_set_selection(i, nil)
					self._drag = DragController.block_scale(block, i, cx)
				end
				return
			end
		end
	end

	for i = #blocks, 1, -1 do
		local x0, y0, x1, y1 = block_bounds(blocks[i], dcx, dcy)
		if point_in(ccx, ccy, x0, y0, x1, y1) and self:_block_on_canvas(blocks[i]) then
			self._hover_block = i
			if pressed then
				self:_set_selection(i, nil)
				self._drag = DragController.block(i, blocks[i].offset, ccx, ccy, dcx, dcy)
			end
			return
		end
	end

	if pressed then
		self:_select_canvas()
	end
end

HudEditor._publish_force_visible = function(self)
	if not self.edit_mode() then
		Session.set_force_visible(nil, nil, nil)
		return
	end

	local tree = self._tree
	local hover_row = not self._hover_row_eye and tree.hover_row and tree.rows and tree.rows[tree.hover_row] or nil
	local hover_bi = self._hover_block or (hover_row and hover_row.bi)
	local hover_block = hover_bi and Session.block_at(hover_bi) or nil

	if Session.is_trashed(hover_block) then
		hover_block = nil
	end

	local block = self._sel_block and Session.block_at(self._sel_block)
	if block and Session.is_trashed(block) then
		block = nil
	end
	if not block then
		Session.set_force_visible(nil, nil, hover_block)
		return
	end

	local nodes = nil
	local function force_node(ni)
		local node = ni and block.nodes[ni]
		if node then
			nodes = nodes or {}
			nodes[node] = true
		end
	end

	force_node(self._sel_node)

	if self._edit_block == self._sel_block then
		force_node(self._hover_node)
	end
	if hover_row and hover_row.kind == "node" and hover_row.bi == self._sel_block then
		force_node(hover_row.ni)
	end

	Session.set_force_visible(block, nodes, hover_block)
end

HudEditor.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	self._frame = (self._frame or 0) + 1
	self:_publish_force_visible()

	if self._browser then
		BrowserLoader.pump()
	end

	HudEditor.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	self._ui_renderer = ui_renderer
	self._d = DrawCalls.setup(ui_renderer)
	self._t = t

	History.set_time(t)

	if not self.edit_mode() then
		self:_end_drag()
		self:_clear_edit_state()
		self:_clear_hover()
		self:_pop_cursor()
		return
	end

	self:_push_cursor()

	mod.hud_studio_editor_self_query = true
	local real_view_up = Managers.ui:using_input(true)
	mod.hud_studio_editor_self_query = false
	if real_view_up then
		self:_end_drag()
		self:_clear_edit_state()
		self:_clear_hover()
		return
	end

	local view_input = Managers.input:get_input_service("View")

	self._d:set_pointer(view_input)

	self._ide_lay = (self._ide and IdeController.layout(self:_ide_ctx())) or nil

	self._browser_lay = (self._browser and BrowserController.layout(self:_browser_ctx())) or nil
	if self._browser then
		BrowserController.handle_scroll(self:_browser_ctx(), view_input)
		self._browser_lay = BrowserController.layout(self:_browser_ctx())
	end

	self._library_lay = (self._library and LibraryController.layout(self:_library_ctx())) or nil
	if self._library then
		LibraryController.handle_scroll(self:_library_ctx(), view_input)
		self._library_lay = LibraryController.layout(self:_library_ctx())
	end

	self._td_lay = self:_td_layout()
	self._cb_lay = self:_cb_layout()

	if self._dropdown then
		self:_dropdown_handle_scroll(view_input)
	end

	DropdownController.update(self:_dropdown_ctx())

	local over_blocks_body = false
	if not self._dropdown and not self._colorpicker then
		local bp, region = self:_panel_at(self._d.cx, self._d.cy)
		over_blocks_body = bp ~= nil and bp.id == "blocks" and region == "body"
	end
	self:_blocks_handle_scroll(view_input, over_blocks_body)

	local field_ate_escape = false
	if TextField.any_focused() then
		self:_sync_multiline_wrap()
		field_ate_escape = TextField.update() == "cancel"
	end

	self:_rename_update()

	if not field_ate_escape and not TextField.any_focused() and view_input and view_input:get("back") then

		if self:_cancel_drag() then
			return
		end
		self:_end_drag()

		if self._ctxmenu then
			self._ctxmenu = nil
		elseif self._browser then
			self:_close_browser()
		elseif self._library then
			self:_close_library()
		elseif self._cb then
			self:_close_cb()
		elseif self._td then
			self:_close_td()
		elseif self._ide then
			self:_close_ide()
		elseif self._edit_block then
			self:_exit_edit_block()
		else
			mod.hud_studio_editor_active = false
			self:_pop_cursor()
		end
		return
	end

	if not self._drag then
		History.resume_all()
	end

	if not TextField.any_focused() and not self._drag then
		local key = KeyboardNav.history_key()
		if key then

			local undoing = key == "undo"
			local applied = undoing and History.undo() or (not undoing and History.redo())
			if applied then
				mod.dl.log.notify(mod:localize(undoing and "history_undo" or "history_redo"))
			else
				mod.dl.log.notify(
					mod:localize(undoing and "history_nothing_undo" or "history_nothing_redo")
				)
			end
			self:_after_history()
			return
		end
	end

	if not TextField.any_focused() and not self._drag then
		KeyboardNav.update(self:_keynav_ctx())
	else

		KeyboardNav.release(self:_keynav_ctx())
	end

	History.begin()
	self:_update_interaction(view_input)
	History.commit()
end

HudEditor._clear_edit_state = function(self)
	TextField.cancel()
	self._dropdown = nil
	self._dropdown_hover = nil
	self._colorpicker = nil
	self._ctxmenu = nil
	self._acc_hover = nil

	KeyboardNav.release(self:_keynav_ctx())
	self:_dismiss_ide()

	if self._browser then
		self:_close_browser()
	end
	if self._library then
		self:_close_library()
	end
	if self._td then
		self:_close_td()
	end
	if self._cb then
		self:_close_cb()
	end
end

HudEditor._draw_grid = function(self, screen_w, screen_h, z)
	local canvas = Session.canvas()
	Grid.draw(self._d, 0, 0, screen_w, screen_h, canvas.grid_rows or 0, canvas.grid_cols or 0, z)
end

HudEditor._draw_block_grids = function(self, dcx, dcy, z, scale)
	local blocks = Session.blocks()
	for i = 1, #blocks do
		local block = blocks[i]
		local rows = block.grid_rows or 0
		local cols = block.grid_cols or 0
		if (rows > 0 or cols > 0) and self:_block_on_canvas(block) then
			local x0, y0, x1, y1 = block_bounds(block, dcx, dcy, scale)
			Grid.draw(self._d, x0, y0, x1 - x0, y1 - y0, rows, cols, z)
		end
	end
end

HudEditor._outlines_ctx = function(self)
	return {
		sel_block = self._sel_block,
		sel_node = self._sel_node,
		edit_block = self._edit_block,
		hover_block = self._hover_block,
		hover_node = self._hover_node,
		hover_row = self._tree.hover_row and self._tree.rows and self._tree.rows[self._tree.hover_row] or nil,
		on_exit_edit = function()
			self:_exit_edit_block()
		end,
		on_canvas = function(block)
			return self:_block_on_canvas(block)
		end,
	}
end

HudEditor._multiline_rc_at = function(self, box, cx, cy)
	return TextMetrics.multiline_rc_at(
		self._ui_renderer,
		box.x + 4,
		box.y + PANEL.MULTILINE_PAD,
		PANEL.MULTILINE_LINE_H,
		cx,
		cy
	)
end

HudEditor._draw_ide = function(self, ui_renderer, z)
	local dragging = DragController.is_panel_drag(self._drag, self._ide_panel)
	CodeEditor.draw(self._d, self:_ide_ctx(), self._ide_lay, dragging, z, self._ide_hover.close)
end

---@param ui_renderer table  unused; kept for symmetry with the other _draw_* panels
---@param z number
HudEditor._draw_browser = function(self, ui_renderer, z)
	BrowserController.draw(self._d, self:_browser_ctx(), z)
end

---@param ui_renderer table  unused; kept for symmetry with the other _draw_* panels
---@param z number
HudEditor._draw_library = function(self, ui_renderer, z)
	LibraryController.draw(self._d, self:_library_ctx(), z)
end

HudEditor._draw_td = function(self, ui_renderer, z)
	local lay = self._td_lay
	if not lay then
		return
	end
	local node = self:_selected_node()
	local dragging = DragController.is_panel_drag(self._drag, self._td_panel)

	local field = self._td.field
	local title = mod:localize(
		"panel_threshold_title_dynamic",
		(node and (node.label or node.id)) or "?",
		(field:gsub("^%l", string.upper):gsub("_", " "))
	)

	ThresholdDesignerPanel.draw(self._d, self._td_panel, z, lay, dragging, {
		title = title,
		close_hover = self._td_close_hover,
		draw_field = self._td_draw_field,
	})
end

HudEditor._draw_cb = function(self, ui_renderer, z)
	local lay = self._cb_lay
	if not lay then
		return
	end
	local dragging = DragController.is_panel_drag(self._drag, self._cb_panel)

	local node = self._cb.node
	local title = mod:localize(
		"panel_condition_title_dynamic",
		(node and (node.label or node.id)) or (select(2, self:_selected_node()) or {}).name or "?"
	)

	ConditionBuilderPanel.draw(self._d, self._cb_panel, z, lay, dragging, {
		title = title,
		close_hover = self._cb_close_hover,
		draw_field = self._cb_draw_field,
	})
end

HudEditor._draw_field = function(self, item, z)
	local d = self._d
	local ctrl = item.ctrl

	local hovered = self._acc_hover ~= nil and self._acc_hover.ctrl == ctrl

	if item.label_rect.h > 0 and ctrl.label then
		Label.field(d, item.label_rect, ctrl.label, z + 1)
	end

	local cr = item.ctrl_rect
	local kind = ctrl.kind

	if kind == "readonly" then
		Label.readonly(d, cr, ctrl.value() or "", z + 1)
	elseif kind == "note" then
		Label.note(d, cr, ctrl.value() or "", z + 1, item.note_lines)
	elseif kind == "text" then

		TextInput.draw(d, ctrl, item.parts.box, TextField.is_focused(ctrl.token), hovered, z, ctrl.input_opts)
	elseif kind == "numeric" then
		Numeric.draw(d, ctrl, item.parts, TextField.is_focused(ctrl.token), hovered, z)
	elseif kind == "dropdown" then
		local open = self._dropdown ~= nil and self._dropdown.ctrl == ctrl
		Dropdown.draw(d, ctrl, item.parts, open, hovered, z)
	elseif kind == "checkbox" then
		Checkbox.draw(d, ctrl, item.parts, hovered, z)
	elseif kind == "checklist" then
		Checklist.draw(d, ctrl, item.parts, hovered, z)
	elseif kind == "button" then

		local box = item.parts.box

		local face = ctrl.text
		if type(face) == "function" then
			face = face()
		end

		local key = "field_btn/" .. tostring(ctrl.field or item.key or "?") .. "/" .. tostring(ctrl.action or "")
		Button.draw(d, key, box.x, box.y, z, box.w, box.h, face or "…", {
			disabled = type(ctrl.disabled) == "function" and ctrl.disabled() or ctrl.disabled == true,
		})

		if hovered and ctrl.tooltip then
			Tooltip.draw(d, ctrl.tooltip)
		end
	elseif kind == "rgba" then

		Rgba.draw(d, ctrl, item.parts, {
			copy_hover = self._rgba_copy_hover == ctrl,
			paste_hover = self._rgba_paste_hover == ctrl,
		}, z)
	elseif kind == "thresholds" then
		ThresholdBar.draw(d, ctrl.get(), item.parts.box, z, ctrl.band_scale and ctrl.band_scale())
		if hovered then
			Tooltip.draw(d, mod:localize("thresholds_open_tooltip"))
		end
	elseif kind == "conditions" then

		local spec = ctrl.get()
		local count = (spec and spec.rows) and #spec.rows or 0
		local text = mod:localize("cb_open_text_no_conditions")
		if count == 1 then
			text = mod:localize("cb_open_text_condition")
		elseif count > 1 then
			text = mod:localize("cb_open_text_conditions", count)
		end
		local box = item.parts.box
		Button.draw(d, "field_btn", box.x, box.y, z, box.w, box.h, text)
		if hovered then
			Tooltip.draw(d, mod:localize("cb_open_tooltip"))
		end
	end
end

HudEditor._draw_label_column_toggle = function(self, panel, z)
	local size = PanelHeader.CLOSE_W
	local x = panel.x + panel.w - size - 4
	local y = panel.y + math.floor((PANEL.TITLE_H - size) * 0.5)
	local next_labelled = not self._label_column

	Button.draw(self._d, "property_label_column", x, y, z, size, size, nil, {
		tooltip = next_labelled and mod:localize("panel_label_layout_wide")
			or mod:localize("panel_label_layout_compact"),
		on_click = function()
			self:_toggle_label_column()
		end,
	})
	EditorIcons.draw_field_layout_icon(self._d, x, y, z + 2, next_labelled)
end

HudEditor._draw_property_panel = function(self, ui_renderer, panel, z)
	local form = self._node_form
	local d = self._d

	if form then
		for i = 1, #form.items do
			local item = form.items[i]
			if item.t == "header" then

				local hovered = self._acc_hover ~= nil and self._acc_hover.key == item.key
				Label.section_header(self._d, item, hovered, z)
			elseif item.t == "grouplabel" then

				Label.group(self._d, item.x, item.y, item.w, item.text, z + 1, item.center_h)
			else
				self:_draw_field(item, z + 1)
			end
		end
		return
	end

	local x, y, w = panel.x, panel.y, panel.w
	local px = x + PANEL.PAD
	local py = y + PANEL.TITLE_H + PANEL.PAD
	local tw = w - PANEL.PAD * 2

	d:text_center(
		mod:localize("property_nothing_selected"),
		ROW_FONT_SIZE,
		px,
		py,
		z,
		tw,
		ROW_FONT_SIZE,
		COLOR.ROW_NODE_TEXT
	)
end

HudEditor._draw_dropdown_popup = function(self, z)
	DropdownController.draw_popup(self._d, self:_dropdown_ctx(), z)
end

HudEditor._draw_colorpicker_popup = function(self, z)
	ColorPickerController.draw_popup(self._d, self:_colorpicker_ctx(), z)
end

HudEditor._draw_panel = function(self, ui_renderer, panel, z)
	local h = self:_panel_height(panel)
	local dragging_this = DragController.is_panel_drag(self._drag, panel)

	if panel.id == "blocks" then
		BlocksPanel.draw(self._d, panel, z, h, dragging_this, {
			rows = self._tree:current_rows(),
			blocks = Session.blocks(),
			sel_darktide = self._sel_darktide,
			sel_canvas = self._sel_canvas,

			sel_folder = self._sel_folder and self._sel_folder.name or nil,
			sel_block = self._sel_block,
			sel_node = self._sel_node,
			hover_row = self._tree.hover_row,
			scroll = self._tree.scroll,

			rename_row = self:_rename_flat_row(),

			hide_hidden = Session.hides_hidden_blocks(),
			is_hidden = function(block)
				return Session.is_hidden(block)
			end,
			is_collapsed = function(block)
				return self._tree.collapsed[block] == true
			end,

			is_folder_collapsed = function(name)
				return self._tree:folder_collapsed(name)
			end,

			is_bin_open = function(block)
				return self._tree:bin_open(block)
			end,
			on_toggle_folder = function(name, next_on)
				self._tree:toggle_folder_visible(name, next_on)
			end,
			on_copy = function()
				self:_copy_selection()
			end,
			on_delete = function()
				self:_delete_selection()
			end,
			on_add_folder = function()
				self:_new_folder()
			end,
			on_add_block = function()
				self:_add_block()
			end,
			on_add_node = function(bi, which)
				self:_add_node(bi, which)
			end,
			on_toggle_visible = function(bi, ni, next_on)
				self:_toggle_visibility(bi, ni, next_on)
			end,
			on_set_visible_state = function(bi, ni, state)
				self:_set_visibility_state(bi, ni, state)
			end,

			all_collapsed = self._tree:all_collapsed(),
			on_collapse_all = function()
				self._tree:toggle_collapse_all()
			end,
			on_open_library = function()
				self:_open_library()
			end,
			on_hide_hidden = function(on)
				self:_set_hide_hidden(on)
			end,
		})

		if self._rename then
			self:_draw_rename_input(panel, z + 8)
		end
	else
		PanelBody.draw(self._d, panel, h, z)
		PanelHeader.draw(self._d, panel, z, dragging_this)
		self:_draw_property_panel(ui_renderer, panel, z + 2)
		self:_draw_label_column_toggle(panel, z + 6)
	end
end

HudEditor._draw = function(self, pass, ui_renderer, ui_style, ui_content, position, size)
	if not self.edit_mode() then
		return
	end

	self._tree:rebuild()
	self:_rebuild_node_form()
	self._ide_lay = (self._ide and IdeController.layout(self:_ide_ctx())) or nil
	self._browser_lay = (self._browser and BrowserController.layout(self:_browser_ctx())) or nil
	self._library_lay = (self._library and LibraryController.layout(self:_library_ctx())) or nil
	self._td_lay = self:_td_layout()
	self._cb_lay = self:_cb_layout()

	local inv = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale) or 1
	local sw = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width) or 1920
	local sh = (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height) or 1080
	local dcx = sw * inv * 0.5
	local dcy = sh * inv * 0.5
	local z_base = (position and position[3]) or 1

	local hud_scale = HudScale.pct()
	self:_draw_grid(math.floor(sw * inv), math.floor(sh * inv), z_base + Z.GRID)
	self:_draw_block_grids(dcx, dcy, z_base + Z.GRID, hud_scale)

	Outlines.draw(self._d, self:_outlines_ctx(), dcx, dcy, z_base + Z.CANVAS, hud_scale)

	local panels = self._panels
	for i = 1, #panels do
		self:_draw_panel(ui_renderer, panels[i], z_base + (panels[i].z or C.PANEL))
	end

	self:_draw_ide(ui_renderer, z_base + Z.PANEL_IDE)
	self:_draw_browser(ui_renderer, z_base + Z.PANEL_BROWSER)
	self:_draw_library(ui_renderer, z_base + Z.PANEL_LIBRARY)
	self:_draw_td(ui_renderer, z_base + Z.PANEL_THRESHOLD)
	self:_draw_cb(ui_renderer, z_base + Z.PANEL_CONDITION)

	self:_draw_dropdown_popup(z_base + Z.POPPER)
	self:_draw_colorpicker_popup(z_base + Z.POPPER)

	ContextMenuController.draw_popup(self._d, self:_ctxmenu_ctx(), z_base + Z.POPPER)
end

return HudEditor
