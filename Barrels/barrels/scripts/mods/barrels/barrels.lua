-- barrels.lua
local mod = get_mod("barrels")
local AttackSettings = require("scripts/settings/damage/attack_settings")
local AttackingUnitResolver = require("scripts/utilities/attack/attacking_unit_resolver")
local Damage = require("scripts/utilities/attack/damage")
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")
local TextUtilities = require("scripts/utilities/ui/text")
local attack_results = AttackSettings.attack_results

local QUIET_DELAY = 1.25
local FIRE_QUIET_DELAY = 3
local BLAST_MAX_AGE = 4
local FIRE_MAX_AGE = 12
local CATAPULT_WINDOW = 4
local MATCH_RADIUS_SQ = 64
local INCIDENT_MATCH_RADIUS_SQ = 400
local INCIDENT_MERGE_WINDOW = 6

local BARREL_EXPLOSION_PROFILES = {
barrel_explosion = true,
barrel_explosion_close = true,
fire_barrel_explosion = true,
fire_barrel_explosion_close = true,
promethium_barrel_explosion = true,
promethium_barrel_explosion_close = true,
}

local BARREL_FIRE_PROFILES = {
liquid_area_fire_burning_barrel = true,
}

local OFF_NAVMESH_PROFILES = {
kill_volume_and_off_navmesh = true,
falling_light = true,
falling_heavy = true,
}

local barrel_owner_by_unit = {}
local barrel_state_seen = {}
local active_incidents = {}
local source_incident_ids = {}
local recent_player_barrel_impacts = {}
local incident_id = 0

local function main_time()
if Managers.time then
return Managers.time:time("main")
end
return Application.time_since_launch()
end

local function glyph_for(col)
return TextUtilities.apply_color_to_text("", col)
end

local function colour_for_type(t)
if t == "explosive_fire_barrel" then return Color.ui_red_light(255, true) end
if t == "explosive_explosion_barrel" then return Color.citadel_dorn_yellow(255, true) end
return Color.citadel_jokaero_orange(255, true)
end

local function player_from_unit(unit)
local player_unit_spawn = Managers.state and Managers.state.player_unit_spawn
return player_unit_spawn and unit and player_unit_spawn:owner(unit) or nil
end

local function resolved_player_unit(unit)
if not unit or not ALIVE[unit] then
return nil
end
local resolved_unit = AttackingUnitResolver.resolve(unit)
if resolved_unit and ALIVE[resolved_unit] and player_from_unit(resolved_unit) then
return resolved_unit
end
if player_from_unit(unit) then
return unit
end
return nil
end

local function strip_rich_text_tags(text)
if not text then
return nil
end
text = text:gsub("{#.-}", "")
text = text:gsub("\r", "")
text = text:gsub("\n", " ")
text = text:gsub("%[", "(")
text = text:gsub("%]", ")")
return text
end

local function safe_player_name(player)
return player and strip_rich_text_tags(player:name()) or nil
end

local function player_name_from_unit(unit)
local resolved_unit = resolved_player_unit(unit) or unit
local player = player_from_unit(resolved_unit)
return safe_player_name(player)
end

local function safe_echo(msg)
if not pcall(function() mod:echo(msg) end) then
mod:print(msg)
end
end

local function overlay(col, txt)
local skull = mod:get("show_skulls") and (glyph_for(col) .. " ") or ""
local msg = skull .. TextUtilities.apply_color_to_text(txt, col)
local mode = mod:get("report_mode")
if mode == "default" then
mod:notify(msg, 4)
elseif mode == "chat" then
safe_echo(msg)
elseif mode == "kill_feed" then
Managers.event:trigger("event_add_combat_feed_message", msg)
end
end

local function barrel_type_from_profile(name)
if not name then return "explosive_common" end
if name == "liquid_area_fire_burning_barrel" then return "explosive_fire_barrel" end
if name:find("promethium_barrel") or name:find("fire_barrel") then return "explosive_fire_barrel" end
if name:find("barrel_explosion") then return "explosive_explosion_barrel" end
return "explosive_common"
end

