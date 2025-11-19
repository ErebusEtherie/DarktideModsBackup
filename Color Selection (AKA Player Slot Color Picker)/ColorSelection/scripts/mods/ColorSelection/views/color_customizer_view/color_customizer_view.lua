local mod = get_mod("ColorSelection")

local UIWidget = require("scripts/managers/ui/ui_widget")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local TextInputPassTemplates = require("scripts/ui/pass_templates/text_input_pass_templates")
local ButtonPassTemplates = require("scripts/ui/pass_templates/button_pass_templates")

local Definitions = mod:io_dofile("ColorSelection/scripts/mods/ColorSelection/views/color_customizer_view/color_customizer_view_definitions")

-- Constants (should match ColorSelection.lua)
local CONSTANTS = {
	MAX_PLAYERS_PER_PAGE = 14,
	MAX_COLOR_VALUE = 255,
	UUID_LENGTH_WITH_HYPHENS = 36,
	UUID_LENGTH_WITHOUT_HYPHENS = 32,
	PLAYER_CHECK_INTERVAL = 1.0
}

-- Get ColorUtils and CONSTANTS from main mod file
local ColorUtils = mod.ColorUtils or {}
local MOD_CONSTANTS = mod.CONSTANTS or CONSTANTS

local ColorCustomizerView = class("ColorCustomizerView", "BaseView")
-- Original account ID validation function
function ColorCustomizerView:init(settings)
    ColorCustomizerView.super.init(self, Definitions, settings)
    
    -- Initialize color values (RGB 0-255)
    self._red = CONSTANTS.MAX_COLOR_VALUE
    self._green = CONSTANTS.MAX_COLOR_VALUE
    self._blue = CONSTANTS.MAX_COLOR_VALUE
    self._account_id = ""
    self._player_name = ""
    self._sliders_initialized = false
    self._updating_from_slider = false  -- Flag to prevent feedback loops
    self._updating_hex_programmatically = false  -- Flag to prevent hex handler from interfering
    self._last_player_check_time = 0  -- Track when we last checked for player updates
    self._player_check_interval = CONSTANTS.PLAYER_CHECK_INTERVAL
    self._players_panel_open = false  -- Track if players panel is open
    self._players_list_data = {}  -- Store list of customized players
    self._current_page = 1  -- Current page in players list
    self._players_per_page = CONSTANTS.MAX_PLAYERS_PER_PAGE
    self._player_entry_widgets = {}  -- Store dynamically created player entry widgets
    self._last_account_id_focused = false  -- Track previous focus state for account ID
    self._last_hex_focused = false  -- Track previous focus state for hex input
    self._last_red_focused = false  -- Track previous focus state for red input
    self._last_green_focused = false  -- Track previous focus state for green input
    self._last_blue_focused = false  -- Track previous focus state for blue input
    self._last_invalid_account_id = nil  -- Track the last invalid account ID we showed an error for
    self._account_id_validation_pending = false  -- Track if we need to validate on blur
    self._editing_slot = nil  -- Track which slot is being edited (1-4), nil means account ID mode
end

function ColorCustomizerView:on_enter()
    ColorCustomizerView.super.on_enter(self)
    
    -- Block input from passing through to game/hotkeys
    self._pass_input = false
    self._allow_close_hotkey = false
    
    -- Reset players panel state when entering the view
    self._players_panel_open = false
    self._current_page = 1
    self._players_list_data = {}  -- Clear list data
    
    self:_setup_input_legend()
    self:_setup_widgets()
    
    -- Hide players panel after widgets are set up (force hide)
    if self._widgets_by_name then
        self:_update_players_panel_visibility(false)
    end
    
    -- Ensure all widgets are visible (no animation)
    if self._widgets then
        for i = 1, #self._widgets do
            local widget = self._widgets[i]
            if widget then
                widget.visible = true
                widget.alpha_multiplier = 1
                if widget.content then
                    widget.content.visible = true
                end
                widget.dirty = true
            end
        end
    end
    if self._render_settings then
        self._render_settings.alpha_multiplier = 1
    end
    
    self._is_open = true
end

function ColorCustomizerView:_setup_widgets()
    local widgets_by_name = self._widgets_by_name
    
    -- Initialize slot button colors
    self:_update_slot_button_colors()
    
    -- Setup account ID input
    local account_id_input = widgets_by_name.account_id_input
    if account_id_input then
        -- Trim any existing whitespace and set the input
        local trimmed_id = (self._account_id or ""):match("^%s*(.-)%s*$")
        account_id_input.content.input_text = trimmed_id or ""
        account_id_input.content.max_length = CONSTANTS.UUID_LENGTH_WITH_HYPHENS
        -- Store the trimmed version
        self._account_id = trimmed_id or ""
    end
    
    -- Setup hex input
    local hex_input = widgets_by_name.hex_input
    if hex_input then
        hex_input.content.input_text = self:_rgb_to_hex(self._red, self._green, self._blue)
        hex_input.content.max_length = 7  -- Allow 7 chars to accommodate #FFFFFF, then strip the #
    end
    
    -- Setup RGB numeric inputs
    local red_input = widgets_by_name.red_input
    if red_input then
        red_input.content.input_text = tostring(self._red)
        red_input.content.max_length = 3
        red_input.content.visible = true
        red_input.visible = true
        red_input.alpha_multiplier = 1
        red_input.dirty = true
    end
    
    local green_input = widgets_by_name.green_input
    if green_input then
        green_input.content.input_text = tostring(self._green)
        green_input.content.max_length = 3
        green_input.content.visible = true
        green_input.visible = true
        green_input.alpha_multiplier = 1
        green_input.dirty = true
    end
    
    local blue_input = widgets_by_name.blue_input
    if blue_input then
        blue_input.content.input_text = tostring(self._blue)
        blue_input.content.max_length = 3
        blue_input.content.visible = true
        blue_input.visible = true
        blue_input.alpha_multiplier = 1
        blue_input.dirty = true
    end
    
    -- Setup button callbacks
    local apply_button = widgets_by_name.apply_button
    if apply_button then
        apply_button.content.hotspot.pressed_callback = callback(self, "_on_apply_pressed")
    end
    
    local save_button = widgets_by_name.save_button
    if save_button then
        save_button.content.hotspot.pressed_callback = callback(self, "_on_save_pressed")
    end
    
    local reset_button = widgets_by_name.reset_button
    if reset_button then
        reset_button.content.hotspot.pressed_callback = callback(self, "_on_reset_pressed")
    end
    
    local reset_all_button = widgets_by_name.reset_all_button
    if reset_all_button then
        reset_all_button.content.hotspot.pressed_callback = callback(self, "_on_reset_all_pressed")
    end
    
    local list_players_button = widgets_by_name.list_players_button
    if list_players_button then
        list_players_button.content.hotspot.pressed_callback = callback(self, "_on_list_players_pressed")
    end
    
    local close_button = widgets_by_name.close_button
    if close_button then
        close_button.content.hotspot.pressed_callback = callback(self, "_on_close_pressed")
    end
    
    -- Setup slot buttons
    local slot1_button = widgets_by_name.slot1_button
    if slot1_button and slot1_button.content and slot1_button.content.hotspot then
        slot1_button.content.hotspot.pressed_callback = callback(self, "_on_slot_button_pressed", 1)
    end
    
    local slot2_button = widgets_by_name.slot2_button
    if slot2_button and slot2_button.content and slot2_button.content.hotspot then
        slot2_button.content.hotspot.pressed_callback = callback(self, "_on_slot_button_pressed", 2)
    end
    
    local slot3_button = widgets_by_name.slot3_button
    if slot3_button and slot3_button.content and slot3_button.content.hotspot then
        slot3_button.content.hotspot.pressed_callback = callback(self, "_on_slot_button_pressed", 3)
    end
    
    local slot4_button = widgets_by_name.slot4_button
    if slot4_button and slot4_button.content and slot4_button.content.hotspot then
        slot4_button.content.hotspot.pressed_callback = callback(self, "_on_slot_button_pressed", 4)
    end
    
    local bot_button = widgets_by_name.bot_button
    if bot_button and bot_button.content and bot_button.content.hotspot then
        bot_button.content.hotspot.pressed_callback = callback(self, "_on_slot_button_pressed", "bot")
    end
    
    -- Setup players panel buttons
    local close_panel_button = widgets_by_name.close_panel_button
    if close_panel_button then
        close_panel_button.content.hotspot.pressed_callback = callback(self, "_on_close_panel_pressed")
    end
    
    local prev_page_button = widgets_by_name.prev_page_button
    if prev_page_button then
        prev_page_button.content.hotspot.pressed_callback = callback(self, "_on_prev_page_pressed")
    end
    
    local next_page_button = widgets_by_name.next_page_button
    if next_page_button then
        next_page_button.content.hotspot.pressed_callback = callback(self, "_on_next_page_pressed")
    end
    
    -- Panel widgets start hidden by default in definitions, but ensure they're hidden here too
    -- This will be called again in on_enter after full setup
    
    -- Setup RGB sliders (only on initial setup)
    local red_slider = widgets_by_name.red_slider
    if red_slider then
        red_slider.visible = true
        red_slider.alpha_multiplier = 1
        red_slider.dirty = true
        if red_slider.content then
            red_slider.content.visible = true
        end
    end
    
    local green_slider = widgets_by_name.green_slider
    if green_slider then
        green_slider.visible = true
        green_slider.alpha_multiplier = 1
        green_slider.dirty = true
        if green_slider.content then
            green_slider.content.visible = true
        end
    end
    
    local blue_slider = widgets_by_name.blue_slider
    if blue_slider then
        blue_slider.visible = true
        blue_slider.alpha_multiplier = 1
        blue_slider.dirty = true
        if blue_slider.content then
            blue_slider.content.visible = true
        end
    end
    
    self._sliders_initialized = true
    self:_update_slider_values(true) -- Force initial update
    self:_update_color_preview()
    
