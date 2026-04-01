--[[
	File: ExpeditionsMissionGrid_data.lua
	Description: DMF settings for ExpeditionsMissionGrid
	Overall Release Version: 1.1.0
	File Version: 1.0.0
	Last Updated: 2026-03-17
	Author: LAUREHTE
]]

local mod = get_mod("ExpeditionsMissionGrid")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	allow_rehooking = true,
	options = {
		widgets = {
			{
				setting_id = "group_grid_layout",
				type = "group",
				title = "group_grid_layout",
				tooltip = "group_grid_layout_description",
				sub_widgets = {
					{
						setting_id = "start_x",
						type = "numeric",
						default_value = 15,
						range = { 0, 60 },
						decimals_number = 0,
					},
					{
						setting_id = "start_y",
						type = "numeric",
						default_value = 30,
						range = { 0, 60 },
						decimals_number = 0,
					},
					{
						setting_id = "spacing_x",
						type = "numeric",
						default_value = 15,
						range = { 6, 25 },
						decimals_number = 0,
					},
					{
						setting_id = "spacing_y",
						type = "numeric",
						default_value = 20,
						range = { 6, 25 },
						decimals_number = 0,
					},
					{
						setting_id = "max_columns",
						type = "numeric",
						default_value = 4,
						range = { 1, 8 },
						decimals_number = 0,
					},
				},
			},
			{
				setting_id = "group_grid_appearance",
				type = "group",
				title = "group_grid_appearance",
				tooltip = "group_grid_appearance_description",
				sub_widgets = {
					{
						setting_id = "card_scale",
						type = "numeric",
						default_value = 100,
						range = { 60, 150 },
						decimals_number = 0,
					},
				},
			},
		},
	},
}
