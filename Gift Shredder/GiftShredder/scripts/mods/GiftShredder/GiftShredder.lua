-- File: GiftShredder/scripts/mods/GiftShredder/GiftShredder.lua
local mod = get_mod("GiftShredder")
if not mod then
    return
end

local Items                           = require("scripts/utilities/items")
local MasterItems                     = require("scripts/backend/master_items")
local ProfileUtils                    = require("scripts/utilities/profile_utils")
local WeaponStats                     = require("scripts/utilities/weapon_stats")

local ipairs                          = ipairs
local pairs                           = pairs
local math_lerp                       = math.lerp
local math_round                      = math.round
local math_round_with_precision       = math.round_with_precision
local string_find                     = string.find
local string_format                   = string.format
local string_sub                      = string.sub
local table_remove                    = table.remove
local tonumber                        = tonumber
local tostring                        = tostring
local type                            = type

mod._seen_gear_ids                    = mod._seen_gear_ids or {}
mod._pending_discard_rewards          = mod._pending_discard_rewards or {}
mod._pending_discard_seen             = mod._pending_discard_seen or {}
mod._discard_state                    = mod._discard_state or {}
mod._time                             = mod._time or 0

local DISCARD_RETRY_DELAY             = 0.5
local DISCARD_MAX_TRIES               = 30

local GADGET_EXPERTISE_KEEP_THRESHOLD = 410
local GADGET_STAMINA_KEEP_THRESHOLD   = 3
local GADGET_HEALTH_KEEP_THRESHOLD    = 0.21
local GADGET_TOUGHNESS_KEEP_THRESHOLD = 0.17

local function is_loc_key(value)
    return type(value) == "string" and string_sub(value, 1, 4) == "loc_"
end

function mod._update_cached_settings(setting_id)
    if setting_id == nil or setting_id == "auto_discard_mission_rewards" then
        mod.auto_discard_mission_rewards_mode = mod:get("auto_discard_mission_rewards")
        mod.auto_discard_mission_rewards_enabled = mod.auto_discard_mission_rewards_mode ~= "disabled"
        mod.auto_discard_mission_reward_echoes_enabled = mod.auto_discard_mission_rewards_mode ==
            "enabled_with_notifications"
    end

    if setting_id == nil or setting_id == "keep_weapon_rewards_with_max_stat_60" then
        mod.keep_weapon_rewards_with_max_stat_60 = mod:get("keep_weapon_rewards_with_max_stat_60")
    end

    if setting_id == nil or setting_id == "keep_gadget_rewards_with_high_value_stat" then
        mod.keep_gadget_rewards_with_high_value_stat = mod:get("keep_gadget_rewards_with_high_value_stat")
    end
end

mod._update_cached_settings()

function mod.on_setting_changed(setting_id)
    mod._update_cached_settings(setting_id)
end

function mod._echo(message)
    if mod.auto_discard_mission_reward_echoes_enabled then
        mod:echo(message)
    end
end

function mod._resolve_item_loc_key(item)
    if type(item) ~= "table" then
        return "n/a", "n/a"
    end

    local loc_key = item.display_name

    if not is_loc_key(loc_key) then
        loc_key = nil
    end

    local weapon_family_display_name = item.weapon_family_display_name
    if not loc_key and type(weapon_family_display_name) == "table" and is_loc_key(weapon_family_display_name.loc_id) then
        loc_key = weapon_family_display_name.loc_id
    end

    local weapon_pattern_display_name = item.weapon_pattern_display_name
    if not loc_key and type(weapon_pattern_display_name) == "table" and is_loc_key(weapon_pattern_display_name.loc_id) then
        loc_key = weapon_pattern_display_name.loc_id
    end

    local weapon_mark_display_name = item.weapon_mark_display_name
    if not loc_key and type(weapon_mark_display_name) == "table" and is_loc_key(weapon_mark_display_name.loc_id) then
        loc_key = weapon_mark_display_name.loc_id
    end

    if not loc_key and is_loc_key(item.description) then
        loc_key = item.description
    end

    if not loc_key then
        return "n/a", "n/a"
    end

    return loc_key, Localize(loc_key)
