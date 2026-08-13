local mod = get_mod("improved_scoreboard_panel")

-- Caches commonly used global functions and tables to local references for faster access.
local pairs = pairs
local math_max = math.max
local math_floor = math.floor
local managers = Managers
local table_clear = table.clear
local string_format = string.format

-- ============================================================
-- VIEW CLASS: IMPROVED SCOREBOARD PANEL VIEW
-- A minimal UI view that enables the Psykhanium test overlay.
-- This view does not capture input and passes draw calls
-- through, managing its own overlay widgets independently.
-- ============================================================

-- Required for the test overlay in Psykhanium.
-- Defined here so it's available when the game's view system requires this file.
local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
local UISettings = mod:original_require("scripts/settings/ui/ui_settings")
local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")
local player_slot_colors = UISettings.player_slot_colors

-- Minimal view definition with only a screen scenegraph and no default widgets.
local definitions = {
    scenegraph_definition = {
        screen = UIWorkspaceSettings.screen,
    },
    widget_definitions = {},
}

-- Creates the ImprovedScoreboardPanelView class that inherits from BaseView.
local ISPV = class("ImprovedScoreboardPanelView", "BaseView")

-- Initializes the view with no cursor capture, pass-through input and draw, and an empty widget list.
ISPV.init = function(self, settings, context)
    self._no_cursor = true
    ISPV.super.init(self, definitions, settings, context)
    self._pass_draw = true
    self._pass_input = true
    self._isp_widgets = {}
end

-- Returns false so this view never captures keyboard or mouse focus from other views.
ISPV.is_using_input = function(self)
    return false
end

-- Builds the test overlay widgets when the view enters the active state.
ISPV.on_enter = function(self)
    ISPV.super.on_enter(self)
    mod:ISP_build_test_overlay(self)
end

-- Refreshes the test overlay widget data every frame while the view is active.
ISPV.update = function(self, dt, t, input_service, view_data)
    local pass_on_input, pass_on_draw = ISPV.super.update(self, dt, t, input_service)
    mod:ISP_refresh_test_overlay(self)
    return pass_on_input, pass_on_draw
end

-- Draws any active ISP overlay widgets within this view's render pass on top of other content.
ISPV.draw = function(self, dt, t, input_service, layer)
    ISPV.super.draw(self, dt, t, input_service, layer)
    if not self._isp_widgets or #self._isp_widgets == 0 then return end
    local render_settings = self._render_settings
    render_settings.start_layer = layer
    UIRenderer.begin_pass(self._ui_renderer, self._ui_scenegraph, input_service, dt, render_settings)
    if self._isp_stroke_widgets then
        for _, w in pairs(self._isp_stroke_widgets) do
            UIWidget.draw(w, self._ui_renderer)
        end
    end
    if self._isp_widgets then
        for _, w in pairs(self._isp_widgets) do
            UIWidget.draw(w, self._ui_renderer)
        end
    end
end

-- Destroys the overlay widgets when the view exits the active state.
ISPV.on_exit = function(self)
    mod:ISP_destroy_test_overlay(self)
    ISPV.super.on_exit(self)
end

-- Guard: if this file is re-required by the game's view system, return the class immediately.
if mod._isp_loaded then
    return ISPV
end
mod._isp_loaded = true
mod:add_require_path("improved_scoreboard_panel/scripts/mods/improved_scoreboard_panel/improved_scoreboard_panel")

-- Preload the scoreboard graph view module so the game's view system can require() it.
local VIEW_MODULE = "improved_scoreboard_panel/scripts/mods/improved_scoreboard_panel/improved_scoreboard_panel_graph"
local VIEW_NAME = "improved_scoreboard_graph_view"
local package_preload = package and package.preload
if package_preload and not package_preload[VIEW_MODULE] then
    package_preload[VIEW_MODULE] = function()
        return ImprovedScoreboardGraphView
    end
end

-- Register the scoreboard graph view so it can be opened with UIManager:open_view()
local Views = require("scripts/ui/views/views")
if not Views[VIEW_NAME] then
    Views[VIEW_NAME] = {
        name = VIEW_NAME,
        class = "ImprovedScoreboardGraphView",
        display_name = "mod_name_boring",
        path = VIEW_MODULE,
        package = "packages/ui/views/options_view/options_view",
        state_bound = true,
        allow_hud = false,
        disable_game_world = false,
        game_world_blur = 0,
        use_transition_ui = false,
    }
end

-- All tracked stat definitions
-- Each entry: name, localization key, sort direction (asc=higher is better), whether to abbreviate large numbers
mod.ISP_STAT_DEFS = {
    { key = "kills",          loc = "stat_kills",          min_loc = "stat_min_kills",          asc = true,  shorten = false },
    { key = "ranged_kills",   loc = "stat_ranged_kills",   min_loc = "stat_min_ranged_kills",   asc = true,  shorten = false },
    { key = "melee_kills",    loc = "stat_melee_kills",    min_loc = "stat_min_melee_kills",    asc = true,  shorten = false },
    { key = "headshots",      loc = "stat_headshots",      min_loc = "stat_min_headshots",      asc = true,  shorten = false },
    { key = "dmg_dealt",      loc = "stat_damage_dealt",   min_loc = "stat_min_damage_dealt",   asc = true,  shorten = true  },
    { key = "dmg_taken",      loc = "stat_damage_taken",   min_loc = "stat_min_damage_taken",   asc = false, shorten = true  },
    { key = "specials",       loc = "stat_specials",       min_loc = "stat_min_specials",       asc = true,  shorten = false },
    { key = "elites",         loc = "stat_elites",         min_loc = "stat_min_elites",         asc = true,  shorten = false },
    { key = "bosses",         loc = "stat_bosses",         min_loc = "stat_min_bosses",         asc = true,  shorten = false },
    { key = "boss_damage",    loc = "stat_boss_damage",    min_loc = "stat_min_boss_damage",    asc = true,  shorten = true  },
    { key = "revives",        loc = "stat_revives",        min_loc = "stat_min_revives",        asc = true,  shorten = false },
    { key = "rescues",        loc = "stat_rescues",        min_loc = "stat_min_rescues",        asc = true,  shorten = false },
    { key = "relics",         loc = "stat_relics",         min_loc = "stat_min_relics",         asc = true,  shorten = false },
    { key = "barrels_exploded", loc = "stat_barrels_exploded", min_loc = "stat_min_barrels_exploded", asc = true,  shorten = false },
}

-- ============================================================
-- HELPER: PLAYER NAME COLOR
-- ============================================================

-- Resolve a player's name color from their mission slot assignment.
-- Uses player:slot() to look up the color in UISettings.player_slot_colors,
-- the same source used by the game's own HUD archetype icons and CareerColourOutlines.
-- Falls back to a neutral light gray if the name pizazz toggle is off.
local function get_name_color(player, name_pizazz)
    if not name_pizazz then
        return { 255, 220, 220, 220 }
    end
    local slot = player:slot()
    local slot_color = player_slot_colors and player_slot_colors[slot]
    if slot_color then
        return { slot_color[1], slot_color[2], slot_color[3], slot_color[4] }
    end
    return { 255, 220, 220, 220 }
end

-- ============================================================
-- RUNTIME DATA STORES
-- Tables that hold all tracked statistics, enemy health state,
-- and attacker references during a mission.
-- ============================================================

-- Per-player stat accumulator, keyed by account ID: { [account_id] = { kills = 0, dmg_dealt = 0, ... } }
mod.ISP_player_stats = {}

-- Track health per enemy unit for accurate damage accounting.
mod.ISP_enemy_health = {}
mod.ISP_last_attacker = {}
mod.ISP_prev_damage = {}

-- Track which player last damaged each barrel unit.
mod.ISP_barrel_attacker = {}

-- ============================================================
-- UTILITY HELPERS
-- Small reusable functions that support the core stat tracking
-- and overlay rendering logic throughout this file.
-- ============================================================

-- Returns the account ID for a player, falling back to the player's display name if no account ID exists.
function mod:ISP_account_id(player)
    return player:account_id() or player:name()
end

-- Returns the account ID of the local player, or an empty string if no local player is available.
function mod:ISP_local_id()
    if not self.player_manager then return "" end
    local ok, lp = pcall(self.player_manager.local_player, self.player_manager, 1)
    if not ok or not lp then return "" end
    return self:ISP_account_id(lp)
end

-- Returns the persistent character ID of the local player, or nil.
-- This is the unique character identifier (not the account UUID), so it
-- correctly distinguishes different characters of the same player.
function mod:ISP_character_id()
    if not self.player_manager then return nil end
    local ok, lp = pcall(self.player_manager.local_player, self.player_manager, 1)
    if not ok or not lp then return nil end
    local cid = lp:character_id()
    if not cid then
        local profile = lp:profile()
        cid = profile and profile.character_id
    end
    if cid and cid ~= "" then
        return cid
    end
    return nil
end

-- Looks up a player object by their in-world unit. Returns nil if no player is found for that unit.
function mod:ISP_lookup_player(unit)
    if not unit then return nil end
    for _, p in pairs(managers.player:players()) do
        if p.player_unit == unit then return p end
    end
    return nil
end

-- Gets a saved setting value, or returns the default if not yet configured.
function mod:_ISP_get_opt(id, default)
    local v = mod:get(id)
    if v == nil then return default end
    return v
end

-- Shorten large numbers: 1234 -> "1.2K", 1234567 -> "1.2M"
function mod:ISP_format_num(val)
    local abs_v = math.abs(val)
    if abs_v >= 1000000 then
        return string_format("%.1fM", val / 1000000)
    elseif abs_v >= 1000 then
        return string_format("%.1fK", val / 1000)
    end
    return string_format("%.0f", val)
end

-- ============================================================
-- TEST MODE FAKE PLAYER HELPERS
-- Creates simulated player objects for previewing the scoreboard
-- layout in the Psykhanium (Meat Grinder / Training Area).
-- ============================================================

-- Test mode helpers: fake players for layout preview
local TEST_NAMES = { "PlayerOne", "PlayerTwo", "PlayerThree", "PlayerFour" }
local TEST_ARCHETYPES = { "veteran", "zealot", "psyker", "ogryn" }

-- Creates a fake player object with the given name, archetype, and slot number for test mode previews.
local function make_fake_player(name, archetype, slot)
    return {
        _name = name,
        _archetype = archetype,
        account_id = function(self) return "test_" .. self._name end,
        name = function(self) return self._name end,
        profile = function(self) return { archetype = { name = self._archetype } } end,
        slot = function(self) return slot end,
    }
end

-- Ensure a player entry exists in the stats table
function mod:ISP_ensure_player(aid)
    if not self.ISP_player_stats[aid] then
        self.ISP_player_stats[aid] = {}
    local active_stats = mod:_ISP_active_stats()
    for _, def in pairs(active_stats) do
            self.ISP_player_stats[aid][def.key] = 0
        end
    end
end

-- Add a value to a player's tracked stat
function mod:ISP_add_stat(aid, stat_key, amount)
    if amount <= 0 then return end
    self:ISP_ensure_player(aid)
    self.ISP_player_stats[aid][stat_key] = (self.ISP_player_stats[aid][stat_key] or 0) + amount
end

