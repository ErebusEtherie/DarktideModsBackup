local mod = get_mod("improved_scoreboard_panel")

-- ============================================================
-- MOD VERSION TRACKING
-- Records the current version and logs a startup message so
-- the user knows the mod loaded successfully.
-- ============================================================

-- Track the mod version for display in the settings description
mod.version = "2.0.6"
mod:info("Improved Scoreboard Panel is installed, using version: " .. tostring(mod.version))

-- ============================================================
-- SETTINGS COLOR PALETTE
-- Defines the RGB color values used throughout the DMF options
-- menu text to give the settings a consistent visual theme.
-- ============================================================

-- Color palette used throughout the settings menu text.
local colours = {
    title = "169,191,153",   -- Greenish tone for group headers
    subtitle = "230,150,30", -- Yellowish orange for the mod title and metadata labels
    text = "169,191,153",    -- Greenish tone for body text
}

-- ============================================================
-- LOCALIZATION TABLE
-- All readable text shown in the mod options screen and
-- scoreboard overlay. Each key maps to a table of language
-- strings; currently only English ("en") is provided.
-- ============================================================

-- All readable text shown in the mod options screen.
mod.localisation = {
    -- Mod name variants: active display name, plain text, and colored fancy version.
    mod_name = {
        en = "{#color(" .. colours.title .. ")}Improved Scoreboard Panel{#reset()}",
    },
    mod_name_boring = {
        en = "Improved Scoreboard Panel",
    },
    mod_name_pizazz = {
        en = "{#color(" .. colours.subtitle .. ")}Improved Scoreboard Panel{#reset()}",
    },
    -- Mod description shown below the mod name in DMF.
    mod_description = {
        en = "{#color("
            .. colours.text
            .. ")}"
            .. "Tracks player performance during missions and displays a compact scoreboard panel."
            .. "{#reset()}"
            .. "\n{#color("
            .. colours.subtitle
            .. ")}Author: {#color("
            .. colours.text
            .. ")}Lumberfart{#reset()}"
            .. "\n{#color("
            .. colours.subtitle
            .. ")}Version: {#color("
            .. colours.text
            .. ")}"
            .. mod.version
            .. "{#reset()}"
            .. "\n{#color("
            .. colours.subtitle
            .. ")}Disclaimer: {#color("
            .. colours.text
            .. ")}Made with OpenCode{#reset()}"
            .. "\n{#color("
            .. colours.subtitle
            .. ")}Language Model: {#color("
            .. colours.text
            .. ")}MiMo V2.5 Pro{#reset()}",
    },
    -- General group
    general_settings = {
        en = "{#color(" .. colours.title .. ")}General Settings{#reset()}",
    },
    show_in_mission = {
        en = "Show in Tactical Overlay (TAB)",
    },
    show_in_mission_tooltip = {
        en = "Display the scoreboard overlay while holding TAB during missions.",
    },
    show_at_mission_end = {
        en = "Show at Mission End",
    },
    show_at_mission_end_tooltip = {
        en = "Automatically display the scoreboard when the mission ends.",
    },
    mod_name_pizazz_toggle = {
        en = "Enable Name Pizazz",
    },
    mod_name_pizazz_tooltip = {
        en = "Toggles the colored effect on the mod name text and applies archetype-based colors to player names on the scoreboard. Requires a reload.",
    },
    minimal_stat_labels = {
        en = "Minimal Stat Labels",
    },
    minimal_stat_labels_tooltip = {
        en = "When enabled, stat labels use shorter names (e.g. \"Kills\" instead of \"Total Kills\").",
    },
    ranked_mode = {
        en = "Ranked Mode",
    },
    ranked_mode_tooltip = {
        en = "Outlines the player card of whoever currently holds the most scoreboard highscores, using the highscore text color.",
    },
    solo_mode_tab = {
        en = "Solo Mode (TAB Only)",
    },
    solo_mode_tab_tooltip = {
        en = "Hides other players' tracked stats from the Tactical Overlay, letting you focus on your own performance without distractions. Stats for all players continue to be tracked and are revealed on the mission end screen.",
    },
    stat_min_kills = {
        en = "Kills",
    },
    stat_min_ranged_kills = {
        en = "Ranged",
    },
    stat_min_melee_kills = {
        en = "Melee",
    },
    stat_min_headshots = {
        en = "Headshots",
    },
    stat_min_damage_dealt = {
        en = "DMG Dealt",
    },
    stat_min_damage_taken = {
        en = "DMG Taken",
    },
    stat_min_specials = {
        en = "Specials",
    },
    stat_min_elites = {
        en = "Elites",
    },
    stat_min_bosses = {
        en = "Bosses",
    },
    stat_min_boss_damage = {
        en = "DMG Bosses",
    },
    stat_min_revives = {
        en = "Revives",
    },
    stat_min_rescues = {
        en = "Rescues",
    },
    stat_min_relics = {
        en = "Relics",
    },
    stat_min_barrels_exploded = {
        en = "Barrels",
    },
    -- Layout group
    layout_settings = {
        en = "{#color(" .. colours.title .. ")}Layout Settings{#reset()}",
    },
    panel_alignment = {
        en = "Panel Alignment",
    },
    box_width = {
        en = "Box Width",
    },
    box_width_tooltip = {
        en = "Width of each player card in pixels.",
    },
    box_offset_x = {
        en = "Box Offset (X)",
    },
    box_offset_x_tooltip = {
        en = "Horizontal offset from the default centered position.",
    },
    box_offset_y = {
        en = "Box Offset (Y)",
    },
    box_offset_y_tooltip = {
        en = "Vertical offset from the default centered position.",
    },
    -- Display group
    display_settings = {
        en = "{#color(" .. colours.title .. ")}Display Settings{#reset()}",
    },
    box_opacity_mission = {
        en = "Box Opacity at Mission End",
    },
    box_opacity_tactical = {
        en = "Box Opacity in Tactical Overlay",
    },
    text_scale_mission = {
        en = "Text Scale in Mission",
    },
    text_scale_tactical = {
        en = "Text Scale in Tactical Overlay",
    },
    tactical_offset_x = {
        en = "Tactical Overlay Offset (X)",
    },
    tactical_offset_x_tooltip = {
        en = "Horizontal offset for the 2x2 grid inside the Tactical Overlay (TAB).",
    },
    tactical_offset_y = {
        en = "Tactical Overlay Offset (Y)",
    },
    tactical_offset_y_tooltip = {
        en = "Vertical offset for the 2x2 grid inside the Tactical Overlay (TAB).",
    },
    row_spacing = {
        en = "Row Gap Size",
    },

    -- RGB color component labels for highscore and stat label color pickers.
    highscore_color_r = {
        en = "Highscore Color - Red",
    },
    highscore_color_g = {
        en = "Highscore Color - Green",
    },
    highscore_color_b = {
        en = "Highscore Color - Blue",
    },
    stat_label_color_r = {
        en = "Stat Label Color - Red",
    },
    stat_label_color_g = {
        en = "Stat Label Color - Green",
    },
    stat_label_color_b = {
        en = "Stat Label Color - Blue",
    },
    -- Row labels
    -- Display names for each tracked stat that appear as row labels on the scoreboard cards.
    stat_kills = {
        en = "Total Kills",
    },
    stat_ranged_kills = {
        en = "Ranged Kills",
    },
    stat_melee_kills = {
        en = "Melee Kills",
    },
    stat_damage_dealt = {
        en = "Damage Dealt",
    },
    stat_damage_taken = {
        en = "Damage Taken",
    },
    stat_specials = {
        en = "Specials Killed",
    },
    stat_elites = {
        en = "Elites Killed",
    },
    stat_bosses = {
        en = "Bosses Killed",
    },
    stat_headshots = {
        en = "Headshots",
    },
    stat_revives = {
        en = "Most Revives",
    },
    stat_rescues = {
        en = "Most Rescues",
    },
    stat_relics = {
        en = "Relics Discovered",
    },
    stat_barrels_exploded = {
        en = "Barrels Exploded",
    },
    stat_boss_damage = {
        en = "Damage to Bosses",
    },
    -- Tracked Stats group
    tracked_stats = {
        en = "{#color(" .. colours.title .. ")}Tracked Stats{#reset()}",
    },
    track_stat_kills = {
        en = "Total Kills",
    },
    track_stat_kills_tooltip = {
        en = "Show total kills on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_ranged_kills = {
        en = "Ranged Kills",
    },
    track_stat_ranged_kills_tooltip = {
        en = "Show ranged kills on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_melee_kills = {
        en = "Melee Kills",
    },
    track_stat_melee_kills_tooltip = {
        en = "Show melee kills on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_dmg_dealt = {
        en = "Damage Dealt",
    },
    track_stat_dmg_dealt_tooltip = {
        en = "Show total damage dealt on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_dmg_taken = {
        en = "Damage Taken",
    },
    track_stat_dmg_taken_tooltip = {
        en = "Show total damage taken on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_specials = {
        en = "Specials Killed",
    },
    track_stat_specials_tooltip = {
        en = "Show special enemies killed on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_elites = {
        en = "Elites Killed",
    },
    track_stat_elites_tooltip = {
        en = "Show elite enemies killed on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_bosses = {
        en = "Bosses Killed",
    },
    track_stat_bosses_tooltip = {
        en = "Show monster/boss enemies killed on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_headshots = {
        en = "Headshots",
    },
    track_stat_headshots_tooltip = {
        en = "Show headshots landed on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_revives = {
        en = "Most Revives",
    },
    track_stat_revives_tooltip = {
        en = "Show revives performed on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_rescues = {
        en = "Most Rescues",
    },
    track_stat_rescues_tooltip = {
        en = "Show rescues performed (pull-ups, net removals, rescues) on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_relics = {
        en = "Relics Discovered",
    },
    track_stat_relics_tooltip = {
        en = "Show relics discovered (grimoires, scriptures, heretical idols, tainted devices, skulls, totems, martyr skulls) on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_barrels_exploded = {
        en = "Barrels Exploded",
    },
    track_stat_barrels_exploded_tooltip = {
        en = "Show explosive barrels detonated on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    track_stat_boss_damage = {
        en = "Damage to Bosses",
    },
    track_stat_boss_damage_tooltip = {
        en = "Show damage dealt to bosses on the scoreboard.\n{#color(255,0,0)}(Recommended: MAX 8 Stats Toggled){#reset()}",
    },
    -- Alignment options
    -- Text labels for the panel alignment dropdown (left edge or right edge anchoring).
    align_left = {
        en = "Left Edge",
    },
    align_right = {
        en = "Right Edge",
    },
    -- Highscore Text Color group
    highscore_text_color = {
        en = "{#color(" .. colours.title .. ")}Highscore Text Color{#reset()}",
    },
    -- Stat Label Color group
    stat_label_color = {
        en = "{#color(" .. colours.title .. ")}Stat Label Color{#reset()}",
    },
    -- Test Mode group
    test_mode_title = {
        en = "{#color(" .. colours.title .. ")}Test Mode{#reset()}",
    },
    test_mode = {
        en = "Enable Test Mode (Psykhanium)",
    },
    test_mode_tooltip = {
        en = "Shows the scoreboard overlay inside the Psykhanium (Meat Grinder) while test mode is active. Real tracked stats are displayed for you, with placeholder cards for extra players.",
    },
    overflow_safeguard_1 = {
        en = "Overflow Safeguard 1",
    },
    overflow_safeguard_1_tooltip = {
        en = "When enabled, splits stat labels into 2-column layout to prevent vertical overflow. Works with any number of stats.",
    },
    overflow_safeguard_2 = {
        en = "Overflow Safeguard 2",
    },
    overflow_safeguard_2_tooltip = {
        en = "When enabled with 10+ tracked stats, scales the scoreboard down by 25%% to prevent vertical overflow. Does not affect the Tactical Overlay (TAB).",
    },
    -- Graph Data group
    graph_data = {
        en = "{#color(" .. colours.title .. ")}Graph Data{#reset()}",
    },
    graph_window_scale = {
        en = "Window Scale",
    },
    graph_bg_opacity = {
        en = "Background Opacity",
    },
    graph_keybind = {
        en = "Open Scoreboard Graph",
    },
    graph_keybind_tooltip = {
        en = "Keyboard shortcut to open the scoreboard graph screen from anywhere in the game.",
    },
    graph_disable = {
        en = "Disable Scoreboard Graph",
    },
    graph_disable_tooltip = {
        en = "When enabled, the Scoreboard Graph [F4] panel is completely disabled. The rest of the mod continues to function normally.",
    },
    graph_per_character = {
        en = "Disable Account Wide Data Tracking",
    },
    graph_per_character_tooltip = {
        en = "When enabled, graph data is tracked separately for each character. When disabled, all character data is combined into one account-wide pool. Toggling does not reset existing tracked stats.",
    },
    graph_color_red = {
        en = "{#color(" .. colours.title .. ")}Bad Performance (Only 1 Highscore){#reset()}",
    },
    graph_red_r = {
        en = "Red - Red",
    },
    graph_red_g = {
        en = "Red - Green",
    },
    graph_red_b = {
        en = "Red - Blue",
    },
    graph_color_yellow = {
        en = "{#color(" .. colours.title .. ")}Low Performance (2 or More Highscores){#reset()}",
    },
    graph_yellow_r = {
        en = "Orange - Red",
    },
    graph_yellow_g = {
        en = "Orange - Green",
    },
    graph_yellow_b = {
        en = "Orange - Blue",
    },
    graph_color_green = {
        en = "{#color(" .. colours.title .. ")}Good Performance (3 or More Highscores){#reset()}",
    },
    graph_green_r = {
        en = "Yellow - Red",
    },
    graph_green_g = {
        en = "Yellow - Green",
    },
    graph_green_b = {
        en = "Yellow - Blue",
    },
    graph_color_perfect = {
        en = "{#color(" .. colours.title .. ")}Perfect Performance (Best Overall Highscore){#reset()}",
    },
    graph_perfect_r = {
        en = "Green - Red",
    },
    graph_perfect_g = {
        en = "Green - Green",
    },
    graph_perfect_b = {
        en = "Green - Blue",
    },
    -- Graph stat labels (same as tracked stat display names but used in the lifetime card context)
    stat_graph_kills = {
        en = "Total Kills",
    },
    stat_graph_ranged_kills = {
        en = "Ranged Kills",
    },
    stat_graph_melee_kills = {
        en = "Melee Kills",
    },
    stat_graph_headshots = {
        en = "Headshots",
    },
    stat_graph_damage_dealt = {
        en = "Damage Dealt",
    },
    stat_graph_damage_taken = {
        en = "Damage Taken",
    },
    stat_graph_specials = {
        en = "Specials Killed",
    },
    stat_graph_elites = {
        en = "Elites Killed",
    },
    stat_graph_bosses = {
        en = "Bosses Killed",
    },
    stat_graph_boss_damage = {
        en = "Damage to Bosses",
    },
    stat_graph_revives = {
        en = "Most Revives",
    },
    stat_graph_rescues = {
        en = "Most Rescues",
    },
    stat_graph_relics = {
        en = "Relics Discovered",
    },
    stat_graph_barrels_exploded = {
        en = "Barrels Exploded",
    },
    stat_graph_total_highscores = {
        en = "Total Highscores",
    },
    stat_graph_times_leader = {
        en = "Times Ranked Leader",
    },
}

-- ============================================================
-- NAME PIZZAZ TOGGLE APPLICATION
-- Switches the displayed mod name between the colored fancy
-- version and the plain text version, depending on whether the
-- "mod_name_pizazz_toggle" setting is enabled or disabled.
-- ============================================================

-- Switches mod name between colored fancy and plain versions based on the pizazz toggle.
mod.toggle_pizazz = function()
    for key, values in pairs(mod.localisation) do
        if key == "mod_name" then
            for language, text in pairs(values) do
                if mod:get("mod_name_pizazz_toggle") == false then
                    mod.localisation[key][language] = mod.localisation["mod_name_boring"][language]
                else
                    mod.localisation[key][language] = mod.localisation["mod_name_pizazz"][language]
                end
            end
        end
    end
end

-- Apply the pizazz toggle on mod load.
mod.toggle_pizazz()

-- Returns the populated localization table to the mod loader.
return mod.localisation