end

function mod._is_weapon_item_type(item_type)
    return item_type == "WEAPON_MELEE"
        or item_type == "WEAPON_RANGED"
end

function mod._is_allowed_auto_discard_item_type(item_type)
    return mod._is_weapon_item_type(item_type)
        or item_type == "GADGET"
end

function mod._item_equipped_in_loadout(loadout, item)
    if not loadout or not item or type(item.slots) ~= "table" then
        return false
    end

    local gear_id = item.gear_id

    if not gear_id then
        return false
    end

    for _, slot_name in ipairs(item.slots) do
        local slot_item = loadout[slot_name]

        if slot_item then
            if type(slot_item) == "string" then
                if slot_item == gear_id then
                    return true
                end
            elseif slot_item.gear_id == gear_id then
                return true
            end
        end
    end

    return false
end

function mod._item_equipped_in_any_loadout(item)
    local player_manager = Managers.player
    local player = player_manager and player_manager:local_player_safe(1)
    local profile = player and player:profile()
    local current_loadout = profile and profile.loadout

    if mod._item_equipped_in_loadout(current_loadout, item) then
        return true
    end

    local presets = ProfileUtils.get_profile_presets()

    if presets and #presets > 0 then
        for _, preset in ipairs(presets) do
            if mod._item_equipped_in_loadout(preset.loadout, item) then
                return true
            end
        end
    end

    return false
end

function mod._is_mission_weapon_drop_reward(reward_card, reward)
    if type(reward_card) ~= "table" or type(reward) ~= "table" then
        return false
    end

    local reward_type = reward.reward_type or reward.rewardType

    return reward_card.kind == "weaponDrop"
        and reward.source == "weaponDrop"
        and reward_type == "gear"
end

function mod._queue_auto_discard_reward(reward, master_item, loc_key)
    if not mod.auto_discard_mission_rewards_enabled then
        return
    end

    if type(reward) ~= "table" or type(master_item) ~= "table" then
        return
    end

    local gear_id = reward.gear_id or reward.gearId
    local master_id = reward.master_id or reward.masterId
    local item_type = master_item.item_type

    if not gear_id or not master_id then
        return
    end

    if mod._pending_discard_seen[gear_id] then
        return
    end

    if not mod._is_allowed_auto_discard_item_type(item_type) then
        return
    end

    mod._pending_discard_rewards[#mod._pending_discard_rewards + 1] = {
        gear_id = gear_id,
        master_id = master_id,
        item_type = item_type,
        slots = master_item.slots,
        loc_key = loc_key or "n/a",
        master_item = master_item,
        mission_reward = true,
        tries = 0,
        next_try = (mod._time or 0) + DISCARD_RETRY_DELAY,
    }

    mod._pending_discard_seen[gear_id] = true
end

function mod._remove_pending_discard(index)
    local pending = mod._pending_discard_rewards[index]

    if pending and pending.gear_id then
        mod._pending_discard_seen[pending.gear_id] = nil
    end

    table_remove(mod._pending_discard_rewards, index)
end

function mod._skip_auto_discard(candidate, reason)
    mod._echo(
        string_format(
            "Mission reward auto-discard skipped: gear_id=%s | master_id=%s | loc_key=%s | reason=%s",
            tostring(candidate and candidate.gear_id),
            tostring(candidate and candidate.master_id),
            tostring(candidate and candidate.loc_key),
            tostring(reason)
        )
    )
end

function mod._candidate_needs_item_data(candidate)
    if type(candidate) ~= "table" then
        return false
    end

    if mod.keep_weapon_rewards_with_max_stat_60 and mod._is_weapon_item_type(candidate.item_type) then
        return true
    end

    if mod.keep_gadget_rewards_with_high_value_stat and candidate.item_type == "GADGET" then
        return true
    end

    return false
end