end

function ColorCustomizerView:_setup_input_legend()
    local input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 10)
    local legend_inputs = self._definitions.legend_inputs
    
    for i = 1, #legend_inputs do
        local legend_input = legend_inputs[i]
        local on_pressed_callback = legend_input.on_pressed_callback
            and callback(self, legend_input.on_pressed_callback)
        
        input_legend_element:add_entry(
            legend_input.display_name,
            legend_input.input_action,
            legend_input.visibility_function,
            on_pressed_callback,
            legend_input.alignment
        )
    end
    
    self._input_legend_element = input_legend_element
end

function ColorCustomizerView:update(dt, t, input_service)
    ColorCustomizerView.super.update(self, dt, t, input_service)
    
    -- Store input_service for use in other functions
    self._input_service = input_service
    
    -- Clear the hex programmatic update flag at the start of each frame
    self._updating_hex_programmatically = false
    
    self:_handle_input()
    self:_update_widgets()
    
    -- Periodically check if player info needs to be reloaded (handles cases where players join/leave)
    -- Only check if we don't have a player name yet (player might join later)
    if t - self._last_player_check_time > self._player_check_interval then
        self._last_player_check_time = t
        if self._account_id and self._account_id ~= "" then
            -- If we have an account ID but no player name, try to reload
            -- This helps when a player joins after entering their ID
            if not self._player_name or self._player_name == "" then
                self:_load_player_info()
            end
        end
    end
    
    -- Clear the hex input update flag after all input handling is done
    self._updating_from_hex = false
    
    -- Return false for pass_input to block hotkeys and game input
    return false, false
end

-- Get current focus states for input fields
function ColorCustomizerView:_get_input_focus_states()
    local widgets_by_name = self._widgets_by_name
    local account_id_input = widgets_by_name.account_id_input
    local hex_input = widgets_by_name.hex_input
    local red_input = widgets_by_name.red_input
    local green_input = widgets_by_name.green_input
    local blue_input = widgets_by_name.blue_input
    
    local account_id_focused = account_id_input and account_id_input.content.hotspot and 
        (account_id_input.content.hotspot.is_focused or account_id_input.content.hotspot.is_selected or account_id_input.content.is_writing)
    
    local hex_focused = hex_input and hex_input.content.hotspot and 
        (hex_input.content.hotspot.is_focused or hex_input.content.hotspot.is_selected or hex_input.content.is_writing)
    
    local red_focused = red_input and red_input.content.hotspot and 
        (red_input.content.hotspot.is_focused or red_input.content.hotspot.is_selected or red_input.content.is_writing)
    
    local green_focused = green_input and green_input.content.hotspot and 
        (green_input.content.hotspot.is_focused or green_input.content.hotspot.is_selected or green_input.content.is_writing)
    
    local blue_focused = blue_input and blue_input.content.hotspot and 
        (blue_input.content.hotspot.is_focused or blue_input.content.hotspot.is_selected or blue_input.content.is_writing)
    
    return account_id_focused, hex_focused, red_focused, green_focused, blue_focused, 
           account_id_input, hex_input, red_input, green_input, blue_input
end

-- Helper to unfocus a single input field
local function unfocus_input(input_widget)
    if input_widget and input_widget.content then
        if input_widget.content.hotspot then
            input_widget.content.hotspot.is_focused = false
            input_widget.content.hotspot.is_selected = false
        end
        input_widget.content.is_writing = false
    end
end

-- Manage focus switching between input fields
function ColorCustomizerView:_handle_focus_management(account_id_focused, hex_focused, red_focused, green_focused, blue_focused,
                                                       account_id_input, hex_input, red_input, green_input, blue_input)
    -- Create list of all inputs for easy iteration
    local all_inputs = {
        {widget = account_id_input, focused = account_id_focused, last_focused = self._last_account_id_focused, name = "account_id"},
        {widget = hex_input, focused = hex_focused, last_focused = self._last_hex_focused, name = "hex"},
        {widget = red_input, focused = red_focused, last_focused = self._last_red_focused, name = "red"},
        {widget = green_input, focused = green_focused, last_focused = self._last_green_focused, name = "green"},
        {widget = blue_input, focused = blue_focused, last_focused = self._last_blue_focused, name = "blue"}
    }
    
    -- Check if any field is becoming focused
    for i, input_data in ipairs(all_inputs) do
        local widget = input_data.widget
        if widget and widget.content and widget.content.hotspot then
            local becoming_focused = widget.content.hotspot.on_pressed or 
                (input_data.focused and not (input_data.last_focused or false))
            
            if becoming_focused then
                -- This field is becoming focused, unfocus all others
                for j, other_input in ipairs(all_inputs) do
                    if i ~= j then
                        unfocus_input(other_input.widget)
                    end
                end
                
                -- Handle special validation for account ID field
                if input_data.name == "account_id" then
                    -- Account ID becoming focused, no special action needed
                else
                    -- Other field becoming focused, validate account ID if needed
                    if self._account_id_validation_pending then
                        self:_validate_account_id_on_blur()
                        self._account_id_validation_pending = false
                    end
                end
            end
            
            -- Check if this field lost focus
            if input_data.name == "account_id" and input_data.last_focused and not input_data.focused then
                if self._account_id_validation_pending then
                    self:_validate_account_id_on_blur()
                    self._account_id_validation_pending = false
                end
            end
        end
    end
    
    -- Store current focus states for next frame comparison
    self._last_account_id_focused = account_id_focused
    self._last_hex_focused = hex_focused
    self._last_red_focused = red_focused
    self._last_green_focused = green_focused
    self._last_blue_focused = blue_focused
end