local function barrel_type_from_content(content)
if content == "fire" then return "explosive_fire_barrel" end
if content == "explosion" or content == "gas" then return "explosive_explosion_barrel" end
return "explosive_common"
end

local function barrel_name_from_type(t)
return mod:localize(t)
end

local function source_position(unit)
if unit and ALIVE[unit] then
if Unit.has_node(unit, "c_explosion") then
return Unit.world_position(unit, Unit.node(unit, "c_explosion"))
end
return POSITION_LOOKUP[unit] or Unit.world_position(unit, 1)
end
end

local function vector_from_box(box)
return box and box:unbox() or nil
end

local function reset_state()
barrel_owner_by_unit = {}
barrel_state_seen = {}
active_incidents = {}
source_incident_ids = {}
recent_player_barrel_impacts = {}
incident_id = 0
end

local function update_barrel_owner_meta(unit, btype, attacker_unit)
local owner_player_unit = resolved_player_unit(attacker_unit)
local owner_name = player_name_from_unit(owner_player_unit or attacker_unit)
local meta = barrel_owner_by_unit[unit] or {
btype = btype,
barrel_name = barrel_name_from_type(btype),
colour = colour_for_type(btype),
}
meta.btype = btype or meta.btype or "explosive_common"
meta.barrel_name = barrel_name_from_type(meta.btype)
meta.colour = colour_for_type(meta.btype)
meta.last_hit_t = main_time()
if owner_name then
if not meta.igniter_name then
meta.igniter_name = owner_name
meta.igniter_unit = owner_player_unit
end
meta.detonator_name = owner_name
meta.detonator_unit = owner_player_unit
meta.owner_name = owner_name
meta.owner_unit = owner_player_unit
end
barrel_owner_by_unit[unit] = meta
return meta
end

local function sync_incident_owner_meta(unit)
local id = unit and source_incident_ids[unit]
local incident = id and active_incidents[id]
local meta = unit and barrel_owner_by_unit[unit]
if not incident or not meta then
return
end
incident.btype = meta.btype or incident.btype
incident.barrel_name = meta.barrel_name or incident.barrel_name
incident.colour = meta.colour or incident.colour
incident.igniter_name = meta.igniter_name or incident.igniter_name
incident.igniter_unit = meta.igniter_unit or incident.igniter_unit
incident.detonator_name = meta.detonator_name or incident.detonator_name
incident.detonator_unit = meta.detonator_unit or incident.detonator_unit
incident.owner_name = incident.detonator_name or incident.owner_name
incident.owner_unit = incident.detonator_unit or incident.owner_unit
end

local function create_incident(source_unit, source_pos, btype, igniter_unit, igniter_name, detonator_unit, detonator_name)
incident_id = incident_id + 1
local started_t = main_time()
local incident = {
id = incident_id,
source_unit = source_unit,
source_position = source_pos and Vector3Box(source_pos) or nil,
btype = btype,
barrel_name = barrel_name_from_type(btype),
colour = colour_for_type(btype),
igniter_unit = igniter_unit,
igniter_name = igniter_name,
detonator_unit = detonator_unit,
detonator_name = detonator_name or igniter_name or "Someone",
owner_unit = detonator_unit or igniter_unit,
owner_name = detonator_name or igniter_name or "Someone",
started_t = started_t,
last_event_t = started_t,
quiet_delay = btype == "explosive_fire_barrel" and FIRE_QUIET_DELAY or QUIET_DELAY,
max_age = btype == "explosive_fire_barrel" and FIRE_MAX_AGE or BLAST_MAX_AGE,
enemy_blast_kills = 0,
enemy_fire_kills = 0,
enemy_blast_ids = {},
enemy_fire_ids = {},
player_blast_damage = {},
player_fire_damage = {},
player_blast_toughness_damage = {},
player_fire_toughness_damage = {},
player_blast_toughness_broken = {},
player_fire_toughness_broken = {},
player_blast_downs = {},
player_fire_downs = {},
player_blast_kills = {},
player_fire_kills = {},
player_catapults = {},
player_catapult_kills = {},
}
active_incidents[incident.id] = incident
if source_unit then
source_incident_ids[source_unit] = incident.id
end
return incident
end

