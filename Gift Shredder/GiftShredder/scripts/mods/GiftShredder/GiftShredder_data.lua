-- File: GiftShredder/scripts/mods/GiftShredder/GiftShredder_data.lua
local mod = get_mod("GiftShredder"); if not mod then return end

local Localize = Localize

local gadget_toughness_text = Localize("loc_inate_gadget_toughness_desc", true, {
    toughness_bonus = "+17%",
})

local gadget_health_text = Localize("loc_inate_gadget_health_desc", true, {
    max_health_modifier = "+21%",
})

local gadget_stamina_text = Localize("loc_inate_gadget_stamina_desc", true, {
    stamina_modifier = "+3",
})

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "auto_discard_mission_rewards",
                localize = false,
                title = Localize("loc_discard_items_button"),
                text = Localize("loc_discard_items_button"),
                type = "dropdown",
                default_value = "enabled_muted",
                options = {
                    {
                        text = Localize("loc_setting_checkbox_on") .. " (" .. Localize("loc_alias_view_show_chat") ..
                            ")",
                        value = "enabled_with_notifications",
                    },
                    {
                        text = Localize("loc_setting_checkbox_on") ..
                            " (" .. Localize("loc_setting_voice_chat_presets_mic_muted") ..
                            ")",
                        value = "enabled_muted",
                    },
                    {
                        text = Localize("loc_setting_checkbox_off"),
                        value = "disabled",
                    },
                },
            },
            {
                setting_id = "keep_weapon_rewards_with_max_stat_60", -- loc_skip -- loc_mission_voting_view_accept_mission
                localize = false,
                title = Localize("loc_skip") ..
                    ": " .. Localize("loc_store_category_display_name_weapons") ..
                    " (" .. Localize("loc_item_type_trait") .. " 60)",
                text = Localize("loc_skip") ..
                    ": " .. Localize("loc_store_category_display_name_weapons") ..
                    " (" .. Localize("loc_item_type_trait") .. " 60)",
                type = "checkbox",
                default_value = false,
            },
            {
                setting_id = "keep_gadget_rewards_with_high_value_stat",
                localize = false,
                title = Localize("loc_skip") .. ": " ..
                    Localize("loc_item_type_gadget") ..
                    " (" .. gadget_toughness_text ..
                    "/" .. gadget_health_text ..
                    "/" .. gadget_stamina_text .. ")",
                text = Localize("loc_skip") ..
                    ": " .. Localize("loc_item_type_gadget") ..
                    " (" .. gadget_toughness_text ..
                    "/" .. gadget_health_text ..
                    "/" .. gadget_stamina_text .. ")",
                type = "checkbox",
                default_value = true,
            },
        },
    },
}
