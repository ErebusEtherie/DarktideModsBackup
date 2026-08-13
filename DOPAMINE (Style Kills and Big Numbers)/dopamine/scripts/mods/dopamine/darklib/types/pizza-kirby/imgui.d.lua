---@meta
---@class Imgui
Imgui = {
    _name = "Imgui",
    KEY_LEFT_ARROW = 513,
    KEY_RIGHT_ARROW = 514,
    KEY_UP_ARROW = 515,
    KEY_DOWN_ARROW = 516,
    KEY_BACKSPACE = 523,
    COLOR_TEXT = 0,
    COLOR_TEXT_DISABLED = 1,
    COLOR_WINDOW_BG = 2,
    COLOR_CHILD_BG = 3,
    COLOR_POPUP_BG = 4,
    COLOR_BORDER = 5,
    COLOR_BORDER_SHADOW = 6,
    COLOR_FRAME_BG = 7,
    COLOR_FRAME_BG_HOVERED = 8,
    COLOR_FRAME_BG_ACTIVE = 9,
    COLOR_TITLE_BG = 10,
    COLOR_TITLE_BG_ACTIVE = 11,
    COLOR_TITLE_BG_COLLAPSED = 12,
    COLOR_MENU_BAR_BG = 13,
    COLOR_SCROLLBAR_BG = 14,
    COLOR_SCROLLBAR_GRAB = 15,
    COLOR_SCROLLBAR_GRAB_HOVERED = 16,
    COLOR_SCROLLBAR_GRAB_ACTIVE = 17,
    COLOR_CHECK_MARK = 18,
    COLOR_SLIDER_GRAB = 19,
    COLOR_SLIDER_GRAB_ACTIVE = 20,
    COLOR_BUTTON = 21,
    COLOR_BUTTON_HOVERED = 22,
    COLOR_BUTTON_ACTIVE = 23,
    COLOR_HEADER = 24,
    COLOR_HEADER_HOVERED = 25,
    COLOR_HEADER_ACTIVE = 26,
    COLOR_SEPARATOR = 27,
    COLOR_SEPARATOR_HOVERED = 28,
    COLOR_SEPARATOR_ACTIVE = 29,
    COLOR_RESIZE_GRIP = 30,
    COLOR_RESIZE_GRIP_HOVERED = 31,
    COLOR_RESIZE_GRIP_ACTIVE = 32,
    COLOR_PLOT_LINES = 43,
    COLOR_PLOT_LINES_HOVERED = 44,
    COLOR_PLOT_HISTOGRAM = 45,
    COLOR_PLOT_HISTOGRAM_HOVERED = 46,
    COLOR_TEXT_SELECTED_BG = 53,
    COLOR_DRAG_DROP_TARGET = 55,
    COLOR_NAV_HIGHLIGHT = 56,
    COLOR_NAV_WINDOWING_HIGHLIGHT = 57,
    COLOR_NAV_WINDOWING_DIM_BG = 58,
    COLOR_MODAL_WINDOW_DIM_BG = 59,
    SELECTABLE_NONE = 0,
    SELECTABLE_DONT_CLOSE_POPUPS = 1,
    SELECTABLE_SPAN_ALL_COLUMNS = 2,
    SELECTABLE_ALLOW_DOUBLE_CLICK = 4,
    SELECTABLE_DISABLED = 8,
    SELECTABLE_ALLOW_ITEM_OVERLAP = 16,
}

---@alias ImGuiID integer
---@alias TableFlags integer
---@alias ChildFlags integer
---@alias TabItemFlags integer
---@alias TableRowFlags integer
---@alias TableColumnFlags integer
---@alias DockNodeFlags integer
---@alias TabBarFlags integer
---@alias Cond integer
---@alias MouseButton integer
---@alias Key integer

---@alias ColorId integer

---@alias WindowFlags

---@param id string
---@return unknown
Imgui.activate_item = function(id) end

---@source imgui_docking.h
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param offset_x_1 number
---@param offset_y_1 number
---@param offset_x_2 number
---@param offset_y_2 number
---@param color Vector4
---@param thickness number
---@param num_segments? integer
---@return nil
Imgui.add_bezier_curve = function(x1, y1, x2, y2, offset_x_1, offset_y_1, offset_x_2, offset_y_2, color, thickness, num_segments) end

---@source https://github.com/ocornut/imgui/blob/763db046fa25517b8ab4627f9188a5cdbea5ea51/imgui_docking.h#L15
---@param x number
---@param y number
---@param radius number
---@param color Vector4
---@param num_segments integer
---@param thickness number
---@return nil
Imgui.add_circle = function(x, y, radius, color, num_segments, thickness) end

