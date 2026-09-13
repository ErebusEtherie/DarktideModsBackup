-- Own rows added to Realms' existing grid. No Realms files or global blueprints
-- are changed, and the optional view is never loaded by this module.
local mod = get_mod("realms_loadout")
local Inspect = mod:io_dofile("realms_loadout/scripts/mods/realms_loadout/talents/realms_inspect")
local Controls = {}
local active_views = setmetatable({}, { __mode = "k" })
Controls.geometry = { height = 46, y = 5, h = 34, font = 18,
	label = { 12, 142 }, minus = { 162, 34 }, points = { 200, 64 }, plus = { 268, 34 },
	auras = { 328, 262 }, keystones = { 606, 262 }, status = { 888, 340 } }
Controls.scum_geometry = { height = 46, y = 5, h = 34, font = 18,
	label = { 12, 122 }, minus = { 138, 30 }, points = { 172, 52 }, plus = { 228, 30 },
	stimm_label = { 274, 100 }, stimm_minus = { 378, 30 }, stimm_points = { 412, 52 }, stimm_plus = { 468, 30 },
	auras = { 514, 150 }, keystones = { 680, 198 }, status = { 894, 334 } }
local ordinary_fields = { "minus", "points", "plus", "auras", "keystones" }
local scum_fields = { "minus", "points", "plus", "stimm_minus", "stimm_points", "stimm_plus", "auras", "keystones" }

local function copy(source)
	local result = {}
	for key, value in pairs(source) do result[key] = value end
	return result
end

local function visible(content)
	return content.tpm_visible == true and mod.realms_talent_controls_active()
end

local function rules_for(widget)
	local rules, connection = mod.realms_talent_player_rules(widget.content.element.tpm_peer_id)
	-- A character switch rebuilds the native player row. Retire its old controls
	-- immediately, including any in-progress stimm edit.
	if rules and (rules.is_scum == true) ~= (widget.content.element.stimm == true) then return nil, connection, true end
	return rules, connection
end

local function set_rules(peer, values, connection, stimm)
  if stimm then
    local current = mod.realms_talent_player_rules(peer)
    if not current or not current.is_scum then return false end
    values.stimm_points, values.points = values.points, current.realms_player_points
  end
  return mod.set_realms_talent_player_rules(peer, values, connection)
end

local function finish_edit(grid, commit)
	local edit = grid._tpm_edit
	grid._tpm_edit = nil
	if not edit or not commit then return end
	local value = edit.text:match("^%s*(%d+)%s*$")
	value = value and tonumber(value)
	if not value then return end
	local rules, connection = mod.realms_talent_player_rules(edit.peer)
	if not rules or connection ~= edit.connection or rules.revision ~= edit.revision
		or (rules.is_scum == true) ~= edit.is_scum then return end
	set_rules(edit.peer, {
		points = math.clamp(value, 0, edit.stimm and 103 or 99), auras = rules.unlock_all_auras,
		keystones = rules.unlock_all_keystones }, connection, edit.stimm)
end

local function change(grid, widget, key, delta, stimm)
	finish_edit(grid, true)
	local rules, connection = rules_for(widget)
	if not rules or not rules.enabled then return end
	local values = { points = rules.realms_player_points,
		auras = rules.unlock_all_auras, keystones = rules.unlock_all_keystones }
	if key == "points" then values.points = math.clamp((stimm and rules.stimm_effective_points or values.points) + delta, 0, stimm and 103 or 99)
	else values[key] = not values[key] end
	set_rules(widget.content.element.tpm_peer_id, values, connection, stimm)
end

