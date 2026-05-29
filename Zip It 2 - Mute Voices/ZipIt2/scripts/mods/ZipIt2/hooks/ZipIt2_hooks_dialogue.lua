-- File: ZipIt2/scripts/mods/ZipIt2/hooks/ZipIt2_hooks_dialogue.lua
local mod = get_mod("ZipIt2"); if not mod then return end

local DialogueBreedSettings = require("scripts/settings/dialogue/dialogue_breed_settings")
local DialogueCategoryConfig = require("scripts/settings/dialogue/dialogue_category_config")
local DialogueExtension = require("scripts/extension_systems/dialogue/dialogue_extension")
local DialogueSettings = require("scripts/settings/dialogue/dialogue_settings")
local DialogueSpeakerVoiceSettings = require("scripts/settings/dialogue/dialogue_speaker_voice_settings")
local DialogueSystem = require("scripts/extension_systems/dialogue/dialogue_system")
local DialogueSystemSubtitle = require("scripts/extension_systems/dialogue/dialogue_system_subtitle")
local HudElementMissionSpeakerPopup = require(
    "scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup")
local HudElementMissionSpeakerPopupSettings = require(
    "scripts/ui/hud/elements/mission_speaker_popup/hud_element_mission_speaker_popup_settings")
local NetworkLookup = require("scripts/network_lookup/network_lookup")
local StateLoading = require("scripts/game_states/game/state_loading")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIHudSettings = require("scripts/settings/ui/ui_hud_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")

local type, pairs, select, table = type, pairs, select, table
local Localize = Localize

local HUB_RADIO_DEFAULT_ICON = "content/ui/textures/icons/npc_portraits/mission_givers/default"
local HUB_RADIO_SCENEGRAPH_ID = "zipit2_hub_radio_background"
local HUB_RADIO_POPUP_WIDGET_NAME = "zipit2_hub_radio_popup"
local HUB_RADIO_NAME_WIDGET_NAME = "zipit2_hub_radio_name_text"

local hub_radio_playing_dialogue = nil
local hub_radio_bypass_play_event_mute = false

local function _first_non_empty_string(...)
    local count = select("#", ...)

    for i = 1, count do
        local value = select(i, ...)
        if type(value) == "string" and value ~= "" then
            return value
        end
    end

    return nil
end

local function _dialogue_identifier_from_event(event)
    if type(event) ~= "table" then
        return nil
    end

    return _first_non_empty_string(
        event.concept,
        event.dialogue_name,
        event.dialogue_event_name,
        event.currently_playing_subtitle,
        event.category,
        event.sound_event
    )
end

local function _dialogue_identifier_from_dialogue(dialogue)
    if type(dialogue) ~= "table" then
        return nil
    end

    return _first_non_empty_string(
        dialogue.concept,
        dialogue.dialogue_name,
        dialogue.dialogue_event_name,
        dialogue.currently_playing_subtitle,
        dialogue.category,
        dialogue.sound_event
    )
end

local function _hub_radio_mode()
    local settings = mod._zipit2_settings
    local mode = settings and settings.hub_radio_mode

    if mode == "full" then
        return "full"
    end

    return "default"
end

local function _is_full_hub_radio_enabled()
    return mod:is_enabled() and _hub_radio_mode() == "full"
end

local function _is_hub_game_mode()
    local game_mode_manager = Managers.state and Managers.state.game_mode
    local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()

    return game_mode_name == "hub"
end

local function _active_top_view_instance()
    local ui_manager = Managers.ui
    local view_name = ui_manager and ui_manager:active_top_view()

    if not view_name then
        return nil
    end

    return ui_manager:view_instance(view_name)
end

local function _is_cinematic_view_active()
    local ui_manager = Managers.ui

    if not ui_manager then
        return false
    end

    local active_views = ui_manager:active_views()

    for _, view_name in pairs(active_views) do
        if view_name == "cutscene_view" or view_name == "video_view" then
            return true
        end
    end

    return false
end

local function _local_player_dialogue_extension()
    local player_manager = Managers.player
    local local_player = player_manager and player_manager:local_player_safe(1)
    local player_unit = local_player and local_player.player_unit

    if not player_unit then
        return nil
    end

    return ScriptUnit.has_extension(player_unit, "dialogue_system")
