local mod = get_mod("BrokerStimTimer")

local packages_to_load = {
	"packages/ui/hud/player_buffs/player_buffs",
	"packages/ui/hud/player_weapon/player_weapon",
}

local STIMM_ICON_MATERIAL = "content/ui/materials/icons/pocketables/hud/syringe_broker"
local _package_id = nil



local function get_stage_color(stage)
	local color = mod:get(stage .. "_color")
	if color then
		return {255, color[2] or 255, color[3] or 255, color[4] or 255}
	end
	return {255, 255, 255, 255}
end

mod.get_stage_color = get_stage_color

mod.on_enabled = function()
	for _, package_path in ipairs(packages_to_load) do
		Managers.package:load(package_path, mod:get_name(), nil, true)
	end

	local resource_package = Application.resource_package(STIMM_ICON_MATERIAL)
	if resource_package then
		_package_id = Managers.package:load(STIMM_ICON_MATERIAL, mod:get_name(), nil, true)
	end

	mod:register_hud_element({
		class_name = "HudElementBrokerStimTimer",
		filename = "BrokerStimTimer/scripts/mods/BrokerStimTimer/hud/HudElementBrokerStimTimer",
		visibility_groups = {
			"alive"
		},
		use_hud_scale = false,
	})
end

mod.on_disabled = function()
	if _package_id then
		Managers.package:release(_package_id)
		_package_id = nil
	end
	mod:remove_require_path("BrokerStimTimer/scripts/mods/BrokerStimTimer/HudElementBrokerStimTimer")
end

