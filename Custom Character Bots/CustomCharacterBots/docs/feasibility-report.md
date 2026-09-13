# Custom Character Bots Feasibility Report

Date: 2026-07-21

## Scope

This report covers the Stage 1 investigation for a Warhammer 40,000: Darktide DMF mod that uses the player's own saved characters as bot profiles. It is based on public community mod code, the Darktide Mod Framework, and the public decompiled Darktide Lua script reference checked out under `external/Darktide-Source-Code`.

No in-game test has been run yet in this workspace, so runtime claims are marked as source-confirmed, likely, uncertain, or not confirmed.

## Sources Reviewed

- `external/Darktide-Mod-Framework`
- `external/Darktide-Mod-Loader`
- `external/Darktide-Mod-Builder`
- `external/BetterBots`
- `external/Darktide-Source-Code`
- Nexus/Forum public pages for BetterBots, Tertium 5, and Tertium 6

Useful public links:

- DMF docs: https://dmf-docs.darkti.de/
- DMF source: https://github.com/Darktide-Mod-Framework/Darktide-Mod-Framework
- Mod Loader source: https://github.com/Darktide-Mod-Framework/Darktide-Mod-Loader
- Mod Builder source: https://github.com/Darktide-Mod-Framework/Darktide-Mod-Builder
- BetterBots source: https://github.com/hummat/BetterBots
- Darktide decompiled Lua reference: https://github.com/Aussiemon/Darktide-Source-Code
- BetterBots Nexus page: https://www.nexusmods.com/warhammer40kdarktide/mods/745
- Tertium 5 Nexus page: https://www.nexusmods.com/warhammer40kdarktide/mods/183
- Tertium 6 / 7 Nexus page: https://www.nexusmods.com/warhammer40kdarktide/mods/725

## Key Findings

### 1. Saved characters are exposed through the profile service

Source-confirmed.

Relevant file: `external/Darktide-Source-Code/scripts/managers/data_service/services/profiles_service.lua`

`ProfilesService.fetch_all_profiles()` calls:

- `backend_interface.characters:fetch()`
- `backend_interface.progression:get_entity_type_progression("character")`
- `Managers.data_service.gear:fetch_gear()`
- `backend_interface.account:get_selected_character()`

It returns a table containing:

- `profiles`
- `selected_profile`
- `gear`

The conversion path is `ProfileUtils.character_to_profile(character, gear_list, progression)`.

### 2. Player profiles include the fields needed for the target concept

Source-confirmed.

Relevant file: `external/Darktide-Source-Code/scripts/utilities/profile_utils.lua`

`ProfileUtils.character_to_profile` builds a profile containing:

- `character_id`
- `archetype`
- `current_level`
- `talent_points`
- `expertise_points`
- `gender`
- `selected_voice`
- `voice_effects`
- `skin_color`
- `hair_color`
- `eye_color`
- `loadout`
- `visual_loadout`
- `loadout_item_ids`
- `loadout_item_data`
- `lore`
- `selected_nodes`
- `talents`
- `name`
- `personal`
- `narrative`
- optional `companion`

This is enough to preserve most appearance, voice, cosmetics, weapons, and talent data if the bot pipeline accepts the profile intact.

### 3. Bot spawning accepts a profile table

Source-confirmed.

Relevant files:

- `external/Darktide-Source-Code/scripts/managers/bot/bot_spawning.lua`
- `external/Darktide-Source-Code/scripts/bot/bot_synchronizer_host.lua`
- `external/Darktide-Source-Code/scripts/bot/bot_synchronizer_client.lua`

Vanilla bot flow:

```text
BotSpawning.spawn_bot_character(profile_name)
  -> ProfileUtils.get_bot_profile(profile_name)
  -> bot_synchronizer_host:add_bot(local_player_id, profile)
  -> profile_synchronizer_host:add_bot(local_player_id, profile)
  -> player_manager:add_bot_player(..., profile, ...)
  -> clients receive profile through profile synchronization
```

The best prototype seam is `BotSynchronizerHost.add_bot(local_player_id, player_profile)`, because it already receives the fully materialized profile before synchronization and player creation.

### 4. Bot backfill is host/server side

Source-confirmed.

Relevant file: `external/Darktide-Source-Code/scripts/managers/player/player_unit_spawn_manager.lua`

Bot spawning runs only when `Managers.state.game_session:is_server()` is true. `PlayerUnitSpawnManager` handles initial bot spawning and replacement on client disconnect.