---@source imgui_docking.h
---@param x number
---@param y number
---@param radius number
---@param color Vector4
---@param num_segments integer
---@return nil
Imgui.add_circle_filled = function(x, y, radius, color, num_segments) end

---@source imgui_docking.h
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param color Vector4
---@param thickness number
---@return nil
Imgui.add_line = function(x1, y1, x2, y2, color, thickness) end

---@source imgui_docking.h
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param color Vector4
---@param rounding number
---@param thickness number
---@return nil
Imgui.add_rect = function(x1, y1, x2, y2, color, rounding, thickness) end

---@source imgui_docking.h
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param color Vector4
---@param rounding? number
---@return nil
Imgui.add_rect_filled = function(x1, y1, x2, y2, color, rounding) end

---@source imgui_docking.h
---@param text string
---@param x number
---@param y number
---@param color Vector4
---@param font_size number
---@return nil
Imgui.add_text = function(text, x, y, color, font_size) end

---@source imgui_docking.h
---@see BeginChild
---@param id string
---@param width number
---@param height number
---@param flags ChildFlags
---@return boolean visible
Imgui.begin_child_window = function(id, width, height, flags) end

---@source imgui_docking.h
---@param label string
---@param preview_value string
---@return boolean unknown
Imgui.begin_combo = function(label, preview_value) end

---@source imgui_docking.h
---@return boolean unknown
Imgui.begin_main_menu_bar = function() end

---@source imgui_docking.h
---@param label string
---@return boolean open
Imgui.begin_menu = function(label) end

---@return boolean unknown
Imgui.begin_menu_bar = function() end

---@source imgui_docking.h
---@param id string
---@return boolean returns true if the popup is open
Imgui.begin_popup = function(id) end

---@param id string
---@param flags TabBarFlags
---@return boolean success
Imgui.begin_tab_bar = function(id, flags) end

---@source imgui_docking.h
---@param label string
---@param p_open boolean
---@param flags TabItemFlags
---@return boolean selected returns true if the tab is selected
Imgui.begin_tab_item = function(label, p_open, flags) end

---@source imgui_docking.h
---@param id string
---@param columns integer
---@param flags TableFlags
---@param x number
---@param y number
---@param inner_width number
Imgui.begin_table = function(id, columns, flags, x, y, inner_width) end

---@source imgui_docking.h
---@return nil
Imgui.begin_tool_tip = function() end

---@param name string
---@param ... WindowFlags
---@return boolean visible false means either collapsed or fully clipped
---@return boolean closed
---@source imgui_docking.h
Imgui.begin_window = function(name, ...) end
---@param menu_bar boolean
Imgui.begin_window = function(name, menu_bar) end

---@source imgui_docking.h
---@param fmt string
---@param ... any
---@return nil
Imgui.bullet_text = function(fmt, ...) end

---@param label string
---@param width? number
---@param height? number
---@return boolean clicked
---@source imgui_docking.h
Imgui.button = function(label, width, height) end

---@param text string
---@return number x
---@return number y
---@source imgui_docking.h:801
Imgui.calculate_text_size = function(text) end

---@source imgui_docking.h
---@return nil
Imgui.channels_merge = function() end

---@source imgui_docking.h
---@param index integer
---@return nil
Imgui.channel_set_current = function(index) end

---@source imgui_docking.h
---@param count integer
---@return nil
Imgui.channel_split = function(count) end

---@source imgui_docking.h
---@param label string
---@param value boolean
---@return boolean unknown
Imgui.checkbox = function(label, value) end

---@source imgui_docking.h
---@return nil
Imgui.close_current_popup = function() end

---@source imgui_docking.h
---@return unknown
Imgui.close_imgui = function() end

---@source imgui_docking.h
---@param label string
---@param default_open boolean
---@return boolean
Imgui.collapsing_header = function(label, default_open) end

---@source imgui_docking.h
---@param label string
---@param red number 0.0 - 1.0
---@param green number 0.0 - 1.0
---@param blue number 0.0 - 1.0
---@return number red 0.0 - 1.0
---@return number green 0.0 - 1.0
---@return number blue 0.0 - 1.0
Imgui.color_edit_3 = function(label, red, green, blue) end

