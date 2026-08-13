-- valkyrie_command.lua
local Danger = require("scripts/utilities/danger")
local M = {
REPORT_VALKYRIE_START = "valkyrie_start",
REPORT_MISSION_START = "mission_start",
REPORT_NONE = "none",
}
function M.init(ctx)
local mod = ctx.mod
local Missions = ctx.Missions
local report_sent = false
local mission_name = "Unknown"
local difficulty = "Unknown"
local function current_report_timing()
return mod:get("report_timing") or M.REPORT_VALKYRIE_START
end
local function echo_mission_report()
mod:echo("{#color(116,143,57)}" .. "Mission: " .. "{#color(3, 140, 103)}" .. mission_name .. "{#reset()}" .. " " .. "{#color(116,143,57)}" .. "Difficulty: " .. "{#color(3, 140, 103)}" .. difficulty .. "{#reset()}")
end
function M.reset_report()
report_sent = false
mission_name = "Unknown"
difficulty = "Unknown"
end
function M.refresh_values(data)
data = data or ctx.get_mechanism_data()
if not data then
return
end
local tpl = Missions[data.mission_name]
mission_name = tpl and Localize(tpl.mission_name) or "Unknown"
local diff = Danger.danger_by_difficulty(data.challenge, data.resistance) or {}
difficulty = diff.display_name and Localize(diff.display_name) or "Unknown"
end
function M.send(timing)
if report_sent or current_report_timing() ~= timing or timing == M.REPORT_NONE then
return
end
echo_mission_report()
report_sent = true
end
function M.manual_mission_report()
if ctx.is_hub() then
mod:echo("This is the Mourningstar.")
return
end
M.refresh_values(ctx.get_mechanism_data())
echo_mission_report()
end
mod:command("valk", "identifies mission via chat", M.manual_mission_report)
return M
end
return M