-- Return only stat definitions whose display toggle is enabled
function mod:_ISP_active_stats()
    local result = {}
    for _, def in pairs(self.ISP_STAT_DEFS) do
        if mod:get("track_stat_" .. def.key) ~= false then
            result[#result + 1] = def
        end
    end
    return result
end

-- Reset all stats (called when entering gameplay)
function mod:ISP_reset_stats()
    table_clear(self.ISP_player_stats)
    table_clear(self.ISP_enemy_health)
    table_clear(self.ISP_last_attacker)
    table_clear(self.ISP_prev_damage)
    table_clear(self.ISP_barrel_attacker)
end

-- ============================================================
-- GRAPH DATA PERSISTENCE
-- Single shared file (graph_data_account.txt) stores all
-- character data with char_id-tagged records. All mutations
-- happen in-memory (_isp_full_data). Disk writes only happen
-- once at game exit (StateTitle enter), eliminating I/O lag
-- during gameplay, loading screens, and hub.
-- ============================================================

-- Use the game's native Lua IO (Mods.lua.io) since the global `io` table
-- is removed by the sandbox. For reading, Mods.lua.io.open + file:read works.
-- For writing, the same handle supports :write.
local _LuaIO = Mods.lua.io
local _LuaOS = Mods.lua.os

local function graph_data_dir()
    local appdata = _LuaOS.getenv("APPDATA")
    return appdata .. "\\Fatshark\\Darktide\\improved_scoreboard_panel"
end

local _graph_dir_ensured = false

local function ensure_graph_dir()
    if _graph_dir_ensured then return end
    local dir = graph_data_dir()
    pcall(_LuaOS.execute, 'mkdir "' .. dir .. '" 2>nul')
    _graph_dir_ensured = true
end

-- Path to the single shared account-wide data file
local function graph_data_account_path()
    return graph_data_dir() .. "\\graph_data_account.txt"
end

-- Legacy per-character file path (used only for migration)
local function graph_data_char_path(char_id)
    return graph_data_dir() .. "\\graph_data_" .. char_id .. ".txt"
end

-- ============================================================
-- NEW FORMAT: Single shared file with char_id-tagged records.
-- File format:
--   # --- missions ---
--   <tier>,<date>,<char_id>
--   # --- lifetime ---
--   <char_id>,<key>=<value>
--   # --- cumulative ---
--   <char_id>,<key>=<value>
-- ============================================================

local function parse_account_file(f)
    local data = { lifetime = {}, missions = {}, cumulative = {} }
    local section = "missions"
    for raw_line in f:lines() do
        local line = raw_line:match("^%s*(.-)%s*$")
        if line ~= "" then
            if line:sub(1, 1) == "#" then
                if line:lower():match("cumulative") then
                    section = "cumulative"
                elseif line:lower():match("lifetime") then
                    section = "lifetime"
                elseif line:lower():match("missions") then
                    section = "missions"
                end
            else
                if section == "missions" then
                    local tier_str, date, char_id = line:match("^(%d+),(.+),(.+)$")
                    if tier_str then
                        data.missions[#data.missions + 1] = {
                            date = date,
                            tier = tonumber(tier_str),
                            char_id = char_id,
                        }
                    end
                elseif section == "lifetime" then
                    local char_id, rest = line:match("^([^,]+),(.+)$")
                    if char_id and rest then
                        local key, val = rest:match("^([%w_]+)=(%-?%d+)$")
                        if key then
                            data.lifetime[char_id] = data.lifetime[char_id] or {}
                            data.lifetime[char_id][key] = tonumber(val) or 0
                        end
                    end
                elseif section == "cumulative" then
                    local char_id, rest = line:match("^([^,]+),(.+)$")
                    if char_id and rest then
                        local key, val = rest:match("^([%w_]+)=(%-?%d+)$")
                        if key then
                            data.cumulative[char_id] = data.cumulative[char_id] or {}
                            data.cumulative[char_id][key] = tonumber(val) or 0
                        end
                    end
                end
            end
        end
    end
    return data
end

local function save_account_file(data)
    ensure_graph_dir()
    local path = graph_data_account_path()
    local f = _LuaIO.open(path, "w")
    if f then
        for _, m in ipairs(data.missions or {}) do
            f:write(string.format("%d,%s,%s\n", m.tier or 0, m.date or "unknown", m.char_id or ""))
        end
        f:write("# --- lifetime ---\n")
        for char_id, char_data in pairs(data.lifetime or {}) do
            for key, val in pairs(char_data) do
                f:write(string.format("%s,%s=%d\n", char_id, key, val))
            end
        end
        f:write("# --- cumulative ---\n")
        for char_id, char_data in pairs(data.cumulative or {}) do
            for key, val in pairs(char_data) do
                f:write(string.format("%s,%s=%d\n", char_id, key, val))
            end
        end
        f:close()
    end
end

-- ============================================================
-- LEGACY FORMAT: Per-character files (for migration only).
-- Old format: tier,date per mission, lifetime/cumulative as key=value.
-- ============================================================

local function parse_legacy_char_file(f)
    local data = { lifetime = {}, missions = {}, cumulative = {} }
    local section = "lifetime"
    for raw_line in f:lines() do
        local line = raw_line:match("^%s*(.-)%s*$")
        if line ~= "" then
            if line:sub(1, 1) == "#" then
                if line:lower():match("cumulative") then section = "cumulative"
                elseif line:lower():match("lifetime") then section = "lifetime"
                end
            else
                local tier_str, date = line:match("^(%d+),(.+)$")
                if tier_str then
                    data.missions[#data.missions + 1] = { date = date, tier = tonumber(tier_str) }
                else
                    local key, val = line:match("^([%w_]+)=(%-?%d+)$")
                    if key then
                        if section == "cumulative" then
                            data.cumulative[key] = tonumber(val) or 0
                        else
                            data.lifetime[key] = tonumber(val) or 0
                        end
                    end
                end
            end
        end
    end
    return data
end

-- ============================================================
-- STARTUP: Load the single shared file into _isp_full_data.
-- Also migrates legacy per-character files on first run.
-- ============================================================

local function migrate_legacy_files(full_data)
    local migrated = 0

    -- Migrate known per-character files
    local known = mod:get("graph_known_ids") or ""
    if known ~= "" then
        for cid in known:gmatch("[^,]+") do
            local path = graph_data_char_path(cid)
            local f = _LuaIO.open(path, "r")
            if f then
                local char_data = parse_legacy_char_file(f)
                f:close()
                -- Migrate missions
                for _, m in ipairs(char_data.missions or {}) do
                    full_data.missions[#full_data.missions + 1] = {
                        date = m.date, tier = m.tier, char_id = cid,
                    }
                end
                -- Migrate lifetime
                full_data.lifetime[cid] = full_data.lifetime[cid] or {}
                for key, val in pairs(char_data.lifetime or {}) do
                    full_data.lifetime[cid][key] = (full_data.lifetime[cid][key] or 0) + val
                end
                -- Migrate cumulative
                full_data.cumulative[cid] = full_data.cumulative[cid] or {}
                for key, val in pairs(char_data.cumulative or {}) do
                    full_data.cumulative[cid][key] = (full_data.cumulative[cid][key] or 0) + val
                end
                migrated = migrated + 1
            end
        end
    end

    -- Legacy graph_data.txt fallback (no char_id — use "legacy" as placeholder)
    local legacy_path = graph_data_dir() .. "\\graph_data.txt"
    local f = _LuaIO.open(legacy_path, "r")
    if f then
        local legacy = parse_legacy_char_file(f)
        f:close()
        local cid = "legacy"
        full_data.missions[#full_data.missions + 1] = nil -- clear if empty
        for _, m in ipairs(legacy.missions or {}) do
            full_data.missions[#full_data.missions + 1] = {
                date = m.date, tier = m.tier, char_id = cid,
            }
        end
        full_data.lifetime[cid] = full_data.lifetime[cid] or {}
        for key, val in pairs(legacy.lifetime or {}) do
            full_data.lifetime[cid][key] = (full_data.lifetime[cid][key] or 0) + val
        end
        full_data.cumulative[cid] = full_data.cumulative[cid] or {}
        for key, val in pairs(legacy.cumulative or {}) do
            full_data.cumulative[cid][key] = (full_data.cumulative[cid][key] or 0) + val
        end
        migrated = migrated + 1
    end

    -- Legacy graph_data_<accountUUID>.txt fallback
    -- NOTE: Do NOT call ISP_local_id() here — during on_all_mods_loaded the
    -- player isn't fully spawned yet and peer_id() can crash the engine (native
    -- access violation).  We can only use a previously-stored account UUID.
    local account_id = mod:get("legacy_account_id") or ""
    if account_id and account_id ~= "" then
        local acc_path = graph_data_dir() .. "\\graph_data_" .. account_id .. ".txt"
        f = _LuaIO.open(acc_path, "r")
        if f then
            local legacy = parse_legacy_char_file(f)
            f:close()
            local cid = account_id
            for _, m in ipairs(legacy.missions or {}) do
                full_data.missions[#full_data.missions + 1] = {
                    date = m.date, tier = m.tier, char_id = cid,
                }
            end
            full_data.lifetime[cid] = full_data.lifetime[cid] or {}
            for key, val in pairs(legacy.lifetime or {}) do
                full_data.lifetime[cid][key] = (full_data.lifetime[cid][key] or 0) + val
            end
            full_data.cumulative[cid] = full_data.cumulative[cid] or {}
            for key, val in pairs(legacy.cumulative or {}) do
                full_data.cumulative[cid][key] = (full_data.cumulative[cid][key] or 0) + val
            end
            migrated = migrated + 1
        end
    end

    if migrated > 0 then
        table.sort(full_data.missions, function(a, b) return a.date < b.date end)
        mod:info("[ISP] migrated " .. tostring(migrated) .. " legacy file(s) to shared format")
        save_account_file(full_data)
    end

    return migrated
end

-- Loads the single shared file into _isp_full_data, migrating legacy files if needed.
function mod:_ISP_load_full_data()
    local full_data = { lifetime = {}, missions = {}, cumulative = {} }
    -- Try new format first
    local path = graph_data_account_path()
    local f = _LuaIO.open(path, "r")
    if f then
        full_data = parse_account_file(f)
        f:close()
    else
        -- No new file found — check for legacy files to migrate
        migrate_legacy_files(full_data)
    end
    return full_data
end

-- Filters the full data to per-character or account-wide for rendering.
function mod:_ISP_load_graph_data()
    local full = self._isp_full_data or { lifetime = {}, missions = {}, cumulative = {} }
    if mod:get("graph_per_character") then
        local char_id = mod:ISP_character_id()
        if char_id then
            local data = { lifetime = {}, missions = {}, cumulative = {} }
            for _, m in ipairs(full.missions or {}) do
                if m.char_id == char_id then
                    data.missions[#data.missions + 1] = { date = m.date, tier = m.tier }
                end
            end
            data.lifetime = full.lifetime and full.lifetime[char_id] or {}
            data.cumulative = full.cumulative and full.cumulative[char_id] or {}
            return data
        end
        return { lifetime = {}, missions = {}, cumulative = {} }
    else
        -- Account-wide: sum all characters
        local data = { lifetime = {}, missions = {}, cumulative = {} }
        for _, m in ipairs(full.missions or {}) do
            data.missions[#data.missions + 1] = { date = m.date, tier = m.tier }
        end
        for _, char_data in pairs(full.lifetime or {}) do
            for key, val in pairs(char_data) do
                data.lifetime[key] = (data.lifetime[key] or 0) + val
            end
        end
        for _, char_data in pairs(full.cumulative or {}) do
            for key, val in pairs(char_data) do
                data.cumulative[key] = (data.cumulative[key] or 0) + val
            end
        end
        return data
    end
end

-- In-memory save: updates _isp_full_data. No disk I/O.
-- Disk writes happen only at game exit via save_account_file().
function mod:_ISP_save_graph_data(data)
    -- This function is now a no-op for disk I/O.
    -- All data mutations go through _isp_full_data directly.
    -- Kept as a stub so existing call sites don't error.
end

-- Applies session report rewards (XP, dockets, plasteel, diamantine) to a data table's cumulative
-- section. Extracted as a helper so it can be called immediately or deferred when the report arrives late.
function mod:_ISP_apply_session_report_to_data(data, report)
    if not report or not data then return end
    local cumulative = data.cumulative
    if not cumulative then
        data.cumulative = {}
        cumulative = data.cumulative
    end
    -- Top-level reward fields (current game version: report.credits_reward, report.plasteel_reward, report.diamantine_reward)
    local cred_reward = report.credits_reward or 0
    if cred_reward > 0 then
        cumulative.dockets = (cumulative.dockets or 0) + cred_reward
    end
    local plas_reward = report.plasteel_reward or 0
    if plas_reward > 0 then
        cumulative.plasteel = (cumulative.plasteel or 0) + plas_reward
    end
    local diam_reward = report.diamantine_reward or 0
    if diam_reward > 0 then
        cumulative.diamantine = (cumulative.diamantine or 0) + diam_reward
    end

    local char = report.character
    if not char and report.team and report.team.participants and report.team.participants[1] then
        char = report.team.participants[1].character
    end
    if char then
        -- XP gained this mission
        local xp_gained = char.xpGained or (char.currentXp and char.startXp and (char.currentXp - char.startXp)) or 0
        if xp_gained > 0 then
            cumulative.xp = (cumulative.xp or 0) + xp_gained
        end
        -- Gained resource fields (fallback: char.plasteelGained, char.diamantineGained)
        local plas_gained = char.plasteelGained or 0
        if plas_gained > 0 then
            cumulative.plasteel = (cumulative.plasteel or 0) + plas_gained
        end
        local diam_gained = char.diamantineGained or 0
        if diam_gained > 0 then
            cumulative.diamantine = (cumulative.diamantine or 0) + diam_gained
        end
        -- Iterate reward cards to find the salary card and extract currency rewards.
        -- char.rewards is an array of reward cards (set by _parse_reward_cards).
        -- Each card has kind="salary" with an array of reward entries containing
        -- currency, amount_gained (the reward earned), and amount (nilled after parsing).
        if char.rewards then
            for _, card in ipairs(char.rewards) do
                if card.kind == "salary" and card.rewards then
                    for _, reward in ipairs(card.rewards) do
                        local amount = reward.amount_gained or reward.amount or 0
                        if amount > 0 then
                            if reward.currency == "credits" then
                                cumulative.dockets = (cumulative.dockets or 0) + amount
                            elseif reward.currency == "plasteel" then
                                cumulative.plasteel = (cumulative.plasteel or 0) + amount
                            elseif reward.currency == "diamantine" then
                                cumulative.diamantine = (cumulative.diamantine or 0) + amount
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Records the local player's highscores from the just-finished mission
-- into the in-memory _isp_full_data. No disk I/O — data is persisted
-- only at game exit via save_account_file().
function mod:_ISP_record_mission_highscores()
    local local_id = mod:ISP_local_id()
    if not local_id or local_id == "" then
        return
    end

    local rankings = mod.ISP_rankings
    local char_id = mod:ISP_character_id()
    if not char_id then return end

    local full = self._isp_full_data
    if not full then return end

    -- Ensure per-character tables exist
    full.cumulative[char_id] = full.cumulative[char_id] or {}
    full.lifetime[char_id] = full.lifetime[char_id] or {}

    -- Accumulate actual stat values from the just-finished mission
    local player_stats = mod.ISP_player_stats[local_id]
    if player_stats then
        for _, def in ipairs(mod.ISP_STAT_DEFS or {}) do
            local val = player_stats[def.key] or 0
            if val > 0 then
                full.cumulative[char_id][def.key] = (full.cumulative[char_id][def.key] or 0) + val
            end
        end
    end

    -- Capture mission rewards from the session report.
    -- May arrive asynchronously — set flag for deferred processing if nil.
    local progression_mgr = Managers.progression
    local report = progression_mgr and progression_mgr:session_report()
    if report then
        self:_ISP_apply_session_report_to_data({ cumulative = full.cumulative[char_id] }, report)
    else
        self._isp_deferred_rewards = true
    end

    local mission_count = 0
    if rankings then
        for _, def in pairs(mod.ISP_STAT_DEFS or {}) do
            local r = rankings[def.key]
            if r and r.best and r.best[local_id] then
                mission_count = mission_count + 1
                full.lifetime[char_id][def.key] = (full.lifetime[char_id][def.key] or 0) + 1
            end
        end
    end

    -- Detect mission failure so failed missions always show red (tier 1) on the grid
    local end_result = Managers.mechanism and Managers.mechanism:end_result()
    local mission_lost = end_result == "lost"

    local tier
    if mission_lost then
        tier = 1
    else
        local is_leader = mod.ISP_ranked_leader and mod.ISP_ranked_leader[local_id]
        tier = 1
        if mission_count >= 2 then tier = 2 end
        if mission_count >= 3 then tier = 3 end
        if is_leader then tier = 4 end
    end

    full.missions[#full.missions + 1] = {
        date = os.date("%Y-%m-%d"),
        tier = tier,
        char_id = char_id,
    }

    -- Flush pending cumulative data (crafting pickups, gear sales) into full data
    local pending = self._isp_pending_cumulative
    if pending then
        for resource_type, amount in pairs(pending) do
            if amount > 0 then
                full.cumulative[char_id][resource_type] = (full.cumulative[char_id][resource_type] or 0) + amount
            end
        end
        table_clear(pending)
    end

    -- Refresh display cache (no disk I/O)
    mod._isp_graph_data = mod:_ISP_load_graph_data()

    -- Sync XP from backend (session report xpGained is always 0).
    -- Writes in-memory only — persists at game exit.
    if not mod._isp_xp_syncing then
        mod._isp_xp_syncing = true
        local backend = Managers.backend
        if backend and backend.interfaces and backend.interfaces.progression then
            local promise = backend.interfaces.progression:get_progression("character", char_id)
            if promise and promise.next then
                promise:next(function(prog)
                    if prog and prog.currentXp then
                        full.cumulative[char_id].xp = prog.currentXp
                        mod._isp_graph_data = mod:_ISP_load_graph_data()
                    end
                    mod._isp_xp_syncing = nil
                end, function()
                    mod._isp_xp_syncing = nil
                end)
            else
                mod._isp_xp_syncing = nil
            end
        else
            mod._isp_xp_syncing = nil
        end
    end
end

-- Tracks ordo dockets earned from item sales at vendors and persists
-- them to the per-character cumulative stats file so they appear
-- alongside mission salary rewards in the cumulative display.
-- DEPRECATED: Use _ISP_track_resource_gained("dockets", amount) instead
-- which uses an in-memory pending buffer to avoid per-sale disk I/O.

-- ============================================================
-- HOOKS: BARREL TRACKING
-- Tracks which player damages each explosive barrel
-- and counts barrels exploded.
-- ============================================================

-- Track which player last damaged a barrel unit.
mod:hook_safe(CLASS.HazardPropExtension, "add_damage", function(self, damage_amount, hit_actor, attack_direction, attacking_unit)
    local unit = self._unit
    local player_spawn = Managers.state and Managers.state.player_unit_spawn
    if not player_spawn then return end
    if not attacking_unit then return end
    local player = player_spawn:owner(attacking_unit)
    if player then
        mod.ISP_barrel_attacker[unit] = mod:ISP_account_id(player)
    end
end)

-- Detect when a barrel explodes and attribute it to the last damager.
mod:hook(CLASS.HazardPropExtension, "set_current_state", function(func, self, state)
    local unit = self._unit
    local prev_state = self._current_state
    func(self, state)
    if state == "broken" and prev_state ~= "broken" then
        local aid = mod.ISP_barrel_attacker[unit]
        if not aid then
            local lp = mod.player_manager and mod.player_manager:local_player(1)
            if lp then
                aid = mod:ISP_account_id(lp)
            end
        end
        if aid then
            mod:ISP_add_stat(aid, "barrels_exploded", 1)
            mod.ISP_barrel_attacker[unit] = nil
        end
    elseif state == "idle" then
        mod.ISP_barrel_attacker[unit] = nil
    end
end)

-- ============================================================
-- HOOKS: STAT TRACKING
-- Intercepts game engine methods to capture real-time
-- performance data for all players during a mission.
-- ============================================================

-- Track damage dealt, kills, headshots, specials/elites
-- Hook: AttackReportManager.add_attack_result — Intercepts every attack result to record damage dealt, kills, headshots, and enemy type kills (specials, elites, bosses).
mod:hook(CLASS.AttackReportManager, "add_attack_result", function(func, self, ...)
    local args = { ... }
    local damage_profile = args[1]
    local attacked_unit = args[2]
    local attacking_unit = args[3]
    local attack_direction = args[4]
    local hit_world_position = args[5]
    local hit_weakspot = args[6]
    local damage = args[7]
    local attack_result = args[8]
    local attack_type = args[9]
    local damage_efficiency = args[10]

    local player = mod:ISP_lookup_player(attacking_unit)
    -- Indirect kill fallback: barrel explosions, DoT ticks, and other non-player
    -- attack sources. Credits the kill to the last player who interacted with the enemy.
    if not player and attacked_unit then
        local last_unit = mod.ISP_last_attacker[attacked_unit]
        if last_unit then
            player = mod:ISP_lookup_player(last_unit)
        end
    end
    if player then
        local aid = mod:ISP_account_id(player)
        if hit_weakspot then
            mod:ISP_add_stat(aid, "headshots", 1)
        end
        if attacked_unit then
            local ud_ext = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
            local breed = ud_ext and ud_ext:breed()
            local is_minion = breed and mod.Breed.is_minion(breed)

            if is_minion then
                mod.ISP_last_attacker[attacked_unit] = attacking_unit
                local prev_health = mod.ISP_enemy_health[attacked_unit]
                local h_ext = ScriptUnit.has_extension(attacked_unit, "health_system")
                local new_health = h_ext and h_ext:current_health()
                local actual = damage

                if attack_result == "damaged" then
                    if not prev_health then
                        prev_health = (new_health or 0) + damage
                    end
                    actual = math.min(damage, prev_health)
                    mod.ISP_enemy_health[attacked_unit] = new_health

                elseif attack_result == "died" then
                    if not prev_health then prev_health = damage end
                    actual = prev_health
                    mod.ISP_enemy_health[attacked_unit] = nil

                    mod:ISP_add_stat(aid, "kills", 1)
                    if attack_type == "ranged" or attack_type == "explosion" or attack_type == "buff" then
                        mod:ISP_add_stat(aid, "ranged_kills", 1)
                    elseif attack_type == "melee" then
                        mod:ISP_add_stat(aid, "melee_kills", 1)
                    end
                    local enemy_type = mod.Breed.enemy_type(breed)
                    if enemy_type == "special" then
                        mod:ISP_add_stat(aid, "specials", 1)
                    elseif enemy_type == "elite" then
                        mod:ISP_add_stat(aid, "elites", 1)
                    elseif enemy_type == "monster" or enemy_type == "captain" then
                        mod:ISP_add_stat(aid, "bosses", 1)
                    end
                end

                mod:ISP_add_stat(aid, "dmg_dealt", actual)
                local is_boss = breed and breed.is_boss
                if is_boss then
                    mod:ISP_add_stat(aid, "boss_damage", actual)
                end
            end
        end
    end

    return func(self, ...)
end)

-- Initialize enemy health when they spawn
-- Hook: HuskHealthExtension.init — Records the maximum health of enemies when their health extension is initialized, enabling accurate damage-overkill calculations.
mod:hook(CLASS.HuskHealthExtension, "init", function(func, self, ...)
    func(self, ...)
    local unit = select(1, ...)
    if unit then
        mod.ISP_enemy_health[unit] = self:max_health()
    end
end)

-- Track damage taken by players (delta from cumulative self._damage, captures all sources)
-- Uses 0.5 threshold to filter network quantization noise that can cause false deltas
-- Hook: PlayerHuskHealthExtension.fixed_update — Monitors cumulative damage on player health extensions to track damage taken via frame-by-frame deltas, filtering out network noise.
mod:hook(CLASS.PlayerHuskHealthExtension, "fixed_update", function(func, self, unit, dt, t, ...)
    func(self, unit, dt, t, ...)
    if unit then
        local player = mod:ISP_lookup_player(unit)
        if player then
            local aid = mod:ISP_account_id(player)
            local current = self._damage
            if current then
                if not mod.ISP_prev_damage then mod.ISP_prev_damage = {} end
                local prev = mod.ISP_prev_damage[aid] or current
                if current > prev + 0.5 then
                    mod:ISP_add_stat(aid, "dmg_taken", current - prev)
                end
                mod.ISP_prev_damage[aid] = current
            end
        end
    end
end)

-- Track revives and saves (interactions)
-- Hook: PlayerInteracteeExtension.stopped — Intercepts completed interactions to count revives, pull-ups, rescues, and net removals.
mod:hook(CLASS.PlayerInteracteeExtension, "stopped", function(func, self, result, ...)
    local InteractionSettings = mod:original_require("scripts/settings/interaction/interaction_settings")
    local interaction_results = InteractionSettings.results
    local itype = self:interaction_type() or ""

    if result == interaction_results.success then
        local unit = self._interactor_unit
        if unit then
            local player = mod:ISP_lookup_player(unit)
            if player then
                local aid = mod:ISP_account_id(player)
                if itype == "revive" then
                    mod:ISP_add_stat(aid, "revives", 1)
                elseif itype == "pull_up" or itype == "remove_net" or itype == "rescue" then
                    mod:ISP_add_stat(aid, "rescues", 1)
                end
            end
        end
    end
    func(self, result, ...)
end)

-- Track relic discoveries from pickups (grimoires, scriptures, tainted devices, skulls, martyr skulls) via the interactee extension on the pickup unit.
mod:hook_safe(CLASS.InteracteeExtension, "stopped", function(self, result, interactor_unit, t)
    local InteractionSettings = mod:original_require("scripts/settings/interaction/interaction_settings")
    if result == InteractionSettings.results.success and interactor_unit and Unit.alive(interactor_unit) and self._unit and Unit.alive(self._unit) then
        local pickup_type = Unit.get_data(self._unit, "pickup_type")
        if pickup_type then
            local player = mod:ISP_lookup_player(interactor_unit)

            -- Determine if this is a relic (all collectible/side-objective/event pickups)
            local is_relic = pickup_type == "collectible_01_pickup" -- martyr skull
                or pickup_type == "communications_hack_device" -- tainted comms device
                or pickup_type == "skulls_01_pickup" -- tainted skull
                or pickup_type == "stolen_rations_01_pickup_small" -- stolen rations (event)
                or pickup_type == "stolen_rations_01_pickup_medium" -- stolen rations (event)
                or pickup_type == "live_event_saints_01_pickup_small" -- holy relic (event)
                or pickup_type == "live_event_saints_01_pickup_medium" -- holy relic (event)
                or pickup_type == "live_event_saints_01_pickup_large" -- holy relic (event)
            if not is_relic then
                local Pickups = mod:original_require("scripts/settings/pickup/pickups")
                local pickup_def = Pickups and Pickups.by_name[pickup_type]
                if pickup_def then
                    is_relic = pickup_def.is_side_mission_pickup -- grimoire, scripture
                        or string.find(pickup_type, "stolen_rations", 1, true) == 1
                        or string.find(pickup_type, "live_event_saints", 1, true) == 1
                        or string.find(pickup_type, "live_event_leftover", 1, true) == 1
                end
            end
            if is_relic and player then
                mod:ISP_add_stat(mod:ISP_account_id(player), "relics", 1)
            end

            -- Track crafting material pickups (plasteel/diamantine) for cumulative totals
            local is_material = pickup_type == "small_metal" or pickup_type == "large_metal"
                or pickup_type == "small_platinum" or pickup_type == "large_platinum"
            if is_material and player then
                local amount
                if pickup_type == "small_metal" then
                    amount = 50
                elseif pickup_type == "large_metal" then
                    amount = 130
                elseif pickup_type == "small_platinum" then
                    amount = 25
                elseif pickup_type == "large_platinum" then
                    amount = 65
                end
                local resource_type = pickup_type:match("metal") and "plasteel" or "diamantine"
                if amount then
                    mod:_ISP_track_resource_gained(resource_type, amount)
                end
            end
        end
    end
end)

-- Track relic discoveries from destructibles (heretical idols, dark rites totems)
mod:hook(CLASS.DestructibleExtension, "_add_damage", function(func, self, damage_amount, attack_direction, force_destruction, attacking_unit)
    local had_collectible = self._collectible_data ~= nil
    local is_nurgle_totem = self._unit and Unit.alive(self._unit)
        and (Unit.get_data(self._unit, "collectible_type") == "nurgle_totem"
            or Unit.get_data(self._unit, "armor_data_name") == "nurgle_totem")
    func(self, damage_amount, attack_direction, force_destruction, attacking_unit)
    if not self._isp_relic_counted then
        local should_count = false
        if had_collectible then
            local health_after = self._destruction_info and self._destruction_info.health
            if health_after ~= nil and health_after <= 0 then
                should_count = true
            end
        elseif is_nurgle_totem then
            should_count = true
        end
        if should_count then
            self._isp_relic_counted = true
            local player
            if attacking_unit and Unit.alive(attacking_unit) then
                player = mod:ISP_lookup_player(attacking_unit)
                if not player then
                    local player_spawn = Managers.state and Managers.state.player_unit_spawn
                    if player_spawn then
                        player = player_spawn:owner(attacking_unit)
                    end
                end
            end
            if player then
                mod:ISP_add_stat(mod:ISP_account_id(player), "relics", 1)
            end
        end
    end
end)

-- Backup hook for heretical idol destruction via collectibles manager notification
mod:hook_safe("CollectiblesManager", "_show_destructible_notification", function(self, peer_id, local_player_id, section_id, id)
    local destroying_player = Managers.player:player(peer_id, local_player_id)
    local local_player = mod.player_manager and mod.player_manager:local_player(1)
    if destroying_player and local_player and destroying_player == local_player then
        local key = tostring(section_id) .. "_" .. tostring(id)
        if not mod._isp_idols_counted then
            mod._isp_idols_counted = {}
        end
        if not mod._isp_idols_counted[key] then
            mod._isp_idols_counted[key] = true
            mod:ISP_add_stat(mod:ISP_account_id(destroying_player), "relics", 1)
        end
    end
end)

-- ============================================================
-- ESC PASSTHROUGH FIX
-- The game's _update_view_hotkeys only opens system_view via hotkey when
-- num_views == 0. Since our test overlay is an always-on view during Psykhanium,
-- ESC can never open the pause menu. We hook _update_view_hotkeys to re-check
-- for system view hotkeys after the original runs, since our view passes input.
-- ============================================================

-- Hook: UIManager._update_view_hotkeys — Re-checks system view hotkeys after the original runs so ESC can still open the pause menu despite our always-on test overlay view.
mod:hook(CLASS.UIManager, "_update_view_hotkeys", function(func, self)
    func(self)

    if not managers.ui:view_active("system_view") then
        local our_active = managers.ui:view_active("improved_scoreboard_panel_view") and
                           not managers.ui:is_view_closing("improved_scoreboard_panel_view")
        if our_active then
            local hotkey_settings = self._update_hotkeys
            if hotkey_settings and hotkey_settings.hotkeys then
                local input_service = self:input_service()
                if not input_service then return end
                for hotkey, view_name in pairs(hotkey_settings.hotkeys) do
                    if input_service:get(hotkey) then
                        self:open_view(view_name)
                        return
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- SHOP SALES & RESOURCE TRACKING
-- Hooks StoreService._change_cached_wallet_balance to detect
-- ordo dockets earned from selling items at vendors (single
-- gear deletes) AND plasteel/diamantine gains from any source
-- (manual pickups, mission rewards, etc.), persisting them
-- to the per-character cumulative stats.
-- ============================================================

mod:hook(CLASS.StoreService, "_change_cached_wallet_balance", function(func, self, wallet_type, change_amount, increment_transaction_id, log_prefix)
    local result = func(self, wallet_type, change_amount, increment_transaction_id, log_prefix)
    if change_amount > 0 then
        if wallet_type == "credits" and log_prefix == "on_gear_deleted" then
            mod:_ISP_track_resource_gained("dockets", change_amount)
        end
    end
    return result
end)

-- Generic resource gain tracker: accumulates crafting material pickups in an
-- in-memory pending table during gameplay. Data is flushed to disk at mission
-- end (via _ISP_record_mission_highscores) or when the graph view opens.
-- This avoids expensive disk I/O on every single pickup during a mission.
function mod:_ISP_track_resource_gained(resource_type, amount)
    if not amount or amount <= 0 then return end
    if not self._isp_pending_cumulative then
        self._isp_pending_cumulative = {}
    end
    self._isp_pending_cumulative[resource_type] = (self._isp_pending_cumulative[resource_type] or 0) + amount
end

-- Flushes pending cumulative data from in-memory buffer into _isp_full_data.
-- No disk I/O — persists at game exit only.
function mod:_ISP_flush_pending_cumulative()
    local pending = self._isp_pending_cumulative
    if not pending or next(pending) == nil then return end

    local char_id = self:ISP_character_id()
    if not char_id then return end

    local full = self._isp_full_data
    if not full then return end

    full.cumulative[char_id] = full.cumulative[char_id] or {}
    for resource_type, amount in pairs(pending) do
        if amount > 0 then
            full.cumulative[char_id][resource_type] = (full.cumulative[char_id][resource_type] or 0) + amount
        end
    end
    table_clear(pending)

    self._isp_graph_data = self:_ISP_load_graph_data()
end

-- Hooks GearService.delete_gear_batch to capture docket rewards
-- from the batch gear deletion endpoint (used by the vendor sell
-- UI when discarding multiple items at once).
mod:hook(CLASS.GearService, "delete_gear_batch", function(func, self, gear_ids)
    local promise = func(self, gear_ids)
    return promise:next(function(result)
        if result then
            local total_dockets = 0
            for i = 1, #result do
                local op = result[i]
                if op.rewards then
                    for j = 1, #op.rewards do
                        local reward = op.rewards[j]
                        if reward.type == "credits" and reward.amount > 0 then
                            total_dockets = total_dockets + reward.amount
                        end
                    end
                end
            end
            if total_dockets > 0 then
                mod:_ISP_track_resource_gained("dockets", total_dockets)
            end
        end
        return result
    end)
end)

-- ============================================================
-- GAME STATE HOOKS
-- Responds to mod lifecycle events and game state transitions
-- to initialize references, register the view, reset stats on
-- mission start, and clean up the overlay on exit.
-- ============================================================

-- Scoreboard graph is a HUD element. The class is defined above at file scope
-- and registered via DMF's register_hud_element below. The drawing logic is
-- loaded from improved_scoreboard_panel_graph.lua.

function mod.on_all_mods_loaded()
    mod.player_manager = managers.player
    mod.package_manager = managers.package
    mod.Breed = mod:original_require("scripts/utilities/breed")
    mod:register_view({
        view_name = "improved_scoreboard_panel_view",
        view_settings = {
            init_view_function = function(ingame_ui_context) return true end,
            class = "ImprovedScoreboardPanelView",
            allow_hud = true,
            disable_game_world = false,
            display_name = "mod_name_boring",
            game_world_blur = 0,
            load_always = true,
            load_in_hub = true,
            package = "packages/ui/views/options_view/options_view",
            path = "improved_scoreboard_panel/scripts/mods/improved_scoreboard_panel/improved_scoreboard_panel",
            state_bound = false,
            enter_sound_events = {},
            exit_sound_events = {},
        },
        view_transitions = {},
        view_options = {
            close_all = false,
            close_previous = false,
            close_transition_time = nil,
            transition_time = nil,
        },
    })

    -- Load persisted graph data on startup (deferred from boot — _ISP_load_graph_data
    -- calls ISP_local_id which triggers a native crash in peer_id before networking is ready)
    if not mod._isp_graph_data then
        mod._isp_graph_data = { lifetime = {}, missions = {}, cumulative = {} }
    end
    if not mod._isp_pending_cumulative then
        mod._isp_pending_cumulative = {}
    end
    if mod._isp_deferred_rewards == nil then
        mod._isp_deferred_rewards = false
    end
    -- Load the single shared data file (with legacy migration on first run)
    if not mod._isp_full_data then
        mod._isp_full_data = mod:_ISP_load_full_data()
    end
end

-- Toggles the scoreboard graph screen on/off via keybind (default F5)
function mod.toggle_scoreboard_graph()
    if mod:get("graph_disable") then return end
    local managers = Managers
    local ui_manager = managers and managers.ui
    if not ui_manager then
        return
    end
    local view_name = "improved_scoreboard_graph_view"
    if ui_manager:view_active(view_name) then
        ui_manager:close_view(view_name)
    else
        ui_manager:open_view(view_name)
    end
end

-- Per-frame update: check if test overlay should open/close.
-- This handles the user toggling test_mode on/off during gameplay.
function mod:update(dt)
    if mod._isp_tab_active and mod:get("test_mode") == true then
        -- Suppressed by tactical overlay when TAB is held
    else
        mod:ISP_check_test_view()
    end
end

-- Handles setting changes: toggling the per-character mode immediately
-- refreshes the display cache. Ensures Overflow Safeguard 1 and 2 are
-- mutually exclusive — enabling one automatically disables the other.
function mod.on_setting_changed(setting_id, value)
    if setting_id == "graph_per_character" then
        mod._isp_graph_data = mod:_ISP_load_graph_data()
    elseif setting_id == "graph_disable" and value then
        local ui_manager = Managers and Managers.ui
        if ui_manager and ui_manager:view_active("improved_scoreboard_graph_view") then
            ui_manager:close_view("improved_scoreboard_graph_view")
        end
    elseif value then
        if setting_id == "overflow_safeguard_1" then
            mod:set("overflow_safeguard_2", false)
        elseif setting_id == "overflow_safeguard_2" then
            mod:set("overflow_safeguard_1", false)
        end
    end
end

-- Responds to game state changes to reset stats on mission start, open or close the test overlay, and clean up the end screen view.
function mod.on_game_state_changed(status, state_name)
    -- Reset stats only the first time we enter gameplay (not on re-enter for join/leave)
    if state_name == "StateGameplay" and status == "enter" then
        if not mod.ISP_mission_active then
            mod.ISP_mission_active = true
            mod:ISP_reset_stats()
            mod._isp_deferred_rewards = false
            -- Reload graph data if empty — local player is now available
            -- for ISP_character_id() / ISP_local_id(), which aren't at
            -- startup (on_all_mods_loaded runs before player spawns).
            if not mod._isp_full_data then
                mod._isp_full_data = mod:_ISP_load_full_data()
            end
            if not mod._isp_graph_data or #(mod._isp_graph_data.missions or {}) == 0 then
                mod._isp_graph_data = mod:_ISP_load_graph_data()
            end
        end
        mod:ISP_check_test_view()
    end
    -- Close test view when leaving gameplay
    if state_name == "StateGameplay" and status == "exit" then
        mod.ISP_mission_active = false
        mod:ISP_close_test_view()
        -- Auto-disable test mode when leaving the Training Area / Psykhanium.
        -- Prevents test mode from persisting into live missions or the hub,
        -- which would cause fake data to appear on the mission end screen.
        if mod:ISP_is_psykhanium() and mod:get("test_mode") == true then
            mod:set("test_mode", false)
        end
    end
    -- Clean up EndView overlay when leaving the end screen
    if state_name == "StateLoading" and status == "enter" then
        mod.ISP_overlay_active = false
    end
    -- Save all in-memory data to disk on every state transition.
    -- Players often exit the game directly from missions/hub/training
    -- without returning to the main menu, so StateTitle alone is not enough.
    if status == "enter" and mod._isp_full_data then
        save_account_file(mod._isp_full_data)
    end
end

-- ============================================================
-- ENDVIEW INTEGRATION
-- Functions that build, refresh, and destroy the scoreboard
-- overlay inside the mission-end screen (EndView).
-- ============================================================

-- Helper to get the active EndView instance
function mod:_ISP_get_endview()
    local ui = managers.ui
    if ui:view_active("EndView") and not ui:is_view_closing("EndView") then
        return ui:view_instance("EndView")
    end
    return nil
end

-- Build a widget from a definition without registering it with any view
function mod:_ISP_make_widget(name, def)
    local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
    local w = UIWidget.init(name, def)
    -- Add value_id-based style references for refresh code
    for _, pass in pairs(def.passes) do
        if pass.value_id then
            if pass.style_id then
                w.style[pass.value_id] = w.style[pass.style_id]
            elseif pass.style then
                w.style[pass.value_id] = pass.style
            end
        end
    end
    w.alpha_multiplier = 1
    w.dirty = true
    return w
end

local function _name_font(name)
    for i = 1, #name do
        if string.byte(name, i) > 127 then return "proxima_nova_bold" end
    end
    return "machine_medium"
end

-- Build the scoreboard overlay widgets and attach them to EndView
function mod:_ISP_build_overlay(view)
    if view._isp_data then return end

    local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
    local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")

    -- Gather current players (max 4), or use fake players in test mode
    local is_test = mod:get("test_mode") == true
    local all_players = {}
    if is_test then
        for i = 1, 4 do
            all_players[#all_players + 1] = make_fake_player(TEST_NAMES[i], TEST_ARCHETYPES[i], i)
        end
    else
        for _, p in pairs(managers.player:players()) do
            all_players[#all_players + 1] = p
            if #all_players >= 4 then break end
        end
    end
    if #all_players == 0 then return end

    -- Ensure all current players have stat entries
    for _, p in pairs(all_players) do
        mod:ISP_ensure_player(mod:ISP_account_id(p))
    end

    -- Fill with random test data if in test mode
    if is_test then
        mod:ISP_reset_stats()
        local rng = math.random
        for _, p in pairs(all_players) do
            local aid = mod:ISP_account_id(p)
            mod:ISP_ensure_player(aid)
            local s = mod.ISP_player_stats[aid]
    local active_stats = mod:_ISP_active_stats()
    for _, def in pairs(active_stats) do
                s[def.key] = rng(1, 500)
            end
        end
    end

    -- Compute best/worst per stat among current players
    mod:_ISP_evaluate_rankings(all_players)
    mod:_ISP_evaluate_ranked_leader(mod:_ISP_present_aids(all_players))

    local scale = (math.max(50, mod:_ISP_get_opt("text_scale_tactical", 90))) / 90
    local screen_w = UIWorkspaceSettings.screen.size[1]
    local screen_h = UIWorkspaceSettings.screen.size[2]
    local row_gap = math.max(1, mod:_ISP_get_opt("row_spacing", 10))
    local box_alpha = mod:_ISP_get_opt("box_opacity_tactical", 150)
    local hs_r = mod:_ISP_get_opt("highscore_color_r", 0)
    local hs_g = mod:_ISP_get_opt("highscore_color_g", 255)
    local hs_b = mod:_ISP_get_opt("highscore_color_b", 0)
    local sl_r = mod:_ISP_get_opt("stat_label_color_r", 255)
    local sl_g = mod:_ISP_get_opt("stat_label_color_g", 255)
    local sl_b = mod:_ISP_get_opt("stat_label_color_b", 255)
    local alignment = mod:_ISP_get_opt("panel_alignment", "align_left")
    local offset_x = mod:_ISP_get_opt("box_offset_x", 0)
    local offset_y = mod:_ISP_get_opt("box_offset_y", 0)

    -- Determine stat count and whether any overflow safeguards are active before computing dimensions
    local active_stats = mod:_ISP_active_stats()
    local stat_count = #active_stats
    local split_stats = mod:get("overflow_safeguard_1")
    if mod:get("overflow_safeguard_2") and stat_count >= 10 then
        scale = scale * 0.75
    end

    local font_size = math_floor(18 * scale)
    local name_font_size = math_floor(20 * scale)
    local stat_label_font = math_floor(14 * scale)
    local stat_h = split_stats and math_floor(32 * scale) or math_floor(18 * scale)
    local name_h = math_floor(24 * scale)

    -- Box width from settings, compute label/value columns proportionally
    local padding = math_floor(12 * scale)
    local box_width = math.max(120, mod:_ISP_get_opt("box_width", 200))
    local card_w = math_floor(box_width * scale)
    local content_w = card_w - padding * 2
    local label_col_w = math_floor(content_w * 0.62)
    local val_col_w = content_w - label_col_w
    local name_to_stats_gap = math_floor(6 * scale)
    local stat_line_gap = 2

    -- Split stats into 2 columns within the card when 10+ are enabled (safeguard against vertical overflow)
    local half = split_stats and math.ceil(stat_count / 2) or stat_count
    local col_gap = split_stats and 8 or 0
    -- Floor the card width at 270 in split mode; the box_width slider can raise it higher
    local display_card_w = split_stats and math.max(card_w, 270) or card_w
    local display_content_w = display_card_w - padding * 2
    local col2_w = split_stats and math.floor((display_content_w - col_gap) * 0.5) or 0
    local col1_label_w = split_stats and math.floor(col2_w * 0.6) or label_col_w
    local col1_val_w = col2_w - col1_label_w
    local stat_rows = split_stats and half or stat_count
    local card_h = padding + name_h + name_to_stats_gap + stat_rows * stat_h + (stat_rows - 1) * stat_line_gap + padding
    local total_h = (#all_players * card_h) + ((#all_players - 1) * row_gap)

    -- Starting X position based on alignment + offset
    local start_x
    if alignment == "align_right" then
        start_x = screen_w - display_card_w - padding + offset_x
    else
        start_x = padding + offset_x
    end
    -- Vertically center the panel with offset
    local start_y = ((screen_h - total_h) / 2) + offset_y

    local row_widgets = {}
    local stroke_widgets = {}
    local stroke_widget_map = {}
    local bg_widgets = {}
    local bg_widget_map = {}
    local text_widgets = {}

    -- Create one card per player (split into background + text widgets)
    for pi = 1, #all_players do
        local player = all_players[pi]
        local aid = mod:ISP_account_id(player)
        local pname = player:name() or "Unknown"
        local profile = player.profile and player:profile()
        local archetype = profile and profile.archetype and profile.archetype.name
        local symbol = player.string_symbol or (archetype and UISettings.archetype_font_icon and UISettings.archetype_font_icon[archetype])
        local display_name = symbol and (symbol .. " " .. pname) or pname
        local name_pizazz = mod:get("mod_name_pizazz_toggle") ~= false
        local name_color = get_name_color(player, name_pizazz)

        local row_y = start_y + (pi - 1) * (card_h + row_gap)

        -- Background widget (card panel)
        local bg_passes = {
            {
                pass_type = "rect",
                style = {
                    offset = { 0, 0, 0 },
                    size = { display_card_w, card_h },
                    color = { box_alpha, 12, 12, 16 },
                },
            },
        }
        local bg_wdef = UIWidget.create_definition(bg_passes, "screen", nil, { display_card_w, card_h })
        local bg_w = mod:_ISP_make_widget("isp_card_bg_" .. pi, bg_wdef)
        bg_w.offset = { start_x, row_y, 0 }
        bg_widgets[#bg_widgets + 1] = bg_w
        bg_widget_map[aid] = bg_w

        -- Ranked mode stroke widget (behind the background, controlled by alpha_multiplier)
        local stroke_passes = {
            {
                pass_type = "rect",
                style = {
                    offset = { 0, 0, 0 },
                    size = { display_card_w + 6, card_h + 6 },
                    color = { 255, hs_r, hs_g, hs_b },
                },
            },
        }
        local stroke_wdef = UIWidget.create_definition(stroke_passes, "screen", nil, { display_card_w + 6, card_h + 6 })
        local stroke_w = mod:_ISP_make_widget("isp_stroke_" .. pi, stroke_wdef)
        stroke_w.offset = { start_x - 3, row_y - 3, 0 }
        stroke_w.alpha_multiplier = 0
        stroke_widgets[#stroke_widgets + 1] = stroke_w
        stroke_widget_map[aid] = stroke_w

        -- Text widget (name + stats)
        local text_passes = {}

        -- Player name at top of card
        local player_name_font = _name_font(display_name)
        text_passes[#text_passes + 1] = {
            value_id = "player_name",
            value = display_name,
            pass_type = "text",
            style = {
                offset = { padding, padding, 0 },
                size = { display_card_w - padding * 2, name_h },
                font_size = name_font_size,
                font_type = player_name_font,
                text_horizontal_alignment = "left",
                text_vertical_alignment = "center",
                text_color = name_color,
            },
        }

        -- Stat lines stacked vertically below player name, split into 2 columns when 10+ stats enabled
        local first_stat_y = padding + name_h + name_to_stats_gap
        for si = 1, stat_count do
            local def = active_stats[si]
            local raw_val = (mod.ISP_player_stats[aid] and mod.ISP_player_stats[aid][def.key]) or 0
            local display_val = def.shorten and mod:ISP_format_num(raw_val) or string_format("%.0f", raw_val)
            local loc_key = mod:get("minimal_stat_labels") and def.min_loc or def.loc
            local label = mod:localize(loc_key)

            -- Determine highlight color for value
            local val_color = { 255, 200, 200, 200 }
            if mod.ISP_rankings and mod.ISP_rankings[def.key] then
                local r = mod.ISP_rankings[def.key]
                if r.best and r.best[aid] then
                    val_color = { 255, hs_r, hs_g, hs_b }
                elseif r.worst and r.worst[aid] and raw_val > 0 then
                    val_color = { 255, 140, 140, 140 }
                end
            end

            local sy, sx_label, sx_val, use_label_w, use_val_w
            if split_stats then
                local local_idx = si - 1
                local col = math_floor(local_idx / half)
                local row = local_idx % half
                sy = first_stat_y + row * (stat_h + stat_line_gap)
                local col_x = padding + col * (col2_w + col_gap)
                sx_label = col_x
                sx_val = col_x + col1_label_w
                use_label_w = col1_label_w
                use_val_w = col1_val_w
            else
                sy = first_stat_y + (si - 1) * (stat_h + stat_line_gap)
                sx_label = padding
                sx_val = padding + label_col_w
                use_label_w = label_col_w
                use_val_w = val_col_w
            end

            -- Stat label on the left
            text_passes[#text_passes + 1] = {
                value_id = "stat_label_" .. def.key .. "_" .. aid,
                value = label .. ":",
                pass_type = "text",
                style = {
                    offset = { sx_label, sy, 0 },
                    size = { use_label_w, stat_h },
                    font_size = stat_label_font,
                    font_type = "machine_medium",
                    text_horizontal_alignment = "left",
                    text_vertical_alignment = "center",
                    text_color = { 255, sl_r, sl_g, sl_b },
                    word_wrap = not split_stats and false or nil,
                },
            }

            -- Stat value on the right
            text_passes[#text_passes + 1] = {
                value_id = "stat_" .. def.key .. "_" .. aid,
                value = display_val,
                pass_type = "text",
                style = {
                    offset = { sx_val, sy, 0 },
                    size = { use_val_w, stat_h },
                    font_size = font_size,
                    font_type = "machine_medium",
                    text_horizontal_alignment = "right",
                    text_vertical_alignment = "center",
                    text_color = val_color,
                },
            }
        end

        local text_wdef = UIWidget.create_definition(text_passes, "screen", nil, { display_card_w, card_h })
        local text_w = mod:_ISP_make_widget("isp_card_text_" .. pi, text_wdef)
        text_w.offset = { start_x, row_y, 0 }
        text_widgets[#text_widgets + 1] = text_w
        row_widgets[aid] = text_w
    end

    view._isp_data = {
        stroke_widgets = stroke_widgets,
        stroke_widget_map = stroke_widget_map,
        bg_widgets = bg_widgets,
        bg_widget_map = bg_widget_map,
        text_widgets = text_widgets,
        widgets = text_widgets,
        row_widgets = row_widgets,
        visible = true,
        alignment = alignment,
        box_width = box_width,
        offset_x = offset_x,
        offset_y = offset_y,
        row_spacing = row_gap,
        start_x = start_x,
        screen_w = screen_w,
        card_w = card_w,
        padding = padding,
    }
    mod.ISP_overlay_active = true
end

-- Determine who has the best and worst values for each stat among current players
function mod:_ISP_evaluate_rankings(players)
    self.ISP_rankings = {}
    local aids = {}
    for _, p in pairs(players) do
        aids[#aids + 1] = mod:ISP_account_id(p)
    end
    for aid, _ in pairs(self.ISP_player_stats) do
        local found = false
        for _, existing in ipairs(aids) do
            if existing == aid then
                found = true
                break
            end
        end
        if not found then
            aids[#aids + 1] = aid
        end
    end

    local active_stats = mod:_ISP_active_stats()
    for _, def in pairs(active_stats) do
        local best_set = {}
        local worst_set = {}
        local best_val = def.asc and -math.huge or math.huge
        local worst_val = def.asc and math.huge or -math.huge
        local all_equal = true
        local first_val = nil

        for _, aid in pairs(aids) do
            local v = (self.ISP_player_stats[aid] and self.ISP_player_stats[aid][def.key]) or 0
            if first_val == nil then
                first_val = v
            elseif v ~= first_val then
                all_equal = false
            end

            if def.asc then
                if v > best_val then
                    best_val = v; table_clear(best_set); best_set[aid] = true
                elseif v == best_val then
                    best_set[aid] = true
                end
                if v < worst_val then
                    worst_val = v; table_clear(worst_set); worst_set[aid] = true
                elseif v == worst_val then
                    worst_set[aid] = true
                end
            else
                if v < best_val then
                    best_val = v; table_clear(best_set); best_set[aid] = true
                elseif v == best_val then
                    best_set[aid] = true
                end
                if v > worst_val then
                    worst_val = v; table_clear(worst_set); worst_set[aid] = true
                elseif v == worst_val then
                    worst_set[aid] = true
                end
            end
        end

        if #aids <= 1 then
            best_set[aids[1]] = true
            table_clear(worst_set)
        elseif all_equal then
            table_clear(best_set)
            table_clear(worst_set)
        end

        self.ISP_rankings[def.key] = { best = best_set, worst = worst_set }
    end
end

-- Build a lookup set of account IDs from a player list for presence checks.
function mod:_ISP_present_aids(players)
    local set = {}
    for _, p in pairs(players) do
        set[mod:ISP_account_id(p)] = true
    end
    return set
end

-- Determine which player currently holds the most scoreboard highscores.
-- Sets self.ISP_ranked_leader as a table of aid -> true for the leader(s).
-- Only active when the "ranked_mode" toggle is enabled.
-- present_aids (optional): lookup set of aid -> true for players whose cards exist
-- on screen. When provided, absent leaders are skipped and the green stroke cascades
-- to the next-highest tier that has at least one player still in the party.
function mod:_ISP_evaluate_ranked_leader(present_aids)
    self.ISP_ranked_leader = {}
    if not mod:get("ranked_mode") then return end
    if not self.ISP_rankings then return end

    local counts = {}
    local active_stats = mod:_ISP_active_stats()
    for _, def in pairs(active_stats) do
        local r = self.ISP_rankings[def.key]
        if r and r.best then
            for aid in pairs(r.best) do
                counts[aid] = (counts[aid] or 0) + 1
            end
        end
    end

    if next(counts) == nil then return end

    -- Generate sorted list of unique tier counts, descending
    local tier_set = {}
    for _, count in pairs(counts) do
        tier_set[count] = true
    end
    local sorted_tiers = {}
    for count in pairs(tier_set) do
        sorted_tiers[#sorted_tiers + 1] = count
    end
    table.sort(sorted_tiers, function(a, b) return a > b end)

    -- Try each tier from highest down until we find at least one present player
    for _, tier in ipairs(sorted_tiers) do
        if present_aids then
            local has_present = false
            for aid, count in pairs(counts) do
                if count == tier and present_aids[aid] then
                    has_present = true
                    break
                end
            end
            if not has_present then
                -- skip this tier; cascade to the next
            else
                for aid, count in pairs(counts) do
                    if count == tier and present_aids[aid] then
                        self.ISP_ranked_leader[aid] = true
                    end
                end
                return
            end
        else
            -- No present filter: award all players at this tier (original behavior)
            for aid, count in pairs(counts) do
                if count == tier then
                    self.ISP_ranked_leader[aid] = true
                end
            end
            return
        end
    end
end

-- Update existing overlay widgets with fresh stats each frame
function mod:_ISP_refresh_overlay(view)
    local data = view._isp_data
    if not data or not data.visible then return end
    if not data.widgets then return end

    -- Rebuild if layout settings changed or grid mode changed (stat count crossed 10 threshold)
    local cur_align = mod:_ISP_get_opt("panel_alignment", "align_left")
    local cur_bw = math.max(120, mod:_ISP_get_opt("box_width", 200))
    local cur_ox = mod:_ISP_get_opt("box_offset_x", 0)
    local cur_oy = mod:_ISP_get_opt("box_offset_y", 0)
    local cur_rg = math.max(1, mod:_ISP_get_opt("row_spacing", 10))
    if data.alignment ~= cur_align or data.box_width ~= cur_bw or data.offset_x ~= cur_ox or data.offset_y ~= cur_oy or data.row_spacing ~= cur_rg or mod:get("test_mode") == true then
        self:_ISP_destroy_overlay(view)
        self:_ISP_build_overlay(view)
        return
    end

    -- Gather current players, or use fake players in test mode
    local all_players = {}
    if mod:get("test_mode") == true then
        for i = 1, 4 do
            all_players[#all_players + 1] = make_fake_player(TEST_NAMES[i], TEST_ARCHETYPES[i], i)
        end
    else
        for _, p in pairs(managers.player:players()) do
            all_players[#all_players + 1] = p
            if #all_players >= 4 then break end
        end
    end
    if #all_players == 0 then return end

    -- Re-evaluate rankings
    for _, p in pairs(all_players) do
        mod:ISP_ensure_player(mod:ISP_account_id(p))
    end
    mod:_ISP_evaluate_rankings(all_players)
    mod:_ISP_evaluate_ranked_leader()

    local hs_r = mod:_ISP_get_opt("highscore_color_r", 0)
    local hs_g = mod:_ISP_get_opt("highscore_color_g", 255)
    local hs_b = mod:_ISP_get_opt("highscore_color_b", 0)
    local sl_r = mod:_ISP_get_opt("stat_label_color_r", 255)
    local sl_g = mod:_ISP_get_opt("stat_label_color_g", 255)
    local sl_b = mod:_ISP_get_opt("stat_label_color_b", 255)

    local name_pizazz = mod:get("mod_name_pizazz_toggle") ~= false
    local active_stats = mod:_ISP_active_stats()
    local stat_count = #active_stats
    local row_widgets = data.row_widgets

    for pi = 1, #all_players do
        local player = all_players[pi]
        local aid = mod:ISP_account_id(player)
        local w = row_widgets[aid]
        if w then
            -- Update player name color if name pizazz changed
            local name_color = get_name_color(player, name_pizazz)
            if w.style.player_name then
                w.style.player_name.text_color = name_color
                w.dirty = true
            end

            for si = 1, stat_count do
                local def = active_stats[si]
                local raw_val = (mod.ISP_player_stats[aid] and mod.ISP_player_stats[aid][def.key]) or 0
                local display_val = def.shorten and mod:ISP_format_num(raw_val) or string_format("%.0f", raw_val)

                local cid = "stat_" .. def.key .. "_" .. aid
                if w.content[cid] ~= nil then
                    w.content[cid] = display_val
                end

                local val_color = { 255, 200, 200, 200 }
                if mod.ISP_rankings and mod.ISP_rankings[def.key] then
                    local r = mod.ISP_rankings[def.key]
                    if r.best and r.best[aid] then
                        val_color = { 255, hs_r, hs_g, hs_b }
                    elseif r.worst and r.worst[aid] and raw_val > 0 then
                        val_color = { 255, 140, 140, 140 }
                    end
                end

                local style_key = "stat_" .. def.key .. "_" .. aid
                if w.style[style_key] then
                    w.style[style_key].text_color = val_color
                end
                local label_key = "stat_label_" .. def.key .. "_" .. aid
                if w.style[label_key] then
                    w.style[label_key].text_color = { 255, sl_r, sl_g, sl_b }
                end
                w.dirty = true
            end
        end
    end
    -- Update ranked mode stroke on each player's background widget
    if mod:get("ranked_mode") then
        local stroke_widget_map = data.stroke_widget_map
        for pi = 1, #all_players do
            local aid = mod:ISP_account_id(all_players[pi])
            local stroke_w = stroke_widget_map[aid]
            if stroke_w then
                local is_leader = mod.ISP_ranked_leader and mod.ISP_ranked_leader[aid]
                stroke_w.alpha_multiplier = is_leader and 1 or 0
            end
        end
    end
end

-- Remove overlay data and widgets
function mod:_ISP_destroy_overlay(view)
    if view and view._isp_data then
        view._isp_data = nil
    end
    mod.ISP_overlay_active = false
end

-- ============================================================
-- TEST MODE (PSYKHANIUM) OVERLAY
-- Provides a preview overlay inside the Meat Grinder and
-- Training Area that shows the scoreboard layout with fake
-- players alongside the real local player's tracked stats.
-- ============================================================

-- Check if the current game mode is Training Area or Meat Grinder (Psykhanium modes)
-- Training Area uses "shooting_range", Meat Grinder uses "survival".
-- Mortis Trials uses a different game mode and is NOT included here.
function mod:ISP_is_psykhanium()
    local gm = Managers.state and Managers.state.game_mode
    if gm and gm.game_mode_name then
        local name = gm:game_mode_name()
        return name == "survival" or name == "shooting_range"
    end
    return false
end

-- Check if the player is in the Morningstar social hub (not in a live mission or training area)
function mod:ISP_is_in_hub()
    local gm = Managers.state and Managers.state.game_mode
    if gm and gm.game_mode_name then
        local name = gm:game_mode_name()
        return name == "hub" or name == "prologue_hub"
    end
    return false
end

-- Open or close the test view based on current conditions
function mod:ISP_check_test_view()
    local test_on = mod:get("test_mode") == true
    if test_on and mod:ISP_is_psykhanium() then
        mod:ISP_open_test_view()
    else
        mod._isp_test_stats_seeded = nil
        mod:ISP_close_test_view()
    end
end

-- Open the test overlay view
function mod:ISP_open_test_view()
    if managers.ui:view_active("improved_scoreboard_panel_view") and not managers.ui:is_view_closing("improved_scoreboard_panel_view") then
        return
    end
    managers.ui:open_view("improved_scoreboard_panel_view", nil, false, false, nil, {}, { use_transition_ui = false })
end

-- Close the test overlay view
function mod:ISP_close_test_view()
    if managers.ui:view_active("improved_scoreboard_panel_view") and not managers.ui:is_view_closing("improved_scoreboard_panel_view") then
        managers.ui:close_view("improved_scoreboard_panel_view", true)
    end
end

-- Build overlay widgets for the test view
function mod:ISP_build_test_overlay(test_view)
    if not test_view then return end
    test_view._isp_widgets = {}

    local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
    local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")

    -- Build player list: 1 real + fakes to fill to 4
    local all_players = {}
    local real_player
    for _, p in pairs(managers.player:players()) do
        real_player = p
        break
    end
    if real_player then
        all_players[#all_players + 1] = real_player
    end
    local rng = math.random
    while #all_players < 4 do
        local idx = #all_players + 1
        all_players[#all_players + 1] = make_fake_player("player_" .. idx, TEST_ARCHETYPES[idx], idx)
    end

    -- Ensure real player has a stat entry
    if real_player then
        mod:ISP_ensure_player(mod:ISP_account_id(real_player))
    end

    -- Seed test stats once per test-mode session: real player = 0, fakes = random 1-9.
    -- Stats persist across TAB opens/closes and only regenerate when the toggle is recycled.
    local active_stats_check = mod:_ISP_active_stats()
    if not mod._isp_test_stats_seeded then
        -- Real player stats start at zero
        if real_player then
            local raid = mod:ISP_account_id(real_player)
            mod:ISP_ensure_player(raid)
            local rs = mod.ISP_player_stats[raid]
            if rs then
                for _, def in pairs(active_stats_check) do
                    rs[def.key] = 0
                end
            end
        end
        -- Fake players get random single-digit values
        for _, p in pairs(all_players) do
            local aid = mod:ISP_account_id(p)
            if not real_player or aid ~= mod:ISP_account_id(real_player) then
                mod:ISP_ensure_player(aid)
                local s = mod.ISP_player_stats[aid]
                for _, def in pairs(active_stats_check) do
                    s[def.key] = rng(1, 9)
                end
            end
        end
        mod._isp_test_stats_seeded = true
    end

    -- Compute layout
    local scale = (math.max(50, mod:_ISP_get_opt("text_scale_mission", 90))) / 90
    local screen_w = UIWorkspaceSettings.screen.size[1]
    local screen_h = UIWorkspaceSettings.screen.size[2]
    local row_gap = math.max(1, mod:_ISP_get_opt("row_spacing", 10))
    local box_alpha = mod:_ISP_get_opt("box_opacity_mission", 150)
    local hs_r = mod:_ISP_get_opt("highscore_color_r", 0)
    local hs_g = mod:_ISP_get_opt("highscore_color_g", 255)
    local hs_b = mod:_ISP_get_opt("highscore_color_b", 0)
    local sl_r = mod:_ISP_get_opt("stat_label_color_r", 255)
    local sl_g = mod:_ISP_get_opt("stat_label_color_g", 255)
    local sl_b = mod:_ISP_get_opt("stat_label_color_b", 255)
    local alignment = mod:_ISP_get_opt("panel_alignment", "align_left")
    local offset_x = mod:_ISP_get_opt("box_offset_x", 0)
    local offset_y = mod:_ISP_get_opt("box_offset_y", 0)

    -- Determine stat count and whether any overflow safeguards are active before computing dimensions
    local active_stats = mod:_ISP_active_stats()
    local stat_count = #active_stats
    local split_stats = mod:get("overflow_safeguard_1")
    if mod:get("overflow_safeguard_2") and stat_count >= 10 then
        scale = scale * 0.75
    end

    local font_size = math_floor(18 * scale)
    local name_font_size = math_floor(20 * scale)
    local stat_label_font = math_floor(14 * scale)
    local stat_h = split_stats and math_floor(32 * scale) or math_floor(18 * scale)
    local name_h = math_floor(24 * scale)

    local padding = math_floor(12 * scale)
    local box_width = math.max(120, mod:_ISP_get_opt("box_width", 200))
    local card_w = math_floor(box_width * scale)
    local content_w = card_w - padding * 2
    local label_col_w = math_floor(content_w * 0.62)
    local val_col_w = content_w - label_col_w
    local name_to_stats_gap = math_floor(6 * scale)
    local stat_line_gap = 2
    -- Split stats into 2 columns within the card when 10+ are enabled (safeguard against vertical overflow)
    local half = split_stats and math.ceil(stat_count / 2) or stat_count
    local col_gap = split_stats and 8 or 0
    -- Floor the card width at 270 in split mode; the box_width slider can raise it higher
    local display_card_w = split_stats and math.max(card_w, 270) or card_w
    local display_content_w = display_card_w - padding * 2
    local col2_w = split_stats and math.floor((display_content_w - col_gap) * 0.5) or 0
    local col1_label_w = split_stats and math.floor(col2_w * 0.6) or label_col_w
    local col1_val_w = col2_w - col1_label_w
    local stat_rows = split_stats and half or stat_count
    local card_h = padding + name_h + name_to_stats_gap + stat_rows * stat_h + (stat_rows - 1) * stat_line_gap + padding

    local start_x
    if alignment == "align_right" then
        start_x = screen_w - display_card_w - padding + offset_x
    else
        start_x = padding + offset_x
    end
    local total_h = (#all_players * card_h) + ((#all_players - 1) * row_gap)
    local start_y = ((screen_h - total_h) / 2) + offset_y

    local row_widgets = {}
    local stroke_widgets = {}

    for pi = 1, #all_players do
        local player = all_players[pi]
        local aid = mod:ISP_account_id(player)
        local pname = player:name() or "Unknown"
        local profile = player.profile and player:profile()
        local archetype = profile and profile.archetype and profile.archetype.name
        local symbol = player.string_symbol or (archetype and UISettings.archetype_font_icon and UISettings.archetype_font_icon[archetype])
        local display_name = symbol and (symbol .. " " .. pname) or pname
        local is_real = real_player and aid == mod:ISP_account_id(real_player)

        local name_pizazz = mod:get("mod_name_pizazz_toggle") ~= false
        local name_color = get_name_color(player, name_pizazz)

        local row_y = start_y + (pi - 1) * (card_h + row_gap)
        local passes = {}

        passes[#passes + 1] = {
            pass_type = "rect",
            style = {
                offset = { 0, 0, 0 },
                size = { display_card_w, card_h },
                color = { box_alpha, 12, 12, 16 },
            },
        }

        local player_name_font = _name_font(display_name)
        passes[#passes + 1] = {
            value_id = "player_name",
            value = display_name,
            pass_type = "text",
            style = {
                offset = { padding, padding, 1 },
                size = { display_card_w - padding * 2, name_h },
                font_size = name_font_size,
                font_type = player_name_font,
                text_horizontal_alignment = "left",
                text_vertical_alignment = "center",
                text_color = name_color,
            },
        }

        -- Evaluate rankings for this player set
    mod:_ISP_evaluate_rankings(all_players)
    mod:_ISP_evaluate_ranked_leader(mod:_ISP_present_aids(all_players))

        local first_stat_y = padding + name_h + name_to_stats_gap
        for si = 1, stat_count do
            local def = active_stats[si]
            local raw_val = (mod.ISP_player_stats[aid] and mod.ISP_player_stats[aid][def.key]) or 0
            local display_val = def.shorten and mod:ISP_format_num(raw_val) or string_format("%.0f", raw_val)
            local loc_key = mod:get("minimal_stat_labels") and def.min_loc or def.loc
            local label = mod:localize(loc_key)

            local val_color = { 255, 200, 200, 200 }
            if mod.ISP_rankings and mod.ISP_rankings[def.key] then
                local r = mod.ISP_rankings[def.key]
                if r.best and r.best[aid] then
                    val_color = { 255, hs_r, hs_g, hs_b }
                elseif r.worst and r.worst[aid] and raw_val > 0 then
                    val_color = { 255, 140, 140, 140 }
                end
            end

            local sy, sx_label, sx_val
            if split_stats then
                local local_idx = si - 1
                local col = math_floor(local_idx / half)
                local row = local_idx % half
                sy = first_stat_y + row * (stat_h + stat_line_gap)
                local col_x = padding + col * (col2_w + col_gap)
                sx_label = col_x
                sx_val = col_x + col1_label_w
            else
                sy = first_stat_y + (si - 1) * (stat_h + stat_line_gap)
                sx_label = padding
                sx_val = padding + label_col_w
            end

            passes[#passes + 1] = {
                value_id = "stat_label_" .. def.key .. "_" .. pi,
                value = label .. ":",
                pass_type = "text",
                style = {
                    offset = { sx_label, sy, 1 },
                    size = { split_stats and col1_label_w or label_col_w, stat_h },
                    font_size = stat_label_font,
                    font_type = "machine_medium",
                    text_horizontal_alignment = "left",
                    text_vertical_alignment = "center",
                    text_color = { 255, sl_r, sl_g, sl_b },
                    word_wrap = not split_stats and false or nil,
                },
            }

            passes[#passes + 1] = {
                value_id = "stat_" .. def.key .. "_" .. pi,
                value = display_val,
                pass_type = "text",
                style = {
                    offset = { sx_val, sy, 1 },
                    size = { split_stats and col1_val_w or val_col_w, stat_h },
                    font_size = font_size,
                    font_type = "machine_medium",
                    text_horizontal_alignment = "right",
                    text_vertical_alignment = "center",
                    text_color = val_color,
                },
            }
        end

        local wdef = UIWidget.create_definition(passes, "screen", nil, { display_card_w, card_h })
        local w = mod:_ISP_make_widget("isp_test_card_" .. pi, wdef)
        w.offset = { start_x, row_y, 0 }
        row_widgets[#row_widgets + 1] = w

        -- Ranked mode stroke widget (behind the card, controlled by alpha_multiplier)
        local stroke_passes = {
            {
                pass_type = "rect",
                style = {
                    offset = { 0, 0, 0 },
                    size = { display_card_w + 6, card_h + 6 },
                    color = { 255, hs_r, hs_g, hs_b },
                },
            },
        }
        local stroke_wdef = UIWidget.create_definition(stroke_passes, "screen", nil, { display_card_w + 6, card_h + 6 })
        local stroke_w = mod:_ISP_make_widget("isp_test_stroke_" .. pi, stroke_wdef)
        stroke_w.offset = { start_x - 3, row_y - 3, 0 }
        stroke_w.alpha_multiplier = 0
        stroke_widgets[#stroke_widgets + 1] = stroke_w
    end

    test_view._isp_widgets = row_widgets
    test_view._isp_stroke_widgets = stroke_widgets
end

-- Refresh overlay widgets for the test view
function mod:ISP_refresh_test_overlay(test_view)
    if not test_view or not test_view._isp_widgets then return end

    -- Check if conditions still hold, close if not
    if mod:get("test_mode") ~= true or not mod:ISP_is_psykhanium() then
        mod:ISP_close_test_view()
        return
    end

    -- Build/re-evaluate player list
    local all_players = {}
    local real_player
    for _, p in pairs(managers.player:players()) do
        real_player = p
        break
    end
    if real_player then
        all_players[#all_players + 1] = real_player
        mod:ISP_ensure_player(mod:ISP_account_id(real_player))
    end
    while #all_players < 4 do
        local idx = #all_players + 1
        all_players[#all_players + 1] = make_fake_player("player_" .. idx, TEST_ARCHETYPES[idx], idx)
    end

    mod:_ISP_evaluate_rankings(all_players)
    mod:_ISP_evaluate_ranked_leader()
    local hs_r = mod:_ISP_get_opt("highscore_color_r", 0)
    local hs_g = mod:_ISP_get_opt("highscore_color_g", 255)
    local hs_b = mod:_ISP_get_opt("highscore_color_b", 0)
    local sl_r = mod:_ISP_get_opt("stat_label_color_r", 255)
    local sl_g = mod:_ISP_get_opt("stat_label_color_g", 255)
    local sl_b = mod:_ISP_get_opt("stat_label_color_b", 255)
    local active_stats = mod:_ISP_active_stats()
    local stat_count = #active_stats
    local row_widgets = test_view._isp_widgets

    for pi = 1, #all_players do
        local player = all_players[pi]
        local aid = mod:ISP_account_id(player)
        local w = row_widgets[pi]
        if not w then break end

        local name_pizazz = mod:get("mod_name_pizazz_toggle") ~= false
        local name_color = get_name_color(player, name_pizazz)
        if w.style.player_name then
            w.style.player_name.text_color = name_color
            w.dirty = true
        end

        for si = 1, stat_count do
            local def = active_stats[si]
            local raw_val = (mod.ISP_player_stats[aid] and mod.ISP_player_stats[aid][def.key]) or 0
            local display_val = def.shorten and mod:ISP_format_num(raw_val) or string_format("%.0f", raw_val)

            local cid = "stat_" .. def.key .. "_" .. pi
            if w.content[cid] ~= nil then
                w.content[cid] = display_val
            end

            local val_color = { 255, 200, 200, 200 }
            if mod.ISP_rankings and mod.ISP_rankings[def.key] then
                local r = mod.ISP_rankings[def.key]
                if r.best and r.best[aid] then
                    val_color = { 255, hs_r, hs_g, hs_b }
                elseif r.worst and r.worst[aid] and raw_val > 0 then
                    val_color = { 255, 140, 140, 140 }
                end
            end

            local style_key = "stat_" .. def.key .. "_" .. pi
            if w.style[style_key] then
                w.style[style_key].text_color = val_color
            end
            local label_key = "stat_label_" .. def.key .. "_" .. pi
            if w.style[label_key] then
                w.style[label_key].text_color = { 255, sl_r, sl_g, sl_b }
            end
            w.dirty = true
        end
        -- Update ranked mode stroke
        if mod:get("ranked_mode") then
            local stroke_widgets = test_view._isp_stroke_widgets
            if stroke_widgets and stroke_widgets[pi] then
                local is_leader = mod.ISP_ranked_leader and mod.ISP_ranked_leader[aid]
                stroke_widgets[pi].alpha_multiplier = is_leader and 1 or 0
            end
        end
    end
end

-- Destroy overlay data for the test view
function mod:ISP_destroy_test_overlay(test_view)
    if test_view then
        test_view._isp_widgets = nil
        test_view._isp_stroke_widgets = nil
    end
end

-- ============================================================
-- ENDVIEW HOOKS
-- Hooks into the mission-end screen (EndView) lifecycle to
-- build, refresh, and destroy the scoreboard overlay widgets
-- alongside the native end-of-mission UI.
-- ============================================================

-- Hook: EndView.on_enter — Builds the scoreboard overlay when the mission-end screen opens, records highscore data for the graph, and sets initial visibility based on the "show_at_mission_end" setting.
mod:hook(CLASS.EndView, "on_enter", function(func, view, ...)
    func(view, ...)
    mod:_ISP_build_overlay(view)
    mod:_ISP_record_mission_highscores()
    if view._isp_data then
        local auto_show = mod:_ISP_get_opt("show_at_mission_end", true)
        view._isp_data.visible = auto_show
        mod.ISP_overlay_active = auto_show
    end
end)

-- Hook: EndView.update — Refreshes the scoreboard overlay data every frame while the mission-end
-- screen is active and the overlay is visible. Also processes deferred session report rewards
-- (XP, dockets) that weren't available during EndView.on_enter (common on failed missions where
-- the report arrives asynchronously after a stall).
mod:hook(CLASS.EndView, "update", function(func, view, dt, t, input_service, ...)
    func(view, dt, t, input_service, ...)

    -- Process deferred mission rewards if the session report just became available
    if mod._isp_deferred_rewards then
        local progression_mgr = Managers.progression
        local report = progression_mgr and progression_mgr:session_report()
        if report then
            local char_id = mod:ISP_character_id()
            if char_id and mod._isp_full_data then
                mod._isp_full_data.cumulative[char_id] = mod._isp_full_data.cumulative[char_id] or {}
                mod:_ISP_apply_session_report_to_data({ cumulative = mod._isp_full_data.cumulative[char_id] }, report)
                mod._isp_graph_data = mod:_ISP_load_graph_data()
            end
            mod._isp_deferred_rewards = false
        end
    end

    if view._isp_data and view._isp_data.visible then
        mod:_ISP_refresh_overlay(view)
    end
end)

-- Hook: EndView.draw — Renders the scoreboard overlay widgets on top of the mission-end screen at a higher layer than the native content.
mod:hook(CLASS.EndView, "draw", function(func, view, dt, t, input_service, layer, ...)
    func(view, dt, t, input_service, layer, ...)
    if view._isp_data and view._isp_data.visible then
        local UIRenderer = mod:original_require("scripts/managers/ui/ui_renderer")
        local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
        local saved_layer = view._render_settings.start_layer
        view._render_settings.start_layer = 1000
        UIRenderer.begin_pass(view._ui_renderer, view._ui_scenegraph, input_service, dt, view._render_settings)
        if view._isp_data.stroke_widgets then
            for _, w in pairs(view._isp_data.stroke_widgets) do
                UIWidget.draw(w, view._ui_renderer)
            end
        end
        if view._isp_data.bg_widgets then
            for _, w in pairs(view._isp_data.bg_widgets) do
                UIWidget.draw(w, view._ui_renderer)
            end
        end
        if view._isp_data.text_widgets then
            for _, w in pairs(view._isp_data.text_widgets) do
                UIWidget.draw(w, view._ui_renderer)
            end
        end
        UIRenderer.end_pass(view._ui_renderer)
        view._render_settings.start_layer = saved_layer
    end
end)

-- Hook: EndView.on_exit — Destroys the scoreboard overlay data when the mission-end screen closes.
mod:hook(CLASS.EndView, "on_exit", function(func, view, ...)
    func(view, ...)
    mod:_ISP_destroy_overlay(view)
end)

-- ============================================================
-- TACTICAL OVERLAY (TAB) INTEGRATION
-- Uses a single _draw_widgets hook for state management and
-- rendering. Overrides the layout to a centered 2x2 grid
-- inside the tactical overlay, separate from the mission-end
-- screen layout. Handles widget lifecycle, stat refresh, and
-- fade alpha matching the native overlay.
-- ============================================================

-- Builds the 2x2 grid of player cards inside the tactical overlay's widget set.
-- Seeds fake player data when test mode is active in Psykhanium.
function mod:_ISP_seed_tactical_panel(tac)
    local UIWidget = mod:original_require("scripts/managers/ui/ui_widget")
    local UIWorkspaceSettings = mod:original_require("scripts/settings/ui/ui_workspace_settings")

    local is_test = mod:get("test_mode") == true
    local all_players = {}

    if is_test and mod:ISP_is_psykhanium() then
        local real_player
        for _, p in pairs(managers.player:players()) do
            real_player = p
            break
        end
        if real_player then
            all_players[#all_players + 1] = real_player
            mod:ISP_ensure_player(mod:ISP_account_id(real_player))
        end
        while #all_players < 4 do
            local idx = #all_players + 1
            all_players[#all_players + 1] = make_fake_player("player_" .. idx, TEST_ARCHETYPES[idx], idx)
        end
        -- Seed fake player stats with random values
        local rng = math.random
        local active_stats = mod:_ISP_active_stats()
        for _, p in pairs(all_players) do
            local aid = mod:ISP_account_id(p)
            local is_real = real_player and aid == mod:ISP_account_id(real_player)
            if not is_real then
                mod:ISP_ensure_player(aid)
                local s = mod.ISP_player_stats[aid]
                for _, def in pairs(active_stats) do
                    s[def.key] = s[def.key] or rng(1, 9)
                end
            end
        end
    else
        for _, p in pairs(managers.player:players()) do
            all_players[#all_players + 1] = p
            if #all_players >= 4 then break end
        end
        if #all_players == 0 then return end
        for _, p in pairs(all_players) do
            mod:ISP_ensure_player(mod:ISP_account_id(p))
        end
    end

    mod:_ISP_evaluate_rankings(all_players)
    mod:_ISP_evaluate_ranked_leader()

    local solo = mod:get("solo_mode_tab") == true
    local local_pi = 1
    if solo then
        local local_id = mod:ISP_local_id()
        for pi = 1, #all_players do
            if mod:ISP_account_id(all_players[pi]) == local_id then
                local_pi = pi
                break
            end
        end
    end

    local scale = (math.max(50, mod:_ISP_get_opt("text_scale_tactical", 90))) / 90
    local screen_w = UIWorkspaceSettings.screen.size[1]
    local screen_h = UIWorkspaceSettings.screen.size[2]
    local gap = math.max(1, mod:_ISP_get_opt("row_spacing", 10))
    local box_alpha = mod:_ISP_get_opt("box_opacity_tactical", 150)
    local hs_r = mod:_ISP_get_opt("highscore_color_r", 0)
    local hs_g = mod:_ISP_get_opt("highscore_color_g", 255)
    local hs_b = mod:_ISP_get_opt("highscore_color_b", 0)
    local sl_r = mod:_ISP_get_opt("stat_label_color_r", 255)
    local sl_g = mod:_ISP_get_opt("stat_label_color_g", 255)
    local sl_b = mod:_ISP_get_opt("stat_label_color_b", 255)

    local font_size = math_floor(18 * scale)
    local name_font_size = math_floor(20 * scale)
    local stat_label_font = math_floor(14 * scale)
    local stat_h = math_floor(18 * scale)
    local name_h = math_floor(24 * scale)
    local active_stats = mod:_ISP_active_stats()
    local stat_count = #active_stats
    local padding = math_floor(12 * scale)
    local box_width = math.max(120, mod:_ISP_get_opt("box_width", 200))
    local card_w = math_floor(box_width * scale)
    local content_w = card_w - padding * 2
    local label_col_w = math_floor(content_w * 0.62)
    local val_col_w = content_w - label_col_w
    local name_to_stats_gap = math_floor(6 * scale)
    local stat_line_gap = 2
    local card_h = padding + name_h + name_to_stats_gap + stat_count * stat_h + (stat_count - 1) * stat_line_gap + padding

    -- 2x2 grid centered on screen
    local columns = solo and 1 or 2
    local grid_w = columns * card_w + (columns - 1) * gap
    local rows = solo and 1 or math.ceil(#all_players / columns)
    local grid_h = rows * card_h + (rows - 1) * gap
    local tac_ox = mod:_ISP_get_opt("tactical_offset_x", 0)
    local tac_oy = mod:_ISP_get_opt("tactical_offset_y", 0)
    local origin_x = (screen_w - grid_w) / 2 + tac_ox
    local origin_y = (screen_h - grid_h) / 2 + tac_oy

    local cards = {}
    local stroke_cards = {}
    for pi = 1, #all_players do
        if solo and pi ~= local_pi then
            -- skip non-local players in solo mode
        else
            local player = all_players[pi]
            local aid = mod:ISP_account_id(player)
            local pname = player:name() or "Unknown"
            local profile = player.profile and player:profile()
            local archetype = profile and profile.archetype and profile.archetype.name
            local symbol = player.string_symbol or (archetype and UISettings.archetype_font_icon and UISettings.archetype_font_icon[archetype])
            local display_name = symbol and (symbol .. " " .. pname) or pname
            local name_pizazz = mod:get("mod_name_pizazz_toggle") ~= false
            local name_color = get_name_color(player, name_pizazz)

            local col = solo and 0 or ((pi - 1) % columns)
            local row = solo and 0 or math_floor((pi - 1) / columns)
        local cell_x = origin_x + col * (card_w + gap)
        local cell_y = origin_y + row * (card_h + gap)
        local passes = {}

        passes[#passes + 1] = {
            pass_type = "rect",
            style = {
                offset = { 0, 0, 20 },
                size = { card_w, card_h },
                color = { box_alpha, 12, 12, 16 },
            },
        }
        local player_name_font = _name_font(display_name)
        passes[#passes + 1] = {
            value_id = "player_name",
            value = display_name,
            pass_type = "text",
            style = {
                offset = { padding, padding, 21 },
                size = { card_w - padding * 2, name_h },
                font_size = name_font_size,
                font_type = player_name_font,
                text_horizontal_alignment = "left",
                text_vertical_alignment = "center",
                text_color = name_color,
            },
        }

        local first_stat_y = padding + name_h + name_to_stats_gap
        for si = 1, stat_count do
            local def = active_stats[si]
            local raw_val = (mod.ISP_player_stats[aid] and mod.ISP_player_stats[aid][def.key]) or 0
            local display_val = def.shorten and mod:ISP_format_num(raw_val) or string_format("%.0f", raw_val)
            local loc_key = mod:get("minimal_stat_labels") and def.min_loc or def.loc
            local label = mod:localize(loc_key)

            local val_color = { 255, 200, 200, 200 }
            if mod.ISP_rankings and mod.ISP_rankings[def.key] then
                local r = mod.ISP_rankings[def.key]
                if r.best and r.best[aid] then
                    val_color = { 255, hs_r, hs_g, hs_b }
                elseif r.worst and r.worst[aid] and raw_val > 0 then
                    val_color = { 255, 140, 140, 140 }
                end
            end

            local sy = first_stat_y + (si - 1) * (stat_h + stat_line_gap)
            local card_idx = #cards + 1
            passes[#passes + 1] = {
                value_id = "stat_label_" .. def.key .. "_" .. card_idx,
                value = label .. ":",
                pass_type = "text",
                style = {
                    offset = { padding, sy, 21 },
                    size = { label_col_w, stat_h },
                    font_size = stat_label_font,
                    font_type = "machine_medium",
                    text_horizontal_alignment = "left",
                    text_vertical_alignment = "center",
                    text_color = { 255, sl_r, sl_g, sl_b },
                },
            }
            passes[#passes + 1] = {
                value_id = "stat_" .. def.key .. "_" .. card_idx,
                value = display_val,
                pass_type = "text",
                style = {
                    offset = { padding + label_col_w, sy, 21 },
                    size = { val_col_w, stat_h },
                    font_size = font_size,
                    font_type = "machine_medium",
                    text_horizontal_alignment = "right",
                    text_vertical_alignment = "center",
                    text_color = val_color,
                },
            }
        end

        local wdef = UIWidget.create_definition(passes, "screen", nil, { card_w, card_h })
        local w = mod:_ISP_make_widget("isp_tac_card_" .. pi, wdef)
        w.offset = { cell_x, cell_y, 20 }
        cards[#cards + 1] = w

        -- Ranked mode stroke widget (behind the card, controlled by alpha_multiplier)
        local stroke_passes = {
            {
                pass_type = "rect",
                style = {
                    offset = { 0, 0, 0 },
                    size = { card_w + 6, card_h + 6 },
                    color = { 255, hs_r, hs_g, hs_b },
                },
            },
        }
        local stroke_wdef = UIWidget.create_definition(stroke_passes, "screen", nil, { card_w + 6, card_h + 6 })
        local stroke_w = mod:_ISP_make_widget("isp_tac_stroke_" .. pi, stroke_wdef)
        stroke_w.offset = { cell_x - 3, cell_y - 3, 20 }
        stroke_w.alpha_multiplier = 0
        stroke_cards[#stroke_cards + 1] = stroke_w
        end
    end

    tac._isp_tactical_panel = cards
    tac._isp_stroke_cards = stroke_cards
end

-- Refreshes stat values, name colors, and ranking highlights on the tactical overlay's 2x2 grid every frame.
function mod:_ISP_update_tactical_panel(tac, dt)
    local cards = tac._isp_tactical_panel
    if not cards then return end

    local is_test = mod:get("test_mode") == true
    local all_players = {}
    local real_player

    if is_test and mod:ISP_is_psykhanium() then
        for _, p in pairs(managers.player:players()) do
            real_player = p
            break
        end
        if real_player then
            all_players[#all_players + 1] = real_player
        end
        while #all_players < 4 do
            local idx = #all_players + 1
            all_players[#all_players + 1] = make_fake_player("player_" .. idx, TEST_ARCHETYPES[idx], idx)
        end
    else
        for _, p in pairs(managers.player:players()) do
            all_players[#all_players + 1] = p
            if #all_players >= 4 then break end
        end
        if #all_players == 0 then return end
    end

    for _, p in pairs(all_players) do
        mod:ISP_ensure_player(mod:ISP_account_id(p))
    end
    mod:_ISP_evaluate_rankings(all_players)
    mod:_ISP_evaluate_ranked_leader()

    local hs_r = mod:_ISP_get_opt("highscore_color_r", 0)
    local hs_g = mod:_ISP_get_opt("highscore_color_g", 255)
    local hs_b = mod:_ISP_get_opt("highscore_color_b", 0)
    local sl_r = mod:_ISP_get_opt("stat_label_color_r", 255)
    local sl_g = mod:_ISP_get_opt("stat_label_color_g", 255)
    local sl_b = mod:_ISP_get_opt("stat_label_color_b", 255)
    local name_pizazz = mod:get("mod_name_pizazz_toggle") ~= false
    local active_stats = mod:_ISP_active_stats()
    local stat_count = #active_stats

    local solo = mod:get("solo_mode_tab") == true
    local local_pi = 1
    if solo then
        local local_id = mod:ISP_local_id()
        for pi = 1, #all_players do
            if mod:ISP_account_id(all_players[pi]) == local_id then
                local_pi = pi
                break
            end
        end
    end

    for pi = 1, #cards do
        local data_pi = solo and local_pi or pi
        local player = all_players[data_pi]
        local aid = mod:ISP_account_id(player)
        local w = cards[pi]

        local name_color = get_name_color(player, name_pizazz)
        if w.style.player_name then
            w.style.player_name.text_color = name_color
            w.dirty = true
        end

        for si = 1, stat_count do
            local def = active_stats[si]
            local raw_val = (mod.ISP_player_stats[aid] and mod.ISP_player_stats[aid][def.key]) or 0
            local display_val = def.shorten and mod:ISP_format_num(raw_val) or string_format("%.0f", raw_val)

            local cid = "stat_" .. def.key .. "_" .. pi
            if w.content[cid] ~= nil then
                w.content[cid] = display_val
            end

            local val_color = { 255, 200, 200, 200 }
            if mod.ISP_rankings and mod.ISP_rankings[def.key] then
                local r = mod.ISP_rankings[def.key]
                if r.best and r.best[aid] then
                    val_color = { 255, hs_r, hs_g, hs_b }
                elseif r.worst and r.worst[aid] and raw_val > 0 then
                    val_color = { 255, 140, 140, 140 }
                end
            end

            local style_key = "stat_" .. def.key .. "_" .. pi
            if w.style[style_key] then
                w.style[style_key].text_color = val_color
            end
            local label_key = "stat_label_" .. def.key .. "_" .. pi
            if w.style[label_key] then
                w.style[label_key].text_color = { 255, sl_r, sl_g, sl_b }
            end
            w.dirty = true
        end
        -- Update ranked mode stroke
        if mod:get("ranked_mode") then
            local stroke_cards = tac._isp_stroke_cards
            if stroke_cards and stroke_cards[pi] then
                local is_leader = mod.ISP_ranked_leader and mod.ISP_ranked_leader[aid]
                stroke_cards[pi].alpha_multiplier = is_leader and 1 or 0
            end
        end
    end
end

-- Single hook on _draw_widgets handles both the widget lifecycle and rendering,
-- keeping the tactical overlay code structurally distinct from the EndView pattern.
-- Hook: HudElementTacticalOverlay._draw_widgets — Manages the entire tactical overlay lifecycle: builds cards when TAB opens, refreshes stats each frame, tears down on close, and renders widgets on top of the native overlay with matching fade alpha.
mod:hook(CLASS.HudElementTacticalOverlay, "_draw_widgets", function(func, self, dt, t, input_service, ui_renderer, render_settings, ...)
    local active = self._active
    local enabled = mod:get("show_in_mission") ~= false and not mod:ISP_is_in_hub()
    local panel = self._isp_tactical_panel
    local is_test = mod:get("test_mode") == true

    -- Build panel when overlay opens
    if enabled and active and not panel then
        mod._isp_tab_active = true
        mod:_ISP_seed_tactical_panel(self)
        panel = self._isp_tactical_panel
    end

    -- Refresh values while active
    if enabled and active and panel then
        mod:_ISP_update_tactical_panel(self, dt)
    end

    -- When test mode is on, suppress the test view and show the tactical overlay instead
    if enabled and active and is_test then
        mod:ISP_close_test_view()
    end

    -- Tear down when overlay closes or toggle is off
    if (not active or not enabled) and panel then
        self._isp_tactical_panel = nil
        self._isp_stroke_cards = nil
        mod._isp_tab_active = false
    end

    -- Let the native overlay finish its render pass
    func(self, dt, t, input_service, ui_renderer, render_settings, ...)

    -- Draw mod widgets on top, matching the overlay's fade alpha
    if enabled and active and self._isp_tactical_panel then
        if self._isp_stroke_cards then
            for _, w in pairs(self._isp_stroke_cards) do
                UIWidget.draw(w, ui_renderer)
            end
        end
        for _, w in pairs(self._isp_tactical_panel) do
            w.alpha_multiplier = self._alpha_multiplier or 0
            UIWidget.draw(w, ui_renderer)
        end
    end
end)

-- ============================================================
-- SCOREBOARD GRAPH VIEW
-- ============================================================

local function _graph_tier_color(tier)
    local r, g, b
    if tier == 4 then
        r = mod:get("graph_perfect_r") or 0
        g = mod:get("graph_perfect_g") or 255
        b = mod:get("graph_perfect_b") or 0
    elseif tier == 3 then
        r = mod:get("graph_green_r") or 255
        g = mod:get("graph_green_g") or 255
        b = mod:get("graph_green_b") or 0
    elseif tier == 2 then
        r = mod:get("graph_yellow_r") or 255
        g = mod:get("graph_yellow_g") or 128
        b = mod:get("graph_yellow_b") or 0
    elseif tier == 1 then
        r = mod:get("graph_red_r") or 255
        g = mod:get("graph_red_g") or 0
        b = mod:get("graph_red_b") or 0
    else
        r, g, b = 128, 128, 128
    end
    return { 255, r, g, b }
end

local function _graph_make_rect(pos_x, pos_y, w, h, color, depth)
    return UIWidget.create_definition({
        {
            pass_type = "rect",
            style = {
                color = color,
                size = { w, h },
                offset = { pos_x, pos_y, depth or 0 },
            },
        },
    }, "screen", nil, { w, h })
end

local function _graph_make_text(text_str, pos_x, pos_y, font_size, color, depth, alignment, box_w, font_type)
    local ha = alignment or "left"
    local bw = box_w or 900
    local ft = font_type or "machine_medium"
    return UIWidget.create_definition({
        {
            pass_type = "text",
            value = text_str,
            style = {
                font_size = font_size,
                font_type = ft,
                text_color = Color(unpack(color)),
                text_horizontal_alignment = ha,
                offset = { pos_x, pos_y, depth or 1 },
                size = { bw, font_size + 4 },
            },
        },
    }, "screen", nil, { bw, font_size + 4 })
end

local ImprovedScoreboardGraphView = class("ImprovedScoreboardGraphView", "BaseView")

ImprovedScoreboardGraphView.init = function(self, settings, context)
    ImprovedScoreboardGraphView.super.init(self, definitions, settings, context)
    self._pass_draw = true
    self._pass_input = true
end

ImprovedScoreboardGraphView.is_using_input = function(self)
    return true
end

ImprovedScoreboardGraphView.on_enter = function(self)
    ImprovedScoreboardGraphView.super.on_enter(self)
end

ImprovedScoreboardGraphView.on_exit = function(self)
    if IS_WINDOWS then
        Application.set_in_menu(false)
    end
    ImprovedScoreboardGraphView.super.on_exit(self)
end

ImprovedScoreboardGraphView.update = function(self, dt, t, input_service, view_data)
    local pass_input, pass_draw = ImprovedScoreboardGraphView.super.update(self, dt, t, input_service)
    return pass_input, pass_draw
end

ImprovedScoreboardGraphView.draw = function(self, dt, t, input_service, layer)
    ImprovedScoreboardGraphView.super.draw(self, dt, t, input_service, layer)

    local render_settings = self._render_settings
    render_settings.start_layer = layer

    UIRenderer.begin_pass(self._ui_renderer, self._ui_scenegraph, input_service, dt, render_settings)

    local scale = math.max(50, mod:get("graph_window_scale") or 100) / 100
    local data = mod._isp_graph_data or { lifetime = {}, missions = {}, cumulative = {} }
    local missions = data.missions or {}
    local lifetime = data.lifetime or {}
    local cumulative = data.cumulative or {}

    -- Seed retroactive XP from backend progression if not yet set.
    -- All writes go to _isp_full_data in memory — persists at game exit.
    if cumulative.xp == nil and not mod._isp_xp_seeding then
        mod._isp_xp_seeding = true
        local local_player = mod.player_manager and mod.player_manager:local_player(1)
        if local_player then
            local character_id = local_player:character_id()
            if not character_id then
                local profile = local_player:profile()
                character_id = profile and profile.character_id
            end
            if character_id then
                local backend = Managers.backend
                if backend and backend.interfaces and backend.interfaces.progression then
                    if mod:get("graph_per_character") then
                        -- Per-character: seed only the current character's XP
                        local promise = backend.interfaces.progression:get_progression("character", character_id)
                        if promise and promise.next then
                            promise:next(function(prog)
                                if prog and prog.currentXp and mod._isp_full_data then
                                    mod._isp_full_data.cumulative[character_id] = mod._isp_full_data.cumulative[character_id] or {}
                                    mod._isp_full_data.cumulative[character_id].xp = prog.currentXp
                                    mod._isp_graph_data = mod:_ISP_load_graph_data()
                                end
                                mod._isp_xp_seeding = nil
                            end, function()
                                mod._isp_xp_seeding = nil
                            end)
                        else
                            mod._isp_xp_seeding = nil
                        end
                    else
                        -- Account-wide: seed each known character's individual XP
                        local known = mod:get("graph_known_ids") or ""
                        local ids = {}
                        if known ~= "" then
                            for cid in known:gmatch("[^,]+") do
                                ids[#ids + 1] = cid
                            end
                        end
                        if #ids == 0 then
                            ids[1] = character_id
                        end
                        local total_xp = 0
                        local pending = #ids
                        for _, cid in ipairs(ids) do
                            local promise = backend.interfaces.progression:get_progression("character", cid)
                            if promise and promise.next then
                                promise:next(function(prog)
                                    local char_xp = (prog and prog.currentXp) or 0
                                    if char_xp > 0 and mod._isp_full_data then
                                        mod._isp_full_data.cumulative[cid] = mod._isp_full_data.cumulative[cid] or {}
                                        mod._isp_full_data.cumulative[cid].xp = char_xp
                                        total_xp = total_xp + char_xp
                                    end
                                    pending = pending - 1
                                    if pending <= 0 then
                                        data.cumulative.xp = total_xp
                                        mod._isp_graph_data = data
                                        mod._isp_xp_seeding = nil
                                    end
                                end, function()
                                    pending = pending - 1
                                    if pending <= 0 then
                                        mod._isp_xp_seeding = nil
                                    end
                                end)
                            else
                                pending = pending - 1
                                if pending <= 0 then
                                    mod._isp_xp_seeding = nil
                                end
                            end
                        end
                    end
                else
                    mod._isp_xp_seeding = nil
                end
            else
                mod._isp_xp_seeding = nil
            end
        else
            mod._isp_xp_seeding = nil
        end
    end

    local padding = 40 * scale
    local screen_w = UIWorkspaceSettings.screen.size[1]
    local screen_h = UIWorkspaceSettings.screen.size[2]

    local sq = 16 * scale
    local sq_gap = 3 * scale
    local cell = sq + sq_gap
    local cols = 50
    local grid_area_w = cols * cell - sq_gap

    local panel_w = grid_area_w + padding * 2
    local panel_x = (screen_w - panel_w) / 2
    local visible_rows = 5
    local grid_area_h = visible_rows * cell - sq_gap
    local graph_h = 100 * scale
    local stat_rows = 0
    do
        local a, b = 0, 0
        for _, def in ipairs(mod.ISP_STAT_DEFS or {}) do
            if def.key == "kills" or def.key == "melee_kills" or def.key == "dmg_dealt" or def.key == "specials" or def.key == "bosses" or def.key == "revives" or def.key == "rescues" then
                a = a + 1
            elseif def.key == "ranged_kills" or def.key == "headshots" or def.key == "dmg_taken" or def.key == "elites" or def.key == "boss_damage" or def.key == "barrels_exploded" or def.key == "relics" then
                b = b + 1
            end
        end
        stat_rows = math.max(a, b)
    end
    local content_above = 36 * scale + 24 * scale + 20 * scale * 3 + 20 * scale + stat_rows * 20 * scale + 16 * scale + 20 * scale + 24 * scale
    local panel_h = padding + content_above + grid_area_h + 52 * scale + graph_h + 28 * scale + sq + 28 * scale
    local panel_y = (screen_h - panel_h) / 2

    local bg_alpha = mod:get("graph_bg_opacity") or 200
    local hs_r = mod:get("highscore_color_r") or 0
    local hs_g = mod:get("highscore_color_g") or 255
    local hs_b = mod:get("highscore_color_b") or 0
    local hs_color = { 255, hs_r, hs_g, hs_b }
    local label_color = { 255, mod:get("stat_label_color_r") or 255, mod:get("stat_label_color_g") or 255, mod:get("stat_label_color_b") or 255 }
    local empty_r = mod:get("graph_empty_r") or 128
    local empty_g = mod:get("graph_empty_g") or 128
    local empty_b = mod:get("graph_empty_b") or 128
    local empty_color = { 255, empty_r, empty_g, empty_b }

    local wi = 0
    local function wname()
        wi = wi + 1
        return "gw" .. tostring(wi)
    end

    UIWidget.draw(UIWidget.init(wname(), _graph_make_rect(panel_x, panel_y, panel_w, panel_h, { bg_alpha, 10, 12, 18 }, 0)), self._ui_renderer)

    local cy = panel_y + 36 * scale

    local font_small = 13 * scale
    local font_medium = 16 * scale
    local card_line_h = 20 * scale
    local card_inner_w = grid_area_w
    local card_x = panel_x + (panel_w - card_inner_w) / 2

    -- Title with keybind
    local keybind_tbl = mod:get("graph_keybind")
    local key_str = "F5"
    if keybind_tbl and type(keybind_tbl) == "table" and #keybind_tbl > 0 then
        key_str = keybind_tbl[1]
    end
    local title_text = "Improved Scoreboard Panel"
    local key_text = " [" .. key_str .. "]"
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text(title_text, card_x, cy, 24 * scale, label_color, 1)), self._ui_renderer)
    local title_px = #title_text * (24 * scale * 0.427)
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text(key_text, card_x + title_px, cy, 24 * scale, hs_color, 1)), self._ui_renderer)
    cy = cy + 36 * scale

    local lp = mod.player_manager and mod.player_manager:local_player(1)
    local player_name = lp and (lp:name() or "You") or "You"

    UIWidget.draw(UIWidget.init(wname(), _graph_make_text(player_name, card_x, cy, font_medium, hs_color, 1, nil, nil, _name_font(player_name))), self._ui_renderer)
    cy = cy + card_line_h + 4 * scale

    local total_highscores = 0
    for _, m in ipairs(missions) do
        if m.tier and m.tier >= 1 then total_highscores = total_highscores + 1 end
    end
    local total_highscores_earned = 0
    for _, def in ipairs(mod.ISP_STAT_DEFS or {}) do
        total_highscores_earned = total_highscores_earned + (lifetime[def.key] or 0)
    end
    local hi_col_w = card_inner_w / 4
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text("Total Missions Completed: ", card_x, cy, font_small, label_color, 1)), self._ui_renderer)
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text(tostring(total_highscores), card_x + hi_col_w, cy, font_small, hs_color, 1)), self._ui_renderer)
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text("Total Highscores Earned: ", card_x + hi_col_w * 2, cy, font_small, label_color, 1)), self._ui_renderer)
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text(tostring(total_highscores_earned), card_x + hi_col_w * 3, cy, font_small, hs_color, 1)), self._ui_renderer)
    cy = cy + card_line_h

    UIWidget.draw(UIWidget.init(wname(), _graph_make_text("Plasteel Collected: ", card_x, cy, font_small, label_color, 1)), self._ui_renderer)
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text(tostring(cumulative.plasteel or 0), card_x + hi_col_w, cy, font_small, hs_color, 1)), self._ui_renderer)
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text("Ordo Dockets Earned: ", card_x + hi_col_w * 2, cy, font_small, label_color, 1)), self._ui_renderer)
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text(tostring(cumulative.dockets or 0), card_x + hi_col_w * 3, cy, font_small, hs_color, 1)), self._ui_renderer)
    cy = cy + card_line_h

    UIWidget.draw(UIWidget.init(wname(), _graph_make_text("Diamantine Collected: ", card_x, cy, font_small, label_color, 1)), self._ui_renderer)
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text(tostring(cumulative.diamantine or 0), card_x + hi_col_w, cy, font_small, hs_color, 1)), self._ui_renderer)
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text("Experience Points Earned: ", card_x + hi_col_w * 2, cy, font_small, label_color, 1)), self._ui_renderer)
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text(tostring(cumulative.xp or 0), card_x + hi_col_w * 3, cy, font_small, hs_color, 1)), self._ui_renderer)
    cy = cy + card_line_h

    UIWidget.draw(UIWidget.init(wname(), _graph_make_rect(card_x, cy, card_inner_w, 1, { 80, mod:get("stat_label_color_r") or 255, mod:get("stat_label_color_g") or 255, mod:get("stat_label_color_b") or 255 }, 1)), self._ui_renderer)
    cy = cy + 20 * scale

    local stat_defs = mod.ISP_STAT_DEFS or {}
    local grid_start_x = card_x
    local grid_start_y = cy
    local grid_cell_h = card_line_h
    local group_a = {}
    local group_b = {}
    for _, def in ipairs(stat_defs) do
        if def.key == "kills" or def.key == "melee_kills" or def.key == "dmg_dealt" or def.key == "specials" or def.key == "bosses" or def.key == "revives" or def.key == "rescues" then
            group_a[#group_a + 1] = def
        elseif def.key == "ranged_kills" or def.key == "headshots" or def.key == "dmg_taken" or def.key == "elites" or def.key == "boss_damage" or def.key == "barrels_exploded" or def.key == "relics" then
            group_b[#group_b + 1] = def
        end
    end
    stat_rows = math.max(#group_a, #group_b)
    local col_w = card_inner_w / 4
    for ri = 1, stat_rows do
        local ry = grid_start_y + (ri - 1) * grid_cell_h
        if group_a[ri] then
            local def = group_a[ri]
            local label = (mod:localize(def.loc) or def.loc or def.key) .. ": "
            local val = tostring(cumulative[def.key] or lifetime[def.key] or 0)
            UIWidget.draw(UIWidget.init(wname(), _graph_make_text(label, grid_start_x, ry, font_small, label_color, 1)), self._ui_renderer)
            UIWidget.draw(UIWidget.init(wname(), _graph_make_text(val, grid_start_x + col_w, ry, font_small, hs_color, 1)), self._ui_renderer)
        end
        if group_b[ri] then
            local def = group_b[ri]
            local label = (mod:localize(def.loc) or def.loc or def.key) .. ": "
            local val = tostring(cumulative[def.key] or lifetime[def.key] or 0)
            local bx = grid_start_x + col_w * 2
            UIWidget.draw(UIWidget.init(wname(), _graph_make_text(label, bx, ry, font_small, label_color, 1)), self._ui_renderer)
            UIWidget.draw(UIWidget.init(wname(), _graph_make_text(val, bx + col_w, ry, font_small, hs_color, 1)), self._ui_renderer)
        end
    end

    cy = grid_start_y + stat_rows * grid_cell_h + 16 * scale

    -- Divider between tracked stats and legend
    UIWidget.draw(UIWidget.init(wname(), _graph_make_rect(card_x, cy, card_inner_w, 1, { 80, mod:get("stat_label_color_r") or 255, mod:get("stat_label_color_g") or 255, mod:get("stat_label_color_b") or 255 }, 1)), self._ui_renderer)
    cy = cy + 20 * scale

    -- 50x5 Missions grid (most recent 250 missions, no scroll)
    local grid_x = card_x
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text("Last 250 Missions:", grid_x, cy, font_medium, label_color, 1)), self._ui_renderer)
    cy = cy + font_medium + 8 * scale
    local grid_y = cy
    local total_missions = #missions

    UIWidget.draw(UIWidget.init(wname(), _graph_make_rect(grid_x, grid_y, grid_area_w, grid_area_h, empty_color, 1)), self._ui_renderer)

    -- Fill rows 0-4 left-to-right, top-to-bottom, most recent 250 missions
    local grid_mission_count = math.min(total_missions, visible_rows * cols)
    local display_start = total_missions - grid_mission_count + 1
    local row_tiers = {}
    for mi = display_start, total_missions do
        local local_idx = mi - display_start
        local mr = math.floor(local_idx / cols)
        local mc = local_idx % cols
        if not row_tiers[mr] then
            row_tiers[mr] = {}
        end
        row_tiers[mr][mc] = missions[mi].tier or 0
    end

    local tier0_color = _graph_tier_color(0)
    local tier1_color = _graph_tier_color(1)
    local tier2_color = _graph_tier_color(2)
    local tier3_color = _graph_tier_color(3)
    local tier4_color = _graph_tier_color(4)

    for r = 0, visible_rows - 1 do
        local row_y = grid_y + r * cell
        local tiers = row_tiers[r]
        for c = 0, cols - 1 do
            local tier = (tiers and tiers[c]) or 0
            if tier == 0 then
                UIWidget.draw(UIWidget.init(wname(), _graph_make_rect(grid_x + c * cell, row_y, sq, sq, tier0_color, 2)), self._ui_renderer)
            elseif tier == 1 then
                UIWidget.draw(UIWidget.init(wname(), _graph_make_rect(grid_x + c * cell, row_y, sq, sq, tier1_color, 2)), self._ui_renderer)
            elseif tier == 2 then
                UIWidget.draw(UIWidget.init(wname(), _graph_make_rect(grid_x + c * cell, row_y, sq, sq, tier2_color, 2)), self._ui_renderer)
            elseif tier == 3 then
                UIWidget.draw(UIWidget.init(wname(), _graph_make_rect(grid_x + c * cell, row_y, sq, sq, tier3_color, 2)), self._ui_renderer)
            elseif tier == 4 then
                UIWidget.draw(UIWidget.init(wname(), _graph_make_rect(grid_x + c * cell, row_y, sq, sq, tier4_color, 2)), self._ui_renderer)
            end
        end
    end

    -- Tree Map: tier distribution
    local tree_title_y = grid_y + grid_area_h + 28 * scale
    UIWidget.draw(UIWidget.init(wname(), _graph_make_text("Overall Performance:", grid_x, tree_title_y, font_medium, label_color, 1)), self._ui_renderer)
    local tree_top = tree_title_y + font_medium + 8 * scale
    local tree_w = grid_area_w
    local tree_x = grid_x
    local tree_h = graph_h
    local gap = 3 * scale

    UIWidget.draw(UIWidget.init(wname(), _graph_make_rect(tree_x, tree_top, tree_w, tree_h, { 60, 20, 24, 30 }, 1)), self._ui_renderer)

    local grid_mission_count = math.min(total_missions, visible_rows * cols)
    local grid_start = total_missions - grid_mission_count + 1
    local tier_counts = { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
    for mi = grid_start, total_missions do
        local t = missions[mi].tier or 0
        tier_counts[t] = tier_counts[t] + 1
    end

    local present = {}
    for t = 0, 4 do
        if tier_counts[t] > 0 then
            present[#present + 1] = t
        end
    end

    if #present > 0 then
        local total = grid_mission_count
        local avail_w = tree_w - (#present - 1) * gap
        local cx = tree_x

        for _, t in ipairs(present) do
            local seg_w = (tier_counts[t] / total) * avail_w
            local inset = 2 * scale
            local rx = cx + inset
            local rw = seg_w - inset * 2

            UIWidget.draw(UIWidget.init(wname(), _graph_make_rect(rx, tree_top + 2 * scale, rw, tree_h - 4 * scale, _graph_tier_color(t), 1)), self._ui_renderer)

            local label = "T" .. t .. ": " .. tier_counts[t]
            UIWidget.draw(UIWidget.init(wname(), _graph_make_text(label, cx + seg_w / 2, tree_top + tree_h / 2 - font_small / 2, font_small, label_color, 1)), self._ui_renderer)

            cx = cx + seg_w + gap
        end
    end

    -- Color definitions legend
    local leg_y = tree_top + tree_h + 28 * scale
    for li, item in ipairs({
        { tier = 1, label = "Bad Performance" },
        { tier = 2, label = "Low Performance" },
        { tier = 3, label = "Good Performance" },
        { tier = 4, label = "Perfect Performance" },
    }) do
        local lx = card_x + (li - 1) * (card_inner_w / 4)
        UIWidget.draw(UIWidget.init(wname(), _graph_make_rect(lx, leg_y, sq, sq, _graph_tier_color(item.tier), 1)), self._ui_renderer)
        UIWidget.draw(UIWidget.init(wname(), _graph_make_text(item.label, lx + sq + 4 * scale, leg_y + sq - font_small, font_small, label_color, 1)), self._ui_renderer)
    end

    UIRenderer.end_pass(self._ui_renderer)
end

return ISPV
