# Changelog

## 3.0.1 - 2026-09-10

- Fixed an error during manager transitions where event cleanup could access a destroyed `EventManager`.

## 3.0

- Improved Mourningstar and Meat Grinder preloading: selected-operative and selected-destination resources are prioritized, while Meat Grinder warming runs in small background batches after higher-priority work finishes.
- Added Preferred Mourningstar Location. Auto measures all regions; a fixed location is preferred for early hub-server reservation and applies on the next login.
- Added early Mourningstar server reservation and preconnection. The selected operative's hub session can begin at character select, and returns from missions can be staged during the score screen.
- Enabled Mourningstar server reservation and preconnection by default.

## 2.5 - 2026-08-27

- Added an opt-in early Mourningstar server reservation using Darktide's native Immaterium party and latched hub matchmaking. After login, one preliminary region-ping round can select the reservation region while character selection, profile preloading, and UI remain unchanged; vanilla still commits and synchronizes the final operative only after Play.
- Preserved the login-scoped region result, party, and reservation across the title-to-character-select transition instead of restarting them in the main menu. As soon as the reservation request captures the preliminary result, a normal 10-round region refresh replaces it in the background so later mission matchmaking waits for and uses vanilla's full measurement.
- Added fallback and cleanup for invalid preliminary measurements, title resets, loading transitions, party changes, setting disable, mod disable, and unload. Late asynchronous results are generation- and party-checked, and cleanup only consumes the exact reservation created by InstantHub.
- Guarded title-screen profile lookup with `PlayerManager:local_player_safe()`. Calling the unguarded lookup during `signing_in` reaches native `Network.peer_id()` before the connection exists and caused an access-violation crash.
- Kept post-mission behavior unchanged: Darktide already reserves the next hub server during the result screen, while Mourningstar Caching retains the local hub assets throughout the mission.

## 2.4.2

- Fixed false-positive unavailable-package warnings during cold direct launches to the Meat Grinder through mods such as Psych Ward. Speculative availability misses are now deferred silently, retried after the authoritative target load, and only reported if the package is still unavailable afterward.
- Added the owning preload scope to persistent unavailable-package warnings so genuine failures identify whether they came from Mourningstar, its theme, Psykanium, or the local profile.

## 2.4

- Preloaded the selected local profile after Mourningstar's early preload completes at character select, moving weapon, ability, cosmetic, voice, particle, and decal package work out of the first hub transition without competing with the hub preload.
- Reconciled local-profile references on every operative, loadout, talent, voice, and cosmetic change. Shared packages stay warm while resources no longer used by the current profile are released, without disturbing the Mourningstar cache.
- Fixed the local profile event callback signature so committed profile changes are detected immediately instead of relying on the character-select fallback.
- Reworked package ownership with deduplicated package references, generation-checked callbacks, and release-before-callback invalidation to prevent stale asynchronous loads from reviving released caches.
- Made Mourningstar and Meat Grinder dependency discovery `MasterItems`-version-aware. Changed item, view-level, and breed dependencies are re-evaluated additively without unloading the existing warm scope first.
- Removed the `BreedLoader` late-package retry hook. Unavailable packages now fail open with a warning and retry during the next relevant preload pass, authoritative target transition, or completed Meat Grinder load instead of leaving a preload permanently stuck in the loading state.
- Delayed the normal automatic Meat Grinder preload until Mourningstar has fully entered gameplay, preventing it from competing with the remaining hub loading stages. Explicit setting changes and authoritative Meat Grinder transitions can still start it immediately.
- Kept the early hub scope stable while separating replaceable context-dependent packages. Item-derived dependencies now revalidate additively, avoiding complete cache rebuilds when runtime context changes.
- Started the authoritative Mourningstar circumstance theme as soon as the hub transition exposes it, prioritized newly queued packages only in that exact level/theme chain, and retained it in its own replaceable package scope instead of guessing or pinning the default theme.
- Added authoritative Mourningstar and Meat Grinder transition checks so changed dependencies and temporarily unavailable target packages get a final revalidation before loading.
- Added a local-player resource keep-alive scope using the game's exact profile package resolver. Current weapon, ability, cosmetic, voice, particle, and decal packages now stay warm across gameplay transitions without caching mutable profile payloads or backend responses.
- Matched Darktide's view preload policies and added item dependency loading for dynamic mission-intro levels.
- Fixed setting ownership and disabled-mod lifecycle handling so `preload_hub` and `hub_caching` no longer release or restart each other's package scope incorrectly.
- Replaced loader-phase timing hooks with Darktide's `event_loading_finished`, so ready notifications reflect completed gameplay loading and also work for Meat Grinder's host loading path.
- Removed direct hook reloading support. Standard DMF Ctrl+Shift+R reload remains supported through deterministic package and event cleanup.
- Added cleanup and re-enable handling for title screen, character select, hub, mission, settings changes, mod disable, and mod unload transitions. Entering `StateTitle` now releases every session scope, while character switching preserves the independent Mourningstar cache.

