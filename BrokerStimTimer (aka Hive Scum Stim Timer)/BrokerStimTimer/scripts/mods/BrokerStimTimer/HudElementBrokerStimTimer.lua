local mod = get_mod("BrokerStimTimer")

require("scripts/ui/hud/elements/hud_element_base")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")

local HudElementBrokerStimTimer = class("HudElementBrokerStimTimer", "HudElementBase")

local STIMM_BUFF_NAME = "syringe_broker_buff"
local STIMM_ABILITY_TYPE = "pocketable_ability"
local STIMM_ICON_MATERIAL = "content/ui/materials/icons/pocketables/hud/syringe_broker"


local function create_scenegraph()
	local icon_size = mod:get("icon_size") or 64
	local font_size = mod:get("font_size") or 30
	local text_width = font_size * 2.5
	local text_height = font_size * 1.2
	local link_all_positions = mod:get("link_all_positions") ~= false
	
	local ready_icon_x, ready_icon_y
	local active_icon_x, active_icon_y, active_text_x, active_text_y
	local cooldown_icon_x, cooldown_icon_y, cooldown_text_x, cooldown_text_y
	
	if link_all_positions then
		local shared_icon_x = mod:get("shared_icon_x") or 765
		local shared_icon_y = mod:get("shared_icon_y") or 620
		local shared_text_x = mod:get("shared_text_x") or 761
		local shared_text_y = mod:get("shared_text_y") or 670
		
		ready_icon_x = shared_icon_x
		ready_icon_y = shared_icon_y
		active_icon_x = shared_icon_x
		active_icon_y = shared_icon_y
		active_text_x = shared_text_x
		active_text_y = shared_text_y
		cooldown_icon_x = shared_icon_x
		cooldown_icon_y = shared_icon_y
		cooldown_text_x = shared_text_x
		cooldown_text_y = shared_text_y
	else
		ready_icon_x = mod:get("ready_icon_x") or 565
		ready_icon_y = mod:get("ready_icon_y") or 620
		active_icon_x = mod:get("active_icon_x") or 565
		active_icon_y = mod:get("active_icon_y") or 620
		active_text_x = mod:get("active_text_x") or 561
		active_text_y = mod:get("active_text_y") or 670
		cooldown_icon_x = mod:get("cooldown_icon_x") or 565
		cooldown_icon_y = mod:get("cooldown_icon_y") or 620
		cooldown_text_x = mod:get("cooldown_text_x") or 561
		cooldown_text_y = mod:get("cooldown_text_y") or 670
	end
	
	local scenegraph = {
		screen = {
			scale = "fit",
			size = { 1920, 1080 },
			position = { 0, 0, 0 }
		},
		shared_icon_root = {
			parent = "screen",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { icon_size, icon_size },
			position = { mod:get("shared_icon_x") or 765, mod:get("shared_icon_y") or 620, 100 }
		},
		shared_text_root = {
			parent = "screen",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { text_width, text_height },
			position = { mod:get("shared_text_x") or 761, mod:get("shared_text_y") or 670, 100 }
		},
		ready_icon_root = {
			parent = "screen",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { icon_size, icon_size },
			position = { ready_icon_x, ready_icon_y, 100 }
		},
		active_icon_root = {
			parent = "screen",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { icon_size, icon_size },
			position = { active_icon_x, active_icon_y, 100 }
		},
		active_text_root = {
			parent = "screen",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { text_width, text_height },
			position = { active_text_x, active_text_y, 100 }
		},
		cooldown_icon_root = {
			parent = "screen",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { icon_size, icon_size },
			position = { cooldown_icon_x, cooldown_icon_y, 100 }
		},
		cooldown_text_root = {
			parent = "screen",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { text_width, text_height },
			position = { cooldown_text_x, cooldown_text_y, 100 }
		}
	}
	
	return scenegraph
end