end

local function _is_mission_giver_speaker_name(speaker_name)
    if type(speaker_name) ~= "string" or speaker_name == "" then
        return false
    end

    local mission_givers_settings = DialogueBreedSettings.mission_giver
    local mission_giver_voices = mission_givers_settings and mission_givers_settings.wwise_voices or {}

    return table.contains(mission_giver_voices, speaker_name)
end

local function _is_hub_radio_dialogue(dialogue)
    if type(dialogue) ~= "table" then
        return false
    end

    local speaker_name = dialogue.speaker_name
    local wwise_route = dialogue.wwise_route

    if not _is_mission_giver_speaker_name(speaker_name) then
        return false
    end

    return wwise_route == 1 or wwise_route == 21
end

local function _find_primary_hub_radio_dialogue(dialogue_system)
    local playing_dialogues_array = dialogue_system and dialogue_system.playing_dialogues_array and
        dialogue_system:playing_dialogues_array()

    if type(playing_dialogues_array) ~= "table" then
        return nil
    end

    for i = 1, #playing_dialogues_array do
        local dialogue = playing_dialogues_array[i]

        if _is_hub_radio_dialogue(dialogue) then
            local speaker_name = dialogue.speaker_name
            local identifier = _dialogue_identifier_from_dialogue(dialogue)

            if not mod.zipit2_should_suppress_muted_voice_ui(speaker_name, identifier) then
                return dialogue
            end
        end
    end

    return nil
end

local function _view_localize(instance, loc_key)
    if type(loc_key) ~= "string" or loc_key == "" then
        return nil
    end

    if instance and type(instance._localize) == "function" then
        return instance:_localize(loc_key)
    end

    if Localize then
        return Localize(loc_key)
    end

    return loc_key
end

local function _hub_radio_widgets(instance)
    local widgets_by_name = instance and instance._widgets_by_name

    if not widgets_by_name then
        return nil, nil
    end

    return widgets_by_name[HUB_RADIO_POPUP_WIDGET_NAME], widgets_by_name[HUB_RADIO_NAME_WIDGET_NAME]
end

local function _set_hub_radio_widget_visibility(instance, visible)
    local popup_widget, name_widget = _hub_radio_widgets(instance)

    if popup_widget then
        popup_widget.visible = visible and true or false
    end

    if name_widget then
        name_widget.visible = visible and true or false
    end
end

local function _clear_hub_radio_widget(instance)
    local popup_widget, name_widget = _hub_radio_widgets(instance)

    if name_widget and name_widget.content then
        name_widget.content[HUB_RADIO_NAME_WIDGET_NAME] = ""
    end

    if popup_widget and popup_widget.style and popup_widget.style.portrait and popup_widget.style.portrait.material_values then
        popup_widget.style.portrait.material_values.main_texture = HUB_RADIO_DEFAULT_ICON
        popup_widget.style.portrait.material_values.distortion = 1
    end

    _set_hub_radio_widget_visibility(instance, false)
end

local function _update_hub_radio_widget(instance, dialogue)
    if not instance then
        return
    end

    local popup_widget, name_widget = _hub_radio_widgets(instance)

    if not popup_widget and not name_widget then
        return
    end

    if not _is_hub_radio_dialogue(dialogue) then
        _clear_hub_radio_widget(instance)
        return
    end

    local speaker_name = dialogue.speaker_name
    local speaker_voice_settings = speaker_name and DialogueSpeakerVoiceSettings[speaker_name]
    local mission_giver_icon = speaker_voice_settings and speaker_voice_settings.icon or HUB_RADIO_DEFAULT_ICON
    local mission_giver_full_name = speaker_voice_settings and speaker_voice_settings.full_name
    local mission_giver_full_name_localized = _view_localize(instance, mission_giver_full_name) or ""

    if name_widget and name_widget.content then
        name_widget.content[HUB_RADIO_NAME_WIDGET_NAME] = mission_giver_full_name_localized
    end

    if popup_widget and popup_widget.style and popup_widget.style.portrait and popup_widget.style.portrait.material_values then
        popup_widget.style.portrait.material_values.main_texture = mission_giver_icon
        popup_widget.style.portrait.material_values.distortion = 0.4
    end

    _set_hub_radio_widget_visibility(instance, true)
