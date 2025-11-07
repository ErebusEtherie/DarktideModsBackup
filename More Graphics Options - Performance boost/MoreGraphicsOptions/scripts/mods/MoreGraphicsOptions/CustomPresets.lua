return {
    textureOptions = {
        {
            id = "very_low",
            display_name = "loc_settings_menu_very_low",
            require_apply = true,
            require_restart = true,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                texture_settings = {
                    ["content/texture_categories/character_nm"] = 3,
                    ["content/texture_categories/weapon_bc"] = 3,
                    ["content/texture_categories/weapon_bca"] = 3,
                    ["content/texture_categories/environment_bc"] = 3,
                    ["content/texture_categories/character_mask"] = 3,
                    ["content/texture_categories/character_orm"] = 3,
                    ["content/texture_categories/character_bc"] = 3,
                    ["content/texture_categories/environment_hm"] = 3,
                    ["content/texture_categories/character_mask2"] = 3,
                    ["content/texture_categories/environment_orm"] = 3,
                    ["content/texture_categories/character_bcm"] = 3,
                    ["content/texture_categories/character_bca"] = 3,
                    ["content/texture_categories/weapon_nm"] = 3,
                    ["content/texture_categories/environment_bca"] = 3,
                    ["content/texture_categories/environment_nm"] = 3,
                    ["content/texture_categories/character_hm"] = 3,
                    ["content/texture_categories/weapon_hm"] = 3,
                    ["content/texture_categories/weapon_mask"] = 3,
                    ["content/texture_categories/weapon_orm"] = 3
                }
            }
        },
        {
            id = "low",
            display_name = "loc_settings_menu_low",
            require_apply = true,
            require_restart = true,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                texture_settings = {
                    ["content/texture_categories/character_nm"] = 2,
                    ["content/texture_categories/weapon_bc"] = 2,
                    ["content/texture_categories/weapon_bca"] = 2,
                    ["content/texture_categories/environment_bc"] = 2,
                    ["content/texture_categories/character_mask"] = 2,
                    ["content/texture_categories/character_orm"] = 2,
                    ["content/texture_categories/character_bc"] = 2,
                    ["content/texture_categories/environment_hm"] = 2,
                    ["content/texture_categories/character_mask2"] = 2,
                    ["content/texture_categories/environment_orm"] = 2,
                    ["content/texture_categories/character_bcm"] = 2,
                    ["content/texture_categories/character_bca"] = 2,
                    ["content/texture_categories/weapon_nm"] = 2,
                    ["content/texture_categories/environment_bca"] = 2,
                    ["content/texture_categories/environment_nm"] = 2,
                    ["content/texture_categories/character_hm"] = 2,
                    ["content/texture_categories/weapon_hm"] = 2,
                    ["content/texture_categories/weapon_mask"] = 2,
                    ["content/texture_categories/weapon_orm"] = 2
                }
            }
        },
        {
            id = "medium",
            display_name = "loc_settings_menu_medium",
            require_apply = true,
            require_restart = true,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                texture_settings = {
                    ["content/texture_categories/character_nm"] = 1,
                    ["content/texture_categories/weapon_bc"] = 1,
                    ["content/texture_categories/weapon_bca"] = 1,
                    ["content/texture_categories/environment_bc"] = 1,
                    ["content/texture_categories/character_mask"] = 1,
                    ["content/texture_categories/character_orm"] = 1,
                    ["content/texture_categories/character_bc"] = 1,
                    ["content/texture_categories/environment_hm"] = 1,
                    ["content/texture_categories/character_mask2"] = 1,
                    ["content/texture_categories/environment_orm"] = 1,
                    ["content/texture_categories/character_bcm"] = 1,
                    ["content/texture_categories/character_bca"] = 1,
                    ["content/texture_categories/weapon_nm"] = 1,
                    ["content/texture_categories/environment_bca"] = 1,
                    ["content/texture_categories/environment_nm"] = 1,
                    ["content/texture_categories/character_hm"] = 1,
                    ["content/texture_categories/weapon_hm"] = 1,
                    ["content/texture_categories/weapon_mask"] = 1,
                    ["content/texture_categories/weapon_orm"] = 1
                }
            }
        },
        {
            id = "high",
            display_name = "loc_settings_menu_high",
            require_apply = true,
            require_restart = true,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                texture_settings = {
                    ["content/texture_categories/character_nm"] = 0,
                    ["content/texture_categories/weapon_bc"] = 0,
                    ["content/texture_categories/weapon_bca"] = 0,
                    ["content/texture_categories/environment_bc"] = 0,
                    ["content/texture_categories/character_mask"] = 0,
                    ["content/texture_categories/character_orm"] = 0,
                    ["content/texture_categories/character_bc"] = 0,
                    ["content/texture_categories/environment_hm"] = 0,
                    ["content/texture_categories/character_mask2"] = 0,
                    ["content/texture_categories/environment_orm"] = 0,
                    ["content/texture_categories/character_bcm"] = 0,
                    ["content/texture_categories/character_bca"] = 0,
                    ["content/texture_categories/weapon_nm"] = 0,
                    ["content/texture_categories/environment_bca"] = 0,
                    ["content/texture_categories/environment_nm"] = 0,
                    ["content/texture_categories/character_hm"] = 0,
                    ["content/texture_categories/weapon_hm"] = 0,
                    ["content/texture_categories/weapon_mask"] = 0,
                    ["content/texture_categories/weapon_orm"] = 0
                }
            }
        }
    },

    volFogOptions = {
        {
            id = "off",
            display_name = "loc_settings_menu_off",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    volumetric_extrapolation_volumetric_shadows = false,
                    volumetric_extrapolation_high_quality = false,
                    volumetric_volumes_enabled = false,
                    volumetric_reprojection_amount = 0.875,
                    light_shafts_enabled = false,
                    volumetric_lighting_local_lights = false,
                    volumetric_data_size = {
                        80,
                        64,
                        96
                    }
                }
            }
        },
        {
            id = "low",
            display_name = "loc_settings_menu_low",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    volumetric_extrapolation_volumetric_shadows = false,
                    volumetric_extrapolation_high_quality = false,
                    volumetric_volumes_enabled = true,
                    volumetric_reprojection_amount = 0.875,
                    light_shafts_enabled = false,
                    volumetric_lighting_local_lights = false,
                    volumetric_data_size = {
                        80,
                        64,
                        96
                    }
                }
            }
        },
        {
            id = "medium",
            display_name = "loc_settings_menu_medium",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    volumetric_extrapolation_volumetric_shadows = false,
                    volumetric_extrapolation_high_quality = true,
                    volumetric_volumes_enabled = true,
                    volumetric_reprojection_amount = 0.625,
                    light_shafts_enabled = true,
                    volumetric_lighting_local_lights = true,
                    volumetric_data_size = {
                        96,
                        80,
                        128
                    }
                }
            }
        },
        {
            id = "high",
            display_name = "loc_settings_menu_high",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    volumetric_extrapolation_volumetric_shadows = false,
                    volumetric_extrapolation_high_quality = true,
                    volumetric_volumes_enabled = true,
                    volumetric_reprojection_amount = 0,
                    light_shafts_enabled = true,
                    volumetric_lighting_local_lights = true,
                    volumetric_data_size = {
                        128,
                        96,
                        160
                    }
                }
            }
        },
        {
            id = "extreme",
            display_name = "loc_settings_menu_extreme",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    volumetric_extrapolation_volumetric_shadows = true,
                    volumetric_extrapolation_high_quality = true,
                    volumetric_volumes_enabled = true,
                    volumetric_reprojection_amount = -0.875,
                    light_shafts_enabled = true,
                    volumetric_lighting_local_lights = true,
                    volumetric_data_size = {
                        144,
                        112,
                        196
                    }
                }
            }
        }
    },

    giOptions = {
        {
            id = "off",
            display_name = "loc_settings_menu_off",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    rtxgi_scale = 0.0,
                    baked_ddgi = false
                }
            }
        },
        {
            id = "very_low",
            display_name = "loc_settings_menu_very_low",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    rtxgi_scale = 0.25,
                    baked_ddgi = true
                }
            }
        },
        {
            id = "low",
            display_name = "loc_settings_menu_low",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    rtxgi_scale = 0.5,
                    baked_ddgi = true
                }
            }
        },
        {
            id = "high",
            display_name = "loc_settings_menu_high",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    rtxgi_scale = 1,
                    baked_ddgi = true
                }
            }
        }
    },

    lightOptions = {
        {
            id = "off",
            display_name = "loc_settings_menu_off",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    local_lights_shadow_map_filter_quality = "low",
                    sun_shadows = false,
                    local_lights_max_dynamic_shadow_distance = 50,
                    local_lights_max_non_shadow_casting_distance = 0,
                    local_lights_max_static_shadow_distance = 100,
                    local_lights_shadows_enabled = false,
                    sun_shadow_map_filter_quality = "low",
                    static_sun_shadows = false,
                    sun_shadow_map_size = {
                        4,
                        4
                    },
                    static_sun_shadow_map_size = {
                        512,
                        512
                    },
                    local_lights_shadow_atlas_size = {
                        512,
                        512
                    }
                }
            }
        },
        {
            id = "very_low",
            display_name = "loc_settings_menu_very_low",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    local_lights_shadow_map_filter_quality = "low",
                    sun_shadows = false,
                    local_lights_max_dynamic_shadow_distance = 50,
                    local_lights_max_non_shadow_casting_distance = 0,
                    local_lights_max_static_shadow_distance = 100,
                    local_lights_shadows_enabled = false,
                    sun_shadow_map_filter_quality = "low",
                    static_sun_shadows = true,
                    sun_shadow_map_size = {
                        4,
                        4
                    },
                    static_sun_shadow_map_size = {
                        1024,
                        1024
                    },
                    local_lights_shadow_atlas_size = {
                        512,
                        512
                    }
                }
            }
        },
        {
            id = "low",
            display_name = "loc_settings_menu_low",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    local_lights_shadow_map_filter_quality = "low",
                    sun_shadows = false,
                    local_lights_max_dynamic_shadow_distance = 50,
                    local_lights_max_non_shadow_casting_distance = 0,
                    local_lights_max_static_shadow_distance = 100,
                    local_lights_shadows_enabled = true,
                    sun_shadow_map_filter_quality = "low",
                    static_sun_shadows = true,
                    sun_shadow_map_size = {
                        4,
                        4
                    },
                    static_sun_shadow_map_size = {
                        2048,
                        2048
                    },
                    local_lights_shadow_atlas_size = {
                        512,
                        512
                    }
                }
            }
        },
        {
            id = "medium",
            display_name = "loc_settings_menu_medium",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    local_lights_shadow_map_filter_quality = "low",
                    sun_shadows = true,
                    local_lights_max_dynamic_shadow_distance = 50,
                    local_lights_max_non_shadow_casting_distance = 0,
                    local_lights_max_static_shadow_distance = 100,
                    local_lights_shadows_enabled = true,
                    sun_shadow_map_filter_quality = "medium",
                    static_sun_shadows = true,
                    sun_shadow_map_size = {
                        2048,
                        2048
                    },
                    static_sun_shadow_map_size = {
                        2048,
                        2048
                    },
                    local_lights_shadow_atlas_size = {
                        1024,
                        1024
                    }
                }
            }
        },
        {
            id = "high",
            display_name = "loc_settings_menu_high",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    local_lights_shadow_map_filter_quality = "high",
                    sun_shadows = true,
                    local_lights_max_dynamic_shadow_distance = 50,
                    local_lights_max_non_shadow_casting_distance = 0,
                    local_lights_max_static_shadow_distance = 100,
                    local_lights_shadows_enabled = true,
                    sun_shadow_map_filter_quality = "high",
                    static_sun_shadows = true,
                    sun_shadow_map_size = {
                        2048,
                        2048
                    },
                    static_sun_shadow_map_size = {
                        2048,
                        2048
                    },
                    local_lights_shadow_atlas_size = {
                        2048,
                        2048
                    }
                }
            }
        },
        {
            id = "extreme",
            display_name = "loc_settings_menu_extreme",
            require_apply = true,
            require_restart = false,
            apply_values_on_edited = {
                graphics_quality = "custom"
            },
            values = {
                render_settings = {
                    local_lights_shadow_map_filter_quality = "high",
                    sun_shadows = true,
                    local_lights_max_dynamic_shadow_distance = 50,
                    local_lights_max_non_shadow_casting_distance = 0,
                    local_lights_max_static_shadow_distance = 100,
                    local_lights_shadows_enabled = true,
                    sun_shadow_map_filter_quality = "high",
                    static_sun_shadows = true,
                    sun_shadow_map_size = {
                        2048,
                        2048
                    },
                    static_sun_shadow_map_size = {
                        2048,
                        2048
                    },
                    local_lights_shadow_atlas_size = {
                        4096,
                        4096
                    }
                }
            }
        }
    }
}
