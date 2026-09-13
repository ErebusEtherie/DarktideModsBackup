# RealmScoreboardExtend

Version 0.2.3-test, 2026-09-12. An independent extension of **scoreboard** for mission, end-screen and historical scoreboards. It supports 1–12 players per page (default 8), configurable page keys, automatic scaling and optional equipment rows from LoadoutMonitor.

## Installation

1. Exit the game. Extract `RealmScoreboardExtend-0.2.3-test.zip` into the game's `mods` folder.
2. Load `scoreboard`, LoadoutMonitor and any additional scoreboard plugins before `RealmScoreboardExtend` in `mod_load_order.txt`.
3. Remove the old `ScoreboardRoster` load-order entry and disable `RealmsScoreboard8`. Do not load both extensions. Existing ScoreboardRoster settings are imported once; settings already saved under RealmScoreboardExtend take priority.

The original multiplayer pack is also available as `RealmScoreboardExtend-0.2.3-test-9.11-Compat.zip`. Other bundled mods are byte-for-byte unchanged from the 0.2.2 bundle. If you have separately upgraded Realms or other mods, update only RealmScoreboardExtend to avoid replacing newer versions with the old pack. Builds are produced on D: for manual installation. Keep existing settings and histories.

## Missing columns and history refresh

- Duplicate bot names and temporarily missing player identifiers now receive separate roster records using local session slots, including Realms slot 0. Late profile names reconnect to those records. Equipment snapshots use the resolved identity too. Unique upstream statistic keys and engine/network player identities remain intact.
- Saving a history invalidates the parsed history-list cache, so a mission appears even if the list was opened before the mission. Repeated saves to the same timestamp/file no longer append duplicate list entries. The base scoreboard still controls whether histories are saved.
- Diagnostics now record live/retained counts, source/resolved identities, actual populated header columns and completed history saves. Look for `[RSE:capture]`, `[RSE:identity]`, `[RSE:columns]` and `[RSE:history_saved]`; `/rse_status` includes each column's statistic key.

The supplied log confirms seven retained records and a bot joining at slot 0, but lacks enough identity detail to prove which record was lost. Duplicate-name loss and history-cache staleness were reproduced locally. If an upstream plugin already combines two same-name bots into one statistic key, the combined number cannot be split reliably. The extension preserves separate columns/equipment without duplicating that total; missing independent values follow the base scoreboard's zero-value setting. A history that originally saved only seven players cannot recover an unsaved eighth player.

## Language and text

- Options, player status labels, page hints, dependency messages, command help and on-screen diagnostics support English and Simplified Chinese. They follow the game's startup language; other UI languages fall back to English. Restart after changing the game language.
- Player names and plugin text retain their original UTF-8 characters, including mixed languages. Plugin localization keys use the plugin's translations when available; literal text and missing translations fall back to the supplied text. Names and already-rendered plugin text are not automatically translated.
- Literal percentages and punctuation in composite row labels are handled as text. Missing text no longer displays the old placeholder. Page hints show the actual key bindings.
- Long text is scaled or shortened for display without truncating the saved text. Glyph coverage depends on the game's fonts.
- New history files escape delimiter/control characters and restore them when read by this extension. Existing histories are not rewritten or decoded as new files. The base scoreboard can still read the numeric statistics; special characters in new files may appear escaped without this extension.
- Historical plugin labels retain the language in which they were saved. This mod's generated equipment labels and UI use the current UI language. Player statistic IDs and equipment snapshot identifiers stay unchanged.

## Controls and equipment

Use Page Up / Page Down by default, or rebind them in Mod Options. Press Esc in a history detail view to return to its list. `/rse_status`, `/rse_next` and `/rse_prev` remain available, with `/sr_*` compatibility aliases.

LoadoutMonitor equipment appears below the statistics. Perks and blessings each default to two visible entries per weapon; increase their limits in Mod Options. Extra entries display “N more”. Full snapshots remain in new histories. Missing old equipment is shown as “Not recorded”.

## Validation

336 Lua/Mod files passed isolated Lua 5.1 syntax checks. Local tests exercise slot 0, duplicate and missing names, late statistic keys, eight populated headers/data columns and separate equipment through all three view adapters, and the actual history-list cache after saving. Existing localization, multilingual text, UTF-8 truncation, history round trips, old records, paging, Back, colors, end-screen draw propagation and multiplayer compatibility tests pass.

Actual game rendering has not been tested for this release. Open the history list before a new mission with one human and seven bots; then check all eight columns in the mission, end screen and newly saved history. If a column is still missing, run `/rse_status` in the affected view and provide that session's log.
