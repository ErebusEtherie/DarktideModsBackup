# Custom Character Bots

DMF mod for using your own saved Darktide characters as Solo Play bot profiles.

Custom Character Bots is intended to act as the saved-character/profile layer in a BetterBots + Tertium setup: it chooses your account characters for bot slots, then lets BetterBots drive combat behavior when BetterBots is installed.

## Current Status

Custom Character Bots lists your saved characters, caches them in the Mourningstar, and can replace locally hosted Solo Play bots with those saved profiles.

## Version

Current package version: `0.2.3`.

`0.2.3` delays frontend auto-cache attempts and backs off longer after early backend failures to reduce startup BackendError warnings.

Implemented:

- `/ccb_profiles` chat command
- Optional keybind to fetch saved profiles
- Automatic Mourningstar profile cache
- Automatic character-select/profile-service cache
- Automatic bot replacement re-arm between screens/missions
- Debug/status logging setting
- Host-only saved-character bot replacement
- `/ccb_reset` command to reset the substitution counter
- Saved-loadout ranged weapon compatibility patch
- BetterBots-derived shoot-input cleanup, sustained-fire, and weapon-special helpers
- Optional bot voice/tag support for low ammo, low health, special tags, and revive thanks
- Experimental player-like behavior overhaul for autonomous scouting, independent target selection, wider engagement, sprinting/crouch-slide-style movement, combat dodging, proactive pickup/container searching, active ammo/healing use, stimm pickup/use, grenade/utility ability use, nearby chest/container interaction, hazard dodging, and BetterBots-style item/enemy tags
- Experimental per-character behavior learning, gated behind `Experimental features`
- BetterBots compatibility mode: CCB becomes the profile provider while BetterBots owns combat, revives, abilities, grenades, movement, pickups, and safety behavior
- Tertium 4/5 compatibility guard so Tertium does not overwrite a bot profile already supplied by CCB
- `/ccb_status`, `/ccb_bots`, and `/ccb_debug` diagnostics
- Feasibility report in `docs/feasibility-report.md`

Still improving:

- Character priority settings
- Deeper BetterBots/Tertium validation across more classes and weapons
- Public/private session behavior checks

## Requirements

- Darktide Mod Loader
- Darktide Mod Framework
- A game state where `Managers.data_service.profiles` is available
- Solo Play or a locally hosted session
- Recommended: BetterBots
- Optional: Tertium 4/5 or Tertium 6

## Installation

Install with Vortex or copy the `CustomCharacterBots` folder into Darktide's `mods` folder.

Recommended load order:

```text
BetterBots
Tertium4Or5
CustomCharacterBots
```

If you do not use Tertium, omit that line. Keep `CustomCharacterBots` below BetterBots/Tertium so its saved-character profile selection runs last.

Run Darktide with mods enabled.

## Usage

Run this chat command:

```text
/ccb_profiles
```

The mod prints saved characters with name, class/archetype, level, and character id. The current character is marked when the profile service reports it.

For saved-character bot replacement:

1. Load to character select or the Mourningstar and wait for `Custom Character Bots: cached ... saved character(s).`, or run `/ccb_profiles` manually.
2. Enable `Enable Custom Character Bots` in the DMF mod options.
3. Keep `Solo host only` enabled.
4. Keep `Use core classes only` enabled unless you are testing newer classes.
5. Leave `Allow duplicate characters` off unless you intentionally want repeated profiles.
6. Set `Combat loadout mode` to `Saved loadout weapons` to test your characters' own weapons.
7. Optionally set `Preferred character index` to `Random` or one of the numbered core-class characters from `/ccb_profiles`.
8. Start a Solo Play/private locally hosted mission with at least one bot.
9. Watch for `Custom Character Bots: replacing bot #1...`.
10. Run `/ccb_status` to confirm BetterBots/Tertium compatibility state.
11. Run `/ccb_bots` in mission to confirm the live bots are carrying CCB metadata.
12. Run BetterBots' `/bb_state` to confirm BetterBots can see and update those same bots.
13. Use `/ccb_reset` before another test attempt.

## Compatibility Notes

BetterBots is the preferred behavior provider. When BetterBots is installed and `BetterBots plugin mode` is enabled, Custom Character Bots disables its own experimental player-like behavior layer and supplies saved-character profiles for BetterBots to run.

Leave `BetterBots plugin mode` on for normal playtesting. Use `Experimental features` only when deliberately testing CCB's own learning/player-like systems without BetterBots behavior mode.

See `THIRD_PARTY_NOTICES.md` for BetterBots license attribution.

Tertium 4/5 and Tertium 6 can remain installed. CCB includes a compatibility guard so Tertium's per-slot character picker yields when CCB has already supplied a saved-character bot profile.

## Known Limits

Darktide public matchmaking uses dedicated servers. Since bot spawning/profile selection is host-side, bot replacement is expected to work only in local host/Solo Play-style sessions.

Bot replacement is confirmed to be feasible in local/Solo Play-style sessions, but public matchmaking is still expected to be outside the mod's control.

## Development Findings

See `docs/feasibility-report.md`.

## Credits

- Darktide Mod Framework community
- Darktide Mod Loader community
- BetterBots by hummat and contributors
- Aussiemon's public Darktide Lua script reference
