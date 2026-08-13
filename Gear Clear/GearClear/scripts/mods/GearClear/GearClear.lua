-- GearClear.lua
local mod = get_mod("GearClear")
local Items = require("scripts/utilities/items")
local MasterItems = require("scripts/backend/master_items")
local WeaponStats = require("scripts/utilities/weapon_stats")

local SLOT_NAMES = {
"slot_primary",
"slot_secondary",
"slot_attachment_1",
"slot_attachment_2",
"slot_attachment_3",
}
local SLOT_LOOKUP = {
slot_primary = true,
slot_secondary = true,
slot_attachment_1 = true,
slot_attachment_2 = true,
slot_attachment_3 = true,
}
local WEAPON_TYPES = {
WEAPON_MELEE = true,
WEAPON_RANGED = true,
}
local GADGET_TYPE = "GADGET"
local CTRL_G_DELAY = 0.25
local HOOK_TOKEN = tostring(mod)

local function safe_lower(text)
if type(text) ~= "string" then
return ""
end

text = string.gsub(text, "{#.-}", "")
text = string.gsub(text, "%%", " percent")

return string.lower(text)
end

local function round_percent(value)
if type(value) ~= "number" then
return nil
end

return math.floor(value * 100 + 0.5)
end

local function round_number(value)
if type(value) ~= "number" then
return nil
end

return math.floor(value + 0.5)
end

local function has_slot(item, slot_name)
local slots = item and item.slots

if not slots then
return false
end

for i = 1, #slots do
if slots[i] == slot_name then
return true
end
end

return false
end

local function item_slot_allowed(item)
local slots = item and item.slots

if not slots then
return false
end

for i = 1, #slots do
if SLOT_LOOKUP[slots[i]] then
return true
end
end

return false
end

local function item_type_allowed(item)
local item_type = item and item.item_type

return WEAPON_TYPES[item_type] or item_type == GADGET_TYPE
end

local function item_gear_id(item)
return item and item.gear_id
end

local function item_favorited(item)
local gear_id = item_gear_id(item)

if not gear_id then
return true
end

local success, result = pcall(Items.is_item_id_favorited, gear_id)

if not success then
return true
end

return not not result
end

local function item_equipped(view, item)
if not view or not item then
return true
end

local slots = item.slots

if not slots then
return true
end

if view.is_item_equipped_in_any_slot then
local success, result = pcall(view.is_item_equipped_in_any_slot, view, item, slots)

if success and result then
return true
elseif not success then
return true
end
end

local equipped_items = view._preview_profile_equipped_items

if not equipped_items then
return false
end

local gear_id = item_gear_id(item)

for i = 1, #slots do
local equipped_item = equipped_items[slots[i]]
local equipped_gear_id = type(equipped_item) == "table" and equipped_item.gear_id or equipped_item

if gear_id and equipped_gear_id == gear_id then
return true
end
end

return false
end

local function weapon_is_melee(item)
return item and (item.item_type == "WEAPON_MELEE" or has_slot(item, "slot_primary"))
end

local function weapon_exception_stat(item, stat_name)
stat_name = safe_lower(stat_name)
stat_name = string.gsub(stat_name, "^%s*(.-)%s*$", "%1")

if stat_name == "" then
return nil
end

if stat_name == "damage" then
return true
end

if stat_name == "penetration" then
return true
end

if stat_name == "ammo" then
return true
end

if weapon_is_melee(item) and stat_name == "finesse" then
return true
end

return false
end

local function weapon_keeper_from_max_stats(item, stats)
if type(stats) ~= "table" or #stats == 0 then
return nil
end

local dump_count = 0
local other_count = 0

for i = 1, #stats do
local stat = stats[i]
local value = type(stat) == "table" and stat.value or stat

if type(value) ~= "number" then
return nil
end

if value >= 59 and value <= 61.5 then
local exception = weapon_exception_stat(item, type(stat) == "table" and stat.name or nil)

if exception == nil then
return nil
end

if exception then
return false
end

dump_count = dump_count + 1
elseif value >= 79.5 and value <= 80.5 then
other_count = other_count + 1
else
return false
end
end

return dump_count == 1 and other_count == #stats - 1
end

local function percent_from_any(value)
if type(value) == "string" then
value = string.gsub(value, "{#.-}", "")
value = string.match(value, "[%+%-]?%d+")
value = value and tonumber(value)
end

if type(value) ~= "number" then
return nil
end

if value <= 1 then
return round_percent(value)
end

