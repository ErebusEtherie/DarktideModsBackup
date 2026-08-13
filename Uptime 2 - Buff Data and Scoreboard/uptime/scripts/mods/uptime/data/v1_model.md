# Uptime Mod Data Model

This document describes the current history-entry data model used by the Uptime mod for Warhammer 40,000: Darktide.

Although this file is still named `v1_model.md` in the mod tree, the current save format produced by `try_end_tracking()` is **version `4`**. Older unversioned entries may still be loaded by the history system, but newly saved entries use the structure documented here.

## Top-Level History Entry

A completed tracking session is saved as one JSON file in Uptime's history directory. The saved object has this shape:

```lua
{
    version = 4,

    buffs = {},      -- Dictionary of tracked buff data, keyed by buff title
    weapons = {},    -- Dictionary of weapon wield events, keyed by weapon display name
    damage = {},     -- Optional dictionary of scoreboard damage data, keyed by account_id
    loadouts = {},   -- Optional dictionary of team loadout data, keyed by account_id

    mission = {},    -- Mission timing and combat-window data
    mission_name = "dm_forge", -- Internal mission name from StateGameplay params

    meta_data = {
        mission_name = "dm_forge",
        player = "Player Name",
        account_id = "account-id-or-player-name",
        archetype = "veteran",
        mission_difficulty = "challenge_5", -- Or "Havoc Rank 25"
        mission_modifier = "circumstance_name", -- Or concatenated Havoc circumstances
        date = 1753640400,
        note = "Optional user note",
        favourite = true,
    },
}
```

### Runtime-Only Fields Added on Load

The following fields are not written by `try_end_tracking()`. They are added by the history I/O layer after loading a saved JSON file:

```lua
{
    file = "1753640400.json",
    file_path = ".../Fatshark/Darktide/uptime_history/1753640400.json",
}
```

These fields are used for updating or deleting existing history entries. They are temporarily removed when an edited entry is re-saved so they do not become part of the stored JSON payload.

## Versioning Notes

Current saves use `version = 4`.

The view currently treats weapon tracking as available when `tonumber(entry.version) > 2`. Damage and loadout data are present only when scoreboard tracking was enabled for that mission. If scoreboard tracking was disabled, `damage` and `loadouts` may be `nil`.

Legacy unversioned entries are still detected during load. The old migration path is minimal and should not be treated as a full schema conversion for new code.

## Mission Data Model

The `mission` field stores mission timing and local-player combat windows:

```lua
mission = {
    start_time = 123.45,
    end_time = 789.01,
    combats = {
        {
            start_time = 234.56,
            end_time = 239.56,
        },
        -- More combat windows...
    },
}
```

### Mission Fields

- `start_time`: Gameplay timer value when tracking started.
- `end_time`: Gameplay timer value when tracking ended.
- `combats`: Array of combat windows involving the local player.

Combat windows are created when the local player either attacks or is attacked. Each detected combat action extends the current combat window by 5 seconds. If the next combat action happens after the previous window has ended, a new combat window is created. When tracking ends, the final combat window is clamped so it cannot extend beyond `mission.end_time`.

## Metadata Model

The `meta_data` field stores mission-list and history-view information:

```lua
meta_data = {
    mission_name = "dm_forge",
    player = "Player Name",
    account_id = "account-id-or-player-name",
    archetype = "veteran",
    mission_difficulty = "challenge_5",
    mission_modifier = "circumstance_name",
    date = 1753640400,
    note = "Optional note text",
    favourite = true,
}
```

### Metadata Fields

- `mission_name`: Internal mission identifier from gameplay parameters.
- `player`: Local player's display name at save time.
- `account_id`: Local player's account id, falling back to player name if no account id is available.
- `archetype`: Local player's internal archetype name.
- `mission_difficulty`: Standard challenge id, or `Havoc Rank <rank>` for Havoc missions.
- `mission_modifier`: Standard circumstance name, or a `" • "`-separated list of Havoc circumstances.
- `date`: Numeric Unix-style timestamp from `mod.lib.os.time(mod.lib.os.date("*t"))`.
- `note`: Optional user-editable note. Newlines are converted to spaces and leading/trailing whitespace is trimmed.
- `favourite`: Optional boolean set by the history view. Favourite entries are protected from deletion and history-limit cleanup.

## Buffs Data Model

The `buffs` field is a dictionary keyed by buff title:

