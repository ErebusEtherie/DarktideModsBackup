

---@param Module DLH_ModMenu
---@param mod DL_Mod
---@param base_path string directory of the mod_menu module (for the view path)
return function(Module, mod, base_path)
	if Module.manager then
		return Module.manager
	end

	local VIEW_NAME = mod:get_name() .. "_dl_mod_menu"
	local VIEW_PATH = base_path .. "/view/mod_menu_view"

	---@type DLH_ModMenuPage[]
	local _pages = {}
	local _active_page_id = nil

	---@type DLH_ModMenuAsideItem[]
	local _aside_items = {}

	local Manager = {}

	---@param page DLH_ModMenuPage
	function Manager.add_page(page)
		for i = 1, #_pages do
			if _pages[i].id == page.id then
				_pages[i] = page
				return
			end
		end
		_pages[#_pages + 1] = page

		if not _active_page_id and not page.secret then
			_active_page_id = page.id
		end
	end

	---@return DLH_ModMenuPage[]
	function Manager.pages()
		return _pages
	end

	---@return DLH_ModMenuPage[]
	function Manager.nav_pages()
		local out = {}
		for i = 1, #_pages do
			if not _pages[i].secret then
				out[#out + 1] = _pages[i]
			end
		end
		return out
	end

	---@return DLH_ModMenuPage | nil
	function Manager.first_secret_page()
		for i = 1, #_pages do
			if _pages[i].secret then
				return _pages[i]
			end
		end
		return nil
	end

	---@return string|nil
	function Manager.active_page_id()
		return _active_page_id
	end

	---@param id string
	function Manager.set_active_page(id)
		_active_page_id = id
	end

	---@param item DLH_ModMenuAsideItem
	function Manager.add_aside_item(item)
		if item.id then
			for i = 1, #_aside_items do
				if _aside_items[i].id == item.id then
					_aside_items[i] = item
					return
				end
			end
		end
		_aside_items[#_aside_items + 1] = item
	end

	---@return DLH_ModMenuAsideItem[]
	function Manager.aside_items()
		return _aside_items
	end

	---@return string
	function Manager.active_page_label()
		for i = 1, #_pages do
			if _pages[i].id == _active_page_id then
				return _pages[i].label
			end
		end
		return ""
	end

	---@return boolean
	function Manager.is_open()
		local ui = Managers and Managers.ui
		return ui ~= nil and ui:view_active(VIEW_NAME) and not ui:is_view_closing(VIEW_NAME)
	end

	local _material_vs_package = {
		["content/ui/materials/frames/end_of_round/reward_default_middle"] = "packages/ui/views/end_player_view/end_player_view",
		["content/ui/materials/frames/mastery_tree/wintrack_frame_corner_right"] = "packages/ui/view_elements/view_element_wintrack/view_element_wintrack | packages/ui/views/mastery_view/mastery_view | packages/ui/views/penance_overview_view/penance_overview_view",
		["content/ui/materials/backgrounds/mastery_tree/bg"] = "packages/ui/views/mastery_view/mastery_view",
		["content/ui/materials/frames/screen/mission_board_01_lower"] = "packages/ui/views/mission_board_view/mission_board_view",
		["content/ui/materials/backgrounds/mutators/mutator_vent"] = "packages/ui/views/expedition_view/expedition_view | packages/ui/views/havoc_play_view/havoc_play_view",
		["content/ui/materials/frames/screen/lobby_01_lower"] = "packages/ui/views/lobby_view/lobby_view",
		["content/ui/materials/scrollbars/scrollbar_metal_handle"] = "packages/ui/views/contracts_view/contracts_view | packages/ui/views/social_menu_roster_view/social_menu_roster_view | hash:e3c58550b56b2afd",
		["content/ui/materials/effects/crafting_recipe_background"] = "packages/ui/view_elements/view_element_crafting_recipe/view_element_crafting_recipe | packages/ui/views/crafting_mechanicus_barter_items_view/crafting_mechanicus_barter_items_view | packages/ui/views/crafting_mechanicus_modify_view/crafting_mechanicus_modify_view | packages/ui/views/crafting_mechanicus_replace_perk_view/crafting_mechanicus_replace_perk_view | packages/ui/views/crafting_mechanicus_replace_trait_view/crafting_mechanicus_replace_trait_view | packages/ui/views/crafting_mechanicus_upgrade_expertise_view/crafting_mechanicus_upgrade_expertise_view | packages/ui/views/crafting_mechanicus_upgrade_item_view/crafting_mechanicus_upgrade_item_view | packages/ui/views/crafting_view/crafting_view",
		["content/ui/materials/hud/backgrounds/interaction_background"] = "packages/ui/hud/interaction/interaction",
		["content/ui/materials/frames/item_purchase_upper"] = "packages/ui/views/broker_stimm_builder_view/broker_stimm_builder_view | packages/ui/views/credits_goods_vendor_view/credits_goods_vendor_view | packages/ui/views/talent_builder_view/talent_builder_view",
		["content/ui/materials/frames/screen/metal_01_upper"] = "packages/ui/views/cosmetics_inspect_view/cosmetics_inspect_view | packages/ui/views/inventory_cosmetics_view/inventory_cosmetics_view | packages/ui/views/inventory_weapon_cosmetics_view/inventory_weapon_cosmetics_view | packages/ui/views/inventory_weapon_details_view/inventory_weapon_details_view | packages/ui/views/inventory_weapon_marks_view/inventory_weapon_marks_view | packages/ui/views/inventory_weapons_view/inventory_weapons_view | packages/ui/views/main_menu_view/main_menu_view",
		["content/ui/materials/backgrounds/voice_matrix_fluff"] = "packages/ui/views/character_appearance_view/character_appearance_view",
	}

	local _dependencies = {
		"packages/ui/views/end_player_view/end_player_view",
		"packages/ui/views/mastery_view/mastery_view",
		"packages/ui/views/mission_board_view/mission_board_view",
		"packages/ui/views/havoc_play_view/havoc_play_view",
		"packages/ui/views/lobby_view/lobby_view",
		"packages/ui/views/social_menu_roster_view/social_menu_roster_view",
		"packages/ui/view_elements/view_element_crafting_recipe/view_element_crafting_recipe",
		"packages/ui/hud/interaction/interaction",
		"packages/ui/views/broker_stimm_builder_view/broker_stimm_builder_view",
		"packages/ui/views/main_menu_view/main_menu_view",
		"packages/ui/views/character_appearance_view/character_appearance_view",
	}

	local _pending_open = false

	local _force_fancy = false

	---@return boolean
	function Manager.force_fancy()
		return _force_fancy
	end

	function Manager.clear_force_fancy()
		_force_fancy = false
	end

	---@param opts { force_fancy: boolean }|nil
	function Manager.open(opts)
		local ui = Managers and Managers.ui
		if not ui or Manager.is_open() then
			return
		end

		_force_fancy = opts ~= nil and opts.force_fancy == true

		for index, dependency in ipairs(_dependencies) do
			if not Managers.package:is_loading(dependency) and not Managers.package:has_loaded(dependency) then
				Managers.package:load(dependency, "dopamine", nil, true)
			end
		end

		_pending_open = true
	end

	function Manager.close()
		local ui = Managers and Managers.ui
		if ui and ui:view_active(VIEW_NAME) and not ui:is_view_closing(VIEW_NAME) then

			ui:close_view(VIEW_NAME, false)
		end
	end

	function Manager.toggle()
		if Manager.is_open() then
			Manager.close()
		else
			Manager.open()
		end
	end

	function Manager.tick()
		local _ready = true
		for index, dependency in ipairs(_dependencies) do
			if not Managers.package:has_loaded(dependency) then
				_ready = false
			end
		end

		if _pending_open and _ready then
			local ui = Managers and Managers.ui

			if ui then
				ui:open_view(
					VIEW_NAME,
					nil,
					nil,
					nil,
					nil,
					{ mod_name = mod:get_name() },
					{ use_transition_ui = false }
				)
				_pending_open = false
			end
		end
	end

	mod:add_require_path(VIEW_PATH)
	mod:register_view({
		view_name = VIEW_NAME,
		view_settings = {
			init_view_function = function()
				return true
			end,
			class = "DLModMenuView",
			disable_game_world = false,
			display_name = "mod_menu_title",
			game_world_blur = 0,
			load_always = true,
			load_in_hub = true,
			package = "packages/ui/views/options_view/options_view",
			path = VIEW_PATH,
			state_bound = false,
			enter_sound_events = { "wwise/events/ui/play_ui_enter_short" },
			exit_sound_events = { "wwise/events/ui/play_ui_back_short" },
			wwise_states = { options = "ingame_menu" },
		},
		view_transitions = {},
		view_options = {
			close_all = false,
			close_previous = false,
			close_transition_time = nil,
			transition_time = nil,
		},
	})
	mod:io_dofile(VIEW_PATH)

	Module.manager = Manager

	return Manager
end
