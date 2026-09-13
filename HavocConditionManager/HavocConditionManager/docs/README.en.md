# Havoc Condition Manager - Solo Play Expansion

Havoc Condition Manager requires SoloPlay and also supports Realms sessions. Configure mission conditions through the SoloPlay menu for solo play or Realms co-op. Havoc, Auric/Maelstrom, event and faction rules have separate categories, and the environment can be selected independently.

## What you can change

- Combine supported conditions without the original fixed slot count. Available entries depend on the installed game scripts.
- Browse Havoc, Auric/Maelstrom, event and faction categories instead of a single mixed list.
- Pick one compatible environment. If a map cannot use that environment, the selection falls back to a supported option.
- Set 1–5× multipliers for common enemies, elites, specialists and bosses. Choose quantity, spawn speed or a mixture of both.
- Use the base mod on its own, or add Havoc Enemy Director for editable generators, pools and capacity limits.

Basic mode combines the selected native condition effects and adjusts their spawning parameters. It retains native generators, pools and capacity rules; conditions can still impose their own original faction and pool changes. A 5× multiplier therefore does not guarantee five times as many enemies alive at once.

## Requirements and installation

Install Darktide Mod Loader, Darktide Mod Framework and SoloPlay first. Solo Play 2.6.1 is the version used with this release. For Realms co-op, also install Realms; SoloPlay remains required. Havoc Enemy Director is optional.

## Vortex installation

- Close the game. Set up Darktide as a managed game in Vortex and install the requirements listed above.
- Download this mod's installation ZIP from Files. In Vortex, use Install From File to import it, then enable the mod and select Deploy Mods.
- Open Load Order, enable HavocConditionManager and place it after SoloPlay. If HavocEnemyDirector is installed, place it after HavocConditionManager.
- Start the game and open Havoc Condition Manager from Mod Options.

## Manual installation

- Close the game and install the requirements listed above, following each dependency's instructions.
- Open the Darktide game folder. In Steam: Properties → Installed Files → Browse.
- Open the game's mods folder and extract this ZIP there. Its top-level folder is HavocConditionManager. The resulting path must be mods/HavocConditionManager.
- Open mods/mod_load_order.txt and add HavocConditionManager on its own line after SoloPlay. Preserve all other entries. If using HavocEnemyDirector, put it after HavocConditionManager.
- Save the file, start the game and open Havoc Condition Manager from Mod Options.

Disable older condition extensions that also replace Solo Play's condition selection, when using this manager.

## Framework switch

Use the enable/disable switch in Darktide Mod Framework. In the hub, it applies immediately. During a local or Realms mission, the switch is saved for the next mission; the current mission keeps its initialized condition and spawning configuration. A notification confirms a deferred change. Saved settings are retained.

Disabling the manager restores SoloPlay's original menu and mission setup for future missions, and suspends Havoc Enemy Director.

## Getting started

Open Mod Options, find Havoc Condition Manager and press Open. Choose the mission settings, conditions, environment and multipliers before starting your next SoloPlay or Realms mission. In Realms, the host configures the mission. The side arrows switch pages. Installing Havoc Enemy Director adds the Advanced page to this menu.

English, Simplified Chinese and Traditional Chinese follow the game language. Restart after changing the game's language. Native condition and environment names use the game's available translations.

## Compatibility and limits

Mission configuration uses SoloPlay and also supports player-hosted Realms sessions, where the host applies the mission settings. This release does not claim support for changing official matchmaking missions or progression; SoloPlay sessions do not award normal progression or rewards. Avoid combining several mods that replace the same condition or spawning logic.

Some condition effects are handled by the game's internal systems. An entry can apply a Buff without creating a new spawn source. Environments are selected individually; this is not an environment-stacking feature.

Code and simulated UI checks passed, including running this manager without Havoc Enemy Director. The current release has not received a new live-game test. Layout checks covered common 16:9, 16:10 and ultrawide sizes, but do not replace testing on every display and UI scale.

## Version 2.4.10

- Fixed redundant presence updates when Realms and Modular Menu Buttons are used together during local Havoc gameplay. Genuine activity changes and menu behavior are preserved.
- Added low-frequency workload records for expanded player Buff queues: at most one event-batch sample every five seconds, with summaries every thirty seconds. Sampling reuses native parameter reclamation; no per-unit Buff-update hook is added.
- Preserved native Buff templates and network IDs, proc order, overflow protection, condition effects, multipliers and saved settings.
- Fully exit and restart the game after updating. Log-based workload checks do not establish an average-FPS improvement.

## Version 2.4.9

- Removed the per-unit Buff-update diagnostic callback. Expanded proc queues report through their existing reclamation path, retaining overflow protection, nested-event order and the finite ceiling.
- Skipped native composition analysis while the advanced director owns spawning.
- Preserved native Buff templates and network IDs, condition effects, multipliers and saved settings.
- Added independent regression coverage for native proc overflow and nested dispatch. No live-game FPS improvement has been measured; fully exit and restart the game after updating.

## Version 2.4.8

- Nurgle's Blessing now uses the original game Buff template and network ID.
- Removed the duplicate Buff registration that could shift IDs assigned by other custom-buff mods.
- Retained the existing condition selection, enemy effects and optional Havoc-rank spawn probability scaling.
- Fully exit the game before updating, then restart. Co-op players who use an older version of this mod should also update and restart.

## Version 2.4.7

- Enabled the Darktide Mod Framework toggle.
- Hub switches apply immediately; in-mission switches apply next mission and keep the current runtime consistent.
- Retained saved settings and added three-language switch guidance.

## Credits

Solo Play and the original UI foundation: deluxghost. Native game systems, names and referenced assets: Fatshark. Darktide source references: Aussiemon/Darktide-Source-Code. This mod is an independent community project.
