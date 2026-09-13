-- passives.lua
--
-- Bot passive system. Introduced v0.22.21.
--
-- Two concepts:
--
--   * A PASSIVE is a named buff a bot carries for its whole mission
--     lifespan. Under the hood it is a Fatshark buff template applied
--     via BuffExtension:add_internally_controlled_buff. We register our
--     own templates via mod:hook_require on the standard buff_templates
--     require path, so they are indistinguishable from Fatshark's own
--     as far as the buff extension is concerned.
--
--   * TIER PASSIVES are baseline buffs a bot gets purely by being at a
--     certain tier. Tier 1 is the vanilla bot slot, no buffs. Higher
--     tiers get progressively more, matching the design intent that
--     bots you unlock via penances or Ordos are meaningfully stronger.
--
-- A preset picks its tier (baseline passives resolved from tier) plus a
-- list of preset-specific passives (unique flavour). Sister Argenta:
-- tier 3 (Champion baseline) + pilgrim_faith_shield (corruption immunity),
-- her signature Sororitas thematic.
--
-- Adding new passives:
--
--   1. Add an entry to M.CATALOGUE with a unique id, display_name,
--      description, buff_template (usually same as id), and a `custom`
--      block for our own buff (stat_buffs, keywords, duration, etc.).
--      If you want to point at a Fatshark template that already exists,
--      set buff_template = "their_name" and omit `custom`.
--
--   2. Optionally register it in M.TIER_PASSIVES[tier] so any bot at
--      that tier picks it up.
--
--   3. For preset-specific passives, add the id to that preset's
--      `passives` list in preset.lua.
--
-- Adding new tiers:
--
--   Extend M.TIER_PASSIVES with a new key. Presets set their `tier`
--   field to that key.

local M = {}

local _mod
local _shared
local _debug_log

-- Runtime windows shared by custom companion proc buffs and the once-per-second
-- companion updater near the bottom of this file. Keeping these states keyed by
-- unit means a rescued or replaced bot cannot inherit the old unit's effect.
M._companion_runtime = {
    severin = setmetatable({}, { __mode = "k" }),
}

