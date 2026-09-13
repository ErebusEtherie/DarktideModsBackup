STRIKEMAP - a real strikemap for Warhammer 40,000: Darktide
=========================================================

Renders the mission's actual walkable floor plan around you, with allies,
player pings, enemies, objectives, medicae stations (with live charge counts),
openable containers, loose ammo and grenades, ammo/medical crates, stimms,
and grimoire/scripture locations. Fixed missions use client-safe pre-baked
geometry; procedural expeditions compose known tiles and scan the client-baked
navigation mesh live, so both paths work as host or client.

FEATURES
- Real floor plans for all missions with Tactical Contours by default: a solid
  warm-bone active floor with crisp wall strokes, fine-lined lower decks,
  diagonal incline hatching on ramps, engraved stair ticks and smooth
  stair/elevator crossfades; classic filled tiers remain selectable and both
  styles work with every frame and the full-screen map
- Soft Light overlay: the map behind you rolls off into a gentle fade and a
  warm lamp glow surrounds your position - purely cosmetic, screen-anchored,
  never hides map data (toggleable)
- Live procedural expedition maps that rebuild as sections change; optional
  developer recording can capture reusable tile-local geometry
- 5 themes: Terminal (cogitator panel), Auspex (round radar),
  Clean Square, Clean Circle, Ghost (no frame at all)
- Enemies by category (horde/elite/specialist/monstrosity) with per-breed
  icon, colour and 50-250% scale overrides (43 breeds, 9 marker styles,
  39 colours)
- Optional Squad Sight / Your Sight marker visibility so enemies and map
  markers do not have to show through walls, with matching sight cones
- Teammates shown by class icon in their player-slot colours, with facing
  chevrons, health rings, downed-player distress pulses and attached badges
  for batteries, scriptures, grimoires and carried mission items
- Player pings mirrored as inward-pulsing rings in the pinging player's
  slot colour, with item icons for tagged pickups
- Mission objectives mirrored from the game's own markers
- Live tactical barriers for closed doors and objective-sealed paths: doors
  visibly converge when sealing, opened routes burn in from the centre, and
  recent changes remain highlighted with expanding scan pulses
- Objective areas flash ACCESS GRANTED or EXTRACTION OPEN as the game's own
  replicated objective markers activate; sealed paths flash ROUTE SEALED
- Medicae stations with remaining charges; typed icons for loose ammo,
  grenades, ammo/medical crates and stimms; openable loot containers;
  grimoire/scripture pickups (markers vanish when collected)
- Dedicated Items settings for per-category visibility and colours, including
  natural per-type or custom stimm colours
- Rotate-with-camera or north-up; zoom keybinds; 6 screen anchors
  (corners + top/bottom center) with fine X/Y offset sliders
- Mission Debrief archive in your Darktide AppData folder, with replay,
  favorite-protected runs and automatic retention for ordinary reports
- Performance tab for trading detail back for frames: enemy scan range and
  update rate, cheap or precise horde line-of-sight, minimap and full-screen
  map detail budgets, panel effects quality, ally status rate, Debrief autosave
  interval, per-hit combat stat tracking and burst timing diagnostics
- Versioned, zero-copy geometry API for compatible external minimap mods,
  with manual or automatic geometry-only mode
- English and Simplified Chinese (community-contributed zh-cn translation)

EXTERNAL MINIMAP INTEGRATION
Compatible mods such as Radar can render Strikemap's baked mission geometry
through the optional public API while Strikemap continues recording Mission
Debriefs. The full versioning, coordinate, spatial-index and lifecycle contract
is documented in COMPATIBILITY_API.txt. Integration controls are under the
Compatibility tab in Mod Options -> Strikemap.

CUSTOM HUD COMPATIBILITY
Custom HUD cannot safely transform StrikemapElement: StrikeMap combines direct
map geometry with normal HUD widgets, while Custom HUD only transforms the HUD
widget half. Add `StrikemapElement = true` to Custom HUD's
`_excluded_element_names` table, then position/scale StrikeMap with its own
Map Anchor, Offset X/Y and Map Size options. Both mods can then run together
without routes and icons separating or Custom HUD selecting a screen-sized box.

INSTALLATION
1. Install the Darktide Mod Framework + Mod Loader (see the Darktide
   modding community guides).
2. Extract this archive into your Darktide `mods/` folder so you have
   `mods/strikemap/strikemap.mod`.
3. Add `strikemap` to `mods/mod_load_order.txt`.

All options are under Mod Options -> Strikemap.

CREDITS
- Navmesh map data for most missions from FunkTheMonk's darktide-maps
  (github.com/funkthemonk/darktide-maps) - thank you!
- Remaining missions recorded in-game with this mod's own tooling.