---@source imgui_docking.h
---@param label string
---@param red number 0.0 -  1.0
---@param green number 0.0 - 1.0
---@param blue number 0.0 - 1.0
---@param alpha number 0.0 - 1.0
---@return number red 0.0 - 1.0
---@return number green 0.0 - 1.0
---@return number blue 0.0 - 1.0
---@return number alpha 0.0 - 1.0
Imgui.color_edit_4 = function(label, red, green, blue, alpha) end

---@source imgui_docking.h
---@param label string
---@param red number 0.0 -  1.0
---@param green number 0.0 - 1.0
---@param blue number 0.0 - 1.0
---@return number red 0.0 - 1.0
---@return number green 0.0 - 1.0
---@return number blue 0.0 - 1.0
Imgui.color_picker_3 = function(label, red, green, blue) end

---@source imgui_docking.h
---@param label string
---@param red number 0.0 -  1.0
---@param green number 0.0 - 1.0
---@param blue number 0.0 - 1.0
---@param alpha number 0.0 - 1.0
---@return number red 0.0 - 1.0
---@return number green 0.0 - 1.0
---@return number blue 0.0 - 1.0
---@return number alpha 0.0 - 1.0
Imgui.color_picker_4 = function(label, red, green, blue, alpha) end

---@source imgui_docking.h
---@param count integer
---@param border boolean
Imgui.columns = function(count, border) end

---@source imgui_docking.h
---@param label string
---@param current_item unknown likely int
---@param values string[]
---@param max_height integer max height in **items**
Imgui.combo = function(label, current_item, values, max_height) end

Imgui.MOUSE = nil
Imgui.KEYBOARD = nil
Imgui.GAMEPAD = nil

---@source imgui_docking.h
---@param systems unknown
---@return unknown
Imgui.disable_imgui_input_system = function(systems) end

---@source imgui_docking.h
---@param ... unknown
---@return unknown
Imgui.disable_keyboard_navigation = function(...) end

---@source imgui_docking.h
---@param label string
---@param x number
---@return unknown
Imgui.drag_float = function(label, x) end

---@source imgui_docking.h
---@param label number
---@param x number
---@param y number
---@return unknown
Imgui.drag_float_2 = function(label, x, y) end

---@source imgui_docking.h
---@param label string
---@param x number
---@param y number
---@param z number
---@return unknown
Imgui.drag_float_3 = function(label, x, y, z) end

---@source imgui_docking.h
---@param label string
---@param x number
---@param y number
---@param z number
---@param w number
---@return unknown
Imgui.drag_float_4 = function(label, x, y, z, w) end

---@source imgui_docking.h:404
---@param width integer
---@param height integer
---@return nil
Imgui.dummy = function(width, height) end

---@source imgui_docking.h
---@param systems unknown
---@return unknown
Imgui.enable_imgui_input_systems = function(systems) end

---@source imgui_docking.h
---@return unknown
Imgui.enable_text_cursor_blink = function() end

---@source imgui_docking.h
---@deprecated no longer exists
---@return unknown
Imgui.enable_keyboard_navigation = function() end

---@source imgui_docking.h
---@see EndChild()
---@return nil
Imgui.end_child_window = function() end

---@source imgui_docking.h
Imgui.end_combo = function() end

---@source imgui_docking.h
---@return unknown
Imgui.disable_imgui_input_systems = function() end

---@source imgui_docking.h
---@return unknown
Imgui.disable_text_cursor_blink = function() end

---@source imgui_docking.h
---@param dockspace_id integer
---@param x number
---@param y number
---@param flags? DockNodeFlags
---@return integer unknown
Imgui.dock_space = function(dockspace_id, x, y, flags) end

---@source imgui_docking.h
---@param dockspace_id integer
---@param viewport Viewport
---@param flags? DockNodeFlags
---@return integer unknown
Imgui.dock_space_over_viewport = function(dockspace_id, viewport, flags) end

---@source imgui_docking.h
---@return nil
Imgui.end_main_menu_bar = function() end

---@source imgui_docking.h
---@return nil
Imgui.end_menu = function() end

---@source imgui_docking.h
---@return nil
Imgui.end_menu_bar = function() end

---@source imgui_docking.h
---@return nil
Imgui.end_popup = function() end

---@source imgui_docking.h
---@return nil
Imgui.end_tab_bar = function() end

---@source imgui_docking.h
---@return nil
Imgui.end_tab_item = function() end

---@source imgui_docking.h
---@return nil
Imgui.end_table = function() end

---@source imgui_docking.h
---@return nil
Imgui.end_tool_tip = function() end

