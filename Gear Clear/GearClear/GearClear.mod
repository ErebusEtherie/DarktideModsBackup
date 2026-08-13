-- GearClear by xxBellatrix
return {
run = function()
fassert(rawget(_G, "new_mod"), "GearClear encountered an error loading the Darktide Mod Framework.")

new_mod("GearClear", {
mod_script = "GearClear/scripts/mods/GearClear/GearClear",
mod_data = "GearClear/scripts/mods/GearClear/GearClear_data",
mod_localization = "GearClear/scripts/mods/GearClear/GearClear_localization",
})
end,
packages = {},
}