-- Handle account ID input processing
function ColorCustomizerView:_handle_account_id_input(account_id_input, hex_focused)
    if not account_id_input or not account_id_input.content then
        return
    end
    
    if account_id_input.content.input_text then
        -- Trim whitespace from the account ID
        local new_account_id = account_id_input.content.input_text:match("^%s*(.-)%s*$") or ""
        
        -- Only process if hex input is not focused (to avoid conflicts)
        if not hex_focused then
            -- If user starts typing an account ID, exit slot editing mode
            if new_account_id ~= "" and self._editing_slot then
                self._editing_slot = nil
            end
            
            -- Validate account ID format
            local is_valid = new_account_id == "" or self:_is_valid_account_id(new_account_id)
            
            -- Check if account ID changed
            if new_account_id ~= self._account_id then
                local old_account_id = self._account_id
                
                -- Only update if valid (or empty)
                if is_valid then
                    self._account_id = new_account_id
                    self._last_invalid_account_id = nil
                    self._account_id_validation_pending = false
                    
                    -- Load player info if account ID changed
                    if new_account_id ~= "" or old_account_id ~= "" then
                        self:_load_player_info()
                    end
                else
                    -- Invalid format - mark for validation on blur
                    if new_account_id ~= "" then
                        self._account_id_validation_pending = true
                    end
                end
            elseif new_account_id ~= "" and new_account_id == self._account_id and is_valid then
                -- Account ID is the same and valid, but make sure player info is loaded
                if not self._player_name or self._player_name == "" then
                    self:_load_player_info()
                end
            end
        end
    elseif not account_id_input.content.input_text or account_id_input.content.input_text == "" then
        -- Handle case where input is cleared
        if self._account_id and self._account_id ~= "" then
            self._account_id = ""
            self._player_name = ""
            self._last_invalid_account_id = nil
            -- Reset to default color when account ID is cleared
            self._red = CONSTANTS.MAX_COLOR_VALUE
            self._green = CONSTANTS.MAX_COLOR_VALUE
            self._blue = CONSTANTS.MAX_COLOR_VALUE
            self:_update_slider_values(true)
            self:_update_hex_input()
            self:_update_color_preview()
        end
    end
end

-- Handle hex input processing
function ColorCustomizerView:_handle_hex_input(hex_input, hex_focused)
    if not hex_input or not hex_input.content or not hex_input.content.input_text or self._updating_hex_programmatically then
        return
    end
    
    local raw_text = hex_input.content.input_text
    local hex_text = raw_text:upper()
    -- Remove # if present and filter to only hex characters
    hex_text = hex_text:gsub("#", ""):gsub("[^0-9A-F]", "")
    
    -- Always clean the input if it contains # or non-hex characters (handles pasting)
    if raw_text:find("#") or raw_text:find("[^0-9A-Fa-f#]") then
        self._updating_hex_programmatically = true
        hex_input.content.input_text = hex_text
        self._updating_hex_programmatically = false
    end
    
    -- Update the input text to reflect filtering (only if focused and changed)
    if hex_focused then
        local current_hex = hex_input.content.input_text:upper():gsub("#", ""):gsub("[^0-9A-F]", "")
        if current_hex ~= hex_text then
            self._updating_hex_programmatically = true
            hex_input.content.input_text = hex_text
            self._updating_hex_programmatically = false
        end
    end
    
    -- Validate and update if we have 6 characters (works for typing and pasting)
    if #hex_text == 6 and hex_text:match("^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$") then
        local r, g, b = self:_hex_to_rgb(hex_text)
        -- Only update if values actually changed
        if r ~= self._red or g ~= self._green or b ~= self._blue then
            self._updating_from_hex = true
            self._red = r
            self._green = g
            self._blue = b
            self:_update_slider_values(true)
            self:_update_color_preview()
        end
    end
end

-- Handle numeric input processing
function ColorCustomizerView:_handle_numeric_input(widgets_by_name)
    if self._updating_from_slider or self._updating_from_hex then
        return
    end
    
    self._updating_from_numeric = true
    
    local red_input = widgets_by_name.red_input
    if red_input and red_input.content and red_input.content.input_text then
        local raw_value = tonumber(red_input.content.input_text)
        if raw_value then
            local clamped_value = math.clamp(math.floor(raw_value), 0, CONSTANTS.MAX_COLOR_VALUE)
            -- Update the input field to show the clamped value
            if raw_value ~= clamped_value then
                red_input.content.input_text = tostring(clamped_value)
            end
            if clamped_value ~= self._red then
                self._red = clamped_value
                self:_update_hex_input()
                self:_update_color_preview()
                self:_sync_slider_from_rgb()
            end
        end
    end
    
    local green_input = widgets_by_name.green_input
    if green_input and green_input.content and green_input.content.input_text then
        local raw_value = tonumber(green_input.content.input_text)
        if raw_value then
            local clamped_value = math.clamp(math.floor(raw_value), 0, CONSTANTS.MAX_COLOR_VALUE)
            -- Update the input field to show the clamped value
            if raw_value ~= clamped_value then
                green_input.content.input_text = tostring(clamped_value)
            end
            if clamped_value ~= self._green then
                self._green = clamped_value
                self:_update_hex_input()
                self:_update_color_preview()
                self:_sync_slider_from_rgb()
            end
        end
    end
    
    local blue_input = widgets_by_name.blue_input
    if blue_input and blue_input.content and blue_input.content.input_text then
        local raw_value = tonumber(blue_input.content.input_text)
        if raw_value then
            local clamped_value = math.clamp(math.floor(raw_value), 0, CONSTANTS.MAX_COLOR_VALUE)
            -- Update the input field to show the clamped value
            if raw_value ~= clamped_value then
                blue_input.content.input_text = tostring(clamped_value)
            end
            if clamped_value ~= self._blue then
                self._blue = clamped_value
                self:_update_hex_input()
                self:_update_color_preview()
                self:_sync_slider_from_rgb()
            end
        end
    end
    
    self._updating_from_numeric = false
end

-- Handle slider input processing
function ColorCustomizerView:_handle_slider_input(widgets_by_name)
    if self._updating_from_hex or self._updating_from_numeric then
        return
    end
    
    self._updating_from_slider = true
    
    local red_slider = widgets_by_name.red_slider
    if red_slider then
        local value = red_slider.content.value or 0
        local int_value = math.floor(value * CONSTANTS.MAX_COLOR_VALUE + 0.5)
        if int_value ~= self._red then
            self._red = int_value
            self:_update_hex_input()
            self:_update_color_preview()
            self:_sync_numeric_inputs()
        end
    end
    
    local green_slider = widgets_by_name.green_slider
    if green_slider then
        local value = green_slider.content.value or 0
        local int_value = math.floor(value * CONSTANTS.MAX_COLOR_VALUE + 0.5)
        if int_value ~= self._green then
            self._green = int_value
            self:_update_hex_input()
            self:_update_color_preview()
            self:_sync_numeric_inputs()
        end
    end
    
    local blue_slider = widgets_by_name.blue_slider
    if blue_slider then
        local value = blue_slider.content.value or 0
        local int_value = math.floor(value * CONSTANTS.MAX_COLOR_VALUE + 0.5)
        if int_value ~= self._blue then
            self._blue = int_value
            self:_update_hex_input()
            self:_update_color_preview()
            self:_sync_numeric_inputs()
        end
    end
    
    self._updating_from_slider = false
end

-- Sync numeric inputs from internal RGB values
function ColorCustomizerView:_sync_numeric_inputs()
    if self._updating_from_numeric then
        return
    end
    
    local widgets_by_name = self._widgets_by_name
    if not widgets_by_name then
        return
    end
    
    local red_input = widgets_by_name.red_input
    if red_input and red_input.content then
        red_input.content.input_text = tostring(self._red)
    end
    
    local green_input = widgets_by_name.green_input
    if green_input and green_input.content then
        green_input.content.input_text = tostring(self._green)
    end
    
    local blue_input = widgets_by_name.blue_input
    if blue_input and blue_input.content then
        blue_input.content.input_text = tostring(self._blue)
    end
end

-- Sync slider from internal RGB values
function ColorCustomizerView:_sync_slider_from_rgb()
    if self._updating_from_slider then
        return
    end
    
    local widgets_by_name = self._widgets_by_name
    if not widgets_by_name then
        return
    end
    
    local red_slider = widgets_by_name.red_slider
    if red_slider and red_slider.content then
        red_slider.content.value = self._red / CONSTANTS.MAX_COLOR_VALUE
    end
    
    local green_slider = widgets_by_name.green_slider
    if green_slider and green_slider.content then
        green_slider.content.value = self._green / CONSTANTS.MAX_COLOR_VALUE
    end
    
    local blue_slider = widgets_by_name.blue_slider
    if blue_slider and blue_slider.content then
        blue_slider.content.value = self._blue / CONSTANTS.MAX_COLOR_VALUE
    end
end

