
---@class DarkLibHUD
---@field marker DLH_Marker

---@class DLH_Marker
---@field manager DLH_MarkerManager
---@field animate DLH_MarkerAnimateLib
---@field state DLH_MarkerState
---@field register_style fun(key: string, style: DLH_MarkerStyle | nil): DLH_MarkerStyle
---@field fire fun(key: string, opts: DLH_MarkerFireOpts): DLH_MarkerHandle | nil
---@field has_style fun(key: string): boolean
---@field remove fun(handle: DLH_MarkerHandle | nil): boolean
---@field is_active fun(handle: DLH_MarkerHandle | nil): boolean whether the handle still refers to a live marker; false after it aged out, was cleared, or the library was rebuilt by a hot reload
---@field clear fun(key: string | nil)

---@class DLH_MarkerHandle

---@class DLH_MarkerAnimateLib
---@field pop_fade fun(opts?: DLH_MarkerPopFadeOpts): DLH_MarkerAnimator library default: pop in, fade in/out, drift along the fan direction
---@field static fun(opts?: DLH_MarkerStaticOpts): DLH_MarkerAnimator pinned to the projected point; fades in, then holds
---@field distance_alpha fun(style: DLH_MarkerStyle, dist: number): number the shared alpha falloff, for use in a custom animator
---@field distance_scale fun(style: DLH_MarkerStyle, dist: number): number the shared size falloff, for use in a custom animator
---@field distance_ramp fun(dist: number, near_distance: number, far_distance: number, near_value: number, far_value: number): number the linear distance ramp both falloffs are built on

---@class DLH_MarkerAnimator
---@field update DLH_MarkerAnimateUpdate per-frame placement, scale and alpha
---@field spawn? DLH_MarkerAnimateSpawn optional fire-time hook for per-marker state

---@alias DLH_MarkerAnimateUpdate fun(marker: DLH_MarkerHandle, out: DLH_MarkerAnimOut, ctx: DLH_MarkerAnimCtx)

---@alias DLH_MarkerAnimateSpawn fun(marker: DLH_MarkerHandle, fire_opts: DLH_MarkerFireOpts)

---@class DLH_MarkerPopFadeOpts
---@field fade_in_time? number seconds spent fading in; shrunk proportionally with fade_out_time if the two exceed the lifetime
---@field fade_out_time? number seconds spent fading out; shrunk proportionally with fade_in_time if the two exceed the lifetime
---@field spawn_radius? number pixels from the projected point the marker starts at
---@field rise? number extra outward drift (pixels) over the marker's life
---@field pop_time? number seconds of the entrance scale "pop"
---@field pop_overshoot? number how far past 1 the pop overshoots
---@field near_distance? number lift markers spawned closer than this (metres)
---@field near_lift? number max upward lift (pixels) applied at zero distance
---@field fan_arc? number half-arc (deg) markers fan across (0 = straight up)
---@field fan_step? number degrees each successive marker steps around the arc
---@field reference_fov? number vertical FOV (deg) at which spawn_radius/rise are literal pixels; offsets are corrected for magnification away from it
---@field spread_near_distance? number metres at or inside which spawn_radius/rise are multiplied by spread_near
---@field spread_far_distance? number metres at or beyond which spawn_radius/rise are multiplied by spread_far; 0 disables the spread ramp
---@field spread_near? number offset multiplier at the near end of the ramp
---@field spread_far? number offset multiplier at the far end; above spread_near to push distant markers further apart

---@class DLH_MarkerStaticOpts
---@field fade_in_time? number seconds to fade in over
---@field near_distance? number lift markers closer than this (metres); 0 disables, so a style opts in
---@field near_lift? number max upward lift (pixels) applied at zero distance, ramping in as the marker is approached

---@class DLH_MarkerAnimOut
---@field offset_x number horizontal offset from the marker's projected screen point
---@field offset_y number vertical offset from the projected point (negative is up)
---@field scale number multiplier on every line's font size
---@field alpha number 0..1 opacity; <= 0 culls the marker for this frame

---@class DLH_MarkerAnimCtx
---@field animation DL_Animation shared easing/fade helpers (mod.dl.animation)
---@field dt number seconds since the last frame; prefer `elapsed` unless you need to integrate
---@field elapsed number seconds since the marker was fired
---@field duration number|nil the marker's lifetime, nil when the style is persistent
---@field progress number elapsed/duration, 0 when there is no duration
---@field dist_to_camera number metres from the camera to the marker's world position
---@field screen_x number the marker's projected x, before this animator's offset
---@field screen_y number the marker's projected y, before this animator's offset
---@field vertical_fov number the camera's vertical FOV in radians; scale screen-space offsets by it or they detach from their anchor when the view zooms

