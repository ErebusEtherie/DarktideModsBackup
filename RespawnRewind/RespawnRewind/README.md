# Respawn Rewind

A client-side Darktide (DMF) mod. While a teammate is dead or awaiting respawn, it marks where they
will respawn and the point on the path to stay behind to pull that respawn to a closer beacon. Purely
local and client-reliable: it reads only client-available data (respawn beacon units, the main path,
player state), so it works in a live mission. Darktide runs missions on dedicated servers, so
every player is a client and nobody is the server except in solo play.

## What it shows (only while a teammate is down/dead)

- **Respawn marker** (light blue, through walls): the beacon where a dead teammate will respawn, with
  distance. It is computed from the game's own selection rule (the nearest beacon far enough ahead of
  the furthest-ahead living player), so it is correct in a live mission, not only under solo play.
- **Hold-back marker** (green, through walls): the main-path point the living players should stay
  behind to pull the respawn to the nearest earlier beacon. When the active beacon is already the
  earliest one, no hold-back marker is shown (there is nothing earlier to pull to).

## Settings (F4 mod menu)

Enabled, Show run-back point, Safety margin, Map practice (show the layout, the points, the lines, the
numbering), Marker size, Markers through walls, Show distance on markers, Marker icon.

## How it works

Dead players respawn at a beacon the game picks by main-path distance: the nearest beacon at least 25m
of path distance ahead of the furthest-ahead living player. The mod reads the beacon units and the main
path on the client and applies the same rule, so its marker matches what the game will do. Holding the
party back lowers that furthest-ahead distance, which can pull the respawn to an earlier beacon; the
hold-back marker is the line to stay behind for that.

Three details of the game's rule that are easy to miss, all confirmed against
`respawn_beacon_system.lua`:

- **The choice is latched, not recomputed.** `fixed_update` reads
  `self._priority_respawn_beacon or self._current_active_respawn_beacon` and only calls
  `_find_optimal_beacon` when both are nil. Once a respawn has happened the beacon is frozen for the
  rest of the episode. The mod latches the same way and clears on its own episode boundary, because the
  game's clear signal (hogtied player count reaching zero) covers a different population than the
  awaiting-respawn players this mod tracks.
- **There are two rules, chosen by path type.** `_find_optimal_beacon` branches on
  `Managers.state.main_path:path_type()`. Only `"linear"` uses the main-path rule above; anything else
  uses `_find_nearest_beacon_with_distance`, which takes the beacon closest to the midpoint of the
  living squad in a straight line. `path_type` is a plain getter with no server gate, so it is readable
  here. On a non-linear path there is no point on a route to stand behind, so no hold-back marker is
  drawn.
- **Safe-zone beacons are matched, not excluded.** The game compares each beacon's `safe_zone()` against
  the system's `_safe_zone_spawn` flag, which the scripted safe-zone sections flip.

All main-path math goes through `MainPathQueries` (an `EngineOptimized` query registered on every
client). The `MainPathManager` methods (`ahead_unit`, `travel_distance_from_position`) are dead on
clients: they depend on nav spawn points that only the server builds, and Darktide missions run on
dedicated servers. The furthest-ahead distance is computed locally by projecting every living player
unit onto the path and taking the max.

### Known blind spot

`_priority_respawn_beacon` overrides everything when a mission forces a specific beacon, but
`make_respawn_beacon_priority` opens with `if not self._is_server then return end`, so on a client it is
always nil. A scripted section that forces a beacon will be mispredicted and there is no client-side
signal that it happened.

## Notes

- Refresh cadence is about 0.3s. Markers clear on rescue/respawn and on mission end.
- **Markers always draw through walls. The "Markers through walls" checkbox cannot turn that off.**
  The through-wall behaviour is real and has always worked; it is the off switch that is inert.
  `template.check_line_of_sight` only makes the HUD queue a raycast (`hud_element_world_markers.lua:441`);
  the result is written to `marker.raycast_result` and the HUD never acts on it, since `marker.draw` is
  decided independently and `_draw_markers` consults only scale and fade. A template has to read
  `raycast_result` itself to hide a blocked marker, the way `world_marker_template_interaction` does at
  its line 742. This template does not, and neither does RitualDangerZones. So unticking the box changes
  nothing on screen. Either wire it up or drop the checkbox; left alone in 1.4.0 because the default is
  the behaviour everyone wants and the fix is untested.
