local loc = {
	mod_name = {
		en = "Inventory2D"
	},
	mod_description = {
		en = "It makes your inventory two-dimensional."
	},
	group_main_toggles = {
		en = "View Toggles"
	},
	group_grid_layout = {
		en = "Grid Layout"
	},
	group_item_details = {
		en = "Item Details"
	},
	group_text = {
		en = "Text"
	},
	enable_for_primary_weapons = {
		en = "Primary (Melee) Weapon"
	},
	enable_for_primary_weapons_description = {
		en = "Enables the 2D inventory grid when viewing primary (melee) weapons."
	},
	enable_for_secondary_weapons = {
		en = "Secondary (Ranged) Weapon"
	},
	enable_for_secondary_weapons_description = {
		en = "Enables the 2D inventory grid when viewing secondary (ranged) weapons."
	},
	enable_for_curios = {
		en = "Curios"
	},
	enable_for_curios_description = {
		en = "Enables the 2D inventory grid when viewing curios weapons."
	},
	show_rarity_tag = {
		en = "Show Rarity Tag"
	},
	show_rarity_tag_description = {
		en = "Reveals the rarity-coloured vertical bar seen in unmodded on the far left of each item."
	},
	darken_item_icons = {
		en = "Darken Item Icons (%%)"
	},
	darken_item_icons_description = {
		en = "Darkens the item icon/preview. This option is available primarily to provide more contrast between the icon and the text, if needed."
	},
	show_curio_blessing_text = {
		en = "Show Curio Blessing Text"
	},
	show_curio_blessing_text_description = {
		en = "Displays text describing a Curio's blessing in the space where you would see weapon blessing icons were it a weapon. This setting does nothing if \"Curio Detail Mode\" is enabled."
	},
	curio_detail_mode = {
		en = "Curio Detail Mode"
	},
	curio_detail_mode_description = {
		en = "Removes curio name and rating from inventory grid items and replaces it with text describing the curio's properties."
	},
	show_item_base_level = {
		en = "Show Item Base Level"
	},
	show_item_base_level_description = {
		en = "Shows the item's base level next to the total level."
	},
	show_equipped_glow = {
		en = "Show Equipped Glow"
	},
	show_equipped_glow_description = {
		en = "Enables display of a white glow around your equipped item as it appears in the inventory listing. This was added because it became clear that it was much harder to recognise the normal equipped icon when using the 2D grid layout."
	},
	items_per_row = {
		en = "Items Per Row"
	},
	items_per_row_description = {
		en = "Number of inventory items to show in each horizontal row. To set it to 1, toggle the mod. :]"
	},
	grid_spacing = {
		en = "Grid Spacing"
	},
	grid_spacing_description = {
		en = "Amount of space to keep between inventory items."
	},
	show_traits = {
		en = "Show Traits",
	},
	show_traits_description = {
		en = "Toggles display of trait icons in the lower-left corner of items."
	},
	item_name_font_size = {
		en = "Item Name Font Size"
	},
	item_name_font_size_description = {
		en = "Sets the font size for the display name of items typically shown in the upper-left corner of each item."
	},
	item_level_font_size = {
		en = "Item Level Font Size"
	},
	item_level_font_size_description = {
		en = "Sets the font size of the total item level number typically shown in the lower-right corner of each item."
	},
	item_base_level_font_size = {
		en = "Item Base Level Font Size",
	},
	item_base_level_font_size_description = {
		en = "Font size for the item base level number that can be activated with the \"Show Item Base Level\" setting."
	},
	curio_blessing_font_size = {
		en = "Curio Blessing Font Size"
	},
	curio_blessing_font_size_description = {
		en = "Sets the font size of the curio blessing text shown in the lower-left corner of the item."
	},
	curio_detail_mode_perks_font_size = {
		en = "Curio Detail Mode: Perk Font Size"
	},
	curio_detail_mode_perks_font_size_description = {
		en = "Sets the font size of perk text in \"Curio Detail Mode\"."
	},
	curio_detail_mode_blessing_font_size = {
		en = "Curio Detail Mode: Blessing Font Size"
	},
	curio_detail_mode_blessing_font_size_description = {
		en = "Sets the font size of the blessing text in \"Curio Detail Mode\"."
	}
}

local abbreviations = Mods.file.dofile("Inventory2D/abbreviations")

for k, v in pairs(abbreviations) do
	loc[k] = v
end

return loc