local function create_widgets()
	local icon_size = mod:get("icon_size") or 64
	local timer_text_style = table.clone(UIFontSettings.hud_body)
	timer_text_style.font_type = "machine_medium"
	timer_text_style.font_size = mod:get("font_size") or 30
	timer_text_style.drop_shadow = true
	timer_text_style.text_horizontal_alignment = "center"
	timer_text_style.text_vertical_alignment = "center"
	timer_text_style.text_color = table.clone(UIHudSettings.color_tint_main_1)
	timer_text_style.offset = { 0, 0, 1 }

	return {
		shared_icon = UIWidget.create_definition({
			{
				visible = false,
				pass_type = "texture",
				style_id = "icon",
				value = "content/ui/materials/base/ui_default_base",
				value_id = "icon",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "center",
					size = { icon_size, icon_size },
					offset = { 0, 0, 0 },
					color = mod.get_stage_color("ready"),
				},
			},
		}, "shared_icon_root"),
		shared_text = UIWidget.create_definition({
			{
				visible = false,
				pass_type = "text",
				style_id = "text",
				value = "",
				value_id = "text",
				style = timer_text_style,
			},
		}, "shared_text_root"),
		ready_icon = UIWidget.create_definition({
			{
				visible = false,
				pass_type = "texture",
				style_id = "icon",
				value = "content/ui/materials/base/ui_default_base",
				value_id = "icon",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "center",
					size = { icon_size, icon_size },
					offset = { 0, 0, 0 },
					color = mod.get_stage_color("ready"),
				},
			},
		}, "ready_icon_root"),
		active_icon = UIWidget.create_definition({
			{
				visible = false,
				pass_type = "texture",
				style_id = "icon",
				value = "content/ui/materials/base/ui_default_base",
				value_id = "icon",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "center",
					size = { icon_size, icon_size },
					offset = { 0, 0, 0 },
					color = mod.get_stage_color("active"),
				},
			},
		}, "active_icon_root"),
		active_text = UIWidget.create_definition({
			{
				visible = false,
				pass_type = "text",
				style_id = "text",
				value = "",
				value_id = "text",
				style = timer_text_style,
			},
		}, "active_text_root"),
		cooldown_icon = UIWidget.create_definition({
			{
				visible = false,
				pass_type = "texture",
				style_id = "icon",
				value = "content/ui/materials/base/ui_default_base",
				value_id = "icon",
				style = {
					horizontal_alignment = "center",
					vertical_alignment = "center",
					size = { icon_size, icon_size },
					offset = { 0, 0, 0 },
					color = mod.get_stage_color("cooldown"),
				},
			},
		}, "cooldown_icon_root"),
		cooldown_text = UIWidget.create_definition({
			{
				visible = false,
				pass_type = "text",
				style_id = "text",
				value = "",
				value_id = "text",
				style = timer_text_style,
			},
		}, "cooldown_text_root")
	}
end

HudElementBrokerStimTimer.init = function(self, parent, draw_layer, start_scale)
	local definitions = {
		scenegraph_definition = create_scenegraph(),
		widget_definitions = create_widgets()
	}

	HudElementBrokerStimTimer.super.init(self, parent, draw_layer, start_scale, definitions)
end

