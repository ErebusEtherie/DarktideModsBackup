-- File: ZipIt2/scripts/mods/ZipIt2/settings/ZipIt2_data_com_wheel.lua
local mod = get_mod("ZipIt2"); if not mod then return end

local ChatManagerConstants = require("scripts/foundation/managers/chat/chat_manager_constants")
local VoQueryConstants = require("scripts/settings/dialogue/vo_query_constants")

local type = type

local ChannelTags = ChatManagerConstants.ChannelTag

local MIRRORED_COM_WHEEL_OPTIONS = {
    {
        value = "cheer",
        display_name_loc = "loc_communication_wheel_display_name_cheer",
        icon = "content/ui/materials/hud/communication_wheel/icons/for_the_emperor",
        voice_event_data = {
            voice_tag_concept = VoQueryConstants.concepts.on_demand_com_wheel,
            voice_tag_id = VoQueryConstants.trigger_ids.com_wheel_vo_for_the_emperor,
        },
        start_angle = -(math.pi / 8) * 3,
    },
    {
        value = "health",
        display_name_loc = "loc_communication_wheel_display_name_need_health",
        icon = "content/ui/materials/hud/communication_wheel/icons/health",
        chat_message_data = {
            text = "loc_communication_wheel_need_health",
            channel = ChannelTags.MISSION,
        },
        voice_event_data = {
            voice_tag_concept = VoQueryConstants.concepts.on_demand_com_wheel,
            voice_tag_id = VoQueryConstants.trigger_ids.com_wheel_vo_need_health,
        },
    },
    {
        value = "thanks",
        display_name_loc = "loc_communication_wheel_display_name_thanks",
        icon = "content/ui/materials/hud/communication_wheel/icons/thanks",
        chat_message_data = {
            text = "loc_communication_wheel_thanks",
            channel = ChannelTags.MISSION,
        },
        voice_event_data = {
            voice_tag_concept = VoQueryConstants.concepts.on_demand_com_wheel,
            voice_tag_id = VoQueryConstants.trigger_ids.com_wheel_vo_thank_you,
        },
    },
    {
        value = "ammo",
        display_name_loc = "loc_communication_wheel_display_name_need_ammo",
        icon = "content/ui/materials/hud/communication_wheel/icons/ammo",
        chat_message_data = {
            text = "loc_communication_wheel_need_ammo",
            channel = ChannelTags.MISSION,
        },
        voice_event_data = {
            voice_tag_concept = VoQueryConstants.concepts.on_demand_com_wheel,
            voice_tag_id = VoQueryConstants.trigger_ids.com_wheel_vo_need_ammo,
        },
    },
    {
        value = "enemy",
        display_name_loc = "loc_communication_wheel_display_name_enemy",
        icon = "content/ui/materials/hud/communication_wheel/icons/enemy",
        tag_type = "location_threat",
        voice_event_data = {
            voice_tag_concept = VoQueryConstants.concepts.on_demand_com_wheel,
            voice_tag_id = VoQueryConstants.trigger_ids.com_wheel_vo_enemy_over_here,
        },
        start_angle = -(math.pi / 8) * 2,
    },
    {
        value = "location",
        display_name_loc = "loc_communication_wheel_display_name_location",
        icon = "content/ui/materials/hud/communication_wheel/icons/location",
        tag_type = "location_ping",
        voice_event_data = {
            voice_tag_concept = VoQueryConstants.concepts.on_demand_com_wheel,
            voice_tag_id = VoQueryConstants.trigger_ids.com_wheel_vo_lets_go_this_way,
        },
    },
    {
        value = "attention",
        display_name_loc = "loc_communication_wheel_display_name_attention",
        icon = "content/ui/materials/hud/communication_wheel/icons/attention",
        tag_type = "location_attention",
        voice_event_data = {
            voice_tag_concept = VoQueryConstants.concepts.on_demand_com_wheel,
            voice_tag_id = VoQueryConstants.trigger_ids.com_wheel_vo_over_here,
        },
    },
}

local function _copy_option_entry(src)
    if type(src) ~= "table" then
        return nil
    end

    local entry = {
        value = src.value,
        display_name_loc = src.display_name_loc,
        icon = src.icon,
        tag_type = src.tag_type,
        start_angle = src.start_angle,
    }

    local chat_message_data = src.chat_message_data
    if type(chat_message_data) == "table" then
        entry.chat_message_data = {
            text = chat_message_data.text,
            channel = chat_message_data.channel,
        }
    end

    local voice_event_data = src.voice_event_data
    if type(voice_event_data) == "table" then
        entry.voice_event_data = {
            voice_tag_concept = voice_event_data.voice_tag_concept,
            voice_tag_id = voice_event_data.voice_tag_id,
        }
    end

    return entry
end

mod.zipit2_build_com_wheel = function(D)
    D = D or mod._zipit2_discovery or {}

    local options = {}
    local option_by_value = {}
    local options_len = 0
    local default_value = nil
    local source_count = #MIRRORED_COM_WHEEL_OPTIONS

    for i = 1, source_count do
        local src = MIRRORED_COM_WHEEL_OPTIONS[i]
        local entry = _copy_option_entry(src)
        local value = entry and entry.value

        if type(value) == "string" and value ~= "" then
            options_len = options_len + 1
            options[options_len] = entry
            option_by_value[value] = entry

            if not default_value then
                default_value = value
            end

            if value == "thanks" then
                default_value = value
            end
        end
    end

    D.com_wheel_options = options
    D.com_wheel_option_by_value = option_by_value
    D.com_wheel_default_option = default_value
    D.com_wheel_options_count = options_len
end

return mod.zipit2_build_com_wheel
