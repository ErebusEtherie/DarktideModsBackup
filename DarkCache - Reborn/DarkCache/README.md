# DarkCache

A mod for Warhammer 40,000: Darktide that stops the game rebuilding the same things over and over.

Two unrelated problems, two caches:

- **Item icons.** Open a vendor, scroll, walk away, come back: every icon is a spinner again. Nothing about those items changed — the pictures were simply thrown away when the screen closed.
- **The Mourningstar itself.** Leaving it releases the whole level and every package it depends on; coming back reads the identical set off the disk again, and you sit at a loading screen while it does. Same for the Psykhanium.

## Item icons

### What the game does

An icon is rendered by spawning the item — or a mannequin wearing it — in a hidden world, waiting a few frames for the pose and textures to settle, capturing the viewport, and copying the result into a slot of a shared texture atlas. The widget is handed the atlas and a slot index and samples it from then on. All of that happens **one icon at a time**, several frames each: that is what you are watching when a grid fills in.

When the last widget looking at an icon goes away, `unload_request_reference()` frees the atlas slot and deletes the request. Re-opening the screen replays the whole thing.

### What DarkCache changes

When the last reference to a **fully rendered** icon is dropped, the reference is detached exactly the way the engine would, but the request and its atlas slot are kept and the entry goes into a memory-bounded LRU list. Next time that icon is asked for, the engine finds the request already marked `spawned` and calls the widget back immediately.

That last path is not new: it is what already happens when two widgets show the same item at once. Nothing had to be taught to the widgets, and no icon is ever drawn differently from how the game would have drawn it.

Covers cosmetics, weapons, gadgets, weapon skins, trinkets, companion gear and player portraits.

### The budget is in bytes, and there is a size ceiling

An icon is never stored on its own. The engine allocates an atlas of **5×5 slots at once** and hands out one slot, and only destroys that atlas once every slot is free. So a cached icon pins a whole atlas, sized five times its slot in each direction.

That makes "number of icons" a meaningless budget, because the slot size is not a constant:

| Render size | Where | Atlas pinned |
|---|---|---|
| 128×128 | cosmetics, companion, appearance grids | 1.6 MB |
| 256×128 | weapon grids | 3.3 MB |
| 128×192 | character creation grid | 2.4 MB |
| 1024×1024 | win-track reward overlay | **104 MB** |
| 1400×1400 | character options portrait | **196 MB** |

So the cache is bounded by a **video memory allowance** (default 256 MB, adjustable from 32 MB to 2 GB), and **nothing larger than 256 pixels a side is cached at all**. 256 is exactly the widest grid format, so every high-volume grid stays eligible while the oversized one-offs are refused — they appear one at a time in views opened once, and a single one of them would eat the whole allowance and evict everything actually earning its place.

`/darkcache` reports what is held, computed from each entry's real render size with atlas granularity included.

### The cache lasts one stay

Every loading screen empties it. An icon cache is worth something for exactly as long as you stay in one place — opening the same vendor three times, switching tabs, scrolling back up. Crossing a loading screen ends that, and a reload of the Mourningstar after changing character may mean different icons entirely.

### Two measured side effects

`tests/bench_scroll.lua` walks a 400-item grid the way `ViewElementGrid` does and counts what the engine has to do.

**Atlas allocations go up.** Without the cache the engine recycles a handful of slots and allocates **2** atlases for the whole scroll; with it, **14**. Each is a `Renderer.create_resource` mid-frame. It converges — a later pass allocates one or none — and the memory held stays flat at the budget.

**An allowance smaller than the grid is worse than useless.** Walking a grid end to end is the pathological pattern for a least-recently-used cache: if the grid does not fit, every entry is evicted just before you come back to it, so a second pass hits 0% while still holding the memory. `/darkcache` shows the hit rate per family for exactly this reason.

CPU cost turned out to be a non-issue: the engine's linear scans grow with the cache, but the whole 400-item scroll measures within a millisecond or two of the unmodded run.

## Levels kept in memory

### What the game does

Every level transition goes through `LocalLoadersState.init`, which calls `cleanup()` then `start_loading()` on every loader. `LevelLoader.cleanup` releases the level's package and every item and theme dependency it pulled in; `BreedLoader` does the same for breeds. Nothing is kept, so the Mourningstar is read off the disk in full on every return.

### What DarkCache changes

It does **not** stop the engine cleaning up. It takes a reference of its own on those packages and never lets go.

That distinction is the whole design. `Managers.package` is reference counted, and `PackageManager.load` on an already-resident package simply queues the callback and returns. One extra reference is therefore enough to make the engine's next load resolve out of memory instead of off the disk, while the loaders keep running their normal cycle with their bookkeeping intact.

Suppressing `cleanup()` so the loader keeps its own references reaches the same place by editing the engine's accounting from underneath it, and a mistake there breaks loading itself. Adding references cannot: worst case it holds memory it should have released, and the game still loads.

Level units are still despawned and respawned normally. Only the disk read is skipped — the part you wait for.

### What it costs, and what it saves

Nothing in the engine reports the size of a loaded package, so the mod takes three readings around each level load and remembers them between sessions:

- **system memory** — `Memory.usage("B").used_memory`
- **video memory** — `Memory.vram_usage()`
- **load time** — `Application.time_since_launch()`, the game's own clock