```lua
buffs = {
    ["Buff Title"] = {
        name = "Buff Title",
        icon = "content/ui/textures/icons/buffs/hud/example_icon",
        gradient_map = "content/ui/textures/color_ramps/talent_default",
        stackable = true,
        max_stacks = 3,
        events = {},

        -- Runtime tracking state stored in the save as currently implemented
        is_active = false,
        current_stack_count = 3,

        category = "talents",
        related_talents = {
            "talent_name_1",
            "talent_name_2",
        },
        related_item = nil,
    },
}
```

### Buff Fields

- `name`: Buff title as reported by the buff instance.
- `icon`: HUD icon path. Weapon trait buffs may use an item override icon when the template itself has no direct `hud_icon`.
- `gradient_map`: HUD icon gradient map from the buff template.
- `stackable`: Boolean derived from whether `max_stacks > 1`.
- `max_stacks`: Maximum stack count, including special handling for unique known maxima, dynamic stepped-stat buffs, and child buff templates.
- `events`: Ordered array of add/remove/stack-change events.
- `is_active`: Internal tracking state. Finalization sets this to `false` before saving because active buffs receive a closing `remove` event.
- `current_stack_count`: Last observed visual stack count.
- `category`: Buff template category. Uptime currently tracks `talents`, `weapon_traits`, and `talents_secondary`.
- `related_talents`: Optional template `related_talents` table.
- `related_item`: Optional item/blessing information for weapon-trait buffs.

### Buff Event Model

Buffs are tracked as event streams:

```lua
events = {
    {
        type = "add",
        time = 234.56,
        stack_count = 1,
    },
    {
        type = "stack_change",
        time = 245.67,
        stack_count = 2,
    },
    {
        type = "remove",
        time = 345.67,
    },
}
```

Event types:

- `add`: Buff became active.
- `stack_change`: Buff remained active but its visual stack count changed.
- `remove`: Buff became inactive or tracking ended while it was active.

Only `add` and `stack_change` events include `stack_count`.

### Buff Inclusion Rules

Uptime reads the player's actual buff extension rather than relying on the filtered HUD list. This allows it to see buffs hidden or moved by UI-filtering mods.

A buff is ignored when any of these are true:

- It has no usable HUD icon.
- Its `buff_category` is not one of `talents`, `weapon_traits`, or `talents_secondary`.
- Its visual stack count is zero.
- It is a negative buff.
- Vanilla HUD activity checks report it inactive.
- For persistent `proc_buff` templates with `active_duration`, `buff_instance:is_proc_active()` is false.

Timed proc buffs with normal `duration` are still tracked by ordinary add/remove presence because they are added and removed as active buff instances.

## Related Item Model

For weapon-trait buffs, `related_item` may contain the weapon and blessing that produced the buff:

```lua
related_item = {
    name = "Weapon Display Name",
    blessing = {
        name = "Blessing Display Name",
        description = "Blessing description text",
    },
}
```

If a matching blessing cannot be identified, `related_item.name` may still be present while `related_item.blessing` is `nil`.

## Weapons Data Model

The `weapons` field records local-player weapon wield state over time:

```lua
weapons = {
    ["Kantrael MG XII Infantry Lasgun"] = {
        name = "Kantrael MG XII Infantry Lasgun",
        events = {
            {
                type = "equipped",
                time = 125.00,
            },
            {
                type = "unequipped",
                time = 240.00,
            },
        },
    },
}
```

### Weapon Fields

- `name`: Localized/display weapon name from the item helper.
- `events`: Ordered array of wield state changes.

### Weapon Event Types

- `equipped`: Weapon slot was wielded.
- `unequipped`: Weapon slot was unwielded.

At tracking end, any weapon still marked as equipped receives a closing `unequipped` event at the mission end time.

## Damage Data Model

The `damage` field is optional. It is only started and saved when scoreboard tracking is enabled.

It is a dictionary keyed by player `account_id`, falling back to player name if no account id is available:

```lua
damage = {
    ["account-id"] = {
        name = "Player Name",
        archetype = "veteran",

        melee = 12345,
        ranged = 23456,
        blitz = 3456,
        dot = 4567,

        horde = 30000,
        elite = 8000,
        special = 6000,
        boss = 4000,
        total = 48000,

        damage_taken = 250,
        times_assisted = 2,
    },
}
```

### Damage Source Buckets

- `melee`: Damage classified as melee.
- `ranged`: Damage not classified as melee, blitz, or DoT.
- `blitz`: Damage classified as blitz by attack type or damage profile.
- `dot`: Damage classified as damage-over-time by damage profile.

### Damage Target Buckets

