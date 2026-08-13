-- File: uptime\scripts\mods\uptime\tracking\uptime_buff_tracking.lua
local mod = get_mod("uptime")
if not mod then
    return
end

local unique_max_stacks = mod:io_dofile("uptime/scripts/mods/uptime/tracking/unique_max_stacks")
local item_lib = mod:io_dofile("uptime/scripts/mods/uptime/libs/items")
local BuffTemplates = mod:original_require("scripts/settings/buff/buff_templates")
local WeaponTraitTemplates = mod:original_require("scripts/settings/equipment/weapon_traits/weapon_trait_templates")
local MasterItems = mod:original_require("scripts/backend/master_items")
local TalentSettings = mod:original_require("scripts/settings/talent/talent_settings")

--[[
    Buff Event Tracking Data Model

    This module implements an event-based tracking system for buffs during missions.

    Data Model:
    1. Mission Data:
       - start_time: When the mission started
       - end_time: When the mission ended
       - combat_sections: Array of {start_time, end_time} for combat sections

    2. Buff Data:
       - icon: Buff icon for UI display
       - gradient_map: Gradient map for UI display
       - stackable: Whether the buff can stack
       - max_stacks: Maximum number of stacks for this buff
       - events: Array of buff events, each containing:
         * type: "add", "remove", or "stack_change"
         * time: When the event occurred
         * stack_count: Current stack count (for "add" and "stack_change" events)

    3. Event Types:
       - "add": Buff was added (became active)
       - "remove": Buff was removed (became inactive)
       - "stack_change": Stack count changed while buff was active

    This event-based approach allows for:
    - Precise tracking of when buffs are active
    - Tracking individual stack changes
    - Calculating uptime and average stacks from event data
    - Supporting future analytics on buff timing and patterns
]]

local tracked_buffs = {}

local displayed_buff_categories = {
    talents = true,
    weapon_traits = true,
    talents_secondary = true,
}

local get_buff_instances_from_hud_element
local update_active_buffs
local update_removed_buffs
local ignore_buff
local get_buff_hud_icon
local is_proc_activity_buff
local get_buff_activity_state
local update_buff
local init_buff
local get_actual_max
local get_optional_item_info
local trait_belongs_to_buff
local finalize_buff_tracking

function mod:start_buff_tracking()
    tracked_buffs = {}
end

function mod:end_buff_tracking(end_time)
    finalize_buff_tracking(end_time)
    return tracked_buffs
end

mod:hook_safe("HudElementPlayerBuffs", "_update_buffs", function(self)
    if not mod:tracking_in_progress() then
        return
    end

    -- Run once from the vanilla player buff HUD element, but do not use its
    -- post-filtered _active_buffs_data as the source of truth.
    --
    -- SBF can hide buffs or move them to custom bars by preventing/marking HUD
    -- entries, so Uptime must read the player's actual buff extension instead.
    if self.__class_name ~= "HudElementPlayerBuffs" or self._filter then
        return
    end

    local buff_instances = get_buff_instances_from_hud_element(self)
    if not buff_instances then
        return
    end

    local now = mod:now()

    local currently_active_buffs = update_active_buffs(tracked_buffs, buff_instances, now)
    update_removed_buffs(tracked_buffs, currently_active_buffs, now)
end)

get_buff_instances_from_hud_element = function(hud_element)
    local parent = hud_element and hud_element._parent
    local player_extensions = parent and parent.player_extensions and parent:player_extensions()
    local buff_extension = player_extensions and player_extensions.buff

    if not buff_extension or not buff_extension.buffs then
        return nil
    end

    return buff_extension:buffs()
end

update_active_buffs = function(tracked_buffs, buff_instances, now)
    local currently_active_buffs = {}

    for i = 1, #buff_instances do
        local buff_instance = buff_instances[i]

        if buff_instance and not ignore_buff(buff_instance) then
            local buff_title = buff_instance:title()

            if buff_title then
                update_buff(tracked_buffs, buff_instance, now)
                currently_active_buffs[buff_title] = true
            end
        end
    end

    return currently_active_buffs
end

update_removed_buffs = function(tracked_buffs, currently_active_buffs, now)
    -- Handle buffs that are no longer active
    for buff_title, buff_data in pairs(tracked_buffs) do
        -- Check if the buff was active but is no longer in the currently active buffs
        if buff_data.is_active and not currently_active_buffs[buff_title] then
            -- Record a remove event
            table.insert(buff_data.events, {
                time = now,
                type = "remove",
            })

            -- Mark the buff as inactive
            tracked_buffs[buff_title].is_active = false
        end
    end
