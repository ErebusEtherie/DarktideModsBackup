# CleanKills

CleanKills removes dead enemies as quickly as safely possible to reduce visual clutter and improve combat readability in Warhammer 40,000: Darktide.

It is focused on reliability with Darktide v1.12.\* + DMF behavior, including queue-based cleanup and fallback handling for edge cases where death/ragdoll callbacks can arrive out of order.

## Features

- Removes enemy bodies quickly after death to keep fights visually clean
- Targets enemy minions only (does not intentionally remove allied/non-enemy units)
- Handles both ragdoll and no-ragdoll death paths
- Includes optional triage logging for troubleshooting
- Lightweight runtime behavior designed for normal gameplay use

## Requirements

- Darktide Mod Framework (DMF)
- Warhammer 40,000: Darktide

## Installation

1. Install DMF and verify it loads correctly.
2. Place the CleanKills mod files in your Darktide mods setup.
3. Enable CleanKills from the in-game DMF mod list.

## Compatibility

- Built against current Darktide 1.12.\* patterns.
- If a game update changes death/ragdoll internals, mod behavior may require an update.

## Permissions, Attribution, and Source Credit

This mod is released with permission from the author of **NoCorpses** ([7878949696](https://www.nexusmods.com/profile/7878949696)).

CleanKills was developed/adapted from parts of the original **NoCorpses** mod, with additional rework for current compatibility.

Original source mod:
- **NoCorpses** - <https://www.nexusmods.com/warhammer40kdarktide/mods/735>

Permission statement:
> "我同意你发布这个基于 NoCorpses 部分代码制作的替代模组，也感谢你在发布前先来征求我的许可。不过我有一个明确要求：请你在模组发布页面、说明文件或描述中清楚标注相关情况，说明这个模组是在得到我允许的情况下发布的，并且它是基于我的 NoCorpses 模组部分代码开发/改写而来。同时也请注明原模组 NoCorpses 的名称，并提供原模组链接，方便玩家了解来源。只要这些说明标注清楚，我同意你按照你上面说的方式发布这个模组。"

Customization note:
- If you are looking for broader customization options, consider using **NoCorpses** instead. CleanKills is intentionally kept stripped down to core corpse-cleanup behavior so it stays easier to maintain across game updates.

## Notes

- This page intentionally includes explicit attribution to NoCorpses per the author's release condition.
- Replace the placeholder NoCorpses link above with the original public mod page URL before publishing.
