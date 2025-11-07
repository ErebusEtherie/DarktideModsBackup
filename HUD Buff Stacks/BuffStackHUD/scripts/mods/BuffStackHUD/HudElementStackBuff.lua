local mod = get_mod("BuffStackHUD")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")

local definitions = {
  	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
  	},
  	widget_definitions = {
  	}
}


for i = 1, mod.buff_max do
	local buff_group_name = "buff_" .. i
	definitions["scenegraph_definition"][buff_group_name .. "_area"] = {
		parent = "screen",
		size = { 150, 150 },
		vertical_alignment = "center",
		horizontal_alignment = "center",
		position = { 200, 300 - (100 * i), 5 }
	}
	definitions["widget_definitions"][buff_group_name] = UIWidget.create_definition({
		{
			pass_type = "text",
			value = "",
			value_id = "stack",
			style_id = "stack",
			style = {
				font_type = "machine_medium",
				font_size = mod.stack_font_size,
				drop_shadow = true,
				text_vertical_alignment = "center",
				text_horizontal_alignment = "center",
				text_color = Color.dark_magenta(255, true),
				offset = { 0, 0, 100 }
			}
		},
		{
			pass_type = "texture",
			style_id = "charge_bar",
			value = "content/ui/materials/effects/powersword_bar",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				offset = { 15, 15, 99 },
				size = { 0, 0 },
				color = Color.dark_magenta(255, true),
				material_values = {
					active = 1,
					color_blend = 0,
					fill_opacity = 1,
					lockout = 0,
					outline_opacity = 1,
					progress = 0,
				},
			},
		},
		{
			pass_type = "text",
			value = "",
			value_id = "label",
			style_id = "label",
			style = {
				font_type = "machine_medium",
				font_size = mod.label_font_size,
				drop_shadow = true,
				text_vertical_alignment = "center",
				text_horizontal_alignment = "center",
				text_color = Color.dark_magenta(255, true),
				offset = { 0, 60, 101 }
			}
		},
	}, buff_group_name .. "_area")
end

HudElementStackBuff = class("HudElementStackBuff", "HudElementBase")

function HudElementStackBuff:init(parent, draw_layer, start_scale)
	HudElementStackBuff.super.init(self, parent, draw_layer, start_scale, definitions)
end

HudElementStackBuff.clear_timer = function(self)
	for _, w in pairs(self._widgets) do
		w.visible = false
	end
end

local _populate_buff = function(widget, buff_name, stack_count, max_stack, duration_pct)
	widget.visible = true
	widget.content.stack = stack_count
	widget.content.label = mod.labels[buff_name] and mod:localize(buff_name) or ""
	local font_size = mod.stack_font_size
	widget.style.charge_bar.visible = duration_pct ~= 0
	widget.style.stack.font_size = font_size
	widget.style.label.font_size = mod.label_font_size
	widget.style.charge_bar.size = { 150, 150 }
	widget.style.charge_bar.material_values.progress = math.lerp(0.028, 0.252, duration_pct)
	widget.style.charge_bar.material_values.color_blend = stack_count > max_stack and 1 or math.lerp(0.01, 1, stack_count / (max_stack or 1))

	local custom_color = mod.colors[buff_name]
	if custom_color and Color[custom_color] then
		widget.style.stack.text_color = Color[custom_color](255, true)
		widget.style.charge_bar.color = Color[custom_color](255, true)
		widget.style.label.text_color = Color[custom_color](255, true)
	else
		widget.style.stack.text_color = Color.dark_magenta(255, true)
		widget.style.charge_bar.color = Color.dark_magenta(255, true)
		widget.style.label.text_color = Color.dark_magenta(255, true)
	end
end

local function get_buff_by_name(buff_extensions, buff_name)
	for _, buff in pairs(buff_extensions._buffs_by_index) do
		if buff._template_name == buff_name then
			return buff
		end
	end
	return nil
end

