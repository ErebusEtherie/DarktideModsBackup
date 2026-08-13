local mod = get_mod("Weapon_XP_Farm")

-- Per-session file logger (mods/Weapon_XP_Farm/logs/<date>_<time>.txt).
-- Must load first so it can wrap mod:info/:warning/:error before any are called.
mod:io_dofile("Weapon_XP_Farm/scripts/mods/Weapon_XP_Farm/wxf_logger")

local VIEW_NAME = "weapon_xp_farm_view"

mod:add_require_path("Weapon_XP_Farm/scripts/mods/Weapon_XP_Farm/views/weapon_xp_farm_view")
mod:add_require_path("Weapon_XP_Farm/scripts/mods/Weapon_XP_Farm/views/weapon_xp_farm_definitions")

-- ── Weapon inventory cache ─────────────────────────────────────────────────
-- Shared via mod._weapon_cache so view.lua can read it.
-- Populated by hooking present_grid_layout on the game's inventory/crafting views.
mod._weapon_cache = {}

local function _cache_items_from_layout(layout)
    if type(layout) ~= "table" then return end
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

local function _install_inv_hooks()
    local ok1, InvView = pcall(function()
        return mod:original_require("scripts/ui/views/inventory_weapons_view/inventory_weapons_view")
    end)
    if ok1 and InvView then
        mod:hook_safe(InvView, "present_grid_layout", function(_, layout)
            _cache_items_from_layout(layout)
        end)
        mod:info("[WXF] hooked InventoryWeaponsView (mod-load)")
    else
        mod:info("[WXF] InventoryWeaponsView hook failed: %s", tostring(InvView))
    end

    -- CraftingModifyView is a game global (not the hub CraftingView from crafting_view.lua)
    local CraftModView = rawget(_G, "CraftingModifyView")
    if CraftModView and CraftModView.present_grid_layout then
        mod:hook_safe(CraftModView, "present_grid_layout", function(_, layout)
            _cache_items_from_layout(layout)
        end)
        mod:info("[WXF] hooked CraftingModifyView (mod-load)")
    else
        mod:info("[WXF] CraftingModifyView not in _G at mod-load (will retry at view-load)")
    end
end

_install_inv_hooks()

mod:info("[WXF] loaded.")

-- ── Timer / state for sacrifice automation ─────────────────────────────────────

local _nav_timer  = 0
local _nav_view   = nil
local _NAV_DELAY  = 0.1

local _sacrifice_timer   = 0
local _sacrifice_view    = nil
local _sacrifice_retries = 0
local _SACRIFICE_DELAY   = 0.1
local _SACRIFICE_TIMEOUT = 25

local _auto_timer   = 0
local _auto_view    = nil
local _auto_ids     = nil
local _auto_pattern = nil
local _auto_phase   = nil
local _auto_retries = 0

-- Phase 4: after _mark_items_to_sell, watch for sacrifice completion then re-select the pattern.
local _reselect_view    = nil
local _reselect_pattern = nil
local _reselect_timer   = 0
local _reselect_retries = 0