function ColorCustomizerView:_handle_input()
    local widgets_by_name = self._widgets_by_name
    
    -- Get focus states (now includes RGB inputs)
    local account_id_focused, hex_focused, red_focused, green_focused, blue_focused, 
          account_id_input, hex_input, red_input, green_input, blue_input = self:_get_input_focus_states()
    
    -- Handle focus management (now handles all inputs)
    self:_handle_focus_management(account_id_focused, hex_focused, red_focused, green_focused, blue_focused,
                                   account_id_input, hex_input, red_input, green_input, blue_input)
    
    -- Re-check focus states after potential changes
    account_id_focused, hex_focused, red_focused, green_focused, blue_focused, 
    account_id_input, hex_input, red_input, green_input, blue_input = self:_get_input_focus_states()
    
    -- Handle account ID input
    self:_handle_account_id_input(account_id_input, hex_focused)
    
    -- Handle hex input
    self:_handle_hex_input(hex_input, hex_focused)
    
    -- Handle numeric input
    self:_handle_numeric_input(widgets_by_name)
    
    -- Handle slider input
    self:_handle_slider_input(widgets_by_name)
end

function ColorCustomizerView:_update_widgets()
    local widgets_by_name = self._widgets_by_name
    
    -- Update player info display with colored text
    local player_info_text = widgets_by_name.player_info_text
    if player_info_text then
        local text_style = player_info_text.style and player_info_text.style.text
        local text_color = text_style and text_style.text_color
        
        if self._editing_slot then
            -- Show slot editing mode with slot color
            player_info_text.content.text = mod:localize("editing_slot", self._editing_slot)
            
            -- Apply current editor color to text
            if text_color then
                text_color[1] = CONSTANTS.MAX_COLOR_VALUE  -- Alpha
                text_color[2] = math.clamp(self._red, 0, CONSTANTS.MAX_COLOR_VALUE)
                text_color[3] = math.clamp(self._green, 0, CONSTANTS.MAX_COLOR_VALUE)
                text_color[4] = math.clamp(self._blue, 0, CONSTANTS.MAX_COLOR_VALUE)
            end
        elseif self._account_id and self._account_id ~= "" then
            -- Show player name (or account ID if name unavailable)
            local display_name = self._player_name and self._player_name ~= "" and self._player_name or "Player"
            player_info_text.content.text = display_name .. "\n" .. self._account_id
            
            -- Use current editor color values (which update in real-time)
            if text_color then
                text_color[1] = CONSTANTS.MAX_COLOR_VALUE  -- Alpha
                text_color[2] = math.clamp(self._red, 0, CONSTANTS.MAX_COLOR_VALUE)
                text_color[3] = math.clamp(self._green, 0, CONSTANTS.MAX_COLOR_VALUE)
                text_color[4] = math.clamp(self._blue, 0, CONSTANTS.MAX_COLOR_VALUE)
            end
        else
            -- No account ID entered yet
            player_info_text.content.text = mod:localize("player_id_label")
            
            -- Reset to default text color
            if text_color then
                text_color[1] = CONSTANTS.MAX_COLOR_VALUE
                text_color[2] = 255  -- Default white
                text_color[3] = 255
                text_color[4] = 255
            end
        end
        
        -- Mark widget as dirty to force redraw
        if player_info_text then
            player_info_text.dirty = true
        end
    end
    
    -- Update slot button colors
    self:_update_slot_button_colors()
    
    -- Update players panel if open
    if self._players_panel_open then
        self:_update_players_list()
        self:_handle_player_list_clicks()
    end
    
    -- Ensure color preview is always updated
    self:_update_color_preview()
end

function ColorCustomizerView:_update_slider_values(force_update)
    local widgets_by_name = self._widgets_by_name
    
    -- Don't update sliders if they haven't been initialized yet
    if not self._sliders_initialized then
        return
    end
    
    -- Only update sliders if force_update is true (when loading saved colors or initial setup)
    -- Otherwise, let the sliders be controlled by user input
    if not force_update then
        return
    end
    
    for i, color_name in ipairs({"red", "green", "blue"}) do
        local slider = widgets_by_name[color_name .. "_slider"]
        if slider then
            local expected_value
            if color_name == "red" then
                expected_value = self._red / CONSTANTS.MAX_COLOR_VALUE
            elseif color_name == "green" then
                expected_value = self._green / CONSTANTS.MAX_COLOR_VALUE
            elseif color_name == "blue" then
                expected_value = self._blue / CONSTANTS.MAX_COLOR_VALUE
            end
            
            -- Only update if the value is significantly different (prevents unnecessary updates)
            local current_value = slider.content.value or 0
            if math.abs(current_value - expected_value) > 0.001 then
                slider.content.value = expected_value
            end
        end
    end
    
    -- Also sync numeric inputs when sliders are updated programmatically
    self:_sync_numeric_inputs()
end

function ColorCustomizerView:_update_hex_input()
    local widgets_by_name = self._widgets_by_name
    local hex_input = widgets_by_name.hex_input
    if hex_input then
        local hex_text = self:_rgb_to_hex(self._red, self._green, self._blue)
        -- Only update if the current text doesn't match (to avoid interfering with user typing)
        local current_text = hex_input.content.input_text or ""
        current_text = current_text:gsub("#", ""):gsub("[^0-9A-F]", ""):upper()
        if current_text ~= hex_text then
            -- Set flag to prevent hex input handler from processing this update in the same frame
            self._updating_hex_programmatically = true
            hex_input.content.input_text = hex_text
            -- Flag will be cleared at the start of the next update cycle
        end
    end
end

function ColorCustomizerView:_update_color_preview()
    local widgets_by_name = self._widgets_by_name
    local color_preview = widgets_by_name.color_preview
    if not color_preview then
        return
    end
    
    -- Force widget to be visible and fully opaque
    color_preview.visible = true
    color_preview.alpha_multiplier = 1
    
    if color_preview.content then
        color_preview.content.visible = true
    end
    
    -- Set the color using widget.style.color_rect
    -- Directly modify the color array - this is the most reliable way
    if color_preview.style and color_preview.style.color_rect then
        local style_rect = color_preview.style.color_rect
        local color = style_rect.color
        if color then
            -- Always set the color every frame to prevent resets
            color[1] = CONSTANTS.MAX_COLOR_VALUE -- Alpha (fully opaque)
            color[2] = math.clamp(self._red, 0, CONSTANTS.MAX_COLOR_VALUE)
            color[3] = math.clamp(self._green, 0, CONSTANTS.MAX_COLOR_VALUE)
            color[4] = math.clamp(self._blue, 0, CONSTANTS.MAX_COLOR_VALUE)
            
            -- Ensure style is visible
            if style_rect.visible == false then
                style_rect.visible = true
            end
        end
    end
    
    -- Also ensure pass data is visible and marked dirty for the rect pass
    if color_preview.passes then
        for i = 1, #color_preview.passes do
            local pass = color_preview.passes[i]
            if pass and pass.pass_type == "rect" and pass.style_id == "color_rect" then
                if pass.data then
                    pass.data.visible = true
                    pass.data.dirty = true
                end
                break
            end
        end
    end
    
    -- Mark as dirty to force redraw every frame
    color_preview.dirty = true
end

