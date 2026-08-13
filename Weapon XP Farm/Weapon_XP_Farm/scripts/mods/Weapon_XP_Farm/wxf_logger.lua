local mod = get_mod("Weapon_XP_Farm")

-- ── Per-session file logger ─────────────────────────────────────────────────
-- Writes a human-readable log to  mods/Weapon_XP_Farm/logs/<date>_<time>.txt
-- One file per launched game session (created lazily on the first log line).
--
-- Public API (dot-call, not colon):
--   mod.flog(category, fmt, ...)   write one categorised line
--   mod.flog_section(title)        write a banner separating logical blocks
--
-- Additionally, mod:info / mod:warning / mod:error are wrapped so everything
-- the mod already logs to the game console is mirrored into the file with an
-- auto-detected category.

local _io = (Mods and Mods.lua and Mods.lua.io) or rawget(_G, "io")
local _os = (Mods and Mods.lua and Mods.lua.os) or rawget(_G, "os")

-- Game CWD is <game>/binaries, so mods live at ./../mods/ (same path form the
-- mod loader itself uses).
local LOG_DIR_REL = "./../mods/Weapon_XP_Farm/logs"
local LOG_DIR_WIN = "..\\mods\\Weapon_XP_Farm\\logs"

local _file         = nil
local _open_failed  = false

local CATEGORY_WIDTH = 10

local HEADER_LINES = {
    "=====================================================================",
    " WEAPON XP FARM - SESSION LOG",
    " Session started: %s",
    "=====================================================================",
    "",
    " Categories used in this file:",
    "   [SESSION  ]  mod/view lifecycle (game launch, view open/close)",
    "   [SCREEN   ]  navigation between mod screens",
    "   [USER     ]  every click / choice the user makes",
    "   [PREVIEW  ]  calculated preview values (weapons needed, costs...)",
    "   [DATA     ]  store offers / mastery / inventory / wallet loading",
    "   [BUY      ]  store purchase steps",
    "   [UPGRADE  ]  consecration (rarity upgrade) steps",
    "   [SACRIFICE]  sacrifice automation in the crafting view",
    "   [RESULT   ]  end-of-run summaries",
    "   [WARNING  ] / [ERROR    ]  problems",
    "   [INFO     ]  everything else",
    "",
    "=====================================================================",
    "",
}

local function _try_open()
    if _file then return _file end
    if _open_failed or not (_io and _os) then return nil end

    local stamp = _os.date("%Y-%m-%d_%H-%M-%S")
    local path  = LOG_DIR_REL .. "/" .. stamp .. ".txt"

    local f = _io.open(path, "a")
    if not f then
        -- logs/ folder may not exist yet on this machine — try to create it
        pcall(function() _os.execute('mkdir "' .. LOG_DIR_WIN .. '" 2>nul') end)
        f = _io.open(path, "a")
    end
    if not f then
        _open_failed = true
        return nil
    end

    _file = f
    for _, line in ipairs(HEADER_LINES) do
        f:write(string.format(line, _os.date("%Y-%m-%d %H:%M:%S")), "\n")
    end
    f:flush()
    return f
end

local function _write_line(category, msg)
    local f = _try_open()
    if not f then return end
    local cat = tostring(category or "INFO")
    if #cat < CATEGORY_WIDTH then
        cat = cat .. string.rep(" ", CATEGORY_WIDTH - #cat)
    end
    f:write("[", _os.date("%H:%M:%S"), "] [", cat, "] ", msg, "\n")
    f:flush()   -- flush per line so a crash never loses log data
end

function mod.flog(category, fmt, ...)
    local ok, msg = pcall(string.format, tostring(fmt), ...)
    _write_line(category, ok and msg or tostring(fmt))
end

function mod.flog_section(title)
    local f = _try_open()
    if not f then return end
    f:write("\n---------------------------------------------------------------------\n")
    f:write("  ", tostring(title), "\n")
    f:write("---------------------------------------------------------------------\n")
    f:flush()
end

-- ── Auto-categorisation for mirrored console messages ───────────────────────
local function _categorize(msg)
    local m = msg:lower()
    if m:find("sacrifice") or m:find("reselect") or m:find("mark_items")
        or m:find("pending_sacrifice") or m:find("pattern '") then
        return "SACRIFICE"
    elseif m:find("consecrat") or m:find("upgrade_weapon") then
        return "UPGRADE"
    elseif m:find("purchas") or m:find("store") or m:find("offer") or m:find("brunt") then
        return "BUY"
    elseif m:find("mastery") or m:find("xp") or m:find("calibrat") or m:find("milestone")
        or m:find("name fix") or m:find("no fix") then
        return "DATA"
    elseif m:find("wallet") or m:find("credits") or m:find("plasteel") or m:find("diamantine") then
        return "DATA"
    elseif m:find("cache") or m:find("inventory") or m:find("scan") then
        return "DATA"
    elseif m:find("hook") or m:find("loaded") or m:find("loading") or m:find("init") then
        return "SESSION"
    end
    return "INFO"
end

-- ── Mirror mod:info / mod:warning / mod:error into the file ────────────────
do
    local orig_info    = mod.info
    local orig_warning = mod.warning
    local orig_error   = mod.error

    mod.info = function(self, fmt, ...)
        orig_info(self, fmt, ...)
        local ok, msg = pcall(string.format, tostring(fmt), ...)
        msg = ok and msg or tostring(fmt)
        _write_line(_categorize(msg), msg)
    end

    if type(orig_warning) == "function" then
        mod.warning = function(self, fmt, ...)
            orig_warning(self, fmt, ...)
            local ok, msg = pcall(string.format, tostring(fmt), ...)
            _write_line("WARNING", ok and msg or tostring(fmt))
        end
    end

    if type(orig_error) == "function" then
        mod.error = function(self, fmt, ...)
            orig_error(self, fmt, ...)
            local ok, msg = pcall(string.format, tostring(fmt), ...)
            _write_line("ERROR", ok and msg or tostring(fmt))
        end
    end
end

mod.flog("SESSION", "Game session started — file logger active")
