---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_block_form then
	return mod.hud_studio_block_form
end

local Visibility = mod:core(mod.hud_studio_visibility, "blocks/visibility")
local Rebind = mod:core(mod.hud_studio_rebind, "document/rebind")
local Registry = mod:core(mod.hud_studio_source_registry, "engine/registry")
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")
local FieldOptions = mod:core(mod.hud_studio_field_options, "hud/editor/forms/field_options")
local Block = mod:core(mod.hud_studio_block, "blocks/block")
local Store = mod:core(mod.hud_studio_store, "document/store")
local Schema = mod:core(mod.hud_studio_schema, "document/schema")
local TextField = mod:core(mod.hud_studio_text_field, "hud/editor/editors/text_field")
local Session = mod:core(mod.hud_studio_session, "document/session")
local BlockLibrary = mod:core(mod.hud_studio_block_library, "document/block_library")

local VISIBLE_MODE_OPTIONS = {
	{ value = "conditions", text = mod:localize("field_mode_conditions") },
	{ value = "source", text = mod:localize("field_mode_source") },
	{ value = "code", text = mod:localize("field_mode_code") },
}

local GAMEMODE_OPTIONS = {
	{ value = "mission", text = mod:localize("gamemode_mission") },
	{ value = "mourningstar", text = mod:localize("gamemode_hub") },
	{ value = "meatgrinder", text = mod:localize("gamemode_practice") },
}

local CLASS_OPTIONS = {
	{ value = "veteran", text = mod:localize("class_veteran") },
	{ value = "psyker", text = mod:localize("class_psyker") },
	{ value = "zealot", text = mod:localize("class_zealot") },
	{ value = "ogryn", text = mod:localize("class_vet") },
	{ value = "adamant", text = mod:localize("class_arbites") },
	{ value = "broker", text = mod:localize("class_hive_scum") },
	{ value = "cryptic", text = mod:localize("class_skitarii") },
}

local GRID_MODE_OPTIONS = {
	{ value = "fixed", text = mod:localize("field_mode_fixed") },
}

local GRID_MIN = 0
local GRID_MAX = 100

local rich_text = mod.dl.str.rich_text

local BlockForm = {}

local SCALE_MODE_OPTIONS = {
	{ value = "fixed", text = mod:localize("field_mode_fixed") },
	{ value = "code", text = mod:localize("field_mode_code") },
}

local SCALE_DEFAULT = Block.SCALE_DEFAULT

local scale_is_default = Block.scale_is_default

local function scale_value(block)
	local rec = block.scale
	local value = rec and rec.value
	return (type(value) == "number" and value) or SCALE_DEFAULT
end

local function set_scale_mode(block, mode)
	local rec = block.scale or {}
	rec.value = scale_value(block)
	if mode == "code" then
		rec.kind = "code"
		if rec.body == nil then
			rec.body = ""
		end
		block.scale = rec
	else
		rec.kind = "fixed"

		block.scale = (not scale_is_default(rec)) and rec or nil
	end
end

---@param block Block
local function scale_group(block)
	local function mode_get()
		local rec = block.scale
		return (rec and rec.kind == "code") and "code" or "fixed"
	end

	return {
		group = true,
		field = "scale",
		label = mod:localize("b_form_scale"),
		mode = {
			kind = "dropdown",
			rebinds = true, 
			options = SCALE_MODE_OPTIONS,
			get = mode_get,
			set = function(v)
				set_scale_mode(block, v)
			end,
		},
		controls = {
			{
				kind = "numeric",
				label = mod:localize("b_form_scale_factor"),
				token = "block/scale.value",
				step = 0.05,
				min = Block.SCALE_MIN,
				max = Block.SCALE_MAX,
				decimals = 2,
				hidden = function()
					return mode_get() ~= "fixed"
				end,
				get = function()
					return scale_value(block)
				end,

				set = function(value)
					local rec = block.scale or {}
					rec.kind = "fixed"
					rec.value = value
					block.scale = (not scale_is_default(rec)) and rec or nil
				end,
			},
			{
				kind = "button",

				text = function()
					local err = block.scale_error and block:scale_error()
					return mod:localize("ide_open_button_text", err and mod:localize("ide_contains_errors") or "")
				end,
				action = "open_ide",
				ide_block_scale = true,
				hidden = function()
					return mode_get() ~= "code"
				end,
			},
		},
	}
