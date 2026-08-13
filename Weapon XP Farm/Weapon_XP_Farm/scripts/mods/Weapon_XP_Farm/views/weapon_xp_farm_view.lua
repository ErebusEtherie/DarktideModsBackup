local mod         = get_mod("Weapon_XP_Farm")
local MasterItems = mod:original_require("scripts/backend/master_items")

-- Weapon cache written by hooks below; read by _scan_inventory.
local _weapon_cache_ref = function() return mod._weapon_cache or {} end

-- Cache weapon items from a grid layout (InventoryWeaponsView / CraftingModifyView).
local function _cache_items_from_layout(layout)
    if type(layout) ~= "table" then return end
    if not mod._weapon_cache then mod._weapon_cache = {} end
    local count = 0
    for _, entry in ipairs(layout) do
        local item = entry and entry.item
        if item and type(item) == "table" then
            local pp  = item.parent_pattern
            local gid = item.gear_id or (item.gear and item.gear.uuid)
            if pp and gid then
                local raw    = item.gear
                local rarity = 1
                local mdi    = raw and raw.masterDataInstance
                if mdi and mdi.overrides then
                    local r = mdi.overrides.rarity
                    if type(r) == "number" and r >= 1 then rarity = r end
                end
                if rarity == 1 then
                    local r = item.rarity
                    if type(r) == "number" and r >= 1 then rarity = r end
                end
                mod._weapon_cache[gid] = { gear_id = gid, pattern = pp, rarity = rarity, gear = raw }
                count = count + 1
            end
        end
    end
    if count > 0 then
        local total = 0
        for _ in pairs(mod._weapon_cache) do total = total + 1 end
        mod:info("[WXF] weapon cache: captured %d items (total=%d)", count, total)
    end
end

-- InventoryWeaponsView hook is installed at mod-load time in Weapon_XP_Farm.lua.
-- At view-load time, also try CraftingModifyView (available only after Hadron crafting is opened).
do
    local CraftModView = rawget(_G, "CraftingModifyView")
    if CraftModView and CraftModView.present_grid_layout then
        mod:hook_safe(CraftModView, "present_grid_layout", function(_, layout)
            _cache_items_from_layout(layout)
        end)
        mod:info("[WXF] hooked CraftingModifyView.present_grid_layout")
    else
        mod:info("[WXF] CraftingModifyView not in _G at view-load (open Hadron crafting to enable)")
    end
end

mod:info("[WXF] view loading...")

-- â"€â"€ Constants â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
local RARITY_NAMES = { "Profane", "Redeemed", "Anointed", "Exalted", "Transcendent" }
-- Localized display names (RARITY_NAMES stays English so file logs remain readable)
local RARITY_LOC = {
    mod:localize("rarity_1"), mod:localize("rarity_2"), mod:localize("rarity_3"),
    mod:localize("rarity_4"), mod:localize("rarity_5"),
}
local FILTER_LOC = {
    mod:localize("filter_any"), mod:localize("filter_redeemed_plus"),
    mod:localize("filter_anointed_plus"), mod:localize("filter_exalted_plus"),
    mod:localize("filter_transcendent_only"),
}

-- Conservative consecration cost estimates (per step, scale with weapon rating).
-- FALLBACK ONLY: used when the backend cost table isn't available yet (see
-- get_consecrate_costs below). Values are deliberately above observed minimums so
-- the pre-run affordability check doesn't give false "can afford" in that case.
-- Observed step-1 real costs: 89-102 plasteel on store weapons (item level ~380).
local CONSECRATE_COSTS = {
    [2] = { plasteel = 115, diamantine = 0   },
    [3] = { plasteel = 300, diamantine = 0   },
    [4] = { plasteel = 650, diamantine = 110 },
    [5] = { plasteel = 1500, diamantine = 320 },
}

