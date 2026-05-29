-- Cut_transmission by xxbellatrix
return {
run = function()
fassert(rawget(_G, "new_mod"), "`Cut_transmission` encountered an error loading the Darktide Mod Framework.")
new_mod("Cut_transmission", {
mod_script = "Cut_transmission/scripts/mods/Cut_transmission/Cut_transmission",
mod_data = "Cut_transmission/scripts/mods/Cut_transmission/Cut_transmission_data",
mod_localization = "Cut_transmission/scripts/mods/Cut_transmission/Cut_transmission_localization",
})
end,
packages = {},
}