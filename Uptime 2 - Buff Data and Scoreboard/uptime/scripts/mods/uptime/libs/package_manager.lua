-- File: uptime\scripts\mods\uptime\libs\package_manager.lua
local mod = get_mod("uptime")
if not mod then
    return
end

local loaded_packages = {}

local function is_managed_resource(name)
    return type(name) == "string"
        and name ~= ""
        and (
            string.find(name, "content/ui/textures/icons/traits/weapon", 1, true) ~= nil
            or string.find(name, "content/ui/materials/icons/weapons/hud", 1, true) ~= nil
        )
end

mod.packages = mod.packages or {}

mod.packages.load_resource = function(name)
    if not is_managed_resource(name) then
        return
    end

    if loaded_packages[name] then
        return
    end

    loaded_packages[name] = Managers.package:load(name, "uptime", function()
    end)
end

mod.packages.unload_resource = function(name)
    -- Intentionally do nothing.
    --
    -- UptimeView widgets can still be referenced by UptimeView_ui_renderer when
    -- the view is destroyed. Releasing dynamically loaded icon packages here can
    -- therefore crash the engine with:
    --
    -- "Trying to unload resource ... that's used elsewhere by the engine"
    --
    -- Weapon-trait icons loaded by Uptime are kept for the rest of the game
    -- session instead.
end
