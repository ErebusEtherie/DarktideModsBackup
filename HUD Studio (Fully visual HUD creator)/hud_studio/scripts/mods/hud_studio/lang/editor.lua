
local mod = get_mod("hud_studio")

local important, lines = mod.dl.loc_helpers.important, mod.dl.loc_helpers.lines

return {

	flip_x = {
		en = "Horizontal",
	},
	flip_y = {
		en = "Vertical",
	},
	flip_xy = {
		en = "Both",
	},
	flip_none = {
		en = "None",
	},
	clip_none = {
		en = "None",
	},
	clip_left = {
		en = "Keep left",
	},
	clip_right = {
		en = "Keep right",
	},
	clip_top = {
		en = "Keep top",
	},
	clip_bottom = {
		en = "Keep bottom",
	},
	clip_top_left = {
		en = "Keep top-left",
	},
	clip_top_right = {
		en = "Keep top-right",
	},
	clip_bottom_left = {
		en = "Keep bottom-left",
	},
	clip_bottom_right = {
		en = "Keep bottom-right",
	},
	clip_center = {
		en = "Keep center",
	},
	clip_inset = {
		en = "Trim border",
	},
	left_right = {
		en = "Left to right",
	},
	right_left = {
		en = "Right to left",
	},
	top_bottom = {
		en = "Top to bottom",
	},
	bottom_top = {
		en = "Bottom to top",
	},
	center = {
		en = "Center outwards (horizontal)",
	},
	center_vertical = {
		en = "Center outwards (vertical)",
	},
	shape_straight = {
		en = "Straight",
	},
	shape_curved = {
		en = "Curved",
	},

	panel_label_layout_wide = {
		en = "Labelled Columns",
	},
	panel_label_layout_compact = {
		en = "Compact rows",
	},

	curved_top_left = {
		en = "Top-left",
	},
	curved_top_right = {
		en = "Top-right",
	},
	curved_bottom_left = {
		en = "Bottom-left",
	},
	curved_bottom_right = {
		en = "Bottom-right",
	},
	curved_top_left_reversed = {
		en = "Top-left (Reversed Fill)",
	},
	curved_top_right_reversed = {
		en = "Top-right (Reversed Fill)",
	},
	curved_bottom_left_reversed = {
		en = "Bottom-left (Reversed Fill)",
	},
	curved_bottom_right_reversed = {
		en = "Bottom-right (Reversed Fill)",
	},

	semicircle_top = {
		en = "Semicircle Top",
	},
	semicircle_bottom = {
		en = "Semicircle Bottom",
	},
	semicircle_left = {
		en = "Semicircle Left",
	},
	semicircle_right = {
		en = "Semicircle Right",
	},
	semicircle_top_reversed = {
		en = "Semicircle Top (Reversed Fill)",
	},
	semicircle_bottom_reversed = {
		en = "Semicircle Bottom (Reversed Fill)",
	},
	semicircle_left_reversed = {
		en = "Semicircle Left (Reversed Fill)",
	},
	semicircle_right_reversed = {
		en = "Semicircle Right (Reversed Fill)",
	},
	add_folder_tooltip = {
		en = "Add Folder",
	},
	add_block_tooltip = {
		en = "Add Block",
	},
	copy_selection_tooltip = {
		en = "Duplicate the selected block or node",
	},
	delete_selection_tooltip = {
		en = "Delete the selected block or node",
	},
	add_text_tooltip = {
		en = "Add Text",
	},
	add_progress_bar_tooltip = {
		en = "Add Progress Bar",
	},
	add_rect_tooltip = {
		en = "Add Rectangle/Texture",
	},
	block_file_path = {
		en = "Block location: %%appdata%%/Fatshark/Darktide/hud_studio/blocks/[block_id]",
	},
	ide_panel_title = {
		en = "Code Editor",
	},
	ide_block_script_declare = {
		en = "-- runs once per frame, before this block's nodes",
	},
	ide_block_script_return = {
		en = "-- node code reads what you stored: block.state.<your_key>",
	},
	ide_prose_style = {
		en = "Modify this node's style table in one pass. Return only the keys you want to override.",
	},
	ide_prose_visible = {
		en = "Control this element's visibility with a code hook.",
	},
	ide_prose_script = {
		en = "Runs once a frame for the whole block, before its nodes. Do the shared work here -- store results in `state`, and every binding on the block reads them back as block.state.",
	},
	ide_return_block = {
		en = "nothing -- write your results into state (read as block.state)",
	},
	ide_return_text = {
		en = "string (or number -- formatted by the node's Decimals)",
	},
	ide_return_current = {
		en = "number  tested as current / max against the threshold bands",
	},
	ide_return_max = {
		en = "number  the value current is a percentage of",
	},
	ide_reset_button_text = {
		en = "RESET CHANGES",
	},
	ide_reset_button_tooltip = {
		en = "Restore the script to what it was when this editor was opened",
	},
	ide_expected_return_label = {
		en = "Expected return: ",
	},
	ide_prose_value = {
		en = "Compute the value bound to this node's ",
	},
	ide_end_undo_redo_warning = {
		en = important("There is no undo! (CTRL+Z) Be careful!"),
	},
	ide_end_fluff = {
		en = "This is a basic code editor built in Darktide. Infinite loops and errors are guarded. Bugs and edge cases are likely.",
	},
	ide_end_warning = {
		en = "You CAN and WILL break this mod and others if you write to anything but the return value and state.",
	},
	gamemodes = {
		en = "Gamemodes",
	},
	classes = {
		en = "(Your) Class",
	},
	static = {
		en = "Static",
	},
	grid = {
		en = "Grid",
	},
	rows = {
		en = "Rows",
	},
	columns = {
		en = "Columns",
	},

	visibility_option_alive = {
		en = "Alive",
	},
	visibility_option_dead = {
		en = "Dead",
	},
	visibility_option_in_party = {
		en = "In Party",
	},
	visibility_eye_tooltip_hide_block = {
		en = "Hide Block",
	},
	visibility_eye_tooltip_hide_node = {
		en = "Hide Node",
	},
	visibility_eye_tooltip_show_block = {
		en = "Show Block",
	},
	visibility_eye_tooltip_show_node = {
		en = "Show Node",
	},
	visibility_eye_force_hidden = {
		en = "[FORCE-HIDDEN]",
	},
	visibility_eye_force_shown = {
		en = "[FORCE-SHOWN]",
	},
	visibility_eye_dynamic_mode = {
		en = "Visibility controlled dynamically",
	},

	visibility_eye_script_error = {
		en = "Script error: ",
	},

	class_veteran = {
		en = "Veteran",
	},
	class_psyker = {
		en = "Psyker",
	},
	class_zealot = {
		en = "Zealot",
	},
	class_vet = {
		en = "Veteran",
	},
	class_arbites = {
		en = "Arbites",
	},
	class_hive_scum = {
		en = "Hive Scum",
	},
	class_skitarii = {
		en = "Skitarii",
	},

	gamemode_mission = {
		en = "Mission",
	},
	gamemode_hub = {
		en = "Mourningstar",
	},
	gamemode_practice = {
		en = "Meat Grinder",
	},

	data_source_player_1 = {
		en = "Player 1 (You)",
	},
	data_source_player_2 = {
		en = "Player 2",
	},
	data_source_player_3 = {
		en = "Player 3",
	},
	data_source_player_4 = {
		en = "Player 4",
	},

	field_mode_conditions = {
		en = "Conditions",
	},
	field_mode_source = {
		en = "Source",
	},
	field_mode_code = {
		en = "Code",
	},
	field_mode_fixed = {
		en = "Static",
	},

	field_mode_data_source = {
		en = "Data Source",
	},
	field_mode_thresholds = {
		en = "Thresholds",
	},

	field_mode_localized = {
		en = "Localized",
	},

	lib_open_tooltip = {
		en = "Open Library",
	},
	lib_save_form_save = {
		en = "Save to Library",
	},
	lib_save_form_missing_name = {
		en = "Name Required",
	},
	lib_save_form_await_blur = {
		en = "Confirm Name (Enter)",
	},
	lib_save_form_overwrite = {
		en = "Overwrite %s?",
	},
	lib_save_form_save_folder = {
		en = "Save Folder to Library",
	},

	section_export_to_mod = {
		en = "Export to Mod",
	},
	field_label_label = {
		en = "Label  [Max %d]",
	},
	field_label_summary = {
		en = "Summary  [Max %d]",
	},
	field_label_mod_version = {
		en = "Version",
	},
	field_label_requires = {
		en = "Dependency Mods [Up to %d]",
	},
	field_label_tags = {
		en = "Tags [Up to %d]",
	},
	field_label_mod_name = {
		en = "Mod Name",
	},

	field_help_label = {
		en = "The block's title and button label in the Block Library.",
	},
	field_help_summary = {
		en = "Describe the purpose or appearance. Shown in the Block Library's details pane.",
	},
	field_help_mod_version = {
		en = "Users are only offered an update if your version is higher than their installed.",
	},
	field_help_requires = {
		en = "Dependency mods, comma separated. e.g. true_level,hud_studio",
	},
	field_help_tags = {
		en = "Library categories to file this block under. Separate with commas, e.g. health,ammo",
	},
	field_help_mod_name = {
		en = "The folder name of the mod to export into, e.g. my_mod.",
	},
	export_form_missing_mod = {
		en = "Mod Name Required",
	},
	export_form_export = {
		en = "Export to %s",
	},
	export_form_no_such_mod = {
		en = "No Mod '%s'",
	},

	export_form_note_no_mod = {
		en = "Enter a mod name to see where this block will be written.",
	},
	export_form_note_missing_mod = {
		en = "No mod '%s' in the mods folder.",
	},

	f_form_title = {
		en = "Folder",
	},
	f_form_trash_title = {
		en = "Deleted Items",
	},
	f_form_trash_note = {

		en = lines(
			"Deleted Items (%d)",
			"Deleted blocks are kept here and never drawn. Drag one back up the tree to"
				.. " restore it, or delete it again to remove it for good."
		),
	},
	ide_open_button_text = {
		en = "Open Ide %s",
	},

	ide_open = {
		en = "Open IDE…",
	},
	ide_open_with_errors = {
		en = "Open IDE… (Contains Errors)",
	},
	ide_contains_errors = {
		en = "(Contains Errors)",
	},
	script_edit = {
		en = "Edit Script…",
	},
	script_add = {
		en = "Add Script…",
	},

	field_label_visible = {
		en = "Visible",
	},
	field_label_source = {
		en = "Source",
	},
	field_label_field = {
		en = "Field",
	},
	dropdown_search_hint = {
		en = "Search...",
	},
	field_label_to = {
		en = "To",
	},
	field_label_name = {
		en = "Name",
	},
	field_label_value = {
		en = "Value",
	},
	field_label_preset = {
		en = "Preset",
	},
	field_label_amount = {
		en = "Amount",
	},
	field_label_loc_id = {
		en = "Localization ID",
	},
	field_label_x = {
		en = "X",
	},
	field_label_y = {
		en = "Y",
	},
	field_label_width = {
		en = "Width",
	},
	field_label_height = {
		en = "Height",
	},
	field_label_decimals = {
		en = "Decimals",
	},
	field_label_fade_in = {
		en = "Fade In",
	},
	field_label_fade_out = {
		en = "Fade Out",
	},
	field_label_easing = {
		en = "Easing",
	},
	field_label_threshold_mode = {
		en = "Threshold Mode",
	},
	field_label_style_mode = {
		en = "Style Mode",
	},
	field_label_style_patch = {
		en = "Style Patch",
	},
	field_label_value_mode = {
		en = "Value Mode",
	},

	color_picker_open_tooltip = {
		en = "Open Color Picker",
	},
	color_picker_copy_tooltip = {
		en = "Copy { A, R, G, B }",
	},
	color_picker_paste_tooltip = {
		en = "Paste { A, R, G, B }",
	},
	thresholds_open_tooltip = {
		en = "Edit Color-by-threshold",
	},

	field_label_color = {
		en = "Color",
	},
	field_label_bg_color = {
		en = "Background",
	},
	field_label_outline_color = {
		en = "Outline",
	},
	field_label_size = {
		en = "Size",
	},
	field_label_offset = {
		en = "Position",
	},
	field_label_font_type = {
		en = "Font",
	},
	field_label_font_size = {
		en = "Font size",
	},
	field_label_text = {
		en = "Text",
	},
	field_label_material = {
		en = "Material",
	},
	field_label_material_fallback = {
		en = "Fallback material",
	},
	field_label_color_fallback = {
		en = "Fallback color",
	},
	field_label_current = {
		en = "Current",
	},
	field_label_max = {
		en = "Max",
	},
	field_label_segments = {
		en = "Segments",
	},
	field_label_segment_gap = {
		en = "Segment gap",
	},
	field_label_orientation = {
		en = "Orientation",
	},
	field_label_shape = {
		en = "Shape",
	},
	field_label_align = {
		en = "Alignment",
	},
	field_label_uvs = {
		en = "Flip",
	},
	field_label_clip = {
		en = "Clip",
	},
	field_label_rotation = {
		en = "Rotation",
	},
	field_label_shadow = {
		en = "Shadow",
	},

	property_nothing_selected = {
		en = "Nothing Selected",
	},
	section_mod_block = {
		en = "Mod Block",
	},
	section_blocks = {
		en = "Blocks",
	},
	section_script = {
		en = "Script",
	},
	section_visibility = {
		en = "Visibility",
	},
	section_transitions = {
		en = "Transitions",
	},
	section_tools = {
		en = "Tools",
	},
	section_style = {
		en = "Style",
	},
	section_value = {
		en = "Value",
	},

	easing_linear = {
		en = "Linear",
	},
	easing_in_out = {
		en = "Ease In-Out",
	},

	align_left = {
		en = "Left",
	},
	align_center = {
		en = "Center",
	},
	align_right = {
		en = "Right",
	},

	scale_number = {
		en = "Number",
	},
	scale_percent = {
		en = "Percentage",
	},
	scale_boolean = {
		en = "True / False",
	},

	style_mode_fields = {
		en = "Fields",
	},
	style_mode_patch = {
		en = "Style patch",
	},
	value_mode_single = {
		en = "Single",
	},
	value_mode_chain = {
		en = "Chain",
	},

	n_form_segment = {
		en = "Segment %d",
	},

	texture_browser_open_tooltip = {
		en = "Open Texture Browser…",
	},

	value_summary_empty = {
		en = "—",
	},

	browse_ellipsis = {
		en = "...",
	},

	b_form_scale = {
		en = "Scale",
	},
	b_form_scale_factor = {
		en = "Factor",
	},

	b_form_rebind_label = {
		en = "Rebind Source",
	},
	b_form_rebind_rewrite_code = {
		en = "Rewrite Code Bodies",
	},
	b_form_rebind_button_text = {
		en = "Rebind",
	},
	b_form_rebind_button_text_changed = {
		en = "Rebind %d",
	},
	b_form_rebind_button_text_changed_and_skipped = {
		en = "Rebind %d (%d Incompatible)",
	},
	b_form_rebind_button_text_nothing_to_rebind = {
		en = "Nothing To Rebind",
	},

	b_form_mod_owner = {
		en = "Mod",
	},
	b_form_mod_author = {
		en = "Author",
	},
	b_form_mod_version = {
		en = "Version",
	},
	b_form_mod_owner_missing_label = {
		en = "Status",
	},
	b_form_mod_owner_missing = {
		en = "Not installed",
	},
	b_form_mod_requires_label = {
		en = "Needs",
	},
	b_form_mod_requires_note = {
		en = important("This block is switched off because a mod it requires is disabled or uninstalled."),
	},
	b_form_mod_note = {
		en = important("Important: ")
			.. "Duplicating mod blocks means you take ownership of errors and "
			.. "won't be able to update without re-adding this block from the library",
	},
	b_form_mod_duplicate = {
		en = "Duplicate To Edit",
	},

	b_form_rebind_warning = {
		en = "Points every binding on this block to another player, including inactive bindings. There is no undo.",
	},

	block_row_mod_chip_text = {
		en = "[MOD]",
	},
	block_row_mod_chip_tooltip = {
		en = "Shipped by another mod - its nodes are the author's. Duplicate it to edit.",
	},
	block_row_mod_chip_owner = {
		en = "From %s",
	},
	block_row_mod_chip_owner_by = {
		en = "From %s, by %s",
	},
	block_row_mod_chip_owner_missing = {
		en = "From %s (not installed)",
	},

	block_row_hidden_chip_text = {
		en = "[HIDDEN]",
	},
	block_row_hidden_chip_tooltip = {
		en = "Hidden while in editor - change this in Mod Canvas or Top Toolbar",
	},
	canvas_row_title = {
		en = "Mod Canvas",
	},
	canvas_title = {
		en = "Canvas",
	},
	canvas_hide_hidden_tooltip = {
		en = "Hide Hidden Blocks in Editor",
	},
	canvas_show_hidden_tooltip = {
		en = "Show Hidden Blocks in Editor",
	},
	canvas_hide_hidden = {
		en = "Hide Hidden Blocks in Editor",
	},
	canvas_hide_hidden_help = {
		en = lines(
			"Any currently hidden blocks (whether manually hidden or hidden by conditions, code, ",
			"or data sources) will not appear on screen while the editor is open. This means they cannot be hovered ",
			"over or selected. Useful when you have many blocks in one area of the screen."
		),
	},

	dt_canvas_row_title = {
		en = "Darktide Canvas",
	},
	dt_canvas_title = {
		en = "Darktide Canvas",
	},
	dt_canvas_player_1 = {
		en = "Player 1 (You) Panel",
	},
	dt_canvas_player_2 = {
		en = "Player 2 Panel",
	},
	dt_canvas_player_3 = {
		en = "Player 3 Panel",
	},
	dt_canvas_player_4 = {
		en = "Player 4 Panel",
	},
	dt_canvas_dodge_stamina = {
		en = "Dodge/Stamina Meter",
	},
	dt_canvas_peril = {
		en = "Peril Indicator",
	},
	dt_canvas_ability = {
		en = "Ability Container",
	},
	dt_canvas_equipment = {
		en = "Equipment Panel",
	},
	dt_canvas_force_greatsword_charge = {
		en = "Force Greatsword (FGS) Charge Bar",
	},
	dt_canvas_weapon_charge_up = {
		en = "Weapon Charge-up Bar (Power sword, etc.)",
	},
	dt_canvas_weapon_heat = {
		en = "Weapon Heat Bar (Relic blade, etc.)",
	},
	dt_canvas_weapon_special_charges = {
		en = "Special Charge Bar (Mechanicus power sword, etc.)",
	},
	dt_canvas_move_buffs = {
		en = "Move Buff Row",
	},

	toolbar_expand_all_tooltip = {
		en = "Expand All Blocks",
	},
	toolbar_collapse_all_tooltip = {
		en = "Collapse All Blocks",
	},

	panel_blocks_title = {
		en = "Blocks",
	},
	f_row_title = {
		en = "Deleted Items",
	},
	f_row_title_filled = {
		en = "Deleted Items (%d)",
	},
	panel_properties_title = {
		en = "Properties",
	},
	panel_ide_title = {
		en = "Code Editor",
	},
	panel_texture_browser_title = {
		en = "Texture Browser",
	},
	panel_threshold_title = {
		en = "Threshold Designer",
	},
	panel_condition_title = {
		en = "Condition Builder",
	},
	panel_library_title_tooltip = {
		en = "Block Library",
	},
	panel_library_title = {
		en = "Block Library",
	},

	panel_threshold_title_dynamic = {
		en = "Threshold Designer - %s > %s",
	},

	panel_condition_title_dynamic = {
		en = "Condition Builder - %s",
	},

	panel_texture_browser_title_dynamic = {
		en = "Texture Browser - %s (%d)",
	},
	panel_library_title_dynamic = {
		en = "Block Library - %s (%d)",
	},

	panel_library_title_status = {
		en = "%s  -  %s",
	},

	td_mirror_hint = {
		en = "Edit Current and Max in the Value section (Properties Panel).",
	},

	history_undo = {
		en = "Undo",
	},
	history_redo = {
		en = "Redo",
	},
	history_nothing_undo = {
		en = "Nothing to undo",
	},
	history_nothing_redo = {
		en = "Nothing to redo",
	},
	cp_save_colour = {
		en = "Save Colour",
	},
	cp_delete_colour = {
		en = "Delete Colour",
	},
	cp_saved_full = {
		en = "Saved colours are full -- delete one first",
	},
	cp_copied = {
		en = "Copied colour %s",
	},
	cp_clipboard_not_colour = {
		en = "Clipboard is not an { A, R, G, B } colour table",
	},
	cp_values_out_of_range = {
		en = "Colour values must be 0-255",
	},
	cp_pasted = {
		en = "Pasted colour { %d, %d, %d, %d }",
	},

	lib_cat_all = {
		en = "All",
	},
	lib_cat_saved = {
		en = "Saved",
	},

	lib_mod_header_by = {
		en = "%s -- by %s",
	},
	lib_mod_disclaimer = {
		en = "Blocks from another mod run code written by its author. Add them at your own discretion.",
	},
	lib_details_empty = {
		en = "Select a block to see what it reads.",
	},
	lib_read_from = {
		en = "Read from",
	},
	lib_add_to_canvas = {
		en = "Add to Canvas",
	},
	lib_add_folder_to_canvas = {
		en = "Add Folder to Canvas",
	},

	lib_update_to_current = {
		en = "Update %d on Canvas",
	},
	lib_delete = {
		en = "Delete",
	},
	lib_delete_folder = {
		en = "Delete Folder",
	},

	lib_confirm_prompt = {
		en = "Are you sure?",
	},
	lib_confirm_delete = {
		en = "Confirm Delete",
	},
	lib_saved_folder = {
		en = "Saved folder",
	},
	lib_saved_block = {
		en = "Saved block",
	},
	lib_tags_line = {
		en = "Tags: %s",
	},
	lib_reads_nothing = {
		en = "Reads: nothing (no bindings)",
	},
	lib_requires_line = {
		en = "Needs: %s",
	},
	lib_requires_missing = {
		en = "Needs (not installed): %s",
	},
	lib_reads_line = {
		en = "Reads: %s",
	},
	lib_saved_line = {
		en = "Saved %s",
	},

	lib_node_count_one = {
		en = "%d node",
	},
	lib_node_count_many = {
		en = "%d nodes",
	},
	lib_block_count_one = {
		en = "%d block",
	},
	lib_block_count_many = {
		en = "%d blocks",
	},

	lib_folder_count_line = {
		en = "%s, %s",
	},
	lib_status_could_not_load = {
		en = "could not load",
	},
	lib_status_add_failed = {
		en = "add failed",
	},
	lib_status_added = {
		en = "added",
	},
	lib_status_added_skipped = {
		en = "added (%d binding(s) not re-pointed)",
	},
	lib_status_added_folder = {
		en = "added %d block(s) to '%s'",
	},
	lib_status_updated = {
		en = "Updated %d block(s)",
	},
	lib_status_update_failed = {

		en = "Update failed - see the mod log",
	},
	lib_status_delete_failed = {
		en = "delete failed",
	},
	lib_status_deleted = {
		en = "deleted",
	},

	cb_open_tooltip = {
		en = "Open Condition Builder",
	},
	cb_open_text_no_conditions = {
		en = "No Conditions",
	},
	cb_open_text_condition = {
		en = "1 condition",
	},
	cb_open_text_conditions = {
		en = "%d conditions",
	},
	cb_if = {
		en = "If",
	},
	cb_join_and = {
		en = "and",
	},
	cb_join_or = {
		en = "or",
	},

	cb_is = {
		en = "Is",
	},
	cb_is_not = {
		en = "Is Not",
	},
	cb_remove_row = {
		en = "x",
	},
	cb_add_condition = {
		en = "Add condition",
	},
	cb_linger = {
		en = "[seconds] Linger for",
	},
	cb_linger_tooltip = {
		en = "Seconds to keep visible after change from true to false",
	},
	cb_delay = {
		en = "[seconds] Delay for",
	},
	cb_delay_tooltip = {
		en = "Seconds to keep hidden after change from false to true",
	},

	cond_op_true = {
		en = "true",
	},
	cond_op_false = {
		en = "false",
	},
	cond_op_equal_to = {
		en = "equal to",
	},
	cond_op_below = {
		en = "below",
	},
	cond_op_at_most = {
		en = "at most",
	},
	cond_op_above = {
		en = "above",
	},
	cond_op_at_least = {
		en = "at least",
	},
	cond_op_between = {
		en = "between",
	},
	cond_op_changed = {
		en = "changed",
	},
	cond_op_increased = {
		en = "increased",
	},
	cond_op_decreased = {
		en = "decreased",
	},

	cond_sentence_and = {
		en = "and",
	},
	cond_sentence_or = {
		en = "or",
	},
	cond_sentence_is = {
		en = "is",
	},
	cond_sentence_is_not = {
		en = "is not",
	},

	error_mod_is_not_installed = {
		en = "is not installed"
	},
	error_mod_api_has_changed = {
		en = "API has changed - inform HUD Studio author"
	},
	error_mod_is_not_enabled = {
		en = "is not enabled"
	},
}
