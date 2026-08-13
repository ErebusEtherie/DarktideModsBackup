# Auto Ping — Changelog

## 1.0.1 — 2026-07-09

### Fixed
- **Companion tag firing twice (one regular ping + one companion ping)** — when Companion Attack Mode was on, the mod always sent a normal ping first and then layered a companion ping on top of the same target. The two competing tags meant the companion ping couldn't be refreshed until the normal ping expired, so the companion only re-tagged sporadically instead of on its own cooldown. The mod now sends only the companion tag when companion mode applies, and only the regular tag otherwise.
- **Auto-tagging silently freezing until the current tag expired** — the "manual override" detection that's supposed to back off when *you* manually re-tag something wasn't checking who created the tag, so two unrelated things could trip it:
  - A teammate tagging any enemy while your cooldown was still fresh flipped the same flag, freezing your auto-tagger until your own tag happened to expire.
  - Switching to a higher-priority target (which deliberately ignores the cooldown) could trip the mod's own flag right after switching, freezing itself before the new tag ever timed out.
  
  The check now only looks at your own tags, and ignores tags the mod itself just created, so priority switching and teammates' pings no longer stall auto-tagging.

## 1.0.0

- Initial release: automatic smart-tagging of enemies by breed with configurable priority tiers (high/medium/disabled), filter modes (all pingable / high priority only / specials & elites / custom), priority-target interrupts, tag cooldown with optional refresh-on-expire, manual override detection, and companion attack mode integration.
