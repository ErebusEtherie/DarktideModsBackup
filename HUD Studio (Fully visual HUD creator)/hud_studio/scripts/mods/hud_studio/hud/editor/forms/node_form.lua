---@class mod : DL_Mod
local mod = get_mod("hud_studio")

if mod.hud_studio_node_form then
	return mod.hud_studio_node_form
end

local Constants = mod:core(mod.editor_constants, "hud/editor/constants")
local PANEL = Constants.PANEL

local Registry = mod:core(mod.hud_studio_source_registry, "engine/registry")
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")
local FieldOptions = mod:core(mod.hud_studio_field_options, "hud/editor/forms/field_options")
local Visibility = mod:core(mod.hud_studio_visibility, "blocks/visibility")
local Thresholds = mod:core(mod.hud_studio_thresholds, "blocks/thresholds")
local Session = mod:core(mod.hud_studio_session, "document/session")

local TextInput = mod:core(mod.hud_studio_text_input_component, "hud/editor/elements/field/text_input")
local Numeric = mod:core(mod.hud_studio_numeric_component, "hud/editor/elements/field/numeric")
local Dropdown = mod:core(mod.hud_studio_dropdown_component, "hud/editor/elements/field/dropdown")
local Checkbox = mod:core(mod.hud_studio_checkbox_component, "hud/editor/elements/field/checkbox")
local Checklist = mod:core(mod.hud_studio_checklist_component, "hud/editor/elements/field/checklist")
local ThresholdBar =
	mod:core(mod.hud_studio_threshold_bar_component, "hud/editor/elements/threshold_designer/threshold_bar")
local Rgba = mod:core(mod.hud_studio_rgba_component, "hud/editor/elements/field/rgba")

---@class FormControl : EditorDoc
---@field kind string          "text"|"numeric"|"dropdown"|"checkbox"|"rgba"|"button"|"readonly"|"note"
---@field label string|nil
---@field disabled boolean|nil  draws as normal but takes no input (mirrors a value owned elsewhere)
---@field text string|nil        button face text
---@field action string|nil      button semantic action the editor handles (e.g. "delete_node")
---@field tooltip string|nil     button: hover label, for a face too small to carry its wording
---@field trailing boolean|nil   laid on the previous control's line, pinned right at a fixed square width
---@field token string|nil      focus id for text/numeric entry (unique per node)
---@field get fun():any|nil
---@field set fun(v:any)|nil
---@field value fun():string|nil  readonly/note display text
---@field wrap boolean|nil       note: word-wrap the text to the column (help text) instead of one line
---@field options table[]|fun():table[]|nil  dropdown options, or a function returning them (cascading)
---@field step number|nil        numeric
---@field min number|nil
---@field max number|nil
---@field decimals number|nil
---@field right_column boolean|nil  plain row: laid out in the group right column (indented past the mode dropdown), so it reads as part of the group above it
---@field hidden fun():boolean|nil  layout skips the row/control while this returns true (dynamic show/hide)
---@field rebinds boolean|nil    set() changes a binding, so the host must recompile the block after

---@class FormGroup : EditorDoc
---@field group boolean          true (marks a group row for layout)
---@field field string
---@field label string
---@field mode FormControl    the left-column binding-mode dropdown
---@field controls FormControl[]  every possible right-column control (hidden-gated by mode)
---@field hidden fun():boolean|nil   whole-group hide (e.g. under the style-patch toggle)

---@class FormSection : EditorDoc
---@field key string
---@field title string
---@field flat boolean|nil       -- no collapsible header; rows sit at the panel root, always shown
---@field rows table[]           -- FormControl (plain row) or FormGroup

---@class NodeForm
local NodeForm = {}

local function ensure_style(node)
	node.style = node.style or {}
	return node.style
end

local function ensure_values(node)
	node.values = node.values or {}
	return node.values
end

local function cap_first(s)
	return (s:gsub("^%l", string.upper))
end

local function node_color(node)
	local style, values = node.style or {}, node.values or {}
	return style.color or values.color
end

local function set_node_color(node, color)
	local style = ensure_style(node)
	style.color = color
end

local function style_number(node, prefix, field, label, opts)
	return {
		kind = "numeric",
		label = label,
		token = prefix .. "/style." .. field,
		step = opts.step,
		min = opts.min,
		max = opts.max,
		decimals = opts.decimals or 0,
		get = function()
			return (node.style and node.style[field]) or opts.default or 0
		end,
		set = function(v)
			ensure_style(node)[field] = v
		end,
	}
end

local function value_number(node, prefix, field, label, opts)
	return {
		kind = "numeric",
		label = label,
		token = prefix .. "/value." .. field,
		step = opts.step or 1,
		min = opts.min,
		max = opts.max,
		decimals = opts.decimals or 0,
		get = function()
			return (node.values and node.values[field]) or opts.default or 0
		end,
		set = function(v)
			ensure_values(node)[field] = v
		end,
	}
end

local function style_size_number(node, prefix, index, label)
	return {
		kind = "numeric",
		label = label,

		half = true,
		token = prefix .. "/style.size." .. index,
		step = 1,
		min = 0,
		max = 4000,
		decimals = 0,
		get = function()
			local size = node.style and node.style.size
			return (size and size[index]) or 0
		end,
		set = function(v)
			local style = ensure_style(node)
			style.size = style.size or { 0, 0 }
			style.size[index] = v
		end,
	}
end

local POSITION_LIMIT = 10000

local function offset_number(node, prefix, index, label)
	return {
		kind = "numeric",
		label = label,

		half = true,
		token = prefix .. "/offset." .. index,
		step = 1,
		min = -POSITION_LIMIT,
		max = POSITION_LIMIT,
		decimals = 0,
		get = function()
			local offset = node.offset
			return (offset and offset[index]) or 0
		end,
		set = function(v)
			node.offset = node.offset or { 0, 0 }
			node.offset[index] = v
		end,
	}
end

local FIELD_TYPES = {
	visible = "bool",
	color = "color",
	bg_color = "color",
	outline_color = "color",
	size = "vector",

	offset = "vector",
	font_type = "enum",
	font_size = "number",
	text = "text",
	material = "material",

	material_fallback = "material",
	color_fallback = "color",
	current = "number",
	max = "number",
	segments = "number",
	segment_gap = "number",
	orientation = "enum",
	shape = "enum",
	align = "enum",
	uvs = "dropdown",
	clip = "clip",
	rotation = "number",
	shadow = "bool",
}

local FIELD_LABELS = {
	visible = mod:localize("field_label_visible"),
	color = mod:localize("field_label_color"),
	bg_color = mod:localize("field_label_bg_color"),
	outline_color = mod:localize("field_label_outline_color"),
	size = mod:localize("field_label_size"),
	offset = mod:localize("field_label_offset"),
	font_type = mod:localize("field_label_font_type"),
	font_size = mod:localize("field_label_font_size"),
	text = mod:localize("field_label_text"),
	material = mod:localize("field_label_material"),
	material_fallback = mod:localize("field_label_material_fallback"),
	color_fallback = mod:localize("field_label_color_fallback"),
	current = mod:localize("field_label_current"),
	max = mod:localize("field_label_max"),
	segments = mod:localize("field_label_segments"),
	segment_gap = mod:localize("field_label_segment_gap"),
	orientation = mod:localize("field_label_orientation"),
	shape = mod:localize("field_label_shape"),
	align = mod:localize("field_label_align"),
	uvs = mod:localize("field_label_uvs"),
	clip = mod:localize("field_label_clip"),
	rotation = mod:localize("field_label_rotation"),
	shadow = mod:localize("field_label_shadow"),
}

