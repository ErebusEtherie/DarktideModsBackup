-- valkyrie_no_uniforms.lua
local no_uniform_slots = {
slot_gear_upperbody = "content/items/characters/player/human/gear_upperbody/empty_upperbody",
slot_gear_lowerbody = "content/items/characters/player/human/gear_lowerbody/empty_lowerbody",
slot_gear_head = "content/items/characters/player/human/gear_head/empty_headgear",
slot_gear_extra_cosmetic = "content/items/characters/player/human/backpacks/empty_backpack",
}
local M = {}
function M.init(ctx)
local MasterItems = ctx.MasterItems
local empty_uniform_items = {}
local no_uniform_profile_cache = setmetatable({}, { __mode = "k" })
local function empty_uniform_item(slot_name)
if empty_uniform_items[slot_name] ~= nil then
return empty_uniform_items[slot_name]
end
local item_path = no_uniform_slots[slot_name]
local item = item_path and MasterItems.get_item(item_path)
empty_uniform_items[slot_name] = item
return item
end
local function clone_table(source)
local clone = {}
if source then
for key, value in pairs(source) do
clone[key] = value
end
end
return clone
end
function M.clear_cache()
table.clear(no_uniform_profile_cache)
end
function M.profile(profile)
if not profile then
return profile
end
local cached = no_uniform_profile_cache[profile]
if cached then
return cached
end
local new_profile = table.clone_instance(profile)
new_profile.loadout = clone_table(profile.loadout)
new_profile.visual_loadout = clone_table(profile.visual_loadout)
new_profile.loadout_item_ids = clone_table(profile.loadout_item_ids)
new_profile.loadout_item_data = clone_table(profile.loadout_item_data)
for slot_name, _ in pairs(no_uniform_slots) do
local item = empty_uniform_item(slot_name)
if item then
new_profile.loadout[slot_name] = item
new_profile.visual_loadout[slot_name] = item
if new_profile.loadout_item_ids then
new_profile.loadout_item_ids[slot_name] = item.name .. slot_name
end
if new_profile.loadout_item_data then
new_profile.loadout_item_data[slot_name] = { id = item.name }
end
end
end
no_uniform_profile_cache[profile] = new_profile
return new_profile
end
function M.add_changed_items(changed_items, visual_loadout)
local changed_clone = clone_table(changed_items)
local visual_clone = clone_table(visual_loadout)
for slot_name, _ in pairs(no_uniform_slots) do
local item = empty_uniform_item(slot_name)
if item then
changed_clone[slot_name] = item
visual_clone[slot_name] = item
end
end
return changed_clone, visual_clone
end
return M
end
return M
