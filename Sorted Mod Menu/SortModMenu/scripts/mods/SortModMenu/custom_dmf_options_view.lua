local dmf = get_mod("DMF")
local mod = get_mod("SortModMenu")

local MAX_HIDDEN_MODS = 10
local MOD_NAME = "SortModMenu"

local DMFOptionsView = dmf:io_dofile("dmf/scripts/mods/dmf/modules/ui/options/dmf_options_view")
local OptionsDisplayUtils = dmf:io_dofile("dmf/scripts/mods/dmf/modules/ui/options/options_display_utils")

-- ####################################################################################################################
-- ##### Local functions ##############################################################################################
-- ####################################################################################################################

-- Set of processed names of all mods the user picked to hide.
local function get_hidden_names()
	local hidden = {}

	for i = 0, MAX_HIDDEN_MODS - 1 do
		local hidden_mod_name = mod:get("hidden_" .. i)

		if hidden_mod_name and hidden_mod_name ~= "None" and hidden_mod_name ~= "" then
			hidden[mod.process_mod_name(hidden_mod_name)] = true
		end
	end

	return hidden
end

-- Returns copies of config.categories/config.settings without hidden mods,
-- sorted alphabetically per the "sort_order" setting.
local function prepare_config(config)
	local hidden_names = get_hidden_names()
	local toggle_categories = {}
	local sortable_categories = {}

	for i = 1, #config.categories do
		local category = config.categories[i]

		if category.is_toggle_mods_category then
			toggle_categories[#toggle_categories + 1] = category
		elseif category.mod_name ~= MOD_NAME
			and hidden_names[mod.process_mod_name(category.display_name)] then
			-- skip hidden mod
		else
			sortable_categories[#sortable_categories + 1] = category
		end
	end

	if mod:get("sort_order") == "Descending" then
		table.sort(sortable_categories, function(a, b)
			return mod.process_mod_name(a.display_name) > mod.process_mod_name(b.display_name)
		end)
	else
		table.sort(sortable_categories, function(a, b)
			return mod.process_mod_name(a.display_name) < mod.process_mod_name(b.display_name)
		end)
	end

	local kept_categories = {}

	for i = 1, #toggle_categories do
		kept_categories[#kept_categories + 1] = toggle_categories[i]
	end

	for i = 1, #sortable_categories do
		kept_categories[#kept_categories + 1] = sortable_categories[i]
	end

	local visible_names = {}

	for i = 1, #kept_categories do
		visible_names[kept_categories[i].display_name] = true
	end

	local kept_settings = {}

	for i = 1, #(config.settings or {}) do
		local setting = config.settings[i]

		if visible_names[setting.category] then
			kept_settings[#kept_settings + 1] = setting
		end
	end

	return kept_categories, kept_settings
end

-- Rewrites the left-column button texts with cleaned-up mod names; entry data is left
-- untouched so DMF's internal lookups keep working.
local function clean_category_widget_texts(view)
	local category_data = view._category_data or {}

	for i = 1, #category_data do
		local data = category_data[i]
		local entry = data.entry

		if entry.mod_name then
			local cleaned_name = mod.strip_color_codes_and_glyphs(entry.display_name)

			data.widget.content.text = entry.is_favorited
				and OptionsDisplayUtils.pinned_category_name(cleaned_name)
				or cleaned_name
		end
	end
end

-- ####################################################################################################################
-- ##### Patch ########################################################################################################
-- ####################################################################################################################

DMFOptionsView._sortmodmenu_original_setup_category_config = DMFOptionsView._sortmodmenu_original_setup_category_config
	or DMFOptionsView._setup_category_config

DMFOptionsView._setup_category_config = function (self, config)
	local original_categories = config.categories
	local original_settings = config.settings

	config.categories, config.settings = prepare_config(config)

	DMFOptionsView._sortmodmenu_original_setup_category_config(self, config)

	config.categories = original_categories
	config.settings = original_settings

	if mod:get("modname_cleaned") then
		clean_category_widget_texts(self)
	end
end

return DMFOptionsView
