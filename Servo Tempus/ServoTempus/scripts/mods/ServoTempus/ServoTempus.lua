-- ServoTempus.lua
local mod = get_mod("ServoTempus")

local DMF = get_mod("DMF")
local io_lib = DMF:persistent_table("_io")
if not io_lib.initialized then
 io_lib = DMF.deepcopy(Mods.lua.io)
 io_lib.initialized = true
end
local os_lib = DMF:persistent_table("_os")
if not os_lib.initialized then
 os_lib = DMF.deepcopy(Mods.lua.os)
 os_lib.initialized = true
end

local appdata = os_lib.getenv("APPDATA")
local home = os_lib.getenv("HOME") or os_lib.getenv("USERPROFILE")
local pb_dir
local pb_file
if appdata and appdata ~= "" then
 pb_dir = appdata .. "/Fatshark/Darktide/ServoTempus"
 pb_file = pb_dir .. "/ServoTempus.txt"
elseif home and home ~= "" then
 pb_dir = home .. "/.servo_tempus/pb"
 pb_file = pb_dir .. "/pb.txt"
else
 pb_dir = nil
 pb_file = nil
end
local pb_data = {}

local in_lobby, run_from_lobby = false, false

mod:hook_safe("LobbyView", "on_enter", function()
 in_lobby = true
end)

mod:hook_safe("LobbyView", "on_exit", function()
 run_from_lobby = in_lobby
 in_lobby = false
end)

mod:register_hud_element({
 class_name = "TimerIconElement",
 filename = "ServoTempus/scripts/mods/ServoTempus/UI/TimerIconElement",
 visibility_groups = { "alive" },
})

local Missions = require("scripts/settings/mission/mission_templates")
local Danger = require("scripts/utilities/danger")
local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")

local in_mission, awaiting_greet, last_bin
local mission_name, difficulty_name = "Unknown", "Unknown"
local mission_mods, havoc_mutators = {}, {}
local has_grimoire, has_scriptures = false, false
local is_havoc, is_maelstrom = false, false
mod.mission_end_t, mod.mission_end_outcome = nil, nil


local TEAM = { veteran="", zealot="", psyker="", ogryn="", adamant="" }
local C_MOD = "{#color(255,200,0)}"
local C_GRIM = "{#color(200,100,255)}"
local C_SCRP = "{#color(100,255,255)}"
local C_END = "{#reset()}"


local function echo(...)
 if not mod:get("silence_chat") then
 pcall(mod.echo, mod, ...)
 end
end

local function current_mission_key()
 local mech = Managers.mechanism and Managers.mechanism._mechanism
 return mech and mech._mechanism_data and mech._mechanism_data.mission_name or ""
end

local function is_hub()
 local key = current_mission_key():lower()
 return (key:find("mourningstar") ~= nil) or (key:find("hub") ~= nil)
end

local function refresh_names()
 local mech = Managers.mechanism and Managers.mechanism._mechanism
 local d = mech and mech._mechanism_data
 if not d then return end
 local tpl = Missions[d.mission_name]
 mission_name = tpl and Localize(tpl.mission_name) or "Unknown"
 local diff = Danger.danger_by_difficulty(d.challenge, d.resistance) or {}
 difficulty_name = diff.display_name and Localize(diff.display_name) or "Unknown"
end

local function circ_order(c)
 if c == " @Havoc" then return 2
 elseif c == " @Maelstrom" then return 3
 else return 1
 end
end


