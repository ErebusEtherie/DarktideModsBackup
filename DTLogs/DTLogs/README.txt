DTLogs v0.13.40 - authoritative buff state-setter capture

- Keeps the startup-safe DMF hook_require() resolution from v0.13.39.
- Adds direct hooks for PlayerUnitBuffExtension._set_proc_active_start_time, _set_start_time_from_rpc, and _set_extra_duration_from_rpc.
- Canonical proc/start-time/extra-duration events are now emitted after Darktide has actually mutated the live buff instance instead of relying only on the network delegate entry point.
- Keeps the base RPC hooks as capability/compatibility probes and avoids duplicate analytics events.
- Preserves predicted lifecycle capture, exact raw/effective stack semantics, batching, talent/owner attribution, and zero per-frame buff polling.
- buff_capture_semantics_version: 7.

DTLogs v0.13.39 - startup-safe buff hook resolution

- Fixes a startup-blocking circular require introduced in v0.13.38.
- Never original_require()s buff_extension_base/player_unit_buff_extension during mod load.
- Uses DMF hook_require() to receive the module-local class table only after Darktide finishes its own require.
- Keeps the v0.13.38 proc/stack/start-time/extra-duration/predicted lifecycle hooks, but installs them safely when their modules become available.
- buff_capture_semantics_version: 6.

DTLogs v0.13.38

Buff lifecycle hook-resolution fix:
- `hook_if_present()` now falls back to Darktide's actual returned class tables via `mod.original_require()` for `BuffExtensionBase` and `PlayerUnitBuffExtension`.
- Hooks are installed directly on the resolved class table instead of depending on the global `CLASS` registry.
- This is intended to make the stack RPC, proc activation, start-time, extra-duration, and predicted lifecycle hooks visible in live Darktide builds where v0.13.37 reported them as unavailable.
- Buff capture semantics version is now 5.

DTLogs v0.13.37

Buff RPC target + predicted lifecycle follow-up
- Hooks inherited buff RPC handlers on `BuffExtensionBase`, where Darktide actually declares `rpc_add_buff_with_stacks`, `rpc_remove_buff_stacks`, `rpc_buff_batched_proc_set_active_time`, `rpc_buff_set_start_time`, and `rpc_buff_set_extra_duration`. v0.13.36 checked those methods on the subclass table and therefore reported them unavailable.
- Base-class RPC hooks are gated to the local player buff extension, so minion/husk buff traffic is not added to the detailed player-buff log.
- `player_buff_proc_activated` now includes activation time plus sampled active-start time, active duration/end time, proc count, and active-state when the live buff instance exposes them.
- Predicted-buff capture now uses lifecycle callbacks (`_on_add_buff`, `_on_add_buff_stack`, `_on_remove_buff_stack`, `_on_remove_buff`) instead of the more brittle private `_add_predicted_buff` / `_remove_predicted_buff` entry points.
- Predicted lifecycle events preserve raw/effective stacks and also include duration, start time, proc timing/count state when available.
- `buff_capture_semantics_version = 4`. No remote-player polling was reintroduced.

DTLogs v0.13.36

Exact effective-stack semantics follow-up
- Fixes `effective_stack_count_after` on buff removal. v0.13.35 used `min(raw_stack_count, max_stacks)`, but Darktide actually computes stat stacks as `clamp(raw_stack_count + stack_offset, 0, max_stat_stacks or max_stacks or 1)`. This mattered for buffs such as `zealot_quickness_counter`, whose `stack_offset = -1`.
- Add batches now include `effective_stack_count_before` as well as the exact post-add value sampled from the live buff instance. Buff batch schema is now version 3.
- Batched stack removals and predicted-buff removals use the same Darktide stack semantics instead of the old simplified clamp.
- Mission metadata now includes `buff_capture_semantics_version = 3` plus `buff_hook_capabilities`, so a test log can distinguish “this hook exists but no event occurred” from “the method was not available in this game build”.
- Keeps the v0.13.35 event-driven design: no per-frame remote buff polling, actual raw/effective stacks, duration/start-time metadata, talent attribution, owner attribution, batching, and predicted-buff hooks.

DTLogs v0.13.35

Buff lifecycle state follow-up
- Replaces the misleading v0.13.34 per-instance `stack_count` (which was only the number of server indexes carried by that RPC) with real buff-instance state: `added_stacks`, `stack_count_before`, `stack_count_after`, `effective_stack_count_after`, `max_stacks`, `max_stacks_cap`, `duration`, `extra_duration`, and `game_start_time`. Buff batch schema is now version 2.
- Resolves network `server_index` through PlayerUnitBuffExtension `_buff_index_map` before reading the actual buff instance. This also improves template discovery from live instances.
- Removal entries now include stack counts before/after removal and effective stack counts, so the backend can reconstruct a true stack timeline.
- Adds local predicted-buff lifecycle capture through `_add_predicted_buff` / `_remove_predicted_buff`. These buffs do not travel through `rpc_add_buff`, so v0.13.34 could not see them. Predicted add/stack/remove events include actual stack state and timing metadata.
- Normalizes Darktide's `from_talent = n/a` sentinel to `talent_id = null`, `talent_name = null` in serialized add batches while preserving `from_specialization` for compatibility.
- Keeps remote-player buff polling disabled. Detailed teammate buff state is not exposed by PlayerHuskBuffExtension; this build remains authoritative for the local player's replicated/predicted buff timeline and records source-owner attribution when the server supplies it.