-- ===========================================================================
-- Catalogue
-- ===========================================================================
--
-- The stat_buffs values use the same numeric conventions Fatshark's own
-- templates use:
--
--   damage_taken_multiplier      MULTIPLICATIVE. 0.9 = take 90% damage,
--                                i.e. 10% DR. 0 = full immunity.
--   corruption_taken_multiplier  MULTIPLICATIVE. 0 = corruption immunity.
--   melee_damage / ranged_damage ADDITIVE. 0.1 = +10% damage output.
--   combat_ability_cooldown_modifier  ADDITIVE. -0.15 = 15% faster CD.
--   ability_cooldown_modifier    ADDITIVE. -0.15 = 15% faster CD.
--
-- Verified against /tmp/dtsrc/scripts/settings/buff/buff_settings.lua
-- lines 704-724 and 649-692 (kind labels next to each stat name in
-- Fatshark's own source).

M.CATALOGUE = {
    {
        -- v0.28.8: Darktide's base wound count is three for Ogryn and two
        -- for every other playable archetype. The native difficulty bot
        -- buffs are neutralized during template registration below, then
        -- this private baseline adds the missing wound only to non-Ogryn
        -- Pilgrimage bots. Talents, curios and signature passives remain
        -- additive on top of the resulting three-wound baseline.
        id            = "pilgrim_non_ogryn_baseline_wound",
        display_name  = "Pilgrimage Bot Wound Baseline",
        description   = "Normalizes the bot's unmodified wound count to three.",
        buff_template = "pilgrim_non_ogryn_baseline_wound",
        custom = {
            stat_buffs = {
                extra_max_amount_of_wounds = 1,
            },
        },
    },
    {
        -- v0.22.95 (Abelard batch, safe subset): plain stat, confirmed
        -- spec "Practiced Steel, +30% melee damage".
        id            = "pilgrim_practiced_steel",
        display_name  = "Practiced Steel",
        description   = "+30% melee damage. Decades at the Lord Captain's side.",
        buff_template = "pilgrim_practiced_steel",
        custom = {
            stat_buffs = {
                melee_damage = 0.3,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/zealot/zealot_keystone_fanatic_rage",
        },
    },
    {
        -- v0.22.95 (Cassia, safe subset): the "bit of damage" third of
        -- her kit. Gaze of the Third Eye + Tisiphone's Discipline are
        -- proc passives and ship with the aura-engine batch.
        id            = "pilgrim_navigators_focus",
        display_name  = "Navigator's Focus",
        description   = "+20% warp damage. The third eye sees the seams of things.",
        buff_template = "pilgrim_navigators_focus",
        custom = {
            stat_buffs = {
                warp_damage = 0.2,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/psyker/psyker_passive_souldrinker",
        },
    },
    {
        -- v0.22.96 (Cassia kit, Kaizen-approved): 20% on-hit shock
        -- jolt: Attack.execute of the Smite channel tick profile at
        -- modest power = stagger CC + a little damage.
        id            = "pilgrim_gaze_third_eye",
        display_name  = "Gaze of the Third Eye",
        description   = "Her attacks have a 20% chance to lash the target with warp lightning, staggering it.",
        buff_template = "pilgrim_gaze_third_eye",
        custom = {
            hud_icon = "content/ui/textures/icons/buffs/hud/psyker/psyker_passive_warp_battery",
            template = function(BS)
                return {
                    class_name = "server_only_proc_buff",
                    max_stacks = 1, max_stacks_cap = 1, predicted = false,
                    proc_events = { [BS.proc_events.on_hit] = 0.2 },
                    proc_func = function(params, template_data, template_context, t)
                        pcall(function()
                            local victim = params.attacked_unit
                            if not victim or not HEALTH_ALIVE[victim] then return end
                            local DPT = require("scripts/settings/damage/damage_profile_templates")
                            local DS = require("scripts/settings/damage/damage_settings")
                            local Attack = require("scripts/utilities/attack/attack")
                            Attack.execute(victim, DPT.psyker_protectorate_channel_chain_lightning_activated,
                                "power_level", 200, "damage_type", DS.damage_types.electrocution,
                                "attacking_unit", template_context.unit, "attack_type", "ranged")
                        end)
                    end,
                }
            end,
        },
    },
    {
        -- v0.22.96 (Cassia kit; Kaizen renamed from Paternova to the
        -- late tyrant of House Orsellio): her kills steel the warband.
        id            = "pilgrim_tisiphones_discipline",
        display_name  = "Tisiphone's Discipline",
        description   = "Her kills replenish 10% toughness for the pilgrim.",
        buff_template = "pilgrim_tisiphones_discipline",
        custom = {
            hud_icon = "content/ui/textures/icons/buffs/hud/zealot/zealot_channel_grants_toughness_damage_reduction",
            template = function(BS)
                return {
                    class_name = "server_only_proc_buff",
                    max_stacks = 1, max_stacks_cap = 1, predicted = false,
                    cooldown_duration = 1,
                    proc_events = { [BS.proc_events.on_kill] = 1 },
                    proc_func = function(params, template_data, template_context, t)
                        pcall(function()
                            local player = Managers.player and Managers.player:local_player_safe(1)
                            local unit = player and player.player_unit
                            if not unit then return end
                            local Toughness = require("scripts/utilities/toughness/toughness")
                            Toughness.replenish_percentage(unit, 0.1, false, "buff")
                        end)
                    end,
                }
            end,
        },
    },
    {
        -- v0.22.96 (Jae, confirmed spec): +~7% move speed per stack on
        -- kill, 3 stacks, 5s. Stacks via a short-lived child buff.
        id            = "pilgrim_silver_tongue",
        display_name  = "Silver Tongue",
        description   = "Kills grant her a burst of speed, stacking briefly.",
        buff_template = "pilgrim_silver_tongue",
        custom = {
            hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_movement_speed",
            template = function(BS)
                return {
                    class_name = "server_only_proc_buff",
                    max_stacks = 1, max_stacks_cap = 1, predicted = false,
                    proc_events = { [BS.proc_events.on_kill] = 1 },
                    proc_func = function(params, template_data, template_context, t)
                        pcall(function()
                            local unit = template_context.unit
                            local ext = ScriptUnit.extension(unit, "buff_system")
                            local FixedFrame = rawget(_G, "FixedFrame")
                            local ft = FixedFrame and FixedFrame.get_latest_fixed_time() or t
                            ext:add_externally_controlled_buff("pilgrim_silver_tongue_stack", ft)
                        end)
                    end,
                }
            end,
        },
    },
    {
        -- v0.22.96 (Jae, confirmed spec): dodge-vs-ranged window after
        -- taking ranged health damage, 15s internal cooldown.
        id            = "pilgrim_serpents_reflex",
        display_name  = "Serpent's Reflex",
        description   = "After ranged fire draws her blood, she weaves: counts as dodging ranged for 5 seconds.",
        buff_template = "pilgrim_serpents_reflex",
        custom = {
            hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_dodge",
            template = function(BS)
                return {
                    class_name = "server_only_proc_buff",
                    max_stacks = 1, max_stacks_cap = 1, predicted = false,
                    cooldown_duration = 15,
                    proc_events = { [BS.proc_events.on_damage_taken] = 1 },
                    check_proc_func = function(params, template_data, template_context, t)
                        return params.attack_type == "ranged" and (params.damage or 0) > 0
                    end,
                    proc_func = function(params, template_data, template_context, t)
                        pcall(function()
                            local unit = template_context.unit
                            local ext = ScriptUnit.extension(unit, "buff_system")
                            local FixedFrame = rawget(_G, "FixedFrame")
                            local ft = FixedFrame and FixedFrame.get_latest_fixed_time() or t
                            ext:add_externally_controlled_buff("pilgrim_serpents_reflex_dodge", ft)
                        end)
                    end,
                }
            end,
        },
    },
    {
        id            = "pilgrim_elite_toughness",
        display_name  = "Elite Toughness",
        description   = "+10% damage resistance while operating.",
        buff_template = "pilgrim_elite_toughness",
        custom = {
            stat_buffs = {
                damage_taken_multiplier = 0.9,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/zealot/zealot_channel_grants_toughness_damage_reduction",
        },
    },
    {
        id            = "pilgrim_champion_might",
        display_name  = "Champion Might",
        description   = "+10% damage, +10% damage resistance, -15% combat ability cooldown.",
        buff_template = "pilgrim_champion_might",
        custom = {
            stat_buffs = {
                melee_damage                     = 0.1,
                ranged_damage                    = 0.1,
                damage_taken_multiplier          = 0.9,
                combat_ability_cooldown_modifier = -0.15,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/zealot/zealot_keystone_fanatic_rage",
        },
    },
    {
        id            = "pilgrim_faith_shield",
        display_name  = "Faith's Shield",
        description   = "Immune to corruption damage. Sororitas thematic; Sister Argenta's signature.",
        buff_template = "pilgrim_faith_shield",
        custom = {
            stat_buffs = {
                corruption_taken_multiplier = 0,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/zealot/zealot_aura_cleansing_prayer",
        },
    },
    {
        id            = "pilgrim_expanded_coherency",
        display_name  = "Bot Coherency Field",
        description   = "+300% coherency radius. Universal quality-of-life passive so bots don't visibly stray out of the coherency bubble; they can't strategise about positioning the way a human can.",
        buff_template = "pilgrim_expanded_coherency",
        custom = {
            stat_buffs = {
                -- coherency_radius_modifier is an "additive_multiplier"
                -- per buff_settings.lua line 687, so 3.0 = +300%.
                coherency_radius_modifier = 3.0,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/zealot/zealot_aura_always_in_coherency",
        },
    },
    {
        -- Pure passthrough to a Fatshark buff template. No `custom`
        -- block means install_templates does not synthesize a new one;
        -- add_internally_controlled_buff resolves the name in
        -- Fatshark's own registry (Mortis Trials / Hordes mode).
        --
        -- hordes_buff_coherency_corruption_healing installs a coherency
        -- aura that heals corruption from every ally within Sister
        -- Argenta's coherency radius on a 0.5s interval. Stacks with
        -- her Beacon of Purity talent (zealot_preacher_coherency_corruption_healing),
        -- so a coherent player gets both cleansing pulses.
        --
        -- Uses the Fatshark-provided icon: no hud_icon override needed.
        id            = "pilgrim_beacon_boon",
        display_name  = "Beacon of Purity Boon",
        description   = "Applies the Mortis Trials Beacon of Purity coherency-corruption-healing aura. Stacks with the Beacon of Purity talent for two healing sources.",
        buff_template = "hordes_buff_coherency_corruption_healing",
    },

    -- v0.22.35: three new preset-specific passives, one per new bot.
    -- All three are pure passthroughs to shipped Fatshark hordes-mode
    -- buff templates; no custom stat_buffs synthesis, so
    -- install_templates leaves them alone and add_internally_controlled_buff
    -- resolves them from Fatshark's own registry.

    {
        -- Magos Haneumann's tech-priest signature: his Voltaic Emitter
        -- (Cryptic discharge ability) always fires as if at max
        -- capacitance / stacks. Direct copy of Fatshark's Mortis
        -- Trials boon; Fatshark exposes it as
        -- hordes_buff_cryptic_discharge_ability_always_full_charges_bonus
        -- (hordes_legendary_cryptic_buff_templates.lua line 33).
        id            = "pilgrim_voltaic_master",
        display_name  = "Voltaic Master",
        description   = "Voltaic Emitter always fires at maximum capacitance. Signature of Magos Haneumann.",
        buff_template = "hordes_buff_cryptic_discharge_ability_always_full_charges_bonus",
    },
    {
        -- Two extra wounds via Fatshark's shipped
        -- hordes_buff_two_extra_wounds
        -- (hordes_unkillable_family_buff_templates.lua line 261).
        -- Kibellah stacks this WITH her native Martyrdom keystone in
        -- v0.22.37; extra wound count is exactly what makes Martyr
        -- scale further.
        id            = "pilgrim_indefatigable",
        display_name  = "Indefatigable",
        description   = "+2 wounds. Extra hit points for Martyrdom to scale with.",
        buff_template = "hordes_buff_two_extra_wounds",
    },
    {
        -- v0.22.36: Kibellah's combat multiplier stack, layered on
        -- top of Indefatigable and her native Martyrdom. Kaizen's
        -- spec: +50% attack speed, +50% crit chance, +35% crit
        -- damage. Names match Fatshark's stat_buffs registry exactly
        -- (buff_settings.lua lines 659, 706, 708). attack_speed and
        -- critical_strike_damage are additive_multiplier stats, so
        -- 0.5 = +50%, 0.35 = +35%. critical_strike_chance is a plain
        -- "value" stat, so 0.5 = add 0.5 (i.e. +50 percentage points)
        -- to base chance.
        id            = "pilgrim_kibellah_edge",
        display_name  = "Spinner's Edge",
        description   = "+50% melee attack speed, +50% melee crit chance, +35% melee crit damage. Layered on top of the Martyrdom keystone she runs natively. Melee-only per Kaizen's spec.",
        buff_template = "pilgrim_kibellah_edge",
        -- v0.22.42: was the generic attack_speed / critical_strike_*
        -- names, which apply to BOTH melee AND ranged. Kaizen wants
        -- these melee-only so her ranged play doesn't get an
        -- accidental boost. Fatshark exposes the melee-specific
        -- variants directly:
        --   melee_attack_speed         additive_multiplier
        --   melee_critical_strike_chance    value (percentage points)
        --   melee_critical_strike_damage    additive_multiplier
        -- (buff_settings.lua lines 798-800). Same numeric values.
        custom = {
            stat_buffs = {
                melee_attack_speed           = 0.5,
                melee_critical_strike_chance = 0.5,
                melee_critical_strike_damage = 0.35,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/zealot/zealot_hits_grant_stacking_damage",
        },
    },
    {
        -- Solomorne's Castigator Stance grants total damage immunity
        -- for its duration. Direct copy of Fatshark's Mortis Trials
        -- boon: hordes_buff_adamant_stance_immunity
        -- (hordes_legendary_adamant_buff_templates.lua line 33). The
        -- buff itself is passive; it only applies invulnerability
        -- during the ability window via a keywords_func check on
        -- adamant_hunt_stance. So Solomorne carries it always but the
        -- effect only fires when he's actually in stance.
        id            = "pilgrim_castigator_immortal",
        display_name  = "Castigator's Aegis",
        description   = "Total damage immunity while Castigator Stance is active. Solomorne's signature.",
        buff_template = "hordes_buff_adamant_stance_immunity",
    },

    -- v0.22.41: Heinrix's three signature passives.

    {
        -- Direct passthrough to Fatshark's Mortis Trials Psyker boon
        -- (hordes_legendary_psyker_buff_templates.lua line 32). Grants
        -- the `psyker_chain_lightning_full_charge` keyword, so Smite
        -- always fires at full charge as if Scrier's Gaze were up.
        -- Solves the bot's inability to time Scrier's Gaze before
        -- Smite: the boon makes the timing moot.
        id            = "pilgrim_heinrix_full_charge",
        display_name  = "Full Biolightning",
        description   = "Every Smite fires at maximum charge, as if Scrier's Gaze were always active.",
        buff_template = "hordes_buff_psyker_smite_always_max_damage",
    },
    {
        -- v0.22.43: layered on top of Full Biolightning per Kaizen's
        -- correction (keep the passthrough AND add raw damage).
        -- Fatshark exposes smite_damage as an additive_multiplier
        -- stat (buff_settings.lua line 894), so 2.0 = +200%. Stacks
        -- with the full-charge keyword: every Smite lands at max
        -- charge with triple damage on top.
        id            = "pilgrim_heinrix_biolightning",
        display_name  = "Overcharged Biolightning",
        description   = "+200% Smite damage. Stacks with Full Biolightning.",
        buff_template = "pilgrim_heinrix_biolightning",
        custom = {
            stat_buffs = {
                smite_damage = 2.0,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_psyker_smite_always_max_damage",
        },
    },

    {
        -- Enhanced Fast Metabolism (Mortis Trials boon
        -- hordes_buff_health_regen is 1% per 5s). Kaizen wants 3% per
        -- 5s, so this is a custom interval_buff mirroring Fatshark's
        -- own shape (hordes_unkillable_family_buff_templates.lua line
        -- 299) with a tripled percentage. Server-only guard is
        -- explicit; interval_func would otherwise fire redundantly on
        -- clients when they don't own the health extension write.
        id            = "pilgrim_heinrix_regen",
        display_name  = "Enhanced Metabolism",
        description   = "Regenerates 3% max HP every 5 seconds. Does not heal corruption.",
        buff_template = "pilgrim_heinrix_regen",
        custom = {
            hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_health_regen",
            template = function(BS)
                return {
                    class_name    = "interval_buff",
                    max_stacks    = 1,
                    max_stacks_cap = 1,
                    predicted     = false,
                    buff_category = BS.buff_categories.hordes_buff or BS.buff_categories.generic,
                    interval      = 5,
                    interval_func = function(template_data, template_context, template, time_since_start, t)
                        if not template_context.is_server then return end
                        local unit = template_context.unit
                        local ok_ext, ext = pcall(ScriptUnit.extension, unit, "health_system")
                        if not ok_ext or not ext then return end
                        local ok_max, max_health = pcall(ext.max_health, ext)
                        if not ok_max or not max_health then return end
                        local ok_heal_settings, DamageSettings = pcall(require, "scripts/settings/damage/damage_settings")
                        local heal_type = ok_heal_settings
                            and DamageSettings
                            and DamageSettings.heal_types
                            and DamageSettings.heal_types.buff
                        pcall(ext.add_heal, ext, max_health * 0.03, heal_type)
                    end,
                }
            end,
        },
    },

    {
        -- Zealot-flavour on-hit heal. Kaizen asked for the zealot
        -- talent that regenerates health after being hit; talents
        -- can't be injected without wrecking her other keystone, so
        -- this is a server-only proc buff that fires on damage_taken
        -- against Heinrix and adds a small heal. 2s internal cooldown
        -- keeps a burst of hits from mega-healing him.
        --
        -- Values: 3% max HP per proc, min 2s between procs. Matches
        -- the "small consistent" feel of the zealot talent without
        -- the recuperate-from-corruption specificity, which is a
        -- health-extension mechanic that isn't buff-expressible on
        -- its own.
        id            = "pilgrim_heinrix_reactive_heal",
        display_name  = "Reactive Regeneration",
        description   = "Heals 3% max HP whenever hit (2 second cooldown between heals). Zealot-inspired.",
        buff_template = "pilgrim_heinrix_reactive_heal",
        custom = {
            hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_health_regen",
            template = function(BS)
                return {
                    class_name        = "server_only_proc_buff",
                    max_stacks        = 1,
                    max_stacks_cap    = 1,
                    predicted         = false,
                    cooldown_duration = 2,
                    buff_category     = BS.buff_categories.hordes_buff or BS.buff_categories.generic,
                    proc_events       = {
                        [BS.proc_events.on_damage_taken] = 1,
                    },
                    -- Only heal when Heinrix himself is the victim
                    -- AND the hit dealt real HP damage (not just
                    -- toughness). Bots take a lot of toughness chip
                    -- damage; letting that trigger the heal would
                    -- effectively make him unkillable.
                    check_proc_func = function(params, template_data, template_context, t)
                        if params.attacked_unit ~= template_context.unit then
                            return false
                        end
                        return (params.damage_amount or 0) > 0
                    end,
                    proc_func = function(params, template_data, template_context, t)
                        local unit = template_context.unit
                        local ok_ext, ext = pcall(ScriptUnit.extension, unit, "health_system")
                        if not ok_ext or not ext then return end
                        local ok_max, max_health = pcall(ext.max_health, ext)
                        if not ok_max or not max_health then return end
                        local ok_heal_settings, DamageSettings = pcall(require, "scripts/settings/damage/damage_settings")
                        local heal_type = ok_heal_settings
                            and DamageSettings
                            and DamageSettings.heal_types
                            and DamageSettings.heal_types.buff
                        pcall(ext.add_heal, ext, max_health * 0.03, heal_type)
                    end,
                }
            end,
        },
    },

    -- v0.22.44: Kaizen's ask was "make Heinrix hold Smite longer, or
    -- auto-cast Scrier's Gaze so he doesn't overload." Making a bot
    -- auto-time a stance ability before Smite is a behavior-tree
    -- surgery job (Fatshark's engine BT + Better Bots' ability queue,
    -- both non-trivial to override safely). The mod-side answer that
    -- gives the same OUTCOME without touching bot AI: neutralise the
    -- peril generated by Smite itself. If Smite costs no peril,
    -- overload never happens, so channel length is not gated by it
    -- anymore and Scrier's Gaze wouldn't have helped there anyway.
    --
    -- Mechanism: warp_charge_amount_smite is a multiplicative_multiplier
    -- stat (buff_settings.lua line 946). Fatshark's own "Efficient
    -- Smites" talent uses 0.5 (halved peril generation) via
    -- talent_settings_2.combat_ability_3.warp_charge_amount_smite;
    -- Havoc-tier boons go down to 0.2. We drop to 0.05 (95% reduction)
    -- rather than exactly 0, because a hardcoded zero on a
    -- multiplicative stat occasionally trips edge cases in gameplay
    -- code that assumes non-zero costs. 5% is close enough to the
    -- intended outcome (effectively infinite channel) without daring
    -- a division/edge path.
    --
    -- Combined stack on Heinrix: Full Biolightning (every smite fires
    -- max-charge) + Overcharged Biolightning (+200% smite damage) +
    -- Undying Warp (near-zero peril from smite) = channel as long as
    -- the bot AI decides to hold the input, every tick at max damage.
    {
        id            = "pilgrim_heinrix_undying_warp",
        display_name  = "Undying Warp",
        description   = "Smite generates 95% less Peril. Heinrix can channel it indefinitely without overloading.",
        buff_template = "pilgrim_heinrix_undying_warp",
        custom = {
            stat_buffs = {
                -- warp_charge_amount_smite is a multiplicative_multiplier:
                -- 0.05 = final peril per smite is 5% of base.
                warp_charge_amount_smite = 0.05,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/big_buffs/hordes_buff_psyker_smite_always_max_damage",
        },
    },

    -- =====================================================================
    -- v0.22.80: Idira Tlass signature kit (Kaizen-approved with changes,
    -- 2026-08-10). The volatile unsanctioned psyker: heavy warp damage,
    -- violent deaths in her wake, dampened but not tamed Peril, and a
    -- 10% chance that pain answers pain with a Perils detonation.
    -- =====================================================================

    {
        id            = "pilgrim_idira_warp_torrent",
        display_name  = "Warp Torrent",
        description   = "+30% warp damage. The storm does not ask permission.",
        buff_template = "pilgrim_idira_warp_torrent",
        custom = {
            stat_buffs = {
                -- additive_multiplier per buff_settings.lua line 951.
                warp_damage = 0.3,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/psyker/psyker_keystone_empowered_psyche",
        },
    },
    {
        -- Pure passthrough to Fatshark's Mortis Trials boon: enemies
        -- Idira kills with ranged attacks detonate (frag-grenade-class
        -- explosion at the corpse). hordes_legendary_generic_buff_
        -- templates.lua line 229; balanced and localised by Fatshark.
        id            = "pilgrim_idira_unstable_wake",
        display_name  = "Unstable Wake",
        description   = "Enemies slain by Idira's ranged attacks detonate. Things die violently around her.",
        buff_template  = "hordes_buff_explode_enemies_on_ranged_kill",
    },
    {
        id            = "pilgrim_idira_dampened_conduit",
        display_name  = "Overwhelmed, Not Consumed",
        description   = "All Peril generation reduced by 60%. Dampened, never tamed. (Kaizen tuned down from the proposed 90%.)",
        buff_template = "pilgrim_idira_dampened_conduit",
        custom = {
            stat_buffs = {
                -- multiplicative_multiplier (buff_settings.lua line
                -- 945): 0.4 = final Peril per action is 40% of base,
                -- a 60% reduction. Covers ALL her warp actions, unlike
                -- Heinrix's Smite-only variant.
                warp_charge_amount = 0.4,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/psyker/psyker_keystone_warp_syphon",
        },
    },
    {
        id            = "pilgrim_idira_thrice_bound",
        display_name  = "Thrice-Bound Soul",
        description   = "+3 wounds. Compensation for a body the warp keeps borrowing.",
        buff_template = "pilgrim_idira_thrice_bound",
        custom = {
            stat_buffs = {
                -- "value" type (buff_settings.lua line 760): flat +3
                -- health segments, same stat the hordes two-extra-
                -- wounds boon drives.
                extra_max_amount_of_wounds = 3,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/horde_buffs/small_buffs/hordes_buff_two_extra_wounds",
        },
    },
    {
        -- v0.28.9: authentic Perils state, replacing the former direct
        -- explosion approximation. A successful health-damage roll writes
        -- Darktide's warp-charge component to "exploding". The normal
        -- disruptive-state transition then owns the scream, gear sound,
        -- forced animation, native blast, weapon interruption and Peril reset.
        --
        -- The overload action hook below supplies its non-lethal branch only
        -- when this passive is present and the captured build does not already
        -- carry Crystalline Will. The passive then consumes one wound after a
        -- completed overload, which makes Thrice-Bound Soul's +3 wounds the
        -- intended safety reserve. A native Crystalline Will build keeps its
        -- own aftermath and is not charged twice.
        id            = "pilgrim_idira_perilous_vessel",
        display_name  = "Perilous Vessel",
        description   = "Health damage has a 10% chance to trigger Perils. Idira survives, but loses one wound.",
        buff_template = "pilgrim_idira_perilous_vessel",
        custom = {
            hud_icon = "content/ui/textures/icons/buffs/hud/psyker/psyker_blocking_soulblaze",
            template = function(BS)
                local on_damage_taken = BS.proc_events.on_damage_taken
                local on_action_finish = BS.proc_events.on_action_finish
                return {
                    class_name     = "proc_buff",
                    max_stacks     = 1,
                    max_stacks_cap = 1,
                    predicted      = false,
                    buff_category  = BS.buff_categories.hordes_buff or BS.buff_categories.generic,
                    proc_events       = {
                        [on_damage_taken] = 0.1,
                        [on_action_finish] = 1,
                    },
                    start_func = function(template_data, template_context)
                        local unit = template_context.unit
                        local unit_data = ScriptUnit.extension(unit, "unit_data_system")
                        template_data.warp_charge = unit_data:write_component("warp_charge")
                        template_data.character_state = unit_data:read_component("character_state")
                        template_data.health = ScriptUnit.extension(unit, "health_system")
                        local talent = ScriptUnit.has_extension(unit, "talent_system")
                        template_data.native_crystalline_will = talent ~= nil
                            and talent:has_special_rule("psyker_no_knock_down_overload") == true
                        template_data.next_overload_t = 0
                    end,
                    specific_check_proc_funcs = {
                        [on_damage_taken] = function(params, template_data, template_context, t)
                            if not template_context.is_server
                                or params.attacked_unit ~= template_context.unit
                                or (params.damage_amount or 0) <= 0
                                or t < (template_data.next_overload_t or 0) then
                                return false
                            end
                            local warp_charge = template_data.warp_charge
                            local character_state = template_data.character_state
                            return warp_charge ~= nil
                                and warp_charge.state ~= "exploding"
                                and (not character_state
                                    or character_state.state_name ~= "exploding")
                        end,
                        [on_action_finish] = function(params, template_data, template_context)
                            return template_context.is_server
                                and not template_data.native_crystalline_will
                                and params.action_name == "action_warp_charge_explode"
                                and params.reason == "action_complete"
                        end,
                    },
                    specific_proc_func = {
                        [on_damage_taken] = function(params, template_data, template_context, t)
                            local warp_charge = template_data.warp_charge
                            if not warp_charge then
                                _debug_log("passives", 0,
                                    "Perilous Vessel proc had no warp-charge component", 0, "warn")
                                if _shared and type(_shared.notify) == "function" then
                                    _shared.notify("Idira's Perilous Vessel could not start.", "alert")
                                end
                                return
                            end
                            template_data.next_overload_t = t + 3
                            warp_charge.current_percentage = 1
                            warp_charge.starting_percentage = 1
                            warp_charge.state = "exploding"
                            _debug_log("passives", 0,
                                "Perilous Vessel armed native Psyker overload", 0, "info")
                        end,
                        [on_action_finish] = function(params, template_data, template_context)
                            local health = template_data.health
                            if not health or type(health.num_wounds) ~= "function" then
                                _debug_log("passives", 0,
                                    "Perilous Vessel survived overload but health extension was unavailable",
                                    0, "warn")
                                return
                            end
                            local current_wounds = health:num_wounds()
                            if current_wounds > 1
                                and type(health.remove_wounds) == "function" then
                                health:remove_wounds(1)
                                _debug_log("passives", 0,
                                    "Perilous Vessel consumed one wound after overload", 0, "info")
                                return
                            end
                            -- Match Crystalline Will's last-wound branch. This is
                            -- normally reachable only after Idira has exhausted the
                            -- three extra wounds granted by Thrice-Bound Soul.
                            local ok_attack, Attack = pcall(require,
                                "scripts/utilities/attack/attack")
                            local ok_profiles, DamageProfileTemplates = pcall(require,
                                "scripts/settings/damage/damage_profile_templates")
                            local ok_types, DamageSettings = pcall(require,
                                "scripts/settings/damage/damage_settings")
                            if ok_attack and ok_profiles and ok_types
                                and Attack and DamageProfileTemplates and DamageSettings then
                                Attack.execute(template_context.unit,
                                    DamageProfileTemplates.warp_charge_exploding_tick,
                                    "instakill", true,
                                    "damage_type", DamageSettings.damage_types.warp_overload)
                            end
                        end,
                    },
                }
            end,
        },
    },

    -- =====================================================================
    -- v0.22.80: Theodora von Valancius signature kit (partial; her
    -- coherency aura, Lord Captain's Standard, is specced in the
    -- roadmap and ships with Abelard's aura batch). Dynastic Largesse
    -- (+50% Ordos earned while she is in the warband) is implemented
    -- wallet-side (wallet.lua SLOTTED_PRESET_MULTIPLIERS), not as a
    -- buff, so it has no entry here.
    -- =====================================================================

    {
        id            = "pilgrim_theodora_duellist_poise",
        display_name  = "Duellist's Poise",
        description   = "+20% melee damage, +10% attack speed. The Lord Captain's falchion craft.",
        buff_template = "pilgrim_theodora_duellist_poise",
        custom = {
            stat_buffs = {
                melee_damage = 0.2,
                attack_speed = 0.1,
            },
            hud_icon = "content/ui/textures/icons/buffs/hud/zealot/zealot_hits_grant_stacking_damage",
        },
    },

    -- v0.28.54: companion identity pass. These six marker/proc buffs are
    -- deliberately owned by the relevant bot. They never consume or replace
    -- either of the human player's Legendary slots.
    {
        id            = "pilgrim_dreyke_marshals_authority",
        display_name  = "Marshal's Authority",
        description   = "Allies in coherency gain 15% damage and 20% toughness replenishment.",
        buff_template = "pilgrim_dreyke_marshals_authority",
        custom = { stat_buffs = {} },
    },
    {
        id            = "pilgrim_cael_adaptive_rig",
        display_name  = "Adaptive Hunting Rig",
        description   = "Elite and Specialist kills grant 2% damage and 1% speed for the mission. Stacks 10 times.",
        buff_template = "pilgrim_cael_adaptive_rig",
        custom = {
            template = function(BS)
                return {
                    class_name = "server_only_proc_buff",
                    max_stacks = 1,
                    max_stacks_cap = 1,
                    predicted = false,
                    proc_events = { [BS.proc_events.on_kill] = 1 },
                    check_proc_func = function(params, template_data, template_context)
                        if not template_context.is_server then return false end
                        local target = params.attacked_unit or params.dying_unit
                        local unit_data = target
                            and ScriptUnit.has_extension(target, "unit_data_system")
                        local breed = unit_data and unit_data:breed()
                        local tags = breed and breed.tags
                        return tags and (tags.elite or tags.special) or false
                    end,
                    proc_func = function(params, template_data, template_context, t)
                        local extension = ScriptUnit.has_extension(
                            template_context.unit, "buff_system")
                        if extension then
                            extension:add_externally_controlled_buff(
                                "pilgrim_cael_adaptive_rig_stack", t)
                        end
                    end,
                }
            end,
        },
    },
    {
        id            = "pilgrim_nex_killclade_directive",
        display_name  = "Killclade Directive",
        description   = "Chordclaw marks targets for 8s. They take 25% more damage; killing them restores 10% toughness.",
        buff_template = "pilgrim_nex_killclade_directive",
        custom = { stat_buffs = {} },
    },
    {
        id            = "pilgrim_grudd_kingpins_example",
        display_name  = "Kingpin's Example",
        description   = "Enemies he staggers are Shaken for 5s: 20% slower attacks and 15% more damage taken.",
        buff_template = "pilgrim_grudd_kingpins_example",
        custom = { stat_buffs = {} },
    },
    {
        id            = "pilgrim_pasqal_omnispex",
        display_name  = "Omnispex",
        description   = "Highlights priority enemies within 30m, acquiring one new target every 2s.",
        buff_template = "pilgrim_pasqal_omnispex",
        custom = { stat_buffs = {} },
    },
    {
        id            = "pilgrim_solomorne_blood_warrant",
        display_name  = "Blood Warrant",
        description   = "Glaito's pounce applies 16 Bleed and makes Bleed deal 40% more damage for 10s.",
        buff_template = "pilgrim_solomorne_blood_warrant",
        custom = {
            template = function(BS)
                return {
                    class_name = "server_only_proc_buff",
                    max_stacks = 1,
                    max_stacks_cap = 1,
                    predicted = false,
                    proc_events = {
                        [BS.proc_events.on_player_companion_pounce] = 1,
                    },
                    check_proc_func = function(params, template_data, template_context)
                        return template_context.is_server
                            and params.owner_unit == template_context.unit
                            and params.pounced_unit ~= nil
                    end,
                    proc_func = function(params, template_data, template_context, t)
                        local target = params.pounced_unit
                        local extension = ScriptUnit.has_extension(target, "buff_system")
                        if not extension then return end
                        if type(extension.add_internally_controlled_buff_with_stacks)
                                == "function" then
                            extension:add_internally_controlled_buff_with_stacks(
                                "bleed", 16, t, "owner_unit", template_context.unit)
                        end
                        extension:add_internally_controlled_buff(
                            "pilgrim_solomorne_blood_warrant_target", t,
                            "owner_unit", template_context.unit)
                    end,
                }
            end,
        },
    },

    -- v0.28.58: the remaining Tier 3 identity pass. Most entries are markers;
    -- their target-aware behavior is handled by the shared attack hook below.
    {
        id            = "pilgrim_dorian_warrant_seizure",
        display_name  = "Warrant of Seizure",
        description   = "While his personal shield is active, damaged enemies are marked for 10s and take 20% more damage.",
        buff_template = "pilgrim_dorian_warrant_seizure",
        custom = { stat_buffs = {} },
    },
    {
        id            = "pilgrim_severin_tempestus_command_net",
        display_name  = "Tempestus Command Net",
        description   = "Voice of Command grants 20% ranged damage and reload speed for 10s. Priority kills extend it, up to 15s.",
        buff_template = "pilgrim_severin_tempestus_command_net",
        custom = {
            template = function(BS)
                return {
                    class_name = "server_only_proc_buff",
                    max_stacks = 1,
                    max_stacks_cap = 1,
                    predicted = false,
                    proc_events = {
                        [BS.proc_events.on_combat_ability] = 1,
                        [BS.proc_events.on_kill] = 1,
                    },
                    proc_func = function(params, template_data, template_context, t)
                        if not template_context.is_server then return end
                        local unit = template_context.unit
                        local state = M._companion_runtime.severin[unit]
                        if not state then
                            state = {}
                            M._companion_runtime.severin[unit] = state
                        end
                        if params and params.triggering_proc_event
                            == BS.proc_events.on_kill then
                            if not state.active_until or t > state.active_until then return end
                            local target = params.attacked_unit or params.dying_unit
                            local unit_data = target and ScriptUnit.has_extension(
                                target, "unit_data_system")
                            local breed = unit_data and unit_data:breed()
                            local tags = breed and breed.tags
                            if not tags or not (tags.elite or tags.special) then return end
                            state.active_until = math.min(state.cap_until,
                                state.active_until + 1)
                            return
                        end
                        state.active_until = t + 10
                        state.cap_until = t + 15
                    end,
                }
            end,
        },
    },
    {
        id            = "pilgrim_canis_alpha_apex_pursuit",
        display_name  = "Apex Pursuit",
        description   = "His first priority target becomes Quarry. He hunts it 30% faster; its death staggers nearby enemies and restores 10% Toughness.",
        buff_template = "pilgrim_canis_alpha_apex_pursuit",
        custom = { stat_buffs = {} },
    },
    {
        id            = "pilgrim_magleviathan_runaway_engine",
        display_name  = "Runaway Engine",
        description   = "After moving 4m, his next melee hit gains 100% power and impact and releases a half-damage shockwave. 5s cooldown.",
        buff_template = "pilgrim_magleviathan_runaway_engine",
        custom = { stat_buffs = {} },
    },
    {
        id            = "pilgrim_lady_steel_foundry_temper",
        display_name  = "Foundry Temper",
        description   = "Every third consecutive hit against one target applies 5% Brittleness for 8s, up to 30%.",
        buff_template = "pilgrim_lady_steel_foundry_temper",
        custom = { stat_buffs = {} },
    },
    {
        id            = "pilgrim_your_host_encore",
        display_name  = "Encore!",
        description   = "Toxined enemies erupt on death and spread 4 Toxin. Priority deaths restore 10% Toughness to nearby allies.",
        buff_template = "pilgrim_your_host_encore",
        custom = { stat_buffs = {} },
    },
    {
        id            = "pilgrim_epione_medicae_mandate",
        display_name  = "Medicae Mandate",
        description   = "Her Stimm Supply restores 20% maximum health over its full field duration.",
        buff_template = "pilgrim_epione_medicae_mandate",
        custom = { stat_buffs = {} },
    },
    {
        id            = "pilgrim_jocasta_masters_rebuke",
        display_name  = "Master's Rebuke",
        description   = "Enemies struck by her Voice of Command deal 25% less damage and take 25% more for 10s.",
        buff_template = "pilgrim_jocasta_masters_rebuke",
        custom = { stat_buffs = {} },
    },
}

local _by_id = {}
for i = 1, #M.CATALOGUE do _by_id[M.CATALOGUE[i].id] = M.CATALOGUE[i] end

-- ===========================================================================
-- Tier passives
-- ===========================================================================
--
-- Tier is a small integer keyed off a preset's `tier` field. A preset
-- with tier N picks up every id in TIER_PASSIVES[N] AND its own
-- `passives` list. Both apply through the same buff extension so
-- Fatshark's max_stacks / uniqueness handling stops double-application.

M.TIER_PASSIVES = {
    [1] = {},                                          -- Novice, no bonuses
    [2] = { "pilgrim_elite_toughness" },               -- Elite
    [3] = { "pilgrim_champion_might" },                -- Champion
}

-- v0.22.24: universal passives are applied to every Pilgrimage bot
-- regardless of tier or preset. Right now this is Kaizen's coherency
-- widen, which is a quality-of-life patch across the board: bots
-- can't reason about positioning the way you can, so widening their
-- coherency bubble means they don't drift out and drop the aura for
-- their teammates. Apply order: universal → tier baseline → preset
-- specifics (see resolve_for_preset below).
-- v0.28.8: the native difficulty buffs' wound fields are removed in
-- install_templates. resolve_for_preset adds one wound to non-Ogryn classes,
-- producing a three-wound baseline at every difficulty. The +2 on Kibellah
-- and +3 on Idira remain intentional signature passives on top of that.
M.UNIVERSAL_PASSIVES = {
    "pilgrim_expanded_coherency",
}

-- ===========================================================================
-- Public read API
-- ===========================================================================

function M.get(id) return _by_id[id] end
function M.all() return M.CATALOGUE end

function M.tier_passives(tier)
    tier = tonumber(tier) or 1
    return M.TIER_PASSIVES[tier] or {}
end

-- Merge tier passives + preset passives into a flat de-duplicated list.
-- Used by the pump: one list per preset, applied slot by slot to the bot.
function M.resolve_for_preset(preset)
    if type(preset) ~= "table" then return {} end
    local ordered = {}
    local seen = {}
    local function push(id)
        if not id or seen[id] then return end
        seen[id] = true
        ordered[#ordered + 1] = id
    end
    -- v0.22.24: universal → tier baseline → preset-specific.
    -- The seen-set gate makes duplicates across those three layers a
    -- no-op, so a preset can safely list a passive it already gets
    -- from tier or universal (no double-apply on Fatshark's side
    -- either, because our custom templates all set max_stacks = 1).
    for i = 1, #M.UNIVERSAL_PASSIVES do push(M.UNIVERSAL_PASSIVES[i]) end
    if preset.archetype_name and preset.archetype_name ~= "ogryn" then
        push("pilgrim_non_ogryn_baseline_wound")
    end
    local tier_ids = M.TIER_PASSIVES[preset.tier or 1] or {}
    for i = 1, #tier_ids do push(tier_ids[i]) end
    local preset_ids = preset.passives or {}
    for i = 1, #preset_ids do push(preset_ids[i]) end
    return ordered
end

-- ===========================================================================
-- Custom buff template registration
-- ===========================================================================
--
-- Fatshark's buff template registry is built by
-- scripts/settings/buff/buff_templates.lua which returns a merged
-- `templates` table via `settings("BuffTemplates", templates)`. DMF's
-- hook_require lets us amend that table the first time it's required.
-- Runs once per mod load; entries stay live for the whole session.

-- v0.22.81 (Boons v2 foothold): other modules can register their own
-- template catalogues to ride this file's buff_templates hook_require.
-- One hook on the require path is safer than several modules each
-- installing their own; DMF's hook_require behavior with multiple
-- registrants on one path is not something we want to depend on.
-- Boons.lua registers its custom-boon catalogue here at init. Entries
-- use the exact same schema as M.CATALOGUE (id / buff_template /
-- custom.stat_buffs or custom.template factory).
M.EXTERNAL_TEMPLATE_SOURCES = {}

function M.register_template_source(catalogue)
    if type(catalogue) ~= "table" then return false end
    M.EXTERNAL_TEMPLATE_SOURCES[#M.EXTERNAL_TEMPLATE_SOURCES + 1] = catalogue
    return true
end

function M.install_templates()
    if not _mod or type(_mod.hook_require) ~= "function" then return end

    _mod:hook_require("scripts/settings/buff/buff_templates",
        function(templates)
            local ok_settings, BuffSettings = pcall(require, "scripts/settings/buff/buff_settings")
            if not ok_settings or type(BuffSettings) ~= "table" then
                _debug_log("passives", 0,
                    "BuffSettings unavailable; custom templates not registered", 0, "warn")
                return
            end
            local stat_buffs      = BuffSettings.stat_buffs
            local buff_categories = BuffSettings.buff_categories
            local keywords        = BuffSettings.keywords
            if not stat_buffs or not buff_categories then
                _debug_log("passives", 0,
                    "BuffSettings has no stat_buffs/buff_categories; templates not registered",
                    0, "warn")
                return
            end

            -- Darktide normally adds one or two wounds to every bot as the
            -- difficulty rises. That turns the intended three-wound baseline
            -- into four for most classes and five for Ogryn. Remove only that
            -- wound field and leave the native health, Toughness, block and
            -- revive bonuses untouched. Non-Ogryn Pilgrimage bots receive one
            -- explicit baseline wound through resolve_for_preset above.
            local wound_token = stat_buffs.extra_max_amount_of_wounds
            local normalized_native_buffs = 0
            if wound_token ~= nil then
                for _, template_name in ipairs({ "bot_medium_buff", "bot_high_buff" }) do
                    local native_template = templates[template_name]
                    if native_template and type(native_template.stat_buffs) == "table"
                        and native_template.stat_buffs[wound_token] ~= nil then
                        native_template.stat_buffs[wound_token] = nil
                        normalized_native_buffs = normalized_native_buffs + 1
                    end
                end
            end
            _debug_log("passives", 0,
                "normalized native wound bonus in " .. normalized_native_buffs
                    .. " bot difficulty template(s)", 0, "info")

            local registered = 0
            -- v0.22.81: walk our catalogue plus every registered
            -- external source (custom boons from boons.lua ride this
            -- same hook; see register_template_source above).
            local sources = { M.CATALOGUE }
            for si = 1, #M.EXTERNAL_TEMPLATE_SOURCES do
                sources[#sources + 1] = M.EXTERNAL_TEMPLATE_SOURCES[si]
            end
            for src = 1, #sources do
            for i = 1, #sources[src] do
                local p = sources[src][i]
                -- v0.22.38: hard-guard against a catalogue entry that
                -- forgot buff_template. Without this the `templates[nil]`
                -- write throws "table index is nil" and crashes the
                -- game at gameplay init (character select). A skipped
                -- passive is a graceful degradation; a crash is not.
                if p.custom and (type(p.buff_template) ~= "string" or p.buff_template == "") then
                    _debug_log("passives", 0,
                        "passive '" .. tostring(p.id) ..
                        "' has custom stat_buffs but no buff_template field; skipping registration",
                        0, "warn")
                elseif p.custom and not templates[p.buff_template] then
                    -- v0.22.41: two synthesis paths.
                    --
                    -- 1. `custom.template` (table or factory function
                    --    (BuffSettings) -> table): raw template written
                    --    directly against Fatshark's shape. Use when the
                    --    passive needs interval_buff, server_only_proc_buff,
                    --    proc_events, start_func, etc, none of which the
                    --    stat_buffs/keywords shortcut can express.
                    -- 2. `custom.stat_buffs` + `custom.keywords`: the
                    --    original shortcut that synthesises a plain
                    --    duration=huge buff. Covers the vast majority of
                    --    passives (Elite Toughness, Champion Might,
                    --    Spinner's Edge...).
                    local synthesized
                    if p.custom.template then
                        local factory = p.custom.template
                        if type(factory) == "function" then
                            local ok, out = pcall(factory, BuffSettings)
                            if ok and type(out) == "table" then
                                synthesized = out
                            else
                                _debug_log("passives", 0,
                                    "custom template factory for '" .. p.id ..
                                    "' failed: " .. tostring(out), 0, "warn")
                            end
                        elseif type(factory) == "table" then
                            synthesized = factory
                        end
                        if synthesized then
                            -- Fill in name if the factory didn't; keeps
                            -- template-vs-registry consistency.
                            synthesized.name = synthesized.name or p.buff_template
                            if p.custom.hud_icon and not synthesized.hud_icon then
                                synthesized.hud_icon = p.custom.hud_icon
                            end
                        end
                    end

                    if not synthesized then
                        local resolved_stat_buffs = {}
                        for stat_name, value in pairs(p.custom.stat_buffs or {}) do
                            local token = stat_buffs[stat_name]
                            if token ~= nil then
                                resolved_stat_buffs[token] = value
                            else
                                _debug_log("passives", 0,
                                    "unknown stat_buff '" .. tostring(stat_name) ..
                                    "' in passive " .. p.id, 0, "warn")
                            end
                        end

                        local resolved_keywords = {}
                        for _, keyword_name in ipairs(p.custom.keywords or {}) do
                            local token = keywords and keywords[keyword_name]
                            if token ~= nil then
                                resolved_keywords[#resolved_keywords + 1] = token
                            end
                        end

                        synthesized = {
                            class_name    = "buff",
                            name          = p.buff_template,
                            duration      = p.custom.duration or math.huge,
                            predicted     = false,
                            max_stacks    = 1,
                            stat_buffs    = resolved_stat_buffs,
                            keywords      = resolved_keywords,
                            buff_category = buff_categories.generic,
                            hud_icon      = p.custom.hud_icon,
                        }
                    end

                    templates[p.buff_template] = synthesized
                    registered = registered + 1
                end
            end
            end

            -- ===============================================================
            -- v0.25.2 PERFORMANCE FIX (root-caused from Kaizen's 2026-08-12
            -- console log): every custom template registered above must ALSO
            -- be registered in NetworkLookup.buff_templates. Vanilla builds
            -- that lookup at boot from its own template list and gives it a
            -- metatable whose __index on a MISSING key calls
            -- table.dump(lookup_table) and errors (network_lookup.lua:578).
            -- Our pilgrim_ names were never in it, so any engine or mod path
            -- that indexes the lookup by an applied buff's name dumped the
            -- ENTIRE ~5300-entry table to the console log, inside a pcall
            -- that swallowed the error but not the dump. The field readout:
            -- 22 dumps in the first 35 seconds of a leg (the reconciler's
            -- cadence), 817k log lines, 90 MB of log, 100-450 ms frame
            -- stalls, "6 fps upon loading into a mission". Registering the
            -- names kills the storm at the source. rawget is MANDATORY for
            -- the existence probe: a plain read of a missing key IS the dump.
            -- Solo-host mod, so extending the lookup cannot desync anyone;
            -- both ends of the "network" are the same machine.
            local ok_nl, NetworkLookup = pcall(require, "scripts/network_lookup/network_lookup")
            if ok_nl and type(NetworkLookup) == "table"
                and type(NetworkLookup.buff_templates) == "table" then
                local bt = NetworkLookup.buff_templates
                local added = 0
                for src = 1, #sources do
                for i = 1, #sources[src] do
                    local name = sources[src][i].buff_template
                    if type(name) == "string" and name ~= ""
                        and rawget(bt, name) == nil then
                        local index = #bt + 1
                        bt[index] = name
                        bt[name] = index
                        added = added + 1
                    end
                end
                end
				-- Shared Dosage clones native syringe templates before the
				-- aggregate BuffTemplates registry is built. They are not catalogue
				-- entries, so register every other Pilgrimage-owned template found
				-- in the completed registry as well. rawget remains mandatory here.
				for name in pairs(templates) do
					if type(name) == "string"
						and string.find(name, "pilgrim_", 1, true) == 1
						and rawget(bt, name) == nil then
						local index = #bt + 1
						bt[index] = name
						bt[name] = index
						added = added + 1
					end
				end
                if added > 0 then
                    _debug_log("passives", 0, "registered " .. added
                        .. " custom template name(s) in NetworkLookup.buff_templates"
                        .. " (dump-storm fix)", 0, "info")
                end
            else
                _debug_log("passives", 0,
                    "NetworkLookup unavailable; buff lookup dumps may continue", 0, "warn")
            end

            _debug_log("passives", 0,
                "registered " .. registered .. " custom buff template(s)", 0, "info")
        end)
end

-- Perilous Vessel needs one narrow bridge into the real overload action.
-- Darktide decides whether that action kills the Psyker through the private
-- `_psyker_alternative_overload` flag. We leave the native talent decision
-- intact, then turn the flag on only for a unit carrying Idira's passive.
-- Everything else, including the action timing, VFX, SFX and explosion, stays
-- in Fatshark's code. The passive template above owns the one-wound aftermath.
local _idira_overload_hook_installed = false

local function _install_idira_overload_hook(action_class)
    if _idira_overload_hook_installed or not action_class
        or not _mod or type(_mod.hook) ~= "function" then
        return false
    end
    _mod:hook(action_class, "start", function(func, self, action_settings, ...)
        func(self, action_settings, ...)
        local unit = self._player_unit
        local buff_extension = unit and ScriptUnit.has_extension(unit, "buff_system")
        if action_settings and action_settings.overload_type == "warp_charge"
            and buff_extension
            and type(buff_extension.has_buff_using_buff_template) == "function"
            and buff_extension:has_buff_using_buff_template(
                "pilgrim_idira_perilous_vessel") then
            self._psyker_alternative_overload = true
        end
    end)
    _idira_overload_hook_installed = true
    _debug_log("passives", 0,
        "installed authentic Perilous Vessel overload survival hook", 0, "info")
    return true
end

function M.install_idira_overload_hook()
    local classes = rawget(_G, "CLASS")
    if classes and _install_idira_overload_hook(classes.ActionOverloadExplosion) then
        return true
    end
    if _mod and type(_mod.hook_require) == "function" then
        _mod:hook_require(
            "scripts/extension_systems/weapon/actions/action_overload_explosion",
            function(action_class)
                _install_idira_overload_hook(action_class)
            end)
        return true
    end
    _debug_log("passives", 0,
        "could not schedule Perilous Vessel overload survival hook", 0, "warn")
    return false
end

-- Field diagnostic for the probabilistic Idira passive. It uses exactly the
-- same component state as a successful 10% health-damage roll, but only when
-- the live Idira bot actually carries Perilous Vessel. This lets one command
-- prove the native scream, animation and overload action without changing the
-- passive's combat odds.
function M.force_idira_overload()
    local Managers = rawget(_G, "Managers")
    local player_manager = Managers and Managers.player
    if not player_manager or type(player_manager.bot_players) ~= "function" then
        return false, "bot player manager unavailable"
    end
    local ok_players, players = pcall(player_manager.bot_players, player_manager)
    if not ok_players or type(players) ~= "table" then
        return false, "bot list unavailable"
    end
    local unit = nil
    for _, player in pairs(players) do
        local profile = nil
        if player and type(player.profile) == "function" then
            local ok_profile, value = pcall(player.profile, player)
            if ok_profile then profile = value end
        end
        profile = profile or (player and player._profile)
        if profile and profile.character_id == "pilgrim_idira_tlass" then
            unit = player.player_unit
            break
        end
    end
    if not unit then return false, "Idira is not alive in the party" end

    local buff_extension = ScriptUnit.has_extension(unit, "buff_system")
    if not buff_extension
        or type(buff_extension.has_buff_using_buff_template) ~= "function"
        or not buff_extension:has_buff_using_buff_template(
            "pilgrim_idira_perilous_vessel") then
        return false, "Perilous Vessel is not applied to Idira"
    end

    local ok_data, unit_data = pcall(ScriptUnit.extension, unit, "unit_data_system")
    if not ok_data or not unit_data then return false, "unit data unavailable" end
    local ok_warp, warp_charge = pcall(unit_data.write_component,
        unit_data, "warp_charge")
    if not ok_warp or not warp_charge then return false, "warp-charge component unavailable" end
    if warp_charge.state == "exploding" then return false, "Idira is already overloading" end

    warp_charge.current_percentage = 1
    warp_charge.starting_percentage = 1
    warp_charge.state = "exploding"
    _debug_log("passives", 0,
        "forced Perilous Vessel native overload diagnostic", 0, "info")
    return true
end

-- ===========================================================================
-- Apply
-- ===========================================================================
--
-- Applies a passive to a bot's unit by calling
-- BuffExtension:add_internally_controlled_buff. Idempotent for
-- max_stacks=1 buffs (Fatshark's own _handle_unique_buffs check
-- prevents duplicates); we also track applied set per unit in the
-- pump for cheaper early-outs.
--
-- Returns (ok, err). ok=true means the buff was added OR was already
-- present. err is populated on real failures (no extension, unknown
-- template, unit not alive).

function M.apply_to_unit(unit, passive_id)
    local passive = _by_id[passive_id]
    if not passive then return false, "unknown passive: " .. tostring(passive_id) end

    return M.apply_template_to_unit(unit, passive.buff_template)
end

-- Fixed companion Legendaries are ordinary buff templates owned by the bot,
-- not by the human's Pilgrimage loadout. Keeping this path template-based lets
-- us assign both Fatshark Mortis buffs and Pilgrimage custom Legendaries while
-- leaving the player's primary and temporary Legendary slots untouched.
function M.apply_template_to_unit(unit, template_name)
    if type(template_name) ~= "string" or template_name == "" then
        return false, "invalid buff template"
    end

    local ScriptUnit = rawget(_G, "ScriptUnit")
    if not ScriptUnit or type(ScriptUnit.extension) ~= "function" then
        return false, "no ScriptUnit.extension"
    end

    local ok_alive, alive = pcall(function()
        local Unit = rawget(_G, "Unit")
        return Unit and Unit.alive and Unit.alive(unit)
    end)
    if not ok_alive or not alive then return false, "unit not alive" end

    local ok_ext, buff_ext = pcall(ScriptUnit.extension, unit, "buff_system")
    if not ok_ext or not buff_ext then return false, "no buff extension yet" end
    if type(buff_ext.add_internally_controlled_buff) ~= "function" then
        return false, "buff extension missing add_internally_controlled_buff"
    end

    local FixedFrame = rawget(_G, "FixedFrame")
    local t = (FixedFrame and FixedFrame.get_latest_fixed_time
        and FixedFrame.get_latest_fixed_time()) or 0

    local ok, err = pcall(buff_ext.add_internally_controlled_buff, buff_ext, template_name, t)
    if not ok then return false, "add threw: " .. tostring(err) end
    return true
end

-- ===========================================================================
-- Pump: apply preset-resolved passives to Pilgrimage bots
-- ===========================================================================
--
-- Called from the Tick scheduler at 0.5s intervals. Iterates every bot
-- player, resolves its preset's passives via resolve_for_preset, and
-- applies each one that isn't already applied. Tracked per (unit,
-- passive_id) so once a bot has its full set, subsequent ticks are
-- effectively no-op iterations of an empty pending set.
--
-- Reset by preset.reset_spawn_counter on StateLoading enter so each
-- fresh mission starts with an empty applied set.

local _applied = {}                        -- [unit] = { [passive_id] = true }
local _retry_count = {}                    -- [unit][passive_id] = int
local PASSIVE_MAX_RETRIES = 20

-- Most companions own one fixed Legendary through the original
-- fixed_legendary field. Exceptional Tier 3 identities may now own several;
-- keeping the plural field separate preserves every existing preset and save.
function M.fixed_legendaries_for_preset(preset)
    local out = {}
    local seen = {}

    local function add(template_name)
        if type(template_name) == "string" and template_name ~= ""
            and not seen[template_name] then
            seen[template_name] = true
            out[#out + 1] = template_name
        end
    end

    if type(preset) == "table" then
        add(preset.fixed_legendary)
        if type(preset.fixed_legendaries) == "table" then
            for i = 1, #preset.fixed_legendaries do
                add(preset.fixed_legendaries[i])
            end
        end
    end

    return out
end

function M.reset_pump_state()
    _applied = {}
    _retry_count = {}
end

function M.pump(preset_module)
    if type(preset_module) ~= "table" or type(preset_module.default_preset) ~= "function" then
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
        local unit = player.player_unit
        if unit then
            local profile
            if type(player.profile) == "function" then
                local ok_p, res_p = pcall(player.profile, player)
                if ok_p then profile = res_p end
            end
            profile = profile or player._profile

            local preset_id = type(profile) == "table" and profile._pilgrimage_preset
            local preset = preset_id and preset_module.get and preset_module.get(preset_id)

            if preset then
                local passive_ids = M.resolve_for_preset(preset)
                local fixed_legendaries = M.fixed_legendaries_for_preset(preset)
                if #passive_ids > 0 or #fixed_legendaries > 0 then
                    _applied[unit] = _applied[unit] or {}
                    _retry_count[unit] = _retry_count[unit] or {}
                    for i = 1, #passive_ids do
                        local pid = passive_ids[i]
                        if not _applied[unit][pid] then
                            local retries = _retry_count[unit][pid] or 0
                            if retries >= PASSIVE_MAX_RETRIES then
                                -- Give up; stop pumping this passive.
                                _applied[unit][pid] = true
                                _debug_log("passives", 0,
                                    "passive " .. pid .. " apply hit retry cap on a bot",
                                    0, "warn")
                            else
                                _retry_count[unit][pid] = retries + 1
                                local ok = M.apply_to_unit(unit, pid)
                                if ok then
                                    _applied[unit][pid] = true
                                end
                            end
                        end
                    end

                    for i = 1, #fixed_legendaries do
                        local fixed_legendary = fixed_legendaries[i]
                        local fixed_key = "fixed_legendary:" .. fixed_legendary
                        if not _applied[unit][fixed_key] then
                            local retries = _retry_count[unit][fixed_key] or 0
                            if retries >= PASSIVE_MAX_RETRIES then
                                _applied[unit][fixed_key] = true
                                _debug_log("passives", 0,
                                    "fixed Legendary " .. fixed_legendary
                                        .. " hit retry cap on a bot", 0, "warn")
                            else
                                _retry_count[unit][fixed_key] = retries + 1
                                local ok = M.apply_template_to_unit(unit, fixed_legendary)
                                if ok then _applied[unit][fixed_key] = true end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ===========================================================================

function M.status()
    local applied_count = 0
    for _, per_unit in pairs(_applied) do
        for _ in pairs(per_unit) do applied_count = applied_count + 1 end
    end
    return {
        catalogue_size    = #M.CATALOGUE,
        tiers             = M.TIER_PASSIVES,
        universal         = M.UNIVERSAL_PASSIVES,
        applied_count     = applied_count,
    }
end

-- ===========================================================================
-- v0.22.96: AURA ENGINE (the deferred batch, built from the roadmap
-- spec with all three APIs verified: PlayerUnitBuffExtension.
-- remove_externally_controlled_buff(local_index, component_index) at
-- line 338, Toughness.replenish_percentage, toughness percent reads).
-- Tick-driven (Pilgrimage.lua, 1s): each def names a source preset, a
-- target (player or the bot itself), an optional radius (coherency
-- approximated by distance), and a condition. Buffs are added via
-- add_externally_controlled_buff and removed with the captured
-- (index, component_index) pair the moment the condition fails.
-- ===========================================================================

local AURA_TEMPLATES = {
    { buff_template = "pilgrim_aura_standard",  custom = { stat_buffs = { damage = 0.1 } } },
    { buff_template = "pilgrim_aura_aegis",     custom = { stat_buffs = { damage_taken_multiplier = 0.8 } } },
    { buff_template = "pilgrim_aura_precept",   custom = { stat_buffs = { ranged_damage = 0.15 } } },
    { buff_template = "pilgrim_steady_blade",   custom = { stat_buffs = { toughness_regen_rate_modifier = 1.5 } } },
    { buff_template = "pilgrim_sleight_of_hand", custom = { stat_buffs = { critical_strike_chance = 0.3 } } },
    { buff_template = "pilgrim_silver_tongue_stack",
      custom = { stat_buffs = { movement_speed = 0.07 }, duration = 5 } },
    { buff_template = "pilgrim_serpents_reflex_dodge",
      custom = { keywords = { "count_as_dodge_vs_ranged" }, duration = 5 } },
    { buff_template = "pilgrim_dreyke_authority_aura",
      custom = { stat_buffs = {
          damage = 0.15,
          toughness_replenish_modifier = 0.20,
      } } },
    { buff_template = "pilgrim_cael_adaptive_rig_stack",
      custom = { template = function(BS)
          return {
              class_name = "buff",
              max_stacks = 10,
              max_stacks_cap = 10,
              predicted = false,
              duration = math.huge,
              stat_buffs = {
                  [BS.stat_buffs.damage] = 0.02,
                  [BS.stat_buffs.movement_speed] = 0.01,
                  [BS.stat_buffs.attack_speed] = 0.01,
              },
          }
      end } },
    { buff_template = "pilgrim_nex_killclade_mark",
      custom = { template = function(BS)
          return {
              class_name = "buff",
              max_stacks = 1,
              max_stacks_cap = 1,
              predicted = false,
              duration = 8,
              refresh_duration_on_stack = true,
              stat_buffs = {
                  [BS.stat_buffs.damage_taken_modifier] = 0.25,
              },
          }
      end } },
    { buff_template = "pilgrim_grudd_shaken",
      custom = { template = function(BS)
          return {
              class_name = "buff",
              max_stacks = 1,
              max_stacks_cap = 1,
              predicted = false,
              duration = 5,
              refresh_duration_on_stack = true,
              stat_buffs = {
                  [BS.stat_buffs.melee_attack_speed] = -0.20,
                  [BS.stat_buffs.minion_shoot_cooldown_modifier] = 1.25,
                  [BS.stat_buffs.damage_taken_modifier] = 0.15,
              },
          }
      end } },
    { buff_template = "pilgrim_solomorne_blood_warrant_target",
      custom = { template = function(BS)
          return {
              class_name = "buff",
              max_stacks = 1,
              max_stacks_cap = 1,
              predicted = false,
              duration = 10,
              refresh_duration_on_stack = true,
              stat_buffs = {
                  [BS.stat_buffs.damage_taken_from_bleeding] = 0.40,
              },
          }
      end } },
    { buff_template = "pilgrim_dorian_seizure_target",
      custom = { template = function(BS)
          return {
              class_name = "buff",
              max_stacks = 1,
              max_stacks_cap = 1,
              predicted = false,
              duration = 10,
              refresh_duration_on_stack = true,
              stat_buffs = {
                  [BS.stat_buffs.damage_taken_modifier] = 0.20,
              },
          }
      end } },
    { buff_template = "pilgrim_severin_command_window",
      custom = { stat_buffs = {
          ranged_damage = 0.20,
          reload_speed = 0.20,
      } } },
    { buff_template = "pilgrim_canis_apex_hunt",
      custom = { stat_buffs = {
          movement_speed = 0.30,
          attack_speed = 0.30,
      } } },
    { buff_template = "pilgrim_magleviathan_engine_charge",
      custom = { stat_buffs = {
          melee_power_level_modifier = 1.00,
          melee_impact_modifier = 1.00,
      } } },
    { buff_template = "pilgrim_lady_steel_foundry_brittleness",
      custom = { template = function(BS)
          return {
              class_name = "buff",
              max_stacks = 6,
              max_stacks_cap = 6,
              predicted = false,
              duration = 8,
              refresh_duration_on_stack = true,
              stat_buffs = {
                  [BS.stat_buffs.rending_multiplier] = 0.05,
              },
          }
      end } },
    { buff_template = "pilgrim_jocasta_rebuke_target",
      custom = { template = function(BS)
          return {
              class_name = "buff",
              max_stacks = 1,
              max_stacks_cap = 1,
              predicted = false,
              duration = 10,
              refresh_duration_on_stack = true,
              stat_buffs = {
                  [BS.stat_buffs.damage] = -0.25,
                  [BS.stat_buffs.damage_taken_modifier] = 0.25,
              },
          }
      end } },
    { buff_template = "pilgrim_epione_medicae_field_heal",
      custom = { template = function(BS)
          return {
              class_name = "interval_buff",
              interval = 1,
              max_stacks = 1,
              max_stacks_cap = 1,
              predicted = false,
              skip_tactical_overlay = true,
              start_func = function(template_data, template_context)
                  if not template_context.is_server then return end
                  template_data.health_extension = ScriptUnit.has_extension(
                      template_context.unit, "health_system")
              end,
              interval_func = function(template_data, template_context)
                  if not template_context.is_server then return end
                  local health = template_data.health_extension
                  if not health or type(health.max_health) ~= "function"
                      or type(health.add_heal) ~= "function" then return end
                  local ok_types, DamageSettings = pcall(require,
                      "scripts/settings/damage/damage_settings")
                  local heal_type = ok_types and DamageSettings.heal_types
                      and DamageSettings.heal_types.syringe or nil
                  pcall(health.add_heal, health, health:max_health() * 0.01,
                      heal_type)
              end,
          }
      end } },
}
for i = 1, #AURA_TEMPLATES do
    M.EXTERNAL_TEMPLATE_SOURCES[#M.EXTERNAL_TEMPLATE_SOURCES + 1] = { AURA_TEMPLATES[i] }
end

local AURA_RADIUS_SQ = 15 * 15

local function _toughness_percent(unit)
    local ok, ext = pcall(ScriptUnit.extension, unit, "toughness_system")
    if not ok or not ext then return nil end
    local ok2, pct = pcall(ext.current_toughness_percent, ext)
    return ok2 and pct or nil
end

local function _wielded_slot(unit)
    local ok, ud = pcall(ScriptUnit.extension, unit, "unit_data_system")
    if not ok or not ud then return nil end
    local ok2, inv = pcall(ud.read_component, ud, "inventory")
    return ok2 and inv and inv.wielded_slot or nil
end

local function _health_percent(unit)
    local ok, ext = pcall(ScriptUnit.extension, unit, "health_system")
    if not ok or not ext then return nil end
    local ok2, cur = pcall(ext.current_health_percent, ext)
    return ok2 and cur or nil
end

M.AURAS = {
    { id = "standard", preset = "theodora_von_valancius", target = "player",
      template = "pilgrim_aura_standard", radius = true,
      condition = function(bot, player_unit) return true end },
    { id = "aegis", preset = "seneschal_abelard", target = "player",
      template = "pilgrim_aura_aegis", radius = true,
      condition = function(bot, player_unit)
          local hp = _health_percent(player_unit)
          return hp ~= nil and hp < 0.5
      end },
    { id = "precept", preset = "seneschal_abelard", target = "player",
      template = "pilgrim_aura_precept", radius = true,
      -- v1 approximation of "when Abelard fires": his gun is out.
      condition = function(bot, player_unit)
          return _wielded_slot(bot) == "slot_secondary"
      end },
    { id = "steady_blade", preset = "seneschal_abelard", target = "self",
      template = "pilgrim_steady_blade",
      condition = function(bot) return (_toughness_percent(bot) or 0) > 0.7 end },
    { id = "sleight_of_hand", preset = "princess_jae", target = "self",
      template = "pilgrim_sleight_of_hand",
      condition = function(bot) return (_toughness_percent(bot) or 0) >= 1 end },
}

local _aura_state = {}

local function _bot_unit_for_preset(preset_id)
    local players = Managers.player and Managers.player:players()
    if not players then return nil end
    local want = "pilgrim_" .. preset_id
    for _, player in pairs(players) do
        local ok_h, is_human = pcall(player.is_human_controlled, player)
        if ok_h and not is_human and player.player_unit then
            local ok_p, profile = pcall(player.profile, player)
            if ok_p and profile and profile.character_id == want then
                return player.player_unit
            end
        end
    end
    return nil
end

local function _fixed_time()
    local FixedFrame = rawget(_G, "FixedFrame")
    if FixedFrame and type(FixedFrame.get_latest_fixed_time) == "function" then
        local ok, value = pcall(FixedFrame.get_latest_fixed_time)
        if ok and type(value) == "number" then return value end
    end
    return 0
end

local function _unit_has_buff(unit, template_name)
    if not unit or not ScriptUnit then return false end
    local extension = ScriptUnit.has_extension(unit, "buff_system")
    if not extension
        or type(extension.has_buff_using_buff_template) ~= "function" then
        return false
    end
    local ok, has = pcall(extension.has_buff_using_buff_template,
        extension, template_name)
    return ok and has == true
end

local function _apply_target_buff(target, template_name, owner, t)
    if not target or (HEALTH_ALIVE and not HEALTH_ALIVE[target]) then return false end
    local extension = ScriptUnit.has_extension(target, "buff_system")
    if not extension
        or type(extension.add_internally_controlled_buff) ~= "function" then
        return false
    end
    local ok = pcall(extension.add_internally_controlled_buff, extension,
        template_name, t, "owner_unit", owner)
    return ok
end

local function _replenish_warband_toughness(amount)
    local ok_toughness, Toughness = pcall(require,
        "scripts/utilities/toughness/toughness")
    local players = Managers.player and Managers.player:players()
    if not ok_toughness or not players then return end
    for _, player in pairs(players) do
        local unit = player and player.player_unit
        if unit and (not HEALTH_ALIVE or HEALTH_ALIVE[unit]) then
            pcall(Toughness.replenish_percentage, unit, amount, false, "buff")
        end
    end
end

local function _replenish_nearby_toughness(origin, radius, amount)
    local players = Managers.player and Managers.player:players()
    local ok_toughness, Toughness = pcall(require,
        "scripts/utilities/toughness/toughness")
    if not origin or not players or not ok_toughness then return end
    local radius_sq = radius * radius
    for _, player in pairs(players) do
        local unit = player and player.player_unit
        local position = unit and POSITION_LOOKUP[unit]
        if position and (not HEALTH_ALIVE or HEALTH_ALIVE[unit])
            and Vector3.distance_squared(origin, position) <= radius_sq then
            pcall(Toughness.replenish_percentage, unit, amount, false, "buff")
        end
    end
end

local function _breed_tags(unit)
    local unit_data = unit and ScriptUnit.has_extension(unit, "unit_data_system")
    local breed = unit_data and unit_data:breed()
    return breed and breed.tags, breed
end

local function _priority_enemy(unit)
    local tags = _breed_tags(unit)
    return tags and (tags.monster or tags.special or tags.elite) or false
end

local function _for_each_enemy(source, origin, radius, excluded, callback)
    local extension_manager = Managers.state and Managers.state.extension
    local side_system = extension_manager and extension_manager:system("side_system")
    local side = side_system and side_system.side_by_unit[source]
    local broadphase_system = extension_manager
        and extension_manager:system("broadphase_system")
    local broadphase = broadphase_system and broadphase_system.broadphase
    if not side or not broadphase or not origin then return end
    local results = {}
    local enemy_side_names = side:relation_side_names("enemy")
    local count = broadphase.query(broadphase, origin, radius, results,
        enemy_side_names)
    for i = 1, count do
        local unit = results[i]
        if unit ~= excluded and (not HEALTH_ALIVE or HEALTH_ALIVE[unit]) then
            callback(unit)
        end
    end
end

-- Reuse a shipped reflection profile name for companion splash damage. This is
-- the same network-safe pattern used by boons.lua and avoids adding another
-- damage_profile_templates key, the cause of an earlier barrel crash report.
local _companion_damage_dependencies
local function _deal_companion_secondary_damage(target, source, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 or not target or not source then return false end
    if not _companion_damage_dependencies then
        local ok_damage, Damage = pcall(require, "scripts/utilities/attack/damage")
        local ok_breed, Breed = pcall(require, "scripts/utilities/breed")
        local ok_attack, AttackSettings = pcall(require,
            "scripts/settings/damage/attack_settings")
        local ok_types, DamageSettings = pcall(require,
            "scripts/settings/damage/damage_settings")
        local ok_profiles, DamageProfiles = pcall(require,
            "scripts/settings/damage/damage_profile_templates")
        local base = ok_profiles
            and DamageProfiles.hordes_buff_damage_reflection_hit
        if not (ok_damage and ok_breed and ok_attack and ok_types
            and type(base) == "table") then return false end
        local profile = {}
        for key, value in pairs(base) do profile[key] = value end
        profile.name = "hordes_buff_damage_reflection_hit"
        profile.skip_on_hit_proc = true
        profile.ignore_toughness = true
        profile.unblockable = true
        _companion_damage_dependencies = {
            Damage = Damage,
            Breed = Breed,
            AttackSettings = AttackSettings,
            DamageSettings = DamageSettings,
            profile = profile,
        }
    end
    local deps = _companion_damage_dependencies
    local breed = deps.Breed.unit_breed_or_nil(target)
    local target_position = POSITION_LOOKUP[target]
    local source_position = POSITION_LOOKUP[source]
    if not breed or not target_position then return false end
    local direction = Vector3.up()
    if source_position
        and Vector3.distance_squared(target_position, source_position) > 0.001 then
        direction = Vector3.normalize(target_position - source_position)
    end
    local attack_results = deps.AttackSettings.attack_results
    local attack_types = deps.AttackSettings.attack_types
    local damage_types = deps.DamageSettings.damage_types
    return pcall(deps.Damage.deal_damage, target, breed, source, source,
        attack_results.damaged, attack_types.buff, deps.profile, amount, amount,
        0, nil, direction, "torso", nil, false,
        damage_types.buff, target_position, nil, false, 0)
end

local function _add_external_buff(unit, template_name, state, t)
    if state.index then return true end
    local extension = ScriptUnit.has_extension(unit, "buff_system")
    if not extension
        or type(extension.add_externally_controlled_buff) ~= "function" then
        return false
    end
    local ok, _, index, component_index = pcall(
        extension.add_externally_controlled_buff, extension, template_name, t)
    if ok and index then
        state.index = index
        state.component_index = component_index
        return true
    end
    return false
end

local function _remove_external_buff(unit, state)
    if not state or not state.index then return end
    local extension = ScriptUnit.has_extension(unit, "buff_system")
    if extension
        and type(extension.remove_externally_controlled_buff) == "function" then
        pcall(extension.remove_externally_controlled_buff, extension,
            state.index, state.component_index)
    end
    state.index = nil
    state.component_index = nil
end

local _killclade_marks = setmetatable({}, { __mode = "k" })
local _canis_state = setmetatable({}, { __mode = "k" })
local _magleviathan_state = setmetatable({}, { __mode = "k" })
local _lady_steel_state = setmetatable({}, { __mode = "k" })
local _severin_command_buffs = setmetatable({}, { __mode = "k" })
local _your_host_unit = nil
local _signature_attack_hook_installed = false

-- Nex and Grudd react to the final result of a normal Darktide attack. This
-- hook adds only target-side buffs, so armor, damage profiles, stagger and
-- death remain fully owned by the engine.
function M.install_signature_attack_hook()
    if _signature_attack_hook_installed or not _mod
        or type(_mod.hook) ~= "function" then return false end
    local ok_attack, Attack = pcall(require, "scripts/utilities/attack/attack")
    if not ok_attack or not Attack then return false end

    local function attack_arg(wanted, ...)
        local count = select("#", ...)
        local i = 1
        while i <= count do
            if select(i, ...) == wanted then return select(i + 1, ...) end
            i = i + 2
        end
        return nil
    end

    _mod:hook(Attack, "execute", function(func, attacked_unit, damage_profile, ...)
        local attacking_unit = attack_arg("attacking_unit", ...)
        local attack_type = attack_arg("attack_type", ...)
        local profile_name = damage_profile and damage_profile.name
        local t = _fixed_time()
        local nex_attack = attacking_unit
            and _unit_has_buff(attacking_unit,
                "pilgrim_nex_killclade_directive")
            and (profile_name == "chordclaw_main"
                or profile_name == "chordclaw_stab_bleed")
        if nex_attack and _apply_target_buff(attacked_unit,
                "pilgrim_nex_killclade_mark", attacking_unit, t) then
            _killclade_marks[attacked_unit] = t + 8
        end

        local toxin_before = false
        local encore_owner = _your_host_unit
        if not encore_owner and attacking_unit and _unit_has_buff(attacking_unit,
                "pilgrim_your_host_encore") then
            encore_owner = attacking_unit
        end
        if encore_owner and (not HEALTH_ALIVE or HEALTH_ALIVE[encore_owner]) then
            local target_buffs = ScriptUnit.has_extension(attacked_unit, "buff_system")
            if target_buffs and type(target_buffs.current_stacks) == "function" then
                local ok_stacks, stacks = pcall(target_buffs.current_stacks,
                    target_buffs, "neurotoxin_interval_buff3")
                toxin_before = ok_stacks and (tonumber(stacks) or 0) > 0
            end
        end

        local damage, attack_result, efficiency, stagger_result, weakspot =
            func(attacked_unit, damage_profile, ...)

        local dealt_damage = (tonumber(damage) or 0) > 0

        if dealt_damage and attacking_unit
            and _unit_has_buff(attacking_unit,
                "pilgrim_dorian_warrant_seizure")
            and _unit_has_buff(attacking_unit,
                "cryptic_grenade_ability_force_field_active") then
            _apply_target_buff(attacked_unit, "pilgrim_dorian_seizure_target",
                attacking_unit, t)
        end

        if attacking_unit and attack_type == "shout"
            and _unit_has_buff(attacking_unit,
                "pilgrim_jocasta_masters_rebuke") then
            _apply_target_buff(attacked_unit, "pilgrim_jocasta_rebuke_target",
                attacking_unit, t)
        end

        if dealt_damage and attacking_unit
            and _unit_has_buff(attacking_unit,
                "pilgrim_lady_steel_foundry_temper") then
            local state = _lady_steel_state[attacking_unit]
            if not state then
                state = { target = attacked_unit, hits = 0 }
                _lady_steel_state[attacking_unit] = state
            elseif state.target ~= attacked_unit then
                state.target = attacked_unit
                state.hits = 0
            end
            state.hits = state.hits + 1
            if state.hits % 3 == 0 then
                _apply_target_buff(attacked_unit,
                    "pilgrim_lady_steel_foundry_brittleness", attacking_unit, t)
            end
        end

        local engine = attacking_unit and _magleviathan_state[attacking_unit]
        if dealt_damage and attack_type == "melee" and engine and engine.charged then
            engine.charged = false
            engine.travel = 0
            engine.ready_at = t + 5
            _remove_external_buff(attacking_unit, engine)
            local origin = POSITION_LOOKUP[attacked_unit]
            if origin then
                _for_each_enemy(attacking_unit, origin, 5, attacked_unit,
                    function(unit)
                        _deal_companion_secondary_damage(unit, attacking_unit,
                            (tonumber(damage) or 0) * 0.50)
                    end)
            end
        end

        if attacking_unit and _unit_has_buff(attacking_unit,
                "pilgrim_canis_alpha_apex_pursuit") then
            local state = _canis_state[attacking_unit]
            if not state then
                state = {}
                _canis_state[attacking_unit] = state
            end
            if not state.quarry and _priority_enemy(attacked_unit) then
                state.quarry = attacked_unit
            end
        end

        for canis, state in pairs(_canis_state) do
            if state.quarry == attacked_unit and attack_result == "died" then
                state.quarry = nil
                _remove_external_buff(canis, state)
                _replenish_warband_toughness(0.10)
                local origin = POSITION_LOOKUP[attacked_unit]
                local ok_stagger, Stagger = pcall(require,
                    "scripts/utilities/attack/stagger")
                if origin and ok_stagger then
                    _for_each_enemy(canis, origin, 6, attacked_unit,
                        function(unit)
                            local position = POSITION_LOOKUP[unit]
                            local direction = Vector3.up()
                            if position and Vector3.distance_squared(
                                    position, origin) > 0.001 then
                                direction = Vector3.normalize(position - origin)
                            end
                            pcall(Stagger.force_stagger, unit, "explosion",
                                direction, 2, 1, 2, canis)
                        end)
                end
            end
        end

        if toxin_before and attack_result == "died" and encore_owner then
            local origin = POSITION_LOOKUP[attacked_unit]
            if origin then
                _for_each_enemy(encore_owner, origin, 4, attacked_unit,
                    function(unit)
                        local extension = ScriptUnit.has_extension(unit, "buff_system")
                        if extension then
                            for _ = 1, 4 do
                                pcall(extension.add_internally_controlled_buff,
                                    extension, "neurotoxin_interval_buff3", t,
                                    "owner_unit", encore_owner)
                            end
                        end
                    end)
            end
            local tags = _breed_tags(attacked_unit)
            if origin and tags and (tags.elite or tags.special) then
                _replenish_nearby_toughness(origin, 15, 0.10)
            end
        end

        if attack_result == "died"
            and (_killclade_marks[attacked_unit] or 0) >= t then
            _killclade_marks[attacked_unit] = nil
            _replenish_warband_toughness(0.10)
        end

        if stagger_result == "stagger" and attacking_unit
            and _unit_has_buff(attacking_unit,
                "pilgrim_grudd_kingpins_example") then
            _apply_target_buff(attacked_unit, "pilgrim_grudd_shaken",
                attacking_unit, t)
        end

        return damage, attack_result, efficiency, stagger_result, weakspot
    end)
    _signature_attack_hook_installed = true
    return true
end

local _dreyke_aura_state = setmetatable({}, { __mode = "k" })

local function _remove_dreyke_aura(unit)
    local state = _dreyke_aura_state[unit]
    _dreyke_aura_state[unit] = nil
    if not state then return end
    pcall(function()
        local extension = ScriptUnit.extension(unit, "buff_system")
        extension:remove_externally_controlled_buff(
            state.index, state.component_index)
    end)
end

local function _update_dreyke_aura()
    local dreyke = _bot_unit_for_preset("arbites_marshal")
    local players = Managers.player and Managers.player:players()
    local wanted = {}
    local dreyke_position = dreyke and POSITION_LOOKUP[dreyke]
    if dreyke and dreyke_position and players
        and (not HEALTH_ALIVE or HEALTH_ALIVE[dreyke]) then
        for _, player in pairs(players) do
            local unit = player and player.player_unit
            local position = unit and POSITION_LOOKUP[unit]
            if position and Vector3.distance_squared(
                    dreyke_position, position) <= AURA_RADIUS_SQ then
                wanted[unit] = true
                if not _dreyke_aura_state[unit] then
                    pcall(function()
                        local extension = ScriptUnit.extension(unit, "buff_system")
                        local _, index, component_index =
                            extension:add_externally_controlled_buff(
                                "pilgrim_dreyke_authority_aura", _fixed_time())
                        if index then
                            _dreyke_aura_state[unit] = {
                                index = index,
                                component_index = component_index,
                            }
                        end
                    end)
                end
            end
        end
    end
    for unit in pairs(_dreyke_aura_state) do
        if not wanted[unit] then _remove_dreyke_aura(unit) end
    end
end

local _omnispex_marks = setmetatable({}, { __mode = "k" })
local _omnispex_next_acquire_t = 0
local OMNISPEX_OUTLINE = "special_target"
local OMNISPEX_RADIUS_SQ = 30 * 30

local function _remove_omnispex_mark(unit)
    _omnispex_marks[unit] = nil
    pcall(function()
        local extension_manager = Managers.state.extension
        if extension_manager and extension_manager:has_system("outline_system") then
            extension_manager:system("outline_system"):remove_outline(
                unit, OMNISPEX_OUTLINE)
        end
    end)
end

local function _omnispex_priority(unit)
    local unit_data = ScriptUnit.has_extension(unit, "unit_data_system")
    local breed = unit_data and unit_data:breed()
    local tags = breed and breed.tags
    if not tags then return nil end
    if tags.monster then return 4 end
    if tags.special and breed.name
        and string.find(breed.name, "netgunner", 1, true) then return 3 end
    if tags.special then return 2 end
    if tags.elite then return 1 end
    return nil
end

local function _update_pasqal_omnispex()
    local t = _fixed_time()
    for unit, expires_at in pairs(_omnispex_marks) do
        if expires_at <= t or (HEALTH_ALIVE and not HEALTH_ALIVE[unit]) then
            _remove_omnispex_mark(unit)
        end
    end

    local pasqal = _bot_unit_for_preset("magos_haneumann")
    if not pasqal or (HEALTH_ALIVE and not HEALTH_ALIVE[pasqal]) then
        for unit in pairs(_omnispex_marks) do _remove_omnispex_mark(unit) end
        _omnispex_next_acquire_t = 0
        return
    end
    if t < _omnispex_next_acquire_t then return end

    local side_system = Managers.state.extension
        and Managers.state.extension:system("side_system")
    local side = side_system and side_system.side_by_unit[pasqal]
    local enemies = side and side.enemy_units_lookup
    local origin = POSITION_LOOKUP[pasqal]
    if not enemies or not origin then return end

    local candidates = {}
    for unit in pairs(enemies) do
        local position = POSITION_LOOKUP[unit]
        local priority = not _omnispex_marks[unit] and _omnispex_priority(unit)
        local distance = position and Vector3.distance_squared(origin, position)
        if priority and distance and distance <= OMNISPEX_RADIUS_SQ then
            candidates[#candidates + 1] = {
                unit = unit,
                priority = priority,
                distance = distance,
            }
        end
    end
    table.sort(candidates, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        return a.distance < b.distance
    end)
    local chosen = candidates[1] and candidates[1].unit
    if chosen then
        local ok = pcall(function()
            Managers.state.extension:system("outline_system"):add_outline(
                chosen, OMNISPEX_OUTLINE)
        end)
        if ok then
            _omnispex_marks[chosen] = t + 10
            _omnispex_next_acquire_t = t + 2
        end
    end
end

local function _remove_aura(key)
    local st = _aura_state[key]
    _aura_state[key] = nil
    if not st then return end
    pcall(function()
        local ext = ScriptUnit.extension(st.unit, "buff_system")
        ext:remove_externally_controlled_buff(st.index, st.component_index)
    end)
end

local function _update_companion_signatures()
    local t = _fixed_time()

    _your_host_unit = _bot_unit_for_preset("your_host")

    local severin = _bot_unit_for_preset("tempestor_prime")
    for unit, buff_state in pairs(_severin_command_buffs) do
        local runtime = M._companion_runtime.severin[unit]
        local wanted = unit == severin and runtime
            and (runtime.active_until or 0) > t
            and (not HEALTH_ALIVE or HEALTH_ALIVE[unit])
        if not wanted then
            _remove_external_buff(unit, buff_state)
            _severin_command_buffs[unit] = nil
        end
    end
    if severin then
        local runtime = M._companion_runtime.severin[severin]
        if runtime and (runtime.active_until or 0) > t then
            local buff_state = _severin_command_buffs[severin]
            if not buff_state then
                buff_state = {}
                _severin_command_buffs[severin] = buff_state
            end
            _add_external_buff(severin, "pilgrim_severin_command_window",
                buff_state, t)
        end
    end

    local canis = _bot_unit_for_preset("mechanicus_warhound_alpha")
    for unit, state in pairs(_canis_state) do
        if unit ~= canis or (HEALTH_ALIVE and not HEALTH_ALIVE[unit]) then
            _remove_external_buff(unit, state)
            _canis_state[unit] = nil
        elseif state.quarry and HEALTH_ALIVE and not HEALTH_ALIVE[state.quarry] then
            state.quarry = nil
            _remove_external_buff(unit, state)
        end
    end
    if canis then
        local state = _canis_state[canis]
        if state and state.quarry
            and (not HEALTH_ALIVE or HEALTH_ALIVE[state.quarry]) then
            _add_external_buff(canis, "pilgrim_canis_apex_hunt", state, t)
        end
    end

    local magleviathan = _bot_unit_for_preset("lord_magleviathan")
    for unit, state in pairs(_magleviathan_state) do
        if unit ~= magleviathan or (HEALTH_ALIVE and not HEALTH_ALIVE[unit]) then
            _remove_external_buff(unit, state)
            _magleviathan_state[unit] = nil
        end
    end
    if magleviathan then
        local position = POSITION_LOOKUP[magleviathan]
        local state = _magleviathan_state[magleviathan]
        if not state then
            state = { travel = 0, ready_at = 0, last_position = position }
            _magleviathan_state[magleviathan] = state
        elseif position and state.last_position and not state.charged then
            local distance = Vector3.distance(position, state.last_position)
            -- Ignore spawn/teleport jumps, but count ordinary sprinting and
            -- combat movement exactly once per updater sample.
            if distance <= 20 then state.travel = state.travel + distance end
        end
        state.last_position = position
        if not state.charged and state.travel >= 4 and t >= (state.ready_at or 0) then
            state.charged = _add_external_buff(magleviathan,
                "pilgrim_magleviathan_engine_charge", state, t)
        end
    end
end

function M.update_auras()
    local player = Managers.player and Managers.player:local_player_safe(1)
    local player_unit = player and player.player_unit
    for i = 1, #M.AURAS do
        local def = M.AURAS[i]
        local bot = _bot_unit_for_preset(def.preset)
        local target = def.target == "self" and bot or player_unit
        local want = false
        if bot and target and rawget(_G, "HEALTH_ALIVE") and HEALTH_ALIVE[bot] then
            local ok_c, cond = pcall(def.condition, bot, player_unit)
            want = ok_c and cond or false
            if want and def.radius and player_unit and def.target == "player" then
                local ok_d, in_range = pcall(function()
                    local a = POSITION_LOOKUP[bot]
                    local b = POSITION_LOOKUP[player_unit]
                    return a and b and Vector3.distance_squared(a, b) <= AURA_RADIUS_SQ
                end)
                want = ok_d and in_range or false
            end
        end
        local st = _aura_state[def.id]
        if want and (not st or st.unit ~= target) then
            if st then _remove_aura(def.id) end
            pcall(function()
                local ext = ScriptUnit.extension(target, "buff_system")
                local FixedFrame = rawget(_G, "FixedFrame")
                local ft = FixedFrame and FixedFrame.get_latest_fixed_time() or 0
                local _, index, component_index = ext:add_externally_controlled_buff(def.template, ft)
                if index then
                    _aura_state[def.id] = { unit = target, index = index, component_index = component_index }
                end
            end)
        elseif not want and st then
            _remove_aura(def.id)
        end
    end
    _update_dreyke_aura()
    _update_pasqal_omnispex()
    _update_companion_signatures()
end

function M.reset_auras()
    for key in pairs(_aura_state) do _remove_aura(key) end
    for unit in pairs(_dreyke_aura_state) do _remove_dreyke_aura(unit) end
    for unit in pairs(_omnispex_marks) do _remove_omnispex_mark(unit) end
    _omnispex_next_acquire_t = 0
    _killclade_marks = setmetatable({}, { __mode = "k" })
    for unit, state in pairs(_canis_state) do _remove_external_buff(unit, state) end
    for unit, state in pairs(_magleviathan_state) do
        _remove_external_buff(unit, state)
    end
    for unit, state in pairs(_severin_command_buffs) do
        _remove_external_buff(unit, state)
    end
    _canis_state = setmetatable({}, { __mode = "k" })
    _magleviathan_state = setmetatable({}, { __mode = "k" })
    _lady_steel_state = setmetatable({}, { __mode = "k" })
    _severin_command_buffs = setmetatable({}, { __mode = "k" })
    _your_host_unit = nil
    M._companion_runtime.severin = setmetatable({}, { __mode = "k" })
end

function M.init(deps)
    _mod       = deps.mod
    _shared    = deps.shared
    _debug_log = deps.debug_log or function() end
    M.install_templates()
    M.install_idira_overload_hook()
    M.install_signature_attack_hook()
end

return M