---@see EndFrame()
---@source imgui_docking.h
---@return nil
Imgui.end_window = function() end

---@source imgui_docking.h
---@param id string
---@return unknown
Imgui.focus_item = function(id) end

---@source imgui_docking.h
---@return number x
---@return number y
Imgui.get_content_region_avail = function() end

---@source imgui_docking.h
---@return number x
---@return number y
Imgui.get_cursor_screen_pos = function() end

---@source imgui_docking.h
---@return number font_size
Imgui.get_font_size = function() end

---@source imgui_docking.h
---@param label string
---@return ImGuiID id
Imgui.get_id = function(label) end

---@source imgui_docking.h
---@return number x
---@return number y
Imgui.get_item_rect_max = function() end

---@source imgui_docking.h
---@return number x
---@return number y
Imgui.get_item_rect_min = function() end

---@source imgui_docking.h
---@return number x
---@return number y
Imgui.get_item_rect_size = function() end

---@source imgui_docking.h
---@return number x
---@return number y
Imgui.get_mouse_delta = function() end

---@source imgui_docking.h
---@return number x
---@return number y
Imgui.get_mouse_pos = function() end

---@source imgui_docking.h
---@return number scroll >0 scrolls up, <0 scrolls down, turns horizontal when shift is held
Imgui.get_mouse_wheel_value = function() end

---@source imgui_docking.h
Imgui.get_sort_specs = function() end

---@param key ImGuiID
---@source @source imgui_docking.h:2935
---@return integer
Imgui.get_state_storage_integer = function(key) end

---@source imgui_docking.h
---@return ImGuiID
Imgui.get_window_dock_id = function() end

---@source imgui_docking.h:4242
---@return number x
---@return number y
Imgui.get_window_pos = function() end

---@source imgui_docking.h
---@return number x
---@return number y
Imgui.get_window_size = function() end

---@source imgui_docking.h
---@param texture any
---@param width number
---@param height number
---@param red_tint number
---@param green_tint number
---@param blue_tint number
---@param alpha number
---@return nil
Imgui.image = function(texture, width, height, red_tint, green_tint, blue_tint, alpha) end

---@source imgui_docking.h
---@param texture any
---@param width number
---@param height number
---@param red_tint number
---@param green_tint number
---@param blue_tint number
---@param alpha number
---@return nil
Imgui.image_button = function(texture, width, height, red_tint, green_tint, blue_tint, alpha) end

---@source imgui_docking.h
---@return boolean
Imgui.imgui_active = function() end

---@source imgui_docking.h
---@param width number
---@return nil
Imgui.indent = function(width) end

---@source imgui_docking.h
---@param label string
---@param x number
---@param format string
---@return number n
Imgui.input_float = function(label, x, format) end

---@source imgui_docking.h
---@param label string
---@param x number
---@param y number
---@return number x
---@return number y
Imgui.input_float_2 = function(label, x, y) end

---@source imgui_docking.h
---@param label string
---@param x number
---@param y number
---@param z number
---@return number x
---@return number y
---@return number z
Imgui.input_float_3 = function(label, x, y, z) end

---@source imgui_docking.h
---@param label string
---@param x number
---@param y number
---@param z number
---@param w number
Imgui.input_float_4 = function(label, x, y, z, w) end

---@source imgui_docking.h
---@param label string
---@param x integer
---@return integer x
Imgui.input_int = function(label, x) end

---@source imgui_docking.h
---@param label string
---@param x integer
---@param y integer
---@return integer x
---@return integer y
Imgui.input_int_2 = function(label, x, y) end

---@source imgui_docking.h
---@param label string
---@param x integer
---@param y integer
---@param z integer
---@return integer x
---@return integer y
---@return integer z
Imgui.input_int_3 = function(label, x, y, z) end

---@source imgui_docking.h
---@param label string
---@param x integer
---@param y integer
---@param z integer
---@param w integer
---@return integer x
---@return integer y
---@return integer z
---@return integer w
Imgui.input_int_4 = function(label, x, y, z, w) end

---@source imgui_docking.h
---@param label string
---@param text string
---@return string text
Imgui.input_text = function(label, text) end

---@source imgui_docking.h
---@param label string
---@param text string
---@return string text
Imgui.input_text_multiline = function(label, text) end

---@source imgui_docking.h
---@return boolean active
Imgui.is_item_active = function() end

---@source imgui_docking.h
---@return boolean active
Imgui.is_item_focused = function() end

---@source imgui_docking.h
---@return boolean active
Imgui.is_item_hovered = function() end