- `horde`: Damage to horde enemies, and fallback bucket for unknown target categories.
- `elite`: Damage to elite enemies.
- `special`: Damage to special enemies.
- `boss`: Damage to boss/monstrosity enemies.
- `total`: Total actual damage dealt to minions.

Target categories are derived from breed data. `breed.is_boss` takes priority over tags. Otherwise, Uptime checks `special`, `elite`, then `horde` tags, falling back to `horde` if classification fails.

### Other Scoreboard Metrics

- `damage_taken`: Delta of the player's cumulative damage value observed during health-extension fixed updates.
- `times_assisted`: Number of successful `pull_up`, `remove_net`, `revive`, or `rescue` interactions where that player was the interactee.

Damage tracking excludes bots by requiring `player:is_human_controlled()`.

### Damage Accounting Notes

Uptime attempts to account for actual damage dealt rather than blindly trusting reported overkill damage. It snapshots enemy health and clamps each damage event against the target's previous known health.

## Loadouts Data Model

The `loadouts` field is optional. It is captured when scoreboard tracking is enabled, and is keyed by the same `account_id` values used by `damage`:

```lua
loadouts = {
    ["account-id"] = {
        name = "Player Name",
        archetype = "veteran",
        is_human = true,
        icons = {},
        weapons = {},
    },
}
```

Only human-controlled players are included.

### Loadout Icon Model

`icons` is an ordered array of selected class-defining talents:

```lua
icons = {
    {
        category = "Blitz",
        valid = true,
        talent_id = "veteran_frag_grenade",
        icon = "content/ui/textures/icons/talents/veteran/example",
        gradient_map = "content/ui/textures/color_ramps/talent_blitz",
        display_name = "loc_talent_display_name",
    },
    {
        category = "Aura",
        valid = true,
        talent_id = "...",
        icon = "...",
        gradient_map = "content/ui/textures/color_ramps/talent_aura",
        display_name = "...",
    },
    {
        category = "Ability",
        valid = true,
        talent_id = "...",
        icon = "...",
        gradient_map = "content/ui/textures/color_ramps/talent_ability",
        display_name = "...",
    },
    {
        category = "Keystone",
        valid = true,
        talent_id = "...",
        icon = "...",
        gradient_map = "content/ui/textures/color_ramps/talent_keystone",
        display_name = "...",
    },
}
```

For archetypes with companions, the order is:

```lua
{ "Blitz", "Aura", "Ability", "Keystone", "Companion" }
```

For other archetypes, the order is:

```lua
{ "Blitz", "Aura", "Ability", "Keystone" }
```

### Loadout Icon Fields

- `category`: One of `Blitz`, `Aura`, `Ability`, `Keystone`, or `Companion`.
- `valid`: True when a non-empty icon path was found.
- `talent_id`: Talent id when one could be resolved.
- `icon`: Icon path.
- `gradient_map`: Gradient map path.
- `display_name`: Talent display name or fallback category label.

Icons are resolved from selected talent layout nodes first. Uptime falls back to `CharacterSheet.class_loadout()` data for base blitz/aura/ability talents, and uses a runtime ability-system icon fallback for combat abilities when needed.

### Loadout Weapon Model

`weapons` is an array containing primary and secondary weapon data:

```lua
weapons = {
    {
        slot = "slot_primary",
        icon = "content/ui/materials/icons/weapons/hud/example_weapon",
        display_name = "Weapon Display Name",
        description = "• Blessing One\n• Blessing Two",
    },
    {
        slot = "slot_secondary",
        icon = "content/ui/materials/icons/weapons/hud/example_weapon",
        display_name = "Weapon Display Name",
        description = "",
    },
}
```

### Loadout Weapon Fields

- `slot`: Usually `slot_primary` or `slot_secondary`.
- `icon`: Item HUD icon or fallback weapon icon.
- `display_name`: Localized master item display name where available, otherwise `"Weapon"`.
- `description`: Newline-separated bullet list of localized trait/blessing names where available.

## Scoreboard Display-Derived Fields

Raw saved `damage` entries do not contain formatted strings, percentage strings, ranking flags, archetype icons, or merged loadout rows. Those are derived by `uptime_view_data_handler.lua` and the shared scoreboard helpers at display time.

The seven team scoreboard rows are:

1. `horde`
2. `elite`
3. `special`
4. `boss`
5. `total`
6. `damage_taken`
7. `times_assisted`

For ranking/highlighting, higher is better for `horde`, `elite`, `special`, `boss`, and `total`. Lower is better for `damage_taken` and `times_assisted`.

