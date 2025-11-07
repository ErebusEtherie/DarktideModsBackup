local mod = get_mod("SuperFlashlight")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,
    options = {
        widgets = {
            {
                setting_id = "first_person",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "first_person_casts_shadows",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "first_person_spot_reflector",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "first_person_spot_angle_max",
                        type = "numeric",
                        default_value = 90,
                        range = { 0, 179 },
                        unit_text = "°",
                        decimals_number = 2
                    },
                    {
                        setting_id = "first_person_spot_angle_min",
                        type = "numeric",
                        default_value = 90,
                        range = { 0, 179 },
                        unit_text = "°",
                        decimals_number = 2
                    },
                    {
                        setting_id = "first_person_falloff_far",
                        type = "numeric",
                        default_value = 200,
                        range = { 0, 300 },
                        decimals_number = 2
                    },
                    {
                        setting_id = "first_person_falloff_near",
                        type = "numeric",
                        default_value = 200,
                        range = { 0, 300 },
                        decimals_number = 2
                    },
                    {
                        setting_id = "first_person_intensity",
                        type = "numeric",
                        default_value = 2,
                        range = { 0, 20 },
                        decimals_number = 2
                    },
                    {
                        setting_id = "first_person_volumetric_intensity",
                        type = "numeric",
                        default_value = 0,
                        range = { 0, 1 },
                        decimals_number = 4
                    },
                    {
                        setting_id = "first_person_color_temperature",
                        type = "numeric",
                        default_value = 8000,
                        range = { 0, 10000 },
                        decimals_number = 0
                    },
                    {
                        setting_id = "first_person_ies_profile",
                        type = "dropdown",
                        default_value = "",
                        options = {
                            { text = "none", value = "" },
                            { text = "custom_01", value = "content/environment/ies_profiles/narrow/flashlight_custom_01" },
                            { text = "custom_02", value = "content/environment/ies_profiles/narrow/flashlight_custom_02" },
                            { text = "custom_03", value = "content/environment/ies_profiles/narrow/flashlight_custom_03" },
                            { text = "narrow_05", value = "content/environment/ies_profiles/narrow/narrow_05" }
                        },
                    },
                }
            },
            {
                setting_id = "third_person",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "third_person_casts_shadows",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "third_person_spot_reflector",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "third_person_spot_angle_max",
                        type = "numeric",
                        default_value = 45.84,
                        range = { 0, 179 },
                        unit_text = "°",
                        decimals_number = 2
                    },
                    {
                        setting_id = "third_person_spot_angle_min",
                        type = "numeric",
                        default_value = 0,
                        range = { 0, 179 },
                        unit_text = "°",
                        decimals_number = 2
                    },
                    {
                        setting_id = "third_person_falloff_far",
                        type = "numeric",
                        default_value = 30,
                        range = { 0, 300 },
                        decimals_number = 2
                    },
                    {
                        setting_id = "third_person_falloff_near",
                        type = "numeric",
                        default_value = 0,
                        range = { 0, 300 },
                        decimals_number = 2
                    },
                    {
                        setting_id = "third_person_intensity",
                        type = "numeric",
                        default_value = 12,
                        range = { 0, 20 },
                        decimals_number = 2
                    },
                    {
                        setting_id = "third_person_volumetric_intensity",
                        type = "numeric",
                        default_value = 0.6,
                        range = { 0, 1 },
                        decimals_number = 4
                    },
                    {
                        setting_id = "third_person_color_temperature",
                        type = "numeric",
                        default_value = 8000,
                        range = { 0, 10000 },
                        decimals_number = 0
                    },
                    {
                        setting_id = "third_person_ies_profile",
                        type = "dropdown",
                        default_value = "content/environment/ies_profiles/narrow/flashlight_custom_02",
                        options = {
                            { text = "none", value = "" },
                            { text = "custom_01", value = "content/environment/ies_profiles/narrow/flashlight_custom_01" },
                            { text = "custom_02", value = "content/environment/ies_profiles/narrow/flashlight_custom_02" },
                            { text = "custom_03", value = "content/environment/ies_profiles/narrow/flashlight_custom_03" },
                            { text = "narrow_05", value = "content/environment/ies_profiles/narrow/narrow_05" }
                        },
                    },
                }
            },
            {
                setting_id = "flicker",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "flicker_chance",
                        type = "numeric",
                        default_value = 0,
                        range = { 0, 1 },
                        decimals_number = 4
                    },
                    {
                        setting_id = "flicker_fade_out",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "flicker_frequence_multiplier",
                        type = "numeric",
                        default_value = 2,
                        range = { 0, 10 },
                        decimals_number = 0
                    },
                    {
                        setting_id = "flicker_min_octave_percentage",
                        type = "numeric",
                        default_value = 0.25,
                        range = { 0, 1 },
                        decimals_number = 4
                    },
                    {
                        setting_id = "flicker_octaves",
                        type = "numeric",
                        default_value = 8,
                        range = { 0, 10 },
                        decimals_number = 0
                    },
                    {
                        setting_id = "flicker_persistance",
                        type = "numeric",
                        default_value = 3,
                        range = { 0, 10 },
                        decimals_number = 0
                    },
                    {
                        setting_id = "flicker_duration_max",
                        type = "numeric",
                        default_value = 3,
                        range = { 0, 20 },
                        decimals_number = 0
                    },
                    {
                        setting_id = "flicker_duration_min",
                        type = "numeric",
                        default_value = 2,
                        range = { 0, 20 },
                        decimals_number = 0
                    },
                    {
                        setting_id = "flicker_interval_max",
                        type = "numeric",
                        default_value = 30,
                        range = { 0, 100 },
                        decimals_number = 0
                    },
                    {
                        setting_id = "flicker_interval_min",
                        type = "numeric",
                        default_value = 15,
                        range = { 0, 100 },
                        decimals_number = 0
                    },
                }
            },
            {
                setting_id = "battery",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "battery_max",
                        type = "numeric",
                        default_value = 10,
                        range = { 0, 100 },
                        decimals_number = 0
                    },
                    {
                        setting_id = "battery_drain",
                        type = "numeric",
                        default_value = 0.002,
                        range = { 0, 1 },
                        decimals_number = 4
                    },
                    {
                        setting_id = "battery_charge",
                        type = "numeric",
                        default_value = 0.004,
                        range = { 0, 1 },
                        decimals_number = 4
                    },
                }
            },
            {
                setting_id = "fov_light",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "fov_light_omni",
                        type = "checkbox",
                        default_value = false,
                        sub_widgets = {
                            {
                                setting_id = "fov_light_omni_casts_shadows",
                                type = "checkbox",
                                default_value = true,
                            },
                            {
                                setting_id = "fov_light_omni_spot_reflector",
                                type = "checkbox",
                                default_value = false,
                            },
                            {
                                setting_id = "fov_light_omni_falloff_far",
                                type = "numeric",
                                default_value = 250,
                                range = { 0, 1000 },
                                decimals_number = 2
                            },
                            {
                                setting_id = "fov_light_omni_falloff_near",
                                type = "numeric",
                                default_value = 250,
                                range = { 0, 1000 },
                                decimals_number = 2
                            },
                            {
                                setting_id = "fov_light_omni_intensity",
                                type = "numeric",
                                default_value = 7.5,
                                range = { 0, 20 },
                                decimals_number = 2
                            },
                            {
                                setting_id = "fov_light_omni_volumetric_intensity",
                                type = "numeric",
                                default_value = 0,
                                range = { 0, 1 },
                                decimals_number = 4
                            },
                            {
                                setting_id = "fov_light_omni_color_temperature",
                                type = "numeric",
                                default_value = 8000,
                                range = { 0, 10000 },
                                decimals_number = 0
                            },
                        }
                    },
                    {
                        setting_id = "fov_light_spot",
                        type = "checkbox",
                        default_value = false,
                        sub_widgets = {
                            {
                                setting_id = "fov_light_spot_casts_shadows",
                                type = "checkbox",
                                default_value = true,
                            },
                            {
                                setting_id = "fov_light_spot_spot_reflector",
                                type = "checkbox",
                                default_value = false,
                            },
                            {
                                setting_id = "fov_light_spot_spot_angle_max",
                                type = "numeric",
                                default_value = 90,
                                range = { 0, 179 },
                                unit_text = "°",
                                decimals_number = 2
                            },
                            {
                                setting_id = "fov_light_spot_spot_angle_min",
                                type = "numeric",
                                default_value = 90,
                                range = { 0, 179 },
                                unit_text = "°",
                                decimals_number = 2
                            },
                            {
                                setting_id = "fov_light_spot_falloff_far",
                                type = "numeric",
                                default_value = 200,
                                range = { 0, 300 },
                                decimals_number = 2
                            },
                            {
                                setting_id = "fov_light_spot_falloff_near",
                                type = "numeric",
                                default_value = 200,
                                range = { 0, 300 },
                                decimals_number = 2
                            },
                            {
                                setting_id = "fov_light_spot_intensity",
                                type = "numeric",
                                default_value = 2,
                                range = { 0, 20 },
                                decimals_number = 2
                            },
                            {
                                setting_id = "fov_light_spot_volumetric_intensity",
                                type = "numeric",
                                default_value = 0,
                                range = { 0, 1 },
                                decimals_number = 4
                            },
                            {
                                setting_id = "fov_light_spot_color_temperature",
                                type = "numeric",
                                default_value = 8000,
                                range = { 0, 10000 },
                                decimals_number = 0
                            },
                            {
                                setting_id = "fov_light_spot_ies_profile",
                                type = "dropdown",
                                default_value = "",
                                options = {
                                    { text = "none", value = "" },
                                    { text = "custom_01", value = "content/environment/ies_profiles/narrow/flashlight_custom_01" },
                                    { text = "custom_02", value = "content/environment/ies_profiles/narrow/flashlight_custom_02" },
                                    { text = "custom_03", value = "content/environment/ies_profiles/narrow/flashlight_custom_03" },
                                    { text = "narrow_05", value = "content/environment/ies_profiles/narrow/narrow_05" }
                                },
                            },
                        }
                    }
                }
            }
        }
    }
}
