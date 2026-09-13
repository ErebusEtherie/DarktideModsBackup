local mod = get_mod("realms_loadout")
if mod._stimm_workspace_class then return mod._stimm_workspace_class end
local Native = require("scripts/ui/views/broker_stimm_builder_view/broker_stimm_builder_view")
local NodeBase = require("scripts/ui/views/node_builder_view_base/node_builder_view_base")
local PlayerAbilities = require("scripts/settings/ability/player_abilities/player_abilities")
local Stimm = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/stimm")
local Presets = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/workspace_presets")
local definitions = table.clone_instance(require("scripts/ui/views/broker_stimm_builder_view/broker_stimm_builder_view_definitions"))
local View = class("RealmsLoadoutStimmView", "BrokerStimmBuilderView")
mod._stimm_workspace_class = View
function View:_get_player_mode_layout()
  return Stimm.editor_layout(self._preview_player:profile())
end
function View:init(settings, context)
  self._context, self._is_readonly = context, context.is_readonly
  context.player_mode = true
  self._preview_player = context.player
  self._character = context.player:character_id()
  self._connection = Managers.connection and (Managers.connection._connection_host or Managers.connection._connection_client)
  self._peer_id, self._local_player_id = context.player:peer_id(), context.player:local_player_id()
  self._is_own_player = context.player == self:_player()
  NodeBase.init(self, definitions, settings, context)
  self._gamepad_cursor_current_pos = Vector3Box(Vector3(RESOLUTION_LOOKUP.width * 0.5, 200 * RESOLUTION_LOOKUP.scale, 0))
  self._gamepad_cursor_current_vel, self._gamepad_cursor_target_pos, self._gamepad_cursor_average_vel = Vector3Box(), Vector3Box(), Vector3Box()
  self._gamepad_cursor_snap_delay, self._grid_size = 0, 30
  self._save_talent_changes = false
end
function View:refresh_selection()
  if self._loading or not self._active_layout then return end
  local profile = self._preview_player:profile()
  self._preset_key = Presets.snapshot(profile).key
  self._node_widget_tiers = mod.workspace_stimm_nodes(profile)
  self._cap = mod.workspace_stimm_cap(profile)
  for _, widget in ipairs(self._node_widgets or {}) do
    local selected = self._node_widget_tiers[widget.name] ~= nil
    widget.content.has_points_spent, widget.content.highlighted = selected, selected
    widget.content.alpha_anim_progress = selected and 1 or 0
  end
  self._draw_instant_lines = true
  self:_refresh_all_nodes()
end
function View:on_enter()
  self._talent_hover_data = {}
  NodeBase.on_enter(self)
  self:refresh_selection()
  self._all_nodes_cost_one = false
  local Overlay = require("scripts/ui/view_elements/view_element_tutorial_overlay/view_element_tutorial_overlay")
  self._tutorial_overlay = self:_add_element(Overlay, "tutorial_overlay", 200, {})
end
function View:_publish()
  if self._is_readonly or not mod:is_enabled() then return end
  local player = self._preview_player
  local connection = Managers.connection and (Managers.connection._connection_host or Managers.connection._connection_client)
  local parent = self._context.parent
  local root = parent and parent._context and parent._context.parent
  if not player or player.__deleted or player:character_id() ~= self._character or connection ~= self._connection
    or parent and parent.__deleted or root and (root.__deleted or root._workspace_invalid or root._workspace_closing) then return end
  mod.workspace_stimm_save(self._preview_player, self._node_widget_tiers, self._preset_key)
end
function View:_max_node_points() return mod.workspace_stimm_cap(self._preview_player:profile()) end
function View:on_exit() return NodeBase.on_exit(self) end
function View:update(dt, t, input_service)
  if mod:is_enabled() and self._active_layout and not self._loading then
    local profile = self._preview_player:profile()
    if self._preset_key ~= Presets.snapshot(profile).key or self._cap ~= mod.workspace_stimm_cap(profile) then self:refresh_selection() end
  end
  return Native.update(self, dt, t, input_service)
end

View._remove_node_point_on_widget = function (self, widget)
	NodeBase._remove_node_point_on_widget(self, widget)
	self:_publish()

	self._save_talent_changes = true
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

		self:_publish()
	end

	return success
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


	self:_publish()

	self._save_talent_changes = true
end

View._update_center_progress = function (self, dt, t)
	local max_points = self:_max_node_points()
	local available_points = self:_points_available()
	local target_fill = max_points == 0 and 0 or available_points / max_points
	local start_node = self:start_node()
	local content = start_node.content

	content.velocity = content.velocity or 0

	local current_fill = content.current_fill or target_fill
	local diff = target_fill - current_fill

	if diff ~= 0 or not content.current_fill then
		local target_velocity = math.remap(0, 1, 0.01, 10, math.abs(diff)) * math.sign(diff)
		local dt_multiplier = math.abs(target_velocity) < math.abs(content.velocity) and 40 or 2

		content.velocity = math.lerp(content.velocity, target_velocity, dt * dt_multiplier)

		local step = content.velocity * dt

		if math.abs(step) > math.abs(diff) then
			current_fill = target_fill
		else
			current_fill = current_fill + step
		end

		current_fill = math.clamp01(current_fill)
		content.current_fill = current_fill
		start_node.style.center_texture.material_values.fill_amount = math.remap(0, 1, 0.21, 0.76, current_fill)

		local player = self._preview_player

		if player then
			local widgets_by_name = self._widgets_by_name
			local profile = player:profile()

			widgets_by_name.summary_header.content.viscocity_text = string.format("%s%%", math.round((1 - content.current_fill) * 100))

			local syringe_ability = PlayerAbilities.broker_ability_syringe
			local lerp_cooldown = syringe_ability.cooldown
			local temp_profile = self._temp_profile or {}

			self._temp_profile = temp_profile
			temp_profile.selected_nodes = self._node_widget_tiers
			temp_profile.archetype = profile.archetype
			temp_profile.expertise_points = self:_max_node_points()

			local cooldown = syringe_ability.cooldown_lerp_func(self._temp_profile, lerp_cooldown.min, lerp_cooldown.max, 1 - current_fill)

			widgets_by_name.summary_header.content.cooldown_text = string.format("%ss", cooldown)
		end
	end

	local outer_fill_anim_time = 1
	local should_have_fill = self:_node_points_spent() > 0

	content.outer_filled = content.outer_filled or should_have_fill and 1 or 0

	local outer_from = should_have_fill and 0 or 1
	local outer_to = outer_from == 1 and 0 or 1

	if content.had_fill ~= should_have_fill or not content.change_outer_fill_t then
		content.had_fill = should_have_fill
		content.change_outer_fill_t = t - math.ilerp(outer_from, outer_to, content.outer_filled) * outer_fill_anim_time
	end

	local outer_progress = math.ease_in_out_quart(math.clamp01((t - content.change_outer_fill_t) / outer_fill_anim_time))
	local outer_fill = math.lerp_clamped(outer_from, outer_to, outer_progress)

	start_node.style.fill_texture.material_values.fill_amount = outer_fill
	content.outer_filled = outer_fill

	local invert = outer_from == 1

	self:_update_start_node_color(invert and 1 - outer_fill or outer_fill)
end

return View
