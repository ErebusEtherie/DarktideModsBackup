local mod = get_mod("BrokerStimTimer")

local packages_to_load = {
	"packages/ui/hud/player_buffs/player_buffs",
	"packages/ui/hud/player_weapon/player_weapon",
}

local STIMM_ICON_MATERIAL = "content/ui/materials/icons/pocketables/hud/syringe_broker"
local _package_id = nil

local color_presets = {}
for _, name in ipairs(Color.list or {}) do
	local c = Color[name](255, true)
	color_presets[#color_presets+1] = { id = name, name = name, r = c[2], g = c[3], b = c[4] }
end
table.sort(color_presets, function(a,b) return a.name < b.name end)

local function preset_options()
	local opts = {}
	for i, p in ipairs(color_presets) do
		opts[#opts+1] = { text = p.name, value = p.id }
	end
	return opts
end

local function get_stage_color(stage)
	local r = mod:get(stage .. "_r") or 255
	local g = mod:get(stage .. "_g") or 255
	local b = mod:get(stage .. "_b") or 255
	return {255, r, g, b}
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
		filename = "BrokerStimTimer/scripts/mods/BrokerStimTimer/HudElementBrokerStimTimer",
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

local default_stage_colors = {
	active = {r = 226, g = 199, b = 126},
	cooldown = {r = 246, g = 69, b = 69},
	ready = {r = 74, g = 177, b = 85},
}

mod.on_setting_changed = function(id)
	if id:match("_preset$") then
		local stage = id:match("(.+)_preset$")
		if stage then
			local preset_id = mod:get(id)
			if preset_id == "default" then
				local defaults = default_stage_colors[stage]
				if defaults then
					mod:set(stage .. "_r", defaults.r)
					mod:set(stage .. "_g", defaults.g)
					mod:set(stage .. "_b", defaults.b)
				end
			elseif preset_id then
				for _, p in ipairs(color_presets) do
					if p.id == preset_id then
						mod:set(stage .. "_r", p.r)
						mod:set(stage .. "_g", p.g)
						mod:set(stage .. "_b", p.b)
						break
					end
				end
			end
		end
	end
end

