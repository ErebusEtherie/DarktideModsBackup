local mod = get_mod("wkc")

local ItemPassTemplates = require("scripts/ui/pass_templates/item_pass_templates")
local WeaponTemplate    = require("scripts/utilities/weapon/weapon_template")
local UIWidget          = require("scripts/managers/ui/ui_widget")

local DETAIL_WIDGET = "wkc_detail_kills"
local ICON = "content/ui/materials/hud/interactions/icons/enemy_priority"
local ICON_INSTANCE = "content/ui/materials/icons/generic/danger"
local ICON_INSTANCE_SCALE = 0.85

local SKIP_TEMPLATES = { credits_goods_item = true }

local _template_cache = {}

mod._overlay_cards = setmetatable({}, { __mode = "k" })
mod._detail_rev = setmetatable({}, { __mode = "k" })
mod._overlay_seen = { grid = 0, loadout = 0 }
mod._layout_gen = 0

local function item_from_content(content)
	if type(content) ~= "table" then return nil end
	local item = content.item
	if type(item) == "table" then return item end
	local element = content.element
	if type(element) == "table" then
		item = element.real_item
		if type(item) == "table" then return item end
		item = element.item
		if type(item) == "table" then return item end
	end
	return nil
end
mod._overlay_item_from_content = item_from_content

local function is_pass_template(t)
	if type(t) ~= "table" then return false end
	local n = #t
	if n == 0 then return false end
	for i = 1, n do
		local pass = t[i]
		if type(pass) ~= "table" or pass.pass_type == nil then return false end
	end
	return true
end
mod._overlay_is_pass_template = is_pass_template

local function template_for_item(item)
	if type(item) ~= "table" then return nil end
	local key = item.weapon_progression_template or item.weapon_template
	if type(key) ~= "string" then key = nil end
	if key then
		local cached = _template_cache[key]
		if cached ~= nil then return cached or nil end
	end
	local ok, template = pcall(WeaponTemplate.weapon_template_from_item, item)
	local name = (ok and template and template.name) or nil
	if key then _template_cache[key] = name or false end
	return name
end

local function kills_for_item(item)
	if not mod:is_enabled() then return nil end
	local name = template_for_item(item)
	if not name then return nil end
	if mod._share_kills_for_item then
		local kills, foreign = mod._share_kills_for_item(item, name)
		if foreign then
			if not kills or kills <= 0 then return nil end
			return kills
		end
	end
	local gid = mod._gear_id_for(name, item)
	if gid and not mod._label_seen[gid] then
		mod._label_seen[gid] = true
		mod._note_instance_label(item, name)
	end
	local s = mod._bucket_for(name, item)
	local kills = s and s.kills or 0
	if kills <= 0 then return nil end
	return kills
end
mod._overlay_kills_for_item = kills_for_item

local function card_cfg()
	return mod._layout_geom().card
end

local function detail_cfg()
	return mod._layout_geom().detail
end

local function lobby_cfg()
	return mod._layout_geom().lobby
end

local function per_instance_for_item(item)
	if mod._share_per_instance_for_item then
		local flag, foreign = mod._share_per_instance_for_item(item)
		if foreign then return flag end
	end
	return mod._per_instance()
end
mod._overlay_per_instance_for_item = per_instance_for_item

local function icon_material(cfg, per_instance)
	local wanted = cfg and cfg.material
	if wanted and wanted ~= "" and wanted ~= ICON and mod._material_ok(wanted) then
		return wanted, 1
	end
	if per_instance and mod._material_ok(ICON_INSTANCE) then
		return ICON_INSTANCE, ICON_INSTANCE_SCALE
	end
	return ICON, 1
end
mod._overlay_icon_material = icon_material

local function set_color(dst, c)
	if not (dst and c) then return end
	dst[1] = c.a or 255
	dst[2] = c.r or 255
	dst[3] = c.g or 255
	dst[4] = c.b or 255
end

local function card_on()
	return card_cfg().on and mod:get("wkc_card_kills") ~= false
end

local function detail_on()
	return detail_cfg().on and mod:get("wkc_detail_kills") ~= false
end