---@source imgui_docking.h
---@param key Key
---@return boolean down
Imgui.is_key_down = function(key) end

---@source imgui_docking.h
---@param key Key
---@return boolean pressed
Imgui.is_key_pressed = function(key) end

---@source imgui_docking.h
---@param button MouseButton
---@return boolean clicked
Imgui.is_mouse_clicked = function(button) end

---@source imgui_docking.h
---@param button MouseButton
---@param threshold number
---@return boolean dragging
Imgui.is_mouse_dragging = function(button, threshold) end

---@source imgui_docking.h
---@param id string
---@return boolean open
Imgui.is_popup_open = function(id) end

---@source imgui_docking.h
---@return boolean docked
Imgui.is_window_docked = function() end

---@source imgui_docking.h
---@return boolean hovered
Imgui.is_window_hovered = function() end

---@source imgui_docking.h
---@param label string
---@param current_item string
---@param values string[]
---@return boolean unknown
Imgui.list_box = function(label, current_item, values) end

---@source imgui_docking.h
---@param label string
---@return boolean selected
Imgui.menu_item = function(label) end

---@source imgui_docking.h
---@return unknown
Imgui.nav_move_request_cancel = function() end

---@source imgui_docking.h
---@return nil
Imgui.next_column = function() end

---@source imgui_docking.h
---@return unknown
Imgui.open_imgui = function() end

---@source imgui_docking.h
---@param id string
---@return nil
Imgui.open_popup = function(id) end

---@source imgui_docking.h
---@param id string
---@return nil
Imgui.open_popup_on_item_click = function(id) end

---@source imgui_docking.h
---@param label string
---@param values number[]
---@return nil
Imgui.plot_histogram = function(label, values) end

---@source imgui_docking.h
---@param label string
---@param values number[]
---@return nil
Imgui.plot_lines = function(label, values) end

---@source imgui_docking.h
---@return nil
Imgui.pop_clip_rect = function() end

---@source imgui_docking.h
---@return nil
Imgui.pop_id = function() end

---@source imgui_docking.h
---@return nil
Imgui.pop_item_width = function() end

---@source imgui_docking.h
---@param count? integer default 1
---@return nil
Imgui.pop_style_color = function(count) end

---@source imgui_docking.h
---@return nil
Imgui.pop_text_wrap_pos = function() end

---@source imgui_docking.h
---@param value number
---@return nil
Imgui.progress_bar = function(value) end

---@source imgui_docking.h
---@param id string|integer|unknown
---@return nil
Imgui.push_id = function(id) end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param intersect_with_current boolean
---@return nil
Imgui.push_clip_rect = function(x1, y1, x2, y2, intersect_with_current) end

---@source imgui_docking.h
---@param width number
---@return nil
Imgui.push_item_width = function(width) end

---@source imgui_docking.h
---@param id ColorId
---@param r number
---@param g number
---@param b number
---@param a number
---@return nil
Imgui.push_style_color = function(id,r,g,b,a) end

---@source imgui_docking.h
---@param position number # <0.0f: no wrapping, ==0.0f: wrap to end of window (or column); > 0.0f: wrap at 'position' in window local space
---@return nil
Imgui.push_text_wrap_pos = function(position) end

---@source imgui_docking.h
---@param label number
---@param value boolean
---@return boolean|unknown
Imgui.radio_button = function(label, value) end

---@source imgui_docking.h
---@param spacing number
---@return nil
Imgui.same_line = function(spacing) end

---@source imgui_docking.h
---@param label string
---@param selected boolean
---@return boolean
Imgui.selectable = function(label, selected) end

---@source imgui_docking.h
---@return nil
Imgui.separator = function() end

---@source imgui_docking.h
---@param width number in pixels
---@param index integer
---@return nil
Imgui.set_column_width = function(width, index) end

---@source imgui_docking.h
---@param x number
---@param y number
---@return nil
Imgui.set_cursor_pos = function(x, y) end

---@source imgui_docking.h
---@param x number
---@param y number
---@return nil
Imgui.set_cursor_screen_pos = function(x, y) end

---@source imgui_docking.h
---@return nil
Imgui.set_item_default_focus = function() end

---@source imgui_docking.h
---@param offset integer ==0 next item, >0 subitem of next item, ==-1 previous item
---@return nil
Imgui.set_keyboard_focus_here = function(offset) end

---@source imgui_docking.h
---@param dock_id ImGuiID
---@param cond integer|unknown unlikely to be included
---@return nil
Imgui.set_next_window_dock_id = function(dock_id, cond) end

