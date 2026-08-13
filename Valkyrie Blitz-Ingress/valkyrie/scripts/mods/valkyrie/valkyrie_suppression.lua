-- valkyrie_suppression.lua
local M = {}
function M.init(ctx)
local mod = ctx.mod
local brief_patterns = {
"mission_.*_brief.*",
"mission_.*_briefing.*",
"mission_brief.*",
"expedition_.*_brief.*",
"expedition_.*_briefing.*",
"expedition_brief.*",
}
local mortis_patterns = {
"horde.*",
"hordes.*",
"mortis.*",
"story_echo_.*",
"survival.*",
"stef.*",
}
local function text_matches_patterns(text, patterns)
if type(text) ~= "string" then
return false
end
for _, pattern in ipairs(patterns) do
if text:match(pattern) then
return true
end
end
return false
end
local function should_block_briefing()
return ctx.should_block_briefing()
end
function M.set_briefing_done_if_silent(view)
if view and should_block_briefing() then
view.mission_briefing_done = true
end
end
function M.register_hooks()
local Vo = rawget(_G, "Vo")
if Vo and Vo.mission_giver_mission_info_vo then
mod:hook(Vo, "mission_giver_mission_info_vo", function(func, voice_selection, selected_voice, trigger_id, ...)
if ctx.is_mortis_trials() and should_block_briefing() then
local trigger_text = tostring(trigger_id or "")
if voice_selection == "rule_based" or text_matches_patterns(trigger_text, mortis_patterns) then
return
end
end
return func(voice_selection, selected_voice, trigger_id, ...)
end)
end
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView._play_mission_brief_vo then
mod:hook(CLASS.MissionIntroView, "_play_mission_brief_vo", function(func, self, ...)
if should_block_briefing() then
self.mission_briefing_done = true
return
end
return func(self, ...)
end)
end
mod:hook("LocalWaitForMissionBriefingDoneState", "update", function(func, self, dt)
if ctx.is_lobby_view_active() then
return func(self, dt)
end
if should_block_briefing() then
return "mission_briefing_done"
end
return func(self, dt)
end)
mod:hook("DialogueExtension", "play_event", function(func, self, event)
local sound_event = event and event.sound_event
local block_briefing = should_block_briefing()
if block_briefing and text_matches_patterns(sound_event, brief_patterns) then
return
end
if block_briefing and text_matches_patterns(sound_event, mortis_patterns) then
return
end
return func(self, event)
end)
mod:hook("DialogueSystemSubtitle", "add_playing_localized_dialogue", function(func, self, speaker, dialogue)
local subtitle = dialogue and dialogue.currently_playing_subtitle
local speaker_name = speaker or dialogue and dialogue.speaker_name
local block_briefing = should_block_briefing()
if block_briefing and text_matches_patterns(subtitle, brief_patterns) then
return
end
if block_briefing and (text_matches_patterns(subtitle, mortis_patterns) or text_matches_patterns(speaker_name, mortis_patterns)) then
return
end
return func(self, speaker, dialogue)
end)
if CLASS and CLASS.MissionIntroView and CLASS.MissionIntroView._set_hologram_briefing_material then
mod:hook_safe(CLASS.MissionIntroView, "_set_hologram_briefing_material", function(self)
if mod:is_enabled() and mod:get("hide_mission_screen") then
local world = self and self._world_spawner and self._world_spawner._world
if not world then
return
end
local holo = World.unit_by_name(world, "valkyrie_hologram_prototype_01")
if holo and Unit.alive(holo) then
Unit.set_unit_visibility(holo, false)
end
end
end)
end
end
return M
end
return M
