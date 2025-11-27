-- valkyrie.mod
return {
  run = function()
    fassert(rawget(_G, "new_mod"), "`valkyrie` needs Darktide Mod Framework.")
    new_mod("valkyrie", {
      mod_script       = "valkyrie/scripts/mods/valkyrie/valkyrie",
      mod_data         = "valkyrie/scripts/mods/valkyrie/valkyrie_data",
      mod_localization = "valkyrie/scripts/mods/valkyrie/valkyrie_localization",
    })
  end,
  packages = {},
}