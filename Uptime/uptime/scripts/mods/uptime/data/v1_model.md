# Uptime Mod Data Model (v1)

This document describes the data model used by the Uptime mod for tracking buff and mission data in Warhammer 40,000: Darktide.

## Top-Level Structure

The object returned by `try_end_tracking()` has the following structure:

```
{
    version = "2",
    buffs = {}, -- Object containing all tracked buffs
    mission = {}, -- Mission tracking data
    mission_name = "Mission Name",
    meta_data = {
        mission_name = "Mission Name",
        player = "Player Name",
        mission_difficulty = "Challenge Level",
        mission_modifier = "Circumstance Name",
        date = "YYYY-MM-DD HH:MM:SS",
    },
}
```

## Mission Data Model

The `mission` field contains tracking data for the mission:

```
{
    start_time = 123.45, -- Timestamp when mission tracking started
    end_time = 789.01, -- Timestamp when mission tracking ended
    combats = { -- Array of combat sections
        {
            start_time = 234.56, -- Timestamp when combat started
            end_time = 345.67 -- Timestamp when combat ended
        },
        -- More combat sections...
    }
}
```

### Combat Sections

Combat sections are automatically tracked when the player engages in combat. Each combat section has:

- `start_time`: The timestamp when combat was detected
- `end_time`: The timestamp when combat ended

Combat is detected when the player attacks an enemy or is attacked by an enemy. The combat window extends for 10 seconds after each combat action. Multiple combat actions within this window will extend the combat duration.

## Buffs Data Model

The `buffs` field contains a dictionary of all tracked buffs, with the buff name as the key:

```
{
    "Buff Name 1": {
        name = "Buff Name 1",
        icon = "path/to/icon", -- Icon path for UI display
        gradient_map = "path/to/gradient", -- Gradient map for UI display
        stackable = true, -- Whether the buff can stack
        max_stacks = 3, -- Maximum number of stacks for this buff
        events = { -- Array of buff events
            {
                type = "add", -- Buff was added
                time = 234.56, -- When the event occurred
                stack_count = 1 -- Initial stack count
            },
            {
                type = "stack_change", -- Stack count changed
                time = 245.67,
                stack_count = 2
            },
            {
                type = "remove", -- Buff was removed
                time = 345.67
            },
            -- More events...
        },
        category = "talents", -- Buff category (talents, weapon_traits, talents_secondary)
        related_talents = { -- Array of related talents (if applicable)
            "talent_name_1",
            "talent_name_2"
        },
        related_item = { -- Information about the item that provides this buff (if applicable)
            name = "Item Name",
            blessing = {
                name = "Blessing Name",
                description = "Blessing Description"
            }
        }
    },
    -- More buffs...
}
```

### Buff Events

Each buff is tracked using an event-based system. Events are recorded when:

1. A buff is added (`type = "add"`)
2. A buff's stack count changes (`type = "stack_change"`)
3. A buff is removed (`type = "remove"`)

This event-based approach allows for:
- Precise tracking of when buffs are active
- Tracking individual stack changes
- Calculating uptime and average stacks from event data
- Supporting analytics on buff timing and patterns

### Buff Categories

Buffs are categorized into:
- `talents`: Buffs from character talents
- `weapon_traits`: Buffs from weapon traits/blessings
- `talents_secondary`: Buffs from secondary talents

### Related Items

For buffs that come from items (typically weapons), the `related_item` field provides:
- `name`: The name of the item
- `blessing`: Information about the blessing that provides the buff
  - `name`: The name of the blessing
  - `description`: The description of the blessing

## Example

Here's a simplified example of the complete data structure:

```
{
    version = "2",
    buffs = {
        ["Toughness Regen"] = {
            name = "Toughness Regen",
            icon = "path/to/icon",
            gradient_map = "path/to/gradient",
            stackable = true,
            max_stacks = 3,
            events = {
                { type = "add", time = 123.45, stack_count = 1 },
                { type = "stack_change", time = 134.56, stack_count = 2 },
                { type = "stack_change", time = 145.67, stack_count = 3 },
                { type = "remove", time = 234.56 }
            },
            category = "talents",
            related_talents = { "toughness_regen_talent" },
            related_item = nil
        },
        ["Damage Boost"] = {
            name = "Damage Boost",
            icon = "path/to/icon",
            gradient_map = "path/to/gradient",
            stackable = false,
            max_stacks = 1,
            events = {
                { type = "add", time = 200.12, stack_count = 1 },
                { type = "remove", time = 300.34 }
            },
            category = "weapon_traits",
            related_talents = nil,
            related_item = {
                name = "Power Sword",
                blessing = {
                    name = "Brutal Momentum",
                    description = "Consecutive hits increase damage"
                }
            }
        }
    },
    mission = {
        start_time = 100.00,
        end_time = 500.00,
        combats = {
            { start_time = 120.00, end_time = 180.00 },
            { start_time = 250.00, end_time = 320.00 }
        }
    },
    mission_name = "Hab Dreyko Purge",
    meta_data = {
        mission_name = "Hab Dreyko Purge",
        player = "Zealot123",
        mission_difficulty = "Damnation",
        mission_modifier = "Darkness",
        date = "2025-07-27 19:20:00",
    }
}
```