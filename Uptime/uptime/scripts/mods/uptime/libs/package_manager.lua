local mod = get_mod("uptime")
local loaded_packages = {}

function load_resource(name)
    if not string.find(name, "content/ui/textures/icons/traits/weapon") then
        -- currently only weapon traits need to be loaded. talent icons seem to be loaded always
        return
    end
    loaded_packages[name] = Managers.package:load(name, "uptime", function()
    end)
end

function unload_resource(name)
    local id = loaded_packages[name]
    if id then
        Managers.package:release(id)
    end
end

mod.packages = {
    load_resource = load_resource,
    unload_resource = unload_resource
}