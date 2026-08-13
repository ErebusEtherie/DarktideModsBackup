-- valkyrie_business_cards.lua
local mod = get_mod("valkyrie")
local Portraits = Mods.file.dofile("valkyrie/scripts/mods/valkyrie/valkyrie_portraits")
local BUSINESS_CARD_WIDTH = 540
local BUSINESS_CARD_HEIGHT = 166
local BUSINESS_CARD_PADDING = 10
local MORTIS_BUSINESS_CARD_GAP = 12
local BUSINESS_CARD_PORTRAIT_WIDTH = 84
local BUSINESS_CARD_PORTRAIT_HEIGHT = 126
local BUSINESS_CARD_LABEL_WIDTH = 116
local BUSINESS_CARD_LINE_HEIGHT = 18
local BUSINESS_CARD_FONT_SIZE = 15
local BUSINESS_CARD_LAYER = 80
local BUSINESS_CARD_VERTICAL_OFFSET = 90
local BUSINESS_CARD_LABELS = {
"Name:",
"Class:",
"Special Ability:",
"Aura:",
"Blitz:",
"Keystone:",
"Melee:",
"Ranged:",
}
local BUSINESS_CARD_TEXT_COLOR = { 235, 210, 210, 205 }
local BUSINESS_CARD_ICON_COLOR = { 235, 205, 205, 205 }
local BUSINESS_CARD_ORANGE_COLOR = { 255, 220, 134, 58 }
local BUSINESS_CARD_YELLOW_COLOR = { 255, 230, 210, 82 }
local BUSINESS_CARD_GREEN_COLOR = { 255, 120, 190, 88 }
local BUSINESS_CARD_PURPLE_COLOR = { 255, 191, 151, 225 }
local BUSINESS_CARD_LABEL_COLORS = {
BUSINESS_CARD_TEXT_COLOR,
BUSINESS_CARD_TEXT_COLOR,
BUSINESS_CARD_ORANGE_COLOR,
BUSINESS_CARD_YELLOW_COLOR,
BUSINESS_CARD_GREEN_COLOR,
BUSINESS_CARD_PURPLE_COLOR,
BUSINESS_CARD_TEXT_COLOR,
BUSINESS_CARD_TEXT_COLOR,
}
local BUSINESS_CARD_OUTLINE_COLOR = { 255, 0, 0, 0 }
local BUSINESS_CARD_INNER_COLOR = { 175, 20, 20, 20 }
local archetype_class_names = {
adamant = "Arbites",
broker = "Hive Scum",
cryptic = "Skitarius",
ogryn = "Ogryn",
psyker = "Psyker",
veteran = "Veteran",
zealot = "Zealot",
}
local archetype_class_icons = {
adamant = "",
broker = "",
cryptic = "",
ogryn = "",
psyker = "",
veteran = "",
zealot = "",
}
local M = {}
function M.init(ctx)
local UIRenderer = ctx.UIRenderer
local UISettings = ctx.UISettings
local ArchetypeTalents = ctx.ArchetypeTalents
local ProfileUtils = ctx.ProfileUtils
local business_card_portraits = {}
local temp_business_card_slots = {}
function M.clear_state(view)
if view then
view._valkyrie_business_card_slot_order = nil
view._valkyrie_business_card_layout = nil
end
local spawn_slots = view and view._spawn_slots
if spawn_slots then
for i = 1, #spawn_slots do
local slot = spawn_slots[i]
if slot then
slot._valkyrie_business_card = nil
slot._valkyrie_business_card_player_id = nil
end
end
end
for _, portrait in pairs(business_card_portraits) do
local load_id = portrait and portrait.icon_load_id
if load_id and Portraits and Portraits.unload_profile_portrait then
Portraits.unload_profile_portrait(load_id)
end
end
table.clear(business_card_portraits)
table.clear(temp_business_card_slots)
end
function M.clean_card_text(value, fallback)
local text = value
if text == nil or text == "" then
text = fallback or "None"
end
if type(text) ~= "string" then
text = tostring(text)
end
text = string.gsub(text, "{#.-}", "")
text = string.gsub(text, "\n", " ")
text = string.gsub(text, "\r", " ")
return text
end
function M.safe_localize(value, fallback)
if value == nil or value == "" then
return fallback or "None"
end
if type(value) ~= "string" then
return tostring(value)
end
local ok, localized
if Localize then
ok, localized = pcall(Localize, value)
if ok and localized and localized ~= "" and localized ~= value then
return M.clean_card_text(localized, fallback)
end
end
local localization_manager = Managers.localization
if localization_manager and localization_manager.localize then
ok, localized = pcall(localization_manager.localize, localization_manager, value)
if ok and localized and localized ~= "" and localized ~= value then
return M.clean_card_text(localized, fallback)
end
end
return M.clean_card_text(value, fallback)
end
function M.item_card_name(item)
if not item then
return "None"
end
return M.safe_localize(item.display_name or item.display_name_localized or item.name, item.name or "None")
end
function M.talent_card_name(profile, talent_name)
if not talent_name then
return "None"
end
local archetype = profile and profile.archetype
local archetype_name = archetype and archetype.name
local talents = ArchetypeTalents and archetype_name and ArchetypeTalents[archetype_name]
local talent_definition = talents and talents[talent_name]
if talent_definition then
return M.safe_localize(talent_definition.display_name or talent_definition.name or talent_name, talent_name)
end
return M.safe_localize(talent_name, talent_name)
end
function M.selected_talent_name_by_node_type(profile, node_type)
local selected_nodes = profile and profile.selected_nodes
local archetype = profile and profile.archetype
if not selected_nodes or not archetype then
return "None"
end
local layout_keys = {
"talent_layout_file_path",
"specialization_talent_layout_file_path",
}
for i = 1, #layout_keys do
local layout_path = archetype[layout_keys[i]]
if layout_path then
local ok, layout = pcall(require, layout_path)
local nodes = ok and layout and layout.nodes
if nodes then
for node_index = 1, #nodes do
local node = nodes[node_index]
local tier = node and node.widget_name and selected_nodes[node.widget_name]
if node and node.type == node_type and tier and tier > 0 then
return M.talent_card_name(profile, node.talent)
end
end
end
end
end
return "None"
end
function M.capital_initial_words(text)
if not text or text == "" then
return "Unknown"
end
text = tostring(text):gsub("_", " "):lower()
return text:gsub("(%a)([%w']*)", function(first, rest)
return string.upper(first) .. rest
end)
end
function M.profile_class_name(profile)
local archetype = profile and profile.archetype
local archetype_name = archetype and archetype.name
if not archetype_name then
return "Unknown"
end
local class_name = archetype_class_names[archetype_name] or M.safe_localize(archetype.archetype_name or archetype_name, archetype_name)
return M.capital_initial_words(class_name)
end
function M.profile_class_icon(profile)
local archetype = profile and profile.archetype
local archetype_name = archetype and archetype.name
if not archetype_name then
return ""
end
archetype_name = string.lower(tostring(archetype_name))
return archetype_class_icons[archetype_name] or ""
end
function M.business_card_portrait(profile, player)
if not profile then
return nil
end
local key = profile.character_id or profile.identifier or ctx.player_unique_id(player) or tostring(profile)
local portrait = business_card_portraits[key]
local frame_material = UISettings and UISettings.portrait_frame_default_material or "content/ui/materials/base/ui_portrait_frame_base"
local loadout = profile.loadout
local frame_item = loadout and loadout.slot_portrait_frame
if frame_item and frame_item.icon_material and frame_item.icon_material ~= "" then
frame_material = frame_item.icon_material
end
if portrait and portrait.character_id == profile.character_id then
portrait.frame_material = frame_material
return portrait
end
portrait = { character_id = profile.character_id, frame_material = frame_material, loaded = false }
business_card_portraits[key] = portrait
if Portraits and Portraits.load_profile_portrait then
local load_id = Portraits.load_profile_portrait(profile, function(grid_index, rows, columns, render_target)
portrait.loaded = true
portrait.grid_index = (grid_index or 1) - 1
portrait.rows = rows or 1
portrait.columns = columns or 1
portrait.texture_icon = render_target
if portrait.widget then
portrait.widget.dirty = true
end
end, function()
portrait.loaded = false
portrait.texture_icon = nil
if portrait.widget then
portrait.widget.dirty = true
end
end)
if load_id then
portrait.icon_load_id = load_id
end
end
return portrait
end
function M.build_business_card(slot, player_override)
local player = player_override or slot and slot.player
local profile = ctx.player_profile(player)
if not profile then
return nil
end
local player_id = ctx.player_unique_id(player) or tostring(player)
if slot._valkyrie_business_card and slot._valkyrie_business_card_player_id == player_id then
return slot._valkyrie_business_card
end
local loadout = profile.loadout or {}
local class_icon = M.profile_class_icon(profile)
local class_text = M.profile_class_name(profile)
local name = profile.name
if ProfileUtils.character_name then
local ok, character_name = pcall(ProfileUtils.character_name, profile)
name = ok and character_name or name
end
local card = {
M.clean_card_text(name, "Unknown"),
M.clean_card_text(class_text, "Unknown"),
M.selected_talent_name_by_node_type(profile, "ability"),
M.selected_talent_name_by_node_type(profile, "aura"),
M.selected_talent_name_by_node_type(profile, "tactical"),
M.selected_talent_name_by_node_type(profile, "keystone"),
M.item_card_name(loadout.slot_primary),
M.item_card_name(loadout.slot_secondary),
_class_icon = class_icon,
_class_name = class_text,
_portrait = M.business_card_portrait(profile, player),
_is_local = ctx.is_local_player(player),
}
slot._valkyrie_business_card = card
slot._valkyrie_business_card_player_id = player_id
return card
end
function M.cache_for_slot(player, slot)
if not ctx.get_option("business_cards", false) or not slot or not player or ctx.player_is_destroyed(player) then
return
end
M.build_business_card(slot, player)
end
function M.add_business_card_slot(slot, index, lateral, distance_squared)
if not slot then
return
end
temp_business_card_slots[#temp_business_card_slots + 1] = {
index = index,
lateral = lateral or 0,
distance_squared = distance_squared or index,
slot = slot,
}
end
function M.fallback_business_card_slots(spawn_slots)
table.clear(temp_business_card_slots)
for i = 1, math.min(ctx.max_occupants, #spawn_slots) do
M.add_business_card_slot(spawn_slots[i], i, i, i)
end
end
function M.store_mortis_business_card_order(view, spawn_slots)
if not view or not spawn_slots then
return
end
table.clear(temp_business_card_slots)
for i = 1, math.min(ctx.max_occupants, #spawn_slots) do
local slot = spawn_slots[i]
if slot then
local player = slot.player
local is_local = player and ctx.is_local_player(player) == true or false
M.add_business_card_slot(slot, i, is_local and -1 or i, i)
end
end
table.sort(temp_business_card_slots, function(a, b)
if a.lateral ~= b.lateral then
return a.lateral < b.lateral
end
return a.index < b.index
end)
M.store_business_card_order(view)
end
function M.use_stored_business_card_order(view)
local order = view and view._valkyrie_business_card_slot_order
if not order then
return false
end
table.clear(temp_business_card_slots)
for i = 1, math.min(ctx.max_occupants, #order) do
local slot = order[i]
if slot then
M.add_business_card_slot(slot, i, i, i)
end
end
return #temp_business_card_slots > 0
end
function M.store_business_card_order(view)
if not view then
return
end
local order = {}
for i = 1, math.min(ctx.max_occupants, #temp_business_card_slots) do
local entry = temp_business_card_slots[i]
order[i] = entry and entry.slot
end
view._valkyrie_business_card_slot_order = order
end
function M.business_card_layout(view)
if not view then
return ctx.is_mortis_trials and ctx.is_mortis_trials() and "mortis" or "seating"
end
if not view._valkyrie_business_card_layout then
view._valkyrie_business_card_layout = ctx.is_mortis_trials and ctx.is_mortis_trials() and "mortis" or "seating"
end
return view._valkyrie_business_card_layout
end
function M.collect_business_card_slots(view)
local spawn_slots = view and view._spawn_slots
if not spawn_slots then
return 0
end
local layout = M.business_card_layout(view)
if M.use_stored_business_card_order(view) then
return #temp_business_card_slots
end
if layout == "mortis" then
M.store_mortis_business_card_order(view, spawn_slots)
return M.use_stored_business_card_order(view) and #temp_business_card_slots or 0
end
table.clear(temp_business_card_slots)
local world_spawner = view._world_spawner
local _, camera_unit = ctx.steady_camera_camera(world_spawner)
local ok, camera_position, camera_rotation
if ctx.unit_alive(camera_unit) then
ok, camera_position, camera_rotation = pcall(function()
return Unit.world_position(camera_unit, 1), Unit.world_rotation(camera_unit, 1)
end)
end
if not ok or not camera_position or not camera_rotation then
M.fallback_business_card_slots(spawn_slots)
M.store_business_card_order(view)
return #temp_business_card_slots
end
local right_ok, camera_right = pcall(function()
return Vector3.flat(Quaternion.right(camera_rotation))
end)
if not right_ok or not camera_right or Vector3.length_squared(camera_right) <= 0 then
M.fallback_business_card_slots(spawn_slots)
M.store_business_card_order(view)
return #temp_business_card_slots
end
camera_right = Vector3.normalize(camera_right)
for i = 1, math.min(ctx.max_occupants, #spawn_slots) do
local slot = spawn_slots[i]
local spawn_point_unit = slot and slot.spawn_point_unit
if ctx.unit_alive(spawn_point_unit) then
local slot_position = Unit.world_position(spawn_point_unit, 1)
M.add_business_card_slot(slot, i, Vector3.dot(slot_position - camera_position, camera_right), Vector3.length_squared(slot_position - camera_position))
end
end
if #temp_business_card_slots == 0 then
M.fallback_business_card_slots(spawn_slots)
M.store_business_card_order(view)
return #temp_business_card_slots
end
table.sort(temp_business_card_slots, function(a, b)
if math.abs(a.distance_squared - b.distance_squared) <= 0.0001 then
return a.index < b.index
end
return a.distance_squared < b.distance_squared
end)
if temp_business_card_slots[2] and temp_business_card_slots[1].lateral > temp_business_card_slots[2].lateral then
temp_business_card_slots[1], temp_business_card_slots[2] = temp_business_card_slots[2], temp_business_card_slots[1]
end
if temp_business_card_slots[4] and temp_business_card_slots[3].lateral < temp_business_card_slots[4].lateral then
temp_business_card_slots[3], temp_business_card_slots[4] = temp_business_card_slots[4], temp_business_card_slots[3]
end
M.store_business_card_order(view)
return #temp_business_card_slots
end
function M.should_draw_slot_business_card(slot, layout)
local card = slot and slot._valkyrie_business_card
if not card then
return false
end
if layout == "mortis" then
return true
end
return ctx.get_option("business_cards_include_me", true) or card._is_local ~= true
end
function M.ui_viewport_size(optional_scale)
local lookup = RESOLUTION_LOOKUP
local width = lookup and lookup.width or 1920
local height = lookup and lookup.height or 1080
local scale = optional_scale or lookup and lookup.scale or 1
if not scale or scale <= 0 then
scale = 1
end
return width / scale, height / scale
end
function M.clamp_card_position(x, y, viewport_width, viewport_height)
local width = viewport_width or 1920
local height = viewport_height or 1080
local min_x = 8
local min_y = 8
local max_x = math.max(min_x, width - BUSINESS_CARD_WIDTH - 8)
local max_y = math.max(min_y, height - BUSINESS_CARD_HEIGHT - 8)
return math.clamp(x, min_x, max_x), math.clamp(y, min_y, max_y)
end
function M.business_card_position(index, viewport_width, viewport_height)
local width = viewport_width or 1920
local height = viewport_height or 1080
local outer_gap = math.max(40, width * 0.055)
local centre_gap = math.max(30, width * 0.016)
local front_y = height * 0.665 + BUSINESS_CARD_VERTICAL_OFFSET + 35
local rear_y = height * 0.5 + BUSINESS_CARD_VERTICAL_OFFSET
local x = outer_gap
local y = front_y
if index == 2 then
x = width - BUSINESS_CARD_WIDTH - outer_gap
elseif index == 3 then
x = width * 0.5 + centre_gap
y = rear_y
elseif index == 4 then
x = width * 0.5 - BUSINESS_CARD_WIDTH - centre_gap
y = rear_y
end
local clamped_x, clamped_y = M.clamp_card_position(x, y, width, height)
return { clamped_x, clamped_y }
end
function M.mortis_business_card_position(index, viewport_width, viewport_height)
local width = viewport_width or 1920
local height = viewport_height or 1080
local stack_height = BUSINESS_CARD_HEIGHT * ctx.max_occupants + MORTIS_BUSINESS_CARD_GAP * (ctx.max_occupants - 1)
local x = width * 0.97 - BUSINESS_CARD_WIDTH
local y = math.max(8, (height - stack_height) * 0.5) + (index - 1) * (BUSINESS_CARD_HEIGHT + MORTIS_BUSINESS_CARD_GAP)
local clamped_x, clamped_y = M.clamp_card_position(x, y, width, height)
return { clamped_x, clamped_y }
end
function M.card_color(color)
local source = color or BUSINESS_CARD_TEXT_COLOR
return Color(source[1] or 255, source[2] or 255, source[3] or 255, source[4] or 255)
end
function M.safe_draw_business_card_text(ui_renderer, text, font_type, x, y, width, options, color, font_size)
if not text or text == "" then
text = "None"
end
font_size = font_size or BUSINESS_CARD_FONT_SIZE
local text_color = color or BUSINESS_CARD_TEXT_COLOR
local gui = ui_renderer and ui_renderer.gui
if Gui and Gui.slug_text and gui then
local font_path = "content/ui/fonts/proxima_nova_medium"
if font_type == "proxima_nova_bold" then
font_path = "content/ui/fonts/proxima_nova_bold"
elseif font_type == "machine_medium" then
font_path = "content/ui/fonts/machine_medium"
elseif font_type == "arial" then
font_path = "content/ui/fonts/arial"
end
local scale = ui_renderer.scale or 1
local scaled_font_size = math.max(math.floor(font_size * scale), 1)
local position = Vector3(x * scale, y * scale + 2, BUSINESS_CARD_LAYER + 4)
local ok = pcall(Gui.slug_text, gui, text, font_path, scaled_font_size, position, nil, M.card_color(text_color), "shadow", Color(255, 0, 0, 0))
if ok then
return
end
end
local ok = pcall(UIRenderer.draw_text, ui_renderer, text, font_size, font_type, Vector3(x, y, BUSINESS_CARD_LAYER + 4), Vector2(width, BUSINESS_CARD_LINE_HEIGHT), text_color, options)
if not ok and font_type ~= "arial" then
pcall(UIRenderer.draw_text, ui_renderer, text, font_size, "arial", Vector3(x, y, BUSINESS_CARD_LAYER + 4), Vector2(width, BUSINESS_CARD_LINE_HEIGHT), text_color, options)
end
end
function M.draw_business_card_class_icon(ui_renderer, card, x, y)
local icon = card and card._class_icon
if not icon or icon == "" or card._class_icon_widget_failed then
return
end
local ok = pcall(function()
if mod._valkyrie_ui_widget == nil then
local require_ok, ui_widget = pcall(require, "scripts/managers/ui/ui_widget")
mod._valkyrie_ui_widget = require_ok and ui_widget or false
end
local ui_widget = mod._valkyrie_ui_widget
if not ui_widget then
return
end
local icon_size = math.floor((BUSINESS_CARD_FONT_SIZE - 1) * 3.89 + 0.5)
local icon_box = icon_size + 14
local icon_gap = BUSINESS_CARD_PADDING + 8
local icon_x = x + BUSINESS_CARD_WIDTH - icon_gap - icon_box
local icon_y = y + BUSINESS_CARD_PADDING + 6
local widget = card._class_icon_widget
if not widget or not widget.style or not widget.style.icon or widget._valkyrie_single_icon ~= true then
local definition = ui_widget.create_definition({
{
pass_type = "text",
style_id = "icon",
value = "",
value_id = "icon",
style = {
font_size = icon_size,
font_type = "machine_medium",
horizontal_alignment = "center",
vertical_alignment = "center",
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
text_color = BUSINESS_CARD_ICON_COLOR,
color = BUSINESS_CARD_ICON_COLOR,
size = { icon_box, icon_box },
offset = { 0, 0, BUSINESS_CARD_LAYER + 6 },
},
},
}, "canvas", nil, { icon_box, icon_box })
widget = ui_widget.init("valkyrie_business_card_class_icon", definition)
card._class_icon_widget = widget
widget._valkyrie_single_icon = true
end
widget.offset = widget.offset or { 0, 0, 0 }
widget.offset[1] = icon_x
widget.offset[2] = icon_y
widget.offset[3] = 0
widget.content.icon = icon
widget.style.icon.font_size = icon_size
widget.style.icon.size[1] = icon_box
widget.style.icon.size[2] = icon_box
widget.style.icon.text_color = BUSINESS_CARD_ICON_COLOR
widget.style.icon.color = BUSINESS_CARD_ICON_COLOR
local draw_ok = pcall(ui_widget.draw, widget, ui_renderer)
if not draw_ok then
error("UIWidget draw failed")
end
end)
if not ok then
card._class_icon_widget_failed = true
card._class_icon_widget = nil
end
end
function M.draw_business_card_portrait(ui_renderer, portrait, x, y)
if not portrait then
return
end
if mod._valkyrie_ui_widget == nil then
local ok, ui_widget = pcall(require, "scripts/managers/ui/ui_widget")
mod._valkyrie_ui_widget = ok and ui_widget or false
end
local ui_widget = mod._valkyrie_ui_widget
if not ui_widget then
return
end
local widget = portrait.widget
if not widget then
local definition = ui_widget.create_definition({
{
pass_type = "texture",
style_id = "texture",
value = "content/ui/materials/base/ui_portrait_frame_base",
value_id = "texture",
style = {
color = { 255, 255, 255, 255 },
offset = { 0, 0, BUSINESS_CARD_LAYER + 3 },
size = { BUSINESS_CARD_PORTRAIT_WIDTH, BUSINESS_CARD_PORTRAIT_HEIGHT },
material_values = {
use_placeholder_texture = 1,
use_render_target = 0,
rows = 1,
columns = 1,
grid_index = 0,
portrait_frame_texture = "content/ui/textures/nameplates/portrait_frames/default",
},
},
},
}, "canvas", nil, { BUSINESS_CARD_PORTRAIT_WIDTH, BUSINESS_CARD_PORTRAIT_HEIGHT })
widget = ui_widget.init("valkyrie_business_card_portrait", definition)
portrait.widget = widget
end
widget.offset = widget.offset or { 0, 0, 0 }
widget.offset[1] = x
widget.offset[2] = y
widget.offset[3] = 0
widget.content.texture = portrait.frame_material or "content/ui/materials/base/ui_portrait_frame_base"
local material_values = widget.style.texture.material_values
if portrait.loaded and portrait.texture_icon then
material_values.use_placeholder_texture = 0
material_values.use_render_target = 1
material_values.rows = portrait.rows or 1
material_values.columns = portrait.columns or 1
material_values.grid_index = portrait.grid_index or 0
material_values.texture_icon = portrait.texture_icon
else
material_values.use_placeholder_texture = 1
material_values.use_render_target = 0
material_values.texture_icon = nil
end
pcall(ui_widget.draw, widget, ui_renderer)
end
function M.draw_business_card(ui_renderer, card, x, y)
UIRenderer.draw_rect(ui_renderer, Vector3(x, y, BUSINESS_CARD_LAYER), Vector2(BUSINESS_CARD_WIDTH, BUSINESS_CARD_HEIGHT), BUSINESS_CARD_OUTLINE_COLOR)
UIRenderer.draw_rect(ui_renderer, Vector3(x + 2, y + 2, BUSINESS_CARD_LAYER + 1), Vector2(BUSINESS_CARD_WIDTH - 4, BUSINESS_CARD_HEIGHT - 4), BUSINESS_CARD_INNER_COLOR)
M.draw_business_card_portrait(ui_renderer, card._portrait, x + BUSINESS_CARD_PADDING, y + BUSINESS_CARD_PADDING + 11)
M.draw_business_card_class_icon(ui_renderer, card, x, y)
local text_x = x + BUSINESS_CARD_PADDING + BUSINESS_CARD_PORTRAIT_WIDTH + 16
local value_x = text_x + BUSINESS_CARD_LABEL_WIDTH
local value_width = BUSINESS_CARD_WIDTH - BUSINESS_CARD_PADDING - value_x + x
for i = 1, #BUSINESS_CARD_LABELS do
local line_y = y + BUSINESS_CARD_PADDING + (i - 1) * BUSINESS_CARD_LINE_HEIGHT
M.safe_draw_business_card_text(ui_renderer, BUSINESS_CARD_LABELS[i], "proxima_nova_bold", text_x, line_y, BUSINESS_CARD_LABEL_WIDTH, nil, BUSINESS_CARD_LABEL_COLORS[i])
M.safe_draw_business_card_text(ui_renderer, card[i] or "None", "proxima_nova_medium", value_x, line_y, value_width, nil)
end
end
function M.draw_cards(view, dt, input_service, layer)
if not (mod:is_enabled() and ctx.in_mission_intro() and ctx.get_option("business_cards", false)) then
return
end
local ui_renderer = view and view._ui_renderer
local ui_scenegraph = view and view._ui_scenegraph
local render_settings = view and view._render_settings
if not ui_renderer or not ui_scenegraph or not render_settings or not UIRenderer then
return
end
if not UIRenderer.begin_pass or not UIRenderer.end_pass or not UIRenderer.draw_rect or not UIRenderer.draw_text then
return
end
local count = M.collect_business_card_slots(view)
if count == 0 then
return
end
local layout = M.business_card_layout(view)
local old_start_layer = render_settings.start_layer
local old_scale = render_settings.scale
local old_inverse_scale = render_settings.inverse_scale
local old_alpha_multiplier = render_settings.alpha_multiplier
local old_color_intensity_multiplier = render_settings.color_intensity_multiplier
local old_material_flags = render_settings.material_flags
local render_scale = view._render_scale or render_settings.scale or RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.scale or 1
if not render_scale or render_scale <= 0 then
render_scale = 1
end
local viewport_width, viewport_height = M.ui_viewport_size(render_scale)
render_settings.start_layer = old_start_layer or layer or 0
render_settings.scale = render_scale
render_settings.inverse_scale = 1 / render_scale
render_settings.alpha_multiplier = render_settings.alpha_multiplier or 1
render_settings.color_intensity_multiplier = 1
render_settings.material_flags = 0
local begin_ok = pcall(UIRenderer.begin_pass, ui_renderer, ui_scenegraph, input_service, dt, render_settings)
if begin_ok then
for i = 1, math.min(count, ctx.max_occupants) do
local entry = temp_business_card_slots[i]
local slot = entry and entry.slot
if M.should_draw_slot_business_card(slot, layout) then
local card = slot._valkyrie_business_card
local position = layout == "mortis" and M.mortis_business_card_position(i, viewport_width, viewport_height) or M.business_card_position(i, viewport_width, viewport_height)
if card and position then
pcall(M.draw_business_card, ui_renderer, card, position[1], position[2])
end
end
end
pcall(UIRenderer.end_pass, ui_renderer)
end
render_settings.start_layer = old_start_layer
render_settings.scale = old_scale
render_settings.inverse_scale = old_inverse_scale
render_settings.alpha_multiplier = old_alpha_multiplier
render_settings.color_intensity_multiplier = old_color_intensity_multiplier
render_settings.material_flags = old_material_flags
end
mod._bc = M
return M
end
return M