DTLogs v0.13.34

Detailed player-buff RPC logging
- Fixes the PlayerUnitBuffExtension `rpc_add_buff` hook signature for Darktide 1.12.x by restoring the missing `owner_unit_id` argument. In v0.13.33 all arguments after `server_index` were shifted while being logged.
- Preserves the actual `from_talent` network lookup ID and resolves it through `NetworkLookup.archetype_talent_names`; buff add events now emit `talent_id` and `talent_name`. `from_specialization` remains only as a legacy derived boolean for older parsers.
- Adds event-driven capture for `rpc_add_buff_with_stacks` and `rpc_remove_buff_stacks`, so batched stack additions/removals no longer disappear from the JSONL timeline.
- Adds `player_buff_start_time_changed`, `player_buff_extra_duration_changed`, and `player_buff_proc_activated` events from Darktide's dedicated buff RPCs. This allows the website to reconstruct refreshes, duration extensions and proc windows without polling every frame.
- Remote buff probing remains disabled. This build records the PlayerUnitBuffExtension state that Darktide actually replicates to this client; it does not claim to expose server-only buff state for every teammate.

DTLogs v0.13.33

Successful-mission upload outcome hotfix
- Fixes successful missions being saved locally but skipped by the default `Successful missions only` upload policy.
- Real Darktide mission completion from `GameModeManager._set_end_conditions_met` reports victory as `outcome = "won"`, not `"success"`. v0.13.29-v0.13.32 incorrectly checked only for `"success"`.
- The successful-mission filter now treats `won` as success and keeps `success` as a compatibility alias for older/synthetic fixtures. `lost` and other non-winning outcomes remain local-only when the default policy is selected.
- This does not change mission completeness detection: `mission_recording_status` / `recording_complete_to_mission_end` remain separate recording-quality fields.
- Existing account linking, startup status messages, silent retries, and local JSONL retention are unchanged.

DTLogs v0.13.32

LuaJIT compiler-limit hotfix
- Fixes the startup failure `attempt to call local 'func' (a nil value)` seen after v0.13.31.
- Root cause: the large DTLogs.lua chunk crossed Lua/LuaJIT's 200-local-variable compiler limit after the v0.13.29 upload-policy/account-menu helpers were added. DMF then received no compiled function and failed while loading the mod script.
- Moves the new upload-policy, startup-status, and account-menu helpers onto the DTLogs mod table instead of creating additional top-level locals. Runtime behavior is unchanged.
- Keeps the v0.13.31 DMF-safe dropdown settings hotfix, successful-missions-only default, startup status messages, linked uploads, silent retries, and existing saved account key.

DTLogs v0.13.31

DMF Mod Options compatibility hotfix
- Fixes the startup error where older DMF builds interpreted the new `text_input` account-status widget as a keybind and rejected it because `keybind_trigger` was missing.
- Removes both `text_input` widgets from DTLogs Mod Options so the settings panel can initialize on the installed DMF version.
- Account connection status is now shown with a standard dropdown (`Linked` / `Not linked`) and is informational; changing it manually is immediately reverted to the real saved-key state.
- Account linking remains fully available through `/dtlogs_link <upload-key-or-link>`. A new Mod Options action prints that command/instructions into chat. Both raw `dtl_up_...` keys and copied text/links containing the key are accepted.
- The disconnect confirmation dropdown remains available in Mod Options and still warns that the key must be entered again to reconnect.
- Upload policy, successful-missions-only default, startup upload/account messages, silent retry behavior, linked endpoint, local queue, and saved upload key are unchanged.

DTLogs v0.13.30

Startup online-upload/account status
- On game startup, DTLogs now prints the current online-upload policy in chat: successful missions only, all completed missions, or disabled.
- The default configuration therefore explicitly reports that online upload is enabled for successful missions only.
- Startup also prints whether a DTLogs account upload key is linked. Linked status shows only the masked key hint; the full key is never printed.
- If no account is linked, DTLogs explains that online uploads are anonymous and the uploader is shown as Anonymous on DTLogs.
- These are startup status messages only; retry behavior remains silent after the first transient upload failure per mission.

DTLogs v0.13.29