end

ignore_buff = function(buff_instance)
    if not buff_instance then
        return true
    end

    local hud_data = buff_instance.get_hud_data and buff_instance:get_hud_data()
    local buff_template = buff_instance.template and buff_instance:template()

    if not hud_data or not buff_template then
        return true
    end

    local buff_icon = get_buff_hud_icon(buff_instance, buff_template, hud_data)
    local buff_category = buff_template.buff_category
    local wrong_category = not displayed_buff_categories[buff_category]
    local no_icon = not buff_icon
    local no_stacks = buff_instance.visual_stack_count and buff_instance:visual_stack_count() == 0
    local is_debuff = buff_instance.is_negative and buff_instance:is_negative()
    local not_active = not get_buff_activity_state(buff_instance, hud_data, buff_template)

    -- Do not check hud_data.show or HUD-list buff_data.show here.
    -- Those are presentation/filtering state and can be changed by SBF.
    --
    -- Do still require a valid icon, but allow weapon trait buffs to use the
    -- item override icon that Darktide applies at runtime. This keeps the
    -- original protection against internal/passive non-HUD buffs while allowing
    -- weapon traits whose templates do not carry hud_icon directly.
    if wrong_category or no_icon or no_stacks or is_debuff or not_active then
        return true
    end

    return false
end

get_buff_hud_icon = function(buff_instance, buff_template, hud_data)
    if not buff_template then
        return nil
    end

    local icon = buff_template.hud_icon

    if type(icon) == "string" and icon ~= "" then
        return icon
    end

    if buff_template.buff_category ~= "weapon_traits" then
        return nil
    end

    local override_data = buff_instance and buff_instance._template_override_data

    icon = override_data and (override_data.item_icon or override_data.hud_icon)

    if type(icon) == "string" and icon ~= "" then
        return icon
    end

    icon = hud_data and (hud_data.item_icon or hud_data.hud_icon)

    if type(icon) == "string" and icon ~= "" then
        return icon
    end

    return nil
end

is_proc_activity_buff = function(buff_instance, buff_template)
    if not buff_instance or not buff_template then
        return false
    end

    if buff_template.class_name ~= "proc_buff" then
        return false
    end

    if not buff_instance.is_proc_active then
        return false
    end

    -- Timed proc buffs with a normal duration are added/removed as active buff
    -- instances, so ordinary presence/HUD activity tracking is still correct.
    if buff_template.duration then
        return false
    end

    -- Proc buffs with active_duration can remain present in the buff extension
    -- while their actual proc window turns on and off.
    return buff_template.active_duration ~= nil
end

get_buff_activity_state = function(buff_instance, hud_data, buff_template)
    if not hud_data or not hud_data.is_active then
        return false
    end

    -- Keep hud_data.is_active as the first gate so conditional_stat_buffs_func,
    -- conditional_keywords_func, check_active_func, and similar vanilla HUD
    -- activity checks still suppress inactive conditional buffs.
    if is_proc_activity_buff(buff_instance, buff_template) then
        return buff_instance:is_proc_active()
    end

    return true
end

update_buff = function(buffs, buff_instance, now)
    local buff_title = buff_instance:title()
    local stack_count = buff_instance:visual_stack_count()

    -- Initialize buff data if it doesn't exist
    if not buffs[buff_title] then
        buffs[buff_title] = init_buff(buff_instance, stack_count)

        -- Record an add event
        table.insert(buffs[buff_title].events, {
            type = "add",
            time = now,
            stack_count = stack_count
        })

        -- If buff exists but was inactive, mark it as active again
    elseif not buffs[buff_title].is_active then
        buffs[buff_title].is_active = true
        buffs[buff_title].current_stack_count = stack_count

        -- Record an add event
        table.insert(buffs[buff_title].events, {
            type = "add",
            time = now,
            stack_count = stack_count
        })

        -- If stack count changed, record a stack change event
    elseif buffs[buff_title].current_stack_count ~= stack_count then
        table.insert(buffs[buff_title].events, {
            type = "stack_change",
            time = now,
            stack_count = stack_count
        })

        buffs[buff_title].current_stack_count = stack_count
    end

    return true