---@source imgui_docking.h
---@param x number
---@param y number
---@return nil
Imgui.set_next_window_pos = function(x, y) end

---@source imgui_docking.h
---@param width number
---@param height number
---@return nil
Imgui.set_next_window_size = function(width, height) end

---@source imgui_docking.h:511
---@param center_y_ratio number where it is placed in the view 0.0-1.0, 0.0 being top, 1.0 being bottom
---@return nil
Imgui.set_scroll_here = function(center_y_ratio) end

---@source imgui_docking.h:2935
---@param key ImGuiID
---@param value integer
---@return nil
Imgui.set_state_storage_integer = function(key, value) end

---@source imgui_docking.h
---@param scale number
---@return nil
Imgui.set_window_font_scale = function(scale) end

---@source imgui_docking.h:439
---@param width number
---@param height number
---@param flag Cond
---@return nil
Imgui.set_window_size = function(width, height, flag) end

---@source imgui_docking.h:706
---@param label string
---@param x number
---@param min number
---@param max number
---@return number x
Imgui.slider_float = function(label, x, min, max) end

---@source imgui_docking.h:707
---@source imgui_docking.h:706
---@param label string
---@param x number
---@param y number
---@param min number
---@param max number
---@return number x
---@return number y
Imgui.slider_float_2 = function(label, x, y, min, max) end

---@source imgui_docking.h:708
---@source imgui_docking.h:707
---@source imgui_docking.h:706
---@param label string
---@param x number
---@param y number
---@param z number
---@param min number
---@param max number
---@return number x
---@return number y
---@return number z
Imgui.slider_float_3 = function(label, x, y, z, min, max) end

---@source imgui_docking.h:709
---@source imgui_docking.h:707
---@source imgui_docking.h:706
---@param label string
---@param x number
---@param y number
---@param z number
---@param w number
---@param min number
---@param max number
---@return number x
---@return number y
---@return number z
---@return number w
Imgui.slider_float_4 = function(label, x, y, z, w, min, max) end

---@source imgui_docking.h:711
---@param label string
---@param x integer
---@param min integer
---@param max integer
---@return integer x
Imgui.slider_int = function(label, x, min, max) end

---@source imgui_docking.h
---@param label string
---@return boolean success
Imgui.small_button = function(label) end

---@source imgui_docking.h
---@return nil
Imgui.spacing = function() end

---@source imgui_docking.h
---@param label string
---@return nil
Imgui.table_header = function(label) end

---@source imgui_docking.h
---@return nil
Imgui.table_headers_row = function() end

---@source imgui_docking.h
---@return boolean visible true if the column is visible
Imgui.table_next_column = function() end

---@source imgui_docking.h
---@param flags? TableRowFlags|unknown
---@param min_row_height? number|unknown #includes padding
---@return nil
Imgui.table_next_row = function(flags, min_row_height) end

---@source imgui_docking.h
---@param column integer
---@return boolean visible true if the column is visible
Imgui.table_set_column_index = function(column) end

---@source imgui_docking.h
---@param label string
---@param flags TableColumnFlags
---@param init_width_or_weight number
Imgui.table_setup_column = function(label, flags, init_width_or_weight) end

---@source imgui_docking.h
---@param columns integer
---@param rows integer
---@return nil
Imgui.table_setup_scroll_freeze = function(columns, rows) end

---@source imgui_docking.h
---@return nil
Imgui.text = function(text) end

---@source imgui_docking.h
---@param text string
---@param red number
---@param green number
---@param blue number
---@param alpha number
---@return nil
Imgui.text_colored = function(text, red, green, blue, alpha) end

---@source imgui_docking.h
---@param label string
---@param default_open? boolean|unknown
---@param nav_left_jumps_back_here? boolean obsolete in 1.92 @see imgui_docking.h:1378
---@param no_tree_push_on_open? boolean Don't do a [tree_push](lua://Imgui.tree_push) when open (e.g. for CollapsingHeader) = no extra indent nor pushing on ID stack
---@return boolean success
Imgui.tree_node = function(label, default_open, nav_left_jumps_back_here, no_tree_push_on_open) end

---@source imgui_docking.h
---@return nil
Imgui.tree_pop = function() end

---@source imgui_docking.h
---@param id string
---@return nil
Imgui.tree_push = function(id) end

---@source imgui_docking.h
---@param width number
---@return nil
Imgui.unindent = function(width) end
