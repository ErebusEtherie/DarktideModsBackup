-- route_view.lua
--
-- What you see when you press the interact key at the terminal: the route you are about
-- to walk, with the option to reroll it or commit to it.
--
-- ===========================================================================
-- WHY THIS FILE REACHES BACK THROUGH THE MOD OBJECT
-- ===========================================================================
--
-- Same reason as terminal_hud.lua. DMF registers the view by class name and file path,
-- and the GAME constructs the object when the view opens. There is no constructor call
-- of ours to inject dependencies into.
--
-- Rather than let the view rummage through mod._modules and couple itself to the whole
-- mod, bootstrap builds a small purpose-made table, mod.pilgrimage_route_api, holding
-- exactly the four things this view needs. If a fifth is ever needed it gets added
-- there deliberately, which keeps the surface visible in one place instead of growing
-- quietly through a dozen call sites.
--
-- ===========================================================================
-- LIFECYCLE
-- ===========================================================================
--
--   on_enter          the game has created the view and it is now on screen. Widgets
--                     exist by this point, so this is where we wire button callbacks
--                     and fill in the route.
--   update            once per frame while open.
--   on_exit           closing. Anything we allocated gets dropped here.
--
-- BaseView draws every widget in the definitions for us, so there is no draw function
-- below. That is the whole benefit of building on it rather than on a bare class.

local mod = get_mod("Pilgrimage")

local Definitions = mod:io_dofile("Pilgrimage/scripts/mods/Pilgrimage/route_view_definitions")

local PilgrimageRouteView = class("PilgrimageRouteView", "BaseView")

local MAX_LEG_ROWS = Definitions.MAX_LEG_ROWS
local PICK_NONE = "__pilgrimage_pick_none"

-- Fatshark's internal archetype ids are stable data keys, while these
-- labels are the names players recognize. The order matches character
-- creation and keeps every class section in a predictable position.
local LEGENDARY_SECTIONS = {
	{ id = "veteran", label = "Veteran" },
	{ id = "zealot",  label = "Zealot" },
	{ id = "psyker",  label = "Psyker" },
	{ id = "ogryn",   label = "Ogryn" },
	{ id = "adamant", label = "Arbites" },
	{ id = "broker",  label = "Hive Scum" },
	{ id = "cryptic", label = "Skitarii" },
}
local LEGENDARY_SECTION_LABEL = {}
for i = 1, #LEGENDARY_SECTIONS do
	LEGENDARY_SECTION_LABEL[LEGENDARY_SECTIONS[i].id] = LEGENDARY_SECTIONS[i].label
end

-- ---------------------------------------------------------------------------

PilgrimageRouteView.init = function(self, settings, context)
	PilgrimageRouteView.super.init(self, Definitions, settings, context)

	-- The route currently on display. Held here and not in run state, because nothing is
	-- committed until Begin is pressed: rerolling ten times must leave no trace.
	self._route = nil
	self._curses = nil
	self._seed = 0
	self._committed = false
	self._mode = "route"
	self._draft = nil
	self._draft_only = context and context.draft_only == true or false
	self._realm_refresh_t = 0
end

PilgrimageRouteView.on_enter = function(self)
	PilgrimageRouteView.super.on_enter(self)

	local widgets = self._widgets_by_name

	-- callback(self, "_method_name") is the game's own helper for binding a method to a
	-- widget. It produces a function that calls the method with self as the first
	-- argument, which a plain function reference would not do.
	widgets.reroll_button.content.hotspot.pressed_callback = callback(self, "_on_reroll_pressed")
	widgets.begin_button.content.hotspot.pressed_callback  = callback(self, "_on_begin_pressed")
	widgets.close_button.content.hotspot.pressed_callback  = callback(self, "_on_close_pressed")
	-- v0.22.51 (Session H): opens the War Plan picker (a preset_pick-style
	-- modal on top of the Route tab). Guarded inside the handler so a
	-- press mid-run is a no-op instead of a plan switch.
	if widgets.plan_button and widgets.plan_button.content and widgets.plan_button.content.hotspot then
		widgets.plan_button.content.hotspot.pressed_callback = callback(self, "_on_plan_button_pressed")
	end

	for i = 1, 3 do
		widgets["boon_" .. i].content.hotspot.pressed_callback =
			callback(self, "_on_boon_pressed", i)
	end

	-- v0.22.31: tab bar. Each tab flips self._tab and calls
	-- _refresh_mode, which dispatches on the tab plus any pending draft
	-- (drafts still override so the boon-pick screen doesn't fall behind
	-- the terminal shell).
	for i = 1, Definitions.TAB_COUNT do
		widgets["tab_" .. i].content.hotspot.pressed_callback =
			callback(self, "_on_tab_pressed", i)
	end

	-- v0.22.31: rows are now clickable. In Party mode a click cycles
	-- that slot's preset; in Emporium mode it buys the SKU. Route mode
	-- ignores the click (dispatch happens in _on_row_pressed).
	for i = 1, MAX_LEG_ROWS do
		widgets["row_" .. i].content.hotspot.pressed_callback =
			callback(self, "_on_row_pressed", i)
	end

	-- Default tab is Route. Preserved across a close/reopen would need
	-- persistent state; not worth it, opening the terminal is a
	-- deliberate act and starting on Route (the most-used view) is the
	-- right default every time.
	self._tab = 1
	self:_refresh_mode()
end

PilgrimageRouteView.on_exit = function(self)
	self._route = nil
	PilgrimageRouteView.super.on_exit(self)
end

-- ---------------------------------------------------------------------------
-- Route handling
-- ---------------------------------------------------------------------------

local function _api()
	return mod.pilgrimage_route_api
end

-- ---------------------------------------------------------------------------
-- Mode
--
-- An unresolved draft replaces the Route page, not the other terminal tabs.
-- The offer is preserved while inspecting or changing the warband/loadout.
-- ---------------------------------------------------------------------------

PilgrimageRouteView._refresh_mode = function(self)
	local api = _api()
	local tab_mode = Definitions.TAB_MODES[self._tab or 1] or "route"
	if self._draft_only then tab_mode = "route" end
	local draft = tab_mode == "route" and api and api.pending_draft and api.pending_draft() or nil

	-- Continue remains unavailable until the offer is accepted or declined,
	-- but switching tabs neither resolves the debt nor consumes a reward.
	if draft and #draft > 0 then
		self._mode = "draft"
		self._draft = draft
		self:_refresh_tab_bar()
		self:_refresh_balance()
		self:_refresh_draft()
		return
	end

	self._draft = nil
	-- Mission offers may never fall through into the hub terminal after
	-- their debt disappears. Normal hub/training terminal tabs stay available.
	if self._draft_only then
		self:_on_close_pressed()
		return
	end

	self._mode = tab_mode
	self:_refresh_tab_bar()
	self:_refresh_balance()

	if tab_mode == "realm" then
		self:_refresh_realm()
	elseif tab_mode == "party" then
		self:_refresh_party()
	elseif tab_mode == "shop" then
		self:_refresh_shop()
	elseif tab_mode == "penances" then
		-- v0.22.77 (Session B phase 2)
		self:_refresh_penances()
	elseif tab_mode == "loadout" then
		-- v0.22.81 (Boon Loadout)
		self:_refresh_loadout()
	else
		self:_load_or_generate()
	end
end

-- ---------------------------------------------------------------------------
-- Realm tab
--
-- Read-only mirror of Realms' human roster. Joining, leaving, loadouts and final
-- ready state remain Realms' job; this panel explains how those humans occupy
-- Pilgrimage seats and whether their exact internal build passed the handshake.
-- ---------------------------------------------------------------------------

