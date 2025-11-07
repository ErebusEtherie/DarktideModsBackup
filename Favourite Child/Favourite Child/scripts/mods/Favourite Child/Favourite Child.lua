--[[
Title: Favourite Child
Author: Wobin
Date: 27/09/2025
Repository: https://github.com/Wobin/FavouriteChild
Version: 1.2.0
--]]


local mod = get_mod("Favourite Child")
local currentFaves = mod:get("favourite_child_info") or {}

local star_icon = "content/ui/materials/icons/presets/preset_15"
local firstTime = false
local table = table

mod.version = "1.2.0"

local favourite_button_def = {  
		alignment = "right_alignment",
		display_name = "loc_inventory_add_favorite",
		input_action = "hotkey_item_favorite",
		on_pressed_callback = "_on_favourite_selected_character_pressed",
		visibility_function = function (parent, id)   
         if not parent or not parent._selected_profile then return false end
         local _, entry = table.find_by_key(parent._input_legend_element._entries, "input_action", "hotkey_item_favorite")
         parent._input_legend_element:set_display_name( entry.id, currentFaves[parent._selected_profile.character_id] and "loc_inventory_remove_favorite" or "loc_inventory_add_favorite")
        return not parent._is_main_menu_open and parent._character_details_active           
		end,	
  }

local	extra_icon_pass = {
		pass_type = "texture",
		style_id = "myfavchild_icon",
		value = star_icon,
		value_id = "myfavchild_icon",
		style = {
			horizontal_alignment = "left",
			vertical_alignment = "top",
			offset = {
				0,
				0,
				1,
			},
			size = {20,	20,},
			default_color = Color.terminal_frame(nil, true),
			hover_color = Color.terminal_frame_hover(nil, true),
			selected_color = Color.terminal_frame_selected(nil, true),
		},		
    visibility_function = function(parent)
      return currentFaves[parent.profile.character_id]
    end,
	}

mod:hook_require("scripts/ui/views/main_menu_view/main_menu_view_definitions", function(defs)
    local _, input = table.find_by_key(defs.legend_inputs, "display_name", "loc_main_menu_delete_button")
    local _, alreadyExists = table.find_by_key(defs.legend_inputs, "input_action", "hotkey_item_favorite")
    input.visibility_function = function(parent)        
        return not parent._is_main_menu_open and parent._character_details_active and not currentFaves[parent._selected_profile.character_id]
      end                   
    if not alreadyExists then
      table.insert(defs.legend_inputs, favourite_button_def)
    end
end)

mod:hook_require("scripts/ui/pass_templates/character_select_pass_templates", function(defs)
    local _, alreadyExists = table.find_by_key(defs.character_select, "value_id", "myfavchild_icon")    
    if not alreadyExists then
      table.insert(defs.character_select, extra_icon_pass)
    end
end)

local package_name = "packages/ui/views/inventory_background_view/inventory_background_view"

mod.on_all_mods_loaded = function()
  mod:info(mod.version)
  Managers.package:load(package_name, "Favourite Child")
  if type(CLASS.MainMenuView) ~= "table" then 
    Promise.delay(10):next(function() 
            mod.on_all_mods_loaded()
            return
        end)    
  else
    CLASS.MainMenuView._on_favourite_selected_character_pressed = function(self)
      if not self or not self._selected_profile or not self._selected_profile.character_id then return end
      currentFaves[self._selected_profile.character_id] = not currentFaves[self._selected_profile.character_id]    
      mod:set("favourite_child_info", currentFaves, false)
    end  
  end
end