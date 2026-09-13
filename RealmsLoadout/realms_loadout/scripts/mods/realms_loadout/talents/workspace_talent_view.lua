local mod = get_mod("realms_loadout")
if mod._talent_workspace_class then return mod._talent_workspace_class end
local Native = require("scripts/ui/views/talent_builder_view/talent_builder_view")
local NodeBase = require("scripts/ui/views/node_builder_view_base/node_builder_view_base")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
-- Take one private template snapshot. NodeBase.init deep-merges this into a
-- fresh per-view table; copying it again on every opening duplicates that work.
local definitions = table.clone_instance(require("scripts/ui/views/talent_builder_view/talent_builder_view_definitions"))
local View = class("RealmsLoadoutTalentView", "TalentBuilderView")
mod._talent_workspace_class = View

function View:init(settings, context)
  context.player_mode = true
  context.current_profile_equipped_talents = context.current_profile_equipped_talents
    or context.parent and context.parent._current_profile_equipped_talents
  self._context = context
  self._is_readonly = context and context.is_readonly
  self._preview_player = context.player
  self._peer_id = context.player:peer_id()
  self._local_player_id = context.player:local_player_id()
  self._is_own_player = context.player == self:_player()
  -- Native algorithms/materials, private definitions and hook target.
  NodeBase.init(self, definitions, settings, context)
  self._save_talent_changes = false
  local x = RESOLUTION_LOOKUP.width * 0.5
  local y = 200 * RESOLUTION_LOOKUP.scale
  self._gamepad_cursor_current_pos = Vector3Box(Vector3(x, y, 0))
  self._gamepad_cursor_current_vel = Vector3Box()
  self._gamepad_cursor_target_pos = Vector3Box(Vector3(x, y, 0))
  self._gamepad_cursor_average_vel = Vector3Box()
  self._gamepad_cursor_snap_delay = 0
  self._gamepad_cursor_previous_scroll_height = 0
  self._summery_window_input_action = "talents_summery_overview_pressed"
  self._grid_size = 30
end

function View:on_exit()
  local parent = self._context and self._context.parent
  if parent and mod.workspace_commit then mod.workspace_commit(parent) end
  if mod._workspace_talent_adapter then mod._workspace_talent_adapter.on_exit(parent or self) end
  return Native.on_exit(self)
end

-- Native presentation with private selection events and no official preset writes.
View.on_enter = function (self)
	if self._player_mode then
		self._definitions.scenegraph_definition.layout_background.horizontal_alignment = "center"
	end

	self._talent_hover_data = {}

	NodeBase.on_enter(self)

	self._widgets_by_name.summary_window.content.visible = false
	self._widgets_by_name.summary_button.style.text.text_horizontal_alignment = "center"
	self._widgets_by_name.summary_button.style.text.text_vertical_alignment = "top"
	self._widgets_by_name.summary_button.content.hotspot.pressed_callback = callback(self, "cb_on_talent_summary_pressed")

	self:_update_summery_button_text()

	local active_layout = self._active_layout
	if not active_layout or type(active_layout.nodes) ~= "table" then
		return
	end

	local nodes = active_layout.nodes
	local player = self._preview_player
	local profile = player:profile()
	-- The workspace owns its saved build. Never read or repair an official preset.
	self._node_widget_tiers = table.clone_instance(self._context.current_profile_equipped_talents or {})

	local start_centered
	local all_nodes_cost_one = true
	local widgets = self._node_widgets

	for i = 1, #widgets do
		local widget = widgets[i]
		local content = widget.content
		local node_selected, _ = self:_node_points_by_widget(widget)

		content.has_points_spent = node_selected
		content.highlighted = content.has_points_spent
		content.alpha_anim_progress = content.has_points_spent and 1 or 0

		local node = content.node_data

		if node.type == "start" then
			start_centered = node.connector_offset[1] == 0 and node.connector_offset[2] == 0
		end

		if node.type ~= "start" then
			all_nodes_cost_one = all_nodes_cost_one and node.cost == 1
		end
	end

	self._all_nodes_cost_one = all_nodes_cost_one
	self._draw_instant_lines = true

	self:_refresh_all_nodes()
	self:_update_base_talent_loadout_presentation()

	local save_manager = Managers.save
	local save_data = save_manager:account_data()
	local show_tutorial_popup = not save_data or not save_data.talent_tutorial_popup_shown

	if show_tutorial_popup and not self._is_readonly and self._is_own_player then
		self:_setup_tutorial_grid()
		self:_present_tutorial_popup_page(1)
	else
		self:_close_tutorial_window()
	end

	if self._player_mode and active_layout and active_layout.base_offset_x then
		self:_set_scenegraph_position("layout_background", active_layout.base_offset_x, nil, nil, nil, nil)
	end

	self._widgets_by_name.archetype_middle_coin.content.visible = start_centered
	self._widgets_by_name.layout_background.content.visible = not start_centered
	self._starts_centered = start_centered
