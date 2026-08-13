

---@param Module DLH_SettingsMenu
---@param mod DL_Mod
---@param base_path string
return function(Module, mod, base_path)
	if Module.manager then
		return Module.manager
	end

	local ACTIVE_TAB_KEY = "__dl_settings_menu_active_tab"

	local SCROLL_KEY = "__dl_settings_menu_scroll"

	---@class DLH_SettingsMenuState
	---@field open boolean whether the modal is currently shown
	---@field built boolean set by build_menu; guards duplicate builds
	local State = {
		open = false,
		built = false,
	}

	Module.state = State

	local Manager = {}

	local Keyboard = rawget(_G, "Keyboard")
	local Mouse = rawget(_G, "Mouse")

	---@param bind table { device, name }
	---@return boolean
	local function bind_pressed(bind)
		if bind.device == "mouse" then
			if Mouse and Mouse.button_index and Mouse.pressed then
				local index = Mouse.button_index(bind.name)
				return index ~= nil and Mouse.pressed(index) or false
			end
			return false
		end
		if Keyboard and Keyboard.button_index and Keyboard.pressed then
			local index = Keyboard.button_index(bind.name)
			return index ~= nil and Keyboard.pressed(index) or false
		end
		return false
	end

	function Manager.dispatch_keybinds()
		if not mod:is_enabled() then
			return
		end
		if Managers.ui and Managers.ui:using_input(true) then
			return
		end
		local Schema = Module.schema
		if not Schema then
			return
		end

		local controls = Module.schema_builder.all_controls(Schema)
		for i = 1, #controls do
			local def = controls[i]
			if def.type == "keybind" and def.function_name and not Manager.is_hidden(def) and not Manager.is_disabled(def) then
				local bind = mod:get(def.key)
				if type(bind) == "table" and bind.name and bind_pressed(bind) then
					local fn = mod[def.function_name]
					if type(fn) == "function" then
						fn(mod, true)
					end
				end
			end
		end
	end

	function Manager.is_open()
		return State.open == true
	end

	function Manager.open()
		State.open = true
	end

	function Manager.close()
		State.open = false
	end

	function Manager.toggle()
		State.open = not State.open
	end

	---@return string | nil
	function Manager.active_tab_id()
		local id = mod:get(ACTIVE_TAB_KEY)
		return type(id) == "string" and id or nil
	end

	---@param id string
	function Manager.set_active_tab_id(id)
		mod:set(ACTIVE_TAB_KEY, id)
	end

	---@return number | nil
	function Manager.scroll_offset()
		local offset = mod:get(SCROLL_KEY)
		return type(offset) == "number" and offset or nil
	end

	---@param offset number
	function Manager.set_scroll_offset(offset)
		mod:set(SCROLL_KEY, offset)
	end

	---@param def table schema entry
	---@param value any
	function Manager.commit_value(def, value)
		mod:set(def.key, value, true)
		mod.dl.settings.invalidate_settings()
	end

	local function dispatch_on_change(setting_id)
		local def = Module.schema_by_key and Module.schema_by_key[setting_id]
		local handler = def and def.on_change_fn
		local fn = type(handler) == "string" and mod[handler] or handler
		if type(fn) == "function" then
			fn(mod:get(setting_id))
		end
	end

	---@param def table schema entry
	function Manager.press_button(def)
		local handler = def and def.on_click_fn
		local fn = type(handler) == "string" and mod[handler] or handler
		if type(fn) ~= "function" then
			return
		end

		---@type DLH_SettingsMenuClickEvent
		local event = {
			key = def.key,
			close_menu = function()
				mod.dl_hud.mod_menu.close()
			end,
		}

		fn(event)
	end

	---@param def table schema entry
	---@param field string
	---@return boolean
	local function evaluate(def, field)
		local predicate = def and def[field]
		if predicate == nil or predicate == false then
			return false
		end
		if predicate == true then
			return true
		end

		local fn = type(predicate) == "string" and mod[predicate] or predicate
		if type(fn) ~= "function" then
			return false
		end

		local ok, result = pcall(fn)
		return ok and result == true
	end

	---@param def table schema entry
	---@return boolean
	function Manager.is_hidden(def)
		return evaluate(def, "hidden_fn")
	end

	---@param def table schema entry
	---@return boolean
	function Manager.is_disabled(def)
		return evaluate(def, "disabled_fn")
	end

	local function install_input_hook()
		mod.dl.game_hooks.hook(CLASS.UIManager, "_update_view_hotkeys", function(func, self)
			if mod:is_enabled() and State.open and mod.dl.gameplay.in_gameplay() then
				return
			end

			return func(self)
		end)
	end

	---@param key string | nil
	---@return string | nil
	local function resolve_loc(key)
		if not key then
			return nil
		end
		local text = mod:localize(key)
		if not text or text == "<" .. key .. ">" then
			return nil
		end
		return text
	end

	Manager.build_menu = function(Schema, opts)
		opts = opts or {}

		local paths = {
			passes = base_path .. "/hud/passes",
			hud_definitions = base_path .. "/hud/hud_definitions",
			hud_instance = base_path .. "/hud/hud_instance",
		}

		if opts.title then
			local localized = mod:localize(opts.title)
			Module.title = (localized and localized ~= opts.title) and localized or opts.title
		end

		Module.schema = Schema
		Module.schema_by_key = Module.schema_builder.by_key(Schema)

		local tabs
		if Schema[1] and Schema[1].is_tab then
			tabs = Schema
		else
			tabs = { { is_tab = true, id = "_default", label_key = nil, controls = Schema } }
		end
		Module.tabs = tabs
		Module.has_tabs = #tabs >= 1

		for i = 1, #tabs do
			local tab = tabs[i]
			tab.title_text = resolve_loc(tab.title_key)
			tab.description_text = resolve_loc(tab.description_key)
		end

		Module.passes = nil
		mod:io_dofile(paths.passes)(Module, mod)

		Module.hud_definitions = nil
		mod:io_dofile(paths.hud_definitions)(Module, mod, Schema)

		mod.dl_hud.__hud_modules["settings_menu"] = Module

		Module.element_path = paths.hud_instance

		if opts.register_page ~= false then
			local label = Module.title or Module.constants.STRINGS.TITLE
			mod.dl_hud.mod_menu.add_page({
				id = "settings",
				label = label,
				element_path = paths.hud_instance,
				element_context = { mod_name = mod:get_name() },
			})
		end

		if State.built then
			return
		end
		State.built = true

		mod.dl.settings.hook_settings_changed(dispatch_on_change)

		mod.dl.gameplay.while_in_gameplay(Manager.dispatch_keybinds)
	end

	Module.manager = Manager

	return Manager
end