local function card_kills(content)
	if not card_on() then return nil end
	return kills_for_item(item_from_content(content))
end

local function card_text_style()
	return {
		horizontal_alignment      = "right",
		vertical_alignment        = "center",
		text_horizontal_alignment = "left",
		text_vertical_alignment   = "center",
		font_size                 = 20,
		font_type                 = "proxima_nova_bold",
		drop_shadow               = true,
		size                      = { 160, 30 },
		offset                    = { 0, 0, 12 },
		text_color                = { 255, 255, 255, 255 },
	}
end

local function card_icon_style()
	return {
		horizontal_alignment = "right",
		vertical_alignment   = "center",
		size                 = { 22, 22 },
		offset               = { 0, 0, 12 },
		color                = { 255, 255, 255, 255 },
	}
end

local card_text_pass = {
	pass_type = "text",
	value_id  = "wkc_kills",
	style_id  = "wkc_kills",
	value     = "",
	style     = card_text_style(),
	change_function = function(content, style)
		local cfg = card_cfg()
		local kills = card_kills(content)
		local text = kills and mod._abbrev_num(kills) or ""
		content.wkc_kills = text

		local size = content.size
		local x, y = mod._card_offsets(cfg, size and size[1], size and size[2])
		local box_w = mod._no_wrap_w(cfg.font_size, text, cfg.text_w)

		style.font_size = cfg.font_size
		style.font_type = cfg.font_type
		style.size[1]   = box_w
		style.offset[1] = x + (box_w - cfg.text_w)
		style.offset[2] = y
		style.offset[3] = cfg.layer
		set_color(style.text_color, cfg.color)
	end,
	visibility_function = function(content)
		return card_kills(content) ~= nil
	end,
}

local card_icon_pass = {
	pass_type = "texture",
	value_id  = "wkc_kills_icon",
	style_id  = "wkc_kills_icon",
	value     = ICON,
	style     = card_icon_style(),
	change_function = function(content, style)
		local cfg = card_cfg()
		local mat, scale = icon_material(cfg,
			per_instance_for_item(item_from_content(content)))
		content.wkc_kills_icon = mat

		local size = content.size
		local x, y = mod._card_offsets(cfg, size and size[1], size and size[2])

		style.size[1]   = cfg.icon_size * scale
		style.size[2]   = cfg.icon_size * scale
		style.offset[1] = x - cfg.text_w - cfg.gap
		style.offset[2] = y
		style.offset[3] = cfg.layer
		set_color(style.color, cfg.icon_color)
	end,
	visibility_function = function(content)
		return card_cfg().icon_on and card_kills(content) ~= nil
	end,
}

local function lobby_kills(content)
	if not lobby_cfg().on then return nil end
	local item = content and content.item
	if type(item) ~= "table" then return nil end
	return kills_for_item(item)
end
mod._overlay_lobby_kills = lobby_kills

local lobby_text_pass = {
	pass_type = "text",
	value_id  = "wkc_lobby_kills",
	style_id  = "wkc_lobby_kills",
	value     = "",
	style = {
		horizontal_alignment      = "center",
		vertical_alignment        = "bottom",
		text_horizontal_alignment = "left",
		text_vertical_alignment   = "center",
		font_size                 = 14,
		font_type                 = "proxima_nova_bold",
		drop_shadow               = true,
		size                      = { 26, 18 },
		offset                    = { 0, 17, 30 },
		text_color                = { 255, 255, 255, 255 },
	},
	change_function = function(content, style)
		local cfg = lobby_cfg()
		local kills = lobby_kills(content)
		local text = kills and mod._abbrev_num(kills) or ""
		content.wkc_lobby_kills = text

		local box_w = mod._no_wrap_w(cfg.font_size, text, cfg.text_w)
		local text_dx = mod._lobby_offsets(cfg, box_w)

		style.font_size = cfg.font_size
		style.font_type = cfg.font_type
		style.size[1]   = box_w
		style.size[2]   = cfg.font_size + 4
		style.offset[1] = text_dx
		style.offset[2] = cfg.y
		style.offset[3] = cfg.layer
		set_color(style.text_color, cfg.color)
	end,
	visibility_function = function(content)
		return lobby_kills(content) ~= nil
	end,
}

