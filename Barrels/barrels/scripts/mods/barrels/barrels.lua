-- barrels.lua
local mod = get_mod("barrels")
local TextUtilities = require("scripts/utilities/ui/text")

local function glyph_for(col)
    return TextUtilities.apply_color_to_text("", col)
end

local function colour_for_type(t)
    if t == "explosive_fire_barrel" then return Color.ui_red_light(255, true) end
    if t == "explosive_explosion_barrel" then return Color.citadel_dorn_yellow(255, true) end
    return Color.citadel_jokaero_orange(255, true)
end

local function player_from_unit(unit)
    if not unit then return end
    for _, p in pairs(Managers.player:players()) do
        if p.player_unit == unit then
            return p
        end
    end
end

local function is_local_player(unit)
    local local_player = Managers.player:local_player(1)
    return unit and local_player and (local_player.player_unit == unit)
end

local function safe_echo(msg)
    if not pcall(function() mod:echo(msg) end) then
        mod:print(msg)
    end
end

local function overlay(col, txt, attacker_u, barrel_u)
    local show_skulls = mod:get("show_skulls")
    local skull = show_skulls and (glyph_for(col) .. " ") or ""
    local colored_txt = TextUtilities.apply_color_to_text(txt, col)
    local msg = skull .. colored_txt
    local mode = mod:get("report_mode")
    if mode == "default" then
        mod:notify(msg, 4)
    elseif mode == "chat" then
        safe_echo(msg)
    elseif mode == "kill_feed" then
        Managers.event:trigger("event_add_combat_feed_message", msg)
    end
end

local function get_barrel_type(damage_profile, unit)
    if damage_profile and damage_profile.name then
        local name = damage_profile.name
        if name:find("fire_barrel") then return "explosive_fire_barrel" end
        if name:find("barrel_explosion") then return "explosive_explosion_barrel" end
    end
    local haz = ScriptUnit.has_extension(unit, "hazard_prop_system")
    if haz then
        if haz._content == "fire" then return "explosive_fire_barrel"
        elseif haz._content == "explosion" then return "explosive_explosion_barrel"
        end
    end
    return "explosive_common"
end

local BARREL_DAMAGE_PROFILES = {
    barrel_explosion = true,
    barrel_explosion_close = true,
    fire_barrel_explosion = true,
    fire_barrel_explosion_close = true,
}

local barrel_kill_counter = {}
local barrel_state_seen = {}
local injure_records = {}
local pending_notifications = {}
local notification_delay = 0.5

local counted_victim_ids = {}

mod:hook_safe("StateGameplay", "on_enter", function()
    barrel_kill_counter = {}
    barrel_state_seen = {}
    injure_records = {}
    pending_notifications = {}
    counted_victim_ids = {}
end)

mod:hook(
    CLASS.AttackReportManager,
    "add_attack_result",
    function(func, self, damage_profile, victim, attacker, dir, pos, weak, dmg, result, atype, eff, ...)
        local profile_name = damage_profile and damage_profile.name
        local is_barrel_profile = profile_name and BARREL_DAMAGE_PROFILES[profile_name]
        local is_barrel_hazard = attacker and ScriptUnit.has_extension(attacker, "hazard_prop_system")
        local victim_id = victim and Unit.alive(victim) and Unit.id and Unit:id(victim) or victim

        if result == "died" and is_barrel_profile and is_barrel_hazard then
            if victim_id and not counted_victim_ids[victim_id] then
                barrel_kill_counter[attacker] = (barrel_kill_counter[attacker] or 0) + 1
                counted_victim_ids[victim_id] = true
            end
        end

        local local_player_unit = Managers.player:local_player(1).player_unit
        if result == "died" and is_barrel_profile and (attacker == local_player_unit) then
            for barrel_u, data in pairs(pending_notifications) do
                if not data._kill_ids then data._kill_ids = {} end
                if victim_id and not data._kill_ids[victim_id] then
                    barrel_kill_counter[barrel_u] = (barrel_kill_counter[barrel_u] or 0) + 1
                    data._kill_ids[victim_id] = true
                    counted_victim_ids[victim_id] = true
                end
            end
        end

        local hit_player = player_from_unit(victim)
        local is_barrel_unit = ScriptUnit.has_extension(victim, "hazard_prop_system")
        if is_barrel_profile and hit_player and not is_barrel_unit then
            local pname = hit_player:name()
            for barrel_u in pairs(pending_notifications) do
                injure_records[barrel_u] = injure_records[barrel_u] or {}
                injure_records[barrel_u][pname] = (injure_records[barrel_u][pname] or 0) + dmg
            end
        end

        if is_barrel_unit then
            local haz = ScriptUnit.has_extension(victim, "hazard_prop_system")
            local state = haz._current_state
            local btype = get_barrel_type(damage_profile, victim)
            local colour = colour_for_type(btype)
            local ply = player_from_unit(attacker)
            local name = (ply and ply:name()) or "Someone"
            local barrel = mod:localize(btype)

            if state == "triggered" and barrel_state_seen[victim] ~= "triggered" then
                overlay(colour, string.format("%s ignited %s", name, barrel))
                barrel_state_seen[victim] = "triggered"

            elseif state == "broken" and barrel_state_seen[victim] ~= "broken" then
                pending_notifications[victim] = {
                    initiator_name = name,
                    btype = btype,
                    colour = colour,
                    barrel_name = barrel,
                    due_time = Managers.time:time("main") + notification_delay,
                    _kill_ids = {},
                }
                barrel_state_seen[victim] = "broken"
            end
        end

        return func(self, damage_profile, victim, attacker, dir, pos, weak, dmg, result, atype, eff, ...)
    end
)

mod:hook_safe("StateGameplay", "update", function(self, dt, t)
    for barrel_u, data in pairs(pending_notifications) do
        if data.due_time and t >= data.due_time then
            local kills = barrel_kill_counter[barrel_u] or 0
            local parts = {}

            if kills > 0 then
                parts[#parts+1] = string.format("%d kill%s", kills, kills > 1 and "s" or "")
            end

            local show_damage = mod:get("show_damage")
            if show_damage then
                local injures = injure_records[barrel_u] or {}
                for pname, total in pairs(injures) do
                    parts[#parts+1] = string.format("Injured %s by %dHP", pname, total)
                end
            end

            local detail = (#parts > 0) and ("\n• " .. table.concat(parts, "; ")) or ""
            local msg = data.initiator_name
                .. " detonated "
                .. data.barrel_name
                .. detail

            overlay(data.colour, msg)

            pending_notifications[barrel_u] = nil
            injure_records[barrel_u] = nil
            barrel_kill_counter[barrel_u] = nil
        end
    end
end)
