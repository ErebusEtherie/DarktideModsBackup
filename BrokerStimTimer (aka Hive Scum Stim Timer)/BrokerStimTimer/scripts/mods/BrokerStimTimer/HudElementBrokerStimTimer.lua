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
	-- Make text box size accurately match the text size for Custom HUD dragging
	-- Width: enough for "99.9" format (about 3-4 characters wide)
	-- Height: font size with minimal padding
	local text_width = font_size * 2.5
	local text_height = font_size * 1.2
	
	return {
		screen = {
			scale = "fit",
			size = { 1920, 1080 },
			position = { 0, 0, 0 }
		},
		timer_icon_root = {
			parent = "screen",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { icon_size, icon_size },
			position = { mod:get("icon_x"), mod:get("icon_y"), 100 }
		},
		timer_text_root = {
			parent = "screen",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { text_width, text_height },
			position = { mod:get("text_x"), mod:get("text_y"), 100 }
		}
	}
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
		timer_icon = UIWidget.create_definition({
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
		}, "timer_icon_root"),
		timer_text = UIWidget.create_definition({
			{
				visible = false,
				pass_type = "text",
				style_id = "text",
				value = "",
				value_id = "text",
				style = timer_text_style,
			},
		}, "timer_text_root")
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
	
	local icon_node_name = string.format("%s|timer_icon_root", element_name)
	local text_node_name = string.format("%s|timer_text_root", element_name)
	
	local has_custom_hud_icon_position = saved_node_settings[icon_node_name] ~= nil
	local has_custom_hud_text_position = saved_node_settings[text_node_name] ~= nil
	
	if not has_custom_hud_icon_position then
		self:set_scenegraph_position("timer_icon_root", mod:get("icon_x"), mod:get("icon_y"), 100)
	end
	
	if not has_custom_hud_text_position then
		self:set_scenegraph_position("timer_text_root", mod:get("text_x"), mod:get("text_y"), 100)
	end

	local text_widget = self._widgets_by_name.timer_text
	local icon_widget = self._widgets_by_name.timer_icon
	
	if not text_widget or not icon_widget then
		return
	end

	local game_mode_manager = Managers.state.game_mode
	local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()
	local is_in_hub = not game_mode_name or game_mode_name == "hub" or game_mode_name == "prologue_hub"
	
	if is_in_hub then
		text_widget.content.visible = false
		icon_widget.content.visible = false
		return
	end

	local player = Managers.player:local_player(1)
	if not player then
		text_widget.content.visible = false
		icon_widget.content.visible = false
		return
	end

	local player_unit = player.player_unit
	if not player_unit or not ALIVE[player_unit] then
		text_widget.content.visible = false
		icon_widget.content.visible = false
		return
	end

	local buff_extension = ScriptUnit.has_extension(player_unit, "buff_system")
	local ability_extension = ScriptUnit.has_extension(player_unit, "ability_system")
	
	if not buff_extension or not ability_extension then
		text_widget.content.visible = false
		icon_widget.content.visible = false
		return
	end

	local archetype_name = player:archetype_name()
	if archetype_name ~= "broker" then
		text_widget.content.visible = false
		icon_widget.content.visible = false
		return
	end

	local equipped_abilities = ability_extension:equipped_abilities()
	local pocketable_ability = equipped_abilities and equipped_abilities[STIMM_ABILITY_TYPE]
	if not pocketable_ability or pocketable_ability.ability_group ~= "broker_syringe" then
		text_widget.content.visible = false
		icon_widget.content.visible = false
		return
	end

	local display_text = ""
	local display_color = mod.get_stage_color("ready")
	local should_show_text = false
	local should_show_icon = false
	local show_decimals = mod:get("show_decimals") ~= false
	local show_when_ready = mod:get("show_when_ready") ~= false
	local show_icon_option = mod:get("show_icon") ~= false
	local show_timer_option = mod:get("show_timer") ~= false
	local show_active = mod:get("show_active") ~= false
	local show_cooldown = mod:get("show_cooldown") ~= false

	local remaining_buff_time = self:_get_buff_remaining_time(buff_extension, STIMM_BUFF_NAME)
	local remaining_cooldown = ability_extension:remaining_ability_cooldown(STIMM_ABILITY_TYPE)

	local has_active_buff = remaining_buff_time and remaining_buff_time >= 0.05
	local has_cooldown = remaining_cooldown and remaining_cooldown >= 0.05

	if has_active_buff and show_active then
		if show_decimals then
			display_text = string.format("%.1f", remaining_buff_time)
		else
			display_text = string.format("%.0f", math.ceil(remaining_buff_time))
		end
		display_color = mod.get_stage_color("active")
		should_show_text = true
		should_show_icon = true
	elseif has_cooldown and show_cooldown then
		if show_decimals then
			display_text = string.format("%.1f", remaining_cooldown)
		else
			display_text = string.format("%.0f", math.ceil(remaining_cooldown))
		end
		display_color = mod.get_stage_color("cooldown")
		should_show_text = true
		should_show_icon = true
	elseif not has_active_buff and not has_cooldown and show_when_ready then
		display_color = mod.get_stage_color("ready")
		should_show_icon = true
	end

	if show_icon_option then
		icon_widget.content.visible = should_show_icon
		icon_widget.content.icon = STIMM_ICON_MATERIAL
		if should_show_icon then
			icon_widget.style.icon.color[1] = display_color[1]
			icon_widget.style.icon.color[2] = display_color[2]
			icon_widget.style.icon.color[3] = display_color[3]
			icon_widget.style.icon.color[4] = display_color[4]
		end
		icon_widget.dirty = true
	else
		icon_widget.content.visible = false
	end

	if show_timer_option and should_show_text then
		text_widget.content.text = display_text
		text_widget.content.visible = true
		text_widget.style.text.text_color[1] = display_color[1]
		text_widget.style.text.text_color[2] = display_color[2]
		text_widget.style.text.text_color[3] = display_color[3]
		text_widget.style.text.text_color[4] = display_color[4]
		text_widget.dirty = true
	else
		text_widget.content.visible = false
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