- World markers are hidden while the F4 mod menu is open (DMF registers its view without `allow_hud`,
  which fails the `in_view` visibility group). A settings change lands on the first frame after the menu
  closes, never while the menu is up. Worth knowing before concluding a marker setting is dead.
- No pacing prediction, no path drawing, no offline cache, no line rendering. Through-wall world
  markers only (the cross-floor, death and spectator safe primitive).
- **Client-side and non-cheat.** This is a publish candidate, unlike the through-wall enemy mods.

## Changelog

- **1.4.0**: Marker size and the new marker icon setting now reach markers that are already on screen.
  Both were read once, at marker-add time: the template bakes its size into the widget when the marker
  is created, and the base HUD only resizes a template that declares `scale_settings`, which this one
  does not. The icon was captured into `marker.data` at add time and the refresh paths updated text and
  colour but not icon, while the practice set was rebuilt only when its own toggles changed. So the
  slider and the dropdown moved and nothing on screen did. Both values now travel through `marker.data`
  every tick, and the template applies them to the live widget whenever they differ. Added the icon
  setting itself (seven choices, every path taken from a shipped world-marker template rather than
  guessed) and lowered the size floor from 24 to 8.
  The safety margin is now visible when it changes. Position markers box their world position at
  add-time and cannot be moved afterwards, so the hold-back marker, keyed only by the beacon it belongs
  to, took the refresh path on a margin change and kept its old position while only its label moved. It
  is now keyed by the line's distance along the path as well, compared with a half-metre tolerance so
  float noise cannot re-add it every tick and flicker it. The practice lines ignored the margin
  entirely, drawing the raw computed threshold while the mod steered to a different one; they now carry
  the same margin, and the margin is part of the practice signature so changing it re-places the set.
  That makes practice mode the place to tune the margin, since it is on screen while you walk the map
  instead of only while somebody is dead.
  Stopped treating a backfilled bot as a dead player. A bot that replaces a leaver has a player entry
  before it has ever spawned, which through the unit-based inference looks identical to a teammate
  awaiting respawn, so the markers came up for a player who had not died and stayed up until the slot
  was filled by a human. Awaiting-respawn now requires having seen that player alive at least once this
  mission.
  Also logs one line per respawn comparing the predicted beacon against the one the game actually used,
  with the margin that would have reconciled them. Twelve samples so far say a single margin cannot: the
  error is per-beacon geometry, from projecting onto the nearest point of the whole route where the game
  projects onto the one path segment owned by the navmesh group a position sits in. Rebuilding those
  groups client-side is the real fix and is not in this release.
- **1.3.1**: Stopped wrapping `HudElementWorldMarkers.update` to re-register the marker template. That
  hook ran every frame and called through to the base update, which walks every world marker the game
  and every other mod has registered, so a profiler charged all of it to this mod. Reported on Nexus as
  0.7ms/frame while the mod's own per-refresh work measures about 25 microseconds (`rr_perf`). Whether
  it appeared at all depended on load order, since a monitor can only wrap hooks from mods that load
  after it. Now hooks `_template_by_type`, which the game calls at marker-add time, costs nothing per
  frame, and is a stronger guarantee than the update hook was.
  Added a run-back safety margin setting, **defaulted to 0**. Our beacon distances cannot match the
  game's: `PathTypeLinear._information_from_position` projects onto the segment belonging to the nav
  spawn-point group a position sits in, and `nav_spawn_points()` is server-only, so the fallback is an
  unconstrained `closest_position` that lands further along. Measured 146.1 against a game value of at
  most 138.9 on one map. The margin subtracts from both the selection threshold and the hold-back line
  from one place, so the marker and the prediction cannot disagree. Left at 0 pending a measurement
  across more than one map.
