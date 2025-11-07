local mod = get_mod("MoreGraphicsOptions")
local customPresets = mod:io_dofile("MoreGraphicsOptions/scripts/mods/MoreGraphicsOptions/CustomPresets")
local render_settings = require("scripts/settings/options/render_settings")
local SettingsUtilitiesFunction = require("scripts/settings/options/settings_utils")
local SettingsUtilities = {}
SettingsUtilities = SettingsUtilitiesFunction(render_settings)

mod:hook_require("scripts/settings/options/render_settings", function(instance)
    for i, v in ipairs(instance.settings) do
        if v.id == "volumetric_fog_quality" then
            v.options = customPresets.volFogOptions
        end
        if v.id == "gi_quality" then
            v.options = customPresets.giOptions
        end
        if v.id == "light_quality" then
            v.options = customPresets.lightOptions
        end
        if v.id == "texture_quality" then
            v.options = customPresets.textureOptions
        end
    end
end)

mod:command("meshquality", (""), function(value)
    value = tonumber(value)
    if value == nil then
        mod:error("Invalid value. Please enter a number.")
        return
    end

    local decimalPart = string.match(value, "%.(%d+)")
    if decimalPart and #decimalPart > 1 then
        mod:error("Invalid value. More than one number after the decimal point is not allowed.")
        return
    end

    if value < 0.1 or value > 5 then
        mod:error("Invalid value. Min 0.1, Max 5")
        return
    end
    Application.set_user_setting("render_settings", "lod_object_multiplier", value)
    SettingsUtilities.apply_user_settings()
    SettingsUtilities.save_user_settings()
end)

mod:command("particles_capacity_multiplier", (""), function(value)
    value = tonumber(value)
    if value == nil then
        mod:error("Invalid value. Please enter a number.")
        return
    end

    local decimalPart = string.match(value, "%.(%d+)")
    if decimalPart and #decimalPart > 2 then
        mod:error("Invalid value. More than two numbers after the decimal point are not allowed.")
        return
    end

    if value < 0.0 or value > 1 then
        mod:error("Invalid value. Min 0.0, Max 1")
        return
    end
    Application.set_user_setting("render_settings", "particles_capacity_multiplier", value)
    SettingsUtilities.apply_user_settings()
    SettingsUtilities.save_user_settings()
end)

mod:command("maxragdolls", (""), function(value)
    value = tonumber(value)
    if value == nil then
        mod:error("Invalid value. Please enter a number.")
        return
    end

    local decimalPart = string.match(value, "%.(%d+)")
    if decimalPart and #decimalPart > 0 then
        mod:error("Invalid value. Can't use float.")
        return
    end

    if value < 1 or value > 50 then
        mod:error("Invalid value. Min 1, Max 50")
        return
    end
    Application.set_user_setting("performance_settings", "max_ragdolls", value)
    SettingsUtilities.apply_user_settings()
    SettingsUtilities.save_user_settings()
end)

mod:command("maximpactdecals", (""), function(value)
    value = tonumber(value)
    if value == nil then
        mod:error("Invalid value. Please enter a number.")
        return
    end

    local decimalPart = string.match(value, "%.(%d+)")
    if decimalPart and #decimalPart > 0 then
        mod:error("Invalid value. Can't use float.")
        return
    end

    if value < 0 or value > 100 then
        mod:error("Invalid value. Min 0, Max 100")
        return
    end
    Application.set_user_setting("performance_settings", "max_impact_decals", value)
    SettingsUtilities.apply_user_settings()
    SettingsUtilities.save_user_settings()
end)

mod:command("maxblooddecals", (""), function(value)
    value = tonumber(value)
    if value == nil then
        mod:error("Invalid value. Please enter a number.")
        return
    end

    local decimalPart = string.match(value, "%.(%d+)")
    if decimalPart and #decimalPart > 0 then
        mod:error("Invalid value. Can't use float.")
        return
    end

    if value < 0 or value > 100 then
        mod:error("Invalid value. Min 0, Max 100")
        return
    end
    Application.set_user_setting("performance_settings", "max_blood_decals", value)
    SettingsUtilities.apply_user_settings()
    SettingsUtilities.save_user_settings()
end)

mod:command("decallifetime", (""), function(value)
    value = tonumber(value)
    if value == nil then
        mod:error("Invalid value. Please enter a number.")
        return
    end

    local decimalPart = string.match(value, "%.(%d+)")
    if decimalPart and #decimalPart > 0 then
        mod:error("Invalid value. Can't use float.")
        return
    end

    if value < 0 or value > 60 then
        mod:error("Invalid value. Min 0, Max 60")
        return
    end
    Application.set_user_setting("performance_settings", "decal_lifetime", value)
    SettingsUtilities.apply_user_settings()
    SettingsUtilities.save_user_settings()
end)