-- ── Phase 2: pattern selection ─────────────────────────────────────────────────
local function _try_select_items(view_self, pending)
    mod:info("[WXF] _try_select_items: pattern=%s  gear_ids=%d",
        tostring(pending.weapon_pattern), #(pending.gear_ids or {}))

    if pending.weapon_pattern then
        local patterns_layout = view_self._patterns_layout
        if type(patterns_layout) == "table" and #patterns_layout > 0 then

            local matched = nil
            for _, entry in ipairs(patterns_layout) do
                if entry.mastery_id == pending.weapon_pattern then
                    matched = entry
                    break
                end
            end

            if matched then
                local matched_widget = nil
                pcall(function()
                    local widgets = view_self._patterns_grid:widgets()
                    for _, w in ipairs(widgets) do
                        local elem = w.content and w.content.element
                        if elem and elem.mastery_id == pending.weapon_pattern then
                            matched_widget = w
                            break
                        end
                    end
                end)

                local ok, err = pcall(function()
                    view_self:cb_pattern_on_grid_entry_left_pressed(matched_widget, matched)
                end)
                mod:info("[WXF] cb_pattern_on_grid_entry_left_pressed (widget=%s) -> %s",
                    matched_widget and "found" or "nil", ok and "OK" or tostring(err))

                if ok then
                    _auto_view    = view_self
                    _auto_ids     = pending.gear_ids or {}
                    _auto_phase   = "confirm"
                    _auto_timer   = 0.3
                    _auto_retries = 0
                    mod:info("[WXF] CONTINUE press scheduled in 0.3s")
                end
            else
                mod:info("[WXF] pattern '%s' not found in _patterns_layout (%d entries):",
                    tostring(pending.weapon_pattern), #patterns_layout)
                for _, e in ipairs(patterns_layout) do
                    if e.mastery_id then
                        mod:info("[WXF]   %s  slot=%s", tostring(e.mastery_id), tostring(e.slot))
                    end
                end
            end
        else
            mod:info("[WXF] _patterns_layout not ready (type=%s)", type(patterns_layout))
        end
    end
end

-- ── Phase 1 helpers ────────────────────────────────────────────────────────────

local SACRIFICE_VIEW_NAME = "crafting_mechanicus_barter_items_view"

local function _try_access_sacrifice_panel(view_self, pending)
    local inst = nil
    pcall(function() inst = view_self._active_view_instance end)
    if type(inst) ~= "table" then
        pcall(function()
            local ui = Managers.ui
            if ui then inst = ui:view_instance(SACRIFICE_VIEW_NAME) end
        end)
    end
    if type(inst) ~= "table" then
        mod:info("[WXF] sacrifice panel not ready")
        return false
    end
    local entered = false
    pcall(function() entered = inst:entered() end)
    if not entered then
        mod:info("[WXF] sacrifice panel exists but not yet entered")
        return false
    end
    local transitioning = false
    pcall(function() transitioning = inst.transitioning_in == true end)
    if transitioning then
        mod:info("[WXF] sacrifice panel animating in, waiting...")
        return false
    end
    local patterns_ready = false
    pcall(function()
        patterns_ready = type(inst._patterns_layout) == "table"
                      and #inst._patterns_layout > 0
    end)
    if not patterns_ready then
        mod:info("[WXF] sacrifice panel entered, waiting for patterns...")
        return false
    end
    pcall(function()
        if view_self._active_view_instance ~= inst then
            if type(view_self.set_active_view_instance) == "function" then
                view_self:set_active_view_instance(inst)
                mod:info("[WXF] set_active_view_instance -> OK")
            else
                view_self._active_view_instance = inst
                mod:info("[WXF] _active_view_instance patched directly")
            end
        end
    end)

    mod:info("[WXF] sacrifice panel ready, patterns: %d -- select in 0.3s",
        inst._patterns_layout and #inst._patterns_layout or 0)
    _auto_view      = inst
    _auto_ids       = pending.gear_ids or {}
    _auto_pattern   = pending.weapon_pattern
    _reselect_pattern = pending.weapon_pattern  -- saved for post-sacrifice re-select
    _auto_phase     = "select"
    _auto_timer     = 0.3
    _auto_retries   = 0
    return true
end

-- ── Phase 0 helpers ────────────────────────────────────────────────────────────

-- Selection panel widget names confirmed from live widget dump.
-- Hiding these instantly removes the "Entreat Hadron / Sacrifice Weapons" overlay
-- without waiting for any exit animation.
local _PANEL_WIDGETS = {
    "option_button_1", "option_button_2",
    "button_divider",  "description_text", "title_text",
}

local function _nav_to_sacrifice(view_self)
    -- Clear the stuck _on_enter_animation_triggered flag so CraftingView's tab
    -- logic runs cleanly when opened via open_view (story callback never fires).
    pcall(function()
        if view_self._on_enter_animation_triggered == true then
            view_self._on_enter_animation_triggered = false
        end
    end)

    -- Navigate to the sacrifice sub-view directly — fastest path, no animation wait.
    local ok = false
    if type(view_self.go_to_crafting_view) == "function" then
        local err
        ok, err = pcall(function()
            view_self:go_to_crafting_view("barter_items_mechanicus", nil)
        end)
        mod:info("[WXF] go_to_crafting_view -> %s", ok and "OK" or tostring(err))
    end

    -- Immediately hide the selection panel widgets by name (confirmed names).
    -- This avoids the slow exit animation while still clearing the overlay.
    pcall(function()
        local wbn = view_self._widgets_by_name
        if type(wbn) ~= "table" then return end
        for _, name in ipairs(_PANEL_WIDGETS) do
            local w = wbn[name]
            if w then w.visible = false end
        end
        mod:info("[WXF] panel widgets hidden")
    end)

    return ok
end

-- ── Hook targets ───────────────────────────────────────────────────────────────

-- Forward declarations: BLS engine is defined after on_all_mods_loaded,
-- but the MasteryView hook closures inside it need to capture these as upvalues.
local BLS = {
    mastery_view         = nil,
    cached_points        = nil,   -- net remaining pts from server (points_available)
    mastery_view_context = nil,
    mv_btn_all           = nil,   -- "Spend All" injected button
}

local CRAFT_MAIN_CLASSES = { "CraftingView", "HadronCraftingView" }
local CRAFT_SACRIFICE_CLASSES = {
    "CraftingMechanicusBarterItemsView",
    "CraftingItemSacrificeView",
    "CraftingSacrificeView",
    "SacrificeView",
    "ItemSacrificeView",
}

-- ── on_all_mods_loaded ─────────────────────────────────────────────────────────

mod.on_all_mods_loaded = function()
    -- Log the user's full mod list into the session file — invaluable when
    -- debugging user bug reports (mod conflicts, load order, disabled mods).
    pcall(function()
        local dmf  = get_mod("DMF")
        local mods = dmf and dmf.mods           -- name -> mod object
        local list = {}                          -- { {name=..., obj=...}, ... } in load order
        local ordered = dmf and dmf.mods_unloading_order   -- list of mod NAMES, unload order
        if type(ordered) == "table" and #ordered > 0 then
            -- unloading order reversed = load order
            for i = #ordered, 1, -1 do
                local name = ordered[i]
                if type(name) == "string" then
                    list[#list+1] = { name = name, obj = mods and mods[name] }
                end
            end
        elseif type(mods) == "table" then
            for name, m in pairs(mods) do
                list[#list+1] = { name = tostring(name), obj = m }
            end
        end
        -- Some mods decorate their readable name with Fatshark text-markup tags,
        -- e.g. {#color(255,0,0)}E{#color(248,0,14)}n...{#reset()}. Strip ALL
        -- {#...} tags generically (any tag name/args) and tidy the whitespace.
        local function _strip_markup(s)
            s = s:gsub("{#.-}", "")           -- any {#tag(...)} block
            s = s:gsub("\194\160", " ")       -- U+00A0 nbsp -> plain space (%s misses it)
            s = s:gsub("\226\128\139", "")    -- U+200B zero-width space
            s = s:gsub("%s+", " ")            -- collapse runs of spaces
            return s:match("^%s*(.-)%s*$")    -- trim
        end
        mod.flog_section("LOADED MODS (" .. tostring(#list) .. ")")
        for i, entry in ipairs(list) do
            local name    = entry.name
            local enabled = "?"
            pcall(function()
                local rn = entry.obj and entry.obj:get_readable_name()
                if type(rn) == "string" and #rn > 0 then
                    rn = _strip_markup(rn)
                    if #rn > 0 then name = rn end
                end
            end)
            pcall(function()
                enabled = entry.obj and (entry.obj:is_enabled() and "enabled" or "DISABLED") or "?"
            end)
            mod.flog("SESSION", "%2d. %-40s %s", i, tostring(name), tostring(enabled))
        end
    end)

    mod:register_view({
        view_name = VIEW_NAME,
        view_settings = {
            init_view_function = function(ingame_ui_context) return true end,
            class              = "WeaponXPFarmView",
            display_name       = "weapon_xp_farm",
            package            = "packages/ui/views/options_view/options_view",
            path               = "Weapon_XP_Farm/scripts/mods/Weapon_XP_Farm/views/weapon_xp_farm_view",
            state_bound        = false,
            disable_game_world = false,
            game_world_blur    = 1.1,
            load_always        = true,
            load_in_hub        = true,
            enter_sound_events = { "wwise/events/ui/play_ui_enter_short" },
            exit_sound_events  = { "wwise/events/ui/play_ui_back_short"  },
            wwise_states       = { options = "ingame_menu" },
        },
        view_transitions = {},
        view_options     = {},
    })
    mod:info("[WXF] view registered.")

    -- ── CraftingView / HadronCraftingView: Phase 0 ────────────────────────────
    for _, cls_name in ipairs(CRAFT_MAIN_CLASSES) do
        pcall(function()
            local cls = CLASS and CLASS[cls_name]
            if not cls then return end
            mod:hook_safe(cls, "on_enter", function(view_self)
                pcall(function()
                    local ctx = nil
                    if type(view_self.context) == "function" then
                        ctx = view_self:context()
                    else
                        ctx = view_self._context
                    end
                    if type(ctx) == "table" then
                        local parts = {}
                        for k, v in pairs(ctx) do
                            parts[#parts + 1] = tostring(k) .. "=" .. tostring(v)
                        end
                        mod:info("[WXF] %s context: {%s}", cls_name,
                            table.concat(parts, ", "))
                    else
                        mod:info("[WXF] %s context: %s", cls_name, tostring(ctx))
                    end
                end)
                if not mod._pending_sacrifice then return end
                mod:info("[WXF] crafting hook: %s - nav in %.1fs", cls_name, _NAV_DELAY)
                _nav_view  = view_self
                _nav_timer = _NAV_DELAY
            end)
            mod:info("[WXF] nav hook on %s", cls_name)
        end)
    end

    -- ── Crash fix: targeted hooks on CraftingMechanicusBarterItemsView ────────
    --
    -- Root cause: CraftingMechanicusBarterItemsView uses _ui_renderer_is_external=true,
    -- meaning it borrows CraftingView's C++ renderer/materials.  When the user presses
    -- ESC, CraftingView begins closing and frees its materials.  The barter_items_view
    -- exit animation then tries to draw/destroy through those freed materials →
    -- "set_scalar: Material expected, got userdata" at ui_passes.lua:113.
    --
    -- Fix: hook draw and destroy ONLY on this specific class.
    -- We deliberately avoid hooking BaseView because other views (e.g. SocialMenuRosterView)
    -- also use _ui_renderer_is_external and would be incorrectly intercepted, causing a
    -- blank social menu screen when custom_hud is also installed.
    pcall(function()
        local barter_cls = CLASS and CLASS["CraftingMechanicusBarterItemsView"]
        if not barter_cls then return end

        -- Hook on_exit to clear stuck animation flag.
        mod:hook_safe(barter_cls, "on_exit", function(view_self)
            pcall(function()
                view_self._on_enter_animation_triggered = false
                mod:info("[WXF] crash-fix: cleared _on_enter_animation_triggered on_exit")
            end)
        end)
        mod:info("[WXF] crash-fix exit hook on CraftingMechanicusBarterItemsView")

        -- Targeted draw hook: absorb stale-material draw errors only for this view.
        mod:hook(barter_cls, "draw", function(func, self, dt, t, input_service)
            if rawget(self, "closing_view") and rawget(self, "_ui_renderer_is_external") then
                local ok, err = pcall(func, self, dt, t, input_service)
                if not ok then
                    mod:info("[WXF] crash-fix: absorbed draw error (barter view closing): %s",
                        tostring(err))
                end
                return
            end
            return func(self, dt, t, input_service)
        end)
        mod:info("[WXF] crash-fix draw hook on CraftingMechanicusBarterItemsView")

        -- Targeted destroy hook: absorb errors only for this specific view.
        mod:hook(barter_cls, "destroy", function(func, self)
            local ok, err = pcall(func, self)
            if not ok then
                mod:info("[WXF] crash-fix: absorbed destroy error (barter view): %s", tostring(err))
            end
        end)
        mod:info("[WXF] crash-fix destroy hook on CraftingMechanicusBarterItemsView")
    end)

    -- ── MasteryView hooks: track instance, inject button, handle spending ───────
    pcall(function()
        local mv_cls = CLASS and CLASS["MasteryView"]
        if not mv_cls then
            mod:info("[WXF BLS] MasteryView class not found — keybind will work once mastery view loads")
            return
        end

        -- UIWidget / UIRenderer are not in the global scope of the main mod file;
        -- require them explicitly so we can create and draw our injected button.
        local _UIWidget, _UIRenderer
        for _, path in ipairs({
            "scripts/managers/ui/ui_widget",
            "scripts/ui/ui_widget",
        }) do
            local ok, r = pcall(mod.original_require, mod, path)
            if ok and type(r) == "table" then _UIWidget = r; break end
        end
        for _, path in ipairs({
            "scripts/managers/ui/ui_renderer",
            "scripts/ui/ui_renderer",
        }) do
            local ok, r = pcall(mod.original_require, mod, path)
            if ok and type(r) == "table" then _UIRenderer = r; break end
        end
        mod:info("[WXF BLS] _UIWidget=%s _UIRenderer=%s", type(_UIWidget), type(_UIRenderer))

        -- Creates a button widget: tries init(name, def), falls back to manual table.
        local function _make_btn(w_name, label, W, H, X, Y, bg_col)
            local Z = 100
            local passes = {
                { pass_type = "rect",    style_id = "bg",
                  style = { color = bg_col, size = {W, H}, offset = {X, Y, Z} } },
                { pass_type = "text",    value_id = "text", style_id = "text",
                  style = { font_type    = "proxima_nova_bold",  font_size = 14,
                            text_color   = {255, 250, 215, 235},
                            text_horizontal_alignment = "center",
                            text_vertical_alignment   = "center",
                            size = {W, H}, offset = {X, Y, Z} } },
                { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot",
                  style = { size = {W, H}, offset = {X, Y, Z} } },
            }
            if _UIWidget then
                local def = _UIWidget.create_definition(passes, "screen", { text = label, hotspot = {} })
                if def then
                    local ok, w = pcall(_UIWidget.init, w_name, def)
                    if ok and type(w) == "table" then return w end
                end
            end
            -- Manual fallback using confirmed widget structure
            return {
                visible = true, name = w_name, scenegraph_id = "screen",
                passes  = {
                    { pass_type = "rect",    style_id = "bg" },
                    { pass_type = "text",    value_id = "text",    style_id = "text" },
                    { pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot" },
                },
                style = {
                    bg      = { color = bg_col, size = {W, H}, offset = {X, Y, Z} },
                    text    = { font_type    = "proxima_nova_bold", font_size = 14,
                                text_color   = {255, 250, 215, 235},
                                text_horizontal_alignment = "center",
                                text_vertical_alignment   = "center",
                                size = {W, H}, offset = {X, Y, Z} },
                    hotspot = { size = {W, H}, offset = {X, Y, Z} },
                },
                content    = { text = label, hotspot = {} },
                animations = {}, offset = {0, 0, 0},
            }
        end

        mod:hook_safe(mv_cls, "on_enter", function(self_mv)
            BLS.mastery_view = self_mv
            -- Cache view context so WXF can reopen this view later
            pcall(function()
                local ctx = self_mv._context
                if type(ctx) == "table" then BLS.mastery_view_context = ctx end
            end)
            -- Cache available points (raw milestone total — never modified by us)
            pcall(function()
                local pts = self_mv._mastery and self_mv._mastery.points_available
                if type(pts) == "number" then BLS.cached_points = pts end
            end)
            mod:info("[WXF BLS] MasteryView on_enter, pts=%s", tostring(BLS.cached_points))
            -- Inject buttons into the view
            pcall(function()
                local pts_str = type(BLS.cached_points) == "number"
                    and tostring(BLS.cached_points) or "?"
                local W, H = 260, 40
                local BX   = 830   -- calibrated center ≈ screenshot x=728
                BLS.mv_btn_all = _make_btn(
                    "bls_btn_all",
                    mod:localize("spend_all_fmt", pts_str),
                    W, H, BX, 1025, {255, 155, 48, 200})
                if self_mv._widgets then
                    table.insert(self_mv._widgets, BLS.mv_btn_all)
                end
            end)
            mod:info("[WXF BLS] button injected: all=%s", type(BLS.mv_btn_all))
        end)

        mod:hook_safe(mv_cls, "on_exit", function(self_mv)
            if BLS.mastery_view == self_mv then
                BLS.mastery_view = nil
                -- Keep BLS.cached_points — WXF display uses it after the view closes
            end
            BLS.mv_btn_all = nil
            mod:info("[WXF BLS] MasteryView on_exit")
        end)

        -- Live update: refresh points text, hover colours, click detection
        local _COL_ALL_NORM   = {255, 155,  48, 200}
        local _COL_ALL_HOVER  = {255, 185,  80, 235}

        mod:hook_safe(mv_cls, "update", function(self_mv, dt)
            if BLS.mastery_view ~= self_mv then return end
            pcall(function()
                local b1 = BLS.mv_btn_all
                if b1 and b1.content and b1.style then
                    local hs = b1.content.hotspot
                    if hs then
                        -- Refresh label and handle hover/click. The spend itself is
                        -- synchronous, so no locked/progress state is needed.
                        local pts = self_mv._mastery and self_mv._mastery.points_available
                        if type(pts) == "number" then
                            BLS.cached_points = pts
                            -- points_available is the net remaining balance; show it directly
                            local want = mod:localize("spend_all_fmt", tostring(pts))
                            if b1.content.text ~= want then
                                b1.content.text = want
                            end
                        end
                        b1.style.bg.color = hs.is_hover and _COL_ALL_HOVER or _COL_ALL_NORM
                        if hs.on_pressed then
                            hs.on_pressed = false
                            mod.bls_start()
                        end
                    end
                end
            end)
        end)

        -- Fallback draw pass (in case _widgets injection silently dropped our widgets)
        local _draw_logged = false
        mod:hook_safe(mv_cls, "draw", function(self_mv, dt)
            if not BLS.mv_btn_all or BLS.mastery_view ~= self_mv then return end
            if not _UIRenderer or not _UIWidget then return end
            local ui_renderer = self_mv._ui_renderer
            if not ui_renderer then return end
            if not _draw_logged then
                _draw_logged = true
                mod:info("[WXF BLS] draw fallback firing")
            end
            pcall(function()
                local input_svc = self_mv._input_service
                    or (Managers.input and Managers.input:get_input_service("View"))
                _UIRenderer.begin_pass(ui_renderer, self_mv._ui_scenegraph,
                    "render", dt, input_svc, self_mv._render_settings)
                if BLS.mv_btn_all then _UIWidget.draw(BLS.mv_btn_all, ui_renderer, dt) end
                _UIRenderer.end_pass(ui_renderer)
            end)
        end)

        mod:info("[WXF BLS] MasteryView hooks installed")
    end)

    -- ── Sacrifice sub-view on_enter hooks (informational) ─────────────────────
    for _, cls_name in ipairs(CRAFT_SACRIFICE_CLASSES) do
        pcall(function()
            local cls = CLASS and CLASS[cls_name]
            if not cls then return end
            mod:hook_safe(cls, "on_enter", function(view_self)
                if not mod._pending_sacrifice then return end
                mod:info("[WXF] sacrifice sub-view on_enter: %s", cls_name)
            end)
            mod:info("[WXF] info hook on %s", cls_name)
        end)
    end
end

-- ── Blessing Points Spending Engine ───────────────────────────────────────────
-- The spend itself is synchronous and local (see _bls_spend_all_local): it mirrors
-- what the vanilla MasteryView does on click, and the game commits the queued
-- purchases to the server when the Mastery screen closes.

-- Returns available blessing points: live from mastery view if open, else cached
function mod.bls_get_points()
    local mv = BLS.mastery_view
    if mv then
        local pts = nil
        pcall(function()
            pts = mv._mastery and mv._mastery.points_available
            if type(pts) ~= "number" then pts = nil end
        end)
        if type(pts) == "number" then
            BLS.cached_points = pts
            return pts
        end
    end
    return BLS.cached_points   -- set by _load_mastery from the API response
end

-- Called from view._load_mastery to cache the points count without needing the mastery view open
function mod.bls_set_cached_points(pts)
    if type(pts) == "number" then BLS.cached_points = pts end
end

local function _bls_get_traits_id()
    local mv = BLS.mastery_view
    if not mv then return nil end
    local tid = nil
    pcall(function() tid = mv._traits_id end)
    if tid then return tid end
    pcall(function() tid = mv._context and mv._context.traits_id end)
    if tid then return tid end
    -- deep search: any string field with "trait" in name that looks like an ID
    pcall(function()
        for k, v in pairs(mv) do
            if type(k) == "string" and k:lower():find("trait") and
               type(v) == "string" and #v > 8 and #v < 128 then
                tid = v; break
            end
        end
    end)
    return tid
end

-- Returns list of { trait_name, trait_status } from the mastery view's widgets
local function _bls_get_traits_list()
    local mv = BLS.mastery_view
    if not mv then return nil end
    local list = {}
    local seen = {}
    pcall(function()
        -- Primary: direct field access (same order as claim_all_master)
        local raw = mv._traits or mv._mastery_traits or (mv._context and mv._context.traits)
        if type(raw) == "table" then
            for _, entry in ipairs(raw) do
                local tn = entry.trait_name or entry.name or entry[1]
                local ts = entry.trait_status or entry.status or entry[2]
                if tn and not seen[tn] then
                    seen[tn] = true
                    list[#list+1] = { trait_name = tn, trait_status = ts }
                end
            end
        end
        -- Fallback: scan _widgets_by_name — only need trait_name (status comes from sticker book)
        local wbn = mv._widgets_by_name
        if type(wbn) == "table" then
            for _, widget in pairs(wbn) do
                local c = widget and widget.content
                if c and c.trait_name and not seen[c.trait_name] then
                    seen[c.trait_name] = true
                    list[#list+1] = { trait_name = c.trait_name, trait_status = c.trait_status }
                end
            end
        end
    end)
    mod:info("[WXF BLS] _bls_get_traits_list: found %d trait(s)", #list)
    -- Log all trait names so we can verify which traits are included
    local tnames = {}
    for i, e in ipairs(list) do tnames[i] = e.trait_name end
    mod:info("[WXF BLS] trait names: %s", table.concat(tnames, " | "))
    return list
end

-- ── Local spend engine (mirrors vanilla MasteryView._cb_trait_left_pressed) ────
-- The REAL blessing purchase in the game is: mutate the view's local trait state,
-- queue each buy into mv._purchased_traits, and let MasteryView.on_exit commit the
-- whole batch via Managers.data_service.mastery:purchase_traits(). The old approach
-- (backend mastery.purchase_trait) hit the trait-COLLECTION endpoint: it "succeeded"
-- without deducting points or unlocking anything. This does what manual clicking does.
local function _bls_spend_all_local(mv)
    local Mastery
    do
        local ok, r = pcall(mod.original_require, mod, "scripts/utilities/mastery")
        if ok and type(r) == "table" then Mastery = r end
    end
    if not Mastery or type(Mastery.get_trait_cost) ~= "function" then
        return nil, "Mastery utilities unavailable"
    end

    local traits  = mv._traits
    local mastery = mv._mastery
    if type(traits) ~= "table" or type(mastery) ~= "table"
        or type(mastery.points_available) ~= "number" then
        return nil, "mastery data not loaded yet — try again in a second"
    end

    local spent_pts, spent_count = 0, 0
    local progressed = true
    while progressed do
        progressed = false

        -- Higher blessing tiers unlock as points are spent — recompute the cap each pass
        local max_r = 4
        pcall(function()
            local lvl = Mastery.get_max_blessing_rarity_unlocked_level_by_points_spent(traits)
            if type(lvl) == "number" and lvl >= 1 then max_r = lvl end
        end)

        for index, t in ipairs(traits) do
            local status = t.trait_status
            local tname  = t.name or t.trait_name
            if type(status) == "table" and tname then
                -- Next purchasable rank: lowest "unseen", all ranks below already "seen".
                -- Anything else ("locked"/"unavailable") blocks that trait's ladder.
                local r
                for rank = 1, max_r do
                    local s = status[rank]
                    if s == "unseen" then r = rank break end
                    if s ~= "seen" then break end
                end
                if r then
                    local okc, cost = pcall(Mastery.get_trait_cost, r)
                    cost = okc and tonumber(cost) or nil
                    if cost and cost > 0 and mastery.points_available >= cost then
                        status[r] = "seen"
                        mastery.points_used      = (mastery.points_used or 0) + cost
                        mastery.points_available = mastery.points_available - cost
                        mv._purchased_traits = mv._purchased_traits or {}
                        mv._purchased_traits[#mv._purchased_traits + 1] = {
                            trait_name = tname,
                            rarity     = r,
                            index      = index,
                        }
                        spent_pts   = spent_pts + cost
                        spent_count = spent_count + 1
                        progressed  = true
                        mod:info("[WXF BLS] queued %s rank %d (cost %d, %d pts left)",
                            tostring(tname), r, cost, mastery.points_available)
                    end
                end
            end
        end
    end

    -- Refresh the view so the purchases are visible immediately (same widgets vanilla updates)
    pcall(function()
        mv._widgets_by_name.mastery_points.content.mastery_points_value =
            string.format(" %s", mastery.points_available)
    end)
    pcall(function() mv:_update_traits() end)
    pcall(function() mv:_check_buttons_visibility() end)
    BLS.cached_points = mastery.points_available

    return { count = spent_count, pts = spent_pts, remaining = mastery.points_available }
end

-- Called by the WXF "Spend All" button.
-- Spends all points if the Mastery screen is already open; otherwise tells the user to open it.
function mod.bls_open_mastery_view()
    if BLS.mastery_view then
        mod.bls_start()
        return
    end
    mod:echo(mod:localize("echo_open_mastery_btn"))
end

-- Public entry point called by keybind and WXF button
function mod.bls_start()
    mod:info("[WXF BLS] bls_start called, mv=%s pts=%s",
        tostring(BLS.mastery_view ~= nil), tostring(BLS.cached_points))
    local mv = BLS.mastery_view
    if not mv then
        mod:echo(mod:localize("echo_open_mastery"))
        mod:info("[WXF BLS] bls_start: no mastery view")
        return
    end

    local pts = mod.bls_get_points()
    mod:info("[WXF BLS] bls_start: pts=%s (cached=%s)", tostring(pts), tostring(BLS.cached_points))
    -- No pts<=0 guard: server returns "cannot afford" gracefully, and pts=0 can be a false
    -- negative right after game load before mastery data has arrived from the server.

    local traits_id   = _bls_get_traits_id()
    local traits_list = _bls_get_traits_list()

    if not traits_id then
        mod:echo(mod:localize("echo_select_weapon"))
        mod:info("[WXF BLS] bls_start: no traits_id")
        return
    end
    if not traits_list or #traits_list == 0 then
        mod:echo(mod:localize("echo_no_traits"))
        mod:info("[WXF BLS] bls_start: traits_list empty")
        return
    end

    -- Try to get a human-readable weapon name for the completion echo
    local weapon_name = traits_id
    pcall(function()
        local name = mv._mastery and mv._mastery.name
        if type(name) == "string" and #name > 0 then weapon_name = name end
    end)

    mod:info("[WXF BLS] starting — traits_id=%s  weapon=%s  traits=%d  pts=%s",
        tostring(traits_id), tostring(weapon_name), #traits_list, tostring(pts))

    -- Instant local spend, exactly like clicking each blessing by hand.
    local result, err = _bls_spend_all_local(mv)
    if not result then
        mod:echo(mod:localize("echo_cannot_spend_fmt", tostring(err)))
        mod:info("[WXF BLS] local spend failed: %s", tostring(err))
        return
    end
    mod.flog("RESULT", "Blessing spend: %d blessing(s) queued for %d point(s), %d point(s) remaining",
        result.count, result.pts, result.remaining)
    if result.count > 0 then
        mod:echo(mod:localize("echo_spent_fmt", result.count, result.pts, result.remaining))
    else
        mod:echo(mod:localize("echo_nothing_fmt", result.remaining))
    end
end

-- ── Chat state tracking ──────────────────────────────────────────────────────
-- Polled once per frame in mod.update so toggle_menu (and anything else) can
-- check a plain boolean instead of calling into Managers.ui every time, and so
-- we get a log line the moment chat opens/closes.
local _chat_open = false

local function _is_chat_open()
    local ui = Managers.ui
    if not ui then return false end
    local ok, result = pcall(function() return ui:chat_using_input() end)
    return ok and result or false
end

-- ── View helpers ───────────────────────────────────────────────────────────────

mod.toggle_menu = function()
    mod:info("[WXF] toggle_menu called.")
    if _chat_open then
        mod.flog("USER", "Open Menu Key pressed while chat is open — ignored")
        mod:info("[WXF] toggle_menu ignored — chat is open")
        return
    end
    local ui = Managers.ui
    if not ui then return end
    local ok, err = pcall(function()
        if ui:view_instance(VIEW_NAME) then
            ui:close_view(VIEW_NAME)
        else
            ui:open_view(VIEW_NAME, nil, nil, nil, nil, nil)
        end
    end)
    if not ok then mod:error("[WXF] toggle_menu error: %s", tostring(err)) end
end

mod.on_enabled  = function() end
mod.on_disabled = function()
    local ui = Managers.ui
    if ui and ui:view_instance(VIEW_NAME) then ui:close_view(VIEW_NAME) end
end

-- ── Open Menu Key logging ────────────────────────────────────────────────────
-- The setting stores the binding as a list of local key names, e.g. {"l"} or
-- {"left ctrl", "l"}. Format it into a readable "left ctrl + l" style string.
local function _format_key_binding(keys)
    if type(keys) ~= "table" or #keys == 0 then return "(unbound)" end
    return table.concat(keys, " + ")
end

mod.on_setting_changed = function(setting_id)
    if setting_id == "open_key" then
        mod.flog("SESSION", "Open Menu Key rebound -> %s",
            _format_key_binding(mod:get("open_key")))
        mod:info("[WXF] Open Menu Key rebound -> %s", _format_key_binding(mod:get("open_key")))
    end
end

-- ── update ─────────────────────────────────────────────────────────────────────

local _logged_open_key = false

function mod.update(dt)
    if not _logged_open_key then
        -- Deferred to the first update tick so DMF has finished applying the
        -- setting's default value before we read it.
        _logged_open_key = true
        mod.flog("SESSION", "Open Menu Key bound to: %s", _format_key_binding(mod:get("open_key")))
        mod:info("[WXF] Open Menu Key bound to: %s", _format_key_binding(mod:get("open_key")))
    end

    -- Track chat open/close so toggle_menu can ignore the bind key while typing.
    do
        local now_open = _is_chat_open()
        if now_open ~= _chat_open then
            _chat_open = now_open
            mod.flog("SESSION", "Chat input %s", _chat_open and "opened" or "closed")
            mod:info("[WXF] chat input %s", _chat_open and "opened" or "closed")
        end
    end

    -- ── Phase 0 ────────────────────────────────────────────────────────────────
    if _nav_timer > 0 and _nav_view then
        _nav_timer = _nav_timer - dt
        if _nav_timer <= 0 then
            if mod._pending_sacrifice then
                local still_transitioning = false
                pcall(function()
                    still_transitioning = _nav_view.transitioning_in == true
                end)
                if still_transitioning then
                    mod:info("[WXF] CraftingView still transitioning_in, wait 0.1s")
                    _nav_timer = 0.1
                else
                    mod:info("[WXF] nav delay done, clicking sacrifice option")
                    local ok = false
                    pcall(function() ok = _nav_to_sacrifice(_nav_view) end)
                    if ok then
                        _sacrifice_view    = _nav_view
                        _sacrifice_timer   = _SACRIFICE_DELAY
                        _sacrifice_retries = 0
                        mod:info("[WXF] sacrifice panel poll in %.1fs", _SACRIFICE_DELAY)
                    end
                    _nav_view = nil
                end
            else
                _nav_view = nil
            end
        end
    end

    -- ── Phase 1 ────────────────────────────────────────────────────────────────
    if _sacrifice_timer > 0 and _sacrifice_view then
        _sacrifice_timer = _sacrifice_timer - dt
        if _sacrifice_timer <= 0 then
            _sacrifice_timer = 0
            if mod._pending_sacrifice then
                local pending = mod._pending_sacrifice
                local found   = false
                pcall(function()
                    found = _try_access_sacrifice_panel(_sacrifice_view, pending)
                end)
                if found then
                    mod._pending_sacrifice = nil
                    mod:info("[WXF] sacrifice panel access done")
                else
                    _sacrifice_retries = _sacrifice_retries + 1
                    local elapsed = _SACRIFICE_DELAY + _sacrifice_retries
                    if elapsed < _SACRIFICE_TIMEOUT then
                        if _sacrifice_retries == 1 then
                            local view_exists = false
                            pcall(function()
                                local ui = Managers.ui
                                if ui then
                                    view_exists = ui:view_instance(SACRIFICE_VIEW_NAME) ~= nil
                                end
                            end)
                            if not view_exists then
                                pcall(function() _nav_to_sacrifice(_sacrifice_view) end)
                                mod:info("[WXF] re-nav triggered (view missing)")
                            else
                                mod:info("[WXF] view present, waiting for patterns...")
                            end
                        end
                        _sacrifice_timer = 0.2
                        mod:info("[WXF] retry %d/%d in 0.2s",
                            _sacrifice_retries, _SACRIFICE_TIMEOUT - 1)
                    else
                        mod._pending_sacrifice = nil
                        mod:info("[WXF] sacrifice panel timed out after %d retries",
                            _sacrifice_retries)
                    end
                end
            end
            if _sacrifice_timer <= 0 then
                _sacrifice_view = nil
            end
        end
    end

    -- ── Phases 2-3 ─────────────────────────────────────────────────────────────
    if _auto_timer > 0 and _auto_view then
        _auto_timer = _auto_timer - dt
        if _auto_timer <= 0 then
            _auto_timer = 0
            local view_self = _auto_view

            if _auto_phase == "select" then
                local still_trans = false
                pcall(function() still_trans = view_self.transitioning_in == true end)
                if still_trans then
                    _auto_retries = _auto_retries + 1
                    mod:info("[WXF] select: still animating (retry %d), wait 0.2s", _auto_retries)
                    _auto_timer = 0.2
                else
                    pcall(function()
                        local cw = view_self._widgets_by_name
                                   and view_self._widgets_by_name["confirm_button"]
                        if cw then
                            local hs = cw.content and cw.content.hotspot
                            mod:info("[WXF] confirm_button pressed_callback=%s",
                                hs and tostring(hs.pressed_callback) or "nil")
                        end
                    end)
                    local pending = { weapon_pattern = _auto_pattern, gear_ids = _auto_ids }
                    _auto_phase = nil
                    _try_select_items(view_self, pending)
                    if _auto_phase ~= "confirm" then
                        mod:info("[WXF] select: pattern not selected, aborting")
                        _auto_view = nil; _auto_ids = nil
                        _auto_phase = nil; _auto_pattern = nil; _auto_retries = 0
                    else
                        _auto_pattern = nil
                        mod:info("[WXF] select done, confirm in %.1fs", _auto_timer)
                    end
                end

            elseif _auto_phase == "confirm" then
                local still_trans = false
                pcall(function() still_trans = view_self.transitioning_in == true end)
                if still_trans then
                    _auto_retries = _auto_retries + 1
                    mod:info("[WXF] confirm: still animating (retry %d), wait 0.2s", _auto_retries)
                    _auto_timer = 0.2
                else
                    -- Try button closure first, fallback to _confirm_pressed
                    local ok = false
                    pcall(function()
                        local cw = view_self._widgets_by_name
                                   and view_self._widgets_by_name["confirm_button"]
                        if cw then
                            local hs = cw.content and cw.content.hotspot
                            if type(hs) == "table" and type(hs.pressed_callback) == "function" then
                                hs.pressed_callback()
                                ok = true
                                mod:info("[WXF] confirm_button closure -> OK")
                            end
                        end
                    end)
                    if not ok then
                        local ok2, err2 = pcall(function() view_self:_confirm_pressed() end)
                        ok = ok2
                        mod:info("[WXF] _confirm_pressed fallback -> %s",
                            ok2 and "OK" or tostring(err2))
                    end
                    if ok and _auto_ids and #_auto_ids > 0 then
                        _auto_phase = "mark"; _auto_timer = 0.3; _auto_retries = 0
                        mod:info("[WXF] item marking scheduled in 0.3s")
                    else
                        _auto_view = nil; _auto_ids = nil
                        _auto_phase = nil; _auto_retries = 0
                    end
                end

            elseif _auto_phase == "mark" then
                local ui_state = nil
                pcall(function() ui_state = view_self._ui_state end)
                local in_weapon_state = (ui_state == "select_weapon")
                if not in_weapon_state then
                    _auto_retries = _auto_retries + 1
                    mod:info("[WXF] mark: state=%s (retry %d), wait 0.2s",
                        tostring(ui_state), _auto_retries)
                    if _auto_retries % 6 == 0 then
                        pcall(function()
                            local cw = view_self._widgets_by_name
                                       and view_self._widgets_by_name["confirm_button"]
                            local called = false
                            if cw then
                                local hs = cw.content and cw.content.hotspot
                                if type(hs) == "table" and type(hs.pressed_callback) == "function" then
                                    hs.pressed_callback()
                                    called = true
                                    mod:info("[WXF] mark: re-tried confirm closure")
                                end
                            end
                            if not called then
                                view_self:_confirm_pressed()
                                mod:info("[WXF] mark: re-tried _confirm_pressed")
                            end
                        end)
                    end
                    _auto_timer = 0.2
                else
                    local gear_ids = _auto_ids
                    _auto_view = nil; _auto_ids = nil
                    _auto_phase = nil; _auto_retries = 0
                    if type(view_self._mark_items_to_sell) == "function" then
                        local items = {}
                        for _, gid in ipairs(gear_ids) do
                            items[#items + 1] = { gear_id = gid }
                        end
                        local ok, err = pcall(function()
                            view_self:_mark_items_to_sell(items)
                        end)
                        mod:info("[WXF] _mark_items_to_sell (%d items) -> %s",
                            #items, ok and "OK" or tostring(err))
                        -- After marking, watch for the sacrifice to complete so we
                        -- can re-select the correct weapon type in the pattern panel.
                        if ok then
                            -- Remove sacrificed gear_ids from cache so the next inventory
                            -- scan doesn't reuse ids that are now gone from the player's inventory.
                            for _, item in ipairs(items) do
                                if item.gear_id and mod._weapon_cache then
                                    mod._weapon_cache[item.gear_id] = nil
                                end
                            end
                            mod:info("[WXF] cleared %d sacrificed items from weapon cache", #items)
                            _reselect_view    = view_self
                            _reselect_timer   = 0.5
                            _reselect_retries = 0
                            mod:info("[WXF] reselect watcher armed for pattern '%s'",
                                tostring(_reselect_pattern))
                        end
                    else
                        mod:info("[WXF] _mark_items_to_sell not available")
                    end
                end

            end
        end
    end

    -- ── Phase 4: re-select pattern after sacrifice completes ──────────────────
    -- Two-pass strategy because the game resets to Shivs (first pattern) when
    -- the sacrifice API response arrives, AFTER the _ui_state has already
    -- changed away from "select_weapon".
    --
    -- Phase 4a: poll until _ui_state != "select_weapon" → first re-select.
    -- Phase 4b: 2.5 s later → second re-select that catches the post-API reset.
    --           (_reselect_retries == -1 is the sentinel for phase 4b)
    if _reselect_timer > 0 and _reselect_view then
        _reselect_timer = _reselect_timer - dt
        if _reselect_timer <= 0 then
            _reselect_timer = 0
            local view_self = _reselect_view
            local pattern   = _reselect_pattern

            local function _do_reselect(label)
                if not pattern then return end
                pcall(function()
                    local patterns_layout = view_self._patterns_layout
                    if type(patterns_layout) ~= "table" or #patterns_layout == 0 then
                        mod:info("[WXF] reselect[%s]: patterns_layout not ready", label); return
                    end
                    local matched = nil
                    for _, entry in ipairs(patterns_layout) do
                        if entry.mastery_id == pattern then matched = entry; break end
                    end
                    if not matched then
                        mod:info("[WXF] reselect[%s]: pattern '%s' not found", label, tostring(pattern))
                        return
                    end
                    local matched_widget = nil
                    pcall(function()
                        local widgets = view_self._patterns_grid:widgets()
                        for _, w in ipairs(widgets) do
                            local elem = w.content and w.content.element
                            if elem and elem.mastery_id == pattern then matched_widget = w; break end
                        end
                    end)
                    local ok, err = pcall(function()
                        view_self:cb_pattern_on_grid_entry_left_pressed(matched_widget, matched)
                    end)
                    mod:info("[WXF] reselect[%s] '%s' -> %s", label, tostring(pattern),
                        ok and "OK" or tostring(err))
                    _auto_view = nil; _auto_ids = nil; _auto_phase = nil
                    _auto_timer = 0; _auto_retries = 0
                end)
            end

            if _reselect_retries < 0 then
                -- ── Phase 4b: rapid follow-up polling after Phase 4a ──
                -- Re-select every 0.3 s (up to 10 times = 3 s coverage).
                -- This catches the post-API-response reset nearly instantly,
                -- regardless of server latency.
                _do_reselect("4b")
                if _reselect_retries > -10 then
                    _reselect_retries = _reselect_retries - 1
                    _reselect_timer   = 0.3
                else
                    _reselect_view = nil; _reselect_pattern = nil; _reselect_retries = 0
                end

            else
                local ui_state = nil
                pcall(function() ui_state = view_self._ui_state end)

                if ui_state == "select_weapon" then
                    -- Still waiting for the user to click SACRIFICE / API to complete
                    _reselect_retries = _reselect_retries + 1
                    if _reselect_retries < 120 then   -- ~60 s timeout
                        _reselect_timer = 0.5
                    else
                        mod:info("[WXF] reselect: timed out waiting for sacrifice")
                        _reselect_view = nil; _reselect_pattern = nil; _reselect_retries = 0
                    end
                else
                    -- ── Phase 4a: state changed, do first re-select then start rapid polling ──
                    _do_reselect("4a")
                    _reselect_view    = view_self
                    _reselect_pattern = pattern
                    _reselect_timer   = 0.3   -- first rapid follow-up
                    _reselect_retries = -1    -- enter phase 4b loop
                end
            end
        end
    end
end
