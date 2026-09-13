# Ritual Danger Zones

Tripwires on the mission path, a location marker with distance, and a completion countdown for
active Heinous Ritual sites (Havoc `mutator_havoc_chaos_rituals`). Client-side.

## 1.3.0

- Rituals trigger on main-path distance, not on how close you are to the daemonhost. The game projects
  the daemonhost onto the mission's main path, marks two points 30 m and 15 m back along it, and
  compares them against whichever player has pushed furthest. Crossing the first starts the ritual
  ticking, crossing the second sends it to full speed, and neither un-triggers. Those two points are
  now drawn on the path as tripwire rings.
- The on-screen warning runs off that same check instead of the local player's distance, so it fires
  when a teammate ahead trips the line. A new approach stage appears before the first point. Stages
  latch, matching the game.
- The warning and the marker no longer stack: while the warning is up it carries the distance and
  countdown itself, so a ritual draws one icon instead of two.
- The rings around the ritual site are off by default (carried to existing installs by a settings
  migration). They described a trigger radius the game does not use. Still available as a locator.
- Marker uses the game's Heinous Rituals circumstance icon by default, switchable back to the skull.
- Fixed an untriggered ritual showing the near-complete marker: the countdown reads the daemonhost's
  health as the ritual bar, and an untriggered daemonhost is at full health. This also un-broke the
  observed-progress check, which had been baselining from that full-health reading.
- Fixed warning while the team is still in the spawn safe zone, which the game does not allow.
- Fixed team progress being taken from the nearest path point to each player, which read as forward
  progress on maps that lock you in a room for an objective.

## 1.2.0

- Fixed the packaged ZIP storing Windows backslash path separators, which broke extraction on
  Linux and Proton.
- Throttled the detection and ring re-styling. This sharply cuts the mod's CPU cost. It was the
  heaviest mod in a typical load order (measured at over 2 ms/frame during an active ritual) and
  now holds Lua memory steady.
- Added a two-stage on-screen warning as you approach a ritual: an amber alert at 30 m and a red
  escalation at 15 m, with an off-screen direction arrow. Configurable size and text color, and it
  can be toggled, in the mod options.

## Rings

The rings are an optional site locator. They are ground decals centred on the daemonhost, drawn at
the two radii the game's thresholds are named after.

| Ring | Radius | What it shows |
|---|---|---|
| Start | 30m | where the 30m threshold sits around the ritual site |
| Speedup | 15m | where the 15m threshold sits around the ritual site |

The rings do not show the trigger. The game does not measure your straight-line distance to the
daemonhost. It projects the daemonhost onto the mission main path, puts one threshold 30m back along
that path and the other 15m back, and compares them against whichever player on the team has
advanced furthest along the path. The tripwires are what mark those two points, and they are on by
default. Both rings are off by default for that reason: they locate the site, nothing more.

Turn them on in the F4 menu if you want the site outlined. Both are magenta at 4% opacity and they
overlap inside 15m, so the inner zone is a denser magenta: the closer you are, the deeper the color.
Magenta because Darktide's palette is browns, greys and green, and the rings need to read as
something that is not part of the level. Color, opacity and per-ring visibility are all configurable.

**Ring projection depth** (default 0.1, applies to all rings) is how far the decal projects
vertically. At 0.1 the rings stay on the daemonhost's floor: they do not climb stairs and do not bleed
onto the floor above. Raise it if you want rings visible across floors, at the cost of color on walls.

## Credits
- Detection logic ported from **RitualZones** (Nexus 687) by **LAUR3HTE**, used with permission per its Nexus terms.
- Decal ring technique learned from **Danger Zone** (Nexus 440) by **LeicaSimile**. Uses the base-game decal via public engine APIs. No Danger Zone assets or code are included.