Upload policy + account controls in Mod Options
- Automatic upload is enabled by default for new installs, with the default upload policy set to successful missions only. DTLogs treats Darktide victory `mission_ended.outcome == "won"` as successful (and accepts `"success"` as a compatibility alias). Failed/non-success mission logs remain saved locally and are not automatically queued in the default mode.
- Adds a Mod Options dropdown to switch between `Successful missions only` and `All completed missions`. Existing reports that were already queued before changing the policy keep retrying.
- Adds DTLogs account status to Mod Options. The full upload key is never displayed; linked status shows only the existing masked suffix.
- Adds a Mod Options text field for account linking. It accepts either a raw `dtl_up_...` upload key or pasted link/text containing such a key. `/dtlogs_link` accepts the same forms.
- Adds an explicit disconnect action in Mod Options with a warning that the upload key must be entered again to reconnect. The standard DMF settings API does not expose arbitrary per-mod push buttons, so the disconnect control is implemented as a confirmation dropdown to avoid brittle custom UI injection.
- Disconnecting removes only the locally stored account upload key. Existing local mission JSONL files are not deleted. Unlinked automatic uploads continue through the anonymous upload endpoint.

DTLogs v0.13.28

Linked-upload endpoint + silent retry hotfix
- Pins account-linked automatic uploads to the deployed production endpoint `POST https://dtlogs.com/api/v1/logs/addon`. This supersedes the pre-rollout `/api/v1/addon/logs` path that returns HTTP 404.
- `/dtlogs_link_status` now prints the linked upload endpoint as well as the masked key status, making it easy to verify that the installed build is using the production route.
- A transient upload failure is shown in chat only once per queued mission. Automatic retries continue in the background without repeating the same failure message every retry interval.
- The first transient failure message is shorter: it keeps the useful HTTP status when available, confirms the JSONL is safe locally, and says retries will continue silently. curl exit-code/stderr noise is no longer echoed into normal chat.
- A successful retry still reports `Upload complete`; linked HTTP 401/403 still pauses retries and asks the user to replace/remove the key.
- Existing queue files and account upload keys are preserved across the update, so a report that previously hit HTTP 404 can be retried after installing v0.13.28.

DTLogs v0.13.27

Account-linked auto-upload groundwork
- Keeps the tested v0.13.25 seamless no-CMD transport unchanged for users who do not configure an account upload key. Unlinked automatic uploads still use the existing anonymous `POST https://dtlogs.com/api/v1/logs` endpoint.
- Adds `/dtlogs_link <upload-key>`, `/dtlogs_unlink`, and `/dtlogs_link_status`. Upload keys use the reserved `dtl_up_...` format and are stored outside mission JSONL in `%APPDATA%\Fatshark\Darktide\DTLogs\dtlogs_upload_key.txt`.
- The mod never echoes the complete upload key after it is saved; status output shows only a masked suffix.
- When linked, automatic uploads switch to the dedicated `POST https://dtlogs.com/api/v1/logs/addon` endpoint and send `Authorization: Bearer <upload-key>`. This endpoint is intentionally separate from the browser/cookie upload path so a missing server rollout cannot silently turn a supposedly linked upload into an anonymous one.
- Upload response headers are captured to a temporary file. A linked HTTP 401/403 pauses automatic retries and keeps the JSONL queued locally until the user supplies a new key or unlinks, avoiding an endless bad-token retry loop.
- Local JSONL retention, persistent queue, success receipts, 30-second transient retry, serial upload, and native ShellExecuteW no-console launching remain unchanged.
- Account ownership requires the matching DTLogs.com backend/account-token feature. Until that server-side feature is deployed and a key is configured, v0.13.27 behaves like v0.13.25 and uploads anonymously.

DTLogs v0.13.25

Native no-console auto-upload launcher
- Fixes the remaining black CMD window that could flash over Darktide when an automatic upload started.
- Root cause: v0.13.24 hid wscript/curl themselves, but started the first wscript process through os.execute(), which still invokes the Windows command processor.
- v0.13.25 launches the hidden WScript worker directly through Windows ShellExecuteW using the FFI library preserved by Darktide Mod Loader. The upload path no longer uses os.execute()/cmd.exe.
- The worker still runs curl.exe with windowStyle=0, so both process-launch stages are hidden.
- If the native FFI launcher is unavailable, DTLogs deliberately leaves the report queued instead of falling back to the visible CMD launcher. `/dtlogs_status` reports `launcher: native ShellExecuteW` when the native path is ready.
- Persistent queue, 30-second retry, success receipts, local JSONL retention, and the existing upload endpoint are unchanged from v0.13.24.

v0.13.24

Silent automatic upload + persistent retry queue
- Automatic upload now launches through Windows Script Host with windowStyle=0. curl.exe no longer runs in a visible CMD window over Darktide.
- Completed logs are written to a persistent upload queue before transfer starts.
- Failed transfers remain queued and retry automatically after 30 seconds while Auto Upload is enabled.
- The queue survives a Darktide restart; existing readable queued JSONL files are retried after the mod loads.
- Only one automatic upload runs at a time, preventing duplicate concurrent attempts.
- Successful uploads are removed from the queue. A tiny success receipt prevents duplicate retry if Darktide closes before it can poll the finished worker. Local JSONL mission logs are never deleted.
- `/dtlogs_upload_last` still provides a manual retry/test path for the latest completed mission in the current session.
- Upload transport still uses the existing `POST https://dtlogs.com/api/v1/logs` multipart field `file`; no backend/parser protocol change is required.

