# Custom Character Bots Test Plan

## Stage 1 Prototype: Profile Listing

1. Install `CustomCharacterBots` in the Darktide `mods` folder.
2. Add `CustomCharacterBots` below `dmf` in `mods/mod_load_order.txt`.
3. Launch the game with DMF enabled.
4. Run `/ccb_profiles` in the hub.
5. Confirm the mod prints saved characters with name, class, level, and id.
6. Run `/ccb_profiles` in a Solo Play/private mission.
7. Confirm whether the profile service is still available.

Expected safe result:

- The command either lists profiles or reports that the profile service is unavailable.
- It must not alter saved characters, equipped items, progression, or account data.

## Stage 2 Prototype: One Bot Substitution

Implemented behind the `enable_one_bot_swap` setting.

1. Run `/ccb_profiles` before starting the mission.
2. Enable `Enable one-bot substitution test`.
3. Keep `Solo host only` enabled.
4. Keep `Skip newer archetypes` enabled.
5. Keep `Allow duplicate characters` disabled for multi-bot tests.
6. Set `Combat loadout mode` to `Bot-safe weapons`.
7. Prefer testing a Veteran, Zealot, Psyker, or Ogryn profile before Adamant/Broker/Cryptic.
8. Start a Solo Play/private locally hosted mission.
9. Confirm whether substituted bots use different saved profiles.
10. Confirm whether bots can fire/use their combat weapons.
11. On any error, confirm the mission still starts and a vanilla bot is used.
12. Use `/ccb_reset` before repeated attempts.

Test cases:

- One missing player slot.
- Two missing player slots.
- Three missing player slots.
- Human joins after custom bot spawns.
- Character uses standard bot-safe weapons.
- Character uses staff/plasma/charged weapon.
- Character uses DLC archetype.
- BetterBots installed above and below this mod.

Pass criteria for the first test:

- Mission starts.
- One bot slot is created.
- Chat logs `Custom Character Bots: replacing bot #1...`.
- Bot appears with the saved character class/appearance, or the mod logs a fallback and the vanilla bot appears.
- Name should use the saved character name plus the normal bot tag.
- No saved character data is changed.

## Current Combat Limitation

Full saved player loadouts are not guaranteed to be bot-safe. If a bot spawns correctly but only melees, the likely cause is that its saved ranged weapon lacks the bot metadata or behavior support expected by the vanilla bot brain. The current prototype can replace combat slots with bot-safe weapons while keeping the saved character identity/appearance. Later compatibility work should add one or both of:

- Bot-safe weapon substitutions per class.
- Optional compatibility with BetterBots-style metadata and ability heuristics.
