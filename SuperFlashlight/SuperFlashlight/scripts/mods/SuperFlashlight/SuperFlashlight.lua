local mod = get_mod("SuperFlashlight")
local math = require("math")
local radian_factor = 0.017453293

local _flashlight_template = {
    light = {
        first_person = {
            cast_shadows = mod:get("first_person_casts_shadows"),
            color_temperature = mod:get("first_person_color_temperature"),
            ies_profile = mod:get("first_person_ies_profile"),
            intensity = mod:get("first_person_intensity"),
            spot_reflector = mod:get("first_person_spot_reflector"),
            volumetric_intensity = mod:get("first_person_volumetric_intensity"),
            spot_angle = {
                max = mod:get("first_person_spot_angle_max") * radian_factor,
                min = mod:get("first_person_spot_angle_min") * radian_factor,
            },
            falloff = {
                far = mod:get("first_person_falloff_far"),
                near = math.min(mod:get("first_person_falloff_near"), mod:get("first_person_falloff_far")),
            },
        },
        third_person = {
            cast_shadows = mod:get("third_person_casts_shadows"),
            color_temperature = mod:get("third_person_color_temperature"),
            ies_profile = mod:get("third_person_ies_profile"),
            intensity = mod:get("third_person_intensity"),
            spot_reflector = mod:get("third_person_spot_reflector"),
            volumetric_intensity = mod:get("third_person_volumetric_intensity"),
            spot_angle = {
                max = mod:get("third_person_spot_angle_max") * radian_factor,
                min = mod:get("third_person_spot_angle_min") * radian_factor,
            },
            falloff = {
                far = mod:get("third_person_falloff_far"),
                near = math.min(mod:get("third_person_falloff_near"), mod:get("third_person_falloff_far")),
            },
        },
    },
    flicker = {
        chance = mod:get("flicker_chance"),
        fade_out = mod:get("flicker_fade_out"),
        frequence_multiplier = mod:get("flicker_frequence_multiplier"),
        min_octave_percentage = mod:get("flicker_min_octave_percentage"),
        octaves = mod:get("flicker_octaves"),
        persistance = mod:get("flicker_persistance"),
        duration = {
            max = mod:get("flicker_duration_max"),
            min = mod:get("flicker_duration_min"),
        },
        interval = {
            max = mod:get("flicker_interval_max"),
            min = mod:get("flicker_interval_min"),
        },
    },
    battery = {
        max = mod:get("battery_max"),
        interval = .1,
        drain = mod:get("battery_drain"),
        charge = mod:get("battery_charge"),
    }
}

local _fov_light_template = {
    omni = {
        cast_shadows = mod:get("fov_light_omni_casts_shadows"),
        color_temperature = mod:get("fov_light_omni_color_temperature"),
        intensity = mod:get("fov_light_omni_intensity"),
        spot_reflector = mod:get("fov_light_omni_spot_reflector"),
        volumetric_intensity = mod:get("fov_light_omni_volumetric_intensity"),
        falloff = {
            far = mod:get("fov_light_omni_falloff_far"),
            near = math.min(mod:get("fov_light_omni_falloff_near"), mod:get("fov_light_omni_falloff_far")),
        },
    },
    spot = {
        cast_shadows = mod:get("fov_light_spot_casts_shadows"),
        color_temperature = mod:get("fov_light_spot_color_temperature"),
        ies_profile = mod:get("fov_light_spot_ies_profile"),
        intensity = mod:get("fov_light_spot_intensity"),
        spot_reflector = mod:get("fov_light_spot_spot_reflector"),
        volumetric_intensity = mod:get("fov_light_spot_volumetric_intensity"),
        spot_angle = {
            max = mod:get("fov_light_spot_spot_angle_max") * radian_factor,
            min = mod:get("fov_light_spot_spot_angle_min") * radian_factor,
        },
        falloff = {
            far = mod:get("fov_light_spot_falloff_far"),
            near = math.min(mod:get("fov_light_spot_falloff_near"), mod:get("fov_light_spot_falloff_far")),
        },
    }
}

local _enable_fov_light_omni = mod:get("fov_light_omni")
local _enable_fov_light_spot = mod:get("fov_light_spot")

local _flashlight
local _weapon_custom_flashlight
local _first_person_unit

local _set_template = function(flashlights, template)
    for ii = 1, #flashlights do
        local flashlight = flashlights[ii]

        flashlight.component:set_template(flashlight.unit, template)
    end
end