mod.on_setting_changed = function(id)
    local val = mod:get(id)
    --render_settings
    if id == "meshquality" then
        Application.set_user_setting("render_settings", "lod_object_multiplier", val)
        SettingsUtilities.save_user_settings()
    end
    if id == "particles_capacity_multiplier" then
        Application.set_user_setting("render_settings", "particles_capacity_multiplier", val)
        SettingsUtilities.save_user_settings()
    end
    --light_quality
    if id == "sunshadows" then
        Application.set_user_setting("render_settings", "sun_shadows", val)
        SettingsUtilities.apply_user_settings()
        SettingsUtilities.save_user_settings()
    end
    if id == "local_lights_shadows_enabled" then
        Application.set_user_setting("render_settings", "local_lights_shadows_enabled", val)
        SettingsUtilities.apply_user_settings()
        SettingsUtilities.save_user_settings()
    end
    if id == "static_sun_shadows" then
        Application.set_user_setting("render_settings", "static_sun_shadows", val)
        SettingsUtilities.apply_user_settings()
        SettingsUtilities.save_user_settings()
    end
    if id == "sun_shadow_map_size" then
        if val == 4 then
            Application.set_user_setting("render_settings", "sun_shadow_map_size", { 4, 4 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
        if val == 256 then
            Application.set_user_setting("render_settings", "sun_shadow_map_size", { 256, 256 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
        if val == 512 then
            Application.set_user_setting("render_settings", "sun_shadow_map_size", { 512, 512 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
        if val == 1024 then
            Application.set_user_setting("render_settings", "sun_shadow_map_size", { 1024, 1024 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
        if val == 2048 then
            Application.set_user_setting("render_settings", "sun_shadow_map_size", { 2048, 2048 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
    end
    if id == "static_sun_shadow_map_size" then
        if val == 256 then
            Application.set_user_setting("render_settings", "static_sun_shadow_map_size", { 256, 256 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
        if val == 512 then
            Application.set_user_setting("render_settings", "static_sun_shadow_map_size", { 512, 512 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
        if val == 1024 then
            Application.set_user_setting("render_settings", "static_sun_shadow_map_size", { 1024, 1024 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
        if val == 2048 then
            Application.set_user_setting("render_settings", "static_sun_shadow_map_size", { 2048, 2048 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
    end
    if id == "local_lights_shadow_atlas_size" then
        if val == 256 then
            Application.set_user_setting("render_settings", "local_lights_shadow_atlas_size", { 256, 256 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
        if val == 512 then
            Application.set_user_setting("render_settings", "local_lights_shadow_atlas_size", { 512, 512 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
        if val == 1024 then
            Application.set_user_setting("render_settings", "local_lights_shadow_atlas_size", { 1024, 1024 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
        if val == 2048 then
            Application.set_user_setting("render_settings", "local_lights_shadow_atlas_size", { 2048, 2048 })
            SettingsUtilities.apply_user_settings()
            SettingsUtilities.save_user_settings()
        end
    end
    --volumetric_fog_quality
    if id == "Volenabled" then
        Application.set_user_setting("render_settings", "volumetric_volumes_enabled", val)
        SettingsUtilities.apply_user_settings()
        SettingsUtilities.save_user_settings()
    end
    if id == "high_quality" then
        Application.set_user_setting("render_settings", "volumetric_extrapolation_high_quality", val)
        SettingsUtilities.apply_user_settings()
        SettingsUtilities.save_user_settings()
    end
    if id == "volumetric_shadows" then
        Application.set_user_setting("render_settings", "volumetric_extrapolation_volumetric_shadows", val)
        SettingsUtilities.apply_user_settings()
        SettingsUtilities.save_user_settings()
    end
    if id == "light_shafts" then
        Application.set_user_setting("render_settings", "light_shafts_enabled", val)
        SettingsUtilities.apply_user_settings()
        SettingsUtilities.save_user_settings()
    end
    if id == "volumetric_local_lights" then
        Application.set_user_setting("render_settings", "volumetric_lighting_local_lights", val)
        SettingsUtilities.apply_user_settings()
        SettingsUtilities.save_user_settings()
    end
    --global_illumination
    if id == "GIenabled" then
        Application.set_user_setting("render_settings", "baked_ddgi", val)
        SettingsUtilities.apply_user_settings()
        SettingsUtilities.save_user_settings()
    end
    if id == "rtxgi_scale" then
        Application.set_user_setting("render_settings", "rtxgi_scale", val)
        SettingsUtilities.save_user_settings()
    end
    --performance_settings
    if id == "maxragdolls" then
        Application.set_user_setting("performance_settings", "max_ragdolls", val)
        SettingsUtilities.save_user_settings()
    end
    if id == "maximpactdecals" then
        Application.set_user_setting("performance_settings", "max_impact_decals", val)
        SettingsUtilities.save_user_settings()
    end
    if id == "maxblooddecals" then
        Application.set_user_setting("performance_settings", "max_blood_decals", val)
        SettingsUtilities.save_user_settings()
    end
    if id == "decallifetime" then
        Application.set_user_setting("performance_settings", "decal_lifetime", val)
        SettingsUtilities.save_user_settings()
    end
end

mod.apply = function()
    SettingsUtilities.apply_user_settings()
    SettingsUtilities.save_user_settings()
end
