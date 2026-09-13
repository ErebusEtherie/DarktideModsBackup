-- preset.lua
--
-- Curated bot personas. v0.22.8 pivots the underlying technique after
-- v0.22.0 through v0.22.7 all failed to make a synthetic profile actually
-- render as a Zealot: our name / archetype / talents mutations either
-- silently dropped (archetype), got overwritten downstream
-- (generate_random_name replaces profile.name), or applied to the profile
-- table without changing what the bot renders as. Tertium 4/5's source
-- (mods/183) proves that a working bot swap does NOT synthesize a
-- profile, it substitutes the whole profile parameter with a
-- fully-resolved real character profile from the backend cache. That is
-- what v0.22.8 does.
--
-- ===========================================================================
-- HOW A PRESET APPLIES (v0.22.8 rewrite)
-- ===========================================================================
--
-- 1. On boot we hook ProfilesService:fetch_all_profiles. Every time the
--    game fetches your saved characters (which it does whenever the
--    character list is opened, and whenever we manually poke it after a
--    state change), we copy each returned profile into _profile_cache
--    keyed by character_id.
--
-- 2. Each preset in the catalogue has an optional source_character_id.
--    You bind it with /pil_preset_capture_char <preset_id> after
--    selecting the character you want the bot modeled on (typically a
--    Zealot with the loadout / talents / appearance you want the bot to
--    inherit).
--
-- 3. When a bot is about to spawn (BotSynchronizerHost:add_bot fires),
--    we resolve which preset that bot slot wants, look up the source
--    character in _profile_cache, deep-clone the cached profile, apply
--    name + voice overrides on the clone, and hand THAT profile to
--    add_bot instead of the default bot profile. Because the source
--    profile is a real backend character, it already has every field
--    Fatshark's spawn pipeline needs (archetype, talents, loadout,
--    visual_loadout, gestalts, unit_data, and so on), so nothing has to
--    be synthesized.
--
-- 4. Fatshark's spawn later calls ProfileUtils.generate_random_name on
--    the bot's profile, which by default replaces profile.name with a
--    random bot name. We hook that too: if profile.original_name is set
--    (we stamp it during the clone), we return it verbatim so the bot
--    keeps the preset's display name instead of getting a random one.
--
-- What Kaizen needs to do once, per preset:
--   /pil_preset_source_list           see your cached characters
--   /pil_preset_capture_char <preset> pin the currently-selected
--                                     character as the preset source
--
-- ===========================================================================
-- BINDING MODEL (unchanged from v0.22.0)
-- ===========================================================================
--
--   default preset   applies to EVERY bot slot. Debug / testing shortcut.
--                    /pil_preset_default sister_argenta = force her onto
--                    every bot in the party until cleared.
--   per-slot binds   /pil_preset_bind 2 sister_argenta = only bot in
--                    slot 2 uses this preset. Slots 1-6 per M.MAX_SLOTS
--                    in bots.lua. Higher slots need penance / Ordos
--                    unlocks.
--
-- The slot counter resets on StateLoading enter (Pilgrimage.lua's
-- on_game_state_changed handler calls M.reset_spawn_counter there,
-- since the DMF Lua VM actually persists across missions and the
-- counter would otherwise accumulate). Bot death + respawn edge case
-- within a single mission is still not handled (documented on
-- _spawn_counter below).

local M = {}

local _mod
local _shared
local _penances
local _shop
local _debug_log
local _hooks
local _realms_bridge

-- ===========================================================================
-- Profile copy notes (v0.22.10)
-- ===========================================================================
--
-- v0.22.8 deep-copied the entire cached profile and passed the clone to
-- add_bot. Crashed on mission load because a naive deep-copy strips
-- metatables from nested tables (item instances, archetype table), and
-- Fatshark's spawn pipeline later invoked methods on those metatable-less
-- tables which no longer had methods.
--
-- v0.22.9 shifted to a top-level shallow copy (nested tables kept their
-- metatables via shared references). Safer than deep-copy but replaced
-- Fatshark's own vanilla bot profile wholesale, which the spawn pipeline
-- may not expect (the vanilla profile carries cosmetic slots, body data,
-- and visual_loadout already set up correctly).
--
-- v0.22.10 follows Better Bots' proven pattern
-- (github.com/hummat/BetterBots/blob/main/scripts/mods/BetterBots/bot_profiles.lua):
-- MUTATE the vanilla profile in place, only overwriting the class-identity
-- fields we care about. Fresh {} containers for talents / loadout_item_data
-- so per-bot state is isolated; MasterItems entries and the archetype
-- table are shared by reference (BB does exactly this and it works).
-- The two helpers below serve that mutation path.

-- ===========================================================================
-- Sister Argenta preset (metadata only in v0.22.8)
-- ===========================================================================
--
-- The talents / loadout tables here are kept as informational reference
-- (they document what the "canonical" Sister Argenta build looks like)
-- but they are NOT applied to the bot in this version. The bot inherits
-- everything from the source character's real backend profile, which is
-- captured via /pil_preset_capture_char. Kaizen: build a Zealot with the
-- talents and loadout below and capture her as the source, and the bot
-- will render exactly like your character but named Sister Argenta with
-- the Judge Female voice.

local SISTER_ARGENTA = {
    -- v0.22.52 (2026-08-09): custom_title test. Argenta gets "Blessed
    -- Sororitas" as her nameplate title, keeping the rarity and colour
    -- inherited from the source character's real title item. When
    -- custom_title is a plain string, apply_source_to_profile flips
    -- profile._pilgrimage_custom_title on and our ProfileUtils hook
    -- swaps ONLY the text at render time (rarity/color path untouched,
    -- so it renders in whatever colour the source's title had at
    -- whatever the user's colour-mode setting is).
    id             = "sister_argenta",
    -- v0.22.56: switched from plain string to { text, color } table so
    -- the gold is guaranteed. Rarity 5 gold matches the game's own
    -- highest-tier title colour (Fatshark uses roughly {255, 215, 100}
    -- for legendary titles in the rarity table). Field test with the
    -- string form showed source-inherited colour path returned plain
    -- white for this specific captured character.
    custom_title   = { text = "Blessed Sororitas", color = { 255, 215, 100 } },
    display_name   = "Sister Argenta",
    role_designation = "Battle Sister",
    fixed_legendary = "hordes_buff_veteran_infinite_ammo_during_stance",
    -- v0.22.53 (2026-08-09): reclassed to Veteran per Kaizen's field-
    -- test call — Argenta plays as a ranged-focused Sororitas so a
    -- Veteran captured source lines up better with her intended
    -- behaviour than a Zealot did. Voice stays zealot_female_c (Judge
    -- Female) — cross-class picks land through the PP v5.1 relaxed
    -- guard as of Session B iteration.
    archetype_name = "veteran",
    gender         = "female",
    selected_voice = "zealot_female_c",
    unlock_penance = "pilgrim_unshakeable_faith",

    -- Bot passive stack:
    --   Universal (all bots): pilgrim_expanded_coherency (+300% radius)
    --   Tier 3 (Champion):    pilgrim_champion_might
    --   Preset specifics:     pilgrim_faith_shield (corruption immunity)
    --                         pilgrim_beacon_boon (Mortis Trials
    --                                              coherency corruption
    --                                              healing aura, stacks
    --                                              with her Beacon of
    --                                              Purity talent)
    -- All applied at bot spawn via the Tick pump (0.5s interval,
    -- one apply per passive per bot, then marked done).
    tier           = 3,
    passives       = {
        "pilgrim_faith_shield",
        "pilgrim_beacon_boon",
    },

    -- Kept as reference so a future "overlay talents on cloned profile"
    -- pass can pull from here. Not applied in v0.22.8.
    reference_talents = {
        base_melee_damage_node_buff_medium_4 = 1,
        base_movement_speed_node_buff_low_4 = 1,
        base_toughness_damage_reduction_node_buff_medium_1 = 1,
        base_toughness_node_buff_medium_2 = 1,
        zealot_additional_wounds = 1,
        zealot_backstab_damage = 1,
        zealot_backstab_periodic_damage = 1,
        zealot_bolstering_prayer = 1,
        zealot_channel_grants_toughness_damage_reduction = 1,
        zealot_corruption_healing_coherency_improved = 1,
        zealot_damage_boosts_movement = 1,
        zealot_damage_vs_nonthreat = 1,
        zealot_dash = 1,
        zealot_flame_grenade = 1,
        zealot_hits_grant_stacking_damage = 1,
        zealot_increased_crit_and_weakspot_damage_after_dodge = 1,
        zealot_increased_damage_vs_resilient = 1,
        zealot_martyrdom = 1,
        zealot_martyrdom_grants_toughness = 1,
        zealot_martyrdom_toughness_modifier = 1,
        zealot_more_damage_when_low_on_stamina = 1,
        zealot_offensive_vs_many = 1,
        zealot_reduced_damage_after_dodge = 1,
        zealot_resist_death = 1,
        zealot_resist_death_healing = 1,
        zealot_restore_stealth_cd_on_damage = 1,
        zealot_revive_speed = 1,
        zealot_shock_grenade = 1,
        zealot_toughness_damage_coherency = 1,
        zealot_toughness_on_dodge = 1,
        zealot_toughness_on_heavy_kills = 1,
        zealot_uninterruptible_no_slow_heavies = 1,
        zealot_weakspot_damage_reduction = 1,
    },
}

-- v0.22.35: three new tier-3 presets built on Rogue Trader companions.
-- All share the universal + tier-3 stack (coherency + champion might),
-- each carries one thematic signature passive on top.

local MAGOS_HANEUMANN = {
    id             = "magos_haneumann",
    -- v0.22.57 (2026-08-09): full name + custom title.
    -- ID stays `magos_haneumann` for backward compat with any saved
    -- capture. Title tier-3 gold per the convention.
    display_name   = "Pasqal Haneumann",
    role_designation = "Magos Explorator",
    fixed_legendary = "pilgrim_legendary_doctrina_override",
    custom_title   = { text = "Magos Explorator", color = { 255, 215, 100 } },
    -- Skitarius. Fatshark's archetype id for the Skitarii class is
    -- "cryptic"; PP's data mapping (CLASSES table) confirms:
    -- cryptic voices are `cryptic_a..d`, and PP's own labels map
    -- a=Pathfinder, b=Reverent, c=Exterminator, d=Hunter.
    archetype_name = "cryptic",
    gender         = "male",
    -- Kaizen chose Pathfinder for the tech-priest voice. cryptic_a
    -- per PP's CLASSES table (PersonalityPicker.lua line 32).
    selected_voice = "cryptic_a",
    unlock_penance = "pilgrim_haneumann_parent",

    tier           = 3,
    passives       = {
        "pilgrim_voltaic_master",
        "pilgrim_pasqal_omnispex",
    },
}

local SPINNER_KIBELLAH = {
    id             = "spinner_kibellah",
    -- v0.22.94 (Kaizen): the Death Cult assassin touches no gun.
    weapon_ban     = "ranged",
    -- v0.22.57: display name dropped the "Spinner" prefix per Kaizen.
    -- ID stays `spinner_kibellah` (historical / saved-capture friendly).
    -- The "Spinner" concept lives on in the custom title instead.
    display_name   = "Kibellah",
    role_designation = "Bloodspun Web Assassin",
    fixed_legendary = "pilgrim_legendary_shadow_emperor",
    custom_title   = { text = "Second Spinner", color = { 255, 215, 100 } },
    archetype_name = "zealot",
    -- male base rig same reason as Argenta: base Zealot preset lines
    -- up cleanest with NPC Look overlays on the male rig.
    gender         = "male",
    -- Judge (female). Same voice as Argenta; Kaizen picked it
    -- deliberately for Kibellah.
    selected_voice = "zealot_female_c",
    unlock_penance = "pilgrim_dancing_on_the_web",

    -- v0.22.37: keeps Indefatigable (2 extra wounds) AND layers
    -- Spinner's Edge on top. Kaizen rebuilt Kibellah to run
    -- Martyrdom natively on the captured character's talent tree, so
    -- the mod side stacks two Pilgrimage passives on top of that:
    --   * pilgrim_indefatigable  — +2 wounds (Fatshark hordes buff),
    --                              exactly the stat Martyrdom scales
    --                              with.
    --   * pilgrim_kibellah_edge  — +50% attack speed, +50% crit
    --                              chance, +35% crit damage (custom
    --                              stat_buffs, no Fatshark template).
    tier           = 3,
    passives       = {
        "pilgrim_indefatigable",
        "pilgrim_kibellah_edge",
    },
}

local SOLOMORNE = {
    id             = "solomorne",
    -- v0.22.57: full surname; "Proctor Exactant" moved from the
    -- prefix on display_name to the custom_title. That matches the
    -- naming convention Kaizen locked for tier-3 (name in the
    -- nameplate main line, in-fiction rank in the title). Gold per
    -- the tier convention.
    display_name   = "Solomorne Anthar",
    role_designation = "Proctor Exactant",
    custom_title   = { text = "Champion of the Lex", color = { 255, 215, 100 } },
    fixed_legendary = "pilgrim_legendary_dog_and_thunder",
    -- Arbitrator. Fatshark id for the Arbites/Adamant class is
    -- "adamant"; PP's CLASSES row confirms voices
    -- adamant_male_a/b/c and adamant_female_a/b/c.
    archetype_name = "adamant",
    gender         = "male",
    -- Authoritarian voice: reasonable default for a lawman.
    -- PersonalityPicker.lua line 30 lists adamant_male_a as first in
    -- the class; PP's own labels doc maps _a=Authoritarian.
    selected_voice = "adamant_male_a",
    unlock_penance = "pilgrim_warrant_served",

    tier           = 3,
    passives       = {
        "pilgrim_castigator_immortal",
        "pilgrim_solomorne_blood_warrant",
    },

    -- v0.22.36: name the dog. HumanPlayer:companion_name (which
    -- BotPlayer inherits) reads profile.companion.name; the nameplate
    -- HUD element updates on event_update_player_name. Our
    -- apply_source_to_profile overrides profile.companion.name with
    -- this string after deep-copying the captured character's
    -- companion table, so the dog on Solomorne's bot renders as
    -- "Glaito" wherever the nameplate draws.
    companion_name = "Glaito",

    -- v0.22.35: Solomorne's dog companion is a Fatshark-native
    -- feature of the Adamant class; when Kaizen captures a real
    -- Adamant character as this preset's source (via
    -- /pil_preset_capture_all), the profile carries its companion
    -- reference (profile.companion) and our clone preserves it. So
    -- the dog comes along automatically without a mod-side spawn
    -- pass. If Kaizen wants a specific dog appearance, that's
    -- captured via NPC Look's own extras on the source character
    -- and lands in npclook_extra_slots as normal.
}

-- v0.22.40: fifth Rogue Trader companion. Psyker with Savant voice.
local INTERROGATOR_HEINRIX = {
    id             = "interrogator_heinrix",
    -- v0.22.57: full surname; "Interrogator" moved to the title.
    -- ID stays `interrogator_heinrix` (historical). Gold per tier-3 convention.
    display_name   = "Heinrix van Calox",
    role_designation = "Inquisitorial Biomancer",
    fixed_legendary = "pilgrim_legendary_overwhelming_mind",
    custom_title   = { text = "Interrogator", color = { 255, 215, 100 } },
    archetype_name = "psyker",
    gender         = "male",
    -- v0.22.78 (2026-08-10): voice changed from Savant Male
    -- (psyker_male_c) to Agitator Male (zealot_male_a) per Kaizen,
    -- riding PP v5.21's new full cross-class ability support (built in
    -- his PP session the same day). Cross-class pick lands through the
    -- PP v5.1+ relaxed guard, and the new ability/blitz callout system
    -- means Heinrix now calls out his Psyker abilities in the Zealot
    -- Agitator's voice instead of going silent on them.
    selected_voice = "zealot_male_a",
    unlock_penance = "pilgrim_biolightning",

    -- v0.22.41: Biomancer/Smite build. Three signature passives on
    -- top of tier 3 base:
    --   * pilgrim_heinrix_biolightning  Smite always at max charge
    --     (Fatshark hordes_buff_psyker_smite_always_max_damage).
    --     Solves "will the bot know to Scrier's-Gaze before Smite" by
    --     making the answer "doesn't matter, always max".
    --   * pilgrim_heinrix_regen         Enhanced Fast Metabolism
    --     (3% max HP per 5s, custom interval buff).
    --   * pilgrim_heinrix_reactive_heal Heals 3% max HP whenever hit,
    --     2s cooldown between heals (custom proc buff).
    -- v0.22.43: Full Biolightning restored (Kaizen: keep both the
    -- Fatshark full-charge boon AND the +200% smite damage layered on
    -- top). Result: every Smite fires at Scrier's-Gaze charge level
    -- with triple damage.
    -- v0.22.44: pilgrim_heinrix_undying_warp added. Kaizen's request
    -- was "make him channel Smite longer or auto-cast Scrier's Gaze so
    -- he doesn't overload". Making a bot behavior-tree auto-time a
    -- stance ability before Smite is deep Fatshark BT surgery; the
    -- mod-side answer that produces the SAME outcome is to remove the
    -- overload risk entirely. warp_charge_amount_smite = 0.05 means
    -- Smite generates 5% of normal Peril, so Heinrix never overloads
    -- no matter how long the bot chooses to hold the channel.
    tier           = 3,
    passives       = {
        "pilgrim_heinrix_full_charge",
        "pilgrim_heinrix_biolightning",
        "pilgrim_heinrix_undying_warp",
        "pilgrim_heinrix_regen",
        "pilgrim_heinrix_reactive_heal",
    },
}

-- v0.22.44: Rogue Trader Seneschal.
-- v0.22.53 (2026-08-09): reclassed to Zealot per Kaizen's field-test
-- call — Abelard's core RT identity is melee prowess (chain axe / power
-- weapon combos), so a Zealot captured source lines up better than a
-- Veteran did. Voice stays veteran_male_a (Professional Male) —
-- cross-class pick lands via the PP v5.1 relaxed guard.
local SENESCHAL_ABELARD = {
    id             = "seneschal_abelard",
    -- v0.22.95: Practiced Steel (plain stat, confirmed spec); his three
    -- aura/conditional passives ship with the aura-engine batch.
    passives       = { "pilgrim_practiced_steel" },
    -- v0.22.57: full surname; "Seneschal" moved to the title.
    -- ID stays `seneschal_abelard` (historical). Gold per tier-3 convention.
    display_name   = "Abelard Werserian",
    role_designation = "Dynastic Seneschal",
    fixed_legendary = "pilgrim_legendary_pilgrims_momentum",
    custom_title   = { text = "The Seneschal", color = { 255, 215, 100 } },
    archetype_name = "zealot",
    gender         = "male",
    selected_voice = "veteran_male_a",
    unlock_penance = "pilgrim_in_lord_captains_service",  -- v0.22.53
    tier           = 3,
}

-- v0.22.44: broker (Hive Scum in-game) preset. Kaizen wanted the
-- quoted title if the display string tolerates it; Darktide's HUD
-- uses Freetype-rendered UTF-8, so ASCII double quotes render
-- correctly. The id has no quotes because it's used as a DMF
-- settings key (KEY_SOURCE_PREFIX .. id) and as a preset lookup key;
-- keeping it plain avoids escaping surprises later.
local PRINCESS_JAE = {
    id             = "princess_jae",
    -- v0.22.96: confirmed kit; Sleight of Hand is aura-engine-driven.
    passives       = { "pilgrim_silver_tongue", "pilgrim_serpents_reflex" },
    -- v0.22.57: dropped the quoted "Princess" moniker; her surname
    -- becomes the main display line, "Cold Trader" is the title.
    -- ID stays `princess_jae` (historical). Gold per tier-3 convention.
    display_name   = "Jae Heydari",
    role_designation = "Cold Trader",
    custom_title   = { text = '"Princess"', color = { 255, 215, 100 } },
    fixed_legendary = "pilgrim_legendary_house_edge",
    -- Fatshark id for the Hive Scum class is "broker".
    -- v0.22.50: voice changed from broker_female_a (Outlaw) to
    -- veteran_female_b (Loose Cannon Female) per Kaizen's field-test
    -- feedback. Cross-archetype voice works: PP's extensions_ready
    -- rewrites the dialogue extension's selected_voice regardless of
    -- the profile's archetype, and Jae's dialogue rules resolve
    -- against her Hive Scum class while the sound bank comes from
    -- the Veteran Loose Cannon Female voice bank.
    archetype_name = "broker",
    gender         = "female",
    selected_voice = "veteran_female_b",
    unlock_penance = "pilgrim_silver_tongued",  -- v0.22.49
    tier           = 3,
}

-- v0.22.54 (2026-08-09): eighth Rogue Trader companion. Psyker with
-- Female Seer voice (psyker_female_b per PP CLASSES table).
-- Signature passives + unlock penance TBD; Kaizen will iterate. She
-- coexists in the catalogue with Interrogator Heinrix (also Psyker),
-- but the one-per-class binding gate in bind_slot means only one of
-- them can be slotted at a time.
local IDIRA_TLASS = {
    id             = "idira_tlass",
    display_name   = "Idira Tlass",
    role_designation = "Unsanctioned Diviner",
    fixed_legendary = "pilgrim_legendary_warp_resonance",
    -- v0.22.57: gold custom title per tier-3 convention.
    custom_title   = { text = "Her Lordship's Telepath", color = { 255, 215, 100 } },
    archetype_name = "psyker",
    gender         = "female",
    selected_voice = "psyker_female_b",
    -- v0.22.80: Unsanctioned Fury (Fanatic+ mission, 20+ elite/special
    -- kills by Peril overload detonation), specced by Kaizen.
    unlock_penance = "pilgrim_unsanctioned_fury",
    tier           = 3,
    -- v0.22.80: full signature kit, Kaizen-approved with changes. The
    -- volatile unsanctioned psyker: +30% warp damage, ranged kills
    -- detonate, -60% Peril generation (Kaizen tuned from the proposed
    -- 90%), +3 wounds, and Perilous Vessel (10% chance on taking HP
    -- damage to trigger a Perils detonation that hurts everything
    -- around her plus 25% of her own health; never knocks her down,
    -- Crystalline Will style).
    passives       = {
        "pilgrim_idira_warp_torrent",
        "pilgrim_idira_unstable_wake",
        "pilgrim_idira_dampened_conduit",
        "pilgrim_idira_thrice_bound",
        "pilgrim_idira_perilous_vessel",
    },
}