end

init_buff = function(buff_instance, stack_count)
    local template = buff_instance:template()
    local max_stacks = get_actual_max(buff_instance)

    return {
        name = buff_instance:title(),
        template_name = template.name,
        icon = get_buff_hud_icon(buff_instance, template),
        gradient_map = template.hud_icon_gradient_map,
        stackable = max_stacks > 1,
        max_stacks = max_stacks,
        events = {},
        is_active = true,
        current_stack_count = stack_count,
        category = template.buff_category,
        related_talents = template.related_talents,
        related_item = get_optional_item_info(buff_instance),
    }
end

get_actual_max = function(buff_instance)
    local template = buff_instance:template()

    local unique_max_stack = unique_max_stacks[buff_instance:title()]
    if unique_max_stack then
        return unique_max_stack
    end

    -- some buffs have dynamic max values https://github.com/Aussiemon/Darktide-Source-Code/blob/72cde1c088677d22b3830d9681d015167782b10a/scripts/extension_systems/buff/buffs/stepped_stat_buff.lua#L40-L47
    local min_max_step_func = template.min_max_step_func
    if min_max_step_func then
        local template_data = buff_instance._template_data
        local template_context = buff_instance._template_context
        local _, max_stacks = min_max_step_func(template_data, template_context)

        return max_stacks
    end

    local child_buff_template = template.child_buff_template
    local child_template = BuffTemplates[child_buff_template]
    if child_template then
        -- https://github.com/Aussiemon/Darktide-Source-Code/blob/72cde1c088677d22b3830d9681d015167782b10a/scripts/extension_systems/buff/buffs/parent_proc_buff.lua#L30
        local template_override_data = buff_instance._template_override_data or {}

        return template_override_data.max_stacks or child_template.max_stacks or 1
    end

    return buff_instance:max_stacks() or 1
end

get_optional_item_info = function(buff_instance)
    local context = buff_instance._template_context or {}
    local item = context.source_item or context.item
    local item_slot_name = context.item_slot_name

    if (not item or not item.traits) and item_slot_name then
        local player = context.player
        local profile = player and player.profile and player:profile()
        local loadout = profile and profile.loadout

        item = loadout and loadout[item_slot_name] or item
    end

    if not item or not item.traits then
        return nil
    end

    local buff_template = buff_instance.template and buff_instance:template()
    local buff_template_name = buff_template and buff_template.name or buff_instance:title()
    local parent_buff_template = context.parent_buff_template
    local parent_buff_template_name = type(parent_buff_template) == "table" and parent_buff_template.name or
        parent_buff_template
    local blessing

    for _, trait in pairs(item.traits) do
        local trait_item = MasterItems.get_item(trait.id)
        local trait_name = trait_item and trait_item.trait
        local trait_definition = trait_name and WeaponTraitTemplates[trait_name]

        if trait_definition and
            (trait_belongs_to_buff(trait_definition, buff_template_name) or
                trait_belongs_to_buff(trait_definition, parent_buff_template_name)) then
            blessing = {
                name = item_lib.get_blessing_name(trait),
                description = item_lib.get_blessing_description(trait)
            }

            break
        end
    end

    return {
        name = item_lib.get_name(item),
        blessing = blessing
    }
end

trait_belongs_to_buff = function(trait_definition, buff_title)
    if not trait_definition or not buff_title then
        return false
    end

    local buffs = trait_definition.buffs

    if buffs and buffs[buff_title] then
        return true
    end

    local format_values = trait_definition.format_values

    if not format_values then
        return false
    end

    -- data structure reference:
    -- https://github.com/Aussiemon/Darktide-Source-Code/blob/72cde1c088677d22b3830d9681d015167782b10a/scripts/settings/equipment/weapon_traits/weapon_traits_bespoke_ogryn_combatblade_p1.lua#L66
    for _, entry in pairs(format_values) do
        if entry.find_value then
            if entry.find_value.buff_template_name == buff_title then
                return true
            end
        end
    end

    return false
end

finalize_buff_tracking = function(tracking_end_time)
    for buff_name, buff_data in pairs(tracked_buffs) do
        -- If the buff is still active at the end of tracking, add a remove event
        if buff_data.is_active then
            table.insert(buff_data.events, {
                type = "remove",
                time = tracking_end_time
            })

            buff_data.is_active = false
        end
    end
end