local _reset_fov_light = function()
    if (_enable_fov_light_omni or _enable_fov_light_spot) and _first_person_unit then
        local num_lights = Unit.num_lights(_first_person_unit)
        for ii = 1, num_lights do
            local light = Unit.light(_first_person_unit, ii)
            local type = Light.type(light)
            local settings = _fov_light_template[type]
            if (_enable_fov_light_omni and type == "omni") or (_enable_fov_light_spot and type == "spot") then
                Light.set_correlated_color_temperature(light, settings.color_temperature)
                Light.set_intensity(light, settings.intensity)
                Light.set_volumetric_intensity(light, settings.volumetric_intensity)
                Light.set_casts_shadows(light, settings.cast_shadows)
                Light.set_spot_reflector(light, settings.spot_reflector)
                Light.set_falloff_start(light, settings.falloff.near)
                Light.set_falloff_end(light, settings.falloff.far)
            end

            if _enable_fov_light_spot and type == "spot" then
                Light.set_ies_profile(light, settings.ies_profile)
                Light.set_spot_angle_start(light, settings.spot_angle.min)
                Light.set_spot_angle_end(light, settings.spot_angle.max)
            end
        end
    end
end

local _reset = function()
    if _flashlight then
        _set_template(_flashlight._flashlights_1p, _flashlight._light_settings.first_person)
        _set_template(_flashlight._flashlights_3p, _flashlight._light_settings.third_person)
    end

    if _weapon_custom_flashlight then
        if _weapon_custom_flashlight.has_flashlight and _weapon_custom_flashlight.flashlight_template then
            _weapon_custom_flashlight:set_light_values(_weapon_custom_flashlight.flashlight_unit_1p, _weapon_custom_flashlight.flashlight_template.light.first_person)
            _weapon_custom_flashlight:set_light_values(_weapon_custom_flashlight.flashlight_unit_3p, _weapon_custom_flashlight.flashlight_template.light.third_person)
        end
    end

    _reset_fov_light()
end

