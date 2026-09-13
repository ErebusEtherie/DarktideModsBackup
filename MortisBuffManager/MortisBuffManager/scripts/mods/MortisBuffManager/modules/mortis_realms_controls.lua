local mod = get_mod("MortisBuffManager")
local Controls = {}
local active_views = setmetatable({}, { __mode = "k" })
local function copy(source) local result = {}; for k,v in pairs(source) do result[k] = v end; return result end
local function visible(content) return content.mbm_visible == true and mod.mortis_realms_controls_active() end
local function maximum(mode,kind) return kind=="diy" and 99 or mode == "draft" and 10 or 99 end
local function native_enabled(rules) if rules.native_enabled~=nil then return rules.native_enabled end;return rules.enabled end
local function points(rules,kind) return kind=="diy" and (rules.diy_limits and rules.diy_limits.max_total or 6) or rules.limit end
local function editable(rules,kind) return not rules.locked and (kind=="diy" or rules.mode~="draft") end
local function save_points(rules,connection,kind,value)
    if kind=="diy" then return mod.set_mortis_diy_rules(value,rules.diy_enabled==true,connection) end
    return mod.set_mortis_global_rules(rules.mode,value,native_enabled(rules),connection)
end
local function finish_edit(grid, commit)
	local edit = grid._mbm_edit; grid._mbm_edit = nil
	if not edit or not commit then return end
	local rules, connection = mod.mortis_global_rules_snapshot()
	local value = edit.text:match("^%s*(%d+)%s*$"); value = value and tonumber(value)
	if value and rules and editable(rules,edit.kind) and connection == edit.connection and rules.revision == edit.revision then
		save_points(rules,connection,edit.kind,math.clamp(value,0,maximum(rules.mode,edit.kind)))
	end
end
local function change(grid, name)
	finish_edit(grid, true)
	local rules, connection = mod.mortis_global_rules_snapshot()
	if not rules then return end
	if name:sub(1,4)=="diy_" then
        if not editable(rules,"diy") then return end
        local limit,enabled=points(rules,"diy"),rules.diy_enabled==true
        if name=="diy_minus" then limit=math.max(0,limit-1)
        elseif name=="diy_plus" then limit=math.min(99,limit+1)
        elseif name=="diy_enable" then enabled=not enabled end
        mod.set_mortis_diy_rules(limit,enabled,connection);return
    end
	local limit, enabled, mode = rules.limit, native_enabled(rules), rules.mode
	if mode == "draft" and (name == "minus" or name == "plus") then return end
	if name == "minus" then limit = math.max(0, limit - 1)
	elseif name == "plus" then limit = math.min(maximum(mode), limit + 1)
	elseif name == "enable" then enabled = not enabled
	else mode = name end
	mod.set_mortis_global_rules(mode, limit, enabled, connection)
