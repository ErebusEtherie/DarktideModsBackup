-- File: RingHud/scripts/mods/RingHud/RingHud_data.lua

local mod = get_mod("RingHud")
if not mod then return end

-- Use Ring HUD's own palette (not the game's global color list)
mod:io_dofile("RingHud/scripts/mods/RingHud/systems/RingHud_colors")

-- Helper: only include flat ARGB255 tuples (four numbers), skip compound tables like color spectrums.
local function _is_argb255_tuple(t)
    return type(t) == "table"
        and type(t[1]) == "number"
        and type(t[2]) == "number"
        and type(t[3]) == "number"
        and type(t[4]) == "number"
end

-- Build dropdown options from the mod palette.
-- Each option's `text` is a localization key equal to the palette key.
-- The localization file will return a colored label for each of these keys.
local function _palette_options()
    local opts, i = {}, 1
    for name, v in pairs(mod.PALETTE_ARGB255 or {}) do
        if _is_argb255_tuple(v) then
            opts[i] = { value = name, text = name }
            i = i + 1
        end
        -- compound entries (e.g., *_spectrum) are intentionally skipped
    end
    table.sort(opts, function(a, b) return a.text < b.text end)
    return opts
end

--========================
-- Options schema
--========================
local DATA = {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,

    options = {
        widgets = {
            {
                setting_id      = "show_all_hud_hotkey",
                type            = "keybind",
                default_value   = {},
                tooltip         = "show_all_hud_hotkey_tooltip",
                keybind_trigger = "held",
                keybind_type    = "function_call",
                function_name   = "handle_show_all_hud_hotkey_state",
            },
            {
                setting_id      = "trigger_detection_range",
                type            = "numeric",
                default_value   = 15,
                range           = { 5, 25 },
                decimals_number = 0,
                tooltip         = "trigger_detection_tooltip",
            },
            {
                setting_id    = "team_hud_mode",
                type          = "dropdown",
                default_value = "team_hud_docked",
                tooltip       = "team_hud_mode_tooltip",
                options       = {
                    { text = "team_hud_disabled",         value = "team_hud_disabled" },
                    { text = "team_hud_docked",           value = "team_hud_docked" },
                    { text = "team_hud_floating",         value = "team_hud_floating" },
                    { text = "team_hud_floating_docked",  value = "team_hud_floating_docked" },
                    { text = "team_hud_floating_vanilla", value = "team_hud_floating_vanilla" },
                    { text = "team_hud_floating_thin",    value = "team_hud_floating_thin" },
                },
            },

            ------------------------------------------------------------------
            -- Layout
            ------------------------------------------------------------------
            {
                setting_id  = "layout_supergroup",
                type        = "group",
                sub_widgets = {
                    {
                        setting_id  = "position_settings",
                        type        = "group",
                        sub_widgets = {
                            {
                                setting_id    = "crosshair_shake_dropdown",
                                type          = "dropdown",
                                default_value = "crosshair_shake_always",
                                tooltip       = "crosshair_shake_dropdown_tooltip",
                                options       = {
                                    { text = "crosshair_shake_always",   value = "crosshair_shake_always" },
                                    { text = "crosshair_shake_ads",      value = "crosshair_shake_ads" },
                                    { text = "crosshair_shake_disabled", value = "crosshair_shake_disabled" },
                                },
                            },
                            {
                                setting_id      = "player_hud_offset_x",
                                type            = "numeric",
                                default_value   = 0,
                                range           = { -1400, 1400 },
                                decimals_number = 0,
                                tooltip         = "player_hud_offset_x_tooltip",
                            },
                            {
                                setting_id      = "player_hud_offset_y",
                                type            = "numeric",
                                default_value   = 0,
                                range           = { -1000, 1000 },
                                decimals_number = 0,
                                tooltip         = "player_hud_offset_y_tooltip",
                            },
                        }
                    },
                    {
                        setting_id  = "layout_settings",
                        type        = "group",
                        sub_widgets = {
                            {
                                setting_id      = "ring_scale",
                                type            = "numeric",
                                default_value   = 1.0,
                                range           = { 0.5, 2.0 },
                                decimals_number = 1,
                                tooltip         = "ring_scale_tooltip",
                            },
                            {
                                setting_id    = "ring_offset_bias",
                                type          = "numeric",
                                default_value = 0,
                                range         = { 0, 200 },
                                tooltip       = "ring_offset_bias_tooltip",
                            },
                            {
                                setting_id    = "scanner_offset_bias_override",
                                type          = "numeric",
                                default_value = 0,
                                range         = { 0, 200 },
                                tooltip       = "scanner_offset_bias_override_tooltip",
                            },
                        },
                    },

                    ------------------------------------------------------------------
                    -- ADS behaviour
                    ------------------------------------------------------------------
                    {
                        setting_id  = "ads_settings",
                        type        = "group",
                        sub_widgets = {
                            {
                                setting_id    = "ads_visibility_dropdown",
                                type          = "dropdown",
                                default_value = "ads_vis_normal",
                                tooltip       = "ads_visibility_dropdown_tooltip",
                                options       = {
                                    { text = "ads_vis_normal",           value = "ads_vis_normal" },
                                    { text = "ads_vis_hide_in_ads",      value = "ads_vis_hide_in_ads" },
                                    { text = "ads_vis_hide_outside_ads", value = "ads_vis_hide_outside_ads" },
                                    { text = "ads_vis_hotkey",           value = "ads_vis_hotkey" },
                                },
                            },
                            {
                                setting_id      = "ads_scale_override",
                                type            = "numeric",
                                default_value   = 1.0,
                                range           = { 0.5, 2.0 },
                                decimals_number = 1,
                                tooltip         = "ads_scale_override_tooltip",
                            },
                            {
                                setting_id    = "ads_offset_bias_override",
                                type          = "numeric",
                                default_value = 0,
                                range         = { 0, 200 },
                                tooltip       = "ads_offset_bias_override_tooltip",
                            },
                        }
                    },
                },
            },
            {
                setting_id  = "combat_supergroup",
                type        = "group",
                sub_widgets = {
                    ------------------------------------------------------------------
                    -- Survival
                    ------------------------------------------------------------------
                    {
                        setting_id  = "survival_settings",
                        type        = "group",
                        sub_widgets = {
                            {
                                setting_id    = "toughness_bar_dropdown",
                                type          = "dropdown",
                                default_value = "toughness_bar_auto_hp",
                                tooltip       = "toughness_bar_dropdown_tooltip",
                                options       = {
                                    { text = "toughness_bar_auto_hp_text",   value = "toughness_bar_auto_hp_text" },
                                    { text = "toughness_bar_auto_hp",        value = "toughness_bar_auto_hp" },
                                    { text = "toughness_bar_always_hp_text", value = "toughness_bar_always_hp_text" },
                                    { text = "toughness_bar_always_hp",      value = "toughness_bar_always_hp" },
                                    { text = "toughness_bar_always",         value = "toughness_bar_always" },
                                    { text = "toughness_bar_disabled",       value = "toughness_bar_disabled" },
                                }
                            },
                            {
                                setting_id      = "stamina_viz_threshold",
                                type            = "numeric",
                                default_value   = 0.25,
                                range           = { -0.01, 1.00 },
                                decimals_number = 2,
                                tooltip         = "stamina_viz_tooltip",
                            },
                            {
                                setting_id    = "dodge_viz_threshold",
                                type          = "numeric",
                                default_value = 1,
                                range         = { -1, 8 },
                                tooltip       = "dodge_viz_tooltip",
                            },
                        }
                    },

                    ------------------------------------------------------------------
                    -- Ability Timers
                    ------------------------------------------------------------------
                    {
                        setting_id  = "timer_settings",
                        type        = "group",
                        sub_widgets = {
                            {
                                setting_id    = "timer_cd_dropdown",
                                type          = "dropdown",
                                default_value = "single",
                                tooltip       = "timer_cd_dropdown_tooltip",
                                options       = {
                                    { text = "timer_cd_disabled",       value = "disabled" },
                                    { text = "timer_cd_single",         value = "single" },
                                    { text = "timer_cd_pips_single",    value = "pips_single" },
                                    { text = "timer_cd_count_single",   value = "count_single" },
                                    { text = "timer_cd_single_colored", value = "single_colored" },
                                },
                            },
                            {
                                setting_id    = "timer_buff_enabled",
                                type          = "checkbox",
                                default_value = true,
                                tooltip       = "timer_buff_tooltip",
                            },
                            {
                                setting_id    = "timer_sound_enabled",
                                type          = "dropdown",
                                default_value = "zealot", -- zealot bolstering prayer is the default
                                tooltip       = "timer_sound_tooltip",
                                options       = {
                                    { text = "timer_sound_default",      value = "default" },   -- vanilla Darktide ability-ready sound
                                    { text = "timer_sound_zealot",       value = "zealot" },    -- zealot bolstering prayer
                                    { text = "timer_sound_blunt_shield", value = "shield" },    -- blunt shield sound
                                    { text = "timer_sound_item_tier3",   value = "item_tier3" } -- emperor's gift
                                },
                            },
                        }
                    },
                },
            },
            {
                setting_id  = "casting_supergroup",
                type        = "group",
                sub_widgets = {
                    ------------------------------------------------------------------
                    -- Peril
                    ------------------------------------------------------------------
                    {
                        setting_id  = "peril_settings",
                        type        = "group",
                        sub_widgets = {
                            {
                                setting_id    = "peril_bar_dropdown",
                                type          = "dropdown",
                                default_value = "peril_lightning_enabled",
                                tooltip       = "peril_tooltip",
                                options       = {
                                    { text = "peril_lightning_enabled", value = "peril_lightning_enabled" },
                                    { text = "peril_bar_enabled",       value = "peril_bar_enabled" },
                                    { text = "peril_bar_disabled",      value = "peril_bar_disabled" },
                                }
                            },
                            {
                                setting_id    = "peril_label_enabled",
                                type          = "checkbox",
                                default_value = true,
                                tooltip       = "peril_label_enabled_tooltip",
                            },
                            {
                                setting_id    = "peril_crosshair_enabled",
                                type          = "checkbox",
                                default_value = false,
                                tooltip       = "peril_crosshair_tooltip",
                            },
                        }
                    },

                    ------------------------------------------------------------------
                    -- Charge
                    ------------------------------------------------------------------
                    {
                        setting_id  = "charge_settings",
                        type        = "group",
                        sub_widgets = {
                            {
                                setting_id    = "charge_perilous_enabled",
                                type          = "checkbox",
                                default_value = true,
                            },
                            {
                                setting_id    = "charge_kills_enabled",
                                type          = "checkbox",
                                default_value = true,
                            },
                            {
                                setting_id    = "charge_other_enabled",
                                type          = "checkbox",
                                default_value = true,
                            },
                        }
                    },
                },
            },
            {
                setting_id  = "supplies_supergroup",
                type        = "group",
                sub_widgets = {
                    ------------------------------------------------------------------
                    -- Munitions
                    ------------------------------------------------------------------
                    {
                        setting_id  = "munitions_settings",
                        type        = "group",
                        sub_widgets = {
                            {
                                setting_id    = "ammo_clip_dropdown",
                                type          = "dropdown",
                                default_value = "ammo_clip_bar",
                                tooltip       = "ammo_clip_dropdown_tooltip",
                                options       = {
                                    { text = "ammo_clip_bar_text", value = "ammo_clip_bar_text" },
                                    { text = "ammo_clip_bar",      value = "ammo_clip_bar" },
                                    { text = "ammo_clip_text",     value = "ammo_clip_text" },
                                    { text = "ammo_clip_disabled", value = "ammo_clip_disabled" },
                                },
                            },
                            {
                                setting_id    = "ammo_reserve_dropdown",
                                type          = "dropdown",
                                default_value = "ammo_reserve_percent_auto",
                                tooltip       = "ammo_reserve_dropdown_tooltip",
                                options       = {
                                    { text = "ammo_reserve_percent_auto",   value = "ammo_reserve_percent_auto" },
                                    { text = "ammo_reserve_actual_auto",    value = "ammo_reserve_actual_auto" },
                                    { text = "ammo_reserve_percent_always", value = "ammo_reserve_percent_always" },
                                    { text = "ammo_reserve_actual_always",  value = "ammo_reserve_actual_always" },
                                    { text = "ammo_reserve_disabled",       value = "ammo_reserve_disabled" },
                                },
                            },
                            {
                                setting_id    = "grenade_bar_dropdown",
                                type          = "dropdown",
                                default_value = "grenade_hide_full_compact",
                                tooltip       = "grenade_bar_dropdown_tooltip",
                                options       = {
                                    { text = "grenade_hide_full_compact",  value = "grenade_hide_full_compact" },
                                    { text = "grenade_hide_full",          value = "grenade_hide_full" },
                                    { text = "grenade_hide_empty_compact", value = "grenade_hide_empty_compact" },
                                    { text = "grenade_hide_empty",         value = "grenade_hide_empty" },
                                    { text = "grenade_disabled",           value = "grenade_disabled" },
                                },
                            },
                        }
                    },

                    ------------------------------------------------------------------
                    -- Pocketables (uses Ring HUD palette + colored localization)
                    ------------------------------------------------------------------
                    {
                        setting_id  = "pocketable_settings",
                        type        = "group",
                        tooltip     = "pocketable_settings_tooltip",
                        sub_widgets = {
                            {
                                setting_id    = "pocketable_visibility_dropdown",
                                type          = "dropdown",
                                default_value = "pocketable_contextual",
                                tooltip       = "pocketable_visibility_dropdown_tooltip",
                                options       = {
                                    { text = "pocketable_contextual", value = "pocketable_contextual" },
                                    { text = "pocketable_always",     value = "pocketable_always" },
                                    { text = "pocketable_disabled",   value = "pocketable_disabled" },
                                }
                            },
                            {
                                setting_id    = "medical_crate_color",
                                type          = "dropdown",
                                default_value = "HEALTH_GREEN",
                                tooltip       = "medical_crate_color_tooltip",
                                options       = _palette_options(),
                            },
                            {
                                setting_id    = "ammo_cache_color",
                                type          = "dropdown",
                                default_value = "SPEED_BLUE",
                                tooltip       = "ammo_cache_color_tooltip",
                                options       = _palette_options(),
                            },
                        }
                    },
                },
            },
            {
                setting_id  = "team_supergroup",
                type        = "group",
                sub_widgets = {
                    ------------------------------------------------------------------
                    -- Team HUD
                    ------------------------------------------------------------------
                    {
                        setting_id  = "team_docked_position",
                        type        = "group",
                        tooltip     = "team_docked_position_tooltip",
                        sub_widgets = {
                            {
                                setting_id    = "team_docked_axis",
                                type          = "dropdown",
                                default_value = "vertical",
                                tooltip       = "team_docked_axis_tooltip",
                                options       = {
                                    { text = "team_docked_axis_vertical",   value = "vertical" },
                                    { text = "team_docked_axis_horizontal", value = "horizontal" },
                                },
                            },
                            {
                                setting_id      = "team_hud_offset_x",
                                type            = "numeric",
                                default_value   = 0,
                                range           = { -800, 800 },
                                decimals_number = 0,
                                tooltip         = "team_hud_offset_x_tooltip",
                            },
                            {
                                setting_id      = "team_hud_offset_y",
                                type            = "numeric",
                                default_value   = 0,
                                range           = { -800, 800 },
                                decimals_number = 0,
                                tooltip         = "team_hud_offset_y_tooltip",
                            },
                        },
                    },
                    {
                        setting_id  = "team_hud_settings",
                        type        = "group",
                        tooltip     = "team_hud_settings_tooltip",
                        sub_widgets = {
                            {
                                setting_id      = "team_tiles_scale",
                                type            = "numeric",
                                default_value   = 1.0,
                                range           = { 0.5, 2.0 },
                                decimals_number = 1,
                                tooltip         = "team_tiles_scale_tooltip",
                            },
                            {
                                setting_id    = "team_hp_bar",
                                type          = "dropdown",
                                default_value = "team_hp_bar_context_text_off",
                                tooltip       = "team_hp_bar_tooltip",
                                options       = {
                                    { text = "team_hp_disabled",                 value = "team_hp_disabled" },
                                    { text = "team_hp_bar_always_text_off",      value = "team_hp_bar_always_text_off" },
                                    { text = "team_hp_bar_always_text_context",  value = "team_hp_bar_always_text_context" },
                                    { text = "team_hp_bar_context_text_off",     value = "team_hp_bar_context_text_off" },
                                    { text = "team_hp_bar_context_text_context", value = "team_hp_bar_context_text_context" },
                                },
                            },
                            {
                                setting_id    = "team_name_icon",
                                type          = "dropdown",
                                default_value = "name1_icon1_status1",
                                tooltip       = "team_name_icon_tooltip",
                                options       = {
                                    { text = "name0_icon1_status1", value = "name0_icon1_status1" }, -- nameplate no name, archetype icon big, status icons special
                                    { text = "name0_icon1_status0", value = "name0_icon1_status0" }, -- nameplate no name, archetype icon big, status icons DT default
                                    { text = "name0_icon0_status1", value = "name0_icon0_status1" }, -- nameplate no name, archetype icon in name, status icons special
                                    { text = "name0_icon0_status0", value = "name0_icon0_status0" }, -- nameplate no name, archetype icon in name, status icons DT default
                                    { text = "name1_icon1_status1", value = "name1_icon1_status1" }, -- nameplate shortname, archetype icon big, status icons special
                                    { text = "name1_icon1_status0", value = "name1_icon1_status0" }, -- nameplate shortname, archetype icon big, status icons DT default
                                    { text = "name1_icon0_status1", value = "name1_icon0_status1" }, -- nameplate shortname, archetype icon in name, status icons special
                                    { text = "name1_icon0_status0", value = "name1_icon0_status0" }, -- nameplate shortname, archetype icon in name, status icons DT default
                                },
                            },
                        },
                    },
                    ------------------------------------------------------------------
                    -- Team HUD Detail
                    ------------------------------------------------------------------
                    {
                        setting_id  = "team_hud_detail",
                        type        = "group",
                        tooltip     = "team_hud_detail_tooltip",
                        sub_widgets = {
                            {
                                setting_id    = "team_munitions",
                                type          = "dropdown",
                                default_value = "team_munitions_ammo_context_cd_enabled",
                                tooltip       = "team_munitions_tooltip",
                                options       = {
                                    { text = "team_munitions_disabled",                 value = "team_munitions_disabled" },
                                    { text = "team_munitions_ammo_context_cd_disabled", value = "team_munitions_ammo_context_cd_disabled" },
                                    { text = "team_munitions_ammo_always_cd_enabled",   value = "team_munitions_ammo_always_cd_enabled" },
                                    { text = "team_munitions_ammo_context_cd_enabled",  value = "team_munitions_ammo_context_cd_enabled" },
                                    { text = "team_munitions_ammo_always_cd_always",    value = "team_munitions_ammo_always_cd_always" },
                                },
                            },
                            {
                                setting_id    = "team_pockets",
                                type          = "dropdown",
                                default_value = "team_pockets_context",
                                tooltip       = "team_pockets_tooltip",
                                options       = {
                                    { text = "team_pockets_disabled", value = "team_pockets_disabled" },
                                    { text = "team_pockets_always",   value = "team_pockets_always" },
                                    { text = "team_pockets_context",  value = "team_pockets_context" },
                                },
                            },
                        },
                    },
                },
            },
            {
                setting_id  = "vanilla_supergroup",
                type        = "group",
                sub_widgets = {
                    ------------------------------------------------------------------
                    -- Vanilla HUD Visibility
                    ------------------------------------------------------------------
                    {
                        setting_id  = "default_hud_visibility_settings",
                        type        = "group",
                        tooltip     = "default_hud_visibility_settings_tooltip",
                        sub_widgets = {
                            { setting_id = "hide_default_ability", type = "checkbox", default_value = false, tooltip = "hide_default_ability_tooltip" },
                            { setting_id = "hide_default_weapons", type = "checkbox", default_value = false, tooltip = "hide_default_weapons_tooltip" },
                            { setting_id = "hide_default_player",  type = "checkbox", default_value = false, tooltip = "hide_default_player_tooltip" },
                        }
                    },

                    -- ─────────────────────────────────────────────────────────────────
                    -- UI Integration (bottom-most)
                    -- ─────────────────────────────────────────────────────────────────
                    {
                        setting_id  = "ui_integration_settings",
                        type        = "group",
                        tooltip     = "ui_integration_settings_tooltip",
                        sub_widgets = {
                            {
                                setting_id    = "minimal_objective_feed_enabled",
                                type          = "checkbox",
                                default_value = true,
                                tooltip       = "minimal_objective_feed_enabled_tooltip",
                            },
                        },
                    },
                },
            },
        },
    },
}

return DATA
