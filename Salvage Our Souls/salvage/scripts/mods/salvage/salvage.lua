-- salvage.lua
local mod = get_mod("salvage")
local exits = Mods.file.dofile("salvage/scripts/mods/salvage/salvage_exits")
local UIWidget = require("scripts/managers/ui/ui_widget")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")

local ROOT_NODE_INDEX = 1
local DEFAULT_HEIGHT = 0.3
local PULSE_INTERVAL = 0.9
local REPEAT_INTERVAL = 1
local PULSE_EFFECT_ID = "staggering_pulse"
local SYNC_INTERVAL = 0.25
local FALLEN_MARKER_SYNC_INTERVAL = 0.5
local PLAYER_DROP_MARKER_SYNC_INTERVAL = 0.5
local DECAL_PATH = "content/levels/training_grounds/fx/decal_aoe_indicator"
local DECAL_PACKAGE_PATH = "content/levels/training_grounds/missions/mission_tg_basic_combat_01"
local DECAL_RADIUS = 1
local FIRE_360_RADIUS_VARIABLE = "radius"
local FALLEN_MARKER_TYPE = "salvage_fallen_comrade_marker"
local FALLEN_MARKER_PENDING = "pending"
local FALLEN_MARKER_ICON = ""
local FALLEN_MARKER_REASON_DEATH = "death"
local FALLEN_MARKER_REASON_DISABLED = "disabled"
local FALLEN_MARKER_BASE_FONT_SIZE = 56
local FALLEN_MARKER_DEATH_FONT_SIZE = math.floor(FALLEN_MARKER_BASE_FONT_SIZE * 1.3 + 0.5)
local FALLEN_MARKER_DISABLED_FONT_SIZE = 45
local FALLEN_MARKER_WIDGET_SIZE = 128
local FALLEN_MARKER_MAX_DISTANCE = 1000
local FALLEN_MARKER_CLOSE_DISTANCE = 3
local FALLEN_MARKER_POSITION_OFFSET = { 0, 0, 1.25 }
local FALLEN_MARKER_DEATH_COLOUR = { 255, 255, 0, 0 }
local FALLEN_MARKER_DISABLED_COLOUR = { 255, 255, 84, 0 }
local FALLEN_MARKER_SHADOW = { 220, 0, 0, 0 }
local FALLEN_MARKER_INVISIBLE = { 0, 0, 0, 0 }
local PLAYER_DROP_MARKER_TYPE = "salvage_player_drop_marker"
local PLAYER_DROP_MARKER_PENDING = "pending"
local PLAYER_DROP_MARKER_ICON = ""
local PLAYER_DROP_MARKER_BASE_FONT_SIZE = 66
local PLAYER_DROP_MARKER_DISABLED_FONT_SIZE = PLAYER_DROP_MARKER_BASE_FONT_SIZE
local PLAYER_DROP_MARKER_DEATH_FONT_SIZE = PLAYER_DROP_MARKER_BASE_FONT_SIZE
local PLAYER_DROP_MARKER_WIDGET_SIZE = 528
local PLAYER_DROP_MARKER_MAX_DISTANCE = 1000
local PLAYER_DROP_MARKER_POSITION_OFFSET = { 0, 0, 0.65 }
local PLAYER_DROP_MARKER_DEATH_COLOUR = { 255, 255, 0, 0 }
local PLAYER_DROP_MARKER_DISABLED_COLOUR = { 255, 255, 84, 0 }
local PLAYER_DROP_MARKER_SHADOW = { 220, 0, 0, 0 }
local PLAYER_DROP_MARKER_INVISIBLE = { 0, 0, 0, 0 }
mod._salvage_player_drop_worth_warning = mod._salvage_player_drop_worth_warning or { last_amount = nil, last_t = -999 }
mod._salvage_recent_player_drop_worth = mod._salvage_recent_player_drop_worth or { amount = nil, time = -999 }
local PLAYER_DROP_PICKUP_TYPE = "expedition_loot_player_drop"
local PLAYER_DROP_REASON_DEATH = "death"
local PLAYER_DROP_REASON_DISABLED = "disabled"
local PLAYER_DROP_RECENT_DURATION = 8
local PLAYER_DROP_RECENT_MATCH_DISTANCE = 12
local RELIQUARY_EFFECT = {
id = "reliquary_fixed_effect",
vfx = "content/fx/particles/player_buffs/buff_electricity_one_target_01",
}

local tracked_effects_by_unit = setmetatable({}, { __mode = "k" })
local tracked_decals_by_unit = setmetatable({}, { __mode = "k" })
local tracked_pickups_by_unit = setmetatable({}, { __mode = "k" })
local tracked_fallen_markers_by_unit = setmetatable({}, { __mode = "k" })
local tracked_player_drop_markers_by_unit = setmetatable({}, { __mode = "k" })
mod._salvage_player_drop_worth_markers_by_unit = mod._salvage_player_drop_worth_markers_by_unit or setmetatable({}, { __mode = "k" })
local tracked_player_drop_pickups_by_unit = setmetatable({}, { __mode = "k" })
mod._salvage_player_drop_worth_by_unit = mod._salvage_player_drop_worth_by_unit or setmetatable({}, { __mode = "k" })
local found_fallen_comrades_by_unit = setmetatable({}, { __mode = "k" })
local recent_player_drop_records = {}
mod._salvage_pending_player_drop_worth_records = mod._salvage_pending_player_drop_worth_records or {}
mod._salvage_stolen_loot_by_minion_unit = mod._salvage_stolen_loot_by_minion_unit or setmetatable({}, { __mode = "k" })
local observed_local_player_drop_states_by_unit = setmetatable({}, { __mode = "k" })
local function pickup_type_from_unit(unit)
if not unit or not Unit or not Unit.alive or not Unit.has_data or not Unit.get_data then
return nil
end

local alive_success, alive = pcall(Unit.alive, unit)

if not alive_success or not alive then
return nil
end

local has_data_success, has_data = pcall(Unit.has_data, unit, "pickup_type")

if not has_data_success or not has_data then
return nil
end

local get_data_success, pickup_type = pcall(Unit.get_data, unit, "pickup_type")

if get_data_success then
return pickup_type
end

return nil
end
local decal_package_loading = false
local sync_timer = SYNC_INTERVAL
local fallen_marker_sync_timer = FALLEN_MARKER_SYNC_INTERVAL
local player_drop_marker_sync_timer = PLAYER_DROP_MARKER_SYNC_INTERVAL

local EFFECTS = {
{
id = "fire_360angle_01",
vfx = "content/fx/particles/player_buffs/buff_fire_360angle_01",
},
{
id = "fire_trail_01",
vfx = "content/fx/particles/player_buffs/buff_fire_trail_01",
},
{
id = "staggering_pulse",
vfx = "content/fx/particles/player_buffs/buff_staggering_pulse",
},
{
id = "electricity_grenade_01",
vfx = "content/fx/particles/player_buffs/buff_electricity_grenade_01",
},
{
id = "daemonhost_shield",
vfx = "content/fx/particles/enemies/chaos_mutator_daemonhost_shield",
},
}

local CATEGORIES = {
{
id = "salvage",
uses_effect_options = true,
decal = {
setting_id = "salvage_blue_decal",
red = 30 / 255,
green = 144 / 255,
blue = 255 / 255,
alpha = 1,
},
types = {
expedition_currency_small_tier_1 = true,
expedition_currency_small_tier_2 = true,
},
},
{
id = "tech_remnants",
uses_effect_options = true,
decal = {
setting_id = "tech_remnants_green_decal",
red = 74 / 255,
green = 199 / 255,
blue = 60 / 255,
alpha = 1,
},
types = {
expedition_loot_small_tier_1 = true,
expedition_loot_small_tier_2 = true,
expedition_loot_small_tier_3 = true,
expedition_loot_player_drop = true,
},
},
{
id = "reliquaries",
fixed_effect = RELIQUARY_EFFECT,
types = {
expedition_loot_heavy_tier_1 = true,
expedition_loot_heavy_tier_2 = true,
expedition_loot_heavy_tier_3 = true,
},
},
}

local function clear_table(target)
if table.clear then
table.clear(target)

return
end

for key, _ in pairs(target) do
target[key] = nil
end
end

local function safe_call(object, method_name)
local method = object and object[method_name]

if type(method) ~= "function" then
return nil
end

local success, result = pcall(method, object)

if success then
return result
end

return nil
end

local function game_mode_manager()
return Managers and Managers.state and Managers.state.game_mode
end

local function mechanism_data()
local mechanism = Managers and Managers.mechanism and Managers.mechanism._mechanism

return mechanism and mechanism._mechanism_data or nil
end

local function mechanism_is_expedition()
local data = mechanism_data()

return data and (data.expedition_template_name ~= nil or data.node_id ~= nil) or false
end

local function is_expedition()
local manager = game_mode_manager()

if manager then
local name = safe_call(manager, "game_mode_name")

if name == "expedition" then
return true
end

if name ~= nil then
return false
end

local game_mode = safe_call(manager, "game_mode")
local game_mode_name = safe_call(game_mode, "name")

if game_mode_name == "expedition" then
return true
end

if game_mode_name ~= nil then
return false
end
end

return mechanism_is_expedition()
end

local function in_safe_zone()
local manager = game_mode_manager()
local game_mode = manager and safe_call(manager, "game_mode")
local game_mode_safe_zone = safe_call(game_mode, "in_safe_zone")

if game_mode_safe_zone ~= nil then
return game_mode_safe_zone == true
end

local pacing = Managers and Managers.state and Managers.state.pacing
local pacing_safe_zone = safe_call(pacing, "get_in_safe_zone")

return pacing_safe_zone == true
end

local function should_run()
if mod.is_enabled and not mod:is_enabled() then
return false
end

return is_expedition() and not in_safe_zone()
end

local function is_alive_unit(unit)
return type(unit) == "userdata" and Unit and Unit.alive and Unit.alive(unit)
end

local function is_valid_unit(unit)
if type(unit) ~= "userdata" or not Unit then
return false
end

if Unit.is_valid then
local success, valid = pcall(Unit.is_valid, unit)

if success then
return valid == true
end
end

return Unit.alive and Unit.alive(unit) or false
end

local function category_for_pickup_type(pickup_type)
if not pickup_type then
return nil
end

for i = 1, #CATEGORIES do
local category = CATEGORIES[i]

if category.types[pickup_type] then
return category
end
end

return nil
end

local function category_enabled(category)
return category and mod:get("enable_" .. category.id) ~= false
end

local function effect_enabled(category, effect)
return category and category.uses_effect_options and category_enabled(category) and mod:get(category.id .. "_" .. effect.id) == true
end

local function decal_enabled(category)
return category and category.decal and category_enabled(category) and mod:get(category.decal.setting_id) == true
end

local function category_has_particle_effect(category)
if not category_enabled(category) then
return false
end

if category.fixed_effect then
return true
end

for i = 1, #EFFECTS do
if effect_enabled(category, EFFECTS[i]) then
return true
end
end

return false
end

local function category_has_any_effect(category)
return category_has_particle_effect(category) or decal_enabled(category)
end

local function is_salvage_effect_setting(setting_id)
if type(setting_id) ~= "string" then
return true
end

return setting_id == "enable_reliquaries" or setting_id == "enable_salvage" or setting_id == "enable_tech_remnants" or string.sub(setting_id, 1, 8) == "salvage_" or string.sub(setting_id, 1, 14) == "tech_remnants_"
end

local MENU_PARENT_SETTING_IDS_BY_NAME = {
["Use Exit Markers"] = "use_exit_icon",
["Use Salvage Effects"] = "enable_salvage",
["Use Tech Remnants Effects"] = "enable_tech_remnants",
}

local CHILD_MENU_VALIDATIONS = {}

local function strip_colour_tags(text)
if type(text) ~= "string" then
return text
end

return string.gsub(string.gsub(text, "{%#.-%}", ""), "​", "")
end

local function menu_parent_setting_id(setting)
local display_name = setting and setting.display_name
local plain_display_name = strip_colour_tags(display_name)
local setting_id = setting and setting.setting_id

return MENU_PARENT_SETTING_IDS_BY_NAME[plain_display_name] or setting_id == "use_exit_icon" and "use_exit_icon" or setting_id == "enable_salvage" and "enable_salvage" or setting_id == "enable_tech_remnants" and "enable_tech_remnants" or nil
end

local function child_menu_validation(parent_setting_id)
local validation_function = CHILD_MENU_VALIDATIONS[parent_setting_id]

if not validation_function then
validation_function = function()
return mod:get(parent_setting_id) ~= false
end
CHILD_MENU_VALIDATIONS[parent_setting_id] = validation_function
end

return validation_function
end

local function is_salvage_options_category(category)
return strip_colour_tags(category) == "Salvage Our Souls"
end

function mod._salvage_patch_child_setting(setting, parent_setting_id)
if setting._salvage_original_hidden == nil then
setting._salvage_original_hidden = setting.hidden == true
end

local suffix = parent_setting_id == "enable_salvage" and "​" or parent_setting_id == "enable_tech_remnants" and "​​" or parent_setting_id == "use_exit_icon" and "​​​" or nil

if suffix and type(setting.display_name) == "string" then
if setting._salvage_original_display_name == nil then
setting._salvage_original_display_name = strip_colour_tags(setting.display_name)
end

setting.display_name = setting._salvage_original_display_name .. suffix
end

setting.validation_function = child_menu_validation(parent_setting_id)
setting.hidden = setting._salvage_original_hidden == true
setting.indentation_level = math.max(1, setting.indentation_level or 0)
end

local function patch_menu_hidden_children(options_templates)
local settings = options_templates and options_templates.settings

if type(settings) ~= "table" then
return options_templates
end

local active_parent_setting_id = nil
local active_parent_indent = nil

for i = 1, #settings do
local setting = settings[i]
local category = setting and setting.category
local indentation_level = setting and setting.indentation_level or setting and setting.depth or 0

if not is_salvage_options_category(category) then
active_parent_setting_id = nil
active_parent_indent = nil
else
local parent_setting_id = menu_parent_setting_id(setting)

if parent_setting_id then
active_parent_setting_id = parent_setting_id
active_parent_indent = indentation_level
elseif active_parent_setting_id and indentation_level > active_parent_indent then
mod._salvage_patch_child_setting(setting, active_parent_setting_id)
elseif active_parent_setting_id and indentation_level <= active_parent_indent then
active_parent_setting_id = nil
active_parent_indent = nil
end
end
end

