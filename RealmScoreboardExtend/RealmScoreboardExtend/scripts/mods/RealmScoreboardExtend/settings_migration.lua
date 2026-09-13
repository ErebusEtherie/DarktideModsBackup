-- Runs from mod_data, before DMF installs defaults and registers keybinds.
-- The old mod need not be loaded: DMF retains settings for unloaded mods.
local M = {}
function M.import(mod, dmf, widgets)
    if mod:get("settings_import_v1") then return 0 end
    if not dmf or type(dmf._get_setting_value) ~= "function" then return 0 end
    local count = 0
    for _, widget in ipairs(widgets) do
        local id = widget.setting_id
        if id and mod:get(id) == nil then
            local previous = dmf._get_setting_value("ScoreboardRoster", id)
            if previous ~= nil then
                mod:set(id, previous, false)
                count = count + 1
            end
        end
    end
    mod:set("settings_import_v1", true, false)
    if count > 0 then mod:info("[RSE:migration] Imported %d settings from ScoreboardRoster", count) end
    return count
end
return M
