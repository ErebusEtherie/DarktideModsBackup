# Realms Loadout

Manage custom equipment, cosmetics, weapon forging, talent builds and Scum stimm recipes in one window. Designed for SoloPlay and Realms, with host-authoritative rules in Realms rooms.

## How to use

Type /rl to open the workspace and select its Talents tab. No key binding is required. An optional workspace shortcut is available in this mod's DMF settings; select Talents inside the workspace. Close the original inventory first. The original I-key inventory remains separate.

This edition includes Talent Point Manager functionality. Disable the separate TalentPointManager mod before using it. Install one realms_loadout copy only.

## Local loadouts

The first time a character has no local loadout file, official presets are copied into local slots. After that, additions, deletions, order and active selection belong to the local workspace. Equipment and talent builds switch together. Later official-preset changes do not overwrite local slots.

Existing local equipment and saved Talent Point Manager builds are migrated without deleting the old data. Guest talent builds remain separate from the local build so host restrictions can be applied without discarding the full local selection.

## Talents and Scum stimms

- Configure 30-99 ordinary talent points, multiple auras and multiple keystones. Points, prerequisites and unaudited exclusive choices still apply.
- Keep the existing compatible talent modifier combinations and optional bot talent settings.
- Set Scum stimm points directly with the DMF slider, from 0 to 103 (default 30). Selecting every Stimm Lab node costs 103 points. Combine the native combat, durability, concentration and celerity branches while retaining costs and prerequisites. These settings apply to local/SoloPlay and initial Realms rules.
- Realms hosts can set talent points, auras and keystones for individual players. A single compact row contains these controls and deployment status; Scum players also have a stimm point field in that same row. Other classes use the ordinary layout without a stimm field. Guests use the host's limits; the host applies tighter limits immediately.
- Room controls show realms_loadout deployment status and version. Disconnects, rejoining and loading transitions retire stale rules and requests.

## Equipment and interface

Retains equipment and cosmetic presets, Forge, local weapon and curio catalogs, weapon stats, blessings, perks and appearance controls. Native inventory tabs and preset controls keep equipment and talents in the same workspace. Scum characters have a Stimm Lab tab.

Compatible with Mortis Buff Manager's workspace and Realms controls, and with BetterLoadouts and LoadoutNames. Mortis remains a separate optional mod. Talent diagnostics are disabled and hidden.

## Requirements

Darktide Mod Loader and Darktide Mod Framework, plus SoloPlay or Realms for custom gameplay. When using Realms, install its dependencies and use the same unified realms_loadout build on the host and guests. The separate TalentPointManager mod is replaced by this edition.

## Vortex installation

- Close the game. Disable the separate TalentPointManager and previous realms_loadout installation.
- Import this ZIP using Install From File, enable it and deploy.
- Place realms_loadout after SoloPlay or Realms in the mod load order.
- Keep existing local save files to migrate your builds and loadouts.

## Manual installation

- Close the game. Replace the previous mod folder with the folder in the ZIP, producing mods/realms_loadout.
- Add realms_loadout once in mods/mod_load_order.txt after SoloPlay or Realms; remove or disable the separate TalentPointManager entry.
- Keep local save files. Open the workspace with /rl.

## Credits

Original Realms Loadout by Tokyovania. Unified talent and stimm management by IRONCROWY. Realms by deluxghost; native game assets by Fatshark.