v0.13.23

Automatic completed-mission upload (opt-in)
- Adds an opt-in Mod Options setting: `Automatically upload completed missions to DTLogs.com` (default OFF).
- After a real `mission_ended`, DTLogs saves the completed JSONL path, forces the existing final flush/close, and only then starts upload.
- Uses the existing website upload contract: `POST https://dtlogs.com/api/v1/logs` as multipart form field `file`. No parser/worker protocol change is required.
- HTTPS transfer runs through Windows `curl.exe` in a background child process so the game thread is never blocked by network latency.
- The local JSONL is never deleted. If curl cannot start, times out, receives an HTTP error, or otherwise fails, the user can still upload the same file manually.
- DTLogs polls only a tiny completion-status file once per second and reports `Upload complete` or `Automatic upload failed` in chat.
- Adds `/dtlogs_upload_last` to retry/test upload of the most recently completed mission from the current game session.
- `/dtlogs_status` now reports whether auto upload is enabled, the number of pending uploads, and the last completed log path.
- This first implementation targets Windows 10/11 installations with `curl.exe`; non-Windows/Proton-native upload transport is not yet implemented.
- Combat capture, protocol 2, damage semantics, presence/completeness semantics, modifier semantics, and player identity semantics are unchanged from v0.13.22.

v0.13.22

Stable player/character identity semantics
- Promotes the v0.13.21 identity diagnostic after live validation on a complete four-human mission.
- `account_id` is the Darktide account identity from `player:account_id()`.
- `character_id` is the operative identity from `player:character_id()` and is the canonical cross-mission Character Profile key when non-null.
- The legacy `player_uuid` field is intentionally retained for compatibility; it currently mirrors account identity for normal human players and MUST NOT be used as a character/profile key.
- Adds `player_identity_semantics_version=1` and marks mission identity status `stable_character_id`. The prior diagnostic-version field is retained only for backward compatibility with v0.13.21-era readers.
- Roster snapshots, join/leave events, build/loadout snapshots, player combat actor snapshots, buff batches, and player-damage events continue to carry explicit account/character identity where the game exposes it.
- Validation sample confirmed four remote/local human players each had a non-null, distinct `character_id`; the same account/character pair repeated consistently across build, presence, and combat events.
- Presence/completeness, damage, mission-modifier semantics, and all existing metrics are otherwise unchanged.

Website/parser contract
- Prefer `character_id` for one-operative identity.
- Use `account_id` only for account/owner identity.
- Treat missing `character_id` as unknown/unlinked; never reconstruct it from nickname, class, or legacy `player_uuid`.
- Protocol v2 files before this identity field existed remain valid reports but are not eligible for cross-mission Character Profile aggregation unless a true `character_id` is present.

v0.13.21

Player identity diagnostic release for competitive character profiles
- Keeps existing protocol=2 `player_uuid` behavior unchanged for backward compatibility. It is legacy/misnamed and currently resolves primarily from `player:account_id()`.
- Adds explicit `account_id` and `character_id` fields. `character_id` is read best-effort from Darktide `player:character_id()` and is nullable when the engine does not expose it for that player object.
- Adds `player_identity_diagnostic_version=1` and `player_identity_semantics_status=diagnostic_only` at mission start. Do not build cross-mission Character Profiles until live logs confirm `character_id` is present and stable for local and remote human players.
- Presence roster snapshots and join/leave events now carry `account_id` + `character_id` alongside legacy `player_uuid`.
- Player build/loadout snapshots carry the same explicit identity pair.
- Player actor snapshots used by attack events now also emit `<prefix>_account_id` and `<prefix>_character_id`; buff batches and player-damage-taken rows carry explicit identity fields too.
- Presence/completeness, damage, mission-modifier semantics, and all existing metrics are otherwise unchanged.

Validation requested before website migration
1. Record one complete mission with at least one remote human teammate.
2. Send the JSONL. Check `presence_roster_snapshot`, `player_build_loadout_snapshot`, a few attack rows, and `mission_ended`.
3. Confirm each human has a non-null `account_id` and a distinct operative `character_id`, and that the same character id repeats consistently across event types.
4. Only then promote character identity to a stable parser/storage contract.

v0.13.20

