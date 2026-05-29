-- File: scripts/mods/BetterLoadouts/hooks/ui_manager_load_view.lua
local mod = get_mod("BetterLoadouts")
if not mod then
    return
end

local PRESET_HOST_VIEWS = {
    main_menu_view = true,
    inventory_view = true,
    item_inspection_view = true,
    crafting_view = true,
    masteries_overview_view = true,
    cosmetics_vendor_view = true,
}

local REQUIRED_PACKAGES = {
    "packages/ui/hud/player_weapon/player_weapon",
    "packages/ui/views/mission_board_view/mission_board_view",
    "packages/ui/views/cosmetics_vendor_view/cosmetics_vendor_view",
    "packages/ui/hud/interaction/interaction",
    "packages/ui/views/barber_vendor_background_view/barber_vendor_background_view",
    "packages/ui/views/training_grounds_options_view/training_grounds_options_view",
    "packages/ui/hud/world_markers/world_markers",
    "content/ui/materials/icons/throwables/hud/missile_launcher",
    "packages/ui/views/scanner_display_view/scanner_display_view",
    "packages/ui/views/expedition_play_view/expedition_play_view",
    "packages/ui/hud/mission_objective_feed/mission_objective_feed",
}

local function ensure_package_loaded(package_manager, package_name, reference_name)
    if package_manager:has_loaded(package_name) or package_manager:is_loading(package_name) then
        return
    end

    package_manager:load(package_name, reference_name, nil)
end

-- Preload icon packages when views that host the Presets element open.
mod:hook_safe("UIManager", "load_view", function(self, view_name, reference_name)
    if not PRESET_HOST_VIEWS[view_name] then
        return
    end

    local package_manager = Managers.package
    if not package_manager then
        return
    end

    local load_reference = reference_name or view_name

    for i = 1, #REQUIRED_PACKAGES do
        ensure_package_loaded(package_manager, REQUIRED_PACKAGES[i], load_reference)
    end
end)