local lobby_icon_pass = {
	pass_type = "texture",
	value_id  = "wkc_lobby_icon",
	style_id  = "wkc_lobby_icon",
	value     = ICON,
	style = {
		horizontal_alignment = "center",
		vertical_alignment   = "bottom",
		size                 = { 14, 14 },
		offset               = { 0, 17, 30 },
		color                = { 255, 255, 255, 255 },
	},
	change_function = function(content, style)
		local cfg = lobby_cfg()
		local mat, scale = icon_material(cfg,
			per_instance_for_item(content and content.item))
		content.wkc_lobby_icon = mat

		local _, icon_dx = mod._lobby_offsets(cfg, 0)
		local isz = cfg.icon_size * scale

		style.size[1]   = isz
		style.size[2]   = isz
		style.offset[1] = icon_dx
		style.offset[2] = cfg.y + (cfg.font_size - isz) * 0.5
		style.offset[3] = cfg.layer
		set_color(style.color, cfg.icon_color)
	end,
	visibility_function = function(content)
		return lobby_cfg().icon_on and lobby_kills(content) ~= nil
	end,
}

local function graft_lobby_passes(blueprint)
	if type(blueprint) ~= "table" then return false end
	local passes = blueprint.pass_template
	if not is_pass_template(passes) then return false end
	for i = 1, #passes do
		if passes[i].value_id == "wkc_lobby_kills" then return false end
	end
	passes[#passes + 1] = lobby_text_pass
	passes[#passes + 1] = lobby_icon_pass
	return true
end
mod._overlay_graft_lobby = graft_lobby_passes

mod:hook_require("scripts/ui/views/lobby_view/lobby_view_content_blueprints",
	function(blueprints)
		local ok = type(blueprints) == "table"
			and graft_lobby_passes(blueprints.item_icon)
		mod:info("share: lobby weapon slots grafted: " .. tostring(ok))
	end)

for key, template in pairs(ItemPassTemplates) do
	if not SKIP_TEMPLATES[key] and is_pass_template(template) then
		template[#template + 1] = card_text_pass
		template[#template + 1] = card_icon_pass
	end
end

local function is_card(widget)
	if type(widget) ~= "table" then return false end
	local content = widget.content
	if not content or content.wkc_kills == nil then return false end
	return item_from_content(content) ~= nil
end
mod._overlay_is_card = is_card

local function track_card(widget)
	if not is_card(widget) then return end
	mod._overlay_cards[widget] = true
	widget.dirty = true
end

function mod._overlay_layout_bumped()
	mod._layout_gen = mod._layout_gen + 1
	for widget in pairs(mod._overlay_cards) do
		widget.dirty = true
	end
end

function mod.update(dt)
	if not mod:is_enabled() then return end
	if mod._layout_poll and mod._layout_poll(dt) then
		mod._overlay_layout_bumped()
	end
	if mod._share_update then
		mod._share_update(dt)
	end
end

mod:hook(CLASS.ViewElementGrid, "_create_entry_widget_from_config",
	function(func, self, ...)
		local widget, alignment_widget = func(self, ...)
		mod._overlay_seen.grid = mod._overlay_seen.grid + 1
		track_card(widget)
		return widget, alignment_widget
	end)

local function sweep_widgets(set)
	if not set then return end
	for i = 1, #set do
		local widget = set[i]
		if widget and not mod._overlay_cards[widget] then
			mod._overlay_seen.loadout = mod._overlay_seen.loadout + 1
			track_card(widget)
		end
	end
end

mod:hook_safe(CLASS.InventoryView, "update", function(self)
	sweep_widgets(self._loadout_widgets)
	sweep_widgets(self._grid_widgets)
end)

local _detail_definition

local function detail_definition()
	if _detail_definition then return _detail_definition end

	local passes = {
		{
			pass_type = "text",
			value_id  = "text",
			style_id  = "text",
			value     = "",
			style = {
				horizontal_alignment      = "center",
				vertical_alignment        = "center",
				text_horizontal_alignment = "left",
				text_vertical_alignment   = "center",
				font_size                 = 22,
				font_type                 = "proxima_nova_bold",
				drop_shadow               = true,
				size                      = { 360, 60 },
				offset                    = { 0, 0, 12 },
				text_color                = { 255, 255, 255, 255 },
			},
			visibility_function = function() return mod:is_enabled() end,
		},
		{
			pass_type = "texture",
			value_id  = "wkc_icon",
			style_id  = "wkc_icon",
			value     = ICON,
			style = {
				horizontal_alignment = "center",
				vertical_alignment   = "center",
				size                 = { 26, 26 },
				offset               = { 0, 0, 14 },
				color                = { 255, 255, 255, 255 },
			},
			visibility_function = function() return mod:is_enabled() end,
		},
	}

	_detail_definition = UIWidget.create_definition(
		passes, "pivot", { text = "" }, { 360, 60 })
	return _detail_definition
end

local function element_widget(element)
	local by_name = element and element._widgets_by_name
	local widgets = element and element._widgets
	if not (by_name and widgets and element._create_widget) then return nil end

	local widget = by_name[DETAIL_WIDGET]
	if widget then return widget end

	local ok, created = pcall(element._create_widget, element, DETAIL_WIDGET, detail_definition())
	if not ok or not created then return nil end

	widgets[#widgets + 1] = created
	created.visible = false
	return created
end

local function update_detail_widget(widget, item)
	if not widget then return end

	local kills = detail_on() and kills_for_item(item) or nil
	if not kills then
		if widget.visible then
			widget.visible = false
			widget.dirty = true
		end
		return
	end

	local text = mod._abbrev_num(kills)
	local rev = mod._layout_revision or 0
	if widget.visible and mod._detail_rev[widget] == rev
		and widget.content.text == text then
		return
	end
	mod._detail_rev[widget] = rev

	local cfg = detail_cfg()
	widget.content.text = text
	local icon_mat, icon_scale = icon_material(cfg, per_instance_for_item(item))
	widget.content.wkc_icon = icon_mat

	local size = widget.content.size
	if size then size[1] = cfg.w; size[2] = cfg.h end

	widget.offset = widget.offset or { 0, 0, 0 }
	widget.offset[1] = cfg.x
	widget.offset[2] = cfg.y
	widget.offset[3] = cfg.layer

	local ts = widget.style and widget.style.text
	if ts then
		local box_w = mod._no_wrap_w(cfg.font_size, widget.content.text)
		ts.font_size = cfg.font_size
		ts.font_type = cfg.font_type
		ts.size[1]   = box_w
		ts.size[2]   = cfg.h
		ts.offset[1] = mod._detail_text_dx(cfg, box_w)
		ts.offset[3] = cfg.layer
		set_color(ts.text_color, cfg.color)
	end

	local is = widget.style and widget.style.wkc_icon
	if is then
		is.size[1]   = cfg.icon_size * icon_scale
		is.size[2]   = cfg.icon_size * icon_scale
		is.offset[1] = cfg.icon_dx
		is.offset[2] = cfg.icon_dy
		is.offset[3] = cfg.layer + 2
		set_color(is.color, cfg.icon_color)
	end

	widget.visible = true
	widget.dirty = true
end

function mod._overlay_element_update(element)
	local widget = element_widget(element)
	if not widget then return end

	local owner = element._parent
	if owner and mod._stats_panel_visible and mod._stats_panel_visible[owner] then
		widget.visible = false
		return
	end

	update_detail_widget(widget, element._item)
end

mod:hook_safe(CLASS.ViewElementWeaponStats, "update", function(self)
	mod._overlay_element_update(self)
end)

mod:hook_safe(CLASS.ViewElementWeaponStats, "stop_presenting", function(self)
	local widget = self._widgets_by_name and self._widgets_by_name[DETAIL_WIDGET]
	if widget then widget.visible = false end
end)

mod:hook(CLASS.InventoryView, "_create_entry_widget_from_config",
	function(func, self, ...)
		local widget, alignment_widget = func(self, ...)
		mod._overlay_seen.grid = mod._overlay_seen.grid + 1
		track_card(widget)
		return widget, alignment_widget
	end)
