-- HavocPost v1.0.0
-- Posts your current Havoc assignment info to the Strike Team chat using /havoc
-- Hooks HavocPlayView to cache the terminal order and read the rendered map name.
-- Author: TIIGRR

local mod = get_mod("HavocPost")

local STR = {
    no_chat      = "[HavocPost] Error: Chat manager unavailable.",
    send_failed  = "[HavocPost] Error: Chat send failed.",
    no_player    = "[HavocPost] Error: Could not get local player.",
    no_character = "[HavocPost] Error: Could not resolve character ID.",
    no_service   = "[HavocPost] Error: Havoc service not found.",
    fetch_failed = "[HavocPost] Error: Could not fetch Havoc data.",
    no_data      = "[HavocPost] Error: No Havoc assignment found. Open the Havoc terminal first.",
    promise_err  = "[HavocPost] Error",
    posted_ok    = "[HavocPost] Havoc info posted to Strike Team chat.",
    loaded_hint  = "[HavocPost] Loaded — type /havoc to post your Havoc assignment.",
}

-- ─── Cache ───────────────────────────────────────────────────────────────────
local _cached_order = nil   -- havoc_order table from the terminal
local _cached_view  = nil   -- HavocPlayView instance (to read map name)
local _cached_circs = nil   -- circ names read from grid while terminal is open

-- Fires every frame while the terminal is open.
-- Reads circ names from the grid widgets immediately (they clear on close).
mod:hook_safe(CLASS.HavocPlayView, "_update_can_play", function(self)
    local order = self._parent and self._parent.havoc_order
    if type(order) == "table" and order.id then
        _cached_order = order
        _cached_view  = self
        -- Read circ names and icon slugs now while grid is populated.
        -- Icon slug is used to identify and optionally filter specific circs.
        local grid = self._mission_detail_grid
        if type(grid) == "table" then
            local gw = grid._grid_widgets
            if type(gw) == "table" and #gw > 0 then
                local entries = {}
                for i = 1, #gw do
                    local w = gw[i]
                    if type(w) == "table" and w.type == "mutator"
                            and type(w.content) == "table" then
                        local header = w.content.header
                        local icon   = w.content.icon or ""
                        if type(header) == "string" and #header > 0 then
                            entries[#entries + 1] = {
                                name      = header,
                                icon_slug = icon:match("([^/]+)$") or "",
                            }
                        end
                    end
                end
                if #entries > 0 then _cached_circs = entries end
            end
        end
    end
end)

-- ─── Map name ────────────────────────────────────────────────────────────────
local function get_map_from_view(view)
    if type(view) ~= "table" then return nil end
    local ok, name = pcall(function()
        return view._widgets_by_name
            and view._widgets_by_name.detail
            and view._widgets_by_name.detail.content
            and view._widgets_by_name.detail.content.header_title
    end)
    if ok and type(name) == "string" and #name > 0 then return name end
    return nil
end

-- Circ names are cached in the hook while the terminal grid is populated.

-- ─── Chat send ───────────────────────────────────────────────────────────────
local function try_send(chat_mgr, handle, message)
    if type(chat_mgr.send_channel_message) == "function" then
        if pcall(chat_mgr.send_channel_message, chat_mgr, handle, message) then return true end
        if pcall(chat_mgr.send_channel_message, chat_mgr, handle, message, false) then return true end
    end
    for _, method in ipairs({"send_message", "send_chat_message", "broadcast_message"}) do
        if type(chat_mgr[method]) == "function" then
            if pcall(chat_mgr[method], chat_mgr, handle, message) then return true end
        end
    end
    return false
end

local function send_team_chat(message)
    local chat_mgr = Managers.chat
    if not chat_mgr then
        mod:echo(STR.no_chat)
        return false
    end

    local sessions = rawget(chat_mgr, "_sessions") or rawget(chat_mgr, "sessions")
    if type(sessions) == "table" then
        -- First pass: prefer party/strike_team tagged channel
        for handle, session in pairs(sessions) do
            if type(session) == "table" then
                local tag = session.tag or session.channel_tag
                           or session.type or session.name or session.channel_type
                if tag and (tag:upper() == "PARTY" or tag:upper() == "STRIKE_TEAM" or tag:upper() == "TEAM") then
                    if try_send(chat_mgr, handle, message) then return true end
                end
            end
        end
        -- Second pass: try every session
        for handle in pairs(sessions) do
            if try_send(chat_mgr, handle, message) then return true end
        end
    end

    -- Last resort: numeric handles 1–4
    for h = 1, 4 do
        if try_send(chat_mgr, h, message) then return true end
    end

    mod:echo(STR.send_failed)
    return false
end

-- ─── Localize helper ─────────────────────────────────────────────────────────
local function try_localize(key)
    local ok, s = pcall(function() return Managers.localization:localize(key) end)
    if ok and s and s ~= key and not s:match("^<") then return s end
    return nil
end

