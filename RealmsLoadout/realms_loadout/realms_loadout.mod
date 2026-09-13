return {
  run = function()
    fassert(rawget(_G, "new_mod"), "realms_loadout encountered an error loading the Darktide Mod Framework.")

    new_mod("realms_loadout", {
      mod_script       = "realms_loadout/scripts/mods/realms_loadout/realms_loadout",
      mod_data         = "realms_loadout/scripts/mods/realms_loadout/realms_loadout_data",
      mod_localization = "realms_loadout/scripts/mods/realms_loadout/realms_loadout_localization"
    })
  end,
  packages = {
      "content/levels/ui/inventory/inventory",
      "content/levels/ui/credits_vendor/credits_vendor",
      "content/levels/ui/inventory_weapon_view/inventory_weapon_view",
      -- Forge adds the Curios tab from CreditsVendorView. Its devices material
      -- is not in the weapon-only CreditsGoodsVendorView package; keep an owned
      -- reference outside the hub too (Psykhanium, SoloPlay and Realms missions).
      "packages/ui/views/credits_vendor_view/credits_vendor_view",
      "packages/ui/view_elements/view_element_crafting_recipe/view_element_crafting_recipe",
      "packages/ui/view_elements/view_element_grid/view_element_grid",
      "packages/ui/view_elements/view_element_perks_item/view_element_perks_item",
      "packages/ui/view_elements/view_element_player_social_popup/view_element_player_social_popup",
      "packages/ui/view_elements/view_element_profile_presets/view_element_profile_presets",
      "packages/ui/view_elements/view_element_tab_menu/view_element_tab_menu",
      "packages/ui/view_elements/view_element_trait_inventory/view_element_trait_inventory",
      "packages/ui/view_elements/view_element_weapon_stats/view_element_weapon_stats",
      "packages/ui/view_elements/view_element_wintrack/view_element_wintrack"
  }
}

