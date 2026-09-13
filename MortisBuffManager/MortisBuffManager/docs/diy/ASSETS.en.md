# Local resources for independent entries

MortisBuffManager and HavocConditionManager expose the same asset API. Each entry keeps its JSON, Lua and resource files in its own package folder. Install SimpleAssets separately and load it before the manager when an entry uses external graphics. The adapter uses the SimpleAssets v2 interface; ordinary entries and `ctx:resource()` do not need it.

The manager validates declarations, prepares immutable resource copies, combines concurrent requests, gives fonts unique aliases and closes consumer scopes. SimpleAssets performs native loading. Its code, DLL and example media are not distributed here. This is a package integration layer, not a replacement native loader or a measured performance comparison.

## Declare and load an image

Copy `package-examples/lua-asset-mortis-example` or `lua-asset-conditions-example` to the matching manager's `diy/packages` directory. Each example has exactly one entry and a small original test image. Selecting it tests loading and writes a success/error to the log. It does not add a HUD or change gameplay stats. The image is a technical fixture, not finished UI artwork.

Set the package API minimum to 1 and add an asset declaration:

```json
"api": {"major": 1, "min_minor": 1},
"assets": [
  {"id": "badge", "type": "texture", "path": "resources/badge.png"}
]
```

Also list `resources/badge.png` in `files`. IDs are local to the package. Files must be declared with exact spelling under `resources/`; absolute paths, traversal, directory links and ambiguous native names are rejected. Asset types and lowercase extensions are checked before loading. A package may declare up to 64 assets. Cursor hotspots are nonnegative integers; the provider additionally verifies image bounds. An animation must declare its same-stem bones file.

In a script entry using `api_version = {major=1, minor=1}`:

```lua
on_activate = function(ctx)
    local handle, why = ctx:load_asset("badge", function(asset, load_error)
        if not asset then
            ctx:log(load_error)
            return
        end
        ctx.state.badge = asset.texture
        -- Use the ready texture in a compatible native UI material.
    end)
    if not handle then ctx:log(why) end
end
```

Callbacks receive `(asset, error)` and may run before `load_asset` returns when the resource is cached or a request fails immediately. A successful result is a fresh shallow table; editing it does not change the shared cache. Do not assume a pending handle is ready.

| Operation | Result |
| --- | --- |
| `ctx:load_asset(id, callback?)` | Handle, or nil/error for an invalid request. Repeated requests for the same ID share the binding's handle. |
| `handle:status()` | `pending`, `ready`, `failed` or `cancelled`, plus any error. |
| `handle:get()` | Ready result, or nil/error; never a half-loaded result. |
| `handle:cancel()` / `ctx:release_asset(id)` | Drop this consumer and suppress its callbacks. Other consumers continue. |
| release, then load again | Retry a failed request. Failures do not become permanent success-cache entries. |
| `ctx:on_cleanup(fn)` | Clean up native objects created by the entry before its asset scope closes. |

A missing provider or failed decode reports an error without removing separate JSON effects. A Lua error inside an asset callback stops that script binding and runs its cleanup. After removal, owner death, lost authority or mission finish, its pending callbacks cannot apply new effects. Synchronous errors and malformed provider results are contained too.

## Supported declarations

| `type` | Source | Ready value to consume |
| --- | --- | --- |
| `texture` | `.png`, `.jpg`, `.jpeg`, `.dds`, compiled `.texture` | `texture`; raster results may also include dimensions |
| `font` | Compiled `.slug` font | `font_type`, generated per resource to avoid global alias clashes |
| `video` | `.ivf` or `.bk2` | `resource_name` for a native video player |
| `mouse_cursor` | `.png` with `hotspot_x`, `hotspot_y` | `resource_name` |
| `slug_album` | Compiled `.slug` icon album | `resource_name` |
| `material`, `particles`, `unit`, `animation` | Matching compiled extension | `resource_name` |