-- ─── Named circumstances (havoc-circ-*) ──────────────────────────────────────
local function localize_circ_name(raw_id)
    local base = raw_id:gsub("^mutator_", "")
    for _, key in ipairs({
        "loc_havoc_" .. base .. "_name",
        "loc_havoc_mutator_" .. base .. "_name",
        "loc_circumstance_" .. base .. "_title",
        "loc_circumstance_mutator_" .. base .. "_title",
    }) do
        local s = try_localize(key)
        if s then return s end
    end
    return base:gsub("_", " ")
        :gsub("(%a)([%w_]*)", function(a, b) return a:upper() .. b end)
end

-- ─── Stat modifiers (havoc-mods-*) ───────────────────────────────────────────
local MOD_NAMES = {
    buff_elites                           = "Elite Health",
    buff_specials                         = "Specialist Health",
    buff_monsters                         = "Monstrosity Amount & Health",
    buff_horde                            = "Horde Hit Mass & Health",
    more_elites                           = "Elite Amount",
    more_ogryns                           = "Ogryn Amount",
    more_alive_specials                   = "Max Specialist Amount",
    melee_minion_attack_speed             = "Enemy Melee Attack Speed",
    ranged_minion_attack_speed            = "Enemy Ranged Attack Speed & Shots",
    melee_minion_permanent_damage         = "Enemy Melee Corruption Damage",
    melee_minion_power_level_buff         = "Enemy Melee Damage",
    horde_spawn_rate_increase             = "Horde Spawn Rate",
    terror_event_point_increase           = "Event Enemies Spawned",
    ammo_pickup_modifier                  = "Player Ammo Gained",
    reduce_toughness                      = "Player Toughness",
    reduce_toughness_regen                = "Player Toughness Regen Rate",
    reduce_health_and_wounds              = "Player Health",
    havoc_vent_speed_reduction            = "Player Vent Duration & Interval",
    positive_weakspot_damage_bonus        = "Player Weakspot Damage",
    positive_knocked_down_health_modifier = "Player Knocked Down Health",
    positive_reload_speed                 = "Player Reload Speed",
    positive_crit_chance                  = "Player Crit Chance",
    positive_movement_speed               = "Player Movement Speed",
    positive_attack_speed                 = "Player Attack Speed",
    positive_grenade_buff                 = "Player Grenades & Brain Burst",
}

local _modifier_templates = nil
local function get_mod_display(mod_name, tier)
    if _modifier_templates == nil then
        local ok, hs = pcall(require, "scripts/settings/havoc_settings")
        _modifier_templates = (ok and hs and hs.modifier_templates) or false
    end
    local base_name = MOD_NAMES[mod_name]
        or mod_name:gsub("_", " "):gsub("(%a)([%w_]*)", function(a, b) return a:upper() .. b end)
    if _modifier_templates and tier then
        local ok, val = pcall(function()
            local tpls = _modifier_templates[mod_name]
            if not tpls or not tpls[tier] then return nil end
            for _, v in pairs(tpls[tier]) do
                if type(v) == "number" then
                    local pct = math.floor(v * 100 + 0.5)
                    return (pct ~= v) and pct or v
                end
            end
        end)
        if ok and val then return base_name .. " " .. tostring(val) end
    end
    return base_name
end