## 2.3

**Psychanium / Meat Grinder preload and persistent warm caches.**

- **Added `Preload Psychanium / Meat Grinder` setting (default ON):** Preloads the Mourningstar Meat Grinder mission (`tg_shooting_range`) while in the hub and keeps its packages warm while enabled.
- **Replaced loader cleanup skipping with package keep-alive references:** Darktide loaders now keep their normal cleanup/state lifecycle, while InstantHub keeps Mourningstar and Meat Grinder packages warm through its own package references.
- **Kept Mourningstar preload references alive when Mourningstar caching is enabled:** Hub packages preloaded before character selection now also act as keep-alive references instead of being released immediately on gameplay enter. If early preload is disabled, Mourningstar caching still starts after the hub is loaded.
- **Expanded UI preload coverage:** UI view level packages now also preload their item dependency packages, matching `UIManager:load_view` more closely.
- **Fixed early hub preload option handling:** The `StateTitle` preload trigger now respects `Preload Hub at Character Select`.
- **Expanded hub breed preload coverage:** Mourningstar preload now includes player and companion breeds, matching the hub loader more closely.
- **Removed BreedLoader cleanup hook:** Now that no loader cleanup is skipped, all loaders including BreedLoader follow their normal lifecycle.
- **Late-packages guard added to completion check:** Preload is no longer marked done while packages are still pending late-load retry.

## 2.1

**Smarter loader coverage, stale-cache fixes, and early hub preloading.**

- **Added `Preload Hub at Character Select` setting (default ON):** Loads all Mourningstar packages (level, views, HUD, breeds) in the background, triggered as soon as backend data is synced during the title screen (`StateTitle`). Packages are released automatically when the hub loads (`StateGameplay` enter), on mod disable, or when the setting is turned off.
- **Added HudLoader and GameModeLoader hooks:** Previously only ViewLoader and LevelLoader were intercepted. HudLoader and GameModeLoader are now also cached, covering 5 of the 6 mission loaders.
- **Removed BreedLoader caching but kept defensive hooks:** BreedLoader is already persistent by default on PC. Replaced with a lightweight hook on `is_loading_done` for late-load retry of packages unavailable during preload, and a `cleanup` hook for defensive safety.
- **Added late-load tracking:** Packages that aren't available during preload (`Application.can_get_resource` returns false) are skipped gracefully and retried automatically when BreedLoader finishes loading.
- **Fixed stale cache flags on disable/re-enable:** When disabled, DMF re-enabled the original cleanup functions (releasing cached packages), but the cache flags still reported `cached_hub = true` — causing freezes or crashes on re-enable. Added `on_disabled` and `on_enabled` handlers that clear cache flags.
- **Fixed stale cache flags across transitions:** Cache flags are now preserved correctly across mission→hub transitions.
- **Added `on_game_state_changed` safety net:** Clears cache when entering the main menu and releases preloaded packages when entering the hub.
- **Added `allow_rehooking = true`:** Supports the `mod:io_dofile()` dev workflow — Ctrl+Shift+R now properly updates hook handlers.
- **Added widget tooltips:** All settings now have tooltips in Mod Options using `<setting_id>_description` keys.
- **Added loading-time notifications:** Hub loads and preload completion now show elapsed time.
- **Fixed preload crash:** Corrected require paths for `ItemPackage` and `ThemePackage`. Added `type(name) ~= "string"` guard in `preload_pkg`. Pass `"default"` as theme_tag.
- **Earlier preload trigger:** Preload now starts during the title screen (`StateTitle`), saving ~5–10 seconds by loading packages in parallel with the main menu loader.
- **Removed all Psykhanium/Training Grounds support.** Focus is exclusively on Mourningstar.
- **All mod options default to ON.**

## 2.0

Complete rewrite — level caching only. Every data prefetch, hook intercept, and cache mechanism from 1.x has been removed.
