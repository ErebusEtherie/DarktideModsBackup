# Mortis Trials Buff Manager

Use native Mortis rewards and editable DIY talents in SoloPlay and Realms. One talent-pool page brings together preselection, progress rewards, competition rewards and room permissions.

Each starter talent has its own folder with JSON, Lua and resources. Hover any list row to read its details without selecting it. Package management enables or disables individual talent folders; reward settings remain separate.

## How to use

Enable the mod, close the original inventory and enter /mortisbuffs in chat. The Mortis page is available in all three reward modes. Before starting, choose a mode and switch the native and DIY pools on or off independently. Open Package manager to inspect automatically loaded packages, refresh new packages or export a starter package.

The talent list has four tabs with counts: Available, DIY, Selected and Unavailable. Available shows talents eligible for the current build and chosen native family; DIY shows all installed DIY entries, including unavailable ones. Selected shows saved choices, including those that have become unavailable. Unavailable shows excluded talents and their reasons. Filter native talents by Common, Class or Family, and type or paste a search. Tab counts follow the current search and category; Selected keeps the total number of saved choices visible. Scroll the talent list with the mouse wheel. In preselection mode, click a talent to add or remove it; selected rows use a check mark and gold highlighting. Hover a row or move keyboard/controller focus to it to inspect details. The right panel shows the description, weight, tier, acquired state and any players whose DIY definition is missing or different. Move the pointer over the detail panel to scroll long descriptions and player lists independently.

Batch actions mark individual entries or every filtered result, including entries outside the visible area. Choose My preselection to add or remove personal choices, or Room DIY pool to change permissions for everyone. Existing selections stay selected when added again. Entries that cannot be added are skipped with a changed/skipped count.

## Pool switches and host permissions

Native on + DIY on combines both sources. Native on + DIY off uses native rewards. Native off + DIY on uses only DIY. Both off grants neither source through the managed Mortis reward flow.

The native pool can only be enabled or disabled as a whole. The host cannot ban individual native talents; personal native preselection remains free within native eligibility and point limits. Only DIY entries have individual room permissions. The host can exclude one or many DIY talents from both manual preselection and random rewards. Permission changes retain saved choices for review in Selected; switching native family removes choices that are unavailable under the new configuration. Unavailable rows are grey, and only players with an affected saved/acquired choice receive a notice.

Every human Realms participant must confirm a matching definition for each DIY entry. A missing or different entry blocks that entry for the whole room, including the host. Other installed packages may differ; each shared entry requires the same package and dependencies, including Lua and resource bytes. Changing a weight also changes the definition. Player names and reasons appear in the detail panel. Connection and loading states are shown while confirmation is pending. Guests follow the host's switches, permissions and limits. Use the current Mortis release on all players.

Package management does not contain reward limits. In the Realms Mortis preparation controls, the host edits the independent DIY switch and point limit using minus/plus or direct numeric entry (0–99). Each DIY talent costs one point regardless of tier. SoloPlay has a separate Reward settings page. Tier is only a label; old saved tier quotas are ignored.

## Preselection

Choose a native family and add the desired native and DIY talents before the mission. The Family category follows the chosen route; compatible generic and class rewards remain available in their own categories. Actually switching family removes saved native and DIY talents that can no longer enter the pool, including DIY entries restricted to the previous family. Browsing tabs or categories does not change the family or remove choices. Open Selected to review and remove saved choices, or use Clear to remove every saved native and DIY choice. Native and DIY point counters remain separate. Native talents use the host's 0–99 point limit; DIY uses a separate 0–99 total limit, default six. Each talent consumes one slot in its own source. DIY selection respects equipment requirements and exclusive groups. Tier is a label only; each DIY talent costs one point, with no tier quota. Mission entry freezes package definitions, Lua, resources and saved preselection. Room configuration and current selections lock during the mission; refreshing or importing packages prepares the next mission. The list remains available for inspection.

Native pool eligibility follows the currently equipped Blitz, including upgraded Arbites grenades and Hive Scum flash grenades. Compatible grenade regeneration and extra-throw rewards appear according to that Blitz.

## Progress and competition

Whenever the native pool is enabled, the opening reward first chooses a native Mortis family and grants its foundation talent. Later rounds grant an available talent from that route and offer a non-route choice. With DIY enabled, those non-route candidates also include eligible DIY talents. With only DIY enabled, the opening is a DIY choice and there are no native family or automatic route rewards. DIY rewards consume these shared reward rounds; there is no additional random DIY opening grant.