return options_templates
end

local function install_menu_hidden_children_patch()
if mod._salvage_menu_hidden_children_patch_done then
return
end

local dmf = get_mod and get_mod("DMF")

if not dmf or type(dmf.create_mod_options_settings) ~= "function" then
return
end

mod._salvage_menu_hidden_children_patch_done = true

local create_mod_options_settings = dmf.create_mod_options_settings

dmf.create_mod_options_settings = function(self, options_templates)
local result = create_mod_options_settings(self, options_templates)

patch_menu_hidden_children(result or options_templates)

return result
end
end


local MENU_FONT_SCALE = 0.75
local MENU_ROW_SCALE = 0.55
local MENU_CHILD_FONT_SCALE = 0.64
local MENU_CHILD_ROW_SCALE = 0.47
local MENU_FONT_TYPE = "rexlia"
local MENU_MIN_FONT_SIZE = 8
local MENU_MIN_ROW_HEIGHT = 28
local MENU_SETTINGS_GRID_INDEX = 2
local MENU_GRID_SPACING = { 0, 3 }
local MENU_DESCRIPTION_GAP_SCALE = 0.5

local MENU_SETTING_WIDGET_TYPES = {
checkbox = true,
dropdown = true,
value_slider = true,
percent_slider = true,
keybind = true,
button = true,
settings_button = true,
}

local function compact_menu_number(value, scale, minimum)
if type(value) ~= "number" then
return value
end

local scaled = math.floor(value * scale + 0.5)

if scaled < minimum then
return minimum
end

return scaled
end

local function clone_menu_table(source)
if type(source) ~= "table" then
return source
end

local clone = {}

for key, value in pairs(source) do
clone[key] = value
end

return clone
end

local function clone_menu_style_data(style_data)
if type(style_data) ~= "table" then
return style_data
end

local clone = {}

for key, value in pairs(style_data) do
if key == "size" or key == "default_size" or key == "offset" or key == "color" or key == "text_color" then
clone[key] = clone_menu_table(value)
else
clone[key] = value
end
end

return clone
end

local function isolate_menu_widget_style(widget)
if not widget or widget._salvage_menu_style_isolated then
return
end

local style = widget.style

if type(style) ~= "table" then
return
end

local isolated_style = {}

for style_id, style_data in pairs(style) do
isolated_style[style_id] = clone_menu_style_data(style_data)
end

widget.style = isolated_style
widget._salvage_menu_style_isolated = true
end

local function isolate_menu_alignment(alignment_widget)
if type(alignment_widget) ~= "table" or alignment_widget._salvage_menu_alignment_isolated then
return
end

if type(alignment_widget.size) == "table" then
alignment_widget._salvage_original_alignment_size = clone_menu_table(alignment_widget.size)
alignment_widget.size = clone_menu_table(alignment_widget.size)
end

local content = alignment_widget.content

if type(content) == "table" and type(content.size) == "table" then
content._salvage_original_size = clone_menu_table(content.size)
content.size = clone_menu_table(content.size)
end

alignment_widget._salvage_menu_alignment_isolated = true
end

local function apply_menu_font_scale(style_data, font_scale)
if type(style_data) ~= "table" then
return false
end

local font_size = style_data.font_size

if type(font_size) ~= "number" then
return false
end

local original_font_size = style_data._salvage_original_font_size or font_size
style_data._salvage_original_font_size = original_font_size
style_data._salvage_original_font_type = style_data._salvage_original_font_type or style_data.font_type
local compact_font_size = compact_menu_number(original_font_size, font_scale or MENU_FONT_SCALE, MENU_MIN_FONT_SIZE)
local changed = false

if style_data.font_size ~= compact_font_size then
style_data.font_size = compact_font_size
changed = true
end

if style_data.font_type ~= MENU_FONT_TYPE then
style_data.font_type = MENU_FONT_TYPE
changed = true
end

return changed
end

local function apply_menu_style_row_scale(style_data, row_scale)
if type(style_data) ~= "table" then
return false
end

local size = style_data.size

if type(size) ~= "table" or type(size[2]) ~= "number" or size[2] < MENU_MIN_ROW_HEIGHT then
return false
end

local original_size_y = style_data._salvage_original_size_y or size[2]
style_data._salvage_original_size_y = original_size_y
local compact_size_y = compact_menu_number(original_size_y, row_scale or MENU_ROW_SCALE, MENU_MIN_ROW_HEIGHT)

if size[2] ~= compact_size_y then
size[2] = compact_size_y
return true
end

return false
end

local function apply_menu_content_row_scale(widget, row_scale)
local content = widget and widget.content

if type(content) ~= "table" or type(content.size) ~= "table" or type(content.size[2]) ~= "number" then
return false
end

local original_size_y = content._salvage_original_size_y or content.size[2]
content._salvage_original_size_y = original_size_y
local compact_size_y = compact_menu_number(original_size_y, row_scale or MENU_ROW_SCALE, MENU_MIN_ROW_HEIGHT)

if content.size[2] ~= compact_size_y then
content.size[2] = compact_size_y
return true
end

return false
end

local function apply_menu_alignment_row_scale(alignment_widget, row_scale)
if type(alignment_widget) ~= "table" or type(alignment_widget.size) ~= "table" or type(alignment_widget.size[2]) ~= "number" then
return false
end

local original_size_y = alignment_widget._salvage_original_alignment_size_y or alignment_widget.size[2]
alignment_widget._salvage_original_alignment_size_y = original_size_y
local compact_size_y = compact_menu_number(original_size_y, row_scale or MENU_ROW_SCALE, MENU_MIN_ROW_HEIGHT)

if alignment_widget.size[2] ~= compact_size_y then
alignment_widget.size[2] = compact_size_y
return true
end

return false
end

function mod._salvage_menu_dropdown_foldout_style(style_id)
if type(style_id) ~= "string" then
return false
end

return style_id == "dropdown_background" or string.sub(style_id, 1, 10) == "scrollbar_" or style_id == "thumb" or string.sub(style_id, 1, 7) == "option_" or string.sub(style_id, 1, 8) == "outline_"
end

local function compact_menu_dropdown_content(widget, alignment_widget)
if not widget or widget.type ~= "dropdown" or type(widget.content) ~= "table" then
return false
end

local content = widget.content
local num_visible_options = content.num_visible_options

if type(num_visible_options) ~= "number" then
return false
end

local row_height = content._salvage_original_size_y

if type(row_height) ~= "number" and type(alignment_widget) == "table" then
row_height = alignment_widget._salvage_original_alignment_size_y
end

if type(row_height) ~= "number" and type(content.size) == "table" then
row_height = content.size[2]
end

if type(row_height) ~= "number" or row_height < MENU_MIN_ROW_HEIGHT then
row_height = MENU_MIN_ROW_HEIGHT
end

local options = content.options
local num_options = type(options) == "table" and #options or num_visible_options
local area_length = row_height * num_visible_options
local scroll_length = math.max(row_height * num_options - area_length, 0)
local changed = content.area_length ~= area_length or content.scroll_length ~= scroll_length or content.scroll_amount ~= (scroll_length > 0 and row_height / scroll_length or 0)
content.area_length = area_length
content.scroll_length = scroll_length
content.scroll_amount = scroll_length > 0 and row_height / scroll_length or 0

return changed
end

local function menu_row_is_child(row)
local entry = row and row.widget and row.widget.content and row.widget.content.entry

return type(entry) == "table" and type(entry.indentation_level) == "number" and entry.indentation_level > 0
end

local function apply_menu_description_gap_scale(widget, alignment_widget)
if not widget or widget.type ~= "description" then
return false
end

local content = widget.content

if type(content) ~= "table" or type(content.size) ~= "table" or type(content.size[2]) ~= "number" then
return false
end

local original_content_size_y = content._salvage_original_size_y or content.size[2]
content._salvage_original_size_y = original_content_size_y
local original_alignment_size_y = original_content_size_y

if type(alignment_widget) == "table" and type(alignment_widget.size) == "table" and type(alignment_widget.size[2]) == "number" then
original_alignment_size_y = alignment_widget._salvage_original_alignment_size_y or alignment_widget.size[2]
alignment_widget._salvage_original_alignment_size_y = original_alignment_size_y
end

local padding = math.max(original_alignment_size_y - original_content_size_y, 0)
local compact_size_y = math.floor(original_content_size_y + padding * MENU_DESCRIPTION_GAP_SCALE + 0.5)

if compact_size_y < original_content_size_y then
compact_size_y = original_content_size_y
end

local changed = false

if content.size[2] ~= compact_size_y then
content.size[2] = compact_size_y
changed = true
end

if type(alignment_widget) == "table" and type(alignment_widget.size) == "table" and type(alignment_widget.size[2]) == "number" and alignment_widget.size[2] ~= compact_size_y then
alignment_widget.size[2] = compact_size_y
changed = true
end

return changed
end

local function compact_menu_row(row)
local widget = row and row.widget
local alignment_widget = row and row.alignment_widget

if not widget then
return false
end

local shrink_row = MENU_SETTING_WIDGET_TYPES[widget.type] == true
local shrink_description_gap = widget.type == "description"
local is_child = menu_row_is_child(row)
local font_scale = is_child and MENU_CHILD_FONT_SCALE or MENU_FONT_SCALE
local row_scale = is_child and MENU_CHILD_ROW_SCALE or MENU_ROW_SCALE
local changed = false

isolate_menu_widget_style(widget)
isolate_menu_alignment(alignment_widget)

local style = widget.style

if type(style) == "table" then
for style_id, style_data in pairs(style) do
if apply_menu_font_scale(style_data, font_scale) then
changed = true
end

local skip_row_scale = widget.type == "dropdown" and mod._salvage_menu_dropdown_foldout_style(style_id)

if shrink_row and not skip_row_scale and apply_menu_style_row_scale(style_data, row_scale) then
changed = true
end
end
end

if shrink_row and apply_menu_content_row_scale(widget, row_scale) then
changed = true
end

if shrink_row and apply_menu_alignment_row_scale(alignment_widget, row_scale) then
changed = true
end

if shrink_description_gap and apply_menu_description_gap_scale(widget, alignment_widget) then
changed = true
end

if shrink_row and compact_menu_dropdown_content(widget, alignment_widget) then
changed = true
end

return changed
end

local function rebuild_salvage_settings_grid(view)
if not view or type(view._setup_grid) ~= "function" then
return
end

local widgets = view._settings_content_widgets
local alignment_widgets = view._settings_alignment_list

if type(widgets) ~= "table" or type(alignment_widgets) ~= "table" then
return
end

local grid_scenegraph_id = "settings_grid_background"
local grid_pivot_scenegraph_id = "settings_grid_content_pivot"
local scrollbar_widget_id = "settings_scrollbar"
local spacing = clone_menu_table(MENU_GRID_SPACING)

view._settings_content_grid = view:_setup_grid(widgets, alignment_widgets, grid_scenegraph_id, spacing, false)

if type(view._setup_content_grid_scrollbar) == "function" then
view:_setup_content_grid_scrollbar(view._settings_content_grid, scrollbar_widget_id, grid_scenegraph_id, grid_pivot_scenegraph_id)
end

if type(view._navigation_widgets) == "table" then
view._navigation_widgets[MENU_SETTINGS_GRID_INDEX] = widgets
end

if type(view._navigation_grids) == "table" then
view._navigation_grids[MENU_SETTINGS_GRID_INDEX] = view._settings_content_grid
end

if type(view._update_grid_navigation_selection) == "function" then
view:_update_grid_navigation_selection()
end
end

local function compact_salvage_visible_rows(view)
local rows = view and view._settings_content_widgets
local alignments = view and view._settings_alignment_list

if type(rows) ~= "table" or type(alignments) ~= "table" then
return false
end

local changed = false

for i = 1, #rows do
local row = {
widget = rows[i],
alignment_widget = alignments[i],
}

if compact_menu_row(row) then
changed = true
end
end

return changed
end

local function compact_salvage_category_rows(view, category)
local settings_category_widgets = view and view._settings_category_widgets
local category_rows = type(settings_category_widgets) == "table" and settings_category_widgets[category]

if type(category_rows) ~= "table" then
return false
end

local changed = false

for i = 1, #category_rows do
if compact_menu_row(category_rows[i]) then
changed = true
end
end

return changed
end

local function salvage_content_matches_category_rows(view, category)
local settings_category_widgets = view and view._settings_category_widgets
local category_rows = type(settings_category_widgets) == "table" and settings_category_widgets[category]
local content_widgets = view and view._settings_content_widgets

if type(category_rows) ~= "table" or type(content_widgets) ~= "table" or #category_rows ~= #content_widgets then
return false
end

for i = 1, #category_rows do
if content_widgets[i] ~= category_rows[i].widget then
return false
end
end

return true
end

local function salvage_menu_signature(view)
local widgets = view and view._settings_content_widgets
local alignments = view and view._settings_alignment_list

if type(widgets) ~= "table" then
return ""
end

local signature = {}

for i = 1, #widgets do
local widget = widgets[i]
local alignment_widget = type(alignments) == "table" and alignments[i]
local alignment_height = type(alignment_widget) == "table" and type(alignment_widget.size) == "table" and alignment_widget.size[2] or 0
signature[i] = tostring(widget and widget.name or i) .. ":" .. tostring(widget and widget.type or "") .. ":" .. tostring(alignment_height)
end

return table.concat(signature, "|")
end

local function compact_salvage_menu_view(view)
if not view or view.view_name ~= "dmf_options_view" then
return
end

local category = view._selected_category

if not is_salvage_options_category(category) then
view._salvage_visible_menu_count = nil
view._salvage_visible_menu_signature = nil
view._salvage_compact_grid_object = nil
return
end

local fallen_setting = mod:get("mark_fallen_comrades")

if fallen_setting == true then
mod:set("mark_fallen_comrades", "all", true)
elseif fallen_setting == false or fallen_setting == "none" or fallen_setting == "off" then
mod:set("mark_fallen_comrades", "never", true)
elseif fallen_setting == "both" then
mod:set("mark_fallen_comrades", "all", true)
elseif fallen_setting == "incapacitated" then
mod:set("mark_fallen_comrades", "disabled_only", true)
end

