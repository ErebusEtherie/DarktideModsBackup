local mod = get_mod("improved_scoreboard_panel")

-- ============================================================
-- MOD CONFIGURATION DATA (DMF OPTIONS MENU SCHEMA)
-- Defines the settings UI structure for the DMF (Darktide Mod
-- Framework) options menu. Each group and widget maps directly
-- to a section in the mod's settings panel.
-- ============================================================

return {
    name = mod:localize("mod_name"),
    description = mod:localize("mod_description"),
    is_togglable = false,
    allow_rehooking = false,
    options = {
        widgets = {
            -- Group 1: General Settings
            -- Controls for basic mod behavior: whether to show the overlay during missions, at the end screen, and whether to enable colored player name styling.
            {
                setting_id = "general_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "show_in_mission",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "show_in_mission_tooltip",
                    },
                    {
                        setting_id = "show_at_mission_end",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "show_at_mission_end_tooltip",
                    },
                    {
                        setting_id = "mod_name_pizazz_toggle",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "mod_name_pizazz_tooltip",
                    },
                    {
                        setting_id = "minimal_stat_labels",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "minimal_stat_labels_tooltip",
                    },
                    {
                        setting_id = "ranked_mode",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "ranked_mode_tooltip",
                    },
                    {
                        setting_id = "solo_mode_tab",
                        type = "checkbox",
                        default_value = false,
                        tooltip = "solo_mode_tab_tooltip",
                    },
                },
            },
            -- Group 2: Layout Settings
            -- Controls for positioning and sizing the scoreboard cards: panel alignment (left or right edge), card width, X/Y offsets for both mission-end and tactical overlay, and spacing between rows.
            {
                setting_id = "layout_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "panel_alignment",
                        type = "dropdown",
                        default_value = "align_left",
                        options = {
                            { text = "align_left", value = "align_left" },
                            { text = "align_right", value = "align_right" },
                        },
                    },
                    {
                        setting_id = "box_width",
                        type = "numeric",
                        default_value = 200,
                        range = { 120, 500 },
                        decimals_number = 0,
                        unit_text = "px",
                    },
                    {
                        setting_id = "box_offset_x",
                        type = "numeric",
                        default_value = 0,
                        range = { -500, 500 },
                        decimals_number = 0,
                        unit_text = "px",
                    },
                    {
                        setting_id = "box_offset_y",
                        type = "numeric",
                        default_value = 0,
                        range = { -500, 500 },
                        decimals_number = 0,
                        unit_text = "px",
                    },
                    {
                        setting_id = "tactical_offset_x",
                        type = "numeric",
                        default_value = 0,
                        range = { -500, 500 },
                        decimals_number = 0,
                        unit_text = "px",
                    },
                    {
                        setting_id = "tactical_offset_y",
                        type = "numeric",
                        default_value = 0,
                        range = { -500, 500 },
                        decimals_number = 0,
                        unit_text = "px",
                    },
                    {
                        setting_id = "row_spacing",
                        type = "numeric",
                        default_value = 10,
                        range = { 1, 30 },
                        decimals_number = 0,
                        unit_text = "px",
                    },
                },
            },
            -- Group 3: Display Settings
            -- Controls for visual appearance: background box opacity for both mission-end and tactical overlay, text scaling percentages, and RGB color pickers for the highscore highlight and stat label text colors.
            {
                setting_id = "display_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "box_opacity_mission",
                        type = "numeric",
                        default_value = 255,
                        range = { 0, 255 },
                        decimals_number = 0,
                    },
                    {
                        setting_id = "box_opacity_tactical",
                        type = "numeric",
                        default_value = 255,
                        range = { 0, 255 },
                        decimals_number = 0,
                    },
                    {
                        setting_id = "text_scale_mission",
                        type = "numeric",
                        default_value = 90,
                        range = { 50, 150 },
                        decimals_number = 0,
                        unit_text = "%",
                    },
                    {
                        setting_id = "text_scale_tactical",
                        type = "numeric",
                        default_value = 90,
                        range = { 50, 150 },
                        decimals_number = 0,
                        unit_text = "%",
                    },
                    -- Highscore Text Color sub-group
                    {
                        setting_id = "highscore_text_color",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "highscore_color_r",
                                type = "numeric",
                                default_value = 0,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                            {
                                setting_id = "highscore_color_g",
                                type = "numeric",
                                default_value = 255,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                            {
                                setting_id = "highscore_color_b",
                                type = "numeric",
                                default_value = 0,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                        },
                    },
                    -- Stat Label Color sub-group
                    {
                        setting_id = "stat_label_color",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "stat_label_color_r",
                                type = "numeric",
                                default_value = 255,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                            {
                                setting_id = "stat_label_color_g",
                                type = "numeric",
                                default_value = 255,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                            {
                                setting_id = "stat_label_color_b",
                                type = "numeric",
                                default_value = 255,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                        },
                    },
                },
            },
            -- Group 4: Tracked Stats
            -- Individual toggles for each tracked statistic. Each checkbox controls whether that stat column appears on the scoreboard. All are enabled by default.
            {
                setting_id = "tracked_stats",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "track_stat_kills",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "track_stat_kills_tooltip",
                    },
                    {
                        setting_id = "track_stat_ranged_kills",
                        type = "checkbox",
                        default_value = false,
                        tooltip = "track_stat_ranged_kills_tooltip",
                    },
                    {
                        setting_id = "track_stat_melee_kills",
                        type = "checkbox",
                        default_value = false,
                        tooltip = "track_stat_melee_kills_tooltip",
                    },
                    {
                        setting_id = "track_stat_headshots",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "track_stat_headshots_tooltip",
                    },
                    {
                        setting_id = "track_stat_dmg_dealt",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "track_stat_dmg_dealt_tooltip",
                    },
                    {
                        setting_id = "track_stat_dmg_taken",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "track_stat_dmg_taken_tooltip",
                    },
                    {
                        setting_id = "track_stat_specials",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "track_stat_specials_tooltip",
                    },
                    {
                        setting_id = "track_stat_elites",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "track_stat_elites_tooltip",
                    },
                    {
                        setting_id = "track_stat_bosses",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "track_stat_bosses_tooltip",
                    },
                    {
                        setting_id = "track_stat_boss_damage",
                        type = "checkbox",
                        default_value = false,
                        tooltip = "track_stat_boss_damage_tooltip",
                    },
                    {
                        setting_id = "track_stat_revives",
                        type = "checkbox",
                        default_value = true,
                        tooltip = "track_stat_revives_tooltip",
                    },
                    {
                        setting_id = "track_stat_rescues",
                        type = "checkbox",
                        default_value = false,
                        tooltip = "track_stat_rescues_tooltip",
                    },
                    {
                        setting_id = "track_stat_relics",
                        type = "checkbox",
                        default_value = false,
                        tooltip = "track_stat_relics_tooltip",
                    },
                    {
                        setting_id = "track_stat_barrels_exploded",
                        type = "checkbox",
                        default_value = false,
                        tooltip = "track_stat_barrels_exploded_tooltip",
                    },
                },
            },
            -- Group 5: Graph Data
            -- A GitHub-style contributions grid that visualizes the local player's highscore history across missions. Each square represents one mission, colored by performance tier. Data persists to disk.
            {
                setting_id = "graph_data",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "graph_disable",
                        type = "checkbox",
                        default_value = false,
                        tooltip = "graph_disable_tooltip",
                    },
                    {
                        setting_id = "graph_per_character",
                        type = "checkbox",
                        default_value = false,
                        tooltip = "graph_per_character_tooltip",
                    },
                    {
                        setting_id = "graph_keybind",
                        type = "keybind",
                        default_value = { "f5" },
                        keybind_global = true,
                        keybind_trigger = "pressed",
                        keybind_type = "function_call",
                        function_name = "toggle_scoreboard_graph",
                        tooltip = "graph_keybind_tooltip",
                    },
                    {
                        setting_id = "graph_window_scale",
                        type = "numeric",
                        default_value = 100,
                        range = { 50, 200 },
                        decimals_number = 0,
                        unit_text = "%",
                    },
                    {
                        setting_id = "graph_bg_opacity",
                        type = "numeric",
                        default_value = 200,
                        range = { 0, 255 },
                        decimals_number = 0,
                    },
                    -- Red / Bad tier color
                    {
                        setting_id = "graph_color_red",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "graph_red_r",
                                type = "numeric",
                                default_value = 255,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                            {
                                setting_id = "graph_red_g",
                                type = "numeric",
                                default_value = 0,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                            {
                                setting_id = "graph_red_b",
                                type = "numeric",
                                default_value = 0,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                        },
                    },
                    -- Yellow tier color
                    {
                        setting_id = "graph_color_yellow",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "graph_yellow_r",
                                type = "numeric",
                                default_value = 255,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                            {
                                setting_id = "graph_yellow_g",
                                type = "numeric",
                                default_value = 128,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                            {
                                setting_id = "graph_yellow_b",
                                type = "numeric",
                                default_value = 0,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                        },
                    },
                    -- Green / Good tier color
                    {
                        setting_id = "graph_color_green",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "graph_green_r",
                                type = "numeric",
                                default_value = 255,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                            {
                                setting_id = "graph_green_g",
                                type = "numeric",
                                default_value = 255,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                            {
                                setting_id = "graph_green_b",
                                type = "numeric",
                                default_value = 0,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                        },
                    },
                    -- Perfect tier color
                    {
                        setting_id = "graph_color_perfect",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "graph_perfect_r",
                                type = "numeric",
                                default_value = 0,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                            {
                                setting_id = "graph_perfect_g",
                                type = "numeric",
                                default_value = 255,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                            {
                                setting_id = "graph_perfect_b",
                                type = "numeric",
                                default_value = 0,
                                range = { 0, 255 },
                                decimals_number = 0,
                            },
                        },
                    },
                },
            },
            -- Group 6: Test Mode
            -- Enables a preview mode in the Psykhanium (Meat Grinder / Training Area) that displays the scoreboard overlay with placeholder data for testing and layout tuning.
            {
                setting_id = "test_mode_title",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "test_mode",
                        type = "checkbox",
                        default_value = false,
                        tooltip = "test_mode_tooltip",
                    },
                    {
                        setting_id = "overflow_safeguard_1",
                        type = "checkbox",
                        default_value = false,
                        tooltip = "overflow_safeguard_1_tooltip",
                    },
                    {
                        setting_id = "overflow_safeguard_2",
                        type = "checkbox",
                        default_value = false,
                        tooltip = "overflow_safeguard_2_tooltip",
                    },
                },
            },
        },
    },
}
