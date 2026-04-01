--[[
	File: AuspexHelper_localization.lua
	Description: Localization for Auspex Helper.
	Overall Release Version: 1.0.0
	File Version: 1.0.0
	File Introduced in: 1.0.0
	Last Updated: 2026-03-14
	Author: LAUREHTE
]]

local mod = get_mod("AuspexHelper")

return {
	mod_name = {
		en = "{#color(80,255,160)}\xEE\x80\xAA Auspex Helper \xEE\x80\xAA{#reset()}",
	},
	mod_description = {
		en = "{#color(120,255,180)}Release 1.0.0{#reset()} | Author: LAUREHTE\n{#color(90,220,150)}Scanner helpers, world-scan overlays, practice mode, and minigame assists.{#reset()}",
	},
	enable_group = {
		en = "{#color(80,255,160)}Enable ---------------------------------------------------------------------------------{#reset()}",
	},
	enable_group_desc = {
		en = "Master on or off controls for Auspex Helper and each supported minigame path.",
	},
	enable_mod_override = {
		en = "Enable mod",
	},
	enable_mod_override_desc = {
		en = "Soft-disable the whole hub while leaving the mod loaded.",
	},
	world_scan_group = {
		en = "{#color(80,255,160)}Scanner Outlines (Objectives) -----------------------------------------------{#reset()}",
	},
	world_scan_group_desc = {
		en = "Choose how roaming scan objectives are highlighted, tinted, and optionally shown in a centered scanner-search overlay while using the auspex.",
	},
	enable_world_scans = {
		en = "Scan Outlines",
	},
	enable_world_scans_desc = {
		en = "Enable assistance for roaming auspex scan objects.",
	},
	world_scan_display_mode = {
		en = "Display mode",
	},
	world_scan_display_mode_desc = {
		en = "Use a scanner outline highlight, an icon marker, or both for scan objects.",
	},
	world_scan_always_show = {
		en = "Always show if available",
	},
	world_scan_always_show_desc = {
		en = "Keep scan-object outlines or icons visible whenever active scannables exist, even without the auspex equipped.",
	},
	world_scan_through_walls = {
		en = "See through walls",
	},
	world_scan_through_walls_desc = {
		en = "Allow scanner outlines and markers to remain visible through walls. Turn this off to use custom color and alpha, see through walls is harder but less intrusive.",
	},
	world_scan_item_overlay = {
		en = "Show scanner overlay",
	},
	world_scan_item_overlay_desc = {
		en = "While actively searching with the auspex, show a centered scanner-style overlay with sonar rings and relative scannable positions instead of relying only on the auspex screen.",
	},
	world_scan_display_mode_highlight = {
		en = "Highlight",
	},
	world_scan_display_mode_icon = {
		en = "Icon",
	},
	world_scan_display_mode_both = {
		en = "Both",
	},
	world_scan_color_red = {
		en = "Color red",
	},
	world_scan_color_red_desc = {
		en = "Red channel for world-scan outlines and icon markers.",
	},
	world_scan_color_green = {
		en = "Color green",
	},
	world_scan_color_green_desc = {
		en = "Green channel for world-scan outlines and icon markers.",
	},
	world_scan_color_blue = {
		en = "Color blue",
	},
	world_scan_color_blue_desc = {
		en = "Blue channel for world-scan outlines and icon markers.",
	},
	world_scan_color_alpha = {
		en = "Color alpha",
	},
	world_scan_color_alpha_desc = {
		en = "Alpha for world-scan icons. The in-world scanner outline glow itself does not support alpha on this build.",
	},
	scanner_view_group = {
		en = "{#color(80,255,160)}Scanner View ----------------------------------------------------------------------{#reset()}",
	},
	scanner_view_group_desc = {
		en = "Control how live scanner minigames render and how much HUD is hidden.",
	},
	enable_scanner_visibility = {
		en = "Scanner view",
	},
	enable_scanner_visibility_desc = {
		en = "Enable live scanner display overrides and HUD fade behavior.",
	},
	live_display_mode = {
		en = "Minigame display mode",
	},
	live_display_mode_desc = {
		en = "Show live scanner minigames and practice mode in the auspex item or as a centered overlay.",
	},
	overlay_display_scale = {
		en = "Overlay scale",
	},
	overlay_display_scale_desc = {
		en = "Scale used by centered overlay scanner displays for live use and practice.",
	},
	overlay_background_opacity = {
		en = "Overlay background opacity",
	},
	overlay_background_opacity_desc = {
		en = "Black backdrop opacity behind centered overlay scanner displays. Set 0 for none or 255 for full black.",
	},
	overlay_color_red = {
		en = "Overlay red",
	},
	overlay_color_red_desc = {
		en = "Red channel for scanner overlays, including minigame overlay frames and the scanner-search overlay.",
	},
	overlay_color_green = {
		en = "Overlay green",
	},
	overlay_color_green_desc = {
		en = "Green channel for scanner overlays, including minigame overlay frames and the scanner-search overlay.",
	},
	overlay_color_blue = {
		en = "Overlay blue",
	},
	overlay_color_blue_desc = {
		en = "Blue channel for scanner overlays, including minigame overlay frames and the scanner-search overlay.",
	},
	overlay_color_alpha = {
		en = "Overlay alpha",
	},
	overlay_color_alpha_desc = {
		en = "Alpha for scanner overlays, including minigame overlay frames and the scanner-search overlay.",
	},
	overlay_show_decorations = {
		en = "Show scanner decorations",
	},
	overlay_show_decorations_desc = {
		en = "Show or hide the stock scanner icons around scanner minigames in both overlay and item mode.",
	},
	display_mode_item = {
		en = "Item",
	},
	display_mode_overlay = {
		en = "Overlay",
	},
	scanner_hide_crosshair = {
		en = "Hide crosshair",
	},
	scanner_hide_crosshair_desc = {
		en = "Hide the standard combat crosshair during scanner use.",
	},
	scanner_hide_crosshair_hud = {
		en = "Hide crosshair HUD",
	},
	scanner_hide_crosshair_hud_desc = {
		en = "Hide crosshair HUD widgets while the scanner is active.",
	},
	decode_group = {
		en = "{#color(80,255,160)}Decode Symbols ------------------------------------------------------------------{#reset()}",
	},
	decode_group_desc = {
		en = "Assist the decode-symbol scanner minigame and optionally auto-solve it.",
	},
	enable_decode_minigame = {
		en = "Decode Symbols",
	},
	enable_decode_minigame_desc = {
		en = "Enable the decode-symbol minigame path in Auspex Helper.",
	},
	enable_decode_helper = {
		en = "Highlight decode targets",
	},
	enable_decode_helper_desc = {
		en = "Highlight the correct decode selections and future rows.",
	},
	enable_decode_autosolve = {
		en = "Auto solve",
	},
	enable_decode_autosolve_desc = {
		en = "Automatically drive decode selections when possible.",
	},
	decode_interact_cooldown = {
		en = "Interact cooldown (ms)",
	},
	decode_interact_cooldown_desc = {
		en = "Delay between auto-solve interactions.",
	},
	decode_target_precision = {
		en = "Target precision",
	},
	decode_target_precision_desc = {
		en = "How strict decode target matching should be before interaction.",
	},
	decode_future_rows = {
		en = "Reveal future rows",
	},
	decode_future_rows_desc = {
		en = "How many upcoming decode rows receive helper highlights.",
	},
	future_rows_0 = {
		en = "Current only",
	},
	future_rows_1 = {
		en = "1 future row",
	},
	future_rows_2 = {
		en = "2 future rows",
	},
	future_rows_3 = {
		en = "3 future rows",
	},
	expedition_group = {
		en = "{#color(80,255,160)}Decode Match (Expeditions) -------------------------------------------------{#reset()}",
	},
	expedition_group_desc = {
		en = "Assist the expedition symbol-grid scanner minigame and optionally auto-solve it.",
	},
	enable_expedition_helper = {
		en = "Highlight correct symbols",
	},
	enable_expedition_helper_desc = {
		en = "Highlight matching symbols on the expedition grid using the puzzle helper color.",
	},
	enable_expedition_autosolve = {
		en = "Auto solve",
	},
	enable_expedition_autosolve_desc = {
		en = "Automatically move the expedition cursor to matching symbols and confirm them.",
	},
	expedition_interact_cooldown = {
		en = "Confirm cooldown (ms)",
	},
	expedition_interact_cooldown_desc = {
		en = "Delay between expedition auto-confirm interactions.",
	},
	expedition_move_interaction_ms = {
		en = "Move interaction (ms)",
	},
	expedition_move_interaction_ms_desc = {
		en = "Delay between expedition auto-solver movement steps on the grid.",
	},
	expedition_map_group = {
		en = "{#color(80,255,160)}Expedition Map ------------------------------------------------------------------{#reset()}",
	},
	expedition_map_group_desc = {
		en = "Control whether the new expedition map stays on the auspex item or opens as a centered overlay.",
	},
	enable_expedition_map_minigame = {
		en = "Expedition Map",
	},
	enable_expedition_map_minigame_desc = {
		en = "Enable Auspex Helper display overrides for the expedition map minigame.",
	},
	expedition_map_display_mode = {
		en = "Map display mode",
	},
	expedition_map_display_mode_desc = {
		en = "Show the expedition map on the auspex item or as a centered overlay.",
	},
	expedition_map_always_minimap = {
		en = "Minimap",
	},
	expedition_map_always_minimap_desc = {
		en = "Keep the expedition map on the HUD as a movable minimap while still allowing the normal expedition item or overlay display mode to work separately.",
	},
	expedition_map_show_item_markers = {
		en = "Show item markers",
	},
	expedition_map_show_item_markers_desc = {
		en = "Draw color-coded item dots for expedition materials, loot, luggables, and unopened chests on the minimap, overlay, and item map view.",
	},
	expedition_map_hide_distant_item_markers = {
		en = "Hide distant item markers",
	},
	expedition_map_hide_distant_item_markers_desc = {
		en = "Hide expedition item markers that are farther than 200 meters away.",
	},
	expedition_map_color_opportunity_icons = {
		en = "Color opportunity icons",
	},
	expedition_map_color_opportunity_icons_desc = {
		en = "Use Auspex Helper custom colors for expedition opportunity icons. Turn this off to keep the stock icon coloring and stock player-color highlight behavior.",
	},
	expedition_map_marker_size = {
		en = "Marker size",
	},
	expedition_map_marker_size_desc = {
		en = "Size of expedition item markers on the map, minimap, and overlay.",
	},
	expedition_map_marker_alpha = {
		en = "Marker alpha",
	},
	expedition_map_marker_alpha_desc = {
		en = "Opacity of expedition item markers. Lower values make the dots more transparent.",
	},
	expedition_map_hide_teammate_arrows = {
		en = "Hide teammate arrows",
	},
	expedition_map_hide_teammate_arrows_desc = {
		en = "Hide other players' arrow markers on the expedition map while keeping your own marker visible.",
	},
	expedition_map_zoom_scale = {
		en = "Map zoom",
	},
	expedition_map_zoom_scale_desc = {
		en = "Scale the expedition map projection itself. Higher values zoom in and lower values zoom out.",
	},
	expedition_map_minimap_scale = {
		en = "Minimap size",
	},
	expedition_map_minimap_scale_desc = {
		en = "Scale used for the expedition map overlay when minimap layout is enabled.",
	},
	expedition_map_minimap_offset_x = {
		en = "Minimap X position",
	},
	expedition_map_minimap_offset_x_desc = {
		en = "Horizontal offset for the expedition map minimap overlay. Positive moves right.",
	},
	expedition_map_minimap_offset_y = {
		en = "Minimap Y position",
	},
	expedition_map_minimap_offset_y_desc = {
		en = "Vertical offset for the expedition map minimap overlay. Positive moves up.",
	},
	drill_group = {
		en = "{#color(80,255,160)}Drill and Tree (Hab Drayko) --------------------------------------------------{#reset()}",
	},
	drill_group_desc = {
		en = "Assist the drill minigame and the Hab Drayko tree interaction path.",
	},
	enable_drill_minigame = {
		en = "Drill and Tree (Hab Drayko)",
	},
	enable_drill_minigame_desc = {
		en = "Enable the drill and tree minigame path in Auspex Helper.",
	},
	enable_drill_helper = {
		en = "Highlight drill targets",
	},
	enable_drill_helper_desc = {
		en = "Highlight the current drill timing target.",
	},
	enable_drill_autosolve = {
		en = "Auto solve",
	},
	enable_drill_autosolve_desc = {
		en = "Automatically move to the correct drill/tree target and confirm it when the search completes.",
	},
	drill_autosolve_speed = {
		en = "Autosolve speed",
	},
	drill_autosolve_speed_desc = {
		en = "Controls how quickly the drill/tree autosolver steps between targets and confirms progress. Higher is faster.",
	},
	enable_drill_direction_arrows = {
		en = "Show direction arrows",
	},
	enable_drill_direction_arrows_desc = {
		en = "Show directional arrows for the next movement input in the drill/tree minigame.",
	},
	enable_drill_overlay_sonar = {
		en = "Show sonar circles",
	},
	enable_drill_overlay_sonar_desc = {
		en = "Show or hide the drill/tree sonar circles in both overlay and item mode. In overlay mode they stay inside the outline bounds.",
	},
	frequency_group = {
		en = "{#color(80,255,160)}Frequency ---------------------------------------------------------------------------{#reset()}",
	},
	frequency_group_desc = {
		en = "Assist the frequency minigame and optional auto-tuning path.",
	},
	enable_frequency_minigame = {
		en = "Frequency",
	},
	enable_frequency_minigame_desc = {
		en = "Enable the frequency minigame path in Auspex Helper.",
	},
	enable_frequency_direction_arrows = {
		en = "Show direction arrows",
	},
	enable_frequency_direction_arrows_desc = {
		en = "Show directional arrows for the adjustments needed to match the target frequency.",
	},
	enable_frequency_autosolve = {
		en = "Auto tune",
	},
	enable_frequency_autosolve_desc = {
		en = "Automatically steer the frequency waveform toward the target and submit when aligned.",
	},
	frequency_autosolve_strength = {
		en = "Autocontrol strength",
	},
	frequency_autosolve_strength_desc = {
		en = "Strength multiplier for frequency auto-tuning movement.",
	},
	balance_group = {
		en = "{#color(80,255,160)}Balance (Rolling Steel) ---------------------------------------------------------{#reset()}",
	},
	balance_group_desc = {
		en = "Assist the Rolling Steel balance minigame and optional auto-balance path.",
	},
	enable_balance_minigame = {
		en = "Balance (Rolling Steel)",
	},
	enable_balance_minigame_desc = {
		en = "Enable the balance minigame path in Auspex Helper.",
	},
	enable_expedition_minigame = {
		en = "Decode Match (Expeditions)",
	},
	enable_expedition_minigame_desc = {
		en = "Enable helper logic for the expedition symbol-grid minigame.",
	},
	enable_balance_autosolve = {
		en = "Auto balance",
	},
	enable_balance_autosolve_desc = {
		en = "Apply assisted movement to keep the balance cursor centered.",
	},
	balance_autosolve_strength = {
		en = "Autocontrol strength",
	},
	balance_autosolve_strength_desc = {
		en = "Strength multiplier for balance auto-control input.",
	},
	ui_color_group = {
		en = "{#color(80,255,160)}Puzzle Highlight Color ----------------------------------------------------------{#reset()}",
	},
	ui_color_group_desc = {
		en = "Tint the helper overlays used inside scanner minigames.",
	},
	ui_color_red = {
		en = "Red",
	},
	ui_color_red_desc = {
		en = "Red channel for puzzle helper highlights.",
	},
	ui_color_green = {
		en = "Green",
	},
	ui_color_green_desc = {
		en = "Green channel for puzzle helper highlights.",
	},
	ui_color_blue = {
		en = "Blue",
	},
	ui_color_blue_desc = {
		en = "Blue channel for puzzle helper highlights.",
	},
	ui_color_alpha = {
		en = "Alpha",
	},
	ui_color_alpha_desc = {
		en = "Opacity for puzzle helper highlights.",
	},
	debug_group = {
		en = "{#color(80,255,160)}Debug ---------------------------------------------------------------------------------{#reset()}",
	},
	debug_group_desc = {
		en = "Toggle developer-facing Auspex Helper debug messages used for troubleshooting.",
	},
	debug_echoes = {
		en = "Debug echoes",
	},
	debug_echoes_desc = {
		en = "Enable Auspex Helper debug echo messages in chat/console.",
	},
	debug_expedition_state = {
		en = "Expedition state traces",
	},
	debug_expedition_state_desc = {
		en = "Show expedition scanner/minimap/view state transitions without enabling every debug message.",
	},
	debug_expedition_autosolve = {
		en = "Expedition autosolve traces",
	},
	debug_expedition_autosolve_desc = {
		en = "Show expedition decode-match target, cursor, and submit decision traces for autosolve debugging.",
	},
	debug_expedition_markers = {
		en = "Expedition marker traces",
	},
	debug_expedition_markers_desc = {
		en = "Show expedition item-marker source counts and drawn marker totals.",
	},
	debug_expedition_slots = {
		en = "Expedition scanner slot traces",
	},
	debug_expedition_slots_desc = {
		en = "Show expedition scanner inventory-slot snapshot and restore messages.",
	},
	debug_silence_messages = {
		en = "Silence mod messages",
	},
	debug_silence_messages_desc = {
		en = "Suppress all Auspex Helper mod:echo, mod:notify, and mod:warn messages.",
	},
	preview_group = {
		en = "{#color(80,255,160)}Practice -------------------------------------------------------------------------------{#reset()}",
	},
	preview_group_desc = {
		en = "Launch supported scanner minigames anywhere for practice runs.",
	},
	enable_preview = {
		en = "Practice",
	},
	enable_preview_desc = {
		en = "Enable the practice launcher and hotkey.",
	},
	preview_type = {
		en = "Practice minigame",
	},
	preview_type_desc = {
		en = "Choose which minigame the practice hotkey will open.",
	},
	preview_type_decode_symbols = {
		en = "Decode symbols",
	},
	preview_type_decode_symbols_12 = {
		en = "Decode symbols (12 row)",
	},
	preview_type_drill = {
		en = "Drill / tree",
	},
	preview_type_frequency = {
		en = "Frequency",
	},
	preview_type_balance = {
		en = "Balance",
	},
	preview_type_expedition = {
		en = "Expedition grid",
	},
	toggle_preview_key = {
		en = "Start practice hotkey",
	},
	toggle_preview_key_desc = {
		en = "Hotkey used to start or close practice.",
	},
	practice_balance_time_multiplier = {
		en = "Balance time multiplier",
	},
	practice_balance_time_multiplier_desc = {
		en = "Practice only. Higher values make balance take longer to complete. Default is 3x.",
	},
	practice_decode_speed_multiplier = {
		en = "Decode speed multiplier",
	},
	practice_decode_speed_multiplier_desc = {
		en = "Practice only. Higher values make decode sweep faster and harder.",
	},
	practice_balance_difficulty = {
		en = "Balance difficulty",
	},
	practice_balance_difficulty_desc = {
		en = "Practice only. Higher values make balance drift and disruption harder to control.",
	},
	preview_unavailable = {
		en = "Auspex practice could not build the selected scanner minigame.",
	},
	practice_complete_time = {
		en = "%s practice complete in %.2fs.",
	},
	preview_type_disabled = {
		en = "That practice minigame path is disabled in Auspex Helper settings.",
	},
	preview_type_expedition_placeholder = {
		en = "The expedition scanner minigame could not be initialized on this build.",
	},
	practice_item_hub_unavailable = {
		en = "Practice item mode is not safe in the hub on this build. Overlay mode was opened instead.",
	},
	practice_item_unavailable = {
		en = "Practice item mode could not equip a usable scanner. Overlay mode was opened instead.",
	},
	live_item_online_unavailable = {
		en = "Item display mode is not safe in online missions on this build. Overlay mode was opened instead.",
	},
}