local changed = compact_salvage_category_rows(view, category)

if not salvage_content_matches_category_rows(view, category) and type(view.present_category_widgets) == "function" then
view:present_category_widgets(category)
changed = true
end

if compact_salvage_visible_rows(view) then
changed = true
end

local content_widgets = view._settings_content_widgets
local visible_count = type(content_widgets) == "table" and #content_widgets or 0
local signature = salvage_menu_signature(view)
local grid_changed = view._salvage_compact_grid_object ~= view._settings_content_grid

if changed or grid_changed or view._salvage_visible_menu_count ~= visible_count or view._salvage_visible_menu_signature ~= signature then
view._salvage_visible_menu_count = visible_count
view._salvage_visible_menu_signature = signature
rebuild_salvage_settings_grid(view)
view._salvage_compact_grid_object = view._settings_content_grid
end
end

local function install_menu_font_size_patch()
if mod._salvage_menu_font_size_patch_done then
return
end

if not CLASS or not CLASS.BaseView or type(mod.hook_safe) ~= "function" then
return
end

mod._salvage_menu_font_size_patch_done = true

mod:hook_safe(CLASS.BaseView, "update", function(view)
compact_salvage_menu_view(view)
end)
end

local function fallen_comrade_markers_enabled()
local setting = mod:get("mark_fallen_comrades")

if setting == true then
mod:set("mark_fallen_comrades", "all", true)
setting = "all"
elseif setting == false or setting == "none" or setting == "off" then
mod:set("mark_fallen_comrades", "never", true)
setting = "never"
elseif setting == "both" then
mod:set("mark_fallen_comrades", "all", true)
setting = "all"
elseif setting == "incapacitated" then
mod:set("mark_fallen_comrades", "disabled_only", true)
setting = "disabled_only"
end

return setting == "dead_only" or setting == "downed_only" or setting == "disabled_only" or setting == "dead_or_downed" or setting == "all"
end

local function world_markers_element()
local ui_manager = Managers and Managers.ui
local hud = ui_manager and ui_manager.get_hud and ui_manager:get_hud()

return hud and hud.element and hud:element("HudElementWorldMarkers") or nil
end

local function fallen_marker_reason_from_source(reason)
if reason == FALLEN_MARKER_REASON_DEATH then
return FALLEN_MARKER_REASON_DEATH
end

return FALLEN_MARKER_REASON_DISABLED
end

local function fallen_marker_colour(reason)
if reason == FALLEN_MARKER_REASON_DEATH then
return FALLEN_MARKER_DEATH_COLOUR
end

return FALLEN_MARKER_DISABLED_COLOUR
end

local function fallen_marker_font_size(reason)
if reason == FALLEN_MARKER_REASON_DEATH then
return FALLEN_MARKER_DEATH_FONT_SIZE
end

return FALLEN_MARKER_DISABLED_FONT_SIZE
end

local function fallen_marker_is_live(marker_id)
if not marker_id or marker_id == FALLEN_MARKER_PENDING then
return false
end

local world_markers = world_markers_element()
local markers_by_id = world_markers and world_markers._markers_by_id

return markers_by_id and markers_by_id[marker_id] ~= nil or false
end

local function remove_fallen_marker_for_unit(unit)
local record = tracked_fallen_markers_by_unit[unit]
local marker_id = record and record.id

if fallen_marker_is_live(marker_id) and Managers and Managers.event then
Managers.event:trigger("remove_world_marker", marker_id)
end

tracked_fallen_markers_by_unit[unit] = nil
end

local function remove_all_fallen_markers()
for unit, _ in pairs(tracked_fallen_markers_by_unit) do
remove_fallen_marker_for_unit(unit)
end

clear_table(found_fallen_comrades_by_unit)
end

local function update_pending_fallen_markers()
for unit, record in pairs(tracked_fallen_markers_by_unit) do
if not is_alive_unit(unit) then
tracked_fallen_markers_by_unit[unit] = nil
elseif record.id == FALLEN_MARKER_PENDING then
record.pending_frames = (record.pending_frames or 0) + 1

if record.pending_frames >= 30 then
tracked_fallen_markers_by_unit[unit] = nil
end
elseif record.id and not fallen_marker_is_live(record.id) then
tracked_fallen_markers_by_unit[unit] = nil
end
end
end

local function update_fallen_marker_widget(widget, marker, marker_template)
local content = widget.content
local style = widget.style
local visible = marker.draw ~= false
local unit = marker.unit
local record = unit and tracked_fallen_markers_by_unit[unit]
local reason = fallen_marker_reason_from_source(record and record.reason)
local colour = fallen_marker_colour(reason)
local font_size = fallen_marker_font_size(reason)

widget.visible = true
content.icon = FALLEN_MARKER_ICON
style.icon_shadow.font_size = font_size
style.icon.font_size = font_size
style.icon_shadow.size[1] = FALLEN_MARKER_WIDGET_SIZE
style.icon_shadow.size[2] = FALLEN_MARKER_WIDGET_SIZE
style.icon.size[1] = FALLEN_MARKER_WIDGET_SIZE
style.icon.size[2] = FALLEN_MARKER_WIDGET_SIZE
style.icon_shadow.text_color = visible and FALLEN_MARKER_SHADOW or FALLEN_MARKER_INVISIBLE
style.icon.text_color = visible and colour or FALLEN_MARKER_INVISIBLE
marker_template.max_distance = FALLEN_MARKER_MAX_DISTANCE
marker.scale = 1
marker.ignore_scale = true
end

local function create_fallen_marker_template()
local font_settings = UIFontSettings.hud_body
local template = {}

template.name = FALLEN_MARKER_TYPE
template.size = { FALLEN_MARKER_WIDGET_SIZE, FALLEN_MARKER_WIDGET_SIZE }
template.unit_node = "j_hips"
template.position_offset = FALLEN_MARKER_POSITION_OFFSET
template.max_distance = FALLEN_MARKER_MAX_DISTANCE
template.screen_clamp = true
template.screen_margins = {
down = 0.18,
left = 0.18,
right = 0.18,
up = 0.18,
}
template.check_line_of_sight = false
template.using_smart_tag_system = false
template.scale_settings = {
distance_min = 0,
distance_max = FALLEN_MARKER_MAX_DISTANCE,
scale_from = 1,
scale_to = 1,
}
template.fade_settings = nil

template.create_widget_defintion = function(_, scenegraph_id)
return UIWidget.create_definition({
{
pass_type = "text",
style_id = "icon_shadow",
value = FALLEN_MARKER_ICON,
value_id = "icon",
style = {
font_type = font_settings.font_type,
font_size = FALLEN_MARKER_DISABLED_FONT_SIZE,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 2, 2, 0 },
size = { FALLEN_MARKER_WIDGET_SIZE, FALLEN_MARKER_WIDGET_SIZE },
text_color = FALLEN_MARKER_SHADOW,
},
},
{
pass_type = "text",
style_id = "icon",
value = FALLEN_MARKER_ICON,
value_id = "icon",
style = {
font_type = font_settings.font_type,
font_size = FALLEN_MARKER_DISABLED_FONT_SIZE,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, 0, 1 },
size = { FALLEN_MARKER_WIDGET_SIZE, FALLEN_MARKER_WIDGET_SIZE },
text_color = FALLEN_MARKER_DEATH_COLOUR,
},
},
}, scenegraph_id)
end

template.on_enter = function(widget, marker, marker_template)
update_fallen_marker_widget(widget, marker, marker_template)
end

template.update_function = function(parent, ui_renderer, widget, marker, marker_template)
update_fallen_marker_widget(widget, marker, marker_template)
end

return template
end

local function ensure_fallen_marker_template()
local world_markers = world_markers_element()

if not world_markers or not world_markers._marker_templates then
return false
end

if not world_markers._marker_templates[FALLEN_MARKER_TYPE] then
world_markers._marker_templates[FALLEN_MARKER_TYPE] = create_fallen_marker_template()
end

return true
end

local function local_player_unit_for_fallen_markers()
local player_manager = Managers and Managers.player
local player = player_manager and player_manager.local_player and player_manager:local_player(1)
local unit = player and player.player_unit

if is_alive_unit(unit) then
return unit
end

return nil
end

local function unit_position(unit)
if is_alive_unit(unit) then
if POSITION_LOOKUP and POSITION_LOOKUP[unit] then
return POSITION_LOOKUP[unit]
end

if Unit and Unit.world_position then
local success, position = pcall(Unit.world_position, unit, ROOT_NODE_INDEX)

if success then
return position
end
end
end

return nil
end

local function player_unit_from_player(player)
local unit = player and player.player_unit

if is_alive_unit(unit) then
return unit
end

return nil
end

local function fallen_marker_reason_for_player_unit(unit)
if not is_alive_unit(unit) or not ScriptUnit or not ScriptUnit.has_extension then
return nil
end

local success, unit_data_extension = pcall(ScriptUnit.has_extension, unit, "unit_data_system")

if not success or not unit_data_extension or type(unit_data_extension.read_component) ~= "function" then
return nil
end

local read_success, character_state_component = pcall(unit_data_extension.read_component, unit_data_extension, "character_state")

if not read_success or not character_state_component then
return nil
end

local state_name = character_state_component.state_name

if state_name == "dead" or state_name == "hogtied" then
return FALLEN_MARKER_REASON_DEATH
end

if PlayerUnitStatus and type(PlayerUnitStatus.is_hogtied) == "function" then
local hogtied_success, is_hogtied = pcall(PlayerUnitStatus.is_hogtied, character_state_component)

if hogtied_success and is_hogtied == true then
return FALLEN_MARKER_REASON_DEATH
end
end

if state_name == "knocked_down" then
return "knocked_down"
end

if PlayerUnitStatus and type(PlayerUnitStatus.is_knocked_down) == "function" then
local knocked_down_success, is_knocked_down = pcall(PlayerUnitStatus.is_knocked_down, character_state_component)

if knocked_down_success and is_knocked_down == true then
return "knocked_down"
end
end

if PlayerUnitStatus and type(PlayerUnitStatus.is_disabled) == "function" then
local disabled_success, is_disabled = pcall(PlayerUnitStatus.is_disabled, character_state_component)

if disabled_success and is_disabled == true then
return FALLEN_MARKER_REASON_DISABLED
end
end

local disabled_success, disabled_character_state_component = pcall(unit_data_extension.read_component, unit_data_extension, "disabled_character_state")

if disabled_success and disabled_character_state_component and disabled_character_state_component.is_disabled == true then
return FALLEN_MARKER_REASON_DISABLED
end

return nil
end

local function request_fallen_marker(unit, reason)
if not is_alive_unit(unit) or not ensure_fallen_marker_template() or not Managers or not Managers.event then
return
end

local record = tracked_fallen_markers_by_unit[unit]
local marker_reason = fallen_marker_reason_from_source(reason)

if record and record.id == FALLEN_MARKER_PENDING then
record.reason = marker_reason
return
end

if record and fallen_marker_is_live(record.id) then
record.reason = marker_reason
return
end

record = {
id = FALLEN_MARKER_PENDING,
pending_frames = 0,
reason = marker_reason,
}
tracked_fallen_markers_by_unit[unit] = record

local function on_marker_added(marker_id)
local current_record = tracked_fallen_markers_by_unit[unit]

if current_record and current_record.id == FALLEN_MARKER_PENDING then
current_record.id = marker_id
current_record.pending_frames = nil
end
end

Managers.event:trigger("add_world_marker_unit", FALLEN_MARKER_TYPE, unit, on_marker_added, {
unit = unit,
})
end

local function collect_fallen_marker_teammates(local_unit)
local player_manager = Managers and Managers.player

if not player_manager or type(player_manager.players) ~= "function" then
return {}
end

local success, players = pcall(player_manager.players, player_manager)
local units = {}

if not success or type(players) ~= "table" then
return units
end

for _, player in pairs(players) do
local unit = player_unit_from_player(player)
local reason = unit and unit ~= local_unit and fallen_marker_reason_for_player_unit(unit) or nil

local setting = mod:get("mark_fallen_comrades")
local is_dead = reason == FALLEN_MARKER_REASON_DEATH
local is_downed = reason == "knocked_down"
local is_disabled = reason == FALLEN_MARKER_REASON_DISABLED
local allowed = setting == true or setting == "all" and (is_dead or is_downed or is_disabled) or setting == "dead_only" and is_dead or setting == "downed_only" and is_downed or setting == "disabled_only" and is_disabled or setting == "dead_or_downed" and (is_dead or is_downed) or setting == "both" and (is_dead or is_downed or is_disabled) or setting == "incapacitated" and is_disabled

if unit and reason and allowed then
units[unit] = reason
end
end

return units
end

local function sync_fallen_comrade_markers()
if not should_run() or not fallen_comrade_markers_enabled() then
remove_all_fallen_markers()
return
end

local local_unit = local_player_unit_for_fallen_markers()

if not local_unit then
remove_all_fallen_markers()
return
end

if not ensure_fallen_marker_template() then
return
end

update_pending_fallen_markers()

local local_position = unit_position(local_unit)
local desired_units = {}
local fallen_units = collect_fallen_marker_teammates(local_unit)

for unit, reason in pairs(fallen_units) do
local position = unit_position(unit)
local is_death_marker = reason == FALLEN_MARKER_REASON_DEATH

if is_death_marker and position and local_position and Vector3.distance(local_position, position) <= FALLEN_MARKER_CLOSE_DISTANCE then
found_fallen_comrades_by_unit[unit] = true
remove_fallen_marker_for_unit(unit)
elseif not is_death_marker or not found_fallen_comrades_by_unit[unit] then
desired_units[unit] = true
request_fallen_marker(unit, reason)
end
end

for unit, _ in pairs(tracked_fallen_markers_by_unit) do
if not desired_units[unit] then
remove_fallen_marker_for_unit(unit)
end
end

for unit, _ in pairs(found_fallen_comrades_by_unit) do
if fallen_marker_reason_for_player_unit(unit) ~= FALLEN_MARKER_REASON_DEATH then
found_fallen_comrades_by_unit[unit] = nil
end
end
end


local function player_drop_markers_enabled()
return mod:get("mark_player_dropped_remnants") == true
end

function mod._salvage_player_drop_warnings_enabled()
return mod:get("player_drop_warning") == true
end

