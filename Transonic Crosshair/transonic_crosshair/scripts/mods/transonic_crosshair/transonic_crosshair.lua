local mod = get_mod("transonic_crosshair")

-- Transonic Blades reticle per mode:
--   slashing   (special off) -> horizontal bar
--   anti-elite (special on)  -> vertical bar

local UIWidget = require("scripts/managers/ui/ui_widget")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local Crosshair = require("scripts/ui/utilities/crosshair")
local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")
local slot_configuration = PlayerCharacterConstants.slot_configuration

local SLASH_TYPE = "transonic_slash"
local ELITE_TYPE = "transonic_elite"

local TARGET_TEMPLATES = {
	-- Transonic Blades (sword + knife). Add other transonic template paths here to include them.
	"scripts/settings/equipment/weapon_templates/transonic_sword_transonic_knife/transonic_sword_transonic_knife_p1_m1",
}

local BAR_MATERIAL = "content/ui/materials/hud/crosshairs/long_spread"
local SCENEGRAPH_ID = "pivot"
local DEFAULTS = { bar_length = 26, bar_thickness = 3, swap_modes = false }

local cfg = {}

local function refresh_cfg()
	cfg.bar_length = mod:get("bar_length") or DEFAULTS.bar_length
	cfg.bar_thickness = mod:get("bar_thickness") or DEFAULTS.bar_thickness

	local swap = mod:get("swap_modes")
	cfg.swap_modes = swap == nil and DEFAULTS.swap_modes or swap
end

refresh_cfg()

local function bar_segment(angle)
	return {
		pass_type = "rotated_texture",
		value = BAR_MATERIAL,
		style_id = "bar",
		style = {
			horizontal_alignment = "center",
			vertical_alignment = "center",
			angle = angle,
			offset = { 0, 0, 1 },
			size = { cfg.bar_length, cfg.bar_thickness },
			color = table.clone(UIHudSettings.color_tint_main_1),
		},
	}
end

local function build_template(name, angle)
	local template = { name = name }

	-- "defintion" matches the engine's (misspelled) call site -- do not correct.
	template.create_widget_defintion = function(_, scenegraph_id)
		return UIWidget.create_definition({
			bar_segment(angle),
			Crosshair.hit_indicator_segment("top_left"),
			Crosshair.hit_indicator_segment("bottom_left"),
			Crosshair.hit_indicator_segment("top_right"),
			Crosshair.hit_indicator_segment("bottom_right"),
			Crosshair.weakspot_hit_indicator_segment("top_left"),
			Crosshair.weakspot_hit_indicator_segment("bottom_left"),
			Crosshair.weakspot_hit_indicator_segment("top_right"),
			Crosshair.weakspot_hit_indicator_segment("bottom_right"),
		}, scenegraph_id)
	end

	template.update_function = function(parent, ui_renderer, widget, template, crosshair_settings, dt, t, draw_hit_indicator)
		local bar = widget.style.bar

		if bar then
			bar.size[1] = cfg.bar_length
			bar.size[2] = cfg.bar_thickness
		end

		local hit_progress, hit_color, hit_weakspot = parent:hit_indicator()

		Crosshair.update_hit_indicator(widget.style, hit_progress, hit_color, hit_weakspot, draw_hit_indicator)
	end

	return template
end

local TEMPLATES = {
	[SLASH_TYPE] = build_template(SLASH_TYPE, 0),
	[ELITE_TYPE] = build_template(ELITE_TYPE, math.rad(90)),
}

mod:hook_safe("HudElementCrosshair", "init", function(self)
	local templates = self._crosshair_templates
	local definitions = self._crosshair_widget_definitions

	if not templates or not definitions then
		return
	end

	for name, template in pairs(TEMPLATES) do
		if not templates[name] then
			templates[name] = template
			definitions[name] = template.create_widget_defintion(template, SCENEGRAPH_ID)
		end
	end
end)

local function mode_crosshair_type(special_active)
	local slash, elite = SLASH_TYPE, ELITE_TYPE
	if cfg.swap_modes then
		slash, elite = elite, slash
	end
	return special_active and elite or slash
end

-- Default path (no crosshair-replacing mod): hand vanilla a crosshair_type_func on the
-- Transonic Blades template. Vanilla's _get_current_crosshair_type calls it for this
-- weapon only and is left completely untouched for every other weapon -- this is the
-- 1.0.0 behaviour, which never affected the ranged crosshair or anything else.
local function crosshair_type_func(condition_func_params)
	if not mod:is_enabled() then
		return nil
	end

	local slot = condition_func_params and condition_func_params.inventory_slot_component
	return mode_crosshair_type(slot and slot.special_active)
end

for _, path in ipairs(TARGET_TEMPLATES) do
	mod:hook_require(path, function(weapon_template)
		if weapon_template and weapon_template.crosshair then
			weapon_template.crosshair.crosshair_type_func = crosshair_type_func
		end
	end)
end

-- A wielded weapon reports its template file's basename as `template_name`, e.g.
-- "transonic_sword_transonic_knife_p1_m1" -- the basename of each target path. Used
-- only by the selector bridge below.
local target_template_names = {}

for _, path in ipairs(TARGET_TEMPLATES) do
	target_template_names[string.match(path, "[^/]+$")] = true
end

-- Bridge for selector-replacing mods (Crosshair Remap et al.): they replace
-- _get_current_crosshair_type wholesale via hook_origin and ignore crosshair_type_func,
-- so our bars would be lost under them. ONLY when such a mod is active do we wrap the
-- selector -- returning our type for the Transonic Blades and deferring every other
-- weapon straight back to that mod. On a vanilla setup this is never installed, so the
-- stock crosshair path stays byte-for-byte identical to 1.0.0.
local REMAP_MODS = { "crosshair_remap" }

local selector_bridge_installed = false

local function install_selector_bridge()
	if selector_bridge_installed then
		return
	end

	local active = false
	for _, name in ipairs(REMAP_MODS) do
		local other = get_mod(name)
		if other and other:is_enabled() then
			active = true
			break
		end
	end

	if not active then
		return
	end

	selector_bridge_installed = true

	mod:hook("HudElementCrosshair", "_get_current_crosshair_type", function(func, self)
		if mod:is_enabled() then
			local parent = self._parent
			local player_extensions = parent and parent:player_extensions()
			local unit_data = player_extensions and player_extensions.unit_data
			local weapon_action = unit_data and unit_data:read_component("weapon_action")

			if weapon_action and target_template_names[weapon_action.template_name] then
				local inventory = unit_data:read_component("inventory")
				local wielded_slot = inventory and inventory.wielded_slot
				local slot
				if wielded_slot and slot_configuration[wielded_slot]
					and slot_configuration[wielded_slot].slot_type == "weapon" then
					slot = unit_data:read_component(wielded_slot)
				end

				return mode_crosshair_type(slot and slot.special_active)
			end
		end

		return func(self)
	end)
end

mod.on_all_mods_loaded = function()
	refresh_cfg()
	install_selector_bridge()
end

function mod.on_setting_changed()
	refresh_cfg()
end