local function update_edit(grid, widget, input)
	local edit = grid._tpm_edit
	if not edit or edit.widget ~= widget or not input or input:is_null_service() then return end
	if input:get("back") then finish_edit(grid, false); return end
	if input:get("confirm_pressed") then finish_edit(grid, true); return end
	if input:get("left_pressed") and not widget.content[edit.hotspot].is_hover then
		finish_edit(grid, true); return
	end
	if input:get("select_all_text") then edit.replace = true end
	if input:get("clipboard_paste") then
		local text = Clipboard.get()
		if type(text) == "string" and text:match("^%s*%d+%s*$") and #text <= 16 then
			text = tostring(math.clamp(tonumber(text), 0, 999))
			edit.text = edit.replace and text or (edit.text .. text):sub(1, 3)
			edit.replace = false
		end
	else
		for _, key in ipairs(Keyboard.keystrokes()) do
			if type(key) == "string" and key:match("^%d+$") then
				edit.text = (edit.replace and key or edit.text .. key):sub(1, 3)
				edit.replace = false
			elseif key == Keyboard.BACKSPACE or key == Keyboard.DELETE then
				edit.text = edit.replace and "" or edit.text:sub(1, -2); edit.replace = false
			elseif key == Keyboard.ENTER then finish_edit(grid, true); return
			elseif key == Keyboard.ESCAPE then finish_edit(grid, false); return end
		end
	end
end

function Controls.update(grid, widget, input, dt)
	local content = widget.content
	local rules, connection, layout_changed = rules_for(widget)
	local owner = grid._tpm_realms_view
	if layout_changed and owner then owner._tpm_control_layout_dirty = true end
	content.tpm_visible = rules ~= nil
	if not rules then
		if grid._tpm_edit and grid._tpm_edit.widget == widget then finish_edit(grid, false) end
		return
	end
	input = owner and owner._tpm_input or input
	local editing = grid._tpm_edit
	if editing and editing.widget == widget and (editing.revision ~= rules.revision or editing.connection ~= connection) then
		finish_edit(grid, false)
	end
	update_edit(grid, widget, input)
	for _, name in ipairs(content.element.stimm and scum_fields or ordinary_fields) do
		local stimm = name:sub(1, 6) == "stimm_"
		local action = stimm and name:sub(7) or name
		local hotspot = content["tpm_" .. name .. "_hotspot"]
		hotspot.disabled = not rules.enabled or (owner and owner._is_main_menu_open) or false
		if hotspot.disabled then hotspot.on_pressed = nil end
		if not hotspot.disabled and hotspot.on_pressed then
			hotspot.on_pressed = nil
			if action == "points" then
				finish_edit(grid, true)
				rules, connection = rules_for(widget)
				if not rules then return end
				grid._tpm_edit = { widget = widget, peer = content.element.tpm_peer_id,
					text = tostring(stimm and rules.stimm_effective_points or rules.realms_player_points), replace = true, stimm = stimm,
					is_scum = rules.is_scum == true, hotspot = "tpm_" .. name .. "_hotspot",
					connection = connection, revision = rules.revision }
			else change(grid, widget, (action == "minus" or action == "plus") and "points" or action, action == "minus" and -1 or 1, stimm) end
		end
		if action == "minus" or action == "plus" then
			if hotspot.is_held and not hotspot.disabled then
				hotspot.tpm_hold = (hotspot.tpm_hold or 0) + dt
				if hotspot.tpm_hold >= (hotspot.tpm_next or 0.4) then
					hotspot.tpm_next = hotspot.tpm_hold + 0.08
					change(grid, widget, "points", action == "minus" and -1 or 1, stimm)
				end
			else hotspot.tpm_hold, hotspot.tpm_next = nil, nil end
		end
	end
	rules = rules_for(widget) or rules
	local edit = grid._tpm_edit
	content.tpm_label = mod:localize("tpm_player_controls")
	content.tpm_minus, content.tpm_plus = "−", "+"
	content.tpm_points = edit and edit.widget == widget and not edit.stimm and (edit.text .. "|") or tostring(rules.realms_player_points)
	if content.element.stimm then
		content.tpm_stimm_label = mod:localize("rl_stimm_controls")
		content.tpm_stimm_minus, content.tpm_stimm_plus = "−", "+"
		content.tpm_stimm_points = edit and edit.widget == widget and edit.stimm and (edit.text .. "|") or tostring(rules.stimm_effective_points)
	end
	content.tpm_auras = mod:localize("tpm_player_auras", mod:localize(rules.unlock_all_auras and "tpm_multi" or "tpm_single"))
	content.tpm_keystones = mod:localize("tpm_player_keystones", mod:localize(rules.unlock_all_keystones and "tpm_multi" or "tpm_single"))
	content.tpm_status = mod:localize(not rules.enabled and "tpm_player_enable_first"
		or edit and edit.widget == widget and "tpm_player_number_help" or "tpm_player_host_only")
	if not edit and mod.realms_talent_deployment then
		local deployment = mod.realms_talent_deployment(content.element.tpm_peer_id)
		if deployment then
			content.tpm_status = "realms_loadout" .. (deployment.version and " " .. deployment.version or "")
                .. "\n" .. mod:localize("tpm_deploy_" .. deployment.status)
		end
	end

	local element = content.element
	local geometry = element and element.stimm and Controls.scum_geometry or Controls.geometry

	Inspect.update_row(grid, widget, content, geometry, dt)
