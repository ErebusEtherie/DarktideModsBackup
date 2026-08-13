-- Setup (core references)
local mod = get_mod("Killfeed_Reborn")
local Breed = mod:original_require("scripts/utilities/breed")
local ChatManagerConstants = mod:original_require("scripts/foundation/managers/chat/chat_manager_constants")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")

-- Paths (external files)
local PATHS = {
    phrases = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/data/phrases",
    localization = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/Killfeed_Reborn_localization",
    classification = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/data/kill_classification",
    death_classifications = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/data/death_classifications",
    colors = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/modules/colors",
    combat_feed = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/modules/combat_feed",
    death_messages = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/modules/death_messages",
    kill_messages = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/modules/kill_messages",
    phrase_picker = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/modules/phrase_picker",
    profile_logger = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/modules/profile_logger",
    settings = "Killfeed_Reborn/scripts/mods/Killfeed_Reborn/modules/settings",
}
local COMBAT_FEED_DEFINITIONS_PATH = "scripts/ui/hud/elements/combat_feed/hud_element_combat_feed_definitions"
local COMBAT_FEED_SETTINGS_PATH = "scripts/ui/hud/elements/combat_feed/hud_element_combat_feed_settings"

-- Modules (mod behavior split by responsibility)
local color_helpers = mod:io_dofile(PATHS.colors)
local combat_feed_helpers = mod:io_dofile(PATHS.combat_feed)
local death_messages = mod:io_dofile(PATHS.death_messages)
local kill_messages = mod:io_dofile(PATHS.kill_messages)
local phrase_picker = mod:io_dofile(PATHS.phrase_picker)
local profile_logger = mod:io_dofile(PATHS.profile_logger)
local settings_helpers = mod:io_dofile(PATHS.settings)

-- State (runtime caches)
local phrases = {}
local last_damage = {}
local active_player_state_messages = {}
local active_combat_feed

-- Settings / Colors (cached values)
local settings = settings_helpers.defaults()
local colors = settings_helpers.default_colors()

-- Classification (external tables)
local classification = mod:io_dofile(PATHS.classification) or {}
local death_classifications = mod:io_dofile(PATHS.death_classifications) or {}
local damage_tables = classification.kill or {}
local profile_family_lookup = {}

for family, profiles in pairs(damage_tables.family_profiles or {}) do
    for i = 1, #profiles do
        profile_family_lookup[profiles[i]] = family
    end
end

-- Feed Layout (combat feed definitions)
mod:hook_require(COMBAT_FEED_DEFINITIONS_PATH, function(instance)
    local width = 600
    local side_padding = 10
    local icon_width = 40
    local text_width = width - (icon_width + side_padding * 2)

    instance.scenegraph_definition.background.size[1] = width

    local widget = instance.notification_message_default
    local text_style = widget.style and widget.style.text

    if text_style then
        text_style.size[1] = text_width
    end
end)

-- Feed Defaults (combat feed settings)
mod:hook_require(COMBAT_FEED_SETTINGS_PATH, function(instance)
    instance.max_messages = mod:get("max_messages") or settings.max_messages or instance.max_messages
end)

-- Localization (DMF strings)
mod:io_dofile(PATHS.localization)

-- Determiners (message grammar)
local determiners = {
    { text = "a", weight = 2 },
    { text = "the", weight = 2 },
    { text = "another", weight = 1 },
}
local death_source_determiners = {
    { text = "A", weight = 2 },
    { text = "The", weight = 2 },
}

local determiner_total = 0
for i = 1, #determiners do
    determiner_total = determiner_total + determiners[i].weight
end
local death_source_determiner_total = 0
for i = 1, #death_source_determiners do
    death_source_determiner_total = death_source_determiner_total + death_source_determiners[i].weight
end

local function load_phrases()
    phrases = mod:io_dofile(PATHS.phrases) or {}
    phrase_picker.reset()
end

-- Settings (cache refresh)
local function refresh_cached_settings()
    settings_helpers.refresh(mod, settings, colors)
    color_helpers.apply_player_slot_colors(colors, UISettings)
end

-- Feed Settings (runtime apply)
local function apply_combat_feed_timing(combat_feed)
    combat_feed_helpers.apply_timing(combat_feed, settings)
end

local function apply_combat_feed_message_limit(combat_feed)
    combat_feed_helpers.apply_message_limit(combat_feed, settings)
end

local function apply_combat_feed_settings(combat_feed)
    combat_feed_helpers.apply_settings(combat_feed, settings)
end

-- Settings (color titles)
local function refresh_color_group_title(setting_id)
    color_helpers.refresh_color_group_title(mod, setting_id, color_helpers.category_title_by_setting)
end