These are adapters to the author's [resource API](https://github.com/deluxghost/darktide-mods/blob/main/SimpleAssets/docs/api/engine-resources.md) and [path/format contracts](https://github.com/deluxghost/darktide-mods/blob/main/SimpleAssets/docs/getting-started/paths.md). Engine assets must already be compiled for the installed game version. Copy required `.bones` and `.texture.stream` companions into `resources/` and declare them in `files`; they are preserved together. Embedded references inside compiled assets are not rewritten, nor are referenced dependencies automatically loaded. There is no FBX/Blender, TTF/OTF, MP4, MP3 or WAV conversion. Video support does not imply audio or alpha support. Global `replace_*` operations are outside this scoped API.

## Local views and client HUDs

Gameplay scripts retain their authority rules. A locally installed view or HUD can use resources on a client without starting a gameplay engine:

```lua
local manager = get_mod("MortisBuffManager") -- or HavocConditionManager
local scope, why = manager.diy_api.open_assets("my-entry-package")
if not scope then return end

-- Assume image_widget already has an image material accepting texture_map,
-- and its visibility function reads content.asset_ready.
scope:own(function()
    image_widget.content.asset_ready = false
    image_widget.style.image.material_values.texture_map = nil
end)
scope:load("badge", function(asset)
    if asset then
        image_widget.style.image.material_values.texture_map = asset.texture
        image_widget.content.asset_ready = true
    end
end)
-- Retain scope in the view; call scope:close("view_exit") before its teardown.
```

`open_assets(package_id, active_predicate?)` pins the current local library snapshot for that scope. A newly opened scope can see refreshed local files; existing scopes and running gameplay bindings retain their versions. A client scope is not proof that an entry was selected or that the host has the same files. It gives local resource access only. `scope:load`, `scope:release`, `scope:own` and `scope:close` use the same request and cleanup rules. A predicate returning false closes the scope during the manager update. Always close views explicitly, before destroying their widgets or renderer.

To play a loaded video, pass its `resource_name` to `UIRenderer.create_video_player` and register `UIRenderer.destroy_video_player` in `scope:own`. Unit and particle instances likewise need the corresponding native destroy calls. Restoring an applied cursor is the consumer's responsibility. Releasing a handle does not destroy a world object, video player or cursor created from it.

## Cache and lifetime

Startup and explicit library refresh prepare resources under:

```text
%APPDATA%/Fatshark/Darktide/mods/<Manager>/assets/diy-cache/<resource-hash>/
```

The original package remains under `<Manager>/diy/packages`. The cache contains resource bytes only. The content hash covers sorted resource paths, bytes, companions and typed loading parameters. Changing a cursor hotspot therefore creates a new native identity even if its PNG is unchanged. Identical resources reuse a directory even when Lua or package metadata changes. Existing copies are verified, never overwritten. No package scan, copy or hash occurs in an asset request; the provider reads/decodes on first load. Prefer requesting resources during activation or view entry, then keep the handle.

Changing a source while playing leaves the active mission's copy intact. Refreshed bytes get a new cache directory and native identity. Mortis room fingerprints still include the manifest, Lua, resources and dependency closure. No resource bytes, code or consumer handles are sent over the network.

Each manager permits 256 open scopes, 256 cached or pending native resource records, 16 waiting callbacks per handle and 64 owned cleanup callbacks per scope. Pending requests fail after 35 seconds of manager update time. Disk staging is limited to 128 MiB and 256 generations; existing package/file limits still apply. These are bookkeeping/source-storage bounds, not a GPU-memory budget. Compiled resources and decoded textures can consume more memory than their source files.

The audited provider has no general per-resource unload API. Ready native results are reused for the process lifetime. Closing consumers cancels their callbacks and runs registered cleanup; it does not promise to free native texture/font/resource allocations. Cache files are kept because videos may continue reading them. If the generated cache is full or altered, exit the game, delete only this manager's `assets/diy-cache` directory shown above, then restart. Never delete the source `diy/packages` folder as cache cleanup. Restart after changing or reloading SimpleAssets.

## Verification

Offline checks exercise all nine provider call signatures, real isolated Windows Unicode cache IO, companion files, content changes, tamper refusal, disk/request limits, shared loads, retries, timeouts, cancellation and callback errors. Both actual manager factories are tested for mission freezing, client-local scopes and optional-provider fallback. Native loading is simulated at that boundary. Actual game rendering, compiled-asset compatibility and multiplayer visual acceptance still require in-game checks; they are not claimed by these tests.