Mission modifier stable-id semantics + v0.13.19 crash hotfix
- Fixes the v0.13.19 startup-probe regression where `write_modifier_context_snapshot()` called `safe_gameplay_clock_ms` before Lua had created the local binding. That error aborted `mod.update` every frame and could leave a mission JSONL with only startup events.
- Adds `mission_modifier_semantics_version=1`. The canonical public contract is an ordered array of stable high-level modifier ids; localized names/descriptions/icons remain website catalog metadata.
- Havoc: parses the ordered high-level card ids from the fifth field of StateGameplay `mechanism_data.havoc_data`. Live Havoc 24 validation showed the exact list `mutator_havoc_enemies_corrupted:mutator_havoc_enraged:mutator_increased_difficulty`, matching the three visible cards in the same order.
- Standard missions: a non-default `mechanism_data.circumstance_name` is emitted as one `kind=condition` modifier; `default` emits an empty list.
- `mission_started`, `mission_difficulty_resolved`, `mission_modifiers_resolved`, diagnostic snapshots, and `mission_ended` carry the canonical modifier ids/source.
- Diagnostic manager/template snapshots remain enabled for now so future tests can discover localization/icon/tier metadata without changing the stable id contract.
- Damage semantics remain version 6 and the Ovenproof damage-accounting function is unchanged. Presence/completeness semantics remain version 1.

Canonical website-facing shape
- `mission_modifier_semantics_version=1`
- `mission_modifiers=[{id, kind, display_order}, ...]`
- `kind` is currently `havoc_mutator` or `condition`.
- `mission_modifiers_source` describes the authoritative game-side source.
- The website must resolve ids to title/description/icon by game version/build; do not rely on English strings embedded in the addon.

v0.13.19

Mission modifier discovery / diagnostic release
- Damage semantics are unchanged from v0.13.18: `scoreboard_damage` remains the canonical Ovenproof-compatible metric and `damage_semantics_version` remains 6.
- Presence/completeness semantics are unchanged from v0.13.18 and remain `presence_semantics_version=1`.
- Adds `mission_modifier_diagnostic_version=1` with `mission_modifier_semantics_status=diagnostic_only`. The website must not yet treat modifier diagnostics as a finalized public modifier contract.
- `mission_started` now preserves the modifier-related subset of StateGameplay `mechanism_data` plus the raw `havoc_data` value. Existing `circumstance` remains unchanged for compatibility.
- Adds bounded `mission_modifier_context_snapshot` events at startup (after managers initialize) and mission end. They inspect only modifier/circumstance/Havoc-related manager fields and read-only getter candidates, plus `DifficultyManager:get_parsed_havoc_data()` when available.
- The diagnostic also records candidate internal modifier/mutator identifiers and matching static MutatorTemplates metadata when exposed by the current game build. This is intended to distinguish user-facing Conditions/Havoc modifier cards from hidden low-level gameplay mutators before the canonical schema is frozen.
- No images or localized prose are embedded in the log. The eventual website should resolve stable modifier ids to its own icon/title/description catalog after live validation.

Validation requested before promoting modifier semantics
1. Record a normal mission with a known non-default condition (for example Hunting Grounds, Hi-Intensity Engagement Zone, Shock Troop Gauntlet, or Power Supply Interruption).
2. Record a Havoc mission with multiple visible modifier cards and note/screenshot the exact cards shown by the game.
3. Optional: record a normal mission with no condition/default circumstance.
4. Send the JSONL files. Inspect `mission_started` and `mission_modifier_context_snapshot` to identify the stable high-level runtime ids and whether tier/title/description/icon metadata are directly available.

v0.13.18

Mission completeness / participant-presence semantics release
- Damage logic is unchanged from v0.13.17/v0.13.16. `scoreboard_damage` remains the canonical Ovenproof-compatible Damage/DPS metric and `damage_semantics_version` remains 6.
- Promotes the server gameplay-clock experiment into `presence_semantics_version=1`.
- The addon now compares two monotonic origins on the first authoritative `rpc_sync_clock`:
  `recording_start_gameplay_clock_estimate_ms = gameplay_clock_first_server_sync_ms - gameplay_clock_first_sync_recording_elapsed_ms`.
- A fresh-start validation produced an estimate of about -3.879 s: the DTLogs file was already open before the server gameplay clock reached zero.
- A known late-join validation produced an estimate of about +90.339 s: the recording began after the mission gameplay clock was already running.
- `mission_ended.mission_recording_status` is therefore:
  - `full` when the estimated recording origin is earlier than gameplay-clock zero by more than 250 ms;
  - `partial` when it is later than zero by more than 250 ms;
  - `unknown` inside the +/-250 ms ambiguity band or when authoritative clock evidence is missing.
  The ambiguity state is intentional: uncertain edge cases are never guessed.
- `mission_ended.recording_complete_to_mission_end=true` means the recording observed the real game-mode end condition. Logs that leave gameplay without that condition receive a `recording_incomplete` event and are closed.
- `mission_gameplay_duration_ms` is the whole server-synchronized mission gameplay clock at the real end condition.
- `recorded_gameplay_duration_ms` is the observed gameplay-clock segment in this file. `recording_gameplay_span_ms` is retained as the compatibility name for the same value.
- `recording_gameplay_coverage_ratio` records observed gameplay duration divided by whole mission gameplay duration.
- `recording_started_at_gameplay_clock_ms` is retained for compatibility with v0.13.17 and represents the first authoritative server-sync gameplay time, NOT the estimated file-start origin. New parsers should use `recording_start_gameplay_clock_estimate_ms`.
- Raw `presence_roster_snapshot`, `session_member_joined`, and `session_member_left` events remain the source for player-presence interpretation. Initial membership events synchronized at recording startup describe players already visible to the recorder; for a partial mission their history before recording is unknown.
- Successful hook installation is now silent. The diagnostic `DTLogs: hooked ...` spam and the early `mission log file created` message were removed. Hook failures/errors are still surfaced.