-- Categories (phrase selection)
local function choose_random_category(categories)
    return categories and categories[#categories > 0 and math.random(#categories) or 1] or nil
end

-- Determiners (random selection)
local function random_det()
    local roll = math.random(determiner_total)
    local running_total = 0

    for i = 1, #determiners do
        running_total = running_total + determiners[i].weight
        if roll <= running_total then
            return determiners[i].text
        end
    end

    return "a"
end

local function random_death_source_det()
    local roll = math.random(death_source_determiner_total)
    local running_total = 0

    for i = 1, #death_source_determiners do
        running_total = running_total + death_source_determiners[i].weight
        if roll <= running_total then
            return death_source_determiners[i].text
        end
    end

    return "A"
end

-- Feed (message dispatch)
local function add_combat_feed_message(text)
    combat_feed_helpers.add_message(text, active_combat_feed)
end

-- Names (units)
local function get_name(unit)
    if not unit then
        return nil
    end

    local player_manager = Managers.state and Managers.state.player_unit_spawn
    local player = player_manager and player_manager:owner(unit)
    if player then
        return player:name()
    end

    local unit_data_extension = ScriptUnit.has_extension(unit, "unit_data_system")
    local breed = unit_data_extension and unit_data_extension:breed()
    return breed and Breed.is_minion(breed) and Localize(breed.display_name) or nil
end

-- Metrics (local player)
local function is_player_unit(unit)
    local player_manager = Managers.state and Managers.state.player_unit_spawn
    return unit and player_manager and player_manager:owner(unit) ~= nil
end

local function is_local_player_unit(unit)
    local local_player = Managers.player and Managers.player:local_player(1)
    return unit and local_player and local_player.player_unit == unit
end

local function should_show_for_metrics(unit)
    return settings.metrics ~= "self" or is_local_player_unit(unit)
end

-- Colors (party slots)
local function get_killer_color(unit)
    return color_helpers.get_killer_color(unit, colors)
end

-- Context (shared module dependencies)
local shared_module_context

local function module_context()
    if shared_module_context then
        return shared_module_context
    end

    shared_module_context = {
        colors = colors,
        damage_tables = damage_tables,
        death_classifications = death_classifications,
        last_damage = last_damage,
        phrases = phrases,
        phrase_picker = phrase_picker,
        profile_logger = profile_logger,
        profile_family_lookup = profile_family_lookup,
        active_player_state_messages = active_player_state_messages,
        settings = settings,
        add_combat_feed_message = add_combat_feed_message,
        choose_random_category = choose_random_category,
        colorize = color_helpers.colorize,
        get_killer_color = get_killer_color,
        get_name = get_name,
        is_player_unit = is_player_unit,
        neon_text = color_helpers.neon_text,
        random_death_source_det = random_death_source_det,
        random_det = random_det,
        should_show_for_metrics = should_show_for_metrics,
    }

    return shared_module_context
end

local function reset_mission_caches()
    last_damage = {}
    active_player_state_messages = {}

    if shared_module_context then
        shared_module_context.last_damage = last_damage
        shared_module_context.active_player_state_messages = active_player_state_messages
    end
end

-- Startup (initial cache)
load_phrases()
refresh_cached_settings()

-- Settings (DMF changes)
mod.on_setting_changed = function(setting_id)
    refresh_cached_settings()
    refresh_color_group_title(setting_id)

    if setting_id == "message_duration" or setting_id == "fade_out" then
        apply_combat_feed_timing(active_combat_feed)
    elseif setting_id == "max_messages" then
        apply_combat_feed_message_limit(active_combat_feed)
    end
end

local hooked = false

-- Hooks (registration)
mod.on_all_mods_loaded = function()
    if hooked then
        return
    end

    hooked = true

    -- Hooks (mission lifecycle)
    mod:hook(CLASS.StateGameplay, "on_enter", function(func, self, parent, params, creation_context, ...)
        reset_mission_caches()

        return func(self, parent, params, creation_context, ...)
    end)

    mod:hook(CLASS.StateGameplay, "on_exit", function(func, self, exit_params, ...)
        reset_mission_caches()

        return func(self, exit_params, ...)
    end)

    -- Hooks (attack data)
    mod:hook(CLASS.AttackReportManager, "add_attack_result", function(func, self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
        if attacking_unit and attacked_unit then
            local attacker_cache = last_damage[attacking_unit]

            if not attacker_cache then
                attacker_cache = {}
                last_damage[attacking_unit] = attacker_cache
            end

            attacker_cache[attacked_unit] = damage_profile and damage_profile.name or "nil"
        end

        return func(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
    end)

    mod:hook_safe("AttackReportManager", "_process_attack_result", function(self, buffer_data)
        if not buffer_data then
            return
        end

        local attacked_unit = buffer_data.attacked_unit
        if not is_player_unit(attacked_unit) then
            return
        end

        local damage_profile = buffer_data.damage_profile
        death_messages.maybe_add_player_state_message(module_context(), attacked_unit, buffer_data.attacking_unit, damage_profile and damage_profile.name)
    end)

    -- Hooks (feed setup)
    mod:hook_safe("HudElementCombatFeed", "init", function(self)
        active_combat_feed = self
        apply_combat_feed_settings(self)
    end)

    local combat_feed = require("scripts/ui/hud/elements/combat_feed/hud_element_combat_feed")

    -- Hooks (feed settings)
    mod:hook(combat_feed, "event_update_combat_feed_message_duration", function(func, self, value)
        func(self, value)
        apply_combat_feed_timing(self)
    end)

    mod:hook(combat_feed, "event_update_combat_feed_max_messages", function(func, self, value)
        func(self, value)
        apply_combat_feed_message_limit(self)
    end)

    mod:hook(combat_feed, "event_add_combat_feed_message", function(func, self, text)
        active_combat_feed = self

        return func(self, text)
    end)

    -- Hooks (kill messages)
    mod:hook(combat_feed, "event_combat_feed_kill", function(func, self, attacker, victim)
        local handled = kill_messages.handle(module_context(), self, attacker, victim)

        if handled == false then
            return func(self, attacker, victim)
        end
    end)

    -- Hooks (local UI rendering only)
    mod:hook(CLASS.ConstantElementChat, "_add_message", function(func, self, message, sender, channel)
        if not settings.chat_colors then
            return func(self, message, sender, channel)
        end

        return func(self, message, color_helpers.colorize_chat_sender(sender, channel, colors, ChatManagerConstants), channel)
    end)

    mod:hook(CLASS.ConstantElementSubtitles, "_display_text_line", function(func, self, text, duration, secondary_subtitle)
        return func(self, color_helpers.colorize_subtitle_speaker(text, colors), duration, secondary_subtitle)
    end)
end