HudElementBrokerStimTimer.update = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudElementBrokerStimTimer.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	local custom_hud_mod = rawget(_G, "get_mod") and get_mod("custom_hud")
	local saved_node_settings = custom_hud_mod and custom_hud_mod:get("saved_node_settings") or {}
	local element_name = self.__class_name
	
	local link_all_positions = mod:get("link_all_positions") ~= false
	local shared_icon_node_name = string.format("%s|shared_icon_root", element_name)
	local shared_text_node_name = string.format("%s|shared_text_root", element_name)
	local ready_icon_node_name = string.format("%s|ready_icon_root", element_name)
	local active_icon_node_name = string.format("%s|active_icon_root", element_name)
	local active_text_node_name = string.format("%s|active_text_root", element_name)
	local cooldown_icon_node_name = string.format("%s|cooldown_icon_root", element_name)
	local cooldown_text_node_name = string.format("%s|cooldown_text_root", element_name)
	
	local has_custom_hud_shared_icon = saved_node_settings[shared_icon_node_name] ~= nil
	local has_custom_hud_shared_text = saved_node_settings[shared_text_node_name] ~= nil
	local has_custom_hud_ready_icon = saved_node_settings[ready_icon_node_name] ~= nil
	local has_custom_hud_active_icon = saved_node_settings[active_icon_node_name] ~= nil
	local has_custom_hud_active_text = saved_node_settings[active_text_node_name] ~= nil
	local has_custom_hud_cooldown_icon = saved_node_settings[cooldown_icon_node_name] ~= nil
	local has_custom_hud_cooldown_text = saved_node_settings[cooldown_text_node_name] ~= nil
	
	local is_custom_hud_shared_icon_hidden = has_custom_hud_shared_icon and (saved_node_settings[shared_icon_node_name].is_hidden == true)
	local is_custom_hud_shared_text_hidden = has_custom_hud_shared_text and (saved_node_settings[shared_text_node_name].is_hidden == true)
	local is_custom_hud_ready_icon_hidden = has_custom_hud_ready_icon and (saved_node_settings[ready_icon_node_name].is_hidden == true)
	local is_custom_hud_active_icon_hidden = has_custom_hud_active_icon and (saved_node_settings[active_icon_node_name].is_hidden == true)
	local is_custom_hud_active_text_hidden = has_custom_hud_active_text and (saved_node_settings[active_text_node_name].is_hidden == true)
	local is_custom_hud_cooldown_icon_hidden = has_custom_hud_cooldown_icon and (saved_node_settings[cooldown_icon_node_name].is_hidden == true)
	local is_custom_hud_cooldown_text_hidden = has_custom_hud_cooldown_text and (saved_node_settings[cooldown_text_node_name].is_hidden == true)
	
	if link_all_positions then
		if not has_custom_hud_shared_icon then
			self:set_scenegraph_position("shared_icon_root", mod:get("shared_icon_x") or 765, mod:get("shared_icon_y") or 620, 100)
		end
		if not has_custom_hud_shared_text then
			self:set_scenegraph_position("shared_text_root", mod:get("shared_text_x") or 761, mod:get("shared_text_y") or 670, 100)
		end
	else
		if not has_custom_hud_ready_icon then
			self:set_scenegraph_position("ready_icon_root", mod:get("ready_icon_x") or 565, mod:get("ready_icon_y") or 620, 100)
		end
		if not has_custom_hud_active_icon then
			self:set_scenegraph_position("active_icon_root", mod:get("active_icon_x") or 565, mod:get("active_icon_y") or 620, 100)
		end
		if not has_custom_hud_active_text then
			self:set_scenegraph_position("active_text_root", mod:get("active_text_x") or 561, mod:get("active_text_y") or 670, 100)
		end
		if not has_custom_hud_cooldown_icon then
			self:set_scenegraph_position("cooldown_icon_root", mod:get("cooldown_icon_x") or 565, mod:get("cooldown_icon_y") or 620, 100)
		end
		if not has_custom_hud_cooldown_text then
			self:set_scenegraph_position("cooldown_text_root", mod:get("cooldown_text_x") or 561, mod:get("cooldown_text_y") or 670, 100)
		end
	end

	local shared_icon_widget = self._widgets_by_name.shared_icon
	local shared_text_widget = self._widgets_by_name.shared_text
	local ready_icon_widget = self._widgets_by_name.ready_icon
	local active_text_widget = self._widgets_by_name.active_text
	local active_icon_widget = self._widgets_by_name.active_icon
	local cooldown_text_widget = self._widgets_by_name.cooldown_text
	local cooldown_icon_widget = self._widgets_by_name.cooldown_icon
	
	if link_all_positions then
		if not shared_icon_widget or not shared_text_widget then
			return
		end
	else
		if not ready_icon_widget or not active_text_widget or not active_icon_widget or not cooldown_text_widget or not cooldown_icon_widget then
			return
		end
	end

	local game_mode_manager = Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()
	local is_in_hub = not game_mode_name or game_mode_name == "hub" or game_mode_name == "prologue_hub"
	
	local function hide_all_widgets()
		if link_all_positions then
			if shared_icon_widget then shared_icon_widget.content.visible = false end
			if shared_text_widget then shared_text_widget.content.visible = false end
			if ready_icon_widget then ready_icon_widget.content.visible = false end
			if active_icon_widget then active_icon_widget.content.visible = false end
			if active_text_widget then active_text_widget.content.visible = false end
			if cooldown_icon_widget then cooldown_icon_widget.content.visible = false end
			if cooldown_text_widget then cooldown_text_widget.content.visible = false end
		else
			if shared_icon_widget then shared_icon_widget.content.visible = false end
			if shared_text_widget then shared_text_widget.content.visible = false end
			if ready_icon_widget then ready_icon_widget.content.visible = false end
			if active_icon_widget then active_icon_widget.content.visible = false end
			if active_text_widget then active_text_widget.content.visible = false end
			if cooldown_icon_widget then cooldown_icon_widget.content.visible = false end
			if cooldown_text_widget then cooldown_text_widget.content.visible = false end
		end
	end
	
	if is_in_hub then
		hide_all_widgets()
		return
	end

	local player = Managers.player:local_player(1)
	if not player then
		hide_all_widgets()
		return
	end

	local player_unit = player.player_unit
	if not player_unit or not ALIVE[player_unit] then
		hide_all_widgets()
		return
	end

	local buff_extension = ScriptUnit.has_extension(player_unit, "buff_system")
	local ability_extension = ScriptUnit.has_extension(player_unit, "ability_system")
	
	if not buff_extension or not ability_extension then
		hide_all_widgets()
		return
	end

	local archetype_name = player:archetype_name()
	if archetype_name ~= "broker" then
		hide_all_widgets()
		return
	end

	local equipped_abilities = ability_extension:equipped_abilities()
	local pocketable_ability = equipped_abilities and equipped_abilities[STIMM_ABILITY_TYPE]
	if not pocketable_ability or pocketable_ability.ability_group ~= "broker_syringe" then
		hide_all_widgets()
		return
	end

	local show_decimals = mod:get("show_decimals") ~= false
	local ready_show_icon = mod:get("ready_show_icon") ~= false
	local active_show_icon = mod:get("active_show_icon") ~= false
	local active_show_timer = mod:get("active_show_timer") ~= false
	local cooldown_show_icon = mod:get("cooldown_show_icon") ~= false
	local cooldown_show_timer = mod:get("cooldown_show_timer") ~= false

	local remaining_buff_time = self:_get_buff_remaining_time(buff_extension, STIMM_BUFF_NAME)
	local remaining_cooldown = ability_extension:remaining_ability_cooldown(STIMM_ABILITY_TYPE)

	local has_active_buff = remaining_buff_time and remaining_buff_time >= 0.05
	local has_cooldown = remaining_cooldown and remaining_cooldown >= 0.05
	local is_ready = not has_active_buff and not has_cooldown

	if link_all_positions then
		ready_icon_widget.content.visible = false
		active_icon_widget.content.visible = false
		active_text_widget.content.visible = false
		cooldown_icon_widget.content.visible = false
		cooldown_text_widget.content.visible = false
		
		if is_ready then
			local ready_color = mod.get_stage_color("ready")
			
			if ready_show_icon and not is_custom_hud_shared_icon_hidden then
				shared_icon_widget.content.visible = true
				shared_icon_widget.content.icon = STIMM_ICON_MATERIAL
				shared_icon_widget.style.icon.color[1] = ready_color[1]
				shared_icon_widget.style.icon.color[2] = ready_color[2]
				shared_icon_widget.style.icon.color[3] = ready_color[3]
				shared_icon_widget.style.icon.color[4] = ready_color[4]
				shared_icon_widget.dirty = true
			else
				shared_icon_widget.content.visible = false
			end
			
			shared_text_widget.content.visible = false
		elseif has_active_buff then
			local active_color = mod.get_stage_color("active")
			local display_text = ""
			if show_decimals then
				display_text = string.format("%.1f", remaining_buff_time)
			else
				display_text = string.format("%.0f", math.ceil(remaining_buff_time))
			end
			
			if active_show_icon and not is_custom_hud_shared_icon_hidden then
				shared_icon_widget.content.visible = true
				shared_icon_widget.content.icon = STIMM_ICON_MATERIAL
				shared_icon_widget.style.icon.color[1] = active_color[1]
				shared_icon_widget.style.icon.color[2] = active_color[2]
				shared_icon_widget.style.icon.color[3] = active_color[3]
				shared_icon_widget.style.icon.color[4] = active_color[4]
				shared_icon_widget.dirty = true
			else
				shared_icon_widget.content.visible = false
			end
			
			if active_show_timer and not is_custom_hud_shared_text_hidden then
				shared_text_widget.content.text = display_text
				shared_text_widget.content.visible = true
				shared_text_widget.style.text.text_color[1] = active_color[1]
				shared_text_widget.style.text.text_color[2] = active_color[2]
				shared_text_widget.style.text.text_color[3] = active_color[3]
				shared_text_widget.style.text.text_color[4] = active_color[4]
				shared_text_widget.dirty = true
			else
				shared_text_widget.content.visible = false
			end
		elseif has_cooldown then
			local cooldown_color = mod.get_stage_color("cooldown")
			local display_text = ""
			if show_decimals then
				display_text = string.format("%.1f", remaining_cooldown)
			else
				display_text = string.format("%.0f", math.ceil(remaining_cooldown))
			end
			
			if cooldown_show_icon and not is_custom_hud_shared_icon_hidden then
				shared_icon_widget.content.visible = true
				shared_icon_widget.content.icon = STIMM_ICON_MATERIAL
				shared_icon_widget.style.icon.color[1] = cooldown_color[1]
				shared_icon_widget.style.icon.color[2] = cooldown_color[2]
				shared_icon_widget.style.icon.color[3] = cooldown_color[3]
				shared_icon_widget.style.icon.color[4] = cooldown_color[4]
				shared_icon_widget.dirty = true
			else
				shared_icon_widget.content.visible = false
			end
			
			if cooldown_show_timer and not is_custom_hud_shared_text_hidden then
				shared_text_widget.content.text = display_text
				shared_text_widget.content.visible = true
				shared_text_widget.style.text.text_color[1] = cooldown_color[1]
				shared_text_widget.style.text.text_color[2] = cooldown_color[2]
				shared_text_widget.style.text.text_color[3] = cooldown_color[3]
				shared_text_widget.style.text.text_color[4] = cooldown_color[4]
				shared_text_widget.dirty = true
			else
				shared_text_widget.content.visible = false
			end
		else
			shared_icon_widget.content.visible = false
			shared_text_widget.content.visible = false
		end
	else
		shared_icon_widget.content.visible = false
		shared_text_widget.content.visible = false
		
		if is_ready then
			local ready_color = mod.get_stage_color("ready")
			
			if ready_show_icon and not is_custom_hud_ready_icon_hidden then
				ready_icon_widget.content.visible = true
				ready_icon_widget.content.icon = STIMM_ICON_MATERIAL
				ready_icon_widget.style.icon.color[1] = ready_color[1]
				ready_icon_widget.style.icon.color[2] = ready_color[2]
				ready_icon_widget.style.icon.color[3] = ready_color[3]
				ready_icon_widget.style.icon.color[4] = ready_color[4]
				ready_icon_widget.dirty = true
			else
				ready_icon_widget.content.visible = false
			end
			
			active_icon_widget.content.visible = false
			active_text_widget.content.visible = false
			cooldown_icon_widget.content.visible = false
			cooldown_text_widget.content.visible = false
		elseif has_active_buff then
			ready_icon_widget.content.visible = false
			
			local active_color = mod.get_stage_color("active")
			local display_text = ""
			if show_decimals then
				display_text = string.format("%.1f", remaining_buff_time)
			else
				display_text = string.format("%.0f", math.ceil(remaining_buff_time))
			end
			
			if active_show_icon and not is_custom_hud_active_icon_hidden then
				active_icon_widget.content.visible = true
				active_icon_widget.content.icon = STIMM_ICON_MATERIAL
				active_icon_widget.style.icon.color[1] = active_color[1]
				active_icon_widget.style.icon.color[2] = active_color[2]
				active_icon_widget.style.icon.color[3] = active_color[3]
				active_icon_widget.style.icon.color[4] = active_color[4]
				active_icon_widget.dirty = true
			else
				active_icon_widget.content.visible = false
			end
			
			if active_show_timer and not is_custom_hud_active_text_hidden then
				active_text_widget.content.text = display_text
				active_text_widget.content.visible = true
				active_text_widget.style.text.text_color[1] = active_color[1]
				active_text_widget.style.text.text_color[2] = active_color[2]
				active_text_widget.style.text.text_color[3] = active_color[3]
				active_text_widget.style.text.text_color[4] = active_color[4]
				active_text_widget.dirty = true
			else
				active_text_widget.content.visible = false
			end
			
			cooldown_icon_widget.content.visible = false
			cooldown_text_widget.content.visible = false
		elseif has_cooldown then
			ready_icon_widget.content.visible = false
			active_icon_widget.content.visible = false
			active_text_widget.content.visible = false
			
			local cooldown_color = mod.get_stage_color("cooldown")
			local display_text = ""
			if show_decimals then
				display_text = string.format("%.1f", remaining_cooldown)
			else
				display_text = string.format("%.0f", math.ceil(remaining_cooldown))
			end
			
			if cooldown_show_icon and not is_custom_hud_cooldown_icon_hidden then
				cooldown_icon_widget.content.visible = true
				cooldown_icon_widget.content.icon = STIMM_ICON_MATERIAL
				cooldown_icon_widget.style.icon.color[1] = cooldown_color[1]
				cooldown_icon_widget.style.icon.color[2] = cooldown_color[2]
				cooldown_icon_widget.style.icon.color[3] = cooldown_color[3]
				cooldown_icon_widget.style.icon.color[4] = cooldown_color[4]
				cooldown_icon_widget.dirty = true
			else
				cooldown_icon_widget.content.visible = false
			end
			
			if cooldown_show_timer and not is_custom_hud_cooldown_text_hidden then
				cooldown_text_widget.content.text = display_text
				cooldown_text_widget.content.visible = true
				cooldown_text_widget.style.text.text_color[1] = cooldown_color[1]
				cooldown_text_widget.style.text.text_color[2] = cooldown_color[2]
				cooldown_text_widget.style.text.text_color[3] = cooldown_color[3]
				cooldown_text_widget.style.text.text_color[4] = cooldown_color[4]
				cooldown_text_widget.dirty = true
			else
				cooldown_text_widget.content.visible = false
			end
		else
			ready_icon_widget.content.visible = false
			active_icon_widget.content.visible = false
			active_text_widget.content.visible = false
			cooldown_icon_widget.content.visible = false
			cooldown_text_widget.content.visible = false
		end
	end
end

HudElementBrokerStimTimer._get_buff_remaining_time = function(self, buff_extension, buff_template_name)
	if not buff_extension then
		return 0
	end

	local buffs_by_index = buff_extension._buffs_by_index
	if not buffs_by_index then
		return 0
	end

	local timer = 0
	for _, buff in pairs(buffs_by_index) do
		local template = buff:template()
		if template and template.name == buff_template_name then
			local remaining = buff:duration_progress() or 1
			local duration = buff:duration() or 15
			timer = math.max(timer, duration * remaining)
		end
	end

	return timer
end

HudElementBrokerStimTimer.draw = function(self, dt, t, ui_renderer, render_settings, input_service)
	HudElementBrokerStimTimer.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

HudElementBrokerStimTimer.destroy = function(self, ui_renderer)
	HudElementBrokerStimTimer.super.destroy(self, ui_renderer)
end

return HudElementBrokerStimTimer

