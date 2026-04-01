# Rear Guard

Rear Guard automatically reacts to Darktide's backstab warning audio cue.

When the melee warning plays, the mod can:
- hold block briefly
- queue a single dodge
- do both

Default profile:
- Response Mode: Block
- Block Hold Duration: 0.18
- Retrigger Cooldown: 0.10
- Dodge Queue Duration: 0.08

Why these defaults:
- block is the most reliable all-purpose response to intermittent backstab warnings
- the short cooldown still allows rare back-to-back warnings to trigger
- the dodge queue is short to avoid delayed accidental dodges

## Features

- reacts to Darktide melee backstab warning sounds
- supports Block, Dodge, and Both response modes
- includes a keybind to cycle response mode in-game
- avoids holding dodge indefinitely after a warning

## Install

1. Place the `RearGuard` folder in your Darktide `mods` directory.
2. Add `RearGuard` to `mod_load_order.txt`.
3. Launch the game with DMF enabled.

## Notes

- The visible mod name is `Rear Guard`.
- The internal mod ID is `RearGuard` for compatibility.

Author: ImperialSkoom