function mod._find_cached_candidate_item(candidate)
    if type(candidate) ~= "table" or not candidate.gear_id then
        return nil
    end

    local gear_service = Managers.data_service and Managers.data_service.gear
    local cached_gear_list = gear_service and gear_service._cached_gear_list

    if type(cached_gear_list) ~= "table" then
        return nil
    end

    local gear = cached_gear_list[candidate.gear_id]

    if not gear then
        for cached_gear_id, cached_gear in pairs(cached_gear_list) do
            if cached_gear_id == candidate.gear_id or cached_gear and cached_gear.uuid == candidate.gear_id then
                gear = cached_gear
                break
            end
        end
    end

    if not gear then
        return nil
    end

    return MasterItems.get_item_instance(gear, candidate.gear_id)
end

function mod._request_candidate_item(candidate)
    if type(candidate) ~= "table" or candidate.item_fetch_pending then
        return
    end

    local gear_service = Managers.data_service and Managers.data_service.gear

    if not gear_service or type(gear_service.fetch_gear) ~= "function" then
        return
    end

    candidate.item_fetch_pending = true

    gear_service:fetch_gear():next(function(gear_list)
        candidate.item_fetch_pending = false

        local gear = gear_list and candidate.gear_id and gear_list[candidate.gear_id]

        if not gear and type(gear_list) == "table" then
            for gear_id, gear_data in pairs(gear_list) do
                if gear_id == candidate.gear_id or gear_data and gear_data.uuid == candidate.gear_id then
                    gear = gear_data
                    break
                end
            end
        end

        if gear then
            candidate.item = MasterItems.get_item_instance(gear, candidate.gear_id)
        end

        candidate.next_try = (mod._time or 0) + DISCARD_RETRY_DELAY
    end):catch(function()
        candidate.item_fetch_pending = false
        candidate.next_try = (mod._time or 0) + DISCARD_RETRY_DELAY
    end)
end

function mod._resolve_auto_discard_candidate_item(candidate)
    if type(candidate) ~= "table" then
        return nil
    end

    if type(candidate.item) == "table" then
        return candidate.item
    end

    local cached_item = mod._find_cached_candidate_item(candidate)

    if cached_item then
        candidate.item = cached_item
        return cached_item
    end

    if candidate.item_fetch_pending then
        return nil
    end

    mod._request_candidate_item(candidate)

    return nil
end

function mod._weapon_reward_has_max_stat_60(item)
    if type(item) ~= "table" or not mod._is_weapon_item_type(item.item_type) then
        return false
    end

    local weapon_stats = WeaponStats:new(item)
    local comparing_stats = weapon_stats:get_comparing_stats()

    if type(comparing_stats) ~= "table" or #comparing_stats ~= 5 then
        return false
    end

    local max_stats = Items.preview_stats_change(item, Items.max_expertise_level(), comparing_stats)

    if type(max_stats) ~= "table" then
        return false
    end

    for i = 1, #comparing_stats do
        local stat_data = comparing_stats[i]
        local max_stat = stat_data and max_stats[stat_data.display_name]

        if max_stat and max_stat.value <= 60.5 then
            return true
        end
    end

    return false
end

function mod._id_contains(value, needle)
    return type(value) == "string" and string_find(value, needle, 1, true) ~= nil
end

function mod._trait_id(trait)
    if type(trait) ~= "table" then
        return trait
    end

    return trait.id
        or trait.name
        or trait.trait
        or trait.trait_id
        or trait.master_id
        or trait.masterId
end

function mod._trait_value(trait)
    if type(trait) ~= "table" then
        return 0
    end

    return tonumber(trait.value or trait.lerp_value or trait.lerpValue) or 0
end

function mod._gadget_stamina_value(trait_value)
    local index = math_round(math_lerp(1, 3, trait_value or 0))

    if index < 1 then
        return 1
    end

    if index > 3 then
        return 3
    end

    return index
end

function mod._gadget_health_bonus(trait_value)
    return math_round_with_precision(math_lerp(0.05, 0.25, trait_value or 0), 2)
end

function mod._gadget_toughness_bonus(trait_value)
    return math_round_with_precision(math_lerp(0.05, 0.2, trait_value or 0), 2)
end