end

local function grid_number(block, field, label)
	return {
		kind = "numeric",
		label = label,
		token = "block/grid." .. field,
		half = true,
		step = 1,
		min = GRID_MIN,
		max = GRID_MAX,
		decimals = 0,
		get = function()
			return block[field] or 0
		end,
		set = function(value)
			block[field] = value
		end,
	}
end

local function grid_group(block)
	return {
		group = true,
		field = "grid",
		label = mod:localize("grid"),
		mode = {
			kind = "dropdown",
			options = GRID_MODE_OPTIONS,
			get = function()
				return "fixed"
			end,
			set = function() end,
		},
		controls = {
			grid_number(block, "grid_rows", mod:localize("rows")),
			grid_number(block, "grid_cols", mod:localize("columns")),
		},
	}
end

local function accept_boolean(hint)
	return DataTypes.type_of(hint) == "boolean"
end

local function source_has_boolean(source)
	return FieldOptions.any(source, accept_boolean)
end

---@param accept fun(source: Source): boolean|nil
local function source_options(accept)
	local grouped = Registry.by_category()
	local cats = {}
	for cat in pairs(grouped) do
		cats[#cats + 1] = cat
	end
	table.sort(cats)

	local out = {}
	for c = 1, #cats do
		local list = grouped[cats[c]]
		table.sort(list, function(a, b)
			return (a.label or a.id) < (b.label or b.id)
		end)
		for i = 1, #list do
			if not accept or accept(list[i]) then
				out[#out + 1] = { value = list[i].id, text = list[i].label or list[i].id }
			end
		end
	end
	return out
end

local function boolean_source_options()
	return source_options(source_has_boolean)
end

local function boolean_field_options(source_id)
	return FieldOptions.build(source_id, accept_boolean)
end

local function first_field_value(options)
	for i = 1, #options do
		if options[i].value ~= nil and not options[i].group then
			return options[i].value
		end
	end
	return nil
end

local function kept_field_value(options, current)
	for i = 1, #options do
		if options[i].value ~= nil and not options[i].group and options[i].value == current then
			return current
		end
	end
	return first_field_value(options)
end

local function set_visible_mode(block, mode)
	if mode == "code" then
		local rec = block.visible or {}
		rec.kind = "code"
		if rec.body == nil then
			rec.body = ""
		end
		block.visible = rec
	elseif mode == "source" then
		local rec = block.visible or {}
		rec.kind = "source"
		if not rec.source then
			local srcs = boolean_source_options()
			rec.source = srcs[1] and srcs[1].value
			rec.field = first_field_value(boolean_field_options(rec.source))
		end
		block.visible = rec
	else
		Visibility.ensure_block_conditions(block)
	end
end

local function visible_group(block)
	local function mode_get()
		return Visibility.block_mode(block)
	end

	return {
		group = true,
		field = "visible",
		label = mod:localize("field_label_visible"),
		mode = {
			kind = "dropdown",
			rebinds = true, 
			options = VISIBLE_MODE_OPTIONS,
			get = mode_get,
			set = function(v)
				set_visible_mode(block, v)
			end,
		},
		controls = {

			{
				kind = "dropdown",
				label = mod:localize("field_label_source"),
				rebinds = true,
				options = boolean_source_options,
				hidden = function()
					return mode_get() ~= "source"
				end,
				get = function()
					local rec = block.visible
					return rec and rec.source
				end,
				set = function(v)
					local rec = block.visible
					if not rec or rec.kind ~= "source" then
						return
					end
					local previous_field = rec.field
					rec.source = v

					rec.field = kept_field_value(boolean_field_options(v), previous_field)
				end,
			},
			{
				kind = "dropdown",
				label = mod:localize("field_label_field"),
				rebinds = true,
				options = function()
					local rec = block.visible
					return (rec and boolean_field_options(rec.source)) or {}
				end,
				hidden = function()
					return mode_get() ~= "source"
				end,
				get = function()
					local rec = block.visible
					return rec and rec.field
				end,
				set = function(v)
					local rec = block.visible
					if rec and rec.kind == "source" then
						rec.field = v
					end
				end,
			},

			{
				kind = "conditions",
				field = "visible",
				cb_node = nil,
				hidden = function()
					return mode_get() ~= "conditions"
				end,
				get = function()
					local rec = block.visible
					return rec and rec.conditions or nil
				end,
			},
			{
				kind = "button",

				text = function()
					local err = block.binding_error and block:binding_error(nil)
					return err and mod:localize("ide_open_with_errors") or mod:localize("ide_open")
				end,
				action = "open_ide",
				ide_block_visible = true,
				hidden = function()
					return mode_get() ~= "code"
				end,
			},
		},
	}
end

---@param block Block
local function script_row(block)
	return {
		kind = "button",
		text = function()
			if block.script_error and block:script_error() then
				return mod:localize("ide_open_with_errors")
			end
			local body = block.script and block.script.body
			return (body and body:find("%S")) and mod:localize("script_edit") or mod:localize("script_add")
		end,
		action = "open_ide",
		ide_block_script = true,
	}
end

---@param block Block
---@param field string             "gamemodes" | "classes"
---@param left_label string
---@param options table[]          { { value, text }, ... }
local function filter_checklist(block, field, left_label, options)
	local function is_on(value)
		local set = block[field]
		return set ~= nil and set[value] == true
	end

	local function toggle(value)
		local set = block[field] or {}
		set[value] = (not set[value]) or nil
		block[field] = next(set) ~= nil and set or nil
	end

	return {
		kind = "checklist",
		left_label = left_label,
		items = options,
		is_on = is_on,
		toggle = toggle,
	}
end

---@param block Block
---@return table[]
local function visibility_rows(block)
	local rows = { visible_group(block) }
	local players = Visibility.player_checklists(block)
	for i = 1, #players do
		rows[#rows + 1] = players[i]
	end
	rows[#rows + 1] = filter_checklist(block, "gamemodes", mod:localize("gamemodes"), GAMEMODE_OPTIONS)
	rows[#rows + 1] = filter_checklist(block, "classes", mod:localize("classes"), CLASS_OPTIONS)
	return rows
end

local REBIND_WARNING = mod:localize("b_form_rebind_warning")

local rebind = { block = nil, from = nil, to = nil, code = false }

local function used_source_options()
	local ids = rebind.block and Rebind.sources_used(rebind.block) or {}
	local out = {}
	for i = 1, #ids do
		local source = Registry.get(ids[i])
		out[i] = {
			value = ids[i],
			text = source and source.label or ids[i],
		}
	end
	return out
end

local function rebind_button_text()
	if not (rebind.from and rebind.to) or rebind.from == rebind.to then
		return mod:localize("b_form_rebind_button_text")
	end
	local changed, skipped = Rebind.run(rebind.block, rebind.from, rebind.to, rebind.code, true)
	if changed == 0 then
		return mod:localize("b_form_rebind_button_text_nothing_to_rebind")
	elseif skipped > 0 then
		return mod:localize("b_form_rebind_button_text_changed_and_skipped", changed, skipped)
	end
	return mod:localize("b_form_rebind_button_text_changed", changed)
end

local function rebind_group()
	return {
		group = true,
		field = "rebind",
		label = mod:localize("b_form_rebind_label"),
		mode = {
			kind = "dropdown",
			no_undo = true,
			options = used_source_options,
			get = function()
				return rebind.from
			end,
			set = function(v)
				rebind.from = v
			end,
		},
		controls = {
			{
				kind = "dropdown",
				no_undo = true,
				label = mod:localize("field_label_to"),
				options = function()
					return source_options(nil)
				end,
				get = function()
					return rebind.to
				end,
				set = function(v)
					rebind.to = v
				end,
			},
			{
				kind = "checkbox",
				no_undo = true,
				label = mod:localize("b_form_rebind_rewrite_code"),
				get = function()
					return rebind.code
				end,
				set = function(on)
					rebind.code = on and true or false
				end,
			},
			{
				kind = "button",
				text = rebind_button_text,
				action = "rebind_sources",
			},
		},
	}
end

local function rebind_warning_row()
	return {
		kind = "note",
		wrap = true,
		value = function()
			return REBIND_WARNING
		end,
	}
end

local library_save = { block = nil, name = nil }

local LIBRARY_NAME_TOKEN = "block/library_name"

local function library_save_name()
	local typed = library_save.name
	if typed and typed ~= "" then
		return Schema.slugify(typed)
	end
	local block = library_save.block
	return Schema.slugify((block and (block.label or block.name)) or "")
end

local function library_save_button_text()
	if TextField.is_focused(LIBRARY_NAME_TOKEN) then
		return mod:localize("lib_save_form_await_blur")
	end
	local name = library_save_name()
	if name == "" then
		return mod:localize("lib_save_form_missing_name")
	end
	if Store.library_exists(name) then
		return mod:localize("lib_save_form_overwrite", name)
	end
	return mod:localize("lib_save_form_save")
end

local function library_save_group()
	return {
		group = true,
		field = "save_to_library",
		label = mod:localize("lib_save_form_save"),
		mode = {
			kind = "text",
			token = LIBRARY_NAME_TOKEN,
			no_undo = true,
			get = function()
				return library_save.name or ""
			end,
			set = function(v)
				library_save.name = v
			end,
		},
		controls = {
			{
				kind = "button",
				text = library_save_button_text,
				action = "save_to_library",
				disabled = function()
					return TextField.is_focused(LIBRARY_NAME_TOKEN) or library_save_name() == ""
				end,
			},

			{
				kind = "button",
				trailing = true,
				text = mod:localize("browse_ellipsis"),
				tooltip = mod:localize("lib_open_tooltip"),
				action = "open_block_library",
			},
		},
	}
end

local MAX_LABEL_LENGTH = 48

local MAX_SUMMARY_LENGTH = 300

local MAX_MOD_NAME_LENGTH = 64

local MAX_CSV_ITEM_LENGTH = 48

local MAX_CSV_ITEMS = 24

---@param text string
---@param limit integer
---@return string
local function capped(text, limit)
	return #text > limit and text:sub(1, limit) or text
end

---@param text string?
---@return string[]?
local function split_csv(text)
	local list = {}
	for item in tostring(text or ""):gmatch("[^,]+") do
		local trimmed = item:gsub("^%s+", ""):gsub("%s+$", "")
		if trimmed ~= "" and #list < MAX_CSV_ITEMS then
			list[#list + 1] = capped(trimmed, MAX_CSV_ITEM_LENGTH)
		end
	end

	return #list > 0 and list or nil
end

---@param list string[]?
---@return string
local function join_csv(list)
	return type(list) == "table" and table.concat(list, ", ") or ""
end

---@param block Block
---@param field string
---@param label string
---@param from_stored fun(value: any): string
---@param to_stored fun(text: string): any
local function export_text_row(block, field, label, from_stored, to_stored)
	return {
		kind = "text",
		label = label,
		token = "block/export." .. field,
		get = function()
			return from_stored(block[field])
		end,
		set = function(text)
			block[field] = to_stored(text)
		end,
	}
end

---@param text string
---@param limit integer
---@return string?
local function trimmed_or_nil(text, limit)
	local trimmed = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	return trimmed ~= "" and capped(trimmed, limit) or nil
end

---@param key string    loc key
---@param limit integer? the field's length cap, where the line quotes one
local function help_row(key, limit)
	return {
		kind = "note",
		wrap = true,
		value = function()
			return limit and mod:localize(key, limit) or mod:localize(key)
		end,
	}
end

local EXPORT_MOD_TOKEN = "block/export.export_mod"

---@param block Block?
---@return string
local function export_mod_name(block)
	return Schema.slugify((block and block.export_mod) or "")
end

---@param block Block?
---@return string path, boolean mod_exists, boolean file_exists
local function export_target(block)
	return BlockLibrary.export_target(library_save_name(), export_mod_name(block))
end

---@param block Block
local function export_button_text(block)
	return function()
		if TextField.is_focused(EXPORT_MOD_TOKEN) then
			return mod:localize("lib_save_form_await_blur")
		end
		local mod_name = export_mod_name(block)
		if mod_name == "" then
			return mod:localize("export_form_missing_mod")
		end
		local _, mod_exists, file_exists = export_target(block)
		if not mod_exists then
			return mod:localize("export_form_no_such_mod", mod_name)
		end
		if file_exists then
			return mod:localize("lib_save_form_overwrite", library_save_name() .. ".lua")
		end
		return mod:localize("export_form_export", mod_name)
	end
end

---@param block Block
local function export_rows(block)
	return {
		export_text_row(block, "label", mod:localize("field_label_label", MAX_LABEL_LENGTH), function(value)
			return tostring(value or "")
		end, function(text)

			Session.set_block_label(block, capped(tostring(text or ""), MAX_LABEL_LENGTH))
			return block.label
		end),
		help_row("field_help_label"),
		export_text_row(block, "summary", mod:localize("field_label_summary", MAX_SUMMARY_LENGTH), function(value)
			return tostring(value or "")
		end, function(text)
			return trimmed_or_nil(text, MAX_SUMMARY_LENGTH)
		end),
		help_row("field_help_summary"),
		{
			kind = "numeric",
			label = mod:localize("field_label_mod_version"),
			token = "block/export.mod_version",
			step = 1,
			min = 1,
			max = 9999,
			decimals = 0,
			get = function()
				return block.mod_version or 1
			end,
			set = function(value)

				local version = math.floor(value or 1)
				block.mod_version = version > 1 and version or nil
			end,
		},
		help_row("field_help_mod_version"),
		export_text_row(block, "requires", mod:localize("field_label_requires", MAX_CSV_ITEMS), join_csv, split_csv),
		help_row("field_help_requires"),
		export_text_row(block, "tags", mod:localize("field_label_tags", MAX_CSV_ITEMS), join_csv, split_csv),
		help_row("field_help_tags"),
		{
			group = true,
			field = "export_to_mod",
			label = mod:localize("field_label_mod_name"),
			mode = {
				kind = "text",
				token = EXPORT_MOD_TOKEN,
				get = function()
					return block.export_mod or ""
				end,
				set = function(text)
					block.export_mod = trimmed_or_nil(text, MAX_MOD_NAME_LENGTH)
				end,
			},
			controls = {
				{
					kind = "button",
					text = export_button_text(block),
					action = "export_to_mod",
					disabled = function()
						if TextField.is_focused(EXPORT_MOD_TOKEN) or export_mod_name(block) == "" then
							return true
						end

						local _, mod_exists = export_target(block)
						return not mod_exists
					end,
				},
			},
		},
		help_row("field_help_mod_name"),

		{
			kind = "note",
			wrap = true,
			value = function()
				local mod_name = export_mod_name(block)
				if mod_name == "" then
					return mod:localize("export_form_note_no_mod")
				end
				local path, mod_exists = export_target(block)
				if not mod_exists then
					return mod:localize("export_form_note_missing_mod", mod_name)
				end
				return path
			end,
		},
	}
end

---@return Block? block, string mod_name, string name
function BlockForm.pending_export()
	return library_save.block, export_mod_name(library_save.block), library_save_name()
end

---@return Block? block, string name
function BlockForm.pending_library_save()
	return library_save.block, library_save_name()
end

---@return Block? block, string? from, string? to, boolean code
function BlockForm.pending_rebind()
	return rebind.block, rebind.from, rebind.to, rebind.code
end

function BlockForm.clear_rebind()
	rebind.from, rebind.to = nil, nil
end

local function origin_note(label, value)
	return {
		kind = "note",
		label = label,
		value = function()
			return value
		end,
	}
end

local function mod_rows(block)
	local origin = block.origin or {}
	local owner = BlockLibrary.owner_info(origin.mod)
	local rows = {
		origin_note(mod:localize("b_form_mod_owner"), owner.label),
	}
	if owner.author and owner.author ~= "" then
		rows[#rows + 1] = origin_note(mod:localize("b_form_mod_author"), owner.author)
	end
	rows[#rows + 1] = origin_note(mod:localize("b_form_mod_version"), tostring(origin.version or 1))
	if not owner.installed then
		rows[#rows + 1] =
			origin_note(mod:localize("b_form_mod_owner_missing_label"), mod:localize("b_form_mod_owner_missing"))
	end

	local missing = block.missing_requires and block:missing_requires()
	if missing then
		rows[#rows + 1] = origin_note(mod:localize("b_form_mod_requires_label"), table.concat(missing, ", "))
		rows[#rows + 1] = {
			kind = "note",
			wrap = true,
			value = function()
				return mod:localize("b_form_mod_requires_note")
			end,
		}
	end

	rows[#rows + 1] = {
		kind = "note",
		wrap = true,
		value = function()
			return mod:localize("b_form_mod_note")
		end,
	}
	rows[#rows + 1] = {
		kind = "button",
		text = mod:localize("b_form_mod_duplicate"),
		action = "duplicate_to_edit",
	}
	return rows
end

---@param block Block
---@return FormSection[]
function BlockForm.build(block)

	if rebind.block ~= block then
		rebind.block, rebind.from, rebind.to = block, nil, nil
	end

	if library_save.block ~= block then
		library_save.block, library_save.name = block, nil
	end

	if Session.is_mod_block(block) then
		return {
			{
				key = "mod",
				title = mod:localize("section_mod_block"),
				flat = true,
				rows = mod_rows(block),
			},
			{
				key = "block",
				title = mod:localize("section_blocks"),
				flat = true,
				rows = {

					scale_group(block),
				},
			},
		}
	end

	return {
		{
			key = "block",
			title = mod:localize("section_blocks"),
			flat = true,
			rows = {
				library_save_group(),
				scale_group(block),
				grid_group(block),
			},
		},
		{
			key = "script",
			title = mod:localize("section_script"),
			rows = {
				script_row(block),
			},
		},
		{
			key = "visibility",
			title = mod:localize("section_visibility"),
			rows = visibility_rows(block),
		},
		{
			key = "transitions",
			title = mod:localize("section_transitions"),
			rows = {
				{
					kind = "checkbox",
					label = mod:localize("field_label_fade_in"),
					side_label = true,
					token = "block/transition.fade_in.enabled",
					half = true,
					get = function()
						local tr = block.transition
						return tr and tr.fade_in and true or false
					end,
					set = function(enabled)
						block.transition = block.transition or {}
						if enabled then
							block.transition.fade_in = block.transition.fade_in or 0.2
						else
							block.transition.fade_in = nil
						end
					end,
				},
				{
					kind = "numeric",
					label = " ",
					token = "block/transition.fade_in.duration",
					half = true,
					step = 0.05,
					min = 0.05,
					max = 2,
					decimals = 2,
					get = function()
						local tr = block.transition
						return (tr and tr.fade_in) or 0.2
					end,
					set = function(v)
						block.transition = block.transition or {}
						block.transition.fade_in = v > 0 and v or nil
					end,
					hidden = function()
						local tr = block.transition
						return not (tr and tr.fade_in)
					end,
				},
				{
					kind = "checkbox",
					label = mod:localize("field_label_fade_out"),
					side_label = true,
					token = "block/transition.fade_out.enabled",
					half = true,
					get = function()
						local tr = block.transition
						return tr and tr.fade_out and true or false
					end,
					set = function(enabled)
						block.transition = block.transition or {}
						if enabled then
							block.transition.fade_out = block.transition.fade_out or 0.2
						else
							block.transition.fade_out = nil
						end
					end,
				},
				{
					kind = "numeric",
					label = " ",
					token = "block/transition.fade_out.duration",
					half = true,
					step = 0.05,
					min = 0.05,
					max = 2,
					decimals = 2,
					get = function()
						local tr = block.transition
						return (tr and tr.fade_out) or 0.2
					end,
					set = function(v)
						block.transition = block.transition or {}
						block.transition.fade_out = v > 0 and v or nil
					end,
					hidden = function()
						local tr = block.transition
						return not (tr and tr.fade_out)
					end,
				},
				{
					kind = "dropdown",
					label = mod:localize("field_label_easing"),
					side_label = true,
					token = "block/transition.ease",
					get = function()
						local tr = block.transition
						return (tr and tr.ease) or "linear"
					end,
					set = function(v)
						block.transition = block.transition or {}
						block.transition.ease = v ~= "linear" and v or nil
					end,
					options = {
						{ text = mod:localize("easing_linear"), value = "linear" },
						{ text = mod:localize("easing_in_out"), value = "in_out" },
					},
					hidden = function()
						local tr = block.transition
						return not (tr and (tr.fade_in or tr.fade_out))
					end,
				},
			},
		},
		{
			key = "tools",
			title = mod:localize("section_tools"),
			rows = {
				rebind_group(),
				rebind_warning_row(),
			},
		},

		{
			key = "export",
			title = mod:localize("section_export_to_mod"),
			rows = export_rows(block),
		},
	}
end

mod.hud_studio_block_form = BlockForm

return BlockForm
