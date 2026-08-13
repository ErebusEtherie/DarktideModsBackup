---@meta
---@class DMFMod : DarktideClass
---@field update fun(dt:number): nil | nil Callback executed every game tick.
---@field on_unload fun(exit_game: boolean): nil | nil Callback executed when mods are unloaded by the game. Triggers either on reload or the game exiting.
---@field on_game_state_changed fun(status: string,state_name: string): nil | nil Callback executed when the game state changes. Game state names can be found in the source code under scripts/game_states/game
---@field on_setting_changed fun(setting_id: string): nil | nil Callback executed when a mod setting is changed.<br>This callback is executed whenever mod:set is called with it’s notify_mod argument set to true. Eg,<br> `mod:set("foo", 42, true) --> Will trigger mod.on_setting_changed`<br>This can happen if the setting has an associated widget.<br>Use [mod:get(setting_id)](lua://DMFMod.get) inside the callback to get the new value.
---@field on_enabled fun(initial_call: boolean): nil | nil Callback executed when the mod is enabled.<br><br>This callback is only executed for togglable mods. When this callback is executed, all hooks and chat commands will already have been re-enabled. You can disable them here to counteract this behaviour.
---@field on_disabled fun(initial_call: boolean): nil | nil Callback executed whenever the mod is disabled.<br><br>This callback is only executed for togglable mods. When this callback is executed, all hooks and chat commands will already have been disabled. You can re-enable them here to counteract this behaviour.
---@field on_user_joined fun(player: Player): nil | nil Callback executed when a player with the same mod joins the game.<br><br>his event will only be called for mods which have registered a network call.
---@field on_user_left fun(player: Player): nil | nil Callback executed when a player with the same mod leaves the game.<br><br>This event will only be called for mods which have registered a network call.
---@field on_all_mods_loaded fun(dt: integer): nil | nil Callback executed when the game finishes loading all mods.
DMFMod = {}

---@param command_name string Command name, without the leading `/`. Should contain only alphanumeric characters and underscores.
---@param command_description string Short command description. Can include newlines (`'\n'`), but some have reported that this can cause UI issues.
---@param command_function function Command handler.
function DMFMod:command(command_name, command_description, command_function) end

---@param command_name string Command name.
function DMFMod:command_remove(command_name) end

---@param command_name string Command name.
function DMFMod:command_disable(command_name) end

---@param command_name string Command name.
function DMFMod:command_enable(command_name) end

function DMFMod:remove_all_commands() end

function DMFMod:disable_all_commands() end

function DMFMod:enable_all_commands() end

---@param table_name string Table identifier.
---@param default_table? table Default table.
---@return table # The persistent table if it exists, otherwise the default table. If this is nil, an empty table is returned.
function DMFMod:persistent_table(table_name, default_table) end

---@param dumped_object table Table to inspect.
---@param dumped_object_name? string Optional string with the table name.
---@param max_depth? number How many levels of nested tables will be dumped.
---@return nil
function DMFMod:dump(dumped_object, dumped_object_name, max_depth) end

---@param dumped_object table Table to inspect.
---@param dumped_object_name? string Name of the file without the extension.
---@param max_depth? number How many levels of nested tables will be dumped.
function DMFMod:dump_to_file(dumped_object, dumped_object_name, max_depth) end
DMFMod.dtf = DMFMod.dump_to_file

---@generic T : DMFMod
---@param mod_name string System mod name. Must be globally unique.
---@param mod_resources ModResources Mod resources definitions.
---@return DMFMod #The newly created mod object.
function _G.new_mod(mod_name, mod_resources) end

---@generic T : DMFMod
---@param mod_name string System mod name.
---@return DMFMod | nil #The mod instance, or nil if it doesn’t exist.
function _G.get_mod(mod_name) end

---@param obj string | table Table holding the method. When this argument is a string, the hooking is defered.
---@param method string Name of the method.
---@param handler fun(...: any) Hook handler.
function DMFMod:hook_safe(obj, method, handler) end

---@param obj string | table Table holding the method. When this argument is a string, the hooking is deferred.
---@param method string Name of the method.
---@param handler fun(func: function, ...: any): ...
---@return any
function DMFMod:hook(obj, method, handler) end

---@param obj string | table Table holding the method. When this argument is a string, the hooking is deferred.
---@param method string Name of the method.
---@param handler fun(...: any): ... Hook handler.
---@return nil
function DMFMod:hook_origin(obj, method, handler) end

---@param obj_str string The filename of the target`
---@param callback_func fun(instance: unknown): ... hook handler
function DMFMod:hook_require(obj_str, callback_func) end

---@param obj table Table holding the method.
---@param method string Name of the method.
function DMFMod:hook_enable(obj, method) end

---@param obj table Table holding the method.
---@param method string Name of the method.
function DMFMod:hook_disable(obj, method) end

function DMFMod:enable_all_hooks() end

function DMFMod:disable_all_hooks() end

---@class ElementSettings
---@field class_name string Name of the class containing the element’s logic.
---@field filename string
---@field use_hud_scale? boolean Set to true if the element should scale with the rest of the HUD.
---@field visibility_groups table Array of visibility group names for the element to be included in.
---@field validation_function? fun(params: table): boolean Function called by UIHud to determine whether to create the element.<br>Return true from this function to conditionally enable the element.<br>Exclude this parameter to always enable the element.

---@param element_settings ElementSettings
---@return boolean success `true` if the element was successfully injected.
function DMFMod:register_hud_element(element_settings) end

---@alias ModLocalization { [string]: { [string]: string }}

---@param text_id string Localization text id.
---@param ... string Parameters used in the formatting.
---@return string #A formatted string or an error message.<br>If the `text_id` wasn’t found, it is wrapped in angled brackets and returned (eg, `<text_id>`).
function DMFMod:localize(text_id, ...) end

---@param message string String message.
---@param ... any formatting parameters
function DMFMod:notify(message, ...) end

---@param message string String message.
---@param ... any formatting parameters
function DMFMod:echo(message, ...) end

---@param localization_id string Variable name for a string message stored in `<mod_name>_localization.lua`
---@param ... any formatting parameters
function DMFMod:echo_localized(localization_id, ...) end

---@param message string String message.
---@param ... any formatting parameters
function DMFMod:error(message, ...) end

---@param message string String message.
---@param ... any formatting parameters
function DMFMod:warning(message, ...) end

---@param message string String message.
---@param ... any formatting parameters
function DMFMod:info(message, ...) end

---@param message string String message.
---@param ... any formatting parameters
function DMFMod:debug(message, ...) end

---@return string #The internal name of the mod.
function DMFMod:get_name() end

---@return string Returns The mod name defined in its `mod_data`, or its internal name otherwise
function DMFMod:get_readable_name() end

---@return string #The mod description defined in its `mod_data`, or its internal name otherwise.
function DMFMod:get_description() end

---@return boolean #`true` if the mod is currently is enabled or is not toggleable.
function DMFMod:is_enabled() end

---@alias InternalDataKey

---@param key InternalDataKey Data entry name.
---@return unknown
function DMFMod:get_internal_data(key) end

---@param func function Function
---@param ... unknown #Arguments to the function.
---@return boolean success Indicator of whether the function execution was successful.
---@return ... #Return values of the function.
function DMFMod:pcall(func, ...) end

---@param file_path string Path to the file, **without** the .lua extension.
---@return ... #Values returned by the file.
function DMFMod:dofile(file_path) end

---@param setting_id string Setting identifier.
---@param setting_value unknown Saved data.
---@param notify_mod? boolean If true, the [mod.on_setting_changed](lua://DMFMod.on_setting_changed) event will be triggered.
function DMFMod:set(setting_id, setting_value, notify_mod) end

---@param setting_id string Setting identifier.
---@return unknown #value of the setting
function DMFMod:get(setting_id) end

---@class ModResources
---@field mod_script fun() | string | nil
---@field mod_data (fun(): ModData) | string | ModData | nil
---@field mod_localization (fun(): ModLocalization) | string | ModLocalization | nil

---@alias WidgetType

---@alias KeybindTrigger

---@alias KeybindType

---@class DropdownOptions
---@field text string
---@field value unknown
---@field show_widgets? integer[]
---@field requires_restart? boolean

---@class TransitionData
---@field open_view_transition_name? string
---@field close_view_transition_name? string
---@field open_view_transition_params? unknown
---@field transition_fade? boolean

---@class Widget
---@field setting_id string
---@field type WidgetType
---@field default_value? unknown
---@field title? string
---@field tooltip? string
---@field sub_widgets? Widget[]
---@field require_restart? boolean
---@field options? DropdownOptions[]
---@field keybind_global? boolean
---@field keybind_trigger? KeybindTrigger
---@field keybind_type? KeybindType
---@field function_name? string
---@field view_name? string
---@field transition_data? TransitionData
---@field range? { [integer]: number } e.g. {-100, 100}
---@field unit_text? string
---@field decimals_number? integer

---@class ModOptions
---@field widgets Widget[]

---@class ModData
---@field name? string | nil default nil
---@field description? string | nil default nil
---@field is_togglable? boolean default false
---@field allow_rehooking? boolean default false
---@field options? ModOptions

---@param view_data ViewData
---@return true | nil
function DMFMod:register_view(view_data) end

---@return true
function DMFMod:handle_transition() end