function mod._gadget_reward_has_high_value_stat(item)
    if type(item) ~= "table" or item.item_type ~= "GADGET" then
        return false
    end

    local expertise_level_text = Items.expertise_level(item, true, true)
    local expertise_level = tonumber(expertise_level_text) or 0

    if expertise_level < GADGET_EXPERTISE_KEEP_THRESHOLD then
        return false
    end

    local traits = item.traits

    if type(traits) ~= "table" then
        return false
    end

    for i = 1, #traits do
        local trait = traits[i]
        local trait_id = mod._trait_id(trait)
        local trait_value = mod._trait_value(trait)

        if mod._id_contains(trait_id, "gadget_stamina_increase")
            and mod._gadget_stamina_value(trait_value) >= GADGET_STAMINA_KEEP_THRESHOLD then
            return true
        end

        if mod._id_contains(trait_id, "gadget_innate_health_increase")
            and mod._gadget_health_bonus(trait_value) >= GADGET_HEALTH_KEEP_THRESHOLD then
            return true
        end

        if mod._id_contains(trait_id, "gadget_innate_toughness_increase")
            and mod._gadget_toughness_bonus(trait_value) >= GADGET_TOUGHNESS_KEEP_THRESHOLD then
            return true
        end
    end

    return false
end

function mod._evaluate_auto_discard_candidate(candidate)
    if type(candidate) ~= "table" then
        return false, "missing-candidate", false
    end

    if candidate.mission_reward ~= true then
        return false, "not-mission-reward", false
    end

    local gear_id = candidate.gear_id

    if not gear_id then
        return false, "missing-gear-id", false
    end

    if not mod._is_allowed_auto_discard_item_type(candidate.item_type) then
        return false, "unsupported-item-type", false
    end

    if type(candidate.slots) ~= "table" then
        return false, "missing-slots", false
    end

    if type(Items.is_item_id_favorited) ~= "function" then
        return false, "favorite-check-unavailable", false
    end

    if Items.is_item_id_favorited(gear_id) then
        return false, "favorited", false
    end

    if mod._item_equipped_in_any_loadout(candidate) then
        return false, "equipped-in-loadout", false
    end

    if mod._candidate_needs_item_data(candidate) then
        local item = mod._resolve_auto_discard_candidate_item(candidate)

        if not item then
            return false, "item-data-pending", true
        end

        if mod.keep_weapon_rewards_with_max_stat_60
            and mod._is_weapon_item_type(item.item_type or candidate.item_type)
            and mod._weapon_reward_has_max_stat_60(item) then
            return false, "weapon-max-stat-60", false
        end

        if mod.keep_gadget_rewards_with_high_value_stat
            and (item.item_type or candidate.item_type) == "GADGET"
            and mod._gadget_reward_has_high_value_stat(item) then
            return false, "gadget-high-value-stat", false
        end
    end

    return true
end

