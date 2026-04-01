-- File: ZipIt2/scripts/mods/ZipIt2/ZipIt2_data.lua
local mod = get_mod("ZipIt2"); if not mod then return end

mod:io_dofile("ZipIt2/scripts/mods/ZipIt2/core/ZipIt2_utils")

local function _load_required_data_module(path, exported_function_name, pass_discovery)
    mod:io_dofile(path)

    local exported = mod[exported_function_name]
    if type(exported) ~= "function" then
        error(("ZipIt2: %s must define mod.%s"):format(path, exported_function_name))
    end

    if pass_discovery then
        exported(mod._zipit2_discovery)
    else
        return exported()
    end
end

mod._zipit2_discovery = mod._zipit2_discovery or {}

_load_required_data_module("ZipIt2/scripts/mods/ZipIt2/settings/ZipIt2_data_archetypes", "zipit2_build_archetypes", true)
_load_required_data_module("ZipIt2/scripts/mods/ZipIt2/settings/ZipIt2_data_npcs", "zipit2_build_npcs", true)
_load_required_data_module("ZipIt2/scripts/mods/ZipIt2/settings/ZipIt2_data_breeds", "zipit2_build_breeds", true)
_load_required_data_module("ZipIt2/scripts/mods/ZipIt2/settings/ZipIt2_data_com_wheel", "zipit2_build_com_wheel", true)

local widgets = _load_required_data_module("ZipIt2/scripts/mods/ZipIt2/settings/ZipIt2_data_widgets",
    "zipit2_build_widgets",
    false) or {}

mod._zipit2_group_keys = {
    major = mod._zipit2_discovery.major_group_keys or {},
    minor = mod._zipit2_discovery.minor_group_keys or {},
    breed = mod._zipit2_discovery.breed_group_keys or {},
}

return {
    name         = mod:localize("mod_name"),
    description  = mod:localize("mod_description"),
    is_togglable = true,
    options      = { localize = false, widgets = widgets },
}
