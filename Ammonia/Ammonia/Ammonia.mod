-- Ammonia.mod by xxBellatrix (prevent call-outs about ammo from other players)
return {
run = function()
fassert(rawget(_G, "new_mod"), "`Ammonia` needs Darktide Mod Framework.")
new_mod("Ammonia", {
mod_script       = "Ammonia/scripts/mods/Ammonia/Ammonia",
mod_data         = "Ammonia/scripts/mods/Ammonia/Ammonia_data",
mod_localization = "Ammonia/scripts/mods/Ammonia/Ammonia_localization",
})
end,
packages = {},
}