end
function Controls.update(grid, widget, input, dt)
	local content, owner = widget.content, grid._mbm_realms_view
	local rules, connection = mod.mortis_global_rules_snapshot()
	content.mbm_visible = rules ~= nil
	if not rules then finish_edit(grid, false); return end
	input = owner and owner._mbm_input or input
	local edit = grid._mbm_edit
	if edit and (not editable(rules,edit.kind) or edit.connection ~= connection or edit.revision ~= rules.revision) then finish_edit(grid, false); edit = nil end
	if edit and input and not input:is_null_service() then
		if input:get("back") then finish_edit(grid, false)
		elseif input:get("confirm_pressed") or input:get("left_pressed") and not content[edit.kind=="diy" and "mbm_diy_points_hotspot" or "mbm_points_hotspot"].is_hover then finish_edit(grid, true)
		else
			if input:get("select_all_text") then edit.replace = true end
			if input:get("clipboard_paste") then
				local value = Clipboard.get()
				if type(value) == "string" and #value <= 16 and value:match("^%s*%d+%s*$") then
					edit.text = tostring(math.clamp(tonumber(value), 0, maximum(rules.mode,edit.kind))); edit.replace = false
				end
			else for _, key in ipairs(Keyboard.keystrokes()) do
				if type(key) == "string" and key:match("^%d+$") then edit.text = (edit.replace and key or edit.text .. key):sub(1, 2); edit.replace = false
				elseif key == Keyboard.BACKSPACE or key == Keyboard.DELETE then edit.text = edit.replace and "" or edit.text:sub(1, -2); edit.replace = false
				elseif key == Keyboard.ENTER then finish_edit(grid, true); break
				elseif key == Keyboard.ESCAPE then finish_edit(grid, false); break end
			end end
		end
	end
	for _, name in ipairs({ "enable", "minus", "points", "plus", "diy_enable", "diy_minus", "diy_points", "diy_plus", "preselect", "draft", "competition" }) do
		local hotspot = content["mbm_" .. name .. "_hotspot"]
		rules = mod.mortis_global_rules_snapshot() or rules
		hotspot.disabled = rules.locked==true or owner and owner._is_main_menu_open or rules.mode == "draft" and (name == "minus" or name == "points" or name == "plus")
            or name:sub(1,4)=="diy_" and type(mod.set_mortis_diy_rules)~="function" or false
		if hotspot.disabled then hotspot.on_pressed = nil end
		if hotspot.on_pressed and not hotspot.disabled then
			hotspot.on_pressed = nil
			if name == "points" or name=="diy_points" then
				finish_edit(grid, true)
                rules,connection=mod.mortis_global_rules_snapshot()
                local kind=name=="diy_points" and "diy" or "native"
				grid._mbm_edit = { kind=kind,text = tostring(points(rules,kind)), replace = true, connection = connection, revision = rules.revision }
			else change(grid, name) end
		end
		if name == "minus" or name == "plus" or name=="diy_minus" or name=="diy_plus" then
			if hotspot.is_held and not hotspot.disabled then
				hotspot.hold = (hotspot.hold or 0) + dt
				if hotspot.hold >= (hotspot.next_repeat or 0.4) then hotspot.next_repeat = hotspot.hold + 0.08; change(grid, name) end
			else hotspot.hold, hotspot.next_repeat = nil, nil end
		end
	end
	rules = mod.mortis_global_rules_snapshot() or rules
	content.mbm_label = mod:localize("diy_policy_native")
	content.mbm_enable = mod:localize(native_enabled(rules) and "mortis_on" or "mortis_off")
	content.mbm_minus, content.mbm_plus = "−", "+"
	content.mbm_points = grid._mbm_edit and grid._mbm_edit.kind~="diy" and grid._mbm_edit.text .. "|" or tostring(rules.limit)
    content.mbm_diy_label=mod:localize("diy_policy_diy")
    content.mbm_diy_enable=mod:localize(rules.diy_enabled and "mortis_on" or "mortis_off")
    content.mbm_diy_minus,content.mbm_diy_plus="−","+"
    content.mbm_diy_points=grid._mbm_edit and grid._mbm_edit.kind=="diy" and grid._mbm_edit.text.."|" or tostring(points(rules,"diy"))
    content.mbm_diy_status=mod:localize(grid._mbm_edit and grid._mbm_edit.kind=="diy" and "diy_number_help" or "diy_points_help")
	content.mbm_status = mod:localize(grid._mbm_edit and grid._mbm_edit.kind~="diy" and "mortis_number_help" or rules.mode == "draft" and "mortis_progress_help" or rules.mode == "competition" and "mortis_competition_help" or "mortis_global_help")
	for _, mode in ipairs({ "preselect", "draft", "competition" }) do
		content["mbm_" .. mode] = mod:localize("mortis_mode_" .. mode)
		content["mbm_" .. mode .. "_selected"] = rules.mode == mode
	end