-- Faithful copy of the game's cost scaler from crafting_mechanicus_settings.lua
-- (including its `or 1 * scale` precedence quirk, so our numbers match the server's).
-- item_level defaults to 380 when unknown, same as vanilla.
local function _scale_by_item_level(cost, item_level, item_crafting_costs)
    local item_level_span   = item_crafting_costs.baseItemLevelSpan
    local cost_scaling_span = item_crafting_costs.costScalingSpan
    local scale = item_level_span.scale or 1
    local span_multiplier = math.remap(
        item_level_span.minInt or item_level_span.min or 1 * scale,
        item_level_span.maxInt or item_level_span.max or 380 * scale,
        cost_scaling_span.minInt or cost_scaling_span.min or 1 * scale,
        cost_scaling_span.maxInt or cost_scaling_span.max or 1 * scale,
        (item_level or 380) * scale) / scale
    return math.round(cost * span_multiplier)
end

-- Live consecration cost for upgrading a weapon TO target_tier (from target_tier-1).
-- Reads the same backend table the game's own consecrate screen uses:
--   Managers.backend.interfaces.crafting:crafting_costs().weapon
--     .rarityUpgrade.startCost[<current rarity as string>]
-- scaled by the item's baseItemLevel. Falls back to the CONSECRATE_COSTS estimates
-- if the backend cache isn't populated (e.g. very early after login).
-- Returns: {plasteel=N, diamantine=N}, is_live(boolean)
-- Memoized per (tier, item level): _refresh_configure calls this every frame for
-- every weapon in the batch; the backend cost table is static for the session so
-- recomputing the scaling math each frame is pure waste. Live results only are
-- cached, so a later-arriving backend table replaces earlier fallback results.
local _cc_cache = {}
local function get_consecrate_costs(target_tier, item)
    local lvl_key = item and (item.baseItemLevel or item.itemLevel
        or (item.masterDataInstance and item.masterDataInstance.overrides
            and item.masterDataInstance.overrides.baseItemLevel)) or 380
    local cache_key = target_tier .. ":" .. tostring(lvl_key)
    local hit = _cc_cache[cache_key]
    if hit then return hit, true end
    local ok, res = pcall(function()
        local cc  = Managers.backend.interfaces.crafting:crafting_costs()
        local wcc = cc and cc.weapon
        local sc  = wcc and wcc.rarityUpgrade and wcc.rarityUpgrade.startCost
        local list = sc and sc[tostring(target_tier - 1)]
        if not list or #list == 0 then return nil end
        -- item may be a master item (baseItemLevel directly) or a raw backend
        -- gear object (nested under masterDataInstance.overrides); nil -> 380 default
        local item_level = item and (item.baseItemLevel or item.itemLevel
            or (item.masterDataInstance and item.masterDataInstance.overrides
                and item.masterDataInstance.overrides.baseItemLevel))
        local out = { plasteel = 0, diamantine = 0 }
        for _, cost in ipairs(list) do
            local amount = _scale_by_item_level(cost.amount or 0, item_level, wcc)
            local t = tostring(cost.type or ""):lower()
            if t == "plasteel" then
                out.plasteel = out.plasteel + amount
            elseif t == "diamantine" then
                out.diamantine = out.diamantine + amount
            end
        end
        return out
    end)
    if ok and res then
        _cc_cache[cache_key] = res
        return res, true
    end
    return CONSECRATE_COSTS[target_tier], false
end

local NUM_ROWS = 10
local NUM_OPTS = 5   -- dropdown options (0 = Profane / no consec, 1-4 = steps)

-- Auto Max Mastery constants
local MAX_MASTERY_LEVEL = 20
local MAX_MASTERY_XP    = 277395   -- fallback; overwritten at runtime from milestones[20].xpLimit
-- XP gained per sacrifice at each rarity tier (confirmed values; overwritten by live calibration).
local SACRIFICE_XP = {
    [1] =      0,  -- Profane      (confirmed — gives no mastery XP)
    [2] =   7830,  -- Redeemed     (confirmed)
    [3] =   8070,  -- Anointed     (confirmed)
    [4] =   8070,  -- Exalted      (confirmed)
    [5] =  11190,  -- Transcendent (confirmed)
}
-- A live-calibration reading below this fraction of the confirmed default is treated as
-- corrupt/stale (e.g. a partially-consecrated weapon diluting the average, or a mastery-XP
-- read that hadn't finished refreshing) and rejected rather than persisted or trusted.
-- Without this guard a single bad reading can silently inflate "weapons needed" by 10-20x
-- for the rest of the mod's life, since the bad value is saved to disk.
local SACRIFICE_XP_MIN_RATIO = 0.5
local function _is_plausible_sacrifice_xp(tier, value)
    local default = SACRIFICE_XP[tier]
    if not default or default <= 0 then return true end
    return value >= default * SACRIFICE_XP_MIN_RATIO
end
-- Overwrite with any values measured in previous sessions
do
    for tier = 1, 5 do
        local saved = mod:get("sacrifice_xp_" .. tier)
        if type(saved) == "number" and saved >= 0 then
            if _is_plausible_sacrifice_xp(tier, saved) then
                SACRIFICE_XP[tier] = saved
            else
                -- Corrupt/stale calibration from a previous session — discard and self-heal.
                mod:set("sacrifice_xp_" .. tier, nil)
                mod:info("[WXF] discarded implausible saved SACRIFICE_XP[%d]=%d (default=%d)",
                    tier, saved, SACRIFICE_XP[tier])
            end
        end
    end
    local saved_max_xp = mod:get("max_mastery_xp")
    if type(saved_max_xp) == "number" and saved_max_xp > 0 then
        MAX_MASTERY_XP = saved_max_xp
    end
end

-- Calculate weapons needed to reach max mastery.
-- current_xp_total: total cumulative mastery XP accumulated (from get_all_masteries current_xp field).
-- Returns: weapons_needed, xp_remaining, levels_remaining, xp_per_sac
local function calc_auto_amount(entry, rarity_tier, current_xp_total)
    local cur_lvl      = entry.mastery_level or 0
    if cur_lvl >= MAX_MASTERY_LEVEL then return 0, 0, 0, 0 end
    local xp_done      = current_xp_total or 0
    local xp_remaining = math.max(0, MAX_MASTERY_XP - xp_done)
    local xp_per_sac   = SACRIFICE_XP[rarity_tier] or 7830
    local lvls_rem     = MAX_MASTERY_LEVEL - cur_lvl
    if xp_per_sac <= 0 then return 0, xp_remaining, lvls_rem, 0 end
    local weapons_needed = math.ceil(xp_remaining / xp_per_sac)
    return weapons_needed, xp_remaining, lvls_rem, xp_per_sac
end

-- Format a number with comma separators  e.g. 12500 -> "12,500", -500 -> "-500"
local function fmt_num(n)
    local neg = (tonumber(n) or 0) < 0
    local s   = tostring(math.abs(math.floor(tonumber(n) or 0)))
    s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return neg and ("-" .. s) or s
end

-- Parse a wallet response – handles every known API shape:
--   Array:  [{type="Credits", amount=N}, ...]
--   Array:  [{type="Credits", balance={amount=N}}, ...]
--   Map:    {Credits={amount=N}, Plasteel={amount=N}, ...}
--   Map:    {credits=N, plasteel=N, ...}
-- In-game type names seen: "Credits", "credits", "CreditsGood",
--   "Plasteel", "Diamantine", "AccountCredits", "MissionsCredits"
local function parse_wallet(wallets)
    local out = { credits = 0, plasteel = 0, diamantine = 0 }
    if not wallets then return out end

    local function classify(tl)
        -- Credits variants
        if tl == "credits" or tl == "creditsgood" or tl == "accountcredits"
            or tl == "missionscredits" or tl == "credit" then
            return "credits"
        elseif tl == "plasteel" then
            return "plasteel"
        elseif tl == "diamantine" then
            return "diamantine"
        end
        return nil
    end

    local function apply(type_str, raw_amount)
        local cat = classify(tostring(type_str or ""):lower())
        if not cat then return end
        local a = raw_amount
        if type(a) == "table" then a = a.amount or 0 end
        a = tonumber(a) or 0
        if     cat == "credits"    then out.credits    = a
        elseif cat == "plasteel"   then out.plasteel   = a
        elseif cat == "diamantine" then out.diamantine  = a
        end
    end

    for k, v in pairs(wallets) do
        if type(v) == "table" then
            -- Map-keyed format: key IS the wallet type  e.g. {Credits={amount=N}}
            local cat = classify(tostring(k):lower())
            if cat then
                apply(k, v.amount or (v.balance and v.balance.amount) or 0)
            else
                -- Array element format: type field lives inside v
                local t = v.type or (v.balance and v.balance.type) or v.wallet_type
                local a = v.amount or (v.balance and v.balance.amount) or 0
                if type(a) == "table" then a = a.amount or 0 end
                apply(t, a)
            end
        elseif type(v) == "number" and type(k) == "string" then
            -- Simple map: {credits=1000, plasteel=200}
            apply(k, v)
        end
    end
    return out
end

-- Weapons whose mastery-track display_name key doesn't localize via Localize()
-- but whose in-game name (as shown in Brunt's Armoury) differs from the item name.
-- Key: mastery track template display_name value (internal key, not a loc string).
-- Value: current player-facing name.
local MASTERY_TRACK_NAME_FIXES = {
    mastery_track_shotgun_p2           = "Double-Barrelled Shotgun",
    mastery_track_autogun_p3           = "Vigilant Autogun",
    mastery_track_ogryn_pickaxe_2h_p1  = "Delver's Pickaxe",
}

-- Known Darktide brand prefixes that appear as a bare first word
-- (no "Mk" suffix) in the parent-pattern localized display_name.
local BRAND_PREFIXES = {
    Brutus  = true,    -- "Brutus Arc Maul"             -> "Arc Maul"
    Echios  = true,    -- "Echios Galvanic Rifle"        -> "Galvanic Rifle"
    Kobal   = true,    -- "Kobal Arc Rifle"              -> "Arc Rifle"
    Ofoid   = true,    -- "Ofoid Phosphor Blast Pistol"  -> "Phosphor Blast Pistol"
    Theta   = true,    -- "Theta Mechanicus Power Sword" -> "Mechanicus Power Sword"
    Xiphor  = true,    -- "Xiphor Transonic Blades"      -> "Transonic Blades"
}

-- After brand stripping the result may still differ from Brunt’s Armoury’s
-- weapon-type name (e.g. "Paired" is load-bearing in the type name).
local POST_STRIP_FIXES = {
    ["Transonic Blades"] = "Paired Transonic Blades",
}

-- Strip the mark prefix from a Darktide weapon display name.
-- Handles all known formats:
--   "Rashad Mk II Combat Axe"               -> "Combat Axe"
--   "Agni Mk Ia Shock Maul"                 -> "Shock Maul"
--   "Atrox Mk II Tactical Axe"              -> "Tactical Axe"
--   "Mk III Branx Pattern Arbites Shock Maul" -> "Arbites Shock Maul"
--   "Echios Galvanic Rifle"                 -> "Galvanic Rifle"
--   "Xiphor Transonic Blades"               -> "Paired Transonic Blades"
local function strip_weapon_mark(name)
    if not name or name == "" then return name end
    -- Step 1: strip mark prefix and take everything after it.
    -- Three sub-formats:
    --   "Mk XX"  spaced      "Rashad Mk II Combat Axe"          -> "Combat Axe"
    --   "MG XX"  spaced      "Kantrael MG Ia Infantry Lasgun"   -> "Infantry Lasgun"
    --   "MkXXX"/"MKXXX" concatenated (no space before numeral)
    --                        "Branx MkVIII Dual Stub Pistols"   -> "Dual Stub Pistols"
    --                        "Branx MKVI Needle Pistol"         -> "Needle Pistol"
    local after_mk = name:match("Mk%s+%w+%s+(.*)")           -- "Mk II" spaced
                  or name:match("MG%s+%w+%s+(.*)")           -- "MG Ia" spaced (Mark Gothic)
                  or name:match(".+%s+[Mm][Kk]%w+%s+(.*)")  -- "MkVIII"/"MKVI" concatenated
    if after_mk then
        name = after_mk:match("^%s*(.-)%s*$") or after_mk
    end
    -- Step 2: strip any remaining "Brand[-Brand] Pattern" prefix.
    -- e.g. "Godwyn-Branx Pattern Bolt Pistol" -> "Bolt Pistol"
    -- e.g. "Branx Pattern Infantry Autogun"   -> "Infantry Autogun"
    local after_pat = name:match("^.+%s+Pattern%s+(.*)")
    if after_pat then
        return POST_STRIP_FIXES[after_pat] or after_pat:match("^%s*(.-)%s*$") or after_pat
    end
    -- Step 3: strip "Standard-issue <Supplier>" prefix for common-issue weapons.
    -- e.g. "Standard-issue Munitorum Sapper Shovel" -> "Sapper Shovel"
    local after_std = name:match("^Standard%-issue%s+%S+%s+(.*)")
    if after_std then
        return POST_STRIP_FIXES[after_std] or after_std:match("^%s*(.-)%s*$") or after_std
    end
    -- Step 4: strip known single-word brand prefixes.
    -- e.g. "Echios Galvanic Rifle" -> "Galvanic Rifle"
    local first, rest = name:match("^(%a+)%s+(.+)")
    if first and BRAND_PREFIXES[first] and rest then
        name = rest
    end
    -- Step 5: post-strip fixes for names that still don’t match Brunt’s Armoury.
    -- e.g. "Transonic Blades" -> "Paired Transonic Blades"
    return POST_STRIP_FIXES[name] or name
end

-- Slider constants â€" must match definitions.lua
local SLIDER_SX = 20
local SLIDER_SY = 506   -- AMT_Y + AMT_BH + 16  =  454+36+16 (SPLIT_Y=132)
local SLIDER_SW = 420   -- narrower than LW2 so slider clears the column divider

-- Scroll-bar geometry â€" must match definitions.lua SB_* constants
local CONTENT_H_V  = 670   -- H - TITLE_H - FOOTER_H - 16
local SB_X_V       = 1022  -- W -38
local SB_W_V       = 18
local SB_BTN_H_V   = 26
local SB_TRACK_Y_V = SB_BTN_H_V + 2              -- 28
local SB_TRACK_H_V = CONTENT_H_V - SB_BTN_H_V * 2 - 4  -- 614

-- Mastery colours
local C_MAST_NORMAL = { 255, 255, 255, 255 }     -- white  (mastery < 20)
local C_MAST_MAX    = { 255, 210,  80,  80 }     -- medium red (mastery >= 20)

-- Dropdown colours (must mirror definitions.lua DD_BG / DD_TEXT exactly)
local DD_BG_COLOURS = {
    [0] = {  70, 100, 100, 100 },   -- gray  (Profane)
    [1] = {  70,  45, 155,  45 },   -- green
    [2] = {  70,  45, 130, 210 },   -- light blue
    [3] = {  70, 135,  65, 195 },   -- violet
    [4] = {  70, 195, 155,  20 },   -- gold
}
local DD_TEXT_COLOURS = {
    [0] = { 255, 160, 160, 160 },   -- gray  (Profane)
    [1] = { 255,  90, 230,  90 },   -- green
    [2] = { 255,  90, 200, 255 },   -- light blue
    [3] = { 255, 210, 140, 255 },   -- violet
    [4] = { 255, 255, 215,  70 },   -- gold
}

-- â"€â"€ Widget name groups â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
local ALL_ROWS = {}
for i = 0, NUM_ROWS - 1 do ALL_ROWS[i+1] = string.format("row_%02d", i) end

local SCROLL_NAMES = { "scroll_up", "scroll_dn", "scroll_track", "scroll_fill", "scroll_zone" }

local CFG_BASE = {
    -- Resource bar (top strip, in content_area)
    "cfg_res_bg", "cfg_res_sep", "cfg_res_div1", "cfg_res_div2",
    "cfg_res_lbl_cr", "cfg_res_have_cr", "cfg_res_cst_cr",
    "cfg_res_lbl_pl", "cfg_res_have_pl", "cfg_res_cst_pl",
    "cfg_res_lbl_di", "cfg_res_have_di", "cfg_res_cst_di",
    -- Header
    "cfg_weapon_name", "cfg_weapon_mast", "cfg_weapon_sub", "cfg_weapon_sub_rar",
    "cfg_header_line", "cfg_icon", "cfg_col_div",
    -- Mode toggle buttons
    "cfg_mode_store_btn", "cfg_mode_inv_btn",
    -- Left column: mode checkboxes + auto info + amount controls + slider
    "cfg_auto_chk_box",   "cfg_auto_chk_lbl",   "cfg_auto_chk_hint",
    "cfg_manual_chk_box", "cfg_manual_chk_lbl", "cfg_manual_chk_hint",
    "cfg_auto_info1", "cfg_auto_info2", "cfg_auto_info3",
    "cfg_amt_lbl", "cfg_amt_m5", "cfg_amt_m1", "cfg_amt_disp", "cfg_amt_p1", "cfg_amt_p5", "cfg_amt_max", "cfg_amt_hint",
    "cfg_slider_track", "cfg_slider_fill", "cfg_slider_handle",
    -- Store-mode inventory calculation toggle
    "cfg_inv_calc_chk_box", "cfg_inv_calc_chk_lbl", "cfg_inv_calc_chk_hint",
    -- Inventory-mode rarity filter dropdown / store-mode inventory notice
    "cfg_inv_filt_lbl", "cfg_inv_filt_dd", "cfg_store_inv_notice",
    -- Right column: dropdown + order summary
    "cfg_upg_hint", "cfg_upg_lbl", "cfg_upg_dd",
    "cfg_ord_hdr", "cfg_ord_sep", "cfg_ord_wpn",
    "cfg_ord_cst_hdr", "cfg_ord_cr", "cfg_ord_pl", "cfg_ord_di", "cfg_ord_note",
    -- Confirm
    "cfg_chk_box", "cfg_chk_lbl",
}

local CFG_DD = { "cfg_dd_bg" }
for i = 0, NUM_OPTS - 1 do CFG_DD[#CFG_DD+1] = "cfg_upg_opt_" .. i end
local CFG_FILT_DD = { "cfg_inv_filt_dd_bg" }
for i = 0, 4 do CFG_FILT_DD[#CFG_FILT_DD+1] = "cfg_inv_filt_opt_" .. i end

local PROC_NAMES = { "proc_hdr", "proc_status", "proc_errors" }

-- All btn()-based buttons that get a hover/press overlay effect
local HOVER_BTNS = {
    "exit_btn",
    "footer_next", "footer_back", "footer_proceed", "footer_close",
    "cfg_mode_store_btn", "cfg_mode_inv_btn",
    "cfg_inv_filt_dd",
    "cfg_amt_m5", "cfg_amt_m1", "cfg_amt_p1", "cfg_amt_p5", "cfg_amt_max",
    "proc_craft_btn",
}
local ALL_FOOTER = { "footer_next", "footer_back", "footer_proceed", "footer_close",
                     "footer_hint", "footer_proceed_hint",
                     "footer_res_lbl", "footer_res_cr", "footer_res_pl", "footer_res_di" }

-- Everything that gets hidden on screen transitions
-- Note: frame widgets (frame_top/bottom/left/right) are NOT here â€" always visible.
local ALL_CONDITIONAL = {}
for _, t in ipairs({
    { "tab_0", "tab_1" }, ALL_ROWS, CFG_BASE, CFG_DD, CFG_FILT_DD,
    PROC_NAMES, ALL_FOOTER, SCROLL_NAMES, { "status_text" },
    { "proc_craft_hint", "proc_craft_hint2", "proc_craft_btn" }
}) do
    for _, n in ipairs(t) do ALL_CONDITIONAL[#ALL_CONDITIONAL+1] = n end
end

-- â"€â"€ View class â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
local WeaponXPFarmView = class("WeaponXPFarmView", "BaseView")

-- â"€â"€ Widget helpers â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
function WeaponXPFarmView:_w(name)
    return self._widgets_by_name and self._widgets_by_name[name]
end

function WeaponXPFarmView:_vis(name, show)
    local w = self:_w(name)
    if not w then return end
    w.visible = show
    if w.content and w.content.hotspot then
        w.content.hotspot.disabled = not show
    end
end

function WeaponXPFarmView:_set_text(name, text)
    local w = self:_w(name)
    if w and w.content then w.content.text = tostring(text or "") end
end

function WeaponXPFarmView:_set_color(name, style_id, color)
    local w = self:_w(name)
    if w and w.style and w.style[style_id] then
        w.style[style_id].color = color
    end
end

function WeaponXPFarmView:_tick_hover()
    for _, name in ipairs(HOVER_BTNS) do
        local w = self:_w(name)
        if w and w.content and w.content.hotspot
                and w.style and w.style.hover_overlay then
            local hs = w.content.hotspot
            -- 0 = idle, 30 = hover, 65 = pressed
            w.style.hover_overlay.color[1] =
                hs.is_pressed and 65 or (hs.is_hover and 30 or 0)
        end
    end
end

function WeaponXPFarmView:_btn_pressed(name)
    local w = self:_w(name)
    return w and w.content and w.content.hotspot and w.content.hotspot.on_pressed
end

function WeaponXPFarmView:_hide_all_conditional()
    for _, n in ipairs(ALL_CONDITIONAL) do self:_vis(n, false) end
end

-- â"€â"€ Init â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
function WeaponXPFarmView:init(settings, context)
    mod:info("[WXF] init()")
    self._widgets         = {}
    self._widgets_by_name = {}

    local defs = mod:io_dofile(
        "Weapon_XP_Farm/scripts/mods/Weapon_XP_Farm/views/weapon_xp_farm_definitions"
    )
    WeaponXPFarmView.super.init(self, defs, settings)

    -- State
    self._screen        = "loading"
    self._tabs          = {}
    self._active_tab    = 1
    self._scroll        = 0
    self._selected      = nil
    self._amount        = 1
    self._upgrade_level = 1   -- default to Step 1 (Redeemed) so list shows real costs immediately
    self._confirmed     = false
    self._dd_open       = false
    self._proc_total      = 0
    self._proc_done       = 0
    self._proc_errors     = {}
    self._proc_gear_ids   = {}
    -- Scrollbar drag state
    self._sb_drag         = false
    self._sb_drag_mouse_y = 0
    self._sb_drag_start   = 0
    -- Wallet / resource state
    self._wallet        = { credits = 0, plasteel = 0, diamantine = 0 }
    self._wallet_loaded = false
    self._can_afford    = true
    -- Auto Max Mastery mode
    self._auto_mode   = true   -- default: auto mode
    self._auto_amount = 0      -- weapons needed (calculated)
    self._mastery_xp  = {}     -- pattern -> XP within current level
    -- Inventory mode state
    self._inv_mode        = false  -- false = buy from store, true = use inventory
    self._inv_weapons     = {}     -- [{gear_id, rarity, needs_consecration, gear}]
    self._inv_found         = 0
    self._inv_skipped       = 0
    self._inv_skipped_fav   = 0   -- subset of skipped: favorited weapons
    self._inv_rarity_ok     = 0   -- already at/above target rarity
    self._inv_scanning    = false
    -- Store mode "count inventory toward goal" toggle
    self._inv_calc        = false
    self._store_inv_count = 0     -- inventory weapons already sacrifice-ready (for calc)
    -- Inventory mode rarity filter: 1=Profane+(all), 2=Redeemed+, … 5=Transcendent only
    self._inv_filter_min  = 1
    self._inv_filt_dd_open   = false
    -- Store mode inventory notice / calc
    self._store_inv_total    = 0
    self._store_rarity_ok    = 0   -- sacrifice-ready count (at/above target rarity)
    self._store_inv_scanning = false
end

-- â"€â"€ Lifecycle â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
function WeaponXPFarmView:on_enter()
    local wbn = self._widgets_by_name
    local cnt = wbn and (function() local n=0; for _ in pairs(wbn) do n=n+1 end; return n end)() or 0
    mod.flog_section("VIEW OPENED")
    mod.flog("SESSION", "Weapon XP Farm view opened")
    mod:info("[WXF] on_enter() widget_count=%d", cnt)

    -- Report where consecration costs come from this session: the game's live
    -- backend cost table (exact, per item level) or the hardcoded estimates.
    do
        local probe, live = get_consecrate_costs(2, nil)
        mod:info("[WXF] consecration cost source: %s (step 1 at default item level: %d Pl / %d Di)",
            live and "LIVE backend table" or "FALLBACK estimates (backend cache not ready)",
            probe and probe.plasteel or 0, probe and probe.diamantine or 0)
    end

    WeaponXPFarmView.super.on_enter(self)

    -- Show mouse cursor while the view is open
    pcall(function()
        Managers.input:enable_mouse_cursor("weapon_xp_farm_view", true)
    end)

    self:_hide_all_conditional()
    self:_vis("status_text", true)
    self:_set_text("status_text", mod:localize("loading_store"))

    -- Auto-scan inventory on open so cache is ready before the user reaches configure screen
    self:_try_scan_from_backend()

    self:_load_data()
end

function WeaponXPFarmView:on_exit()
    mod.flog("SESSION", "Weapon XP Farm view closed (last screen: %s)", tostring(self._screen))
    -- Release mouse cursor so it doesn't stay visible after closing
    pcall(function()
        Managers.input:enable_mouse_cursor("weapon_xp_farm_view", false)
    end)
    WeaponXPFarmView.super.on_exit(self)
end

function WeaponXPFarmView:on_back_pressed()
    local scr = self._screen
    if scr == "configure" then
        -- First Escape press closes any open dropdown
        if self._inv_filt_dd_open then
            self._inv_filt_dd_open = false
            self:_vis("cfg_inv_filt_dd_bg", false)
            for _fi = 0, 4 do self:_vis("cfg_inv_filt_opt_" .. _fi, false) end
            return true
        end
        if self._dd_open then
            self:_close_dd()
            return true
        end
        -- Second Escape press (or first when dropdown is closed) goes back to weapon select
        mod.flog("USER", "Escape pressed — back to weapon selection screen")
        self._screen    = "weapon_select"
        self._confirmed = false
        self._dd_open   = false
        self:_show_weapon_select()
        return true
    end
    -- Escape on any other screen (weapon_select, loading, done, processing) closes the view
    mod.flog("USER", "Escape pressed — closing view (screen: %s)", tostring(scr))
    Managers.ui:close_view("weapon_xp_farm_view")
    return true
end

-- â"€â"€ Screen transitions â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
function WeaponXPFarmView:_show_weapon_select()
    self:_hide_all_conditional()
    for i = 1, math.min(#self._tabs, 2) do
        self:_vis("tab_" .. (i-1), true)
    end
    self:_vis("footer_next",    true)
    self:_vis("footer_res_lbl", true)
    self:_vis("footer_res_cr",  true)
    self:_vis("footer_res_pl",  true)
    self:_vis("footer_res_di",  true)
    -- Scroll bar buttons + track
    for _, n in ipairs(SCROLL_NAMES) do self:_vis(n, true) end
    self:_refresh_tabs()
    self:_refresh_rows()
    self:_refresh_next_btn()  -- also manages footer_hint visibility
    self:_refresh_wallet_footer()
end

function WeaponXPFarmView:_show_configure()
    self:_hide_all_conditional()
    for _, n in ipairs(CFG_BASE) do self:_vis(n, true) end
    self:_vis("footer_back",    true)
    self:_vis("footer_proceed", true)
    -- Set proceed button label based on current mode
    local pw = self:_w("footer_proceed")
    if pw and pw.content then
        pw.content.text = self._inv_mode and mod:localize("btn_proceed_inv") or mod:localize("btn_proceed")
    end
    self._dd_open            = false
    self._inv_filt_dd_open   = false
    self._store_inv_scanning = false
    self._store_inv_total    = 0
    self._store_rarity_ok    = 0
    self:_setup_dd_options()
    self:_load_wallet()
    if self._inv_mode then
        self:_trigger_inv_scan()
    else
        self:_trigger_store_inv_scan()
    end
    self:_refresh_configure()
end

function WeaponXPFarmView:_show_processing()
    self:_hide_all_conditional()
    for _, n in ipairs(PROC_NAMES) do self:_vis(n, true) end
    self:_set_text("proc_hdr",    mod:localize("processing_header"))
    self:_set_text("proc_status", "")
    self:_set_text("proc_errors", "")
end

function WeaponXPFarmView:_show_done()
    self:_vis("footer_close", true)
end

-- â"€â"€ Dropdown helpers â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
function WeaponXPFarmView:_setup_dd_options()
    local e        = self._selected
    local base_rar = e and (e.base_rarity or 1) or 1
    local max_step = math.min(NUM_OPTS - 1, 5 - base_rar)

    for i = 0, NUM_OPTS - 1 do
        local w = self:_w("cfg_upg_opt_" .. i)
        if w and w.content then
            if i == 0 then
                w.content.text = "  " .. RARITY_LOC[1]
            else
                local tgt = math.min(5, base_rar + i)
                w.content.text = "  " .. mod:localize("upgrade_step_fmt", i, RARITY_LOC[tgt] or "?")
            end
            -- Color: restore tier colour for enabled options, dim for disabled ones
            if w.style and w.style.text then
                if i <= max_step then
                    w.style.text.text_color = DD_TEXT_COLOURS[i] or { 255, 255, 255, 255 }
                else
                    w.style.text.text_color = Color.gray(100, true)
                end
            end
        end
    end
end

function WeaponXPFarmView:_open_dd()
    local e        = self._selected
    local base_rar = e and (e.base_rarity or 1) or 1
    local max_step = math.min(NUM_OPTS - 1, 5 - base_rar)
    self._dd_open  = true
    self:_vis("cfg_dd_bg", true)
    for i = 0, NUM_OPTS - 1 do
        self:_vis("cfg_upg_opt_" .. i, i <= max_step)
    end
end

function WeaponXPFarmView:_close_dd()
    self._dd_open = false
    self:_vis("cfg_dd_bg", false)
    for i = 0, NUM_OPTS - 1 do
        self:_vis("cfg_upg_opt_" .. i, false)
        -- Clear stale on_pressed so re-opening doesn't instantly fire an option
        local w = self:_w("cfg_upg_opt_" .. i)
        if w and w.content and w.content.hotspot then
            w.content.hotspot.on_pressed = false
        end
    end
    -- Also clear the button's own on_pressed to prevent toggle flicker
    local dd = self:_w("cfg_upg_dd")
    if dd and dd.content and dd.content.hotspot then
        dd.content.hotspot.on_pressed = false
    end
end

-- â"€â"€ Refresh helpers â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
function WeaponXPFarmView:_refresh_tabs()
    local C_ACCENT  = Color.terminal_text_header(255, true)
    local C_BODY    = Color.terminal_text_body(255, true)
    local C_FRAME   = Color.terminal_frame(255, true)
    local C_TRANS   = Color.black(0, true)
    -- Inactive tab uses a slightly-brighter-than-panel colour so the gap above it is visible.
    -- Must match C_TAB_INACTIVE in definitions.lua.
    local C_TAB_INACTIVE = { 255, 38, 52, 38 }
    -- Active tab: solid amber, clearly distinct from both inactive and the panel background
    local C_SEL_TAB      = { 220, 200, 140, 0 }

    for i, tab in ipairs(self._tabs) do
        if i > 2 then break end
        local w = self:_w("tab_" .. (i-1))
        if w then
            if w.content then w.content.text = tab.name end
            local active = (i == self._active_tab)
            if w.style then
                -- Swap background colour: amber when active, distinct dark when not
                if w.style.bg then
                    w.style.bg.color = active and C_SEL_TAB or C_TAB_INACTIVE
                end
                -- Underline bar on active tab
                if w.style.line then
                    w.style.line.color = active and C_FRAME or C_TRANS
                end
                -- Text colour: bright header colour when active
                if w.style.text then
                    w.style.text.text_color = active and C_ACCENT or C_BODY
                end
            end
        end
    end
end

function WeaponXPFarmView:_refresh_rows()
    -- Row selection colours
    local C_SEL_BAR  = { 255, 255, 165,   0 }   -- vivid amber bar (8 px left edge)
    local C_SEL_BG   = {  60, 255, 160,  40 }   -- amber tint over full row
    local C_NORM_BAR = { 0, 0, 0, 0 }
    local C_NORM_BG  = Color.terminal_grid_background(255, true)

    local tab     = self._tabs[self._active_tab]
    local weapons = tab and tab.weapons or {}
    local total   = #weapons
    local max_sc  = math.max(0, total - NUM_ROWS)

    for i = 0, NUM_ROWS - 1 do
        local rname = string.format("row_%02d", i)
        local entry = weapons[i + self._scroll + 1]
        self:_vis(rname, entry ~= nil)
        if entry then
            local w = self:_w(rname)
            if w and w.content then
                w.content.name = entry.display_name or ""
                w.content.mast = mod:localize("mastery_fmt", tostring(entry.mastery_level or 0))
                w.content.icon = (entry.item and entry.item.hud_icon) or ""

                -- Cost strip: dynamic — mirrors configure screen logic per weapon
                local rarity_tier = math.min(5, (entry.base_rarity or 1) + self._upgrade_level)
                local pat         = entry.item and entry.item.parent_pattern or ""
                local cur_xp      = (self._mastery_xp and self._mastery_xp[pat]) or 0
                local wep_auto    = calc_auto_amount(entry, rarity_tier, cur_xp)
                -- Page-1 rows always preview the per-weapon "needed for max" count.
                -- A manual amount chosen on the configure screen applies only to the
                -- weapon selected there — not to every row of this list.
                local eff_count   = wep_auto

                local row_cr = eff_count * (entry.price or 0)
                local row_pl = 0
                for step = 1, self._upgrade_level do
                    local cc = get_consecrate_costs((entry.base_rarity or 1) + step, entry.item)
                    if cc then row_pl = row_pl + cc.plasteel end
                end
                row_pl = row_pl * eff_count

                w.content.rar = "● " .. (RARITY_LOC[rarity_tier] or "?")
                w.content.cr  = "Cr: " .. fmt_num(row_cr)
                w.content.pl  = "Pl: " .. fmt_num(row_pl)
                w.content.cnt = (entry.mastery_level or 0) >= MAX_MASTERY_LEVEL
                    and "" or ("x " .. tostring(eff_count))
            end
            if w and w.style then
                local is_sel = (self._selected == entry)
                if w.style.sel then
                    w.style.sel.color = is_sel and C_SEL_BAR or C_NORM_BAR
                end
                if w.style.bg then
                    w.style.bg.color = is_sel and C_SEL_BG or C_NORM_BG
                end
                if w.style.mast then
                    local mlvl = entry.mastery_level or 0
                    w.style.mast.text_color = (mlvl >= 20) and C_MAST_MAX or C_MAST_NORMAL
                end
            end
        end
    end

    -- Update scrollbar fill indicator position/size
    local sf = self:_w("scroll_fill")
    if sf and sf.style and sf.style.rect then
        if total > NUM_ROWS and max_sc > 0 then
            local fill_h = math.max(16, math.floor(SB_TRACK_H_V * NUM_ROWS / total))
            local fill_t = self._scroll / max_sc
            local fill_y = SB_TRACK_Y_V + 2 +
                math.floor((SB_TRACK_H_V - fill_h - 4) * fill_t)
            sf.style.rect.size   = { SB_W_V - 4, fill_h }
            sf.style.rect.offset = { SB_X_V + 2, fill_y, 2 }
        else
            -- Full bar when all weapons fit on screen
            sf.style.rect.size   = { SB_W_V - 4, SB_TRACK_H_V - 4 }
            sf.style.rect.offset = { SB_X_V + 2, SB_TRACK_Y_V + 2, 2 }
        end
    end
end

function WeaponXPFarmView:_refresh_next_btn()
    local C_OK  = Color.green(200, true)
    local C_DIS = Color.gray(120, true)
    local w = self:_w("footer_next")
    if w and w.style and w.style.bg then
        w.style.bg.color = self._selected and C_OK or C_DIS
    end
    -- Show hint only when nothing is selected yet
    self:_vis("footer_hint", not self._selected)
end

function WeaponXPFarmView:_refresh_configure()
    local e = self._selected
    if not e then return end

    -- ── Mode toggle button visuals ──────────────────────────────────────────
    local C_TOG_ON  = Color.green(160, true)
    local C_TOG_OFF = Color.gray(80,  true)
    local sb = self:_w("cfg_mode_store_btn")
    if sb and sb.style and sb.style.bg then
        sb.style.bg.color = self._inv_mode and C_TOG_OFF or C_TOG_ON
    end
    local ib = self:_w("cfg_mode_inv_btn")
    if ib and ib.style and ib.style.bg then
        ib.style.bg.color = self._inv_mode and C_TOG_ON or C_TOG_OFF
    end

    -- ── Weapon header ───────────────────────────────────────────────────────
    self:_set_text("cfg_weapon_name", e.display_name or "")
    local mlvl = e.mastery_level or 0
    self:_set_text("cfg_weapon_mast", mod:localize("mastery_fmt", tostring(mlvl)))
    local mast_w = self:_w("cfg_weapon_mast")
    if mast_w and mast_w.style and mast_w.style.text then
        mast_w.style.text.text_color = (mlvl >= 20) and C_MAST_MAX or { 255, 255, 255, 255 }
    end
    self:_set_text("cfg_weapon_sub", mod:localize("base_rarity_prefix"))
    local ci = self:_w("cfg_icon")
    if ci and ci.content then
        ci.content.icon = (e.item and e.item.hud_icon) or ""
    end

    -- ── Mode checkboxes (auto / manual) — same in both modes ────────────────
    local C_MODE_ON  = Color.green(200, true)
    local C_MODE_OFF = Color.black(0, true)
    local auto_chk = self:_w("cfg_auto_chk_box")
    local man_chk  = self:_w("cfg_manual_chk_box")
    if auto_chk and auto_chk.style and auto_chk.style.check then
        auto_chk.style.check.color = self._auto_mode and C_MODE_ON or C_MODE_OFF
    end
    if man_chk and man_chk.style and man_chk.style.check then
        man_chk.style.check.color = self._auto_mode and C_MODE_OFF or C_MODE_ON
    end

    -- ── Mode checkbox labels/hints — differ between store and inventory mode ──
    if self._inv_mode then
        self:_set_text("cfg_auto_chk_lbl",  mod:localize("auto_sacrifice"))
        self:_set_text("cfg_auto_chk_hint", mod:localize("auto_sacrifice_hint"))
        self:_set_text("cfg_manual_chk_lbl",  mod:localize("manual_count"))
        self:_set_text("cfg_manual_chk_hint", mod:localize("manual_count_hint"))
    else
        self:_set_text("cfg_auto_chk_lbl",  mod:localize("auto_max_mastery"))
        self:_set_text("cfg_auto_chk_hint", mod:localize("auto_max_mastery_hint"))
        self:_set_text("cfg_manual_chk_lbl",  mod:localize("manual_amount"))
        self:_set_text("cfg_manual_chk_hint", mod:localize("manual_amount_hint"))
    end

    -- ── Shared XP / rarity calculations ────────────────────────────────────
    local rarity_tier = math.min(5, (e.base_rarity or 1) + self._upgrade_level)
    local current_xp_total = self._mastery_xp and
                             self._mastery_xp[e.item and e.item.parent_pattern or ""] or 0
    local weapons_auto, xp_rem, lvls_rem, xp_per_sac = calc_auto_amount(e, rarity_tier, current_xp_total)

    -- ── Mode-specific: amount, costs, info text ─────────────────────────────
    local eff_amount    = 0
    local credits_cost  = 0
    local pl_cost       = 0
    local di_cost       = 0
    local costs_live    = true   -- false if any consecration cost fell back to estimates

    if not self._inv_mode then
        -- ── STORE MODE ──────────────────────────────────────────────────────

        -- Adjust auto amount if "count inventory toward goal" is on
        local adj_auto = weapons_auto
        if self._inv_calc and self._store_inv_count > 0 then
            adj_auto = math.max(0, weapons_auto - self._store_inv_count)
        end
        self._auto_amount = adj_auto
        eff_amount = self._auto_mode and self._auto_amount or self._amount

        -- Auto info text
        if self._auto_mode then
            local info1
            if self._inv_calc and self._store_inv_scanning then
                info1 = mod:localize("need_scanning_fmt",
                    fmt_num(weapons_auto), MAX_MASTERY_LEVEL)
            elseif self._inv_calc and self._store_inv_count > 0 then
                info1 = mod:localize("need_buy_fmt",
                    fmt_num(weapons_auto), MAX_MASTERY_LEVEL, fmt_num(adj_auto), self._store_inv_count)
            else
                info1 = mod:localize("need_fmt",
                    fmt_num(weapons_auto), MAX_MASTERY_LEVEL)
            end
            self:_set_text("cfg_auto_info1", info1)
            self:_set_text("cfg_auto_info2", "")
            self:_set_text("cfg_auto_info3", "")
        else
            self:_set_text("cfg_auto_info1", "")
            self:_set_text("cfg_auto_info2", "")
            self:_set_text("cfg_auto_info3", "")
        end

        -- Cost: credits + plasteel + diamantine
        credits_cost = eff_amount * (e.price or 0)
        for step = 1, self._upgrade_level do
            local tier = (e.base_rarity or 1) + step
            local cc, cc_live = get_consecrate_costs(tier, e.item)
            if cc then pl_cost = pl_cost + cc.plasteel; di_cost = di_cost + cc.diamantine end
            if not cc_live then costs_live = false end
        end
        pl_cost = pl_cost * eff_amount
        di_cost = di_cost * eff_amount

        -- Show credits column + inv_calc checkbox
        self:_vis("cfg_res_lbl_cr",  true)
        self:_vis("cfg_res_have_cr", true)
        self:_vis("cfg_res_cst_cr",  true)
        self:_vis("cfg_res_div1",    true)
        self:_vis("cfg_ord_cr",      true)
        self:_vis("cfg_inv_calc_chk_box",  true)
        self:_vis("cfg_inv_calc_chk_lbl",  true)
        self:_vis("cfg_inv_calc_chk_hint", true)
        local ic_chk = self:_w("cfg_inv_calc_chk_box")
        if ic_chk and ic_chk.style and ic_chk.style.check then
            ic_chk.style.check.color = self._inv_calc and C_MODE_ON or C_MODE_OFF
        end

    else
        -- ── INVENTORY MODE ──────────────────────────────────────────────────

        local inv_count = #self._inv_weapons
        local adj_auto  = math.min(weapons_auto, inv_count)
        self._auto_amount = adj_auto
        eff_amount = self._auto_mode
            and self._auto_amount
            or  math.min(self._amount, math.max(1, inv_count))

        -- Inventory stats in auto info area
        if self._inv_scanning then
            self:_set_text("cfg_auto_info1", mod:localize("scanning_inventory"))
            self:_set_text("cfg_auto_info2", "")
            self:_set_text("cfg_auto_info3", "")
        else
            self:_set_text("cfg_auto_info1",
                mod:localize("need_fmt",
                    fmt_num(weapons_auto), MAX_MASTERY_LEVEL))
            if self._inv_skipped > 0 then
                local skip_fav    = self._inv_skipped_fav or 0
                local skip_rarity = self._inv_skipped - skip_fav
                local parts = {}
                if skip_fav > 0 then
                    parts[#parts+1] = mod:localize("skipped_fav_fmt", skip_fav)
                end
                if skip_rarity > 0 then
                    local _RARITY_MIN_NAMES = RARITY_LOC
                    local rname = _RARITY_MIN_NAMES[self._inv_filter_min] or "selected"
                    parts[#parts+1] = mod:localize("skipped_below_fmt", skip_rarity, rname)
                end
                self:_set_text("cfg_auto_info2",
                    mod:localize("skipped_fmt", self._inv_skipped, table.concat(parts, ", ")))
            else
                self:_set_text("cfg_auto_info2", "")
            end
            self:_set_text("cfg_auto_info3", "")
        end

        -- Cost: plasteel + diamantine only (no credits — no purchase)
        local target = math.min(5, (e.base_rarity or 1) + self._upgrade_level)
        for i = 1, eff_amount do
            local weapon = self._inv_weapons[i]
            if weapon and weapon.needs_consecration then
                local steps_to_do = target - weapon.rarity
                for step = 1, steps_to_do do
                    local cc, cc_live = get_consecrate_costs(weapon.rarity + step, weapon.gear)
                    if cc then
                        pl_cost = pl_cost + cc.plasteel
                        di_cost = di_cost + cc.diamantine
                    end
                    if not cc_live then costs_live = false end
                end
            end
        end

        -- Hide credits column + inv_calc checkbox; show rarity filter
        self:_vis("cfg_res_lbl_cr",  false)
        self:_vis("cfg_res_have_cr", false)
        self:_vis("cfg_res_cst_cr",  false)
        self:_vis("cfg_res_div1",    false)
        self:_vis("cfg_ord_cr",      false)
        self:_vis("cfg_inv_calc_chk_box",  false)
        self:_vis("cfg_inv_calc_chk_lbl",  false)
        self:_vis("cfg_inv_calc_chk_hint", false)
    end  -- closes: if not self._inv_mode then ... else (inventory mode branch)

    -- ── Rarity filter dropdown (inv mode) / inventory notice (store mode) ──
    self:_vis("cfg_inv_filt_lbl",     self._inv_mode)
    self:_vis("cfg_inv_filt_dd",      self._inv_mode)
    self:_vis("cfg_store_inv_notice", not self._inv_mode)
    if self._inv_mode then
        local _FILT_NAMES = FILTER_LOC
        local dd_w = self:_w("cfg_inv_filt_dd")
        if dd_w then
            local fi0 = self._inv_filter_min - 1
            dd_w.content.text = "\xe2\x96\xbc  " .. (_FILT_NAMES[self._inv_filter_min] or mod:localize("filter_any"))
            if dd_w.style then
                if dd_w.style.bg   then dd_w.style.bg.color       = DD_BG_COLOURS[fi0]  end
                if dd_w.style.text then dd_w.style.text.text_color = DD_TEXT_COLOURS[fi0] end
            end
        end
    else
        local notice_w = self:_w("cfg_store_inv_notice")
        if notice_w then
            if self._store_inv_scanning then
                notice_w.content.text = mod:localize("checking_inventory")
            elseif self._store_inv_total > 0 then
                notice_w.content.text = mod:localize("store_inv_notice_fmt", self._store_inv_total)
            else
                notice_w.content.text = ""
            end
        end
    end

    -- ── Amount display + slider ─────────────────────────────────────────────
    local C_AMT_DIM = { 255, 100, 100, 100 }
    local max_manual = self._inv_mode and math.max(1, #self._inv_weapons) or 38
    -- Clamp amount when max changes (e.g. switching between store/inventory mode)
    if not self._auto_mode and self._amount > max_manual then
        self._amount = max_manual
    end
    -- Update "+MAX" button label and amount hint dynamically
    local max_btn = self:_w("cfg_amt_max")
    if max_btn and max_btn.content then
        max_btn.content.text = "+" .. tostring(max_manual)
    end
    self:_set_text("cfg_amt_hint", "")
    -- Update right-column hint: show filter rarity in inv mode, hide in store mode
    self:_vis("cfg_upg_hint", self._inv_mode)
    if self._inv_mode then
        local _RARITY_FILT = { mod:localize("upg_hint_any"),
            RARITY_LOC[2], RARITY_LOC[3], RARITY_LOC[4], RARITY_LOC[5] }
        self:_set_text("cfg_upg_hint",
            mod:localize("upg_hint_fmt", _RARITY_FILT[self._inv_filter_min] or mod:localize("upg_hint_any")))
    end
    self:_set_text("cfg_amt_disp", self._auto_mode and mod:localize("auto_display") or tostring(self._amount))
    local amt_disp = self:_w("cfg_amt_disp")
    if amt_disp and amt_disp.style and amt_disp.style.text then
        amt_disp.style.text.text_color = self._auto_mode and C_AMT_DIM or C_MAST_NORMAL
    end

    local t  = self._auto_mode and 1.0 or math.min(1.0, (self._amount - 1) / math.max(1, max_manual - 1))
    local fw = math.max(2, math.floor(t * SLIDER_SW))
    local sf = self:_w("cfg_slider_fill")
    if sf and sf.style and sf.style.rect then
        sf.style.rect.size = { fw, 10 }
    end
    local sh = self:_w("cfg_slider_handle")
    if sh and sh.style and sh.style.rect then
        sh.style.rect.offset = { SLIDER_SX + fw - 7, SLIDER_SY - 7, 3 }
    end

    -- ── Dropdown button ─────────────────────────────────────────────────────
    local lvl    = self._upgrade_level
    local bg_col = DD_BG_COLOURS[lvl]   or { 70, 80, 80, 80 }
    local tx_col = DD_TEXT_COLOURS[lvl] or { 255, 255, 255, 255 }
    local dd_w = self:_w("cfg_upg_dd")
    if dd_w then
        if dd_w.style then
            if dd_w.style.bg   then dd_w.style.bg.color        = bg_col end
            if dd_w.style.text then dd_w.style.text.text_color = tx_col end
        end
        if dd_w.content then
            if lvl == 0 then
                dd_w.content.text = "\xe2\x96\xbc  " .. RARITY_LOC[1]
            else
                local tgt = math.min(5, (e.base_rarity or 1) + lvl)
                dd_w.content.text = "\xe2\x96\xbc  " .. mod:localize("upgrade_step_fmt", lvl, RARITY_LOC[tgt] or "?")
            end
        end
    end

    -- ── Resource bar ────────────────────────────────────────────────────────
    local wd = self._wallet
    local rem_cr = wd.credits    - credits_cost
    local rem_pl = wd.plasteel   - pl_cost
    local rem_di = wd.diamantine - di_cost
    local C_REM_OK  = { 255, 220, 70, 70 }
    local C_REM_ERR = { 255, 255, 80, 80 }
    local function rem_col(rem)
        return (not self._wallet_loaded or rem >= 0) and C_REM_OK or C_REM_ERR
    end
    local function upd_res(have_name, cst_name, have_val, cost_val, rem_val)
        self:_set_text(have_name, self._wallet_loaded and fmt_num(have_val) or "...")
        self:_set_text(cst_name, cost_val > 0 and ("\xe2\x86\x92 -" .. fmt_num(cost_val)) or "")
        local cw = self:_w(cst_name)
        if cw and cw.style and cw.style.text then
            cw.style.text.text_color = rem_col(rem_val)
        end
    end
    if not self._inv_mode then
        upd_res("cfg_res_have_cr", "cfg_res_cst_cr", wd.credits, credits_cost, rem_cr)
    end
    upd_res("cfg_res_have_pl", "cfg_res_cst_pl", wd.plasteel,   pl_cost, rem_pl)
    upd_res("cfg_res_have_di", "cfg_res_cst_di", wd.diamantine, di_cost, rem_di)

    -- ── Order summary ───────────────────────────────────────────────────────
    local qty_str = self._auto_mode
        and (fmt_num(eff_amount) .. "  " .. mod:localize("auto_tag"))
        or fmt_num(eff_amount)
    self:_set_text("cfg_ord_wpn", mod:localize("ord_weapons_fmt", qty_str))
    if not self._inv_mode then
        self:_set_text("cfg_ord_cr", mod:localize("ord_credits_fmt", fmt_num(credits_cost)))
    end
    self:_set_text("cfg_ord_pl", mod:localize("ord_plasteel_fmt", fmt_num(pl_cost)))
    self:_set_text("cfg_ord_di", mod:localize("ord_diamantine_fmt", fmt_num(di_cost)))

    -- ── Affordability ───────────────────────────────────────────────────────
    if self._inv_mode then
        self._can_afford = (not self._wallet_loaded)
            or (rem_pl >= 0 and rem_di >= 0)
        -- Block proceed if no inventory weapons found (and scan is complete)
        if not self._inv_scanning and #self._inv_weapons == 0 then
            self._can_afford = false
        end
    else
        self._can_afford = (not self._wallet_loaded)
            or (rem_cr >= 0 and rem_pl >= 0 and rem_di >= 0)
    end

    -- ── Confirm checkbox ────────────────────────────────────────────────────
    local C_OK    = Color.green(200, true)
    local C_TRANS = Color.black(0, true)
    local chk = self:_w("cfg_chk_box")
    if chk and chk.style and chk.style.check then
        chk.style.check.color = self._confirmed and C_OK or C_TRANS
    end

    -- ── Proceed button color ────────────────────────────────────────────────
    local pw = self:_w("footer_proceed")
    if pw and pw.style and pw.style.bg then
        if not self._can_afford then
            pw.style.bg.color = { 180, 160, 40, 40 }
        elseif self._confirmed then
            pw.style.bg.color = C_OK
        else
            pw.style.bg.color = Color.gray(120, true)
        end
    end

    -- ── Footer hint ─────────────────────────────────────────────────────────
    local fph = self:_w("footer_proceed_hint")
    if not self._can_afford then
        local cache_empty = (next(_weapon_cache_ref()) == nil)
        local no_inv = self._inv_mode and not self._inv_scanning and #self._inv_weapons == 0
        local hint_text
        if no_inv and cache_empty then
            hint_text = self._inv_scanning and mod:localize("scanning_inventory") or mod:localize("hint_open_armory")
        elseif no_inv then
            hint_text = mod:localize("hint_no_weapons")
        else
            hint_text = mod:localize("hint_no_resources")
        end
        self:_set_text("footer_proceed_hint", hint_text)
        if fph and fph.style and fph.style.text then
            fph.style.text.text_color = { 255, 255, 80, 80 }
        end
        self:_vis("footer_proceed_hint", true)
    elseif not self._confirmed then
        self:_set_text("footer_proceed_hint", mod:localize("hint_tick_checkbox"))
        if fph and fph.style and fph.style.text then
            fph.style.text.text_color = { 255, 220, 130, 130 }
        end
        self:_vis("footer_proceed_hint", true)
    else
        self:_vis("footer_proceed_hint", false)
    end

    -- ── File log: configure preview (only when the numbers actually change) ──
    local sig = table.concat({
        e.display_name or "?", tostring(self._inv_mode), tostring(self._auto_mode),
        eff_amount, weapons_auto, self._upgrade_level,
        credits_cost, pl_cost, di_cost, tostring(self._can_afford),
        #self._inv_weapons, self._store_inv_count, tostring(costs_live),
    }, "|")
    if sig ~= self._last_cfg_log_sig then
        self._last_cfg_log_sig = sig
        mod.flog("PREVIEW",
            "Configure '%s': source %s, count %s (need %s for max, %s XP remaining, %s XP per sacrifice at %s), upgrade step %d, cost %s Cr / %s Pl / %s Di (%s) — %s",
            e.display_name or "?",
            self._inv_mode and "INVENTORY" or "STORE",
            self._auto_mode and (fmt_num(eff_amount) .. " auto") or fmt_num(eff_amount),
            fmt_num(weapons_auto), fmt_num(xp_rem), fmt_num(xp_per_sac),
            RARITY_NAMES[rarity_tier] or "?",
            self._upgrade_level,
            fmt_num(credits_cost), fmt_num(pl_cost), fmt_num(di_cost),
            costs_live and "live costs" or "ESTIMATED costs",
            self._can_afford and "affordable" or "NOT AFFORDABLE")
    end
end

-- Update the page-1 footer labels with current wallet values
function WeaponXPFarmView:_refresh_wallet_footer()
    local wd = self._wallet
    if self._wallet_loaded then
        self:_set_text("footer_res_cr", "Cr: "  .. fmt_num(wd.credits))
        self:_set_text("footer_res_pl", "Pl: "  .. fmt_num(wd.plasteel))
        self:_set_text("footer_res_di", "Di: "  .. fmt_num(wd.diamantine))
    else
        self:_set_text("footer_res_cr", "Cr: ...")
        self:_set_text("footer_res_pl", "Pl: ...")
        self:_set_text("footer_res_di", "Di: ...")
    end
end

-- Extract a numeric amount from a wallet entry object.
-- Handles plain tables, class instances with metatable, and nested balance fields.
local function extract_amount(w)
    if w == nil then return 0 end
    -- Plain number
    if type(w) == "number" then return w end
    if type(w) ~= "table" then return 0 end
    -- Direct .amount field
    local a = rawget(w, "amount")
    if a ~= nil then return tonumber(a) or 0 end
    -- Nested .balance.amount  (decorated wallet format)
    local bal = rawget(w, "balance")
    if type(bal) == "table" then
        local ba = rawget(bal, "amount")
        if ba ~= nil then return tonumber(ba) or 0 end
    end
    -- Fields hidden behind __index metatable (class instance)
    local ok, v = pcall(function() return w.amount end)
    if ok and v then return tonumber(v) or 0 end
    ok, v = pcall(function() return w.balance and w.balance.amount end)
    if ok and v then return tonumber(v) or 0 end
    return 0
end

-- Fetch wallet amount for one type via _find_cached_wallet_by_type.
-- Logs what it finds to help future debugging.
function WeaponXPFarmView:_load_wallet()
    local svc = Managers.data_service and Managers.data_service.store
    if not svc then
        mod:error("[WXF] wallet: no data_service.store")
        return
    end

    -- Use the store's own type-keyed lookup (_find_cached_wallet_by_type exists in method list)
    local function get_by_type(type_name)
        local ok, w = pcall(function() return svc:_find_cached_wallet_by_type(type_name) end)
        if not ok or w == nil then return nil end
        local amt = extract_amount(w)
        mod:info("[WXF] wallet %s = %d  (w_type=%s)", type_name, amt, type(w))
        -- Extra dump if still 0 so we can see the raw shape
        if amt == 0 and type(w) == "table" then
            for k2, v2 in pairs(w) do
                mod:info("[WXF]   %s.%s = %s", type_name, tostring(k2), tostring(v2))
                if type(v2) == "table" then
                    for k3, v3 in pairs(v2) do
                        mod:info("[WXF]     .%s = %s", tostring(k3), tostring(v3))
                    end
                end
            end
        end
        return amt
    end

    -- Credits live in the account wallet; Plasteel/Diamantine in the character wallet.
    -- Try several type-name spellings the game might use.
    local credits = 0
    for _, tname in ipairs({ "Credits", "credits", "CreditsGood", "MissionsCredits", "AccountCredits" }) do
        local v = get_by_type(tname)
        if v and v > 0 then credits = v; break end
    end
    if credits == 0 then
        local v = get_by_type("Credits"); if v then credits = v end
    end

    local plasteel   = get_by_type("Plasteel")   or get_by_type("plasteel")   or 0
    local diamantine = get_by_type("Diamantine")  or get_by_type("diamantine") or 0

    -- If _find_cached_wallet_by_type returned nil for everything, fall back to combined_wallets
    if credits == 0 and plasteel == 0 and diamantine == 0 then
        mod:info("[WXF] wallet: _find_cached_wallet_by_type returned all 0, trying combined_wallets")
        local ok2, raw = pcall(function() return svc:combined_wallets() end)
        if ok2 and type(raw) == "table" then
            mod:info("[WXF] wallet combined_wallets type=%s len=%d", type(raw), #raw)
            for k, v in pairs(raw) do
                mod:info("[WXF]  combined[%s] type=%s val=%s", tostring(k), type(v), tostring(v))
                if type(v) == "table" then
                    for k2, v2 in pairs(v) do
                        mod:info("[WXF]    .%s=%s", tostring(k2), tostring(v2))
                    end
                end
            end
        end
    end

    self._wallet        = { credits = credits, plasteel = plasteel, diamantine = diamantine }
    self._wallet_loaded = true
    mod:info("[WXF] wallet final: cr=%d  pl=%d  di=%d", credits, plasteel, diamantine)

    if self._screen == "configure"     then self:_refresh_configure()     end
    if self._screen == "weapon_select" then self:_refresh_wallet_footer() end
end

-- ── Inventory scan ──────────────────────────────────────────────────────────
-- Walk the full metatable chain and collect all function keys
local function _collect_methods(t)
    local seen, out = {}, {}
    local function scan(tbl)
        if type(tbl) ~= "table" then return end
        for k, v in pairs(tbl) do
            if type(v) == "function" and not seen[k] then
                seen[k] = true; out[#out+1] = k
            end
        end
    end
    scan(t)
    local cur = t
    for _ = 1, 8 do
        local mt = getmetatable(cur)
        if not mt then break end
        local idx = rawget(mt, "__index")
        if type(idx) == "table" then scan(idx); cur = idx
        elseif type(idx) == "function" then break
        else break end
    end
    return out
end

local function _make_gear_list_promise()
    local ds = Managers.data_service
    if not ds then return nil end

    -- Always log gear methods so we can discover the right one
    local gear_svc = ds.gear
    if gear_svc then
        local methods = _collect_methods(gear_svc)
        mod:info("[WXF] data_service.gear methods: %s",
            #methods > 0 and table.concat(methods, ", ") or "(none)")
    end

    -- Get current character ID for character-scoped API calls
    local char_id = nil
    local ok_p, player = pcall(function()
        return Managers.player and Managers.player:local_player(1)
    end)
    if ok_p and player then
        local ok_pr, profile = pcall(function() return player:profile() end)
        if ok_pr and profile then
            char_id = profile.character_id or profile.uuid
        end
    end
    mod:info("[WXF] character_id=%s", tostring(char_id))

    -- Try no-arg candidates first, then character-scoped ones
    local candidates = {
        -- character-scoped (weapon gear) — try these first
        { "gear", "fetch_character_gear",    char_id },
        { "gear", "get_character_gear",      char_id },
        { "gear", "fetch_character_items",   char_id },
        { "gear", "get_items_for_character", char_id },
        -- no-arg fallbacks
        { "gear", "fetch_gear"               },
        { "gear", "get_gear_list"            },
        { "gear", "get_all_gear"             },
        { "gear", "get_items"                },
        -- fetch_inventory is confirmed to return account cosmetics only — skip
    }
    for _, c in ipairs(candidates) do
        local svc = ds[c[1]]
        local fn_name = c[2]
        local arg = c[3]
        if svc and type(svc[fn_name]) == "function" then
            local ok, p = pcall(function()
                return arg ~= nil and svc[fn_name](svc, arg) or svc[fn_name](svc)
            end)
            if ok and p then
                mod:info("[WXF] gear list: using data_service.%s:%s(%s)",
                    c[1], fn_name, tostring(arg or ""))
                return p
            else
                mod:info("[WXF] candidate %s:%s failed: %s", c[1], fn_name, tostring(p))
            end
        end
    end

    -- Fall back to fetch_inventory with a warning
    if gear_svc and type(gear_svc.fetch_inventory) == "function" then
        local ok, p = pcall(function() return gear_svc:fetch_inventory() end)
        if ok and p then
            mod:info("[WXF] gear list: FALLBACK to fetch_inventory (returns cosmetics only)")
            return p
        end
    end

    return nil
end

-- Try to populate mod._weapon_cache directly from the backend gear service without
-- opening any UI view. Falls back to an informational update if no usable API is found.
function WeaponXPFarmView:_try_scan_from_backend()
    mod:info("[WXF] SCAN INV: attempting backend gear fetch")

    -- Attempt 1: Managers.data_service.gear
    local function _try_ds_gear()
        local ok, gs = pcall(function() return Managers.data_service and Managers.data_service.gear end)
        if not ok or not gs then return nil end
        for _, m in ipairs({ "fetch_gear", "fetch", "get_all", "get_items", "sync" }) do
            local fn = type(gs[m]) == "function" and gs[m]
            if fn then
                local ok2, p = pcall(fn, gs)
                if ok2 and p and type(p) == "table" and type(p.next) == "function" then
                    mod:info("[WXF] SCAN: data_service.gear:%s()", m)
                    return p
                end
            end
        end
        return nil
    end

    -- Attempt 2: Managers.backend.interfaces (gear / item / items)
    local function _try_backend_if()
        local ok, bi = pcall(function() return Managers.backend and Managers.backend.interfaces end)
        if not ok or not bi then return nil end
        for _, key in ipairs({ "gear", "item", "items" }) do
            local svc = bi[key]
            if svc then
                for _, m in ipairs({ "fetch_gear", "fetch_all", "get_items", "fetch", "get_gear" }) do
                    local fn = type(svc[m]) == "function" and svc[m]
                    if fn then
                        local ok2, p = pcall(fn, svc)
                        if ok2 and p and type(p) == "table" and type(p.next) == "function" then
                            mod:info("[WXF] SCAN: backend.interfaces.%s:%s()", key, m)
                            return p
                        end
                    end
                end
            end
        end
        return nil
    end

    local promise = _try_ds_gear() or _try_backend_if()

    if not promise then
        mod:info("[WXF] SCAN: no backend method available — open Armory manually")
        if not mod._scan_no_api_warned then
            mod._scan_no_api_warned = true
            mod:echo("[WXF] Could not auto-scan inventory — open Armory or Hadron crafting once to populate weapon data.")
        end
        return
    end

    self._inv_scanning = true
    self:_refresh_configure()

    promise:next(function(items)
        if not mod._weapon_cache then mod._weapon_cache = {} end
        local count = 0
        -- Use MasterItems to resolve parent_pattern from mdi.id (same as store item lookup)
        local master_items = (MasterItems and MasterItems.get_cached and MasterItems.get_cached()) or {}
        for _, raw in pairs(items or {}) do
            if type(raw) == "table" then
                local mdi = raw.masterDataInstance
                if mdi and mdi.id then
                    local gid = raw.uuid or raw.gear_id
                    if gid then
                        local mi  = master_items[mdi.id]
                        local pp  = (mi and mi.parent_pattern) or mdi.id
                        local rarity = 1
                        if mdi.overrides and type(mdi.overrides.rarity) == "number" then
                            rarity = math.max(1, mdi.overrides.rarity)
                        end
                        mod._weapon_cache[gid] = {
                            gear_id = gid, pattern = pp, rarity = rarity, gear = raw
                        }
                        count = count + 1
                    end
                end
            end
        end
        mod:info("[WXF] SCAN backend: cached %d items", count)

        -- Build a signature from count + sorted unique weapon types so we can
        -- skip the echo when nothing has changed since the last open.
        local pattern_set = {}
        for _, cached in pairs(mod._weapon_cache) do
            pattern_set[cached.pattern] = true
        end
        local pattern_list = {}
        for p in pairs(pattern_set) do pattern_list[#pattern_list + 1] = p end
        table.sort(pattern_list)
        local new_sig = tostring(count) .. "|" .. table.concat(pattern_list, ",")
        if new_sig ~= mod._last_scan_sig then
            mod._last_scan_sig = new_sig
            mod:echo(mod:localize("echo_inv_scanned_fmt", count))
        end

        self._inv_scanning = false
        if self._inv_mode then self:_trigger_inv_scan() end
        if self._screen == "configure" then self:_refresh_configure() end
    end):catch(function(err)
        mod:info("[WXF] SCAN backend error: %s", tostring(err))
        if not mod._scan_error_warned then
            mod._scan_error_warned = true
            mod:echo("[WXF] Inventory scan failed — open Armory or Hadron crafting once to populate weapon data.")
        end
        self._inv_scanning = false
        if self._screen == "configure" then self:_refresh_configure() end
    end)
end

function WeaponXPFarmView:_scan_inventory(pattern, target_rarity, min_rarity, callback)
    min_rarity = min_rarity or 1

    -- Count cache size
    local wc = _weapon_cache_ref()
    local cache_size = 0
    for _ in pairs(wc) do cache_size = cache_size + 1 end

    mod:info("[WXF] inventory scan: pattern=%s target=%d min=%d cache_size=%d",
        tostring(pattern), target_rarity, min_rarity, cache_size)

    if cache_size == 0 then
        mod:info("[WXF] weapon cache empty — player must open Armory or Hadron crafting first")
        callback({}, 0, 0)
        return
    end

    local found        = {}
    local skipped      = 0
    local skipped_fav  = 0
    local rarity_ok    = 0

    for gear_id, cached in pairs(wc) do
        if cached.pattern ~= pattern then goto continue_scan end

        local raw = cached.gear

        -- Skip favorites
        if raw and raw.is_favorite then
            skipped     = skipped + 1
            skipped_fav = skipped_fav + 1
            goto continue_scan
        end

        local current_rarity = cached.rarity or 1

        if current_rarity < min_rarity then
            skipped = skipped + 1
            goto continue_scan
        end

        local needs_consec = current_rarity < target_rarity
        if current_rarity >= target_rarity then
            rarity_ok = rarity_ok + 1
        end

        found[#found+1] = {
            gear_id            = gear_id,
            rarity             = current_rarity,
            needs_consecration = needs_consec,
            gear               = raw,   -- for live per-item consecration cost lookup
        }

        ::continue_scan::
    end

    mod:info("[WXF] inventory scan done: found=%d skipped=%d (fav=%d) rarity_ok=%d",
        #found, skipped, skipped_fav, rarity_ok)
    callback(found, skipped, rarity_ok, skipped_fav)
end

-- Trigger async inventory scan for inventory mode; updates _inv_weapons et al.
function WeaponXPFarmView:_trigger_inv_scan()
    local e = self._selected
    if not e or not e.item then return end
    local pattern      = e.item.parent_pattern
    local target_rarity = math.min(5, (e.base_rarity or 1) + self._upgrade_level)
    self._inv_scanning    = true
    self._inv_weapons     = {}
    self._inv_found       = 0
    self._inv_skipped     = 0
    self._inv_skipped_fav = 0
    self._inv_rarity_ok   = 0
    if self._screen == "configure" then self:_refresh_configure() end
    self:_scan_inventory(pattern, target_rarity, self._inv_filter_min, function(weapons, skipped, rarity_ok, skipped_fav)
        self._inv_weapons     = weapons
        self._inv_found       = #weapons
        self._inv_skipped     = skipped
        self._inv_skipped_fav = skipped_fav or 0
        self._inv_rarity_ok   = rarity_ok
        self._inv_scanning    = false
        if self._screen == "configure" then self:_refresh_configure() end
    end)
end

-- Trigger async inventory scan for store mode (always runs for notice; count used for calc when enabled).
function WeaponXPFarmView:_trigger_store_inv_scan()
    local e = self._selected
    if not e or not e.item then return end
    local pattern       = e.item.parent_pattern
    local target_rarity = math.min(5, (e.base_rarity or 1) + self._upgrade_level)
    self._store_inv_scanning = true
    if self._screen == "configure" then self:_refresh_configure() end
    self:_scan_inventory(pattern, target_rarity, 1, function(weapons, skipped, rarity_ok)
        self._store_inv_total    = #weapons
        self._store_rarity_ok    = rarity_ok
        self._store_inv_count    = self._inv_calc and rarity_ok or 0
        self._store_inv_scanning = false
        if self._screen == "configure" then self:_refresh_configure() end
    end)
end

function WeaponXPFarmView:_load_data()
    local player = Managers.player and Managers.player:local_player(1)
    if not player then
        self:_set_text("status_text", mod:localize("status_no_player"))
        return
    end

    Managers.data_service.store:get_credits_goods_store()
        :next(function(data)
            local ok, err = pcall(function() self:_process_store(data) end)
            if not ok then
                mod:error("[WXF] _process_store error: %s", tostring(err))
                self:_set_text("status_text", mod:localize("status_store_error"))
            end
        end)
        :catch(function(err)
            mod:error("[WXF] get_credits_goods_store error: %s", tostring(err))
            self:_set_text("status_text", mod:localize("status_store_unavailable"))
        end)
end

function WeaponXPFarmView:_process_store(store_data)
    local offers    = store_data and store_data.offers or {}
    local melee     = { name = "MELEE",  weapons = {} }
    local ranged    = { name = "RANGED", weapons = {} }
    local all_items = MasterItems.get_cached()

    -- One entry per weapon type: keyed by parent_pattern (or item_id as fallback)
    local seen_melee  = {}
    local seen_ranged = {}

    mod:info("[WXF] processing %d offers from Brunt's Armoury", #offers)

    for _, offer in ipairs(offers) do
        local desc = offer.description
        if not desc then goto continue end

        local lc      = desc.lootChoices
        local item_id = (lc and type(lc) == "table" and lc[1]) or desc.id
        if not item_id or item_id == "random-item" then goto continue end

        local item = all_items[item_id]
        if not item then goto continue end

        local slot = item.slots and item.slots[1]
        if slot ~= "slot_primary" and slot ~= "slot_secondary" then goto continue end

        -- Deduplicate by parent_pattern (falls back to item_id if no pattern)
        local pattern_key = item.parent_pattern or item_id
        local seen = (slot == "slot_secondary") and seen_ranged or seen_melee
        if seen[pattern_key] then goto continue end
        seen[pattern_key] = true

        local price = 0
        if offer.price and offer.price.amount then
            price = offer.price.amount.amount or 0
        end

        -- Resolve display name: prefer parent pattern item (cleaner base name),
        -- fall back to the mark-specific item name, then strip the mark either way.
        local disp_name = item_id
        local parent_item = item.parent_pattern and all_items[item.parent_pattern]
        if parent_item and parent_item.display_name then
            local ok, loc = pcall(Localize, parent_item.display_name)
            disp_name = (ok and loc and loc ~= "") and loc or parent_item.display_name
        elseif item.display_name then
            local ok, loc = pcall(Localize, item.display_name)
            disp_name = (ok and loc and loc ~= "") and loc or item.display_name
        end
        -- Strip mark prefix ("Mk II", "Mk Ia", "Branx Pattern", etc.) from the name
        disp_name = strip_weapon_mark(disp_name)

        local entry = {
            item          = item,
            item_id       = item_id,
            offer         = offer,
            price         = price,
            display_name  = disp_name,
            mastery_level = 0,
            base_rarity   = item.rarity or 1,
        }

        if slot == "slot_secondary" then
            ranged.weapons[#ranged.weapons+1] = entry
        else
            melee.weapons[#melee.weapons+1] = entry
        end
        ::continue::
    end

    self._tabs = {}
    if #melee.weapons  > 0 then self._tabs[#self._tabs+1] = melee  end
    if #ranged.weapons > 0 then self._tabs[#self._tabs+1] = ranged end
    mod:info("[WXF] store processed: tabs=%d melee=%d ranged=%d",
        #self._tabs, #melee.weapons, #ranged.weapons)

    local first_entry = (melee.weapons[1] or ranged.weapons[1])
    if first_entry and first_entry.item then
        local it = first_entry.item
        mod:info("[WXF] first item: hud_icon=%s parent_pattern=%s",
            tostring(it.hud_icon), tostring(it.parent_pattern))
    end

    if #self._tabs == 0 then
        self:_set_text("status_text",
            "No weapons in Brunt's Armoury for your class.\n(Must be opened from the hub.)")
        return
    end

    self:_load_mastery(function()
        self._screen     = "weapon_select"
        self._active_tab = 1
        self._scroll     = 0

        -- Restore the last selected weapon type so the user can immediately
        -- continue with the same weapon after a sacrifice-and-reopen cycle.
        local last_pat = mod._last_sacrifice_pattern
        if last_pat then
            for ti, tab in ipairs(self._tabs or {}) do
                for _, entry in ipairs(tab.weapons or {}) do
                    if entry.item and entry.item.parent_pattern == last_pat then
                        self._active_tab = ti
                        self._selected   = entry
                        break
                    end
                end
                if self._selected then break end
            end
        end

        self:_show_weapon_select()
        self:_load_wallet()
    end)
end

function WeaponXPFarmView:_load_mastery(callback)
    Managers.data_service.mastery:get_all_masteries()
        :next(function(masteries)
            local mastery_svc   = Managers.data_service.mastery
            local direct_tracks = mastery_svc and mastery_svc._mastery_tracks
            local track_ids     = mastery_svc and mastery_svc._mastery_track_ids

            local by_pattern      = {}
            local by_pattern_name = {}  -- pattern -> corrected display name
            local by_pattern_tkey = {}  -- pattern -> raw mastery key (for diagnostics)

            if direct_tracks then
                local track_count = 0
                local by_tid_name = {}
                local by_tid_tkey = {}
                for k, v in pairs(direct_tracks) do
                    track_count = track_count + 1
                    local lvl = (type(v) == "table" and (v.mastery_level or v.level or 0))
                             or (type(v) == "number" and v) or 0
                    by_pattern[tostring(k)] = lvl
                    if type(v) == "table" then
                        local track_key = v.display_name or v.name
                        if track_key then
                            by_tid_tkey[tostring(k)] = track_key
                            local fix = MASTERY_TRACK_NAME_FIXES[track_key]
                            if fix then
                                by_tid_name[tostring(k)] = fix
                            end
                        end
                    end
                end
                mod:info("[WXF] _mastery_tracks: %d entries", track_count)
                if track_ids then
                    for pat, tid in pairs(track_ids) do
                        local lvl = direct_tracks[tid]
                        if lvl ~= nil then
                            local actual = (type(lvl) == "table" and (lvl.mastery_level or lvl.level or 0))
                                        or (type(lvl) == "number" and lvl) or 0
                            by_pattern[tostring(pat)] = actual
                        end
                        local name = by_tid_name[tostring(tid)]
                        if name then by_pattern_name[tostring(pat)] = name end
                        local tkey = by_tid_tkey[tostring(tid)]
                        if tkey then by_pattern_tkey[tostring(pat)] = tkey end
                        -- (current_xp comes from the public get_all_masteries API, not private tracks)
                    end
                end
            end

            if masteries then
                for k, v in pairs(masteries) do
                    if type(v) == "table" then
                        local mid  = v.mastery_id or v.id or v.pattern_id or tostring(k)
                        local mlvl = v.mastery_level or v.level or 0
                        by_pattern[tostring(mid)] = mlvl
                        -- current_xp is total cumulative mastery XP for this weapon
                        if v.current_xp then
                            self._mastery_xp[tostring(mid)] = v.current_xp
                        end
                        -- milestones[n].xpLimit = cumulative XP to reach level n
                        if v.milestones then
                            local m = v.milestones[MAX_MASTERY_LEVEL]
                            if m and type(m.xpLimit) == "number" and m.xpLimit > 0
                               and m.xpLimit ~= MAX_MASTERY_XP then
                                MAX_MASTERY_XP = m.xpLimit
                                mod:set("max_mastery_xp", MAX_MASTERY_XP)
                                mod:info("[WXF] MAX_MASTERY_XP updated from milestones: %d", MAX_MASTERY_XP)
                            end
                        end
                    elseif type(v) == "number" then
                        by_pattern[tostring(k)] = v
                    end
                end
            end

            -- Fetch blessing points for the selected weapon via get_mastery_by_pattern
            pcall(function()
                local mastery_svc = Managers.data_service.mastery
                if not mastery_svc then return end
                local selected_pattern = self._item and self._item.parent_pattern
                if not selected_pattern then return end

                local function handle_mastery_data(md)
                    if type(md) ~= "table" then
                        mod:info("[WXF BLS] get_mastery result not a table: %s", tostring(md))
                        return
                    end
                    local pts = md.points_available
                    if type(pts) == "number" then
                        mod.bls_set_cached_points(pts)
                        mod:info("[WXF BLS] points_available=%d (get_mastery_by_pattern)", pts)
                        pcall(function() self:_refresh_configure() end)
                    else
                        -- Log fields so we can find the right name
                        local f = {}
                        for k, v in pairs(md) do
                            if type(v) ~= "table" and type(v) ~= "function" then
                                f[#f+1] = tostring(k).."="..tostring(v)
                            end
                        end
                        mod:info("[WXF BLS] mastery_data fields: %s", table.concat(f, ", "))
                    end
                end

                -- Try get_mastery_by_pattern first, then get_mastery with the mastery_id
                local fn = mastery_svc.get_mastery_by_pattern
                if type(fn) ~= "function" then
                    fn = mastery_svc.get_mastery
                end
                if type(fn) ~= "function" then return end

                local ok, res = pcall(fn, mastery_svc, selected_pattern)
                if not ok then
                    mod:info("[WXF BLS] get_mastery call error: %s", tostring(res))
                    return
                end
                -- Promise-based (like get_all_masteries) or synchronous?
                if res and type(res.next) == "function" then
                    res:next(handle_mastery_data)
                       :catch(function(err)
                           mod:info("[WXF BLS] get_mastery promise error: %s", tostring(err))
                       end)
                elseif res then
                    handle_mastery_data(res)
                end
            end)

            -- XP calibration: measure sacrifice XP per rarity from before/after delta
            local snap = mod._sacrifice_xp_snapshot
            if snap and snap.rarity_tier and snap.rarity_tier >= 2 and snap.num_items > 0 then
                local new_xp = self._mastery_xp[snap.pattern]
                if new_xp and new_xp > snap.xp_before then
                    local xp_gained  = new_xp - snap.xp_before
                    local per_weapon = math.floor(xp_gained / snap.num_items + 0.5)
                    if per_weapon > 0 and _is_plausible_sacrifice_xp(snap.rarity_tier, per_weapon) then
                        SACRIFICE_XP[snap.rarity_tier] = per_weapon
                        mod:set("sacrifice_xp_" .. snap.rarity_tier, per_weapon)
                        mod:info("[WXF] calibrated SACRIFICE_XP[%d] = %d  (gained=%d over %d weapons)",
                            snap.rarity_tier, per_weapon, xp_gained, snap.num_items)
                    elseif per_weapon > 0 then
                        -- Reject implausibly low reading (e.g. a partially-consecrated weapon
                        -- diluted the batch average, or the XP snapshot was stale) — do not persist it.
                        mod:info("[WXF] rejected implausible calibration SACRIFICE_XP[%d]=%d (gained=%d over %d weapons) — keeping %d",
                            snap.rarity_tier, per_weapon, xp_gained, snap.num_items, SACRIFICE_XP[snap.rarity_tier])
                    end
                    mod._sacrifice_xp_snapshot = nil
                else
                    mod:info("[WXF] XP snapshot stale (before=%d, now=%s) – will retry next open",
                        snap.xp_before, tostring(new_xp))
                end
            end

            local found, named = 0, 0
            for _ in pairs(by_pattern)      do found = found + 1 end
            for _ in pairs(by_pattern_name) do named = named + 1 end
            mod:info("[WXF] mastery: %d entries, %d name corrections", found, named)

            for _, tab in ipairs(self._tabs) do
                for _, entry in ipairs(tab.weapons) do
                    local pat = entry.item.parent_pattern
                    if pat then
                        entry.mastery_level = by_pattern[pat] or 0
                        local fix = by_pattern_name[pat]
                        if fix then
                            mod:info("[WXF] name fix: %s -> %s", entry.display_name, fix)
                            entry.display_name = fix
                        else
                            -- Log the mastery key so we can add a fix if the name is wrong
                            local tkey = by_pattern_tkey[pat]
                            if tkey then
                                mod:info("[WXF] no fix: '%s'  mastery key: %s", entry.display_name, tkey)
                            end
                        end
                    end
                end
            end

            -- Full weapon overview: what the first page shows, including the
            -- "x N weapons needed for max" preview per weapon.
            mod.flog_section("WEAPON OVERVIEW (first-page preview)")
            for _, tab in ipairs(self._tabs) do
                mod.flog("PREVIEW", "--- %s tab: %d weapons ---", tab.name, #tab.weapons)
                for _, entry in ipairs(tab.weapons) do
                    local pat    = entry.item.parent_pattern or ""
                    local cur_xp = self._mastery_xp[pat] or 0
                    local tier   = math.min(5, (entry.base_rarity or 1) + (self._upgrade_level or 1))
                    local need, xp_rem = calc_auto_amount(entry, tier, cur_xp)
                    if (entry.mastery_level or 0) >= MAX_MASTERY_LEVEL then
                        mod.flog("PREVIEW", "%-32s mastery %2d/%d — MAXED",
                            entry.display_name or "?", entry.mastery_level or 0, MAX_MASTERY_LEVEL)
                    else
                        mod.flog("PREVIEW",
                            "%-32s mastery %2d/%d  xp %s/%s (%s remaining)  needs x%d sacrifices at %s  price %s Cr each",
                            entry.display_name or "?", entry.mastery_level or 0, MAX_MASTERY_LEVEL,
                            fmt_num(cur_xp), fmt_num(MAX_MASTERY_XP), fmt_num(xp_rem),
                            need, RARITY_NAMES[tier] or "?", fmt_num(entry.price or 0))
                    end
                end
            end

            callback()
        end)
        :catch(function(err)
            mod:error("[WXF] get_all_masteries error: %s", tostring(err))
            callback()
        end)
end

-- â"€â"€ Update / input â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
function WeaponXPFarmView:update(dt, t, input_service)
    WeaponXPFarmView.super.update(self, dt, t, input_service)
    self:_tick_hover()

    local scr = self._screen
    if scr == "loading" or scr == "processing" then return end

    -- â"€â"€ Exit button (always active) â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
    if self:_btn_pressed("exit_btn") then
        Managers.ui:close_view("weapon_xp_farm_view")
        return
    end

    -- â"€â"€ Weapon select â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
    if scr == "weapon_select" then

        -- Tab switching
        for i = 1, math.min(#self._tabs, 2) do
            if self:_btn_pressed("tab_" .. (i-1)) and i ~= self._active_tab then
                self._active_tab = i
                self._scroll     = 0
                self._selected   = nil
                mod.flog("USER", "Switched to %s tab", (self._tabs[i] and self._tabs[i].name) or ("#" .. i))
                self:_refresh_tabs()
                self:_refresh_rows()
                self:_refresh_next_btn()
            end
        end

        -- Compute scroll limits
        local tab    = self._tabs[self._active_tab]
        local total  = tab and #tab.weapons or 0
        local max_sc = math.max(0, total - NUM_ROWS)

        -- Scroll: buttons, mouse wheel, keyboard
        local scroll_changed = false

        if self:_btn_pressed("scroll_up") then
            self._scroll   = math.max(self._scroll - 1, 0)
            scroll_changed = true
        end
        if self:_btn_pressed("scroll_dn") then
            self._scroll   = math.min(self._scroll + 1, max_sc)
            scroll_changed = true
        end

        -- Mouse wheel: Mouse.axis() returns a Vector3, so extract Y component
        if Mouse and Vector3 then
            local ok_mw, wheel_y = pcall(function()
                local v = Mouse.axis(Mouse.axis_index("wheel"))
                return Vector3.y(v)
            end)
            if ok_mw and wheel_y and wheel_y ~= 0 then
                if wheel_y > 0 then
                    self._scroll = math.max(self._scroll - 1, 0)
                else
                    self._scroll = math.min(self._scroll + 1, max_sc)
                end
                scroll_changed = true
            end
        end

        -- Keyboard navigate
        local ok_dn, dn = pcall(function() return input_service:get("navigate_down_continuous") end)
        local ok_up, up = pcall(function() return input_service:get("navigate_up_continuous") end)
        if ok_dn and dn then
            self._scroll   = math.min(self._scroll + 1, max_sc)
            scroll_changed = true
        elseif ok_up and up then
            self._scroll   = math.max(self._scroll - 1, 0)
            scroll_changed = true
        end

        -- Scrollbar drag: click-and-drag the track to scroll
        local sb_cur_y = nil
        if Mouse and Vector3 then
            pcall(function()
                local v = Mouse.axis(Mouse.axis_index("cursor"))
                sb_cur_y = Vector3.y(v)
            end)
        end

        local sb_left_down = false
        if Mouse then
            pcall(function()
                local b = Mouse.button(Mouse.button_index("left"))
                sb_left_down = b and b ~= 0 and b ~= false
            end)
        end

        -- Pressing on the track zone starts a drag
        if self:_btn_pressed("scroll_zone") and sb_cur_y then
            self._sb_drag         = true
            self._sb_drag_mouse_y = sb_cur_y
            self._sb_drag_start   = self._scroll
        end

        -- Continue drag while mouse is held
        if self._sb_drag then
            if not sb_left_down then
                self._sb_drag = false
            elseif sb_cur_y and max_sc > 0 then
                local delta  = sb_cur_y - self._sb_drag_mouse_y
                -- pixels per one scroll unit along the track
                local ppu    = SB_TRACK_H_V / max_sc
                local new_sc = math.max(0, math.min(max_sc,
                                   self._sb_drag_start + math.floor(delta / ppu + 0.5)))
                if new_sc ~= self._scroll then
                    self._scroll   = new_sc
                    scroll_changed = true
                end
            end
        end

        if scroll_changed then
            self:_refresh_rows()
        end

        -- Row click (select weapon)
        for i = 0, NUM_ROWS - 1 do
            if self:_btn_pressed(string.format("row_%02d", i)) then
                local weapons = tab and tab.weapons or {}
                local entry   = weapons[i + self._scroll + 1]
                if entry then
                    self._selected = entry
                    local pat    = entry.item and entry.item.parent_pattern or ""
                    local cur_xp = (self._mastery_xp and self._mastery_xp[pat]) or 0
                    local tier   = math.min(5, (entry.base_rarity or 1) + self._upgrade_level)
                    local need   = calc_auto_amount(entry, tier, cur_xp)
                    mod.flog("USER",
                        "Selected weapon: %s (mastery %d/%d, xp %s, base rarity %s, price %s Cr, needs x%d for max)",
                        entry.display_name or "?", entry.mastery_level or 0, MAX_MASTERY_LEVEL,
                        fmt_num(cur_xp), RARITY_NAMES[entry.base_rarity or 1] or "?",
                        fmt_num(entry.price or 0), need)
                    self:_refresh_rows()
                    self:_refresh_next_btn()
                end
            end
        end

        -- NEXT button
        if self:_btn_pressed("footer_next") and self._selected then
            mod.flog("USER", "NEXT pressed — opening configure screen for '%s'",
                self._selected.display_name or "?")
            self._screen        = "configure"
            self._confirmed     = false
            self._upgrade_level = 1
            self._dd_open       = false
            self._amount        = 1
            -- Reset inventory state for new selection
            self._inv_weapons     = {}
            self._inv_found       = 0
            self._inv_skipped     = 0
            self._inv_skipped_fav = 0
            self._inv_rarity_ok   = 0
            self._inv_scanning    = false
            self._store_inv_count = 0
            self:_show_configure()
        end

    -- â"€â"€ Configure screen â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
    elseif scr == "configure" then

        -- BACK
        if self:_btn_pressed("footer_back") then
            mod.flog("USER", "BACK pressed — returning to weapon selection screen")
            self._screen    = "weapon_select"
            self._confirmed = false
            self._dd_open   = false
            self:_show_weapon_select()
            return
        end

        -- Source mode toggle (STORE / INVENTORY)
        if self:_btn_pressed("cfg_mode_store_btn") and self._inv_mode then
            mod.flog("USER", "Source mode switched to STORE (buy from Brunt's Armoury)")
            self._inv_mode         = false
            self._confirmed        = false
            self._inv_filt_dd_open = false
            self:_vis("cfg_inv_filt_dd_bg", false)
            for _fi = 0, 4 do self:_vis("cfg_inv_filt_opt_" .. _fi, false) end
            local pw = self:_w("footer_proceed")
            if pw and pw.content then pw.content.text = mod:localize("btn_proceed") end
            self._store_inv_total    = 0
            self._store_rarity_ok    = 0
            self._store_inv_scanning = false
            self:_trigger_store_inv_scan()
            self:_refresh_configure()
        end
        if self:_btn_pressed("cfg_mode_inv_btn") and not self._inv_mode then
            mod.flog("USER", "Source mode switched to INVENTORY (use owned weapons)")
            self._inv_mode  = true
            self._confirmed = false
            local pw = self:_w("footer_proceed")
            if pw and pw.content then pw.content.text = mod:localize("btn_proceed_inv") end
            self:_trigger_inv_scan()
            self:_refresh_configure()
        end

        -- Inventory-mode rarity filter dropdown
        if self._inv_mode then
            local _FILT_NAMES = FILTER_LOC
            if self:_btn_pressed("cfg_inv_filt_dd") then
                self._inv_filt_dd_open = not self._inv_filt_dd_open
                self:_vis("cfg_inv_filt_dd_bg", self._inv_filt_dd_open)
                for _fi = 0, 4 do
                    self:_vis("cfg_inv_filt_opt_" .. _fi, self._inv_filt_dd_open)
                end
            end
            if self._inv_filt_dd_open then
                for _fi = 0, 4 do
                    local opt_w = self:_w("cfg_inv_filt_opt_" .. _fi)
                    if opt_w then
                        local hs = opt_w.content.hotspot
                        if opt_w.style and opt_w.style.hi then
                            opt_w.style.hi.color = (hs and hs.is_hover) and { 80, 255, 255, 255 } or { 0, 0, 0, 0 }
                        end
                        if self:_btn_pressed("cfg_inv_filt_opt_" .. _fi) then
                            local new_min = _fi + 1
                            if new_min ~= self._inv_filter_min then
                                mod.flog("USER", "Inventory rarity filter set to: %s",
                                    _FILT_NAMES[new_min] or "?")
                                self._inv_filter_min = new_min
                                self._confirmed      = false
                            end
                            self._inv_filt_dd_open = false
                            self:_vis("cfg_inv_filt_dd_bg", false)
                            for _fj = 0, 4 do
                                self:_vis("cfg_inv_filt_opt_" .. _fj, false)
                                local fw = self:_w("cfg_inv_filt_opt_" .. _fj)
                                if fw and fw.content and fw.content.hotspot then
                                    fw.content.hotspot.on_pressed = false
                                end
                            end
                            local dd_w = self:_w("cfg_inv_filt_dd")
                            if dd_w then
                                dd_w.content.text = "\xe2\x96\xbc  " .. _FILT_NAMES[new_min]
                                if dd_w.style then
                                    if dd_w.style.bg   then dd_w.style.bg.color       = DD_BG_COLOURS[_fi]  end
                                    if dd_w.style.text then dd_w.style.text.text_color = DD_TEXT_COLOURS[_fi] end
                                end
                            end
                            self:_trigger_inv_scan()
                            break
                        end
                    end
                end
            end
        end

        -- Auto / Manual mode checkbox (radio pair)
        if self:_btn_pressed("cfg_auto_chk_box") or self:_btn_pressed("cfg_auto_chk_lbl") then
            if not self._auto_mode then
                mod.flog("USER", "Count mode set to AUTO (%s)",
                    self._inv_mode and "Auto Sacrifice Weapons" or "Auto Max Mastery")
                self._auto_mode = true
                self._confirmed = false
                self:_refresh_configure()
            end
        end
        if self:_btn_pressed("cfg_manual_chk_box") or self:_btn_pressed("cfg_manual_chk_lbl") then
            if self._auto_mode then
                mod.flog("USER", "Count mode set to MANUAL (amount: %d)", self._amount)
                self._auto_mode = false
                self._confirmed = false
                self:_refresh_configure()
            end
        end

        -- "Count inventory toward goal" toggle (store mode only)
        if self:_btn_pressed("cfg_inv_calc_chk_box") or self:_btn_pressed("cfg_inv_calc_chk_lbl") then
            self._inv_calc  = not self._inv_calc
            self._confirmed = false
            -- Update the cached count (scan already ran; just toggle whether it's applied)
            self._store_inv_count = self._inv_calc and (self._store_rarity_ok or 0) or 0
            mod.flog("USER", "'Count inventory toward goal' toggled %s (%d sacrifice-ready in inventory)",
                self._inv_calc and "ON" or "OFF", self._store_inv_count)
            self:_refresh_configure()
        end

        -- Amount buttons (capped by inventory in inv mode)
        local amt_changed = false
        local max_v = self._inv_mode and math.max(1, #self._inv_weapons) or 38
        -- Max button works even in auto mode: switches to manual + sets max
        if self:_btn_pressed("cfg_amt_max") then
            self._auto_mode = false
            self._amount    = max_v
            amt_changed     = true
        end
        if not self._auto_mode then
            if self:_btn_pressed("cfg_amt_m5") then
                self._amount = math.max(1,     self._amount - 5); amt_changed = true
            end
            if self:_btn_pressed("cfg_amt_m1") then
                self._amount = math.max(1,     self._amount - 1); amt_changed = true
            end
            if self:_btn_pressed("cfg_amt_p1") then
                self._amount = math.min(max_v, self._amount + 1); amt_changed = true
            end
            if self:_btn_pressed("cfg_amt_p5") then
                self._amount = math.min(max_v, self._amount + 5); amt_changed = true
            end
        end
        if amt_changed then
            mod.flog("USER", "Weapon amount set to %d%s", self._amount,
                self._auto_mode and "" or " (manual)")
            self._confirmed = false
            self:_refresh_configure()
            return
        end

        -- Dropdown toggle
        if self:_btn_pressed("cfg_upg_dd") then
            if self._dd_open then self:_close_dd() else self:_open_dd() end
        end

        -- Dropdown option selection
        if self._dd_open then
            for i = 0, NUM_OPTS - 1 do
                if self:_btn_pressed("cfg_upg_opt_" .. i) then
                    local e = self._selected
                    local max_step = e and math.min(NUM_OPTS-1, 5-(e.base_rarity or 1)) or 0
                    self._upgrade_level = math.min(i, max_step)
                    self._confirmed     = false
                    local _tgt = e and math.min(5, (e.base_rarity or 1) + self._upgrade_level) or 1
                    mod.flog("USER", "Upgrade level set to Step %d (target rarity: %s)",
                        self._upgrade_level,
                        self._upgrade_level == 0 and "Profane / none" or (RARITY_NAMES[_tgt] or "?"))
                    self:_close_dd()
                    -- Re-scan if rarity target changed
                    if self._inv_mode then
                        self:_trigger_inv_scan()
                    elseif self._inv_calc then
                        self:_trigger_store_inv_scan()
                    end
                    self:_refresh_configure()
                    return
                end
            end
        end

        -- Confirm checkbox
        if self:_btn_pressed("cfg_chk_box") then
            self._confirmed = not self._confirmed
            mod.flog("USER", "Confirm checkbox %s", self._confirmed and "TICKED" or "UNTICKED")
            self:_refresh_configure()
        end

        -- PROCEED (blocked if resources insufficient or no inv weapons found)
        if self:_btn_pressed("footer_proceed") and self._confirmed and self._can_afford then
            local e = self._selected
            mod.flog("USER", "%s pressed — weapon '%s', source %s, count %s, upgrade step %d",
                self._inv_mode and "PROCEED" or "BUY",
                e and e.display_name or "?",
                self._inv_mode and "INVENTORY" or "STORE",
                self._auto_mode and (tostring(self._auto_amount) .. " (auto)") or tostring(self._amount),
                self._upgrade_level)
            if self._inv_mode then
                self:_inv_start_proc()
            else
                self:_start_proc()
            end
            return
        end

        -- Refresh every frame (costs, slider, dd button color, etc.)
        self:_refresh_configure()

    -- â"€â"€ Done screen â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
    elseif scr == "done" then
        if self:_btn_pressed("footer_close") then
            mod.flog("USER", "CLOSE pressed on done screen")
            Managers.ui:close_view("weapon_xp_farm_view")
        end
        if self:_btn_pressed("proc_craft_btn") then
            mod.flog("USER", "OPEN & SELECT pressed — handing %d weapon(s) to sacrifice automation",
                self._proc_gear_ids and #self._proc_gear_ids or 0)
            pcall(function()
                -- Snapshot XP before sacrifice so we can auto-calibrate SACRIFICE_XP afterward
                local snap_e = self._selected
                if snap_e and snap_e.item then
                    local snap_pat    = snap_e.item.parent_pattern
                    local snap_rarity = math.min(5, (snap_e.base_rarity or 1) + (self._upgrade_level or 0))
                    local snap_count  = self._proc_gear_ids and #self._proc_gear_ids or 0
                    if snap_pat and snap_count > 0 and snap_rarity >= 2 then
                        local xp_before = (self._mastery_xp and self._mastery_xp[snap_pat]) or 0
                        mod._sacrifice_xp_snapshot = {
                            pattern     = snap_pat,
                            xp_before   = xp_before,
                            num_items   = snap_count,
                            rarity_tier = snap_rarity,
                        }
                        mod:info("[WXF] XP snapshot: pat=%s xp_before=%d n=%d rarity=%d",
                            snap_pat, xp_before, snap_count, snap_rarity)
                    end
                end

                -- Store sacrifice context so the crafting view hook can pick it up
                local pattern = self._selected and self._selected.item
                             and self._selected.item.parent_pattern
                mod._pending_sacrifice = {
                    weapon_pattern = pattern,
                    gear_ids       = self._proc_gear_ids or {},
                }
                -- Remember the selected weapon type so the next WXF open can restore it
                mod._last_sacrifice_pattern = pattern
                mod:info("[WXF] pending_sacrifice set: pattern=%s  gear_ids=%d",
                    tostring(pattern), #mod._pending_sacrifice.gear_ids)

                Managers.ui:close_view("weapon_xp_farm_view")

                -- hub_interaction=true tells CraftingView to open directly to the crafting
                -- tabs, bypassing the "Entreat Hadron / Sacrifice Weapons" selection panel
                -- that would otherwise stay visible behind the sacrifice sub-view.
                local hub_ctx = { hub_interaction = true }

                -- Try the most specific sacrifice view first, then the general crafting view
                local opened = false
                for _, vname in ipairs({
                    "crafting_sacrifice_view",
                    "crafting_item_sacrifice_view",
                    "sacrifice_view",
                    "crafting_view",
                }) do
                    local ok2 = pcall(function()
                        Managers.ui:open_view(vname, nil, nil, nil, nil, hub_ctx)
                    end)
                    if ok2 then
                        mod:info("[WXF] opened view: %s (hub_interaction=true)", vname)
                        opened = true
                        break
                    end
                end
                if not opened then
                    mod:error("[WXF] could not open any crafting view")
                    mod._pending_sacrifice = nil
                end
            end)
        end
    end
end

-- â"€â"€ Processing â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€
function WeaponXPFarmView:_start_proc()
    mod.flog_section("STORE PURCHASE RUN")
    mod.flog("BUY", "Starting: buying %d x '%s' at %s Cr each, upgrade to step %d",
        self._auto_mode and self._auto_amount or self._amount,
        self._selected and self._selected.display_name or "?",
        fmt_num(self._selected and self._selected.price or 0),
        self._upgrade_level)
    self._screen        = "processing"
    self._proc_total    = self._auto_mode and self._auto_amount or self._amount
    self._proc_done     = 0
    self._proc_errors   = {}
    self._proc_gear_ids = {}
    self._out_of_funds  = false                         -- set true when server says "Insufficient funds"
    self._run_pl        = self._wallet.plasteel         -- running plasteel balance (estimate)
    self._run_di        = self._wallet.diamantine       -- running diamantine balance (estimate)
    self:_show_processing()
    self:_purchase_step(1)
end

function WeaponXPFarmView:_purchase_step(idx)
    if idx > self._proc_total then self:_finish(); return end
    if self._out_of_funds then self:_finish(); return end

    self:_set_text("proc_status",
        mod:localize("processing_buying", idx, self._proc_total))

    local offer = self._selected and self._selected.offer
    if not offer then
        self._proc_errors[#self._proc_errors+1] = "No store offer attached."
        self:_finish(); return
    end

    Managers.data_service.store:purchase_item(offer)
        :next(function(result)
            self._proc_done = self._proc_done + 1
            local gear_id = result and (
                result.gear_id
                or (result.items and result.items[1] and result.items[1].gear_id)
                or (result.item  and result.item.gear_id))
            if gear_id then
                self._proc_gear_ids[#self._proc_gear_ids + 1] = gear_id
            end
            mod.flog("BUY", "Purchase %d/%d OK (gear_id: %s)",
                idx, self._proc_total, tostring(gear_id))
            if self._upgrade_level > 0 and gear_id then
                self:_consecrate_step(gear_id, self._selected.base_rarity, 1, idx, function()
                    self:_purchase_step(idx + 1)
                end)
            else
                self:_purchase_step(idx + 1)
            end
        end)
        :catch(function(err)
            mod.flog("ERROR", "Purchase %d/%d FAILED: %s", idx, self._proc_total, tostring(err))
            self._proc_errors[#self._proc_errors+1] =
                "Buy #" .. idx .. ": " .. tostring(err)
            self:_purchase_step(idx + 1)
        end)
end

-- ── Inventory mode processing ───────────────────────────────────────────────
function WeaponXPFarmView:_inv_start_proc()
    local inv_count = #self._inv_weapons
    local eff_total = self._auto_mode
        and math.min(self._auto_amount, inv_count)
        or  math.min(self._amount,      math.max(1, inv_count))

    mod.flog_section("INVENTORY PROCESSING RUN")
    mod.flog("UPGRADE", "Starting: processing %d of %d matching inventory weapon(s) of '%s', upgrade step %d",
        eff_total, inv_count,
        self._selected and self._selected.display_name or "?",
        self._upgrade_level)

    self._screen        = "processing"
    self._proc_total    = eff_total
    self._proc_done     = 0
    self._proc_errors   = {}
    self._proc_gear_ids = {}
    self._out_of_funds  = false
    self._run_pl        = self._wallet.plasteel
    self._run_di        = self._wallet.diamantine
    self:_show_processing()
    self:_inv_proc_step(1)
end

function WeaponXPFarmView:_inv_proc_step(idx)
    if idx > self._proc_total then self:_finish(); return end
    if self._out_of_funds     then self:_finish(); return end

    local weapon = self._inv_weapons[idx]
    if not weapon then
        self:_inv_proc_step(idx + 1)
        return
    end

    self:_set_text("proc_status",
        mod:localize("processing_fmt", idx, self._proc_total))

    -- Always add to gear list (consecrated or not — all will be sacrificed)
    self._proc_gear_ids[#self._proc_gear_ids+1] = weapon.gear_id
    self._proc_done = self._proc_done + 1

    mod.flog("UPGRADE", "Weapon %d/%d: gear_id %s, rarity %s%s",
        idx, self._proc_total, tostring(weapon.gear_id),
        RARITY_NAMES[weapon.rarity or 1] or tostring(weapon.rarity),
        weapon.needs_consecration and " — needs consecration" or " — already at target rarity")

    if weapon.needs_consecration then
        -- Temporarily set _upgrade_level to the steps needed for this specific weapon
        -- (it may already be partially consecrated)
        local target       = math.min(5, (self._selected.base_rarity or 1) + self._upgrade_level)
        local steps_to_do  = math.max(0, target - weapon.rarity)
        local saved_level  = self._upgrade_level
        self._upgrade_level = steps_to_do
        self:_consecrate_step(weapon.gear_id, weapon.rarity, 1, idx, function()
            self._upgrade_level = saved_level
            self:_inv_proc_step(idx + 1)
        end)
    else
        -- Already at target rarity — no consecration needed
        self:_inv_proc_step(idx + 1)
    end
end

function WeaponXPFarmView:_consecrate_step(gear_id, base_tier, step, item_idx, cb)
    if step > self._upgrade_level then cb(); return end

    -- If a previous step already ran out of funds, skip all remaining consecrations.
    if self._out_of_funds then cb(); return end

    -- Live server-accurate cost for this specific weapon; falls back to the
    -- conservative estimate table if the backend cost cache isn't available.
    local cached_gear = mod._weapon_cache and mod._weapon_cache[gear_id]
    local costs, costs_live = get_consecrate_costs(base_tier + step,
        cached_gear and cached_gear.gear or (self._selected and self._selected.item))
    if not costs then cb(); return end

    -- Pre-check running balance estimate before sending the request.
    if self._wallet_loaded then
        local need_pl = costs.plasteel or 0
        local need_di = costs.diamantine or 0
        if (self._run_pl or 0) < need_pl or (self._run_di or 0) < need_di then
            self._out_of_funds = true
            local short = need_pl > (self._run_pl or 0)
                and string.format("Plasteel (need ~%d, have ~%d)", need_pl, self._run_pl or 0)
                or  string.format("Diamantine (need ~%d, have ~%d)", need_di, self._run_di or 0)
            self._proc_errors[#self._proc_errors+1] = string.format(
                "Consecrate #%d step %d: stopped — not enough %s", item_idx, step, short)
            mod.flog("WARNING", "Out of resources before item %d step %d: not enough %s",
                item_idx, step, short)
            cb(); return
        end
    end

    self:_set_text("proc_status",
        mod:localize("consecrating_step_fmt", item_idx, step, self._upgrade_level))

    Managers.data_service.crafting:upgrade_weapon_rarity(gear_id, {
        { type = "Plasteel",   amount = costs.plasteel   },
        { type = "Diamantine", amount = costs.diamantine },
    })
        :next(function()
            -- Deduct estimated costs from running balance so next pre-check stays accurate.
            self._run_pl = (self._run_pl or 0) - (costs.plasteel or 0)
            self._run_di = (self._run_di or 0) - (costs.diamantine or 0)
            mod.flog("UPGRADE", "Consecrated item %d step %d/%d -> %s (%s cost %d Pl / %d Di)",
                item_idx, step, self._upgrade_level,
                RARITY_NAMES[base_tier + step] or "?",
                costs_live and "live" or "est.",
                costs.plasteel or 0, costs.diamantine or 0)
            self:_consecrate_step(gear_id, base_tier, step + 1, item_idx, cb)
        end)
        :catch(function(err)
            mod.flog("ERROR", "Consecrate item %d step %d FAILED: %s",
                item_idx, step, tostring(err))
            local msg = tostring(err):lower()
            if msg:find("insufficient funds") or msg:find("not enough") then
                self._out_of_funds = true
                self._proc_errors[#self._proc_errors+1] = string.format(
                    "Consecrate #%d step %d: %s — stopped to prevent further losses.",
                    item_idx, step, tostring(err))
                self:_finish()  -- must call directly; skipping cb() would hang the loop
            else
                self._proc_errors[#self._proc_errors+1] =
                    "Consecrate #" .. item_idx .. " step " .. step .. ": " .. tostring(err)
                cb()
            end
        end)
end

function WeaponXPFarmView:_finish()
    if self._screen == "done" then return end
    local errs     = #self._proc_errors
    local have_ids = #self._proc_gear_ids > 0

    mod.flog_section("RUN RESULT")
    local status = self._out_of_funds and "STOPPED (out of resources)"
        or (errs > 0 and "DONE WITH ERRORS" or "DONE")
    mod.flog("RESULT", "%s — %d/%d processed, %d weapon(s) ready to sacrifice, %d error(s)",
        status, self._proc_done, self._proc_total, #self._proc_gear_ids, errs)
    for _, err_msg in ipairs(self._proc_errors) do
        mod.flog("RESULT", "  error: %s", tostring(err_msg))
    end

    if self._out_of_funds then
        self:_set_text("proc_hdr", mod:localize("stopped_hdr"))
        if self._inv_mode then
            self:_set_text("proc_status", mod:localize("stopped_inv_fmt", self._proc_done, self._proc_total))
        else
            self:_set_text("proc_status", mod:localize("stopped_store_fmt", self._proc_done, self._proc_total))
        end
        self:_set_text("proc_errors", table.concat(self._proc_errors, "\n"))
        -- In inventory mode still show craft button if we have some gear ready
        if self._inv_mode and have_ids then
            self:_vis("proc_craft_hint",  true)
            self:_vis("proc_craft_hint2", true)
            self:_vis("proc_craft_btn",   true)
        end
    elseif errs > 0 then
        self:_set_text("proc_hdr",    mod:localize("done_errors_hdr"))
        self:_set_text("proc_status", mod:localize("errors_count_fmt", errs))
        self:_set_text("proc_errors", table.concat(self._proc_errors, "\n"))
        -- In inventory mode show craft button even with errors (partial success)
        if self._inv_mode and have_ids then
            self:_vis("proc_craft_hint",  true)
            self:_vis("proc_craft_hint2", true)
            self:_vis("proc_craft_btn",   true)
        end
    else
        self:_set_text("proc_hdr", mod:localize("done_hdr"))
        if self._inv_mode then
            self:_set_text("proc_status",
                mod:localize("done_processed_fmt", self._proc_done))
        else
            self:_set_text("proc_status",
                mod:localize("done_purchased_fmt", self._proc_done))
        end
        self:_set_text("proc_errors", "")
        self:_vis("proc_craft_hint",  true)
        self:_vis("proc_craft_hint2", true)
        self:_vis("proc_craft_btn",   true)
    end
    self._screen = "done"
    self:_show_done()
end

mod:info("[WXF] view loaded OK.")
return WeaponXPFarmView

