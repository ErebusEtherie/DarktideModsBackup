ModShrine v0.5.5
=================


V0.5.5 UPDATE
=============
Workflow performance, diagnostics, and retired-mod cleanup.

- Adds a guarded UI-only workflow/current-state cache so repeated ModShrine
  menu opens can reuse an already verified state instead of rebuilding it.
- Warms that cache automatically after a verified snapshot or confirmed
  duplicate and keeps it synchronized across verified unchanged Mod Options
  closes.
- Adds a UI-only Known Good/latest restore-target cache for passive workflow
  display. Actual Preview Restore and Stage Safe Restore still read and analyze
  the backup fresh from disk.
- Fixes false WORKFLOW_CACHE disk_changed misses caused by harmless DMF
  Mod Options file churn. The raw fingerprint is refreshed only after the
  existing verified unchanged guard and required DMF save both succeed.
- Adds hold-to-confirm FORGET TRACKING for obsolete retired/missing mod IDs,
  useful after a mod is renamed or permanently removed. Forgotten IDs stop
  appearing in active retired/missing workflow tracking and restore
  missing-target counts.
- FORGET TRACKING does not delete live DMF settings, historical snapshots, or
  existing per-mod archives. If the exact forgotten mod ID is installed again,
  ModShrine automatically resumes tracking it.
- Adds detailed build_current_state subphase timing plus SLOW_PHASE breadcrumbs
  for measured ModShrine phases at or above 50 ms.

Field testing confirmed the workflow and preview caches hit correctly after
startup and unchanged closes, real settings changes still invalidate the cache
and complete the full verified automatic snapshot path, and forgotten IDs
persist correctly across a full Darktide restart.

There are no changes to snapshot format, Known Good safety verification, Safe
Restore staging, retention, the missing-mod archive format, or the required
changed-settings DMF safety flushes.


V0.5.4 UPDATE
=============
Large-installation Mod Options performance update.

- Adds a guarded fast path for closing DMF Mod Options when no meaningful
  settings or roster changes are present.
- The fast path is armed only from a fully verified ModShrine state.
- Before skipping the delayed duplicate check, ModShrine requires the live DMF
  settings fingerprint, semantic on-disk settings fingerprint, current
  installed/enabled/retired roster fingerprint, and exact latest verified
  snapshot identity to still match.
- Any mismatch, missing baseline, pending live change, unavailable roster scan,
  or changed/missing latest snapshot falls back to the existing full
  verification path.
- Real settings changes retain the immediate DMF save and the snapshot job's
  final safety flush before a verified automatic backup is written.

Field testing confirmed that an unchanged Mod Options close can skip the delayed
snapshot/state-build cycle, while a real settings change still disarms the fast
path and completes the normal verified backup flow.

There are no changes to snapshot format, Known Good, restore staging, retention,
missing-mod archives, or Mourningstar gating.


V0.5.3 UPDATE
=============
This update reduces unnecessary work after closing DMF Mod Options.

- Removed a redundant delayed DMF settings save from the automatic backup path.
- ModShrine still saves immediately when Mod Options closes.
- The snapshot job still performs its final safety flush before reading the
  configuration.
- Duplicate/no-change backup checks remain suppressed as before.

There are no changes to backup format, Known Good, restore behavior, retention,
missing-mod archives, or Mourningstar gating.

V0.5.2 UPDATE
=============
This update reduces retention-related frame hitches and tightens Mourningstar
transition safety.

- Automatic-retention finalization no longer validates all indexed snapshot
  files in one frame. Normal 20/20 retention now uses ModShrine's own index and
  keeps expensive reconciliation cooperative and outside snapshot finalization.
- Mourningstar disk/archive work remains paused through GameplayInitStep* and
  unlocks when GameplayStateRun confirms the hub is fully initialized.
- GameplayStateRun is authoritative whenever available; a delayed compatibility
  fallback is reserved for future game builds where that hook is unavailable.

Backup format, Known Good, restore staging, missing-mod archives, and the
guided workflow are unchanged.

WHAT MODSHRINE DOES
===================
ModShrine protects Darktide Mod Framework (DMF) and mod settings by creating
verified backups of Darktide's user_settings.config file, preserving per-mod
archives, and providing a guarded Known Good restore workflow.

The normal user workflow is intentionally simple:

  1. Protect Your Settings
  2. Choose a Trusted Restore Point
  3. Preview Before Restoring
  4. Restore Known Good

Automatic backups are enabled by default.

IMPORTANT PATHS
===============
Darktide settings source:

  %APPDATA%\Fatshark\Darktide\user_settings.config

ModShrine vault:

  %LOCALAPPDATA%\ModShrine\Darktide

