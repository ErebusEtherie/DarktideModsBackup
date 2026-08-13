-- File: Flux/scripts/mods/Flux/Flux_localization.lua
local mod = get_mod("Flux")
if not mod then return end

local Localize = Localize
local string_format = string.format
local tonumber = tonumber

function mod.flux_format_coloured_title(text, r, g, b)
    r = tonumber(r) or 255
    g = tonumber(g) or 255
    b = tonumber(b) or 255

    return string_format("{#color(%d,%d,%d)}%s{#reset()}", r, g, b, text or "")
end

return {
    mod_name = {
        en = "Flux",
    },
    mod_description = {
        en = "Adds a customisable capacitance or ability bar to the HUD.",
    },

    horizontal_bar = {
        en = "Bar Mode",
    },
    horizontal_bar_description = {
        en =
        "Controls whether Flux draws horizontal, vertical, or circular segmented bars.",
    },
    bar_mode_horizontal = {
        en = "Horizontal",
    },
    bar_mode_horizontal_rev = {
        en = "Horizontal (Reversed)",
    },
    bar_mode_vertical = {
        en = "Vertical",
    },
    bar_mode_vertical_rev = {
        en = "Vertical (Reversed)",
    },
    bar_mode_circular = {
        en = "Circular",
    },
    bar_mode_circular_rev = {
        en = "Circular (Reversed)",
    },
    offset_x = { en = "X" },
    offset_y = { en = "Y" },
    bar_thickness = {
        en = "Bar Thickness",
    },
    bar_thickness_description = {
        en = "Controls the short side of linear segments, or the ring thickness in circular mode.",
    },
    bar_length = {
        en = "Bar Length",
    },
    bar_length_description = {
        en = "Controls the long side of linear bars, or the ring diameter in circular mode.",
    },
    text_mode = {
        en = "Text Widgets",
    },
    text_mode_description = {
        en = "Controls the remaining-charge text and the recharge countdown text with one shared setting.",
    },
    hide_when_full = {
        en = "Hide When Full",
    },
    hide_when_full_description = {
        en = "Fades the Flux HUD element out when all charges are available.",
    },
    font_size = { en = Localize("loc_interface_setting_subtitle_font_size") },
    font_size_description = { en = "Controls the font size of the charge and cooldown text widgets." },
    font_type = {
        en = "Text Font",
    },
    font_type_description = {
        en =
        "Selects the font used for the charge and cooldown text widgets. If the selected font is no longer available, Flux falls back to a safe default font.",
    },
    charge_text_distance = {
        en = "Charge Text Distance",
    },
    charge_text_distance_description = {
        en = "Distance from the centre of the bar to the remaining-charge text widget.",
    },
    cooldown_text_distance = {
        en = "Cooldown Text Distance",
    },
    cooldown_text_distance_description = {
        en = "Distance from the centre of the bar to the cooldown text widget.",
    },
    timer_sound_enabled = {
        en = Localize("loc_setting_notification_type_notification") ..
            " (" .. Localize("loc_settings_menu_category_sound") .. ")",
    },
    timer_sound_tooltip = {
        en = "Sound to play when a charge is gained. (Also makes the bar flash)",
    },
    archetype_colours = { en = Localize("loc_character_view_display_name") },
    glossary_default = { en = Localize("loc_setting_mix_preset_flat") },
    text_mode_off = { en = Localize("loc_setting_checkbox_off") },

    text_mode_charges = {
        en = "Charges",
    },
    text_mode_charges_pct = {
        en = "Charges & Percentage",
    },
    text_mode_cooldown = { en = Localize("loc_game_mode_expedition_objective_header_time") },
    text_mode_both = {
        en = "Charges & " .. Localize("loc_game_mode_expedition_objective_header_time"),
    },
    text_mode_both_pct = {
        en = "Charges, Percentage, & " .. Localize("loc_game_mode_expedition_objective_header_time"),
    },
    timer_sound_zealot = {
        en = Localize("loc_talent_zealot_bolstering_prayer"),
    },
    timer_sound_blunt_shield = {
        en = Localize("loc_talent_ogryn_melee_stagger") .. "!",
    },
    timer_sound_item_tier3 = {
        en = Localize("loc_eor_card_title_random_reward"),
    },

    archetype_enabled = { en = Localize("loc_setting_nv_reflex_low_latency_enabled") },
    archetype_enabled_tooltip = {
        en =
        "Set to -1 to disable. Values 0-6 will only show Flux if your max ability charges are equal to or higher than this value.",
    },
    archetype_opacity = {
        en = "Opacity",
    },
    colour_red = {
        en = mod.flux_format_coloured_title("Red", 200, 100, 100),
    },
    colour_green = {
        en = mod.flux_format_coloured_title("Green", 100, 200, 100),
    },
    colour_blue = {
        en = mod.flux_format_coloured_title("Blue", 100, 100, 200),
    },
}
