
local mod = get_mod("hud_studio")

if mod.hud_studio_td_controller then
	return mod.hud_studio_td_controller
end

local Thresholds = mod:core(mod.hud_studio_thresholds, "blocks/thresholds")
local Layout = mod:core(mod.hud_studio_threshold_designer, "hud/editor/elements/threshold_designer/threshold_designer")
local NodeForm = mod:core(mod.hud_studio_node_form, "hud/editor/forms/node_form")
local NodeTypes = mod:core(mod.hud_studio_node_registry, "blocks/registry")
local TextInput = mod:core(mod.hud_studio_text_input_component, "hud/editor/elements/field/text_input")
local Numeric = mod:core(mod.hud_studio_numeric_component, "hud/editor/elements/field/numeric")
local Dropdown = mod:core(mod.hud_studio_dropdown_component, "hud/editor/elements/field/dropdown")
local Rgba = mod:core(mod.hud_studio_rgba_component, "hud/editor/elements/field/rgba")
local Checklist = mod:core(mod.hud_studio_checklist_component, "hud/editor/elements/field/checklist")
local Checkbox = mod:core(mod.hud_studio_checkbox_component, "hud/editor/elements/field/checkbox")
local C = mod:core(mod.editor_constants, "hud/editor/constants")
local Format = mod:core(mod.editor_format, "hud/editor/format")

---@class TdController
local TdController = {}

---@return table|nil spec
function TdController.spec(node, field)
	return node and NodeForm.threshold_spec(node, field)
end

local function ensure_rows(spec, i)
	local list = spec.list
	for j = 1, i do
		if not list[j] then
			list[j] = { pct = 0, color = table.clone(Thresholds.DEFAULT_COLOR) }
		end
	end
	return list[i]
end

local function row_at(spec, i)
	return spec.list[i]
end

---@return integer
function TdController.row_count(spec)
	if NodeForm.threshold_scale(spec) == "boolean" then
		return #Thresholds.BOOL_ROWS
	end
	local n = #spec.list
	return math.min(math.max(n, 1) + 1, Layout.MAX_ROWS)
end

function TdController.set_pct(spec, i, n)
	local list = spec.list
	if n == nil then
		for j = #list, i, -1 do
			list[j] = nil
		end
		return
	end
	local entry = ensure_rows(spec, i)
	entry.pct = n
end

function TdController.set_color(spec, i, color)
	ensure_rows(spec, i).color = color
end

---@return table ctrl
function TdController.pct_ctrl(spec, i)
	return {
		kind = "text",
		token = "td/pct/" .. i,
		get = function()
			local e = row_at(spec, i)
			if e and e.pct ~= nil then
				return Format.value(e.pct)
			end
			return (i == 1) and "0" or ""
		end,
		set = function(v)
			TdController.set_pct(spec, i, tonumber(v))
		end,
	}
end

---@return table ctrl
function TdController.bool_label_ctrl(i)
	local row = Thresholds.BOOL_ROWS[i]
	local text = row and row.text or ""
	return {
		kind = "text",
		disabled = true,
		input_opts = { bg = C.COLOR.CTRL_BG_DISABLED, bg_hover = C.COLOR.CTRL_BG_DISABLED },
		get = function()
			return text
		end,
	}
end

---@param always_default boolean?
---@return table ctrl
function TdController.value_ctrl(spec, i, always_default)
	return {
		kind = "rgba",
		get = function()
			local e = row_at(spec, i)
			return (e and e.color) or ((always_default or i == 1) and Thresholds.DEFAULT_COLOR or nil)
		end,
		set = function(c)
			TdController.set_color(spec, i, c)
		end,
	}
end

function TdController.ctrls(cache, node, field, spec, row_count)
	local scale = NodeForm.threshold_scale(spec)
	if cache.node ~= node or cache.field ~= field or cache.scale_mode ~= scale then
		cache.node, cache.field, cache.scale_mode = node, field, scale
		cache.pct = {}
		cache.value = {}
		cache.current = nil
		cache.max = nil
		cache.scale = nil
	end
	cache.scale = cache.scale or NodeForm.threshold_scale_control(node, field)
	local boolean_scale = scale == "boolean"
	for i = 1, row_count do
		cache.pct[i] = cache.pct[i]
			or (boolean_scale and TdController.bool_label_ctrl(i) or TdController.pct_ctrl(spec, i))
		cache.value[i] = cache.value[i] or TdController.value_ctrl(spec, i, boolean_scale)
	end
	return cache
end

local function control_parts(kind, r)
	if kind == "dropdown" then
		return Dropdown.parts(r.x, r.y, r.w, r.h)
	elseif kind == "numeric" then
		return Numeric.parts(r.x, r.y, r.w, r.h)
	elseif kind == "text" then
		return TextInput.parts(r.x, r.y, r.w, r.h)
	elseif kind == "checkbox" then
		return Checkbox.parts(r.x, r.y, r.w, r.h)
	elseif kind == "button" then
		return { box = { x = r.x, y = r.y, w = r.w, h = r.h } }
	end
	return nil
