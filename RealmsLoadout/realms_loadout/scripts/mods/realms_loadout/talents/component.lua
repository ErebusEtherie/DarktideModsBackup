local mod = get_mod("realms_loadout")
local component = {}
local build = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/build_config")
local function disable_release_debug()
    mod._settings.debug_talent_effects = false
    if mod:get("debug_talent_effects") == true then mod:set("debug_talent_effects", false) end
end
mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/migration")
local data = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/settings")
mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/session")
mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/custom_talents")
-- Equipment catalogs load after the talent module; both profile transforms
-- register with the shared single-hook dispatcher (realms_profile_hooks.lua),
-- which runs the weapon rebuild before the talent transform.
mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/weapon_catalog_sync")
-- Display-only patch for the Realms preparation page (local row shows the
-- saved Realms loadout instead of the live profile that temporarily holds the
-- official loadout). Never touches the profile pipeline.
mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/realms_preparation_loadout")
disable_release_debug()
mod:add_require_path("realms_loadout/scripts/mods/realms_loadout/talents/workspace_stimm_view")
mod:register_view({ view_name = "realms_loadout_stimm_view", view_settings = {
  class = "RealmsLoadoutStimmView", path = "realms_loadout/scripts/mods/realms_loadout/talents/workspace_stimm_view",
  package = "packages/ui/views/broker_stimm_builder_view/broker_stimm_builder_view", state_bound = true,
  init_view_function = function() return true end }, view_transitions = {} })
local function sync(widgets)
    for _, widget in ipairs(widgets or {}) do
        if widget.type == "group" then sync(widget.sub_widgets)
        elseif widget.setting_id and widget.type ~= "button" then
            mod._settings[widget.setting_id] = mod:get(widget.setting_id)
        end
    end
end
component.update = function(dt)
    if mod:is_enabled() then
        mod.update_custom_talents(dt)
        if mod.update_weapon_catalog_sync then mod.update_weapon_catalog_sync(dt) end
        if mod.update_preparation_loadout_display then mod.update_preparation_loadout_display(dt) end
        if mod._realms_inspect_update then mod._realms_inspect_update(dt) end
    end
end
component.on_all_mods_loaded = function()
    sync(data.options.widgets)
    mod.custom_talents_on_all_mods_loaded()
    disable_release_debug()
end
component.on_setting_changed = function(key)
    mod._settings[key] = mod:get(key)
    if key == "debug_talent_effects" then
        disable_release_debug()
        return
    end
    mod.custom_talents_on_setting_changed(key)
end
component.on_game_state_changed = function(status, state_name)
    if state_name == "RealmsPreparationState" then
        if not mod:is_enabled() then return end
        if status == "enter" then
            sync(data.options.widgets)
            mod.resume_custom_talents()
            mod.weapon_catalog_sync_resume()
        elseif status == "exit" then
            mod.pause_custom_talents()
            mod.weapon_catalog_sync_pause()
        end
        return
    end
    if state_name ~= "GameplayStateRun" then return end
    if status == "enter" then sync(data.options.widgets)
    mod.resume_custom_talents()
    mod.weapon_catalog_sync_resume()
    disable_release_debug()
    elseif status == "exit" then
        mod.cleanup_custom_talents(false, "gameplay_exit")
        mod.weapon_catalog_sync_cleanup()
    end
end
component.on_disabled = function()
    mod.cleanup_custom_talents(true)
    mod.weapon_catalog_sync_cleanup(true)
end
component.on_unload = component.on_disabled
component.on_enabled = function()
    sync(data.options.widgets)
    mod.resume_custom_talents()
    mod.weapon_catalog_sync_resume()
    disable_release_debug()
end

return component