This means a profile-replacement mod must run on the session host/server to affect spawned bots.

### 5. Public matchmaking is almost certainly out of scope

Source-supported, not independently in-game tested here.

BetterBots documents that public/matched Darktide uses Fatshark dedicated servers and that BetterBots only affects locally hosted Solo Play-style sessions. Since this mod also needs host-side bot spawning/profile authority, the same limitation likely applies.

Expected support:

- Solo Play / local singleplayer host: likely.
- Private locally hosted sessions if provided by Solo Play/Tertium-style mods: likely.
- Public/matched dedicated-server games: likely impossible for bot profile replacement.
- Non-host clients: likely can list profiles, but cannot alter bot spawn profiles.

## Feasibility Questions

1. Where does Darktide store or expose created character profiles?

Exposed through backend/data services, especially `Managers.data_service.profiles:fetch_all_profiles()`. Raw character data comes from `backend_interface.characters:fetch()`, progression from `backend_interface.progression`, gear from `Managers.data_service.gear`.

2. Can those profiles be accessed while inside a mission?

Likely, but not confirmed in-game. The data service exists globally in game states, but the prototype must test whether `Managers.data_service.profiles` is available and whether backend requests are allowed during `GameplayStateRun`.

3. Can a saved player profile be passed directly into the bot spawning system?

Likely, but not confirmed in-game. The bot synchronizer accepts a profile table, and player profiles produced by `ProfileUtils.character_to_profile` appear structurally close to synchronized player profiles. The next prototype should hook `BotSynchronizerHost.add_bot` and substitute one profile.

4. Does the game separate visual profile from combat profile?

Partly. Profiles contain both `loadout` and `visual_loadout`. `ProfileUtils.pack_profile` removes those resolved tables for network packing but leaves `loadout_item_ids` and `loadout_item_data`, allowing clients to reconstruct. This suggests appearance/cosmetics and combat equipment can be handled separately if the mod deliberately edits only specific fields.

5. Can the mod safely assign cosmetics, weapons, talents, voices, and personalities?

- Cosmetics: likely, because `visual_loadout` is generated from loadout item data.
- Weapons: likely but risky; bot AI depends on weapon metadata. BetterBots has compatibility work for player weapons.
- Talents: uncertain. BetterBots notes vanilla bots normally have empty talents, but BetterBots custom profiles can use talent tables. More testing is required.
- Voice/personality: likely; profile fields include `selected_voice`, `voice_effects`, `gender`, and lore/narrative fields.
- Curios/equipment: likely as data, uncertain as useful bot behavior.

6. Are profiles retrieved from Fatshark servers, cached locally, or both?

Primarily backend/data-service retrieved. The source path calls backend character/progression endpoints and gear service. Presence also serializes character profile data for social display. There may be runtime caches inside data services, but the profile fetch itself is backend-oriented.

7. Will this work only in solo/private games, or also public empty slots?

Likely only local host/Solo Play/private local sessions. Public matchmaking uses dedicated servers, and host-side bot spawn authority is not in the client.

8. What happens when a human joins and replaces one of the custom bots?

Source-confirmed vanilla behavior removes bots on join/backfill changes through `PlayerUnitSpawnManager._on_client_joined`, `_num_available_bot_slots`, and `BotSynchronizerHost.remove_bot`. If this mod only changes profile tables passed to vanilla spawn, normal removal should continue working.

9. Are some classes, weapons, abilities, or talents incompatible with bot AI?

Yes. BetterBots exists because vanilla bot ability/weapon behavior is limited. It removes an ability whitelist, injects metadata, and adds heuristics/fallbacks. Human weapons without `attack_meta_data`, talent-dependent abilities, staves, plasma/charged shots, blitz items, and DLC archetypes need compatibility checks.

10. Is this entirely client-side, or does it require host authority?

It requires host authority to change bot profiles. The fetching/listing part is client-side. The replacement part must run where `BotSpawning` and `BotSynchronizerHost` are active as server/host.

## Existing Work

### BetterBots

Open source, MIT licensed. It improves bot ability use, weapon specials, targeting, pickup logic, and profile metadata in Solo Play. It includes custom bot profile templates and generated profile-authoring docs. It does not appear to provide an in-game account-character picker.

Relevant local files:

- `external/BetterBots/README.md`
- `external/BetterBots/docs/bot/profiles-spawning.md`
- `external/BetterBots/docs/bot/custom-profiles.md`
- `external/BetterBots/scripts/mods/BetterBots/bot_profiles.lua`
- `external/BetterBots/scripts/mods/BetterBots/bot_profile_templates.lua`

Best relationship: optional compatibility, not code copying. It may be better to output profiles compatible with BetterBots rather than duplicate BetterBots' behavior logic.

### Tertium 5 / Tertium 6

Nexus/public comments indicate these mods enable extra bots and/or use own characters as bots in Solo Play. Source was not found during this pass. Treat as closed-source unless permission/source appears. Do not copy.

Best relationship: study behavior via documentation and in-game testing only, or contact author for permission/source.

## Likely System Map

```text
Account characters
  -> Managers.data_service.profiles:fetch_all_profiles()
    -> backend_interface.characters:fetch()
    -> progression service
    -> gear service
    -> ProfileUtils.character_to_profile()
      -> account character profile table

Vanilla bot backfill
  -> PlayerUnitSpawnManager._handle_initial_bot_spawning()
  -> PlayerUnitSpawnManager._handle_bot_spawning()
  -> BotSpawning.spawn_bot_character(profile_name)
  -> ProfileUtils.get_bot_profile(profile_name)
  -> BotSynchronizerHost.add_bot(local_player_id, profile)
  -> ProfileSynchronizerHost.add_bot(local_player_id, profile)
  -> PlayerManager.add_bot_player(...)
  -> BotGameplay spawns player unit
```

Best prototype hooks:

- `Managers.data_service.profiles:fetch_all_profiles()` for Stage 2 profile discovery.
- `BotSynchronizerHost.add_bot` for Stage 2 single-profile substitution.
- Possibly `BotSpawning.spawn_bot_character` for earlier selection by profile name.
- Possibly `PlayerUnitSpawnManager._handle_initial_bot_spawning` only if slot-aware selection is needed.

## Proposed Mod Folder Structure

```text
CustomCharacterBots/
  CustomCharacterBots.mod
  README.md
  docs/
    feasibility-report.md
    test-plan.md
  scripts/mods/CustomCharacterBots/
    CustomCharacterBots.lua
    CustomCharacterBots_data.lua
    CustomCharacterBots_localization.lua
    profile_fetcher.lua
    profile_selector.lua
    bot_profile_substitution.lua
    compatibility.lua
    logging.lua
```

Current prototype includes the entry files, profile fetch/list logic, and a small opt-in one-bot substitution hook. The module split should happen before the substitution code grows beyond this test.

## Current Proof Of Concept

Implemented in `CustomCharacterBots/scripts/mods/CustomCharacterBots/CustomCharacterBots.lua`.

Capabilities:

- Adds `/ccb_profiles` chat command.
- Adds `/ccb_reset` chat command.
- Adds a DMF keybind action.
- Optionally fetches profiles after all mods load.
- Uses `Managers.data_service.profiles:fetch_all_profiles()`.
- Prints each visible saved profile's name, class/archetype, level, id, and current-character marker.
- Optionally hooks `BotSynchronizerHost.add_bot` and substitutes up to `max_bots_to_swap` profiles.
- Does not mutate saved profiles.
- Falls back to the original bot profile on substitution errors.

## Parts Requiring In-Game Testing

- Whether `fetch_all_profiles()` succeeds in hub, character select, mission lobby, and active mission.
- Whether account profiles returned during a mission include full gear/talent/cosmetic data.
- Whether `BotSynchronizerHost.add_bot` accepts a cloned account profile without additional normalization.
- Whether `ProfileSynchronizerHost.add_bot` name rewriting needs a hook to preserve saved character names.
- Whether non-bot player weapons need `bot_gestalts`, `attack_meta_data`, or BetterBots metadata injection.
- Whether clients can see substituted bot cosmetics/voice/name correctly.
- Whether a player joining mid-mission removes the custom bot without stale profile/package sync.
- Whether DLC archetypes require extra compatibility logic.
- Whether public/matched games block all substitution, as expected.

## Recommended Next Stage

Stage 2 should:

1. Install this prototype below `dmf` in `mod_load_order.txt`.
2. Run `/ccb_profiles` in the Mourningstar and in a Solo Play mission.
3. Add a temporary host-only hook around `BotSynchronizerHost.add_bot`.
4. Clone the first non-current profile and substitute it for exactly one bot.
5. Log every field changed or rejected.
6. Keep fallback to the original vanilla profile on any error.
