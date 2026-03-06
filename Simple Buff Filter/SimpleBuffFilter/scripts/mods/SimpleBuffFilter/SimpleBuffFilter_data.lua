-- File: scripts/mods/SimpleBuffFilter/SimpleBuffFilter_data.lua
local mod = get_mod("SimpleBuffFilter")
if not mod then
    return {
        name = "SimpleBuffFilter",
        description = "Missing mod instance",
        is_togglable = true,
        options = { widgets = {} },
    }
end

-- Make sure option builders exist even if DMF loads this file first
mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/core/options_builders")

-- Init archetypes & ordering
local Resolve = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/resolve")
Resolve.init_archetypes()

-- For glyphs/colors on group headers + rule tinting
local UiSettings = require("scripts/settings/ui/ui_settings")
local Colors     = mod:io_dofile("SimpleBuffFilter/scripts/mods/SimpleBuffFilter/util/colors")

-- ---- Rule option lists (pre-tinted) ---------------------------------------
-- Simplified set: Allow, Hide, Only in Psykhanium
local function _rule_options()
    local function tint(lbl, val)
        return { text = Colors.tint_rule(lbl, val), value = val, localize = false }
    end
    return {
        tint(" " .. Localize("loc_settings_menu_group_display"), "allow"),
        tint(" " .. Localize("loc_social_menu_player_blocked"), "hide"),
        tint(" " .. Localize("loc_training_grounds_view_intro_title"), "only_in_psykhanium"),
    }
end

-- Same subset for weapon traits/misc (identical now, kept for consistency)
local function _weapon_rule_options()
    local function tint(lbl, val)
        return { text = Colors.tint_rule(lbl, val), value = val, localize = false }
    end
    return {
        tint(" " .. Localize("loc_settings_menu_group_display"), "allow"),
        tint(" " .. Localize("loc_social_menu_player_blocked"), "hide"),
        tint(" " .. Localize("loc_training_grounds_view_intro_title"), "only_in_psykhanium"),
    }
end

-- Builders (items are pre-colored upstream by core/options_builders)
local function _get_talent_options_for(archetype)
    return mod.get_talent_options_for and mod.get_talent_options_for(archetype) or {
        {
            title = Localize("loc_group_finder_slot_tag_button_default_value"),
            text = Localize("loc_group_finder_slot_tag_button_default_value"),
            value = "",
            localize = false
        },
        {
            title = Localize("loc_enginseer_a__event_scan_more_data_01"),
            text = Localize("loc_enginseer_a__event_scan_more_data_01"),
            value = "__collect__",
            localize = false
        },
    }
end

local function _get_weapon_trait_options(category)
    return mod.get_weapon_trait_options and mod.get_weapon_trait_options(category) or {
        {
            title = Localize("loc_group_finder_slot_tag_button_default_value"),
            text = Localize("loc_group_finder_slot_tag_button_default_value"),
            value = "",
            localize = false
        },
        {
            title = Localize("loc_enginseer_a__event_scan_more_data_01"),
            text = Localize("loc_enginseer_a__event_scan_more_data_01"),
            value = "__collect__",
            localize = false
        },
    }
end

local function _get_misc_buff_options()
    return mod.get_misc_buff_options and mod.get_misc_buff_options() or {
        {
            title = Localize("loc_group_finder_slot_tag_button_default_value"),
            text = Localize("loc_group_finder_slot_tag_button_default_value"),
            value = "",
            localize = false
        },
        {
            title = Localize("loc_enginseer_a__event_scan_more_data_01"),
            text = Localize("loc_enginseer_a__event_scan_more_data_01"),
            value = "__collect__",
            localize = false
        },
    }
end

