-- Ammonia.lua
local mod = get_mod and get_mod("Ammonia")
if not mod then
return
end
local dmf = get_mod and get_mod("DMF")
local state = mod:persistent_table("state", {
counts = {},
})
if type(state.counts) ~= "table" then
state.counts = {}
end
local SUPPRESSION_SETTING_ID = "suppression"
local SCORE_COLOUR_TAG = "{#color(236,192,131)}"
local SCORE_HEADING_TAG = "{#size(23);color(236,192,131)}"
local SCORE_RESET_TAG = "{#reset()}"
local AMMO_HOG_RESPONSE_BLOCK_DURATION = 12
local AMMO_HOG_RESPONSE_EVENT_NAMES = {
combat_pause_quirk_ammo_hog = true,
}
local AMMO_CHAT_TERMS = {
"ammo",
"ammunition",
"munitions",
"out of rounds",
"need rounds",
"low on rounds",
"rounds left",
"bullets",
"cartridges",
}
local PING_ITEM_TAGS = {
pup_ammo = true,
pup_deployed_ammo_crate = true,
ammo = true,
}
local SCORE_ROWS = {
{
label = "Chat",
counter_id = "chat",
},
{
label = "Voice - need ammo",
counter_id = "voice_need_ammo",
},
{
label = "Voice - out of ammo",
counter_id = "voice_out_of_ammo",
},
{
label = "Voice - ammo hog",
counter_id = "voice_ammo_hog",
},
}
local SCORE_FILE_NAME = "ammonia.txt"
local LEGACY_SCORE_FILE_NAME = "ammonia_scores.txt"
local SCORE_DIRECTORY_NAME = "Ammonia"
local SCORE_FILE_DIRECTORY
local SCORE_FILE_PATH
local io_lib
local os_lib
local score_file_dirty = false
local score_directory_ready = false
local score_file_loaded = false
local function initialise_lib(lib_name)
if not Mods or not Mods.lua or type(Mods.lua[lib_name]) ~= "table" then
return nil
end
if dmf and dmf.deepcopy then
local ok, copy = pcall(dmf.deepcopy, Mods.lua[lib_name])
if ok and type(copy) == "table" then
return copy
end
end
return Mods.lua[lib_name]
end
local function initialise_score_file_access()
if io_lib and os_lib and SCORE_FILE_PATH then
return true
end
io_lib = io_lib or initialise_lib("io")
os_lib = os_lib or initialise_lib("os")
if type(io_lib) ~= "table" or type(os_lib) ~= "table" or not os_lib.getenv then
return false
end
local ok, appdata = pcall(os_lib.getenv, "APPDATA")
if not ok or type(appdata) ~= "string" or appdata == "" then
return false
end
SCORE_FILE_DIRECTORY = appdata .. "/Fatshark/Darktide/" .. SCORE_DIRECTORY_NAME
SCORE_FILE_PATH = SCORE_FILE_DIRECTORY .. "/" .. SCORE_FILE_NAME
return true
end
local function valid_counter_id(counter_id)
for i = 1, #SCORE_ROWS do
if SCORE_ROWS[i].counter_id == counter_id then
return true
end
end
return false
end
local function normalise_counts()
if type(state.counts) ~= "table" then
state.counts = {}
end
for i = 1, #SCORE_ROWS do
local counter_id = SCORE_ROWS[i].counter_id
local value = tonumber(state.counts[counter_id]) or 0
if value < 0 then
value = 0
end
state.counts[counter_id] = math.floor(value)
end
end
local function total_score_count()
normalise_counts()
local total = 0
for i = 1, #SCORE_ROWS do
local counter_id = SCORE_ROWS[i].counter_id
total = total + (state.counts[counter_id] or 0)
end
return total
end
local function ensure_score_directory()
if score_directory_ready then
return true
end
if not initialise_score_file_access() or not os_lib.execute then
return false
end
local ok = pcall(os_lib.execute, string.format('mkdir "%s"', SCORE_FILE_DIRECTORY))
if ok then
score_directory_ready = true
end
return ok
end
local function mark_score_file_dirty()
score_file_dirty = true
end
local function read_score_file(path)
if not initialise_score_file_access() or not io_lib.open then
return false
end
local ok, file = pcall(io_lib.open, path or SCORE_FILE_PATH, "r")
if not ok or not file then
return false
end
local counts = {}
local read_ok = pcall(function()
for line in file:lines() do
local counter_id, value = string.match(line, "^([%w_]+)%s*=%s*(%-?%d+)")
if counter_id and valid_counter_id(counter_id) then
counts[counter_id] = tonumber(value) or 0
end
end
end)
pcall(file.close, file)
if not read_ok then
return false
end
state.counts = counts
normalise_counts()
return true
end
local function write_score_file(force)
if not force and not score_file_dirty then
return true
end
normalise_counts()
if not initialise_score_file_access() or not io_lib.open then
return false
end
if not ensure_score_directory() then
return false
end
local ok, file = pcall(io_lib.open, SCORE_FILE_PATH, "w")
if not ok or not file then
return false
end
local write_ok = pcall(function()
for i = 1, #SCORE_ROWS do
local counter_id = SCORE_ROWS[i].counter_id
file:write(counter_id .. "=" .. tostring(state.counts[counter_id] or 0) .. "\n")
end
end)
local close_ok = pcall(file.close, file)
local success = write_ok and close_ok
if success then
score_file_dirty = false
end
return success
end
local function load_score_file()
if read_score_file() then
score_file_loaded = true
return
end
local legacy_path = SCORE_FILE_DIRECTORY and SCORE_FILE_DIRECTORY .. "/" .. LEGACY_SCORE_FILE_NAME
if legacy_path and read_score_file(legacy_path) then
score_file_loaded = true
mark_score_file_dirty()
return
end
normalise_counts()
score_file_loaded = true
if total_score_count() > 0 then
mark_score_file_dirty()
end
end
load_score_file()
local runtime = {
local_ammo_hog_response_block_until = 0,
}
local function mod_enabled()
if not mod.is_enabled then
return true
end
local ok, enabled = pcall(mod.is_enabled, mod)
return not ok or enabled ~= false
end
local function suppression_enabled()
if not mod_enabled() then
return false
end
if not mod.get then
return true
end
local ok, enabled = pcall(mod.get, mod, SUPPRESSION_SETTING_ID)
return not ok or enabled ~= false
end
local function reset_defaults()
if mod.set then
pcall(mod.set, mod, SUPPRESSION_SETTING_ID, true, true)
end
end
local function count_suppressed(counter_id)
if not valid_counter_id(counter_id) then
return
end
if type(state.counts) ~= "table" then
state.counts = {}
end
local value = tonumber(state.counts[counter_id]) or 0
if value < 0 then
value = 0
end
state.counts[counter_id] = math.floor(value) + 1
mark_score_file_dirty()
end
local function current_time()
local time_manager = Managers and Managers.time
if time_manager and time_manager.time then
local ok, t = pcall(time_manager.time, time_manager, "main")
if ok and type(t) == "number" then
return t
end
ok, t = pcall(time_manager.time, time_manager, "gameplay")
if ok and type(t) == "number" then
return t
end
end
return os.clock and os.clock() or 0
end
local function arm_local_ammo_hog_response_block()
runtime.local_ammo_hog_response_block_until = current_time() + AMMO_HOG_RESPONSE_BLOCK_DURATION
end
local function local_ammo_hog_response_block_active()
return runtime.local_ammo_hog_response_block_until > current_time()
end
local function count_voice_suppressed(counter_id)
if counter_id == "voice_ammo_hog" then
arm_local_ammo_hog_response_block()
end
count_suppressed(counter_id)
end
local function counter_value(counter_id)
return state.counts[counter_id] or 0
end
local function score_block_text()
local lines = {
"",
"",
"",
"",
"",
SCORE_HEADING_TAG .. mod:localize("score_table_heading") .. SCORE_RESET_TAG,
mod:localize("score_table_title"),
"",
}
for i = 1, #SCORE_ROWS do
local row = SCORE_ROWS[i]
lines[#lines + 1] = row.label
lines[#lines + 1] = SCORE_COLOUR_TAG .. tostring(counter_value(row.counter_id)) .. SCORE_RESET_TAG
lines[#lines + 1] = ""
end
return table.concat(lines, "\n")
end
local function text_mentions_ammo(text)
if type(text) ~= "string" then
return false
end
local lower = string.lower(text)
for i = 1, #AMMO_CHAT_TERMS do
if string.find(lower, AMMO_CHAT_TERMS[i], 1, true) then
return true
end
end
return false
end
local VANILLA_NEED_AMMO_LOC_KEY = "loc_communication_wheel_need_ammo"
local function text_is_ammo_chat_callout(text)
if type(text) ~= "string" then
return false
end
if string.find(text, VANILLA_NEED_AMMO_LOC_KEY, 1, true) or text_mentions_ammo(text) then
return true
end
if Localize then
local ok, localized_text = pcall(Localize, VANILLA_NEED_AMMO_LOC_KEY)
if ok and type(localized_text) == "string" and text == localized_text then
return true
end
end
return false
end
local function local_chat_sender_state(chat_element, sender, channel)
if type(sender) ~= "string" or type(channel) ~= "table" or not channel.tag then
return nil
end
local localization_manager = Managers and Managers.localization
if not chat_element or not chat_element._channel_name or not localization_manager or not localization_manager.localize then
return nil
end
local ok_channel, channel_name = pcall(chat_element._channel_name, chat_element, channel.tag, false, channel.channel_name)
if not ok_channel or type(channel_name) ~= "string" then
return nil
end
local ok_sender, local_sender = pcall(localization_manager.localize, localization_manager, "loc_chat_own_player", true, {
channel_name = channel_name,
})
if not ok_sender or type(local_sender) ~= "string" then
return nil
end
return sender == local_sender
end
local function safe_peer_id(player)
if not player or not player.peer_id then
return nil
end
local ok, peer_id = pcall(player.peer_id, player)
return ok and peer_id or nil
end
local function safe_unique_id(player)
if not player or not player.unique_id then
return nil
end
local ok, unique_id = pcall(player.unique_id, player)
return ok and unique_id or nil
end
local function safe_unit_alive(unit)
if not unit then
return false
end
if ALIVE and ALIVE[unit] then
return true
end
if Unit and Unit.alive then
local ok, alive = pcall(Unit.alive, unit)
return ok and alive or false
end
return false
end
local function owner_for_unit(unit)
if not safe_unit_alive(unit) then
return nil
end
local state_managers = Managers and Managers.state
local player_unit_spawn = state_managers and state_managers.player_unit_spawn
if not player_unit_spawn or not player_unit_spawn.owner then
return nil
end
local ok, owner = pcall(player_unit_spawn.owner, player_unit_spawn, unit)
return ok and owner or nil
end
local function local_player()
local player_manager = Managers and Managers.player
if not player_manager or not player_manager.local_player then
return nil
end
local ok, player = pcall(player_manager.local_player, player_manager, 1)
return ok and player or nil
end
local function unit_is_local_player(unit, dialogue_system)
if not safe_unit_alive(unit) then
return false
end
local extension = dialogue_system and dialogue_system._unit_to_extension_map and dialogue_system._unit_to_extension_map[unit]
if extension and extension.get_context then
local ok, context = pcall(extension.get_context, extension)
if ok and context and context.is_local_player == true then
return true
end
end
local owner = owner_for_unit(unit)
if not owner then
return false
end
local player = local_player()
if owner == player then
return true
end
local owner_peer_id = safe_peer_id(owner)
local local_peer_id = safe_peer_id(player)
if owner_peer_id and local_peer_id and owner_peer_id == local_peer_id then
return true
end
local owner_unique_id = safe_unique_id(owner)
local local_unique_id = safe_unique_id(player)
if owner_unique_id and local_unique_id and owner_unique_id == local_unique_id then
return true
end
if Network and Network.peer_id and owner_peer_id then
local ok, peer_id = pcall(Network.peer_id)
if ok and owner_peer_id == peer_id then
return true
end
end
return false
end
local function unit_is_other_player(unit, dialogue_system)
if not safe_unit_alive(unit) or not owner_for_unit(unit) then
return false
end
return not unit_is_local_player(unit, dialogue_system)
end
local function classify_voice_event(event_name, event_data)
if type(event_name) ~= "string" then
return nil
end
if type(event_data) ~= "table" then
event_data = {}
end
local trigger_id = event_data.trigger_id
local item_tag = event_data.item_tag
local fail_reason = event_data.fail_reason
local dialogue_name = event_data.dialogue_name
if item_tag and PING_ITEM_TAGS[item_tag] then
return nil
end
if trigger_id and PING_ITEM_TAGS[trigger_id] then
return nil
end
if trigger_id == "com_need_ammo" then
return "voice_need_ammo"
end
if event_name == "ammo_hog" or AMMO_HOG_RESPONSE_EVENT_NAMES[event_name] then
return "voice_ammo_hog"
end
if event_name == "reload_failed" and fail_reason == "out_of_ammo" then
return "voice_out_of_ammo"
end
if dialogue_name == "reload_failed_out_of_ammo" then
return "voice_out_of_ammo"
end
return nil
end
local function classify_dialogue_name(dialogue_name)
if type(dialogue_name) ~= "string" then
return nil
end
local lower = string.lower(dialogue_name)
if string.find(lower, "smart_tag", 1, true) or string.find(lower, "pup_ammo", 1, true) or string.find(lower, "deployed_ammo", 1, true) then
return nil
end
if string.find(lower, "reload_failed_out_of_ammo", 1, true) then
return "voice_out_of_ammo"
end
if string.find(lower, "ammo_hog", 1, true) then
return "voice_ammo_hog"
end
if string.find(lower, "need_ammo", 1, true) or string.find(lower, "com_need_ammo", 1, true) then
return "voice_need_ammo"
end
return nil
end
local function classify_subtitle(dialogue)
if type(dialogue) ~= "table" then
return nil
end
return classify_dialogue_name(dialogue.currently_playing_subtitle) or classify_dialogue_name(dialogue.dialogue_name) or classify_dialogue_name(dialogue.sound_event)
end
local function is_local_ammo_hog_response(counter_id, unit, dialogue_system, event_name, dialogue_name)
if counter_id ~= "voice_ammo_hog" or not local_ammo_hog_response_block_active() then
return false
end
if not unit_is_local_player(unit, dialogue_system) then
return false
end
if AMMO_HOG_RESPONSE_EVENT_NAMES[event_name] then
return true
end
if type(dialogue_name) == "string" and string.find(string.lower(dialogue_name), "combat_pause_quirk_ammo_hog", 1, true) then
return true
end
return false
end
local function should_suppress_voice_counter(counter_id, unit, dialogue_system, event_name, dialogue_name)
if not counter_id then
return false
end
if unit_is_other_player(unit, dialogue_system) then
return true
end
return is_local_ammo_hog_response(counter_id, unit, dialogue_system, event_name, dialogue_name)
end
local function message_is_from_other_player(participant, message)
if not participant or participant.is_current_user == true then
return false
end
return not (message and message.is_current_user == true)
end
local function strip_color_tags(text)
if type(text) ~= "string" then
return ""
end
return string.gsub(text, "{%#.-}", "")
end
local function is_ammonia_category(category_name)
return strip_color_tags(category_name) == "Ammonia"
end
local function refresh_score_file_for_menu()
if score_file_dirty then
normalise_counts()
return
end
if not score_file_loaded then
load_score_file()
return
end
read_score_file()
end
local function patch_options_templates(options_templates)
if type(options_templates) ~= "table" or type(options_templates.categories) ~= "table" or type(options_templates.settings) ~= "table" then
return false
end
refresh_score_file_for_menu()
local category_name
local categories = options_templates.categories
local category_lookup = {}
for i = 1, #categories do
local category = categories[i]
local display_name = category and category.display_name
if display_name then
category_lookup[display_name] = true
if is_ammonia_category(display_name) then
category_name = display_name
category.can_be_reset = true
category.reset_function = reset_defaults
end
end
end
if not category_name then
return false
end
local settings = options_templates.settings
local insert_index
local changed = false
for i = #settings, 1, -1 do
local setting = settings[i]
if setting and setting.ammonia_score_row then
table.remove(settings, i)
changed = true
elseif setting and setting.category == category_name and setting.setting_id == SUPPRESSION_SETTING_ID then
insert_index = i
end
end
if not insert_index then
for i = 1, #settings do
local setting = settings[i]
if setting and setting.category == category_name then
insert_index = i
end
end
end
if not insert_index then
return changed
end
table.insert(settings, insert_index + 1, {
after = insert_index,
ammonia_score_row = true,
category = category_name,
custom = true,
display_name = score_block_text(),
group_name = "Ammonia",
validation_function = function()
return true
end,
widget_type = "description",
})
for i = 1, #settings do
local setting = settings[i]
if setting and setting.ammonia_score_row then
if not setting.category or not category_lookup[setting.category] then
setting.category = category_name
end
if not setting.display_name then
setting.display_name = "ammonia_score_row_" .. tostring(i)
end
end
end
return true
end
local function install_options_patch()
if not dmf or not dmf.create_mod_options_settings then
return
end
if mod._ammonia_options_patch_installed then
return
end
mod._ammonia_options_patch_installed = true
mod:hook(dmf, "create_mod_options_settings", function(func, self, options_templates)
local result = func(self, options_templates)
local target = result or options_templates
if target then
pcall(patch_options_templates, target)
end
return target
end)
end
install_options_patch()
local GAMEPLAY_STATE_NAMES = {
StateIngame = true,
StateGameplay = true,
StateMissionGameplay = true,
}
local function is_gameplay_state(state_name)
return type(state_name) == "string" and (GAMEPLAY_STATE_NAMES[state_name] or string.find(state_name, "Gameplay", 1, true) ~= nil)
end
local function flush_score_file()
write_score_file(false)
end
mod.on_game_state_changed = function(status, state_name)
if status == "exit" and is_gameplay_state(state_name) then
flush_score_file()
end
end
mod.on_disabled = function(initial_call)
if not initial_call then
flush_score_file()
end
end
mod.on_unload = function()
write_score_file(false)
end
local function hook_game_mode_manager(GameModeManager)
if GameModeManager and GameModeManager._set_end_conditions_met then
mod:hook_safe(GameModeManager, "_set_end_conditions_met", function()
flush_score_file()
end)
end
end
if CLASS and CLASS.GameModeManager then
hook_game_mode_manager(CLASS.GameModeManager)
else
mod:hook_require("scripts/managers/game_mode/game_mode_manager", hook_game_mode_manager)
end
local function hook_chat_class(ConstantElementChat)
if ConstantElementChat and ConstantElementChat.cb_chat_manager_message_recieved then
mod:hook(ConstantElementChat, "cb_chat_manager_message_recieved", function(func, self, channel_handle, participant, message)
if suppression_enabled() and message_is_from_other_player(participant, message) and message and text_is_ammo_chat_callout(message.message_body) then
count_suppressed("chat")
return
end
return func(self, channel_handle, participant, message)
end)
end
if ConstantElementChat and ConstantElementChat._add_message then
mod:hook(ConstantElementChat, "_add_message", function(func, self, message, sender, channel)
if suppression_enabled() and text_is_ammo_chat_callout(message) and local_chat_sender_state(self, sender, channel) == false then
count_suppressed("chat")
return
end
return func(self, message, sender, channel)
end)
end
end
if CLASS and CLASS.ConstantElementChat then
hook_chat_class(CLASS.ConstantElementChat)
else
mod:hook_require("scripts/ui/constant_elements/elements/chat/constant_element_chat", hook_chat_class)
end
mod:hook_require("scripts/utilities/vo", function(Vo)
if Vo.on_demand_vo_event then
mod:hook(Vo, "on_demand_vo_event", function(func, unit, concept, trigger_id, target_unit)
if suppression_enabled() and trigger_id == "com_need_ammo" and unit_is_other_player(unit) then
count_voice_suppressed("voice_need_ammo")
return
end
return func(unit, concept, trigger_id, target_unit)
end)
end
if Vo.out_of_ammo_event then
mod:hook(Vo, "out_of_ammo_event", function(func, inventory_slot_component, visual_loadout_extension)
local player = visual_loadout_extension and visual_loadout_extension._player
local player_unit = player and player.player_unit
if suppression_enabled() and unit_is_other_player(player_unit) then
count_voice_suppressed("voice_out_of_ammo")
return
end
return func(inventory_slot_component, visual_loadout_extension)
end)
end
if Vo.ammo_hog_event then
mod:hook(Vo, "ammo_hog_event", function(func, unit, ...)
if suppression_enabled() then
if unit_is_local_player(unit) then
arm_local_ammo_hog_response_block()
elseif unit_is_other_player(unit) then
count_voice_suppressed("voice_ammo_hog")
return
end
end
return func(unit, ...)
end)
end
end)
mod:hook_require("scripts/extension_systems/dialogue/dialogue_system", function(DialogueSystem)
if DialogueSystem.append_event_to_queue then
mod:hook(DialogueSystem, "append_event_to_queue", function(func, self, unit, event_name, event_data, identifier)
if suppression_enabled() then
local counter_id = classify_voice_event(event_name, event_data)
if should_suppress_voice_counter(counter_id, unit, self, event_name) then
count_voice_suppressed(counter_id)
return
end
end
return func(self, unit, event_name, event_data, identifier)
end)
end
if DialogueSystem._play_dialogue_event_implementation then
mod:hook(DialogueSystem, "_play_dialogue_event_implementation", function(func, self, go_id, is_level_unit, level_name_hash, dialogue_id, dialogue_index, dialogue_rule_index, optional_query)
if suppression_enabled() then
local unit_spawner = Managers and Managers.state and Managers.state.unit_spawner
local unit
if unit_spawner and unit_spawner.unit then
local ok, resolved_unit = pcall(unit_spawner.unit, unit_spawner, go_id, is_level_unit, level_name_hash)
if ok then
unit = resolved_unit
end
end
local dialogue_name = NetworkLookup and NetworkLookup.dialogue_names and NetworkLookup.dialogue_names[dialogue_id]
local counter_id = classify_dialogue_name(dialogue_name)
if should_suppress_voice_counter(counter_id, unit, self, nil, dialogue_name) then
count_voice_suppressed(counter_id)
return
end
end
return func(self, go_id, is_level_unit, level_name_hash, dialogue_id, dialogue_index, dialogue_rule_index, optional_query)
end)
end
end)
mod:hook_require("scripts/extension_systems/dialogue/dialogue_system_subtitle", function(DialogueSystemSubtitle)
if DialogueSystemSubtitle.add_playing_localized_dialogue then
mod:hook(DialogueSystemSubtitle, "add_playing_localized_dialogue", function(func, self, speaker_name, dialogue)
if suppression_enabled() then
local unit = dialogue and dialogue.currently_playing_unit
local counter_id = classify_subtitle(dialogue)
if should_suppress_voice_counter(counter_id, unit, nil, nil, dialogue and dialogue.dialogue_name) then
count_voice_suppressed(counter_id)
return
end
end
return func(self, speaker_name, dialogue)
end)
end
end)