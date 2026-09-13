local mod = get_mod("HavocConditionManager")
local base_mod = get_mod("SoloPlay")

if not base_mod then
	mod:error("SoloPlay is required and must load before HavocConditionManager")

	return
end

local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local WwiseGameSyncSettings = require("scripts/settings/wwise_game_sync/wwise_game_sync_settings")
mod.has_local_gameplay_authority = function ()
    return base_mod.has_local_gameplay_authority and base_mod.has_local_gameplay_authority() or false
end
mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/reference_conditions")
local Catalog = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/condition_catalog")
if type(Catalog)~="table" then return end
local Toggle=mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/runtime_toggle")
local function authority()
    return base_mod.has_local_gameplay_authority and base_mod.has_local_gameplay_authority() or false
end
local toggle=Toggle(mod,authority)
mod.is_gameplay_enabled=toggle.active
mod.has_local_gameplay_authority=function() return toggle.active() and authority() end
mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/buff_capacity")
mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/presence_compat")
local SoloPlaySettings = base_mod:io_dofile("SoloPlay/scripts/mods/SoloPlay/SoloPlaySettings")
local HavocConditions = mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/havoc_conditions")
mod.condition_catalog = Catalog
local catalog_state
local extended_order,extended_lookup
mod.extend_condition_settings=function(settings)
    Catalog.extend(settings)
    if settings==SoloPlaySettings then
        extended_order=settings.order.havoc_circumstances
        extended_lookup=settings.lookup.havoc_circumstances
        if catalog_state then
            catalog_state.extended_order=extended_order
            catalog_state.extended_lookup=extended_lookup
            catalog_state.extended_loc=table.clone(settings.loc.havoc_circumstances)
        end
    end
    return settings
end
local function set_catalog_enabled(enabled)
    if enabled and not catalog_state then
        catalog_state={order=SoloPlaySettings.order.havoc_circumstances,lookup=SoloPlaySettings.lookup.havoc_circumstances,
            loc=table.clone(SoloPlaySettings.loc.havoc_circumstances)}
        mod.extend_condition_settings(SoloPlaySettings)
    elseif not enabled and catalog_state then
        if SoloPlaySettings.order.havoc_circumstances==catalog_state.extended_order then SoloPlaySettings.order.havoc_circumstances=catalog_state.order end
        if SoloPlaySettings.lookup.havoc_circumstances==catalog_state.extended_lookup then SoloPlaySettings.lookup.havoc_circumstances=catalog_state.lookup end
        for key,value in pairs(catalog_state.extended_loc) do
            if SoloPlaySettings.loc.havoc_circumstances[key]==value then SoloPlaySettings.loc.havoc_circumstances[key]=catalog_state.loc[key] end
        end
        catalog_state=nil
    end