mod.on_setting_changed = function(id)
    local value = mod:get(id)
    if id == "first_person_casts_shadows" then
        _flashlight_template.light.first_person.cast_shadows = value
    elseif id == "first_person_spot_reflector" then
        _flashlight_template.light.first_person.spot_reflector = value
    elseif id == "first_person_spot_angle_max" then
        _flashlight_template.light.first_person.spot_angle.max = value * radian_factor
    elseif id == "first_person_spot_angle_min" then
        _flashlight_template.light.first_person.spot_angle.min = value * radian_factor
    elseif id == "first_person_falloff_far" then
        _flashlight_template.light.first_person.falloff.far = value
    elseif id == "first_person_falloff_near" then
        _flashlight_template.light.first_person.falloff.near = value
    elseif id == "first_person_intensity" then
        _flashlight_template.light.first_person.intensity = value
    elseif id == "first_person_volumetric_intensity" then
        _flashlight_template.light.first_person.volumetric_intensity = value
    elseif id == "first_person_color_temperature" then
        _flashlight_template.light.first_person.color_temperature = value
    elseif id == "first_person_ies_profile" then
        _flashlight_template.light.first_person.ies_profile = value
    elseif id == "third_person_casts_shadows" then
        _flashlight_template.light.third_person.cast_shadows = value
    elseif id == "third_person_spot_reflector" then
        _flashlight_template.light.third_person.spot_reflector = value
    elseif id == "third_person_spot_angle_max" then
        _flashlight_template.light.third_person.spot_angle.max = value * radian_factor
    elseif id == "third_person_spot_angle_min" then
        _flashlight_template.light.third_person.spot_angle.min = value * radian_factor
    elseif id == "third_person_falloff_far" then
        _flashlight_template.light.third_person.falloff.far = value
    elseif id == "third_person_falloff_near" then
        _flashlight_template.light.third_person.falloff.near = value
    elseif id == "third_person_intensity" then
        _flashlight_template.light.third_person.intensity = value
    elseif id == "third_person_volumetric_intensity" then
        _flashlight_template.light.third_person.volumetric_intensity = value
    elseif id == "third_person_color_temperature" then
        _flashlight_template.light.third_person.color_temperature = value
    elseif id == "third_person_ies_profile" then
        _flashlight_template.light.third_person.ies_profile = value
    elseif id == "flicker_chance" then
        _flashlight_template.flicker.chance = value
    elseif id == "flicker_fade_out" then
        _flashlight_template.flicker.fade_out = value
    elseif id == "flicker_frequence_multiplier" then
        _flashlight_template.flicker.frequence_multiplier = value
    elseif id == "flicker_min_octave_percentage" then
        _flashlight_template.flicker.min_octave_percentage = value
    elseif id == "flicker_octaves" then
        _flashlight_template.flicker.octaves = value
    elseif id == "flicker_persistance" then
        _flashlight_template.flicker.persistance = value
    elseif id == "flicker_duration_max" then
        _flashlight_template.flicker.duration.max = value
    elseif id == "flicker_duration_min" then
        _flashlight_template.flicker.duration.min = value
    elseif id == "flicker_interval_max" then
        _flashlight_template.flicker.interval.max = value
    elseif id == "flicker_interval_min" then
        _flashlight_template.flicker.interval.min = value
    elseif id == "fov_light_omni_casts_shadows" then
        _fov_light_template.omni.cast_shadows = value
    elseif id == "fov_light_omni_spot_reflector" then
        _fov_light_template.omni.spot_reflector = value
    elseif id == "fov_light_omni_falloff_far" then
        _fov_light_template.omni.falloff.far = value
    elseif id == "fov_light_omni_falloff_near" then
        _fov_light_template.omni.falloff.near = value
    elseif id == "fov_light_omni_intensity" then
        _fov_light_template.omni.intensity = value
    elseif id == "fov_light_omni_volumetric_intensity" then
        _fov_light_template.omni.volumetric_intensity = value
    elseif id == "fov_light_omni_color_temperature" then
        _fov_light_template.omni.color_temperature = value
    elseif id == "fov_light_spot_casts_shadows" then
        _fov_light_template.spot.cast_shadows = value
    elseif id == "fov_light_spot_spot_reflector" then
        _fov_light_template.spot.spot_reflector = value
    elseif id == "fov_light_spot_spot_angle_max" then
        _fov_light_template.spot.spot_angle.max = value * radian_factor
    elseif id == "fov_light_spot_spot_angle_min" then
        _fov_light_template.spot.spot_angle.min = value * radian_factor
    elseif id == "fov_light_spot_falloff_far" then
        _fov_light_template.spot.falloff.far = value
    elseif id == "fov_light_spot_falloff_near" then
        _fov_light_template.spot.falloff.near = value
    elseif id == "fov_light_spot_intensity" then
        _fov_light_template.spot.intensity = value
    elseif id == "fov_light_spot_volumetric_intensity" then
        _fov_light_template.spot.volumetric_intensity = value
    elseif id == "fov_light_spot_color_temperature" then
        _fov_light_template.spot.color_temperature = value
    elseif id == "fov_light_spot_ies_profile" then
        _fov_light_template.spot.ies_profile = value
    elseif id == "fov_light_omni" then
        _enable_fov_light_omni = value
    elseif id == "fov_light_spot" then
        _enable_fov_light_spot = value
    end

    if _flashlight_template.light.first_person.falloff.far < _flashlight_template.light.first_person.falloff.near then
        _flashlight_template.light.first_person.falloff.near = _flashlight_template.light.first_person.falloff.far
        mod:set("first_person_falloff_near", _flashlight_template.light.first_person.falloff.near, false)
    end
    if _flashlight_template.light.third_person.falloff.far < _flashlight_template.light.third_person.falloff.near then
        _flashlight_template.light.third_person.falloff.near = _flashlight_template.light.third_person.falloff.far
        mod:set("third_person_falloff_near", _flashlight_template.light.third_person.falloff.near, false)
    end
    if _fov_light_template.omni.falloff.far < _fov_light_template.omni.falloff.near then
        _fov_light_template.omni.falloff.near = _fov_light_template.omni.falloff.far
        mod:set("fov_light_omni_falloff_near", _fov_light_template.omni.falloff.near, false)
    end
    if _fov_light_template.spot.falloff.far < _fov_light_template.spot.falloff.near then
        _fov_light_template.spot.falloff.near = _fov_light_template.spot.falloff.far
        mod:set("fov_light_spot_falloff_near", _fov_light_template.spot.falloff.near, false)
    end

    _reset()
end

mod:hook(CLASS.Flashlight, "init", function(func, self, context, slot, weapon_template, ...)
    _flashlight = self
    weapon_template.flashlight_template = _flashlight_template
    return func(self, context, slot, weapon_template, ...)
end)

mod:hook_safe(CLASS.Flashlight, "destroy", function(...)
    _flashlight = nil
end)

mod:hook_safe(CLASS.FirstPersonAnimationCamera, "set_root_unit", function(self, unit, object)
    _first_person_unit = self._first_person_unit
    _reset_fov_light()
end)

mod:hook_safe(CLASS.FirstPersonAnimationCamera, "destroy", function(self)
    _first_person_unit = nil
end)

mod.on_all_mods_loaded = function()
    local wc = get_mod("weapon_customization")
    if wc then
        for k, _ in pairs(wc.flashlight_templates) do
            wc.flashlight_templates[k] = _flashlight_template
        end

        mod:hook_safe(CLASS.FlashlightExtension, "init", function(self, ...)
            _weapon_custom_flashlight = self
        end)

        mod:hook_safe(CLASS.FlashlightExtension, "delete", function(...)
            _weapon_custom_flashlight = nil
        end)
    end
end