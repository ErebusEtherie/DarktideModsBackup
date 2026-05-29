-- Salvage Our Souls by xxbellatrix

-- salvage.mod 
return {
run = function()
fassert(rawget(_G, "new_mod"), "salvage encountered an error loading the Darktide Mod Framework.")

new_mod("salvage", {
mod_script = "salvage/scripts/mods/salvage/salvage",
mod_data = "salvage/scripts/mods/salvage/salvage_data",
mod_localization = "salvage/scripts/mods/salvage/salvage_localization",
})
end,
packages = {},
}