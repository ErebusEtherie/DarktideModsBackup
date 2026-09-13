# Changelog

## v2.1.6

### Features

- **Hide Cinematic Black Bars** — New checkbox (off by default) that removes the letterbox black bars shown during mission intro/outro cinematics and other in-game cutscenes. The bars are stripped at HUD-build time, so the element is never created and the option has zero per-frame cost. Everything else about cutscenes is unchanged. Localised in English, Chinese and Russian.

### Bug Fixes

- **HUD no longer self-destructs on a partial mod file** — If the customizer's element file could not be fully read when the HUD was being built (typically: reloading mods while the mod files were still being copied into the game folder), the game's HUD builder would crash on the broken module and take the entire HUD down with it. The mod now verifies the file actually loads before handing it to the HUD builder — at both HUD-build entry points — and, as a last line of defence, skips only its own element inside the game's element constructor. A broken load now costs you the customizer for that session (with a clear error message telling you to reload) instead of the whole HUD.
- **HUD rebuild can no longer crash with the old HUD already destroyed** — The pre-rebuild check that strips unloadable third-party elements now also catches modules that load to an invalid value (not just modules that are missing), so the rebuild can't throw after the old HUD is gone.

### Performance

- **Element hide hooks moved from instances to classes** — The draw hook that suppresses right-click-hidden elements is now installed once per element *class* instead of on every element *instance*. The mod framework never releases instance hooks, so each hooked instance — and its widgets, renderer and engine handles — was retained for the rest of the session; rebuilt HUDs (every mission/hub transition and every mods reload) piled those dead copies up over time. Class tables are permanent anyway, so the new scheme retains nothing extra, survives hot reloads correctly, and hidden elements can no longer "come back" after a mods reload.

## v2.1.5

### Features

- **Editor box colours** — The edit-mode overlay box of every HUD element is now fully themeable. Independent colours for the **fill** and each of the four **borders** (top / bottom / left / right), each with its own **default / hovered / hidden / hidden-hovered** state and a separate transparency slider. Colours are picked from the engine palette (`Color.list`). Live-tracks element resize and animates on hover.
- **Colourised colour dropdowns** — Every entry (and the selected value) shows the colour name drawn *in that colour*, so the palette is pickable by sight. Uses `{#color()}` text markup — works with **or without** Alf's DMF Extensions, no add-on dependency. Names are title-cased ("Blue Violet"); very dark colours are floored to a readable shade in the list only (the applied HUD colour is unchanged).
- **Settings reorganised into tabs** — Options are split into a **General** tab and a **Colors** tab, each declaring an explicit `tab` field so Alf's DMF Extensions tabbed settings render them on their own pages (no positional drift / overlap). The Colors tab is further grouped into Box Fill and the four border sections.

### Changes

- **Settings-page description trimmed** — The keybind legend is no longer duplicated in the mod's settings description (the in-editor Controls legend and the keybind tooltip cover it). The description now shows the author credit.
- **Author** — Now maintained by **Sungrief**.

### Notes

- Colour/alpha changes rebuild the HUD so the new values apply immediately (the overlay-box styles capture the colour tables by reference at build time).
- Graft preserved all existing optimisations: lazy opacity draw-hooks, the single-pass position re-pinning system, and the plain `mod._opacity` fast path. The colour cache is additive.

## v2.1.2

### Features

- **Snap to Elements** — New magnetic snapping system that aligns dragged elements to nearby HUD element edges and centers (min-min, mid-mid, max-max, min-max, max-min). Toggled via settings checkbox or `/snap_to_elements` command. Respects the same Ctrl-to-invert logic as grid snapping.
- **Tactical Overlay sub-node support** — `HudElementTacticalOverlay` is no longer globally excluded. Its `background` and `canvas` scenegraphs are excluded individually, allowing other sub-nodes to be repositioned. Hide/visibility toggling correctly skips tactical overlay sub-nodes to avoid blanking the whole overlay.
- **Allowlist filtering** — Added `_allowed_scenegraphs_by_element` table to optionally whitelist specific sub-nodes per element (currently empty, ready for future use).
- **`ConstantElementExpeditionContinue`** removed from exclusion list — now customizable.

### Bug Fixes

- **Saved coords reopen fix** — Node setup now resolves position from `node_settings.position` or falls back to `{x, y, z}` fields, then merges with live `world_position`/`position` from the scenegraph. Fixes nodes losing their saved coordinates when the customizer is re-initialized.
- **Reset node preserves curated defaults** — `reset_node` no longer nils out the saved entry and forces a full rebuild. Instead it writes default values back into the existing settings and calls `_apply_node_settings_live`, preserving any custom default targets for composite/background nodes.
- **Alignment pinning** — Edit-mode overlay boxes now always use `top`/`left` alignment regardless of native node pivot. Native pivots are preserved in `default_settings` for reference but no longer cause boxes to jump or disappear during editing.
- **Persist normalization** — `_persist_saved_settings` now canonicalizes all nodes before saving: syncing `x/y/z` ↔ `position` array, stripping stale alignment fields, and clamping size components. Prevents desync across save/load cycles.
- **`_apply_node_settings_live` nil safety** — Defaults `x/y/z` to `0` and rebuilds the `position` array before applying, preventing nil propagation from partial settings.
- **`_init_node_settings` snapshots live box** — First-time init now captures the currently resolved scenegraph position/size (which may already have been moved by the game or other mods) rather than the authored definition. Makes reset behavior match what the user actually started with.
- **Tactical overlay hide safety** — `_process_widget_press_right` and `_apply_saved_node_settings` now skip setting `_is_hidden` on tactical overlay sub-nodes to prevent blanking the overlay.

### Performance

#### pcall Elimination

- **`_safe_draw_text` detect-once** — Was creating 6 closures + running up to 6 `pcall`s per invocation (~30+ calls/frame when panel visible ≈ 180 pcalls/frame). Now probes once on first call, then direct-dispatches via cached variant index. Zero pcalls after first text draw.
- **Keyboard button index cache** — `_panel_take_key` was doing 1–2 `pcall`s per key per frame during text editing. Now pcalls once per unique key name ever, caches the result (including negatives). Shared by `is_shift_held`, `is_alt_held`, `is_ctrl_held` which were previously calling uncached `kb.button_index()` multiple times per frame.

#### Allocation Elimination

- **`_get_panel_metrics` pooled** — Was allocating a 9-field table per call (2–3×/frame). Now writes into a single pooled table. Replaced per-frame `mod:get("panel_scale")` / `mod:get("panel_list_rows")` with cached locals refreshed on settings change.
- **Element snap zero-alloc** — Replaced `_element_snap_candidates` (allocated a 5-entry table-of-tables per axis per other-node during drag) with `_best_snap_axis` that returns values directly.
- **Hoisted static tables** — `_digit_keys`, `_minus_matchers`, `_period_matchers`, `_field_rows`, `_active_field_bg_color`, `_current_map_pool`, `_default_map_pool` moved to module scope from per-frame recreation inside `_handle_panel_text_input` and `_draw_info_panel`.
- **Hoisted closures** — `_prepare_buffer` and `_append_char` extracted to module-level functions from per-frame closure allocation during text editing.

### Code Quality

- Fixed forward-reference ordering for `_cached_panel_scale` / `PANEL_SCALE_DEFAULT` upvalues.
- Localization and settings data updated with `snap_to_elements` entries.