local function get_or_create_barrel_incident(unit)
local existing_id = source_incident_ids[unit]
if existing_id and active_incidents[existing_id] then
return active_incidents[existing_id]
end
local meta = barrel_owner_by_unit[unit] or {
btype = "explosive_common",
barrel_name = barrel_name_from_type("explosive_common"),
colour = colour_for_type("explosive_common"),
owner_name = "Someone",
}
local position = source_position(unit)
return create_incident(unit, position, meta.btype or "explosive_common", meta.igniter_unit, meta.igniter_name, meta.detonator_unit, meta.detonator_name)
end

local function nearest_incident_by_position(position, btype)
if not position then return nil end
local best_incident, best_distance_sq
for _, incident in pairs(active_incidents) do
if incident.btype == btype and incident.source_position then
local distance_sq = Vector3.distance_squared(position, incident.source_position:unbox())
if distance_sq <= MATCH_RADIUS_SQ and (not best_distance_sq or distance_sq < best_distance_sq) then
best_incident = incident
best_distance_sq = distance_sq
end
end
end
return best_incident
end

local function same_name(a, b)
return not a or not b or a == b
end

local function incident_detail_score(incident)
local score = incident.enemy_blast_kills + incident.enemy_fire_kills
local groups = {
incident.player_blast_damage,
incident.player_fire_damage,
incident.player_blast_toughness_damage,
incident.player_fire_toughness_damage,
incident.player_blast_toughness_broken,
incident.player_fire_toughness_broken,
incident.player_blast_downs,
incident.player_fire_downs,
incident.player_blast_kills,
incident.player_fire_kills,
incident.player_catapults,
incident.player_catapult_kills,
}
for i = 1, #groups do
for _ in pairs(groups[i]) do
score = score + 1
end
end
return score
end

local function incidents_are_compatible(a, b)
if not a or not b or a.id == b.id or a.btype ~= b.btype then
return false
end
if math.abs((a.started_t or 0) - (b.started_t or 0)) > INCIDENT_MERGE_WINDOW then
return false
end
if not same_name(a.owner_name, b.owner_name) then
return false
end
if not same_name(a.igniter_name, b.igniter_name) then
return false
end
if not same_name(a.detonator_name, b.detonator_name) then
return false
end
if a.source_position and b.source_position then
local distance_sq = Vector3.distance_squared(a.source_position:unbox(), b.source_position:unbox())
if distance_sq > INCIDENT_MATCH_RADIUS_SQ then
return false
end
end
return true
end

local function merge_number_maps(dst, src)
for name, amount in pairs(src) do
dst[name] = (dst[name] or 0) + amount
end
end

local function merge_bool_maps(dst, src)
for name in pairs(src) do
dst[name] = true
end
end

