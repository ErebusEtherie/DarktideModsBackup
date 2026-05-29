-- excise-vault-scope.mod by xxbellatrix
return {
run = function()
fassert(rawget(_G, "new_mod"), "`excise-vault-scope` encountered an error loading the Darktide Mod Framework.")
new_mod("excise-vault-scope", {
mod_script = "excise-vault-scope/scripts/mods/excise-vault-scope/excise-vault-scope",
mod_data = "excise-vault-scope/scripts/mods/excise-vault-scope/excise-vault-scope_data",
mod_localization = "excise-vault-scope/scripts/mods/excise-vault-scope/excise-vault-scope_localization",
})
end,
packages = {},
}