local THRESHOLD_TYPES = {
	color = true,
}

local function has_material(node)
	local m = node.values and node.values.material
	if m ~= nil and m ~= "" then
		return true
	end

	local bind = node.callbacks and node.callbacks.value and node.callbacks.value.material
	return bind ~= nil and (bind.kind == "source" or bind.kind == "code")
end

local function material_is_source(node)
	local bind = node.callbacks and node.callbacks.value and node.callbacks.value.material
	return bind ~= nil and bind.kind == "source"
end

local function is_curved(node)
	return node.style ~= nil and node.style.shape == "curved"
end

local FIELD_VISIBLE_WHEN = {
	uvs = has_material,
	clip = has_material,
	rotation = has_material,

	material_fallback = material_is_source,
	color_fallback = material_is_source,
	outline_color = is_curved,
}

local function shape_prim(shape)
	return DataTypes.type_of(shape)
end

local function source_field_hint(source, field_path)
	if not (source and source.fields and field_path) then
		return nil
	end
	local group, leaf = field_path:match("^([^.]+)%.(.+)$")
	if group then
		local g = source.fields[group]
		return (type(g) == "table" and g[leaf]) or nil
	end
	return source.fields[field_path]
end

local function type_accepts(target_type, prim)
	if target_type == "number" then
		return prim == "number" or prim == "integer"
	elseif target_type == "text" then
		return prim == "string" or prim == "number" or prim == "integer"
	elseif target_type == "bool" then

		return prim == "boolean"
	elseif target_type == "color" then

		return prim == "rgba"
	elseif target_type == "material" then

		return prim == "material"
	elseif target_type == "operand" then

		return prim == "string" or prim == "number" or prim == "integer" or prim == "boolean"
	end
	return false
end

local accept_by_type = {}
local function accept_for(target_type)
	local accept = accept_by_type[target_type]
	if not accept then
		accept = function(hint)
			return type_accepts(target_type, shape_prim(hint))
		end
		accept_by_type[target_type] = accept
	end
	return accept
end

local function source_field_options(source_id, target_type)
	return FieldOptions.build(source_id, accept_for(target_type))
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

local function uv_dropdown_options()
	local uv_values = {
		"flip_none",
		"flip_x",
		"flip_y",
		"flip_xy",
	}

	local uvs = {}

	for idx, value in ipairs(uv_values) do
		uvs[#uvs + 1] = {
			value = value,
			text = mod:localize(value),
		}
	end

	return uvs
end

local function clip_dropdown_options()
	local clip_values = {
		"clip_none",
		"clip_left",
		"clip_right",
		"clip_top",
		"clip_bottom",
		"clip_top_left",
		"clip_top_right",
		"clip_bottom_left",
		"clip_bottom_right",
		"clip_center",
		"clip_inset",
	}

	local clips = {}

	for _, value in ipairs(clip_values) do
		clips[#clips + 1] = {
			value = value,
			text = mod:localize(value),
		}
	end

	return clips
end

---@param node table
---@return NodeType?
local function node_type_of(node)
	local registry = mod.hud_studio_node_registry
	return registry and node.type and registry.get(node.type) or nil
end

---@param node table
---@param field string
---@return any|nil
local function field_default(node, field)
	local node_type = node_type_of(node)
	local default_fn = node_type and node_type["default_" .. field]
	return default_fn and default_fn() or nil
end

local STRAIGHT_ORIENTATIONS = {
	"left_right",
	"right_left",
	"top_bottom",
	"bottom_top",
	"center",
	"center_vertical",
}

---@param node table?
---@return table[]
local function orientation_dropdown_options(node)
	local values = STRAIGHT_ORIENTATIONS
	if node and node.style and node.style.shape == "curved" then
		local node_type = node_type_of(node)
		values = (node_type and node_type.curved_orientations and node_type.curved_orientations()) or values
	end

	local orientations = {}

	for _, value in ipairs(values) do
		orientations[#orientations + 1] = {
			value = value,
			text = mod:localize(value),
		}
	end

	return orientations
end

---@param node table
---@param shape string
local function reset_orientation_for_shape(node, shape)
	local node_type = node_type_of(node)
	if not node_type or not node_type.default_orientation then
		return
	end
	local style = ensure_style(node)
	style.orientation = node_type.default_orientation(shape)
end

local function shape_dropdown_options()
	local shape_values = {
		"straight",
		"curved",
	}

	local shapes = {}

	for _, value in ipairs(shape_values) do
		shapes[#shapes + 1] = {
			value = value,

			text = mod:localize("shape_" .. value),
		}
	end

	return shapes
end

local function align_dropdown_options()
	return {
		{ value = "left", text = mod:localize("align_left") },
		{ value = "center", text = mod:localize("align_center") },
		{ value = "right", text = mod:localize("align_right") },
	}
end

local _font_options = nil
local function font_dropdown_options()
	if _font_options then
		return _font_options
	end
	local font_types = mod.dl.fonts.font_types()
	if not font_types or #font_types == 0 then
		return {}
	end
	local options = {}
	for i = 1, #font_types do
		local name = font_types[i].font_type
		options[i] = { value = name, text = name }
	end
	_font_options = options
	return options
end

local ENUM_FIELDS = {

	orientation = {
		options = orientation_dropdown_options,
		default = function(node)
			local node_type = node_type_of(node)
			if node_type and node_type.default_orientation then
				return node_type.default_orientation(node.style and node.style.shape)
			end
			return "left_right"
		end,
		store = "style",
	},

	shape = {
		options = shape_dropdown_options,
		default = "straight",
		store = "style",

		on_set = reset_orientation_for_shape,
	},
	align = { options = align_dropdown_options, default = "left", store = "style" },

	font_type = { options = font_dropdown_options, default = "proxima_nova_bold", store = "style" },
}

local function source_has_compatible(source, target_type)
	return FieldOptions.any(source, accept_for(target_type))
end

