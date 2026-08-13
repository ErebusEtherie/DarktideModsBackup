-- valkyrie_extra_bots.lua
local M = {}
function M.init(ctx)
local ProfileUtils = ctx.ProfileUtils
local fallback_intro_bots = {}
local function fallback_bot_player(index)
local cached = fallback_intro_bots[index]
if cached then
return cached
end
local profile_name = "bot_" .. tostring(index)
local ok, profile = pcall(ProfileUtils.get_bot_profile, profile_name)
if not ok or not profile then
return nil
end
profile.identifier = profile.identifier or profile_name
local player = {}
function player:unique_id()
return "valkyrie_intro_" .. profile_name
end
function player:profile()
return profile
end
function player:slot()
return 1000 + index
end
function player:is_human_controlled()
return false
end
function player:breed_name()
local archetype = profile.archetype
return archetype and archetype.breed or "human"
end
fallback_intro_bots[index] = player
return player
end
function M.collect_real_bot_intro_players(player_manager)
if not ctx.should_show_bots() or not player_manager.bot_players then
return
end
local bot_players = player_manager:bot_players()
for unique_id, player in pairs(bot_players) do
if #ctx.temp_sorted_players >= ctx.max_occupants then
return
end
if ctx.should_show_player_in_intro(player) then
ctx.add_intro_player(ctx.temp_sorted_players, ctx.temp_seen_players, player, unique_id)
end
end
end
function M.fill_intro_with_fallback_bots()
if not ctx.should_show_bots() then
return
end
local index = 1
while #ctx.temp_sorted_players < ctx.max_occupants and index <= ctx.max_occupants do
local player = fallback_bot_player(index)
if player then
ctx.add_intro_player(ctx.temp_sorted_players, ctx.temp_seen_players, player)
end
index = index + 1
end
end
return M
end
return M