return round_number(value)
end

local function weapon_preview_max_stats(item)
local success, max_stats, localized_text = pcall(function ()
local weapon_stats = WeaponStats:new(item)
local comparing_stats = weapon_stats:get_comparing_stats()

if type(comparing_stats) ~= "table" or #comparing_stats == 0 then
return nil, nil
end

local start_expertise = 0

if Items and Items.expertise_level then
local expertise_value = Items.expertise_level(item, true)

start_expertise = tonumber(expertise_value) or 0
end

local max_expertise = Items and Items.max_expertise_level and Items.max_expertise_level() or start_expertise
local max_delta = math.max((tonumber(max_expertise) or start_expertise) - start_expertise, 0)
local max_stats = Items and Items.preview_stats_change and Items.preview_stats_change(item, max_delta, comparing_stats) or nil
local maximum = {}
local text = ""

if type(max_stats) ~= "table" then
return nil, nil
end

for i = 1, #comparing_stats do
local stat_data = comparing_stats[i]
local display_name = stat_data and stat_data.display_name
local max_stat = display_name and max_stats[display_name]
local max_value = percent_from_any(max_stat and (max_stat.value or max_stat.fraction))

if not max_value then
return nil, nil
end

local localized_name = display_name and Localize(display_name) or ""

maximum[#maximum + 1] = {
name = localized_name ~= "" and localized_name or display_name,
value = max_value,
}
text = text .. " " .. localized_name .. " /" .. tostring(max_value) .. "%"
end

return maximum, text
end)

if success then
return max_stats, localized_text
end

return nil, nil
end

local function weapon_keeper_from_localized_text(item, max_stats, localized_text)
if type(localized_text) ~= "string" then
return nil
end

localized_text = safe_lower(localized_text)

local has_sixty = string.find(localized_text, "/60 percent", 1, true)
local has_sixty_one = string.find(localized_text, "/61 percent", 1, true)
local has_seventy_nine = string.find(localized_text, "/79 percent", 1, true)

if has_sixty_one and has_seventy_nine then
return false
end

if not has_sixty and not has_sixty_one then
return false
end

return weapon_keeper_from_max_stats(item, max_stats)
end

local function weapon_item_keeper(item)
local max_stats, localized_text = weapon_preview_max_stats(item)
local backend = weapon_keeper_from_max_stats(item, max_stats)
local localized = weapon_keeper_from_localized_text(item, max_stats, localized_text)

if backend == true or localized == true then
return true
end

if backend == nil or localized == nil then
return true
end

return false
end

local function trait_item_from_trait(trait)
local trait_id = trait and trait.id

if not trait_id then
return nil
end

local success, trait_item = pcall(MasterItems.get_item, trait_id)

if success then
return trait_item
end

return nil
end

local function trait_name_from_item(trait_item, trait)
return trait_item and (trait_item.trait or trait_item.name) or trait and trait.id or ""
end

local function trait_description_text(trait_item, trait)
if not trait_item then
return nil
end

local success, description = pcall(Items.trait_description, trait_item, trait.rarity, trait.value)

if success then
return description
end

return nil
end

local function curio_value_from_backend(trait_name, lerp_value)
if type(lerp_value) ~= "number" then
return nil
end

if string.find(trait_name, "gadget_innate_health_increase", 1, true) then
return "health", round_number((0.05 + 0.2 * lerp_value) * 100)
elseif string.find(trait_name, "gadget_innate_toughness_increase", 1, true) then
return "toughness", round_number((0.05 + 0.15 * lerp_value) * 100)
elseif string.find(trait_name, "gadget_stamina_increase", 1, true) then
return "stamina", round_number(1 + 2 * lerp_value)
elseif string.find(trait_name, "gadget_innate_max_wounds_increase", 1, true) then
return "wounds", 1
end

return nil, nil
end

local function curio_keeper_from_kind(kind, value)
if kind == "health" then
return value and value >= 21
elseif kind == "toughness" then
return value and value >= 17
elseif kind == "stamina" then
return value and value >= 3
elseif kind == "wounds" then
return false
end

return nil
end

local function curio_keeper_backend(item)
local traits = item and item.traits

if type(traits) ~= "table" or #traits == 0 then
return nil
end

local saw_known_innate = false

for i = 1, #traits do
local trait = traits[i]
local trait_item = trait_item_from_trait(trait)
local trait_name = safe_lower(trait_name_from_item(trait_item, trait))
local kind, value = curio_value_from_backend(trait_name, trait and trait.value)
local keep = curio_keeper_from_kind(kind, value)