-- v0.22.55 (2026-08-09): ninth Rogue Trader companion — the Lord
-- Captain herself. Veteran, Loose Cannon Female voice
-- (veteran_female_b, same voice Jae uses on a cross-class pick;
-- Theodora is same-class so PP applies it without the wrong-class
-- warning). custom_title = "Lord Captain" overrides the nameplate
-- title text at render time via the ProfileUtils hook installed in
-- Pilgrimage.lua; source character's rarity/colour formatting is
-- preserved. Signature passives + unlock penance TBD.
--
-- Coexists with Sister Argenta (also Veteran as of v0.22.53) in the
-- catalogue; one-per-class enforcement blocks both being slotted at
-- once.
local THEODORA_VON_VALANCIUS = {
    id             = "theodora_von_valancius",
    display_name   = "Theodora von Valancius",
    role_designation = "Rogue Trader",
    fixed_legendary = "hordes_buff_veteran_apply_infinite_bleed_on_shout",
    -- v0.22.56: gold, matching Argenta's Blessed Sororitas. The Lord
    -- Captain rank deserves legendary-tier colour.
    custom_title   = { text = "Lord Captain", color = { 255, 215, 100 } },
    archetype_name = "veteran",
    gender         = "female",
    selected_voice = "veteran_female_b",
    -- v0.22.80: A Rogue Trader's Fortune (amass 20k OR lifetime-spend
    -- 20k Ordos), specced by Kaizen. Thresholds pending economy audit.
    unlock_penance = "pilgrim_rogue_traders_fortune",
    tier           = 3,
    -- v0.22.80: partial signature kit. Duellist's Poise here; Dynastic
    -- Largesse (+50% Ordos earned while she's in the warband) is
    -- wallet-side (wallet.lua SLOTTED_PRESET_MULTIPLIERS), not a buff;
    -- Lord Captain's Standard (coherency +10% damage aura) is specced
    -- in the roadmap and ships with Abelard's aura batch.
    passives       = {
        "pilgrim_theodora_duellist_poise",
    },
}

-- v0.22.78 (2026-08-10): tenth Rogue Trader companion, the ship's
-- Navigator. Psyker with Savant Female voice (psyker_female_c,
-- same-class pick). Joins Idira and Theodora in the bare-tier3 queue:
-- no signature passives and no unlock penance yet, Kaizen will iterate.
-- Third Psyker in the catalogue (Heinrix, Idira, Cassia); one-per-class
-- enforcement means only one of them can be slotted at a time.
local CASSIA_ORSELLIO = {
    id             = "cassia_orsellio",
    display_name   = "Cassia Orsellio",
    role_designation = "Navis Nobilite Navigator",
    fixed_legendary = "hordes_buff_psyker_shock_on_touch_force_field",
    -- v0.22.95: first third of her kit (plain stat); Gaze of the Third
    -- Eye and Tisiphone's Discipline ship with the aura-engine batch.
    passives       = { "pilgrim_navigators_focus", "pilgrim_gaze_third_eye", "pilgrim_tisiphones_discipline" },
    -- v0.22.94 (Kaizen): Navigators do not brawl. Slot names, not
    -- flavor names: melee = slot_primary. Enforced by the
    -- BtBotInventorySwitchAction redirect in Pilgrimage.lua.
    weapon_ban     = "melee",
    -- Gold per the tier-3 convention.
    custom_title   = { text = "Navis Nobilite Heiress", color = { 255, 215, 100 } },
    archetype_name = "psyker",
    gender         = "female",
    selected_voice = "psyker_female_c",
    unlock_penance = nil,
    tier           = 3,
}

