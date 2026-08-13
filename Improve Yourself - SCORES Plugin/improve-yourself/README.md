# Improve Yourself

Version 1.0.0

Improve Yourself is a visualization plugin for Scores. It turns raw score rows
into compact graphs, comparison bars, goals, and role-oriented feedback in the
Tactical overlay, at the end of a mission, and in Scores History.

Scores remains responsible for collecting statistics, saving match history,
player inspection, and navigation. Improve Yourself supplies the alternative
visual presentation and an additional four-category Damage Taken breakdown.

## Requirements

- Darktide Mod Framework
- Scores 1.1 or newer

Scores must be installed and enabled. Improve Yourself stays inactive and
reports the missing dependency if Scores is unavailable.

Do not run Scores and Scoreboard II together.

## Installation

1. Extract the archive into your Darktide `mods` directory so the resulting
   folder is `mods/improve-yourself`.
2. Add `scores` to `mod_load_order.txt`.
3. Add `improve-yourself` on the next line, after `scores`.
4. Fully restart Darktide.

## Main features

- Tactical performance visualization inside Scores' live overlay.
- Visual Victory Board at the end of a mission.
- Visual Scores History with an in-place `Show numbers` / `Show bars` toggle.
- Configurable default History view.
- Goal-oriented and team-comparison color modes.
- Six configurable playstyle roles with automatic best- and second-role
  recommendations.
- Defense, Offense, Combat Quality, and Teamplay presentations.
- Damage Taken split into Area, Ranged, Melee, and Other.
- Friendly source summaries for each Damage Taken category.
- Automatic layout compaction when Scores rows are disabled.
- Disabled Scores metrics are also excluded from goals, praise, and role
  evaluation.
- Valid zero-event values appear as `--`; missing data in older History entries
  appears as `NO DATA`.

## Scores integration

Improve Yourself respects Scores' row-visibility settings across Tactical,
Victory, and History. Damage Total, Damage Taken, damage sources, and Objectives
remain visible because Scores does not provide row toggles for those datasets.

When `Split Kill Tiers` is disabled in Scores, the Swarmer, Elite, and Special
bars are hidden together. No synthetic combined-kills value is created.

Improve Yourself does not create a separate match-history archive. Its hidden
damage-source values and source labels are stored in the corresponding Scores
entry. History matches saved before damage-source tracking was available keep
their Damage Taken total but show `NO DATA` for the unavailable breakdown.

## Damage-source diagnostics

Diagnostics are optional and disabled by default.

- `/iy_debug_damage` starts or stops a manual incoming-damage capture.
- `/iy_reset_damage` clears the live Damage Taken state, useful in the
  Psykhanium.
- `Automatic damage diagnostic per mission` writes one timestamped report per
  mission when enabled in the Developer settings.

Reports are written to:

`%APPDATA%/Fatshark/Darktide/scores_history/v1/`

The manual report is overwritten by the next manual capture. Automatic reports
use timestamped filenames.

## Compatibility and fallback behavior

- Built for Scores 1.1.
- Scores remains available as the numerical fallback if the visual end board
  cannot be prepared.
- Scores History auto-save is optional. If disabled, the end board uses Scores'
  finalized live data.
- Existing Scores History remains intact. Improve Yourself never deletes saved
  matches or rewrites Scores settings.

## Version 1.0.0

- First public release as a dedicated Scores plugin.
- Tactical, Victory, and History visualizations share the finalized layout.
- Scores row settings control visibility and evaluation consistently.
- Dynamic centering and panel compaction cover all supported metric states.
- Damage Taken includes the four-category source breakdown and adaptive labels.
- Combat Quality and Defense comparisons retain correct Best/You/Worst
  alignment in all supported views.
- Development-only test notes and packaging remnants have been removed from the
  release package.

## Credits and development disclosure

Created by Till with development assistance from OpenAI.

Improve Yourself is an independent plugin for Scores. It uses Scores' public
mod interfaces and runtime data but does not redistribute Scores files.