end

local function _hide_hub_radio_widgets_on_active_views()
    local ui_manager = Managers.ui

    if not ui_manager then
        return
    end

    local active_views = ui_manager:active_views()

    for _, view_name in pairs(active_views) do
        local instance = ui_manager:view_instance(view_name)

        if instance then
            local popup_widget, _ = _hub_radio_widgets(instance)
            if popup_widget and popup_widget.visible ~= false then
                _clear_hub_radio_widget(instance)
            end
        end
    end
end

local function _stop_hub_radio_dialogue(dialogue_system, remove_dialogue)
    local event_id = mod._zipit2_active_hub_radio_event_id
    local dialogue_system_wwise = dialogue_system and dialogue_system._dialogue_system_wwise

    if dialogue_system_wwise and event_id then
        dialogue_system_wwise:stop_if_playing(event_id)
    end

    if remove_dialogue and dialogue_system and hub_radio_playing_dialogue and hub_radio_playing_dialogue.currently_playing_unit then
        local pd = dialogue_system._playing_dialogues
        if pd and pd[hub_radio_playing_dialogue] then
            dialogue_system:_remove_stopped_dialogue(hub_radio_playing_dialogue.currently_playing_unit,
                hub_radio_playing_dialogue)
        end
    end

    mod._zipit2_active_hub_radio_event_id = nil
    hub_radio_playing_dialogue = nil
    hub_radio_bypass_play_event_mute = false

    _hide_hub_radio_widgets_on_active_views()
end

local function _play_hub_radio_sound_event(dialogue_system, sound_event)
    if _is_cinematic_view_active() then
        return false
    end

    local player_dialogue_extension = _local_player_dialogue_extension()

    if not player_dialogue_extension then
        return false
    end

    local previous_voice_fx_preset = player_dialogue_extension._voice_fx_preset
    local previous_context_voice_fx_preset = player_dialogue_extension._context and
        player_dialogue_extension._context.voice_fx_preset or nil
    local wwise_route = dialogue_system._wwise_routes[3]

    if not wwise_route then
        return false
    end

    player_dialogue_extension._voice_fx_preset = 0

    if player_dialogue_extension._context then
        player_dialogue_extension._context.voice_fx_preset = 0
    end

    local vo_event = {
        sound_event = sound_event,
        type = "vorbis_external",
        wwise_route = wwise_route,
    }

    hub_radio_bypass_play_event_mute = true
    local event_id = player_dialogue_extension:play_event(vo_event)
    hub_radio_bypass_play_event_mute = false

    player_dialogue_extension._voice_fx_preset = previous_voice_fx_preset

    if player_dialogue_extension._context then
        player_dialogue_extension._context.voice_fx_preset = previous_context_voice_fx_preset
    end

    mod._zipit2_active_hub_radio_event_id = event_id

    return true
end

local function _hub_radio_name_text_style()
    local portrait_size = HudElementMissionSpeakerPopupSettings.portrait_size
    local name_text_style = table.clone(UIFontSettings.hud_body)

    name_text_style.horizontal_alignment = "right"
    name_text_style.vertical_alignment = "top"
    name_text_style.text_horizontal_alignment = "right"
    name_text_style.text_vertical_alignment = "bottom"
    name_text_style.size = {
        650,
        40,
    }
    name_text_style.offset = {
        -(portrait_size[1] + 20),
        15,
        2,
    }
    name_text_style.drop_shadow = true
    name_text_style.font_size = 24

    return name_text_style
end