end

function Controls.blueprint(width, stimm)
	local g = stimm and Controls.scum_geometry or Controls.geometry
	local passes = { { pass_type = "rect", style = { color = { 230, 22, 38, 48 } }, visibility_function = visible } }
	for _, name in ipairs(stimm and { "label", "minus", "points", "plus", "stimm_label", "stimm_minus", "stimm_points", "stimm_plus", "auras", "keystones", "status" } or { "label", "minus", "points", "plus", "auras", "keystones", "status" }) do
		local column = g[name]
		local button = name ~= "label" and name ~= "stimm_label" and name ~= "status"
		local id = "tpm_" .. name
		if button then
			passes[#passes + 1] = { pass_type = "rect", style_id = id .. "_bg",
				style = { color = { 255, 45, 66, 80 }, size = { column[2], g.h }, offset = { column[1], g.y, 1 } },
				visibility_function = visible, change_function = function(content, style)
					style.color[1] = content[id .. "_hotspot"].disabled and 90 or 255
				end }
			passes[#passes + 1] = { pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px",
				style = { color = { 255, 117, 144, 159 }, size = { column[2], g.h }, offset = { column[1], g.y, 2 } },
				visibility_function = visible }
			passes[#passes + 1] = { pass_type = "hotspot", content_id = id .. "_hotspot", content = {},
				style_id = id .. "_hotspot", style = { size = { column[2], g.h }, offset = { column[1], g.y, 5 } },
				visibility_function = function(content) return visible(content.parent) end }
		end
		passes[#passes + 1] = { pass_type = "text", value_id = id, value = "", style_id = id,
			style = { font_type = "proxima_nova_bold", font_size = name == "status" and 16 or g.font,
				text_color = { 255, 226, 223, 195 }, text_horizontal_alignment = button and "center" or "left",
				text_vertical_alignment = "center", size = { column[2], g.h }, offset = { column[1], g.y, 3 } },
			visibility_function = visible }
	end
	Inspect.add_passes(passes, width, g)

	return { size = { width, g.height }, pass_template = passes,
		init = function(grid, widget, element)
			widget.content.element = element
			widget.content._inspect_row_width = width
			Controls.update(grid, widget, nil, 0)
		end, update = Controls.update,
		destroy = function(grid, widget)
			if grid._tpm_edit and grid._tpm_edit.widget == widget then finish_edit(grid, false) end
		end }
end