PilgrimageRouteView._refresh_realm = function(self)
	local widgets = self._widgets_by_name
	local api = _api()
	local realm = api and api.realm or nil

	self:_set_list_visible(true, false)
	widgets.title.content.text = "REALM PARTY"
	widgets.title.dirty = true
	widgets.reroll_button.visible = false
	widgets.reroll_button.dirty = true
	widgets.begin_button.visible = false
	widgets.begin_button.dirty = true
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end

	local installed = realm and realm.installed and realm.installed() or false
	local active = realm and realm.active and realm.active() or false
	local role = realm and realm.role and realm.role() or "none"
	local host_name = realm and realm.host_name and realm.host_name() or "Realm host"
	local slots = realm and realm.guest_slots and realm.guest_slots() or {}

	if not installed then
		widgets.subtitle.content.text =
			"Realms 0.5.1 is not loaded. Solo Pilgrimage is unchanged."
	elseif not active then
		widgets.subtitle.content.text =
			"The Realm opens after Begin or Continue. Players join and ready up in Realms' preparation screen."
	else
		widgets.subtitle.content.text = string.format(
			"Host: %s. Three guest seats mirror the active Realm. You are the %s.",
			tostring(host_name), role)
	end
	widgets.subtitle.dirty = true

	for i = 1, MAX_LEG_ROWS do
		local widget = widgets["row_" .. i]
		if i <= 3 then
			local entry = slots[i] or { occupied = false, status = "open" }
			widget.visible = true
			widget.content.index = "Player " .. tostring(i + 1)
			widget.style.curse_icon.visible = false
			widget.style.index.text_color = { 255, 255, 226, 168 }
			if not active then
				widget.content.name = installed and "Opens after launch" or "Unavailable"
				widget.content.condition = ""
				widget.content.status = ""
				widget.style.name.text_color = { 255, 110, 110, 110 }
				widget.style.condition.text_color = { 255, 110, 110, 110 }
			elseif entry.occupied then
				widget.content.name = entry.name or "Connected player"
				if entry.status == "compatible" then
					widget.content.condition = "Pilgrimage v" .. tostring(entry.version or "?")
					widget.content.status = "synchronized"
					widget.style.name.text_color = { 255, 219, 219, 219 }
					widget.style.condition.text_color = { 255, 170, 220, 170 }
				elseif entry.status == "incompatible" then
					widget.content.condition = tostring(entry.reason or "incompatible build")
					widget.content.status = "rejected"
					widget.style.name.text_color = { 255, 230, 120, 100 }
					widget.style.condition.text_color = { 255, 230, 120, 100 }
				else
					widget.content.condition = tostring(entry.reason or "checking version")
					widget.content.status = "checking"
					widget.style.name.text_color = { 255, 219, 219, 219 }
					widget.style.condition.text_color = { 255, 255, 226, 168 }
				end
			else
				widget.content.name = "Open guest seat"
				widget.content.condition = "Bot slot " .. tostring(i) .. " remains available"
				widget.content.status = "open"
				widget.style.name.text_color = { 255, 150, 150, 150 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			end
			widget.dirty = true
		else
			widget.visible = false
			widget.dirty = true
		end
	end

	local rules = realm and realm.rules and realm.rules() or {}
	widgets.footer.content.text = string.format(
		"Host rules: Weapon Rebalance %s   |   Cheat Mode %s   |   Exact internal Pilgrimage version required",
		rules.custom_weapon_balancing and "ON" or "OFF",
		rules.cheat_mode and "ON" or "OFF")
	widgets.footer.visible = active
	widgets.footer.dirty = true
end

-- Redraw the tab strip. The active tab gets a highlight colour; the
-- others fall back to the default text colour that the button template
-- already draws. Done by overwriting original_text_color rather than by
-- swapping textures, because the terminal_button template exposes that
-- one field and nothing else this shape reaches without a
-- change_function.
PilgrimageRouteView._refresh_tab_bar = function(self)
	local widgets = self._widgets_by_name
	local active_index = self._mode == "draft" and 1 or self._tab

	for i = 1, Definitions.TAB_COUNT do
		local widget = widgets["tab_" .. i]
		if widget then
			widget.visible = not self._draft_only
			if widget.content and widget.content.hotspot then
				widget.content.hotspot.disabled = self._draft_only == true
			end
			-- Highlight the active tab, dim the others.
			--
			-- v0.22.33: writing text_color used to no-op because the
			-- terminal_button_small template runs a change_function
			-- every frame that lerps default_color -> hover_color into
			-- text_color, overwriting whatever we wrote. Write
			-- default_color instead; the change function reads that as
			-- its base and our value survives the lerp.
			local text_style = widget.style and widget.style.text
			if text_style then
				local active   = { 255, 255, 226, 168 }
				local inactive = { 255, 150, 150, 150 }
				local target = i == active_index and active or inactive
				text_style.default_color = target
			end
			widget.dirty = true
		end
	end
end

-- The Ordos balance readout lives in the Emporium tab only. On other
-- tabs the widget is invisible; on Emporium it shows "Ordos: N" in the
-- top-right of the tab bar strip.
PilgrimageRouteView._refresh_balance = function(self)
	local widgets = self._widgets_by_name
	local widget = widgets.balance_label
	if not widget then return end

	-- v0.22.81: the Loadout tab spends Ordos too, so it shows the
	-- balance alongside the Emporium. v0.22.82: and the boon picker,
	-- where unowned boons are bought.
	if self._mode == "shop" or self._mode == "loadout" or self._mode == "boon_pick" or self._mode == "ban_pick" then
		local api = _api()
		local shop = api and api.shop or nil
		local balance = shop and shop.balance and shop.balance() or 0
		widget.content.text = "Ordos: " .. tostring(balance)
		widget.visible = true
	else
		widget.visible = false
	end
	widget.dirty = true
end

PilgrimageRouteView._on_tab_pressed = function(self, index)
	if self._draft_only then return end
	if not index or index < 1 or index > Definitions.TAB_COUNT then return end
	self._tab = index
	-- v0.22.77: entering the Penances tab always starts at page 1 with
	-- no penance inspected, so a stale page from a previous visit can't
	-- open onto an empty window.
	self._penances_page = 1
	self._penances_inspect = nil
	-- v0.22.82: page resets for the paginated Emporium and boon picker.
	self._shop_page = 1
	self._boon_pick_page = 1
	self._ban_pick_page = 1
	self:_refresh_mode()
end

-- Dispatch a row click to the mode-specific handler. Route mode has no
-- per-row action, so the click is intentionally a no-op there.
PilgrimageRouteView._on_row_pressed = function(self, index)
	if self._mode == "party" then
		self:_on_party_row_pressed(index)
	elseif self._mode == "shop" then
		self:_on_shop_row_pressed(index)
	elseif self._mode == "preset_pick" then
		self:_on_preset_pick_row_pressed(index)
	elseif self._mode == "war_plan_pick" then
		-- v0.22.51 (Session H)
		self:_on_war_plan_row_pressed(index)
	elseif self._mode == "penances" then
		-- v0.22.77 (Session B phase 2)
		self:_on_penances_row_pressed(index)
	elseif self._mode == "loadout" then
		-- v0.22.81 (Boon Loadout)
		self:_on_loadout_row_pressed(index)
	elseif self._mode == "boon_pick" then
		-- v0.22.82 (slot-model boon picker)
		self:_on_boon_pick_row_pressed(index)
	elseif self._mode == "archetype_pick" then
		-- v0.24.1 (archetype picker)
		self:_on_archetype_pick_row_pressed(index)
	elseif self._mode == "legendary_pick" then
		-- v0.25.0 (legendary picker)
		self:_on_legendary_pick_row_pressed(index)
	elseif self._mode == "ban_pick" then
		-- v0.22.89 (writ tier picker)
		self:_on_ban_pick_row_pressed(index)
	end
	-- route mode: rows are read-only.
end

PilgrimageRouteView._set_list_visible = function(self, legs_visible, boons_visible)
	local widgets = self._widgets_by_name

	for i = 1, MAX_LEG_ROWS do
		local widget = widgets["row_" .. i]
		-- v0.22.76: central reset of the picker's section-header state.
		-- Every list-mode refresh passes through here, so a widget that
		-- rendered a header (flat bar, no hover, muted sounds) in the
		-- preset picker always reverts to a normal interactive row
		-- before any other mode draws with it. _refresh_preset_pick
		-- re-applies the header state after this for its header rows.
		if widget.content.pilg_header then
			widget.content.pilg_header = false
			widget.dirty = true
		end
		local hotspot = widget.content.hotspot
		if hotspot then
			hotspot.on_pressed_sound = Definitions.ROW_ON_PRESSED_SOUND
			hotspot.on_hover_sound = Definitions.ROW_ON_HOVER_SOUND
		end
		if widget.visible ~= legs_visible then
			widget.visible = legs_visible
			widget.dirty = true
		end
	end

	for i = 1, 3 do
		local widget = widgets["boon_" .. i]
		if widget.visible ~= boons_visible then
			widget.visible = boons_visible
			widget.dirty = true
		end
	end
end

PilgrimageRouteView._refresh_draft = function(self)
	local widgets = self._widgets_by_name
	local draft = self._draft or {}

	self:_set_list_visible(false, true)

	widgets.title.content.text = "CHOOSE A BOON"
	widgets.title.dirty = true

	widgets.subtitle.content.text = "Choose one. Every other offer is gone."
	widgets.subtitle.dirty = true

	for i = 1, 3 do
		local widget = widgets["boon_" .. i]
		local boon = draft[i]

		if boon then
			widget.visible = true
			widget.content.boon_title = boon.title or boon.name
			widget.content.boon_body = boon.description or ""

			-- Point the icon material at this buff's own art. Guarded because the style
			-- table is built by the definitions file and a missing key here would be a
			-- crash rather than a plain card.
			local icon_style = widget.style and widget.style.boon_icon
			local values = icon_style and icon_style.material_values
			if values then
				-- A bundled SimpleAssets glyph is drawn by the direct texture
				-- layer below. Feed the container its own mask as a solid icon so
				-- the normal Hordes gradient and frame remain behind that glyph.
				values.icon = boon.custom_icon and Definitions.BOON_ICON_MASK
					or boon.icon or Definitions.BOON_ICON_DEFAULT
				values.gradient_map = boon.gradient or Definitions.BOON_GRADIENT_DEFAULT
			end
			local custom_style = widget.style and widget.style.boon_custom_icon
			local custom_values = custom_style and custom_style.material_values
			if custom_values then
				custom_values.texture_map = boon.custom_icon
			end

			-- terminal_button_small draws original_text itself. We draw our own title and
			-- body passes on top, so its own label has to be empty or the two overlap.
			widget.content.original_text = ""
			widget.content.text = ""
		else
			widget.visible = false
		end

		widget.dirty = true
	end

	-- Second Reading is the one explicit exception to immutable drafts. The
	-- route API persists its use before producing replacements, so closing or
	-- crashing the menu cannot roll another set.
	local api = _api()
	local can_reroll = api and api.can_reroll_draft and api.can_reroll_draft() or false
	widgets.reroll_button.visible = can_reroll
	widgets.reroll_button.content.original_text = "SECOND READING"
	widgets.reroll_button.dirty = true
	widgets.begin_button.visible = true
	widgets.begin_button.content.original_text = "REJECT BOON"
	widgets.begin_button.dirty = true

	-- v0.22.51: plan_button hidden in draft mode too (only Route-tab-
	-- pre-run shows it). Guarded because early builds without the
	-- widget still parse.
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end

	widgets.footer.content.text = "Boons last for the whole pilgrimage and are lost when it ends."
	widgets.footer.visible = true
	widgets.footer.dirty = true
end

PilgrimageRouteView._on_boon_pressed = function(self, index)
	if self._mode ~= "draft" then return end

	local draft = self._draft or {}
	local boon = draft[index]
	if not boon then return end

	local api = _api()
	if not api or not api.choose_boon then return end

	api.choose_boon(boon.name)

	-- WHERE YOU ARE DECIDES WHAT HAPPENS NEXT.
	--
	-- In the Mourningstar, fall through to the route so you can see where the boon is
	-- about to be used and press Begin. Taking a boon and looking at the road ahead are
	-- one thought.
	--
	-- In a mission, close. You are standing in a level with the run already underway;
	-- there is nothing to begin, and showing a route screen with a Resume button over a
	-- live mission would be both useless and dangerous to press.
	if api.in_hub and not api.in_hub() then
		self:_on_close_pressed()
		return
	end

	self:_refresh_mode()
end

-- If a run is already going, show it and do not offer to reroll: you cannot reshuffle a
-- pilgrimage you are halfway through. Otherwise generate a fresh route to preview.
PilgrimageRouteView._load_or_generate = function(self)
	local api = _api()
	if not api then
		self:_show_error("Pilgrimage is not fully loaded.")
		return
	end

	local active = api.current and api.current() or nil

	if active and active.active then
		self._route = active.queue
		self._curses = active.curses
		self._seed = active.seed
		self._plan_name = active.plan_name
		self._existing_run = active
		self:_refresh()
		return
	end

	self._existing_run = nil
	self:_generate()
end

PilgrimageRouteView._generate = function(self)
	local api = _api()
	if not api or not api.generate then return end

	local result = api.generate()
	if not result or not result.queue or #result.queue == 0 then
		self:_show_error("Could not generate a route. No playable missions found.")
		return
	end

	self._route = result.queue
	self._curses = result.curses
	self._seed = result.seed
	self._plan_name = result.plan_name
	self:_refresh()
end

-- Pushes the current route into the widgets. Everything visible is set here, so there is
-- exactly one function to read when the display is wrong.
PilgrimageRouteView._refresh = function(self)
	local api = _api()
	local widgets = self._widgets_by_name
	local route = self._route or {}

	self:_set_list_visible(true, false)

	-- v0.19.0: title carries the War Plan name. Falls back to plain
	-- "PILGRIMAGE" when no plan is known (pre-v0.19 run in progress, or
	-- some load-order race where the plan lookup returned nil).
	if type(self._plan_name) == "string" and self._plan_name ~= "" then
		widgets.title.content.text = "PILGRIMAGE   /   " .. self._plan_name
	else
		widgets.title.content.text = "PILGRIMAGE"
	end
	widgets.title.dirty = true

	local existing = self._existing_run
	local current_leg = existing and existing.index or 0

	-- "Assignment", not "leg". Kaizen's call, display text only: internally everything
	-- stays leg/index so no path or key changes.
	widgets.subtitle.content.text = string.format("Seed %d          %d assignments", self._seed or 0, #route)
	widgets.subtitle.dirty = true

	-- run_length allows up to 10 but there are only MAX_LEG_ROWS row widgets. A route
	-- longer than the display must never just stop at row 8, because that would show a
	-- shorter pilgrimage than the one you are about to walk. The last row becomes a
	-- count of what did not fit instead.
	local overflow = #route > MAX_LEG_ROWS and (#route - MAX_LEG_ROWS + 1) or 0
	local last_listed = overflow > 0 and (MAX_LEG_ROWS - 1) or MAX_LEG_ROWS

	-- v0.20.1: fog of war. Ask the shop whether each row is visible right
	-- now. current_leg == 0 pre-run means "show only leg 1" by default.
	-- Scout Ahead purchases push the horizon deeper. See shop.leg_visible
	-- for the exact formula.
	local shop_api = api and api.shop or nil
	local function leg_visible(leg)
		if not shop_api or not shop_api.leg_visible then return true end
		return shop_api.leg_visible(leg, current_leg) == true
	end

	-- v0.20.1: which shop consumables are set right now. The current-leg
	-- row gets a badge for each one so the player can see the buy took
	-- before pressing Continue. Applies to both the current mid-run leg
	-- (the one about to be Continue-launched) and pre-run leg 1 (the
	-- one about to be Begin-launched).
	local skip_active   = shop_api and shop_api.is_active and shop_api.is_active("curse_skip") or false
	local reroll_active = shop_api and shop_api.is_active and shop_api.is_active("curse_reroll") or false
	local target_leg = current_leg > 0 and current_leg or 1

	for i = 1, MAX_LEG_ROWS do
		local widget = widgets["row_" .. i]
		local mission = route[i]

		if overflow > 0 and i == MAX_LEG_ROWS then
			widget.visible = true
			widget.content.index = ""
			widget.content.status = ""
			widget.content.condition = ""
			widget.style.curse_icon.visible = false
			widget.content.name = string.format("and %d more assignments", overflow)
			widget.style.name.text_color = { 255, 150, 150, 150 }
			widget.dirty = true
		elseif mission and i <= last_listed then
			widget.visible = true
			widget.content.index = "Assignment " .. tostring(i)

			local visible = leg_visible(i)

			if not visible then
				-- Fogged. Show only the assignment number and a question
				-- mark; the eye still sees the run's overall LENGTH which
				-- was Kaizen's ask, just not what is IN each unknown leg.
				widget.content.name = "?"
				widget.content.condition = "?"
				widget.content.status = ""
				widget.style.name.text_color = { 255, 130, 130, 130 }
				widget.style.index.text_color = { 255, 150, 150, 150 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
				widget.style.curse_icon.visible = false
				widget.dirty = true
			else
				widget.content.name = api and api.display_name and api.display_name(mission) or tostring(mission)

				-- The leg's curse. v0.20.1: current-leg row also reflects
				-- purchased Skip / Reroll so the player can see the buy
				-- landed before they Continue.
				local curse = self._curses and self._curses[i]
				local curse_label = curse and api and api.curse_name and api.curse_name(curse) or ""
				local severity = curse_label ~= "" and api and api.curse_severity
					and api.curse_severity(curse) or 0

				if i == target_leg and skip_active then
					-- Skip wins over reroll if both are somehow active
					-- (can_buy prevents that in normal play, but a debug
					-- grant could set both).
					widget.content.condition = "-- SKIP purchased --"
					severity = 0
				elseif i == target_leg and reroll_active then
					local new_curse = api and api.curse_after_reroll
						and api.curse_after_reroll(self._seed, i) or nil
					local new_label = new_curse and api and api.curse_name
						and api.curse_name(new_curse) or "?"
					widget.content.condition = "REROLL -> " .. new_label
					severity = new_curse and api and api.curse_severity
						and api.curse_severity(new_curse) or severity
				else
					widget.content.condition = curse_label
				end

				-- Colour by severity: a tier 1 tax stays dim, tier 2 warms to the gold of
				-- the surrounding UI, tier 3 leans red because it is the reason runs end.
				if severity >= 3 then
					widget.style.condition.text_color = { 255, 230, 120, 100 }
				elseif severity == 2 then
					widget.style.condition.text_color = { 255, 255, 226, 168 }
				else
					widget.style.condition.text_color = { 255, 170, 170, 170 }
				end

				-- The circumstance's own icon, drawn only when its material is provably
				-- loaded. Anything short of a confirmed true stays hidden: a missing
				-- material asserts in the renderer, it does not draw a placeholder.
				-- Skip's badge hides the icon (no curse means no icon).
				local icon = curse and api and api.curse_icon and api.curse_icon(curse) or nil
				local icon_ok = icon and api and api.icon_resident
					and api.icon_resident(icon) == true
				if icon_ok and not (i == target_leg and skip_active) then
					widget.content.curse_icon = icon
					widget.style.curse_icon.visible = true
				else
					widget.style.curse_icon.visible = false
				end

				-- Mark where you are in an in-progress run, and dim the legs already behind
				-- you, so the view answers "where am I" as well as "where am I going".
				widget.content.status = ""

				if current_leg > 0 then
					if i < current_leg then
						widget.style.name.text_color = { 255, 110, 110, 110 }
						widget.style.index.text_color = { 255, 110, 110, 110 }
						widget.style.condition.text_color = { 255, 110, 110, 110 }
						widget.content.status = "done"
					elseif i == current_leg then
						widget.style.name.text_color = { 255, 255, 226, 168 }
						widget.style.index.text_color = { 255, 255, 226, 168 }
						widget.content.status = "current"
					else
						widget.style.name.text_color = { 255, 219, 219, 219 }
						widget.style.index.text_color = { 255, 255, 226, 168 }
					end
				end
			end
		else
			widget.visible = false
		end

		widget.dirty = true
	end

	-- Reroll is meaningless once a run has started, so the button goes away rather than
	-- sitting there doing nothing when pressed.
	local can_reroll = existing == nil
	widgets.reroll_button.visible = can_reroll
	widgets.reroll_button.content.original_text = "Reroll route"
	widgets.reroll_button.dirty = true

	-- MUST be re-shown explicitly. The draft screen hides it, and the first version never
	-- turned it back on, so after taking a boon you got a route with no way to act on it.
	-- A widget that another mode hid stays hidden until something says otherwise.
	widgets.begin_button.visible = true
	widgets.begin_button.content.original_text = existing and "Resume pilgrimage" or "Begin pilgrimage"
	widgets.begin_button.dirty = true

	-- v0.20.1: footer hints at fog + scout. If any legs are hidden,
	-- mention the reveal SKU so the player knows how to see further.
	local hidden = 0
	for i = 1, #route do
		if not leg_visible(i) then hidden = hidden + 1 end
	end

	local base = existing
		and "A pilgrimage is already in progress. Failing a leg ends the run."
		or "Missions run back to back. Failing any leg ends the whole pilgrimage."
	if hidden > 0 then
		base = base .. string.format(
			-- v0.22.56: dropped the "(/pil_buy reveal_next)" chat command
			-- hint. The Emporium is a tab in the very same terminal;
			-- pointing users at a chat command reads as a hack. Anyone
			-- reading the hint can just click Emporium and buy Scout
			-- Ahead through the UI.
			"   %d assignment(s) hidden. Buy Scout Ahead at the Emporium to see further.",
			hidden)
	end
	widgets.footer.content.text = base
	-- v0.22.33: restore footer visibility. Party / Emporium hide it to
	-- avoid overlap, so a tab back to Route has to turn it back on.
	widgets.footer.visible = true
	widgets.footer.dirty = true

	-- v0.22.51 (Session H): "Change War Plan" button visible ONLY when
	-- no run is in progress. Mid-run the plan is locked (same reason
	-- Blitz mode is locked at run start) — switching plans mid-run
	-- would leave the queue and difficulty ramp inconsistent, and every
	-- consumer of `plan_id` would need to handle both the old and the
	-- new plan. Simpler: no switch mid-run.
	if widgets.plan_button then
		widgets.plan_button.visible = (existing == nil)
		widgets.plan_button.dirty = true
	end
end

-- ---------------------------------------------------------------------------
-- Party tab
--
-- One row per bot slot. Left click cycles that slot's preset forward.
-- Locked slots (past bots.slot_count) render as greyed rows saying how
-- to unlock the next one, so the terminal answers "why can't I bind
-- another bot" without the user leaving to check chat commands.
-- ---------------------------------------------------------------------------

-- Build a display label for a slot given its binding. Nil is a legacy
-- unbound slot and is now empty, exactly like the explicit None binding.
-- Kept in this file rather than the API because the format is a view
-- concern: another view could show it differently.
local function _party_binding_identity(binding_id, presets)
	if not binding_id or binding_id == "" then
		return "Empty (no bot)", ""
	end
	-- v0.22.75: None binding — the slot stays deliberately empty and
	-- spawns no bot at all.
	if binding_id == "none" then
		return "Empty (no bot)", ""
	end
	for i = 1, #presets do
		if presets[i].id == binding_id then
			return presets[i].display_name,
				presets[i].role_designation or ""
		end
	end
	return binding_id, ""
end

PilgrimageRouteView._refresh_party = function(self)
	local widgets = self._widgets_by_name
	local api = _api()
	local party = api and api.party or nil

	self:_set_list_visible(true, false)

	widgets.title.content.text = "PARTY"
	widgets.title.dirty = true

	if not party then
		widgets.subtitle.content.text = "Party API not loaded. Report this."
		widgets.subtitle.dirty = true
		return
	end

	local slot_count = party.slot_count and party.slot_count() or 0
	local max_slots  = party.max_slots  and party.max_slots()  or 6
	local presets    = party.presets    and party.presets()    or {}
	local realm = api and api.realm or nil
	local realm_role = realm and realm.role and realm.role() or "none"
	local realm_client = realm_role == "client"

	widgets.subtitle.content.text = realm_client
		and "The Realm host owns the bot roster. Occupied human seats are mirrored here."
		or string.format("%d of %d slots active. Click a slot to choose its preset.",
			slot_count, max_slots)
	widgets.subtitle.dirty = true

	-- Buttons that make no sense here are hidden. Begin and Reroll
	-- belong to Route; leaving them visible would suggest they'd act
	-- on the party (they don't).
	widgets.reroll_button.visible = false
	widgets.reroll_button.dirty = true
	widgets.begin_button.visible = false
	widgets.begin_button.dirty = true
	-- v0.22.51: plan_button is Route-tab-only. Same reasoning.
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end

	for i = 1, MAX_LEG_ROWS do
		local widget = widgets["row_" .. i]

		if i <= max_slots then
			widget.visible = true
			widget.content.index = "Slot " .. tostring(i)
			widget.content.status = ""
			widget.style.curse_icon.visible = false

			local human = party.human_occupant and party.human_occupant(i) or nil
			if human then
				-- Human occupancy is an in-memory overlay. The saved bot binding is
				-- deliberately left alone and becomes usable again when the guest leaves.
				widget.content.name = "Bot - Off"
				widget.content.condition = "Occupied by " .. tostring(human.name or "Realm player")
				widget.content.status = "player active"
				widget.style.name.text_color = { 255, 110, 110, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 110, 110, 110 }
			elseif realm_client then
				-- The host's actual bot profiles are synchronized by the game when
				-- they spawn. Until Pilgrimage has a full preparation snapshot, do
				-- not show or edit this client's unrelated saved companion bindings.
				widget.content.name = "Host-managed bot seat"
				widget.content.condition = "Preset chosen by Realm host"
				widget.content.status = "locked"
				widget.style.name.text_color = { 255, 150, 150, 150 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 110, 110, 110 }
			elseif i <= slot_count then
				-- Unlocked. The companion name remains in the widest column,
				-- while the public role tells players what that authored name
				-- actually represents. The interaction hint now uses the row's
				-- dedicated status column instead of displacing the role.
				local binding = party.binding_for_slot and party.binding_for_slot(i) or nil
				local display_name, role_designation =
					_party_binding_identity(binding, presets)
				widget.content.name = display_name
				widget.content.condition = role_designation
				widget.content.status = "click to swap"
				widget.style.name.text_color = { 255, 219, 219, 219 }
				widget.style.index.text_color = { 255, 255, 226, 168 }
				widget.style.condition.text_color = { 255, 150, 150, 150 }
			else
				-- Locked. Grey everything and label how to unlock.
				-- All expansion slots are now Penance rewards. Legacy
				-- third/fourth-slot purchases are still honored invisibly.
				widget.content.name = "Locked"
				local slot_penance = {
					[2] = "First Recruit",
					[3] = "Second Recruit",
					[4] = "Sanctioned",
					[5] = "Full Muster",
					[6] = "Emperor Sends Six",
				}
				widget.content.condition = slot_penance[i] or "unlock via penance"
				widget.style.name.text_color = { 255, 110, 110, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 110, 110, 110 }
			end
			widget.dirty = true
		else
			widget.visible = false
			widget.dirty = true
		end
	end

	-- v0.22.33: hide the footer in Party. It sits at panel bottom -120
	-- which lands ON TOP of row 8 with 8 rows visible; user reported
	-- the "consumables die..." text (from the previous shop draw) was
	-- painted over the last shop row. Rather than reflow the panel,
	-- the two new tabs simply skip the footer, since neither has a
	-- one-line summary that earns the collision.
	widgets.footer.visible = false
	widgets.footer.dirty = true
end

PilgrimageRouteView._on_party_row_pressed = function(self, index)
	local api = _api()
	local party = api and api.party or nil
	if not party then return end
	local realm = api and api.realm or nil
	if realm and realm.role and realm.role() == "client" then return end

	local slot_count = party.slot_count and party.slot_count() or 0
	if index < 1 or index > slot_count then return end -- locked or off-list
	if party.human_occupant and party.human_occupant(index) then return end

	-- v0.22.33: was cycle-through, now open a picker. Kaizen's
	-- feedback: cycling is fine for two options (default / Argenta),
	-- terrible past three because you can't jump to the one you want
	-- and you don't see what's coming. Enter preset_pick mode with the
	-- slot number stashed on self; the picker's row-click binds and
	-- flips back to the party tab.
	self._party_pick_slot = index
	-- v0.22.75: the picker paginates now (tier-grouped list outgrew
	-- the 8-row widget pool); always open on page 1.
	self._pick_page = 1
	self._mode = "preset_pick"
	self:_refresh_tab_bar()
	self:_refresh_balance()
	self:_refresh_preset_pick()
end

-- ---------------------------------------------------------------------------
-- Preset picker (transient mode entered from a Party row)
--
-- Not a separate tab: it's an in-panel modal-ish list, same widget
-- family as the Party rows. Click a preset row to bind and return;
-- press Close to cancel without binding.
-- ---------------------------------------------------------------------------

PilgrimageRouteView._refresh_preset_pick = function(self)
	local widgets = self._widgets_by_name
	local api = _api()
	local party = api and api.party or nil
	local slot = self._party_pick_slot

	self:_set_list_visible(true, false)

	widgets.title.content.text = string.format("PARTY / SLOT %d", slot or 0)
	widgets.title.dirty = true
	widgets.subtitle.content.text = "Choose a preset. Close (X) to cancel."
	widgets.subtitle.dirty = true

	widgets.reroll_button.visible = false
	widgets.reroll_button.dirty = true
	widgets.begin_button.visible = false
	widgets.begin_button.dirty = true
	widgets.footer.visible = false
	widgets.footer.dirty = true
	-- v0.22.51
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end

	local presets = party and party.presets and party.presets() or {}

	-- v0.22.75 (Session I): tier-grouped picker. Kaizen's spec
	-- (2026-08-09): sort as Iconic (T4) / Heroes (T3) / Champions (T2)
	-- / Living Tithe (T1), highest first, each under a non-clickable
	-- section-header row; within a group, unlocked presets first,
	-- locked at the bottom; and a "None, leave slot empty" row above
	-- everything, because an unlocked slot is a capability, not a
	-- requirement. The old "Default bot" entry is retired; Living Tithe
	-- companions now provide the intended low-tier baseline.
	local entries = {}
	entries[#entries + 1] = { kind = "none", id = "none",
		display_name = "None, leave slot empty" }

	local buckets = {}
	for i = 1, #presets do
		local p = presets[i]
		local t = tonumber(p.tier) or 1
		if t < 1 then t = 1 elseif t > 4 then t = 4 end
		buckets[t] = buckets[t] or {}
		buckets[t][#buckets[t] + 1] = p
	end

	-- Empty groups are skipped entirely (no Iconic header until the
	-- first Tier 4 preset ships).
	local GROUPS = {
		{ 4, "Iconic" },
		{ 3, "Heroes" },
		{ 2, "Champions" },
		{ 1, "Living Tithe" },
	}
	for gi = 1, #GROUPS do
		local tier, label = GROUPS[gi][1], GROUPS[gi][2]
		local bucket = buckets[tier]
		if bucket and #bucket > 0 then
			table.sort(bucket, function(a, b)
				local ua = a.unlocked == true
				local ub = b.unlocked == true
				if ua ~= ub then return ua end
				return tostring(a.display_name) < tostring(b.display_name)
			end)
			entries[#entries + 1] = { kind = "header", display_name = label }
			for j = 1, #bucket do
				local e = bucket[j]
				e.kind = "preset"
				entries[#entries + 1] = e
			end
		end
	end

	-- Pagination. The scenegraph has exactly MAX_LEG_ROWS (8) row
	-- widgets and the grouped list is ~30 entries, so when it
	-- overflows, row 1 and row 8 become navigation rows and each page
	-- carries MAX_LEG_ROWS - 2 entries. self._pick_rows maps the
	-- visible row index to its entry for the click handler.
	local rows = {}
	local total = #entries
	if total <= MAX_LEG_ROWS then
		for i = 1, total do rows[i] = entries[i] end
	else
		local page_size = MAX_LEG_ROWS - 2
		local pages = math.ceil(total / page_size)
		local page = tonumber(self._pick_page) or 1
		if page < 1 then page = 1 elseif page > pages then page = pages end
		self._pick_page = page
		rows[1] = { kind = "nav", dir = -1, enabled = page > 1,
			display_name = string.format("Back  (page %d of %d)", page, pages) }
		local base = (page - 1) * page_size
		for i = 1, page_size do
			local e = entries[base + i]
			if e then rows[#rows + 1] = e end
		end
		rows[#rows + 1] = { kind = "nav", dir = 1, enabled = page < pages,
			display_name = "More..." }
	end
	self._pick_rows = rows

	local current = party and party.binding_for_slot and party.binding_for_slot(slot) or nil
	local blocking_slot_by_id = {}
	local max_slots = party and party.max_slots and party.max_slots() or 0
	if party and party.binding_for_slot then
		for other_slot = 1, max_slots do
			if other_slot ~= slot then
				local other_id = party.binding_for_slot(other_slot)
				if other_id and other_id ~= "none" then
					blocking_slot_by_id[other_id] = other_slot
				end
			end
		end
	end

	-- Dormant one-per-class picker gate. preset.lua now disables it after the
	-- profile-isolation fixes survived a same-class Psyker party. Keeping this
	-- UI path behind the same switch makes rollback a one-line change.
	local class_lock_enabled = party and party.class_lock_enabled
		and party.class_lock_enabled() or false
	local slot_archetypes = party and party.slot_archetypes and party.slot_archetypes() or {}
	local blocking_slot_by_arch = {}
	if class_lock_enabled then
		for other_slot, other_arch in pairs(slot_archetypes) do
			if other_slot ~= slot and other_arch then
				blocking_slot_by_arch[other_arch] = other_slot
			end
		end
	end

	for i = 1, MAX_LEG_ROWS do
		local widget = widgets["row_" .. i]
		local entry = rows[i]

		if not entry then
			widget.visible = false
			widget.dirty = true
		else
			widget.visible = true
			widget.content.status = ""
			widget.style.curse_icon.visible = false

			if entry.kind == "header" then
				-- Section header: a label, not an option. v0.22.76
				-- (Kaizen's field-test feedback): pilg_header suppresses
				-- the bar and its hover highlight via the definitions'
				-- change_function, hover/click sounds are muted on the
				-- hotspot (restored centrally in _set_list_visible), the
				-- click handler ignores kind == "header", and the text
				-- is uppercased in brackets in dim gold so it reads as
				-- a divider at a glance.
				widget.content.pilg_header = true
				local hotspot = widget.content.hotspot
				if hotspot then
					hotspot.on_pressed_sound = nil
					hotspot.on_hover_sound = nil
				end
				widget.content.index = ""
				widget.content.name = "[  " .. string.upper(entry.display_name) .. "  ]"
				widget.content.condition = ""
				widget.style.name.text_color = { 255, 190, 165, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			elseif entry.kind == "nav" then
				widget.content.index = ""
				widget.content.name = entry.display_name
				widget.content.condition = ""
				if entry.enabled then
					widget.style.name.text_color = { 255, 219, 219, 219 }
				else
					widget.style.name.text_color = { 255, 110, 110, 110 }
				end
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			else
				-- none / default / preset rows.
				widget.content.index = entry.kind == "preset"
					and ("Tier " .. tostring(entry.tier or 1)) or ""
				widget.content.name = entry.display_name
				widget.content.status = (entry.id == current) and "current" or ""
				-- Identity pass: the compact secondary column is the role line.
				-- In-mission titles stay on the profile and never appear here.
				local role = entry.kind == "preset"
					and tostring(entry.role_designation or "") or ""
				widget.content.condition = role
				local function role_status(status)
					return role ~= "" and (role .. "  |  " .. status) or status
				end

				local class_conflict_slot = entry.kind == "preset"
					and entry.archetype_name
					and blocking_slot_by_arch[entry.archetype_name]
				local identity_conflict_slot = entry.kind == "preset"
					and blocking_slot_by_id[entry.id]

				if entry.kind == "preset" and entry.unlocked == false then
					widget.content.condition = role_status("locked")
					widget.style.name.text_color = { 255, 110, 110, 110 }
					widget.style.index.text_color = { 255, 130, 130, 130 }
					widget.style.condition.text_color = { 255, 110, 110, 110 }
				elseif identity_conflict_slot then
					widget.content.condition = role_status(string.format(
						"already in slot %d", identity_conflict_slot))
					widget.style.name.text_color = { 255, 110, 110, 110 }
					widget.style.index.text_color = { 255, 130, 130, 130 }
					widget.style.condition.text_color = { 255, 200, 100, 100 }
				elseif class_conflict_slot then
					widget.content.condition = role_status(string.format(
						"class taken (slot %d)", class_conflict_slot))
					widget.style.name.text_color = { 255, 110, 110, 110 }
					widget.style.index.text_color = { 255, 130, 130, 130 }
					widget.style.condition.text_color = { 255, 200, 100, 100 }
				elseif entry.id == current then
					widget.style.name.text_color = { 255, 255, 226, 168 }
					widget.style.index.text_color = { 255, 255, 226, 168 }
					widget.style.condition.text_color = { 255, 150, 150, 150 }
				else
					if entry.kind == "none" then
						widget.content.condition = "spawns no bot"
					end
					widget.style.name.text_color = { 255, 219, 219, 219 }
					widget.style.index.text_color = { 255, 150, 150, 150 }
					widget.style.condition.text_color = { 255, 150, 150, 150 }
				end
			end
			widget.dirty = true
		end
	end
end

PilgrimageRouteView._on_preset_pick_row_pressed = function(self, index)
	-- Rows carry a `kind` (none / preset /
	-- header / nav). Headers ignore the click; nav rows page without
	-- leaving the picker; the other three bind and return to Party.
	local rows = self._pick_rows or {}
	local entry = rows[index]
	if not entry then return end

	if entry.kind == "header" then return end

	if entry.kind == "nav" then
		if not entry.enabled then return end
		self._pick_page = (tonumber(self._pick_page) or 1) + entry.dir
		self:_refresh_preset_pick()
		return
	end

	if entry.kind == "preset" and entry.unlocked == false then return end

	local api = _api()
	if not api or not api.party then return end

	local slot = self._party_pick_slot
	if not slot then return end

	-- Bind path. bind_slot lives on preset.lua; the party API exposes
	-- only cycle_slot for the tab, so we reach through pilgrimage's
	-- own module. Kept behind a nil-check because a stale API layout
	-- could otherwise crash the click.
	local Pilgrimage = rawget(_G, "get_mod") and get_mod("Pilgrimage") or nil
	local Preset = Pilgrimage and Pilgrimage._modules and Pilgrimage._modules.Preset

	if entry.kind == "none" then
		-- Deliberately-empty slot: spawns no bot at all.
		if Preset and Preset.bind_slot then
			Preset.bind_slot(slot, Preset.NONE_BINDING or "none")
		end
	else
		-- Exact preset identities stay unique even while same-class parties
		-- are allowed. Mirror preset.lua's API guard so a blocked row does not
		-- look clickable and then fail silently.
		local max_slots = api.party.max_slots and api.party.max_slots() or 0
		for other_slot = 1, max_slots do
			if other_slot ~= slot and api.party.binding_for_slot
				and api.party.binding_for_slot(other_slot) == entry.id then
				return
			end
		end
		-- Refuse the click for class-conflict rows only while the dormant
		-- greyed-out state actually blocks the bind. (bind_slot ALSO
		-- enforces this on the API side, but blocking at the click
		-- keeps the picker from silently failing after the user
		-- clicks.)
		local class_lock_enabled = api.party.class_lock_enabled
			and api.party.class_lock_enabled() or false
		if class_lock_enabled and entry.archetype_name then
			local slot_archetypes = api.party.slot_archetypes and api.party.slot_archetypes() or {}
			for other_slot, other_arch in pairs(slot_archetypes) do
				if other_slot ~= slot and other_arch == entry.archetype_name then
					return
				end
			end
		end
		if Preset and Preset.bind_slot then
			Preset.bind_slot(slot, entry.id)
		end
	end

	-- Return to the party tab (via _refresh_mode so tab bar redraws
	-- and any pending draft gets its own precedence check).
	self._party_pick_slot = nil
	self._pick_rows = nil
	self._pick_page = nil
	self._mode = "party"
	self:_refresh_mode()
end

-- ---------------------------------------------------------------------------
-- v0.22.51 (Session H): War Plan picker (transient mode entered from
-- the "Change War Plan" button on the Route tab)
--
-- Follows the preset_pick pattern exactly: fill the row widgets with
-- plan entries, highlight the currently-selected plan, grey out locked
-- plans with their required penance in the condition column, refuse the
-- click for locked rows. On accept, switch the selected plan and
-- regenerate the route.
--
-- Not a real tab because the picker is transient — you enter it, pick
-- (or cancel), and you're back on Route with the new plan's route
-- rendered. Full-time tab would waste the space; a modal-style overlay
-- on the tab we came from matches how the rest of the mod handles
-- one-shot pickers.
-- ---------------------------------------------------------------------------

-- Entry from the Change War Plan button.
PilgrimageRouteView._on_plan_button_pressed = function(self)
	-- Guard: a mid-run press is a no-op. plan_button.visible already
	-- reflects this, but a stale click or a hotspot race could still
	-- fire once, and switching the plan mid-run would leave the
	-- queue/curses inconsistent (see roadmap Section 9 rationale).
	local api = _api()
	local existing = api and api.current and api.current() or nil
	if existing and existing.active then return end

	self._mode = "war_plan_pick"
	self:_refresh_tab_bar()
	self:_refresh_balance()
	self:_refresh_war_plan_pick()
end

PilgrimageRouteView._refresh_war_plan_pick = function(self)
	local widgets = self._widgets_by_name
	local api = _api()

	self:_set_list_visible(true, false)

	widgets.title.content.text = "WAR PLANS"
	widgets.title.dirty = true
	widgets.subtitle.content.text = "Choose your pilgrimage tier. Close (X) to cancel."
	widgets.subtitle.dirty = true

	widgets.reroll_button.visible = false
	widgets.reroll_button.dirty = true
	widgets.begin_button.visible = false
	widgets.begin_button.dirty = true
	widgets.footer.visible = false
	widgets.footer.dirty = true
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end

	-- Get the plan list. war_plans_api exposes list() (every plan,
	-- ordered) + is_unlocked(id) + selected_id() + gate_penance(id)
	-- (the penance name that gates a locked plan, for the row label).
	local wp = api and api.war_plans or nil
	local plans = wp and wp.list and wp.list() or {}
	local selected = wp and wp.selected_id and wp.selected_id() or nil

	self._plan_pick_ordered = plans

	for i = 1, MAX_LEG_ROWS do
		local widget = widgets["row_" .. i]
		local entry = plans[i]

		if not entry then
			widget.visible = false
			widget.dirty = true
		else
			widget.visible = true
			widget.content.index = ""
			widget.content.name = entry.display_name or entry.id
			widget.content.status = (entry.id == selected) and "current" or ""
			widget.style.curse_icon.visible = false

			local is_unlocked = entry.unlocked == true
			if not is_unlocked then
				-- Locked: show the required penance in the condition
				-- column so the user knows how to open the tier.
				local gate = entry.gate_penance or "penance required"
				widget.content.condition = "locked - " .. gate
				widget.style.name.text_color = { 255, 110, 110, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 200, 100, 100 }
			elseif entry.id == selected then
				widget.content.condition = ""
				widget.style.name.text_color = { 255, 255, 226, 168 }
				widget.style.index.text_color = { 255, 255, 226, 168 }
				widget.style.condition.text_color = { 255, 150, 150, 150 }
			else
				widget.content.condition = ""
				widget.style.name.text_color = { 255, 219, 219, 219 }
				widget.style.index.text_color = { 255, 150, 150, 150 }
				widget.style.condition.text_color = { 255, 150, 150, 150 }
			end
			widget.dirty = true
		end
	end
end

PilgrimageRouteView._on_war_plan_row_pressed = function(self, index)
	local ordered = self._plan_pick_ordered or {}
	local entry = ordered[index]
	if not entry then return end
	if entry.unlocked ~= true then return end

	local api = _api()
	local wp = api and api.war_plans or nil
	if not wp or not wp.select then return end

	-- Skip the API call when they clicked what's already selected.
	-- Still returns to Route so the click still "does something".
	local already = wp.selected_id and wp.selected_id() or nil
	if entry.id ~= already then
		local ok = wp.select(entry.id)
		if not ok then
			-- select() returns false + error string if the plan is somehow
			-- locked from underneath us. Bail without state change.
			return
		end
		-- Wipe the cached route so _load_or_generate falls into _generate
		-- with the new plan's config on the next Route refresh.
		self._route = nil
		self._curses = nil
		self._seed = nil
		self._plan_name = nil
		self._existing_run = nil
	end

	self._plan_pick_ordered = nil
	self._mode = "route"
	self:_refresh_tab_bar()
	self:_refresh_balance()
	self:_load_or_generate()
end

-- ---------------------------------------------------------------------------
-- v0.22.77 (Session B phase 2): Penances tab
--
-- Reads api.penances.list(), groups by category under the same
-- non-interactive header rows the preset picker uses (pilg_header), and
-- paginates the same way (rows 1/8 become Back/More when the list
-- overflows the 8-widget pool; with ~27 penances it always does).
-- Earned penances render green with an "EARNED" tag; unearned render
-- grey with what they unlock in the condition column. Clicking a
-- penance row shows its full description in the subtitle line, since
-- descriptions don't fit a row column.
-- ---------------------------------------------------------------------------

local PENANCE_GROUPS = {
	{ "war_plan", "War Plans" },
	{ "preset",   "Warband" },
	{ "shop",     "Emporium" },
	{ "vanity",   "Vanity" },
}

PilgrimageRouteView._refresh_penances = function(self)
	local widgets = self._widgets_by_name
	local api = _api()
	local list = api and api.penances and api.penances.list and api.penances.list() or {}

	self:_set_list_visible(true, false)

	widgets.title.content.text = "PENANCES"
	widgets.title.dirty = true

	widgets.reroll_button.visible = false
	widgets.reroll_button.dirty = true
	widgets.begin_button.visible = false
	widgets.begin_button.dirty = true
	widgets.footer.visible = false
	widgets.footer.dirty = true
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end

	-- Bucket by category, preserving catalogue order within a group.
	local buckets = {}
	local earned_count = 0
	for i = 1, #list do
		local p = list[i]
		if p.earned then earned_count = earned_count + 1 end
		local cat = p.category or "vanity"
		buckets[cat] = buckets[cat] or {}
		buckets[cat][#buckets[cat] + 1] = p
	end

	-- Subtitle: either the inspected penance's description, or the
	-- overall progress line.
	local inspected = nil
	if self._penances_inspect then
		for i = 1, #list do
			if list[i].id == self._penances_inspect then
				inspected = list[i]
				break
			end
		end
	end
	if inspected then
		-- v0.22.79: the inspect line carries the full unlock info too,
		-- since the condition column only fits the short label.
		local line = inspected.name .. ": " .. (inspected.description or "")
		if inspected.unlocks_label and inspected.unlocks_label ~= "glory" then
			line = line .. "  |  Unlocks: " .. inspected.unlocks_label
		end
		widgets.subtitle.content.text = line
	else
		widgets.subtitle.content.text = string.format(
			"%d of %d earned. Click a penance for details.", earned_count, #list)
	end
	widgets.subtitle.dirty = true

	-- Flatten: headers + entries, in the fixed group order. Categories
	-- with nothing in them (shouldn't happen, but catalogue drift is
	-- cheap to guard) render no header.
	local entries = {}
	for gi = 1, #PENANCE_GROUPS do
		local cat, label = PENANCE_GROUPS[gi][1], PENANCE_GROUPS[gi][2]
		local bucket = buckets[cat]
		if bucket and #bucket > 0 then
			entries[#entries + 1] = { kind = "header", display_name = label }
			for j = 1, #bucket do
				local e = bucket[j]
				e.kind = "penance"
				entries[#entries + 1] = e
			end
		end
	end

	-- Pagination, same scheme as the preset picker. v0.22.85 (Kaizen's
	-- field feedback): row 1 of EVERY page is a fixed column-legend row
	-- naming what each column is (penance name / what it unlocks /
	-- state), so the pool for entries shrinks by one.
	local rows = {}
	rows[1] = { kind = "colhead" }
	local pool = MAX_LEG_ROWS - 1
	local total = #entries
	if total <= pool then
		for i = 1, total do rows[#rows + 1] = entries[i] end
	else
		local page_size = pool - 2
		local pages = math.ceil(total / page_size)
		local page = tonumber(self._penances_page) or 1
		if page < 1 then page = 1 elseif page > pages then page = pages end
		self._penances_page = page
		rows[#rows + 1] = { kind = "nav", dir = -1, enabled = page > 1,
			display_name = string.format("Back  (page %d of %d)", page, pages) }
		local base = (page - 1) * page_size
		for i = 1, page_size do
			local e = entries[base + i]
			if e then rows[#rows + 1] = e end
		end
		rows[#rows + 1] = { kind = "nav", dir = 1, enabled = page < pages,
			display_name = "More..." }
	end
	self._penances_rows = rows

	for i = 1, MAX_LEG_ROWS do
		local widget = widgets["row_" .. i]
		local entry = rows[i]

		if not entry then
			widget.visible = false
			widget.dirty = true
		else
			widget.visible = true
			widget.content.status = ""
			widget.style.curse_icon.visible = false

			if entry.kind == "colhead" then
				-- v0.22.85 (Kaizen): fixed legend row naming the
				-- columns. Non-interactive like the group dividers,
				-- but brighter, so it reads as a table header rather
				-- than a section break.
				widget.content.pilg_header = true
				local hotspot = widget.content.hotspot
				if hotspot then
					hotspot.on_pressed_sound = nil
					hotspot.on_hover_sound = nil
				end
				widget.content.index = ""
				widget.content.name = "PENANCE"
				widget.content.condition = "REWARD UNLOCKED"
				widget.content.status = "STATE"
				widget.style.name.text_color = { 255, 219, 200, 150 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 219, 200, 150 }
			elseif entry.kind == "header" then
				-- Same divider treatment as the preset picker
				-- (v0.22.76): flat bar, no hover, muted sounds,
				-- bracketed uppercase dim gold.
				widget.content.pilg_header = true
				local hotspot = widget.content.hotspot
				if hotspot then
					hotspot.on_pressed_sound = nil
					hotspot.on_hover_sound = nil
				end
				widget.content.index = ""
				widget.content.name = "[  " .. string.upper(entry.display_name) .. "  ]"
				widget.content.condition = ""
				widget.style.name.text_color = { 255, 190, 165, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			elseif entry.kind == "nav" then
				widget.content.index = ""
				widget.content.name = entry.display_name
				widget.content.condition = ""
				if entry.enabled then
					widget.style.name.text_color = { 255, 219, 219, 219 }
				else
					widget.style.name.text_color = { 255, 110, 110, 110 }
				end
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			else
				-- v0.22.79 (Kaizen's field feedback): the unlock label
				-- is ALWAYS shown in the condition column, earned or
				-- not; the earned state moves to the right-hand status
				-- column so it no longer hides what the penance gates.
				local is_inspected = entry.id == self._penances_inspect
				widget.content.index = ""
				widget.content.name = entry.name
				widget.content.condition = entry.unlocks_label or ""
				widget.content.status = entry.earned and "EARNED"
					or (is_inspected and "current" or "")

				if entry.earned then
					widget.style.name.text_color = { 255, 130, 210, 130 }
					widget.style.condition.text_color = { 255, 110, 170, 110 }
				else
					widget.style.name.text_color = is_inspected
						and { 255, 219, 219, 219 } or { 255, 150, 150, 150 }
					widget.style.condition.text_color = { 255, 190, 165, 110 }
				end
				widget.style.index.text_color = { 255, 130, 130, 130 }
			end
			widget.dirty = true
		end
	end
end

PilgrimageRouteView._on_penances_row_pressed = function(self, index)
	local rows = self._penances_rows or {}
	local entry = rows[index]
	if not entry then return end
	if entry.kind == "header" or entry.kind == "colhead" then return end

	if entry.kind == "nav" then
		if not entry.enabled then return end
		self._penances_page = (tonumber(self._penances_page) or 1) + entry.dir
		self:_refresh_penances()
		return
	end

	-- Toggle inspection: clicking the inspected penance again clears
	-- the detail line back to the progress summary.
	if self._penances_inspect == entry.id then
		self._penances_inspect = nil
	else
		self._penances_inspect = entry.id
	end
	self:_refresh_penances()
end

-- ---------------------------------------------------------------------------
-- v0.22.82 (Boon Loadout, slot model): Loadout tab
--
-- Kaizen's field feedback on the v0.22.81 flat list: "it should mimick
-- the slot system that party has, with unlocked/locked slots, choosing
-- in a different window, with scrolling pages ... and boons separated
-- by categories (once we implement them)." So: one row per Doctrine
-- slot (4 max), locked rows labelled with their unlock path, click an
-- unlocked slot to open the boon picker (paginated, None row, header
-- groups ready for categories).
-- ---------------------------------------------------------------------------

local BOON_SLOT_UNLOCK_LABEL = {
	[2] = "unlock in Emporium",
	[3] = "unlock in Emporium",
	[4] = "unlock via penance (soon)",
}

PilgrimageRouteView._refresh_loadout = function(self)
	local widgets = self._widgets_by_name
	local api = _api()
	local loadout = api and api.loadout or nil

	self:_set_list_visible(true, false)

	widgets.title.content.text = "BOON LOADOUT"
	widgets.title.dirty = true

	widgets.reroll_button.visible = false
	widgets.reroll_button.dirty = true
	widgets.begin_button.visible = false
	widgets.begin_button.dirty = true
	widgets.footer.visible = false
	widgets.footer.dirty = true
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end

	if not loadout then
		widgets.subtitle.content.text = "Loadout API not loaded. Report this."
		widgets.subtitle.dirty = true
		return
	end

	local slots = loadout.slots and loadout.slots() or 1
	local max_slots = loadout.max_slots and loadout.max_slots() or 4
	local list = loadout.list and loadout.list() or {}
	local by_id = {}
	for i = 1, #list do by_id[list[i].id] = list[i] end

	if loadout.loadout_locked and loadout.loadout_locked() then
		widgets.subtitle.content.text =
			"Loadout locked while a pilgrimage is under way. What you brought is what you carry."
	else
		widgets.subtitle.content.text = string.format(
			"%d of %d Doctrine slots open. Archetype, Legendaries and Doctrines lock in at run start.",
			slots, max_slots)
	end
	widgets.subtitle.dirty = true

	-- v0.24.0 (Boons v2): row 1 is the ARCHETYPE slot; Doctrine slots
	-- shift down one row. Clicking the archetype row cycles the
	-- selection (None and each archetype in catalogue order); the
	-- choice locks in at run start, so mid-run the row shows the run's
	-- own archetype while the selection underneath stays editable for
	-- the NEXT run.
	do
		local widget = widgets.row_1
		widget.visible = true
		widget.content.index = "Archetype"
		widget.content.status = ""
		widget.style.curse_icon.visible = false

		local unlocked = loadout.archetype_unlocked and loadout.archetype_unlocked()
		local run_arch = loadout.run_archetype and loadout.run_archetype() or nil
		local selected = loadout.selected_archetype and loadout.selected_archetype() or nil

		if not unlocked then
			widget.content.name = "Locked"
			widget.content.condition = string.format(
				"Archetype Authorization, %d Ordos at the Emporium",
				loadout.archetype_cost and loadout.archetype_cost() or 1500)
			widget.style.name.text_color = { 255, 110, 110, 110 }
			widget.style.index.text_color = { 255, 130, 130, 130 }
			widget.style.condition.text_color = { 255, 110, 110, 110 }
		elseif run_arch then
			widget.content.name = run_arch.name .. "  (locked for this run)"
			widget.content.condition = (selected and selected.id ~= run_arch.id)
				and ("next run: " .. selected.name)
				or ((selected == nil) and "next run: none" or "the road is drafted to match")
			widget.style.name.text_color = { 255, 210, 170, 100 }
			widget.style.index.text_color = { 255, 255, 226, 168 }
			widget.style.condition.text_color = { 255, 150, 150, 150 }
		else
			widget.content.name = selected and selected.name or "None"
			widget.content.condition = selected
				and (selected.short .. ", click to choose")
				or "no run identity, click to choose"
			widget.style.name.text_color = selected
				and { 255, 130, 210, 130 } or { 255, 219, 219, 219 }
			widget.style.index.text_color = { 255, 255, 226, 168 }
			widget.style.condition.text_color = { 255, 150, 150, 150 }
		end
		widget.dirty = true
	end

	-- Rows 2 and 3 are the permanent and run-scoped Legendary slots. The
	-- second row becomes selectable only after its expensive Emporium
	-- consumable is bought before the run.
	for legendary_slot = 1, 2 do
		local widget = widgets["row_" .. tostring(legendary_slot + 1)]
		widget.visible = true
		widget.content.index = legendary_slot == 1 and "Legendary"
			or "Legendary II"
		widget.content.status = ""
		widget.style.curse_icon.visible = false
		local slot_open = legendary_slot == 1
			or (loadout.temporary_legendary_unlocked
				and loadout.temporary_legendary_unlocked())

		local unlocked_count = 0
		if loadout.legendaries then
			local ll = loadout.legendaries(legendary_slot)
			unlocked_count = #ll
		end
		local run_leg = loadout.run_legendary
			and loadout.run_legendary(legendary_slot) or nil
		local sel_leg = loadout.selected_legendary
			and loadout.selected_legendary(legendary_slot) or nil

		if not slot_open and not run_leg then
			widget.content.name = "Locked"
			widget.content.condition = string.format(
				"Temporary Legendary Slot, %d Ordos at the Emporium",
				loadout.temporary_legendary_cost
					and loadout.temporary_legendary_cost() or 2000)
			widget.style.name.text_color = { 255, 110, 110, 110 }
			widget.style.index.text_color = { 255, 130, 130, 130 }
			widget.style.condition.text_color = { 255, 110, 110, 110 }
		elseif run_leg then
			widget.content.name = run_leg.name .. "  (locked for this run)"
			widget.content.condition = (sel_leg and sel_leg.id ~= run_leg.id)
				and ("next run: " .. sel_leg.name) or ""
			widget.style.name.text_color = { 255, 210, 170, 100 }
			widget.style.index.text_color = { 255, 255, 226, 168 }
			widget.style.condition.text_color = { 255, 150, 150, 150 }
		elseif unlocked_count == 0 then
			widget.content.name = "Empty"
			widget.content.condition =
				"unlock legendaries by drafting them on Penitent or higher and finishing the leg"
			widget.style.name.text_color = { 255, 219, 219, 219 }
			widget.style.index.text_color = { 255, 255, 226, 168 }
			widget.style.condition.text_color = { 255, 150, 150, 150 }
		else
			widget.content.name = sel_leg and sel_leg.name or "Empty"
			widget.content.condition = string.format(
				"%d unlocked, click to choose", unlocked_count)
			widget.style.name.text_color = sel_leg
				and { 255, 130, 210, 130 } or { 255, 219, 219, 219 }
			widget.style.index.text_color = { 255, 255, 226, 168 }
			widget.style.condition.text_color = { 255, 150, 150, 150 }
		end
		widget.dirty = true
	end

	for i = 1, MAX_LEG_ROWS - 3 do
		local widget = widgets["row_" .. (i + 3)]

		if i <= max_slots then
			widget.visible = true
			widget.content.index = "Doctrine " .. tostring(i)
			widget.content.status = ""
			widget.style.curse_icon.visible = false

			if i <= slots then
				local binding = loadout.binding_for_slot and loadout.binding_for_slot(i)
				local bound = binding and by_id[binding] or nil
				widget.content.name = bound and bound.name or "Empty"
				widget.content.condition = bound and bound.short or "click to choose"
				widget.style.name.text_color = bound
					and { 255, 130, 210, 130 } or { 255, 219, 219, 219 }
				widget.style.index.text_color = { 255, 255, 226, 168 }
				widget.style.condition.text_color = { 255, 150, 150, 150 }
			else
				widget.content.name = "Locked"
				widget.content.condition = BOON_SLOT_UNLOCK_LABEL[i] or "locked"
				widget.style.name.text_color = { 255, 110, 110, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 110, 110, 110 }
			end
			widget.dirty = true
		else
			widget.visible = false
			widget.dirty = true
		end
	end
end

PilgrimageRouteView._on_loadout_row_pressed = function(self, index)
	local api = _api()
	local loadout = api and api.loadout or nil
	if not loadout then return end

	-- v0.24.1 (Kaizen exploit report): the whole Loadout tab is LOCKED
	-- while a pilgrimage is under way. Slotting is a pre-run decision
	-- like the War Plan; the module layer enforces the same rule, this
	-- is just the polite refusal.
	if loadout.loadout_locked and loadout.loadout_locked() then
		local widgets = self._widgets_by_name
		widgets.subtitle.content.text =
			"Loadout locked while a pilgrimage is under way. Finish or abandon the run to change it."
		widgets.subtitle.dirty = true
		return
	end

	-- v0.24.1: row 1 is the Archetype slot; a click opens the archetype
	-- PICKER (Kaizen: lists, not cycles). A locked slot ignores the
	-- click; the row itself says where to buy the authorization.
	if index == 1 then
		if loadout.archetype_unlocked and loadout.archetype_unlocked() then
			self._archetype_pick_selected = nil
			self._archetype_pick_page = 1
			self._mode = "archetype_pick"
			self:_refresh_tab_bar()
			self:_refresh_balance()
			self:_refresh_archetype_pick()
		end
		return
	end

	-- Rows 2 and 3 open the primary and temporary Legendary pickers.
	if index == 2 or index == 3 then
		local legendary_slot = index - 1
		local slot_open = legendary_slot == 1
			or (loadout.temporary_legendary_unlocked
				and loadout.temporary_legendary_unlocked())
		local ll = loadout.legendaries and loadout.legendaries(legendary_slot) or {}
		if slot_open and #ll > 0 then
			self._legendary_pick_slot = legendary_slot
			self._legendary_pick_selected = nil
			self._legendary_pick_section = nil
			self._legendary_pick_page = 1
			self._mode = "legendary_pick"
			self:_refresh_tab_bar()
			self:_refresh_balance()
			self:_refresh_legendary_pick()
		end
		return
	end

	-- Doctrine rows are shifted down three: row N is Doctrine N-3.
	local slot = index - 3
	local slots = loadout.slots and loadout.slots() or 1
	if slot < 1 or slot > slots then return end -- locked or off-list

	-- Same shape as the party picker: stash the slot, enter picker mode.
	self._boon_pick_slot = slot
	self._boon_pick_selected = nil
	self._boon_pick_page = 1
	self._mode = "boon_pick"
	self:_refresh_tab_bar()
	self:_refresh_balance()
	self:_refresh_boon_pick()
end

-- ---------------------------------------------------------------------------
-- v0.24.1: archetype picker (transient mode entered from the Archetype
-- slot). Same list shape as the other pickers: Back row, None row, a
-- header, one row per archetype. Four archetypes fit one page, so no
-- pagination machinery until the catalogue outgrows the row pool.
-- ---------------------------------------------------------------------------

PilgrimageRouteView._refresh_archetype_pick = function(self)
	local widgets = self._widgets_by_name
	local api = _api()
	local loadout = api and api.loadout or nil

	self:_set_list_visible(true, false)

	widgets.title.content.text = "LOADOUT / ARCHETYPE"
	widgets.title.dirty = true
	local inspected = self._archetype_pick_selected
	widgets.subtitle.content.text =
		"Select an Archetype to inspect it, then Equip. Locked in when a run begins."
	widgets.subtitle.dirty = true

	widgets.reroll_button.visible = false
	widgets.reroll_button.dirty = true
	widgets.footer.visible = false
	widgets.footer.dirty = true
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end

	local list = loadout and loadout.archetypes and loadout.archetypes() or {}
	local current = nil
	for i = 1, #list do
		if list[i].selected then current = list[i].id end
		if inspected == list[i].id then
			local lock_note = list[i].unlocked and "" or "  |  Locked: " .. tostring(list[i].gate or "penance required")
			widgets.subtitle.content.text = list[i].name .. ": "
				.. (list[i].description or "") .. lock_note
		end
	end
	if inspected == PICK_NONE then
		widgets.subtitle.content.text = "None: no Archetype effects and unfiltered boon drafts."
	end
	widgets.subtitle.dirty = true
	local inspected_entry = nil
	for i = 1, #list do if list[i].id == inspected then inspected_entry = list[i] break end end
	local can_commit = (inspected == PICK_NONE and current ~= nil)
		or (inspected_entry ~= nil and inspected_entry.unlocked and inspected ~= current)
	widgets.begin_button.visible = can_commit
	widgets.begin_button.content.original_text = inspected == PICK_NONE and "Clear slot" or "Equip"
	widgets.begin_button.dirty = true

	local entries = {}
	entries[#entries + 1] = { kind = "back", display_name = "<<  Back to Loadout" }
	entries[#entries + 1] = { kind = "none", display_name = "None, no run identity" }
	entries[#entries + 1] = { kind = "header", display_name = "Archetypes" }
	for i = 1, #list do
		local a = list[i]
		a.kind = "archetype"
		entries[#entries + 1] = a
	end
	local rows = {}
	if #entries <= MAX_LEG_ROWS then
		for i = 1, #entries do rows[i] = entries[i] end
	else
		local page_size = MAX_LEG_ROWS - 2
		local pages = math.ceil(#entries / page_size)
		local page = tonumber(self._archetype_pick_page) or 1
		if page < 1 then page = 1 elseif page > pages then page = pages end
		self._archetype_pick_page = page
		rows[1] = { kind = "nav", dir = -1, enabled = page > 1,
			display_name = string.format("Back  (page %d of %d)", page, pages) }
		local base = (page - 1) * page_size
		for i = 1, page_size do
			local e = entries[base + i]
			if e then rows[#rows + 1] = e end
		end
		rows[#rows + 1] = { kind = "nav", dir = 1, enabled = page < pages,
			display_name = "More..." }
	end
	self._archetype_pick_rows = rows

	for i = 1, MAX_LEG_ROWS do
		local widget = widgets["row_" .. i]
		local entry = rows[i]

		if not entry then
			widget.visible = false
			widget.dirty = true
		else
			widget.visible = true
			widget.content.status = ""
			widget.style.curse_icon.visible = false

			if entry.kind == "header" then
				widget.content.pilg_header = true
				local hotspot = widget.content.hotspot
				if hotspot then
					hotspot.on_pressed_sound = nil
					hotspot.on_hover_sound = nil
				end
				widget.content.index = ""
				widget.content.name = "[  " .. string.upper(entry.display_name) .. "  ]"
				widget.content.condition = ""
				widget.style.name.text_color = { 255, 190, 165, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			elseif entry.kind == "back" or entry.kind == "nav" then
				widget.content.index = ""
				widget.content.name = entry.display_name
				widget.content.condition = ""
				local enabled = entry.kind == "back" or entry.enabled
				widget.style.name.text_color = enabled
					and { 255, 219, 219, 219 } or { 255, 110, 110, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			elseif entry.kind == "none" then
				widget.content.index = inspected == PICK_NONE and ">>" or ""
				widget.content.name = entry.display_name
				widget.content.status = current == nil and "equipped" or ""
				widget.content.condition = "drafts stay unfiltered"
				widget.style.name.text_color = inspected == PICK_NONE
					and { 255, 255, 226, 168 } or { 255, 219, 219, 219 }
				widget.style.index.text_color = { 255, 255, 226, 168 }
				widget.style.condition.text_color = { 255, 150, 150, 150 }
			else
				widget.content.index = inspected == entry.id and ">>" or ""
				widget.content.name = entry.name
				widget.content.status = entry.selected and "equipped" or ""
				widget.content.condition = entry.unlocked and entry.short
					or ("locked - " .. tostring(entry.gate or "penance required"))
				widget.style.name.text_color = inspected == entry.id
					and { 255, 255, 226, 168 }
					or (entry.unlocked and { 255, 219, 219, 219 } or { 255, 130, 130, 130 })
				widget.style.index.text_color = { 255, 255, 226, 168 }
				widget.style.condition.text_color = { 255, 150, 150, 150 }
			end
			widget.dirty = true
		end
	end
end

-- ---------------------------------------------------------------------------
-- v0.26.6: two-level Legendary picker. The flat cross-class list had
-- already reached thirteen pages before Pilgrimage's own catalogue was
-- added. The first level is one row per operative class; the second
-- contains that class's combat-ability and blitz Legendaries together.
-- A class page still greys entries that need a different equipped
-- ability, because class ownership and exact loadout applicability are
-- separate questions.
-- ---------------------------------------------------------------------------

PilgrimageRouteView._refresh_legendary_pick = function(self)
	local widgets = self._widgets_by_name
	local api = _api()
	local loadout = api and api.loadout or nil

	self:_set_list_visible(true, false)

	widgets.reroll_button.visible = false
	widgets.reroll_button.dirty = true
	widgets.footer.visible = false
	widgets.footer.dirty = true
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end

	local legendary_slot = tonumber(self._legendary_pick_slot) == 2 and 2 or 1
	local slot_label = legendary_slot == 2 and "LEGENDARY II" or "LEGENDARY"
	local list = loadout and loadout.legendaries
		and loadout.legendaries(legendary_slot) or {}
	local inspected = self._legendary_pick_selected
	local current = nil
	local buckets = {}
	for i = 1, #list do
		local e = list[i]
		if e.selected then current = e.id end
		local section = e.section
		if section and LEGENDARY_SECTION_LABEL[section] then
			buckets[section] = buckets[section] or {}
			buckets[section][#buckets[section] + 1] = e
		end
	end

	for _, bucket in pairs(buckets) do
		table.sort(bucket, function(a, b)
			if a.usable ~= b.usable then return a.usable == true end
			return tostring(a.name) < tostring(b.name)
		end)
	end

	local rows = {}
	local section = self._legendary_pick_section
	if not section then
		widgets.title.content.text = "LOADOUT / " .. slot_label
		widgets.subtitle.content.text = current
			and "Choose an operative section, or clear the currently equipped Legendary."
			or "Choose an operative section. Combat abilities and blitzes are grouped together."
		widgets.begin_button.visible = current ~= nil
		widgets.begin_button.content.original_text = "Clear slot"

		rows[#rows + 1] = { kind = "back", display_name = "<<  Back to Loadout" }
		for i = 1, #LEGENDARY_SECTIONS do
			local spec = LEGENDARY_SECTIONS[i]
			local bucket = buckets[spec.id]
			if bucket and #bucket > 0 then
				local has_current = false
				for j = 1, #bucket do
					if bucket[j].selected then has_current = true break end
				end
				rows[#rows + 1] = {
					kind = "section",
					id = spec.id,
					display_name = spec.label,
					count = #bucket,
					selected = has_current,
				}
			end
		end
	else
		local label = LEGENDARY_SECTION_LABEL[section] or tostring(section)
		local entries = buckets[section] or {}
		widgets.title.content.text = "LOADOUT / " .. slot_label .. " / " .. string.upper(label)
		widgets.subtitle.content.text =
			"Select a Legendary to inspect it, then Equip. Greyed entries need a different ability or blitz."
		local inspected_entry
		for i = 1, #entries do
			local e = entries[i]
			if inspected == e.id then
				inspected_entry = e
				local note = e.usable and ""
					or "  |  " .. (e.inert_reason
						or "Inert with the current ability or blitz.")
				if e.equipped_other then
					note = "  |  Already equipped in the other Legendary slot."
				end
				widgets.subtitle.content.text = e.name .. ": " .. (e.description or "") .. note
			end
		end
		widgets.begin_button.visible = inspected ~= nil and inspected ~= current
			and not (inspected_entry and inspected_entry.equipped_other)
		widgets.begin_button.content.original_text = "Equip"

		local page_size = MAX_LEG_ROWS - 2
		local pages = math.max(1, math.ceil(#entries / page_size))
		local page = tonumber(self._legendary_pick_page) or 1
		if page < 1 then page = 1 elseif page > pages then page = pages end
		self._legendary_pick_page = page
		rows[1] = page == 1
			and { kind = "section_back", display_name = "<<  Back to Operatives" }
			or { kind = "nav", dir = -1, enabled = true,
				display_name = string.format("Back  (page %d of %d)", page, pages) }
		local base = (page - 1) * page_size
		for i = 1, page_size do
			local e = entries[base + i]
			if e then
				e.kind = "legendary"
				rows[#rows + 1] = e
			end
		end
		rows[#rows + 1] = { kind = "nav", dir = 1, enabled = page < pages,
			display_name = "More..." }
	end
	widgets.title.dirty = true
	widgets.subtitle.dirty = true
	widgets.begin_button.dirty = true
	self._legendary_pick_rows = rows

	for i = 1, MAX_LEG_ROWS do
		local widget = widgets["row_" .. i]
		local entry = rows[i]

		if not entry then
			widget.visible = false
			widget.dirty = true
		else
			widget.visible = true
			widget.content.status = ""
			widget.style.curse_icon.visible = false

			if entry.kind == "back" or entry.kind == "section_back" or entry.kind == "nav" then
				widget.content.index = ""
				widget.content.name = entry.display_name
				widget.content.condition = ""
				local enabled = entry.kind ~= "nav" or entry.enabled
				widget.style.name.text_color = enabled
					and { 255, 219, 219, 219 } or { 255, 110, 110, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			elseif entry.kind == "section" then
				widget.content.index = ""
				widget.content.name = entry.display_name
				widget.content.status = entry.selected and "equipped here" or ""
				widget.content.condition = string.format("%d unlocked", entry.count or 0)
				widget.style.name.text_color = entry.selected
					and { 255, 255, 226, 168 } or { 255, 219, 219, 219 }
				widget.style.index.text_color = { 255, 150, 150, 150 }
				widget.style.condition.text_color = { 255, 150, 150, 150 }
			else
				widget.content.index = inspected == entry.id and ">>" or ""
				widget.content.name = entry.name
				widget.content.status = entry.selected and "equipped"
					or (entry.equipped_other and "in other slot" or "")
				widget.content.condition = entry.usable
					and "" or "needs a different ability or blitz"
				widget.style.name.text_color = inspected == entry.id
					and { 255, 255, 226, 168 }
					or (entry.usable and { 255, 219, 219, 219 } or { 255, 130, 130, 130 })
				widget.style.index.text_color = { 255, 255, 226, 168 }
				widget.style.condition.text_color = { 255, 150, 140, 100 }
			end
			widget.dirty = true
		end
	end
end

PilgrimageRouteView._on_legendary_pick_row_pressed = function(self, index)
	local rows = self._legendary_pick_rows or {}
	local entry = rows[index]
	if not entry then return end

	if entry.kind == "nav" then
		if not entry.enabled then return end
		self._legendary_pick_page = (tonumber(self._legendary_pick_page) or 1) + entry.dir
		self:_refresh_legendary_pick()
		return
	end

	local api = _api()
	local loadout = api and api.loadout or nil

	if entry.kind == "section" then
		self._legendary_pick_section = entry.id
		self._legendary_pick_selected = nil
		self._legendary_pick_page = 1
		self:_refresh_legendary_pick()
		return
	end

	if entry.kind == "section_back" then
		self._legendary_pick_section = nil
		self._legendary_pick_selected = nil
		self._legendary_pick_page = 1
		self:_refresh_legendary_pick()
		return
	end

	if entry.kind == "back" then
		self._legendary_pick_selected = nil
		self._legendary_pick_section = nil
		self._legendary_pick_slot = nil
		self._mode = "loadout"
		self:_refresh_tab_bar()
		self:_refresh_balance()
		self:_refresh_loadout()
		return
	end

	if not loadout then return end
	self._legendary_pick_selected = entry.id
	self:_refresh_legendary_pick()
end

PilgrimageRouteView._on_archetype_pick_row_pressed = function(self, index)
	local rows = self._archetype_pick_rows or {}
	local entry = rows[index]
	if not entry then return end
	if entry.kind == "header" then return end
	if entry.kind == "nav" then
		if not entry.enabled then return end
		self._archetype_pick_page = (tonumber(self._archetype_pick_page) or 1) + entry.dir
		self:_refresh_archetype_pick()
		return
	end

	local api = _api()
	local loadout = api and api.loadout or nil

	if entry.kind == "back" then
		self._archetype_pick_selected = nil
		self._mode = "loadout"
		self:_refresh_tab_bar()
		self:_refresh_balance()
		self:_refresh_loadout()
		return
	end

	if not loadout then return end
	self._archetype_pick_selected = entry.kind == "none" and PICK_NONE or entry.id
	self:_refresh_archetype_pick()
end

-- ---------------------------------------------------------------------------
-- v0.22.82: boon picker (transient mode entered from a Doctrine slot).
-- Mirrors the preset picker: None row on top, non-hoverable bracketed
-- header groups (single "Doctrines" group until Boons v2 categories
-- land), pagination when the list outgrows the 8-row pool. Unowned
-- boons are buyable IN the picker (click pays and the row flips to
-- selectable); owned boons bind on click and return to the Loadout
-- tab.
-- ---------------------------------------------------------------------------

PilgrimageRouteView._refresh_boon_pick = function(self)
	local widgets = self._widgets_by_name
	local api = _api()
	local loadout = api and api.loadout or nil
	local slot = self._boon_pick_slot

	self:_set_list_visible(true, false)

	widgets.title.content.text = string.format("LOADOUT / DOCTRINE %d", slot or 0)
	widgets.title.dirty = true
	widgets.subtitle.content.text =
		"Select a Doctrine to inspect it, then Equip. Unowned Doctrines are bought at the Emporium."
	widgets.subtitle.dirty = true

	widgets.reroll_button.visible = false
	widgets.reroll_button.dirty = true
	widgets.footer.visible = false
	widgets.footer.dirty = true
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end

	local list = loadout and loadout.list and loadout.list() or {}
	local current = loadout and loadout.binding_for_slot
		and loadout.binding_for_slot(slot) or nil
	local inspected = self._boon_pick_selected
	local inspected_entry = nil
	for i = 1, #list do
		if list[i].id == inspected then inspected_entry = list[i] break end
	end
	if inspected_entry then
		local note = ""
		if not inspected_entry.owned then note = "  |  Buy at the Emporium."
		elseif inspected_entry.bound_slot and inspected_entry.bound_slot ~= slot then
			note = string.format("  |  Already in Doctrine %d.", inspected_entry.bound_slot)
		end
		widgets.subtitle.content.text = inspected_entry.name .. ": "
			.. (inspected_entry.description or "") .. note
	elseif inspected == PICK_NONE then
		widgets.subtitle.content.text = "None: leave this Doctrine slot empty."
	end
	widgets.subtitle.dirty = true
	local can_commit = (inspected == PICK_NONE and current ~= nil)
		or (inspected_entry ~= nil and inspected_entry.owned
			and (not inspected_entry.bound_slot or inspected_entry.bound_slot == slot)
			and inspected_entry.id ~= current)
	widgets.begin_button.visible = can_commit
	widgets.begin_button.content.original_text = inspected == PICK_NONE and "Clear slot" or "Equip"
	widgets.begin_button.dirty = true

	-- Order: owned & free first, then bound-elsewhere, then unowned
	-- (by price). Stable enough for six boons; categories become
	-- header groups here when Boons v2 lands.
	table.sort(list, function(a, b)
		local ra = (a.owned and not a.bound_slot) and 1 or (a.owned and 2 or 3)
		local rb = (b.owned and not b.bound_slot) and 1 or (b.owned and 2 or 3)
		if ra ~= rb then return ra < rb end
		if ra == 3 and a.cost ~= b.cost then return a.cost < b.cost end
		return tostring(a.name) < tostring(b.name)
	end)

	local entries = {}
	-- v0.24.1: back row, same reasoning as the writ picker.
	entries[#entries + 1] = { kind = "back",
		display_name = "<<  Back to Loadout" }
	entries[#entries + 1] = { kind = "none", id = nil,
		display_name = "None, leave slot empty" }
	entries[#entries + 1] = { kind = "header", display_name = "Doctrines" }
	for i = 1, #list do
		local e = list[i]
		e.kind = "boon"
		entries[#entries + 1] = e
	end

	-- Pagination, same scheme as the preset picker.
	local rows = {}
	local total = #entries
	if total <= MAX_LEG_ROWS then
		for i = 1, total do rows[i] = entries[i] end
	else
		local page_size = MAX_LEG_ROWS - 2
		local pages = math.ceil(total / page_size)
		local page = tonumber(self._boon_pick_page) or 1
		if page < 1 then page = 1 elseif page > pages then page = pages end
		self._boon_pick_page = page
		rows[1] = { kind = "nav", dir = -1, enabled = page > 1,
			display_name = string.format("Back  (page %d of %d)", page, pages) }
		local base = (page - 1) * page_size
		for i = 1, page_size do
			local e = entries[base + i]
			if e then rows[#rows + 1] = e end
		end
		rows[#rows + 1] = { kind = "nav", dir = 1, enabled = page < pages,
			display_name = "More..." }
	end
	self._boon_pick_rows = rows

	for i = 1, MAX_LEG_ROWS do
		local widget = widgets["row_" .. i]
		local entry = rows[i]

		if not entry then
			widget.visible = false
			widget.dirty = true
		else
			widget.visible = true
			widget.content.status = ""
			widget.style.curse_icon.visible = false

			if entry.kind == "header" then
				widget.content.pilg_header = true
				local hotspot = widget.content.hotspot
				if hotspot then
					hotspot.on_pressed_sound = nil
					hotspot.on_hover_sound = nil
				end
				widget.content.index = ""
				widget.content.name = "[  " .. string.upper(entry.display_name) .. "  ]"
				widget.content.condition = ""
				widget.style.name.text_color = { 255, 190, 165, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			elseif entry.kind == "back" then
				widget.content.index = ""
				widget.content.name = entry.display_name
				widget.content.condition = ""
				widget.style.name.text_color = { 255, 219, 219, 219 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			elseif entry.kind == "nav" then
				widget.content.index = ""
				widget.content.name = entry.display_name
				widget.content.condition = ""
				widget.style.name.text_color = entry.enabled
					and { 255, 219, 219, 219 } or { 255, 110, 110, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			elseif entry.kind == "none" then
				widget.content.index = inspected == PICK_NONE and ">>" or ""
				widget.content.name = entry.display_name
				widget.content.status = (current == nil) and "equipped" or ""
				widget.content.condition = "clears the slot"
				widget.style.name.text_color = inspected == PICK_NONE
					and { 255, 255, 226, 168 } or { 255, 219, 219, 219 }
				widget.style.index.text_color = { 255, 150, 150, 150 }
				widget.style.condition.text_color = { 255, 150, 150, 150 }
			else
				widget.content.index = inspected == entry.id and ">>" or ""
				widget.content.name = entry.name
				widget.content.status = (entry.id == current) and "equipped" or ""

				if not entry.owned then
					widget.content.index = tostring(entry.cost) .. " Ordos"
					widget.content.condition = "buy at the Emporium"
					widget.style.name.text_color = { 255, 170, 170, 170 }
					widget.style.index.text_color = { 255, 255, 226, 168 }
					widget.style.condition.text_color = { 255, 130, 130, 130 }
				elseif entry.bound_slot and entry.id ~= current then
					widget.content.index = ""
					widget.content.condition = string.format(
						"in Doctrine %d", entry.bound_slot)
					widget.style.name.text_color = { 255, 110, 110, 110 }
					widget.style.index.text_color = { 255, 130, 130, 130 }
					widget.style.condition.text_color = { 255, 200, 100, 100 }
				else
					widget.content.index = ""
					widget.content.condition = entry.short
					widget.style.name.text_color = (inspected == entry.id)
						and { 255, 255, 226, 168 } or { 255, 219, 219, 219 }
					widget.style.index.text_color = { 255, 150, 150, 150 }
					widget.style.condition.text_color = { 255, 150, 150, 150 }
				end
			end
			widget.dirty = true
		end
	end
end

PilgrimageRouteView._on_boon_pick_row_pressed = function(self, index)
	local rows = self._boon_pick_rows or {}
	local entry = rows[index]
	if not entry then return end

	if entry.kind == "header" then return end

	-- v0.24.1: back to the Loadout tab, nothing changed.
	if entry.kind == "back" then
		self._boon_pick_selected = nil
		self._mode = "loadout"
		self:_refresh_tab_bar()
		self:_refresh_balance()
		self:_refresh_loadout()
		return
	end

	if entry.kind == "nav" then
		if not entry.enabled then return end
		self._boon_pick_page = (tonumber(self._boon_pick_page) or 1) + entry.dir
		self:_refresh_boon_pick()
		return
	end

	local api = _api()
	local loadout = api and api.loadout or nil
	if not loadout then return end

	if not self._boon_pick_slot then return end
	self._boon_pick_selected = entry.kind == "none" and PICK_NONE or entry.id
	self:_refresh_boon_pick()
end

-- v0.22.89: writ tier flavor, shown on empty tier slots and picker
-- headers. Wording from the locked Session C design.
local BAN_TIER_FLAVOR = {
	"monstrosities and daemonhosts",
	"disabler specialists",
	"secondary specialists and heavy elites",
	"other elites",
}

-- ---------------------------------------------------------------------------
-- v0.22.89: ban picker (transient mode entered from a writ tier slot in
-- the Emporium; Kaizen: "rebuild it so it's more convenient to use, in
-- the same way as party picker or boons picker"). Mirrors the boon
-- picker: bracketed header, pagination, buy stays a single click. No
-- None row: a writ is a purchase, not a binding, so there is nothing to
-- revoke; an already-active tier renders its writ as ACTIVE and the
-- rest of the tier as blocked. Close (X) cancels back to the Emporium.
-- ---------------------------------------------------------------------------

PilgrimageRouteView._refresh_ban_pick = function(self)
	local widgets = self._widgets_by_name
	local api = _api()
	local shop = api and api.shop or nil
	local tier = self._ban_pick_tier or 1

	self:_set_list_visible(true, false)

	widgets.title.content.text = string.format("EMPORIUM / WRIT TIER %d", tier)
	widgets.title.dirty = true
	local selected_sku = self._ban_pick_selected and shop and shop.get
		and shop.get(self._ban_pick_selected) or nil
	if selected_sku then
		local price = shop.effective_cost and shop.effective_cost(selected_sku) or (selected_sku.cost or 0)
		local status
		if shop.is_active and shop.is_active(selected_sku.id) then
			status = "already active this run"
		else
			local can, why = shop.can_buy and shop.can_buy(selected_sku.id)
			status = can and (tostring(price) .. " Ordos") or tostring(why or "unavailable")
		end
		widgets.subtitle.content.text = selected_sku.name .. ": "
			.. (selected_sku.description or "") .. "  |  " .. status
	else
		widgets.subtitle.content.text = string.format(
			"Ban one kind of enemy for the rest of the run: %s. One writ per tier. Click a writ for details, then Purchase. Close (X) to cancel.",
			BAN_TIER_FLAVOR[tier] or "")
	end
	widgets.subtitle.dirty = true

	widgets.reroll_button.visible = false
	widgets.reroll_button.dirty = true
	local selected_buyable = false
	if selected_sku and shop and shop.can_buy then
		selected_buyable = shop.can_buy(selected_sku.id) and true or false
	end
	widgets.begin_button.visible = selected_buyable
	widgets.begin_button.content.original_text = "Purchase"
	widgets.begin_button.dirty = true
	widgets.footer.visible = false
	widgets.footer.dirty = true
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end

	local list = {}
	local by_ban = shop and shop.by_category and shop.by_category("ban") or {}
	for i = 1, #by_ban do
		if by_ban[i].ban_tier == tier then
			list[#list + 1] = by_ban[i]
		end
	end

	local entries = {}
	-- v0.24.1 (Kaizen): a way back. The X closes the whole terminal,
	-- which reads as "no exit" when you only wanted to un-open a writ
	-- tier. Same back-row pattern as the archetype picker.
	entries[#entries + 1] = { kind = "back", display_name = "<<  Back to Emporium" }
	entries[#entries + 1] = { kind = "header",
		display_name = string.format("Tier %d Writs", tier) }
	for i = 1, #list do
		entries[#entries + 1] = { kind = "ban", sku = list[i] }
	end

	-- Pagination, same scheme as the other pickers (5 writs max per
	-- tier, so a single page in practice; the machinery is shared
	-- anyway in case tiers ever grow).
	local rows = {}
	local total = #entries
	if total <= MAX_LEG_ROWS then
		for i = 1, total do rows[i] = entries[i] end
	else
		local page_size = MAX_LEG_ROWS - 2
		local pages = math.ceil(total / page_size)
		local page = tonumber(self._ban_pick_page) or 1
		if page < 1 then page = 1 elseif page > pages then page = pages end
		self._ban_pick_page = page
		rows[1] = { kind = "nav", dir = -1, enabled = page > 1,
			display_name = string.format("Back  (page %d of %d)", page, pages) }
		local base = (page - 1) * page_size
		for i = 1, page_size do
			local e = entries[base + i]
			if e then rows[#rows + 1] = e end
		end
		rows[#rows + 1] = { kind = "nav", dir = 1, enabled = page < pages,
			display_name = "More..." }
	end
	self._ban_pick_rows = rows

	for i = 1, MAX_LEG_ROWS do
		local widget = widgets["row_" .. i]
		local entry = rows[i]

		if not entry then
			widget.visible = false
			widget.dirty = true
		else
			widget.visible = true
			widget.content.status = ""
			widget.style.curse_icon.visible = false

			if entry.kind == "header" then
				widget.content.pilg_header = true
				local hotspot = widget.content.hotspot
				if hotspot then
					hotspot.on_pressed_sound = nil
					hotspot.on_hover_sound = nil
				end
				widget.content.index = ""
				widget.content.name = "[  " .. string.upper(entry.display_name) .. "  ]"
				widget.content.condition = ""
				widget.style.name.text_color = { 255, 190, 165, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			elseif entry.kind == "back" then
				widget.content.index = ""
				widget.content.name = entry.display_name
				widget.content.condition = ""
				widget.style.name.text_color = { 255, 219, 219, 219 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			elseif entry.kind == "nav" then
				widget.content.index = ""
				widget.content.name = entry.display_name
				widget.content.condition = ""
				widget.style.name.text_color = entry.enabled
					and { 255, 219, 219, 219 } or { 255, 110, 110, 110 }
				widget.style.index.text_color = { 255, 130, 130, 130 }
				widget.style.condition.text_color = { 255, 130, 130, 130 }
			else
				local sku = entry.sku
				local active = shop and shop.is_active and shop.is_active(sku.id)
				local can, why = false, nil
				if shop and shop.can_buy then can, why = shop.can_buy(sku.id) end
				local price = shop and shop.effective_cost
					and shop.effective_cost(sku) or (sku.cost or 0)

				widget.content.name = sku.name
				widget.content.status = active and "ACTIVE" or ""
				widget.content.index = tostring(price) .. " Ordos"

				if active then
					widget.content.condition = "lasts until the run ends"
					widget.style.name.text_color = { 255, 130, 210, 130 }
					widget.style.index.text_color = { 255, 130, 130, 130 }
					widget.style.condition.text_color = { 255, 110, 170, 110 }
				elseif can then
					widget.content.condition = ""
					widget.style.name.text_color = { 255, 219, 219, 219 }
					widget.style.index.text_color = { 255, 255, 226, 168 }
					widget.style.condition.text_color = { 255, 150, 150, 150 }
				else
					-- Blocked: price stays visible (the v0.22.83
					-- lesson), reason in the condition column.
					widget.content.condition = tostring(why or "unavailable")
					widget.style.name.text_color = { 255, 110, 110, 110 }
					widget.style.index.text_color = { 255, 150, 140, 100 }
					widget.style.condition.text_color = { 255, 200, 100, 100 }
				end
			end
			widget.dirty = true
		end
	end
end

PilgrimageRouteView._on_ban_pick_row_pressed = function(self, index)
	local rows = self._ban_pick_rows or {}
	local entry = rows[index]
	if not entry then return end
	if entry.kind == "header" then return end

	-- v0.24.1: back to the Emporium, selection dropped.
	if entry.kind == "back" then
		self._ban_pick_selected = nil
		self._mode = "shop"
		self:_refresh_tab_bar()
		self:_refresh_balance()
		self:_refresh_shop()
		return
	end

	if entry.kind == "nav" then
		if not entry.enabled then return end
		self._ban_pick_page = (tonumber(self._ban_pick_page) or 1) + entry.dir
		self:_refresh_ban_pick()
		return
	end

	local api = _api()
	local shop = api and api.shop or nil
	if not shop or not shop.buy then return end

	local sku = entry.sku
	if not sku then return end

	-- v0.22.94: select, don't buy; Purchase button commits.
	if self._ban_pick_selected == sku.id then
		self._ban_pick_selected = nil
	else
		self._ban_pick_selected = sku.id
	end
	self:_refresh_ban_pick()
end

-- ---------------------------------------------------------------------------
-- Emporium tab
--
-- One row per SKU in the shop catalogue, in category order. Click to
-- buy if can_buy passes. Right-most column shows the price when buyable,
-- or the reason it's not (owned, active, locked, too expensive). v0.22.89:
-- the ban category renders as four writ tier slots that open the ban
-- picker above; other categories stay flat rows.
-- ---------------------------------------------------------------------------

PilgrimageRouteView._refresh_shop = function(self)
	local widgets = self._widgets_by_name
	local api = _api()
	local shop = api and api.shop or nil

	self:_set_list_visible(true, false)

	widgets.title.content.text = "EMPORIUM"
	widgets.title.dirty = true

	if not shop then
		widgets.subtitle.content.text = "Shop API not loaded. Report this."
		widgets.subtitle.dirty = true
		return
	end

	local skus = shop.skus and shop.skus() or {}
	self._shop_visible_skus = {} -- row index -> SKU id

	-- v0.22.94 (Kaizen: "it needs to be visible what you are buying
	-- before you buy"): rows SELECT, the Purchase button buys. The
	-- subtitle carries the selected SKU's full description + status.
	-- v0.24.2 (Kaizen: "same thing for buying doctrines, you know the
	-- drill"): Doctrines are bought HERE, select-then-Purchase like
	-- every other SKU. The Loadout picker only slots what is owned.
	local loadout = api and api.loadout or nil
	local selected_doctrine = nil
	if self._shop_selected_doctrine and loadout and loadout.list then
		local dl = loadout.list()
		for i = 1, #dl do
			if dl[i].id == self._shop_selected_doctrine then selected_doctrine = dl[i] end
		end
	end

	local selected_sku = self._shop_selected and shop.get and shop.get(self._shop_selected) or nil
	if selected_doctrine then
		local status
		if selected_doctrine.owned then
			status = "already owned; slot it in the Loadout tab"
		else
			status = tostring(selected_doctrine.cost or 0) .. " Ordos"
		end
		widgets.subtitle.content.text = selected_doctrine.name .. ": "
			.. (selected_doctrine.description or "") .. "  |  " .. status
	elseif selected_sku then
		local price = shop.effective_cost and shop.effective_cost(selected_sku) or (selected_sku.cost or 0)
		local status
		if selected_sku.pending then
			status = "coming soon"
		elseif selected_sku.kind == "permanent" and shop.is_unlocked and shop.is_unlocked(selected_sku.id) then
			status = "already owned"
		elseif shop.is_active and shop.is_active(selected_sku.id) then
			status = "already active this run"
		else
			local can, why = shop.can_buy and shop.can_buy(selected_sku.id)
			status = can and (tostring(price) .. " Ordos") or tostring(why or "unavailable")
		end
		widgets.subtitle.content.text = selected_sku.name .. ": "
			.. (selected_sku.description or "") .. "  |  " .. status
	else
		widgets.subtitle.content.text = "Click an item for details, then Purchase."
	end
	widgets.subtitle.dirty = true

	widgets.reroll_button.visible = false
	widgets.reroll_button.dirty = true
	local selected_buyable = false
	if selected_sku and not selected_sku.pending and shop.can_buy then
		selected_buyable = shop.can_buy(selected_sku.id) and true or false
	end
	-- v0.24.2: an unowned selected Doctrine arms Purchase too. The buy
	-- itself reports "not enough Ordos" through the subtitle on failure.
	if selected_doctrine and not selected_doctrine.owned then
		selected_buyable = true
	end
	widgets.begin_button.visible = selected_buyable
	widgets.begin_button.content.original_text = "Purchase"
	widgets.begin_button.dirty = true
	-- v0.22.51
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end

	-- Order the SKUs so consumables come before permanent unlocks. The
	-- catalogue already stores them in this order but sort explicitly so
	-- a future re-order in shop.lua doesn't scramble the display.
	local ordered = {}
	local seen = {}
	-- v0.22.88: enemy bans get their own group between the run
	-- consumables and the permanent unlocks.
	for _, cat in ipairs({ "consumable", "ban", "permanent" }) do
		local by_cat = shop.by_category and shop.by_category(cat) or {}
		for i = 1, #by_cat do
			if not seen[by_cat[i].id] then
				ordered[#ordered + 1] = by_cat[i]
				seen[by_cat[i].id] = true
			end
		end
	end
	-- Anything with an unknown category still shows, tacked on the end.
	for i = 1, #skus do
		if not seen[skus[i].id] then
			ordered[#ordered + 1] = skus[i]
			seen[skus[i].id] = true
		end
	end

	-- v0.22.82 (Kaizen: "the list of purchasable items keeps
	-- growing"): category header rows + the same Back/More pagination
	-- as the preset picker. Header groups: Consumables / Permanent
	-- Unlocks (unknown categories fall under the last header shown).
	local entries = {}
	local last_cat = nil
	local CAT_LABELS = {
		consumable = "Consumables",
		ban = "Writs of Exclusion",
		permanent = "Permanent Unlocks",
	}
	-- v0.22.89 (Kaizen: "rebuild it so it's more convenient... same way
	-- as party picker or boons picker"): the ban category renders as
	-- FOUR TIER SLOTS instead of seventeen SKU rows. Clicking a slot
	-- opens the ban picker (transient mode, same shape as the boon
	-- picker); the slot shows the run's active writ for that tier.
	local ban_slots_emitted = false
	for i = 1, #ordered do
		local sku = ordered[i]
		if sku.category == "ban" then
			if not ban_slots_emitted then
				ban_slots_emitted = true
				entries[#entries + 1] = { kind = "header", display_name = CAT_LABELS.ban }
				for tier = 1, 4 do
					entries[#entries + 1] = { kind = "ban_slot", tier = tier }
				end
				last_cat = CAT_LABELS.ban
			end
		else
			local cat = CAT_LABELS[sku.category] or "Consumables"
			if cat ~= last_cat then
				entries[#entries + 1] = { kind = "header", display_name = cat }
				last_cat = cat
			end
			entries[#entries + 1] = { kind = "sku", sku = sku }
		end
	end

	-- v0.24.2: Doctrines section, spliced in before Permanent Unlocks
	-- (they ARE permanent purchases; giving them their own header keeps
	-- the slot expansions readable). Entries come from the loadout API,
	-- not the shop catalogue: Doctrines live in boons.lua.
	if loadout and loadout.list then
		local dl = loadout.list()
		table.sort(dl, function(a, b)
			if (a.owned and 1 or 0) ~= (b.owned and 1 or 0) then
				return (a.owned and 1 or 0) < (b.owned and 1 or 0)
			end
			if (a.cost or 0) ~= (b.cost or 0) then return (a.cost or 0) < (b.cost or 0) end
			return tostring(a.name) < tostring(b.name)
		end)
		local doc_entries = {}
		doc_entries[#doc_entries + 1] = { kind = "header", display_name = "Doctrines" }
		for i = 1, #dl do
			doc_entries[#doc_entries + 1] = { kind = "doctrine", boon = dl[i] }
		end
		local insert_at = #entries + 1
		for i = 1, #entries do
			if entries[i].kind == "header"
				and entries[i].display_name == CAT_LABELS.permanent then
				insert_at = i
				break
			end
		end
		for i = #doc_entries, 1, -1 do
			table.insert(entries, insert_at, doc_entries[i])
		end
	end

	local rows = {}
	local total = #entries
	if total <= MAX_LEG_ROWS then
		for i = 1, total do rows[i] = entries[i] end
	else
		local page_size = MAX_LEG_ROWS - 2
		local pages = math.ceil(total / page_size)
		local page = tonumber(self._shop_page) or 1
		if page < 1 then page = 1 elseif page > pages then page = pages end
		self._shop_page = page
		rows[1] = { kind = "nav", dir = -1, enabled = page > 1,
			display_name = string.format("Back  (page %d of %d)", page, pages) }
		local base = (page - 1) * page_size
		for i = 1, page_size do
			local e = entries[base + i]
			if e then rows[#rows + 1] = e end
		end
		rows[#rows + 1] = { kind = "nav", dir = 1, enabled = page < pages,
			display_name = "More..." }
	end
	self._shop_rows = rows

	for i = 1, MAX_LEG_ROWS do
		local widget = widgets["row_" .. i]
		local entry = rows[i]

		if not entry then
			widget.visible = false
			widget.dirty = true
		elseif entry.kind == "header" then
			widget.visible = true
			widget.content.pilg_header = true
			local hotspot = widget.content.hotspot
			if hotspot then
				hotspot.on_pressed_sound = nil
				hotspot.on_hover_sound = nil
			end
			widget.content.index = ""
			widget.content.name = "[  " .. string.upper(entry.display_name) .. "  ]"
			widget.content.condition = ""
			widget.content.status = ""
			widget.style.curse_icon.visible = false
			widget.style.name.text_color = { 255, 190, 165, 110 }
			widget.style.index.text_color = { 255, 130, 130, 130 }
			widget.style.condition.text_color = { 255, 130, 130, 130 }
			widget.dirty = true
		elseif entry.kind == "nav" then
			widget.visible = true
			widget.content.index = ""
			widget.content.name = entry.display_name
			widget.content.condition = ""
			widget.content.status = ""
			widget.style.curse_icon.visible = false
			widget.style.name.text_color = entry.enabled
				and { 255, 219, 219, 219 } or { 255, 110, 110, 110 }
			widget.style.index.text_color = { 255, 130, 130, 130 }
			widget.style.condition.text_color = { 255, 130, 130, 130 }
			widget.dirty = true
		elseif entry.kind == "doctrine" then
			-- v0.24.2: Doctrine purchase row. Same reading order as SKU
			-- rows: tag, name, price/status on the right.
			local b = entry.boon
			widget.visible = true
			widget.content.index = (self._shop_selected_doctrine == b.id) and ">>" or "DOCT"
			widget.content.name = b.name or b.id
			widget.content.status = ""
			widget.style.curse_icon.visible = false
			if b.owned then
				widget.content.condition = b.bound_slot
					and string.format("Owned, in Doctrine %d", b.bound_slot)
					or "Owned"
				widget.style.condition.text_color = { 255, 130, 200, 130 }
			else
				widget.content.condition = string.format("%d Ordos", b.cost or 0)
				widget.style.condition.text_color = { 255, 255, 226, 168 }
			end
			widget.style.index.text_color = { 255, 150, 150, 150 }
			widget.style.name.text_color = { 255, 219, 219, 219 }
			widget.dirty = true
		elseif entry.kind == "ban_slot" then
			-- v0.22.89: one row per writ tier, party-slot styling.
			local tier = entry.tier
			local active_sku = nil
			local by_ban = shop.by_category and shop.by_category("ban") or {}
			for j = 1, #by_ban do
				if by_ban[j].ban_tier == tier and shop.is_active
					and shop.is_active(by_ban[j].id) then
					active_sku = by_ban[j]
					break
				end
			end
			widget.visible = true
			widget.content.index = "Writ Tier " .. tostring(tier)
			widget.content.name = active_sku and active_sku.name or "Empty"
			widget.content.condition = active_sku and "lasts until the run ends"
				or (BAN_TIER_FLAVOR[tier] .. ", click to choose")
			widget.content.status = active_sku and "ACTIVE" or ""
			widget.style.curse_icon.visible = false
			widget.style.name.text_color = active_sku
				and { 255, 130, 210, 130 } or { 255, 219, 219, 219 }
			widget.style.index.text_color = { 255, 255, 226, 168 }
			widget.style.condition.text_color = { 255, 150, 150, 150 }
			widget.dirty = true
		else
			local sku = entry.sku
			self._shop_visible_skus[i] = sku.id
			widget.visible = true
			widget.content.index = (self._shop_selected == sku.id) and ">>" or (sku.category == "permanent" and "PERM" or "CONS")
			widget.content.name = sku.name or sku.id
			widget.content.status = ""
			widget.style.curse_icon.visible = false

			-- Decide the right-column text and colour.
			local reason_text, colour
			local active   = shop.is_active   and shop.is_active(sku.id)
			local unlocked = shop.is_unlocked and shop.is_unlocked(sku.id)
			local stacks   = shop.stack_count and shop.stack_count(sku.id) or 0
			local can, why = shop.can_buy and shop.can_buy(sku.id)

			if sku.pending then
				reason_text = "coming soon"
				colour = { 255, 110, 110, 110 }
			elseif sku.kind == "permanent" and unlocked then
				reason_text = "Owned"
				colour = { 255, 130, 200, 130 }
			elseif sku.kind == "consumable" and sku.stackable and stacks > 0 then
				-- v0.22.81: effective_cost, so the House Always Wins
				-- tax shows in the price the moment it applies.
				local price = shop.effective_cost and shop.effective_cost(sku.id) or sku.cost or 0
				reason_text = string.format("Active x%d  (%d Ordos)", stacks, price)
				colour = { 255, 255, 226, 168 }
			elseif sku.kind == "consumable" and active then
				reason_text = "Active this run"
				colour = { 255, 130, 200, 130 }
			elseif can then
				local price = shop.effective_cost and shop.effective_cost(sku.id) or sku.cost or 0
				reason_text = string.format("%d Ordos", price)
				colour = { 255, 255, 226, 168 }
			else
				-- v0.22.83 (Kaizen: "make it so the cost is visible
				-- regardless of whether you have the ordos"): a
				-- non-buyable row still shows its price next to the
				-- reason, so "not enough Ordos" never reads as
				-- "not purchasable at all".
				local price = shop.effective_cost and shop.effective_cost(sku.id) or sku.cost or 0
				if price > 0 then
					reason_text = string.format("%d Ordos, %s", price, tostring(why or "locked"))
				else
					reason_text = tostring(why or "locked")
				end
				colour = { 255, 200, 100, 100 }
			end

			widget.content.condition = reason_text
			widget.style.condition.text_color = colour

			-- Left columns: category tag muted, name in body colour so
			-- the eye reads name -> price left-to-right.
			widget.style.index.text_color = { 255, 150, 150, 150 }
			widget.style.name.text_color  = sku.pending
				and { 255, 130, 130, 130 } or { 255, 219, 219, 219 }

			widget.dirty = true
		end
	end

	-- v0.22.33: hide footer in Emporium for the same reason as Party
	-- (see _refresh_party). The "consumables die..." rule was already
	-- documented per-row through the CONS/PERM tag, so no info is
	-- lost by dropping the footer here.
	widgets.footer.visible = false
	widgets.footer.dirty = true
end

PilgrimageRouteView._on_shop_row_pressed = function(self, index)
	-- v0.22.82: header rows ignore the click, nav rows page.
	local entry = self._shop_rows and self._shop_rows[index]
	if entry and entry.kind == "header" then return end
	if entry and entry.kind == "nav" then
		if not entry.enabled then return end
		self._shop_page = (tonumber(self._shop_page) or 1) + entry.dir
		self:_refresh_shop()
		return
	end

	-- v0.22.89: writ tier slots open the ban picker, same shape as a
	-- Doctrine slot opening the boon picker.
	if entry and entry.kind == "ban_slot" then
		self._ban_pick_tier = entry.tier
		self._ban_pick_page = 1
		self._mode = "ban_pick"
		self:_refresh_tab_bar()
		self:_refresh_balance()
		self:_refresh_ban_pick()
		return
	end

	-- v0.24.2: Doctrine rows select like SKU rows; the two selections
	-- are mutually exclusive so the Purchase button is never ambiguous.
	if entry and entry.kind == "doctrine" then
		local id = entry.boon and entry.boon.id
		if not id then return end
		if self._shop_selected_doctrine == id then
			self._shop_selected_doctrine = nil
		else
			self._shop_selected_doctrine = id
			self._shop_selected = nil
		end
		self:_refresh_shop()
		return
	end

	local api = _api()
	local shop = api and api.shop or nil
	if not shop or not shop.buy then return end

	local sku_id = self._shop_visible_skus and self._shop_visible_skus[index]
	if not sku_id then return end

	-- v0.22.94: a row click SELECTS (details into the subtitle, the
	-- Purchase button arms); clicking the selected row again clears.
	if self._shop_selected == sku_id then
		self._shop_selected = nil
		self._shop_selected_doctrine = nil
	else
		self._shop_selected = sku_id
		self._shop_selected_doctrine = nil
	end
	self:_refresh_shop()
end

PilgrimageRouteView._show_error = function(self, message)
	local widgets = self._widgets_by_name

	widgets.subtitle.content.text = message
	widgets.subtitle.dirty = true

	widgets.footer.content.text = ""
	widgets.footer.dirty = true

	for i = 1, MAX_LEG_ROWS do
		widgets["row_" .. i].visible = false
		widgets["row_" .. i].dirty = true
	end

	widgets.begin_button.visible = false
	widgets.begin_button.dirty = true
	widgets.reroll_button.visible = false
	widgets.reroll_button.dirty = true
	-- v0.22.51
	if widgets.plan_button then
		widgets.plan_button.visible = false
		widgets.plan_button.dirty = true
	end
end

-- ---------------------------------------------------------------------------
-- Buttons
-- ---------------------------------------------------------------------------

PilgrimageRouteView._on_reroll_pressed = function(self)
	if self._mode == "draft" then
		local api = _api()
		local draft = api and api.reroll_draft and api.reroll_draft() or nil
		if draft and #draft > 0 then
			self._draft = draft
			self:_refresh_draft()
		else
			self:_show_error("Second Reading could not replace this draft.")
		end
		return
	end
	if self._existing_run then return end
	-- v0.20.1: force a new seed. Opening the terminal used to accidentally
	-- reroll because both paths went through generate(); the Reroll button
	-- now has its own API entry so it's the only way to get a new seed.
	local api = _api()
	if not api or not api.reroll_preview then
		-- Fallback for any older wire-up where reroll_preview is missing.
		self:_generate()
		return
	end

	local result = api.reroll_preview()
	if not result or not result.queue or #result.queue == 0 then
		self:_show_error("Could not reroll the route. No playable missions found.")
		return
	end

	self._route = result.queue
	self._curses = result.curses
	self._seed = result.seed
	self._plan_name = result.plan_name
	self:_refresh()
end

PilgrimageRouteView._on_begin_pressed = function(self)
	if self._mode == "draft" then
		local api = _api()
		if not api or not api.reject_boon or not api.reject_boon() then return end
		if api.in_hub and not api.in_hub() then
			self:_on_close_pressed()
			return
		end
		self:_refresh_mode()
		return
	end

	-- v0.26.1: Loadout pickers are inspect-then-Equip, matching the
	-- Emporium's select-then-Purchase interaction. Row clicks only set
	-- transient view state; this shared action button is the sole commit.
	if self._mode == "boon_pick" or self._mode == "archetype_pick"
		or self._mode == "legendary_pick" then
		local api = _api()
		local loadout = api and api.loadout or nil
		if not loadout then return end
		local ok, why = false, "nothing selected"

		if self._mode == "boon_pick" and self._boon_pick_selected ~= nil then
			local id = self._boon_pick_selected
			if id == PICK_NONE then id = nil end
			ok, why = loadout.bind(self._boon_pick_slot, id)
		elseif self._mode == "archetype_pick" and self._archetype_pick_selected ~= nil then
			local id = self._archetype_pick_selected
			if id == PICK_NONE then id = nil end
			ok, why = loadout.select_archetype(id)
		elseif self._mode == "legendary_pick" and self._legendary_pick_section == nil then
			-- The section index uses the shared action button as a direct,
			-- explicit Clear Slot control, which keeps all seven classes
			-- visible without spending an eighth row on a None entry.
			ok, why = loadout.select_legendary(nil, self._legendary_pick_slot)
		elseif self._mode == "legendary_pick" and self._legendary_pick_selected ~= nil then
			local id = self._legendary_pick_selected
			ok, why = loadout.select_legendary(id, self._legendary_pick_slot)
		end

		if not ok then
			local widgets = self._widgets_by_name
			widgets.subtitle.content.text = "Could not equip: " .. tostring(why or "unavailable")
			widgets.subtitle.dirty = true
			return
		end

		self._boon_pick_slot = nil
		self._boon_pick_rows = nil
		self._boon_pick_page = nil
		self._boon_pick_selected = nil
		self._archetype_pick_rows = nil
		self._archetype_pick_page = nil
		self._archetype_pick_selected = nil
		self._legendary_pick_rows = nil
		self._legendary_pick_page = nil
		self._legendary_pick_selected = nil
		self._legendary_pick_section = nil
		self._legendary_pick_slot = nil
		self._mode = "loadout"
		self:_refresh_mode()
		return
	end

	-- v0.22.94: in shop and ban-picker modes the same button is the
	-- Purchase button for the current selection.
	if self._mode == "shop" or self._mode == "ban_pick" then
		local api = _api()
		local shop = api and api.shop or nil

		-- v0.24.2: a selected Doctrine buys through the loadout API
		-- (Doctrines live in boons.lua, not the shop catalogue). On
		-- failure the reason lands in the subtitle so "not enough
		-- Ordos" is never a silent click.
		if self._mode == "shop" and self._shop_selected_doctrine then
			local loadout = api and api.loadout or nil
			if not loadout or not loadout.buy then return end
			local ok_buy, why = loadout.buy(self._shop_selected_doctrine)
			self:_refresh_shop()
			self:_refresh_balance()
			if not ok_buy then
				local widgets = self._widgets_by_name
				widgets.subtitle.content.text = "Purchase failed: " .. tostring(why or "unknown")
				widgets.subtitle.dirty = true
			end
			return
		end

		local selected = self._mode == "shop" and self._shop_selected or self._ban_pick_selected
		if not shop or not shop.buy or not selected then return end
		local bought = shop.buy(selected)
		if self._mode == "ban_pick" then
			if bought then
				-- Back to the Emporium, slot now shows the writ.
				self._ban_pick_tier = nil
				self._ban_pick_rows = nil
				self._ban_pick_page = nil
				self._ban_pick_selected = nil
				self._mode = "shop"
				self:_refresh_mode()
			else
				self:_refresh_ban_pick()
				self:_refresh_balance()
			end
		else
			self:_refresh_shop()
			self:_refresh_balance()
		end
		return
	end

	-- Guard against a double press. The view takes a moment to close and the launch
	-- itself is asynchronous, so without this a fast second click would start a second
	-- run over the top of the first.
	if self._committed then return end

	local api = _api()
	if not api or not api.begin then return end
	if not self._route or #self._route == 0 then return end

	self._committed = true

	self:_on_close_pressed()

	-- Launch after the close request, so the loading screen replaces the view rather
	-- than appearing behind it.
	api.begin(self._route, self._seed, self._existing_run ~= nil, self._curses)
end

PilgrimageRouteView._on_close_pressed = function(self)
	Managers.ui:close_view(self.view_name or "pilgrimage_route_view")
end

-- Escape and the controller back button both land here.
PilgrimageRouteView.on_back_pressed = function(self)
	self:_on_close_pressed()
end

-- ---------------------------------------------------------------------------

PilgrimageRouteView.update = function(self, dt, t, input_service)
	-- Realms join/leave and handshake events can arrive while the terminal is open.
	-- Half-second repainting keeps this read-only panel current without rebuilding
	-- widgets or polling the network every frame.
	if self._mode == "realm" and type(t) == "number"
		and t - (self._realm_refresh_t or 0) >= 0.5 then
		self._realm_refresh_t = t
		self:_refresh_realm()
	end
	return PilgrimageRouteView.super.update(self, dt, t, input_service)
end

return PilgrimageRouteView
