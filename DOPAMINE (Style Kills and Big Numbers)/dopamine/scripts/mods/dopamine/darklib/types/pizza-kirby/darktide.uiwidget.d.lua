---@meta _

---@class UIWidget
UIWidget = {}

---@alias PassType string

---@class Pass
---@class PassInfo
---@class UIRenderer
---@class UIWidgetDefinition
---@class Scenegraph
---@class DestinationContent
---@class Destination

---@class MaterialValues
---@field right_offset? number
---@field left_offset? number
---@field rows? number
---@field grid_index? number
---@field columns? number
---@field use_placeholder_texture? number

---@class PassDefinitionStyle
---@field vertical_alignment? "bottom" | "center" | "top"
---@field horizontal_alignment? "left" | "center" | "right"
---@field offset? number[] length: 3
---@field color? number[] length: 4, rgba
---@field size? number[] length: 2
---@field material? string
---@field font_size? number
---@field default_font_size? number
---@field line_spacing? number
---@field drop_shadow? boolean
---@field font_type? string
---@field debug_draw_box? boolean
---@field default_color? number[] length: 4, rgba
---@field default_text_color? number[] length: 4, rgba
---@field text_color? number[] length: 4, rgba
---@field disabled_text_color? number[] length: 4, rgba
---@field anim_focus_speed? number
---@field anim_input_speed? number
---@field anim_hover_speed? number
---@field anim_select_speed? number
---@field scale_to_material? boolean
---@field size_addition? number[] length: 3
---@field hover_color? number[] length: 4, rgba
---@field selected_color? number[] length: 4, rgba
---@field disabled_color? number[] length: 4, rgba
---@field hdr? boolean
---@field uvs? uv
---@field material_values? MaterialValues
---@field highlight_color? number[] length: 4, rgba
---@field idle_color? number[] length: 4, rgba
---@field default_width? number

---@class PassDefinitionContent
---@field is_focused? boolean
---@field use_is_focused? boolean

---@class ContentOverrides
---@field visible? boolean
---@field scroll_amount? number
---@field scroll_speed? number
---@field num_party_members? number
---@field flicker_data? { fade_in: number }
---@field time_till_next_flicker? number[]
---@field max_num_party_members? number
---@field blueprint_name? string

---@class PassDefinition
---@field pass_type PassType
---@field value? string | function
---@field style_id? string
---@field value_id? string
---@field content_id? string
---@field style? PassDefinitionStyle
---@field content? PassDefinitionContent
---@field visibility_function? function
---@field change_function? function

---@param name string
---@param widget_definition UIWidgetDefinition
---@return UIWidget
function UIWidget.init(name, widget_definition) end

---@param ui_renderer UIRenderer
---@param widget UIWidget
---@return nil
function UIWidget.destroy(ui_renderer, widget) end

---@param widget UIWidget
---@param animation string ---NOTE: it's used as key, is it a string?
---@return nil
function UIWidget.animate(widget, animation) end

---@param widget UIWidget
---@return nil
function UIWidget.stop_animations(widget) end

---@param pass_definitions PassDefinition[]
---@param scenegraph_id string
---@param content_overrides? ContentOverrides
---@param optional_size? number[] length: 2
---@param style_overrides? PassDefinitionStyle[]
---@param definition_overrides? table not used internally
---@return UIWidgetDefinition definition
function UIWidget.create_definition(pass_definitions, scenegraph_id, content_overrides, optional_size, style_overrides, definition_overrides) end

---@param destination table Pass[] ?
---@param pass_info table PassInfo ?
---@return nil
function UIWidget.add_definition_pass(destination, pass_info) end

---@alias uv {[integer]: {[integer]: number}}
---@alias out_uv uv

---@param parent_pos_x number
---@param parent_pos_y number
---@param parent_size_x number
---@param parent_size_y number
---@param child_pos_x number
---@param child_pos_y number
---@param child_size_x number
---@param child_size_y number
---@param optional_child_uvs? uv must be a table of form {{number,number},{number,number}}
---@param out_uvs? out_uv must be a 2-dimensional table
---@return number child_pos_x
---@return number child_pos_y
---@return number child_size_x
---@return number child_size_y
---@return uv? out_uvs only if out_uvs params was supplied, is of form {{number,number},{number,number}}
function UIWidget._get_clip_uv(parent_pos_x, parent_pos_y, parent_size_x, parent_size_y, child_pos_x, child_pos_y, child_size_x, child_size_y, optional_child_uvs, out_uvs) end

---@param widget UIWidget
---@param ui_renderer UIRenderer
---@return nil
function UIWidget.draw(widget, ui_renderer) end

---@param widget UIWidget
---@param ui_renderer UIRenderer
---@param visible boolean
---@return boolean
function UIWidget.set_visible(widget, ui_renderer, visible) end