mod:hook_safe("MissionIntroView", "on_enter", function()
 mission_mods, havoc_mutators = {}, {}
 has_grimoire, has_scriptures = false, false
 is_havoc, is_maelstrom = false, false

 local mech = Managers.mechanism and Managers.mechanism._mechanism
 local d = mech and mech._mechanism_data
 if not d then return end

 refresh_names()

 local tpl = Missions[d.mission_name]
 if tpl and tpl.is_flash_mission and tpl.is_auric_mission then
 is_maelstrom = true
 end


 if d.circumstance_name and d.circumstance_name ~= "default" then
 local circ = CircumstanceTemplates[d.circumstance_name]
 if circ and circ.ui and circ.ui.display_name then
 mission_mods[#mission_mods+1] = Localize(circ.ui.display_name)
 end
 end


 if d.side_mission and d.side_mission ~= "default" then
 if d.side_mission:find("scripture") then
 has_scriptures = true
 elseif d.side_mission:find("grimoire") or d.side_mission:find("tome") then
 has_grimoire = true
 end
 end


 if d.flags then
 for f in pairs(d.flags) do
 if f:match("^havoc%-rank") then
 is_havoc = true
 break
 end
 end
 if is_havoc then
 for f in pairs(d.flags) do
 local id = f:match("^havoc%-mutator%-(.+)$")
 if id then
 local key = "loc_havoc_" .. id:gsub("%-","_") .. "_name"
 havoc_mutators[#havoc_mutators+1] = Localize(key)
 end
 end
 end
 end
end)

mod:hook_safe("MissionIntroView", "on_exit", function()
 in_mission, awaiting_greet, last_bin = true, true, nil

 if run_from_lobby then
 if pb_dir then os_lib.execute(string.format('mkdir "%s"', pb_dir)) end
 local f = pb_file and io_lib.open(pb_file, "r")
 pb_data = {}
 if f then
 for line in f:lines() do pb_data[#pb_data+1] = line end
 f:close()
 else
 if pb_file then
 local f2 = io_lib.open(pb_file, "w")
 if f2 then f2:close() end
 end
 end

 if mod:get("show_greeting") then
 echo(string.format("%s [%s]: Mission start!", mission_name, difficulty_name))
 end
 end
end)


mod:hook_safe("GameModeManager", "_set_end_conditions_met", function(self, outcome, ...)
 mod.mission_end_t = Managers.time:time("gameplay")
 mod.mission_end_outcome = outcome
end)

mod:hook_safe("EndView", "on_enter", function(self, params, ...)
 refresh_names()
 local total = mod.mission_end_t or 0
 local m, s = math.floor(total/60), math.floor(total%60)

 if not mod:get("silence_chat") then
 echo(string.format("%s [%s] took %02d:%02d in total.", mission_name, difficulty_name, m, s))
 end

 if run_from_lobby and mod.mission_end_outcome == true then
  local prefix = mission_name .. " #" .. difficulty_name
 if is_havoc then prefix = prefix .. " @Havoc"
 elseif is_maelstrom then prefix = prefix .. " @Maelstrom" end

 local idx, old_time
 for i, line in ipairs(pb_data) do
 if line:sub(1, #prefix) == prefix then
 idx, old_time = i, line:sub(#prefix+2)
 break
 end
 end

 local new_time = string.format("%02d:%02d", m, s)
 local new_s = m*60 + s
 local write_ok = mod:get("log_personal_best")

 if not idx then
 if write_ok then
 pb_data[#pb_data+1] = prefix .. " " .. new_time
 end
 echo("Logged your first personal best time for this mission. Run it again and try to beat " .. new_time .. ".")
 else
 local em, es = old_time:match("^(%d+):(%d+)$")
 local old_s = tonumber(em)*60 + tonumber(es)

 if new_s < old_s then
 local diff = old_s - new_s
 local dm, ds = math.floor(diff/60), diff%60
 if write_ok then pb_data[idx] = prefix .. " " .. new_time end
 echo(
 C_MOD .. string.format(
 "Well done! You beat your previous best of %s by %dm %ds.", old_time, dm, ds
 ) .. C_END
 )
 elseif new_s == old_s then
 echo("You matched your personal best of " .. old_time .. ".")
 else
 local delta = new_s - old_s
 if delta <= 60 then echo("Ooh, close, but not quite. Your personal best is " .. old_time .. ".")
 elseif delta <= 300 then echo("Not bad, but your personal best is " .. old_time .. ".")
 else echo("Bit slow. Your personal best is " .. old_time .. ".")
 end
 end
 end

 if write_ok then
 table.sort(pb_data, function(a,b)
 local ma, da, ca = a:match("^(.-) #([^ @]+)( @%w+)? ")
 local mb, db, cb = b:match("^(.-) #([^ @]+)( @%w+)? ")
 if ma ~= mb then return ma < mb end
 local order = { Uprising=1, Malice=2, Heresy=3, Damnation=4, Auric=5 }
 if order[da] ~= order[db] then return order[da] < order[db] end
 ca, cb = ca or "", cb or ""
 if circ_order(ca) ~= circ_order(cb) then
 return circ_order(ca) < circ_order(cb)
 end
 return a < b
 end)
 if pb_dir then os_lib.execute(string.format('mkdir "%s"', pb_dir)) end
 local f2 = pb_file and io_lib.open(pb_file, "w")
 if f2 then
 for _, line in ipairs(pb_data) do f2:write(line.."\n") end
 f2:close()
 end
 end
 end

 in_mission, awaiting_greet, last_bin = false, false, nil
end)

local function greet(elapsed)
 if not mod:get("show_greeting") or is_hub() or not in_mission then return end
 refresh_names()

 local counts = { veteran=0, zealot=0, psyker=0, ogryn=0, adamant=0 }
 for _, p in pairs(Managers.player:players() or {}) do
 if p.player_unit then
 local a = p.profile_name or ""
 if counts[a] then counts[a] = counts[a]+1 end
 end
 end
 local team_line = ""
 for k,v in pairs(counts) do
 if v>0 then team_line = team_line.." "..TEAM[k]..v end
 end

 local tags = ""
 if is_havoc then
 for _,n in ipairs(havoc_mutators) do tags = tags.." ["..n.."]" end
 tags = tags.." [Havoc]"
 elseif is_maelstrom then
 tags = tags.." [Maelstrom]"
 end
 for _,n in ipairs(mission_mods) do tags = tags.." ["..n.."]" end
 if has_scriptures then
 tags = tags.." "..C_SCRP.."[Scriptures]"..C_END
 elseif has_grimoire then
 tags = tags.." "..C_GRIM.."[Grimoires]"..C_END
 end

 local time_str = string.format("%02d:%02d", math.floor(elapsed/60), elapsed%60)
 echo(string.format("%s [%s]:%s %s My clock reads %s. Get moving, Reject.",
 mission_name, difficulty_name, team_line, tags, time_str
 ))
end

local function announce_interval(bin)
 echo(string.format("%d minutes have elapsed.", bin*5))
 if mod:get("show_5min_icon") then
 Managers.event:trigger("servo_tempus_show_icon", 3)
 end
end


mod.update = function(_,dt)
 if not mod:is_enabled() or is_hub() or not in_mission then return end
 local T = Managers.time
 if awaiting_greet and T and T:has_timer("gameplay") then
 greet(T:time("gameplay"))
 last_bin,awaiting_greet = math.floor(T:time("gameplay")/300),false
 end
 if last_bin and T and T:has_timer("gameplay") then
 local b = math.floor(T:time("gameplay")/300)
 if b>last_bin then last_bin=b; announce_interval(b) end
 end
end

mod:command("servo", mod:localize("chat_command_desc"), function(args)
 if args == "icon" then
 Managers.event:trigger("servo_tempus_show_icon", 10)
 echo("Revealing timer icon location for 10 seconds.")
 return
 end

 if is_hub() then
 echo("Pick a mission and I'll time you, Reject.")
 return
 end

 local T = Managers.time
 if T and T:has_timer("gameplay") then
 local e = T:time("gameplay")
 echo(string.format("My timepiece says %02d:%02d.", math.floor(e/60), e%60))
 else
 echo("Mission timer not started yet.")
 end
end)

mod.on_enabled = function() in_mission,awaiting_greet,last_bin = false,false,nil end
mod.on_disabled = mod.on_enabled