- **1.3.0**: Added the map-practice layout: every respawn point and the line that governs it, shown at
  once, off by default, with toggles for the points, the lines and the numbering. Placed once per
  mission and never refreshed, so it costs nothing per tick.
  Fixed the run-back point being wrong where the route runs wide. Progress was credited only when a
  player was within `ON_PATH_MAX_OFFSET` of the route centre, and past the first beacon on one map that
  offset reads 22m, so progress froze at 91.4 while the player walked on to 127.0. The mod then fed a
  stale distance into the beacon rule and predicted a nearer respawn than the game chose. A projection
  is now believed if it is near the route OR continuous with the last credited value (within
  `MAX_STEP`), which keeps the objective-room protection intact because that failure is a jump, not a
  drift. Verified against two missions: predicted beacon 2 with a downed bot holding the team's
  furthest-ahead position, predicted beacon 1 once the living bot followed the player back, and the
  game agreed both times.
- **1.2.1**: Corrected the 1.2.0 latch. `fixed_update` reads
  `self._priority_respawn_beacon or self._current_active_respawn_beacon` before calling
  `_find_optimal_beacon`, which reads as a latch for the whole respawn, but a few lines later in the
  same tick `_update_hogtied_players` clears `_current_active_respawn_beacon` whenever the hogtied
  count is zero. So the hold survives only while somebody is hogtied; an ordinary death re-picks every
  tick from the live ahead-distance, and that live re-pick IS the hold-back mechanic. 1.2.0 froze it.
  The latch is now conditional on a hogtied player, read from the same replicated `character_state`
  component as `dead`. Also: the hold-back marker now reports a signed offset against its line with a
  switching label ("Run back | 29m" past it, "Stay behind | -12m" behind it), since the old label read
  as an instruction to travel when it was really slack. Awaiting-respawn is detected from
  `character_state.state_name == "dead"` rather than waiting for the player unit to disappear.
- **1.2.0**: Matched three parts of the game's beacon rule the mod was missing, all read from
  `respawn_beacon_system.lua`. The chosen beacon is now latched for the respawn episode instead of
  recomputed every tick: the game reads
  `self._priority_respawn_beacon or self._current_active_respawn_beacon` and only re-picks when both
  are nil, so recomputing walked the marker forward while the game stayed put. `path_type` is now
  honoured, because `_find_optimal_beacon` uses a different rule entirely on non-linear paths (nearest
  beacon to the midpoint of the living squad, no main path involved) and the mod had been applying the
  linear rule everywhere. Safe-zone beacons are matched against the system's `_safe_zone_spawn` flag
  rather than excluded outright, which is what the game does. `rr_beacons` now reports `path_type`,
  `safe_zone` and `latched`. Verified in a live run: team progress advanced from 84.8 to 189.1 while
  the marked beacon held at 146.1.
- **1.1.1**: Fixed the predicted beacon jumping forward early on maps with a locked objective room.
  Team progress was taken by projecting each player onto the nearest point of the main path, which
  answers "which bit of the route is closest to you", not "how far have you got". An objective room
  sits off the route, so a player inside one projects onto whatever path point is nearest, often well
  ahead of where they have actually reached. The game does not advance there, so the mod disagreed
  with it. Progress is now only credited when the player is demonstrably near the path, holding the
  last trusted position otherwise.
- **1.1.0**: Fixed the mod doing nothing in live missions. 1.0.0 read main-path distances through
  `MainPathManager` (`ahead_unit`, `travel_distance_from_position`), which silently return nil on
  clients because their nav-spawn-point inputs are server-only. Since live missions run on dedicated
  servers, the mod only ever worked under SoloPlay, which is how it passed testing. All main-path
  math now goes through the client-safe `MainPathQueries`, and the furthest-ahead distance is
  computed locally from living player positions. Also fixed a finiteness guard that accepted nil.
- **1.0.0**: Initial build.

## Credits

The respawn beacon model (beacon fields, the ahead-distance selection rule) was understood by reading
**RitualZones** (Nexus 687, LAUR3HTE). Implementation is original and built on the game's own systems.
If ever published, credit LAUR3HTE, check Nexus permissions, and consider a courtesy note (the same
gate as RitualDangerZones).
