-- valkyrie.lua
local mod       = get_mod("valkyrie")
local Missions  = require("scripts/settings/mission/mission_templates")
local Danger    = require("scripts/utilities/danger")

local COL_PRIMARY_START = "{#color(116,143,57)}"
local COL_MISSION_START = "{#color(3, 140, 103)}"
local COL_END           = "{#reset()}"

local report_sent  = false
local mission_name = "Unknown"
local difficulty   = "Unknown"
local in_lobby     = false
local silent_mode  = true

local brief_patterns = {
  "mission_.*_brief.*",
  "mission_.*_briefing.*",
  "mission_brief.*",
}

mod:hook("LevelTransitionHandler", "on_mission_start", function(func, self, key, params)
  report_sent, silent_mode, in_lobby = false, true, false
  return func(self, key, params)
end)

mod:hook_safe(CLASS.LobbyView, "on_enter", function()
  in_lobby = true
end)

if CLASS.LobbyView._setup_loadout_widgets then
  mod:hook_safe(CLASS.LobbyView, "_setup_loadout_widgets", function()
    in_lobby = true
  end)
end

mod:hook_safe(CLASS.LobbyView, "on_exit", function()
  if in_lobby and not mod:get("mute_lobby_mission") then
    silent_mode = false
  end
  in_lobby = false
end)

mod:hook_safe(CLASS.MissionIntroView, "on_enter", function()
  report_sent = false

  local mech = Managers.mechanism and Managers.mechanism._mechanism
  local data = mech and mech._mechanism_data

  if data then
    local tpl = Missions[data.mission_name]
    mission_name = tpl and Localize(tpl.mission_name) or "Unknown"

    local diff = Danger.danger_by_difficulty(data.challenge, data.resistance) or {}
    difficulty = diff.display_name and Localize(diff.display_name) or "Unknown"
  end
end)

mod:hook_safe(CLASS.MissionIntroView, "on_exit", function()
  silent_mode = true

  if mod:get("report_on_skip") and not report_sent then
    mod:echo(
      COL_PRIMARY_START .. "Mission: "
      .. COL_MISSION_START .. mission_name .. COL_END
      .. " "
      .. COL_PRIMARY_START .. "Difficulty: "
      .. COL_MISSION_START .. difficulty .. COL_END
    )
    report_sent = true
  end
end)

mod:hook("LocalWaitForMissionBriefingDoneState", "update", function(func, self, dt)
  if mod:is_enabled() and silent_mode then
    return "mission_briefing_done"
  end
  return func(self, dt)
end)

local function block()
  return mod:is_enabled() and silent_mode
end

mod:hook("DialogueExtension", "play_event", function(func, self, event)
  if block() and event.sound_event then
    for _, pat in ipairs(brief_patterns) do
      if event.sound_event:match(pat) then
        return
      end
    end
  end

  return func(self, event)
end)

mod:hook("DialogueSystemSubtitle", "add_playing_localized_dialogue", function(func, self, speaker, dialogue)
  if block() and dialogue.currently_playing_subtitle then
    for _, pat in ipairs(brief_patterns) do
      if dialogue.currently_playing_subtitle:match(pat) then
        return
      end
    end
  end

  return func(self, speaker, dialogue)
end)

mod:hook_safe(CLASS.MissionIntroView, "_set_hologram_briefing_material", function(self, mission_name)
  if mod:is_enabled() and mod:get("hide_mission_screen") then
    local world = self._world_spawner and self._world_spawner._world
    if not world then
      return true
    end

    local holo = World.unit_by_name(world, "valkyrie_hologram_prototype_01")
    if holo and Unit.alive(holo) then
      Unit.set_unit_visibility(holo, false)
    end

    return true
  end
end)
