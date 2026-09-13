-- weapon_counter_timed_mode.lua
--
-- Relic-Blade-style HUD feedback for a fixed-duration weapon mode. The bar
-- fills while the special is active, then drains during its cooldown. This is
-- presentation only: num_special_charges remains the authority for whether
-- the special may be activated.

local PlayerCharacterConstants = require(
	"scripts/settings/player_character/player_character_constants")
local BuffSettings = require("scripts/settings/buff/buff_settings")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local stat_buff_types = BuffSettings.stat_buffs

local M = {}

local _mod
local _hooks
local _heavy

local HUD_ELEMENT_PATH =
	"scripts/ui/hud/elements/weapon_counter/hud_element_weapon_counter"
local COUNTER_TYPE = "pilgrimage_timed_mode"
local slot_configuration = PlayerCharacterConstants.slot_configuration

local length = 200
local thickness = 200
local size = {
	length,
	thickness,
}
local center_size = {
	4,
	4,
}

local function clamp01(value)
	return math.max(0, math.min(value, 1))
end

local function effective_active_duration(tweak_data, buff_extension)
	local duration = tonumber(tweak_data.active_duration) or 0
	local seconds_per_extra =
		tonumber(tweak_data.active_duration_per_extra_activation) or 0
	if seconds_per_extra == 0 or not buff_extension then return duration end

	local stat_buffs = buff_extension:stat_buffs()
	local extra = tonumber(stat_buffs
		and stat_buffs[stat_buff_types.weapon_special_max_activations]) or 0
	return duration + math.max(extra, 0) * seconds_per_extra
end

-- Kept public for the focused timing harness. Ready always renders empty.
-- During use the value rises from zero to one; during cooldown it falls from
-- one to zero, with no discontinuity at the phase boundary.
local function phase_at(t, start_t, active_duration, cooldown, ready)
	if ready then return "ready", 0 end

	start_t = tonumber(start_t) or t
	active_duration = math.max(tonumber(active_duration) or 0, 0)
	cooldown = math.max(tonumber(cooldown) or 0, 0)

	local active_end_t = start_t + active_duration
	if active_duration > 0 and t < active_end_t then
		return "active", clamp01((t - start_t) / active_duration)
	end

	local cooldown_end_t = active_end_t + cooldown
	if cooldown > 0 and t < cooldown_end_t then
		return "cooldown", clamp01((cooldown_end_t - t) / cooldown)
	end

	return "ready", 0
end

local template = {
	data = {},
	name = COUNTER_TYPE,
	size = size,
	center_size = center_size,
}

local function current_status(hud_element_weapon_counter, widget, t)
	-- HUD t comes from UIManager's main-derived timer. Weapon activation uses
	-- fixed simulation time; comparing these clocks skips the entire cycle.
	local extension_manager = Managers and Managers.state and Managers.state.extension
	if not extension_manager or not extension_manager.latest_fixed_t then return nil end
	t = extension_manager:latest_fixed_t()
	if type(t) ~= "number" then return nil end
	local parent = hud_element_weapon_counter._parent
	local player_extensions = parent and parent:player_extensions()
	if not player_extensions then return nil end

	local unit_data_extension = player_extensions.unit_data
	local visual_loadout_extension = player_extensions.visual_loadout
	local buff_extension = player_extensions.buff
	if not unit_data_extension or not visual_loadout_extension then return nil end

	local inventory_component = unit_data_extension:read_component("inventory")
	local wielded_slot = inventory_component and inventory_component.wielded_slot
	if not wielded_slot or wielded_slot == "none" then return nil end
	local slot = slot_configuration[wielded_slot]
	if not slot or slot.slot_type ~= "weapon" then return nil end

	local slot_name = widget.content.pilgrimage_slot_name
	if not slot_name then return nil end
	local component = unit_data_extension:read_component(slot_name)
	local weapon_template =
		visual_loadout_extension:weapon_template_from_slot(slot_name)
	local tweak_data = weapon_template
		and weapon_template.weapon_special_tweak_data
	if not component or not tweak_data then return nil end

	-- The HUD-side component can continue reporting a full discrete charge
	-- while the authoritative weapon-special implementation is active or
	-- cooling down. Do not let that stale presentation value erase the timed
	-- phase. The native special start timestamp plus the two configured
	-- durations are sufficient to determine when the bar is genuinely ready.
	local start_t = tonumber(component.special_active_start_t) or 0
	local cycle_started = component.special_active == true or start_t > 0
	local phase, progress = phase_at(t,
		start_t,
		effective_active_duration(tweak_data, buff_extension),
		tweak_data.cooldown,
		not cycle_started)
	-- A chain latch may legitimately overrun the nominal active window. Keep
	-- the bar full and active until the saw releases; the special class then
	-- rebases the timestamp so a complete cooldown drains from that moment.
	if component.special_active and phase ~= "active" then
		phase = "active"
		progress = 1
	end

	return phase, progress, component.special_active == true
