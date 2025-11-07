return {
  run = function()
    fassert(rawget(_G, "new_mod"), "`ColorSelection` encountered an error loading the Darktide Mod Framework.")

    new_mod("ColorSelection", {
      mod_script       = "ColorSelection/scripts/mods/ColorSelection/ColorSelection",
      mod_data         = "ColorSelection/scripts/mods/ColorSelection/ColorSelection_data",
      mod_localization = "ColorSelection/scripts/mods/ColorSelection/ColorSelection_localization",
    })
  end,
  packages = {},
}
