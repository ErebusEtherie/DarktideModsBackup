local mod = get_mod("RetainSelection")

-- Your mod code goes here.
-- https://vmf-docs.verminti.de

local selected_item = nil
local function retain_selection(instance)
	if instance._discard_items_element and instance._discard_items_element:visible() then return end
	local item_grid = instance._item_grid
	local widget_index = item_grid:selected_grid_index()
	if widget_index then
		local first_index = item_grid:first_interactable_grid_index()
		if widget_index ~= first_index then
			selected_item = widget_index
		elseif widget_index == first_index and selected_item then
			if selected_item >= first_index and selected_item <= item_grid:last_interactable_grid_index() then
				instance:focus_grid_index(selected_item)
				instance:scroll_to_grid_index(selected_item, true)
			end
			selected_item = nil
		end
	end
end
mod:hook_safe("CraftingMechanicusModifyView","_cb_on_present",retain_selection)
mod:hook_safe("InventoryWeaponsView","_cb_on_present",retain_selection)