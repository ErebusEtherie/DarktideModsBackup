-- (S)imple (M)od (O)bject (G)arbage Cleaner by xxbellatrix
-- SMOG.mod
return {
run = function()
fassert(rawget(_G, "new_mod"), "`SMOG` encountered an error loading the Darktide Mod Framework.")
new_mod("SMOG", {
mod_script = "SMOG/scripts/mods/SMOG/SMOG",
mod_data = "SMOG/scripts/mods/SMOG/SMOG_data",
mod_localization = "SMOG/scripts/mods/SMOG/SMOG_localization",
})
end,
packages = {},
}