local function merge_incident_into(dst, src)
if not dst or not src or dst.id == src.id then
return dst
end
if not dst.source_unit and src.source_unit then
dst.source_unit = src.source_unit
end
if not dst.source_position and src.source_position then
local pos = src.source_position:unbox()
dst.source_position = Vector3Box(pos)
end
if not dst.igniter_name and src.igniter_name then
dst.igniter_name = src.igniter_name
dst.igniter_unit = src.igniter_unit
end
if not dst.detonator_name and src.detonator_name then
dst.detonator_name = src.detonator_name
dst.detonator_unit = src.detonator_unit
end
if not dst.owner_name and src.owner_name then
dst.owner_name = src.owner_name
end
if not dst.owner_unit and src.owner_unit then
dst.owner_unit = src.owner_unit
end
dst.started_t = math.min(dst.started_t or 0, src.started_t or 0)
dst.last_event_t = math.max(dst.last_event_t or 0, src.last_event_t or 0)
dst.quiet_delay = math.max(dst.quiet_delay or QUIET_DELAY, src.quiet_delay or QUIET_DELAY)
dst.max_age = math.max(dst.max_age or BLAST_MAX_AGE, src.max_age or BLAST_MAX_AGE)
dst.enemy_blast_kills = (dst.enemy_blast_kills or 0) + (src.enemy_blast_kills or 0)
dst.enemy_fire_kills = (dst.enemy_fire_kills or 0) + (src.enemy_fire_kills or 0)
merge_bool_maps(dst.enemy_blast_ids, src.enemy_blast_ids)
merge_bool_maps(dst.enemy_fire_ids, src.enemy_fire_ids)
merge_number_maps(dst.player_blast_damage, src.player_blast_damage)
merge_number_maps(dst.player_fire_damage, src.player_fire_damage)
merge_number_maps(dst.player_blast_toughness_damage, src.player_blast_toughness_damage)
merge_number_maps(dst.player_fire_toughness_damage, src.player_fire_toughness_damage)
merge_bool_maps(dst.player_blast_toughness_broken, src.player_blast_toughness_broken)
merge_bool_maps(dst.player_fire_toughness_broken, src.player_fire_toughness_broken)
merge_bool_maps(dst.player_blast_downs, src.player_blast_downs)
merge_bool_maps(dst.player_fire_downs, src.player_fire_downs)
merge_bool_maps(dst.player_blast_kills, src.player_blast_kills)
merge_bool_maps(dst.player_fire_kills, src.player_fire_kills)
merge_bool_maps(dst.player_catapults, src.player_catapults)
merge_bool_maps(dst.player_catapult_kills, src.player_catapult_kills)
for unit, recent in pairs(recent_player_barrel_impacts) do
if recent.incident_id == src.id then
recent.incident_id = dst.id
end
end
if src.source_unit and source_incident_ids[src.source_unit] == src.id then
source_incident_ids[src.source_unit] = dst.id
end
active_incidents[src.id] = nil
return dst
end

local function find_merge_candidate(position, btype, owner_name)
local best_incident, best_score, best_t
local now = main_time()
for _, incident in pairs(active_incidents) do
if incident.btype == btype and (not owner_name or same_name(incident.owner_name, owner_name) or same_name(incident.detonator_name, owner_name) or same_name(incident.igniter_name, owner_name)) then
if now - (incident.started_t or now) <= INCIDENT_MERGE_WINDOW then
local score = incident_detail_score(incident)
local valid_position = true
if position and incident.source_position then
valid_position = Vector3.distance_squared(position, incident.source_position:unbox()) <= INCIDENT_MATCH_RADIUS_SQ
end
if valid_position and (not best_incident or score > best_score or (score == best_score and (incident.started_t or 0) > best_t)) then
best_incident = incident
best_score = score
best_t = incident.started_t or 0
end
end
end
end
return best_incident
end

