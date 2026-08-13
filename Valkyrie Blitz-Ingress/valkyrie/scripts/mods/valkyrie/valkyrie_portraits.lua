-- valkyrie_portraits.lua
local PORTRAIT_SIZE = { 128, 192 }
local PORTRAIT_CAMERA_FOCUS_SLOT = "slot_gear_head"
local M = {}
function M.clone_profile(profile)
if not profile then
return nil
end
if table and table.clone_instance then
local ok, clone = pcall(table.clone_instance, profile)
if ok and clone then
return clone
end
end
if table and table.clone then
local ok, clone = pcall(table.clone, profile)
if ok and clone then
return clone
end
end
local clone = {}
for key, value in pairs(profile) do
clone[key] = value
end
return clone
end
function M.request_profile(profile)
local request_profile = M.clone_profile(profile)
if not request_profile then
return nil
end
local character_id = profile.character_id or profile.identifier or tostring(profile)
request_profile.character_id = tostring(character_id) .. "_valkyrie_business_card_portrait"
local loadout = request_profile.loadout
if loadout then
local loadout_copy = {}
for key, value in pairs(loadout) do
loadout_copy[key] = value
end
loadout_copy.slot_animation_end_of_round = nil
request_profile.loadout = loadout_copy
end
return request_profile
end
function M.render_context()
return {
camera_focus_slot_name = PORTRAIT_CAMERA_FOCUS_SLOT,
size = { PORTRAIT_SIZE[1], PORTRAIT_SIZE[2] },
ignore_companion = true,
}
end
function M.load_profile_portrait(profile, on_load_callback, on_unload_callback)
if not profile or not Managers or not Managers.ui or not Managers.ui.load_profile_portrait then
return nil
end
local request_profile = M.request_profile(profile)
if not request_profile then
return nil
end
local ok, load_id = pcall(Managers.ui.load_profile_portrait, Managers.ui, request_profile, on_load_callback, M.render_context(), on_unload_callback)
if ok then
return load_id
end
return nil
end
function M.unload_profile_portrait(load_id)
if load_id and Managers and Managers.ui and Managers.ui.unload_profile_portrait then
pcall(Managers.ui.unload_profile_portrait, Managers.ui, load_id)
end
end
return M
