-- Cut_transmission.lua
local mod = get_mod("Cut_transmission")
local EndViewSettings = mod:original_require("scripts/ui/views/end_view/end_view_settings")
local debrief_videos = EndViewSettings and EndViewSettings.debrief_videos or {}
local pack = table.pack or function(...)
return {n = select("#", ...), ...}
end
local unpack_fn = table.unpack or unpack

local function enabled()
if mod.get then
local value = mod:get("skip_transmissions")
if value ~= nil then
return value
end
end
return true
end

local function is_debriefing_template(template_name)
return type(template_name) == "string" and (
template_name:find("^debriefing_") ~= nil or
template_name:find("^debriefing_nml_") ~= nil
)
end

local function should_block_applied_event(applied_event)
local debrief_video = applied_event and debrief_videos[applied_event]
return is_debriefing_template(debrief_video)
end

mod:hook_require("scripts/ui/views/end_view/end_view", function(end_view)
if mod._bdtd_hooked_end_view then
return
end
mod._bdtd_hooked_end_view = true
mod:hook(end_view, "update", function(func, self, dt, t, input_service, ...)
local session_report = self and self._session_report
local mission = session_report and session_report.eor and session_report.eor.mission
local original_applied_event = mission and mission.appliedEvent
if enabled() and should_block_applied_event(original_applied_event) then
mission.appliedEvent = nil
end
local results = pack(func(self, dt, t, input_service, ...))
if mission then
mission.appliedEvent = original_applied_event
end
return unpack_fn(results, 1, results.n)
end)
end)
