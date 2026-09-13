
local mod = get_mod("hud_studio")

if mod.ide_docs_tree_component then
	return mod.ide_docs_tree_component
end

local C = mod:core(mod.editor_constants, "hud/editor/constants")

local DocsData = mod:core(mod.ide_docs_data, "hud/editor/ide_docs_data")
mod.ide_docs_data = DocsData
local DataTypes = mod:core(mod.hud_studio_data_types, "sources/data_types")
local TextMetrics = mod:core(mod.hud_studio_text_metrics, "hud/editor/text_metrics")
local Registry = mod:core(mod.hud_studio_source_registry, "engine/registry")

local DocsTree = {}

local ROW_H = 24 
local FONT_SIZE = 12
local CRUMB_H = 16 
local CRUMB_PAD = 4 
local ROOT_TITLE = "Bindings" 
local COL_GAP = 10 
local COL1_MIN = 40 
local COL1_MAX_FRAC = 0.5 
local NAME_PAD = 2 
local WALK_CAP = 8 
local BACK_LABEL = "< back"
local LINK_SUFFIX = " >"

local COLOR = {
	CRUMB = { 255, 230, 230, 242 }, 
	BACK = { 255, 170, 200, 240 },
	LINK = { 255, 170, 200, 240 }, 
	LEAF = C.COLOR.ROW_TEXT, 
	NOTE = C.COLOR.NOTE_TEXT,
	HOVER_BG = { 255, 56, 56, 56 },
	RULE = C.COLOR.PANEL_RULE,
}

local function leaf_note(type_text, note)
	if note and note ~= "" then
		return (type_text or "?") .. "  --  " .. note
	end
	return type_text or ""
end

local function class_is_open(name)
	return name ~= nil and DocsData.classes[name] ~= nil
end

local function class_field(class_name, field_name)
	local fields = DocsData.classes[class_name]
	if not fields then
		return nil
	end
	for i = 1, #fields do
		if fields[i].name == field_name then
			return fields[i]
		end
	end
	return nil
end

local function class_entries(class_name)
	local out = {}
	local fields = DocsData.classes[class_name] or {}
	for i = 1, #fields do
		local f = fields[i]
		out[#out + 1] = {
			name = f.name,
			note = leaf_note(f.type, f.note),
			link = class_is_open(f.ref),
			ref = f.ref,
		}
	end
	return out
end

