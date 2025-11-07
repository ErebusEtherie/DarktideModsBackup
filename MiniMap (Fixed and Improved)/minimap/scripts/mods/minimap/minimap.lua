local mod = get_mod("minimap")

mod.settings = {}
mod.settings.screen_alignment = {}
mod.settings.icon_vis = {}

local hud_elements = {
    {
        filename = "minimap/scripts/mods/minimap/hud_element_minimap/hud_element_minimap",
        class_name = "HudElementMinimap",
    },
}

for _, hud_element in ipairs(hud_elements) do
    mod:add_require_path(hud_element.filename)
end

-- Taken from raindish
mod:hook("UIHud", "init", function(func, self, elements, visibility_groups, params)
    for _, hud_element in ipairs(hud_elements) do
        if not table.find_by_key(elements, "class_name", hud_element.class_name) then
            table.insert(elements, {
                class_name = hud_element.class_name,
                filename = hud_element.filename,
                use_hud_scale = true,
                visibility_groups = {
                    "alive",
                    "communication_wheel"
                },
            })
        end
    end

    return func(self, elements, visibility_groups, params)
end)

---@param elements any[]
---@return HudElementMinimap?
local function get_hud_minimap_element(elements)
	if not elements or table.is_empty(elements) then return nil end

	return elements[hud_elements[1].class_name]
end

local function update_minimap_style_settings(hud)
	if not hud or not hud._elements then return end

	local minimap = get_hud_minimap_element(hud._elements)
	if minimap then
		minimap:set_scenegraph_position("minimap", mod:get("minimap_offset_x"), mod:get("minimap_offset_y"), 0, mod:get("minimap_horizontal_alignment"), mod:get("minimap_vertical_alignment"))
	end
end

-- Taken from Fracticality
local function recreate_hud()
    local ui_manager = Managers.ui
    if ui_manager then
        local hud = ui_manager._hud
        if hud then
            local player_manager = Managers.player
            local player = player_manager:local_player(1)
            local peer_id = player:peer_id()
            local local_player_id = player:local_player_id()
            local elements = hud._element_definitions
            local visibility_groups = hud._visibility_groups

            hud:destroy()
            ui_manager:create_player_hud(peer_id, local_player_id, elements, visibility_groups)

            update_minimap_style_settings(ui_manager._hud)
        end
    end
end

local function collect_settings()
    mod.settings["display_class_icon"] = mod:get("display_class_icon")

    mod.settings.icon_vis["location_attention"] = mod:get("location_attention_vis")
    mod.settings.icon_vis["location_ping"] = mod:get("location_ping_vis")
    mod.settings.icon_vis["location_threat"] = mod:get("location_threat_vis")
    mod.settings.icon_vis["unit_threat"] = mod:get("unit_threat_vis")
    mod.settings.icon_vis["nameplate"] = mod:get("player_vis")
    mod.settings.icon_vis["nameplate_party"] = mod:get("player_vis")
    mod.settings.icon_vis["nameplate_party_hud"] = mod:get("player_vis")
    mod.settings.icon_vis["nameplate_combat"] = mod:get("player_vis")
    mod.settings.icon_vis["nameplate_companion"] = mod:get("player_vis")
    mod.settings.icon_vis["nameplate_companion_hub"] = mod:get("player_vis")
    mod.settings.icon_vis["ringhud_teammate_tile"] = mod:get("player_vis")  -- RingHud compatibility
    mod.settings.icon_vis["objective"] = mod:get("objective_vis")
    mod.settings.icon_vis["player_assistance"] = mod:get("assistance_vis")
    mod.settings.icon_vis["damage_indicator"] = mod:get("damaged_enemy_vis")
    mod.settings.icon_vis["interaction"] = mod:get("tagged_interaction_vis")
end

mod.on_all_mods_loaded = function()
    collect_settings()
    recreate_hud()
end

mod.on_setting_changed = function()
    collect_settings()
    recreate_hud()
end