-- ===========================================================================
-- v0.22.75 (Session I): Tier 2 "Champions" batch. Nine presets from
-- Kaizen's 2026-08-08 design list (roadmap Section 7). All ship
-- UNLOCKED for field-testing; penance/Ordos gating comes with
-- Sessions B phase 2 and C (Kaizen 2026-08-10: "Unlocked for now, we
-- will figure out how to gate them later").
--
-- Baseline stack comes from tier = 2 (pilgrim_elite_toughness) plus
-- the universal coherency widen. No signature passives at this tier;
-- signature work stays a Tier 3+ privilege so the tiers feel
-- different in play, not just in stats.
--
-- Titles: tier-2 purple {200, 110, 220} per the colour scheme locked
-- 2026-08-09. Text drafted by Claude, reviewed by Kaizen pre-install.
-- ===========================================================================

local KRIEG_GUARDSMAN = {
    id             = "krieg_guardsman",
    display_name   = "143-621",
    role_designation = "Death Korps Guardsman",
    custom_title   = { text = "In Death, Atonement", color = { 200, 110, 220 } },
    fixed_legendary = "pilgrim_legendary_shrapnel_doctrine",
    archetype_name = "veteran",
    gender         = "male",
    -- Professional Male: flat, procedural delivery is the closest
    -- Darktide gets to a Krieg gas-mask monotone.
    selected_voice = "veteran_male_a",
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local SPYER = {
    id             = "spyer",
    display_name   = "Cael Helmawr",
    role_designation = "Necromundan Spyrer",
    fixed_legendary = "pilgrim_legendary_gutter_rage",
    -- Necromundan Spyre hunter flavor per Kaizen's design note.
    custom_title   = { text = "Spyre Hunter", color = { 255, 215, 100 } },
    archetype_name = "broker",
    gender         = "male",
    -- Bounty Hunter per the design table (broker_male_b).
    selected_voice = "broker_male_b",
    unlock_penance = nil,
    tier           = 3,
    passives       = { "pilgrim_cael_adaptive_rig" },
}

local SISTER_OF_BATTLE = {
    id             = "sister_of_battle",
    display_name   = "Sister Verena Holt",
    role_designation = "Battle Sister",
    fixed_legendary = "hordes_buff_zealot_channel_heals_corruption",
    -- Kaizen's original custom-title example was giving Argenta
    -- "Adepta Sororitas"; Argenta ended up with "Blessed Sororitas"
    -- at tier 3, so the order's plain name lands here instead.
    custom_title   = { text = "Adepta Sororitas", color = { 200, 110, 220 } },
    archetype_name = "zealot",
    gender         = "female",
    -- Fanatic (zealot_female_b) per the design table.
    selected_voice = "zealot_female_b",
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local SISTER_REPENTIA = {
    id             = "sister_repentia",
    -- Repentia fight with the eviscerator only. The shared bot inventory
    -- redirect sends any ranged selection back to the melee slot.
    weapon_ban     = "ranged",
    display_name   = "Caelia Venn",
    role_designation = "Sister Repentia",
    fixed_legendary = "pilgrim_legendary_pilgrims_momentum",
    custom_title   = { text = "Penitent Blade", color = { 200, 110, 220 } },
    archetype_name = "zealot",
    gender         = "female",
    -- Same Fanatic voice as Sister of Battle; the two are
    -- one-per-class exclusive anyway (both Zealot), so they never
    -- speak side by side.
    selected_voice = "zealot_female_b",
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local HEAVY_COMBAT_SERVITOR = {
    id             = "heavy_combat_servitor",
    -- Heavy servitors are walking industrial melee platforms. The bot
    -- inventory hook keeps the ranged slot holstered, while the bot ability
    -- hook suppresses only the grenade/blitz component. Combat abilities stay
    -- available.
    weapon_ban     = "ranged",
    blitz_ban      = true,
    display_name   = "HCS-819",
    role_designation = "Heavy Combat Servitor",
    fixed_legendary = "hordes_buff_ogryn_apply_fire_on_shout",
    custom_title   = { text = "Property of the Mechanicus", color = { 200, 110, 220 } },
    archetype_name = "ogryn",
    gender         = "male",
    -- Bodyguard Ogryn base voice, run through the game's own
    -- "robotic" voice fx preset (RTPC 50, the full servitor sound)
    -- via the bot voice-filter hook in voices.lua. Mechanism borrowed
    -- from Kaizen's VoxFilter mod, reimplemented Pilgrimage-side and
    -- scoped to bots only, so VoxFilter itself stays untouched (we
    -- do not patch third-party mods after the NPCLook lesson).
    selected_voice = "ogryn_a",
    voice_filter   = "robotic",
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local SANCTIONED_PSYCHIC_ENFORCER = {
    -- Name flagged by Kaizen as possibly changing (roadmap open
    -- question 4). The id is deliberately generic enough to survive a
    -- display_name rename without invalidating captures.
    id             = "sanctioned_psychic_enforcer",
    display_name   = "Orren Thale",
    role_designation = "Psykana Battle-Psyker",
    custom_title   = { text = "The Emperor's Instrument", color = { 200, 110, 220 } },
    fixed_legendary = "pilgrim_legendary_fly_trap",
    archetype_name = "psyker",
    gender         = "male",
    -- Savant Male per the design table. Kaizen's note: a psyker
    -- enforcer with a ranged WEAPON, not a staff; that lives in the
    -- captured source loadout, not here.
    selected_voice = "psyker_male_c",
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local ARBITES_MARSHAL = {
    id             = "arbites_marshal",
    display_name   = "Severan Dreyke",
    role_designation = "Arbites Marshal",
    custom_title   = { text = "Lex Imperialis", color = { 255, 215, 100 } },
    fixed_legendary = "pilgrim_legendary_standing_order",
    archetype_name = "adamant",
    gender         = "male",
    -- Maul (adamant_male_c) per the design table: senior lawman.
    selected_voice = "adamant_male_c",
    unlock_penance = nil,
    tier           = 3,
    passives       = { "pilgrim_dreyke_marshals_authority" },
}

local HEAVY_GUNNER = {
    -- v0.22.75: was "The Show Raider" in the 2026-08-08 batch; Kaizen
    -- renamed him at Session I kickoff (2026-08-10): "change his name
    -- to Heavy Gunner (his title will be 'The Show's Showstopper')".
    -- Tier 2 confirmed in the same exchange.
    id             = "heavy_gunner",
    display_name   = "Rictus Vane",
    role_designation = "The Show Heavy Gunner",
    fixed_legendary = "hordes_buff_broker_damage_increase_over_time_during_focus_stance",
    custom_title   = { text = "The Show's Showstopper", color = { 200, 110, 220 } },
    archetype_name = "broker",
    gender         = "male",
    -- Bounty Hunter, same as Spyer; one-per-class exclusive with him.
    selected_voice = "broker_male_b",
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local TECH_PRIEST = {
    id             = "tech_priest",
    display_name   = "Lathrix-9",
    role_designation = "Tech-Priest Enginseer",
    fixed_legendary = "hordes_buff_cryptic_servo_skull_flamethrower_uses_no_charge",
    custom_title   = { text = "Adeptus Mechanicus", color = { 200, 110, 220 } },
    archetype_name = "cryptic",
    gender         = "male",
    -- Reverent (cryptic_b). Cryptic voices are ungendered a..d per
    -- PP's CLASSES table; gender here only picks the base rig.
    selected_voice = "cryptic_b",
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

-- v0.28.2: three additional Tier 2 capture targets requested by Kaizen.
-- These catalogue records define their picker identity and title. Their
-- Personality Picker voice is supplied by capture-all, never guessed here.
-- Their armour and weapon loadouts remain capture-driven, like the other
-- presets, so a player's own customised operative can supply the visuals.
local KASRKIN_MARKSMAN = {
    id             = "kasrkin_marksman",
    display_name   = "Darran Rhen",
    role_designation = "Kasrkin Marksman",
    fixed_legendary = "pilgrim_legendary_cold_wake",
    custom_title   = { text = "Cadia's Finest", color = { 200, 110, 220 } },
    archetype_name = "veteran",
    gender         = "male",
    selected_voice = nil,
    -- Explicit Pilgrimage fallback. The captured helmet currently misses NPC
    -- Look's automatic gear classification, so do not leave this on Default.
    voice_filter   = "metal",
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local MINISTORUM_FLAMER = {
    id             = "ministorum_flamer",
    display_name   = "Maela Vorn",
    role_designation = "Ministorum Flamer",
    fixed_legendary = "pilgrim_legendary_cleansing_flame",
    custom_title   = { text = "Purging Flame", color = { 200, 110, 220 } },
    archetype_name = "zealot",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local ELECTROPRIEST = {
    id             = "electropriest",
    display_name   = "Iohm-Theta",
    role_designation = "Corpuscarii Electro-Priest",
    fixed_legendary = "hordes_buff_psyker_smite_always_max_damage",
    custom_title   = { text = "Motive Force Incarnate", color = { 200, 110, 220 } },
    archetype_name = "cryptic",
    gender         = "male",
    selected_voice = nil,
    -- VoxFilter calls its clean/no-filter override "none" internally. This is
    -- deliberately an override, rather than Default, so a captured Skitarii
    -- voice has all three character-creation modulation controls neutralized.
    voice_filter   = "none",
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

-- v0.28.49: additional Tier 2 capture targets. As with the preceding capture
-- batch, voices, talents, equipment, appearance, EWC attachments and Vox pins
-- come from capture-all. Only the uncaptured fallback identity lives here.
local SICARIAN_RUSTSTALKER = {
    id             = "sicarian_ruststalker",
    display_name   = "Nex-17",
    role_designation = "Sicarian Ruststalker",
    fixed_legendary = "hordes_buff_cryptic_chordclaw_kills_replenish_charge",
    custom_title   = { text = "The Omnissiah's Razor", color = { 200, 110, 220 } },
    archetype_name = "cryptic",
    gender         = "male",
    selected_voice = nil,
    weapon_ban     = "ranged",
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local SICARIAN_RUSTSTALKER_PRINCEPS = {
    id             = "sicarian_ruststalker_princeps",
    display_name   = "Nex-Primus",
    role_designation = "Sicarian Ruststalker Princeps",
    custom_title   = { text = "Killclade Princeps", color = { 255, 215, 100 } },
    fixed_legendary = "pilgrim_legendary_red_harvest",
    archetype_name = "cryptic",
    gender         = "male",
    selected_voice = nil,
    weapon_ban     = "ranged",
    unlock_penance = nil,
    tier           = 3,
    passives       = { "pilgrim_nex_killclade_directive" },
}

local ARBITES_ENFORCER = {
    id             = "arbites_enforcer",
    display_name   = "Brannic Kord",
    role_designation = "Arbites Enforcer",
    fixed_legendary = "pilgrim_legendary_weight_of_lex",
    companion_name = "Probable Cause",
    custom_title   = { text = "The Lex Made Flesh", color = { 200, 110, 220 } },
    archetype_name = "adamant",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local UNDERCOVER_ARBITRATOR = {
    id             = "undercover_arbitrator",
    display_name   = "Cyran Vale",
    role_designation = "Arbites Intelligencer",
    fixed_legendary = "hordes_buff_adamant_auto_detonate",
    companion_name = "Alibi",
    custom_title   = { text = "The Lex Unseen", color = { 200, 110, 220 } },
    archetype_name = "adamant",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local OGRYN_HUNTER = {
    id             = "ogryn_hunter",
    display_name   = "Ogryn Hunter",
    role_designation = "Underhive Ogryn Hunter",
    fixed_legendary = "pilgrim_legendary_special_delivery",
    custom_title   = { text = "The Quarry's End", color = { 200, 110, 220 } },
    archetype_name = "ogryn",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

-- Capture-ready identities. Weapons, talents and voices come from captures;
-- legendary and signature-passive designs are deliberately still pending.
local OGRYN_DEMOLITION_SPECIALIST = {
    id = "ogryn_demolition_specialist",
    display_name = "Borrik",
    role_designation = "Ogryn Demolition Specialist",
    custom_title = { text = "Big Bang Theory", color = { 200, 110, 220 } },
    archetype_name = "ogryn",
    tier = 2,
    passives = {},
}

local HEAVY_WEAPONS_SERVITOR = {
    -- Historical capture id retained; Ferrum-9 is now our Ogryn Skitarius.
    id = "heavy_weapons_servitor",
    display_name = "Ferrum-9",
    role_designation = "Ogryn Skitarius",
    custom_title = { text = "Percussive Maintenance", color = { 255, 215, 100 } },
    archetype_name = "ogryn",
    tier = 3,
    passives = {},
}

local AUGMENTED_OGRYN_HEAVY_GUNNER = {
    id = "augmented_ogryn_heavy_gunner",
    display_name = "Lug",
    role_designation = "Ogryn Siege Veteran",
    custom_title = { text = "Enlightenment", color = { 255, 215, 100 } },
    archetype_name = "ogryn",
    tier = 3,
    passives = {},
}

local OGRYN_GUNLUGGER = {
    id             = "ogryn_gunlugger",
    display_name   = "Boss Grudd",
    role_designation = "Ogryn Crime Lord",
    custom_title   = { text = "Underhive Kingpin", color = { 255, 215, 100 } },
    fixed_legendary = "pilgrim_legendary_belt_fed_believer",
    archetype_name = "ogryn",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 3,
    passives       = { "pilgrim_grudd_kingpins_example" },
}

-- v0.28.53: the nine companion concepts accepted during the Penance audit
-- become real capture targets. Their practical role names remain the visible
-- names until the separate identity pass assigns personal names and
-- role_designation fields. Voices, equipment, talents, cosmetics, Vox pins
-- and EWC data are intentionally capture-driven. No weapon, blitz or ability
-- restrictions are inferred here.
local COMMISSAR = {
    id             = "commissar",
    display_name   = "Cassian Drave",
    role_designation = "Commissar",
    custom_title   = { text = "The Emperor's Discipline", color = { 200, 110, 220 } },
    archetype_name = "veteran",
    fixed_legendary = "pilgrim_legendary_word_carries",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local HIVE_CHEMIST = {
    id             = "hive_chemist",
    display_name   = "Veyra Kline",
    role_designation = "Hive Scum Chemist",
    custom_title   = { text = "Chymical Savant", color = { 200, 110, 220 } },
    archetype_name = "broker",
    fixed_legendary = "pilgrim_legendary_overdose",
    gender         = "female",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local HIVE_EXTERMINATOR = {
    id             = "hive_exterminator",
    display_name   = "Garran Rusk",
    role_designation = "Hive Scum Exterminator",
    custom_title   = { text = "Vermin-Shrive", color = { 200, 110, 220 } },
    archetype_name = "broker",
    fixed_legendary = "pilgrim_legendary_flak_cannon",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local CRUSADER = {
    id             = "crusader",
    display_name   = "Gideon Mordane",
    role_designation = "Ministorum Crusader",
    custom_title   = { text = "Shield of the Creed", color = { 200, 110, 220 } },
    archetype_name = "adamant",
    fixed_legendary = "pilgrim_legendary_weight_of_lex",
    gender         = "male",
    weapon_ban     = "ranged",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local RECON_DRONE = {
    id             = "recon_drone",
    display_name   = "Rho-32",
    role_designation = "Skitarii Recon Marksman",
    custom_title   = { text = "Omnispex Designate", color = { 200, 110, 220 } },
    archetype_name = "cryptic",
	-- Rho's captured Galvanic Rifle build uses Advanced Combat Doctrines as a
	-- deliberate single-shot marksman. Elite kills refund its Capacitance,
	-- extending the firing solution without borrowing Bront-66's rapid-fire
	-- fixed-drain treatment.
	fixed_legendary = "hordes_buff_cryptic_precision_stance_duration_extension_on_kill",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local MECHANICUS_WARHOUND = {
    id             = "mechanicus_warhound",
    display_name   = "Canis-43",
    role_designation = "Mechanicus Warhound",
    custom_title   = { text = "Hunter-Killer", color = { 200, 110, 220 } },
    archetype_name = "cryptic",
    -- Captured with Chordclaw. Kills restore a charge, letting the Tier 2
    -- hunter keep cycling its signature attack without borrowing a T3 passive.
    fixed_legendary = "hordes_buff_cryptic_chordclaw_kills_replenish_charge",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local TEMPESTUS_SCION = {
    id             = "tempestus_scion",
    display_name   = "Kastor Hale",
    role_designation = "Tempestus Scion",
    custom_title   = { text = "By Order, Victory", color = { 200, 110, 220 } },
    archetype_name = "veteran",
    -- The captured hot-shot build uses Executioner's Stance and a rapid-fire
    -- autogun. Full Auto removes ammunition consumption during the stance.
    fixed_legendary = "hordes_buff_veteran_infinite_ammo_during_stance",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local HEAVY_SKITARIUS = {
    id             = "heavy_skitarius",
    display_name   = "Bront-66",
    role_designation = "Skitarii Heavy Gunner",
    custom_title   = { text = "Maniple Suppressor", color = { 200, 110, 220 } },
    archetype_name = "cryptic",
    -- Bront's rapid-fire autogun would normally empty ACD Capacitance through
    -- its per-shot cost. Omnissian Certainty replaces that with a fixed 7%
    -- drain per second, regardless of rate of fire or refunds.
    fixed_legendary = "pilgrim_legendary_target_marked",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local ROGUE_TRADER = {
    id             = "rogue_trader",
    display_name   = "Dorian Valec",
    role_designation = "Rogue Trader",
    custom_title   = { text = "Bearer of the Warrant", color = { 255, 215, 100 } },
    archetype_name = "veteran",
    fixed_legendary = "hordes_buff_cryptic_discharge_ability_always_full_charges_bonus",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 3,
    passives       = { "pilgrim_dorian_warrant_seizure" },
}

-- v0.28.54: approved identity-pass intake. These entries are capture targets,
-- not synthesized loadouts. Until capture-all supplies a real profile they use
-- only the safe fallback class and body metadata below. Voices, talents,
-- equipment, cosmetics, EWC state and Vox pins remain capture-driven.
local ARBITES_PROCTOR = {
    id             = "arbites_proctor",
    display_name   = "Sabine Krail",
    role_designation = "Arbites Proctor",
    custom_title   = { text = "Riot's End", color = { 200, 110, 220 } },
    archetype_name = "adamant",
    fixed_legendary = "pilgrim_legendary_voltaic_web",
    gender         = "female",
    selected_voice = nil,
    companion_name = "Contempt",
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local TEMPESTOR_PRIME = {
    id             = "tempestor_prime",
    display_name   = "Severin Rauth",
    role_designation = "Tempestor Prime",
    custom_title   = { text = "The Emperor's Talon", color = { 255, 215, 100 } },
    archetype_name = "veteran",
    -- Cold Wake protects the Tempestor from ranged fire during the captured
    -- Executioner's Stance and rewards leading the advance under fire.
    fixed_legendary = "hordes_buff_veteran_apply_infinite_bleed_on_shout",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 3,
    passives       = { "pilgrim_severin_tempestus_command_net" },
}

local MECHANICUS_WARHOUND_ALPHA = {
    id             = "mechanicus_warhound_alpha",
    display_name   = "Canis-Alpha",
    role_designation = "Mechanicus Warhound Alpha",
    custom_title   = { text = "Apex Hunter-Killer", color = { 255, 215, 100 } },
    archetype_name = "cryptic",
    -- The Alpha uses the same captured Chordclaw chassis as Canis-43, but its
    -- Tier 3 package takes the harder-hitting Red Harvest branch.
    fixed_legendary = "pilgrim_legendary_red_harvest",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 3,
    passives       = { "pilgrim_canis_alpha_apex_pursuit" },
}

local LORD_MAGLEVIATHAN = {
    id             = "lord_magleviathan",
    display_name   = "Lord Magleviathan",
    role_designation = "Iron Riders Cartel Lord",
    custom_title   = { text = "The Rails Run Red", color = { 255, 215, 100 } },
    archetype_name = "broker",
    fixed_legendaries = {
        "hordes_buff_broker_health_regen_during_punk_rage",
        "pilgrim_legendary_gutter_rage",
    },
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 3,
    passives       = { "pilgrim_magleviathan_runaway_engine" },
}

local LADY_STEEL = {
    id             = "lady_steel",
    display_name   = "Lady Steel",
    role_designation = "Tread Lightlies Cartel Lord",
    custom_title   = { text = "Mistress of the Foundries", color = { 255, 215, 100 } },
    archetype_name = "broker",
    fixed_legendaries = {
        "pilgrim_legendary_lights_out_forever",
        "hordes_buff_broker_flash_grenade_increase_damage_taken",
    },
    gender         = "female",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 3,
    passives       = { "pilgrim_lady_steel_foundry_temper" },
}

local YOUR_HOST = {
    id             = "your_host",
    display_name   = "Your Host",
    role_designation = "The Show Cartel Lord",
    custom_title   = { text = "Master of Ceremonies", color = { 255, 215, 100 } },
    archetype_name = "broker",
    fixed_legendary = "pilgrim_legendary_overdose",
    gender         = nil,
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 3,
    passives       = { "pilgrim_your_host_encore" },
}

local HOUSEHOLD_NAVIGATOR = {
    id             = "household_navigator",
    display_name   = "Lucien Orphael",
    role_designation = "Household Navigator",
    custom_title   = { text = "The Unblinking Way", color = { 200, 110, 220 } },
    archetype_name = "psyker",
    fixed_legendary = "pilgrim_legendary_unwarded_minds",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local ASTROPATH = {
    id             = "astropath",
    display_name   = "Mara Quill",
    role_designation = "Astropath",
    custom_title   = { text = "Soul-Bound", color = { 200, 110, 220 } },
    archetype_name = "psyker",
    fixed_legendary = "pilgrim_legendary_overwhelming_mind",
    gender         = "female",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local SCHOLASTICA_PYROKINETIC = {
    id             = "scholastica_pyrokinetic",
    display_name   = "Ilyra Neth",
    role_designation = "Scholastica Pyrokinetic",
    custom_title   = { text = "Witchfire Tempered", color = { 200, 110, 220 } },
    archetype_name = "psyker",
    fixed_legendary = "hordes_buff_psyker_brain_burst_spreads_fire_on_hit",
    gender         = "female",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local UNDERHIVE_WYRD = {
    id             = "underhive_wyrd",
    display_name   = "Knell",
    role_designation = "Underhive Wyrd",
    custom_title   = { text = "Unlicensed Miracle", color = { 200, 110, 220 } },
    archetype_name = "psyker",
    fixed_legendary = "pilgrim_legendary_harrowing_rebuke",
    gender         = nil,
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local VOIDSMAN_AT_ARMS = {
    id             = "voidsman_at_arms",
    display_name   = "Renn Calder",
    role_designation = "Voidsman-at-Arms",
    custom_title   = { text = "Void-Hardened", color = { 200, 110, 220 } },
    archetype_name = "veteran",
    -- Renn's captured build carries Frag Grenades. Red Hail gives the
    -- Voidsman-at-Arms a breaching and deck-clearing answer to packed enemies.
    fixed_legendary = "pilgrim_legendary_shrapnel_doctrine",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local VOIDSHIP_BREACHER = {
    id             = "voidship_breacher",
    display_name   = "Mira Hest",
    role_designation = "Voidship Breacher",
    custom_title   = { text = "First In", color = { 200, 110, 220 } },
    archetype_name = "adamant",
    fixed_legendary = "hordes_buff_adamant_stance_immunity",
    gender         = "female",
    selected_voice = nil,
    -- Voidsmen teams can field Cyber-Mastiffs, so Mira keeps the companion
    -- available to her captured Adamant build under an explicit shipboard name.
    companion_name = "Bulkhead",
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local DECK_CLEANER = {
    id             = "deck_cleaner",
    display_name   = "Brakk",
    role_designation = "Voidsman Deck Gunner",
    custom_title   = { text = "Deck Cleaner", color = { 200, 110, 220 } },
    archetype_name = "ogryn",
    fixed_legendary = "hordes_buff_ogryn_increase_penetration_during_stance",
    gender         = "male",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 2,
    passives       = {},
}

local REJUVENAT_ADEPT = {
    id             = "rejuvenat_adept",
    display_name   = "Epione Spes",
    role_designation = "Officio Medicae Chirurgeon",
    custom_title   = { text = "Lifeline", color = { 255, 215, 100 } },
    archetype_name = "broker",
    fixed_legendary = "hordes_buff_broker_stimm_field_shock_on_interval",
    gender         = "female",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 3,
    passives       = { "pilgrim_epione_medicae_mandate" },
}

local JOCASTA_SAUERBACK = {
    id             = "jocasta_sauerback",
    display_name   = "Jocasta Sauerback",
    role_designation = "Voidship Master-at-Arms",
    custom_title   = { text = "Master-at-Arms", color = { 255, 215, 100 } },
    archetype_name = "veteran",
    -- Jocasta's intended recapture uses Voice of Command. Deafening Bellow
    -- turns the shout into an offensive order by applying 20 stacks of the
    -- permanent minion Bleed effect to every enemy it reaches.
    fixed_legendary = "hordes_buff_veteran_apply_infinite_bleed_on_shout",
    gender         = "female",
    selected_voice = nil,
    unlock_penance = nil,
    tier           = 3,
    passives       = { "pilgrim_jocasta_masters_rebuke" },
}

-- ===========================================================================
-- v0.28.56: Tier 1 identity rule. The four original classes deliberately
-- remain uncaptured and borrow Better Bots' default class profiles at spawn.
-- Pilgrimage then removes their talent trees and applies only the Living
-- Tithe identity. Every Tier 1 is silent through Personality Picker except
-- the Cartel Recruit, whose deliberately absurd voice is Ogryn Brawler.
--
-- Baseline stack: tier = 1 resolves to NO tier passives (vanilla-bot
-- power), universal coherency widen still applies. Titles tier-1
-- blue {90, 160, 240}.
-- ===========================================================================

local MOEBIAN_CONSCRIPT = {
    id             = "moebian_conscript",
    display_name   = "Moebian 21st Conscript",
    role_designation = "Penal Conscript",
    custom_title   = { text = "Penal Legionnaire", color = { 90, 160, 240 } },
    archetype_name = "veteran",
    gender         = "male",
    selected_voice = nil,
    personality_override = "pp_virtual_silent_all",
    unlock_penance = nil,
    tier           = 1,
    passives       = {},
}

local MILITARUM_PREACHER = {
    id             = "militarum_preacher",
    display_name   = "Militarum Preacher",
    role_designation = "Conscript Preacher",
    custom_title   = { text = "Adeptus Ministorum", color = { 90, 160, 240 } },
    archetype_name = "zealot",
    gender         = "male",
    selected_voice = nil,
    personality_override = "pp_virtual_silent_all",
    unlock_penance = nil,
    unlock_sku     = "living_tithe_preacher",
    tier           = 1,
    passives       = {},
}

local GROG = {
    id             = "grog",
    display_name   = "Grog",
    role_designation = "Ogryn Auxilia",
    custom_title   = { text = "Ogryn Auxilia", color = { 90, 160, 240 } },
    archetype_name = "ogryn",
    gender         = "male",
    selected_voice = nil,
    personality_override = "pp_virtual_silent_all",
    unlock_penance = nil,
    unlock_sku     = "living_tithe_grog",
    tier           = 1,
    passives       = {},
}

local BLACK_SHIP_FODDER = {
    id             = "black_ship_fodder",
    display_name   = "Black Ship Fodder",
    role_designation = "Unsanctioned Psyker",
    custom_title   = { text = "Tithed Soul", color = { 90, 160, 240 } },
    archetype_name = "psyker",
    gender         = "male",
    selected_voice = nil,
    personality_override = "pp_virtual_silent_all",
    unlock_penance = nil,
    unlock_sku     = "living_tithe_psyker",
    tier           = 1,
    passives       = {},
}

local MOEBIAN_DEPUTY = {
    id             = "moebian_deputy",
    display_name   = "Moebian Deputy",
    role_designation = "Tertium Deputy",
    companion_name = "Misdemeanour",
    custom_title   = { text = "Tertium Lawman", color = { 90, 160, 240 } },
    archetype_name = "adamant",
    gender         = "male",
    selected_voice = nil,
    personality_override = "pp_virtual_silent_all",
    unlock_penance = nil,
    unlock_sku     = "living_tithe_deputy",
    tier           = 1,
    passives       = {},
}

local CARTEL_RECRUIT = {
    id             = "cartel_recruit",
    display_name   = "Cartel Recruit",
    role_designation = "Low-Hive Runner",
    custom_title   = { text = "Low-Hive Runner", color = { 90, 160, 240 } },
    archetype_name = "broker",
    -- The capture supplies the physical broker rig. Personality Picker
    -- remaps it to Ogryn Brawler without putting a cross-class virtual id
    -- into the network profile.
    gender         = "female",
    selected_voice = nil,
    personality_override = "ogryn_c",
    unlock_penance = nil,
    unlock_sku     = "living_tithe_cartel",
    tier           = 1,
    passives       = {},
}

local SKITARIUS_2137 = {
    id             = "skitarius_2137",
    -- Leet-speak name intentional per Kaizen's design table.
    display_name   = "Sk1tar1us 2137",
    role_designation = "Damaged Skitarius",
    custom_title   = { text = "Pr0perty 0f M4rs", color = { 90, 160, 240 } },
    archetype_name = "cryptic",
    gender         = "male",
    selected_voice = nil,
    personality_override = "pp_virtual_silent_all",
    unlock_penance = nil,
    unlock_sku     = "living_tithe_skitarius",
    tier           = 1,
    passives       = {},
}

M.CATALOGUE = {
    -- Tier 3 (Heroes)
    SISTER_ARGENTA, MAGOS_HANEUMANN, SPINNER_KIBELLAH, SOLOMORNE,
    INTERROGATOR_HEINRIX, SENESCHAL_ABELARD, PRINCESS_JAE, IDIRA_TLASS,
    THEODORA_VON_VALANCIUS, CASSIA_ORSELLIO, ARBITES_MARSHAL, SPYER,
    SICARIAN_RUSTSTALKER_PRINCEPS, OGRYN_GUNLUGGER, ROGUE_TRADER,
    TEMPESTOR_PRIME, MECHANICUS_WARHOUND_ALPHA, LORD_MAGLEVIATHAN,
    LADY_STEEL, YOUR_HOST, JOCASTA_SAUERBACK,
    HEAVY_WEAPONS_SERVITOR, AUGMENTED_OGRYN_HEAVY_GUNNER,
    -- Tier 2 (Champions)
    KRIEG_GUARDSMAN, SISTER_OF_BATTLE, SISTER_REPENTIA,
    HEAVY_COMBAT_SERVITOR, SANCTIONED_PSYCHIC_ENFORCER,
    HEAVY_GUNNER, TECH_PRIEST, KASRKIN_MARKSMAN, MINISTORUM_FLAMER,
    ELECTROPRIEST, SICARIAN_RUSTSTALKER, ARBITES_ENFORCER,
    UNDERCOVER_ARBITRATOR, ARBITES_PROCTOR, OGRYN_HUNTER,
    COMMISSAR, HIVE_CHEMIST, HIVE_EXTERMINATOR, CRUSADER, RECON_DRONE,
    MECHANICUS_WARHOUND, TEMPESTUS_SCION, HEAVY_SKITARIUS,
    HOUSEHOLD_NAVIGATOR, ASTROPATH, SCHOLASTICA_PYROKINETIC,
    UNDERHIVE_WYRD, VOIDSMAN_AT_ARMS, VOIDSHIP_BREACHER, DECK_CLEANER,
    REJUVENAT_ADEPT, OGRYN_DEMOLITION_SPECIALIST,
    -- Tier 1 (Living Tithe), v0.22.75
    MOEBIAN_CONSCRIPT, MILITARUM_PREACHER, GROG, BLACK_SHIP_FODDER,
    MOEBIAN_DEPUTY, CARTEL_RECRUIT, SKITARIUS_2137,
}

local _by_id = {}
for i = 1, #M.CATALOGUE do _by_id[M.CATALOGUE[i].id] = M.CATALOGUE[i] end

-- Public mission-HUD identity. This is deliberately separate from
-- archetype_name: several companions use another class as their mechanical
-- chassis, and exposing that implementation detail undermines their fiction.
-- Keeping the labels keyed by the save-stable preset id makes every exception
-- explicit without changing captures, talents or matchmaking data.
M.HUD_DESIGNATIONS = {
    -- Rogue Trader companions and voidship personnel
    sister_argenta = "Rogue Trader Retinue",
    magos_haneumann = "Rogue Trader Retinue",
    spinner_kibellah = "Rogue Trader Retinue",
    solomorne = "Rogue Trader Retinue",
    interrogator_heinrix = "Rogue Trader Retinue",
    seneschal_abelard = "Rogue Trader Retinue",
    princess_jae = "Rogue Trader Retinue",
    idira_tlass = "Rogue Trader Retinue",
    theodora_von_valancius = "Rogue Trader Retinue",
    cassia_orsellio = "Rogue Trader Retinue",
    rogue_trader = "Rogue Trader Retinue",
    voidsman_at_arms = "Rogue Trader Retinue",
    voidship_breacher = "Rogue Trader Retinue",
    deck_cleaner = "Rogue Trader Retinue",
    rejuvenat_adept = "Rogue Trader Retinue",
    jocasta_sauerback = "Rogue Trader Retinue",

    -- Astra Militarum
    krieg_guardsman = "Astra Militarum",
    commissar = "Astra Militarum",
    kasrkin_marksman = "Astra Militarum",
    tempestus_scion = "Astra Militarum",
    tempestor_prime = "Astra Militarum",
    moebian_conscript = "Astra Militarum",
    militarum_preacher = "Astra Militarum",
    grog = "Astra Militarum",
    ogryn_demolition_specialist = "Astra Militarum",
    augmented_ogryn_heavy_gunner = "Astra Militarum",

    -- Adeptus Mechanicus
    heavy_combat_servitor = "Adeptus Mechanicus",
    heavy_weapons_servitor = "Adeptus Mechanicus",
    tech_priest = "Adeptus Mechanicus",
    electropriest = "Adeptus Mechanicus",
    sicarian_ruststalker = "Adeptus Mechanicus",
    sicarian_ruststalker_princeps = "Adeptus Mechanicus",
    recon_drone = "Adeptus Mechanicus",
    mechanicus_warhound = "Adeptus Mechanicus",
    heavy_skitarius = "Adeptus Mechanicus",
    mechanicus_warhound_alpha = "Adeptus Mechanicus",
    skitarius_2137 = "Adeptus Mechanicus",

    -- Adeptus Arbites and local Enforcers
    arbites_marshal = "Adeptus Arbites",
    arbites_enforcer = "Adeptus Arbites",
    undercover_arbitrator = "Adeptus Arbites",
    arbites_proctor = "Adeptus Arbites",
    moebian_deputy = "Tertium Enforcers",

    -- Ministorum
    sister_of_battle = "Adeptus Ministorum",
    sister_repentia = "Adeptus Ministorum",
    ministorum_flamer = "Adeptus Ministorum",
    crusader = "Adeptus Ministorum",

    -- Psykana, Navigators and unsanctioned warp-touched companions
    sanctioned_psychic_enforcer = "Adeptus Astra Telepathica",
    astropath = "Adeptus Astra Telepathica",
    scholastica_pyrokinetic = "Adeptus Astra Telepathica",
    black_ship_fodder = "Adeptus Astra Telepathica",
    household_navigator = "Navis Nobilite",
    underhive_wyrd = "Tertium Underhive",

    -- Underhive powers and personnel
    spyer = "House Helmawr",
    heavy_gunner = "Tertium Underhive",
    hive_chemist = "Tertium Underhive",
    hive_exterminator = "Tertium Underhive",
    ogryn_hunter = "Tertium Underhive",
    ogryn_gunlugger = "Tertium Underhive",
    lord_magleviathan = "Tertium Cartels",
    lady_steel = "Tertium Cartels",
    your_host = "Tertium Cartels",
    cartel_recruit = "Tertium Underhive",
}

-- ===========================================================================
-- Public read API
-- ===========================================================================

function M.get(id) return _by_id[id] end
function M.all() return M.CATALOGUE end

function M.hud_designation(id_or_preset)
    local preset = type(id_or_preset) == "table"
        and id_or_preset or _by_id[id_or_preset]
    return preset and M.HUD_DESIGNATIONS[preset.id] or nil
end

function M.is_unlocked(id)
    local preset = _by_id[id]
    if not preset then return false end
    if preset.unlock_penance then
        if not _penances or not _penances.is_earned
            or _penances.is_earned(preset.unlock_penance) ~= true then
            return false
        end
    end
    if preset.unlock_sku then
        if not _shop or not _shop.is_unlocked
            or _shop.is_unlocked(preset.unlock_sku) ~= true then
            return false
        end
    end
    return true
end

-- ===========================================================================
-- Binding storage
-- ===========================================================================
--
-- Three settings channels persisted via DMF:
--   _preset_default      the single preset applied to every slot
--   _preset_slots        per-slot bindings, encoded as "1:sister_argenta,2:..."
--   _preset_source_<id>  the source character_id captured for preset <id>

local KEY_DEFAULT       = "_preset_default"
local KEY_SLOTS         = "_preset_slots"
local KEY_SOURCE_PREFIX = "_preset_source_"
local KEY_T1_MIGRATED   = "_preset_living_tithe_migrated"
local KEY_HERO_GATES_MIGRATED = "_preset_t3_penance_gates_migrated"
local KEY_NO_DEFAULT_BOTS_MIGRATED = "_preset_no_default_bots_migrated"

local GRANDFATHERED_HERO_PENANCES = {
    -- Grant the two Haneumann sub-Penances first. The normal parent cascade
    -- then produces a logically complete Penance record rather than an
    -- earned parent with two visibly unfinished children.
    "pilgrim_data_hymn",
    "pilgrim_machine_spirit",
    "pilgrim_haneumann_parent",
    "pilgrim_dancing_on_the_web",
    "pilgrim_warrant_served",
    "pilgrim_biolightning",
}

-- v0.22.75 (Session I): "None" is a first-class binding (locked
-- decision 2026-08-09: "Bot slots being unlocked is a capability, not
-- a requirement"). A slot bound to NONE_BINDING spawns NO bot at all,
-- Since v0.28.56 an unbound slot (nil) has the same empty behavior. The
-- implicit vanilla/Better Bots "Default bot" choice was retired once the
-- Living Tithe roster covered the entry-level role. The sentinel is stored
-- in the same _preset_slots
-- channel as preset ids; it can never collide with a real preset id
-- because ids are catalogue-validated on load and "none" is reserved
-- here.
M.NONE_BINDING = "none"

local function _load_slots()
    if not _mod then return {} end
    local raw = _mod:get(KEY_SLOTS)
    local out = {}
    local seen_ids = {}
    if type(raw) ~= "string" or raw == "" then return out end
    for entry in string.gmatch(raw, "([^,]+)") do
        local slot_str, id = string.match(entry, "^(%d+):(.+)$")
        -- v0.22.75: the NONE_BINDING sentinel round-trips through the
        -- same channel as catalogue ids.
        if slot_str and id and (_by_id[id] or id == M.NONE_BINDING) then
            -- Exact identities are unique even though different presets of the
            -- same class are now allowed. Old duplicate settings are sanitized
            -- on read, and the lowest slot wins even if an old raw string was
            -- written out of order.
            local slot = tonumber(slot_str)
            local previous_slot = seen_ids[id]
            if id == M.NONE_BINDING then
                out[slot] = id
            elseif not previous_slot or slot < previous_slot then
                if previous_slot then out[previous_slot] = nil end
                out[slot] = id
                seen_ids[id] = slot
            end
        end
    end
    return out
end

local function _store_slots(map)
    if not _mod then return end
    local entries = {}
    for slot, id in pairs(map) do
        entries[#entries + 1] = tostring(slot) .. ":" .. id
    end
    table.sort(entries)
    _mod:set(KEY_SLOTS, table.concat(entries, ","), false)
end

function M.default_preset()
    if not _mod then return nil end
    local id = _mod:get(KEY_DEFAULT)
    if type(id) == "string" and id ~= "" and _by_id[id] then return id end
    return nil
end

function M.set_default(id)
    if not _mod then return false, "no mod" end
    if id == nil or id == "" or id == "none" then
        _mod:set(KEY_DEFAULT, "", false)
        return true
    end
    if not _by_id[id] then return false, "unknown preset" end
    if not M.is_unlocked(id) then return false, "locked (penance required)" end
    _mod:set(KEY_DEFAULT, id, false)
    return true
end

function M.slot_bindings() return _load_slots() end

-- Same-class bots used to share parts of their profiles, loadouts and looks.
-- The isolation work added since then appears to have removed that engine bug,
-- so the restriction is disabled. The complete old guard remains behind this
-- single switch for a quick rollback if field testing finds contamination.
local ENFORCE_ONE_PRESET_PER_ARCHETYPE = false

function M.class_lock_enabled()
    return ENFORCE_ONE_PRESET_PER_ARCHETYPE
end

-- Quick lookup for "which archetype is bound to which slot(s)". It remains
-- useful to the dormant class-lock path and to diagnostics.
-- Returns { [slot_index] = archetype_name }.
function M.slot_archetypes()
    local out = {}
    local map = _load_slots()
    for slot, id in pairs(map) do
        local p = _by_id[id]
        if p and p.archetype_name then
            out[slot] = p.archetype_name
        end
    end
    return out
end

function M.bind_slot(slot, id)
    slot = tonumber(slot)
    if not slot or slot < 1 then return false, "invalid slot" end

    -- v0.22.75: bind-to-None. Skips the unlock and one-per-class
    -- checks (an empty slot has no class and needs no penance); the
    -- slot simply spawns nothing until rebound.
    if id == M.NONE_BINDING then
        local map = _load_slots()
        map[slot] = M.NONE_BINDING
        _store_slots(map)
        return true
    end

    if not _by_id[id] then return false, "unknown preset" end
    if not M.is_unlocked(id) then return false, "locked (penance required)" end

    -- Same-class parties are supported, duplicate people are not. Keep this
    -- independent from ENFORCE_ONE_PRESET_PER_ARCHETYPE so the old class-level
    -- safety switch can stay disabled without allowing one preset twice.
    local map = _load_slots()
    for other_slot, other_id in pairs(map) do
        if other_slot ~= slot and other_id == id then
            return false, string.format(
                "preset '%s' is already bound to slot %d",
                id, other_slot)
        end
    end

    -- Dormant one-per-class enforcement. If ANOTHER slot already
    -- has a preset of this archetype, refuse. Kaizen's design ask:
    -- "only one per class can be assigned. Would be interesting to
    -- see how people draft their loadouts, instead of going full 6
    -- stack support zealots". The party HUD only has one player row
    -- per class visually, and same-class bots seem to trip a
    -- profile-cross-contamination bug in the underlying Fatshark
    -- spawn (Kibellah wielding Argenta's Thunder Hammer, mixed
    -- outfits). Enforcing uniqueness sidesteps that whole class of
    -- issue as a bonus.
    --
    -- The re-bind case (setting the same slot to a preset whose
    -- archetype matches ITSELF at that slot) is fine, so we skip the
    -- check when the conflicting slot IS the one being bound.
    local preset = _by_id[id]
    if M.class_lock_enabled() and preset.archetype_name then
        local archetypes = M.slot_archetypes()
        for other_slot, other_arch in pairs(archetypes) do
            if other_slot ~= slot and other_arch == preset.archetype_name then
                return false, string.format(
                    "class '%s' is already bound to slot %d",
                    preset.archetype_name, other_slot)
            end
        end
    end

    map[slot] = id
    _store_slots(map)
    return true
end

function M.unbind_slot(slot)
    slot = tonumber(slot)
    if not slot then return false, "invalid slot" end
    local map = _load_slots()
    if not map[slot] then return false, "not bound" end
    map[slot] = nil
    _store_slots(map)
    return true
end

function M.clear_all_bindings()
    if not _mod then return end
    _mod:set(KEY_DEFAULT, "", false)
    _mod:set(KEY_SLOTS, "", false)
end

-- v0.28.53 migration. Before these gates existed, every established player
-- could use all four Heroes and there was no separate ownership record. An
-- established Pilgrimage profile therefore receives the corresponding
-- Penances silently. A completely untouched profile receives no grant and
-- sees the intended gates from its first terminal visit.
local function _migrate_tier3_penance_gates()
    if not _mod or _mod:get(KEY_HERO_GATES_MIGRATED) == true then return end

    local established = _mod:get(KEY_T1_MIGRATED) == true
        or (tonumber(_mod:get("_stat_total_runs_completed")) or 0) > 0
        or (tonumber(_mod:get("_stat_total_missions_completed")) or 0) > 0

    local earned_raw = _mod:get("_penances_earned")
    if type(earned_raw) == "string" and earned_raw ~= "" then
        established = true
    end

    local default_raw = _mod:get(KEY_DEFAULT)
    local slots_raw = _mod:get(KEY_SLOTS)
    if (type(default_raw) == "string" and default_raw ~= "")
        or (type(slots_raw) == "string" and slots_raw ~= "") then
        established = true
    end

    if not established then
        for i = 1, #M.CATALOGUE do
            local source = _mod:get(KEY_SOURCE_PREFIX .. M.CATALOGUE[i].id)
            if type(source) == "string" and source ~= "" then
                established = true
                break
            end
        end
    end

    if established and _penances and type(_penances.grant) == "function" then
        for i = 1, #GRANDFATHERED_HERO_PENANCES do
            _penances.grant(
                GRANDFATHERED_HERO_PENANCES[i],
                "v0.28.53_existing_player_migration",
                true)
        end
    end

    _mod:set(KEY_HERO_GATES_MIGRATED, true, false)
end

-- One-time v0.28.52 migration. Existing captured or slotted Tier 1 presets
-- remain owned when Living Tithe purchases become real gates. On profiles
-- without any explicit Warband setup, slot 1 receives the free Veteran.
local function _migrate_living_tithe()
    if not _mod or _mod:get(KEY_T1_MIGRATED) == true then return end

    local preserved = {}
    local default = M.default_preset()
    if default then preserved[default] = true end
    local slots = _load_slots()
    local has_binding = default ~= nil
    for _, id in pairs(slots) do
        if id ~= M.NONE_BINDING then preserved[id] = true end
        has_binding = true
    end

    for i = 1, #M.CATALOGUE do
        local preset = M.CATALOGUE[i]
        if preset.tier == 1 and preset.unlock_sku then
            local source = _mod:get(KEY_SOURCE_PREFIX .. preset.id)
            if type(source) == "string" and source ~= "" then
                preserved[preset.id] = true
            end
        end
    end

    if _shop and _shop.grant_permanent then
        for id in pairs(preserved) do
            local preset = _by_id[id]
            if preset and preset.unlock_sku then
                _shop.grant_permanent(preset.unlock_sku)
            end
        end
    end

    if not has_binding then
        slots[1] = "moebian_conscript"
        _store_slots(slots)
    end

    _mod:set(KEY_T1_MIGRATED, true, false)

    if _penances and _penances.observe and _shop
        and _shop.living_tithe_owned_count then
        _penances.observe("recruit_update", {
            tier1_owned = _shop.living_tithe_owned_count(),
        })
    end
end

-- v0.28.56 migration. Older installations may have an entirely empty slot
-- map because nil used to mean "spawn a default bot". Seed only that truly
-- untouched shape with the free Conscript. Partially configured parties keep
-- their choices and every remaining nil slot becomes deliberately empty.
local function _migrate_no_default_bots()
    if not _mod or _mod:get(KEY_NO_DEFAULT_BOTS_MIGRATED) == true then return end
    local slots = _load_slots()
    if next(slots) == nil then
        slots[1] = "moebian_conscript"
        _store_slots(slots)
    end
    _mod:set(KEY_NO_DEFAULT_BOTS_MIGRATED, true, false)
end

-- ===========================================================================
-- Source character binding (v0.22.8)
-- ===========================================================================
--
-- Each preset can pin ONE of your saved characters as the "template."
-- The bot spawns as a clone of that template with only name / voice
-- overridden. Stored per-preset in DMF settings so it survives across
-- sessions.

function M.source_character_id(preset_id)
    if not _mod or not _by_id[preset_id] then return nil end
    local id = _mod:get(KEY_SOURCE_PREFIX .. preset_id)
    if type(id) == "string" and id ~= "" then return id end
    return nil
end

function M.set_source_character(preset_id, character_id)
    if not _mod or not _by_id[preset_id] then return false, "unknown preset" end
    if character_id == nil or character_id == "" then
        _mod:set(KEY_SOURCE_PREFIX .. preset_id, "", false)
        return true
    end
    _mod:set(KEY_SOURCE_PREFIX .. preset_id, character_id, false)
    return true
end

-- ===========================================================================
-- Profile cache
-- ===========================================================================
--
-- Populated by our hook on ProfilesService:fetch_all_profiles. We do NOT
-- try to guess when to fetch: the game fetches whenever it needs the
-- character list (opening the character select screen is the primary
-- trigger), and we keep whatever it hands us. On top of that,
-- M.request_profile_fetch() lets other code (like our state-change hook)
-- kick a fetch manually.

local _profile_cache = {}
local _profile_cache_count = 0

function M.profile_cache_count() return _profile_cache_count end

function M.list_cached_profiles()
    local out = {}
    for char_id, profile in pairs(_profile_cache) do
        local arch = "?"
        if type(profile.archetype) == "table" then
            arch = tostring(profile.archetype.name or profile.archetype.archetype_name or "?")
        end
        out[#out + 1] = {
            character_id = char_id,
            name         = tostring(profile.original_name or profile.name or "?"),
            archetype    = arch,
            gender       = tostring(profile.gender or "?"),
        }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function M.get_cached_profile(character_id)
    return _profile_cache[character_id]
end

-- ===========================================================================
-- Per-preset stored look (v0.22.22)
-- ===========================================================================
--
-- Kaizen's complaint: bots were mirroring his CURRENT NPC Look, so if
-- he swapped his personal NPCLL pin, bots picked up the new look. Sister
-- Argenta should carry HER OWN look (the Sororitas one), independent of
-- whatever he happens to be wearing at the time.
--
-- Design: a preset can store its own NPC Look state snapshot as a DMF
-- setting. When present, apply_source_to_profile and the bot apply
-- pumps use the stored snapshot INSTEAD of NPC Look's live state. When
-- absent, they fall back to the live state (backwards compatible with
-- v0.22.16-v0.22.21 behavior).
--
-- Serialization: cjson encode/decode the snapshot table. NPC Look state
-- is only strings, numbers, and bools nested a couple of levels deep,
-- which cjson handles fine.

local KEY_LOOK_STATE_PREFIX     = "_preset_look_state_"
local KEY_PACKED_PROFILE_PREFIX = "_preset_packed_profile_"
local KEY_PERSONALITY_PREFIX    = "_preset_personality_"
local KEY_EWC_PREFIX            = "_preset_ewc_"
local _live_profile_if_current
local _default_captures

-- Per-preset voice capture has two parts:
--   key          VoxFilter pin/override name, including explicit "default".
--   game_preset  the resolved helmet/mask RTPC before VoxFilter overrides it.
-- Keeping both is important. Default tells the bot not to invent an override,
-- while game_preset lets captured base-game and NPC Look headgear sound the
-- same even when Darktide does not rebuild the voice preset for a bot profile.
local KEY_VOICE_FILTER_PREFIX          = "_preset_voice_filter_"
local KEY_VOICE_FILTER_BASELINE_PREFIX = "_preset_voice_filter_baseline_"

function M.set_stored_voice_filter(preset_id, key, game_preset)
    if not _mod or not _by_id[preset_id] then return false end
    _mod:set(KEY_VOICE_FILTER_PREFIX .. preset_id, key or "default", false)
    -- "none" is a storage sentinel meaning an intentionally empty baseline.
    -- It prevents an older bundled baseline from leaking back after recapture.
    local encoded_baseline = type(game_preset) == "number"
        and tostring(game_preset) or "none"
    _mod:set(KEY_VOICE_FILTER_BASELINE_PREFIX .. preset_id,
        encoded_baseline, false)
    return true
end

local function _voice_filter_bucket_value(kind, preset_id)
    local defaults = _default_captures and _default_captures()
    local bucket = defaults and defaults[kind]
    return bucket and bucket[preset_id] or nil
end

function M.voice_filter_snapshot(preset_id)
    local preset = _by_id[preset_id]
    if not preset then return nil end

    -- Data-defined fallbacks intentionally outrank captures. Heavy Servitor is
    -- always Robotic; Electropriest is always the explicit Clean override.
    if type(preset.voice_filter) == "string" and preset.voice_filter ~= "" then
        return { key = preset.voice_filter, game_preset = nil }
    end

    local key = _mod and _mod:get(KEY_VOICE_FILTER_PREFIX .. preset_id) or nil
    if type(key) ~= "string" or key == "" then
        key = _voice_filter_bucket_value("voice_filter", preset_id)
    end
    if type(key) ~= "string" or key == "" then key = "default" end

    local raw_baseline = _mod
        and _mod:get(KEY_VOICE_FILTER_BASELINE_PREFIX .. preset_id) or nil
    if type(raw_baseline) ~= "string" or raw_baseline == "" then
        raw_baseline = _voice_filter_bucket_value("voice_filter_baseline", preset_id)
    end
    local game_preset = tonumber(raw_baseline)

    -- Retroactive path for captures made before numeric baselines existed. The
    -- captured NPC Look state already contains the original headgear item name,
    -- so the NPC Look bridge can resolve its authored voice_fx_preset without
    -- asking the player to rebuild or recapture the bot.
    if game_preset == nil and key == "default" then
        local get_mod = rawget(_G, "get_mod")
        local npc_look = get_mod and get_mod("NPCLook")
        local resolver = npc_look and npc_look.npclook_voice_fx_preset_for_state
        local stored_look = type(M.stored_look_state) == "function"
            and M.stored_look_state(preset_id) or nil

        if type(resolver) == "function" and type(stored_look) == "table" then
            local ok, resolved = pcall(resolver, stored_look)
            if ok and type(resolved) == "number" then game_preset = resolved end
        end
    end

    return { key = key, game_preset = game_preset }
end

function M.voice_filter_key(preset_id)
    local snapshot = M.voice_filter_snapshot(preset_id)
    return snapshot and snapshot.key or nil
end

local function _local_dialogue_extension()
    local Managers = rawget(_G, "Managers")
    local player = Managers and Managers.player
        and Managers.player:local_player_safe(1)
    local unit = player and player.player_unit
    local ScriptUnit = rawget(_G, "ScriptUnit")
    if not unit or not ScriptUnit or type(ScriptUnit.has_extension) ~= "function"
        or not ScriptUnit.has_extension(unit, "dialogue_system") then
        return nil
    end
    local ok, extension = pcall(ScriptUnit.extension, unit, "dialogue_system")
    return ok and extension or nil
end

-- Capture the active VoxFilter pin and the underlying game/NPC Look preset.
-- VoxFilter v1.2+ exposes the baseline it saved before an override. The local
-- fallback keeps Pilgrimage compatible with older VoxFilter versions and with
-- players who do not install it at all.
function M.capture_voice_filter_for(preset_id)
    if not _by_id[preset_id] then return false, "unknown preset" end

    local key = "default"
    local game_preset = nil
    local get_mod = rawget(_G, "get_mod")
    local vf = get_mod and get_mod("VoxFilter")

    if type(vf) == "table"
        and type(vf.preset_capture_voice_filter_snapshot) == "function" then
        local ok_api, snapshot = pcall(vf.preset_capture_voice_filter_snapshot)
        if ok_api and type(snapshot) == "table" then
            if type(snapshot.key) == "string" and snapshot.key ~= "" then
                key = snapshot.key
            end
            if type(snapshot.game_preset) == "number" then
                game_preset = snapshot.game_preset
            end
        end
    elseif type(vf) == "table" then
        -- Compatibility read for older VoxFilter builds. Preserve Default pins
        -- instead of discarding them as the old Pilgrimage capture did.
        local ok_old = pcall(function()
            if vf:get("enable_filter") then
                local selected = vf:get("filter")
                if selected and selected ~= "default" then key = selected end
            end
            if key == "default" and vf:get("pin_filter_to_loadouts") then
                local Managers = rawget(_G, "Managers")
                local player = Managers and Managers.player
                    and Managers.player:local_player_safe(1)
                if player and type(player.character_id) == "function" then
                    local ok_char, char_id = pcall(player.character_id, player)
                    if ok_char and char_id then
                        local ok_pu, pu = pcall(require, "scripts/utilities/profile_utils")
                        if ok_pu and pu and pu.get_active_profile_preset_id then
                            local ok_pid, pid = pcall(pu.get_active_profile_preset_id)
                            local pins = vf:get("filter_pins")
                            local pin = ok_pid and pid and type(pins) == "table"
                                and pins[pid] or nil
                            if type(pin) == "string" and pin ~= "" then key = pin end
                        end
                    end
                end
            end
        end)
        if not ok_old then return false, "VoxFilter read failed" end
    end

    -- With an explicit override, the visible dialogue value is that override,
    -- not the helmet baseline. New VoxFilter supplies the true baseline above;
    -- old builds safely leave it empty. Default can always read the live value.
    if game_preset == nil and key == "default" then
        local dialogue_extension = _local_dialogue_extension()
        local visible = dialogue_extension and dialogue_extension._voice_fx_preset
        if type(visible) == "number" then game_preset = visible end
    end

    M.set_stored_voice_filter(preset_id, key, game_preset)
    return true, { key = key, game_preset = game_preset }
end

local function _load_cjson()
    -- cjson is a Fatshark-provided global in the game, but not always
    -- reachable via require. Try both paths.
    local g = rawget(_G, "cjson")
    if type(g) == "table" then return g end
    local ok, mod_or_err = pcall(require, "cjson")
    if ok and type(mod_or_err) == "table" then return mod_or_err end
    return nil
end

-- ===========================================================================
-- Optional capture metadata: Personality Picker and EWC (v0.26.3)
-- ===========================================================================
--
-- ProfileUtils.pack_profile only serializes Fatshark's backend profile. It
-- cannot see client-side choices made by Personality Picker or Extended Weapon
-- Customization, so those travel in small sidecar settings of their own.
-- Captured data always wins over curated defaults. Clearing a sidecar restores
-- the old behaviour without touching the packed character profile.

local function _stored_setting(prefix, preset_id)
    if not _mod or not _by_id[preset_id] then return nil end
    local raw = _mod:get(prefix .. preset_id)
    if type(raw) == "string" and raw ~= "" then return raw end
    return nil
end

function M.set_stored_personality(preset_id, voice)
    if not _mod or not _by_id[preset_id] then return false, "unknown preset" end
    if voice ~= nil and (type(voice) ~= "string" or voice == "") then
        return false, "voice must be a non-empty string"
    end
    _mod:set(KEY_PERSONALITY_PREFIX .. preset_id, voice or "", false)
    return true
end

function M.stored_personality(preset_id)
    local stored = _stored_setting(KEY_PERSONALITY_PREFIX, preset_id)
    if stored then return stored end
    local defaults = _default_captures and _default_captures()
    local bundled = defaults and defaults.personality
        and defaults.personality[preset_id]
    if type(bundled) == "string" and bundled ~= "" then return bundled end
    return nil
end

-- Preserve the Personality Picker choice exactly, including a virtual preset
-- such as Binharic-only. This value belongs in PP's bot-slot setting, not in a
-- Darktide profile or NetworkLookup.
function M.personality_for(preset_id, source_voice)
    local preset = _by_id[preset_id]
    if not preset then return source_voice end

    -- A catalogue override is an authored identity rule, not a capture
    -- fallback. It must therefore win over older stored captures. This is
    -- what keeps every Tier 1 silent and lets Cartel Recruit remain Ogryn
    -- Brawler even if its physical broker profile was captured earlier with
    -- an ordinary broker personality.
    if type(preset.personality_override) == "string"
        and preset.personality_override ~= "" then
        return preset.personality_override
    end

    local captured = M.stored_personality(preset_id)
    if captured then
        local get_mod = rawget(_G, "get_mod")
        if get_mod and type(get_mod("PersonalityPicker")) == "table" then
            return captured
        end
    end
    return preset.selected_voice or source_voice
end

-- Resolve the official backing voice that is safe to place in the bot profile.
-- Normal personalities pass through unchanged. Virtual personalities ask PP
-- for their backing profile, keeping custom ids out of Darktide networking.
function M.voice_for(preset_id, source_voice)
    local preset = _by_id[preset_id]
    if not preset then return source_voice end

    local choice = M.personality_for(preset_id, source_voice)
    local get_mod = rawget(_G, "get_mod")
    local pp = get_mod and get_mod("PersonalityPicker") or nil

    if type(pp) == "table" and type(pp.backing_voice_for) == "function" then
        local real_voice = source_voice or preset.selected_voice
        local ok, backing = pcall(pp.backing_voice_for, choice, real_voice)

        if ok and type(backing) == "string" and backing ~= "" then
            return backing
        end
    end

    -- A virtual id is never safe as a fallback profile. If PP is missing or
    -- too old to translate it, use the curated/source voice instead.
    if type(choice) == "string" and choice:sub(1, 11) ~= "pp_virtual_" then
        return choice
    end

    return preset.selected_voice or source_voice
end

local function _local_dialogue_voice()
    local get_mod = rawget(_G, "get_mod")
    local pp = get_mod and get_mod("PersonalityPicker") or nil

    if type(pp) == "table" and type(pp.capture_choice) == "function" then
        local ok, choice = pcall(pp.capture_choice)

        if ok and type(choice) == "string" and choice ~= "" then
            return choice
        end
    end

    local Managers = rawget(_G, "Managers")
    local ScriptUnit = rawget(_G, "ScriptUnit")
    local Unit = rawget(_G, "Unit")
    if not Managers or not Managers.player or not ScriptUnit then return nil end
    if type(Managers.player.local_player_safe) ~= "function" then return nil end

    local ok_player, player = pcall(Managers.player.local_player_safe, Managers.player, 1)
    if not ok_player or not player or not player.player_unit then return nil end
    if Unit and type(Unit.alive) == "function" then
        local ok_alive, alive = pcall(Unit.alive, player.player_unit)
        if not ok_alive or not alive then return nil end
    end

    local ok_has, has = pcall(ScriptUnit.has_extension, player.player_unit, "dialogue_system")
    if not ok_has or not has then return nil end
    local ok_ext, extension = pcall(ScriptUnit.extension, player.player_unit, "dialogue_system")
    if not ok_ext or not extension or type(extension.get_voice_profile) ~= "function" then
        return nil
    end
    local ok_voice, voice = pcall(extension.get_voice_profile, extension)
    if ok_voice and type(voice) == "string" and voice ~= "" then return voice end
    return nil
end

function M.capture_personality_for(preset_id, character_id)
    if not _by_id[preset_id] then return false, "unknown preset" end
    local get_mod = rawget(_G, "get_mod")
    if not get_mod or type(get_mod("PersonalityPicker")) ~= "table" then
        return false, "Personality Picker not installed"
    end
    local voice = _local_dialogue_voice()
    if not voice then
        return false, "no live personality available; capture from the hub after your character spawns"
    end
    local ok, err = M.set_stored_personality(preset_id, voice)
    if ok then
        _debug_log("preset", 0, "captured personality " .. tostring(voice)
            .. " for " .. tostring(preset_id), 0, "info")
        return true, voice
    end
    return false, err
end

local EWC_WEAPON_SLOTS = { "slot_primary", "slot_secondary" }

local function _ewc_mod()
    local get_mod = rawget(_G, "get_mod")
    local ewc = get_mod and get_mod("extended_weapon_customization")
    if type(ewc) ~= "table" or type(ewc.gear_settings) ~= "function" then return nil end
    return ewc
end

local function _ewc_origin_name(ewc, path, weapon_template)
    if not ewc or type(ewc.pt) ~= "function" then return nil end
    local ok_pt, pt = pcall(ewc.pt, ewc)
    local origins = ok_pt and type(pt) == "table" and pt.attachment_data_origin
    local by_weapon = type(origins) == "table" and origins[path]
    local origin = type(by_weapon) == "table" and by_weapon[weapon_template] or nil
    if type(origin) == "table" and type(origin.get_name) == "function" then
        local ok_name, name = pcall(origin.get_name, origin)
        if ok_name and type(name) == "string" then return name end
    end
    return nil
end

local function _clean_ewc_settings(ewc, settings, weapon_template)
    local clean = { attachments = {}, material_overrides = {}, origins = {} }
    for slot, value in pairs(settings or {}) do
        if slot == "material_overrides" and type(value) == "table" then
            for attachment_slot, data in pairs(value) do
                if type(data) == "table" and type(data.material_overrides) == "table" then
                    local values = {}
                    for _, material in pairs(data.material_overrides) do
                        if type(material) == "string" and material ~= "" then
                            values[#values + 1] = material
                        end
                    end
                    if #values > 0 then clean.material_overrides[attachment_slot] = values end
                end
            end
        elseif type(value) == "string" and value ~= "" then
            clean.attachments[slot] = value
            local origin = _ewc_origin_name(ewc, value, weapon_template)
            if origin then clean.origins[slot] = origin end
        end
    end
    return clean
end

function M.set_stored_ewc(preset_id, snapshot)
    if not _mod or not _by_id[preset_id] then return false, "unknown preset" end
    if snapshot == nil then
        _mod:set(KEY_EWC_PREFIX .. preset_id, "", false)
        return true
    end
    local cjson = _load_cjson()
    if not cjson then return false, "cjson unavailable" end
    local ok, encoded = pcall(cjson.encode, snapshot)
    if not ok then return false, "EWC encode failed: " .. tostring(encoded) end
    _mod:set(KEY_EWC_PREFIX .. preset_id, encoded, false)
    return true
end

function M.stored_ewc(preset_id)
    local raw = _stored_setting(KEY_EWC_PREFIX, preset_id)
    if not raw then
        local defaults = _default_captures and _default_captures()
        local bundled = defaults and defaults.ewc and defaults.ewc[preset_id]
        if type(bundled) == "string" and bundled ~= "" then raw = bundled end
    end
    if not raw then return nil end
    local cjson = _load_cjson()
    if not cjson then return nil end
    local ok, decoded = pcall(cjson.decode, raw)
    if not ok or type(decoded) ~= "table" or decoded.version ~= 1 then return nil end
    return decoded
end

function M.capture_ewc_for(preset_id, character_id)
    if not _by_id[preset_id] then return false, "unknown preset" end
    local ewc = _ewc_mod()
    if not ewc then return false, "Extended Weapon Customization not installed" end

    local source = character_id and _live_profile_if_current(character_id) or nil
    source = source or (character_id and _profile_cache[character_id])
    if type(source) ~= "table" then return false, "source profile unavailable" end

    local snapshot = { version = 1, weapons = {} }
    local captured = 0
    for i = 1, #EWC_WEAPON_SLOTS do
        local slot = EWC_WEAPON_SLOTS[i]
        local item = source.loadout and source.loadout[slot]
        local gear_id = source.loadout_item_ids and source.loadout_item_ids[slot]
        if not gear_id and item and type(ewc.gear_id) == "function" then
            local ok_id, resolved_id = pcall(ewc.gear_id, ewc, item)
            if ok_id then gear_id = resolved_id end
        end
        local settings
        if gear_id then
            local ok_settings, result = pcall(ewc.gear_settings, ewc, gear_id)
            if ok_settings and type(result) == "table" then settings = result end
        end
        if item and settings then
            local clean = _clean_ewc_settings(ewc, settings, item.weapon_template)
            if next(clean.attachments) or next(clean.material_overrides) then
                snapshot.weapons[slot] = {
                    item_name = item.name,
                    weapon_template = item.weapon_template,
                    settings = clean,
                }
                captured = captured + 1
            end
        end
    end

    -- Recapturing while EWC has no edits clears stale customization. This is
    -- intentional and matches the overwrite semantics of NPC Look captures.
    local ok, err = M.set_stored_ewc(preset_id, snapshot)
    if not ok then return false, err end
    _debug_log("preset", 0, "captured EWC snapshot for " .. tostring(preset_id)
        .. " (" .. tostring(captured) .. " weapons)", 0, "info")
    return true, captured
end

function M.capture_optional_for(preset_id, character_id)
    local result = {}
    local ok_voice, voice_or_err = M.capture_personality_for(preset_id, character_id)
    result.personality = {
        ok = ok_voice,
        value = ok_voice and voice_or_err or nil,
        reason = ok_voice and nil or voice_or_err,
    }
    local ok_ewc, count_or_err = M.capture_ewc_for(preset_id, character_id)
    result.ewc = {
        ok = ok_ewc,
        count = ok_ewc and count_or_err or nil,
        reason = ok_ewc and nil or count_or_err,
    }
    local ok_filter, filter_or_err = M.capture_voice_filter_for(preset_id)
    result.voice_filter = {
        ok = ok_filter,
        value = ok_filter and filter_or_err or nil,
        reason = ok_filter and nil or filter_or_err,
    }
    return result
end

-- v0.23.1 (Nexus beta): bundled default captures. Every preset captured for a
-- release ships in default_captures.lua so a
-- fresh install fields a dressed, talented warband immediately. The
-- user's OWN capture (the settings channel) always wins; the bundle is
-- only consulted when the channel is empty, so clearing a capture
-- returns to the bundled default rather than to bare vanilla. Lazy,
-- load-once, and a missing/broken bundle degrades to exactly the old
-- no-capture behaviour.
local _default_captures_cache = nil
_default_captures = function()
    if _default_captures_cache == nil then
        local loaded = false
        if _mod and type(_mod.io_dofile) == "function" then
            local ok, m = pcall(_mod.io_dofile, _mod,
                "Pilgrimage/scripts/mods/Pilgrimage/default_captures")
            if ok and type(m) == "table" then
                _default_captures_cache = m
                loaded = true
            end
        end
        if not loaded then _default_captures_cache = false end
    end
    return _default_captures_cache or nil
end

-- Channel first, bundle second. Returns nil when neither has content.
local function _stored_raw(prefix, preset_id, kind)
    local raw = _mod and _mod:get(prefix .. preset_id)
    if type(raw) == "string" and raw ~= "" then return raw end
    local defaults = _default_captures()
    local bucket = defaults and defaults[kind]
    local fallback = bucket and bucket[preset_id]
    if type(fallback) == "string" and fallback ~= "" then return fallback end
    return nil
end

function M.has_stored_look_state(preset_id)
    if not _mod or not _by_id[preset_id] then return false end
    return _stored_raw(KEY_LOOK_STATE_PREFIX, preset_id, "look_state") ~= nil
end

-- v0.22.34: cache the decoded look state per (preset_id, raw JSON).
-- Kaizen reported 6 fps in the hub after leaving a mission; profiling
-- (mental) points at this function: our UI hooks call it on every
-- portrait / profile spawn for our bot profiles, and the mission-end
-- scoreboard keeps four bot profiles addressable while it renders,
-- so cjson.decode runs dozens of times per frame. The cache is keyed
-- by RAW JSON so a set_stored_look_state auto-invalidates: the next
-- read gets a different `raw` string and skips the cache.
local _look_state_cache = {}   -- [preset_id] = { raw = <string>, decoded = <table> }

local function _invalidate_look_state_cache(preset_id)
    if preset_id then
        _look_state_cache[preset_id] = nil
    else
        _look_state_cache = {}
    end
end

function M.stored_look_state(preset_id)
    if not _mod or not _by_id[preset_id] then return nil end
    -- v0.23.1: falls back to the bundled default capture; the raw-keyed
    -- cache below stays correct because the bundle string is stable.
    local raw = _stored_raw(KEY_LOOK_STATE_PREFIX, preset_id, "look_state")
    if type(raw) ~= "string" or raw == "" then return nil end

    local cached = _look_state_cache[preset_id]
    if cached and cached.raw == raw then return cached.decoded end

    local cjson = _load_cjson()
    if not cjson then return nil end
    local ok, decoded = pcall(cjson.decode, raw)
    if not ok or type(decoded) ~= "table" then return nil end

    _look_state_cache[preset_id] = { raw = raw, decoded = decoded }
    return decoded
end

function M.set_stored_look_state(preset_id, snapshot)
    if not _mod or not _by_id[preset_id] then return false, "unknown preset" end
    _invalidate_look_state_cache(preset_id)
    if snapshot == nil then
        _mod:set(KEY_LOOK_STATE_PREFIX .. preset_id, "", false)
        return true
    end
    local cjson = _load_cjson()
    if not cjson then return false, "cjson unavailable" end
    local ok, encoded = pcall(cjson.encode, snapshot)
    if not ok then return false, "encode failed: " .. tostring(encoded) end
    _mod:set(KEY_LOOK_STATE_PREFIX .. preset_id, encoded, false)
    return true
end

-- ===========================================================================
-- Per-preset packed profile snapshot (v0.22.27)
-- ===========================================================================
--
-- _profile_cache gets overwritten every time ProfilesService fetches
-- (which fires on StateLoading entry via Pilgrimage.lua's state
-- handler). The fetched profile always reflects the CURRENTLY-ACTIVE
-- loadout preset of that character. So bots using
-- `_profile_cache[stored_character_id]` end up cloning whatever
-- loadout is active at bot-spawn time, not what was captured. That's
-- why Kaizen swapped loadouts on the same character and bots followed.
--
-- Fix: at capture time, pack the profile with Fatshark's own
-- pack_profile (which JSON-encodes it, stripping loadout/visual_loadout
-- and replacing the archetype table with its name string). Store the
-- packed JSON per-preset. At apply time, unpack_profile hydrates it
-- back to a full profile (with archetype table re-resolved, loadout
-- and visual_loadout regenerated from item ids/data). That gives us a
-- point-in-time snapshot that survives loadout swaps AND game
-- restarts.

function M.has_stored_packed_profile(preset_id)
    if not _mod or not _by_id[preset_id] then return false end
    return _stored_raw(KEY_PACKED_PROFILE_PREFIX, preset_id, "packed_profile") ~= nil
end

function M.stored_packed_profile(preset_id)
    if not _mod or not _by_id[preset_id] then return nil, "unknown preset" end
    -- v0.23.1: falls back to the bundled default capture.
    local raw = _stored_raw(KEY_PACKED_PROFILE_PREFIX, preset_id, "packed_profile")
    if type(raw) ~= "string" or raw == "" then return nil, "no packed profile stored" end

    local ok_pu, ProfileUtils = pcall(require, "scripts/utilities/profile_utils")
    if not ok_pu or type(ProfileUtils.unpack_profile) ~= "function" then
        return nil, "ProfileUtils.unpack_profile unavailable"
    end
    local ok, profile = pcall(ProfileUtils.unpack_profile, raw)
    if not ok or type(profile) ~= "table" then
        return nil, "unpack_profile failed: " .. tostring(profile)
    end
    return profile
end

function M.set_stored_packed_profile(preset_id, packed_json)
    if not _mod or not _by_id[preset_id] then return false, "unknown preset" end
    if packed_json == nil then
        _mod:set(KEY_PACKED_PROFILE_PREFIX .. preset_id, "", false)
        return true
    end
    if type(packed_json) ~= "string" then return false, "packed_json must be string" end
    _mod:set(KEY_PACKED_PROFILE_PREFIX .. preset_id, packed_json, false)
    return true
end

-- Remove only the user's per-preset capture. Each capture is split across
-- several hidden DMF settings because the game profile, NPC Look, Personality
-- Picker, EWC and Vox Filter are independent systems. Emptying every channel
-- makes the existing readers fall through to default_captures.lua. Party slot
-- bindings, unlocks, Penances and progression are deliberately left alone.
M.PERSONAL_CAPTURE_PREFIXES = {
    KEY_SOURCE_PREFIX,
    KEY_LOOK_STATE_PREFIX,
    KEY_PACKED_PROFILE_PREFIX,
    KEY_PERSONALITY_PREFIX,
    KEY_EWC_PREFIX,
    KEY_VOICE_FILTER_PREFIX,
    KEY_VOICE_FILTER_BASELINE_PREFIX,
}

function M.restore_bundled_capture(preset_id)
    if not _mod or not _by_id[preset_id] then return false, "unknown preset" end

    local cleared = 0
    for i = 1, #M.PERSONAL_CAPTURE_PREFIXES do
        local key = M.PERSONAL_CAPTURE_PREFIXES[i] .. preset_id
        local current = _mod:get(key)
        if current ~= nil and current ~= "" then
            _mod:set(key, "", false)
            cleared = cleared + 1
        end
    end

    _invalidate_look_state_cache(preset_id)
    return true, cleared
end

function M.restore_all_bundled_captures()
    if not _mod then return false, "preset module not initialized" end

    local affected = 0
    local cleared = 0
    for i = 1, #M.CATALOGUE do
        local preset = M.CATALOGUE[i]
        local ok, count_or_err = M.restore_bundled_capture(preset.id)
        if not ok then return false, count_or_err end
        if count_or_err > 0 then
            affected = affected + 1
            cleared = cleared + count_or_err
        end
    end

    return true, { presets = affected, fields = cleared }
end

-- v0.23.5 (Kaizen "recapture is stuck" report): the LIVE profile of the
-- character being played right now, when it matches character_id. The
-- fetched _profile_cache refreshes only on loading transitions (the
-- StateLoading handler triggers fetch_all_profiles), so a capture taken
-- after changing loadouts in the hub, without a loading screen in
-- between, re-packed STALE cache data. Same wrong result on every
-- recapture, which is exactly the reported symptom. The live player
-- profile is what the game itself mutates on every equip/talent change,
-- so it is always current for the character you are on.
_live_profile_if_current = function(character_id)
    local Managers = rawget(_G, "Managers")
    if not Managers or not Managers.player then return nil end
    if type(Managers.player.local_player) ~= "function" then return nil end
    local ok, player = pcall(Managers.player.local_player, Managers.player, 1)
    if not ok or not player or type(player.profile) ~= "function" then return nil end
    local ok_p, profile = pcall(player.profile, player)
    if not ok_p or type(profile) ~= "table" then return nil end
    if profile.character_id ~= character_id then return nil end
    return profile
end

-- Capture the profile of `character_id` and store the packed snapshot
-- against `preset_id`. Called by /pil_preset_capture_char and
-- /pil_preset_capture_all after the character binding is set.
-- v0.23.5: prefers the LIVE profile when capturing the character being
-- played (always current); the fetched cache is the fallback for
-- capturing a character you are not on (refreshed at loading screens
-- or via /pil_preset_fetch). pack_profile reads either the same way.
function M.capture_profile_for(preset_id, character_id)
    if not _by_id[preset_id] then return false, "unknown preset" end
    if not character_id then return false, "no character_id" end
    local source = _live_profile_if_current(character_id)
    local from_live = source ~= nil
    if not source then
        source = _profile_cache[character_id]
    end
    if not source then
        return false, "character not in profile cache (open Character Select or run /pil_preset_fetch)"
    end
    local ok_pu, ProfileUtils = pcall(require, "scripts/utilities/profile_utils")
    if not ok_pu or type(ProfileUtils.pack_profile) ~= "function" then
        return false, "ProfileUtils.pack_profile unavailable"
    end
    local ok, packed = pcall(ProfileUtils.pack_profile, source)
    if not ok then return false, "pack_profile failed: " .. tostring(packed) end
    _debug_log("preset", 0, "captured " .. tostring(preset_id)
        .. " from " .. (from_live and "LIVE profile" or "fetched cache"), 0, "info")
    return M.set_stored_packed_profile(preset_id, packed)
end

-- Convenience: grab NPC Look's live snapshot and store it for a preset.
-- Called by /pil_preset_capture_look. Returns (ok, err) so the command
-- can report clearly.
function M.capture_current_look_for(preset_id)
    if not _by_id[preset_id] then return false, "unknown preset" end
    local get_mod = rawget(_G, "get_mod")
    local npc_look = get_mod and get_mod("NPCLook")
    if not npc_look or type(npc_look.npclook_state_snapshot) ~= "function" then
        return false, "NPC Look not installed or missing snapshot API"
    end
    local ok, snap = pcall(npc_look.npclook_state_snapshot)
    if not ok or type(snap) ~= "table" then
        return false, "snapshot call failed"
    end
    -- Strip fields cjson can't round-trip (functions or userdata). The
    -- snapshot itself is pure data per NPC Look's source, but we strip
    -- preset_names since it can be huge and irrelevant to bot apply.
    snap.preset_names = nil
    local ok_store, err_store = M.set_stored_look_state(preset_id, snap)
    -- Snapshot the complete voice-filter state alongside the look too. This is
    -- intentionally duplicated with capture_optional_for so every public
    -- capture path, including look-only recaptures, refreshes the sound.
    pcall(M.capture_voice_filter_for, preset_id)
    return ok_store, err_store
end

function M.request_profile_fetch()
    local Managers = rawget(_G, "Managers")
    if not Managers or not Managers.data_service then return false, "no data service" end
    local svc = Managers.data_service.profiles
    if not svc or type(svc.fetch_all_profiles) ~= "function" then
        return false, "no ProfilesService"
    end
    local ok, err = pcall(function() svc:fetch_all_profiles() end)
    if not ok then return false, tostring(err) end
    return true
end

-- ===========================================================================
-- Currently-selected character helper
-- ===========================================================================
--
-- Used by /pil_preset_capture_char to grab the character_id of whoever
-- is currently selected in the character list (or the character you are
-- playing right now). Reads Managers.data_service.account:selected_character()
-- which is Fatshark's standard "who am I" accessor.

function M.selected_character_id()
    local Managers = rawget(_G, "Managers")
    if not Managers or not Managers.player then return nil end

    -- Preferred: local player's live profile character_id. This works
    -- both in the hub and in a mission because the local player's
    -- profile is populated by the time either environment is loaded.
    if type(Managers.player.local_player) == "function" then
        local ok, player = pcall(Managers.player.local_player, Managers.player, 1)
        if ok and player then
            local profile
            if type(player.profile) == "function" then
                local pok, res = pcall(player.profile, player)
                if pok then profile = res end
            end
            profile = profile or player._profile
            if type(profile) == "table" and profile.character_id then
                return profile.character_id
            end
        end
    end

    -- Fallback: account manager's selected character. This only carries
    -- a value on the character-select screen, so it may be nil in a
    -- mission.
    if Managers.data_service and Managers.data_service.account then
        local acc = Managers.data_service.account
        if type(acc.selected_character) == "function" then
            local ok, res = pcall(acc.selected_character, acc)
            if ok and type(res) == "table" then
                return res.character_id
            elseif ok and type(res) == "string" then
                return res
            end
        end
    end

    return nil
end

-- ===========================================================================
-- Spawn slot counter
-- ===========================================================================

local _spawn_counter = 0

-- v0.22.10: per-mission dedupe for "apply failed" notifications. Keyed
-- by "<preset_id>:<reason>". Without this, a 4-bot party hitting the
-- same "source not cached" case (cache not populated yet on first
-- launch) fires 4 red alerts back-to-back. reset_spawn_counter also
-- clears this so the next mission starts fresh.
local _apply_warn_seen = {}

-- v0.22.17: per-mission cache of the NPC Look decoration output, keyed
-- by source character_id. Rebuilding the decoration for every bot at
-- mission start caused Kaizen's fps to tank; four bots sharing one
-- source now share the cache entry so only the first pays the cost.
-- Cleared in reset_spawn_counter so the next mission picks up any look
-- changes that happened in the hub.
local _npclook_decoration_cache = {}

-- v0.22.20: auto-apply NPC Look on Pilgrimage bots. The pump ticks every
-- 0.5s (registered in bootstrap.lua), iterates bot players, and for any
-- Pilgrimage bot without an "applied" mark whose unit exists AND has a
-- visual_loadout extension, calls npclook_apply_active_look_to_bot_unit.
-- Retries until either apply succeeds cleanly (packages_loading=false),
-- or a retry cap is hit (avoids ticking forever for bots whose apply
-- won't ever complete).
--
-- Keyed by the player object, but stores the exact unit that was dressed.
-- A rescued bot keeps its BotPlayer while Darktide replaces player_unit.
-- Treating the player itself as the completion marker therefore left the
-- replacement body in its incomplete base outfit.
local _npclook_applied     = {}
local _npclook_retry_count = {}
-- v0.22.34: was 40 (with a 0.5s pump = 20s ceiling). Pump interval is
-- now 1.5s (see bootstrap's npclook_bot_apply).
-- v0.22.39: bumped back up to 40. Kaizen reported bot looks not
-- applying on the new preset roster (Argenta + Haneumann + Kibellah +
-- Solomorne, four different cosmetic sets loading at once). The 15
-- cap gave a 22.5s wall-clock ceiling per bot, which was fine for
-- four-of-a-kind Argenta but not for four distinct outfits whose
-- packages can chain-block on each other while NPC Look's package
-- loader works through them. 40 retries at 1.5s = 60s ceiling; the
-- pump early-outs the moment a bot's look actually lands, so the
-- extra headroom costs nothing on successful applies and only pays
-- out when the loader legitimately needs longer.
local NPCLOOK_APPLY_MAX_RETRIES = 40

function M.reset_spawn_counter()
    _spawn_counter = 0
    _apply_warn_seen = {}
    _npclook_decoration_cache = {}
    _npclook_applied = {}
    _npclook_retry_count = {}

    -- v0.22.21: also clear the passives pump's applied set so a fresh
    -- mission re-applies each bot's passives from scratch. Passives
    -- module lookup is best-effort (bootstrap init order guarantees it
    -- exists by the time missions load, but tests may not have it).
    local get_mod = rawget(_G, "get_mod")
    local mod = get_mod and get_mod("Pilgrimage")
    local passives = mod and mod._modules and mod._modules.Passives
    if passives and type(passives.reset_pump_state) == "function" then
        passives.reset_pump_state()
    end
end

-- Called by the Tick scheduler. Cheap early-outs: no NPC Look mod, no
-- patched entry point, no player manager, no bots → returns immediately.
function M.pump_npclook_apply()
    local get_mod = rawget(_G, "get_mod")
    local npc_look = get_mod and get_mod("NPCLook")
    if not npc_look
        or type(npc_look.npclook_apply_active_look_to_bot_unit) ~= "function" then
        return
    end

    local Managers = rawget(_G, "Managers")
    if not Managers or not Managers.player
        or type(Managers.player.bot_players) ~= "function" then
        return
    end

    local ok_players, bot_players = pcall(Managers.player.bot_players, Managers.player)
    if not ok_players or type(bot_players) ~= "table" then return end

    for _, player in pairs(bot_players) do
        local player_unit = player and player.player_unit

        -- A death/rescue or another respawn path replaces the unit without
        -- replacing the BotPlayer. Restart the package-aware apply sequence
        -- for that new body.
        if _npclook_applied[player] ~= player_unit then
            if _npclook_applied[player] ~= nil then
                _npclook_applied[player] = nil
                _npclook_retry_count[player] = nil
                _debug_log("preset", 0,
                    "NPC Look detected a replacement bot unit; reapplying stored look",
                    0, "info")
            end

            -- Read the profile through the standard accessor.
            local profile
            if type(player.profile) == "function" then
                local ok_p, res_p = pcall(player.profile, player)
                if ok_p then profile = res_p end
            end
            profile = profile or player._profile

            local sentinel = type(profile) == "table" and profile._pilgrimage_preset
            if sentinel then
                -- Unit needs to exist and have a visual_loadout extension
                -- before NPC Look can equip on it. The patched
                -- npclook_apply_active_look_to_bot_unit already checks
                -- this and returns cleanly if not, but we can spare the
                -- work by checking player.player_unit up front.
                if player_unit then
                    local retries = _npclook_retry_count[player] or 0
                    if retries >= NPCLOOK_APPLY_MAX_RETRIES then
                        -- Give up. Marking as "applied" stops us
                        -- pumping forever for a bot that will never
                        -- complete.
                        _npclook_applied[player] = player_unit
                        _npclook_retry_count[player] = nil
                        _debug_log("preset", 0,
                            "NPC Look apply hit retry cap for a bot", 0, "warn")
                    else
                        _npclook_retry_count[player] = retries + 1
                        -- v0.22.22: pass the preset's stored look
                        -- state as the second arg if available. Vanilla
                        -- (nil) means "use whatever NPC Look has live",
                        -- which is what pre-v0.22.22 did.
                        local override_state = M.stored_look_state(sentinel)
                        local call_ok, apply_ok, err, loading =
                            pcall(npc_look.npclook_apply_active_look_to_bot_unit, player, override_state)
                        if call_ok and apply_ok and not loading then
                            -- Clean success. Stop retrying this bot.
                            _npclook_applied[player] = player_unit
                            _npclook_retry_count[player] = nil
                            _debug_log("preset", 0,
                                "NPC Look auto-applied to bot after " ..
                                tostring(retries + 1) .. " retries", 0, "info")
                        elseif not call_ok then
                            _debug_log("preset", 0,
                                "NPC Look auto-apply threw: " .. tostring(apply_ok), 5, "warn")
                        else
                            -- Silent retry: err is likely
                            -- "packages_loading" or similar transient.
                            local _ = err  -- silence lint
                        end
                    end
                end
            end
        end
    end
end

local function _next_slot()
    _spawn_counter = _spawn_counter + 1
    return _spawn_counter
end

-- How many active slots (1..limit) are empty. Explicit None and legacy nil
-- bindings are equivalent now that implicit default bots have been removed.
-- bots.lua subtracts this from slot_count() to get the actual spawn count.
function M.none_count(limit)
    limit = tonumber(limit) or 6
    local map = _load_slots()
    local n = 0
    for slot = 1, limit do
        local id = map[slot]
        if id == nil or id == M.NONE_BINDING then n = n + 1 end
    end
    return n
end

-- v0.22.75 REWRITE: the argument is a SPAWN INDEX (the Nth bot the
-- synchronizer adds this mission), not a raw slot number. With None
-- bindings in play the two diverge: if slot 2 of 4 is bound to None,
-- only 3 bots spawn, and spawn index 2 must resolve to slot 3's
-- binding, not slot 2's. So we walk slots in order, skip the
-- None-bound ones, and hand back the binding of the Nth slot that
-- actually spawns. Every consumer of this function (add_bot's counter,
-- the PP voice sync per bot index, the NPCLook pump) indexes bots in
-- spawn order, so they all stay consistent through this one mapping.
function M.resolve_for_slot(spawn_index)
    local default = M.default_preset()
    if default then return default end
    local map = _load_slots()
    spawn_index = tonumber(spawn_index)
    if not spawn_index then return nil end
    local seen = 0
    for slot = 1, 6 do  -- 6 = hard slot cap (bots.lua M.MAX_SLOTS)
        local id = map[slot]
        local occupied = _realms_bridge
            and _realms_bridge.human_occupant_for_bot_slot
            and _realms_bridge.human_occupant_for_bot_slot(slot)
        if not occupied and id and id ~= M.NONE_BINDING then
            seen = seen + 1
            if seen == spawn_index then return id end
        end
    end
    return nil
end

-- ===========================================================================
-- Apply a preset onto the vanilla bot profile (v0.22.10 rewrite)
-- ===========================================================================
--
-- v0.22.8 crashed on mission load. Root cause diagnosed from the Fatshark
-- source (scripts/loading/profile_synchronizer_host.lua) and Better Bots
-- (github.com/hummat/BetterBots, bot_profiles.lua): a bot profile that
-- goes through add_bot is later JSON-packed for network sync, and the
-- pack path calls table.clone_instance on the profile. If our copy
-- stripped metatables from nested tables (item instances especially), a
-- later method call on those tables errors and the engine takes a hard
-- fault.
--
-- v0.22.9 shifted to a shallow copy of the top level (nested tables
-- stayed as shared references so metatables were preserved). That fixes
-- the metatable problem but discards Fatshark's own vanilla bot profile,
-- which has cosmetic/body/visual_loadout fields already set up correctly
-- and is what the spawn pipeline expects to receive.
--
-- v0.22.10 follows Better Bots' proven pattern: MUTATE the vanilla
-- profile in place, only overwriting the class-identity fields we care
-- about (archetype, gender, voice, talents, loadout, name). Every other
-- Fatshark-added field on the vanilla profile is preserved. Nested
-- tables that vary per bot (talents, loadout_item_data) get fresh {}
-- containers so same-preset bots don't share mutable state; item
-- objects and the archetype table are shared references (BB does this
-- and it works, because those tables are cache entries and treated as
-- read-only by the spawn pipeline).

local function _shallow_copy_map(src)
    local out = {}
    if type(src) == "table" then
        for k, v in pairs(src) do out[k] = v end
    end
    return out
end

local function _deep_copy_data(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for k, v in pairs(value) do
        out[k] = _deep_copy_data(v, seen)
    end
    return out
end

local function _validated_ewc_settings(ewc, captured)
    if type(captured) ~= "table" or type(captured.settings) ~= "table" then
        return nil, 0, 0
    end
    local source = captured.settings
    local out = {}
    local accepted = 0
    local rejected = 0
    local registry = ewc.settings and ewc.settings.attachment_data_by_item_string

    for slot, path in pairs(source.attachments or {}) do
        if type(slot) == "string" and type(path) == "string"
            and type(registry) == "table" and registry[path] then
            out[slot] = path
            accepted = accepted + 1
        else
            rejected = rejected + 1
        end
    end

    local materials = {}
    for attachment_slot, values in pairs(source.material_overrides or {}) do
        if type(attachment_slot) == "string" and type(values) == "table" then
            local valid = {}
            for _, material in pairs(values) do
                local ok_valid, item = false, nil
                if type(material) == "string"
                    and type(ewc.validated_material_override_item) == "function" then
                    ok_valid, item = pcall(ewc.validated_material_override_item, ewc, material)
                end
                if ok_valid and item then
                    valid[#valid + 1] = material
                    accepted = accepted + 1
                else
                    rejected = rejected + 1
                end
            end
            if #valid > 0 then
                materials[attachment_slot] = { material_overrides = valid }
            end
        end
    end
    if next(materials) then out.material_overrides = materials end
    if not next(out) then return nil, accepted, rejected end
    return out, accepted, rejected
end

-- Apply EWC after NPC Look has finished constructing the flat loadout. Each
-- weapon receives a clone and a Pilgrimage-only EWC gear id. The real backend
-- gear id remains in loadout_item_ids for Darktide's network/profile code, but
-- every later EWC hook resolves the private id through __original_gear_id.
local function _apply_ewc_snapshot(vanilla_profile, preset_id)
    local snapshot = M.stored_ewc(preset_id)
    if not snapshot or type(snapshot.weapons) ~= "table" then return 0, 0 end
    local ewc = _ewc_mod()
    if not ewc then return 0, 0 end
    if type(table.clone_instance_safe) ~= "function" then
        _debug_log("preset", 0, "EWC bot snapshot skipped: clone_instance_safe unavailable", 0, "warn")
        return 0, 0
    end

    local applied = 0
    local rejected = 0
    for i = 1, #EWC_WEAPON_SLOTS do
        local slot = EWC_WEAPON_SLOTS[i]
        local captured = snapshot.weapons[slot]
        local item = vanilla_profile.loadout and vanilla_profile.loadout[slot]
        if captured and item then
            local identity_matches = captured.item_name == item.name
                and (not captured.weapon_template
                    or captured.weapon_template == item.weapon_template)
            if identity_matches then
                local settings, _, dropped = _validated_ewc_settings(ewc, captured)
                rejected = rejected + (dropped or 0)
                if settings then
                    local ok_clone, clone = pcall(table.clone_instance_safe, item)
                    if ok_clone and type(clone) == "table" then
                        local private_id = "pilgrim_ewc_" .. tostring(preset_id)
                            .. "_" .. tostring(slot)
                        clone.__original_gear_id = private_id

                        -- EWC keeps gear and material caches across missions.
                        -- Clear only our namespaced entry before replacing it,
                        -- otherwise a same-session recapture could resurrect
                        -- the preset's previous material colours.
                        if type(ewc.sweep_gear_id) == "function" then
                            pcall(ewc.sweep_gear_id, ewc, private_id)
                        end
                        if type(ewc.pt) == "function" then
                            local ok_pt, pt = pcall(ewc.pt, ewc)
                            if ok_pt and type(pt) == "table"
                                and type(pt.gear_material_overrides) == "table" then
                                pt.gear_material_overrides[private_id] = nil
                            end
                        end
                        local ok_register = pcall(ewc.gear_settings, ewc,
                            private_id, settings, false)
                        if ok_register then
                            -- A getter pass hydrates EWC's separate material
                            -- cache from the settings table we just registered.
                            pcall(ewc.gear_settings, ewc, private_id)
                            if type(ewc.modify_item) == "function" then
                                pcall(ewc.modify_item, ewc, clone, nil, settings)
                            end
                            if type(ewc.apply_attachment_fixes) == "function" then
                                pcall(ewc.apply_attachment_fixes, ewc, clone)
                            end
                            vanilla_profile.loadout[slot] = clone
                            applied = applied + 1
                        end
                    end
                end
            else
                -- A snapshot must never cross weapon families. Falling back to
                -- the unmodified captured weapon is safer than spawning paths
                -- whose attachment nodes do not exist on this item.
                rejected = rejected + 1
            end
        end
    end

    if applied > 0 then
        local ok_pu, ProfileUtils = pcall(require, "scripts/utilities/profile_utils")
        if ok_pu and type(ProfileUtils.generate_visual_loadout) == "function" then
            local ok_visual, visual = pcall(ProfileUtils.generate_visual_loadout,
                vanilla_profile.loadout)
            if ok_visual and type(visual) == "table" then
                vanilla_profile.visual_loadout = visual
            end
        end
    end
    if rejected > 0 then
        _debug_log("preset", 0, "EWC snapshot for " .. tostring(preset_id)
            .. " skipped " .. tostring(rejected)
            .. " unavailable or incompatible entries", 0, "warn")
    end
    return applied, rejected
end

-- Mutate `vanilla_profile` in place with fields sourced from the cached
-- character profile for `preset_id`. Returns true on success, false and
-- a reason otherwise. On false, the caller MUST NOT hand a partially
-- mutated profile to add_bot (see the hook for the guarded flow).
function M.apply_source_to_profile(vanilla_profile, preset_id)
    if type(vanilla_profile) ~= "table" then return false, "no vanilla profile" end
    local preset = _by_id[preset_id]
    if not preset then return false, "unknown preset" end

    -- v0.22.27: PREFER the packed snapshot over the live cache. Live
    -- cache reflects whichever loadout Kaizen has active RIGHT NOW,
    -- because ProfilesService overwrites the cache entry per-loadout.
    -- Packed snapshot is a point-in-time copy from the capture command.
    -- Only fall back to the live cache if no snapshot was captured
    -- (backward compat with pre-v0.22.27 presets that only had
    -- source_character_id bound).
    local source = M.stored_packed_profile(preset_id)
    local source_id
    if not source then
        source_id = M.source_character_id(preset_id)
        if not source_id then
            return false, "no packed profile stored AND no source character bound"
        end
        source = _profile_cache[source_id]
        if not source then return false, "source character not cached, and no packed snapshot" end
    else
        -- Prefer the packed profile's own character_id so downstream
        -- references (character_id assignment on the bot) stay
        -- consistent with the snapshot.
        source_id = source.character_id or M.source_character_id(preset_id)
    end

    -- Class identity: overwrite outright. archetype is a table reference
    -- from the Archetypes global; sharing it is safe (Archetypes[name] is
    -- effectively a singleton and treated as read-only).
    vanilla_profile.archetype       = source.archetype
    vanilla_profile.current_level   = source.current_level or 30
    vanilla_profile.gender          = source.gender
    vanilla_profile.selected_voice  = M.voice_for(preset_id, source.selected_voice)
    vanilla_profile.voice_effects   = source.voice_effects
    vanilla_profile.skin_color      = source.skin_color
    vanilla_profile.hair_color      = source.hair_color
    vanilla_profile.eye_color       = source.eye_color

    -- Talents: fresh table, shallow-copy scalars. Two bots on the same
    -- preset must not share the talents table because bot runtime may
    -- toggle activation flags per-instance.
    vanilla_profile.talents         = _shallow_copy_map(source.talents)

    -- Bot gestalts: empty {} matches BB's default. If the source has one
    -- (rare, this is a Fatshark bot-only field), copy it too.
    vanilla_profile.bot_gestalts    = _shallow_copy_map(source.bot_gestalts)

    -- Loadout item ids: shallow-copy the slot->gear-id map (scalars).
    vanilla_profile.loadout_item_ids  = _shallow_copy_map(source.loadout_item_ids)

    -- Loadout item data: DEEP-COPY. Contains per-slot override dicts
    -- (perks, traits, base_stats) that will be mutated during any EWC
    -- pass; must not share references between bots or with the source.
    vanilla_profile.loadout_item_data = _deep_copy_data(source.loadout_item_data)

    -- Loadout (resolved item objects): shallow-copy the slot map. The
    -- item objects themselves are MasterItems cache entries, shared by
    -- reference (BB does exactly this and it works).
    vanilla_profile.loadout         = _shallow_copy_map(source.loadout)

    -- Visual loadout: shallow-copy for the same reason.
    vanilla_profile.visual_loadout  = _shallow_copy_map(source.visual_loadout)

    -- v0.22.15: NPC Look integration take 4.
    --
    -- Fix from tracing Fatshark's own profile-to-unit pipeline
    -- (scripts/managers/ui/ui_profile_spawner.lua line 678 for cutscene,
    -- scripts/extension_systems/unit_templates/utilities/unit_template.lua
    -- line 79 for in-mission unit spawn): the in-mission unit spawn
    -- reads profile.visual_loadout DIRECTLY, and in solo play the profile
    -- goes through unchanged (no pack/unpack loop). v0.22.14's writes to
    -- loadout_item_ids/data therefore had no effect in solo, because
    -- nothing regenerates visual_loadout from those persistent fields
    -- when there's no network sync happening.
    --
    -- v0.22.15 asks NPC Look for a decorated LOADOUT (flat slot -> item)
    -- via the same add_look_to_loadout helper as v0.22.14, then uses
    -- Fatshark's OWN public regenerator ProfileUtils.generate_visual_loadout
    -- (profile_utils.lua line 1273) to build a properly nested
    -- visual_loadout with attachments. That's exactly what
    -- ui_profile_spawner does at line 678 for the cutscene, which is
    -- why the cutscene renders correctly. Assigning the result to
    -- vanilla_profile.visual_loadout carries the same look into the
    -- in-mission unit spawn.
    --
    -- Requires our small NPC Look patch (the two functions added to the
    -- end of NPCLook.lua). Without the patch this block silently
    -- no-ops, so shipping is safe either way.
    -- v0.22.17: cache the NPC Look decoration per source character to
    -- avoid rebuilding it once per bot at mission start. add_look_to_loadout
    -- iterates STUDIO_SLOT_ORDER and constructs a full item instance for
    -- every pinned slot, and generate_visual_loadout does another slot
    -- iteration on top. Doing that four times back-to-back at bot spawn
    -- time was causing Kaizen's massive fps drop at mission start.
    -- Since every Sister Argenta bot in the party clones the SAME source
    -- character, the resulting decorated loadout + visual_loadout are
    -- identical, so we compute it for the first bot and reuse for the
    -- rest. Cache is invalidated in reset_spawn_counter (StateLoading
    -- entry) so a fresh mission picks up any look changes.
    local get_mod = rawget(_G, "get_mod")
    local npc_look = get_mod and get_mod("NPCLook")
    if npc_look
        and type(npc_look.npclook_current_state) == "function"
        and type(npc_look.npclook_add_look_to_loadout) == "function" then

        -- v0.22.22: use the preset's OWN stored look snapshot if one
        -- has been captured (/pil_preset_capture_all).
        --
        -- v0.22.61 (2026-08-09): REMOVED the "fall back to whatever NPC
        -- Look currently has pinned on the local player" branch. Field
        -- report: Sister Argenta (Veteran) copied Kaizen's own live
        -- pinned outfit EXACTLY, including every extra slot, because
        -- her preset had no stored snapshot yet. The old fallback
        -- called npclook_current_state() (which returns _look_state,
        -- Kaizen's own pinned overrides on his current character) and
        -- fed that into add_look_to_loadout on top of Argenta's source
        -- gear. With full-slot overrides pinned, every slot was
        -- overwritten. Now capture-all defines a bot's look strictly:
        -- captured -> that snapshot, not captured -> source character's
        -- raw gear stands unmodified. Fallback was intentional in
        -- v0.22.15 (pre-capture-all) so a live NPC Look pin could
        -- propagate to bots without extra UI. Post-capture-all it's
        -- pure footgun.
        local state
        local stored = M.stored_look_state(preset_id)
        if stored and type(stored.applied) == "table" then
            state = stored
        end
        local has_active = type(state) == "table" and (
            type(state.applied) == "table" and next(state.applied) ~= nil
            or type(state.extra_anchors) == "table" and next(state.extra_anchors) ~= nil
        )

        if has_active then
            -- Cache key: source_id + "|stored". "|live" branch dropped
            -- with the fallback above, so a plain "|stored" suffix is
            -- kept only to keep older cache entries in existing runs
            -- from being reused with the new decoration semantics
            -- (they'd have "|live" and still be busted).
            local cache_key = tostring(source_id or "no_id")
                .. "|stored|" .. tostring(preset_id)
            local cached = _npclook_decoration_cache[cache_key]
            if not cached then
                local ok_deco, decorated = pcall(
                    npc_look.npclook_add_look_to_loadout, source.loadout or {}, state)
                local extra_slots

                -- Bake extra-slot presentation data into the bot profile too.
                -- Cutscene characters are separate UIProfileSpawner actors, not
                -- the live bot unit. Carrying this list on the profile lets the
                -- surrogate build the same claws, armour pieces and other extras
                -- directly, without depending on hook order at cinematic start.
                if type(npc_look.npclook_profile_with_look) == "function" then
                    local ok_profile, decorated_profile = pcall(
                        npc_look.npclook_profile_with_look, source, state)

                    if ok_profile and type(decorated_profile) == "table" then
                        extra_slots = decorated_profile.npclook_extra_slots
                        decorated = decorated_profile.loadout or decorated
                        ok_deco = type(decorated) == "table"
                    end
                end

                if ok_deco and type(decorated) == "table" then
                    local ok_pu, ProfileUtils = pcall(
                        require, "scripts/utilities/profile_utils")

                    if ok_pu and type(ProfileUtils) == "table"
                        and type(ProfileUtils.generate_visual_loadout) == "function" then

                        local ok_vl, generated_visual_loadout = pcall(
                            ProfileUtils.generate_visual_loadout, decorated)

                        if ok_vl and type(generated_visual_loadout) == "table" then
                            cached = {
                                loadout = decorated,
                                visual_loadout = generated_visual_loadout,
                                extra_slots = extra_slots,
                            }
                            _npclook_decoration_cache[cache_key] = cached
                        end
                    end
                end
            end

            if cached then
                vanilla_profile.loadout        = cached.loadout
                vanilla_profile.visual_loadout = cached.visual_loadout
                vanilla_profile.npclook_extra_slots = cached.extra_slots
            end
        end
    end

    -- v0.26.3: EWC is optional. With no snapshot or no installed EWC this is a
    -- no-op. Missing addon attachments are rejected individually, leaving that
    -- part of the source weapon unchanged.
    _apply_ewc_snapshot(vanilla_profile, preset_id)

    -- Companion (Auric/beast pet) if the source character has one.
    -- v0.22.36: preset.companion_name overrides profile.companion.name
    -- if set, so an Adamant bot preset can name its dog explicitly
    -- (Solomorne -> "Glaito"). HumanPlayer:companion_name() (which
    -- BotPlayer inherits) reads profile.companion.name at runtime and
    -- the nameplate widget picks it up automatically. Only writes when
    -- the source actually carries a companion (Adamant, mostly) — else
    -- the override would silently create a nameplate on a bot with no
    -- companion at all.
    if source.companion then
        vanilla_profile.companion   = _deep_copy_data(source.companion)
        if preset.companion_name and vanilla_profile.companion then
            vanilla_profile.companion.name = preset.companion_name
        end
    end

    -- Lore, personal, narrative: sourced strings/dicts. Deep-copy for
    -- safety (they can be small nested tables).
    vanilla_profile.lore            = _deep_copy_data(source.lore)
    vanilla_profile.personal        = _deep_copy_data(source.personal)
    vanilla_profile.narrative       = _deep_copy_data(source.narrative)

    -- Name / identity: preset display name wins. original_name is what
    -- our generate_random_name hook returns to short-circuit Fatshark's
    -- random-bot-name pass; setting both keeps the preset name visible
    -- everywhere.
    vanilla_profile.name            = preset.display_name
    vanilla_profile.original_name   = preset.display_name

    -- Sentinels: is_local_profile + _bb_resolved match what BB sets, so
    -- BB (if loaded after us) recognises the profile as already resolved
    -- and yields. _pilgrimage_preset is our own tag so /pil_preset_diag
    -- can identify our bots on live inspection.
    vanilla_profile.is_local_profile   = true
    vanilla_profile._bb_resolved       = true
    vanilla_profile._pilgrimage_preset = preset.id

    -- character_id.
    --
    -- v0.22.67 (2026-08-09): re-shape the mangle to a PURE namespaced
    -- form `pilgrim_<preset_id>` that contains NO substring of the
    -- source character's raw UUID. Field evidence from Kaizen's
    -- bot_spawn_diag.txt: v0.22.62's `<raw_uuid>_pilgrim_<preset>`
    -- form did stop NPCLook's outer hook from matching (that hook
    -- uses plain string EQUALITY), but portrait_ui.profile_updated
    -- at line 22 does a SUBSTRING search
    -- (`string.find(request.id, character_id, nil, true)`) and
    -- updates every cached request whose id contains the incoming
    -- character_id anywhere inside it. With the v0.22.62 shape,
    -- Kaizen's own profile updates (his raw UUID as character_id)
    -- would substring-match Argenta's request id
    -- `<Kaizen's raw UUID>_pilgrim_sister_argenta_<size>` and
    -- re-render Argenta's portrait with Kaizen's live profile —
    -- exactly the "class-matched bot's icon shows me" symptom
    -- across sessions where Kaizen switched from Veteran (traitor
    -- captain outfit copied onto Argenta) to Skitarii (Pasqal's
    -- icon now takes on his Skitarii look). The initial render was
    -- correct; the substring-driven re-render was overwriting it
    -- with local player's live profile on every profile-updated
    -- event Fatshark fires for the local player.
    --
    -- Namespaced form `pilgrim_<preset>` has ZERO overlap with
    -- Fatshark UUIDs (which are hex + dashes, never contain
    -- "pilgrim"). Uniqueness per preset preserves the portrait
    -- cache key stability that v0.22.30 established is critical.
    -- No character_id in the game shares this prefix, so nothing
    -- else's profile_updated event can substring-match a Pilgrimage
    -- bot's request either.
    --
    -- Old (v0.22.62):
    -- v0.22.62: MANGLE with a per-preset suffix instead
    -- of copying the source's UUID verbatim.
    --
    -- Why: when a bot's source character IS one of Kaizen's own
    -- characters (e.g. SISTER_ARGENTA sourced from Kaizen's own
    -- Sororitas Veteran named Sister Argenta), the copied character_id
    -- equals Kaizen's currently-active character_id whenever he plays
    -- that same character. NPCLook's outer spawn_profile /
    -- portrait_ui / cutscene hook chain calls
    -- profile_matches_active_character(profile) with a plain
    -- character_id == local_player.character_id test; that returns
    -- true for the bot; NPCLook then applies the LOCAL player's live
    -- NPC-Look state to the bot (via live_visual.profile_with_active_look).
    -- Field report v0.22.61: Argenta wore Kaizen's exact live outfit
    -- including every extra slot in the intro cinematic, even after
    -- the v0.22.61 apply_source_to_profile fallback removal, because
    -- the cutscene path never touches the baked visual_loadout: it
    -- runs the profile through the LIVE UIProfileSpawner hook chain
    -- where NPCLook fires first and overwrites the loadout with the
    -- local-player look before our inner hook gets a chance to
    -- decorate with the stored preset look.
    --
    -- Suffix keeps character_id STABLE per preset so portrait_ui's
    -- request cache (portrait_ui.lua line 67, keyed on character_id
    -- via string concat) still deduplicates correctly. v0.22.30 tried
    -- BLANKING to nil, which broke the same cache: nil landed the
    -- request under a math.uuid() key and profile_updated could never
    -- find the same slot again to refresh. A stable non-nil string
    -- avoids both problems.
    --
    -- BB compat: BB's yield-guard checks name + is_local_profile +
    -- _bb_resolved (all set above) plus a non-nil character_id string.
    -- It doesn't validate the string against the backend, so a
    -- suffix-mangled id passes the same as the original.
    --
    -- With mangling in place: NPCLook sees a character_id that doesn't
    -- match the local player -> profile_matches_active_character
    -- returns false -> NPCLook returns the profile unchanged ->
    -- our inner hook then decorates with the stored preset look
    -- (or leaves the source's raw gear standing if no snapshot).
    -- This is one place, ONE mangle, covering cutscene + portrait +
    -- any future UI path that goes through NPCLook's chain.
    --
    -- The portrait hook _wrap_portrait_hook further below used to
    -- do the same mangle AT SPAWN TIME conditional on a fresh
    -- decoration; that path is now redundant but left in place as a
    -- second-layer no-op (its "base ~= suffix already applied?" is
    -- naturally idempotent for our suffix shape).
    -- v0.22.67: `pilgrim_<preset>` — pure namespaced form, no raw
    -- source UUID substring. See long comment above.
    vanilla_profile.character_id = "pilgrim_" .. tostring(preset.id)

    -- v0.22.52: custom_title override. Just a marker on the profile;
    -- the actual text substitution happens at nameplate render via
    -- our ProfileUtils.character_title{_no_color} hooks (installed in
    -- Pilgrimage.lua). We do NOT touch profile.loadout.slot_character_title
    -- itself, so the rarity/colour formatting the game applies stays
    -- based on the source's real title item.
    --
    -- v0.22.56 (2026-08-09): accept two shapes now:
    --   string                            -> "keep source's colour"
    --   { text = "...", color = {r,g,b} } -> "force this colour"
    -- The hook receives the marker as-is and decides what to do.
    -- Field test showed Argenta's source title item didn't carry
    -- rarity markup in the game's return string, so "keep source's
    -- colour" produced plain white. The table form gives explicit
    -- control.
    if type(preset.custom_title) == "string" and preset.custom_title ~= "" then
        vanilla_profile._pilgrimage_custom_title = preset.custom_title
    elseif type(preset.custom_title) == "table" and preset.custom_title.text then
        -- Deep copy the color array so a preset-catalogue tweak later
        -- doesn't reach through the profile back into the shared table.
        local color = preset.custom_title.color
        vanilla_profile._pilgrimage_custom_title = {
            text = preset.custom_title.text,
            color = color and { color[1], color[2], color[3] } or nil,
        }
    end

    return true
end

-- The original four class recruits deliberately have no captured character.
-- Their weapons, cosmetics and class skeleton come from Better Bots' stock
-- profiles. Pilgrimage adds only the weak Tier 1 rules after Better Bots has
-- finished resolving that profile.
local DEFAULT_T1_BETTERBOTS_CLASS = {
    moebian_conscript = "veteran",
    militarum_preacher = "zealot",
    grog = "ogryn",
    black_ship_fodder = "psyker",
}

local function _apply_default_t1_identity(profile, preset_id)
    local preset = _by_id[preset_id]
    if type(profile) ~= "table" or not preset then return false end

    -- Better Bots has already resolved the class, weapons and bot gestalts.
    -- Emptying only the talent containers preserves that reliable profile
    -- while making the recruit genuinely weaker than a captured companion.
    profile.talents = {}
    if profile.selected_nodes ~= nil then profile.selected_nodes = {} end
    profile.selected_voice = M.voice_for(preset_id, profile.selected_voice)
    profile.name = preset.display_name
    profile.original_name = preset.display_name
    profile.character_id = "pilgrim_" .. tostring(preset.id)
    profile.is_local_profile = true
    profile._bb_resolved = true
    profile._pilgrimage_preset = preset.id
    profile._pilgrimage_default_t1 = true

    if type(preset.custom_title) == "string" and preset.custom_title ~= "" then
        profile._pilgrimage_custom_title = preset.custom_title
    elseif type(preset.custom_title) == "table" and preset.custom_title.text then
        local color = preset.custom_title.color
        profile._pilgrimage_custom_title = {
            text = preset.custom_title.text,
            color = color and { color[1], color[2], color[3] } or nil,
        }
    end

    return true
end

local function _spawn_default_t1(orig, self, local_player_id, profile,
    preset_id, spawn_index)
    local desired_class = DEFAULT_T1_BETTERBOTS_CLASS[preset_id]
    local setting_id = spawn_index and spawn_index <= 5
        and ("bot_slot_" .. tostring(spawn_index) .. "_profile") or nil
    local get_mod = rawget(_G, "get_mod")
    local better_bots = get_mod and get_mod("BetterBots") or nil
    local previous_choice
    local choice_overridden = false

    -- Better Bots reads this setting synchronously inside its add_bot hook.
    -- Temporarily selecting the class lets Pilgrimage reuse its maintained
    -- default profile without editing or redistributing Better Bots. The
    -- player's own setting is restored before this function returns.
    if setting_id and type(better_bots) == "table"
        and type(better_bots.get) == "function"
        and type(better_bots.set) == "function" then
        previous_choice = better_bots:get(setting_id)
        better_bots:set(setting_id, desired_class, false)
        choice_overridden = true
    end

    local ok_spawn, result = pcall(orig, self, local_player_id, profile)

    if choice_overridden then
        better_bots:set(setting_id, previous_choice, false)
    end

    if not ok_spawn then error(result, 0) end

    -- Fatshark's add_bot only queues this exact table reference. Better Bots
    -- has mutated it by now, while Fatshark does not consume it until the next
    -- synchronizer update, so this is the safe point to strip the talents.
    _apply_default_t1_identity(profile, preset_id)

    local archetype = profile.archetype
    local actual_class = type(archetype) == "table" and archetype.name or archetype
    if actual_class ~= desired_class then
        _debug_log("preset_t1_class:" .. tostring(preset_id), 0,
            "default Tier 1 '" .. tostring(preset_id) .. "' requested "
            .. tostring(desired_class) .. " but received " .. tostring(actual_class)
            .. "; Better Bots supports five resolved slots", 0, "warn")
    end

    return result
end

-- Backward-compat shim. Older test paths and any external caller pass
-- just (profile, preset_id) without needing the full source-cache path;
-- this keeps them working with a minimal metadata-only overlay.
function M.apply_to_profile(profile, preset_id)
    if type(profile) ~= "table" then return false, "no profile" end
    local preset = _by_id[preset_id]
    if not preset then return false, "unknown preset" end
    profile.name = preset.display_name
    profile.original_name = preset.display_name
    if preset.selected_voice then
        profile.selected_voice = preset.selected_voice
    end
    profile._pilgrimage_preset = preset.id
    return true
end

-- ===========================================================================
-- Diagnostic getters (kept for /pil_preset_diag)
-- ===========================================================================

local _stats = {
    add_bot_fires       = 0,
    add_bot_substituted = 0,
    add_bot_fallthrough = 0,
    set_profile_calls   = 0,
    set_profile_blocked = 0,
    set_profile_passed  = 0,
    fetch_all_hits      = 0,
    generate_name_hits  = 0,
}

function M.stats() return _stats end

-- Preserve pre-v0.22.8 diag getters so debug.lua doesn't error on missing
-- functions. They report benign defaults now.
function M.archetype_probe() return nil end
function M.last_archetype_result() return "n/a in v0.22.10 (archetype is sourced from your cached real character)" end
function M.probe_archetype() return { name = "n/a", resolved = true, resolved_name = "n/a" } end

local _recent_set_profile = {}
local MAX_RECENT = 12
local function _record_set_profile(entry)
    _recent_set_profile[#_recent_set_profile + 1] = entry
    while #_recent_set_profile > MAX_RECENT do
        table.remove(_recent_set_profile, 1)
    end
end
function M.recent_set_profile() return _recent_set_profile end

-- ===========================================================================
-- Hook installation
-- ===========================================================================

M.SYNCHRONIZER_HOST_PATH = "scripts/managers/bot/bot_synchronizer_host"  -- unused; kept for grep

local _hook_registered = false
local _last_apply_t = 0
local PILGRIMAGE_RESOLVE_WINDOW_S = 10

function M.install_hooks()
    if _hook_registered then return end
    if not _mod or type(_mod.hook) ~= "function" then return end
    _hook_registered = true

    -- 1. Cache your characters as the game fetches them. The promise
    --    chain is: fetch_all_profiles returns a Promise that resolves
    --    to { profiles = { ... } }. We chain a :next() so we run AFTER
    --    the game's own resolve, and just copy each entry into our
    --    cache keyed by character_id. We stamp original_name so our
    --    generate_random_name hook has something to short-circuit on
    --    if we accidentally leave the cached profile addressable.
    _mod:hook("ProfilesService", "fetch_all_profiles",
        function(orig, self, ...)
            local promise = orig(self, ...)
            if promise and type(promise.next) == "function" then
                promise:next(function(data)
                    if type(data) ~= "table" or type(data.profiles) ~= "table" then
                        return data
                    end
                    _stats.fetch_all_hits = _stats.fetch_all_hits + 1
                    for _, profile in pairs(data.profiles) do
                        if type(profile) == "table" and profile.character_id then
                            profile.original_name = profile.original_name or profile.name
                            if not _profile_cache[profile.character_id] then
                                _profile_cache_count = _profile_cache_count + 1
                            end
                            _profile_cache[profile.character_id] = profile
                        end
                    end
                    _debug_log("preset", 0,
                        "cached " .. tostring(_profile_cache_count) .. " character profile(s)", 0, "info")
                    return data
                end)
            end
            return promise
        end)

    -- 2. Apply preset onto the vanilla bot profile IN PLACE (v0.22.10).
    --    This mirrors Better Bots' proven pattern in
    --    scripts/mods/BetterBots/bot_profiles.lua: keep Fatshark's own
    --    vanilla bot profile object (it already carries cosmetic slots,
    --    body data, and visual_loadout set up correctly), and only
    --    overwrite the class-identity fields (archetype, gender, voice,
    --    talents, loadout, name) with values sourced from the cached
    --    real character profile that the preset is bound to. If the
    --    apply fails (no source bound, source not cached, or a crash),
    --    hand the untouched vanilla profile to orig so the mission
    --    still loads with a default bot in that slot.
    _mod:hook("BotSynchronizerHost", "add_bot",
        function(orig, self, local_player_id, profile)
            local slot = _next_slot()
            _stats.add_bot_fires = _stats.add_bot_fires + 1

            local preset_id = M.resolve_for_slot(slot)
            _debug_log("preset", 0,
                "add_bot fired, slot=" .. tostring(slot) ..
                ", preset=" .. tostring(preset_id), 0, "info")

            if not preset_id then
                _stats.add_bot_fallthrough = _stats.add_bot_fallthrough + 1
                return orig(self, local_player_id, profile)
            end

            if not M.is_unlocked(preset_id) then
                _debug_log("preset", 0,
                    "preset '" .. preset_id .. "' locked for slot " .. tostring(slot), 0, "warn")
                _stats.add_bot_fallthrough = _stats.add_bot_fallthrough + 1
                return orig(self, local_player_id, profile)
            end

            -- The base Veteran, Zealot, Ogryn and Psyker Tier 1 entries are
            -- intentionally not captures. Resolve the corresponding Better
            -- Bots stock class first, then keep its equipment and AI gestalts
            -- while removing every talent and applying the Living Tithe name.
            if DEFAULT_T1_BETTERBOTS_CLASS[preset_id] then
                local result = _spawn_default_t1(orig, self, local_player_id,
                    profile, preset_id, slot)
                _last_apply_t = os.clock and os.clock() or 0
                _stats.add_bot_substituted = _stats.add_bot_substituted + 1
                _debug_log("preset", 0,
                    "applied default Tier 1 preset '" .. tostring(preset_id)
                    .. "' for slot " .. tostring(slot), 0, "info")
                return result
            end

            local ok_apply, applied_or_err, apply_err = pcall(M.apply_source_to_profile, profile, preset_id)
            local applied, err
            if ok_apply then
                applied, err = applied_or_err, apply_err
            else
                applied, err = false, "apply crashed: " .. tostring(applied_or_err)
            end

            if not applied then
                _debug_log("preset", 0,
                    "preset '" .. preset_id .. "' skipped, " .. tostring(err), 0, "warn")
                -- Dedupe: same (preset, reason) fires the alert once per
                -- mission, then goes silent. Rest of the failing slots
                -- still log to debug for /pil_preset_diag inspection.
                local warn_key = tostring(preset_id) .. ":" .. tostring(err)
                if _shared and _shared.notify and not _apply_warn_seen[warn_key] then
                    _apply_warn_seen[warn_key] = true
                    _shared.notify("Pilgrimage: " .. preset_id ..
                        " skipped (" .. tostring(err) .. "). Falling back to default bot.", "alert")
                end
                _stats.add_bot_fallthrough = _stats.add_bot_fallthrough + 1
                return orig(self, local_player_id, profile)
            end

            _last_apply_t = os.clock and os.clock() or 0
            _stats.add_bot_substituted = _stats.add_bot_substituted + 1
            _debug_log("preset", 0,
                "applied preset '" .. preset_id .. "' onto vanilla profile for slot " ..
                tostring(slot), 0, "info")
            -- v0.22.65 / v0.22.66 (2026-08-09): file-based diagnostic
            -- for the "bots missing extras in intro cutscene + portraits"
            -- hunt. Two hypotheses being tested with the SAME line:
            --   H-A: stored snapshots don't contain extra_anchors, so
            --        there's nothing for NPCLook to spawn (capture-all
            --        was run when local player had no extras pinned).
            --   H-B: stored snapshots DO contain extras, but they
            --        never load in time for the cutscene / first
            --        portrait render (async package streaming vs a
            --        ~5s cutscene budget).
            -- The extra_anchors field distinguishes: 0 = H-A (capture
            -- didn't include extras), >0 = H-B (extras were captured,
            -- sync/streaming is what's failing). char_id shows whether
            -- v0.22.62's mangling took effect on this bot's live
            -- profile (should end in "_pilgrim_<id>").
            --
            -- v0.22.66: switched from mod:echo (silent no-op for
            -- Kaizen — DMF logging_mode = custom with all
            -- output_mode_* = 0, per fileio.lua's header note) to
            -- direct file append via Mods.lua.io, matching the
            -- pattern fileio.lua uses. Path
            -- "./../mods/Pilgrimage/bot_spawn_diag.txt". Gated on
            -- log_level != "off"; appends one line per (preset, slot)
            -- per session (no dedup file-side, only in-process).
            do
                local echoed_key = "_pilgrimage_bot_spawn_echoed_" .. preset_id .. "_" .. tostring(slot)
                if not rawget(_G, echoed_key) then
                    rawset(_G, echoed_key, true)
                    local log_level = _mod and type(_mod.get) == "function"
                        and _mod:get("log_level") or "off"
                    if log_level ~= "off" then
                        local stored = M.stored_look_state(preset_id)
                        local extras_count = 0
                        if type(stored) == "table" and type(stored.extra_anchors) == "table" then
                            for _ in pairs(stored.extra_anchors) do
                                extras_count = extras_count + 1
                            end
                        end
                        local applied_count = 0
                        if type(stored) == "table" and type(stored.applied) == "table" then
                            for _ in pairs(stored.applied) do
                                applied_count = applied_count + 1
                            end
                        end
                        -- Inline the fileio path to avoid a new
                        -- module dependency on Preset.init. Matches
                        -- the exact shape fileio.lua uses.
                        -- v0.23.0 (Nexus beta): gated behind the
                        -- diagnostics option so public installs do not
                        -- accumulate log files (/pil_diagnostics on).
                        local diag_on = false
                        do
                            local ok_d, v = pcall(_mod.get, _mod, "diagnostics_enabled")
                            diag_on = ok_d and v == true
                        end
                        local Mods = rawget(_G, "Mods")
                        local io_l = diag_on and Mods and Mods.lua and Mods.lua.io or nil
                        local os_l = Mods and Mods.lua and Mods.lua.os
                        if io_l then
                            local timestamp = "?"
                            if os_l and os_l.date then
                                local ok_t, txt = pcall(os_l.date, "%Y-%m-%d %H:%M:%S")
                                if ok_t and txt then timestamp = txt end
                            end
                            local line = string.format(
                                "[%s] preset=%s slot=%s char_id=%s stored=%s applied_slots=%d extra_anchors=%d\n",
                                timestamp,
                                tostring(preset_id),
                                tostring(slot),
                                tostring(profile and profile.character_id),
                                tostring(stored ~= nil),
                                applied_count,
                                extras_count)
                            pcall(function()
                                local file = io_l.open("./../mods/Pilgrimage/bot_spawn_diag.txt", "a")
                                if file then
                                    file:write(line)
                                    file:close()
                                end
                            end)
                        end
                    end
                end
            end
            -- v0.22.16: silenced per-slot notify. Every mission entry
            -- was firing one notification per bot slot ("Pilgrimage: bot
            -- slot N = X"), and now that the flow works reliably the
            -- messages are noise. The information is still available via
            -- /pil_preset_diag when needed.
            return orig(self, local_player_id, profile)
        end)

    -- 3. Preserve the display name. Fatshark's spawn runs
    --    ProfileUtils.generate_random_name(profile) which normally
    --    stomps profile.name with a random bot name. If the profile
    --    carries original_name (we stamp it in apply_source_to_profile),
    --    return it verbatim so "Sister Argenta" survives.
    local ok_pu, ProfileUtils = pcall(require, "scripts/utilities/profile_utils")
    if ok_pu and type(ProfileUtils) == "table" and type(ProfileUtils.generate_random_name) == "function" then
        _mod:hook(ProfileUtils, "generate_random_name",
            function(orig, profile)
                _stats.generate_name_hits = _stats.generate_name_hits + 1
                if type(profile) == "table" and profile.original_name then
                    return profile.original_name
                end
                return orig(profile)
            end)
    else
        _debug_log("preset", 0,
            "ProfileUtils.generate_random_name not hookable; names may be replaced with random bot names", 0, "warn")
    end

    -- 4. Defense-in-depth: our set_profile guard.
    --
    -- History:
    --   v0.22.2: hooked BotPlayer.set_profile to block Fatshark's
    --   network-sync overwrites within a 10-second post-apply window,
    --   defending the sentinel field.
    --   v0.22.10: profile substitution moved to add_bot; the "network
    --   sync overwrites our field mutations" scenario became less
    --   common because the substituted profile has a real
    --   character_id the backend accepts. Guard kept as
    --   defense-in-depth.
    --   v0.22.64 (2026-08-09): REMOVED the time window and now block
    --   PERMANENTLY. Field diagnosis: with v0.22.62's character_id
    --   mangling in place, the cutscene renders bots correctly, but
    --   the party portrait icons still show the local player's look
    --   for class-matched bots (Argenta while Kaizen plays Veteran).
    --   Timing hypothesis: the intro cutscene resolves within the
    --   10-second post-apply window, so NPCLook's outer hook sees
    --   the mangled character_id and bails. The party HUD portrait
    --   however is a persistent element that also gets refreshed
    --   AFTER a later network-sync-driven set_profile call replaces
    --   our mangled profile with an unmangled Fatshark-canonical
    --   one; that call gets through the old 10-second guard because
    --   we're past the window. The HUD then re-requests the portrait
    --   with the now-unmangled character_id, NPCLook's outer hook
    --   sees class-match, and applies the local player's live look.
    --   Result: correct cutscene, wrong icon.
    --
    -- Fix: any set_profile call that would replace a
    -- `_pilgrimage_preset`-sentinel profile with an incoming profile
    -- lacking the same sentinel is dropped, regardless of how long
    -- ago the last apply was. Pilgrimage OWNS the bot's profile for
    -- the duration of the run; nothing else should be handing that
    -- bot a different profile. This is the correct semantic anyway
    -- (Fatshark's re-sync of a bot slot mid-run would erase the
    -- preset content — voice, name, loadout, everything, not just
    -- character_id — even without this bug).
    --
    -- Allow-through cases:
    --  * incoming carries the SAME sentinel (Pilgrimage refresh —
    --    we're re-applying, that's fine)
    --  * existing profile has no sentinel (not our bot yet, or a
    --    non-Pilgrimage slot)
    --  * incoming has DIFFERENT sentinel (preset swap between runs;
    --    let it through so switching presets works)
    _mod:hook("BotPlayer", "set_profile",
        function(orig, self, profile)
            _stats.set_profile_calls = _stats.set_profile_calls + 1
            local now = os.clock and os.clock() or 0

            local existing_sentinel = self._profile and self._profile._pilgrimage_preset or nil
            local incoming_sentinel = profile and profile._pilgrimage_preset or nil

            _record_set_profile({
                time_since_apply  = now - _last_apply_t,
                existing_sentinel = existing_sentinel,
                existing_char_id  = self._profile and self._profile.character_id or nil,
                existing_name     = self._profile and self._profile.name or nil,
                incoming_sentinel = incoming_sentinel,
                incoming_char_id  = profile and profile.character_id or nil,
                incoming_name     = profile and profile.name or nil,
            })

            -- Permanent block: existing profile is Pilgrimage-owned AND
            -- incoming is not the same preset (either no sentinel, or a
            -- different preset). Dropping preserves the mangled
            -- character_id, the sentinel, the custom title, the voice
            -- override, and the loadout.
            if existing_sentinel and existing_sentinel ~= incoming_sentinel then
                _stats.set_profile_blocked = _stats.set_profile_blocked + 1
                _debug_log("preset", 0,
                    "blocked overwrite of preset '" ..
                    tostring(existing_sentinel) ..
                    "' (incoming sentinel=" .. tostring(incoming_sentinel) ..
                    ", " .. string.format("%.1fs", now - _last_apply_t) ..
                    " since last apply)", 0, "info")
                return
            end

            _stats.set_profile_passed = _stats.set_profile_passed + 1
            return orig(self, profile)
        end)

    -- v0.22.23: UI-path hooks that make Pilgrimage bot profiles keep
    -- their PER-PRESET stored look through the loading cutscene, party
    -- portrait, and any other UI render.
    --
    -- v0.22.30: hook order rethink. Load order: NPCLook loads AFTER us,
    -- so NPCLook's spawn_profile / portrait hooks are the OUTER wrapper,
    -- they run first, decorate with local player look, then hand the
    -- profile down the chain to our hook. Because ours runs LAST before
    -- orig(), our re-decoration overrides theirs cleanly. Which means
    -- we do NOT need to blank profile.character_id to fool NPCLook's
    -- profile_matches_active_character check, and blanking it was
    -- actively harmful: portrait_ui uses character_id as its request
    -- cache key (portrait_ui.lua line 67), so a nil character_id landed
    -- the request under a math.uuid() prefix and profile_updated could
    -- never find it again to refresh. That's why v0.22.29 portraits
    -- showed a stale wrong-loadout render with no NPC Look overlay.
    --
    -- Fix: for a profile carrying our _pilgrimage_preset sentinel with a
    -- stored look, decorate with our stored state via
    -- npclook_profile_with_look (patched-in helper on NPC Look) and
    -- return the decorated copy unchanged. Second return kept for
    -- signature compatibility with the old _wrap_ui_hook; always nil
    -- now that we no longer save/restore character_id.
    --
    -- v0.22.63 (2026-08-09): CRITICAL fix for class-match icon leak.
    -- When we run INNER of NPCLook's outer hook, and NPCLook DID
    -- decorate the profile with the local player's active look
    -- (happens when `profile_matches_active_character` returns true,
    -- which is a plain string compare on character_id — the v0.22.62
    -- mangling was supposed to prevent this, but there is at least
    -- one code path where NPCLook still ends up applying the active
    -- look: their `profile_with_look` sets
    -- `copy.npclook_source_profile = source_profile` on the decorated
    -- table as their own marker for "the original undecorated
    -- profile", per NPCLook.lua line 6762), then the profile we
    -- receive is a shallow-copy of the source with
    -- `loadout = add_look_to_loadout(source_loadout, LOCAL_PLAYER_STATE)`
    -- already baked in. If we then call
    -- `npclook_profile_with_look(that_decorated_profile, stored)` it
    -- OVERLAYS the stored preset look on top of Kaizen-flavour
    -- source_loadout — slots the stored snapshot covers get overwritten
    -- cleanly, but slots the stored snapshot does NOT cover keep
    -- Kaizen's overlay. That's the "Argenta icon shows Kaizen" bleed
    -- Kaizen field-tested after v0.22.62.
    --
    -- Fix: when the incoming profile carries `npclook_source_profile`
    -- (NPCLook's own marker that they decorated it), we KNOW they
    -- ran their overlay pass. Re-decorate from
    -- `profile.npclook_source_profile` (the pristine pre-NPCLook
    -- version) instead of from `profile` (the NPCLook-decorated
    -- version). Stored preset look then overlays a clean base with
    -- no Kaizen bleed-through in uncovered slots.
    --
    -- Safety: this only fires when the sentinel is present, so
    -- non-Pilgrimage profiles are untouched. If for whatever reason
    -- the source-profile lookup fails, fall through to the original
    -- behaviour (decorate `profile` directly) so we don't regress
    -- the non-active-look case where `profile` IS the pristine one.
    local function _pilgrimage_decorate_bot_profile_for_ui(profile)
        if type(profile) ~= "table" then return profile, nil end
        local sentinel = profile._pilgrimage_preset
        if not sentinel then
            -- v0.22.63: also check the NPCLook-marker'd source profile.
            -- Sentinel survives NPCLook's shallow_copy for top-level
            -- scalar fields (comment holds), but be defensive in case
            -- an unusual copy path drops it.
            local origin = profile.npclook_source_profile
            sentinel = type(origin) == "table" and origin._pilgrimage_preset
            if not sentinel then return profile, nil end
        end
        local stored = M.stored_look_state(sentinel)
        if not stored then return profile, nil end
        local get_mod = rawget(_G, "get_mod")
        local npc_look = get_mod and get_mod("NPCLook")
        if not npc_look or type(npc_look.npclook_profile_with_look) ~= "function" then
            return profile, nil
        end
        -- Base = pristine source when NPCLook already decorated,
        -- otherwise the profile itself.
        local base = profile
        if type(profile.npclook_source_profile) == "table" then
            base = profile.npclook_source_profile
        end
        local ok, decorated = pcall(npc_look.npclook_profile_with_look, base, stored)
        if not ok or type(decorated) ~= "table" then return profile, nil end
        -- decorated is a shallow-copy of base with new .loadout and
        -- .npclook_extra_slots. Sentinel and character_id survive the
        -- copy. NPC Look's update hook reads decorated.npclook_extra_slots
        -- on the next frame and applies extras via extra_slot_runtime.
        return decorated, nil
    end

    -- v0.22.28: FIX for v0.22.26. Previous version called pcall(require, path)
    -- at boot time, but ui_profile_spawner and portrait_ui are lazy-loaded
    -- when the UI first needs them, well AFTER mod boot. `require` at boot
    -- returned "table not requireable" and our hook silently no-op'd.
    -- Cutscene bots kept copying Kaizen's live look, portraits copied his
    -- current character, because the intercept never installed.
    --
    -- Fix: use DMF's mod:hook_require, which defers hook install until the
    -- file actually loads. Callback receives the required table; we then
    -- register a normal mod:hook against its method inside. This matches
    -- what NPC Look itself does when hooking classes that load with the
    -- UI, and it survives lazy loading without any timing guesswork.
    local function _wrap_ui_hook(orig, self, profile, ...)
        local decorated = _pilgrimage_decorate_bot_profile_for_ui(profile)
        return orig(self, decorated, ...)
    end

    -- v0.22.30 (portrait-specific): PortraitUI caches by
    -- profile.character_id, so if Kaizen's own portrait was rendered
    -- first with character_id X, and our bot profile arrives with the
    -- same character_id X, load_profile_portrait finds the existing
    -- request and REUSES Kaizen's cached data instead of rendering the
    -- bot. That's why v0.22.29 icons showed a wrong loadout with no
    -- NPC Look overlay — they were the local player's stale portrait.
    --
    -- Fix: for our bots, mangle character_id to a preset-specific
    -- variant (raw_id .. "_pilgrim_" .. preset_id). PortraitUI keys
    -- solely on character_id via string concat, so any suffix breaks
    -- the collision without affecting anything else.
    --
    -- v0.22.62 (2026-08-09): apply_source_to_profile now writes the
    -- suffix at PROFILE CREATION time (with the exact same shape),
    -- so most calls into this wrapper already carry a mangled id and
    -- the append below would double-mangle. Made idempotent: skip
    -- the extra append if the id already ends with our per-preset
    -- suffix. Also: the analogous "we don't need this for the
    -- spawn_profile / cutscene path" claim in v0.22.30 turned out to
    -- be wrong (NPCLook's outer spawn_profile hook DOES read
    -- character_id to decide whether to overlay the local-player
    -- look), which is exactly why apply_source_to_profile now bakes
    -- the mangle in universally. This wrapper is kept as a
    -- second-layer safety net that costs nothing.
    -- v0.22.67: apply_source_to_profile writes the pure
    -- `pilgrim_<preset>` form at bot creation, so this wrapper's own
    -- character_id rewrite becomes: if the incoming character_id
    -- ISN'T already the namespaced form (defensive), rewrite it in
    -- place. Idempotent on the new shape.
    local function _wrap_portrait_hook(orig, self, profile, ...)
        local decorated = _pilgrimage_decorate_bot_profile_for_ui(profile)
        if decorated ~= profile and decorated._pilgrimage_preset then
            local want = "pilgrim_" .. tostring(decorated._pilgrimage_preset)
            if decorated.character_id ~= want then
                decorated.character_id = want
            end
        end
        return orig(self, decorated, ...)
    end

    -- v0.28.34: Visible Equipment and EWC can legitimately finish an
    -- end-of-round character build without a separate slot_body_face unit
    -- (for example when a head item replaces that part). Vanilla assumes the
    -- face unit always exists and calls Unit.has_animation_state_machine(nil),
    -- which crashes as the success/failure screen opens. Keep this bridge
    -- deliberately narrow: only EndView spawners, only after streaming is
    -- complete, and only when the requested face unit is actually absent.
    -- The body animation still plays; merely the optional neutral face pose is
    -- skipped for a model that has no face actor to animate.
    local function _wrap_end_view_face_animation(orig, self, face_animation_event, ...)
        local reference_name = tostring(self and self._reference_name or "")
        local spawn_data = self and self._character_spawn_data
        local slots = spawn_data and spawn_data.slots
        local face_slot = slots and slots.slot_body_face
        local face_unit = face_slot and face_slot.unit_3p

        if string.sub(reference_name, 1, 8) == "EndView_"
            and spawn_data and spawn_data.streaming_complete
            and face_animation_event and face_unit == nil then
            self._pending_face_animation_event = nil
            if self._loading_profile_data then
                self._loading_profile_data.face_animation_event = face_animation_event
            end
            _debug_log("preset", 0,
                "EndView face animation skipped: no slot_body_face unit", 0, "info")
            return
        end

        return orig(self, face_animation_event, ...)
    end

    -- Consolidated per path: our hooks.lua guard rejects duplicate
    -- hook_require registrations for the same path (DMF silently discards
    -- the second, this catches that class of bug loudly). So each file
    -- gets ONE hook_require callback that installs every method hook we
    -- need on it.
    local function _install_method_hook(target, method_name, wrapper)
        if type(target[method_name]) ~= "function" then
            _debug_log("preset", 0,
                "UI hook: method missing " .. tostring(method_name), 0, "warn")
            return
        end
        local sentinel = "_pilgrimage_ui_hook_" .. method_name
        if rawget(target, sentinel) then return end
        rawset(target, sentinel, true)
        _mod:hook(target, method_name, wrapper or _wrap_ui_hook)
    end

    -- v0.22.29: use hooks.require_now (our own wrapper around DMF's
    -- hook_require) instead of raw mod:hook_require. The wrapper ALSO
    -- fires immediately if package.loaded already has the file, which
    -- both of these UI files typically are by the time mod boot runs.
    -- With plain hook_require, an already-loaded file gets no callback
    -- because DMF only walks its own require store (empty for pre-mod
    -- loads), which is why v0.22.28's hooks silently no-op'd for
    -- Kaizen even though the guard against duplicate registration was
    -- correct. hooks.require_now falls back to Lua's package.loaded
    -- cache, so already-required modules still get decorated.
    local function _hook_now(path, cb)
        if _hooks and type(_hooks.require_now) == "function" then
            local ok, err = pcall(_hooks.require_now, path, cb)
            if ok then return end
            -- Fall through to raw mod:hook_require. This happens in the
            -- headless test harness where hooks.lua is loaded but its
            -- install(mod) hasn't been called, leaving its _mod upvalue
            -- nil. In-game, install runs first thing at boot so require_now
            -- always works.
            _debug_log("preset", 0,
                "hooks.require_now failed for " .. path .. ", falling back to hook_require: " ..
                tostring(err), 0, "warn")
        end
        if type(_mod.hook_require) == "function" then
            _mod:hook_require(path, cb)
        end
    end

    _hook_now("scripts/managers/ui/ui_profile_spawner", function(target)
        if type(target) ~= "table" then return end
        _install_method_hook(target, "spawn_profile")
        _install_method_hook(target, "assign_face_animation_event",
            _wrap_end_view_face_animation)
        _debug_log("preset", 0,
            "UI hooks installed: ui_profile_spawner.{spawn_profile, assign_face_animation_event}",
            0, "info")
    end)

    _hook_now("scripts/ui/portrait_ui", function(target)
        if type(target) ~= "table" then return end
        _install_method_hook(target, "load_profile_portrait", _wrap_portrait_hook)
        _install_method_hook(target, "profile_updated", _wrap_portrait_hook)
        _debug_log("preset", 0, "UI hooks installed: portrait_ui.{load_profile_portrait, profile_updated}", 0, "info")
    end)

    _debug_log("preset", 0,
        "v0.22.8 hooks registered: ProfilesService.fetch_all_profiles, BotSynchronizerHost.add_bot, ProfileUtils.generate_random_name, BotPlayer.set_profile; v0.22.23 UI hooks: ui_profile_spawner.spawn_profile, portrait_ui.load_profile_portrait, portrait_ui.profile_updated",
        0, "info")
end

-- Backward-compat: bootstrap fanout still calls M.install (formerly a
-- class-table pass-through). Registration happens in init now, so this
-- is a no-op.
function M.install(_BotSynchronizerHost) return end

-- ===========================================================================

function M.status()
    local defaults = M.default_preset()
    local bindings = M.slot_bindings()
    local counts = {}
    for slot, id in pairs(bindings) do
        counts[#counts + 1] = { slot = slot, id = id }
    end
    table.sort(counts, function(a, b) return a.slot < b.slot end)
    local sources = {}
    for i = 1, #M.CATALOGUE do
        local p = M.CATALOGUE[i]
        sources[#sources + 1] = {
            id = p.id,
            source_character_id = M.source_character_id(p.id),
            captured_personality = M.stored_personality(p.id),
            captured_ewc = M.stored_ewc(p.id) ~= nil,
        }
    end
    return {
        default              = defaults,
        bindings             = counts,
        sources              = sources,
        catalogue_size       = #M.CATALOGUE,
        spawn_counter        = _spawn_counter,
        profile_cache_count  = _profile_cache_count,
    }
end

function M.init(deps)
    _mod = deps.mod
    _shared = deps.shared
    _penances = deps.penances
    _shop = deps.shop
    _realms_bridge = deps.realms_bridge
    _debug_log = deps.debug_log or function() end
    _hooks = deps.hooks

    -- Hero migration must run first. A fresh profile has no old Living Tithe
    -- marker yet, which lets us distinguish it from an existing installation.
    _migrate_tier3_penance_gates()
    _migrate_living_tithe()
    _migrate_no_default_bots()
    M.install_hooks()

    -- Note: profile-fetch kicking on state change is done from
    -- Pilgrimage.lua's own on_game_state_changed handler (a single mod
    -- can only carry one), which calls Preset.request_profile_fetch()
    -- when entering StateLoading or the main menu.
end

return M