if keep ~= nil then
saw_known_innate = true

if keep then
return true
end
end
end

if saw_known_innate then
return false
end

return nil
end

local function number_from_text(text)
local value = string.match(text, "([%+%-]?%d+)")

return value and tonumber(value) or nil
end

local function curio_keeper_localized(item)
local traits = item and item.traits

if type(traits) ~= "table" or #traits == 0 then
return nil
end

local saw_relevant = false

for i = 1, #traits do
local trait = traits[i]
local trait_item = trait_item_from_trait(trait)
local text = safe_lower(trait_description_text(trait_item, trait))
local value = number_from_text(text)

if string.find(text, "wound", 1, true) then
saw_relevant = true
elseif string.find(text, "max health", 1, true) or string.find(text, "health", 1, true) then
saw_relevant = true

if value and value >= 21 then
return true
end
elseif string.find(text, "toughness", 1, true) then
saw_relevant = true

if value and value >= 17 then
return true
end
elseif string.find(text, "max stamina", 1, true) or string.find(text, "stamina", 1, true) then
saw_relevant = true

if value and value >= 3 then
return true
end
end
end

if saw_relevant then
return false
end

return nil
end

local function item_keeper(item)
local item_type = item and item.item_type

if WEAPON_TYPES[item_type] then
return weapon_item_keeper(item)
elseif item_type == GADGET_TYPE then
local backend = curio_keeper_backend(item)
local localized = curio_keeper_localized(item)

if backend == true or localized == true then
return true
end

if backend == nil and localized == nil then
return true
end

return false
end

return true
end

local function item_eligible(view, item, ignore_good)
if not item or not item_gear_id(item) then
return false
end

if not item_type_allowed(item) or not item_slot_allowed(item) then
return false
end

if item_favorited(item) then
return false
end

if item_equipped(view, item) then
return false
end

if ignore_good and item_keeper(item) then
return false
end

return true
end

local function current_view_items(view)
local layouts = view and view._offer_items_layout
local items = {}

if type(layouts) ~= "table" then
return items
end

for i = 1, #layouts do
local item = layouts[i] and layouts[i].item

