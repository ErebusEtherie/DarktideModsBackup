-- Hunt the Salvage by xxBellatrix
return {
run = function()
fassert(rawget(_G, "new_mod"), "huntsalvage encountered an error loading the Darktide Mod Framework.")
new_mod("huntsalvage", {
mod_script = "huntsalvage/scripts/mods/huntsalvage/huntsalvage",
mod_data = "huntsalvage/scripts/mods/huntsalvage/huntsalvage_data",
mod_localization = "huntsalvage/scripts/mods/huntsalvage/huntsalvage_localization",
})
end,
packages = {},
}