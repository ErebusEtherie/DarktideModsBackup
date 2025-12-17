local mod = get_mod("A la Mode")

local MasterItems = require("scripts/backend/master_items")
local Items = require("scripts/utilities/items")

local ui_scale = 1
local WIDTH = 450
local HEIGHT = 240
local OFFSET = 550
local PADDING = 16
local first_run = true
local window_width = math.min(WIDTH * ui_scale, RESOLUTION_LOOKUP.width - OFFSET)
local window_height = math.min(HEIGHT * ui_scale, RESOLUTION_LOOKUP.height - OFFSET)
local padded_width = window_width - PADDING

-- local refs
local Imgui = Imgui
local Imgui_text = Imgui.text
local Imgui_set_next_window_size = Imgui.set_next_window_size
local Imgui_begin_window = Imgui.begin_window
local Imgui_push_item_width = Imgui.push_item_width
local Imgui_set_next_window_pos = Imgui.set_next_window_pos
local Imgui_set_window_font_scale = Imgui.set_window_font_scale
local Imgui_begin_combo = Imgui.begin_combo
local Imgui_selectable = Imgui.selectable
local Imgui_end_combo = Imgui.end_combo
local Imgui_color_edit_3 = Imgui.color_edit_3
local Imgui_end_window = Imgui.end_window
local Managers = Managers

local ALaModeConfig = class("ALaModeConfig")
local valid_weapons = mod:io_dofile("A La Mode/scripts/mods/A La Mode/data/weapon_info")
local Localize = Localize

function ALaModeConfig:init()
	self._is_open = false
	self.selected_weapon = nil
	self.selected_weapon_key = nil
end

local input_manager = Managers.input

function ALaModeConfig:open()
	
	local name = self.__class_name
	if not input_manager:cursor_active() then
		input_manager:push_cursor(name)
    self.pushedcursor = true
	end

	self._is_open = true
	Imgui.open_imgui()    
end

function ALaModeConfig:close()	
	local name = self.__class_name
  
	if self.pushedcursor then    
		input_manager:pop_cursor(name)
    self.pushedcursor = false
	end

	self._is_open = false
	Imgui.close_imgui()
end


function ALaModeConfig:update()
	if not self._is_open then
		return
	end

	Imgui_set_next_window_size(window_width, window_height)
	if first_run then
		Imgui_set_next_window_pos((RESOLUTION_LOOKUP.width / 2) - (WIDTH / 2) - 100, (RESOLUTION_LOOKUP.height / 2) - (HEIGHT / 2) - 100)
		first_run = false
	end
	local _, closed = Imgui_begin_window("A La Mode Config", "always_auto_resize")

	if closed then
		self:close()
	end
  
    Imgui_set_window_font_scale(ui_scale)
  
  Imgui_text("-----------------------------------")
  Imgui_text("Weapon Color Settings")
  Imgui_text("-----------------------------------")
  Imgui_push_item_width(padded_width - PADDING)  
  -- Weapon dropdown
  local display_name = self.selected_weapon or "Select Weapon..."

  if Imgui_begin_combo("##Weapon", display_name) then
    -- Create sorted list of weapons
    local sorted_weapons = {}
    for weapon_key, weapon_data in pairs(valid_weapons) do
      local weapon_item = MasterItems.get_item(weapon_key)
      local weapon_display_name = Localize(weapon_data[1]) .. " (".. Items.weapon_lore_mark_name(weapon_item) .. ")"
      table.insert(sorted_weapons, {key = weapon_key, display = weapon_display_name})
    end
    table.sort(sorted_weapons, function(a, b) return a.display < b.display end)
    
    -- Display sorted weapons
    for _, weapon in ipairs(sorted_weapons) do
      if Imgui_selectable(weapon.display, self.selected_weapon == weapon.display) then
        self.selected_weapon = weapon.display
        self.selected_weapon_key = weapon.key
      end
    end
    Imgui_end_combo()
    Imgui.pop_item_width()  
  end
  
  -- Color pickers for selected weapon
  if self.selected_weapon_key then
    local weapon_data = valid_weapons[self.selected_weapon_key]
    
    -- Get current colors from settings or defaults
    local color1_argb = mod:get(self.selected_weapon_key .. "-color_1") or Color[weapon_data[2]](255, true)
    local color2_argb = mod:get(self.selected_weapon_key .. "-color_2") or Color[weapon_data[3]](255, true)
    
    
    Imgui_text("Mode A/Normal:")
    local r1, g1, b1 = Imgui_color_edit_3("##color1", color1_argb[2] / 255, color1_argb[3] / 255, color1_argb[4] / 255)
    if r1 ~= color1_argb[2] / 255 or g1 ~= color1_argb[3] / 255 or b1 ~= color1_argb[4] / 255 then
      mod:set(self.selected_weapon_key .. "-color_1", {255, math.floor(r1 * 255), math.floor(g1 * 255), math.floor(b1 * 255)}, true)
    end
    
    Imgui_text("Mode B/Active:")
    local r2, g2, b2 = Imgui_color_edit_3("##color2", color2_argb[2] / 255, color2_argb[3] / 255, color2_argb[4] / 255)
    if r2 ~= color2_argb[2] / 255 or g2 ~= color2_argb[3] / 255 or b2 ~= color2_argb[4] / 255 then
      mod:set(self.selected_weapon_key .. "-color_2", {255, math.floor(r2 * 255), math.floor(g2 * 255), math.floor(b2 * 255)}, true)
    end
  end
  
 
	Imgui_end_window()
end

return ALaModeConfig