local mod = get_mod("uptime")
local ItemUtils = mod:original_require("scripts/utilities/items")
local MasterItems = mod:original_require("scripts/backend/master_items")

function is_weapon(item)
    return ItemUtils.is_weapon(item)
end

function get_item_name(item)
    return ItemUtils.display_name(item)
end

function get_blessing_name(trait)
    if trait then
        local trait_id = trait.id
        local trait_item = MasterItems.get_item(trait_id)
        local desc = Localize(trait_item.display_name)
        -- local desc2 = Localize(trait_item.description, true, {power_level=1,time=2,stacks=3})
        return desc
    end
end
function get_blessing_description(trait)
    if trait then
        local trait_item = MasterItems.get_item(trait.id)
        return ItemUtils.trait_description(trait_item, trait.rarity or 4, 0)
    end
end

mod.items = {
    is_weapon = is_weapon,
    get_name = get_item_name,
    get_blessing_name = get_blessing_name,
    get_blessing_description = get_blessing_description,
}

return mod.items