end
function Controls.blueprint(width)
	local scale = width / 1240
	local columns = { label = { 12, 8, 208, 36 }, enable = { 230, 8, 110, 36 },
		minus = { 374, 8, 38, 36 }, points = { 418, 8, 76, 36 }, plus = { 500, 8, 38, 36 }, status = { 560, 8, 656, 36 },
        diy_label={12,54,208,40},diy_enable={230,54,110,40},diy_minus={374,54,38,40},diy_points={418,54,76,40},diy_plus={500,54,38,40},diy_status={560,54,656,40},
		preselect = { 12, 104, 398, 40 }, draft = { 422, 104, 398, 40 }, competition = { 832, 104, 396, 40 } }
	local passes = { { pass_type = "rect", style = { color = { 235, 20, 32, 31 } }, visibility_function = visible } }
	for _, name in ipairs({ "label", "enable", "minus", "points", "plus", "status", "diy_label", "diy_enable", "diy_minus", "diy_points", "diy_plus", "diy_status", "preselect", "draft", "competition" }) do
		local c = columns[name]; local id = "mbm_" .. name; local button = name ~= "label" and name ~= "status" and name~="diy_label" and name~="diy_status"
		local size, offset = { c[3] * scale, c[4] }, { c[1] * scale, c[2], 2 }
		local function tint(content, style)
			local hotspot = content[id .. "_hotspot"]
			local color = style.text_color or style.color
			color[1] = hotspot and hotspot.disabled and 90 or 255
		end
		if button then
			passes[#passes + 1] = { pass_type = "rect", style_id = id .. "_bg", style = { color = { 255, 43, 55, 48 }, size = size, offset = offset }, visibility_function = visible,
				change_function = function(content, style) tint(content, style); style.color[2] = content[id .. "_selected"] and 99 or 43; style.color[3] = content[id .. "_selected"] and 84 or 55 end }
			passes[#passes + 1] = { pass_type = "texture", value = "content/ui/materials/frames/frame_tile_2px", style = { color = { 255, 150, 139, 98 }, size = size, offset = { offset[1], offset[2], 3 } }, visibility_function = visible, change_function = tint }
			passes[#passes + 1] = { pass_type = "hotspot", content_id = id .. "_hotspot", content = {}, style_id = id .. "_hotspot", style = { size = size, offset = { offset[1], offset[2], 5 } }, visibility_function = function(content) return visible(content.parent) end }
		end
		passes[#passes + 1] = { pass_type = "text", value_id = id, value = "", style_id = id,
			style = { font_type = "proxima_nova_bold", font_size = (name == "status" or name=="diy_status") and 15 or 20,
				text_color = { 255, 230, 223, 191 }, text_horizontal_alignment = button and "center" or "left", text_vertical_alignment = "center",
				size = size, offset = { offset[1], offset[2], 4 } }, visibility_function = visible, change_function = tint }
	end
	return { size = { width, 156 }, pass_template = passes,
		init = function(grid, widget, element) widget.content.element = element; Controls.update(grid, widget, nil, 0) end,
		update = Controls.update, destroy = function(grid) finish_edit(grid, false) end }
end
function Controls.wrap_layout(grid, layout, blueprints)
	if not grid._mbm_realms_view or not mod.mortis_realms_controls_active() then return layout, blueprints end
	local own, decorated = copy(blueprints), {}
	local width = blueprints.player and blueprints.player.size[1]
	if not width then return layout, blueprints end
	own.mbm_global_rules = Controls.blueprint(width)
	own.mbm_deployment = { size = { width, 32 }, pass_template = {
		{ pass_type = "text", value_id = "text", value = "", style_id = "text",
			style = { font_type = "proxima_nova_bold", font_size = 17, text_color = { 255, 175, 205, 178 },
				text_vertical_alignment = "center", offset = { 16, 0, 3 }, size = { width - 32, 32 } },
			visibility_function = function() return mod.mortis_realms_controls_active() end },
	}, init = function(_, widget, element) widget.content.element = element end,
		update = function(_, widget)
			local deployment = mod.mortis_peer_deployment(widget.content.element.mbm_status_peer)
			local status = deployment.status
			widget.content.text = mod:localize("mortis_deploy_label", mod:localize("mortis_deploy_" .. status))
				.. (deployment.version and " · " .. deployment.version or "")
			widget.style.text.text_color = status == "ready" and { 255, 170, 212, 171 }
				or (status == "connecting" or status == "loading_assets") and { 255, 227, 192, 111 } or { 255, 239, 150, 135 }
		end }
	decorated[1] = { widget_type = "mbm_global_rules" }
	for _, row in ipairs(layout) do
		if row.widget_type ~= "mbm_global_rules" and row.widget_type ~= "mbm_deployment" then
			decorated[#decorated + 1] = copy(row)
			if row.widget_type == "player" and row.peer_id then
				decorated[#decorated + 1] = { widget_type = "mbm_deployment", mbm_status_peer = row.peer_id }
			end
		end
	end
	return decorated, own
end
function Controls.cleanup()
	for view in pairs(active_views) do
		local grid = view._player_grid
		if grid then finish_edit(grid, false); grid._mbm_realms_view = nil; view:_present_player_rows(true) end
		view._mbm_input, view._mbm_controls_present = nil, false
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
		local active = mod.mortis_realms_controls_active()
		if active ~= self._mbm_controls_present then force = true end
		self._mbm_controls_present = active
		if self._player_grid then self._player_grid._mbm_realms_view = self end
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
		self._mbm_input = self._realms_rule_control_input
		local grid = self._player_grid
		local editing = grid and grid._mbm_edit
		if editing and self._is_main_menu_open then finish_edit(grid, false) end
		-- Keep Enter/Esc/inventory shortcuts away from the preparation view while typing.
		local result = func(self, dt, t, editing and input:null_service() or input)
		self._realms_rule_control_input = outer_input
		return result
	end)
	attach_method(view_class, "on_exit", function(func, self, ...)
		active_views[self] = nil
		if self._player_grid then finish_edit(self._player_grid, false); self._player_grid._mbm_realms_view = nil end
		self._mbm_input = nil
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