The two memory readings are **independent totals from different allocators**: neither contains the other, so they are always reported side by side and never as a whole and its part. They are only kept from a *cold* load, since a warm one reads nothing and its delta would be noise. Load times are kept from both, which is what makes the saving computable — the options menu ends up saying "loads in 3.2 s instead of 18.5 s" for your machine rather than quoting someone else's.

Whether a load was cold or warm is decided by asking the package manager whether the level was already resident, not by consulting the mod's own bookkeeping: the loaders report in in an order the mod does not control, so anything derived from its own state can already have been touched for the transition being measured.

## Options

- **Video memory allowance** — the icon cache budget, 32 MB to 2 GB, default 256 MB.
- **Cosmetics / Weapons / Player portraits** — one switch per icon family.
- **Empty the icon cache now** — a keybind.
- **Mourningstar / Psykhanium** — keep each level in memory. Each states its measured cost once known.
- **Frames before capture** — how long an item settles before its picture is taken. 5 is the game's own value; lower is faster but can freeze an icon on a half-loaded texture.
- **Developer report** — enables `/debugdarkcache` and logs cache activity.

The level options state what they measured on your machine, and the group above them totals whatever is switched on. Those tooltips are refreshed the moment a measurement lands rather than at the next restart: DMF resolves a tooltip once at load and stores the string in `dmf.options_widgets_data`, which the options view rebuilds from every time it opens — so updating that string is enough.

Option values are persisted by DMF, so a changed default would never reach an existing install. Every change to what is held by default gets a version number in `DarkCache.lua` and is pushed on next load.

## Chat commands

- `/darkcache` — what each thing is costing: cosmetics, weapons, portraits and companion, then each level.
- `/darkcache_clear` — empty the icon cache.
- `/debugdarkcache` — the full picture per level and per icon family: system memory, video memory, cold and cached load times, and the saving. Only offered while the **Developer report** option is on; with it off the command is not registered at all.

## The hidden icon world is switched off between renders

This one has no option, because there is nothing to weigh: it is a straight correction that follows the master switch like everything else.

The game builds item icons in a hidden world. When there is nothing left to render it calls `world_spawner:set_world_disabled(true)` — but that function takes a second argument, `include_viewport`, and the engine does not pass it. So the world stops simulating while **its viewport stays active**, and the world goes on being drawn into its capture render target every frame for the rest of the session, however long ago the last icon was made.

DarkCache passes the second argument: the viewport is switched off once the queue is empty and back on before the next icon spawns, which happens several frames ahead of any capture, so nothing is ever photographed on a dead viewport.

## Implementation notes

- **Hooks are on `PortraitUI` and `WeaponIconUI`, not their shared base class.** Fatshark's `class(name, super)` **copies** the super's methods into the subclass at creation time; it is not a lookup chain. Hooking the base class after the fact changes nothing for either subclass.
- **Only the game's long-lived renderers are cached.** `Managers.ui._back_buffer_render_handlers` holds one per icon family for the session, and its key doubles as the channel name used for budgets and statistics. `ViewElementWeaponActions` and `EndPlayerView` spin up their own short-lived `WeaponIconUI` and are left alone.
- **Atlas slots are freed through the engine's own path**, and only after checking `get_atlas_render_target` — freeing a slot of an already-destroyed atlas blows up later inside the atlas generator's update.
- **A hot entry is never evicted.** Both the LRU bookkeeping and the release function guard against dropping something a widget is currently drawing.
- **Stale entries are dropped, not re-rendered.** When the game says an item changed, or render settings or resolution changed, the entry is released rather than re-queued, so the render queue is never spent redrawing something nobody is looking at.

## Tests

`tests/run.sh` exercises the mod outside Darktide with LuaJIT. The harness does not reimplement the engine: it loads the **real** `render_target_atlas_generator.lua`, `render_target_icon_generator_base.lua`, `portrait_ui.lua` and `weapon_icon_ui.lua` from the decompiled source and stubs only the GPU, the 3D world and the package manager. The request queue, the atlas, the reference counting and the capture cycle are the game's own, so a hook that drifts from the engine's semantics fails there.

The level cache gets the same treatment, since it is the part that cannot be tried out anywhere else: the real `level_loader.lua` is driven through the engine's own `cleanup` → `start_loading` → package callback → `is_loading_done` cycle, against a package manager stub that reference counts the way the real one does — a package is read from disk only if nothing held it, and leaves memory only on the last release.

Covered: a re-opened screen renders nothing; the byte budget evicts oldest-first and stabilises on whole atlases; an invalidated icon is dropped rather than re-queued; a request shared by several widgets is only cached after the last one; the mod switched off behaves exactly like the unmodded game; a full flush hands every atlas slot back; oversized formats are refused with the ceiling checked to the pixel (256×128 cached, 257×128 refused); and the reported memory counts whole atlases rather than occupied slots.

For the level cache: the Mourningstar stays resident through a mission while an ordinary level does not; returning to it reads nothing from disk, where a first visit read everything; and with the option off the level is released on the way out exactly as the unmodded game would.

`tests/bench_scroll.lua` measures what a grid scroll costs the engine with and without the cache.

---

Description: "Mod developed with Claude - Direction Ralendil"