end

---@return table ctrl
local function mirror_ctrl(node, field)
	return {
		kind = "text",
		disabled = true,

		input_opts = { bg = C.COLOR.CTRL_BG_DISABLED, bg_hover = C.COLOR.CTRL_BG_DISABLED },
		get = function()
			return NodeForm.value_summary(node, field)
		end,
	}
end

local MIRROR_HINT = mod:localize("td_mirror_hint")

---@return table items, table labels, number height, boolean mirrored
local function ratio_stacks(node, node_type, field, spec, prefix, panel, y, cache, boolean_scale)
	local left, right = Layout.columns(panel.x, panel.w)
	if boolean_scale then
		left = Layout.full_column(panel.x, panel.w)
	end

	local mirror = NodeForm.threshold_uses_mirror(spec) and NodeForm.threshold_mirror(node_type) or nil

	if not cache.current then
		if mirror then

			cache.current =
				{ label = mod:localize("field_label_current"), mode = mirror_ctrl(node, mirror.current), controls = {} }
			cache.max = { label = mod:localize("field_label_max"), mode = mirror_ctrl(node, mirror.max), controls = {} }
		else
			cache.current =
				NodeForm.threshold_input_group(node, prefix, field, "current", mod:localize("field_label_current"))

			cache.max = NodeForm.threshold_input_group(node, prefix, field, "max", mod:localize("field_label_max"))
		end
	end

	local items, labels = {}, {}
	local h = math.max(
		Layout.stack_group(cache.current, left.x, y, left.w, items, labels),
		Layout.stack_group(cache.max, right.x, y, right.w, items, labels)
	)

	for i = 1, #items do
		local it = items[i]
		it.parts = control_parts(it.ctrl.kind, it.ctrl_rect)
	end
	return items, labels, h, mirror ~= nil
end

---@return table|nil lay { frame, title, bar, ratio, hint, scale, rows, items, labels, list }
function TdController.layout(panel, node, field, cache)
	local spec = TdController.spec(node, field)
	if not spec then
		return nil
	end
	local node_type = NodeTypes.get(node.type)
	local row_count = TdController.row_count(spec)
	TdController.ctrls(cache, node, field, spec, row_count)

	local scale = NodeForm.threshold_scale(spec)
	local boolean_scale = scale == "boolean"
	local prefix = "td/" .. tostring(node.id or node.type) .. "/" .. field
	local ratio_items, ratio_labels, ratio_h, mirrored =
		ratio_stacks(node, node_type, field, spec, prefix, panel, Layout.ratio_y(panel.y), cache, boolean_scale)

	local hint_h = mirrored and Layout.HINT_H or 0
	local geo = Layout.layout(panel.x, panel.y, panel.w, row_count, ratio_h, hint_h, Checklist.LINE_H)

	local items = ratio_items

	local scale_ctrl = cache.scale
	if geo.scale and scale_ctrl then
		items[#items + 1] = {
			t = "field",
			ctrl = scale_ctrl,
			parts = Layout.scale_parts(geo.scale.ctrl, scale_ctrl.items),
			ctrl_rect = geo.scale.ctrl,
			label_rect = { x = geo.scale.ctrl.x, y = geo.scale.ctrl.y, w = geo.scale.ctrl.w, h = 0 },
		}
		ratio_labels[#ratio_labels + 1] = {
			x = geo.scale.label.x,
			y = geo.scale.label.y,
			w = geo.scale.label.w,
			h = geo.scale.label.h,
			text = scale_ctrl.label,
			group = true,
		}
	end

	for i = 1, #geo.rows do
		local r = geo.rows[i]

		items[#items + 1] = {
			t = "field",

			pct = scale == "percent",
			ctrl = cache.pct[i],
			parts = TextInput.parts(r.pct.x, r.pct.y, r.pct.w, r.pct.h),
			ctrl_rect = r.pct,
			label_rect = { x = r.pct.x, y = r.pct.y, w = r.pct.w, h = 0 },
		}
		items[#items + 1] = {
			t = "field",
			ctrl = cache.value[i],
			parts = Rgba.parts(r.value.x, r.value.y, r.value.w, r.value.h),
			ctrl_rect = r.value,
			label_rect = { x = r.value.x, y = r.value.y, w = r.value.w, h = 0 },
		}
	end

	geo.items = items
	geo.labels = ratio_labels
	geo.hint_text = (hint_h > 0) and MIRROR_HINT or nil
	geo.list = spec.list
	geo.band_scale = scale
	return geo
end

mod.hud_studio_td_controller = TdController

return TdController