-- ─── Flag parser ─────────────────────────────────────────────────────────────
local function parse_flags(flags)
    local circs, mods, faction = {}, {}, nil
    if type(flags) ~= "table" then return circs, mods, faction end

    local function process(flag)
        if type(flag) ~= "string" then return end
        local circ_id = flag:match("^havoc%-circ%-(.+)$")
        if circ_id then
            circs[#circs + 1] = localize_circ_name(circ_id)
            return
        end
        local mod_id = flag:match("^havoc%-mods%-(.+)$")
        if mod_id then
            local name, tier_str = mod_id:match("^(.+)%-(%d+)$")
            mods[#mods + 1] = name and get_mod_display(name, tonumber(tier_str))
                                    or get_mod_display(mod_id, nil)
            return
        end
        local fac = flag:match("^havoc%-faction%-(.+)$")
        if fac then
            faction = fac:gsub("_", " ")
                :gsub("(%a)([%w_]*)", function(a, b) return a:upper() .. b end)
        end
    end

    -- Dict {key=true} (terminal) or array {"key"} (service)
    local is_dict = false
    for k in pairs(flags) do if type(k) == "string" then is_dict = true; break end end

    if is_dict then
        local keys = {}
        for k in pairs(flags) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do process(k) end
    else
        for _, v in ipairs(flags) do process(v) end
    end

    return circs, mods, faction
end

-- ─── Format and post ─────────────────────────────────────────────────────────
local function post_order(order)
    if type(order) ~= "table" then return false end

    local blueprint  = type(order.blueprint) == "table" and order.blueprint or {}
    local rank       = (type(order.data) == "table" and order.data.rank) or order.rank or "?"
    local challenge  = blueprint.challenge or "?"
    local resistance = blueprint.resistance or "?"
    local charges    = order.charges
    local flags      = type(blueprint.flags) == "table" and blueprint.flags or {}

    local expiry_str
    local expiry_secs = tonumber(order.expiryInSeconds)
    if expiry_secs then
        local ok, ds = pcall(function() return os.date("!%m-%d %H:%M", expiry_secs) end)
        expiry_str = ok and ds or nil
    end

    local map_name = get_map_from_view(_cached_view) or "Unknown"

    -- Use circ entries cached from the grid while the terminal was open.
    -- Fall back to flag parsing if cache isn't populated yet.
    local circ_entries = _cached_circs
    local circ_names
    if circ_entries then
        local filtered = {}
        local hide_fading_light = not mod:get("show_fading_light")
        for _, entry in ipairs(circ_entries) do
            local is_fading_light = entry.icon_slug:find("fading_light", 1, true)
            if not (hide_fading_light and is_fading_light) then
                filtered[#filtered + 1] = entry.name
            end
        end
        circ_names = filtered
    else
        local fc; circ_names, fc = parse_flags(flags)
    end

    local parts = {}
    if mod:get("show_rank") then
        parts[#parts + 1] = "Rank " .. tostring(rank)
    end
    parts[#parts + 1] = map_name
    if charges and mod:get("show_charges") then
        parts[#parts + 1] = "Charges: " .. tostring(charges)
    end
    parts[#parts + 1] = #circ_names > 0 and table.concat(circ_names, ", ") or "None"

    local prefix = mod:get("show_havoc_tag") and "[HAVOC] " or ""
    send_team_chat(prefix .. table.concat(parts, " | "))
    if mod:get("show_status_messages") then
        mod:echo(STR.posted_ok)
    end
    return true
end

-- ─── Core ────────────────────────────────────────────────────────────────────
local function build_and_post_havoc_info()
    if _cached_order then
        local ok, err = pcall(post_order, _cached_order)
        if not ok then mod:echo(STR.promise_err .. ": " .. tostring(err)) end
        return
    end

    -- Fallback: fetch from service (map name will show as Unknown)
    local lp = Managers.player and Managers.player:local_player(1)
    if not lp then mod:echo(STR.no_player) return end
    local char_id = lp:character_id()
    if not char_id then mod:echo(STR.no_character) return end

    local svc
    pcall(function() svc = Managers.data_service and Managers.data_service.havoc end)
    if not svc then mod:echo(STR.no_service) return end

    local function try_promise(mname)
        if type(svc[mname]) ~= "function" then return nil end
        local ok, p = pcall(svc[mname], svc, char_id)
        if ok and type(p) == "table" and type(p.next) == "function" then return p end
        ok, p = pcall(svc[mname], svc)
        if ok and type(p) == "table" and type(p.next) == "function" then return p end
        return nil
    end

    local p = try_promise("current_order")
           or try_promise("personal_mission")
           or try_promise("havoc_order")
           or try_promise("get_order")
    if not p then mod:echo(STR.no_data) return end

    p:next(function(data)
        if type(data) ~= "table" then mod:echo(STR.no_data) return end
        local ok, err = pcall(post_order, data)
        if not ok then mod:echo(STR.promise_err .. ": " .. tostring(err)) end
    end):catch(function(err)
        mod:echo(STR.promise_err .. " (fetch): " .. tostring(err):sub(1, 120))
    end)
end

-- ─── Commands ────────────────────────────────────────────────────────────────
mod:command("havoc", "Post your Havoc assignment to Strike Team chat.", function()
    if _cached_order then
        if mod:get("show_status_messages") then
            mod:echo("[HavocPost] Using cached terminal order.")
        end
    else
        mod:echo("[HavocPost] No cached order — open the Havoc terminal first for map name. Trying service fallback...")
    end
    build_and_post_havoc_info()
end)

mod:command("havocinfo", "Debug: show what circ names and map the mod currently sees.", function()
    mod:echo("[HavocPost] _cached_view = " .. tostring(_cached_view ~= nil))
    mod:echo("[HavocPost] _cached_order = " .. tostring(_cached_order ~= nil))
    if not _cached_view then mod:echo("[HavocPost] No view cached.") return end
    local map = get_map_from_view(_cached_view)
    mod:echo("[HavocPost] map = " .. tostring(map))
    local grid = _cached_view._mission_detail_grid
    mod:echo("[HavocPost] _mission_detail_grid = " .. tostring(type(grid)))
    if type(grid) == "table" then
        local gw = grid._grid_widgets
        mod:echo("[HavocPost] _grid_widgets type=" .. type(gw) .. " count=" .. (type(gw)=="table" and tostring(#gw) or "?"))
        if type(gw) == "table" then
            for i = 1, #gw do
                local w = gw[i]
                if type(w) == "table" then
                    local header = type(w.content)=="table" and tostring(w.content.header) or "nil"
                    mod:echo("[HavocPost] widget["..i.."] type="..tostring(w.type).." header="..header)
                end
            end
        end
    end
    if _cached_circs then
        mod:echo("[HavocPost] circs: " .. table.concat(_cached_circs, ", "))
    else
        mod:echo("[HavocPost] _cached_circs = nil (fallback to flags)")
    end
end)

-- ─── Startup hint ────────────────────────────────────────────────────────────
mod:hook_safe(CLASS.StateMainMenu, "on_enter", function()
    if mod:get("show_startup_message") then
        mod:echo(STR.loaded_hint)
    end
end)