local function _add_hub_radio_definitions(definitions)
    if type(definitions) ~= "table" then
        return
    end

    definitions.scenegraph_definition = definitions.scenegraph_definition or {}
    definitions.widget_definitions = definitions.widget_definitions or {}

    local scenegraph_definition = definitions.scenegraph_definition
    local widget_definitions = definitions.widget_definitions
    local portrait_size = HudElementMissionSpeakerPopupSettings.portrait_size

    scenegraph_definition.screen = scenegraph_definition.screen or UIWorkspaceSettings.screen
    scenegraph_definition[HUB_RADIO_SCENEGRAPH_ID] = scenegraph_definition[HUB_RADIO_SCENEGRAPH_ID] or {
        horizontal_alignment = "right",
        parent = "screen",
        vertical_alignment = "top",
        size = portrait_size,
        position = {
            -50,
            300,
            200,
        },
    }

    if not widget_definitions[HUB_RADIO_POPUP_WIDGET_NAME] then
        widget_definitions[HUB_RADIO_POPUP_WIDGET_NAME] = UIWidget.create_definition({
            {
                pass_type = "texture",
                style_id = "portrait",
                value = "content/ui/materials/base/ui_radio_portrait_base",
                style = {
                    horizontal_alignment = "center",
                    vertical_alignment = "top",
                    offset = {
                        -1,
                        0,
                        0,
                    },
                    size = portrait_size,
                    color = {
                        255,
                        255,
                        255,
                        255,
                    },
                    material_values = {
                        main_texture = HUB_RADIO_DEFAULT_ICON,
                        distortion = 1,
                    },
                },
            },
            {
                pass_type = "texture",
                style_id = "frame",
                value = "content/ui/materials/hud/backgrounds/weapon_frame",
                style = {
                    horizontal_alignment = "right",
                    vertical_alignment = "center",
                    color = UIHudSettings.color_tint_main_3,
                    offset = {
                        0,
                        0,
                        2,
                    },
                    size_addition = {
                        8,
                        5,
                    },
                },
            },
        }, HUB_RADIO_SCENEGRAPH_ID)
    end

    if not widget_definitions[HUB_RADIO_NAME_WIDGET_NAME] then
        widget_definitions[HUB_RADIO_NAME_WIDGET_NAME] = UIWidget.create_definition({
            {
                pass_type = "text",
                style_id = HUB_RADIO_NAME_WIDGET_NAME,
                value_id = HUB_RADIO_NAME_WIDGET_NAME,
                value = "",
                style = _hub_radio_name_text_style(),
            },
        }, HUB_RADIO_SCENEGRAPH_ID)
    end
end

local function _add_hub_radio_view_hook(definitions_path)
    mod:hook_require(definitions_path, function(definitions)
        _add_hub_radio_definitions(definitions)
    end)
end

_add_hub_radio_view_hook("scripts/ui/views/inventory_view/inventory_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/inventory_background_view/inventory_background_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/masteries_overview_view/masteries_overview_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/mastery_view/mastery_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/inventory_cosmetics_view/inventory_cosmetics_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/inventory_weapons_view/inventory_weapons_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/inventory_weapon_cosmetics_view/inventory_weapon_cosmetics_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/inventory_weapon_details_view/inventory_weapon_details_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/inventory_weapon_marks_view/inventory_weapon_marks_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/crafting_view/crafting_view_definitions")
_add_hub_radio_view_hook(
    "scripts/ui/views/crafting_mechanicus_barter_items_view/crafting_mechanicus_barter_items_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/crafting_mechanicus_modify_view/crafting_mechanicus_modify_view_definitions")
_add_hub_radio_view_hook(
    "scripts/ui/views/crafting_mechanicus_replace_perk_view/crafting_mechanicus_replace_perk_view_definitions")
_add_hub_radio_view_hook(
    "scripts/ui/views/crafting_mechanicus_replace_trait_view/crafting_mechanicus_replace_trait_view_definitions")
_add_hub_radio_view_hook(
    "scripts/ui/views/crafting_mechanicus_upgrade_expertise_view/crafting_mechanicus_upgrade_expertise_view_definitions")
_add_hub_radio_view_hook(
    "scripts/ui/views/crafting_mechanicus_upgrade_item_view/crafting_mechanicus_upgrade_item_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/cosmetics_vendor_view/cosmetics_vendor_view_definitions")
_add_hub_radio_view_hook(
    "scripts/ui/views/cosmetics_vendor_background_view/cosmetics_vendor_background_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/cosmetics_inspect_view/cosmetics_inspect_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/contracts_view/contracts_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/contracts_background_view/contracts_background_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/marks_goods_vendor_view/marks_goods_vendor_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/marks_vendor_view/marks_vendor_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/credits_goods_vendor_view/credits_goods_vendor_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/credits_vendor_background_view/credits_vendor_background_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/credits_vendor_view/credits_vendor_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/penance_overview_view/penance_overview_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/store_view/store_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/store_item_detail_view/store_item_detail_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/mission_board_view/mission_board_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/barber_vendor_background_view/barber_vendor_background_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/live_events_view/live_events_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/havoc_background_view/havoc_background_view_definitions")
