local Templates = require("scripts/settings/circumstance/circumstance_templates")
local Mutators = require("scripts/settings/mutator/mutator_templates")
local HavocTemplates = require("scripts/settings/circumstance/templates/havoc_circumstance_template")
local mod = get_mod("HavocConditionManager")
local Catalog = {}
local Auric = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/auric_conditions")
-- DMF reports the original file error and returns false when a module fails.
if type(Auric)~="table" then return end
-- Classify by the actual mechanic, not an alias containing "havoc".
local custom = {
    more_havoc_nurgle_blessing = {"maelstrom", "option_nurgle_blessing"},
    more_havoc_monster_specials = {"maelstrom", "option_monster_specials"},
    more_havoc_assault_force = {"maelstrom", "option_assault_force"},
    more_old_rotten_armor = {"havoc", "option_old_rotten_armor"},
    more_havoc_abhuman = {"event", "option_abhuman"},
    more_havoc_elite_army = {"event", "option_elite_army"},
    more_havoc_endless_hordes = {"event", "option_endless_hordes"},
    more_havoc_barrel_grounds = {"event", "option_barrel_grounds"},
    more_faction_switch = {"faction", "option_faction_switch"},
    more_faction_combined = {"faction", "option_faction_combined"},
}
-- Base event presets only: their difficulty/environment variants belong to those selectors.
-- These are existing engine IDs, so no additional network registration is needed.
local events = {
    abhuman_01=mod:localize("ui_001"), abhuman_explosions=mod:localize("ui_002"), barrel_grounds=mod:localize("ui_003"),
    barren=mod:localize("ui_004"), barren_odin=mod:localize("ui_005"), broker_stimms=mod:localize("ui_006"),
    communication_hack_01=mod:localize("ui_007"), elite_army=mod:localize("ui_008"), endless_hordes=mod:localize("ui_009"),
    leftover=mod:localize("ui_010"), moebian_21st_01=mod:localize("ui_011"), nurgle_explosion_01=mod:localize("ui_012"),
    plasma_smugglers_default=mod:localize("ui_013"), rotten_armor=mod:localize("ui_014"),
    saints_core=mod:localize("ui_015"), skulls_event_01=mod:localize("ui_016"), skulls_guns=mod:localize("ui_017"),
    rations_core=mod:localize("ui_018"), rations_destroy=mod:localize("ui_019"), rations_recover=mod:localize("ui_020"),
}
local function event_available(id)
    local template=Templates[id]
    if not events[id] or not template then return false,"missing circumstance" end
    if template.theme_tag~="default" or type(template.mutators)~="table" then return false,"not a standalone default-theme event" end
    for _,name in ipairs(template.mutators) do if not Mutators[name] then return false,"missing mutator "..name end end
    return true
end
Catalog.event_ids=events
local difficulties = {mutator_increased_difficulty=1, mutator_highest_difficulty=2}
Catalog.labels = {havoc=mod:localize("ui_021"), maelstrom=mod:localize("ui_022"), event=mod:localize("ui_023"), faction=mod:localize("ui_024")}
local order = {havoc=1, maelstrom=2, event=3, faction=4}
Catalog.category = function(id)
    if difficulties[id] then return nil end
    if Auric.entries[id] then return "maelstrom" end
    if custom[id] then return custom[id][1] end
    if event_available(id) then return "event" end
    if HavocTemplates[id] then return "havoc" end
end
Catalog.is_reference = function(id) return custom[id] ~= nil end
Catalog.environment_available = function(settings,mission,id)
    if id=="default" then return true end
    local allowed=settings.lookup.theme_circumstances_of_havoc_missions
    local template=Templates[id]
    if not (allowed and allowed[mission] and allowed[mission][id] and template) then return false end
    local theme=settings.lookup.theme_of_circumstances and settings.lookup.theme_of_circumstances[id]
    if not theme or template.theme_tag~=theme then return false end
    for _,mutator in ipairs(template.mutators or {}) do if not Mutators[mutator] then return false end end
    return true
end
Catalog.extend = function(settings)
    local wanted = {}
    for id in pairs(HavocTemplates) do wanted[id] = true end
    for id in pairs(custom) do wanted[id] = true end
    for id in pairs(Auric.entries) do wanted[id] = true end
    mod._event_skip_reasons=mod._event_skip_reasons or {}
    for id in pairs(events) do
        local available,reason=event_available(id)
        if available then wanted[id]=true
        elseif mod._event_skip_reasons[id]~=reason then
            mod._event_skip_reasons[id]=reason
            mod:info("Unavailable event %s: %s",id,reason)
        end
    end
    local ids, lookup = {}, {}
    for id in pairs(wanted) do
        local template = Templates[id]
        if Catalog.category(id) and template and type(template.mutators) == "table" then
            ids[#ids + 1] = id
            lookup[id] = true
            local display = settings.loc.havoc_circumstances[id] or settings.loc.circumstances[id]
            if custom[id] then display = mod:localize(custom[id][2]) end
            if custom[id] and (custom[id][1]=="maelstrom" or custom[id][1]=="event") then display=display..mod:localize("ui_025") end
            if Auric.entries[id] then display=Localize(Auric.entries[id].title) end
            if events[id] then
                local key=template.ui and template.ui.display_name
                display=key and Localize(key)
                if not display or display==key or display:find("unlocalized",1,true) then display=events[id] end
                display=display..mod:localize("ui_026")
            end
            if not display and template.ui and template.ui.display_name then display = Localize(template.ui.display_name) end
            settings.loc.havoc_circumstances[id] = display or id
        end
    end
    table.sort(ids, function(a,b)
        local ac,bc = order[Catalog.category(a)],order[Catalog.category(b)]
        if ac~=bc then return ac<bc end
        if Auric.entries[a] and Auric.entries[b] then return Auric.entries[a].order<Auric.entries[b].order end
        if (Auric.entries[a]~=nil)~=(Auric.entries[b]~=nil) then return Auric.entries[a]~=nil end
        return a<b
    end)
    -- Replace the lookup too: SoloPlay previously left difficulty entries in it.
    settings.lookup.havoc_circumstances = lookup
    settings.order.havoc_circumstances = ids
    return settings
end
Catalog.migrate_difficulty = function(selected,base_mod)
    local best = base_mod:get("havoc_difficulty_circumstance")
    local rank = difficulties[best] or 0
    for _,id in ipairs(selected) do
        if (difficulties[id] or 0)>rank then best=id; rank=difficulties[id] end
    end
    if rank>0 and best~=base_mod:get("havoc_difficulty_circumstance") then base_mod:set("havoc_difficulty_circumstance",best) end
end
return Catalog