function mod._salvage_player_drop_feature_enabled()
return player_drop_markers_enabled() or mod._salvage_player_drop_warnings_enabled()
end

function mod._salvage_current_main_time()
local time_manager = Managers and Managers.time

if time_manager and type(time_manager.time) == "function" then
local success, value = pcall(time_manager.time, time_manager, "main")

if success and type(value) == "number" then
return value
end
end

return 0
end

function mod._salvage_cache_player_drop_worth(amount)
local numeric_amount = math.abs(tonumber(amount) or 0)

if numeric_amount <= 0 then
return nil
end

local rounded_amount = math.floor(numeric_amount + 0.5)

mod._salvage_recent_player_drop_worth.amount = rounded_amount
mod._salvage_recent_player_drop_worth.time = mod._salvage_current_main_time()

return rounded_amount
end

function mod._salvage_recent_cached_player_drop_worth()
local record = mod._salvage_recent_player_drop_worth
local amount = record and tonumber(record.amount)
local time = record and tonumber(record.time) or -999

if amount and amount > 0 and mod._salvage_current_main_time() - time <= PLAYER_DROP_RECENT_DURATION then
return math.floor(amount + 0.5)
end

return nil
end

function mod._salvage_show_player_drop_worth_flash(amount)
local rounded_amount = mod._salvage_cache_player_drop_worth(amount)

if not rounded_amount or not should_run() or not mod._salvage_player_drop_warnings_enabled() or not Managers or not Managers.event then
return
end

local t = mod._salvage_current_main_time()

if mod._salvage_player_drop_worth_warning.last_amount == rounded_amount and t - mod._salvage_player_drop_worth_warning.last_t < 0.15 then
return
end

mod._salvage_player_drop_worth_warning.last_amount = rounded_amount
mod._salvage_player_drop_worth_warning.last_t = t

if type(mod._salvage_queue_pending_player_drop_worth) == "function" then
mod._salvage_queue_pending_player_drop_worth(rounded_amount, nil, PLAYER_DROP_REASON_DISABLED, true)
end

Managers.event:trigger("salvage_show_player_drop_worth_warning", rounded_amount, 1.5)
end

function mod._salvage_event_add_notification_message(self, message_type, data)
if type(data) ~= "table" or not mod._salvage_player_drop_feature_enabled() then
return
end

if message_type == "player_loot_drop" then
if type(mod._salvage_record_player_drop_notification) == "function" then
mod._salvage_record_player_drop_notification(data)
end
elseif message_type == "minion_loot_steal" then
mod._salvage_show_player_drop_worth_flash(data.amount)
elseif message_type == "minion_loot_drop" and type(mod._salvage_remember_recent_stolen_minion_drop) == "function" then
mod._salvage_remember_recent_stolen_minion_drop(data.amount)
end
end

function mod._salvage_register_player_drop_notification_event()
if mod._salvage_player_drop_notification_event_registered or not Managers or not Managers.event or type(Managers.event.register) ~= "function" then
return
end

Managers.event:register(mod, "event_add_notification_message", "_salvage_event_add_notification_message")
mod._salvage_player_drop_notification_event_registered = true
end


local function player_drop_marker_reason_from_source(reason)
if reason == PLAYER_DROP_REASON_DEATH or reason == "dead" or reason == "killed" or reason == "hogtied" then
return PLAYER_DROP_REASON_DEATH
end

if reason == PLAYER_DROP_REASON_DISABLED or reason == "knocked_down" or reason == "netted" or reason == "pounced" or reason == "mutant_charged" or reason == "grabbed" or reason == "disabled" or reason == "stolen" or reason == "direct_drop" then
return PLAYER_DROP_REASON_DISABLED
end

return nil
end

local function player_drop_reason_priority(reason)
if reason == PLAYER_DROP_REASON_DEATH then
return 2
end

if reason == PLAYER_DROP_REASON_DISABLED then
return 1
end

return 0
end

local function player_drop_marker_colour(reason)
if reason == PLAYER_DROP_REASON_DEATH then
return PLAYER_DROP_MARKER_DEATH_COLOUR
end

return PLAYER_DROP_MARKER_DISABLED_COLOUR
end

local function player_drop_marker_font_size(reason)
if reason == PLAYER_DROP_REASON_DEATH then
return PLAYER_DROP_MARKER_DEATH_FONT_SIZE
end

return PLAYER_DROP_MARKER_DISABLED_FONT_SIZE
end

function mod._salvage_player_drop_amount_symbol_string(amount)
local numeric_amount = math.floor(math.abs(tonumber(amount) or 0) + 0.5)

if numeric_amount <= 0 then
return ""
end

local text = tostring(numeric_amount)
local result = ""

for i = 1, #text do
local char = string.sub(text, i, i)

if char == "0" then
result = result .. ""
elseif char == "1" then
result = result .. ""
elseif char == "2" then
result = result .. ""
elseif char == "3" then
result = result .. ""
elseif char == "4" then
result = result .. ""
elseif char == "5" then
result = result .. ""
elseif char == "6" then
result = result .. ""
elseif char == "7" then
result = result .. ""
elseif char == "8" then
result = result .. ""
elseif char == "9" then
result = result .. ""
end
end

return result
end

local function player_drop_marker_is_live(marker_id)
if not marker_id or marker_id == PLAYER_DROP_MARKER_PENDING then
return false
end

local world_markers = world_markers_element()
local markers_by_id = world_markers and world_markers._markers_by_id

return markers_by_id and markers_by_id[marker_id] ~= nil or false
end

local function remove_player_drop_marker_for_unit(unit)
local record = tracked_player_drop_markers_by_unit[unit]
local marker_id = record and record.id

if player_drop_marker_is_live(marker_id) and Managers and Managers.event then
Managers.event:trigger("remove_world_marker", marker_id)
end

local worth_record = mod._salvage_player_drop_worth_markers_by_unit[unit]
local worth_marker_id = worth_record and worth_record.id

if player_drop_marker_is_live(worth_marker_id) and Managers and Managers.event then
Managers.event:trigger("remove_world_marker", worth_marker_id)
end

tracked_player_drop_markers_by_unit[unit] = nil
mod._salvage_player_drop_worth_markers_by_unit[unit] = nil
end

local function remove_all_player_drop_markers()
for unit, _ in pairs(tracked_player_drop_markers_by_unit) do
remove_player_drop_marker_for_unit(unit)
end

clear_table(tracked_player_drop_pickups_by_unit)
clear_table(mod._salvage_player_drop_worth_markers_by_unit)
clear_table(mod._salvage_player_drop_worth_by_unit)
clear_table(recent_player_drop_records)
clear_table(mod._salvage_pending_player_drop_worth_records)
clear_table(mod._salvage_stolen_loot_by_minion_unit)
clear_table(observed_local_player_drop_states_by_unit)
end

local function update_pending_player_drop_markers()
for unit, record in pairs(tracked_player_drop_markers_by_unit) do
if not is_alive_unit(unit) then
tracked_player_drop_markers_by_unit[unit] = nil
mod._salvage_player_drop_worth_markers_by_unit[unit] = nil
tracked_player_drop_pickups_by_unit[unit] = nil
mod._salvage_player_drop_worth_by_unit[unit] = nil
elseif record.id == PLAYER_DROP_MARKER_PENDING then
record.pending_frames = (record.pending_frames or 0) + 1

if record.pending_frames >= 30 then
tracked_player_drop_markers_by_unit[unit] = nil
end
elseif record.id and not player_drop_marker_is_live(record.id) then
tracked_player_drop_markers_by_unit[unit] = nil
end
end

for unit, record in pairs(mod._salvage_player_drop_worth_markers_by_unit) do
if not is_alive_unit(unit) then
mod._salvage_player_drop_worth_markers_by_unit[unit] = nil
elseif record.id == PLAYER_DROP_MARKER_PENDING then
record.pending_frames = (record.pending_frames or 0) + 1

if record.pending_frames >= 30 then
mod._salvage_player_drop_worth_markers_by_unit[unit] = nil
end
elseif record.id and not player_drop_marker_is_live(record.id) then
mod._salvage_player_drop_worth_markers_by_unit[unit] = nil
end
end
end

local function update_player_drop_marker_widget(widget, marker, marker_template)
local content = widget.content
local style = widget.style
local visible = marker.draw ~= false
local unit = marker.unit
local record = unit and tracked_player_drop_markers_by_unit[unit]
local reason = player_drop_marker_reason_from_source(record and record.reason)
local colour = player_drop_marker_colour(reason)
local font_size = player_drop_marker_font_size(reason)
local marker_data = marker and marker.data
local cached_worth = record and record.worth or unit and mod._salvage_player_drop_worth_by_unit[unit] or marker_data and marker_data.worth

if not cached_worth and unit and type(mod._salvage_bind_pending_player_drop_worth_to_existing_pickups) == "function" then
mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
cached_worth = record and record.worth or mod._salvage_player_drop_worth_by_unit[unit] or marker_data and marker_data.worth
end

if not cached_worth and unit then
local recent_worth = mod._salvage_recent_cached_player_drop_worth()

if type(recent_worth) == "number" and recent_worth > 0 and pickup_type_from_unit(unit) == PLAYER_DROP_PICKUP_TYPE then
cached_worth = recent_worth
mod._salvage_player_drop_worth_by_unit[unit] = recent_worth

if record then
record.worth = recent_worth
end
end
end

local numeric_worth = tonumber(cached_worth)
local worth_symbols = numeric_worth and numeric_worth > 0 and mod._salvage_player_drop_amount_symbol_string(numeric_worth) or ""
local line_text = worth_symbols ~= "" and PLAYER_DROP_MARKER_ICON .. " " .. worth_symbols or PLAYER_DROP_MARKER_ICON

widget.visible = true
content.icon = line_text
content.worth = ""
style.icon_shadow.font_size = font_size
style.icon.font_size = font_size
style.icon_shadow.size[1] = PLAYER_DROP_MARKER_WIDGET_SIZE
style.icon_shadow.size[2] = PLAYER_DROP_MARKER_WIDGET_SIZE
style.icon.size[1] = PLAYER_DROP_MARKER_WIDGET_SIZE
style.icon.size[2] = PLAYER_DROP_MARKER_WIDGET_SIZE
style.icon_shadow.text_color = visible and PLAYER_DROP_MARKER_SHADOW or PLAYER_DROP_MARKER_INVISIBLE
style.icon.text_color = visible and colour or PLAYER_DROP_MARKER_INVISIBLE
if style.worth_shadow and style.worth then
style.worth_shadow.text_color = PLAYER_DROP_MARKER_INVISIBLE
style.worth.text_color = PLAYER_DROP_MARKER_INVISIBLE
end
marker_template.max_distance = PLAYER_DROP_MARKER_MAX_DISTANCE
marker.scale = 1
marker.ignore_scale = true
widget.dirty = true
end

mod._salvage_player_drop_worth_text_for_unit = function(unit, marker_data)
local record = unit and tracked_player_drop_markers_by_unit[unit]
local cached_worth = record and record.worth or unit and mod._salvage_player_drop_worth_by_unit[unit] or marker_data and marker_data.worth

if not cached_worth and unit and type(mod._salvage_bind_pending_player_drop_worth_to_existing_pickups) == "function" then
mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
record = tracked_player_drop_markers_by_unit[unit]
cached_worth = record and record.worth or mod._salvage_player_drop_worth_by_unit[unit] or marker_data and marker_data.worth
end

if not cached_worth and unit then
local recent_worth = mod._salvage_recent_cached_player_drop_worth()

if type(recent_worth) == "number" and recent_worth > 0 and pickup_type_from_unit(unit) == PLAYER_DROP_PICKUP_TYPE then
cached_worth = recent_worth
mod._salvage_player_drop_worth_by_unit[unit] = recent_worth

if record then
record.worth = recent_worth
end
end
end

local numeric_worth = tonumber(cached_worth)

return numeric_worth and numeric_worth > 0 and tostring(math.floor(math.abs(numeric_worth) + 0.5)) or ""
end

mod._salvage_update_player_drop_worth_marker_widget = function(widget, marker, marker_template)
local content = widget.content
local style = widget.style
local unit = marker.unit
local marker_data = marker and marker.data
local worth_text = mod._salvage_player_drop_worth_text_for_unit(unit, marker_data)
local visible = marker.draw ~= false and worth_text ~= ""

widget.visible = true
content.worth = worth_text
style.worth_shadow.font_size = 6
style.worth.font_size = 6
style.worth_shadow.text_color = visible and PLAYER_DROP_MARKER_SHADOW or PLAYER_DROP_MARKER_INVISIBLE
style.worth.text_color = visible and PLAYER_DROP_MARKER_DISABLED_COLOUR or PLAYER_DROP_MARKER_INVISIBLE
marker_template.max_distance = PLAYER_DROP_MARKER_MAX_DISTANCE
marker.scale = 1
marker.ignore_scale = true
widget.dirty = true
end

local function create_player_drop_marker_template()
local font_settings = UIFontSettings.hud_body
local template = {}

template.name = PLAYER_DROP_MARKER_TYPE
template._salvage_version = 35
template.size = { PLAYER_DROP_MARKER_WIDGET_SIZE, PLAYER_DROP_MARKER_WIDGET_SIZE }
template.unit_node = nil
template.position_offset = PLAYER_DROP_MARKER_POSITION_OFFSET
template.max_distance = PLAYER_DROP_MARKER_MAX_DISTANCE
template.screen_clamp = true
template.screen_margins = {
down = 0.18,
left = 0.18,
right = 0.18,
up = 0.18,
}
template.check_line_of_sight = false
template.using_smart_tag_system = false
template.scale_settings = {
distance_min = 0,
distance_max = PLAYER_DROP_MARKER_MAX_DISTANCE,
scale_from = 1,
scale_to = 1,
}
template.fade_settings = nil

