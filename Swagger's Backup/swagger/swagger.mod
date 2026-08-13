-- Swagger's Backup by xxBellatrix
return {
run = function()
fassert(rawget(_G, "new_mod"), "swagger encountered an error loading the Darktide Mod Framework.")
new_mod("swagger", {
mod_script = "swagger/scripts/mods/swagger/swagger",
mod_data = "swagger/scripts/mods/swagger/swagger_data",
mod_localization = "swagger/scripts/mods/swagger/swagger_localization",
})
end,
packages = {},
}