function ColorCustomizerView:_update_slot_button_colors()
    local widgets_by_name = self._widgets_by_name
    
    -- Update all slot buttons with their current colors
    for slot = 1, 4 do
        local button_name = "slot" .. slot .. "_button"
        local button = widgets_by_name[button_name]
        
        if button and button.style and button.style.color_swatch then
            local swatch_style = button.style.color_swatch
            local swatch_color = swatch_style.color
            
            -- Get the color for this slot
            local r, g, b
            
            -- If we're currently editing this slot, use the live editor values
            if self._editing_slot == slot then
                r = math.clamp(self._red, 0, CONSTANTS.MAX_COLOR_VALUE)
                g = math.clamp(self._green, 0, CONSTANTS.MAX_COLOR_VALUE)
                b = math.clamp(self._blue, 0, CONSTANTS.MAX_COLOR_VALUE)
            else
                -- Otherwise, get the saved slot color
                local slot_prefix = "player" .. (slot == 1 and "" or tostring(slot)) .. "_color"
                r = mod:get(slot_prefix .. "_r") or CONSTANTS.MAX_COLOR_VALUE
                g = mod:get(slot_prefix .. "_g") or CONSTANTS.MAX_COLOR_VALUE
                b = mod:get(slot_prefix .. "_b") or CONSTANTS.MAX_COLOR_VALUE
            end
            
            -- Update the color swatch
            if swatch_color then
                swatch_color[1] = CONSTANTS.MAX_COLOR_VALUE  -- Alpha
                swatch_color[2] = r
                swatch_color[3] = g
                swatch_color[4] = b
            else
                swatch_style.color = Color(CONSTANTS.MAX_COLOR_VALUE, r, g, b)
            end
            
            -- Ensure the swatch is visible
            if swatch_style.visible == false then
                swatch_style.visible = true
            end
            
            -- Mark button as dirty to force redraw
            button.dirty = true
        end
    end
    
    -- Update bot button
    local bot_button = widgets_by_name.bot_button
    if bot_button and bot_button.style and bot_button.style.color_swatch then
        local swatch_style = bot_button.style.color_swatch
        local swatch_color = swatch_style.color
        
        -- Get the color for bot
        local r, g, b
        
        -- If we're currently editing bot, use the live editor values
        if self._editing_slot == "bot" then
            r = math.clamp(self._red, 0, CONSTANTS.MAX_COLOR_VALUE)
            g = math.clamp(self._green, 0, CONSTANTS.MAX_COLOR_VALUE)
            b = math.clamp(self._blue, 0, CONSTANTS.MAX_COLOR_VALUE)
        else
            -- Otherwise, get the saved bot color
            r = mod:get("bot_color_r") or 128
            g = mod:get("bot_color_g") or 128
            b = mod:get("bot_color_b") or 128
        end
        
        -- Update the color swatch
        if swatch_color then
            swatch_color[1] = CONSTANTS.MAX_COLOR_VALUE  -- Alpha
            swatch_color[2] = r
            swatch_color[3] = g
            swatch_color[4] = b
        else
            swatch_style.color = Color(CONSTANTS.MAX_COLOR_VALUE, r, g, b)
        end
        
        -- Ensure the swatch is visible
        if swatch_style.visible == false then
            swatch_style.visible = true
        end
        
        -- Mark button as dirty to force redraw
        bot_button.dirty = true
    end
end