Website/parser interpretation for v0.13.18+
- Mission completeness: prefer `mission_ended.mission_recording_status`. If there is no `mission_ended`, or a `recording_incomplete`/`logging_disabled` event terminates the file, the report is incomplete.
- Mission duration: use `mission_ended.mission_gameplay_duration_ms`, not local file duration.
- Player presence in a FULL mission:
  - present in the startup synchronized roster and no observed leave gap through mission end => full-mission participant;
  - a player first observed in a later live join event => late join;
  - leave before mission end => left early;
  - leave then rejoin => interrupted.
- Player presence in a PARTIAL mission: players already present at recording startup are `unknown_before_recording`; only joins/leaves observed after the recording started are authoritative.
- Do not infer a player's pre-recording history from the initial synchronized `session_member_joined` burst in a partial log.

v0.13.17

Diagnostic mission-completeness / participant-presence / server gameplay clock release
- Damage logic is unchanged from v0.13.16. `scoreboard_damage` remains the canonical Ovenproof-compatible Damage/DPS metric and damage_semantics_version remains 6.
- Adds diagnostic capture of Darktide's synchronized `gameplay` clock. The client receives the current server gameplay time through `GameplayStateRun.rpc_sync_clock`; `Managers.time:time("gameplay")` is sampled at mission end.
- New `mission_ended.mission_gameplay_duration_ms` records the server-synchronized gameplay clock at the real game-mode end condition.
- New `mission_ended.recording_duration_ms` records how long this local DTLogs file existed.
- New `recording_started_at_gameplay_clock_ms` and `recording_gameplay_span_ms` make it possible to compare the recorded segment with the whole gameplay clock.
- New diagnostic lifecycle events: `gameplay_state_entered`, `gameplay_clock_sync_received`, `gameplay_clock_registered`, and (for abnormal/non-finalized transitions) `gameplay_state_exited`.
- New participant evidence: `presence_roster_snapshot`, `session_member_joined`, `session_member_left`, with peer IDs, current gameplay-clock time and best-effort player UUID/name resolution.
- Initial roster snapshot is captured at the first authoritative gameplay-clock synchronization; final roster snapshot is captured immediately before `mission_ended`.
- `presence_diagnostic_version=1`, `gameplay_clock_diagnostic_version=1`, and `presence_semantics_status="diagnostic_only"` are written so the website does NOT yet label a report FULL/PARTIAL from unvalidated heuristics.

Validation plan before enabling FULL/PARTIAL on the website
1. Record one mission entered from the beginning.
2. Record one Quickplay mission joined clearly after it has already been running.
3. Send both JSONL files. Compare first server sync time, final gameplay duration, local recording duration and roster evidence.
4. Only after live validation promote these diagnostics into stable mission-completeness/player-presence semantics.

Important intended interpretation
- `mission_gameplay_duration_ms`: whole server-synchronized gameplay clock at mission end. This is the duration field intended for the website after live validation.
- `recording_duration_ms`: duration of this particular DTLogs recording only.
- On a late join, `mission_gameplay_duration_ms` should include time before the recorder joined, while `recording_gameplay_span_ms` covers only the observed gameplay segment.
- Session join/leave events are authoritative only from the moment this recorder is connected. For players already present when a late recorder joins, their pre-recording history remains unknown.

v0.13.16

Hotfix for v0.13.15 profile polling regression
- Restored the profile/talent/loadout helper functions accidentally omitted from the v0.13.15 package.
- Fixes repeated `profile_player_identity` nil errors during DTLogs update/profile polling.
- Restores player_build_loadout_snapshot capture, including startup and late-join profiles.
- Damage semantics are unchanged from v0.13.15: `scoreboard_damage` remains the canonical Ovenproof-compatible Damage/DPS metric.
- damage_semantics_version remains 6.

v0.13.15
--------
- Cleanup/stabilization release after live validation against Ovenproof Scoreboard Plugin.
- `scoreboard_damage` is now the canonical Damage/DPS metric. Its calculation is unchanged from v0.13.14.
- Live validation matched Ovenproof `total_damage` exactly for all 4 players and the team total.
- `effective_damage` remains an alias of `scoreboard_damage` for backward compatibility.
- `overkill_damage` is now serialized as null and `overkill_semantics_available=false`. Do not derive
  overkill as raw `damage - scoreboard_damage`: Ovenproof total_damage is not an overkill metric.
