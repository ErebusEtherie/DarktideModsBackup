return {
        run = function()
            fassert(rawget(_G, "new_mod"), "ColorMyStamina must be lower than DMF in your load order.")
            new_mod("ColorMyStamina", {
                mod_script       = "ColorMyStamina/scripts/mods/ColorMyStamina/ColorMyStamina",
                mod_data         = "ColorMyStamina/scripts/mods/ColorMyStamina/ColorMyStamina_data",
                mod_localization = "ColorMyStamina/scripts/mods/ColorMyStamina/ColorMyStamina_localization",
            })
        end,
        package = "resource_packages/mods/ColorMyStamina/ColorMyStamina",
        version = "1.0.0",
}