---@class DLH_MarkerStyle
---@field font? string engine font_type used to draw the marker text (per-line default)
---@field font_size? number per-line default font size
---@field color? number[] per-line default text color, ARGB
---@field lifetime? number seconds the marker lives (fade in -> hold -> fade out); ignored when persistent
---@field persistent? boolean marker never expires; lives until removed by handle or cleared (default false)
---@field animate? DLH_MarkerAnimator built by mod.dl_hud.marker.animate.*() (default: animate.pop_fade())
---@field world_lift? number metres to raise the marker above its anchor, applied to the world position before projection; stays pinned above the object at every distance, unlike a screen-space offset
---@field max_distance? number metres past which the marker is hidden entirely, 0 disables (every built-in animator)
---@field fade_in_distance? number metres, inside max_distance, over which the marker fades in as it is approached; clamped to max_distance
---@field scale_near_distance? number metres at or inside which the marker draws at scale_near (every built-in animator)
---@field scale_far_distance? number metres at or beyond which the marker draws at scale_far; 0 disables distance scaling
---@field scale_near? number scale at the near end of the ramp
---@field scale_far? number scale at the far end of the ramp; below scale_near to shrink with distance
---@field text_box_size? number[] bounding box passed to draw_text (height only; line widths are measured from the text itself)
---@field z_lift? number z added above the element's base draw layer
---@field z_layer? number extra z; higher-layer styles draw over lower ones
---@field shadow_alpha? number drop-shadow alpha (scaled by the marker's fade)
---@field shadow_offset_base? number base shadow offset (pixels)
---@field shadow_offset_font_scale? number additional shadow offset per unit font size
---@field background_color? number[] ARGB backing plate drawn behind the whole line block; unset means no plate
---@field background_padding? number padding (design px, all sides) between the line block and the plate edge
---@field line_gap? number default vertical gap (px) between stacked lines
---@field texture_size? number[] fallback { width, height } for texture lines without their own
---@field texture_color? number[] fallback tint for texture lines, ARGB (white leaves the material untouched)
---@field lines? DLH_MarkerLine[] stacked lines; omit for a single text line from the fired text
---@field max_active? number cap on simultaneously active markers from this style; transient styles evict the oldest, persistent styles refuse the spawn
---@field visible_fn? fun(marker: DLH_MarkerHandle): boolean per-frame predicate; false eases the marker out without removing it (unset = always visible). Reach per-marker state through `marker.data`
---@field visible_fade_time? number seconds to ease between hidden and shown when visible_fn is set; 0 snaps

---@class DLH_MarkerLine
---@field id? string|number key used to supply this line's content via fire opts (default: array index)
---@field texture? string material path, e.g. "content/ui/materials/icons/hud/radio"; makes this a texture line
---@field size? number[] texture line's { width, height } in design pixels (default: style.texture_size)
---@field font? string engine font_type for this line (text lines)
---@field font_size? number absolute font size for this line (text lines)
---@field color? number[] text color, or tint for a texture line, ARGB
---@field align? "left"|"center"|"right" horizontal alignment within the block width
---@field gap? number vertical gap (px) above this line, ignored on the first line
---@field shadow? boolean draw the drop shadow; defaults true for text lines, false for texture lines

---@class DLH_MarkerFireOpts
---@field world_pos? Vector3 fixed world position to anchor the marker to; ignored when `unit` is given
---@field unit? Unit unit to follow, re-read every frame; takes precedence over `world_pos`, and the last known position holds once it dies
---@field unit_node? string node name on `unit` to anchor to (e.g. "ui_objective_marker"); falls back to node 1
---@field data? any caller payload stored untouched on the handle as `marker.data`, for `visible_fn` to read
---@field text? string text for the first/only line (defaults to "")
---@field lines? table<string|number, string|DLH_MarkerFireLine> per-line text/overrides, keyed by style line id
---@field font? string font_type for the single-line (no style.lines) case
---@field font_size? number font size for the single-line case
---@field color? number[] color for the single-line case, ARGB
---@field align? "left"|"center"|"right" alignment for the single-line case
---@field lifetime? number override the style's lifetime (seconds); ignored when the style is persistent
---@field scale_mult? number scalar applied to the marker's scale
---@field alpha_mult? number scalar applied to the marker's alpha
---@field fan_dir_x? number override the fan direction x (paired with fan_dir_y)
---@field fan_dir_y? number override the fan direction y (paired with fan_dir_x)

---@class DLH_MarkerFireLine
---@field text? string this line's text (a text line is skipped if nil/empty)
---@field texture? string override the material path, or make this line a texture line
---@field size? number[] override a texture line's { width, height } in design pixels
---@field color? number[] override this line's color/tint, ARGB
---@field font? string override this line's font_type
---@field font_size? number override this line's font size
---@field align? "left"|"center"|"right" override this line's alignment

---@alias DLH_MarkerHudClassName "DarkLibHudMarker"