template.create_widget_defintion = function(_, scenegraph_id)
return UIWidget.create_definition({
{
pass_type = "text",
style_id = "icon_shadow",
value = PLAYER_DROP_MARKER_ICON,
value_id = "icon",
style = {
font_type = font_settings.font_type,
font_size = PLAYER_DROP_MARKER_DISABLED_FONT_SIZE,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 2, 2, 0 },
size = { PLAYER_DROP_MARKER_WIDGET_SIZE, PLAYER_DROP_MARKER_WIDGET_SIZE },
text_color = PLAYER_DROP_MARKER_SHADOW,
},
},
{
pass_type = "text",
style_id = "icon",
value = PLAYER_DROP_MARKER_ICON,
value_id = "icon",
style = {
font_type = font_settings.font_type,
font_size = PLAYER_DROP_MARKER_DISABLED_FONT_SIZE,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, 0, 1 },
size = { PLAYER_DROP_MARKER_WIDGET_SIZE, PLAYER_DROP_MARKER_WIDGET_SIZE },
text_color = PLAYER_DROP_MARKER_DISABLED_COLOUR,
},
},
{
pass_type = "text",
style_id = "worth_shadow",
value = "",
value_id = "worth",
style = {
font_type = font_settings.font_type,
font_size = 6,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 2, -48 + 1, 2 },
size = { PLAYER_DROP_MARKER_WIDGET_SIZE, 18 },
text_color = PLAYER_DROP_MARKER_INVISIBLE,
},
},
{
pass_type = "text",
style_id = "worth",
value = "",
value_id = "worth",
style = {
font_type = font_settings.font_type,
font_size = 6,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, -48, 3 },
size = { PLAYER_DROP_MARKER_WIDGET_SIZE, 18 },
text_color = PLAYER_DROP_MARKER_INVISIBLE,
},
},
}, scenegraph_id)
end

template.on_enter = function(widget, marker, marker_template)
update_player_drop_marker_widget(widget, marker, marker_template)
end

template.update_function = function(parent, ui_renderer, widget, marker, marker_template)
update_player_drop_marker_widget(widget, marker, marker_template)
end

return template
end

mod._salvage_create_player_drop_worth_marker_template = function()
local font_settings = UIFontSettings.hud_body
local template = {}

template.name = "salvage_player_drop_worth_marker"
template._salvage_version = 35
template.size = { 96, 24 }
template.unit_node = nil
template.position_offset = { 0, 0, 1.08 }
template.max_distance = PLAYER_DROP_MARKER_MAX_DISTANCE
template.screen_clamp = true
template.screen_margins = {
down = 0.18,
left = 0.18,
right = 0.18,
up = 0.18,
}
template.check_line_of_sight = false
template.using_smart_tag_system = false
template.scale_settings = {
distance_min = 0,
distance_max = PLAYER_DROP_MARKER_MAX_DISTANCE,
scale_from = 1,
scale_to = 1,
}
template.fade_settings = nil

template.create_widget_defintion = function(_, scenegraph_id)
return UIWidget.create_definition({
{
pass_type = "text",
style_id = "worth_shadow",
value = "",
value_id = "worth",
style = {
font_type = font_settings.font_type,
font_size = 6,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 1, 1, 1 },
size = { 96, 24 },
text_color = PLAYER_DROP_MARKER_INVISIBLE,
},
},
{
pass_type = "text",
style_id = "worth",
value = "",
value_id = "worth",
style = {
font_type = font_settings.font_type,
font_size = 6,
text_horizontal_alignment = "center",
text_vertical_alignment = "center",
horizontal_alignment = "center",
vertical_alignment = "center",
offset = { 0, 0, 2 },
size = { 96, 24 },
text_color = PLAYER_DROP_MARKER_INVISIBLE,
},
},
}, scenegraph_id)
end

template.on_enter = function(widget, marker, marker_template)
mod._salvage_update_player_drop_worth_marker_widget(widget, marker, marker_template)
end

template.update_function = function(parent, ui_renderer, widget, marker, marker_template)
mod._salvage_update_player_drop_worth_marker_widget(widget, marker, marker_template)
end

return template
end

local function ensure_player_drop_marker_template()
local world_markers = world_markers_element()

if not world_markers or not world_markers._marker_templates then
return false
end

local marker_template = world_markers._marker_templates[PLAYER_DROP_MARKER_TYPE]

if not marker_template or marker_template._salvage_version ~= 35 then
world_markers._marker_templates[PLAYER_DROP_MARKER_TYPE] = create_player_drop_marker_template()
end

return true
end

function mod._salvage_install_player_drop_marker_template_patch()
if mod._salvage_player_drop_marker_template_patch_done then
return
end

if not CLASS or not CLASS.HudElementWorldMarkers or type(mod.hook_safe) ~= "function" then
return
end

mod._salvage_player_drop_marker_template_patch_done = true

mod:hook_safe(CLASS.HudElementWorldMarkers, "init", function(world_markers)
if world_markers and world_markers._marker_templates then
local marker_template = world_markers._marker_templates[PLAYER_DROP_MARKER_TYPE]

if not marker_template or marker_template._salvage_version ~= 35 then
world_markers._marker_templates[PLAYER_DROP_MARKER_TYPE] = create_player_drop_marker_template()
end

 
end
end)
end

local function read_unit_components(unit)
if not is_alive_unit(unit) or not ScriptUnit or not ScriptUnit.has_extension then
return nil, nil
end

local success, unit_data_extension = pcall(ScriptUnit.has_extension, unit, "unit_data_system")

if not success or not unit_data_extension or type(unit_data_extension.read_component) ~= "function" then
return nil, nil
end

local character_state_component = nil
local disabled_character_state_component = nil
local character_success, character_component = pcall(unit_data_extension.read_component, unit_data_extension, "character_state")

if character_success then
character_state_component = character_component
end

local disabled_success, disabled_component = pcall(unit_data_extension.read_component, unit_data_extension, "disabled_character_state")

if disabled_success then
disabled_character_state_component = disabled_component
end

return character_state_component, disabled_character_state_component
end

local function player_drop_reason_from_status_components(character_state_component, disabled_character_state_component)
local state_name = character_state_component and character_state_component.state_name

if state_name == "dead" or state_name == "hogtied" then
return PLAYER_DROP_REASON_DEATH
end

if character_state_component and PlayerUnitStatus and type(PlayerUnitStatus.is_disabled) == "function" then
local success, is_disabled = pcall(PlayerUnitStatus.is_disabled, character_state_component)

if success and is_disabled == true then
return PLAYER_DROP_REASON_DISABLED
end
end

if disabled_character_state_component and disabled_character_state_component.is_disabled == true then
return PLAYER_DROP_REASON_DISABLED
end

return nil
end

local function player_status_drop_reason(player)
local unit = player_unit_from_player(player)

if not unit then
return nil
end

local character_state_component, disabled_character_state_component = read_unit_components(unit)

return player_drop_reason_from_status_components(character_state_component, disabled_character_state_component)
end

local function remember_recent_player_drop_at_position(position, reason, worth, flash_warning, short_match)
if not position and type(worth) ~= "number" then
return
end

local marker_reason = player_drop_marker_reason_from_source(reason)

if not marker_reason then
return
end

local numeric_worth = math.abs(tonumber(worth) or 0)

if numeric_worth > 0 then
mod._salvage_cache_player_drop_worth(numeric_worth)
end

if flash_warning and numeric_worth > 0 then
mod._salvage_show_player_drop_worth_flash(numeric_worth)
end

if numeric_worth > 0 and type(mod._salvage_queue_pending_player_drop_worth) == "function" then
mod._salvage_queue_pending_player_drop_worth(numeric_worth, position, marker_reason, flash_warning == true)
end

local best_unit = nil
local best_distance = PLAYER_DROP_RECENT_MATCH_DISTANCE

if position then
for unit, _ in pairs(tracked_player_drop_pickups_by_unit) do
if is_alive_unit(unit) and pickup_type_from_unit(unit) == PLAYER_DROP_PICKUP_TYPE then
local drop_position = unit_position(unit)

if drop_position then
local distance = Vector3.distance(position, drop_position)

if distance <= best_distance then
best_distance = distance
best_unit = unit
end
end
end
end
end

if best_unit then
tracked_player_drop_pickups_by_unit[best_unit] = marker_reason
if numeric_worth > 0 then
mod._salvage_player_drop_worth_by_unit[best_unit] = math.floor(numeric_worth + 0.5)
end

local marker_record = tracked_player_drop_markers_by_unit[best_unit]

if marker_record then
marker_record.reason = marker_reason
if numeric_worth > 0 then
marker_record.worth = math.floor(numeric_worth + 0.5)
end
end

if numeric_worth > 0 and type(mod._salvage_apply_player_drop_worth_to_unit) == "function" then
mod._salvage_apply_player_drop_worth_to_unit(best_unit, numeric_worth)
end

return
end

recent_player_drop_records[#recent_player_drop_records + 1] = {
position = position,
reason = marker_reason,
worth = numeric_worth > 0 and numeric_worth or nil,
flash_warning = flash_warning == true,
duration = short_match and 1.5 or PLAYER_DROP_RECENT_DURATION,
time = Managers and Managers.time and Managers.time:time("main") or 0,
}
end

function mod._salvage_record_player_drop_notification(data)
local player = data and data.player
local unit = player_unit_from_player(player)
local reason = player_status_drop_reason(player) or PLAYER_DROP_REASON_DISABLED

remember_recent_player_drop_at_position(unit and unit_position(unit) or nil, reason, data and data.amount, true)
end

local function observe_local_player_drop_source()
if not should_run() or not mod._salvage_player_drop_feature_enabled() then
return
end

local player_manager = Managers and Managers.player
local player = player_manager and player_manager.local_player and player_manager:local_player(1)
local unit = player_unit_from_player(player)

if not unit then
return
end

local character_state_component, disabled_character_state_component = read_unit_components(unit)
local reason = player_drop_reason_from_status_components(character_state_component, disabled_character_state_component)

if not reason then
observed_local_player_drop_states_by_unit[unit] = nil
return
end

local state_name = character_state_component and character_state_component.state_name or "none"
local disabling_type = disabled_character_state_component and disabled_character_state_component.disabling_type or "none"
local state_key = reason .. ":" .. state_name .. ":" .. disabling_type

if observed_local_player_drop_states_by_unit[unit] == state_key then
return
end

observed_local_player_drop_states_by_unit[unit] = state_key
remember_recent_player_drop_at_position(unit_position(unit), reason, nil, false)
end

local function remember_recent_player_drop(peer_id, reason, worth, flash_warning, short_match)
local player_manager = Managers and Managers.player
local player = player_manager and peer_id and player_manager.player and player_manager:player(peer_id, 1)
local unit = player_unit_from_player(player)
local position = unit and unit_position(unit)

remember_recent_player_drop_at_position(position, reason, worth, flash_warning, short_match)
end

local function prune_recent_player_drop_records(t)
for i = #recent_player_drop_records, 1, -1 do
local record = recent_player_drop_records[i]

if not record or t - (record.time or 0) > (record.duration or PLAYER_DROP_RECENT_DURATION) then
table.remove(recent_player_drop_records, i)
end
end
end

local function recent_player_drop_reason_for_unit(unit)
local position = unit_position(unit)
local t = Managers and Managers.time and Managers.time:time("main") or 0

prune_recent_player_drop_records(t)

local best_index = nil
local best_distance = PLAYER_DROP_RECENT_MATCH_DISTANCE
local best_priority = 0
local fallback_index = nil
local fallback_priority = 0

for i = 1, #recent_player_drop_records do
local record = recent_player_drop_records[i]
local record_position = record and record.position
local priority = player_drop_reason_priority(record and record.reason)

if record_position and position then
local distance = Vector3.distance(position, record_position)

if distance <= PLAYER_DROP_RECENT_MATCH_DISTANCE and (priority > best_priority or priority == best_priority and distance <= best_distance) then
best_distance = distance
best_priority = priority
best_index = i
end
elseif not record_position and type(record and record.worth) == "number" and record.worth > 0 and priority >= fallback_priority then
fallback_index = i
fallback_priority = priority
end
end

if not best_index then
best_index = fallback_index
end

if best_index then
local record = recent_player_drop_records[best_index]
local reason = record and record.reason
local worth = record and record.worth

if type(worth) == "number" and worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(worth + 0.5)
if record and record.flash_warning == true then
mod._salvage_show_player_drop_worth_flash(worth)
end
end
table.remove(recent_player_drop_records, best_index)

return reason
end

return nil
end

local function current_expedition_loot_handler()
local manager = game_mode_manager()
local game_mode = manager and safe_call(manager, "game_mode")
local candidates = {
game_mode,
game_mode and game_mode._logic,
game_mode and game_mode._game_mode_logic,
manager,
manager and manager._game_mode,
manager and manager._game_mode and manager._game_mode._logic,
}

for i = 1, #candidates do
local candidate = candidates[i]
local loot_handler = candidate and candidate._loot_handler

if loot_handler then
return loot_handler
end

if candidate and type(candidate.loot_handler) == "function" then
local success, result = pcall(candidate.loot_handler, candidate)

if success and result then
return result
end
end
end

return nil
end

function mod._salvage_current_pickup_system()
local extension_manager = Managers and Managers.state and Managers.state.extension

if not extension_manager or type(extension_manager.system) ~= "function" then
return nil
end

local success, pickup_system = pcall(extension_manager.system, extension_manager, "pickup_system")

if success then
return pickup_system
end

return nil
end

function mod._salvage_loot_handler_raw_drop_reason(unit)
local loot_handler = current_expedition_loot_handler()
local reasons = loot_handler and loot_handler._dropped_reason_by_pickup_unit

if type(reasons) ~= "table" then
return nil
end

return reasons[unit]
end

function mod._salvage_rounded_player_drop_worth(amount)
local numeric_amount = math.abs(tonumber(amount) or 0)

if numeric_amount <= 0 then
return nil
end

return math.floor(numeric_amount + 0.5)
end

function mod._salvage_apply_player_drop_worth_to_unit(unit, amount)
local rounded_amount = mod._salvage_rounded_player_drop_worth(amount)

if not rounded_amount or not is_alive_unit(unit) or pickup_type_from_unit(unit) ~= PLAYER_DROP_PICKUP_TYPE then
return false
end

mod._salvage_player_drop_worth_by_unit[unit] = rounded_amount

local record = tracked_player_drop_markers_by_unit[unit]

if record then
record.worth = rounded_amount
end

local world_markers = world_markers_element()
local markers_by_id = world_markers and world_markers._markers_by_id
local marker_id = record and record.id
local marker = marker_id and marker_id ~= PLAYER_DROP_MARKER_PENDING and markers_by_id and markers_by_id[marker_id]

if marker then
marker.data = marker.data or {}
marker.data.worth = rounded_amount

local widget = marker.widget