local function merge_duplicate_incidents()
local changed = true
while changed do
changed = false
local incidents = {}
for _, incident in pairs(active_incidents) do
incidents[#incidents + 1] = incident
end
for i = 1, #incidents do
local a = incidents[i]
if a and active_incidents[a.id] then
for j = i + 1, #incidents do
local b = incidents[j]
if b and active_incidents[b.id] and incidents_are_compatible(a, b) then
local a_score = incident_detail_score(a)
local b_score = incident_detail_score(b)
if b_score > a_score or (b_score == a_score and (b.started_t or 0) < (a.started_t or 0)) then
merge_incident_into(b, a)
a = b
else
merge_incident_into(a, b)
end
changed = true
break
end
end
end
if changed then
break
end
end
end
end

local function create_ad_hoc_incident(buffer_data, btype)
local attacker = buffer_data.attacking_unit
local owner_unit = resolved_player_unit(attacker)
local position = vector_from_box(buffer_data.hit_world_position)
local owner_name = player_name_from_unit(owner_unit or attacker) or "Someone"
local candidate = find_merge_candidate(position, btype, owner_name)
if candidate then
candidate.last_event_t = main_time()
if owner_unit then
candidate.igniter_unit = candidate.igniter_unit or owner_unit
candidate.igniter_name = candidate.igniter_name or owner_name
candidate.detonator_unit = candidate.detonator_unit or owner_unit
candidate.detonator_name = candidate.detonator_name or owner_name
candidate.owner_unit = candidate.owner_unit or owner_unit
candidate.owner_name = candidate.owner_name or owner_name
end
return candidate
end
return create_incident(nil, position, btype, owner_unit, owner_name, owner_unit, owner_name)
end



local function match_incident(buffer_data, profile_name)
local btype = barrel_type_from_profile(profile_name)
local attacker = buffer_data.attacking_unit
local direct_id = attacker and source_incident_ids[attacker]
if direct_id and active_incidents[direct_id] then
return active_incidents[direct_id]
end
local hit_position = vector_from_box(buffer_data.hit_world_position)
local by_position = nearest_incident_by_position(hit_position, btype)
if by_position then
return by_position
end
if BARREL_EXPLOSION_PROFILES[profile_name] and player_from_unit(attacker) then
return create_ad_hoc_incident(buffer_data, btype)
end
return nil
end

local function unit_key(unit)
return unit or false
end

local function sorted_keys(tbl)
local keys = {}
for key in pairs(tbl) do
keys[#keys + 1] = key
end
table.sort(keys)
return keys
end

local function exclude_self(incident, name)
return incident.owner_unit and player_name_from_unit(incident.owner_unit) == name
end

local function record_player_damage(targets, incident, player_name, damage)
if not player_name or damage <= 0 then return end
if exclude_self(incident, player_name) then return end
targets[player_name] = (targets[player_name] or 0) + damage
incident.last_event_t = main_time()
end

local function record_player_toughness_damage(targets, broken_targets, incident, player_name, damage, broke)
if not player_name or damage <= 0 then return end
if exclude_self(incident, player_name) then return end
if broke then
broken_targets[player_name] = true
targets[player_name] = nil
else
targets[player_name] = (targets[player_name] or 0) + damage
end
incident.last_event_t = main_time()
end

local function record_named_event(targets, incident, player_name)
if not player_name then return end
if exclude_self(incident, player_name) then return end
targets[player_name] = true
incident.last_event_t = main_time()
end

local function record_enemy_kill(incident, target_unit, phase)
if not target_unit then
if phase == "fire" then
incident.enemy_fire_kills = incident.enemy_fire_kills + 1
else
incident.enemy_blast_kills = incident.enemy_blast_kills + 1
end
incident.last_event_t = main_time()
return
end
local ids = phase == "fire" and incident.enemy_fire_ids or incident.enemy_blast_ids
local key = unit_key(target_unit)
if ids[key] then return end
ids[key] = true
if phase == "fire" then
incident.enemy_fire_kills = incident.enemy_fire_kills + 1
else
incident.enemy_blast_kills = incident.enemy_blast_kills + 1
end
incident.last_event_t = main_time()
end

local function remember_barrel_impact(incident, attacked_unit)
recent_player_barrel_impacts[attacked_unit] = {
incident_id = incident.id,
t = main_time(),
catapult_reported = false,
}
end

local function record_catapult_death(buffer_data)
local attacked_unit = buffer_data.attacked_unit
local recent = attacked_unit and recent_player_barrel_impacts[attacked_unit]
if not recent or main_time() - recent.t > CATAPULT_WINDOW then
return
end
local incident = active_incidents[recent.incident_id]
if not incident then
return
end
local player_name = player_name_from_unit(attacked_unit)
if not player_name or incident.player_catapult_kills[player_name] then
return
end
incident.player_catapults[player_name] = nil
incident.player_catapult_kills[player_name] = true
recent.catapult_reported = true
incident.last_event_t = main_time()
end

local function join_names(names)
local count = #names
if count == 0 then
return ""
end
if count == 1 then
return names[1]
end
if count == 2 then
return names[1] .. " and " .. names[2]
end
return table.concat(names, ", ", 1, count - 1) .. ", and " .. names[count]
end

local function grouped_target_phrase(targets, singular_verb, plural_verb)
if #targets == 0 then
return nil
end
if #targets == 1 then
return targets[1] .. " " .. singular_verb
end
return join_names(targets) .. " " .. plural_verb
end

local function format_grouped_catapults(incident, target_map, death)
local targets = {}
for _, name in ipairs(sorted_keys(target_map)) do
if incident.owner_unit and player_name_from_unit(incident.owner_unit) == name then
targets[#targets + 1] = "themselves"
else
targets[#targets + 1] = name
end
end
if #targets == 0 then
return nil
end
local owner_name = incident.owner_name
if owner_name then
local action = death and "likely catapulted" or "catapulted"
local suffix = death and (#targets == 1 and " to their death" or " to their deaths") or ""
return string.format("%s %s %s%s", owner_name, action, join_names(targets), suffix)
end
return grouped_target_phrase(targets, death and "was likely catapulted to their death" or "was catapulted", death and "were likely catapulted to their deaths" or "were catapulted")
end

local function incident_headline(incident)
local igniter_name = incident.igniter_name
local detonator_name = incident.detonator_name or incident.owner_name
local headline
if igniter_name and detonator_name then
if igniter_name == detonator_name then
headline = string.format("%s ignited & detonated %s", detonator_name, incident.barrel_name)
else
headline = string.format("%s ignited & %s detonated %s", igniter_name, detonator_name, incident.barrel_name)
end
elseif detonator_name then
headline = string.format("%s detonated %s", detonator_name, incident.barrel_name)
elseif igniter_name then
headline = string.format("%s ignited %s", igniter_name, incident.barrel_name)
else
headline = string.format("Someone detonated %s", incident.barrel_name)
end
local total_enemy_kills = incident.enemy_blast_kills + incident.enemy_fire_kills
if total_enemy_kills > 0 then
headline = string.format("%s killing %d enem%s", headline, total_enemy_kills, total_enemy_kills == 1 and "y" or "ies")
end
return headline
end

local function record_catapult(incident, attacked_unit)
local recent = attacked_unit and recent_player_barrel_impacts[attacked_unit]
if not recent or recent.incident_id ~= incident.id or recent.catapult_reported then
return
end
local player_name = player_name_from_unit(attacked_unit)
if not player_name or incident.player_catapults[player_name] or incident.player_catapult_kills[player_name] then
return
end
incident.player_catapults[player_name] = true
recent.catapult_reported = true
incident.last_event_t = main_time()
end

local function finalise_incident(incident)
local parts = {}
if mod:get("show_damage") then
for _, name in ipairs(sorted_keys(incident.player_blast_toughness_broken)) do
parts[#parts + 1] = string.format("Broke %s’s Toughness", name)
end
for _, name in ipairs(sorted_keys(incident.player_fire_toughness_broken)) do
parts[#parts + 1] = string.format("Barrel fire broke %s’s Toughness", name)
end
for _, name in ipairs(sorted_keys(incident.player_blast_toughness_damage)) do
parts[#parts + 1] = string.format("Dealt %d toughness damage to %s", math.floor(incident.player_blast_toughness_damage[name] + 0.5), name)
end
for _, name in ipairs(sorted_keys(incident.player_fire_toughness_damage)) do
parts[#parts + 1] = string.format("Barrel fire dealt %d toughness damage to %s", math.floor(incident.player_fire_toughness_damage[name] + 0.5), name)
end
local catapults = format_grouped_catapults(incident, incident.player_catapults, false)
if catapults then
parts[#parts + 1] = catapults
end
for _, name in ipairs(sorted_keys(incident.player_blast_damage)) do
parts[#parts + 1] = string.format("Hurt %s by %d hp", name, math.floor(incident.player_blast_damage[name] + 0.5))
end
for _, name in ipairs(sorted_keys(incident.player_fire_damage)) do
parts[#parts + 1] = string.format("Barrel fire hurt %s by %d hp", name, math.floor(incident.player_fire_damage[name] + 0.5))
end
local blast_downs = sorted_keys(incident.player_blast_downs)
if #blast_downs > 0 then
parts[#parts + 1] = string.format("Downed %s", join_names(blast_downs))
end
local fire_downs = sorted_keys(incident.player_fire_downs)
if #fire_downs > 0 then
parts[#parts + 1] = string.format("Barrel fire downed %s", join_names(fire_downs))
end
local blast_kills = sorted_keys(incident.player_blast_kills)
if #blast_kills > 0 then
parts[#parts + 1] = string.format("Killed %s", join_names(blast_kills))
end
local fire_kills = sorted_keys(incident.player_fire_kills)
if #fire_kills > 0 then
parts[#parts + 1] = string.format("Barrel fire killed %s", join_names(fire_kills))
end
local catapult_kills = format_grouped_catapults(incident, incident.player_catapult_kills, true)
if catapult_kills then
parts[#parts + 1] = catapult_kills
end
end
local msg = incident_headline(incident)
if #parts > 0 then
msg = msg .. " • " .. table.concat(parts, " • ")
end
overlay(incident.colour, msg)
active_incidents[incident.id] = nil
if incident.source_unit and source_incident_ids[incident.source_unit] == incident.id then
source_incident_ids[incident.source_unit] = nil
end
end

mod:hook_safe("StateGameplay", "on_enter", function()
reset_state()
end)

mod:hook_safe("HazardPropExtension", "add_damage", function(self, damage_amount, hit_actor, attack_direction, attacking_unit)
local unit = self._unit
local btype = barrel_type_from_content(self._content)
local meta = update_barrel_owner_meta(unit, btype, attacking_unit)
if meta.detonator_name then
sync_incident_owner_meta(unit)
end
end)

mod:hook_safe("HazardPropExtension", "set_current_state", function(self, state)
local unit = self._unit
if state == "idle" then
barrel_state_seen[unit] = nil
return
end
local current = barrel_state_seen[unit]
local meta = barrel_owner_by_unit[unit]
local btype = meta and meta.btype or barrel_type_from_content(self._content)
if not meta then
meta = {
owner_name = "Someone",
owner_unit = nil,
btype = btype,
barrel_name = barrel_name_from_type(btype),
colour = colour_for_type(btype),
}
barrel_owner_by_unit[unit] = meta
end
if state == "triggered" and current ~= "triggered" then
barrel_state_seen[unit] = "triggered"
elseif state == "broken" and current ~= "broken" then
get_or_create_barrel_incident(unit)
sync_incident_owner_meta(unit)
barrel_state_seen[unit] = "broken"
end
end)

mod:hook(Damage, "deal_damage", function(func, unit, breed_or_nil, attacking_unit, attacking_unit_owner_unit, attack_result, attack_type, damage_profile, damage, permanent_damage, tougness_damage, hit_actor, attack_direction, hit_zone_name, herding_template_or_nil, is_critical_strike, damage_type, hit_world_position_or_nil, wounds_shape_or_nil, instakill, damage_absorbed)
local hazard_prop_extension = ScriptUnit.has_extension(unit, "hazard_prop_system")
if hazard_prop_extension then
local btype = barrel_type_from_content(hazard_prop_extension._content)
local meta = update_barrel_owner_meta(unit, btype, attacking_unit_owner_unit or attacking_unit)
if meta.detonator_name then
sync_incident_owner_meta(unit)
end
end
local actual_damage_dealt = func(unit, breed_or_nil, attacking_unit, attacking_unit_owner_unit, attack_result, attack_type, damage_profile, damage, permanent_damage, tougness_damage, hit_actor, attack_direction, hit_zone_name, herding_template_or_nil, is_critical_strike, damage_type, hit_world_position_or_nil, wounds_shape_or_nil, instakill, damage_absorbed)
local profile_name = damage_profile and damage_profile.name
if not profile_name or damage ~= 0 or permanent_damage ~= 0 or not tougness_damage or tougness_damage <= 0 then
return actual_damage_dealt
end
local phase
if BARREL_EXPLOSION_PROFILES[profile_name] then
phase = "blast"
elseif BARREL_FIRE_PROFILES[profile_name] then
phase = "fire"
else
return actual_damage_dealt
end
local player = player_from_unit(unit)
if not player then
return actual_damage_dealt
end
local incident = match_incident({attacking_unit = attacking_unit, attacked_unit = unit, hit_world_position = hit_world_position_or_nil and Vector3Box(hit_world_position_or_nil) or nil}, profile_name)
if not incident then
return actual_damage_dealt
end
local player_name = safe_player_name(player)
local broke = attack_result == attack_results.toughness_broken
if phase == "blast" then
record_player_toughness_damage(incident.player_blast_toughness_damage, incident.player_blast_toughness_broken, incident, player_name, tougness_damage, broke)
remember_barrel_impact(incident, unit)
else
record_player_toughness_damage(incident.player_fire_toughness_damage, incident.player_fire_toughness_broken, incident, player_name, tougness_damage, broke)
end
return actual_damage_dealt
end)

mod:hook_safe("AttackReportManager", "_process_attack_result", function(self, buffer_data)
local attacked_unit = buffer_data.attacked_unit
local hazard_prop_extension = ScriptUnit.has_extension(attacked_unit, "hazard_prop_system")
if hazard_prop_extension then
local profile_name = buffer_data.damage_profile and buffer_data.damage_profile.name
local btype = barrel_type_from_profile(profile_name) or barrel_type_from_content(hazard_prop_extension._content)
local meta = update_barrel_owner_meta(attacked_unit, btype, buffer_data.attacking_unit)
if meta.detonator_name then
sync_incident_owner_meta(attacked_unit)
end
end
local damage_profile = buffer_data.damage_profile
local profile_name = damage_profile and damage_profile.name
if not profile_name then
return
end
if OFF_NAVMESH_PROFILES[profile_name] and buffer_data.attack_result == attack_results.died then
record_catapult_death(buffer_data)
return
end
local phase
if BARREL_EXPLOSION_PROFILES[profile_name] then
phase = "blast"
elseif BARREL_FIRE_PROFILES[profile_name] then
phase = "fire"
else
return
end
local incident = match_incident(buffer_data, profile_name)
if not incident then
return
end
incident.last_event_t = main_time()
local owner_unit = resolved_player_unit(buffer_data.attacking_unit)
if owner_unit then
incident.detonator_unit = incident.detonator_unit or owner_unit
incident.detonator_name = incident.detonator_name or player_name_from_unit(owner_unit) or incident.detonator_name
incident.owner_unit = incident.detonator_unit or incident.owner_unit
incident.owner_name = incident.detonator_name or incident.owner_name
end
local attacked_unit = buffer_data.attacked_unit
local player = player_from_unit(attacked_unit)
if player then
local player_name = safe_player_name(player)
if phase == "blast" then
record_player_damage(incident.player_blast_damage, incident, player_name, buffer_data.damage or 0)
remember_barrel_impact(incident, attacked_unit)
if buffer_data.attack_result == attack_results.knock_down then
record_named_event(incident.player_blast_downs, incident, player_name)
elseif buffer_data.attack_result == attack_results.died then
record_named_event(incident.player_blast_kills, incident, player_name)
end
else
record_player_damage(incident.player_fire_damage, incident, player_name, buffer_data.damage or 0)
if buffer_data.attack_result == attack_results.knock_down then
record_named_event(incident.player_fire_downs, incident, player_name)
elseif buffer_data.attack_result == attack_results.died then
record_named_event(incident.player_fire_kills, incident, player_name)
end
end
elseif buffer_data.attack_result == attack_results.died then
record_enemy_kill(incident, attacked_unit, phase)
end
end)

mod:hook_safe("StateGameplay", "update", function(self, dt, t)
for player_unit, recent in pairs(recent_player_barrel_impacts) do
if not ALIVE[player_unit] or t - recent.t > CATAPULT_WINDOW then
recent_player_barrel_impacts[player_unit] = nil
else
local incident = active_incidents[recent.incident_id]
if not incident then
recent_player_barrel_impacts[player_unit] = nil
elseif not recent.catapult_reported then
local unit_data_extension = ScriptUnit.has_extension(player_unit, "unit_data_system")
local character_state_component = unit_data_extension and unit_data_extension:read_component("character_state")
if character_state_component and PlayerUnitStatus.is_catapulted(character_state_component) then
record_catapult(incident, player_unit)
end
end
end
end
local to_finalise = {}
merge_duplicate_incidents()
for id, incident in pairs(active_incidents) do
local quiet_elapsed = t - incident.last_event_t
local total_elapsed = t - incident.started_t
if quiet_elapsed >= (incident.quiet_delay or QUIET_DELAY) or total_elapsed >= incident.max_age then
to_finalise[#to_finalise + 1] = id
end
end
for i = 1, #to_finalise do
local incident = active_incidents[to_finalise[i]]
if incident then
finalise_incident(incident)
end
end
end)