## Complete Example

```lua
{
    version = 4,
    buffs = {
        ["Toughness Regen"] = {
            name = "Toughness Regen",
            icon = "content/ui/textures/icons/buffs/hud/toughness_regen",
            gradient_map = "content/ui/textures/color_ramps/talent_default",
            stackable = true,
            max_stacks = 3,
            events = {
                { type = "add", time = 120.00, stack_count = 1 },
                { type = "stack_change", time = 130.00, stack_count = 2 },
                { type = "remove", time = 180.00 },
            },
            is_active = false,
            current_stack_count = 2,
            category = "talents",
            related_talents = { "example_talent" },
            related_item = nil,
        },
        ["Weapon Trait Proc"] = {
            name = "Weapon Trait Proc",
            icon = "content/ui/textures/icons/traits/weapon/example_trait",
            gradient_map = "content/ui/textures/color_ramps/talent_default",
            stackable = false,
            max_stacks = 1,
            events = {
                { type = "add", time = 200.00, stack_count = 1 },
                { type = "remove", time = 205.00 },
            },
            is_active = false,
            current_stack_count = 1,
            category = "weapon_traits",
            related_talents = nil,
            related_item = {
                name = "Power Sword",
                blessing = {
                    name = "Brutal Momentum",
                    description = "Blessing description text",
                },
            },
        },
    },
    weapons = {
        ["Power Sword"] = {
            name = "Power Sword",
            events = {
                { type = "equipped", time = 100.00 },
                { type = "unequipped", time = 300.00 },
            },
        },
    },
    damage = {
        ["account-1"] = {
            name = "Veteran123",
            archetype = "veteran",
            melee = 10000,
            ranged = 25000,
            blitz = 1500,
            dot = 500,
            horde = 22000,
            elite = 6000,
            special = 5000,
            boss = 4000,
            total = 37000,
            damage_taken = 180,
            times_assisted = 1,
        },
    },
    loadouts = {
        ["account-1"] = {
            name = "Veteran123",
            archetype = "veteran",
            is_human = true,
            icons = {
                {
                    category = "Blitz",
                    valid = true,
                    talent_id = "veteran_frag_grenade",
                    icon = "content/ui/textures/icons/talents/veteran/example_blitz",
                    gradient_map = "content/ui/textures/color_ramps/talent_blitz",
                    display_name = "loc_talent_blitz_name",
                },
                {
                    category = "Aura",
                    valid = true,
                    talent_id = "veteran_aura_example",
                    icon = "content/ui/textures/icons/talents/veteran/example_aura",
                    gradient_map = "content/ui/textures/color_ramps/talent_aura",
                    display_name = "loc_talent_aura_name",
                },
                {
                    category = "Ability",
                    valid = true,
                    talent_id = "veteran_combat_ability_example",
                    icon = "content/ui/textures/icons/talents/veteran/example_ability",
                    gradient_map = "content/ui/textures/color_ramps/talent_ability",
                    display_name = "loc_talent_ability_name",
                },
                {
                    category = "Keystone",
                    valid = true,
                    talent_id = "veteran_keystone_example",
                    icon = "content/ui/textures/icons/talents/veteran/example_keystone",
                    gradient_map = "content/ui/textures/color_ramps/talent_keystone",
                    display_name = "loc_talent_keystone_name",
                },
            },
            weapons = {
                {
                    slot = "slot_primary",
                    icon = "content/ui/materials/icons/weapons/hud/powersword",
                    display_name = "Power Sword",
                    description = "• Brutal Momentum\n• Power Cycler",
                },
                {
                    slot = "slot_secondary",
                    icon = "content/ui/materials/icons/weapons/hud/lasgun",
                    display_name = "Infantry Lasgun",
                    description = "• Infernus",
                },
            },
        },
    },
    mission = {
        start_time = 100.00,
        end_time = 500.00,
        combats = {
            { start_time = 120.00, end_time = 180.00 },
            { start_time = 250.00, end_time = 320.00 },
        },
    },
    mission_name = "dm_hab_dreyko",
    meta_data = {
        mission_name = "dm_hab_dreyko",
        player = "Veteran123",
        account_id = "account-1",
        archetype = "veteran",
        mission_difficulty = "Havoc Rank 25",
        mission_modifier = "circumstance_1 • circumstance_2",
        date = 1753640400,
        note = "Testing weapon-trait uptime after the HUD icon fix.",
        favourite = true,
    },
}
```
