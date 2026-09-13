local mod = get_mod("MortisBuffManager")
mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/migration")
local Workspace = mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/workspace_router")
Workspace.install()
mod.open_workspace = function() return Workspace.open("mortis") end
local data = mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/MortisBuffManager_data")
mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/session")
mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_catalog")
mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_buffs")
local DIY=mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/diy_mortis")
-- io_dofile reports the original error and returns false on failure. Avoid
-- repeating that initialization failure from every update and teardown call.
if type(DIY)~="table" then DIY=nil end
mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/diy_ranged_salvo")
mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_talent_ui")
mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_workspace_view")
local RealmsControls = mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_realms_controls")
local DraftHUD = mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_draft_hud")
mod:io_dofile("MortisBuffManager/scripts/mods/MortisBuffManager/modules/mortis_numeric_ui")
if RealmsControls then RealmsControls.install() end
local function sync(widgets)
    for _, widget in ipairs(widgets or {}) do
        if widget.type == "group" then sync(widget.sub_widgets)
        elseif widget.setting_id and widget.type ~= "button" then
            mod._settings[widget.setting_id] = mod:get(widget.setting_id)
        end
    end
end
mod.update = function(dt)
    if mod:is_enabled() then
        mod.update_mortis_buffs(dt)
        if DIY then DIY.update(dt) end
    end
end
mod.on_all_mods_loaded = function()
    sync(data.options.widgets)
    mod.mortis_buffs_on_all_mods_loaded()
    if DIY and mod.diy_library and mod.diy_library.resolve_startup_dependencies then mod.diy_library.resolve_startup_dependencies() end
end
mod.on_setting_changed = function(key)
    if key == "mortis_debug_input" then mod._settings[key] = false; return end
    mod._settings[key] = mod:get(key)
    mod.mortis_buffs_on_setting_changed(key)
end
mod.on_game_state_changed = function(status, state_name)
    if state_name ~= "GameplayStateRun" then return end
    if status == "enter" then sync(data.options.widgets)
    elseif status == "exit" then
        if DraftHUD then DraftHUD.cleanup() end
        mod.cleanup_mortis_buffs()
        if DIY then DIY.finish() end
    end
end
mod.on_disabled = function()
    if DIY then DIY.finish() end
    Workspace.cleanup()
	mod.cleanup_mortis_talent_ui()
    if RealmsControls then RealmsControls.cleanup() end
    if DraftHUD then DraftHUD.cleanup() end
    mod.cleanup_mortis_buffs()
end
mod.on_unload = mod.on_disabled
mod.on_enabled = function()
    Workspace.enable()
    sync(data.options.widgets)
    if RealmsControls then RealmsControls.refresh_hooks() end
end