local function source_field_entries(fields)
	local names = {}
	for name in pairs(fields or {}) do
		names[#names + 1] = name
	end
	table.sort(names)
	local out = {}
	for i = 1, #names do
		local name = names[i]
		local shape = fields[name]
		if DataTypes.is_leaf(shape) then
			out[#out + 1] = { name = name, note = leaf_note(shape.type, shape.note), link = false }
		else
			out[#out + 1] = { name = name, note = "(group)", link = true, group = name }
		end
	end
	return out
end

local function node_type_names(node_type, which)
	if not node_type then
		return nil
	end
	if which == "value" then
		return node_type.callbacks and node_type.callbacks.value and node_type.callbacks.value.fields
	end
	return node_type.style_knobs
end

local function node_type_has(node_type, which)
	local names = node_type_names(node_type, which)
	return names ~= nil and #names > 0
end

local function root_entries(model)
	local out = {}
	for i = 1, #model.scope do
		local name = model.scope[i]
		local p = DocsData.params[name]
		local r = DocsData.runtime[name]
		if p then
			out[#out + 1] = { name = name, note = p.note or "", link = class_is_open(p.ref), ref = p.ref }
		elseif r then
			local link = false
			if name == "sources" then
				link = true
			elseif name == "value" or name == "style" then
				link = node_type_has(model.node_type, name)
			end
			out[#out + 1] = { name = name, note = r.note or "", link = link }
		else
			out[#out + 1] = { name = name, note = "", link = false }
		end
	end
	out[#out + 1] = { name = "globals", note = "always in scope (sandbox)", link = #DocsData.globals > 0 }
	return out
end

local function drill_entries(model, path)
	local head = path[1]

	if head == "globals" then
		local out = {}
		for i = 1, #DocsData.globals do
			local g = DocsData.globals[i]
			out[#out + 1] = { name = g.name, note = leaf_note(g.type, g.note), link = false }
		end
		return out
	end

	if head == "sources" then
		if #path == 1 then
			local out = {}
			local all = Registry.all()
			local ids = {}
			for id in pairs(all) do
				ids[#ids + 1] = id
			end
			table.sort(ids)
			for i = 1, #ids do
				local src = all[ids[i]]
				local has = src.fields ~= nil and next(src.fields) ~= nil
				out[#out + 1] = { name = ids[i], note = src.label or "", link = has, source = ids[i] }
			end
			return out
		end
		local src = Registry.get(path[2])
		if not src or not src.fields then
			return {}
		end
		if #path == 2 then
			return source_field_entries(src.fields)
		end

		local group = src.fields[path[3]]
		if type(group) ~= "table" then
			return {}
		end
		return source_field_entries(group)
	end

	if head == "value" or head == "style" then
		local names = node_type_names(model.node_type, head)
		local out = {}
		for i = 1, #(names or {}) do
			out[#out + 1] = { name = names[i], note = "", link = false }
		end
		return out
	end

	local p = DocsData.params[head]
	if not (p and p.ref) then
		return {}
	end
	local cur = p.ref
	for i = 2, #path do
		local f = class_field(cur, path[i])
		if not (f and class_is_open(f.ref)) then
			return {}
		end
		cur = f.ref
	end
	return class_entries(cur)
end

function DocsTree.prepare(model, x, y, w, ui_renderer)
	local path = model.path or {}
	local drilled = #path > 0

	local entries
	if drilled and #path <= WALK_CAP then
		entries = drill_entries(model, path)
	else
		entries = root_entries(model)
	end

	local crumb_y = y
	local back_rect
	if drilled then
		back_rect = { x = x, y = crumb_y, w = TextMetrics.measure(ui_renderer, BACK_LABEL) + NAME_PAD * 2, h = CRUMB_H }
	end
	local crumb = drilled and table.concat(path, " > ") or ROOT_TITLE
	local rule_y = crumb_y + CRUMB_H + CRUMB_PAD
	local cursor_y = rule_y + 1

	local copy_prefix = ""
	if drilled and path[1] ~= "globals" then
		copy_prefix = table.concat(path, ".") .. "."
	end

	local col1_w = COL1_MIN
	for i = 1, #entries do
		local e = entries[i]
		e.label = e.link and (e.name .. LINK_SUFFIX) or e.name
		e.label_w = TextMetrics.measure(ui_renderer, e.label) + NAME_PAD * 2
		local tw = TextMetrics.measure(ui_renderer, e.name) + NAME_PAD * 2
		if tw > col1_w then
			col1_w = tw
		end
	end
	local col1_cap = w * COL1_MAX_FRAC
	if col1_w > col1_cap then
		col1_w = col1_cap
	end
	local col2_x = x + col1_w + COL_GAP

	local rows = {}
	for i = 1, #entries do
		local e = entries[i]
		e.rect = { x = x, y = cursor_y, w = w, h = ROW_H }

		local name_w = (e.label_w < col1_w) and e.label_w or col1_w
		e.name_rect = { x = x, y = cursor_y, w = name_w, h = ROW_H }
		if not e.link then
			e.copy_path = copy_prefix .. e.name
		end
		rows[#rows + 1] = e
		cursor_y = cursor_y + ROW_H
	end

	return {
		rows = rows,
		back_rect = back_rect,
		crumb = crumb,
		crumb_y = crumb_y,
		rule_y = rule_y,
		col2_x = col2_x,
		x = x,
		w = w,
		h = cursor_y - y,
	}
end

function DocsTree.hit(lay, cx, cy)
	if not lay then
		return nil, false
	end
	local function in_rect(r)
		return r and cx >= r.x and cx <= r.x + r.w and cy >= r.y and cy <= r.y + r.h
	end
	if in_rect(lay.back_rect) then
		return { back = true }, true
	end
	for i = 1, #lay.rows do
		local e = lay.rows[i]
		if in_rect(e.rect) then
			if in_rect(e.name_rect) then
				if e.link then

					return { descend = e.source or e.group or e.name }, true
				end
				return { copy = e.copy_path }, true
			end
			return nil, true 
		end
	end
	return nil, false
end

function DocsTree.draw(d, lay, z, hover)
	if not lay then
		return
	end
	local hx = hover and hover.cx
	local hy = hover and hover.cy
	local function hot(r)
		return r and hx and hx >= r.x and hx <= r.x + r.w and hy >= r.y and hy <= r.y + r.h
	end

	if lay.back_rect then
		if hot(lay.back_rect) then
			d:rect(lay.back_rect.x, lay.back_rect.y, z, lay.back_rect.w, lay.back_rect.h, COLOR.HOVER_BG)
		end
		d:text_left(
			BACK_LABEL,
			FONT_SIZE,
			lay.back_rect.x + NAME_PAD,
			lay.back_rect.y,
			z + 1,
			lay.back_rect.w,
			CRUMB_H,
			COLOR.BACK
		)
	end
	if lay.crumb and lay.crumb ~= "" then
		d:text_left(lay.crumb, FONT_SIZE, lay.col2_x, lay.crumb_y, z + 1, lay.w, CRUMB_H, COLOR.CRUMB)
	end
	d:rect(lay.x, lay.rule_y, z, lay.w, 1, COLOR.RULE)

	for i = 1, #lay.rows do
		local e = lay.rows[i]
		local r = e.rect

		if hot(e.name_rect) then
			d:rect(e.name_rect.x, e.name_rect.y, z, e.name_rect.w, e.name_rect.h, COLOR.HOVER_BG)
		end
		d:text_left(
			e.label,
			FONT_SIZE,
			r.x + NAME_PAD,
			r.y,
			z + 1,
			lay.col2_x - r.x,
			ROW_H,
			e.link and COLOR.LINK or COLOR.LEAF
		)
		if e.note and e.note ~= "" then
			d:text_left(e.note, FONT_SIZE, lay.col2_x, r.y, z + 1, r.x + r.w - lay.col2_x, ROW_H, COLOR.NOTE)
		end
	end
end

mod.ide_docs_tree_component = DocsTree

return DocsTree