if widget then
widget.content.worth = tostring(rounded_amount)
widget.dirty = true
end
end

local worth_record = mod._salvage_player_drop_worth_markers_by_unit[unit]
local worth_marker_id = worth_record and worth_record.id
local worth_marker = worth_marker_id and worth_marker_id ~= PLAYER_DROP_MARKER_PENDING and markers_by_id and markers_by_id[worth_marker_id]

if worth_record then
worth_record.worth = rounded_amount
end

if worth_marker then
worth_marker.data = worth_marker.data or {}
worth_marker.data.worth = rounded_amount

if worth_marker.widget then
worth_marker.widget.content.worth = tostring(rounded_amount)
worth_marker.widget.dirty = true
end
end

if type(mod._salvage_request_player_drop_worth_marker) == "function" then
mod._salvage_request_player_drop_worth_marker(unit, rounded_amount)
end

return true
end

function mod._salvage_player_drop_unit_candidate_allowed(unit)
if not is_alive_unit(unit) or pickup_type_from_unit(unit) ~= PLAYER_DROP_PICKUP_TYPE then
return false
end

return mod._salvage_loot_handler_raw_drop_reason(unit) ~= "reward"
end

function mod._salvage_bind_pending_record_to_best_pickup(record)
if type(record) ~= "table" or not mod._salvage_rounded_player_drop_worth(record.amount) then
return false
end

local record_position = record.position
local best_unit = nil
local best_distance = math.huge
local seen_units = {}

local function try_unit(unit)
if seen_units[unit] or not mod._salvage_player_drop_unit_candidate_allowed(unit) then
return
end

seen_units[unit] = true

local existing_worth = mod._salvage_player_drop_worth_by_unit[unit]

if type(existing_worth) == "number" and existing_worth > 0 then
return
end

local distance = 0

if record_position then
local position = unit_position(unit)

if not position then
return
end

distance = Vector3.distance(position, record_position)

if distance > PLAYER_DROP_RECENT_MATCH_DISTANCE then
return
end
elseif tracked_player_drop_markers_by_unit[unit] then
distance = 0
else
distance = 1
end

if distance < best_distance then
best_distance = distance
best_unit = unit
end
end

for unit, _ in pairs(tracked_player_drop_markers_by_unit) do
try_unit(unit)
end

for unit, _ in pairs(tracked_player_drop_pickups_by_unit) do
try_unit(unit)
end

for unit, pickup_type in pairs(tracked_pickups_by_unit) do
if pickup_type == PLAYER_DROP_PICKUP_TYPE then
try_unit(unit)
end
end

local pickup_system = mod._salvage_current_pickup_system()
local spawned_pickups = pickup_system and pickup_system._spawned_pickups

if type(spawned_pickups) == "table" then
for _, unit in pairs(spawned_pickups) do
try_unit(unit)
end
end

if best_unit then
local reason = player_drop_marker_reason_from_source(record.reason) or PLAYER_DROP_REASON_DISABLED

tracked_player_drop_pickups_by_unit[best_unit] = reason
mod._salvage_apply_player_drop_worth_to_unit(best_unit, record.amount)

return true
end

return false
end

function mod._salvage_queue_pending_player_drop_worth(amount, position, reason, prefer_existing_marker)
local rounded_amount = mod._salvage_rounded_player_drop_worth(amount)

if not rounded_amount then
return nil
end

local record = {
amount = rounded_amount,
position = position,
reason = player_drop_marker_reason_from_source(reason) or PLAYER_DROP_REASON_DISABLED,
time = mod._salvage_current_main_time(),
prefer_existing_marker = prefer_existing_marker == true,
}

