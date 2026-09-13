# Changelog

0.5.4

* Fixed UI from other mods remaining visible when opening Realms Loadout from the operative selection screen.
* Fixed a crash that could occur during mission completion.
* Further strengthened the separation of Realms Loadout equipment and talent setups from official loadouts.

0.5.2

* Fixed issues where `/rl` talent changes and loadout changes could incorrectly overwrite official data when opening official equipment/talent screens. It also fixes loadout/talent rollback behavior when switching back from official inventory during Realms preparation, preventing unexpected talent rewrites during room flow, and adds safer loading guards to the talent and inventory views so temporary missing resources are handled more gracefully instead of throwing errors.

0.5.1

* Added a button on each Realms preparation player row to open a read-only view of that player's loadout.
* The solo/host talent-point budget slider and the per-player talent-point controls on the preparation screen now go from 0 to 99.
* Added a Stamina attachment option to the Realm Forge attachment list, placed directly after Wounds (fixed +3 stamina).
* Fixed forged and existing local weapons showing their five base stats in alphabetical order: the Forge now automatically reads `base_stat_orders.json` and applies the official order, and existing local weapons are migrated on load.
* Lowered the default trust level (character level) of newly forged weapons from 30 to 1.

0.5.0

* Merge the experimental version into the main version

0.5.0-experimental.4

* Raise the Scum stimm cap from 100 to 103 across the DMF slider, Realms numeric controls, private editor, saved builds and host/client validation.
* Confirm the native full-tree cost: combat 33, concentration 25, durability 20 and celerity 25, totaling 103 points across 29 nodes.
* Keep the default at 30 and preserve existing slider values, ordinary talent limits and native node costs.
* Update English, Simplified Chinese and Traditional Chinese help. Hosts and guests must use this same build for 103-point synchronization.

0.5.0-experimental.3

* Remove the official-points checkbox. The Scum stimm slider now sets 0-100 points directly, with a default of 30 and existing slider values retained.
* Unlock the audited native Stimm Lab branch choices in both the private editor and authoritative host validation. Preserve point costs, prerequisites, native effects and the original inventory.
* Fit talent points, Scum stimm points, aura/keystone choices and one deployment status into one Realms control row. Non-Scum players have no stimm field.
* Keep both numeric fields independent, including paste, click-away confirmation, hold repeat and stale-player protection.
* Remove the standalone talent keybind. Use /rl or the workspace shortcut, then select Talents.
* Update English, Simplified Chinese and Traditional Chinese text. Hosts and guests must update together for the expanded Stimm policy.

0.5.0-experimental.2

* Remove the standalone /talentpoints chat command. Open /rl and select Talents; the optional DMF talent shortcut remains available.
* Update English, Simplified Chinese and Traditional Chinese usage text.

0.5.0-experimental.1

* Combine equipment, Forge, Talent Point Manager functionality and Scum Stimm Lab under one realms\_loadout owner, settings page and workspace.
* Import official presets only for characters without local loadout records. Preserve local additions, deletions, order and active selection when reopening; stop pruning legacy local IDs.
* Link equipment and talent trees to the authoritative local slots, retain per-slot initial trees and migrate saved standalone talent builds without deleting old data.
* Separate custom LoadoutNames keys from official preset names.
* Add official-default Scum stimm points and a custom 0-100 DMF cap; add host-only per-Scum-player controls in Realms.
* Validate and apply stimm recipes with native costs and prerequisites. Sync host limits, enforce reductions immediately, retain desired guest builds and display the unified mod version.
* Retain Mortis workspace/room-control compatibility, native I-key isolation, loading safeguards and disabled/hidden talent diagnostics.

Experimental compatibility release. Host and guests need this same unified build; disable standalone TalentPointManager. Automated Lua, native-rule, persistence, UI-boundary and simulated host/client checks are included in the project. Live game/multiplayer validation remains required.

## 0.4.0 - 2026-09-06

### Fixed

* Fixed the Ogryn Realm Forge displaying human weapons instead of Ogryn weapons when "Remove Weapon Career Restrictions" was enabled.

## 0.4.1 - 2026-09-07

### Fixed

* Isolated the Realms talent view from the live official talent builder definitions by loading a mod-owned snapshot during mod init, so widgets/scenegraph nodes injected by other mods (e.g. MortisBuffManager) no longer appear in the Realms talent page.
* Fixed the Realm Forge marked Perk/Trait border crash: the vendored Forge view elements now preload all of their `view\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_element\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\*` packages, and the marked border no longer references `line\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_thin\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_dashed\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_animated`; it uses `frame\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_corner\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_2px`, which the same grids already draw, so `Material not found` can no longer occur when a Perk or Trait is marked.
* Treat the Cryptic/Skitarii breed as human-compatible in the local weapon selector and Realm Forge, so Cryptic and human weapons can be shared when "Remove Weapon Career Restrictions" is enabled.
* Prevent the inventory profile spawner from applying Cryptic-exclusive weapon idle animations to non-Cryptic human careers, avoiding a Lua crash when a Broker/Veteran/Zealot/Psyker previews a Cryptic-exclusive weapon (e.g. the phosphor pistol) in the Realms loadout view.
* Added a Broker Stimm Lab Extra Talent Points setting (0-100, default 0) with Realms host synchronization, mirroring the regular Realm Extra Talent Points behavior. Extra Stimm points allow spending beyond the base 30-point tree, but cooldown remains based on the original 30 expertise points and stops increasing once 30 points are spent.

## 0.3.0 - 2026-09-06

### Added

* Declared Realms as a required dependency in `info.json`.
* Added Traditional Chinese (`zh-tw`) and Russian (`ru`) localization for all mod texts.
* Added localized tab prefixes for the loadout page tabs.
* Added localized chat command description for `realms\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_loadout`.
* Added English `readme.md`, Chinese feature guide (`mod功能.txt`), and Chinese usage guide (`使用说明.txt`).
* Added inventory change detection so newly acquired official weapons are added to the local catalog without overwriting existing local copies.

### Changed

* Weapon mark switching is now always local-only and no longer calls the official backend.
* Sync Official Weapon now refreshes the current preview immediately.
* Opening the loadout page now uses the cached weapon catalog instead of rebuilding the full catalog every time, greatly reducing page-open stutter.
* Catalog cache is automatically invalidated when the official inventory changes or when official items are discarded.

### Fixed

* Fixed a race condition where an unrelated `backend\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_profile\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_data\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_to\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_profile` call could consume the pending Realms profile override.
* Fixed repeated Sync Official Weapon requests being triggered by clicking the button multiple times.
* Fixed `realms\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_broker\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_stimm\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_builder\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_view` using the talent builder display name.
* Removed hardcoded tab prefix text and replaced it with localization keys.

## 0.2.0 - Initial Release

* Local copy of the official equipment and talent UI for Realms LAN sessions.
* Local loadout presets, weapon catalog, attachment catalog, and Realm Forge.
* Extra talent points with host/client synchronization.
* Optional weapon career restriction removal.
* Optional uncapped weapon and attachment stats.
* BetterLoadouts and LoadoutNames compatibility.

## 0.1.0

* Added localized loadout pages.