- `damage_accounting_anomaly` is retained only as a deprecated compatibility flag. The neutral replacement
  is `scoreboard_damage_outlier`; mission end also records `scoreboard_damage_outlier_count`.
- New mission-end canonical total: `total_scoreboard_damage`.
- New mission metadata: `damage_metric=ovenproof_total_damage`.
- `damage_semantics_version=6`; protocol remains 2.

Website/parser rule for v0.13.15+
- Damage Done / DPS: sum `scoreboard_damage` where attacker_type=player and target_is_minion=true.
- `effective_damage` is a compatibility alias and should not be summed in addition to scoreboard_damage.
- Highest Hit: use raw `damage`.
- Ignore `overkill_damage` for v0.13.15+; it is null by design.
- At mission level, `total_scoreboard_damage` is the canonical team total.

DTLogs v0.13.15 — Stable Ovenproof-Compatible Damage Semantics

v0.13.14
--------
- Switched Damage/DPS accounting to the exact Ovenproof `total_damage` semantics used in the original
  user comparison.
- Non-lethal enemy hits use raw `damage`; lethal enemy hits use `max_health - damage_taken`, with the
  Ovenproof Psykanium shooting-range correction.
- Added explicit `scoreboard_damage` alongside the backward-compatible `effective_damage` alias.
- Removed the experimental v0.13.12-v0.13.13 per-minion HP-cache algorithm from the canonical damage path.
- `damage_semantics_version=5`; protocol remains 2.

Website/parser rule for v0.13.14
- Damage Done / DPS: sum `scoreboard_damage` where attacker_type=player and target_is_minion=true.
- Highest Hit: use raw `damage`.
- Do not rely on v0.13.14 `overkill_damage`; it was only a derived diagnostic and is deprecated in v0.13.15.

DTLogs v0.13.14 — Ovenproof-Compatible Total Damage

v0.13.12
--------
- Replaces v0.13.11 lethal remaining-health arithmetic with Scoreboard-style per-minion HP caching.
- `attack_result` adds `target_health_before`, `target_health_after`, and `health_cache_hit`.
- On `damaged`, cached pre-hit HP is used; first observation seeds it from post-hit HP + raw damage.
- On `died`, cached pre-hit HP becomes Actual Damage. If no cache entry exists, the full killing
  hit is Actual Damage and Overkill is zero, matching Scoreboard's fallback.
- The health cache is updated for every minion attack report, including non-player sources.
- `damage_semantics_version=3`; protocol remains 2.
- New mission-end diagnostics: enemy_health_cache_hit_count, enemy_health_cache_miss_count,
  enemy_health_cache_seed_count, and enemy_health_read_fallback_count.

Website/parser rule for v0.13.12+
- Damage Done / DPS: sum `effective_damage` only where attacker_type=player and target_is_minion=true.
- Overkill: sum `overkill_damage` over the same events.
- Highest Hit: keep using raw `damage`.

DTLogs v0.13.12 — Scoreboard-Compatible Health Cache

