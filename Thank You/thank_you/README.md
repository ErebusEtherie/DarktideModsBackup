# Thank You

Speaks a communication wheel line automatically when something worth reacting to
happens. Thanks when a teammate cuts you out of a net, pulls you off a ledge or
picks you up. My pleasure when you return the favour. A call for help the moment
a Hound lands on you.

It uses your character's real wheel voice lines through the game's own dialogue
system, so the rest of the strike team hears them exactly as if you had opened
the wheel and picked the line yourself — same voice, same networking, same
subtitles.

## Triggers

| Trigger | Fires when | Default | On by default |
| --- | --- | --- | --- |
| Revived | A teammate finishes picking you up from knocked down | Thanks | yes |
| Freed from a disabler | You get out of a net, pounce, Mutant grab, Beast of Nurgle, warp grab or hogtie | Thanks | yes |
| Pulled off a ledge | A teammate hauls you back up (falling does not count) | Thanks | yes |
| **Someone thanks you** | A teammate uses the Thanks line on the wheel | My Pleasure | yes |
| You revived or freed an ally | You finish a revive, pull up, rescue or un-net | My Pleasure | no |
| You go down | You are knocked down | Over Here | yes |
| You are disabled | A special takes you, or you end up hanging from a ledge | Over Here | yes |
| Health drops low | Your health crosses the threshold | Need Health | no |
| Out of ammo | You try to reload with an empty reserve | Need Ammo | no |

Every trigger can be set to any of the thirteen wheel lines — Thanks, My
Pleasure, For the Emperor, Yes, No, Need Health, Need Ammo, I Need That, Take
This, Following You, Over Here, Let's Go This Way, Enemy Over There — or to Say
Nothing.

## Settings

- **Response Delay** (default 1.0s) — pause before a callout is spoken. Some
  delay is worth keeping; speaking the instant you stand up talks over the grunt
  your character already makes getting to their feet. Each trigger adds a small
  head start of its own on top of this.
- **Callout Repeat Cooldown** (default 8s) — shortest gap before the *same*
  callout can repeat; this is what stops a bad Trapper wave from turning you into
  a stuck vox bead. Different callouts never block each other — being freed
  seconds after calling for help still gets its thank-you — and two callouts
  landing together are spaced about two seconds apart so they don't overlap.
- **Write Log File** (default on) — records everything the mod does (hooks bound,
  state changes, every callout queued, fired, or skipped and why) to
  `%APPDATA%\Fatshark\Darktide\thank_you_log.txt`. Fresh file per session, one
  line per event. If a trigger fails, this file says exactly where it stopped.
- **Also Send Chat Message** (default off) — posts the matching text to mission
  chat the way the wheel does. Only Thanks, Need Health and Need Ammo have chat
  text in the base game; the rest stay voice-only there, so they stay voice-only
  here. Off by default because automatic chat is far more intrusive than
  automatic voice.
- **Log Callouts To Chat** (default off) — prints each callout to your own feed
  as it fires. Local only.
- **Test** — pick a line and bind a key to speak it on demand, ignoring delay and
  cooldown. Works in the Mourningstar, so you can audition a voice line without
  loading a mission.

## Answering a thank-you

**Someone thanks you** listens for the wheel's Thanks line and answers it. Its
**Answer** setting decides whose:

- **Only When You Helped Them** (default) — you answer the person you just
  revived, pulled up, un-netted or rescued, within twenty seconds, once per
  rescue. No reply to thanks that had nothing to do with you.
- **Anyone** — you answer every thanks in the squad. Be aware that four players
  running this all reply to the same one.

Replies are staggered by a random fraction of a second so a squad running the mod
answers raggedly rather than in perfect chorus.

This overlaps with **You revived or freed an ally**, which speaks whether or not
anyone thanks you. Pick one — running both mostly gets you the unprompted version,
because the shared cooldown swallows the reply that follows a second later.
Answering when actually thanked reads better, so that is the one that ships on.

## Notes

- The base game already has some automatic distress VO when you go down or get
  grabbed, so **You go down** and **You are disabled** can double up with it. If
  it sounds busy, turn those two off — the gratitude triggers are the ones with
  no vanilla equivalent.
- Giving someone a med-stim or ammo already plays "Take This" in the base game.
  Thank You deliberately does not duplicate it.
- Cooldown is claimed when a callout is queued rather than when it plays, so a
  burst of events can't all slip through the window while they wait out the delay.
- Getting grabbed again cancels a thank-you that hasn't gone out yet.
- Low health only re-arms after you heal clear of the threshold, so hovering on
  the line doesn't make you repeat yourself.

## Development

`.harness/run_all.py` runs four offline checks against the game source dump in
`mods/strikemap/.research/` (needs `lupa`):

- **syntax_check** — every Lua file compiles under LuaJIT
- **boot_safety** — no unguarded engine calls that crash before a mission exists
- **audit** — options schema: localization coverage, valid defaults, unique ids
- **wiring** — no dead options, no dangling triggers, no invented engine ids
- **hooks** — every hook signature matches the game's own definition
- **scenario** — loads the real mod file under LuaJIT with a stubbed engine and
  replays live disable/rescue sequences through `mod.update`, asserting both the
  distress call and the thank-you actually fire, correctly spaced

`scenario` exists because build 3 passed every static check and then failed the
first live ledge rescue: one shared cooldown was claimed by the distress callout
at disable time, which silently swallowed the thank-you seconds later — the mod's
central feature dead in its most common scenario. Cooldowns are per-callout now,
with a fixed ~2s anti-overlap gap that postpones rather than drops.

Two things these checks did **not** catch, both found only by playing:

- `mod:hook_safe("ClassName", …)` by string can silently never bind. DMF defers an
  unresolved name and reports it through `mod:info`, which is invisible unless DMF
  log output is turned up — so the mod loads clean, logs nothing, and every trigger
  is dead. Hook by table reference (`CLASS.<Name>`) and assert the method exists.
  The **Diagnostics Key** prints the bind status of every hook for this reason.
- Signatures matching the engine proves nothing about a hook *attaching*. That is a
  runtime property and the harness is entirely static.

`boot_safety` exists because of a launch crash on 2026-07-19: `mod.update` runs
from the very first frame of boot, and `Managers.player:local_player(1)` reaches
`Network.peer_id()` before the connection manager is up, which is an access
violation in native code — not a Lua error, so no amount of `pcall` catches it.
Use `local_player_safe(1)`. A deliberately guarded call may be annotated
`-- boot-safe: <reason>`.

Rerun after a game patch; it catches renamed character states and changed hook
signatures before they turn into a silent no-op in a mission.

## How it works

| What | Where |
| --- | --- |
| Playing a line | `Vo.on_demand_vo_event(unit, on_demand_com_wheel, trigger_id)` — the single call the real wheel makes |
| Networking | `DialogueExtension.trigger_dialogue_event` → `send_rpc_server("rpc_trigger_dialogue_event", …)`, same client→server path as the wheel |
| Disable / recovery detection | polling `unit_data_system:read_component("character_state").state_name` each update and diffing it |
| Assisting an ally | `stop` on all four `AssistBaseInteraction` subclasses — Revive, PullUp, Rescue, RemoveNet — gated on a success result |
| Hearing a teammate's wheel line | `DialogueSystem._play_dialogue_event_implementation`, resolving `NetworkLookup.dialogue_names[dialogue_id]` to the rule name and the speaker via `unit_spawner:unit(go_id, …)` |
| Out of ammo | `Vo.out_of_ammo_event`, gated on an empty reserve |
| Low health | polled from the local player's `health_system` extension |
