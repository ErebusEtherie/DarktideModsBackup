local mod = get_mod("character_cosmetics_view_improved")

local UISettings = require("scripts/settings/ui/ui_settings")

local menu_zoom_out = "loc_inventory_menu_zoom_out"
local menu_zoom_in = "loc_inventory_menu_zoom_in"

local legend_inputs = {
	{
		alignment = "left_alignment",
		display_name = "loc_settings_menu_close_menu",
		input_action = "back",
		on_pressed_callback = "cb_on_close_pressed",
	},
	{
		alignment = "right_alignment",
		display_name = "loc_inventory_menu_zoom_in",
		input_action = "hotkey_menu_special_2",
		on_pressed_callback = "cb_on_camera_zoom_toggled",
		visibility_function = function (parent, id)
			local display_name = parent._camera_zoomed_in and menu_zoom_out or menu_zoom_in

			parent._input_legend_element:set_display_name(id, display_name)

			return parent._initialize_zoom
		end,
	},
	{
		alignment = "right_alignment",
		display_name = "loc_weapon_inventory_inspect_button",
		input_action = "hotkey_item_inspect",
		on_pressed_callback = "cb_on_inspect_pressed",
		visibility_function = function (parent)
			local previewed_item = parent._previewed_item

			if previewed_item then
				local item_type = previewed_item.item_type
				local ITEM_TYPES = UISettings.ITEM_TYPES

				if item_type == ITEM_TYPES.WEAPON_MELEE or item_type == ITEM_TYPES.WEAPON_RANGED or item_type == ITEM_TYPES.WEAPON_SKIN or item_type == ITEM_TYPES.END_OF_ROUND or item_type == ITEM_TYPES.GEAR_EXTRA_COSMETIC or item_type == ITEM_TYPES.GEAR_HEAD or item_type == ITEM_TYPES.GEAR_LOWERBODY or item_type == ITEM_TYPES.GEAR_UPPERBODY or item_type == ITEM_TYPES.EMOTE or item_type == ITEM_TYPES.SET then
					return true
				end
			end

			return false
		end,
	},
    {
		alignment = "right_alignment",
		display_name = "loc_VPCC_show_all_commodores",
		input_action = "hotkey_menu_special_1",
		on_pressed_callback = "cb_on_commodores_toggle_pressed",
		visibility_function = function (parent, id)
            parent._input_legend_element:set_display_name(id, parent._commodores_toggle)

			local previewed_item = parent._previewed_item

			if previewed_item then
				local item_type = previewed_item.item_type
				local ITEM_TYPES = UISettings.ITEM_TYPES

				if item_type == ITEM_TYPES.WEAPON_MELEE or item_type == ITEM_TYPES.WEAPON_RANGED or item_type == ITEM_TYPES.WEAPON_SKIN or item_type == ITEM_TYPES.END_OF_ROUND or item_type == ITEM_TYPES.GEAR_EXTRA_COSMETIC or item_type == ITEM_TYPES.GEAR_HEAD or item_type == ITEM_TYPES.GEAR_LOWERBODY or item_type == ITEM_TYPES.GEAR_UPPERBODY or item_type == ITEM_TYPES.EMOTE or item_type == ITEM_TYPES.SET then
					return true
				end
			end

			return false
		end,
	},
}

return {
    legend_inputs = legend_inputs
}