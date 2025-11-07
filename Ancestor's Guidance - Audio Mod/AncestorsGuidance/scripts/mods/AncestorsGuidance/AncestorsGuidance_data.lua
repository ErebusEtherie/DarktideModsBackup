local mod = get_mod("AncestorsGuidance")

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "master_volume",
                type = "numeric",
                tooltip = "master_volume_description",
                default_value = 100,
                range = {0, 100},
                decimals_number = 0,
                callback = "apply_master_volume"
            },
            {
                setting_id = "medicae_keybinds_group",
                type = "group",
                title = "medicae_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_medicae_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "medicae_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "medicae_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "medicae_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "armoury_keybinds_group",
                type = "group",
                title = "armoury_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_armoury_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "armoury_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "armoury_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "armoury_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "crafting_keybinds_group",
                type = "group",
                title = "crafting_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_crafting_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "crafting_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "crafting_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "crafting_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "sefoni_keybinds_group",
                type = "group",
                title = "sefoni_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_sefoni_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "sefoni_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "sefoni_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "sefoni_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "contract_keybinds_group",
                type = "group",
                title = "contract_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_contract_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "contract_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "contract_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "contract_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "penance_keybinds_group",
                type = "group",
                title = "penance_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_penance_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "penance_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "penance_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "penance_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "commodore_keybinds_group",
                type = "group",
                title = "commodore_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_commodore_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "commodore_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "commodore_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "commodore_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "barber_keybinds_group",
                type = "group",
                title = "barber_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_barber_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "barber_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "barber_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "barber_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "commissar_keybinds_group",
                type = "group",
                title = "commissar_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_commissar_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "commissar_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "commissar_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "commissar_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "boss_keybinds_group",
                type = "group",
                title = "boss_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_boss_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "boss_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "boss_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "boss_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "horde_keybinds_group",
                type = "group",
                title = "horde_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_horde_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "horde_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "horde_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "horde_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "kill_keybinds_group",
                type = "group",
                title = "kill_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_kill_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "kill_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "kill_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "kill_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "intro_keybinds_group",
                type = "group",
                title = "intro_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_intro_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "intro_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "intro_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "intro_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "character_select_keybinds_group",
                type = "group",
                title = "character_select_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_character_select_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "character_select_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "character_select_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "character_select_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "chest_keybinds_group",
                type = "group",
                title = "chest_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_chest_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "chest_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "chest_chance",
                                type = "numeric",
                                default_value = 5,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "chest_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "teammate_died_keybinds_group",
                type = "group",
                title = "teammate_died_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_teammate_died_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "teammate_died_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "teammate_died_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "teammate_died_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "teammate_downed_keybinds_group",
                type = "group",
                title = "teammate_downed_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_teammate_downed_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "teammate_downed_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "teammate_downed_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "teammate_downed_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "mortis_trials_keybinds_group",
                type = "group",
                title = "mortis_trials_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_mortis_trials_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "mortis_trials_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "mortis_trials_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "mortis_trials_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "defeat_keybinds_group",
                type = "group",
                title = "defeat_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_defeat_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "defeat_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "defeat_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "defeat_chance_description",
                            }
                        }
                    }
                }
            },
            {
                setting_id = "victory_keybinds_group",
                type = "group",
                title = "victory_keybinds_title",
                sub_widgets = {
                    {
                        setting_id = "enable_victory_sounds",
                        type = "checkbox",
                        default_value = true,
                        sub_widgets = {
                            {
                                setting_id = "victory_volume",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                decimals_number = 0,
                            },
                            {
                                setting_id = "victory_chance",
                                type = "numeric",
                                default_value = 100,
                                range = {1, 100},
                                decimals_number = 0,
                                tooltip = "victory_chance_description",
                            }
                        }
                    }
                }
            },
        }
    }
}