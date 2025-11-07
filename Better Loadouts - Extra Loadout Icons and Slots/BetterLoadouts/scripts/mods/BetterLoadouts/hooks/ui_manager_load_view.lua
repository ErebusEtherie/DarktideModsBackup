-- File: scripts/mods/BetterLoadouts/hooks/ui_manager_load_view.lua
local mod = get_mod("BetterLoadouts"); if not mod then return end

-- Preload icon packages when views that host the Presets element open (DSMI pattern).
mod:hook_safe("UIManager", "load_view", function(self, view_name, reference_name)
    local pm = Managers.package
    if not pm then return end

    local function ensure(pkg)
        if pm:has_loaded(pkg) or pm:is_loading(pkg) then return end
        pcall(function()
            pm:load(pkg, reference_name, nil) -- tie lifetime to the opening view
        end)
    end

    if view_name == "main_menu_view"
        or view_name == "inventory_view"
        or view_name == "item_inspection_view"
        or view_name == "crafting_view"
        or view_name == "masteries_overview_view"
        or view_name == "cosmetics_vendor_view"
    then
        ensure("packages/ui/hud/player_weapon/player_weapon")
        ensure("packages/ui/views/mission_board_view/mission_board_view")
        ensure("packages/ui/views/masteries_overview_view/masteries_overview_view")
        ensure("packages/ui/views/cosmetics_vendor_view/cosmetics_vendor_view")
        ensure("packages/ui/hud/interaction_hud/interaction_hud")
        ensure("packages/ui/hud/interaction/interaction")
    end
end)
