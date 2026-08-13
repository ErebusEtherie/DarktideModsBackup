local mod = get_mod("InstantHub")
local Application = rawget(_G, "Application")
local Xbox = rawget(_G, "Xbox")

local settings = {}
local setting_keys = { "hub_caching", "show_notifications", "preload_hub", "preload_psychanium" }

local function setting(key)
    if settings[key] == nil then
        settings[key] = mod:get(key)
    end

    return settings[key]
end

local function build_settings()
    for _, key in ipairs(setting_keys) do
        settings[key] = mod:get(key)
    end
end

local function game_mode_name()
    local game_mode = Managers.state and Managers.state.game_mode

    return game_mode and game_mode:game_mode_name()
end

local function is_in_hub()
    return game_mode_name() == "hub"
end

local hub_mission_name = "hub_ship"
local psychanium_mission_name = "tg_shooting_range"

local function new_preload(reference_name, done_message)
    return {
        state = "idle",
        generation = 0,
        packages = {},
        pending_ids = {},
        scheduling = 0,
        unavailable_packages = {},
        warned_packages = {},
        item_dependencies_scheduled = {},
        theme_dependencies_scheduled = {},
        base_scheduled = false,
        master_items_version = nil,
        active_theme_tag = nil,
        active_character_id = nil,
        notified = false,
        silent = false,
        reference_name = reference_name,
        done_message = done_message,
    }
end

local hub_preload = new_preload("InstantHub:Mourningstar", "InstantHub: Mourningstar preloaded")
local hub_theme_preload = new_preload("InstantHub:MourningstarTheme", "InstantHub: Mourningstar theme preloaded")
local psychanium_preload = new_preload("InstantHub:Psychanium", "InstantHub: Psychanium / Meat Grinder preloaded")
local local_profile_preload = new_preload("InstantHub:LocalProfile", "InstantHub: Local profile resources preloaded")

local preload_triggered_once = false
local hub_ready = false
local hub_setup_pending = false
local hub_ready_once = false
local hub_cache_active = false
local registered_event_manager = nil
local main_menu_profile_preload_triggered = false

local function release_preload(preload)
    if preload.state == "released" then
        return
    end

    preload.generation = preload.generation + 1
    preload.state = "released"

    local packages = preload.packages

    preload.packages = {}
    preload.pending_ids = {}
    preload.scheduling = 0
    preload.unavailable_packages = {}
    preload.warned_packages = {}
    preload.item_dependencies_scheduled = {}
    preload.theme_dependencies_scheduled = {}
    preload.base_scheduled = false
    preload.master_items_version = nil
    preload.active_theme_tag = nil
    preload.active_character_id = nil
    preload.notified = false
    preload.silent = false

    local package_manager = Managers.package

    if package_manager then
        for _, entry in pairs(packages) do
            package_manager:release(entry.id)
        end
    end
end

local function reset_preload(preload)
    if preload.state ~= "released" then
        release_preload(preload)
    end

    preload.state = "idle"
end

local function mark_preload_done(preload)
    if preload.state ~= "loading" or preload.scheduling > 0 or next(preload.pending_ids) then
        return
    end

    preload.state = "done"

    if not preload.notified and not preload.silent and not next(preload.unavailable_packages) then
        preload.notified = true

        if setting("show_notifications") then
            mod:notify(preload.done_message)
        end
    end
end