-- Build wipe target dropdown options
local function _wipe_target_options()
    local opts = { { text = Localize("loc_talent_menu_action_clear_all_points"), value = "__all__" } }

    -- Per-archetype
    for _, archetype in ipairs(Resolve.sorted_archetypes()) do
        local keys = Resolve.archetype_loc_keys(archetype)
        local name = (keys and keys.name_loc) and Localize(keys.name_loc) or archetype
        opts[#opts + 1] = { text = name, value = archetype, localize = false }
    end

    -- Weapon trait groups (game loc; pre-resolve)
    opts[#opts + 1] = {
        text = Localize("loc_glossary_term_melee_weapons"),
        value = "__traits_melee__",
        localize = false
    }
    opts[#opts + 1] = {
        text = Localize("loc_glossary_term_ranged_weapons"),
        value = "__traits_ranged__",
        localize = false
    }

    -- "Misc Buffs" (game loc; pre-resolve)
    opts[#opts + 1] = {
        text = Localize("loc_settings_menu_group_other_settings"),
        value = "__misc__",
        localize = false
    }

    return opts
end

local widgets = {}

-- One grouped section per base archetype (sorted by ui_selection_order)
for _, archetype in ipairs(Resolve.sorted_archetypes()) do
    local keys            = Resolve.archetype_loc_keys(archetype)
    local name            = (keys and keys.name_loc) and Localize(keys.name_loc) or archetype
    local desc            = (keys and keys.desc_loc) and Localize(keys.desc_loc) or nil
    local glyph           = (UiSettings.archetype_font_icon_simple and UiSettings.archetype_font_icon_simple[archetype]) or
        ""
    local primary         = select(1, Colors.archetype_color_pair(archetype))
    local label           = (glyph ~= "" and (glyph .. " ") or "") .. name
    local header          = Colors.tint_text(label, primary)

    widgets[#widgets + 1] = {
        setting_id  = ("group_%s"):format(archetype),
        type        = "group",
        title       = header,
        subtitle    = desc,
        localize    = false,
        sub_widgets = {
            {
                setting_id    = ("arch_%s_talent"):format(archetype),
                title         = Localize("loc_talent_view_display_name"),
                text          = Localize("loc_talent_view_display_name"),
                type          = "dropdown",
                default_value = "__collect__",
                options       = _get_talent_options_for(archetype),
                description   = "tbuff_talent_dropdown_tt",
                localize      = false,
            },
            {
                setting_id    = ("arch_%s_rule"):format(archetype),
                title         = Localize("loc_settings_menu_group_gameplay_settings"),
                type          = "dropdown",
                default_value = "allow",
                options       = _rule_options(),
                text          = Localize("loc_settings_menu_group_gameplay_settings"),
                localize      = false,
            },
        },
    }
end

-- ==== Weapon trait groups (shared across archetypes) =========================

local melee_icon     = ""
local melee_primary  = select(1, Colors.archetype_color_pair("zealot"))
local melee_title    = Colors.tint_text(melee_icon .. " " .. Localize("loc_glossary_term_melee_weapons"), melee_primary)

local ranged_icon    = ""
local ranged_primary = select(1, Colors.archetype_color_pair("veteran"))
local ranged_title   = Colors.tint_text(ranged_icon .. " " .. Localize("loc_glossary_term_ranged_weapons"),
    ranged_primary)

do
    widgets[#widgets + 1] = {
        setting_id  = "group_traits_melee",
        type        = "group",
        title       = melee_title,
        subtitle    = mod:localize("tbuff_group_traits_melee_desc"),
        localize    = false,
        sub_widgets = {
            {
                setting_id    = "traits_melee_choice",
                title         = Localize("loc_weapon_inventory_traits_title_text"),
                type          = "dropdown",
                default_value = "__collect__",
                options       = _get_weapon_trait_options("melee"),
                text          = Localize("loc_weapon_inventory_traits_title_text"),
                description   = "tbuff_traits_choice_tt",
                localize      = false,
            },
            {
                setting_id    = "traits_melee_rule",
                title         = Localize("loc_settings_menu_group_gameplay_settings"),
                type          = "dropdown",
                default_value = "allow",
                options       = _weapon_rule_options(),
                text          = Localize("loc_settings_menu_group_gameplay_settings"),
                description   = "tbuff_traits_rule_tt",
                localize      = false,
            },
        },
    }
end

do
    widgets[#widgets + 1] = {
        setting_id  = "group_traits_ranged",
        type        = "group",
        title       = ranged_title,
        subtitle    = mod:localize("tbuff_group_traits_ranged_desc"),
        localize    = false,
        sub_widgets = {
            {
                setting_id    = "traits_ranged_choice",
                title         = Localize("loc_weapon_inventory_traits_title_text"),
                text          = Localize("loc_weapon_inventory_traits_title_text"),
                type          = "dropdown",
                default_value = "__collect__",
                options       = _get_weapon_trait_options("ranged"),
                description   = "tbuff_traits_choice_tt",
                localize      = false,
            },
            {
                setting_id    = "traits_ranged_rule",
                title         = Localize("loc_settings_menu_group_gameplay_settings"),
                type          = "dropdown",
                default_value = "allow",
                options       = _weapon_rule_options(),
                text          = Localize("loc_settings_menu_group_gameplay_settings"),
                description   = "tbuff_traits_rule_tt",
                localize      = false,
            },
        },
    }
end

-- ==== "Misc Buffs" (unmapped) ===============================================
do
    local misc_icon       = ""
    local misc_color      = Colors.color_arr("ui_orange_light")
    local misc_title      = Colors.tint_text(misc_icon .. " " .. Localize("loc_settings_menu_group_other_settings"),
        misc_color)

    widgets[#widgets + 1] = {
        setting_id  = "group_misc_buffs",
        type        = "group",
        title       = misc_title,
        subtitle    = mod:localize("tbuff_group_misc_desc"),
        localize    = false,
        sub_widgets = {
            {
                setting_id    = "misc_choice",
                title         = Localize("loc_settings_menu_group_buff_interface_settings"),
                type          = "dropdown",
                default_value = "__collect__",
                options       = _get_misc_buff_options(),
                text          = Localize("loc_settings_menu_group_buff_interface_settings"),
                description   = "tbuff_misc_choice_tt",
                localize      = false,
            },
            {
                setting_id    = "misc_rule",
                title         = Localize("loc_settings_menu_group_gameplay_settings"),
                type          = "dropdown",
                default_value = "allow",
                options       = _weapon_rule_options(),
                text          = Localize("loc_settings_menu_group_gameplay_settings"),
                description   = "tbuff_misc_rule_tt",
                localize      = false,
            },
        },
    }
end

-- ==== Buff Bars (Reduced to simple transform settings for vanilla HUD) ========
do
    local bars_icon       = ""
    local bars_color      = Colors.color_arr("ui_blue_light")
    local bars_title      = Colors.tint_text(bars_icon .. " " .. Localize("loc_barber_vendor_view_option_modify"),
        bars_color)

    widgets[#widgets + 1] = {
        setting_id  = "group_buff_bars",
        type        = "group",
        title       = bars_title,
        subtitle    = mod:localize("tbuff_group_bars_desc"),
        localize    = false,
        sub_widgets = {
            {
                setting_id      = "bars_x_offset",
                type            = "numeric",
                default_value   = 0,
                range           = { -1500, 1500 },
                decimals_number = 0,
                title           = "X",
                text            = "X",
                localize        = false,
            },
            {
                setting_id      = "bars_y_offset",
                type            = "numeric",
                default_value   = 0,
                range           = { -1500, 1500 },
                decimals_number = 0,
                title           = "Y",
                text            = "Y",
                localize        = false,
            },
            {
                setting_id      = "bars_scale",
                type            = "numeric",
                default_value   = 1.0,
                range           = { 0.5, 3.0 },
                decimals_number = 1,
                title           = Localize("loc_interface_setting_hud_scale"),
                text            = Localize("loc_interface_setting_hud_scale"),
                description     = "tbuff_bar_scale_tt",
                localize        = false,
            },
            {
                setting_id      = "bars_opacity",
                type            = "numeric",
                default_value   = 255,
                range           = { 0, 255 },
                decimals_number = 0,
                text            = "tbuff_bar_opacity",
                description     = "tbuff_bar_opacity",
                localize        = true,
            },
        },
    }
end

-- ==== Maintenance ============================================================
do
    local maint_icon      = ""
    local maint_color     = Colors.color_arr("ui_toughness_default")
    local maint_title     = Colors.tint_text(maint_icon .. " " .. Localize("loc_weapon_inventory_inspect_button"),
        maint_color)

    widgets[#widgets + 1] = {
        setting_id  = "group_maintenance",
        type        = "group",
        title       = maint_title,
        subtitle    = mod:localize("tbuff_maintenance_group_tt"),
        localize    = false,
        sub_widgets = {
            {
                setting_id    = "tbuff_refresh_now",
                title         = Localize("loc_group_finder_refresh_group_list_button"),
                type          = "checkbox",
                default_value = false,
                description   = "tbuff_refresh_now_desc",
                localize      = false,
            },
            {
                setting_id    = "tbuff_wipe_target",
                title         = Localize("loc_discard_items_button"),
                text          = Localize("loc_discard_items_button"),
                type          = "dropdown",
                default_value = "__all__",
                options       = _wipe_target_options(),
                description   = "tbuff_wipe_target_desc",
                localize      = false,
            },
            {
                setting_id    = "tbuff_wipe_now",
                title         = Localize("loc_confirm"),
                text          = Localize("loc_confirm"),
                type          = "checkbox",
                default_value = false,
                description   = "tbuff_wipe_now_desc",
                localize      = false,
            },
        },
    }
end

return {
    name         = mod:localize("tbuff_mod_name"),
    description  = mod:localize("tbuff_mod_desc"),
    is_togglable = true,
    options      = { localize = true, widgets = widgets },
}