local function source_options(target_type)
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
			if source_has_compatible(list[i], target_type) then
				out[#out + 1] = { value = list[i].id, text = list[i].label or list[i].id }
			end
		end
	end
	return out
end

local function type_has_any_source(target_type)
	for _, source in pairs(Registry.all()) do
		if source_has_compatible(source, target_type) then
			return true
		end
	end
	return false
end

---@class BindingCursor
---@field get fun():table|nil       the record, or nil when none has been allocated yet
---@field ensure fun():table        the record, allocating it (and its parents) on demand

---@return BindingCursor
local function field_cursor(node, field)
	return {
		get = function()
			local value = node.callbacks and node.callbacks.value
			return value and value[field]
		end,
		ensure = function()
			node.callbacks = node.callbacks or {}
			node.callbacks.value = node.callbacks.value or {}
			local rec = node.callbacks.value[field]
			if not rec then
				rec = {}
				node.callbacks.value[field] = rec
			end
			return rec
		end,
	}
end

local function get_binding(node, field)
	local value = node.callbacks and node.callbacks.value
	return value and value[field]
end

---@param cursor BindingCursor
---@param default_mode string|nil
local function binding_mode(cursor, default_mode)
	local b = cursor.get()
	if not b or b.kind == "fixed" or b.kind == nil then
		return default_mode or "fixed"
	elseif b.kind == "code" then
		return "code"
	elseif b.kind == "thresholds" then
		return "thresholds"
	elseif b.kind == "conditions" then
		return "conditions"
	end
	return "source"
end

local THRESHOLD_INPUT_DEFAULTS = { current = 0, max = 100 }

---@return table spec
local function ensure_threshold_spec(node, node_type, field)
	local rec = field_cursor(node, field).ensure()
	local spec = rec.thresholds
	if not spec then
		spec = { list = { { pct = 0, color = table.clone(Thresholds.DEFAULT_COLOR) } } }
		rec.thresholds = spec
	end

	spec.list = spec.list or {}

	spec.scale = spec.scale or "percent"

	local mirror = node_type and node_type.threshold_values
	if mirror then
		spec.mirror = { current = mirror.current, max = mirror.max }
		spec.current, spec.max = nil, nil
	else
		spec.mirror = nil
		spec.current = spec.current or { kind = "fixed", value = THRESHOLD_INPUT_DEFAULTS.current }
		spec.max = spec.max or { kind = "fixed", value = THRESHOLD_INPUT_DEFAULTS.max }
	end
	return spec
end

---@return table|nil spec
function NodeForm.threshold_spec(node, field)
	local rec = node and field and get_binding(node, field)
	return rec and rec.kind == "thresholds" and rec.thresholds or nil
end

---@param slot "current"|"max"
---@return BindingCursor
local function threshold_input_cursor(spec, slot)
	return {
		get = function()
			return spec[slot]
		end,
		ensure = function()
			local rec = spec[slot]
			if not rec then
				rec = { kind = "fixed", value = THRESHOLD_INPUT_DEFAULTS[slot] }
				spec[slot] = rec
			end
			return rec
		end,
	}
end

---@param cursor BindingCursor
---@param seed_thresholds fun()|nil
---@param seed_conditions fun()|nil
local function set_mode(cursor, mode, target_type, seed_thresholds, seed_conditions)
	if mode == "source" then
		local rec = cursor.ensure()
		rec.kind = "source"
		if not rec.source then
			local srcs = source_options(target_type)
			rec.source = srcs[1] and srcs[1].value
			rec.field = first_field_value(source_field_options(rec.source, target_type))
		end
	elseif mode == "code" then
		local rec = cursor.ensure()
		rec.kind = "code"
		if rec.body == nil then
			rec.body = ""
		end
	elseif mode == "thresholds" and seed_thresholds then
		cursor.ensure().kind = "thresholds"
		seed_thresholds()
	elseif mode == "conditions" and seed_conditions then
		cursor.ensure().kind = "conditions"
		seed_conditions()
	else

		local rec = cursor.get()
		if rec then
			rec.kind = "fixed"
		end
	end
end

local function fixed_controls(node, prefix, field, is_knob)
	local ftype = FIELD_TYPES[field] or "text"
	local label = FIELD_LABELS[field] or cap_first(field)

	if ftype == "color" then
		if field == "color" then

			return {
				{
					kind = "rgba",
					label = label,
					get = function()
						return node_color(node)
					end,
					set = function(c)
						set_node_color(node, c)
					end,
				},
			}
		end

		return {
			{
				kind = "rgba",
				label = label,
				get = function()
					local tbl = is_knob and node.style or node.values
					local stored = tbl and tbl[field]
					if stored ~= nil then
						return stored
					end
					return field_default(node, field)
				end,
				set = function(c)
					local tbl = is_knob and ensure_style(node) or ensure_values(node)
					tbl[field] = c
				end,
			},
		}
	elseif field == "font_size" then
		return { style_number(node, prefix, "font_size", label, { min = 4, max = 240, default = 22, step = 1 }) }
	elseif ftype == "vector" then
		if field == "offset" then
			return {
				offset_number(node, prefix, 1, mod:localize("field_label_x")),
				offset_number(node, prefix, 2, mod:localize("field_label_y")),
			}
		end
		return {
			style_size_number(node, prefix, 1, mod:localize("field_label_width")),
			style_size_number(node, prefix, 2, mod:localize("field_label_height")),
		}
	elseif ftype == "number" then
		local opts = { min = 0, max = 100000, step = 1, default = (field == "max") and 100 or 0 }
		if field == "segments" then

			opts.min, opts.max, opts.default = 1, 64, 1
		elseif field == "segment_gap" then

			local node_type = node_type_of(node)
			opts.min, opts.max = 0, 64
			opts.default = (node_type and node_type.default_segment_gap and node_type.default_segment_gap()) or 3
		elseif field == "rotation" then

			opts.min, opts.max, opts.default = -360, 360, 0
		end
		if is_knob then
			return { style_number(node, prefix, field, label, opts) }
		end
		return { value_number(node, prefix, field, label, opts) }
	elseif ftype == "enum" then

		local enum = ENUM_FIELDS[field] or {
			options = function()
				return {}
			end,
		}
		local store_style = enum.store == "style" or (enum.store == nil and is_knob)
		return {
			{
				kind = "dropdown",
				label = label,

				options = function()
					return enum.options(node)
				end,
				get = function()
					local tbl = store_style and node.style or node.values
					local stored = tbl and tbl[field]
					if stored ~= nil then
						return stored
					end

					if type(enum.default) == "function" then
						return enum.default(node)
					end
					return enum.default
				end,
				set = function(v)
					local tbl = store_style and ensure_style(node) or ensure_values(node)
					tbl[field] = v

					if enum.on_set then
						enum.on_set(node, v)
					end
				end,
			},
		}
	elseif ftype == "bool" then

		return {
			{
				kind = "checkbox",
				label = label,
				get = function()
					local tbl = is_knob and node.style or node.values
					return (tbl and tbl[field]) or false
				end,
				set = function(v)
					local tbl = is_knob and ensure_style(node) or ensure_values(node)
					tbl[field] = v and true or nil
				end,
			},
		}
	elseif ftype == "material" then

		return {
			{
				kind = "text",
				label = label,
				token = prefix .. "/value." .. field,
				get = function()
					return (node.values and node.values[field]) or ""
				end,
				set = function(v)
					ensure_values(node)[field] = (v ~= "" and v) or nil
				end,
			},

			{
				kind = "button",
				text = mod:localize("browse_ellipsis"),
				tooltip = mod:localize("texture_browser_open_tooltip"),
				trailing = true,
				action = "open_texture_browser",
				field = field,
			},
		}
	elseif ftype == "dropdown" then
		return {
			{
				kind = "dropdown",
				label = label,
				rebinds = true,
				options = uv_dropdown_options,
				get = function()
					return (node.values and node.values.uv) or "flip_none"
				end,
				set = function(v)
					ensure_values(node).uv = v or nil
				end,
			},
		}
	elseif ftype == "clip" then

		return {
			{
				kind = "dropdown",

				label = mod:localize("field_label_preset"),
				rebinds = true,
				options = clip_dropdown_options,

				half = true,
				get = function()
					return (node.values and node.values.clip_mode) or "clip_none"
				end,
				set = function(v)
					ensure_values(node).clip_mode = (v ~= "clip_none" and v) or nil
				end,
			},
			{
				kind = "numeric",
				label = mod:localize("field_label_amount"),
				token = prefix .. "/value.clip_amount",
				half = true,
				step = 1,
				min = 0,
				max = 100,
				decimals = 0,

				hidden = function()
					return not (node.values and node.values.clip_mode)
				end,
				get = function()
					return (node.values and node.values.clip_amount) or 50
				end,
				set = function(v)
					ensure_values(node).clip_amount = v
				end,
			},
		}
	end
	return {}
end

local NO_FIXED = { [Visibility.FIELD] = true }

local DEFAULT_MODE = { [Visibility.FIELD] = "conditions" }

---@param cursor BindingCursor
local function source_controls(cursor, target_type, mode_get)
	return {
		{
			kind = "dropdown",
			label = mod:localize("field_label_source"),
			rebinds = true,
			options = function()
				return source_options(target_type)
			end,
			hidden = function()
				return mode_get() ~= "source"
			end,
			get = function()
				local b = cursor.get()
				return b and b.source
			end,
			set = function(v)
				local b = cursor.get()
				if not b or b.kind ~= "source" then
					return
				end
				local previous_field = b.field
				b.source = v

				b.field = kept_field_value(source_field_options(v, target_type), previous_field)
			end,
		},
		{
			kind = "dropdown",
			label = mod:localize("field_label_field"),
			rebinds = true,

			searchable = true,
			options = function()
				local b = cursor.get()
				return (b and source_field_options(b.source, target_type)) or {}
			end,
			hidden = function()
				return mode_get() ~= "source"
			end,
			get = function()
				local b = cursor.get()
				return b and b.field
			end,
			set = function(v)
				local b = cursor.get()
				if b and b.kind == "source" then
					b.field = v
				end
			end,
		},
	}
end

local _form_block = nil

---@param node Node|nil     nil = the block's own visibility binding
---@param field string|nil  the value field name, or "style"
---@return fun(): string
local function ide_button_text(node, field)
	return function()
		local block = _form_block
		local err = block and block.binding_error and block:binding_error(node, field)
		return err and mod:localize("ide_open_with_errors") or mod:localize("ide_open")
	end
end

local function code_control(node, field, slot, mode_get)
	return {
		kind = "button",
		text = ide_button_text(node, slot and (field .. "/" .. slot) or field),
		action = "open_ide",
		ide_field = field,
		ide_threshold_slot = slot,
		hidden = function()
			return mode_get() ~= "code"
		end,
	}
end

local function is_text_field(field)
	return field == "text" or field:match("^text%d+$") ~= nil
end

local function seg_mode_slot(field)
	return (field == "text") and "mode" or ("mode" .. field:match("%d+"))
end

local function seg_loc_slot(field)
	return (field == "text") and "loc_id" or ("loc_id" .. field:match("%d+"))
end

local function text_mode(node, field)
	local b = get_binding(node, field)
	if b and b.kind == "source" then
		return "source"
	elseif b and b.kind == "code" then
		return "code"
	end
	local m = node.values and node.values[seg_mode_slot(field)]
	return (m == "localized") and "localized" or "fixed"
end

local function set_text_mode(node, field, v, target_type)
	local mode_slot = seg_mode_slot(field)
	if v == "source" or v == "code" then
		set_mode(field_cursor(node, field), v, target_type)

		ensure_values(node)[mode_slot] = "fixed"
	else
		set_mode(field_cursor(node, field), "fixed", target_type)
		ensure_values(node)[mode_slot] = (v == "localized") and "localized" or "fixed"
	end
end

local function text_value_control(node, prefix, label, mode_name, store_field, mode_get)
	return {
		kind = "text",
		label = label,
		token = prefix .. "/value." .. store_field,
		hidden = function()
			return mode_get() ~= mode_name
		end,
		get = function()
			return (node.values and node.values[store_field]) or ""
		end,
		set = function(v)
			ensure_values(node)[store_field] = (v ~= "" and v) or nil
		end,
	}
end

---@param cursor BindingCursor
local function field_mode_spec(
	node,
	cursor,
	field,
	target_type,
	bindable,
	no_fixed,
	has_src,
	has_thr,
	seed_thresholds,
	seed_conditions,
	default_mode
)
	if is_text_field(field) then
		return {
			options = function()

				local o = { { value = "fixed", text = mod:localize("field_mode_fixed") } }

				if has_src then
					o[#o + 1] = { value = "source", text = mod:localize("field_mode_data_source") }
				end
				o[#o + 1] = { value = "code", text = mod:localize("field_mode_code") }
				return o
			end,
			get = function()
				return text_mode(node, field)
			end,
			set = function(v)
				set_text_mode(node, field, v, target_type)
			end,
		}
	end

	return {
		options = function()
			local o = {}
			if not no_fixed then
				o[#o + 1] = { value = "fixed", text = mod:localize("field_mode_fixed") }
			end
			if seed_conditions and default_mode == "conditions" then

				o[#o + 1] = { value = "conditions", text = mod:localize("field_mode_conditions") }
			end
			if has_src then
				o[#o + 1] = { value = "source", text = mod:localize("field_mode_data_source") }
			end
			if has_thr then
				o[#o + 1] = { value = "thresholds", text = mod:localize("field_mode_thresholds") }
			end
			if seed_conditions and default_mode ~= "conditions" then
				o[#o + 1] = { value = "conditions", text = mod:localize("field_mode_conditions") }
			end
			if bindable then
				o[#o + 1] = { value = "code", text = mod:localize("field_mode_code") }
			end
			return o
		end,
		get = function()
			local m = binding_mode(cursor, default_mode)
			if m == "fixed" and no_fixed then

				return has_src and "source" or "code"
			end
			return m
		end,
		set = function(v)
			set_mode(cursor, v, target_type, seed_thresholds, seed_conditions)
		end,
	}
end

local function field_group(node, node_type, prefix, field, bindable, is_knob)
	local target_type = FIELD_TYPES[field] or "text"
	local label = FIELD_LABELS[field] or cap_first(field)
	local no_fixed = NO_FIXED[field] == true
	local default_mode = DEFAULT_MODE[field]
	local has_src = bindable and type_has_any_source(target_type)
	local has_thr = bindable and THRESHOLD_TYPES[target_type] == true
	local cursor = field_cursor(node, field)
	local seed_thresholds = has_thr and function()
		ensure_threshold_spec(node, node_type, field)
	end or nil

	local seed_conditions = (bindable and field == Visibility.FIELD)
			and function()
				Visibility.ensure_conditions(cursor.ensure())
			end
		or nil

	if no_fixed and not default_mode and binding_mode(cursor) == "fixed" then
		set_mode(cursor, has_src and "source" or "code", target_type)
	end

	local spec = field_mode_spec(
		node,
		cursor,
		field,
		target_type,
		bindable,
		no_fixed,
		has_src,
		has_thr,
		seed_thresholds,
		seed_conditions,
		default_mode
	)
	local mode_get = spec.get
	local controls = {}

	local visible_when = FIELD_VISIBLE_WHEN[field]
	local group_hidden = visible_when and function()
		return not visible_when(node)
	end or nil

	if is_text_field(field) then

		controls[#controls + 1] = text_value_control(node, prefix, mod:localize("field_label_value"), "fixed", field, mode_get)
		controls[#controls + 1] =
			text_value_control(node, prefix, mod:localize("field_label_loc_id"), "localized", seg_loc_slot(field), mode_get)
	elseif not no_fixed then
		local fixed = fixed_controls(node, prefix, field, is_knob)
		for i = 1, #fixed do
			local c = fixed[i]

			if c.label == label then
				c.label = nil
			end
			c.hidden = function()
				return mode_get() ~= "fixed"
			end
			controls[#controls + 1] = c
		end
	end

	if has_src then
		local sc = source_controls(cursor, target_type, mode_get)
		for i = 1, #sc do
			controls[#controls + 1] = sc[i]
		end
	end
	if has_thr then

		controls[#controls + 1] = {
			kind = "thresholds",
			field = field,
			hidden = function()
				return mode_get() ~= "thresholds"
			end,
			get = function()
				local rec = cursor.get()
				return rec and rec.thresholds and rec.thresholds.list
			end,

			band_scale = function()
				local rec = cursor.get()
				return NodeForm.threshold_scale(rec and rec.thresholds)
			end,
		}
	end
	if seed_conditions then

		controls[#controls + 1] = {
			kind = "conditions",
			field = field,
			cb_node = node,
			hidden = function()
				return mode_get() ~= "conditions"
			end,
			get = function()
				local rec = cursor.get()
				return rec and rec.conditions or nil
			end,
		}
	end
	if bindable then
		controls[#controls + 1] = code_control(node, field, nil, mode_get)
	end

	return {
		group = true,
		field = field,
		label = label,
		mode = {
			kind = "dropdown",
			rebinds = true,
			options = spec.options,
			get = spec.get,
			set = spec.set,
		},
		controls = controls,
		hidden = group_hidden,
	}
end

---@param slot "current"|"max"
---@return table|nil group
function NodeForm.threshold_input_group(node, prefix, field, slot, label)
	local spec = NodeForm.threshold_spec(node, field)
	if not spec or NodeForm.threshold_uses_mirror(spec) then
		return nil
	end
	local boolean_scale = NodeForm.threshold_scale(spec) == "boolean"
	if boolean_scale and slot == "max" then
		return nil
	end

	local cursor = threshold_input_cursor(spec, slot)
	local label = label or cap_first(slot)

	local target_type = boolean_scale and "bool" or "number"
	local has_src = type_has_any_source(target_type)
	local mode_spec = field_mode_spec(node, cursor, field, target_type, true, false, has_src, false, nil)
	local mode_get = mode_spec.get

	local fixed_ctrl
	if boolean_scale then

		fixed_ctrl = {
			kind = "checkbox",
			label = mod:localize("field_label_value"),
			get = function()
				local rec = cursor.get()
				return rec ~= nil and rec.value == true
			end,
			set = function(v)
				cursor.ensure().value = v and true or false
			end,
		}
	else
		fixed_ctrl = {
			kind = "numeric",
			label = mod:localize("field_label_value"),
			token = prefix .. "/thresholds." .. field .. "." .. slot,
			step = 1,
			min = 0,
			max = 100000,
			decimals = 0,
			get = function()
				local rec = cursor.get()
				return (rec and rec.value) or THRESHOLD_INPUT_DEFAULTS[slot]
			end,
			set = function(v)
				cursor.ensure().value = v
			end,
		}
	end
	fixed_ctrl.hidden = function()
		return mode_get() ~= "fixed"
	end
	local controls = { fixed_ctrl }
	if has_src then
		local sc = source_controls(cursor, target_type, mode_get)
		for i = 1, #sc do
			controls[#controls + 1] = sc[i]
		end
	end
	controls[#controls + 1] = code_control(node, field, slot, mode_get)

	return {
		group = true,
		field = field,
		slot = slot,
		label = label,
		mode = {
			kind = "dropdown",
			rebinds = true,
			options = mode_spec.options,
			get = mode_spec.get,
			set = mode_spec.set,
		},
		controls = controls,
	}
end

local SCALE_OPTIONS = {
	{ value = "number", text = mod:localize("scale_number") },
	{ value = "percent", text = mod:localize("scale_percent") },
	{ value = "boolean", text = mod:localize("scale_boolean") },
}

---@return table|nil ctrl
function NodeForm.threshold_scale_control(node, field)
	local spec = NodeForm.threshold_spec(node, field)
	if not spec then
		return nil
	end
	return {
		kind = "checklist",
		label = mod:localize("field_label_threshold_mode"),
		left_label = "",
		items = SCALE_OPTIONS,
		is_on = function(value)
			return (spec.scale or "percent") == value
		end,
		toggle = function(value)
			spec.scale = value
			if value == "boolean" then

				spec.current = spec.current or { kind = "fixed", value = false }
				if type(spec.current.value) ~= "boolean" then
					spec.current.value = false
				end
			end
		end,
	}
end

---@return "percent"|"number"|"boolean"
function NodeForm.threshold_scale(spec)
	local scale = spec ~= nil and spec.scale or nil
	if scale == "number" or scale == "boolean" then
		return scale
	end
	return "percent"
end

---@return boolean
function NodeForm.threshold_uses_mirror(spec)
	return spec ~= nil and spec.mirror ~= nil and NodeForm.threshold_scale(spec) ~= "boolean"
end

---@return { current: string, max: string }|nil
function NodeForm.threshold_mirror(node_type)
	return node_type and node_type.threshold_values or nil
end

---@return table|nil spec
function NodeForm.condition_spec(node, field)
	if not (node and field) then
		return nil
	end

	if field == Visibility.FIELD then
		return Visibility.node_conditions(node)
	end
	local rec = get_binding(node, field)
	return rec and rec.kind == "conditions" and rec.conditions or nil
end

---@param slot "lhs"|"rhs"|"rhs2"
---@return BindingCursor
local function condition_operand_cursor(spec, row_index, slot)
	return {
		get = function()
			local row = spec.rows[row_index]
			return row and row[slot]
		end,
		ensure = function()
			local row = spec.rows[row_index]
			local rec = row[slot]
			if not rec then
				rec = { kind = "fixed" }
				row[slot] = rec
			end
			return rec
		end,
	}
end

---@param binding Binding|nil
---@return string|nil
function NodeForm.condition_operand_type(binding)
	if not binding or binding.kind ~= "source" then
		return nil
	end
	return shape_prim(source_field_hint(Registry.get(binding.source), binding.field))
end

---@param slot "lhs"|"rhs"|"rhs2"
---@return table|nil group
function NodeForm.condition_operand_group(node, prefix, field, spec, row_index, slot)
	if not spec or not spec.rows[row_index] then
		return nil
	end
	local cursor = condition_operand_cursor(spec, row_index, slot)
	local slot_key = row_index .. "." .. slot
	local target_type = "operand"
	local has_src = type_has_any_source(target_type)
	local mode_spec = field_mode_spec(node, cursor, field, target_type, true, false, has_src, false, nil, nil)
	local mode_get = mode_spec.get

	local controls = {
		{
			kind = "text",
			label = mod:localize("field_label_value"),
			token = prefix .. "/conditions." .. field .. "." .. slot_key,
			hidden = function()
				return mode_get() ~= "fixed"
			end,
			get = function()
				local rec = cursor.get()
				return rec and rec.value ~= nil and tostring(rec.value) or ""
			end,
			set = function(v)

				cursor.ensure().value = tonumber(v) or v
			end,
		},
	}
	if has_src then
		local sc = source_controls(cursor, target_type, mode_get)
		for i = 1, #sc do
			controls[#controls + 1] = sc[i]
		end
	end

	controls[#controls + 1] = {
		kind = "button",
		text = ide_button_text(node, node and (field .. "/" .. slot_key) or slot_key),
		action = "open_ide",
		ide_field = field,
		ide_condition_slot = slot_key,
		ide_block_conditions = node == nil,
		hidden = function()
			return mode_get() ~= "code"
		end,
	}

	return {
		group = true,
		field = field,
		slot = slot_key,
		label = cap_first(slot),
		mode = {
			kind = "dropdown",
			rebinds = true,
			options = mode_spec.options,
			get = mode_spec.get,
			set = mode_spec.set,
		},
		controls = controls,
	}
end

---@param binding Binding|nil
---@return string
function NodeForm.condition_operand_summary(binding)
	local kind = binding and binding.kind
	if kind == "source" then
		return tostring(binding.source or "?") .. "." .. tostring(binding.field or "?")
	elseif kind == "code" then
		return mod:localize("field_mode_code")
	end
	local v = binding and binding.value
	return (v ~= nil and tostring(v) ~= "") and tostring(v) or mod:localize("value_summary_empty")
end

---@return string
function NodeForm.value_summary(node, field)
	local b = get_binding(node, field)
	local kind = b and b.kind
	if kind == "source" then
		return tostring(b.source or "?") .. "." .. tostring(b.field or "?")
	elseif kind == "code" then
		return mod:localize("field_mode_code")
	elseif kind == "thresholds" then
		return mod:localize("field_mode_thresholds")
	end
	local v = node.values and node.values[field]
	return (v ~= nil) and tostring(v) or mod:localize("value_summary_empty")
end

local STYLE_MODE_OPTIONS = {
	{ value = "fields", text = mod:localize("style_mode_fields") },
	{ value = "patch", text = mod:localize("style_mode_patch") },
}

local function style_mode(node)
	local s = node.callbacks and node.callbacks.style
	if s and (s.kind == "patch" or s.kind == "code") then
		return "patch"
	end
	return "fields"
end

local function set_style_mode(node, v)
	node.callbacks = node.callbacks or {}
	if v == "patch" then
		local s = node.callbacks.style or {}
		if s.kind ~= "code" then
			s.kind = "patch" 
		end
		s.body = s.body or ""
		node.callbacks.style = s
	elseif node.callbacks.style then
		node.callbacks.style.kind = "off"
	end
end

local function style_mode_toggle(node)
	return {
		kind = "dropdown",
		label = mod:localize("field_label_style_mode"),
		rebinds = true,
		options = STYLE_MODE_OPTIONS,
		get = function()
			return style_mode(node)
		end,
		set = function(v)
			set_style_mode(node, v)
		end,
	}
end

local function patch_button(node)
	return {
		kind = "button",
		label = mod:localize("field_label_style_patch"),
		text = ide_button_text(node, "style"),
		action = "open_ide",
		ide_style = true,
		hidden = function()
			return style_mode(node) ~= "patch"
		end,
	}
end

local MAX_TEXT_SEGMENTS = 10

local function seg_field(i)
	return (i == 1) and "text" or ("text" .. i)
end

local function value_mode(node)
	return (node.values and node.values.value_mode == "chain") and "chain" or "single"
end

local function set_value_mode(node, v)
	ensure_values(node).value_mode = (v == "chain") and "chain" or nil
end

local VALUE_MODE_OPTIONS = {
	{ value = "single", text = mod:localize("value_mode_single") },
	{ value = "chain", text = mod:localize("value_mode_chain") },
}

local function value_mode_toggle(node)
	return {
		kind = "dropdown",
		label = mod:localize("field_label_value_mode"),
		options = VALUE_MODE_OPTIONS,
		get = function()
			return value_mode(node)
		end,
		set = function(v)
			set_value_mode(node, v)
		end,
	}
end

local function segment_has_value(node, field)
	local values = node.values
	if values then
		local literal = values[field]
		if literal ~= nil and literal ~= "" then
			return true
		end
		local loc = values[seg_loc_slot(field)]
		if loc ~= nil and loc ~= "" then
			return true
		end
	end
	local b = get_binding(node, field)
	return b ~= nil and (b.kind == "source" or b.kind == "code")
end

local function segment_is_numeric(node, field)
	local b = get_binding(node, field)
	if not (b and b.kind == "source") then
		return false
	end
	local source = b.source and Registry.get(b.source)
	local prim = shape_prim(source_field_hint(source, b.field))
	return prim == "number" or prim == "integer"
end

local function decimals_control(node, prefix, i, segment_hidden)
	local field = (i == 1) and "decimals" or ("decimals" .. i)
	local ctrl = style_number(node, prefix, field, mod:localize("field_label_decimals"), { min = 0, max = 5, step = 1, default = 0 })

	ctrl.right_column = true
	ctrl.hidden = function()

		if segment_hidden and segment_hidden() then
			return true
		end
		return not segment_is_numeric(node, seg_field(i))
	end
	return ctrl
end

local function text_value_rows(node, node_type, prefix)
	local rows = {}
	rows[#rows + 1] = value_mode_toggle(node)

	for i = 1, MAX_TEXT_SEGMENTS do
		local field = seg_field(i)

		local group = field_group(node, node_type, prefix, field, true, false)
		if i > 1 then
			group.label = mod:localize("n_form_segment", i)
			local previous = seg_field(i - 1)
			group.hidden = function()
				if value_mode(node) ~= "chain" then
					return true
				end
				return not (segment_has_value(node, previous) or segment_has_value(node, field))
			end
		end
		rows[#rows + 1] = group
		rows[#rows + 1] = decimals_control(node, prefix, i, group.hidden)
	end

	return rows
end

local function bindable_set(node_type)
	local set = {}
	local cb = node_type and node_type.callbacks and node_type.callbacks.value
	if cb and cb.fields then
		for i = 1, #cb.fields do
			set[cb.fields[i]] = true
		end
	end
	return set
end

---@param node Node
---@param node_type NodeType|nil
---@param prefix string
---@param block Block|nil
---@return FormSection[]

local function NOOP_SET() end
local function TRUE_FN()
	return true
end

---@param value any
---@param seen table
local function mark_document(value, seen)
	if type(value) ~= "table" or seen[value] then
		return seen
	end
	seen[value] = true
	for _, v in pairs(value) do
		mark_document(v, seen)
	end
	return seen
end

local function freeze(value, seen)
	if type(value) ~= "table" or seen[value] then
		return
	end
	seen[value] = true
	if value.set ~= nil then
		value.set = NOOP_SET
	end

	if type(value.kind) == "string" then
		value.disabled = TRUE_FN
	end
	for _, v in pairs(value) do
		freeze(v, seen)
	end
end

function NodeForm.build(node, node_type, prefix, block)

	_form_block = block

	local frozen = Session.is_mod_block(block)
	local sections = {}

	if node.type == "progress_bar" then
		local v = ensure_values(node)
		if v.current == nil and v.max == nil and v.progress == nil then
			v.current, v.max = 60, 100
		end
	end

	local bindable = bindable_set(node_type)
	local is_style_knob = {}

	is_style_knob["visible"] = true
	local visibility_rows = {
		field_group(node, node_type, prefix, "visible", bindable["visible"] == true, true),
	}

	local player_rows = Visibility.player_checklists(node)
	for i = 1, #player_rows do
		visibility_rows[#visibility_rows + 1] = player_rows[i]
	end
	sections[#sections + 1] = {
		key = "visibility",
		title = mod:localize("section_visibility"),
		rows = visibility_rows,
	}

	local transition_rows = {
		{
			kind = "checkbox",
			label = mod:localize("field_label_fade_in"),
			side_label = true,
			token = prefix .. "/transition.fade_in.enabled",
			half = true,
			get = function()
				local tr = node.style and node.style.transition
				return tr and tr.fade_in and true or false
			end,
			set = function(enabled)
				local style = ensure_style(node)
				style.transition = style.transition or {}
				if enabled then
					style.transition.fade_in = style.transition.fade_in or 0.2
				else
					style.transition.fade_in = nil
				end
			end,
		},
		{
			kind = "numeric",
			label = " ",
			token = prefix .. "/transition.fade_in.duration",
			half = true,
			step = 0.05,
			min = 0.05,
			max = 2,
			decimals = 2,
			get = function()
				local tr = node.style and node.style.transition
				return (tr and tr.fade_in) or 0.2
			end,
			set = function(v)
				local style = ensure_style(node)
				style.transition = style.transition or {}
				style.transition.fade_in = v > 0 and v or nil
			end,
			hidden = function()
				local tr = node.style and node.style.transition
				return not (tr and tr.fade_in)
			end,
		},
		{
			kind = "checkbox",
			label = mod:localize("field_label_fade_out"),
			side_label = true,
			token = prefix .. "/transition.fade_out.enabled",
			half = true,
			get = function()
				local tr = node.style and node.style.transition
				return tr and tr.fade_out and true or false
			end,
			set = function(enabled)
				local style = ensure_style(node)
				style.transition = style.transition or {}
				if enabled then
					style.transition.fade_out = style.transition.fade_out or 0.2
				else
					style.transition.fade_out = nil
				end
			end,
		},
		{
			kind = "numeric",
			label = " ",
			token = prefix .. "/transition.fade_out.duration",
			half = true,
			step = 0.05,
			min = 0.05,
			max = 2,
			decimals = 2,
			get = function()
				local tr = node.style and node.style.transition
				return (tr and tr.fade_out) or 0.2
			end,
			set = function(v)
				local style = ensure_style(node)
				style.transition = style.transition or {}
				style.transition.fade_out = v > 0 and v or nil
			end,
			hidden = function()
				local tr = node.style and node.style.transition
				return not (tr and tr.fade_out)
			end,
		},
		{
			kind = "dropdown",
			label = mod:localize("field_label_easing"),
			side_label = true,
			token = prefix .. "/transition.ease",
			get = function()
				local tr = node.style and node.style.transition
				return (tr and tr.ease) or "linear"
			end,
			set = function(v)
				local style = ensure_style(node)
				style.transition = style.transition or {}
				style.transition.ease = v ~= "linear" and v or nil
			end,
			options = {
				{ text = mod:localize("easing_linear"), value = "linear" },
				{ text = mod:localize("easing_in_out"), value = "in_out" },
			},
			hidden = function()
				local tr = node.style and node.style.transition
				return not (tr and (tr.fade_in or tr.fade_out))
			end,
		},
	}
	sections[#sections + 1] = {
		key = "transitions",
		title = mod:localize("section_transitions"),
		rows = transition_rows,
	}

	if node_type and node_type.style_knobs and #node_type.style_knobs > 0 then
		local has_patch = node_type.callbacks and node_type.callbacks.style ~= nil
		local rows = {}

		if has_patch then
			rows[#rows + 1] = style_mode_toggle(node)
		end

		is_style_knob["offset"] = true
		local position = field_group(node, node_type, prefix, "offset", bindable["offset"] == true, true)
		if has_patch then
			position.hidden = function()
				return style_mode(node) == "patch"
			end
		end
		rows[#rows + 1] = position
		for i = 1, #node_type.style_knobs do
			local knob = node_type.style_knobs[i]

			if knob ~= "visible" and knob ~= "offset" then
				is_style_knob[knob] = true
				local group = field_group(node, node_type, prefix, knob, bindable[knob] == true, true)
				if has_patch then

					local field_hidden = group.hidden
					group.hidden = function()
						return style_mode(node) == "patch" or (field_hidden ~= nil and field_hidden())
					end
				end
				rows[#rows + 1] = group
			end
		end
		if has_patch then
			rows[#rows + 1] = patch_button(node)
		end
		sections[#sections + 1] = { key = "style", title = mod:localize("section_style"), rows = rows }
	end

	local value_cb = node_type and node_type.callbacks and node_type.callbacks.value
	if value_cb and value_cb.fields then
		local rows
		if node.type == "text" then

			rows = text_value_rows(node, node_type, prefix)
		else
			rows = {}
			for i = 1, #value_cb.fields do
				local field = value_cb.fields[i]
				if not is_style_knob[field] then
					rows[#rows + 1] = field_group(node, node_type, prefix, field, true, false)
				end
			end
		end
		if #rows > 0 then
			sections[#sections + 1] = { key = "value", title = mod:localize("section_value"), rows = rows }
		end
	end

	if frozen then
		freeze(sections, mark_document(node, {}))
	end

	return sections
end

local function control_parts(kind, x, y, w, h)
	if kind == "numeric" then
		return Numeric.parts(x, y, w, h)
	elseif kind == "dropdown" then
		return Dropdown.parts(x, y, w, h)
	elseif kind == "text" then
		return TextInput.parts(x, y, w, h)
	elseif kind == "checkbox" then
		return Checkbox.parts(x, y, w, h)
	elseif kind == "rgba" then
		return Rgba.parts(x, y, w, h)
	elseif kind == "button" then
		return { box = { x = x, y = y, w = w, h = h } }
	elseif kind == "thresholds" then
		return ThresholdBar.parts(x, y, w, h)
	elseif kind == "conditions" then

		return { box = { x = x, y = y, w = w, h = h } }
	end
	return nil
end

local _layout_opts = nil

local function layout_ctrl(ctrl, cx, cy, cw, label_mode)

	if ctrl.kind == "checklist" then
		local reserved_h = (label_mode ~= nil) and PANEL.FIELD_LABEL_H or 0

		local list_gap = (_layout_opts ~= nil and _layout_opts.label_column) and PANEL.COL_GAP or 0
		local parts = Checklist.parts(cx, cy + reserved_h, cw, ctrl.items, list_gap)
		return {
			t = "field",
			ctrl = ctrl,
			x = cx,
			y = cy,
			w = cw,
			h = reserved_h + parts.height + PANEL.FIELD_GAP,
			label_rect = { x = cx, y = cy, w = cw, h = 0 },
			ctrl_rect = { x = cx, y = cy + reserved_h, w = cw, h = parts.height },
			parts = parts,
		}
	end

	local has_label = ctrl.label ~= nil and ctrl.label ~= "" and label_mode ~= "side"
	local label_h = (has_label or label_mode ~= nil) and PANEL.FIELD_LABEL_H or 0

	local ctrl_h
	local note_lines
	if ctrl.multiline then
		local rows = 1
		if _layout_opts and _layout_opts.text_rows then
			rows = _layout_opts.text_rows(ctrl, cw - 8) or 1
		end
		if rows < 1 then
			rows = 1
		end
		ctrl_h = rows * PANEL.MULTILINE_LINE_H + PANEL.MULTILINE_PAD * 2
	elseif ctrl.kind == "note" then

		if ctrl.wrap and _layout_opts and _layout_opts.note_lines then
			note_lines = _layout_opts.note_lines(ctrl, cw)
		end
		ctrl_h = note_lines and #note_lines * PANEL.NOTE_LINE_H or PANEL.FIELD_LABEL_H
	else
		ctrl_h = PANEL.FIELD_H
	end
	local cry = cy + label_h

	return {
		t = "field",
		ctrl = ctrl,
		x = cx,
		y = cy,
		w = cw,
		h = label_h + ctrl_h + PANEL.FIELD_GAP,
		label_rect = { x = cx, y = cy, w = cw, h = label_h },
		ctrl_rect = { x = cx, y = cry, w = cw, h = ctrl_h },
		parts = control_parts(ctrl.kind, cx, cry, cw, ctrl_h),
		note_lines = note_lines,
	}
end

---@return number x, number w
local function side_label_column(items, label, inner_x, inner_w, cy)
	items[#items + 1] = {
		t = "grouplabel",
		text = label,
		x = inner_x,
		y = cy + PANEL.FIELD_LABEL_H,
		w = PANEL.LABEL_COL_W,
		h = PANEL.FIELD_H,
		center_h = PANEL.FIELD_H,
	}
	local offset = PANEL.LABEL_COL_W + PANEL.COL_GAP
	return inner_x + offset, inner_w - offset
end

local function layout_field(ctrl, x, cy, w)
	return layout_ctrl(ctrl, x + PANEL.PAD, cy, w - PANEL.PAD * 2)
end

---@return table[] items, number height
local function layout_group(group, x, cy, w)
	local items = {}
	local inner_x = x + PANEL.PAD
	local inner_w = w - PANEL.PAD * 2
	local start = cy

	local labelled = (_layout_opts ~= nil and _layout_opts.label_column) or false

	local label_col_w = labelled and (PANEL.LABEL_COL_W + PANEL.COL_GAP) or 0

	local mode_x = inner_x + label_col_w
	local mode_y = cy + PANEL.FIELD_LABEL_H

	if labelled then

		items[#items + 1] = {
			t = "grouplabel",
			text = group.label,
			x = inner_x,
			y = mode_y,
			w = PANEL.LABEL_COL_W,
			h = PANEL.FIELD_H,
			center_h = PANEL.FIELD_H,
		}
	else
		items[#items + 1] = {
			t = "grouplabel",
			text = group.label,
			x = inner_x,
			y = cy,
			w = inner_w,
			h = PANEL.FIELD_LABEL_H,
		}
	end

	local right_x = mode_x + PANEL.MODE_COL_W + PANEL.COL_GAP
	local right_w = inner_w - label_col_w - PANEL.MODE_COL_W - PANEL.COL_GAP

	local nudge = 0
	if not labelled then
		for i = 1, #group.controls do
			local c = group.controls[i]
			if not (c.hidden and c.hidden()) then
				if c.label ~= nil and c.label ~= "" then
					nudge = PANEL.FIELD_LABEL_H
				end
				break
			end
		end
	end

	local right_label_mode = labelled and "reserve" or nil

	local right_items = {}

	local ry = mode_y - nudge - (labelled and PANEL.FIELD_LABEL_H or 0)
	local half_w = math.floor((right_w - PANEL.COL_GAP) * 0.5)
	local i = 1
	while i <= #group.controls do
		local c = group.controls[i]
		if not (c.hidden and c.hidden()) then

			local trail = group.controls[i + 1]
			if trail and trail.trailing and not (trail.hidden and trail.hidden()) then
				local trail_w = PANEL.FIELD_H * 2
				local main_w = right_w - trail_w - PANEL.COL_GAP
				local main = layout_ctrl(c, right_x, ry, main_w, right_label_mode)

				local main_label_h = ((c.label ~= nil and c.label ~= "") or labelled) and PANEL.FIELD_LABEL_H
					or 0
				local trail_item = layout_ctrl(trail, right_x + main_w + PANEL.COL_GAP, ry + main_label_h, trail_w)
				right_items[#right_items + 1] = main
				right_items[#right_items + 1] = trail_item
				ry = ry + math.max(main.h, main_label_h + trail_item.h)
				i = i + 2
			elseif c.half and trail and trail.half and not (trail.hidden and trail.hidden()) then
				local pair = trail
				local left = layout_ctrl(c, right_x, ry, half_w, right_label_mode)

				local right = layout_ctrl(pair, right_x + half_w + PANEL.COL_GAP, ry, right_w - half_w - PANEL.COL_GAP, right_label_mode)
				right_items[#right_items + 1] = left
				right_items[#right_items + 1] = right
				ry = ry + math.max(left.h, right.h)
				i = i + 2
			else
				local it = layout_ctrl(c, right_x, ry, right_w, right_label_mode)
				right_items[#right_items + 1] = it
				ry = ry + it.h
				i = i + 1
			end
		else
			i = i + 1
		end
	end

	items[#items + 1] = layout_ctrl(group.mode, mode_x, mode_y, PANEL.MODE_COL_W)
	for i = 1, #right_items do
		items[#items + 1] = right_items[i]
	end

	local bottom = math.max(ry, mode_y + PANEL.FIELD_H + PANEL.FIELD_GAP)
	return items, bottom - start
end

---@param sections FormSection[]
---@param open table<string, boolean>
---@param x number
---@param y number
---@param w number
---@param opts { text_rows: (fun(ctrl: table, content_w: number): integer)?, note_lines: (fun(ctrl: table, content_w: number): string[]?)?, label_column: boolean? }|nil

---@return { items: table[], height: number }
function NodeForm.layout(sections, open, x, y, w, opts)
	_layout_opts = opts
	local items = {}
	local cy = y

	for s = 1, #sections do
		local sec = sections[s]

		local is_open = sec.flat or open[sec.key]
		if is_open == nil then
			is_open = true
		end

		if not sec.flat then
			items[#items + 1] = {
				t = "header",
				key = sec.key,
				title = sec.title,
				x = x,
				y = cy,
				w = w,
				h = PANEL.SECTION_H,
				open = is_open,
			}
			cy = cy + PANEL.SECTION_H

			if is_open then
				cy = cy + PANEL.SECTION_HEAD_PAD
			end
		end

		if is_open then
			local inner_x = x + PANEL.PAD
			local inner_w = w - PANEL.PAD * 2
			local labelled = (_layout_opts ~= nil and _layout_opts.label_column) or false
			local r = 1
			while r <= #sec.rows do
				local row = sec.rows[r]

				if not (row.hidden and row.hidden()) then
					local pair = sec.rows[r + 1]
					if row.group then
						local gitems, gh = layout_group(row, x, cy, w)
						for i = 1, #gitems do
							items[#items + 1] = gitems[i]
						end
						cy = cy + gh
						r = r + 1
					elseif row.half and pair and pair.half and not (pair.hidden and pair.hidden()) then

						local pair_x, pair_w = inner_x, inner_w
						local pair_label_mode = nil
						if labelled then
							pair_x, pair_w = side_label_column(items, row.label, inner_x, inner_w, cy)
							pair_label_mode = "side"
						end
						local pair_half_w = math.floor((pair_w - PANEL.COL_GAP) * 0.5)
						local left = layout_ctrl(row, pair_x, cy, pair_half_w, pair_label_mode)
						local right = layout_ctrl(
							pair,
							pair_x + pair_half_w + PANEL.COL_GAP,
							cy,
							pair_w - pair_half_w - PANEL.COL_GAP,
							pair_label_mode
						)
						items[#items + 1] = left
						items[#items + 1] = right
						cy = cy + math.max(left.h, right.h)
						r = r + 2
					elseif labelled and row.side_label and row.label and row.label ~= "" then

						local row_x, row_w = side_label_column(items, row.label, inner_x, inner_w, cy)

						if row.half then
							row_w = math.floor((row_w - PANEL.COL_GAP) * 0.5)
						end
						local item = layout_ctrl(row, row_x, cy, row_w, "side")
						items[#items + 1] = item
						cy = cy + item.h
						r = r + 1
					else

						local item
						if row.right_column then
							local skip = PANEL.MODE_COL_W + PANEL.COL_GAP
							if _layout_opts ~= nil and _layout_opts.label_column then
								skip = skip + PANEL.LABEL_COL_W + PANEL.COL_GAP
							end
							item = layout_ctrl(row, inner_x + skip, cy, inner_w - skip)
						else
							item = layout_field(row, x, cy, w)
						end
						items[#items + 1] = item
						cy = cy + item.h
						r = r + 1
					end
				else
					r = r + 1
				end
			end
		end

		cy = cy + PANEL.SECTION_GAP
	end

	return { items = items, height = cy - y }
end

mod.hud_studio_node_form = NodeForm

return NodeForm