if item then
items[#items + 1] = item
end
end

return items
end

local function selected_slot_valid(view)
local selected_slot = view and view._selected_slot
local slot_name = selected_slot and selected_slot.name

return slot_name and SLOT_LOOKUP[slot_name]
end

local function eligible_from_items(view, items)
local ignore_good = mod:get("ignore_good_gear_mode") ~= false
local eligible = {}
local seen = {}

for i = 1, #items do
local item = items[i]
local gear_id = item_gear_id(item)

if gear_id and not seen[gear_id] and item_eligible(view, item, ignore_good) then
seen[gear_id] = true
eligible[#eligible + 1] = item
end
end

return eligible
end

local function gear_ids_from_items(items)
local gear_ids = {}
local seen = {}

for i = 1, #items do
local gear_id = item_gear_id(items[i])

if gear_id and not seen[gear_id] and not item_favorited(items[i]) then
seen[gear_id] = true
gear_ids[#gear_ids + 1] = gear_id
end
end

return gear_ids
end

local function discard_items(items)
local gear_ids = gear_ids_from_items(items)

if #gear_ids > 0 and Managers and Managers.event then
Managers.event:trigger("event_discard_items", gear_ids)
end
end

local function fetch_all_items()
local player_manager = Managers and Managers.player
local player = player_manager and player_manager.local_player and player_manager:local_player(1)
local character_id = player and player.character_id and player:character_id()
local data_service = Managers and Managers.data_service
local gear_service = data_service and data_service.gear

if not character_id or not gear_service or not gear_service.fetch_inventory then
return nil
end

return gear_service:fetch_inventory(character_id, SLOT_NAMES)
end

local function inventory_view_items(view)
local items = {}
local inventory_items = view and view._inventory_items

if type(inventory_items) ~= "table" then
return items
end

for _, item in pairs(inventory_items) do
if item then
items[#items + 1] = item
end
end

return items
end

function mod.perform_gear_clear(view, scope)
if mod._gear_clear_running then
return
end

if scope == "page" then
if not selected_slot_valid(view) then
return
end

local eligible = eligible_from_items(view, current_view_items(view))

discard_items(eligible)

return
end

local promise = fetch_all_items()

if not promise then
local fallback_items = inventory_view_items(view)

if #fallback_items == 0 then
fallback_items = current_view_items(view)
end

local eligible = eligible_from_items(view, fallback_items)

discard_items(eligible)

return
end

mod._gear_clear_running = true
promise:next(function (items_by_id)
mod._gear_clear_running = false

if view and view._destroyed then
return
end

local items = {}

if type(items_by_id) == "table" then
for _, item in pairs(items_by_id) do
items[#items + 1] = item
end
end

local eligible = eligible_from_items(view, items)

discard_items(eligible)
end):catch(function ()
mod._gear_clear_running = false
end)
end

local function discard_element_visible(view)
local element = view and view._discard_items_element

if not element then
return false
end

if element.visible then
local success, result = pcall(element.visible, element)

if success then
return not not result
end
end

return true
end

local function gear_clear_available(view)
return selected_slot_valid(view) and view._offer_items_layout and not view._selected_options and not discard_element_visible(view)
end

local function gear_clear_all_available(view)
if not view or view.view_name ~= "inventory_background_view" or view._destroyed then
return false
end

if view._is_readonly or view._is_own_player == false then
return false
end

if view.is_inventory_synced and not view:is_inventory_synced() then
return false
end

if view._active_view and view._active_view ~= "inventory_view" then
return false
end

if Managers and Managers.ui and Managers.ui.view_active and Managers.ui:view_active("inventory_weapons_view") then
return false
end

return true
end

local function selected_slot_label(view)
local selected_slot = view and view._selected_slot
local slot_name = selected_slot and selected_slot.name

if slot_name == "slot_primary" then
return "melee weapons"
elseif slot_name == "slot_secondary" then
return "ranged weapons"
elseif slot_name == "slot_attachment_1" or slot_name == "slot_attachment_2" or slot_name == "slot_attachment_3" then
return "curios"
end

return "this gear slot"
end

local function gear_clear_scope(view)
if gear_clear_all_available(view) then
return "all"
end

if gear_clear_available(view) then
return "page"
end

return nil
end

local function gear_clear_popup_message(view, scope)
if scope == "page" then
return "Clear unwanted gear from " .. selected_slot_label(view)
end

return "Clear unwanted gear from all gear slots"
end

function mod.run_gear_clear(view, scope)
scope = scope or gear_clear_scope(view)

if not scope or mod._gear_clear_popup_open then
return
end

if not Managers or not Managers.event then
return
end

mod._gear_clear_popup_open = true

local context = {
title_text_unlocalized = "Gear Clear",
description_text_unlocalized = gear_clear_popup_message(view, scope),
options = {
{
close_on_pressed = true,
no_localization = true,
text = "Clear",
callback = function ()
mod._gear_clear_popup_open = false

if view and not view._destroyed and gear_clear_scope(view) == scope then
mod.perform_gear_clear(view, scope)
end
end,
},
{
close_on_pressed = true,
hotkey = "back",
no_localization = true,
text = "Cancel",
callback = function ()
mod._gear_clear_popup_open = false
end,
},
},
}

Managers.event:trigger("event_show_ui_popup", context)
end

local function ctrl_g_pressed()
if not Keyboard or not Keyboard.button_index or not Keyboard.button or not Keyboard.pressed then
return false
end

local g = Keyboard.button_index("g")
local left_ctrl = Keyboard.button_index("left ctrl")
local right_ctrl = Keyboard.button_index("right ctrl")

if not g then
return false
end

local ctrl = 0

if left_ctrl then
ctrl = ctrl + Keyboard.button(left_ctrl)
end

if right_ctrl then
ctrl = ctrl + Keyboard.button(right_ctrl)
end

return ctrl > 0.5 and Keyboard.pressed(g)
end

local function inventory_weapons_screen(view)
if not view or view.view_name ~= "inventory_weapons_view" or view._destroyed then
return false
end

if view._is_readonly or view._is_own_player == false then
return false
end

return true
end

local function inventory_background_screen(view)
if not view or view.view_name ~= "inventory_background_view" or view._destroyed then
return false
end

if view._is_readonly or view._is_own_player == false then
return false
end

return true
end

local function gear_clear_legend_screen(view)
if inventory_weapons_screen(view) then
return true
end

if inventory_background_screen(view) then
return true
end

return false
end

local function gear_clear_legend_visible(parent)
return gear_clear_legend_screen(parent)
end

local function control_text()
local text = mod:localize("gear_clear_control")

if text == "<gear_clear_control>" then
text = "[Ctrl+G] Gear Clear"
end

local label = string.gsub(text, "%[Ctrl%+G%]%s*", "", 1)
local key = "{#color(226, 199, 126)}[Ctrl+G]{#reset()}"
local template = Localize and Localize("loc_input_legend_text_template") or "%s %s"

return string.format(template, key, label)
end

local ensure_gear_clear_entry

local function current_gear_clear_entry(input_legend_element, preferred_id, remove_duplicates)
local entries = input_legend_element and input_legend_element._entries

if type(entries) ~= "table" then
return nil
end

local selected_entry = nil

for i = 1, #entries do
local entry = entries[i]

if entry and entry.display_name == "gear_clear_legend" then
if preferred_id and entry.id == preferred_id then
selected_entry = entry
break
elseif not selected_entry then
selected_entry = entry
end
end
end

if remove_duplicates and selected_entry and input_legend_element.remove_entry then
for i = #entries, 1, -1 do
local entry = entries[i]

if entry and entry.display_name == "gear_clear_legend" and entry ~= selected_entry then
pcall(input_legend_element.remove_entry, input_legend_element, entry.id)
end
end
end

return selected_entry
end

local function set_gear_clear_entry_callback(input_legend_element, entry)
if not entry then
return
end

local widget = entry.widget
local content = widget and widget.content
local hotspot = content and content.hotspot

if hotspot then
hotspot.pressed_callback = function ()
if not input_legend_element._input_handled and entry.on_pressed_callback then
entry.on_pressed_callback(entry.id, true)
end
end
end
end

local function update_gear_clear_entry(view, input_legend_element, entry)
if not entry then
return
end

view.cb_on_gear_clear_pressed = view.cb_on_gear_clear_pressed or function (self)
mod.run_gear_clear(self)
end

entry.display_name = "gear_clear_legend"
entry.input_action = nil
entry.visibility_function = gear_clear_legend_visible
entry.on_pressed_callback = callback(view, "cb_on_gear_clear_pressed")
entry.side = "right_alignment"
entry.use_mouse_hold = nil
entry.extra_input_actions = nil
entry.suffix_function = nil
entry.is_visible = gear_clear_legend_visible(view)
set_gear_clear_entry_callback(input_legend_element, entry)

local widget = entry.widget

if widget and widget.content then
widget.content.text = control_text()
entry.recalcultate_text_width = true
end
end

local function gear_clear_entry_is_visible(view)
local input_legend_element = view and view._input_legend_element
local entry = current_gear_clear_entry(input_legend_element, view and view._gear_clear_legend_entry_id, false)

if not entry then
return false
end

local visible = entry.is_visible ~= false

if entry.visibility_function then
local success, result = pcall(entry.visibility_function, view, entry.id)

if success then
visible = not not result
end
end

return visible
end

local function add_gear_clear_entry(view, input_legend_element)
if not input_legend_element or not input_legend_element.add_entry then
return nil
end

view.cb_on_gear_clear_pressed = view.cb_on_gear_clear_pressed or function (self)
mod.run_gear_clear(self)
end

local entry_id = input_legend_element:add_entry("gear_clear_legend", nil, gear_clear_legend_visible, callback(view, "cb_on_gear_clear_pressed"), "right_alignment")
view._gear_clear_legend_entry_id = entry_id

local entry = current_gear_clear_entry(input_legend_element, entry_id, true)
update_gear_clear_entry(view, input_legend_element, entry)

return entry
end

ensure_gear_clear_entry = function (view)
local input_legend_element = view and view._input_legend_element

if not input_legend_element or not gear_clear_legend_screen(view) then
return nil
end

local entry = current_gear_clear_entry(input_legend_element, view._gear_clear_legend_entry_id, true)

if entry then
view._gear_clear_legend_entry_id = entry.id
update_gear_clear_entry(view, input_legend_element, entry)
return entry
end

view._gear_clear_legend_entry_id = nil

return add_gear_clear_entry(view, input_legend_element)
end

local function update_gear_clear_view(view, t)
if not gear_clear_legend_screen(view) then
return
end

ensure_gear_clear_entry(view)

local scope = gear_clear_scope(view)

if scope and type(t) == "number" and gear_clear_entry_is_visible(view) and ctrl_g_pressed() then
local last_t = view._gear_clear_last_t or 0

if t - last_t >= CTRL_G_DELAY then
view._gear_clear_last_t = t
mod.run_gear_clear(view, scope)
end
end
end

local function hook_input_legend(ViewElementInputLegend)
if not ViewElementInputLegend then
return
end

if ViewElementInputLegend.gearclear_text_hook_token ~= HOOK_TOKEN then
ViewElementInputLegend.gearclear_text_hook_token = HOOK_TOKEN
mod:hook(ViewElementInputLegend, "_update_widget_text", function (func, self, entry)
if entry and entry.display_name == "gear_clear_legend" then
local widget = entry.widget

if widget and widget.content then
widget.content.text = control_text()
entry.recalcultate_text_width = true
end

return
end

return func(self, entry)
end)
end

if ViewElementInputLegend.gearclear_update_hook_token ~= HOOK_TOKEN then
ViewElementInputLegend.gearclear_update_hook_token = HOOK_TOKEN
mod:hook(ViewElementInputLegend, "update", function (func, self, dt, t, input_service, ...)
local result = func(self, dt, t, input_service, ...)
local parent = self and self._parent

update_gear_clear_view(parent, t)

return result
end)
end
end

local function hook_inventory_weapons_view(InventoryWeaponsView)
if not InventoryWeaponsView or InventoryWeaponsView.gearclear_view_hook_token == HOOK_TOKEN then
return
end

InventoryWeaponsView.gearclear_view_hook_token = HOOK_TOKEN
InventoryWeaponsView.cb_on_gear_clear_pressed = function (self)
mod.run_gear_clear(self)
end

mod:hook_safe(InventoryWeaponsView, "on_enter", function (self)
ensure_gear_clear_entry(self)
end)

mod:hook(InventoryWeaponsView, "_setup_input_legend", function (func, self, ...)
func(self, ...)
ensure_gear_clear_entry(self)
end)

mod:hook(InventoryWeaponsView, "update", function (func, self, dt, t, input_service, ...)
local result = func(self, dt, t, input_service, ...)

update_gear_clear_view(self, t)

return result
end)
end

local function hook_inventory_background_view(InventoryBackgroundView)
if not InventoryBackgroundView or InventoryBackgroundView.gearclear_inventory_background_hook_token == HOOK_TOKEN then
return
end

InventoryBackgroundView.gearclear_inventory_background_hook_token = HOOK_TOKEN
InventoryBackgroundView.cb_on_gear_clear_pressed = function (self)
mod.run_gear_clear(self, "all")
end

mod:hook_safe(InventoryBackgroundView, "on_enter", function (self)
ensure_gear_clear_entry(self)
end)

mod:hook(InventoryBackgroundView, "_setup_input_legend", function (func, self, ...)
func(self, ...)
ensure_gear_clear_entry(self)
end)

mod:hook(InventoryBackgroundView, "update", function (func, self, dt, t, input_service, ...)
local result = func(self, dt, t, input_service, ...)

update_gear_clear_view(self, t)

return result
end)
end

local function hook_base_view(BaseView)
if not BaseView or BaseView.gearclear_base_view_hook_token == HOOK_TOKEN then
return
end

BaseView.gearclear_base_view_hook_token = HOOK_TOKEN
mod:hook(BaseView, "update", function (func, self, dt, t, input_service, ...)
local pass_input, pass_draw = func(self, dt, t, input_service, ...)

if self and (self.view_name == "inventory_weapons_view" or self.view_name == "inventory_background_view") then
update_gear_clear_view(self, t)
end

return pass_input, pass_draw
end)
end

mod:hook_require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend", hook_input_legend)
mod:hook_require("scripts/ui/views/inventory_weapons_view/inventory_weapons_view", hook_inventory_weapons_view)
mod:hook_require("scripts/ui/views/inventory_background_view/inventory_background_view", hook_inventory_background_view)
mod:hook_require("scripts/ui/views/base_view", hook_base_view)

local input_legend_loaded, ViewElementInputLegend = pcall(require, "scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")

if input_legend_loaded then
hook_input_legend(ViewElementInputLegend)
end

local inventory_weapons_view_loaded, InventoryWeaponsView = pcall(require, "scripts/ui/views/inventory_weapons_view/inventory_weapons_view")

if inventory_weapons_view_loaded then
hook_inventory_weapons_view(InventoryWeaponsView)
end

local inventory_background_view_loaded, InventoryBackgroundView = pcall(require, "scripts/ui/views/inventory_background_view/inventory_background_view")

if inventory_background_view_loaded then
hook_inventory_background_view(InventoryBackgroundView)
end

local base_view_loaded, BaseView = pcall(require, "scripts/ui/views/base_view")

if base_view_loaded then
hook_base_view(BaseView)
end