function mod._format_discard_rewards(result)
    local rewards = result and result.rewards

    if type(rewards) ~= "table" then
        return "none"
    end

    local parts = {}

    for _, reward in ipairs(rewards) do
        local reward_type = reward and reward.type
        local amount = reward and reward.amount

        if reward_type and amount then
            parts[#parts + 1] = string_format("%s: %s", tostring(reward_type), tostring(amount))
        end
    end

    if #parts == 0 then
        for reward_type, amount in pairs(rewards) do
            if reward_type and amount then
                parts[#parts + 1] = string_format("%s: %s", tostring(reward_type), tostring(amount))
            end
        end
    end

    if #parts == 0 then
        return "none"
    end

    return table.concat(parts, ", ")
end

function mod._delete_auto_discard_candidate(candidate)
    local gear_service = Managers.data_service and Managers.data_service.gear

    if not gear_service or type(gear_service.delete_gear) ~= "function" then
        candidate.next_try = (mod._time or 0) + DISCARD_RETRY_DELAY
        return
    end

    local gear_id = candidate.gear_id
    local discard_state = mod._discard_state

    discard_state.pending = true
    discard_state.gear_id = gear_id

    gear_service:delete_gear(gear_id):next(function(result)
        discard_state.pending = false
        discard_state.gear_id = nil

        if type(Items.unmark_item_id_as_new) == "function" then
            Items.unmark_item_id_as_new(gear_id)
        end

        if type(Items.unmark_item_notification_id_as_new) == "function" then
            Items.unmark_item_notification_id_as_new(gear_id)
        end

        if type(gear_service.invalidate_gear_cache) == "function" then
            gear_service:invalidate_gear_cache()
        end

        Managers.event:trigger("event_force_wallet_update")

        local formatted_rewards = mod._format_discard_rewards(result)

        mod._remove_pending_discard(1)

        mod._echo(
            string_format(
                "Mission reward auto-discarded: gear_id=%s | master_id=%s | loc_key=%s | rewards=%s",
                tostring(candidate.gear_id),
                tostring(candidate.master_id),
                tostring(candidate.loc_key),
                tostring(formatted_rewards)
            )
        )
    end):catch(function(error)
        discard_state.pending = false
        discard_state.gear_id = nil

        if candidate.tries >= DISCARD_MAX_TRIES then
            mod._remove_pending_discard(1)

            mod._echo(
                string_format(
                    "Mission reward auto-discard failed: gear_id=%s | master_id=%s | loc_key=%s | error=%s",
                    tostring(candidate.gear_id),
                    tostring(candidate.master_id),
                    tostring(candidate.loc_key),
                    tostring(error)
                )
            )
        else
            candidate.next_try = (mod._time or 0) + DISCARD_RETRY_DELAY
        end
    end)
end

function mod._process_pending_auto_discards()
    if not mod.auto_discard_mission_rewards_enabled then
        if #mod._pending_discard_rewards > 0 then
            table.clear(mod._pending_discard_rewards)
            table.clear(mod._pending_discard_seen)
        end

        return
    end

    if mod._discard_state.pending then
        return
    end

    local candidate = mod._pending_discard_rewards[1]

    if not candidate then
        return
    end

    local now = mod._time or 0

    if now < (candidate.next_try or 0) then
        return
    end

    candidate.tries = (candidate.tries or 0) + 1

    local allowed, reason, retry = mod._evaluate_auto_discard_candidate(candidate)

    if not allowed then
        if retry and candidate.tries < DISCARD_MAX_TRIES then
            candidate.next_try = now + DISCARD_RETRY_DELAY

            return
        end

        mod._remove_pending_discard(1)
        mod._skip_auto_discard(candidate, reason)

        return
    end

    mod._delete_auto_discard_candidate(candidate)
end

function mod._echo_mission_item_reward(reward)
    if type(reward) ~= "table" then
        return
    end

    if not mod.auto_discard_mission_rewards_enabled then
        return
    end

    local gear_id = reward.gear_id or reward.gearId
    local master_id = reward.master_id or reward.masterId

    if not gear_id or not master_id then
        return
    end

    if mod._seen_gear_ids[gear_id] then
        return
    end

    mod._seen_gear_ids[gear_id] = true

    local item = MasterItems.get_item(master_id)
    local loc_key, localized_name = mod._resolve_item_loc_key(item)

    mod._echo(
        string_format(
            "Mission item reward: gear_id=%s | master_id=%s | %s",
            tostring(gear_id),
            tostring(master_id),
            tostring(localized_name)
        )
    )

    mod._queue_auto_discard_reward(reward, item, loc_key)
end

mod:hook("ProgressionManager", "_parse_reward_cards", function(func, self, account_data, item_rewards)
    local result = func(self, account_data, item_rewards)

    if self._session_report_is_dummy then
        return result
    end

    local session_report = self._session_report
    local character_report = session_report and session_report.character
    local reward_cards = character_report and character_report.rewards

    if not reward_cards then
        return result
    end

    for _, reward_card in ipairs(reward_cards) do
        local rewards = reward_card.rewards

        if rewards then
            for _, reward in ipairs(rewards) do
                if mod._is_mission_weapon_drop_reward(reward_card, reward) then
                    mod._echo_mission_item_reward(reward)
                end
            end
        end
    end

    return result
end)

function mod.update(dt)
    mod._time = (mod._time or 0) + (dt or 0)

    mod._process_pending_auto_discards()
end