end
set_catalog_enabled(true)
do
    local events=0
    for _,id in ipairs(SoloPlaySettings.order.havoc_circumstances) do if Catalog.category(id)=="event" then events=events+1 end end
    mod:info("Loaded %d conditions, including %d event conditions",#SoloPlaySettings.order.havoc_circumstances,events)
end
local VIEW_NAME = "havoc_condition_manager_view"
mod.validate_environment_selection = function()
    local mission=base_mod:get("havoc_mission")
    if base_mod.parse_mission_params and mission then mission=base_mod.parse_mission_params(mission) end
    local selected=base_mod:get("havoc_theme_circumstance") or "default"
    if not Catalog.environment_available(SoloPlaySettings,mission,selected) then
        selected="default"
        base_mod:set("havoc_theme_circumstance",selected)
    end
    return selected
end

local function default_primary_conditions()
	local first = extended_order[1]
	local second = extended_order[3] or extended_order[2]

	return HavocConditions.sanitize({
		base_mod:get("havoc_circumstance1") or first,
		base_mod:get("havoc_circumstance2") or second,
	}, extended_lookup, HavocConditions.max_primary)
end

mod.get_primary_havoc_conditions = function ()
	Catalog.migrate_difficulty(HavocConditions.decode(mod:get(HavocConditions.storage_key)), base_mod)
	local selected = HavocConditions.sanitize(
		HavocConditions.decode(mod:get(HavocConditions.storage_key)),
		extended_lookup,
		HavocConditions.max_primary
	)

	if mod:get(HavocConditions.storage_key) == nil then
		selected = default_primary_conditions()
	end

	mod:set(HavocConditions.storage_key, HavocConditions.encode(selected))

	return selected
end

mod.apply_havoc_conditions = function (mission_context)
	if not mod:is_enabled() then return mission_context end
	if type(mission_context) ~= "table" or type(mission_context.havoc_data) ~= "string" then
		return mission_context
	end

	local selected = mod.get_primary_havoc_conditions()
	local _, replaced = HavocConditions.apply_to_mission_context(mission_context, selected, {
		base_mod:get("havoc_theme_circumstance"),
		base_mod:get("havoc_difficulty_circumstance"),
	}, HavocConditions.max_total)

	if not replaced then
		mod:warning("SoloPlay returned malformed Havoc mission data; keeping its original condition list")
	end

	return mod.prepare_reference_conditions(mission_context)
end

mod:add_require_path("HavocConditionManager/scripts/mods/HavocConditionManager/condition_manager_view/condition_manager_view")
mod:register_view({
	view_name = VIEW_NAME,
	view_settings = {
		package = {
			"packages/ui/views/inventory_view/inventory_view",
		},
		init_view_function = function (ingame_ui_context)
			return true
		end,
		state_bound = true,
		path = "HavocConditionManager/scripts/mods/HavocConditionManager/condition_manager_view/condition_manager_view",
		class = "HavocConditionManagerView",
		disable_game_world = false,
		load_always = true,
		load_in_hub = true,
		game_world_blur = 1.1,
		enter_sound_events = {
			UISoundEvents.system_menu_enter,
		},
		exit_sound_events = {
			UISoundEvents.system_menu_exit,
		},
		wwise_states = {
			options = WwiseGameSyncSettings.state_groups.options.ingame_menu,
		},
		context = {
			use_item_categories = false,
		},
	},
	view_transitions = {},
	view_options = {
		close_all = false,
		close_previous = false,
		close_transition_time = nil,
		transition_time = nil,
	},
})

mod.open_condition_manager_view = function ()
	if not mod:is_enabled() then return end
	if not Managers.ui:view_instance(VIEW_NAME) then
		Managers.ui:open_view(VIEW_NAME, nil, nil, nil, nil, {})
	end
end

if not base_mod._havoc_condition_manager_context_wrapper then
	base_mod._havoc_condition_manager_context_wrapper = base_mod.gen_havoc_mission_context
	base_mod.gen_havoc_mission_context = function (...)
		if not mod:is_enabled() then return base_mod._havoc_condition_manager_context_wrapper(...) end
		mod.validate_environment_selection()
		return mod.apply_havoc_conditions(base_mod._havoc_condition_manager_context_wrapper(...))
	end
end

if not base_mod._havoc_condition_manager_view_wrapper then
	base_mod._havoc_condition_manager_view_wrapper = base_mod.open_solo_view
	base_mod.open_solo_view = function(...)
		if mod:is_enabled() then return mod.open_condition_manager_view(...) end
		return base_mod._havoc_condition_manager_view_wrapper(...)
	end
end

mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/workarounds/havoc_condition_ui")
mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/native_spawn")
mod:io_dofile("HavocConditionManager/scripts/mods/HavocConditionManager/condition_compatibility")

mod.get_selected_conditions = function()
    return HavocConditions.compose(mod.get_primary_havoc_conditions(), {
        base_mod:get("havoc_theme_circumstance"), base_mod:get("havoc_difficulty_circumstance"),
    })
end
mod.refresh_condition_generators = function()
    local director=get_mod("HavocEnemyDirector")
    if director and director.synchronize_conditions then director.synchronize_conditions() end
end
mod.on_setting_changed = function(key)
    local category=type(key)=="string" and key:match("^spawn_multiplier_(%w+)$")
    local director=category and get_mod("HavocEnemyDirector")
    if director and director.apply_capacity_presets then director.apply_capacity_presets(category) end
end
mod.close_condition_manager_view=function()
    if Managers.ui and Managers.ui:view_instance(VIEW_NAME) then Managers.ui:close_view(VIEW_NAME) end
end
local function state_changed(initial_call)
    toggle.changed(initial_call)
    set_catalog_enabled(mod:is_enabled())
    if not initial_call then mod.close_condition_manager_view() end
    local director=get_mod("HavocEnemyDirector")
    if director and director.on_base_state_changed then director.on_base_state_changed(initial_call) end
end
mod.on_enabled=state_changed
mod.on_disabled=state_changed
mod.on_game_state_changed=function(status,state)
    if state~="GameplayStateRun" then return end
    if status=="exit" then toggle.finish() elseif status=="enter" then toggle.start() end
end