Progress mode has ten rounds at the opening and path milestones 8%, 16%, 24%, 32%, 40%, 50%, 60%, 70% and 80%. Native route rewards can bring this to nineteen talents. Only-DIY play can award at most ten, also subject to DIY limits. Maps without a linear path use bounded objective events; Mortis Trials uses waves. Time alone grants no rounds.

Competition gives each player personal kill progress; each 100% earns another round, up to the host's 0–99 round limit including the opening. Defaults: ordinary enemies 0.25%, specialists 5%, elites 2.5%, bosses 40%, weakened bosses 20%, captains/twins 50%. Bot kills do not count. Kill weights support two decimal places. Choose a local bar, bar with percentage, percentage only or hidden indicator. Earned quotas stop further counting while queued rewards finish.

Choose cards with Ctrl+1, Ctrl+2 or Ctrl+3. A choice has sixty seconds, then the host picks randomly; queued choices get a fresh timer after the previous award presentation. Competition automatically grants its last sole candidate. Acquired talents are excluded from future draws. In all modes the catalog remains accessible. Native acquired Buffs also appear in the native Tab list; the unified catalog shows acquired DIY talents.

## DIY templates and probability

Packages load automatically at startup. Place one complete folder per package in the corresponding package directory; use Refresh packages after adding or editing files in game. The starter contains twelve entries. Complete data and executable Lua examples are included in docs/diy/package-examples. Supported effects include passive stats, native keywords, conditional events, temporary layers, resource changes and audited native statuses. Native reinforcement requests require Havoc Enemy Director; native pacing pause actions require Havoc Condition Manager. Ordinary Mortis DIY talents do not require either mod.

An entry's weight ranges from 0 to 1000 and defaults to 1; positive fractions are allowed. Zero excludes random offers but still permits manual preselection. Mixed non-route draws give each native candidate weight 1 and each DIY candidate its configured weight. Each slot samples without replacement from the remaining eligible entries: weights 1, 2 and 7 give first-slot probabilities of 10%, 20% and 70%. These are relative weights, not guaranteed whole-card appearance percentages. Native-only play retains native category weighting. DIY random awards obey total and exclusive-group limits, checked again after every grant.

The Fivefold salvo example creates five copies of a ranged attack, including staff attacks, while paying the original ammunition, warp-charge or overheat cost once. Native extra projectiles multiply: a Surge critical shot creates ten projectiles. Shotgun copies reuse the native pellet pattern. Flame and lightning repeat native hit pulses, with native status limits. The ranged_salvo_count modifier accepts integers 1–5, is Mortis-only and combines by maximum rather than multiplying multiple copies of the talent.

Package IDs, versions, dependencies, conflicts and capabilities are validated. Selected local Lua runs on the authority with separate module environments, resource snapshots and cleanup callbacks. Package updates apply next mission. JSON, Lua, resources and dependency fingerprints participate in Mortis room compatibility; network messages never carry executable Lua. Three-language API guides and complete examples are included.

## Requirements and installation

Requires Darktide Mod Loader, Darktide Mod Framework and SoloPlay. Realms is optional for player-hosted co-op. English, Simplified Chinese and Traditional Chinese follow the game language. The DMF option Enable custom Mortis Buffs controls the native source; the unified page provides both source switches. Disabling the mod removes its controls and effects while retaining saved data. Other mods replacing the same Mortis reward flow may conflict.

### Vortex installation

- Close the game, import the ZIP using Install From File, enable it and Deploy Mods.
- Place MortisBuffManager after SoloPlay in Load Order; enable Realms for co-op.

### Manual installation

- Close the game and extract the ZIP into Darktide/mods, producing mods/MortisBuffManager.
- Add MortisBuffManager after SoloPlay in mods/mod_load_order.txt.
- Start the game, enable the mod and configure its talent pools.

SoloPlay and Realms: deluxghost. Native Mortis systems and materials: Fatshark.

Authored DIY entries can declare external textures, fonts, videos, cursors, icon albums and compiled engine resources. SimpleAssets is an optional resource-loading dependency and must load before this manager when those assets are used. Each entry keeps its own files; active missions retain a frozen copy. The included resource guide explains loading, local view cleanup and native format limits. Ordinary entries do not require SimpleAssets.


[DIY guide](diy/GUIDE.en.md)
