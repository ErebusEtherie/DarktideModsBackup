-- weakspots.mod by xxBellatrix
return {
run = function()
fassert(rawget(_G, "new_mod"), "`Weak Spots` encountered an error loading the Darktide Mod Framework.")
new_mod("weakspots", {
mod_script       = "weakspots/scripts/mods/weakspots/weakspots",
mod_data         = "weakspots/scripts/mods/weakspots/weakspots_data",
mod_localization = "weakspots/scripts/mods/weakspots/weakspots_localization",
})
end,
packages = {},
}