The ModShrine vault is separate from Darktide's normal settings directory.

FIRST-TIME SETUP
================
On a fresh ModShrine vault, ModShrine creates a verified protection snapshot.

Expected workflow:

  Step 1:
    ✓ PROTECTED

  Step 2:
    Hold MARK KNOWN GOOD

Choose MARK KNOWN GOOD when your current mod settings are working exactly the
way you want.

After Step 2 finishes, DMF's Mod Options screen may not immediately refresh
Step 3.

ModShrine explicitly tells you:

  Step 2 complete. Known Good is protected.
  Exit Mod Options to the Mourningstar,
  then reopen ModShrine to continue to Step 3.

Return to the Mourningstar, reopen Mod Options, and select ModShrine again.

If your settings have not changed since Known Good was created:

  Step 3:
    ✓ NO RESTORE NEEDED

FIRST PROTECTION PASS
=====================
The first protection pass must catalog the current DMF/mod configuration and
build the initial per-mod archives.

On a large mod setup this can cause a brief one-time hitch while the initial
snapshot is prepared.

Subsequent incremental automatic backups are normally much lighter because
ModShrine can reuse its existing snapshot and archive state.

KNOWN GOOD
==========
Known Good is the trusted restore point used by the guided recovery workflow.

Do not mark a backup as Known Good until your current mod settings are working
the way you want.

RESTORE SAFETY
==============
ModShrine does not replace the live Darktide settings file while Darktide is
running.

The restore workflow:

  1. Preview the exact restore plan.
  2. Require the Preview to match the current configuration and Known Good.
  3. Create an emergency pre-restore backup.
  4. Stage and verify the merged restore.
  5. Launch a hidden local watcher.
  6. Wait until Darktide fully exits.
  7. Apply the staged settings file offline.
  8. Verify the resulting file on the next Darktide launch.

If Preview becomes stale because settings change, restore authorization is
cleared and Step 3 must be completed again.

MISSING MODS
============
If a previously seen mod is no longer installed, ModShrine preserves its
archived settings instead of silently throwing them away.

A missing mod is shown as "Missing Mod Archived" because its protected settings
archive is retained. The row is informational unless you choose to retire that
mod from active tracking.

Retiring a missing mod does not erase historical backups or its protected
archive.

ADVANCED TOOLS
==============
Advanced Tools are hidden by default.

They expose maintenance actions such as manual backup, Known Good replacement,
roster export, vault access, and detailed diagnostics.

Normal users do not need them for everyday protection or recovery.

DEFAULTS
========
Show Backup Notifications:        On
Automatic Backups:               On
Automatic Backup Limit:           20
Show Missing / Retired Mod Actions: On
Show Advanced Tools:              Off

RELEASE STATUS
==============
ModShrine has graduated from its public beta label after repeated live validation of its backup, retention, Known Good, restore, and mission-safety workflows.

Core release gates tested include:

- clean initialization
- automatic startup protection
- live DMF setting-change detection
- verified snapshots
- rolling backup retention
- Known Good creation
- guided Preview gating
- missing-mod preservation
- protected per-mod archives
- hidden offline restore application
- next-launch restore hash verification
- mission/loading safety gating
- normal Darktide gameplay sessions

If you report a problem, include the Darktide console log when possible.

INSTALLATION
============
Requires Darktide Mod Framework (DMF).

Install the mod_shrine folder into the Darktide mods directory and ensure
mod_shrine is present in mod_load_order.txt using the normal DMF installation
method.

UPDATING
========
Replace the existing mod_shrine mod folder with the new version.

Do NOT delete the ModShrine vault when updating unless you intentionally want
to erase ModShrine backup history.

UNINSTALLING
============
Remove mod_shrine from the DMF load order and delete the mod_shrine mod folder.

The separate ModShrine vault remains at:

  %LOCALAPPDATA%\ModShrine\Darktide

Delete that vault manually only if you also want to remove all ModShrine backup
history.

VERSION
=======
0.5.4


FINAL UI POLISH
===============
The current UI keeps workflow labels stable while status appears
on the right:

  3. Preview Restore
    ✓ PREVIEW COMPLETE

When a restore is staged, its cancellation control appears directly beneath
Step 4 so the pending action and its escape hatch stay together.

Missing mods are labeled:

  Missing Mod Archived: <mod name>

because ModShrine has already preserved their protected settings archive.


v0.5.1 RETENTION PERFORMANCE FIX
================================
When the rolling automatic-backup pool is full, modern snapshots no longer
launch the legacy _assets-directory cleanup path unless that legacy directory
actually exists.

This removes the brief retention hitch observed on full backup pools while
leaving backup verification, Known Good, restore behavior, archive semantics,
and the configured retention limit unchanged.