mod._salvage_pending_player_drop_worth_records[#mod._salvage_pending_player_drop_worth_records + 1] = record
mod._salvage_bind_pending_record_to_best_pickup(record)

return rounded_amount
end

function mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
local t = mod._salvage_current_main_time()

for i = #mod._salvage_pending_player_drop_worth_records, 1, -1 do
local record = mod._salvage_pending_player_drop_worth_records[i]

if not record or t - (record.time or 0) > PLAYER_DROP_RECENT_DURATION then
table.remove(mod._salvage_pending_player_drop_worth_records, i)
elseif mod._salvage_bind_pending_record_to_best_pickup(record) then
table.remove(mod._salvage_pending_player_drop_worth_records, i)
end
end
end

local function loot_handler_drop_reason(unit)
return player_drop_marker_reason_from_source(mod._salvage_loot_handler_raw_drop_reason(unit))
end

local function player_drop_reason_for_unit(unit)
if mod._salvage_loot_handler_raw_drop_reason(unit) == "reward" then
return nil
end

local cached_reason = tracked_player_drop_pickups_by_unit[unit]

if cached_reason then
local loot_handler = current_expedition_loot_handler()
local dropped_loot = loot_handler and loot_handler._dropped_loot_by_pickup_unit
local worth = type(dropped_loot) == "table" and dropped_loot[unit] or nil

if type(worth) == "number" and worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(worth + 0.5)
end

return player_drop_marker_reason_from_source(cached_reason)
end

local handler_reason = loot_handler_drop_reason(unit)

if handler_reason then
tracked_player_drop_pickups_by_unit[unit] = handler_reason
local loot_handler = current_expedition_loot_handler()
local dropped_loot = loot_handler and loot_handler._dropped_loot_by_pickup_unit
local worth = type(dropped_loot) == "table" and dropped_loot[unit] or nil

if type(worth) == "number" and worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(worth + 0.5)
end

return handler_reason
end

local recent_reason = recent_player_drop_reason_for_unit(unit)

if recent_reason then
tracked_player_drop_pickups_by_unit[unit] = recent_reason
return recent_reason
end

local cached_worth = mod._salvage_player_drop_worth_by_unit[unit] or mod._salvage_recent_cached_player_drop_worth()

if type(cached_worth) == "number" and cached_worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(cached_worth + 0.5)
return PLAYER_DROP_REASON_DISABLED
end

return nil
end


mod._salvage_request_player_drop_worth_marker = function(unit, worth)
local rounded_worth = mod._salvage_rounded_player_drop_worth(worth or mod._salvage_player_drop_worth_by_unit[unit] or mod._salvage_recent_cached_player_drop_worth())

if not rounded_worth or not is_alive_unit(unit) or pickup_type_from_unit(unit) ~= PLAYER_DROP_PICKUP_TYPE then
return
end

mod._salvage_player_drop_worth_by_unit[unit] = rounded_worth

local record = tracked_player_drop_markers_by_unit[unit]

if record then
record.worth = rounded_worth
local world_markers = world_markers_element()
local markers_by_id = world_markers and world_markers._markers_by_id
local marker = record.id and record.id ~= PLAYER_DROP_MARKER_PENDING and markers_by_id and markers_by_id[record.id]

if marker then
marker.data = marker.data or {}
marker.data.worth = rounded_worth

if marker.widget then
marker.widget.content.icon = PLAYER_DROP_MARKER_ICON .. " " .. mod._salvage_player_drop_amount_symbol_string(rounded_worth)
marker.widget.content.worth = ""
marker.widget.dirty = true
end
end
end
end

local function request_player_drop_marker(unit, reason)
if not is_alive_unit(unit) or not ensure_player_drop_marker_template() or not Managers or not Managers.event then
return
end

local record = tracked_player_drop_markers_by_unit[unit]
local marker_reason = player_drop_marker_reason_from_source(reason)

if not marker_reason then
return
end

local loot_handler = current_expedition_loot_handler()
local dropped_loot = loot_handler and loot_handler._dropped_loot_by_pickup_unit
local worth = type(dropped_loot) == "table" and dropped_loot[unit] or nil

if type(worth) == "number" and worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(worth + 0.5)
end

local cached_marker_worth = type(worth) == "number" and worth > 0 and math.floor(worth + 0.5) or mod._salvage_player_drop_worth_by_unit[unit] or mod._salvage_recent_cached_player_drop_worth()

if type(cached_marker_worth) == "number" and cached_marker_worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(cached_marker_worth + 0.5)
end

if record and record.id == PLAYER_DROP_MARKER_PENDING then
record.reason = marker_reason
record.worth = cached_marker_worth or record.worth
mod._salvage_request_player_drop_worth_marker(unit, record.worth)
return
end

if record and player_drop_marker_is_live(record.id) then
record.reason = marker_reason
record.worth = cached_marker_worth or record.worth
mod._salvage_request_player_drop_worth_marker(unit, record.worth)
return
end

record = {
id = PLAYER_DROP_MARKER_PENDING,
pending_frames = 0,
reason = marker_reason,
worth = cached_marker_worth,
}
tracked_player_drop_markers_by_unit[unit] = record

local function on_marker_added(marker_id)
local current_record = tracked_player_drop_markers_by_unit[unit]

if current_record and current_record.id == PLAYER_DROP_MARKER_PENDING then
current_record.id = marker_id
current_record.pending_frames = nil
end
end

Managers.event:trigger("add_world_marker_unit", PLAYER_DROP_MARKER_TYPE, unit, on_marker_added, {
unit = unit,
worth = cached_marker_worth,
reason = marker_reason,
})

if cached_marker_worth then
mod._salvage_apply_player_drop_worth_to_unit(unit, cached_marker_worth)
end

mod._salvage_request_player_drop_worth_marker(unit, cached_marker_worth)
end

local function register_player_drop_pickup_unit(unit, reason, worth, flash_warning)
if not is_alive_unit(unit) then
return
end

local marker_reason = player_drop_marker_reason_from_source(reason)

if not marker_reason then
return
end

tracked_player_drop_pickups_by_unit[unit] = marker_reason
local cached_worth = worth

if type(cached_worth) ~= "number" then
local loot_handler = current_expedition_loot_handler()
local dropped_loot = loot_handler and loot_handler._dropped_loot_by_pickup_unit
cached_worth = type(dropped_loot) == "table" and dropped_loot[unit] or nil
end

if type(cached_worth) ~= "number" then
cached_worth = mod._salvage_recent_cached_player_drop_worth()
end

if type(cached_worth) ~= "number" and type(mod._salvage_bind_pending_player_drop_worth_to_existing_pickups) == "function" then
mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
cached_worth = mod._salvage_player_drop_worth_by_unit[unit]
end

if type(cached_worth) == "number" and cached_worth > 0 then
local rounded_worth = math.floor(cached_worth + 0.5)
mod._salvage_player_drop_worth_by_unit[unit] = rounded_worth
if flash_warning == true then
mod._salvage_show_player_drop_worth_flash(rounded_worth)
end

local marker_record = tracked_player_drop_markers_by_unit[unit]
if marker_record then
marker_record.worth = rounded_worth
end
end

if player_drop_markers_enabled() then
request_player_drop_marker(unit, marker_reason)
end
end

local function pickup_type_from_marker_data(marker)
if not marker then
return nil
end

local success, pickup_type = pcall(function()
local data = marker.data

return data and data.type or nil
end)

if success then
return pickup_type
end

return nil
end

local function luggable_extension(unit)
if not is_alive_unit(unit) or not ScriptUnit or not ScriptUnit.has_extension then
return nil
end

local success, extension = pcall(ScriptUnit.has_extension, unit, "luggable_system")

if success then
return extension
end

return nil
end

local function is_currently_carried(unit)
local extension = luggable_extension(unit)

return safe_call(extension, "is_currently_carried") == true
end

local function stop_particle(world, effect_id)
if world and effect_id and World and World.stop_spawning_particles then
World.stop_spawning_particles(world, effect_id)
end
end

local function stop_particle_record(world, particle_record)
if type(particle_record) == "table" then
for i = 1, #particle_record do
stop_particle(world, particle_record[i])
end
else
stop_particle(world, particle_record)
end
end

local function stop_effect_for_unit(unit)
local effect_data = tracked_effects_by_unit[unit]

if not effect_data then
return
end

local active_effects = effect_data.active_effects

if active_effects then
for _, particle_record in pairs(active_effects) do
stop_particle_record(effect_data.world, particle_record)
end
end

tracked_effects_by_unit[unit] = nil
end

local function stop_all_particle_effects(clear_units)
for unit, _ in pairs(tracked_effects_by_unit) do
stop_effect_for_unit(unit)
end

if clear_units then
clear_table(tracked_pickups_by_unit)
end
end

local function stop_decal_for_unit(unit)
local decal_data = tracked_decals_by_unit[unit]

if not decal_data then
return
end

local decal_unit = decal_data.unit

if is_valid_unit(decal_unit) and World and World.destroy_unit and Unit.world then
local success, world = pcall(Unit.world, decal_unit)

if success and world then
World.destroy_unit(world, decal_unit)
end
end

tracked_decals_by_unit[unit] = nil
end

local function stop_all_decals()
for unit, _ in pairs(tracked_decals_by_unit) do
stop_decal_for_unit(unit)
end
end

local function stop_all_visuals(clear_units)
stop_all_particle_effects(clear_units)
stop_all_decals()
end

local function ensure_decal_package()
local package_manager = Managers and Managers.package

if not package_manager or not package_manager.has_loaded or not package_manager.load then
return false
end

local loaded_success, loaded = pcall(function()
return package_manager:has_loaded(DECAL_PACKAGE_PATH)
end)

if loaded_success and loaded then
return true
end

if not decal_package_loading then
decal_package_loading = true
local load_success = pcall(function()
package_manager:load(DECAL_PACKAGE_PATH, "salvage", function()
decal_package_loading = false
end)
end)

if not load_success then
decal_package_loading = false
end
end

return false
end

local function decal_position(unit)
if POSITION_LOOKUP and POSITION_LOOKUP[unit] then
return POSITION_LOOKUP[unit]
end

if Unit and Unit.world_position then
local success, position = pcall(Unit.world_position, unit, ROOT_NODE_INDEX)

if success then
return position
end
end

return nil
end

local function apply_decal_style(decal_data, category)
local decal = category and category.decal
local decal_unit = decal_data and decal_data.unit

if not decal or not is_valid_unit(decal_unit) or not Unit.set_vector4_for_material or not Unit.set_scalar_for_material or not Unit.set_local_scale then
return
end

local colour = Quaternion.identity()

Quaternion.set_xyzw(colour, decal.red, decal.green, decal.blue, 0)
Unit.set_vector4_for_material(decal_unit, "projector", "particle_color", colour, true)
Unit.set_scalar_for_material(decal_unit, "projector", "color_multiplier", decal.alpha)
Unit.set_local_scale(decal_unit, ROOT_NODE_INDEX, Vector3(DECAL_RADIUS * 2, DECAL_RADIUS * 2, 1))
decal_data.active = true
end

local function show_decal_for_unit(unit, pickup_type, category)
if not decal_enabled(category) then
stop_decal_for_unit(unit)

return
end

local decal_data = tracked_decals_by_unit[unit]

if decal_data and is_valid_unit(decal_data.unit) then
apply_decal_style(decal_data, category)

return
end

stop_decal_for_unit(unit)

if not ensure_decal_package() or not is_alive_unit(unit) or not World or not World.spawn_unit_ex or not Unit.world then
return
end

local world = Unit.world(unit)
local position = decal_position(unit)

if not world or not position then
return
end

local decal_unit = World.spawn_unit_ex(world, DECAL_PATH, nil, position)

if not is_valid_unit(decal_unit) then
return
end

if World.link_unit then
World.link_unit(world, decal_unit, ROOT_NODE_INDEX, unit, ROOT_NODE_INDEX)
end

decal_data = {
unit = decal_unit,
pickup_type = pickup_type,
category_id = category.id,
radius = DECAL_RADIUS,
active = false,
}

tracked_decals_by_unit[unit] = decal_data
apply_decal_style(decal_data, category)
end

local function apply_particle_radius_variable(world, effect_id, effect)
if not effect or effect.id ~= "fire_360angle_01" or not World.find_particles_variable or not World.set_particles_variable then
return
end

pcall(function()
local variable_index = World.find_particles_variable(world, effect.vfx, FIRE_360_RADIUS_VARIABLE)
local variable_value = Vector3(DECAL_RADIUS, DECAL_RADIUS, DECAL_RADIUS)

World.set_particles_variable(world, effect_id, variable_index, variable_value)
end)
end

local function spawn_linked_effect(world, unit, node_index, node_position, translation_offset, effect)
if not World or not World.create_particles or not World.link_particles or not effect then
return nil
end

local effect_id = World.create_particles(world, effect.vfx, node_position + translation_offset, Quaternion.identity())

if not effect_id then
return nil
end

apply_particle_radius_variable(world, effect_id, effect)

local attachment_pose = Matrix4x4.from_translation(translation_offset)

World.link_particles(world, effect_id, unit, node_index, attachment_pose, "destroy")

return effect_id
end

local function effect_repeat_interval(effect)
if not effect then
return nil
end

if effect.id == PULSE_EFFECT_ID then
return PULSE_INTERVAL
end

if effect.id == "fire_360angle_01" or effect.id == "electricity_grenade_01" or effect.id == RELIQUARY_EFFECT.id then
return REPEAT_INTERVAL
end

return nil
end

local function effect_offsets(effect_id)
return nil
end

local function effect_spawn_count(effect_id)
if effect_id == "daemonhost_shield" then
return 3
end

return 1
end

local function create_effect_record(world, unit, effect)
local node_index = ROOT_NODE_INDEX
local node_position = Unit.world_position(unit, node_index)
local offsets = effect_offsets(effect.id)
local particle_record = {}

if offsets then
for i = 1, #offsets do
local effect_id = spawn_linked_effect(world, unit, node_index, node_position, offsets[i], effect)

if effect_id then
particle_record[#particle_record + 1] = effect_id
end
end
else
local translation_offset = Vector3(0, 0, DEFAULT_HEIGHT)
local count = effect_spawn_count(effect.id)

for i = 1, count do
local effect_id = spawn_linked_effect(world, unit, node_index, node_position, translation_offset, effect)

if effect_id then
particle_record[#particle_record + 1] = effect_id
end
end
end

if #particle_record == 0 then
return nil
end

if #particle_record == 1 then
return particle_record[1]
end

return particle_record
end

local function effect_should_run(unit, effect_data, effect)
local category = effect_data and effect_data.category

if not category_enabled(category) then
return false
end

if category.fixed_effect then
return effect.id == category.fixed_effect.id and not is_currently_carried(unit)
end

return effect_enabled(category, effect)
end

local function spawn_effect(unit, effect_data, effect)
if not effect_data or not effect_should_run(unit, effect_data, effect) or not is_alive_unit(unit) then
return
end

local world = effect_data.world

if not world then
return
end

local active_effects = effect_data.active_effects
local old_particle_record = active_effects[effect.id]

stop_particle_record(world, old_particle_record)
active_effects[effect.id] = nil

local particle_record = create_effect_record(world, unit, effect)

if particle_record then
active_effects[effect.id] = particle_record
end
end

local function spawn_effects_for_unit(unit, pickup_type)
if not is_alive_unit(unit) then
return
end

local category = category_for_pickup_type(pickup_type)

if not category_has_any_effect(category) then
stop_decal_for_unit(unit)

return
end

show_decal_for_unit(unit, pickup_type, category)

if tracked_effects_by_unit[unit] then
return
end

if not category_has_particle_effect(category) or category and category.fixed_effect and is_currently_carried(unit) then
return
end

local world = Unit.world(unit)

if not world then
return
end

local effect_data = {
pickup_type = pickup_type,
category = category,
world = world,
active_effects = {},
timers = {},
}

tracked_effects_by_unit[unit] = effect_data

if category.fixed_effect then
spawn_effect(unit, effect_data, category.fixed_effect)

return
end

for i = 1, #EFFECTS do
local effect = EFFECTS[i]

if effect_repeat_interval(effect) then
effect_data.timers[effect.id] = 0
end

spawn_effect(unit, effect_data, effect)
end
end

local function update_effects(dt)
local update_dt = type(dt) == "number" and dt or 0

for unit, effect_data in pairs(tracked_effects_by_unit) do
local category = effect_data.category

if not is_alive_unit(unit) or not category_has_particle_effect(category) or category.fixed_effect and is_currently_carried(unit) then
stop_effect_for_unit(unit)
elseif category.fixed_effect then
local effect = category.fixed_effect
local effect_id = effect.id
local timers = effect_data.timers
local interval = effect_repeat_interval(effect)

if effect_should_run(unit, effect_data, effect) then
if interval then
if not effect_data.active_effects[effect_id] then
spawn_effect(unit, effect_data, effect)
timers[effect_id] = 0
else
timers[effect_id] = (timers[effect_id] or 0) + update_dt

if timers[effect_id] >= interval then
timers[effect_id] = timers[effect_id] % interval
spawn_effect(unit, effect_data, effect)
end
end
elseif not effect_data.active_effects[effect_id] then
spawn_effect(unit, effect_data, effect)
end
end
else
for i = 1, #EFFECTS do
local effect = EFFECTS[i]
local effect_id = effect.id
local timers = effect_data.timers
local interval = effect_repeat_interval(effect)

if effect_enabled(category, effect) then
if interval then
if not effect_data.active_effects[effect_id] then
spawn_effect(unit, effect_data, effect)
timers[effect_id] = 0
else
timers[effect_id] = (timers[effect_id] or 0) + update_dt

if timers[effect_id] >= interval then
timers[effect_id] = timers[effect_id] % interval
spawn_effect(unit, effect_data, effect)
end
end
elseif not effect_data.active_effects[effect_id] then
spawn_effect(unit, effect_data, effect)
end
else
stop_particle_record(effect_data.world, effect_data.active_effects[effect_id])
effect_data.active_effects[effect_id] = nil
timers[effect_id] = 0
end
end
end
end
end

function mod._salvage_maybe_register_player_drop_overlay(unit, pickup_type)
if pickup_type ~= PLAYER_DROP_PICKUP_TYPE or not is_alive_unit(unit) then
return
end

local raw_reason = mod._salvage_loot_handler_raw_drop_reason(unit)

if raw_reason == "reward" and not mod._salvage_player_drop_worth_by_unit[unit] and not mod._salvage_recent_cached_player_drop_worth() then
return
end

local reason = player_drop_reason_for_unit(unit) or PLAYER_DROP_REASON_DISABLED
local worth = mod._salvage_player_drop_worth_by_unit[unit] or mod._salvage_recent_cached_player_drop_worth()

if type(worth) == "number" and worth > 0 then
mod._salvage_player_drop_worth_by_unit[unit] = math.floor(worth + 0.5)
end

tracked_player_drop_pickups_by_unit[unit] = player_drop_marker_reason_from_source(reason)

if player_drop_markers_enabled() then
register_player_drop_pickup_unit(unit, reason, worth, false)
end
end

local function register_pickup_unit(unit)
if not should_run() or not is_alive_unit(unit) then
return
end

local pickup_type = pickup_type_from_unit(unit)

mod._salvage_maybe_register_player_drop_overlay(unit, pickup_type)

if not pickup_type or not category_for_pickup_type(pickup_type) then
return
end

tracked_pickups_by_unit[unit] = pickup_type
end

local function add_registered_pickup_units(desired_units)
for unit, pickup_type in pairs(tracked_pickups_by_unit) do
local category = category_for_pickup_type(pickup_type)

if is_alive_unit(unit) and category_has_any_effect(category) then
if not category.fixed_effect or not is_currently_carried(unit) then
desired_units[unit] = pickup_type
end
elseif not is_alive_unit(unit) then
tracked_pickups_by_unit[unit] = nil
end
end
end

local function add_marker_units(desired_units)
local ui_manager = Managers and Managers.ui
local hud = ui_manager and ui_manager.get_hud and ui_manager:get_hud()
local world_markers = hud and hud.element and hud:element("HudElementWorldMarkers")
local markers_by_type = world_markers and world_markers._markers_by_type

if not markers_by_type then
return
end

for _, markers in pairs(markers_by_type) do
for i = 1, #markers do
local marker = markers[i]
local unit = marker and marker.unit
local pickup_type = unit and pickup_type_from_unit(unit)

if not pickup_type then
pickup_type = pickup_type_from_marker_data(marker)
end

local category = category_for_pickup_type(pickup_type)

if type(unit) == "userdata" and category_has_any_effect(category) and (not category.fixed_effect or not is_currently_carried(unit)) then
desired_units[unit] = pickup_type
tracked_pickups_by_unit[unit] = pickup_type
end
end
end
end


function mod._salvage_add_pickup_system_player_drop_units(desired_units)
local pickup_system = mod._salvage_current_pickup_system()
local spawned_pickups = pickup_system and pickup_system._spawned_pickups

if type(spawned_pickups) ~= "table" then
return
end

for _, unit in pairs(spawned_pickups) do
if is_alive_unit(unit) and pickup_type_from_unit(unit) == PLAYER_DROP_PICKUP_TYPE then
local raw_reason = mod._salvage_loot_handler_raw_drop_reason(unit)

if raw_reason ~= "reward" then
local reason = player_drop_reason_for_unit(unit) or PLAYER_DROP_REASON_DISABLED

if not mod._salvage_player_drop_worth_by_unit[unit] and type(mod._salvage_bind_pending_player_drop_worth_to_existing_pickups) == "function" then
mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
end

desired_units[unit] = reason
tracked_player_drop_pickups_by_unit[unit] = reason
end
end
end
end

function mod._salvage_add_tracked_pickup_player_drop_units(desired_units)
for unit, pickup_type in pairs(tracked_pickups_by_unit) do
if is_alive_unit(unit) and pickup_type == PLAYER_DROP_PICKUP_TYPE then
local raw_reason = mod._salvage_loot_handler_raw_drop_reason(unit)

if raw_reason ~= "reward" then
local reason = player_drop_reason_for_unit(unit) or PLAYER_DROP_REASON_DISABLED

if not mod._salvage_player_drop_worth_by_unit[unit] and type(mod._salvage_bind_pending_player_drop_worth_to_existing_pickups) == "function" then
mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
end

desired_units[unit] = reason
tracked_player_drop_pickups_by_unit[unit] = reason
end
end
end
end

local function add_registered_player_drop_units(desired_units)
for unit, reason in pairs(tracked_player_drop_pickups_by_unit) do
local marker_reason = player_drop_marker_reason_from_source(reason)

if is_alive_unit(unit) and pickup_type_from_unit(unit) == PLAYER_DROP_PICKUP_TYPE and marker_reason then
desired_units[unit] = marker_reason
else
tracked_player_drop_pickups_by_unit[unit] = nil
mod._salvage_player_drop_worth_by_unit[unit] = nil
end
end
end

local function add_player_drop_marker_units(desired_units)
local ui_manager = Managers and Managers.ui
local hud = ui_manager and ui_manager.get_hud and ui_manager:get_hud()
local world_markers = hud and hud.element and hud:element("HudElementWorldMarkers")
local markers_by_type = world_markers and world_markers._markers_by_type

if not markers_by_type then
return
end

for _, markers in pairs(markers_by_type) do
for i = 1, #markers do
local marker = markers[i]
local unit = marker and marker.unit
local pickup_type = unit and pickup_type_from_unit(unit)

if not pickup_type then
pickup_type = pickup_type_from_marker_data(marker)
end

if type(unit) == "userdata" and pickup_type == PLAYER_DROP_PICKUP_TYPE and is_alive_unit(unit) then
local reason = player_drop_reason_for_unit(unit)

if reason then
desired_units[unit] = reason
tracked_player_drop_pickups_by_unit[unit] = reason
end
end
end
end
end

function mod._salvage_remember_stolen_minion_unit(unit, amount)
local numeric_amount = math.abs(tonumber(amount) or 0)

if not unit or numeric_amount <= 0 then
return
end

local existing_record = mod._salvage_stolen_loot_by_minion_unit[unit]
local existing_amount = math.abs(tonumber(existing_record and existing_record.amount) or 0)
mod._salvage_stolen_loot_by_minion_unit[unit] = {
amount = existing_amount + numeric_amount,
position = unit_position(unit) or existing_record and existing_record.position,
time = mod._salvage_current_main_time(),
}
end

function mod._salvage_observe_stolen_minion_sources()
local t = mod._salvage_current_main_time()

for unit, record in pairs(mod._salvage_stolen_loot_by_minion_unit) do
if is_alive_unit(unit) then
record.position = unit_position(unit) or record.position
record.time = t
elseif record then
remember_recent_player_drop_at_position(record.position, PLAYER_DROP_REASON_DISABLED, record.amount, false)
mod._salvage_stolen_loot_by_minion_unit[unit] = nil
end
end
end

function mod._salvage_remember_recent_stolen_minion_drop(amount)
local numeric_amount = math.abs(tonumber(amount) or 0)

if numeric_amount <= 0 then
return false
end

local rounded_amount = math.floor(numeric_amount + 0.5)
local best_unit = nil
local best_record = nil
local best_age = math.huge
local t = mod._salvage_current_main_time()

for unit, record in pairs(mod._salvage_stolen_loot_by_minion_unit) do
local record_amount = math.floor(math.abs(tonumber(record and record.amount) or 0) + 0.5)
local age = t - (record and record.time or 0)

if record_amount == rounded_amount and age <= 20 and age < best_age then
best_unit = unit
best_record = record
best_age = age
end
end

if best_record then
local position = unit_position(best_unit) or best_record.position
remember_recent_player_drop_at_position(position, PLAYER_DROP_REASON_DISABLED, best_record.amount, false)
mod._salvage_stolen_loot_by_minion_unit[best_unit] = nil
return true
end

return false
end

local function sync_player_drop_markers()
if not should_run() or not player_drop_markers_enabled() then
remove_all_player_drop_markers()
return
end

if not ensure_player_drop_marker_template() then
return
end

update_pending_player_drop_markers()

if type(mod._salvage_bind_pending_player_drop_worth_to_existing_pickups) == "function" then
mod._salvage_bind_pending_player_drop_worth_to_existing_pickups()
end

local desired_units = {}

mod._salvage_add_pickup_system_player_drop_units(desired_units)
mod._salvage_add_tracked_pickup_player_drop_units(desired_units)
add_registered_player_drop_units(desired_units)
add_player_drop_marker_units(desired_units)

for unit, reason in pairs(desired_units) do
request_player_drop_marker(unit, reason)
end

for unit, _ in pairs(tracked_player_drop_markers_by_unit) do
if not desired_units[unit] then
remove_player_drop_marker_for_unit(unit)
end
end
end

local function install_player_drop_reason_hooks()
if mod._salvage_player_drop_reason_hooks_done or type(mod.hook_require) ~= "function" then
return
end

mod._salvage_player_drop_reason_hooks_done = true

mod:hook_require("scripts/utilities/expeditions/expedition_loot_handler", function(instance)
if not instance then
return
end

if type(instance.add_external_player_pickup_unit) == "function" then
mod:hook_safe(instance, "add_external_player_pickup_unit", function(_, pickup_unit, amount, reason)
local flash_warning = reason == PLAYER_DROP_REASON_DISABLED or reason == PLAYER_DROP_REASON_DEATH

register_player_drop_pickup_unit(pickup_unit, reason or PLAYER_DROP_REASON_DISABLED, amount, flash_warning)
end)
end

if type(instance.server_drop_player_loot) == "function" then
mod:hook_safe(instance, "server_drop_player_loot", function(loot_handler)
local reasons = loot_handler and loot_handler._dropped_reason_by_pickup_unit

if type(reasons) ~= "table" then
return
end

for unit, reason in pairs(reasons) do
if is_alive_unit(unit) and pickup_type_from_unit(unit) == PLAYER_DROP_PICKUP_TYPE then
register_player_drop_pickup_unit(unit, reason, loot_handler and loot_handler._dropped_loot_by_pickup_unit and loot_handler._dropped_loot_by_pickup_unit[unit], reason == PLAYER_DROP_REASON_DEATH)
end
end
end)
end

if type(instance.rpc_client_expedition_loot_collected) == "function" then
mod:hook_safe(instance, "rpc_client_expedition_loot_collected", function(_, channel_id, peer_id, amount, loot_type)
if loot_type == "small" and type(amount) == "number" and amount < 0 then
local player_manager = Managers and Managers.player
local player = player_manager and peer_id and player_manager.player and player_manager:player(peer_id, 1)

remember_recent_player_drop(peer_id, player_status_drop_reason(player), math.abs(amount), true)
end
end)
end

if type(instance.rpc_client_expedition_remove_loot_collected) == "function" then
mod:hook_safe(instance, "rpc_client_expedition_remove_loot_collected", function(_, channel_id, peer_id, loot_type, amount_to_deduct)
if loot_type == "small" and type(amount_to_deduct) == "number" and amount_to_deduct > 0 then
remember_recent_player_drop(peer_id, PLAYER_DROP_REASON_DISABLED, amount_to_deduct, true, true)
end
end)
end

if type(instance._show_collected_materials_notification) == "function" then
mod:hook_safe(instance, "_show_collected_materials_notification", function(_, peer_id, amount, loot_type)
if loot_type == "small" and type(amount) == "number" and amount < 0 then
local player_manager = Managers and Managers.player
local player = player_manager and peer_id and player_manager.player and player_manager:player(peer_id, 1)

remember_recent_player_drop(peer_id, player_status_drop_reason(player), math.abs(amount), true)
end
end)
end
end)

mod:hook_require("scripts/utilities/expeditions/expedition_minion_loot_handler", function(instance)
if not instance then
return
end

if type(instance.rpc_player_loot_stolen) == "function" then
mod:hook_safe(instance, "rpc_player_loot_stolen", function(_, channel_id, peer_id, amount_to_steal, breed_id, game_object_id)
local unit_spawner = Managers and Managers.state and Managers.state.unit_spawner
local unit = unit_spawner and type(unit_spawner.unit) == "function" and unit_spawner:unit(game_object_id, nil, nil) or nil

mod._salvage_show_player_drop_worth_flash(amount_to_steal)
mod._salvage_remember_stolen_minion_unit(unit, amount_to_steal)
end)
end

if type(instance.rpc_minion_dropped_loot) == "function" then
mod:hook_safe(instance, "rpc_minion_dropped_loot", function(_, channel_id, amount_to_steal)
mod._salvage_remember_recent_stolen_minion_drop(amount_to_steal)
end)
end
end)

mod:hook_require("scripts/utilities/player_death", function(instance)
if not instance then
return
end

if type(instance.die) == "function" then
mod:hook_safe(instance, "die", function(unit)
remember_recent_player_drop_at_position(unit_position(unit), PLAYER_DROP_REASON_DEATH, nil, false)
end)
end

if type(instance.knock_down) == "function" then
mod:hook_safe(instance, "knock_down", function(unit)
remember_recent_player_drop_at_position(unit_position(unit), PLAYER_DROP_REASON_DISABLED, nil, false)
end)
end
end)
end

local function sync_effects()
if not should_run() then
stop_all_visuals(true)

return
end

local desired_units = {}

add_registered_pickup_units(desired_units)
add_marker_units(desired_units)

for unit, pickup_type in pairs(desired_units) do
mod._salvage_maybe_register_player_drop_overlay(unit, pickup_type)
spawn_effects_for_unit(unit, pickup_type)
end

for unit, effect_data in pairs(tracked_effects_by_unit) do
local desired_pickup_type = desired_units[unit]

if not is_alive_unit(unit) or not desired_pickup_type or effect_data.pickup_type ~= desired_pickup_type then
stop_effect_for_unit(unit)
end
end

for unit, decal_data in pairs(tracked_decals_by_unit) do
local desired_pickup_type = desired_units[unit]
local category = category_for_pickup_type(desired_pickup_type)

if not is_alive_unit(unit) or not desired_pickup_type or decal_data.pickup_type ~= desired_pickup_type or not decal_enabled(category) then
stop_decal_for_unit(unit)
end
end
end

mod.on_all_mods_loaded = function()
local fallen_setting = mod:get("mark_fallen_comrades")

if fallen_setting == true then
mod:set("mark_fallen_comrades", "all", true)
elseif fallen_setting == false or fallen_setting == "none" or fallen_setting == "off" then
mod:set("mark_fallen_comrades", "never", true)
elseif fallen_setting == "both" then
mod:set("mark_fallen_comrades", "all", true)
elseif fallen_setting == "incapacitated" then
mod:set("mark_fallen_comrades", "disabled_only", true)
end

install_menu_hidden_children_patch()
install_menu_font_size_patch()
mod._salvage_install_player_drop_marker_template_patch()
install_player_drop_reason_hooks()
mod._salvage_register_player_drop_notification_event()

local is_mod_loading = true

mod:hook_require("scripts/extension_systems/unit_templates", function(instance)
if not is_mod_loading then
return
end

if instance.pickup then
mod:hook_safe(instance.pickup, "local_unit_spawned", function(unit)
register_pickup_unit(unit)
end)

mod:hook_safe(instance.pickup, "husk_unit_spawned", function(unit)
register_pickup_unit(unit)
end)
end

if instance.decoy then
mod:hook_safe(instance.decoy, "local_unit_spawned", function(unit)
register_pickup_unit(unit)
end)

mod:hook_safe(instance.decoy, "husk_unit_spawned", function(unit)
register_pickup_unit(unit)
end)
end

is_mod_loading = false
end)

mod:hook("PickupSystem", "spawn_pickup", function(func, pickup_system, pickup_name, ...)
local pickup_unit, pickup_unit_go_id = func(pickup_system, pickup_name, ...)

if pickup_name == PLAYER_DROP_PICKUP_TYPE and is_alive_unit(pickup_unit) then
local raw_reason = mod._salvage_loot_handler_raw_drop_reason(pickup_unit)

if raw_reason ~= "reward" then
local reason = player_drop_reason_for_unit(pickup_unit) or PLAYER_DROP_REASON_DISABLED

register_player_drop_pickup_unit(pickup_unit, reason)
end
end

return pickup_unit, pickup_unit_go_id
end)

mod:hook_safe("PickupSystem", "dropped", function(_, pickup_unit)
if is_alive_unit(pickup_unit) and pickup_type_from_unit(pickup_unit) == PLAYER_DROP_PICKUP_TYPE then
local raw_reason = mod._salvage_loot_handler_raw_drop_reason(pickup_unit)

if raw_reason ~= "reward" then
local reason = player_drop_reason_for_unit(pickup_unit) or PLAYER_DROP_REASON_DISABLED

register_player_drop_pickup_unit(pickup_unit, reason)
end
end
end)

mod:hook_safe("UnitSpawnerManager", "mark_for_deletion", function(_, unit)
local stolen_record = mod._salvage_stolen_loot_by_minion_unit[unit]

if stolen_record then
remember_recent_player_drop_at_position(stolen_record.position, PLAYER_DROP_REASON_DISABLED, stolen_record.amount, true)
end

stop_effect_for_unit(unit)
stop_decal_for_unit(unit)
remove_fallen_marker_for_unit(unit)
remove_player_drop_marker_for_unit(unit)
found_fallen_comrades_by_unit[unit] = nil
tracked_pickups_by_unit[unit] = nil
tracked_player_drop_pickups_by_unit[unit] = nil
mod._salvage_stolen_loot_by_minion_unit[unit] = nil
mod._salvage_player_drop_worth_by_unit[unit] = nil
observed_local_player_drop_states_by_unit[unit] = nil
end)

if exits and type(exits.on_all_mods_loaded) == "function" then
exits.on_all_mods_loaded()
end
end

mod.update = function(dt)
if exits and type(exits.update) == "function" then
exits.update(dt)
end

if not should_run() then
stop_all_visuals(true)
remove_all_fallen_markers()
remove_all_player_drop_markers()
sync_timer = SYNC_INTERVAL
fallen_marker_sync_timer = FALLEN_MARKER_SYNC_INTERVAL
player_drop_marker_sync_timer = PLAYER_DROP_MARKER_SYNC_INTERVAL

return
end

local update_dt = type(dt) == "number" and dt or 0

sync_timer = sync_timer + update_dt
fallen_marker_sync_timer = fallen_marker_sync_timer + update_dt
player_drop_marker_sync_timer = player_drop_marker_sync_timer + update_dt

if sync_timer >= SYNC_INTERVAL then
sync_timer = sync_timer % SYNC_INTERVAL
sync_effects()
end

if fallen_marker_sync_timer >= FALLEN_MARKER_SYNC_INTERVAL then
fallen_marker_sync_timer = fallen_marker_sync_timer % FALLEN_MARKER_SYNC_INTERVAL
sync_fallen_comrade_markers()
end

if player_drop_marker_sync_timer >= PLAYER_DROP_MARKER_SYNC_INTERVAL then
player_drop_marker_sync_timer = player_drop_marker_sync_timer % PLAYER_DROP_MARKER_SYNC_INTERVAL
observe_local_player_drop_source()
mod._salvage_observe_stolen_minion_sources()
sync_player_drop_markers()
end

update_effects(update_dt)
end

mod.on_setting_changed = function(setting_id)
if is_salvage_effect_setting(setting_id) then
stop_all_visuals(false)
sync_timer = SYNC_INTERVAL

if should_run() then
sync_effects()
end
end

if setting_id == "mark_fallen_comrades" then
remove_all_fallen_markers()
fallen_marker_sync_timer = FALLEN_MARKER_SYNC_INTERVAL

if should_run() then
sync_fallen_comrade_markers()
end
end

if setting_id == "mark_player_dropped_remnants" then
remove_all_player_drop_markers()
player_drop_marker_sync_timer = PLAYER_DROP_MARKER_SYNC_INTERVAL

if should_run() then
sync_player_drop_markers()
end
end

if setting_id == "player_drop_warning" then
mod._salvage_player_drop_worth_warning.last_amount = nil
mod._salvage_player_drop_worth_warning.last_t = -999
end

if exits and type(exits.on_setting_changed) == "function" then
exits.on_setting_changed(setting_id)
end
end

mod.on_game_state_changed = function(status)
if status == "exit" then
stop_all_visuals(true)
remove_all_fallen_markers()
remove_all_player_drop_markers()
sync_timer = SYNC_INTERVAL
fallen_marker_sync_timer = FALLEN_MARKER_SYNC_INTERVAL
player_drop_marker_sync_timer = PLAYER_DROP_MARKER_SYNC_INTERVAL
end

if exits and type(exits.on_game_state_changed) == "function" then
exits.on_game_state_changed(status)
end
end

mod.on_unload = function()
stop_all_visuals(true)
remove_all_fallen_markers()
remove_all_player_drop_markers()

if exits and type(exits.on_unload) == "function" then
exits.on_unload()
end
end

mod.on_disabled = function()
stop_all_visuals(true)
remove_all_fallen_markers()
remove_all_player_drop_markers()

if exits and type(exits.on_disabled) == "function" then
exits.on_disabled()
end
end