end

function View:replace_selected_nodes(nodes)
  self._context.current_profile_equipped_talents = table.clone_instance(nodes or {})
  -- NodeBase allocates an empty widget table before loading the layout. Preset
  -- events may arrive in that interval; on_enter consumes the latest context.
  if self._loading or not self._active_layout or not self._node_widgets then return end
  self._node_widget_tiers = table.clone_instance(nodes or {})
  self._tamm_user_edited, self._save_talent_changes = false, false
  for _, widget in ipairs(self._node_widgets) do
    local content = widget.content
    content.has_points_spent = self:_node_points_by_widget(widget)
    content.highlighted = content.has_points_spent
    content.alpha_anim_progress = content.has_points_spent and 1 or 0
    if content.parent_line_anim_data then table.clear(content.parent_line_anim_data) end
  end
  -- As in native preset switching, a loaded build is already connected.
  -- Inventory setup can refresh it after the first instant draw on entry.
  self._draw_instant_lines = true
  self:_set_selected_node(nil)
  self:_refresh_all_nodes()
  self:_update_base_talent_loadout_presentation()
end

View._add_node_point_on_widget = function (self, widget, amount_to_add)
	local success = NodeBase._add_node_point_on_widget(self, widget, amount_to_add)

	if success then
		self._save_talent_changes = true

		local parent_line_anim_data = widget.content.parent_line_anim_data

		if parent_line_anim_data then
			table.clear(parent_line_anim_data)
		end

		local node = widget.content.node_data
		local widget_name = widget.name
		local widgets_by_name = self._widgets_by_name
		local children = node.children

		for i = 1, #children do
			local child_name = children[i]

			if self:_node_by_name(child_name) then
				local child_widget = widgets_by_name[child_name]
				local child_parent_line_anim_data = child_widget.content.parent_line_anim_data
				local child_widget_anim_data = child_parent_line_anim_data and child_parent_line_anim_data[widget_name]

				if child_widget_anim_data then
					child_widget_anim_data.progress_fraction = 0
					child_widget_anim_data.progress_complete = false
				end
			end
		end

		if self:_points_available() == 0 then
			self:_play_sound(UISoundEvents.talent_last_point_spent)
		end

		self:_update_base_talent_loadout_presentation()
		Managers.event:trigger("tpm_workspace_nodes_updated", self._node_widget_tiers)
	end

	return success
end

View._remove_node_point_on_widget = function (self, widget, skip_tooltip_update)
	NodeBase._remove_node_point_on_widget(self, widget, skip_tooltip_update)
	self:_update_base_talent_loadout_presentation()
	Managers.event:trigger("tpm_workspace_nodes_updated", self._node_widget_tiers)

	self._save_talent_changes = true
end

View.clear_node_points = function (self)
	NodeBase.clear_node_points(self)

	local node_widgets = self._node_widgets

	for i = 1, #node_widgets do
		local widget = node_widgets[i]
		local parent_line_anim_data = widget.content.parent_line_anim_data

		if parent_line_anim_data then
			table.clear(parent_line_anim_data)
		end
	end

	self:_update_base_talent_loadout_presentation()

	Managers.event:trigger("tpm_workspace_nodes_updated", self._node_widget_tiers)

	self._save_talent_changes = true
end

function View:event_on_profile_preset_changed() end

return View