end

template.create_widget_defintion = function (scenegraph_id)
	local center_half_width = center_size[1] * 0.5
	local charge_bar_offset = 100
	local charge_bar_offset_right = {
		charge_bar_offset + center_half_width,
		35,
		1,
	}

	return UIWidget.create_definition({
		{
			pass_type = "texture",
			style_id = "charge_bar",
			value = "content/ui/materials/effects/powersword_bar",
			style = {
				horizontal_alignment = "center",
				vertical_alignment = "center",
				offset = charge_bar_offset_right,
				size = {
					size[1],
					size[2],
				},
				color = UIHudSettings.color_tint_main_1,
				material_values = {
					active = 0,
					color_blend = 0,
					fill_opacity = 1,
					lockout = 0,
					outline_opacity = 1,
					progress = 0,
				},
			},
		},
	}, scenegraph_id)
end

template.on_enter = function (hud_element_weapon_counter, slot_name, widget)
	-- Store this on the widget rather than the shared template. That keeps two
	-- weapon slots using the same counter type from overwriting one another.
	widget.content.pilgrimage_slot_name = slot_name
end

template.update_function = function (hud_element_weapon_counter, ui_renderer,
		widget, is_currently_wielded, weapon_counter_settings,
		counter_template, dt, t)
	local phase, progress, special_active =
		current_status(hud_element_weapon_counter, widget, t)
	local visible = phase ~= nil and (is_currently_wielded
		or weapon_counter_settings.show_when_unwielded
			and not is_currently_wielded)

	widget.visible = visible
	if not visible then return end

	local cooling = phase == "cooldown"
	local material_values = widget.style.charge_bar.material_values
	material_values.progress = math.lerp(0.028, 0.252, progress)
	material_values.active = special_active and 1 or 0
	material_values.color_blend = math.lerp(0, 1,
		cooling and 1 or math.easeInCubic(progress) + 0.1)
	material_values.fill_opacity = special_active and 0.75 or 0.4
	material_values.outline_opacity = special_active and 2 or 1
	material_values.lockout = cooling and 1 or 0
end

function M.install(HudElementWeaponCounter)
	if not _mod or type(HudElementWeaponCounter) ~= "table"
		or type(HudElementWeaponCounter.init) ~= "function" then
		return false
	end
	if _hooks and _hooks.claim
		and _hooks.claim(HudElementWeaponCounter,
			"__pilgrimage_timed_mode_counter") then
		return false
	end

	_mod:hook(HudElementWeaponCounter, "init",
		function (func, self, parent, draw_layer, start_scale, data)
			func(self, parent, draw_layer, start_scale, data)
			if not self._weapon_counter_templates
				or not self._weapon_counter_widget_definitions then
				return
			end
			self._weapon_counter_templates[COUNTER_TYPE] =
				table.clone(template)
			self._weapon_counter_widget_definitions[COUNTER_TYPE] =
				template.create_widget_defintion("pivot")
			if _heavy then _heavy.attach_counter(self) end
		end)

	return true
end

function M.init(deps)
	_mod = deps.mod
	_hooks = deps.hooks
	_heavy = deps.heavy
end

M.HUD_ELEMENT_PATH = HUD_ELEMENT_PATH
M.COUNTER_TYPE = COUNTER_TYPE
M.phase_at = phase_at
M.effective_active_duration = effective_active_duration

return M
