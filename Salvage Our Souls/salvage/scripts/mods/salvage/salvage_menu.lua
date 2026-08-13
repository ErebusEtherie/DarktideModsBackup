-- salvage_menu.lua
local mod = get_mod("salvage")
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
local menu = {}
function menu.on_all_mods_loaded()
install_menu_hidden_children_patch()
install_menu_font_size_patch()
end
return menu
