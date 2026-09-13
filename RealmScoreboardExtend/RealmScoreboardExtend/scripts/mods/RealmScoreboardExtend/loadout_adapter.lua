local ext = get_mod("RealmScoreboardExtend")
local E = ext:io_dofile("RealmScoreboardExtend/scripts/mods/RealmScoreboardExtend/equipment")
local A = {snapshots = {}, encoded = {}, fingerprints = {}, revision = 0}
local lm, api
local legacy_names = {Melee_1=true,Melee_2=true,Melee_perk=true,Melee_blessing_1=true,Melee_blessing_2=true,
    Range_1=true,Range_2=true,Range_perk=true,Range_blessing_1=true,Range_blessing_2=true,player_feat=true}
local old_ids = {}
for name in pairs(legacy_names) do old_ids[#old_ids+1] = "row_scoreboard_weapon_"..name end
for _, name in ipairs(old_ids) do legacy_names[name] = true end
legacy_names.row_scoreboard_player_feat, legacy_names.row_scoreboard_blank_1 = true, true
local metadata = "sr_equipment_snapshot_v1"
function A.enabled() return lm and (not lm.is_enabled or lm:is_enabled()) end
function A.settings_stamp()
    local values = {tostring(A.enabled())}
    if lm then
        for _, key in ipairs({"endview_scoreboard_weapons","endview_scoreboard_weapons_perk",
            "endview_scoreboard_weapons_blessing","endview_scoreboard_feat","player_feats_display_type","display_player_feats"}) do
            values[#values+1] = tostring(lm:get(key))
        end
        for i=1,4 do values[#values+1] = tostring(lm:get("player_Feats_order_"..i)) end
    end
    return table.concat(values,":")
end
function A.install()
    lm = get_mod("LoadoutMonitor")
    if not lm then return end
    local ItemUtils = require("scripts/utilities/items")
    local MasterItems = require("scripts/backend/master_items")
    api = {
        name = ItemUtils.display_name,
        feats = function(profile) return lm.get_player_feats and lm.get_player_feats(profile) end,
        trait = function(trait, category)
            local item = MasterItems.get_item(trait.id)
            if not item then return trait.id end
            if category == "perks" and item.trait then
                local text = ext.text.lookup(lm, "trait_" .. item.trait)
                if text then return text end
            end
            return ItemUtils.display_name(item)
        end,
    }
    -- The original collector only runs at EndView and blanks bots. This
    -- adapter owns these rows in every view; preserve its other HUD features.
    if lm.update_scoreboard then ext:hook(lm, "update_scoreboard", function() end) end
end
function A.clear()
    A.snapshots, A.encoded, A.fingerprints = {}, {}, {}
    A.revision = A.revision + 1
end
function A.capture(players)
    if not A.enabled() then return end
    for _, player in pairs(players or {}) do
        local key = ext.model.key(player, ext.roster)
        local profile = ext.model.value(player, "profile") or player._profile
        local fingerprint = E.fingerprint(profile)
        if fingerprint then fingerprint = fingerprint .. A.settings_stamp() end
        if key and fingerprint and fingerprint ~= A.fingerprints[key] then
            local snapshot = E.capture(profile, api, A.snapshots[key])
            local encoded = E.encode(snapshot)
            if encoded ~= A.encoded[key] then
                A.snapshots[key], A.encoded[key] = snapshot, encoded
                A.revision = A.revision + 1
            end
            A.fingerprints[key] = fingerprint
        end
    end
end
local function own(row) return row.name and row.name:find("sr_equipment_", 1, true) == 1 end
local function legacy(row)
    return row.mod == lm and lm ~= nil or legacy_names[row.name]
end
local function row(name, label, players, value)
    local r = {name="sr_equipment_"..name, text=label, mod=ext, is_text=true, data={},
        validation_type="ASC", iteration_type="ADD", visible=true}
    for _, player in ipairs(players) do
        local key = ext.model.key(player)
        if key then r.data[key] = {score=0, text=value(key) or "—"} end
    end
    return r
end
function A.append(groups, players, history, saving)
    local result, old, saved = {}, {}, {}
    local have_metadata = false
    for _, group in ipairs(groups) do
        local kept = {}
        for _, r in ipairs(group) do
            if r.name == metadata then
                have_metadata = true
                for key, data in pairs(r.data or {}) do saved[key] = E.decode(data.text_data or data.text) end
            elseif own(r) then
                -- Rebuild from the complete snapshot, never from capped rows.
            elseif legacy(r) then
                old[#old + 1] = r
            else kept[#kept + 1] = r end
        end
        if #kept > 0 then result[#result + 1] = kept end
    end
    if not A.enabled() and not have_metadata then return groups end
    if history and not have_metadata and #old > 0 then
        -- Old LoadoutMonitor histories contain text only; keep that evidence.
        local restored = {}
        for _, r in ipairs(old) do
            local copy = {}
            for key,value in pairs(r) do if key ~= "setting" then copy[key] = value end end
            restored[#restored+1] = copy
        end
        result[#result + 1] = restored
        return result
    end
    local snapshots = history and saved or A.snapshots
    local appended = {}
    local function add(name, label, fn)
        appended[#appended+1] = row(name, history and ext:localize(label) or label, players, fn)
    end
    local show_weapons = not lm or lm:get("endview_scoreboard_weapons") ~= false
    if show_weapons then
        for slot = 1, 2 do
            local function weapon(key) return snapshots[key] and snapshots[key].weapons[slot] end
            local prefix = slot == 1 and "melee" or "ranged"
            add(prefix, "equipment_"..prefix, function(key)
                local w = weapon(key)
                return w and w.name or ext:localize("equipment_missing")
            end)
            for _, kind in ipairs({{id="perks",setting="endview_scoreboard_weapons_perk",limit="equipment_perk_limit"},
                {id="traits",setting="endview_scoreboard_weapons_blessing",limit="equipment_blessing_limit"}}) do
                if not lm or lm:get(kind.setting) ~= false then
                    local cap = math.max(1, math.min(6, math.floor(tonumber(ext:get(kind.limit)) or 2)))
                    local maximum = 0
                    for _, player in ipairs(players) do
                        local w = weapon(ext.model.key(player))
                        maximum = math.max(maximum, w and #w[kind.id] or 0)
                    end
                    for i = 1, math.min(cap, math.max(1, maximum)) do
                        add(prefix.."_"..kind.id..i, "equipment_"..kind.id, function(key)
                            local w = weapon(key)
                            return w and E.trait_text(w[kind.id][i]) or "—"
                        end)
                    end
                    if maximum > cap then
                        add(prefix.."_"..kind.id.."_more", "equipment_"..kind.id, function(key)
                            local w = weapon(key)
                            local n = w and #w[kind.id] - cap or 0
                            return n > 0 and ext:localize("equipment_more", n) or "—"
                        end)
                    end
                end
            end
        end
    end
    if not lm or lm:get("endview_scoreboard_feat") ~= false then
        add("feats", "equipment_feats", function(key)
            return snapshots[key] and snapshots[key].feats or ext:localize("equipment_missing")
        end)
    end
    if saving then
        local r = row("snapshot_v1", "equipment_snapshot", players, function(key) return E.encode(snapshots[key]) end)
        r.visible = false
        appended[#appended + 1] = r
    end
    if #appended > 0 then result[#result + 1] = appended end
    return result
end
return A
