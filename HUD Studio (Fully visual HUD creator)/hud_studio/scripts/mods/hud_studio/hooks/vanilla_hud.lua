---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_vanilla_hud then
	return mod.hud_studio_vanilla_hud
end

local Session = mod:core(mod.hud_studio_session, "document/session")

---@param id string
---@return boolean
local function is_hidden(id)
	if not mod:is_enabled() then
		return false
	end
	local vanilla = Session.canvas().vanilla
	return vanilla and vanilla[id] == false or false
end

---@type table<table, boolean>
local retained_cleared = setmetatable({}, { __mode = "k" })

---@param class_name string
---@param hidden_for fun(self: table): boolean
local function wrap_draw(class_name, hidden_for)
	mod.dl.game_hooks.hook(class_name, "draw", function(next, self, dt, t, ui_renderer, render_settings, input_service)
		if hidden_for(self) then
			if not retained_cleared[self] and self.set_visible then
				self:set_visible(false, ui_renderer, render_settings and render_settings.force_retained_mode)
				retained_cleared[self] = true
			end
			return
		end

		if retained_cleared[self] then
			if self.set_visible then
				self:set_visible(true, ui_renderer, render_settings and render_settings.force_retained_mode)
			end
			retained_cleared[self] = nil
		end

		return next(self, dt, t, ui_renderer, render_settings, input_service)
	end)
end

local ELEMENT_CLASSES = {
	dodge_stamina = { "HudElementStamina", "HudElementDodgeCounter" },
	peril = { "HudElementOvercharge" },
	ability = { "HudElementPlayerAbilityHandler" },
	equipment = { "HudElementPlayerWeaponHandler" },
}

for id, class_names in pairs(ELEMENT_CLASSES) do
	for i = 1, #class_names do
		local toggle_id = id
		wrap_draw(class_names[i], function()
			return is_hidden(toggle_id)
		end)
	end
end

local PANEL_SLOT_ID = {
	local_player = "player_1",
	player_1 = "player_2",
	player_2 = "player_3",
	player_3 = "player_4",
}

local PANEL_CLASSES = {
	"HudElementPersonalPlayerPanel",
	"HudElementTeamPlayerPanel",
	"HudElementPersonalPlayerPanelHub",
	"HudElementTeamPlayerPanelHub",
}

---@param panel table
---@return boolean
local function panel_hidden(panel)
	local data = panel._data
	local scenegraph_id = data and data.scenegraph_id
	local id = scenegraph_id and PANEL_SLOT_ID[scenegraph_id]
	return id ~= nil and is_hidden(id)
end

for i = 1, #PANEL_CLASSES do
	wrap_draw(PANEL_CLASSES[i], panel_hidden)
end

local function _hide_weapon_counter_widget(slot_widgets, slot_name)
	local widget = slot_widgets[slot_name]
	if widget then
		widget.visible = false
	end
end

mod.dl.game_hooks.hook("HudElementWeaponCounter", "_draw_widgets", function(next, self, ...)
	if is_hidden("weapon_heat") or is_hidden("force_greatsword_charge") or is_hidden("weapon_special_charges") then
		local counter_types = self._slot_weapon_counter_type
		local slot_widgets = self._slot_widgets
		if counter_types and slot_widgets then
			for slot_name, counter_type in pairs(counter_types) do
				if is_hidden("force_greatsword_charge") and counter_type == "kill_charges" then
					_hide_weapon_counter_widget(slot_widgets, slot_name)
				end
				if is_hidden("weapon_heat") and counter_type == "overheat_lockout" then
					_hide_weapon_counter_widget(slot_widgets, slot_name)
				end
				if is_hidden("weapon_special_charges") and counter_type == "cooldown_charges" then
					_hide_weapon_counter_widget(slot_widgets, slot_name)
				end
			end
		end
	end

	return next(self, ...)
end)

mod.dl.game_hooks.hook("HudElementCrosshair", "_get_current_crosshair_type", function(next, self, ...)
	local crosshair_type = next(self, ...)

	if (crosshair_type == "charge_up" or crosshair_type == "charge_up_ads") and is_hidden("weapon_charge_up") then
		return "none"
	end

	return crosshair_type
end)

local BUFFS_CLASS = "HudElementPlayerBuffs"
local BUFFS_DEFINITIONS = "scripts/ui/hud/elements/player_buffs/hud_element_player_buffs_definitions"
local BUFFS_SCENEGRAPH_ID = "background"

---@return number x, number y
local function buffs_offset()
	if not mod:is_enabled() then
		return 0, 0
	end
	local offset = Session.canvas().buffs_offset
	if not offset then
		return 0, 0
	end
	return offset[1] or 0, offset[2] or 0
end

---@type number[]?
local buffs_base_position

---@return number[]?
local function base_position()
	if buffs_base_position then
		return buffs_base_position
	end
	local ok, definitions = pcall(require, BUFFS_DEFINITIONS)
	local scenegraph = ok and definitions and definitions.scenegraph_definition
	local node = scenegraph and scenegraph[BUFFS_SCENEGRAPH_ID]
	local position = node and node.position
	if not position then
		return nil
	end
	buffs_base_position = { position[1], position[2] }
	return buffs_base_position
end

---@type table<table, number[]>
local buffs_applied_offset = setmetatable({}, { __mode = "k" })

mod.dl.game_hooks.hook(BUFFS_CLASS, "update", function(next, self, ...)
	local base = base_position()
	if not base then
		return next(self, ...)
	end

	local offset_x, offset_y = buffs_offset()
	local applied = buffs_applied_offset[self]
	if not applied or applied[1] ~= offset_x or applied[2] ~= offset_y then
		self:set_scenegraph_position(BUFFS_SCENEGRAPH_ID, base[1] + offset_x, base[2] + offset_y)
		buffs_applied_offset[self] = { offset_x, offset_y }
	end

	return next(self, ...)
end)

---@class VanillaHud
local VanillaHud = {}

mod.hud_studio_vanilla_hud = VanillaHud

return VanillaHud