function ColorCustomizerView:_load_player_info()
    -- Trim account ID to handle any whitespace
    if self._account_id then
        self._account_id = self._account_id:match("^%s*(.-)%s*$") or ""
    end
    
    if not self._account_id or self._account_id == "" then
        self._player_name = ""
        -- Don't reset colors when account ID is cleared
        return
    end
    
    -- Don't load player info if user is actively adjusting sliders
    if self._updating_from_slider then
        return
    end
    
    -- Try to fetch account name for any valid account ID (even if player not in game)
    if self._account_id and self._account_id ~= "" then
        local backend = Managers and Managers.backend
        if backend and backend.interfaces and backend.interfaces.account then
            -- Try to get account name (async, will update later if needed)
            backend.interfaces.account:get_account_name_by_account_id(self._account_id):next(function(name)
                if name and name ~= "" then
                    self._player_name = name
                    -- Update stored account name
                    local saved_colors = mod:get("saved_player_colors")
                    if saved_colors and type(saved_colors) == "table" and saved_colors[self._account_id] then
                        local color = saved_colors[self._account_id]
                        if color and type(color) == "table" then
                            color.account_name = name
                            saved_colors[self._account_id] = color
                            mod:set("saved_player_colors", saved_colors)
                        end
                    end
                end
            end):catch(function()
                -- Failed to fetch account name, player name will stay as fallback
            end)
        end
    end
    
    -- Try to find player by account ID using cache
    local pm = Managers and Managers.player
    local player_slot = nil
    if pm and self._account_id and self._account_id ~= "" then
        local player = nil
        -- Use cached lookup if available, otherwise fall back to iteration
        if mod.get_player_by_account_id and type(mod.get_player_by_account_id) == "function" then
            player = mod.get_player_by_account_id(self._account_id)
        else
            -- Fallback: iterate through players if cache function not available
            local human_players = pm:human_players()
            if human_players then
                for unique_id, p in pairs(human_players) do
                    -- Safety check: ensure player object is valid before accessing methods
                    if p and p.account_id then
                        local success, account_id = pcall(function() return p:account_id() end)
                        if success and account_id == self._account_id then
                            player = p
                            break
                        end
                    end
                end
            end
        end
        
        if player then
            -- Verify player object is still valid (not destroyed)
            local player_unit = player.player_unit
            if not player_unit then
                -- Player object is destroyed or invalid, skip
                player = nil
            else
                -- Use character name as immediate fallback while account name loads
                if (not self._player_name or self._player_name == "") and player.name then
                    self._player_name = player:name() or ""
                end
                -- Get slot safely
                local slot_success, slot = pcall(function() return player:slot() end)
                if slot_success and slot then
                    player_slot = slot
                end
            end
        end
        
        if player then
            
            -- Check if player has a custom color already applied
            if mod._player_custom_colors and mod._player_custom_colors[self._account_id] then
                local color = mod._player_custom_colors[self._account_id]
                if color and type(color) == "table" then
                    self._red = color[2] or CONSTANTS.MAX_COLOR_VALUE
                    self._green = color[3] or CONSTANTS.MAX_COLOR_VALUE
                    self._blue = color[4] or CONSTANTS.MAX_COLOR_VALUE
                    self:_update_slider_values(true) -- Force update when loading
                    self:_update_hex_input()
                    self:_update_color_preview()
                    return
                end
            end
        end
    end
    
    -- Try to load from saved colors (stored as table directly, no JSON needed)
    local saved_colors = mod:get("saved_player_colors")
    if saved_colors and type(saved_colors) == "table" and saved_colors[self._account_id] then
        local color = saved_colors[self._account_id]
        if color and type(color) == "table" then
            self._red = color.r or CONSTANTS.MAX_COLOR_VALUE
            self._green = color.g or CONSTANTS.MAX_COLOR_VALUE
            self._blue = color.b or CONSTANTS.MAX_COLOR_VALUE
            
            -- Use stored account name if available and we don't have one from in-game
            if (not self._player_name or self._player_name == "") then
                if color.account_name and color.account_name ~= "" then
                    self._player_name = color.account_name
                elseif color.name and color.name ~= "" then
                    self._player_name = color.name
                end
            end
            
            self:_update_slider_values(true) -- Force update when loading saved colors
            self:_update_hex_input()
            self:_update_color_preview()
            return
        end
    end
    
    -- If no custom color found, try to load slot-based color (only if player is in game)
    if player_slot and player_slot >= 1 then
        -- Get slot-based color directly from mod settings
        -- Map slot to color index: slot 1 = player_color, slot 2 = player2_color, etc.
        local slot_prefix = "player" .. (player_slot == 1 and "" or tostring(player_slot)) .. "_color"
        self._red = mod:get(slot_prefix .. "_r") or 255
        self._green = mod:get(slot_prefix .. "_g") or 255
        self._blue = mod:get(slot_prefix .. "_b") or 255
        self:_update_slider_values(true)
        self:_update_hex_input()
        self:_update_color_preview()
    elseif not player_slot then
        -- Player is not in game and no saved color exists
        -- Keep current color values (don't reset) so user can customize even if player isn't present
        -- If this is the first time loading this account ID, use default white
        if not self._red or not self._green or not self._blue then
            self._red = 255
            self._green = 255
            self._blue = 255
            self:_update_slider_values(true)
            self:_update_hex_input()
            self:_update_color_preview()
        end
    end
    
    if not self._player_name then
        self._player_name = ""
    end
end

function ColorCustomizerView:_on_apply_pressed()
    -- Handle slot color editing
    if self._editing_slot then
        local slot = self._editing_slot
        local slot_prefix
        if slot == "bot" then
            slot_prefix = "bot_color"
        else
            slot_prefix = "player" .. (slot == 1 and "" or tostring(slot)) .. "_color"
        end
        
        -- Save slot color to mod settings
        mod:set(slot_prefix .. "_r", self._red)
        mod:set(slot_prefix .. "_g", self._green)
        mod:set(slot_prefix .. "_b", self._blue)
        
        -- Force color refresh
        if mod.apply_slot_colors and type(mod.apply_slot_colors) == "function" then
            mod.apply_slot_colors()
        end
        
        -- Force immediate UI refresh of player panels
        if mod.update_player_panel_colors and type(mod.update_player_panel_colors) == "function" then
            mod.update_player_panel_colors()
        end
        
        -- Update slot button colors to reflect the saved color
        self:_update_slot_button_colors()
        
        mod:notify(mod:localize("slot_color_saved", slot == "bot" and "Bot" or slot))
        return
    end
    
    -- Validate account ID before applying
    local account_id_input = self._widgets_by_name.account_id_input
    if account_id_input and account_id_input.content.input_text then
        local trimmed_id = account_id_input.content.input_text:match("^%s*(.-)%s*$") or ""
        if trimmed_id ~= "" and not self:_is_valid_account_id(trimmed_id) then
            mod:notify(mod:localize("error_invalid_account_id"))
            return
        end
    end
    
    if not self._account_id or self._account_id == "" then
        mod:notify(mod:localize("error_no_account_id"))
        return
    end
    
    -- Validate account ID format
    if not self:_is_valid_account_id(self._account_id) then
        mod:notify(mod:localize("error_invalid_account_id"))
        return
    end
    
    -- Store color in mod's custom colors table
    if not mod._player_custom_colors then
        mod._player_custom_colors = {}
    end
    
    -- Store color in ARGB format: {alpha, red, green, blue}
    mod._player_custom_colors[self._account_id] = {CONSTANTS.MAX_COLOR_VALUE, self._red, self._green, self._blue}
    
    -- Force color refresh by calling apply_slot_colors
    -- This will update UISettings.player_slot_colors with the new custom color
    if mod.apply_slot_colors and type(mod.apply_slot_colors) == "function" then
        mod.apply_slot_colors()
    else
        -- Fallback: trigger setting change which will call apply_slot_colors
        mod.on_setting_changed("player_custom_color")
    end
    
    -- Force immediate UI refresh of player panels
    if mod.update_player_panel_colors and type(mod.update_player_panel_colors) == "function" then
        mod.update_player_panel_colors()
    end
    
    mod:notify(mod:localize("color_applied"))
end

function ColorCustomizerView:_on_save_pressed()
    -- Handle slot color editing (save works the same as apply for slots)
    if self._editing_slot then
        self:_on_apply_pressed()  -- Reuse apply logic for slots
        return
    end
    
    -- Validate account ID before saving
    local account_id_input = self._widgets_by_name.account_id_input
    if account_id_input and account_id_input.content.input_text then
        local trimmed_id = account_id_input.content.input_text:match("^%s*(.-)%s*$") or ""
        if trimmed_id ~= "" and not self:_is_valid_account_id(trimmed_id) then
            mod:notify(mod:localize("error_invalid_account_id"))
            return
        end
    end
    
    if not self._account_id or self._account_id == "" then
        mod:notify(mod:localize("error_no_account_id"))
        return
    end
    
    -- Validate account ID format
    if not self:_is_valid_account_id(self._account_id) then
        mod:notify(mod:localize("error_invalid_account_id"))
        return
    end
    
    -- Load existing saved colors (stored as table directly, no JSON needed)
    local saved_colors = mod:get("saved_player_colors")
    local colors = {}
    
    if saved_colors and type(saved_colors) == "table" then
        -- Clone the table to avoid modifying the original
        for account_id, color in pairs(saved_colors) do
            if color and type(color) == "table" then
                colors[account_id] = {
                    r = color.r or 255,
                    g = color.g or 255,
                    b = color.b or 255
                }
            end
        end
    end
    
    -- Update color for this account ID, also store account name if available
    colors[self._account_id] = {
        r = self._red,
        g = self._green,
        b = self._blue,
        account_name = self._player_name or "",  -- Store account name for later display
        name = self._player_name or ""  -- Keep for backwards compatibility
    }
    
    -- Save back to mod settings (DMF handles table serialization automatically)
    mod:set("saved_player_colors", colors)
    
    mod:notify(mod:localize("color_saved"))
end

function ColorCustomizerView:_on_reset_pressed()
    if not self._account_id or self._account_id == "" then
        mod:notify(mod:localize("error_no_account_id"))
        return
    end
    
    -- Validate account ID format
    if not self:_is_valid_account_id(self._account_id) then
        mod:notify(mod:localize("error_invalid_account_id"))
        return
    end
    
    -- Remove custom color from runtime table
    if mod._player_custom_colors and mod._player_custom_colors[self._account_id] then
        mod._player_custom_colors[self._account_id] = nil
    end
    
    -- Remove saved color from settings
    local saved_colors = mod:get("saved_player_colors")
    if saved_colors and type(saved_colors) == "table" and saved_colors[self._account_id] then
        local colors = {}
        -- Clone the table, excluding this account ID
        for account_id, color in pairs(saved_colors) do
            if account_id ~= self._account_id and color and type(color) == "table" then
                colors[account_id] = {
                    r = color.r or 255,
                    g = color.g or 255,
                    b = color.b or 255
                }
            end
        end
        mod:set("saved_player_colors", colors)
    end
    
    -- Force color refresh to use slot-based colors
    if mod.apply_slot_colors and type(mod.apply_slot_colors) == "function" then
        mod.apply_slot_colors()
    else
        mod.on_setting_changed("player_custom_color")
    end
    
    -- Force immediate UI refresh of player panels
    if mod.update_player_panel_colors and type(mod.update_player_panel_colors) == "function" then
        mod.update_player_panel_colors()
    end
    
    -- Update UI to show slot-based color (load player info to get slot color)
    -- Temporarily disable the updating_from_slider check so we can load the slot color
    local was_updating = self._updating_from_slider
    self._updating_from_slider = false
    self:_load_player_info()
    self._updating_from_slider = was_updating
    
    mod:notify(mod:localize("color_reset"))
end

function ColorCustomizerView:_on_reset_all_pressed()
    -- Reset all slot colors to base game defaults
    -- Slot 1 (You): Yellow
    mod:set("player_color_r", 226)
    mod:set("player_color_g", 210)
    mod:set("player_color_b", 117)
    
    -- Slot 2: Green
    mod:set("player2_color_r", 180)
    mod:set("player2_color_g", 88)
    mod:set("player2_color_b", 197)
    
    -- Slot 3: Purple/Magenta
    mod:set("player3_color_r", 84)
    mod:set("player3_color_g", 172)
    mod:set("player3_color_b", 80)
    
    -- Slot 4: Blue
    mod:set("player4_color_r", 126)
    mod:set("player4_color_g", 153)
    mod:set("player4_color_b", 200)
    
    -- Bot: Gray
    mod:set("bot_color_r", 128)
    mod:set("bot_color_g", 128)
    mod:set("bot_color_b", 128)
    
    -- Clear all custom colors from runtime table
    if mod._player_custom_colors then
        mod._player_custom_colors = {}
    end
    
    -- Clear all saved colors from settings
    mod:set("saved_player_colors", {})
    
    -- Force color refresh to use slot-based colors for all players
    if mod.apply_slot_colors and type(mod.apply_slot_colors) == "function" then
        mod.apply_slot_colors()
    else
        mod.on_setting_changed("player_custom_color")
    end
    
    -- Force immediate UI refresh of player panels
    if mod.update_player_panel_colors and type(mod.update_player_panel_colors) == "function" then
        mod.update_player_panel_colors()
    end
    
    -- Update slot button colors to reflect the reset
    self:_update_slot_button_colors()
    
    -- Update UI to show slot-based color for current account ID (if set)
    if self._account_id and self._account_id ~= "" then
        local was_updating = self._updating_from_slider
        self._updating_from_slider = false
        self:_load_player_info()
        self._updating_from_slider = was_updating
    end
    
    -- If editing a slot, reload the reset color into editor
    if self._editing_slot then
        local slot = self._editing_slot
        local slot_prefix
        if slot == "bot" then
            slot_prefix = "bot_color"
        else
            slot_prefix = "player" .. (slot == 1 and "" or tostring(slot)) .. "_color"
        end
        self._red = mod:get(slot_prefix .. "_r") or CONSTANTS.MAX_COLOR_VALUE
        self._green = mod:get(slot_prefix .. "_g") or CONSTANTS.MAX_COLOR_VALUE
        self._blue = mod:get(slot_prefix .. "_b") or CONSTANTS.MAX_COLOR_VALUE
        
        self:_update_slider_values(true)
        self:_update_hex_input()
        self:_update_color_preview()
    end
    
    mod:notify(mod:localize("color_reset_all"))
end

function ColorCustomizerView:_on_close_pressed()
    Managers.ui:close_view(self.view_name)
end

function ColorCustomizerView:_on_back_pressed()
    Managers.ui:close_view(self.view_name)
end

function ColorCustomizerView:_on_slot_button_pressed(slot)
    -- Load slot color into editor
    self._editing_slot = slot
    self._account_id = ""  -- Clear account ID when editing slot
    self._player_name = ""
    
    -- Get slot color from mod settings
    local slot_prefix
    if slot == "bot" then
        slot_prefix = "bot_color"
    else
        slot_prefix = "player" .. (slot == 1 and "" or tostring(slot)) .. "_color"
    end
    self._red = mod:get(slot_prefix .. "_r") or CONSTANTS.MAX_COLOR_VALUE
    self._green = mod:get(slot_prefix .. "_g") or CONSTANTS.MAX_COLOR_VALUE
    self._blue = mod:get(slot_prefix .. "_b") or CONSTANTS.MAX_COLOR_VALUE
    
    -- Update UI
    local widgets_by_name = self._widgets_by_name
    local account_id_input = widgets_by_name.account_id_input
    if account_id_input then
        account_id_input.content.input_text = ""
    end
    
    self:_update_slider_values(true)
    self:_update_hex_input()
    self:_update_color_preview()
    
    mod:notify(mod:localize("slot_color_loaded", slot == "bot" and "Bot" or slot))
end

function ColorCustomizerView:_on_list_players_pressed()
    self._players_panel_open = not self._players_panel_open
    self:_update_players_panel_visibility(self._players_panel_open)
    if self._players_panel_open then
        self:_load_players_list()
        self._current_page = 1
        self:_update_players_list()
        -- Initialize hotspots for player entries
        self:_initialize_player_entry_hotspots()
    end
end

function ColorCustomizerView:_initialize_player_entry_hotspots()
    -- Initialize hotspot content for player entries
    local widgets_by_name = self._widgets_by_name
    local players_list = widgets_by_name.players_list
    
    if not players_list or not players_list.content then
        return
    end
    
    -- Initialize all hotspots (they'll be shown/hidden and populated in _update_players_list)
    for i = 1, CONSTANTS.MAX_PLAYERS_PER_PAGE do
        local hotspot_key = "player_entry_" .. i
        if not players_list.content[hotspot_key] then
            players_list.content[hotspot_key] = {
                visible = false,
                account_id = nil
            }
        end
    end
end

function ColorCustomizerView:_on_close_panel_pressed()
    self._players_panel_open = false
    self:_update_players_panel_visibility(false)
end

function ColorCustomizerView:_on_prev_page_pressed()
    if self._current_page > 1 then
        self._current_page = self._current_page - 1
    end
end

function ColorCustomizerView:_on_next_page_pressed()
    local total_pages = math.ceil(#self._players_list_data / self._players_per_page)
    if self._current_page < total_pages then
        self._current_page = self._current_page + 1
    end
end

function ColorCustomizerView:_update_players_panel_visibility(visible)
    local widgets_by_name = self._widgets_by_name
    
    if not widgets_by_name then
        return
    end
    
    local panel_widgets = {
        "players_panel",
        "players_panel_title",
        "players_list",
        "players_pagination",
        "page_info_text",
        "prev_page_button",
        "next_page_button",
        "close_panel_button"
    }
    
    for i = 1, #panel_widgets do
        local widget = widgets_by_name[panel_widgets[i]]
        if widget then
            widget.visible = visible
            widget.alpha_multiplier = visible and 1 or 0
            if widget.content then
                widget.content.visible = visible
            end
            -- Also update style visibility if available
            if widget.style then
                for style_key, style_data in pairs(widget.style) do
                    if style_data and type(style_data) == "table" then
                        style_data.visible = visible
                    end
                end
            end
            widget.dirty = true
        end
    end
end

function ColorCustomizerView:_load_players_list()
    self._players_list_data = {}
    
    -- Load from saved colors
    local saved_colors = mod:get("saved_player_colors")
    if saved_colors and type(saved_colors) == "table" then
        for account_id, color in pairs(saved_colors) do
            if color and type(color) == "table" then
                -- Use stored account name if available
                local account_name = color.account_name or color.name or ""
                
                -- If no stored account name, try to get from backend (async, will update later)
                if account_name == "" then
                    -- Try to fetch account name from backend
                    local backend = Managers.backend
                    if backend and backend.interfaces and backend.interfaces.account then
                        backend.interfaces.account:get_account_name_by_account_id(account_id):next(function(name)
                            if name and name ~= "" then
                                -- Update stored account name
                                if saved_colors[account_id] then
                                    saved_colors[account_id].account_name = name
                                    mod:set("saved_player_colors", saved_colors)
                                    -- Refresh the list if panel is open
                                    if self._players_panel_open then
                                        self:_load_players_list()
                                        self:_update_players_list()
                                    end
                                end
                            end
                        end):catch(function()
                            -- Failed to fetch, use account ID as fallback
                        end)
                    end
                end
                
                -- Fallback to account ID if no name available
                if account_name == "" then
                    account_name = account_id:sub(1, 8) .. "..."
                end
                
                -- Ensure color data is in the correct format (normalize if needed)
                local normalized_color = ColorUtils.normalize_to_rgb(color)
                -- Preserve account_name if it exists
                if color.account_name then
                    normalized_color.account_name = color.account_name
                end
                if color.name then
                    normalized_color.name = color.name
                end
                
                table.insert(self._players_list_data, {
                    account_id = account_id,
                    player_name = account_name,  -- Now stores account name instead of character name
                    color = normalized_color
                })
            end
        end
        
        -- Save back if we updated any names
        mod:set("saved_player_colors", saved_colors)
    end
    
    -- Sort by player name (if available) or account ID
    table.sort(self._players_list_data, function(a, b)
        if a.player_name ~= "" and b.player_name ~= "" then
            return a.player_name < b.player_name
        elseif a.player_name ~= "" then
            return true
        elseif b.player_name ~= "" then
            return false
        else
            return a.account_id < b.account_id
        end
    end)
end

-- Helper function to hide a color swatch
function ColorCustomizerView:_hide_color_swatch(swatch_num, players_list)
    local swatch_key = "color_swatch_" .. swatch_num
    
    -- Hide through widget style
    if players_list.style and players_list.style[swatch_key] then
        local style_swatch = players_list.style[swatch_key]
        if style_swatch.color then
            style_swatch.color[1] = 0  -- Transparent
        else
            style_swatch.color = Color.white(0, true)
        end
        style_swatch.visible = false
    end
    
    -- Hide through pass data as well
    if players_list.passes then
        for pass_idx = 1, #players_list.passes do
            local pass = players_list.passes[pass_idx]
            if pass and (pass.value_id == swatch_key or pass.style_id == swatch_key) and pass.pass_type == "rect" then
                if pass.data then
                    pass.data.visible = false
                    pass.data.dirty = true
                end
                if pass.style then
                    pass.style.visible = false
                end
                break
            end
        end
    end
end

-- Calculate pagination info
function ColorCustomizerView:_calculate_pagination()
    local total_players = #self._players_list_data
    local total_pages = math.max(1, math.ceil(total_players / self._players_per_page))
    self._current_page = math.clamp(self._current_page, 1, total_pages)
    
    local start_index = (self._current_page - 1) * self._players_per_page + 1
    local end_index = math.min(start_index + self._players_per_page - 1, total_players)
    
    return {
        total_players = total_players,
        total_pages = total_pages,
        current_page = self._current_page,
        start_index = start_index,
        end_index = end_index
    }
end

-- Update pagination UI elements
function ColorCustomizerView:_update_pagination_ui(pagination)
    local widgets_by_name = self._widgets_by_name
    
    -- Update page info
    local page_info_text = widgets_by_name.page_info_text
    if page_info_text then
        if pagination.total_players > 0 and pagination.total_pages > 0 then
            page_info_text.content.text = mod:localize("page_info", pagination.current_page, pagination.total_pages)
        else
            page_info_text.content.text = mod:localize("no_customized_players")
        end
    end
    
    -- Update pagination buttons
    local prev_button = widgets_by_name.prev_page_button
    if prev_button then
        prev_button.content.visible = pagination.total_pages > 1
        prev_button.content.disabled = pagination.current_page <= 1
    end
    
    local next_button = widgets_by_name.next_page_button
    if next_button then
        next_button.content.visible = pagination.total_pages > 1
        next_button.content.disabled = pagination.current_page >= pagination.total_pages
    end
end

-- Update a single player entry's display
function ColorCustomizerView:_update_player_entry(entry_num, player_data, players_list)
    local name = player_data.player_name ~= "" and player_data.player_name or "Unknown"
    
    -- Truncate name if too long to prevent overflow (using byte length)
    local max_name_length = 22
    if #name > max_name_length then
        name = string.sub(name, 1, max_name_length) .. "..."
    end
    
    -- Truncate account ID to first 8 characters for display
    local short_account_id = string.sub(player_data.account_id, 1, 8) .. "..."
    
    local display_text = string.format("%d. %s (%s)\n\n", entry_num, name, short_account_id)
    
    -- Update color swatch
    local swatch_key = "color_swatch_" .. entry_num
    local rgb = ColorUtils.normalize_to_rgb(player_data.color)
    local r, g, b = rgb.r, rgb.g, rgb.b
    
    -- Update widget style
    if players_list.style and players_list.style[swatch_key] then
        local style_swatch = players_list.style[swatch_key]
        local style_color = style_swatch.color
        
        if style_color then
            style_color[1] = CONSTANTS.MAX_COLOR_VALUE  -- Alpha
            style_color[2] = r
            style_color[3] = g
            style_color[4] = b
        else
            style_swatch.color = Color(CONSTANTS.MAX_COLOR_VALUE, r, g, b)
        end
        
        if style_swatch.visible == false then
            style_swatch.visible = true
        end
    end
    
    -- Update pass data
    if players_list.passes then
        for pass_idx = 1, #players_list.passes do
            local pass = players_list.passes[pass_idx]
            if pass and (pass.value_id == swatch_key or pass.style_id == swatch_key) and pass.pass_type == "rect" then
                if pass.data then
                    pass.data.visible = true
                    pass.data.dirty = true
                end
                break
            end
        end
    end
    
    -- Update hotspot
    local hotspot_key = "player_entry_" .. entry_num
    if players_list.content and players_list.content[hotspot_key] then
        local hotspot = players_list.content[hotspot_key]
        hotspot.account_id = player_data.account_id
        hotspot.visible = true
    end
    
    return display_text
end

-- Display empty list state
function ColorCustomizerView:_display_empty_list(players_list)
    -- Hide all color swatches when no players
    for swatch_num = 1, CONSTANTS.MAX_PLAYERS_PER_PAGE do
        self:_hide_color_swatch(swatch_num, players_list)
    end
    return ""
end

-- Display players list with entries
function ColorCustomizerView:_display_players_list(players_list, pagination)
    local display_text = ""
    local entry_num = 0
    
    for i = pagination.start_index, pagination.end_index do
        local player_data = self._players_list_data[i]
        if player_data then
            entry_num = entry_num + 1
            display_text = display_text .. self:_update_player_entry(entry_num, player_data, players_list)
        end
    end
    
    -- Hide unused hotspots
    for hotspot_num = entry_num + 1, CONSTANTS.MAX_PLAYERS_PER_PAGE do
        local hotspot_key = "player_entry_" .. hotspot_num
        if players_list.content and players_list.content[hotspot_key] then
            local hotspot = players_list.content[hotspot_key]
            hotspot.visible = false
            hotspot.account_id = nil
        end
    end
    
    -- Hide unused color swatches
    for swatch_num = entry_num + 1, CONSTANTS.MAX_PLAYERS_PER_PAGE do
        self:_hide_color_swatch(swatch_num, players_list)
    end
    
    return display_text, entry_num
end

function ColorCustomizerView:_update_players_list()
    local widgets_by_name = self._widgets_by_name
    local players_list = widgets_by_name.players_list
    
    if not players_list then
        return
    end
    
    -- Calculate pagination
    local pagination = self:_calculate_pagination()
    
    -- Update pagination UI
    self:_update_pagination_ui(pagination)
    
    -- Display players list
    if players_list.content then
        local display_text = ""
        local entry_num = 0
        
        if pagination.total_players == 0 then
            display_text = self:_display_empty_list(players_list)
        else
            display_text, entry_num = self:_display_players_list(players_list, pagination)
        end
        
        players_list.content.list_text = display_text
        players_list.dirty = true
        players_list.alpha_multiplier = 1
        
        -- Final safety check: Ensure all unused swatches are properly hidden
        for swatch_num = entry_num + 1, CONSTANTS.MAX_PLAYERS_PER_PAGE do
            self:_hide_color_swatch(swatch_num, players_list)
        end
    end
end

function ColorCustomizerView:_handle_player_list_clicks()
    -- Handle clicks on player list entries
    local widgets_by_name = self._widgets_by_name
    local players_list = widgets_by_name.players_list
    
    if not players_list or not players_list.content then
        return
    end
    
    -- Check each hotspot for clicks
    for i = 1, CONSTANTS.MAX_PLAYERS_PER_PAGE do
        local hotspot_key = "player_entry_" .. i
        local hotspot = players_list.content[hotspot_key]
        
        if hotspot and hotspot.account_id then
            -- Check if hotspot was pressed (on_pressed is a flag that gets set when clicked)
            if hotspot.on_pressed then
                -- Player entry was clicked, load their account ID
                self:_on_player_entry_clicked(hotspot.account_id)
                -- Reset the pressed flag
                hotspot.on_pressed = false
                break
            end
        end
    end
end

function ColorCustomizerView:_on_player_entry_clicked(account_id)
    -- Load the clicked player's account ID into the main view
    local widgets_by_name = self._widgets_by_name
    local account_id_input = widgets_by_name.account_id_input
    
    if account_id_input and account_id then
        self._account_id = account_id
        account_id_input.content.input_text = account_id
        self:_load_player_info()
        
        -- Close the panel after selection
        self._players_panel_open = false
        self:_update_players_panel_visibility(false)
        
        -- Play sound feedback
        if Managers.ui then
            Managers.ui:play_2d_sound(UISoundEvents.default_click)
        end
    end
end

function ColorCustomizerView:_validate_account_id_on_blur()
    -- Validate account ID when field loses focus
    local account_id_input = self._widgets_by_name.account_id_input
    if account_id_input and account_id_input.content.input_text then
        local trimmed_id = account_id_input.content.input_text:match("^%s*(.-)%s*$") or ""
        if trimmed_id ~= "" and not self:_is_valid_account_id(trimmed_id) then
            -- Only show error if it's a new invalid ID (not the same one we already showed)
            if trimmed_id ~= self._last_invalid_account_id then
                mod:notify(mod:localize("error_invalid_account_id"))
                self._last_invalid_account_id = trimmed_id
            end
        else
            self._last_invalid_account_id = nil
        end
    end
end

-- Helper function to validate UUID format (with or without hyphens)
function ColorCustomizerView:_is_valid_account_id(account_id)
    if not account_id or account_id == "" then
        return false
    end
    
    -- Remove hyphens for validation
    local normalized = account_id:gsub("-", "")
    
    -- Check length (32 hex digits)
    if #normalized ~= CONSTANTS.UUID_LENGTH_WITHOUT_HYPHENS then
        return false
    end
    
    -- Check if all characters are hex digits
    return normalized:match("^[0-9a-fA-F]+$") ~= nil
end

function ColorCustomizerView:on_exit()
    self._is_open = false
    -- Reset players panel state when exiting the view
    self._players_panel_open = false
    self._current_page = 1
    ColorCustomizerView.super.on_exit(self)
end

-- Helper functions
function ColorCustomizerView:_rgb_to_hex(r, g, b)
    return string.format("%02X%02X%02X", math.clamp(r, 0, CONSTANTS.MAX_COLOR_VALUE), math.clamp(g, 0, CONSTANTS.MAX_COLOR_VALUE), math.clamp(b, 0, CONSTANTS.MAX_COLOR_VALUE))
end

function ColorCustomizerView:_hex_to_rgb(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 0
    local g = tonumber(hex:sub(3, 4), 16) or 0
    local b = tonumber(hex:sub(5, 6), 16) or 0
    return r, g, b
end

return ColorCustomizerView