v0.13.11
--------
- Fixes inflated Damage/DPS caused by counting raw lethal-hit overkill as real enemy damage.
- `attack_result.damage` remains the raw hit value for backward compatibility and highest-hit analytics.
- New `attack_result.effective_damage` records enemy HP actually removed.
- New `attack_result.overkill_damage` records the raw lethal-hit amount above remaining enemy HP.
- New `attack_result.target_is_minion` is the authoritative enemy-minion flag.
- New `attack_result.damage_accounting_source` explains how effective damage was obtained.
- Lethal enemy hits use the Scoreboard-compatible remaining-health calculation:
  `max_health - damage_taken` (with Darktide's shooting-range special case).
- Targetless/non-enemy attack reports do not receive effective enemy damage. This prevents
  targetless post-death companion/servo-skull reports from inflating player Damage.
- New mission_started field: `damage_semantics_version=2`. Protocol remains 2.
- New mission_ended diagnostics: `total_effective_enemy_damage`, `total_overkill_damage`,
  `enemy_damage_event_count`, and `enemy_damage_fallback_count`.

Website/parser rule for v0.13.11+
- Damage Done / DPS: sum `effective_damage` only for events where
  `event == "attack_result"`, `attacker_type == "player"`, and `target_is_minion == true`.
- Do not sum raw `damage` for Damage Done / DPS.
- Keep raw `damage` available for hit-size analytics such as Highest Hit.
- For pre-v0.13.11 logs, exact overkill correction is not available from JSONL alone.

DTLogs v0.13.11 — Effective Enemy Damage

v0.13.10
--------
- Fixes difficulty-context contamination when leaving a short/aborted mission.
- The previous mission file is now closed before handling any new StateGameplay
  context, including hub/hub_ship.
- Prevents a hub DifficultyManager snapshot from being appended as a second
  mission_difficulty_resolved event to the previous mission.
- Keeps protocol 2 and all v0.13.10 difficulty fields unchanged.

DTLogs v0.13.10 — Resolved Difficulty Context

Fully branded DTLogs build.

Why v0.13.10 exists
- Live validation of v0.13.8 confirmed exact Havoc and Expedition detection.
- A real Auric sample exposed an important timing detail: StateGameplay receives raw/base
  challenge + resistance before Darktide's DifficultyManager is fully initialized.
- Therefore mission_started alone is not always enough to identify the final human-facing
  standard/Auric difficulty.
- v0.13.10 keeps mission_started backward-compatible and adds one later
  mission_difficulty_resolved event after the live DifficultyManager becomes authoritative.

Changes in v0.13.10
- New event: mission_difficulty_resolved
- It is written once per recorded mission, normally about one second after mission start.
- It records:
  difficulty_mode
  havoc_rank
  base_challenge
  base_resistance
  initial_challenge
  initial_resistance
  effective_challenge
  effective_resistance
  danger_name
  danger_index
  danger_difficulty
  danger_is_auric
  danger_localization_key
  resolution_source="difficulty_manager"
- The live Darktide DifficultyManager getters are used:
  get_challenge
  get_resistance
  get_initial_challenge
  get_initial_resistance
  get_danger_settings
  get_parsed_havoc_data
- A one-second guard avoids sampling a stale difficulty manager during state transition.
- Mission end performs a final forced difficulty resolution if the normal poll did not run.
- /dtlogs_status now shows both the base StateGameplay values and the resolved effective danger.
- difficulty_context_version=2 is written to mission_started and mission_difficulty_resolved.
- Protocol remains 2.

Important semantics
- challenge/resistance on mission_started remain the raw/base mechanism values for backward
  compatibility.
- Do NOT map mission_started challenge/resistance directly to the final display name when a
  mission_difficulty_resolved event exists.
- For new v0.13.10 logs, the website/parser should prefer mission_difficulty_resolved.
- Havoc display should use difficulty_mode="havoc" + havoc_rank, e.g. "Havoc 18".
- Expedition remains a separate mode; its resolved danger can still be captured independently.
- Standard/Auric human-readable names can use danger_name / danger_localization_key from the
  resolved event. The addon stores the game identifier/key rather than a localized string.

v0.13.8 live validation that motivated this change
- Known Havoc 18 sample:
  mission_started difficulty_mode="havoc", havoc_rank=18
- Known Expedition sample:
  mission_started difficulty_mode="expedition", havoc_rank=null
- Known Auric sample supplied by the tester:
  mission_started difficulty_mode="standard", challenge=5, resistance=4,
  circumstance="more_resistance_01"
  This is exactly why the raw mission-start pair must not be treated as the final UI difficulty.

Changes retained from v0.13.8
- mission_started records difficulty_mode.
- Havoc rank is read directly from Darktide mission mechanism Havoc data; it is not inferred from
  mutators or from challenge/resistance.
- Expedition detection uses Darktide MissionTemplates game_mode_name=expedition with a safe exp_
  mission-id fallback.
- Existing challenge and resistance fields remain unchanged.

Changes retained from v0.13.7
- Players who join after a mission has already started receive the same full
  player_build_loadout_snapshot as players present at mission start.
- Snapshot includes character/profile identity, archetype, level, talent data, selected nodes,
  raw talents, equipped weapons, curios/accessories and supported cosmetic/equipment slots.
- Lightweight late-join roster check stays active after the initial snapshot window.
- Each captured player identity is serialized once per mission.
- Mission end performs one final forced roster check.
- mission_ended includes player_build_snapshot_count and late_join_build_snapshot_count.

Changes retained from v0.13.6
- Successful mission finalization prints the DTLogs.com upload message.
- mission_started and mission_ended include game build metadata.
- /dtlogs_status shows the captured game version and build identifier.

Existing package characteristics
- Mod folder: DTLogs
- DMF module ID: DTLogs
- Mod definition: DTLogs.mod
- Lua script folder and filenames: DTLogs
- Mod menu name: DTLogs
- Chat/on-screen messages: English, prefixed with DTLogs
- JSONL output folder: %APPDATA%\Fatshark\Darktide\DTLogs\
- Commands:
  /dtlogs_status
  /dtlogs_profile_snapshot
  /dtlogs_file_test

Installation / upgrade
1. Close Darktide.
2. Replace the existing DTLogs mod folder with the DTLogs folder from this archive.
3. Keep DTLogs in mod_load_order.txt.
4. Start the game.

Recommended acceptance test
1. Record one mission that the game UI identifies as Auric.
2. Record one Havoc mission whose exact rank is known.
3. Record one Expedition start if convenient.
4. Send the resulting JSONL files for validation.

Expected v0.13.10 structure
- line/event mission_started:
  raw/base challenge/resistance + difficulty_mode + initial Havoc rank if available
- later event mission_difficulty_resolved:
  effective live DifficultyManager values + danger metadata + verified Havoc rank

The JSONL protocol remains version 2.