_add_hub_radio_view_hook("scripts/ui/views/expedition_background_view/expedition_background_view_definitions")

mod.zipit2_register_dialogue_hooks = mod.zipit2_register_dialogue_hooks or function()
    if mod._zipit2_dialogue_hooks_registered then
        return
    end

    mod._zipit2_dialogue_hooks_registered = true

    mod:hook(DialogueExtension, "play_event", function(func, self, event)
        if hub_radio_bypass_play_event_mute then
            return func(self, event)
        end

        if not mod:is_enabled() then
            return func(self, event)
        end

        -- Extensions in Darktide standardise passing the unit to self._unit
        local unit = self._unit or self.unit
        if unit and mod.zipit2_should_mute_bot and mod.zipit2_should_mute_bot(unit) then
            return
        end

        local voice_profile = self and self._vo_profile_name
        local identifier = _dialogue_identifier_from_event(event)

        if mod.zipit2_should_mute_enemy_dialogue_breed(voice_profile, event, nil, nil) then
            return
        end

        if voice_profile and mod.zipit2_should_mute_voice_profile(voice_profile, identifier) then
            local st = mod._zipit2_state

            if st.in_lobby_view or st.in_mission_intro_view or st.in_briefing_state then
                st.blocked_briefing_vo = true
            end

            return
        end

        return func(self, event)
    end)

    mod:hook(DialogueSystem, "_play_dialogue_event_implementation",
        function(func, self, go_id, is_level_unit, level_name_hash,
                 dialogue_id, dialogue_index, dialogue_rule_index, optional_query)
            if not _is_full_hub_radio_enabled() then
                return func(self, go_id, is_level_unit, level_name_hash, dialogue_id, dialogue_index,
                    dialogue_rule_index, optional_query)
            end

            if not _is_hub_game_mode() then
                return func(self, go_id, is_level_unit, level_name_hash, dialogue_id, dialogue_index,
                    dialogue_rule_index, optional_query)
            end

            local dialogue_actor_unit = Managers.state.unit_spawner:unit(go_id, is_level_unit, level_name_hash)
            local extension = dialogue_actor_unit and self._unit_to_extension_map[dialogue_actor_unit]

            if not extension then
                return func(self, go_id, is_level_unit, level_name_hash, dialogue_id, dialogue_index,
                    dialogue_rule_index, optional_query)
            end

            if extension:is_a_player() and not HEALTH_ALIVE[dialogue_actor_unit] then
                return
            end

            local dialogue_name = NetworkLookup.dialogue_names[dialogue_id]
            local dialogue_template = dialogue_name and self._dialogue_templates[dialogue_name]

            if not dialogue_template then
                return func(self, go_id, is_level_unit, level_name_hash, dialogue_id, dialogue_index,
                    dialogue_rule_index, optional_query)
            end

            local speaker_context = extension:get_context()
            local speaker_name = speaker_context and speaker_context.voice_template
            local wwise_route_key = dialogue_template.wwise_route
            local class_name = speaker_context and speaker_context.class_name

            if mod.zipit2_should_mute_enemy_dialogue_breed(speaker_name, nil, optional_query, nil) then
                return
            end

            if class_name == "tech_priest" and wwise_route_key == 1 then
                wwise_route_key = 21
            end

            local should_route_to_views = _is_mission_giver_speaker_name(speaker_name)
                and (wwise_route_key == 1 or wwise_route_key == 21)
                and not mod.zipit2_should_mute_voice_profile(speaker_name, dialogue_name)

            if not should_route_to_views then
                return func(self, go_id, is_level_unit, level_name_hash, dialogue_id, dialogue_index,
                    dialogue_rule_index, optional_query)
            end

            local dialogue_category = dialogue_template.category

            if not self:_is_playable_dialogue_category(dialogue_category) then
                return
            end

            if self:_prevent_on_demand_vo(dialogue_actor_unit, dialogue_category) then
                return
            end

            if extension:is_currently_playing_dialogue() then
                extension:stop_currently_playing_vo()
            end

            local sound_event, subtitles_event, sound_event_duration =
                extension:get_dialogue_event(dialogue_name, dialogue_index)
            local rule = self._tagquery_database:get_rule(dialogue_rule_index)

            if sound_event then
                extension:set_last_query_sound_event(sound_event)
            end

            local dialogue = extension:request_empty_dialogue_table()

            table.merge(dialogue, dialogue_template)

            dialogue.speaker_name = speaker_name
            dialogue.wwise_route = wwise_route_key
            dialogue.used_query = optional_query
            dialogue.enemy_tag = type(optional_query) == "table" and optional_query.enemy_tag or nil
            dialogue.breed_name = type(optional_query) == "table" and optional_query.breed_name or nil
            self._speaker_name = speaker_name

            if not DEDICATED_SERVER then
                local wwise_route = self._wwise_route_default

                if wwise_route_key ~= nil then
                    wwise_route = self._wwise_routes[wwise_route_key]
                end

                if not sound_event then
                    return
                end

                local is_sequence = false

                if rule and (rule.pre_wwise_event or rule.post_wwise_event) then
                    dialogue.dialogue_sequence = self:_create_sequence_events_table(
                        rule.pre_wwise_event,
                        wwise_route,
                        sound_event,
                        rule.post_wwise_event
                    )

                    if _play_hub_radio_sound_event(self, sound_event) then
                        dialogue.currently_playing_event_id = nil
                    else
                        dialogue.currently_playing_event_id = extension:play_event(dialogue.dialogue_sequence[1])
                    end

                    is_sequence = true
                else
                    local vo_event = {
                        sound_event = sound_event,
                        type = "vorbis_external",
                        wwise_route = wwise_route,
                    }

                    if _play_hub_radio_sound_event(self, sound_event) then
                        dialogue.currently_playing_event_id = nil
                    else
                        dialogue.currently_playing_event_id = extension:play_event(vo_event)
                    end
                end

                local concurrent_wwise_event = rule and rule.concurrent_wwise_event

                if concurrent_wwise_event then
                    dialogue.concurrent_wwise_event_id = self:play_wwise_event(extension, concurrent_wwise_event)
                end

                local distance_culled_wwise_routes = DialogueSettings.distance_culled_wwise_routes
                local subtitle_distance = distance_culled_wwise_routes[wwise_route_key]

                if subtitle_distance then
                    dialogue.subtitle_distance = subtitle_distance
                    dialogue.is_audible = self:is_dialogue_audible(dialogue_actor_unit, dialogue)
                else
                    dialogue.is_audible = true
                end

                self:_trigger_face_animation_event(dialogue_actor_unit, "start_talking")

                self._playing_units[dialogue_actor_unit] = extension
                dialogue.currently_playing_unit = dialogue_actor_unit
                dialogue.dialogue_timer = sound_event_duration
                dialogue.currently_playing_subtitle = subtitles_event

                extension:set_is_currently_playing_dialogue(true)

                local category_config = DialogueCategoryConfig[dialogue_category]

                self._playing_dialogues[dialogue] = category_config
                table.insert(self._playing_dialogues_array, 1, dialogue)

                local sequence_table = dialogue.dialogue_sequence

                if (sequence_table ~= nil and sequence_table[1] and sequence_table[1].type == "vorbis_external")
                    or not is_sequence
                then
                    self._dialogue_system_subtitle:add_playing_localized_dialogue(speaker_name, dialogue)
                end

                hub_radio_playing_dialogue = dialogue
            end
        end)

    mod:hook(DialogueSystemSubtitle, "add_playing_localized_dialogue", function(func, self, speaker_name, dialogue)
        if not mod:is_enabled() then
            return func(self, speaker_name, dialogue)
        end

        if dialogue and dialogue.currently_playing_unit and mod.zipit2_should_mute_bot and mod.zipit2_should_mute_bot(dialogue.currently_playing_unit) then
            return
        end

        if mod.zipit2_should_mute_enemy_dialogue_breed(speaker_name, nil, nil, dialogue) then
            return
        end

        local identifier = _dialogue_identifier_from_dialogue(dialogue)

        if mod.zipit2_should_suppress_muted_voice_ui(speaker_name, identifier) then
            return
        end

        return func(self, speaker_name, dialogue)
    end)

    mod:hook(HudElementMissionSpeakerPopup, "_sync_active_speaker",
        function(func, self, dt, t, ui_renderer, render_settings, input_service)
            if not mod:is_enabled() or mod._zipit2_settings.subtitles_enabled then
                return func(self, dt, t, ui_renderer, render_settings, input_service)
            end

            local extension_manager = Managers.state.extension
            local dialogue_system = extension_manager and extension_manager:system("dialogue_system")

            if not dialogue_system then
                return
            end

            local mission_giver_speaker_name
            local playing_dialogues_array = dialogue_system:playing_dialogues_array()
            local mission_givers_settings = DialogueBreedSettings.mission_giver
            local mission_giver_voices = mission_givers_settings and mission_givers_settings.wwise_voices or {}

            for i = 1, #playing_dialogues_array do
                local currently_playing = playing_dialogues_array[i]
                local current_speaker_name = currently_playing and currently_playing.speaker_name
                local current_identifier = _dialogue_identifier_from_dialogue(currently_playing)

                if type(current_speaker_name) == "string"
                    and not mod.zipit2_should_mute_enemy_dialogue_breed(current_speaker_name, nil, nil, currently_playing)
                    and not mod.zipit2_should_suppress_muted_voice_ui(current_speaker_name, current_identifier)
                then
                    if current_speaker_name == self._speaker_name then
                        mission_giver_speaker_name = self._speaker_name
                        break
                    end

                    if table.contains(mission_giver_voices, current_speaker_name) then
                        local ww_route = currently_playing.wwise_route

                        if ww_route == 1 or ww_route == 21 then
                            mission_giver_speaker_name = current_speaker_name
                        end
                    end
                end
            end

            if mission_giver_speaker_name ~= self._speaker_name then
                self._speaker_name = mission_giver_speaker_name
                self:_mission_speaker_stop()
                self._is_speaking = false
            else
                return
            end

            if not mission_giver_speaker_name then
                return
            end

            local speaker_voice_settings = DialogueSpeakerVoiceSettings[mission_giver_speaker_name]
            local mission_giver_icon = speaker_voice_settings and speaker_voice_settings.icon
            local mission_giver_full_name = speaker_voice_settings and speaker_voice_settings.full_name
            local mission_giver_full_name_localized = self:_localize(mission_giver_full_name)

            self:_mission_speaker_start(mission_giver_full_name_localized, mission_giver_icon)
            self._is_speaking = true
        end)

    mod:hook_safe(DialogueSystem, "update", function(self, context, dt, t)
        if not _is_full_hub_radio_enabled() or not _is_hub_game_mode() then
            _hide_hub_radio_widgets_on_active_views()
            hub_radio_playing_dialogue = nil
            return
        end

        if _is_cinematic_view_active() then
            _stop_hub_radio_dialogue(self, true)
            return
        end

        local dialogue = _find_primary_hub_radio_dialogue(self)
        if dialogue then
            hub_radio_playing_dialogue = dialogue
        end

        if hub_radio_playing_dialogue then
            local event_id = mod._zipit2_active_hub_radio_event_id
            local is_playing = false
            if event_id and self._dialogue_system_wwise then
                is_playing = self._dialogue_system_wwise:is_playing(event_id)
            end

            local timer = hub_radio_playing_dialogue.dialogue_timer or 0
            timer = timer - dt
            hub_radio_playing_dialogue.dialogue_timer = timer

            if timer <= 0 and not is_playing then
                hub_radio_playing_dialogue = nil
                mod._zipit2_active_hub_radio_event_id = nil
                _hide_hub_radio_widgets_on_active_views()
            else
                local instance = _active_top_view_instance()
                if instance then
                    _update_hub_radio_widget(instance, hub_radio_playing_dialogue)
                end
            end
        else
            _hide_hub_radio_widgets_on_active_views()
        end
    end)

    mod:hook_safe(StateLoading, "on_enter", function(self, ...)
        local extension_manager = Managers.state and Managers.state.extension
        local dialogue_system = extension_manager and extension_manager:system("dialogue_system")

        _stop_hub_radio_dialogue(dialogue_system, true)
    end)
end
