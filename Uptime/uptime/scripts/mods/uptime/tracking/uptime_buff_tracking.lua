local mod = get_mod("uptime")
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

    local active_buffs_data = self._active_buffs_data
    local now = mod:now()

    local currently_active_buffs = update_active_buffs(tracked_buffs, active_buffs_data, now)
    update_removed_buffs(tracked_buffs, currently_active_buffs, now)
end)

function update_active_buffs(tracked_buffs, active_buffs_data, now)
    local currently_active_buffs = {}

    -- Process all active buffs
    for i = 1, #active_buffs_data do
        local buff_data = active_buffs_data[i]
        local buff_instance = buff_data.buff_instance
        if not buff_data.remove and buff_instance then
            local ignore = ignore_buff(buff_data)
            local buff_title = buff_instance:title()
            if (not ignore) then
                update_buff(tracked_buffs, buff_instance, now)
                currently_active_buffs[buff_title] = true
            end
        end
    end
    return currently_active_buffs
end

function update_removed_buffs(tracked_buffs, currently_active_buffs, now)
    -- Handle buffs that are no longer active
    for buff_title, buff_data in pairs(tracked_buffs) do
        -- Check if the buff was active but is no longer in the currently active buffs
        if buff_data.is_active and not currently_active_buffs[buff_title] then
            -- Record a remove event
            table.insert(buff_data.events, {
                type = "remove",
                time = now
            })

            -- Mark the buff as inactive
            tracked_buffs[buff_title].is_active = false
        end
    end
end

function ignore_buff(buff_data)
    local buff_instance = buff_data.buff_instance
    local hud_data = buff_instance:get_hud_data()
    local buff_template = buff_instance:template()

    local buff_category = buff_template.buff_category
    local wrong_category = not displayed_buff_categories[buff_category]
    local no_stacks = buff_instance:visual_stack_count() == 0
    local is_debuff = buff_instance:is_negative()
    local not_shown = not buff_data.show
    local not_active = not hud_data.is_active
    if (wrong_category or no_stacks or is_debuff or not_shown or not_active) then
        return true
    end
    return false
end

function update_buff(buffs, buff_instance, now)
    local buff_title = buff_instance:title()
    local stack_count = buff_instance:visual_stack_count()

    -- Initialize buff data if it doesn't exist
    if not buffs[buff_title] then
        buffs[buff_title] = init_buff(buff_instance)
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

function init_buff(buff_instance)
    local template = buff_instance:template()

    local max_stacks = get_actual_max(buff_instance)

    return {
        name = buff_instance:title(),
        icon = buff_instance:_hud_icon(),
        gradient_map = buff_instance:hud_icon_gradient_map(),
        stackable = max_stacks > 1,
        max_stacks = max_stacks,
        events = {},
        is_active = true,
        current_stack_count = stack_count,
        category = template.buff_category,
        related_talents = template.related_talents,
        related_item = get_optional_item_info(buff_instance),
        instance = buff_instance
    }
end

function get_actual_max(buff_instance)
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
        return (buff_instance._template_override_data.max_stacks or child_template.max_stacks or 1)
    end

    return buff_instance:max_stacks() or 1
end

function get_optional_item_info(buff_instance)
    local context = (buff_instance._template_context or {})
    local item = context.source_item or context.item
    if not item then
        mod.buffs_without_item = mod.buffs_without_item or {}
        mod.buffs_without_item[#mod.buffs_without_item + 1] = buff_instance
        return nil
    end
    mod.buffs_with_item = mod.buffs_with_item or {}
    mod.buffs_with_item[#mod.buffs_with_item + 1] = buff_instance
    local blessing
    for _, trait in pairs(item.traits) do
        local trait_item = MasterItems.get_item(trait.id)
        local trait_name = trait_item.trait
        local trait_definition = WeaponTraitTemplates[trait_name]
        if trait_definition and trait_belongs_to_buff(trait_definition, buff_instance:title()) then
            blessing = {
                name = item_lib.get_blessing_name(trait),
                description = item_lib.get_blessing_description(trait)
            }
        end
    end
    return {
        name = item_lib.get_name(item),
        blessing = blessing
    }
end

function trait_belongs_to_buff(trait_definition, buff_title)
    -- data structure reference:
    -- https://github.com/Aussiemon/Darktide-Source-Code/blob/72cde1c088677d22b3830d9681d015167782b10a/scripts/settings/equipment/weapon_traits/weapon_traits_bespoke_ogryn_combatblade_p1.lua#L66
    for _, entry in pairs(trait_definition.format_values) do
        if entry.find_value then
            if entry.find_value.buff_template_name == buff_title then
                return true
            end
        end
    end
    return false
end

function finalize_buff_tracking(tracking_end_time)
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