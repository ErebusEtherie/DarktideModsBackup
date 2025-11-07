local mod = get_mod("outline_colours")

local OutlineSettings = require("scripts/settings/outline/outline_settings")

local get_colour_array = function(name)
	local r = tonumber(mod:get(name.."_r"))
	local g = tonumber(mod:get(name.."_g"))
	local b = tonumber(mod:get(name.."_b"))

	return {r,g,b}
end

mod.update_colours_in_settings = function(self, instance)
	-- colours
	instance.MinionOutlineExtension.special_target.color = get_colour_array("special_target")
	instance.MinionOutlineExtension.smart_tagged_enemy.color = get_colour_array("smart_tagged_enemy")
	instance.MinionOutlineExtension.smart_tagged_enemy_passive.color = get_colour_array("smart_tagged_enemy_passive")
	instance.MinionOutlineExtension.veteran_smart_tag.color = get_colour_array("veteran_smart_tag")
	--instance.MinionOutlineExtension.psyker_marked_target.color = get_colour_array("psyker_marked_target")

	instance.PlayerUnitOutlineExtension.default_both_always.color = get_colour_array("player_outline")
	instance.PlayerUnitOutlineExtension.default_outlines_always.color = get_colour_array("player_outline")
	instance.PlayerUnitOutlineExtension.default_mesh_always.color = get_colour_array("player_outline")

	instance.PlayerUnitOutlineExtension.knocked_down.color = get_colour_array("player_outline_downed")

	-- priorities
	instance.MinionOutlineExtension.special_target.priority = mod:get("special_target_priority")
	instance.MinionOutlineExtension.smart_tagged_enemy.priority = mod:get("smart_tagged_enemy_priority")
	instance.MinionOutlineExtension.smart_tagged_enemy_passive.priority = mod:get("smart_tagged_enemy_passive_priority")
	instance.MinionOutlineExtension.veteran_smart_tag.priority = mod:get("veteran_smart_tag_priority")
	--instance.MinionOutlineExtension.psyker_marked_target.priority = mod:get("psyker_marked_target_priority")

	instance.PlayerUnitOutlineExtension.default_both_always.priority = mod:get("player_outline_priority")
	instance.PlayerUnitOutlineExtension.default_outlines_always.priority = mod:get("player_outline_priority")
	instance.PlayerUnitOutlineExtension.default_mesh_always.priority = mod:get("player_outline_priority")

	instance.PlayerUnitOutlineExtension.knocked_down.priority = mod:get("player_outline_downed_priority")
end

mod.on_setting_changed = function(setting_name)
	mod:update_colours_in_settings(OutlineSettings)
end

mod:hook_require("scripts/settings/outline/outline_settings", function(instance)
	mod:update_colours_in_settings(instance)
end)

mod:hook_safe(CLASS.OutlineSystem, "update", function (self, context, dt, t)

	if self._total_num_outlines == 0 then
		return
	end

	local visible = self._visible

	if not visible then
		return
	end

	for unit, extension in pairs(self._unit_extension_data) do
		local top_outline = extension.outlines[1]

		if top_outline then
			local colour = extension.settings[top_outline.name].color
			if colour then
				Unit.set_vector3_for_materials(unit, "outline_color", Vector3(colour[1], colour[2], colour[3]), true)
			end
		end
	end
end)