local function preload_pkg(preload, name, loaded_callback, prioritize, warn_unavailable)
    if type(name) ~= "string" or preload.state ~= "loading" then
        return
    end

    local existing_entry = preload.packages[name]

    if existing_entry then
        if loaded_callback then
            if existing_entry.loaded then
                loaded_callback()
            else
                existing_entry.callbacks[#existing_entry.callbacks + 1] = loaded_callback
            end
        end

        return existing_entry.id
    end

    local unavailable_entry = preload.unavailable_packages[name]

    if unavailable_entry then
        unavailable_entry.prioritize = unavailable_entry.prioritize or prioritize

        if loaded_callback then
            unavailable_entry.callbacks[#unavailable_entry.callbacks + 1] = loaded_callback
        end

        return
    end

    local package_manager = Managers.package

    if not package_manager then
        return
    end

    local package_is_known = package_manager:package_is_known(name)

    if not package_is_known and (not Application or not Application.can_get_resource("package", name)) then
        preload.unavailable_packages[name] = {
            callbacks = loaded_callback and { loaded_callback } or {},
            prioritize = prioritize,
        }

        if warn_unavailable and not preload.warned_packages[name] then
            preload.warned_packages[name] = true
            mod:warning("Package still unavailable after target load [%s]: %s", preload.reference_name, name)
        end

        return
    end

    local generation = preload.generation

    local function package_loaded(id)
        if preload.generation ~= generation or preload.state == "released" then
            return
        end

        local entry = preload.packages[name]

        if not entry or entry.id ~= id then
            return
        end

        entry.loaded = true
        preload.pending_ids[id] = nil

        local callbacks = entry.callbacks

        entry.callbacks = {}

        for i = 1, #callbacks do
            if preload.generation ~= generation or preload.state == "released" then
                return
            end

            callbacks[i]()
        end

        mark_preload_done(preload)
    end

    local id = package_manager:load(name, preload.reference_name, package_loaded, prioritize)

    preload.packages[name] = {
        id = id,
        loaded = false,
        callbacks = loaded_callback and { loaded_callback } or {},
    }
    preload.pending_ids[id] = true

    return id
end

local function retry_unavailable_packages(preload, warn_unavailable)
    local unavailable_packages = preload.unavailable_packages

    if not next(unavailable_packages) then
        return
    end

    preload.unavailable_packages = {}

    for name, entry in pairs(unavailable_packages) do
        if #entry.callbacks == 0 then
            preload_pkg(preload, name, nil, entry.prioritize, warn_unavailable)
        else
            for i = 1, #entry.callbacks do
                preload_pkg(preload, name, entry.callbacks[i], entry.prioritize, warn_unavailable)
            end
        end
    end
end

local function schedule_preload(preload, silent, schedule, warn_unavailable)
    if preload.state == "released" then
        reset_preload(preload)
    end

    if preload.state == "idle" then
        preload.notified = false
        preload.silent = silent
    elseif not silent then
        preload.silent = false
    end

    preload.state = "loading"
    preload.scheduling = preload.scheduling + 1

    retry_unavailable_packages(preload, warn_unavailable)
    schedule()

    preload.scheduling = preload.scheduling - 1
    mark_preload_done(preload)
end

local function preload_package_setting(preload, package_setting)
    if type(package_setting) == "table" then
        for i = 1, #package_setting do
            preload_pkg(preload, package_setting[i])
        end
    else
        preload_pkg(preload, package_setting)
    end
end

local function preload_level_items(preload, level_name, item_definitions, item_package, master_items_version)
    if preload.item_dependencies_scheduled[level_name] then
        return
    end

    preload.item_dependencies_scheduled[level_name] = true

    preload_pkg(preload, level_name, function()
        local current_master_items_version = require("scripts/backend/master_items").get_cached_version()

        if preload.master_items_version ~= master_items_version or current_master_items_version ~= master_items_version then
            return
        end

        local item_packages = item_package.level_resource_dependency_packages(item_definitions, level_name)

        if item_packages then
            for package_name, _ in pairs(item_packages) do
                preload_pkg(preload, package_name)
            end
        end
    end)
end

local function preload_level_theme(preload, level_name, theme_tag, theme_package, prioritize)
    local dependency_key = level_name .. "\0" .. theme_tag
    local dependency_data = preload.theme_dependencies_scheduled[dependency_key]

    if dependency_data then
        dependency_data.prioritize = dependency_data.prioritize or prioritize

        return
    end

    dependency_data = {
        prioritize = prioritize or false,
    }
    preload.theme_dependencies_scheduled[dependency_key] = dependency_data

    preload_pkg(preload, level_name, function()
        local theme_packages = theme_package.level_resource_dependency_packages(level_name, theme_tag)

        if theme_packages then
            for _, package_name in pairs(theme_packages) do
                preload_pkg(preload, package_name, nil, dependency_data.prioritize)
            end
        end
    end, dependency_data.prioritize)
end

local function preload_view_level(preload, level_name, item_definitions, item_package, master_items_version)
    preload_level_items(preload, level_name, item_definitions, item_package, master_items_version)
end

local function view_preload_policies()
    local sub_platform = ""

    if IS_XBS and Xbox then
        if Xbox.console_type() == Xbox.CONSOLE_TYPE_XBOX_SCARLETT_ANACONDA then
            sub_platform = "anaconda"
        elseif Xbox.console_type() == Xbox.CONSOLE_TYPE_XBOX_SCARLETT_LOCKHEART then
            sub_platform = "lockhart"
        end
    end

    local disable_preload = GameParameters.disable_view_preload

    return {
        always_even_with_debug = true,
        always = not disable_preload,
        not_ps5 = not disable_preload and not IS_PLAYSTATION,
        not_ps5_nor_lockhart = not disable_preload and not IS_PLAYSTATION and sub_platform ~= "lockhart",
    }
end

local function preload_views(preload, policy_key, mission_name, item_definitions, item_package, master_items_version)
    local Views = require("scripts/ui/views/views")
    local policies = view_preload_policies()

    for view_name, view_settings in pairs(Views) do
        local policy = view_settings[policy_key]

        if policy and policies[policy] then
            preload_package_setting(preload, view_settings.package)

            if view_settings.levels then
                for _, level_name in ipairs(view_settings.levels) do
                    preload_view_level(preload, level_name, item_definitions, item_package, master_items_version)
                end
            end

            if view_name == "mission_intro_view" then
                local MissionIntroView = require("scripts/ui/views/mission_intro_view/mission_intro_view")
                local _, dynamic_level_package = MissionIntroView.select_target_intro_level(mission_name)

                if dynamic_level_package and dynamic_level_package.is_level_package then
                    preload_view_level(preload, dynamic_level_package.name, item_definitions, item_package, master_items_version)
                elseif dynamic_level_package then
                    preload_pkg(preload, dynamic_level_package.name)
                end
            end
        end
    end
end

local function preload_hud(preload, mission_settings)
    if not mission_settings.hud_elements then
        return
    end

    local hud_elements = require(mission_settings.hud_elements)

    if hud_elements then
        for _, element in ipairs(hud_elements) do
            preload_pkg(preload, element.package)
        end
    end
end

local function preload_game_mode(preload, mission_settings)
    local GameModeSettings = require("scripts/settings/game_mode/game_mode_settings")
    local game_mode_settings = GameModeSettings[mission_settings.game_mode_name]
    local packages = game_mode_settings and game_mode_settings.packages

    if packages then
        for i = 1, #packages do
            preload_pkg(preload, packages[i])
        end
    end
end

local function preload_hub_breeds(preload, item_definitions)
    local BreedQueries = require("scripts/utilities/breed_queries")
    local BreedResourceDependencies = require("scripts/utilities/breed_resource_dependencies")
    local chosen_breeds = {}
    local player_breeds = BreedQueries.player_breeds_by_name()

    for breed_name, breed in pairs(player_breeds) do
        chosen_breeds[breed_name] = breed
    end

    local companion_breeds = BreedQueries.minion_companion_breeds_by_name()

    for breed_name, breed in pairs(companion_breeds) do
        chosen_breeds[breed_name] = breed
    end

    local breeds_to_load = BreedResourceDependencies.generate(chosen_breeds, item_definitions)

    if breeds_to_load then
        for package_name, _ in pairs(breeds_to_load) do
            preload_pkg(preload, package_name)
        end
    end
end

local function preload_mission_breeds(preload, item_definitions)
    local BreedResourceDependencies = require("scripts/utilities/breed_resource_dependencies")
    local Breeds = require("scripts/settings/breed/breeds")
    local breeds_to_load = BreedResourceDependencies.generate(Breeds, item_definitions)

    if breeds_to_load then
        for package_name, _ in pairs(breeds_to_load) do
            preload_pkg(preload, package_name)
        end
    end
end

local function start_hub_preload(silent, warn_unavailable)
    if hub_preload.state == "released" then
        reset_preload(hub_preload)
    end

    local MasterItems = require("scripts/backend/master_items")
    local Missions = require("scripts/settings/mission/mission_templates")
    local item_definitions = MasterItems.get_cached()
    local master_items_version = MasterItems.get_cached_version()
    local hub_settings = Missions[hub_mission_name]

    if not item_definitions or not hub_settings then
        return false
    end

    local initial_base = not hub_preload.base_scheduled
    local version_changed = hub_preload.base_scheduled and hub_preload.master_items_version ~= master_items_version

    if version_changed then
        hub_preload.item_dependencies_scheduled = {}
        hub_preload.unavailable_packages = {}
        hub_preload.base_scheduled = false
    end

    local needs_base = not hub_preload.base_scheduled
    local has_unavailable_packages = next(hub_preload.unavailable_packages) ~= nil

    if not needs_base and not has_unavailable_packages then
        return true
    end

    if initial_base and setting("show_notifications") and not silent then
        mod:notify("InstantHub: Preloading Mourningstar...")
    end

    local ItemPackage = require("scripts/foundation/managers/package/utilities/item_package")
    local level_name = hub_settings.level

    schedule_preload(hub_preload, silent, function()
        if needs_base then
            hub_preload.base_scheduled = true
            hub_preload.master_items_version = master_items_version
            preload_level_items(hub_preload, level_name, item_definitions, ItemPackage, master_items_version)
            preload_views(hub_preload, "preload_in_hub", hub_mission_name, item_definitions, ItemPackage, master_items_version)
            preload_hud(hub_preload, hub_settings)
            preload_game_mode(hub_preload, hub_settings)
            preload_hub_breeds(hub_preload, item_definitions)
        end
    end, warn_unavailable)

    return true
end

local function start_hub_theme_preload(theme_tag, prioritize, warn_unavailable)
    if hub_theme_preload.state == "released" then
        reset_preload(hub_theme_preload)
    end

    if hub_theme_preload.active_theme_tag and hub_theme_preload.active_theme_tag ~= theme_tag then
        release_preload(hub_theme_preload)
        reset_preload(hub_theme_preload)
    end

    local needs_theme = hub_theme_preload.active_theme_tag ~= theme_tag

    if prioritize then
        for _, entry in pairs(hub_theme_preload.unavailable_packages) do
            entry.prioritize = true
        end
    end

    local has_unavailable_packages = next(hub_theme_preload.unavailable_packages) ~= nil
    local Missions = require("scripts/settings/mission/mission_templates")
    local hub_settings = Missions[hub_mission_name]

    if not hub_settings then
        return
    end

    local ThemePackage = require("scripts/foundation/managers/package/utilities/theme_package")

    if not needs_theme and prioritize then
        preload_level_theme(hub_theme_preload, hub_settings.level, theme_tag, ThemePackage, true)
    end

    if not needs_theme and not has_unavailable_packages then
        return
    end

    schedule_preload(hub_theme_preload, true, function()
        if needs_theme then
            hub_theme_preload.active_theme_tag = theme_tag
            preload_level_theme(hub_theme_preload, hub_settings.level, theme_tag, ThemePackage, prioritize)
        end
    end, warn_unavailable)
end

local function start_psychanium_preload(warn_unavailable)
    if not setting("preload_psychanium") then
        return
    end

    if psychanium_preload.state == "released" then
        reset_preload(psychanium_preload)
    end

    local MasterItems = require("scripts/backend/master_items")
    local Missions = require("scripts/settings/mission/mission_templates")
    local item_definitions = MasterItems.get_cached()
    local master_items_version = MasterItems.get_cached_version()
    local mission_settings = Missions[psychanium_mission_name]

    if not item_definitions or not mission_settings then
        return
    end

    local initial_base = not psychanium_preload.base_scheduled
    local version_changed = psychanium_preload.base_scheduled and psychanium_preload.master_items_version ~= master_items_version

    if version_changed then
        psychanium_preload.item_dependencies_scheduled = {}
        psychanium_preload.theme_dependencies_scheduled = {}
        psychanium_preload.unavailable_packages = {}
        psychanium_preload.base_scheduled = false
    end

    local needs_base = not psychanium_preload.base_scheduled
    local has_unavailable_packages = next(psychanium_preload.unavailable_packages) ~= nil

    if not needs_base and not has_unavailable_packages then
        return
    end

    if initial_base and setting("show_notifications") then
        mod:notify("InstantHub: Preloading Psychanium / Meat Grinder...")
    end

    local ItemPackage = require("scripts/foundation/managers/package/utilities/item_package")
    local ThemePackage = require("scripts/foundation/managers/package/utilities/theme_package")

    schedule_preload(psychanium_preload, false, function()
        if needs_base then
            psychanium_preload.base_scheduled = true
            psychanium_preload.master_items_version = master_items_version
            psychanium_preload.active_theme_tag = "default"
            preload_level_items(psychanium_preload, mission_settings.level, item_definitions, ItemPackage, master_items_version)
            preload_level_theme(psychanium_preload, mission_settings.level, "default", ThemePackage)
            preload_views(psychanium_preload, "preload_in_mission", psychanium_mission_name, item_definitions, ItemPackage, master_items_version)
            preload_hud(psychanium_preload, mission_settings)
            preload_game_mode(psychanium_preload, mission_settings)
            preload_mission_breeds(psychanium_preload, item_definitions)
        end
    end, warn_unavailable)
end

local function hub_theme_tag(circumstance_name)
    local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")
    local circumstance_template = circumstance_name and CircumstanceTemplates[circumstance_name]

    return circumstance_template and circumstance_template.theme_tag or "default"
end

local function current_hub_theme_tag()
    local mechanism_manager = Managers.mechanism
    local mechanism_data = mechanism_manager and mechanism_manager:mechanism_data()

    return hub_theme_tag(mechanism_data and mechanism_data.circumstance_name)
end

local function should_keep_hub_preload()
    local early_preload_active = not hub_ready_once and setting("preload_hub")

    return early_preload_active or hub_cache_active
end

local function should_retain_local_profile_preload()
    return setting("hub_caching") or setting("preload_psychanium")
end

local function should_use_local_profile_preload(state_name)
    if state_name == "StateMainMenu" then
        return setting("preload_hub") or should_retain_local_profile_preload()
    elseif state_name == "StateGameplay" then
        return should_retain_local_profile_preload()
    elseif state_name == "StateTitle" then
        return false
    end

    return setting("preload_hub") or should_retain_local_profile_preload()
end

local function local_profile_package_resolver()
    local package_synchronization_manager = Managers.package_synchronization
    local synchronizer_client = package_synchronization_manager and package_synchronization_manager:synchronizer_client()

    if synchronizer_client and synchronizer_client:item_definitions_initialized() then
        return synchronizer_client
    end

    local item_definitions = require("scripts/backend/master_items").get_cached()

    if not item_definitions then
        return
    end

    local PackageSynchronizerClient = require("scripts/loading/package_synchronizer_client")

    return setmetatable({
        _item_definitions = item_definitions,
        _mission_name = hub_mission_name,
    }, {
        __index = PackageSynchronizerClient,
    })
end

local function current_local_profile()
    local player_manager = Managers.player
    local player = player_manager and player_manager:local_player(1)

    return player and player:profile()
end

local function start_local_profile_preload(profile, warn_unavailable)
    local resolver = local_profile_package_resolver()
    local package_manager = Managers.package

    if not package_manager or not resolver then
        return false
    end

    if not profile then
        profile = current_local_profile()
    end

    local character_id = profile and profile.character_id

    if not character_id then
        return false
    end

    if local_profile_preload.state == "released" then
        reset_preload(local_profile_preload)
    end

    local profile_packages = resolver:resolve_profile_packages(profile)
    local desired_packages = {}
    local packages_to_release = {}

    for _, package_data in pairs(profile_packages) do
        for package_name, _ in pairs(package_data.dependencies) do
            desired_packages[package_name] = true
        end
    end

    for package_name, _ in pairs(local_profile_preload.packages) do
        if not desired_packages[package_name] then
            packages_to_release[#packages_to_release + 1] = package_name
        end
    end

    for i = 1, #packages_to_release do
        local package_name = packages_to_release[i]
        local entry = local_profile_preload.packages[package_name]

        if entry then
            local_profile_preload.packages[package_name] = nil
            local_profile_preload.pending_ids[entry.id] = nil
            local_profile_preload.warned_packages[package_name] = nil
            package_manager:release(entry.id)
        end
    end

    for package_name, _ in pairs(local_profile_preload.unavailable_packages) do
        if not desired_packages[package_name] then
            local_profile_preload.unavailable_packages[package_name] = nil
            local_profile_preload.warned_packages[package_name] = nil
        end
    end

    local_profile_preload.active_character_id = character_id

    schedule_preload(local_profile_preload, true, function()
        for package_name, _ in pairs(desired_packages) do
            preload_pkg(local_profile_preload, package_name)
        end
    end, warn_unavailable)

    return true
end

local function prepare_hub_caches()
    hub_setup_pending = false
    hub_ready_once = true

    if setting("hub_caching") then
        hub_cache_active = true
        start_hub_preload(true, true)
        start_hub_theme_preload(current_hub_theme_tag(), false, true)
    else
        hub_cache_active = false
        release_preload(hub_preload)
        release_preload(hub_theme_preload)
    end

    start_psychanium_preload()
end

local function register_events()
    local event_manager = Managers.event

    if registered_event_manager == event_manager then
        return
    end

    if registered_event_manager then
        registered_event_manager:unregister(mod, "event_loading_finished")
        registered_event_manager:unregister(mod, "event_player_set_profile")
        registered_event_manager = nil
    end

    if event_manager then
        event_manager:register(mod, "event_loading_finished", "event_loading_finished")
        event_manager:register(mod, "event_player_set_profile", "event_player_set_profile")
        registered_event_manager = event_manager
    end
end

local function unregister_events()
    if registered_event_manager then
        registered_event_manager:unregister(mod, "event_loading_finished")
        registered_event_manager:unregister(mod, "event_player_set_profile")
        registered_event_manager = nil
    end
end

mod.event_loading_finished = function()
    if not mod:is_enabled() then
        return
    end

    if should_retain_local_profile_preload() then
        start_local_profile_preload(nil, true)
    else
        release_preload(local_profile_preload)
    end

    local mode_name = game_mode_name()

    if mode_name == "hub" then
        hub_ready = true
        hub_setup_pending = true

        if setting("show_notifications") then
            mod:notify("InstantHub: Mourningstar ready")
        end
    else
        if mode_name == "shooting_range" then
            start_psychanium_preload(true)

            if setting("show_notifications") then
                mod:notify("InstantHub: Psychanium / Meat Grinder ready")
            end
        end

        if hub_cache_active and setting("hub_caching") then
            start_hub_preload(true)
        end
    end
end

mod.event_player_set_profile = function(_, player, profile)
    if not mod:is_enabled() then
        return
    end

    local player_manager = Managers.player
    local local_player = player_manager and player_manager:local_player(1)

    if player == local_player then
        local state_name = Managers.presence and Managers.presence._current_game_state_name

        if profile and should_use_local_profile_preload(state_name) then
            local wait_for_hub_preload = state_name == "StateMainMenu" and setting("preload_hub") and hub_preload.state ~= "done"
            local started = not wait_for_hub_preload and start_local_profile_preload(profile)

            if state_name == "StateMainMenu" then
                main_menu_profile_preload_triggered = started
            end
        else
            release_preload(local_profile_preload)

            if state_name == "StateMainMenu" then
                main_menu_profile_preload_triggered = false
            end
        end
    end
end

mod:hook("MechanismManager", "wanted_transition", function(func, self, ...)
    local next_state, context = func(self, ...)

    if context and context.mission_name == hub_mission_name then
        if should_keep_hub_preload() then
            start_hub_preload(true)
        end

        if setting("preload_hub") or setting("hub_caching") then
            start_hub_theme_preload(hub_theme_tag(context.circumstance_name), true)
        end
    elseif context and context.mission_name == psychanium_mission_name then
        start_psychanium_preload()
    end

    return next_state, context
end)

mod:hook("StateTitle", "update", function(func, self, ...)
    local next_state, params = func(self, ...)

    if not preload_triggered_once and self._backend_data_synced then
        if setting("preload_hub") then
            preload_triggered_once = start_hub_preload(false)
        end
    end

    return next_state, params
end)

mod.update = function()
    if not mod:is_enabled() then
        return
    end

    register_events()

    local state_name = Managers.presence and Managers.presence._current_game_state_name

    if state_name == "StateMainMenu" and setting("preload_hub") and not preload_triggered_once then
        preload_triggered_once = start_hub_preload(false)
    end

    if state_name == "StateMainMenu" and should_use_local_profile_preload(state_name) then
        local profile = current_local_profile()

        if profile and local_profile_preload.active_character_id ~= profile.character_id then
            main_menu_profile_preload_triggered = false
        end

        local hub_preload_ready = not setting("preload_hub") or hub_preload.state == "done"

        if not main_menu_profile_preload_triggered and hub_preload_ready then
            main_menu_profile_preload_triggered = start_local_profile_preload(profile)
        end
    end

    if hub_setup_pending and hub_ready and is_in_hub() then
        prepare_hub_caches()
    end
end

mod.on_setting_changed = function(setting_id)
    settings[setting_id] = mod:get(setting_id)

    if not mod:is_enabled() then
        return
    end

    if setting_id == "hub_caching" then
        if setting("hub_caching") then
            local state_name = Managers.presence and Managers.presence._current_game_state_name

            if hub_ready or hub_ready_once or state_name == "StateGameplay" then
                hub_cache_active = true

                if is_in_hub() then
                    start_hub_preload(true)
                    start_hub_theme_preload(current_hub_theme_tag())
                else
                    start_hub_preload(true)
                end
            end
        else
            hub_cache_active = false

            if not should_keep_hub_preload() then
                release_preload(hub_preload)
                release_preload(hub_theme_preload)
            end
        end
    elseif setting_id == "preload_hub" then
        if setting("preload_hub") then
            local state_name = Managers.presence and Managers.presence._current_game_state_name

            if not hub_ready_once and state_name == "StateMainMenu" then
                preload_triggered_once = start_hub_preload(false)
            end
        elseif not should_keep_hub_preload() then
            release_preload(hub_preload)
            release_preload(hub_theme_preload)
        end
    elseif setting_id == "preload_psychanium" then
        if setting("preload_psychanium") then
            local state_name = Managers.presence and Managers.presence._current_game_state_name

            if (hub_ready and is_in_hub()) or state_name == "StateGameplay" then
                start_psychanium_preload()
            end
        else
            release_preload(psychanium_preload)
        end
    end

    if setting_id == "hub_caching" or setting_id == "preload_hub" or setting_id == "preload_psychanium" then
        local state_name = Managers.presence and Managers.presence._current_game_state_name

        if not should_use_local_profile_preload(state_name) then
            release_preload(local_profile_preload)
            main_menu_profile_preload_triggered = false
        elseif state_name == "StateMainMenu" then
            main_menu_profile_preload_triggered = false

            if not setting("preload_hub") or hub_preload.state == "done" then
                main_menu_profile_preload_triggered = start_local_profile_preload()
            end
        else
            start_local_profile_preload()
        end
    end
end

mod.on_enabled = function()
    build_settings()
    register_events()

    if hub_preload.state == "released" then
        reset_preload(hub_preload)
    end

    if hub_theme_preload.state == "released" then
        reset_preload(hub_theme_preload)
    end

    if psychanium_preload.state == "released" then
        reset_preload(psychanium_preload)
    end

    if local_profile_preload.state == "released" then
        reset_preload(local_profile_preload)
    end

    local state_name = Managers.presence and Managers.presence._current_game_state_name

    if state_name == "StateGameplay" then
        if is_in_hub() then
            hub_ready = true
            hub_setup_pending = true
        elseif setting("hub_caching") then
            hub_cache_active = true
            start_hub_preload(true)
        end

        if not is_in_hub() and setting("preload_psychanium") then
            start_psychanium_preload()
        end

        if should_retain_local_profile_preload() then
            start_local_profile_preload()
        end
    end
end

mod.on_disabled = function()
    unregister_events()
    release_preload(hub_preload)
    release_preload(hub_theme_preload)
    release_preload(psychanium_preload)
    release_preload(local_profile_preload)

    preload_triggered_once = false
    hub_ready = false
    hub_setup_pending = false
    hub_ready_once = false
    hub_cache_active = false
    main_menu_profile_preload_triggered = false
end

mod.on_game_state_changed = function(status, state_name)
    if not mod:is_enabled() or status ~= "enter" then
        return
    end

    if state_name == "StateLoading" or state_name == "StateMainMenu" or state_name == "StateTitle" then
        hub_ready = false
        hub_setup_pending = false
    end

    if state_name == "StateMainMenu" then
        preload_triggered_once = false
        main_menu_profile_preload_triggered = false
    elseif state_name == "StateTitle" then
        release_preload(hub_preload)
        release_preload(hub_theme_preload)
        release_preload(psychanium_preload)
        release_preload(local_profile_preload)

        preload_triggered_once = false
        hub_ready_once = false
        hub_cache_active = false
        main_menu_profile_preload_triggered = false
    end
end

mod.on_unload = function()
    unregister_events()
    release_preload(hub_preload)
    release_preload(hub_theme_preload)
    release_preload(psychanium_preload)
    release_preload(local_profile_preload)
end