HudElementStackBuff.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudElementStackBuff.super.update(self, dt, t, ui_renderer, render_settings, input_service)
	local player = Managers.player:local_player(1)
	if not player or not player.player_unit then
		return self:clear_timer()
	end
	local archetype = player:archetype_name()
	local buff_extensions = ScriptUnit.extension(player.player_unit, "buff_system")
	if not buff_extensions then
		return self:clear_timer()
	end
	local buff_max = #self._widgets
	local nodupe = {}
	local buffs_needs_slots = {}
	local reserved_slots = {}
	local duration_need_update = {}
	local buff_pairs = {}
	for _, buff in pairs(buff_extensions._buffs_by_index) do
		local template = buff:template()
		local temp_max_stack = 1
		if template and template.name then
			if mod.colors[template.name] then
				local buff_stack = buff:stat_buff_stacking_count() or 0
				local duration = buff:duration() or 0
				local duration_pct = buff:duration_progress() or 0
				if template.name == "veteran_weapon_switch_ranged_visual" or template.name == "psyker_empowered_grenades_passive_visual_buff_increased" then
					-- Weapon specialist uses an unconventional way to stores the charges
					-- So we must hard code this
					buff_stack = buff:visual_stack_count() or 0
					-- mod:dump(buff)
				elseif template.name == "zealot_fanatic_rage" then
					-- The zealot keystone also don't use conventional way to store stacks
					buff_stack = buff:template_data().talent_resource_component.current_resource or 0
					temp_max_stack = buff:template_data().talent_resource_component.max_resource or 1
					if buff_stack == temp_max_stack then
						local rage_real_buff = get_buff_by_name(buff_extensions, "zealot_fanatic_rage_buff")
						if rage_real_buff then
							duration_pct = rage_real_buff:duration_progress() or 0
							duration = rage_real_buff:duration() or 0
						end
					end
				end
				local finished = buff._template_data and buff._template_data.finish
				if buff_stack > 0 and duration_pct > 0 and not finished and not nodupe[template.name] then
					nodupe[template.name] = {
						stack = buff_stack,
						max_stack = buff.max_stacks and buff:max_stacks() or temp_max_stack,
						duration_pct = duration_pct,
						duration = duration,
					}
					local last_slot = mod.last_buff_idx[template.name]
					local reserve_slot = mod.reserve[template.name]
					if reserve_slot and reserve_slot <= buff_max and not reserved_slots[reserve_slot] then
						reserved_slots[reserve_slot] = template.name
					elseif last_slot and last_slot <= buff_max and not reserved_slots[last_slot] then
						reserved_slots[last_slot] = template.name
					else
						buffs_needs_slots[#buffs_needs_slots + 1] = template.name
						-- mod:echo("buff need slot " .. template.name)
					end
				end
			end
			if not buff_pairs[template.name] then
				buff_pairs[template.name] = buff
			end
		end
	end

	for buff_name, buff in pairs(nodupe) do
		if buff.duration_pct == 1 and mod.child_parent_buffs[buff_name] and buff_pairs[mod.child_parent_buffs[buff_name]] then
			local parent_buff = buff_pairs[mod.child_parent_buffs[buff_name]]
			buff.duration_pct = parent_buff:duration_progress() or 1
			buff.duration = (parent_buff._template and parent_buff._template.child_duration) or (parent_buff._template_override_data and parent_buff._template_override_data.child_duration) or buff.duration
		end
		if buff.duration == 0 then
			if buff.max_stack > 1 then
				buff.duration_pct = buff.stack / buff.max_stack
			else
				buff.duration_pct = 0
			end
		end
	end

	mod.last_buff_idx = {}
	table.sort(buffs_needs_slots, function(a, b)
		return a < b
	end)
	local buff_iters, _, next_idx = pairs(buffs_needs_slots)
	local buff_name = nil

	for buff_idx = 1, buff_max do
		local widget = self._widgets_by_name["buff_" .. buff_idx]
		if reserved_slots[buff_idx] then
			local buff = nodupe[reserved_slots[buff_idx]]
			_populate_buff(widget, reserved_slots[buff_idx], buff.stack, buff.max_stack, buff.duration_pct)
			mod.last_buff_idx[reserved_slots[buff_idx]] = buff_idx
		elseif not mod.emptyslots[buff_idx] then
			next_idx, buff_name = buff_iters(buffs_needs_slots, next_idx)
			if buff_name then
				local buff = nodupe[buff_name]
				_populate_buff(widget, buff_name, buff.stack, buff.max_stack, buff.duration_pct)
				-- mod:echo("new buff slot for " .. buff_name .. " on index " .. buff_idx .. " for widget " .. widget.name)
				mod.last_buff_idx[buff_name] = buff_idx
			else
				buffs_needs_slots = {}
				widget.visible = false
			end
		else
			widget.visible = false
		end
	end
end

return HudElementStackBuff