function Controls.wrap_layout(grid, layout, blueprints)
	if not grid._tpm_realms_view or not mod.realms_talent_controls_active() then return layout, blueprints end
	local decorated, own_blueprints = {}, copy(blueprints)
	local width = blueprints.player and blueprints.player.size[1]
	if not width or width < 1240 then return layout, blueprints end
	own_blueprints.tpm_player_rules = Controls.blueprint(width)
    own_blueprints.rl_stimm_rules = Controls.blueprint(width, true)
	for _, row in ipairs(layout) do
		decorated[#decorated + 1] = copy(row)
		if row.widget_type == "player" and row.peer_id then
			-- Deliberately no element.peer_id: Realms' latency updater handles only its player rows.
			local rules = mod.realms_talent_player_rules(row.peer_id)
			local stimm = rules and rules.is_scum == true or false
			decorated[#decorated + 1] = { widget_type = stimm and "rl_stimm_rules" or "tpm_player_rules",
				tpm_peer_id = row.peer_id, stimm = stimm }
		end
	end
	return decorated, own_blueprints
end

function Controls.cleanup()
	for view in pairs(active_views) do
		local grid = view._player_grid
		if grid then finish_edit(grid, false) end
		view._tpm_input = nil
		view._tpm_controls_present = false
		view._tpm_control_layout_dirty = nil
		-- Blueprints and callbacks live on the grid after DMF disables hooks.
		-- Rebuild from Realms' own rows to remove the controls and their spacing.
		if grid then view:_present_player_rows(true); grid._tpm_realms_view = nil end
	end
	active_views = setmetatable({}, { __mode = "k" })
end

local attached = setmetatable({}, { __mode = "k" })
local function attach_method(class, name, callback)
	if not class or type(class[name]) ~= "function" then return end
	local methods = attached[class]
	if not methods then methods = {}; attached[class] = methods end
	-- Shared passive ancestry metadata lets independently installed controls
	-- recognize their wrapper beneath the other mod, including after re-enable.
	local chains = rawget(class, "_realms_rule_control_chains")
	if not chains then chains = setmetatable({}, { __mode = "k" }); class._realms_rule_control_chains = chains end
	local cursor = class[name]
	while cursor do
		if methods[name] == cursor then return end
		cursor = chains[cursor]
	end
	-- Native class() reuses the class table and overwrites its methods on IO reload.
	-- DMF caches originals by table/method, so use a fresh hook target for each
	-- replacement. The resulting wrapper still follows DMF enable/disable state.
	local previous = class[name]
	-- DMF unwraps copied internal hooks. A forwarding function preserves the
	-- other mod's complete chain instead of restoring the native original.
	local target = { [name] = function(...) return previous(...) end }
	mod:hook(target, name, callback)
	chains[target[name]] = previous
	class[name] = target[name]
	methods[name] = target[name]
end

function Controls.attach(view_class, grid_class)
	attach_method(view_class, "_present_player_rows", function(func, self, force)
		active_views[self] = true
		local active = mod.realms_talent_controls_active()
		if active ~= self._tpm_controls_present or self._tpm_control_layout_dirty then force = true end
		self._tpm_control_layout_dirty = nil
		self._tpm_controls_present = active
		if self._player_grid then self._player_grid._tpm_realms_view = self end
		return func(self, force)
	end)
	-- Native class() copies inherited methods. Hook the actual Realms subclass,
	-- not ViewElementGrid after that copy has already happened.
	attach_method(grid_class, "present_grid_layout", function(func, self, layout, blueprints, ...)
		layout, blueprints = Controls.wrap_layout(self, layout, blueprints)
		return func(self, layout, blueprints, ...)
	end)
	attach_method(view_class, "update", function(func, self, dt, t, input)
		-- Both optional controls receive the original input, even if the outer
		-- wrapper masks shortcuts while its number editor is active.
		local outer_input = self._realms_rule_control_input
		self._realms_rule_control_input = outer_input or input
		self._tpm_input = self._realms_rule_control_input
		local grid = self._player_grid
		local editing = grid and grid._tpm_edit
		if editing and self._is_main_menu_open then finish_edit(grid, false) end
		-- Keep Enter/Esc/inventory shortcuts away from the preparation view while typing.
		local result = func(self, dt, t, editing and input:null_service() or input)
		self._realms_rule_control_input = outer_input
		return result
	end)
	attach_method(view_class, "on_exit", function(func, self, ...)
		active_views[self] = nil
		if self._player_grid then finish_edit(self._player_grid, false); self._player_grid._tpm_realms_view = nil end
		self._tpm_input = nil
		return func(self, ...)
	end)
end

function Controls.refresh_hooks()
	local classes = rawget(_G, "CLASS")
	if classes then Controls.attach(classes.RealmsPreparationView, classes.RealmsPreparationGrid) end
end

function Controls.install()
	-- DMF's IO paths bypass hook_require and run on every require. Attach only
	-- after this exact optional view has finished defining its current methods.
	mod:hook(_G, "require", function(func, path, ...)
		local result = func(path, ...)
		if path == "Realms/scripts/mods/Realms/views/preparation_view/preparation_view" then
			Controls.refresh_hooks()
		end
		return result
	end)
	Controls.refresh_hooks()
end

return Controls
